from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

import mes_basic_block_ir_v4
import mes_basic_block_ir_v5
import mes_control_flow_ir as control_decoder
import mes_partial_decoder as base_decoder
import mes_tolerant_ir as tolerant_decoder
from mes_archive_ir import load_archive_entry


ROOT = Path(__file__).resolve().parents[1]
V5_DECODE_INSTRUCTION = mes_basic_block_ir_v5.decode_instruction


def decode_instruction(code: bytes, offset: int, limit: int) -> dict[str, Any] | None:
    if offset >= limit or code[offset] not in {0x06, 0x07, 0x08}:
        return V5_DECODE_INSTRUCTION(code, offset, limit)
    command_id = code[offset]
    cursor = offset + 1
    destination, cursor = tolerant_decoder.decode_expression(code, cursor, limit)
    if cursor >= limit:
        raise base_decoder.MesDecodeError(f"truncated command 0x{command_id:02x} bank at 0x{cursor:x}")
    bank = code[cursor]
    cursor += 1
    pairs: list[dict[str, Any]] = []
    while True:
        expression, cursor = tolerant_decoder.decode_expression(code, cursor, limit)
        if cursor >= limit:
            raise base_decoder.MesDecodeError(f"truncated command 0x{command_id:02x} continuation at 0x{cursor:x}")
        continuation = code[cursor]
        cursor += 1
        pairs.append(
            {
                "type": "expression_byte_pair",
                "expression": expression,
                "continuation": continuation,
            }
        )
        if continuation == 0:
            break
    return base_decoder.finish_instruction(
        code,
        offset,
        cursor,
        {
            0x06: "banked_u8_write_run",
            0x07: "banked_u16_write_run",
            0x08: "banked_i32_write_run",
        }[command_id],
        command_id,
        [
            {"type": "expression_index", "value": destination},
            {"type": "u8_bank", "value": bank, "sourceOffset": destination["end_offset"]},
            {"type": "expression_byte_pairs", "pairs": pairs},
        ],
    )


def decode_mes(data: bytes, source: dict[str, Any] | None = None) -> dict[str, Any]:
    previous = control_decoder.decode_instruction
    control_decoder.decode_instruction = decode_instruction
    try:
        document = mes_basic_block_ir_v4.decode_mes(data, source)
    finally:
        control_decoder.decode_instruction = previous
    document["schema"] = "ai5_mes_basic_block_ir/v6"
    document["diagnostics"].extend(
        [
            {
                "level": "info",
                "code": "command_06_banked_u8_write_run",
                "message": (
                    "Command 0x06 evaluates a destination index, reads a static bank byte, and writes one or "
                    "more expression values to consecutive banked_u8 indices."
                ),
            },
            {
                "level": "info",
                "code": "command_03_global_u8_write_run",
                "message": (
                    "Command 0x03 writes clamped 0..15 expression values to consecutive global_u8 indices "
                    "while its expression-pair continuation byte is nonzero."
                ),
            },
            {
                "level": "info",
                "code": "command_04_state_u16_write_run",
                "message": (
                    "Command 0x04 reads a u8 start index and writes one or more expression values to "
                    "consecutive state_u16 indices."
                ),
            },
            {
                "level": "info",
                "code": "command_07_banked_u16_write_run",
                "message": (
                    "Command 0x07 evaluates a destination index, reads a static bank byte, and writes one or "
                    "more expression values to consecutive banked_u16 indices."
                ),
            },
            {
                "level": "info",
                "code": "command_08_banked_i32_write_run",
                "message": (
                    "Command 0x08 evaluates a destination index, reads a static bank byte, and writes one or "
                    "more expression values to consecutive banked_i32 indices."
                ),
            },
        ]
    )
    return document


def main() -> None:
    parser = argparse.ArgumentParser(description="Emit MES basic-block IR v6 with native command 0x03/0x04/0x06/0x07/0x08 writes.")
    parser.add_argument("archive", type=Path)
    parser.add_argument("entry")
    parser.add_argument("-o", "--output", type=Path)
    args = parser.parse_args()
    archive = args.archive if args.archive.is_absolute() else ROOT / args.archive
    data, source = load_archive_entry(archive, args.entry)
    document = decode_mes(data, {**source, "archive": archive.name})
    encoded = json.dumps(document, ensure_ascii=False, indent=2)
    if args.output:
        output = args.output if args.output.is_absolute() else ROOT / args.output
        if archive.resolve().parent in output.resolve().parents:
            parser.error("output must be outside the source archive directory")
        output.parent.mkdir(parents=True, exist_ok=True)
        temporary = output.with_name(output.name + ".tmp")
        temporary.write_text(encoded + "\n", encoding="utf-8")
        temporary.replace(output)
        flow = document["controlFlow"]
        print(
            f"{source['entry']}: blocks={flow['basicBlockCount']} blockEdges={flow['blockEdgeCount']} "
            f"decoded={document['decodedRatio']:.1%} output={output}"
        )
    else:
        print(encoded)


if __name__ == "__main__":
    main()
