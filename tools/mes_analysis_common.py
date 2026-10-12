"""Shared code-region and opaque-tail shapes for the analyzer handoff."""

from __future__ import annotations

import hashlib
from typing import Any


MAX_REGION_INSTRUCTIONS = 500000
ANALYSIS_SCHEMA = "kakyu_mes_analysis/v19"


def analysis_regions(container: dict[str, Any]) -> list[dict[str, Any]]:
    """Bootstrap followed by address-table entries, in original byte order."""
    regions: list[dict[str, Any]] = []
    bootstrap = container.get("bootstrap", {})
    if bootstrap.get("size", 0) > 0:
        regions.append({"id": "bootstrap", "offset": bootstrap["offset"], "end_offset": bootstrap["end_offset"]})
    regions.extend(
        {"id": entry["id"], "offset": entry["offset"], "end_offset": entry["end_offset"]}
        for entry in container.get("entries", [])
    )
    if not regions and container.get("header", {}).get("code_size", 0) > 0:
        regions.append({"id": "zero_table_code", "offset": 0, "end_offset": container["header"]["code_size"]})
    return regions


def opaque_region_tail(code: bytes, region: str, start: int, end: int, reason: str) -> dict[str, Any]:
    """A failed decode owns the remaining bytes; none may become instructions."""
    raw = code[start:end]
    return {
        "type": "opaque_region_tail", "region": region,
        "source_offset": start, "end_offset": end, "byte_length": end - start,
        "raw_hex": raw.hex(), "raw_sha256": hashlib.sha256(raw).hexdigest(),
        "boundary": "byte_preserving_fail_closed", "reason": reason,
    }


def find_region(offset: int, ranges: list[dict[str, Any]]) -> str:
    """Match the source coordinate to the first owning region."""
    for region in ranges:
        if region["offset"] <= offset < region["end_offset"]:
            return region["id"]
    return "unassigned"
