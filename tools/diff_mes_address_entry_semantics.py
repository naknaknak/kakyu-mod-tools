from __future__ import annotations

import argparse
import copy
import hashlib
import json
from pathlib import Path
from typing import Any

import compile_mes_address_entry_insert as entry_compiler
import compile_mes_noop as noop_compiler
import decompile_mes_handoff as decompiler
import prepare_mes_editable_ir as editable_ir
import validate_mes_analyzer_handoff as handoff_validator
from payload_values import canonical_payload_bytes, fingerprint, is_sha256 as _is_sha256


DIFF_SCHEMA = "kakyu_mes_semantic_diff/v3"
TOP_LEVEL_KEYS = {
    "ok", "schema", "producer", "compatibility", "source_identity", "inputs",
    "operation", "container_diff", "semantic_changes", "node_diff", "preservation",
    "output_binding", "invariants", "payload_sha256",
}
COMPATIBILITY = {
    "policy": "address_entry_insert_with_byte_identical_code_and_exact_node_mapping",
    "input_editable_schema": editable_ir.EDITABLE_IR_SCHEMA,
    "input_compile_audit_schemas": [entry_compiler.AUDIT_SCHEMA],
    "input_handoff_schema": handoff_validator.HANDOFF_SCHEMA,
    "output_decompiler_schema": decompiler.DECOMPILER_IR_SCHEMA,
    "supported_families": ["address_entry_insert"],
    "unknown_diff_schema": "reject",
    "unknown_v3_field": "reject",
}
INVARIANTS = {
    "source_editable_ir_validated": True,
    "compile_audit_validated": True,
    "output_handoff_validated": True,
    "output_decompiler_ir_validated": True,
    "expected_output_bytes_exact": True,
    "address_entry_insert_exact": True,
    "bytecode_preserved_exactly": True,
    "all_nodes_mapped_once": True,
    "all_node_bytes_preserved": True,
    "all_node_statements_preserved": True,
    "all_references_preserved": True,
    "region_partition_change_exact": True,
}


class MesAddressEntrySemanticDiffError(ValueError):
    pass


def build(
    editable_document: dict[str, Any], audit: dict[str, Any], handoff: dict[str, Any],
) -> dict[str, Any]:
    result = _build(editable_document, audit, handoff)
    result["payload_sha256"] = fingerprint(result)
    validate(result, editable_document, audit, handoff)
    return result


def validate(
    document: dict[str, Any], editable_document: dict[str, Any] | None = None,
    audit: dict[str, Any] | None = None, handoff: dict[str, Any] | None = None,
) -> dict[str, Any]:
    if (
        document.get("ok") is not True
        or document.get("schema") != DIFF_SCHEMA
        or set(document) != TOP_LEVEL_KEYS
    ):
        raise MesAddressEntrySemanticDiffError(
            "MES address-entry semantic diff schema or fields changed"
        )
    if document.get("producer") != {
        "implementation": "python_phase6_address_entry_semantic_diff",
        "contract": DIFF_SCHEMA,
    } or document.get("compatibility") != COMPATIBILITY:
        raise MesAddressEntrySemanticDiffError(
            "MES address-entry semantic diff producer or compatibility changed"
        )
    retained = document.get("payload_sha256")
    if not _is_sha256(retained) or fingerprint(document) != retained:
        raise MesAddressEntrySemanticDiffError(
            "MES address-entry semantic diff fingerprint changed"
        )
    _validate_shape(document)
    supplied = (editable_document, audit, handoff)
    if any(value is not None for value in supplied):
        if any(value is None for value in supplied):
            raise MesAddressEntrySemanticDiffError(
                "MES address-entry semantic diff inputs are incomplete"
            )
        expected = _build(editable_document, audit, handoff)  # type: ignore[arg-type]
        expected["payload_sha256"] = fingerprint(expected)
        if expected != document:
            raise MesAddressEntrySemanticDiffError(
                "MES address-entry semantic diff differs from its inputs"
            )
    return {"ok": True, "schema": DIFF_SCHEMA, "payload_sha256": retained}


def _build(
    editable_document: dict[str, Any], audit: dict[str, Any], handoff: dict[str, Any],
) -> dict[str, Any]:
    editable_ir.validate(editable_document)
    entry_compiler.validate_audit(audit)
    handoff_validator.validate(handoff)
    source_ir = editable_document["source_ir"]
    output_ir = decompiler.lift(handoff)
    if (
        source_ir["source_identity"] != audit["source_identity"]
        or source_ir["source_identity"] != output_ir["source_identity"]
        or audit["inputs"]["editable_ir_sha256"] != editable_document["payload_sha256"]
        or audit["inputs"]["decompiler_ir_sha256"] != source_ir["payload_sha256"]
    ):
        raise MesAddressEntrySemanticDiffError(
            "MES address-entry semantic diff source binding changed"
        )
    source = decompiler.reconstruct_container(source_ir)
    output = decompiler.reconstruct_container(output_ir)
    if hashlib.sha256(source).hexdigest() != audit["source"]["entry_sha256"]:
        raise MesAddressEntrySemanticDiffError(
            "MES address-entry semantic diff source container changed"
        )
    if hashlib.sha256(output).hexdigest() != audit["output"]["entry_sha256"]:
        raise MesAddressEntrySemanticDiffError(
            "MES address-entry semantic diff output container changed"
        )
    source_header = noop_compiler.reopen_container(source)
    output_header = noop_compiler.reopen_container(output)
    table = audit["table_change"]
    insertion_index = int(table["insertion_index"])
    inserted_offset = int(table["inserted_offset"])
    expected_offsets = (
        source_header["entry_offsets"][:insertion_index]
        + [inserted_offset]
        + source_header["entry_offsets"][insertion_index:]
    )
    expected_preamble = len(expected_offsets).to_bytes(4, "little") + b"".join(
        offset.to_bytes(4, "little") for offset in expected_offsets
    )
    source_code = source[int(audit["source"]["code_offset"]):]
    if (
        output_header["entry_offsets"] != expected_offsets
        or output[:int(audit["output"]["code_offset"])] != expected_preamble
        or output[int(audit["output"]["code_offset"]):] != source_code
        or audit["source"]["bytecode_sha256"] != audit["output"]["bytecode_sha256"]
    ):
        raise MesAddressEntrySemanticDiffError(
            "MES address-entry semantic diff output bytes exceed the inserted cell"
        )

    source_nodes = {int(row["source"]["start"]): row for row in source_ir["nodes"]}
    output_nodes = {int(row["source"]["start"]): row for row in output_ir["nodes"]}
    if set(source_nodes) != set(output_nodes) or len(source_nodes) != len(source_ir["nodes"]):
        raise MesAddressEntrySemanticDiffError(
            "MES address-entry semantic diff node starts changed"
        )
    mapping = []
    region_changes = []
    typed = opaque = 0
    for start in sorted(source_nodes):
        source_node = source_nodes[start]
        output_node = output_nodes[start]
        if not _node_preserved(source_node, output_node):
            raise MesAddressEntrySemanticDiffError(
                "MES address-entry semantic diff changed a node outside region ownership"
            )
        kind = str(source_node["kind"])
        typed += int(kind == "statement")
        opaque += int(kind == "opaque")
        source_region = str(source_node["source"]["region"])
        output_region = str(output_node["source"]["region"])
        row = {
            "node_id": str(source_node["id"]), "start": start,
            "end": int(source_node["source"]["end"]), "kind": kind,
            "raw_sha256": str(source_node["source"]["raw_sha256"]),
            "source_region": source_region, "output_region": output_region,
        }
        mapping.append(row)
        if source_region != output_region:
            region_changes.append(row)
    reference_region_changes = _reference_region_changes(
        source_ir["references"], output_ir["references"], output_ir["regions"]
    )
    target = audit["target"]
    source_target_node = source_nodes.get(inserted_offset)
    target_node = output_nodes.get(inserted_offset)
    new_region = f"entry_{insertion_index:04d}"
    if (
        source_target_node is None
        or source_target_node["source"]["region"] != target["source_region_id"]
        or target_node is None
        or target_node["kind"] != "statement"
        or target_node["source"]["raw_sha256"] != target["instruction_raw_sha256"]
        or target_node["source"]["region"] != new_region
        or target_node["id"] != target["node_id"]
    ):
        raise MesAddressEntrySemanticDiffError(
            "MES address-entry semantic diff target instruction changed"
        )
    output_regions = {
        (str(row["kind"]), row["index"]): row for row in output_ir["regions"]
    }
    new_region_row = output_regions.get(("entry", insertion_index))
    if new_region_row is None or int(new_region_row["source_start"]) != inserted_offset:
        raise MesAddressEntrySemanticDiffError(
            "MES address-entry semantic diff new region boundary changed"
        )
    operation = audit["operation"]
    return {
        "ok": True, "schema": DIFF_SCHEMA,
        "producer": {
            "implementation": "python_phase6_address_entry_semantic_diff",
            "contract": DIFF_SCHEMA,
        },
        "compatibility": copy.deepcopy(COMPATIBILITY),
        "source_identity": copy.deepcopy(source_ir["source_identity"]),
        "inputs": {
            "editable_ir_sha256": editable_document["payload_sha256"],
            "source_decompiler_ir_sha256": source_ir["payload_sha256"],
            "compile_audit_sha256": audit["payload_sha256"],
            "output_analyzer_handoff_sha256": handoff["payload_sha256"],
        },
        "operation": {"family": "address_entry_insert", "kind": operation["kind"]},
        "container_diff": {
            "source_size": len(source), "output_size": len(output),
            "byte_delta": len(output) - len(source),
            "source_entry_count": int(audit["source"]["entry_count"]),
            "output_entry_count": int(audit["output"]["entry_count"]),
            "entry_delta": int(audit["output"]["entry_count"]) - int(audit["source"]["entry_count"]),
            "source_code_offset": int(audit["source"]["code_offset"]),
            "output_code_offset": int(audit["output"]["code_offset"]),
            "code_offset_delta": int(audit["output"]["code_offset"]) - int(audit["source"]["code_offset"]),
            "source_code_size": len(source_code), "output_code_size": len(source_code),
            "code_delta": 0,
        },
        "semantic_changes": {
            "address_entry": {
                "insertion_index": insertion_index, "inserted_offset": inserted_offset,
                "inserted_raw_sha256": hashlib.sha256(bytes.fromhex(table["inserted_raw_hex"])).hexdigest(),
                "source_owner_region": str(target["source_region_id"]),
                "output_new_region": new_region, "target_node_id": str(target["node_id"]),
                "target_instruction_sha256": str(target["instruction_raw_sha256"]),
                "target_verified": True,
            },
            "region_changes_sha256": _json_sha256(region_changes),
            "reference_region_changes_sha256": _json_sha256(reference_region_changes),
        },
        "node_diff": {
            "source_node_count": len(source_nodes), "output_node_count": len(output_nodes),
            "exact_raw_node_count": len(mapping),
            "region_changed_node_count": len(region_changes),
            "region_unchanged_node_count": len(mapping) - len(region_changes),
            "mapping_sha256": _json_sha256(mapping),
        },
        "preservation": {
            "source_typed_node_count": typed, "output_typed_node_count": typed,
            "source_opaque_node_count": opaque, "output_opaque_node_count": opaque,
            "source_bytecode_sha256": audit["source"]["bytecode_sha256"],
            "output_bytecode_sha256": audit["output"]["bytecode_sha256"],
            "bytecode_exact": True, "reference_coordinates_exact": True,
            "statements_exact": True,
        },
        "output_binding": {
            "analyzer_handoff_sha256": handoff["payload_sha256"],
            "decompiler_ir_sha256": output_ir["payload_sha256"],
            "entry_sha256": output_ir["container"]["entry_sha256"],
            "bytecode_sha256": output_ir["container"]["bytecode_sha256"],
        },
        "invariants": copy.deepcopy(INVARIANTS),
    }


def _node_preserved(source: dict[str, Any], output: dict[str, Any]) -> bool:
    source_copy = copy.deepcopy(source)
    output_copy = copy.deepcopy(output)
    source_copy["source"].pop("region", None)
    output_copy["source"].pop("region", None)
    # The standard changed-file handoff intentionally carries no focused CFG
    # request; CFG source-map rows are input-query evidence, not node semantics.
    source_copy.pop("cfg_nodes", None)
    output_copy.pop("cfg_nodes", None)
    return source_copy == output_copy


def _reference_region_changes(
    source_rows: list[dict[str, Any]], output_rows: list[dict[str, Any]],
    output_regions: list[dict[str, Any]],
) -> list[dict[str, Any]]:
    if len(source_rows) != len(output_rows):
        raise MesAddressEntrySemanticDiffError(
            "MES address-entry semantic diff reference count changed"
        )
    changes = []
    for source, output in zip(source_rows, output_rows):
        source_copy = copy.deepcopy(source)
        output_copy = copy.deepcopy(output)
        source_ownership = {}
        output_ownership = {}
        for field in ("region", "target_region"):
            source_ownership[field] = source_copy.get("value", {}).pop(field, None)
            output_ownership[field] = output_copy.get("value", {}).pop(field, None)
        if source_copy != output_copy:
            raise MesAddressEntrySemanticDiffError(
                "MES address-entry semantic diff changed a reference coordinate"
            )
        for field, coordinate in (("region", "source_offset"), ("target_region", "target_offset")):
            source_region = source_ownership[field]
            output_region = output_ownership[field]
            offset = output.get("value", {}).get(coordinate)
            if output_region is None:
                if source_region is not None:
                    raise MesAddressEntrySemanticDiffError(
                        "MES address-entry semantic diff dropped reference region ownership"
                    )
                continue
            if offset is None:
                raise MesAddressEntrySemanticDiffError(
                    "MES address-entry semantic diff reference region lacks its coordinate"
                )
            expected_region = next((
                row["id"] for row in output_regions
                if int(row["source_start"]) <= int(offset) < int(row["source_end"])
            ), None)
            if output_region != expected_region:
                raise MesAddressEntrySemanticDiffError(
                    "MES address-entry semantic diff reference region changed unexpectedly"
                )
            if source_region != output_region:
                changes.append({
                    "reference_id": str(source["id"]), "field": field,
                    "source_region": source_region, "output_region": output_region,
                    "coordinate": int(offset),
                })
    return changes


def _validate_shape(document: dict[str, Any]) -> None:
    expected_keys = {
        "inputs": {"editable_ir_sha256", "source_decompiler_ir_sha256", "compile_audit_sha256", "output_analyzer_handoff_sha256"},
        "operation": {"family", "kind"},
        "container_diff": {"source_size", "output_size", "byte_delta", "source_entry_count", "output_entry_count", "entry_delta", "source_code_offset", "output_code_offset", "code_offset_delta", "source_code_size", "output_code_size", "code_delta"},
        "semantic_changes": {
            "address_entry", "region_changes_sha256", "reference_region_changes_sha256",
        },
        "node_diff": {"source_node_count", "output_node_count", "exact_raw_node_count", "region_changed_node_count", "region_unchanged_node_count", "mapping_sha256"},
        "preservation": {"source_typed_node_count", "output_typed_node_count", "source_opaque_node_count", "output_opaque_node_count", "source_bytecode_sha256", "output_bytecode_sha256", "bytecode_exact", "reference_coordinates_exact", "statements_exact"},
        "output_binding": {"analyzer_handoff_sha256", "decompiler_ir_sha256", "entry_sha256", "bytecode_sha256"},
    }
    for key, keys in expected_keys.items():
        if not isinstance(document.get(key), dict) or set(document[key]) != keys:
            raise MesAddressEntrySemanticDiffError(
                f"MES address-entry semantic diff {key} fields changed"
            )
    address = document["semantic_changes"].get("address_entry")
    if not isinstance(address, dict) or set(address) != {
        "insertion_index", "inserted_offset", "inserted_raw_sha256",
        "source_owner_region", "output_new_region", "target_node_id",
        "target_instruction_sha256", "target_verified",
    }:
        raise MesAddressEntrySemanticDiffError(
            "MES address-entry semantic diff address fields changed"
        )
    diff = document["container_diff"]
    nodes = document["node_diff"]
    preservation = document["preservation"]
    if (
        document["operation"] != {"family": "address_entry_insert", "kind": "insert_address_entry"}
        or diff["byte_delta"] != 4 or diff["entry_delta"] != 1
        or diff["code_offset_delta"] != 4 or diff["code_delta"] != 0
        or nodes["source_node_count"] != nodes["output_node_count"]
        or nodes["exact_raw_node_count"] != nodes["source_node_count"]
        or nodes["region_changed_node_count"] + nodes["region_unchanged_node_count"] != nodes["source_node_count"]
        or preservation["source_typed_node_count"] != preservation["output_typed_node_count"]
        or preservation["source_opaque_node_count"] != preservation["output_opaque_node_count"]
        or preservation["source_bytecode_sha256"] != preservation["output_bytecode_sha256"]
        or any(preservation[key] is not True for key in (
            "bytecode_exact", "reference_coordinates_exact", "statements_exact",
        ))
        or address["target_verified"] is not True
        or document.get("invariants") != INVARIANTS
    ):
        raise MesAddressEntrySemanticDiffError(
            "MES address-entry semantic diff accounting changed"
        )
    hash_values = [
        document["payload_sha256"], document["semantic_changes"]["region_changes_sha256"],
        document["semantic_changes"]["reference_region_changes_sha256"],
        nodes["mapping_sha256"], address["inserted_raw_sha256"],
        address["target_instruction_sha256"], *document["inputs"].values(),
        preservation["source_bytecode_sha256"], preservation["output_bytecode_sha256"],
        *document["output_binding"].values(),
    ]
    if not all(_is_sha256(value) for value in hash_values):
        raise MesAddressEntrySemanticDiffError(
            "MES address-entry semantic diff hash changed"
        )


def _json_sha256(value: Any) -> str:
    return hashlib.sha256(json.dumps(
        value, ensure_ascii=False, allow_nan=False, sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")).hexdigest()


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Build an exact semantic diff for one MES address-entry insertion."
    )
    parser.add_argument("editable_ir", type=Path)
    parser.add_argument("compile_audit", type=Path)
    parser.add_argument("output_handoff", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    paths = [path.resolve() for path in (
        args.editable_ir, args.compile_audit, args.output_handoff, args.output,
    )]
    if len(set(paths)) != 4 or args.output.exists():
        raise MesAddressEntrySemanticDiffError(
            "MES address-entry semantic diff output must be new and distinct"
        )
    documents = [json.loads(path.read_text("utf-8")) for path in paths[:3]]
    result = build(*documents)
    editable_ir.publish_new(
        args.output, editable_ir.canonical_json_bytes(result) + b"\n"
    )
    validate(json.loads(args.output.read_text("utf-8")), *documents)
    print(
        "MES_ADDRESS_ENTRY_SEMANTIC_DIFF_PASS "
        f"schema={DIFF_SCHEMA} entry={result['source_identity']['entry']} "
        f"insert_index={result['semantic_changes']['address_entry']['insertion_index']} "
        f"target=0x{result['semantic_changes']['address_entry']['inserted_offset']:X} "
        f"nodes={result['node_diff']['source_node_count']} "
        f"payload_sha256={result['payload_sha256']}"
    )


if __name__ == "__main__":
    main()
