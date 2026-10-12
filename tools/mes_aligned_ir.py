from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

import mes_partial_decoder as base_decoder
import mes_tolerant_ir as tolerant_decoder
from mes_archive_ir import load_archive_entry


ROOT = Path(__file__).resolve().parents[1]
TOLERANT_DECODE_INSTRUCTION = tolerant_decoder.decode_instruction


def decode_instruction(code: bytes, offset: int, limit: int) -> dict[str, Any] | None:
    return TOLERANT_DECODE_INSTRUCTION(code, offset, limit)


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
            "code": "command_04_dynamic_shape",
            "message": "Command 0x04 uses the native u8-index plus repeated expression/continuation write-run shape.",
        }
    )
    return document


def main() -> None:
    parser = argparse.ArgumentParser(description="Decode MES with corpus-aligned fixed command shapes.")
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
