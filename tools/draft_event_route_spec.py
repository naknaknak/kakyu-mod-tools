"""Draft a route spec (JSON) and a review sheet (Markdown) for one EVENT intro site.

    py tools/draft_event_route_spec.py --arc "<mes.arc>" --group-measure analysis/19c_group_measure.json \
        --callee EVENTL05.MES --route 19c_l05 --out-dir analysis

Reads the caller inventory (`analysis/<caller>_group_measure.json`, produced by
the group-measure builders) for the intro's guard and call record, decodes the
caller's gap and the whole callee with `mes_route_decode`, and derives
mechanically what a route sheet used to state by hand: the package, the
baseline seed satisfying every conjunct, one witness per conjunct edge, and
the variant list (guard edges, presentation arms, the callee's own free
branches and counters). It never runs Godot. The spec is the single input of
`tools/content_suite/cli/measure_event_route.gd` and
`tools/build_event_route_profile.py`; the sheet is for review only.

Conjuncts the drafter cannot turn into a seed (a cell compared with another
cell, an arithmetic expression) are listed under `notes` with a "manual seed"
marker and the spec's `baseline` must be completed by hand before measuring.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from mes_route_decode import (AFFECTION_RANGE, Archive, conjuncts, facts, format_fact,  # noqa: E402
                              summarize_callee)
from payload_values import map_location_poll  # noqa: E402

CALENDAR_CELLS = [0, 1, 2, 4, 7, 10, 19, 25]
CORE_MEMBERS = ["START.MES", "DEF_MAIN.MES", "LIBLARY.LIB"]
PRESENTATION_VARIANTS = [
    ("global_u8_2847-1", "global_u8", 2847, 1),
    ("global_u8_3006-1", "global_u8", 3006, 1),
    ("callee-state_u16_8-1", "state_u16", 8, 1),
    ("callee-global_u8_4000-1", "global_u8", 4000, 1),
]


def w(storage: str, index: int, value: int) -> dict:
    return {"storage": storage, "bank": 0, "index": index, "value": value}


def _cell_name(storage: str, index: int) -> str:
    if storage == "state_u16" and index == 4:
        return "weekday"
    if storage == "state_u16" and index == 7:
        return "date"
    if storage == "state_u16" and index == 19:
        return "clock"
    if storage == "banked_u16" and index in AFFECTION_RANGE:
        return f"word{index}"
    if storage == "banked_u16":
        return f"banked{index}"
    return f"{storage}-{index}"


def _simple(ast: dict) -> tuple | None:
    """(storage, index, op, literal) for `cell OP literal` / `literal OP cell`, else None."""
    if not isinstance(ast, dict) or ast.get("type") != "binary":
        return None
    lhs, rhs, op = ast.get("lhs"), ast.get("rhs"), ast.get("op")
    flip = {"greater_than": "less_than", "less_than": "greater_than", "equal": "equal", "not_equal": "not_equal"}

    def cell(node):
        if isinstance(node, dict) and node.get("type") == "state_ref":
            index = node.get("index")
            if isinstance(index, dict) and index.get("type") == "literal":
                index = index.get("value")
            if not isinstance(index, dict):
                return node.get("storage"), int(index)
        return None

    def literal(node):
        return node.get("value") if isinstance(node, dict) and node.get("type") == "literal" else None
    if cell(lhs) is not None and literal(rhs) is not None:
        return (*cell(lhs), op, int(literal(rhs)))
    if cell(rhs) is not None and literal(lhs) is not None and op in flip:
        return (*cell(rhs), flip[op], int(literal(lhs)))
    return None


def _or_arms(ast: dict) -> list[dict]:
    if isinstance(ast, dict) and ast.get("type") == "binary" and ast.get("op") == "logical_or":
        return _or_arms(ast["lhs"]) + _or_arms(ast["rhs"])
    return [ast]


def _and_parts(ast: dict) -> list[dict]:
    if isinstance(ast, dict) and ast.get("type") == "binary" and ast.get("op") == "logical_and":
        return _and_parts(ast["lhs"]) + _and_parts(ast["rhs"])
    return [ast]


def derive_guard(parts: list[dict]) -> dict:
    """Seeds, witnesses and edge variants from the guard's top-level conjuncts."""
    ranges: dict[tuple, dict] = {}
    equals: dict[tuple, int] = {}
    not_equals: dict[tuple, list[int]] = {}
    notes: list[str] = []
    or_groups: list[list[list[tuple]]] = []
    for part in parts:
        arms = _or_arms(part["ast"])
        if len(arms) > 1:
            group = []
            for arm in arms:
                simple = [_simple(a) for a in _and_parts(arm)]
                if any(s is None for s in simple):
                    notes.append(f"manual seed: `or` arm not simple: {part['text']}")
                    group = []
                    break
                group.append(simple)
            if group:
                or_groups.append(group)
            continue
        simple = _simple(part["ast"])
        if simple is None:
            notes.append(f"manual seed: {part['text']}")
            continue
        storage, index, op, value = simple
        key = (storage, index)
        if op == "equal":
            equals[key] = value
        elif op == "not_equal":
            not_equals.setdefault(key, []).append(value)
        elif op == "greater_than":
            ranges.setdefault(key, {})["lo"] = value
        elif op == "less_than":
            ranges.setdefault(key, {})["hi"] = value
    baseline: dict[tuple, int] = {}
    witnesses: list[dict] = []
    edges: list[tuple] = []
    for key, value in equals.items():
        baseline[key] = value
        name = _cell_name(*key)
        other = {("state_u16", 4): 6 if value == 0 else 0}.get(key, 0 if value != 0 else 1)
        witnesses.append({"case_id": f"{name}-{other}", "writes": [w(*key, other)], "note": "reject"})
    for key, values in not_equals.items():
        name = _cell_name(*key)
        baseline.setdefault(key, 0 if 0 not in values else 5)
        for value in values:
            witnesses.append({"case_id": f"{name}-{value}", "writes": [w(*key, value)], "note": "reject"})
    for key, bounds in ranges.items():
        name = _cell_name(*key)
        lo, hi = bounds.get("lo"), bounds.get("hi")
        if lo is not None and hi is not None:
            mid = _midpoint(key, lo, hi)
            baseline[key] = mid
            witnesses += [{"case_id": f"{name}-{lo}", "writes": [w(*key, lo)], "note": "reject"},
                          {"case_id": f"{name}-{lo + 1}", "writes": [w(*key, lo + 1)], "note": "accept"},
                          {"case_id": f"{name}-{hi - 1}", "writes": [w(*key, hi - 1)], "note": "accept"},
                          {"case_id": f"{name}-{hi}", "writes": [w(*key, hi)], "note": "reject"}]
            edges += [(f"{name}-{lo + 1}", key, lo + 1), (f"{name}-{hi - 1}", key, hi - 1)]
        elif lo is not None:
            baseline[key] = lo + 10
            witnesses += [{"case_id": f"{name}-{lo}", "writes": [w(*key, lo)], "note": "reject"},
                          {"case_id": f"{name}-{lo + 1}", "writes": [w(*key, lo + 1)], "note": "accept"}]
            far = 200 if key[0] == "banked_u16" else lo + 100
            edges += [(f"{name}-{lo + 1}", key, lo + 1), (f"{name}-{far}", key, far)]
        else:
            baseline[key] = max(hi - 10, 0)
            witnesses += [{"case_id": f"{name}-{hi - 1}", "writes": [w(*key, hi - 1)], "note": "accept"},
                          {"case_id": f"{name}-{hi}", "writes": [w(*key, hi)], "note": "reject"}]
            edges += [(f"{name}-{hi - 1}", key, hi - 1), (f"{name}-0", key, 0)]
    for group in or_groups:
        # Seed the first arm; witness each arm's edges with the other arms false.
        for arm_index, arm in enumerate(group):
            arm_ranges: dict[tuple, dict] = {}
            for storage, index, op, value in arm:
                key = (storage, index)
                if op == "equal":
                    arm_ranges.setdefault(key, {})["eq"] = value
                elif op == "greater_than":
                    arm_ranges.setdefault(key, {})["lo"] = value
                elif op == "less_than":
                    arm_ranges.setdefault(key, {})["hi"] = value
            for key, bounds in arm_ranges.items():
                name = _cell_name(*key)
                if "eq" in bounds:
                    if arm_index == 0:
                        baseline.setdefault(key, bounds["eq"])
                    witnesses.append({"case_id": f"{name}-{bounds['eq']}-or{arm_index}", "writes": [w(*key, bounds["eq"])],
                                      "note": "accept if the other arms' cells hold their baseline"})
                    continue
                lo, hi = bounds.get("lo"), bounds.get("hi")
                if lo is not None and hi is not None:
                    if arm_index == 0:
                        baseline.setdefault(key, _midpoint(key, lo, hi))
                    witnesses += [{"case_id": f"{name}-{lo}", "writes": [w(*key, lo)], "note": "reject (or arm edge)"},
                                  {"case_id": f"{name}-{lo + 1}", "writes": [w(*key, lo + 1)], "note": "accept"},
                                  {"case_id": f"{name}-{hi - 1}", "writes": [w(*key, hi - 1)], "note": "accept"},
                                  {"case_id": f"{name}-{hi}", "writes": [w(*key, hi)], "note": "reject (or arm edge)"}]
                    edges += [(f"{name}-{lo + 1}", key, lo + 1), (f"{name}-{hi - 1}", key, hi - 1)]
    return {"baseline": baseline, "witnesses": witnesses, "edges": edges, "notes": notes}


def _midpoint(key: tuple, lo: int, hi: int) -> int:
    storage, index = key
    if storage == "state_u16" and index in (7, 19):
        # MMDD / HHMM: pick a valid value near the middle.
        span = list(range(lo + 1, hi))
        valid = [v for v in span if (index == 7 and 1 <= v % 100 <= 28 and 1 <= v // 100 <= 15)
                 or (index == 19 and v % 100 <= 59)]
        return valid[len(valid) // 2] if valid else (lo + hi) // 2
    return (lo + hi) // 2


def _callee_question(callee_summary: dict, question_offset: int | None) -> dict | None:
    """The callee's own routine-40 question and the definitions it owns.

    A callee with one routine-40 keeps the original behaviour (the only site,
    every definition_invoke in the callee - unchanged for every existing
    caller). A callee with more than one routine-40 (EP-12 PROMIS: an earlier
    own-menu selector feeding a field the later commit selector reads) needs
    `question_offset` to say which site is "the" question the group answers;
    its definitions are scoped to the span after the previous routine-40 (if
    any) up to the selected one, so an earlier menu's definitions are not
    misattributed to it.
    """
    routines = callee_summary["question"]["routine40"]
    if not routines:
        return None
    if question_offset is None:
        site = routines[0]
        lo = 0
    else:
        ordered = sorted(routines, key=lambda r: r["offset"])
        site = next((r for r in ordered if r["offset"] == question_offset), None)
        if site is None:
            raise SystemExit(f"no routine-40 at {question_offset}; found {[r['offset'] for r in ordered]}")
        earlier = [r["end"] for r in ordered if r["offset"] < question_offset]
        lo = max(earlier) if earlier else 0
    definitions = [d for d in callee_summary["question"]["definitions"] if lo <= d < site["offset"]]
    prefix = [r["offset"] for r in routines if r["offset"] < site["offset"]] if question_offset is not None else []
    return {"routine40": site["offset"], "definitions": definitions, "prefix_routine40": prefix}


def draft(archive: Archive, group_measure: dict, callee: str, route: str, guard_offset: int | None,
          check_name: str | None, question_offset: int | None = None) -> dict:
    caller = group_measure["caller"]
    intro = next(i for i in group_measure["intros"] if i["target"].upper() == callee.upper())
    guards = intro["guards"]
    guard = next((g for g in guards if guard_offset is None and g["conjunct_count"] > 1) or
                 (g for g in guards if g["offset"] == guard_offset), None) if guards else None
    if guard is None:
        guard = guards[0] if guards else None
    dispatch = intro["dispatch"]
    call = {"offset": dispatch["offset"], "end": dispatch["end"], "command": dispatch["command"], "kind": dispatch["kind"]}
    callee_summary = summarize_callee(archive, callee)
    parts = conjuncts(archive, caller, guard["offset"]) if guard else []
    derived = derive_guard(parts)
    gap = facts(archive, caller, guard["end"] if guard else 0, call["offset"]) if guard else []
    gap_writes = [f for f in gap if f["kind"] == "write" and f["storage"] in ("global_u8", "state_u16", "banked_u16")
                  and not (f["storage"] == "banked_u16" and f["index"] in (1, 2))
                  and not (f["storage"] == "global_u8" and f["index"] is not None and f["index"] <= 20)]
    gap_branches = [f for f in gap if f["kind"] == "branch"]
    gap_dispatches = [f for f in gap if f["kind"] == "dispatch"]
    gap_questions = [f for f in gap if f["kind"] == "routine" and f["routine"] == 40]
    guard_cells = sorted({tuple(c) for p in parts for c in p["cells"]})

    baseline = dict(derived["baseline"])
    baseline.setdefault(("state_u16", 0), 0)
    baseline.setdefault(("state_u16", 1), 13)
    baseline.setdefault(("state_u16", 5), 0)
    baseline.setdefault(("state_u16", 21), 0)
    baseline.setdefault(("banked_u16", 242), 0)
    baseline.setdefault(("banked_u16", 2), 0)
    for cell in [("global_u8", 2847), ("global_u8", 3006), ("global_u8", 4000)]:
        baseline.setdefault(cell, 0)
    # Cells the callee's own gate and counters read: seed them at 0 so the body runs.
    if callee_summary["gate"]:
        for storage, index in callee_summary["gate"]["cells"]:
            baseline.setdefault((storage, index), 0)
    for counter in callee_summary["counters"]:
        if counter["index"] is not None:
            baseline.setdefault((counter["storage"], counter["index"]), 0)
    watch = set(guard_cells)
    for wr in callee_summary["affection_writes"] + callee_summary["stamp_writes"] + callee_summary["other_banked_writes"]:
        if wr["index"] is not None:
            watch.add((wr["storage"], wr["index"]))
    for wr in gap_writes:
        if wr["index"] is not None and wr["storage"] in ("global_u8", "banked_u16", "state_u16"):
            watch.add((wr["storage"], wr["index"]))

    variants: list[dict] = []
    for name, key, value in derived["edges"]:
        variants.append({"variant_id": name, "writes": [w(*key, value)]})
    for name, storage, index, value in PRESENTATION_VARIANTS:
        variants.append({"variant_id": name, "writes": [w(storage, index, value)]})
    notes = list(derived["notes"])
    for branch in callee_summary["free_branches"]:
        for storage, index in branch["cells"]:
            if (storage, index) in baseline and (storage, index) not in guard_cells:
                continue
            notes.append(f"callee reads {storage}[{index}] at {branch['offset']}: {branch['condition']} - add a variant per arm")
        simple = [_simple(a) for a in _and_parts(branch.get("ast", {}))] if "ast" in branch else []
    for counter in callee_summary["counters"]:
        if counter["index"] is not None and counter["storage"] == "global_u8":
            variants.append({"variant_id": f"{counter['storage']}_{counter['index']}-5",
                             "writes": [w(counter["storage"], counter["index"], 5)]})
    for arm in callee_summary["free_branches"]:
        for cell in arm["cells"]:
            key = tuple(cell)
            match = re.search(rf"{re.escape(cell[0])}\[{cell[1]}\] (greater_than|less_than) (\d+)", arm["condition"])
            if match and key not in guard_cells:
                op, value = match.group(1), int(match.group(2))
                lo_v, hi_v = (value, value + 1) if op == "greater_than" else (value - 1, value)
                for v in (lo_v, hi_v):
                    variants.append({"variant_id": f"{_cell_name(*key)}-{v}", "writes": [w(*key, v)]})
                baseline.setdefault(key, hi_v if op == "greater_than" else lo_v)
            elif match and key in guard_cells:
                op, value = match.group(1), int(match.group(2))
                lo_v, hi_v = (value, value + 1) if op == "greater_than" else (value - 1, value)
                for v in (lo_v, hi_v):
                    variants.append({"variant_id": f"{_cell_name(*key)}-{v}-direct", "writes": [w(*key, v)], "direct": True,
                                     "note": "the callee's own gate on a guard cell, measured directly from the prefix state"})
    seen = set()
    unique_variants = []
    for v in variants:
        if v["variant_id"] in seen:
            continue
        seen.add(v["variant_id"])
        unique_variants.append(v)

    members = [caller, callee]
    for d in gap_dispatches + callee_summary["dispatches"]:
        if d["target"] and d["target"] not in members:
            members.append(d["target"])
    for door in callee_summary["doors"]:
        if door["target"] and door["target"] not in members:
            members.append(door["target"])
    members += [m for m in CORE_MEMBERS if m not in members]

    doors = callee_summary["doors"]
    form = "root_handoff" if call["command"] == 14 else "nested_call"
    cq = _callee_question(callee_summary, question_offset)
    spec = {
        "schema": "kakyu_event_route_spec/v1",
        "route": route,
        "group_id": route.replace("_", "-"),
        "check_name": check_name or route.upper().replace("_", " "),
        "caller": caller,
        "callee": callee.upper(),
        "members": members,
        "form": form,
        "origin": guard["offset"] if guard else None,
        "guard": {"offset": guard["offset"], "end": guard["end"], "false_target": guard["false_target"],
                  "conjuncts": [p["text"] for p in parts], "cells": [list(c) for c in guard_cells]} if guard else None,
        "call": call,
        "gap": {"writes": [format_fact(f) for f in gap_writes], "branches": [format_fact(f) for f in gap_branches],
                "dispatches": [format_fact(f) for f in gap_dispatches],
                "questions": [f["offset"] for f in gap_questions]},
        "door": {"offset": doors[0]["offset"], "end": doors[0]["end"], "target": doors[0]["target"]} if len(doors) == 1 else None,
        "doors": [{"offset": d["offset"], "end": d["end"], "target": d["target"]} for d in doors],
        "callee_gate": {"offset": callee_summary["gate"]["offset"], "false_target": callee_summary["gate"]["false_target"],
                        "cells": callee_summary["gate"]["cells"],
                        "own_writes": [x["offset"] for x in callee_summary["own_gate_writes"]]} if callee_summary["gate"] else None,
        "callee_question": {k: v for k, v in (cq or {}).items() if k != "prefix_routine40"} if cq else None,
        "callee_prefix_choices": [{"boundary": off, "result_value": 3,
                                   "note": "the routine-40 consumer answers by one-based registration position, not"
                                           " by definition id (kakyu_mes_routine40_choice_contract/v5); position 3 is"
                                           " the third-lowest offered id. Sandbox-replayed for A_PROMIS.MES:2221"
                                           " (EP-12): position 1 (id 0) plays its own dialogue then loops back to"
                                           " the same menu with id 0 now hidden rather than reaching the declared"
                                           " question - a native mapping this unit could not establish further, so"
                                           " it is avoided rather than answered again; positions 3 and 13 (ids 2 and"
                                           " 13) each reach the declared question in one pass. Position 3/id 2"
                                           " matches the archive's own already-Confirmed 'location 2' controller-"
                                           " integration baseline (all ten time options accept it) when ids 0-2 are"
                                           " contiguous, as measured for A; verify per group and change if another"
                                           " answer is wanted or id 2 is itself hidden."}
                                  for off in (cq or {}).get("prefix_routine40", [])],
        "caller_question": {"routine40": gap_questions[0]["offset"]} if gap_questions else None,
        "caller_choice": ({"boundary": gap_questions[0]["offset"], "result_value": 1,
                           "note": "the answer that hands off; change if the handoff sits under another answer"}
                          if gap_questions else None),
        "baseline": [w(s, i, v) for (s, i), v in sorted(baseline.items())],
        "guard_cases": [{"case_id": "baseline", "writes": [], "note": "accept"}] + derived["witnesses"],
        "variants": unique_variants,
        "calendar_cells": CALENDAR_CELLS,
        "guard_cells": [list(c) for c in guard_cells],
        "watch_cells": [list(c) for c in sorted(watch)],
        "callee_summary": {k: v for k, v in callee_summary.items() if k not in ("gate",)},
        "map_location_contracts": [],
        "notes": notes,
        "unresolved": [],
    }
    for member in members:
        for offset in map_location_polls(archive, member):
            notes.append(f"MAP LOCATION POLL: {member}:{offset} is Map.get_location (Util(6,13)); if the walk enters it,"
                         f" add {{entry, poll_offset, locations}} to map_location_contracts")
    return spec


# The search signature is the record itself, built from the typed-record grammar
# (`payload_values.map_location_poll`, `Util(6,13)`): a search needs the bytes, and
# a decoded-instruction match could differ from the raw find (WD-25 item 1b, G).
MAP_LOCATION_POLL_BYTES = map_location_poll()


def map_location_polls(archive, entry: str) -> list:
    """Offsets of every Map.get_location record (Util(6,13)) in a member's bytecode."""
    try:
        code = archive.code(entry)
    except Exception:  # noqa: BLE001 - a member without bytecode has no polls
        return []
    if not code:
        return []
    found, start = [], 0
    while True:
        at = code.find(MAP_LOCATION_POLL_BYTES, start)
        if at < 0:
            return found
        found.append(at)
        start = at + 1


def render_sheet(spec: dict) -> str:
    lines = [f"# Route spec review: {spec['caller']} / {spec['callee']} ({spec['route']})", ""]
    g = spec["guard"]
    if g:
        lines.append(f"ORIGIN = GUARD {g['offset']}..{g['end']} (false {g['false_target']}), {len(g['conjuncts'])} conjuncts:")
        lines += [f"  - {c}" for c in g["conjuncts"]]
    else:
        lines.append("ORIGIN: NO TYPED GUARD - owner question")
    c = spec["call"]
    lines.append(f"CALL {c['offset']}..{c['end']} command {c['command']} ({spec['form']})")
    if spec["form"] == "nested_call":
        lines.append(f"  NESTED CALL: the callee returns and the caller resumes at {c['end']}; the measured resume stop"
                     " picks the policy (root handoff -> v5 natural_handoff, the caller's own routine-40 -> v8"
                     " def_selection_boundary, the caller's own loop -> v10 caller_menu_loop);"
                     " scripts the resume reaches are added to members by the driver")
    gap = spec["gap"]
    lines.append(f"Gap: {len(gap['branches'])} branches, {len(gap['dispatches'])} dispatches, {len(gap['writes'])} writes, questions {gap['questions']}")
    lines += [f"  {x}" for x in gap["writes"] + gap["branches"] + gap["dispatches"]]
    cs = spec["callee_summary"]
    lines.append(f"Callee {spec['callee']}: {cs['code_size']} bytes, {cs['branches']} branches; opaque tails {[(t['source_offset'], t['end_offset']) for t in cs['opaque_tails']]}")
    if spec["callee_gate"]:
        lines.append(f"  gate at {spec['callee_gate']['offset']} on {spec['callee_gate']['cells']} (false {spec['callee_gate']['false_target']}), own writes at {spec['callee_gate']['own_writes']}")
    else:
        lines.append("  NO DONE-GATE: a direct reentry replays the body (G14 shape)")
    if spec["callee_question"]:
        lines.append(f"  QUESTION: routine-40 at {spec['callee_question']['routine40']}, definitions {spec['callee_question']['definitions']} (tier B - one route per answer)")
    if spec.get("callee_prefix_choices"):
        lines.append(f"  PREFIX CHOICES (earlier, undeclared routine-40 sites answered fixed): {spec['callee_prefix_choices']}")
    if spec["caller_question"]:
        lines.append(f"  CALLER QUESTION in the gap at {spec['caller_question']['routine40']} (tier C - the caller's contract; set spec.caller_choice)")
    lines.append(f"  doors: {spec['doors']}")
    lines.append(f"  dispatches: {[format_fact(d) for d in cs['dispatches']]}")
    lines.append(f"  affection writes: {[format_fact(x) for x in cs['affection_writes']]}")
    lines.append(f"  stamp: {[format_fact(x) for x in cs['stamp_writes']]}; other banked: {[format_fact(x) for x in cs['other_banked_writes']]}")
    lines.append(f"  counters: {[format_fact(x) for x in cs['counters']]}")
    lines.append(f"  free branches: {[(b['offset'], b['condition']) for b in cs['free_branches']]}")
    lines.append(f"  global_u8 writes: {[format_fact(x) for x in cs['global_u8_writes']]}")
    lines.append(f"Members: {spec['members']}")
    lines.append("Baseline: " + ", ".join(f"{b['storage']}[{b['index']}]={b['value']}" for b in spec["baseline"]))
    lines.append(f"Witnesses ({len(spec['guard_cases'])}): " + ", ".join(f"{x['case_id']} ({x.get('note', '')})" for x in spec["guard_cases"]))
    lines.append(f"Variants ({len(spec['variants'])}): " + ", ".join(v["variant_id"] + (" [direct]" if v.get("direct") else "") for v in spec["variants"]))
    if spec["notes"]:
        lines.append("NOTES (need a hand):")
        lines += [f"  - {n}" for n in spec["notes"]]
    return "\n".join(lines) + "\n"


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--arc", required=True)
    parser.add_argument("--group-measure", required=True)
    parser.add_argument("--callee", required=True)
    parser.add_argument("--route", required=True, help="file stem, e.g. 19c_l05")
    parser.add_argument("--guard", type=int, default=None, help="guard offset when the inventory lists several")
    parser.add_argument("--check-name", default=None)
    parser.add_argument("--out-dir", default="analysis")
    parser.add_argument("--question-offset", type=int, default=None,
                        help="which routine-40 is the group's own question, when the callee has more than one")
    args = parser.parse_args(argv)
    archive = Archive(Path(args.arc))
    group_measure = json.loads(Path(args.group_measure).read_text(encoding="utf-8"))
    spec = draft(archive, group_measure, args.callee.upper(), args.route, args.guard, args.check_name,
                args.question_offset)
    out_dir = Path(args.out_dir)
    spec_path = out_dir / f"{args.route}_spec.json"
    sheet_path = out_dir / f"{args.route}_sheet.md"
    spec_path.write_text(json.dumps(spec, indent=1, ensure_ascii=False) + "\n", encoding="utf-8")
    sheet_path.write_text(render_sheet(spec), encoding="utf-8")
    print(render_sheet(spec))
    print("wrote", spec_path, "and", sheet_path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
