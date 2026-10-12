"""Resource references from the authority's bounded marker-envelope scan."""

from __future__ import annotations

from typing import Any

from mes_analysis_common import find_region
from mes_instruction_ir import decode_resource_marker_ir


_RESOURCE_KINDS = {
    "mmo_resource_marker": ("mmo", ("mmo.arc",)),
    "ax_resource_marker": ("ax", ("data.arc",)),
    "voice_marker": ("voice", ("voice.arc", "tina1.arc", "tina2.arc")),
    "inline_script_execution": ("mes_script", ("mes.arc",)),
}
_STRING_FIELDS = (
    "native_audible_output", "native_audible_evidence", "native_host_device_output",
    "tool_preview_semantics", "native_active_surface_storage",
    "native_active_surface_identity", "execution_role", "native_loader_argument",
    "native_loader_argument_semantics", "native_payload_semantics",
    "native_context_restore", "tool_execution_semantics",
)
_INTEGER_FIELDS = (
    "presentation_subcommand", "outer_command", "native_active_surface_state_offset",
    "native_active_surface_bank", "native_active_surface_storage_index",
    "execution_selector", "data_archive_index",
)


def _append_resource_reference(
    instruction: dict[str, Any], strict_indexed: bool, output: list[dict[str, Any]],
) -> None:
    op = instruction.get("op", "")
    if op not in _RESOURCE_KINDS:
        return
    operands = instruction.get("operands", [])
    if not operands or not isinstance(operands[0], dict):
        return
    operand = operands[0]
    if operand.get("type", "") != "resource_name":
        return
    name = str(operand.get("name", ""))
    if not name:
        return
    kind, archives = _RESOURCE_KINDS[op]
    reference = {
        "source_offset": int(instruction.get("source_offset", -1)),
        "region": str(instruction.get("region", "unassigned")),
        "op": op,
        "resource_kind": kind,
        "name": name,
        "source_name": str(operand.get("source_name", name)),
        "archive_candidates": list(archives),
        "boundary": "strict_indexed" if strict_indexed else "bounded_envelope_scan",
        "native_semantics": str(operand.get(
            "native_consumer_semantics", operand.get("native_playback_semantics", "unresolved"),
        )),
    }
    reference.update({key: str(operand[key]) for key in _STRING_FIELDS if key in operand})
    reference.update({key: int(operand[key]) for key in _INTEGER_FIELDS if key in operand})
    if "native_default_origin_arguments" in operand:
        reference["native_default_origin_arguments"] = list(operand["native_default_origin_arguments"])
    output.append(reference)


def scan_resource_references(
    code: bytes, instruction_starts: set[int], ranges: list[dict[str, Any]],
) -> list[dict[str, Any]]:
    """Scan the whole code and label each marker by its start-point boundary.

    Successful envelopes own their bytes even across an analysis-region edge.
    Failed candidates advance one byte, matching the authority's resource scan.
    This scan records references only; it does not turn payload into commands.
    """
    output: list[dict[str, Any]] = []
    offset = 0
    while offset < len(code):
        if code[offset] not in (0x08, 0x09, 0x0D):
            offset += 1
            continue
        marker = decode_resource_marker_ir(code, offset, len(code))
        if not marker.get("matched", False) or not marker.get("result", {}).get("ok", False):
            offset += 1
            continue
        instruction = dict(marker["result"])
        instruction["region"] = find_region(offset, ranges)
        _append_resource_reference(instruction, offset in instruction_starts, output)
        offset = max(offset + 1, int(instruction["end_offset"]))
    return output
