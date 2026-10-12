"""Audit one MES address-table entry's routine-40 native group registrations.

The report is structural and deliberately omits dialogue text and raw payload
bytes. It records command-0x1B group clears, command-0x10 registrations, their
bounded state guards, the routine-40 terminal, the stored two-stage result
dispatch, its fallback owner, and command-0x0E source records naming the target
MES. It does not execute native input or the dynamic host, infer an unmatched
result's meaning, or assign gameplay labels to a group.
"""

from __future__ import annotations

import argparse
import bisect
import hashlib
import json
from pathlib import Path
from typing import Any

import mes_basic_block_ir_v6
from audit_mes_def_routes import (
    _compound_state_21_gate_branch,
    _decode_definition_body,
    _literal_record,
    _skip_result_markers,
    _state_u16_equal_literal_branch,
    _u32_target,
    _unique_instructions,
    scan_code,
)
from extract_kakyu_arc import read_entries
from mes_archive_ir import load_archive_entry, parse_mes_container
from payload_values import sha256_file as _sha256_file


SCHEMA = "kakyu_mes_routine40_group_route_audit/v4"


def _string_record_value(instruction: dict[str, Any]) -> str | None:
    operands = instruction.get("operands", [])
    if len(operands) != 1 or operands[0].get("type") != "record_list":
        return None
    records = operands[0].get("records", [])
    if len(records) != 1 or int(records[0].get("tag", -1)) != 1:
        return None
    value = records[0].get("value", {})
    if not isinstance(value, dict) or value.get("type") != "cp932_string":
        return None
    text = value.get("value")
    return str(text) if isinstance(text, str) else None


def scan_host_activation_payload(
    data: bytes,
    entry_name: str,
    target_entry: str,
) -> list[dict[str, Any]]:
    """Find exact command-0x0E active-string records for one target MES.

    The result deliberately records only control metadata and hashes. It does
    not retain surrounding dialogue or infer the dynamic host receiver.
    """

    container = parse_mes_container(data, {"entry": entry_name})
    decoded = mes_basic_block_ir_v6.decode_mes(data, {"entry": entry_name})
    by_offset, conflicts = _unique_instructions(decoded)
    if conflicts:
        raise ValueError(f"{entry_name} has conflicting decoded instruction offsets")
    entry_offsets = [int(value) for value in container["header"]["entryOffsets"]]
    code_offset = int(container["header"]["codeOffset"])
    code = data[code_offset:]
    wanted = target_entry.casefold()
    activations: list[dict[str, Any]] = []
    for offset, instruction in sorted(by_offset.items()):
        if int(instruction.get("commandId", -1)) != 0x0E:
            continue
        stored_target = _string_record_value(instruction)
        if stored_target is None or stored_target.casefold() != wanted:
            continue
        end_offset = int(instruction["endOffset"])
        owner_index = bisect.bisect_right(entry_offsets, offset) - 1
        activations.append(
            {
                "source_entry": entry_name,
                "source_entry_sha256": hashlib.sha256(data).hexdigest(),
                "owner_address_entry_index": owner_index,
                "source_offset": offset,
                "end_offset": end_offset,
                "command_id": 0x0E,
                "target_entry": stored_target,
                "envelope_sha256": hashlib.sha256(code[offset:end_offset]).hexdigest(),
                "receiver_semantics": "unresolved_dynamic_virtual_dispatch",
                "callee_start_coordinate": "unresolved",
            }
        )
    return activations


def scan_archive_host_activations(
    archive: Path,
    target_entry: str,
) -> list[dict[str, Any]]:
    """Scan an ARC once and structurally decode candidate command-0x0E callers."""

    raw_archive = archive.read_bytes()
    target_bytes = target_entry.encode("ascii").lower()
    activations: list[dict[str, Any]] = []
    for entry_name, offset, size in read_entries(archive):
        data = raw_archive[offset : offset + size]
        if target_bytes not in data.lower():
            continue
        activations.extend(scan_host_activation_payload(data, entry_name, target_entry))
    return activations


def _code_coordinate_transfer(instruction: dict[str, Any]) -> int | None:
    if int(instruction.get("commandId", -1)) != 0x0C:
        return None
    # The decoder used to hand 0x0C back as four separate bytes, which this
    # reassembled; it now reads the authoritative u32 target directly.
    operands = instruction.get("operands", [])
    if len(operands) != 1 or operands[0].get("type") != "code_offset":
        return None
    target = int(operands[0].get("value", -1))
    return None if target < 0 else target


def _dispatch_branch(instruction: dict[str, Any]) -> dict[str, int] | None:
    simple = _state_u16_equal_literal_branch(instruction)
    if simple is not None and int(simple["state_index"]) == 21:
        return {
            "first_result": int(simple["literal"]),
            "secondary_result": -1,
            "target": int(simple["target"]),
        }
    compound = _compound_state_21_gate_branch(instruction)
    if compound is None:
        return None
    gate = compound["gate"]
    if str(gate.get("storage", "")) != "state_u16" or int(gate.get("index", -1)) != 13:
        return None
    return {
        "first_result": int(compound["result"]),
        "secondary_result": int(gate["literal"]),
        "target": int(compound["target"]),
    }


def _secondary_branch(instruction: dict[str, Any]) -> dict[str, int] | None:
    branch = _state_u16_equal_literal_branch(instruction)
    if branch is None or int(branch["state_index"]) != 13:
        return None
    return {
        "secondary_result": int(branch["literal"]),
        "target": int(branch["target"]),
    }


def _first_secondary_between(
    by_offset: dict[int, dict[str, Any]], start_offset: int, end_offset: int
) -> int | None:
    for offset, instruction in sorted(by_offset.items()):
        if offset < start_offset:
            continue
        if offset >= end_offset:
            break
        if _secondary_branch(instruction) is not None:
            return offset
    return None


def scan_result_dispatch(
    by_offset: dict[int, dict[str, Any]],
    resume_offset: int,
    groups: list[dict[str, Any]],
) -> dict[str, Any]:
    """Audit the stored 43C-style first/secondary result dispatch without executing it."""

    groups_by_selector = {int(group["selector"]): group for group in groups}
    group_zero = groups_by_selector.get(0)
    if group_zero is None:
        return {"ok": False, "reason": "missing_first_stage_group"}
    first_count = int(group_zero["registration_count"])
    if first_count <= 0:
        return {"ok": False, "reason": "empty_first_stage_group"}
    expected_selectors = list(range(first_count + 1))
    if sorted(groups_by_selector) != expected_selectors:
        return {
            "ok": False,
            "reason": "group_selectors_do_not_match_first_stage_results",
            "expected_group_selectors": expected_selectors,
            "actual_group_selectors": sorted(groups_by_selector),
        }

    first_offset = _skip_result_markers(by_offset, resume_offset)
    rows: list[dict[str, Any]] = []
    cursor = first_offset
    for expected_result in range(1, first_count + 1):
        instruction = by_offset.get(cursor)
        branch = _dispatch_branch(instruction or {})
        if branch is None:
            return {
                "ok": False,
                "reason": "missing_first_result_branch",
                "first_result": expected_result,
                "source_offset": cursor,
            }
        if int(branch["first_result"]) != expected_result:
            return {
                "ok": False,
                "reason": "nonsequential_first_result_branch",
                "expected_first_result": expected_result,
                "actual_first_result": int(branch["first_result"]),
                "source_offset": cursor,
            }
        false_target = _skip_result_markers(by_offset, int(branch["target"]))
        if false_target not in by_offset:
            return {
                "ok": False,
                "reason": "first_result_target_not_decoded",
                "first_result": expected_result,
                "source_offset": cursor,
                "false_target_offset": false_target,
            }

        group = groups_by_selector[expected_result]
        registration_count = int(group["registration_count"])
        secondary_rows: list[dict[str, int]] = []
        secondary_cursor: int | None
        if int(branch["secondary_result"]) >= 0:
            secondary_cursor = cursor
        elif registration_count > 0:
            secondary_cursor = _first_secondary_between(
                by_offset, int(instruction["endOffset"]), false_target
            )
        else:
            secondary_cursor = None
            unexpected_secondary = _first_secondary_between(
                by_offset, int(instruction["endOffset"]), false_target
            )
            if unexpected_secondary is not None:
                return {
                    "ok": False,
                    "reason": "empty_group_has_secondary_result_branch",
                    "first_result": expected_result,
                    "source_offset": unexpected_secondary,
                }
        if registration_count > 0 and secondary_cursor is None:
            return {
                "ok": False,
                "reason": "missing_secondary_result_branch",
                "first_result": expected_result,
                "registration_count": registration_count,
            }

        expected_secondary = 1
        seen_secondary_offsets: set[int] = set()
        terminal_false_target = false_target
        while secondary_cursor is not None and secondary_cursor not in seen_secondary_offsets:
            seen_secondary_offsets.add(secondary_cursor)
            secondary_instruction = by_offset.get(secondary_cursor)
            if secondary_instruction is None:
                break
            secondary_value: int | None = None
            target: int | None = None
            compound = _dispatch_branch(secondary_instruction)
            if (
                compound is not None
                and int(compound["first_result"]) == expected_result
                and int(compound["secondary_result"]) >= 0
            ):
                secondary_value = int(compound["secondary_result"])
                target = int(compound["target"])
            else:
                simple = _secondary_branch(secondary_instruction)
                if simple is not None:
                    secondary_value = int(simple["secondary_result"])
                    target = int(simple["target"])
            if secondary_value is None or target is None:
                break
            if secondary_value != expected_secondary:
                return {
                    "ok": False,
                    "reason": "nonsequential_secondary_result_branch",
                    "first_result": expected_result,
                    "expected_secondary_result": expected_secondary,
                    "actual_secondary_result": secondary_value,
                    "source_offset": secondary_cursor,
                }
            terminal_false_target = _skip_result_markers(by_offset, target)
            secondary_rows.append(
                {
                    "source_offset": secondary_cursor,
                    "secondary_result": secondary_value,
                    "fallthrough_offset": _skip_result_markers(
                        by_offset, int(secondary_instruction["endOffset"])
                    ),
                    "false_target_offset": terminal_false_target,
                }
            )
            expected_secondary += 1
            next_instruction = by_offset.get(terminal_false_target)
            next_compound = _dispatch_branch(next_instruction or {})
            next_simple = _secondary_branch(next_instruction or {})
            if (
                next_compound is not None
                and int(next_compound["first_result"]) == expected_result
                and int(next_compound["secondary_result"]) == expected_secondary
            ) or (
                next_simple is not None
                and int(next_simple["secondary_result"]) == expected_secondary
            ):
                secondary_cursor = terminal_false_target
            else:
                secondary_cursor = None

        observed_values = [int(row["secondary_result"]) for row in secondary_rows]
        if len(observed_values) > registration_count:
            return {
                "ok": False,
                "reason": "secondary_results_exceed_registered_group",
                "first_result": expected_result,
                "registration_count": registration_count,
                "secondary_result_values": observed_values,
            }
        unmatched_values = list(range(len(observed_values) + 1, registration_count + 1))
        rows.append(
            {
                "first_result": expected_result,
                "group_selector": expected_result,
                "first_branch_offset": cursor,
                "first_branch_kind": (
                    "first_and_secondary" if int(branch["secondary_result"]) >= 0 else "first_only"
                ),
                "first_false_target_offset": false_target,
                "registration_count": registration_count,
                "secondary_result_values": observed_values,
                "secondary_branches": secondary_rows,
                "secondary_dispatch_complete": len(observed_values) == registration_count,
                "unmatched_secondary_results": unmatched_values,
                "secondary_terminal_false_target_offset": terminal_false_target,
            }
        )
        if expected_result < first_count:
            cursor = false_target

    default_source = int(rows[-1]["secondary_terminal_false_target_offset"])
    default_instruction = by_offset.get(default_source)
    default_destination = _code_coordinate_transfer(default_instruction or {})
    if default_destination is None:
        return {
            "ok": False,
            "reason": "missing_result_default_continuation",
            "source_offset": default_source,
        }
    if default_destination not in by_offset:
        return {
            "ok": False,
            "reason": "result_default_destination_not_decoded",
            "source_offset": default_source,
            "destination_offset": default_destination,
        }

    incomplete = [
        {
            "first_result": int(row["first_result"]),
            "unmatched_secondary_results": list(row["unmatched_secondary_results"]),
            "stored_fallback_source_offset": default_source,
            "stored_fallback_destination_offset": default_destination,
        }
        for row in rows
        if row["unmatched_secondary_results"]
    ]
    return {
        "ok": True,
        "kind": "one_based_state_u16_21_then_state_u16_13_dispatch",
        "first_result_storage": "state_u16",
        "first_result_index": 21,
        "first_result_values": list(range(1, first_count + 1)),
        "secondary_result_storage": "state_u16",
        "secondary_result_index": 13,
        "groups": rows,
        "complete_secondary_mapping": not incomplete,
        "incomplete_secondary_mappings": incomplete,
        "default_continuation": {
            "kind": "unconditional_code_coordinate_transfer",
            "source_offset": default_source,
            "destination_offset": default_destination,
            "backward_transfer": default_destination < default_source,
            "covers_unmatched_or_out_of_range_results": True,
            "gameplay_meaning": "unresolved",
        },
        "native_input_and_cadence": "unresolved",
    }


def bind_default_continuation_context(
    by_offset: dict[int, dict[str, Any]],
    entry_offsets: list[int],
    code_size: int,
    result_dispatch: dict[str, Any],
) -> dict[str, Any]:
    """Bind the stored fallback destination to its address-table owner."""

    if not result_dispatch.get("ok", False):
        return {"ok": False, "reason": "result_dispatch_not_validated"}
    continuation = result_dispatch.get("default_continuation", {})
    destination = int(continuation.get("destination_offset", -1))
    if destination < 0 or destination >= code_size:
        return {"ok": False, "reason": "fallback_destination_outside_code"}
    owner_index = bisect.bisect_right(entry_offsets, destination) - 1
    if owner_index < 0:
        return {"ok": False, "reason": "fallback_destination_has_no_address_entry_owner"}
    owner_start = entry_offsets[owner_index]
    owner_end = entry_offsets[owner_index + 1] if owner_index + 1 < len(entry_offsets) else code_size
    instruction = by_offset.get(destination)
    if instruction is None:
        return {"ok": False, "reason": "fallback_destination_not_decoded"}
    operands = instruction.get("operands", [])
    condition_literal: int | None = None
    branch_target: int | None = None
    if int(instruction.get("commandId", -1)) == 0x0B and len(operands) == 2:
        condition = operands[0].get("value", {})
        ast = condition.get("ast", {}) if isinstance(condition, dict) else {}
        if isinstance(ast, dict) and ast.get("type") == "literal":
            condition_literal = int(ast.get("value", 0))
        if operands[1].get("type") == "code_offset":
            branch_target = int(operands[1].get("value", -1))
    return {
        "ok": True,
        "destination_offset": destination,
        "owner_address_entry_index": owner_index,
        "owner_start_offset": owner_start,
        "owner_end_offset": owner_end,
        "first_instruction_command_id": int(instruction.get("commandId", -1)),
        "first_instruction_end_offset": int(instruction.get("endOffset", -1)),
        "condition_literal": condition_literal,
        "branch_target_offset": branch_target,
        "stored_path": (
            "constant_true_fallthrough"
            if int(instruction.get("commandId", -1)) == 0x0B and condition_literal == 1
            else "unresolved"
        ),
        "gameplay_meaning": "dispatcher_reentry_unresolved",
    }


def _literal_ast(ast: dict[str, Any]) -> int | None:
    if ast.get("type") != "literal":
        return None
    return int(ast.get("value", 0))


def _state_predicate(ast: dict[str, Any]) -> dict[str, Any] | None:
    if ast.get("type") != "binary" or ast.get("op") not in {"equal", "not_equal"}:
        return None
    lhs = ast.get("lhs", {})
    rhs = ast.get("rhs", {})
    if not isinstance(lhs, dict) or not isinstance(rhs, dict):
        return None
    state = lhs if lhs.get("type") == "state_ref" else rhs
    literal_ast = rhs if state is lhs else lhs
    if not isinstance(state, dict) or state.get("type") != "state_ref":
        return None
    index_ast = state.get("index", {})
    if not isinstance(index_ast, dict):
        return None
    index = _literal_ast(index_ast)
    value = _literal_ast(literal_ast)
    if index is None or value is None:
        return None
    result: dict[str, Any] = {
        "storage": str(state.get("storage", "")),
        "index": index,
        "operator": str(ast["op"]),
        "value": value,
    }
    if "bank" in state:
        result["bank"] = int(state["bank"])
    return result


def _flatten_boolean_predicates(ast: dict[str, Any], operator: str) -> list[dict[str, Any]] | None:
    if ast.get("type") == "binary" and ast.get("op") == operator:
        lhs = ast.get("lhs", {})
        rhs = ast.get("rhs", {})
        if not isinstance(lhs, dict) or not isinstance(rhs, dict):
            return None
        left = _flatten_boolean_predicates(lhs, operator)
        right = _flatten_boolean_predicates(rhs, operator)
        if left is None or right is None:
            return None
        return left + right
    predicate = _state_predicate(ast)
    return [predicate] if predicate is not None else None


def _summarize_guard(instruction: dict[str, Any]) -> dict[str, Any] | None:
    if int(instruction.get("commandId", -1)) != 0x0B:
        return None
    operands = instruction.get("operands", [])
    if len(operands) != 2 or operands[0].get("type") != "condition":
        return None
    condition = operands[0].get("value", {})
    ast = condition.get("ast", {}) if isinstance(condition, dict) else {}
    if not isinstance(ast, dict):
        return None
    predicate = _state_predicate(ast)
    if predicate is not None:
        return {"kind": "state_predicate", **predicate}
    for operator, kind in (("logical_or", "any_state_predicate"), ("logical_and", "all_state_predicate")):
        predicates = _flatten_boolean_predicates(ast, operator)
        if predicates is not None and len(predicates) > 1:
            return {"kind": kind, "predicates": predicates}
    return {"kind": "unresolved_condition_shape"}


def _branch_target(instruction: dict[str, Any]) -> int | None:
    operands = instruction.get("operands", [])
    if len(operands) != 2 or operands[1].get("type") != "code_offset":
        return None
    value = operands[1].get("value")
    return int(value) if isinstance(value, int) else None


def scan_group_entry(
    code: bytes,
    by_offset: dict[int, dict[str, Any]],
    start_offset: int,
    end_offset: int,
    entry_name: str = "TEST.MES",
    require_result_dispatch: bool = False,
) -> dict[str, Any]:
    if start_offset < 0 or end_offset <= start_offset or end_offset > len(code):
        return {"ok": False, "error": "address_entry_range_invalid"}

    predecessors_by_end: dict[int, list[dict[str, Any]]] = {}
    for instruction in by_offset.values():
        predecessors_by_end.setdefault(int(instruction["endOffset"]), []).append(instruction)

    groups: list[dict[str, Any]] = []
    groups_by_selector: dict[int, dict[str, Any]] = {}
    issues: list[dict[str, Any]] = []
    current_group: dict[str, Any] | None = None
    routine_40_offsets: list[int] = []

    for offset, instruction in sorted(by_offset.items()):
        if offset < start_offset or offset >= end_offset:
            continue
        command_id = int(instruction["commandId"])
        if command_id == 0x1B:
            selector = _literal_record(instruction)
            if selector is None:
                issues.append({"source_offset": offset, "reason": "nonliteral_group_selector"})
                current_group = None
                continue
            if selector in groups_by_selector:
                issues.append({"source_offset": offset, "reason": "repeated_group_clear", "selector": selector})
                current_group = None
                continue
            current_group = {
                "selector": selector,
                "clear_offset": offset,
                "registrations": [],
            }
            groups.append(current_group)
            groups_by_selector[selector] = current_group
            continue
        if command_id == 0x1D and _literal_record(instruction) == 40:
            routine_40_offsets.append(offset)
            continue
        if command_id != 0x10:
            continue
        if current_group is None:
            issues.append({"source_offset": offset, "reason": "registration_without_group"})
            continue
        definition_id = _literal_record(instruction)
        target = _u32_target(instruction)
        if definition_id is None or target is None:
            issues.append({"source_offset": offset, "reason": "invalid_registration_envelope"})
            continue
        body = _decode_definition_body(code, int(instruction["endOffset"]), target)
        if not body.get("ok", False):
            issues.append(
                {
                    "source_offset": offset,
                    "reason": "invalid_registration_body",
                    "detail": str(body.get("reason", "unknown")),
                }
            )
            continue

        registration: dict[str, Any] = {
            "source_offset": offset,
            "definition_id": definition_id,
            "target_offset": target,
            "message_count": int(body["message_count"]),
            "guard": {"kind": "unconditional"},
        }
        predecessors = predecessors_by_end.get(offset, [])
        branches = [row for row in predecessors if int(row.get("commandId", -1)) == 0x0B]
        if len(branches) > 1:
            issues.append({"source_offset": offset, "reason": "ambiguous_guard_predecessor"})
            continue
        if branches:
            branch = branches[0]
            guard = _summarize_guard(branch)
            if guard is None:
                issues.append({"source_offset": offset, "reason": "invalid_guard"})
                continue
            branch_target = _branch_target(branch)
            if branch_target != target:
                issues.append(
                    {
                        "source_offset": offset,
                        "reason": "guard_false_target_mismatch",
                        "branch_target": branch_target,
                        "definition_target": target,
                    }
                )
                continue
            registration["guard"] = {
                **guard,
                "source_offset": int(branch["sourceOffset"]),
                "false_target_offset": branch_target,
            }
        current_group["registrations"].append(registration)

    for group in groups:
        registrations: list[dict[str, Any]] = group["registrations"]
        group["registration_count"] = len(registrations)
        group["definition_ids"] = [int(row["definition_id"]) for row in registrations]
        group["empty_after_clear"] = not registrations
        group["conditional_registration_count"] = sum(
            1 for row in registrations if row["guard"]["kind"] != "unconditional"
        )

    route_audit = scan_code(code, entry_name)
    matching_routes = [
        route
        for route in route_audit.get("routes", [])
        if start_offset <= int(route["source_offset"]) < end_offset
        and int(route["routine_40_offset"]) in routine_40_offsets
    ]
    result_dispatch = (
        scan_result_dispatch(by_offset, int(matching_routes[0]["resume_offset"]), groups)
        if len(matching_routes) == 1
        else {"ok": False, "reason": "unique_routine_40_route_required"}
    )
    return {
        "ok": (
            not issues
            and len(routine_40_offsets) == 1
            and len(matching_routes) == 1
            and (not require_result_dispatch or bool(result_dispatch.get("ok", False)))
        ),
        "entry": entry_name,
        "address_entry_start": start_offset,
        "address_entry_end": end_offset,
        "groups": groups,
        "group_selectors": [int(group["selector"]) for group in groups],
        "empty_group_selectors": [
            int(group["selector"]) for group in groups if group["empty_after_clear"]
        ],
        "registration_count": sum(int(group["registration_count"]) for group in groups),
        "routine_40_offsets": routine_40_offsets,
        "routine_40_route": matching_routes[0] if len(matching_routes) == 1 else {},
        "result_dispatch": result_dispatch,
        "issues": issues,
        "playback_promotion": "blocked_native_input_and_gameplay_mapping_unresolved",
    }


def audit_archive(
    archive: Path,
    entry_name: str = "43C.MES",
    address_entry_index: int = 148,
) -> dict[str, Any]:
    archive = archive.resolve()
    data, source = load_archive_entry(archive, entry_name)
    container = parse_mes_container(data, source)
    entries = container["entries"]
    if address_entry_index < 0 or address_entry_index >= len(entries):
        raise ValueError(
            f"address entry {address_entry_index} is outside 0..{max(len(entries) - 1, 0)}"
        )
    address_entry = entries[address_entry_index]
    entry_count = int(container["header"]["entryCount"])
    code_offset = 4 + entry_count * 4
    code = data[code_offset:]
    decoded = mes_basic_block_ir_v6.decode_mes(data, source)
    by_offset, conflicts = _unique_instructions(decoded)
    result = scan_group_entry(
        code,
        by_offset,
        int(address_entry["offset"]),
        int(address_entry["endOffset"]),
        str(source["entry"]),
        True,
    )
    result_dispatch = result.get("result_dispatch", {})
    result["default_continuation_context"] = bind_default_continuation_context(
        by_offset,
        [int(value) for value in container["header"]["entryOffsets"]],
        len(code),
        result_dispatch if isinstance(result_dispatch, dict) else {},
    )
    host_activations = scan_archive_host_activations(archive, str(source["entry"]))
    result["host_activations"] = host_activations
    result["host_activation_contract"] = {
        "target_entry": str(source["entry"]),
        "activation_command_id": 0x0E,
        "stored_activation_count": len(host_activations),
        "source_entries": sorted({str(row["source_entry"]) for row in host_activations}),
        "callee_start_coordinate": "unresolved",
        "receiver_semantics": "unresolved_dynamic_virtual_dispatch",
        "playback_promotion": "blocked_command_0e_host_activation",
    }
    if conflicts:
        result = {
            **result,
            "ok": False,
            "issues": [
                *result.get("issues", []),
                {"reason": "conflicting_duplicate_instruction_offsets", "count": conflicts},
            ],
        }
    return {
        "schema": SCHEMA,
        "archive": archive.name,
        "archive_sha256": _sha256_file(archive),
        "entry": str(source["entry"]),
        "entry_sha256": str(source["sha256"]),
        "address_entry_index": address_entry_index,
        "offset_basis": "mes_code_start",
        "conflicting_duplicate_offsets": conflicts,
        **result,
    }


def _write_json_atomic(path: Path, value: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name + ".tmp")
    temporary.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    temporary.replace(path)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Audit one MES address entry's routine-40 native group registrations."
    )
    parser.add_argument("archive", type=Path)
    parser.add_argument("--entry", default="43C.MES")
    parser.add_argument("--address-entry", type=int, default=148)
    parser.add_argument("-o", "--output", type=Path)
    args = parser.parse_args()
    archive = args.archive.resolve()
    if args.output:
        output = args.output.resolve()
        if output == archive or output == archive.parent or archive.parent in output.parents:
            parser.error("output must be outside the source archive directory")
    result = audit_archive(archive, args.entry, args.address_entry)
    if not result["ok"]:
        raise SystemExit(json.dumps(result, ensure_ascii=False, indent=2))
    if args.output:
        _write_json_atomic(args.output.resolve(), result)
        print(
            f"entry={result['entry']} address_entry={result['address_entry_index']} "
            f"groups={result['group_selectors']} registrations={result['registration_count']} "
            f"routine40={result['routine_40_offsets']} "
            f"host_command0e={result['host_activation_contract']['stored_activation_count']} "
            f"output={args.output.resolve()}"
        )
    else:
        print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
