from __future__ import annotations

import argparse
import copy
import hashlib
import json
from pathlib import Path
from typing import Any

import compile_mes_condition_literal_edit as condition_compiler
import compile_mes_control_target_edit as control_target_compiler
import compile_mes_choice_option_edit as choice_compiler
import compile_mes_inline_script_name_edit as inline_compiler
import compile_mes_registered_definition_call_edit as registered_call_compiler
import compile_mes_resource_name_edit as resource_compiler
import compile_mes_shared_routine_call_edit as shared_call_compiler
import compile_mes_state_literal_edit as state_compiler
import decompile_mes_handoff as decompiler
import prepare_mes_editable_ir as editable_ir
import validate_mes_analyzer_handoff as handoff_validator
from payload_values import canonical_payload_bytes, fingerprint, is_sha256 as _is_sha256


DIFF_SCHEMA = "kakyu_mes_semantic_diff/v2"
TOP_LEVEL_KEYS = {
    "ok", "schema", "producer", "compatibility", "source_identity", "inputs",
    "operation", "container_diff", "semantic_changes", "node_diff", "preservation",
    "output_binding", "invariants", "payload_sha256",
}
PATCH_KEYS = {
    "role", "source_start", "source_end", "output_start", "output_end",
    "byte_length", "source_raw_sha256", "output_raw_sha256", "owner_kind",
    "source_owner_node_id", "output_owner_node_id", "source_owner_start",
    "source_owner_end", "output_owner_start", "output_owner_end",
    "source_owner_sha256", "output_owner_sha256",
}
ASSERTION_KEYS = {
    "kind", "source_value", "output_value", "reference_id",
    "reference_boundary", "verified",
}
NODE_CHANGE_KEYS = {
    "source_node_id", "output_node_id", "source_start", "source_end",
    "output_start", "output_end", "source_raw_sha256", "output_raw_sha256",
    "source_kind", "output_kind",
}
SUPPORTED: dict[str, dict[str, Any]] = {
    state_compiler.AUDIT_SCHEMA: {
        "module": state_compiler, "family": "state_literal_edit",
        "role": "state_expression", "start": "expression_start", "end": "expression_end",
        "owner_start": "instruction_start", "owner_end": "instruction_end",
        "target_key": "target", "patch_key": None,
        "source_patch_hash": "source_expression_sha256",
        "output_patch_hash": "replacement_expression_sha256",
        "source_owner_hash": "source_instruction_sha256",
        "output_owner_hash": "replacement_instruction_sha256", "owner_kind": "statement",
        "assertion": "literal_value", "source_value": "source_value",
        "output_value": "replacement_value",
    },
    condition_compiler.AUDIT_SCHEMA: {
        "module": condition_compiler, "family": "condition_literal_edit",
        "role": "condition_literal", "start": "literal_start", "end": "literal_end",
        "owner_start": "instruction_start", "owner_end": "instruction_end",
        "target_key": "target", "patch_key": None,
        "source_patch_hash": "source_literal_sha256",
        "output_patch_hash": "replacement_literal_sha256",
        "source_owner_hash": "source_instruction_sha256",
        "output_owner_hash": "replacement_instruction_sha256", "owner_kind": "statement",
        "assertion": "literal_value", "source_value": "source_value",
        "output_value": "replacement_value",
    },
    resource_compiler.AUDIT_SCHEMA: {
        "module": resource_compiler, "family": "resource_name_edit",
        "role": "resource_name", "start": "name_start", "end": "name_end",
        "owner_start": "instruction_start", "owner_end": "instruction_end",
        "target_key": "target", "patch_key": None,
        "source_patch_hash": "source_name_sha256",
        "output_patch_hash": "replacement_name_sha256",
        "source_owner_hash": "source_instruction_sha256",
        "output_owner_hash": "replacement_instruction_sha256", "owner_kind": "statement",
        "assertion": "resource_reference",
    },
    inline_compiler.AUDIT_SCHEMA: {
        "module": inline_compiler, "family": "inline_script_name_edit",
        "role": "inline_script_name", "start": "name_start", "end": "name_end",
        "owner_start": "owner_start", "owner_end": "owner_end",
        "target_key": "target", "patch_key": None,
        "source_patch_hash": "source_name_sha256",
        "output_patch_hash": "replacement_name_sha256",
        "source_owner_hash": "source_owner_sha256",
        "output_owner_hash": "replacement_owner_sha256", "owner_kind": None,
        "assertion": "resource_reference",
    },
    shared_call_compiler.AUDIT_SCHEMA: {
        "module": shared_call_compiler, "family": "shared_routine_call_edit",
        "role": "shared_routine_literal", "start": "literal_start", "end": "literal_end",
        "owner_start": "instruction_start", "owner_end": "instruction_end",
        "target_key": "target", "patch_key": None,
        "source_patch_hash": "source_literal_sha256",
        "output_patch_hash": "replacement_literal_sha256",
        "source_owner_hash": "source_instruction_sha256",
        "output_owner_hash": "replacement_instruction_sha256", "owner_kind": "statement",
        "assertion": "literal_value", "source_value": "source_routine_id",
        "output_value": "replacement_routine_id",
    },
    registered_call_compiler.AUDIT_SCHEMA: {
        "module": registered_call_compiler, "family": "registered_definition_call_edit",
        "role": "registered_definition_literal", "start": "literal_start", "end": "literal_end",
        "owner_start": "instruction_start", "owner_end": "instruction_end",
        "target_key": "target", "patch_key": None,
        "source_patch_hash": "source_literal_sha256",
        "output_patch_hash": "replacement_literal_sha256",
        "source_owner_hash": "source_instruction_sha256",
        "output_owner_hash": "replacement_instruction_sha256", "owner_kind": "statement",
        "assertion": "literal_value", "source_value": "source_selector",
        "output_value": "replacement_selector",
    },
    control_target_compiler.AUDIT_SCHEMA: {
        "module": control_target_compiler, "family": "control_target_edit",
        "role": "control_target_operand", "start": "operand_start", "end": "operand_end",
        "owner_start": "instruction_start", "owner_end": "instruction_end",
        "target_key": "source_control", "patch_key": "patch",
        "source_patch_hash": "source_raw_hex", "output_patch_hash": "output_raw_hex",
        "source_owner_hash": "source_instruction_sha256",
        "output_owner_hash": "replacement_instruction_sha256", "owner_kind": "statement",
        "assertion": "code_reference_target", "source_value": "current_target_offset",
        "output_value": "replacement_target_offset",
    },
    choice_compiler.AUDIT_SCHEMA: {
        "module": choice_compiler, "family": "choice_option_edit",
        "role": "choice_option_cp932_payload", "start": "code_start", "end": "code_end",
        "owner_start": None, "owner_end": None, "owner_from_hash": True,
        "target_key": "patch", "patch_key": None,
        "source_patch_hash": "source_payload_sha256",
        "output_patch_hash": "replacement_payload_sha256",
        "source_owner_hash": "source_instruction_sha256",
        "output_owner_hash": "replacement_instruction_sha256", "owner_kind": "statement",
        "assertion": "choice_option_cp932_payload",
        "operation_kind": "replace_choice_option_cp932_same_length",
        "layout_keys": ("size", "entry_count", "code_offset", "code_size", "address_table_sha256"),
    },
}
FAMILY_RULES = {
    spec["family"]: {
        "role": spec["role"],
        "assertion": spec["assertion"],
        "owner_kinds": [spec["owner_kind"]]
        if spec["owner_kind"] is not None else ["statement", "opaque"],
    }
    for spec in SUPPORTED.values()
}
COMPATIBILITY = {
    "policy": "same_layout_exact_patch_and_complete_node_preservation",
    "input_editable_schema": editable_ir.EDITABLE_IR_SCHEMA,
    "input_compile_audit_schemas": sorted(SUPPORTED),
    "input_handoff_schema": handoff_validator.HANDOFF_SCHEMA,
    "output_decompiler_schema": decompiler.DECOMPILER_IR_SCHEMA,
    "supported_families": sorted(spec["family"] for spec in SUPPORTED.values()),
    "opaque_policy": "unrelated_opaque_exact_and_intended_bounded_opaque_patch_explicit",
    "unrelated_node_policy": "every_unpatched_node_maps_once_with_identical_raw_bytes",
    "unknown_diff_schema": "reject",
    "unknown_v2_field": "reject",
}
INVARIANTS = {
    "source_editable_ir_validated": True,
    "compile_audit_validated": True,
    "output_handoff_validated": True,
    "output_decompiler_ir_validated": True,
    "container_layout_preserved": True,
    "expected_output_bytes_exact": True,
    "all_source_nodes_accounted_once": True,
    "all_output_nodes_accounted_once": True,
    "intended_patch_exact": True,
    "semantic_assertion_verified": True,
    "unrelated_typed_nodes_preserved": True,
    "unrelated_opaque_nodes_preserved": True,
}


class MesBytePatchSemanticDiffError(ValueError):
    pass


def build(editable_document: dict[str, Any], audit: dict[str, Any], handoff: dict[str, Any]) -> dict[str, Any]:
    result = _build(editable_document, audit, handoff)
    result["payload_sha256"] = fingerprint(result)
    validate(result, editable_document, audit, handoff)
    return result


def validate(document: dict[str, Any], editable_document: dict[str, Any] | None = None,
             audit: dict[str, Any] | None = None, handoff: dict[str, Any] | None = None) -> dict[str, Any]:
    if document.get("ok") is not True or document.get("schema") != DIFF_SCHEMA or set(document) != TOP_LEVEL_KEYS:
        raise MesBytePatchSemanticDiffError("MES byte-patch semantic diff schema or fields changed")
    if document.get("producer") != {"implementation": "python_phase6_byte_patch_semantic_diff", "contract": DIFF_SCHEMA}:
        raise MesBytePatchSemanticDiffError("MES byte-patch semantic diff producer changed")
    if document.get("compatibility") != COMPATIBILITY:
        raise MesBytePatchSemanticDiffError("MES byte-patch semantic diff compatibility changed")
    retained = document.get("payload_sha256")
    if not _is_sha256(retained) or fingerprint(document) != retained:
        raise MesBytePatchSemanticDiffError("MES byte-patch semantic diff fingerprint changed")
    _validate_shape(document)
    inputs = (editable_document, audit, handoff)
    if any(value is not None for value in inputs):
        if any(value is None for value in inputs):
            raise MesBytePatchSemanticDiffError("MES byte-patch semantic diff validation inputs are incomplete")
        expected = _build(editable_document, audit, handoff)  # type: ignore[arg-type]
        expected["payload_sha256"] = fingerprint(expected)
        if expected != document:
            raise MesBytePatchSemanticDiffError("MES byte-patch semantic diff differs from its inputs")
    return {"ok": True, "schema": DIFF_SCHEMA, "payload_sha256": retained}


def _build(editable_document: dict[str, Any], audit: dict[str, Any], handoff: dict[str, Any]) -> dict[str, Any]:
    editable_ir.validate(editable_document)
    spec = SUPPORTED.get(str(audit.get("schema", "")))
    if spec is None:
        raise MesBytePatchSemanticDiffError("MES byte-patch compile audit schema is unsupported")
    spec["module"].validate_audit(audit)
    handoff_validator.validate(handoff)
    source_ir = editable_document["source_ir"]
    output_ir = decompiler.lift(handoff)
    audit_identity = _normalized_identity(audit["source_identity"])
    if (
        _normalized_identity(source_ir["source_identity"]) != audit_identity
        or _normalized_identity(output_ir["source_identity"]) != audit_identity
    ):
        raise MesBytePatchSemanticDiffError("MES byte-patch source identities changed")
    source_container = decompiler.reconstruct_container(source_ir)
    output_container = decompiler.reconstruct_container(output_ir)
    if hashlib.sha256(source_container).hexdigest() != audit["source"]["entry_sha256"]:
        raise MesBytePatchSemanticDiffError("MES byte-patch source container changed")
    if hashlib.sha256(output_container).hexdigest() != audit["output"]["entry_sha256"]:
        raise MesBytePatchSemanticDiffError("MES byte-patch output container changed")
    source_summary, output_summary = audit["source"], audit["output"]
    layout_keys = spec.get("layout_keys", (
        "size", "entry_count", "code_offset", "code_size", "preamble_sha256",
        "address_table_sha256",
    ))
    if any(source_summary[key] != output_summary[key] for key in layout_keys):
        raise MesBytePatchSemanticDiffError("MES byte-patch container layout changed")
    code_offset = int(source_summary["code_offset"])
    source_code, output_code = source_container[code_offset:], output_container[code_offset:]
    target = audit[spec["target_key"]]
    start, end = int(target[spec["start"]]), int(target[spec["end"]])
    source_patch, output_patch = source_code[start:end], output_code[start:end]
    patch_owner = audit[spec["patch_key"]] if spec["patch_key"] else target
    source_patch_value = patch_owner[spec["source_patch_hash"]]
    output_patch_value = patch_owner[spec["output_patch_hash"]]
    if spec["patch_key"]:
        patch_source_hash = hashlib.sha256(_hex_bytes(source_patch_value, "source patch")).hexdigest()
        patch_output_hash = hashlib.sha256(_hex_bytes(output_patch_value, "output patch")).hexdigest()
    else:
        patch_source_hash, patch_output_hash = source_patch_value, output_patch_value
    if hashlib.sha256(source_patch).hexdigest() != patch_source_hash or hashlib.sha256(output_patch).hexdigest() != patch_output_hash:
        raise MesBytePatchSemanticDiffError("MES byte-patch intended range hash changed")
    expected = source_code[:start] + output_patch + source_code[end:]
    if expected != output_code or source_patch == output_patch:
        raise MesBytePatchSemanticDiffError("MES byte-patch output exceeds or omits the intended range")
    source_nodes = {int(row["source"]["start"]): row for row in source_ir["nodes"]}
    output_nodes = {int(row["source"]["start"]): row for row in output_ir["nodes"]}
    if len(source_nodes) != len(source_ir["nodes"]) or len(output_nodes) != len(output_ir["nodes"]) or set(source_nodes) != set(output_nodes):
        raise MesBytePatchSemanticDiffError("MES byte-patch node starts changed")
    if spec.get("owner_from_hash"):
        owner_start, owner_end = _owner_boundary_by_hash(
            source_nodes, output_nodes, start, end,
            str(target[spec["source_owner_hash"]]),
            str(target[spec["output_owner_hash"]]),
        )
    else:
        owner_start = int(target[spec["owner_start"]])
        owner_end = int(target[spec["owner_end"]])
    owner = source_nodes.get(owner_start)
    output_owner = output_nodes.get(owner_start)
    if owner is None or output_owner is None or int(owner["source"]["end"]) != owner_end or int(output_owner["source"]["end"]) != owner_end:
        raise MesBytePatchSemanticDiffError("MES byte-patch owner boundary changed")
    owner_kind = str(target.get("owner_kind", spec["owner_kind"]))
    if owner["kind"] != owner_kind or output_owner["kind"] != owner_kind:
        raise MesBytePatchSemanticDiffError("MES byte-patch owner kind changed")
    if owner["source"]["raw_sha256"] != target[spec["source_owner_hash"]] or output_owner["source"]["raw_sha256"] != target[spec["output_owner_hash"]]:
        raise MesBytePatchSemanticDiffError("MES byte-patch owner hash changed")
    mapping = []
    exact_typed = exact_opaque = patched_typed = patched_opaque = 0
    for offset in sorted(source_nodes):
        source_node, output_node = source_nodes[offset], output_nodes[offset]
        if int(source_node["source"]["end"]) != int(output_node["source"]["end"]) or source_node["kind"] != output_node["kind"]:
            raise MesBytePatchSemanticDiffError("MES byte-patch node boundary or kind changed")
        changed = offset == owner_start
        if changed != (source_node["source"]["raw_sha256"] != output_node["source"]["raw_sha256"]):
            raise MesBytePatchSemanticDiffError("MES byte-patch changed-node set changed")
        if source_node["kind"] == "opaque":
            patched_opaque += int(changed)
            exact_opaque += int(not changed)
        else:
            patched_typed += int(changed)
            exact_typed += int(not changed)
        mapping.append({"source_node_id": source_node["id"], "output_node_id": output_node["id"], "start": offset,
                        "end": int(source_node["source"]["end"]), "changed": changed})
    assertion = _semantic_assertion(spec, audit, source_ir, output_ir, start)
    node_change = _node_change(owner, output_owner)
    return {
        "ok": True, "schema": DIFF_SCHEMA,
        "producer": {"implementation": "python_phase6_byte_patch_semantic_diff", "contract": DIFF_SCHEMA},
        "compatibility": copy.deepcopy(COMPATIBILITY),
        "source_identity": copy.deepcopy(source_ir["source_identity"]),
        "inputs": {"editable_ir_sha256": editable_document["payload_sha256"],
                   "source_decompiler_ir_sha256": source_ir["payload_sha256"],
                   "compile_audit_sha256": audit["payload_sha256"],
                   "output_analyzer_handoff_sha256": handoff["payload_sha256"]},
        "operation": {
            "family": spec["family"],
            "kind": spec.get("operation_kind", audit.get("operation", {}).get("kind", "")),
        },
        "container_diff": {"source_size": len(source_container), "output_size": len(output_container),
                           "byte_delta": 0, "source_code_size": len(source_code), "output_code_size": len(output_code),
                           "code_delta": 0, "entry_count": int(output_summary["entry_count"]), "code_offset": code_offset},
        "semantic_changes": {"patch": {"role": spec["role"], "source_start": start, "source_end": end,
            "output_start": start, "output_end": end, "byte_length": end - start,
            "source_raw_sha256": hashlib.sha256(source_patch).hexdigest(), "output_raw_sha256": hashlib.sha256(output_patch).hexdigest(),
            "owner_kind": owner_kind, "source_owner_node_id": owner["id"], "output_owner_node_id": output_owner["id"],
            "source_owner_start": owner_start, "source_owner_end": owner_end,
            "output_owner_start": owner_start, "output_owner_end": owner_end,
            "source_owner_sha256": owner["source"]["raw_sha256"], "output_owner_sha256": output_owner["source"]["raw_sha256"]},
            "assertion": assertion},
        "node_diff": {"source_node_count": len(source_nodes), "output_node_count": len(output_nodes),
                      "exact_node_count": len(source_nodes) - 1, "patched_node_count": 1,
                      "mapping_sha256": _json_sha256(mapping), "patched_nodes": [node_change]},
        "preservation": {"source_typed_node_count": exact_typed + patched_typed,
                         "output_typed_node_count": exact_typed + patched_typed,
                         "exact_typed_node_count": exact_typed, "patched_typed_node_count": patched_typed,
                         "source_opaque_node_count": exact_opaque + patched_opaque,
                         "output_opaque_node_count": exact_opaque + patched_opaque,
                         "exact_opaque_node_count": exact_opaque, "patched_opaque_node_count": patched_opaque,
                         "unrelated_exact_node_count": exact_typed + exact_opaque},
        "output_binding": {"analyzer_handoff_sha256": handoff["payload_sha256"],
                           "decompiler_ir_sha256": output_ir["payload_sha256"],
                           "entry_sha256": output_ir["container"]["entry_sha256"],
                           "bytecode_sha256": output_ir["container"]["bytecode_sha256"]},
        "invariants": copy.deepcopy(INVARIANTS),
    }


def _semantic_assertion(spec: dict[str, Any], audit: dict[str, Any], source_ir: dict[str, Any],
                        output_ir: dict[str, Any], patch_start: int) -> dict[str, Any]:
    operation = audit.get("operation", {})
    if spec["assertion"] == "literal_value":
        source_value = operation[spec["source_value"]]
        output_value = operation[spec["output_value"]]
        source_matches = _literal_values_at(source_ir, patch_start)
        output_matches = _literal_values_at(output_ir, patch_start)
        if source_matches != [source_value] or output_matches != [output_value]:
            raise MesBytePatchSemanticDiffError("MES byte-patch literal semantic assertion changed")
        return {"kind": "literal_value", "source_value": source_value, "output_value": output_value,
                "reference_id": "", "reference_boundary": "", "verified": True}
    if spec["assertion"] == "code_reference_target":
        control = audit["source_control"]
        reference_id = str(control["reference_id"])
        source_ref = _reference(source_ir, reference_id)
        output_ref = _reference(output_ir, reference_id)
        source_value = operation[spec["source_value"]]
        output_value = operation[spec["output_value"]]
        boundary = str(operation["reference_kind"])
        if (
            source_ref["value"].get("target_offset") != source_value
            or output_ref["value"].get("target_offset") != output_value
            or source_ref["value"].get("kind") != boundary
            or output_ref["value"].get("kind") != boundary
        ):
            raise MesBytePatchSemanticDiffError(
                "MES byte-patch code-reference semantic assertion changed"
            )
        return {"kind": "code_reference_target", "source_value": source_value,
                "output_value": output_value, "reference_id": reference_id,
                "reference_boundary": boundary, "verified": True}
    if spec["assertion"] == "choice_option_cp932_payload":
        patch = audit["patch"]
        source_value = str(patch["source_payload_sha256"])
        output_value = str(patch["replacement_payload_sha256"])
        if (
            _choice_payload_hashes_at(source_ir, patch_start) != [source_value]
            or _choice_payload_hashes_at(output_ir, patch_start) != [output_value]
        ):
            raise MesBytePatchSemanticDiffError(
                "MES byte-patch choice-option semantic assertion changed"
            )
        return {
            "kind": "choice_option_cp932_payload", "source_value": source_value,
            "output_value": output_value, "reference_id": "",
            "reference_boundary": "typed_cp932_message_payload", "verified": True,
        }
    reference_id = str(operation["reference_id"])
    source_ref = _reference(source_ir, reference_id)
    output_ref = _reference(output_ir, reference_id)
    source_name, output_name = str(operation["source_name"]), str(operation["replacement_name"])
    if str(source_ref["value"].get("source_name", "")).casefold() != source_name.casefold() or str(output_ref["value"].get("source_name", "")).casefold() != output_name.casefold():
        raise MesBytePatchSemanticDiffError("MES byte-patch resource semantic assertion changed")
    boundary = str(audit["target"]["reference_boundary"])
    if str(output_ref["value"].get("boundary", "")) != boundary:
        raise MesBytePatchSemanticDiffError("MES byte-patch resource boundary changed")
    return {"kind": "resource_reference", "source_value": source_name, "output_value": output_name,
            "reference_id": reference_id, "reference_boundary": boundary, "verified": True}


def _literal_values_at(document: dict[str, Any], offset: int) -> list[int]:
    values: list[int] = []
    def visit(value: Any) -> None:
        if isinstance(value, dict):
            if value.get("type") == "literal" and value.get("source", {}).get("offset") == offset and isinstance(value.get("value"), int):
                values.append(int(value["value"]))
            for child in value.values():
                visit(child)
        elif isinstance(value, list):
            for child in value:
                visit(child)
    visit(document["nodes"])
    return values


def _reference(document: dict[str, Any], reference_id: str) -> dict[str, Any]:
    matches = [row for row in document["references"] if row["id"] == reference_id]
    if len(matches) != 1:
        raise MesBytePatchSemanticDiffError("MES byte-patch resource reference changed")
    return matches[0]


def _node_change(source: dict[str, Any], output: dict[str, Any]) -> dict[str, Any]:
    return {"source_node_id": source["id"], "output_node_id": output["id"],
            "source_start": int(source["source"]["start"]), "source_end": int(source["source"]["end"]),
            "output_start": int(output["source"]["start"]), "output_end": int(output["source"]["end"]),
            "source_raw_sha256": source["source"]["raw_sha256"], "output_raw_sha256": output["source"]["raw_sha256"],
            "source_kind": source["kind"], "output_kind": output["kind"]}


def _validate_shape(document: dict[str, Any]) -> None:
    required_dicts = {"operation": {"family", "kind"}, "container_diff": {"source_size", "output_size", "byte_delta", "source_code_size", "output_code_size", "code_delta", "entry_count", "code_offset"},
                      "semantic_changes": {"patch", "assertion"}, "node_diff": {"source_node_count", "output_node_count", "exact_node_count", "patched_node_count", "mapping_sha256", "patched_nodes"},
                      "preservation": {"source_typed_node_count", "output_typed_node_count", "exact_typed_node_count", "patched_typed_node_count", "source_opaque_node_count", "output_opaque_node_count", "exact_opaque_node_count", "patched_opaque_node_count", "unrelated_exact_node_count"},
                      "output_binding": {"analyzer_handoff_sha256", "decompiler_ir_sha256", "entry_sha256", "bytecode_sha256"}}
    for key, keys in required_dicts.items():
        if not isinstance(document.get(key), dict) or set(document[key]) != keys:
            raise MesBytePatchSemanticDiffError(f"MES byte-patch semantic diff {key} fields changed")
    if set(document["semantic_changes"]["patch"]) != PATCH_KEYS or set(document["semantic_changes"]["assertion"]) != ASSERTION_KEYS:
        raise MesBytePatchSemanticDiffError("MES byte-patch semantic change fields changed")
    family = document["operation"]["family"]
    rule = FAMILY_RULES.get(family)
    if (
        rule is None
        or document["semantic_changes"]["patch"]["role"] != rule["role"]
        or document["semantic_changes"]["patch"]["owner_kind"] not in rule["owner_kinds"]
        or document["semantic_changes"]["assertion"]["kind"] != rule["assertion"]
    ):
        raise MesBytePatchSemanticDiffError("MES byte-patch family semantic rule changed")
    nodes, preservation, container = document["node_diff"], document["preservation"], document["container_diff"]
    if nodes["source_node_count"] != nodes["output_node_count"] or nodes["patched_node_count"] != 1 or nodes["exact_node_count"] + 1 != nodes["source_node_count"] or len(nodes["patched_nodes"]) != 1 or set(nodes["patched_nodes"][0]) != NODE_CHANGE_KEYS:
        raise MesBytePatchSemanticDiffError("MES byte-patch semantic diff node accounting changed")
    if any(container[key] != 0 for key in ("byte_delta", "code_delta")) or container["source_size"] != container["output_size"] or container["source_code_size"] != container["output_code_size"]:
        raise MesBytePatchSemanticDiffError("MES byte-patch semantic diff layout changed")
    if preservation["source_typed_node_count"] != preservation["output_typed_node_count"] or preservation["source_opaque_node_count"] != preservation["output_opaque_node_count"] or preservation["exact_typed_node_count"] + preservation["patched_typed_node_count"] != preservation["source_typed_node_count"] or preservation["exact_opaque_node_count"] + preservation["patched_opaque_node_count"] != preservation["source_opaque_node_count"] or preservation["patched_typed_node_count"] + preservation["patched_opaque_node_count"] != 1 or preservation["unrelated_exact_node_count"] != nodes["exact_node_count"]:
        raise MesBytePatchSemanticDiffError("MES byte-patch semantic diff preservation accounting changed")
    if document.get("invariants") != INVARIANTS or any(not _is_sha256(value) for value in document["inputs"].values()) or any(not _is_sha256(value) for value in document["output_binding"].values()):
        raise MesBytePatchSemanticDiffError("MES byte-patch semantic diff binding or invariants changed")
    if document["semantic_changes"]["assertion"]["verified"] is not True:
        raise MesBytePatchSemanticDiffError("MES byte-patch semantic assertion is not verified")
    if document["semantic_changes"]["assertion"]["kind"] not in {
        "literal_value", "resource_reference", "code_reference_target",
        "choice_option_cp932_payload",
    }:
        raise MesBytePatchSemanticDiffError("MES byte-patch semantic assertion kind changed")


def _json_sha256(value: Any) -> str:
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(",", ":")).encode()).hexdigest()


def _hex_bytes(value: Any, label: str) -> bytes:
    if not isinstance(value, str):
        raise MesBytePatchSemanticDiffError(f"MES byte-patch {label} is missing")
    try:
        return bytes.fromhex(value)
    except ValueError as error:
        raise MesBytePatchSemanticDiffError(f"MES byte-patch {label} is invalid") from error


def _normalized_identity(value: Any) -> dict[str, Any]:
    if not isinstance(value, dict):
        raise MesBytePatchSemanticDiffError("MES byte-patch source identity is invalid")
    result = copy.deepcopy(value)
    result.pop("entry_sha256", None)
    result.pop("source_kind", None)
    return result


def _owner_boundary_by_hash(
    source_nodes: dict[int, dict[str, Any]], output_nodes: dict[int, dict[str, Any]],
    patch_start: int, patch_end: int, source_hash: str, output_hash: str,
) -> tuple[int, int]:
    matches = []
    for start, source_node in source_nodes.items():
        end = int(source_node["source"]["end"])
        output_node = output_nodes[start]
        if (
            start <= patch_start < patch_end <= end
            and source_node["source"]["raw_sha256"] == source_hash
            and int(output_node["source"]["end"]) == end
            and output_node["source"]["raw_sha256"] == output_hash
        ):
            matches.append((start, end))
    if len(matches) != 1:
        raise MesBytePatchSemanticDiffError(
            "MES byte-patch owner boundary is not uniquely hash-bound"
        )
    return matches[0]


def _choice_payload_hashes_at(document: dict[str, Any], offset: int) -> list[str]:
    matches = []
    for node in document["nodes"]:
        statement = node.get("statement", {})
        if node.get("kind") != "statement" or statement.get("op") != "text":
            continue
        for operand in statement.get("operands", []):
            if operand.get("type") != "cp932_bytes" or operand.get("source_offset") != offset:
                continue
            raw_hex = operand.get("raw_hex")
            matches.append(hashlib.sha256(_hex_bytes(raw_hex, "choice payload")).hexdigest())
    return matches


def main() -> None:
    parser = argparse.ArgumentParser(description="Build an exact semantic diff for one same-layout MES byte patch.")
    parser.add_argument("editable_ir", type=Path)
    parser.add_argument("compile_audit", type=Path)
    parser.add_argument("output_handoff", type=Path)
    parser.add_argument("output_diff", type=Path)
    args = parser.parse_args()
    paths = [args.editable_ir, args.compile_audit, args.output_handoff, args.output_diff]
    if len({path.resolve() for path in paths}) != 4 or args.output_diff.exists():
        raise MesBytePatchSemanticDiffError("MES byte-patch semantic diff output must be a new distinct file")
    values = [json.loads(path.read_text(encoding="utf-8")) for path in paths[:3]]
    document = build(values[0], values[1], values[2])
    editable_ir.publish_new(args.output_diff, editable_ir.canonical_json_bytes(document) + b"\n")
    print("MES_BYTE_PATCH_SEMANTIC_DIFF_PASS " f"schema={DIFF_SCHEMA} entry={document['source_identity']['entry']} "
          f"family={document['operation']['family']} owner_kind={document['semantic_changes']['patch']['owner_kind']} "
          f"typed_exact={document['preservation']['exact_typed_node_count']} opaque_exact={document['preservation']['exact_opaque_node_count']} "
          f"payload_sha256={document['payload_sha256']}")


if __name__ == "__main__":
    main()
