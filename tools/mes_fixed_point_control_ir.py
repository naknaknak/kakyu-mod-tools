from __future__ import annotations

import argparse
import bisect
import heapq
import json
from pathlib import Path
from typing import Any

import mes_control_flow_ir as control_decoder
import mes_partial_decoder as base_decoder
from mes_archive_ir import load_archive_entry, parse_mes_container


ROOT = Path(__file__).resolve().parents[1]
TRACE_TERMINATORS = {0x0B, 0x14, 0x18, 0x1D}


def region_id(entry_offsets: list[int], offset: int) -> str:
    index = bisect.bisect_right(entry_offsets, offset) - 1
    return "bootstrap" if index < 0 else f"entry_{index:04d}"


def region_end(entry_offsets: list[int], offset: int, code_size: int) -> int:
    index = bisect.bisect_right(entry_offsets, offset)
    return entry_offsets[index] if index < len(entry_offsets) else code_size


def literal_expression_value(operand: dict[str, Any]) -> int | None:
    value = operand.get("value", operand)
    ast = value.get("ast", {}) if isinstance(value, dict) else {}
    return int(ast["value"]) if ast.get("type") == "literal" else None


def add_fixed_point_paths(document: dict[str, Any], data: bytes) -> None:
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
    instruction_starts = sorted(instruction_by_offset)

    seed_heap: list[int] = []
    queued: set[int] = set()
    processed: set[int] = set()
    rejected_inside: set[int] = set()
    rejected_invalid_condition = 0
    decode_error_samples: list[dict[str, Any]] = []
    overlap_samples: list[dict[str, Any]] = []

    def instruction_containing(offset: int) -> tuple[int, int] | None:
        index = bisect.bisect_right(instruction_starts, offset) - 1
        if index < 0:
            return None
        start = instruction_starts[index]
        end = int(instruction_by_offset[start]["endOffset"])
        return (start, end) if start < offset < end else None

    def enqueue(offset: int) -> None:
        if not 0 <= offset < code_size or offset in queued or offset in processed:
            return
        if offset in instruction_by_offset:
            return
        containing = instruction_containing(offset)
        if containing is not None:
            rejected_inside.add(offset)
            return
        queued.add(offset)
        heapq.heappush(seed_heap, offset)

    for edge in document["edges"]:
        if not edge.get("resolved") or not str(edge.get("type", "")).startswith("condition_"):
            continue
        condition = edge.get("condition", {})
        if not condition.get("valid", False):
            rejected_invalid_condition += 1
            continue
        enqueue(int(edge["targetOffset"]))

    added_nodes: list[dict[str, Any]] = []
    added_instruction_count = 0
    added_byte_count = 0
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
        containing = instruction_containing(start)
        if containing is not None:
            rejected_inside.add(start)
            continue

        cursor = start
        limit = region_end(entry_offsets, start, code_size)
        instructions: list[dict[str, Any]] = []
        stop_reason = "region_end"
        error: str | None = None

        while cursor < limit:
            if cursor in instruction_by_offset:
                stop_reason = "joins_decoded_instruction"
                break
            containing = instruction_containing(cursor)
            if containing is not None:
                rejected_inside.add(cursor)
                stop_reason = "enters_decoded_instruction"
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

            end_offset = int(instruction["endOffset"])
            next_existing_index = bisect.bisect_right(instruction_starts, cursor)
            if (
                next_existing_index < len(instruction_starts)
                and instruction_starts[next_existing_index] < end_offset
            ):
                stop_reason = "overlaps_decoded_instruction"
                if len(overlap_samples) < 100:
                    overlap_samples.append(
                        {
                            "seedOffset": start,
                            "instructionOffset": cursor,
                            "instructionEndOffset": end_offset,
                            "existingInstructionOffset": instruction_starts[next_existing_index],
                        }
                    )
                break

            instructions.append(instruction)
            instruction_by_offset[cursor] = instruction
            bisect.insort(instruction_starts, cursor)
            added_instruction_count += 1
            added_byte_count += int(instruction["byteLength"])
            command_id = int(instruction["commandId"])

            if command_id == 0x0B:
                added_condition_count += 1
                condition = instruction["operands"][0]["value"]
                target = int(instruction["operands"][1]["value"])
                fallthrough = end_offset
                target_region = control_decoder.containing_region(entry_offsets, target, code_size)
                fallthrough_region = control_decoder.containing_region(entry_offsets, fallthrough, code_size)
                resolved = target_region is not None
                if resolved:
                    added_resolved_condition_count += 1
                    discovered_targets.add(target)
                else:
                    added_invalid_condition_count += 1
                source_node = f"fixed_{start:08x}"
                document["edges"].append(
                    {
                        "type": "condition_false",
                        "predicate": "value != 1",
                        "source": source_node,
                        "sourceOffset": cursor,
                        "condition": condition,
                        "target": control_decoder.offset_id(target) if resolved else None,
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
                        "source": source_node,
                        "sourceOffset": cursor,
                        "condition": condition,
                        "target": control_decoder.offset_id(fallthrough) if fallthrough_region else None,
                        "targetOffset": fallthrough,
                        "targetRegion": fallthrough_region,
                        "resolved": fallthrough_region is not None,
                        "commandId": 0x0B,
                    }
                )
                if condition.get("valid", False):
                    enqueue(target)
                    enqueue(fallthrough)
                else:
                    rejected_invalid_condition += 2
                stop_reason = "condition_branch"
                cursor = end_offset
                break

            if command_id in {0x14, 0x1C}:
                target = int(instruction["operands"][1]["value"])
                target_region = control_decoder.containing_region(entry_offsets, target, code_size)
                source_node = f"fixed_{start:08x}"
                document["edges"].append(
                    {
                        "type": "transfer" if command_id == 0x14 else "call_like",
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
                if command_id == 0x14:
                    stop_reason = "transfer"
                    cursor = end_offset
                    break

            if command_id == 0x18:
                target_index = literal_expression_value(instruction["operands"][0])
                resolved = target_index is not None and 0 <= target_index < len(entry_offsets)
                target = entry_offsets[target_index] if resolved else None
                document["edges"].append(
                    {
                        "type": "jump_table",
                        "source": f"fixed_{start:08x}",
                        "sourceOffset": cursor,
                        "target": f"entry_{target_index:04d}" if resolved else None,
                        "targetIndex": target_index,
                        "targetOffset": target,
                        "targetRegion": f"entry_{target_index:04d}" if resolved else None,
                        "resolved": resolved,
                        "commandId": command_id,
                    }
                )
                stop_reason = "jump_table"
                cursor = end_offset
                break

            if command_id == 0x1D:
                stop_reason = "script_transfer"
                cursor = end_offset
                break

            cursor = end_offset

        if instructions:
            node: dict[str, Any] = {
                "id": f"fixed_{start:08x}",
                "offset": start,
                "endOffset": limit,
                "instructions": instructions,
                "decodedEndOffset": cursor,
                "fullyDecoded": cursor == limit,
                "seedReason": "resolved_condition_target",
                "stopReason": stop_reason,
                "containingRegion": region_id(entry_offsets, start),
            }
            if cursor < limit and cursor not in instruction_by_offset:
                node["undecoded"] = {
                    "offset": cursor,
                    "size": limit - cursor,
                    "firstByte": code[cursor],
                    "rawHexPrefix": code[cursor : min(limit, cursor + 64)].hex(),
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
    document["decodedByteCount"] = int(document["decodedByteCount"]) + added_byte_count
    document["decodedRatio"] = document["decodedByteCount"] / code_size if code_size else 1.0
    flow = document["controlFlow"]
    flow["conditionBranchCount"] = int(flow["conditionBranchCount"]) + added_condition_count
    flow["resolvedConditionBranchCount"] = (
        int(flow["resolvedConditionBranchCount"]) + added_resolved_condition_count
    )
    flow["invalidConditionBranchCount"] = (
        int(flow["invalidConditionBranchCount"]) + added_invalid_condition_count
    )
    flow["branchTargetOffsets"] = sorted(
        set(int(value) for value in flow["branchTargetOffsets"]) | discovered_targets
    )
    flow["fixedPointSeedCount"] = len(processed)
    flow["fixedPointNodeCount"] = len(added_nodes)
    flow["fixedPointInstructionCount"] = added_instruction_count
    flow["fixedPointDecodedByteCount"] = added_byte_count
    flow["rejectedInteriorTargetCount"] = len(rejected_inside)
    flow["rejectedInvalidConditionEdgeCount"] = rejected_invalid_condition
    flow["fixedPointDecodeErrorCount"] = len(decode_error_samples)
    flow["fixedPointOverlapCount"] = len(overlap_samples)
    document["fixedPointDiagnostics"] = {
        "decodeErrorSamples": decode_error_samples,
        "overlapSamples": overlap_samples,
        "rejectedInteriorTargetOffsets": sorted(rejected_inside)[:1000],
    }
    document["diagnostics"].append(
        {
            "level": "info",
            "code": "condition_target_fixed_point",
            "message": (
                "Valid resolved condition targets were decoded to a fixed point; targets inside "
                "an existing instruction were retained as diagnostics rather than invented boundaries."
            ),
        }
    )


def decode_mes(data: bytes, source: dict[str, Any] | None = None) -> dict[str, Any]:
    document = control_decoder.decode_mes(data, source)
    add_fixed_point_paths(document, data)
    document["schema"] = "ai5_mes_fixed_point_control_ir/v1"
    return document


def main() -> None:
    parser = argparse.ArgumentParser(description="Decode MES condition targets to a control-flow fixed point.")
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
            f"{source['entry']}: nodes={document['nodeCount']} branches={flow['conditionBranchCount']} "
            f"fixedNodes={flow['fixedPointNodeCount']} interior={flow['rejectedInteriorTargetCount']} "
            f"decoded={document['decodedRatio']:.1%} output={output}"
        )
    else:
        print(encoded)


if __name__ == "__main__":
    main()
