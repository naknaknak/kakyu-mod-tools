"""Audit a captured target MES root-replacement terminal without replaying it.

The input capture remains local and may contain raw state snapshots.  This tool
emits only path-free control metadata, source offsets, and hashes; it never
copies snapshot bytes or dialogue from the capture or authoritative archive.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import struct
from pathlib import Path
from typing import Any, Callable

import mes_basic_block_ir_v6
from audit_mes_routine40_groups import scan_host_activation_payload
from mes_archive_ir import load_archive_entry, parse_mes_container
from mes_structured_ir import decode_record_list
from payload_values import sha256_file as _sha256_file


SCHEMA = "kakyu_mes_runtime_trace_terminal_audit/v3"
TRACE_SCHEMA = "kakyu_mes_runtime_trace_capture/v3"
LIBRARY_ENTRY = "LIBLARY.LIB"
FIRST_SELECTION_SOURCE = 0x1C95
FIRST_SELECTION_END = 0x1CA0
SECOND_SELECTION_SOURCE = 0x1CC4
SECOND_SELECTION_END = 0x1CD0
EVENTB03_CHOICE_DISPATCH_START = 0x12DC
EVENTB03_CHOICE_RESULT_SLOT = 21
EVENTB03_CHOICE_RESULTS = (1, 2, 3)
NON_TERMINAL_OBLIGATIONS = (
    "target_identity",
    "host_consumption_timing",
    "archive_lookup",
    "stream_installation",
    "intro_coordinate",
    "caller_context_ownership",
)


def _required(mapping: dict[str, Any], key: str, owner: str) -> Any:
    if key not in mapping:
        raise ValueError(f"{owner} is missing {key}")
    return mapping[key]


def _captures(event: dict[str, Any]) -> dict[str, Any]:
    value = event.get("captures", {})
    return value if isinstance(value, dict) else {}


def _filename(event: dict[str, Any]) -> str | None:
    captures = _captures(event)
    for key in ("target_name", "filename", "successor_entry"):
        value = captures.get(key)
        if isinstance(value, str):
            return value.casefold()
    return None


def _next_event(
    events: list[dict[str, Any]],
    start: int,
    predicate: Callable[[dict[str, Any]], bool],
) -> int | None:
    for index in range(start, len(events)):
        if predicate(events[index]):
            return index
    return None


def find_root_replacement(
    capture: dict[str, Any],
) -> dict[str, Any]:
    events_value = _required(capture, "events", "trace capture")
    if not isinstance(events_value, list):
        raise ValueError("trace capture events are not a list")
    events = [dict(event) for event in events_value]
    target = str(_required(capture, "target_entry", "trace capture")).casefold()
    if not target.endswith(".mes"):
        raise ValueError("trace target is not a MES entry")
    sequences = [int(_required(event, "sequence", "trace event")) for event in events]
    if sequences != sorted(sequences) or len(sequences) != len(set(sequences)):
        raise ValueError("trace event sequence is not strictly ordered")

    start_index = _next_event(
        events,
        0,
        lambda event: event.get("id") == "target_execution_start"
        and event.get("evidence") is True,
    )
    if start_index is None:
        raise ValueError("trace has no qualified target execution start")
    target_command = next(
        (
            event
            for event in reversed(events[: start_index + 1])
            if event.get("id") == "command_0e_receiver_call"
            and event.get("evidence") is True
            and _filename(event) == target
        ),
        None,
    )
    if target_command is None:
        raise ValueError("trace has no qualified target command-0x0E producer")
    owner_state = _captures(target_command).get("active_state")
    owner_receiver = _captures(target_command).get("public_context_receiver")

    for command_index in range(start_index + 1, len(events)):
        command = events[command_index]
        if command.get("id") == "target_root_replacement" and command.get(
            "evidence"
        ) is True:
            successor = _filename(command)
            if successor is None or successor == target:
                continue
            chain = _captures(command).get("root_replacement_chain", {})
            return {
                "successor_entry": successor,
                "command_sequence": int(chain.get("command_sequence", -1)),
                "loader_sequence": int(chain.get("loader_sequence", -1)),
                "lookup_sequence": int(chain.get("lookup_sequence", -1)),
                "installer_sequence": int(chain.get("installer_sequence", -1)),
                "coordinate_sequence": int(chain.get("coordinate_sequence", -1)),
                "terminal_sequence": int(command["sequence"]),
                "classification": "collector_native",
            }
        if command.get("id") != "command_0e_receiver_call":
            continue
        successor = _filename(command)
        captures = _captures(command)
        if (
            successor is None
            or successor == target
            or not successor.endswith(".mes")
            or captures.get("active_state") != owner_state
            or captures.get("public_context_receiver") != owner_receiver
        ):
            continue

        def before_next_command(index: int) -> bool:
            return not any(
                event.get("id") == "command_0e_receiver_call"
                for event in events[command_index + 1 : index]
            )

        loader_index = _next_event(
            events,
            command_index + 1,
            lambda event: event.get("id") == "mes_archive_loader_entry"
            and _filename(event) == successor,
        )
        if loader_index is None or not before_next_command(loader_index):
            continue
        lookup_index = _next_event(
            events,
            loader_index + 1,
            lambda event: event.get("id") == "mes_archive_lookup_call"
            and _filename(event) == successor,
        )
        if lookup_index is None or not before_next_command(lookup_index):
            continue
        installer_index = _next_event(
            events,
            lookup_index + 1,
            lambda event: event.get("id") == "stream_installer_entry",
        )
        if installer_index is None or not before_next_command(installer_index):
            continue
        coordinate_index = _next_event(
            events,
            installer_index + 1,
            lambda event: event.get("id") == "stream_coordinate_write",
        )
        if coordinate_index is None or not before_next_command(coordinate_index):
            continue
        terminal_index = _next_event(
            events,
            coordinate_index + 1,
            lambda event: str(event.get("id", "")).startswith(
                "command_0e_flag_writer_"
            )
            and _filename(event) == successor,
        )
        if terminal_index is None or not before_next_command(terminal_index):
            continue
        return {
            "successor_entry": successor,
            "command_sequence": int(command["sequence"]),
            "loader_sequence": int(events[loader_index]["sequence"]),
            "lookup_sequence": int(events[lookup_index]["sequence"]),
            "installer_sequence": int(events[installer_index]["sequence"]),
            "coordinate_sequence": int(events[coordinate_index]["sequence"]),
            "terminal_sequence": int(events[terminal_index]["sequence"]),
            "classification": "offline_reclassified",
        }
    raise ValueError("trace has no complete same-owner command-0x0E root replacement")


def summarize_choice(
    capture: dict[str, Any], expected_choice: int | None
) -> dict[str, Any]:
    rows_value = capture.get("target_choice_results", [])
    if not isinstance(rows_value, list):
        raise ValueError("target choice results are not a list")
    rows = [dict(row) for row in rows_value]
    selected = {
        int(row["one_based_result"])
        for row in rows
        if row.get("result_path") == "selected_control_store"
        and isinstance(row.get("one_based_result"), int)
        and 0 < int(row["one_based_result"]) < 0xFFFF
    }
    if len(selected) != 1:
        raise ValueError("trace does not expose one selected-control result")
    result = selected.pop()
    mirrored = any(
        row.get("result_path") == "command_12_slot_18_store"
        and row.get("one_based_result") == result
        for row in rows
    )
    reset = any(
        row.get("result_path") == "command_12_slot_18_store"
        and row.get("one_based_result") == 0xFFFF
        and row.get("state_u16_18_before") == result
        and row.get("state_u16_21_before") == result
        for row in rows
    )
    if not mirrored or not reset:
        raise ValueError("choice result is missing its slot-18 mirror or sentinel reset")
    if expected_choice is not None and result != expected_choice:
        raise ValueError(
            f"runtime choice result {result} does not match expected {expected_choice}"
        )
    return {
        "one_based_result": result,
        "expected_one_based_result": expected_choice,
        "expected_result_matched": expected_choice is None or result == expected_choice,
        "selected_control_store": True,
        "command_12_slot_18_mirror": True,
        "slot_18_reset_to_ffff": True,
        "source_coordinate": "nested_stream_unresolved",
    }


def _runtime_stream_base(captures: dict[str, Any]) -> int:
    instruction = captures.get("active_instruction_pointer")
    offset = captures.get("active_stream_offset")
    if not isinstance(instruction, int) or not isinstance(offset, int):
        raise ValueError("runtime choice event has no stream pointer pair")
    base = instruction - offset
    if base <= 0:
        raise ValueError("runtime choice event has an invalid stream base")
    return base


def _expression_signature(record: dict[str, Any]) -> tuple[str, int]:
    if record.get("type") != "expression_record":
        raise ValueError("routine-40 native record is not an expression")
    expression = record.get("value", {})
    if not isinstance(expression, dict) or expression.get("valid") is not True:
        raise ValueError("routine-40 native record expression is invalid")
    ast = expression.get("ast", {})
    if not isinstance(ast, dict):
        raise ValueError("routine-40 native record has no expression AST")
    if ast.get("type") == "literal" and isinstance(ast.get("value"), int):
        return "literal", int(ast["value"])
    if ast.get("type") == "state_ref" and ast.get("storage") == "state_u16":
        index = ast.get("index", {})
        if (
            isinstance(index, dict)
            and index.get("type") == "literal"
            and isinstance(index.get("value"), int)
        ):
            return "state_u16", int(index["value"])
    raise ValueError("routine-40 native record expression shape changed")


def _instruction_map(data: bytes) -> dict[int, dict[str, Any]]:
    decoded = mes_basic_block_ir_v6.decode_mes(data, {"entry": LIBRARY_ENTRY})
    rows: dict[int, dict[str, Any]] = {}
    for node in decoded.get("nodes", []):
        for instruction in node.get("instructions", []):
            offset = int(instruction["sourceOffset"])
            prior = rows.get(offset)
            if prior is not None and prior != instruction:
                raise ValueError("library decode has conflicting instruction offsets")
            rows[offset] = instruction
    return rows


def bind_choice_source(
    capture: dict[str, Any],
    library_data: bytes,
    expected_choice: int,
) -> dict[str, Any]:
    """Bind the runtime result stores to authoritative routine-40 records."""

    events_value = _required(capture, "events", "trace capture")
    if not isinstance(events_value, list):
        raise ValueError("trace capture events are not a list")
    choice_events = [
        event
        for event in events_value
        if isinstance(event, dict)
        and event.get("id") == "target_choice_result"
        and event.get("evidence") is True
    ]
    selected = [
        event
        for event in choice_events
        if _captures(event).get("result_path") == "selected_control_store"
        and _captures(event).get("one_based_result") == expected_choice
    ]
    if len(selected) != 1:
        raise ValueError("trace does not have one source-bindable selected result")
    selected_event = selected[0]
    selected_captures = _captures(selected_event)
    stream_base = _runtime_stream_base(selected_captures)
    if (
        selected_captures.get("context") != stream_base
        or selected_captures.get("active_stream_offset") != FIRST_SELECTION_END
    ):
        raise ValueError("selected result is not at the first routine-40 continuation")

    selected_sequence = int(selected_event["sequence"])
    mirrors = [
        event
        for event in choice_events
        if int(event["sequence"]) > selected_sequence
        and _captures(event).get("result_path") == "command_12_slot_18_store"
        and _captures(event).get("one_based_result") == expected_choice
        and _runtime_stream_base(_captures(event)) == stream_base
        and _captures(event).get("context") == stream_base
        and _captures(event).get("active_stream_offset") == FIRST_SELECTION_END
    ]
    if len(mirrors) != 1:
        raise ValueError("trace does not bind one slot-18 mirror to routine 40")
    mirror_event = mirrors[0]
    mirror_sequence = int(mirror_event["sequence"])
    resets = [
        event
        for event in choice_events
        if int(event["sequence"]) > mirror_sequence
        and _captures(event).get("result_path") == "command_12_slot_18_store"
        and _captures(event).get("one_based_result") == 0xFFFF
        and _captures(event).get("state_u16_18_before") == expected_choice
        and _captures(event).get("state_u16_21_before") == expected_choice
        and _runtime_stream_base(_captures(event)) == stream_base
        and _captures(event).get("context") == stream_base
        and _captures(event).get("active_stream_offset") == SECOND_SELECTION_END
    ]
    if len(resets) != 1:
        raise ValueError("trace does not bind one sentinel reset to routine 40")
    reset_event = resets[0]

    container = parse_mes_container(library_data, {"entry": LIBRARY_ENTRY})
    code_offset = int(container["header"]["codeOffset"])
    code = library_data[code_offset:]
    first_records, first_end = decode_record_list(
        code, FIRST_SELECTION_SOURCE + 1, len(code)
    )
    second_records, second_end = decode_record_list(
        code, SECOND_SELECTION_SOURCE + 1, len(code)
    )
    if (
        code[FIRST_SELECTION_SOURCE] != 0x12
        or first_end != FIRST_SELECTION_END
        or [_expression_signature(row) for row in first_records["records"]]
        != [("literal", 1), ("literal", 21), ("literal", 0)]
    ):
        raise ValueError("authoritative first routine-40 selection record changed")
    if (
        code[SECOND_SELECTION_SOURCE] != 0x12
        or second_end != SECOND_SELECTION_END
        or [_expression_signature(row) for row in second_records["records"]]
        != [("literal", 1), ("literal", 21), ("state_u16", 21)]
    ):
        raise ValueError("authoritative second routine-40 selection record changed")
    instructions = _instruction_map(library_data)
    write = instructions.get(FIRST_SELECTION_END, {})
    operands = write.get("operands", [])
    pairs = operands[1].get("pairs", []) if len(operands) == 2 else []
    if not (
        write.get("commandId") == 0x04
        and operands[0].get("type") == "u8_index"
        and operands[0].get("value") == 21
        and len(pairs) == 1
        and pairs[0].get("continuation") == 0
        and pairs[0].get("expression", {}).get("ast", {}).get("type")
        == "state_ref"
        and pairs[0].get("expression", {}).get("ast", {}).get("storage")
        == "state_u16"
        and pairs[0]
        .get("expression", {})
        .get("ast", {})
        .get("index", {})
        .get("value")
        == 18
        and instructions.get(SECOND_SELECTION_END, {}).get("commandId") == 0x0C
    ):
        raise ValueError("authoritative routine-40 result envelope changed")

    observations_value = capture.get("target_native_path_observations", [])
    if not isinstance(observations_value, list):
        raise ValueError("target native-path observations are not a list")
    anchor_offsets: set[int] = set()
    target_linked = False
    self_linked = False
    for observation in observations_value:
        if not isinstance(observation, dict):
            continue
        if observation.get("probe_id") != "command_1d_shared_script_call":
            continue
        try:
            if _runtime_stream_base(observation) != stream_base:
                continue
        except ValueError:
            continue
        offset = observation.get("active_stream_offset")
        observed_dword = observation.get("destination_first_dword")
        if not isinstance(offset, int) or offset < 0 or offset + 4 > len(code):
            continue
        if not isinstance(observed_dword, int):
            continue
        if observed_dword != struct.unpack_from("<I", code, offset)[0]:
            continue
        anchor_offsets.add(offset)
        target_linked = target_linked or (
            observation.get("caller_stream_binding") == "target_code_base_relative"
        )
        self_linked = self_linked or observation.get("caller_code_base") == stream_base
    if len(anchor_offsets) < 3 or not target_linked or not self_linked:
        raise ValueError("runtime choice stream is not sufficiently bound to LIBLARY.LIB")

    return {
        "source_entry": LIBRARY_ENTRY,
        "source_entry_sha256": hashlib.sha256(library_data).hexdigest(),
        "stream_binding": "library_code_base_relative",
        "matched_command_1d_anchor_offsets": sorted(anchor_offsets),
        "target_linked_anchor": target_linked,
        "library_self_linked_anchor": self_linked,
        "first_native_record": {
            "source_offset": FIRST_SELECTION_SOURCE,
            "end_offset": FIRST_SELECTION_END,
            "envelope_sha256": hashlib.sha256(
                code[FIRST_SELECTION_SOURCE:FIRST_SELECTION_END]
            ).hexdigest(),
        },
        "selected_control_observation": {
            "sequence": selected_sequence,
            "source_offset": FIRST_SELECTION_END,
            "one_based_result": expected_choice,
        },
        "slot_18_mirror_observation": {
            "sequence": mirror_sequence,
            "source_offset": FIRST_SELECTION_END,
            "one_based_result": expected_choice,
        },
        "second_native_record": {
            "source_offset": SECOND_SELECTION_SOURCE,
            "end_offset": SECOND_SELECTION_END,
            "envelope_sha256": hashlib.sha256(
                code[SECOND_SELECTION_SOURCE:SECOND_SELECTION_END]
            ).hexdigest(),
        },
        "slot_18_reset_observation": {
            "sequence": int(reset_event["sequence"]),
            "source_offset": SECOND_SELECTION_END,
            "one_based_result": 0xFFFF,
        },
    }


def _choice_dispatch_literal(condition: dict[str, Any]) -> int:
    ast = condition.get("ast", {})
    if not isinstance(ast, dict) or ast.get("type") != "binary" or ast.get("op") != "equal":
        raise ValueError("EVENTB03 choice dispatch condition is not an equality")
    lhs = ast.get("lhs", {})
    rhs = ast.get("rhs", {})
    if not isinstance(lhs, dict) or not isinstance(rhs, dict):
        raise ValueError("EVENTB03 choice dispatch condition is malformed")
    index = lhs.get("index", {})
    if not (
        lhs.get("type") == "state_ref"
        and lhs.get("storage") == "state_u16"
        and isinstance(index, dict)
        and index.get("type") == "literal"
        and index.get("value") == EVENTB03_CHOICE_RESULT_SLOT
        and rhs.get("type") == "literal"
        and isinstance(rhs.get("value"), int)
    ):
        raise ValueError("EVENTB03 choice dispatch no longer reads state_u16[21]")
    return int(rhs["value"])


def bind_choice_successor_source(
    target_data: bytes,
    static_handoffs: list[dict[str, Any]],
    expected_choice: int,
) -> dict[str, Any]:
    """Bind a captured one-based result to one authoritative successor command.

    EVENTB03's post-routine-40 code is a three-guard chain over state_u16[21].
    The CFG walk fixes each guard according to the captured result while keeping
    every unrelated conditional edge conservative.  Each possible result must
    reach exactly one of the three authoritative MACHI.MES envelopes and the
    same script-return block before the selected route is reported.
    """

    if expected_choice not in EVENTB03_CHOICE_RESULTS:
        raise ValueError("EVENTB03 choice result is outside the audited 1..3 range")
    if len(static_handoffs) != len(EVENTB03_CHOICE_RESULTS):
        raise ValueError("EVENTB03 authoritative successor count changed")
    handoff_by_offset: dict[int, dict[str, Any]] = {}
    target_sha256 = hashlib.sha256(target_data).hexdigest()
    for row in static_handoffs:
        offset = int(row.get("source_offset", -1))
        if offset < 0 or offset in handoff_by_offset:
            raise ValueError("EVENTB03 successor offsets are invalid or duplicated")
        if str(row.get("source_entry_sha256", target_sha256)) != target_sha256:
            raise ValueError("EVENTB03 successor binding has a different source hash")
        handoff_by_offset[offset] = row

    decoded = mes_basic_block_ir_v6.decode_mes(
        target_data, {"entry": str(static_handoffs[0].get("source_entry", "EVENTB03.MES"))}
    )
    blocks_value = decoded.get("basicBlocks", [])
    edges_value = decoded.get("blockEdges", [])
    if not isinstance(blocks_value, list) or not isinstance(edges_value, list):
        raise ValueError("EVENTB03 CFG projection is unavailable")
    blocks = {
        str(block["id"]): block
        for block in blocks_value
        if isinstance(block, dict) and isinstance(block.get("id"), str)
    }
    if len(blocks) != len(blocks_value):
        raise ValueError("EVENTB03 CFG has malformed or duplicate blocks")
    edges = [edge for edge in edges_value if isinstance(edge, dict)]
    outgoing: dict[str, list[dict[str, Any]]] = {}
    for edge in edges:
        outgoing.setdefault(str(edge.get("source", "")), []).append(edge)

    start_blocks = [
        block_id
        for block_id, block in blocks.items()
        if EVENTB03_CHOICE_DISPATCH_START in block.get("instructionOffsets", [])
    ]
    if len(start_blocks) != 1:
        raise ValueError("EVENTB03 first post-choice dispatch block changed")

    guard_rows: list[dict[str, Any]] = []
    guard_literals: dict[int, int] = {}
    current_block = start_blocks[0]
    common_exit_block = ""
    common_exit_offset = -1
    for expected_literal in EVENTB03_CHOICE_RESULTS:
        condition_edges = [
            edge
            for edge in outgoing.get(current_block, [])
            if edge.get("type") in {"condition_true", "condition_false"}
        ]
        by_type = {str(edge.get("type")): edge for edge in condition_edges}
        if len(condition_edges) != 2 or set(by_type) != {"condition_true", "condition_false"}:
            raise ValueError("EVENTB03 choice dispatch no longer has two resolved edges")
        true_edge = by_type["condition_true"]
        false_edge = by_type["condition_false"]
        source_offset = int(true_edge.get("sourceOffset", -1))
        if source_offset != int(false_edge.get("sourceOffset", -2)):
            raise ValueError("EVENTB03 choice dispatch edge coordinates disagree")
        if expected_literal == 1 and source_offset != EVENTB03_CHOICE_DISPATCH_START:
            raise ValueError("EVENTB03 choice dispatch start changed")
        true_condition = true_edge.get("condition", {})
        false_condition = false_edge.get("condition", {})
        if true_condition != false_condition or not isinstance(true_condition, dict):
            raise ValueError("EVENTB03 choice dispatch edge conditions disagree")
        literal = _choice_dispatch_literal(true_condition)
        if literal != expected_literal:
            raise ValueError("EVENTB03 one-based choice dispatch order changed")
        if (
            true_edge.get("resolved") is not True
            or false_edge.get("resolved") is not True
            or str(true_edge.get("target", "")) not in blocks
            or str(false_edge.get("target", "")) not in blocks
        ):
            raise ValueError("EVENTB03 choice dispatch has an unresolved CFG edge")
        guard_literals[source_offset] = literal
        guard_rows.append(
            {
                "source_offset": source_offset,
                "result_value": literal,
                "true_target_offset": int(true_edge.get("targetOffset", -1)),
                "false_target_offset": int(false_edge.get("targetOffset", -1)),
            }
        )
        current_block = str(false_edge["target"])
        if expected_literal == EVENTB03_CHOICE_RESULTS[-1]:
            common_exit_block = current_block
            common_exit_offset = int(false_edge.get("targetOffset", -1))

    def route_for(choice: int) -> dict[str, Any]:
        seen: set[str] = set()
        pending = [start_blocks[0]]
        reached_handoffs: set[int] = set()
        terminal_blocks: set[str] = set()
        rejected_out_of_range_edges: set[tuple[int, int]] = set()
        while pending:
            block_id = pending.pop()
            if block_id in seen:
                continue
            seen.add(block_id)
            block = blocks[block_id]
            for untyped_offset in block.get("instructionOffsets", []):
                offset = int(untyped_offset)
                if offset in handoff_by_offset:
                    reached_handoffs.add(offset)
            block_edges = outgoing.get(block_id, [])
            if not block_edges:
                terminal_blocks.add(block_id)
                continue
            for edge in block_edges:
                source_offset = int(edge.get("sourceOffset", -1))
                if source_offset in guard_literals:
                    expected_type = (
                        "condition_true"
                        if choice == guard_literals[source_offset]
                        else "condition_false"
                    )
                    if edge.get("type") != expected_type:
                        continue
                target = str(edge.get("target", ""))
                if edge.get("resolved") is not True or target not in blocks:
                    target_offset = int(edge.get("targetOffset", -1))
                    if 0 <= target_offset < int(decoded.get("codeSize", 0)):
                        raise ValueError("EVENTB03 selected route has an unresolved in-range CFG edge")
                    rejected_out_of_range_edges.add((source_offset, target_offset))
                    continue
                pending.append(target)
        if len(reached_handoffs) != 1:
            raise ValueError("EVENTB03 choice does not reach exactly one successor handoff")
        if terminal_blocks != {common_exit_block}:
            raise ValueError("EVENTB03 choice routes no longer share one return terminal")
        return {
            "one_based_result": choice,
            "successor_source_offset": next(iter(reached_handoffs)),
            "reachable_block_count": len(seen),
            "rejected_out_of_range_edge_count": len(rejected_out_of_range_edges),
        }

    result_routes = [route_for(choice) for choice in EVENTB03_CHOICE_RESULTS]
    routed_offsets = {int(row["successor_source_offset"]) for row in result_routes}
    if routed_offsets != set(handoff_by_offset):
        raise ValueError("EVENTB03 result routes do not cover the authoritative successors")
    selected_route = next(
        row for row in result_routes if int(row["one_based_result"]) == expected_choice
    )
    selected_offset = int(selected_route["successor_source_offset"])
    selected_handoff = handoff_by_offset[selected_offset]
    return {
        "source_entry": str(selected_handoff.get("source_entry", "EVENTB03.MES")),
        "source_entry_sha256": target_sha256,
        "cfg_schema": str(decoded.get("schema", "")),
        "dispatch_storage": "state_u16",
        "dispatch_index": EVENTB03_CHOICE_RESULT_SLOT,
        "dispatch_chain": guard_rows,
        "result_routes": result_routes,
        "selected_one_based_result": expected_choice,
        "selected_handoff": {
            "source_offset": selected_offset,
            "end_offset": int(selected_handoff.get("end_offset", -1)),
            "envelope_sha256": str(selected_handoff.get("envelope_sha256", "")),
        },
        "common_exit_offset": common_exit_offset,
    }


def build_report(
    capture: dict[str, Any],
    root_replacement: dict[str, Any],
    static_handoffs: list[dict[str, Any]],
    choice: dict[str, Any],
    choice_source: dict[str, Any],
    choice_successor: dict[str, Any],
    *,
    capture_name: str,
    archive_name: str,
    archive_sha256: str,
) -> dict[str, Any]:
    if capture.get("schema") != TRACE_SCHEMA:
        raise ValueError("trace capture schema is not supported")
    if capture.get("target_qualified") is not True:
        raise ValueError("trace capture is not target-qualified")
    obligations_value = _required(capture, "proof_obligations", "trace capture")
    obligations = {
        str(row.get("id")): bool(row.get("complete"))
        for row in obligations_value
        if isinstance(row, dict)
    }
    missing = [name for name in NON_TERMINAL_OBLIGATIONS if not obligations.get(name)]
    if missing:
        raise ValueError(f"trace is missing non-terminal obligations: {', '.join(missing)}")
    if not static_handoffs:
        raise ValueError("authoritative target has no matching successor handoff")
    successor = str(root_replacement["successor_entry"])
    for row in static_handoffs:
        if str(row.get("source_entry", "")).casefold() != str(
            capture["target_entry"]
        ).casefold():
            raise ValueError("static successor handoff belongs to another MES entry")
        if str(row.get("target_entry", "")).casefold() != successor:
            raise ValueError("static successor handoff target changed")
    source = dict(_required(capture, "source", "trace capture"))
    if source.get("source_unchanged") is not True:
        raise ValueError("trace capture did not retain source identity")
    if source.get("archive_sha256") != archive_sha256:
        raise ValueError("trace and authoritative archive hashes differ")
    proof = [
        {"id": name, "complete": True, "observed_from_capture": True}
        for name in NON_TERMINAL_OBLIGATIONS
    ]
    proof.append(
        {
            "id": "return_or_terminal",
            "complete": True,
            "match": "any",
            "observed": ["target_root_replacement"],
        }
    )
    return {
        "schema": SCHEMA,
        "capture": capture_name,
        "archive": archive_name,
        "archive_sha256": archive_sha256,
        "target_entry": str(capture["target_entry"]),
        "target_entry_sha256": source.get("target_entry_sha256"),
        "runtime_sha256": source.get("runtime_sha256"),
        "host_slice_anchor_sha256": source.get("host_slice_anchor_sha256"),
        "capture_stop_reason": capture.get("stop_reason"),
        "root_replacement": {
            **root_replacement,
            "authoritative_source_offsets": sorted(
                int(row["source_offset"]) for row in static_handoffs
            ),
            "authoritative_envelope_sha256": sorted(
                {str(row["envelope_sha256"]) for row in static_handoffs}
            ),
            "exact_source_offset": int(
                choice_successor["selected_handoff"]["source_offset"]
            ),
            "source_binding": choice_successor,
        },
        "choice": {
            **choice,
            "source_coordinate": (
                f"{choice_source['source_entry']}:"
                f"0x{int(choice_source['first_native_record']['source_offset']):04X}"
                f"..0x{int(choice_source['first_native_record']['end_offset']):04X}"
            ),
            "source_binding": choice_source,
        },
        "proof_obligations": proof,
        "promotion_ready": True,
        "promotion_scope": "command_0e_host_activation",
        "unresolved_boundaries": [
            "portable_caller_state_preset",
        ],
        "source_unchanged": True,
    }


def audit(
    capture_path: Path,
    archive_path: Path,
    expected_target: str,
    expected_choice: int | None,
) -> dict[str, Any]:
    capture = json.loads(capture_path.read_text(encoding="utf-8"))
    if not isinstance(capture, dict):
        raise ValueError("trace capture root is not an object")
    target = str(_required(capture, "target_entry", "trace capture"))
    if target.casefold() != expected_target.casefold():
        raise ValueError(f"expected {expected_target}, found {target}")
    archive_before = _sha256_file(archive_path)
    root_replacement = find_root_replacement(capture)
    successor = str(root_replacement["successor_entry"])
    target_data, target_source = load_archive_entry(archive_path, target)
    library_data, _library_source = load_archive_entry(archive_path, LIBRARY_ENTRY)
    source = dict(_required(capture, "source", "trace capture"))
    if target_source["sha256"] != source.get("target_entry_sha256"):
        raise ValueError("authoritative target entry hash differs from trace")
    static_handoffs = scan_host_activation_payload(target_data, target, successor)
    choice = summarize_choice(capture, expected_choice)
    choice_value = int(choice["one_based_result"])
    choice_successor = bind_choice_successor_source(
        target_data, static_handoffs, choice_value
    )
    report = build_report(
        capture,
        root_replacement,
        static_handoffs,
        choice,
        bind_choice_source(capture, library_data, choice_value),
        choice_successor,
        capture_name=capture_path.name,
        archive_name=archive_path.name,
        archive_sha256=archive_before,
    )
    if _sha256_file(archive_path) != archive_before:
        raise ValueError("authoritative archive changed during audit")
    return report


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Reclassify a complete target root replacement in one local trace."
    )
    parser.add_argument("capture", type=Path)
    parser.add_argument("archive", type=Path)
    parser.add_argument("--expect-target", required=True)
    parser.add_argument("--expect-choice", type=int)
    args = parser.parse_args()
    report = audit(
        args.capture,
        args.archive,
        args.expect_target,
        args.expect_choice,
    )
    print(json.dumps(report, ensure_ascii=True, sort_keys=True, indent=2))


if __name__ == "__main__":
    main()
