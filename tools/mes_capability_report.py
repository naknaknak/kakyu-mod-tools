"""Capability counts over canonical analyzer components and attached evidence.

This is a summary, not validation of a handoff or its optional evidence. The
complete handoff producer must validate inputs before publishing that contract.
"""

from __future__ import annotations

from collections.abc import Sequence
from copy import deepcopy
from typing import Any


def _count_values(rows: Sequence[Any], key: str) -> dict[str, int]:
    counts: dict[str, int] = {}
    for row in rows:
        if not isinstance(row, dict):
            continue
        value = row.get(key, "unresolved")
        if not isinstance(value, str):
            raise ValueError(f"Canonical capability label {key!r} must be a string.")
        counts[value] = counts.get(value, 0) + 1
    return counts


def build_capability_report(
    typed_ir: dict[str, Any], alignment: dict[str, Any], references: dict[str, Any],
    graphs: Sequence[dict[str, Any]] = (),
    call_evidence: Sequence[dict[str, Any]] = (),
    trace_evidence: Sequence[dict[str, Any]] = (),
) -> dict[str, Any]:
    """Summarize string-valued kinds/schemas without decoding or promoting bytes.

    Strict instructions and opaque boundaries describe the analysis view;
    compound families retain the independent structural alignment view. Counts
    of attached evidence describe its presence, not confirmed native meaning.
    """
    return {
        "phase_range": [1, 2, 3, 4],
        "completion_scope": "safe_reproducible_low_level_structure",
        "typed_instruction_ops": _count_values(typed_ir.get("instructions", []), "op"),
        "compound_record_families": deepcopy(alignment.get("compound_families", {})),
        "opaque_boundary_types": _count_values(typed_ir.get("opaque_boundaries", []), "type"),
        "code_reference_kinds": _count_values(references.get("code", []), "kind"),
        "resource_reference_kinds": _count_values(references.get("resources", []), "resource_kind"),
        "cfg_count": len(graphs),
        "call_evidence_schemas": _count_values(call_evidence, "schema"),
        "trace_evidence_schemas": _count_values(trace_evidence, "schema"),
        "semantic_policy": "numeric_or_source_qualified_only",
        "remaining_numeric_or_unresolved_meanings": [
            "state_and_bank_indices",
            "native_selector_arguments",
            "choice_and_routine_results_without_source_qualified_labels",
            "native_pixel_audio_and_input_effects",
            "outer_host_handoff_consumers",
        ],
        "product_ui_data": "forbidden",
        "source_mutation": "forbidden",
    }
