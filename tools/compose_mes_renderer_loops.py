from __future__ import annotations

import argparse
import copy
import json
from pathlib import Path
from typing import Any

import compose_mes_renderer_overlays as overlay_composer
import prove_mes_execution_fallthroughs as execution_proof
import prove_mes_natural_loops as loop_proof
import prove_mes_shared_call_returns as shared_call_proof
from payload_values import canonical_payload_bytes, fingerprint


RENDERER_INPUT_SCHEMA = "kakyu_mes_renderer_input/v3"


class RendererLoopError(ValueError):
    pass


def compose(
    linear_ir: dict[str, Any],
    annotations: dict[str, Any],
    transfer_proof: dict[str, Any],
    conditional_proof: dict[str, Any],
    guard_chains: dict[str, Any],
    value_dispatches: dict[str, Any],
    predicate_dispatches: dict[str, Any],
    cross_region_joins: dict[str, Any],
    call_families: dict[str, Any],
    library_audit: dict[str, Any],
    shared_calls: dict[str, Any],
    execution_fallthroughs: dict[str, Any],
    natural_loops: dict[str, Any],
) -> dict[str, Any]:
    inputs = (
        linear_ir,
        annotations,
        transfer_proof,
        conditional_proof,
        guard_chains,
        value_dispatches,
        predicate_dispatches,
        cross_region_joins,
        call_families,
        library_audit,
        shared_calls,
        execution_fallthroughs,
        natural_loops,
    )
    overlay_input = _validate_inputs(*inputs)
    document = _build(overlay_input, *inputs)
    document["payload_sha256"] = fingerprint(document)
    validate(document, *inputs)
    return document


def validate(
    document: dict[str, Any],
    linear_ir: dict[str, Any],
    annotations: dict[str, Any],
    transfer_proof: dict[str, Any],
    conditional_proof: dict[str, Any],
    guard_chains: dict[str, Any],
    value_dispatches: dict[str, Any],
    predicate_dispatches: dict[str, Any],
    cross_region_joins: dict[str, Any],
    call_families: dict[str, Any],
    library_audit: dict[str, Any],
    shared_calls: dict[str, Any],
    execution_fallthroughs: dict[str, Any],
    natural_loops: dict[str, Any],
) -> dict[str, Any]:
    if document.get("schema") != RENDERER_INPUT_SCHEMA:
        raise RendererLoopError("unsupported MES renderer loop schema")
    retained = document.get("payload_sha256")
    if (
        not isinstance(retained, str)
        or len(retained) != 64
        or fingerprint(document) != retained
    ):
        raise RendererLoopError("MES renderer loop fingerprint changed")
    inputs = (
        linear_ir,
        annotations,
        transfer_proof,
        conditional_proof,
        guard_chains,
        value_dispatches,
        predicate_dispatches,
        cross_region_joins,
        call_families,
        library_audit,
        shared_calls,
        execution_fallthroughs,
        natural_loops,
    )
    overlay_input = _validate_inputs(*inputs)
    expected = _build(overlay_input, *inputs)
    actual = dict(document)
    actual.pop("payload_sha256", None)
    if actual != expected:
        raise RendererLoopError("MES renderer loop projection changed")
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
    guard_chains: dict[str, Any],
    value_dispatches: dict[str, Any],
    predicate_dispatches: dict[str, Any],
    cross_region_joins: dict[str, Any],
    call_families: dict[str, Any],
    library_audit: dict[str, Any],
    shared_calls: dict[str, Any],
    execution_fallthroughs: dict[str, Any],
    natural_loops: dict[str, Any],
) -> dict[str, Any]:
    overlay_input = overlay_composer.compose(
        linear_ir,
        annotations,
        transfer_proof,
        conditional_proof,
        guard_chains,
        value_dispatches,
        predicate_dispatches,
        cross_region_joins,
        call_families,
    )
    shared_call_proof.validate(shared_calls, linear_ir, library_audit)
    execution_proof.validate(
        execution_fallthroughs,
        linear_ir,
        transfer_proof,
        shared_calls,
        library_audit,
    )
    loop_proof.validate(
        natural_loops,
        linear_ir,
        transfer_proof,
        conditional_proof,
        execution_fallthroughs,
        shared_calls,
        library_audit,
    )
    source_identity = linear_ir.get("source_identity", {})
    for name, candidate in (
        ("shared-call proof", shared_calls),
        ("execution-fallthrough proof", execution_fallthroughs),
        ("natural-loop proof", natural_loops),
    ):
        if candidate.get("source_identity", {}) != source_identity:
            raise RendererLoopError(f"{name} source identity changed")
    return overlay_input


def _build(
    overlay_input: dict[str, Any],
    linear_ir: dict[str, Any],
    annotations: dict[str, Any],
    transfer_proof: dict[str, Any],
    conditional_proof: dict[str, Any],
    guard_chains: dict[str, Any],
    value_dispatches: dict[str, Any],
    predicate_dispatches: dict[str, Any],
    cross_region_joins: dict[str, Any],
    call_families: dict[str, Any],
    library_audit: dict[str, Any],
    shared_calls: dict[str, Any],
    execution_fallthroughs: dict[str, Any],
    natural_loops: dict[str, Any],
) -> dict[str, Any]:
    document = copy.deepcopy(overlay_input)
    overlay_sha256 = str(document.pop("payload_sha256"))
    library_sha256 = shared_call_proof.input_fingerprint(library_audit)
    document["schema"] = RENDERER_INPUT_SCHEMA
    document["producer"] = {
        "implementation": "python_phase5_renderer_loop_composer",
        "contract": RENDERER_INPUT_SCHEMA,
    }
    document["compatibility"].update(
        {
            "policy": "exact_renderer_overlay_and_loop_proof_family_match",
            "input_renderer_overlay_schema": overlay_composer.RENDERER_INPUT_SCHEMA,
            "input_library_audit_schema": shared_call_proof.LIBRARY_AUDIT_SCHEMA,
            "input_shared_call_schema": shared_call_proof.SHARED_CALL_RETURN_PROOF_SCHEMA,
            "input_execution_fallthrough_schema": execution_proof.EXECUTION_FALLTHROUGH_PROOF_SCHEMA,
            "input_natural_loop_schema": loop_proof.NATURAL_LOOP_PROOF_SCHEMA,
            "loop_overlay_policy": "promote_only_proved_natural_loop_rows",
            "surface_loop_policy": "retain_labels_and_gotos_no_while_or_for_guess",
            "unknown_v3_field": "reject",
        }
    )
    document["inputs"].update(
        {
            "renderer_overlay_sha256": overlay_sha256,
            "library_audit_sha256": library_sha256,
            "shared_call_return_sha256": shared_calls["payload_sha256"],
            "execution_fallthrough_sha256": execution_fallthroughs[
                "payload_sha256"
            ],
            "natural_loop_sha256": natural_loops["payload_sha256"],
        }
    )
    document["proof_layers"].update(
        {
            "library_audit": copy.deepcopy(library_audit),
            "shared_call_returns": copy.deepcopy(shared_calls),
            "execution_fallthroughs": copy.deepcopy(execution_fallthroughs),
            "natural_loops": copy.deepcopy(natural_loops),
        }
    )
    loop_overlays = _loop_overlays(
        document["fallback_control"], natural_loops, linear_ir["nodes"]
    )
    document["structure_overlays"].extend(loop_overlays)
    document["structure_overlays"].sort(
        key=lambda row: (
            min(
                int(row["proof"].get(key, 1 << 62))
                for key in (
                    "source_start",
                    "source_offset",
                    "call_start",
                    "envelope_start",
                )
            ),
            str(row["layer"]),
            str(row["id"]),
        )
    )
    loop_ids_by_node = {str(node["id"]): [] for node in linear_ir["nodes"]}
    for overlay in loop_overlays:
        for node_id in overlay["member_linear_node_ids"]:
            loop_ids_by_node[node_id].append(str(overlay["id"]))
    for row in document["source_map"]:
        row["overlay_ids"] = sorted(
            list(row["overlay_ids"])
            + loop_ids_by_node[str(row["linear_node_id"])]
        )
    document["coverage"].update(
        {
            "natural_loop_overlay_count": len(loop_overlays),
            "overlay_count": len(document["structure_overlays"]),
            "proved_shared_call_return_count": int(
                shared_calls["coverage"]["proved_call_return_count"]
            ),
            "unresolved_shared_call_count": int(
                shared_calls["coverage"]["unresolved_call_count"]
            ),
            "proved_execution_fallthrough_count": int(
                execution_fallthroughs["coverage"]["proved_fallthrough_count"]
            ),
            "proved_call_return_edge_count": int(
                execution_fallthroughs["coverage"][
                    "proved_call_return_edge_count"
                ]
            ),
            "all_loop_overlays_source_reversible": all(
                bool(row["member_linear_node_ids"]) for row in loop_overlays
            ),
            "all_loop_rejections_retained": True,
        }
    )
    return document


def _loop_overlays(
    fallback_control: dict[str, Any],
    natural_loops: dict[str, Any],
    linear_nodes: list[dict[str, Any]],
) -> list[dict[str, Any]]:
    labels_by_graph: dict[int, dict[str, str]] = {}
    for graph in fallback_control["graphs"]:
        labels_by_graph[int(graph["graph_index"])] = {
            str(statement["label"]): str(statement["source_node"]["id"])
            for statement in graph["statements"]
            if str(statement.get("source_node", {}).get("id", ""))
        }
    all_node_ids = {str(node["id"]) for node in linear_nodes}
    overlays: list[dict[str, Any]] = []
    for graph in natural_loops["graphs"]:
        graph_index = int(graph["graph_index"])
        if graph_index not in labels_by_graph:
            raise RendererLoopError("natural-loop graph has no fallback graph")
        for row in graph["natural_loops"]:
            overlays.append(
                overlay_composer._overlay_record(
                    "natural_loop",
                    graph_index,
                    row,
                    labels_by_graph[graph_index],
                    all_node_ids,
                )
            )
    return overlays


def main() -> None:
    parser = argparse.ArgumentParser(
        description=(
            "Compose validated shared-call, execution-fallthrough, and "
            "natural-loop proofs into one source-reversible MES renderer input."
        )
    )
    names = (
        "linear_ir",
        "semantic_annotations",
        "flow_proof",
        "region_proof",
        "guard_chain_proof",
        "value_dispatch_proof",
        "predicate_dispatch_proof",
        "cross_region_join_proof",
        "call_family_proof",
        "library_audit",
        "shared_call_proof",
        "execution_fallthrough_proof",
        "natural_loop_proof",
    )
    for name in names:
        parser.add_argument(name, type=Path)
    parser.add_argument("output", type=Path, nargs="?")
    args = parser.parse_args()
    input_paths = tuple(getattr(args, name) for name in names)
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
            raise RendererLoopError("renderer output must not replace an input")
        args.output.write_text(encoded + "\n", encoding="utf-8")
    print(
        "MES_RENDERER_LOOP_PASS "
        f"schema={document['schema']} entry={document['source_identity'].get('entry', '')} "
        f"loops={document['coverage']['natural_loop_overlay_count']} "
        f"overlays={document['coverage']['overlay_count']} "
        f"payload_sha256={document['payload_sha256']}"
    )


if __name__ == "__main__":
    main()
