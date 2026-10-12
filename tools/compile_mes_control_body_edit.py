from __future__ import annotations

import argparse
import copy
import hashlib
import json
from pathlib import Path
from typing import Any

import compile_mes_noop as noop_compiler
import decompile_mes_handoff as decompiler
import plan_mes_control_body_edit as body_planner
import prepare_mes_editable_ir as editable_ir
from payload_values import canonical_payload_bytes, fingerprint, is_sha256 as _is_sha256


AUDIT_SCHEMA = "kakyu_mes_control_body_edit_compile_audit/v1"
TOP_LEVEL_KEYS = {
    "ok", "schema", "producer", "compatibility", "source_identity", "inputs",
    "operation", "body", "relocation", "target_patches", "changed_output_code_offsets",
    "source", "output", "coverage", "invariants", "payload_sha256",
}
SUMMARY_KEYS = {
    "size", "entry_count", "code_offset", "code_size", "entry_sha256",
    "bytecode_sha256", "preamble_sha256", "address_table_sha256",
}
OPERATION_KEYS = {"kind", "source_start", "source_end", "output_start", "output_end"}
BODY_KEYS = {
    "byte_length", "source_raw_sha256", "source_node_count", "inserted_node_count",
}
RELOCATION_KEYS = {
    "delta", "pivot", "address_update_count", "region_update_count",
    "node_map_count", "reference_map_count", "cfg_node_count", "cfg_edge_count",
    "target_patch_count", "target_patch_stream_sha256",
}
COVERAGE_KEYS = {
    "expected_output_region_count", "source_node_count", "source_typed_node_count",
    "source_opaque_node_count", "expected_output_node_count",
    "expected_output_typed_node_count", "expected_output_opaque_node_count",
    "source_code_bytes", "output_code_bytes",
}
INVARIANT_KEYS = {
    "plan_ready", "output_reopened", "entry_count_preserved",
    "code_size_delta_exact", "address_table_relocated_exactly",
    "nonaddress_preamble_bytes_preserved", "body_edit_exact",
    "target_patches_exact", "changed_offsets_exhaustive",
    "source_container_not_modified", "source_documents_not_modified",
}
COMPATIBILITY = {
    "policy": "blocker_free_exact_control_body_plan_new_file_only",
    "input_editable_schema": editable_ir.EDITABLE_IR_SCHEMA,
    "input_plan_schema": body_planner.PLAN_SCHEMA,
    "input_decompiler_schema": decompiler.DECOMPILER_IR_SCHEMA,
    "unknown_audit_schema": "reject",
    "unknown_v1_field": "reject",
    "output_policy": "new_file_only",
    "native_engine_compatibility": "unverified",
}
SOURCE_IDENTITY_KEYS = {"archive", "entry", "source_kind", "archive_sha256"}


class ControlBodyEditCompileError(ValueError):
    pass


def compile_body_edit(
    editable_document: dict[str, Any], plan_document: dict[str, Any]
) -> tuple[bytes, dict[str, Any]]:
    retained_editable = copy.deepcopy(editable_document)
    retained_plan = copy.deepcopy(plan_document)
    editable_ir.validate(editable_document)
    body_planner.validate(plan_document, editable_document)
    if plan_document.get("assembly_ready") is not True or plan_document.get("blockers"):
        raise ControlBodyEditCompileError("MES control-body edit plan is blocked")

    source_ir = editable_document["source_ir"]
    source = decompiler.reconstruct_container(source_ir)
    source_before = bytes(source)
    source_header = noop_compiler.reopen_container(source)
    source_code = source[source_header["code_offset"]:]
    operation = plan_document["operation"]
    body = plan_document["body"]
    source_start = int(body["source_start"])
    source_end = int(body["source_end"])
    body_raw = _bytes_from_hex(body["source_raw_hex"], "source body")
    if (
        source_end <= source_start
        or source_code[source_start:source_end] != body_raw
        or hashlib.sha256(body_raw).hexdigest() != body["source_raw_sha256"]
    ):
        raise ControlBodyEditCompileError("MES control-body source bytes changed")

    kind = str(operation["kind"])
    if kind == "insert_typed_body_copy":
        output_start = int(operation["anchor_offset"])
        output_end = output_start + len(body_raw)
        output_code = bytearray(source_code[:output_start] + body_raw + source_code[output_start:])
    elif kind == "remove_typed_body":
        output_start = output_end = source_start
        output_code = bytearray(source_code[:source_start] + source_code[source_end:])
    else:
        raise ControlBodyEditCompileError("unsupported MES control-body compile operation")
    delta = len(output_code) - len(source_code)
    if (
        delta != int(plan_document["relocation"]["delta"])
        or output_start != int(body["output_start"])
        or output_end != int(body["output_end"])
    ):
        raise ControlBodyEditCompileError("MES control-body compile geometry changed")
    body_edited_code = bytes(output_code)

    changed_offsets: list[int] = []
    previous_end = -1
    for patch in plan_document["target_patches"]:
        operand_start = int(patch["output_operand_start"])
        operand_end = int(patch["output_operand_end"])
        source_operand = _bytes_from_hex(patch["source_raw_hex"], "source target operand")
        output_operand = _bytes_from_hex(patch["output_raw_hex"], "output target operand")
        if (
            operand_end - operand_start != 4
            or operand_start < previous_end
            or operand_end > len(output_code)
            or bytes(output_code[operand_start:operand_end]) != source_operand
            or len(output_operand) != 4
        ):
            raise ControlBodyEditCompileError("MES control-body target patch is stale or overlapping")
        changed_offsets.extend(
            operand_start + index
            for index, (old, new) in enumerate(zip(source_operand, output_operand))
            if old != new
        )
        output_code[operand_start:operand_end] = output_operand
        previous_end = operand_end
    if len(changed_offsets) != len(set(changed_offsets)):
        raise ControlBodyEditCompileError("MES control-body changed target offsets overlap")

    updates = _validated_address_updates(plan_document, source_header)
    output_preamble = bytearray(source[:source_header["code_offset"]])
    for index, output_offset in updates.items():
        position = 4 + index * 4
        output_preamble[position:position + 4] = output_offset.to_bytes(4, "little")
    output = bytes(output_preamble) + bytes(output_code)
    reopened = noop_compiler.reopen_container(output)
    expected_offsets = [
        updates.get(index, source_offset)
        for index, source_offset in enumerate(source_header["entry_offsets"])
    ]
    if reopened["entry_offsets"] != expected_offsets:
        raise ControlBodyEditCompileError("MES control-body address table did not relocate exactly")
    if reopened["code_size"] != int(plan_document["relocation"]["output_code_size"]):
        raise ControlBodyEditCompileError("MES control-body output code size changed")
    if source != source_before:
        raise ControlBodyEditCompileError("MES control-body compile changed its source buffer")

    coverage = source_ir["coverage"]
    body_node_count = len(body["source_node_ids"])
    node_delta = body_node_count if kind == "insert_typed_body_copy" else -body_node_count
    audit = {
        "ok": True,
        "schema": AUDIT_SCHEMA,
        "producer": {
            "implementation": "python_phase6_control_body_edit_compiler",
            "contract": AUDIT_SCHEMA,
        },
        "compatibility": copy.deepcopy(COMPATIBILITY),
        "source_identity": copy.deepcopy(source_ir["source_identity"]),
        "inputs": {
            "editable_ir_sha256": editable_document["payload_sha256"],
            "decompiler_ir_sha256": source_ir["payload_sha256"],
            "control_body_edit_plan_sha256": plan_document["payload_sha256"],
        },
        "operation": {
            "kind": kind,
            "source_start": source_start,
            "source_end": source_end,
            "output_start": output_start,
            "output_end": output_end,
        },
        "body": {
            "byte_length": len(body_raw),
            "source_raw_sha256": str(body["source_raw_sha256"]),
            "source_node_count": body_node_count,
            "inserted_node_count": body_node_count if kind == "insert_typed_body_copy" else 0,
        },
        "relocation": {
            "delta": delta,
            "pivot": int(plan_document["relocation"]["pivot"]),
            "address_update_count": len(updates),
            "region_update_count": len(plan_document["region_updates"]),
            "node_map_count": len(plan_document["node_map"]),
            "reference_map_count": len(plan_document["reference_map"]),
            "cfg_node_count": len(plan_document["cfg_relocation"]["node_rows"]),
            "cfg_edge_count": len(plan_document["cfg_relocation"]["edge_rows"]),
            "target_patch_count": len(plan_document["target_patches"]),
            "target_patch_stream_sha256": _json_sha256(plan_document["target_patches"]),
        },
        "target_patches": copy.deepcopy(plan_document["target_patches"]),
        "changed_output_code_offsets": changed_offsets,
        "source": _container_summary(source, source_header),
        "output": _container_summary(output, reopened),
        "coverage": {
            "expected_output_region_count": _output_region_count(reopened),
            "source_node_count": int(coverage["node_count"]),
            "source_typed_node_count": int(coverage["typed_node_count"]),
            "source_opaque_node_count": int(coverage["opaque_node_count"]),
            "expected_output_node_count": int(coverage["node_count"]) + node_delta,
            "expected_output_typed_node_count": int(coverage["typed_node_count"]) + node_delta,
            "expected_output_opaque_node_count": int(coverage["opaque_node_count"]),
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
            "body_edit_exact": _body_edit_exact(
                source_code, body_edited_code, kind, source_start, source_end,
                output_start, output_end, body_raw,
            ),
            "target_patches_exact": all(
                bytes(output_code[int(row["output_operand_start"]):int(row["output_operand_end"])])
                == bytes.fromhex(str(row["output_raw_hex"]))
                for row in plan_document["target_patches"]
            ),
            "changed_offsets_exhaustive": changed_offsets == sorted(changed_offsets),
            "source_container_not_modified": source == source_before,
            "source_documents_not_modified": (
                editable_document == retained_editable and plan_document == retained_plan
            ),
        },
    }
    if not all(audit["invariants"].values()):
        failed = sorted(key for key, value in audit["invariants"].items() if value is not True)
        raise ControlBodyEditCompileError(
            "MES control-body compile invariant failed: " + ", ".join(failed)
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
        raise ControlBodyEditCompileError("MES control-body compile audit schema or fields changed")
    if audit.get("producer") != {
        "implementation": "python_phase6_control_body_edit_compiler",
        "contract": AUDIT_SCHEMA,
    } or audit.get("compatibility") != COMPATIBILITY:
        raise ControlBodyEditCompileError("MES control-body compile producer or compatibility changed")
    retained = audit.get("payload_sha256")
    if not _is_sha256(retained) or fingerprint(audit) != retained:
        raise ControlBodyEditCompileError("MES control-body compile fingerprint changed")
    identity = audit.get("source_identity")
    inputs = audit.get("inputs")
    if (
        not isinstance(identity, dict)
        or not set(identity).issubset(SOURCE_IDENTITY_KEYS)
        or not identity.get("entry")
        or not isinstance(inputs, dict)
        or set(inputs) != {
            "editable_ir_sha256", "decompiler_ir_sha256", "control_body_edit_plan_sha256"
        }
        or not all(_is_sha256(value) for value in inputs.values())
    ):
        raise ControlBodyEditCompileError("MES control-body compile input identity changed")
    for key in ("source", "output"):
        if not _valid_summary(audit.get(key)):
            raise ControlBodyEditCompileError("MES control-body compile container summary changed")
    operation = audit.get("operation")
    body = audit.get("body")
    relocation = audit.get("relocation")
    coverage = audit.get("coverage")
    if not isinstance(operation, dict) or set(operation) != OPERATION_KEYS:
        raise ControlBodyEditCompileError("MES control-body compile operation fields changed")
    if not isinstance(body, dict) or set(body) != BODY_KEYS:
        raise ControlBodyEditCompileError("MES control-body compile body fields changed")
    if not isinstance(relocation, dict) or set(relocation) != RELOCATION_KEYS:
        raise ControlBodyEditCompileError("MES control-body compile relocation fields changed")
    if not isinstance(coverage, dict) or set(coverage) != COVERAGE_KEYS:
        raise ControlBodyEditCompileError("MES control-body compile coverage fields changed")
    if operation.get("kind") not in body_planner.COMPATIBILITY["supported_operations"]:
        raise ControlBodyEditCompileError("MES control-body compile operation changed")
    if any(not _is_nonnegative_int(operation.get(key)) for key in OPERATION_KEYS - {"kind"}):
        raise ControlBodyEditCompileError("MES control-body compile operation coordinate changed")
    if (
        any(not _is_nonnegative_int(body.get(key)) for key in BODY_KEYS - {"source_raw_sha256"})
        or not _is_sha256(body.get("source_raw_sha256"))
        or int(body["byte_length"]) != int(operation["source_end"]) - int(operation["source_start"])
        or int(body["source_node_count"]) <= 0
    ):
        raise ControlBodyEditCompileError("MES control-body compile body changed")
    if (
        not _is_int(relocation.get("delta"))
        or any(
            not _is_nonnegative_int(relocation.get(key))
            for key in RELOCATION_KEYS - {"delta", "target_patch_stream_sha256"}
        )
        or not _is_sha256(relocation.get("target_patch_stream_sha256"))
    ):
        raise ControlBodyEditCompileError("MES control-body compile relocation changed")
    patches = audit.get("target_patches")
    changed = audit.get("changed_output_code_offsets")
    if (
        not isinstance(patches, list)
        or any(not isinstance(row, dict) or set(row) != body_planner.target_relocation.PATCH_KEYS for row in patches)
        or not isinstance(changed, list)
        or any(not _is_nonnegative_int(value) for value in changed)
        or changed != sorted(set(changed))
        or len(patches) != int(relocation["target_patch_count"])
        or _json_sha256(patches) != relocation["target_patch_stream_sha256"]
    ):
        raise ControlBodyEditCompileError("MES control-body compile target patch stream changed")
    try:
        body_planner.target_relocation._validate_patch_rows(patches)
    except ValueError as error:
        raise ControlBodyEditCompileError(
            "MES control-body compile target patch stream changed"
        ) from error
    expected_changed = sorted(
        int(row["output_operand_start"]) + index
        for row in patches
        for index, (old, new) in enumerate(zip(
            bytes.fromhex(str(row["source_raw_hex"])),
            bytes.fromhex(str(row["output_raw_hex"])),
        ))
        if old != new
    )
    if changed != expected_changed:
        raise ControlBodyEditCompileError("MES control-body compile changed offsets changed")
    if (
        any(not _is_nonnegative_int(value) for value in coverage.values())
        or int(coverage["source_node_count"])
        != int(coverage["source_typed_node_count"]) + int(coverage["source_opaque_node_count"])
        or int(coverage["expected_output_node_count"])
        != int(coverage["expected_output_typed_node_count"]) + int(coverage["expected_output_opaque_node_count"])
        or int(coverage["source_code_bytes"]) != int(audit["source"]["code_size"])
        or int(coverage["output_code_bytes"]) != int(audit["output"]["code_size"])
        or int(audit["output"]["entry_count"]) != int(audit["source"]["entry_count"])
        or int(audit["output"]["code_size"]) != int(audit["source"]["code_size"]) + int(relocation["delta"])
        or int(audit["output"]["size"]) != int(audit["source"]["size"]) + int(relocation["delta"])
    ):
        raise ControlBodyEditCompileError("MES control-body compile coverage changed")
    node_delta = int(body["source_node_count"])
    if operation["kind"] == "insert_typed_body_copy":
        if (
            int(relocation["delta"]) != int(body["byte_length"])
            or int(body["inserted_node_count"]) != node_delta
            or int(operation["output_end"]) - int(operation["output_start"]) != int(body["byte_length"])
            or int(coverage["expected_output_node_count"]) != int(coverage["source_node_count"]) + node_delta
        ):
            raise ControlBodyEditCompileError("MES control-body insertion audit changed")
    else:
        if (
            int(relocation["delta"]) != -int(body["byte_length"])
            or int(body["inserted_node_count"]) != 0
            or int(operation["output_start"]) != int(operation["output_end"])
            or int(coverage["expected_output_node_count"]) != int(coverage["source_node_count"]) - node_delta
        ):
            raise ControlBodyEditCompileError("MES control-body removal audit changed")
    invariants = audit.get("invariants")
    if (
        not isinstance(invariants, dict)
        or set(invariants) != INVARIANT_KEYS
        or not all(value is True for value in invariants.values())
    ):
        raise ControlBodyEditCompileError("MES control-body compile invariants changed")
    if editable_document is not None or plan_document is not None or output is not None:
        if editable_document is None or plan_document is None or output is None:
            raise ControlBodyEditCompileError("MES control-body compile validation inputs are incomplete")
        expected_output, expected_audit = compile_body_edit(editable_document, plan_document)
        if expected_output != output or expected_audit != audit:
            raise ControlBodyEditCompileError("MES control-body compile audit differs from its source")
    return {"ok": True, "schema": AUDIT_SCHEMA, "payload_sha256": retained}


def _validated_address_updates(
    plan_document: dict[str, Any], source_header: dict[str, Any]
) -> dict[int, int]:
    rows = plan_document.get("address_table_updates")
    output: dict[int, int] = {}
    if not isinstance(rows, list):
        raise ControlBodyEditCompileError("MES control-body address updates are missing")
    for row in rows:
        if not isinstance(row, dict) or set(row) != body_planner.ADDRESS_KEYS:
            raise ControlBodyEditCompileError("MES control-body address update changed")
        index = int(row["index"])
        if (
            index < 0 or index >= int(source_header["entry_count"]) or index in output
            or int(source_header["entry_offsets"][index]) != int(row["source_offset"])
        ):
            raise ControlBodyEditCompileError("MES control-body address update is invalid")
        output[index] = int(row["output_offset"])
    return output


def _container_summary(payload: bytes, header: dict[str, Any]) -> dict[str, Any]:
    code_offset = int(header["code_offset"])
    entry_count = int(header["entry_count"])
    return {
        "size": len(payload),
        "entry_count": entry_count,
        "code_offset": code_offset,
        "code_size": int(header["code_size"]),
        "entry_sha256": hashlib.sha256(payload).hexdigest(),
        "bytecode_sha256": hashlib.sha256(payload[code_offset:]).hexdigest(),
        "preamble_sha256": hashlib.sha256(payload[:code_offset]).hexdigest(),
        "address_table_sha256": hashlib.sha256(payload[4:4 + entry_count * 4]).hexdigest(),
    }


def _valid_summary(value: Any) -> bool:
    return (
        isinstance(value, dict) and set(value) == SUMMARY_KEYS
        and all(_is_nonnegative_int(value.get(key)) for key in ("size", "entry_count", "code_offset", "code_size"))
        and all(_is_sha256(value.get(key)) for key in ("entry_sha256", "bytecode_sha256", "preamble_sha256", "address_table_sha256"))
        and int(value["size"]) == int(value["code_offset"]) + int(value["code_size"])
    )


def _output_region_count(header: dict[str, Any]) -> int:
    offsets = header["entry_offsets"]
    if not offsets:
        return 1 if int(header["code_size"]) > 0 else 0
    return len(offsets) + (1 if int(offsets[0]) > 0 else 0)


def _body_edit_exact(
    source: bytes, output: bytes, kind: str, source_start: int, source_end: int,
    output_start: int, output_end: int, body: bytes,
) -> bool:
    if kind == "insert_typed_body_copy":
        return (
            output[:output_start] == source[:output_start]
            and output[output_start:output_end] == body
            and output[output_end:] == source[output_start:]
        )
    return output[:output_start] == source[:source_start] and output[output_end:] == source[source_end:]


def _nonaddress_preamble_preserved(source: bytes, output: bytes, entry_count: int) -> bool:
    table_end = 4 + entry_count * 4
    return (
        source[:4] == output[:4]
        and len(source) >= table_end
        and len(output) >= table_end
    )


def _bytes_from_hex(value: Any, label: str) -> bytes:
    if not isinstance(value, str):
        raise ControlBodyEditCompileError(f"MES control-body compile {label} is missing")
    try:
        return bytes.fromhex(value)
    except ValueError as error:
        raise ControlBodyEditCompileError(f"MES control-body compile {label} is invalid") from error


def _json_sha256(value: Any) -> str:
    return hashlib.sha256(json.dumps(
        value, ensure_ascii=False, allow_nan=False, sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")).hexdigest()


def _is_nonnegative_int(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value >= 0


def _is_int(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool)


def main() -> None:
    parser = argparse.ArgumentParser(
        description=(
            "Compile one blocker-free exact MES control-body insertion/removal plan "
            "into a new container and compact audit."
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
        raise ControlBodyEditCompileError("MES control-body compile input and output paths must differ")
    if args.output_mes.exists() or args.audit_output.exists():
        raise ControlBodyEditCompileError("MES control-body compile output already exists")
    try:
        editable_document = json.loads(args.editable_ir.read_text(encoding="utf-8"))
        plan_document = json.loads(args.plan.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise ControlBodyEditCompileError("MES control-body compile input JSON could not be read") from error
    if not isinstance(editable_document, dict) or not isinstance(plan_document, dict):
        raise ControlBodyEditCompileError("MES control-body compile inputs must be JSON objects")
    output, audit = compile_body_edit(editable_document, plan_document)
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
        "MES_CONTROL_BODY_EDIT_COMPILE_PASS "
        f"schema={audit['schema']} "
        f"entry={audit['source_identity'].get('entry', '')} "
        f"kind={audit['operation']['kind']} "
        f"delta={audit['relocation']['delta']} "
        f"patches={audit['relocation']['target_patch_count']} "
        f"bytes={audit['output']['size']} "
        f"payload_sha256={audit['payload_sha256']}"
    )


if __name__ == "__main__":
    main()
