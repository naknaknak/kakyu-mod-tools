from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

import mes_aligned_ir as aligned_decoder
import mes_partial_decoder as base_decoder
import mes_tolerant_ir as tolerant_decoder
from mes_archive_ir import load_archive_entry


ROOT = Path(__file__).resolve().parents[1]
ALIGNED_DECODE_INSTRUCTION = aligned_decoder.decode_instruction


def read_continuation(code: bytes, cursor: int, limit: int, command_id: int) -> tuple[int, int]:
    if cursor >= limit:
        raise base_decoder.MesDecodeError(
            f"truncated command 0x{command_id:02x} continuation at 0x{cursor:x}"
        )
    return code[cursor], cursor + 1


def expression_pair(code: bytes, cursor: int, limit: int, command_id: int) -> tuple[dict[str, Any], int]:
    expression, cursor = tolerant_decoder.decode_expression(code, cursor, limit)
    continuation, cursor = read_continuation(code, cursor, limit, command_id)
    return {
        "type": "expression_byte_pair",
        "expression": expression,
        "continuation": continuation,
    }, cursor


def decode_instruction(code: bytes, offset: int, limit: int) -> dict[str, Any] | None:
    if offset >= limit:
        return None
    command_id = code[offset]
    cursor = offset + 1

    if command_id == 0x05:
        first, cursor = tolerant_decoder.decode_expression(code, cursor, limit)
        second_pair, cursor = expression_pair(code, cursor, limit, command_id)
        operands: list[dict[str, Any]] = [
            {"type": "expression", "value": first},
            second_pair,
        ]
        while second_pair["continuation"] != 0:
            second_pair, cursor = expression_pair(code, cursor, limit, command_id)
            operands.append(second_pair)
        return base_decoder.finish_instruction(code, offset, cursor, "command_05", command_id, operands)

    if command_id == 0x16:
        if cursor >= limit:
            raise base_decoder.MesDecodeError(f"truncated command 0x16 selector at 0x{cursor:x}")
        selector = code[cursor]
        cursor += 1
        pair, cursor = expression_pair(code, cursor, limit, command_id)
        operands = [{"type": "u8", "value": selector, "sourceOffset": offset + 1}, pair]
        while pair["continuation"] != 0:
            pair, cursor = expression_pair(code, cursor, limit, command_id)
            operands.append(pair)
        return base_decoder.finish_instruction(code, offset, cursor, "argument_slot_write_run", command_id, operands)

    return ALIGNED_DECODE_INSTRUCTION(code, offset, limit)


def decode_mes(data: bytes, source: dict[str, Any] | None = None) -> dict[str, Any]:
    previous_instruction = base_decoder.decode_instruction
    previous_expression = base_decoder.decode_expression
    base_decoder.decode_instruction = decode_instruction
    base_decoder.decode_expression = tolerant_decoder.decode_expression
    try:
        document = base_decoder.decode_mes(data, source)
    finally:
        base_decoder.decode_instruction = previous_instruction
        base_decoder.decode_expression = previous_expression
    document["schema"] = "ai5_mes_partial_ir/v8"
    document["diagnostics"].append(
        {
            "level": "info",
            "code": "commands_05_16_loop_shapes",
            "message": "Command 0x05 and the command-0x16 argument-slot run retain their continuation-controlled expression loops.",
        }
    )
    return document


def main() -> None:
    parser = argparse.ArgumentParser(description="Decode MES with confirmed continuation-controlled operand loops.")
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
