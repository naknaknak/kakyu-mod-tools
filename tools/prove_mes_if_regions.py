from __future__ import annotations

import argparse
import copy
import json
from pathlib import Path
from typing import Any

import decompile_mes_handoff as decompiler
import emit_mes_low_level_control as low_control
import prove_mes_control_flow as flow_proof
from payload_values import canonical_payload_bytes, fingerprint


REDUCIBLE_REGION_PROOF_SCHEMA = "kakyu_mes_reducible_region_proof/v2"
BLOCKING_OPS = {"command_00", "continuation_transfer"}
TRANSFER_OPS = {"branch_if_not_true", "continuation_transfer"}
CONFIRMED_REFERENCE_KINDS = {
    "condition_true_fallthrough",
    "condition_false_target",
    "continuation_target",
}


class ReducibleRegionProofError(ValueError):
    pass


def prove(linear_ir: dict[str, Any], proof: dict[str, Any]) -> dict[str, Any]:
    decompiler.validate(linear_ir)
    flow_proof.validate(proof)
    if proof["input_decompiler"]["payload_sha256"] != linear_ir["payload_sha256"]:
        raise ReducibleRegionProofError("flow proof belongs to another linear IR")
    document = _build(linear_ir, proof)
    document["payload_sha256"] = fingerprint(document)
    validate(document, linear_ir, proof)
    return document


def validate(document: dict[str, Any], linear_ir: dict[str, Any], proof: dict[str, Any]) -> dict[str, Any]:
    if document.get("schema") != REDUCIBLE_REGION_PROOF_SCHEMA:
        raise ReducibleRegionProofError("unsupported reducible-region proof schema")
    retained = document.get("payload_sha256")
    if not isinstance(retained, str) or len(retained) != 64 or fingerprint(document) != retained:
        raise ReducibleRegionProofError("reducible-region proof fingerprint changed")
    decompiler.validate(linear_ir)
    flow_proof.validate(proof)
    expected = _build(linear_ir, proof)
    actual = dict(document)
    actual.pop("payload_sha256", None)
    if actual != expected:
        raise ReducibleRegionProofError("reducible-region projection changed")
    return {"ok": True, "schema": REDUCIBLE_REGION_PROOF_SCHEMA, "payload_sha256": retained}


def _build(linear_ir: dict[str, Any], proof: dict[str, Any]) -> dict[str, Any]:
    control = low_control.emit(proof)
    graph_results = [
        _prove_graph(index, linear_ir, proof["graphs"][index], graph)
        for index, graph in enumerate(control["graphs"])
    ]
    return {
        "ok": True,
        "schema": REDUCIBLE_REGION_PROOF_SCHEMA,
        "producer": {"implementation": "python_phase5_reducible_if_prover", "contract": REDUCIBLE_REGION_PROOF_SCHEMA},
        "compatibility": {
            "policy": "exact_linear_and_flow_proof_match",
            "input_decompiler_schema": decompiler.DECOMPILER_IR_SCHEMA,
            "input_flow_proof_schema": flow_proof.CONTROL_FLOW_PROOF_SCHEMA,
            "fallback_schema": low_control.LOW_LEVEL_CONTROL_IR_SCHEMA,
            "unknown_v2_field": "ignore",
            "unproved_region_policy": "retain_low_level_labels_and_gotos",
        },
        "inputs": {
            "linear_ir_sha256": linear_ir["payload_sha256"],
            "flow_proof_sha256": proof["payload_sha256"],
            "fallback_control_sha256": control["payload_sha256"],
        },
        "source_identity": copy.deepcopy(linear_ir.get("source_identity", {})),
        "fallback_control": control,
        "graphs": graph_results,
        "coverage": {
            "graph_count": len(graph_results),
            "proved_fallthrough_count": sum(len(row["proved_fallthroughs"]) for row in graph_results),
            "if_then_region_count": sum(len(row["if_then_regions"]) for row in graph_results),
            "if_else_region_count": sum(len(row["if_else_regions"]) for row in graph_results),
            "rejected_conditional_count": sum(len(row["rejected_conditionals"]) for row in graph_results),
        },
    }


def _prove_graph(graph_index: int, linear_ir: dict[str, Any], proof_graph: dict[str, Any], control_graph: dict[str, Any]) -> dict[str, Any]:
    labels = control_graph["labels"]
    statements = control_graph["statements"]
    label_by_id = {row["id"]: row for row in labels}
    statement_by_label = {row["label"]: row for row in statements}
    region_labels: dict[str, list[dict[str, Any]]] = {}
    for label in labels:
        region_labels.setdefault(str(label["region"]), []).append(label)
    for rows in region_labels.values():
        rows.sort(key=lambda row: (int(row["offset"]), str(row["id"])))

    outgoing: dict[str, list[str]] = {}
    proved_fallthroughs: list[dict[str, Any]] = []
    for statement in statements:
        label = str(statement["label"])
        kind = str(statement["kind"])
        if kind == "conditional_goto":
            outgoing[label] = [str(statement["true_label"]), str(statement["false_label"])]
        elif kind == "goto":
            outgoing[label] = [str(statement["target_label"])]
        elif kind == "anchor":
            target = _next_same_region_label(label_by_id[label], region_labels)
            if target is not None and _plain_linear_span(
                linear_ir, graph_index, label_by_id[label], target
            ):
                outgoing[label] = [str(target["id"])]
                proved_fallthroughs.append({
                    "source_label": label,
                    "target_label": str(target["id"]),
                    "source_end": int(statement["source_node"]["source"]["end"]),
                    "target_start": int(target["offset"]),
                    "proof_status": "exact_linear_fallthrough",
                })
            else:
                outgoing[label] = []
        else:
            outgoing[label] = []

    if_then_candidates: list[dict[str, Any]] = []
    if_else_candidates: list[dict[str, Any]] = []
    rejected: list[dict[str, Any]] = []
    for statement in statements:
        if statement["kind"] != "conditional_goto":
            continue
        if_else, if_else_reason = _if_else_candidate(
            linear_ir, statement, label_by_id, statement_by_label, outgoing
        )
        if if_else is not None:
            if_else["id"] = f"if_else_{int(statement['source_node']['source']['start']):08x}"
            if_else_candidates.append(if_else)
            continue
        if_then, if_then_reason = _if_candidate(
            linear_ir, statement, label_by_id, statement_by_label, outgoing
        )
        if if_then is None:
            rejected.append({
                "source_label": statement["label"],
                "reason": if_then_reason,
                "if_else_reason": if_else_reason,
            })
        else:
            if_then["id"] = f"if_then_{int(statement['source_node']['source']['start']):08x}"
            if_then_candidates.append(if_then)
    candidates = if_then_candidates + if_else_candidates
    for candidate in candidates:
        candidate_body_start = int(candidate.get("body_start", candidate.get("then_start", -1)))
        children = [
            row["id"] for row in candidates
            if row is not candidate
            and candidate_body_start <= int(row["source_start"])
            and int(row["join_offset"]) <= int(candidate["join_offset"])
        ]
        candidate["nested_region_ids"] = sorted(children)
    return {
        "graph_index": graph_index,
        "bounded_complete": bool(proof_graph.get("bounded_complete", False)),
        "proved_fallthroughs": proved_fallthroughs,
        "if_then_regions": if_then_candidates,
        "if_else_regions": if_else_candidates,
        "rejected_conditionals": rejected,
    }


def _next_same_region_label(source: dict[str, Any], region_labels: dict[str, list[dict[str, Any]]]) -> dict[str, Any] | None:
    for label in region_labels.get(str(source["region"]), []):
        if int(label["offset"]) > int(source["offset"]):
            return label
    return None


def _plain_linear_span(
    linear_ir: dict[str, Any],
    graph_index: int,
    source: dict[str, Any],
    target: dict[str, Any],
) -> bool:
    source_node = next(
        (
            node
            for node in linear_ir["nodes"]
            if any(
                int(link["graph_index"]) == graph_index
                and link["node_id"] == source["graph_node_id"]
                for link in node["cfg_nodes"]
            )
        ),
        None,
    )
    if source_node is None or source_node["kind"] != "statement":
        return False
    start = int(source_node["source"]["end"])
    end = int(target["offset"])
    if end < start:
        return False
    span_nodes = sorted(
        (
            node for node in linear_ir["nodes"]
            if node["source"]["region"] == source["region"]
            and start <= int(node["source"]["start"]) < end
        ),
        key=lambda node: (int(node["source"]["start"]), int(node["source"]["end"]), str(node["id"])),
    )
    cursor = start
    for node in span_nodes:
        node_start = int(node["source"]["start"])
        node_end = int(node["source"]["end"])
        if node_start != cursor or node_end <= node_start or node_end > end:
            return False
        if node["kind"] == "opaque":
            return False
        if node["statement"].get("op") in BLOCKING_OPS | {"branch_if_not_true"}:
            return False
        cursor = node_end
    if cursor != end:
        return False
    return True


def _if_candidate(
    linear_ir: dict[str, Any],
    source: dict[str, Any],
    label_by_id: dict[str, dict[str, Any]],
    statement_by_label: dict[str, dict[str, Any]],
    outgoing: dict[str, list[str]],
) -> tuple[dict[str, Any] | None, str]:
    true_label = str(source["true_label"])
    join_label = str(source["false_label"])
    source_label = str(source["label"])
    source_info = label_by_id[source_label]
    true_info = label_by_id[true_label]
    join_info = label_by_id[join_label]
    region = str(source_info["region"])
    if str(true_info["region"]) != region or str(join_info["region"]) != region:
        return None, "targets_cross_source_region"
    body_start = int(true_info["offset"])
    join_offset = int(join_info["offset"])
    if join_offset <= body_start:
        return None, "non_forward_or_empty_body"
    body_labels = [
        label for label, info in label_by_id.items()
        if str(info["region"]) == region and body_start <= int(info["offset"]) < join_offset
    ]
    body_labels.sort(key=lambda label: int(label_by_id[label]["offset"]))
    source_offset = int(source["source_node"]["source"]["start"])
    arm, reason = _prove_arm(
        linear_ir,
        region,
        true_label,
        join_label,
        body_start,
        join_offset,
        body_labels,
        label_by_id,
        statement_by_label,
        outgoing,
        {(source_offset, body_start)},
    )
    if arm is None:
        return None, reason.replace("arm", "body")
    return {
        "kind": "if_then",
        "source_label": source_label,
        "source_start": source_offset,
        "condition": copy.deepcopy(source["condition"]),
        "body_entry_label": true_label,
        "body_start": body_start,
        "body_label_ids": arm["label_ids"],
        "body_linear_node_ids": arm["linear_node_ids"],
        "join_label": join_label,
        "join_offset": join_offset,
        "fallback_statement_ids": arm["fallback_statement_ids"],
        "proof_status": "single_entry_acyclic_single_join",
    }, ""


def _if_else_candidate(
    linear_ir: dict[str, Any],
    source: dict[str, Any],
    label_by_id: dict[str, dict[str, Any]],
    statement_by_label: dict[str, dict[str, Any]],
    outgoing: dict[str, list[str]],
) -> tuple[dict[str, Any] | None, str]:
    source_label = str(source["label"])
    then_label = str(source["true_label"])
    else_label = str(source["false_label"])
    source_info = label_by_id[source_label]
    then_info = label_by_id[then_label]
    else_info = label_by_id[else_label]
    region = str(source_info["region"])
    if str(then_info["region"]) != region or str(else_info["region"]) != region:
        return None, "targets_cross_source_region"
    then_start = int(then_info["offset"])
    else_start = int(else_info["offset"])
    if else_start <= then_start:
        return None, "non_forward_or_empty_then_arm"
    then_labels = sorted(
        (
            label for label, info in label_by_id.items()
            if str(info["region"]) == region and then_start <= int(info["offset"]) < else_start
        ),
        key=lambda label: int(label_by_id[label]["offset"]),
    )
    then_label_set = set(then_labels)
    then_exits = sorted({
        target
        for label in then_labels
        for target in outgoing.get(label, [])
        if target not in then_label_set and target != else_label
    })
    if len(then_exits) != 1:
        return None, "then_arm_has_no_unique_forward_join"
    join_label = then_exits[0]
    if join_label not in label_by_id:
        return None, "then_join_is_unresolved"
    join_info = label_by_id[join_label]
    join_offset = int(join_info["offset"])
    if str(join_info["region"]) != region or join_offset <= else_start:
        return None, "join_crosses_source_region_or_is_not_forward"
    else_labels = sorted(
        (
            label for label, info in label_by_id.items()
            if str(info["region"]) == region and else_start <= int(info["offset"]) < join_offset
        ),
        key=lambda label: int(label_by_id[label]["offset"]),
    )
    source_offset = int(source["source_node"]["source"]["start"])
    then_arm, reason = _prove_arm(
        linear_ir,
        region,
        then_label,
        join_label,
        then_start,
        else_start,
        then_labels,
        label_by_id,
        statement_by_label,
        outgoing,
        {(source_offset, then_start)},
    )
    if then_arm is None:
        return None, f"then_{reason}"
    else_arm, reason = _prove_arm(
        linear_ir,
        region,
        else_label,
        join_label,
        else_start,
        join_offset,
        else_labels,
        label_by_id,
        statement_by_label,
        outgoing,
        {(source_offset, else_start)},
    )
    if else_arm is None:
        return None, f"else_{reason}"
    return {
        "kind": "if_else",
        "source_label": source_label,
        "source_start": source_offset,
        "condition": copy.deepcopy(source["condition"]),
        "then_entry_label": then_label,
        "then_start": then_start,
        "then_label_ids": then_arm["label_ids"],
        "then_linear_node_ids": then_arm["linear_node_ids"],
        "then_exit_label_ids": then_arm["exit_label_ids"],
        "else_entry_label": else_label,
        "else_start": else_start,
        "else_label_ids": else_arm["label_ids"],
        "else_linear_node_ids": else_arm["linear_node_ids"],
        "else_exit_label_ids": else_arm["exit_label_ids"],
        "join_label": join_label,
        "join_offset": join_offset,
        "fallback_statement_ids": then_arm["fallback_statement_ids"] + else_arm["fallback_statement_ids"],
        "proof_status": "two_single_entry_acyclic_arms_single_join",
    }, ""


def _prove_arm(
    linear_ir: dict[str, Any],
    region: str,
    entry_label: str,
    join_label: str,
    span_start: int,
    span_end: int,
    labels: list[str],
    label_by_id: dict[str, dict[str, Any]],
    statement_by_label: dict[str, dict[str, Any]],
    outgoing: dict[str, list[str]],
    allowed_external_entries: set[tuple[int, int]],
) -> tuple[dict[str, Any] | None, str]:
    if entry_label not in labels:
        return None, "entry_not_in_arm"
    label_set = set(labels)
    exit_labels: list[str] = []
    for label in labels:
        statement = statement_by_label[label]
        if statement["kind"] in {"boundary", "unresolved_transfer", "unexpanded_transfer"}:
            return None, "arm_contains_unproved_or_terminal_anchor"
        targets = outgoing.get(label, [])
        if not targets or any(target not in label_set and target != join_label for target in targets):
            return None, "arm_does_not_have_single_join"
        if join_label in targets:
            exit_labels.append(label)
    reachable = _reachable(entry_label, outgoing, label_set | {join_label})
    if not label_set.issubset(reachable) or join_label not in reachable:
        return None, "arm_or_join_not_reachable"
    if _has_cycle(entry_label, outgoing, label_set):
        return None, "arm_contains_cycle"
    reverse_reachable = _reverse_reachable(join_label, outgoing, label_set | {join_label})
    if not label_set.issubset(reverse_reachable):
        return None, "not_all_arm_paths_reach_join"
    linear_nodes = sorted(
        (
            node for node in linear_ir["nodes"]
            if node["source"]["region"] == region
            and span_start <= int(node["source"]["start"]) < span_end
        ),
        key=lambda node: (int(node["source"]["start"]), int(node["source"]["end"]), str(node["id"])),
    )
    cursor = span_start
    for node in linear_nodes:
        node_start = int(node["source"]["start"])
        node_end = int(node["source"]["end"])
        if node_start != cursor or node_end <= node_start or node_end > span_end:
            return None, "linear_arm_span_is_incomplete"
        cursor = node_end
    if not linear_nodes or cursor != span_end:
        return None, "linear_arm_span_is_incomplete"
    for node in linear_nodes:
        if node["kind"] == "opaque" or node["statement"].get("op") in BLOCKING_OPS - {"continuation_transfer"}:
            return None, "linear_arm_contains_boundary"
        if node["statement"].get("op") in TRANSFER_OPS:
            matching_labels = [
                label for label in labels
                if int(label_by_id[label]["offset"]) == int(node["source"]["start"])
            ]
            if not any(
                statement_by_label[label]["kind"] in {"conditional_goto", "goto"}
                for label in matching_labels
            ):
                return None, "linear_arm_contains_unproved_transfer"
    for reference in linear_ir["references"]:
        value = reference.get("value", {})
        if reference.get("kind") != "code" or value.get("kind") not in CONFIRMED_REFERENCE_KINDS:
            continue
        target = int(value.get("target_offset", -1))
        owner = int(value.get("source_offset", -1))
        target_in_arm = span_start <= target < span_end
        owner_in_arm = span_start <= owner < span_end
        if target_in_arm and not owner_in_arm and (owner, target) not in allowed_external_entries:
            return None, "arm_has_external_confirmed_entry"
    return {
        "label_ids": labels,
        "linear_node_ids": [node["id"] for node in linear_nodes],
        "exit_label_ids": sorted(exit_labels),
        "fallback_statement_ids": [statement_by_label[label]["id"] for label in labels],
    }, ""


def _reachable(start: str, outgoing: dict[str, list[str]], allowed: set[str]) -> set[str]:
    seen: set[str] = set()
    pending = [start]
    while pending:
        node = pending.pop()
        if node in seen or node not in allowed:
            continue
        seen.add(node)
        pending.extend(outgoing.get(node, []))
    return seen


def _reverse_reachable(target: str, outgoing: dict[str, list[str]], allowed: set[str]) -> set[str]:
    reverse: dict[str, list[str]] = {}
    for source, targets in outgoing.items():
        for destination in targets:
            if source in allowed and destination in allowed:
                reverse.setdefault(destination, []).append(source)
    return _reachable(target, reverse, allowed)


def _has_cycle(start: str, outgoing: dict[str, list[str]], body: set[str]) -> bool:
    visiting: set[str] = set()
    visited: set[str] = set()
    def visit(node: str) -> bool:
        if node in visiting:
            return True
        if node in visited or node not in body:
            return False
        visiting.add(node)
        if any(visit(target) for target in outgoing.get(node, []) if target in body):
            return True
        visiting.remove(node)
        visited.add(node)
        return False
    return visit(start)


def main() -> None:
    parser = argparse.ArgumentParser(description="Prove same-region reducible MES if and if/else regions.")
    parser.add_argument("linear_ir", type=Path)
    parser.add_argument("flow_proof", type=Path)
    parser.add_argument("output", type=Path, nargs="?")
    args = parser.parse_args()
    linear_ir = json.loads(args.linear_ir.read_text(encoding="utf-8"))
    proof = json.loads(args.flow_proof.read_text(encoding="utf-8"))
    document = prove(linear_ir, proof)
    encoded = json.dumps(document, ensure_ascii=False, allow_nan=False, sort_keys=True, separators=(",", ":"))
    if args.output is not None:
        if args.output.resolve() in {args.linear_ir.resolve(), args.flow_proof.resolve()}:
            raise ReducibleRegionProofError("region proof output must not replace an input")
        args.output.write_text(encoded + "\n", encoding="utf-8")
    print(
        "MES_REDUCIBLE_IF_PROOF_PASS "
        f"schema={document['schema']} entry={document['source_identity'].get('entry', '')} "
        f"if_then={document['coverage']['if_then_region_count']} "
        f"if_else={document['coverage']['if_else_region_count']} "
        f"rejected={document['coverage']['rejected_conditional_count']} "
        f"payload_sha256={document['payload_sha256']}"
    )


if __name__ == "__main__":
    main()
