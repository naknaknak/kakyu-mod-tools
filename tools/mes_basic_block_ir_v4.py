from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

import mes_basic_block_ir_v3
from mes_archive_ir import load_archive_entry


ROOT = Path(__file__).resolve().parents[1]


def classify_actionable_targets(document: dict[str, Any]) -> None:
    block_starts = {int(block["offset"]) for block in document["basicBlocks"]}
    spatial_missing = [int(value) for value in document["controlFlow"]["missingRequestedBlockTargets"]]
    actionable_targets: set[int] = set()
    invalid_candidate_targets: set[int] = set()
    invalid_candidate_edge_count = 0

    for edge in document["edges"]:
        target_value = edge.get("targetOffset")
        if not edge.get("resolved") or target_value is None:
            continue
        target = int(target_value)
        is_condition = str(edge.get("type", "")).startswith("condition_")
        if is_condition and not edge.get("condition", {}).get("valid", False):
            invalid_candidate_edge_count += 1
            if target not in block_starts:
                invalid_candidate_targets.add(target)
            continue
        actionable_targets.add(target)

    actionable_missing = sorted(target for target in actionable_targets if target not in block_starts)
    unresolved_actionable_edges = 0
    ignored_invalid_edges = 0
    for edge in document["blockEdges"]:
        if edge.get("resolved"):
            continue
        is_condition = str(edge.get("type", "")).startswith("condition_")
        if is_condition and not edge.get("condition", {}).get("valid", False):
            ignored_invalid_edges += 1
        else:
            unresolved_actionable_edges += 1

    flow = document["controlFlow"]
    flow["spatialMissingRequestedBlockTargets"] = spatial_missing
    flow["missingRequestedBlockTargets"] = actionable_missing
    flow["actionableBlockTargetCount"] = len(actionable_targets)
    flow["missingActionableBlockTargetCount"] = len(actionable_missing)
    flow["invalidConditionCandidateEdgeCount"] = invalid_candidate_edge_count
    flow["ignoredInvalidConditionBlockEdgeCount"] = ignored_invalid_edges
    flow["invalidConditionCandidateMissingTargets"] = sorted(invalid_candidate_targets)
    flow["unresolvedActionableBlockEdgeCount"] = unresolved_actionable_edges
    document["diagnostics"].append(
        {
            "level": "info",
            "code": "actionable_target_classification",
            "message": (
                "Targets from invalid retained expression candidates are audited separately and are not "
                "reported as missing executable basic blocks."
            ),
        }
    )


def decode_mes(data: bytes, source: dict[str, Any] | None = None) -> dict[str, Any]:
    document = mes_basic_block_ir_v3.decode_mes(data, source)
    classify_actionable_targets(document)
    document["schema"] = "ai5_mes_basic_block_ir/v4"
    return document


def main() -> None:
    parser = argparse.ArgumentParser(description="Emit production MES basic-block IR with actionable targets.")
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
            f"missingActionable={flow['missingActionableBlockTargetCount']} "
            f"invalidCandidates={flow['ignoredInvalidConditionBlockEdgeCount']} "
            f"decoded={document['decodedRatio']:.1%} output={output}"
        )
    else:
        print(encoded)


if __name__ == "__main__":
    main()
