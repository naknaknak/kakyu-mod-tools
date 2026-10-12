from __future__ import annotations

import argparse
import copy
import json
from collections import deque
from pathlib import Path
from typing import Any

import decompile_mes_handoff as decompiler
import prove_mes_control_flow as flow_proof
import prove_mes_if_regions as region_proof
from payload_values import canonical_payload_bytes, fingerprint


CROSS_REGION_JOIN_PROOF_SCHEMA = "kakyu_mes_cross_region_join_proof/v1"
CONFIRMED_REFERENCE_KINDS = {
    "condition_true_fallthrough",
    "condition_false_target",
    "continuation_target",
}


class CrossRegionJoinProofError(ValueError):
    pass


def prove(
    linear_ir: dict[str, Any],
    transfer_proof: dict[str, Any],
    conditional_proof: dict[str, Any],
) -> dict[str, Any]:
    _validate_inputs(linear_ir, transfer_proof, conditional_proof)
    document = _build(linear_ir, transfer_proof, conditional_proof)
    document["payload_sha256"] = fingerprint(document)
    validate(document, linear_ir, transfer_proof, conditional_proof)
    return document


def validate(
    document: dict[str, Any],
    linear_ir: dict[str, Any],
    transfer_proof: dict[str, Any],
    conditional_proof: dict[str, Any],
) -> dict[str, Any]:
    if document.get("schema") != CROSS_REGION_JOIN_PROOF_SCHEMA:
        raise CrossRegionJoinProofError("unsupported cross-region join proof schema")
    retained = document.get("payload_sha256")
    if (
        not isinstance(retained, str)
        or len(retained) != 64
        or fingerprint(document) != retained
    ):
        raise CrossRegionJoinProofError("cross-region join proof fingerprint changed")
    _validate_inputs(linear_ir, transfer_proof, conditional_proof)
    expected = _build(linear_ir, transfer_proof, conditional_proof)
    actual = dict(document)
    actual.pop("payload_sha256", None)
    if actual != expected:
        raise CrossRegionJoinProofError("cross-region join projection changed")
    return {
        "ok": True,
        "schema": CROSS_REGION_JOIN_PROOF_SCHEMA,
        "payload_sha256": retained,
    }


def _validate_inputs(
    linear_ir: dict[str, Any],
    transfer_proof: dict[str, Any],
    conditional_proof: dict[str, Any],
) -> None:
    decompiler.validate(linear_ir)
    flow_proof.validate(transfer_proof)
    region_proof.validate(conditional_proof, linear_ir, transfer_proof)
    if transfer_proof["input_decompiler"]["payload_sha256"] != linear_ir["payload_sha256"]:
        raise CrossRegionJoinProofError("flow proof belongs to another linear IR")
    if conditional_proof["inputs"]["linear_ir_sha256"] != linear_ir["payload_sha256"]:
        raise CrossRegionJoinProofError("conditional proof belongs to another linear IR")


def _build(
    linear_ir: dict[str, Any],
    transfer_proof: dict[str, Any],
    conditional_proof: dict[str, Any],
) -> dict[str, Any]:
    graph_results = [
        _prove_graph(
            linear_ir,
            conditional_proof["graphs"][index],
            fallback_graph,
        )
        for index, fallback_graph in enumerate(
            conditional_proof["fallback_control"]["graphs"]
        )
    ]
    return {
        "ok": True,
        "schema": CROSS_REGION_JOIN_PROOF_SCHEMA,
        "producer": {
            "implementation": "python_phase5_cross_region_join_prover",
            "contract": CROSS_REGION_JOIN_PROOF_SCHEMA,
        },
        "compatibility": {
            "policy": "exact_linear_transfer_and_conditional_proof_match",
            "input_decompiler_schema": decompiler.DECOMPILER_IR_SCHEMA,
            "input_flow_proof_schema": flow_proof.CONTROL_FLOW_PROOF_SCHEMA,
            "input_region_proof_schema": region_proof.REDUCIBLE_REGION_PROOF_SCHEMA,
            "unknown_v1_field": "ignore",
            "promotion_policy": "bounded_complete_all_paths_converge_at_unique_nearest_join_without_arm_external_entry",
            "surface_syntax_policy": "retain_low_level_fallback_no_cross_region_if_guess",
        },
        "inputs": {
            "linear_ir_sha256": linear_ir["payload_sha256"],
            "flow_proof_sha256": transfer_proof["payload_sha256"],
            "region_proof_sha256": conditional_proof["payload_sha256"],
            "fallback_control_sha256": conditional_proof["fallback_control"][
                "payload_sha256"
            ],
        },
        "source_identity": copy.deepcopy(linear_ir.get("source_identity", {})),
        "graphs": graph_results,
        "coverage": {
            "graph_count": len(graph_results),
            "cross_region_candidate_count": sum(
                len(graph["cross_region_joins"])
                + len(graph["rejected_cross_region_conditionals"])
                for graph in graph_results
            ),
            "proved_cross_region_join_count": sum(
                len(graph["cross_region_joins"]) for graph in graph_results
            ),
            "rejected_cross_region_conditional_count": sum(
                len(graph["rejected_cross_region_conditionals"])
                for graph in graph_results
            ),
        },
    }


def _prove_graph(
    linear_ir: dict[str, Any],
    conditional_graph: dict[str, Any],
    fallback_graph: dict[str, Any],
) -> dict[str, Any]:
    labels = {str(row["id"]): row for row in fallback_graph["labels"]}
    statements = {
        str(row["label"]): row for row in fallback_graph["statements"]
    }
    outgoing = _outgoing(conditional_graph, statements)
    proved: list[dict[str, Any]] = []
    rejected: list[dict[str, Any]] = []
    for source_label in sorted(statements, key=lambda label: _label_key(labels[label])):
        statement = statements[source_label]
        if statement["kind"] != "conditional_goto":
            continue
        true_label = str(statement["true_label"])
        false_label = str(statement["false_label"])
        regions = {
            str(labels[source_label]["region"]),
            str(labels[true_label]["region"]),
            str(labels[false_label]["region"]),
        }
        if len(regions) == 1:
            continue
        candidate, reason = _cross_region_join_candidate(
            linear_ir,
            statement,
            labels,
            statements,
            outgoing,
            bool(conditional_graph.get("bounded_complete", False)),
        )
        if candidate is None:
            rejected.append(
                {
                    "source_label": source_label,
                    "source_offset": int(labels[source_label]["offset"]),
                    "true_label": true_label,
                    "false_label": false_label,
                    "reason": reason,
                }
            )
        else:
            candidate["id"] = (
                f"cross_region_join_{int(labels[source_label]['offset']):08x}"
            )
            proved.append(candidate)
    return {
        "graph_index": int(fallback_graph["graph_index"]),
        "bounded_complete": bool(conditional_graph.get("bounded_complete", False)),
        "cross_region_joins": proved,
        "rejected_cross_region_conditionals": rejected,
    }


def _outgoing(
    conditional_graph: dict[str, Any],
    statements: dict[str, dict[str, Any]],
) -> dict[str, list[str]]:
    outgoing: dict[str, list[str]] = {}
    for label, statement in statements.items():
        kind = str(statement["kind"])
        if kind == "conditional_goto":
            outgoing[label] = [
                str(statement["true_label"]),
                str(statement["false_label"]),
            ]
        elif kind == "goto":
            outgoing[label] = [str(statement["target_label"])]
        else:
            outgoing[label] = []
    for edge in conditional_graph["proved_fallthroughs"]:
        source = str(edge["source_label"])
        target = str(edge["target_label"])
        if source not in outgoing or outgoing[source]:
            raise CrossRegionJoinProofError(
                "conditional fallthrough source is not an empty anchor"
            )
        outgoing[source] = [target]
    return outgoing


def _cross_region_join_candidate(
    linear_ir: dict[str, Any],
    source: dict[str, Any],
    labels: dict[str, dict[str, Any]],
    statements: dict[str, dict[str, Any]],
    outgoing: dict[str, list[str]],
    bounded_complete: bool,
) -> tuple[dict[str, Any] | None, str]:
    if not bounded_complete:
        return None, "control_graph_is_not_bounded_complete"
    source_label = str(source["label"])
    true_label = str(source["true_label"])
    false_label = str(source["false_label"])
    true_distances = _distances(true_label, outgoing)
    false_distances = _distances(false_label, outgoing)
    common = set(true_distances) & set(false_distances)
    valid: list[tuple[tuple[int, int, tuple[int, str]], str]] = []
    for join_label in common:
        if join_label == source_label:
            continue
        if not _all_paths_reach(true_label, join_label, outgoing):
            continue
        if not _all_paths_reach(false_label, join_label, outgoing):
            continue
        metric = (
            max(true_distances[join_label], false_distances[join_label]),
            true_distances[join_label] + false_distances[join_label],
            _label_key(labels[join_label]),
        )
        valid.append((metric, join_label))
    if not valid:
        return None, "branches_have_no_common_total_join"
    valid.sort()
    best_metric = valid[0][0][:2]
    nearest = [row for row in valid if row[0][:2] == best_metric]
    if len(nearest) != 1:
        return None, "branches_have_ambiguous_nearest_join"
    join_label = nearest[0][1]
    true_path = _path_envelope(true_label, join_label, outgoing)
    false_path = _path_envelope(false_label, join_label, outgoing)
    arm_labels = (true_path | false_path) - {join_label}
    source_offset = int(labels[source_label]["offset"])
    incoming: dict[str, set[str]] = {label: set() for label in outgoing}
    for owner, targets in outgoing.items():
        for target in targets:
            incoming.setdefault(target, set()).add(owner)
    for label in arm_labels:
        allowed = set(arm_labels)
        if label in {true_label, false_label}:
            allowed.add(source_label)
        if incoming.get(label, set()) - allowed:
            return None, "cross_region_arm_has_external_graph_entry"
    arm_offsets = {int(labels[label]["offset"]) for label in arm_labels}
    allowed_owner_offsets = arm_offsets | {source_offset}
    for reference in linear_ir["references"]:
        value = reference.get("value", {})
        if (
            reference.get("kind") != "code"
            or value.get("kind") not in CONFIRMED_REFERENCE_KINDS
        ):
            continue
        target = int(value.get("target_offset", -1))
        owner = int(value.get("source_offset", -1))
        if target in arm_offsets and owner not in allowed_owner_offsets:
            return None, "cross_region_arm_has_external_confirmed_reference"
    path_labels = sorted(arm_labels, key=lambda label: _label_key(labels[label]))
    return {
        "kind": "cross_region_join",
        "source_label": source_label,
        "source_offset": source_offset,
        "condition": copy.deepcopy(source["condition"]),
        "true_entry_label": true_label,
        "true_path_label_ids": sorted(
            true_path - {join_label}, key=lambda label: _label_key(labels[label])
        ),
        "false_entry_label": false_label,
        "false_path_label_ids": sorted(
            false_path - {join_label}, key=lambda label: _label_key(labels[label])
        ),
        "join_label": join_label,
        "join_offset": int(labels[join_label]["offset"]),
        "path_region_ids": sorted(
            {str(labels[label]["region"]) for label in path_labels}
        ),
        "fallback_statement_ids": [
            str(statements[label]["id"])
            for label in path_labels
            if label in statements
        ],
        "proof_status": "bounded_all_paths_converge_at_unique_nearest_join_without_arm_external_entry",
        "surface_syntax": "unresolved_low_level_fallback_retained",
    }, ""


def _distances(start: str, outgoing: dict[str, list[str]]) -> dict[str, int]:
    distances = {start: 0}
    pending = deque([start])
    while pending:
        source = pending.popleft()
        for target in outgoing.get(source, []):
            if target not in distances:
                distances[target] = distances[source] + 1
                pending.append(target)
    return distances


def _all_paths_reach(
    start: str, join: str, outgoing: dict[str, list[str]]
) -> bool:
    visiting: set[str] = set()
    memo: dict[str, bool] = {}

    def visit(label: str) -> bool:
        if label == join:
            return True
        if label in memo:
            return memo[label]
        if label in visiting:
            return False
        visiting.add(label)
        targets = outgoing.get(label, [])
        result = bool(targets) and all(visit(target) for target in targets)
        visiting.remove(label)
        memo[label] = result
        return result

    return visit(start)


def _path_envelope(
    start: str, join: str, outgoing: dict[str, list[str]]
) -> set[str]:
    seen: set[str] = set()
    pending = [start]
    while pending:
        label = pending.pop()
        if label in seen:
            continue
        seen.add(label)
        if label != join:
            pending.extend(outgoing.get(label, []))
    return seen


def _label_key(label: dict[str, Any]) -> tuple[int, str]:
    return int(label["offset"]), str(label["id"])


def main() -> None:
    parser = argparse.ArgumentParser(
        description=(
            "Prove bounded cross-region conditional joins while retaining the "
            "low-level label/goto fallback."
        )
    )
    parser.add_argument("linear_ir", type=Path)
    parser.add_argument("flow_proof", type=Path)
    parser.add_argument("if_regions", type=Path)
    parser.add_argument("output", type=Path, nargs="?")
    args = parser.parse_args()
    linear_ir = json.loads(args.linear_ir.read_text(encoding="utf-8"))
    transfers = json.loads(args.flow_proof.read_text(encoding="utf-8"))
    regions = json.loads(args.if_regions.read_text(encoding="utf-8"))
    document = prove(linear_ir, transfers, regions)
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
            args.if_regions.resolve(),
        }:
            raise CrossRegionJoinProofError(
                "cross-region join output must not replace an input"
            )
        args.output.write_text(encoded + "\n", encoding="utf-8")
    print(
        "MES_CROSS_REGION_JOIN_PROOF_PASS "
        f"schema={document['schema']} entry={document['source_identity'].get('entry', '')} "
        f"candidates={document['coverage']['cross_region_candidate_count']} "
        f"proved={document['coverage']['proved_cross_region_join_count']} "
        f"rejected={document['coverage']['rejected_cross_region_conditional_count']} "
        f"payload_sha256={document['payload_sha256']}"
    )


if __name__ == "__main__":
    main()
