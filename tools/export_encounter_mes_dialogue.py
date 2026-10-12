from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path
from typing import Any

from mes_archive_ir import load_archive_entry
from mes_basic_block_ir_v6 import decode_mes


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUTPUT = ROOT / "data" / "mes_dialogue" / "maki_fish_shop_affection_50.json"

EXPECTED_HASHES = {
    "D_INTRO.MES": "d2b20eb1d4343d98947b6c699ccc6d1e31ac41584d84a9cdcabe8b06b0a93337",
    "D_TALK50.MES": "8ad2ced46e2a43bac62999c564dcc981b1bfb71d31059fa85c899de23355e1bd",
    "D_OUTRO.MES": "7900463ea3eebecae1157bebbea637e0a2f4acacc6062242f73150e624f594c8",
}

# This is a narrow, reproducible trace through the ordinary fish-shop encounter,
# not a replacement for the full MES interpreter. Every displayed string is read
# from the named raw mes.arc record at export time.
TRACE = {
    "intro": {
        "entry": "D_INTRO.MES",
        "caller_offset": "0x0370",
        "state": {
            "global_u8[226]": 0,
            "global_u8[402]": 1,
            "global_u8[682]": 0,
            "banked_u16[0][212]": 50,
        },
        "lines": [
            [0x6C07, 0x6C2C],
            [0x6C72, 0x6C87],
        ],
    },
    "talk": {
        "entry": "D_TALK50.MES",
        "caller_offset": "0x040B",
        "state": {
            "global_u8[688]": 0,
            "global_u8[689]": 0,
            "global_u8[691]": 0,
            "banked_u16[0][212]": 50,
        },
        "lines": [
            [0x2F3A, 0x2F4F],
            [0x2FF1],
            [0x304D, 0x3062],
            [0x30B6],
            [0x313C, 0x3151],
            [0x318F],
        ],
    },
    "outro": {
        "entry": "D_OUTRO.MES",
        "caller_offset": "0x0637",
        "state": {
            "global_u8[226]": 0,
            "global_u8[350]": 0,
            "banked_u16[0][212]": 50,
        },
        "lines": [
            [0x0AD1, 0x0AE6],
            [0x0B10, 0x0B25],
        ],
    },
}

SPEAKER_PATTERN = re.compile(r"^［([^］]*)］：(.*)$", re.DOTALL)


def instruction_index(document: dict[str, Any]) -> dict[int, dict[str, Any]]:
    result: dict[int, dict[str, Any]] = {}
    for node in document["nodes"]:
        for instruction in node.get("instructions", []):
            result[int(instruction["sourceOffset"])] = instruction
    return result


def extract_text_record(
    entry: str, offset: int, instructions: dict[int, dict[str, Any]]
) -> tuple[str, dict[str, Any]]:
    instruction = instructions.get(offset)
    if instruction is None:
        raise ValueError(f"{entry}: no decoded instruction at code offset 0x{offset:04X}")
    if instruction.get("op") != "text":
        raise ValueError(
            f"{entry}: instruction at code offset 0x{offset:04X} is {instruction.get('op')}, not text"
        )
    operands = instruction.get("operands", [])
    if len(operands) != 1 or operands[0].get("type") != "cp932_string":
        raise ValueError(f"{entry}: text at 0x{offset:04X} has an unexpected operand shape")
    value = str(operands[0]["value"])
    raw = bytes.fromhex(str(operands[0]["rawHex"]))
    return value, {
        "offset": f"0x{offset:04X}",
        "end_offset": f"0x{int(instruction['endOffset']):04X}",
        "cp932_sha256": hashlib.sha256(raw).hexdigest(),
    }


def split_speaker(value: str) -> tuple[str, str, str]:
    match = SPEAKER_PATTERN.match(value)
    if not match:
        return "", "", value
    speaker = match.group(1)
    text = match.group(2)
    if speaker == "":
        return "protagonist", "主人公", text
    if speaker == "麻紀":
        return "maki", speaker, text
    return "source_named", speaker, text


def export_projection(archive: Path) -> dict[str, Any]:
    decoded: dict[str, tuple[dict[str, Any], dict[int, dict[str, Any]]]] = {}
    source_rows: list[dict[str, Any]] = []
    for entry in EXPECTED_HASHES:
        raw, source = load_archive_entry(archive, entry)
        actual_hash = str(source["sha256"])
        if actual_hash != EXPECTED_HASHES[entry]:
            raise ValueError(
                f"{entry}: authoritative hash mismatch; expected {EXPECTED_HASHES[entry]}, got {actual_hash}"
            )
        document = decode_mes(raw, source)
        if float(document.get("decodedRatio", 0.0)) != 1.0:
            raise ValueError(f"{entry}: decoder coverage is not 100%")
        decoded[entry] = (document, instruction_index(document))
        source_rows.append(
            {
                "entry": entry,
                "sha256": actual_hash,
                "size": int(source["size"]),
                "decoded_ratio": float(document["decodedRatio"]),
            }
        )

    phases: dict[str, list[dict[str, Any]]] = {}
    phase_traces: dict[str, dict[str, Any]] = {}
    for phase, definition in TRACE.items():
        entry = str(definition["entry"])
        instructions = decoded[entry][1]
        phases[phase] = []
        phase_traces[phase] = {
            "source_mes_file": entry,
            "caller_mes_file": "12C.MES",
            "caller_offset": definition["caller_offset"],
            "selected_state": definition["state"],
        }
        for offsets in definition["lines"]:
            fragments: list[str] = []
            records: list[dict[str, Any]] = []
            for offset in offsets:
                value, record = extract_text_record(entry, offset, instructions)
                fragments.append(value)
                records.append(record)
            speaker_id, speaker, text = split_speaker("".join(fragments))
            phases[phase].append(
                {
                    "speaker_id": speaker_id,
                    "speaker": speaker,
                    "text": text,
                    "source_mes_file": entry,
                    "caller_mes_file": "12C.MES",
                    "caller_offset": definition["caller_offset"],
                    "source_records": records,
                    "fidelity": "verbatim_cp932_text_records",
                }
            )

    return {
        "schema": "kakyu_mes_dialogue_projection/v1",
        "id": "maki_fish_shop_affection_50_trace_0",
        "source_kind": "authoritative_mes_arc_projection",
        "criteria": {
            "character_id": "maki",
            "location_id": "fish_shop",
            "affection_min": 41,
            "affection_max": 50,
        },
        "limitations": [
            "This file is a selected ordinary-encounter trace, not a full MES interpreter.",
            "Choice dispatch, arbitrary event flags, and alternate random variants are outside this projection.",
        ],
        "sources": source_rows,
        "trace": phase_traces,
        "phases": phases,
    }


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Export a local Godot dialogue projection from authoritative mes.arc records."
    )
    parser.add_argument("archive", type=Path, help="Path to the authoritative ELFIMAGE/mes.arc")
    parser.add_argument("-o", "--output", type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()

    archive = args.archive.resolve()
    output = args.output if args.output.is_absolute() else ROOT / args.output
    try:
        document = export_projection(archive)
    except (OSError, ValueError) as error:
        print(f"error: {error}", file=sys.stderr)
        raise SystemExit(1) from error

    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(document, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    line_count = sum(len(lines) for lines in document["phases"].values())
    print(f"exported {line_count} MES-backed lines to {output}")


if __name__ == "__main__":
    main()
