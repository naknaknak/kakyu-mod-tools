from __future__ import annotations

import argparse
import bisect
import json
from pathlib import Path
from typing import Any

import mes_loop_ir as loop_decoder
import mes_partial_decoder as base_decoder
import mes_tolerant_ir as tolerant_decoder
from mes_archive_ir import load_archive_entry, parse_mes_container


ROOT = Path(__file__).resolve().parents[1]
LOOP_DECODE_INSTRUCTION = loop_decoder.decode_instruction


def decode_instruction(code: bytes, offset: int, limit: int) -> dict[str, Any] | None:
    if offset >= limit or code[offset] != 0x0B:
        return LOOP_DECODE_INSTRUCTION(code, offset, limit)
    cursor = offset + 1
    condition, cursor = tolerant_decoder.decode_expression(code, cursor, limit)
    target, cursor = base_decoder.read_u32(code, cursor, limit)
    return base_decoder.finish_instruction(
        code,
        offset,
        cursor,
        "branch_if_not_true",
        0x0B,
        [
            {"type": "condition", "value": condition},
            {"type": "code_offset", "value": target},
        ],
    )


def containing_region(entry_offsets: list[int], target: int, code_size: int) -> str | None:
    if not 0 <= target < code_size:
        return None
    index = bisect.bisect_right(entry_offsets, target) - 1
    return "bootstrap" if index < 0 else f"entry_{index:04d}"


def offset_id(offset: int) -> str:
    return f"offset_{offset:08x}"


def add_condition_edges(document: dict[str, Any], entry_offsets: list[int]) -> None:
    code_size = int(document["codeSize"])
    branch_targets: set[int] = set()
    branch_count = 0
    resolved_count = 0
    invalid_count = 0

    for node in document["nodes"]:
        for instruction in node["instructions"]:
            if instruction["commandId"] != 0x0B:
                continue
            branch_count += 1
            condition = instruction["operands"][0]["value"]
            target = int(instruction["operands"][1]["value"])
            fallthrough = int(instruction["endOffset"])
            target_region = containing_region(entry_offsets, target, code_size)
            fallthrough_region = containing_region(entry_offsets, fallthrough, code_size)
            resolved = target_region is not None
            if resolved:
                branch_targets.add(target)
                resolved_count += 1
            else:
                invalid_count += 1

            document["edges"].append(
                {
                    "type": "condition_false",
                    "predicate": "value != 1",
                    "source": node["id"],
                    "sourceOffset": instruction["sourceOffset"],
                    "condition": condition,
                    "target": offset_id(target) if resolved else None,
                    "targetOffset": target,
                    "targetRegion": target_region,
                    "resolved": resolved,
                    "commandId": 0x0B,
                }
            )
            document["edges"].append(
                {
                    "type": "condition_true",
                    "predicate": "value == 1",
                    "source": node["id"],
                    "sourceOffset": instruction["sourceOffset"],
                    "condition": condition,
                    "target": offset_id(fallthrough) if fallthrough_region is not None else None,
                    "targetOffset": fallthrough,
                    "targetRegion": fallthrough_region,
                    "resolved": fallthrough_region is not None,
                    "commandId": 0x0B,
                }
            )

    document["edges"].sort(key=lambda edge: (int(edge.get("sourceOffset", -1)), edge["type"]))
    document["controlFlow"] = {
        "conditionBranchCount": branch_count,
        "resolvedConditionBranchCount": resolved_count,
        "invalidConditionBranchCount": invalid_count,
        "branchTargetOffsets": sorted(branch_targets),
        "targetIdFormat": "offset_%08x",
        "offsetBasis": "code_start",
    }


def decode_mes(data: bytes, source: dict[str, Any] | None = None) -> dict[str, Any]:
    container = parse_mes_container(data, source)
    entry_offsets = [int(value) for value in container["header"]["entryOffsets"]]
    previous_instruction = base_decoder.decode_instruction
    previous_expression = base_decoder.decode_expression
    base_decoder.decode_instruction = decode_instruction
    base_decoder.decode_expression = tolerant_decoder.decode_expression
    try:
        document = base_decoder.decode_mes(data, source)
    finally:
        base_decoder.decode_instruction = previous_instruction
        base_decoder.decode_expression = previous_expression
    add_condition_edges(document, entry_offsets)
    document["schema"] = "ai5_mes_control_flow_ir/v1"
    document["diagnostics"].append(
        {
            "level": "info",
            "code": "command_0b_condition_edges",
            "message": (
                "Command 0x0b branches to its code offset when the expression result is not 1; "
                "result 1 falls through."
            ),
        }
    )
    return document


def main() -> None:
    parser = argparse.ArgumentParser(description="Convert MES conditions and control transfers to Godot-friendly JSON IR.")
    parser.add_argument("archive", type=Path)
    parser.add_argument("entry")
    parser.add_argument("-o", "--output", type=Path)
    args = parser.parse_args()
    archive = args.archive if args.archive.is_absolute() else ROOT / args.archive
    data, source = load_archive_entry(archive, args.entry)
    document = decode_mes(data, source)
    encoded = json.dumps(document, ensure_ascii=False, indent=2)
    if args.output:
        output = args.output if args.output.is_absolute() else ROOT / args.output
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(encoded + "\n", encoding="utf-8")
        print(
            f"{source['entry']}: nodes={document['nodeCount']} edges={len(document['edges'])} "
            f"branches={document['controlFlow']['conditionBranchCount']} "
            f"decoded={document['decodedRatio']:.1%} output={output}"
        )
    else:
        print(encoded)


if __name__ == "__main__":
    main()
