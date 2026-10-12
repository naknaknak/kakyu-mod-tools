from __future__ import annotations

import argparse
import copy
import json
from pathlib import Path
from typing import Any

import compose_mes_renderer_input as core_composer
import prove_mes_call_families as call_proof
import prove_mes_cross_region_joins as join_proof
import prove_mes_guard_chains as guard_proof
import prove_mes_predicate_dispatches as predicate_proof
import prove_mes_value_dispatches as value_proof
from payload_values import canonical_payload_bytes, fingerprint


RENDERER_INPUT_SCHEMA = "kakyu_mes_renderer_input/v2"


class RendererOverlayError(ValueError):
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
    )
    core = _validate_inputs(*inputs)
    document = _build(core, *inputs)
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
) -> dict[str, Any]:
    if document.get("schema") != RENDERER_INPUT_SCHEMA:
        raise RendererOverlayError("unsupported MES renderer overlay schema")
    retained = document.get("payload_sha256")
    if (
        not isinstance(retained, str)
        or len(retained) != 64
        or fingerprint(document) != retained
    ):
        raise RendererOverlayError("MES renderer overlay fingerprint changed")
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
    )
    core = _validate_inputs(*inputs)
    expected = _build(core, *inputs)
    actual = dict(document)
    actual.pop("payload_sha256", None)
    if actual != expected:
        raise RendererOverlayError("MES renderer overlay projection changed")
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
) -> dict[str, Any]:
    core = core_composer.compose(
        linear_ir, annotations, transfer_proof, conditional_proof
    )
    guard_proof.validate(
        guard_chains, linear_ir, transfer_proof, conditional_proof
    )
    value_proof.validate(
        value_dispatches,
        linear_ir,
        transfer_proof,
        conditional_proof,
        guard_chains,
    )
    predicate_proof.validate(
        predicate_dispatches,
        linear_ir,
        transfer_proof,
        conditional_proof,
        guard_chains,
        value_dispatches,
    )
    join_proof.validate(
        cross_region_joins, linear_ir, transfer_proof, conditional_proof
    )
    call_proof.validate(call_families, linear_ir)
    source_identity = linear_ir.get("source_identity", {})
    for name, candidate in (
        ("guard-chain proof", guard_chains),
        ("value-dispatch proof", value_dispatches),
        ("predicate-dispatch proof", predicate_dispatches),
        ("cross-region-join proof", cross_region_joins),
        ("call-family proof", call_families),
    ):
        if candidate.get("source_identity", {}) != source_identity:
            raise RendererOverlayError(f"{name} source identity changed")
    return core


def _build(
    core: dict[str, Any],
    linear_ir: dict[str, Any],
    annotations: dict[str, Any],
    transfer_proof: dict[str, Any],
    conditional_proof: dict[str, Any],
    guard_chains: dict[str, Any],
    value_dispatches: dict[str, Any],
    predicate_dispatches: dict[str, Any],
    cross_region_joins: dict[str, Any],
    call_families: dict[str, Any],
) -> dict[str, Any]:
    document = copy.deepcopy(core)
    core_sha256 = str(document.pop("payload_sha256"))
    document["schema"] = RENDERER_INPUT_SCHEMA
    document["producer"] = {
        "implementation": "python_phase5_renderer_overlay_composer",
        "contract": RENDERER_INPUT_SCHEMA,
    }
    document["compatibility"].update(
        {
            "policy": "exact_renderer_core_and_structure_proof_family_match",
            "input_renderer_core_schema": core_composer.RENDERER_INPUT_SCHEMA,
            "input_guard_chain_schema": guard_proof.GUARD_CHAIN_PROOF_SCHEMA,
            "input_value_dispatch_schema": value_proof.VALUE_DISPATCH_PROOF_SCHEMA,
            "input_predicate_dispatch_schema": predicate_proof.PREDICATE_DISPATCH_PROOF_SCHEMA,
            "input_cross_region_join_schema": join_proof.CROSS_REGION_JOIN_PROOF_SCHEMA,
            "input_call_family_schema": call_proof.CALL_FAMILY_PROOF_SCHEMA,
            "overlay_policy": "retain_full_proofs_and_promote_only_accepted_rows",
            "unknown_v2_field": "reject",
            "loop_overlay_policy": "not_present_in_v2",
        }
    )
    document["inputs"].update(
        {
            "renderer_core_sha256": core_sha256,
            "guard_chain_proof_sha256": guard_chains["payload_sha256"],
            "value_dispatch_proof_sha256": value_dispatches["payload_sha256"],
            "predicate_dispatch_proof_sha256": predicate_dispatches[
                "payload_sha256"
            ],
            "cross_region_join_proof_sha256": cross_region_joins[
                "payload_sha256"
            ],
            "call_family_proof_sha256": call_families["payload_sha256"],
        }
    )
    proof_layers = {
        "guard_chains": copy.deepcopy(guard_chains),
        "value_dispatches": copy.deepcopy(value_dispatches),
        "predicate_dispatches": copy.deepcopy(predicate_dispatches),
        "cross_region_joins": copy.deepcopy(cross_region_joins),
        "call_families": copy.deepcopy(call_families),
    }
    overlays = _structure_overlays(
        document["fallback_control"],
        proof_layers,
        {str(node["id"]) for node in linear_ir["nodes"]},
    )
    overlay_ids_by_node = {
        str(node["id"]): [] for node in linear_ir["nodes"]
    }
    for overlay in overlays:
        for node_id in overlay["member_linear_node_ids"]:
            overlay_ids_by_node[node_id].append(str(overlay["id"]))
    for row in document["source_map"]:
        row["overlay_ids"] = sorted(
            overlay_ids_by_node[str(row["linear_node_id"])]
        )

    document["proof_layers"] = proof_layers
    document["structure_overlays"] = overlays
    document["coverage"].update(
        {
            "guard_chain_overlay_count": _count_layer(overlays, "guard_chain"),
            "value_dispatch_overlay_count": _count_layer(
                overlays, "value_dispatch"
            ),
            "predicate_dispatch_overlay_count": _count_layer(
                overlays, "predicate_dispatch"
            ),
            "cross_region_join_overlay_count": _count_layer(
                overlays, "cross_region_join"
            ),
            "call_family_overlay_count": _count_layer(overlays, "call_family"),
            "overlay_count": len(overlays),
            "all_overlays_source_reversible": all(
                bool(row["member_linear_node_ids"]) for row in overlays
            ),
            "all_proof_rejections_retained": True,
        }
    )
    return document


def _structure_overlays(
    fallback_control: dict[str, Any],
    proof_layers: dict[str, dict[str, Any]],
    all_node_ids: set[str],
) -> list[dict[str, Any]]:
    overlays: list[dict[str, Any]] = []
    graph_labels: dict[int, dict[str, str]] = {}
    for graph in fallback_control["graphs"]:
        graph_index = int(graph["graph_index"])
        labels: dict[str, str] = {}
        for statement in graph["statements"]:
            node_id = str(statement.get("source_node", {}).get("id", ""))
            if node_id:
                labels[str(statement["label"])] = node_id
        graph_labels[graph_index] = labels

    graph_specs = (
        ("guard_chain", proof_layers["guard_chains"], "guard_chains"),
        ("value_dispatch", proof_layers["value_dispatches"], "value_dispatches"),
        (
            "predicate_dispatch",
            proof_layers["predicate_dispatches"],
            "predicate_dispatches",
        ),
        (
            "cross_region_join",
            proof_layers["cross_region_joins"],
            "cross_region_joins",
        ),
    )
    for layer, proof, row_key in graph_specs:
        for graph in proof["graphs"]:
            graph_index = int(graph["graph_index"])
            if graph_index not in graph_labels:
                raise RendererOverlayError("overlay graph has no fallback graph")
            for row in graph[row_key]:
                overlays.append(
                    _overlay_record(
                        layer,
                        graph_index,
                        row,
                        graph_labels[graph_index],
                        all_node_ids,
                    )
                )
    for row in proof_layers["call_families"]["call_sites"]:
        overlays.append(
            _overlay_record(
                "call_family", None, row, {}, all_node_ids
            )
        )
    overlays.sort(
        key=lambda row: (
            min(
                int(row["proof"].get(key, 1 << 62))
                for key in ("source_start", "source_offset", "call_start")
            ),
            str(row["layer"]),
            str(row["id"]),
        )
    )
    return overlays


def _overlay_record(
    layer: str,
    graph_index: int | None,
    proof_row: dict[str, Any],
    label_to_node: dict[str, str],
    all_node_ids: set[str],
) -> dict[str, Any]:
    strings = _all_strings(proof_row)
    source_labels = sorted(value for value in strings if value in label_to_node)
    member_ids = sorted(value for value in strings if value in all_node_ids)
    member_ids.extend(label_to_node[label] for label in source_labels)
    member_ids = list(dict.fromkeys(member_ids))
    if not member_ids:
        raise RendererOverlayError(
            "promoted overlay has no reversible source node: "
            f"layer={layer} proof_id={proof_row.get('id', '')}"
        )
    proof_id = str(proof_row.get("id", ""))
    if not proof_id:
        raise RendererOverlayError("promoted overlay has no proof identity")
    graph_token = "none" if graph_index is None else f"{graph_index:04d}"
    return {
        "id": f"overlay_{layer}_{graph_token}_{proof_id}",
        "layer": layer,
        "kind": str(proof_row.get("kind", layer)),
        "graph_index": graph_index,
        "proof_id": proof_id,
        "source_labels": source_labels,
        "member_linear_node_ids": member_ids,
        "proof": copy.deepcopy(proof_row),
    }


def _all_strings(value: Any) -> set[str]:
    if isinstance(value, str):
        return {value}
    if isinstance(value, list):
        result: set[str] = set()
        for item in value:
            result.update(_all_strings(item))
        return result
    if isinstance(value, dict):
        result = set()
        for item in value.values():
            result.update(_all_strings(item))
        return result
    return set()


def _count_layer(overlays: list[dict[str, Any]], layer: str) -> int:
    return sum(row["layer"] == layer for row in overlays)


def main() -> None:
    parser = argparse.ArgumentParser(
        description=(
            "Compose validated guard, dispatch, join, and call proof layers "
            "into one source-reversible MES renderer input."
        )
    )
    parser.add_argument("linear_ir", type=Path)
    parser.add_argument("semantic_annotations", type=Path)
    parser.add_argument("flow_proof", type=Path)
    parser.add_argument("region_proof", type=Path)
    parser.add_argument("guard_chain_proof", type=Path)
    parser.add_argument("value_dispatch_proof", type=Path)
    parser.add_argument("predicate_dispatch_proof", type=Path)
    parser.add_argument("cross_region_join_proof", type=Path)
    parser.add_argument("call_family_proof", type=Path)
    parser.add_argument("output", type=Path, nargs="?")
    args = parser.parse_args()
    input_paths = (
        args.linear_ir,
        args.semantic_annotations,
        args.flow_proof,
        args.region_proof,
        args.guard_chain_proof,
        args.value_dispatch_proof,
        args.predicate_dispatch_proof,
        args.cross_region_join_proof,
        args.call_family_proof,
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
            raise RendererOverlayError("renderer output must not replace an input")
        args.output.write_text(encoded + "\n", encoding="utf-8")
    print(
        "MES_RENDERER_OVERLAY_PASS "
        f"schema={document['schema']} entry={document['source_identity'].get('entry', '')} "
        f"overlays={document['coverage']['overlay_count']} "
        f"payload_sha256={document['payload_sha256']}"
    )


if __name__ == "__main__":
    main()
