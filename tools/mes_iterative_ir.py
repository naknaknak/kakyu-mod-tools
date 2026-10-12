from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

import mes_partial_decoder as base_decoder
import mes_structured_ir as structured_decoder
from mes_archive_ir import load_archive_entry


ROOT = Path(__file__).resolve().parents[1]
STRUCTURED_DECODE_INSTRUCTION = structured_decoder.decode_instruction


def decode_instruction(code: bytes, offset: int, limit: int) -> dict[str, Any] | None:
    if offset >= limit or code[offset] != 0x07:
        return STRUCTURED_DECODE_INSTRUCTION(code, offset, limit)

    cursor = offset + 1
    operands: list[dict[str, Any]] = []
    while True:
        expression, cursor = base_decoder.decode_expression(code, cursor, limit)
        if cursor >= limit:
            raise base_decoder.MesDecodeError(f"truncated command 0x07 continuation at 0x{cursor:x}")
        continuation = code[cursor]
        cursor += 1
        operands.append(
            {
                "type": "expression_byte_pair",
                "expression": expression,
                "continuation": continuation,
            }
        )
        # The first pair selects the base; the native do/while body always reads
        # at least one additional pair and repeats that body while this byte is non-zero.
        if len(operands) >= 2 and continuation == 0:
            break
    return base_decoder.finish_instruction(code, offset, cursor, "command_07", 0x07, operands)


def decode_mes(data: bytes, source: dict[str, Any] | None = None) -> dict[str, Any]:
    previous = base_decoder.decode_instruction
    base_decoder.decode_instruction = decode_instruction
    try:
        document = base_decoder.decode_mes(data, source)
    finally:
        base_decoder.decode_instruction = previous
    document["schema"] = "ai5_mes_partial_ir/v4"
    document["diagnostics"].append(
        {
            "level": "info",
            "code": "command_07_iterative_shape",
            "message": "Command 0x07 is decoded as a native do/while sequence of expression-byte pairs.",
        }
    )
    return document


def main() -> None:
    parser = argparse.ArgumentParser(description="Decode MES with confirmed structured and iterative operand shapes.")
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
