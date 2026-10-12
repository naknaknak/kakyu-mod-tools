from __future__ import annotations

import argparse
import copy
import hashlib
import json
from pathlib import Path
from typing import Any

import prepare_mes_editable_ir as editable_ir
from payload_values import canonical_payload_bytes, fingerprint, is_sha256 as _is_sha256


PLAN_SCHEMA = "kakyu_mes_state_literal_edit_plan/v1"
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
    "pair_index",
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
    "storage",
    "destination",
    "pair_index",
    "pair_count",
    "continuation_offset",
    "continuation",
    "expression_start",
    "expression_end",
    "expression_raw_hex",
    "expression_raw_sha256",
    "value",
    "width",
}
REPLACEMENT_KEYS = {
    "value",
    "width",
    "expression_raw_hex",
    "expression_raw_sha256",
    "instruction_raw_hex",
    "instruction_raw_sha256",
}
SOURCE_IDENTITY_KEYS = {"archive", "entry", "source_kind", "archive_sha256"}
SUPPORTED_WRITES = {
    "global_u8_write_run": {
        "command_id": 0x03,
        "storage": "global_u8",
        "destination_operand": 0,
        "pairs_operand": 1,
        "bank_operand": None,
    },
    "state_u16_write_run": {
        "command_id": 0x04,
        "storage": "state_u16",
        "destination_operand": 0,
        "pairs_operand": 1,
        "bank_operand": None,
    },
    "banked_u8_write_run": {
        "command_id": 0x06,
        "storage": "banked_u8",
        "destination_operand": 0,
        "pairs_operand": 2,
        "bank_operand": 1,
    },
    "banked_u16_write_run": {
        "command_id": 0x07,
        "storage": "banked_u16",
        "destination_operand": 0,
        "pairs_operand": 2,
        "bank_operand": 1,
    },
    "banked_i32_write_run": {
        "command_id": 0x08,
        "storage": "banked_i32",
        "destination_operand": 0,
        "pairs_operand": 2,
        "bank_operand": 1,
    },
    "global_i32_write_run": {
        "command_id": 0x0A,
        "storage": "global_i32",
        "destination_operand": 0,
        "pairs_operand": 1,
        "bank_operand": None,
    },
}
COMPATIBILITY = {
    "policy": "planning_only_same_width_literal_expression_replacement",
    "input_editable_schema": editable_ir.EDITABLE_IR_SCHEMA,
    "input_decompiler_schema": "kakyu_mes_decompiler_ir/v1",
    "supported_operation": "replace_state_write_literal",
    "supported_writes": {
        key: {
            "command_id": value["command_id"],
            "storage": value["storage"],
        }
        for key, value in SUPPORTED_WRITES.items()
    },
    "supported_literal_widths": [8, 16, 32],
    "u8_literal_policy": "unambiguous_token_00_through_7f_only",
    "expression_shape_policy": "single_literal_only",
    "length_policy": "replacement_expression_must_match_source_length",
    "binary_publication": "forbidden",
    "native_engine_compatibility": "unverified",
    "unknown_plan_schema": "reject",
    "unknown_v1_field": "reject",
}
INVARIANTS = {
    "source_editable_ir_validated": True,
    "target_node_unique_and_typed": True,
    "source_instruction_hash_matched": True,
    "source_expression_is_exact_literal": True,
    "replacement_expression_same_width_and_length": True,
    "continuation_byte_unchanged": True,
    "all_other_instruction_bytes_unchanged": True,
    "opaque_bytes_not_rewritten": True,
    "binary_not_published": True,
}


class StateLiteralEditPlanError(ValueError):
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
        raise StateLiteralEditPlanError("MES state literal edit plan schema or fields changed")
    if document.get("producer") != {
        "implementation": "python_phase6_state_literal_edit_planner",
        "contract": PLAN_SCHEMA,
    }:
        raise StateLiteralEditPlanError("MES state literal edit plan producer changed")
    if document.get("compatibility") != COMPATIBILITY:
        raise StateLiteralEditPlanError("MES state literal edit compatibility changed")
    retained = document.get("payload_sha256")
    if not _is_sha256(retained) or fingerprint(document) != retained:
        raise StateLiteralEditPlanError("MES state literal edit plan fingerprint changed")
    operation = document.get("operation")
    if not isinstance(operation, dict) or set(operation) != OPERATION_KEYS:
        raise StateLiteralEditPlanError("MES state literal edit operation fields changed")
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
        raise StateLiteralEditPlanError("MES state literal edit source identity changed")
    inputs = document.get("inputs")
    if (
        not isinstance(inputs, dict)
        or set(inputs) != {"editable_ir_sha256", "decompiler_ir_sha256"}
        or not all(_is_sha256(value) for value in inputs.values())
    ):
        raise StateLiteralEditPlanError("MES state literal edit input identity changed")
    target = document.get("target")
    replacement = document.get("replacement")
    if not isinstance(target, dict) or set(target) != TARGET_KEYS:
        raise StateLiteralEditPlanError("MES state literal edit target fields changed")
    if not isinstance(replacement, dict) or set(replacement) != REPLACEMENT_KEYS:
        raise StateLiteralEditPlanError("MES state literal edit replacement fields changed")
    if document.get("assembly_ready") is not True:
        raise StateLiteralEditPlanError("MES state literal edit plan is not assembly ready")
    if document.get("invariants") != INVARIANTS:
        raise StateLiteralEditPlanError("MES state literal edit invariants changed")
    write_form = SUPPORTED_WRITES.get(str(target.get("op", "")))
    if (
        write_form is None
        or not _is_int(target.get("command_id"))
        or int(target["command_id"]) != int(write_form["command_id"])
        or target.get("storage") != write_form["storage"]
        or not isinstance(target.get("node_id"), str)
        or not target["node_id"]
        or not isinstance(target.get("region_id"), str)
        or not target["region_id"]
        or target.get("instruction_raw_sha256") != operation["instruction_raw_sha256"]
        or target.get("pair_index") != operation["pair_index"]
        or replacement.get("value") != operation["value"]
    ):
        raise StateLiteralEditPlanError("MES state literal edit typed target identity changed")
    _validate_destination(target["destination"])
    destination_kind = target["destination"]["kind"]
    expected_destination_kind = (
        "fixed_index"
        if target["op"] in {"global_u8_write_run", "state_u16_write_run"}
        else "expression_index"
    )
    if (
        destination_kind != expected_destination_kind
        or (
            target["op"] in {"global_u8_write_run", "state_u16_write_run", "global_i32_write_run"}
            and int(target["destination"]["bank"]) != 0
        )
    ):
        raise StateLiteralEditPlanError("MES state literal edit destination does not match its write form")
    _validate_plan_coordinates(target, replacement)
    if editable_document is not None:
        expected = _build_plan(editable_document, copy.deepcopy(operation))
        expected["payload_sha256"] = fingerprint(expected)
        if expected != document:
            raise StateLiteralEditPlanError("MES state literal edit plan differs from its source")
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
        raise StateLiteralEditPlanError("MES state literal edit target is not one unique node")
    owner = owners[0]
    source = owner.get("source")
    statement = owner.get("statement")
    if (
        owner.get("kind") != "statement"
        or not isinstance(source, dict)
        or not isinstance(statement, dict)
        or statement.get("kind") != "instruction"
    ):
        raise StateLiteralEditPlanError("MES state literal edit target is not a typed instruction")
    operation_name = str(statement.get("op", ""))
    write_form = SUPPORTED_WRITES.get(operation_name)
    if write_form is None:
        raise StateLiteralEditPlanError("MES state literal edit target write form is unsupported")
    if int(statement.get("command_id", -1)) != int(write_form["command_id"]):
        raise StateLiteralEditPlanError("MES state literal edit command identity changed")
    instruction_raw = _hex_bytes(source.get("raw_hex"), "instruction source")
    if hashlib.sha256(instruction_raw).hexdigest() != operation["instruction_raw_sha256"]:
        raise StateLiteralEditPlanError("MES state literal edit instruction source hash is stale")
    instruction_start = int(source.get("start", -1))
    instruction_end = int(source.get("end", -1))
    if instruction_end - instruction_start != len(instruction_raw):
        raise StateLiteralEditPlanError("MES state literal edit instruction boundary changed")

    operands = statement.get("operands")
    if not isinstance(operands, list):
        raise StateLiteralEditPlanError("MES state literal edit operands are missing")
    pair_operand = _operand(operands, int(write_form["pairs_operand"]), "expression pairs")
    if pair_operand.get("type") != "expression_byte_pairs" or not isinstance(
        pair_operand.get("pairs"), list
    ):
        raise StateLiteralEditPlanError("MES state literal edit expression pairs changed")
    pairs = pair_operand["pairs"]
    pair_index = operation["pair_index"]
    if pair_index >= len(pairs):
        raise StateLiteralEditPlanError("MES state literal edit pair index is outside the write run")
    pair = pairs[pair_index]
    if not isinstance(pair, dict) or pair.get("type") != "expression_byte_pair":
        raise StateLiteralEditPlanError("MES state literal edit pair is not typed")
    continuation = pair.get("continuation")
    if not _is_int(continuation) or not 0 <= continuation <= 0xFF:
        raise StateLiteralEditPlanError("MES state literal edit continuation changed")
    expression = pair.get("expression")
    if not isinstance(expression, dict):
        raise StateLiteralEditPlanError("MES state literal edit expression is missing")
    ast = expression.get("ast")
    if not isinstance(ast, dict) or ast.get("type") != "literal":
        raise StateLiteralEditPlanError("MES state literal edit expression is not one literal")
    source_value = ast.get("value")
    source_width = ast.get("width")
    if not _is_int(source_value) or not _is_int(source_width):
        raise StateLiteralEditPlanError("MES state literal edit literal value changed")
    source_expression = _hex_bytes(expression.get("raw_hex"), "expression source")
    if source_expression != _encode_literal(source_value, source_width):
        raise StateLiteralEditPlanError("MES state literal edit expression bytes are not canonical")
    expression_start = int(expression.get("offset", -1))
    expression_end = int(expression.get("end_offset", -1))
    if (
        expression_end - expression_start != len(source_expression)
        or int(expression.get("byte_length", -1)) != len(source_expression)
        or expression_start < instruction_start
        or expression_end >= instruction_end
    ):
        raise StateLiteralEditPlanError("MES state literal edit expression boundary changed")
    relative_start = expression_start - instruction_start
    relative_end = expression_end - instruction_start
    if instruction_raw[relative_start:relative_end] != source_expression:
        raise StateLiteralEditPlanError("MES state literal edit expression is not inside its instruction")
    continuation_offset = expression_end
    if instruction_raw[relative_end] != continuation:
        raise StateLiteralEditPlanError("MES state literal edit continuation byte changed")

    replacement_expression = _encode_literal(operation["value"], source_width)
    if len(replacement_expression) != len(source_expression):
        raise StateLiteralEditPlanError("MES state literal edit replacement changes expression length")
    replacement_instruction = (
        instruction_raw[:relative_start]
        + replacement_expression
        + instruction_raw[relative_end:]
    )
    destination = _destination_summary(operands, write_form)
    return {
        "ok": True,
        "schema": PLAN_SCHEMA,
        "producer": {
            "implementation": "python_phase6_state_literal_edit_planner",
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
            "op": operation_name,
            "command_id": int(write_form["command_id"]),
            "instruction_start": instruction_start,
            "instruction_end": instruction_end,
            "instruction_raw_hex": instruction_raw.hex(),
            "instruction_raw_sha256": hashlib.sha256(instruction_raw).hexdigest(),
            "storage": str(write_form["storage"]),
            "destination": destination,
            "pair_index": pair_index,
            "pair_count": len(pairs),
            "continuation_offset": continuation_offset,
            "continuation": continuation,
            "expression_start": expression_start,
            "expression_end": expression_end,
            "expression_raw_hex": source_expression.hex(),
            "expression_raw_sha256": hashlib.sha256(source_expression).hexdigest(),
            "value": source_value,
            "width": source_width,
        },
        "replacement": {
            "value": operation["value"],
            "width": source_width,
            "expression_raw_hex": replacement_expression.hex(),
            "expression_raw_sha256": hashlib.sha256(replacement_expression).hexdigest(),
            "instruction_raw_hex": replacement_instruction.hex(),
            "instruction_raw_sha256": hashlib.sha256(replacement_instruction).hexdigest(),
        },
        "assembly_ready": True,
        "invariants": copy.deepcopy(INVARIANTS),
    }


def _validate_operation(raw: dict[str, Any]) -> dict[str, Any]:
    if not isinstance(raw, dict) or set(raw) != OPERATION_KEYS:
        raise StateLiteralEditPlanError("MES state literal edit operation fields changed")
    if raw.get("kind") != "replace_state_write_literal":
        raise StateLiteralEditPlanError("unsupported MES state literal edit operation")
    for key in ("source_offset", "pair_index", "value"):
        if not _is_int(raw.get(key)) or int(raw[key]) < 0:
            raise StateLiteralEditPlanError(f"MES state literal edit {key} is invalid")
    if not _is_sha256(raw.get("instruction_raw_sha256")):
        raise StateLiteralEditPlanError("MES state literal edit source hash is invalid")
    return copy.deepcopy(raw)


def _destination_summary(operands: list[Any], write_form: dict[str, Any]) -> dict[str, Any]:
    destination = _operand(operands, int(write_form["destination_operand"]), "destination")
    bank_index = write_form["bank_operand"]
    bank = 0
    if bank_index is not None:
        bank_operand = _operand(operands, int(bank_index), "bank")
        if bank_operand.get("type") != "u8_bank" or not _is_int(bank_operand.get("value")):
            raise StateLiteralEditPlanError("MES state literal edit destination bank changed")
        bank = int(bank_operand["value"])
    if destination.get("type") in {"u16_index", "u8_index"}:
        index = destination.get("value")
        if not _is_int(index) or int(index) < 0:
            raise StateLiteralEditPlanError("MES state literal edit fixed destination changed")
        return {"kind": "fixed_index", "index": int(index), "bank": bank}
    if destination.get("type") == "expression_index":
        expression = destination.get("value")
        if not isinstance(expression, dict):
            raise StateLiteralEditPlanError("MES state literal edit expression destination changed")
        raw = _hex_bytes(expression.get("raw_hex"), "destination expression")
        return {
            "kind": "expression_index",
            "expression_raw_hex": raw.hex(),
            "expression_raw_sha256": hashlib.sha256(raw).hexdigest(),
            "bank": bank,
        }
    raise StateLiteralEditPlanError("MES state literal edit destination form is unsupported")


def _validate_plan_coordinates(target: dict[str, Any], replacement: dict[str, Any]) -> None:
    for key in (
        "command_id",
        "instruction_start",
        "instruction_end",
        "pair_index",
        "pair_count",
        "continuation_offset",
        "continuation",
        "expression_start",
        "expression_end",
        "value",
        "width",
    ):
        if not _is_int(target.get(key)) or int(target[key]) < 0:
            raise StateLiteralEditPlanError("MES state literal edit target coordinate changed")
    if not _is_int(replacement.get("value")) or not _is_int(replacement.get("width")):
        raise StateLiteralEditPlanError("MES state literal edit replacement value changed")
    if (
        int(target["instruction_end"]) <= int(target["instruction_start"])
        or int(target["expression_start"]) < int(target["instruction_start"])
        or int(target["expression_end"]) >= int(target["instruction_end"])
        or int(target["pair_count"]) <= 0
        or int(target["pair_index"]) >= int(target["pair_count"])
        or int(target["continuation"]) > 0xFF
    ):
        raise StateLiteralEditPlanError("MES state literal edit target boundary changed")
    source_instruction = _hex_bytes(target.get("instruction_raw_hex"), "planned instruction")
    source_expression = _hex_bytes(target.get("expression_raw_hex"), "planned expression")
    output_instruction = _hex_bytes(replacement.get("instruction_raw_hex"), "replacement instruction")
    output_expression = _hex_bytes(replacement.get("expression_raw_hex"), "replacement expression")
    if len(source_instruction) != len(output_instruction) or len(source_expression) != len(output_expression):
        raise StateLiteralEditPlanError("MES state literal edit planned length changed")
    if int(target["instruction_end"]) - int(target["instruction_start"]) != len(source_instruction):
        raise StateLiteralEditPlanError("MES state literal edit planned instruction boundary changed")
    if int(target["expression_end"]) - int(target["expression_start"]) != len(source_expression):
        raise StateLiteralEditPlanError("MES state literal edit planned expression boundary changed")
    if int(target["continuation_offset"]) != int(target["expression_end"]):
        raise StateLiteralEditPlanError("MES state literal edit planned continuation moved")
    for row, raw, prefix in (
        (target, source_instruction, "instruction"),
        (target, source_expression, "expression"),
        (replacement, output_instruction, "instruction"),
        (replacement, output_expression, "expression"),
    ):
        if row.get(f"{prefix}_raw_sha256") != hashlib.sha256(raw).hexdigest():
            raise StateLiteralEditPlanError("MES state literal edit planned hash changed")
    if source_expression != _encode_literal(int(target["value"]), int(target["width"])):
        raise StateLiteralEditPlanError("MES state literal edit source literal changed")
    if output_expression != _encode_literal(int(replacement["value"]), int(replacement["width"])):
        raise StateLiteralEditPlanError("MES state literal edit replacement literal changed")
    if int(target["width"]) != int(replacement["width"]):
        raise StateLiteralEditPlanError("MES state literal edit replacement width changed")
    relative_start = int(target["expression_start"]) - int(target["instruction_start"])
    relative_end = int(target["expression_end"]) - int(target["instruction_start"])
    expected = source_instruction[:relative_start] + output_expression + source_instruction[relative_end:]
    if expected != output_instruction:
        raise StateLiteralEditPlanError("MES state literal edit replacement touched unrelated bytes")


def _validate_destination(destination: Any) -> None:
    if not isinstance(destination, dict):
        raise StateLiteralEditPlanError("MES state literal edit destination changed")
    if destination.get("kind") == "fixed_index":
        if (
            set(destination) != {"kind", "index", "bank"}
            or not _is_int(destination.get("index"))
            or int(destination["index"]) < 0
            or not _is_int(destination.get("bank"))
            or not 0 <= int(destination["bank"]) <= 0xFF
        ):
            raise StateLiteralEditPlanError("MES state literal edit fixed destination changed")
        return
    if destination.get("kind") == "expression_index":
        if (
            set(destination)
            != {"kind", "expression_raw_hex", "expression_raw_sha256", "bank"}
            or not _is_int(destination.get("bank"))
            or not 0 <= int(destination["bank"]) <= 0xFF
        ):
            raise StateLiteralEditPlanError("MES state literal edit expression destination changed")
        raw = _hex_bytes(destination.get("expression_raw_hex"), "destination expression")
        if destination.get("expression_raw_sha256") != hashlib.sha256(raw).hexdigest():
            raise StateLiteralEditPlanError("MES state literal edit destination hash changed")
        return
    raise StateLiteralEditPlanError("MES state literal edit destination form is unsupported")


def _encode_literal(value: int, width: int) -> bytes:
    if not _is_int(value) or value < 0:
        raise StateLiteralEditPlanError("MES state literal edit literal value is invalid")
    if width == 8:
        if value > 0x7F:
            raise StateLiteralEditPlanError("MES state literal edit 8-bit literal is not an unambiguous token")
        return bytes((value, 0xFF))
    if width == 16:
        if value > 0xFFFF:
            raise StateLiteralEditPlanError("MES state literal edit 16-bit literal is out of range")
        return b"\xF1" + value.to_bytes(2, "little") + b"\xFF"
    if width == 32:
        if value > 0xFFFFFFFF:
            raise StateLiteralEditPlanError("MES state literal edit 32-bit literal is out of range")
        return b"\xF2" + value.to_bytes(4, "little") + b"\xFF"
    raise StateLiteralEditPlanError("MES state literal edit literal width is unsupported")


def _operand(operands: list[Any], index: int, label: str) -> dict[str, Any]:
    if index < 0 or index >= len(operands) or not isinstance(operands[index], dict):
        raise StateLiteralEditPlanError(f"MES state literal edit {label} operand changed")
    return operands[index]


def _hex_bytes(value: Any, label: str) -> bytes:
    if not isinstance(value, str):
        raise StateLiteralEditPlanError(f"MES state literal edit {label} bytes are missing")
    try:
        return bytes.fromhex(value)
    except ValueError as error:
        raise StateLiteralEditPlanError(
            f"MES state literal edit {label} bytes are invalid"
        ) from error


def _is_int(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool)


def main() -> None:
    parser = argparse.ArgumentParser(
        description=(
            "Build a fail-closed JSON plan for one same-width literal in a typed "
            "MES state-write run. This tool never publishes MES bytes."
        )
    )
    parser.add_argument("editable_ir", type=Path)
    parser.add_argument("operation", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    resolved = {args.editable_ir.resolve(), args.operation.resolve(), args.output.resolve()}
    if len(resolved) != 3:
        raise StateLiteralEditPlanError("MES state literal edit paths must be distinct")
    try:
        editable_document = json.loads(args.editable_ir.read_text(encoding="utf-8"))
        operation = json.loads(args.operation.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise StateLiteralEditPlanError("MES state literal edit input could not be read") from error
    if not isinstance(editable_document, dict) or not isinstance(operation, dict):
        raise StateLiteralEditPlanError("MES state literal edit input is not an object")
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
        "MES_STATE_LITERAL_EDIT_PLAN_PASS "
        f"schema={document['schema']} "
        f"entry={document['source_identity'].get('entry', '')} "
        f"offset={document['target']['instruction_start']} "
        f"storage={document['target']['storage']} "
        f"width={document['target']['width']} "
        "mes_bytes=false "
        f"payload_sha256={document['payload_sha256']}"
    )


if __name__ == "__main__":
    main()
