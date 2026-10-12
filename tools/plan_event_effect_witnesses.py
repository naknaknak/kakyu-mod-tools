"""Event definition v4, unit 1b, part A: plan the shift witnesses and the
done-cell probe requests a v2 analysis-group replay needs.

Reads every `kakyu_event_analysis_group_replay/v2` file in a directory and
writes one `kakyu_event_effect_witness_request/v1` request file per replay,
named the same as the replay. Pure Python: no Godot, no archive access. See
`analysis/_docs/v4_unit1b_witness_spec.md` and
`docs/spec/data/event_definition_v4_design.md` ("Unit 1a measurement").

    py tools/plan_event_effect_witnesses.py --replays analysis/replays_v2 --out analysis/witness_requests
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

# The request document's payload_sha256 is copied from the replay (it names
# the replay's profile, per the spec), never recomputed with
# tools/payload_values.fingerprint - there is no canonical form defined for
# this scratch request schema.

# A `kakyu_event_analysis_group/v14` flow profile's replay carries per-hop
# `state_changes` lists, not the prefix/callee/resume dict this planner reads,
# and its documents never use witnesses (TD-37): such a replay is skipped.
FLOW_RUNTIME_SCHEMA = "kakyu_event_analysis_group_runtime/v14"

CLOCK_CELLS = {("state_u16", 0, 0), ("state_u16", 0, 1), ("state_u16", 0, 19)}
STEPS = [7, -7, 1, -1]
STATE_CHANGE_LISTS = ("prefix", "callee", "resume")


def cell_key(row: dict) -> tuple:
    return (str(row["storage"]), int(row["bank"]), int(row["index"]))


def net_changes_for_variant(variant: dict) -> dict:
    """The variant's NET change per cell over prefix + callee + resume state
    changes, in that order: first `before` seen, last `after` seen. Cells
    whose net effect is zero (a round trip across the three lists) are
    dropped: "for every cell that changed" means the net changed."""
    net: dict[tuple, dict] = {}
    changes = variant.get("state_changes") or {}
    for name in STATE_CHANGE_LISTS:
        for row in changes.get(name) or []:
            key = cell_key(row)
            if key not in net:
                net[key] = {"storage": row["storage"], "bank": int(row["bank"]), "index": int(row["index"]),
                            "before": int(row["before"]), "after": int(row["after"])}
            else:
                net[key]["after"] = int(row["after"])
    return {key: value for key, value in net.items() if value["before"] != value["after"]}


def _message_identity(rows: list) -> tuple:
    return tuple((str(row.get("entry", "")), int(row.get("offset", -1))) for row in (rows or []))


def _terminal_identity(terminal: dict) -> tuple:
    return (str(terminal.get("entry", "")), str(terminal.get("status", "")),
            int(terminal.get("offset", -1)), int(terminal.get("end", -1)), str(terminal.get("target", "")))


def group_key(variant: dict) -> tuple:
    """(the offsets and entries of prefix_messages + messages + resume.messages,
    the last terminal - the resume's when there is one, else the callee's)."""
    resume = variant.get("resume")
    messages = (_message_identity(variant.get("prefix_messages"))
                + _message_identity(variant.get("messages"))
                + (_message_identity(resume.get("messages")) if resume else ()))
    terminal = _terminal_identity(resume["terminal"] if resume else variant["terminal"])
    return (messages, terminal)


def group_route_variants(route: dict) -> list:
    """Reached variants of one route, grouped by `group_key`, in first-seen
    order. Returns a list of (key, [variant, ...]) in first-group-seen order."""
    order: list[tuple] = []
    groups: dict[tuple, list] = {}
    for variant in route.get("variants", []):
        if not variant.get("reached", False):
            continue
        key = group_key(variant)
        if key not in groups:
            groups[key] = []
            order.append(key)
        groups[key].append(variant)
    return [(key, groups[key]) for key in order]


def plan_route(route: dict) -> tuple[list, list, dict]:
    """Returns (shift_requests, done_probe_requests, skip_counts) for one route."""
    shift_requests: list[dict] = []
    done_probe_requests: list[dict] = []
    skipped = {"clock": 0, "entries_vary": 0, "flag_pattern": 0}
    route_id = route["route_id"]

    for _key, group in group_route_variants(route):
        first_variant = group[0]
        nets = {variant["variant_id"]: net_changes_for_variant(variant) for variant in group}

        candidate_cells: dict[tuple, None] = {}
        for net in nets.values():
            for key in net:
                candidate_cells.setdefault(key, None)

        for key in sorted(candidate_cells):
            storage, bank, index = key
            contributors = [net[key] for net in nets.values() if key in net]
            if not contributors:
                continue
            if key in CLOCK_CELLS:
                skipped["clock"] += 1
                continue
            befores = {row["before"] for row in contributors}
            if len(befores) >= 2:
                skipped["entries_vary"] += 1
                continue
            before_value = next(iter(befores))
            if storage == "global_u8" and all(row["before"] == 0 and row["after"] == 1 for row in contributors):
                skipped["flag_pattern"] += 1
                continue
            shift_requests.append({
                "kind": "shift",
                "route_id": route_id,
                "variant_id": first_variant["variant_id"],
                "cell": {"storage": storage, "bank": bank, "index": index},
                "entry": before_value,
                "steps": list(STEPS),
            })

        done_eligible = len(group) > 0 and all(
            (variant.get("reentry") or {}).get("message_count") == 0 for variant in group
        )
        if done_eligible:
            first_net = nets[first_variant["variant_id"]]
            cells = []
            for key in sorted(first_net):
                if key in CLOCK_CELLS:
                    continue
                storage, bank, index = key
                cells.append({"storage": storage, "bank": bank, "index": index, "entry": first_net[key]["before"]})
            done_probe_requests.append({
                "kind": "done_probe",
                "route_id": route_id,
                "variant_id": first_variant["variant_id"],
                "cells": cells,
            })

    return shift_requests, done_probe_requests, skipped


def plan_replay(replay: dict) -> tuple[dict, dict]:
    """Returns (request_document, summary) for one replay document."""
    all_shift: list[dict] = []
    all_done_probe: list[dict] = []
    skipped_total = {"clock": 0, "entries_vary": 0, "flag_pattern": 0}
    groups_total = 0
    for route in replay.get("routes", []):
        groups_total += len(group_route_variants(route))
        shift_requests, done_probe_requests, skipped = plan_route(route)
        all_shift.extend(shift_requests)
        all_done_probe.extend(done_probe_requests)
        for reason in skipped_total:
            skipped_total[reason] += skipped[reason]

    document = {
        "schema": "kakyu_event_effect_witness_request/v1",
        "group_id": replay.get("group_id"),
        "profile": replay.get("profile"),
        "payload_sha256": replay.get("payload_sha256"),
        "requests": all_shift + all_done_probe,
    }
    summary = {
        "groups": groups_total,
        "shift_requests": len(all_shift),
        "done_probe_requests": len(all_done_probe),
        "skipped": skipped_total,
    }
    return document, summary


def is_flow_replay(replay: dict) -> bool:
    return replay.get("runtime_schema") == FLOW_RUNTIME_SCHEMA


def plan_directory(replays_dir: Path, out_dir: Path) -> dict:
    out_dir.mkdir(parents=True, exist_ok=True)
    totals = {"groups": 0, "shift_requests": 0, "done_probe_requests": 0,
              "skipped": {"clock": 0, "entries_vary": 0, "flag_pattern": 0}}
    per_file = []
    skipped_flow_replays = []
    for replay_path in sorted(replays_dir.glob("*.json")):
        with replay_path.open("r", encoding="utf-8") as fh:
            replay = json.load(fh)
        if is_flow_replay(replay):
            skipped_flow_replays.append(replay_path.stem)
            continue
        document, summary = plan_replay(replay)
        out_path = out_dir / replay_path.name
        with out_path.open("w", encoding="utf-8") as fh:
            json.dump(document, fh, indent=1, sort_keys=True)
        per_file.append({"profile": replay_path.stem, **summary})
        totals["groups"] += summary["groups"]
        totals["shift_requests"] += summary["shift_requests"]
        totals["done_probe_requests"] += summary["done_probe_requests"]
        for reason in totals["skipped"]:
            totals["skipped"][reason] += summary["skipped"][reason]
    return {"files": len(per_file), "skipped_flow_replays": skipped_flow_replays,
            "totals": totals, "per_file": per_file}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--replays", required=True, help="directory of kakyu_event_analysis_group_replay/v2 files")
    parser.add_argument("--out", required=True, help="output directory for kakyu_event_effect_witness_request/v1 files")
    args = parser.parse_args()

    result = plan_directory(Path(args.replays), Path(args.out))
    print(json.dumps({"files": result["files"], "skipped_flow_replays": len(result["skipped_flow_replays"]),
                      "totals": result["totals"]}, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
