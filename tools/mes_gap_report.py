from __future__ import annotations

import argparse
import bisect
from collections import Counter
from pathlib import Path
from typing import Any

from mes_archive_ir import load_archive_entry, parse_mes_container
from mes_basic_block_ir_v6 import decode_mes


ROOT = Path(__file__).resolve().parents[1]


def decoded_ranges(document: dict[str, Any]) -> list[tuple[int, int]]:
    ranges = sorted(
        (int(instruction["sourceOffset"]), int(instruction["endOffset"]))
        for node in document["nodes"]
        for instruction in node["instructions"]
    )
    merged: list[tuple[int, int]] = []
    for start, end in ranges:
        if not merged or start > merged[-1][1]:
            merged.append((start, end))
            continue
        if end > merged[-1][1]:
            merged[-1] = (merged[-1][0], end)
    return merged


def complement(ranges: list[tuple[int, int]], size: int) -> list[tuple[int, int]]:
    gaps: list[tuple[int, int]] = []
    cursor = 0
    for start, end in ranges:
        if cursor < start:
            gaps.append((cursor, start))
        cursor = max(cursor, end)
    if cursor < size:
        gaps.append((cursor, size))
    return gaps


def main() -> None:
    parser = argparse.ArgumentParser(description="Report byte ranges not covered by the MES basic-block decoder.")
    parser.add_argument("archive", type=Path)
    parser.add_argument("entry")
    parser.add_argument("--prefix-bytes", type=int, default=16)
    parser.add_argument("--context-instructions", type=int, default=0)
    args = parser.parse_args()

    archive = args.archive if args.archive.is_absolute() else ROOT / args.archive
    data, source = load_archive_entry(archive, args.entry)
    container = parse_mes_container(data, source)
    if not container["header"]["entryOffsets"]:
        parser.error(
            f"{source['entry']} has no address table; use its format-specific scanner instead"
        )
    code_offset = int(container["header"]["codeOffset"])
    code = data[code_offset:]
    document = decode_mes(data, source)
    ranges = decoded_ranges(document)
    gaps = complement(ranges, len(code))
    instructions = sorted(
        (
            int(instruction["sourceOffset"]),
            int(instruction["endOffset"]),
            str(instruction["op"]),
            int(instruction["commandId"]),
            str(instruction["rawHex"]),
        )
        for node in document["nodes"]
        for instruction in node["instructions"]
    )
    starts = [item[0] for item in instructions]
    entry_offsets = [int(value) for value in container["header"]["entryOffsets"]]

    first_bytes = Counter(code[start] for start, end in gaps if start < end)
    dispatcher_bytes = Counter(
        command_id
        for _start, _end, op, command_id, _raw in instructions
        if op in {"dispatcher_default_byte", "dispatcher_character_text"}
    )
    character_lead_count = sum(
        1 for _start, _end, op, _command_id, _raw in instructions if op == "dispatcher_character_text"
    )
    decode_error_count = sum(1 for node in document["nodes"] if node.get("decodeError"))
    total = sum(end - start for start, end in gaps)
    print(
        f"{source['entry']}: decoded={document['decodedRatio']:.6%} "
        f"gaps={len(gaps)} gapBytes={total} codeSize={len(code)}"
    )
    print(
        "gapFirstBytes="
        + ", ".join(f"0x{value:02x}:{count}" for value, count in sorted(first_bytes.items()))
    )
    print(
        f"dispatcherBytes={sum(dispatcher_bytes.values())} characterLeads={character_lead_count} "
        f"decodeErrors={decode_error_count} values="
        + ", ".join(f"0x{value:02x}:{count}" for value, count in sorted(dispatcher_bytes.items()))
    )
    for start, end, op, command_id, _raw in instructions:
        if op not in {"dispatcher_default_byte", "dispatcher_character_text"}:
            continue
        print(f"dispatcherByte 0x{start:04x}..0x{end:04x} value=0x{command_id:02x} route={op}")
    for index, (start, end) in enumerate(gaps):
        prefix_end = min(end, start + max(args.prefix_bytes, 0))
        insertion = bisect.bisect_left(starts, start)
        previous = instructions[insertion - 1] if insertion else None
        next_instruction = instructions[bisect.bisect_left(starts, end)] if bisect.bisect_left(starts, end) < len(instructions) else None
        entry_index = bisect.bisect_right(entry_offsets, start) - 1
        region = "bootstrap" if entry_index < 0 else f"entry_{entry_index:04d}"
        previous_text = "none" if previous is None else f"{previous[2]}@0x{previous[0]:04x}..0x{previous[1]:04x}"
        next_text = (
            "none"
            if next_instruction is None
            else f"{next_instruction[2]}@0x{next_instruction[0]:04x}..0x{next_instruction[1]:04x}"
        )
        print(
            f"gap[{index:03d}] 0x{start:04x}..0x{end:04x} "
            f"size={end - start} region={region} prefix={code[start:prefix_end].hex()} "
            f"previous={previous_text} next={next_text}"
        )
        context_start = max(0, insertion - max(args.context_instructions, 0))
        context_end = min(len(instructions), bisect.bisect_left(starts, end) + max(args.context_instructions, 0))
        for item in instructions[context_start:context_end]:
            if item[1] <= start or item[0] >= end:
                print(
                    f"  instruction 0x{item[0]:04x}..0x{item[1]:04x} "
                    f"cmd=0x{item[3]:02x} op={item[2]} raw={item[4][:64]}"
                )


if __name__ == "__main__":
    main()
