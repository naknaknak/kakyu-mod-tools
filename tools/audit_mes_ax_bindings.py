"""Audit exact AX-buffer binding and all-cell invalidation records in MES ARC.

The exact envelope is outer presentation command 0x0D, subcommand 3,
selector 0, row 0, column 0..2, and buffer expression banked_i32[0][2].
The original executable routes it to the sole registered presentation
consumer's virtual slot +0x08.  This audit does not claim that the bounded
consumer call draws pixels or decode the pointed-to AX subrecord.

The separate no-argument selector-7 envelope routes to the same consumer's
virtual slot +0x20.  That handler visits all 10 x 32 cells and uses slot +0x14
to write the inactive state 0xFF.  The scanner intentionally accepts only the
complete literal envelopes documented here.
"""

from __future__ import annotations

import argparse
import re
import struct
from pathlib import Path

from extract_kakyu_arc import read_entries
from payload_values import sha256_file as _sha256_file


SCHEMA = "kakyu_mes_ax_binding_audit/v2"
BINDING = re.compile(
    rb"\x0d\x03\xff\x02\x00\xff\x02\x00\xff\x02"
    rb"(?P<column>[\x00-\x02])\xff"
    rb"\x02\x02\xf9\x00\xff\x00"
)
INVALIDATE_ALL = re.compile(rb"\x0d\x03\xff\x02\x07\xff\x00")


def audit_archive(mes_arc: Path) -> dict[str, object]:
    archive_sha256 = _sha256_file(mes_arc)
    entries = read_entries(mes_arc)
    rows: list[dict[str, object]] = []
    invalidation_rows: list[dict[str, object]] = []

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
            for match in BINDING.finditer(code):
                rows.append(
                    {
                        "entry": entry_name,
                        "offset": match.start(),
                        "end_offset": match.end(),
                        "outer_command": 0x0D,
                        "presentation_subcommand": 3,
                        "execution_selector": 0,
                        "consumer_index": 0,
                        "consumer_virtual_slot": 0x08,
                        "cell_row": 0,
                        "cell_column": match.group("column")[0],
                        "buffer_argument": "banked_i32[0][2]",
                        "buffer_argument_semantics": "engine_initialized_destination_buffer_pointer",
                        "native_consumer_semantics": "ax_binding_table_cell_install_confirmed",
                        "native_rendering_semantics": "unresolved",
                    }
                )
            for match in INVALIDATE_ALL.finditer(code):
                invalidation_rows.append(
                    {
                        "entry": entry_name,
                        "offset": match.start(),
                        "end_offset": match.end(),
                        "outer_command": 0x0D,
                        "presentation_subcommand": 3,
                        "execution_selector": 7,
                        "consumer_index": "native_default_only_valid_index_zero",
                        "consumer_virtual_slot": 0x20,
                        "cell_rows": 10,
                        "cell_columns": 32,
                        "cell_record_bytes": 0x2C,
                        "cell_state_offset": 0,
                        "inactive_state": 0xFF,
                        "native_consumer_semantics": (
                            "ax_binding_table_all_cells_invalidate_confirmed"
                        ),
                        "native_rendering_semantics": "unresolved",
                    }
                )

    column_counts = {
        str(column): sum(int(row["cell_column"]) == column for row in rows)
        for column in range(3)
    }
    if _sha256_file(mes_arc) != archive_sha256:
        raise ValueError("source archive changed during read-only AX audit")
    return {
        "schema": SCHEMA,
        "archive_sha256": archive_sha256,
        "entries": len(entries),
        "bindings": len(rows),
        "binding_entries": len({str(row["entry"]) for row in rows}),
        "column_counts": column_counts,
        "rows": rows,
        "invalidations": len(invalidation_rows),
        "invalidation_entries": len(
            {str(row["entry"]) for row in invalidation_rows}
        ),
        "invalidation_rows": invalidation_rows,
        "source_unchanged": True,
    }


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Audit exact AX-buffer presentation binding envelopes in mes.arc."
    )
    parser.add_argument("mes_arc", type=Path)
    parser.add_argument("--entry", help="Print binding rows for one MES entry.")
    args = parser.parse_args()

    result = audit_archive(args.mes_arc)
    print(
        "schema={schema} entries={entries} bindings={bindings} "
        "binding_entries={binding_entries} columns={column_counts} "
        "invalidations={invalidations} invalidation_entries={invalidation_entries}".format(
            **result
        )
    )
    if args.entry:
        for row in result["rows"]:  # type: ignore[assignment]
            if str(row["entry"]).casefold() != args.entry.casefold():
                continue
            print(
                f"{row['entry']} code+0x{int(row['offset']):X}..0x{int(row['end_offset']):X} "
                f"cell=({row['cell_row']},{row['cell_column']}) "
                f"buffer={row['buffer_argument']}"
            )
        for row in result["invalidation_rows"]:  # type: ignore[assignment]
            if str(row["entry"]).casefold() != args.entry.casefold():
                continue
            print(
                f"{row['entry']} code+0x{int(row['offset']):X}..0x{int(row['end_offset']):X} "
                "selector=7 all_cells=10x32 inactive_state=0xFF"
            )


if __name__ == "__main__":
    main()
