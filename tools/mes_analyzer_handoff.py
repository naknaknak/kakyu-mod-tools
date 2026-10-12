"""Build complete Phase 1-4 analyzer handoffs with explicit Python provenance.

The authority is MA-09's frozen corpus fingerprint, and the fingerprint is a
SHA-256 over one line per entry naming that entry's handoff payload hash. So
reproducing it is not a port of one module: the payload aggregates the
container, the record-alignment audit, the typed IR, four reference lists and a
capability report, and every field name, value and ordering has to match.

``build_components`` retains the component-only API. ``build_handoff`` also
validates and preserves attached evidence, source identity and compatibility,
then signs the complete payload with its actual Python producer identity.
``baseline_projection`` changes only that producer name for a labelled
comparison with the historical GDScript fingerprint; it is not an export.

Fingerprints use the handoff's own normalization: dictionaries sorted by key,
byte arrays as ``{"$packed_byte_array_hex": ...}``, then Godot's
``JSON.stringify(value, "", true, true)`` byte-for-byte over the supported
transport subset. The shared serializer also reproduces full-precision floats;
ordinary ``json.dumps`` does not guarantee the same decimal spelling.
"""

from __future__ import annotations

import hashlib
import json
import struct
from copy import deepcopy
from typing import Any

from mes_analysis_common import ANALYSIS_SCHEMA, MAX_REGION_INSTRUCTIONS, analysis_regions, opaque_region_tail
from mes_handoff_transport import canonical_json_bytes, normalize as normalize_transport


# Read from content_core/content_core_version.gd rather than assumed; the
# container schema is one of the few that is not `kakyu_`-prefixed.
CONTAINER_SCHEMA = "ai5_mes_container/v1"
PYTHON_PRODUCER = "python_phase1_4"
GDSCRIPT_PRODUCER = "godot_gdscript_phase1_4"
BASELINE_PROJECTION_POLICY = "producer_implementation_only/v1"

# Components the authority's payload carries. A name here that build_components
# does not return is reported as not produced, never as equal.
COMPONENTS = ("container", "record_alignment", "typed_ir", "references", "capability_report")


class HandoffError(ValueError):
    pass


def normalize(value: Any) -> Any:
    """The handoff's normalization rule, so a Python fingerprint is comparable."""
    return normalize_transport(value)


def fingerprint(value: Any) -> str:
    return hashlib.sha256(canonical_json_bytes(value)).hexdigest()


def build_container(payload: bytes, source: dict[str, Any] | None = None) -> dict[str, Any]:
    """The container component, in the authority's field names and shapes.

    This deliberately re-derives the header rather than reusing
    ``mes_archive_ir.parse_mes_container``: that parser answers a different
    question in camelCase, and mapping its names would hide a divergence in the
    mapping instead of reporting it here.
    """
    if len(payload) < 4:
        raise HandoffError("MES entry is smaller than the 4-byte entry count.")
    entry_count = struct.unpack_from("<I", payload, 0)[0]
    if entry_count > (len(payload) - 4) // 4:
        raise HandoffError("MES address table exceeds the entry data.")
    code_offset = 4 + entry_count * 4
    code_size = len(payload) - code_offset

    entry_offsets: list[int] = []
    for index in range(entry_count):
        offset = struct.unpack_from("<I", payload, 4 + index * 4)[0]
        if offset >= code_size:
            raise HandoffError(f"MES address {index} is outside code size 0x{code_size:X}.")
        if index > 0 and offset <= entry_offsets[index - 1]:
            raise HandoffError(f"MES addresses are not strictly increasing at index {index}.")
        entry_offsets.append(offset)

    first_entry = entry_offsets[0] if entry_offsets else code_size
    entries = []
    for index, offset in enumerate(entry_offsets):
        end_offset = entry_offsets[index + 1] if index + 1 < entry_count else code_size
        entries.append(
            {
                "id": f"entry_{index:04d}",
                "index": index,
                "offset": offset,
                "file_offset": code_offset + offset,
                "end_offset": end_offset,
                "size": end_offset - offset,
            }
        )

    bytecode = payload[code_offset:]
    return {
        "schema": CONTAINER_SCHEMA,
        "header": {
            "entry_count": entry_count,
            "table_offset": 4,
            "table_size": entry_count * 4,
            "code_offset": code_offset,
            "code_size": code_size,
            "entry_offsets": entry_offsets,
            "offset_basis": "code_start",
        },
        "bootstrap": {
            "offset": 0,
            "file_offset": code_offset,
            "end_offset": first_entry,
            "size": first_entry,
        },
        "entries": entries,
        "entry_sha256": hashlib.sha256(payload).hexdigest(),
        "bytecode_sha256": hashlib.sha256(bytecode).hexdigest() if bytecode else "",
        "raw_hex": payload.hex(),
        "_bytecode": bytecode,
        "_source": dict(source or {}),
    }


def handoff_container_component(container: dict[str, Any]) -> dict[str, Any]:
    """The container exactly as the handoff embeds it, without local helpers."""
    return {
        key: value
        for key, value in container.items()
        if not key.startswith("_")
    }


def build_components(payload: bytes, source: dict[str, Any] | None = None) -> dict[str, Any]:
    """All five component dictionaries; not a complete handoff payload."""
    from mes_capability_report import build_capability_report
    from mes_record_alignment import SCHEMA as ALIGNMENT_SCHEMA, build_record_alignment
    from mes_references import build_references

    container = build_container(payload, source)
    alignment = build_record_alignment(container)
    if not alignment.get("ok", False) or alignment.get("schema") != ALIGNMENT_SCHEMA:
        raise HandoffError("MES record alignment is not complete for the handoff.")
    typed_ir = build_typed_ir(container)
    references = build_references(container, typed_ir)
    return {
        "container": handoff_container_component(container),
        "typed_ir": typed_ir,
        "record_alignment": alignment,
        "references": references,
        "capability_report": build_capability_report(typed_ir, alignment, references),
    }


def build_typed_ir(container: dict[str, Any]) -> dict[str, Any]:
    """Strict analysis-v19 instructions and byte-preserving opaque region tails."""
    from mes_instruction_ir import decode_region_ir

    code = container["_bytecode"]
    regions = analysis_regions(container)
    instructions: list[dict[str, Any]] = []
    diagnostics: list[dict[str, Any]] = []
    opaque: list[dict[str, Any]] = []
    for region in regions:
        decoded = decode_region_ir(code, region["offset"], region["end_offset"], MAX_REGION_INSTRUCTIONS)
        instructions.extend({**instruction, "region": region["id"]} for instruction in decoded["instructions"])
        if not decoded["ok"]:
            start, end = decoded["decoded_end_offset"], region["end_offset"]
            diagnostics.append({"region": region["id"], "source_offset": start, "error": decoded["error"]})
            opaque.append(opaque_region_tail(code, region["id"], start, end, decoded["error"]))
    return {
        "schema": ANALYSIS_SCHEMA, "complete": not diagnostics,
        "instructions": instructions, "diagnostics": diagnostics, "opaque_boundaries": opaque,
    }


def build_handoff(
    payload: bytes, source: dict[str, Any] | None = None, *,
    graphs: list[dict[str, Any]] | None = None,
    call_evidence: list[dict[str, Any]] | None = None,
    trace_evidence: list[dict[str, Any]] | None = None,
) -> dict[str, Any]:
    """Produce a signed v1 handoff with truthful Python producer identity.

    Attached CFG/call/trace evidence is validated and retained, not generated.
    Use baseline_projection only for an explicitly labelled comparison with
    the frozen GDScript producer; the actual output always names Python.
    """
    from mes_capability_report import build_capability_report
    from mes_handoff_contract import compatibility, validate_attachments, validate_components
    from validate_mes_analyzer_handoff import HANDOFF_SCHEMA

    try:
        if not isinstance(payload, bytes):
            raise HandoffError("MES handoff source must be bytes.")
        if source is not None and not isinstance(source, dict):
            raise HandoffError("MES handoff source identity must be a dictionary.")
        graphs = [] if graphs is None else graphs
        calls = [] if call_evidence is None else call_evidence
        traces = [] if trace_evidence is None else trace_evidence
        # Validate transport before recursive evidence inspection or copying.
        normalize([graphs, calls, traces])
        validate_attachments(graphs, calls, traces)
        components = build_components(payload)
        validate_components(components, payload)
        components["capability_report"] = build_capability_report(
            components["typed_ir"], components["record_alignment"], components["references"],
            graphs, calls, traces,
        )
        result = normalize({
            "ok": True, "schema": HANDOFF_SCHEMA,
            "producer": {"implementation": PYTHON_PRODUCER, "contract": HANDOFF_SCHEMA},
            "compatibility": compatibility(),
            "source_identity": {
                key: value for key, value in (source or {}).items()
                if key in ("archive", "entry", "source_kind", "archive_sha256")
            },
            **components, "cfg": deepcopy(graphs), "calls": deepcopy(calls), "traces": deepcopy(traces),
        })
        from validate_mes_analyzer_handoff import _find_product_ui_key
        if _find_product_ui_key(result) is not None:
            raise HandoffError("MES handoff contains product UI data.")
        result["payload_sha256"] = fingerprint(result)
        verify(result)
        return result
    except (ValueError, TypeError, KeyError, OverflowError, RecursionError) as failure:
        if isinstance(failure, HandoffError):
            raise
        raise HandoffError(str(failure)) from failure


def verify(handoff: dict[str, Any]) -> dict[str, Any]:
    """Validate a complete signed payload, including retained source boundaries."""
    from mes_handoff_contract import validate_payload
    try:
        return validate_payload(handoff)
    except (ValueError, TypeError, KeyError, OverflowError, RecursionError) as failure:
        if isinstance(failure, HandoffError):
            raise
        raise HandoffError(str(failure)) from failure


def to_json(handoff: dict[str, Any]) -> str:
    """Serialize only a verified handoff using the shared canonical transport."""
    from mes_handoff_transport import canonical_json_bytes
    verify(handoff)
    return canonical_json_bytes(handoff).decode("utf-8")


def baseline_projection(handoff: dict[str, Any]) -> dict[str, Any]:
    """Comparison-only projection: change exactly producer.implementation.

    The returned object is not the actual Python output and must be labelled
    with BASELINE_PROJECTION_POLICY by every report or comparison using it.
    The caller's actual producer and fingerprint remain unchanged.
    """
    verify(handoff)
    if handoff["producer"]["implementation"] != PYTHON_PRODUCER:
        raise HandoffError("Baseline projection requires an actual Python handoff.")
    projected = normalize(handoff)
    projected["producer"]["implementation"] = GDSCRIPT_PRODUCER
    projected.pop("payload_sha256")
    projected["payload_sha256"] = fingerprint(projected)
    return projected
