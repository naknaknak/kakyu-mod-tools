from __future__ import annotations

import argparse
import bisect
import heapq
import json
from pathlib import Path
from typing import Any

import mes_control_flow_ir as control_decoder
import mes_fixed_point_control_ir
import mes_partial_decoder as base_decoder
from mes_archive_ir import load_archive_entry, parse_mes_container


ROOT = Path(__file__).resolve().parents[1]
TRACE_TERMINATORS = {0x0B, 0x14, 0x18, 0x1D}


def unique_decoded_bytes(document: dict[str, Any]) -> int:
    ranges = sorted(
        (int(instruction["sourceOffset"]), int(instruction["endOffset"]))
        for node in document["nodes"]
        for instruction in node["instructions"]
    )
    total = 0
    merged_end = 0
    for start, end in ranges:
        if end <= merged_end:
            continue
        total += end - max(start, merged_end)
        merged_end = end
    return total


def add_overlapping_paths(document: dict[str, Any], data: bytes) -> None:
    container = parse_mes_container(data, document.get("source"))
    code_offset = int(container["header"]["codeOffset"])
    code = data[code_offset:]
    code_size = len(code)
    entry_offsets = [int(value) for value in container["header"]["entryOffsets"]]
    instruction_by_offset: dict[int, dict[str, Any]] = {
        int(instruction["sourceOffset"]): instruction
        for node in document["nodes"]
        for instruction in node["instructions"]
    }
    starts = sorted(instruction_by_offset)
    seed_heap: list[int] = []
    queued: set[int] = set()
    processed: set[int] = set()
    overlap_samples: list[dict[str, Any]] = []
    decode_error_samples: list[dict[str, Any]] = []

    def containing_instruction(offset: int) -> tuple[int, int] | None:
        candidates = [start for start in starts if start < offset]
        for start in reversed(candidates):
            end = int(instruction_by_offset[start]["endOffset"])
            if offset < end:
                return start, end
            if end <= offset:
                break
        return None

    def enqueue(offset: int) -> None:
        if not 0 <= offset < code_size or offset in queued or offset in processed:
            return
        if offset in instruction_by_offset:
            return
        queued.add(offset)
        heapq.heappush(seed_heap, offset)

    for value in document.get("fixedPointDiagnostics", {}).get("rejectedInteriorTargetOffsets", []):
        enqueue(int(value))

    added_nodes: list[dict[str, Any]] = []
    added_instruction_count = 0
    added_condition_count = 0
    added_resolved_condition_count = 0
    added_invalid_condition_count = 0
    discovered_targets: set[int] = set()

    while seed_heap:
        start = heapq.heappop(seed_heap)
        queued.discard(start)
        if start in processed or start in instruction_by_offset:
            continue
        processed.add(start)
        containing = containing_instruction(start)
        if containing is not None and len(overlap_samples) < 100:
            overlap_samples.append(
                {"targetOffset": start, "otherPathInstructionOffset": containing[0], "otherPathEndOffset": containing[1]}
            )
        cursor = start
        limit = mes_fixed_point_control_ir.region_end(entry_offsets, start, code_size)
        instructions: list[dict[str, Any]] = []
        stop_reason = "region_end"
        error: str | None = None

        while cursor < limit:
            if cursor in instruction_by_offset:
                stop_reason = "joins_existing_path"
                break
            try:
                instruction = control_decoder.decode_instruction(code, cursor, limit)
            except base_decoder.MesDecodeError as exc:
                error = str(exc)
                stop_reason = "decode_error"
                break
            if instruction is None:
                stop_reason = "unknown_command"
                break
            instructions.append(instruction)
            instruction_by_offset[cursor] = instruction
            bisect.insort(starts, cursor)
            added_instruction_count += 1
            end_offset = int(instruction["endOffset"])
            command_id = int(instruction["commandId"])
            source_node = f"overlap_{start:08x}"

            if command_id == 0x0B:
                added_condition_count += 1
                condition = instruction["operands"][0]["value"]
                target = int(instruction["operands"][1]["value"])
                target_region = control_decoder.containing_region(entry_offsets, target, code_size)
                fallthrough_region = control_decoder.containing_region(entry_offsets, end_offset, code_size)
                if target_region is not None:
                    added_resolved_condition_count += 1
                    discovered_targets.add(target)
                else:
                    added_invalid_condition_count += 1
                document["edges"].extend(
                    [
                        {
                            "type": "condition_false",
                            "predicate": "value != 1",
                            "source": source_node,
                            "sourceOffset": cursor,
                            "condition": condition,
                            "target": control_decoder.offset_id(target) if target_region else None,
                            "targetOffset": target,
                            "targetRegion": target_region,
                            "resolved": target_region is not None,
                            "commandId": 0x0B,
                        },
                        {
                            "type": "condition_true",
                            "predicate": "value == 1",
                            "source": source_node,
                            "sourceOffset": cursor,
                            "condition": condition,
                            "target": control_decoder.offset_id(end_offset) if fallthrough_region else None,
                            "targetOffset": end_offset,
                            "targetRegion": fallthrough_region,
                            "resolved": fallthrough_region is not None,
                            "commandId": 0x0B,
                        },
                    ]
                )
                if condition.get("valid", False):
                    enqueue(target)
                    enqueue(end_offset)
                stop_reason = "condition_branch"
                cursor = end_offset
                break

            if command_id == 0x14:
                target = int(instruction["operands"][1]["value"])
                target_region = control_decoder.containing_region(entry_offsets, target, code_size)
                document["edges"].append(
                    {
                        "type": "transfer",
                        "source": source_node,
                        "sourceOffset": cursor,
                        "target": control_decoder.offset_id(target) if target_region else None,
                        "targetOffset": target,
                        "targetRegion": target_region,
                        "resolved": target_region is not None,
                        "commandId": command_id,
                    }
                )
                if target_region is not None:
                    enqueue(target)
                stop_reason = "transfer"
                cursor = end_offset
                break

            if command_id in {0x18, 0x1D}:
                stop_reason = "jump_table" if command_id == 0x18 else "script_transfer"
                cursor = end_offset
                break
            cursor = end_offset

        if instructions:
            node: dict[str, Any] = {
                "id": f"overlap_{start:08x}",
                "offset": start,
                "endOffset": limit,
                "instructions": instructions,
                "decodedEndOffset": cursor,
                "fullyDecoded": cursor == limit,
                "seedReason": "overlapping_condition_target",
                "stopReason": stop_reason,
                "containingRegion": mes_fixed_point_control_ir.region_id(entry_offsets, start),
            }
            if error:
                node["decodeError"] = error
                if len(decode_error_samples) < 100:
                    decode_error_samples.append({"seedOffset": start, "offset": cursor, "message": error})
            added_nodes.append(node)

    document["nodes"].extend(added_nodes)
    document["nodes"].sort(key=lambda node: (int(node["offset"]), str(node["id"])))
    document["edges"].sort(key=lambda edge: (int(edge.get("sourceOffset", -1)), str(edge["type"])))
    document["nodeCount"] = len(document["nodes"])
    document["decodedByteCount"] = unique_decoded_bytes(document)
    document["decodedRatio"] = document["decodedByteCount"] / code_size if code_size else 1.0
    flow = document["controlFlow"]
    flow["conditionBranchCount"] = int(flow["conditionBranchCount"]) + added_condition_count
    flow["resolvedConditionBranchCount"] = int(flow["resolvedConditionBranchCount"]) + added_resolved_condition_count
    flow["invalidConditionBranchCount"] = int(flow["invalidConditionBranchCount"]) + added_invalid_condition_count
    flow["branchTargetOffsets"] = sorted(set(int(value) for value in flow["branchTargetOffsets"]) | discovered_targets)
    flow["overlappingPathTargetCount"] = len(processed)
    flow["overlappingPathNodeCount"] = len(added_nodes)
    flow["overlappingPathInstructionCount"] = added_instruction_count
    document["overlappingPathDiagnostics"] = {
        "overlapSamples": overlap_samples,
        "decodeErrorSamples": decode_error_samples,
    }
    document["diagnostics"].append(
        {
            "level": "info",
            "code": "overlapping_bytecode_paths",
            "message": "Condition targets inside another path's operand span are decoded as path-specific instruction streams.",
        }
    )


def decode_mes(data: bytes, source: dict[str, Any] | None = None) -> dict[str, Any]:
    document = mes_fixed_point_control_ir.decode_mes(data, source)
    add_overlapping_paths(document, data)
    document["schema"] = "ai5_mes_overlapping_control_ir/v1"
    return document


def main() -> None:
    parser = argparse.ArgumentParser(description="Decode overlapping MES bytecode paths reached by valid conditions.")
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
        flow = document["controlFlow"]
        print(
            f"{source['entry']}: nodes={document['nodeCount']} overlapNodes={flow['overlappingPathNodeCount']} "
            f"branches={flow['conditionBranchCount']} decoded={document['decodedRatio']:.1%} output={output}"
        )
    else:
        print(encoded)


if __name__ == "__main__":
    main()
