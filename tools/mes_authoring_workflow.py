"""Bounded editor bridge over the authoritative Python analyzer and Phase 6.

Bundles contain local source evidence. They are not distributable mod packages.
The editor connects same-width state literals, same-width condition literals,
same-length resource-name edits, same-length grouped choice-option edits,
same-width registered-definition call selectors, same-width shared-routine
call selectors, variable-length CP932 messages with exact control-target
relocation and exact control-target retargeting; other families remain in
their backend tools. The eighth family: one u32 target operand of a
`branch_if_not_true` false target (command 0x0B) or a `continuation_transfer`
(command 0x0C), retargeted to another unique typed instruction start.

A bundle can also hold an ORDERED SEQUENCE of operations, compiled as a
chain: step 1 on the original entry, step k on step k-1's compiled output
(re-analysed with `analyze`). Every step but the last must be same-size (its
coordinates therefore stay original coordinates); at most one trailing
`replace_message` step may relocate the entry. `compile_sequence` builds the
chain and its `sequence.json`/chain proof; `compile_edit` remains the
single-step engine underneath every step.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import tempfile
from typing import Any

import compile_mes_state_literal_edit as compiler
import compile_mes_choice_option_edit as choice_compiler
import compile_mes_condition_literal_edit as condition_compiler
import compile_mes_registered_definition_call_edit as call_compiler
import compile_mes_resource_name_edit as resource_compiler
import compile_mes_shared_routine_call_edit as shared_call_compiler
import compile_mes_control_target_edit as target_edit_compiler
import compile_mes_control_target_relocation as message_compiler
import plan_mes_choice_option_edit as choice_planner
import plan_mes_condition_literal_edit as condition_planner
import plan_mes_registered_definition_call_edit as call_planner
import plan_mes_resource_name_edit as resource_planner
import plan_mes_shared_routine_call_edit as shared_call_planner
import plan_mes_control_target_edit as target_edit_planner
import plan_mes_message_relocation as message_planner
import plan_mes_control_target_relocation as target_planner
import diff_mes_message_relocation_semantics as message_diff
import decompile_mes_handoff as decompiler
import diff_mes_byte_patch_semantics as semantic_diff
import diff_mes_sequence_semantics as sequence_diff
import mes_analyzer_handoff as analyzer
import mes_archive_ir as archive_reader
from mes_handoff_transport import canonical_json_bytes
import plan_mes_state_literal_edit as planner
import prepare_mes_editable_ir as editable
import prove_mes_call_families as call_prover
import prove_mes_choice_group_authoring as choice_prover
import prove_mes_registered_definition_registry as registry_prover
import prove_mes_shared_call_returns as shared_call_prover

SCHEMA = "kakyu_mes_authoring_bundle/v9"
LEGACY_SCHEMA = "kakyu_mes_authoring_bundle/v1"
LEGACY_SCHEMAS = (
    "kakyu_mes_authoring_bundle/v1",
    "kakyu_mes_authoring_bundle/v2",
    "kakyu_mes_authoring_bundle/v3",
    "kakyu_mes_authoring_bundle/v4",
    "kakyu_mes_authoring_bundle/v5",
    "kakyu_mes_authoring_bundle/v6",
    "kakyu_mes_authoring_bundle/v7",
    "kakyu_mes_authoring_bundle/v8",
)
REGISTRY_MEMBER = "registry.proof.json"
LIBRARY_MEMBER = "library.audit.json"
SEQUENCE_SCHEMA = "kakyu_mes_authoring_sequence/v1"
SEQUENCE_MEMBER = "sequence.json"
STEP_SUFFIXES = ("plan.json", "compile.audit.json", "semantic.diff.json", "output.mes", "output.handoff.json")
SOURCE_FILES = {"handoff.json", "handoff.payload.json", "editable.json"}
FILES = SOURCE_FILES | {"plan.json", "output.mes",
         "output.handoff.json", "compile.audit.json", "semantic.diff.json"}
MESSAGE_FILES = FILES | {"control.plan.json"}


def step_member(index: int, suffix: str) -> str:
    return f"step-{index:02d}.{suffix}"


def _json(document: Any) -> bytes:
    return (json.dumps(document, ensure_ascii=False, allow_nan=False,
                       sort_keys=True, separators=(",", ":")) + "\n").encode("utf-8")


def _sha(payload: bytes) -> str:
    return hashlib.sha256(payload).hexdigest()


def _source(source: dict[str, Any]) -> None:
    if set(source) != {"archive", "entry", "source_kind", "archive_sha256"}:
        raise ValueError("Authoring source fields changed")
    entry = source["entry"]
    if (source["archive"] != "mes.arc" or source["source_kind"] != "original_arc"
            or not isinstance(entry, str) or not entry.upper().endswith(".MES")
            or any(c not in "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_.-" for c in entry)
            or entry in (".", "..") or ".." in entry
            or not isinstance(source["archive_sha256"], str)
            or len(source["archive_sha256"]) != 64
            or any(c not in "0123456789abcdef" for c in source["archive_sha256"])):
        raise ValueError("Authoring requires a path-free original MES identity")


def analyze(payload: bytes, source: dict[str, Any],
            registry_proof: dict[str, Any] | None = None,
            library_audit: dict[str, Any] | None = None) -> dict[str, bytes]:
    _source(source)
    handoff = analyzer.build_handoff(payload, source)
    model = editable.prepare(decompiler.lift(handoff))
    signed_payload = dict(handoff)
    signed_payload.pop("payload_sha256")
    files = {"handoff.json": _json(handoff), "editable.json": _json(model),
             "handoff.payload.json": canonical_json_bytes(signed_payload)}
    if registry_proof is not None:
        files[REGISTRY_MEMBER] = _json(registry_proof)
    if library_audit is not None:
        files[LIBRARY_MEMBER] = _json(library_audit)
    return files


def state_controls(model: dict[str, Any]) -> list[dict[str, Any]]:
    """List typed literal candidates; the planner validates a chosen edit fully."""
    editable.validate(model)
    rows = []
    for node in model["source_ir"]["nodes"]:
        statement = node["statement"]
        form = planner.SUPPORTED_WRITES.get(statement.get("op"))
        if form is None:
            continue
        operands = statement.get("operands", [])
        index = form["pairs_operand"]
        if len(operands) <= index:
            continue
        for pair_index, pair in enumerate(operands[index].get("pairs", [])):
            ast = pair.get("expression", {}).get("ast", {})
            if ast.get("type") != "literal":
                continue
            operation = {"kind": "replace_state_write_literal",
                         "source_offset": node["source"]["start"],
                         "instruction_raw_sha256": node["source"]["raw_sha256"],
                         "pair_index": pair_index, "value": ast.get("value")}
            rows.append({"operation": operation, "storage": form["storage"],
                         "destination": operands[form["destination_operand"]],
                         "width": ast.get("width"),
                         "end_offset": node["source"]["end"]})
    return rows


def condition_controls(model: dict[str, Any]) -> list[dict[str, Any]]:
    """List same-width condition literal candidates; the planner validates a chosen edit fully."""
    editable.validate(model)
    rows = []
    for node in model["source_ir"]["nodes"]:
        statement = node["statement"]
        if statement.get("op") != "branch_if_not_true" or statement.get("command_id") != 0x0B:
            continue
        operands = statement.get("operands", [])
        if len(operands) != 2:
            continue
        condition_operand, target_operand = operands
        if condition_operand.get("type") != "condition" or target_operand.get("type") != "code_offset":
            continue
        condition = condition_operand.get("value", {})
        false_target = target_operand.get("value")
        for literal in condition_planner._walk_ast(condition.get("ast", {})):
            if literal.get("type") != "literal":
                continue
            source = literal.get("source", {})
            if not isinstance(source.get("offset"), int) or isinstance(source.get("offset"), bool):
                continue
            operation = {"kind": "replace_condition_literal",
                         "source_offset": node["source"]["start"],
                         "instruction_raw_sha256": node["source"]["raw_sha256"],
                         "literal_offset": source["offset"], "value": literal.get("value")}
            rows.append({"operation": operation, "width": literal.get("width"),
                         "end_offset": node["source"]["end"], "false_target": false_target})
    return rows


def resource_controls(model: dict[str, Any]) -> list[dict[str, Any]]:
    """List same-length resource-name candidates; the planner validates a chosen edit fully."""
    editable.validate(model)
    nodes_by_start = {node["source"]["start"]: node for node in model["source_ir"]["nodes"]}
    rows = []
    for row in model["source_ir"]["references"]:
        if row.get("kind") != "resource":
            continue
        value = row.get("value", {})
        if (value.get("boundary") != "strict_indexed"
                or value.get("op") not in resource_planner.SUPPORTED_RESOURCES):
            continue
        owner = nodes_by_start.get(value.get("source_offset"))
        if owner is None or row.get("id") not in owner.get("reference_ids", []):
            continue
        operands = owner.get("statement", {}).get("operands", [])
        resource_operand = next((op for op in operands if op.get("type") == "resource_name"), None)
        if resource_operand is None:
            continue
        name_raw = bytes.fromhex(resource_operand["raw_hex"])
        source_name = str(value.get("source_name", ""))
        extension = source_name.rsplit(".", 1)[1].lower() if "." in source_name else ""
        operation = {"kind": "replace_resource_name", "source_offset": value["source_offset"],
                     "instruction_raw_sha256": owner["source"]["raw_sha256"],
                     "reference_id": row["id"], "name": source_name}
        rows.append({"operation": operation, "resource_kind": value.get("resource_kind"),
                     "normalized_name": value.get("name"), "name_length": len(name_raw),
                     "extension": extension, "archive_candidates": value.get("archive_candidates"),
                     "end_offset": owner["source"]["end"]})
    rows.sort(key=lambda row: row["operation"]["source_offset"])
    return rows


def _has_group_clear(model: dict[str, Any]) -> bool:
    """True when the editable model's own decoded nodes hold a group-clear (command 0x1B) statement.

    This is a cheap, prologue-independent pre-check: it only looks at the
    editable IR nodes already decoded by the authoritative analyzer, never at
    the routine-40 grouped-route prover, so an entry without a group clear
    never pays for (or fails on) the CFG decoder's prologue precondition.
    """
    return any(
        node.get("statement", {}).get("command_id") == 0x1B
        for node in model["source_ir"]["nodes"]
    )


def choice_controls(model: dict[str, Any]) -> list[dict[str, Any]]:
    """List same-length grouped choice-option candidates; the planner validates a chosen edit fully.

    ``choice_controls`` only receives the model, so the choice-proof identity is
    projected from ``model["source_ir"]["source_identity"]`` (restricted to
    ``archive``, ``archive_sha256``, ``entry`` - the prover's own identity shape).
    The routine-40 grouped-route prover (and its CFG-prologue precondition) is
    only consulted when the model already holds a group-clear (command 0x1B)
    statement; an entry without one has no choice candidate.
    """
    editable.validate(model)
    if not _has_group_clear(model):
        return []
    source_identity = model["source_ir"]["source_identity"]
    identity = {key: source_identity[key] for key in ("archive", "archive_sha256", "entry")}
    payload = decompiler.reconstruct_container(model["source_ir"])
    rows = []
    for index in choice_prover.group_entry_indices(payload, identity):
        proof = choice_prover.prove_entry(payload, identity, index)
        code_offset = int(proof["container"]["code_offset"])
        for group in proof["groups"]:
            for definition in group["definitions"]:
                message = definition["message"]
                payload_start = int(message["payload_start"])
                payload_end = int(message["payload_end"])
                text = payload[code_offset + payload_start:code_offset + payload_end].decode("cp932")
                operation = {"kind": "replace_choice_option_cp932_same_length",
                             "group_selector": group["selector"],
                             "definition_id": definition["definition_id"],
                             "source_payload_sha256": message["payload_raw_sha256"],
                             "text": text, "encoding": "cp932"}
                rows.append({"operation": operation, "address_entry_index": index,
                             "payload_size": message["payload_size"],
                             "source_offset": message["instruction_start"],
                             "payload_start": payload_start, "payload_end": payload_end})
    rows.sort(key=lambda row: (
        row["address_entry_index"], row["operation"]["group_selector"], row["operation"]["definition_id"],
    ))
    return rows


def call_controls(model: dict[str, Any], files: dict[str, bytes]) -> list[dict[str, Any]]:
    """List registered-definition call candidates; the planner validates a chosen edit fully.

    Unlike the other listers, this one needs the bundle's own files: a
    candidate only exists once the archive's DEF_MAIN.MES registry proof
    (``REGISTRY_MEMBER``) is part of the bundle, because a selector without a
    known registry body has no editable destination. Listing a candidate here
    is not compiler approval - the planner re-checks source and replacement
    selectors against the registry independently.
    """
    editable.validate(model)
    if REGISTRY_MEMBER not in files:
        return []
    handoff = json.loads(files["handoff.json"])
    family = call_prover.prove(decompiler.lift(handoff))
    registry = json.loads(files[REGISTRY_MEMBER])
    nodes_by_start = {node["source"]["start"]: node for node in model["source_ir"]["nodes"]}
    registered_selectors = sorted(int(row["selector"]) for row in registry["registrations"])
    registry_entry = registry["source_identity"]["entry"]
    registry_entry_sha256 = registry["source_identity"]["entry_sha256"]
    rows = []
    for call in family["call_sites"]:
        if (call.get("kind") != "registered_definition_call_site"
                or call.get("selector", {}).get("kind") != "literal"
                or call.get("proof_status") != "typed_registered_selector_and_exact_physical_resume"):
            continue
        node = nodes_by_start.get(call["call_start"])
        if node is None:
            continue
        operation = {"kind": "replace_registered_definition_literal", "source_offset": call["call_start"],
                     "instruction_raw_sha256": node["source"]["raw_sha256"], "selector": call["selector"]["value"]}
        rows.append({"operation": operation, "end_offset": call["call_end"],
                     "physical_resume_offset": call["physical_resume_offset"],
                     "registered_selectors": registered_selectors,
                     "registry_entry": registry_entry, "registry_entry_sha256": registry_entry_sha256})
    rows.sort(key=lambda row: row["operation"]["source_offset"])
    return rows


def shared_call_controls(model: dict[str, Any], files: dict[str, bytes]) -> list[dict[str, Any]]:
    """List shared-routine call candidates; the planner validates a chosen edit fully.

    Unlike the other listers, this one needs the bundle's own files: a
    candidate only exists once the archive's Godot-built LIBLARY.LIB audit
    (``LIBRARY_MEMBER``) is part of the bundle, because a routine ID without
    a proved total-return contract has no editable destination. Listing a
    candidate here is not compiler approval - the planner re-checks the
    source and replacement routines against the library audit independently.
    """
    editable.validate(model)
    if LIBRARY_MEMBER not in files:
        return []
    handoff = json.loads(files["handoff.json"])
    library = json.loads(files[LIBRARY_MEMBER])
    proof = shared_call_prover.prove(decompiler.lift(handoff), library)
    nodes_by_start = {node["source"]["start"]: node for node in model["source_ir"]["nodes"]}
    replaceable_routine_ids = sorted(
        int(row["routine_id"]) for row in proof["routine_return_contracts"] if row["proved"] is True
    )
    rows = []
    for call in proof["proved_calls"]:
        node = nodes_by_start.get(call["call_start"])
        if node is None:
            continue
        operation = {"kind": "replace_shared_routine_literal", "source_offset": call["call_start"],
                     "instruction_raw_sha256": node["source"]["raw_sha256"], "routine_id": call["routine_id"]}
        rows.append({"operation": operation, "end_offset": call["call_end"],
                     "physical_resume_offset": call["physical_resume_offset"],
                     "callee_body_start": call["callee_body_start"],
                     "replaceable_routine_ids": replaceable_routine_ids,
                     "library_entry_sha256": library["entry_sha256"]})
    rows.sort(key=lambda row: row["operation"]["source_offset"])
    return rows


def _unique_typed_node_map(source_ir: dict[str, Any]) -> dict[int, dict[str, Any]]:
    """Map instruction start -> node for every unique strict typed instruction start.

    Mirrors ``plan_mes_control_target_edit._unique_typed_node``'s predicate: kind
    ``statement``, evidence ``decompiler.TYPED_EVIDENCE_STATUS``, statement kind
    ``instruction``, not ``metadata.structural_only``, and exactly one node at
    that start.
    """
    by_start: dict[int, list[dict[str, Any]]] = {}
    for node in source_ir["nodes"]:
        by_start.setdefault(node.get("source", {}).get("start"), []).append(node)
    unique: dict[int, dict[str, Any]] = {}
    for start, group in by_start.items():
        if len(group) != 1:
            continue
        node = group[0]
        statement = node.get("statement")
        metadata = statement.get("metadata", {}) if isinstance(statement, dict) else {}
        if (node.get("kind") == "statement" and node.get("evidence_status") == decompiler.TYPED_EVIDENCE_STATUS
                and isinstance(statement, dict) and statement.get("kind") == "instruction"
                and metadata.get("structural_only") is not True):
            unique[start] = node
    return unique


def control_target_controls(model: dict[str, Any]) -> list[dict[str, Any]]:
    """List control-target retarget candidates; the planner validates a chosen edit fully.

    The row operation deliberately omits ``replacement_target_instruction_raw_sha256``
    and carries the current target as the replacement, so an unedited row is
    rejected by the planner as unchanged, like the other families.
    """
    editable.validate(model)
    source_ir = model["source_ir"]
    unique = _unique_typed_node_map(source_ir)
    rows = []
    for start, node in unique.items():
        statement = node["statement"]
        op = statement.get("op")
        command_id = statement.get("command_id")
        for kind, form in target_edit_planner.SUPPORTED_FORMS.items():
            if op != form["op"] or command_id != form["command_id"]:
                continue
            references = [
                row for row in source_ir["references"]
                if row.get("kind") == "code" and row.get("source_offset") == start
                and isinstance(row.get("value"), dict) and row["value"].get("kind") == kind
                and row["value"].get("aligned") is True and row["value"].get("in_code") is True
            ]
            if len(references) != 1 or references[0].get("id") not in node.get("reference_ids", []):
                continue
            current = references[0]["value"].get("target_offset")
            if current not in unique:
                continue
            operation = {"kind": "retarget_control_flow", "source_offset": start,
                         "reference_kind": kind, "source_instruction_raw_sha256": node["source"]["raw_sha256"],
                         "replacement_target_offset": current}
            rows.append({"operation": operation, "end_offset": node["source"]["end"],
                         "current_target_offset": current, "current_target_op": unique[current]["statement"]["op"],
                         "code_size": source_ir["container"]["code_size"]})
    rows.sort(key=lambda row: row["operation"]["source_offset"])
    return rows


def message_controls(model: dict[str, Any]) -> list[dict[str, Any]]:
    editable.validate(model)
    rows = []
    for reference in model["source_ir"]["references"]:
        value = reference.get("value", {})
        if reference.get("kind") != "message" or value.get("native_stream_projection_match") is not True:
            continue
        raw = bytes.fromhex(value["raw_hex"])
        try:
            text = raw.decode("cp932", errors="strict")
        except UnicodeDecodeError:
            continue
        rows.append({"operation": {"kind": "replace_message", "source_offset": reference["source_offset"],
                                  "raw_sha256": _sha(raw), "text": text, "encoding": "cp932",
                                  "native_projection": "require_match"}, "byte_length": len(raw)})
    return rows


def compile_edit(files: dict[str, bytes], operation: dict[str, Any]) -> dict[str, bytes]:
    model = json.loads(files["editable.json"])
    handoff = json.loads(files["handoff.json"])
    analyzer.verify(handoff)
    if editable.prepare(decompiler.lift(handoff)) != model:
        raise ValueError("Authoring editable model does not match its Python handoff")
    extra = {}
    carried = {name: files[name] for name in (REGISTRY_MEMBER, LIBRARY_MEMBER) if name in files}
    kind = operation.get("kind")
    if kind == "replace_message":
        message_planner._validate_operation(operation)
        encoded = message_planner._encode_replacement(operation["text"])
        if encoded.decode("cp932", errors="strict") != operation["text"]:
            raise ValueError("Authoring message must round-trip through CP932 without Unicode aliases")
        plan = message_planner.plan(model, operation)
        control = target_planner.plan(model, plan)
        output, audit = message_compiler.compile_message_with_targets(model, plan, control)
        message_compiler.validate_audit(audit, model, plan, control, output)
        extra["control.plan.json"] = _json(control)
    elif kind == "replace_condition_literal":
        plan = condition_planner.plan(model, operation)
        output, audit = condition_compiler.compile_condition_literal(model, plan)
        condition_compiler.validate_audit(audit, model, plan, output)
    elif kind == "replace_resource_name":
        plan = resource_planner.plan(model, operation)
        output, audit = resource_compiler.compile_resource_name(model, plan)
        resource_compiler.validate_audit(audit, model, plan, output)
    elif kind == "replace_choice_option_cp932_same_length":
        if not _has_group_clear(model):
            raise ValueError("Choice option target is not one unique grouped definition")
        source_identity = model["source_ir"]["source_identity"]
        identity = {key: source_identity[key] for key in ("archive", "archive_sha256", "entry")}
        reconstructed = decompiler.reconstruct_container(model["source_ir"])
        matches = []
        for index in choice_prover.group_entry_indices(reconstructed, identity):
            candidate_proof = choice_prover.prove_entry(reconstructed, identity, index)
            for group in candidate_proof["groups"]:
                if group["selector"] != operation.get("group_selector"):
                    continue
                for definition in group["definitions"]:
                    if (
                        definition["definition_id"] == operation.get("definition_id")
                        and definition["message"]["payload_raw_sha256"]
                        == operation.get("source_payload_sha256")
                    ):
                        matches.append(candidate_proof)
        if len(matches) != 1:
            raise ValueError("Choice option target is not one unique grouped definition")
        choice_proof = matches[0]
        plan = choice_planner.plan(reconstructed, choice_proof, operation)
        output, audit = choice_compiler.compile_choice_option(reconstructed, choice_proof, plan)
        choice_compiler.validate_audit(audit, reconstructed, choice_proof, plan, output)
    elif kind == "replace_registered_definition_literal":
        if REGISTRY_MEMBER not in files:
            raise ValueError("Registered-definition call edits need the archive's DEF_MAIN.MES registry proof")
        family = call_prover.prove(decompiler.lift(handoff))
        registry = json.loads(files[REGISTRY_MEMBER])
        plan = call_planner.plan(model, family, registry, operation)
        output, audit = call_compiler.compile_registered_definition_call(model, family, registry, plan)
        call_compiler.validate_audit(audit, model, family, registry, plan, output)
    elif kind == "replace_shared_routine_literal":
        if LIBRARY_MEMBER not in files:
            raise ValueError("Shared-routine call edits need the Godot-built LIBLARY.LIB audit")
        library = json.loads(files[LIBRARY_MEMBER])
        proof = shared_call_prover.prove(decompiler.lift(handoff), library)
        plan = shared_call_planner.plan(model, proof, library, operation)
        output, audit = shared_call_compiler.compile_shared_routine_call(model, proof, library, plan)
        shared_call_compiler.validate_audit(audit, model, proof, library, plan, output)
    elif kind == "retarget_control_flow":
        operation = dict(operation)
        if "replacement_target_instruction_raw_sha256" not in operation:
            unique = _unique_typed_node_map(model["source_ir"])
            replacement_node = unique.get(operation.get("replacement_target_offset"))
            if replacement_node is None:
                raise ValueError("Control-target replacement is not a typed instruction start")
            operation["replacement_target_instruction_raw_sha256"] = replacement_node["source"]["raw_sha256"]
        plan = target_edit_planner.plan(model, operation)
        output, audit = target_edit_compiler.compile_target_edit(model, plan)
        target_edit_compiler.validate_audit(audit, model, plan, output)
    else:
        plan = planner.plan(model, operation)
        output, audit = compiler.compile_state_literal(model, plan)
        compiler.validate_audit(audit, model, plan, output)
    reopened = analyzer.build_handoff(output, handoff["source_identity"])
    proof = (message_diff if extra else semantic_diff).build(model, audit, reopened)
    return {**{name: files[name] for name in SOURCE_FILES}, **extra, **carried,
            "plan.json": _json(plan), "output.mes": output,
            "output.handoff.json": _json(reopened), "compile.audit.json": _json(audit),
            "semantic.diff.json": _json(proof)}


def _sequence_step_offset(operation: dict[str, Any]) -> Any:
    if operation.get("kind") == "replace_choice_option_cp932_same_length":
        return operation.get("group_selector")
    return operation.get("source_offset")


def _sequence_document(step_files: list[dict[str, bytes]]) -> dict[str, Any]:
    rows = []
    for index, step in enumerate(step_files, start=1):
        audit = json.loads(step["compile.audit.json"])
        plan = json.loads(step["plan.json"])
        proof = json.loads(step["semantic.diff.json"])
        control_plan_sha256 = ""
        if "control.plan.json" in step:
            control_plan_sha256 = json.loads(step["control.plan.json"])["payload_sha256"]
        rows.append({
            "index": index, "operation": plan["operation"],
            "source_entry_sha256": audit["source"]["entry_sha256"],
            "output_entry_sha256": audit["output"]["entry_sha256"],
            "plan_sha256": plan["payload_sha256"], "compile_audit_sha256": audit["payload_sha256"],
            "semantic_diff_sha256": proof["payload_sha256"], "control_plan_sha256": control_plan_sha256,
        })
    document = {"ok": True, "schema": SEQUENCE_SCHEMA,
                "source_entry_sha256": rows[0]["source_entry_sha256"],
                "output_entry_sha256": rows[-1]["output_entry_sha256"], "steps": rows}
    document["payload_sha256"] = editable.fingerprint(document)
    return document


def compile_sequence(files: dict[str, bytes], operations: list[dict[str, Any]]) -> dict[str, bytes]:
    if not isinstance(operations, list) or not operations:
        raise ValueError("An operation sequence must be a non-empty list")
    for position, operation in enumerate(operations, start=1):
        if not isinstance(operation, dict) or not operation.get("kind"):
            raise ValueError(f"Step {position} is not an operation")
        if operation.get("kind") == "replace_message" and position != len(operations):
            raise ValueError("A message relocation must be the last operation of a sequence")
    if len(operations) == 1:
        compiled = compile_edit(files, operations[0])
        sequence = _sequence_document([compiled])
        return {**compiled, SEQUENCE_MEMBER: _json(sequence)}
    identity = json.loads(files["handoff.json"])["source_identity"]
    current = files
    step_files: list[dict[str, bytes]] = []
    for position, operation in enumerate(operations, start=1):
        try:
            compiled = compile_edit(current, operation)
        except Exception as error:  # noqa: BLE001 - wrapped with the failing step's identity
            offset = _sequence_step_offset(operation)
            offset_text = f"0x{offset:X}" if isinstance(offset, int) and not isinstance(offset, bool) else str(offset)
            raise ValueError(f"Step {position} ({operation.get('kind')} at {offset_text}): {error}") from error
        step_files.append(compiled)
        registry_proof = json.loads(compiled[REGISTRY_MEMBER]) if REGISTRY_MEMBER in compiled else None
        library_audit = json.loads(compiled[LIBRARY_MEMBER]) if LIBRARY_MEMBER in compiled else None
        current = analyze(compiled["output.mes"], identity, registry_proof, library_audit)
    sequence = _sequence_document(step_files)
    source_subset = {name: files[name] for name in SOURCE_FILES}
    chain_proof = sequence_diff.build(source_subset, step_files)
    result = {name: files[name] for name in SOURCE_FILES}
    result.update({name: files[name] for name in (REGISTRY_MEMBER, LIBRARY_MEMBER) if name in files})
    last = step_files[-1]
    result["output.mes"] = last["output.mes"]
    result["output.handoff.json"] = last["output.handoff.json"]
    result["semantic.diff.json"] = _json(chain_proof)
    result[SEQUENCE_MEMBER] = _json(sequence)
    for index, step in enumerate(step_files, start=1):
        for suffix in STEP_SUFFIXES:
            result[step_member(index, suffix)] = step[suffix]
        if "control.plan.json" in step:
            result[step_member(index, "control.plan.json")] = step["control.plan.json"]
    return result


def _is_step_member(name: str) -> bool:
    if not name.startswith("step-") or len(name) < 9 or name[7] != ".":
        return False
    if not name[5:7].isdigit():
        return False
    suffix = name[8:]
    return suffix in STEP_SUFFIXES or suffix == "control.plan.json"


def _validate_files(files: dict[str, bytes]) -> dict[str, Any]:
    inventory = set(files) - {REGISTRY_MEMBER, LIBRARY_MEMBER}
    step_names = {name for name in inventory if name.startswith("step-")}
    if step_names:
        base = SOURCE_FILES | {"output.mes", "output.handoff.json", "semantic.diff.json", SEQUENCE_MEMBER}
        if inventory - step_names != base or not all(_is_step_member(name) for name in step_names):
            raise ValueError("Authoring bundle inventory changed")
    elif inventory not in (
        SOURCE_FILES, FILES, MESSAGE_FILES, FILES | {SEQUENCE_MEMBER}, MESSAGE_FILES | {SEQUENCE_MEMBER},
    ):
        raise ValueError("Authoring bundle inventory changed")
    handoff = json.loads(files["handoff.json"])
    _source(handoff["source_identity"])
    analyzer.verify(handoff)
    payload = dict(handoff)
    payload.pop("payload_sha256")
    if canonical_json_bytes(payload) != files["handoff.payload.json"]:
        raise ValueError("Authoring handoff canonical byte witness changed")
    model = json.loads(files["editable.json"])
    if editable.prepare(decompiler.lift(handoff)) != model:
        raise ValueError("Authoring model differs from its authoritative handoff")
    if REGISTRY_MEMBER in files:
        registry = json.loads(files[REGISTRY_MEMBER])
        registry_prover.validate_document(registry)
        registry_source = registry["source_identity"]
        if (registry_source["archive"] != handoff["source_identity"]["archive"]
                or registry_source["archive_sha256"] != handoff["source_identity"]["archive_sha256"]):
            raise ValueError("Authoring registry proof does not belong to the source archive")
    if LIBRARY_MEMBER in files:
        library = json.loads(files[LIBRARY_MEMBER])
        shared_call_prover._validate_library_audit(library)
        if (library.get("archive_sha256") != handoff["source_identity"]["archive_sha256"]
                or library.get("entry") != "LIBLARY.LIB"):
            raise ValueError("Authoring library audit does not belong to the source archive")
    compiled = "output.mes" in files
    operations: list[dict[str, Any]] = []
    if compiled:
        if SEQUENCE_MEMBER in files:
            sequence = json.loads(files[SEQUENCE_MEMBER])
            if not isinstance(sequence, dict) or not isinstance(sequence.get("steps"), list):
                raise ValueError("Authoring bundle sequence changed")
            operations = [row["operation"] for row in sequence["steps"]]
            source_subset = {name: files[name] for name in SOURCE_FILES}
            source_subset.update({name: files[name] for name in (REGISTRY_MEMBER, LIBRARY_MEMBER) if name in files})
            expected = compile_sequence(source_subset, operations)
        else:
            plan = json.loads(files["plan.json"])
            operations = [plan["operation"]]
            expected = compile_edit(files, plan["operation"])
        if expected != files:
            raise ValueError("Authoring compiled evidence differs from its exact inputs")
    source = decompiler.reconstruct_container(model["source_ir"])
    return {"source_identity": handoff["source_identity"], "source_entry_sha256": _sha(source),
            "handoff_sha256": handoff["payload_sha256"], "compiled": compiled,
            "output_entry_sha256": _sha(files["output.mes"]) if compiled else "",
            "step_count": len(operations) if compiled else 0, "operations": operations if compiled else [],
            "state_controls": state_controls(model), "message_controls": message_controls(model),
            "condition_controls": condition_controls(model), "resource_controls": resource_controls(model),
            "choice_controls": choice_controls(model), "call_controls": call_controls(model, files),
            "shared_call_controls": shared_call_controls(model, files),
            "control_target_controls": control_target_controls(model)}


def publish(directory: Path, files: dict[str, bytes]) -> dict[str, Any]:
    """Reopen a unique sibling stage and rename it to a new directory on Windows."""
    summary = _validate_files(files)
    directory = directory.resolve()
    if directory.exists():
        raise ValueError("Authoring output already exists")
    directory.parent.mkdir(parents=True, exist_ok=True)
    stage = Path(tempfile.mkdtemp(prefix=".mes-authoring-", dir=directory.parent)).resolve()
    # Cleanup is confined to this invocation's newly created sibling directory.
    if stage.parent != directory.parent or not stage.name.startswith(".mes-authoring-"):
        raise ValueError("Authoring staging directory escaped its parent")
    published = False
    try:
        for name, payload in files.items():
            editable.publish_new(stage / name, payload)
        manifest = {"ok": True, "schema": SCHEMA, "summary": summary,
                    "files": [{"name": name, "size": len(files[name]), "sha256": _sha(files[name])}
                              for name in sorted(files)]}
        manifest["payload_sha256"] = editable.fingerprint(manifest)
        editable.publish_new(stage / "manifest.json", _json(manifest))
        read_bundle(stage)
        if directory.exists():
            raise ValueError("Authoring output appeared during publication")
        os.rename(stage, directory)
        published = True
        return manifest
    finally:
        if not published:
            for name in set(files) | {"manifest.json"}:
                (stage / name).unlink(missing_ok=True)
            stage.rmdir()


def read_bundle(directory: Path) -> tuple[dict[str, Any], dict[str, bytes]]:
    manifest = json.loads((directory / "manifest.json").read_bytes())
    if (set(manifest) != {"ok", "schema", "summary", "files", "payload_sha256"}
            or manifest["ok"] is not True or manifest["schema"] not in (SCHEMA,) + LEGACY_SCHEMAS
            or manifest["payload_sha256"] != editable.fingerprint(manifest)
            or not isinstance(manifest["files"], list)):
        raise ValueError("Authoring bundle manifest changed")
    files = {}
    for row in manifest["files"]:
        if (not isinstance(row, dict) or set(row) != {"name", "size", "sha256"}
                or row["name"] in files or type(row["size"]) is not int
                or (row["name"] not in MESSAGE_FILES | {REGISTRY_MEMBER, LIBRARY_MEMBER, SEQUENCE_MEMBER}
                    and not _is_step_member(row["name"]))):
            raise ValueError("Authoring bundle file binding changed")
        payload = (directory / row["name"]).read_bytes()
        if len(payload) != row["size"] or _sha(payload) != row["sha256"]:
            raise ValueError("Authoring bundle file bytes changed")
        files[row["name"]] = payload
    summary = _validate_files(files)
    if manifest["schema"] in LEGACY_SCHEMAS:
        summary.pop("step_count")
        summary.pop("operations")
        if SEQUENCE_MEMBER in files:
            raise ValueError("Legacy authoring bundle cannot carry a sequence")
        if manifest["schema"] != LEGACY_SCHEMAS[7]:
            summary.pop("control_target_controls")
            if manifest["schema"] != LEGACY_SCHEMAS[6]:
                summary.pop("shared_call_controls")
                if LIBRARY_MEMBER in files:
                    raise ValueError("Legacy authoring bundle cannot carry a library audit")
                if manifest["schema"] != LEGACY_SCHEMAS[5]:
                    summary.pop("call_controls")
                    if REGISTRY_MEMBER in files:
                        raise ValueError("Legacy authoring bundle cannot carry a registry proof")
                    if manifest["schema"] != LEGACY_SCHEMAS[4]:
                        summary.pop("choice_controls")
                        if manifest["schema"] != LEGACY_SCHEMAS[3]:
                            summary.pop("resource_controls")
                            if manifest["schema"] != LEGACY_SCHEMAS[2]:
                                summary.pop("condition_controls")
                                if manifest["schema"] == LEGACY_SCHEMA:
                                    summary.pop("message_controls")
                                    if set(files) not in (SOURCE_FILES, FILES):
                                        raise ValueError("Legacy authoring bundle cannot contain message relocation")
    if summary != manifest["summary"]:
        raise ValueError("Authoring bundle summary changed")
    return manifest, files


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    inspect = sub.add_parser("inspect")
    inspect.add_argument("arc", type=Path)
    inspect.add_argument("entry")
    inspect.add_argument("source_sha256")
    inspect.add_argument("output", type=Path)
    inspect.add_argument("--library-audit", type=Path)
    build = sub.add_parser("compile")
    build.add_argument("bundle", type=Path)
    build.add_argument("operation", type=Path)
    build.add_argument("output", type=Path)
    for command in (inspect, build):
        command.add_argument("--report", type=Path)
    args = parser.parse_args()
    try:
        if args.command == "inspect":
            if args.output.resolve().is_relative_to(args.arc.resolve().parent):
                raise ValueError("Authoring output must be outside the source archive directory")
            archive_sha = _sha(args.arc.read_bytes())
            payload, entry = archive_reader.load_archive_entry(args.arc, args.entry)
            if _sha(payload) != args.source_sha256 or _sha(args.arc.read_bytes()) != archive_sha:
                raise ValueError("Selected original MES changed before authoring")
            registry_proof = None
            if any(name.casefold() == "def_main.mes" for name, _offset, _size in archive_reader.read_entries(args.arc)):
                registry_proof = registry_prover.prove_archive(args.arc, "DEF_MAIN.MES")
            library_audit = None
            if args.library_audit is not None:
                library_audit = json.loads(args.library_audit.read_text(encoding="utf-8"))
                library_payload, _library_entry = archive_reader.load_archive_entry(args.arc, "LIBLARY.LIB")
                if library_audit.get("entry_sha256") != _sha(library_payload):
                    raise ValueError("Library audit does not match the archive's LIBLARY.LIB")
            files = analyze(payload, {"archive": "mes.arc", "entry": entry["entry"],
                                     "archive_sha256": archive_sha, "source_kind": "original_arc"},
                             registry_proof, library_audit)
        else:
            _manifest, source_files = read_bundle(args.bundle)
            request = json.loads(args.operation.read_bytes())
            operations = request if isinstance(request, list) else [request]
            files = compile_sequence(source_files, operations)
        result = publish(args.output, files)
        report = {"ok": True, "schema": SCHEMA, "payload_sha256": result["payload_sha256"]}
    except (ValueError, OSError, KeyError, TypeError) as error:
        report = {"ok": False, "schema": SCHEMA, "error": str(error)}
    if args.report is not None:
        if args.command == "inspect" and args.report.resolve().is_relative_to(args.arc.resolve().parent):
            raise ValueError("Authoring report must be outside the source archive directory")
        editable.publish_new(args.report, _json(report))
    print(json.dumps(report))
    if not report["ok"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
