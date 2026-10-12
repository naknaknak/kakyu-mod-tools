"""Projects one event site into a `kakyu_event_definition/v5` document
(WD-23). Shares `project_event_definition_v4`'s whole pipeline for the v4
body - schema and `contract_fingerprint` come from `--contract-fingerprint`
and `SCHEMA_VERSION` is monkeypatched for the run, so this module has no
copy of the v3/v4 candidate/effect/dialogue machinery. The only new code
here is `visits`, added for the two sites whose v13 profile declares a
document-level visit ladder (EP-11 parts 1a-1c;
`docs/spec/mes/44c_caller_group.md`): `tina.town.44c.10.2` (EVENTM10 site
B) and `tina.town.44c.03.1` (EVENTM03). Every other site's v5 document is
v4's own plus the v5 schema fields only.

    py tools/project_event_definition_v5.py --site <id> --names <dir> \
        --profiles-dir <dir> --replays-dir analysis/replays_v2 \
        --witnesses-dir analysis/witnesses --package <dir> --arc <mes.arc> \
        --out <dir> [--shared-lines <json>] [--resolved-out <dir>]

Same command line as `project_event_definition_v4.py`; `--contract-fingerprint`
defaults to `config/contracts/event_definition_v5/contract_fingerprint`.
"""
from __future__ import annotations

import argparse
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import project_event_definition as ped  # noqa: E402
import project_event_definition_v4 as pv4  # noqa: E402
import state_cells  # noqa: E402

SCHEMA_VERSION = "kakyu_event_definition/v5"
DEFAULT_CONTRACT_FINGERPRINT_PATH = os.path.join(
    "config", "contracts", "event_definition_v5", "contract_fingerprint"
)

# ---------------------------------------------------------------------------
# WD-23's two visit-ladder sites. Evidence: `config/event_catalog/
# analysis_groups/44c_m10b_v13.json` / `44c_m03_v13.json` (the v13 profiles
# EP-11 parts 1a/1c declared) and their v2 replays (this module reads
# `<replays_dir>/<profile stem>.json`, the same file `project_event_definition_v4`
# reads for the route body - profile stem, not group_id). The M10 gate cell
# ranges and the M03 join condition are the audited static/replay evidence
# recorded in docs/spec/mes/44c_caller_group.md, not a hand list: they are
# the same 23/24-cell "any non-zero" test and the same `[2420]==1 and
# [2417]==0` join the document already cites by exact offset.
# ---------------------------------------------------------------------------

M10_GATE_23 = (
    [("global_u8", i) for i in range(287, 303)]
    + [("global_u8", i) for i in (316, 317, 318, 320, 321, 322, 323)]
)
M10_GATE_24 = M10_GATE_23 + [("global_u8", 319)]

# visit_id -> (counter value, gate cell list, gate polarity [True = the
# gate's non-zero/true edge, i.e. the visit dispatches EVENTM11.MES]).
M10_VISIT_GATES = {
    "visit2-gate": (1, M10_GATE_23, True),
    "visit3": (2, M10_GATE_23, False),
    "visit3-gate": (2, M10_GATE_23, True),
    "visit4-gate": (3, M10_GATE_24, True),
    "visit5-gate": (3, M10_GATE_24, True),
}

VISIT_SITES = {
    "tina.town.44c.10.2": {
        "profile_stem": "44c_m10b_v13",
        "profile_path": os.path.join("config", "event_catalog", "analysis_groups", "44c_m10b_v13.json"),
        "group_id": "44c-m10b",
        "route_id": "44c-m10b",
        "callee_entry": "EVENTM10.MES",
        "nested_entries": ["EVENTM11.MES"],
        "select_kind": "m10",
    },
    "tina.town.44c.03.1": {
        "profile_stem": "44c_m03_v13",
        "profile_path": os.path.join("config", "event_catalog", "analysis_groups", "44c_m03_v13.json"),
        "group_id": "44c-m03",
        "route_id": "44c-m03",
        "callee_entry": "EVENTM03.MES",
        "nested_entries": [],
        "select_kind": "m03",
    },
}


def _cell_leaf(storage, index, op, value, bank=0):
    return {"kind": "cell", "storage": storage, "bank": bank, "index": index, "op": op, "value": value}


def _gate_ast(cells, positive):
    """The gate's own branch condition, whole: `or` of `not_equal 0` leaves
    on its true edge, De Morgan's negation (`and` of `equal 0` leaves) on
    its false edge - the same 23/24 cells either way, never simplified to
    the one seed_writes cell alone."""
    op = "or" if positive else "and"
    leaf_op = "not_equal" if positive else "equal"
    return {"op": op, "args": [_cell_leaf(storage, index, leaf_op, 0) for storage, index in cells]}


def _entry_state_value(visit, storage, index, bank=0):
    for row in visit.get("entry_state", []) or []:
        if row.get("storage") == storage and int(row.get("bank", 0)) == bank and int(row.get("index")) == index:
            return int(row["value"])
    raise KeyError("visit %s entry_state has no %s[%d]" % (visit.get("visit_id"), storage, index))


def build_select_rows(meta, visit):
    kind = meta["select_kind"]
    if kind == "m10":
        counter_value = _entry_state_value(visit, "global_u8", 2456)
        expected_counter, gate_cells, positive = M10_VISIT_GATES[visit["visit_id"]]
        if counter_value != expected_counter:
            raise ValueError(
                "visit %s: entry_state global_u8[2456]=%d != the documented rung %d"
                % (visit["visit_id"], counter_value, expected_counter)
            )
        return [
            {"storage": "global_u8", "bank": 0, "index": 2456, "operator": "equals", "value": counter_value},
            {"type": "mes_expression", "ast": _gate_ast(gate_cells, positive)},
        ]
    if kind == "m03":
        counter_value = _entry_state_value(visit, "global_u8", 2421)
        return [
            {"storage": "global_u8", "bank": 0, "index": 2421, "operator": "equals", "value": counter_value},
            {
                "type": "mes_expression",
                "ast": {
                    "op": "and",
                    "args": [
                        _cell_leaf("global_u8", 2420, "equal", 1),
                        _cell_leaf("global_u8", 2417, "equal", 0),
                    ],
                },
            },
        ]
    raise ValueError("unknown select_kind %r" % kind)


def build_follows(visit):
    after = visit.get("after")
    if after == "route":
        return "first"
    return after  # "reentry" or an earlier visit_id, unchanged


def build_visit_effects(visits, replay_visits_by_id, state_cells_table, unresolved_out, argument_storage=None):
    """Decides `after` rows the way v4 decides a result's effects (rule 2,
    `project_event_definition_v4.decide_effects_for_group`), treating the
    route's own visits as one group: every net-changed cell over the whole
    ladder (the replay's own `state_diff`, not only the profile's curated
    `expected_state`), one decision per cell (write when every contributing
    visit agrees on a final value, add when they agree on a delta, else a
    document-level `unresolved` line - no witness exists at visit
    granularity, so an ambiguous single-entry cell is always `unresolved`,
    never guessed). The one decided row for a cell is then assigned to
    every visit whose own run actually changed that cell.

    With `argument_storage` (TD-56 D11, `project_event_definition.ArgumentStorage`) a visit's
    `global_i32` change that its own run's command-`0x09` literal wrote is call-argument
    storage and takes no part in the decision; the caller records it in `unresolved`.

    Returns `{visit_id: [after rows]}`.
    """
    candidates = []
    per_visit_changes = {}
    for visit in visits:
        vid = visit["visit_id"]
        replay_visit = replay_visits_by_id[vid]
        declared_keys = {pv4.cell_key3(row) for row in visit.get("expected_state", []) or []}
        net_changes = {}
        for row in replay_visit.get("state_diff", []) or []:
            before, after = int(row["before"]), int(row["after"])
            if before == after:
                continue
            key = (row["storage"], int(row.get("bank", 0)), int(row["index"]))
            net_changes[key] = {
                "storage": row["storage"], "bank": int(row.get("bank", 0)), "index": int(row["index"]),
                "before": before, "after": after,
            }
        if argument_storage is not None:
            net_changes = argument_storage.split(net_changes, [replay_visit.get("executed")])
        per_visit_changes[vid] = net_changes
        candidates.append({
            "variant_id": vid, "route_id": visit.get("_route_id", ""),
            "net_changes": net_changes, "declared_keys": declared_keys,
        })

    rows, _evidence = pv4.decide_effects_for_group(candidates, "visits", state_cells_table, {}, unresolved_out)

    per_visit_rows = {vid: [] for vid in per_visit_changes}
    for row in rows:
        key = (row["storage"], row["bank"], row["index"])
        for vid, changes in per_visit_changes.items():
            if key in changes:
                per_visit_rows[vid].append(dict(row))
    return per_visit_rows


def build_visit_dialogue(messages, events_doc_by_entry):
    report = {"missing_records": [], "missing_text_operand": []}
    entries = []
    for message in messages:
        entry = ped.build_dialogue_entry(message, events_doc_by_entry, report)
        if entry is None:
            raise RuntimeError("visit dialogue: could not resolve message %r (report=%r)" % (message, report))
        entries.append(entry)
    entries.append({"kind": "scene_end"})
    return entries


def build_visits_for_site(doc_id, meta, args, state_cells_table):
    profile = ped.load_json(meta["profile_path"])
    routes = {r["route_id"]: r for r in profile.get("routes", [])}
    route = routes[meta["route_id"]]
    raw_visits = route.get("visits") or []
    if not raw_visits:
        raise RuntimeError("route %s declares no visits" % meta["route_id"])

    replay = ped.load_json(os.path.join(args.replays_dir, "%s.json" % meta["profile_stem"]))
    replay_route = next(r for r in replay["routes"] if r["route_id"] == meta["route_id"])
    # Every variant's own visits replay is identical (measured: WD-23 report),
    # since none of these visits reads a calendar cell; the first variant is
    # the canonical dialogue/effects source.
    replay_visits = replay_route["variants"][0]["visits"]
    replay_visits_by_id = {v["visit_id"]: v for v in replay_visits}

    for visit in raw_visits:
        visit["_route_id"] = meta["route_id"]

    events_doc_by_entry = {
        entry: ped.load_events_document(args.package, entry)
        for entry in [meta["callee_entry"]] + meta["nested_entries"]
    }

    unresolved_out = []
    argument_storage = ped.ArgumentStorage(lambda entry: ped.load_events_document(args.package, entry))
    effects_by_visit = build_visit_effects(raw_visits, replay_visits_by_id, state_cells_table, unresolved_out,
                                           argument_storage=argument_storage)
    unresolved_out.extend(argument_storage.lines())

    # The v13 profile itself carries no "repeats" field (it is a v5-only
    # concept): the profile's own construction is what marks the fixed
    # point - EP-11 declared exactly one extra revisit of the rung the
    # ladder no longer advances past (EVENTM10 site B's `visit5-gate`,
    # EVENTM03's `ladder-15`), always the last entry of the route's own
    # `visits` list, to prove it repeats. A defensive check confirms the
    # counter cell itself shows no net change on that last visit's own
    # replay, rather than trusting list order alone.
    counter_storage, counter_index = {"m10": ("global_u8", 2456), "m03": ("global_u8", 2421)}[meta["select_kind"]]
    fixed_point_id = raw_visits[-1]["visit_id"]

    visits_out = []
    for visit in raw_visits:
        vid = visit["visit_id"]
        replay_visit = replay_visits_by_id[vid]
        is_fixed_point = vid == fixed_point_id
        if is_fixed_point:
            counter_before = _entry_state_value(visit, counter_storage, counter_index)
            counter_after_rows = [r for r in replay_visit.get("state_diff", []) or []
                                   if r["storage"] == counter_storage and int(r["index"]) == counter_index]
            if counter_after_rows and int(counter_after_rows[0]["after"]) != counter_before:
                raise RuntimeError(
                    "visit %s: expected to be the fixed point (last declared visit) but its own counter "
                    "cell still advances (%r)" % (vid, counter_after_rows[0])
                )
        visits_out.append({
            "visit_id": vid,
            "follows": build_follows(visit),
            "select": build_select_rows(meta, visit),
            "dialogue": build_visit_dialogue(replay_visit["messages"], events_doc_by_entry),
            "after": effects_by_visit.get(vid, []),
            "repeats": is_fixed_point,
            "evidence": {
                "group": meta["group_id"],
                "profile_sha256": profile["payload_sha256"],
                "route": meta["route_id"],
                "seed_basis": visit.get("seed_basis", "none"),
            },
        })
    return visits_out, unresolved_out


def _resolve_visit_dialogue(dialogue, text_doc_by_entry):
    resolved = []
    for entry in dialogue:
        entry = json.loads(json.dumps(entry))
        if entry.get("kind") == "text":
            text_ref = entry["text_ref"]
            strings = text_doc_by_entry[text_ref["entry"]]["strings"]
            text_ref["text"] = strings[text_ref["s"]]
        resolved.append(entry)
    return resolved


def inject_visits(doc_id, meta, args, state_cells_table):
    tracked_path = os.path.join(args.out, "%s.json" % doc_id)
    with open(tracked_path, "r", encoding="utf-8") as fh:
        document = json.load(fh)

    visits, unresolved_out = build_visits_for_site(doc_id, meta, args, state_cells_table)
    document["visits"] = visits
    if unresolved_out:
        document["unresolved"] = ped.merge_unresolved(list(document.get("unresolved", [])) + unresolved_out)

    pv4.recompute_cell_classes(document, state_cells_table)

    with open(tracked_path, "w", encoding="utf-8", newline="\n") as fh:
        json.dump(document, fh, indent=2, ensure_ascii=False, sort_keys=False)
        fh.write("\n")

    resolved_dir = args.resolved_out or args.out
    resolved_path = os.path.join(resolved_dir, "%s.resolved.json" % doc_id)
    involved_entries = [meta["callee_entry"]] + meta["nested_entries"]
    text_doc_by_entry = {entry: ped.load_text_document(args.package, entry) for entry in involved_entries}
    if os.path.isfile(resolved_path):
        with open(resolved_path, "r", encoding="utf-8") as fh:
            resolved_document = json.load(fh)
    else:
        resolved_document = json.loads(json.dumps(document))
    resolved_document["visits"] = [
        dict(v, dialogue=_resolve_visit_dialogue(v["dialogue"], text_doc_by_entry))
        for v in visits
    ]
    resolved_document["unresolved"] = document["unresolved"]
    os.makedirs(resolved_dir, exist_ok=True)
    with open(resolved_path, "w", encoding="utf-8", newline="\n") as fh:
        json.dump(resolved_document, fh, indent=2, ensure_ascii=False)
        fh.write("\n")

    return len(visits)


def run_site_v5(args):
    previous_schema = pv4.SCHEMA_VERSION
    pv4.SCHEMA_VERSION = SCHEMA_VERSION
    try:
        rc = pv4.run_site(args)
    finally:
        pv4.SCHEMA_VERSION = previous_schema
    if rc != 0:
        return rc
    meta = VISIT_SITES.get(args.site)
    if meta is not None:
        state_cells_table = state_cells.load()
        visit_count = inject_visits(args.site, meta, args, state_cells_table)
        print("WD23_VISITS site=%s visits=%d" % (args.site, visit_count))
    return 0


def run_catalog_v5(args):
    previous_schema = pv4.SCHEMA_VERSION
    pv4.SCHEMA_VERSION = SCHEMA_VERSION
    try:
        return pv4.run_catalog(args)
    finally:
        pv4.SCHEMA_VERSION = previous_schema


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--catalog")
    parser.add_argument("--event")
    parser.add_argument("--site")
    parser.add_argument("--profiles-dir", default=os.path.join("config", "event_catalog", "analysis_groups"))
    parser.add_argument("--replays-dir", default=os.path.join("analysis", "replays_v2"))
    parser.add_argument("--witnesses-dir", default=os.path.join("analysis", "witnesses"))
    parser.add_argument("--names", required=True)
    parser.add_argument("--package", required=True)
    parser.add_argument("--replay")
    parser.add_argument("--arc", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--resolved-out", default=None)
    parser.add_argument("--shared-lines", default=None)
    parser.add_argument("--contract-fingerprint", default=DEFAULT_CONTRACT_FINGERPRINT_PATH)
    args = parser.parse_args()

    if bool(args.event) == bool(args.site):
        print("exactly one of --event or --site is required")
        return 1
    if args.event:
        if not args.catalog or not args.replay:
            print("--event requires --catalog and --replay")
            return 1
        return run_catalog_v5(args)
    return run_site_v5(args)


if __name__ == "__main__":
    sys.exit(main())
