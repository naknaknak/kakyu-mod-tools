from __future__ import annotations

import argparse
import copy
import hashlib
import json
from pathlib import Path
from typing import Any

import compile_mes_noop as noop_compiler
import decompile_mes_handoff as decompiler
import plan_mes_control_target_edit as target_planner
import prepare_mes_editable_ir as editable_ir
from payload_values import canonical_payload_bytes, fingerprint, is_sha256 as _is_sha256


AUDIT_SCHEMA = "kakyu_mes_control_target_edit_compile_audit/v1"
TOP_LEVEL_KEYS = {
    "ok", "schema", "producer", "compatibility", "source_identity", "inputs",
    "source", "output", "operation", "source_control", "replacement_target",
    "patch", "coverage", "invariants", "payload_sha256",
}
SUMMARY_KEYS = {
    "size", "entry_count", "code_offset", "code_size", "entry_sha256",
    "bytecode_sha256", "preamble_sha256", "address_table_sha256",
}
OPERATION_KEYS = {
    "kind", "reference_kind", "source_offset", "current_target_offset",
    "replacement_target_offset",
}
SOURCE_CONTROL_KEYS = {
    "node_id", "source_region_id", "instruction_start", "instruction_end",
    "source_instruction_sha256", "replacement_instruction_sha256", "op",
    "command_id", "reference_id", "reference_kind", "operand_start",
    "operand_end", "expression_kind", "expression_start", "expression_end",
    "expression_sha256", "current_target_node_id",
}
REPLACEMENT_TARGET_KEYS = {
    "node_id", "source_region_id", "instruction_start", "instruction_end",
    "instruction_sha256", "op", "command_id",
}
PATCH_KEYS = {
    "operand_start", "operand_end", "source_raw_hex", "output_raw_hex",
    "changed_code_offsets", "encoding",
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
    "changed_offsets_exact", "source_container_not_modified",
}
COMPATIBILITY = {
    "policy": "exact_same_width_control_target_edit_plan_only",
    "input_editable_schema": editable_ir.EDITABLE_IR_SCHEMA,
    "input_plan_schema": target_planner.PLAN_SCHEMA,
    "input_decompiler_schema": decompiler.DECOMPILER_IR_SCHEMA,
    "unknown_audit_schema": "reject",
    "unknown_v1_field": "reject",
    "output_policy": "new_file_only",
    "relocation": "forbidden",
    "native_engine_compatibility": "unverified",
}
SOURCE_IDENTITY_KEYS = {"archive", "entry", "source_kind", "archive_sha256"}


class ControlTargetEditCompileError(ValueError):
    pass


def compile_target_edit(
    editable_document: dict[str, Any], plan_document: dict[str, Any]
) -> tuple[bytes, dict[str, Any]]:
    editable_ir.validate(editable_document)
    target_planner.validate(plan_document, editable_document)
    if plan_document.get("assembly_ready") is not True:
        raise ControlTargetEditCompileError(
            "MES control-target edit plan is not assembly ready"
        )
    source_ir = editable_document["source_ir"]
    source = decompiler.reconstruct_container(source_ir)
    source_before = bytes(source)
    source_header = noop_compiler.reopen_container(source)
    code_offset = int(source_header["code_offset"])
    source_code = source[code_offset:]
    control = plan_document["source_control"]
    patch = plan_document["patch"]
    start = int(control["instruction_start"])
    end = int(control["instruction_end"])
    operand_start = int(patch["operand_start"])
    operand_end = int(patch["operand_end"])
    source_instruction = _hex_bytes(
        patch["source_instruction_raw_hex"], "source instruction"
    )
    output_instruction = _hex_bytes(
        patch["output_instruction_raw_hex"], "output instruction"
    )
    source_operand = _hex_bytes(patch["source_raw_hex"], "source target operand")
    output_operand = _hex_bytes(patch["output_raw_hex"], "output target operand")
    relative_start = operand_start - start
    relative_end = operand_end - start
    if (
        start < 0 or end <= start or end > len(source_code)
        or len(source_instruction) != end - start
        or len(output_instruction) != len(source_instruction)
        or source_code[start:end] != source_instruction
        or operand_end - operand_start != 4
        or source_instruction[relative_start:relative_end] != source_operand
        or output_instruction[relative_start:relative_end] != output_operand
        or source_instruction[:relative_start] != output_instruction[:relative_start]
        or source_instruction[relative_end:] != output_instruction[relative_end:]
    ):
        raise ControlTargetEditCompileError(
            "MES control-target edit compile boundary or instruction changed"
        )
    output_code = source_code[:start] + output_instruction + source_code[end:]
    output = source[:code_offset] + output_code
    reopened = noop_compiler.reopen_container(output)
    if (
        reopened["entry_count"] != source_header["entry_count"]
        or reopened["entry_offsets"] != source_header["entry_offsets"]
        or reopened["code_offset"] != source_header["code_offset"]
        or reopened["code_size"] != source_header["code_size"]
    ):
        raise ControlTargetEditCompileError(
            "MES control-target edit compile changed container layout"
        )
    changed_offsets = [
        index for index, (before, after) in enumerate(zip(source_code, output_code))
        if before != after
    ]
    expected_changed = [
        operand_start + index
        for index, (before, after) in enumerate(zip(source_operand, output_operand))
        if before != after
    ]
    if not changed_offsets or changed_offsets != expected_changed:
        raise ControlTargetEditCompileError(
            "MES control-target edit changed offsets differ from the plan"
        )
    if source != source_before:
        raise ControlTargetEditCompileError(
            "MES control-target edit compile changed its source buffer"
        )
    coverage = source_ir["coverage"]
    operation = plan_document["operation"]
    target = plan_document["replacement_target"]
    audit = {
        "ok": True,
        "schema": AUDIT_SCHEMA,
        "producer": {
            "implementation": "python_phase6_control_target_edit_compiler",
            "contract": AUDIT_SCHEMA,
        },
        "compatibility": copy.deepcopy(COMPATIBILITY),
        "source_identity": copy.deepcopy(source_ir["source_identity"]),
        "inputs": {
            "editable_ir_sha256": editable_document["payload_sha256"],
            "decompiler_ir_sha256": source_ir["payload_sha256"],
            "control_target_edit_plan_sha256": plan_document["payload_sha256"],
        },
        "source": _container_summary(source, source_header),
        "output": _container_summary(output, reopened),
        "operation": {
            "kind": "retarget_control_flow",
            "reference_kind": str(operation["reference_kind"]),
            "source_offset": start,
            "current_target_offset": int(control["current_target_offset"]),
            "replacement_target_offset": int(target["instruction_start"]),
        },
        "source_control": {
            "node_id": str(control["node_id"]),
            "source_region_id": str(control["source_region_id"]),
            "instruction_start": start,
            "instruction_end": end,
            "source_instruction_sha256": str(control["instruction_raw_sha256"]),
            "replacement_instruction_sha256": str(patch["output_instruction_raw_sha256"]),
            "op": str(control["op"]),
            "command_id": int(control["command_id"]),
            "reference_id": str(control["reference_id"]),
            "reference_kind": str(control["reference_kind"]),
            "operand_start": operand_start,
            "operand_end": operand_end,
            "expression_kind": str(control["expression_kind"]),
            "expression_start": int(control["expression_start"]),
            "expression_end": int(control["expression_end"]),
            "expression_sha256": str(control["expression_raw_sha256"]),
            "current_target_node_id": str(control["current_target_node_id"]),
        },
        "replacement_target": {
            "node_id": str(target["node_id"]),
            "source_region_id": str(target["source_region_id"]),
            "instruction_start": int(target["instruction_start"]),
            "instruction_end": int(target["instruction_end"]),
            "instruction_sha256": str(target["instruction_raw_sha256"]),
            "op": str(target["op"]),
            "command_id": int(target["command_id"]),
        },
        "patch": {
            "operand_start": operand_start,
            "operand_end": operand_end,
            "source_raw_hex": source_operand.hex(),
            "output_raw_hex": output_operand.hex(),
            "changed_code_offsets": changed_offsets,
            "encoding": "u32_le_absolute_code_offset",
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
            "code_prefix_preserved": output_code[:start] == source_code[:start],
            "replacement_instruction_exact": output_code[start:end] == output_instruction,
            "code_suffix_preserved": output_code[end:] == source_code[end:],
            "changed_offsets_exact": changed_offsets == expected_changed,
            "source_container_not_modified": source == source_before,
        },
    }
    if not all(audit["invariants"].values()):
        raise ControlTargetEditCompileError(
            "MES control-target edit compile invariant failed"
        )
    audit["payload_sha256"] = fingerprint(audit)
    validate_audit(audit)
    return output, audit


def validate_audit(
    audit: dict[str, Any], editable_document: dict[str, Any] | None = None,
    plan_document: dict[str, Any] | None = None, output: bytes | None = None,
) -> dict[str, Any]:
    if audit.get("ok") is not True or audit.get("schema") != AUDIT_SCHEMA or set(audit) != TOP_LEVEL_KEYS:
        raise ControlTargetEditCompileError(
            "MES control-target edit compile audit schema or fields changed"
        )
    if audit.get("producer") != {
        "implementation": "python_phase6_control_target_edit_compiler",
        "contract": AUDIT_SCHEMA,
    } or audit.get("compatibility") != COMPATIBILITY:
        raise ControlTargetEditCompileError(
            "MES control-target edit compile producer or compatibility changed"
        )
    retained = audit.get("payload_sha256")
    if not _is_sha256(retained) or fingerprint(audit) != retained:
        raise ControlTargetEditCompileError(
            "MES control-target edit compile audit fingerprint changed"
        )
    source_identity = audit.get("source_identity")
    inputs = audit.get("inputs")
    if not isinstance(source_identity, dict) or not set(source_identity).issubset(SOURCE_IDENTITY_KEYS) or not all(isinstance(source_identity.get(key), str) and source_identity[key] for key in ("archive", "entry")) or not _is_sha256(source_identity.get("archive_sha256")) or not isinstance(inputs, dict) or set(inputs) != {
        "editable_ir_sha256", "decompiler_ir_sha256", "control_target_edit_plan_sha256",
    } or not all(_is_sha256(value) for value in inputs.values()):
        raise ControlTargetEditCompileError(
            "MES control-target edit compile input identity changed"
        )
    for key in ("source", "output"):
        if not _valid_summary(audit.get(key)):
            raise ControlTargetEditCompileError(
                "MES control-target edit compile container summary changed"
            )
    source = audit["source"]
    output_row = audit["output"]
    operation = audit.get("operation")
    control = audit.get("source_control")
    target = audit.get("replacement_target")
    patch = audit.get("patch")
    coverage = audit.get("coverage")
    if not isinstance(operation, dict) or set(operation) != OPERATION_KEYS or operation.get("kind") != "retarget_control_flow" or operation.get("reference_kind") not in target_planner.SUPPORTED_FORMS or any(not _is_nonnegative_int(operation.get(key)) for key in ("source_offset", "current_target_offset", "replacement_target_offset")) or operation["current_target_offset"] == operation["replacement_target_offset"]:
        raise ControlTargetEditCompileError("MES control-target edit compile operation changed")
    if not isinstance(control, dict) or set(control) != SOURCE_CONTROL_KEYS or not isinstance(target, dict) or set(target) != REPLACEMENT_TARGET_KEYS or not isinstance(patch, dict) or set(patch) != PATCH_KEYS:
        raise ControlTargetEditCompileError("MES control-target edit compile component fields changed")
    if any(not _is_nonnegative_int(control.get(key)) for key in ("instruction_start", "instruction_end", "command_id", "operand_start", "operand_end", "expression_start", "expression_end")) or any(not _is_sha256(control.get(key)) for key in ("source_instruction_sha256", "replacement_instruction_sha256", "expression_sha256")) or not all(isinstance(control.get(key), str) and control[key] for key in ("node_id", "source_region_id", "op", "reference_id", "reference_kind", "expression_kind", "current_target_node_id")):
        raise ControlTargetEditCompileError("MES control-target edit compile source control changed")
    if any(not _is_nonnegative_int(target.get(key)) for key in ("instruction_start", "instruction_end", "command_id")) or not _is_sha256(target.get("instruction_sha256")) or not all(isinstance(target.get(key), str) and target[key] for key in ("node_id", "source_region_id", "op")):
        raise ControlTargetEditCompileError("MES control-target edit compile replacement target changed")
    changed = patch.get("changed_code_offsets")
    if any(not _is_nonnegative_int(patch.get(key)) for key in ("operand_start", "operand_end")) or patch.get("encoding") != "u32_le_absolute_code_offset" or not isinstance(changed, list) or not changed or any(not _is_nonnegative_int(value) for value in changed) or changed != sorted(set(changed)) or int(patch["operand_end"]) - int(patch["operand_start"]) != 4 or _decode_u32(patch.get("source_raw_hex")) != int(operation["current_target_offset"]) or _decode_u32(patch.get("output_raw_hex")) != int(operation["replacement_target_offset"]) or any(value < int(patch["operand_start"]) or value >= int(patch["operand_end"]) for value in changed):
        raise ControlTargetEditCompileError("MES control-target edit compile patch changed")
    source_operand = _hex_bytes(patch["source_raw_hex"], "audit source target operand")
    output_operand = _hex_bytes(patch["output_raw_hex"], "audit output target operand")
    expected_changed = [
        int(patch["operand_start"]) + index
        for index, (before, after) in enumerate(zip(source_operand, output_operand))
        if before != after
    ]
    if changed != expected_changed:
        raise ControlTargetEditCompileError("MES control-target edit compile patch changed")
    if int(operation["source_offset"]) != int(control["instruction_start"]) or int(operation["replacement_target_offset"]) != int(target["instruction_start"]) or control["reference_kind"] != operation["reference_kind"] or int(control["operand_start"]) != int(patch["operand_start"]) or int(control["operand_end"]) != int(patch["operand_end"]):
        raise ControlTargetEditCompileError("MES control-target edit compile coordinate binding changed")
    if not isinstance(coverage, dict) or set(coverage) != COVERAGE_KEYS or any(not _is_nonnegative_int(value) for value in coverage.values()) or int(coverage["node_count"]) != int(coverage["typed_node_count"]) + int(coverage["opaque_node_count"]) or int(coverage["code_bytes"]) != int(source["code_size"]):
        raise ControlTargetEditCompileError("MES control-target edit compile coverage changed")
    invariants = audit.get("invariants")
    if not isinstance(invariants, dict) or set(invariants) != INVARIANT_KEYS or not all(value is True for value in invariants.values()):
        raise ControlTargetEditCompileError("MES control-target edit compile invariants changed")
    if any(output_row[key] != source[key] for key in ("size", "entry_count", "code_offset", "code_size", "preamble_sha256", "address_table_sha256")):
        raise ControlTargetEditCompileError("MES control-target edit compile layout preservation changed")
    if editable_document is not None or plan_document is not None or output is not None:
        if editable_document is None or plan_document is None or output is None:
            raise ControlTargetEditCompileError(
                "MES control-target edit compile validation inputs are incomplete"
            )
        expected_output, expected_audit = compile_target_edit(editable_document, plan_document)
        if expected_output != output or expected_audit != audit:
            raise ControlTargetEditCompileError(
                "MES control-target edit compile audit differs from its source"
            )
    return {"ok": True, "schema": AUDIT_SCHEMA, "payload_sha256": retained}


def _container_summary(payload: bytes, header: dict[str, Any]) -> dict[str, Any]:
    code_offset = int(header["code_offset"])
    preamble = payload[:code_offset]
    return {
        "size": len(payload), "entry_count": int(header["entry_count"]),
        "code_offset": code_offset, "code_size": int(header["code_size"]),
        "entry_sha256": hashlib.sha256(payload).hexdigest(),
        "bytecode_sha256": hashlib.sha256(payload[code_offset:]).hexdigest(),
        "preamble_sha256": hashlib.sha256(preamble).hexdigest(),
        "address_table_sha256": hashlib.sha256(preamble).hexdigest(),
    }


def _valid_summary(value: Any) -> bool:
    return isinstance(value, dict) and set(value) == SUMMARY_KEYS and all(_is_nonnegative_int(value.get(key)) for key in ("size", "entry_count", "code_offset", "code_size")) and all(_is_sha256(value.get(key)) for key in ("entry_sha256", "bytecode_sha256", "preamble_sha256", "address_table_sha256")) and int(value["size"]) == int(value["code_offset"]) + int(value["code_size"])


def _hex_bytes(value: Any, label: str) -> bytes:
    if not isinstance(value, str):
        raise ControlTargetEditCompileError(f"MES control-target edit {label} is missing")
    try:
        return bytes.fromhex(value)
    except ValueError as error:
        raise ControlTargetEditCompileError(f"MES control-target edit {label} is invalid") from error


def _decode_u32(value: Any) -> int | None:
    try:
        raw = bytes.fromhex(value) if isinstance(value, str) else b""
    except ValueError:
        return None
    return int.from_bytes(raw, "little") if len(raw) == 4 else None


def _is_nonnegative_int(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value >= 0


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Compile one validated MES control-target edit into a new container and compact audit."
    )
    parser.add_argument("editable_ir", type=Path)
    parser.add_argument("plan", type=Path)
    parser.add_argument("output_mes", type=Path)
    parser.add_argument("audit_output", type=Path)
    args = parser.parse_args()
    paths = {args.editable_ir.resolve(), args.plan.resolve(), args.output_mes.resolve(), args.audit_output.resolve()}
    if len(paths) != 4:
        raise ControlTargetEditCompileError("MES control-target edit compile paths must differ")
    if args.output_mes.exists() or args.audit_output.exists():
        raise ControlTargetEditCompileError("MES control-target edit compile output already exists")
    editable_document = json.loads(args.editable_ir.read_text(encoding="utf-8"))
    plan_document = json.loads(args.plan.read_text(encoding="utf-8"))
    output, audit = compile_target_edit(editable_document, plan_document)
    published_mes = False
    published_audit = False
    try:
        editable_ir.publish_new(args.output_mes, output)
        published_mes = True
        editable_ir.publish_new(args.audit_output, editable_ir.canonical_json_bytes(audit) + b"\n")
        published_audit = True
        validate_audit(json.loads(args.audit_output.read_text(encoding="utf-8")), editable_document, plan_document, args.output_mes.read_bytes())
    except BaseException:
        if published_audit and args.audit_output.is_file():
            args.audit_output.unlink()
        if published_mes and args.output_mes.is_file():
            args.output_mes.unlink()
        raise
    print(
        "MES_CONTROL_TARGET_EDIT_COMPILE_PASS "
        f"schema={AUDIT_SCHEMA} entry={audit['source_identity']['entry']} "
        f"kind={audit['operation']['reference_kind']} "
        f"source=0x{audit['operation']['source_offset']:X} "
        f"old_target=0x{audit['operation']['current_target_offset']:X} "
        f"new_target=0x{audit['operation']['replacement_target_offset']:X} "
        f"bytes={audit['output']['size']} payload_sha256={audit['payload_sha256']}"
    )


if __name__ == "__main__":
    main()
