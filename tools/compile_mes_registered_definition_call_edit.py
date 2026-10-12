from __future__ import annotations

import argparse
import copy
import hashlib
import json
from pathlib import Path
from typing import Any

import compile_mes_noop as noop_compiler
import decompile_mes_handoff as decompiler
import plan_mes_registered_definition_call_edit as call_planner
import prepare_mes_editable_ir as editable_ir
import prove_mes_registered_definition_registry as registry_prover
from payload_values import canonical_payload_bytes, fingerprint, is_sha256 as _is_sha256


AUDIT_SCHEMA = "kakyu_mes_registered_definition_call_compile_audit/v1"
TOP_LEVEL_KEYS = {
    "ok", "schema", "producer", "compatibility", "source_identity",
    "registry_identity", "inputs", "source", "output", "operation",
    "target", "coverage", "invariants", "payload_sha256",
}
SUMMARY_KEYS = {
    "size", "entry_count", "code_offset", "code_size", "entry_sha256",
    "bytecode_sha256", "preamble_sha256", "address_table_sha256",
}
OPERATION_KEYS = {
    "kind", "source_offset", "source_selector", "replacement_selector",
    "width", "physical_resume_offset",
}
TARGET_KEYS = {
    "node_id", "region_id", "instruction_start", "instruction_end",
    "literal_start", "literal_end", "resume_node_id", "resume_region_id",
    "resume_start", "resume_end", "resume_raw_sha256",
    "source_instruction_sha256", "replacement_instruction_sha256",
    "source_expression_sha256", "replacement_expression_sha256",
    "source_literal_sha256", "replacement_literal_sha256", "call_proof",
    "source_registry_binding", "replacement_registry_binding",
}
COVERAGE_KEYS = {
    "region_count", "node_count", "typed_node_count", "opaque_node_count",
    "code_bytes",
}
INVARIANT_KEYS = {
    "plan_ready", "output_reopened", "container_size_preserved",
    "entry_count_preserved", "code_offset_preserved", "code_size_preserved",
    "address_table_preserved", "preamble_preserved", "code_prefix_preserved",
    "replacement_instruction_exact", "code_suffix_preserved",
    "only_literal_range_changed", "physical_resume_bytes_preserved",
    "call_proof_retained", "source_registry_certificate_retained",
    "replacement_registry_certificate_retained", "registered_bodies_not_executed",
    "source_container_not_modified",
}
SOURCE_IDENTITY_KEYS = {"archive", "entry", "source_kind", "archive_sha256"}
COMPATIBILITY = {
    "policy": "exact_same_width_literal_registered_definition_call_plan_only",
    "input_editable_schema": editable_ir.EDITABLE_IR_SCHEMA,
    "input_plan_schema": call_planner.PLAN_SCHEMA,
    "input_decompiler_schema": decompiler.DECOMPILER_IR_SCHEMA,
    "input_call_family_proof_schema": "kakyu_mes_call_family_proof/v1",
    "input_registry_proof_schema": registry_prover.SCHEMA,
    "unknown_audit_schema": "reject",
    "unknown_v1_field": "reject",
    "output_policy": "new_file_only",
    "relocation": "forbidden",
    "registered_body_execution": "not_performed",
    "return_edge_policy": "not_emitted",
    "native_engine_compatibility": "unverified",
}


class RegisteredDefinitionCallCompileError(ValueError):
    pass


def compile_registered_definition_call(
    editable_document: dict[str, Any],
    call_family_proof: dict[str, Any],
    registry_proof: dict[str, Any],
    plan_document: dict[str, Any],
) -> tuple[bytes, dict[str, Any]]:
    editable_ir.validate(editable_document)
    call_planner.validate(
        plan_document, editable_document, call_family_proof, registry_proof
    )
    if plan_document.get("assembly_ready") is not True:
        raise RegisteredDefinitionCallCompileError(
            "MES registered-definition call edit plan is not assembly ready"
        )
    source_ir = editable_document["source_ir"]
    source = decompiler.reconstruct_container(source_ir)
    source_before = bytes(source)
    source_header = noop_compiler.reopen_container(source)
    code_offset = int(source_header["code_offset"])
    source_code = source[code_offset:]
    target = plan_document["target"]
    replacement = plan_document["replacement"]
    instruction_start = int(target["instruction_start"])
    instruction_end = int(target["instruction_end"])
    literal_start = int(target["literal_start"])
    literal_end = int(target["literal_end"])
    source_instruction = _hex_bytes(target["instruction_raw_hex"], "source instruction")
    replacement_instruction = _hex_bytes(
        replacement["instruction_raw_hex"], "replacement instruction"
    )
    if (
        instruction_start < 0
        or instruction_end <= instruction_start
        or instruction_end > len(source_code)
        or len(source_instruction) != instruction_end - instruction_start
        or len(replacement_instruction) != len(source_instruction)
        or source_code[instruction_start:instruction_end] != source_instruction
        or not instruction_start <= literal_start < literal_end <= instruction_end
        or literal_end - literal_start != 1
    ):
        raise RegisteredDefinitionCallCompileError(
            "MES registered-definition call compile target boundary changed"
        )
    output_code = (
        source_code[:instruction_start]
        + replacement_instruction
        + source_code[instruction_end:]
    )
    output = source[:code_offset] + output_code
    reopened = noop_compiler.reopen_container(output)
    if (
        reopened["entry_count"] != source_header["entry_count"]
        or reopened["entry_offsets"] != source_header["entry_offsets"]
        or reopened["code_offset"] != source_header["code_offset"]
        or reopened["code_size"] != source_header["code_size"]
    ):
        raise RegisteredDefinitionCallCompileError(
            "MES registered-definition call compile changed container layout"
        )
    changed = [
        index for index, (before, after) in enumerate(zip(source_code, output_code))
        if before != after
    ]
    if changed != list(range(literal_start, literal_end)):
        raise RegisteredDefinitionCallCompileError(
            "MES registered-definition call compile changed bytes outside the literal"
        )
    call_proof = target["call_proof"]
    resume_node = _resume_node(source_ir, call_proof)
    resume_start = int(resume_node["source"]["start"])
    resume_end = int(resume_node["source"]["end"])
    resume_raw = _hex_bytes(resume_node["source"]["raw_hex"], "physical resume")
    if (
        resume_start != int(call_proof["physical_resume_offset"])
        or source_code[resume_start:resume_end] != resume_raw
        or output_code[resume_start:resume_end] != resume_raw
    ):
        raise RegisteredDefinitionCallCompileError(
            "MES registered-definition call physical resume bytes changed"
        )
    if source != source_before:
        raise RegisteredDefinitionCallCompileError(
            "MES registered-definition call compile changed its source buffer"
        )
    coverage = source_ir["coverage"]
    operation = plan_document["operation"]
    source_binding = target["registry_binding"]
    replacement_binding = replacement["registry_binding"]
    audit = {
        "ok": True,
        "schema": AUDIT_SCHEMA,
        "producer": {
            "implementation": "python_phase6_registered_definition_call_compiler",
            "contract": AUDIT_SCHEMA,
        },
        "compatibility": copy.deepcopy(COMPATIBILITY),
        "source_identity": copy.deepcopy(source_ir["source_identity"]),
        "registry_identity": copy.deepcopy(plan_document["registry_identity"]),
        "inputs": {
            "editable_ir_sha256": editable_document["payload_sha256"],
            "decompiler_ir_sha256": source_ir["payload_sha256"],
            "call_family_proof_sha256": call_family_proof["payload_sha256"],
            "registry_proof_sha256": registry_proof["payload_sha256"],
            "registered_definition_call_plan_sha256": plan_document["payload_sha256"],
        },
        "source": _container_summary(source, source_header),
        "output": _container_summary(output, reopened),
        "operation": {
            "kind": "replace_registered_definition_literal",
            "source_offset": int(operation["source_offset"]),
            "source_selector": int(target["selector"]),
            "replacement_selector": int(replacement["selector"]),
            "width": int(target["width"]),
            "physical_resume_offset": int(call_proof["physical_resume_offset"]),
        },
        "target": {
            "node_id": str(target["node_id"]),
            "region_id": str(target["region_id"]),
            "instruction_start": instruction_start,
            "instruction_end": instruction_end,
            "literal_start": literal_start,
            "literal_end": literal_end,
            "resume_node_id": str(resume_node["id"]),
            "resume_region_id": str(resume_node["source"]["region"]),
            "resume_start": resume_start,
            "resume_end": resume_end,
            "resume_raw_sha256": hashlib.sha256(resume_raw).hexdigest(),
            "source_instruction_sha256": str(target["instruction_raw_sha256"]),
            "replacement_instruction_sha256": str(
                replacement["instruction_raw_sha256"]
            ),
            "source_expression_sha256": str(target["expression_raw_sha256"]),
            "replacement_expression_sha256": str(
                replacement["expression_raw_sha256"]
            ),
            "source_literal_sha256": str(target["literal_raw_sha256"]),
            "replacement_literal_sha256": str(replacement["literal_raw_sha256"]),
            "call_proof": copy.deepcopy(call_proof),
            "source_registry_binding": copy.deepcopy(source_binding),
            "replacement_registry_binding": copy.deepcopy(replacement_binding),
        },
        "coverage": {
            "region_count": int(coverage["region_count"]),
            "node_count": int(coverage["node_count"]),
            "typed_node_count": int(coverage["typed_node_count"]),
            "opaque_node_count": int(coverage["opaque_node_count"]),
            "code_bytes": int(coverage["code_bytes"]),
        },
        "invariants": {
            "plan_ready": True,
            "output_reopened": True,
            "container_size_preserved": len(output) == len(source),
            "entry_count_preserved": reopened["entry_count"] == source_header["entry_count"],
            "code_offset_preserved": reopened["code_offset"] == source_header["code_offset"],
            "code_size_preserved": reopened["code_size"] == source_header["code_size"],
            "address_table_preserved": reopened["entry_offsets"] == source_header["entry_offsets"],
            "preamble_preserved": output[:code_offset] == source[:code_offset],
            "code_prefix_preserved": output_code[:instruction_start] == source_code[:instruction_start],
            "replacement_instruction_exact": output_code[instruction_start:instruction_end] == replacement_instruction,
            "code_suffix_preserved": output_code[instruction_end:] == source_code[instruction_end:],
            "only_literal_range_changed": changed == list(range(literal_start, literal_end)),
            "physical_resume_bytes_preserved": output_code[resume_start:resume_end] == resume_raw,
            "call_proof_retained": call_proof == target["call_proof"],
            "source_registry_certificate_retained": source_binding == target["registry_binding"],
            "replacement_registry_certificate_retained": replacement_binding == replacement["registry_binding"],
            "registered_bodies_not_executed": True,
            "source_container_not_modified": source == source_before,
        },
    }
    if not all(audit["invariants"].values()):
        raise RegisteredDefinitionCallCompileError(
            "MES registered-definition call compile invariant failed"
        )
    audit["payload_sha256"] = fingerprint(audit)
    validate_audit(audit)
    return output, audit


def validate_audit(
    audit: dict[str, Any],
    editable_document: dict[str, Any] | None = None,
    call_family_proof: dict[str, Any] | None = None,
    registry_proof: dict[str, Any] | None = None,
    plan_document: dict[str, Any] | None = None,
    output: bytes | None = None,
) -> dict[str, Any]:
    if (
        audit.get("ok") is not True
        or audit.get("schema") != AUDIT_SCHEMA
        or set(audit) != TOP_LEVEL_KEYS
    ):
        raise RegisteredDefinitionCallCompileError(
            "MES registered-definition call compile audit schema or fields changed"
        )
    if audit.get("producer") != {
        "implementation": "python_phase6_registered_definition_call_compiler",
        "contract": AUDIT_SCHEMA,
    }:
        raise RegisteredDefinitionCallCompileError(
            "MES registered-definition call compile audit producer changed"
        )
    if audit.get("compatibility") != COMPATIBILITY:
        raise RegisteredDefinitionCallCompileError(
            "MES registered-definition call compile compatibility changed"
        )
    retained = audit.get("payload_sha256")
    if not _is_sha256(retained) or fingerprint(audit) != retained:
        raise RegisteredDefinitionCallCompileError(
            "MES registered-definition call compile audit fingerprint changed"
        )
    source_identity = audit.get("source_identity")
    registry_identity = audit.get("registry_identity")
    inputs = audit.get("inputs")
    if (
        not isinstance(source_identity, dict)
        or not set(source_identity).issubset(SOURCE_IDENTITY_KEYS)
        or not isinstance(source_identity.get("entry"), str)
        or not source_identity["entry"]
        or not _is_sha256(source_identity.get("archive_sha256"))
        or not isinstance(registry_identity, dict)
        or set(registry_identity) != call_planner.REGISTRY_IDENTITY_KEYS
        or not isinstance(registry_identity.get("archive"), str)
        or not registry_identity["archive"]
        or not isinstance(registry_identity.get("entry"), str)
        or not registry_identity["entry"]
        or any(
            not _is_sha256(registry_identity.get(key))
            for key in ("archive_sha256", "entry_sha256", "proof_sha256")
        )
        or registry_identity.get("archive_sha256") != source_identity.get("archive_sha256")
        or not isinstance(inputs, dict)
        or set(inputs) != {
            "editable_ir_sha256", "decompiler_ir_sha256",
            "call_family_proof_sha256", "registry_proof_sha256",
            "registered_definition_call_plan_sha256",
        }
        or not all(_is_sha256(value) for value in inputs.values())
        or inputs["registry_proof_sha256"] != registry_identity.get("proof_sha256")
    ):
        raise RegisteredDefinitionCallCompileError(
            "MES registered-definition call compile input identity changed"
        )
    for key in ("source", "output"):
        if not _valid_summary(audit.get(key)):
            raise RegisteredDefinitionCallCompileError(
                "MES registered-definition call compile container summary changed"
            )
    operation = audit.get("operation")
    if (
        not isinstance(operation, dict)
        or set(operation) != OPERATION_KEYS
        or operation.get("kind") != "replace_registered_definition_literal"
        or any(
            not _is_nonnegative_int(operation.get(key))
            for key in OPERATION_KEYS - {"kind"}
        )
        or operation.get("width") != 8
        or operation.get("source_selector") == operation.get("replacement_selector")
        or operation.get("source_selector") > 0x7F
        or operation.get("replacement_selector") > 0x7F
    ):
        raise RegisteredDefinitionCallCompileError(
            "MES registered-definition call compile operation changed"
        )
    target = audit.get("target")
    if not _valid_target(target, operation):
        raise RegisteredDefinitionCallCompileError(
            "MES registered-definition call compile target changed"
        )
    coverage = audit.get("coverage")
    if (
        not isinstance(coverage, dict)
        or set(coverage) != COVERAGE_KEYS
        or any(not _is_nonnegative_int(value) for value in coverage.values())
        or coverage["node_count"]
        != coverage["typed_node_count"] + coverage["opaque_node_count"]
        or coverage["code_bytes"] != audit["source"]["code_size"]
    ):
        raise RegisteredDefinitionCallCompileError(
            "MES registered-definition call compile coverage changed"
        )
    invariants = audit.get("invariants")
    if (
        not isinstance(invariants, dict)
        or set(invariants) != INVARIANT_KEYS
        or not all(value is True for value in invariants.values())
    ):
        raise RegisteredDefinitionCallCompileError(
            "MES registered-definition call compile invariants changed"
        )
    source = audit["source"]
    output_row = audit["output"]
    if (
        output_row["size"] != source["size"]
        or output_row["entry_count"] != source["entry_count"]
        or output_row["code_offset"] != source["code_offset"]
        or output_row["code_size"] != source["code_size"]
        or output_row["preamble_sha256"] != source["preamble_sha256"]
        or output_row["address_table_sha256"] != source["address_table_sha256"]
    ):
        raise RegisteredDefinitionCallCompileError(
            "MES registered-definition call compile layout identity changed"
        )
    supplied = (
        editable_document, call_family_proof, registry_proof, plan_document, output
    )
    if any(value is not None for value in supplied):
        if any(value is None for value in supplied):
            raise RegisteredDefinitionCallCompileError(
                "MES registered-definition call compile validation inputs are incomplete"
            )
        expected_output, expected_audit = compile_registered_definition_call(
            editable_document, call_family_proof, registry_proof, plan_document
        )
        if expected_output != output or expected_audit != audit:
            raise RegisteredDefinitionCallCompileError(
                "MES registered-definition call compile audit differs from its source"
            )
    return {"ok": True, "schema": AUDIT_SCHEMA, "payload_sha256": retained}


def _valid_target(value: Any, operation: dict[str, Any]) -> bool:
    if (
        not isinstance(value, dict)
        or set(value) != TARGET_KEYS
        or any(
            not isinstance(value.get(key), str) or not value[key]
            for key in ("node_id", "region_id", "resume_node_id", "resume_region_id")
        )
        or any(
            not _is_nonnegative_int(value.get(key))
            for key in (
                "instruction_start", "instruction_end", "literal_start",
                "literal_end", "resume_start", "resume_end",
            )
        )
        or any(
            not _is_sha256(value.get(key))
            for key in (
                "resume_raw_sha256", "source_instruction_sha256",
                "replacement_instruction_sha256", "source_expression_sha256",
                "replacement_expression_sha256", "source_literal_sha256",
                "replacement_literal_sha256",
            )
        )
        or not isinstance(value.get("call_proof"), dict)
        or set(value["call_proof"]) != call_planner.CALL_PROOF_KEYS
        or value["instruction_start"] != operation["source_offset"]
        or value["instruction_end"] != value["instruction_start"] + 5
        or value["literal_start"] != value["instruction_start"] + 2
        or value["instruction_end"] != operation["physical_resume_offset"]
        or value["resume_start"] != operation["physical_resume_offset"]
        or value["literal_end"] != value["literal_start"] + 1
        or value["resume_end"] <= value["resume_start"]
        or value["call_proof"].get("selector") != operation["source_selector"]
        or value["call_proof"].get("call_start") != value["instruction_start"]
        or value["call_proof"].get("call_end") != value["instruction_end"]
        or value["call_proof"].get("physical_resume_offset") != value["resume_start"]
        or value["call_proof"].get("physical_resume_node_id")
        != value["resume_node_id"]
        or value["call_proof"].get("physical_resume_region")
        != value["resume_region_id"]
        or value["call_proof"].get("physical_resume_raw_sha256")
        != value["resume_raw_sha256"]
        or value["call_proof"].get("proof_status")
        != "typed_registered_selector_and_exact_physical_resume"
        or value["call_proof"].get("native_role")
        != "registered_definition_lookup_call_and_restore"
        or value["call_proof"].get("registry_binding_status")
        != "source_and_replacement_exact_body_boundaries_supplied"
        or value["call_proof"].get("return_edge")
        != "unproved_registered_body_total_return_not_supplied"
    ):
        return False
    for key, selector in (
        ("source_registry_binding", operation["source_selector"]),
        ("replacement_registry_binding", operation["replacement_selector"]),
    ):
        binding = value.get(key)
        if not _valid_registry_binding(binding, selector):
            return False
    return True


def _valid_registry_binding(value: Any, selector: int) -> bool:
    integer_keys = {
        "selector", "registration_start", "registration_end", "selector_start",
        "selector_end", "expression_start", "expression_end", "body_start",
        "body_end", "body_size", "skip_target",
    }
    return (
        isinstance(value, dict)
        and set(value) == registry_prover.REGISTRATION_KEYS
        and all(_is_nonnegative_int(value.get(key)) for key in integer_keys)
        and value["selector"] == selector
        and value["selector"] <= 0x7F
        and value["registration_end"] == value["body_start"]
        and value["body_end"] == value["skip_target"]
        and value["body_size"] == value["body_end"] - value["body_start"]
        and value["body_size"] > 0
        and value["registration_start"] < value["selector_start"]
        and value["selector_end"] == value["selector_start"] + 1
        and value["expression_start"] == value["selector_start"]
        and value["expression_end"] == value["selector_end"] + 1
        and value["expression_end"] <= value["registration_end"]
        and all(
            _is_sha256(value.get(key))
            for key in (
                "registration_raw_sha256", "selector_raw_sha256",
                "expression_raw_sha256", "body_raw_sha256",
            )
        )
        and value.get("body_execution") == "not_performed"
        and value.get("proof_status")
        == "literal_command14_registration_with_exact_body_boundary"
    )


def _resume_node(source_ir: dict[str, Any], call_proof: dict[str, Any]) -> dict[str, Any]:
    matches = [
        node for node in source_ir["nodes"]
        if node.get("id") == call_proof.get("physical_resume_node_id")
        and node.get("source", {}).get("start") == call_proof.get("physical_resume_offset")
        and node.get("source", {}).get("raw_sha256")
        == call_proof.get("physical_resume_raw_sha256")
    ]
    if len(matches) != 1:
        raise RegisteredDefinitionCallCompileError(
            "MES registered-definition call compile physical resume node changed"
        )
    return matches[0]


def _container_summary(raw: bytes, header: dict[str, Any]) -> dict[str, Any]:
    code_offset = int(header["code_offset"])
    code = raw[code_offset:]
    return {
        "size": len(raw),
        "entry_count": int(header["entry_count"]),
        "code_offset": code_offset,
        "code_size": len(code),
        "entry_sha256": hashlib.sha256(raw).hexdigest(),
        "bytecode_sha256": hashlib.sha256(code).hexdigest(),
        "preamble_sha256": hashlib.sha256(raw[:code_offset]).hexdigest(),
        "address_table_sha256": hashlib.sha256(raw[4:code_offset]).hexdigest(),
    }


def _valid_summary(value: Any) -> bool:
    return (
        isinstance(value, dict)
        and set(value) == SUMMARY_KEYS
        and all(
            _is_nonnegative_int(value.get(key))
            for key in ("size", "entry_count", "code_offset", "code_size")
        )
        and all(
            _is_sha256(value.get(key))
            for key in (
                "entry_sha256", "bytecode_sha256", "preamble_sha256",
                "address_table_sha256",
            )
        )
        and value["size"] == value["code_offset"] + value["code_size"]
    )


def _hex_bytes(value: Any, label: str) -> bytes:
    if not isinstance(value, str) or not value or len(value) % 2 != 0:
        raise RegisteredDefinitionCallCompileError(
            f"MES registered-definition call compile {label} is invalid"
        )
    try:
        return bytes.fromhex(value)
    except ValueError as error:
        raise RegisteredDefinitionCallCompileError(
            f"MES registered-definition call compile {label} is invalid"
        ) from error


def _is_nonnegative_int(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value >= 0


def main() -> None:
    parser = argparse.ArgumentParser(
        description=(
            "Compile one validated same-width command-0x11 registered-definition "
            "literal edit into a new MES container and compact audit."
        )
    )
    parser.add_argument("editable_ir", type=Path)
    parser.add_argument("call_family_proof", type=Path)
    parser.add_argument("registry_proof", type=Path)
    parser.add_argument("plan", type=Path)
    parser.add_argument("output_mes", type=Path)
    parser.add_argument("audit_output", type=Path)
    args = parser.parse_args()
    paths = [
        args.editable_ir.resolve(), args.call_family_proof.resolve(),
        args.registry_proof.resolve(), args.plan.resolve(), args.output_mes.resolve(),
        args.audit_output.resolve(),
    ]
    if len(set(paths)) != len(paths):
        raise RegisteredDefinitionCallCompileError(
            "MES registered-definition call compile paths must differ"
        )
    if args.output_mes.exists() or args.audit_output.exists():
        raise RegisteredDefinitionCallCompileError(
            "MES registered-definition call compile output already exists"
        )
    try:
        editable_document = json.loads(args.editable_ir.read_text(encoding="utf-8"))
        call_family_proof = json.loads(
            args.call_family_proof.read_text(encoding="utf-8")
        )
        registry_proof = json.loads(args.registry_proof.read_text(encoding="utf-8"))
        plan_document = json.loads(args.plan.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise RegisteredDefinitionCallCompileError(
            "MES registered-definition call compile input JSON could not be read"
        ) from error
    if not all(
        isinstance(value, dict)
        for value in (
            editable_document, call_family_proof, registry_proof, plan_document,
        )
    ):
        raise RegisteredDefinitionCallCompileError(
            "MES registered-definition call compile inputs must be JSON objects"
        )
    output, audit = compile_registered_definition_call(
        editable_document, call_family_proof, registry_proof, plan_document
    )
    audit_bytes = editable_ir.canonical_json_bytes(audit) + b"\n"
    published_mes = False
    published_audit = False
    try:
        editable_ir.publish_new(args.output_mes, output)
        published_mes = True
        editable_ir.publish_new(args.audit_output, audit_bytes)
        published_audit = True
        reopened_audit = json.loads(args.audit_output.read_text(encoding="utf-8"))
        validate_audit(
            reopened_audit, editable_document, call_family_proof, registry_proof,
            plan_document, args.output_mes.read_bytes(),
        )
    except BaseException:
        if published_audit and args.audit_output.is_file():
            args.audit_output.unlink()
        if published_mes and args.output_mes.is_file():
            args.output_mes.unlink()
        raise
    print(
        "MES_REGISTERED_DEFINITION_CALL_COMPILE_PASS "
        f"schema={audit['schema']} "
        f"entry={audit['source_identity'].get('entry', '')} "
        f"offset={audit['target']['instruction_start']} "
        f"source_selector={audit['operation']['source_selector']} "
        f"replacement_selector={audit['operation']['replacement_selector']} "
        f"resume={audit['operation']['physical_resume_offset']} "
        f"bytes={audit['output']['size']} "
        f"payload_sha256={audit['payload_sha256']}"
    )


if __name__ == "__main__":
    main()
