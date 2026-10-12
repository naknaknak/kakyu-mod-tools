from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

import mes_iterative_ir as iterative_decoder
import mes_partial_decoder as base_decoder
import mes_structured_ir as structured_decoder
from mes_archive_ir import load_archive_entry


ROOT = Path(__file__).resolve().parents[1]
ITERATIVE_DECODE_INSTRUCTION = iterative_decoder.decode_instruction


def decode_fields(
    code: bytes, offset: int, limit: int, command_id: int, grammar: str
) -> dict[str, Any]:
    cursor = offset + 1
    operands: list[dict[str, Any]] = []
    for field in grammar:
        if field == "e":
            expression, cursor = base_decoder.decode_expression(code, cursor, limit)
            operands.append({"type": "expression", "value": expression})
        else:
            if cursor >= limit:
                raise base_decoder.MesDecodeError(f"truncated u8 at 0x{cursor:x}")
            operands.append({"type": "u8", "value": code[cursor], "sourceOffset": cursor})
            cursor += 1
    return base_decoder.finish_instruction(
        code, offset, cursor, f"command_{command_id:02x}", command_id, operands
    )


def decode_instruction(code: bytes, offset: int, limit: int) -> dict[str, Any] | None:
    if offset >= limit:
        return None
    command_id = code[offset]
    if command_id == 0x09:
        mmo_marker = structured_decoder.decode_confirmed_mmo_marker(code, offset, limit)
        if mmo_marker is not None:
            return mmo_marker
    # Direct disassembly plus aligned corpus instances show that the later calls
    # previously attributed to these commands belong to following commands.
    if command_id == 0x09:
        return decode_fields(code, offset, limit, command_id, "bbeb")
    if command_id == 0x0B:
        return decode_fields(code, offset, limit, command_id, "ebbbb")
    return ITERATIVE_DECODE_INSTRUCTION(code, offset, limit)


def decode_mes(data: bytes, source: dict[str, Any] | None = None) -> dict[str, Any]:
    previous = base_decoder.decode_instruction
    base_decoder.decode_instruction = decode_instruction
    try:
        document = base_decoder.decode_mes(data, source)
    finally:
        base_decoder.decode_instruction = previous
    document["schema"] = "ai5_mes_partial_ir/v5"
    document["diagnostics"].append(
        {
            "level": "info",
            "code": "aligned_fixed_grammars",
            "message": "Commands 0x09 and 0x0b use corpus-aligned fixed operand shapes.",
        }
    )
    return document


def main() -> None:
    parser = argparse.ArgumentParser(description="Decode MES with corrected fixed and iterative operand shapes.")
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
            f"decoded={document['decodedRatio']:.1%} output={output}"
        )
    else:
        print(encoded)


if __name__ == "__main__":
    main()
