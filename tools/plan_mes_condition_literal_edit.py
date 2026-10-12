from __future__ import annotations

import argparse
import copy
import hashlib
import json
from pathlib import Path
from typing import Any

import prepare_mes_editable_ir as editable_ir
from payload_values import canonical_payload_bytes, fingerprint, is_sha256 as _is_sha256


PLAN_SCHEMA = "kakyu_mes_condition_literal_edit_plan/v1"
TOP_LEVEL_KEYS = {
    "ok",
    "schema",
    "producer",
    "compatibility",
    "source_identity",
    "inputs",
    "operation",
    "target",
    "replacement",
    "assembly_ready",
    "invariants",
    "payload_sha256",
}
OPERATION_KEYS = {
    "kind",
    "source_offset",
    "instruction_raw_sha256",
    "literal_offset",
    "value",
}
TARGET_KEYS = {
    "node_id",
    "region_id",
    "op",
    "command_id",
    "instruction_start",
    "instruction_end",
    "instruction_raw_hex",
    "instruction_raw_sha256",
    "condition_start",
    "condition_end",
    "condition_raw_hex",
    "condition_raw_sha256",
    "literal_start",
    "literal_end",
    "literal_raw_hex",
    "literal_raw_sha256",
    "value",
    "width",
    "terminator_offset",
    "terminator",
    "false_target",
}
FALSE_TARGET_KEYS = {
    "reference_id",
    "operand_start",
    "operand_end",
    "operand_raw_hex",
    "operand_raw_sha256",
    "value",
    "in_code",
    "aligned",
    "target_region",
}
REPLACEMENT_KEYS = {
    "value",
    "width",
    "literal_raw_hex",
    "literal_raw_sha256",
    "condition_raw_hex",
    "condition_raw_sha256",
    "instruction_raw_hex",
    "instruction_raw_sha256",
}
SOURCE_IDENTITY_KEYS = {"archive", "entry", "source_kind", "archive_sha256"}
COMPATIBILITY = {
    "policy": "planning_only_same_width_condition_literal_replacement",
    "input_editable_schema": editable_ir.EDITABLE_IR_SCHEMA,
    "input_decompiler_schema": "kakyu_mes_decompiler_ir/v1",
    "supported_operation": "replace_condition_literal",
    "supported_instruction": {"op": "branch_if_not_true", "command_id": 0x0B},
    "supported_literal_widths": [8, 16, 32],
    "u8_literal_policy": "unambiguous_token_00_through_7f_only",
    "selection_policy": "one_exact_ast_literal_source_offset",
    "length_policy": "replacement_literal_must_match_source_length",
    "binary_publication": "forbidden",
    "native_engine_compatibility": "unverified",
    "unknown_plan_schema": "reject",
    "unknown_v1_field": "reject",
}
INVARIANTS = {
    "source_editable_ir_validated": True,
    "target_node_unique_and_typed": True,
    "source_instruction_hash_matched": True,
    "source_literal_unique_in_condition_ast": True,
    "replacement_literal_same_width_and_length": True,
    "condition_terminator_unchanged": True,
    "false_target_reference_bound": True,
    "false_target_operand_unchanged": True,
    "all_other_instruction_bytes_unchanged": True,
    "opaque_bytes_not_rewritten": True,
    "binary_not_published": True,
}


class ConditionLiteralEditPlanError(ValueError):
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
        raise ConditionLiteralEditPlanError(
            "MES condition literal edit plan schema or fields changed"
        )
    if document.get("producer") != {
        "implementation": "python_phase6_condition_literal_edit_planner",
        "contract": PLAN_SCHEMA,
    }:
        raise ConditionLiteralEditPlanError(
            "MES condition literal edit plan producer changed"
        )
    if document.get("compatibility") != COMPATIBILITY:
        raise ConditionLiteralEditPlanError(
            "MES condition literal edit compatibility changed"
        )
    retained = document.get("payload_sha256")
    if not _is_sha256(retained) or fingerprint(document) != retained:
        raise ConditionLiteralEditPlanError(
            "MES condition literal edit plan fingerprint changed"
        )
    operation = document.get("operation")
    if not isinstance(operation, dict) or set(operation) != OPERATION_KEYS:
        raise ConditionLiteralEditPlanError(
            "MES condition literal edit operation fields changed"
        )
    operation = _validate_operation(operation)
    source_identity = document.get("source_identity")
    if (
        not isinstance(source_identity, dict)
        or not set(source_identity).issubset(SOURCE_IDENTITY_KEYS)
        or not isinstance(source_identity.get("archive"), str)
        or not source_identity["archive"]
        or not isinstance(source_identity.get("entry"), str)
        or not source_identity["entry"]
        or (
            "archive_sha256" in source_identity
            and not _is_sha256(source_identity["archive_sha256"])
        )
    ):
        raise ConditionLiteralEditPlanError(
            "MES condition literal edit source identity changed"
        )
    inputs = document.get("inputs")
    if (
        not isinstance(inputs, dict)
        or set(inputs) != {"editable_ir_sha256", "decompiler_ir_sha256"}
        or not all(_is_sha256(value) for value in inputs.values())
    ):
        raise ConditionLiteralEditPlanError(
            "MES condition literal edit input identity changed"
        )
    target = document.get("target")
    replacement = document.get("replacement")
    if not isinstance(target, dict) or set(target) != TARGET_KEYS:
        raise ConditionLiteralEditPlanError(
            "MES condition literal edit target fields changed"
        )
    if not isinstance(replacement, dict) or set(replacement) != REPLACEMENT_KEYS:
        raise ConditionLiteralEditPlanError(
            "MES condition literal edit replacement fields changed"
        )
    if (
        target.get("op") != "branch_if_not_true"
        or target.get("command_id") != 0x0B
        or not isinstance(target.get("node_id"), str)
        or not target["node_id"]
        or not isinstance(target.get("region_id"), str)
        or not target["region_id"]
        or target.get("instruction_raw_sha256")
        != operation["instruction_raw_sha256"]
        or target.get("literal_start") != operation["literal_offset"]
        or replacement.get("value") != operation["value"]
    ):
        raise ConditionLiteralEditPlanError(
            "MES condition literal edit typed target identity changed"
        )
    if document.get("assembly_ready") is not True:
        raise ConditionLiteralEditPlanError(
            "MES condition literal edit plan is not assembly ready"
        )
    if document.get("invariants") != INVARIANTS:
        raise ConditionLiteralEditPlanError(
            "MES condition literal edit invariants changed"
        )
    _validate_plan_coordinates(target, replacement)
    if editable_document is not None:
        expected = _build_plan(editable_document, copy.deepcopy(operation))
        expected["payload_sha256"] = fingerprint(expected)
        if expected != document:
            raise ConditionLiteralEditPlanError(
                "MES condition literal edit plan differs from its source"
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
        if int(node.get("source", {}).get("start", -1))
        == operation["source_offset"]
    ]
    if len(owners) != 1:
        raise ConditionLiteralEditPlanError(
            "MES condition literal edit target is not one unique node"
        )
    owner = owners[0]
    source = owner.get("source")
    statement = owner.get("statement")
    if (
        owner.get("kind") != "statement"
        or not isinstance(source, dict)
        or not isinstance(statement, dict)
        or statement.get("kind") != "instruction"
        or statement.get("op") != "branch_if_not_true"
        or statement.get("command_id") != 0x0B
    ):
        raise ConditionLiteralEditPlanError(
            "MES condition literal edit target is not a typed conditional branch"
        )
    instruction_raw = _hex_bytes(source.get("raw_hex"), "instruction source")
    if hashlib.sha256(instruction_raw).hexdigest() != operation["instruction_raw_sha256"]:
        raise ConditionLiteralEditPlanError(
            "MES condition literal edit instruction source hash is stale"
        )
    instruction_start = int(source.get("start", -1))
    instruction_end = int(source.get("end", -1))
    if instruction_end - instruction_start != len(instruction_raw):
        raise ConditionLiteralEditPlanError(
            "MES condition literal edit instruction boundary changed"
        )
    operands = statement.get("operands")
    if not isinstance(operands, list) or len(operands) != 2:
        raise ConditionLiteralEditPlanError(
            "MES condition literal edit branch operands changed"
        )
    condition_operand = operands[0]
    target_operand = operands[1]
    if (
        not isinstance(condition_operand, dict)
        or condition_operand.get("type") != "condition"
        or not isinstance(condition_operand.get("value"), dict)
        or not isinstance(target_operand, dict)
        or target_operand.get("type") != "code_offset"
        or not _is_int(target_operand.get("value"))
    ):
        raise ConditionLiteralEditPlanError(
            "MES condition literal edit branch operand typing changed"
        )
    condition = condition_operand["value"]
    condition_raw = _hex_bytes(condition.get("raw_hex"), "condition source")
    condition_start = int(condition.get("offset", -1))
    condition_end = int(condition.get("end_offset", -1))
    if (
        condition_start != instruction_start + 1
        or condition_end - condition_start != len(condition_raw)
        or int(condition.get("byte_length", -1)) != len(condition_raw)
        or condition_end + 4 != instruction_end
        or not condition_raw
        or condition_raw[-1] != 0xFF
    ):
        raise ConditionLiteralEditPlanError(
            "MES condition literal edit condition boundary changed"
        )
    condition_relative_start = condition_start - instruction_start
    condition_relative_end = condition_end - instruction_start
    if instruction_raw[condition_relative_start:condition_relative_end] != condition_raw:
        raise ConditionLiteralEditPlanError(
            "MES condition literal edit condition is not inside its instruction"
        )
    ast = condition.get("ast")
    literals = [
        node
        for node in _walk_ast(ast)
        if node.get("type") == "literal"
        and isinstance(node.get("source"), dict)
        and node["source"].get("offset") == operation["literal_offset"]
    ]
    if len(literals) != 1:
        raise ConditionLiteralEditPlanError(
            "MES condition literal edit offset does not select one exact AST literal"
        )
    literal = literals[0]
    source_value = literal.get("value")
    source_width = literal.get("width")
    if not _is_int(source_value) or not _is_int(source_width):
        raise ConditionLiteralEditPlanError(
            "MES condition literal edit literal value changed"
        )
    source_literal = _encode_literal_token(source_value, source_width)
    literal_start = operation["literal_offset"]
    literal_end = literal_start + len(source_literal)
    if literal_start < condition_start or literal_end > condition_end - 1:
        raise ConditionLiteralEditPlanError(
            "MES condition literal edit literal boundary changed"
        )
    literal_relative_start = literal_start - instruction_start
    literal_relative_end = literal_end - instruction_start
    if instruction_raw[literal_relative_start:literal_relative_end] != source_literal:
        raise ConditionLiteralEditPlanError(
            "MES condition literal edit literal bytes are not canonical"
        )
    false_target_start = condition_end
    false_target_end = instruction_end
    false_target_raw = instruction_raw[
        false_target_start - instruction_start:false_target_end - instruction_start
    ]
    false_target_value = int(target_operand["value"])
    if (
        len(false_target_raw) != 4
        or int.from_bytes(false_target_raw, "little") != false_target_value
    ):
        raise ConditionLiteralEditPlanError(
            "MES condition literal edit false-target operand changed"
        )
    false_target = _false_target_summary(
        source_ir, owner, instruction_start, false_target_value, false_target_raw,
        false_target_start, false_target_end
    )
    replacement_literal = _encode_literal_token(operation["value"], source_width)
    if len(replacement_literal) != len(source_literal):
        raise ConditionLiteralEditPlanError(
            "MES condition literal edit replacement changes literal length"
        )
    replacement_instruction = (
        instruction_raw[:literal_relative_start]
        + replacement_literal
        + instruction_raw[literal_relative_end:]
    )
    replacement_condition = replacement_instruction[
        condition_relative_start:condition_relative_end
    ]
    return {
        "ok": True,
        "schema": PLAN_SCHEMA,
        "producer": {
            "implementation": "python_phase6_condition_literal_edit_planner",
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
            "op": "branch_if_not_true",
            "command_id": 0x0B,
            "instruction_start": instruction_start,
            "instruction_end": instruction_end,
            "instruction_raw_hex": instruction_raw.hex(),
            "instruction_raw_sha256": hashlib.sha256(instruction_raw).hexdigest(),
            "condition_start": condition_start,
            "condition_end": condition_end,
            "condition_raw_hex": condition_raw.hex(),
            "condition_raw_sha256": hashlib.sha256(condition_raw).hexdigest(),
            "literal_start": literal_start,
            "literal_end": literal_end,
            "literal_raw_hex": source_literal.hex(),
            "literal_raw_sha256": hashlib.sha256(source_literal).hexdigest(),
            "value": source_value,
            "width": source_width,
            "terminator_offset": condition_end - 1,
            "terminator": 0xFF,
            "false_target": false_target,
        },
        "replacement": {
            "value": operation["value"],
            "width": source_width,
            "literal_raw_hex": replacement_literal.hex(),
            "literal_raw_sha256": hashlib.sha256(replacement_literal).hexdigest(),
            "condition_raw_hex": replacement_condition.hex(),
            "condition_raw_sha256": hashlib.sha256(replacement_condition).hexdigest(),
            "instruction_raw_hex": replacement_instruction.hex(),
            "instruction_raw_sha256": hashlib.sha256(replacement_instruction).hexdigest(),
        },
        "assembly_ready": True,
        "invariants": copy.deepcopy(INVARIANTS),
    }


def _false_target_summary(
    source_ir: dict[str, Any],
    owner: dict[str, Any],
    source_offset: int,
    target_value: int,
    raw: bytes,
    operand_start: int,
    operand_end: int,
) -> dict[str, Any]:
    reference_ids = owner.get("reference_ids")
    references = source_ir.get("references")
    if not isinstance(reference_ids, list) or not isinstance(references, list):
        raise ConditionLiteralEditPlanError(
            "MES condition literal edit reference index changed"
        )
    wanted = []
    for reference in references:
        if not isinstance(reference, dict) or reference.get("id") not in reference_ids:
            continue
        value = reference.get("value")
        if (
            reference.get("kind") == "code"
            and reference.get("source_offset") == source_offset
            and isinstance(value, dict)
            and value.get("kind") == "condition_false_target"
        ):
            wanted.append(reference)
    if len(wanted) != 1:
        raise ConditionLiteralEditPlanError(
            "MES condition literal edit has no unique indexed false-target reference"
        )
    reference = wanted[0]
    value = reference["value"]
    if (
        value.get("source_offset") != source_offset
        or value.get("op") != "branch_if_not_true"
        or value.get("target_offset") != target_value
        or not isinstance(value.get("in_code"), bool)
        or not isinstance(value.get("aligned"), bool)
        or not isinstance(value.get("target_region"), str)
    ):
        raise ConditionLiteralEditPlanError(
            "MES condition literal edit false-target reference changed"
        )
    return {
        "reference_id": str(reference["id"]),
        "operand_start": operand_start,
        "operand_end": operand_end,
        "operand_raw_hex": raw.hex(),
        "operand_raw_sha256": hashlib.sha256(raw).hexdigest(),
        "value": target_value,
        "in_code": value["in_code"],
        "aligned": value["aligned"],
        "target_region": value["target_region"],
    }


def _validate_operation(raw: dict[str, Any]) -> dict[str, Any]:
    if not isinstance(raw, dict) or set(raw) != OPERATION_KEYS:
        raise ConditionLiteralEditPlanError(
            "MES condition literal edit operation fields changed"
        )
    if raw.get("kind") != "replace_condition_literal":
        raise ConditionLiteralEditPlanError(
            "unsupported MES condition literal edit operation"
        )
    for key in ("source_offset", "literal_offset", "value"):
        if not _is_int(raw.get(key)) or int(raw[key]) < 0:
            raise ConditionLiteralEditPlanError(
                f"MES condition literal edit {key} is invalid"
            )
    if not _is_sha256(raw.get("instruction_raw_sha256")):
        raise ConditionLiteralEditPlanError(
            "MES condition literal edit source hash is invalid"
        )
    return copy.deepcopy(raw)


def _validate_plan_coordinates(
    target: dict[str, Any], replacement: dict[str, Any]
) -> None:
    for key in (
        "command_id", "instruction_start", "instruction_end", "condition_start",
        "condition_end", "literal_start", "literal_end", "value", "width",
        "terminator_offset", "terminator",
    ):
        if not _is_int(target.get(key)) or int(target[key]) < 0:
            raise ConditionLiteralEditPlanError(
                "MES condition literal edit target coordinate changed"
            )
    if not _is_int(replacement.get("value")) or not _is_int(replacement.get("width")):
        raise ConditionLiteralEditPlanError(
            "MES condition literal edit replacement value changed"
        )
    false_target = target.get("false_target")
    if not isinstance(false_target, dict) or set(false_target) != FALSE_TARGET_KEYS:
        raise ConditionLiteralEditPlanError(
            "MES condition literal edit false-target fields changed"
        )
    for key in ("operand_start", "operand_end", "value"):
        if not _is_int(false_target.get(key)) or int(false_target[key]) < 0:
            raise ConditionLiteralEditPlanError(
                "MES condition literal edit false-target coordinate changed"
            )
    if (
        not isinstance(false_target.get("reference_id"), str)
        or not false_target["reference_id"]
        or not isinstance(false_target.get("in_code"), bool)
        or not isinstance(false_target.get("aligned"), bool)
        or not isinstance(false_target.get("target_region"), str)
        or int(target["instruction_end"]) <= int(target["instruction_start"])
        or int(target["condition_start"]) != int(target["instruction_start"]) + 1
        or int(target["literal_start"]) < int(target["condition_start"])
        or int(target["literal_end"]) > int(target["condition_end"]) - 1
        or int(target["terminator_offset"]) != int(target["condition_end"]) - 1
        or int(target["terminator"]) != 0xFF
        or int(false_target["operand_start"]) != int(target["condition_end"])
        or int(false_target["operand_end"]) != int(target["instruction_end"])
    ):
        raise ConditionLiteralEditPlanError(
            "MES condition literal edit target boundary changed"
        )
    source_instruction = _hex_bytes(target.get("instruction_raw_hex"), "planned instruction")
    source_condition = _hex_bytes(target.get("condition_raw_hex"), "planned condition")
    source_literal = _hex_bytes(target.get("literal_raw_hex"), "planned literal")
    false_target_raw = _hex_bytes(false_target.get("operand_raw_hex"), "planned false target")
    output_instruction = _hex_bytes(replacement.get("instruction_raw_hex"), "replacement instruction")
    output_condition = _hex_bytes(replacement.get("condition_raw_hex"), "replacement condition")
    output_literal = _hex_bytes(replacement.get("literal_raw_hex"), "replacement literal")
    if (
        len(source_instruction) != len(output_instruction)
        or len(source_condition) != len(output_condition)
        or len(source_literal) != len(output_literal)
        or len(false_target_raw) != 4
        or int.from_bytes(false_target_raw, "little") != int(false_target["value"])
    ):
        raise ConditionLiteralEditPlanError(
            "MES condition literal edit planned length or target changed"
        )
    rows = (
        (target, source_instruction, "instruction"),
        (target, source_condition, "condition"),
        (target, source_literal, "literal"),
        (false_target, false_target_raw, "operand"),
        (replacement, output_instruction, "instruction"),
        (replacement, output_condition, "condition"),
        (replacement, output_literal, "literal"),
    )
    for row, raw, prefix in rows:
        if row.get(f"{prefix}_raw_sha256") != hashlib.sha256(raw).hexdigest():
            raise ConditionLiteralEditPlanError(
                "MES condition literal edit planned hash changed"
            )
    if (
        int(target["instruction_end"]) - int(target["instruction_start"]) != len(source_instruction)
        or int(target["condition_end"]) - int(target["condition_start"]) != len(source_condition)
        or int(target["literal_end"]) - int(target["literal_start"]) != len(source_literal)
        or source_condition[-1:] != b"\xFF"
        or source_instruction[-4:] != false_target_raw
        or output_instruction[-4:] != false_target_raw
    ):
        raise ConditionLiteralEditPlanError(
            "MES condition literal edit planned boundary changed"
        )
    if source_literal != _encode_literal_token(int(target["value"]), int(target["width"])):
        raise ConditionLiteralEditPlanError(
            "MES condition literal edit source literal changed"
        )
    if output_literal != _encode_literal_token(int(replacement["value"]), int(replacement["width"])):
        raise ConditionLiteralEditPlanError(
            "MES condition literal edit replacement literal changed"
        )
    if int(target["width"]) != int(replacement["width"]):
        raise ConditionLiteralEditPlanError(
            "MES condition literal edit replacement width changed"
        )
    literal_relative_start = int(target["literal_start"]) - int(target["instruction_start"])
    literal_relative_end = int(target["literal_end"]) - int(target["instruction_start"])
    condition_relative_start = int(target["condition_start"]) - int(target["instruction_start"])
    condition_relative_end = int(target["condition_end"]) - int(target["instruction_start"])
    if (
        source_instruction[condition_relative_start:condition_relative_end]
        != source_condition
        or source_instruction[literal_relative_start:literal_relative_end]
        != source_literal
    ):
        raise ConditionLiteralEditPlanError(
            "MES condition literal edit source slices changed"
        )
    expected_instruction = (
        source_instruction[:literal_relative_start]
        + output_literal
        + source_instruction[literal_relative_end:]
    )
    if (
        expected_instruction != output_instruction
        or output_instruction[condition_relative_start:condition_relative_end]
        != output_condition
    ):
        raise ConditionLiteralEditPlanError(
            "MES condition literal edit replacement touched unrelated bytes"
        )


def _walk_ast(value: Any) -> list[dict[str, Any]]:
    result: list[dict[str, Any]] = []
    if isinstance(value, dict):
        result.append(value)
        for child in value.values():
            result.extend(_walk_ast(child))
    elif isinstance(value, list):
        for child in value:
            result.extend(_walk_ast(child))
    return result


def _encode_literal_token(value: int, width: int) -> bytes:
    if not _is_int(value) or value < 0:
        raise ConditionLiteralEditPlanError(
            "MES condition literal edit literal value is invalid"
        )
    if width == 8:
        if value > 0x7F:
            raise ConditionLiteralEditPlanError(
                "MES condition literal edit 8-bit literal is not an unambiguous token"
            )
        return bytes((value,))
    if width == 16:
        if value > 0xFFFF:
            raise ConditionLiteralEditPlanError(
                "MES condition literal edit 16-bit literal is out of range"
            )
        return b"\xF1" + value.to_bytes(2, "little")
    if width == 32:
        if value > 0xFFFFFFFF:
            raise ConditionLiteralEditPlanError(
                "MES condition literal edit 32-bit literal is out of range"
            )
        return b"\xF2" + value.to_bytes(4, "little")
    raise ConditionLiteralEditPlanError(
        "MES condition literal edit literal width is unsupported"
    )


def _hex_bytes(value: Any, label: str) -> bytes:
    if not isinstance(value, str):
        raise ConditionLiteralEditPlanError(
            f"MES condition literal edit {label} bytes are missing"
        )
    try:
        return bytes.fromhex(value)
    except ValueError as error:
        raise ConditionLiteralEditPlanError(
            f"MES condition literal edit {label} bytes are invalid"
        ) from error


def _is_int(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool)


def main() -> None:
    parser = argparse.ArgumentParser(
        description=(
            "Build a fail-closed JSON plan for one same-width literal token in "
            "a typed MES conditional branch. This tool never publishes MES bytes."
        )
    )
    parser.add_argument("editable_ir", type=Path)
    parser.add_argument("operation", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    resolved = {args.editable_ir.resolve(), args.operation.resolve(), args.output.resolve()}
    if len(resolved) != 3:
        raise ConditionLiteralEditPlanError(
            "MES condition literal edit paths must be distinct"
        )
    try:
        editable_document = json.loads(args.editable_ir.read_text(encoding="utf-8"))
        operation = json.loads(args.operation.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise ConditionLiteralEditPlanError(
            "MES condition literal edit input could not be read"
        ) from error
    if not isinstance(editable_document, dict) or not isinstance(operation, dict):
        raise ConditionLiteralEditPlanError(
            "MES condition literal edit input is not an object"
        )
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
        "MES_CONDITION_LITERAL_EDIT_PLAN_PASS "
        f"schema={document['schema']} "
        f"entry={document['source_identity'].get('entry', '')} "
        f"offset={document['target']['instruction_start']} "
        f"literal_offset={document['target']['literal_start']} "
        f"width={document['target']['width']} "
        "mes_bytes=false "
        f"payload_sha256={document['payload_sha256']}"
    )


if __name__ == "__main__":
    main()
