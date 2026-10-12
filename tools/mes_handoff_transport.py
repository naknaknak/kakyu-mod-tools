"""Bounded, JSON-readable subset of the GD analyzer handoff transport.

Accepted values are exact builtin dict/list/str/bool/int/float/None and packed
bytes/bytearray. Dictionary keys must already be strings: no coercion can hide
a key collision. Integers are signed 64-bit; floats must be finite. Strings
must contain Unicode scalar values and only JSON-standard escaped controls
(backspace, tab, LF, FF, CR). Other C0 controls, including GD's nonstandard
vertical-tab escape, are rejected instead of publishing unreadable JSON.

For accepted values the bytes match JSON.stringify(normalize(value), "", true,
true). The float interval calculation uses Python integer arithmetic and the
Grisu2 boundaries; cached decimal powers are derived, not copied from a table.
The decimal grid search is independent of the engine's digit-generation code.
See Godot 4.7 core/io/json.cpp and thirdparty/grisu2/grisu2.h, and Florian
Loitsch, "Printing Floating-Point Numbers Quickly and Accurately with Integers"
(PLDI 2010). No engine or third-party runtime is required.

Limits apply per call, including repeated shared containers: 256 nesting
levels, 4 million normalized nodes, and 256 MiB of canonical UTF-8 output.
Cycles, unsupported types and values exceeding any limit fail closed.
"""

from __future__ import annotations

from functools import lru_cache
import math
import re
import struct
from typing import Any


MAX_DEPTH = 256
MAX_NODES = 4_000_000
MAX_BYTES = 256 * 1024 * 1024
_MIN_INT = -(1 << 63)
_MAX_INT = (1 << 63) - 1
_PACKED_KEY = "$packed_byte_array_hex"
_ESCAPES = str.maketrans({
    "\\": "\\\\", '"': '\\"', "\b": "\\b", "\t": "\\t", "\n": "\\n",
    "\f": "\\f", "\r": "\\r",
})
_UNSUPPORTED_CONTROLS = re.compile("[\x00-\x07\x0b\x0e-\x1f]")


class TransportError(ValueError):
    """A value cannot be represented by the supported handoff transport."""


def _normalized_binary(significand: int, exponent: int) -> tuple[int, int]:
    shift = 64 - significand.bit_length()
    return significand << shift, exponent - shift


@lru_cache(maxsize=79)
def _decimal_power(exponent: int) -> tuple[int, int]:
    """Nearest normalized 64-bit approximation to 10**exponent, ties upward."""
    numerator = 10 ** max(exponent, 0)
    denominator = 10 ** max(-exponent, 0)
    binary_exponent = numerator.bit_length() - denominator.bit_length() - 63
    if binary_exponent < 0:
        numerator <<= -binary_exponent
    else:
        denominator <<= binary_exponent
    if numerator < denominator << 63:
        numerator <<= 1
        binary_exponent -= 1
    return (2 * numerator + denominator) // (2 * denominator), binary_exponent


def _float_text(value: float) -> str:
    if value == 0.0:
        return "0.0"
    bits = struct.unpack("<Q", struct.pack("<d", abs(value)))[0]
    exponent_bits, fraction = bits >> 52, bits & ((1 << 52) - 1)
    significand = fraction + ((1 << 52) if exponent_bits else 0)
    exponent = exponent_bits - 1075 if exponent_bits else -1074
    upper, upper_exponent = _normalized_binary(2 * significand + 1, exponent - 1)
    if fraction == 0 and exponent_bits > 1:
        lower, lower_exponent = 4 * significand - 1, exponent - 2
    else:
        lower, lower_exponent = 2 * significand - 1, exponent - 1
    lower <<= lower_exponent - upper_exponent
    center, center_exponent = _normalized_binary(significand, exponent)

    # Select the same eight-decimal-step scale used by the GD Grisu2 interval.
    requested = ((-61 - upper_exponent) * 78913 + (1 << 18) - 1) // (1 << 18)
    decimal_exponent = -300 + ((300 + requested + 7) // 8) * 8
    power, power_exponent = _decimal_power(decimal_exponent)
    rounded_product = lambda number: (number * power + (1 << 63)) >> 64
    lower = rounded_product(lower) + 1
    upper = rounded_product(upper) - 1
    center = rounded_product(center)
    binary_exponent = center_exponent + power_exponent + 64
    unit = 1 << -binary_exponent

    # Find the coarsest decimal grid intersecting the closed safe interval.
    # At that precision select its closest point to the scaled center, with
    # midpoint ties upward, matching GD's final digit adjustment.
    grid_exponent = len(str(upper // unit)) - 1
    for _ in range(18):
        scale = 10 ** max(-grid_exponent, 0)
        grid_unit = unit * 10 ** max(grid_exponent, 0)
        first = (lower * scale + grid_unit - 1) // grid_unit
        last = upper * scale // grid_unit
        if first <= last:
            nearest = (2 * center * scale + grid_unit) // (2 * grid_unit)
            digits = str(max(first, min(last, nearest)))
            break
        grid_exponent -= 1
    else:
        raise TransportError("Float exceeds the bounded GD decimal precision.")

    decimal_point = len(digits) + grid_exponent - decimal_exponent
    if len(digits) <= decimal_point <= 15:
        text = digits + "0" * (decimal_point - len(digits)) + ".0"
    elif 0 < decimal_point <= 15:
        text = digits[:decimal_point] + "." + digits[decimal_point:]
    elif -4 < decimal_point <= 0:
        text = "0." + "0" * -decimal_point + digits
    else:
        mantissa = digits[0] + ("." + digits[1:] if len(digits) > 1 else "")
        text = f"{mantissa}e{decimal_point - 1:+03d}"
    return "-" + text if value < 0 else text


def _string_bytes(value: str) -> bytes:
    if _UNSUPPORTED_CONTROLS.search(value):
        raise TransportError("Handoff strings contain an unsupported control character.")
    try:
        return ('"' + value.translate(_ESCAPES) + '"').encode("utf-8")
    except UnicodeEncodeError as error:
        raise TransportError("Handoff strings must contain valid Unicode scalar values.") from error


def _scalar_bytes(value: Any) -> bytes:
    if value is None:
        return b"null"
    if type(value) is bool:
        return b"true" if value else b"false"
    if type(value) is int:
        if not _MIN_INT <= value <= _MAX_INT:
            raise TransportError("Handoff integer is outside the signed 64-bit range.")
        return str(value).encode("ascii")
    if type(value) is float:
        if not math.isfinite(value):
            raise TransportError("Handoff floats must be finite.")
        return _float_text(value).encode("ascii")
    if type(value) is str:
        if len(value) > MAX_BYTES:
            raise TransportError("Handoff exceeds its canonical byte limit.")
        return _string_bytes(value)
    raise TransportError(f"Unsupported handoff transport type: {type(value).__name__}.")


def normalize(value: Any) -> Any:
    """Return a validated independent tree with sorted keys and packed bytes."""
    active: set[int] = set()
    nodes = 0
    byte_count = 0

    def consume(count: int, size: int) -> None:
        nonlocal nodes, byte_count
        nodes += count
        byte_count += size
        if nodes > MAX_NODES:
            raise TransportError("Handoff exceeds its normalized node limit.")
        if byte_count > MAX_BYTES:
            raise TransportError("Handoff exceeds its canonical byte limit.")

    def visit(child: Any, depth: int) -> Any:
        if depth > MAX_DEPTH:
            raise TransportError("Handoff exceeds its nesting depth limit.")
        kind = type(child)
        if kind in (bytes, bytearray):
            # Check the hex expansion before allocating it.
            consume(3, 2 * len(child) + len(_PACKED_KEY) + 7)
            if depth + 1 > MAX_DEPTH:
                raise TransportError("Handoff exceeds its nesting depth limit.")
            return {_PACKED_KEY: child.hex()}
        if kind not in (dict, list):
            encoded = _scalar_bytes(child)
            consume(1, len(encoded))
            return child
        if id(child) in active:
            raise TransportError("Handoff transport contains a container cycle.")
        if len(child) > MAX_NODES - nodes:
            raise TransportError("Handoff exceeds its normalized node limit.")
        consume(1, 2 + max(0, len(child) - 1))
        active.add(id(child))
        try:
            if kind is list:
                result = []
                for item in child:
                    result.append(visit(item, depth + 1))
                return result
            if any(type(key) is not str for key in child):
                raise TransportError("Handoff dictionary keys must be strings; coercion is forbidden.")
            result = {}
            for key in sorted(child):
                consume(1, len(_scalar_bytes(key)) + 1)
                result[key] = visit(child[key], depth + 1)
            return result
        finally:
            active.remove(id(child))

    return visit(value, 0)


def canonical_json_bytes(value: Any) -> bytes:
    """Return GD-compatible bytes for the validated JSON-readable subset."""
    normalized = normalize(value)
    output = bytearray()

    def write(child: Any) -> None:
        if type(child) is list:
            output.extend(b"[")
            for index, item in enumerate(child):
                if index:
                    output.extend(b",")
                write(item)
            output.extend(b"]")
        elif type(child) is dict:
            output.extend(b"{")
            for index, (key, item) in enumerate(child.items()):
                if index:
                    output.extend(b",")
                output.extend(_string_bytes(key))
                output.extend(b":")
                write(item)
            output.extend(b"}")
        else:
            output.extend(_scalar_bytes(child))

    write(normalized)
    return bytes(output)
