from __future__ import annotations

import argparse
import copy
import hashlib
import json
from pathlib import Path
from typing import Any

import compile_mes_noop as noop_compiler
import decompile_mes_handoff as decompiler
import plan_mes_message_relocation as relocation_planner
import prepare_mes_editable_ir as editable_ir
from payload_values import canonical_payload_bytes, fingerprint, is_sha256 as _is_sha256


AUDIT_SCHEMA = "kakyu_mes_message_compile_audit/v1"
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
    "coverage",
    "invariants",
    "payload_sha256",
}
INVARIANT_KEYS = {
    "plan_ready",
    "output_reopened",
    "entry_count_preserved",
    "code_size_delta_exact",
    "address_table_relocated_exactly",
    "nonaddress_preamble_bytes_preserved",
    "code_prefix_preserved",
    "replacement_node_exact",
    "code_suffix_preserved",
    "opaque_records_not_shifted",
    "source_container_not_modified",
}
COMPATIBILITY = {
    "policy": "blocker_free_message_plan_only",
    "input_editable_schema": editable_ir.EDITABLE_IR_SCHEMA,
    "input_plan_schema": relocation_planner.PLAN_SCHEMA,
    "input_decompiler_schema": decompiler.DECOMPILER_IR_SCHEMA,
    "unknown_audit_schema": "reject",
    "unknown_v1_field": "reject",
    "output_policy": "new_file_only",
    "native_engine_compatibility": "unverified",
}
SOURCE_IDENTITY_KEYS = {"archive", "entry", "source_kind", "archive_sha256"}


class MessageCompileError(ValueError):
    pass


def compile_message(
    editable_document: dict[str, Any], plan_document: dict[str, Any]
) -> tuple[bytes, dict[str, Any]]:
    editable_ir.validate(editable_document)
    relocation_planner.validate(plan_document, editable_document)
    if plan_document.get("assembly_ready") is not True or plan_document.get("blockers"):
        raise MessageCompileError("MES message relocation plan is blocked")

    source_ir = editable_document["source_ir"]
    source = decompiler.reconstruct_container(source_ir)
    source_before = bytes(source)
    source_header = noop_compiler.reopen_container(source)
    target = plan_document["target"]
    relocation = plan_document["relocation"]
    node_start = int(target["instruction_start"])
    node_end = int(target["instruction_end"])
    replacement_node = _bytes_from_hex(
        target.get("replacement_node_raw_hex"), "replacement instruction"
    )
    source_code = source[source_header["code_offset"] :]
    if node_start < 0 or node_end <= node_start or node_end > len(source_code):
        raise MessageCompileError("MES message compile target boundary is invalid")
    output_code = source_code[:node_start] + replacement_node + source_code[node_end:]
    delta = len(output_code) - len(source_code)
    if delta != int(relocation["delta"]):
        raise MessageCompileError("MES message compile byte delta changed")

    output_preamble = bytearray(source[: source_header["code_offset"]])
    updates = _validated_address_updates(plan_document, source_header)
    for index, output_offset in updates.items():
        position = 4 + index * 4
        output_preamble[position : position + 4] = output_offset.to_bytes(4, "little")
    output = bytes(output_preamble) + output_code
    reopened = noop_compiler.reopen_container(output)
    expected_offsets = [
        updates.get(index, source_offset)
        for index, source_offset in enumerate(source_header["entry_offsets"])
    ]
    if reopened["entry_offsets"] != expected_offsets:
        raise MessageCompileError("MES message compile address table did not relocate exactly")
    if reopened["code_size"] != int(relocation["output_code_size"]):
        raise MessageCompileError("MES message compile output code size changed")
    if source != source_before:
        raise MessageCompileError("MES message compile changed its source buffer")

    coverage = source_ir["coverage"]
    output_target_end = int(relocation["output_target_end"])
    audit = {
        "ok": True,
        "schema": AUDIT_SCHEMA,
        "producer": {
            "implementation": "python_phase6_message_compiler",
            "contract": AUDIT_SCHEMA,
        },
        "compatibility": copy.deepcopy(COMPATIBILITY),
        "source_identity": copy.deepcopy(source_ir["source_identity"]),
        "inputs": {
            "editable_ir_sha256": editable_document["payload_sha256"],
            "decompiler_ir_sha256": source_ir["payload_sha256"],
            "relocation_plan_sha256": plan_document["payload_sha256"],
        },
        "source": _container_summary(source, source_header),
        "output": _container_summary(output, reopened),
        "operation": {
            "kind": "replace_message",
            "source_offset": int(plan_document["operation"]["source_offset"]),
            "source_raw_sha256": str(plan_document["operation"]["raw_sha256"]),
            "replacement_raw_sha256": str(target["replacement_raw_sha256"]),
            "source_byte_length": int(target["source_byte_length"]),
            "replacement_byte_length": int(target["replacement_byte_length"]),
            "encoding": "cp932",
        },
        "relocation": {
            "delta": delta,
            "source_instruction_start": node_start,
            "source_instruction_end": node_end,
            "output_instruction_end": output_target_end,
            "address_table_update_count": len(updates),
            "affected_reference_count": len(plan_document["affected_references"]),
        },
        "coverage": {
            "output_region_count": _output_region_count(reopened),
            "source_node_count": int(coverage["node_count"]),
            "source_typed_node_count": int(coverage["typed_node_count"]),
            "source_opaque_node_count": int(coverage["opaque_node_count"]),
            "source_code_bytes": len(source_code),
            "output_code_bytes": len(output_code),
        },
        "invariants": {
            "plan_ready": True,
            "output_reopened": True,
            "entry_count_preserved": reopened["entry_count"] == source_header["entry_count"],
            "code_size_delta_exact": len(output_code) == len(source_code) + delta,
            "address_table_relocated_exactly": reopened["entry_offsets"] == expected_offsets,
            "nonaddress_preamble_bytes_preserved": _nonaddress_preamble_preserved(
                source, output, source_header["entry_count"]
            ),
            "code_prefix_preserved": output_code[:node_start] == source_code[:node_start],
            "replacement_node_exact": output_code[node_start:output_target_end]
            == replacement_node,
            "code_suffix_preserved": output_code[output_target_end:] == source_code[node_end:],
            "opaque_records_not_shifted": int(coverage["opaque_node_count"]) == 0
            or not any(
                blocker.get("code") == "opaque_boundary_would_shift"
                for blocker in plan_document["blockers"]
            ),
            "source_container_not_modified": source == source_before,
        },
    }
    if not all(audit["invariants"].values()):
        raise MessageCompileError("MES message compile invariant failed")
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
        raise MessageCompileError("MES message compile audit schema or fields changed")
    if audit.get("producer") != {
        "implementation": "python_phase6_message_compiler",
        "contract": AUDIT_SCHEMA,
    }:
        raise MessageCompileError("MES message compile audit producer changed")
    if audit.get("compatibility") != COMPATIBILITY:
        raise MessageCompileError("MES message compile compatibility changed")
    retained = audit.get("payload_sha256")
    if not _is_sha256(retained) or fingerprint(audit) != retained:
        raise MessageCompileError("MES message compile audit fingerprint changed")
    inputs = audit.get("inputs")
    source_identity = audit.get("source_identity")
    if (
        not isinstance(source_identity, dict)
        or not isinstance(source_identity.get("entry"), str)
        or not source_identity["entry"]
        or not set(source_identity).issubset(SOURCE_IDENTITY_KEYS)
        or not isinstance(inputs, dict)
        or set(inputs)
        != {"editable_ir_sha256", "decompiler_ir_sha256", "relocation_plan_sha256"}
        or not all(_is_sha256(value) for value in inputs.values())
    ):
        raise MessageCompileError("MES message compile input identity changed")
    invariants = audit.get("invariants")
    if (
        not isinstance(invariants, dict)
        or set(invariants) != INVARIANT_KEYS
        or not all(value is True for value in invariants.values())
    ):
        raise MessageCompileError("MES message compile invariants changed")
    for key in ("source", "output"):
        row = audit.get(key)
        if (
            not isinstance(row, dict)
            or set(row)
            != {
                "size",
                "entry_count",
                "code_offset",
                "code_size",
                "entry_sha256",
                "bytecode_sha256",
                "preamble_sha256",
            }
            or any(
                not _is_nonnegative_int(row[field])
                for field in ("size", "entry_count", "code_offset", "code_size")
            )
            or not all(
                _is_sha256(row[field])
                for field in ("entry_sha256", "bytecode_sha256", "preamble_sha256")
            )
        ):
            raise MessageCompileError("MES message compile container summary changed")
        if int(row["size"]) != int(row["code_offset"]) + int(row["code_size"]):
            raise MessageCompileError("MES message compile container size changed")
    source = audit["source"]
    output_row = audit["output"]
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
            not _is_nonnegative_int(operation.get(field))
            for field in ("source_offset", "source_byte_length", "replacement_byte_length")
        )
        or not _is_sha256(operation.get("source_raw_sha256"))
        or not _is_sha256(operation.get("replacement_raw_sha256"))
    ):
        raise MessageCompileError("MES message compile operation changed")
    relocation = audit.get("relocation")
    if (
        not isinstance(relocation, dict)
        or set(relocation)
        != {
            "delta",
            "source_instruction_start",
            "source_instruction_end",
            "output_instruction_end",
            "address_table_update_count",
            "affected_reference_count",
        }
        or not _is_int(relocation.get("delta"))
        or any(
            not _is_nonnegative_int(relocation.get(field))
            for field in (
                "source_instruction_start",
                "source_instruction_end",
                "output_instruction_end",
                "address_table_update_count",
                "affected_reference_count",
            )
        )
        or int(relocation["source_instruction_end"])
        <= int(relocation["source_instruction_start"])
        or int(relocation["output_instruction_end"])
        <= int(relocation["source_instruction_start"])
        or int(relocation["delta"])
        != int(operation["replacement_byte_length"])
        - int(operation["source_byte_length"])
        or int(relocation["output_instruction_end"])
        != int(relocation["source_instruction_end"]) + int(relocation["delta"])
    ):
        raise MessageCompileError("MES message compile relocation changed")
    coverage = audit.get("coverage")
    coverage_keys = {
        "output_region_count",
        "source_node_count",
        "source_typed_node_count",
        "source_opaque_node_count",
        "source_code_bytes",
        "output_code_bytes",
    }
    if (
        not isinstance(coverage, dict)
        or set(coverage) != coverage_keys
        or any(not _is_nonnegative_int(value) for value in coverage.values())
        or int(coverage["source_node_count"])
        != int(coverage["source_typed_node_count"])
        + int(coverage["source_opaque_node_count"])
        or int(coverage["source_code_bytes"]) != int(source["code_size"])
        or int(coverage["output_code_bytes"]) != int(output_row["code_size"])
        or int(output_row["entry_count"]) != int(source["entry_count"])
        or int(output_row["code_offset"]) != int(source["code_offset"])
        or int(output_row["code_size"])
        != int(source["code_size"]) + int(relocation["delta"])
        or int(output_row["size"]) != int(source["size"]) + int(relocation["delta"])
    ):
        raise MessageCompileError("MES message compile coverage changed")
    if editable_document is not None or plan_document is not None or output is not None:
        if editable_document is None or plan_document is None or output is None:
            raise MessageCompileError("MES message compile validation inputs are incomplete")
        expected_output, expected_audit = compile_message(editable_document, plan_document)
        if expected_output != output or expected_audit != audit:
            raise MessageCompileError("MES message compile audit differs from its source")
    return {"ok": True, "schema": AUDIT_SCHEMA, "payload_sha256": retained}


def _validated_address_updates(
    plan_document: dict[str, Any], source_header: dict[str, Any]
) -> dict[int, int]:
    rows = plan_document.get("relocation", {}).get("address_table_updates")
    if not isinstance(rows, list):
        raise MessageCompileError("MES message compile address update plan is missing")
    output: dict[int, int] = {}
    for row in rows:
        if not isinstance(row, dict) or set(row) != {"index", "source_offset", "output_offset"}:
            raise MessageCompileError("MES message compile address update changed")
        index = row.get("index")
        source_offset = row.get("source_offset")
        output_offset = row.get("output_offset")
        if (
            not _is_nonnegative_int(index)
            or int(index) >= int(source_header["entry_count"])
            or int(index) in output
            or source_header["entry_offsets"][int(index)] != source_offset
            or not _is_nonnegative_int(output_offset)
        ):
            raise MessageCompileError("MES message compile address update is invalid")
        output[int(index)] = int(output_offset)
    return output


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
    }


def _output_region_count(header: dict[str, Any]) -> int:
    offsets = header["entry_offsets"]
    if not offsets:
        return 1 if int(header["code_size"]) > 0 else 0
    return len(offsets) + (1 if int(offsets[0]) > 0 else 0)


def _nonaddress_preamble_preserved(
    source: bytes, output: bytes, entry_count: int
) -> bool:
    table_end = 4 + entry_count * 4
    return (
        len(source) >= table_end
        and len(output) >= table_end
        and source[:4] == output[:4]
    )


def _bytes_from_hex(value: Any, label: str) -> bytes:
    if not isinstance(value, str):
        raise MessageCompileError(f"MES message compile {label} is missing")
    try:
        return bytes.fromhex(value)
    except ValueError as error:
        raise MessageCompileError(f"MES message compile {label} is invalid") from error


def _is_nonnegative_int(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value >= 0


def _is_int(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool)


def main() -> None:
    parser = argparse.ArgumentParser(
        description=(
            "Compile one blocker-free variable-length CP932 MES message plan "
            "into a new container and compact audit."
        )
    )
    parser.add_argument("editable_ir", type=Path)
    parser.add_argument("plan", type=Path)
    parser.add_argument("output_mes", type=Path)
    parser.add_argument("audit_output", type=Path)
    args = parser.parse_args()
    resolved = {
        args.editable_ir.resolve(),
        args.plan.resolve(),
        args.output_mes.resolve(),
        args.audit_output.resolve(),
    }
    if len(resolved) != 4:
        raise MessageCompileError("MES message compile input and output paths must differ")
    if args.output_mes.exists() or args.audit_output.exists():
        raise MessageCompileError("MES message compile output already exists")
    try:
        editable_document = json.loads(args.editable_ir.read_text(encoding="utf-8"))
        plan_document = json.loads(args.plan.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise MessageCompileError("MES message compile input JSON could not be read") from error
    if not isinstance(editable_document, dict) or not isinstance(plan_document, dict):
        raise MessageCompileError("MES message compile inputs must be JSON objects")
    output, audit = compile_message(editable_document, plan_document)
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
            plan_document,
            args.output_mes.read_bytes(),
        )
    except BaseException:
        if published_audit and args.audit_output.is_file():
            args.audit_output.unlink()
        if published_mes and args.output_mes.is_file():
            args.output_mes.unlink()
        raise
    print(
        "MES_MESSAGE_COMPILE_PASS "
        f"schema={audit['schema']} "
        f"entry={audit['source_identity'].get('entry', '')} "
        f"delta={audit['relocation']['delta']} "
        f"bytes={audit['output']['size']} "
        f"payload_sha256={audit['payload_sha256']}"
    )


if __name__ == "__main__":
    main()
