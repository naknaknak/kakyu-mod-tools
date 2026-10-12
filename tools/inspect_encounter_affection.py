from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any, Iterable

from extract_kakyu_arc import read_entries
from inspect_normal_talk import affection_delta, condition_ast, iter_instructions
from mes_archive_ir import load_archive_entry
from mes_basic_block_ir_v6 import decode_mes


def branch_target(instruction: dict[str, Any]) -> int | None:
    operands = instruction.get("operands", [])
    if len(operands) < 2:
        return None
    value = operands[1].get("value")
    return int(value) if value is not None else None


def containing_conditions(
    branches: Iterable[dict[str, Any]], offset: int
) -> list[dict[str, Any]]:
    result: list[dict[str, Any]] = []
    for branch in branches:
        source = int(branch["sourceOffset"])
        target = branch_target(branch)
        ast = condition_ast(branch)
        if ast is None or target is None or target <= source:
            continue
        if source < offset < target:
            result.append(
                {
                    "sourceOffset": source,
                    "falseTargetOffset": target,
                    "condition": ast,
                }
            )
    result.sort(key=lambda row: int(row["sourceOffset"]), reverse=True)
    return result


def inspect_entry(arc_path: Path, entry_name: str) -> dict[str, Any]:
    raw, source = load_archive_entry(arc_path, entry_name)
    document = decode_mes(raw, source)
    instructions = sorted(iter_instructions(document), key=lambda item: int(item["sourceOffset"]))
    branches = [item for item in instructions if condition_ast(item) is not None]
    deltas: list[dict[str, Any]] = []
    for instruction in instructions:
        delta = affection_delta(instruction)
        if delta is None:
            continue
        offset = int(instruction["sourceOffset"])
        deltas.append(
            {
                "sourceOffset": offset,
                **delta,
                "containingConditions": containing_conditions(branches, offset),
            }
        )
    return {
        "entry": entry_name,
        "size": int(source["size"]),
        "sha256": source["sha256"],
        "decodedRatio": document["decodedRatio"],
        "affectionDeltaSites": deltas,
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Inspect direct affection-delta assignments in A-L encounter INTRO/OUTRO scripts."
    )
    parser.add_argument("arc", type=Path, help="Path to the authoritative mes.arc")
    parser.add_argument("-o", "--output", type=Path, help="Optional compact JSON output path")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    available = {name.casefold(): name for name, _, _ in read_entries(args.arc)}
    wanted = [f"{prefix}_{phase}.MES" for prefix in "ABCDEFGHIJKL" for phase in ("INTRO", "OUTRO")]
    missing = [name for name in wanted if name.casefold() not in available]
    if missing:
        raise SystemExit(f"missing archive entries: {', '.join(missing)}")

    entries = [inspect_entry(args.arc, available[name.casefold()]) for name in wanted]
    output = {
        "schema": "kakyu_encounter_affection_audit/v1",
        "source": str(args.arc),
        "entryCount": len(entries),
        "entries": entries,
    }
    encoded = json.dumps(output, ensure_ascii=False, indent=2) + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(encoded, encoding="utf-8")
        print(f"entries={len(entries)} output={args.output.resolve()}")
    else:
        print(encoded, end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
