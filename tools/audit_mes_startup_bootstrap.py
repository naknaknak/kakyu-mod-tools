"""Audit START.MES bootstrap entry execution records without extracting data.

The audit reads only the named ARC entries and reports hashes, coordinates, and
the bounded presentation-subcommand records that execute the shared library and
definition script. It never writes to the source archive or emits payload data.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import struct
from pathlib import Path
from typing import Any

from extract_kakyu_arc import read_entries
from payload_values import sha256_file as _sha256_file


SCHEMA = "kakyu_mes_startup_bootstrap_audit/v2"
START_ENTRY = "START.MES"
ROOT_BOOTSTRAP = bytes.fromhex("1412ff0800000000")
ROOT_ENTRY_COORDINATE = 0x0008
EXPECTED_RECORDS = (
    (0x014C, 2, "LIBLARY.LIB", "inline_library_execution"),
    (0x0165, 3, "DEF_MAIN.MES", "inline_definition_execution"),
)
TERMINAL_HANDOFF_COORDINATE = 0x0BCA
TERMINAL_HANDOFF_TARGET = "OPEN.MES"
TERMINAL_HANDOFF = b"\x0e\x01" + TERMINAL_HANDOFF_TARGET.lower().encode("ascii") + b"\0\0"
TAIL_RETURN_COORDINATE = 0x0BEA


def _read_arc_entry(
    archive_path: Path, entries: dict[str, tuple[str, int, int]], name: str
) -> bytes:
    entry = entries.get(name.casefold())
    if entry is None:
        raise ValueError(f"required ARC entry is missing: {name}")
    _stored_name, offset, size = entry
    with archive_path.open("rb") as archive:
        archive.seek(offset)
        payload = archive.read(size)
    if len(payload) != size:
        raise ValueError(f"ARC entry read was truncated: {name}")
    return payload


def _parse_single_entry_mes(payload: bytes) -> tuple[int, bytes]:
    if len(payload) < 8:
        raise ValueError("START.MES is too small for its address table")
    entry_count = struct.unpack_from("<I", payload, 0)[0]
    if entry_count != 1:
        raise ValueError(f"START.MES address count changed: {entry_count}")
    code_offset = 4 + entry_count * 4
    first_entry = struct.unpack_from("<I", payload, 4)[0]
    if first_entry != ROOT_ENTRY_COORDINATE:
        raise ValueError(
            f"START.MES entry-zero coordinate changed: 0x{first_entry:X} "
            f"!= 0x{ROOT_ENTRY_COORDINATE:X}"
        )
    return code_offset, payload[code_offset:]


def _parse_root_route(code: bytes) -> tuple[dict[str, Any], dict[str, Any]]:
    if len(code) != TAIL_RETURN_COORDINATE + 1:
        raise ValueError(f"START.MES code size changed: 0x{len(code):X}")
    if code[: len(ROOT_BOOTSTRAP)] != ROOT_BOOTSTRAP:
        raise ValueError("START.MES root bootstrap transfer changed")
    entry_label = b"\x17" + struct.pack("<I", 0)
    if code[ROOT_ENTRY_COORDINATE : ROOT_ENTRY_COORDINATE + len(entry_label)] != entry_label:
        raise ValueError("START.MES entry-zero label changed")
    handoff_end = TERMINAL_HANDOFF_COORDINATE + len(TERMINAL_HANDOFF)
    if code[TERMINAL_HANDOFF_COORDINATE:handoff_end].lower() != TERMINAL_HANDOFF:
        raise ValueError("START.MES terminal handoff changed")
    if code.lower().count(TERMINAL_HANDOFF) != 1:
        raise ValueError("START.MES terminal handoff is not unique")
    if code[TAIL_RETURN_COORDINATE] != 0:
        raise ValueError("START.MES tail return changed")
    return (
        {
            "command_coordinate": 0,
            "command": 0x14,
            "registered_selector": 18,
            "target_coordinate": ROOT_ENTRY_COORDINATE,
            "tail_return_coordinate": len(ROOT_BOOTSTRAP) - 1,
        },
        {
            "command_coordinate": TERMINAL_HANDOFF_COORDINATE,
            "end_coordinate": handoff_end,
            "command": 0x0E,
            "target_entry": TERMINAL_HANDOFF_TARGET,
            "tail_return_coordinate": TAIL_RETURN_COORDINATE,
        },
    )


def _parse_execution_record(
    code: bytes, coordinate: int, expected_selector: int, expected_name: str
) -> dict[str, Any]:
    prefix = bytes((0x0D, 0x08, 0xFF, 0x02, expected_selector, 0xFF, 0x01))
    expected = prefix + expected_name.lower().encode("ascii") + b"\0\0"
    if coordinate < 0 or coordinate + len(expected) > len(code):
        raise ValueError(f"START.MES bootstrap record is out of bounds at 0x{coordinate:04X}")
    if code[coordinate : coordinate + len(expected)].lower() != expected:
        raise ValueError(f"START.MES bootstrap record changed at 0x{coordinate:04X}")
    if code.lower().count(expected) != 1:
        raise ValueError(f"START.MES bootstrap record is not unique: {expected_name}")
    return {
        "command_coordinate": coordinate,
        "end_coordinate": coordinate + len(expected),
        "outer_command": 0x0D,
        "presentation_subcommand": 8,
        "selector": expected_selector,
        "target_entry": expected_name,
    }


def audit_startup_bootstrap(archive_path: Path) -> dict[str, Any]:
    archive_entries = read_entries(archive_path)
    entries = {name.casefold(): (name, offset, size) for name, offset, size in archive_entries}
    start_payload = _read_arc_entry(archive_path, entries, START_ENTRY)
    code_offset, code = _parse_single_entry_mes(start_payload)
    root_bootstrap, terminal_handoff = _parse_root_route(code)

    records: list[dict[str, Any]] = []
    target_hashes: dict[str, str] = {}
    for coordinate, selector, target_name, role in EXPECTED_RECORDS:
        record = _parse_execution_record(code, coordinate, selector, target_name)
        record["role"] = role
        records.append(record)
        target_payload = _read_arc_entry(archive_path, entries, target_name)
        target_hashes[target_name] = hashlib.sha256(target_payload).hexdigest()
    terminal_payload = _read_arc_entry(archive_path, entries, TERMINAL_HANDOFF_TARGET)
    target_hashes[TERMINAL_HANDOFF_TARGET] = hashlib.sha256(terminal_payload).hexdigest()

    return {
        "schema": SCHEMA,
        "archive_sha256": _sha256_file(archive_path),
        "archive_entry_count": len(archive_entries),
        "start_entry": START_ENTRY,
        "start_entry_sha256": hashlib.sha256(start_payload).hexdigest(),
        "start_entry_size": len(start_payload),
        "address_count": 1,
        "code_file_offset": code_offset,
        "code_size": len(code),
        "root_bootstrap": root_bootstrap,
        "records": records,
        "terminal_handoff": terminal_handoff,
        "target_entry_sha256": target_hashes,
        "execution_order": [record["target_entry"] for record in records],
        "semantic_boundary": (
            "startup_mes_root_bootstrap_inline_script_targets_and_stored_terminal_"
            "command0e_handoff_only_without_target_activation_coordinate"
        ),
        "native_execution_contract": "cross_check_with_kakyu_ai5_mes_exe_audit_v100",
    }


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Audit START.MES inline library/definition bootstrap records in mes.arc."
    )
    parser.add_argument("mes_arc", type=Path)
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()
    result = audit_startup_bootstrap(args.mes_arc)
    if args.json:
        print(json.dumps(result, ensure_ascii=True, sort_keys=True, indent=2))
        return
    coordinates = ",".join(
        f"{record['target_entry']}@0x{record['command_coordinate']:04X}/selector{record['selector']}"
        for record in result["records"]
    )
    print(
        f"schema={result['schema']} archive_sha256={result['archive_sha256']} "
        f"start_sha256={result['start_entry_sha256']} records={coordinates} "
        f"terminal={result['terminal_handoff']['target_entry']}"
    )


if __name__ == "__main__":
    main()
