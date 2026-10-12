from __future__ import annotations

import argparse
import copy
import hashlib
import json
from pathlib import Path
from typing import Any

import compile_mes_noop as noop_compiler
import decompile_mes_handoff as decompiler
import plan_mes_resource_name_edit as resource_planner
import prepare_mes_editable_ir as editable_ir
from payload_values import canonical_payload_bytes, fingerprint, is_sha256 as _is_sha256


AUDIT_SCHEMA = "kakyu_mes_resource_name_compile_audit/v1"
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
    "kind", "source_offset", "reference_id", "resource_kind", "source_name",
    "replacement_name",
}
TARGET_KEYS = {
    "node_id", "region_id", "op", "instruction_start", "instruction_end",
    "name_start", "name_end", "name_bytes", "prefix_bytes", "suffix_bytes",
    "source_instruction_sha256",
    "replacement_instruction_sha256", "source_name_sha256",
    "replacement_name_sha256", "prefix_sha256", "suffix_sha256",
    "reference_boundary",
}
INVARIANT_KEYS = {
    "plan_ready", "output_reopened", "container_size_preserved",
    "entry_count_preserved", "code_offset_preserved", "code_size_preserved",
    "address_table_preserved", "preamble_preserved", "code_prefix_preserved",
    "replacement_instruction_exact", "code_suffix_preserved",
    "marker_prefix_preserved", "marker_suffix_preserved",
    "only_name_range_changed", "source_container_not_modified",
}
COMPATIBILITY = {
    "policy": "exact_same_length_resource_name_plan_only",
    "input_editable_schema": editable_ir.EDITABLE_IR_SCHEMA,
    "input_plan_schema": resource_planner.PLAN_SCHEMA,
    "input_decompiler_schema": decompiler.DECOMPILER_IR_SCHEMA,
    "unknown_audit_schema": "reject",
    "unknown_v1_field": "reject",
    "output_policy": "new_file_only",
    "relocation": "forbidden",
    "resource_existence": "not_checked",
    "native_engine_compatibility": "unverified",
}
SOURCE_IDENTITY_KEYS = {"archive", "entry", "source_kind", "archive_sha256"}


class ResourceNameCompileError(ValueError):
    pass


def compile_resource_name(
    editable_document: dict[str, Any], plan_document: dict[str, Any]
) -> tuple[bytes, dict[str, Any]]:
    editable_ir.validate(editable_document)
    resource_planner.validate(plan_document, editable_document)
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
    name_start = int(target["name_start"])
    name_end = int(target["name_end"])
    source_instruction = _hex_bytes(target["instruction_raw_hex"], "source instruction")
    replacement_instruction = _hex_bytes(
        replacement["instruction_raw_hex"], "replacement instruction"
    )
    source_name = _hex_bytes(target["name_raw_hex"], "source name")
    replacement_name = _hex_bytes(replacement["name_raw_hex"], "replacement name")
    prefix = _hex_bytes(target["prefix_raw_hex"], "marker prefix")
    suffix = _hex_bytes(target["suffix_raw_hex"], "marker suffix")
    name_relative_start = name_start - instruction_start
    name_relative_end = name_end - instruction_start
    if (
        instruction_start < 0
        or instruction_end <= instruction_start
        or instruction_end > len(source_code)
        or name_relative_start < 0
        or name_relative_end <= name_relative_start
        or name_relative_end > len(source_instruction)
        or len(source_instruction) != instruction_end - instruction_start
        or len(replacement_instruction) != len(source_instruction)
        or len(source_name) != len(replacement_name)
        or source_code[instruction_start:instruction_end] != source_instruction
        or source_instruction != prefix + source_name + suffix
        or replacement_instruction != prefix + replacement_name + suffix
    ):
        raise ResourceNameCompileError("MES resource name compile target boundary changed")
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
        raise ResourceNameCompileError("MES resource name compile changed container layout")
    if source != source_before:
        raise ResourceNameCompileError("MES resource name compile changed its source buffer")
    changed_offsets = [
        index for index, (old, new) in enumerate(zip(source_code, output_code))
        if old != new
    ]
    coverage = source_ir["coverage"]
    operation = plan_document["operation"]
    audit = {
        "ok": True,
        "schema": AUDIT_SCHEMA,
        "producer": {
            "implementation": "python_phase6_resource_name_compiler",
            "contract": AUDIT_SCHEMA,
        },
        "compatibility": copy.deepcopy(COMPATIBILITY),
        "source_identity": copy.deepcopy(source_ir["source_identity"]),
        "inputs": {
            "editable_ir_sha256": editable_document["payload_sha256"],
            "decompiler_ir_sha256": source_ir["payload_sha256"],
            "resource_name_plan_sha256": plan_document["payload_sha256"],
        },
        "source": _container_summary(source, source_header),
        "output": _container_summary(output, reopened),
        "operation": {
            "kind": "replace_resource_name",
            "source_offset": int(operation["source_offset"]),
            "reference_id": str(operation["reference_id"]),
            "resource_kind": str(target["resource_kind"]),
            "source_name": str(target["source_name"]),
            "replacement_name": str(replacement["source_name"]),
        },
        "target": {
            "node_id": str(target["node_id"]),
            "region_id": str(target["region_id"]),
            "op": str(target["op"]),
            "instruction_start": instruction_start,
            "instruction_end": instruction_end,
            "name_start": name_start,
            "name_end": name_end,
            "name_bytes": len(source_name),
            "prefix_bytes": len(prefix),
            "suffix_bytes": len(suffix),
            "source_instruction_sha256": str(target["instruction_raw_sha256"]),
            "replacement_instruction_sha256": str(
                replacement["instruction_raw_sha256"]
            ),
            "source_name_sha256": str(target["name_raw_sha256"]),
            "replacement_name_sha256": str(replacement["name_raw_sha256"]),
            "prefix_sha256": str(target["prefix_raw_sha256"]),
            "suffix_sha256": str(target["suffix_raw_sha256"]),
            "reference_boundary": str(target["reference_boundary"]),
        },
        "coverage": {
            "region_count": int(coverage["region_count"]),
            "node_count": int(coverage["node_count"]),
            "typed_node_count": int(coverage["typed_node_count"]),
            "opaque_node_count": int(coverage["opaque_node_count"]),
            "code_bytes": int(coverage["code_bytes"]),
        },
        "invariants": {
            "plan_ready": plan_document.get("assembly_ready") is True,
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
            "marker_prefix_preserved": replacement_instruction[:name_relative_start] == prefix,
            "marker_suffix_preserved": replacement_instruction[name_relative_end:] == suffix,
            "only_name_range_changed": all(name_start <= value < name_end for value in changed_offsets),
            "source_container_not_modified": source == source_before,
        },
    }
    if not all(audit["invariants"].values()):
        raise ResourceNameCompileError("MES resource name compile invariant failed")
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
        raise ResourceNameCompileError("MES resource name compile audit schema or fields changed")
    if audit.get("producer") != {
        "implementation": "python_phase6_resource_name_compiler",
        "contract": AUDIT_SCHEMA,
    }:
        raise ResourceNameCompileError("MES resource name compile audit producer changed")
    if audit.get("compatibility") != COMPATIBILITY:
        raise ResourceNameCompileError("MES resource name compile compatibility changed")
    retained = audit.get("payload_sha256")
    if not _is_sha256(retained) or fingerprint(audit) != retained:
        raise ResourceNameCompileError("MES resource name compile audit fingerprint changed")
    source_identity = audit.get("source_identity")
    inputs = audit.get("inputs")
    if (
        not isinstance(source_identity, dict)
        or not set(source_identity).issubset(SOURCE_IDENTITY_KEYS)
        or not isinstance(source_identity.get("entry"), str)
        or not source_identity["entry"]
        or not isinstance(inputs, dict)
        or set(inputs) != {
            "editable_ir_sha256", "decompiler_ir_sha256", "resource_name_plan_sha256",
        }
        or not all(_is_sha256(value) for value in inputs.values())
    ):
        raise ResourceNameCompileError("MES resource name compile input identity changed")
    for key in ("source", "output"):
        row = audit.get(key)
        if (
            not isinstance(row, dict)
            or set(row) != SUMMARY_KEYS
            or any(not _is_nonnegative_int(row.get(field)) for field in (
                "size", "entry_count", "code_offset", "code_size",
            ))
            or not all(_is_sha256(row.get(field)) for field in (
                "entry_sha256", "bytecode_sha256", "preamble_sha256",
                "address_table_sha256",
            ))
            or int(row["size"]) != int(row["code_offset"]) + int(row["code_size"])
        ):
            raise ResourceNameCompileError("MES resource name compile container summary changed")
    operation = audit.get("operation")
    if (
        not isinstance(operation, dict)
        or set(operation) != OPERATION_KEYS
        or operation.get("kind") != "replace_resource_name"
        or not _is_nonnegative_int(operation.get("source_offset"))
        or any(not isinstance(operation.get(key), str) or not operation[key] for key in (
            "reference_id", "resource_kind", "source_name", "replacement_name",
        ))
    ):
        raise ResourceNameCompileError("MES resource name compile operation changed")
    target = audit.get("target")
    if (
        not isinstance(target, dict)
        or set(target) != TARGET_KEYS
        or any(not isinstance(target.get(key), str) or not target[key] for key in (
            "node_id", "region_id", "op", "reference_boundary",
        ))
        or target.get("reference_boundary") != "strict_indexed"
        or any(not _is_nonnegative_int(target.get(key)) for key in (
            "instruction_start", "instruction_end", "name_start", "name_end",
            "name_bytes", "prefix_bytes", "suffix_bytes",
        ))
        or not all(_is_sha256(target.get(key)) for key in (
            "source_instruction_sha256", "replacement_instruction_sha256",
            "source_name_sha256", "replacement_name_sha256", "prefix_sha256",
            "suffix_sha256",
        ))
        or int(target["instruction_end"]) <= int(target["instruction_start"])
        or int(target["name_start"]) < int(target["instruction_start"])
        or int(target["name_end"]) <= int(target["name_start"])
        or int(target["name_end"]) > int(target["instruction_end"])
        or int(target["name_start"])
        != int(target["instruction_start"]) + int(target["prefix_bytes"])
        or int(target["name_end"]) != int(target["name_start"]) + int(target["name_bytes"])
        or int(target["instruction_end"])
        != int(target["name_end"]) + int(target["suffix_bytes"])
        or int(operation["source_offset"]) != int(target["instruction_start"])
    ):
        raise ResourceNameCompileError("MES resource name compile target changed")
    coverage = audit.get("coverage")
    if (
        not isinstance(coverage, dict)
        or set(coverage) != {
            "region_count", "node_count", "typed_node_count", "opaque_node_count", "code_bytes",
        }
        or any(not _is_nonnegative_int(value) for value in coverage.values())
        or int(coverage["node_count"]) != int(coverage["typed_node_count"]) + int(coverage["opaque_node_count"])
        or int(coverage["code_bytes"]) != int(audit["source"]["code_size"])
    ):
        raise ResourceNameCompileError("MES resource name compile coverage changed")
    invariants = audit.get("invariants")
    if (
        not isinstance(invariants, dict)
        or set(invariants) != INVARIANT_KEYS
        or not all(value is True for value in invariants.values())
    ):
        raise ResourceNameCompileError("MES resource name compile invariants changed")
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
        raise ResourceNameCompileError("MES resource name compile layout preservation changed")
    if editable_document is not None or plan_document is not None or output is not None:
        if editable_document is None or plan_document is None or output is None:
            raise ResourceNameCompileError("MES resource name compile validation inputs are incomplete")
        expected_output, expected_audit = compile_resource_name(editable_document, plan_document)
        if expected_output != output or expected_audit != audit:
            raise ResourceNameCompileError("MES resource name compile audit differs from its source")
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
        raise ResourceNameCompileError(f"MES resource name compile {label} is missing")
    try:
        result = bytes.fromhex(value)
    except ValueError as error:
        raise ResourceNameCompileError(f"MES resource name compile {label} is invalid") from error
    if not result:
        raise ResourceNameCompileError(f"MES resource name compile {label} is empty")
    return result


def _is_nonnegative_int(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value >= 0


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Compile one same-length typed MES resource-name edit into a new container and audit."
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
        raise ResourceNameCompileError("MES resource name compile paths must differ")
    if args.output_mes.exists() or args.audit_output.exists():
        raise ResourceNameCompileError("MES resource name compile output already exists")
    try:
        editable_document = json.loads(args.editable_ir.read_text(encoding="utf-8"))
        plan_document = json.loads(args.plan.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise ResourceNameCompileError("MES resource name compile input JSON could not be read") from error
    if not isinstance(editable_document, dict) or not isinstance(plan_document, dict):
        raise ResourceNameCompileError("MES resource name compile inputs must be JSON objects")
    output, audit = compile_resource_name(editable_document, plan_document)
    audit_bytes = editable_ir.canonical_json_bytes(audit) + b"\n"
    published_mes = False
    published_audit = False
    try:
        editable_ir.publish_new(args.output_mes, output)
        published_mes = True
        editable_ir.publish_new(args.audit_output, audit_bytes)
        published_audit = True
        reopened_audit = json.loads(args.audit_output.read_text(encoding="utf-8"))
        validate_audit(reopened_audit, editable_document, plan_document, args.output_mes.read_bytes())
    except BaseException:
        if published_audit and args.audit_output.is_file():
            args.audit_output.unlink()
        if published_mes and args.output_mes.is_file():
            args.output_mes.unlink()
        raise
    print(
        "MES_RESOURCE_NAME_COMPILE_PASS "
        f"schema={audit['schema']} entry={audit['source_identity'].get('entry', '')} "
        f"offset={audit['target']['instruction_start']} kind={audit['operation']['resource_kind']} "
        f"source={audit['operation']['source_name']} replacement={audit['operation']['replacement_name']} "
        f"bytes={audit['output']['size']} payload_sha256={audit['payload_sha256']}"
    )


if __name__ == "__main__":
    main()
