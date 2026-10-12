from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]


class ExpressionError(ValueError):
    def __init__(self, message: str, *, ir_error: dict[str, Any] | None = None) -> None:
        super().__init__(message)
        # The partial-decoder API keeps its original exception text. Consumers
        # producing the analyzer contract can retain the authority's diagnostic
        # and consumed coordinates without parsing that text or decoding again.
        self.ir_error = ir_error


BINARY_OPS = {
    0xE0: "add",
    0xE1: "subtract",
    0xE2: "multiply",
    0xE3: "divide_unsigned",
    0xE4: "modulo_unsigned",
    0xE6: "logical_and",
    0xE7: "logical_or",
    0xE8: "bit_and",
    0xE9: "bit_or",
    0xEA: "bit_xor",
    0xEB: "less_than",
    0xEC: "greater_than",
    0xED: "less_or_equal",
    0xEE: "greater_or_equal",
    0xEF: "equal",
    0xF0: "not_equal",
}


def source(offset: int, token: int) -> dict[str, Any]:
    return {"offset": offset, "token": f"0x{token:02x}"}


MAX_EXPRESSION_BYTES = 0x1000


def read_uint(data: bytes, offset: int, size: int, limit: int | None = None) -> tuple[int, int]:
    """Read one little-endian operand, bounded by the expression's own end.

    ``limit`` is the expression scan limit rather than the length of the buffer.
    The authority bounds every operand read by that limit, so an operand running
    past it is truncated even when the surrounding code has more bytes.
    """
    end = offset + size
    if end > (len(data) if limit is None else min(limit, len(data))):
        raise ExpressionError(f"truncated {size}-byte operand at 0x{offset:x}")
    return int.from_bytes(data[offset:end], "little"), end


def pop_node(stack: list[dict[str, Any]], offset: int, token: int) -> dict[str, Any]:
    if not stack:
        raise ExpressionError(f"stack underflow for token 0x{token:02x} at 0x{offset:x}")
    return stack.pop()


def parse_expression(
    data: bytes, offset: int, max_bytes: int = MAX_EXPRESSION_BYTES, *, strict: bool = False
) -> dict[str, Any]:
    """Parse one 0xff-terminated RPN expression.

    ``strict`` selects the authority's two decode modes. Strict parsing fails
    closed when the terminator arrives with a stack depth other than one, which
    is how a region becomes a byte-preserving opaque span instead of continuing
    to decode; the permissive mode records that as a diagnostic and returns the
    stack, which is the structural mode used for analysis rather than framing.
    """
    start = offset
    # The scan never runs past MAX_EXPRESSION_BYTES from the start, whatever the
    # caller allows, because the authority caps it before applying its own limit.
    limit = min(len(data), offset + min(max_bytes, MAX_EXPRESSION_BYTES))
    stack: list[dict[str, Any]] = []
    diagnostics: list[str] = []

    def failure(message: str, ir_message: str) -> ExpressionError:
        if start < 0 or start >= len(data):
            return ExpressionError(
                message,
                ir_error={"ok": False, "error": "Expression offset is outside bytecode."},
            )
        return ExpressionError(
            message,
            ir_error={"ok": False, "error": ir_message, "offset": start, "end_offset": offset},
        )

    def read_operand(size: int, ir_message: str) -> tuple[int, int]:
        try:
            return read_uint(data, offset, size, limit)
        except ExpressionError as exc:
            raise failure(str(exc), ir_message) from exc

    def pop_operand(token_offset: int, token: int, ir_message: str) -> dict[str, Any]:
        try:
            return pop_node(stack, token_offset, token)
        except ExpressionError as exc:
            raise failure(str(exc), ir_message) from exc

    while offset < limit:
        token_offset = offset
        token = data[offset]
        offset += 1

        if token == 0xFF:
            if len(stack) != 1:
                if strict:
                    raise failure(
                        f"expression at 0x{start:x} ended with stack depth {len(stack)}, expected 1",
                        f"Expression ended with stack depth {len(stack)}, expected 1.",
                    )
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

        if token in BINARY_OPS:
            ir_message = f"Expression stack underflow for token 0x{token:02X}."
            rhs = pop_operand(token_offset, token, ir_message)
            lhs = pop_operand(token_offset, token, ir_message)
            stack.append({
                "type": "binary", "op": BINARY_OPS[token], "lhs": lhs, "rhs": rhs,
                "source": source(token_offset, token),
            })
            continue

        if token == 0xE5:
            bound = pop_operand(token_offset, token, "Expression stack underflow for random_below.")
            stack.append({
                "type": "call", "name": "random_below", "args": [bound],
                "source": source(token_offset, token),
            })
            continue

        if token == 0xF1:
            value, offset = read_operand(2, "Expression literal is truncated.")
            stack.append({"type": "literal", "value": value, "width": 16, "source": source(token_offset, token)})
            continue

        if token == 0xF2:
            value, offset = read_operand(4, "Expression literal is truncated.")
            stack.append({"type": "literal", "value": value, "width": 32, "source": source(token_offset, token)})
            continue

        if token in {0x80, 0xF8}:
            index, offset = read_operand(1, "Expression state index is truncated.")
            storage = "state_u16" if token == 0x80 else "state_i32"
            stack.append({
                "type": "state_ref", "storage": storage,
                "index": {"type": "literal", "value": index},
                "source": source(token_offset, token),
            })
            continue

        if token in {0xF3, 0xF6}:
            index, offset = read_operand(2, "Expression global index is truncated.")
            storage = "global_u8" if token == 0xF3 else "global_i32"
            stack.append({
                "type": "state_ref", "storage": storage,
                "index": {"type": "literal", "value": index},
                "source": source(token_offset, token),
            })
            continue

        if token in {0xF5, 0xF7}:
            index = pop_operand(token_offset, token, "Expression stack underflow for dynamic global index.")
            storage = "global_u8" if token == 0xF5 else "global_i32"
            stack.append({
                "type": "state_ref", "storage": storage, "index": index,
                "source": source(token_offset, token),
            })
            continue

        if token in {0xA0, 0xC0, 0xF9}:
            ir_message = "Expression banked state reference is truncated."
            index = pop_operand(token_offset, token, ir_message)
            bank, offset = read_operand(1, ir_message)
            storage = {0xA0: "banked_u16", 0xC0: "banked_u8", 0xF9: "banked_i32"}[token]
            stack.append({
                "type": "state_ref", "storage": storage, "bank": bank, "index": index,
                "source": source(token_offset, token),
            })
            continue

        # The original evaluator pushes every non-special token as its raw byte value.
        stack.append({"type": "literal", "value": token, "width": 8, "source": source(token_offset, token)})

    reason = "end of file" if offset >= len(data) else f"maximum length {max_bytes} reached"
    raise failure(
        f"missing 0xff expression terminator before {reason} (start 0x{start:x})",
        "Expression is missing its 0xFF terminator.",
    )


def parse_expression_ir(
    data: bytes, offset: int, limit: int = -1, structural: bool = False
) -> dict[str, Any]:
    """Produce the GDScript expression contract through the shared RPN parser.

    ``limit`` is an absolute, exclusive bytecode coordinate. Strict results omit
    ``valid`` and ``diagnostics``; structural results retain a non-single stack
    as boundary-only evidence. Parse failures are dictionaries with the exact
    diagnostic and consumed coordinates carried by the analyzer handoff.
    """
    if offset < 0 or offset >= len(data):
        return {"ok": False, "error": "Expression offset is outside bytecode."}
    max_bytes = MAX_EXPRESSION_BYTES if limit < 0 else limit - offset
    try:
        result = parse_expression(data, offset, max_bytes=max_bytes, strict=not structural)
    except ExpressionError as exc:
        if exc.ir_error is None:
            raise
        return dict(exc.ir_error)

    pending: list[Any] = [result["ast"]]
    while pending:
        value = pending.pop()
        if isinstance(value, dict):
            if value.get("type") == "state_ref":
                value.setdefault("bank", 0)
            pending.extend(value.values())
        elif isinstance(value, list):
            pending.extend(value)

    result["ok"] = True
    if structural:
        if not result["valid"]:
            depth = len(result["ast"]["items"])
            result["diagnostics"] = [f"Expression ended with stack depth {depth}, expected 1."]
    else:
        result.pop("valid")
        result.pop("diagnostics")
    return result


def find_all(data: bytes, marker: bytes) -> list[int]:
    hits: list[int] = []
    offset = 0
    while True:
        offset = data.find(marker, offset)
        if offset < 0:
            return hits
        hits.append(offset)
        offset += 1


def main() -> None:
    parser = argparse.ArgumentParser(description="Decode AI5 MES 0xff-terminated RPN expressions into JSON AST.")
    parser.add_argument("mes", type=Path)
    parser.add_argument("--offset", action="append", default=[], help="Expression offset (decimal or 0x-prefixed).")
    parser.add_argument("--after-hex", help="Parse after every occurrence of this hex byte marker.")
    parser.add_argument("--max-bytes", type=lambda value: int(value, 0), default=0x1000)
    parser.add_argument("--valid-only", action="store_true")
    args = parser.parse_args()

    path = args.mes if args.mes.is_absolute() else ROOT / args.mes
    data = path.read_bytes()
    requests: list[tuple[int, int | None]] = [(int(value, 0), None) for value in args.offset]
    if args.after_hex:
        marker = bytes.fromhex(args.after_hex)
        requests.extend((hit + len(marker), hit) for hit in find_all(data, marker))
    if not requests:
        parser.error("provide --offset or --after-hex")

    results: list[dict[str, Any]] = []
    for expression_offset, marker_offset in requests:
        try:
            row = parse_expression(data, expression_offset, args.max_bytes)
        except ExpressionError as exc:
            row = {"offset": expression_offset, "valid": False, "diagnostics": [str(exc)]}
        if marker_offset is not None:
            row["marker_offset"] = marker_offset
        if not args.valid_only or row["valid"]:
            results.append(row)

    print(json.dumps({"schema": "ai5_mes_expression/v1", "source": str(path), "expressions": results}, indent=2))


if __name__ == "__main__":
    main()
