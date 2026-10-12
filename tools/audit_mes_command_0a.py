"""Audit structurally aligned MES command-0x0A dword write runs.

The report contains offsets, hashes, stack-depth diagnostics, and aggregate
counts only. It does not export expression bytecode or execute any write.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
from typing import Any

import mes_basic_block_ir_v6
from extract_kakyu_arc import read_entries
from payload_values import sha256_file as _sha256_file


SCHEMA = "kakyu_mes_command_0a_audit/v2"


def _unique_instructions(document: dict[str, Any]) -> dict[int, dict[str, Any]]:
    by_offset: dict[int, dict[str, Any]] = {}
    for node in document.get("nodes", []):
        for instruction in node.get("instructions", []):
            by_offset.setdefault(int(instruction["sourceOffset"]), instruction)
    return by_offset


def _stack_depth(expression: dict[str, Any]) -> int:
    ast = expression.get("ast", {})
    if ast.get("type") == "stack":
        return len(ast.get("items", []))
    return 1


def _persistent_stack_effect(depths: list[int]) -> tuple[int, int]:
    balance = 0
    lowest_balance = 0
    for depth in depths:
        # The native 0xff terminator pops one result from the persistent
        # evaluator stack after the expression tokens have pushed `depth`
        # locally observable items.
        balance += depth - 1
        lowest_balance = min(lowest_balance, balance)
    return max(0, -lowest_balance), balance


def scan_code(code: bytes, entry_name: str = "TEST.MES") -> dict[str, Any]:
    document = mes_basic_block_ir_v6.decode_mes((0).to_bytes(4, "little") + code, {"entry": entry_name})
    rows: list[dict[str, Any]] = []
    for offset, instruction in sorted(_unique_instructions(document).items()):
        if int(instruction["commandId"]) != 0x0A or instruction.get("op") != "global_i32_write_run":
            continue
        operands = instruction.get("operands", [])
        destination = operands[0].get("value", {})
        pairs = operands[1].get("pairs", [])
        value_depths = [_stack_depth(pair.get("expression", {})) for pair in pairs]
        value_valid = [bool(pair.get("expression", {}).get("valid", False)) for pair in pairs]
        expression_depths = [_stack_depth(destination), *value_depths]
        minimum_incoming_stack, net_stack_delta = _persistent_stack_effect(expression_depths)
        rows.append(
            {
                "entry": entry_name,
                "source_offset": offset,
                "end_offset": int(instruction["endOffset"]),
                "destination_valid": bool(destination.get("valid", False)),
                "destination_stack_depth": _stack_depth(destination),
                "value_count": len(pairs),
                "value_valid": value_valid,
                "value_stack_depths": value_depths,
                "continuations": [int(pair["continuation"]) for pair in pairs],
                "strict_valid": bool(destination.get("valid", False)) and all(value_valid),
                "isolated_expression_stack_depths": expression_depths,
                "minimum_incoming_stack": minimum_incoming_stack,
                "net_stack_delta": net_stack_delta,
            }
        )
    return {"entry": entry_name, "rows": rows}


def audit_archive(archive: Path, entry_filter: str = "") -> dict[str, Any]:
    archive = archive.resolve()
    wanted = entry_filter.casefold()
    rows: list[dict[str, Any]] = []
    script_entries = 0
    with archive.open("rb") as source:
        for entry_name, archive_offset, size in read_entries(archive):
            if Path(entry_name).suffix.lower() not in {".mes", ".lib"}:
                continue
            if wanted and entry_name.casefold() != wanted:
                continue
            script_entries += 1
            source.seek(archive_offset)
            data = source.read(size)
            if len(data) != size or len(data) < 4:
                raise ValueError(f"truncated MES archive entry: {entry_name}")
            entry_count = int.from_bytes(data[:4], "little")
            code_offset = 4 + entry_count * 4
            if code_offset > len(data):
                raise ValueError(f"invalid MES container: {entry_name}")
            entry_sha256 = hashlib.sha256(data).hexdigest()
            for row in scan_code(data[code_offset:], entry_name)["rows"]:
                rows.append({**row, "entry_sha256": entry_sha256})

    destination_depths: dict[str, int] = {}
    value_depths: dict[str, int] = {}
    minimum_incoming: dict[str, int] = {}
    net_stack_deltas: dict[str, int] = {}
    for row in rows:
        destination_key = str(row["destination_stack_depth"])
        destination_depths[destination_key] = destination_depths.get(destination_key, 0) + 1
        for depth in row["value_stack_depths"]:
            value_key = str(depth)
            value_depths[value_key] = value_depths.get(value_key, 0) + 1
        incoming_key = str(row["minimum_incoming_stack"])
        minimum_incoming[incoming_key] = minimum_incoming.get(incoming_key, 0) + 1
        delta_key = str(row["net_stack_delta"])
        net_stack_deltas[delta_key] = net_stack_deltas.get(delta_key, 0) + 1
    return {
        "schema": SCHEMA,
        "archive": str(archive),
        "archive_sha256": _sha256_file(archive),
        "summary": {
            "script_entries": script_entries,
            "command_0a_rows": len(rows),
            "strict_valid_rows": sum(1 for row in rows if row["strict_valid"]),
            "non_strict_rows": sum(1 for row in rows if not row["strict_valid"]),
            "destination_stack_depths": destination_depths,
            "value_stack_depths": value_depths,
            "minimum_incoming_stack": minimum_incoming,
            "net_stack_deltas": net_stack_deltas,
        },
        "rows": rows,
    }


def main() -> None:
    parser = argparse.ArgumentParser(description="Audit aligned MES command-0x0A dword write structures.")
    parser.add_argument("archive", type=Path)
    parser.add_argument("--entry", default="", help="Optional case-insensitive MES/LIB entry name.")
    parser.add_argument("-o", "--output", type=Path)
    args = parser.parse_args()
    result = audit_archive(args.archive, args.entry)
    encoded = json.dumps(result, ensure_ascii=False, indent=2)
    if args.output:
        args.output.write_text(encoded + "\n", encoding="utf-8")
    else:
        print(encoded)
    summary = result["summary"]
    print(
        "command0a rows={command_0a_rows} strict={strict_valid_rows} non_strict={non_strict_rows}".format(
            **summary
        )
    )


if __name__ == "__main__":
    main()
