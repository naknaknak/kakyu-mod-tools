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


PLAN_SCHEMA = "kakyu_mes_address_entry_insert_plan/v1"
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
    "coverage",
    "assembly_ready",
    "invariants",
    "payload_sha256",
}
OPERATION_KEYS = {
    "kind",
    "owner_entry_index",
    "target_offset",
    "instruction_raw_sha256",
}
TARGET_KEYS = {
    "node_id",
    "evidence_status",
    "source_region_id",
    "source_region_index",
    "source_region_start",
    "source_region_end",
    "instruction_start",
    "instruction_end",
    "instruction_raw_sha256",
    "op",
    "command_id",
}
TABLE_CHANGE_KEYS = {
    "source_entry_count",
    "output_entry_count",
    "insertion_index",
    "inserted_offset",
    "inserted_raw_hex",
    "previous_entry_offset",
    "next_entry_offset",
    "source_code_offset",
    "output_code_offset",
    "source_preamble_sha256",
    "output_preamble_sha256",
    "source_address_table_sha256",
    "output_address_table_sha256",
}
COVERAGE_KEYS = {
    "source_code_size",
    "output_code_size",
    "source_node_count",
    "moved_node_count",
    "moved_reference_count",
}
COMPATIBILITY = {
    "policy": "planning_only_insert_one_address_entry_boundary",
    "input_editable_schema": editable_ir.EDITABLE_IR_SCHEMA,
    "input_decompiler_schema": decompiler.DECOMPILER_IR_SCHEMA,
    "supported_operation": "insert_address_entry",
    "target_policy": "strict_typed_instruction_start_inside_existing_entry",
    "bootstrap_policy": "cannot_split_bootstrap",
    "code_coordinate_policy": "unchanged_code_relative_offsets",
    "bytecode_policy": "unchanged",
    "binary_publication": "forbidden",
    "native_engine_compatibility": "unverified",
    "unknown_plan_schema": "reject",
    "unknown_v1_field": "reject",
}
INVARIANTS = {
    "source_editable_ir_validated": True,
    "source_preamble_rebuilt_exactly": True,
    "target_node_unique_and_typed": True,
    "target_instruction_hash_matched": True,
    "target_is_strictly_inside_source_entry": True,
    "address_offsets_remain_strictly_increasing": True,
    "bytecode_and_code_coordinates_unchanged": True,
    "opaque_bytes_not_rewritten": True,
    "binary_not_published": True,
}


class AddressEntryInsertPlanError(ValueError):
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
        raise AddressEntryInsertPlanError(
            "MES address-entry insertion plan schema or fields changed"
        )
    if document.get("producer") != {
        "implementation": "python_phase6_address_entry_insert_planner",
        "contract": PLAN_SCHEMA,
    }:
        raise AddressEntryInsertPlanError(
            "MES address-entry insertion plan producer changed"
        )
    if document.get("compatibility") != COMPATIBILITY:
        raise AddressEntryInsertPlanError(
            "MES address-entry insertion compatibility changed"
        )
    retained = document.get("payload_sha256")
    if not _is_sha256(retained) or fingerprint(document) != retained:
        raise AddressEntryInsertPlanError(
            "MES address-entry insertion plan fingerprint changed"
        )
    if (
        not isinstance(document.get("operation"), dict)
        or set(document["operation"]) != OPERATION_KEYS
        or not isinstance(document.get("target"), dict)
        or set(document["target"]) != TARGET_KEYS
        or not isinstance(document.get("table_change"), dict)
        or set(document["table_change"]) != TABLE_CHANGE_KEYS
        or not isinstance(document.get("coverage"), dict)
        or set(document["coverage"]) != COVERAGE_KEYS
    ):
        raise AddressEntryInsertPlanError(
            "MES address-entry insertion plan component fields changed"
        )
    if document.get("assembly_ready") is not True:
        raise AddressEntryInsertPlanError(
            "MES address-entry insertion plan is not assembly ready"
        )
    if document.get("invariants") != INVARIANTS:
        raise AddressEntryInsertPlanError(
            "MES address-entry insertion invariants changed"
        )
    if editable_document is not None:
        expected = _build_plan(
            editable_document, copy.deepcopy(document["operation"])
        )
        expected["payload_sha256"] = fingerprint(expected)
        if expected != document:
            raise AddressEntryInsertPlanError(
                "MES address-entry insertion plan differs from its source"
            )
    return {"ok": True, "schema": PLAN_SCHEMA, "payload_sha256": retained}


def _build_plan(
    editable_document: dict[str, Any], raw_operation: dict[str, Any]
) -> dict[str, Any]:
    editable_ir.validate(editable_document)
    operation = _validate_operation(raw_operation)
    source_ir = editable_document["source_ir"]
    container = source_ir["container"]
    preamble, offsets = _rebuild_source_preamble(container)
    regions = _entry_regions(source_ir, offsets, int(container["code_size"]))
    owner_index = operation["owner_entry_index"]
    if owner_index >= len(regions):
        raise AddressEntryInsertPlanError(
            "MES address-entry insertion owner index is out of range"
        )
    owner = regions[owner_index]
    target_offset = operation["target_offset"]
    if not (owner["source_start"] < target_offset < owner["source_end"]):
        raise AddressEntryInsertPlanError(
            "MES address-entry insertion target is not strictly inside its source entry"
        )
    candidates = [
        node
        for node in source_ir["nodes"]
        if _exact_int(node.get("source", {}).get("start")) == target_offset
    ]
    if len(candidates) != 1:
        raise AddressEntryInsertPlanError(
            "MES address-entry insertion target is not one unique instruction start"
        )
    node = candidates[0]
    source = node.get("source")
    statement = node.get("statement")
    metadata = statement.get("metadata", {}) if isinstance(statement, dict) else {}
    if (
        node.get("kind") != "statement"
        or node.get("evidence_status") != decompiler.TYPED_EVIDENCE_STATUS
        or not isinstance(source, dict)
        or not isinstance(statement, dict)
        or statement.get("kind") != "instruction"
        or source.get("region") != owner["id"]
        or metadata.get("structural_only") is True
    ):
        raise AddressEntryInsertPlanError(
            "MES address-entry insertion target is not a strict typed instruction"
        )
    raw_sha256 = str(source.get("raw_sha256", ""))
    if (
        not _is_sha256(raw_sha256)
        or raw_sha256 != operation["instruction_raw_sha256"]
    ):
        raise AddressEntryInsertPlanError(
            "MES address-entry insertion instruction hash is stale"
        )
    insertion_index = owner_index + 1
    output_offsets = offsets[:insertion_index] + [target_offset] + offsets[insertion_index:]
    if any(
        output_offsets[index] >= output_offsets[index + 1]
        for index in range(len(output_offsets) - 1)
    ):
        raise AddressEntryInsertPlanError(
            "MES address-entry insertion offsets are not strictly increasing"
        )
    source_table = b"".join(value.to_bytes(4, "little") for value in offsets)
    output_table = b"".join(value.to_bytes(4, "little") for value in output_offsets)
    output_preamble = len(output_offsets).to_bytes(4, "little") + output_table
    moved_nodes = [
        row
        for row in source_ir["nodes"]
        if target_offset
        <= int(row.get("source", {}).get("start", -1))
        < owner["source_end"]
    ]
    moved_references = [
        row
        for row in source_ir["references"]
        if target_offset <= int(row.get("source_offset", -1)) < owner["source_end"]
    ]
    return {
        "ok": True,
        "schema": PLAN_SCHEMA,
        "producer": {
            "implementation": "python_phase6_address_entry_insert_planner",
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
            "node_id": str(node["id"]),
            "evidence_status": str(node["evidence_status"]),
            "source_region_id": str(owner["id"]),
            "source_region_index": owner_index,
            "source_region_start": owner["source_start"],
            "source_region_end": owner["source_end"],
            "instruction_start": target_offset,
            "instruction_end": int(source["end"]),
            "instruction_raw_sha256": raw_sha256,
            "op": str(statement.get("op", "")),
            "command_id": int(statement.get("command_id", -1)),
        },
        "table_change": {
            "source_entry_count": len(offsets),
            "output_entry_count": len(output_offsets),
            "insertion_index": insertion_index,
            "inserted_offset": target_offset,
            "inserted_raw_hex": target_offset.to_bytes(4, "little").hex(),
            "previous_entry_offset": offsets[owner_index],
            "next_entry_offset": (
                offsets[insertion_index]
                if insertion_index < len(offsets)
                else int(container["code_size"])
            ),
            "source_code_offset": int(container["code_offset"]),
            "output_code_offset": int(container["code_offset"]) + 4,
            "source_preamble_sha256": hashlib.sha256(preamble).hexdigest(),
            "output_preamble_sha256": hashlib.sha256(output_preamble).hexdigest(),
            "source_address_table_sha256": hashlib.sha256(source_table).hexdigest(),
            "output_address_table_sha256": hashlib.sha256(output_table).hexdigest(),
        },
        "coverage": {
            "source_code_size": int(container["code_size"]),
            "output_code_size": int(container["code_size"]),
            "source_node_count": int(source_ir["coverage"]["node_count"]),
            "moved_node_count": len(moved_nodes),
            "moved_reference_count": len(moved_references),
        },
        "assembly_ready": True,
        "invariants": copy.deepcopy(INVARIANTS),
    }


def _validate_operation(value: dict[str, Any]) -> dict[str, Any]:
    if not isinstance(value, dict) or set(value) != OPERATION_KEYS:
        raise AddressEntryInsertPlanError(
            "MES address-entry insertion operation fields changed"
        )
    if value.get("kind") != "insert_address_entry":
        raise AddressEntryInsertPlanError(
            "MES address-entry insertion operation kind changed"
        )
    owner_index = _exact_int(value.get("owner_entry_index"))
    target_offset = _exact_int(value.get("target_offset"))
    raw_sha256 = value.get("instruction_raw_sha256")
    if (
        owner_index is None
        or owner_index < 0
        or target_offset is None
        or target_offset < 0
        or not _is_sha256(raw_sha256)
    ):
        raise AddressEntryInsertPlanError(
            "MES address-entry insertion operation value changed"
        )
    return {
        "kind": "insert_address_entry",
        "owner_entry_index": owner_index,
        "target_offset": target_offset,
        "instruction_raw_sha256": str(raw_sha256),
    }


def _rebuild_source_preamble(container: dict[str, Any]) -> tuple[bytes, list[int]]:
    try:
        preamble = bytes.fromhex(str(container.get("preamble_raw_hex", "")))
    except ValueError as error:
        raise AddressEntryInsertPlanError(
            "MES address-entry insertion source preamble is invalid"
        ) from error
    code_offset = _exact_int(container.get("code_offset"))
    code_size = _exact_int(container.get("code_size"))
    if (
        code_offset is None
        or code_size is None
        or code_offset < 4
        or code_size < 0
        or len(preamble) != code_offset
        or hashlib.sha256(preamble).hexdigest()
        != container.get("preamble_sha256")
    ):
        raise AddressEntryInsertPlanError(
            "MES address-entry insertion source preamble changed"
        )
    count = int.from_bytes(preamble[:4], "little")
    if code_offset != 4 + count * 4:
        raise AddressEntryInsertPlanError(
            "MES address-entry insertion source address table is malformed"
        )
    offsets = [
        int.from_bytes(preamble[4 + index * 4 : 8 + index * 4], "little")
        for index in range(count)
    ]
    if (
        count == 0
        or any(value < 0 or value >= code_size for value in offsets)
        or any(offsets[index] >= offsets[index + 1] for index in range(count - 1))
    ):
        raise AddressEntryInsertPlanError(
            "MES address-entry insertion source offsets are invalid"
        )
    return preamble, offsets


def _entry_regions(
    source_ir: dict[str, Any], offsets: list[int], code_size: int
) -> list[dict[str, Any]]:
    regions = [row for row in source_ir["regions"] if row.get("kind") == "entry"]
    if len(regions) != len(offsets):
        raise AddressEntryInsertPlanError(
            "MES address-entry insertion source regions changed"
        )
    for index, region in enumerate(regions):
        expected_end = offsets[index + 1] if index + 1 < len(offsets) else code_size
        if (
            _exact_int(region.get("index")) != index
            or region.get("id") != f"entry_{index:04d}"
            or _exact_int(region.get("source_start")) != offsets[index]
            or _exact_int(region.get("source_end")) != expected_end
        ):
            raise AddressEntryInsertPlanError(
                "MES address-entry insertion source region partition changed"
            )
    return regions


def _exact_int(value: Any) -> int | None:
    return value if isinstance(value, int) and not isinstance(value, bool) else None


def main() -> None:
    parser = argparse.ArgumentParser(
        description=(
            "Plan one new MES address-table entry at a strict typed instruction "
            "boundary without publishing MES bytes."
        )
    )
    parser.add_argument("editable_ir", type=Path)
    parser.add_argument("operation", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    editable_path = args.editable_ir.resolve()
    operation_path = args.operation.resolve()
    output_path = args.output.resolve()
    if output_path.exists() or output_path in {editable_path, operation_path}:
        raise AddressEntryInsertPlanError(
            "MES address-entry insertion output must be a new path"
        )
    editable_document = json.loads(editable_path.read_text(encoding="utf-8"))
    operation = json.loads(operation_path.read_text(encoding="utf-8"))
    document = plan(editable_document, operation)
    editable_ir.publish_new(
        output_path, editable_ir.canonical_json_bytes(document) + b"\n"
    )
    print(
        "MES_ADDRESS_ENTRY_INSERT_PLAN_PASS "
        f"schema={PLAN_SCHEMA} entry={document['source_identity']['entry']} "
        f"source_entries={document['table_change']['source_entry_count']} "
        f"output_entries={document['table_change']['output_entry_count']} "
        f"insert_index={document['table_change']['insertion_index']} "
        f"target=0x{document['target']['instruction_start']:X} "
        f"payload_sha256={document['payload_sha256']}"
    )


if __name__ == "__main__":
    main()
