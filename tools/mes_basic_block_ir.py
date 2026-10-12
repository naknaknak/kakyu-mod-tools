from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

import mes_control_flow_ir as control_decoder
from mes_archive_ir import load_archive_entry


ROOT = Path(__file__).resolve().parents[1]
BLOCK_TERMINATORS = {0x0B, 0x14, 0x18}


def block_id(offset: int) -> str:
    return f"block_{offset:08x}"


def build_basic_blocks(document: dict[str, Any]) -> None:
    instructions: dict[int, dict[str, Any]] = {}
    instruction_regions: dict[int, str] = {}
    region_starts: set[int] = set()
    for node in document["nodes"]:
        node_instructions = node["instructions"]
        if node_instructions:
            region_starts.add(int(node_instructions[0]["sourceOffset"]))
        for instruction in node_instructions:
            offset = int(instruction["sourceOffset"])
            if offset in instructions:
                raise ValueError(f"duplicate decoded instruction at 0x{offset:x}")
            instructions[offset] = instruction
            instruction_regions[offset] = str(node["id"])

    boundaries = set(region_starts)
    requested_targets: set[int] = set()
    for edge in document["edges"]:
        if not edge.get("resolved"):
            continue
        target_offset = edge.get("targetOffset")
        if target_offset is None:
            continue
        target = int(target_offset)
        requested_targets.add(target)
        if target in instructions:
            boundaries.add(target)

    for instruction in instructions.values():
        command_id = int(instruction["commandId"])
        if command_id in BLOCK_TERMINATORS:
            successor = int(instruction["endOffset"])
            if successor in instructions:
                boundaries.add(successor)

    blocks: list[dict[str, Any]] = []
    instruction_to_block: dict[int, str] = {}
    current_offsets: list[int] = []
    current_region: str | None = None

    def finish_block() -> None:
        nonlocal current_offsets, current_region
        if not current_offsets:
            return
        start = current_offsets[0]
        last = instructions[current_offsets[-1]]
        identifier = block_id(start)
        block = {
            "id": identifier,
            "offset": start,
            "endOffset": int(last["endOffset"]),
            "byteLength": int(last["endOffset"]) - start,
            "instructionOffsets": current_offsets,
            "instructionCount": len(current_offsets),
            "sourceRegion": current_region,
            "terminalCommandId": int(last["commandId"]),
        }
        blocks.append(block)
        for instruction_offset in current_offsets:
            instruction_to_block[instruction_offset] = identifier
        current_offsets = []
        current_region = None

    previous_end: int | None = None
    for offset in sorted(instructions):
        instruction = instructions[offset]
        region = instruction_regions[offset]
        starts_new = bool(current_offsets) and (
            offset in boundaries or offset != previous_end or region != current_region
        )
        if starts_new:
            finish_block()
        if not current_offsets:
            current_region = region
        current_offsets.append(offset)
        previous_end = int(instruction["endOffset"])
        if int(instruction["commandId"]) in BLOCK_TERMINATORS:
            finish_block()
            previous_end = None
    finish_block()

    block_by_start = {int(block["offset"]): block for block in blocks}
    block_edges: list[dict[str, Any]] = []
    resolved_edge_count = 0
    unresolved_edge_count = 0
    for edge in document["edges"]:
        converted = dict(edge)
        source_offset = int(edge.get("sourceOffset", -1))
        converted["sourceRegion"] = edge.get("source")
        converted["source"] = instruction_to_block.get(source_offset)
        target_offset_value = edge.get("targetOffset")
        target_block = None
        if target_offset_value is not None:
            target_block_value = block_by_start.get(int(target_offset_value))
            if target_block_value is not None:
                target_block = target_block_value["id"]
        converted["targetRegion"] = edge.get("targetRegion", edge.get("target"))
        converted["target"] = target_block
        converted["resolved"] = converted["source"] is not None and target_block is not None
        if converted["resolved"]:
            resolved_edge_count += 1
        else:
            unresolved_edge_count += 1
            converted["resolutionReason"] = (
                "source_not_decoded" if converted["source"] is None else "target_not_decoded_block_start"
            )
        block_edges.append(converted)

    existing_pairs = {
        (edge.get("source"), edge.get("target"), edge.get("type")) for edge in block_edges
    }
    for index, block in enumerate(blocks[:-1]):
        next_block = blocks[index + 1]
        if int(block["endOffset"]) != int(next_block["offset"]):
            continue
        if int(block["terminalCommandId"]) in BLOCK_TERMINATORS:
            continue
        key = (block["id"], next_block["id"], "fallthrough")
        if key in existing_pairs:
            continue
        block_edges.append(
            {
                "type": "fallthrough",
                "source": block["id"],
                "sourceOffset": block["instructionOffsets"][-1],
                "target": next_block["id"],
                "targetOffset": next_block["offset"],
                "resolved": True,
            }
        )
        existing_pairs.add(key)

    missing_requested_targets = sorted(target for target in requested_targets if target not in block_by_start)
    block_edges.sort(
        key=lambda edge: (
            int(edge.get("sourceOffset", -1)),
            str(edge.get("type", "")),
            int(edge.get("targetOffset", -1)),
        )
    )
    document["basicBlocks"] = blocks
    document["blockEdges"] = block_edges
    document["controlFlow"].update(
        {
            "basicBlockCount": len(blocks),
            "blockEdgeCount": len(block_edges),
            "resolvedBlockEdgeCount": resolved_edge_count,
            "unresolvedBlockEdgeCount": unresolved_edge_count,
            "requestedBlockTargetCount": len(requested_targets),
            "missingRequestedBlockTargets": missing_requested_targets,
            "blockIdFormat": "block_%08x",
        }
    )


def decode_mes(data: bytes, source: dict[str, Any] | None = None) -> dict[str, Any]:
    document = control_decoder.decode_mes(data, source)
    build_basic_blocks(document)
    document["schema"] = "ai5_mes_basic_block_ir/v1"
    document["diagnostics"].append(
        {
            "level": "info",
            "code": "basic_blocks",
            "message": "Entry starts, resolved branch targets and conditional fallthroughs are basic-block boundaries.",
        }
    )
    return document


def main() -> None:
    parser = argparse.ArgumentParser(description="Convert MES control flow into Godot-friendly basic blocks.")
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
            f"{source['entry']}: blocks={document['controlFlow']['basicBlockCount']} "
            f"blockEdges={document['controlFlow']['blockEdgeCount']} "
            f"missingTargets={len(document['controlFlow']['missingRequestedBlockTargets'])} "
            f"decoded={document['decodedRatio']:.1%} output={output}"
        )
    else:
        print(encoded)


if __name__ == "__main__":
    main()
