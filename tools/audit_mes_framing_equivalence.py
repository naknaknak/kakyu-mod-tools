"""Measure whether the Python decoder reproduces the authoritative record framing.

Phase 1-4 authority is MA-09's measurement over the corpus, not the language
that computes it, so moving that authority to Python needs the measurement
repeated on the Python side rather than the code translated.  No tool compared
the two decoders: ``validate_mes_analyzer_handoff`` checks the *schema* of the
GDScript handoff, and ``audit_mes_decompiler_equivalence`` compares one Python
renderer against another, downstream of the handoff.  This crosses the line.

What is compared is the record framing itself - the exact ``[start, end)`` range
of every consumed instruction and of every byte-preserving opaque remainder -
because that is what the Phase 2 gate requires and what the authority is about.
Both sides emit the same canonical line list, so a digest mismatch reduces to
one coordinate:

    i <start> <end>    one decoded instruction, code-relative, decimal
    o <start> <end>    the undecoded remainder of a region

Regions are the container's own: the bootstrap prefix when it has bytes, then
the address-table entries in index order.  The Python seed always emits a
bootstrap node and the GDScript exporter omits an empty one, so an empty
bootstrap contributes no line on either side and the two still agree.

Two measures are reported, because one of them alone cannot plan the work.

*Sequential* framing equivalence asks whether Python reproduces a whole entry's
framing.  It is the real gate, and it is unforgiving: decoding stops at the
first command with no grammar, so one missing command reports the entry as
wholly divergent and hides every record after it.

*Per-record* agreement asks, for each authoritative record start, whether Python
frames that one record to the same end.  It sees past the first failure, so it
measures actual coverage and ranks the missing commands by how much of the
corpus each one blocks.  A command that appears once is not the same problem as
one that appears in every entry.

This audit reports the gap.  It does not close it, and a divergence is a
measurement rather than a failure: the Python decoder documents itself as
partial.  The exit code reflects whether the audit ran, not whether the two
decoders agree; ``--require-equivalent`` asks for the stricter reading once the
gap is expected to be closed.

Usage:
    py tools/audit_mes_framing_equivalence.py --digest <framing.jsonl> \\
        --arc <mes.arc> [--json report.json] [--limit N]

Produce the digest first with Godot:
    Godot_v4.7-stable_win64_console.exe --headless --path . \\
      --script res://tools/content_suite/cli/export_mes_framing_digest.gd -- \\
      <mes.arc> <framing.jsonl>
"""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
from collections import Counter
from pathlib import Path
from typing import Any, Iterator

sys.path.insert(0, str(Path(__file__).resolve().parent))

from mes_archive_ir import MesContainerError, load_archive_entry, parse_mes_container
from mes_partial_decoder import MesDecodeError, decode_instruction


SCHEMA = "kakyu_mes_framing_equivalence/v1"
DIGEST_SCHEMA = "kakyu_mes_framing_digest/v1"
MAX_INSTRUCTIONS = 100000


class FramingError(ValueError):
    pass


def container_regions(container: dict[str, Any]) -> list[tuple[int, int]]:
    """The container's own regions: a non-empty bootstrap, then each entry.

    This deliberately mirrors the GDScript exporter rather than reusing
    ``mes_cfg_seed``, whose bootstrap node is always present and whose purpose
    is control-flow seeding rather than framing.
    """
    header = container["header"]
    code_size = header["codeSize"]
    offsets: list[int] = header["entryOffsets"]
    regions: list[tuple[int, int]] = []
    bootstrap_end = offsets[0] if offsets else code_size
    if bootstrap_end > 0:
        regions.append((0, bootstrap_end))
    for index, offset in enumerate(offsets):
        end = offsets[index + 1] if index + 1 < len(offsets) else code_size
        regions.append((offset, end))
    return regions


def python_framing(payload: bytes) -> dict[str, Any]:
    """Frame one MES entry with the Python decoder, in the canonical form.

    The code bytes and the regions come back with the framing because the
    caller needs both to name the opcode at a divergence, and parsing the same
    payload twice to recover them would be the same container read done again.
    """
    container = parse_mes_container(payload)
    code_offset = container["header"]["codeOffset"]
    code = payload[code_offset:]
    regions = container_regions(container)
    lines: list[str] = []
    instruction_count = 0
    opaque_count = 0
    decoded_bytes = 0

    for start, end in regions:
        cursor = start
        while cursor < end and instruction_count < MAX_INSTRUCTIONS:
            try:
                instruction = decode_instruction(code, cursor, end)
            except MesDecodeError:
                break
            if instruction is None:
                break
            source_offset = int(instruction["sourceOffset"])
            end_offset = int(instruction["endOffset"])
            if end_offset <= source_offset:
                break
            lines.append(f"i {source_offset} {end_offset}")
            instruction_count += 1
            decoded_bytes += end_offset - source_offset
            cursor = end_offset
        if cursor < end:
            lines.append(f"o {cursor} {end}")
            opaque_count += 1

    framing = "\n".join(lines)
    return {
        "code_size": len(code),
        "region_count": len(regions),
        "instruction_count": instruction_count,
        "opaque_count": opaque_count,
        "decoded_bytes": decoded_bytes,
        "framing_sha256": hashlib.sha256(framing.encode("utf-8")).hexdigest(),
        "framing": framing,
        "code": code,
        "regions": regions,
    }


def first_divergence(expected: str, actual: str, code: bytes = b"") -> dict[str, Any] | None:
    """The first differing framing line, with both sides and the opcode there.

    The opcode is what makes the report a work list rather than a bug list: a
    divergence is almost always one command the Python decoder has no grammar
    for, and counting entries per command says which grammar to write first.
    """
    left = expected.split("\n") if expected else []
    right = actual.split("\n") if actual else []
    for index in range(min(len(left), len(right))):
        if left[index] != right[index]:
            offset = _line_offset(left[index])
            return {
                "line": index,
                "authoritative": left[index],
                "python": right[index],
                "offset": offset,
                "command_id": _command_at(code, offset),
            }
    if len(left) != len(right):
        index = min(len(left), len(right))
        longer = left if len(left) > len(right) else right
        offset = _line_offset(longer[index])
        return {
            "line": index,
            "authoritative": left[index] if index < len(left) else "",
            "python": right[index] if index < len(right) else "",
            "offset": offset,
            "command_id": _command_at(code, offset),
            "reason": "one side stops earlier",
        }
    return None


def _line_offset(line: str) -> int:
    parts = line.split(" ")
    return int(parts[1]) if len(parts) >= 2 and parts[1].isdigit() else -1


def _command_at(code: bytes, offset: int) -> str:
    if not code or offset < 0 or offset >= len(code):
        return ""
    return f"0x{code[offset]:02X}"


def per_record_agreement(
    authoritative: str, code: bytes, regions: list[tuple[int, int]]
) -> tuple[Counter[str], Counter[str]]:
    """Per authoritative record, does Python frame it to the same end?

    Sequential decoding stops at the first command it cannot read, so it cannot
    say what else would have worked.  Starting from each authoritative offset
    instead measures coverage, and the counters say which command to teach the
    decoder next.
    """
    agreed: Counter[str] = Counter()
    disagreed: Counter[str] = Counter()
    for line in authoritative.split("\n") if authoritative else []:
        parts = line.split(" ")
        if len(parts) != 3 or parts[0] != "i":
            continue
        start, end = int(parts[1]), int(parts[2])
        command = _command_at(code, start)
        limit = _region_end(regions, start)
        if limit is None:
            disagreed[command] += 1
            continue
        try:
            instruction = decode_instruction(code, start, limit)
        except MesDecodeError:
            instruction = None
        if instruction is not None and int(instruction["endOffset"]) == end:
            agreed[command] += 1
        else:
            disagreed[command] += 1
    return agreed, disagreed


def _region_end(regions: list[tuple[int, int]], offset: int) -> int | None:
    for start, end in regions:
        if start <= offset < end:
            return end
    return None


def read_digest(path: Path) -> tuple[dict[str, Any], Iterator[dict[str, Any]]]:
    rows = [json.loads(line) for line in path.read_text(encoding="utf-8").splitlines() if line.strip()]
    if not rows or rows[0].get("kind") != "header":
        raise FramingError("framing digest is missing its header row")
    header = rows[0]
    if header.get("schema") != DIGEST_SCHEMA:
        raise FramingError(f"framing digest schema is not {DIGEST_SCHEMA}")
    return header, iter(rows[1:])


def audit(digest_path: Path, arc_path: Path, limit: int | None = None) -> dict[str, Any]:
    header, rows = read_digest(digest_path)
    compared: list[dict[str, Any]] = []
    equal = 0
    diverged = 0
    unreadable = 0
    skipped = 0
    divergence_offsets: Counter[str] = Counter()
    record_agreed: Counter[str] = Counter()
    record_disagreed: Counter[str] = Counter()

    for row in rows:
        if limit is not None and len(compared) >= limit:
            break
        if not row.get("ok", False):
            skipped += 1
            continue
        entry = str(row["entry"])
        try:
            payload, _ = load_archive_entry(arc_path, entry)
            actual = python_framing(payload)
        except (MesContainerError, MesDecodeError, ValueError, KeyError, IndexError) as error:
            unreadable += 1
            compared.append({
                "entry": entry,
                "status": "python_failed",
                "error": f"{type(error).__name__}: {error}",
            })
            continue

        agreed, disagreed = per_record_agreement(
            row.get("framing", ""), actual["code"], actual["regions"]
        )
        record_agreed.update(agreed)
        record_disagreed.update(disagreed)

        same = actual["framing_sha256"] == row["framing_sha256"]
        record: dict[str, Any] = {
            "entry": entry,
            "status": "equal" if same else "diverged",
            "code_size": row["code_size"],
            "authoritative_instructions": row["instruction_count"],
            "python_instructions": actual["instruction_count"],
            "authoritative_opaque": row["opaque_count"],
            "python_opaque": actual["opaque_count"],
        }
        if same:
            equal += 1
        else:
            diverged += 1
            divergence = first_divergence(
                row.get("framing", ""), actual["framing"], actual["code"]
            )
            if divergence is not None:
                record["first_divergence"] = divergence
                divergence_offsets[divergence["command_id"] or "unknown"] += 1
        compared.append(record)

    total = equal + diverged + unreadable
    commands = sorted(set(record_agreed) | set(record_disagreed))
    per_command = {
        command: {
            "authoritative_records": record_agreed[command] + record_disagreed[command],
            "python_agreed": record_agreed[command],
            "python_disagreed": record_disagreed[command],
        }
        for command in commands
    }
    records_total = sum(record_agreed.values()) + sum(record_disagreed.values())
    return {
        "schema": SCHEMA,
        "archive_sha256": header.get("archive_sha256", ""),
        "decode_mode": header.get("decode_mode", ""),
        "entry_count": total,
        "equal": equal,
        "diverged": diverged,
        "python_failed": unreadable,
        "skipped_unframed": skipped,
        "equivalent": diverged == 0 and unreadable == 0 and equal > 0,
        "divergence_commands": dict(sorted(divergence_offsets.items())),
        "records": {
            "authoritative": records_total,
            "python_agreed": sum(record_agreed.values()),
            "python_disagreed": sum(record_disagreed.values()),
            "agreement_ratio": (
                sum(record_agreed.values()) / records_total if records_total else 0.0
            ),
        },
        "per_command": per_command,
        "entries": compared,
    }


def summarize(report: dict[str, Any]) -> str:
    return (
        "MES_FRAMING_EQUIVALENCE "
        f"schema={report['schema']} "
        f"archive_sha256={report['archive_sha256'][:16]} "
        f"entries={report['entry_count']} "
        f"equal={report['equal']} "
        f"diverged={report['diverged']} "
        f"python_failed={report['python_failed']} "
        f"records={report['records']['authoritative']} "
        f"record_agreement={report['records']['agreement_ratio']:.4f} "
        f"equivalent={str(report['equivalent']).lower()}"
    )


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--digest", type=Path, required=True, help="framing digest JSONL")
    parser.add_argument("--arc", type=Path, required=True, help="the same MES archive")
    parser.add_argument("--json", type=Path, help="write the full report here")
    parser.add_argument("--limit", type=int, help="compare at most N entries")
    parser.add_argument(
        "--require-equivalent",
        action="store_true",
        help="exit non-zero unless every compared entry agrees",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    arguments = parse_args(argv)
    if arguments.limit is not None and arguments.limit <= 0:
        print("MES_FRAMING_EQUIVALENCE_CONFIGURATION_ERROR: limit must be greater than zero.")
        return 2
    try:
        report = audit(arguments.digest, arguments.arc, arguments.limit)
    except (FramingError, OSError, json.JSONDecodeError) as error:
        print(f"MES_FRAMING_EQUIVALENCE_ERROR: {error}")
        return 2

    if arguments.json is not None:
        arguments.json.parent.mkdir(parents=True, exist_ok=True)
        arguments.json.write_text(
            json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8"
        )
    print(summarize(report))
    for command, count in sorted(report["divergence_commands"].items()):
        print(f"  first divergence at command {command}: {count} entries")
    blocking = sorted(
        (
            (row["python_disagreed"], command)
            for command, row in report["per_command"].items()
            if row["python_disagreed"]
        ),
        reverse=True,
    )
    if blocking:
        print(f"  commands Python does not frame, by corpus records ({len(blocking)}):")
        for count, command in blocking[:12]:
            total = report["per_command"][command]["authoritative_records"]
            print(f"    {command}  {count:>9} of {total:>9} records")
    if arguments.require_equivalent and not report["equivalent"]:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
