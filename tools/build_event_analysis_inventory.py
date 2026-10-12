"""Inventory the original event-analysis frontier from current Python handoffs.

This is a structural work inventory, not a playable-route certificate. Conditions
whose source interval encloses a call are explicitly candidates, not proven guards.
Reports contain coordinates/counts/hashes, never message text or instruction bytes.
"""
from __future__ import annotations

import argparse
from collections import Counter, defaultdict
from concurrent.futures import ProcessPoolExecutor
import hashlib
import json
from pathlib import Path
import sys

from classify_event_routes import canonical
from extract_kakyu_arc import read_entries
from mes_analyzer_handoff import build_handoff
from mes_instruction_ir import INSTRUCTION_SCHEMA

SCHEMA = "kakyu_event_analysis_inventory/v1"
INDEX_SCHEMA = "kakyu_event_route_classification/v1"
# Every scope the classification uses for an EVENT-named archive entry. A tail-
# named target is an EVENT entry too; it is only its intro that the strict
# decoder and the Python handoff both decline to frame in sequence.
EVENT_SCOPES = ("event_named_target", "event_named_tail_target", "event_named_undispatched")


def fingerprint(value: dict) -> str:
    return hashlib.sha256(canonical({k: v for k, v in value.items() if k != "payload_sha256"})).hexdigest()


def _nodes(value):
    pending = [value]
    while pending:
        node = pending.pop()
        if isinstance(node, dict):
            yield node
            pending.extend(reversed(list(node.values())))
        elif isinstance(node, list):
            pending.extend(reversed(node))


def _selector(instruction):
    for operand in instruction.get("operands", []):
        if operand.get("type") == "record_list":
            records = operand.get("records", [])
            if records and records[0].get("type") == "expression_record":
                ast = records[0].get("value", {}).get("ast", {})
                if ast.get("type") == "literal" and type(ast.get("value")) is int:
                    return ast["value"]
    return None


def summarize_entry(job: tuple[str, bytes, str]) -> dict:
    name, payload, archive_sha = job
    handoff = build_handoff(payload, {"archive": "mes.arc", "entry": name,
        "source_kind": "original_arc", "archive_sha256": archive_sha})
    instructions = handoff["typed_ir"]["instructions"]
    starts = {row["source_offset"] for row in instructions}
    edges = defaultdict(list)
    for row in handoff["references"]["code"]:
        edges[row["source_offset"]].append({key: row[key] for key in
            ("kind", "target_offset", "aligned", "in_code")})
    state = defaultdict(list)
    for row in handoff["references"]["state"]:
        state[row["source_offset"]].append({key: row[key] for key in
            ("access", "storage", "bank", "index", "count")})
    branches, calls, terminals, writes = [], [], [], []
    for row in instructions:
        coordinate = {"offset": row["source_offset"], "end": row["end_offset"]}
        if row["op"] == "branch_if_not_true":
            condition = next(item["value"] for item in row["operands"] if item["type"] == "condition")
            literals = sorted({node["value"] for node in _nodes(condition.get("ast", {}))
                               if node.get("type") == "literal" and type(node.get("value")) is int})
            branches.append({**coordinate, "condition_sha256": hashlib.sha256(canonical(condition["ast"])).hexdigest(),
                "state_references": state[row["source_offset"]], "literal_values": literals,
                "edges": edges[row["source_offset"]], "execution_coverage": "not_measured"})
        if row.get("script_target"):
            calls.append({**coordinate, "command": row["command_id"], "target": row["script_target"].upper(),
                          "kind": "root_handoff" if row["command_id"] == 14 else "nested_call"})
        elif row["command_id"] in (0x11, 0x1D):
            calls.append({**coordinate, "command": row["command_id"], "selector": _selector(row),
                          "kind": "shared_routine" if row["command_id"] == 0x1D else "registered_definition"})
        if row["command_id"] == 0x00 or row["op"] == "script_handoff_marker":
            terminals.append({**coordinate, "kind": "return" if row["command_id"] == 0x00 else "root_handoff",
                              "target": row.get("script_target", ""), "execution_coverage": "not_measured"})
        if row["op"].endswith("_write_run"):
            writes.append({**coordinate, "op": row["op"], "state_references": state[row["source_offset"]]})
    opaque = [{"offset": row["source_offset"], "end": row["end_offset"]}
              for row in handoff["typed_ir"]["opaque_boundaries"]]
    alignment = handoff["record_alignment"]
    return {"entry": name, "entry_sha256": hashlib.sha256(payload).hexdigest(),
        "handoff_sha256": handoff["payload_sha256"], "producer": handoff["producer"]["implementation"],
        "instruction_schema": INSTRUCTION_SCHEMA, "code_size": handoff["container"]["header"]["code_size"],
        "address_entries": handoff["container"]["header"]["entry_offsets"],
        "instruction_count": len(instructions), "message_record_count": len(handoff["references"]["messages"]),
        "op_counts": dict(sorted(Counter(row["op"] for row in instructions).items())),
        "framing": {key: alignment[key] for key in ("ok", "code_bytes", "framed_bytes", "opaque_bytes", "failure_count")},
        "branches": branches, "calls": calls, "terminal_candidates": terminals,
        "write_sites": writes, "opaque_boundaries": opaque,
        "unaligned_code_references": sum(not row["aligned"] for row in handoff["references"]["code"]),
        "zero_is_instruction_start": 0 in starts}


def assemble(index: dict, summaries: dict[str, dict]) -> dict:
    routes, seen = [], set()
    groups = defaultdict(list)
    for source in index["rows"]:
        profile = summaries[source["entry"]]
        if profile["entry_sha256"] != source["entry_sha256"]:
            raise ValueError("Classification entry differs from original")
        intros = []
        for intro in source["intro_evidence"]:
            key = (intro["caller_entry"], intro["source_offset"])
            if key in seen:
                raise ValueError("Duplicate intro evidence")
            seen.add(key)
            caller = summaries[intro["caller_entry"]]
            matches = [call for call in caller["calls"] if call["offset"] == intro["source_offset"]]
            if (caller["entry_sha256"] != intro["caller_entry_sha256"] or len(matches) != 1
                    or matches[0].get("target") != source["entry"]
                    or matches[0]["command"] != intro["command_id"] or matches[0]["end"] != intro["end_offset"]):
                raise ValueError("Intro does not match an exact Python handoff dispatch")
            # This lexical relation does NOT establish dominance, natural host
            # eligibility, a reachable true arm or preserved pre-call state.
            candidates = [branch["offset"] for branch in caller["branches"]
                          if branch["offset"] < intro["source_offset"] and any(
                              edge["kind"] == "condition_false_target" and edge["target_offset"] > intro["source_offset"]
                              for edge in branch["edges"])]
            intros.append({**intro, "kind": matches[0]["kind"],
                           "lexical_guard_candidates": candidates, "guard_qualification": "not_proven"})
            if source["scope"] == "event_named_target":
                groups[intro["caller_entry"]].append({"entry": source["entry"], "offset": intro["source_offset"],
                    "kind": matches[0]["kind"], "catalogued": bool(source["catalog_routes"])})
        routes.append({"entry": source["entry"], "scope": source["scope"], "classification": source["class"],
            "catalog_routes": source["catalog_routes"], "intros": intros,
            "branch_count": len(profile["branches"]), "terminal_candidate_count": len(profile["terminal_candidates"]),
            "static_dependencies": sorted({call["target"] for call in profile["calls"] if "target" in call}),
            "runtime_coverage": "not_measured_by_this_inventory"})
    event_routes = [row for row in routes if row["scope"] == "event_named_target"]
    # A tail-named target carries no frontier intro on purpose: its dispatch
    # record decodes point-wise but neither the strict decoder nor the Python
    # handoff frames it in sequence, so there is no handoff call to match it to.
    counts = {"indexed_entries": len(routes), "analyzed_entries_with_callers": len(summaries),
        "tail_named_event_targets": sum(row["scope"] == "event_named_tail_target" for row in routes),
        "event_targets": len(event_routes), "event_intro_sites": sum(len(row["intros"]) for row in event_routes),
        "multi_intro_targets": sum(len(row["intros"]) > 1 for row in event_routes),
        "catalogued_targets": sum(bool(row["catalog_routes"]) for row in event_routes),
        "event_branch_sites": sum(row["branch_count"] for row in event_routes),
        "event_terminal_candidates": sum(row["terminal_candidate_count"] for row in event_routes)}
    report = {"ok": True, "schema": SCHEMA, "archive_sha256": index["archive_sha256"],
        "classification_sha256": index["payload_sha256"], "catalog_sha256": index["catalog_sha256"],
        "scope": "static_all_indexed_entries_and_incoming_callers",
        "runtime_coverage": "not_measured", "nonliteral_reachability": "not_proven",
        "counts": counts, "routes": routes, "entries": [summaries[name] for name in sorted(summaries)],
        "caller_groups": [{"caller": name, "intro_count": len(rows), "routes": sorted(rows, key=lambda row: row["offset"])}
                          for name, rows in sorted(groups.items(), key=lambda pair: (-len(pair[1]), pair[0]))]}
    report["payload_sha256"] = fingerprint(report)
    return report


def build(arc: Path, index: dict, catalog: dict, jobs: int = 1) -> dict:
    if not 1 <= jobs <= 4:
        raise ValueError("Use between one and four worker processes")
    if index.get("schema") != INDEX_SCHEMA or fingerprint(index) != index.get("payload_sha256"):
        raise ValueError("Classification schema or fingerprint differs")
    if catalog.get("schema_version") != "kakyu_event_player_catalog/v8" or hashlib.sha256(canonical(catalog)).hexdigest() != index["catalog_sha256"]:
        raise ValueError("Classification is not bound to this catalog revision")
    archive = arc.read_bytes()
    archive_sha = hashlib.sha256(archive).hexdigest()
    if archive_sha != index["archive_sha256"] or archive_sha != catalog["source_profile"]["mes_archive"]["sha256"]:
        raise ValueError("Original archive identity differs")
    payloads = {name: archive[offset:offset + size] for name, offset, size in read_entries(arc)}
    names = {row["entry"] for row in index["rows"]}
    if len(names) != len(index["rows"]):
        raise ValueError("Duplicate classification entry")
    expected_events = {name for name in payloads if name.startswith("EVENT") and name.endswith(".MES")}
    actual_events = {row["entry"] for row in index["rows"]
                     if row["scope"] in EVENT_SCOPES}
    if expected_events != actual_events:
        raise ValueError("Classification omits an original EVENT entry")
    names.update(intro["caller_entry"] for row in index["rows"] for intro in row["intro_evidence"])
    if not names <= payloads.keys():
        raise ValueError("Classification references a missing original entry")
    work = [(name, payloads[name], archive_sha) for name in sorted(names)]
    summaries = {}
    def consume(results):
        for result in results:
            summaries[result["entry"]] = result
            print("ANALYZED", len(summaries), "/", len(work), result["entry"], file=sys.stderr, flush=True)
    if jobs == 1:
        consume(map(summarize_entry, work))
    else:
        with ProcessPoolExecutor(max_workers=jobs) as pool:
            consume(pool.map(summarize_entry, work))
    if hashlib.sha256(arc.read_bytes()).hexdigest() != archive_sha:
        raise ValueError("Original archive changed during analysis")
    return assemble(index, summaries)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("elfimage", type=Path)
    parser.add_argument("--classification", type=Path, default=Path("config/event_catalog/route_classification_v1.json"))
    parser.add_argument("--catalog", type=Path, default=Path("config/event_catalog/original_events_v1.json"))
    parser.add_argument("--jobs", type=int, default=4)
    parser.add_argument("--summary", action="store_true", help="Print only identity and counts after analyzing every entry")
    parser.add_argument("--verify", type=Path, help="Recompute and require an exact saved inventory match")
    args = parser.parse_args()
    try:
        report = build(args.elfimage / "mes.arc", json.loads(args.classification.read_text(encoding="utf-8")),
                       json.loads(args.catalog.read_text(encoding="utf-8")), args.jobs)
        if args.verify:
            saved = json.loads(args.verify.read_text(encoding="utf-8"))
            if saved.get("schema") != SCHEMA or fingerprint(saved) != saved.get("payload_sha256") or canonical(saved) != canonical(report):
                raise ValueError("Saved analysis inventory does not reproduce from originals")
        if args.verify or args.summary:
            report = {"ok": True, "schema": SCHEMA, "counts": report["counts"], "payload_sha256": report["payload_sha256"]}
        print(json.dumps(report, ensure_ascii=False, separators=(",", ":")))
        return 0
    except (OSError, ValueError, KeyError, TypeError) as failure:
        print(json.dumps({"ok": False, "error": str(failure)}))
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
