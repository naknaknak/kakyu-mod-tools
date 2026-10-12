from __future__ import annotations

import argparse
import copy
import hashlib
import json
from pathlib import Path
from typing import Any

import decompile_mes_handoff as decompiler
from payload_values import canonical_payload_bytes, fingerprint


SHARED_CALL_RETURN_PROOF_SCHEMA = "kakyu_mes_shared_call_return_proof/v2"
LIBRARY_AUDIT_SCHEMA = "kakyu_mes_library_audit/v17"


class SharedCallReturnProofError(ValueError):
    pass


def canonical_input_bytes(document: dict[str, Any]) -> bytes:
    return json.dumps(
        document,
        ensure_ascii=False,
        allow_nan=False,
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")


def input_fingerprint(document: dict[str, Any]) -> str:
    return hashlib.sha256(canonical_input_bytes(document)).hexdigest()


def prove(linear_ir: dict[str, Any], library_audit: dict[str, Any]) -> dict[str, Any]:
    decompiler.validate(linear_ir)
    routines = _validate_library_audit(library_audit)
    return_contracts = _resolve_total_return_contracts(routines)
    document = _build(linear_ir, library_audit, routines, return_contracts)
    document["payload_sha256"] = fingerprint(document)
    validate(document, linear_ir, library_audit)
    return document


def validate(
    document: dict[str, Any],
    linear_ir: dict[str, Any],
    library_audit: dict[str, Any],
) -> dict[str, Any]:
    if document.get("schema") != SHARED_CALL_RETURN_PROOF_SCHEMA:
        raise SharedCallReturnProofError("unsupported shared-call return proof schema")
    retained = document.get("payload_sha256")
    if (
        not isinstance(retained, str)
        or len(retained) != 64
        or fingerprint(document) != retained
    ):
        raise SharedCallReturnProofError("shared-call return proof fingerprint changed")
    decompiler.validate(linear_ir)
    routines = _validate_library_audit(library_audit)
    return_contracts = _resolve_total_return_contracts(routines)
    expected = _build(linear_ir, library_audit, routines, return_contracts)
    actual = dict(document)
    actual.pop("payload_sha256", None)
    if actual != expected:
        raise SharedCallReturnProofError("shared-call return projection changed")
    return {
        "ok": True,
        "schema": SHARED_CALL_RETURN_PROOF_SCHEMA,
        "payload_sha256": retained,
    }


def _build(
    linear_ir: dict[str, Any],
    library_audit: dict[str, Any],
    routines: dict[int, dict[str, Any]],
    return_contracts: dict[int, dict[str, Any]],
) -> dict[str, Any]:
    proved: list[dict[str, Any]] = []
    unresolved: list[dict[str, Any]] = []
    call_nodes = [
        node
        for node in linear_ir["nodes"]
        if node.get("kind") == "statement"
        and node.get("statement", {}).get("op") == "script_transfer"
    ]
    call_nodes.sort(
        key=lambda node: (
            int(node["source"]["start"]),
            int(node["source"]["end"]),
            str(node["id"]),
        )
    )
    for node in call_nodes:
        routine_id, reason = _literal_routine_id(node)
        if routine_id is None:
            unresolved.append(_unresolved_call(node, reason))
            continue
        routine = routines.get(routine_id)
        if routine is None:
            unresolved.append(
                _unresolved_call(
                    node,
                    "shared_routine_is_absent_from_supplied_library_audit",
                    routine_id,
                )
            )
            continue
        return_contract = return_contracts[routine_id]
        if return_contract["proved"] is not True:
            unresolved.append(
                _unresolved_call(
                    node,
                    str(return_contract["reason"]),
                    routine_id,
                    return_contract.get("direct_callee_routine_ids", []),
                )
            )
            continue
        flow = routine["native_dispatch_flow"]
        proved.append(
            {
                "id": f"shared_call_{int(node['source']['start']):08x}",
                "kind": "shared_routine_call_return",
                "call_node_id": str(node["id"]),
                "caller_entry": str(node["source"].get("entry", "")),
                "caller_region": str(node["source"]["region"]),
                "call_start": int(node["source"]["start"]),
                "call_end": int(node["source"]["end"]),
                "physical_resume_offset": int(node["source"]["end"]),
                "routine_id": routine_id,
                "callee_entry": str(library_audit["entry"]),
                "callee_body_start": int(routine["body_offset"]),
                "callee_body_end": int(routine["end_offset"]),
                "callee_return_offsets": sorted(
                    int(value) for value in flow["return_offsets"]
                ),
                "direct_callee_routine_ids": copy.deepcopy(
                    return_contract["direct_callee_routine_ids"]
                ),
                "transitive_callee_routine_ids": copy.deepcopy(
                    return_contract["transitive_callee_routine_ids"]
                ),
                "proof_status": "literal_shared_call_all_callee_terminals_return_to_physical_resume",
                "surface_syntax": "shared_call_with_numeric_routine_id",
                "fallback_linear_node_id": str(node["id"]),
            }
        )
    return {
        "ok": True,
        "schema": SHARED_CALL_RETURN_PROOF_SCHEMA,
        "producer": {
            "implementation": "python_phase5_shared_call_return_prover",
            "contract": SHARED_CALL_RETURN_PROOF_SCHEMA,
        },
        "compatibility": {
            "policy": "exact_linear_ir_and_library_audit_match",
            "input_decompiler_schema": decompiler.DECOMPILER_IR_SCHEMA,
            "input_library_audit_schema": LIBRARY_AUDIT_SCHEMA,
            "unknown_v2_field": "ignore",
            "promotion_policy": "literal_command_1d_and_complete_total_return_library_cfg_with_fixed_point_nested_call_certificates",
            "decode_policy": "native_dispatch_flow_may_supersede_incomplete_strict_or_structural_diagnostic_decode",
            "unproved_call_policy": "retain_numeric_script_transfer_fallback",
            "excluded_call_families": [
                "dynamic_shared_routine_selector",
                "registered_definition_call",
                "external_mes_script_dispatch",
            ],
        },
        "inputs": {
            "linear_ir_sha256": linear_ir["payload_sha256"],
            "library_audit_sha256": input_fingerprint(library_audit),
        },
        "source_identity": copy.deepcopy(linear_ir.get("source_identity", {})),
        "library_identity": {
            "archive_name": str(library_audit["archive_name"]),
            "archive_sha256": str(library_audit["archive_sha256"]),
            "entry": str(library_audit["entry"]),
            "entry_sha256": str(library_audit["entry_sha256"]),
        },
        "proved_calls": proved,
        "unresolved_calls": unresolved,
        "routine_return_contracts": [
            copy.deepcopy(return_contracts[routine_id])
            for routine_id in sorted(return_contracts)
        ],
        "coverage": {
            "script_transfer_count": len(call_nodes),
            "proved_call_return_count": len(proved),
            "unresolved_call_count": len(unresolved),
            "audited_routine_count": len(routines),
            "proved_total_return_routine_count": sum(
                1 for contract in return_contracts.values() if contract["proved"] is True
            ),
            "unresolved_total_return_routine_count": sum(
                1 for contract in return_contracts.values() if contract["proved"] is not True
            ),
        },
    }


def _validate_library_audit(
    document: dict[str, Any],
) -> dict[int, dict[str, Any]]:
    if document.get("schema") != LIBRARY_AUDIT_SCHEMA or document.get("ok") is not True:
        raise SharedCallReturnProofError("unsupported or failed library audit")
    if document.get("source_archive_unchanged") is not True:
        raise SharedCallReturnProofError("library audit did not preserve its source archive")
    if str(document.get("entry", "")).upper() != "LIBLARY.LIB":
        raise SharedCallReturnProofError("library audit is not bound to LIBLARY.LIB")
    for key in ("archive_sha256", "entry_sha256"):
        value = document.get(key)
        if not isinstance(value, str) or len(value) != 64:
            raise SharedCallReturnProofError(f"library audit {key} is missing")
    routines_value = document.get("routines")
    if not isinstance(routines_value, list):
        raise SharedCallReturnProofError("library audit routines are missing")
    routines: dict[int, dict[str, Any]] = {}
    for routine in routines_value:
        if not isinstance(routine, dict):
            raise SharedCallReturnProofError("library audit routine is not an object")
        routine_id = int(routine.get("routine_id", -1))
        body_start = int(routine.get("body_offset", -1))
        body_end = int(routine.get("end_offset", -1))
        if routine_id < 0 or routine_id in routines or body_start < 0 or body_end <= body_start:
            raise SharedCallReturnProofError("library audit routine identity or bounds changed")
        for key in ("strict", "structural"):
            summary = routine.get(key)
            if (
                not isinstance(summary, dict)
                or not isinstance(summary.get("complete"), bool)
            ):
                raise SharedCallReturnProofError(
                    f"library audit routine {routine_id} {key} decode summary changed"
                )
            decoded_end = int(summary.get("decoded_end_offset", -1))
            if (
                decoded_end < body_start
                or decoded_end > body_end
                or (summary["complete"] is True and decoded_end != body_end)
            ):
                raise SharedCallReturnProofError(
                    f"library audit routine {routine_id} {key} decode bounds changed"
                )
        flow = routine.get("native_dispatch_flow")
        if not isinstance(flow, dict):
            raise SharedCallReturnProofError("library audit native dispatch flow is missing")
        instructions = flow.get("instructions")
        edges = flow.get("edges")
        returns = flow.get("return_offsets")
        if not isinstance(instructions, list) or not isinstance(edges, list) or not isinstance(returns, list):
            raise SharedCallReturnProofError("library audit flow arrays are missing")
        offsets = [int(row.get("source_offset", -1)) for row in instructions if isinstance(row, dict)]
        if (
            len(offsets) != len(instructions)
            or len(set(offsets)) != len(offsets)
            or any(offset < body_start or offset >= body_end for offset in offsets)
            or int(flow.get("instruction_count", -1)) != len(instructions)
            or int(flow.get("edge_count", -1)) != len(edges)
        ):
            raise SharedCallReturnProofError("library audit flow instruction coverage changed")
        for row in instructions:
            decoded_end = int(row.get("decoded_end_offset", -1))
            if decoded_end <= int(row["source_offset"]) or decoded_end > body_end:
                raise SharedCallReturnProofError(
                    "library audit flow instruction bounds changed"
                )
        offset_set = set(offsets)
        for edge in edges:
            if (
                not isinstance(edge, dict)
                or int(edge.get("from_offset", -1)) not in offset_set
                or int(edge.get("to_offset", -1)) not in offset_set
            ):
                raise SharedCallReturnProofError("library audit flow contains a dangling edge")
        if any(int(offset) not in offset_set for offset in returns):
            raise SharedCallReturnProofError("library audit return offset is not an instruction")
        routines[routine_id] = routine
    return routines


def _resolve_total_return_contracts(
    routines: dict[int, dict[str, Any]],
) -> dict[int, dict[str, Any]]:
    local_results: dict[int, tuple[bool, str, list[int]]] = {
        routine_id: _local_total_return_contract(routine)
        for routine_id, routine in routines.items()
    }
    proved: set[int] = set()
    transitive: dict[int, set[int]] = {}
    changed = True
    while changed:
        changed = False
        for routine_id in sorted(routines):
            local_ok, _reason, direct_callees = local_results[routine_id]
            if routine_id in proved or not local_ok:
                continue
            if all(callee in proved for callee in direct_callees):
                proved.add(routine_id)
                closure: set[int] = set(direct_callees)
                for callee in direct_callees:
                    closure.update(transitive[callee])
                transitive[routine_id] = closure
                changed = True

    contracts: dict[int, dict[str, Any]] = {}
    for routine_id in sorted(routines):
        local_ok, local_reason, direct_callees = local_results[routine_id]
        reason = ""
        if not local_ok:
            reason = local_reason
        elif routine_id not in proved:
            missing = sorted(callee for callee in direct_callees if callee not in routines)
            invalid = sorted(
                callee
                for callee in direct_callees
                if callee in routines and local_results[callee][0] is not True
            )
            if missing:
                reason = "shared_routine_nested_callee_is_absent_from_supplied_library_audit"
            elif invalid:
                reason = "shared_routine_nested_callee_is_not_total_return"
            else:
                reason = "shared_routine_nested_call_graph_is_cyclic_or_unresolved"
        contracts[routine_id] = {
            "routine_id": routine_id,
            "proved": routine_id in proved,
            "reason": reason,
            "direct_callee_routine_ids": direct_callees,
            "transitive_callee_routine_ids": sorted(transitive.get(routine_id, set())),
        }
    return contracts


def _local_total_return_contract(
    routine: dict[str, Any],
) -> tuple[bool, str, list[int]]:
    flow = routine["native_dispatch_flow"]
    if flow.get("complete") is not True:
        return False, "shared_routine_native_cfg_is_incomplete", []
    for key in ("failures", "boundaries", "exit_offsets"):
        value = flow.get(key)
        if not isinstance(value, list) or value:
            return False, f"shared_routine_has_{key}", []
    instructions = {
        int(row["source_offset"]): row for row in flow["instructions"]
    }
    entry_offset = int(routine["body_offset"])
    if entry_offset not in instructions:
        return False, "shared_routine_entry_is_not_a_native_cfg_instruction", []
    direct_callees: list[int] = []
    for instruction in instructions.values():
        if int(instruction.get("command_id", -1)) != 0x1D:
            continue
        if instruction.get("op") != "script_transfer":
            return False, "shared_routine_nested_call_shape_changed", []
        routine_id = instruction.get("routine_id")
        if (
            not isinstance(routine_id, int)
            or isinstance(routine_id, bool)
            or routine_id < 0
        ):
            return False, "shared_routine_nested_call_is_not_literal", []
        direct_callees.append(routine_id)
    direct_callees = sorted(set(direct_callees))
    outgoing = {offset: set() for offset in instructions}
    incoming = {offset: set() for offset in instructions}
    for edge in flow["edges"]:
        source = int(edge["from_offset"])
        target = int(edge["to_offset"])
        outgoing[source].add(target)
        incoming[target].add(source)
    reachable: set[int] = set()
    pending = [entry_offset]
    while pending:
        offset = pending.pop()
        if offset in reachable:
            continue
        reachable.add(offset)
        pending.extend(sorted(outgoing[offset], reverse=True))
    if reachable != set(instructions):
        return False, "shared_routine_native_cfg_has_unreachable_instruction", direct_callees
    remaining_incoming = {
        offset: len(incoming[offset]) for offset in instructions
    }
    ready = sorted(offset for offset, count in remaining_incoming.items() if count == 0)
    visited = 0
    while ready:
        offset = ready.pop(0)
        visited += 1
        for target in sorted(outgoing[offset]):
            remaining_incoming[target] -= 1
            if remaining_incoming[target] == 0:
                ready.append(target)
                ready.sort()
    if visited != len(instructions):
        return False, "shared_routine_native_cfg_is_cyclic", direct_callees
    terminals = {offset for offset, targets in outgoing.items() if not targets}
    returns = {int(offset) for offset in flow["return_offsets"]}
    if not returns:
        return False, "shared_routine_has_no_return_terminal", direct_callees
    if terminals != returns:
        return False, "shared_routine_has_nonreturn_terminal", direct_callees
    if any(int(instructions[offset].get("command_id", -1)) != 0 for offset in returns):
        return False, "shared_routine_return_terminal_is_not_command_00", direct_callees
    return True, "", direct_callees


def _literal_routine_id(node: dict[str, Any]) -> tuple[int | None, str]:
    statement = node.get("statement", {})
    if int(statement.get("command_id", -1)) != 0x1D:
        return None, "script_transfer_command_id_changed"
    operands = statement.get("operands")
    if not isinstance(operands, list) or len(operands) != 1:
        return None, "shared_routine_operand_shape_is_not_one_record_list"
    records = operands[0].get("records") if isinstance(operands[0], dict) else None
    if not isinstance(records, list) or len(records) != 1:
        return None, "shared_routine_selector_is_not_one_record"
    record = records[0]
    if not isinstance(record, dict) or record.get("type") != "expression_record":
        return None, "shared_routine_selector_is_not_an_expression_record"
    ast = record.get("value", {}).get("ast", {})
    if not isinstance(ast, dict) or ast.get("type") != "literal":
        return None, "shared_routine_selector_is_dynamic"
    raw_value = ast.get("value")
    if not isinstance(raw_value, int) or isinstance(raw_value, bool) or raw_value < 0:
        return None, "shared_routine_literal_is_not_a_non_negative_integer"
    return raw_value, ""


def _unresolved_call(
    node: dict[str, Any],
    reason: str,
    routine_id: int | None = None,
    required_callee_routine_ids: list[int] | None = None,
) -> dict[str, Any]:
    result = {
        "call_node_id": str(node["id"]),
        "caller_region": str(node["source"]["region"]),
        "call_start": int(node["source"]["start"]),
        "call_end": int(node["source"]["end"]),
        "reason": reason,
        "fallback_linear_node_id": str(node["id"]),
    }
    if routine_id is not None:
        result["routine_id"] = routine_id
    if required_callee_routine_ids:
        result["required_callee_routine_ids"] = copy.deepcopy(
            required_callee_routine_ids
        )
    return result


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Prove literal MES shared-routine calls that return to their physical resume."
    )
    parser.add_argument("linear_ir", type=Path)
    parser.add_argument("library_audit", type=Path)
    parser.add_argument("output", type=Path, nargs="?")
    args = parser.parse_args()
    linear_ir = json.loads(args.linear_ir.read_text(encoding="utf-8"))
    library_audit = json.loads(args.library_audit.read_text(encoding="utf-8"))
    document = prove(linear_ir, library_audit)
    encoded = json.dumps(
        document,
        ensure_ascii=False,
        allow_nan=False,
        sort_keys=True,
        separators=(",", ":"),
    )
    if args.output is not None:
        if args.output.resolve() in {
            args.linear_ir.resolve(),
            args.library_audit.resolve(),
        }:
            raise SharedCallReturnProofError("shared-call output must not replace an input")
        args.output.write_text(encoded + "\n", encoding="utf-8")
    print(
        "MES_SHARED_CALL_RETURN_PROOF_PASS "
        f"schema={document['schema']} entry={document['source_identity'].get('entry', '')} "
        f"calls={document['coverage']['script_transfer_count']} "
        f"proved={document['coverage']['proved_call_return_count']} "
        f"unresolved={document['coverage']['unresolved_call_count']} "
        f"payload_sha256={document['payload_sha256']}"
    )


if __name__ == "__main__":
    main()
