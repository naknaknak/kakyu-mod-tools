"""Build an analysis-group profile from a route spec and its measurement.

    py tools/build_event_route_profile.py --arc "<mes.arc>" --spec analysis/19c_l05_spec.json \
        --measure analysis/19c_l05_measure.json --out config/event_catalog/analysis_groups/19c_l05_v6.json

Replaces the per-route copies of analysis/build_35m_i13_profile.py. Every
number comes from the measurement: the door, the return record, message
counts, the constant/varying split over the two-pass profile cells (values
read from `profile_cell_effects`, never from diffs), the reentry (declared as
measured, with a per-variant override for any row whose reentry differs), the
contracts (caller and/or callee) and the selections. One route per callee
answer when the callee asks; one route otherwise. A variant that did not
reach the door is dropped and listed with where its walk ended - unless the
walk left the caller by a handoff to a script the spec names in
`bypass_targets` (a map's exit, `["MACHI.MES"]` for the grounds' gate): that
walk is declared as a bypass variant (writes, selections, the exact handoff,
message count, the profile cells' values and every cell the walk changed),
which the validator replays from the origin and checks never dispatches the
callee. A `direct` variant is dropped by design (its guard rejects) and its
finding goes to `unresolved`.

A root handoff (command 0x0E) becomes a v6 root-replacement group. A nested
call (command 0x0F, `form: nested_call`) becomes a caller-continuation group:
the callee's return record is the outcome, and the caller's measured resume
walk is declared under `resume` with the policy its stop names - a root
handoff (`natural_handoff`, v5), a dispatch to a script outside the package
(`stop_before_unprovided_dependency`, v5), the caller's own routine-40
without a supplied choice (`def_selection_boundary`, v8) or the caller's own
loop, proven by a repeated continuation (`caller_menu_loop`, v10, declared
with its head record, period, cycle and per-period message count). A variant
whose resume stops elsewhere or after a different count is dropped and listed
(it needs its own route, the 44C M03 / 06C J18 precedent).
"""
from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from build_event_analysis_inventory import fingerprint  # noqa: E402
from extract_kakyu_arc import read_entries  # noqa: E402
from mes_analyzer_handoff import build_container, build_handoff  # noqa: E402

CALENDAR_TABLE = "f21ee0fcb09e960046878e35ad0410aed88680f849ace471b713ef7a12525b4a"
TYPED = {"kind": "typed_record"}
PROBE_ONLY_CONTRACT_KEYS = {"ok", "messages_before_boundary", "awaiting_stop"}


def intify(node):
    """Godot's JSON writes every number as a float; restore integral values to int."""
    if isinstance(node, float) and node.is_integer():
        return int(node)
    if isinstance(node, list):
        return [intify(x) for x in node]
    if isinstance(node, dict):
        return {k: intify(v) for k, v in node.items()}
    return node


def w(storage: str, index: int, value: int) -> dict:
    return {"storage": storage, "bank": 0, "index": index, "value": value}


def cell_map(rows: list) -> dict:
    return {(r["storage"], r["index"]): r["value"] for r in rows}


def restricted(diff: list, cells: list[tuple], calendar: set) -> dict:
    out = {}
    for d in diff:
        key = (d["storage"], d["index"])
        if key in cells and key not in calendar:
            out[key] = d["after"]
    return out


def exit_cells(diff: list, calendar: set) -> dict:
    """Every profile-storage cell a walk changed, calendar cells aside."""
    out = {}
    for d in diff:
        key = (d["storage"], d["index"])
        if d["storage"] in ("global_u8", "state_u16", "banked_u16") and key not in calendar:
            out[key] = d["after"]
    return out


def binding_for(entry: str, handoff: dict, offset: int, end: int, code: bytes) -> dict:
    """Typed binding, or an opaque-tail binding when the record lies in one."""
    for tail in handoff["typed_ir"].get("opaque_boundaries", []):
        if tail["source_offset"] <= offset < end <= tail["end_offset"]:
            return {"kind": "runtime_observation_in_opaque_tail", "offset": tail["source_offset"],
                    "end": tail["end_offset"], "sha256": tail["raw_sha256"]}
    return dict(TYPED)


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--arc", required=True)
    parser.add_argument("--spec", required=True)
    parser.add_argument("--measure", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--unresolved", default=None, help="text file, one unresolved line per paragraph")
    args = parser.parse_args(argv)

    spec = json.loads(Path(args.spec).read_text(encoding="utf-8"))
    measured = intify(json.loads(Path(args.measure).read_text(encoding="utf-8")))
    arc = Path(args.arc)
    blob = arc.read_bytes()
    archive_sha = hashlib.sha256(blob).hexdigest()
    payloads = {n: blob[o:o + s] for n, o, s in read_entries(arc)}
    members = list(spec["members"])
    for reported in measured.get("not_a_package_member", []):
        print("WARNING not a package member during measurement:", reported)
    code = {n: build_container(payloads[n])["_bytecode"] for n in members}
    contract_entries = [str(c["entry"]).upper() for c in spec.get("map_location_contracts", [])]
    handoffs = {n: build_handoff(payloads[n], {"archive": "mes.arc", "entry": n, "source_kind": "original_arc",
                                              "archive_sha256": archive_sha})
                for n in dict.fromkeys([spec["caller"], spec["callee"], *contract_entries])}

    def sha(entry: str, lo: int, hi: int) -> str:
        return hashlib.sha256(code[entry][lo:hi]).hexdigest()

    caller, callee = spec["caller"], spec["callee"]
    guard = spec["guard"]
    call = spec["call"]
    origin = spec["origin"]
    calendar = {("state_u16", i) for i in spec.get("calendar_cells", [0, 1, 2, 4, 7, 10, 19, 25])}
    profile_cells = [tuple(c) for c in measured["profile_cells"]]
    guard_cases = [{"case_id": c["case_id"], "writes": c["writes"], "expected": c["condition_value"]}
                   for c in measured["guard_cases"]]
    assert guard_cases[0]["case_id"] == "baseline" and guard_cases[0]["expected"] == 1, guard_cases[0]

    contracts = []
    selections_base = []
    if measured.get("caller_contract"):
        contract = {k: v for k, v in measured["caller_contract"].items() if k not in PROBE_ONLY_CONTRACT_KEYS}
        contracts.append(contract)
        selections_base.append({"owner_entry": caller, "boundary_offset": contract["boundary_offset"],
                                "result_value": spec["caller_choice"]["result_value"]})
    # EP-12 PROMIS: a callee-owned prefix choice (an earlier, undeclared
    # routine-40 before the callee_question) is bound into choice_contracts
    # and selections the same way a caller_choice is, so the runtime
    # validator answers it the same fixed way on every replay.
    prefix_contracts = measured.get("callee_prefix_contracts", [])
    prefix_choices = spec.get("callee_prefix_choices", [])
    assert len(prefix_contracts) == len(prefix_choices), (
        "callee_prefix_contracts/callee_prefix_choices count mismatch", len(prefix_contracts), len(prefix_choices))
    for prefix_contract_raw, prefix_choice in zip(prefix_contracts, prefix_choices):
        prefix_contract = {k: v for k, v in prefix_contract_raw.items() if k not in PROBE_ONLY_CONTRACT_KEYS}
        contracts.append(prefix_contract)
        selections_base.append({"owner_entry": callee, "boundary_offset": prefix_contract["boundary_offset"],
                                "result_value": int(prefix_choice["result_value"])})
    callee_boundary = None
    if measured.get("callee_contract"):
        contract = {k: v for k, v in measured["callee_contract"].items() if k not in PROBE_ONLY_CONTRACT_KEYS}
        contracts.append(contract)
        callee_boundary = contract["boundary_offset"]

    nested = spec.get("form") == "nested_call" or int(call["command"]) == 15
    bypass_targets = {str(t).upper() for t in spec.get("bypass_targets", [])}
    map_contracts = [map_location_binding(str(c["entry"]).upper(), handoffs[str(c["entry"]).upper()], c, code, sha)
                     for c in spec.get("map_location_contracts", [])]
    blocks = measured["results"] if "results" in measured else {"null": measured}
    routes = []
    dropped_notes = []
    policies = set()
    for r_key, block in blocks.items():
        result = None if r_key == "null" else int(r_key)
        target = block["route"]["target"]
        terminal = target["terminal"]
        if result is not None and not terminal and str(target.get("stop", "")):
            # A callee answer whose run stopped before any terminal - a second
            # routine-40 of the callee the spec does not declare (EVENTB14's
            # answer 2, EVENTA22's answer 2) - is measured and not declared:
            # the profile carries the answers that reach a terminal and names
            # this one under `unresolved`, the same way a dropped variant is.
            dropped_notes.append(f"result {result} of the routine-40 selection at {callee}:{callee_boundary}:"
                                 f" the callee stopped at '{target['stop']}' after {int(target['messages'])} messages"
                                 f" without reaching a terminal; measured and not declared")
            continue
        spent_contracts = []
        if map_contracts:
            # 0.319.0: which runs drain each queue is measured, not assumed.
            chain = [("prefix", block["route"]["prefix"]), ("callee", target)]
            if nested:
                chain.append(("resume", block["resume"]))
            spent_contracts = [dict(c, spent_by=spent_by_runs(c, chain, block["route"]["whole"])) for c in map_contracts]
        if nested:
            assert terminal.get("status") == "script_return", ("the callee did not return", terminal)
            door = (int(terminal["offset"]), int(terminal["end"]), "")
            resume = block["resume"]
            policy, resume_outcome = resume_binding(caller, handoffs[caller], resume["stop"], code, sha)
            loop = loop_binding(caller, handoffs[caller], resume["stop"]) if policy == "caller_menu_loop" else None
            policies.add(policy)
            resume_key = (resume["stop"]["kind"], resume["stop"]["offset"], resume["messages"])
            resume_expected = restricted(resume["state_diff"], profile_cells, calendar)
            resume_effects = cell_map(block["resume_profile_cell_effects"])
        else:
            assert terminal.get("status") == "script_handoff_boundary", ("target did not leave by a door", terminal)
            door = (int(terminal["offset"]), int(terminal["end"]), str(terminal["target"]).upper())
            policy, resume_outcome, resume_key, resume_expected, resume_effects = None, None, None, {}, {}
        post_guard = block["post_guard"]
        reentry = block["reentry"]["direct"]
        reentry_record = block["reentry"]["direct_return_record"]
        bypass_rows = []
        rows = [{"name": "baseline", "cells": cell_map(block["profile_cell_effects"]), "messages": target["messages"],
                 "reentry_messages": reentry["messages"],
                 "reentry_diff": restricted(reentry["state_diff"], profile_cells, calendar),
                 "reentry_record": reentry_record, "writes": [], "resume_expected": resume_expected,
                 "resume_effects": resume_effects}]
        for v in measured["variants"]:
            v_result = v.get("result_value")
            if (v_result if v_result is not None else None) != result and not (v_result is None and result is None):
                if not (result is not None and v_result is None):
                    continue
            if v.get("mode") == "direct_from_prefix":
                dropped_notes.append(f"{v['variant_id']} (direct from the prefix state, guard {v['guard']['condition_value']}):"
                                     f" callee {v['callee_messages']} messages, arms {v['branches_changing_arm']},"
                                     f" cells {cell_map(v.get('profile_cell_effects', []))}")
                continue
            if not v.get("prefix_reached_dispatch"):
                record = v.get("prefix_terminal") or {}
                door_target = str(record.get("target", "")).upper()
                left_by_door = str(record.get("status", "")) == "script_handoff_boundary" and bool(door_target)
                if left_by_door and door_target in bypass_targets and callee not in v.get("prefix_entries", []):
                    # The guard turned the walk away and the caller left by a
                    # door of its own: the map's exit without the event.
                    bypass_rows.append({"name": v["variant_id"], "writes": v["writes"], "messages": int(v["prefix_messages"]),
                                        "record": record, "cells": cell_map(v["profile_cell_effects"]),
                                        "diff": exit_cells(v.get("prefix_state_diff", []), calendar)})
                    continue
                where = (f"; it leaves by {record['offset']}..{record['end']} -> {door_target} after {v['prefix_messages']} messages"
                         if left_by_door else f"; stop: {v.get('prefix_stop', '')}")
                dropped_notes.append(f"{v['variant_id']} did not reach the dispatch (guard {v.get('guard')}){where}")
                continue
            assert v["identical"] is True, (v["variant_id"], "whole and segmented runs differ", v.get("identical_detail"))
            if (v["terminal"]["offset"], v["terminal"]["end"]) != door[:2]:
                # Another door: a route of its own (the 09M M20 / 44C M03 shape), not a variant.
                dropped_notes.append(f"{v['variant_id']}: the callee leaves by another door,"
                                     f" {v['terminal'].get('offset')}..{v['terminal'].get('end')} ->"
                                     f" {str(v['terminal'].get('target', '')).upper()} after {v['callee_messages']} messages;"
                                     f" it needs its own route")
                continue
            row = {"name": v["variant_id"], "cells": cell_map(v["profile_cell_effects"]), "messages": v["callee_messages"],
                   "reentry_messages": v["reentry_messages"],
                   "reentry_diff": restricted(v["reentry_state_diff"], profile_cells, calendar),
                   "reentry_record": v["reentry_return_record"], "writes": v["writes"], "resume_expected": {},
                   "resume_effects": {}}
            if nested:
                v_key = (v["resume_stop"]["kind"], v["resume_stop"]["offset"], v["resume_messages"])
                if v_key != resume_key:
                    dropped_notes.append(f"{v['variant_id']}: the caller's resume differs from the baseline's"
                                         f" ({v['resume_stop']['kind']} at {v['resume_stop']['offset']} after"
                                         f" {v['resume_messages']} messages against {resume_key[0]} at {resume_key[1]}"
                                         f" after {resume_key[2]}); it needs its own route")
                    continue
                row["resume_expected"] = restricted(v["resume_state_diff"], profile_cells, calendar)
                row["resume_effects"] = cell_map(v["resume_profile_cell_effects"])
            rows.append(row)
        # The caller's completion effects: every profile cell the resume touched
        # in any row, split like the callee's - a constant value is declared on
        # the route, a varying one per variant (the validator checks the route's
        # list on every variant's resumed state).
        resume_constant, resume_varying = {}, {}
        if nested:
            resume_cells = sorted({cell for r in rows for cell in r["resume_expected"]})
            for cell in resume_cells:
                values = {r["resume_effects"].get(cell) for r in rows}
                assert None not in values, (cell, "missing from a row's resume_profile_cell_effects")
                if len(values) == 1:
                    resume_constant[cell] = values.pop()
                else:
                    resume_varying[cell] = {r["name"]: r["resume_effects"][cell] for r in rows}
        constant, varying = {}, {}
        for cell in profile_cells:
            values = {r["cells"].get(cell) for r in rows}
            assert None not in values, (cell, "missing from a row's profile_cell_effects")
            if len(values) == 1:
                constant[cell] = values.pop()
            else:
                varying[cell] = {r["name"]: r["cells"].get(cell) for r in rows}
        print(f"route {spec['group_id']}{'' if result is None else '-result%d' % result}: "
              f"{'return' if nested else 'door'} {door}, post_guard"
              f" {post_guard['condition_value']} -> {post_guard['next_offset']}, baseline messages {target['messages']}")
        print("  constant:", {"%s[%d]" % k: v for k, v in constant.items()})
        print("  varying:", {"%s[%d]" % k: v for k, v in varying.items()})
        base = rows[0]
        reentry_expected = [w(s, i, v) for (s, i), v in sorted(base["reentry_diff"].items())]
        reentry_outcome = _outcome(callee, handoffs[callee], reentry_record, code, sha)
        print("  reentry:", reentry_record, "messages", base["reentry_messages"], "expected", reentry_expected)
        route_id = spec["group_id"] if result is None else f"{spec['group_id']}-result{result}"
        route = {
            "route_id": route_id,
            "qualification": "caller_continuation_observation" if nested else "root_replacement_observation",
            "origin_offset": origin,
            "caller": {"entry": caller, "offset": call["offset"], "end": call["end"], "command": int(call["command"]),
                       "source_binding": binding_for(caller, handoffs[caller], call["offset"], call["end"], code[caller]),
                       "record_sha256": sha(caller, call["offset"], call["end"])},
            "callee": {"entry": callee, "offset": 0},
            "guard": {"offset": guard["offset"], "end": guard["end"], "false_target": guard["false_target"],
                      "source_binding": dict(TYPED), "record_sha256": sha(caller, guard["offset"], guard["end"]),
                      "prefix_sha256": sha(caller, origin, call["end"])},
            "post_guard_expected": int(post_guard["condition_value"]),
            "caller_outcome": {"kind": "dispatch"} if nested else {"kind": "root_handoff"},
            "outcome": (_outcome(callee, handoffs[callee], {"offset": door[0], "end": door[1], "status": "script_return"}, code, sha)
                        if nested else
                        _outcome(callee, handoffs[callee], {"offset": door[0], "end": door[1], "target": door[2],
                                                            "status": "script_handoff_boundary", "op": "script_handoff_marker"}, code, sha)),
            "state_context": {"kind": "original_calendar", "entry": "START.MES", "table_sha256": CALENDAR_TABLE},
            "choice_contracts": contracts,
            "baseline": spec["baseline"],
            "expected_state": [w(s, i, v) for (s, i), v in constant.items()],
            "guard_cases": guard_cases,
            "reentry": {"outcome": reentry_outcome, "message_count": base["reentry_messages"], "expected_state": reentry_expected},
            "variants": [],
            "unresolved": [],
        }
        if map_contracts:
            route["map_location_contracts"] = spent_contracts
        if nested:
            route["resume"] = {"start": call["end"], "boundary_policy": policy, "outcome": resume_outcome,
                               "message_count": resume_key[2],
                               "expected_state": [w(s, i, v) for (s, i), v in sorted(resume_constant.items())]}
            if loop is not None:
                route["resume"]["loop"] = loop
            print("  resume:", policy, resume_outcome["offset"], resume_outcome["end"], resume_outcome.get("target", ""),
                  "messages", resume_key[2], "constant", {"%s[%d]" % k: v for k, v in resume_constant.items()},
                  "varying", {"%s[%d]" % k: v for k, v in resume_varying.items()})
        selections = list(selections_base)
        if result is not None:
            selections.append({"owner_entry": callee, "boundary_offset": callee_boundary, "result_value": result})
        if bypass_rows:
            route["bypass_variants"] = []
            for b in bypass_rows:
                cells = {**{k: b["cells"][k] for k in profile_cells if k in b["cells"]}, **b["diff"]}
                route["bypass_variants"].append({
                    "variant_id": b["name"], "writes": b["writes"], "selections": selections,
                    "outcome": _outcome(caller, handoffs[caller], {"offset": b["record"]["offset"], "end": b["record"]["end"],
                                                                   "target": b["record"]["target"], "status": "script_handoff_boundary"},
                                        code, sha),
                    "message_count": b["messages"],
                    "expected_state": [w(s, i, val) for (s, i), val in sorted(cells.items())]})
                shown = ", ".join("%s[%d]: %s" % (k[0], k[1], val) for k, val in sorted(cells.items()))
                print(f"  bypass: {b['name']} leaves by {b['record']['offset']}..{b['record']['end']} ->"
                      f" {str(b['record']['target']).upper()} after {b['messages']} messages; cells {{{shown}}}")
        for r in rows:
            entry = {"variant_id": r["name"], "writes": r["writes"], "selections": selections, "message_count": r["messages"],
                     "expected_state": [w(s, i, r["cells"][(s, i)]) for (s, i) in sorted(varying)]}
            if nested:
                entry["expected_resume_state"] = [w(s, i, r["resume_effects"][(s, i)]) for (s, i) in sorted(resume_varying)]
            re_record = r["reentry_record"]
            if r["name"] != "baseline" and (r["reentry_messages"] != base["reentry_messages"] or r["reentry_diff"] != base["reentry_diff"]
                                            or (re_record["offset"], re_record["end"]) != (reentry_record["offset"], reentry_record["end"])):
                entry["reentry"] = {"outcome": _outcome(callee, handoffs[callee], re_record, code, sha),
                                    "message_count": r["reentry_messages"],
                                    "expected_state": [w(s, i, v) for (s, i), v in sorted(r["reentry_diff"].items())]}
                print("  reentry override:", r["name"], r["reentry_messages"], entry["reentry"]["expected_state"])
            route["variants"].append(entry)
        routes.append(route)

    unresolved = list(spec.get("unresolved", []))
    if args.unresolved:
        unresolved += [p.strip().replace("\n", " ") for p in Path(args.unresolved).read_text(encoding="utf-8").split("\n\n") if p.strip()]
    unresolved += [f"Measured and not declared: {n}" for n in dropped_notes]
    for route in routes:
        route["unresolved"] = unresolved
    profile = {
        "schema": schema_for(nested, policies, bool(map_contracts)),
        "group_id": spec["group_id"],
        "archive_sha256": archive_sha,
        "source_members": [{"entry": n, "entry_sha256": hashlib.sha256(payloads[n]).hexdigest()} for n in members],
        "routes": routes,
    }
    profile["payload_sha256"] = fingerprint(profile)
    out = Path(args.out)
    out.write_text(json.dumps(profile, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("wrote", out, profile["payload_sha256"], "routes", [r["route_id"] for r in routes],
          "variants", [len(r["variants"]) for r in routes], "bypasses", [len(r.get("bypass_variants", [])) for r in routes])
    return 0


RESUME_POLICIES = {
    "script_handoff_boundary": "natural_handoff",
    "def_selection_boundary": "def_selection_boundary",
    "script_dispatch_boundary": "stop_before_unprovided_dependency",
    "loop_boundary": "caller_menu_loop",
}
LOOP_ROW_STATUSES = ("dialogue_boundary", "shared_routine_boundary")


def schema_for(nested: bool, policies: set, map_contracts: bool = False) -> str:
    """v6 for a root replacement; v10 when a resume ends in the caller's own
    loop, v8 when one stops at the caller's own routine-40, v5 for the two
    handoff/dependency policies (each later schema accepts the earlier
    policies, so a mixed group takes the latest one it needs). A route that
    supplies map locations is v11 (root replacement) or v12 (continuation)."""
    if not nested:
        return "kakyu_event_analysis_group/v11" if map_contracts else "kakyu_event_analysis_group/v6"
    if map_contracts:
        return "kakyu_event_analysis_group/v12"
    if "caller_menu_loop" in policies:
        return "kakyu_event_analysis_group/v10"
    return "kakyu_event_analysis_group/v8" if "def_selection_boundary" in policies else "kakyu_event_analysis_group/v5"


MAP_LOCATION_CONTRACT_SCHEMA = "kakyu_mes_map_location_contract/v1"
MAP_LOCATION_POLL = (6, 13)


def map_location_binding(entry: str, handoff: dict, contract: dict, code: dict, sha) -> dict:
    """The declared Map.get_location poll of a member and the locations to
    supply there: an exact typed command-0x12 record whose two literal
    records are 6 and 13 (ai5-sdl2's Kakyuusei map module), the cell the
    native module writes, and the ordered locations."""
    offset = int(contract["poll_offset"])
    record = next((row for row in handoff["typed_ir"]["instructions"] if int(row.get("source_offset", -1)) == offset), None)
    if record is None or int(record.get("command_id", -1)) != 0x12:
        raise SystemExit(f"no typed command-0x12 record at the map-location poll {entry}:{offset}")
    literals = [r["value"]["ast"].get("value") for r in record["operands"][0].get("records", [])
                if r.get("type") == "expression_record"]
    if tuple(literals[:2]) != MAP_LOCATION_POLL or len(literals) != 2:
        raise SystemExit(f"the record at {entry}:{offset} is not Map.get_location (Util(6,13)): {literals}")
    locations = [int(v) for v in contract.get("locations", [])]
    if not locations or any(v < 0 or v > 0xFFFE for v in locations):
        raise SystemExit(f"map-location contract for {entry} needs locations in 0..65534")
    end = int(record["end_offset"])
    return {"schema": MAP_LOCATION_CONTRACT_SCHEMA, "source_identity": {"archive": "mes.arc", "entry": entry},
            "poll_offset": offset, "poll_end": end, "poll_function": list(MAP_LOCATION_POLL),
            "record_sha256": sha(entry, offset, end), "result_storage": "state_u16", "result_index": 18,
            "none_value": 0xFFFF, "locations": locations}


RUN_ORDER = ("prefix", "callee", "resume", "whole")


def contract_remaining(run: dict, contract: dict) -> int:
    """What a run left in this contract's queue: the per-queue row the
    0.319.0 probe reports, or - for a measurement that predates it - the
    run's total, which is exact when the route declares one contract."""
    rows = run.get("map_locations")
    if rows is None:
        return int(run.get("map_locations_remaining", 0))
    for row in rows:
        if (str(row.get("entry", "")).upper() == contract["source_identity"]["entry"]
                and int(row.get("poll_offset", -1)) == int(contract["poll_offset"])):
            return len(row.get("remaining", []))
    raise SystemExit("the measurement reports no queue for the map-location contract "
                     f"{contract['source_identity']['entry']}:{contract['poll_offset']}")


def spent_by_runs(contract: dict, chain: list, whole: dict) -> list:
    """The runs that consume from a contract's queue, in chain order. The
    segmented chain carries one queue - the prefix starts with the declared
    locations, the callee with what the prefix left, the resume with what
    the callee left - so a run consumes when it leaves fewer than it was
    given: the prefix for the caller's own arrival, the callee for a map the
    callee's dispatch walks into, the resume for a map the caller walks back
    into. The chain's last run and the unbroken run must leave nothing, or
    the declared locations are not what the route consumes."""
    before = len(contract["locations"])
    spent = []
    for name, run in chain:
        after = contract_remaining(run, contract)
        if after < before:
            spent.append(name)
        before = after
    whole_left = contract_remaining(whole, contract)
    if whole_left == 0:
        spent.append("whole")
    if whole_left != 0 or before != 0 or len(spent) < 2:
        raise SystemExit(("the declared map locations are not spent by the segmented chain and the unbroken run",
                          contract["source_identity"]["entry"], contract["poll_offset"], spent, before, whole_left))
    return spent


def loop_binding(entry: str, handoff: dict, stop: dict) -> dict:
    """The declared loop: its period, the messages one period emits and the
    cycle's records, each an exact typed record of the caller."""
    rows = {int(r["source_offset"]): r for r in handoff["typed_ir"]["instructions"]}
    cycle = []
    for row in stop.get("cycle", []):
        if str(row.get("entry", "")).upper() != entry:
            raise SystemExit(f"the caller's loop leaves the caller ({row}); that shape is not declarable")
        offset = int(row["offset"])
        record = rows.get(offset)
        status = str(row.get("status", ""))
        if record is None or status not in LOOP_ROW_STATUSES:
            raise SystemExit(f"loop segment {entry}:{offset} ({status}) is not a typed message wait or shared-routine call")
        cycle.append({"entry": entry, "offset": offset, "end": int(record["end_offset"]), "status": status})
    period = int(stop.get("period", 0))
    if period < 1 or period != len(cycle):
        raise SystemExit(f"loop period {period} does not match its {len(cycle)} cycle rows")
    return {"period": period, "period_message_count": int(stop.get("period_message_count", 0)), "cycle": cycle}


def resume_binding(entry: str, handoff: dict, stop: dict, code: dict, sha) -> tuple[str, dict]:
    """The caller-continuation policy and the resume outcome record for a measured resume stop."""
    kind = str(stop.get("kind", ""))
    if kind not in RESUME_POLICIES:
        raise SystemExit(f"the caller's resume did not stop at a boundary the schemas can name: {stop}")
    offset, end = int(stop["offset"]), int(stop["end"])
    if kind == "def_selection_boundary":
        record = next((row for row in handoff["typed_ir"]["instructions"] if int(row.get("source_offset", -1)) == offset), None)
        if record is None:
            raise SystemExit(f"no typed record at the resume's selection stop {entry}:{offset}")
        end = int(record["end_offset"])
        out = {"offset": offset, "end": end, "op": "script_transfer", "status": "def_selection_boundary", "target": "",
               "source_binding": binding_for(entry, handoff, offset, end, code[entry]), "record_sha256": sha(entry, offset, end)}
    elif kind == "loop_boundary":
        record = next((row for row in handoff["typed_ir"]["instructions"] if int(row.get("source_offset", -1)) == offset), None)
        if record is None:
            raise SystemExit(f"no typed record at the resume's loop head {entry}:{offset}")
        end = int(record["end_offset"])
        out = {"offset": offset, "end": end, "op": str(record["op"]), "status": "loop_boundary", "target": "",
               "source_binding": binding_for(entry, handoff, offset, end, code[entry]), "record_sha256": sha(entry, offset, end)}
    elif kind == "script_handoff_boundary":
        out = _outcome(entry, handoff, {"offset": offset, "end": end, "target": stop.get("target", ""),
                                        "status": "script_handoff_boundary"}, code, sha)
    else:
        out = {"offset": offset, "end": end, "op": "script_dispatch", "status": "script_dispatch_boundary",
               "target": str(stop.get("target", "")).upper(),
               "source_binding": binding_for(entry, handoff, offset, end, code[entry]), "record_sha256": sha(entry, offset, end)}
    return RESUME_POLICIES[kind], out


def _outcome(entry: str, handoff: dict, record: dict, code: dict, sha) -> dict:
    offset, end = int(record["offset"]), int(record["end"])
    status = str(record.get("status", ""))
    if status == "script_handoff_boundary":
        op = "script_handoff_marker"
    elif status == "script_return":
        op = "command_00"
    else:
        op = str(record.get("op", ""))
    out = {"offset": offset, "end": end, "op": op, "status": status,
           "source_binding": binding_for(entry, handoff, offset, end, code[entry]),
           "record_sha256": sha(entry, offset, end)}
    if status == "script_handoff_boundary":
        out["target"] = str(record.get("target", "")).upper()
    return out


if __name__ == "__main__":
    raise SystemExit(main())
