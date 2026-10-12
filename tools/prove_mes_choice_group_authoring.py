from __future__ import annotations

import argparse
import bisect
import copy
import hashlib
import json
from pathlib import Path
from typing import Any

import mes_basic_block_ir_v6
from audit_mes_def_routes import _literal_record, _u32_target, _unique_instructions
from audit_mes_routine40_groups import scan_group_entry
from mes_archive_ir import load_archive_entry, parse_mes_container
from payload_values import (
    canonical_payload_bytes,
    fingerprint,
    is_sha256 as _is_sha256,
    sha256_file as _sha256_file,
)


SCHEMA = "kakyu_mes_choice_group_authoring_proof/v1"
TOP_LEVEL_KEYS = {
    "ok", "schema", "producer", "compatibility", "source_identity",
    "container", "boundary", "groups", "first_stage_options",
    "result_mapping", "coverage", "invariants", "payload_sha256",
}
SOURCE_IDENTITY_KEYS = {"archive", "archive_sha256", "entry", "entry_sha256"}
CONTAINER_KEYS = {
    "size", "entry_count", "code_offset", "code_size", "entry_sha256",
    "bytecode_sha256", "address_table_sha256",
}
BOUNDARY_KEYS = {
    "address_entry_index", "address_entry_start", "address_entry_end",
    "route_source_start", "terminal_start", "terminal_end",
    "terminal_raw_sha256", "physical_resume_start", "physical_resume_end",
    "physical_resume_raw_sha256",
}
GROUP_KEYS = {
    "selector", "clear", "definition_count", "empty_after_clear",
    "conditional_definition_count", "definitions",
}
SPAN_KEYS = {"start", "end", "raw_sha256"}
DEFINITION_KEYS = {
    "definition_id", "registration", "body", "message", "return_record",
    "guard",
}
BODY_KEYS = {"start", "end", "size", "raw_sha256"}
MESSAGE_KEYS = {
    "instruction_start", "instruction_end", "instruction_raw_sha256",
    "payload_start", "payload_end", "payload_size", "payload_raw_sha256",
    "encoding", "native_projection", "terminator_offset", "terminator",
}
GUARD_KEYS = {"kind", "instruction", "predicate_sha256"}
FIRST_OPTION_KEYS = {
    "first_result", "definition_id", "registration_start", "message_payload_sha256",
    "selected_group_selector",
}
RESULT_MAPPING_KEYS = {
    "kind", "first_result_storage", "first_result_index",
    "second_result_storage", "second_result_index", "first_result_values",
    "groups", "complete_secondary_mapping", "default_continuation",
}
RESULT_GROUP_KEYS = {
    "first_result", "group_selector", "first_branch", "first_false_target",
    "definition_count", "second_routes", "secondary_mapping_complete",
    "unmatched_second_results",
}
SECOND_ROUTE_KEYS = {
    "second_result", "definition_id", "registration_start", "resolution",
    "branch", "consumer_entry_offset", "false_target_offset",
}
DEFAULT_KEYS = {
    "instruction", "destination_offset", "backward_transfer",
    "covers_unmatched_or_out_of_range_results", "gameplay_meaning",
}
COVERAGE_KEYS = {
    "group_count", "definition_count", "conditional_definition_count",
    "empty_group_count", "first_stage_option_count", "result_group_count",
    "stored_second_route_count", "fallback_second_route_count",
}
COMPATIBILITY = {
    "policy": "source_bound_routine40_choice_group_authoring",
    "input_container_schema": "ai5_mes_container/v1",
    "group_clear_command_id": 0x1B,
    "definition_registration_command_id": 0x10,
    "routine_call_command_id": 0x1D,
    "routine_id": 40,
    "definition_body_policy": "one_strict_cp932_message_then_return",
    "first_result_policy": "one_based_state_u16_21_selects_group_1_through_n",
    "second_result_policy": "one_based_state_u16_13_selects_group_definition",
    "unmatched_result_policy": "retain_exact_stored_default_continuation",
    "native_input_and_cadence": "unresolved",
    "gameplay_labels": "not_exported",
    "binary_publication": "forbidden",
    "unknown_v1_field": "reject",
}
INVARIANTS = {
    "source_container_hash_bound": True,
    "address_entry_boundary_bound": True,
    "group_selectors_sequential_from_zero": True,
    "group_clear_envelopes_bound": True,
    "definition_ids_zero_based_and_sequential": True,
    "definition_envelopes_and_bodies_bound": True,
    "option_messages_strict_cp932_and_hash_only": True,
    "routine40_terminal_and_physical_resume_bound": True,
    "first_stage_rows_match_group_zero": True,
    "second_stage_numeric_routes_match_registered_groups": True,
    "stored_default_continuation_bound": True,
    "native_input_not_executed": True,
    "dialogue_text_not_exported": True,
    "binary_not_published": True,
}


class ChoiceGroupAuthoringProofError(ValueError):
    pass


def prove_entry(
    payload: bytes,
    source_identity: dict[str, Any],
    address_entry_index: int,
) -> dict[str, Any]:
    document = _build(payload, source_identity, address_entry_index)
    document["payload_sha256"] = fingerprint(document)
    validate(document, payload, source_identity, address_entry_index)
    return document


def group_entry_indices(
    payload: bytes,
    raw_source_identity: dict[str, Any],
) -> list[int]:
    """List address-entry indices holding a routine-40 grouped route, without proving each one.

    Decodes the whole container once and only calls the structural scanner
    (not the full ``prove_entry``) for the address entries that hold at
    least one group-clear (command 0x1B) instruction.
    """
    source_identity = _normalize_source_identity(payload, raw_source_identity)
    container = parse_mes_container(payload, source_identity)
    entries = container["entries"]
    code_offset = int(container["header"]["codeOffset"])
    code = payload[code_offset:]
    decoded = mes_basic_block_ir_v6.decode_mes(payload, source_identity)
    by_offset, conflicts = _unique_instructions(decoded)
    if conflicts:
        raise ChoiceGroupAuthoringProofError(
            "MES choice-group source has conflicting instruction offsets"
        )
    clear_offsets = sorted(
        offset for offset, instruction in by_offset.items()
        if int(instruction["commandId"]) == 0x1B
    )
    indices: list[int] = []
    for index, entry in enumerate(entries):
        start = int(entry["offset"])
        end = int(entry["endOffset"])
        lower = bisect.bisect_left(clear_offsets, start)
        if lower >= len(clear_offsets) or clear_offsets[lower] >= end:
            continue
        route = scan_group_entry(
            code, by_offset, start, end, source_identity["entry"], True
        )
        if route.get("ok", False):
            indices.append(index)
    return sorted(indices)


def validate(
    document: dict[str, Any],
    payload: bytes | None = None,
    source_identity: dict[str, Any] | None = None,
    address_entry_index: int | None = None,
) -> dict[str, Any]:
    result = validate_document(document)
    supplied = (payload, source_identity, address_entry_index)
    if any(value is not None for value in supplied):
        if any(value is None for value in supplied):
            raise ChoiceGroupAuthoringProofError(
                "MES choice-group source validation inputs are incomplete"
            )
        expected = _build(payload, source_identity, int(address_entry_index))
        actual = dict(document)
        actual.pop("payload_sha256", None)
        if expected != actual:
            raise ChoiceGroupAuthoringProofError(
                "MES choice-group authoring proof differs from its source"
            )
    return result


def validate_document(document: dict[str, Any]) -> dict[str, Any]:
    if (
        document.get("ok") is not True
        or document.get("schema") != SCHEMA
        or set(document) != TOP_LEVEL_KEYS
    ):
        raise ChoiceGroupAuthoringProofError(
            "MES choice-group authoring proof schema or fields changed"
        )
    if document.get("producer") != {
        "implementation": "python_phase6_choice_group_authoring_prover",
        "contract": SCHEMA,
    }:
        raise ChoiceGroupAuthoringProofError(
            "MES choice-group authoring proof producer changed"
        )
    if document.get("compatibility") != COMPATIBILITY:
        raise ChoiceGroupAuthoringProofError(
            "MES choice-group authoring compatibility changed"
        )
    retained = document.get("payload_sha256")
    if not _is_sha256(retained) or fingerprint(document) != retained:
        raise ChoiceGroupAuthoringProofError(
            "MES choice-group authoring proof fingerprint changed"
        )
    source = document.get("source_identity")
    container = document.get("container")
    boundary = document.get("boundary")
    if not _valid_source(source) or not _valid_container(container, source):
        raise ChoiceGroupAuthoringProofError(
            "MES choice-group source or container identity changed"
        )
    if not _valid_boundary(boundary, container):
        raise ChoiceGroupAuthoringProofError(
            "MES choice-group address-entry boundary changed"
        )
    groups = document.get("groups")
    first_options = document.get("first_stage_options")
    mapping = document.get("result_mapping")
    if not isinstance(groups, list) or not groups:
        raise ChoiceGroupAuthoringProofError("MES choice-group rows changed")
    if not isinstance(first_options, list) or not first_options:
        raise ChoiceGroupAuthoringProofError("MES choice-group first-stage rows changed")
    expected_selectors = list(range(len(first_options) + 1))
    if [row.get("selector") for row in groups if isinstance(row, dict)] != expected_selectors:
        raise ChoiceGroupAuthoringProofError(
            "MES choice-group selectors no longer match first-stage results"
        )
    total_definitions = 0
    total_conditional = 0
    empty_count = 0
    for group in groups:
        if not _valid_group(group):
            raise ChoiceGroupAuthoringProofError(
                "MES choice-group definition boundary changed"
            )
        total_definitions += group["definition_count"]
        total_conditional += group["conditional_definition_count"]
        empty_count += int(group["empty_after_clear"])
    group_zero = groups[0]
    if len(first_options) != group_zero["definition_count"]:
        raise ChoiceGroupAuthoringProofError(
            "MES choice-group first-stage count changed"
        )
    for index, option in enumerate(first_options):
        definition = group_zero["definitions"][index]
        if (
            not isinstance(option, dict)
            or set(option) != FIRST_OPTION_KEYS
            or option.get("first_result") != index + 1
            or option.get("definition_id") != index
            or option.get("registration_start")
            != definition["registration"]["start"]
            or option.get("message_payload_sha256")
            != definition["message"]["payload_raw_sha256"]
            or option.get("selected_group_selector") != index + 1
        ):
            raise ChoiceGroupAuthoringProofError(
                "MES choice-group first-stage option mapping changed"
            )
    stored_count, fallback_count = _validate_result_mapping(mapping, groups)
    coverage = document.get("coverage")
    if (
        not isinstance(coverage, dict)
        or set(coverage) != COVERAGE_KEYS
        or any(not _is_nonnegative_int(coverage.get(key)) for key in COVERAGE_KEYS)
        or coverage["group_count"] != len(groups)
        or coverage["definition_count"] != total_definitions
        or coverage["conditional_definition_count"] != total_conditional
        or coverage["empty_group_count"] != empty_count
        or coverage["first_stage_option_count"] != len(first_options)
        or coverage["result_group_count"] != len(first_options)
        or coverage["stored_second_route_count"] != stored_count
        or coverage["fallback_second_route_count"] != fallback_count
    ):
        raise ChoiceGroupAuthoringProofError(
            "MES choice-group coverage changed"
        )
    if document.get("invariants") != INVARIANTS:
        raise ChoiceGroupAuthoringProofError(
            "MES choice-group authoring invariants changed"
        )
    return {"ok": True, "schema": SCHEMA, "payload_sha256": retained}


def _build(
    payload: bytes,
    raw_source_identity: dict[str, Any],
    address_entry_index: int,
) -> dict[str, Any]:
    source_identity = _normalize_source_identity(payload, raw_source_identity)
    container = parse_mes_container(payload, source_identity)
    entries = container["entries"]
    if (
        not _is_nonnegative_int(address_entry_index)
        or address_entry_index >= len(entries)
    ):
        raise ChoiceGroupAuthoringProofError(
            "MES choice-group address entry is outside the container"
        )
    code_offset = int(container["header"]["codeOffset"])
    code = payload[code_offset:]
    entry = entries[address_entry_index]
    start = int(entry["offset"])
    end = int(entry["endOffset"])
    decoded = mes_basic_block_ir_v6.decode_mes(payload, source_identity)
    by_offset, conflicts = _unique_instructions(decoded)
    if conflicts:
        raise ChoiceGroupAuthoringProofError(
            "MES choice-group source has conflicting instruction offsets"
        )
    route = scan_group_entry(
        code, by_offset, start, end, source_identity["entry"], True
    )
    if not route.get("ok", False):
        raise ChoiceGroupAuthoringProofError(
            "MES choice-group route is not structurally complete"
        )
    groups = [
        _build_group(code, by_offset, group)
        for group in route["groups"]
    ]
    first_options = []
    for first_result, definition in enumerate(groups[0]["definitions"], 1):
        first_options.append({
            "first_result": first_result,
            "definition_id": definition["definition_id"],
            "registration_start": definition["registration"]["start"],
            "message_payload_sha256": definition["message"]["payload_raw_sha256"],
            "selected_group_selector": first_result,
        })
    result_mapping = _build_result_mapping(
        code, by_offset, route["result_dispatch"], groups
    )
    route_row = route["routine_40_route"]
    terminal_start = int(route_row["routine_40_offset"])
    terminal = _instruction(by_offset, terminal_start, 0x1D)
    if _literal_record(terminal) != 40:
        raise ChoiceGroupAuthoringProofError(
            "MES choice-group terminal is not literal routine 40"
        )
    terminal_span = _span(code, terminal)
    resume_start = int(route_row["resume_offset"])
    resume = by_offset.get(resume_start)
    if resume is None:
        raise ChoiceGroupAuthoringProofError(
            "MES choice-group physical resume is not decoded"
        )
    resume_span = _span(code, resume)
    conditional_count = sum(
        group["conditional_definition_count"] for group in groups
    )
    stored_count = sum(
        route_row["resolution"] == "stored_consumer_coordinate"
        for group in result_mapping["groups"]
        for route_row in group["second_routes"]
    )
    fallback_count = sum(
        route_row["resolution"] == "stored_default_continuation"
        for group in result_mapping["groups"]
        for route_row in group["second_routes"]
    )
    return {
        "ok": True,
        "schema": SCHEMA,
        "producer": {
            "implementation": "python_phase6_choice_group_authoring_prover",
            "contract": SCHEMA,
        },
        "compatibility": copy.deepcopy(COMPATIBILITY),
        "source_identity": source_identity,
        "container": {
            "size": len(payload),
            "entry_count": int(container["header"]["entryCount"]),
            "code_offset": code_offset,
            "code_size": len(code),
            "entry_sha256": hashlib.sha256(payload).hexdigest(),
            "bytecode_sha256": hashlib.sha256(code).hexdigest(),
            "address_table_sha256": hashlib.sha256(payload[4:code_offset]).hexdigest(),
        },
        "boundary": {
            "address_entry_index": address_entry_index,
            "address_entry_start": start,
            "address_entry_end": end,
            "route_source_start": int(route_row["source_offset"]),
            "terminal_start": terminal_span["start"],
            "terminal_end": terminal_span["end"],
            "terminal_raw_sha256": terminal_span["raw_sha256"],
            "physical_resume_start": resume_span["start"],
            "physical_resume_end": resume_span["end"],
            "physical_resume_raw_sha256": resume_span["raw_sha256"],
        },
        "groups": groups,
        "first_stage_options": first_options,
        "result_mapping": result_mapping,
        "coverage": {
            "group_count": len(groups),
            "definition_count": sum(group["definition_count"] for group in groups),
            "conditional_definition_count": conditional_count,
            "empty_group_count": sum(group["empty_after_clear"] for group in groups),
            "first_stage_option_count": len(first_options),
            "result_group_count": len(result_mapping["groups"]),
            "stored_second_route_count": stored_count,
            "fallback_second_route_count": fallback_count,
        },
        "invariants": copy.deepcopy(INVARIANTS),
    }


def _build_group(
    code: bytes,
    by_offset: dict[int, dict[str, Any]],
    source: dict[str, Any],
) -> dict[str, Any]:
    selector = int(source["selector"])
    clear = _instruction(by_offset, int(source["clear_offset"]), 0x1B)
    if _literal_record(clear) != selector:
        raise ChoiceGroupAuthoringProofError(
            "MES choice-group clear selector changed"
        )
    definitions = [
        _build_definition(code, by_offset, row)
        for row in source["registrations"]
    ]
    if [row["definition_id"] for row in definitions] != list(range(len(definitions))):
        raise ChoiceGroupAuthoringProofError(
            "MES choice-group definition identifiers are not sequential"
        )
    return {
        "selector": selector,
        "clear": _span(code, clear),
        "definition_count": len(definitions),
        "empty_after_clear": not definitions,
        "conditional_definition_count": sum(
            row["guard"]["kind"] != "unconditional" for row in definitions
        ),
        "definitions": definitions,
    }


def _build_definition(
    code: bytes,
    by_offset: dict[int, dict[str, Any]],
    source: dict[str, Any],
) -> dict[str, Any]:
    start = int(source["source_offset"])
    target = int(source["target_offset"])
    definition_id = int(source["definition_id"])
    instruction = _instruction(by_offset, start, 0x10)
    if _literal_record(instruction) != definition_id or _u32_target(instruction) != target:
        raise ChoiceGroupAuthoringProofError(
            "MES choice-group registration envelope changed"
        )
    registration = _span(code, instruction)
    body_start = registration["end"]
    if target <= body_start:
        raise ChoiceGroupAuthoringProofError(
            "MES choice-group definition body boundary changed"
        )
    message = _instruction(by_offset, body_start, 0x01)
    message_span = _span(code, message)
    operands = message.get("operands", [])
    operand = operands[0] if len(operands) == 1 else None
    if (
        not isinstance(operand, dict)
        or operand.get("type") != "cp932_string"
        or operand.get("decodeError")
        or not isinstance(operand.get("rawHex"), str)
    ):
        raise ChoiceGroupAuthoringProofError(
            "MES choice-group option is not one strict CP932 message"
        )
    payload = bytes.fromhex(operand["rawHex"])
    payload_start = message_span["start"] + 1
    payload_end = payload_start + len(payload)
    if (
        not payload
        or code[payload_start:payload_end] != payload
        or payload_end >= message_span["end"]
        or code[payload_end] != 0
        or message_span["end"] != payload_end + 1
    ):
        raise ChoiceGroupAuthoringProofError(
            "MES choice-group option message boundary changed"
        )
    return_record = _instruction(by_offset, message_span["end"], 0x00)
    return_span = _span(code, return_record)
    if return_span["end"] != target:
        raise ChoiceGroupAuthoringProofError(
            "MES choice-group option body is not one message then return"
        )
    body = code[body_start:target]
    guard_source = source.get("guard", {})
    guard_kind = str(guard_source.get("kind", ""))
    if guard_kind == "unconditional":
        guard = {
            "kind": "unconditional",
            "instruction": None,
            "predicate_sha256": hashlib.sha256(b"unconditional").hexdigest(),
        }
    else:
        guard_instruction = _instruction(
            by_offset, int(guard_source.get("source_offset", -1)), 0x0B
        )
        guard = {
            "kind": guard_kind,
            "instruction": _span(code, guard_instruction),
            "predicate_sha256": hashlib.sha256(
                json.dumps(
                    guard_source, ensure_ascii=False, allow_nan=False,
                    sort_keys=True, separators=(",", ":"),
                ).encode("utf-8")
            ).hexdigest(),
        }
    return {
        "definition_id": definition_id,
        "registration": registration,
        "body": {
            "start": body_start,
            "end": target,
            "size": len(body),
            "raw_sha256": hashlib.sha256(body).hexdigest(),
        },
        "message": {
            "instruction_start": message_span["start"],
            "instruction_end": message_span["end"],
            "instruction_raw_sha256": message_span["raw_sha256"],
            "payload_start": payload_start,
            "payload_end": payload_end,
            "payload_size": len(payload),
            "payload_raw_sha256": hashlib.sha256(payload).hexdigest(),
            "encoding": "cp932",
            "native_projection": "typed_cp932_string_source_decoder",
            "terminator_offset": payload_end,
            "terminator": 0,
        },
        "return_record": return_span,
        "guard": guard,
    }


def _build_result_mapping(
    code: bytes,
    by_offset: dict[int, dict[str, Any]],
    source: dict[str, Any],
    groups: list[dict[str, Any]],
) -> dict[str, Any]:
    if not source.get("ok", False):
        raise ChoiceGroupAuthoringProofError(
            "MES choice-group result mapping is incomplete"
        )
    default = source["default_continuation"]
    default_instruction = _instruction(
        by_offset, int(default["source_offset"]), 0x0C
    )
    default_row = {
        "instruction": _span(code, default_instruction),
        "destination_offset": int(default["destination_offset"]),
        "backward_transfer": bool(default["backward_transfer"]),
        "covers_unmatched_or_out_of_range_results": bool(
            default["covers_unmatched_or_out_of_range_results"]
        ),
        "gameplay_meaning": str(default["gameplay_meaning"]),
    }
    result_groups = []
    for source_group in source["groups"]:
        first_result = int(source_group["first_result"])
        group = groups[first_result]
        first_branch = _span(
            code,
            by_offset[int(source_group["first_branch_offset"])],
        )
        stored = {
            int(row["secondary_result"]): row
            for row in source_group["secondary_branches"]
        }
        second_routes = []
        unmatched = []
        for second_result, definition in enumerate(group["definitions"], 1):
            if second_result in stored:
                row = stored[second_result]
                branch = _span(code, by_offset[int(row["source_offset"])])
                resolution = "stored_consumer_coordinate"
                consumer = int(row["fallthrough_offset"])
                false_target = int(row["false_target_offset"])
            else:
                branch = None
                resolution = "stored_default_continuation"
                consumer = int(default["destination_offset"])
                false_target = int(default["destination_offset"])
                unmatched.append(second_result)
            second_routes.append({
                "second_result": second_result,
                "definition_id": definition["definition_id"],
                "registration_start": definition["registration"]["start"],
                "resolution": resolution,
                "branch": branch,
                "consumer_entry_offset": consumer,
                "false_target_offset": false_target,
            })
        result_groups.append({
            "first_result": first_result,
            "group_selector": int(source_group["group_selector"]),
            "first_branch": first_branch,
            "first_false_target": int(source_group["first_false_target_offset"]),
            "definition_count": group["definition_count"],
            "second_routes": second_routes,
            "secondary_mapping_complete": not unmatched,
            "unmatched_second_results": unmatched,
        })
    return {
        "kind": "one_based_state_u16_21_then_state_u16_13_dispatch",
        "first_result_storage": str(source["first_result_storage"]),
        "first_result_index": int(source["first_result_index"]),
        "second_result_storage": str(source["secondary_result_storage"]),
        "second_result_index": int(source["secondary_result_index"]),
        "first_result_values": [int(value) for value in source["first_result_values"]],
        "groups": result_groups,
        "complete_secondary_mapping": bool(source["complete_secondary_mapping"]),
        "default_continuation": default_row,
    }


def _validate_result_mapping(
    mapping: Any,
    groups: list[dict[str, Any]],
) -> tuple[int, int]:
    if (
        not isinstance(mapping, dict)
        or set(mapping) != RESULT_MAPPING_KEYS
        or mapping.get("kind")
        != "one_based_state_u16_21_then_state_u16_13_dispatch"
        or mapping.get("first_result_storage") != "state_u16"
        or mapping.get("first_result_index") != 21
        or mapping.get("second_result_storage") != "state_u16"
        or mapping.get("second_result_index") != 13
        or mapping.get("first_result_values") != list(range(1, len(groups)))
        or not isinstance(mapping.get("groups"), list)
        or len(mapping["groups"]) != len(groups) - 1
        or not isinstance(mapping.get("complete_secondary_mapping"), bool)
        or not _valid_default(mapping.get("default_continuation"))
    ):
        raise ChoiceGroupAuthoringProofError(
            "MES choice-group numeric result mapping changed"
        )
    stored_count = 0
    fallback_count = 0
    incomplete = False
    for index, row in enumerate(mapping["groups"], 1):
        group = groups[index]
        if (
            not isinstance(row, dict)
            or set(row) != RESULT_GROUP_KEYS
            or row.get("first_result") != index
            or row.get("group_selector") != index
            or not _valid_span(row.get("first_branch"))
            or not _is_nonnegative_int(row.get("first_false_target"))
            or row.get("definition_count") != group["definition_count"]
            or not isinstance(row.get("second_routes"), list)
            or len(row["second_routes"]) != group["definition_count"]
            or not isinstance(row.get("secondary_mapping_complete"), bool)
            or not isinstance(row.get("unmatched_second_results"), list)
        ):
            raise ChoiceGroupAuthoringProofError(
                "MES choice-group result group changed"
            )
        unmatched = []
        for second_index, route in enumerate(row["second_routes"], 1):
            definition = group["definitions"][second_index - 1]
            if (
                not isinstance(route, dict)
                or set(route) != SECOND_ROUTE_KEYS
                or route.get("second_result") != second_index
                or route.get("definition_id") != definition["definition_id"]
                or route.get("registration_start")
                != definition["registration"]["start"]
                or not _is_nonnegative_int(route.get("consumer_entry_offset"))
                or not _is_nonnegative_int(route.get("false_target_offset"))
            ):
                raise ChoiceGroupAuthoringProofError(
                    "MES choice-group second-stage route changed"
                )
            if route.get("resolution") == "stored_consumer_coordinate":
                if not _valid_span(route.get("branch")):
                    raise ChoiceGroupAuthoringProofError(
                        "MES choice-group stored result branch changed"
                    )
                stored_count += 1
            elif route.get("resolution") == "stored_default_continuation":
                if route.get("branch") is not None:
                    raise ChoiceGroupAuthoringProofError(
                        "MES choice-group fallback route grew a branch"
                    )
                unmatched.append(second_index)
                fallback_count += 1
            else:
                raise ChoiceGroupAuthoringProofError(
                    "MES choice-group second-stage resolution changed"
                )
        if row["unmatched_second_results"] != unmatched:
            raise ChoiceGroupAuthoringProofError(
                "MES choice-group unmatched result set changed"
            )
        if row["secondary_mapping_complete"] is not (not unmatched):
            raise ChoiceGroupAuthoringProofError(
                "MES choice-group result completion changed"
            )
        incomplete = incomplete or bool(unmatched)
    if mapping["complete_secondary_mapping"] is not (not incomplete):
        raise ChoiceGroupAuthoringProofError(
            "MES choice-group aggregate result completion changed"
        )
    return stored_count, fallback_count


def _valid_group(value: Any) -> bool:
    if (
        not isinstance(value, dict)
        or set(value) != GROUP_KEYS
        or not _is_nonnegative_int(value.get("selector"))
        or not _valid_span(value.get("clear"))
        or not _is_nonnegative_int(value.get("definition_count"))
        or not isinstance(value.get("empty_after_clear"), bool)
        or not _is_nonnegative_int(value.get("conditional_definition_count"))
        or not isinstance(value.get("definitions"), list)
        or value["definition_count"] != len(value["definitions"])
        or value["empty_after_clear"] is not (len(value["definitions"]) == 0)
    ):
        return False
    conditional = 0
    for index, definition in enumerate(value["definitions"]):
        if not _valid_definition(definition, index):
            return False
        conditional += int(definition["guard"]["kind"] != "unconditional")
    return conditional == value["conditional_definition_count"]


def _valid_definition(value: Any, definition_id: int) -> bool:
    if (
        not isinstance(value, dict)
        or set(value) != DEFINITION_KEYS
        or value.get("definition_id") != definition_id
        or not _valid_span(value.get("registration"))
        or not _valid_span(value.get("return_record"))
        or not isinstance(value.get("body"), dict)
        or set(value["body"]) != BODY_KEYS
        or not all(
            _is_nonnegative_int(value["body"].get(key))
            for key in ("start", "end", "size")
        )
        or not _is_sha256(value["body"].get("raw_sha256"))
        or value["body"]["end"] <= value["body"]["start"]
        or value["body"]["size"]
        != value["body"]["end"] - value["body"]["start"]
        or value["registration"]["end"] != value["body"]["start"]
        or value["return_record"]["end"] != value["body"]["end"]
        or not _valid_message(value.get("message"), value["body"])
        or not _valid_guard(value.get("guard"))
    ):
        return False
    return value["message"]["instruction_start"] == value["body"]["start"]


def _valid_message(value: Any, body: dict[str, Any]) -> bool:
    return (
        isinstance(value, dict)
        and set(value) == MESSAGE_KEYS
        and all(
            _is_nonnegative_int(value.get(key))
            for key in (
                "instruction_start", "instruction_end", "payload_start",
                "payload_end", "payload_size", "terminator_offset", "terminator",
            )
        )
        and _is_sha256(value.get("instruction_raw_sha256"))
        and _is_sha256(value.get("payload_raw_sha256"))
        and value["payload_start"] == value["instruction_start"] + 1
        and value["payload_end"] == value["terminator_offset"]
        and value["instruction_end"] == value["terminator_offset"] + 1
        and value["payload_size"] == value["payload_end"] - value["payload_start"]
        and value["payload_size"] > 0
        and value["terminator"] == 0
        and value["instruction_start"] == body["start"]
        and value["instruction_end"] < body["end"]
        and value["encoding"] == "cp932"
        and value["native_projection"]
        == "typed_cp932_string_source_decoder"
    )


def _valid_guard(value: Any) -> bool:
    if not isinstance(value, dict) or set(value) != GUARD_KEYS:
        return False
    if not isinstance(value.get("kind"), str) or not value["kind"]:
        return False
    if not _is_sha256(value.get("predicate_sha256")):
        return False
    if value["kind"] == "unconditional":
        return value.get("instruction") is None
    return _valid_span(value.get("instruction"))


def _valid_source(value: Any) -> bool:
    return (
        isinstance(value, dict)
        and set(value) == SOURCE_IDENTITY_KEYS
        and isinstance(value.get("archive"), str)
        and Path(value["archive"]).name == value["archive"]
        and isinstance(value.get("entry"), str)
        and Path(value["entry"]).name == value["entry"]
        and _is_sha256(value.get("archive_sha256"))
        and _is_sha256(value.get("entry_sha256"))
    )


def _valid_container(value: Any, source: dict[str, Any]) -> bool:
    return (
        isinstance(value, dict)
        and set(value) == CONTAINER_KEYS
        and all(
            _is_nonnegative_int(value.get(key))
            for key in ("size", "entry_count", "code_offset", "code_size")
        )
        and all(
            _is_sha256(value.get(key))
            for key in ("entry_sha256", "bytecode_sha256", "address_table_sha256")
        )
        and value["size"] == value["code_offset"] + value["code_size"]
        and value["entry_sha256"] == source["entry_sha256"]
    )


def _valid_boundary(value: Any, container: dict[str, Any]) -> bool:
    return (
        isinstance(value, dict)
        and set(value) == BOUNDARY_KEYS
        and all(
            _is_nonnegative_int(value.get(key))
            for key in (
                "address_entry_index", "address_entry_start", "address_entry_end",
                "route_source_start", "terminal_start", "terminal_end",
                "physical_resume_start", "physical_resume_end",
            )
        )
        and _is_sha256(value.get("terminal_raw_sha256"))
        and _is_sha256(value.get("physical_resume_raw_sha256"))
        and value["address_entry_start"] <= value["route_source_start"]
        and value["route_source_start"] <= value["terminal_start"]
        and value["terminal_end"] == value["physical_resume_start"]
        and value["physical_resume_end"] > value["physical_resume_start"]
        and value["address_entry_end"] <= container["code_size"]
    )


def _valid_default(value: Any) -> bool:
    return (
        isinstance(value, dict)
        and set(value) == DEFAULT_KEYS
        and _valid_span(value.get("instruction"))
        and _is_nonnegative_int(value.get("destination_offset"))
        and isinstance(value.get("backward_transfer"), bool)
        and value.get("covers_unmatched_or_out_of_range_results") is True
        and value.get("gameplay_meaning") == "unresolved"
    )


def _valid_span(value: Any) -> bool:
    return (
        isinstance(value, dict)
        and set(value) == SPAN_KEYS
        and _is_nonnegative_int(value.get("start"))
        and _is_nonnegative_int(value.get("end"))
        and value["end"] > value["start"]
        and _is_sha256(value.get("raw_sha256"))
    )


def _instruction(
    by_offset: dict[int, dict[str, Any]],
    offset: int,
    command_id: int,
) -> dict[str, Any]:
    value = by_offset.get(offset)
    if value is None or int(value.get("commandId", -1)) != command_id:
        raise ChoiceGroupAuthoringProofError(
            "MES choice-group expected instruction is missing"
        )
    return value


def _span(code: bytes, instruction: dict[str, Any]) -> dict[str, Any]:
    start = int(instruction["sourceOffset"])
    end = int(instruction["endOffset"])
    if start < 0 or end <= start or end > len(code):
        raise ChoiceGroupAuthoringProofError(
            "MES choice-group instruction span is invalid"
        )
    raw = code[start:end]
    if raw.hex() != str(instruction.get("rawHex", "")):
        raise ChoiceGroupAuthoringProofError(
            "MES choice-group instruction bytes changed"
        )
    return {
        "start": start,
        "end": end,
        "raw_sha256": hashlib.sha256(raw).hexdigest(),
    }


def _normalize_source_identity(
    payload: bytes,
    value: dict[str, Any],
) -> dict[str, Any]:
    if not isinstance(value, dict):
        raise ChoiceGroupAuthoringProofError(
            "MES choice-group source identity is missing"
        )
    archive = value.get("archive")
    entry = value.get("entry")
    archive_sha256 = value.get("archive_sha256")
    if (
        not isinstance(archive, str)
        or Path(archive).name != archive
        or not isinstance(entry, str)
        or Path(entry).name != entry
        or not _is_sha256(archive_sha256)
    ):
        raise ChoiceGroupAuthoringProofError(
            "MES choice-group source identity is invalid"
        )
    return {
        "archive": archive,
        "archive_sha256": archive_sha256,
        "entry": entry,
        "entry_sha256": hashlib.sha256(payload).hexdigest(),
    }


def _is_nonnegative_int(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value >= 0


def main() -> None:
    parser = argparse.ArgumentParser(
        description=(
            "Prove exact command-0x10 group, option-message, numeric result, "
            "routine-40, and physical-resume boundaries without exporting text."
        )
    )
    parser.add_argument("archive", type=Path)
    parser.add_argument("entry")
    parser.add_argument("address_entry", type=int)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    archive = args.archive.resolve()
    output = args.output.resolve()
    if (
        output == archive
        or output == archive.parent
        or archive.parent in output.parents
        or output.exists()
    ):
        raise ChoiceGroupAuthoringProofError(
            "MES choice-group proof output must be a new path outside the source directory"
        )
    payload, _source = load_archive_entry(archive, args.entry)
    source_identity = {
        "archive": archive.name,
        "archive_sha256": _sha256_file(archive),
        "entry": args.entry,
    }
    document = prove_entry(payload, source_identity, args.address_entry)
    encoded = json.dumps(
        document, ensure_ascii=False, allow_nan=False, sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8") + b"\n"
    temporary = output.with_name(output.name + ".tmp")
    output.parent.mkdir(parents=True, exist_ok=True)
    try:
        with temporary.open("xb") as destination:
            destination.write(encoded)
        temporary.replace(output)
    except BaseException:
        if temporary.is_file():
            temporary.unlink()
        raise
    print(
        "MES_CHOICE_GROUP_AUTHORING_PROOF_PASS "
        f"schema={SCHEMA} entry={document['source_identity']['entry']} "
        f"address_entry={document['boundary']['address_entry_index']} "
        f"groups={document['coverage']['group_count']} "
        f"definitions={document['coverage']['definition_count']} "
        f"first_options={document['coverage']['first_stage_option_count']} "
        f"stored_routes={document['coverage']['stored_second_route_count']} "
        f"fallback_routes={document['coverage']['fallback_second_route_count']} "
        f"payload_sha256={document['payload_sha256']}"
    )


if __name__ == "__main__":
    main()
