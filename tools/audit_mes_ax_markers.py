"""Audit exact filename-bearing AX presentation records in an original MES ARC.

The exact envelope is outer presentation command 0x0D, subcommand 8, selector
0. The original executable routes that selector to the document Data loader.
The audit confirms named-entry requests and carries the independently verified
native destination-buffer argument role. It does not infer AX token or
rendering semantics.
"""

from __future__ import annotations

import argparse
import re
import struct
from pathlib import Path

from extract_kakyu_arc import read_entries


SCHEMA = "kakyu_mes_ax_marker_audit/v3"
MARKER = re.compile(
    rb"\x0d\x08\xff\x02\x00\xff\x01"
    rb"(?P<name>[A-Za-z0-9_]{1,64}\.[Aa][Xx])"
    rb"\x00\x02\x02\xf9\x00\xff\x00"
)
AX_TOKEN = re.compile(rb"(?i)[A-Za-z0-9_]{1,64}\.ax")


def normalize_ax_name(raw_name: bytes) -> str:
    return raw_name.decode("ascii").upper()


def audit_archive(mes_arc: Path, data_arc: Path | None = None) -> dict[str, object]:
    entries = read_entries(mes_arc)
    data_names = (
        {name.casefold() for name, _, _ in read_entries(data_arc)}
        if data_arc is not None and data_arc.is_file()
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
            token_count += len(AX_TOKEN.findall(code))
            for match in MARKER.finditer(code):
                raw_name = match.group("name")
                normalized = normalize_ax_name(raw_name)
                rows.append(
                    {
                        "entry": entry_name,
                        "offset": match.start(),
                        "token": raw_name.decode("ascii"),
                        "normalized": normalized,
                        "resolved": normalized.casefold() in data_names,
                        "outer_command": 0x0D,
                        "presentation_subcommand": 8,
                        "execution_selector": 0,
                        "data_archive_index": 0,
                        "native_consumer_semantics": "data_arc_named_entry_load_confirmed",
                        "native_loader_argument": "banked_i32[0][2]",
                        "native_loader_argument_semantics": "engine_initialized_destination_buffer_pointer",
                        "native_payload_semantics": "unresolved",
                    }
                )

    return {
        "schema": SCHEMA,
        "entries": len(entries),
        "ax_tokens": token_count,
        "markers": len(rows),
        "marker_entries": len({str(row["entry"]) for row in rows}),
        "resolved_markers": sum(bool(row["resolved"]) for row in rows),
        "rows": rows,
    }


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Audit exact filename-bearing AX marker envelopes in mes.arc."
    )
    parser.add_argument("mes_arc", type=Path)
    parser.add_argument("--data-arc", type=Path, help="Optional sibling data.arc for target resolution.")
    parser.add_argument("--entry", help="Print marker rows for one MES entry.")
    args = parser.parse_args()

    result = audit_archive(args.mes_arc, args.data_arc)
    print(
        "schema={schema} entries={entries} ax_tokens={ax_tokens} markers={markers} "
        "marker_entries={marker_entries} resolved={resolved_markers}".format(**result)
    )
    if args.entry:
        for row in result["rows"]:  # type: ignore[assignment]
            if str(row["entry"]).casefold() != args.entry.casefold():
                continue
            print(
                f"{row['entry']} code+0x{int(row['offset']):X} {row['token']} -> "
                f"{row['normalized']} resolved={row['resolved']}"
            )


if __name__ == "__main__":
    main()
