from __future__ import annotations

import argparse
import copy
import hashlib
import json
from pathlib import Path
from typing import Any

import compile_mes_noop as noop_compiler
import decompile_mes_handoff as decompiler
import plan_mes_control_target_relocation as target_relocation
import prepare_mes_editable_ir as editable_ir
from payload_values import canonical_payload_bytes, fingerprint, is_sha256 as _is_sha256


PLAN_SCHEMA = "kakyu_mes_control_body_edit_plan/v1"
TOP_LEVEL_KEYS = {
    "ok", "schema", "producer", "compatibility", "source_identity", "inputs",
    "operation", "body", "relocation", "address_table_updates", "region_updates",
    "node_map", "reference_map", "target_patches", "cfg_relocation",
    "evidence_inventory", "blockers", "assembly_ready", "invariants",
    "payload_sha256",
}
INSERT_OPERATION_KEYS = {
    "kind", "anchor_offset", "anchor_instruction_raw_sha256", "donor_start",
    "donor_end", "donor_span_raw_sha256",
}
REMOVE_OPERATION_KEYS = {
    "kind", "body_start", "body_end", "body_span_raw_sha256",
}
BODY_KEYS = {
    "policy", "source_region_id", "source_start", "source_end", "byte_length",
    "source_raw_hex", "source_raw_sha256", "source_node_ids", "source_node_hashes",
    "output_start", "output_end", "output_raw_sha256", "inserted_node_map",
}
INSERTED_NODE_KEYS = {
    "source_node_id", "source_start", "source_end", "output_node_id",
    "output_start", "output_end", "raw_sha256",
}
RELOCATION_KEYS = {
    "delta", "pivot", "source_code_size", "output_code_size", "entry_count",
    "affected_address_count", "affected_region_count", "affected_node_count",
    "affected_reference_count", "target_patch_count", "cfg_node_count",
    "cfg_edge_count",
}
ADDRESS_KEYS = {"index", "source_offset", "output_offset"}
REGION_KEYS = {
    "region_id", "kind", "index", "source_start", "source_end", "output_start",
    "output_end", "source_raw_sha256", "output_raw_sha256",
}
NODE_MAP_KEYS = {
    "source_node_id", "source_region_id", "source_start", "source_end", "status",
    "output_node_id", "output_start", "output_end", "raw_sha256",
}
REFERENCE_MAP_KEYS = {
    "reference_id", "kind", "status", "source_offset", "output_source_offset",
    "source_target_offset", "output_target_offset",
}
CFG_RELOCATION_KEYS = {
    "source_control_flow_sha256", "graph_count", "source_node_count",
    "source_edge_count", "node_rows", "edge_rows",
}
CFG_NODE_KEYS = {
    "graph_index", "source_id", "source_offset", "status", "output_id",
    "output_offset",
}
CFG_EDGE_KEYS = {
    "graph_index", "source_from_id", "source_to_id", "kind", "status",
    "output_from_id", "output_to_id",
}
EVIDENCE_KEYS = {
    "source_reference_count", "source_cfg_graph_count", "source_cfg_node_count",
    "source_cfg_edge_count", "source_call_count", "source_trace_count",
    "source_opaque_node_count", "moved_opaque_node_count", "calls_sha256",
    "traces_sha256", "control_flow_sha256",
}
BLOCKER_KEYS = {"code", "source_id", "source_offset", "target_offset", "detail"}

COMPATIBILITY = {
    "policy": "planning_only_exact_typed_control_body_edit",
    "input_editable_schema": editable_ir.EDITABLE_IR_SCHEMA,
    "input_decompiler_schema": decompiler.DECOMPILER_IR_SCHEMA,
    "supported_operations": ["insert_typed_body_copy", "remove_typed_body"],
    "body_policy": "one_contiguous_strict_typed_span_inside_one_entry",
    "insert_policy": "copy_source_span_preceding_exact_typed_anchor",
    "remove_policy": "delete_span_strictly_inside_one_entry",
    "reference_policy": "all_affected_coordinates_and_encoded_targets_planned",
    "call_resume_policy": "v1_requires_empty_call_and_trace_evidence",
    "opaque_policy": "v1_rejects_any_shifted_opaque_boundary",
    "cfg_policy": "all_affected_graph_node_and_edge_ids_planned",
    "binary_publication": "forbidden",
    "native_engine_compatibility": "unverified",
    "unknown_plan_schema": "reject",
    "unknown_v1_field": "reject",
}
INVARIANTS = {
    "source_editable_ir_validated": True,
    "body_contiguous_strict_typed_and_hash_bound": True,
    "body_region_and_entry_boundary_exact": True,
    "address_table_exhaustively_planned": True,
    "source_map_exhaustively_planned": True,
    "reference_coordinates_exhaustively_planned": True,
    "encoded_control_targets_exhaustively_planned": True,
    "cfg_coordinates_exhaustively_planned": True,
    "call_resume_and_trace_evidence_inventoried": True,
    "opaque_boundaries_inventoried": True,
    "binary_not_published": True,
}


class ControlBodyEditPlanError(ValueError):
    pass


def plan(editable_document: dict[str, Any], operation: dict[str, Any]) -> dict[str, Any]:
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
        raise ControlBodyEditPlanError("MES control-body edit plan schema or fields changed")
    if document.get("producer") != {
        "implementation": "python_phase6_control_body_edit_planner",
        "contract": PLAN_SCHEMA,
    }:
        raise ControlBodyEditPlanError("MES control-body edit producer changed")
    if document.get("compatibility") != COMPATIBILITY:
        raise ControlBodyEditPlanError("MES control-body edit compatibility changed")
    retained = document.get("payload_sha256")
    if not _is_sha256(retained) or fingerprint(document) != retained:
        raise ControlBodyEditPlanError("MES control-body edit fingerprint changed")
    operation = document.get("operation")
    if not isinstance(operation, dict):
        raise ControlBodyEditPlanError("MES control-body edit operation is missing")
    expected_operation_keys = (
        INSERT_OPERATION_KEYS
        if operation.get("kind") == "insert_typed_body_copy"
        else REMOVE_OPERATION_KEYS
    )
    if set(operation) != expected_operation_keys:
        raise ControlBodyEditPlanError("MES control-body edit operation fields changed")
    _require_dict_keys(document, "body", BODY_KEYS)
    _require_dict_keys(document, "relocation", RELOCATION_KEYS)
    _require_dict_keys(document, "cfg_relocation", CFG_RELOCATION_KEYS)
    _require_dict_keys(document, "evidence_inventory", EVIDENCE_KEYS)
    _require_rows(document, "address_table_updates", ADDRESS_KEYS)
    _require_rows(document, "region_updates", REGION_KEYS)
    _require_rows(document, "node_map", NODE_MAP_KEYS)
    _require_rows(document, "reference_map", REFERENCE_MAP_KEYS)
    _require_rows(document["body"], "inserted_node_map", INSERTED_NODE_KEYS)
    _require_rows(document["cfg_relocation"], "node_rows", CFG_NODE_KEYS)
    _require_rows(document["cfg_relocation"], "edge_rows", CFG_EDGE_KEYS)
    _require_rows(document, "blockers", BLOCKER_KEYS)
    patches = document.get("target_patches")
    if not isinstance(patches, list) or any(
        not isinstance(row, dict) or set(row) != target_relocation.PATCH_KEYS
        for row in patches
    ):
        raise ControlBodyEditPlanError("MES control-body target patch fields changed")
    target_relocation._validate_patch_rows(patches)
    if document.get("assembly_ready") is not (len(document["blockers"]) == 0):
        raise ControlBodyEditPlanError("MES control-body readiness changed")
    if document.get("invariants") != INVARIANTS:
        raise ControlBodyEditPlanError("MES control-body invariants changed")
    if editable_document is not None:
        expected = _build_plan(editable_document, copy.deepcopy(operation))
        expected["payload_sha256"] = fingerprint(expected)
        if expected != document:
            raise ControlBodyEditPlanError("MES control-body plan differs from its source")
    return {"ok": True, "schema": PLAN_SCHEMA, "payload_sha256": retained}


def _build_plan(
    editable_document: dict[str, Any], raw_operation: dict[str, Any]
) -> dict[str, Any]:
    editable_ir.validate(editable_document)
    operation = _validate_operation(raw_operation)
    source_ir = editable_document["source_ir"]
    source_container = decompiler.reconstruct_container(source_ir)
    reopened = noop_compiler.reopen_container(source_container)
    code_offset = int(source_ir["container"]["code_offset"])
    source_code = source_container[code_offset:]
    nodes = list(source_ir["nodes"])
    references = list(source_ir["references"])
    regions = list(source_ir["regions"])
    entry_regions = [row for row in regions if row.get("kind") == "entry"]
    entry_regions.sort(key=lambda row: int(row["index"]))
    if [int(row["source_start"]) for row in entry_regions] != reopened["entry_offsets"]:
        raise ControlBodyEditPlanError("MES control-body address table disagrees with regions")

    if operation["kind"] == "insert_typed_body_copy":
        anchor = _unique_typed_node(nodes, operation["anchor_offset"], "insert anchor")
        if anchor["source"]["raw_sha256"] != operation["anchor_instruction_raw_sha256"]:
            raise ControlBodyEditPlanError("MES control-body insert anchor hash is stale")
        start, end = operation["donor_start"], operation["donor_end"]
        if end > operation["anchor_offset"]:
            raise ControlBodyEditPlanError("MES control-body donor must precede the insert anchor")
        body_nodes = _strict_span(nodes, start, end)
        pivot = operation["anchor_offset"]
        delta = end - start
        body_policy = "copied_before_anchor"
        output_start, output_end = pivot, pivot + delta
        output_code = source_code[:pivot] + source_code[start:end] + source_code[pivot:]
        threshold = pivot
    else:
        start, end = operation["body_start"], operation["body_end"]
        body_nodes = _strict_span(nodes, start, end)
        pivot = end
        delta = start - end
        body_policy = "removed_from_source"
        output_start = output_end = start
        output_code = source_code[:start] + source_code[end:]
        threshold = end

    source_raw = source_code[start:end]
    expected_hash = (
        operation["donor_span_raw_sha256"]
        if operation["kind"] == "insert_typed_body_copy"
        else operation["body_span_raw_sha256"]
    )
    if hashlib.sha256(source_raw).hexdigest() != expected_hash:
        raise ControlBodyEditPlanError("MES control-body source span hash is stale")
    region_id = str(body_nodes[0]["source"]["region"])
    owner_entries = [
        row for row in entry_regions
        if row["id"] == region_id
        and int(row["source_start"]) < start < end < int(row["source_end"])
    ]
    if len(owner_entries) != 1:
        raise ControlBodyEditPlanError(
            "MES control-body span must be strictly inside one address-table entry"
        )
    if operation["kind"] == "insert_typed_body_copy":
        anchor_region = str(_unique_typed_node(nodes, pivot, "insert anchor")["source"]["region"])
        if anchor_region != region_id:
            raise ControlBodyEditPlanError("MES control-body donor and anchor must share one entry")

    blockers: list[dict[str, Any]] = []
    body_node_ids = {str(row["id"]) for row in body_nodes}
    for node in body_nodes:
        node_start = int(node["source"]["start"])
        if node.get("reference_ids"):
            blockers.append(_blocker("body_owns_references", str(node["id"]), node_start))
        if node.get("cfg_nodes"):
            blockers.append(_blocker("body_owns_cfg_nodes", str(node["id"]), node_start))
        if node.get("statement", {}).get("op") == "command_10":
            blockers.append(_blocker("body_contains_implicit_definition_target", str(node["id"]), node_start))

    calls = source_ir["analysis_evidence"]["calls"]
    traces = source_ir["analysis_evidence"]["traces"]
    if calls:
        blockers.append(_blocker("call_resume_evidence_not_supported", "calls", -1, detail=str(len(calls))))
    if traces:
        blockers.append(_blocker("trace_evidence_not_supported", "traces", -1, detail=str(len(traces))))

    moved_opaque = 0
    for node in nodes:
        node_start = int(node["source"]["start"])
        if node.get("kind") == "opaque" and node_start >= threshold:
            moved_opaque += 1
            blockers.append(_blocker("opaque_boundary_would_shift", str(node["id"]), node_start))

    address_updates = [
        {"index": int(row["index"]), "source_offset": int(row["source_start"]),
         "output_offset": int(row["source_start"]) + delta}
        for row in entry_regions if int(row["source_start"]) >= threshold
    ]
    node_map = _node_map(nodes, operation["kind"], start, end, threshold, delta)
    reference_map, reference_blockers = _reference_map(
        references, operation["kind"], start, end, threshold, delta
    )
    blockers.extend(reference_blockers)

    target_patches: list[dict[str, Any]] = []
    references_by_id = {str(row["id"]): row for row in references}
    for row in reference_map:
        if (
            row["kind"] != "code"
            or row["status"] != "retained"
            or row["source_target_offset"] == row["output_target_offset"]
        ):
            continue
        reference = references_by_id[row["reference_id"]]
        value = reference.get("value", {})
        reference_kind = str(value.get("kind", ""))
        if reference_kind == "condition_true_fallthrough":
            continue
        patch = target_relocation._resolve_target_patch(
            {
                "source_offset": int(value.get("source_offset", -1)),
                "target_offset": row["source_target_offset"],
                "output_target_offset": row["output_target_offset"],
            },
            reference,
            nodes,
            threshold,
            delta,
        )
        if patch is None:
            blockers.append(_blocker(
                "encoded_control_target_unresolved", row["reference_id"],
                row["source_offset"], row["source_target_offset"], reference_kind,
            ))
        else:
            target_patches.append(patch)

    definition_patches, definition_blockers = target_relocation._collect_definition_skip_patches(
        nodes, threshold, delta
    )
    target_patches.extend(definition_patches)
    for row in definition_blockers:
        blockers.append(_blocker(
            str(row.get("code", "definition_skip_target_unresolved")),
            str(row.get("node_id", "")), int(row.get("source_offset", -1)),
            int(row.get("target_offset", -1)),
        ))
    target_patches.sort(key=lambda row: (int(row["output_operand_start"]), str(row["reference_id"])))
    target_relocation._validate_patch_rows(target_patches)

    cfg_relocation, cfg_blockers = _cfg_relocation(
        source_ir["analysis_evidence"]["control_flow"], operation["kind"],
        start, end, threshold, delta,
    )
    blockers.extend(cfg_blockers)
    region_updates = _region_updates(regions, source_code, output_code, threshold, delta)
    blockers.sort(key=lambda row: (
        int(row["source_offset"]), str(row["code"]), str(row["source_id"])
    ))

    inserted_node_map = []
    if operation["kind"] == "insert_typed_body_copy":
        for node in body_nodes:
            relative_start = int(node["source"]["start"]) - start
            relative_end = int(node["source"]["end"]) - start
            inserted_node_map.append({
                "source_node_id": str(node["id"]),
                "source_start": int(node["source"]["start"]),
                "source_end": int(node["source"]["end"]),
                "output_node_id": _linear_id(output_start + relative_start),
                "output_start": output_start + relative_start,
                "output_end": output_start + relative_end,
                "raw_sha256": str(node["source"]["raw_sha256"]),
            })

    control_flow = source_ir["analysis_evidence"]["control_flow"]
    inventory = {
        "source_reference_count": len(references),
        "source_cfg_graph_count": len(control_flow),
        "source_cfg_node_count": sum(len(row.get("nodes", [])) for row in control_flow),
        "source_cfg_edge_count": sum(len(row.get("edges", [])) for row in control_flow),
        "source_call_count": len(calls),
        "source_trace_count": len(traces),
        "source_opaque_node_count": int(source_ir["coverage"]["opaque_node_count"]),
        "moved_opaque_node_count": moved_opaque,
        "calls_sha256": _json_sha256(calls),
        "traces_sha256": _json_sha256(traces),
        "control_flow_sha256": _json_sha256(control_flow),
    }
    return {
        "ok": True,
        "schema": PLAN_SCHEMA,
        "producer": {
            "implementation": "python_phase6_control_body_edit_planner",
            "contract": PLAN_SCHEMA,
        },
        "compatibility": copy.deepcopy(COMPATIBILITY),
        "source_identity": copy.deepcopy(source_ir["source_identity"]),
        "inputs": {
            "editable_ir_sha256": editable_document["payload_sha256"],
            "decompiler_ir_sha256": source_ir["payload_sha256"],
        },
        "operation": copy.deepcopy(operation),
        "body": {
            "policy": body_policy,
            "source_region_id": region_id,
            "source_start": start,
            "source_end": end,
            "byte_length": len(source_raw),
            "source_raw_hex": source_raw.hex(),
            "source_raw_sha256": hashlib.sha256(source_raw).hexdigest(),
            "source_node_ids": [str(row["id"]) for row in body_nodes],
            "source_node_hashes": [str(row["source"]["raw_sha256"]) for row in body_nodes],
            "output_start": output_start,
            "output_end": output_end,
            "output_raw_sha256": hashlib.sha256(output_code[output_start:output_end]).hexdigest(),
            "inserted_node_map": inserted_node_map,
        },
        "relocation": {
            "delta": delta,
            "pivot": threshold,
            "source_code_size": len(source_code),
            "output_code_size": len(output_code),
            "entry_count": len(entry_regions),
            "affected_address_count": len(address_updates),
            "affected_region_count": len(region_updates),
            "affected_node_count": len(node_map),
            "affected_reference_count": len(reference_map),
            "target_patch_count": len(target_patches),
            "cfg_node_count": len(cfg_relocation["node_rows"]),
            "cfg_edge_count": len(cfg_relocation["edge_rows"]),
        },
        "address_table_updates": address_updates,
        "region_updates": region_updates,
        "node_map": node_map,
        "reference_map": reference_map,
        "target_patches": target_patches,
        "cfg_relocation": cfg_relocation,
        "evidence_inventory": inventory,
        "blockers": blockers,
        "assembly_ready": len(blockers) == 0,
        "invariants": copy.deepcopy(INVARIANTS),
    }


def _validate_operation(raw: dict[str, Any]) -> dict[str, Any]:
    if not isinstance(raw, dict):
        raise ControlBodyEditPlanError("MES control-body operation is not an object")
    kind = raw.get("kind")
    expected = INSERT_OPERATION_KEYS if kind == "insert_typed_body_copy" else REMOVE_OPERATION_KEYS
    if kind not in COMPATIBILITY["supported_operations"] or set(raw) != expected:
        raise ControlBodyEditPlanError("unsupported MES control-body operation or fields")
    numeric = ("anchor_offset", "donor_start", "donor_end") if kind == "insert_typed_body_copy" else ("body_start", "body_end")
    if any(not _is_nonnegative_int(raw.get(key)) for key in numeric):
        raise ControlBodyEditPlanError("MES control-body operation coordinate is invalid")
    start = int(raw["donor_start"] if kind == "insert_typed_body_copy" else raw["body_start"])
    end = int(raw["donor_end"] if kind == "insert_typed_body_copy" else raw["body_end"])
    if end <= start:
        raise ControlBodyEditPlanError("MES control-body span is empty")
    hash_keys = ("anchor_instruction_raw_sha256", "donor_span_raw_sha256") if kind == "insert_typed_body_copy" else ("body_span_raw_sha256",)
    if any(not _is_sha256(raw.get(key)) for key in hash_keys):
        raise ControlBodyEditPlanError("MES control-body operation hash is invalid")
    return copy.deepcopy(raw)


def _strict_span(nodes: list[dict[str, Any]], start: int, end: int) -> list[dict[str, Any]]:
    selected = [row for row in nodes if start <= int(row["source"]["start"]) < end]
    selected.sort(key=lambda row: int(row["source"]["start"]))
    cursor = start
    regions: set[str] = set()
    for row in selected:
        source = row.get("source", {})
        row_start, row_end = int(source.get("start", -1)), int(source.get("end", -1))
        if (
            row.get("kind") != "statement"
            or row.get("evidence_status") != decompiler.TYPED_EVIDENCE_STATUS
            or row_start != cursor
            or row_end <= row_start
        ):
            raise ControlBodyEditPlanError("MES control-body span is not contiguous strict typed IR")
        cursor = row_end
        regions.add(str(source.get("region", "")))
    if not selected or cursor != end or len(regions) != 1:
        raise ControlBodyEditPlanError("MES control-body span boundary or region changed")
    return selected


def _unique_typed_node(nodes: list[dict[str, Any]], offset: int, label: str) -> dict[str, Any]:
    matches = [
        row for row in nodes
        if int(row.get("source", {}).get("start", -1)) == offset
        and row.get("kind") == "statement"
        and row.get("evidence_status") == decompiler.TYPED_EVIDENCE_STATUS
    ]
    if len(matches) != 1:
        raise ControlBodyEditPlanError(f"MES control-body {label} is not one typed instruction")
    return matches[0]


def _node_map(
    nodes: list[dict[str, Any]], kind: str, start: int, end: int,
    threshold: int, delta: int,
) -> list[dict[str, Any]]:
    rows = []
    for node in nodes:
        source = node["source"]
        source_start, source_end = int(source["start"]), int(source["end"])
        removed = kind == "remove_typed_body" and start <= source_start < end
        affected = removed or source_start >= threshold
        if not affected:
            continue
        output_start = -1 if removed else source_start + delta
        output_end = -1 if removed else source_end + delta
        rows.append({
            "source_node_id": str(node["id"]),
            "source_region_id": str(source["region"]),
            "source_start": source_start,
            "source_end": source_end,
            "status": "removed" if removed else "retained",
            "output_node_id": "" if removed else _linear_id(output_start),
            "output_start": output_start,
            "output_end": output_end,
            "raw_sha256": str(source["raw_sha256"]),
        })
    return rows


def _reference_map(
    references: list[dict[str, Any]], kind: str, start: int, end: int,
    threshold: int, delta: int,
) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    rows: list[dict[str, Any]] = []
    blockers: list[dict[str, Any]] = []
    for reference in references:
        source_offset = int(reference["source_offset"])
        removed_source = kind == "remove_typed_body" and start <= source_offset < end
        output_source = -1 if removed_source else source_offset + (delta if source_offset >= threshold else 0)
        source_target = -1
        output_target = -1
        if reference["kind"] == "code":
            source_target = int(reference["value"]["target_offset"])
            removed_target = kind == "remove_typed_body" and start <= source_target < end
            output_target = -1 if removed_target else source_target + (delta if source_target >= threshold else 0)
            if kind == "insert_typed_body_copy" and source_target == threshold:
                blockers.append(_blocker(
                    "incoming_target_at_insert_anchor", str(reference["id"]),
                    source_offset, source_target,
                ))
            if removed_target:
                blockers.append(_blocker(
                    "code_target_enters_removed_body", str(reference["id"]),
                    source_offset, source_target,
                ))
        if removed_source:
            blockers.append(_blocker(
                "reference_source_inside_removed_body", str(reference["id"]), source_offset,
            ))
        changed = removed_source or output_source != source_offset or output_target != source_target
        if changed:
            rows.append({
                "reference_id": str(reference["id"]),
                "kind": str(reference["kind"]),
                "status": "removed" if removed_source else "retained",
                "source_offset": source_offset,
                "output_source_offset": output_source,
                "source_target_offset": source_target,
                "output_target_offset": output_target,
            })
    rows.sort(key=lambda row: (int(row["source_offset"]), str(row["kind"]), str(row["reference_id"])))
    return rows, blockers


def _region_updates(
    regions: list[dict[str, Any]], source_code: bytes, output_code: bytes,
    threshold: int, delta: int,
) -> list[dict[str, Any]]:
    rows = []
    for region in regions:
        source_start, source_end = int(region["source_start"]), int(region["source_end"])
        output_start = source_start + (delta if source_start >= threshold else 0)
        output_end = source_end + (delta if source_end >= threshold else 0)
        source_hash = hashlib.sha256(source_code[source_start:source_end]).hexdigest()
        output_hash = hashlib.sha256(output_code[output_start:output_end]).hexdigest()
        if output_start != source_start or output_end != source_end or output_hash != source_hash:
            rows.append({
                "region_id": str(region["id"]),
                "kind": str(region["kind"]),
                "index": -1 if region.get("index") is None else int(region["index"]),
                "source_start": source_start,
                "source_end": source_end,
                "output_start": output_start,
                "output_end": output_end,
                "source_raw_sha256": source_hash,
                "output_raw_sha256": output_hash,
            })
    return rows


def _cfg_relocation(
    graphs: list[dict[str, Any]], kind: str, start: int, end: int,
    threshold: int, delta: int,
) -> tuple[dict[str, Any], list[dict[str, Any]]]:
    node_rows: list[dict[str, Any]] = []
    edge_rows: list[dict[str, Any]] = []
    blockers: list[dict[str, Any]] = []
    for graph_index, graph in enumerate(graphs):
        id_map: dict[str, str] = {}
        removed_ids: set[str] = set()
        for node in graph.get("nodes", []):
            source_id = str(node["id"])
            source_offset = int(node["offset"])
            removed = kind == "remove_typed_body" and start <= source_offset < end
            output_offset = -1 if removed else source_offset + (delta if source_offset >= threshold else 0)
            output_id = "" if removed else _cfg_id(output_offset)
            id_map[source_id] = output_id
            if removed:
                removed_ids.add(source_id)
            if kind == "insert_typed_body_copy" and source_offset == threshold:
                blockers.append(_blocker(
                    "cfg_node_at_insert_anchor", source_id, source_offset,
                ))
            if removed or output_offset != source_offset:
                node_rows.append({
                    "graph_index": graph_index,
                    "source_id": source_id,
                    "source_offset": source_offset,
                    "status": "removed" if removed else "retained",
                    "output_id": output_id,
                    "output_offset": output_offset,
                })
        for edge in graph.get("edges", []):
            source_from, source_to = str(edge["from_id"]), str(edge["to_id"])
            output_from = id_map.get(source_from, source_from)
            output_to = id_map.get(source_to, source_to)
            removed = source_from in removed_ids or source_to in removed_ids
            if removed:
                blockers.append(_blocker(
                    "cfg_edge_touches_removed_body", f"{source_from}->{source_to}", -1,
                ))
            if removed or output_from != source_from or output_to != source_to:
                edge_rows.append({
                    "graph_index": graph_index,
                    "source_from_id": source_from,
                    "source_to_id": source_to,
                    "kind": str(edge["kind"]),
                    "status": "removed" if removed else "retained",
                    "output_from_id": "" if removed else output_from,
                    "output_to_id": "" if removed else output_to,
                })
    result = {
        "source_control_flow_sha256": _json_sha256(graphs),
        "graph_count": len(graphs),
        "source_node_count": sum(len(row.get("nodes", [])) for row in graphs),
        "source_edge_count": sum(len(row.get("edges", [])) for row in graphs),
        "node_rows": node_rows,
        "edge_rows": edge_rows,
    }
    return result, blockers


def _blocker(
    code: str, source_id: str, source_offset: int,
    target_offset: int = -1, detail: str = "",
) -> dict[str, Any]:
    return {
        "code": code,
        "source_id": source_id,
        "source_offset": source_offset,
        "target_offset": target_offset,
        "detail": detail,
    }


def _json_sha256(value: Any) -> str:
    return hashlib.sha256(json.dumps(
        value, ensure_ascii=False, allow_nan=False, sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")).hexdigest()


def _linear_id(offset: int) -> str:
    return f"linear_{offset:08x}"


def _cfg_id(offset: int) -> str:
    return f"instruction_{offset:08x}"


def _require_dict_keys(document: dict[str, Any], key: str, expected: set[str]) -> None:
    value = document.get(key)
    if not isinstance(value, dict) or set(value) != expected:
        raise ControlBodyEditPlanError(f"MES control-body {key} fields changed")


def _require_rows(document: dict[str, Any], key: str, expected: set[str]) -> None:
    value = document.get(key)
    if not isinstance(value, list) or any(
        not isinstance(row, dict) or set(row) != expected for row in value
    ):
        raise ControlBodyEditPlanError(f"MES control-body {key} fields changed")


def _is_nonnegative_int(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value >= 0


def main() -> None:
    parser = argparse.ArgumentParser(
        description=(
            "Build a fail-closed JSON plan for one exact typed MES control-body "
            "copy insertion or removal. This tool never publishes MES bytes."
        )
    )
    parser.add_argument("editable_ir", type=Path)
    parser.add_argument("operation", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    if len({args.editable_ir.resolve(), args.operation.resolve(), args.output.resolve()}) != 3:
        raise ControlBodyEditPlanError("MES control-body input and output paths must differ")
    try:
        editable_document = json.loads(args.editable_ir.read_text(encoding="utf-8"))
        operation = json.loads(args.operation.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise ControlBodyEditPlanError("MES control-body input JSON could not be read") from error
    if not isinstance(editable_document, dict) or not isinstance(operation, dict):
        raise ControlBodyEditPlanError("MES control-body inputs must be JSON objects")
    document = plan(editable_document, operation)
    editable_ir.publish_new(args.output, editable_ir.canonical_json_bytes(document) + b"\n")
    print(
        "MES_CONTROL_BODY_EDIT_PLAN_PASS "
        f"schema={document['schema']} "
        f"entry={document['source_identity'].get('entry', '')} "
        f"kind={document['operation']['kind']} "
        f"delta={document['relocation']['delta']} "
        f"patches={len(document['target_patches'])} "
        f"blockers={len(document['blockers'])} "
        f"assembly_ready={str(document['assembly_ready']).lower()} "
        f"payload_sha256={document['payload_sha256']}"
    )


if __name__ == "__main__":
    main()
