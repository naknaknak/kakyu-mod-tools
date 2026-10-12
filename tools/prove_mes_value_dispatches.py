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
from payload_values import canonical_payload_bytes, fingerprint


VALUE_DISPATCH_PROOF_SCHEMA = "kakyu_mes_value_dispatch_proof/v1"


class ValueDispatchProofError(ValueError):
    pass


def prove(
    linear_ir: dict[str, Any],
    transfer_proof: dict[str, Any],
    conditional_proof: dict[str, Any],
    guard_chain_proof: dict[str, Any],
) -> dict[str, Any]:
    decompiler.validate(linear_ir)
    flow_proof.validate(transfer_proof)
    region_proof.validate(conditional_proof, linear_ir, transfer_proof)
    guard_proof.validate(
        guard_chain_proof, linear_ir, transfer_proof, conditional_proof
    )
    document = _build(
        linear_ir, transfer_proof, conditional_proof, guard_chain_proof
    )
    document["payload_sha256"] = fingerprint(document)
    validate(
        document,
        linear_ir,
        transfer_proof,
        conditional_proof,
        guard_chain_proof,
    )
    return document


def validate(
    document: dict[str, Any],
    linear_ir: dict[str, Any],
    transfer_proof: dict[str, Any],
    conditional_proof: dict[str, Any],
    guard_chain_proof: dict[str, Any],
) -> dict[str, Any]:
    if document.get("schema") != VALUE_DISPATCH_PROOF_SCHEMA:
        raise ValueDispatchProofError("unsupported value-dispatch proof schema")
    retained = document.get("payload_sha256")
    if not isinstance(retained, str) or len(retained) != 64 or fingerprint(document) != retained:
        raise ValueDispatchProofError("value-dispatch proof fingerprint changed")
    decompiler.validate(linear_ir)
    flow_proof.validate(transfer_proof)
    region_proof.validate(conditional_proof, linear_ir, transfer_proof)
    guard_proof.validate(
        guard_chain_proof, linear_ir, transfer_proof, conditional_proof
    )
    expected = _build(
        linear_ir, transfer_proof, conditional_proof, guard_chain_proof
    )
    actual = dict(document)
    actual.pop("payload_sha256", None)
    if actual != expected:
        raise ValueDispatchProofError("value-dispatch projection changed")
    return {
        "ok": True,
        "schema": VALUE_DISPATCH_PROOF_SCHEMA,
        "payload_sha256": retained,
    }


def _build(
    linear_ir: dict[str, Any],
    transfer_proof: dict[str, Any],
    conditional_proof: dict[str, Any],
    guard_chain_proof: dict[str, Any],
) -> dict[str, Any]:
    graph_results = [
        _prove_graph(graph)
        for graph in guard_chain_proof["graphs"]
    ]
    return {
        "ok": True,
        "schema": VALUE_DISPATCH_PROOF_SCHEMA,
        "producer": {
            "implementation": "python_phase5_value_dispatch_prover",
            "contract": VALUE_DISPATCH_PROOF_SCHEMA,
        },
        "compatibility": {
            "policy": "exact_linear_transfer_region_and_guard_proof_match",
            "input_decompiler_schema": decompiler.DECOMPILER_IR_SCHEMA,
            "input_flow_proof_schema": flow_proof.CONTROL_FLOW_PROOF_SCHEMA,
            "input_region_proof_schema": region_proof.REDUCIBLE_REGION_PROOF_SCHEMA,
            "input_guard_chain_schema": guard_proof.GUARD_CHAIN_PROOF_SCHEMA,
            "unknown_v1_field": "ignore",
            "promotion_policy": "same_numeric_state_equality_unique_literals",
        },
        "inputs": {
            "linear_ir_sha256": linear_ir["payload_sha256"],
            "flow_proof_sha256": transfer_proof["payload_sha256"],
            "region_proof_sha256": conditional_proof["payload_sha256"],
            "guard_chain_proof_sha256": guard_chain_proof["payload_sha256"],
        },
        "source_identity": copy.deepcopy(linear_ir.get("source_identity", {})),
        "graphs": graph_results,
        "coverage": {
            "graph_count": len(graph_results),
            "value_dispatch_count": sum(
                len(row["value_dispatches"]) for row in graph_results
            ),
            "case_count": sum(
                sum(len(dispatch["cases"]) for dispatch in row["value_dispatches"])
                for row in graph_results
            ),
            "rejected_guard_chain_count": sum(
                len(row["rejected_guard_chains"]) for row in graph_results
            ),
        },
    }


def _prove_graph(guard_graph: dict[str, Any]) -> dict[str, Any]:
    dispatches: list[dict[str, Any]] = []
    rejected: list[dict[str, Any]] = []
    for chain in guard_graph["guard_chains"]:
        dispatch, reason = _value_dispatch(chain)
        if dispatch is None:
            rejected.append({
                "guard_chain_id": str(chain["id"]),
                "reason": reason,
            })
        else:
            dispatches.append(dispatch)
    return {
        "graph_index": int(guard_graph["graph_index"]),
        "value_dispatches": dispatches,
        "rejected_guard_chains": rejected,
    }


def _value_dispatch(
    chain: dict[str, Any],
) -> tuple[dict[str, Any] | None, str]:
    cases: list[dict[str, Any]] = []
    discriminator: dict[str, Any] | None = None
    retained_values: set[int] = set()
    for guard in chain["guards"]:
        normalized = _state_equality(guard["condition"].get("ast", {}))
        if normalized is None:
            return None, "guard_condition_is_not_simple_state_equality"
        state, value = normalized
        if discriminator is None:
            discriminator = state
        elif state != discriminator:
            return None, "guard_discriminator_changed"
        if value in retained_values:
            return None, "guard_case_literal_repeated"
        retained_values.add(value)
        cases.append({
            "literal": value,
            "guard_label": str(guard["label"]),
            "source_start": int(guard["source_start"]),
            "source_region": str(guard["source_region"]),
            "case_label": str(guard["case_label"]),
        })
    if discriminator is None or len(cases) < 2:
        return None, "guard_chain_has_fewer_than_two_cases"
    return {
        "id": f"value_dispatch_{str(chain['id'])}",
        "kind": "value_dispatch",
        "guard_chain_id": str(chain["id"]),
        "discriminator": discriminator,
        "cases": cases,
        "default_label": str(chain["default_label"]),
        "external_entry_guard_labels": copy.deepcopy(
            chain["external_entry_guard_labels"]
        ),
        "proof_status": "same_numeric_state_equality_unique_literals",
        "labels_retained": True,
        "reducible_region": False,
        "case_body_extent": "unresolved",
    }, ""


def _state_equality(ast: dict[str, Any]) -> tuple[dict[str, Any], int] | None:
    if ast.get("type") != "binary" or ast.get("op") != "equal":
        return None
    lhs = ast.get("lhs", {})
    rhs = ast.get("rhs", {})
    if _is_state_ref(lhs) and _is_literal(rhs):
        state_node, literal_node = lhs, rhs
    elif _is_literal(lhs) and _is_state_ref(rhs):
        state_node, literal_node = rhs, lhs
    else:
        return None
    index = state_node.get("index", {})
    if not _is_literal(index):
        return None
    return {
        "storage": str(state_node.get("storage", "")),
        "bank": int(state_node.get("bank", 0)),
        "index": int(index["value"]),
    }, int(literal_node["value"])


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
        description="Prove numeric state equality dispatches from MES guard chains."
    )
    parser.add_argument("linear_ir", type=Path)
    parser.add_argument("flow_proof", type=Path)
    parser.add_argument("region_proof", type=Path)
    parser.add_argument("guard_chain_proof", type=Path)
    parser.add_argument("output", type=Path, nargs="?")
    args = parser.parse_args()
    linear_ir = json.loads(args.linear_ir.read_text(encoding="utf-8"))
    transfer = json.loads(args.flow_proof.read_text(encoding="utf-8"))
    conditional = json.loads(args.region_proof.read_text(encoding="utf-8"))
    guards = json.loads(args.guard_chain_proof.read_text(encoding="utf-8"))
    document = prove(linear_ir, transfer, conditional, guards)
    encoded = json.dumps(
        document,
        ensure_ascii=False,
        allow_nan=False,
        sort_keys=True,
        separators=(",", ":"),
    )
    if args.output is not None:
        inputs = {
            args.linear_ir.resolve(),
            args.flow_proof.resolve(),
            args.region_proof.resolve(),
            args.guard_chain_proof.resolve(),
        }
        if args.output.resolve() in inputs:
            raise ValueDispatchProofError("value-dispatch output must not replace an input")
        args.output.write_text(encoded + "\n", encoding="utf-8")
    print(
        "MES_VALUE_DISPATCH_PROOF_PASS "
        f"schema={document['schema']} entry={document['source_identity'].get('entry', '')} "
        f"dispatches={document['coverage']['value_dispatch_count']} "
        f"cases={document['coverage']['case_count']} "
        f"rejected={document['coverage']['rejected_guard_chain_count']} "
        f"payload_sha256={document['payload_sha256']}"
    )


if __name__ == "__main__":
    main()
