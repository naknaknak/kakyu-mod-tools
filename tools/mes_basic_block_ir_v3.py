from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

import mes_basic_block_ir
import mes_overlapping_control_ir
from mes_archive_ir import load_archive_entry


ROOT = Path(__file__).resolve().parents[1]
TERMINATORS = {0x0B, 0x14, 0x18, 0x1D}


def repair_path_fallthrough_edges(document: dict[str, Any]) -> None:
    blocks = document["basicBlocks"]
    block_by_start = {int(block["offset"]): block for block in blocks}
    existing = {(edge.get("source"), edge.get("target"), edge.get("type")) for edge in document["blockEdges"]}
    added = 0
    for block in blocks:
        if int(block["terminalCommandId"]) in TERMINATORS:
            continue
        target = block_by_start.get(int(block["endOffset"]))
        if target is None:
            continue
        key = (block["id"], target["id"], "fallthrough")
        if key in existing:
            continue
        document["blockEdges"].append(
            {
                "type": "fallthrough",
                "source": block["id"],
                "sourceOffset": block["instructionOffsets"][-1],
                "target": target["id"],
                "targetOffset": target["offset"],
                "resolved": True,
            }
        )
        existing.add(key)
        added += 1
    document["blockEdges"].sort(
        key=lambda edge: (int(edge.get("sourceOffset", -1)), str(edge.get("type", "")), int(edge.get("targetOffset", -1)))
    )
    document["controlFlow"]["overlapAwareFallthroughEdgeCount"] = added
    document["controlFlow"]["blockEdgeCount"] = len(document["blockEdges"])


def decode_mes(data: bytes, source: dict[str, Any] | None = None) -> dict[str, Any]:
    document = mes_overlapping_control_ir.decode_mes(data, source)
    mes_basic_block_ir.build_basic_blocks(document)
    repair_path_fallthrough_edges(document)
    document["schema"] = "ai5_mes_basic_block_ir/v3"
    document["controlFlow"]["basicBlockTerminatorCommandIds"] = sorted(TERMINATORS)
    document["diagnostics"].append(
        {
            "level": "info",
            "code": "overlap_aware_basic_blocks",
            "message": "Fallthrough edges are matched by end offset so overlapping instruction paths remain independent.",
        }
    )
    return document


def main() -> None:
    parser = argparse.ArgumentParser(description="Convert overlapping MES paths to Godot-friendly basic-block IR v3.")
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
            f"{source['entry']}: blocks={flow['basicBlockCount']} blockEdges={flow['blockEdgeCount']} "
            f"missingTargets={len(flow['missingRequestedBlockTargets'])} overlaps={flow['overlappingPathTargetCount']} "
            f"decoded={document['decodedRatio']:.1%} output={output}"
        )
    else:
        print(encoded)


if __name__ == "__main__":
    main()
