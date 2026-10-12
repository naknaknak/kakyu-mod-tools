from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

import mes_partial_decoder as base_decoder
from mes_archive_ir import load_archive_entry


ROOT = Path(__file__).resolve().parents[1]
BASE_DECODE_INSTRUCTION = base_decoder.decode_instruction


def decode_cp932(raw: bytes) -> tuple[str, str | None]:
    try:
        return raw.decode("cp932"), None
    except UnicodeDecodeError as exc:
        return raw.decode("cp932", errors="replace"), str(exc)


def decode_cstring(code: bytes, offset: int, limit: int) -> tuple[dict[str, Any], int]:
    terminator = code.find(b"\0", offset, limit)
    if terminator < 0:
        raise base_decoder.MesDecodeError(f"unterminated CP932 string at 0x{offset:x}")
    raw = code[offset:terminator]
    value, decode_error = decode_cp932(raw)
    operand: dict[str, Any] = {
        "type": "cp932_string",
        "value": value,
        "rawHex": raw.hex(),
        "sourceOffset": offset,
    }
    if decode_error:
        operand["decodeError"] = decode_error
    return operand, terminator + 1


def probe_native_double_byte_stream(code: bytes, offset: int, limit: int) -> dict[str, Any]:
    cursor = offset
    character_count = 0
    while cursor < limit:
        value = code[cursor]
        if value == 0:
            cursor += 1
            return {
                "startOffset": offset,
                "probeEndOffset": cursor,
                "characterCount": character_count,
                "stopOffset": cursor - 1,
                "stopReason": "nul_consumed",
            }
        if not (
            0x81 <= value <= 0x9F
            or 0xE0 <= value <= 0xEF
            or 0xFA <= value <= 0xFC
        ):
            return {
                "startOffset": offset,
                "probeEndOffset": cursor,
                "characterCount": character_count,
                "stopOffset": cursor,
                "stopReason": "single_byte_marker_deferred",
            }
        if cursor + 1 >= limit:
            return {
                "startOffset": offset,
                "probeEndOffset": cursor,
                "characterCount": character_count,
                "stopOffset": cursor,
                "stopReason": "truncated_double_byte_pair",
            }
        cursor += 2
        character_count += 1
    return {
        "startOffset": offset,
        "probeEndOffset": cursor,
        "characterCount": character_count,
        "stopOffset": cursor,
        "stopReason": "decode_limit",
    }


def finish_native_double_byte_stream(
    code: bytes,
    start: int,
    end: int,
    op: str,
    command_id: int,
    operands: list[Any],
    probe: dict[str, Any],
) -> dict[str, Any]:
    result = base_decoder.finish_instruction(code, start, end, op, command_id, operands)
    result["nativeHandlerFamily"] = "double_byte_character_stream"
    result["nativeStreamConsumption"] = "double_byte_pairs_until_nul_or_nonlead"
    result["nativeStreamProbe"] = probe
    result["nativeStreamProjectionMatch"] = (
        probe["stopReason"] in {"nul_consumed", "single_byte_marker_deferred"}
        and int(probe["probeEndOffset"]) == end
    )
    return result


def native_cp932_operand(raw: bytes, source_offset: int) -> dict[str, Any]:
    value, decode_error = decode_cp932(raw)
    operand: dict[str, Any] = {
        "type": "cp932_string",
        "value": value,
        "rawHex": raw.hex(),
        "sourceOffset": source_offset,
    }
    if decode_error:
        operand["decodeError"] = decode_error
    return operand


def is_deferred_ff_boundary(code: bytes, probe: dict[str, Any], limit: int) -> bool:
    stop_offset = int(probe["stopOffset"])
    return (
        probe["stopReason"] == "single_byte_marker_deferred"
        and 0 <= stop_offset < limit
        and code[stop_offset] == 0xFF
    )


def decode_record_list(code: bytes, offset: int, limit: int) -> tuple[dict[str, Any], int]:
    """Decode the zero-terminated record array built by CScript::0x43e800.

    Confirmed record tags are 1 (zero-terminated byte string) and 2 (RPN
    expression). The native parser consumes unknown non-zero tags without a
    payload, so they are retained losslessly instead of guessed.
    """
    cursor = offset
    records: list[dict[str, Any]] = []
    while True:
        if cursor >= limit:
            raise base_decoder.MesDecodeError(f"unterminated record list at 0x{offset:x}")
        tag_offset = cursor
        tag = code[cursor]
        cursor += 1
        if tag == 0:
            break
        if tag == 1:
            value, cursor = decode_cstring(code, cursor, limit)
            records.append(
                {
                    "tag": tag,
                    "type": "string_record",
                    "sourceOffset": tag_offset,
                    "value": value,
                }
            )
        elif tag == 2:
            expression, cursor = base_decoder.decode_expression(code, cursor, limit)
            records.append(
                {
                    "tag": tag,
                    "type": "expression_record",
                    "sourceOffset": tag_offset,
                    "value": expression,
                }
            )
        else:
            records.append(
                {
                    "tag": tag,
                    "type": "unknown_tag",
                    "sourceOffset": tag_offset,
                }
            )
    return {
        "type": "record_list",
        "sourceOffset": offset,
        "endOffset": cursor,
        "records": records,
    }, cursor


def decode_confirmed_mmo_marker(
    code: bytes,
    offset: int,
    limit: int,
) -> dict[str, Any] | None:
    if (
        offset <= 0
        or code[offset - 1] != 0x0D
        or offset + 3 > limit
        or code[offset : offset + 3] != b"\x09\xFF\x01"
    ):
        return None
    name_start = offset + 3
    terminator = code.find(b"\0", name_start, min(limit, name_start + 256))
    if terminator < 0 or terminator + 1 >= limit or code[terminator + 1] != 0:
        return None
    raw_name = code[name_start:terminator]
    if (
        not raw_name
        or any(value < 0x20 or value > 0x7E for value in raw_name)
        or b"/" in raw_name
        or b"\\" in raw_name
        or b":" in raw_name
        or not raw_name.lower().endswith(b".mmo")
    ):
        return None
    return base_decoder.finish_instruction(
        code,
        offset,
        terminator + 2,
        "mmo_resource_marker",
        0x09,
        [
            {
                "type": "resource_name",
                "resource_kind": "mmo_marker",
                "name": raw_name.decode("ascii"),
                "sourceOffset": name_start,
                "outerCommand": 0x0D,
                "outerCommandSourceOffset": offset - 1,
                "presentationSubcommand": 9,
            }
        ],
    )


def decode_instruction(code: bytes, offset: int, limit: int) -> dict[str, Any] | None:
    if offset >= limit:
        return None
    command_id = code[offset]
    cursor = offset + 1

    if command_id == 0x09:
        mmo_marker = decode_confirmed_mmo_marker(code, offset, limit)
        if mmo_marker is not None:
            return mmo_marker

    if command_id == 0x0D and code[offset : min(limit, offset + 3)] == b"\x0D\x0B\xFF":
        record_list, cursor = decode_record_list(code, offset + 3, limit)
        return base_decoder.finish_instruction(
            code,
            offset,
            cursor,
            "surface_dispatch_record_list",
            command_id,
            [record_list],
        )

    if command_id == 0x01:
        probe = probe_native_double_byte_stream(code, cursor, limit)
        if is_deferred_ff_boundary(code, probe, limit):
            native_end = int(probe["probeEndOffset"])
            if int(probe["characterCount"]) == 0:
                return finish_native_double_byte_stream(
                    code, offset, cursor, "command_01", command_id, [], probe
                )
            return finish_native_double_byte_stream(
                code,
                offset,
                native_end,
                "text",
                command_id,
                [native_cp932_operand(code[cursor:native_end], cursor)],
                probe,
            )
        operand, cursor = decode_cstring(code, cursor, limit)
        return base_decoder.finish_instruction(code, offset, cursor, "text", command_id, [operand])

    # The native dispatcher only indexes the 0x00..0x1f command jump table.
    # Other values take its character/default paths. Character-lead values use
    # the same zero-terminated stream handler as command 0x01; the generic path
    # uses the same operand-free handler as command 0x02.
    if command_id > 0x1F:
        is_character_lead = (
            0x81 <= command_id <= 0x9F
            or 0xE0 <= command_id <= 0xEF
            or 0xFA <= command_id <= 0xFC
        )
        if is_character_lead:
            probe = probe_native_double_byte_stream(code, offset, limit)
            if is_deferred_ff_boundary(code, probe, limit):
                native_end = int(probe["probeEndOffset"])
                return finish_native_double_byte_stream(
                    code,
                    offset,
                    native_end,
                    "dispatcher_character_text",
                    command_id,
                    [native_cp932_operand(code[offset:native_end], offset)],
                    probe,
                )
            operand, cursor = decode_cstring(code, cursor, limit)
            return base_decoder.finish_instruction(
                code,
                offset,
                cursor,
                "dispatcher_character_text",
                command_id,
                [
                    {"type": "u8", "value": command_id, "sourceOffset": offset},
                    operand,
                ],
            )
        op = "separator_ff" if command_id == 0xFF else "dispatcher_default_byte"
        operands = [] if command_id == 0xFF else [
            {"type": "u8", "value": command_id, "sourceOffset": offset}
        ]
        return base_decoder.finish_instruction(code, offset, cursor, op, command_id, operands)

    # These handlers each invoke the common structured-record reader once.
    if command_id in {0x0E, 0x0F, 0x10, 0x11, 0x12, 0x15, 0x1B, 0x1D}:
        record_list, cursor = decode_record_list(code, cursor, limit)
        operands: list[dict[str, Any]] = [record_list]
        if command_id == 0x10:
            raw_fields: list[int] = []
            for _ in range(4):
                if cursor >= limit:
                    raise base_decoder.MesDecodeError(f"truncated command 0x10 fields at 0x{cursor:x}")
                raw_fields.append(code[cursor])
                cursor += 1
            operands.append({"type": "u8_array", "value": raw_fields})
        names = {
            0x0E: "command_0e",
            0x0F: "command_0f",
            0x10: "command_10",
            0x11: "definition_invoke",
            0x12: "native_record_dispatch",
            0x15: "native_selection",
            0x1B: "command_1b",
            0x1D: "script_transfer",
        }
        op = names[command_id]
        if command_id == 0x0E and is_protagonist_name_insert(record_list):
            op = "protagonist_name_insert"
        return base_decoder.finish_instruction(code, offset, cursor, op, command_id, operands)

    return BASE_DECODE_INSTRUCTION(code, offset, limit)


def is_protagonist_name_insert(record_list: dict[str, Any]) -> bool:
    records = record_list.get("records", [])
    return (
        len(records) == 2
        and records[0].get("tag") == 0xFF
        and records[0].get("type") == "unknown_tag"
        and records[1].get("tag") == 0x02
        and records[1].get("type") == "expression_record"
        and records[1].get("value", {}).get("raw_hex") == "00f90000a000e0f1400be0ff"
    )


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
            "code": "structured_record_lists",
            "message": (
                "Commands 0x0e, 0x0f, 0x10, 0x11, 0x12, 0x15, 0x1b and 0x1d use the "
                "confirmed zero-terminated common record-list format."
            ),
        }
    )
    document["diagnostics"].append(
        {
            "level": "info",
            "code": "bounded_presentation_envelopes",
            "message": (
                "Confirmed outer command 0x0d/subcommand 0x09 MMO names and "
                "subcommand 0x0b typed surface record lists retain their full "
                "native presentation envelopes."
            ),
        }
    )
    document["diagnostics"].append(
        {
            "level": "info",
            "code": "dispatcher_default_bytes",
            "message": (
                "Bytes above 0x1f are decoded through the native dispatcher routes. "
                "Character-lead ranges share command 0x01's zero-terminated text handler; "
                "the generic route shares command 0x02's operand-free handler."
            ),
        }
    )
    return document


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Decode MES commands, CP932 text and confirmed common structured operands to JSON IR."
    )
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
