from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
from typing import Any

import mes_basic_block_ir_v6
from mes_archive_ir import load_archive_entry


SCHEMA = "kakyu_mes_instruction_oracle/v1"
DEFAULT_ENTRIES = ["START.MES", "MACHI.MES", "EVENTD03.MES", "D_TALK00.MES", "D_DATE3.MES"]


def expression_is_valid(value: Any) -> bool:
    if isinstance(value, dict):
        if "valid" in value and not bool(value["valid"]):
            return False
        return all(expression_is_valid(child) for child in value.values())
    if isinstance(value, list):
        return all(expression_is_valid(child) for child in value)
    return True


def collect_instructions(document: dict[str, Any], limit: int) -> tuple[list[dict[str, Any]], int, int]:
    candidates: dict[int, set[tuple[int, int, str, str]]] = {}
    metadata: dict[int, dict[str, Any]] = {}
    invalid_offsets: set[int] = set()
    for node in document["nodes"]:
        for instruction in node["instructions"]:
            offset = int(instruction["sourceOffset"])
            if not expression_is_valid(instruction.get("operands", [])):
                invalid_offsets.add(offset)
                continue
            signature = (
                int(instruction["endOffset"]),
                int(instruction["commandId"]),
                str(instruction["rawHex"]),
                str(instruction["op"]),
            )
            candidates.setdefault(offset, set()).add(signature)
            metadata.setdefault(offset, instruction)

    conflicts = sum(1 for signatures in candidates.values() if len(signatures) != 1)
    result: list[dict[str, Any]] = []
    for offset in sorted(candidates):
        signatures = candidates[offset]
        if len(signatures) != 1:
            continue
        end_offset, command_id, raw_hex, operation = next(iter(signatures))
        record = {
            "source_offset": offset,
            "end_offset": end_offset,
            "command_id": command_id,
            "raw_hex": raw_hex,
        }
        if command_id == 0x03:
            instruction = metadata[offset]
            pairs = instruction["operands"][1]["pairs"]
            record["op"] = operation
            record["write_start"] = int(instruction["operands"][0]["value"])
            record["write_count"] = len(pairs)
            record["continuations"] = [int(pair["continuation"]) for pair in pairs]
        elif command_id in {0x07, 0x08}:
            instruction = metadata[offset]
            pairs = instruction["operands"][2]["pairs"]
            record["op"] = operation
            record["destination_raw_hex"] = str(instruction["operands"][0]["value"]["raw_hex"])
            record["write_bank"] = int(instruction["operands"][1]["value"])
            record["write_count"] = len(pairs)
            record["continuations"] = [int(pair["continuation"]) for pair in pairs]
        result.append(record)
        if len(result) >= limit:
            break
    return result, conflicts, len(invalid_offsets)


def main() -> None:
    parser = argparse.ArgumentParser(description="Export a disposable MES instruction-boundary oracle cache.")
    parser.add_argument("archive", type=Path)
    parser.add_argument("-o", "--output", type=Path, required=True)
    parser.add_argument("--entry", action="append", dest="entries")
    parser.add_argument("--limit-per-entry", type=int, default=500)
    args = parser.parse_args()
    if args.limit_per_entry <= 0:
        parser.error("--limit-per-entry must be positive")
    archive_root = args.archive.resolve().parent
    output_path = args.output.resolve()
    if output_path == args.archive.resolve() or output_path == archive_root or archive_root in output_path.parents:
        parser.error("output must be outside the source archive directory")

    entries: list[dict[str, Any]] = []
    for entry_name in args.entries or DEFAULT_ENTRIES:
        data, source = load_archive_entry(args.archive, entry_name)
        document = mes_basic_block_ir_v6.decode_mes(data, {"entry": source["entry"], "sha256": source["sha256"]})
        instructions, conflicts, invalid_expressions = collect_instructions(document, args.limit_per_entry)
        entries.append(
            {
                "entry": source["entry"],
                "entry_sha256": source["sha256"],
                "code_size": int(document["codeSize"]),
                "decoded_ratio": float(document["decodedRatio"]),
                "omitted_conflicting_offsets": conflicts,
                "omitted_invalid_expression_offsets": invalid_expressions,
                "instructions": instructions,
            }
        )
        print(
            f"{source['entry']}: oracle={len(instructions)} conflicts={conflicts} invalid={invalid_expressions} "
            f"decoded={document['decodedRatio']:.1%}"
        )

    output = {
        "schema": SCHEMA,
        "generator": "tools/export_mes_instruction_oracle.py",
        "archive": args.archive.name,
        "archive_sha256": hashlib.sha256(args.archive.read_bytes()).hexdigest(),
        "entries": entries,
    }
    output_path.parent.mkdir(parents=True, exist_ok=True)
    temporary = output_path.with_name(output_path.name + ".tmp")
    temporary.write_text(json.dumps(output, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    temporary.replace(output_path)
    print(f"output={output_path} entries={len(entries)}")


if __name__ == "__main__":
    main()
