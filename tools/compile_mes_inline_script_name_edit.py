from __future__ import annotations

import argparse
import copy
import hashlib
import json
from pathlib import Path
from typing import Any

import compile_mes_noop as noop_compiler
import decompile_mes_handoff as decompiler
import plan_mes_inline_script_name_edit as inline_planner
import prepare_mes_editable_ir as editable_ir
from payload_values import canonical_payload_bytes, fingerprint, is_sha256 as _is_sha256


AUDIT_SCHEMA = "kakyu_mes_inline_script_name_compile_audit/v1"
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
    "kind", "source_offset", "reference_id", "source_name", "replacement_name",
    "execution_selector", "execution_role",
}
TARGET_KEYS = {
    "node_id", "region_id", "owner_kind", "owner_start", "owner_end",
    "owner_bytes", "envelope_start", "envelope_end", "name_start", "name_end", "name_bytes",
    "prefix_bytes", "suffix_bytes", "source_owner_sha256",
    "replacement_owner_sha256", "source_envelope_sha256",
    "replacement_envelope_sha256", "source_name_sha256",
    "replacement_name_sha256", "prefix_sha256", "suffix_sha256",
    "reference_boundary",
}
INVARIANT_KEYS = {
    "plan_ready", "output_reopened", "container_size_preserved",
    "entry_count_preserved", "code_offset_preserved", "code_size_preserved",
    "address_table_preserved", "preamble_preserved", "code_prefix_preserved",
    "code_suffix_preserved", "replacement_envelope_exact",
    "owner_prefix_preserved", "owner_suffix_preserved", "selector_prefix_preserved",
    "double_nul_suffix_preserved", "only_name_range_changed",
    "opaque_owner_boundary_preserved", "source_container_not_modified",
}
COMPATIBILITY = {
    "policy": "exact_same_length_inline_script_name_plan_only",
    "input_editable_schema": editable_ir.EDITABLE_IR_SCHEMA,
    "input_plan_schema": inline_planner.PLAN_SCHEMA,
    "input_decompiler_schema": decompiler.DECOMPILER_IR_SCHEMA,
    "unknown_audit_schema": "reject",
    "unknown_v1_field": "reject",
    "output_policy": "new_file_only",
    "relocation": "forbidden",
    "resource_existence": "not_checked",
    "tool_execution": "not_performed",
    "native_engine_compatibility": "unverified",
}
SOURCE_IDENTITY_KEYS = {"archive", "entry", "source_kind", "archive_sha256"}


class InlineScriptNameCompileError(ValueError):
    pass


def compile_inline_script_name(
    editable_document: dict[str, Any], plan_document: dict[str, Any]
) -> tuple[bytes, dict[str, Any]]:
    editable_ir.validate(editable_document)
    inline_planner.validate(plan_document, editable_document)
    source_ir = editable_document["source_ir"]
    source = decompiler.reconstruct_container(source_ir)
    source_before = bytes(source)
    source_header = noop_compiler.reopen_container(source)
    code_offset = int(source_header["code_offset"])
    source_code = source[code_offset:]
    target = plan_document["target"]
    replacement = plan_document["replacement"]
    owner_start = int(target["owner_start"])
    owner_end = int(target["owner_end"])
    envelope_start = int(target["envelope_start"])
    envelope_end = int(target["envelope_end"])
    name_start = int(target["name_start"])
    name_end = int(target["name_end"])
    source_envelope = _hex_bytes(target["envelope_raw_hex"], "source envelope")
    replacement_envelope = _hex_bytes(
        replacement["envelope_raw_hex"], "replacement envelope"
    )
    source_name = _hex_bytes(target["name_raw_hex"], "source name")
    replacement_name = _hex_bytes(replacement["name_raw_hex"], "replacement name")
    prefix = _hex_bytes(target["prefix_raw_hex"], "selector prefix")
    suffix = _hex_bytes(target["suffix_raw_hex"], "double-NUL suffix")
    owner_relative_name_start = name_start - owner_start
    owner_relative_name_end = name_end - owner_start
    if (
        owner_start < 0
        or owner_end <= owner_start
        or owner_end > len(source_code)
        or envelope_start < owner_start
        or envelope_end > owner_end
        or envelope_end <= envelope_start
        or name_start < envelope_start
        or name_end > envelope_end
        or name_end <= name_start
        or envelope_end - envelope_start != len(source_envelope)
        or source_code[envelope_start:envelope_end] != source_envelope
        or source_envelope != prefix + source_name + suffix
        or replacement_envelope != prefix + replacement_name + suffix
        or len(source_name) != len(replacement_name)
        or hashlib.sha256(source_code[owner_start:owner_end]).hexdigest()
        != target["owner_raw_sha256"]
    ):
        raise InlineScriptNameCompileError(
            "MES inline script name compile target boundary changed"
        )
    output_code = source_code[:name_start] + replacement_name + source_code[name_end:]
    output = source[:code_offset] + output_code
    reopened = noop_compiler.reopen_container(output)
    if (
        reopened["entry_count"] != source_header["entry_count"]
        or reopened["entry_offsets"] != source_header["entry_offsets"]
        or reopened["code_offset"] != source_header["code_offset"]
        or reopened["code_size"] != source_header["code_size"]
    ):
        raise InlineScriptNameCompileError(
            "MES inline script name compile changed container layout"
        )
    if source != source_before:
        raise InlineScriptNameCompileError(
            "MES inline script name compile changed its source buffer"
        )
    changed_offsets = [
        index for index, (old, new) in enumerate(zip(source_code, output_code))
        if old != new
    ]
    source_owner = source_code[owner_start:owner_end]
    output_owner = output_code[owner_start:owner_end]
    coverage = source_ir["coverage"]
    operation = plan_document["operation"]
    audit = {
        "ok": True,
        "schema": AUDIT_SCHEMA,
        "producer": {
            "implementation": "python_phase6_inline_script_name_compiler",
            "contract": AUDIT_SCHEMA,
        },
        "compatibility": copy.deepcopy(COMPATIBILITY),
        "source_identity": copy.deepcopy(source_ir["source_identity"]),
        "inputs": {
            "editable_ir_sha256": editable_document["payload_sha256"],
            "decompiler_ir_sha256": source_ir["payload_sha256"],
            "inline_script_name_plan_sha256": plan_document["payload_sha256"],
        },
        "source": _container_summary(source, source_header),
        "output": _container_summary(output, reopened),
        "operation": {
            "kind": "replace_inline_script_name",
            "source_offset": int(operation["source_offset"]),
            "reference_id": str(operation["reference_id"]),
            "source_name": str(target["source_name"]),
            "replacement_name": str(replacement["source_name"]),
            "execution_selector": int(target["execution_selector"]),
            "execution_role": str(target["execution_role"]),
        },
        "target": {
            "node_id": str(target["node_id"]),
            "region_id": str(target["region_id"]),
            "owner_kind": str(target["owner_kind"]),
            "owner_start": owner_start,
            "owner_end": owner_end,
            "owner_bytes": len(source_owner),
            "envelope_start": envelope_start,
            "envelope_end": envelope_end,
            "name_start": name_start,
            "name_end": name_end,
            "name_bytes": len(source_name),
            "prefix_bytes": len(prefix),
            "suffix_bytes": len(suffix),
            "source_owner_sha256": hashlib.sha256(source_owner).hexdigest(),
            "replacement_owner_sha256": hashlib.sha256(output_owner).hexdigest(),
            "source_envelope_sha256": str(target["envelope_raw_sha256"]),
            "replacement_envelope_sha256": str(replacement["envelope_raw_sha256"]),
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
            "code_prefix_preserved": output_code[:name_start] == source_code[:name_start],
            "code_suffix_preserved": output_code[name_end:] == source_code[name_end:],
            "replacement_envelope_exact": output_code[envelope_start:envelope_end] == replacement_envelope,
            "owner_prefix_preserved": output_owner[:owner_relative_name_start] == source_owner[:owner_relative_name_start],
            "owner_suffix_preserved": output_owner[owner_relative_name_end:] == source_owner[owner_relative_name_end:],
            "selector_prefix_preserved": output_code[envelope_start:name_start] == prefix,
            "double_nul_suffix_preserved": output_code[name_end:envelope_end] == suffix,
            "only_name_range_changed": bool(changed_offsets) and all(
                name_start <= value < name_end for value in changed_offsets
            ),
            "opaque_owner_boundary_preserved": (
                target["owner_kind"] != "opaque"
                or len(output_owner) == len(source_owner)
            ),
            "source_container_not_modified": source == source_before,
        },
    }
    if not all(audit["invariants"].values()):
        raise InlineScriptNameCompileError(
            "MES inline script name compile invariant failed"
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
        raise InlineScriptNameCompileError(
            "MES inline script name compile audit schema or fields changed"
        )
    if audit.get("producer") != {
        "implementation": "python_phase6_inline_script_name_compiler",
        "contract": AUDIT_SCHEMA,
    }:
        raise InlineScriptNameCompileError(
            "MES inline script name compile audit producer changed"
        )
    if audit.get("compatibility") != COMPATIBILITY:
        raise InlineScriptNameCompileError(
            "MES inline script name compile compatibility changed"
        )
    retained = audit.get("payload_sha256")
    if not _is_sha256(retained) or fingerprint(audit) != retained:
        raise InlineScriptNameCompileError(
            "MES inline script name compile audit fingerprint changed"
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
            "inline_script_name_plan_sha256",
        }
        or not all(_is_sha256(value) for value in inputs.values())
    ):
        raise InlineScriptNameCompileError(
            "MES inline script name compile input identity changed"
        )
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
            raise InlineScriptNameCompileError(
                "MES inline script name compile container summary changed"
            )
    operation = audit.get("operation")
    if (
        not isinstance(operation, dict)
        or set(operation) != OPERATION_KEYS
        or operation.get("kind") != "replace_inline_script_name"
        or not _is_nonnegative_int(operation.get("source_offset"))
        or operation.get("execution_selector") not in inline_planner.SUPPORTED_SELECTORS
        or any(not isinstance(operation.get(key), str) or not operation[key] for key in (
            "reference_id", "source_name", "replacement_name", "execution_role",
        ))
        or operation["execution_role"]
        != inline_planner.SUPPORTED_SELECTORS[operation["execution_selector"]]["role"]
    ):
        raise InlineScriptNameCompileError(
            "MES inline script name compile operation changed"
        )
    target = audit.get("target")
    if (
        not isinstance(target, dict)
        or set(target) != TARGET_KEYS
        or target.get("owner_kind") not in ["statement", "opaque"]
        or target.get("reference_boundary")
        != ("strict_indexed" if target.get("owner_kind") == "statement" else "bounded_envelope_scan")
        or any(not isinstance(target.get(key), str) or not target[key] for key in (
            "node_id", "region_id",
        ))
        or any(not _is_nonnegative_int(target.get(key)) for key in (
            "owner_start", "owner_end", "owner_bytes", "envelope_start", "envelope_end",
            "name_start", "name_end", "name_bytes", "prefix_bytes", "suffix_bytes",
        ))
        or not all(_is_sha256(target.get(key)) for key in (
            "source_owner_sha256", "replacement_owner_sha256",
            "source_envelope_sha256", "replacement_envelope_sha256",
            "source_name_sha256", "replacement_name_sha256", "prefix_sha256",
            "suffix_sha256",
        ))
        or int(target["owner_end"]) <= int(target["owner_start"])
        or int(target["owner_end"]) != int(target["owner_start"]) + int(target["owner_bytes"])
        or int(target["envelope_start"]) < int(target["owner_start"])
        or int(target["envelope_end"]) > int(target["owner_end"])
        or int(target["name_start"])
        != int(target["envelope_start"]) + int(target["prefix_bytes"])
        or int(target["name_end"]) != int(target["name_start"]) + int(target["name_bytes"])
        or int(target["envelope_end"])
        != int(target["name_end"]) + int(target["suffix_bytes"])
        or int(operation["source_offset"]) != int(target["envelope_start"])
    ):
        raise InlineScriptNameCompileError(
            "MES inline script name compile target changed"
        )
    coverage = audit.get("coverage")
    if (
        not isinstance(coverage, dict)
        or set(coverage) != {
            "region_count", "node_count", "typed_node_count", "opaque_node_count",
            "code_bytes",
        }
        or any(not _is_nonnegative_int(value) for value in coverage.values())
        or int(coverage["node_count"])
        != int(coverage["typed_node_count"]) + int(coverage["opaque_node_count"])
        or int(coverage["code_bytes"]) != int(audit["source"]["code_size"])
    ):
        raise InlineScriptNameCompileError(
            "MES inline script name compile coverage changed"
        )
    invariants = audit.get("invariants")
    if (
        not isinstance(invariants, dict)
        or set(invariants) != INVARIANT_KEYS
        or not all(value is True for value in invariants.values())
    ):
        raise InlineScriptNameCompileError(
            "MES inline script name compile invariants changed"
        )
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
        raise InlineScriptNameCompileError(
            "MES inline script name compile layout identity changed"
        )
    if editable_document is not None and plan_document is not None:
        expected_output, expected_audit = compile_inline_script_name(
            editable_document, plan_document
        )
        if expected_audit != audit:
            raise InlineScriptNameCompileError(
                "MES inline script name compile audit differs from its source"
            )
        if output is not None and output != expected_output:
            raise InlineScriptNameCompileError(
                "MES inline script name compile output differs from its source"
            )
    elif output is not None:
        reopened = noop_compiler.reopen_container(output)
        if _container_summary(output, reopened) != output_row:
            raise InlineScriptNameCompileError(
                "MES inline script name compile output identity changed"
            )
    return {"ok": True, "schema": AUDIT_SCHEMA, "payload_sha256": retained}


def _container_summary(raw: bytes, header: dict[str, Any]) -> dict[str, Any]:
    code_offset = int(header["code_offset"])
    code = raw[code_offset:]
    table = raw[4:code_offset]
    return {
        "size": len(raw),
        "entry_count": int(header["entry_count"]),
        "code_offset": code_offset,
        "code_size": len(code),
        "entry_sha256": hashlib.sha256(raw).hexdigest(),
        "bytecode_sha256": hashlib.sha256(code).hexdigest(),
        "preamble_sha256": hashlib.sha256(raw[:code_offset]).hexdigest(),
        "address_table_sha256": hashlib.sha256(table).hexdigest(),
    }


def _hex_bytes(value: Any, label: str) -> bytes:
    if not isinstance(value, str) or not value or len(value) % 2 != 0:
        raise InlineScriptNameCompileError(
            f"MES inline script name compile {label} bytes are invalid"
        )
    try:
        return bytes.fromhex(value)
    except ValueError as error:
        raise InlineScriptNameCompileError(
            f"MES inline script name compile {label} bytes are invalid"
        ) from error


def _is_nonnegative_int(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value >= 0


def _load_json(path: Path, label: str) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise InlineScriptNameCompileError(
            f"MES inline script name compile {label} could not be read"
        ) from error
    if not isinstance(value, dict):
        raise InlineScriptNameCompileError(
            f"MES inline script name compile {label} is not an object"
        )
    return value


def main() -> None:
    parser = argparse.ArgumentParser(
        description=(
            "Compile one validated same-length inline MES script name edit to "
            "an exclusively published new container and compact audit."
        )
    )
    parser.add_argument("editable_ir", type=Path)
    parser.add_argument("plan", type=Path)
    parser.add_argument("output_mes", type=Path)
    parser.add_argument("output_audit", type=Path)
    args = parser.parse_args()
    resolved = {
        args.editable_ir.resolve(), args.plan.resolve(), args.output_mes.resolve(),
        args.output_audit.resolve(),
    }
    if len(resolved) != 4:
        raise InlineScriptNameCompileError(
            "MES inline script name compile paths must be distinct"
        )
    if args.output_mes.exists() or args.output_audit.exists():
        raise InlineScriptNameCompileError(
            "MES inline script name compile output already exists"
        )
    editable_document = _load_json(args.editable_ir, "editable IR")
    plan_document = _load_json(args.plan, "plan")
    output, audit = compile_inline_script_name(editable_document, plan_document)
    editable_ir.publish_new(args.output_mes, output)
    try:
        editable_ir.publish_new(
            args.output_audit,
            json.dumps(
                audit,
                ensure_ascii=False,
                allow_nan=False,
                sort_keys=True,
                separators=(",", ":"),
            ).encode("utf-8") + b"\n",
        )
    except Exception:
        args.output_mes.unlink(missing_ok=True)
        raise
    print(
        "MES_INLINE_SCRIPT_NAME_COMPILE_PASS "
        f"schema={audit['schema']} "
        f"entry={audit['source_identity'].get('entry', '')} "
        f"offset={audit['operation']['source_offset']} "
        f"selector={audit['operation']['execution_selector']} "
        f"name={audit['operation']['source_name']} "
        f"replacement={audit['operation']['replacement_name']} "
        f"output_bytes={audit['output']['size']} "
        f"payload_sha256={audit['payload_sha256']}"
    )


if __name__ == "__main__":
    main()
