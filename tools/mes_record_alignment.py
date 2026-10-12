"""Exact structural record coverage, matching the GDScript alignment audit.

Structural expressions retain unresolved stack results without changing their
record boundaries. A decode failure still owns one byte-preserving opaque tail,
so a successful coverage audit is not a claim of complete native semantics.
"""

from __future__ import annotations

from typing import Any

from mes_analysis_common import MAX_REGION_INSTRUCTIONS, analysis_regions, opaque_region_tail
from mes_instruction_ir import decode_region_ir


SCHEMA = "kakyu_mes_record_alignment_audit/v1"
SAMPLE_LIMIT = 24


def _compound_family(instruction: dict[str, Any]) -> str:
    if "native_payload_boundary" in instruction:
        return "opaque_native_stream_branch_guard"
    if "native_record_consumption" in instruction:
        return instruction["native_record_consumption"]
    if "native_stream_consumption" in instruction and "native_stream_probe" not in instruction:
        return instruction["native_stream_consumption"]
    if instruction.get("op") == "mmo_resource_marker":
        return "typed_presentation_subcommand_9_mmo_record"
    operands = instruction.get("operands", [])
    if operands and operands[0].get("type") == "record_list":
        return f"typed_record_list_command_{instruction['command_id']:02x}"
    return ""


def build_record_alignment(container: dict[str, Any]) -> dict[str, Any]:
    """Audit a canonical container produced by mes_analyzer_handoff."""
    if container.get("schema") != "ai5_mes_container/v1":
        return {"ok": False, "error": "A valid MES container document is required."}
    code = container.get("_bytecode")
    if not isinstance(code, bytes):
        return {"ok": False, "error": "MES container bytecode is missing."}
    regions = analysis_regions(container)
    instruction_count = instruction_bytes = compound_record_count = compound_record_bytes = 0
    opaque_bytes = framed_bytes = total_bytes = 0
    families: dict[str, int] = {}
    family_bytes: dict[str, int] = {}
    opaque: list[dict[str, Any]] = []
    samples: list[dict[str, Any]] = []
    failures: list[str] = []
    for region in regions:
        start, end, region_id = region["offset"], region["end_offset"], region["id"]
        total_bytes += end - start
        decoded = decode_region_ir(code, start, end, MAX_REGION_INSTRUCTIONS, structural=True)
        cursor = start
        for instruction in decoded.get("instructions", []):
            record_start = instruction.get("source_offset", -1)
            record_end = instruction.get("end_offset", -1)
            raw_hex = code[record_start:record_end].hex() if record_start >= 0 and record_end >= record_start else ""
            if (
                record_start != cursor or record_end <= record_start or record_end > end
                or instruction.get("byte_length", -1) != record_end - record_start
                or instruction.get("raw_hex", "") != raw_hex
            ):
                failures.append(f"{region_id} instruction 0x{record_start:X}..0x{record_end:X} is not an exact contiguous record")
                break
            length = record_end - record_start
            instruction_count += 1
            instruction_bytes += length
            framed_bytes += length
            family = _compound_family(instruction)
            if family:
                compound_record_count += 1
                compound_record_bytes += length
                families[family] = families.get(family, 0) + 1
                family_bytes[family] = family_bytes.get(family, 0) + length
                if len(samples) < SAMPLE_LIMIT:
                    samples.append({"region": region_id, "source_offset": record_start, "end_offset": record_end, "family": family})
            cursor = record_end
        if not decoded.get("ok", False):
            opaque_start = decoded.get("decoded_end_offset", cursor)
            if opaque_start != cursor or opaque_start < start or opaque_start >= end:
                failures.append(f"{region_id} structural stop does not begin at the framed cursor")
            else:
                boundary = opaque_region_tail(code, region_id, opaque_start, end, decoded.get("error", "structural decode stopped"))
                opaque.append(boundary)
                opaque_bytes += boundary["byte_length"]
                framed_bytes += boundary["byte_length"]
                cursor = end
        if cursor != end:
            failures.append(f"{region_id} coverage ends at 0x{cursor:X} instead of 0x{end:X}")
    if total_bytes != len(code):
        failures.append(f"Container regions cover {total_bytes} of {len(code)} code bytes")
    if framed_bytes != total_bytes:
        failures.append(f"Typed and opaque records cover {framed_bytes} of {total_bytes} region bytes")
    return {
        "ok": not failures, "schema": SCHEMA, "region_count": len(regions),
        "code_bytes": len(code), "framed_bytes": framed_bytes,
        "instruction_count": instruction_count, "instruction_bytes": instruction_bytes,
        "compound_record_count": compound_record_count, "compound_record_bytes": compound_record_bytes,
        "compound_families": families, "compound_family_bytes": family_bytes,
        "opaque_boundary_count": len(opaque), "opaque_bytes": opaque_bytes, "opaque_boundaries": opaque,
        "samples": samples, "failure_count": len(failures), "failures": failures,
        "coverage_policy": "every_region_byte_exactly_one_typed_instruction_or_opaque_tail",
    }
