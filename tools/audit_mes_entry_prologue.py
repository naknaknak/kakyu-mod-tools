"""Test whether command 0x17 is the address-table entry prologue.

The decoders call 0x17 ``entry_label`` and hand back an ``entry_index`` operand,
which is a name the code chose rather than one the corpus proved.  Executable
audit v101 confirms something the name does not suggest: the handler assembles
the four operand bytes into delayed state DWORD ``+0x2174`` and clones the
active string into the saved execution context, so 0x17 is not an inert marker.

This audit asks the one question that decides the name, over every entry of an
authoritative archive: **is a 0x17 record always the first instruction of an
address-table entry, carrying that entry's own index?**

It reports four counts, because a claim this strong is only worth making if its
exceptions are named:

``entries``          address-table entries across the archive
``prologues``        0x17 records that are the first instruction of one, with a
                     matching index
``entries_without``  entries whose first instruction is not such a record
``outside``          0x17 records anywhere else, listed individually

The bootstrap prefix before entry zero is not an address-table entry and is
expected to carry no prologue, so it is excluded rather than counted as a miss.

Usage:
    py tools/audit_mes_entry_prologue.py --arc <mes.arc> [--json report.json]
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

sys.path.insert(0, str(Path(__file__).resolve().parent))

from audit_mes_framing_equivalence import container_regions
from extract_kakyu_arc import read_entries
from mes_archive_ir import parse_mes_container
from mes_partial_decoder import MesDecodeError, decode_instruction


SCHEMA = "kakyu_mes_entry_prologue_audit/v1"
ENTRY_PROLOGUE_COMMAND = 0x17


def audit_payload(payload: bytes, entry_name: str) -> dict[str, Any]:
    """Every 0x17 in one MES payload, classified by where it sits."""
    container = parse_mes_container(payload)
    header = container["header"]
    code = payload[header["codeOffset"] :]
    entry_offsets: list[int] = header["entryOffsets"]
    regions = container_regions(container)
    # container_regions prepends the bootstrap only when it has bytes, so the
    # address-table index of a region is its position minus that prefix. With no
    # address table at all the bootstrap is the whole code and there are no entry
    # regions -- which is `LIBLARY.LIB`, and reading its one region as entry zero
    # would invent both a missing prologue and a stray one.
    bootstrap_end = entry_offsets[0] if entry_offsets else header["codeSize"]
    has_bootstrap = bootstrap_end > 0
    prologues = 0
    entries_without: list[dict[str, Any]] = []
    outside: list[dict[str, Any]] = []

    for region_index, (start, end) in enumerate(regions):
        is_bootstrap = has_bootstrap and region_index == 0
        entry_index = region_index - (1 if has_bootstrap else 0)
        cursor, position, matched = start, 0, False
        while cursor < end:
            try:
                instruction = decode_instruction(code, cursor, end)
            except MesDecodeError:
                break
            if instruction is None:
                break
            if instruction["commandId"] == ENTRY_PROLOGUE_COMMAND:
                value = int(instruction["operands"][0]["value"])
                if not is_bootstrap and position == 0 and value == entry_index:
                    prologues += 1
                    matched = True
                else:
                    outside.append(
                        {
                            "entry": entry_name,
                            "offset": cursor,
                            "position": position,
                            "value": value,
                            "region": "bootstrap" if is_bootstrap else f"entry {entry_index}",
                        }
                    )
            position += 1
            cursor = instruction["endOffset"]
        if not is_bootstrap and not matched:
            entries_without.append({"entry": entry_name, "index": entry_index, "offset": start})

    return {
        "entries": len(entry_offsets),
        "prologues": prologues,
        "entries_without": entries_without,
        "outside": outside,
    }


def audit_archive(arc_path: Path, limit: int | None = None) -> dict[str, Any]:
    archive = arc_path.read_bytes()
    totals = {"entries": 0, "prologues": 0}
    entries_without: list[dict[str, Any]] = []
    outside: list[dict[str, Any]] = []
    failed: list[dict[str, str]] = []
    scanned = 0

    for name, offset, size in read_entries(arc_path):
        if limit is not None and scanned >= limit:
            break
        scanned += 1
        try:
            row = audit_payload(archive[offset : offset + size], name)
        except ValueError as error:
            failed.append({"entry": name, "error": str(error)})
            continue
        totals["entries"] += row["entries"]
        totals["prologues"] += row["prologues"]
        entries_without.extend(row["entries_without"])
        outside.extend(row["outside"])

    return {
        "schema": SCHEMA,
        "archive": str(arc_path),
        "scanned_entries": scanned,
        "address_table_entries": totals["entries"],
        "prologues": totals["prologues"],
        "entries_without_prologue": entries_without,
        "prologues_outside_entry_start": outside,
        "failed": failed,
        "every_entry_has_one": (
            totals["entries"] == totals["prologues"] and not entries_without and not failed
        ),
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--arc", type=Path, required=True, help="an authoritative MES archive")
    parser.add_argument("--json", type=Path, help="write the full report here")
    parser.add_argument("--limit", type=int, help="scan at most N archive entries")
    arguments = parser.parse_args(argv)

    if arguments.limit is not None and arguments.limit <= 0:
        print("MES_ENTRY_PROLOGUE_ERROR: --limit must be positive", file=sys.stderr)
        return 2
    if not arguments.arc.is_file():
        print(f"MES_ENTRY_PROLOGUE_ERROR: archive does not exist: {arguments.arc}", file=sys.stderr)
        return 2

    report = audit_archive(arguments.arc, arguments.limit)
    print(
        f"MES_ENTRY_PROLOGUE schema={SCHEMA}"
        f" scanned={report['scanned_entries']}"
        f" entries={report['address_table_entries']}"
        f" prologues={report['prologues']}"
        f" missing={len(report['entries_without_prologue'])}"
        f" outside={len(report['prologues_outside_entry_start'])}"
        f" every_entry_has_one={str(report['every_entry_has_one']).lower()}"
    )
    for row in report["prologues_outside_entry_start"]:
        print(f"  outside: {row['entry']} {row['region']} at 0x{row['offset']:X} value={row['value']}")
    for row in report["entries_without_prologue"][:20]:
        print(f"  missing: {row['entry']} entry {row['index']} at 0x{row['offset']:X}")
    if arguments.json is not None:
        arguments.json.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(f"Report: {arguments.json.resolve()}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
