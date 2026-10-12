"""Audit archive entries that nothing in the shipped product names.

The dispatch naming audit establishes which entries no dispatch record, inline
script execution or host reference names. This tool takes that list and asks a
wider question of the shipped data: does the entry's name occur *at all* - in
any archive, in the configuration, or in the executable?

A zero-occurrence result across every shipped file is the strongest evidence
this repository can produce for the product goal's `unreachable_stored_route`
class. It is still evidence about naming, not about the native host's ability
to construct a name, and the report says so.

For an entry with an identical twin the report also records a structural
comparison, so a stored duplicate can be told apart from a stored orphan
without retaining any dialogue: message counts, the digest of the per-message
raw hashes, address-table size, and the per-op record counts.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import struct
from pathlib import Path
from typing import Any

import mes_basic_block_ir_v6
from build_event_analysis_inventory import fingerprint
from extract_kakyu_arc import read_entries
from payload_values import ORIGINAL_EXECUTABLE_SHA256, sha256_file

SCHEMA = "kakyu_unreferenced_entries_audit/v2"
NAMING_SCHEMA = "kakyu_mes_dispatch_naming_audit/v1"
ARCHIVE_SHA = "31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6"
DEFAULT_NAMING = Path("config/event_catalog/dispatch_naming_v1.json")
# Measured 2026-09-10 over the configured ELFIMAGE plus the unpatched executable.
EXPECTED_UNREFERENCED = [
    "DATETIME.MES", "EVENTL09.MES", "FLAGINI.MES", "FLAG_INC.MES",
    "M_TIME.MES", "OMAKE.MES", "SIZUKA44.MES", "_TEST.MES",
]
# The one EVENT-named entry among them, and the entry whose scene it repeats.
DUPLICATE_PAIRS = {"EVENTL09.MES": "EVENTL10.MES"}
# The executable is identified by content (its pinned sha256), never by file name.
EXECUTABLE_LABEL = "<executable>"
# Files the game itself rewrites: still scanned, but not pinned by size.
MUTABLE_FILES = {"AI5WIN.INI"}


def entry_profile(payload: bytes) -> dict[str, Any]:
    """Structure and message identity without retaining any message text."""
    count = struct.unpack_from("<I", payload, 0)[0]
    document = mes_basic_block_ir_v6.decode_mes(payload, {"entry": "compared"})
    seen: dict[int, dict[str, Any]] = {}
    for node in document.get("nodes", []):
        for row in node.get("instructions", []):
            seen.setdefault(int(row["sourceOffset"]), row)
    ops: dict[str, int] = {}
    digests: list[str] = []
    for offset in sorted(seen):
        row = seen[offset]
        op = str(row.get("op", ""))
        ops[op] = ops.get(op, 0) + 1
        if op == "text":
            raw = bytes.fromhex(str(row.get("rawHex", "")))
            digests.append(hashlib.sha256(raw).hexdigest())
    return {
        "entry_size": len(payload),
        "address_entries": count,
        "record_count": len(seen),
        "message_records": len(digests),
        "message_digest": hashlib.sha256("".join(digests).encode("ascii")).hexdigest(),
        "op_counts": dict(sorted(ops.items())),
    }


def scan_files(root: Path, names: list[str], executable: Path | None) -> list[dict[str, Any]]:
    targets = sorted(root.glob("*.arc")) + sorted(root.glob("*.INI"))
    if executable is not None:
        targets.append(executable)
    rows = []
    for path in targets:
        blob = path.read_bytes()
        lowered = blob.lower()
        row: dict[str, Any] = {
            "file": EXECUTABLE_LABEL if path == executable else path.name,
        }
        if path != executable and path.name.upper() in MUTABLE_FILES:
            row["mutable"] = True
        else:
            row["size"] = len(blob)
        row["occurrences"] = {name: lowered.count(name.lower().encode("ascii")) for name in names}
        rows.append(row)
    return rows


def audit(root: Path, naming: dict, executable: Path | None) -> dict[str, Any]:
    if naming.get("schema") != NAMING_SCHEMA or naming.get("archive_sha256") != ARCHIVE_SHA:
        raise ValueError("Unsupported or foreign dispatch naming audit")
    unreferenced = list(naming.get("unnamed_after_archive_forms", []))
    if unreferenced != EXPECTED_UNREFERENCED:
        raise ValueError("The set of entries no archive naming form reaches changed")
    if executable is not None and sha256_file(executable) != ORIGINAL_EXECUTABLE_SHA256:
        raise ValueError("The executable is not the pinned unpatched original")
    arc = root / "mes.arc"
    if hashlib.sha256(arc.read_bytes()).hexdigest() != ARCHIVE_SHA:
        raise ValueError("Original archive identity differs")
    payloads = {name: None for name in ()}
    blob = arc.read_bytes()
    payloads = {name: blob[offset:offset + size] for name, offset, size in read_entries(arc)}

    files = scan_files(root, unreferenced, executable)
    totals = {name: sum(row["occurrences"][name] for row in files) for name in unreferenced}
    unnamed = sorted(name for name, count in totals.items() if count == 0)

    duplicates = []
    for name, twin in sorted(DUPLICATE_PAIRS.items()):
        if name not in payloads or twin not in payloads:
            raise ValueError("A declared duplicate pair is not in the archive")
        left, right = entry_profile(payloads[name]), entry_profile(payloads[twin])
        duplicates.append({
            "entry": name, "twin": twin,
            "entry_profile": left, "twin_profile": right,
            "message_digest_equal": left["message_digest"] == right["message_digest"],
            "message_count_equal": left["message_records"] == right["message_records"],
            "address_entries_equal": left["address_entries"] == right["address_entries"],
            "op_count_differences": {
                op: [left["op_counts"].get(op, 0), right["op_counts"].get(op, 0)]
                for op in sorted(set(left["op_counts"]) | set(right["op_counts"]))
                if left["op_counts"].get(op, 0) != right["op_counts"].get(op, 0)
            },
        })
    for row in duplicates:
        if not (row["message_digest_equal"] and row["message_count_equal"]):
            raise ValueError("A declared duplicate pair no longer shares its message identity")

    report = {
        "schema": SCHEMA,
        "archive_sha256": ARCHIVE_SHA,
        "scanned_files": files,
        "unreferenced_entries": unreferenced,
        "total_occurrences": totals,
        "named_nowhere": unnamed,
        "executable_scanned": EXECUTABLE_LABEL if executable is not None else "",
        "executable_sha256": ORIGINAL_EXECUTABLE_SHA256 if executable is not None else "",
        "duplicates": duplicates,
        "evidence_boundary": (
            "zero occurrences of the name in every scanned file; this bounds naming,"
            " not the native host's ability to construct a name at runtime"
        ),
    }
    report["payload_sha256"] = fingerprint(report)
    return report


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("elfimage", type=Path)
    parser.add_argument("--naming", type=Path, default=DEFAULT_NAMING)
    parser.add_argument("--exe", type=Path)
    parser.add_argument("--check", type=Path, help="Reproduce an existing report exactly")
    parser.add_argument("--output", type=Path)
    arguments = parser.parse_args()
    report = audit(arguments.elfimage,
                   json.loads(arguments.naming.read_text(encoding="utf-8")),
                   arguments.exe)
    if arguments.check and json.loads(arguments.check.read_text(encoding="utf-8")) != report:
        raise ValueError("Tracked unreferenced-entry report does not reproduce")
    if arguments.output:
        arguments.output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n",
                                    encoding="utf-8")
    print(json.dumps({key: value for key, value in report.items()
                      if key not in ("scanned_files", "duplicates")}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
