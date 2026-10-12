from __future__ import annotations

import argparse
from collections import Counter
import hashlib
import json
import re
import struct
import sys
from pathlib import Path
from typing import Any

from extract_kakyu_arc import read_entries
from mes_archive_ir import load_archive_entry
from mes_basic_block_ir_v6 import decode_mes


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUTPUT = ROOT / "data" / "mes_location_entries" / "all_maps.json"

MAP_LOCATION_COUNTS = {
    "MACHI": 43,
    "TRAIN": 2,
    "GROUND": 6,
    "FLOOR1": 8,
    "FLOOR2": 7,
    "FLOOR3": 7,
    "FLOOR4": 7,
    "FLOOR5": 8,
}

MOVEMENT_MAP_ENTRIES = {f"{map_id}.MES" for map_id in MAP_LOCATION_COUNTS} | {"TIME_C.MES"}
LOCATION_SCENE_PATTERN = re.compile(r"^(\d{2}[CM])", re.IGNORECASE)
TIME_BACKGROUND_BANDS = [
    {"before_hhmm": 600, "variant": 3, "source_offset": 0x02BD},
    {"before_hhmm": 1600, "variant": 1, "source_offset": 0x0300},
    {"before_hhmm": 1800, "variant": 2, "source_offset": 0x0343},
    {"before_hhmm": 2400, "variant": 3, "source_offset": 0x0386},
]


def instruction_index(document: dict[str, Any]) -> list[dict[str, Any]]:
    instructions: dict[int, dict[str, Any]] = {}
    for node in document.get("nodes", []):
        for instruction in node.get("instructions", []):
            instructions[int(instruction["sourceOffset"])] = instruction
    return [instructions[offset] for offset in sorted(instructions)]


def state_location_ids(expression: Any) -> set[int]:
    result: set[int] = set()
    if isinstance(expression, list):
        for value in expression:
            result.update(state_location_ids(value))
        return result
    if not isinstance(expression, dict):
        return result
    if expression.get("type") == "binary" and expression.get("op") == "equal":
        pairs = (
            (expression.get("lhs"), expression.get("rhs")),
            (expression.get("rhs"), expression.get("lhs")),
        )
        for state_ref, literal in pairs:
            if not isinstance(state_ref, dict) or not isinstance(literal, dict):
                continue
            index = state_ref.get("index", {})
            if (
                state_ref.get("type") == "state_ref"
                and state_ref.get("storage") == "state_u16"
                and isinstance(index, dict)
                and index.get("type") == "literal"
                and int(index.get("value", -1)) == 21
                and literal.get("type") == "literal"
            ):
                result.add(int(literal.get("value", -1)))
    for value in expression.values():
        result.update(state_location_ids(value))
    return result


def cp932_values(instruction: dict[str, Any]) -> list[dict[str, Any]]:
    result: list[dict[str, Any]] = []

    def visit(value: Any) -> None:
        if isinstance(value, list):
            for item in value:
                visit(item)
            return
        if not isinstance(value, dict):
            return
        if value.get("type") == "cp932_string":
            result.append(value)
        for child in value.values():
            visit(child)

    visit(instruction.get("operands", []))
    return result


def text_records(body: list[dict[str, Any]]) -> list[dict[str, Any]]:
    records: list[dict[str, Any]] = []
    for instruction in body:
        if instruction.get("op") != "text":
            continue
        for value in cp932_values(instruction):
            text = str(value.get("value", ""))
            if text in ("", "\uf8f3"):
                continue
            raw = bytes.fromhex(str(value.get("rawHex", "")))
            records.append(
                {
                    "text": text,
                    "offset": int(instruction["sourceOffset"]),
                    "end_offset": int(instruction["endOffset"]),
                    "cp932_sha256": hashlib.sha256(raw).hexdigest(),
                }
            )
    return records


def text_lines(body: list[dict[str, Any]], entry: str) -> list[dict[str, Any]]:
    records = text_records(body)

    lines: list[dict[str, Any]] = []
    pending_open: dict[str, Any] | None = None
    for record in records:
        value = str(record["text"])
        if value == "［":
            pending_open = record
            continue
        if pending_open is not None and value.startswith("］："):
            lines.append(
                {
                    "speaker_id": "protagonist",
                    "text": value.removeprefix("］："),
                    "source_mes_file": entry,
                    "source_records": [pending_open, record],
                    "fidelity": "verbatim_cp932_text_records",
                }
            )
            pending_open = None
            continue
        lines.append(
            {
                "speaker_id": "source_text",
                "text": value,
                "source_mes_file": entry,
                "source_records": [record],
                "fidelity": "verbatim_cp932_text_record",
            }
        )
        pending_open = None
    return lines


def called_entries(body: list[dict[str, Any]]) -> list[dict[str, Any]]:
    result: list[dict[str, Any]] = []
    for instruction in body:
        operation = str(instruction.get("op", ""))
        if operation not in ("command_0f", "command_0e"):
            continue
        for value in cp932_values(instruction):
            target = str(value.get("value", ""))
            if not target.lower().endswith(".mes"):
                continue
            result.append(
                {
                    "entry": target.upper(),
                    "call_source_offset": int(instruction["sourceOffset"]),
                    "relation": (
                        "script_call"
                        if operation == "command_0f"
                        else "map_dispatch_target_record"
                    ),
                }
            )
    return result


def location_scene_entry(calls: list[dict[str, Any]]) -> str:
    for call in calls:
        target = str(call.get("entry", "")).upper()
        if (
            call.get("relation") == "map_dispatch_target_record"
            and target not in MOVEMENT_MAP_ENTRIES
            and LOCATION_SCENE_PATTERN.match(target.removesuffix(".MES"))
        ):
            return target
    return ""


def continuation_target(instruction: dict[str, Any]) -> int | None:
    raw = bytes.fromhex(str(instruction.get("rawHex", "")))
    if instruction.get("op") != "command_0c" or len(raw) != 5:
        return None
    return struct.unpack_from("<I", raw, 1)[0]


def first_mes_target(instruction: dict[str, Any]) -> str:
    for value in cp932_values(instruction):
        target = str(value.get("value", ""))
        if target.lower().endswith(".mes"):
            return target.upper()
    return ""


def command_10_choice_index(instruction: dict[str, Any]) -> int | None:
    if instruction.get("op") != "command_10":
        return None
    operands = instruction.get("operands", [])
    if not operands or not isinstance(operands[0], dict):
        return None
    records = operands[0].get("records", [])
    for record in records:
        if not isinstance(record, dict) or record.get("type") != "expression_record":
            continue
        expression = record.get("value", {})
        if not isinstance(expression, dict) or not bool(expression.get("valid", False)):
            continue
        ast = expression.get("ast", {})
        if isinstance(ast, dict) and ast.get("type") == "literal":
            value = int(ast.get("value", -1))
            return value if value >= 0 else None
    return None


def choice_label_instruction(
    instructions: list[dict[str, Any]], command_index: int
) -> dict[str, Any] | None:
    for candidate in instructions[command_index + 1 : command_index + 5]:
        operation = str(candidate.get("op", ""))
        if operation == "text" and text_records([candidate]):
            return candidate
        if operation in {
            "branch_if_not_true",
            "bootstrap_transfer",
            "command_0c",
            "command_0f",
            "command_0e",
            "script_transfer",
            "command_10",
        }:
            break
    return None


def scene_intro_program(document: dict[str, Any], entry: str) -> dict[str, Any]:
    instructions = instruction_index(document)
    choice_labels: dict[int, tuple[int, dict[str, Any]]] = {}
    consumed_label_offsets: set[int] = set()
    for command_index, instruction in enumerate(instructions):
        choice_index = command_10_choice_index(instruction)
        if choice_index is None:
            continue
        label_instruction = choice_label_instruction(instructions, command_index)
        if label_instruction is None:
            continue
        command_offset = int(instruction["sourceOffset"])
        choice_labels[command_offset] = (choice_index, label_instruction)
        consumed_label_offsets.add(int(label_instruction["sourceOffset"]))

    program: list[dict[str, Any]] = []
    for instruction in instructions:
        operation = str(instruction.get("op", ""))
        source_offset = int(instruction["sourceOffset"])
        if source_offset in choice_labels:
            choice_index, label_instruction = choice_labels[source_offset]
            label_records = text_records([label_instruction])
            program.append(
                {
                    "op": "choice_option",
                    "source_offset": source_offset,
                    "result": choice_index + 1,
                    "label": "".join(str(record["text"]) for record in label_records),
                    "label_source_offset": int(label_instruction["sourceOffset"]),
                    "label_records": label_records,
                    "result_projection": "command_10_zero_based_index_plus_one",
                }
            )
            continue
        if source_offset in consumed_label_offsets:
            continue
        if operation == "text":
            records = text_records([instruction])
            if records:
                program.append(
                    {
                        "op": "text",
                        "source_offset": source_offset,
                        "records": records,
                    }
                )
            continue
        if operation == "branch_if_not_true":
            operands = instruction.get("operands", [])
            if len(operands) < 2:
                continue
            condition = operands[0].get("value", {})
            if not bool(condition.get("valid", False)):
                continue
            program.append(
                {
                    "op": "branch_if_not_true",
                    "source_offset": source_offset,
                    "condition": condition.get("ast", {}),
                    "false_target_offset": int(operands[1].get("value", -1)),
                }
            )
            continue
        if operation == "bootstrap_transfer":
            operands = instruction.get("operands", [])
            if len(operands) >= 2:
                program.append(
                    {
                        "op": "jump",
                        "source_offset": source_offset,
                        "target_offset": int(operands[1].get("value", -1)),
                        "relation": "bootstrap_entry",
                    }
                )
            continue
        target = continuation_target(instruction)
        if target is not None:
            program.append(
                {
                    "op": "jump",
                    "source_offset": source_offset,
                    "target_offset": target,
                    "relation": "continuation_transfer",
                }
            )
            continue
        if operation in ("command_0f", "command_0e"):
            target_entry = first_mes_target(instruction)
            if not target_entry:
                continue
            program.append(
                {
                    "op": "call" if operation == "command_0f" else "transfer",
                    "source_offset": source_offset,
                    "target_entry": target_entry,
                }
            )
    return {
        "source_mes_file": entry,
        "intro_anchor_offset": 0,
        "instructions": program,
        "stop_boundary": "first_called_or_transferred_mes",
    }


def background_groups(
    scene_entry: str, mmo_entries: dict[str, tuple[int, int]]
) -> dict[str, Any]:
    match = LOCATION_SCENE_PATTERN.match(scene_entry.removesuffix(".MES"))
    if match is None:
        return {}
    base = match.group(1).upper()

    def variants(prefix: str) -> dict[str, str]:
        result: dict[str, str] = {}
        exact = f"{prefix}.MMO"
        if exact in mmo_entries:
            result["default"] = exact
        for variant in (1, 2, 3):
            candidate = f"{prefix}_{variant}.MMO"
            if candidate in mmo_entries:
                result[str(variant)] = candidate
        return result

    groups: dict[str, dict[str, str]] = {}
    direct = variants(base)
    if direct:
        groups["default"] = direct
    for suffix in ("M", "S", "A"):
        seasonal = variants(base + suffix)
        if seasonal:
            groups[suffix] = seasonal

    evidence: list[dict[str, Any]] = []
    for group in groups.values():
        for resource in sorted(set(group.values())):
            archive_offset, size = mmo_entries[resource]
            evidence.append(
                {
                    "entry": resource,
                    "archive_offset": archive_offset,
                    "size": size,
                }
            )
    return {
        "asset_base": base,
        "variant_groups": groups,
        "time_bands": TIME_BACKGROUND_BANDS,
        "time_band_source": {
            "entry": "TIME_C.MES",
            "role": "projected_location_palette_suffix_from_confirmed_machine_palette_dispatch",
        },
        "season_suffix_projection": {
            "spring": "M",
            "summer": "S",
            "autumn_winter": "A",
        },
        "mmo_sources": evidence,
    }


def project_scene(
    archive: Path,
    scene_entry: str,
    mmo_entries: dict[str, tuple[int, int]],
) -> tuple[dict[str, Any], dict[str, Any]]:
    raw, source = load_archive_entry(archive, scene_entry)
    document = decode_mes(raw, source)
    program = scene_intro_program(document, scene_entry)
    background = background_groups(scene_entry, mmo_entries)
    if not background.get("variant_groups"):
        raise ValueError(f"{scene_entry}: no matching original MMO background family")
    if not any(item.get("op") == "text" for item in program["instructions"]):
        raise ValueError(f"{scene_entry}: no decoded source text in location intro program")
    projection = {
        "source_mes_file": scene_entry,
        "program": program,
        "background": background,
    }
    source_row = {
        "entry": scene_entry,
        "archive_offset": int(source["archiveOffset"]),
        "size": int(source["size"]),
        "sha256": str(source["sha256"]),
        "decoded_ratio": float(document.get("decodedRatio", 0.0)),
        "missing_actionable_target_count": int(
            document.get("controlFlow", {}).get("missingActionableBlockTargetCount", 0)
        ),
    }
    return projection, source_row


def duration_operands(body: list[dict[str, Any]]) -> list[dict[str, int]]:
    result: list[dict[str, int]] = []
    for instruction in body:
        if instruction.get("op") != "command_04":
            continue
        operands = instruction.get("operands", [])
        if len(operands) < 2 or int(operands[0].get("value", -1)) != 2:
            continue
        expression = operands[1].get("value", {}).get("ast", {})
        if expression.get("type") != "literal":
            continue
        minutes = int(expression.get("value", 0))
        if minutes <= 1 or minutes > 240:
            continue
        result.append(
            {
                "minutes": minutes,
                "source_offset": int(instruction["sourceOffset"]),
            }
        )
    return result


def project_map(
    archive: Path, map_id: str, location_count: int
) -> tuple[dict[str, Any], dict[str, Any]]:
    entry = f"{map_id}.MES"
    raw, source = load_archive_entry(archive, entry)
    document = decode_mes(raw, source)
    instructions = instruction_index(document)
    by_offset = {int(item["sourceOffset"]): item for item in instructions}
    locations: dict[str, Any] = {
        str(location_id): {"source_event_id": location_id, "branches": []}
        for location_id in range(location_count)
    }

    dispatcher_offsets: list[int] = []
    for instruction in instructions:
        if instruction.get("op") != "branch_if_not_true":
            continue
        operands = instruction.get("operands", [])
        if len(operands) < 2:
            continue
        condition = operands[0].get("value", {})
        expression = condition.get("ast", {})
        ids = state_location_ids(expression)
        ids = {location_id for location_id in ids if 0 <= location_id < location_count}
        if not ids:
            continue
        false_target = int(operands[1].get("value", -1))
        true_target = int(instruction.get("endOffset", -1))
        if false_target <= true_target or false_target > int(document.get("codeSize", 0)):
            continue
        body = [
            candidate
            for candidate in instructions
            if true_target <= int(candidate["sourceOffset"]) < false_target
        ]
        lines = text_lines(body, entry)
        calls = called_entries(body)
        durations = duration_operands(body)
        scene_entry = location_scene_entry(calls)
        for location_id in sorted(ids):
            branch = {
                "condition_source_offset": int(instruction["sourceOffset"]),
                "body_start_offset": true_target,
                "body_end_offset": false_target,
                "condition": expression,
                "condition_raw_hex": str(condition.get("raw_hex", "")),
                "executable": bool(condition.get("valid", False)),
                "diagnostics": condition.get("diagnostics", []),
                "lines": lines,
                "called_entries": calls,
                "location_scene_entry": scene_entry,
                "duration_operands": durations,
            }
            locations[str(location_id)]["branches"].append(branch)
            dispatcher_offsets.append(int(instruction["sourceOffset"]))

    missing = [
        location_id
        for location_id in range(location_count)
        if not locations[str(location_id)]["branches"]
    ]
    if missing:
        raise ValueError(f"{entry}: no state_u16[21] branches for location IDs {missing}")

    explicit_costs = [
        int(duration["minutes"])
        for location in locations.values()
        for branch in location["branches"]
        for duration in branch["duration_operands"]
    ]
    default_time_cost = Counter(explicit_costs).most_common(1)[0][0] if explicit_costs else 0
    for location in locations.values():
        for branch in location["branches"]:
            durations = branch.pop("duration_operands")
            branch_costs = sorted({int(item["minutes"]) for item in durations})
            if len(branch_costs) > 1:
                raise ValueError(
                    f"{entry}: conflicting duration operands in branch "
                    f"0x{int(branch['condition_source_offset']):04X}: {branch_costs}"
                )
            branch["time_cost_minutes"] = branch_costs[0] if branch_costs else default_time_cost
            branch["time_cost_source"] = (
                "inline_duration_operand"
                if branch_costs
                else "owning_map_recurring_duration_default"
            )
            branch["time_cost_source_offsets"] = [
                int(item["source_offset"]) for item in durations
            ]

    map_projection = {
        "map_id": map_id,
        "source_mes_file": entry,
        "dispatcher_condition_offset": min(dispatcher_offsets),
        "location_count": location_count,
        "default_time_cost_minutes": default_time_cost,
        "locations": locations,
    }
    source_row = {
        "entry": entry,
        "archive_offset": int(source["archiveOffset"]),
        "size": int(source["size"]),
        "sha256": str(source["sha256"]),
        "decoded_ratio": float(document.get("decodedRatio", 0.0)),
        "missing_actionable_target_count": int(
            document.get("controlFlow", {}).get("missingActionableBlockTargetCount", 0)
        ),
    }
    return map_projection, source_row


def export_projection(archive: Path) -> dict[str, Any]:
    maps: dict[str, Any] = {}
    sources: list[dict[str, Any]] = []
    for map_id, location_count in MAP_LOCATION_COUNTS.items():
        projection, source = project_map(archive, map_id, location_count)
        maps[map_id] = projection
        sources.append(source)
    image_archive = archive.with_name("mmo.arc")
    if not image_archive.is_file():
        raise ValueError(f"authoritative image archive is missing: {image_archive}")
    mmo_entries = {
        name.upper(): (offset, size)
        for name, offset, size in read_entries(image_archive)
    }
    scene_entries = sorted(
        {
            str(branch.get("location_scene_entry", ""))
            for map_projection in maps.values()
            for location in map_projection["locations"].values()
            for branch in location["branches"]
            if str(branch.get("location_scene_entry", ""))
        }
    )
    scenes: dict[str, Any] = {}
    for scene_entry in scene_entries:
        scene_projection, source = project_scene(archive, scene_entry, mmo_entries)
        scenes[scene_entry] = scene_projection
        sources.append(source)
    return {
        "schema_version": "kakyu_mes_map_location_entries/v2",
        "source_kind": "authoritative_mes_arc_projection",
        "limitations": [
            "Called location MES intro execution stops before the first called or transferred MES.",
            "Recognized command_10 literal indices followed by text are projected as resumable entrance choices.",
            "Location background numeric suffix selection projects TIME_C.MES machine palette bands onto confirmed sibling MMO variants.",
            "Season-letter background groups are a presentation projection; every selected filename remains an original mmo.arc entry.",
        ],
        "sources": sources,
        "maps": maps,
        "scenes": scenes,
    }


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Export all movement-map location entry branches from authoritative mes.arc."
    )
    parser.add_argument("archive", type=Path, help="Path to authoritative ELFIMAGE/mes.arc")
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
    scene_directory = output.parent / "scenes"
    scene_directory.mkdir(parents=True, exist_ok=True)
    scene_index: dict[str, Any] = {}
    for scene_entry, scene_projection in document["scenes"].items():
        scene_filename = scene_entry.removesuffix(".MES").lower() + ".json"
        scene_output = scene_directory / scene_filename
        scene_document = {
            "schema_version": "kakyu_mes_location_scene/v2",
            "source_kind": "authoritative_mes_arc_projection",
            "scene": scene_projection,
        }
        scene_output.write_text(
            json.dumps(scene_document, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )
        scene_index[scene_entry] = {
            "source_mes_file": scene_entry,
            "projection_file": f"scenes/{scene_filename}",
        }
    document["scenes"] = scene_index
    output.write_text(json.dumps(document, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    location_count = sum(len(item["locations"]) for item in document["maps"].values())
    branch_count = sum(
        len(location["branches"])
        for item in document["maps"].values()
        for location in item["locations"].values()
    )
    print(f"exported {location_count} locations / {branch_count} MES branches to {output}")


if __name__ == "__main__":
    main()
