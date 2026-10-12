from __future__ import annotations

import argparse
import hashlib
import json
import struct
from pathlib import Path
from typing import Any, Iterable

from extract_kakyu_arc import read_entries
from mes_archive_ir import load_archive_entry
from mes_basic_block_ir_v6 import decode_mes


ROOT = Path(__file__).resolve().parents[1]
# The normal-conversation menu label (6 characters) is recognised by the length and SHA-256
# of its CP932 bytes rather than stored (WD-25 item 1b, D3): an original text of this
# size does not belong in a tracked file, and the match needs only the digest.
NORMAL_TALK_LABEL_CP932_LENGTH = 12
NORMAL_TALK_LABEL_CP932_SHA256 = "3b59c8d23f7b9df85db84614e82d4aebdaafd92b9feea34fa08e6ff2b245d36d"


def is_normal_talk_label(text: str | None) -> bool:
    """True when ``text`` is the normal-conversation menu label (a character CP932 cannot
    encode is no match)."""
    if text is None:
        return False
    try:
        encoded = text.encode("cp932")
    except UnicodeEncodeError:
        return False
    return (
        len(encoded) == NORMAL_TALK_LABEL_CP932_LENGTH
        and hashlib.sha256(encoded).hexdigest() == NORMAL_TALK_LABEL_CP932_SHA256
    )


def iter_instructions(document: dict[str, Any]) -> Iterable[dict[str, Any]]:
    for node in document["nodes"]:
        yield from node["instructions"]


def text_value(instruction: dict[str, Any]) -> str | None:
    if instruction.get("op") != "text":
        return None
    operands = instruction.get("operands", [])
    if not operands:
        return None
    return str(operands[0].get("value", ""))


def condition_ast(instruction: dict[str, Any]) -> dict[str, Any] | None:
    if instruction.get("op") != "branch_if_not_true":
        return None
    operands = instruction.get("operands", [])
    if len(operands) < 2:
        return None
    return operands[0].get("value", {}).get("ast")


def branch_target(instruction: dict[str, Any]) -> int | None:
    operands = instruction.get("operands", [])
    if len(operands) < 2:
        return None
    value = operands[1].get("value")
    return int(value) if value is not None else None


def is_selection_one(ast: dict[str, Any] | None) -> bool:
    if not ast or ast.get("type") != "binary" or ast.get("op") != "equal":
        return False
    lhs = ast.get("lhs", {})
    rhs = ast.get("rhs", {})
    return (
        lhs.get("type") == "state_ref"
        and lhs.get("storage") == "state_u16"
        and lhs.get("index", {}).get("value") == 21
        and rhs.get("type") == "literal"
        and rhs.get("value") == 1
    )


def literal_value(ast: dict[str, Any]) -> int | None:
    if ast.get("type") != "literal":
        return None
    return int(ast["value"])


def banked_u16_ref(ast: dict[str, Any]) -> tuple[int, int] | None:
    if ast.get("type") != "state_ref" or ast.get("storage") != "banked_u16":
        return None
    index = literal_value(ast.get("index", {}))
    if index is None:
        return None
    return int(ast.get("bank", 0)), index


def affection_delta(instruction: dict[str, Any]) -> dict[str, int] | None:
    if instruction.get("op") != "banked_u16_write_run":
        return None
    operands = instruction.get("operands", [])
    if len(operands) != 3:
        return None
    destination = literal_value(operands[0].get("value", {}).get("ast", {}))
    destination_bank = int(operands[1].get("value", -1))
    pairs = operands[2].get("pairs", [])
    if len(pairs) != 1:
        return None
    source = pairs[0].get("expression", {}).get("ast", {})
    if destination is None or source.get("type") != "binary" or source.get("op") not in {"add", "subtract"}:
        return None
    reference = banked_u16_ref(source.get("lhs", {}))
    magnitude = literal_value(source.get("rhs", {}))
    if reference is None or reference != (destination_bank, destination) or magnitude is None:
        return None
    delta = magnitude if source["op"] == "add" else -magnitude
    return {"bank": destination_bank, "index": destination, "delta": delta}


def global_u8_writes(instruction: dict[str, Any]) -> list[dict[str, Any]]:
    if instruction.get("op") == "global_u8_write_run":
        operands = instruction.get("operands", [])
        if len(operands) != 2:
            return []
        start_index = int(operands[0].get("value", -1))
        pairs = operands[1].get("pairs", [])
        return [
            {"index": start_index + pair_index, "value": pair.get("expression", {}).get("ast")}
            for pair_index, pair in enumerate(pairs)
        ]
    if instruction.get("op") != "command_03":
        return []
    operands = instruction.get("operands", [])
    if len(operands) < 3 or operands[0].get("type") != "u8" or operands[1].get("type") != "u8":
        return []
    index = int(operands[0]["value"]) | (int(operands[1]["value"]) << 8)
    value_ast = operands[2].get("value", {}).get("ast")
    return [{"index": index, "value": value_ast}]


def continuation_target(instruction: dict[str, Any]) -> int | None:
    if instruction.get("op") != "command_0c":
        return None
    raw = bytes.fromhex(str(instruction.get("rawHex", "")))
    if len(raw) != 5:
        return None
    return struct.unpack_from("<I", raw, 1)[0]


def false_spine_summary(
    instructions: list[dict[str, Any]], normal_start: int, normal_end: int
) -> tuple[list[dict[str, Any]], dict[str, int] | None]:
    by_offset = {int(item["sourceOffset"]): item for item in instructions}
    spine: list[dict[str, Any]] = []
    visited: set[int] = set()
    cursor = normal_start
    terminal_transfer: dict[str, int] | None = None

    while normal_start <= cursor < normal_end and cursor not in visited:
        visited.add(cursor)
        instruction = by_offset.get(cursor)
        if instruction is None:
            break
        if instruction.get("op") == "command_0c":
            target = continuation_target(instruction)
            if target is not None:
                terminal_transfer = {"sourceOffset": cursor, "targetOffset": target}
            break
        if instruction.get("op") != "branch_if_not_true":
            cursor = int(instruction["endOffset"])
            continue

        true_start = int(instruction["endOffset"])
        false_target = branch_target(instruction)
        if false_target is None:
            break
        body_writes: list[dict[str, Any]] = []
        body_deltas: list[dict[str, int]] = []
        body_transfers: list[dict[str, int]] = []
        for body_instruction in instructions:
            offset = int(body_instruction["sourceOffset"])
            if not true_start <= offset < false_target:
                continue
            for write in global_u8_writes(body_instruction):
                body_writes.append({"sourceOffset": offset, **write})
            delta = affection_delta(body_instruction)
            if delta is not None:
                body_deltas.append({"sourceOffset": offset, **delta})
            target = continuation_target(body_instruction)
            if target is not None:
                body_transfers.append({"sourceOffset": offset, "targetOffset": target})
        spine.append(
            {
                "sourceOffset": int(instruction["sourceOffset"]),
                "trueStartOffset": true_start,
                "falseTargetOffset": false_target,
                "condition": condition_ast(instruction),
                "linearBodySummary": {
                    "globalU8Writes": body_writes,
                    "affectionDeltaSites": body_deltas,
                    "continuationTransfers": body_transfers,
                },
            }
        )
        cursor = false_target

    return spine, terminal_transfer


def summarize_entry(archive: Path, entry_name: str) -> dict[str, Any] | None:
    data, source = load_archive_entry(archive, entry_name)
    document = decode_mes(data, source)
    instructions = sorted(iter_instructions(document), key=lambda item: int(item["sourceOffset"]))
    labels = [item for item in instructions if is_normal_talk_label(text_value(item))]
    if not labels:
        return None
    label = labels[0]
    label_offset = int(label["sourceOffset"])

    prior = [item for item in instructions if int(item["sourceOffset"]) < label_offset]
    menu_insert = next((item for item in reversed(prior) if item.get("op") == "command_10"), None)
    guard = next((item for item in reversed(prior) if item.get("op") == "branch_if_not_true"), None)

    dispatch = next(
        (
            item
            for item in instructions
            if int(item["sourceOffset"]) > label_offset and is_selection_one(condition_ast(item))
        ),
        None,
    )
    normal_start = int(dispatch["endOffset"]) if dispatch else None
    normal_end = branch_target(dispatch) if dispatch else None

    delta_sites: list[dict[str, int]] = []
    if normal_start is not None and normal_end is not None:
        for item in instructions:
            offset = int(item["sourceOffset"])
            if not normal_start <= offset < normal_end:
                continue
            delta = affection_delta(item)
            if delta:
                delta_sites.append({"sourceOffset": offset, **delta})

    leading_branches: list[dict[str, Any]] = []
    if normal_start is not None and normal_end is not None:
        for item in instructions:
            offset = int(item["sourceOffset"])
            if offset < normal_start or offset >= min(normal_end, normal_start + 5000):
                continue
            ast = condition_ast(item)
            if ast is None:
                continue
            leading_branches.append(
                {
                    "sourceOffset": offset,
                    "falseTarget": branch_target(item),
                    "condition": ast,
                }
            )
            if len(leading_branches) == 12:
                break

    false_spine: list[dict[str, Any]] = []
    terminal_transfer: dict[str, int] | None = None
    if normal_start is not None and normal_end is not None:
        false_spine, terminal_transfer = false_spine_summary(instructions, normal_start, normal_end)

    return {
        "entry": source["entry"],
        "size": source["size"],
        "sha256": source["sha256"],
        "decodedRatio": document["decodedRatio"],
        "normalTalkLabelOffset": label_offset,
        "menuInsertOffset": None if menu_insert is None else int(menu_insert["sourceOffset"]),
        "menuGuardOffset": None if guard is None else int(guard["sourceOffset"]),
        "menuGuardCondition": None if guard is None else condition_ast(guard),
        "selectionDispatchOffset": None if dispatch is None else int(dispatch["sourceOffset"]),
        "normalTalkStartOffset": normal_start,
        "normalTalkEndOffset": normal_end,
        "affectionDeltaSites": delta_sites,
        "leadingBranches": leading_branches,
        "normalTalkFalseSpine": false_spine,
        "normalTalkTerminalTransfer": terminal_transfer,
    }


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Inspect the common normal-conversation entry point without exporting dialogue text."
    )
    parser.add_argument("archive", type=Path)
    parser.add_argument("-o", "--output", type=Path)
    parser.add_argument("--entry", action="append", default=[])
    args = parser.parse_args()

    archive = args.archive if args.archive.is_absolute() else ROOT / args.archive
    wanted = {value.casefold() for value in args.entry}
    names = [
        name
        for name, _offset, _size in read_entries(archive)
        if (not wanted or name.casefold() in wanted) and "_talk" in name.casefold()
    ]
    entries = [summary for name in names if (summary := summarize_entry(archive, name)) is not None]
    document = {
        "schema": "kakyu_normal_talk_analysis/v1",
        "source": {"archiveName": archive.name},
        "entryCount": len(entries),
        "entries": entries,
    }
    encoded = json.dumps(document, ensure_ascii=False, indent=2) + "\n"
    if args.output:
        output = args.output if args.output.is_absolute() else ROOT / args.output
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(encoded, encoding="utf-8")
        print(f"entries={len(entries)} output={output}")
    else:
        print(encoded, end="")


if __name__ == "__main__":
    main()
