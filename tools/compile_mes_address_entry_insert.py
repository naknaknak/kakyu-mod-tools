from __future__ import annotations

import argparse
import copy
import hashlib
import json
from pathlib import Path
from typing import Any

import compile_mes_noop as noop_compiler
import decompile_mes_handoff as decompiler
import plan_mes_address_entry_insert as entry_planner
import prepare_mes_editable_ir as editable_ir
from payload_values import canonical_payload_bytes, fingerprint, is_sha256 as _is_sha256


AUDIT_SCHEMA = "kakyu_mes_address_entry_insert_compile_audit/v1"
TOP_LEVEL_KEYS = {
    "ok",
    "schema",
    "producer",
    "compatibility",
    "source_identity",
    "inputs",
    "operation",
    "target",
    "table_change",
    "source",
    "output",
    "coverage",
    "invariants",
    "payload_sha256",
}
CONTAINER_KEYS = {
    "size",
    "entry_count",
    "code_offset",
    "code_size",
    "entry_sha256",
    "bytecode_sha256",
    "preamble_sha256",
    "address_table_sha256",
}
COMPATIBILITY = {
    "policy": "exact_address_entry_insert_plan_new_file_only",
    "input_editable_schema": editable_ir.EDITABLE_IR_SCHEMA,
    "input_decompiler_schema": decompiler.DECOMPILER_IR_SCHEMA,
    "input_plan_schema": entry_planner.PLAN_SCHEMA,
    "output_policy": "new_file_only",
    "bytecode_policy": "byte_identical",
    "code_coordinate_policy": "unchanged",
    "native_engine_compatibility": "unverified",
    "unknown_audit_schema": "reject",
    "unknown_v1_field": "reject",
}
INVARIANTS = {
    "entry_insert_plan_validated": True,
    "source_container_reconstructed_exactly": True,
    "output_container_reopened": True,
    "entry_count_incremented_once": True,
    "address_table_cell_inserted_exactly": True,
    "address_offsets_strictly_increasing": True,
    "bytecode_byte_identical": True,
    "code_coordinates_unchanged": True,
    "source_buffer_not_modified": True,
    "output_published_exclusively": True,
    "audit_published_after_output": True,
}


class AddressEntryInsertCompileError(ValueError):
    pass


def compile_address_entry_insert(
    editable_document: dict[str, Any], plan_document: dict[str, Any]
) -> tuple[bytes, dict[str, Any]]:
    entry_planner.validate(plan_document, editable_document)
    source_ir = editable_document["source_ir"]
    source = decompiler.reconstruct_container(source_ir)
    source_header = noop_compiler.reopen_container(source)
    table_change = plan_document["table_change"]
    if (
        source_header["entry_count"] != table_change["source_entry_count"]
        or source_header["code_offset"] != table_change["source_code_offset"]
        or source_header["code_size"] != plan_document["coverage"]["source_code_size"]
        or hashlib.sha256(source[: source_header["code_offset"]]).hexdigest()
        != table_change["source_preamble_sha256"]
        or hashlib.sha256(source[4 : source_header["code_offset"]]).hexdigest()
        != table_change["source_address_table_sha256"]
    ):
        raise AddressEntryInsertCompileError(
            "MES address-entry insertion source container differs from its plan"
        )
    source_offsets = source_header["entry_offsets"]
    insertion_index = int(table_change["insertion_index"])
    inserted_offset = int(table_change["inserted_offset"])
    output_offsets = (
        source_offsets[:insertion_index]
        + [inserted_offset]
        + source_offsets[insertion_index:]
    )
    output_preamble = len(output_offsets).to_bytes(4, "little") + b"".join(
        value.to_bytes(4, "little") for value in output_offsets
    )
    source_code = source[source_header["code_offset"] :]
    output = output_preamble + source_code
    output_header = noop_compiler.reopen_container(output)
    if (
        output_header["entry_count"] != table_change["output_entry_count"]
        or output_header["entry_offsets"] != output_offsets
        or output_header["code_offset"] != table_change["output_code_offset"]
        or output_header["code_size"] != source_header["code_size"]
        or output[output_header["code_offset"] :] != source_code
        or hashlib.sha256(output_preamble).hexdigest()
        != table_change["output_preamble_sha256"]
        or hashlib.sha256(output_preamble[4:]).hexdigest()
        != table_change["output_address_table_sha256"]
    ):
        raise AddressEntryInsertCompileError(
            "MES address-entry insertion output does not match its plan"
        )
    audit = {
        "ok": True,
        "schema": AUDIT_SCHEMA,
        "producer": {
            "implementation": "python_phase6_address_entry_insert_compiler",
            "contract": AUDIT_SCHEMA,
        },
        "compatibility": copy.deepcopy(COMPATIBILITY),
        "source_identity": copy.deepcopy(source_ir["source_identity"]),
        "inputs": {
            "editable_ir_sha256": editable_document["payload_sha256"],
            "decompiler_ir_sha256": source_ir["payload_sha256"],
            "address_entry_insert_plan_sha256": plan_document["payload_sha256"],
        },
        "operation": copy.deepcopy(plan_document["operation"]),
        "target": copy.deepcopy(plan_document["target"]),
        "table_change": copy.deepcopy(table_change),
        "source": _container_summary(source, source_header),
        "output": _container_summary(output, output_header),
        "coverage": copy.deepcopy(plan_document["coverage"]),
        "invariants": copy.deepcopy(INVARIANTS),
    }
    audit["payload_sha256"] = fingerprint(audit)
    validate_audit(audit)
    return output, audit


def validate_audit(
    document: dict[str, Any],
    editable_document: dict[str, Any] | None = None,
    plan_document: dict[str, Any] | None = None,
    output: bytes | None = None,
) -> dict[str, Any]:
    if (
        document.get("ok") is not True
        or document.get("schema") != AUDIT_SCHEMA
        or set(document) != TOP_LEVEL_KEYS
    ):
        raise AddressEntryInsertCompileError(
            "MES address-entry insertion compile audit schema or fields changed"
        )
    if document.get("producer") != {
        "implementation": "python_phase6_address_entry_insert_compiler",
        "contract": AUDIT_SCHEMA,
    }:
        raise AddressEntryInsertCompileError(
            "MES address-entry insertion compile producer changed"
        )
    if document.get("compatibility") != COMPATIBILITY:
        raise AddressEntryInsertCompileError(
            "MES address-entry insertion compile compatibility changed"
        )
    retained = document.get("payload_sha256")
    if not _is_sha256(retained) or fingerprint(document) != retained:
        raise AddressEntryInsertCompileError(
            "MES address-entry insertion compile fingerprint changed"
        )
    if (
        not isinstance(document.get("source"), dict)
        or set(document["source"]) != CONTAINER_KEYS
        or not isinstance(document.get("output"), dict)
        or set(document["output"]) != CONTAINER_KEYS
        or document.get("invariants") != INVARIANTS
    ):
        raise AddressEntryInsertCompileError(
            "MES address-entry insertion compile summaries changed"
        )
    _validate_container_summary(document["source"], "source")
    _validate_container_summary(document["output"], "output")
    table = document.get("table_change")
    if (
        not isinstance(table, dict)
        or set(table) != entry_planner.TABLE_CHANGE_KEYS
        or document["output"]["entry_count"]
        != document["source"]["entry_count"] + 1
        or document["output"]["code_offset"]
        != document["source"]["code_offset"] + 4
        or document["output"]["code_size"] != document["source"]["code_size"]
        or document["output"]["bytecode_sha256"]
        != document["source"]["bytecode_sha256"]
        or document["output"]["entry_count"] != table["output_entry_count"]
        or document["output"]["code_offset"] != table["output_code_offset"]
        or document["output"]["preamble_sha256"]
        != table["output_preamble_sha256"]
        or document["output"]["address_table_sha256"]
        != table["output_address_table_sha256"]
    ):
        raise AddressEntryInsertCompileError(
            "MES address-entry insertion compile geometry changed"
        )
    if output is not None:
        reopened = noop_compiler.reopen_container(output)
        summary = _container_summary(output, reopened)
        if summary != document["output"]:
            raise AddressEntryInsertCompileError(
                "MES address-entry insertion compiled output changed"
            )
        if (
            reopened["entry_offsets"][int(table["insertion_index"])]
            != int(table["inserted_offset"])
        ):
            raise AddressEntryInsertCompileError(
                "MES address-entry insertion compiled cell changed"
            )
    supplied = [editable_document, plan_document, output]
    if any(value is not None for value in supplied):
        if not all(value is not None for value in supplied):
            raise AddressEntryInsertCompileError(
                "MES address-entry insertion compile validation inputs are incomplete"
            )
        expected_output, expected_audit = compile_address_entry_insert(
            editable_document, plan_document
        )
        if expected_output != output or expected_audit != document:
            raise AddressEntryInsertCompileError(
                "MES address-entry insertion compile audit differs from its source"
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
        "address_table_sha256": hashlib.sha256(payload[4:code_offset]).hexdigest(),
    }


def _validate_container_summary(document: dict[str, Any], label: str) -> None:
    for key in ("size", "entry_count", "code_offset", "code_size"):
        if not _is_nonnegative_int(document.get(key)):
            raise AddressEntryInsertCompileError(
                f"MES address-entry insertion compile {label} count changed"
            )
    if document["code_offset"] != 4 + document["entry_count"] * 4:
        raise AddressEntryInsertCompileError(
            f"MES address-entry insertion compile {label} code offset changed"
        )
    if document["size"] != document["code_offset"] + document["code_size"]:
        raise AddressEntryInsertCompileError(
            f"MES address-entry insertion compile {label} size changed"
        )
    for key in (
        "entry_sha256",
        "bytecode_sha256",
        "preamble_sha256",
        "address_table_sha256",
    ):
        if not _is_sha256(document.get(key)):
            raise AddressEntryInsertCompileError(
                f"MES address-entry insertion compile {label} hash changed"
            )


def _is_nonnegative_int(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value >= 0


def main() -> None:
    parser = argparse.ArgumentParser(
        description=(
            "Compile one validated MES address-entry insertion into a new "
            "container and compact audit."
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
        raise AddressEntryInsertCompileError(
            "MES address-entry insertion compile paths must differ"
        )
    if args.output_mes.exists() or args.audit_output.exists():
        raise AddressEntryInsertCompileError(
            "MES address-entry insertion compile output already exists"
        )
    try:
        editable_document = json.loads(args.editable_ir.read_text(encoding="utf-8"))
        plan_document = json.loads(args.plan.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise AddressEntryInsertCompileError(
            "MES address-entry insertion compile input JSON could not be read"
        ) from error
    if not isinstance(editable_document, dict) or not isinstance(plan_document, dict):
        raise AddressEntryInsertCompileError(
            "MES address-entry insertion compile inputs must be JSON objects"
        )
    output, audit = compile_address_entry_insert(editable_document, plan_document)
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
        "MES_ADDRESS_ENTRY_INSERT_COMPILE_PASS "
        f"schema={audit['schema']} "
        f"entry={audit['source_identity'].get('entry', '')} "
        f"source_entries={audit['source']['entry_count']} "
        f"output_entries={audit['output']['entry_count']} "
        f"insert_index={audit['table_change']['insertion_index']} "
        f"target=0x{audit['table_change']['inserted_offset']:X} "
        f"bytes={audit['output']['size']} "
        f"payload_sha256={audit['payload_sha256']}"
    )


if __name__ == "__main__":
    main()
