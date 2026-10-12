"""Audit bounded presentation-subcommand 11 records in an original MES ARC.

Top-level MES command 0x0B is a conditional transfer.  This audit considers
0x0B a presentation selector only when it follows outer command 0x0D and is a
complete ``0D 0B FF`` typed-record envelope.  The native adapter consumes
a bounded expression-record list before the zero record-list terminator.  The
native adapter has thirteen parsed-record cells; it expands the first nine into
a thirteen-argument surface call by turning two inclusive endpoint pairs into
width/height values.  Missing cells retain the native parser defaults.
"""

from __future__ import annotations

import argparse
import struct
from collections import Counter
from pathlib import Path
from typing import Any

from extract_kakyu_arc import read_entries
from mes_expression import ExpressionError, parse_expression


SCHEMA = "kakyu_mes_surface_operation_audit/v4"
MARKER = bytes.fromhex("0d0bff")
EXPECTED_RECORD_COUNTS = {0: {8, 9}, 1: {9}, 2: {5}}
EXPECTED_DISPLAY_REFRESH_RECORD_COUNTS = {13: {6}}


def _literal_value(expression: dict[str, Any]) -> int | None:
    ast = expression.get("ast", {})
    if ast.get("type") != "literal":
        return None
    return int(ast["value"])


def parse_surface_dispatch(code: bytes, offset: int) -> dict[str, Any] | None:
    """Parse one bounded outer-0D/subcommand-11 typed-record envelope."""
    if code[offset : offset + len(MARKER)] != MARKER:
        return None
    cursor = offset + len(MARKER)
    expressions: list[dict[str, Any]] = []
    try:
        while cursor < len(code):
            tag_offset = cursor
            tag = code[cursor]
            cursor += 1
            if tag == 0:
                return {
                    "outer_offset": offset,
                    "subcommand_offset": offset + 1,
                    "end_offset": cursor,
                    "argument_count": len(expressions),
                    "mode": _literal_value(expressions[0]) if expressions else None,
                    "literal_arguments": [_literal_value(value) for value in expressions],
                    "expressions": expressions,
                    "raw_hex": code[offset:cursor].hex(),
                }
            if tag != 2:
                return None
            expression = parse_expression(code, cursor, max_bytes=len(code) - cursor)
            if not expression.get("valid", False):
                return None
            expression["record_tag_offset"] = tag_offset
            expressions.append(expression)
            if len(expressions) > 13:
                return None
            cursor = int(expression["end_offset"])
    except ExpressionError:
        return None
    return None


def parse_surface_operation(code: bytes, offset: int) -> dict[str, Any] | None:
    """Parse one EXE-confirmed mode-0/1/2 surface operation at ``offset``."""
    row = parse_surface_dispatch(code, offset)
    if row is None:
        return None
    mode = row["mode"]
    if mode not in EXPECTED_RECORD_COUNTS:
        return None
    if row["argument_count"] not in EXPECTED_RECORD_COUNTS[mode]:
        return None
    row["operation"] = {
        0: "opaque_rectangle_copy_confirmed",
        1: "rgb_chroma_key_rectangle_copy_confirmed",
        2: "active_surface_rectangle_fill_confirmed",
    }[mode]
    return row


def parse_display_refresh(code: bytes, offset: int) -> dict[str, Any] | None:
    """Parse one EXE-confirmed mode-13 attached-display refresh envelope."""
    row = parse_surface_dispatch(code, offset)
    if row is None:
        return None
    mode = row["mode"]
    if mode not in EXPECTED_DISPLAY_REFRESH_RECORD_COUNTS:
        return None
    if row["argument_count"] not in EXPECTED_DISPLAY_REFRESH_RECORD_COUNTS[mode]:
        return None
    row["operation"] = "conditional_attached_display_rectangle_refresh_confirmed"
    row["refresh_origin"] = [0, 0]
    arguments = row["literal_arguments"]
    if all(arguments[index] is not None for index in (1, 2, 3, 4)):
        row["refresh_extent"] = [
            (int(arguments[3]) - int(arguments[1]) + 1) & 0xFFFF,
            (int(arguments[4]) - int(arguments[2]) + 1) & 0xFFFF,
        ]
    else:
        row["refresh_extent"] = None
    return row


def audit_archive(mes_arc: Path) -> dict[str, Any]:
    entries = read_entries(mes_arc)
    archive = mes_arc.read_bytes()
    rows: list[dict[str, Any]] = []
    refresh_rows: list[dict[str, Any]] = []
    dispatch_rows: list[dict[str, Any]] = []
    marker_samples: list[dict[str, Any]] = []
    marker_count = 0

    for entry_name, archive_offset, size in entries:
        data = archive[archive_offset : archive_offset + size]
        if len(data) < 4:
            continue
        entry_count = struct.unpack_from("<I", data, 0)[0]
        code_offset = 4 + entry_count * 4
        if code_offset > len(data):
            raise ValueError(f"{entry_name} has an invalid MES address table")
        code = data[code_offset:]
        cursor = 0
        while True:
            cursor = code.find(MARKER, cursor)
            if cursor < 0:
                break
            marker_count += 1
            if len(marker_samples) < 100:
                marker_samples.append(
                    {
                        "entry": entry_name,
                        "outer_offset": cursor,
                        "raw_hex": code[cursor : cursor + 100].hex(),
                    }
                )
            row = parse_surface_operation(code, cursor)
            refresh_row = parse_display_refresh(code, cursor)
            dispatch_row = parse_surface_dispatch(code, cursor)
            if dispatch_row is not None:
                dispatch_row["entry"] = entry_name
                dispatch_rows.append(dispatch_row)
            if row is not None:
                row["entry"] = entry_name
                row["next_command"] = code[row["end_offset"]] if row["end_offset"] < len(code) else None
                rows.append(row)
            if refresh_row is not None:
                refresh_row["entry"] = entry_name
                refresh_row["next_command"] = (
                    code[refresh_row["end_offset"]]
                    if refresh_row["end_offset"] < len(code)
                    else None
                )
                refresh_rows.append(refresh_row)
            cursor += 1

    mode_counts = Counter(row["mode"] for row in rows)
    dynamic_argument_counts = Counter(
        sum(value is None for value in row["literal_arguments"]) for row in rows
    )
    record_count_counts = Counter(row["argument_count"] for row in rows)
    unresolved_rows = [
        row
        for row in dispatch_rows
        if not (
            row["mode"] in EXPECTED_RECORD_COUNTS
            and row["argument_count"] in EXPECTED_RECORD_COUNTS[row["mode"]]
        )
        and not (
            row["mode"] in EXPECTED_DISPLAY_REFRESH_RECORD_COUNTS
            and row["argument_count"]
            in EXPECTED_DISPLAY_REFRESH_RECORD_COUNTS[row["mode"]]
        )
    ]
    return {
        "schema": SCHEMA,
        "entries": len(entries),
        "raw_markers": marker_count,
        "dispatch_candidates": len(dispatch_rows),
        "operations": len(rows),
        "display_refreshes": len(refresh_rows),
        "display_refresh_entries": len({row["entry"] for row in refresh_rows}),
        "operation_entries": len({row["entry"] for row in rows}),
        "mode_counts": dict(sorted(mode_counts.items(), key=lambda item: (-1 if item[0] is None else item[0]))),
        "dynamic_argument_counts": dict(sorted(dynamic_argument_counts.items())),
        "record_count_counts": dict(sorted(record_count_counts.items())),
        "unresolved_candidates": len(unresolved_rows),
        "unresolved_candidate_rows": unresolved_rows,
        "marker_samples": marker_samples,
        "dispatch_rows": dispatch_rows,
        "rows": rows,
        "display_refresh_rows": refresh_rows,
    }


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Audit exact presentation-subcommand 11 surface-operation records in mes.arc."
    )
    parser.add_argument("mes_arc", type=Path)
    parser.add_argument("--entry", help="Print operation rows for one MES entry.")
    parser.add_argument("--limit", type=int, default=40, help="Maximum rows to print.")
    parser.add_argument(
        "--raw-markers",
        action="store_true",
        help="Print bounded hex samples for raw 0D 0B FF hits that may not be envelopes.",
    )
    args = parser.parse_args()

    result = audit_archive(args.mes_arc)
    print(
        "schema={schema} entries={entries} raw_markers={raw_markers} "
        "dispatch_candidates={dispatch_candidates} operations={operations} "
        "display_refreshes={display_refreshes} "
        "unresolved_candidates={unresolved_candidates} operation_entries={operation_entries} "
        "modes={mode_counts} records={record_count_counts} "
        "dynamic_args={dynamic_argument_counts}".format(**result)
    )
    if args.raw_markers:
        for sample in result["marker_samples"][: args.limit]:
            print(
                f"RAW {sample['entry']} code+0x{sample['outer_offset']:X} "
                f"{sample['raw_hex']}"
            )
        for row in result["unresolved_candidate_rows"]:
            print(
                f"UNRESOLVED {row['entry']} code+0x{row['outer_offset']:X}..0x{row['end_offset']:X} "
                f"mode={row['mode']} records={row['argument_count']} "
                f"args={row['literal_arguments']}"
            )
    shown = 0
    if args.limit <= 0:
        return
    for row in result["display_refresh_rows"]:
        if args.entry and str(row["entry"]).casefold() != args.entry.casefold():
            continue
        next_command = row["next_command"]
        next_label = "eof" if next_command is None else f"0x{next_command:02X}"
        print(
            f"DISPLAY_REFRESH {row['entry']} "
            f"code+0x{row['outer_offset']:X}..0x{row['end_offset']:X} "
            f"mode={row['mode']} op={row['operation']} "
            f"args={row['literal_arguments']} refresh={row['refresh_origin']}+{row['refresh_extent']} "
            f"next={next_label}"
        )
    for row in result["rows"]:
        if args.entry and str(row["entry"]).casefold() != args.entry.casefold():
            continue
        next_command = row["next_command"]
        next_label = "eof" if next_command is None else f"0x{next_command:02X}"
        print(
            f"{row['entry']} code+0x{row['outer_offset']:X}..0x{row['end_offset']:X} "
            f"mode={row['mode']} op={row['operation']} "
            f"args={row['literal_arguments']} next={next_label}"
        )
        shown += 1
        if shown >= args.limit:
            break


if __name__ == "__main__":
    main()
