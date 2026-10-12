from __future__ import annotations

import argparse
import json
import struct
from pathlib import Path
from typing import Any

from mes_archive_ir import load_archive_entry, parse_mes_container
from mes_cfg_seed import seed_cfg
from mes_expression import ExpressionError, parse_expression


ROOT = Path(__file__).resolve().parents[1]

# Operand read order recovered from the CCommon handlers. "b" is one raw byte and
# "e" is one 0xff-terminated RPN expression. Complex handlers are intentionally absent.
FIXED_GRAMMARS: dict[int, str] = {
    0x00: "",
    0x02: "",
    0x13: "b",
    0x19: "",
    0x1A: "",
    0x1E: "",
}

# Every write-run command ends the same way: a run of (expression, continuation
# byte) pairs that stops on a zero continuation. Only the header before the run
# differs, so each command is named by the header it reads. A fixed grammar can
# only ever match a run of exactly one pair, which is why the six commands moved
# here framed their single-pair records and nothing longer.
#   ""    no header
#   "u8"  one byte, "u16" one little-endian u16, "e" one expression
#   "e+b" one expression then a one-byte bank
PAIR_RUN_OPS: dict[int, tuple[str, str]] = {
    0x03: ("u16", "global_u8_write_run"),
    0x04: ("u8", "state_u16_write_run"),
    0x05: ("e", "dynamic_global_u8_write_run"),
    0x06: ("e+b", "banked_u8_write_run"),
    0x07: ("e+b", "banked_u16_write_run"),
    0x08: ("e+b", "banked_i32_write_run"),
    0x09: ("u16", "argument_slot_write_run"),
    0x0A: ("e", "global_i32_write_run"),
    0x16: ("u8", "argument_slot_write_run"),
}

# Commands whose whole operand is one tag-terminated record list. The list is the
# same grammar in every one of them, which is why porting it moves eight commands
# at once rather than one; 0x10 alone carries four trailing bytes after the list.
RECORD_LIST_COMMANDS: dict[int, str] = {
    0x0E: "command_0e",
    0x0F: "command_0f",
    0x10: "command_10",
    0x11: "definition_invoke",
    0x12: "native_record_dispatch",
    0x15: "native_selection",
    0x1B: "command_1b",
    0x1D: "script_transfer",
}


class MesDecodeError(ValueError):
    pass


def read_u32(code: bytes, offset: int, limit: int) -> tuple[int, int]:
    if offset + 4 > limit:
        raise MesDecodeError(f"truncated u32 at 0x{offset:x}")
    return struct.unpack_from("<I", code, offset)[0], offset + 4


def decode_expression(
    code: bytes, offset: int, limit: int, *, structural: bool = False
) -> tuple[dict[str, Any], int]:
    return _parse_expression(code, offset, limit, structural=structural)


def _parse_expression(
    code: bytes, offset: int, limit: int, *, structural: bool
) -> tuple[dict[str, Any], int]:
    # Strict remains the default: a wrong stack depth stops the region. The
    # explicit structural mode retains that stack solely to preserve framing.
    try:
        expression = parse_expression(code, offset, max_bytes=limit - offset, strict=not structural)
    except ExpressionError as exc:
        raise MesDecodeError(str(exc)) from exc
    if expression["end_offset"] > limit:
        raise MesDecodeError(f"expression at 0x{offset:x} crosses node end 0x{limit:x}")
    return expression, expression["end_offset"]


def _decode_expression_for_mode(
    code: bytes, offset: int, limit: int, *, structural: bool
) -> tuple[dict[str, Any], int]:
    # Legacy projections temporarily install a three-argument tolerant hook.
    # Keep their default path intact; explicit structural decoding always uses
    # the shared parser, whose underflow contract differs from that hook.
    if structural:
        return _parse_expression(code, offset, limit, structural=True)
    return decode_expression(code, offset, limit)


def decode_cstring(code: bytes, offset: int, limit: int) -> tuple[dict[str, Any], int]:
    cursor = offset
    while cursor < limit and code[cursor] != 0:
        cursor += 1
    if cursor >= limit:
        raise MesDecodeError(f"CP932 byte string at 0x{offset:x} is unterminated")
    raw = code[offset:cursor]
    return (
        {
            "type": "cp932_bytes",
            "rawHex": raw.hex(),
            "sourceOffset": offset,
        },
        cursor + 1,
    )


def decode_record_list(
    code: bytes, offset: int, limit: int, *, structural: bool = False
) -> tuple[dict[str, Any], int]:
    """One record list: tagged records until the zero tag, which is consumed.

    Tag 1 is a NUL-terminated CP932 byte string and tag 2 an RPN expression. Any
    other tag is a one-byte record with no payload, so an unrecognized tag stays
    inside the framing instead of ending it.
    """
    cursor = offset
    records: list[dict[str, Any]] = []
    while cursor < limit:
        tag_offset = cursor
        tag = code[cursor]
        cursor += 1
        if tag == 0:
            return (
                {
                    "type": "record_list",
                    "sourceOffset": offset,
                    "endOffset": cursor,
                    "records": records,
                },
                cursor,
            )
        if tag == 1:
            value, cursor = decode_cstring(code, cursor, limit)
            records.append(
                {"tag": tag, "type": "string_record", "sourceOffset": tag_offset, "value": value}
            )
        elif tag == 2:
            expression, cursor = _decode_expression_for_mode(code, cursor, limit, structural=structural)
            records.append(
                {"tag": tag, "type": "expression_record", "sourceOffset": tag_offset, "value": expression}
            )
        else:
            records.append({"tag": tag, "type": "unknown_tag", "sourceOffset": tag_offset})
    raise MesDecodeError(f"structured record list at 0x{offset:x} is unterminated")


def decode_expression_byte_pairs(
    code: bytes, offset: int, limit: int, command_id: int, *, structural: bool = False
) -> tuple[list[dict[str, Any]], int]:
    cursor = offset
    pairs: list[dict[str, Any]] = []
    while True:
        expression, cursor = _decode_expression_for_mode(code, cursor, limit, structural=structural)
        if cursor >= limit:
            raise MesDecodeError(
                f"command 0x{command_id:02x} continuation is truncated at 0x{cursor:x}"
            )
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
            return pairs, cursor


def _decode_pair_run(
    code: bytes, offset: int, cursor: int, limit: int, command_id: int, *, structural: bool = False
) -> dict[str, Any]:
    header, op = PAIR_RUN_OPS[command_id]
    operands: list[dict[str, Any]] = []
    if header == "u8":
        if cursor >= limit:
            raise MesDecodeError(f"command 0x{command_id:02x} index is truncated at 0x{cursor:x}")
        operands.append({"type": "u8_index", "value": code[cursor], "sourceOffset": cursor})
        cursor += 1
    elif header == "u16":
        if cursor + 2 > limit:
            raise MesDecodeError(f"command 0x{command_id:02x} index is truncated at 0x{cursor:x}")
        operands.append(
            {
                "type": "u16_index",
                "value": int.from_bytes(code[cursor : cursor + 2], "little"),
                "sourceOffset": cursor,
            }
        )
        cursor += 2
    elif header in {"e", "e+b"}:
        destination, cursor = _decode_expression_for_mode(code, cursor, limit, structural=structural)
        operands.append({"type": "expression_index", "value": destination})
        if header == "e+b":
            if cursor >= limit:
                raise MesDecodeError(
                    f"command 0x{command_id:02x} bank is truncated at 0x{cursor:x}"
                )
            operands.append({"type": "u8_bank", "value": code[cursor], "sourceOffset": cursor})
            cursor += 1
    pairs, cursor = decode_expression_byte_pairs(code, cursor, limit, command_id, structural=structural)
    operands.append({"type": "expression_byte_pairs", "pairs": pairs})
    return finish_instruction(code, offset, cursor, op, command_id, operands)


# Presentation command 0x0D is a tree of confirmed native forms, tried in this
# order; a byte sequence matching none of them is one statement separator. Every
# structured form is `0D <subcommand> FF <record list>` and frames to that list's
# end, so what decides framing is which form matches, not how the bytes are read.
#
# A form that matches its prefix but fails a validity gate does NOT fall through
# to the separator. Some return "no match" and let a later form try; others
# return an error, which the region records as a byte-preserving opaque span.
# Reproducing that difference is the whole correctness of this port.

AX_EXACT_ENVELOPES: tuple[bytes, ...] = (
    bytes([0x0D, 0x03, 0xFF, 0x02, 0x02, 0xFF, 0x00]),
    bytes([0x0D, 0x03, 0xFF, 0x02, 0x06, 0xFF, 0x00]),
    bytes([0x0D, 0x03, 0xFF, 0x02, 0x07, 0xFF, 0x00]),
    bytes([0x0D, 0x03, 0xFF, 0x02, 0x08, 0xFF, 0x00]),
    bytes([0x0D, 0x0A, 0xFF, 0x02, 0x01, 0xFF, 0x00]),
)
AX_BINDING_PREFIX = bytes([0x0D, 0x03, 0xFF, 0x02, 0x00, 0xFF, 0x02, 0x00, 0xFF, 0x02])
AX_BINDING_SUFFIX = bytes([0xFF, 0x02, 0x02, 0xF9, 0x00, 0xFF, 0x00])
AX_MARKER_HEADER = bytes([0x0D, 0x08, 0xFF, 0x02, 0x00, 0xFF, 0x01])
AX_MARKER_SUFFIX = bytes([0x02, 0x02, 0xF9, 0x00, 0xFF, 0x00])
VOICE_MARKER_HEADER = bytes([0x0D, 0x07, 0xFF, 0x02, 0x02, 0xFF, 0x01])
VOICE_MARKER_SUFFIX = bytes([0x02, 0x00, 0xFF, 0x00])


def is_safe_entry_name(name: str) -> bool:
    if name in {"", ".", ".."}:
        return False
    if any(separator in name for separator in "/\\:"):
        return False
    return all(0x20 <= ord(character) <= 0x7E for character in name)


def _extension(name: str) -> str:
    _head, separator, tail = name.rpartition(".")
    return tail.lower() if separator else ""


def _read_marker_name(
    code: bytes, name_start: int, limit: int, ascii_only: bool
) -> tuple[str, str, int]:
    """Read a NUL-terminated name of at most 255 bytes.

    Returns one of three outcomes, because the caller must treat them
    differently: "nomatch" means a later form may still claim these bytes,
    "unterminated" means this form owns them and the region is opaque, and
    "ok" carries the name and the offset of its terminating NUL.
    """
    cursor = name_start
    while cursor < limit and cursor - name_start <= 255 and code[cursor] != 0:
        if ascii_only and not 0x20 <= code[cursor] <= 0x7E:
            return "nomatch", "", cursor
        cursor += 1
    if cursor >= limit or code[cursor] != 0:
        return "unterminated", "", cursor
    # GD get_string_from_ascii preserves each input byte as a code point.
    # ASCII-only forms have already applied their stricter byte gate above.
    return "ok", code[name_start:cursor].decode("latin-1"), cursor


def _presentation_operand(subcommand: int, kind: str, **fields: Any) -> dict[str, Any]:
    return {"type": kind, "presentationSubcommand": subcommand, **fields}


def _presentation_result(
    code: bytes, offset: int, end: int, op: str, subcommand: int, operand: dict[str, Any]
) -> dict[str, Any]:
    result = finish_instruction(code, offset, end, op, 0x0D, [operand])
    # A structured form owns its whole envelope, so the generic character-stream
    # probe that 0x0D otherwise carries does not describe it.
    result.pop("nativeStreamProbe", None)
    result["nativeStreamConsumption"] = (
        f"typed_presentation_subcommand_{subcommand}_record_list"
    )
    return result


def _literal_record_value(record: dict[str, Any]) -> int | None:
    if record.get("type") != "expression_record":
        return None
    expression = record.get("value", {})
    ast = expression.get("ast", {})
    if not expression.get("valid", True) or ast.get("type") != "literal":
        return None
    return int(ast["value"])


def _decode_effect_dispatch(
    code: bytes, offset: int, limit: int, *, structural: bool = False
) -> dict[str, Any] | None:
    if offset + 3 > limit or code[offset : offset + 3] != bytes([0x0D, 0x06, 0xFF]):
        return None
    record_list, end = decode_record_list(code, offset + 3, limit, structural=structural)
    records = record_list["records"]
    selector = _literal_record_value(records[0]) if records else None
    return _presentation_result(
        code,
        offset,
        end,
        "effect_dispatch",
        6,
        _presentation_operand(
            6,
            "effect_dispatch",
            executionSelector=-1 if selector is None else selector,
            selectorSource="literal" if selector is not None else "expression_or_native_default_unresolved",
            records=records,
            nativeRecordCount=len(records),
            nativeRecordTerminatorConsumed=True,
            nativeEffectSemantics="unresolved_not_executed",
            toolExecutionSemantics="metadata_only_native_effect_omitted",
        ),
    )


def _decode_ax_selected_cell_control(code: bytes, offset: int, limit: int) -> dict[str, Any] | None:
    if offset + 6 > limit or code[offset : offset + 4] != bytes([0x0D, 0x03, 0xFF, 0x02]):
        return None
    selector = code[offset + 4]
    if selector not in (1, 2) or code[offset + 5] != 0xFF:
        return None
    # The seven-byte selector-2 envelope keeps its own metadata contract below.
    if selector == 2 and offset + 7 <= limit and code[offset + 6] == 0:
        return None
    # The authority always reads this form structurally, then requires each
    # argument to be a valid literal. Preserve that rejection diagnostic even
    # when the enclosing instruction decoder uses strict expressions.
    record_list, end = decode_record_list(code, offset + 3, limit, structural=True)
    records = record_list["records"]
    if not records or len(records) > 4:
        raise MesDecodeError(
            f"AX selected-cell control at 0x{offset:x} requires one to four literal records"
        )
    values = [selector, 0, 0, 0]
    for index, record in enumerate(records):
        literal = _literal_record_value(record)
        if literal is None:
            raise MesDecodeError(
                f"AX selected-cell control at 0x{offset:x} has an unqualified nonliteral argument"
            )
        values[index] = literal
    if not (0 <= values[1] < 10 and 0 <= values[2] < 32 and values[3] == 0):
        raise MesDecodeError(
            f"AX selected-cell control at 0x{offset:x} is outside the bounded 10x32,"
            " consumer-zero domain"
        )
    return _presentation_result(
        code,
        offset,
        end,
        "ax_presentation_control",
        3,
        _presentation_operand(
            3,
            "ax_presentation_control",
            executionSelector=selector,
            consumerIndex=values[3],
            cellRow=values[1],
            cellColumn=values[2],
            cellStateValue=selector - 1,
            nativeRecordCount=len(records),
            nativeDefaultedArguments=4 - len(records),
            toolExecutionSemantics="metadata_only_native_effect_omitted",
        ),
    )


def _decode_ax_exact_envelope(code: bytes, offset: int, limit: int) -> dict[str, Any] | None:
    for envelope in AX_EXACT_ENVELOPES:
        end = offset + len(envelope)
        if end <= limit and code[offset:end] == envelope:
            subcommand = envelope[1]
            return _presentation_result(
                code,
                offset,
                end,
                "ax_presentation_control",
                subcommand,
                _presentation_operand(
                    subcommand,
                    "ax_presentation_control",
                    executionSelector=envelope[4],
                    toolExecutionSemantics="metadata_only_native_effect_omitted",
                ),
            )
    return None


def _decode_surface_dispatch(
    code: bytes, offset: int, limit: int, *, structural: bool = False
) -> dict[str, Any] | None:
    if offset + 3 > limit or code[offset : offset + 3] != bytes([0x0D, 0x0B, 0xFF]):
        return None
    record_list, end = decode_record_list(code, offset + 3, limit, structural=structural)
    records = record_list["records"]
    if any(record.get("type") != "expression_record" for record in records):
        return None
    mode = _literal_record_value(records[0]) if records else None
    shaped = mode is not None and (
        (mode == 0 and len(records) in (8, 9))
        or (mode == 1 and len(records) == 9)
        or (mode == 2 and len(records) == 5)
    )
    if mode == 13 and len(records) == 6:
        op, kind = "surface_display_refresh", "native_surface_display_refresh"
    elif shaped:
        op, kind = "surface_operation", "native_surface_operation"
    else:
        op, kind = "surface_dispatch_unresolved", "native_surface_dispatch"
    return _presentation_result(
        code,
        offset,
        end,
        op,
        11,
        _presentation_operand(
            11,
            kind,
            mode=-1 if mode is None else mode,
            modeSource="literal" if mode is not None else "native_record_default_unresolved",
            recordCount=len(records),
            expressions=[record["value"] for record in records],
        ),
    )


def _decode_ax_binding(code: bytes, offset: int, limit: int) -> dict[str, Any] | None:
    end = offset + len(AX_BINDING_PREFIX) + 1 + len(AX_BINDING_SUFFIX)
    if end > limit or code[offset : offset + len(AX_BINDING_PREFIX)] != AX_BINDING_PREFIX:
        return None
    column = code[offset + len(AX_BINDING_PREFIX)]
    suffix_start = offset + len(AX_BINDING_PREFIX) + 1
    if column > 2 or code[suffix_start : suffix_start + len(AX_BINDING_SUFFIX)] != AX_BINDING_SUFFIX:
        return None
    return _presentation_result(
        code,
        offset,
        end,
        "ax_presentation_binding",
        3,
        _presentation_operand(
            3,
            "ax_presentation_binding",
            executionSelector=0,
            consumerIndex=0,
            cellRow=0,
            cellColumn=column,
            bufferArgument="banked_i32[0][2]",
            toolExecutionSemantics="not_executed",
        ),
    )


def _decode_named_offset_mappings(raw: bytes) -> list[dict[str, Any]] | None:
    if not raw:
        return None
    cursor = 0
    mappings: list[dict[str, Any]] = []
    while cursor < len(raw):
        uses_i32_table = raw[cursor] == 0x5F
        if uses_i32_table:
            cursor += 1
            if cursor >= len(raw):
                return None
        letter = raw[cursor]
        if not 0x41 <= letter <= 0x5A:
            return None
        letter_index = letter - 0x41
        mappings.append(
            {
                "name": ("_" if uses_i32_table else "") + chr(letter),
                "letterIndex": letter_index,
                "table": "i32_relative_offset" if uses_i32_table else "u16_relative_offset",
                "slotOffset": (
                    0x20EC + letter_index * 4 if uses_i32_table else 0x2084 + letter_index * 2
                ),
            }
        )
        cursor += 1
    return mappings


def _decode_named_state_transfer(
    code: bytes, offset: int, limit: int, *, structural: bool = False
) -> dict[str, Any] | None:
    header = bytes([0x0D, 0x04, 0xFF, 0x02, 0x0D, 0xFF])
    if offset + len(header) > limit or code[offset : offset + len(header)] != header:
        return None
    record_list, end = decode_record_list(code, offset + len(header), limit, structural=structural)
    records = record_list["records"]
    if (
        len(records) != 2
        or records[0].get("type") != "expression_record"
        or records[1].get("type") != "string_record"
    ):
        return None
    raw = bytes.fromhex(records[1]["value"]["rawHex"])
    mappings = _decode_named_offset_mappings(raw)
    if mappings is None:
        return None
    return _presentation_result(
        code,
        offset,
        end,
        "named_state_transfer",
        4,
        _presentation_operand(
            4,
            "native_state_transfer",
            transferSelector=13,
            snapshotSelector=records[0]["value"],
            mappingString=raw.decode("ascii", "replace"),
            mappings=mappings,
            toolExecutionSemantics="not_executed",
        ),
    )


def _decode_named_marker(
    code: bytes,
    offset: int,
    limit: int,
    header: bytes,
    suffix: bytes,
    extension: str,
    op: str,
    subcommand: int,
    kind: str,
    **fields: Any,
) -> dict[str, Any] | None:
    if offset + len(header) > limit or code[offset : offset + len(header)] != header:
        return None
    name_start = offset + len(header)
    status, name, nul = _read_marker_name(code, name_start, limit, True)
    if status == "nomatch":
        return None
    if status == "unterminated":
        raise MesDecodeError(f"{op} filename at 0x{offset:x} is unterminated")
    if _extension(name) != extension or not is_safe_entry_name(name):
        return None
    suffix_start = nul + 1
    end = suffix_start + len(suffix)
    if end > limit:
        raise MesDecodeError(f"{op} envelope at 0x{offset:x} is truncated")
    if code[suffix_start:end] != suffix:
        return None
    return _presentation_result(
        code,
        offset,
        end,
        op,
        subcommand,
        _presentation_operand(
            subcommand,
            "resource_name",
            resourceKind=kind,
            name=name.rpartition(".")[0].upper() + "." + extension.upper(),
            sourceName=name,
            sourceOffset=name_start,
            **fields,
        ),
    )


def _decode_inline_script_execution(code: bytes, offset: int, limit: int) -> dict[str, Any] | None:
    header = bytes([0x0D, 0x08, 0xFF, 0x02])
    if offset + len(header) + 3 > limit or code[offset : offset + len(header)] != header:
        return None
    selector = code[offset + 4]
    if selector not in (2, 3) or code[offset + 5] != 0xFF or code[offset + 6] != 0x01:
        return None
    name_start = offset + 7
    status, name, nul = _read_marker_name(code, name_start, limit, True)
    if status == "nomatch":
        return None
    if status == "unterminated":
        raise MesDecodeError(f"inline script execution filename at 0x{offset:x} is unterminated")
    if _extension(name) != ("lib" if selector == 2 else "mes") or not is_safe_entry_name(name):
        return None
    end = nul + 2
    if end > limit:
        raise MesDecodeError(f"inline script execution envelope at 0x{offset:x} is truncated")
    if code[nul + 1] != 0:
        return None
    return _presentation_result(
        code,
        offset,
        end,
        "inline_script_execution",
        8,
        _presentation_operand(
            8,
            "resource_name",
            resourceKind="mes_script",
            name=name.upper(),
            sourceName=name,
            sourceOffset=name_start,
            executionSelector=selector,
            executionRole="library_bootstrap" if selector == 2 else "definition_bootstrap",
            toolExecutionSemantics="not_executed",
        ),
    )


def _decode_presentation_command(
    code: bytes, offset: int, limit: int, *, structural: bool = False
) -> dict[str, Any]:
    """The 0x0D tree, in the authority's order, ending in one statement separator."""
    for form, inherits_expression_mode in (
        (_decode_effect_dispatch, True),
        (_decode_ax_selected_cell_control, False),
        (_decode_ax_exact_envelope, False),
        (_decode_surface_dispatch, True),
        (_decode_ax_binding, False),
        (_decode_named_state_transfer, True),
        (_decode_inline_script_execution, False),
    ):
        matched = (
            form(code, offset, limit, structural=structural)
            if inherits_expression_mode else form(code, offset, limit)
        )
        if matched is not None:
            return matched
    ax_marker = _decode_named_marker(
        code,
        offset,
        limit,
        AX_MARKER_HEADER,
        AX_MARKER_SUFFIX,
        "ax",
        "ax_resource_marker",
        8,
        "ax_marker",
        executionSelector=0,
        dataArchiveIndex=0,
    )
    if ax_marker is not None:
        return ax_marker
    voice_marker = _decode_named_marker(
        code,
        offset,
        limit,
        VOICE_MARKER_HEADER,
        VOICE_MARKER_SUFFIX,
        "ogg",
        "voice_marker",
        7,
        "voice_marker",
        queueSelector=2,
        playbackSelector=3,
        toolPreviewSemantics="godot_only",
    )
    if voice_marker is not None:
        return voice_marker
    system_call = _decode_system_call(code, offset, limit, structural=structural)
    if system_call is not None:
        return system_call
    separator = finish_instruction(code, offset, offset + 1, "statement_separator", 0x0D, [], limit)
    return _align_bounded_native_stream(code, separator, limit)


NAME_INSERT_EXPRESSION_HEX = "00f90000a000e0f1400be0ff"
SYSTEM_CALL_CONSUMPTION = "system_call_selector_expression_and_record_list"


def _decode_system_call(
    code: bytes, offset: int, limit: int, *, structural: bool = False
) -> dict[str, Any] | None:
    """Command 0x0D as the engine reads it: one system call.

    A selector expression names the system function, then the same typed record
    list every structured command carries (tag 1 a NUL-terminated string, tag 2
    an expression, tag 0 the end) supplies its arguments. Every confirmed
    presentation form above is an instance of this grammar; this rule frames the
    rest, so the bytes after the selector are never read as further commands. An
    explicit empty selector (`0D FF`, two library bootstraps) selects function 0.
    Framing that fails here falls back to the byte-preserving separator.
    """
    cursor = offset + 1
    if cursor >= limit:
        return None
    try:
        if code[cursor] == 0xFF:
            selector: dict[str, Any] = {
                "type": "empty_selector", "value": 0, "sourceOffset": cursor, "endOffset": cursor + 1,
            }
            cursor += 1
        else:
            expression, cursor = _decode_expression_for_mode(code, cursor, limit, structural=structural)
            if not expression.get("valid", True):
                # A structural decode keeps a malformed expression's framing; a
                # selector that is not one value is not a call, so the bytes
                # keep their separator reading rather than claiming a false call.
                return None
            selector = {"type": "expression", "value": expression}
        records, end = decode_record_list(code, cursor, limit, structural=structural)
    except MesDecodeError:
        return None
    function = 0 if selector["type"] == "empty_selector" else literal_expression_value(selector)
    op, operands = _classify_system_call(offset, function, selector, records)
    result = finish_instruction(code, offset, end, op, 0x0D, operands)
    # The call owns its whole envelope; the character-stream probe that a bare
    # 0x0D otherwise carries does not describe it. The three calls the runner
    # and the presentation tools already name keep the shape they had.
    result.pop("nativeStreamProbe", None)
    if op == "system_call":
        result["nativeStreamConsumption"] = SYSTEM_CALL_CONSUMPTION
    else:
        result.pop("nativeStreamConsumption", None)
        result.pop("nativeHandlerFamily", None)
    if function is not None:
        result["systemFunction"] = function
    return result


def _classify_system_call(
    offset: int, function: int | None, selector: dict[str, Any], records: dict[str, Any]
) -> tuple[str, list[Any]]:
    """Name the calls the runner and the presentation tools already understand.

    Function 14 with the protagonist-name expression is the name insert the
    runner presents (formerly framed as a separator plus a 0x0E record), a lone
    string argument the literal insert; function 9 with one safe `.MMO` name is
    the presentation-9 marker (formerly framed as a separator plus a 0x09
    record). The marker keeps its single resource operand so its consumers are
    unchanged; every other call carries its selector and record list.
    """
    rows = records["records"]
    if function == 14 and len(rows) == 1:
        row = rows[0]
        if row["type"] == "expression_record" and row["value"].get("raw_hex") == NAME_INSERT_EXPRESSION_HEX:
            return "protagonist_name_insert", [records]
        if row["type"] == "string_record":
            return "literal_text_insert", [records]
    if function == 9 and len(rows) == 1 and rows[0]["type"] == "string_record":
        raw = bytes.fromhex(rows[0]["value"]["rawHex"])
        name = raw.decode("latin-1")
        checked_name = name.encode("ascii", "replace").decode("ascii")
        if len(raw) <= 255 and _extension(name) == "mmo" and is_safe_entry_name(checked_name):
            return "mmo_resource_marker", [
                _presentation_operand(
                    9,
                    "resource_name",
                    resourceKind="mmo_marker",
                    name=name,
                    sourceOffset=int(rows[0]["value"]["sourceOffset"]),
                    outerCommand=0x0D,
                    outerCommandSourceOffset=offset,
                    argumentCount=1,
                    toolPreviewSemantics="decoded_frame_without_native_surface_composition",
                )
            ]
    return "system_call", [selector, records]


def _align_bounded_native_stream(
    code: bytes, instruction: dict[str, Any], limit: int
) -> dict[str, Any]:
    """Promote only the separator whose handler-consumed run hides 0x0B/0x0C.

    A generic character-stream probe is not proof that the following bytes belong
    to the dispatch, so broad promotion would change valid instruction alignment.
    A 0x0B or 0x0C anywhere inside the consumed run is different: leaving those
    bytes as siblings exposes an internal payload byte as MES control flow.
    """
    probe = instruction.get("nativeStreamProbe", {})
    payload_end = int(probe.get("probeEndOffset", -1))
    instruction_end = int(instruction.get("endOffset", -1))
    if (
        int(probe.get("consumedByteCount", 0)) <= 0
        or payload_end <= instruction_end
        or payload_end > limit
    ):
        return instruction
    shadow = [
        candidate
        for candidate in range(instruction_end, payload_end)
        if code[candidate] in (0x0B, 0x0C)
    ]
    if instruction.get("commandId") != 0x0D or not shadow:
        return instruction
    start = int(instruction["sourceOffset"])
    aligned = dict(instruction)
    aligned["nativeDispatchInstructionEndOffset"] = instruction_end
    aligned["nativePayloadStartOffset"] = instruction_end
    aligned["nativePayloadEndOffset"] = payload_end
    aligned["nativePayloadByteLength"] = payload_end - instruction_end
    aligned["nativePayloadRawHex"] = code[instruction_end:payload_end].hex()
    aligned["nativePayloadBoundary"] = "bounded_byte_preserving_opaque_stream"
    aligned["nativeShadowControlOffsets"] = shadow
    aligned["endOffset"] = payload_end
    aligned["byteLength"] = payload_end - start
    aligned["rawHex"] = code[start:payload_end].hex()
    return aligned


def _decode_mmo_marker(code: bytes, offset: int, limit: int) -> dict[str, Any] | None:
    """0x09 directly after a 0x0D naming an MMO is the presentation-9 marker.

    Its two NULs are the filename terminator and the native argument-list
    terminator; any byte after them starts a separate instruction.
    """
    if (
        offset <= 0
        or code[offset - 1] != 0x0D
        or offset + 3 > limit
        or code[offset + 1] != 0xFF
        or code[offset + 2] != 0x01
    ):
        return None
    name_start = offset + 3
    status, name, nul = _read_marker_name(code, name_start, limit, False)
    if status != "ok":
        return None
    # The MMO form has no byte-level ASCII gate. Its shared GD name check
    # inspects to_ascii_buffer(), which replaces non-ASCII characters with '?',
    # while the marker retains the original Latin-1 name and payload bytes.
    checked_name = name.encode("ascii", "replace").decode("ascii")
    if _extension(name) != "mmo" or not is_safe_entry_name(checked_name):
        return None
    end = nul + 2
    if end > limit:
        raise MesDecodeError(
            f"presentation subcommand 9 MMO argument-list terminator at 0x{offset:x} is truncated"
        )
    if code[nul + 1] != 0:
        return None
    return finish_instruction(
        code,
        offset,
        end,
        "mmo_resource_marker",
        0x09,
        [
            _presentation_operand(
                9,
                "resource_name",
                resourceKind="mmo_marker",
                name=name,
                sourceOffset=name_start,
                outerCommand=0x0D,
                outerCommandSourceOffset=offset - 1,
                argumentCount=1,
                toolPreviewSemantics="decoded_frame_without_native_surface_composition",
            )
        ],
    )


def is_character_lead(value: int) -> bool:
    return 0x81 <= value <= 0x9F or 0xE0 <= value <= 0xEF or 0xFA <= value <= 0xFC


def probe_native_double_byte_stream(code: bytes, offset: int, limit: int) -> dict[str, Any]:
    """Walk CP932 lead/trail pairs and report where the run stops and why.

    The stop reason is what decides framing: a consumed NUL ends the run inside
    the instruction, while a deferred single-byte marker leaves the next byte to
    be decoded as its own command.
    """
    cursor = offset
    character_count = 0
    while cursor < limit:
        value = code[cursor]
        if value == 0:
            cursor += 1
            return {
                "startOffset": offset,
                "probeEndOffset": cursor,
                "consumedByteCount": cursor - offset,
                "characterCount": character_count,
                "stopOffset": cursor - 1,
                "stopReason": "nul_consumed",
            }
        if not is_character_lead(value):
            return {
                "startOffset": offset,
                "probeEndOffset": cursor,
                "consumedByteCount": cursor - offset,
                "characterCount": character_count,
                "stopOffset": cursor,
                "stopReason": "single_byte_marker_deferred",
            }
        if cursor + 1 >= limit:
            return {
                "startOffset": offset,
                "probeEndOffset": cursor,
                "consumedByteCount": cursor - offset,
                "characterCount": character_count,
                "stopOffset": cursor,
                "stopReason": "truncated_pair",
            }
        cursor += 2
        character_count += 1
    return {
        "startOffset": offset,
        "probeEndOffset": cursor,
        "consumedByteCount": cursor - offset,
        "characterCount": character_count,
        "stopOffset": cursor,
        "stopReason": "decode_limit",
    }


def _is_deferred_ff_boundary(code: bytes, probe: dict[str, Any], limit: int) -> bool:
    stop_offset = int(probe.get("stopOffset", -1))
    return (
        probe.get("stopReason") == "single_byte_marker_deferred"
        and 0 <= stop_offset < limit
        and code[stop_offset] == 0xFF
    )


def _cp932_operand(raw: bytes, source_offset: int) -> dict[str, Any]:
    return {"type": "cp932_bytes", "rawHex": raw.hex(), "sourceOffset": source_offset}


def _finish_native_double_byte_stream(
    code: bytes,
    start: int,
    payload_offset: int,
    decoded_end: int,
    op: str,
    command_id: int,
    operands: list[Any],
    limit: int,
) -> dict[str, Any]:
    result = finish_instruction(code, start, decoded_end, op, command_id, operands)
    probe = probe_native_double_byte_stream(code, payload_offset, limit)
    result["nativeHandlerFamily"] = "double_byte_character_stream_presentation"
    result["nativeStreamConsumption"] = "double_byte_pairs_until_nul_or_nonlead"
    result["nativeStreamProbe"] = probe
    result["nativeStreamProjectionMatch"] = (
        probe["stopReason"] in {"nul_consumed", "single_byte_marker_deferred"}
        and probe["probeEndOffset"] == decoded_end
    )
    return result


def _probe_native_single_byte_stream(code: bytes, offset: int, limit: int) -> dict[str, Any]:
    cursor = offset
    while cursor < limit:
        value = code[cursor]
        if value == 0:
            cursor += 1
            return {
                "startOffset": offset,
                "probeEndOffset": cursor,
                "consumedByteCount": cursor - offset,
                "stopOffset": cursor - 1,
                "stopReason": "nul_consumed",
            }
        if 0x81 <= value <= 0x9F or 0xE0 <= value <= 0xEF:
            return {
                "startOffset": offset,
                "probeEndOffset": cursor,
                "consumedByteCount": cursor - offset,
                "stopOffset": cursor,
                "stopReason": "double_byte_lead_deferred",
            }
        cursor += 1
    return {
        "startOffset": offset,
        "probeEndOffset": cursor,
        "consumedByteCount": cursor - offset,
        "stopOffset": cursor,
        "stopReason": "decode_limit",
    }


def finish_instruction(
    code: bytes,
    start: int,
    end: int,
    op: str,
    command_id: int,
    operands: list[Any],
    native_limit: int | None = None,
) -> dict[str, Any]:
    result = {
        "op": op,
        "commandId": command_id,
        "sourceOffset": start,
        "endOffset": end,
        "byteLength": end - start,
        "rawHex": code[start:end].hex(),
        "operands": operands,
    }
    if command_id in {0x02, 0x0D}:
        result["nativeHandlerFamily"] = "character_stream_presentation"
        result["nativeStreamConsumption"] = "single_byte_run_until_nul_or_primary_double_byte_lead"
        result["nativeStreamProbe"] = _probe_native_single_byte_stream(
            code,
            end,
            len(code) if native_limit is None else min(native_limit, len(code)),
        )
    return result


def decode_instruction(
    code: bytes, offset: int, limit: int, *, structural: bool = False
) -> dict[str, Any] | None:
    if offset >= limit:
        return None
    command_id = code[offset]
    cursor = offset + 1

    if command_id == 0x01:
        probe = probe_native_double_byte_stream(code, cursor, limit)
        if _is_deferred_ff_boundary(code, probe, limit):
            native_end = probe["probeEndOffset"]
            if probe["characterCount"] == 0:
                return _finish_native_double_byte_stream(
                    code, offset, cursor, cursor, "command_01", command_id, [], limit
                )
            return _finish_native_double_byte_stream(
                code,
                offset,
                cursor,
                native_end,
                "text",
                command_id,
                [_cp932_operand(code[cursor:native_end], cursor)],
                limit,
            )
        operand, end = decode_cstring(code, cursor, limit)
        return _finish_native_double_byte_stream(
            code, offset, cursor, end, "text", command_id, [operand], limit
        )

    if command_id > 0x1F:
        # A byte above the command range is either the lead of an inline CP932
        # run or a one-byte dispatcher default; 0xFF in that second role is the
        # separator every entry ends on.
        if is_character_lead(command_id):
            probe = probe_native_double_byte_stream(code, offset, limit)
            if _is_deferred_ff_boundary(code, probe, limit):
                native_end = probe["probeEndOffset"]
                return _finish_native_double_byte_stream(
                    code,
                    offset,
                    offset,
                    native_end,
                    "dispatcher_character_text",
                    command_id,
                    [_cp932_operand(code[offset:native_end], offset)],
                    limit,
                )
            operand, end = decode_cstring(code, cursor, limit)
            full = code[offset:end - 1]
            return _finish_native_double_byte_stream(
                code,
                offset,
                offset,
                end,
                "dispatcher_character_text",
                command_id,
                [_cp932_operand(full, offset)],
                limit,
            )
        op = "separator_ff" if command_id == 0xFF else "dispatcher_default_byte"
        return finish_instruction(code, offset, cursor, op, command_id, [], limit)

    if command_id in {0x14, 0x1C}:
        expression, cursor = _decode_expression_for_mode(code, cursor, limit, structural=structural)
        target, cursor = read_u32(code, cursor, limit)
        op = "bootstrap_transfer" if command_id == 0x14 else "library_register_skip"
        return finish_instruction(
            code,
            offset,
            cursor,
            op,
            command_id,
            [
                {"type": "expression", "value": expression},
                {"type": "code_offset", "value": target},
            ],
        )

    if command_id == 0x17:
        label_index, cursor = read_u32(code, cursor, limit)
        return finish_instruction(
            code,
            offset,
            cursor,
            "entry_label",
            command_id,
            [{"type": "entry_index", "value": label_index}],
        )

    if command_id == 0x18:
        expression, cursor = _decode_expression_for_mode(code, cursor, limit, structural=structural)
        return finish_instruction(
            code,
            offset,
            cursor,
            "jump_table",
            command_id,
            [{"type": "expression", "value": expression}],
        )

    if command_id == 0x0D:
        return _decode_presentation_command(code, offset, limit, structural=structural)

    if command_id == 0x1F:
        value, cursor = read_u32(code, cursor, limit)
        return finish_instruction(
            code,
            offset,
            cursor,
            "source_line_marker",
            command_id,
            [{"type": "source_line", "value": value}],
        )

    if command_id == 0x09:
        mmo_marker = _decode_mmo_marker(code, offset, limit)
        if mmo_marker is not None:
            return mmo_marker

    if command_id in PAIR_RUN_OPS:
        return _decode_pair_run(code, offset, cursor, limit, command_id, structural=structural)

    if command_id == 0x0B:
        # Condition then a u32 branch target. The former fixed grammar read five
        # raw bytes after the condition instead of four, so every 0x0B record was
        # framed one byte long.
        condition, cursor = _decode_expression_for_mode(code, cursor, limit, structural=structural)
        target, cursor = read_u32(code, cursor, limit)
        return finish_instruction(
            code,
            offset,
            cursor,
            "branch_if_not_true",
            command_id,
            [
                {"type": "condition", "value": condition},
                {"type": "code_offset", "value": target},
            ],
        )

    if command_id == 0x0C:
        target, cursor = read_u32(code, cursor, limit)
        return finish_instruction(
            code,
            offset,
            cursor,
            "continuation_transfer",
            command_id,
            [{"type": "code_offset", "value": target}],
        )

    if command_id in RECORD_LIST_COMMANDS:
        record_list, cursor = decode_record_list(code, cursor, limit, structural=structural)
        operands: list[dict[str, Any]] = [record_list]
        if command_id == 0x10:
            if cursor + 4 > limit:
                raise MesDecodeError(f"command 0x10 fields are truncated at 0x{cursor:x}")
            operands.append({"type": "u8_array", "value": list(code[cursor : cursor + 4])})
            cursor += 4
        result = finish_instruction(
            code, offset, cursor, RECORD_LIST_COMMANDS[command_id], command_id, operands
        )
        if command_id == 0x12:
            result["nativeHandlerFamily"] = "native_record_dispatch"
            result["nativeRecordConsumption"] = "typed_record_list_until_zero"
            result["nativeRecordCount"] = len(record_list["records"])
            result["nativeRecordTerminatorConsumed"] = True
            result["nativeRecordDispatchSemantics"] = "unresolved_not_executed"
        return result

    grammar = FIXED_GRAMMARS.get(command_id)
    if grammar is None:
        return None

    operands: list[dict[str, Any]] = []
    for item in grammar:
        if item == "b":
            if cursor >= limit:
                raise MesDecodeError(f"truncated u8 at 0x{cursor:x}")
            operands.append({"type": "u8", "value": code[cursor], "sourceOffset": cursor})
            cursor += 1
        else:
            expression, cursor = _decode_expression_for_mode(code, cursor, limit, structural=structural)
            operands.append({"type": "expression", "value": expression})
    op = {
        0x19: "internal_record_push",
        0x1A: "internal_record_pop",
    }.get(command_id, f"command_{command_id:02x}")
    return finish_instruction(code, offset, cursor, op, command_id, operands, limit)


def literal_expression_value(operand: dict[str, Any]) -> int | None:
    if operand.get("type") != "expression":
        return None
    ast = operand["value"].get("ast", {})
    if ast.get("type") == "literal":
        return int(ast["value"])
    return None


def decode_mes(data: bytes, source: dict[str, Any] | None = None) -> dict[str, Any]:
    container = parse_mes_container(data, source)
    cfg = seed_cfg(data, source)
    code_offset = container["header"]["codeOffset"]
    entry_offsets: list[int] = container["header"]["entryOffsets"]
    code = data[code_offset:]
    offset_to_entry = {offset: index for index, offset in enumerate(entry_offsets)}
    nodes: list[dict[str, Any]] = []
    edges: list[dict[str, Any]] = []
    decoded_bytes = 0

    for seed_node in cfg["nodes"]:
        start = seed_node["offset"]
        end = seed_node["endOffset"]
        cursor = start
        instructions: list[dict[str, Any]] = []
        error: str | None = None
        while cursor < end:
            try:
                instruction = decode_instruction(code, cursor, end)
            except MesDecodeError as exc:
                error = str(exc)
                break
            if instruction is None:
                break
            instructions.append(instruction)
            decoded_bytes += instruction["byteLength"]
            cursor = instruction["endOffset"]

            command_id = instruction["commandId"]
            if command_id in {0x14, 0x1C}:
                target_offset = int(instruction["operands"][1]["value"])
                target_index = offset_to_entry.get(target_offset)
                edges.append(
                    {
                        "type": "transfer" if command_id == 0x14 else "call_like",
                        "source": seed_node["id"],
                        "sourceOffset": instruction["sourceOffset"],
                        "target": None if target_index is None else f"entry_{target_index:04d}",
                        "targetOffset": target_offset,
                        "resolved": target_index is not None,
                        "commandId": command_id,
                    }
                )
            elif command_id == 0x18:
                target_index = literal_expression_value(instruction["operands"][0])
                resolved = target_index is not None and 0 <= target_index < len(entry_offsets)
                edges.append(
                    {
                        "type": "jump_table",
                        "source": seed_node["id"],
                        "sourceOffset": instruction["sourceOffset"],
                        "target": f"entry_{target_index:04d}" if resolved else None,
                        "targetIndex": target_index,
                        "resolved": resolved,
                        "commandId": command_id,
                    }
                )

        node = {
            "id": seed_node["id"],
            "offset": start,
            "endOffset": end,
            "instructions": instructions,
            "decodedEndOffset": cursor,
            "fullyDecoded": cursor == end,
        }
        if cursor < end:
            node["undecoded"] = {
                "offset": cursor,
                "size": end - cursor,
                "firstByte": code[cursor],
                "rawHexPrefix": code[cursor : min(end, cursor + 64)].hex(),
            }
        if error:
            node["decodeError"] = error
        nodes.append(node)

    return {
        "schema": "ai5_mes_partial_ir/v1",
        "source": container["source"],
        "codeSize": len(code),
        "decodedByteCount": decoded_bytes,
        "decodedRatio": decoded_bytes / len(code) if code else 1.0,
        "nodeCount": len(nodes),
        "nodes": nodes,
        "edges": edges,
        "diagnostics": [
            {
                "level": "info",
                "code": "partial_decoder",
                "message": "Decoding stops at handlers whose operand grammar is not yet confirmed.",
            }
        ],
    }


def main() -> None:
    parser = argparse.ArgumentParser(description="Decode confirmed fixed-shape CCommon MES commands into partial IR JSON.")
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
