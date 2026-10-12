from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

import mes_basic_block_ir_v4
import mes_control_flow_ir as control_decoder
import mes_partial_decoder as base_decoder
import mes_tolerant_ir as tolerant_decoder
from mes_archive_ir import load_archive_entry


ROOT = Path(__file__).resolve().parents[1]
V4_DECODE_INSTRUCTION = control_decoder.decode_instruction


def decode_instruction(code: bytes, offset: int, limit: int) -> dict[str, Any] | None:
    if offset >= limit or code[offset] != 0x03:
        return V4_DECODE_INSTRUCTION(code, offset, limit)
    cursor = offset + 1
    if cursor + 2 > limit:
        raise base_decoder.MesDecodeError(f"truncated command 0x03 index at 0x{cursor:x}")
    index = code[cursor] | (code[cursor + 1] << 8)
    cursor += 2
    pairs: list[dict[str, Any]] = []
    while True:
        expression, cursor = tolerant_decoder.decode_expression(code, cursor, limit)
        if cursor >= limit:
            raise base_decoder.MesDecodeError(f"truncated command 0x03 continuation at 0x{cursor:x}")
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
        "global_u8_write_run",
        0x03,
        [
            {"type": "u16_index", "value": index, "sourceOffset": offset + 1},
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
    document["schema"] = "ai5_mes_basic_block_ir/v5"
    document["diagnostics"].append(
        {
            "level": "info",
            "code": "command_03_global_u8_write_run",
            "message": (
                "Command 0x03 writes clamped 0..15 expression values to consecutive global_u8 indices "
                "while its expression-pair continuation byte is nonzero."
            ),
        }
    )
    return document


def main() -> None:
    parser = argparse.ArgumentParser(description="Emit MES basic-block IR v5 with native command 0x03 write runs.")
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
