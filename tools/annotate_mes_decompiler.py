from __future__ import annotations

import argparse
import copy
import json
import re
from pathlib import Path
from typing import Any

import decompile_mes_handoff as decompiler
from payload_values import canonical_payload_bytes, fingerprint


SEMANTIC_ANNOTATION_SCHEMA = "kakyu_mes_semantic_annotation/v1"
REFERENCE_KINDS = {"code", "message", "resource", "state"}
INTEGER_TEXT = re.compile(r"^-?[0-9]+$")


class SemanticAnnotationError(ValueError):
    pass


def annotate(linear_ir: dict[str, Any]) -> dict[str, Any]:
    decompiler.validate(linear_ir)
    document = _build(linear_ir)
    document["payload_sha256"] = fingerprint(document)
    validate(document, linear_ir)
    return document


def validate(
    document: dict[str, Any], linear_ir: dict[str, Any]
) -> dict[str, Any]:
    if document.get("schema") != SEMANTIC_ANNOTATION_SCHEMA:
        raise SemanticAnnotationError("unsupported MES semantic annotation schema")
    retained = document.get("payload_sha256")
    if (
        not isinstance(retained, str)
        or len(retained) != 64
        or fingerprint(document) != retained
    ):
        raise SemanticAnnotationError("MES semantic annotation fingerprint changed")
    decompiler.validate(linear_ir)
    expected = _build(linear_ir)
    actual = dict(document)
    actual.pop("payload_sha256", None)
    if actual != expected:
        raise SemanticAnnotationError("MES semantic annotation projection changed")
    return {
        "ok": True,
        "schema": SEMANTIC_ANNOTATION_SCHEMA,
        "payload_sha256": retained,
    }


def _build(linear_ir: dict[str, Any]) -> dict[str, Any]:
    nodes = linear_ir["nodes"]
    references = linear_ir["references"]
    owner_by_reference: dict[str, str] = {}
    annotated_nodes: list[dict[str, Any]] = []
    for node in nodes:
        node_id = str(node["id"])
        symbol_ids: list[str] = []
        for reference_id_raw in node["reference_ids"]:
            reference_id = str(reference_id_raw)
            if reference_id in owner_by_reference:
                raise SemanticAnnotationError(
                    "linear reference has more than one annotation owner"
                )
            owner_by_reference[reference_id] = node_id
            symbol_ids.append(_symbol_id(reference_id))
        annotated_nodes.append(_annotated_node(node, symbol_ids))

    symbols: list[dict[str, Any]] = []
    for reference in references:
        reference_id = str(reference["id"])
        if reference_id not in owner_by_reference:
            raise SemanticAnnotationError("linear reference has no annotation owner")
        symbols.append(_annotated_symbol(reference, owner_by_reference[reference_id]))

    symbol_kind_counts: dict[str, int] = {}
    symbol_status_counts: dict[str, int] = {}
    for symbol in symbols:
        kind = str(symbol["kind"])
        status = str(symbol["annotation_status"])
        symbol_kind_counts[kind] = symbol_kind_counts.get(kind, 0) + 1
        symbol_status_counts[status] = symbol_status_counts.get(status, 0) + 1
    opaque_count = sum(
        node["operation"]["kind"] == "opaque_boundary"
        for node in annotated_nodes
    )
    return {
        "ok": True,
        "schema": SEMANTIC_ANNOTATION_SCHEMA,
        "producer": {
            "implementation": "python_phase5_source_annotation",
            "contract": SEMANTIC_ANNOTATION_SCHEMA,
        },
        "compatibility": {
            "policy": "exact_linear_ir_match",
            "input_decompiler_schema": decompiler.DECOMPILER_IR_SCHEMA,
            "unknown_annotation_schema": "reject",
            "unknown_v1_field": "reject",
            "semantic_alias_policy": "unresolved_without_source_bound_evidence",
            "message_policy": "coordinate_and_raw_identity_only",
            "state_policy": "numeric_storage_coordinate_only",
            "resource_policy": "literal_source_identity_only",
        },
        "input": {
            "linear_ir_schema": decompiler.DECOMPILER_IR_SCHEMA,
            "linear_ir_sha256": linear_ir["payload_sha256"],
        },
        "source_identity": copy.deepcopy(linear_ir.get("source_identity", {})),
        "unresolved_semantic_categories": [
            "character",
            "event_role",
            "place",
            "state_meaning",
        ],
        "nodes": annotated_nodes,
        "symbols": symbols,
        "coverage": {
            "linear_node_count": len(nodes),
            "node_annotation_count": len(annotated_nodes),
            "typed_operation_count": len(annotated_nodes) - opaque_count,
            "opaque_operation_count": opaque_count,
            "reference_count": len(references),
            "symbol_annotation_count": len(symbols),
            "symbol_kind_counts": dict(sorted(symbol_kind_counts.items())),
            "symbol_status_counts": dict(sorted(symbol_status_counts.items())),
            "semantic_alias_count": 0,
            "all_linear_nodes_annotated": len(annotated_nodes) == len(nodes),
            "all_references_annotated": len(symbols) == len(references),
        },
    }


def _annotated_node(
    node: dict[str, Any], symbol_ids: list[str]
) -> dict[str, Any]:
    source = node["source"]
    statement = node["statement"]
    if node["kind"] == "statement":
        operation = {
            "kind": "typed_instruction",
            "token": str(statement["op"]),
            "command_id": int(statement["command_id"]),
            "annotation_status": "typed_phase1_4_operation",
            "semantic_alias": None,
        }
    else:
        operation = {
            "kind": "opaque_boundary",
            "token": str(statement["boundary"]),
            "annotation_status": "byte_preserving_unresolved",
            "semantic_alias": None,
        }
    return {
        "id": f"annotation_{int(source['start']):08x}",
        "linear_node_id": str(node["id"]),
        "source": {
            "entry": str(source.get("entry", "")),
            "region": str(source["region"]),
            "start": int(source["start"]),
            "end": int(source["end"]),
            "raw_sha256": str(source["raw_sha256"]),
        },
        "evidence_status": str(node["evidence_status"]),
        "operation": operation,
        "symbol_ids": symbol_ids,
    }


def _annotated_symbol(
    reference: dict[str, Any], owner_node_id: str
) -> dict[str, Any]:
    reference_id = str(reference["id"])
    kind = str(reference["kind"])
    if kind not in REFERENCE_KINDS:
        raise SemanticAnnotationError(
            f"unsupported source reference kind: {kind}"
        )
    value = reference.get("value")
    if not isinstance(value, dict):
        raise SemanticAnnotationError("source reference value is not an object")
    source_offset = int(reference["source_offset"])
    canonical_name, identity, status = _symbol_identity(
        kind, source_offset, value
    )
    return {
        "id": _symbol_id(reference_id),
        "reference_id": reference_id,
        "linear_node_id": owner_node_id,
        "kind": kind,
        "source_offset": source_offset,
        "canonical_name": canonical_name,
        "identity": identity,
        "annotation_status": status,
        "semantic_alias": None,
    }


def _symbol_identity(
    kind: str, source_offset: int, value: dict[str, Any]
) -> tuple[str, dict[str, Any], str]:
    if kind == "code":
        target = value.get("target_offset")
        if isinstance(target, int) and not isinstance(target, bool) and target >= 0:
            return (
                f"code[0x{target:08X}]",
                {
                    key: copy.deepcopy(value[key])
                    for key in (
                        "kind",
                        "target_offset",
                        "target_region",
                        "in_code",
                        "aligned",
                    )
                    if key in value
                },
                "numeric_code_coordinate",
            )
        return (
            f"code@0x{source_offset:08X}",
            {},
            "unresolved_reference_shape",
        )
    if kind == "message":
        identity = {
            key: copy.deepcopy(value[key])
            for key in ("kind", "end_offset", "raw_sha256", "region")
            if key in value
        }
        return (
            f"message@0x{source_offset:08X}",
            identity,
            "raw_message_coordinate",
        )
    if kind == "resource":
        name = value.get("name", value.get("source_name"))
        identity = {
            key: copy.deepcopy(value[key])
            for key in (
                "name",
                "source_name",
                "resource_kind",
                "archive_candidates",
            )
            if key in value
        }
        if isinstance(name, str) and name:
            return (
                f"resource[{json.dumps(name, ensure_ascii=False)}]",
                identity,
                "literal_resource_identity",
            )
        return (
            f"resource@0x{source_offset:08X}",
            identity,
            "unresolved_reference_shape",
        )

    storage = value.get("storage")
    index = value.get("index")
    identity = {
        key: copy.deepcopy(value[key])
        for key in ("storage", "bank", "index", "count", "access")
        if key in value
    }
    if isinstance(storage, str) and storage and _is_display_atom(index):
        rendered_index = _display_atom(index)
        bank = value.get("bank")
        if storage.startswith("banked_") and _is_display_atom(bank):
            canonical = (
                f"{storage}[bank={_display_atom(bank)},index={rendered_index}]"
            )
        else:
            canonical = f"{storage}[{rendered_index}]"
        return canonical, identity, "numeric_state_coordinate"
    return (
        f"state@0x{source_offset:08X}",
        identity,
        "unresolved_reference_shape",
    )


def _symbol_id(reference_id: str) -> str:
    return f"symbol_{reference_id}"


def _is_display_atom(value: Any) -> bool:
    return (
        isinstance(value, int)
        and not isinstance(value, bool)
        or isinstance(value, str)
        and INTEGER_TEXT.fullmatch(value) is not None
    )


def _display_atom(value: Any) -> str:
    if isinstance(value, int) and not isinstance(value, bool):
        return str(value)
    text = str(value)
    if INTEGER_TEXT.fullmatch(text):
        return text
    return json.dumps(text, ensure_ascii=False)


def main() -> None:
    parser = argparse.ArgumentParser(
        description=(
            "Annotate a validated linear MES decompiler IR with deterministic "
            "source-qualified numeric and literal identities."
        )
    )
    parser.add_argument("linear_ir", type=Path)
    parser.add_argument("output", type=Path, nargs="?")
    args = parser.parse_args()
    linear_ir = json.loads(args.linear_ir.read_text(encoding="utf-8"))
    document = annotate(linear_ir)
    encoded = json.dumps(
        document,
        ensure_ascii=False,
        allow_nan=False,
        sort_keys=True,
        separators=(",", ":"),
    )
    if args.output is not None:
        if args.output.resolve() == args.linear_ir.resolve():
            raise SemanticAnnotationError(
                "semantic annotation output must not replace its linear input"
            )
        args.output.write_text(encoded + "\n", encoding="utf-8")
    print(
        "MES_SEMANTIC_ANNOTATION_PASS "
        f"schema={document['schema']} entry={document['source_identity'].get('entry', '')} "
        f"nodes={document['coverage']['node_annotation_count']} "
        f"symbols={document['coverage']['symbol_annotation_count']} "
        f"aliases={document['coverage']['semantic_alias_count']} "
        f"payload_sha256={document['payload_sha256']}"
    )


if __name__ == "__main__":
    main()
