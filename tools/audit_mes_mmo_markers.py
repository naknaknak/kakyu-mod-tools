"""Audit exact filename-bearing MMO presentation records in an original MES ARC.

The bounded record is outer presentation command 0x0D, subcommand 9, one
filename argument, and the argument-list terminator. Native top-level command
0x09 remains a separate indexed dword writer. Bytes after the record are never
folded into the presentation row; in particular, an adjacent command 0x07 is a
separate banked-u16 write.
"""

from __future__ import annotations

import argparse
import re
import struct
from pathlib import Path

from extract_kakyu_arc import read_entries


SCHEMA = "kakyu_mes_mmo_presentation_audit/v2"
PRESENTATION = re.compile(
    rb"\x0d\x09\xff\x01"
    rb"(?P<name>[A-Za-z0-9_]{1,64}\.[Mm][Mm][Oo])"
    rb"\x00\x00"
)
MMO_TOKEN = re.compile(rb"(?i)[A-Za-z0-9_]{1,64}\.mmo")


def normalize_mmo_name(raw_name: bytes) -> str:
    return raw_name.decode("ascii").upper()


def audit_archive(mes_arc: Path, mmo_arc: Path | None = None) -> dict[str, object]:
    entries = read_entries(mes_arc)
    mmo_names = (
        {name.casefold() for name, _, _ in read_entries(mmo_arc)}
        if mmo_arc is not None and mmo_arc.is_file()
        else set()
    )
    rows: list[dict[str, object]] = []
    token_count = 0

    with mes_arc.open("rb") as archive:
        for entry_name, archive_offset, size in entries:
            archive.seek(archive_offset)
            data = archive.read(size)
            if len(data) != size:
                raise ValueError(f"{entry_name} payload read was truncated")
            if len(data) < 4:
                continue
            entry_count = struct.unpack_from("<I", data, 0)[0]
            code_offset = 4 + entry_count * 4
            if code_offset > len(data):
                raise ValueError(f"{entry_name} has an invalid MES address table")
            code = data[code_offset:]
            token_count += len(MMO_TOKEN.findall(code))
            for match in PRESENTATION.finditer(code):
                raw_name = match.group("name")
                normalized = normalize_mmo_name(raw_name)
                rows.append(
                    {
                        "entry": entry_name,
                        "outer_offset": match.start(),
                        "offset": match.start() + 1,
                        "end_offset": match.end(),
                        "outer_command": 0x0D,
                        "presentation_subcommand": 9,
                        "argument_count": 1,
                        "token": raw_name.decode("ascii"),
                        "normalized": normalized,
                        "resolved": normalized.casefold() in mmo_names,
                        "next_command": code[match.end()] if match.end() < len(code) else None,
                    }
                )

    next_commands = sorted(
        {row["next_command"] for row in rows},
        key=lambda value: -1 if value is None else int(value),
    )
    return {
        "schema": SCHEMA,
        "entries": len(entries),
        "mmo_tokens": token_count,
        "presentations": len(rows),
        "presentation_entries": len({str(row["entry"]) for row in rows}),
        "resolved_presentations": sum(bool(row["resolved"]) for row in rows),
        "markers": len(rows),
        "marker_entries": len({str(row["entry"]) for row in rows}),
        "resolved_markers": sum(bool(row["resolved"]) for row in rows),
        "next_command_counts": {
            "eof" if command is None else f"0x{int(command):02X}": sum(
                row["next_command"] == command for row in rows
            )
            for command in next_commands
        },
        "rows": rows,
    }


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Audit exact filename-bearing MMO presentation records in mes.arc."
    )
    parser.add_argument("mes_arc", type=Path)
    parser.add_argument("--mmo-arc", type=Path, help="Optional sibling mmo.arc for target resolution.")
    parser.add_argument("--entry", help="Print marker rows for one MES entry.")
    args = parser.parse_args()

    result = audit_archive(args.mes_arc, args.mmo_arc)
    print(
        "schema={schema} entries={entries} mmo_tokens={mmo_tokens} "
        "presentations={presentations} presentation_entries={presentation_entries} "
        "resolved={resolved_presentations} next={next_command_counts}".format(**result)
    )
    if args.entry:
        for row in result["rows"]:  # type: ignore[assignment]
            if str(row["entry"]).casefold() != args.entry.casefold():
                continue
            next_command = row["next_command"]
            next_label = "eof" if next_command is None else f"0x{int(next_command):02X}"
            print(
                f"{row['entry']} code+0x{int(row['outer_offset']):X}..0x{int(row['end_offset']):X} "
                f"subcommand+0x{int(row['offset']):X} {row['token']} -> "
                f"{row['normalized']} resolved={row['resolved']} "
                f"next={next_label}"
            )


if __name__ == "__main__":
    main()
