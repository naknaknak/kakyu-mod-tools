from __future__ import annotations

import argparse
import copy
import hashlib
import json
from pathlib import Path
from typing import Any

import decompile_mes_handoff as decompiler
import emit_mes_low_level_control as low_control
import prove_mes_control_flow as flow_proof
import prove_mes_shared_call_returns as call_proof
from payload_values import canonical_payload_bytes, fingerprint


EXECUTION_FALLTHROUGH_PROOF_SCHEMA = "kakyu_mes_execution_fallthrough_proof/v2"
NON_FALLTHROUGH_COMMAND_IDS = {
    0x00,
    0x0B,
    0x0C,
    0x10,
    0x11,
    0x14,
    0x18,
    0x1D,
}


class ExecutionFallthroughProofError(ValueError):
    pass


def prove(
    linear_ir: dict[str, Any],
    transfer_proof: dict[str, Any],
    shared_calls: dict[str, Any],
    library_audit: dict[str, Any],
) -> dict[str, Any]:
    _validate_inputs(linear_ir, transfer_proof, shared_calls, library_audit)
    document = _build(linear_ir, transfer_proof, shared_calls)
    document["payload_sha256"] = fingerprint(document)
    validate(document, linear_ir, transfer_proof, shared_calls, library_audit)
    return document


def validate(
    document: dict[str, Any],
    linear_ir: dict[str, Any],
    transfer_proof: dict[str, Any],
    shared_calls: dict[str, Any],
    library_audit: dict[str, Any],
) -> dict[str, Any]:
    if document.get("schema") != EXECUTION_FALLTHROUGH_PROOF_SCHEMA:
        raise ExecutionFallthroughProofError(
            "unsupported execution-fallthrough proof schema"
        )
    retained = document.get("payload_sha256")
    if (
        not isinstance(retained, str)
        or len(retained) != 64
        or fingerprint(document) != retained
    ):
        raise ExecutionFallthroughProofError(
            "execution-fallthrough proof fingerprint changed"
        )
    _validate_inputs(linear_ir, transfer_proof, shared_calls, library_audit)
    expected = _build(linear_ir, transfer_proof, shared_calls)
    actual = dict(document)
    actual.pop("payload_sha256", None)
    if actual != expected:
        raise ExecutionFallthroughProofError(
            "execution-fallthrough projection changed"
        )
    return {
        "ok": True,
        "schema": EXECUTION_FALLTHROUGH_PROOF_SCHEMA,
        "payload_sha256": retained,
    }


def _validate_inputs(
    linear_ir: dict[str, Any],
    transfer_proof: dict[str, Any],
    shared_calls: dict[str, Any],
    library_audit: dict[str, Any],
) -> None:
    decompiler.validate(linear_ir)
    flow_proof.validate(transfer_proof)
    if transfer_proof["input_decompiler"]["payload_sha256"] != linear_ir["payload_sha256"]:
        raise ExecutionFallthroughProofError(
            "flow proof belongs to another linear IR"
        )
    call_proof.validate(shared_calls, linear_ir, library_audit)


def _build(
    linear_ir: dict[str, Any],
    transfer_proof: dict[str, Any],
    shared_calls: dict[str, Any],
) -> dict[str, Any]:
    control = low_control.emit(transfer_proof)
    call_by_node = {
        str(row["call_node_id"]): row for row in shared_calls["proved_calls"]
    }
    graph_results = [
        _prove_graph(linear_ir, graph, call_by_node)
        for graph in control["graphs"]
    ]
    call_return_edges, rejected_call_return_edges = _prove_call_return_edges(
        linear_ir, shared_calls
    )
    return {
        "ok": True,
        "schema": EXECUTION_FALLTHROUGH_PROOF_SCHEMA,
        "producer": {
            "implementation": "python_phase5_execution_fallthrough_prover",
            "contract": EXECUTION_FALLTHROUGH_PROOF_SCHEMA,
        },
        "compatibility": {
            "policy": "exact_linear_flow_and_shared_call_proof_match",
            "input_decompiler_schema": decompiler.DECOMPILER_IR_SCHEMA,
            "input_flow_proof_schema": flow_proof.CONTROL_FLOW_PROOF_SCHEMA,
            "input_shared_call_schema": call_proof.SHARED_CALL_RETURN_PROOF_SCHEMA,
            "unknown_v2_field": "ignore",
            "promotion_policy": "exact_anchor_span_with_native_payload_mask_and_proved_shared_call_return",
            "unproved_span_policy": "retain_disconnected_low_level_anchors",
            "call_return_edge_policy": "exact_literal_call_node_to_same_region_physical_resume_node",
            "unproved_call_edge_policy": "retain_numeric_linear_fallback_and_rejection_reason",
        },
        "inputs": {
            "linear_ir_sha256": linear_ir["payload_sha256"],
            "flow_proof_sha256": transfer_proof["payload_sha256"],
            "fallback_control_sha256": control["payload_sha256"],
            "shared_call_return_sha256": shared_calls["payload_sha256"],
            "library_audit_sha256": shared_calls["inputs"]["library_audit_sha256"],
        },
        "source_identity": copy.deepcopy(linear_ir.get("source_identity", {})),
        "graphs": graph_results,
        "call_return_edges": call_return_edges,
        "rejected_call_return_edges": rejected_call_return_edges,
        "coverage": {
            "graph_count": len(graph_results),
            "anchor_candidate_count": sum(
                len(row["proved_fallthroughs"]) + len(row["rejected_anchors"])
                for row in graph_results
            ),
            "proved_fallthrough_count": sum(
                len(row["proved_fallthroughs"]) for row in graph_results
            ),
            "rejected_anchor_count": sum(
                len(row["rejected_anchors"]) for row in graph_results
            ),
            "native_stream_span_count": sum(
                sum(
                    1
                    for proof in row["proved_fallthroughs"]
                    for segment in proof["segments"]
                    if segment["kind"] == "native_stream_payload"
                )
                for row in graph_results
            ),
            "shared_call_return_segment_count": sum(
                sum(
                    1
                    for proof in row["proved_fallthroughs"]
                    for segment in proof["segments"]
                    if segment["kind"] == "shared_call_return"
                )
                for row in graph_results
            ),
            "call_return_edge_candidate_count": (
                len(call_return_edges) + len(rejected_call_return_edges)
            ),
            "proved_call_return_edge_count": len(call_return_edges),
            "rejected_call_return_edge_count": len(rejected_call_return_edges),
        },
    }


def _prove_call_return_edges(
    linear_ir: dict[str, Any],
    shared_calls: dict[str, Any],
) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    node_by_id = {str(node["id"]): node for node in linear_ir["nodes"]}
    node_by_coordinate: dict[tuple[str, int], dict[str, Any]] = {}
    duplicate_coordinates: set[tuple[str, int]] = set()
    for node in linear_ir["nodes"]:
        coordinate = (
            str(node["source"]["region"]),
            int(node["source"]["start"]),
        )
        if coordinate in node_by_coordinate:
            duplicate_coordinates.add(coordinate)
        else:
            node_by_coordinate[coordinate] = node

    proved: list[dict[str, Any]] = []
    rejected: list[dict[str, Any]] = []
    calls = [
        (True, row) for row in shared_calls["proved_calls"]
    ] + [
        (False, row) for row in shared_calls["unresolved_calls"]
    ]
    calls.sort(
        key=lambda item: (
            int(item[1]["call_start"]),
            int(item[1]["call_end"]),
            str(item[1]["caller_region"]),
            str(item[1]["call_node_id"]),
            not item[0],
        )
    )
    for certified, call in calls:
        base = {
            "call_node_id": str(call["call_node_id"]),
            "caller_region": str(call["caller_region"]),
            "call_start": int(call["call_start"]),
            "call_end": int(call["call_end"]),
        }
        if not certified:
            rejected.append(
                {
                    **base,
                    "routine_id": call.get("routine_id"),
                    "reason": str(call["reason"]),
                    "fallback_linear_node_id": str(call["fallback_linear_node_id"]),
                }
            )
            continue
        source = node_by_id.get(base["call_node_id"])
        if source is None:
            rejected.append({**base, "reason": "certified_call_node_is_missing"})
            continue
        source_statement = source.get("statement", {})
        if (
            source.get("kind") != "statement"
            or source_statement.get("op") != "script_transfer"
            or int(source_statement.get("command_id", -1)) != 0x1D
            or str(source["source"]["region"]) != base["caller_region"]
            or int(source["source"]["start"]) != base["call_start"]
            or int(source["source"]["end"]) != base["call_end"]
            or int(call["physical_resume_offset"]) != base["call_end"]
        ):
            rejected.append(
                {**base, "reason": "certified_call_node_or_resume_shape_changed"}
            )
            continue
        target_coordinate = (base["caller_region"], base["call_end"])
        if target_coordinate in duplicate_coordinates:
            rejected.append(
                {**base, "reason": "physical_resume_coordinate_is_ambiguous"}
            )
            continue
        target = node_by_coordinate.get(target_coordinate)
        if target is None:
            rejected.append(
                {**base, "reason": "physical_resume_has_no_linear_ir_node"}
            )
            continue
        proved.append(
            {
                "id": f"call_return_edge_{len(proved):04d}_{base['call_start']:08x}",
                **base,
                "routine_id": int(call["routine_id"]),
                "target_node_id": str(target["id"]),
                "target_kind": str(target["kind"]),
                "physical_resume_offset": base["call_end"],
                "edge_kind": "shared_call_returns_to_physical_resume",
                "proof_status": "source_bound_callee_total_return_and_exact_same_region_resume_node",
                "fallback_linear_node_id": str(call["fallback_linear_node_id"]),
            }
        )
    return proved, rejected


def _prove_graph(
    linear_ir: dict[str, Any],
    control_graph: dict[str, Any],
    call_by_node: dict[str, dict[str, Any]],
) -> dict[str, Any]:
    labels = sorted(
        control_graph["labels"],
        key=lambda row: (int(row["offset"]), str(row["id"])),
    )
    label_by_id = {str(row["id"]): row for row in labels}
    by_region: dict[str, list[dict[str, Any]]] = {}
    for label in labels:
        by_region.setdefault(str(label["region"]), []).append(label)
    proved: list[dict[str, Any]] = []
    rejected: list[dict[str, Any]] = []
    for statement in control_graph["statements"]:
        if statement["kind"] != "anchor":
            continue
        source_label = label_by_id[str(statement["label"])]
        target_label = _next_label(source_label, by_region)
        if target_label is None:
            continue
        start = int(statement["source_node"]["source"]["end"])
        end = int(target_label["offset"])
        result, reason = _prove_span(
            linear_ir,
            str(source_label["region"]),
            start,
            end,
            call_by_node,
        )
        if result is None:
            rejected.append(
                {
                    "source_label": str(source_label["id"]),
                    "target_label": str(target_label["id"]),
                    "span_start": start,
                    "span_end": end,
                    "reason": reason,
                }
            )
            continue
        proved.append(
            {
                "source_label": str(source_label["id"]),
                "target_label": str(target_label["id"]),
                "source_end": start,
                "target_start": end,
                "linear_node_ids": result["linear_node_ids"],
                "segments": result["segments"],
                "proof_status": "exact_runtime_fallthrough_to_next_same_region_anchor",
            }
        )
    return {
        "graph_index": int(control_graph["graph_index"]),
        "bounded_complete": bool(control_graph["bounded_complete"]),
        "proved_fallthroughs": proved,
        "rejected_anchors": rejected,
    }


def _next_label(
    source: dict[str, Any],
    by_region: dict[str, list[dict[str, Any]]],
) -> dict[str, Any] | None:
    for label in by_region.get(str(source["region"]), []):
        if int(label["offset"]) > int(source["offset"]):
            return label
    return None


def _prove_span(
    linear_ir: dict[str, Any],
    region: str,
    start: int,
    end: int,
    call_by_node: dict[str, dict[str, Any]],
) -> tuple[dict[str, Any] | None, str]:
    if end < start:
        return None, "next_anchor_precedes_source_end"
    nodes = sorted(
        (
            node
            for node in linear_ir["nodes"]
            if str(node["source"]["region"]) == region
            and start <= int(node["source"]["start"]) < end
        ),
        key=lambda node: (
            int(node["source"]["start"]),
            int(node["source"]["end"]),
            str(node["id"]),
        ),
    )
    by_start = {int(node["source"]["start"]): node for node in nodes}
    if len(by_start) != len(nodes):
        return None, "linear_span_has_duplicate_source_start"
    cursor = start
    retained_ids: list[str] = []
    segments: list[dict[str, Any]] = []
    while cursor < end:
        node = by_start.get(cursor)
        if node is None:
            return None, "linear_span_is_incomplete"
        node_end = int(node["source"]["end"])
        if node_end <= cursor or node_end > end:
            return None, "linear_node_exceeds_anchor_span"
        if node["kind"] == "opaque":
            return None, "linear_span_contains_opaque_boundary"
        statement = node["statement"]
        metadata = statement.get("metadata", {})
        if metadata.get("native_handler_family") == "character_stream_presentation":
            native, reason = _native_stream_segment(node, nodes, end)
            if native is None:
                return None, reason
            retained_ids.extend(native["linear_node_ids"])
            segments.append(native["segment"])
            cursor = int(native["end"])
            continue
        if statement.get("op") == "script_transfer":
            call = call_by_node.get(str(node["id"]))
            if call is None:
                return None, "shared_call_return_is_not_proven"
            if (
                int(call["call_start"]) != cursor
                or int(call["call_end"]) != node_end
                or int(call["physical_resume_offset"]) != node_end
                or str(call["caller_region"]) != region
            ):
                return None, "shared_call_certificate_does_not_match_linear_node"
            retained_ids.append(str(node["id"]))
            segments.append(
                {
                    "kind": "shared_call_return",
                    "start": cursor,
                    "end": node_end,
                    "linear_node_id": str(node["id"]),
                    "routine_id": int(call["routine_id"]),
                    "callee_entry": str(call["callee_entry"]),
                    "callee_body_start": int(call["callee_body_start"]),
                    "callee_body_end": int(call["callee_body_end"]),
                    "callee_return_offsets": copy.deepcopy(
                        call["callee_return_offsets"]
                    ),
                }
            )
            cursor = node_end
            continue
        command_id = int(statement.get("command_id", -1))
        if command_id in NON_FALLTHROUGH_COMMAND_IDS:
            return None, "linear_span_contains_unproved_control_transfer"
        retained_ids.append(str(node["id"]))
        segments.append(
            {
                "kind": "linear_fallthrough",
                "start": cursor,
                "end": node_end,
                "linear_node_id": str(node["id"]),
                "op": str(statement.get("op", "")),
            }
        )
        cursor = node_end
    if cursor != end:
        return None, "linear_span_is_incomplete"
    return {"linear_node_ids": retained_ids, "segments": segments}, ""


def _native_stream_segment(
    owner: dict[str, Any],
    span_nodes: list[dict[str, Any]],
    anchor_end: int,
) -> tuple[dict[str, Any] | None, str]:
    source = owner["source"]
    statement = owner["statement"]
    probe = statement.get("metadata", {}).get("native_stream_probe")
    if not isinstance(probe, dict):
        return None, "native_stream_probe_is_missing"
    payload_start = int(source["end"])
    probe_start = int(probe.get("start_offset", -1))
    probe_end = int(probe.get("probe_end_offset", -1))
    consumed = int(probe.get("consumed_byte_count", -1))
    if (
        str(statement["metadata"].get("native_stream_consumption", ""))
        != "single_byte_run_until_nul_or_primary_double_byte_lead"
        or str(probe.get("stop_reason", "")) != "nul_consumed"
        or probe_start != payload_start
        or consumed <= 0
        or probe_end != payload_start + consumed
        or int(probe.get("stop_offset", -1)) != probe_end - 1
        or probe_end > anchor_end
    ):
        return None, "native_stream_probe_is_not_exact_nul_consumed_span"
    payload_nodes = sorted(
        (
            node
            for node in span_nodes
            if payload_start <= int(node["source"]["start"]) < probe_end
        ),
        key=lambda node: int(node["source"]["start"]),
    )
    cursor = payload_start
    raw = bytearray()
    for node in payload_nodes:
        node_start = int(node["source"]["start"])
        node_end = int(node["source"]["end"])
        if (
            node_start != cursor
            or node_end <= node_start
            or node_end > probe_end
            or node["kind"] == "opaque"
        ):
            return None, "native_stream_payload_partition_is_not_exact"
        try:
            node_raw = bytes.fromhex(str(node["source"]["raw_hex"]))
        except ValueError:
            return None, "native_stream_payload_raw_hex_is_invalid"
        if len(node_raw) != node_end - node_start:
            return None, "native_stream_payload_raw_length_changed"
        raw.extend(node_raw)
        cursor = node_end
    if cursor != probe_end or len(raw) != consumed or not raw or raw[-1] != 0:
        return None, "native_stream_payload_terminator_or_extent_changed"
    owner_start = int(source["start"])
    return {
        "end": probe_end,
        "linear_node_ids": [str(owner["id"])]
        + [str(node["id"]) for node in payload_nodes],
        "segment": {
            "kind": "native_stream_payload",
            "start": owner_start,
            "dispatch_token_end": payload_start,
            "end": probe_end,
            "owner_linear_node_id": str(owner["id"]),
            "payload_linear_node_ids": [str(node["id"]) for node in payload_nodes],
            "handler_family": "character_stream_presentation",
            "stop_reason": "nul_consumed",
            "payload_sha256": hashlib.sha256(bytes(raw)).hexdigest(),
        },
    }, ""


def main() -> None:
    parser = argparse.ArgumentParser(
        description=(
            "Prove same-region MES anchor fallthroughs across exact native payload "
            "spans and certified shared calls."
        )
    )
    parser.add_argument("linear_ir", type=Path)
    parser.add_argument("flow_proof", type=Path)
    parser.add_argument("shared_call_returns", type=Path)
    parser.add_argument("library_audit", type=Path)
    parser.add_argument("output", type=Path, nargs="?")
    args = parser.parse_args()
    linear_ir = json.loads(args.linear_ir.read_text(encoding="utf-8"))
    transfers = json.loads(args.flow_proof.read_text(encoding="utf-8"))
    shared_calls = json.loads(args.shared_call_returns.read_text(encoding="utf-8"))
    library = json.loads(args.library_audit.read_text(encoding="utf-8"))
    document = prove(linear_ir, transfers, shared_calls, library)
    encoded = json.dumps(
        document,
        ensure_ascii=False,
        allow_nan=False,
        sort_keys=True,
        separators=(",", ":"),
    )
    if args.output is not None:
        if args.output.resolve() in {
            args.linear_ir.resolve(),
            args.flow_proof.resolve(),
            args.shared_call_returns.resolve(),
            args.library_audit.resolve(),
        }:
            raise ExecutionFallthroughProofError(
                "execution-fallthrough output must not replace an input"
            )
        args.output.write_text(encoded + "\n", encoding="utf-8")
    print(
        "MES_EXECUTION_FALLTHROUGH_PROOF_PASS "
        f"schema={document['schema']} entry={document['source_identity'].get('entry', '')} "
        f"candidates={document['coverage']['anchor_candidate_count']} "
        f"proved={document['coverage']['proved_fallthrough_count']} "
        f"rejected={document['coverage']['rejected_anchor_count']} "
        f"native_spans={document['coverage']['native_stream_span_count']} "
        f"shared_returns={document['coverage']['shared_call_return_segment_count']} "
        f"call_edges={document['coverage']['proved_call_return_edge_count']} "
        f"call_edge_rejections={document['coverage']['rejected_call_return_edge_count']} "
        f"payload_sha256={document['payload_sha256']}"
    )


if __name__ == "__main__":
    main()
