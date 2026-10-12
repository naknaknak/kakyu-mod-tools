from __future__ import annotations

import argparse
import copy
import hashlib
import json
from pathlib import Path
from typing import Any

from mes_archive_ir import load_archive_entry, parse_mes_container
import plan_mes_choice_option_edit as choice_planner
import prepare_mes_editable_ir as editable_ir
import prove_mes_choice_group_authoring as choice_prover
from payload_values import (
    canonical_payload_bytes,
    fingerprint,
    is_sha256 as _is_sha256,
    sha256_file as _sha256_file,
)


AUDIT_SCHEMA = "kakyu_mes_choice_option_compile_audit/v1"
TOP_LEVEL_KEYS = {
    "ok", "schema", "producer", "compatibility", "source_identity", "inputs",
    "source", "output", "patch", "retained_contract", "invariants",
    "payload_sha256",
}
SUMMARY_KEYS = {
    "size", "entry_count", "code_offset", "code_size", "entry_sha256",
    "bytecode_sha256", "address_table_sha256", "choice_proof_sha256",
}
PATCH_KEYS = {
    "group_selector", "definition_id", "code_start", "code_end",
    "absolute_start", "absolute_end", "payload_size", "source_payload_sha256",
    "replacement_payload_sha256", "source_instruction_sha256",
    "replacement_instruction_sha256", "source_body_sha256",
    "replacement_body_sha256", "byte_delta",
}
RETAINED_KEYS = {
    "address_entry_index", "address_entry_start", "address_entry_end",
    "source_structure_sha256", "output_structure_sha256",
    "result_mapping_sha256", "terminal_start", "terminal_end",
    "terminal_raw_sha256", "physical_resume_start", "physical_resume_end",
    "physical_resume_raw_sha256", "source_prefix_sha256",
    "source_suffix_sha256", "unchanged_definition_count",
}
SOURCE_IDENTITY_KEYS = {"archive", "archive_sha256", "entry", "entry_sha256"}
COMPATIBILITY = {
    "policy": "exact_same_length_choice_option_plan_only",
    "input_plan_schema": choice_planner.PLAN_SCHEMA,
    "input_choice_proof_schema": choice_prover.SCHEMA,
    "output_choice_proof_schema": choice_prover.SCHEMA,
    "output_policy": "new_file_only",
    "relocation": "forbidden_zero_delta_only",
    "native_engine_compatibility": "unverified",
    "native_input_and_gameplay_labels": "unresolved",
    "unknown_audit_schema": "reject",
    "unknown_v1_field": "reject",
}
INVARIANTS = {
    "plan_ready": True,
    "source_choice_proof_rebuilt": True,
    "output_choice_proof_rebuilt": True,
    "container_size_preserved": True,
    "entry_count_preserved": True,
    "code_offset_preserved": True,
    "code_size_preserved": True,
    "address_table_preserved": True,
    "address_entry_boundary_preserved": True,
    "group_and_definition_coordinates_preserved": True,
    "result_mapping_preserved": True,
    "routine40_terminal_and_physical_resume_preserved": True,
    "registration_and_return_preserved": True,
    "replacement_payload_exact": True,
    "code_prefix_preserved": True,
    "code_suffix_preserved": True,
    "only_selected_payload_changed": True,
    "source_container_not_modified": True,
}


class ChoiceOptionCompileError(ValueError):
    pass


def compile_choice_option(
    source_payload: bytes,
    source_proof: dict[str, Any],
    plan_document: dict[str, Any],
) -> tuple[bytes, dict[str, Any]]:
    choice_planner.validate(plan_document, source_payload, source_proof)
    source_before = bytes(source_payload)
    source_container = parse_mes_container(source_payload, source_proof["source_identity"])
    code_offset = int(source_container["header"]["codeOffset"])
    source_code = source_payload[code_offset:]
    target = plan_document["target"]
    replacement = plan_document["replacement"]
    code_start = int(target["payload_start"])
    code_end = int(target["payload_end"])
    source_raw = _hex_bytes(target["payload_raw_hex"], "source payload")
    replacement_raw = _hex_bytes(
        replacement["payload_raw_hex"], "replacement payload"
    )
    if (
        code_start < 0
        or code_end <= code_start
        or code_end > len(source_code)
        or len(source_raw) != code_end - code_start
        or len(replacement_raw) != len(source_raw)
        or source_code[code_start:code_end] != source_raw
        or hashlib.sha256(source_raw).hexdigest() != target["payload_raw_sha256"]
        or hashlib.sha256(replacement_raw).hexdigest()
        != replacement["payload_raw_sha256"]
    ):
        raise ChoiceOptionCompileError("MES choice-option compile target boundary changed")
    output_code = source_code[:code_start] + replacement_raw + source_code[code_end:]
    output = source_payload[:code_offset] + output_code
    output_container = parse_mes_container(output, source_proof["source_identity"])
    if (
        len(output) != len(source_payload)
        or output_container["header"]["entryCount"]
        != source_container["header"]["entryCount"]
        or output_container["header"]["entryOffsets"]
        != source_container["header"]["entryOffsets"]
        or output_container["header"]["codeOffset"]
        != source_container["header"]["codeOffset"]
        or len(output_code) != len(source_code)
        or hashlib.sha256(output).hexdigest()
        != replacement["output_entry_sha256"]
        or hashlib.sha256(output_code).hexdigest()
        != replacement["output_bytecode_sha256"]
    ):
        raise ChoiceOptionCompileError("MES choice-option compile changed container layout")
    output_proof = choice_prover.prove_entry(
        output,
        {
            "archive": source_proof["source_identity"]["archive"],
            "archive_sha256": source_proof["source_identity"]["archive_sha256"],
            "entry": source_proof["source_identity"]["entry"],
        },
        int(source_proof["boundary"]["address_entry_index"]),
    )
    source_structure = _structure_projection(source_proof)
    output_structure = _structure_projection(output_proof)
    if source_structure != output_structure:
        raise ChoiceOptionCompileError(
            "MES choice-option compile changed grouped structure coordinates"
        )
    _verify_output_proof(source_proof, output_proof, plan_document)
    if source_payload != source_before:
        raise ChoiceOptionCompileError("MES choice-option compile changed source buffer")
    absolute_start = code_offset + code_start
    absolute_end = code_offset + code_end
    changed_offsets = [
        index for index, (old, new) in enumerate(zip(source_payload, output))
        if old != new
    ]
    unchanged_definitions = int(source_proof["coverage"]["definition_count"]) - 1
    audit = {
        "ok": True,
        "schema": AUDIT_SCHEMA,
        "producer": {
            "implementation": "python_phase6_choice_option_compiler",
            "contract": AUDIT_SCHEMA,
        },
        "compatibility": copy.deepcopy(COMPATIBILITY),
        "source_identity": copy.deepcopy(source_proof["source_identity"]),
        "inputs": {
            "choice_proof_sha256": source_proof["payload_sha256"],
            "choice_option_plan_sha256": plan_document["payload_sha256"],
        },
        "source": _summary(source_payload, source_container, source_proof),
        "output": _summary(output, output_container, output_proof),
        "patch": {
            "group_selector": int(target["group_selector"]),
            "definition_id": int(target["definition_id"]),
            "code_start": code_start,
            "code_end": code_end,
            "absolute_start": absolute_start,
            "absolute_end": absolute_end,
            "payload_size": len(source_raw),
            "source_payload_sha256": str(target["payload_raw_sha256"]),
            "replacement_payload_sha256": str(replacement["payload_raw_sha256"]),
            "source_instruction_sha256": str(target["instruction_raw_sha256"]),
            "replacement_instruction_sha256": str(
                replacement["instruction_raw_sha256"]
            ),
            "source_body_sha256": str(target["body_raw_sha256"]),
            "replacement_body_sha256": str(replacement["body_raw_sha256"]),
            "byte_delta": 0,
        },
        "retained_contract": {
            "address_entry_index": int(source_proof["boundary"]["address_entry_index"]),
            "address_entry_start": int(source_proof["boundary"]["address_entry_start"]),
            "address_entry_end": int(source_proof["boundary"]["address_entry_end"]),
            "source_structure_sha256": _subtree_hash(source_structure),
            "output_structure_sha256": _subtree_hash(output_structure),
            "result_mapping_sha256": _subtree_hash(source_proof["result_mapping"]),
            "terminal_start": int(source_proof["boundary"]["terminal_start"]),
            "terminal_end": int(source_proof["boundary"]["terminal_end"]),
            "terminal_raw_sha256": str(
                source_proof["boundary"]["terminal_raw_sha256"]
            ),
            "physical_resume_start": int(
                source_proof["boundary"]["physical_resume_start"]
            ),
            "physical_resume_end": int(
                source_proof["boundary"]["physical_resume_end"]
            ),
            "physical_resume_raw_sha256": str(
                source_proof["boundary"]["physical_resume_raw_sha256"]
            ),
            "source_prefix_sha256": hashlib.sha256(
                source_payload[:absolute_start]
            ).hexdigest(),
            "source_suffix_sha256": hashlib.sha256(
                source_payload[absolute_end:]
            ).hexdigest(),
            "unchanged_definition_count": unchanged_definitions,
        },
        "invariants": {
            **copy.deepcopy(INVARIANTS),
            "only_selected_payload_changed": bool(changed_offsets)
            and all(absolute_start <= value < absolute_end for value in changed_offsets),
        },
    }
    if audit["invariants"] != INVARIANTS:
        raise ChoiceOptionCompileError("MES choice-option compile invariant failed")
    audit["payload_sha256"] = fingerprint(audit)
    validate_audit(audit)
    return output, audit


def validate_audit(
    audit: dict[str, Any],
    source_payload: bytes | None = None,
    source_proof: dict[str, Any] | None = None,
    plan_document: dict[str, Any] | None = None,
    output: bytes | None = None,
) -> dict[str, Any]:
    if (
        audit.get("ok") is not True
        or audit.get("schema") != AUDIT_SCHEMA
        or set(audit) != TOP_LEVEL_KEYS
    ):
        raise ChoiceOptionCompileError(
            "MES choice-option compile audit schema or fields changed"
        )
    if audit.get("producer") != {
        "implementation": "python_phase6_choice_option_compiler",
        "contract": AUDIT_SCHEMA,
    }:
        raise ChoiceOptionCompileError("MES choice-option compile producer changed")
    if audit.get("compatibility") != COMPATIBILITY:
        raise ChoiceOptionCompileError("MES choice-option compile compatibility changed")
    retained_hash = audit.get("payload_sha256")
    if not _is_sha256(retained_hash) or fingerprint(audit) != retained_hash:
        raise ChoiceOptionCompileError("MES choice-option compile fingerprint changed")
    identity = audit.get("source_identity")
    if (
        not isinstance(identity, dict)
        or set(identity) != SOURCE_IDENTITY_KEYS
        or not _is_sha256(identity.get("archive_sha256"))
        or not _is_sha256(identity.get("entry_sha256"))
        or not isinstance(identity.get("archive"), str)
        or not isinstance(identity.get("entry"), str)
    ):
        raise ChoiceOptionCompileError("MES choice-option compile source changed")
    inputs = audit.get("inputs")
    if (
        not isinstance(inputs, dict)
        or set(inputs) != {"choice_proof_sha256", "choice_option_plan_sha256"}
        or not all(_is_sha256(value) for value in inputs.values())
    ):
        raise ChoiceOptionCompileError("MES choice-option compile inputs changed")
    for key in ("source", "output"):
        if not _valid_summary(audit.get(key)):
            raise ChoiceOptionCompileError(
                f"MES choice-option compile {key} summary changed"
            )
    patch = audit.get("patch")
    if not _valid_patch(patch, audit["source"], audit["output"]):
        raise ChoiceOptionCompileError("MES choice-option compile patch changed")
    retained = audit.get("retained_contract")
    if not _valid_retained(retained, audit["source"]):
        raise ChoiceOptionCompileError(
            "MES choice-option compile retained contract changed"
        )
    if audit.get("invariants") != INVARIANTS:
        raise ChoiceOptionCompileError("MES choice-option compile invariants changed")
    supplied = (source_payload, source_proof, plan_document, output)
    if any(value is not None for value in supplied):
        if any(value is None for value in supplied):
            raise ChoiceOptionCompileError(
                "MES choice-option compile source validation inputs are incomplete"
            )
        expected_output, expected_audit = compile_choice_option(
            source_payload, source_proof, plan_document
        )
        if expected_output != output or expected_audit != audit:
            raise ChoiceOptionCompileError(
                "MES choice-option compile audit differs from its source"
            )
    return {"ok": True, "schema": AUDIT_SCHEMA, "payload_sha256": retained_hash}
def _verify_output_proof(
    source: dict[str, Any],
    output: dict[str, Any],
    plan: dict[str, Any],
) -> None:
    if (
        source["boundary"] != output["boundary"]
        or source["result_mapping"] != output["result_mapping"]
        or source["coverage"] != output["coverage"]
        or len(source["groups"]) != len(output["groups"])
    ):
        raise ChoiceOptionCompileError("MES choice-option output proof topology changed")
    target_group = int(plan["target"]["group_selector"])
    target_definition = int(plan["target"]["definition_id"])
    for source_group, output_group in zip(source["groups"], output["groups"]):
        for source_definition, output_definition in zip(
            source_group["definitions"], output_group["definitions"]
        ):
            selected = (
                source_group["selector"] == target_group
                and source_definition["definition_id"] == target_definition
            )
            if not selected and source_definition != output_definition:
                raise ChoiceOptionCompileError(
                    "MES choice-option compile changed another definition"
                )
            if selected:
                if (
                    source_definition["registration"]
                    != output_definition["registration"]
                    or source_definition["return_record"]
                    != output_definition["return_record"]
                    or source_definition["guard"] != output_definition["guard"]
                    or output_definition["message"]["payload_raw_sha256"]
                    != plan["replacement"]["payload_raw_sha256"]
                    or output_definition["message"]["instruction_raw_sha256"]
                    != plan["replacement"]["instruction_raw_sha256"]
                    or output_definition["body"]["raw_sha256"]
                    != plan["replacement"]["body_raw_sha256"]
                ):
                    raise ChoiceOptionCompileError(
                        "MES choice-option output definition proof changed"
                    )


def _structure_projection(proof: dict[str, Any]) -> dict[str, Any]:
    groups = []
    for group in proof["groups"]:
        definitions = []
        for definition in group["definitions"]:
            message = definition["message"]
            guard = definition["guard"]
            definitions.append({
                "definition_id": definition["definition_id"],
                "registration": _span_coordinates(definition["registration"]),
                "body": {
                    "start": definition["body"]["start"],
                    "end": definition["body"]["end"],
                    "size": definition["body"]["size"],
                },
                "message": {
                    "instruction_start": message["instruction_start"],
                    "instruction_end": message["instruction_end"],
                    "payload_start": message["payload_start"],
                    "payload_end": message["payload_end"],
                    "payload_size": message["payload_size"],
                    "encoding": message["encoding"],
                    "native_projection": message["native_projection"],
                    "terminator_offset": message["terminator_offset"],
                    "terminator": message["terminator"],
                },
                "return_record": _span_coordinates(definition["return_record"]),
                "guard": {
                    "kind": guard["kind"],
                    "instruction": (
                        None if guard["instruction"] is None
                        else _span_coordinates(guard["instruction"])
                    ),
                },
            })
        groups.append({
            "selector": group["selector"],
            "clear": _span_coordinates(group["clear"]),
            "definition_count": group["definition_count"],
            "empty_after_clear": group["empty_after_clear"],
            "conditional_definition_count": group["conditional_definition_count"],
            "definitions": definitions,
        })
    return {
        "boundary": {
            key: value for key, value in proof["boundary"].items()
            if not key.endswith("_sha256")
        },
        "groups": groups,
        "first_stage_options": [
            {key: value for key, value in row.items() if key != "message_payload_sha256"}
            for row in proof["first_stage_options"]
        ],
        "coverage": copy.deepcopy(proof["coverage"]),
    }


def _span_coordinates(span: dict[str, Any]) -> dict[str, int]:
    return {"start": int(span["start"]), "end": int(span["end"])}


def _summary(
    payload: bytes,
    container: dict[str, Any],
    proof: dict[str, Any],
) -> dict[str, Any]:
    code_offset = int(container["header"]["codeOffset"])
    return {
        "size": len(payload),
        "entry_count": int(container["header"]["entryCount"]),
        "code_offset": code_offset,
        "code_size": len(payload) - code_offset,
        "entry_sha256": hashlib.sha256(payload).hexdigest(),
        "bytecode_sha256": hashlib.sha256(payload[code_offset:]).hexdigest(),
        "address_table_sha256": hashlib.sha256(payload[4:code_offset]).hexdigest(),
        "choice_proof_sha256": proof["payload_sha256"],
    }


def _valid_summary(value: Any) -> bool:
    return (
        isinstance(value, dict)
        and set(value) == SUMMARY_KEYS
        and all(
            _is_nonnegative_int(value.get(key))
            for key in ("size", "entry_count", "code_offset", "code_size")
        )
        and value["size"] == value["code_offset"] + value["code_size"]
        and all(
            _is_sha256(value.get(key))
            for key in (
                "entry_sha256", "bytecode_sha256", "address_table_sha256",
                "choice_proof_sha256",
            )
        )
    )


def _valid_patch(
    value: Any,
    source: dict[str, Any],
    output: dict[str, Any],
) -> bool:
    if not isinstance(value, dict) or set(value) != PATCH_KEYS:
        return False
    integers = {
        "group_selector", "definition_id", "code_start", "code_end",
        "absolute_start", "absolute_end", "payload_size", "byte_delta",
    }
    hashes = PATCH_KEYS - integers
    return (
        all(_is_nonnegative_int(value.get(key)) for key in integers)
        and all(_is_sha256(value.get(key)) for key in hashes)
        and value["byte_delta"] == 0
        and value["code_end"] - value["code_start"] == value["payload_size"]
        and value["absolute_start"] == source["code_offset"] + value["code_start"]
        and value["absolute_end"] == source["code_offset"] + value["code_end"]
        and source["size"] == output["size"]
        and source["entry_count"] == output["entry_count"]
        and source["code_offset"] == output["code_offset"]
        and source["code_size"] == output["code_size"]
        and source["address_table_sha256"] == output["address_table_sha256"]
    )


def _valid_retained(value: Any, source: dict[str, Any]) -> bool:
    if not isinstance(value, dict) or set(value) != RETAINED_KEYS:
        return False
    integer_keys = {
        "address_entry_index", "address_entry_start", "address_entry_end",
        "terminal_start", "terminal_end", "physical_resume_start",
        "physical_resume_end", "unchanged_definition_count",
    }
    hash_keys = RETAINED_KEYS - integer_keys
    return (
        all(_is_nonnegative_int(value.get(key)) for key in integer_keys)
        and all(_is_sha256(value.get(key)) for key in hash_keys)
        and value["source_structure_sha256"] == value["output_structure_sha256"]
        and value["address_entry_end"] > value["address_entry_start"]
        and value["terminal_end"] > value["terminal_start"]
        and value["terminal_end"] == value["physical_resume_start"]
        and value["physical_resume_end"] > value["physical_resume_start"]
        and value["address_entry_end"] <= source["code_size"]
    )


def _subtree_hash(value: Any) -> str:
    return hashlib.sha256(
        json.dumps(
            value, ensure_ascii=False, allow_nan=False, sort_keys=True,
            separators=(",", ":"),
        ).encode("utf-8")
    ).hexdigest()


def _hex_bytes(value: Any, label: str) -> bytes:
    if not isinstance(value, str) or len(value) % 2:
        raise ChoiceOptionCompileError(f"MES choice-option {label} hex changed")
    try:
        return bytes.fromhex(value)
    except ValueError as error:
        raise ChoiceOptionCompileError(
            f"MES choice-option {label} hex changed"
        ) from error


def _is_nonnegative_int(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value >= 0


def _load_json_object(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ChoiceOptionCompileError(f"{path.name} is not a JSON object")
    return value


def main() -> None:
    parser = argparse.ArgumentParser(
        description=(
            "Compile one validated same-length choice-option plan into a new "
            "MES and compact structural audit."
        )
    )
    parser.add_argument("archive", type=Path)
    parser.add_argument("entry")
    parser.add_argument("choice_proof", type=Path)
    parser.add_argument("plan", type=Path)
    parser.add_argument("output_mes", type=Path)
    parser.add_argument("audit_output", type=Path)
    args = parser.parse_args()
    archive = args.archive.resolve()
    paths = {
        archive, args.choice_proof.resolve(), args.plan.resolve(),
        args.output_mes.resolve(), args.audit_output.resolve(),
    }
    if len(paths) != 5:
        raise ChoiceOptionCompileError("MES choice-option compile paths must differ")
    for output in (args.output_mes.resolve(), args.audit_output.resolve()):
        if (
            output.exists()
            or output == archive.parent
            or archive.parent in output.parents
        ):
            raise ChoiceOptionCompileError(
                "MES choice-option compile outputs must be new and outside the source directory"
            )
    source_payload, _source = load_archive_entry(archive, args.entry)
    source_proof = _load_json_object(args.choice_proof)
    plan_document = _load_json_object(args.plan)
    identity = source_proof.get("source_identity", {})
    if (
        identity.get("archive") != archive.name
        or identity.get("archive_sha256") != _sha256_file(archive)
        or identity.get("entry") != args.entry
    ):
        raise ChoiceOptionCompileError(
            "MES choice-option compile source differs from its proof"
        )
    output, audit = compile_choice_option(source_payload, source_proof, plan_document)
    audit_bytes = json.dumps(
        audit, ensure_ascii=False, allow_nan=False, sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8") + b"\n"
    published_mes = False
    published_audit = False
    try:
        editable_ir.publish_new(args.output_mes, output)
        published_mes = True
        editable_ir.publish_new(args.audit_output, audit_bytes)
        published_audit = True
        reopened_audit = _load_json_object(args.audit_output)
        validate_audit(
            reopened_audit, source_payload, source_proof, plan_document,
            args.output_mes.read_bytes(),
        )
    except BaseException:
        if published_audit and args.audit_output.is_file():
            args.audit_output.unlink()
        if published_mes and args.output_mes.is_file():
            args.output_mes.unlink()
        raise
    print(
        "MES_CHOICE_OPTION_COMPILE_PASS "
        f"schema={AUDIT_SCHEMA} entry={audit['source_identity']['entry']} "
        f"group={audit['patch']['group_selector']} "
        f"definition={audit['patch']['definition_id']} "
        f"bytes={audit['output']['size']} "
        f"output_entry_sha256={audit['output']['entry_sha256']} "
        f"output_choice_proof_sha256={audit['output']['choice_proof_sha256']} "
        f"payload_sha256={audit['payload_sha256']}"
    )


if __name__ == "__main__":
    main()
