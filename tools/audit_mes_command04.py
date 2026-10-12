from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
from typing import Any

import mes_basic_block_ir_v6
from extract_kakyu_arc import read_entries
from payload_values import sha256_file as _sha256_file


SCHEMA = "kakyu_mes_command04_audit/v2"


def _increment(counter: dict[str, int], value: int) -> None:
    key = str(value)
    counter[key] = counter.get(key, 0) + 1


def audit_archive(archive: Path, focus_index: int | None = None) -> dict[str, Any]:
    archive = archive.resolve()
    summary: dict[str, Any] = {
        "script_entries": 0,
        "entries_with_command_04": 0,
        "command_04_runs": 0,
        "write_values": 0,
        "multi_write_runs": 0,
        "strict_valid_runs": 0,
        "strict_valid_write_values": 0,
        "strict_valid_multi_write_runs": 0,
        "strict_valid_index_overflow_runs": 0,
        "strict_valid_max_run_length": 0,
        "strict_valid_continuation_values": {},
        "structural_only_runs": 0,
        "structural_only_multi_write_runs": 0,
        "structural_only_index_overflow_runs": 0,
        "index_overflow_runs": 0,
        "max_run_length": 0,
        "max_written_index": 0,
        "conflicting_duplicate_offsets": 0,
        "continuation_values": {},
        "start_indices": {},
        "written_indices": {},
    }
    samples: list[dict[str, Any]] = []
    focus_records: list[dict[str, Any]] = []
    with archive.open("rb") as source:
        for entry_name, archive_offset, size in read_entries(archive):
            if Path(entry_name).suffix.lower() not in {".mes", ".lib"}:
                continue
            summary["script_entries"] += 1
            source.seek(archive_offset)
            data = source.read(size)
            if len(data) != size:
                raise ValueError(f"truncated archive read for {entry_name}")
            entry_sha = hashlib.sha256(data).hexdigest()
            document = mes_basic_block_ir_v6.decode_mes(
                data,
                {"archive": archive.name, "entry": entry_name, "sha256": entry_sha},
            )
            by_offset: dict[int, dict[str, Any]] = {}
            for node in document["nodes"]:
                for instruction in node["instructions"]:
                    if int(instruction["commandId"]) != 0x04:
                        continue
                    offset = int(instruction["sourceOffset"])
                    previous = by_offset.get(offset)
                    if previous is not None:
                        if previous["rawHex"] != instruction["rawHex"]:
                            summary["conflicting_duplicate_offsets"] += 1
                        continue
                    by_offset[offset] = instruction
            if by_offset:
                summary["entries_with_command_04"] += 1
            for offset, instruction in sorted(by_offset.items()):
                start_index = int(instruction["operands"][0]["value"])
                pairs = instruction["operands"][1]["pairs"]
                pair_count = len(pairs)
                valid = all(bool(pair["expression"].get("valid", False)) for pair in pairs)
                continuations = [int(pair["continuation"]) for pair in pairs]
                summary["command_04_runs"] += 1
                summary["write_values"] += pair_count
                summary["max_run_length"] = max(summary["max_run_length"], pair_count)
                summary["max_written_index"] = max(summary["max_written_index"], start_index + pair_count - 1)
                _increment(summary["start_indices"], start_index)
                for pair_index, pair in enumerate(pairs):
                    written_index = (start_index + pair_index) & 0xFF
                    _increment(summary["written_indices"], written_index)
                    if focus_index is None or written_index != focus_index:
                        continue
                    expression = pair["expression"]
                    focus_records.append(
                        {
                            "entry": entry_name,
                            "source_offset": offset,
                            "start_index": start_index,
                            "write_count": pair_count,
                            "pair_index": pair_index,
                            "strict_valid": bool(expression.get("valid", False)),
                            "expression_ast": expression.get("ast", {}),
                        }
                    )
                for continuation in continuations:
                    _increment(summary["continuation_values"], continuation)
                if pair_count > 1:
                    summary["multi_write_runs"] += 1
                if start_index + pair_count > 0x100:
                    summary["index_overflow_runs"] += 1
                if valid:
                    summary["strict_valid_runs"] += 1
                    summary["strict_valid_write_values"] += pair_count
                    summary["strict_valid_max_run_length"] = max(
                        summary["strict_valid_max_run_length"], pair_count
                    )
                    if pair_count > 1:
                        summary["strict_valid_multi_write_runs"] += 1
                    if start_index + pair_count > 0x100:
                        summary["strict_valid_index_overflow_runs"] += 1
                    for continuation in continuations:
                        _increment(summary["strict_valid_continuation_values"], continuation)
                else:
                    summary["structural_only_runs"] += 1
                    if pair_count > 1:
                        summary["structural_only_multi_write_runs"] += 1
                    if start_index + pair_count > 0x100:
                        summary["structural_only_index_overflow_runs"] += 1
                if (pair_count > 1 or not valid) and len(samples) < 32:
                    samples.append(
                        {
                            "entry": entry_name,
                            "source_offset": offset,
                            "start_index": start_index,
                            "write_count": pair_count,
                            "continuations": continuations,
                            "strict_valid": valid,
                        }
                    )
    result = {
        "schema": SCHEMA,
        "archive": archive.name,
        "archive_sha256": _sha256_file(archive),
        "offset_basis": "mes_code_start",
        "storage": "state_u16",
        "summary": summary,
        "samples": samples,
    }
    if focus_index is not None:
        result["focus_index"] = {
            "index": focus_index,
            "write_count": len(focus_records),
            "strict_valid_write_count": sum(
                1 for record in focus_records if record["strict_valid"]
            ),
            "records": focus_records,
        }
    return result


def _write_json_atomic(path: Path, value: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name + ".tmp")
    temporary.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    temporary.replace(path)


def main() -> None:
    parser = argparse.ArgumentParser(description="Audit native command 0x04 state_u16 write runs across mes.arc.")
    parser.add_argument("archive", type=Path)
    parser.add_argument("-o", "--output", type=Path)
    parser.add_argument(
        "--focus-index",
        type=lambda value: int(value, 0),
        choices=range(0x100),
        help="Include decoded write records that cover one state_u16 index",
    )
    args = parser.parse_args()
    archive = args.archive.resolve()
    if args.output:
        output = args.output.resolve()
        if output == archive or output == archive.parent or archive.parent in output.parents:
            parser.error("output must be outside the source archive directory")
    result = audit_archive(archive, args.focus_index)
    print(json.dumps(result, ensure_ascii=False, indent=2))
    if args.output:
        _write_json_atomic(args.output.resolve(), result)


if __name__ == "__main__":
    main()
