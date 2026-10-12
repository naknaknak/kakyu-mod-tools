from __future__ import annotations

import argparse
import copy
import hashlib
import json
from pathlib import Path
from typing import Any

import prepare_mes_editable_ir as editable_ir
import prove_mes_call_families as call_prover
import prove_mes_registered_definition_registry as registry_prover
from payload_values import canonical_payload_bytes, fingerprint, is_sha256 as _is_sha256


PLAN_SCHEMA = "kakyu_mes_registered_definition_call_edit_plan/v1"
TOP_LEVEL_KEYS = {
    "ok", "schema", "producer", "compatibility", "source_identity",
    "registry_identity", "inputs", "operation", "target", "replacement",
    "assembly_ready", "invariants", "payload_sha256",
}
OPERATION_KEYS = {
    "kind", "source_offset", "instruction_raw_sha256", "selector",
}
TARGET_KEYS = {
    "node_id", "region_id", "op", "command_id", "instruction_start",
    "instruction_end", "instruction_raw_hex", "instruction_raw_sha256",
    "record_list_start", "record_list_end", "expression_start",
    "expression_end", "expression_raw_hex", "expression_raw_sha256",
    "literal_start", "literal_end", "literal_raw_hex", "literal_raw_sha256",
    "selector", "width", "expression_terminator_offset",
    "expression_terminator", "record_terminator_offset", "record_terminator",
    "call_proof", "registry_binding",
}
REPLACEMENT_KEYS = {
    "selector", "width", "literal_raw_hex", "literal_raw_sha256",
    "expression_raw_hex", "expression_raw_sha256", "instruction_raw_hex",
    "instruction_raw_sha256", "registry_binding",
}
CALL_PROOF_KEYS = {
    "id", "call_node_id", "caller_entry", "caller_region", "call_start",
    "call_end", "physical_resume_offset", "physical_resume_node_id",
    "physical_resume_region", "physical_resume_raw_sha256", "selector",
    "proof_status", "native_role", "registry_binding_status", "return_edge",
}
SOURCE_IDENTITY_KEYS = {"archive", "entry", "source_kind", "archive_sha256"}
REGISTRY_IDENTITY_KEYS = {
    "archive", "archive_sha256", "entry", "entry_sha256", "proof_sha256",
}
COMPATIBILITY = {
    "policy": "planning_only_same_width_literal_registered_definition_call_replacement",
    "input_editable_schema": editable_ir.EDITABLE_IR_SCHEMA,
    "input_decompiler_schema": "kakyu_mes_decompiler_ir/v1",
    "input_call_family_proof_schema": call_prover.CALL_FAMILY_PROOF_SCHEMA,
    "input_registry_proof_schema": registry_prover.SCHEMA,
    "supported_operation": "replace_registered_definition_literal",
    "supported_instruction": {"op": "definition_invoke", "command_id": 0x11},
    "supported_literal_widths": [8],
    "u8_literal_policy": "unambiguous_token_00_through_7f_only",
    "selection_policy": "one_exact_typed_call_and_unique_physical_resume_node",
    "registry_policy": "source_and_replacement_require_exact_command14_body_boundaries",
    "return_edge_policy": "not_emitted_without_registered_body_total_return_proof",
    "body_execution": "not_performed",
    "command_10_policy": "excluded_choice_definition_body_family",
    "length_policy": "replacement_literal_must_match_source_length",
    "binary_publication": "forbidden",
    "native_engine_compatibility": "unverified",
    "unknown_plan_schema": "reject",
    "unknown_v1_field": "reject",
}
INVARIANTS = {
    "source_editable_ir_validated": True,
    "source_call_family_proof_validated": True,
    "registry_proof_validated": True,
    "target_node_unique_and_typed": True,
    "source_instruction_hash_matched": True,
    "source_literal_expression_exact": True,
    "physical_resume_node_unique": True,
    "source_registry_body_boundary_bound": True,
    "replacement_registry_body_boundary_bound": True,
    "replacement_literal_same_width_and_length": True,
    "expression_and_record_terminators_unchanged": True,
    "command_10_not_classified_as_registry": True,
    "registered_bodies_not_executed": True,
    "all_other_instruction_bytes_unchanged": True,
    "opaque_bytes_not_rewritten": True,
    "binary_not_published": True,
}


class RegisteredDefinitionCallEditPlanError(ValueError):
    pass


def plan(
    editable_document: dict[str, Any],
    call_family_proof: dict[str, Any],
    registry_proof: dict[str, Any],
    operation: dict[str, Any],
) -> dict[str, Any]:
    result = _build_plan(
        editable_document, call_family_proof, registry_proof, operation
    )
    result["payload_sha256"] = fingerprint(result)
    validate(result, editable_document, call_family_proof, registry_proof)
    return result


def validate(
    document: dict[str, Any],
    editable_document: dict[str, Any] | None = None,
    call_family_proof: dict[str, Any] | None = None,
    registry_proof: dict[str, Any] | None = None,
) -> dict[str, Any]:
    if (
        document.get("ok") is not True
        or document.get("schema") != PLAN_SCHEMA
        or set(document) != TOP_LEVEL_KEYS
    ):
        raise RegisteredDefinitionCallEditPlanError(
            "MES registered-definition call edit plan schema or fields changed"
        )
    if document.get("producer") != {
        "implementation": "python_phase6_registered_definition_call_edit_planner",
        "contract": PLAN_SCHEMA,
    }:
        raise RegisteredDefinitionCallEditPlanError(
            "MES registered-definition call edit plan producer changed"
        )
    if document.get("compatibility") != COMPATIBILITY:
        raise RegisteredDefinitionCallEditPlanError(
            "MES registered-definition call edit compatibility changed"
        )
    retained = document.get("payload_sha256")
    if not _is_sha256(retained) or fingerprint(document) != retained:
        raise RegisteredDefinitionCallEditPlanError(
            "MES registered-definition call edit plan fingerprint changed"
        )
    operation = document.get("operation")
    if not isinstance(operation, dict) or set(operation) != OPERATION_KEYS:
        raise RegisteredDefinitionCallEditPlanError(
            "MES registered-definition call edit operation fields changed"
        )
    operation = _validate_operation(operation)
    source_identity = document.get("source_identity")
    registry_identity = document.get("registry_identity")
    if (
        not isinstance(source_identity, dict)
        or not set(source_identity).issubset(SOURCE_IDENTITY_KEYS)
        or not isinstance(source_identity.get("archive"), str)
        or not source_identity["archive"]
        or not isinstance(source_identity.get("entry"), str)
        or not source_identity["entry"]
        or not _is_sha256(source_identity.get("archive_sha256"))
        or not isinstance(registry_identity, dict)
        or set(registry_identity) != REGISTRY_IDENTITY_KEYS
        or not isinstance(registry_identity.get("archive"), str)
        or not isinstance(registry_identity.get("entry"), str)
        or not _is_sha256(registry_identity.get("archive_sha256"))
        or not _is_sha256(registry_identity.get("entry_sha256"))
        or not _is_sha256(registry_identity.get("proof_sha256"))
        or source_identity["archive_sha256"] != registry_identity["archive_sha256"]
    ):
        raise RegisteredDefinitionCallEditPlanError(
            "MES registered-definition call edit source identity changed"
        )
    inputs = document.get("inputs")
    expected_inputs = {
        "editable_ir_sha256", "decompiler_ir_sha256",
        "call_family_proof_sha256", "registry_proof_sha256",
    }
    if (
        not isinstance(inputs, dict)
        or set(inputs) != expected_inputs
        or not all(_is_sha256(value) for value in inputs.values())
        or inputs["registry_proof_sha256"] != registry_identity["proof_sha256"]
    ):
        raise RegisteredDefinitionCallEditPlanError(
            "MES registered-definition call edit input identity changed"
        )
    target = document.get("target")
    replacement = document.get("replacement")
    if not isinstance(target, dict) or set(target) != TARGET_KEYS:
        raise RegisteredDefinitionCallEditPlanError(
            "MES registered-definition call edit target fields changed"
        )
    if not isinstance(replacement, dict) or set(replacement) != REPLACEMENT_KEYS:
        raise RegisteredDefinitionCallEditPlanError(
            "MES registered-definition call edit replacement fields changed"
        )
    if (
        target.get("op") != "definition_invoke"
        or target.get("command_id") != 0x11
        or not isinstance(target.get("node_id"), str)
        or not target["node_id"]
        or not isinstance(target.get("region_id"), str)
        or not target["region_id"]
        or target.get("instruction_start") != operation["source_offset"]
        or target.get("instruction_raw_sha256")
        != operation["instruction_raw_sha256"]
        or replacement.get("selector") != operation["selector"]
    ):
        raise RegisteredDefinitionCallEditPlanError(
            "MES registered-definition call edit typed target identity changed"
        )
    _validate_plan_bytes(target, replacement)
    if document.get("assembly_ready") is not True:
        raise RegisteredDefinitionCallEditPlanError(
            "MES registered-definition call edit plan is not assembly ready"
        )
    if document.get("invariants") != INVARIANTS:
        raise RegisteredDefinitionCallEditPlanError(
            "MES registered-definition call edit invariants changed"
        )
    supplied = (editable_document, call_family_proof, registry_proof)
    if any(value is not None for value in supplied):
        if any(value is None for value in supplied):
            raise RegisteredDefinitionCallEditPlanError(
                "MES registered-definition call edit source validation inputs are incomplete"
            )
        expected = _build_plan(
            editable_document,
            call_family_proof,
            registry_proof,
            copy.deepcopy(operation),
        )
        expected["payload_sha256"] = fingerprint(expected)
        if expected != document:
            raise RegisteredDefinitionCallEditPlanError(
                "MES registered-definition call edit plan differs from its source"
            )
    return {"ok": True, "schema": PLAN_SCHEMA, "payload_sha256": retained}


def _build_plan(
    editable_document: dict[str, Any],
    call_family_proof: dict[str, Any],
    registry_proof: dict[str, Any],
    raw_operation: dict[str, Any],
) -> dict[str, Any]:
    editable_ir.validate(editable_document)
    operation = _validate_operation(raw_operation)
    source_ir = editable_document["source_ir"]
    call_prover.validate(call_family_proof, source_ir)
    registry_prover.validate_document(registry_proof)
    source_identity = source_ir.get("source_identity", {})
    registry_source = registry_proof["source_identity"]
    if (
        source_identity.get("archive_sha256") != registry_source["archive_sha256"]
        or source_identity.get("archive") != registry_source["archive"]
    ):
        raise RegisteredDefinitionCallEditPlanError(
            "MES registered-definition caller and registry archives differ"
        )
    owners = [
        node for node in source_ir["nodes"]
        if int(node.get("source", {}).get("start", -1)) == operation["source_offset"]
    ]
    if len(owners) != 1:
        raise RegisteredDefinitionCallEditPlanError(
            "MES registered-definition call edit target is not one unique node"
        )
    owner = owners[0]
    source = owner.get("source")
    statement = owner.get("statement")
    if (
        owner.get("kind") != "statement"
        or not isinstance(source, dict)
        or not isinstance(statement, dict)
        or statement.get("kind") != "instruction"
        or statement.get("op") != "definition_invoke"
        or statement.get("command_id") != 0x11
    ):
        raise RegisteredDefinitionCallEditPlanError(
            "MES registered-definition call edit target is not a typed command-0x11 call"
        )
    instruction_raw = _hex_bytes(source.get("raw_hex"), "instruction source")
    if hashlib.sha256(instruction_raw).hexdigest() != operation["instruction_raw_sha256"]:
        raise RegisteredDefinitionCallEditPlanError(
            "MES registered-definition call edit instruction source hash is stale"
        )
    instruction_start = int(source.get("start", -1))
    instruction_end = int(source.get("end", -1))
    if instruction_end - instruction_start != len(instruction_raw):
        raise RegisteredDefinitionCallEditPlanError(
            "MES registered-definition call edit instruction boundary changed"
        )
    record_list, expression, ast = _literal_expression(statement)
    source_selector = ast.get("value")
    if not _is_int(source_selector) or ast.get("width") != 8:
        raise RegisteredDefinitionCallEditPlanError(
            "MES registered-definition call edit selector is not an exact 8-bit literal"
        )
    expression_raw = _encode_literal(source_selector)
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
        or instruction_raw != bytes((0x11, 0x02)) + expression_raw + b"\x00"
    ):
        raise RegisteredDefinitionCallEditPlanError(
            "MES registered-definition call edit literal record boundary changed"
        )
    source_call = _source_call_proof(
        call_family_proof,
        owner,
        source_ir,
        source_selector,
        instruction_start,
        instruction_end,
    )
    source_binding = _registry_binding(registry_proof, source_selector)
    replacement_selector = operation["selector"]
    if replacement_selector == source_selector:
        raise RegisteredDefinitionCallEditPlanError(
            "MES registered-definition call edit replacement is unchanged"
        )
    replacement_binding = _registry_binding(registry_proof, replacement_selector)
    replacement_expression = _encode_literal(replacement_selector)
    replacement_instruction = bytes((0x11, 0x02)) + replacement_expression + b"\x00"
    return {
        "ok": True,
        "schema": PLAN_SCHEMA,
        "producer": {
            "implementation": "python_phase6_registered_definition_call_edit_planner",
            "contract": PLAN_SCHEMA,
        },
        "compatibility": copy.deepcopy(COMPATIBILITY),
        "source_identity": copy.deepcopy(source_identity),
        "registry_identity": {
            **copy.deepcopy(registry_source),
            "proof_sha256": registry_proof["payload_sha256"],
        },
        "inputs": {
            "editable_ir_sha256": editable_document["payload_sha256"],
            "decompiler_ir_sha256": source_ir["payload_sha256"],
            "call_family_proof_sha256": call_family_proof["payload_sha256"],
            "registry_proof_sha256": registry_proof["payload_sha256"],
        },
        "operation": copy.deepcopy(operation),
        "target": {
            "node_id": str(owner["id"]),
            "region_id": str(source["region"]),
            "op": "definition_invoke",
            "command_id": 0x11,
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
            "literal_raw_hex": bytes((source_selector,)).hex(),
            "literal_raw_sha256": hashlib.sha256(bytes((source_selector,))).hexdigest(),
            "selector": source_selector,
            "width": 8,
            "expression_terminator_offset": literal_end,
            "expression_terminator": 0xFF,
            "record_terminator_offset": expression_end,
            "record_terminator": 0,
            "call_proof": source_call,
            "registry_binding": source_binding,
        },
        "replacement": {
            "selector": replacement_selector,
            "width": 8,
            "literal_raw_hex": bytes((replacement_selector,)).hex(),
            "literal_raw_sha256": hashlib.sha256(bytes((replacement_selector,))).hexdigest(),
            "expression_raw_hex": replacement_expression.hex(),
            "expression_raw_sha256": hashlib.sha256(replacement_expression).hexdigest(),
            "instruction_raw_hex": replacement_instruction.hex(),
            "instruction_raw_sha256": hashlib.sha256(replacement_instruction).hexdigest(),
            "registry_binding": replacement_binding,
        },
        "assembly_ready": True,
        "invariants": copy.deepcopy(INVARIANTS),
    }


def _literal_expression(statement: dict[str, Any]) -> tuple[dict, dict, dict]:
    operands = statement.get("operands")
    record_list = operands[0] if isinstance(operands, list) and len(operands) == 1 else None
    records = record_list.get("records") if isinstance(record_list, dict) else None
    record = records[0] if isinstance(records, list) and len(records) == 1 else None
    expression = record.get("value") if isinstance(record, dict) else None
    ast = expression.get("ast") if isinstance(expression, dict) else None
    if (
        not isinstance(record_list, dict)
        or record_list.get("type") != "record_list"
        or not isinstance(record, dict)
        or record.get("type") != "expression_record"
        or record.get("tag") != 0x02
        or not isinstance(expression, dict)
        or not isinstance(ast, dict)
        or ast.get("type") != "literal"
        or not isinstance(ast.get("source"), dict)
    ):
        raise RegisteredDefinitionCallEditPlanError(
            "MES registered-definition call edit selector is not one typed literal expression"
        )
    return record_list, expression, ast


def _source_call_proof(
    proof: dict[str, Any],
    owner: dict[str, Any],
    source_ir: dict[str, Any],
    selector: int,
    instruction_start: int,
    instruction_end: int,
) -> dict[str, Any]:
    matches = [
        row for row in proof["call_sites"]
        if row.get("kind") == "registered_definition_call_site"
        and row.get("call_start") == instruction_start
        and row.get("call_node_id") == owner.get("id")
    ]
    if len(matches) != 1:
        raise RegisteredDefinitionCallEditPlanError(
            "MES registered-definition call edit has no unique proved source call"
        )
    call = matches[0]
    if (
        call.get("call_end") != instruction_end
        or call.get("physical_resume_offset") != instruction_end
        or call.get("selector") != {"kind": "literal", "value": selector}
        or call.get("proof_status")
        != "typed_registered_selector_and_exact_physical_resume"
        or call.get("native_role")
        != "registered_definition_lookup_call_and_restore"
        or call.get("registry_binding") != "not_supplied"
    ):
        raise RegisteredDefinitionCallEditPlanError(
            "MES registered-definition call edit source call proof changed"
        )
    resume_nodes = [
        node for node in source_ir["nodes"]
        if int(node.get("source", {}).get("start", -1)) == instruction_end
        and node.get("source", {}).get("entry") == owner.get("source", {}).get("entry")
    ]
    if len(resume_nodes) != 1:
        raise RegisteredDefinitionCallEditPlanError(
            "MES registered-definition call edit physical resume node is not unique"
        )
    resume = resume_nodes[0]
    resume_source = resume["source"]
    return {
        "id": str(call["id"]),
        "call_node_id": str(call["call_node_id"]),
        "caller_entry": str(call["caller_entry"]),
        "caller_region": str(call["caller_region"]),
        "call_start": int(call["call_start"]),
        "call_end": int(call["call_end"]),
        "physical_resume_offset": int(call["physical_resume_offset"]),
        "physical_resume_node_id": str(resume["id"]),
        "physical_resume_region": str(resume_source["region"]),
        "physical_resume_raw_sha256": str(resume_source["raw_sha256"]),
        "selector": selector,
        "proof_status": str(call["proof_status"]),
        "native_role": str(call["native_role"]),
        "registry_binding_status": "source_and_replacement_exact_body_boundaries_supplied",
        "return_edge": "unproved_registered_body_total_return_not_supplied",
    }


def _registry_binding(proof: dict[str, Any], selector: int) -> dict[str, Any]:
    matches = [row for row in proof["registrations"] if row.get("selector") == selector]
    if len(matches) != 1:
        raise RegisteredDefinitionCallEditPlanError(
            "MES registered-definition call edit selector has no unique registry body"
        )
    return copy.deepcopy(matches[0])


def _validate_plan_bytes(target: dict[str, Any], replacement: dict[str, Any]) -> None:
    integer_target_keys = {
        "command_id", "instruction_start", "instruction_end", "record_list_start",
        "record_list_end", "expression_start", "expression_end", "literal_start",
        "literal_end", "selector", "width", "expression_terminator_offset",
        "expression_terminator", "record_terminator_offset", "record_terminator",
    }
    if any(not _is_nonnegative_int(target.get(key)) for key in integer_target_keys):
        raise RegisteredDefinitionCallEditPlanError(
            "MES registered-definition call edit target coordinate changed"
        )
    if (
        not _is_nonnegative_int(replacement.get("selector"))
        or not _is_nonnegative_int(replacement.get("width"))
        or target["width"] != 8
        or replacement["width"] != 8
        or target["selector"] == replacement["selector"]
        or target["selector"] > 0x7F
        or replacement["selector"] > 0x7F
    ):
        raise RegisteredDefinitionCallEditPlanError(
            "MES registered-definition call edit replacement literal changed"
        )
    source_instruction = _checked_bytes(target, "instruction")
    source_expression = _checked_bytes(target, "expression")
    source_literal = _checked_bytes(target, "literal")
    output_instruction = _checked_bytes(replacement, "instruction")
    output_expression = _checked_bytes(replacement, "expression")
    output_literal = _checked_bytes(replacement, "literal")
    if (
        source_literal != bytes((target["selector"],))
        or output_literal != bytes((replacement["selector"],))
        or source_expression != source_literal + b"\xFF"
        or output_expression != output_literal + b"\xFF"
        or source_instruction != b"\x11\x02" + source_expression + b"\x00"
        or output_instruction != b"\x11\x02" + output_expression + b"\x00"
        or len(source_instruction) != len(output_instruction)
    ):
        raise RegisteredDefinitionCallEditPlanError(
            "MES registered-definition call edit planned instruction bytes changed"
        )
    start = int(target["instruction_start"])
    if (
        target["instruction_end"] != start + 5
        or target["record_list_start"] != start + 1
        or target["expression_start"] != start + 2
        or target["literal_start"] != start + 2
        or target["literal_end"] != start + 3
        or target["expression_terminator_offset"] != start + 3
        or target["expression_end"] != start + 4
        or target["record_terminator_offset"] != start + 4
        or target["record_list_end"] != start + 5
        or target["expression_terminator"] != 0xFF
        or target["record_terminator"] != 0
    ):
        raise RegisteredDefinitionCallEditPlanError(
            "MES registered-definition call edit planned record boundary changed"
        )
    call = target.get("call_proof")
    if not isinstance(call, dict) or set(call) != CALL_PROOF_KEYS:
        raise RegisteredDefinitionCallEditPlanError(
            "MES registered-definition call edit call proof fields changed"
        )
    if (
        call.get("call_start") != start
        or call.get("call_end") != target["instruction_end"]
        or call.get("physical_resume_offset") != target["instruction_end"]
        or call.get("selector") != target["selector"]
        or not _is_sha256(call.get("physical_resume_raw_sha256"))
        or call.get("proof_status")
        != "typed_registered_selector_and_exact_physical_resume"
        or call.get("native_role")
        != "registered_definition_lookup_call_and_restore"
        or call.get("registry_binding_status")
        != "source_and_replacement_exact_body_boundaries_supplied"
        or call.get("return_edge")
        != "unproved_registered_body_total_return_not_supplied"
    ):
        raise RegisteredDefinitionCallEditPlanError(
            "MES registered-definition call edit call proof changed"
        )
    for binding, selector in (
        (target.get("registry_binding"), target["selector"]),
        (replacement.get("registry_binding"), replacement["selector"]),
    ):
        _validate_registry_binding(binding, selector)


def _validate_registry_binding(value: Any, selector: int) -> None:
    if not isinstance(value, dict) or set(value) != registry_prover.REGISTRATION_KEYS:
        raise RegisteredDefinitionCallEditPlanError(
            "MES registered-definition call edit registry binding fields changed"
        )
    integer_keys = {
        "selector", "registration_start", "registration_end", "selector_start",
        "selector_end", "expression_start", "expression_end", "body_start",
        "body_end", "body_size", "skip_target",
    }
    if (
        any(not _is_nonnegative_int(value.get(key)) for key in integer_keys)
        or value.get("selector") != selector
        or value["registration_end"] != value["body_start"]
        or value["body_end"] != value["skip_target"]
        or value["body_size"] != value["body_end"] - value["body_start"]
        or value["body_size"] <= 0
        or any(
            not _is_sha256(value.get(key))
            for key in (
                "registration_raw_sha256", "selector_raw_sha256",
                "expression_raw_sha256", "body_raw_sha256",
            )
        )
        or value.get("body_execution") != "not_performed"
        or value.get("proof_status")
        != "literal_command14_registration_with_exact_body_boundary"
    ):
        raise RegisteredDefinitionCallEditPlanError(
            "MES registered-definition call edit registry binding changed"
        )


def _checked_bytes(row: dict[str, Any], prefix: str) -> bytes:
    raw = _hex_bytes(row.get(f"{prefix}_raw_hex"), f"planned {prefix}")
    if row.get(f"{prefix}_raw_sha256") != hashlib.sha256(raw).hexdigest():
        raise RegisteredDefinitionCallEditPlanError(
            "MES registered-definition call edit planned hash changed"
        )
    return raw


def _validate_operation(raw: dict[str, Any]) -> dict[str, Any]:
    if not isinstance(raw, dict) or set(raw) != OPERATION_KEYS:
        raise RegisteredDefinitionCallEditPlanError(
            "MES registered-definition call edit operation fields changed"
        )
    if raw.get("kind") != "replace_registered_definition_literal":
        raise RegisteredDefinitionCallEditPlanError(
            "unsupported MES registered-definition call edit operation"
        )
    if not _is_nonnegative_int(raw.get("source_offset")):
        raise RegisteredDefinitionCallEditPlanError(
            "MES registered-definition call edit source_offset is invalid"
        )
    if not _is_nonnegative_int(raw.get("selector")) or raw["selector"] > 0x7F:
        raise RegisteredDefinitionCallEditPlanError(
            "MES registered-definition call edit selector is not an unambiguous token"
        )
    if not _is_sha256(raw.get("instruction_raw_sha256")):
        raise RegisteredDefinitionCallEditPlanError(
            "MES registered-definition call edit source hash is invalid"
        )
    return copy.deepcopy(raw)


def _encode_literal(value: Any) -> bytes:
    if not _is_nonnegative_int(value) or value > 0x7F:
        raise RegisteredDefinitionCallEditPlanError(
            "MES registered-definition call edit selector is not an unambiguous token"
        )
    return bytes((value, 0xFF))


def _hex_bytes(value: Any, label: str) -> bytes:
    if not isinstance(value, str):
        raise RegisteredDefinitionCallEditPlanError(
            f"MES registered-definition call edit {label} bytes are missing"
        )
    try:
        return bytes.fromhex(value)
    except ValueError as error:
        raise RegisteredDefinitionCallEditPlanError(
            f"MES registered-definition call edit {label} bytes are invalid"
        ) from error


def _is_int(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool)


def _is_nonnegative_int(value: Any) -> bool:
    return _is_int(value) and value >= 0


def main() -> None:
    parser = argparse.ArgumentParser(
        description=(
            "Build a fail-closed JSON plan for one typed command-0x11 literal "
            "whose source and replacement selectors have exact command-0x14 "
            "registry body boundaries. This tool never publishes MES bytes."
        )
    )
    parser.add_argument("editable_ir", type=Path)
    parser.add_argument("call_family_proof", type=Path)
    parser.add_argument("registry_proof", type=Path)
    parser.add_argument("operation", type=Path)
    parser.add_argument("output", type=Path)
    arguments = parser.parse_args()
    paths = [
        arguments.editable_ir.resolve(), arguments.call_family_proof.resolve(),
        arguments.registry_proof.resolve(), arguments.operation.resolve(),
        arguments.output.resolve(),
    ]
    if len(set(paths)) != len(paths):
        raise RegisteredDefinitionCallEditPlanError(
            "MES registered-definition call edit paths must be distinct"
        )
    try:
        editable_document = json.loads(arguments.editable_ir.read_text(encoding="utf-8"))
        call_family_proof = json.loads(
            arguments.call_family_proof.read_text(encoding="utf-8")
        )
        registry_proof = json.loads(arguments.registry_proof.read_text(encoding="utf-8"))
        operation = json.loads(arguments.operation.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise RegisteredDefinitionCallEditPlanError(
            "MES registered-definition call edit input could not be read"
        ) from error
    if not all(
        isinstance(value, dict)
        for value in (editable_document, call_family_proof, registry_proof, operation)
    ):
        raise RegisteredDefinitionCallEditPlanError(
            "MES registered-definition call edit input is not an object"
        )
    document = plan(
        editable_document, call_family_proof, registry_proof, operation
    )
    payload = json.dumps(
        document,
        ensure_ascii=False,
        allow_nan=False,
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8") + b"\n"
    editable_ir.publish_new(arguments.output, payload)
    print(
        "MES_REGISTERED_DEFINITION_CALL_EDIT_PLAN_PASS "
        f"schema={document['schema']} "
        f"entry={document['source_identity'].get('entry', '')} "
        f"offset={document['target']['instruction_start']} "
        f"source_selector={document['target']['selector']} "
        f"replacement_selector={document['replacement']['selector']} "
        f"resume={document['target']['call_proof']['physical_resume_offset']} "
        "mes_bytes=false "
        f"payload_sha256={document['payload_sha256']}"
    )


if __name__ == "__main__":
    main()
