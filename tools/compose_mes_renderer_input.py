from __future__ import annotations

import argparse
import copy
import json
from pathlib import Path
from typing import Any

import annotate_mes_decompiler as semantic_annotations
import decompile_mes_handoff as decompiler
import prove_mes_control_flow as flow_proof
import prove_mes_if_regions as region_proof
from payload_values import canonical_payload_bytes, fingerprint


RENDERER_INPUT_SCHEMA = "kakyu_mes_renderer_input/v1"


class RendererInputError(ValueError):
    pass


def compose(
    linear_ir: dict[str, Any],
    annotations: dict[str, Any],
    transfer_proof: dict[str, Any],
    conditional_proof: dict[str, Any],
) -> dict[str, Any]:
    _validate_inputs(linear_ir, annotations, transfer_proof, conditional_proof)
    document = _build(linear_ir, annotations, transfer_proof, conditional_proof)
    document["payload_sha256"] = fingerprint(document)
    validate(document, linear_ir, annotations, transfer_proof, conditional_proof)
    return document


def validate(
    document: dict[str, Any],
    linear_ir: dict[str, Any],
    annotations: dict[str, Any],
    transfer_proof: dict[str, Any],
    conditional_proof: dict[str, Any],
) -> dict[str, Any]:
    if document.get("schema") != RENDERER_INPUT_SCHEMA:
        raise RendererInputError("unsupported MES renderer-input schema")
    retained = document.get("payload_sha256")
    if (
        not isinstance(retained, str)
        or len(retained) != 64
        or fingerprint(document) != retained
    ):
        raise RendererInputError("MES renderer-input fingerprint changed")
    _validate_inputs(linear_ir, annotations, transfer_proof, conditional_proof)
    expected = _build(linear_ir, annotations, transfer_proof, conditional_proof)
    actual = dict(document)
    actual.pop("payload_sha256", None)
    if actual != expected:
        raise RendererInputError("MES renderer-input projection changed")
    return {
        "ok": True,
        "schema": RENDERER_INPUT_SCHEMA,
        "payload_sha256": retained,
    }


def _validate_inputs(
    linear_ir: dict[str, Any],
    annotations: dict[str, Any],
    transfer_proof: dict[str, Any],
    conditional_proof: dict[str, Any],
) -> None:
    decompiler.validate(linear_ir)
    semantic_annotations.validate(annotations, linear_ir)
    flow_proof.validate(transfer_proof)
    if (
        transfer_proof.get("input_decompiler", {}).get("payload_sha256")
        != linear_ir["payload_sha256"]
    ):
        raise RendererInputError("control-flow proof belongs to another linear IR")
    region_proof.validate(conditional_proof, linear_ir, transfer_proof)
    source_identity = linear_ir.get("source_identity", {})
    for name, candidate in (
        ("semantic annotation", annotations),
        ("control-flow proof", transfer_proof),
        ("conditional proof", conditional_proof),
    ):
        if candidate.get("source_identity", {}) != source_identity:
            raise RendererInputError(f"{name} source identity changed")


def _build(
    linear_ir: dict[str, Any],
    annotations: dict[str, Any],
    transfer_proof: dict[str, Any],
    conditional_proof: dict[str, Any],
) -> dict[str, Any]:
    linear_nodes = linear_ir["nodes"]
    node_by_id = {str(node["id"]): node for node in linear_nodes}
    annotation_by_node = {
        str(annotation["linear_node_id"]): annotation
        for annotation in annotations["nodes"]
    }
    if set(annotation_by_node) != set(node_by_id):
        raise RendererInputError("semantic annotation node coverage changed")

    fallback_control = conditional_proof["fallback_control"]
    control_locations = _control_locations(fallback_control, node_by_id)
    structures = _conditional_structures(
        conditional_proof, fallback_control, node_by_id
    )
    structure_ids_by_node: dict[str, list[str]] = {
        node_id: [] for node_id in node_by_id
    }
    for structure in structures:
        for node_id in structure["member_linear_node_ids"]:
            structure_ids_by_node[node_id].append(str(structure["id"]))

    source_map = []
    for node in linear_nodes:
        node_id = str(node["id"])
        source_map.append(
            {
                "linear_node_id": node_id,
                "annotation_id": str(annotation_by_node[node_id]["id"]),
                "source": copy.deepcopy(node["source"]),
                "control_locations": control_locations[node_id],
                "structure_ids": sorted(structure_ids_by_node[node_id]),
            }
        )

    mapped_control_count = sum(bool(row["control_locations"]) for row in source_map)
    return {
        "ok": True,
        "schema": RENDERER_INPUT_SCHEMA,
        "producer": {
            "implementation": "python_phase5_renderer_input_composer",
            "contract": RENDERER_INPUT_SCHEMA,
        },
        "compatibility": {
            "policy": "exact_linear_annotation_flow_and_region_match",
            "input_decompiler_schema": decompiler.DECOMPILER_IR_SCHEMA,
            "input_annotation_schema": semantic_annotations.SEMANTIC_ANNOTATION_SCHEMA,
            "input_flow_proof_schema": flow_proof.CONTROL_FLOW_PROOF_SCHEMA,
            "input_region_proof_schema": region_proof.REDUCIBLE_REGION_PROOF_SCHEMA,
            "unknown_renderer_schema": "reject",
            "unknown_v1_field": "reject",
            "fallback_policy": "retain_complete_low_level_labels_and_gotos",
            "structure_policy": "only_reducible_if_regions_proven_by_input",
            "semantic_alias_policy": "retain_unresolved_source_annotations",
        },
        "inputs": {
            "linear_ir_sha256": linear_ir["payload_sha256"],
            "semantic_annotation_sha256": annotations["payload_sha256"],
            "flow_proof_sha256": transfer_proof["payload_sha256"],
            "region_proof_sha256": conditional_proof["payload_sha256"],
            "fallback_control_sha256": fallback_control["payload_sha256"],
        },
        "source_identity": copy.deepcopy(linear_ir.get("source_identity", {})),
        "program": {
            "regions": copy.deepcopy(linear_ir["regions"]),
            "nodes": copy.deepcopy(linear_nodes),
            "references": copy.deepcopy(linear_ir["references"]),
        },
        "semantic_annotations": {
            "unresolved_semantic_categories": copy.deepcopy(
                annotations["unresolved_semantic_categories"]
            ),
            "nodes": copy.deepcopy(annotations["nodes"]),
            "symbols": copy.deepcopy(annotations["symbols"]),
        },
        "fallback_control": copy.deepcopy(fallback_control),
        "conditional_structures": structures,
        "source_map": source_map,
        "coverage": {
            "linear_node_count": len(linear_nodes),
            "source_mapped_node_count": len(source_map),
            "control_mapped_node_count": mapped_control_count,
            "control_unmapped_node_count": len(source_map) - mapped_control_count,
            "symbol_count": len(annotations["symbols"]),
            "if_then_structure_count": sum(
                row["kind"] == "if_then" for row in structures
            ),
            "if_else_structure_count": sum(
                row["kind"] == "if_else" for row in structures
            ),
            "all_linear_nodes_source_mapped": len(source_map) == len(linear_nodes),
            "all_structures_source_reversible": all(
                bool(row["member_linear_node_ids"]) for row in structures
            ),
            "complete_low_level_fallback_retained": True,
        },
    }


def _control_locations(
    fallback_control: dict[str, Any],
    node_by_id: dict[str, dict[str, Any]],
) -> dict[str, list[dict[str, Any]]]:
    locations: dict[str, list[dict[str, Any]]] = {
        node_id: [] for node_id in node_by_id
    }
    for graph in fallback_control["graphs"]:
        graph_index = int(graph["graph_index"])
        for statement in graph["statements"]:
            node_id = str(statement.get("source_node", {}).get("id", ""))
            if not node_id:
                continue
            if node_id not in locations:
                raise RendererInputError("fallback control references an unknown node")
            locations[node_id].append(
                {
                    "graph_index": graph_index,
                    "label": str(statement["label"]),
                    "statement_id": str(statement["id"]),
                    "statement_kind": str(statement["kind"]),
                }
            )
    for rows in locations.values():
        rows.sort(
            key=lambda row: (
                int(row["graph_index"]),
                str(row["label"]),
                str(row["statement_id"]),
            )
        )
    return locations


def _conditional_structures(
    conditional_proof: dict[str, Any],
    fallback_control: dict[str, Any],
    node_by_id: dict[str, dict[str, Any]],
) -> list[dict[str, Any]]:
    structures: list[dict[str, Any]] = []
    fallback_graphs = fallback_control["graphs"]
    for index, graph in enumerate(conditional_proof["graphs"]):
        graph_index = int(graph["graph_index"])
        if graph_index != int(fallback_graphs[index]["graph_index"]):
            raise RendererInputError("conditional and fallback graph order changed")
        statements_by_label = {
            str(row["label"]): row for row in fallback_graphs[index]["statements"]
        }
        for key in ("if_then_regions", "if_else_regions"):
            for proof_row in graph[key]:
                source_label = str(proof_row["source_label"])
                source_statement = statements_by_label.get(source_label)
                if source_statement is None:
                    raise RendererInputError("conditional source label is missing")
                source_node_id = str(
                    source_statement.get("source_node", {}).get("id", "")
                )
                member_ids = [source_node_id]
                if proof_row["kind"] == "if_then":
                    member_ids.extend(
                        str(value) for value in proof_row["body_linear_node_ids"]
                    )
                else:
                    member_ids.extend(
                        str(value) for value in proof_row["then_linear_node_ids"]
                    )
                    member_ids.extend(
                        str(value) for value in proof_row["else_linear_node_ids"]
                    )
                member_ids = list(dict.fromkeys(member_ids))
                if not member_ids or any(value not in node_by_id for value in member_ids):
                    raise RendererInputError(
                        "conditional structure references an unknown linear node"
                    )
                proof_id = str(proof_row["id"])
                structures.append(
                    {
                        "id": f"structure_{graph_index:04d}_{proof_id}",
                        "proof_id": proof_id,
                        "kind": str(proof_row["kind"]),
                        "graph_index": graph_index,
                        "source_label": source_label,
                        "source_linear_node_id": source_node_id,
                        "member_linear_node_ids": member_ids,
                        "join_label": str(proof_row["join_label"]),
                        "proof_status": str(proof_row["proof_status"]),
                        "proof": copy.deepcopy(proof_row),
                    }
                )
    structures.sort(
        key=lambda row: (
            int(row["graph_index"]),
            int(row["proof"].get("source_start", -1)),
            str(row["id"]),
        )
    )
    return structures


def main() -> None:
    parser = argparse.ArgumentParser(
        description=(
            "Compose validated linear, semantic, low-level control, and "
            "reducible-if MES layers into one source-reversible renderer input."
        )
    )
    parser.add_argument("linear_ir", type=Path)
    parser.add_argument("semantic_annotations", type=Path)
    parser.add_argument("flow_proof", type=Path)
    parser.add_argument("region_proof", type=Path)
    parser.add_argument("output", type=Path, nargs="?")
    args = parser.parse_args()
    input_paths = (
        args.linear_ir,
        args.semantic_annotations,
        args.flow_proof,
        args.region_proof,
    )
    documents = [
        json.loads(path.read_text(encoding="utf-8")) for path in input_paths
    ]
    document = compose(*documents)
    encoded = json.dumps(
        document,
        ensure_ascii=False,
        allow_nan=False,
        sort_keys=True,
        separators=(",", ":"),
    )
    if args.output is not None:
        if args.output.resolve() in {path.resolve() for path in input_paths}:
            raise RendererInputError("renderer output must not replace an input")
        args.output.write_text(encoded + "\n", encoding="utf-8")
    print(
        "MES_RENDERER_INPUT_PASS "
        f"schema={document['schema']} entry={document['source_identity'].get('entry', '')} "
        f"nodes={document['coverage']['linear_node_count']} "
        f"structures={len(document['conditional_structures'])} "
        f"payload_sha256={document['payload_sha256']}"
    )


if __name__ == "__main__":
    main()
