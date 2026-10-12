from __future__ import annotations

import argparse
import copy
import json
from pathlib import Path
from typing import Any

import decompile_mes_handoff as decompiler
import prove_mes_control_flow as flow_proof
import prove_mes_execution_fallthroughs as execution_proof
import prove_mes_if_regions as region_proof
import prove_mes_shared_call_returns as call_proof
from payload_values import canonical_payload_bytes, fingerprint


NATURAL_LOOP_PROOF_SCHEMA = "kakyu_mes_natural_loop_proof/v2"
CONFIRMED_REFERENCE_KINDS = {
    "condition_true_fallthrough",
    "condition_false_target",
    "continuation_target",
}


class NaturalLoopProofError(ValueError):
    pass


def prove(
    linear_ir: dict[str, Any],
    transfer_proof: dict[str, Any],
    conditional_proof: dict[str, Any],
    execution_fallthroughs: dict[str, Any],
    shared_calls: dict[str, Any],
    library_audit: dict[str, Any],
) -> dict[str, Any]:
    decompiler.validate(linear_ir)
    flow_proof.validate(transfer_proof)
    region_proof.validate(conditional_proof, linear_ir, transfer_proof)
    execution_proof.validate(
        execution_fallthroughs,
        linear_ir,
        transfer_proof,
        shared_calls,
        library_audit,
    )
    document = _build(
        linear_ir, transfer_proof, conditional_proof, execution_fallthroughs
    )
    document["payload_sha256"] = fingerprint(document)
    validate(
        document,
        linear_ir,
        transfer_proof,
        conditional_proof,
        execution_fallthroughs,
        shared_calls,
        library_audit,
    )
    return document


def validate(
    document: dict[str, Any],
    linear_ir: dict[str, Any],
    transfer_proof: dict[str, Any],
    conditional_proof: dict[str, Any],
    execution_fallthroughs: dict[str, Any],
    shared_calls: dict[str, Any],
    library_audit: dict[str, Any],
) -> dict[str, Any]:
    if document.get("schema") != NATURAL_LOOP_PROOF_SCHEMA:
        raise NaturalLoopProofError("unsupported natural-loop proof schema")
    retained = document.get("payload_sha256")
    if (
        not isinstance(retained, str)
        or len(retained) != 64
        or fingerprint(document) != retained
    ):
        raise NaturalLoopProofError("natural-loop proof fingerprint changed")
    decompiler.validate(linear_ir)
    flow_proof.validate(transfer_proof)
    region_proof.validate(conditional_proof, linear_ir, transfer_proof)
    execution_proof.validate(
        execution_fallthroughs,
        linear_ir,
        transfer_proof,
        shared_calls,
        library_audit,
    )
    expected = _build(
        linear_ir, transfer_proof, conditional_proof, execution_fallthroughs
    )
    actual = dict(document)
    actual.pop("payload_sha256", None)
    if actual != expected:
        raise NaturalLoopProofError("natural-loop projection changed")
    return {
        "ok": True,
        "schema": NATURAL_LOOP_PROOF_SCHEMA,
        "payload_sha256": retained,
    }


def _build(
    linear_ir: dict[str, Any],
    transfer_proof: dict[str, Any],
    conditional_proof: dict[str, Any],
    execution_fallthroughs: dict[str, Any],
) -> dict[str, Any]:
    fallback_graphs = conditional_proof["fallback_control"]["graphs"]
    graph_results = [
        _prove_graph(
            index,
            linear_ir,
            conditional_proof["graphs"][index],
            execution_fallthroughs["graphs"][index],
            graph,
        )
        for index, graph in enumerate(fallback_graphs)
    ]
    return {
        "ok": True,
        "schema": NATURAL_LOOP_PROOF_SCHEMA,
        "producer": {
            "implementation": "python_phase5_natural_loop_prover",
            "contract": NATURAL_LOOP_PROOF_SCHEMA,
        },
        "compatibility": {
            "policy": "exact_linear_transfer_region_and_execution_proof_match",
            "input_decompiler_schema": decompiler.DECOMPILER_IR_SCHEMA,
            "input_flow_proof_schema": flow_proof.CONTROL_FLOW_PROOF_SCHEMA,
            "input_region_proof_schema": region_proof.REDUCIBLE_REGION_PROOF_SCHEMA,
            "input_execution_fallthrough_schema": execution_proof.EXECUTION_FALLTHROUGH_PROOF_SCHEMA,
            "unknown_v2_field": "ignore",
            "promotion_policy": "same_region_bounded_root_header_dominates_all_latches_single_entry",
            "surface_syntax_policy": "retain_label_goto_fallback_no_while_for_guess",
        },
        "inputs": {
            "linear_ir_sha256": linear_ir["payload_sha256"],
            "flow_proof_sha256": transfer_proof["payload_sha256"],
            "region_proof_sha256": conditional_proof["payload_sha256"],
            "execution_fallthrough_sha256": execution_fallthroughs["payload_sha256"],
            "fallback_control_sha256": conditional_proof["fallback_control"][
                "payload_sha256"
            ],
        },
        "source_identity": copy.deepcopy(linear_ir.get("source_identity", {})),
        "graphs": graph_results,
        "coverage": {
            "graph_count": len(graph_results),
            "back_edge_candidate_count": sum(
                int(row["back_edge_candidate_count"]) for row in graph_results
            ),
            "natural_loop_count": sum(
                len(row["natural_loops"]) for row in graph_results
            ),
            "proved_back_edge_count": sum(
                sum(len(loop["back_edges"]) for loop in row["natural_loops"])
                for row in graph_results
            ),
            "rejected_header_count": sum(
                len(row["rejected_headers"]) for row in graph_results
            ),
        },
    }


def _prove_graph(
    graph_index: int,
    linear_ir: dict[str, Any],
    conditional_graph: dict[str, Any],
    execution_graph: dict[str, Any],
    control_graph: dict[str, Any],
) -> dict[str, Any]:
    labels = {str(row["id"]): row for row in control_graph["labels"]}
    statements = {str(row["label"]): row for row in control_graph["statements"]}
    outgoing = _outgoing(conditional_graph, execution_graph, statements)
    predecessors = _predecessors(labels, outgoing)
    by_header: dict[str, list[str]] = {}
    for label, statement in statements.items():
        if statement["kind"] != "goto":
            continue
        target = str(statement["target_label"])
        if target not in labels:
            continue
        source_info = labels[label]
        target_info = labels[target]
        if (
            str(source_info["region"]) == str(target_info["region"])
            and int(target_info["offset"]) < int(source_info["offset"])
        ):
            by_header.setdefault(target, []).append(label)

    roots_by_region = _region_roots(linear_ir, labels)
    dominators_by_region = {
        region: _dominators(
            {
                label
                for label, info in labels.items()
                if str(info["region"]) == region
            },
            predecessors,
            roots,
        )
        for region, roots in roots_by_region.items()
    }
    loops: list[dict[str, Any]] = []
    rejected: list[dict[str, Any]] = []
    for header in sorted(by_header, key=lambda label: _label_key(labels[label])):
        latches = sorted(by_header[header], key=lambda label: _label_key(labels[label]))
        if not bool(conditional_graph.get("bounded_complete", False)):
            rejected.append(
                {
                    "header_label": header,
                    "header_offset": int(labels[header]["offset"]),
                    "latch_labels": latches,
                    "reason": "control_graph_is_not_bounded_complete",
                }
            )
            continue
        candidate, reason = _natural_loop_candidate(
            graph_index,
            linear_ir,
            header,
            latches,
            labels,
            statements,
            outgoing,
            predecessors,
            dominators_by_region.get(str(labels[header]["region"]), {}),
        )
        if candidate is None:
            rejected.append(
                {
                    "header_label": header,
                    "header_offset": int(labels[header]["offset"]),
                    "latch_labels": latches,
                    "reason": reason,
                }
            )
        else:
            candidate["id"] = f"natural_loop_{int(labels[header]['offset']):08x}"
            loops.append(candidate)
    return {
        "graph_index": graph_index,
        "bounded_complete": bool(conditional_graph.get("bounded_complete", False)),
        "back_edge_candidate_count": sum(len(rows) for rows in by_header.values()),
        "natural_loops": loops,
        "rejected_headers": rejected,
    }


def _outgoing(
    conditional_graph: dict[str, Any],
    execution_graph: dict[str, Any],
    statements: dict[str, dict[str, Any]],
) -> dict[str, list[str]]:
    fallthrough = {
        str(row["source_label"]): str(row["target_label"])
        for row in conditional_graph["proved_fallthroughs"]
    }
    for row in execution_graph["proved_fallthroughs"]:
        source = str(row["source_label"])
        target = str(row["target_label"])
        if source in fallthrough and fallthrough[source] != target:
            raise NaturalLoopProofError(
                "conditional and execution fallthrough proofs disagree"
            )
        fallthrough[source] = target
    result: dict[str, list[str]] = {}
    for label, statement in statements.items():
        kind = str(statement["kind"])
        if kind == "conditional_goto":
            result[label] = [
                str(statement["true_label"]),
                str(statement["false_label"]),
            ]
        elif kind == "goto":
            result[label] = [str(statement["target_label"])]
        elif kind == "anchor" and label in fallthrough:
            result[label] = [fallthrough[label]]
        else:
            result[label] = []
    return result


def _predecessors(
    labels: dict[str, dict[str, Any]], outgoing: dict[str, list[str]]
) -> dict[str, set[str]]:
    result = {label: set() for label in labels}
    for source, targets in outgoing.items():
        for target in targets:
            if target in result:
                result[target].add(source)
    return result


def _region_roots(
    linear_ir: dict[str, Any],
    labels: dict[str, dict[str, Any]],
) -> dict[str, set[str]]:
    regions = {str(row["region"]) for row in labels.values()}
    roots: dict[str, set[str]] = {}
    for region in regions:
        region_labels = {
            label for label, info in labels.items() if str(info["region"]) == region
        }
        region_roots: set[str] = set()
        if region_labels:
            region_roots.add(min(region_labels, key=lambda label: _label_key(labels[label])))
        roots[region] = region_roots

    for reference in linear_ir["references"]:
        value = reference.get("value", {})
        if (
            reference.get("kind") != "code"
            or value.get("kind") not in CONFIRMED_REFERENCE_KINDS
        ):
            continue
        source_offset = int(value.get("source_offset", -1))
        target_offset = int(value.get("target_offset", -1))
        source_region = _region_for_offset(linear_ir, source_offset)
        for label, info in labels.items():
            target_region = str(info["region"])
            if int(info["offset"]) == target_offset and source_region != target_region:
                roots.setdefault(target_region, set()).add(label)
    return roots


def _dominators(
    nodes: set[str],
    predecessors: dict[str, set[str]],
    roots: set[str],
) -> dict[str, set[str]]:
    if not nodes:
        return {}
    actual_roots = roots & nodes
    successors: dict[str, set[str]] = {node: set() for node in nodes}
    for target in nodes:
        for source in predecessors[target] & nodes:
            successors[source].add(target)
    reachable: set[str] = set()
    pending = list(actual_roots)
    while pending:
        node = pending.pop()
        if node in reachable:
            continue
        reachable.add(node)
        pending.extend(successors[node] - reachable)
    dominators = {
        node: ({node} if node in actual_roots else set(reachable))
        for node in reachable
    }
    changed = True
    while changed:
        changed = False
        for node in sorted(reachable):
            if node in actual_roots:
                continue
            incoming = predecessors[node] & reachable
            if not incoming:
                updated = {node}
            else:
                common = set(reachable)
                for source in incoming:
                    common &= dominators[source]
                updated = common | {node}
            if updated != dominators[node]:
                dominators[node] = updated
                changed = True
    return dominators


def _natural_loop_candidate(
    graph_index: int,
    linear_ir: dict[str, Any],
    header: str,
    latches: list[str],
    labels: dict[str, dict[str, Any]],
    statements: dict[str, dict[str, Any]],
    outgoing: dict[str, list[str]],
    predecessors: dict[str, set[str]],
    dominators: dict[str, set[str]],
) -> tuple[dict[str, Any] | None, str]:
    if not latches:
        return None, "header_has_no_backward_latch"
    reachable_labels = set(dominators)
    if header not in reachable_labels or any(
        latch not in reachable_labels for latch in latches
    ):
        return None, "candidate_component_is_not_reachable_from_bounded_control_root"
    reached_from_header = _reachable(header, outgoing)
    if any(latch not in reached_from_header for latch in latches):
        return None, "latch_is_not_reachable_from_header"
    if any(header not in dominators.get(latch, set()) for latch in latches):
        return None, "header_does_not_dominate_every_latch"
    region = str(labels[header]["region"])
    loop_nodes = {header}
    for latch in latches:
        loop_nodes.add(latch)
        pending = [latch]
        while pending:
            node = pending.pop()
            for source in predecessors[node]:
                if (
                    source not in reachable_labels
                    or str(labels[source]["region"]) != region
                    or source in loop_nodes
                ):
                    continue
                loop_nodes.add(source)
                if source != header:
                    pending.append(source)
    if any(
        target != header
        for target in loop_nodes
        for source in predecessors[target]
        if source in reachable_labels and source not in loop_nodes
    ):
        return None, "natural_loop_has_external_non_header_entry"

    loop_offsets = {int(labels[label]["offset"]) for label in loop_nodes}
    reachable_offsets = {
        int(labels[label]["offset"]) for label in reachable_labels
    }
    header_offset = int(labels[header]["offset"])
    if any(offset < header_offset for offset in loop_offsets):
        return None, "natural_loop_is_not_a_forward_lexical_envelope"
    for reference in linear_ir["references"]:
        value = reference.get("value", {})
        if (
            reference.get("kind") != "code"
            or value.get("kind") not in CONFIRMED_REFERENCE_KINDS
        ):
            continue
        target = int(value.get("target_offset", -1))
        source = int(value.get("source_offset", -1))
        if (
            target in loop_offsets
            and source in reachable_offsets
            and source not in loop_offsets
            and target != header_offset
        ):
            return None, "natural_loop_has_external_confirmed_non_header_entry"

    loop_ends = [
        int(statements[label]["source_node"]["source"]["end"])
        for label in loop_nodes
    ]
    envelope_end = max(loop_ends)
    linear_nodes = sorted(
        (
            node
            for node in linear_ir["nodes"]
            if node["source"]["region"] == region
            and header_offset <= int(node["source"]["start"]) < envelope_end
        ),
        key=lambda node: (
            int(node["source"]["start"]),
            int(node["source"]["end"]),
            str(node["id"]),
        ),
    )
    cursor = header_offset
    for node in linear_nodes:
        start = int(node["source"]["start"])
        end = int(node["source"]["end"])
        if start != cursor or end <= start or end > envelope_end:
            return None, "linear_loop_envelope_is_incomplete"
        if node["kind"] == "opaque":
            return None, "linear_loop_envelope_contains_opaque_boundary"
        cursor = end
    if not linear_nodes or cursor != envelope_end:
        return None, "linear_loop_envelope_is_incomplete"

    ordered_nodes = sorted(loop_nodes, key=lambda label: _label_key(labels[label]))
    envelope_labels = sorted(
        (
            label
            for label, info in labels.items()
            if str(info["region"]) == region
            and header_offset <= int(info["offset"]) < envelope_end
        ),
        key=lambda label: _label_key(labels[label]),
    )
    exit_edges = sorted(
        (
            {
                "source_label": source,
                "source_offset": int(labels[source]["offset"]),
                "target_label": target,
                "target_offset": int(labels[target]["offset"]),
            }
            for source in loop_nodes
            for target in outgoing[source]
            if target not in loop_nodes
        ),
        key=lambda row: (
            int(row["source_offset"]),
            int(row["target_offset"]),
            str(row["source_label"]),
        ),
    )
    return {
        "kind": "natural_loop",
        "graph_index": graph_index,
        "region": region,
        "header_label": header,
        "header_offset": header_offset,
        "latch_labels": latches,
        "latch_offsets": [int(labels[label]["offset"]) for label in latches],
        "back_edges": [
            {
                "source_label": latch,
                "source_offset": int(labels[latch]["offset"]),
                "target_label": header,
                "target_offset": header_offset,
            }
            for latch in latches
        ],
        "natural_label_ids": ordered_nodes,
        "natural_statement_ids": [statements[label]["id"] for label in ordered_nodes],
        "envelope_start": header_offset,
        "envelope_end": envelope_end,
        "envelope_label_ids": envelope_labels,
        "envelope_statement_ids": [statements[label]["id"] for label in envelope_labels],
        "envelope_linear_node_ids": [node["id"] for node in linear_nodes],
        "exit_edges": exit_edges,
        "proof_status": "same_region_header_dominates_all_latches_single_entry",
        "surface_syntax": "unresolved_retain_label_goto_fallback",
    }, ""


def _region_for_offset(linear_ir: dict[str, Any], offset: int) -> str:
    for node in linear_ir["nodes"]:
        if int(node["source"]["start"]) <= offset < int(node["source"]["end"]):
            return str(node["source"]["region"])
    return ""


def _reachable(start: str, outgoing: dict[str, list[str]]) -> set[str]:
    seen: set[str] = set()
    pending = [start]
    while pending:
        node = pending.pop()
        if node in seen:
            continue
        seen.add(node)
        pending.extend(target for target in outgoing.get(node, []) if target not in seen)
    return seen


def _label_key(label: dict[str, Any]) -> tuple[int, str]:
    return int(label["offset"]), str(label["id"])


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Prove same-region natural MES loops without guessing surface syntax."
    )
    parser.add_argument("linear_ir", type=Path)
    parser.add_argument("flow_proof", type=Path)
    parser.add_argument("region_proof", type=Path)
    parser.add_argument("execution_fallthroughs", type=Path)
    parser.add_argument("shared_call_returns", type=Path)
    parser.add_argument("library_audit", type=Path)
    parser.add_argument("output", type=Path, nargs="?")
    args = parser.parse_args()
    linear_ir = json.loads(args.linear_ir.read_text(encoding="utf-8"))
    transfer_proof = json.loads(args.flow_proof.read_text(encoding="utf-8"))
    conditional_proof = json.loads(args.region_proof.read_text(encoding="utf-8"))
    execution_fallthroughs = json.loads(
        args.execution_fallthroughs.read_text(encoding="utf-8")
    )
    shared_calls = json.loads(args.shared_call_returns.read_text(encoding="utf-8"))
    library_audit = json.loads(args.library_audit.read_text(encoding="utf-8"))
    document = prove(
        linear_ir,
        transfer_proof,
        conditional_proof,
        execution_fallthroughs,
        shared_calls,
        library_audit,
    )
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
            args.region_proof.resolve(),
            args.execution_fallthroughs.resolve(),
            args.shared_call_returns.resolve(),
            args.library_audit.resolve(),
        }:
            raise NaturalLoopProofError("natural-loop output must not replace an input")
        args.output.write_text(encoded + "\n", encoding="utf-8")
    print(
        "MES_NATURAL_LOOP_PROOF_PASS "
        f"schema={document['schema']} entry={document['source_identity'].get('entry', '')} "
        f"candidates={document['coverage']['back_edge_candidate_count']} "
        f"loops={document['coverage']['natural_loop_count']} "
        f"proved_edges={document['coverage']['proved_back_edge_count']} "
        f"rejected={document['coverage']['rejected_header_count']} "
        f"payload_sha256={document['payload_sha256']}"
    )


if __name__ == "__main__":
    main()
