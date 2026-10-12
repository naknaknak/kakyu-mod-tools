from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
from typing import Any

import mes_basic_block_ir_v6
from extract_kakyu_arc import read_entries
from payload_values import sha256_file as _sha256_file


SCHEMA = "kakyu_mes_command03_audit/v3"


def _increment(counter: dict[str, int], value: int) -> None:
    key = str(value)
    counter[key] = counter.get(key, 0) + 1


def write_json_atomic(path: Path, value: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name + ".tmp")
    temporary.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    temporary.replace(path)


def _normalize_focus_indices(focus_indices: int | list[int] | tuple[int, ...] | None) -> list[int]:
    if focus_indices is None:
        return []
    values = [focus_indices] if isinstance(focus_indices, int) else list(focus_indices)
    result: list[int] = []
    seen: set[int] = set()
    for raw_value in values:
        value = int(raw_value)
        if value < 0 or value > 0xFFFF:
            raise ValueError(f"focus index outside 0..65535: {value}")
        if value in seen:
            continue
        seen.add(value)
        result.append(value)
    return result


def audit_archive(
    archive: Path,
    focus_indices: int | list[int] | tuple[int, ...] | None = None,
) -> dict[str, Any]:
    archive = archive.resolve()
    normalized_focus = _normalize_focus_indices(focus_indices)
    focus_set = set(normalized_focus)
    summary: dict[str, Any] = {
        "script_entries": 0,
        "entries_with_command_03": 0,
        "command_03_runs": 0,
        "write_values": 0,
        "multi_write_runs": 0,
        "max_run_length": 0,
        "strict_valid_runs": 0,
        "strict_valid_write_values": 0,
        "strict_valid_multi_write_runs": 0,
        "strict_valid_max_run_length": 0,
        "max_written_index": 0,
        "invalid_expression_pairs": 0,
        "index_overflow_runs": 0,
        "conflicting_duplicate_offsets": 0,
        "continuation_values": {},
        "strict_valid_continuation_values": {},
    }
    samples: list[dict[str, Any]] = []
    focus_records: dict[int, list[dict[str, Any]]] = {
        index: [] for index in normalized_focus
    }
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
            document = mes_basic_block_ir_v6.decode_mes(data, {"archive": archive.name, "entry": entry_name, "sha256": entry_sha})
            by_offset: dict[int, dict[str, Any]] = {}
            entry_has_write = False
            for node in document["nodes"]:
                for instruction in node["instructions"]:
                    if int(instruction["commandId"]) != 0x03:
                        continue
                    offset = int(instruction["sourceOffset"])
                    previous = by_offset.get(offset)
                    if previous is not None:
                        if previous["rawHex"] != instruction["rawHex"]:
                            summary["conflicting_duplicate_offsets"] += 1
                        continue
                    by_offset[offset] = instruction
            for offset, instruction in sorted(by_offset.items()):
                entry_has_write = True
                start_index = int(instruction["operands"][0]["value"])
                pairs = instruction["operands"][1]["pairs"]
                pair_count = len(pairs)
                summary["command_03_runs"] += 1
                summary["write_values"] += pair_count
                summary["max_run_length"] = max(summary["max_run_length"], pair_count)
                summary["max_written_index"] = max(summary["max_written_index"], start_index + pair_count - 1)
                if pair_count > 1:
                    summary["multi_write_runs"] += 1
                if start_index + pair_count > 0x10000:
                    summary["index_overflow_runs"] += 1
                continuation_values = [int(pair["continuation"]) for pair in pairs]
                valid_pairs = [bool(pair["expression"].get("valid", False)) for pair in pairs]
                for pair_index, pair in enumerate(pairs):
                    written_index = (start_index + pair_index) & 0xFFFF
                    if written_index not in focus_set:
                        continue
                    expression = pair["expression"]
                    focus_records[written_index].append(
                        {
                            "entry": entry_name,
                            "entry_sha256": entry_sha,
                            "source_offset": offset,
                            "start_index": start_index,
                            "write_count": pair_count,
                            "pair_index": pair_index,
                            "strict_valid": bool(expression.get("valid", False)),
                            "continuation": int(pair["continuation"]),
                            "expression_ast": expression.get("ast", {}),
                        }
                    )
                for continuation in continuation_values:
                    _increment(summary["continuation_values"], continuation)
                summary["invalid_expression_pairs"] += valid_pairs.count(False)
                if all(valid_pairs):
                    summary["strict_valid_runs"] += 1
                    summary["strict_valid_write_values"] += pair_count
                    summary["strict_valid_max_run_length"] = max(summary["strict_valid_max_run_length"], pair_count)
                    if pair_count > 1:
                        summary["strict_valid_multi_write_runs"] += 1
                    for continuation in continuation_values:
                        _increment(summary["strict_valid_continuation_values"], continuation)
                if all(valid_pairs) and pair_count > 1 and len(samples) < 24:
                    samples.append(
                        {
                            "entry": entry_name,
                            "source_offset": offset,
                            "start_index": start_index,
                            "write_count": pair_count,
                            "continuations": continuation_values,
                        }
                    )
            if entry_has_write:
                summary["entries_with_command_03"] += 1

    result: dict[str, Any] = {
        "schema": SCHEMA,
        "archive": archive.name,
        "archive_sha256": _sha256_file(archive),
        "offset_basis": "mes_code_start",
        "storage": "global_u8",
        "summary": summary,
        "multi_write_samples": samples,
    }
    if normalized_focus:
        focus_summaries = [
            {
                "index": index,
                "write_count": len(focus_records[index]),
                "strict_valid_write_count": sum(
                    1 for record in focus_records[index] if record["strict_valid"]
                ),
                "records": focus_records[index],
            }
            for index in normalized_focus
        ]
        result["focus_indices"] = focus_summaries
        if len(focus_summaries) == 1:
            result["focus_index"] = focus_summaries[0]
    return result


def _u16(value: str) -> int:
    parsed = int(value, 0)
    if parsed < 0 or parsed > 0xFFFF:
        raise argparse.ArgumentTypeError("focus index must be in 0..65535")
    return parsed


def main() -> None:
    parser = argparse.ArgumentParser(description="Audit native command 0x03 global_u8 write runs across mes.arc.")
    parser.add_argument("archive", type=Path)
    parser.add_argument("-o", "--output", type=Path)
    parser.add_argument(
        "--focus-index",
        type=_u16,
        action="append",
        help="Include decoded writes covering this global_u8 index; repeat for a single-pass set",
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
        write_json_atomic(args.output.resolve(), result)


if __name__ == "__main__":
    main()
