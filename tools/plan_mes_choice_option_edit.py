from __future__ import annotations

import argparse
import copy
import hashlib
import json
from pathlib import Path
from typing import Any

from mes_archive_ir import load_archive_entry, parse_mes_container
import prove_mes_choice_group_authoring as choice_prover
from payload_values import (
    canonical_payload_bytes,
    fingerprint,
    is_sha256 as _is_sha256,
    sha256_file as _sha256_file,
)


PLAN_SCHEMA = "kakyu_mes_choice_option_edit_plan/v1"
TOP_LEVEL_KEYS = {
    "ok", "schema", "producer", "compatibility", "source_identity",
    "inputs", "operation", "target", "replacement", "retained_contract",
    "assembly_ready", "invariants", "payload_sha256",
}
OPERATION_KEYS = {
    "kind", "group_selector", "definition_id", "source_payload_sha256",
    "text", "encoding",
}
TARGET_KEYS = {
    "group_selector", "definition_id", "registration_start",
    "registration_end", "registration_raw_sha256", "body_start", "body_end",
    "body_raw_hex", "body_raw_sha256", "instruction_start", "instruction_end",
    "instruction_raw_hex", "instruction_raw_sha256", "payload_start",
    "payload_end", "payload_size", "payload_raw_hex", "payload_raw_sha256",
    "terminator_offset", "terminator", "return_start", "return_end",
    "return_raw_hex", "return_raw_sha256", "guard_sha256",
}
REPLACEMENT_KEYS = {
    "text", "encoding", "payload_size", "payload_raw_hex",
    "payload_raw_sha256", "instruction_raw_hex", "instruction_raw_sha256",
    "body_raw_hex", "body_raw_sha256", "byte_delta", "output_entry_sha256",
    "output_bytecode_sha256",
}
RETAINED_KEYS = {
    "choice_proof_sha256", "address_entry_index", "address_entry_start",
    "address_entry_end", "groups_sha256", "result_mapping_sha256",
    "terminal_start", "terminal_end", "terminal_raw_sha256",
    "physical_resume_start", "physical_resume_end",
    "physical_resume_raw_sha256", "source_prefix_sha256",
    "source_suffix_sha256", "all_bytes_outside_payload_unchanged",
    "all_coordinates_unchanged", "native_input_and_gameplay_labels",
}
SOURCE_IDENTITY_KEYS = {"archive", "archive_sha256", "entry", "entry_sha256"}
COMPATIBILITY = {
    "policy": "planning_only_source_bound_same_length_choice_option_replacement",
    "input_choice_proof_schema": choice_prover.SCHEMA,
    "supported_operation": "replace_choice_option_cp932_same_length",
    "supported_instruction": {"command_id": 0x01, "body_shape": "message_then_return"},
    "encoding": "cp932",
    "length_policy": "replacement_payload_must_match_source_length",
    "coordinate_policy": "zero_delta_all_source_coordinates_retained",
    "result_mapping_policy": "exact_choice_proof_fingerprint_retained",
    "native_input_and_gameplay_labels": "unresolved",
    "binary_publication": "forbidden",
    "unknown_plan_schema": "reject",
    "unknown_v1_field": "reject",
}
INVARIANTS = {
    "source_choice_proof_rebuilt": True,
    "target_group_and_definition_unique": True,
    "target_is_one_strict_cp932_message_then_return": True,
    "source_payload_hash_matched": True,
    "replacement_cp932_strict_and_same_length": True,
    "registration_target_unchanged": True,
    "definition_return_unchanged": True,
    "group_topology_unchanged": True,
    "result_mapping_unchanged": True,
    "routine40_terminal_and_physical_resume_unchanged": True,
    "all_other_entry_bytes_unchanged": True,
    "native_input_not_executed": True,
    "binary_not_published": True,
}


class ChoiceOptionEditPlanError(ValueError):
    pass


def plan(
    source_payload: bytes,
    choice_proof: dict[str, Any],
    operation: dict[str, Any],
) -> dict[str, Any]:
    document = _build_plan(source_payload, choice_proof, operation)
    document["payload_sha256"] = fingerprint(document)
    validate(document, source_payload, choice_proof)
    return document


def validate(
    document: dict[str, Any],
    source_payload: bytes | None = None,
    choice_proof: dict[str, Any] | None = None,
) -> dict[str, Any]:
    if (
        document.get("ok") is not True
        or document.get("schema") != PLAN_SCHEMA
        or set(document) != TOP_LEVEL_KEYS
    ):
        raise ChoiceOptionEditPlanError(
            "MES choice-option edit plan schema or fields changed"
        )
    if document.get("producer") != {
        "implementation": "python_phase6_choice_option_edit_planner",
        "contract": PLAN_SCHEMA,
    }:
        raise ChoiceOptionEditPlanError("MES choice-option edit producer changed")
    if document.get("compatibility") != COMPATIBILITY:
        raise ChoiceOptionEditPlanError("MES choice-option compatibility changed")
    retained_hash = document.get("payload_sha256")
    if not _is_sha256(retained_hash) or fingerprint(document) != retained_hash:
        raise ChoiceOptionEditPlanError("MES choice-option plan fingerprint changed")
    source_identity = document.get("source_identity")
    if (
        not isinstance(source_identity, dict)
        or set(source_identity) != SOURCE_IDENTITY_KEYS
        or Path(str(source_identity.get("archive", ""))).name
        != source_identity.get("archive")
        or Path(str(source_identity.get("entry", ""))).name
        != source_identity.get("entry")
        or not _is_sha256(source_identity.get("archive_sha256"))
        or not _is_sha256(source_identity.get("entry_sha256"))
    ):
        raise ChoiceOptionEditPlanError("MES choice-option source identity changed")
    inputs = document.get("inputs")
    if (
        not isinstance(inputs, dict)
        or set(inputs) != {"choice_proof_sha256"}
        or not _is_sha256(inputs.get("choice_proof_sha256"))
    ):
        raise ChoiceOptionEditPlanError("MES choice-option input identity changed")
    operation = _validate_operation(document.get("operation"))
    target = document.get("target")
    replacement = document.get("replacement")
    retained = document.get("retained_contract")
    if not _valid_target(target, operation):
        raise ChoiceOptionEditPlanError("MES choice-option target boundary changed")
    if not _valid_replacement(replacement, target, operation):
        raise ChoiceOptionEditPlanError("MES choice-option replacement bytes changed")
    if not _valid_retained(retained, inputs):
        raise ChoiceOptionEditPlanError("MES choice-option retained contract changed")
    if document.get("assembly_ready") is not True:
        raise ChoiceOptionEditPlanError("MES choice-option plan is not assembly ready")
    if document.get("invariants") != INVARIANTS:
        raise ChoiceOptionEditPlanError("MES choice-option invariants changed")
    supplied = (source_payload, choice_proof)
    if any(value is not None for value in supplied):
        if any(value is None for value in supplied):
            raise ChoiceOptionEditPlanError(
                "MES choice-option source validation inputs are incomplete"
            )
        expected = _build_plan(source_payload, choice_proof, copy.deepcopy(operation))
        expected["payload_sha256"] = fingerprint(expected)
        if expected != document:
            raise ChoiceOptionEditPlanError(
                "MES choice-option edit plan differs from its source"
            )
    return {"ok": True, "schema": PLAN_SCHEMA, "payload_sha256": retained_hash}


def _build_plan(
    source_payload: bytes,
    choice_proof: dict[str, Any],
    raw_operation: dict[str, Any],
) -> dict[str, Any]:
    operation = _validate_operation(raw_operation)
    proof_source = choice_proof.get("source_identity", {})
    boundary = choice_proof.get("boundary", {})
    choice_prover.validate(
        choice_proof,
        source_payload,
        {
            "archive": proof_source.get("archive"),
            "archive_sha256": proof_source.get("archive_sha256"),
            "entry": proof_source.get("entry"),
        },
        boundary.get("address_entry_index"),
    )
    matches = []
    for group in choice_proof["groups"]:
        if group["selector"] != operation["group_selector"]:
            continue
        matches.extend(
            definition
            for definition in group["definitions"]
            if definition["definition_id"] == operation["definition_id"]
        )
    if len(matches) != 1:
        raise ChoiceOptionEditPlanError(
            "MES choice-option target is not one unique grouped definition"
        )
    definition = matches[0]
    message = definition["message"]
    if message["payload_raw_sha256"] != operation["source_payload_sha256"]:
        raise ChoiceOptionEditPlanError("MES choice-option source payload hash is stale")
    container = parse_mes_container(source_payload, proof_source)
    code_offset = int(container["header"]["codeOffset"])
    code = source_payload[code_offset:]
    payload_start = int(message["payload_start"])
    payload_end = int(message["payload_end"])
    source_raw = code[payload_start:payload_end]
    if (
        len(source_raw) != int(message["payload_size"])
        or hashlib.sha256(source_raw).hexdigest() != message["payload_raw_sha256"]
    ):
        raise ChoiceOptionEditPlanError("MES choice-option source payload boundary changed")
    try:
        source_raw.decode("cp932", errors="strict")
    except UnicodeDecodeError as error:
        raise ChoiceOptionEditPlanError(
            "MES choice-option source payload is not strict CP932"
        ) from error
    replacement_raw = _encode_replacement(operation["text"])
    if replacement_raw == source_raw:
        raise ChoiceOptionEditPlanError("MES choice-option replacement is unchanged")
    if len(replacement_raw) != len(source_raw):
        raise ChoiceOptionEditPlanError(
            "MES choice-option v1 replacement must keep the exact payload length"
        )
    instruction_start = int(message["instruction_start"])
    instruction_end = int(message["instruction_end"])
    body_start = int(definition["body"]["start"])
    body_end = int(definition["body"]["end"])
    registration_start = int(definition["registration"]["start"])
    registration_end = int(definition["registration"]["end"])
    return_start = int(definition["return_record"]["start"])
    return_end = int(definition["return_record"]["end"])
    instruction_raw = code[instruction_start:instruction_end]
    body_raw = code[body_start:body_end]
    registration_raw = code[registration_start:registration_end]
    return_raw = code[return_start:return_end]
    if (
        instruction_raw != b"\x01" + source_raw + b"\x00"
        or body_start != instruction_start
        or instruction_end != return_start
        or body_raw != instruction_raw + return_raw
        or hashlib.sha256(instruction_raw).hexdigest()
        != message["instruction_raw_sha256"]
        or hashlib.sha256(body_raw).hexdigest() != definition["body"]["raw_sha256"]
        or hashlib.sha256(registration_raw).hexdigest()
        != definition["registration"]["raw_sha256"]
        or hashlib.sha256(return_raw).hexdigest()
        != definition["return_record"]["raw_sha256"]
    ):
        raise ChoiceOptionEditPlanError("MES choice-option definition bytes changed")
    replacement_instruction = b"\x01" + replacement_raw + b"\x00"
    replacement_body = replacement_instruction + return_raw
    absolute_start = code_offset + payload_start
    absolute_end = code_offset + payload_end
    output_payload = (
        source_payload[:absolute_start] + replacement_raw + source_payload[absolute_end:]
    )
    output_code = output_payload[code_offset:]
    guard_hash = hashlib.sha256(
        json.dumps(
            definition["guard"], ensure_ascii=False, allow_nan=False,
            sort_keys=True, separators=(",", ":"),
        ).encode("utf-8")
    ).hexdigest()
    return {
        "ok": True,
        "schema": PLAN_SCHEMA,
        "producer": {
            "implementation": "python_phase6_choice_option_edit_planner",
            "contract": PLAN_SCHEMA,
        },
        "compatibility": copy.deepcopy(COMPATIBILITY),
        "source_identity": copy.deepcopy(proof_source),
        "inputs": {"choice_proof_sha256": choice_proof["payload_sha256"]},
        "operation": copy.deepcopy(operation),
        "target": {
            "group_selector": operation["group_selector"],
            "definition_id": operation["definition_id"],
            "registration_start": registration_start,
            "registration_end": registration_end,
            "registration_raw_sha256": hashlib.sha256(registration_raw).hexdigest(),
            "body_start": body_start,
            "body_end": body_end,
            "body_raw_hex": body_raw.hex(),
            "body_raw_sha256": hashlib.sha256(body_raw).hexdigest(),
            "instruction_start": instruction_start,
            "instruction_end": instruction_end,
            "instruction_raw_hex": instruction_raw.hex(),
            "instruction_raw_sha256": hashlib.sha256(instruction_raw).hexdigest(),
            "payload_start": payload_start,
            "payload_end": payload_end,
            "payload_size": len(source_raw),
            "payload_raw_hex": source_raw.hex(),
            "payload_raw_sha256": hashlib.sha256(source_raw).hexdigest(),
            "terminator_offset": int(message["terminator_offset"]),
            "terminator": int(message["terminator"]),
            "return_start": return_start,
            "return_end": return_end,
            "return_raw_hex": return_raw.hex(),
            "return_raw_sha256": hashlib.sha256(return_raw).hexdigest(),
            "guard_sha256": guard_hash,
        },
        "replacement": {
            "text": operation["text"],
            "encoding": "cp932",
            "payload_size": len(replacement_raw),
            "payload_raw_hex": replacement_raw.hex(),
            "payload_raw_sha256": hashlib.sha256(replacement_raw).hexdigest(),
            "instruction_raw_hex": replacement_instruction.hex(),
            "instruction_raw_sha256": hashlib.sha256(replacement_instruction).hexdigest(),
            "body_raw_hex": replacement_body.hex(),
            "body_raw_sha256": hashlib.sha256(replacement_body).hexdigest(),
            "byte_delta": 0,
            "output_entry_sha256": hashlib.sha256(output_payload).hexdigest(),
            "output_bytecode_sha256": hashlib.sha256(output_code).hexdigest(),
        },
        "retained_contract": {
            "choice_proof_sha256": choice_proof["payload_sha256"],
            "address_entry_index": int(boundary["address_entry_index"]),
            "address_entry_start": int(boundary["address_entry_start"]),
            "address_entry_end": int(boundary["address_entry_end"]),
            "groups_sha256": _subtree_hash(choice_proof["groups"]),
            "result_mapping_sha256": _subtree_hash(choice_proof["result_mapping"]),
            "terminal_start": int(boundary["terminal_start"]),
            "terminal_end": int(boundary["terminal_end"]),
            "terminal_raw_sha256": str(boundary["terminal_raw_sha256"]),
            "physical_resume_start": int(boundary["physical_resume_start"]),
            "physical_resume_end": int(boundary["physical_resume_end"]),
            "physical_resume_raw_sha256": str(
                boundary["physical_resume_raw_sha256"]
            ),
            "source_prefix_sha256": hashlib.sha256(
                source_payload[:absolute_start]
            ).hexdigest(),
            "source_suffix_sha256": hashlib.sha256(
                source_payload[absolute_end:]
            ).hexdigest(),
            "all_bytes_outside_payload_unchanged": True,
            "all_coordinates_unchanged": True,
            "native_input_and_gameplay_labels": "unresolved",
        },
        "assembly_ready": True,
        "invariants": copy.deepcopy(INVARIANTS),
    }


def _validate_operation(value: Any) -> dict[str, Any]:
    if not isinstance(value, dict) or set(value) != OPERATION_KEYS:
        raise ChoiceOptionEditPlanError("MES choice-option operation fields changed")
    if value.get("kind") != "replace_choice_option_cp932_same_length":
        raise ChoiceOptionEditPlanError("MES choice-option operation kind changed")
    if value.get("encoding") != "cp932":
        raise ChoiceOptionEditPlanError("MES choice-option encoding changed")
    if not _is_nonnegative_int(value.get("group_selector")):
        raise ChoiceOptionEditPlanError("MES choice-option group selector changed")
    if not _is_nonnegative_int(value.get("definition_id")):
        raise ChoiceOptionEditPlanError("MES choice-option definition id changed")
    if not _is_sha256(value.get("source_payload_sha256")):
        raise ChoiceOptionEditPlanError("MES choice-option source hash changed")
    if not isinstance(value.get("text"), str) or not value["text"]:
        raise ChoiceOptionEditPlanError("MES choice-option replacement text is empty")
    return copy.deepcopy(value)


def _valid_target(value: Any, operation: dict[str, Any]) -> bool:
    if not isinstance(value, dict) or set(value) != TARGET_KEYS:
        return False
    integers = {
        "group_selector", "definition_id", "registration_start",
        "registration_end", "body_start", "body_end", "instruction_start",
        "instruction_end", "payload_start", "payload_end", "payload_size",
        "terminator_offset", "terminator", "return_start", "return_end",
    }
    if any(not _is_nonnegative_int(value.get(key)) for key in integers):
        return False
    hex_keys = {
        "body_raw_hex", "instruction_raw_hex", "payload_raw_hex", "return_raw_hex"
    }
    raw = {key: _hex_bytes(value.get(key)) for key in hex_keys}
    if any(item is None for item in raw.values()):
        return False
    if any(
        not _is_sha256(value.get(key))
        for key in (
            "registration_raw_sha256", "body_raw_sha256",
            "instruction_raw_sha256", "payload_raw_sha256",
            "return_raw_sha256", "guard_sha256",
        )
    ):
        return False
    body = raw["body_raw_hex"]
    instruction = raw["instruction_raw_hex"]
    payload = raw["payload_raw_hex"]
    return_raw = raw["return_raw_hex"]
    return (
        value["group_selector"] == operation["group_selector"]
        and value["definition_id"] == operation["definition_id"]
        and value["payload_raw_sha256"] == operation["source_payload_sha256"]
        and value["payload_size"] == len(payload)
        and value["payload_end"] - value["payload_start"] == len(payload)
        and value["instruction_start"] + 1 == value["payload_start"]
        and value["payload_end"] == value["terminator_offset"]
        and value["instruction_end"] == value["terminator_offset"] + 1
        and value["terminator"] == 0
        and value["body_start"] == value["instruction_start"]
        and value["instruction_end"] == value["return_start"]
        and value["body_end"] == value["return_end"]
        and instruction == b"\x01" + payload + b"\x00"
        and body == instruction + return_raw
        and hashlib.sha256(body).hexdigest() == value["body_raw_sha256"]
        and hashlib.sha256(instruction).hexdigest()
        == value["instruction_raw_sha256"]
        and hashlib.sha256(payload).hexdigest() == value["payload_raw_sha256"]
        and hashlib.sha256(return_raw).hexdigest() == value["return_raw_sha256"]
    )


def _valid_replacement(
    value: Any,
    target: dict[str, Any],
    operation: dict[str, Any],
) -> bool:
    if not isinstance(value, dict) or set(value) != REPLACEMENT_KEYS:
        return False
    raw = {
        key: _hex_bytes(value.get(key))
        for key in ("payload_raw_hex", "instruction_raw_hex", "body_raw_hex")
    }
    if any(item is None for item in raw.values()):
        return False
    if any(
        not _is_sha256(value.get(key))
        for key in (
            "payload_raw_sha256", "instruction_raw_sha256", "body_raw_sha256",
            "output_entry_sha256", "output_bytecode_sha256",
        )
    ):
        return False
    payload = raw["payload_raw_hex"]
    instruction = raw["instruction_raw_hex"]
    body = raw["body_raw_hex"]
    return_raw = _hex_bytes(target.get("return_raw_hex"))
    if return_raw is None:
        return False
    try:
        encoded = operation["text"].encode("cp932", errors="strict")
    except UnicodeEncodeError:
        return False
    return (
        value["text"] == operation["text"]
        and value["encoding"] == "cp932"
        and value["byte_delta"] == 0
        and value["payload_size"] == target["payload_size"] == len(payload)
        and payload == encoded
        and payload != _hex_bytes(target["payload_raw_hex"])
        and b"\x00" not in payload
        and instruction == b"\x01" + payload + b"\x00"
        and body == instruction + return_raw
        and hashlib.sha256(payload).hexdigest() == value["payload_raw_sha256"]
        and hashlib.sha256(instruction).hexdigest()
        == value["instruction_raw_sha256"]
        and hashlib.sha256(body).hexdigest() == value["body_raw_sha256"]
    )


def _valid_retained(value: Any, inputs: dict[str, Any]) -> bool:
    if not isinstance(value, dict) or set(value) != RETAINED_KEYS:
        return False
    integer_keys = {
        "address_entry_index", "address_entry_start", "address_entry_end",
        "terminal_start", "terminal_end", "physical_resume_start",
        "physical_resume_end",
    }
    hash_keys = {
        "choice_proof_sha256", "groups_sha256", "result_mapping_sha256",
        "terminal_raw_sha256", "physical_resume_raw_sha256",
        "source_prefix_sha256", "source_suffix_sha256",
    }
    return (
        all(_is_nonnegative_int(value.get(key)) for key in integer_keys)
        and all(_is_sha256(value.get(key)) for key in hash_keys)
        and value["choice_proof_sha256"] == inputs["choice_proof_sha256"]
        and value["address_entry_end"] > value["address_entry_start"]
        and value["terminal_end"] > value["terminal_start"]
        and value["terminal_end"] == value["physical_resume_start"]
        and value["physical_resume_end"] > value["physical_resume_start"]
        and value["all_bytes_outside_payload_unchanged"] is True
        and value["all_coordinates_unchanged"] is True
        and value["native_input_and_gameplay_labels"] == "unresolved"
    )


def _encode_replacement(text: str) -> bytes:
    try:
        encoded = text.encode("cp932", errors="strict")
    except UnicodeEncodeError as error:
        raise ChoiceOptionEditPlanError(
            "MES choice-option replacement is not representable in CP932"
        ) from error
    if not encoded or b"\x00" in encoded:
        raise ChoiceOptionEditPlanError(
            "MES choice-option replacement contains an invalid terminator"
        )
    return encoded


def _subtree_hash(value: Any) -> str:
    return hashlib.sha256(
        json.dumps(
            value, ensure_ascii=False, allow_nan=False, sort_keys=True,
            separators=(",", ":"),
        ).encode("utf-8")
    ).hexdigest()


def _hex_bytes(value: Any) -> bytes | None:
    if not isinstance(value, str) or len(value) % 2:
        return None
    try:
        return bytes.fromhex(value)
    except ValueError:
        return None


def _is_nonnegative_int(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value >= 0


def _load_json_object(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ChoiceOptionEditPlanError(f"{path.name} is not a JSON object")
    return value


def main() -> None:
    parser = argparse.ArgumentParser(
        description=(
            "Plan one exact same-length CP932 command-0x10 choice-option edit "
            "without publishing MES bytes."
        )
    )
    parser.add_argument("archive", type=Path)
    parser.add_argument("entry")
    parser.add_argument("choice_proof", type=Path)
    parser.add_argument("operation", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    archive = args.archive.resolve()
    proof_path = args.choice_proof.resolve()
    operation_path = args.operation.resolve()
    output = args.output.resolve()
    if (
        output == archive
        or output == proof_path
        or output == operation_path
        or output == archive.parent
        or archive.parent in output.parents
        or output.exists()
    ):
        raise ChoiceOptionEditPlanError(
            "MES choice-option plan output must be a new path outside the source directory"
        )
    payload, _source = load_archive_entry(archive, args.entry)
    proof = _load_json_object(proof_path)
    operation = _load_json_object(operation_path)
    proof_source = proof.get("source_identity", {})
    if (
        proof_source.get("archive") != archive.name
        or proof_source.get("archive_sha256") != _sha256_file(archive)
        or proof_source.get("entry") != args.entry
    ):
        raise ChoiceOptionEditPlanError(
            "MES choice-option CLI source differs from the choice proof"
        )
    document = plan(payload, proof, operation)
    encoded = json.dumps(
        document, ensure_ascii=False, allow_nan=False, sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8") + b"\n"
    temporary = output.with_name(output.name + ".tmp")
    output.parent.mkdir(parents=True, exist_ok=True)
    try:
        with temporary.open("xb") as destination:
            destination.write(encoded)
        temporary.replace(output)
    except BaseException:
        if temporary.is_file():
            temporary.unlink()
        raise
    print(
        "MES_CHOICE_OPTION_EDIT_PLAN_PASS "
        f"schema={PLAN_SCHEMA} entry={document['source_identity']['entry']} "
        f"group={document['target']['group_selector']} "
        f"definition={document['target']['definition_id']} "
        f"payload_size={document['target']['payload_size']} "
        f"output_entry_sha256={document['replacement']['output_entry_sha256']} "
        f"payload_sha256={document['payload_sha256']}"
    )


if __name__ == "__main__":
    main()
