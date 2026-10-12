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


PLAN_SCHEMA = "kakyu_mes_utf8_overlay_plan/v1"
PROJECTION_SCHEMA = "kakyu_mes_text_overlay_entry/v1"
TOP_LEVEL_KEYS = {
    "ok",
    "schema",
    "producer",
    "compatibility",
    "source_identity",
    "inputs",
    "operation",
    "target",
    "projection_document",
    "invariants",
    "payload_sha256",
}
OPERATION_KEYS = {
    "kind",
    "source_offset",
    "raw_sha256",
    "text",
    "encoding",
    "compatibility",
    "container_policy",
}
COMPATIBILITY = {
    "policy": "remake_only_projection_no_mes_assembly",
    "input_editable_schema": editable_ir.EDITABLE_IR_SCHEMA,
    "input_decompiler_schema": decompiler.DECOMPILER_IR_SCHEMA,
    "supported_operation": "replace_message_utf8_overlay",
    "supported_encoding": "utf8",
    "projection_schema": PROJECTION_SCHEMA,
    "mes_container_output": "forbidden",
    "original_engine_compatibility": "not_claimed",
    "unknown_plan_schema": "reject",
    "unknown_v1_field": "reject",
}


class MesUtf8OverlayPlanError(ValueError):
    pass


def plan(
    editable_document: dict[str, Any], operation: dict[str, Any]
) -> dict[str, Any]:
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
        raise MesUtf8OverlayPlanError("MES UTF-8 overlay plan schema or fields changed")
    if document.get("producer") != {
        "implementation": "python_phase6_utf8_overlay_planner",
        "contract": PLAN_SCHEMA,
    }:
        raise MesUtf8OverlayPlanError("MES UTF-8 overlay plan producer changed")
    if document.get("compatibility") != COMPATIBILITY:
        raise MesUtf8OverlayPlanError("MES UTF-8 overlay compatibility changed")
    retained = document.get("payload_sha256")
    if not _is_sha256(retained) or fingerprint(document) != retained:
        raise MesUtf8OverlayPlanError("MES UTF-8 overlay plan fingerprint changed")
    operation = document.get("operation")
    if not isinstance(operation, dict) or set(operation) != OPERATION_KEYS:
        raise MesUtf8OverlayPlanError("MES UTF-8 overlay operation fields changed")
    _validate_operation(operation)
    identity = document.get("source_identity")
    if not isinstance(identity, dict):
        raise MesUtf8OverlayPlanError("MES UTF-8 overlay source identity is missing")
    archive = identity.get("archive")
    entry = identity.get("entry")
    if (
        not _is_safe_entry_name(archive)
        or not _is_safe_entry_name(entry)
        or not _is_sha256(identity.get("archive_sha256"))
    ):
        raise MesUtf8OverlayPlanError("MES UTF-8 overlay source identity is incomplete")
    inputs = document.get("inputs")
    if (
        not isinstance(inputs, dict)
        or set(inputs)
        != {"editable_ir_sha256", "decompiler_ir_sha256", "entry_sha256"}
        or not all(_is_sha256(value) for value in inputs.values())
    ):
        raise MesUtf8OverlayPlanError("MES UTF-8 overlay input hashes changed")
    target = document.get("target")
    if not isinstance(target, dict) or set(target) != {
        "reference_id",
        "node_id",
        "region_id",
        "instruction_start",
        "instruction_end",
        "payload_start",
        "payload_end",
        "source_byte_length",
        "source_raw_sha256",
    }:
        raise MesUtf8OverlayPlanError("MES UTF-8 overlay target fields changed")
    for key in (
        "instruction_start",
        "instruction_end",
        "payload_start",
        "payload_end",
        "source_byte_length",
    ):
        if not _is_nonnegative_int(target.get(key)):
            raise MesUtf8OverlayPlanError("MES UTF-8 overlay target coordinate changed")
    if (
        int(target["instruction_start"]) > int(target["payload_start"])
        or int(target["payload_start"]) > int(target["payload_end"])
        or int(target["payload_end"]) > int(target["instruction_end"])
        or int(target["payload_end"]) - int(target["payload_start"])
        != int(target["source_byte_length"])
        or target.get("source_raw_sha256") != operation.get("raw_sha256")
    ):
        raise MesUtf8OverlayPlanError("MES UTF-8 overlay target boundary changed")
    projection = document.get("projection_document")
    if not isinstance(projection, dict) or set(projection) != {
        "schema",
        "base_archive_sha256",
        "entry_sha256",
        "target_archive",
        "target_entry",
        "edits",
    }:
        raise MesUtf8OverlayPlanError("MES UTF-8 overlay projection fields changed")
    expected_projection = {
        "schema": PROJECTION_SCHEMA,
        "base_archive_sha256": identity["archive_sha256"],
        "entry_sha256": inputs["entry_sha256"],
        "target_archive": archive,
        "target_entry": entry,
        "edits": [{
            "source_offset": operation["source_offset"],
            "raw_sha256": operation["raw_sha256"],
            "text": operation["text"],
        }],
    }
    if projection != expected_projection:
        raise MesUtf8OverlayPlanError("MES UTF-8 overlay projection changed")
    if document.get("invariants") != {
        "source_editable_ir_validated": True,
        "target_message_unique_and_typed": True,
        "source_message_hash_matched": True,
        "source_message_strict_cp932": True,
        "replacement_utf8_valid": True,
        "projection_document_ready": True,
        "mes_container_bytes_not_emitted": True,
        "source_container_not_modified": True,
    }:
        raise MesUtf8OverlayPlanError("MES UTF-8 overlay invariants changed")
    if editable_document is not None:
        expected = _build_plan(editable_document, copy.deepcopy(operation))
        expected["payload_sha256"] = fingerprint(expected)
        if expected != document:
            raise MesUtf8OverlayPlanError("MES UTF-8 overlay plan differs from its source")
    return {"ok": True, "schema": PLAN_SCHEMA, "payload_sha256": retained}


def _build_plan(
    editable_document: dict[str, Any], raw_operation: dict[str, Any]
) -> dict[str, Any]:
    editable_ir.validate(editable_document)
    operation = _validate_operation(raw_operation)
    source_ir = editable_document["source_ir"]
    identity = source_ir.get("source_identity")
    if not isinstance(identity, dict):
        raise MesUtf8OverlayPlanError("MES UTF-8 overlay source identity is missing")
    archive = identity.get("archive")
    entry = identity.get("entry")
    archive_sha256 = identity.get("archive_sha256")
    if (
        not _is_safe_entry_name(archive)
        or not _is_safe_entry_name(entry)
        or not _is_sha256(archive_sha256)
    ):
        raise MesUtf8OverlayPlanError("MES UTF-8 overlay requires an archive-bound source")
    container = source_ir.get("container")
    if not isinstance(container, dict) or not _is_sha256(container.get("entry_sha256")):
        raise MesUtf8OverlayPlanError("MES UTF-8 overlay entry hash is missing")
    messages = [
        row
        for row in source_ir["references"]
        if row.get("kind") == "message"
        and int(row.get("source_offset", -1)) == operation["source_offset"]
    ]
    if len(messages) != 1:
        raise MesUtf8OverlayPlanError(
            "MES UTF-8 overlay target is not one unique indexed message"
        )
    message = messages[0]
    owners = [
        node for node in source_ir["nodes"] if message["id"] in node["reference_ids"]
    ]
    if len(owners) != 1:
        raise MesUtf8OverlayPlanError("MES UTF-8 overlay message owner is not unique")
    owner = owners[0]
    statement = owner.get("statement")
    if (
        owner.get("kind") != "statement"
        or not isinstance(statement, dict)
        or statement.get("kind") != "instruction"
        or statement.get("op") not in {"text", "dispatcher_character_text"}
    ):
        raise MesUtf8OverlayPlanError("MES UTF-8 overlay target is not typed text")
    value = message.get("value")
    if not isinstance(value, dict) or value.get("native_stream_projection_match") is not True:
        raise MesUtf8OverlayPlanError("MES UTF-8 overlay source text boundary is unresolved")
    raw_hex = value.get("raw_hex")
    if not isinstance(raw_hex, str):
        raise MesUtf8OverlayPlanError("MES UTF-8 overlay source bytes are missing")
    try:
        source_raw = bytes.fromhex(raw_hex)
        source_raw.decode("cp932", errors="strict")
    except (ValueError, UnicodeDecodeError) as error:
        raise MesUtf8OverlayPlanError(
            "MES UTF-8 overlay source is not strict CP932"
        ) from error
    source_sha256 = hashlib.sha256(source_raw).hexdigest()
    if source_sha256 != value.get("raw_sha256") or source_sha256 != operation["raw_sha256"]:
        raise MesUtf8OverlayPlanError("MES UTF-8 overlay source hash is stale")
    operands = statement.get("operands")
    if not isinstance(operands, list) or not operands or not isinstance(operands[0], dict):
        raise MesUtf8OverlayPlanError("MES UTF-8 overlay text operand is missing")
    operand = operands[0]
    if operand.get("type") != "cp932_bytes" or operand.get("raw_hex") != raw_hex:
        raise MesUtf8OverlayPlanError("MES UTF-8 overlay operand disagrees with source")
    node_start = int(owner["source"]["start"])
    node_end = int(owner["source"]["end"])
    payload_start = int(operand.get("source_offset", -1))
    payload_end = payload_start + len(source_raw)
    if not (node_start <= payload_start <= payload_end <= node_end):
        raise MesUtf8OverlayPlanError("MES UTF-8 overlay payload boundary changed")
    return {
        "ok": True,
        "schema": PLAN_SCHEMA,
        "producer": {
            "implementation": "python_phase6_utf8_overlay_planner",
            "contract": PLAN_SCHEMA,
        },
        "compatibility": copy.deepcopy(COMPATIBILITY),
        "source_identity": copy.deepcopy(identity),
        "inputs": {
            "editable_ir_sha256": editable_document["payload_sha256"],
            "decompiler_ir_sha256": source_ir["payload_sha256"],
            "entry_sha256": container["entry_sha256"],
        },
        "operation": copy.deepcopy(operation),
        "target": {
            "reference_id": str(message["id"]),
            "node_id": str(owner["id"]),
            "region_id": str(owner["source"]["region"]),
            "instruction_start": node_start,
            "instruction_end": node_end,
            "payload_start": payload_start,
            "payload_end": payload_end,
            "source_byte_length": len(source_raw),
            "source_raw_sha256": source_sha256,
        },
        "projection_document": {
            "schema": PROJECTION_SCHEMA,
            "base_archive_sha256": archive_sha256,
            "entry_sha256": container["entry_sha256"],
            "target_archive": archive,
            "target_entry": entry,
            "edits": [{
                "source_offset": operation["source_offset"],
                "raw_sha256": operation["raw_sha256"],
                "text": operation["text"],
            }],
        },
        "invariants": {
            "source_editable_ir_validated": True,
            "target_message_unique_and_typed": True,
            "source_message_hash_matched": True,
            "source_message_strict_cp932": True,
            "replacement_utf8_valid": True,
            "projection_document_ready": True,
            "mes_container_bytes_not_emitted": True,
            "source_container_not_modified": True,
        },
    }


def _validate_operation(raw: dict[str, Any]) -> dict[str, Any]:
    if not isinstance(raw, dict) or set(raw) != OPERATION_KEYS:
        raise MesUtf8OverlayPlanError("MES UTF-8 overlay operation fields changed")
    if raw.get("kind") != "replace_message_utf8_overlay":
        raise MesUtf8OverlayPlanError("unsupported MES UTF-8 overlay operation")
    if raw.get("encoding") != "utf8" or raw.get("compatibility") != "remake_only":
        raise MesUtf8OverlayPlanError("MES UTF-8 overlay encoding or compatibility changed")
    if raw.get("container_policy") != "do_not_assemble_mes":
        raise MesUtf8OverlayPlanError("MES UTF-8 overlay container policy changed")
    if not _is_nonnegative_int(raw.get("source_offset")):
        raise MesUtf8OverlayPlanError("MES UTF-8 overlay source offset is invalid")
    if not _is_sha256(raw.get("raw_sha256")):
        raise MesUtf8OverlayPlanError("MES UTF-8 overlay source hash is invalid")
    text = raw.get("text")
    if not isinstance(text, str):
        raise MesUtf8OverlayPlanError("MES UTF-8 overlay text is invalid")
    try:
        text.encode("utf-8", errors="strict")
    except UnicodeEncodeError as error:
        raise MesUtf8OverlayPlanError("MES UTF-8 overlay text is not valid UTF-8") from error
    return copy.deepcopy(raw)


def _is_nonnegative_int(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value >= 0


def _is_safe_entry_name(value: Any) -> bool:
    return (
        isinstance(value, str)
        and bool(value)
        and value not in {".", ".."}
        and "/" not in value
        and "\\" not in value
        and ":" not in value
    )


def main() -> None:
    parser = argparse.ArgumentParser(
        description=(
            "Build a remake-only UTF-8 MES text-overlay plan. The operation "
            "cannot publish or modify an MES container."
        )
    )
    parser.add_argument("editable_ir", type=Path)
    parser.add_argument("operation", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    if len({args.editable_ir.resolve(), args.operation.resolve(), args.output.resolve()}) != 3:
        raise MesUtf8OverlayPlanError("MES UTF-8 overlay input and output paths must differ")
    try:
        editable_document = json.loads(args.editable_ir.read_text(encoding="utf-8"))
        operation = json.loads(args.operation.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise MesUtf8OverlayPlanError("MES UTF-8 overlay input JSON could not be read") from error
    if not isinstance(editable_document, dict) or not isinstance(operation, dict):
        raise MesUtf8OverlayPlanError("MES UTF-8 overlay inputs must be JSON objects")
    document = plan(editable_document, operation)
    editable_ir.publish_new(
        args.output, editable_ir.canonical_json_bytes(document) + b"\n"
    )
    print(
        "MES_UTF8_OVERLAY_PLAN_PASS "
        f"schema={document['schema']} "
        f"entry={document['source_identity']['entry']} "
        f"offset=0x{document['operation']['source_offset']:X} "
        "compatibility=remake_only mes_bytes=false "
        f"payload_sha256={document['payload_sha256']}"
    )


if __name__ == "__main__":
    main()
