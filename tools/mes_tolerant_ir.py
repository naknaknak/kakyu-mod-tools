from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

import mes_corrected_ir as corrected_decoder
import mes_expression
import mes_partial_decoder as base_decoder
from mes_archive_ir import load_archive_entry


ROOT = Path(__file__).resolve().parents[1]
CORRECTED_DECODE_INSTRUCTION = corrected_decoder.decode_instruction


def expression_source(offset: int, token: int) -> dict[str, Any]:
    return {"offset": offset, "token": f"0x{token:02x}"}


def parse_expression_tolerant(data: bytes, offset: int, max_bytes: int) -> dict[str, Any]:
    start = offset
    limit = min(len(data), offset + max_bytes)
    stack: list[dict[str, Any]] = []
    diagnostics: list[str] = []

    def pop(token_offset: int, token: int) -> dict[str, Any]:
        if stack:
            return stack.pop()
        diagnostics.append(f"stack underflow for token 0x{token:02x} at 0x{token_offset:x}")
        return {
            "type": "underflow",
            "source": expression_source(token_offset, token),
        }

    def read_uint(size: int) -> int:
        nonlocal offset
        end = offset + size
        if end > limit:
            raise base_decoder.MesDecodeError(f"truncated {size}-byte expression operand at 0x{offset:x}")
        value = int.from_bytes(data[offset:end], "little")
        offset = end
        return value

    while offset < limit:
        token_offset = offset
        token = data[offset]
        offset += 1

        if token == 0xFF:
            if len(stack) != 1:
                diagnostics.append(f"expression ended with stack depth {len(stack)}, expected 1")
            ast: dict[str, Any] = stack[0] if len(stack) == 1 else {"type": "stack", "items": stack}
            return {
                "offset": start,
                "end_offset": offset,
                "byte_length": offset - start,
                "raw_hex": data[start:offset].hex(),
                "ast": ast,
                "valid": not diagnostics,
                "diagnostics": diagnostics,
            }

        if token in mes_expression.BINARY_OPS:
            rhs = pop(token_offset, token)
            lhs = pop(token_offset, token)
            stack.append(
                {
                    "type": "binary",
                    "op": mes_expression.BINARY_OPS[token],
                    "lhs": lhs,
                    "rhs": rhs,
                    "source": expression_source(token_offset, token),
                }
            )
            continue

        if token == 0xE5:
            stack.append(
                {
                    "type": "call",
                    "name": "random_below",
                    "args": [pop(token_offset, token)],
                    "source": expression_source(token_offset, token),
                }
            )
            continue

        if token == 0xF1:
            stack.append(
                {
                    "type": "literal",
                    "value": read_uint(2),
                    "width": 16,
                    "source": expression_source(token_offset, token),
                }
            )
            continue

        if token == 0xF2:
            stack.append(
                {
                    "type": "literal",
                    "value": read_uint(4),
                    "width": 32,
                    "source": expression_source(token_offset, token),
                }
            )
            continue

        if token in {0x80, 0xF8}:
            index = read_uint(1)
            stack.append(
                {
                    "type": "state_ref",
                    "storage": "state_u16" if token == 0x80 else "state_i32",
                    "index": {"type": "literal", "value": index},
                    "source": expression_source(token_offset, token),
                }
            )
            continue

        if token in {0xF3, 0xF6}:
            index = read_uint(2)
            stack.append(
                {
                    "type": "state_ref",
                    "storage": "global_u8" if token == 0xF3 else "global_i32",
                    "index": {"type": "literal", "value": index},
                    "source": expression_source(token_offset, token),
                }
            )
            continue

        if token in {0xF5, 0xF7}:
            stack.append(
                {
                    "type": "state_ref",
                    "storage": "global_u8" if token == 0xF5 else "global_i32",
                    "index": pop(token_offset, token),
                    "source": expression_source(token_offset, token),
                }
            )
            continue

        if token in {0xA0, 0xC0, 0xF9}:
            index = pop(token_offset, token)
            bank = read_uint(1)
            stack.append(
                {
                    "type": "state_ref",
                    "storage": {0xA0: "banked_u16", 0xC0: "banked_u8", 0xF9: "banked_i32"}[token],
                    "bank": bank,
                    "index": index,
                    "source": expression_source(token_offset, token),
                }
            )
            continue

        stack.append(
            {
                "type": "literal",
                "value": token,
                "width": 8,
                "source": expression_source(token_offset, token),
            }
        )

    raise base_decoder.MesDecodeError(
        f"missing 0xff expression terminator before maximum length {max_bytes} reached (start 0x{start:x})"
    )


def decode_expression(code: bytes, offset: int, limit: int) -> tuple[dict[str, Any], int]:
    expression = parse_expression_tolerant(code, offset, limit - offset)
    return expression, int(expression["end_offset"])


def decode_instruction(code: bytes, offset: int, limit: int) -> dict[str, Any] | None:
    previous = base_decoder.decode_expression
    base_decoder.decode_expression = decode_expression
    try:
        return CORRECTED_DECODE_INSTRUCTION(code, offset, limit)
    finally:
        base_decoder.decode_expression = previous


def decode_mes(data: bytes, source: dict[str, Any] | None = None) -> dict[str, Any]:
    previous_instruction = base_decoder.decode_instruction
    previous_expression = base_decoder.decode_expression
    base_decoder.decode_instruction = decode_instruction
    base_decoder.decode_expression = decode_expression
    try:
        document = base_decoder.decode_mes(data, source)
    finally:
        base_decoder.decode_instruction = previous_instruction
        base_decoder.decode_expression = previous_expression
    document["schema"] = "ai5_mes_partial_ir/v6"
    document["diagnostics"].append(
        {
            "level": "info",
            "code": "tolerant_expression_stack",
            "message": "Expression stack underflow is retained as an AST diagnostic without losing byte alignment.",
        }
    )
    return document


def main() -> None:
    parser = argparse.ArgumentParser(description="Decode MES while preserving native expression underflow diagnostics.")
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
