from __future__ import annotations

import argparse
import copy
import json
from pathlib import Path
from typing import Any

import decompile_mes_handoff as decompiler
import prove_mes_control_flow as flow_proof
import prove_mes_if_regions as region_proof
from payload_values import canonical_payload_bytes, fingerprint


GUARD_CHAIN_PROOF_SCHEMA = "kakyu_mes_guard_chain_proof/v1"
CONFIRMED_REFERENCE_KINDS = {
    "condition_true_fallthrough",
    "condition_false_target",
    "continuation_target",
}


class GuardChainProofError(ValueError):
    pass


def prove(
    linear_ir: dict[str, Any],
    transfer_proof: dict[str, Any],
    conditional_proof: dict[str, Any],
) -> dict[str, Any]:
    decompiler.validate(linear_ir)
    flow_proof.validate(transfer_proof)
    region_proof.validate(conditional_proof, linear_ir, transfer_proof)
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
    if document.get("schema") != GUARD_CHAIN_PROOF_SCHEMA:
        raise GuardChainProofError("unsupported guard-chain proof schema")
    retained = document.get("payload_sha256")
    if not isinstance(retained, str) or len(retained) != 64 or fingerprint(document) != retained:
        raise GuardChainProofError("guard-chain proof fingerprint changed")
    decompiler.validate(linear_ir)
    flow_proof.validate(transfer_proof)
    region_proof.validate(conditional_proof, linear_ir, transfer_proof)
    expected = _build(linear_ir, transfer_proof, conditional_proof)
    actual = dict(document)
    actual.pop("payload_sha256", None)
    if actual != expected:
        raise GuardChainProofError("guard-chain projection changed")
    return {
        "ok": True,
        "schema": GUARD_CHAIN_PROOF_SCHEMA,
        "payload_sha256": retained,
    }


def _build(
    linear_ir: dict[str, Any],
    transfer_proof: dict[str, Any],
    conditional_proof: dict[str, Any],
) -> dict[str, Any]:
    fallback_graphs = conditional_proof["fallback_control"]["graphs"]
    graph_results = [
        _prove_graph(
            index,
            linear_ir,
            conditional_proof["graphs"][index],
            graph,
        )
        for index, graph in enumerate(fallback_graphs)
    ]
    return {
        "ok": True,
        "schema": GUARD_CHAIN_PROOF_SCHEMA,
        "producer": {
            "implementation": "python_phase5_guard_chain_prover",
            "contract": GUARD_CHAIN_PROOF_SCHEMA,
        },
        "compatibility": {
            "policy": "exact_linear_transfer_and_region_proof_match",
            "input_decompiler_schema": decompiler.DECOMPILER_IR_SCHEMA,
            "input_flow_proof_schema": flow_proof.CONTROL_FLOW_PROOF_SCHEMA,
            "input_region_proof_schema": region_proof.REDUCIBLE_REGION_PROOF_SCHEMA,
            "unknown_v1_field": "ignore",
            "promotion_policy": "labels_retained_no_if_elif_or_dispatch_semantics",
        },
        "inputs": {
            "linear_ir_sha256": linear_ir["payload_sha256"],
            "flow_proof_sha256": transfer_proof["payload_sha256"],
            "region_proof_sha256": conditional_proof["payload_sha256"],
        },
        "source_identity": copy.deepcopy(linear_ir.get("source_identity", {})),
        "graphs": graph_results,
        "coverage": {
            "graph_count": len(graph_results),
            "guard_chain_count": sum(len(row["guard_chains"]) for row in graph_results),
            "guard_count": sum(
                sum(len(chain["guards"]) for chain in row["guard_chains"])
                for row in graph_results
            ),
            "cross_region_false_edge_count": sum(
                int(row["cross_region_false_edge_count"]) for row in graph_results
            ),
            "external_entry_guard_count": sum(
                sum(len(chain["external_entry_guard_labels"]) for chain in row["guard_chains"])
                for row in graph_results
            ),
            "unchained_conditional_count": sum(
                int(row["unchained_conditional_count"]) for row in graph_results
            ),
            "rejected_component_count": sum(
                len(row["rejected_components"]) for row in graph_results
            ),
        },
    }


def _prove_graph(
    graph_index: int,
    linear_ir: dict[str, Any],
    conditional_graph: dict[str, Any],
    control_graph: dict[str, Any],
) -> dict[str, Any]:
    labels = {str(row["id"]): row for row in control_graph["labels"]}
    statements = {
        str(row["label"]): row
        for row in control_graph["statements"]
        if row["kind"] == "conditional_goto"
    }
    structured = {
        str(row["source_label"])
        for key in ("if_then_regions", "if_else_regions")
        for row in conditional_graph[key]
    }
    eligible = {
        label: statement
        for label, statement in statements.items()
        if label not in structured
    }
    false_successor = {
        label: str(statement["false_label"])
        for label, statement in eligible.items()
        if str(statement["false_label"]) in eligible
    }
    predecessors: dict[str, list[str]] = {label: [] for label in eligible}
    for source, target in false_successor.items():
        predecessors[target].append(source)
    for rows in predecessors.values():
        rows.sort(key=lambda label: _label_key(labels[label]))

    merged = sorted(
        (label for label, rows in predecessors.items() if len(rows) > 1),
        key=lambda label: _label_key(labels[label]),
    )
    rejected: list[dict[str, Any]] = []
    visited: set[str] = set()
    chains: list[dict[str, Any]] = []
    starts = sorted(
        (label for label in eligible if len(predecessors[label]) == 0),
        key=lambda label: _label_key(labels[label]),
    )
    for start in starts:
        labels_in_chain = _walk_chain(
            start, false_successor, predecessors, visited
        )
        if len(labels_in_chain) >= 2:
            default_label = str(eligible[labels_in_chain[-1]]["false_label"])
            chains.append(
                _chain_record(
                    graph_index,
                    labels_in_chain,
                    default_label,
                    eligible,
                    labels,
                    linear_ir,
                )
            )

    for label in merged:
        if label in visited:
            continue
        component = _walk_unstructured_component(label, false_successor, visited)
        rejected.append({
            "kind": "merged_false_guard_component",
            "guard_labels": component,
            "merge_label": label,
            "predecessor_labels": predecessors[label],
        })

    remaining = sorted(
        (label for label in eligible if label not in visited),
        key=lambda label: _label_key(labels[label]),
    )
    while remaining:
        start = remaining[0]
        component: list[str] = []
        seen: set[str] = set()
        current = start
        while current in eligible and current not in seen:
            seen.add(current)
            visited.add(current)
            component.append(current)
            current = false_successor.get(current, "")
        rejected.append({
            "kind": "cyclic_or_merged_false_guard_component",
            "guard_labels": component,
        })
        remaining = sorted(
            (label for label in eligible if label not in visited),
            key=lambda label: _label_key(labels[label]),
        )

    chained = {
        guard["label"]
        for chain in chains
        for guard in chain["guards"]
    }
    cross_region = sum(
        1
        for source, target in false_successor.items()
        if str(labels[source]["region"]) != str(labels[target]["region"])
    )
    return {
        "graph_index": graph_index,
        "guard_chains": chains,
        "rejected_components": rejected,
        "cross_region_false_edge_count": cross_region,
        "unchained_conditional_count": len(eligible) - len(chained),
    }


def _walk_chain(
    start: str,
    false_successor: dict[str, str],
    predecessors: dict[str, list[str]],
    visited: set[str],
) -> list[str]:
    chain: list[str] = []
    current = start
    while current and current not in visited:
        visited.add(current)
        chain.append(current)
        successor = false_successor.get(current, "")
        if not successor or len(predecessors.get(successor, [])) != 1:
            break
        current = successor
    return chain


def _walk_unstructured_component(
    start: str,
    false_successor: dict[str, str],
    visited: set[str],
) -> list[str]:
    component: list[str] = []
    current = start
    while current and current not in visited:
        visited.add(current)
        component.append(current)
        current = false_successor.get(current, "")
    return component


def _chain_record(
    graph_index: int,
    chain: list[str],
    default_label: str,
    statements: dict[str, dict[str, Any]],
    labels: dict[str, dict[str, Any]],
    linear_ir: dict[str, Any],
) -> dict[str, Any]:
    guards: list[dict[str, Any]] = []
    external_entries: list[str] = []
    previous_source_offset: int | None = None
    for label in chain:
        statement = statements[label]
        source_offset = int(statement["source_node"]["source"]["start"])
        label_offset = int(labels[label]["offset"])
        if previous_source_offset is not None and _has_external_entry(
            linear_ir, label_offset, previous_source_offset
        ):
            external_entries.append(label)
        guards.append({
            "label": label,
            "source_start": source_offset,
            "source_region": str(labels[label]["region"]),
            "condition": copy.deepcopy(statement["condition"]),
            "case_label": str(statement["true_label"]),
            "next_false_label": str(statement["false_label"]),
        })
        previous_source_offset = source_offset
    return {
        "id": f"guard_chain_g{graph_index:02d}_{int(guards[0]['source_start']):08x}",
        "kind": "guard_chain",
        "guards": guards,
        "default_label": default_label,
        "external_entry_guard_labels": sorted(external_entries),
        "proof_status": "confirmed_false_edge_chain_labels_retained",
        "reducible_region": False,
        "semantic_dispatch": "unresolved",
    }


def _has_external_entry(
    linear_ir: dict[str, Any], target_offset: int, expected_owner: int
) -> bool:
    for reference in linear_ir["references"]:
        value = reference.get("value", {})
        if (
            reference.get("kind") == "code"
            and value.get("kind") in CONFIRMED_REFERENCE_KINDS
            and int(value.get("target_offset", -1)) == target_offset
            and int(value.get("source_offset", -1)) != expected_owner
        ):
            return True
    return False


def _label_key(label: dict[str, Any]) -> tuple[int, str]:
    return int(label["offset"]), str(label["id"])


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Prove label-preserving MES false-edge guard chains."
    )
    parser.add_argument("linear_ir", type=Path)
    parser.add_argument("flow_proof", type=Path)
    parser.add_argument("region_proof", type=Path)
    parser.add_argument("output", type=Path, nargs="?")
    args = parser.parse_args()
    linear_ir = json.loads(args.linear_ir.read_text(encoding="utf-8"))
    transfer = json.loads(args.flow_proof.read_text(encoding="utf-8"))
    conditional = json.loads(args.region_proof.read_text(encoding="utf-8"))
    document = prove(linear_ir, transfer, conditional)
    encoded = json.dumps(
        document,
        ensure_ascii=False,
        allow_nan=False,
        sort_keys=True,
        separators=(",", ":"),
    )
    if args.output is not None:
        inputs = {args.linear_ir.resolve(), args.flow_proof.resolve(), args.region_proof.resolve()}
        if args.output.resolve() in inputs:
            raise GuardChainProofError("guard-chain output must not replace an input")
        args.output.write_text(encoded + "\n", encoding="utf-8")
    print(
        "MES_GUARD_CHAIN_PROOF_PASS "
        f"schema={document['schema']} entry={document['source_identity'].get('entry', '')} "
        f"chains={document['coverage']['guard_chain_count']} "
        f"guards={document['coverage']['guard_count']} "
        f"rejected={document['coverage']['rejected_component_count']} "
        f"payload_sha256={document['payload_sha256']}"
    )


if __name__ == "__main__":
    main()
