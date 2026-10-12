from __future__ import annotations

import argparse
import copy
import json
from pathlib import Path
from typing import Any

import decompile_mes_handoff as decompiler
from payload_values import canonical_payload_bytes, fingerprint


CONTROL_FLOW_PROOF_SCHEMA = "kakyu_mes_control_flow_proof/v1"
REFERENCE_GRAPH_SCHEMA = "kakyu_mes_reference_graph/v1"
CONDITIONAL_EDGE_KINDS = {
    "condition_true_fallthrough",
    "condition_false_target",
}
CONTINUATION_EDGE_KIND = "continuation_target"


class ControlFlowProofError(ValueError):
    pass


def prove(linear_ir: dict[str, Any]) -> dict[str, Any]:
    decompiler.validate(linear_ir)
    nodes = linear_ir["nodes"]
    linear_by_id = {str(node["id"]): node for node in nodes}
    linear_by_graph_id: dict[tuple[int, str], dict[str, Any]] = {}
    for node in nodes:
        for link in node.get("cfg_nodes", []):
            key = (int(link["graph_index"]), str(link["node_id"]))
            if key in linear_by_graph_id:
                raise ControlFlowProofError("multiple linear nodes own one CFG node")
            linear_by_graph_id[key] = node

    graphs: list[dict[str, Any]] = []
    total_graph_nodes = 0
    total_graph_edges = 0
    total_proven_edges = 0
    total_unresolved = 0
    total_boundaries = 0
    for graph_index, graph in enumerate(linear_ir["analysis_evidence"]["control_flow"]):
        projection = _prove_graph(graph_index, graph, linear_by_graph_id)
        graphs.append(projection)
        total_graph_nodes += int(projection["coverage"]["graph_node_count"])
        total_graph_edges += int(projection["coverage"]["graph_edge_count"])
        total_proven_edges += int(projection["coverage"]["proven_edge_count"])
        total_unresolved += int(projection["coverage"]["unresolved_construct_count"])
        total_boundaries += int(projection["coverage"]["boundary_anchor_count"])

    document = {
        "ok": True,
        "schema": CONTROL_FLOW_PROOF_SCHEMA,
        "producer": {
            "implementation": "python_phase5_control_flow_prover",
            "contract": CONTROL_FLOW_PROOF_SCHEMA,
        },
        "compatibility": {
            "policy": "exact_linear_ir_schema_match",
            "input_decompiler_schema": decompiler.DECOMPILER_IR_SCHEMA,
            "input_reference_graph_schema": REFERENCE_GRAPH_SCHEMA,
            "unknown_proof_schema": "reject",
            "unknown_v1_field": "ignore",
            "unproved_transfer_policy": "explicit_unresolved_construct",
        },
        "input_decompiler": {
            "schema": decompiler.DECOMPILER_IR_SCHEMA,
            "payload_sha256": linear_ir["payload_sha256"],
        },
        "source_identity": copy.deepcopy(linear_ir.get("source_identity", {})),
        "graphs": graphs,
        "coverage": {
            "graph_count": len(graphs),
            "graph_node_count": total_graph_nodes,
            "graph_edge_count": total_graph_edges,
            "proven_edge_count": total_proven_edges,
            "unresolved_construct_count": total_unresolved,
            "boundary_anchor_count": total_boundaries,
            "all_graph_edges_accounted": total_graph_edges
            == sum(
                len(construct["edge_indices"])
                for graph in graphs
                for construct in graph["constructs"]
            ),
        },
    }
    document["payload_sha256"] = fingerprint(document)
    validate(document)
    if any(node_id not in linear_by_id for node_id in _linear_node_ids(document)):
        raise ControlFlowProofError("control-flow proof lost its linear source owner")
    return document


def validate(document: dict[str, Any]) -> dict[str, Any]:
    if document.get("schema") != CONTROL_FLOW_PROOF_SCHEMA:
        raise ControlFlowProofError("unsupported MES control-flow proof schema")
    compatibility = document.get("compatibility")
    if not isinstance(compatibility, dict):
        raise ControlFlowProofError("missing control-flow proof compatibility contract")
    if compatibility.get("input_decompiler_schema") != decompiler.DECOMPILER_IR_SCHEMA:
        raise ControlFlowProofError("unsupported control-flow proof input schema")
    if compatibility.get("input_reference_graph_schema") != REFERENCE_GRAPH_SCHEMA:
        raise ControlFlowProofError("unsupported control-flow proof graph schema")
    input_decompiler = document.get("input_decompiler")
    if (
        not isinstance(input_decompiler, dict)
        or input_decompiler.get("schema") != decompiler.DECOMPILER_IR_SCHEMA
        or not isinstance(input_decompiler.get("payload_sha256"), str)
        or len(input_decompiler["payload_sha256"]) != 64
    ):
        raise ControlFlowProofError("control-flow proof input identity is missing")
    retained = document.get("payload_sha256")
    if not isinstance(retained, str) or len(retained) != 64:
        raise ControlFlowProofError("missing MES control-flow proof fingerprint")
    if fingerprint(document) != retained:
        raise ControlFlowProofError("MES control-flow proof fingerprint changed")

    graphs = document.get("graphs")
    if not isinstance(graphs, list):
        raise ControlFlowProofError("control-flow proof graphs are missing")
    total_nodes = 0
    total_edges = 0
    total_proven = 0
    total_unresolved = 0
    total_boundaries = 0
    all_edges_accounted = True
    for expected_index, projection in enumerate(graphs):
        if not isinstance(projection, dict) or int(projection.get("graph_index", -1)) != expected_index:
            raise ControlFlowProofError("control-flow proof graph index changed")
        source_graph = projection.get("source_graph")
        constructs = projection.get("constructs")
        graph_coverage = projection.get("coverage")
        if (
            not isinstance(source_graph, dict)
            or source_graph.get("schema") != REFERENCE_GRAPH_SCHEMA
            or not isinstance(constructs, list)
            or not isinstance(graph_coverage, dict)
        ):
            raise ControlFlowProofError("control-flow proof graph payload is incomplete")
        graph_nodes = source_graph.get("nodes", [])
        graph_edges = source_graph.get("edges", [])
        node_by_id = {
            str(node.get("id", "")): node
            for node in graph_nodes
            if isinstance(node, dict)
        }
        if len(node_by_id) != len(graph_nodes) or "" in node_by_id:
            raise ControlFlowProofError("control-flow proof graph node identity changed")
        edge_indices: list[int] = []
        proven_indices: list[int] = []
        construct_ids: set[str] = set()
        construct_source_ids: set[str] = set()
        unresolved_count = 0
        boundary_count = 0
        for construct in constructs:
            if not isinstance(construct, dict):
                raise ControlFlowProofError("control-flow construct is not an object")
            construct_id = str(construct.get("id", ""))
            if not construct_id or construct_id in construct_ids:
                raise ControlFlowProofError("control-flow construct identity changed")
            construct_ids.add(construct_id)
            source_graph_node_id = str(construct.get("source_graph_node_id", ""))
            if source_graph_node_id not in node_by_id:
                raise ControlFlowProofError("control-flow construct lost its graph source")
            if source_graph_node_id in construct_source_ids:
                raise ControlFlowProofError("graph node owns multiple control-flow constructs")
            construct_source_ids.add(source_graph_node_id)
            source_snapshot = construct.get("source_node")
            if not isinstance(source_snapshot, dict):
                raise ControlFlowProofError("control-flow construct lost its linear source")
            if int(source_snapshot.get("source", {}).get("start", -1)) != int(
                node_by_id[source_graph_node_id].get("offset", -2)
            ):
                raise ControlFlowProofError("control-flow construct source offset changed")
            indices = construct.get("edge_indices")
            if not isinstance(indices, list) or any(
                not isinstance(index, int) or index < 0 or index >= len(graph_edges)
                for index in indices
            ):
                raise ControlFlowProofError("control-flow construct edge ownership changed")
            edge_indices.extend(indices)
            kind = str(construct.get("kind", ""))
            if kind == "conditional_branch":
                _validate_conditional_construct(construct, graph_edges, node_by_id)
                proven_indices.extend(indices)
            elif kind == "continuation_transfer":
                _validate_continuation_construct(construct, graph_edges, node_by_id)
                proven_indices.extend(indices)
            elif kind == "boundary_anchor":
                if indices:
                    raise ControlFlowProofError("boundary anchor owns transfer edges")
                boundary_count += 1
            elif kind == "graph_anchor":
                if indices:
                    raise ControlFlowProofError("graph anchor owns transfer edges")
            elif kind == "unresolved_transfer":
                if not indices or not str(construct.get("reason", "")):
                    raise ControlFlowProofError("unresolved transfer is not explicit")
                unresolved_count += 1
            elif kind == "unexpanded_transfer_anchor":
                if indices or not str(construct.get("reason", "")):
                    raise ControlFlowProofError("unexpanded transfer anchor is not explicit")
                unresolved_count += 1
            else:
                raise ControlFlowProofError("unsupported control-flow construct kind")
        if construct_source_ids != set(node_by_id):
            raise ControlFlowProofError("control-flow construct coverage is incomplete")
        if sorted(edge_indices) != list(range(len(graph_edges))):
            all_edges_accounted = False
            raise ControlFlowProofError("control-flow proof edge coverage is incomplete")
        bounded_complete = (
            not bool(source_graph.get("truncated", False))
            and int(source_graph.get("skipped_references", 0)) == 0
            and int(source_graph.get("skipped_stops", 0)) == 0
            and not source_graph.get("skipped_expansion_regions", [])
        )
        if bool(projection.get("bounded_complete", False)) != bounded_complete:
            raise ControlFlowProofError("bounded graph completeness changed")
        if (
            int(graph_coverage.get("graph_node_count", -1)) != len(graph_nodes)
            or int(graph_coverage.get("graph_edge_count", -1)) != len(graph_edges)
            or int(graph_coverage.get("proven_edge_count", -1)) != len(proven_indices)
            or int(graph_coverage.get("unresolved_construct_count", -1)) != unresolved_count
            or int(graph_coverage.get("boundary_anchor_count", -1)) != boundary_count
            or graph_coverage.get("all_edges_accounted") is not True
        ):
            raise ControlFlowProofError("control-flow graph coverage counts changed")
        total_nodes += len(graph_nodes)
        total_edges += len(graph_edges)
        total_proven += len(proven_indices)
        total_unresolved += unresolved_count
        total_boundaries += boundary_count

    coverage = document.get("coverage")
    if not isinstance(coverage, dict):
        raise ControlFlowProofError("control-flow proof coverage is missing")
    if (
        int(coverage.get("graph_count", -1)) != len(graphs)
        or int(coverage.get("graph_node_count", -1)) != total_nodes
        or int(coverage.get("graph_edge_count", -1)) != total_edges
        or int(coverage.get("proven_edge_count", -1)) != total_proven
        or int(coverage.get("unresolved_construct_count", -1)) != total_unresolved
        or int(coverage.get("boundary_anchor_count", -1)) != total_boundaries
        or coverage.get("all_graph_edges_accounted") is not all_edges_accounted
    ):
        raise ControlFlowProofError("control-flow proof aggregate coverage changed")
    return {"ok": True, "schema": CONTROL_FLOW_PROOF_SCHEMA, "payload_sha256": retained}


def _prove_graph(
    graph_index: int,
    graph: dict[str, Any],
    linear_by_graph_id: dict[tuple[int, str], dict[str, Any]],
) -> dict[str, Any]:
    if not isinstance(graph, dict) or graph.get("schema") != REFERENCE_GRAPH_SCHEMA:
        raise ControlFlowProofError("input reference graph schema changed")
    graph_nodes = graph.get("nodes")
    graph_edges = graph.get("edges")
    if not isinstance(graph_nodes, list) or not isinstance(graph_edges, list):
        raise ControlFlowProofError("input reference graph arrays are missing")
    node_by_id = {
        str(node.get("id", "")): node
        for node in graph_nodes
        if isinstance(node, dict)
    }
    if len(node_by_id) != len(graph_nodes) or "" in node_by_id:
        raise ControlFlowProofError("input reference graph node identity changed")
    outgoing: dict[str, list[tuple[int, dict[str, Any]]]] = {}
    for edge_index, edge in enumerate(graph_edges):
        if not isinstance(edge, dict):
            raise ControlFlowProofError("input reference graph edge is not an object")
        source_id = str(edge.get("from_id", ""))
        target_id = str(edge.get("to_id", ""))
        if source_id not in node_by_id or target_id not in node_by_id:
            raise ControlFlowProofError("input reference graph contains a dangling edge")
        outgoing.setdefault(source_id, []).append((edge_index, edge))

    constructs: list[dict[str, Any]] = []
    proven_edge_count = 0
    unresolved_count = 0
    boundary_count = 0
    for graph_node in sorted(
        graph_nodes,
        key=lambda node: (int(node.get("offset", -1)), str(node.get("id", ""))),
    ):
        graph_node_id = str(graph_node["id"])
        source_node = linear_by_graph_id.get((graph_index, graph_node_id))
        edges = outgoing.get(graph_node_id, [])
        construct = _prove_node(graph_index, graph_node, source_node, edges, node_by_id)
        constructs.append(construct)
        if construct["kind"] in {"conditional_branch", "continuation_transfer"}:
            proven_edge_count += len(construct["edge_indices"])
        elif construct["kind"] in {"unresolved_transfer", "unexpanded_transfer_anchor"}:
            unresolved_count += 1
        elif construct["kind"] == "boundary_anchor":
            boundary_count += 1

    bounded_complete = (
        not bool(graph.get("truncated", False))
        and int(graph.get("skipped_references", 0)) == 0
        and int(graph.get("skipped_stops", 0)) == 0
        and not graph.get("skipped_expansion_regions", [])
    )
    return {
        "graph_index": graph_index,
        "bounded_complete": bounded_complete,
        "source_graph": copy.deepcopy(graph),
        "constructs": constructs,
        "coverage": {
            "graph_node_count": len(graph_nodes),
            "graph_edge_count": len(graph_edges),
            "proven_edge_count": proven_edge_count,
            "unresolved_construct_count": unresolved_count,
            "boundary_anchor_count": boundary_count,
            "all_edges_accounted": sum(len(row["edge_indices"]) for row in constructs)
            == len(graph_edges),
        },
    }


def _prove_node(
    graph_index: int,
    graph_node: dict[str, Any],
    source_node: dict[str, Any] | None,
    outgoing: list[tuple[int, dict[str, Any]]],
    node_by_id: dict[str, dict[str, Any]],
) -> dict[str, Any]:
    source_graph_node_id = str(graph_node["id"])
    base = {
        "id": f"graph_{graph_index:04d}_{source_graph_node_id}",
        "source_graph_node_id": source_graph_node_id,
        "source_node": _source_snapshot(source_node, graph_node),
        "edge_indices": [index for index, _edge in outgoing],
    }
    if source_node is None:
        if outgoing:
            return {
                **base,
                "kind": "unresolved_transfer",
                "reason": "graph_node_has_no_linear_source_owner",
            }
        return {**base, "kind": "boundary_anchor", "boundary": "unmapped_graph_node"}

    statement = source_node["statement"]
    op = str(statement.get("op", ""))
    if op == "branch_if_not_true":
        if not outgoing:
            return {
                **base,
                "kind": "unexpanded_transfer_anchor",
                "reason": "outgoing_edges_not_supplied_by_bounded_graph",
            }
        proof = _conditional_proof(source_node, outgoing, node_by_id)
        if proof is not None:
            return {**base, **proof}
        return {
            **base,
            "kind": "unresolved_transfer",
            "reason": "conditional_shape_or_target_not_proven",
        }
    if op == "continuation_transfer":
        if not outgoing:
            return {
                **base,
                "kind": "unexpanded_transfer_anchor",
                "reason": "outgoing_edges_not_supplied_by_bounded_graph",
            }
        proof = _continuation_proof(source_node, outgoing, node_by_id)
        if proof is not None:
            return {**base, **proof}
        return {
            **base,
            "kind": "unresolved_transfer",
            "reason": "continuation_shape_or_target_not_proven",
        }
    if outgoing:
        return {
            **base,
            "kind": "unresolved_transfer",
            "reason": "graph_edges_not_supported_for_source_op",
        }
    if source_node["kind"] == "opaque" or str(graph_node.get("status", "")) == "stop":
        return {**base, "kind": "boundary_anchor", "boundary": source_node["evidence_status"]}
    return {**base, "kind": "graph_anchor"}


def _conditional_proof(
    source_node: dict[str, Any],
    outgoing: list[tuple[int, dict[str, Any]]],
    node_by_id: dict[str, dict[str, Any]],
) -> dict[str, Any] | None:
    if len(outgoing) != 2:
        return None
    edges_by_kind = {str(edge.get("kind", "")): (index, edge) for index, edge in outgoing}
    if set(edges_by_kind) != CONDITIONAL_EDGE_KINDS:
        return None
    if any(edge.get("confirmed_flow") is not True for _index, edge in outgoing):
        return None
    condition = _operand_value(source_node["statement"], "condition")
    false_operand = _operand_value(source_node["statement"], "code_offset")
    if not isinstance(condition, dict) or not isinstance(condition.get("ast"), dict):
        return None
    if not isinstance(false_operand, int):
        return None
    true_index, true_edge = edges_by_kind["condition_true_fallthrough"]
    false_index, false_edge = edges_by_kind["condition_false_target"]
    true_target = node_by_id[str(true_edge["to_id"])]
    false_target = node_by_id[str(false_edge["to_id"])]
    if (
        int(true_target.get("offset", -1)) != int(source_node["source"]["end"])
        or int(false_target.get("offset", -1)) != false_operand
    ):
        return None
    return {
        "kind": "conditional_branch",
        "condition": copy.deepcopy(condition),
        "true_target": _target_snapshot(true_edge, true_target),
        "false_target": _target_snapshot(false_edge, false_target),
        "edge_indices": [true_index, false_index],
        "proof": {
            "status": "confirmed_flow_bounded",
            "requirements": [
                "exact_branch_if_not_true_statement",
                "condition_ast_retained",
                "true_target_equals_instruction_end",
                "false_target_equals_code_offset_operand",
                "both_reference_graph_edges_confirmed",
            ],
        },
    }


def _continuation_proof(
    source_node: dict[str, Any],
    outgoing: list[tuple[int, dict[str, Any]]],
    node_by_id: dict[str, dict[str, Any]],
) -> dict[str, Any] | None:
    if len(outgoing) != 1:
        return None
    edge_index, edge = outgoing[0]
    target_operand = _operand_value(source_node["statement"], "code_offset")
    if (
        edge.get("kind") != CONTINUATION_EDGE_KIND
        or edge.get("confirmed_flow") is not True
        or not isinstance(target_operand, int)
    ):
        return None
    target = node_by_id[str(edge["to_id"])]
    if int(target.get("offset", -1)) != target_operand:
        return None
    return {
        "kind": "continuation_transfer",
        "target": _target_snapshot(edge, target),
        "edge_indices": [edge_index],
        "proof": {
            "status": "confirmed_flow_bounded",
            "requirements": [
                "exact_continuation_transfer_statement",
                "target_equals_code_offset_operand",
                "reference_graph_edge_confirmed",
            ],
        },
    }


def _validate_conditional_construct(
    construct: dict[str, Any],
    graph_edges: list[dict[str, Any]],
    node_by_id: dict[str, dict[str, Any]],
) -> None:
    source_node = construct["source_node"]
    outgoing = [(index, graph_edges[index]) for index in construct["edge_indices"]]
    expected = _conditional_proof(source_node, outgoing, node_by_id)
    if expected is None:
        raise ControlFlowProofError("conditional proof no longer satisfies its evidence")
    for key in ("condition", "true_target", "false_target", "proof"):
        if construct.get(key) != expected[key]:
            raise ControlFlowProofError("conditional proof payload changed")


def _validate_continuation_construct(
    construct: dict[str, Any],
    graph_edges: list[dict[str, Any]],
    node_by_id: dict[str, dict[str, Any]],
) -> None:
    source_node = construct["source_node"]
    outgoing = [(index, graph_edges[index]) for index in construct["edge_indices"]]
    expected = _continuation_proof(source_node, outgoing, node_by_id)
    if expected is None:
        raise ControlFlowProofError("continuation proof no longer satisfies its evidence")
    for key in ("target", "proof"):
        if construct.get(key) != expected[key]:
            raise ControlFlowProofError("continuation proof payload changed")


def _operand_value(statement: dict[str, Any], operand_type: str) -> Any:
    for operand in statement.get("operands", []):
        if isinstance(operand, dict) and operand.get("type") == operand_type:
            return operand.get("value")
    return None


def _source_snapshot(
    source_node: dict[str, Any] | None,
    graph_node: dict[str, Any],
) -> dict[str, Any]:
    if source_node is None:
        return {
            "id": "",
            "kind": "unmapped",
            "source": {
                "entry": "",
                "region": str(graph_node.get("region", "")),
                "start": int(graph_node.get("offset", -1)),
                "end": int(graph_node.get("offset", -1)),
                "raw_hex": "",
                "raw_sha256": "",
            },
            "evidence_status": str(graph_node.get("status", "unresolved")),
            "statement": {"kind": "unmapped"},
        }
    return {
        "id": str(source_node["id"]),
        "kind": str(source_node["kind"]),
        "source": copy.deepcopy(source_node["source"]),
        "evidence_status": str(source_node["evidence_status"]),
        "statement": copy.deepcopy(source_node["statement"]),
    }


def _target_snapshot(edge: dict[str, Any], graph_node: dict[str, Any]) -> dict[str, Any]:
    return {
        "graph_node_id": str(edge["to_id"]),
        "offset": int(graph_node.get("offset", -1)),
        "region": str(graph_node.get("region", "")),
        "status": str(graph_node.get("status", "")),
    }


def _linear_node_ids(document: dict[str, Any]) -> list[str]:
    return [
        str(construct["source_node"]["id"])
        for graph in document["graphs"]
        for construct in graph["constructs"]
        if str(construct["source_node"].get("id", ""))
    ]


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Prove bounded MES conditional and continuation transfers from linear decompiler IR."
    )
    parser.add_argument("linear_ir", type=Path)
    parser.add_argument("output", type=Path, nargs="?")
    args = parser.parse_args()
    with args.linear_ir.open("r", encoding="utf-8") as stream:
        linear_ir = json.load(stream)
    document = prove(linear_ir)
    encoded = json.dumps(
        document,
        ensure_ascii=False,
        allow_nan=False,
        sort_keys=True,
        separators=(",", ":"),
    )
    if args.output is not None:
        if args.output.resolve() == args.linear_ir.resolve():
            raise ControlFlowProofError("control-flow output must not replace its input IR")
        args.output.write_text(encoded + "\n", encoding="utf-8")
    print(
        "MES_CONTROL_FLOW_PROOF_PASS "
        f"schema={document['schema']} entry={document['source_identity'].get('entry', '')} "
        f"graphs={document['coverage']['graph_count']} edges={document['coverage']['graph_edge_count']} "
        f"proven={document['coverage']['proven_edge_count']} "
        f"unresolved={document['coverage']['unresolved_construct_count']} "
        f"payload_sha256={document['payload_sha256']}"
    )


if __name__ == "__main__":
    main()
