from __future__ import annotations

import argparse
import copy
import hashlib
import json
from pathlib import Path
from typing import Any

import prepare_mes_editable_ir as editable_ir
import prove_mes_shared_call_returns as call_prover
from payload_values import canonical_payload_bytes, fingerprint, is_sha256 as _is_sha256


PLAN_SCHEMA = "kakyu_mes_shared_routine_call_edit_plan/v1"
TOP_LEVEL_KEYS = {
    "ok", "schema", "producer", "compatibility", "source_identity",
    "library_identity", "inputs", "operation", "target", "replacement",
    "assembly_ready", "invariants", "payload_sha256",
}
OPERATION_KEYS = {
    "kind", "source_offset", "instruction_raw_sha256", "routine_id",
}
TARGET_KEYS = {
    "node_id", "region_id", "op", "command_id", "instruction_start",
    "instruction_end", "instruction_raw_hex", "instruction_raw_sha256",
    "record_list_start", "record_list_end", "expression_start",
    "expression_end", "expression_raw_hex", "expression_raw_sha256",
    "literal_start", "literal_end", "literal_raw_hex", "literal_raw_sha256",
    "routine_id", "width", "expression_terminator_offset",
    "expression_terminator", "record_terminator_offset", "record_terminator",
    "call_proof",
}
REPLACEMENT_KEYS = {
    "routine_id", "width", "literal_raw_hex", "literal_raw_sha256",
    "expression_raw_hex", "expression_raw_sha256", "instruction_raw_hex",
    "instruction_raw_sha256", "callee_proof",
}
CALL_PROOF_KEYS = {
    "id", "call_node_id", "call_start", "call_end",
    "physical_resume_offset", "physical_resume_node_id",
    "physical_resume_region", "physical_resume_raw_sha256", "routine_id",
    "callee_entry", "callee_registration_offset", "callee_body_start",
    "callee_body_end", "callee_return_offsets", "direct_callee_routine_ids",
    "transitive_callee_routine_ids", "proof_status",
}
CALLEE_PROOF_KEYS = {
    "routine_id", "callee_entry", "registration_offset", "body_start",
    "body_end", "return_offsets", "direct_callee_routine_ids",
    "transitive_callee_routine_ids", "proof_status",
}
SOURCE_IDENTITY_KEYS = {"archive", "entry", "source_kind", "archive_sha256"}
LIBRARY_IDENTITY_KEYS = {
    "archive_name", "archive_sha256", "entry", "entry_sha256",
}
COMPATIBILITY = {
    "policy": "planning_only_same_width_literal_shared_routine_call_replacement",
    "input_editable_schema": editable_ir.EDITABLE_IR_SCHEMA,
    "input_decompiler_schema": "kakyu_mes_decompiler_ir/v1",
    "input_shared_call_proof_schema": call_prover.SHARED_CALL_RETURN_PROOF_SCHEMA,
    "input_library_audit_schema": call_prover.LIBRARY_AUDIT_SCHEMA,
    "supported_operation": "replace_shared_routine_literal",
    "supported_instruction": {"op": "script_transfer", "command_id": 0x1D},
    "supported_literal_widths": [8],
    "u8_literal_policy": "unambiguous_token_00_through_7f_only",
    "selection_policy": "one_exact_typed_call_and_unique_physical_resume_node",
    "callee_policy": "source_and_replacement_require_total_return_certificates",
    "length_policy": "replacement_literal_must_match_source_length",
    "binary_publication": "forbidden",
    "native_engine_compatibility": "unverified",
    "unknown_plan_schema": "reject",
    "unknown_v1_field": "reject",
}
INVARIANTS = {
    "source_editable_ir_validated": True,
    "source_call_return_proof_validated": True,
    "library_audit_validated": True,
    "target_node_unique_and_typed": True,
    "source_instruction_hash_matched": True,
    "source_literal_expression_exact": True,
    "physical_resume_node_unique": True,
    "source_callee_total_return_proved": True,
    "replacement_callee_total_return_proved": True,
    "replacement_literal_same_width_and_length": True,
    "expression_and_record_terminators_unchanged": True,
    "all_other_instruction_bytes_unchanged": True,
    "opaque_bytes_not_rewritten": True,
    "binary_not_published": True,
}


class SharedRoutineCallEditPlanError(ValueError):
    pass


def plan(
    editable_document: dict[str, Any],
    shared_call_proof: dict[str, Any],
    library_audit: dict[str, Any],
    operation: dict[str, Any],
) -> dict[str, Any]:
    result = _build_plan(
        editable_document, shared_call_proof, library_audit, operation
    )
    result["payload_sha256"] = fingerprint(result)
    validate(result, editable_document, shared_call_proof, library_audit)
    return result


def validate(
    document: dict[str, Any],
    editable_document: dict[str, Any] | None = None,
    shared_call_proof: dict[str, Any] | None = None,
    library_audit: dict[str, Any] | None = None,
) -> dict[str, Any]:
    if (
        document.get("ok") is not True
        or document.get("schema") != PLAN_SCHEMA
        or set(document) != TOP_LEVEL_KEYS
    ):
        raise SharedRoutineCallEditPlanError(
            "MES shared-routine call edit plan schema or fields changed"
        )
    if document.get("producer") != {
        "implementation": "python_phase6_shared_routine_call_edit_planner",
        "contract": PLAN_SCHEMA,
    }:
        raise SharedRoutineCallEditPlanError(
            "MES shared-routine call edit plan producer changed"
        )
    if document.get("compatibility") != COMPATIBILITY:
        raise SharedRoutineCallEditPlanError(
            "MES shared-routine call edit compatibility changed"
        )
    retained = document.get("payload_sha256")
    if not _is_sha256(retained) or fingerprint(document) != retained:
        raise SharedRoutineCallEditPlanError(
            "MES shared-routine call edit plan fingerprint changed"
        )
    operation = document.get("operation")
    if not isinstance(operation, dict) or set(operation) != OPERATION_KEYS:
        raise SharedRoutineCallEditPlanError(
            "MES shared-routine call edit operation fields changed"
        )
    operation = _validate_operation(operation)
    source_identity = document.get("source_identity")
    if (
        not isinstance(source_identity, dict)
        or not set(source_identity).issubset(SOURCE_IDENTITY_KEYS)
        or not isinstance(source_identity.get("archive"), str)
        or not source_identity["archive"]
        or not isinstance(source_identity.get("entry"), str)
        or not source_identity["entry"]
        or (
            "archive_sha256" in source_identity
            and not _is_sha256(source_identity["archive_sha256"])
        )
    ):
        raise SharedRoutineCallEditPlanError(
            "MES shared-routine call edit source identity changed"
        )
    library_identity = document.get("library_identity")
    if (
        not isinstance(library_identity, dict)
        or set(library_identity) != LIBRARY_IDENTITY_KEYS
        or library_identity.get("entry") != "LIBLARY.LIB"
        or not isinstance(library_identity.get("archive_name"), str)
        or not _is_sha256(library_identity.get("archive_sha256"))
        or not _is_sha256(library_identity.get("entry_sha256"))
    ):
        raise SharedRoutineCallEditPlanError(
            "MES shared-routine call edit library identity changed"
        )
    inputs = document.get("inputs")
    expected_input_keys = {
        "editable_ir_sha256", "decompiler_ir_sha256",
        "shared_call_return_proof_sha256", "library_audit_sha256",
    }
    if (
        not isinstance(inputs, dict)
        or set(inputs) != expected_input_keys
        or not all(_is_sha256(value) for value in inputs.values())
    ):
        raise SharedRoutineCallEditPlanError(
            "MES shared-routine call edit input identity changed"
        )
    target = document.get("target")
    replacement = document.get("replacement")
    if not isinstance(target, dict) or set(target) != TARGET_KEYS:
        raise SharedRoutineCallEditPlanError(
            "MES shared-routine call edit target fields changed"
        )
    if not isinstance(replacement, dict) or set(replacement) != REPLACEMENT_KEYS:
        raise SharedRoutineCallEditPlanError(
            "MES shared-routine call edit replacement fields changed"
        )
    if (
        target.get("op") != "script_transfer"
        or target.get("command_id") != 0x1D
        or not isinstance(target.get("node_id"), str)
        or not target["node_id"]
        or not isinstance(target.get("region_id"), str)
        or not target["region_id"]
        or target.get("instruction_start") != operation["source_offset"]
        or target.get("instruction_raw_sha256")
        != operation["instruction_raw_sha256"]
        or replacement.get("routine_id") != operation["routine_id"]
    ):
        raise SharedRoutineCallEditPlanError(
            "MES shared-routine call edit typed target identity changed"
        )
    _validate_plan_bytes(target, replacement, library_identity)
    if document.get("assembly_ready") is not True:
        raise SharedRoutineCallEditPlanError(
            "MES shared-routine call edit plan is not assembly ready"
        )
    if document.get("invariants") != INVARIANTS:
        raise SharedRoutineCallEditPlanError(
            "MES shared-routine call edit invariants changed"
        )
    supplied = (editable_document, shared_call_proof, library_audit)
    if any(value is not None for value in supplied):
        if any(value is None for value in supplied):
            raise SharedRoutineCallEditPlanError(
                "MES shared-routine call edit source validation inputs are incomplete"
            )
        expected = _build_plan(
            editable_document,
            shared_call_proof,
            library_audit,
            copy.deepcopy(operation),
        )
        expected["payload_sha256"] = fingerprint(expected)
        if expected != document:
            raise SharedRoutineCallEditPlanError(
                "MES shared-routine call edit plan differs from its source"
            )
    return {"ok": True, "schema": PLAN_SCHEMA, "payload_sha256": retained}


def _build_plan(
    editable_document: dict[str, Any],
    shared_call_proof: dict[str, Any],
    library_audit: dict[str, Any],
    raw_operation: dict[str, Any],
) -> dict[str, Any]:
    editable_ir.validate(editable_document)
    operation = _validate_operation(raw_operation)
    source_ir = editable_document["source_ir"]
    call_prover.validate(shared_call_proof, source_ir, library_audit)
    routines = _routine_rows(library_audit)
    return_contracts = _return_contracts(shared_call_proof)
    owners = [
        node for node in source_ir["nodes"]
        if int(node.get("source", {}).get("start", -1)) == operation["source_offset"]
    ]
    if len(owners) != 1:
        raise SharedRoutineCallEditPlanError(
            "MES shared-routine call edit target is not one unique node"
        )
    owner = owners[0]
    source = owner.get("source")
    statement = owner.get("statement")
    if (
        owner.get("kind") != "statement"
        or not isinstance(source, dict)
        or not isinstance(statement, dict)
        or statement.get("kind") != "instruction"
        or statement.get("op") != "script_transfer"
        or statement.get("command_id") != 0x1D
    ):
        raise SharedRoutineCallEditPlanError(
            "MES shared-routine call edit target is not a typed command-0x1D call"
        )
    instruction_raw = _hex_bytes(source.get("raw_hex"), "instruction source")
    if hashlib.sha256(instruction_raw).hexdigest() != operation["instruction_raw_sha256"]:
        raise SharedRoutineCallEditPlanError(
            "MES shared-routine call edit instruction source hash is stale"
        )
    instruction_start = int(source.get("start", -1))
    instruction_end = int(source.get("end", -1))
    if instruction_end - instruction_start != len(instruction_raw):
        raise SharedRoutineCallEditPlanError(
            "MES shared-routine call edit instruction boundary changed"
        )
    record_list, expression, ast = _literal_expression(statement)
    source_routine_id = ast.get("value")
    width = ast.get("width")
    if not _is_int(source_routine_id) or width != 8:
        raise SharedRoutineCallEditPlanError(
            "MES shared-routine call edit selector is not an exact 8-bit literal"
        )
    expression_raw = _encode_literal(source_routine_id)
    expression_start = int(expression.get("offset", -1))
    expression_end = int(expression.get("end_offset", -1))
    literal_start = int(ast.get("source", {}).get("offset", -1))
    literal_end = literal_start + 1
    record_list_start = int(record_list.get("source_offset", -1))
    record_list_end = int(record_list.get("end_offset", -1))
    if (
        _hex_bytes(expression.get("raw_hex"), "expression source") != expression_raw
        or int(expression.get("byte_length", -1)) != len(expression_raw)
        or record_list_start != instruction_start + 1
        or expression_start != record_list_start + 1
        or literal_start != expression_start
        or expression_end != literal_end + 1
        or record_list_end != instruction_end
        or instruction_raw != bytes((0x1D, 0x02)) + expression_raw + b"\x00"
    ):
        raise SharedRoutineCallEditPlanError(
            "MES shared-routine call edit literal record boundary changed"
        )
    source_call = _source_call_proof(
        shared_call_proof, owner, source_ir, routines, source_routine_id,
        instruction_start, instruction_end
    )
    replacement_routine_id = operation["routine_id"]
    if replacement_routine_id == source_routine_id:
        raise SharedRoutineCallEditPlanError(
            "MES shared-routine call edit replacement is unchanged"
        )
    replacement_callee = _callee_proof(
        routines, return_contracts, replacement_routine_id, str(library_audit["entry"])
    )
    replacement_expression = _encode_literal(replacement_routine_id)
    replacement_instruction = bytes((0x1D, 0x02)) + replacement_expression + b"\x00"
    library_identity = {
        "archive_name": str(library_audit["archive_name"]),
        "archive_sha256": str(library_audit["archive_sha256"]),
        "entry": str(library_audit["entry"]),
        "entry_sha256": str(library_audit["entry_sha256"]),
    }
    return {
        "ok": True,
        "schema": PLAN_SCHEMA,
        "producer": {
            "implementation": "python_phase6_shared_routine_call_edit_planner",
            "contract": PLAN_SCHEMA,
        },
        "compatibility": copy.deepcopy(COMPATIBILITY),
        "source_identity": copy.deepcopy(source_ir["source_identity"]),
        "library_identity": library_identity,
        "inputs": {
            "editable_ir_sha256": editable_document["payload_sha256"],
            "decompiler_ir_sha256": source_ir["payload_sha256"],
            "shared_call_return_proof_sha256": shared_call_proof["payload_sha256"],
            "library_audit_sha256": call_prover.input_fingerprint(library_audit),
        },
        "operation": copy.deepcopy(operation),
        "target": {
            "node_id": str(owner["id"]),
            "region_id": str(source["region"]),
            "op": "script_transfer",
            "command_id": 0x1D,
            "instruction_start": instruction_start,
            "instruction_end": instruction_end,
            "instruction_raw_hex": instruction_raw.hex(),
            "instruction_raw_sha256": hashlib.sha256(instruction_raw).hexdigest(),
            "record_list_start": record_list_start,
            "record_list_end": record_list_end,
            "expression_start": expression_start,
            "expression_end": expression_end,
            "expression_raw_hex": expression_raw.hex(),
            "expression_raw_sha256": hashlib.sha256(expression_raw).hexdigest(),
            "literal_start": literal_start,
            "literal_end": literal_end,
            "literal_raw_hex": bytes((source_routine_id,)).hex(),
            "literal_raw_sha256": hashlib.sha256(bytes((source_routine_id,))).hexdigest(),
            "routine_id": source_routine_id,
            "width": 8,
            "expression_terminator_offset": literal_end,
            "expression_terminator": 0xFF,
            "record_terminator_offset": expression_end,
            "record_terminator": 0,
            "call_proof": source_call,
        },
        "replacement": {
            "routine_id": replacement_routine_id,
            "width": 8,
            "literal_raw_hex": bytes((replacement_routine_id,)).hex(),
            "literal_raw_sha256": hashlib.sha256(bytes((replacement_routine_id,))).hexdigest(),
            "expression_raw_hex": replacement_expression.hex(),
            "expression_raw_sha256": hashlib.sha256(replacement_expression).hexdigest(),
            "instruction_raw_hex": replacement_instruction.hex(),
            "instruction_raw_sha256": hashlib.sha256(replacement_instruction).hexdigest(),
            "callee_proof": replacement_callee,
        },
        "assembly_ready": True,
        "invariants": copy.deepcopy(INVARIANTS),
    }


def _literal_expression(statement: dict[str, Any]) -> tuple[dict, dict, dict]:
    operands = statement.get("operands")
    if not isinstance(operands, list) or len(operands) != 1:
        raise SharedRoutineCallEditPlanError(
            "MES shared-routine call edit operand shape is not one record list"
        )
    record_list = operands[0]
    records = record_list.get("records") if isinstance(record_list, dict) else None
    if (
        not isinstance(record_list, dict)
        or record_list.get("type") != "record_list"
        or not isinstance(records, list)
        or len(records) != 1
    ):
        raise SharedRoutineCallEditPlanError(
            "MES shared-routine call edit selector is not one record"
        )
    record = records[0]
    expression = record.get("value") if isinstance(record, dict) else None
    ast = expression.get("ast") if isinstance(expression, dict) else None
    if (
        not isinstance(record, dict)
        or record.get("type") != "expression_record"
        or record.get("tag") != 0x02
        or not isinstance(expression, dict)
        or not isinstance(ast, dict)
        or ast.get("type") != "literal"
        or not isinstance(ast.get("source"), dict)
    ):
        raise SharedRoutineCallEditPlanError(
            "MES shared-routine call edit selector is not one typed literal expression"
        )
    return record_list, expression, ast


def _source_call_proof(
    proof: dict[str, Any], owner: dict[str, Any], source_ir: dict[str, Any],
    routines: dict[int, dict[str, Any]], routine_id: int,
    instruction_start: int, instruction_end: int,
) -> dict[str, Any]:
    matches = [
        row for row in proof["proved_calls"]
        if row.get("call_start") == instruction_start
        and row.get("call_node_id") == owner.get("id")
    ]
    if len(matches) != 1:
        raise SharedRoutineCallEditPlanError(
            "MES shared-routine call edit has no unique proved source call"
        )
    call = matches[0]
    if (
        call.get("call_end") != instruction_end
        or call.get("physical_resume_offset") != instruction_end
        or call.get("routine_id") != routine_id
        or call.get("proof_status")
        != "literal_shared_call_all_callee_terminals_return_to_physical_resume"
    ):
        raise SharedRoutineCallEditPlanError(
            "MES shared-routine call edit source call proof changed"
        )
    resume_nodes = [
        node for node in source_ir["nodes"]
        if int(node.get("source", {}).get("start", -1)) == instruction_end
        and node.get("source", {}).get("entry") == owner.get("source", {}).get("entry")
    ]
    if len(resume_nodes) != 1:
        raise SharedRoutineCallEditPlanError(
            "MES shared-routine call edit physical resume node is not unique"
        )
    resume = resume_nodes[0]
    resume_source = resume.get("source", {})
    callee = routines.get(routine_id)
    if callee is None:
        raise SharedRoutineCallEditPlanError(
            "MES shared-routine call edit source callee disappeared"
        )
    flow = callee["native_dispatch_flow"]
    if (
        call.get("callee_body_start") != callee.get("body_offset")
        or call.get("callee_body_end") != callee.get("end_offset")
        or call.get("callee_return_offsets")
        != sorted(int(value) for value in flow["return_offsets"])
    ):
        raise SharedRoutineCallEditPlanError(
            "MES shared-routine call edit source callee boundary changed"
        )
    return {
        "id": str(call["id"]),
        "call_node_id": str(call["call_node_id"]),
        "call_start": int(call["call_start"]),
        "call_end": int(call["call_end"]),
        "physical_resume_offset": int(call["physical_resume_offset"]),
        "physical_resume_node_id": str(resume["id"]),
        "physical_resume_region": str(resume_source["region"]),
        "physical_resume_raw_sha256": str(resume_source["raw_sha256"]),
        "routine_id": routine_id,
        "callee_entry": str(call["callee_entry"]),
        "callee_registration_offset": int(callee["registration_offset"]),
        "callee_body_start": int(call["callee_body_start"]),
        "callee_body_end": int(call["callee_body_end"]),
        "callee_return_offsets": copy.deepcopy(call["callee_return_offsets"]),
        "direct_callee_routine_ids": copy.deepcopy(call["direct_callee_routine_ids"]),
        "transitive_callee_routine_ids": copy.deepcopy(call["transitive_callee_routine_ids"]),
        "proof_status": str(call["proof_status"]),
    }


def _callee_proof(
    routines: dict[int, dict[str, Any]], contracts: dict[int, dict[str, Any]],
    routine_id: int, library_entry: str,
) -> dict[str, Any]:
    routine = routines.get(routine_id)
    contract = contracts.get(routine_id)
    if routine is None or contract is None or contract.get("proved") is not True:
        raise SharedRoutineCallEditPlanError(
            "MES shared-routine call edit replacement callee has no total-return proof"
        )
    flow = routine["native_dispatch_flow"]
    return {
        "routine_id": routine_id,
        "callee_entry": library_entry,
        "registration_offset": int(routine["registration_offset"]),
        "body_start": int(routine["body_offset"]),
        "body_end": int(routine["end_offset"]),
        "return_offsets": sorted(int(value) for value in flow["return_offsets"]),
        "direct_callee_routine_ids": copy.deepcopy(contract["direct_callee_routine_ids"]),
        "transitive_callee_routine_ids": copy.deepcopy(contract["transitive_callee_routine_ids"]),
        "proof_status": "replacement_shared_routine_total_return_proved",
    }


def _routine_rows(library_audit: dict[str, Any]) -> dict[int, dict[str, Any]]:
    validated = call_prover._validate_library_audit(library_audit)
    for routine in validated.values():
        if not _is_int(routine.get("registration_offset")):
            raise SharedRoutineCallEditPlanError(
                "MES shared-routine call edit library registration offset is missing"
            )
    return validated


def _return_contracts(proof: dict[str, Any]) -> dict[int, dict[str, Any]]:
    rows = proof.get("routine_return_contracts")
    if not isinstance(rows, list):
        raise SharedRoutineCallEditPlanError(
            "MES shared-routine call edit return contracts changed"
        )
    result: dict[int, dict[str, Any]] = {}
    for row in rows:
        if not isinstance(row, dict) or not _is_int(row.get("routine_id")):
            raise SharedRoutineCallEditPlanError(
                "MES shared-routine call edit return contract changed"
            )
        routine_id = int(row["routine_id"])
        if routine_id in result:
            raise SharedRoutineCallEditPlanError(
                "MES shared-routine call edit return contract is duplicated"
            )
        result[routine_id] = row
    return result


def _validate_plan_bytes(
    target: dict[str, Any], replacement: dict[str, Any], library_identity: dict[str, Any]
) -> None:
    integer_target_keys = {
        "command_id", "instruction_start", "instruction_end", "record_list_start",
        "record_list_end", "expression_start", "expression_end", "literal_start",
        "literal_end", "routine_id", "width", "expression_terminator_offset",
        "expression_terminator", "record_terminator_offset", "record_terminator",
    }
    if any(not _is_int(target.get(key)) or int(target[key]) < 0 for key in integer_target_keys):
        raise SharedRoutineCallEditPlanError(
            "MES shared-routine call edit target coordinate changed"
        )
    if (
        not _is_int(replacement.get("routine_id"))
        or not _is_int(replacement.get("width"))
        or target["width"] != 8
        or replacement["width"] != 8
        or target["routine_id"] == replacement["routine_id"]
    ):
        raise SharedRoutineCallEditPlanError(
            "MES shared-routine call edit replacement literal changed"
        )
    source_instruction = _checked_bytes(target, "instruction")
    source_expression = _checked_bytes(target, "expression")
    source_literal = _checked_bytes(target, "literal")
    output_instruction = _checked_bytes(replacement, "instruction")
    output_expression = _checked_bytes(replacement, "expression")
    output_literal = _checked_bytes(replacement, "literal")
    if (
        source_literal != bytes((target["routine_id"],))
        or output_literal != bytes((replacement["routine_id"],))
        or source_expression != source_literal + b"\xFF"
        or output_expression != output_literal + b"\xFF"
        or source_instruction != b"\x1D\x02" + source_expression + b"\x00"
        or output_instruction != b"\x1D\x02" + output_expression + b"\x00"
        or len(source_instruction) != len(output_instruction)
    ):
        raise SharedRoutineCallEditPlanError(
            "MES shared-routine call edit planned instruction bytes changed"
        )
    start = int(target["instruction_start"])
    if (
        int(target["instruction_end"]) != start + len(source_instruction)
        or int(target["record_list_start"]) != start + 1
        or int(target["expression_start"]) != start + 2
        or int(target["literal_start"]) != start + 2
        or int(target["literal_end"]) != start + 3
        or int(target["expression_terminator_offset"]) != start + 3
        or int(target["expression_end"]) != start + 4
        or int(target["record_terminator_offset"]) != start + 4
        or int(target["record_list_end"]) != start + 5
        or int(target["expression_terminator"]) != 0xFF
        or int(target["record_terminator"]) != 0
    ):
        raise SharedRoutineCallEditPlanError(
            "MES shared-routine call edit planned record boundary changed"
        )
    call = target.get("call_proof")
    callee = replacement.get("callee_proof")
    if not isinstance(call, dict) or set(call) != CALL_PROOF_KEYS:
        raise SharedRoutineCallEditPlanError(
            "MES shared-routine call edit source call proof fields changed"
        )
    if not isinstance(callee, dict) or set(callee) != CALLEE_PROOF_KEYS:
        raise SharedRoutineCallEditPlanError(
            "MES shared-routine call edit replacement callee proof fields changed"
        )
    if (
        call.get("call_start") != start
        or call.get("call_end") != target["instruction_end"]
        or call.get("physical_resume_offset") != target["instruction_end"]
        or call.get("routine_id") != target["routine_id"]
        or call.get("callee_entry") != library_identity["entry"]
        or call.get("proof_status")
        != "literal_shared_call_all_callee_terminals_return_to_physical_resume"
        or not _is_sha256(call.get("physical_resume_raw_sha256"))
        or callee.get("routine_id") != replacement["routine_id"]
        or callee.get("callee_entry") != library_identity["entry"]
        or callee.get("proof_status") != "replacement_shared_routine_total_return_proved"
    ):
        raise SharedRoutineCallEditPlanError(
            "MES shared-routine call edit call or callee proof changed"
        )
    for row, keys in (
        (call, ("call_start", "call_end", "physical_resume_offset", "routine_id",
                "callee_registration_offset", "callee_body_start", "callee_body_end")),
        (callee, ("routine_id", "registration_offset", "body_start", "body_end")),
    ):
        if any(not _is_int(row.get(key)) or int(row[key]) < 0 for key in keys):
            raise SharedRoutineCallEditPlanError(
                "MES shared-routine call edit proof coordinate changed"
            )
    for row, keys in (
        (call, ("callee_return_offsets", "direct_callee_routine_ids", "transitive_callee_routine_ids")),
        (callee, ("return_offsets", "direct_callee_routine_ids", "transitive_callee_routine_ids")),
    ):
        for key in keys:
            values = row.get(key)
            if (
                not isinstance(values, list)
                or any(not _is_int(value) or value < 0 for value in values)
                or values != sorted(set(values))
            ):
                raise SharedRoutineCallEditPlanError(
                    "MES shared-routine call edit proof list changed"
                )


def _checked_bytes(row: dict[str, Any], prefix: str) -> bytes:
    raw = _hex_bytes(row.get(f"{prefix}_raw_hex"), f"planned {prefix}")
    if row.get(f"{prefix}_raw_sha256") != hashlib.sha256(raw).hexdigest():
        raise SharedRoutineCallEditPlanError(
            "MES shared-routine call edit planned hash changed"
        )
    return raw


def _validate_operation(raw: dict[str, Any]) -> dict[str, Any]:
    if not isinstance(raw, dict) or set(raw) != OPERATION_KEYS:
        raise SharedRoutineCallEditPlanError(
            "MES shared-routine call edit operation fields changed"
        )
    if raw.get("kind") != "replace_shared_routine_literal":
        raise SharedRoutineCallEditPlanError(
            "unsupported MES shared-routine call edit operation"
        )
    for key in ("source_offset", "routine_id"):
        if not _is_int(raw.get(key)) or int(raw[key]) < 0:
            raise SharedRoutineCallEditPlanError(
                f"MES shared-routine call edit {key} is invalid"
            )
    if raw["routine_id"] > 0x7F:
        raise SharedRoutineCallEditPlanError(
            "MES shared-routine call edit 8-bit literal is not an unambiguous token"
        )
    if not _is_sha256(raw.get("instruction_raw_sha256")):
        raise SharedRoutineCallEditPlanError(
            "MES shared-routine call edit source hash is invalid"
        )
    return copy.deepcopy(raw)


def _encode_literal(value: Any) -> bytes:
    if not _is_int(value) or not 0 <= value <= 0x7F:
        raise SharedRoutineCallEditPlanError(
            "MES shared-routine call edit 8-bit literal is not an unambiguous token"
        )
    return bytes((value, 0xFF))


def _hex_bytes(value: Any, label: str) -> bytes:
    if not isinstance(value, str):
        raise SharedRoutineCallEditPlanError(
            f"MES shared-routine call edit {label} bytes are missing"
        )
    try:
        return bytes.fromhex(value)
    except ValueError as error:
        raise SharedRoutineCallEditPlanError(
            f"MES shared-routine call edit {label} bytes are invalid"
        ) from error


def _is_int(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool)


def main() -> None:
    parser = argparse.ArgumentParser(
        description=(
            "Build a fail-closed JSON plan for one typed command-0x1D literal "
            "whose source and replacement shared routines both have exact "
            "total-return evidence. This tool never publishes MES bytes."
        )
    )
    parser.add_argument("editable_ir", type=Path)
    parser.add_argument("shared_call_proof", type=Path)
    parser.add_argument("library_audit", type=Path)
    parser.add_argument("operation", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    paths = [
        args.editable_ir.resolve(), args.shared_call_proof.resolve(),
        args.library_audit.resolve(), args.operation.resolve(), args.output.resolve(),
    ]
    if len(set(paths)) != len(paths):
        raise SharedRoutineCallEditPlanError(
            "MES shared-routine call edit paths must be distinct"
        )
    try:
        editable_document = json.loads(args.editable_ir.read_text(encoding="utf-8"))
        shared_call_proof = json.loads(args.shared_call_proof.read_text(encoding="utf-8"))
        library_audit = json.loads(args.library_audit.read_text(encoding="utf-8"))
        operation = json.loads(args.operation.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise SharedRoutineCallEditPlanError(
            "MES shared-routine call edit input could not be read"
        ) from error
    if not all(
        isinstance(value, dict)
        for value in (editable_document, shared_call_proof, library_audit, operation)
    ):
        raise SharedRoutineCallEditPlanError(
            "MES shared-routine call edit input is not an object"
        )
    document = plan(
        editable_document, shared_call_proof, library_audit, operation
    )
    payload = json.dumps(
        document,
        ensure_ascii=False,
        allow_nan=False,
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8") + b"\n"
    editable_ir.publish_new(args.output, payload)
    print(
        "MES_SHARED_ROUTINE_CALL_EDIT_PLAN_PASS "
        f"schema={document['schema']} "
        f"entry={document['source_identity'].get('entry', '')} "
        f"offset={document['target']['instruction_start']} "
        f"source_routine={document['target']['routine_id']} "
        f"replacement_routine={document['replacement']['routine_id']} "
        f"resume={document['target']['call_proof']['physical_resume_offset']} "
        "mes_bytes=false "
        f"payload_sha256={document['payload_sha256']}"
    )


if __name__ == "__main__":
    main()
