from __future__ import annotations

import argparse
import copy
import json
import re
from pathlib import Path
from typing import Any

import decompile_mes_handoff as decompiler
from payload_values import canonical_payload_bytes, fingerprint


CALL_FAMILY_PROOF_SCHEMA = "kakyu_mes_call_family_proof/v1"
SAFE_MES_TARGET = re.compile(r"^[A-Za-z0-9_]+\.MES$", re.IGNORECASE)


class CallFamilyProofError(ValueError):
    pass


def prove(linear_ir: dict[str, Any]) -> dict[str, Any]:
    decompiler.validate(linear_ir)
    document = _build(linear_ir)
    document["payload_sha256"] = fingerprint(document)
    validate(document, linear_ir)
    return document


def validate(
    document: dict[str, Any], linear_ir: dict[str, Any]
) -> dict[str, Any]:
    if document.get("schema") != CALL_FAMILY_PROOF_SCHEMA:
        raise CallFamilyProofError("unsupported call-family proof schema")
    retained = document.get("payload_sha256")
    if (
        not isinstance(retained, str)
        or len(retained) != 64
        or fingerprint(document) != retained
    ):
        raise CallFamilyProofError("call-family proof fingerprint changed")
    decompiler.validate(linear_ir)
    expected = _build(linear_ir)
    actual = dict(document)
    actual.pop("payload_sha256", None)
    if actual != expected:
        raise CallFamilyProofError("call-family projection changed")
    return {
        "ok": True,
        "schema": CALL_FAMILY_PROOF_SCHEMA,
        "payload_sha256": retained,
    }


def _build(linear_ir: dict[str, Any]) -> dict[str, Any]:
    nodes = [node for node in linear_ir["nodes"] if isinstance(node, dict)]
    nodes_by_start: dict[int, list[dict[str, Any]]] = {}
    for node in nodes:
        nodes_by_start.setdefault(int(node["source"]["start"]), []).append(node)
    call_sites: list[dict[str, Any]] = []
    rejected: list[dict[str, Any]] = []
    for node in nodes:
        statement = node.get("statement", {})
        op = statement.get("op")
        if op not in {"script_dispatch", "definition_invoke"}:
            continue
        resume, reason = _resume_node(node, nodes_by_start)
        if resume is None:
            rejected.append(_rejection(node, str(op), reason))
            continue
        if op == "script_dispatch":
            call, reason = _external_script_call(node, resume)
        else:
            call, reason = _registered_definition_call(node, resume)
        if call is None:
            rejected.append(_rejection(node, str(op), reason))
        else:
            call_sites.append(call)
    calls = linear_ir.get("analysis_evidence", {}).get("calls", [])
    return {
        "ok": True,
        "schema": CALL_FAMILY_PROOF_SCHEMA,
        "producer": {
            "implementation": "python_phase5_call_family_prover",
            "contract": CALL_FAMILY_PROOF_SCHEMA,
        },
        "compatibility": {
            "policy": "exact_linear_ir_match",
            "input_decompiler_schema": decompiler.DECOMPILER_IR_SCHEMA,
            "unknown_v1_field": "ignore",
            "promotion_policy": "typed_external_or_registered_call_site_with_exact_physical_resume",
            "return_edge_policy": "never_emit_without_source_bound_total_callee_or_registry_body_proof",
            "supplemental_call_evidence_policy": "retained_in_linear_input_not_promoted_without_exact_call_site_binding",
            "fallback_policy": "retain_original_numeric_or_typed_linear_node",
        },
        "input": {
            "linear_ir_sha256": linear_ir["payload_sha256"],
        },
        "source_identity": copy.deepcopy(linear_ir.get("source_identity", {})),
        "call_sites": call_sites,
        "rejected_call_sites": rejected,
        "coverage": {
            "typed_call_family_count": len(call_sites) + len(rejected),
            "proved_call_site_count": len(call_sites),
            "external_mes_call_site_count": sum(
                call["kind"] == "external_mes_script_call_site"
                for call in call_sites
            ),
            "registered_definition_call_site_count": sum(
                call["kind"] == "registered_definition_call_site"
                for call in call_sites
            ),
            "literal_registered_selector_count": sum(
                call["kind"] == "registered_definition_call_site"
                and call["selector"]["kind"] == "literal"
                for call in call_sites
            ),
            "dynamic_registered_selector_count": sum(
                call["kind"] == "registered_definition_call_site"
                and call["selector"]["kind"] == "expression"
                for call in call_sites
            ),
            "rejected_call_site_count": len(rejected),
            "proved_return_edge_count": 0,
            "supplemental_call_evidence_count": len(calls),
        },
    }


def _resume_node(
    call_node: dict[str, Any],
    nodes_by_start: dict[int, list[dict[str, Any]]],
) -> tuple[dict[str, Any] | None, str]:
    call_end = int(call_node["source"]["end"])
    candidates = nodes_by_start.get(call_end, [])
    if not candidates:
        return None, "physical_resume_node_missing"
    if len(candidates) != 1:
        return None, "physical_resume_node_ambiguous"
    if candidates[0]["source"].get("entry") != call_node["source"].get("entry"):
        return None, "physical_resume_entry_changed"
    return candidates[0], ""


def _external_script_call(
    node: dict[str, Any], resume: dict[str, Any]
) -> tuple[dict[str, Any] | None, str]:
    statement = node["statement"]
    metadata = statement.get("metadata", {})
    target = metadata.get("script_target")
    if not isinstance(target, str) or SAFE_MES_TARGET.fullmatch(target) is None:
        return None, "external_mes_target_is_not_safe_and_typed"
    records = _single_record_list(statement)
    if records is None or len(records) != 1 or records[0].get("type") != "string_record":
        return None, "external_mes_target_record_shape_changed"
    value = records[0].get("value", {})
    if not isinstance(value, dict):
        return None, "external_mes_target_record_shape_changed"
    raw_hex = value.get("raw_hex")
    if not isinstance(raw_hex, str):
        return None, "external_mes_target_bytes_are_missing"
    try:
        decoded = bytes.fromhex(raw_hex).decode("ascii")
    except (UnicodeDecodeError, ValueError):
        return None, "external_mes_target_bytes_are_not_ascii"
    if decoded.lower() != target.lower():
        return None, "external_mes_target_metadata_disagrees_with_record"
    return {
        **_base_call_site(node, resume),
        "kind": "external_mes_script_call_site",
        "target_entry": target.upper(),
        "target_entry_coordinate": 0,
        "proof_status": "typed_safe_external_mes_target_and_exact_physical_resume",
        "native_role": "nested_mes_call_with_saved_caller_coordinate",
        "callee_control_flow": "not_supplied",
        "return_edge": "unproved_callee_total_return_not_supplied",
        "surface_syntax": "external_call_site_with_low_level_fallback",
    }, ""


def _registered_definition_call(
    node: dict[str, Any], resume: dict[str, Any]
) -> tuple[dict[str, Any] | None, str]:
    records = _single_record_list(node["statement"])
    if (
        records is None
        or len(records) != 1
        or records[0].get("type") != "expression_record"
    ):
        return None, "registered_selector_is_not_one_expression_record"
    value = records[0].get("value", {})
    ast = value.get("ast", {}) if isinstance(value, dict) else {}
    if not isinstance(ast, dict) or not ast:
        return None, "registered_selector_ast_is_missing"
    selector: dict[str, Any]
    if _is_integer_literal(ast):
        selector = {"kind": "literal", "value": int(ast["value"])}
    else:
        selector = {"kind": "expression", "ast": copy.deepcopy(ast)}
    return {
        **_base_call_site(node, resume),
        "kind": "registered_definition_call_site",
        "selector": selector,
        "proof_status": "typed_registered_selector_and_exact_physical_resume",
        "native_role": "registered_definition_lookup_call_and_restore",
        "registry_binding": "not_supplied",
        "return_edge": "unproved_registered_body_binding_not_supplied",
        "surface_syntax": "registered_call_site_with_low_level_fallback",
    }, ""


def _base_call_site(
    node: dict[str, Any], resume: dict[str, Any]
) -> dict[str, Any]:
    source = node["source"]
    return {
        "id": f"call_family_{int(source['start']):08x}",
        "call_node_id": str(node["id"]),
        "caller_entry": str(source.get("entry", "")),
        "caller_region": str(source["region"]),
        "call_start": int(source["start"]),
        "call_end": int(source["end"]),
        "physical_resume_offset": int(source["end"]),
        "physical_resume_node_id": str(resume["id"]),
        "physical_resume_region": str(resume["source"]["region"]),
        "fallback_linear_node_id": str(node["id"]),
        "cfg_edge_emitted": False,
    }


def _single_record_list(statement: dict[str, Any]) -> list[dict[str, Any]] | None:
    operands = statement.get("operands", [])
    if not isinstance(operands, list) or len(operands) != 1:
        return None
    operand = operands[0]
    if not isinstance(operand, dict) or operand.get("type") != "record_list":
        return None
    records = operand.get("records")
    if not isinstance(records, list) or any(
        not isinstance(record, dict) for record in records
    ):
        return None
    return records


def _is_integer_literal(ast: dict[str, Any]) -> bool:
    return (
        ast.get("type") == "literal"
        and isinstance(ast.get("value"), int)
        and not isinstance(ast.get("value"), bool)
    )


def _rejection(
    node: dict[str, Any], family: str, reason: str
) -> dict[str, Any]:
    return {
        "call_node_id": str(node.get("id", "")),
        "call_start": int(node.get("source", {}).get("start", -1)),
        "call_end": int(node.get("source", {}).get("end", -1)),
        "family": family,
        "reason": reason,
        "fallback_linear_node_id": str(node.get("id", "")),
    }


def main() -> None:
    parser = argparse.ArgumentParser(
        description=(
            "Prove typed external-MES and registered-definition call sites "
            "without inventing return edges."
        )
    )
    parser.add_argument("linear_ir", type=Path)
    parser.add_argument("output", type=Path, nargs="?")
    args = parser.parse_args()
    linear_ir = json.loads(args.linear_ir.read_text(encoding="utf-8"))
    document = prove(linear_ir)
    encoded = json.dumps(
        document,
        ensure_ascii=False,
        allow_nan=False,
        sort_keys=True,
        separators=(",", ":"),
    )
    if args.output is not None:
        if args.output.resolve() == args.linear_ir.resolve():
            raise CallFamilyProofError(
                "call-family output must not replace its linear input"
            )
        args.output.write_text(encoded + "\n", encoding="utf-8")
    print(
        "MES_CALL_FAMILY_PROOF_PASS "
        f"schema={document['schema']} entry={document['source_identity'].get('entry', '')} "
        f"sites={document['coverage']['proved_call_site_count']} "
        f"external={document['coverage']['external_mes_call_site_count']} "
        f"registered={document['coverage']['registered_definition_call_site_count']} "
        f"return_edges={document['coverage']['proved_return_edge_count']} "
        f"rejected={document['coverage']['rejected_call_site_count']} "
        f"payload_sha256={document['payload_sha256']}"
    )


if __name__ == "__main__":
    main()
