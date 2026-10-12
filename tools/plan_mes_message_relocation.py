from __future__ import annotations

import argparse
import copy
import hashlib
import json
from pathlib import Path
from typing import Any

import compile_mes_noop as noop_compiler
import decompile_mes_handoff as decompiler
import prepare_mes_editable_ir as editable_ir
from payload_values import canonical_payload_bytes, fingerprint, is_sha256 as _is_sha256


PLAN_SCHEMA = "kakyu_mes_message_relocation_plan/v1"
TOP_LEVEL_KEYS = {
    "ok",
    "schema",
    "producer",
    "compatibility",
    "source_identity",
    "inputs",
    "operation",
    "target",
    "relocation",
    "affected_references",
    "blockers",
    "assembly_ready",
    "invariants",
    "payload_sha256",
}
OPERATION_KEYS = {
    "kind",
    "source_offset",
    "raw_sha256",
    "text",
    "encoding",
    "native_projection",
}
COMPATIBILITY = {
    "policy": "planning_only_no_binary_publication",
    "input_editable_schema": editable_ir.EDITABLE_IR_SCHEMA,
    "input_decompiler_schema": decompiler.DECOMPILER_IR_SCHEMA,
    "supported_operation": "replace_message",
    "supported_encoding": "cp932",
    "native_projection_policy": "require_source_and_replacement_match",
    "opaque_record_policy": "block_when_shifted",
    "code_target_policy": "defer_encoded_target_relocation_to_mw03",
    "unknown_plan_schema": "reject",
    "unknown_v1_field": "reject",
}


class MessageRelocationPlanError(ValueError):
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
        raise MessageRelocationPlanError("MES message relocation plan schema or fields changed")
    if document.get("producer") != {
        "implementation": "python_phase6_message_relocation_planner",
        "contract": PLAN_SCHEMA,
    }:
        raise MessageRelocationPlanError("MES message relocation plan producer changed")
    if document.get("compatibility") != COMPATIBILITY:
        raise MessageRelocationPlanError("MES message relocation compatibility changed")
    retained = document.get("payload_sha256")
    if not _is_sha256(retained) or fingerprint(document) != retained:
        raise MessageRelocationPlanError("MES message relocation plan fingerprint changed")
    operation = document.get("operation")
    if not isinstance(operation, dict) or set(operation) != OPERATION_KEYS:
        raise MessageRelocationPlanError("MES message relocation operation fields changed")
    if not isinstance(document.get("affected_references"), list):
        raise MessageRelocationPlanError("MES message relocation reference plan changed")
    blockers = document.get("blockers")
    if not isinstance(blockers, list):
        raise MessageRelocationPlanError("MES message relocation blockers changed")
    if document.get("assembly_ready") is not (len(blockers) == 0):
        raise MessageRelocationPlanError("MES message relocation readiness changed")
    invariants = document.get("invariants")
    if invariants != {
        "source_editable_ir_validated": True,
        "target_message_unique_and_typed": True,
        "source_message_hash_matched": True,
        "source_and_replacement_native_projection_matched": True,
        "address_table_exhaustively_planned": True,
        "opaque_bytes_not_rewritten": True,
        "binary_not_published": True,
    }:
        raise MessageRelocationPlanError("MES message relocation invariants changed")
    if editable_document is not None:
        expected = _build_plan(editable_document, copy.deepcopy(operation))
        expected["payload_sha256"] = fingerprint(expected)
        if expected != document:
            raise MessageRelocationPlanError("MES message relocation plan differs from its source")
    return {"ok": True, "schema": PLAN_SCHEMA, "payload_sha256": retained}


def _build_plan(
    editable_document: dict[str, Any], raw_operation: dict[str, Any]
) -> dict[str, Any]:
    editable_ir.validate(editable_document)
    operation = _validate_operation(raw_operation)
    source_ir = editable_document["source_ir"]
    references = source_ir["references"]
    message_rows = [
        row
        for row in references
        if row.get("kind") == "message"
        and int(row.get("source_offset", -1)) == operation["source_offset"]
    ]
    if len(message_rows) != 1:
        raise MessageRelocationPlanError(
            "MES message relocation target is not one unique indexed message"
        )
    message = message_rows[0]
    owners = [
        node for node in source_ir["nodes"] if message["id"] in node["reference_ids"]
    ]
    if len(owners) != 1:
        raise MessageRelocationPlanError("MES message relocation owner is not unique")
    owner = owners[0]
    statement = owner["statement"]
    if (
        owner.get("kind") != "statement"
        or statement.get("kind") != "instruction"
        or statement.get("op") not in {"text", "dispatcher_character_text"}
    ):
        raise MessageRelocationPlanError("MES message relocation target is not a typed text instruction")
    message_value = message.get("value")
    if not isinstance(message_value, dict):
        raise MessageRelocationPlanError("MES message relocation source evidence is missing")
    source_raw = _message_raw_bytes(message_value)
    if hashlib.sha256(source_raw).hexdigest() != operation["raw_sha256"]:
        raise MessageRelocationPlanError("MES message relocation source hash is stale")
    try:
        source_raw.decode("cp932", errors="strict")
    except UnicodeDecodeError as error:
        raise MessageRelocationPlanError(
            "MES message relocation source is not strict CP932"
        ) from error
    if message_value.get("native_stream_projection_match") is not True:
        raise MessageRelocationPlanError(
            "MES message relocation source does not match the native text boundary"
        )
    replacement = _encode_replacement(operation["text"])
    _validate_native_double_byte_stream(replacement)
    if len(replacement) == len(source_raw):
        raise MessageRelocationPlanError(
            "MES message relocation requires a variable-length replacement"
        )

    operands = statement.get("operands")
    if not isinstance(operands, list) or not operands or not isinstance(operands[0], dict):
        raise MessageRelocationPlanError("MES message relocation text operand is missing")
    operand = operands[0]
    if operand.get("type") != "cp932_bytes" or operand.get("raw_hex") != source_raw.hex():
        raise MessageRelocationPlanError("MES message relocation operand disagrees with its source evidence")
    node_start = int(owner["source"]["start"])
    node_end = int(owner["source"]["end"])
    payload_start = int(operand.get("source_offset", -1))
    payload_end = payload_start + len(source_raw)
    node_raw = bytes.fromhex(str(owner["source"]["raw_hex"]))
    relative_start = payload_start - node_start
    relative_end = payload_end - node_start
    if (
        relative_start < 0
        or relative_end > len(node_raw)
        or node_raw[relative_start:relative_end] != source_raw
    ):
        raise MessageRelocationPlanError("MES message relocation payload boundary changed")
    boundary = _message_boundary(message_value, node_raw, relative_end)
    replacement_node = node_raw[:relative_start] + replacement + node_raw[relative_end:]
    delta = len(replacement) - len(source_raw)

    source_container = decompiler.reconstruct_container(source_ir)
    reopened = noop_compiler.reopen_container(source_container)
    entry_regions = [region for region in source_ir["regions"] if region["kind"] == "entry"]
    source_offsets = [int(region["source_start"]) for region in entry_regions]
    if source_offsets != reopened["entry_offsets"]:
        raise MessageRelocationPlanError("MES message relocation address table disagrees with regions")
    address_updates = [
        {"index": index, "source_offset": offset, "output_offset": offset + delta}
        for index, offset in enumerate(source_offsets)
        if offset >= node_end
    ]

    blockers: list[dict[str, Any]] = []
    for node in source_ir["nodes"]:
        if node["kind"] == "opaque" and int(node["source"]["start"]) >= node_end:
            blockers.append(
                {
                    "code": "opaque_boundary_would_shift",
                    "node_id": str(node["id"]),
                    "source_offset": int(node["source"]["start"]),
                }
            )

    affected_references: list[dict[str, Any]] = []
    for reference in references:
        reference_id = str(reference["id"])
        kind = str(reference["kind"])
        old_source = int(reference["source_offset"])
        new_source = _relocate_offset(old_source, node_start, node_end, delta)
        if node_start < old_source < node_end and reference_id != message["id"]:
            blockers.append(
                {
                    "code": "nonmessage_reference_inside_edited_instruction",
                    "reference_id": reference_id,
                    "source_offset": old_source,
                }
            )
        row: dict[str, Any] = {
            "reference_id": reference_id,
            "kind": kind,
            "source_offset": old_source,
            "output_source_offset": new_source,
        }
        changed = new_source != old_source
        if kind == "code":
            value = reference.get("value")
            if not isinstance(value, dict) or not isinstance(value.get("target_offset"), int):
                raise MessageRelocationPlanError("MES code reference target is missing")
            old_target = int(value["target_offset"])
            new_target = _relocate_offset(old_target, node_start, node_end, delta)
            row["target_offset"] = old_target
            row["output_target_offset"] = new_target
            changed = changed or new_target != old_target
            if node_start < old_target < node_end:
                blockers.append(
                    {
                        "code": "code_target_inside_edited_instruction",
                        "reference_id": reference_id,
                        "target_offset": old_target,
                    }
                )
            elif (
                new_target != old_target
                and str(value.get("kind", "")) != "condition_true_fallthrough"
            ):
                blockers.append(
                    {
                        "code": "encoded_code_target_requires_mw03",
                        "reference_id": reference_id,
                        "source_offset": old_source,
                        "target_offset": old_target,
                        "output_target_offset": new_target,
                    }
                )
        if changed or reference_id == message["id"]:
            affected_references.append(row)

    blockers.sort(key=_blocker_sort_key)
    affected_references.sort(
        key=lambda row: (int(row["source_offset"]), str(row["kind"]), str(row["reference_id"]))
    )
    following_nodes = sum(
        int(node["source"]["start"]) >= node_end for node in source_ir["nodes"]
    )
    following_regions = sum(
        int(region["source_start"]) >= node_end for region in source_ir["regions"]
    )
    return {
        "ok": True,
        "schema": PLAN_SCHEMA,
        "producer": {
            "implementation": "python_phase6_message_relocation_planner",
            "contract": PLAN_SCHEMA,
        },
        "compatibility": copy.deepcopy(COMPATIBILITY),
        "source_identity": copy.deepcopy(source_ir["source_identity"]),
        "inputs": {
            "editable_ir_sha256": editable_document["payload_sha256"],
            "decompiler_ir_sha256": source_ir["payload_sha256"],
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
            "boundary_byte": boundary,
            "source_byte_length": len(source_raw),
            "replacement_byte_length": len(replacement),
            "replacement_raw_hex": replacement.hex(),
            "replacement_raw_sha256": hashlib.sha256(replacement).hexdigest(),
            "replacement_node_raw_hex": replacement_node.hex(),
        },
        "relocation": {
            "delta": delta,
            "pivot_source_end": node_end,
            "output_target_end": node_end + delta,
            "source_code_size": reopened["code_size"],
            "output_code_size": reopened["code_size"] + delta,
            "entry_count": reopened["entry_count"],
            "address_table_updates": address_updates,
            "following_node_count": following_nodes,
            "following_region_count": following_regions,
        },
        "affected_references": affected_references,
        "blockers": blockers,
        "assembly_ready": len(blockers) == 0,
        "invariants": {
            "source_editable_ir_validated": True,
            "target_message_unique_and_typed": True,
            "source_message_hash_matched": True,
            "source_and_replacement_native_projection_matched": True,
            "address_table_exhaustively_planned": True,
            "opaque_bytes_not_rewritten": True,
            "binary_not_published": True,
        },
    }


def _validate_operation(raw: dict[str, Any]) -> dict[str, Any]:
    if not isinstance(raw, dict) or set(raw) != OPERATION_KEYS:
        raise MessageRelocationPlanError("MES message relocation operation fields changed")
    if raw.get("kind") != "replace_message":
        raise MessageRelocationPlanError("unsupported MES message relocation operation")
    if raw.get("encoding") != "cp932":
        raise MessageRelocationPlanError("unsupported MES message relocation encoding")
    if raw.get("native_projection") != "require_match":
        raise MessageRelocationPlanError("unsupported MES native projection policy")
    source_offset = raw.get("source_offset")
    if not isinstance(source_offset, int) or isinstance(source_offset, bool) or source_offset < 0:
        raise MessageRelocationPlanError("MES message relocation source offset is invalid")
    raw_sha256 = raw.get("raw_sha256")
    if not _is_sha256(raw_sha256):
        raise MessageRelocationPlanError("MES message relocation source hash is invalid")
    if not isinstance(raw.get("text"), str):
        raise MessageRelocationPlanError("MES message relocation text is invalid")
    return copy.deepcopy(raw)


def _message_raw_bytes(value: dict[str, Any]) -> bytes:
    raw_hex = value.get("raw_hex")
    if not isinstance(raw_hex, str):
        raise MessageRelocationPlanError("MES message relocation raw source is missing")
    try:
        raw = bytes.fromhex(raw_hex)
    except ValueError as error:
        raise MessageRelocationPlanError("MES message relocation raw source is invalid") from error
    if value.get("raw_sha256") != hashlib.sha256(raw).hexdigest():
        raise MessageRelocationPlanError("MES message relocation indexed source hash changed")
    return raw


def _encode_replacement(text: str) -> bytes:
    try:
        encoded = text.encode("cp932", errors="strict")
    except UnicodeEncodeError as error:
        raise MessageRelocationPlanError(
            "MES message relocation text cannot encode as CP932"
        ) from error
    if b"\x00" in encoded:
        raise MessageRelocationPlanError("MES message relocation text contains NUL")
    return encoded


def _validate_native_double_byte_stream(data: bytes) -> None:
    offset = 0
    while offset < len(data):
        lead = data[offset]
        if lead < 0x81 or (lead > 0x9F and lead < 0xE0) or lead > 0xFC:
            raise MessageRelocationPlanError(
                "MES message relocation replacement does not preserve the native double-byte projection"
            )
        if 0xF0 <= lead <= 0xF9 or offset + 1 >= len(data):
            raise MessageRelocationPlanError(
                "MES message relocation replacement uses an unsupported native lead byte"
            )
        offset += 2


def _message_boundary(value: dict[str, Any], node_raw: bytes, relative_end: int) -> int:
    probe = value.get("native_stream_probe")
    if not isinstance(probe, dict):
        raise MessageRelocationPlanError("MES message relocation native probe is missing")
    reason = probe.get("stop_reason")
    expected = 0x00 if reason == "nul_consumed" else 0xFF if reason == "single_byte_marker_deferred" else -1
    if expected < 0 or relative_end >= len(node_raw) or node_raw[relative_end] != expected:
        raise MessageRelocationPlanError("MES message relocation native boundary changed")
    return expected


def _relocate_offset(value: int, node_start: int, node_end: int, delta: int) -> int:
    if value >= node_end:
        return value + delta
    return value


def _blocker_sort_key(row: dict[str, Any]) -> tuple[Any, ...]:
    return (
        int(row.get("source_offset", row.get("target_offset", -1))),
        str(row.get("code", "")),
        str(row.get("reference_id", row.get("node_id", ""))),
    )


def main() -> None:
    parser = argparse.ArgumentParser(
        description=(
            "Build a fail-closed JSON relocation preflight for one variable-length "
            "CP932 MES message edit. This tool never publishes MES bytes."
        )
    )
    parser.add_argument("editable_ir", type=Path)
    parser.add_argument("operation", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    resolved = {args.editable_ir.resolve(), args.operation.resolve(), args.output.resolve()}
    if len(resolved) != 3:
        raise MessageRelocationPlanError("MES relocation input and output paths must differ")
    try:
        editable_document = json.loads(args.editable_ir.read_text(encoding="utf-8"))
        operation = json.loads(args.operation.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise MessageRelocationPlanError("MES relocation input JSON could not be read") from error
    if not isinstance(editable_document, dict) or not isinstance(operation, dict):
        raise MessageRelocationPlanError("MES relocation inputs must be JSON objects")
    document = plan(editable_document, operation)
    editable_ir.publish_new(
        args.output, editable_ir.canonical_json_bytes(document) + b"\n"
    )
    print(
        "MES_MESSAGE_RELOCATION_PLAN_PASS "
        f"schema={document['schema']} "
        f"entry={document['source_identity'].get('entry', '')} "
        f"offset=0x{document['operation']['source_offset']:X} "
        f"delta={document['relocation']['delta']} "
        f"blockers={len(document['blockers'])} "
        f"assembly_ready={str(document['assembly_ready']).lower()} "
        f"payload_sha256={document['payload_sha256']}"
    )


if __name__ == "__main__":
    main()
