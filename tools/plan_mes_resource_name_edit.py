from __future__ import annotations

import argparse
import copy
import hashlib
import json
from pathlib import Path
from typing import Any

import prepare_mes_editable_ir as editable_ir
from payload_values import canonical_payload_bytes, fingerprint, is_sha256 as _is_sha256


PLAN_SCHEMA = "kakyu_mes_resource_name_edit_plan/v1"
TOP_LEVEL_KEYS = {
    "ok", "schema", "producer", "compatibility", "source_identity", "inputs",
    "operation", "target", "replacement", "assembly_ready", "invariants",
    "payload_sha256",
}
OPERATION_KEYS = {
    "kind", "source_offset", "instruction_raw_sha256", "reference_id", "name",
}
TARGET_KEYS = {
    "node_id", "region_id", "op", "command_id", "instruction_start",
    "instruction_end", "instruction_raw_hex", "instruction_raw_sha256",
    "reference_id", "reference_boundary", "resource_kind", "archive_candidates",
    "operand_resource_kind", "source_name", "normalized_name", "extension",
    "name_start", "name_end", "name_raw_hex", "name_raw_sha256",
    "prefix_raw_hex", "prefix_raw_sha256", "suffix_raw_hex", "suffix_raw_sha256",
}
REPLACEMENT_KEYS = {
    "source_name", "normalized_name", "extension", "name_raw_hex",
    "name_raw_sha256", "instruction_raw_hex", "instruction_raw_sha256",
}
SOURCE_IDENTITY_KEYS = {"archive", "entry", "source_kind", "archive_sha256"}
SUPPORTED_RESOURCES = {
    "mmo_resource_marker": {
        # 0x0D framing since Core 0.316.0; formerly a separator plus a 0x09 record.
        "command_id": 0x0D,
        "resource_kind": "mmo",
        "operand_resource_kind": "mmo_marker",
        "extensions": ["mmo"],
        "normalization": "identity",
        "prefix_hex": "0d09ff01",
        "suffix_hex": "0000",
    },
    "ax_resource_marker": {
        "command_id": 0x0D,
        "resource_kind": "ax",
        "operand_resource_kind": "ax_marker",
        "extensions": ["ax"],
        "normalization": "uppercase_basename_and_extension",
        "prefix_hex": "0d08ff0200ff01",
        "suffix_hex": "000202f900ff00",
    },
    "voice_marker": {
        "command_id": 0x0D,
        "resource_kind": "voice",
        "operand_resource_kind": "voice_marker",
        "extensions": ["ogg"],
        "normalization": "uppercase_basename_and_extension",
        "prefix_hex": "0d07ff0202ff01",
        "suffix_hex": "000200ff00",
    },
}
COMPATIBILITY = {
    "policy": "planning_only_same_length_typed_resource_name_replacement",
    "input_editable_schema": editable_ir.EDITABLE_IR_SCHEMA,
    "input_decompiler_schema": "kakyu_mes_decompiler_ir/v1",
    "supported_operation": "replace_resource_name",
    "supported_resources": copy.deepcopy(SUPPORTED_RESOURCES),
    "selection_policy": "one_exact_strict_indexed_resource_reference",
    "name_policy": "printable_ascii_safe_entry_name_and_matching_extension",
    "length_policy": "replacement_name_must_match_source_byte_length",
    "numeric_operand_policy": "preserve_all_non_name_bytes_without_new_semantic_labels",
    "inline_script_policy": "deferred_to_nested_call_authoring",
    "binary_publication": "forbidden",
    "native_engine_compatibility": "unverified",
    "unknown_plan_schema": "reject",
    "unknown_v1_field": "reject",
}
INVARIANTS = {
    "source_editable_ir_validated": True,
    "target_node_unique_and_typed": True,
    "source_instruction_hash_matched": True,
    "resource_reference_unique_strict_and_indexed": True,
    "source_name_bytes_match_typed_operand": True,
    "replacement_name_same_length_and_extension": True,
    "prefix_suffix_and_numeric_bytes_unchanged": True,
    "opaque_bytes_not_rewritten": True,
    "binary_not_published": True,
}


class ResourceNameEditPlanError(ValueError):
    pass


def plan(
    editable_document: dict[str, Any], operation: dict[str, Any]
) -> dict[str, Any]:
    result = _build_plan(editable_document, operation)
    result["payload_sha256"] = fingerprint(result)
    validate(result, editable_document)
    return result


def validate(
    document: dict[str, Any], editable_document: dict[str, Any] | None = None
) -> dict[str, Any]:
    if (
        document.get("ok") is not True
        or document.get("schema") != PLAN_SCHEMA
        or set(document) != TOP_LEVEL_KEYS
    ):
        raise ResourceNameEditPlanError(
            "MES resource name edit plan schema or fields changed"
        )
    if document.get("producer") != {
        "implementation": "python_phase6_resource_name_edit_planner",
        "contract": PLAN_SCHEMA,
    }:
        raise ResourceNameEditPlanError("MES resource name edit plan producer changed")
    if document.get("compatibility") != COMPATIBILITY:
        raise ResourceNameEditPlanError("MES resource name edit compatibility changed")
    retained = document.get("payload_sha256")
    if not _is_sha256(retained) or fingerprint(document) != retained:
        raise ResourceNameEditPlanError("MES resource name edit plan fingerprint changed")
    operation = document.get("operation")
    if not isinstance(operation, dict) or set(operation) != OPERATION_KEYS:
        raise ResourceNameEditPlanError("MES resource name edit operation fields changed")
    operation = _validate_operation(operation)
    source_identity = document.get("source_identity")
    if (
        not isinstance(source_identity, dict)
        or not set(source_identity).issubset(SOURCE_IDENTITY_KEYS)
        or not _is_safe_entry_name(source_identity.get("archive"))
        or not _is_safe_entry_name(source_identity.get("entry"))
        or (
            "archive_sha256" in source_identity
            and not _is_sha256(source_identity["archive_sha256"])
        )
    ):
        raise ResourceNameEditPlanError("MES resource name edit source identity changed")
    inputs = document.get("inputs")
    if (
        not isinstance(inputs, dict)
        or set(inputs) != {"editable_ir_sha256", "decompiler_ir_sha256"}
        or not all(_is_sha256(value) for value in inputs.values())
    ):
        raise ResourceNameEditPlanError("MES resource name edit input identity changed")
    target = document.get("target")
    replacement = document.get("replacement")
    if not isinstance(target, dict) or set(target) != TARGET_KEYS:
        raise ResourceNameEditPlanError("MES resource name edit target fields changed")
    if not isinstance(replacement, dict) or set(replacement) != REPLACEMENT_KEYS:
        raise ResourceNameEditPlanError("MES resource name edit replacement fields changed")
    supported = SUPPORTED_RESOURCES.get(str(target.get("op", "")))
    if (
        supported is None
        or target.get("command_id") != supported["command_id"]
        or target.get("resource_kind") != supported["resource_kind"]
        or target.get("operand_resource_kind") != supported["operand_resource_kind"]
        or target.get("reference_id") != operation["reference_id"]
        or target.get("instruction_start") != operation["source_offset"]
        or target.get("instruction_raw_sha256") != operation["instruction_raw_sha256"]
        or replacement.get("source_name") != operation["name"]
        or not isinstance(target.get("node_id"), str)
        or not target["node_id"]
        or not isinstance(target.get("region_id"), str)
        or not target["region_id"]
    ):
        raise ResourceNameEditPlanError("MES resource name edit typed target identity changed")
    _validate_plan_bytes(target, replacement, supported)
    if document.get("assembly_ready") is not True:
        raise ResourceNameEditPlanError("MES resource name edit plan is not assembly ready")
    if document.get("invariants") != INVARIANTS:
        raise ResourceNameEditPlanError("MES resource name edit invariants changed")
    if editable_document is not None:
        expected = _build_plan(editable_document, copy.deepcopy(operation))
        expected["payload_sha256"] = fingerprint(expected)
        if expected != document:
            raise ResourceNameEditPlanError(
                "MES resource name edit plan differs from its source"
            )
    return {"ok": True, "schema": PLAN_SCHEMA, "payload_sha256": retained}


def _build_plan(
    editable_document: dict[str, Any], raw_operation: dict[str, Any]
) -> dict[str, Any]:
    editable_ir.validate(editable_document)
    operation = _validate_operation(raw_operation)
    source_ir = editable_document["source_ir"]
    owners = [
        node
        for node in source_ir["nodes"]
        if int(node.get("source", {}).get("start", -1)) == operation["source_offset"]
    ]
    if len(owners) != 1:
        raise ResourceNameEditPlanError(
            "MES resource name edit target is not one unique node"
        )
    owner = owners[0]
    source = owner.get("source")
    statement = owner.get("statement")
    if (
        owner.get("kind") != "statement"
        or not isinstance(source, dict)
        or not isinstance(statement, dict)
        or statement.get("kind") != "instruction"
    ):
        raise ResourceNameEditPlanError(
            "MES resource name edit target is not a typed instruction"
        )
    op = str(statement.get("op", ""))
    supported = SUPPORTED_RESOURCES.get(op)
    if supported is None:
        raise ResourceNameEditPlanError(
            "MES resource name edit target resource form is unsupported"
        )
    if statement.get("command_id") != supported["command_id"]:
        raise ResourceNameEditPlanError("MES resource name edit command identity changed")
    instruction = _hex_bytes(source.get("raw_hex"), "instruction source")
    if hashlib.sha256(instruction).hexdigest() != operation["instruction_raw_sha256"]:
        raise ResourceNameEditPlanError(
            "MES resource name edit instruction source hash is stale"
        )
    instruction_start = int(source.get("start", -1))
    instruction_end = int(source.get("end", -1))
    if instruction_end - instruction_start != len(instruction):
        raise ResourceNameEditPlanError("MES resource name edit instruction boundary changed")
    operands = statement.get("operands")
    resource_operands = [
        operand
        for operand in operands if isinstance(operand, dict)
        and operand.get("type") == "resource_name"
    ] if isinstance(operands, list) else []
    if len(resource_operands) != 1:
        raise ResourceNameEditPlanError(
            "MES resource name edit target does not own one typed resource operand"
        )
    operand = resource_operands[0]
    if operand.get("resource_kind") != supported["operand_resource_kind"]:
        raise ResourceNameEditPlanError("MES resource name edit operand kind changed")
    name_start = operand.get("source_offset")
    raw_hex = operand.get("raw_hex")
    packed = operand.get("raw_bytes")
    if (
        not _is_int(name_start)
        or not isinstance(raw_hex, str)
        or packed != {"$packed_byte_array_hex": raw_hex}
    ):
        raise ResourceNameEditPlanError("MES resource name edit operand bytes changed")
    name_raw = _hex_bytes(raw_hex, "resource name")
    source_name = _ascii_name(name_raw, "source")
    extension = _extension(source_name)
    if extension not in supported["extensions"] or not _is_safe_entry_name(source_name):
        raise ResourceNameEditPlanError("MES resource name edit source name is invalid")
    normalized_name = _normalize_name(source_name, supported)
    if (
        str(operand.get("source_name", operand.get("name", ""))) != source_name
        or str(operand.get("name", "")) != normalized_name
    ):
        raise ResourceNameEditPlanError("MES resource name edit typed name changed")
    name_end = int(name_start) + len(name_raw)
    if (
        int(name_start) < instruction_start
        or name_end > instruction_end
        or instruction[int(name_start) - instruction_start:name_end - instruction_start]
        != name_raw
    ):
        raise ResourceNameEditPlanError(
            "MES resource name edit name is outside its instruction"
        )
    reference = _resource_reference(source_ir, owner, operation, supported, source_name, normalized_name)
    replacement_raw = _encode_replacement(operation["name"], supported, len(name_raw))
    relative_start = int(name_start) - instruction_start
    relative_end = name_end - instruction_start
    prefix = instruction[:relative_start]
    suffix = instruction[relative_end:]
    replacement_instruction = prefix + replacement_raw + suffix
    return {
        "ok": True,
        "schema": PLAN_SCHEMA,
        "producer": {
            "implementation": "python_phase6_resource_name_edit_planner",
            "contract": PLAN_SCHEMA,
        },
        "compatibility": copy.deepcopy(COMPATIBILITY),
        "source_identity": copy.deepcopy(source_ir["source_identity"]),
        "inputs": {
            "editable_ir_sha256": editable_document["payload_sha256"],
            "decompiler_ir_sha256": source_ir["payload_sha256"],
        },
        "operation": copy.deepcopy(operation),
        "target": {
            "node_id": str(owner.get("id", "")),
            "region_id": str(source.get("region", "")),
            "op": op,
            "command_id": supported["command_id"],
            "instruction_start": instruction_start,
            "instruction_end": instruction_end,
            "instruction_raw_hex": instruction.hex(),
            "instruction_raw_sha256": hashlib.sha256(instruction).hexdigest(),
            "reference_id": operation["reference_id"],
            "reference_boundary": reference["boundary"],
            "resource_kind": supported["resource_kind"],
            "archive_candidates": copy.deepcopy(reference["archive_candidates"]),
            "operand_resource_kind": supported["operand_resource_kind"],
            "source_name": source_name,
            "normalized_name": normalized_name,
            "extension": extension,
            "name_start": int(name_start),
            "name_end": name_end,
            "name_raw_hex": name_raw.hex(),
            "name_raw_sha256": hashlib.sha256(name_raw).hexdigest(),
            "prefix_raw_hex": prefix.hex(),
            "prefix_raw_sha256": hashlib.sha256(prefix).hexdigest(),
            "suffix_raw_hex": suffix.hex(),
            "suffix_raw_sha256": hashlib.sha256(suffix).hexdigest(),
        },
        "replacement": {
            "source_name": operation["name"],
            "normalized_name": _normalize_name(operation["name"], supported),
            "extension": _extension(operation["name"]),
            "name_raw_hex": replacement_raw.hex(),
            "name_raw_sha256": hashlib.sha256(replacement_raw).hexdigest(),
            "instruction_raw_hex": replacement_instruction.hex(),
            "instruction_raw_sha256": hashlib.sha256(replacement_instruction).hexdigest(),
        },
        "assembly_ready": True,
        "invariants": copy.deepcopy(INVARIANTS),
    }


def _resource_reference(
    source_ir: dict[str, Any], owner: dict[str, Any], operation: dict[str, Any],
    supported: dict[str, Any], source_name: str, normalized_name: str,
) -> dict[str, Any]:
    reference_ids = owner.get("reference_ids")
    references = source_ir.get("references")
    if not isinstance(reference_ids, list) or not isinstance(references, list):
        raise ResourceNameEditPlanError("MES resource name edit reference index changed")
    matches = [
        row for row in references
        if isinstance(row, dict)
        and row.get("id") == operation["reference_id"]
        and row.get("id") in reference_ids
        and row.get("kind") == "resource"
    ]
    if len(matches) != 1:
        raise ResourceNameEditPlanError(
            "MES resource name edit has no unique indexed resource reference"
        )
    reference = matches[0]
    value = reference.get("value")
    if (
        reference.get("source_offset") != operation["source_offset"]
        or not isinstance(value, dict)
        or value.get("source_offset") != operation["source_offset"]
        or value.get("op") not in SUPPORTED_RESOURCES
        or value.get("op") != next(
            op for op, form in SUPPORTED_RESOURCES.items() if form is supported
        )
        or value.get("resource_kind") != supported["resource_kind"]
        or value.get("boundary") != "strict_indexed"
        or value.get("source_name") != source_name
        or value.get("name") != normalized_name
        or not isinstance(value.get("archive_candidates"), list)
        or not value["archive_candidates"]
        or any(not _is_safe_entry_name(name) for name in value["archive_candidates"])
    ):
        raise ResourceNameEditPlanError("MES resource name edit resource reference changed")
    return value


def _validate_operation(raw: dict[str, Any]) -> dict[str, Any]:
    if not isinstance(raw, dict) or set(raw) != OPERATION_KEYS:
        raise ResourceNameEditPlanError("MES resource name edit operation fields changed")
    if raw.get("kind") != "replace_resource_name":
        raise ResourceNameEditPlanError("unsupported MES resource name edit operation")
    if not _is_int(raw.get("source_offset")) or int(raw["source_offset"]) < 0:
        raise ResourceNameEditPlanError("MES resource name edit source offset is invalid")
    if not _is_sha256(raw.get("instruction_raw_sha256")):
        raise ResourceNameEditPlanError("MES resource name edit source hash is invalid")
    if not isinstance(raw.get("reference_id"), str) or not raw["reference_id"]:
        raise ResourceNameEditPlanError("MES resource name edit reference id is invalid")
    if not _is_safe_entry_name(raw.get("name")):
        raise ResourceNameEditPlanError("MES resource name edit replacement name is invalid")
    return copy.deepcopy(raw)


def _validate_plan_bytes(
    target: dict[str, Any], replacement: dict[str, Any], supported: dict[str, Any]
) -> None:
    for key in ("command_id", "instruction_start", "instruction_end", "name_start", "name_end"):
        if not _is_int(target.get(key)) or int(target[key]) < 0:
            raise ResourceNameEditPlanError("MES resource name edit target coordinate changed")
    if (
        target.get("reference_boundary") != "strict_indexed"
        or not isinstance(target.get("archive_candidates"), list)
        or not target["archive_candidates"]
        or any(not _is_safe_entry_name(name) for name in target["archive_candidates"])
    ):
        raise ResourceNameEditPlanError("MES resource name edit reference boundary changed")
    source_instruction = _hex_bytes(target.get("instruction_raw_hex"), "planned instruction")
    source_name = _hex_bytes(target.get("name_raw_hex"), "planned source name")
    prefix = _hex_bytes_allow_empty(target.get("prefix_raw_hex"), "planned prefix")
    suffix = _hex_bytes_allow_empty(target.get("suffix_raw_hex"), "planned suffix")
    output_name = _hex_bytes(replacement.get("name_raw_hex"), "planned replacement name")
    output_instruction = _hex_bytes(replacement.get("instruction_raw_hex"), "planned output instruction")
    rows = (
        (target, source_instruction, "instruction"),
        (target, source_name, "name"),
        (target, prefix, "prefix"),
        (target, suffix, "suffix"),
        (replacement, output_name, "name"),
        (replacement, output_instruction, "instruction"),
    )
    for row, raw, prefix_name in rows:
        if row.get(f"{prefix_name}_raw_sha256") != hashlib.sha256(raw).hexdigest():
            raise ResourceNameEditPlanError("MES resource name edit planned hash changed")
    instruction_start = int(target["instruction_start"])
    instruction_end = int(target["instruction_end"])
    name_start = int(target["name_start"])
    name_end = int(target["name_end"])
    if (
        instruction_end <= instruction_start
        or name_start < instruction_start
        or name_end <= name_start
        or name_end > instruction_end
        or instruction_end - instruction_start != len(source_instruction)
        or name_end - name_start != len(source_name)
        or len(source_name) != len(output_name)
        or source_instruction != prefix + source_name + suffix
        or output_instruction != prefix + output_name + suffix
        or len(source_instruction) != len(output_instruction)
        or prefix.hex() != supported["prefix_hex"]
        or suffix.hex() != supported["suffix_hex"]
    ):
        raise ResourceNameEditPlanError("MES resource name edit planned boundary changed")
    source_name_text = _ascii_name(source_name, "source")
    output_name_text = _ascii_name(output_name, "replacement")
    if (
        source_name_text != target.get("source_name")
        or _extension(source_name_text) != target.get("extension")
        or _normalize_name(source_name_text, supported) != target.get("normalized_name")
        or output_name_text != replacement.get("source_name")
        or _extension(output_name_text) != replacement.get("extension")
        or _normalize_name(output_name_text, supported) != replacement.get("normalized_name")
        or _extension(source_name_text) not in supported["extensions"]
        or _extension(output_name_text) not in supported["extensions"]
    ):
        raise ResourceNameEditPlanError("MES resource name edit planned name changed")


def _encode_replacement(name: str, supported: dict[str, Any], source_length: int) -> bytes:
    if not _is_safe_entry_name(name) or _extension(name) not in supported["extensions"]:
        raise ResourceNameEditPlanError(
            "MES resource name edit replacement extension or name is invalid"
        )
    raw = name.encode("ascii")
    if len(raw) != source_length:
        raise ResourceNameEditPlanError(
            "MES resource name edit replacement changes name length"
        )
    return raw


def _normalize_name(name: str, supported: dict[str, Any]) -> str:
    if supported["normalization"] == "identity":
        return name
    basename, extension = name.rsplit(".", 1)
    return basename.upper() + "." + extension.upper()


def _extension(name: str) -> str:
    return name.rsplit(".", 1)[1].lower() if "." in name else ""


def _ascii_name(raw: bytes, label: str) -> str:
    try:
        value = raw.decode("ascii")
    except UnicodeDecodeError as error:
        raise ResourceNameEditPlanError(
            f"MES resource name edit {label} name is not ASCII"
        ) from error
    if not _is_safe_entry_name(value):
        raise ResourceNameEditPlanError(
            f"MES resource name edit {label} name is unsafe"
        )
    return value


def _hex_bytes(value: Any, label: str) -> bytes:
    raw = _hex_bytes_allow_empty(value, label)
    if not raw:
        raise ResourceNameEditPlanError(f"MES resource name edit {label} bytes are empty")
    return raw


def _hex_bytes_allow_empty(value: Any, label: str) -> bytes:
    if not isinstance(value, str) or len(value) % 2 != 0:
        raise ResourceNameEditPlanError(f"MES resource name edit {label} bytes are invalid")
    try:
        return bytes.fromhex(value)
    except ValueError as error:
        raise ResourceNameEditPlanError(
            f"MES resource name edit {label} bytes are invalid"
        ) from error


def _is_safe_entry_name(value: Any) -> bool:
    return (
        isinstance(value, str)
        and bool(value)
        and value not in {".", ".."}
        and "/" not in value
        and "\\" not in value
        and ":" not in value
        and all(0x20 <= byte <= 0x7E for byte in value.encode("ascii", errors="ignore"))
        and len(value.encode("ascii", errors="ignore")) == len(value)
    )


def _is_int(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool)


def main() -> None:
    parser = argparse.ArgumentParser(
        description=(
            "Build a fail-closed JSON plan for one same-length name in a typed "
            "MES resource marker. This tool never publishes MES bytes."
        )
    )
    parser.add_argument("editable_ir", type=Path)
    parser.add_argument("operation", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    if len({args.editable_ir.resolve(), args.operation.resolve(), args.output.resolve()}) != 3:
        raise ResourceNameEditPlanError("MES resource name edit paths must be distinct")
    try:
        editable_document = json.loads(args.editable_ir.read_text(encoding="utf-8"))
        operation = json.loads(args.operation.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise ResourceNameEditPlanError("MES resource name edit input could not be read") from error
    if not isinstance(editable_document, dict) or not isinstance(operation, dict):
        raise ResourceNameEditPlanError("MES resource name edit input is not an object")
    document = plan(editable_document, operation)
    payload = json.dumps(
        document,
        ensure_ascii=False,
        allow_nan=False,
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8") + b"\n"
    editable_ir.publish_new(args.output, payload)
    print(
        "MES_RESOURCE_NAME_EDIT_PLAN_PASS "
        f"schema={document['schema']} "
        f"entry={document['source_identity'].get('entry', '')} "
        f"offset={document['target']['instruction_start']} "
        f"kind={document['target']['resource_kind']} "
        f"name={document['target']['source_name']} "
        f"replacement={document['replacement']['source_name']} "
        "mes_bytes=false "
        f"payload_sha256={document['payload_sha256']}"
    )


if __name__ == "__main__":
    main()
