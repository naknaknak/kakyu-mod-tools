from __future__ import annotations

import argparse
import copy
import hashlib
import json
from pathlib import Path
from typing import Any

import render_mes_pseudocode as pseudocode_renderer
from payload_values import canonical_payload_bytes, fingerprint


EQUIVALENCE_AUDIT_SCHEMA = "kakyu_mes_decompiler_equivalence_audit/v1"
UNRESOLVED_CONTROL_KINDS = {
    "boundary",
    "unexpanded_transfer",
    "unresolved_transfer",
}


class EquivalenceAuditError(ValueError):
    pass


def audit(
    renderer_input: dict[str, Any], pseudocode: dict[str, Any]
) -> dict[str, Any]:
    pseudocode_renderer.validate_renderer_input(renderer_input)
    pseudocode_renderer.validate(pseudocode, renderer_input)
    document = _build(renderer_input, pseudocode)
    document["payload_sha256"] = fingerprint(document)
    validate(document, renderer_input, pseudocode)
    return document


def validate(
    document: dict[str, Any],
    renderer_input: dict[str, Any],
    pseudocode: dict[str, Any],
) -> dict[str, Any]:
    if document.get("schema") != EQUIVALENCE_AUDIT_SCHEMA:
        raise EquivalenceAuditError("unsupported MES equivalence-audit schema")
    retained = document.get("payload_sha256")
    if (
        not isinstance(retained, str)
        or len(retained) != 64
        or fingerprint(document) != retained
    ):
        raise EquivalenceAuditError("MES equivalence-audit fingerprint changed")
    pseudocode_renderer.validate_renderer_input(renderer_input)
    pseudocode_renderer.validate(pseudocode, renderer_input)
    expected = _build(renderer_input, pseudocode)
    actual = dict(document)
    actual.pop("payload_sha256", None)
    if actual != expected:
        raise EquivalenceAuditError("MES equivalence-audit projection changed")
    return {
        "ok": True,
        "schema": EQUIVALENCE_AUDIT_SCHEMA,
        "payload_sha256": retained,
    }


def _build(
    renderer_input: dict[str, Any], pseudocode: dict[str, Any]
) -> dict[str, Any]:
    nodes = renderer_input["program"]["nodes"]
    partition = _source_partition(nodes, renderer_input["program"]["regions"])
    line_equivalence = _line_equivalence(renderer_input, pseudocode)
    fallback_statements = [
        statement
        for graph in renderer_input["fallback_control"]["graphs"]
        for statement in graph["statements"]
    ]
    unresolved = _unresolved_inventory(renderer_input)
    coverage = {
        "linear_node_count": len(nodes),
        "linear_byte_count": partition["linear_byte_count"],
        "region_count": len(renderer_input["program"]["regions"]),
        "fallback_statement_count": len(fallback_statements),
        "conditional_structure_count": len(
            renderer_input["conditional_structures"]
        ),
        "structure_overlay_count": len(renderer_input["structure_overlays"]),
        "pseudocode_node_line_count": line_equivalence["node_line_count"],
        "pseudocode_structure_line_count": line_equivalence[
            "structure_line_count"
        ],
        "pseudocode_overlay_line_count": line_equivalence["overlay_line_count"],
        "source_partition_complete": partition["complete"],
        "region_node_ownership_complete": partition[
            "region_node_ownership_complete"
        ],
        "all_linear_nodes_rendered_once": line_equivalence[
            "all_linear_nodes_rendered_once"
        ],
        "all_structures_rendered_once": line_equivalence[
            "all_structures_rendered_once"
        ],
        "all_overlays_rendered_once": line_equivalence[
            "all_overlays_rendered_once"
        ],
        "all_rendered_sources_reverse": line_equivalence[
            "all_rendered_sources_reverse"
        ],
        "opaque_node_count": len(unresolved["opaque_nodes"]),
        "unresolved_control_count": len(unresolved["control_constructs"]),
        "proof_rejection_count": len(unresolved["proof_rejections"]),
        "surface_unresolved_overlay_count": len(
            unresolved["surface_unresolved_overlays"]
        ),
    }
    equivalent = all(
        coverage[key]
        for key in (
            "source_partition_complete",
            "region_node_ownership_complete",
            "all_linear_nodes_rendered_once",
            "all_structures_rendered_once",
            "all_overlays_rendered_once",
            "all_rendered_sources_reverse",
        )
    )
    return {
        "ok": equivalent,
        "schema": EQUIVALENCE_AUDIT_SCHEMA,
        "producer": {
            "implementation": "python_phase5_entry_equivalence_auditor",
            "contract": EQUIVALENCE_AUDIT_SCHEMA,
        },
        "compatibility": {
            "policy": "exact_renderer_v3_and_pseudocode_v1_match",
            "input_renderer_schema": pseudocode_renderer.loop_composer.RENDERER_INPUT_SCHEMA,
            "input_pseudocode_schema": pseudocode_renderer.PSEUDOCODE_SCHEMA,
            "unknown_audit_schema": "reject",
            "unknown_v1_field": "reject",
            "unresolved_policy": "inventory_without_promotion",
            "corpus_policy": "single_entry_contract_not_yet_corpus_closure",
        },
        "inputs": {
            "renderer_input_sha256": renderer_input["payload_sha256"],
            "pseudocode_sha256": pseudocode["payload_sha256"],
            "rendered_text_sha256": pseudocode["rendered_text_sha256"],
        },
        "source_identity": copy.deepcopy(
            renderer_input.get("source_identity", {})
        ),
        "equivalent": equivalent,
        "partition": partition,
        "line_equivalence": line_equivalence,
        "unresolved_inventory": unresolved,
        "coverage": coverage,
    }


def _source_partition(
    nodes: list[dict[str, Any]], regions: list[dict[str, Any]]
) -> dict[str, Any]:
    cursor = 0
    ordered_ids: list[str] = []
    for node in nodes:
        source = node.get("source", {})
        start = int(source.get("start", -1))
        end = int(source.get("end", -1))
        if start != cursor or end <= start:
            raise EquivalenceAuditError(
                f"linear source partition changed at 0x{max(start, 0):08X}"
            )
        raw_hex = source.get("raw_hex")
        if not isinstance(raw_hex, str):
            raise EquivalenceAuditError("linear node raw bytes are missing")
        try:
            raw = bytes.fromhex(raw_hex)
        except ValueError as error:
            raise EquivalenceAuditError("linear node raw bytes are invalid") from error
        if len(raw) != end - start or hashlib.sha256(raw).hexdigest() != source.get(
            "raw_sha256"
        ):
            raise EquivalenceAuditError("linear node raw identity changed")
        cursor = end
        ordered_ids.append(str(node["id"]))
    owned_ids = [str(value) for region in regions for value in region["node_ids"]]
    region_ownership = (
        len(owned_ids) == len(set(owned_ids))
        and set(owned_ids) == set(ordered_ids)
    )
    if not region_ownership:
        raise EquivalenceAuditError("region node ownership changed")
    return {
        "source_start": 0,
        "source_end": cursor,
        "linear_byte_count": cursor,
        "node_count": len(nodes),
        "complete": True,
        "region_node_ownership_complete": True,
    }


def _line_equivalence(
    renderer_input: dict[str, Any], pseudocode: dict[str, Any]
) -> dict[str, Any]:
    node_ids = [str(node["id"]) for node in renderer_input["program"]["nodes"]]
    structure_ids = {
        str(row["id"]): set(str(value) for value in row["member_linear_node_ids"])
        for row in renderer_input["conditional_structures"]
    }
    overlay_ids = {
        str(row["id"]): set(str(value) for value in row["member_linear_node_ids"])
        for row in renderer_input["structure_overlays"]
    }
    rendered_nodes: list[str] = []
    rendered_structures: list[str] = []
    rendered_overlays: list[str] = []
    all_sources_reverse = True
    for line in pseudocode["lines"]:
        text = str(line["text"])
        line_node_ids = [str(value) for value in line["linear_node_ids"]]
        source_ids = {
            str(source["linear_node_id"]) for source in line["sources"]
        }
        if set(line_node_ids) != source_ids:
            all_sources_reverse = False
        if text.startswith("0x"):
            if len(line_node_ids) != 1:
                raise EquivalenceAuditError("node pseudocode line ownership changed")
            rendered_nodes.append(line_node_ids[0])
        elif text.startswith("@proved_structure "):
            identity = _text_field(text, "id")
            if identity not in structure_ids or set(line_node_ids) != structure_ids[identity]:
                raise EquivalenceAuditError("structure pseudocode line ownership changed")
            rendered_structures.append(identity)
        elif text.startswith("@proved_overlay "):
            identity = _text_field(text, "id")
            if identity not in overlay_ids or set(line_node_ids) != overlay_ids[identity]:
                raise EquivalenceAuditError("overlay pseudocode line ownership changed")
            rendered_overlays.append(identity)
        elif line_node_ids or line["sources"]:
            raise EquivalenceAuditError("header pseudocode line gained source ownership")
    return {
        "node_line_count": len(rendered_nodes),
        "structure_line_count": len(rendered_structures),
        "overlay_line_count": len(rendered_overlays),
        "all_linear_nodes_rendered_once": rendered_nodes == node_ids,
        "all_structures_rendered_once": (
            len(rendered_structures) == len(set(rendered_structures))
            and set(rendered_structures) == set(structure_ids)
        ),
        "all_overlays_rendered_once": (
            len(rendered_overlays) == len(set(rendered_overlays))
            and set(rendered_overlays) == set(overlay_ids)
        ),
        "all_rendered_sources_reverse": all_sources_reverse,
    }


def _text_field(text: str, field: str) -> str:
    prefix = f"{field}="
    for token in text.split():
        if token.startswith(prefix):
            return token[len(prefix) :]
    raise EquivalenceAuditError(f"pseudocode marker lost {field}")


def _unresolved_inventory(renderer_input: dict[str, Any]) -> dict[str, Any]:
    opaque_nodes = [
        {
            "linear_node_id": str(node["id"]),
            "region": str(node["source"]["region"]),
            "start": int(node["source"]["start"]),
            "end": int(node["source"]["end"]),
            "boundary": str(node["statement"].get("boundary", "")),
        }
        for node in renderer_input["program"]["nodes"]
        if node["kind"] == "opaque"
    ]
    control_constructs = [
        {
            "graph_index": int(graph["graph_index"]),
            "statement_id": str(statement["id"]),
            "label": str(statement["label"]),
            "kind": str(statement["kind"]),
            "reason": str(
                statement.get("reason", statement.get("boundary", ""))
            ),
            "linear_node_id": str(
                statement.get("source_node", {}).get("id", "")
            ),
        }
        for graph in renderer_input["fallback_control"]["graphs"]
        for statement in graph["statements"]
        if statement["kind"] in UNRESOLVED_CONTROL_KINDS
    ]
    proof_rejections: list[dict[str, Any]] = []
    for layer, proof in sorted(renderer_input["proof_layers"].items()):
        _collect_rejections(proof, str(layer), [], proof_rejections)
    surface_unresolved = [
        {
            "overlay_id": str(overlay["id"]),
            "layer": str(overlay["layer"]),
            "kind": str(overlay["kind"]),
            "surface_syntax": str(
                overlay["proof"].get("surface_syntax", "unresolved")
            ),
        }
        for overlay in renderer_input["structure_overlays"]
        if "unresolved"
        in str(overlay["proof"].get("surface_syntax", "unresolved"))
    ]
    return {
        "semantic_categories": copy.deepcopy(
            renderer_input["semantic_annotations"][
                "unresolved_semantic_categories"
            ]
        ),
        "opaque_nodes": opaque_nodes,
        "control_constructs": control_constructs,
        "proof_rejections": proof_rejections,
        "surface_unresolved_overlays": surface_unresolved,
    }


def _collect_rejections(
    value: Any,
    layer: str,
    path: list[str],
    output: list[dict[str, Any]],
) -> None:
    if isinstance(value, dict):
        for key, child in sorted(value.items()):
            next_path = path + [str(key)]
            if (
                isinstance(child, list)
                and (str(key).startswith("rejected_") or str(key).startswith("unresolved_"))
                and all(isinstance(row, dict) for row in child)
            ):
                for index, row in enumerate(child):
                    output.append(_rejection_summary(layer, next_path, index, row))
            else:
                _collect_rejections(child, layer, next_path, output)
    elif isinstance(value, list):
        for index, child in enumerate(value):
            _collect_rejections(child, layer, path + [str(index)], output)


def _rejection_summary(
    layer: str, path: list[str], index: int, row: dict[str, Any]
) -> dict[str, Any]:
    identity_keys = (
        "id",
        "call_node_id",
        "fallback_linear_node_id",
        "guard_chain_id",
        "header_label",
        "source_label",
        "source_offset",
        "call_start",
        "reason",
    )
    identity = {
        key: copy.deepcopy(row[key]) for key in identity_keys if key in row
    }
    raw = json.dumps(
        row,
        ensure_ascii=False,
        allow_nan=False,
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")
    return {
        "layer": layer,
        "category": path[-1],
        "path": "/".join(path + [str(index)]),
        "identity": identity,
        "evidence_sha256": hashlib.sha256(raw).hexdigest(),
    }


def main() -> None:
    parser = argparse.ArgumentParser(
        description=(
            "Audit one MES renderer/pseudocode pair for source, fallback, "
            "structure, and unresolved-inventory equivalence."
        )
    )
    parser.add_argument("renderer_input", type=Path)
    parser.add_argument("pseudocode", type=Path)
    parser.add_argument("output", type=Path, nargs="?")
    args = parser.parse_args()
    renderer_input = json.loads(args.renderer_input.read_text(encoding="utf-8"))
    pseudocode = json.loads(args.pseudocode.read_text(encoding="utf-8"))
    document = audit(renderer_input, pseudocode)
    encoded = json.dumps(
        document,
        ensure_ascii=False,
        allow_nan=False,
        sort_keys=True,
        separators=(",", ":"),
    )
    if args.output is not None:
        inputs = {args.renderer_input.resolve(), args.pseudocode.resolve()}
        if args.output.resolve() in inputs:
            raise EquivalenceAuditError("audit output must not replace an input")
        args.output.write_text(encoded + "\n", encoding="utf-8")
    print(
        "MES_EQUIVALENCE_AUDIT_PASS "
        f"schema={document['schema']} entry={document['source_identity'].get('entry', '')} "
        f"nodes={document['coverage']['linear_node_count']} "
        f"rejections={document['coverage']['proof_rejection_count']} "
        f"payload_sha256={document['payload_sha256']}"
    )


if __name__ == "__main__":
    main()
