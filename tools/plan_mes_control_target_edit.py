from __future__ import annotations

import argparse
import copy
import hashlib
import json
from pathlib import Path
from typing import Any

import decompile_mes_handoff as decompiler
import prepare_mes_editable_ir as editable_ir
from payload_values import canonical_payload_bytes, fingerprint, is_sha256 as _is_sha256


PLAN_SCHEMA = "kakyu_mes_control_target_edit_plan/v1"
TOP_LEVEL_KEYS = {
    "ok", "schema", "producer", "compatibility", "source_identity", "inputs",
    "operation", "source_control", "replacement_target", "patch", "coverage",
    "assembly_ready", "invariants", "payload_sha256",
}
OPERATION_KEYS = {
    "kind", "source_offset", "reference_kind", "source_instruction_raw_sha256",
    "replacement_target_offset", "replacement_target_instruction_raw_sha256",
}
SOURCE_CONTROL_KEYS = {
    "node_id", "evidence_status", "source_region_id", "instruction_start",
    "instruction_end", "instruction_raw_sha256", "op", "command_id",
    "reference_id", "reference_kind", "operand_start", "operand_end",
    "current_target_offset", "current_target_node_id", "expression_kind",
    "expression_start", "expression_end", "expression_raw_sha256",
}
REPLACEMENT_TARGET_KEYS = {
    "node_id", "evidence_status", "source_region_id", "instruction_start",
    "instruction_end", "instruction_raw_sha256", "op", "command_id",
}
PATCH_KEYS = {
    "operand_start", "operand_end", "source_raw_hex", "output_raw_hex",
    "encoding", "source_instruction_raw_hex", "output_instruction_raw_hex",
    "output_instruction_raw_sha256",
}
COVERAGE_KEYS = {
    "source_code_size", "output_code_size", "source_node_count",
    "source_typed_node_count", "source_opaque_node_count", "changed_byte_count",
}
SUPPORTED_FORMS = {
    "condition_false_target": {
        "op": "branch_if_not_true",
        "command_id": 0x0B,
        "operand_position": "instruction_tail_u32_le",
        "expression_kind": "condition",
    },
    "continuation_target": {
        "op": "continuation_transfer",
        "command_id": 0x0C,
        "operand_position": "command_plus_one_u32_le",
        "expression_kind": "none",
    },
}
COMPATIBILITY = {
    "policy": "planning_only_retarget_one_exact_control_transfer",
    "input_editable_schema": editable_ir.EDITABLE_IR_SCHEMA,
    "input_decompiler_schema": decompiler.DECOMPILER_IR_SCHEMA,
    "supported_operation": "retarget_control_flow",
    "supported_forms": copy.deepcopy(SUPPORTED_FORMS),
    "source_policy": "strict_typed_transfer_with_one_exact_reference",
    "replacement_policy": "strict_unique_typed_instruction_start",
    "coordinate_policy": "code_relative_offsets_unchanged",
    "byte_length_policy": "unchanged_u32_operand_only",
    "binary_publication": "forbidden",
    "native_engine_compatibility": "unverified",
    "unknown_plan_schema": "reject",
    "unknown_v1_field": "reject",
}
INVARIANTS = {
    "source_editable_ir_validated": True,
    "source_transfer_unique_and_typed": True,
    "source_instruction_hash_matched": True,
    "source_expression_or_transfer_form_exact": True,
    "source_reference_unique_aligned_and_in_code": True,
    "current_target_unique_and_typed": True,
    "replacement_target_unique_and_typed": True,
    "replacement_target_hash_matched": True,
    "instruction_length_unchanged": True,
    "only_target_operand_planned_to_change": True,
    "opaque_bytes_not_rewritten": True,
    "binary_not_published": True,
}


class ControlTargetEditPlanError(ValueError):
    pass


def plan(editable_document: dict[str, Any], operation: dict[str, Any]) -> dict[str, Any]:
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
        raise ControlTargetEditPlanError(
            "MES control-target edit plan schema or fields changed"
        )
    if document.get("producer") != {
        "implementation": "python_phase6_control_target_edit_planner",
        "contract": PLAN_SCHEMA,
    }:
        raise ControlTargetEditPlanError("MES control-target edit producer changed")
    if document.get("compatibility") != COMPATIBILITY:
        raise ControlTargetEditPlanError("MES control-target edit compatibility changed")
    retained = document.get("payload_sha256")
    if not _is_sha256(retained) or fingerprint(document) != retained:
        raise ControlTargetEditPlanError("MES control-target edit fingerprint changed")
    for key, expected in (
        ("operation", OPERATION_KEYS),
        ("source_control", SOURCE_CONTROL_KEYS),
        ("replacement_target", REPLACEMENT_TARGET_KEYS),
        ("patch", PATCH_KEYS),
        ("coverage", COVERAGE_KEYS),
    ):
        value = document.get(key)
        if not isinstance(value, dict) or set(value) != expected:
            raise ControlTargetEditPlanError(
                f"MES control-target edit {key} fields changed"
            )
    if document.get("assembly_ready") is not True or document.get("invariants") != INVARIANTS:
        raise ControlTargetEditPlanError(
            "MES control-target edit readiness or invariants changed"
        )
    if editable_document is not None:
        expected = _build_plan(editable_document, copy.deepcopy(document["operation"]))
        expected["payload_sha256"] = fingerprint(expected)
        if expected != document:
            raise ControlTargetEditPlanError(
                "MES control-target edit plan differs from its source"
            )
    return {"ok": True, "schema": PLAN_SCHEMA, "payload_sha256": retained}


def _build_plan(
    editable_document: dict[str, Any], raw_operation: dict[str, Any]
) -> dict[str, Any]:
    editable_ir.validate(editable_document)
    operation = _validate_operation(raw_operation)
    source_ir = editable_document["source_ir"]
    nodes = source_ir["nodes"]
    source = _unique_typed_node(nodes, operation["source_offset"], "source transfer")
    statement = source["statement"]
    source_range = source["source"]
    form = SUPPORTED_FORMS[operation["reference_kind"]]
    if (
        statement.get("op") != form["op"]
        or _exact_int(statement.get("command_id")) != form["command_id"]
        or source_range.get("raw_sha256") != operation["source_instruction_raw_sha256"]
    ):
        raise ControlTargetEditPlanError(
            "MES control-target source transfer form or instruction hash is stale"
        )
    raw = _raw_bytes(source_range, "source transfer")
    start = int(source_range["start"])
    end = int(source_range["end"])
    if len(raw) != end - start or not raw or raw[0] != form["command_id"]:
        raise ControlTargetEditPlanError(
            "MES control-target source instruction bytes changed"
        )
    operand_start, operand_end, expression = _source_form(
        statement, form, raw, start, end
    )
    current_target = int.from_bytes(raw[operand_start - start:operand_end - start], "little")
    references = [
        row for row in source_ir["references"]
        if row.get("kind") == "code"
        and _exact_int(row.get("source_offset")) == start
        and isinstance(row.get("value"), dict)
        and row["value"].get("kind") == operation["reference_kind"]
        and row["value"].get("op") == form["op"]
        and _exact_int(row["value"].get("target_offset")) == current_target
        and row["value"].get("aligned") is True
        and row["value"].get("in_code") is True
    ]
    if len(references) != 1 or references[0].get("id") not in source.get("reference_ids", []):
        raise ControlTargetEditPlanError(
            "MES control-target source reference is not one exact aligned reference"
        )
    current_node = _unique_typed_node(nodes, current_target, "current target")
    replacement_node = _unique_typed_node(
        nodes, operation["replacement_target_offset"], "replacement target"
    )
    if current_target == operation["replacement_target_offset"]:
        raise ControlTargetEditPlanError(
            "MES control-target replacement target is unchanged"
        )
    replacement_source = replacement_node["source"]
    if replacement_source.get("raw_sha256") != operation["replacement_target_instruction_raw_sha256"]:
        raise ControlTargetEditPlanError(
            "MES control-target replacement instruction hash is stale"
        )
    code_size = _exact_int(source_ir.get("container", {}).get("code_size"))
    if code_size is None or not (0 <= operation["replacement_target_offset"] < code_size):
        raise ControlTargetEditPlanError(
            "MES control-target replacement target is outside code"
        )
    output_operand = operation["replacement_target_offset"].to_bytes(4, "little")
    output_raw = bytearray(raw)
    output_raw[operand_start - start:operand_end - start] = output_operand
    coverage = source_ir["coverage"]
    return {
        "ok": True,
        "schema": PLAN_SCHEMA,
        "producer": {
            "implementation": "python_phase6_control_target_edit_planner",
            "contract": PLAN_SCHEMA,
        },
        "compatibility": copy.deepcopy(COMPATIBILITY),
        "source_identity": copy.deepcopy(source_ir["source_identity"]),
        "inputs": {
            "editable_ir_sha256": editable_document["payload_sha256"],
            "decompiler_ir_sha256": source_ir["payload_sha256"],
        },
        "operation": copy.deepcopy(operation),
        "source_control": {
            "node_id": str(source["id"]),
            "evidence_status": str(source["evidence_status"]),
            "source_region_id": str(source_range["region"]),
            "instruction_start": start,
            "instruction_end": end,
            "instruction_raw_sha256": str(source_range["raw_sha256"]),
            "op": str(statement["op"]),
            "command_id": int(statement["command_id"]),
            "reference_id": str(references[0]["id"]),
            "reference_kind": operation["reference_kind"],
            "operand_start": operand_start,
            "operand_end": operand_end,
            "current_target_offset": current_target,
            "current_target_node_id": str(current_node["id"]),
            **expression,
        },
        "replacement_target": {
            "node_id": str(replacement_node["id"]),
            "evidence_status": str(replacement_node["evidence_status"]),
            "source_region_id": str(replacement_source["region"]),
            "instruction_start": int(replacement_source["start"]),
            "instruction_end": int(replacement_source["end"]),
            "instruction_raw_sha256": str(replacement_source["raw_sha256"]),
            "op": str(replacement_node["statement"]["op"]),
            "command_id": int(replacement_node["statement"]["command_id"]),
        },
        "patch": {
            "operand_start": operand_start,
            "operand_end": operand_end,
            "source_raw_hex": raw[operand_start - start:operand_end - start].hex(),
            "output_raw_hex": output_operand.hex(),
            "encoding": "u32_le_absolute_code_offset",
            "source_instruction_raw_hex": raw.hex(),
            "output_instruction_raw_hex": bytes(output_raw).hex(),
            "output_instruction_raw_sha256": hashlib.sha256(output_raw).hexdigest(),
        },
        "coverage": {
            "source_code_size": code_size,
            "output_code_size": code_size,
            "source_node_count": int(coverage["node_count"]),
            "source_typed_node_count": int(coverage["typed_node_count"]),
            "source_opaque_node_count": int(coverage["opaque_node_count"]),
            "changed_byte_count": sum(a != b for a, b in zip(
                raw[operand_start - start:operand_end - start], output_operand
            )),
        },
        "assembly_ready": True,
        "invariants": copy.deepcopy(INVARIANTS),
    }


def _validate_operation(value: dict[str, Any]) -> dict[str, Any]:
    if not isinstance(value, dict) or set(value) != OPERATION_KEYS:
        raise ControlTargetEditPlanError(
            "MES control-target edit operation fields changed"
        )
    source_offset = _exact_int(value.get("source_offset"))
    target_offset = _exact_int(value.get("replacement_target_offset"))
    if (
        value.get("kind") != "retarget_control_flow"
        or value.get("reference_kind") not in SUPPORTED_FORMS
        or source_offset is None or source_offset < 0
        or target_offset is None or target_offset < 0
        or not _is_sha256(value.get("source_instruction_raw_sha256"))
        or not _is_sha256(value.get("replacement_target_instruction_raw_sha256"))
    ):
        raise ControlTargetEditPlanError(
            "MES control-target edit operation value changed"
        )
    return {
        "kind": "retarget_control_flow",
        "source_offset": source_offset,
        "reference_kind": str(value["reference_kind"]),
        "source_instruction_raw_sha256": str(value["source_instruction_raw_sha256"]),
        "replacement_target_offset": target_offset,
        "replacement_target_instruction_raw_sha256": str(
            value["replacement_target_instruction_raw_sha256"]
        ),
    }


def _source_form(
    statement: dict[str, Any], form: dict[str, Any], raw: bytes, start: int, end: int
) -> tuple[int, int, dict[str, Any]]:
    operands = statement.get("operands")
    if not isinstance(operands, list):
        raise ControlTargetEditPlanError("MES control-target operands changed")
    if form["expression_kind"] == "none":
        if len(raw) != 5 or len(operands) != 1 or operands[0].get("type") != "code_offset":
            raise ControlTargetEditPlanError(
                "MES continuation transfer is not command-plus-one u32"
            )
        return start + 1, end, {
            "expression_kind": "none",
            "expression_start": start + 1,
            "expression_end": start + 1,
            "expression_raw_sha256": hashlib.sha256(b"").hexdigest(),
        }
    if len(raw) < 7 or len(operands) != 2 or operands[0].get("type") != "condition":
        raise ControlTargetEditPlanError("MES conditional transfer form changed")
    condition = operands[0].get("value")
    if not isinstance(condition, dict):
        raise ControlTargetEditPlanError("MES conditional expression changed")
    try:
        condition_raw = bytes.fromhex(str(condition.get("raw_hex", "")))
    except ValueError as error:
        raise ControlTargetEditPlanError("MES conditional expression bytes changed") from error
    condition_start = _exact_int(condition.get("offset"))
    condition_end = _exact_int(condition.get("end_offset"))
    if (
        condition_start != start + 1
        or condition_end != end - 4
        or raw[1:-4] != condition_raw
        or operands[1].get("type") != "code_offset"
    ):
        raise ControlTargetEditPlanError("MES conditional expression boundary changed")
    return end - 4, end, {
        "expression_kind": "condition",
        "expression_start": condition_start,
        "expression_end": condition_end,
        "expression_raw_sha256": hashlib.sha256(condition_raw).hexdigest(),
    }


def _unique_typed_node(
    nodes: list[dict[str, Any]], offset: int, role: str
) -> dict[str, Any]:
    candidates = [
        node for node in nodes
        if _exact_int(node.get("source", {}).get("start")) == offset
    ]
    if len(candidates) != 1:
        raise ControlTargetEditPlanError(
            f"MES control-target {role} is not one unique instruction start"
        )
    node = candidates[0]
    statement = node.get("statement")
    source = node.get("source")
    metadata = statement.get("metadata", {}) if isinstance(statement, dict) else {}
    if (
        node.get("kind") != "statement"
        or node.get("evidence_status") != decompiler.TYPED_EVIDENCE_STATUS
        or not isinstance(statement, dict)
        or statement.get("kind") != "instruction"
        or not isinstance(source, dict)
        or metadata.get("structural_only") is True
        or not _is_sha256(source.get("raw_sha256"))
    ):
        raise ControlTargetEditPlanError(
            f"MES control-target {role} is not a strict typed instruction"
        )
    return node


def _raw_bytes(source: dict[str, Any], role: str) -> bytes:
    try:
        raw = bytes.fromhex(str(source.get("raw_hex", "")))
    except ValueError as error:
        raise ControlTargetEditPlanError(
            f"MES control-target {role} raw bytes changed"
        ) from error
    if hashlib.sha256(raw).hexdigest() != source.get("raw_sha256"):
        raise ControlTargetEditPlanError(
            f"MES control-target {role} raw hash changed"
        )
    return raw


def _exact_int(value: Any) -> int | None:
    return value if isinstance(value, int) and not isinstance(value, bool) else None


def main() -> None:
    parser = argparse.ArgumentParser(
        description=(
            "Plan one exact MES conditional or continuation target edit without "
            "publishing MES bytes."
        )
    )
    parser.add_argument("editable_ir", type=Path)
    parser.add_argument("operation", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    editable_path = args.editable_ir.resolve()
    operation_path = args.operation.resolve()
    output_path = args.output.resolve()
    if output_path.exists() or output_path in {editable_path, operation_path}:
        raise ControlTargetEditPlanError(
            "MES control-target edit output must be a new path"
        )
    document = plan(
        json.loads(editable_path.read_text(encoding="utf-8")),
        json.loads(operation_path.read_text(encoding="utf-8")),
    )
    editable_ir.publish_new(
        output_path, editable_ir.canonical_json_bytes(document) + b"\n"
    )
    print(
        "MES_CONTROL_TARGET_EDIT_PLAN_PASS "
        f"schema={PLAN_SCHEMA} entry={document['source_identity']['entry']} "
        f"kind={document['source_control']['reference_kind']} "
        f"source=0x{document['source_control']['instruction_start']:X} "
        f"old_target=0x{document['source_control']['current_target_offset']:X} "
        f"new_target=0x{document['replacement_target']['instruction_start']:X} "
        f"payload_sha256={document['payload_sha256']}"
    )


if __name__ == "__main__":
    main()
