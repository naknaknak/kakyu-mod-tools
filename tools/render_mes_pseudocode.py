from __future__ import annotations

import argparse
import copy
import hashlib
import json
from pathlib import Path
from typing import Any

import compose_mes_renderer_input as core_composer
import compose_mes_renderer_loops as loop_composer
from payload_values import canonical_payload_bytes, fingerprint


PSEUDOCODE_SCHEMA = "kakyu_mes_pseudocode/v1"


class PseudocodeRenderError(ValueError):
    pass


def render(renderer_input: dict[str, Any]) -> dict[str, Any]:
    validate_renderer_input(renderer_input)
    document = _build(renderer_input)
    document["payload_sha256"] = fingerprint(document)
    validate(document, renderer_input)
    return document


def validate(
    document: dict[str, Any], renderer_input: dict[str, Any]
) -> dict[str, Any]:
    if document.get("schema") != PSEUDOCODE_SCHEMA:
        raise PseudocodeRenderError("unsupported MES pseudocode schema")
    retained = document.get("payload_sha256")
    if (
        not isinstance(retained, str)
        or len(retained) != 64
        or fingerprint(document) != retained
    ):
        raise PseudocodeRenderError("MES pseudocode fingerprint changed")
    validate_renderer_input(renderer_input)
    expected = _build(renderer_input)
    actual = dict(document)
    actual.pop("payload_sha256", None)
    if actual != expected:
        raise PseudocodeRenderError("MES pseudocode projection changed")
    return {
        "ok": True,
        "schema": PSEUDOCODE_SCHEMA,
        "payload_sha256": retained,
    }


def validate_renderer_input(document: dict[str, Any]) -> dict[str, Any]:
    if document.get("schema") != loop_composer.RENDERER_INPUT_SCHEMA:
        raise PseudocodeRenderError("unsupported renderer-input schema")
    retained = document.get("payload_sha256")
    if (
        not isinstance(retained, str)
        or len(retained) != 64
        or loop_composer.fingerprint(document) != retained
    ):
        raise PseudocodeRenderError("renderer-input fingerprint changed")
    program = document.get("program")
    semantics = document.get("semantic_annotations")
    source_map = document.get("source_map")
    if (
        not isinstance(program, dict)
        or not isinstance(semantics, dict)
        or not isinstance(source_map, list)
    ):
        raise PseudocodeRenderError("renderer source program is incomplete")
    nodes = program.get("nodes")
    annotations = semantics.get("nodes")
    symbols = semantics.get("symbols")
    if not isinstance(nodes, list) or not isinstance(annotations, list) or not isinstance(symbols, list):
        raise PseudocodeRenderError("renderer node or symbol arrays are missing")
    node_by_id = _unique_by(nodes, "id", "linear node")
    annotation_by_node = _unique_by(
        annotations, "linear_node_id", "semantic annotation"
    )
    map_by_node = _unique_by(source_map, "linear_node_id", "source map")
    if set(node_by_id) != set(annotation_by_node) or set(node_by_id) != set(map_by_node):
        raise PseudocodeRenderError("renderer node coverage changed")

    symbol_by_id = _unique_by(symbols, "id", "semantic symbol")
    for symbol in symbols:
        if str(symbol.get("linear_node_id", "")) not in node_by_id:
            raise PseudocodeRenderError("semantic symbol owner changed")
    for node_id, node in node_by_id.items():
        annotation = annotation_by_node[node_id]
        source_row = map_by_node[node_id]
        source = node.get("source", {})
        if source_row.get("source") != source:
            raise PseudocodeRenderError("source-map byte range changed")
        if str(source_row.get("annotation_id", "")) != str(annotation.get("id", "")):
            raise PseudocodeRenderError("source-map annotation owner changed")
        _validate_annotation(node, annotation)
        for symbol_id in annotation.get("symbol_ids", []):
            symbol = symbol_by_id.get(str(symbol_id))
            if symbol is None or str(symbol.get("linear_node_id", "")) != node_id:
                raise PseudocodeRenderError("annotation symbol ownership changed")

    expected_locations = core_composer._control_locations(
        document["fallback_control"], node_by_id
    )
    expected_structure_ids = {node_id: [] for node_id in node_by_id}
    for structure in document.get("conditional_structures", []):
        structure_id = str(structure.get("id", ""))
        members = structure.get("member_linear_node_ids", [])
        if not structure_id or not isinstance(members, list) or not members:
            raise PseudocodeRenderError("conditional structure source map changed")
        for node_id_raw in members:
            node_id = str(node_id_raw)
            if node_id not in node_by_id:
                raise PseudocodeRenderError("conditional structure names an unknown node")
            expected_structure_ids[node_id].append(structure_id)
    expected_overlay_ids = {node_id: [] for node_id in node_by_id}
    for overlay in document.get("structure_overlays", []):
        overlay_id = str(overlay.get("id", ""))
        members = overlay.get("member_linear_node_ids", [])
        if not overlay_id or not isinstance(members, list) or not members:
            raise PseudocodeRenderError("overlay source map changed")
        for node_id_raw in members:
            node_id = str(node_id_raw)
            if node_id not in node_by_id:
                raise PseudocodeRenderError("overlay names an unknown node")
            expected_overlay_ids[node_id].append(overlay_id)
    for node_id, source_row in map_by_node.items():
        if source_row.get("control_locations") != expected_locations[node_id]:
            raise PseudocodeRenderError("control source-map reversal changed")
        if source_row.get("structure_ids") != sorted(expected_structure_ids[node_id]):
            raise PseudocodeRenderError("conditional source-map reversal changed")
        if source_row.get("overlay_ids") != sorted(expected_overlay_ids[node_id]):
            raise PseudocodeRenderError("overlay source-map reversal changed")

    coverage = document.get("coverage", {})
    if (
        int(coverage.get("linear_node_count", -1)) != len(nodes)
        or int(coverage.get("source_mapped_node_count", -1)) != len(source_map)
        or int(coverage.get("symbol_count", -1)) != len(symbols)
        or int(coverage.get("overlay_count", -1))
        != len(document.get("structure_overlays", []))
        or int(coverage.get("natural_loop_overlay_count", -1))
        != sum(
            row.get("layer") == "natural_loop"
            for row in document.get("structure_overlays", [])
        )
    ):
        raise PseudocodeRenderError("renderer coverage changed")
    return {
        "ok": True,
        "schema": loop_composer.RENDERER_INPUT_SCHEMA,
        "payload_sha256": retained,
    }


def _unique_by(
    rows: list[dict[str, Any]], key: str, description: str
) -> dict[str, dict[str, Any]]:
    result: dict[str, dict[str, Any]] = {}
    for row in rows:
        if not isinstance(row, dict):
            raise PseudocodeRenderError(f"{description} is not an object")
        identity = str(row.get(key, ""))
        if not identity or identity in result:
            raise PseudocodeRenderError(f"{description} identity changed")
        result[identity] = row
    return result


def _validate_annotation(node: dict[str, Any], annotation: dict[str, Any]) -> None:
    source = node.get("source", {})
    annotated_source = annotation.get("source", {})
    for key in ("entry", "region", "start", "end", "raw_sha256"):
        if annotated_source.get(key) != source.get(key):
            raise PseudocodeRenderError("semantic annotation source changed")
    operation = annotation.get("operation", {})
    statement = node.get("statement", {})
    if node.get("kind") == "statement":
        if operation.get("kind") != "typed_instruction" or operation.get(
            "token"
        ) != statement.get("op"):
            raise PseudocodeRenderError("typed operation annotation changed")
    elif node.get("kind") == "opaque":
        if operation.get("kind") != "opaque_boundary" or operation.get(
            "token"
        ) != statement.get("boundary"):
            raise PseudocodeRenderError("opaque operation annotation changed")
    else:
        raise PseudocodeRenderError("unsupported renderer node kind")


def _build(renderer_input: dict[str, Any]) -> dict[str, Any]:
    nodes = renderer_input["program"]["nodes"]
    annotation_by_node = {
        str(row["linear_node_id"]): row
        for row in renderer_input["semantic_annotations"]["nodes"]
    }
    symbol_by_id = {
        str(row["id"]): row
        for row in renderer_input["semantic_annotations"]["symbols"]
    }
    source_map_by_node = {
        str(row["linear_node_id"]): row for row in renderer_input["source_map"]
    }
    structures_by_source: dict[str, list[dict[str, Any]]] = {}
    for structure in renderer_input["conditional_structures"]:
        structures_by_source.setdefault(
            str(structure["source_linear_node_id"]), []
        ).append(structure)
    overlays_by_source: dict[str, list[dict[str, Any]]] = {}
    node_start = {str(node["id"]): int(node["source"]["start"]) for node in nodes}
    for overlay in renderer_input["structure_overlays"]:
        source_node_id = min(
            (str(value) for value in overlay["member_linear_node_ids"]),
            key=lambda value: (node_start[value], value),
        )
        overlays_by_source.setdefault(source_node_id, []).append(overlay)

    statements = _fallback_statements(renderer_input["fallback_control"])
    lines: list[dict[str, Any]] = []

    def append(text: str, node_ids: list[str]) -> None:
        sources = [_line_source(source_map_by_node[node_id]) for node_id in node_ids]
        lines.append(
            {
                "id": f"line_{len(lines):08d}",
                "text": text,
                "linear_node_ids": node_ids,
                "sources": sources,
            }
        )

    entry = str(renderer_input.get("source_identity", {}).get("entry", ""))
    append(
        f"entry {entry or '<unresolved>'} renderer={renderer_input['schema']}",
        [],
    )
    current_region: str | None = None
    for node in nodes:
        node_id = str(node["id"])
        source = node["source"]
        region = str(source["region"])
        if region != current_region:
            current_region = region
            append(f"region {region}", [])
        for structure in sorted(
            structures_by_source.get(node_id, []), key=lambda row: str(row["id"])
        ):
            append(_structure_text(structure), list(structure["member_linear_node_ids"]))
        for overlay in sorted(
            overlays_by_source.get(node_id, []), key=lambda row: str(row["id"])
        ):
            append(_overlay_text(overlay), list(overlay["member_linear_node_ids"]))
        annotation = annotation_by_node[node_id]
        symbols = [
            str(symbol_by_id[str(symbol_id)]["canonical_name"])
            for symbol_id in annotation["symbol_ids"]
        ]
        controls = [
            _control_text(
                statements[(
                    int(location["graph_index"]),
                    str(location["statement_id"]),
                )]
            )
            for location in source_map_by_node[node_id]["control_locations"]
        ]
        append(
            _node_text(node, annotation, symbols, controls),
            [node_id],
        )

    rendered_text = "\n".join(row["text"] for row in lines) + "\n"
    source_line_count = sum(bool(row["linear_node_ids"]) for row in lines)
    return {
        "ok": True,
        "schema": PSEUDOCODE_SCHEMA,
        "producer": {
            "implementation": "python_phase5_source_order_pseudocode_renderer",
            "contract": PSEUDOCODE_SCHEMA,
        },
        "compatibility": {
            "policy": "exact_renderer_input_v3_projection",
            "input_renderer_schema": loop_composer.RENDERER_INPUT_SCHEMA,
            "unknown_pseudocode_schema": "reject",
            "unknown_v1_field": "reject",
            "output_policy": "json_lines_with_optional_derived_text",
            "message_policy": "source_coordinate_only_no_dialogue_decode",
            "semantic_policy": "numeric_or_unresolved_aliases_only",
            "surface_control_policy": "proved_tokens_and_retained_labels_no_switch_while_for_guess",
        },
        "input": {
            "renderer_input_sha256": renderer_input["payload_sha256"],
        },
        "source_identity": copy.deepcopy(
            renderer_input.get("source_identity", {})
        ),
        "lines": lines,
        "rendered_text_sha256": hashlib.sha256(
            rendered_text.encode("utf-8")
        ).hexdigest(),
        "coverage": {
            "line_count": len(lines),
            "node_line_count": len(nodes),
            "structure_line_count": len(renderer_input["conditional_structures"]),
            "overlay_line_count": len(renderer_input["structure_overlays"]),
            "source_qualified_line_count": source_line_count,
            "unmapped_linear_node_count": 0,
            "semantic_alias_count": 0,
            "decoded_dialogue_count": 0,
            "guessed_surface_control_count": 0,
            "all_linear_nodes_rendered_once": True,
            "all_non_header_lines_source_reversible": all(
                bool(row["linear_node_ids"])
                for row in lines
                if not row["text"].startswith(("entry ", "region "))
            ),
        },
    }


def _fallback_statements(
    fallback_control: dict[str, Any]
) -> dict[tuple[int, str], dict[str, Any]]:
    statements: dict[tuple[int, str], dict[str, Any]] = {}
    for graph in fallback_control["graphs"]:
        graph_index = int(graph["graph_index"])
        for statement in graph["statements"]:
            key = (graph_index, str(statement["id"]))
            if key in statements:
                raise PseudocodeRenderError("fallback statement identity changed")
            statements[key] = statement
    return statements


def _line_source(source_map: dict[str, Any]) -> dict[str, Any]:
    source = source_map["source"]
    return {
        "linear_node_id": str(source_map["linear_node_id"]),
        "annotation_id": str(source_map["annotation_id"]),
        "entry": str(source.get("entry", "")),
        "region": str(source["region"]),
        "start": int(source["start"]),
        "end": int(source["end"]),
        "raw_sha256": str(source["raw_sha256"]),
    }


def _structure_text(structure: dict[str, Any]) -> str:
    return (
        f"@proved_structure kind={structure['kind']} id={structure['id']} "
        f"members={len(structure['member_linear_node_ids'])} "
        f"join={structure['join_label']} status={structure['proof_status']}"
    )


def _overlay_text(overlay: dict[str, Any]) -> str:
    proof = overlay["proof"]
    surface = str(proof.get("surface_syntax", "unresolved"))
    return (
        f"@proved_overlay layer={overlay['layer']} kind={overlay['kind']} "
        f"id={overlay['id']} members={len(overlay['member_linear_node_ids'])} "
        f"surface={surface}"
    )


def _node_text(
    node: dict[str, Any],
    annotation: dict[str, Any],
    symbols: list[str],
    controls: list[str],
) -> str:
    source = node["source"]
    operation = annotation["operation"]
    parts = [
        f"0x{int(source['start']):08X}..0x{int(source['end']):08X}",
        f"{source['region']}",
        f"{operation['kind']}={operation['token']}",
    ]
    if symbols:
        parts.append(
            "symbols="
            + json.dumps(symbols, ensure_ascii=False, separators=(",", ":"))
        )
    if controls:
        parts.append(
            "control="
            + json.dumps(controls, ensure_ascii=False, separators=(",", ":"))
        )
    return " ".join(parts)


def _control_text(statement: dict[str, Any]) -> str:
    kind = str(statement["kind"])
    label = str(statement["label"])
    if kind == "conditional_goto":
        condition = json.dumps(
            statement["condition"].get("ast", {}),
            ensure_ascii=False,
            sort_keys=True,
            separators=(",", ":"),
        )
        return (
            f"{label}: branch ast={condition} "
            f"true={statement['true_label']} false={statement['false_label']}"
        )
    if kind == "goto":
        return f"{label}: goto {statement['target_label']}"
    if kind == "boundary":
        return f"{label}: boundary {statement['boundary']}"
    if kind == "unresolved_transfer":
        return f"{label}: unresolved_transfer reason={statement['reason']}"
    if kind == "unexpanded_transfer":
        return f"{label}: unexpanded_transfer reason={statement['reason']}"
    return f"{label}: {kind}"


def main() -> None:
    parser = argparse.ArgumentParser(
        description=(
            "Render a validated MES renderer-input v3 as deterministic, "
            "source-reversible pseudocode JSON."
        )
    )
    parser.add_argument("renderer_input", type=Path)
    parser.add_argument("output", type=Path, nargs="?")
    parser.add_argument("--text-output", type=Path)
    args = parser.parse_args()
    renderer_input = json.loads(args.renderer_input.read_text(encoding="utf-8"))
    document = render(renderer_input)
    encoded = json.dumps(
        document,
        ensure_ascii=False,
        allow_nan=False,
        sort_keys=True,
        separators=(",", ":"),
    )
    protected = {args.renderer_input.resolve()}
    if args.output is not None:
        if args.output.resolve() in protected:
            raise PseudocodeRenderError("pseudocode output must not replace its input")
        args.output.write_text(encoded + "\n", encoding="utf-8")
        protected.add(args.output.resolve())
    if args.text_output is not None:
        if args.text_output.resolve() in protected:
            raise PseudocodeRenderError("text output must not replace a JSON input or output")
        args.text_output.write_text(
            "\n".join(row["text"] for row in document["lines"]) + "\n",
            encoding="utf-8",
        )
    print(
        "MES_PSEUDOCODE_PASS "
        f"schema={document['schema']} entry={document['source_identity'].get('entry', '')} "
        f"lines={document['coverage']['line_count']} "
        f"payload_sha256={document['payload_sha256']}"
    )


if __name__ == "__main__":
    main()
