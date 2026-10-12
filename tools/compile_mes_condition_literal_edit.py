from __future__ import annotations

import argparse
import copy
import hashlib
import json
from pathlib import Path
from typing import Any

import compile_mes_noop as noop_compiler
import decompile_mes_handoff as decompiler
import plan_mes_condition_literal_edit as condition_planner
import prepare_mes_editable_ir as editable_ir
from payload_values import canonical_payload_bytes, fingerprint, is_sha256 as _is_sha256


AUDIT_SCHEMA = "kakyu_mes_condition_literal_compile_audit/v1"
TOP_LEVEL_KEYS = {
    "ok", "schema", "producer", "compatibility", "source_identity", "inputs",
    "source", "output", "operation", "target", "coverage", "invariants",
    "payload_sha256",
}
SUMMARY_KEYS = {
    "size", "entry_count", "code_offset", "code_size", "entry_sha256",
    "bytecode_sha256", "preamble_sha256", "address_table_sha256",
}
OPERATION_KEYS = {
    "kind", "source_offset", "literal_offset", "source_value",
    "replacement_value", "width", "false_target",
}
TARGET_KEYS = {
    "node_id", "region_id", "instruction_start", "instruction_end",
    "condition_start", "condition_end", "literal_start", "literal_end",
    "source_instruction_sha256", "replacement_instruction_sha256",
    "source_condition_sha256", "replacement_condition_sha256",
    "source_literal_sha256", "replacement_literal_sha256",
    "false_target_reference_id", "false_target_operand_start",
    "false_target_operand_end", "false_target_operand_sha256",
}
INVARIANT_KEYS = {
    "plan_ready", "output_reopened", "container_size_preserved",
    "entry_count_preserved", "code_offset_preserved", "code_size_preserved",
    "address_table_preserved", "preamble_preserved", "code_prefix_preserved",
    "replacement_instruction_exact", "code_suffix_preserved",
    "condition_terminator_preserved", "false_target_operand_preserved",
    "source_container_not_modified",
}
COMPATIBILITY = {
    "policy": "exact_same_width_condition_literal_plan_only",
    "input_editable_schema": editable_ir.EDITABLE_IR_SCHEMA,
    "input_plan_schema": condition_planner.PLAN_SCHEMA,
    "input_decompiler_schema": decompiler.DECOMPILER_IR_SCHEMA,
    "unknown_audit_schema": "reject",
    "unknown_v1_field": "reject",
    "output_policy": "new_file_only",
    "relocation": "forbidden",
    "native_engine_compatibility": "unverified",
}
SOURCE_IDENTITY_KEYS = {"archive", "entry", "source_kind", "archive_sha256"}


class ConditionLiteralCompileError(ValueError):
    pass


def compile_condition_literal(
    editable_document: dict[str, Any], plan_document: dict[str, Any]
) -> tuple[bytes, dict[str, Any]]:
    editable_ir.validate(editable_document)
    condition_planner.validate(plan_document, editable_document)
    if plan_document.get("assembly_ready") is not True:
        raise ConditionLiteralCompileError(
            "MES condition literal edit plan is not assembly ready"
        )
    source_ir = editable_document["source_ir"]
    source = decompiler.reconstruct_container(source_ir)
    source_before = bytes(source)
    source_header = noop_compiler.reopen_container(source)
    code_offset = int(source_header["code_offset"])
    source_code = source[code_offset:]
    target = plan_document["target"]
    replacement = plan_document["replacement"]
    false_target = target["false_target"]
    instruction_start = int(target["instruction_start"])
    instruction_end = int(target["instruction_end"])
    source_instruction = _hex_bytes(
        target["instruction_raw_hex"], "source instruction"
    )
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
    ):
        raise ConditionLiteralCompileError(
            "MES condition literal compile target boundary changed"
        )
    false_target_start = int(false_target["operand_start"])
    false_target_end = int(false_target["operand_end"])
    false_target_raw = _hex_bytes(
        false_target["operand_raw_hex"], "false-target operand"
    )
    target_relative_start = false_target_start - instruction_start
    target_relative_end = false_target_end - instruction_start
    if (
        false_target_start != int(target["condition_end"])
        or false_target_end != instruction_end
        or len(false_target_raw) != 4
        or source_instruction[target_relative_start:target_relative_end]
        != false_target_raw
        or replacement_instruction[target_relative_start:target_relative_end]
        != false_target_raw
    ):
        raise ConditionLiteralCompileError(
            "MES condition literal compile false-target operand changed"
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
        raise ConditionLiteralCompileError(
            "MES condition literal compile changed container layout"
        )
    if source != source_before:
        raise ConditionLiteralCompileError(
            "MES condition literal compile changed its source buffer"
        )
    condition_start = int(target["condition_start"])
    condition_end = int(target["condition_end"])
    literal_start = int(target["literal_start"])
    literal_end = int(target["literal_end"])
    terminator_absolute = int(target["terminator_offset"])
    terminator_relative = terminator_absolute - instruction_start
    coverage = source_ir["coverage"]
    operation = plan_document["operation"]
    audit = {
        "ok": True,
        "schema": AUDIT_SCHEMA,
        "producer": {
            "implementation": "python_phase6_condition_literal_compiler",
            "contract": AUDIT_SCHEMA,
        },
        "compatibility": copy.deepcopy(COMPATIBILITY),
        "source_identity": copy.deepcopy(source_ir["source_identity"]),
        "inputs": {
            "editable_ir_sha256": editable_document["payload_sha256"],
            "decompiler_ir_sha256": source_ir["payload_sha256"],
            "condition_literal_plan_sha256": plan_document["payload_sha256"],
        },
        "source": _container_summary(source, source_header),
        "output": _container_summary(output, reopened),
        "operation": {
            "kind": "replace_condition_literal",
            "source_offset": int(operation["source_offset"]),
            "literal_offset": int(operation["literal_offset"]),
            "source_value": int(target["value"]),
            "replacement_value": int(replacement["value"]),
            "width": int(target["width"]),
            "false_target": int(false_target["value"]),
        },
        "target": {
            "node_id": str(target["node_id"]),
            "region_id": str(target["region_id"]),
            "instruction_start": instruction_start,
            "instruction_end": instruction_end,
            "condition_start": condition_start,
            "condition_end": condition_end,
            "literal_start": literal_start,
            "literal_end": literal_end,
            "source_instruction_sha256": str(target["instruction_raw_sha256"]),
            "replacement_instruction_sha256": str(
                replacement["instruction_raw_sha256"]
            ),
            "source_condition_sha256": str(target["condition_raw_sha256"]),
            "replacement_condition_sha256": str(
                replacement["condition_raw_sha256"]
            ),
            "source_literal_sha256": str(target["literal_raw_sha256"]),
            "replacement_literal_sha256": str(
                replacement["literal_raw_sha256"]
            ),
            "false_target_reference_id": str(false_target["reference_id"]),
            "false_target_operand_start": false_target_start,
            "false_target_operand_end": false_target_end,
            "false_target_operand_sha256": str(
                false_target["operand_raw_sha256"]
            ),
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
            "entry_count_preserved": reopened["entry_count"]
            == source_header["entry_count"],
            "code_offset_preserved": reopened["code_offset"]
            == source_header["code_offset"],
            "code_size_preserved": reopened["code_size"]
            == source_header["code_size"],
            "address_table_preserved": reopened["entry_offsets"]
            == source_header["entry_offsets"],
            "preamble_preserved": output[:code_offset] == source[:code_offset],
            "code_prefix_preserved": output_code[:instruction_start]
            == source_code[:instruction_start],
            "replacement_instruction_exact": output_code[
                instruction_start:instruction_end
            ]
            == replacement_instruction,
            "code_suffix_preserved": output_code[instruction_end:]
            == source_code[instruction_end:],
            "condition_terminator_preserved": (
                source_instruction[terminator_relative]
                == replacement_instruction[terminator_relative]
                == 0xFF
            ),
            "false_target_operand_preserved": (
                replacement_instruction[target_relative_start:target_relative_end]
                == source_instruction[target_relative_start:target_relative_end]
                == false_target_raw
            ),
            "source_container_not_modified": source == source_before,
        },
    }
    if not all(audit["invariants"].values()):
        raise ConditionLiteralCompileError(
            "MES condition literal compile invariant failed"
        )
    audit["payload_sha256"] = fingerprint(audit)
    validate_audit(audit)
    return output, audit


def validate_audit(
    audit: dict[str, Any],
    editable_document: dict[str, Any] | None = None,
    plan_document: dict[str, Any] | None = None,
    output: bytes | None = None,
) -> dict[str, Any]:
    if (
        audit.get("ok") is not True
        or audit.get("schema") != AUDIT_SCHEMA
        or set(audit) != TOP_LEVEL_KEYS
    ):
        raise ConditionLiteralCompileError(
            "MES condition literal compile audit schema or fields changed"
        )
    if audit.get("producer") != {
        "implementation": "python_phase6_condition_literal_compiler",
        "contract": AUDIT_SCHEMA,
    }:
        raise ConditionLiteralCompileError(
            "MES condition literal compile audit producer changed"
        )
    if audit.get("compatibility") != COMPATIBILITY:
        raise ConditionLiteralCompileError(
            "MES condition literal compile compatibility changed"
        )
    retained = audit.get("payload_sha256")
    if not _is_sha256(retained) or fingerprint(audit) != retained:
        raise ConditionLiteralCompileError(
            "MES condition literal compile audit fingerprint changed"
        )
    source_identity = audit.get("source_identity")
    inputs = audit.get("inputs")
    if (
        not isinstance(source_identity, dict)
        or not set(source_identity).issubset(SOURCE_IDENTITY_KEYS)
        or not isinstance(source_identity.get("entry"), str)
        or not source_identity["entry"]
        or not isinstance(inputs, dict)
        or set(inputs) != {
            "editable_ir_sha256", "decompiler_ir_sha256",
            "condition_literal_plan_sha256",
        }
        or not all(_is_sha256(value) for value in inputs.values())
    ):
        raise ConditionLiteralCompileError(
            "MES condition literal compile input identity changed"
        )
    for key in ("source", "output"):
        row = audit.get(key)
        if (
            not isinstance(row, dict)
            or set(row) != SUMMARY_KEYS
            or any(
                not _is_nonnegative_int(row.get(field))
                for field in ("size", "entry_count", "code_offset", "code_size")
            )
            or not all(
                _is_sha256(row.get(field))
                for field in (
                    "entry_sha256", "bytecode_sha256", "preamble_sha256",
                    "address_table_sha256",
                )
            )
            or int(row["size"]) != int(row["code_offset"]) + int(row["code_size"])
        ):
            raise ConditionLiteralCompileError(
                "MES condition literal compile container summary changed"
            )
    source = audit["source"]
    output_row = audit["output"]
    operation = audit.get("operation")
    if (
        not isinstance(operation, dict)
        or set(operation) != OPERATION_KEYS
        or operation.get("kind") != "replace_condition_literal"
        or any(
            not _is_nonnegative_int(operation.get(field))
            for field in (
                "source_offset", "literal_offset", "source_value",
                "replacement_value", "width", "false_target",
            )
        )
        or int(operation["width"]) not in {8, 16, 32}
    ):
        raise ConditionLiteralCompileError(
            "MES condition literal compile operation changed"
        )
    target = audit.get("target")
    if (
        not isinstance(target, dict)
        or set(target) != TARGET_KEYS
        or not isinstance(target.get("node_id"), str)
        or not target["node_id"]
        or not isinstance(target.get("region_id"), str)
        or not target["region_id"]
        or not isinstance(target.get("false_target_reference_id"), str)
        or not target["false_target_reference_id"]
        or any(
            not _is_nonnegative_int(target.get(field))
            for field in (
                "instruction_start", "instruction_end", "condition_start",
                "condition_end", "literal_start", "literal_end",
                "false_target_operand_start", "false_target_operand_end",
            )
        )
        or not all(
            _is_sha256(target.get(field))
            for field in (
                "source_instruction_sha256", "replacement_instruction_sha256",
                "source_condition_sha256", "replacement_condition_sha256",
                "source_literal_sha256", "replacement_literal_sha256",
                "false_target_operand_sha256",
            )
        )
        or int(target["instruction_end"]) <= int(target["instruction_start"])
        or int(target["condition_start"]) != int(target["instruction_start"]) + 1
        or int(target["literal_start"]) < int(target["condition_start"])
        or int(target["literal_end"]) > int(target["condition_end"]) - 1
        or int(target["false_target_operand_start"]) != int(target["condition_end"])
        or int(target["false_target_operand_end"]) != int(target["instruction_end"])
        or int(operation["source_offset"]) != int(target["instruction_start"])
        or int(operation["literal_offset"]) != int(target["literal_start"])
    ):
        raise ConditionLiteralCompileError(
            "MES condition literal compile target changed"
        )
    coverage = audit.get("coverage")
    if (
        not isinstance(coverage, dict)
        or set(coverage) != {
            "region_count", "node_count", "typed_node_count",
            "opaque_node_count", "code_bytes",
        }
        or any(not _is_nonnegative_int(value) for value in coverage.values())
        or int(coverage["node_count"])
        != int(coverage["typed_node_count"]) + int(coverage["opaque_node_count"])
        or int(coverage["code_bytes"]) != int(source["code_size"])
    ):
        raise ConditionLiteralCompileError(
            "MES condition literal compile coverage changed"
        )
    invariants = audit.get("invariants")
    if (
        not isinstance(invariants, dict)
        or set(invariants) != INVARIANT_KEYS
        or not all(value is True for value in invariants.values())
    ):
        raise ConditionLiteralCompileError(
            "MES condition literal compile invariants changed"
        )
    if (
        output_row["size"] != source["size"]
        or output_row["entry_count"] != source["entry_count"]
        or output_row["code_offset"] != source["code_offset"]
        or output_row["code_size"] != source["code_size"]
        or output_row["preamble_sha256"] != source["preamble_sha256"]
        or output_row["address_table_sha256"] != source["address_table_sha256"]
        or int(coverage["code_bytes"]) != int(output_row["code_size"])
    ):
        raise ConditionLiteralCompileError(
            "MES condition literal compile layout preservation changed"
        )
    if editable_document is not None or plan_document is not None or output is not None:
        if editable_document is None or plan_document is None or output is None:
            raise ConditionLiteralCompileError(
                "MES condition literal compile validation inputs are incomplete"
            )
        expected_output, expected_audit = compile_condition_literal(
            editable_document, plan_document
        )
        if expected_output != output or expected_audit != audit:
            raise ConditionLiteralCompileError(
                "MES condition literal compile audit differs from its source"
            )
    return {"ok": True, "schema": AUDIT_SCHEMA, "payload_sha256": retained}


def _container_summary(payload: bytes, header: dict[str, Any]) -> dict[str, Any]:
    code_offset = int(header["code_offset"])
    return {
        "size": len(payload),
        "entry_count": int(header["entry_count"]),
        "code_offset": code_offset,
        "code_size": int(header["code_size"]),
        "entry_sha256": hashlib.sha256(payload).hexdigest(),
        "bytecode_sha256": hashlib.sha256(payload[code_offset:]).hexdigest(),
        "preamble_sha256": hashlib.sha256(payload[:code_offset]).hexdigest(),
        "address_table_sha256": hashlib.sha256(payload[:code_offset]).hexdigest(),
    }


def _hex_bytes(value: Any, label: str) -> bytes:
    if not isinstance(value, str):
        raise ConditionLiteralCompileError(
            f"MES condition literal compile {label} is missing"
        )
    try:
        return bytes.fromhex(value)
    except ValueError as error:
        raise ConditionLiteralCompileError(
            f"MES condition literal compile {label} is invalid"
        ) from error


def _is_nonnegative_int(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value >= 0


def main() -> None:
    parser = argparse.ArgumentParser(
        description=(
            "Compile one validated same-width MES condition-literal edit into "
            "a new container and compact audit."
        )
    )
    parser.add_argument("editable_ir", type=Path)
    parser.add_argument("plan", type=Path)
    parser.add_argument("output_mes", type=Path)
    parser.add_argument("audit_output", type=Path)
    args = parser.parse_args()
    resolved = {
        args.editable_ir.resolve(), args.plan.resolve(), args.output_mes.resolve(),
        args.audit_output.resolve(),
    }
    if len(resolved) != 4:
        raise ConditionLiteralCompileError(
            "MES condition literal compile paths must differ"
        )
    if args.output_mes.exists() or args.audit_output.exists():
        raise ConditionLiteralCompileError(
            "MES condition literal compile output already exists"
        )
    try:
        editable_document = json.loads(args.editable_ir.read_text(encoding="utf-8"))
        plan_document = json.loads(args.plan.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise ConditionLiteralCompileError(
            "MES condition literal compile input JSON could not be read"
        ) from error
    if not isinstance(editable_document, dict) or not isinstance(plan_document, dict):
        raise ConditionLiteralCompileError(
            "MES condition literal compile inputs must be JSON objects"
        )
    output, audit = compile_condition_literal(editable_document, plan_document)
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
            reopened_audit, editable_document, plan_document,
            args.output_mes.read_bytes(),
        )
    except BaseException:
        if published_audit and args.audit_output.is_file():
            args.audit_output.unlink()
        if published_mes and args.output_mes.is_file():
            args.output_mes.unlink()
        raise
    print(
        "MES_CONDITION_LITERAL_COMPILE_PASS "
        f"schema={audit['schema']} "
        f"entry={audit['source_identity'].get('entry', '')} "
        f"offset={audit['target']['instruction_start']} "
        f"literal_offset={audit['target']['literal_start']} "
        f"false_target={audit['operation']['false_target']} "
        f"bytes={audit['output']['size']} "
        f"payload_sha256={audit['payload_sha256']}"
    )


if __name__ == "__main__":
    main()
