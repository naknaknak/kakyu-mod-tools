"""Project the shared Python framing decoder into the instruction-v45 contract.

The framing parser remains shared with its existing audit consumers. This view
adds the authority's field shapes and evidence; it never infers a boundary from
an older CFG projection. Region failures retain one byte-preserving opaque tail
in the handoff builder instead of decoding inside the failed record.
"""

from __future__ import annotations

import re
from typing import Any

import mes_partial_decoder as framing
from mes_expression import parse_expression_ir
from mes_presentation_ir import enrich_presentation


INSTRUCTION_SCHEMA = "ai5_mes_instruction/v45"
_CAMEL_BOUNDARY = re.compile(r"(?<=[a-z0-9])(?=[A-Z])")


def _canonical_value(value: Any, code: bytes, *, structural: bool = False) -> Any:
    if isinstance(value, list):
        return [_canonical_value(child, code, structural=structural) for child in value]
    if not isinstance(value, dict):
        return value
    if "ast" in value and "offset" in value and "end_offset" in value:
        return parse_expression_ir(code, value["offset"], value["end_offset"], structural=structural)
    result = {
        _CAMEL_BOUNDARY.sub("_", key).lower(): _canonical_value(child, code, structural=structural)
        for key, child in value.items()
    }
    if result.get("type") == "cp932_bytes":
        result["raw_bytes"] = bytes.fromhex(result["raw_hex"])
    return result


def _error(message: str, offset: int) -> dict[str, Any]:
    return {"ok": False, "error": message, "source_offset": offset}


def _pair_start(code: bytes, offset: int, limit: int, *, structural: bool = False) -> int:
    header = framing.PAIR_RUN_OPS[code[offset]][0]
    if header in ("u8", "u16"):
        return offset + (2 if header == "u8" else 3)
    expression = parse_expression_ir(code, offset + 1, limit, structural=structural)
    return int(expression["end_offset"]) + (1 if header == "e+b" else 0)


def _instruction_error(
    code: bytes, offset: int, limit: int, failure: framing.MesDecodeError, *, structural: bool = False
) -> dict[str, Any]:
    """Keep the shared parser's failure, with the authority's diagnostic context."""
    command = code[offset]
    text = str(failure)
    source_offset = offset
    expression_error = getattr(failure.__cause__, "ir_error", None)
    if expression_error is not None:
        message = str(expression_error["error"])
        expression_start = int(expression_error.get("offset", len(code)))
        if command in framing.RECORD_LIST_COMMANDS or command == 0x0D:
            message = f"Record-list expression: {message}"
            source_offset = expression_start - 1
        elif command in framing.PAIR_RUN_OPS:
            header = framing.PAIR_RUN_OPS[command][0]
            if header in ("e", "e+b") and (
                expression_start == offset + 1 or offset + 1 >= limit
            ):
                field = "expression" if command == 0x05 else "destination"
            else:
                field = "expression pair"
                source_offset = _pair_start(code, offset, limit, structural=structural)
            message = f"Command 0x{command:02X} {field}: {message}"
        else:
            field = "condition" if command == 0x0B else "expression"
            message = f"Command 0x{command:02X} {field}: {message}"
    elif text.startswith("CP932 byte string"):
        message = "CP932 byte string is unterminated."
        source_offset = int(re.search(r"at 0x([0-9a-f]+)", text)[1], 16)
    elif text.startswith("structured record list"):
        message = "Structured record list is unterminated."
        source_offset = int(re.search(r"at 0x([0-9a-f]+)", text)[1], 16)
    elif text.startswith("truncated u32"):
        field = "u32" if command in (0x17, 0x1F) else "target"
        message = f"Command 0x{command:02X} {field} is truncated."
    elif text.startswith("truncated u8"):
        message = f"Command 0x{command:02X} u8 is truncated."
    elif "continuation is truncated" in text:
        message = f"Command 0x{command:02X} continuation is truncated."
        source_offset = _pair_start(code, offset, limit, structural=structural)
    elif "index is truncated" in text:
        field = {0x03: "index", 0x04: "start index", 0x09: "start slot", 0x16: "selector"}[command]
        message = f"Command 0x{command:02X} {field} is truncated."
    elif "bank is truncated" in text:
        message = f"Command 0x{command:02X} bank is truncated."
    elif "command 0x10 fields" in text:
        message = "Command 0x10 fields are truncated."
    elif text.startswith("AX selected-cell control"):
        message = re.sub(r" at 0x[0-9a-f]+", "", text) + "."
    elif "filename" in text or "envelope" in text:
        label = (
            "Voice marker" if text.startswith("voice_marker")
            else "AX marker" if text.startswith("ax_resource_marker")
            else "Inline script execution"
        )
        message = label + (" filename is unterminated." if "filename" in text else " envelope is truncated.")
    elif "MMO" in text:
        message = "Presentation subcommand 9 MMO argument-list terminator is truncated."
    else:
        # Unknown transport diagnostics are not a claim of authority parity.
        message = text

    if command == 0x0D:
        prefix = code[offset:offset + 3]
        if prefix == b"\x0d\x06\xff":
            message = f"Effect typed-record dispatch: {message}"
            source_offset = offset
        elif prefix == b"\x0d\x03\xff" and not message.startswith("AX selected-cell control"):
            message = f"AX selected-cell control: {message}"
            source_offset = offset
    return _error(message, source_offset)


def _script_target(operand: dict[str, Any]) -> str:
    records = operand.get("records", [])
    if len(records) != 1 or records[0].get("type") != "string_record":
        return ""
    raw = records[0]["value"]["raw_bytes"]
    if not raw.isascii():
        return ""
    target = raw.decode("ascii")
    return target if framing.is_safe_entry_name(target) and target.lower().endswith(".mes") else ""


def _decode_instruction_ir(
    code: bytes, offset: int, limit: int, *, aligned: bool, structural: bool = False
) -> dict[str, Any]:
    end_limit = len(code) if limit < 0 else min(limit, len(code))
    if offset < 0 or offset >= end_limit:
        return _error("Instruction offset is outside the decode range.", offset)
    try:
        parsed = framing.decode_instruction(code, offset, end_limit, structural=structural)
    except framing.MesDecodeError as failure:
        return _instruction_error(code, offset, end_limit, failure, structural=structural)
    if parsed is None:
        return _error(f"Unsupported structural opcode 0x{code[offset]:02X}.", offset)
    return _canonical_instruction(parsed, code, offset, end_limit, aligned=aligned, structural=structural)


def _canonical_instruction(
    parsed: dict[str, Any], code: bytes, offset: int, end_limit: int,
    *, aligned: bool, structural: bool = False,
) -> dict[str, Any]:
    """One canonical projection for ordinary instructions and marker-only scans."""
    result = {"ok": True, "schema": INSTRUCTION_SCHEMA, **_canonical_value(parsed, code, structural=structural)}
    command = code[offset]
    operands = result["operands"]
    if command in (0x05, 0x16):
        operands[0]["type"] = "expression" if command == 0x05 else "u8"
        result["operands"] = [operands[0], *operands[1]["pairs"]]
    if command in (0x0E, 0x0F):
        target = _script_target(operands[0])
        records = operands[0]["records"]
        if target:
            result["script_target"] = target
            result["op"] = "script_handoff_marker" if command == 0x0E else "script_dispatch"
        elif command == 0x0E:
            if (
                len(records) == 2
                and records[0].get("tag") == 0xFF
                and records[0].get("type") == "unknown_tag"
                and records[1].get("type") == "expression_record"
                and records[1]["value"].get("raw_hex") == "00f90000a000e0f1400be0ff"
            ):
                result["op"] = "protagonist_name_insert"
            elif len(records) == 1 and records[0].get("type") == "string_record":
                result["op"] = "literal_text_insert"
    if command == 0x13 and operands[0]["value"] == 0xFF:
        result["op"] = "message_cursor_no_advance"
    if command > 0x1F and not framing.is_character_lead(command):
        result["native_handler_family"] = "character_stream_presentation"
        result["native_stream_consumption"] = "single_byte_run_until_nul_or_primary_double_byte_lead"
        result["native_stream_probe"] = _canonical_value(
            framing._probe_native_single_byte_stream(code, result["end_offset"], end_limit), code
        )
    result = enrich_presentation(result, code, end_limit)
    if structural and _contains_non_strict_expression(result["operands"]):
        result["structural_only"] = True
    if not aligned and "native_dispatch_instruction_end_offset" in result:
        end = result.pop("native_dispatch_instruction_end_offset")
        for key in tuple(result):
            if key.startswith("native_payload_") or key == "native_shadow_control_offsets":
                del result[key]
        result.update(end_offset=end, byte_length=end - offset, raw_hex=code[offset:end].hex())
    return result


def _contains_non_strict_expression(value: Any) -> bool:
    pending = [value]
    while pending:
        child = pending.pop()
        if isinstance(child, dict):
            if "ast" in child and "valid" in child and not child["valid"]:
                return True
            pending.extend(child.values())
        elif isinstance(child, list):
            pending.extend(child)
    return False


def decode_instruction_ir(
    code: bytes, offset: int, limit: int = -1, *, structural: bool = False
) -> dict[str, Any]:
    """An instruction-v45 view of GD decode_at or decode_at_structural."""
    return _decode_instruction_ir(code, offset, limit, aligned=False, structural=structural)


def decode_resource_marker_ir(code: bytes, offset: int, limit: int = -1) -> dict[str, Any]:
    """The marker-only decode_resource_marker_at contract, including no-match.

    A bounded resource envelope may occur outside strict indexed instructions.
    Scan only the existing marker parsers, without treating its surrounding
    bytes as ordinary instructions or trying unrelated presentation forms.
    """
    end_limit = len(code) if limit < 0 else min(limit, len(code))
    if offset < 0 or offset >= end_limit:
        return {"matched": False}
    parsed = None
    try:
        if code[offset] == 0x0D:
            parsed = framing._decode_named_marker(
                code, offset, end_limit,
                framing.AX_MARKER_HEADER, framing.AX_MARKER_SUFFIX,
                "ax", "ax_resource_marker", 8, "ax_marker",
                executionSelector=0, dataArchiveIndex=0,
            )
            if parsed is None:
                parsed = framing._decode_named_marker(
                    code, offset, end_limit,
                    framing.VOICE_MARKER_HEADER, framing.VOICE_MARKER_SUFFIX,
                    "ogg", "voice_marker", 7, "voice_marker",
                    queueSelector=2, playbackSelector=3, toolPreviewSemantics="godot_only",
                )
            if parsed is None:
                parsed = framing._decode_inline_script_execution(code, offset, end_limit)
            if parsed is None:
                # The MMO marker is the system call 0D 09 FF 01 <name> 00 00, one
                # record from the 0x0D; the marker-only scan claims it here so it
                # aligns with the strict instruction index.
                system_call = framing._decode_system_call(code, offset, end_limit)
                if system_call is not None and system_call.get("op") == "mmo_resource_marker":
                    parsed = system_call
        elif code[offset] == 0x09:
            parsed = framing._decode_mmo_marker(code, offset, end_limit)
    except framing.MesDecodeError as failure:
        return {"matched": True, "result": _instruction_error(code, offset, end_limit, failure)}
    if parsed is None:
        return {"matched": False}
    return {
        "matched": True,
        "result": _canonical_instruction(parsed, code, offset, end_limit, aligned=False),
    }


def decode_region_ir(
    code: bytes, start: int, end: int, max_instructions: int = 100000, *, structural: bool = False
) -> dict[str, Any]:
    """Aligned strict/structural decoding with the native shadow boundary."""
    if start < 0 or end < start or end > len(code):
        return _error("Instruction region is outside bytecode.", start)
    instructions: list[dict[str, Any]] = []
    cursor = start
    while cursor < end and len(instructions) < max_instructions:
        instruction = _decode_instruction_ir(code, cursor, end, aligned=True, structural=structural)
        if not instruction["ok"]:
            return {"ok": False, "error": instruction["error"], "decoded_end_offset": cursor, "instructions": instructions}
        instructions.append(instruction)
        cursor = instruction["end_offset"]
    result = {"ok": cursor == end, "decoded_end_offset": cursor, "instructions": instructions}
    if cursor < end:
        result["error"] = "Instruction region exceeded its step limit."
    return result
