"""Validation for Python production of complete analyzer handoffs.

The legacy transport consumer remains available separately. These checks also
bind the complete producer's retained records to its source container and check
the attached evidence contract; they do not re-interpret native semantics.
"""

from __future__ import annotations

import hashlib
import re
from typing import Any

from mes_analysis_common import analysis_regions
from validate_mes_analyzer_handoff import (
    CALL_EVIDENCE_SCHEMAS, COMPONENT_SCHEMAS, HANDOFF_SCHEMA, TRACE_EVIDENCE_SCHEMAS,
    HandoffValidationError, _find_product_ui_key, validate as validate_transport_contract,
)


def _require(condition: bool, message: str) -> None:
    if not condition:
        raise HandoffValidationError(message)


def _rows(value: Any, message: str) -> list[dict[str, Any]]:
    _require(isinstance(value, list) and all(isinstance(row, dict) for row in value), message)
    return value


def compatibility() -> dict[str, Any]:
    return {
        "policy": "exact_component_schema_match", "unknown_handoff_schema": "reject",
        "unknown_component_schema": "reject", "unknown_v1_field": "ignore",
        "dictionary_key_encoding": "unique_string_key", "packed_byte_array_encoding": "hex_object",
        "component_schemas": {
            **COMPONENT_SCHEMAS, "accepted_call_evidence": list(CALL_EVIDENCE_SCHEMAS),
            "accepted_trace_evidence": list(TRACE_EVIDENCE_SCHEMAS),
        },
    }


def validate_attachments(graphs: Any, calls: Any, traces: Any) -> None:
    for graph in _rows(graphs, "MES handoff contains a non-dictionary CFG."):
        _require(graph.get("ok") is True and graph.get("schema") == COMPONENT_SCHEMAS["reference_graph"],
                 "MES handoff CFG schema is unsupported.")
        nodes = _rows(graph.get("nodes", []), "MES handoff CFG node is not a dictionary.")
        edges = _rows(graph.get("edges", []), "MES handoff CFG edge is not a dictionary.")
        _require(all(isinstance(node.get("id", ""), str) for node in nodes), "MES CFG node id must be a string.")
        ids = {node.get("id", "") for node in nodes}
        for edge in edges:
            _require(isinstance(edge.get("from_id", ""), str) and isinstance(edge.get("to_id", ""), str),
                     "MES CFG edge ids must be strings.")
            _require(edge.get("from_id", "") in ids and edge.get("to_id", "") in ids,
                     "MES handoff CFG contains a dangling edge.")
    for rows, schemas, kind in ((calls, CALL_EVIDENCE_SCHEMAS, "call"), (traces, TRACE_EVIDENCE_SCHEMAS, "trace")):
        for row in _rows(rows, f"MES {kind} evidence is not a dictionary."):
            _require(row.get("schema") in schemas, f"MES {kind} evidence schema is unsupported.")
    _require(_find_product_ui_key([graphs, calls, traces]) is None, "MES evidence contains product UI data.")


def _record_bounds(record: dict[str, Any], code: bytes) -> tuple[int, int]:
    start, end = record.get("source_offset"), record.get("end_offset")
    _require(type(start) is int and type(end) is int and 0 <= start < end <= len(code),
             "MES handoff record boundary changed.")
    _require(record.get("byte_length") == end - start and record.get("raw_hex") == code[start:end].hex(),
             "MES handoff record bytes changed.")
    return start, end


def _opaque_bounds(record: dict[str, Any], code: bytes) -> tuple[int, int]:
    start, end = _record_bounds(record, code)
    _require(record.get("boundary") == "byte_preserving_fail_closed"
             and record.get("raw_sha256") == hashlib.sha256(code[start:end]).hexdigest(),
             "MES analysis opaque boundary is not byte preserving.")
    return start, end


def validate_components(components: dict[str, Any], raw: bytes) -> None:
    from mes_analyzer_handoff import build_container, handoff_container_component

    expected = build_container(raw)
    container = components.get("container")
    _require(container == handoff_container_component(expected), "MES container reconstruction or source hash changed.")
    code = expected["_bytecode"]
    typed = components.get("typed_ir")
    _require(isinstance(typed, dict) and typed.get("schema") == COMPONENT_SCHEMAS["analysis"],
             "A current MES typed IR is required.")
    instructions = _rows(typed.get("instructions"), "MES analysis contains a non-dictionary instruction.")
    opaque = _rows(typed.get("opaque_boundaries"), "MES opaque boundaries must be dictionaries.")
    diagnostics = _rows(typed.get("diagnostics"), "MES diagnostics must be dictionaries.")
    _require(type(typed.get("complete")) is bool and typed["complete"] == (not diagnostics),
             "MES analysis completion status changed.")
    owned = {region["id"]: region for region in analysis_regions(expected)}
    spans = []
    for records, is_opaque in ((instructions, False), (opaque, True)):
        for record in records:
            start, end = _opaque_bounds(record, code) if is_opaque else _record_bounds(record, code)
            if not is_opaque:
                _require(record.get("schema") == COMPONENT_SCHEMAS["instruction"],
                         "MES handoff instruction schema changed.")
            region = owned.get(record.get("region"))
            _require(region is not None and region["offset"] <= start < end <= region["end_offset"],
                     "MES handoff record crosses its source region.")
            spans.append((start, end))
    cursor = 0
    for start, end in sorted(spans):
        _require(start == cursor, "MES typed and opaque records have a gap or overlap.")
        cursor = end
    _require(cursor == len(code), "MES typed and opaque records do not cover the source code.")
    alignment = components.get("record_alignment")
    _require(isinstance(alignment, dict) and alignment.get("ok") is True
             and alignment.get("schema") == COMPONENT_SCHEMAS["record_alignment"],
             "MES record alignment is not complete for the handoff.")
    _require(alignment.get("code_bytes") == len(code) and alignment.get("framed_bytes") == len(code)
             and alignment.get("failure_count") == 0 and alignment.get("failures") == [],
             "MES record alignment coverage changed.")
    for boundary in _rows(alignment.get("opaque_boundaries"), "MES alignment opaque boundaries must be dictionaries."):
        _opaque_bounds(boundary, code)
    references = components.get("references")
    _require(isinstance(references, dict), "MES reference lists are missing.")
    for key in ("messages", "code", "state", "resources"):
        _rows(references.get(key), f"MES {key} references must be dictionaries.")


def validate_payload(handoff: dict[str, Any]) -> dict[str, Any]:
    from mes_analyzer_handoff import GDSCRIPT_PRODUCER, PYTHON_PRODUCER
    from mes_capability_report import build_capability_report
    from mes_handoff_transport import normalize

    normalized = normalize(handoff)
    _require(isinstance(normalized, dict) and normalized.get("ok") is True, "MES handoff is not a successful payload.")
    # Hash and component schema checks are shared with existing Python consumers.
    result = validate_transport_contract(normalized)
    producer = normalized.get("producer")
    _require(isinstance(producer, dict)
             and producer.get("contract") == HANDOFF_SCHEMA
             and producer.get("implementation") in (PYTHON_PRODUCER, GDSCRIPT_PRODUCER),
             "MES handoff producer identity is unsupported.")
    expected_compatibility = compatibility()
    _require(all(normalized["compatibility"].get(key) == value for key, value in expected_compatibility.items()),
             "MES handoff compatibility policy changed.")
    source = normalized.get("source_identity")
    _require(isinstance(source, dict) and all(isinstance(source[key], str)
             for key in ("archive", "entry", "source_kind", "archive_sha256") if key in source),
             "MES source identity values must be strings.")
    if "archive_sha256" in source:
        _require(re.fullmatch(r"[0-9a-f]{64}", source["archive_sha256"]) is not None, "MES source archive fingerprint is invalid.")
    container = normalized.get("container")
    _require(isinstance(container, dict) and isinstance(container.get("raw_hex"), str), "MES source bytes are missing.")
    _require(re.fullmatch(r"(?:[0-9a-f]{2})*", container["raw_hex"]) is not None, "MES source bytes are not canonical hex.")
    validate_components(normalized, bytes.fromhex(container["raw_hex"]))
    graphs, calls, traces = normalized.get("cfg"), normalized.get("calls"), normalized.get("traces")
    validate_attachments(graphs, calls, traces)
    expected_report = build_capability_report(
        normalized["typed_ir"], normalized["record_alignment"], normalized["references"], graphs, calls, traces,
    )
    _require(normalized.get("capability_report") == expected_report, "MES capability report counts or policy changed.")
    return result
