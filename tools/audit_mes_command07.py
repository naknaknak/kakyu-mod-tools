from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
from typing import Any

import mes_basic_block_ir_v6
from extract_kakyu_arc import read_entries
from payload_values import sha256_file as _sha256_file


SCHEMA = "kakyu_mes_banked_write_audit/v3"


def _write_json_atomic(path: Path, value: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name + ".tmp")
    temporary.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    temporary.replace(path)


def _literal_value(expression: dict[str, Any]) -> int | None:
    ast = expression.get("ast", {})
    if ast.get("type") != "literal":
        return None
    return int(ast["value"])


def _increment(counter: dict[str, int], value: int) -> None:
    key = str(value)
    counter[key] = counter.get(key, 0) + 1


def audit_archive(
    archive: Path,
    command_id: int = 0x07,
    focus_start_index: int | None = None,
    focus_end_index: int | None = None,
    focus_bank: int | None = None,
    focus_record_limit: int = 256,
) -> dict[str, Any]:
    if command_id not in {0x06, 0x07, 0x08}:
        raise ValueError(f"unsupported banked-write command: 0x{command_id:02X}")
    if (focus_start_index is None) != (focus_end_index is None):
        raise ValueError("focus start and end indices must be supplied together")
    if focus_start_index is not None and focus_start_index > int(focus_end_index):
        raise ValueError("focus start index must not exceed its end index")
    if focus_record_limit < 0:
        raise ValueError("focus record limit must not be negative")
    storage = {0x06: "banked_u8", 0x07: "banked_u16", 0x08: "banked_i32"}[command_id]
    archive = archive.resolve()
    summary: dict[str, Any] = {
        "script_entries": 0,
        "entries_with_command": 0,
        "command_runs": 0,
        "write_values": 0,
        "multi_write_runs": 0,
        "max_run_length": 0,
        "strict_valid_runs": 0,
        "strict_valid_write_values": 0,
        "strict_valid_multi_write_runs": 0,
        "strict_valid_max_run_length": 0,
        "literal_destination_runs": 0,
        "dynamic_destination_runs": 0,
        "max_literal_written_index": 0,
        "strict_valid_literal_destination_runs": 0,
        "strict_valid_dynamic_destination_runs": 0,
        "strict_valid_max_literal_written_index": 0,
        "invalid_expressions": 0,
        "conflicting_duplicate_offsets": 0,
        "bank_values": {},
        "strict_valid_bank_values": {},
        "continuation_values": {},
        "strict_valid_continuation_values": {},
    }
    samples: list[dict[str, Any]] = []
    nonzero_bank_samples: list[dict[str, Any]] = []
    longest_strict_run: dict[str, Any] = {}
    focus_records: list[dict[str, Any]] = []
    potential_dynamic_records: list[dict[str, Any]] = []
    focus_write_count = 0
    focus_strict_write_count = 0
    focus_index_counts: dict[str, int] = {}
    focus_entry_counts: dict[str, int] = {}
    potential_dynamic_count = 0
    potential_dynamic_entry_counts: dict[str, int] = {}
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
                    if int(instruction["commandId"]) != command_id:
                        continue
                    offset = int(instruction["sourceOffset"])
                    previous = by_offset.get(offset)
                    if previous is not None:
                        if previous["rawHex"] != instruction["rawHex"]:
                            summary["conflicting_duplicate_offsets"] += 1
                        continue
                    by_offset[offset] = instruction
            if by_offset:
                summary["entries_with_command"] += 1
            for offset, instruction in sorted(by_offset.items()):
                destination = instruction["operands"][0]["value"]
                bank = int(instruction["operands"][1]["value"])
                pairs = instruction["operands"][2]["pairs"]
                pair_count = len(pairs)
                _increment(summary["bank_values"], bank)
                summary["command_runs"] += 1
                summary["write_values"] += pair_count
                summary["max_run_length"] = max(summary["max_run_length"], pair_count)
                if pair_count > 1:
                    summary["multi_write_runs"] += 1
                continuations = [int(pair["continuation"]) for pair in pairs]
                for continuation in continuations:
                    _increment(summary["continuation_values"], continuation)
                valid_expressions = [bool(destination.get("valid", False))]
                valid_expressions.extend(bool(pair["expression"].get("valid", False)) for pair in pairs)
                summary["invalid_expressions"] += valid_expressions.count(False)
                literal_destination = _literal_value(destination)
                if literal_destination is None:
                    summary["dynamic_destination_runs"] += 1
                    if (
                        focus_start_index is not None
                        and (focus_bank is None or bank == focus_bank)
                    ):
                        potential_dynamic_count += 1
                        potential_dynamic_entry_counts[entry_name] = potential_dynamic_entry_counts.get(entry_name, 0) + 1
                        if len(potential_dynamic_records) < focus_record_limit:
                            potential_dynamic_records.append(
                                {
                                    "entry": entry_name,
                                    "entry_sha256": entry_sha,
                                    "source_offset": offset,
                                    "bank": bank,
                                    "write_count": pair_count,
                                    "strict_valid": all(valid_expressions),
                                    "destination_ast": destination.get("ast", {}),
                                }
                            )
                else:
                    summary["literal_destination_runs"] += 1
                    summary["max_literal_written_index"] = max(
                        summary["max_literal_written_index"],
                        literal_destination + pair_count - 1,
                    )
                    if focus_start_index is not None and (focus_bank is None or bank == focus_bank):
                        for pair_index, pair in enumerate(pairs):
                            written_index = literal_destination + pair_index
                            if focus_start_index <= written_index <= int(focus_end_index):
                                strict_valid = bool(destination.get("valid", False)) and bool(
                                    pair["expression"].get("valid", False)
                                )
                                focus_write_count += 1
                                focus_strict_write_count += int(strict_valid)
                                _increment(focus_index_counts, written_index)
                                focus_entry_counts[entry_name] = focus_entry_counts.get(entry_name, 0) + 1
                                if len(focus_records) < focus_record_limit:
                                    focus_records.append(
                                        {
                                            "entry": entry_name,
                                            "entry_sha256": entry_sha,
                                            "source_offset": offset,
                                            "bank": bank,
                                            "start_index": literal_destination,
                                            "written_index": written_index,
                                            "pair_index": pair_index,
                                            "write_count": pair_count,
                                            "strict_valid": strict_valid,
                                            "expression_ast": pair["expression"].get("ast", {}),
                                        }
                                    )
                if all(valid_expressions):
                    _increment(summary["strict_valid_bank_values"], bank)
                    summary["strict_valid_runs"] += 1
                    summary["strict_valid_write_values"] += pair_count
                    summary["strict_valid_max_run_length"] = max(summary["strict_valid_max_run_length"], pair_count)
                    if pair_count > 1:
                        summary["strict_valid_multi_write_runs"] += 1
                    for continuation in continuations:
                        _increment(summary["strict_valid_continuation_values"], continuation)
                    if literal_destination is None:
                        summary["strict_valid_dynamic_destination_runs"] += 1
                    else:
                        summary["strict_valid_literal_destination_runs"] += 1
                        summary["strict_valid_max_literal_written_index"] = max(
                            summary["strict_valid_max_literal_written_index"],
                            literal_destination + pair_count - 1,
                        )
                    sample = {
                        "entry": entry_name,
                        "source_offset": offset,
                        "bank": bank,
                        "literal_start_index": literal_destination,
                        "write_count": pair_count,
                        "continuations": continuations,
                    }
                    if pair_count > int(longest_strict_run.get("write_count", 0)):
                        longest_strict_run = sample
                    if bank != 0 and len(nonzero_bank_samples) < 16:
                        nonzero_bank_samples.append(sample)
                    if (pair_count > 1 or len(samples) < 8) and len(samples) < 24:
                        samples.append(sample)

    result = {
        "schema": SCHEMA,
        "command_id": command_id,
        "storage": storage,
        "archive": archive.name,
        "archive_sha256": _sha256_file(archive),
        "offset_basis": "mes_code_start",
        "summary": summary,
        "samples": samples,
        "longest_strict_run": longest_strict_run,
        "strict_nonzero_bank_samples": nonzero_bank_samples,
    }
    if focus_start_index is not None:
        result["focus_range"] = {
            "start_index": focus_start_index,
            "end_index": focus_end_index,
            "bank": focus_bank,
            "literal_write_count": focus_write_count,
            "strict_valid_literal_write_count": focus_strict_write_count,
            "literal_write_counts_by_index": focus_index_counts,
            "literal_write_counts_by_entry": focus_entry_counts,
            "record_limit": focus_record_limit,
            "records_truncated": focus_write_count > len(focus_records),
            "records": focus_records,
            "potential_dynamic_run_count": potential_dynamic_count,
            "potential_dynamic_counts_by_entry": potential_dynamic_entry_counts,
            "potential_dynamic_records_truncated": potential_dynamic_count > len(potential_dynamic_records),
            "potential_dynamic_records": potential_dynamic_records,
        }
    return result


def main() -> None:
    parser = argparse.ArgumentParser(description="Audit native command 0x06/0x07/0x08 banked write runs across mes.arc.")
    parser.add_argument("archive", type=Path)
    parser.add_argument("-o", "--output", type=Path)
    parser.add_argument("--command-id", type=lambda value: int(value, 0), choices=(0x06, 0x07, 0x08), default=0x07)
    parser.add_argument("--focus-start-index", type=lambda value: int(value, 0))
    parser.add_argument("--focus-end-index", type=lambda value: int(value, 0))
    parser.add_argument("--focus-bank", type=lambda value: int(value, 0))
    parser.add_argument(
        "--focus-record-limit",
        type=int,
        default=256,
        help="Maximum literal and dynamic focus records retained after complete counting",
    )
    args = parser.parse_args()
    if (args.focus_start_index is None) != (args.focus_end_index is None):
        parser.error("--focus-start-index and --focus-end-index must be supplied together")
    archive = args.archive.resolve()
    if args.output:
        output = args.output.resolve()
        if output == archive or output == archive.parent or archive.parent in output.parents:
            parser.error("output must be outside the source archive directory")
    result = audit_archive(
        archive,
        args.command_id,
        args.focus_start_index,
        args.focus_end_index,
        args.focus_bank,
        args.focus_record_limit,
    )
    print(json.dumps(result, ensure_ascii=False, indent=2))
    if args.output:
        _write_json_atomic(args.output.resolve(), result)


if __name__ == "__main__":
    main()
