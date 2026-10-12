from __future__ import annotations

import argparse
import copy
import json
from pathlib import Path
from typing import Any

import prove_mes_control_flow as flow_proof
from payload_values import canonical_payload_bytes, fingerprint


LOW_LEVEL_CONTROL_IR_SCHEMA = "kakyu_mes_low_level_control_ir/v1"


class LowLevelControlIrError(ValueError):
    pass


def emit(proof: dict[str, Any]) -> dict[str, Any]:
    flow_proof.validate(proof)
    proof_graphs = copy.deepcopy(proof["graphs"])
    graphs = [_emit_graph(index, graph) for index, graph in enumerate(proof_graphs)]
    document = {
        "ok": True,
        "schema": LOW_LEVEL_CONTROL_IR_SCHEMA,
        "producer": {
            "implementation": "python_phase5_low_level_control_emitter",
            "contract": LOW_LEVEL_CONTROL_IR_SCHEMA,
        },
        "compatibility": {
            "policy": "exact_control_flow_proof_schema_match",
            "input_proof_schema": flow_proof.CONTROL_FLOW_PROOF_SCHEMA,
            "unknown_control_ir_schema": "reject",
            "unknown_v1_field": "ignore",
            "unstructured_flow_policy": "deterministic_labels_and_explicit_gotos",
        },
        "input_proof": {
            "schema": flow_proof.CONTROL_FLOW_PROOF_SCHEMA,
            "payload_sha256": proof["payload_sha256"],
        },
        "source_identity": copy.deepcopy(proof.get("source_identity", {})),
        "proof_graphs": proof_graphs,
        "graphs": graphs,
        "coverage": _aggregate_coverage(graphs),
    }
    document["payload_sha256"] = fingerprint(document)
    validate(document)
    return document


def validate(document: dict[str, Any]) -> dict[str, Any]:
    if document.get("schema") != LOW_LEVEL_CONTROL_IR_SCHEMA:
        raise LowLevelControlIrError("unsupported MES low-level control IR schema")
    compatibility = document.get("compatibility")
    if not isinstance(compatibility, dict) or compatibility.get(
        "input_proof_schema"
    ) != flow_proof.CONTROL_FLOW_PROOF_SCHEMA:
        raise LowLevelControlIrError("unsupported low-level control proof schema")
    input_proof = document.get("input_proof")
    if (
        not isinstance(input_proof, dict)
        or input_proof.get("schema") != flow_proof.CONTROL_FLOW_PROOF_SCHEMA
        or not isinstance(input_proof.get("payload_sha256"), str)
        or len(input_proof["payload_sha256"]) != 64
    ):
        raise LowLevelControlIrError("low-level control input identity is missing")
    retained = document.get("payload_sha256")
    if not isinstance(retained, str) or len(retained) != 64:
        raise LowLevelControlIrError("missing low-level control IR fingerprint")
    if fingerprint(document) != retained:
        raise LowLevelControlIrError("low-level control IR fingerprint changed")
    proof_graphs = document.get("proof_graphs")
    graphs = document.get("graphs")
    if not isinstance(proof_graphs, list) or not isinstance(graphs, list):
        raise LowLevelControlIrError("low-level control graph arrays are missing")
    if len(proof_graphs) != len(graphs):
        raise LowLevelControlIrError("low-level control graph count changed")
    for index, proof_graph in enumerate(proof_graphs):
        expected = _emit_graph(index, proof_graph)
        if graphs[index] != expected:
            raise LowLevelControlIrError("low-level control graph projection changed")
    if document.get("coverage") != _aggregate_coverage(graphs):
        raise LowLevelControlIrError("low-level control aggregate coverage changed")
    return {"ok": True, "schema": LOW_LEVEL_CONTROL_IR_SCHEMA, "payload_sha256": retained}


def _emit_graph(graph_index: int, proof_graph: dict[str, Any]) -> dict[str, Any]:
    source_graph = proof_graph.get("source_graph")
    constructs = proof_graph.get("constructs")
    if not isinstance(source_graph, dict) or not isinstance(constructs, list):
        raise LowLevelControlIrError("control proof graph is incomplete")
    graph_nodes = source_graph.get("nodes")
    graph_edges = source_graph.get("edges")
    if not isinstance(graph_nodes, list) or not isinstance(graph_edges, list):
        raise LowLevelControlIrError("control proof source graph arrays are missing")
    sorted_nodes = sorted(
        graph_nodes,
        key=lambda node: (int(node.get("offset", -1)), str(node.get("id", ""))),
    )
    label_by_graph_node: dict[str, str] = {}
    labels: list[dict[str, Any]] = []
    offset_counts: dict[int, int] = {}
    for graph_node in sorted_nodes:
        graph_node_id = str(graph_node.get("id", ""))
        offset = int(graph_node.get("offset", -1))
        ordinal = offset_counts.get(offset, 0)
        offset_counts[offset] = ordinal + 1
        label = f"L_{offset:08X}" + (f"_{ordinal}" if ordinal else "")
        label_by_graph_node[graph_node_id] = label
        labels.append(
            {
                "id": label,
                "graph_node_id": graph_node_id,
                "offset": offset,
                "region": str(graph_node.get("region", "")),
                "graph_depth": int(graph_node.get("graph_depth", 0)),
                "status": str(graph_node.get("status", "")),
            }
        )
    construct_by_source = {
        str(construct.get("source_graph_node_id", "")): construct
        for construct in constructs
        if isinstance(construct, dict)
    }
    if len(construct_by_source) != len(sorted_nodes) or set(construct_by_source) != set(
        label_by_graph_node
    ):
        raise LowLevelControlIrError("control proof construct coverage changed")

    statements: list[dict[str, Any]] = []
    for ordinal, label in enumerate(labels):
        construct = construct_by_source[label["graph_node_id"]]
        statements.append(
            _emit_statement(
                ordinal,
                label["id"],
                construct,
                graph_edges,
                label_by_graph_node,
            )
        )
    statement_by_label = {row["label"]: row["id"] for row in statements}
    region_groups: dict[tuple[int, str], dict[str, Any]] = {}
    for label in labels:
        key = (int(label["graph_depth"]), str(label["region"]))
        group = region_groups.setdefault(
            key,
            {
                "region": key[1],
                "graph_depth": key[0],
                "label_ids": [],
                "statement_ids": [],
            },
        )
        group["label_ids"].append(label["id"])
        group["statement_ids"].append(statement_by_label[label["id"]])
    regions: list[dict[str, Any]] = []
    for ordinal, (_key, group) in enumerate(sorted(region_groups.items())):
        regions.append({"id": f"control_region_{ordinal:04d}", **group})

    kind_counts: dict[str, int] = {}
    for statement in statements:
        kind = str(statement["kind"])
        kind_counts[kind] = kind_counts.get(kind, 0) + 1
    return {
        "graph_index": graph_index,
        "bounded_complete": bool(proof_graph.get("bounded_complete", False)),
        "labels": labels,
        "regions": regions,
        "statements": statements,
        "coverage": {
            "graph_node_count": len(graph_nodes),
            "graph_edge_count": len(graph_edges),
            "label_count": len(labels),
            "statement_count": len(statements),
            "region_count": len(regions),
            "statement_kind_counts": dict(sorted(kind_counts.items())),
            "all_graph_nodes_labeled": len(labels) == len(graph_nodes),
            "all_proof_constructs_emitted": len(statements) == len(constructs),
        },
    }


def _emit_statement(
    ordinal: int,
    label: str,
    construct: dict[str, Any],
    graph_edges: list[dict[str, Any]],
    label_by_graph_node: dict[str, str],
) -> dict[str, Any]:
    base = {
        "id": f"control_statement_{ordinal:04d}",
        "label": label,
        "source_construct_id": str(construct.get("id", "")),
        "source_node": copy.deepcopy(construct.get("source_node", {})),
    }
    kind = str(construct.get("kind", ""))
    if kind == "conditional_branch":
        return {
            **base,
            "kind": "conditional_goto",
            "condition": copy.deepcopy(construct["condition"]),
            "true_label": _target_label(construct["true_target"], label_by_graph_node),
            "false_label": _target_label(construct["false_target"], label_by_graph_node),
            "true_is_instruction_fallthrough": True,
            "proof_status": str(construct["proof"]["status"]),
        }
    if kind == "continuation_transfer":
        return {
            **base,
            "kind": "goto",
            "target_label": _target_label(construct["target"], label_by_graph_node),
            "transfer_kind": "continuation",
            "proof_status": str(construct["proof"]["status"]),
        }
    if kind == "boundary_anchor":
        return {
            **base,
            "kind": "boundary",
            "boundary": str(construct.get("boundary", "")),
        }
    if kind == "graph_anchor":
        return {**base, "kind": "anchor"}
    if kind == "unexpanded_transfer_anchor":
        return {
            **base,
            "kind": "unexpanded_transfer",
            "reason": str(construct.get("reason", "")),
        }
    if kind == "unresolved_transfer":
        targets = []
        for edge_index in construct.get("edge_indices", []):
            edge = graph_edges[int(edge_index)]
            targets.append(
                {
                    "edge_kind": str(edge.get("kind", "")),
                    "target_label": label_by_graph_node[str(edge.get("to_id", ""))],
                    "confirmed_flow": bool(edge.get("confirmed_flow", False)),
                }
            )
        return {
            **base,
            "kind": "unresolved_transfer",
            "reason": str(construct.get("reason", "")),
            "targets": targets,
        }
    raise LowLevelControlIrError("unsupported control proof construct kind")


def _target_label(
    target: dict[str, Any],
    label_by_graph_node: dict[str, str],
) -> str:
    graph_node_id = str(target.get("graph_node_id", ""))
    if graph_node_id not in label_by_graph_node:
        raise LowLevelControlIrError("control transfer target has no label")
    return label_by_graph_node[graph_node_id]


def _aggregate_coverage(graphs: list[dict[str, Any]]) -> dict[str, Any]:
    statement_kind_counts: dict[str, int] = {}
    for graph in graphs:
        for kind, count in graph["coverage"]["statement_kind_counts"].items():
            statement_kind_counts[kind] = statement_kind_counts.get(kind, 0) + int(count)
    return {
        "graph_count": len(graphs),
        "graph_node_count": sum(int(graph["coverage"]["graph_node_count"]) for graph in graphs),
        "graph_edge_count": sum(int(graph["coverage"]["graph_edge_count"]) for graph in graphs),
        "label_count": sum(int(graph["coverage"]["label_count"]) for graph in graphs),
        "statement_count": sum(int(graph["coverage"]["statement_count"]) for graph in graphs),
        "region_count": sum(int(graph["coverage"]["region_count"]) for graph in graphs),
        "statement_kind_counts": dict(sorted(statement_kind_counts.items())),
        "all_graph_nodes_labeled": all(
            graph["coverage"]["all_graph_nodes_labeled"] for graph in graphs
        ),
        "all_proof_constructs_emitted": all(
            graph["coverage"]["all_proof_constructs_emitted"] for graph in graphs
        ),
    }


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Emit deterministic label/goto MES control IR from a validated flow proof."
    )
    parser.add_argument("flow_proof", type=Path)
    parser.add_argument("output", type=Path, nargs="?")
    args = parser.parse_args()
    with args.flow_proof.open("r", encoding="utf-8") as stream:
        proof = json.load(stream)
    document = emit(proof)
    encoded = json.dumps(
        document,
        ensure_ascii=False,
        allow_nan=False,
        sort_keys=True,
        separators=(",", ":"),
    )
    if args.output is not None:
        if args.output.resolve() == args.flow_proof.resolve():
            raise LowLevelControlIrError("low-level control output must not replace its proof")
        args.output.write_text(encoded + "\n", encoding="utf-8")
    print(
        "MES_LOW_LEVEL_CONTROL_IR_PASS "
        f"schema={document['schema']} entry={document['source_identity'].get('entry', '')} "
        f"graphs={document['coverage']['graph_count']} labels={document['coverage']['label_count']} "
        f"statements={document['coverage']['statement_count']} "
        f"payload_sha256={document['payload_sha256']}"
    )


if __name__ == "__main__":
    main()
