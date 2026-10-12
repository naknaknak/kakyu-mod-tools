from __future__ import annotations

import argparse
import copy
import json
from pathlib import Path
from typing import Any

import compile_mes_message_relocation as message_compiler
import compile_mes_noop as noop_compiler
import decompile_mes_handoff as decompiler
import plan_mes_control_target_relocation as control_planner
import plan_mes_message_relocation as message_planner
import prepare_mes_editable_ir as editable_ir
from payload_values import canonical_payload_bytes, fingerprint, is_sha256 as _is_sha256


AUDIT_SCHEMA = "kakyu_mes_control_target_compile_audit/v1"
TOP_LEVEL_KEYS = {
    "ok",
    "schema",
    "producer",
    "compatibility",
    "source_identity",
    "inputs",
    "source",
    "output",
    "operation",
    "relocation",
    "target_patches",
    "coverage",
    "invariants",
    "payload_sha256",
}
COMPATIBILITY = {
    "policy": "exact_message_and_control_target_plans",
    "input_editable_schema": editable_ir.EDITABLE_IR_SCHEMA,
    "input_decompiler_schema": decompiler.DECOMPILER_IR_SCHEMA,
    "input_message_plan_schema": message_planner.PLAN_SCHEMA,
    "input_control_plan_schema": control_planner.PLAN_SCHEMA,
    "unknown_audit_schema": "reject",
    "unknown_v1_field": "reject",
    "output_policy": "new_file_only",
    "native_engine_compatibility": "unverified",
}
INVARIANTS = {
    "message_plan_validated": True,
    "control_target_plan_ready": True,
    "source_target_operands_matched": True,
    "target_patches_applied_exactly": True,
    "output_reopened": True,
    "entry_count_preserved": True,
    "code_size_delta_exact": True,
    "address_table_relocated_exactly": True,
    "nonaddress_preamble_bytes_preserved": True,
    "only_planned_code_ranges_changed": True,
    "opaque_records_not_shifted": True,
    "source_container_not_modified": True,
}


class ControlTargetCompileError(ValueError):
    pass


def compile_message_with_targets(
    editable_document: dict[str, Any],
    message_plan: dict[str, Any],
    control_plan: dict[str, Any],
) -> tuple[bytes, dict[str, Any]]:
    editable_ir.validate(editable_document)
    message_planner.validate(message_plan, editable_document)
    control_planner.validate(control_plan, editable_document, message_plan)
    if (
        control_plan.get("assembly_ready") is not True
        or control_plan.get("remaining_blockers")
    ):
        raise ControlTargetCompileError("MES control-target relocation plan is blocked")

    source_ir = editable_document["source_ir"]
    source = decompiler.reconstruct_container(source_ir)
    source_before = bytes(source)
    source_header = noop_compiler.reopen_container(source)
    target = message_plan["target"]
    relocation = message_plan["relocation"]
    node_start = int(target["instruction_start"])
    node_end = int(target["instruction_end"])
    replacement_node = _bytes_from_hex(
        target.get("replacement_node_raw_hex"), "replacement instruction"
    )
    source_code = source[source_header["code_offset"] :]
    if node_start < 0 or node_end <= node_start or node_end > len(source_code):
        raise ControlTargetCompileError("MES control-target message boundary is invalid")
    expected_code = bytearray(
        source_code[:node_start] + replacement_node + source_code[node_end:]
    )
    delta = len(expected_code) - len(source_code)
    if delta != int(relocation["delta"]):
        raise ControlTargetCompileError("MES control-target compile byte delta changed")

    message_output_start = node_start
    message_output_end = int(relocation["output_target_end"])
    patch_ranges: list[tuple[int, int]] = []
    for patch in control_plan["target_patches"]:
        source_operand_start = int(patch["source_operand_start"])
        source_operand_end = int(patch["source_operand_end"])
        output_operand_start = int(patch["output_operand_start"])
        output_operand_end = int(patch["output_operand_end"])
        source_raw = _bytes_from_hex(patch.get("source_raw_hex"), "source target operand")
        output_raw = _bytes_from_hex(patch.get("output_raw_hex"), "output target operand")
        if (
            source_operand_start < 0
            or source_operand_end - source_operand_start != 4
            or source_operand_end > len(source_code)
            or source_code[source_operand_start:source_operand_end] != source_raw
            or output_operand_start < 0
            or output_operand_end - output_operand_start != 4
            or output_operand_end > len(expected_code)
            or bytes(expected_code[output_operand_start:output_operand_end]) != source_raw
            or _ranges_overlap(
                output_operand_start,
                output_operand_end,
                message_output_start,
                message_output_end,
            )
        ):
            raise ControlTargetCompileError(
                "MES control-target operand bytes or output boundary changed"
            )
        expected_code[output_operand_start:output_operand_end] = output_raw
        patch_ranges.append((output_operand_start, output_operand_end))

    output_preamble = bytearray(source[: source_header["code_offset"]])
    updates = _validated_address_updates(message_plan, source_header)
    for index, output_offset in updates.items():
        position = 4 + index * 4
        output_preamble[position : position + 4] = output_offset.to_bytes(4, "little")
    output = bytes(output_preamble) + bytes(expected_code)
    reopened = noop_compiler.reopen_container(output)
    expected_offsets = [
        updates.get(index, source_offset)
        for index, source_offset in enumerate(source_header["entry_offsets"])
    ]
    if reopened["entry_offsets"] != expected_offsets:
        raise ControlTargetCompileError(
            "MES control-target address table did not relocate exactly"
        )
    if reopened["code_size"] != int(relocation["output_code_size"]):
        raise ControlTargetCompileError("MES control-target output code size changed")
    if source != source_before:
        raise ControlTargetCompileError("MES control-target compile changed its source buffer")

    coverage = source_ir["coverage"]
    audit = {
        "ok": True,
        "schema": AUDIT_SCHEMA,
        "producer": {
            "implementation": "python_phase6_control_target_compiler",
            "contract": AUDIT_SCHEMA,
        },
        "compatibility": copy.deepcopy(COMPATIBILITY),
        "source_identity": copy.deepcopy(source_ir["source_identity"]),
        "inputs": {
            "editable_ir_sha256": editable_document["payload_sha256"],
            "decompiler_ir_sha256": source_ir["payload_sha256"],
            "message_relocation_plan_sha256": message_plan["payload_sha256"],
            "control_target_plan_sha256": control_plan["payload_sha256"],
        },
        "source": _container_summary(source, source_header),
        "output": _container_summary(output, reopened),
        "operation": {
            "kind": "replace_message",
            "source_offset": int(message_plan["operation"]["source_offset"]),
            "source_raw_sha256": str(message_plan["operation"]["raw_sha256"]),
            "replacement_raw_sha256": str(target["replacement_raw_sha256"]),
            "source_byte_length": int(target["source_byte_length"]),
            "replacement_byte_length": int(target["replacement_byte_length"]),
            "encoding": "cp932",
        },
        "relocation": {
            "delta": delta,
            "pivot_source_end": int(relocation["pivot_source_end"]),
            "source_code_size": int(relocation["source_code_size"]),
            "output_code_size": int(relocation["output_code_size"]),
            "source_instruction_start": node_start,
            "source_instruction_end": node_end,
            "output_instruction_end": message_output_end,
            "address_table_update_count": len(updates),
            "affected_reference_count": len(message_plan["affected_references"]),
            "target_patch_count": len(control_plan["target_patches"]),
        },
        "target_patches": copy.deepcopy(control_plan["target_patches"]),
        "coverage": {
            "output_region_count": _output_region_count(reopened),
            "source_node_count": int(coverage["node_count"]),
            "source_typed_node_count": int(coverage["typed_node_count"]),
            "source_opaque_node_count": int(coverage["opaque_node_count"]),
            "source_code_bytes": len(source_code),
            "output_code_bytes": len(expected_code),
        },
        "invariants": copy.deepcopy(INVARIANTS),
    }
    if int(coverage["opaque_node_count"]) > 0:
        audit["invariants"]["opaque_records_not_shifted"] = not any(
            blocker.get("code") == "opaque_boundary_would_shift"
            for blocker in message_plan["blockers"]
        )
    if not all(audit["invariants"].values()):
        raise ControlTargetCompileError("MES control-target compile invariant failed")
    audit["payload_sha256"] = fingerprint(audit)
    validate_audit(audit)
    return output, audit


def validate_audit(
    audit: dict[str, Any],
    editable_document: dict[str, Any] | None = None,
    message_plan: dict[str, Any] | None = None,
    control_plan: dict[str, Any] | None = None,
    output: bytes | None = None,
) -> dict[str, Any]:
    if (
        audit.get("ok") is not True
        or audit.get("schema") != AUDIT_SCHEMA
        or set(audit) != TOP_LEVEL_KEYS
    ):
        raise ControlTargetCompileError(
            "MES control-target compile audit schema or fields changed"
        )
    if audit.get("producer") != {
        "implementation": "python_phase6_control_target_compiler",
        "contract": AUDIT_SCHEMA,
    }:
        raise ControlTargetCompileError("MES control-target compile audit producer changed")
    if audit.get("compatibility") != COMPATIBILITY:
        raise ControlTargetCompileError(
            "MES control-target compile compatibility changed"
        )
    retained = audit.get("payload_sha256")
    if not _is_sha256(retained) or fingerprint(audit) != retained:
        raise ControlTargetCompileError(
            "MES control-target compile audit fingerprint changed"
        )
    inputs = audit.get("inputs")
    source_identity = audit.get("source_identity")
    if (
        not isinstance(source_identity, dict)
        or not isinstance(source_identity.get("entry"), str)
        or not source_identity["entry"]
        or not set(source_identity).issubset(
            {"archive", "entry", "source_kind", "archive_sha256"}
        )
        or not _is_sha256(source_identity.get("archive_sha256"))
        or not isinstance(inputs, dict)
        or set(inputs)
        != {
            "editable_ir_sha256",
            "decompiler_ir_sha256",
            "message_relocation_plan_sha256",
            "control_target_plan_sha256",
        }
        or not all(_is_sha256(value) for value in inputs.values())
    ):
        raise ControlTargetCompileError(
            "MES control-target compile input identity changed"
        )
    if not _valid_container_summary(audit.get("source")) or not _valid_container_summary(
        audit.get("output")
    ):
        raise ControlTargetCompileError(
            "MES control-target compile container summary changed"
        )
    operation = audit.get("operation")
    if (
        not isinstance(operation, dict)
        or set(operation)
        != {
            "kind",
            "source_offset",
            "source_raw_sha256",
            "replacement_raw_sha256",
            "source_byte_length",
            "replacement_byte_length",
            "encoding",
        }
        or operation.get("kind") != "replace_message"
        or operation.get("encoding") != "cp932"
        or any(
            not _is_nonnegative_int(operation.get(key))
            for key in ("source_offset", "source_byte_length", "replacement_byte_length")
        )
        or not _is_sha256(operation.get("source_raw_sha256"))
        or not _is_sha256(operation.get("replacement_raw_sha256"))
    ):
        raise ControlTargetCompileError("MES control-target compile operation changed")
    relocation = audit.get("relocation")
    if (
        not isinstance(relocation, dict)
        or set(relocation)
        != {
            "delta",
            "pivot_source_end",
            "source_code_size",
            "output_code_size",
            "source_instruction_start",
            "source_instruction_end",
            "output_instruction_end",
            "address_table_update_count",
            "affected_reference_count",
            "target_patch_count",
        }
        or not _is_int(relocation.get("delta"))
        or any(
            not _is_nonnegative_int(relocation.get(key))
            for key in set(relocation) - {"delta"}
        )
        or int(relocation["delta"])
        != int(operation["replacement_byte_length"])
        - int(operation["source_byte_length"])
        or int(relocation["output_code_size"])
        != int(relocation["source_code_size"]) + int(relocation["delta"])
        or int(relocation["output_instruction_end"])
        != int(relocation["source_instruction_end"]) + int(relocation["delta"])
    ):
        raise ControlTargetCompileError("MES control-target compile relocation changed")
    patches = audit.get("target_patches")
    if not isinstance(patches, list):
        raise ControlTargetCompileError("MES control-target compile patches changed")
    control_planner._validate_patch_rows(patches)
    if len(patches) != int(relocation["target_patch_count"]):
        raise ControlTargetCompileError("MES control-target compile patch count changed")
    coverage = audit.get("coverage")
    source_row = audit["source"]
    output_row = audit["output"]
    if (
        not isinstance(coverage, dict)
        or set(coverage)
        != {
            "output_region_count",
            "source_node_count",
            "source_typed_node_count",
            "source_opaque_node_count",
            "source_code_bytes",
            "output_code_bytes",
        }
        or any(not _is_nonnegative_int(value) for value in coverage.values())
        or int(coverage["source_node_count"])
        != int(coverage["source_typed_node_count"])
        + int(coverage["source_opaque_node_count"])
        or int(coverage["source_code_bytes"]) != int(source_row["code_size"])
        or int(coverage["output_code_bytes"]) != int(output_row["code_size"])
        or int(relocation["source_code_size"]) != int(source_row["code_size"])
        or int(relocation["output_code_size"]) != int(output_row["code_size"])
        or int(output_row["entry_count"]) != int(source_row["entry_count"])
        or int(output_row["code_offset"]) != int(source_row["code_offset"])
        or int(output_row["code_size"])
        != int(source_row["code_size"]) + int(relocation["delta"])
        or int(output_row["size"]) != int(source_row["size"]) + int(relocation["delta"])
    ):
        raise ControlTargetCompileError("MES control-target compile coverage changed")
    if audit.get("invariants") != INVARIANTS:
        raise ControlTargetCompileError("MES control-target compile invariants changed")
    provided = (editable_document, message_plan, control_plan, output)
    if any(value is not None for value in provided):
        if any(value is None for value in provided):
            raise ControlTargetCompileError(
                "MES control-target compile validation inputs are incomplete"
            )
        expected_output, expected_audit = compile_message_with_targets(
            editable_document, message_plan, control_plan
        )
        if expected_output != output or expected_audit != audit:
            raise ControlTargetCompileError(
                "MES control-target compile audit differs from its source"
            )
    return {"ok": True, "schema": AUDIT_SCHEMA, "payload_sha256": retained}


def _validated_address_updates(
    plan_document: dict[str, Any], source_header: dict[str, Any]
) -> dict[int, int]:
    try:
        return message_compiler._validated_address_updates(plan_document, source_header)
    except message_compiler.MessageCompileError as error:
        raise ControlTargetCompileError(str(error)) from error


def _container_summary(payload: bytes, header: dict[str, Any]) -> dict[str, Any]:
    return message_compiler._container_summary(payload, header)


def _output_region_count(header: dict[str, Any]) -> int:
    return message_compiler._output_region_count(header)


def _valid_container_summary(value: Any) -> bool:
    if not isinstance(value, dict) or set(value) != {
        "size",
        "entry_count",
        "code_offset",
        "code_size",
        "entry_sha256",
        "bytecode_sha256",
        "preamble_sha256",
    }:
        return False
    return (
        all(
            _is_nonnegative_int(value.get(key))
            for key in ("size", "entry_count", "code_offset", "code_size")
        )
        and all(
            _is_sha256(value.get(key))
            for key in ("entry_sha256", "bytecode_sha256", "preamble_sha256")
        )
        and int(value["size"]) == int(value["code_offset"]) + int(value["code_size"])
    )


def _bytes_from_hex(value: Any, label: str) -> bytes:
    try:
        return message_compiler._bytes_from_hex(value, label)
    except message_compiler.MessageCompileError as error:
        raise ControlTargetCompileError(str(error)) from error


def _ranges_overlap(left_start: int, left_end: int, right_start: int, right_end: int) -> bool:
    return left_start < right_end and right_start < left_end


def _is_nonnegative_int(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value >= 0


def _is_int(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool)


def main() -> None:
    parser = argparse.ArgumentParser(
        description=(
            "Compile one variable-length CP932 MES message plus exact control-target "
            "target repairs into a new container and audit."
        )
    )
    parser.add_argument("editable_ir", type=Path)
    parser.add_argument("message_plan", type=Path)
    parser.add_argument("control_plan", type=Path)
    parser.add_argument("output_mes", type=Path)
    parser.add_argument("audit_output", type=Path)
    args = parser.parse_args()
    resolved = {
        args.editable_ir.resolve(),
        args.message_plan.resolve(),
        args.control_plan.resolve(),
        args.output_mes.resolve(),
        args.audit_output.resolve(),
    }
    if len(resolved) != 5:
        raise ControlTargetCompileError(
            "MES control-target compile input and output paths must differ"
        )
    if args.output_mes.exists() or args.audit_output.exists():
        raise ControlTargetCompileError("MES control-target compile output already exists")
    try:
        editable_document = json.loads(args.editable_ir.read_text(encoding="utf-8"))
        message_plan = json.loads(args.message_plan.read_text(encoding="utf-8"))
        control_plan = json.loads(args.control_plan.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise ControlTargetCompileError(
            "MES control-target compile input JSON could not be read"
        ) from error
    if not all(
        isinstance(document, dict)
        for document in (editable_document, message_plan, control_plan)
    ):
        raise ControlTargetCompileError(
            "MES control-target compile inputs must be JSON objects"
        )
    output, audit = compile_message_with_targets(
        editable_document, message_plan, control_plan
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
            reopened_audit,
            editable_document,
            message_plan,
            control_plan,
            args.output_mes.read_bytes(),
        )
    except BaseException:
        if published_audit and args.audit_output.is_file():
            args.audit_output.unlink()
        if published_mes and args.output_mes.is_file():
            args.output_mes.unlink()
        raise
    print(
        "MES_CONTROL_TARGET_COMPILE_PASS "
        f"schema={audit['schema']} "
        f"entry={audit['source_identity'].get('entry', '')} "
        f"delta={audit['relocation']['delta']} "
        f"patches={audit['relocation']['target_patch_count']} "
        f"bytes={audit['output']['size']} "
        f"payload_sha256={audit['payload_sha256']}"
    )


if __name__ == "__main__":
    main()
