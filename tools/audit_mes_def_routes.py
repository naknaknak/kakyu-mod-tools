"""Audit exact bounded DEF sequences that terminate at shared routine 40.

The audit deliberately reports structure only. It does not export option text,
execute the shared routine, or infer a native input rule from a recurring byte
pattern.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
from typing import Any

import mes_basic_block_ir_v6
from extract_kakyu_arc import read_entries
from payload_values import sha256_file as _sha256_file


SCHEMA = "kakyu_mes_def_route_audit/v4"
SKIPPABLE_COMMANDS = {0x0D, 0x17, 0x1F}
RESULT_MARKER_COMMANDS = {0x1F}


def _literal_record(instruction: dict[str, Any]) -> int | None:
    operands = instruction.get("operands", [])
    if not operands or operands[0].get("type") != "record_list":
        return None
    records = operands[0].get("records", [])
    if len(records) != 1 or records[0].get("type") != "expression_record":
        return None
    value = records[0].get("value", {})
    ast = value.get("ast", {})
    if not value.get("valid", False) or ast.get("type") != "literal":
        return None
    return int(ast["value"])


def _u32_target(instruction: dict[str, Any]) -> int | None:
    operands = instruction.get("operands", [])
    if len(operands) != 2 or operands[1].get("type") != "u8_array":
        return None
    raw = operands[1].get("value", [])
    if len(raw) != 4 or any(int(value) < 0 or int(value) > 0xFF for value in raw):
        return None
    return int.from_bytes(bytes(int(value) for value in raw), "little")


def _decode_definition_body(code: bytes, start: int, target: int) -> dict[str, Any]:
    if target <= start or target > len(code):
        return {"ok": False, "reason": "target_out_of_range"}
    cursor = start
    message_count = 0
    while cursor < target:
        try:
            instruction = mes_basic_block_ir_v6.decode_instruction(code, cursor, target)
        except (IndexError, ValueError) as error:
            return {"ok": False, "reason": f"body_decode_error:{error}"}
        if instruction is None:
            return {"ok": False, "reason": "body_decode_none"}
        command_id = int(instruction["commandId"])
        end_offset = int(instruction["endOffset"])
        if end_offset <= cursor or end_offset > target:
            return {"ok": False, "reason": "body_decode_range"}
        if command_id == 0x01:
            operands = instruction.get("operands", [])
            if (
                len(operands) != 1
                or operands[0].get("type") != "cp932_string"
                or not operands[0].get("rawHex")
                or operands[0].get("decodeError")
            ):
                return {"ok": False, "reason": "body_invalid_cp932"}
            message_count += 1
            cursor = end_offset
            continue
        if command_id == 0x00 and end_offset == target and message_count > 0:
            return {"ok": True, "message_count": message_count}
        return {"ok": False, "reason": "body_not_text_return"}
    return {"ok": False, "reason": "body_missing_return"}


def _unique_instructions(document: dict[str, Any]) -> tuple[dict[int, dict[str, Any]], int]:
    by_offset: dict[int, dict[str, Any]] = {}
    conflicts = 0
    for node in document.get("nodes", []):
        for instruction in node.get("instructions", []):
            offset = int(instruction["sourceOffset"])
            previous = by_offset.get(offset)
            if previous is not None:
                if previous.get("rawHex") != instruction.get("rawHex"):
                    conflicts += 1
                continue
            by_offset[offset] = instruction
    return by_offset, conflicts


def _skip_markers(by_offset: dict[int, dict[str, Any]], offset: int) -> int:
    seen: set[int] = set()
    cursor = offset
    while cursor not in seen:
        seen.add(cursor)
        instruction = by_offset.get(cursor)
        if instruction is None or int(instruction["commandId"]) not in SKIPPABLE_COMMANDS:
            break
        cursor = int(instruction["endOffset"])
    return cursor


def _skip_result_markers(by_offset: dict[int, dict[str, Any]], offset: int) -> int:
    seen: set[int] = set()
    cursor = offset
    while cursor not in seen:
        seen.add(cursor)
        instruction = by_offset.get(cursor)
        if instruction is None or int(instruction["commandId"]) not in RESULT_MARKER_COMMANDS:
            break
        cursor = int(instruction["endOffset"])
    return cursor


def _literal_ast_value(ast: dict[str, Any]) -> int | None:
    if ast.get("type") != "literal":
        return None
    return int(ast.get("value", 0))


def _state_u16_index(ast: dict[str, Any]) -> int | None:
    if ast.get("type") != "state_ref" or ast.get("storage") != "state_u16":
        return None
    index = ast.get("index", {})
    if not isinstance(index, dict):
        return None
    return _literal_ast_value(index)


def _state_u16_equal_literal_branch(instruction: dict[str, Any]) -> dict[str, int] | None:
    if int(instruction.get("commandId", -1)) != 0x0B:
        return None
    operands = instruction.get("operands", [])
    if len(operands) != 2 or operands[0].get("type") != "condition":
        return None
    condition = operands[0].get("value", {})
    ast = condition.get("ast", {}) if isinstance(condition, dict) else {}
    if ast.get("type") != "binary" or ast.get("op") != "equal":
        return None
    left = ast.get("lhs", {})
    right = ast.get("rhs", {})
    if not isinstance(left, dict) or not isinstance(right, dict):
        return None
    state_index = _state_u16_index(left)
    literal = _literal_ast_value(right)
    if state_index is None or literal is None:
        state_index = _state_u16_index(right)
        literal = _literal_ast_value(left)
    target = operands[1].get("value")
    if state_index is None or literal is None or not isinstance(target, int):
        return None
    return {
        "state_index": state_index,
        "literal": literal,
        "target": target,
    }


def _state_equal_literal(ast: dict[str, Any]) -> dict[str, Any] | None:
    if ast.get("type") != "binary" or ast.get("op") != "equal":
        return None
    left = ast.get("lhs", {})
    right = ast.get("rhs", {})
    if not isinstance(left, dict) or not isinstance(right, dict):
        return None
    state = left if left.get("type") == "state_ref" else right
    literal_ast = right if state is left else left
    if not isinstance(state, dict) or state.get("type") != "state_ref":
        return None
    literal = _literal_ast_value(literal_ast)
    index = state.get("index", {})
    if literal is None or not isinstance(index, dict):
        return None
    index_value = _literal_ast_value(index)
    if index_value is None:
        return None
    result: dict[str, Any] = {
        "storage": str(state.get("storage", "")),
        "index": index_value,
        "literal": literal,
    }
    if "bank" in state:
        result["bank"] = int(state["bank"])
    return result


def _compound_state_21_gate_branch(instruction: dict[str, Any]) -> dict[str, Any] | None:
    if int(instruction.get("commandId", -1)) != 0x0B:
        return None
    operands = instruction.get("operands", [])
    if len(operands) != 2 or operands[0].get("type") != "condition":
        return None
    condition = operands[0].get("value", {})
    ast = condition.get("ast", {}) if isinstance(condition, dict) else {}
    if ast.get("type") != "binary" or ast.get("op") != "logical_and":
        return None
    left = _state_equal_literal(ast.get("lhs", {}))
    right = _state_equal_literal(ast.get("rhs", {}))
    if left is None or right is None:
        return None
    result = left if left["storage"] == "state_u16" and left["index"] == 21 else right
    gate = right if result is left else left
    target = operands[1].get("value")
    if (
        result["storage"] != "state_u16"
        or result["index"] != 21
        or (gate["storage"] == "state_u16" and gate["index"] == 21)
        or not isinstance(target, int)
    ):
        return None
    return {"result": int(result["literal"]), "gate": gate, "target": target}


def _canonical_routine_40_result_consumer(
    by_offset: dict[int, dict[str, Any]], resume_offset: int, definition_count: int
) -> dict[str, Any]:
    if definition_count <= 0:
        return {"kind": "unresolved", "reason": "no_definitions"}
    cursor = _skip_result_markers(by_offset, resume_offset)
    if definition_count == 1:
        instruction = by_offset.get(cursor)
        if instruction is None:
            return {"kind": "unresolved", "reason": "missing_result_branch"}
        branch = _state_u16_equal_literal_branch(instruction)
        if branch is None:
            return {"kind": "unresolved", "reason": "noncanonical_result_branch"}
        if branch["state_index"] != 21:
            return {"kind": "unresolved", "reason": "different_result_storage"}
        if branch["literal"] != 1:
            return {"kind": "unresolved", "reason": "nonsequential_result_literal"}
        fallthrough = _skip_result_markers(by_offset, int(instruction["endOffset"]))
        false_target = _skip_result_markers(by_offset, branch["target"])
        if fallthrough not in by_offset or false_target not in by_offset:
            return {"kind": "unresolved", "reason": "result_target_not_decoded"}
        if fallthrough == false_target:
            return {"kind": "unresolved", "reason": "single_result_targets_not_distinct"}
        return {
            "kind": "one_based_state_u16_21_branch_chain",
            "result_storage": "state_u16",
            "result_index": 21,
            "result_values": [1],
            "native_producer": "unresolved",
            "comparisons": [
                {
                    "source_offset": int(instruction["sourceOffset"]),
                    "result": 1,
                    "fallthrough_offset": fallthrough,
                    "false_target_offset": false_target,
                }
            ],
            "option_entry_offsets": [fallthrough],
            "fallback_offset": false_target,
        }

    comparisons: list[dict[str, int]] = []
    option_entries: list[int] = []
    for expected_result in range(1, definition_count):
        instruction = by_offset.get(cursor)
        if instruction is None:
            return {"kind": "unresolved", "reason": "missing_result_branch"}
        branch = _state_u16_equal_literal_branch(instruction)
        if branch is None:
            return {"kind": "unresolved", "reason": "noncanonical_result_branch"}
        if branch["state_index"] != 21:
            return {"kind": "unresolved", "reason": "different_result_storage"}
        if branch["literal"] != expected_result:
            return {"kind": "unresolved", "reason": "nonsequential_result_literal"}
        fallthrough = _skip_result_markers(by_offset, int(instruction["endOffset"]))
        false_target = _skip_result_markers(by_offset, branch["target"])
        if fallthrough not in by_offset or false_target not in by_offset:
            return {"kind": "unresolved", "reason": "result_target_not_decoded"}
        comparisons.append(
            {
                "source_offset": int(instruction["sourceOffset"]),
                "result": expected_result,
                "fallthrough_offset": fallthrough,
                "false_target_offset": false_target,
            }
        )
        option_entries.append(fallthrough)
        cursor = false_target
    option_entries.append(cursor)
    return {
        "kind": "one_based_state_u16_21_branch_chain",
        "result_storage": "state_u16",
        "result_index": 21,
        "result_values": list(range(1, definition_count + 1)),
        "native_producer": "unresolved",
        "comparisons": comparisons,
        "option_entry_offsets": option_entries,
    }


def _gated_routine_40_result_consumer(
    by_offset: dict[int, dict[str, Any]], resume_offset: int, definition_count: int
) -> dict[str, Any]:
    cursor = _skip_result_markers(by_offset, resume_offset)
    rows: list[dict[str, Any]] = []
    seen: set[int] = set()
    while cursor not in seen:
        seen.add(cursor)
        instruction = by_offset.get(cursor)
        if instruction is None:
            return {"kind": "unresolved", "reason": "missing_gated_result_branch"}
        branch = _compound_state_21_gate_branch(instruction)
        if branch is None:
            break
        fallthrough = _skip_result_markers(by_offset, int(instruction["endOffset"]))
        false_target = _skip_result_markers(by_offset, int(branch["target"]))
        if fallthrough not in by_offset or false_target not in by_offset:
            return {"kind": "unresolved", "reason": "gated_result_target_not_decoded"}
        rows.append(
            {
                "source_offset": int(instruction["sourceOffset"]),
                "result": int(branch["result"]),
                "gate": branch["gate"],
                "fallthrough_offset": fallthrough,
                "false_target_offset": false_target,
            }
        )
        cursor = false_target
    if not rows:
        return {"kind": "unresolved", "reason": "noncanonical_result_branch"}
    first_gate = rows[0]["gate"]
    gate_identity = {key: first_gate[key] for key in ("storage", "index", "bank") if key in first_gate}
    grouped: dict[int, list[dict[str, Any]]] = {}
    for row in rows:
        gate = row["gate"]
        identity = {key: gate[key] for key in ("storage", "index", "bank") if key in gate}
        if identity != gate_identity:
            return {"kind": "unresolved", "reason": "mixed_result_gate_storage"}
        grouped.setdefault(int(row["result"]), []).append(row)
    expected_results = list(range(1, definition_count + 1))
    if sorted(grouped) != expected_results:
        return {"kind": "unresolved", "reason": "nonsequential_gated_result_literal"}
    expected_gate_values = [int(row["gate"]["literal"]) for row in grouped[1]]
    if len(expected_gate_values) < 2 or len(expected_gate_values) != len(set(expected_gate_values)):
        return {"kind": "unresolved", "reason": "invalid_result_gate_values"}
    for result_value in expected_results:
        values = [int(row["gate"]["literal"]) for row in grouped[result_value]]
        if values != expected_gate_values:
            return {"kind": "unresolved", "reason": "incomplete_result_gate_matrix"}
    variants = [
        {
            "result": int(row["result"]),
            "gate_value": int(row["gate"]["literal"]),
            "source_offset": int(row["source_offset"]),
            "fallthrough_offset": int(row["fallthrough_offset"]),
            "false_target_offset": int(row["false_target_offset"]),
        }
        for row in rows
    ]
    return {
        "kind": "gated_one_based_state_u16_21_branch_matrix",
        "result_storage": "state_u16",
        "result_index": 21,
        "result_values": expected_results,
        "gate": {**gate_identity, "values": expected_gate_values},
        "native_producer": "unresolved",
        "variants": variants,
        "fallback_offset": cursor,
    }


def _result_gate_dependencies(
    by_offset: dict[int, dict[str, Any]], resume_offset: int, limit: int = 64
) -> list[dict[str, Any]]:
    cursor = _skip_result_markers(by_offset, resume_offset)
    dependencies: dict[tuple[Any, ...], dict[str, Any]] = {}
    seen: set[int] = set()
    for _ in range(limit):
        if cursor in seen:
            break
        seen.add(cursor)
        instruction = by_offset.get(cursor)
        if instruction is None or int(instruction.get("commandId", -1)) != 0x0B:
            break
        compound = _compound_state_21_gate_branch(instruction)
        if compound is not None:
            gate = compound["gate"]
            key = (gate.get("storage"), gate.get("bank"), gate.get("index"))
            record = dependencies.setdefault(
                key,
                {
                    "storage": str(gate.get("storage", "")),
                    "index": int(gate.get("index", -1)),
                    "values": [],
                },
            )
            if "bank" in gate:
                record["bank"] = int(gate["bank"])
            literal = int(gate["literal"])
            if literal not in record["values"]:
                record["values"].append(literal)
        operands = instruction.get("operands", [])
        if len(operands) != 2 or not isinstance(operands[1].get("value"), int):
            break
        cursor = _skip_result_markers(by_offset, int(operands[1]["value"]))
    return list(dependencies.values())


def _routine_40_result_consumer(
    by_offset: dict[int, dict[str, Any]], resume_offset: int, definition_count: int
) -> dict[str, Any]:
    canonical = _canonical_routine_40_result_consumer(by_offset, resume_offset, definition_count)
    if canonical["kind"] == "one_based_state_u16_21_branch_chain":
        return canonical
    if definition_count == 1:
        return canonical
    gated = _gated_routine_40_result_consumer(by_offset, resume_offset, definition_count)
    if gated["kind"] == "gated_one_based_state_u16_21_branch_matrix":
        return gated
    dependencies = _result_gate_dependencies(by_offset, resume_offset)
    if dependencies:
        reason = (
            "native_secondary_state_u16_13_gate"
            if any(row["storage"] == "state_u16" and row["index"] == 13 for row in dependencies)
            else "mixed_result_gate_chain"
        )
        return {"kind": "unresolved", "reason": reason, "gate_dependencies": dependencies}
    return canonical


def scan_code(code: bytes, entry_name: str = "TEST.MES") -> dict[str, Any]:
    data = (0).to_bytes(4, "little") + code
    document = mes_basic_block_ir_v6.decode_mes(data, {"entry": entry_name})
    by_offset, conflicts = _unique_instructions(document)
    definitions: dict[int, dict[str, Any]] = {}
    rejected: dict[str, int] = {}
    rejected_rows: list[dict[str, Any]] = []
    command_10_candidates = 0

    for offset, instruction in sorted(by_offset.items()):
        if int(instruction["commandId"]) != 0x10:
            continue
        command_10_candidates += 1
        definition_id = _literal_record(instruction)
        target = _u32_target(instruction)
        reason = ""
        if definition_id is None:
            reason = "nonliteral_record"
        elif target is None:
            reason = "missing_target"
        else:
            body = _decode_definition_body(code, int(instruction["endOffset"]), target)
            if not body["ok"]:
                reason = str(body["reason"])
            else:
                definitions[offset] = {
                    "definition_id": definition_id,
                    "source_offset": offset,
                    "target_offset": target,
                    "message_count": int(body["message_count"]),
                }
        if reason:
            rejected[reason] = rejected.get(reason, 0) + 1
            rejected_rows.append({"entry": entry_name, "source_offset": offset, "reason": reason})

    predecessors: set[int] = set()
    next_offsets: dict[int, int] = {}
    for offset, definition in definitions.items():
        next_offset = _skip_markers(by_offset, int(definition["target_offset"]))
        next_offsets[offset] = next_offset
        if next_offset in definitions:
            predecessors.add(next_offset)

    routes: list[dict[str, Any]] = []
    for root in sorted(set(definitions) - predecessors):
        route_definitions: list[dict[str, Any]] = []
        seen: set[int] = set()
        cursor = root
        while cursor in definitions and cursor not in seen:
            seen.add(cursor)
            route_definitions.append(definitions[cursor])
            cursor = next_offsets[cursor]
        terminal = by_offset.get(cursor)
        if terminal is None or int(terminal["commandId"]) != 0x1D or _literal_record(terminal) != 40:
            continue
        ids = [int(definition["definition_id"]) for definition in route_definitions]
        routes.append(
            {
                "entry": entry_name,
                "source_offset": root,
                "routine_40_offset": cursor,
                "resume_offset": int(terminal["endOffset"]),
                "definition_count": len(route_definitions),
                "definition_ids": ids,
                "definition_offsets": [int(definition["source_offset"]) for definition in route_definitions],
                "definition_targets": [int(definition["target_offset"]) for definition in route_definitions],
                "message_counts": [int(definition["message_count"]) for definition in route_definitions],
                "zero_based_sequential_ids": ids == list(range(len(ids))),
                "result_consumer": _routine_40_result_consumer(
                    by_offset, int(terminal["endOffset"]), len(route_definitions)
                ),
            }
        )

    return {
        "entry": entry_name,
        "command_10_candidates": command_10_candidates,
        "exact_definitions": len(definitions),
        "rejected": rejected,
        "rejected_rows": rejected_rows,
        "conflicting_duplicate_offsets": conflicts,
        "routes": routes,
    }


def audit_archive(archive: Path, entry_filter: str = "") -> dict[str, Any]:
    archive = archive.resolve()
    summary: dict[str, Any] = {
        "script_entries": 0,
        "entries_with_command_10": 0,
        "command_10_candidates": 0,
        "exact_definitions": 0,
        "rejected_definitions": 0,
        "routes_to_routine_40": 0,
        "entries_with_routes": 0,
        "zero_based_sequential_routes": 0,
        "one_based_state_u16_21_consumers": 0,
        "single_definition_one_based_consumers": 0,
        "gated_state_u16_21_consumers": 0,
        "max_definition_count": 0,
        "definition_count_distribution": {},
        "conflicting_duplicate_offsets": 0,
        "rejection_reasons": {},
        "result_consumer_rejection_reasons": {},
    }
    routes: list[dict[str, Any]] = []
    rejected_rows: list[dict[str, Any]] = []
    wanted = entry_filter.casefold()
    with archive.open("rb") as source:
        for entry_name, archive_offset, size in read_entries(archive):
            if Path(entry_name).suffix.lower() not in {".mes", ".lib"}:
                continue
            if wanted and entry_name.casefold() != wanted:
                continue
            summary["script_entries"] += 1
            source.seek(archive_offset)
            data = source.read(size)
            if len(data) != size:
                raise ValueError(f"truncated archive read for {entry_name}")
            entry_sha256 = hashlib.sha256(data).hexdigest()
            entry_count = int.from_bytes(data[:4], "little") if len(data) >= 4 else 0
            code_offset = 4 + entry_count * 4
            if code_offset > len(data):
                raise ValueError(f"invalid MES container for {entry_name}")
            entry_result = scan_code(data[code_offset:], entry_name)
            candidates = int(entry_result["command_10_candidates"])
            exact = int(entry_result["exact_definitions"])
            if candidates:
                summary["entries_with_command_10"] += 1
            summary["command_10_candidates"] += candidates
            summary["exact_definitions"] += exact
            summary["conflicting_duplicate_offsets"] += int(entry_result["conflicting_duplicate_offsets"])
            for reason, count in entry_result["rejected"].items():
                summary["rejected_definitions"] += int(count)
                reasons: dict[str, int] = summary["rejection_reasons"]
                reasons[reason] = reasons.get(reason, 0) + int(count)
            for rejected_row in entry_result["rejected_rows"]:
                rejected_rows.append({**rejected_row, "entry_sha256": entry_sha256})
            entry_routes = entry_result["routes"]
            if entry_routes:
                summary["entries_with_routes"] += 1
            for route in entry_routes:
                route["entry_sha256"] = entry_sha256
                summary["routes_to_routine_40"] += 1
                summary["max_definition_count"] = max(summary["max_definition_count"], int(route["definition_count"]))
                distribution: dict[str, int] = summary["definition_count_distribution"]
                count_key = str(route["definition_count"])
                distribution[count_key] = distribution.get(count_key, 0) + 1
                if route["zero_based_sequential_ids"]:
                    summary["zero_based_sequential_routes"] += 1
                result_consumer = route["result_consumer"]
                if result_consumer["kind"] == "one_based_state_u16_21_branch_chain":
                    summary["one_based_state_u16_21_consumers"] += 1
                    if int(route["definition_count"]) == 1:
                        summary["single_definition_one_based_consumers"] += 1
                elif result_consumer["kind"] == "gated_one_based_state_u16_21_branch_matrix":
                    summary["gated_state_u16_21_consumers"] += 1
                else:
                    reason = str(result_consumer.get("reason", "unknown"))
                    result_reasons: dict[str, int] = summary["result_consumer_rejection_reasons"]
                    result_reasons[reason] = result_reasons.get(reason, 0) + 1
                routes.append(route)

    return {
        "schema": SCHEMA,
        "archive": archive.name,
        "archive_sha256": _sha256_file(archive),
        "offset_basis": "mes_code_start",
        "summary": summary,
        "routes": routes,
        "rejected_definitions": rejected_rows,
    }


def _write_json_atomic(path: Path, value: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name + ".tmp")
    temporary.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    temporary.replace(path)


def main() -> None:
    parser = argparse.ArgumentParser(description="Audit exact bounded DEF sequences ending at routine 40.")
    parser.add_argument("archive", type=Path)
    parser.add_argument("--entry", default="", help="Restrict the audit to one archive entry.")
    parser.add_argument("-o", "--output", type=Path)
    args = parser.parse_args()
    archive = args.archive.resolve()
    if args.output:
        output = args.output.resolve()
        if output == archive or output == archive.parent or archive.parent in output.parents:
            parser.error("output must be outside the source archive directory")
    result = audit_archive(archive, args.entry)
    if args.output:
        _write_json_atomic(args.output.resolve(), result)
        summary = result["summary"]
        print(
            f"entries={summary['script_entries']} candidates={summary['command_10_candidates']} "
            f"exact={summary['exact_definitions']} routes={summary['routes_to_routine_40']} "
            f"one_based_consumers={summary['one_based_state_u16_21_consumers']} "
            f"gated_consumers={summary['gated_state_u16_21_consumers']} "
            f"consumer_outliers={sum(summary['result_consumer_rejection_reasons'].values())} "
            f"output={args.output.resolve()}"
        )
    else:
        print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
