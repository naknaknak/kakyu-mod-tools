from __future__ import annotations

import argparse
import copy
import json
from pathlib import Path
from typing import Any

import decompile_mes_handoff as decompiler
import prove_mes_control_flow as flow_proof
import prove_mes_guard_chains as guard_proof
import prove_mes_if_regions as region_proof
import prove_mes_value_dispatches as value_proof
from payload_values import canonical_payload_bytes, fingerprint


PREDICATE_DISPATCH_PROOF_SCHEMA = "kakyu_mes_predicate_dispatch_proof/v1"
MAX_ALTERNATIVES = 32
MAX_ATOMS_PER_ALTERNATIVE = 16
MAX_ATOM_OCCURRENCES = 256


class PredicateDispatchProofError(ValueError):
    pass


def prove(
    linear_ir: dict[str, Any],
    transfer_proof: dict[str, Any],
    conditional_proof: dict[str, Any],
    guard_chain_proof: dict[str, Any],
    value_dispatch_proof: dict[str, Any],
) -> dict[str, Any]:
    _validate_inputs(
        linear_ir,
        transfer_proof,
        conditional_proof,
        guard_chain_proof,
        value_dispatch_proof,
    )
    document = _build(
        linear_ir,
        transfer_proof,
        conditional_proof,
        guard_chain_proof,
        value_dispatch_proof,
    )
    document["payload_sha256"] = fingerprint(document)
    validate(
        document,
        linear_ir,
        transfer_proof,
        conditional_proof,
        guard_chain_proof,
        value_dispatch_proof,
    )
    return document


def validate(
    document: dict[str, Any],
    linear_ir: dict[str, Any],
    transfer_proof: dict[str, Any],
    conditional_proof: dict[str, Any],
    guard_chain_proof: dict[str, Any],
    value_dispatch_proof: dict[str, Any],
) -> dict[str, Any]:
    if document.get("schema") != PREDICATE_DISPATCH_PROOF_SCHEMA:
        raise PredicateDispatchProofError(
            "unsupported predicate-dispatch proof schema"
        )
    retained = document.get("payload_sha256")
    if (
        not isinstance(retained, str)
        or len(retained) != 64
        or fingerprint(document) != retained
    ):
        raise PredicateDispatchProofError(
            "predicate-dispatch proof fingerprint changed"
        )
    _validate_inputs(
        linear_ir,
        transfer_proof,
        conditional_proof,
        guard_chain_proof,
        value_dispatch_proof,
    )
    expected = _build(
        linear_ir,
        transfer_proof,
        conditional_proof,
        guard_chain_proof,
        value_dispatch_proof,
    )
    actual = dict(document)
    actual.pop("payload_sha256", None)
    if actual != expected:
        raise PredicateDispatchProofError(
            "predicate-dispatch projection changed"
        )
    return {
        "ok": True,
        "schema": PREDICATE_DISPATCH_PROOF_SCHEMA,
        "payload_sha256": retained,
    }


def _validate_inputs(
    linear_ir: dict[str, Any],
    transfer_proof: dict[str, Any],
    conditional_proof: dict[str, Any],
    guard_chain_proof: dict[str, Any],
    value_dispatch_proof: dict[str, Any],
) -> None:
    decompiler.validate(linear_ir)
    flow_proof.validate(transfer_proof)
    region_proof.validate(conditional_proof, linear_ir, transfer_proof)
    guard_proof.validate(
        guard_chain_proof, linear_ir, transfer_proof, conditional_proof
    )
    value_proof.validate(
        value_dispatch_proof,
        linear_ir,
        transfer_proof,
        conditional_proof,
        guard_chain_proof,
    )
    if value_dispatch_proof["inputs"]["guard_chain_proof_sha256"] != (
        guard_chain_proof["payload_sha256"]
    ):
        raise PredicateDispatchProofError(
            "value-dispatch proof belongs to another guard-chain proof"
        )


def _build(
    linear_ir: dict[str, Any],
    transfer_proof: dict[str, Any],
    conditional_proof: dict[str, Any],
    guard_chain_proof: dict[str, Any],
    value_dispatch_proof: dict[str, Any],
) -> dict[str, Any]:
    graphs = [
        _prove_graph(guard_graph, value_dispatch_proof["graphs"][index])
        for index, guard_graph in enumerate(guard_chain_proof["graphs"])
    ]
    return {
        "ok": True,
        "schema": PREDICATE_DISPATCH_PROOF_SCHEMA,
        "producer": {
            "implementation": "python_phase5_predicate_dispatch_prover",
            "contract": PREDICATE_DISPATCH_PROOF_SCHEMA,
        },
        "compatibility": {
            "policy": "exact_linear_transfer_region_guard_and_value_proof_match",
            "input_decompiler_schema": decompiler.DECOMPILER_IR_SCHEMA,
            "input_flow_proof_schema": flow_proof.CONTROL_FLOW_PROOF_SCHEMA,
            "input_region_proof_schema": region_proof.REDUCIBLE_REGION_PROOF_SCHEMA,
            "input_guard_chain_schema": guard_proof.GUARD_CHAIN_PROOF_SCHEMA,
            "input_value_dispatch_schema": value_proof.VALUE_DISPATCH_PROOF_SCHEMA,
            "unknown_v1_field": "ignore",
            "promotion_policy": "value_rejected_state_equality_boolean_guards_only",
            "surface_syntax_policy": "retain_ordered_guard_fallback_no_switch_guess",
        },
        "limits": {
            "max_alternatives_per_guard": MAX_ALTERNATIVES,
            "max_atoms_per_alternative": MAX_ATOMS_PER_ALTERNATIVE,
            "max_atom_occurrences_per_guard": MAX_ATOM_OCCURRENCES,
        },
        "inputs": {
            "linear_ir_sha256": linear_ir["payload_sha256"],
            "flow_proof_sha256": transfer_proof["payload_sha256"],
            "region_proof_sha256": conditional_proof["payload_sha256"],
            "guard_chain_proof_sha256": guard_chain_proof["payload_sha256"],
            "value_dispatch_proof_sha256": value_dispatch_proof[
                "payload_sha256"
            ],
        },
        "source_identity": copy.deepcopy(linear_ir.get("source_identity", {})),
        "graphs": graphs,
        "coverage": {
            "graph_count": len(graphs),
            "predicate_dispatch_count": sum(
                len(graph["predicate_dispatches"]) for graph in graphs
            ),
            "ordered_case_count": sum(
                sum(
                    len(dispatch["ordered_cases"])
                    for dispatch in graph["predicate_dispatches"]
                )
                for graph in graphs
            ),
            "alternative_count": sum(
                sum(
                    sum(
                        len(case["alternatives"])
                        for case in dispatch["ordered_cases"]
                    )
                    for dispatch in graph["predicate_dispatches"]
                )
                for graph in graphs
            ),
            "atom_occurrence_count": sum(
                sum(
                    sum(
                        sum(len(alt["atoms"]) for alt in case["alternatives"])
                        for case in dispatch["ordered_cases"]
                    )
                    for dispatch in graph["predicate_dispatches"]
                )
                for graph in graphs
            ),
            "rejected_guard_chain_count": sum(
                len(graph["rejected_guard_chains"]) for graph in graphs
            ),
        },
    }


def _prove_graph(
    guard_graph: dict[str, Any], value_graph: dict[str, Any]
) -> dict[str, Any]:
    chains = {
        str(chain["id"]): chain for chain in guard_graph["guard_chains"]
    }
    dispatches: list[dict[str, Any]] = []
    rejected: list[dict[str, Any]] = []
    for value_rejection in value_graph["rejected_guard_chains"]:
        chain_id = str(value_rejection["guard_chain_id"])
        if chain_id not in chains:
            raise PredicateDispatchProofError(
                "value rejection names a missing guard chain"
            )
        dispatch, reason = _predicate_dispatch(chains[chain_id])
        if dispatch is None:
            rejected.append(
                {
                    "guard_chain_id": chain_id,
                    "value_rejection_reason": str(value_rejection["reason"]),
                    "reason": reason,
                }
            )
        else:
            dispatch["value_rejection_reason"] = str(
                value_rejection["reason"]
            )
            dispatches.append(dispatch)
    return {
        "graph_index": int(guard_graph["graph_index"]),
        "predicate_dispatches": dispatches,
        "rejected_guard_chains": rejected,
    }


def _predicate_dispatch(
    chain: dict[str, Any],
) -> tuple[dict[str, Any] | None, str]:
    cases: list[dict[str, Any]] = []
    state_coordinates: set[tuple[str, int, int]] = set()
    for guard in chain["guards"]:
        alternatives, reason = _state_equality_dnf(
            guard["condition"].get("ast", {})
        )
        if alternatives is None:
            return None, reason
        rendered_alternatives: list[dict[str, Any]] = []
        for alternative in alternatives:
            for atom in alternative:
                state_coordinates.add(
                    (atom["storage"], atom["bank"], atom["index"])
                )
            rendered_alternatives.append({"atoms": alternative})
        cases.append(
            {
                "guard_label": str(guard["label"]),
                "source_start": int(guard["source_start"]),
                "source_region": str(guard["source_region"]),
                "predicate_ast": copy.deepcopy(guard["condition"]["ast"]),
                "alternatives": rendered_alternatives,
                "case_label": str(guard["case_label"]),
                "next_false_label": str(guard["next_false_label"]),
            }
        )
    if len(cases) < 2:
        return None, "guard_chain_has_fewer_than_two_cases"
    return {
        "id": f"predicate_dispatch_{str(chain['id'])}",
        "kind": "ordered_predicate_dispatch",
        "guard_chain_id": str(chain["id"]),
        "ordered_cases": cases,
        "default_label": str(chain["default_label"]),
        "state_coordinates": [
            {"storage": storage, "bank": bank, "index": index}
            for storage, bank, index in sorted(state_coordinates)
        ],
        "external_entry_guard_labels": copy.deepcopy(
            chain["external_entry_guard_labels"]
        ),
        "proof_status": "exact_state_equality_boolean_dnf",
        "selection_order": "first_true_guard_in_false_edge_order",
        "mutual_exclusivity": "unresolved",
        "case_body_extent": "unresolved",
        "surface_syntax": "unresolved_retain_guard_chain_fallback",
    }, ""


def _state_equality_dnf(
    ast: dict[str, Any],
) -> tuple[list[list[dict[str, Any]]] | None, str]:
    if not isinstance(ast, dict):
        return None, "guard_contains_non_state_equality_boolean_term"
    atom = _state_equality_atom(ast)
    if atom is not None:
        return [[atom]], ""
    if ast.get("type") != "binary" or ast.get("op") not in {
        "logical_and",
        "logical_or",
    }:
        return None, "guard_contains_non_state_equality_boolean_term"
    left, reason = _state_equality_dnf(ast.get("lhs", {}))
    if left is None:
        return None, reason
    right, reason = _state_equality_dnf(ast.get("rhs", {}))
    if right is None:
        return None, reason
    if ast["op"] == "logical_or":
        if len(left) + len(right) > MAX_ALTERNATIVES:
            return None, "guard_dnf_alternative_limit_exceeded"
        alternatives = left + right
    else:
        if len(left) * len(right) > MAX_ALTERNATIVES:
            return None, "guard_dnf_alternative_limit_exceeded"
        alternatives = [
            left_atoms + right_atoms
            for left_atoms in left
            for right_atoms in right
        ]
    if len(alternatives) > MAX_ALTERNATIVES:
        return None, "guard_dnf_alternative_limit_exceeded"
    if any(
        len(alternative) > MAX_ATOMS_PER_ALTERNATIVE
        for alternative in alternatives
    ):
        return None, "guard_dnf_atom_limit_exceeded"
    if sum(len(alternative) for alternative in alternatives) > MAX_ATOM_OCCURRENCES:
        return None, "guard_dnf_occurrence_limit_exceeded"
    return alternatives, ""


def _state_equality_atom(ast: dict[str, Any]) -> dict[str, Any] | None:
    if not isinstance(ast, dict):
        return None
    if ast.get("type") != "binary" or ast.get("op") != "equal":
        return None
    lhs = ast.get("lhs", {})
    rhs = ast.get("rhs", {})
    if _is_state_ref(lhs) and _is_literal(rhs):
        state, literal = lhs, rhs
    elif _is_literal(lhs) and _is_state_ref(rhs):
        state, literal = rhs, lhs
    else:
        return None
    index = state.get("index", {})
    if not _is_literal(index):
        return None
    return {
        "storage": str(state["storage"]),
        "bank": int(state["bank"]),
        "index": int(index["value"]),
        "literal": int(literal["value"]),
    }


def _is_state_ref(node: Any) -> bool:
    return (
        isinstance(node, dict)
        and node.get("type") == "state_ref"
        and isinstance(node.get("storage"), str)
        and bool(node.get("storage"))
        and isinstance(node.get("bank"), int)
        and not isinstance(node.get("bank"), bool)
        and isinstance(node.get("index"), dict)
    )


def _is_literal(node: Any) -> bool:
    return (
        isinstance(node, dict)
        and node.get("type") == "literal"
        and isinstance(node.get("value"), int)
        and not isinstance(node.get("value"), bool)
    )


def main() -> None:
    parser = argparse.ArgumentParser(
        description=(
            "Prove ordered Boolean predicate dispatches rejected by the simple "
            "MES value-dispatch layer."
        )
    )
    parser.add_argument("linear_ir", type=Path)
    parser.add_argument("flow_proof", type=Path)
    parser.add_argument("if_regions", type=Path)
    parser.add_argument("guard_chains", type=Path)
    parser.add_argument("value_dispatches", type=Path)
    parser.add_argument("output", type=Path, nargs="?")
    args = parser.parse_args()
    inputs = [
        json.loads(path.read_text(encoding="utf-8"))
        for path in (
            args.linear_ir,
            args.flow_proof,
            args.if_regions,
            args.guard_chains,
            args.value_dispatches,
        )
    ]
    document = prove(*inputs)
    encoded = json.dumps(
        document,
        ensure_ascii=False,
        allow_nan=False,
        sort_keys=True,
        separators=(",", ":"),
    )
    if args.output is not None:
        source_paths = {
            args.linear_ir.resolve(),
            args.flow_proof.resolve(),
            args.if_regions.resolve(),
            args.guard_chains.resolve(),
            args.value_dispatches.resolve(),
        }
        if args.output.resolve() in source_paths:
            raise PredicateDispatchProofError(
                "predicate-dispatch output must not replace an input"
            )
        args.output.write_text(encoded + "\n", encoding="utf-8")
    print(
        "MES_PREDICATE_DISPATCH_PROOF_PASS "
        f"schema={document['schema']} entry={document['source_identity'].get('entry', '')} "
        f"dispatches={document['coverage']['predicate_dispatch_count']} "
        f"cases={document['coverage']['ordered_case_count']} "
        f"rejected={document['coverage']['rejected_guard_chain_count']} "
        f"payload_sha256={document['payload_sha256']}"
    )


if __name__ == "__main__":
    main()
