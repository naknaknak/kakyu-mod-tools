from __future__ import annotations

import argparse
import copy
import json
from pathlib import Path
from typing import Any

import decompile_mes_handoff as decompiler
import plan_mes_message_relocation as message_planner
import prepare_mes_editable_ir as editable_ir
from payload_values import canonical_payload_bytes, fingerprint, is_sha256 as _is_sha256


PLAN_SCHEMA = "kakyu_mes_control_target_relocation_plan/v2"
TOP_LEVEL_KEYS = {
    "ok",
    "schema",
    "producer",
    "compatibility",
    "source_identity",
    "inputs",
    "relocation",
    "target_patches",
    "resolved_blocker_reference_ids",
    "remaining_blockers",
    "assembly_ready",
    "invariants",
    "payload_sha256",
}
PATCH_KEYS = {
    "reference_id",
    "reference_kind",
    "owner_node_id",
    "owner_op",
    "command_id",
    "source_instruction_start",
    "source_instruction_end",
    "output_instruction_start",
    "output_instruction_end",
    "source_operand_start",
    "source_operand_end",
    "output_operand_start",
    "output_operand_end",
    "source_target_offset",
    "output_target_offset",
    "source_target_node_id",
    "source_raw_hex",
    "output_raw_hex",
    "encoding",
}
SUPPORTED_TARGET_FORMS = {
    "condition_false_target": {
        "op": "branch_if_not_true",
        "command_id": 0x0B,
        "operand_index": 1,
        "operand_position": "instruction_tail_u32_le",
    },
    "continuation_target": {
        "op": "continuation_transfer",
        "command_id": 0x0C,
        "operand_index": 0,
        "operand_position": "command_plus_one_u32_le",
    },
    "definition_skip_target": {
        "op": "command_10",
        "command_id": 0x10,
        "operand_index": 1,
        "operand_position": "instruction_tail_u32_le",
    },
}
COMPATIBILITY = {
    "policy": "augment_exact_message_relocation_plan",
    "input_editable_schema": editable_ir.EDITABLE_IR_SCHEMA,
    "input_decompiler_schema": decompiler.DECOMPILER_IR_SCHEMA,
    "input_message_plan_schema": message_planner.PLAN_SCHEMA,
    "supported_target_forms": copy.deepcopy(SUPPORTED_TARGET_FORMS),
    "target_alignment_policy": "typed_instruction_start_only",
    "operand_encoding": "u32_le_absolute_code_offset",
    "unsupported_target_policy": "retain_blocker",
    "binary_publication": "forbidden",
    "native_engine_compatibility": "unverified",
    "unknown_plan_schema": "reject",
    "unknown_v1_field": "reject",
}


class ControlTargetRelocationPlanError(ValueError):
    pass


def plan(
    editable_document: dict[str, Any], message_plan: dict[str, Any]
) -> dict[str, Any]:
    result = _build_plan(editable_document, message_plan)
    result["payload_sha256"] = fingerprint(result)
    validate(result, editable_document, message_plan)
    return result


def validate(
    document: dict[str, Any],
    editable_document: dict[str, Any] | None = None,
    message_plan: dict[str, Any] | None = None,
) -> dict[str, Any]:
    if (
        document.get("ok") is not True
        or document.get("schema") != PLAN_SCHEMA
        or set(document) != TOP_LEVEL_KEYS
    ):
        raise ControlTargetRelocationPlanError(
            "MES control-target relocation plan schema or fields changed"
        )
    if document.get("producer") != {
        "implementation": "python_phase6_control_target_relocation_planner",
        "contract": PLAN_SCHEMA,
    }:
        raise ControlTargetRelocationPlanError(
            "MES control-target relocation plan producer changed"
        )
    if document.get("compatibility") != COMPATIBILITY:
        raise ControlTargetRelocationPlanError(
            "MES control-target relocation compatibility changed"
        )
    retained = document.get("payload_sha256")
    if not _is_sha256(retained) or fingerprint(document) != retained:
        raise ControlTargetRelocationPlanError(
            "MES control-target relocation plan fingerprint changed"
        )
    inputs = document.get("inputs")
    if (
        not isinstance(inputs, dict)
        or set(inputs)
        != {
            "editable_ir_sha256",
            "decompiler_ir_sha256",
            "message_relocation_plan_sha256",
        }
        or not all(_is_sha256(value) for value in inputs.values())
    ):
        raise ControlTargetRelocationPlanError(
            "MES control-target relocation input identity changed"
        )
    relocation = document.get("relocation")
    if (
        not isinstance(relocation, dict)
        or set(relocation)
        != {
            "delta",
            "pivot_source_end",
            "source_code_size",
            "output_code_size",
        }
        or not _is_int(relocation.get("delta"))
        or not all(
            _is_nonnegative_int(relocation.get(key))
            for key in ("pivot_source_end", "source_code_size", "output_code_size")
        )
        or int(relocation["output_code_size"])
        != int(relocation["source_code_size"]) + int(relocation["delta"])
    ):
        raise ControlTargetRelocationPlanError(
            "MES control-target relocation coordinates changed"
        )
    patches = document.get("target_patches")
    resolved = document.get("resolved_blocker_reference_ids")
    remaining = document.get("remaining_blockers")
    if (
        not isinstance(patches, list)
        or not isinstance(resolved, list)
        or not isinstance(remaining, list)
        or any(not isinstance(row, dict) or set(row) != PATCH_KEYS for row in patches)
        or any(not isinstance(value, str) or not value for value in resolved)
        or any(not isinstance(row, dict) for row in remaining)
    ):
        raise ControlTargetRelocationPlanError(
            "MES control-target relocation patch collection changed"
        )
    if resolved != [str(row["reference_id"]) for row in patches]:
        raise ControlTargetRelocationPlanError(
            "MES control-target relocation resolved blockers changed"
        )
    _validate_patch_rows(patches)
    if document.get("assembly_ready") is not (len(remaining) == 0):
        raise ControlTargetRelocationPlanError(
            "MES control-target relocation readiness changed"
        )
    if document.get("invariants") != {
        "source_editable_ir_validated": True,
        "message_relocation_plan_validated": True,
        "source_instruction_bytes_matched": True,
        "target_operand_u32_le_matched": True,
        "target_instruction_start_confirmed": True,
        "patch_ranges_nonoverlapping": True,
        "definition_skip_targets_scanned": True,
        "unsupported_blockers_retained": True,
        "binary_not_published": True,
    }:
        raise ControlTargetRelocationPlanError(
            "MES control-target relocation invariants changed"
        )
    if editable_document is not None or message_plan is not None:
        if editable_document is None or message_plan is None:
            raise ControlTargetRelocationPlanError(
                "MES control-target relocation source pair is incomplete"
            )
        expected = _build_plan(editable_document, message_plan)
        expected["payload_sha256"] = fingerprint(expected)
        if expected != document:
            raise ControlTargetRelocationPlanError(
                "MES control-target relocation plan differs from its source"
            )
    return {"ok": True, "schema": PLAN_SCHEMA, "payload_sha256": retained}


def _build_plan(
    editable_document: dict[str, Any], message_plan: dict[str, Any]
) -> dict[str, Any]:
    editable_ir.validate(editable_document)
    message_planner.validate(message_plan, editable_document)
    source_ir = editable_document["source_ir"]
    if message_plan.get("source_identity") != source_ir.get("source_identity"):
        raise ControlTargetRelocationPlanError(
            "MES control-target relocation source identity changed"
        )
    relocation = message_plan["relocation"]
    delta = int(relocation["delta"])
    pivot = int(relocation["pivot_source_end"])
    references = {str(row["id"]): row for row in source_ir["references"]}
    nodes = source_ir["nodes"]
    target_patches: list[dict[str, Any]] = []
    resolved_ids: list[str] = []
    remaining: list[dict[str, Any]] = []
    for untyped_blocker in message_plan["blockers"]:
        if not isinstance(untyped_blocker, dict):
            raise ControlTargetRelocationPlanError(
                "MES message relocation blocker is not an object"
            )
        blocker = copy.deepcopy(untyped_blocker)
        if blocker.get("code") != "encoded_code_target_requires_mw03":
            remaining.append(blocker)
            continue
        reference_id = str(blocker.get("reference_id", ""))
        patch = _resolve_target_patch(
            blocker,
            references.get(reference_id),
            nodes,
            pivot,
            delta,
        )
        if patch is None:
            remaining.append(blocker)
            continue
        target_patches.append(patch)
        resolved_ids.append(reference_id)
    definition_patches, definition_blockers = _collect_definition_skip_patches(
        nodes, pivot, delta
    )
    target_patches.extend(definition_patches)
    remaining.extend(definition_blockers)
    target_patches.sort(
        key=lambda row: (int(row["output_operand_start"]), str(row["reference_id"]))
    )
    resolved_ids = [str(row["reference_id"]) for row in target_patches]
    remaining.sort(key=_blocker_sort_key)
    _validate_patch_rows(target_patches)
    return {
        "ok": True,
        "schema": PLAN_SCHEMA,
        "producer": {
            "implementation": "python_phase6_control_target_relocation_planner",
            "contract": PLAN_SCHEMA,
        },
        "compatibility": copy.deepcopy(COMPATIBILITY),
        "source_identity": copy.deepcopy(source_ir["source_identity"]),
        "inputs": {
            "editable_ir_sha256": editable_document["payload_sha256"],
            "decompiler_ir_sha256": source_ir["payload_sha256"],
            "message_relocation_plan_sha256": message_plan["payload_sha256"],
        },
        "relocation": {
            "delta": delta,
            "pivot_source_end": pivot,
            "source_code_size": int(relocation["source_code_size"]),
            "output_code_size": int(relocation["output_code_size"]),
        },
        "target_patches": target_patches,
        "resolved_blocker_reference_ids": resolved_ids,
        "remaining_blockers": remaining,
        "assembly_ready": len(remaining) == 0,
        "invariants": {
            "source_editable_ir_validated": True,
            "message_relocation_plan_validated": True,
            "source_instruction_bytes_matched": True,
            "target_operand_u32_le_matched": True,
            "target_instruction_start_confirmed": True,
            "patch_ranges_nonoverlapping": True,
            "definition_skip_targets_scanned": True,
            "unsupported_blockers_retained": True,
            "binary_not_published": True,
        },
    }


def _collect_definition_skip_patches(
    nodes: list[dict[str, Any]], pivot: int, delta: int
) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    patches: list[dict[str, Any]] = []
    blockers: list[dict[str, Any]] = []
    nodes_by_start: dict[int, list[dict[str, Any]]] = {}
    for node in nodes:
        start = _exact_int(node.get("source", {}).get("start"))
        if start is not None:
            nodes_by_start.setdefault(start, []).append(node)
    for owner in nodes:
        statement = owner.get("statement")
        source = owner.get("source")
        if (
            owner.get("kind") != "statement"
            or owner.get("evidence_status") != decompiler.TYPED_EVIDENCE_STATUS
            or not isinstance(statement, dict)
            or not isinstance(source, dict)
            or statement.get("kind") != "instruction"
            or statement.get("op") != "command_10"
            or _exact_int(statement.get("command_id")) != 0x10
        ):
            continue
        start = _exact_int(source.get("start"))
        end = _exact_int(source.get("end"))
        operands = statement.get("operands")
        try:
            raw = bytes.fromhex(str(source.get("raw_hex", "")))
        except ValueError:
            raw = b""
        target: int | None = None
        if isinstance(operands, list) and len(operands) == 2:
            target_operand = operands[1]
            if (
                isinstance(target_operand, dict)
                and target_operand.get("type") == "u8_array"
                and isinstance(target_operand.get("value"), list)
                and len(target_operand["value"]) == 4
                and all(
                    _is_nonnegative_int(value) and int(value) <= 0xFF
                    for value in target_operand["value"]
                )
            ):
                target = int.from_bytes(
                    bytes(int(value) for value in target_operand["value"]), "little"
                )
        if target is None:
            blockers.append(
                {
                    "code": "definition_skip_target_unresolved",
                    "node_id": str(owner.get("id", "")),
                    "source_offset": -1 if start is None else start,
                    "target_offset": -1,
                }
            )
            continue
        if target < pivot:
            continue
        target_nodes = nodes_by_start.get(target, [])
        if (
            start is None
            or end is None
            or end <= start
            or len(raw) != end - start
            or len(raw) < 5
            or raw[0] != 0x10
            or int.from_bytes(raw[-4:], "little") != target
            or len(target_nodes) != 1
            or target_nodes[0].get("kind") != "statement"
            or target_nodes[0].get("evidence_status")
            != decompiler.TYPED_EVIDENCE_STATUS
        ):
            blockers.append(
                {
                    "code": "definition_skip_target_unresolved",
                    "node_id": str(owner.get("id", "")),
                    "source_offset": -1 if start is None else start,
                    "target_offset": target,
                }
            )
            continue
        output_target = _relocate_offset(target, pivot, delta)
        operand_start = end - 4
        output_start = _relocate_offset(start, pivot, delta)
        output_end = output_start + (end - start)
        output_operand_start = _relocate_offset(operand_start, pivot, delta)
        patches.append(
            {
                "reference_id": f"definition_skip_{start:08x}",
                "reference_kind": "definition_skip_target",
                "owner_node_id": str(owner["id"]),
                "owner_op": "command_10",
                "command_id": 0x10,
                "source_instruction_start": start,
                "source_instruction_end": end,
                "output_instruction_start": output_start,
                "output_instruction_end": output_end,
                "source_operand_start": operand_start,
                "source_operand_end": end,
                "output_operand_start": output_operand_start,
                "output_operand_end": output_operand_start + 4,
                "source_target_offset": target,
                "output_target_offset": output_target,
                "source_target_node_id": str(target_nodes[0]["id"]),
                "source_raw_hex": raw[-4:].hex(),
                "output_raw_hex": output_target.to_bytes(4, "little").hex(),
                "encoding": "u32_le_absolute_code_offset",
            }
        )
    return patches, blockers


def _resolve_target_patch(
    blocker: dict[str, Any],
    reference: Any,
    nodes: list[dict[str, Any]],
    pivot: int,
    delta: int,
) -> dict[str, Any] | None:
    if not isinstance(reference, dict) or reference.get("kind") != "code":
        return None
    value = reference.get("value")
    if not isinstance(value, dict):
        return None
    reference_kind = str(value.get("kind", ""))
    form = SUPPORTED_TARGET_FORMS.get(reference_kind)
    if form is None:
        return None
    reference_id = str(reference.get("id", ""))
    source_offset = _exact_int(value.get("source_offset"))
    source_target = _exact_int(value.get("target_offset"))
    output_target = _exact_int(blocker.get("output_target_offset"))
    if (
        not reference_id
        or source_offset is None
        or source_target is None
        or output_target is None
        or source_offset != _exact_int(blocker.get("source_offset"))
        or source_target != _exact_int(blocker.get("target_offset"))
        or output_target != _relocate_offset(source_target, pivot, delta)
        or value.get("in_code") is not True
        or value.get("aligned") is not True
        or str(value.get("op", "")) != form["op"]
    ):
        return None
    owners = [node for node in nodes if reference_id in node.get("reference_ids", [])]
    if len(owners) != 1:
        return None
    owner = owners[0]
    statement = owner.get("statement")
    source = owner.get("source")
    if (
        owner.get("kind") != "statement"
        or owner.get("evidence_status") != decompiler.TYPED_EVIDENCE_STATUS
        or not isinstance(statement, dict)
        or not isinstance(source, dict)
        or statement.get("kind") != "instruction"
        or statement.get("op") != form["op"]
        or _exact_int(statement.get("command_id")) != form["command_id"]
        or _exact_int(source.get("start")) != source_offset
    ):
        return None
    operands = statement.get("operands")
    if not isinstance(operands, list) or len(operands) <= form["operand_index"]:
        return None
    target_operand = operands[form["operand_index"]]
    if (
        not isinstance(target_operand, dict)
        or target_operand.get("type") != "code_offset"
        or _exact_int(target_operand.get("value")) != source_target
    ):
        return None
    try:
        raw = bytes.fromhex(str(source.get("raw_hex", "")))
    except ValueError:
        return None
    start = int(source["start"])
    end = _exact_int(source.get("end"))
    if end is None or end <= start or len(raw) != end - start:
        return None
    if raw[0] != form["command_id"]:
        return None
    if reference_kind == "condition_false_target":
        if len(operands) != 2 or not _validated_condition_operand(
            operands[0], raw, start, end
        ):
            return None
        operand_start = end - 4
    else:
        if len(operands) != 1 or len(raw) != 5:
            return None
        operand_start = start + 1
    operand_end = operand_start + 4
    relative_start = operand_start - start
    source_target_raw = raw[relative_start : relative_start + 4]
    if (
        len(source_target_raw) != 4
        or int.from_bytes(source_target_raw, "little") != source_target
        or source_target < 0
        or source_target > 0xFFFFFFFF
        or output_target < 0
        or output_target > 0xFFFFFFFF
    ):
        return None
    target_nodes = [
        node
        for node in nodes
        if node.get("kind") == "statement"
        and node.get("evidence_status") == decompiler.TYPED_EVIDENCE_STATUS
        and _exact_int(node.get("source", {}).get("start")) == source_target
    ]
    if len(target_nodes) != 1:
        return None
    output_start = _relocate_offset(start, pivot, delta)
    output_end = output_start + (end - start)
    output_operand_start = _relocate_offset(operand_start, pivot, delta)
    output_operand_end = output_operand_start + 4
    return {
        "reference_id": reference_id,
        "reference_kind": reference_kind,
        "owner_node_id": str(owner["id"]),
        "owner_op": str(form["op"]),
        "command_id": int(form["command_id"]),
        "source_instruction_start": start,
        "source_instruction_end": end,
        "output_instruction_start": output_start,
        "output_instruction_end": output_end,
        "source_operand_start": operand_start,
        "source_operand_end": operand_end,
        "output_operand_start": output_operand_start,
        "output_operand_end": output_operand_end,
        "source_target_offset": source_target,
        "output_target_offset": output_target,
        "source_target_node_id": str(target_nodes[0]["id"]),
        "source_raw_hex": source_target_raw.hex(),
        "output_raw_hex": output_target.to_bytes(4, "little").hex(),
        "encoding": "u32_le_absolute_code_offset",
    }


def _validated_condition_operand(
    operand: Any, raw: bytes, start: int, end: int
) -> bool:
    if not isinstance(operand, dict) or operand.get("type") != "condition":
        return False
    value = operand.get("value")
    if not isinstance(value, dict):
        return False
    expression_start = _exact_int(value.get("offset"))
    expression_end = _exact_int(value.get("end_offset"))
    if expression_start != start + 1 or expression_end != end - 4:
        return False
    try:
        expression_raw = bytes.fromhex(str(value.get("raw_hex", "")))
    except ValueError:
        return False
    return (
        value.get("ok") is True
        and _exact_int(value.get("byte_length")) == expression_end - expression_start
        and expression_raw == raw[1:-4]
    )


def _validate_patch_rows(patches: list[dict[str, Any]]) -> None:
    previous_end = -1
    seen_ids: set[str] = set()
    for row in patches:
        reference_id = str(row.get("reference_id", ""))
        reference_kind = str(row.get("reference_kind", ""))
        form = SUPPORTED_TARGET_FORMS.get(reference_kind)
        numeric_keys = PATCH_KEYS - {
            "reference_id",
            "reference_kind",
            "owner_node_id",
            "owner_op",
            "source_target_node_id",
            "source_raw_hex",
            "output_raw_hex",
            "encoding",
        }
        if (
            not reference_id
            or reference_id in seen_ids
            or form is None
            or row.get("owner_op") != form["op"]
            or _exact_int(row.get("command_id")) != form["command_id"]
            or row.get("encoding") != "u32_le_absolute_code_offset"
            or any(not _is_nonnegative_int(row.get(key)) for key in numeric_keys)
        ):
            raise ControlTargetRelocationPlanError(
                "MES control-target relocation patch fields changed"
            )
        seen_ids.add(reference_id)
        source_operand_start = int(row["source_operand_start"])
        source_operand_end = int(row["source_operand_end"])
        output_operand_start = int(row["output_operand_start"])
        output_operand_end = int(row["output_operand_end"])
        try:
            source_raw = bytes.fromhex(str(row["source_raw_hex"]))
            output_raw = bytes.fromhex(str(row["output_raw_hex"]))
        except ValueError as error:
            raise ControlTargetRelocationPlanError(
                "MES control-target relocation patch bytes changed"
            ) from error
        if (
            source_operand_end - source_operand_start != 4
            or output_operand_end - output_operand_start != 4
            or output_operand_start < previous_end
            or len(source_raw) != 4
            or len(output_raw) != 4
            or int.from_bytes(source_raw, "little") != int(row["source_target_offset"])
            or int.from_bytes(output_raw, "little") != int(row["output_target_offset"])
            or not (
                int(row["source_instruction_start"])
                <= source_operand_start
                < source_operand_end
                <= int(row["source_instruction_end"])
            )
            or not (
                int(row["output_instruction_start"])
                <= output_operand_start
                < output_operand_end
                <= int(row["output_instruction_end"])
            )
        ):
            raise ControlTargetRelocationPlanError(
                "MES control-target relocation patch boundary changed"
            )
        previous_end = output_operand_end


def _relocate_offset(value: int, pivot: int, delta: int) -> int:
    return value + delta if value >= pivot else value


def _blocker_sort_key(row: dict[str, Any]) -> tuple[Any, ...]:
    return (
        int(row.get("source_offset", row.get("target_offset", -1))),
        str(row.get("code", "")),
        str(row.get("reference_id", row.get("node_id", ""))),
    )


def _exact_int(value: Any) -> int | None:
    if isinstance(value, bool) or not isinstance(value, int):
        return None
    return value


def _is_int(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool)


def _is_nonnegative_int(value: Any) -> bool:
    return _is_int(value) and value >= 0


def main() -> None:
    parser = argparse.ArgumentParser(
        description=(
            "Resolve exact branch, continuation, and definition-skip u32 target patches for one "
            "fingerprinted MES message relocation plan. This tool never publishes MES bytes."
        )
    )
    parser.add_argument("editable_ir", type=Path)
    parser.add_argument("message_plan", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    resolved = {
        args.editable_ir.resolve(),
        args.message_plan.resolve(),
        args.output.resolve(),
    }
    if len(resolved) != 3:
        raise ControlTargetRelocationPlanError(
            "MES control-target relocation input and output paths must differ"
        )
    try:
        editable_document = json.loads(args.editable_ir.read_text(encoding="utf-8"))
        message_plan = json.loads(args.message_plan.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise ControlTargetRelocationPlanError(
            "MES control-target relocation input JSON could not be read"
        ) from error
    if not isinstance(editable_document, dict) or not isinstance(message_plan, dict):
        raise ControlTargetRelocationPlanError(
            "MES control-target relocation inputs must be JSON objects"
        )
    document = plan(editable_document, message_plan)
    editable_ir.publish_new(
        args.output, editable_ir.canonical_json_bytes(document) + b"\n"
    )
    print(
        "MES_CONTROL_TARGET_RELOCATION_PLAN_PASS "
        f"schema={document['schema']} "
        f"entry={document['source_identity'].get('entry', '')} "
        f"patches={len(document['target_patches'])} "
        f"remaining_blockers={len(document['remaining_blockers'])} "
        f"assembly_ready={str(document['assembly_ready']).lower()} "
        f"payload_sha256={document['payload_sha256']}"
    )


if __name__ == "__main__":
    main()
