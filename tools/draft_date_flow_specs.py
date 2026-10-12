"""Draft a kakyu_event_analysis_group/v14 flow measurement recipe for one
heroine's promise date (EP-12, `01m-<letter>-date`), from the original
archive's own bytecode - no execution.

    py tools/draft_date_flow_specs.py --arc "<mes.arc>" --letter B --out analysis/_undoc/ep12_b_flow_recipe.json

Static discovery only (`tools/mes_route_decode.py`'s `facts()`/`conjuncts()`
against the Phase 1-4 typed IR): finds the heroine's own date guard branch in
`01M.MES` (the conjunct on `state_u16[7] == banked_u16[<promise_field>]`),
the ten shared-prefix dispatch coordinates that follow it in file order
(`?_PIC`, `?_DATE1`, `DENSHA`, `?_TIME`, `YABAI`, `?_DATE2`, `?_PIC`,
`?_DATE7`, `?_PIC`, `?_DATE3`), the town-route tail (`?_DATE4` dispatch +
`MACHI.MES` handoff), `?_DATE3.MES`'s own two routine-40 sites and their
3-case elif chains, the date5 gate's own affection-banded elif chain (its
last, topmost band), the hotel gate's own affection ladder (its own last
threshold before the first-visit check) and money gate, its two
`definition_invoke` sites (17 then 11), and the hotel chain
(`?_HOTEL.MES`'s routine-40 + 6-case chain, `?_HOTEL1.MES`'s and
`?_HOTEL2.MES`'s own single handoffs). Cross-checked, not re-derived, against
the per-heroine table this task's own reports already measured:
`tools/content_suite/validators/validate_event_player_promise_dates.gd`'s
`CASES` (promise field/location field) and
`analysis/_undoc/ep12_hotel_report.md`'s per-heroine table (affection cell,
DATE3->HOTEL guard #1 state_u16[21] value, guard #2 hotel flag).

The recipe this tool writes is `tools/content_suite/cli/measure_date_flow.gd`'s
only input; that tool runs each hop through the real archive and writes the
three `build_event_flow_profile.py` spec files plus a measurement report. If
a search finds zero or more than one candidate where exactly one is expected,
this tool stops with an error naming the ambiguity instead of guessing.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from mes_route_decode import Archive, facts  # noqa: E402
from build_event_route_profile import map_location_binding  # noqa: E402
from mes_analyzer_handoff import build_container  # noqa: E402

# Cited from validate_event_player_promise_dates.gd's CASES table (promise
# field / promise-time field / location field) and
# analysis/_undoc/ep12_hotel_report.md's per-heroine table (affection cell,
# the DATE3->HOTEL guard #1 state_u16[21] value, and guard #2's hotel flag).
# All twelve heroines are populated (A and B this family's template unit;
# C..L this family's later batch unit, EP-12).
HEROINE_TABLE = {
    "A": {"promise_field": 215, "location_field": 119, "affection_cell": 201,
          "hotel_state21_value": 3, "hotel_flag": 992},
    "B": {"promise_field": 233, "location_field": 209, "affection_cell": 210,
          "hotel_state21_value": 3, "hotel_flag": 664},
    "C": {"promise_field": 225, "location_field": 169, "affection_cell": 206,
          "hotel_state21_value": 3, "hotel_flag": 1651},
    "D": {"promise_field": 237, "location_field": 229, "affection_cell": 212,
          "hotel_state21_value": 3, "hotel_flag": 676},
    "E": {"promise_field": 217, "location_field": 129, "affection_cell": 202,
          "hotel_state21_value": 2, "hotel_flag": 1790},
    "F": {"promise_field": 213, "location_field": 109, "affection_cell": 200,
          "hotel_state21_value": 3, "hotel_flag": 1502},
    "G": {"promise_field": 221, "location_field": 149, "affection_cell": 204,
          "hotel_state21_value": 1, "hotel_flag": 1362},
    "H": {"promise_field": 227, "location_field": 179, "affection_cell": 207,
          "hotel_state21_value": 3, "hotel_flag": 2081},
    "I": {"promise_field": 219, "location_field": 139, "affection_cell": 203,
          "hotel_state21_value": 2, "hotel_flag": 1217},
    "J": {"promise_field": 235, "location_field": 219, "affection_cell": 211,
          "hotel_state21_value": 1, "hotel_flag": 782},
    "K": {"promise_field": 229, "location_field": 189, "affection_cell": 208,
          "hotel_state21_value": 3, "hotel_flag": 2182},
    "L": {"promise_field": 231, "location_field": 199, "affection_cell": 209,
          "hotel_state21_value": 1, "hotel_flag": 1923},
}

SHARED_DISPATCH_TARGETS = ["{H}_PIC.MES", "{H}_DATE1.MES", "DENSHA.MES", "{H}_TIME.MES",
                           "YABAI.MES", "{H}_DATE2.MES", "{H}_PIC.MES", "{H}_DATE7.MES",
                           "{H}_PIC.MES", "{H}_DATE3.MES"]
TRAIN_CONTRACT = {"entry": "TRAIN.MES", "poll_offset": 886, "result_storage": "state_u16",
                  "result_index": 18, "values": [0, 1]}
DEF17_POLL = {"definition": 17, "poll_offset": 4222, "entry": "DEF_MAIN.MES",
              "result_storage": "state_u16", "result_index": 18, "value": 0}


def _find_guard(archive: Archive, promise_field: int) -> dict:
    hits = [row for row in facts(archive, "01M.MES")
            if row["kind"] == "branch" and any(c[0] == "banked_u16" and c[1] == promise_field for c in row["cells"])]
    if len(hits) != 1:
        raise SystemExit(f"expected exactly one 01M.MES guard branch on banked_u16[{promise_field}], found {len(hits)}")
    row = hits[0]
    cells = {tuple(c) for c in row["cells"]}
    guard_flags = sorted(c for c in cells if c[0] == "global_u8" and c[1] not in ())
    return {"offset": row["offset"], "end": row["end"], "false_target": row["false_target"], "cells": row["cells"]}


def _find_shared_dispatches(archive: Archive, guard_end: int, letter: str) -> list[dict]:
    targets = [t.format(H=letter) for t in SHARED_DISPATCH_TARGETS]
    rows = [row for row in facts(archive, "01M.MES", guard_end, guard_end + 3000) if row["kind"] == "dispatch"]
    found = []
    cursor = 0
    for target in targets:
        match = next((row for row in rows if row["offset"] >= cursor and row["target"] == target), None)
        if match is None:
            raise SystemExit(f"could not find shared dispatch to {target} after offset {cursor} in 01M.MES")
        found.append({"offset": match["offset"], "end": match["end"], "target": target})
        cursor = match["end"]
    return found


def _find_town_tail(archive: Archive, after: int, letter: str) -> dict:
    date4 = f"{letter}_DATE4.MES"
    rows = [row for row in facts(archive, "01M.MES", after, after + 1000) if row["kind"] in ("dispatch", "handoff")]
    dispatch = next((row for row in rows if row["kind"] == "dispatch" and row["target"] == date4), None)
    if dispatch is None:
        raise SystemExit(f"could not find the town-route dispatch to {date4} in 01M.MES after {after}")
    handoff = next((row for row in rows if row["kind"] == "handoff" and row["offset"] > dispatch["end"]
                     and row["target"] == "MACHI.MES"), None)
    if handoff is None:
        raise SystemExit("could not find the town-route MACHI.MES handoff in 01M.MES")
    return {"dispatch": {"offset": dispatch["offset"], "end": dispatch["end"], "target": date4},
            "handoff": {"offset": handoff["offset"], "end": handoff["end"], "target": "MACHI.MES"}}


def _routine40_sites(archive: Archive, entry: str) -> list[int]:
    return [row["offset"] for row in facts(archive, entry) if row["kind"] == "routine" and row.get("routine") == 40]


def _case_chain(archive: Archive, entry: str, start: int) -> dict:
    """The 3-case `state_u16[21] equal N` elif chain immediately following a
    routine-40 site at `start`."""
    rows = [row for row in facts(archive, entry, start) if row["kind"] == "branch"
            and any(c[0] == "state_u16" and c[1] == 21 for c in row["cells"])]
    chain = []
    cursor = start
    for _ in range(3):
        row = next((r for r in rows if r["offset"] >= cursor), None)
        if row is None:
            raise SystemExit(f"{entry}: expected a 3-case state_u16[21] elif chain from {start}, found {len(chain)}")
        chain.append({"offset": row["offset"], "end": row["end"], "false_target": row["false_target"]})
        cursor = row["end"]
    return {"case1": chain[0], "case2": chain[1], "case3": chain[2]}


def _town_terminal(archive: Archive, entry: str, case1: dict) -> dict:
    """Case 1's own body: a short scene ending at a plain `script_return`,
    reached by the same jump-chasing a human reader would do. The jump's own
    target is not always the return record's own offset directly - some
    heroines (D, E, F, K) land a few bytes short, on a plain write/routine
    pair that falls straight through into the return a short distance later
    (a cosmetic difference from A/B/C/G/H/I/J/L, not a different shape); take
    the nearest return at or after the jump target within a small window."""
    jump_rows = {row["offset"]: row for row in facts(archive, entry, case1["offset"], case1["false_target"])
                 if row["kind"] == "jump"}
    returns = {row["offset"]: row for row in facts(archive, entry) if row["kind"] == "return"}
    # Case 1's body typically ends in one jump to the shared plain return; take
    # the last jump in its own body range and follow it once.
    if not jump_rows:
        raise SystemExit(f"{entry}: case 1's own body holds no jump to a shared return")
    last_jump = jump_rows[max(jump_rows)]
    target = last_jump["target"]
    if target in returns:
        return {"offset": target, "end": returns[target]["end"]}
    candidates = sorted(o for o in returns if target <= o < target + 64)
    if not candidates:
        raise SystemExit(f"{entry}: case 1's own jump target {target} does not fall through to a script_return")
    landing = candidates[0]
    return {"offset": landing, "end": returns[landing]["end"]}


def _affection_ladder(archive: Archive, entry: str, lo: int, hi: int, affection_cell: int) -> list[dict]:
    return [row for row in facts(archive, entry, lo, hi) if row["kind"] == "branch"
            and any(c[0] == "banked_u16" and c[1] == affection_cell for c in row["cells"])
            and "less_than" in row["condition"]]


def _date5_gate(archive: Archive, entry: str, case2: dict, affection_cell: int) -> dict:
    ladder = _affection_ladder(archive, entry, case2["offset"], case2["false_target"], affection_cell)
    if not ladder:
        raise SystemExit(f"{entry}: case 2's own body holds no banked_u16[{affection_cell}] affection ladder")
    handoffs = [row for row in facts(archive, entry, case2["offset"], case2["false_target"])
                if row["kind"] == "handoff" and row["target"].endswith("_DATE5.MES")]
    if not handoffs:
        raise SystemExit(f"{entry}: case 2's own body holds no handoff to a DATE5 entry")
    last_band = ladder[-1]
    last_handoff = handoffs[-1]
    threshold = int(last_band["condition"].split("less_than ")[1].rstrip(")"))
    return {"threshold": threshold, "seed_value": threshold + 20,
            "handoff": {"offset": last_handoff["offset"], "end": last_handoff["end"], "target": last_handoff["target"]}}


def _hotel_gate(archive: Archive, entry: str, case3: dict, affection_cell: int, hotel_flag: int) -> dict:
    # The return-visit shortcut near the top of case 3's body also references
    # the hotel flag (`== 1`, short-circuited by state_u16[12] < 150); the
    # real first-visit gate is the *last* `global_u8[flag] equal 0` branch in
    # the case's own body, reached only after the whole affection ladder.
    candidates = [row for row in facts(archive, entry, case3["offset"], case3["false_target"])
                  if row["kind"] == "branch" and f"global_u8[{hotel_flag}] equal 0" in row["condition"]]
    if not candidates:
        raise SystemExit(f"{entry}: case 3's own body holds no global_u8[{hotel_flag}]==0 first-visit gate")
    first_visit = candidates[-1]
    ladder = _affection_ladder(archive, entry, case3["offset"], first_visit["offset"], affection_cell)
    if not ladder:
        raise SystemExit(f"{entry}: case 3's own body holds no banked_u16[{affection_cell}] affection ladder")
    threshold = int(ladder[-1]["condition"].split("less_than ")[1].rstrip(")"))
    return {"threshold": threshold, "seed_value": threshold + 20, "first_visit_gate": first_visit}


def _second_question(archive: Archive, entry: str, after: int, hotel_state21_value: int) -> dict:
    sites = [o for o in _routine40_sites(archive, entry) if o >= after]
    if len(sites) != 1:
        raise SystemExit(f"{entry}: expected exactly one second routine-40 site after {after}, found {len(sites)}")
    boundary = sites[0]
    chain = _case_chain(archive, entry, boundary)
    hotel_case = next((c for c in chain.values() if c is not None
                        and hotel_state21_value == list(chain.values()).index(c) + 1), None)
    # Map the declared hotel value (1/2/3) directly to its own case slot.
    case_key = f"case{hotel_state21_value}"
    hotel_case = chain[case_key]
    # Present for A/B/C/D/F/H/K; five heroines' own hotel case bodies (E, G,
    # I, J, L) carry no `state_u16[12]` money gate at all (confirmed by a
    # full branch dump of each - a genuine structural absence, not a search
    # miss) - the gate is optional, not a fixed part of the shape.
    money = next((row for row in facts(archive, entry, hotel_case["offset"], hotel_case["false_target"])
                 if row["kind"] == "branch" and "state_u16[12] less_than" in row["condition"]), None)
    money_threshold = None if money is None else int(money["condition"].split("less_than ")[1].rstrip(")"))
    invokes = [ins for ins in archive.instructions(entry) if ins["op"] == "definition_invoke"
               and hotel_case["offset"] <= ins["source_offset"] < hotel_case["false_target"]]
    if len(invokes) < 2:
        raise SystemExit(f"{entry}: the hotel case's own body holds fewer than 2 definition_invoke sites")
    handoff = next((row for row in facts(archive, entry, invokes[-1]["source_offset"], hotel_case["false_target"])
                    if row["kind"] == "handoff" and row["target"].endswith("_HOTEL.MES")), None)
    if handoff is None:
        raise SystemExit(f"{entry}: the hotel case's own body holds no handoff to a HOTEL entry")
    return {"boundary": boundary, "chain": chain, "money_threshold": money_threshold,
            "def17_offset": invokes[0]["source_offset"], "def11_offset": invokes[1]["source_offset"],
            "handoff": {"offset": handoff["offset"], "end": handoff["end"], "target": handoff["target"]}}


def _hotel2_terminal(archive: Archive, hotel2: str) -> dict:
    """`?_HOTEL2.MES`'s own terminal under baseline execution: the first
    handoff in file order. Nine heroines (A, B, C, D, F, G, H, J, K) reach it
    unconditionally; L's own richer structure (a later 4-case switch with
    further MACHI.MES/43C.MES sites this measurement does not reach) also
    resolves to an earlier, unconditional handoff this way (to `44C.MES`,
    not `MACHI.MES` - the outcome vocabulary still classifies it, since a
    route's terminal need not be a map handoff). E and I gate their own
    first handoff behind one more routine-40 (2 options; case 1's own body
    holds that first handoff) - `choice_boundary` names the site so the
    caller can answer it, per the task's own "first value the choice
    contract offers" policy for a question with no route policy."""
    handoffs = sorted((row for row in facts(archive, hotel2) if row["kind"] == "handoff"),
                       key=lambda r: r["offset"])
    if not handoffs:
        raise SystemExit(f"{hotel2}: no handoff found")
    first = handoffs[0]
    prior_r40 = [o for o in _routine40_sites(archive, hotel2) if o < first["offset"]]
    return {"offset": first["offset"], "end": first["end"], "target": first["target"],
            "choice_boundary": max(prior_r40) if prior_r40 else None}


def _hotel_chain(archive: Archive, letter: str) -> dict:
    hotel = f"{letter}_HOTEL.MES"
    hotel1 = f"{letter}_HOTEL1.MES"
    hotel2 = f"{letter}_HOTEL2.MES"
    gate = next((row for row in facts(archive, hotel) if row["kind"] == "branch"
                and any(c[0] == "global_u8" and c[1] == 3004 for c in row["cells"])), None)
    if gate is None:
        raise SystemExit(f"{hotel}: no global_u8[3004] site-selector branch found")
    # The two mutually-exclusive routine-40 sites the gate selects between
    # (baseline: global_u8[3004] == 0, the site strictly inside the gate's
    # own true-branch range). E and I carry one further, later routine-40
    # elsewhere in the file (an unrelated side question, per
    # analysis/_undoc/ep12_hotel_report.md's Q2) that this scan must not
    # pick up as the site selector.
    sites = _routine40_sites(archive, hotel)
    boundary = next((o for o in sites if gate["offset"] < o < gate["false_target"]), None)
    if boundary is None:
        raise SystemExit(f"{hotel}: no routine-40 site found inside the global_u8[3004] gate's true branch")
    chain = _case_chain(archive, hotel, boundary)
    handoff = next((row for row in facts(archive, hotel, chain["case3"]["end"])
                    if row["kind"] == "handoff" and row["target"] == hotel1), None)
    if handoff is None:
        raise SystemExit(f"{hotel}: no handoff to {hotel1} found after its own 6-case chain")
    h1_handoffs = [row for row in facts(archive, hotel1) if row["kind"] == "handoff" and row["target"] == hotel2]
    if len(h1_handoffs) != 1:
        raise SystemExit(f"{hotel1}: expected exactly one handoff to {hotel2}, found {len(h1_handoffs)}")
    hotel2_terminal = _hotel2_terminal(archive, hotel2)
    return {"hotel_entry": hotel, "hotel1_entry": hotel1, "hotel2_entry": hotel2,
            "hotel_boundary": boundary, "hotel1_handoff": {"offset": h1_handoffs[0]["offset"], "end": h1_handoffs[0]["end"]},
            "hotel2_handoff": {"offset": hotel2_terminal["offset"], "end": hotel2_terminal["end"],
                                "target": hotel2_terminal["target"]},
            "hotel2_choice_boundary": hotel2_terminal["choice_boundary"]}


def draft(archive: Archive, letter: str) -> dict:
    params = HEROINE_TABLE[letter]
    guard = _find_guard(archive, params["promise_field"])
    shared = _find_shared_dispatches(archive, guard["end"], letter)
    time_sites = _routine40_sites(archive, f"{letter}_TIME.MES")
    if len(time_sites) != 1:
        raise SystemExit(f"{letter}_TIME.MES: expected exactly one routine-40 site, found {len(time_sites)}")
    town_tail = _find_town_tail(archive, shared[-1]["end"], letter)
    date3 = f"{letter}_DATE3.MES"
    q1_sites = _routine40_sites(archive, date3)
    if len(q1_sites) < 1:
        raise SystemExit(f"{date3}: no routine-40 sites found")
    q1_boundary = min(q1_sites)
    q1_chain = _case_chain(archive, date3, q1_boundary)
    town = _town_terminal(archive, date3, q1_chain["case1"])
    date5 = _date5_gate(archive, date3, q1_chain["case2"], params["affection_cell"])
    hotel_gate = _hotel_gate(archive, date3, q1_chain["case3"], params["affection_cell"], params["hotel_flag"])
    q2 = _second_question(archive, date3, hotel_gate["first_visit_gate"]["offset"], params["hotel_state21_value"])
    hotel_chain = _hotel_chain(archive, letter)
    return {
        "letter": letter, "archive_sha256": archive.sha, "params": params,
        "guard": guard, "shared_dispatches": shared, "town_tail": town_tail,
        "date3_entry": date3, "q1_boundary": q1_boundary, "q1_chain": q1_chain,
        "town_terminal": town, "date5_gate": date5, "hotel_first_question_gate": hotel_gate,
        "q2": q2, "hotel_chain": hotel_chain, "time_boundary": time_sites[0],
        "train_contract": TRAIN_CONTRACT, "def17_poll": DEF17_POLL,
        "train_map_location_contract": _train_map_location_contract(archive),
    }


def _train_map_location_contract(archive: Archive) -> dict:
    """The real `kakyu_mes_map_location_contract/v1` binding for TRAIN.MES's
    own `Map.get_location` poll (shared/heroine-independent), built the same
    way `build_event_route_profile.py`'s own v11/v12 groups build it - not a
    hand-written dict - so a v14 hop's `map_locations` field is exactly what
    the runtime flow validator (`Probe.map_location_queues`) expects."""
    handoff = archive.handoff("TRAIN.MES")
    code = build_container(archive.entries["TRAIN.MES"])["_bytecode"]
    contract = {"entry": "TRAIN.MES", "poll_offset": TRAIN_CONTRACT["poll_offset"], "locations": TRAIN_CONTRACT["values"]}
    return map_location_binding("TRAIN.MES", handoff, contract, code,
                                 lambda entry, offset, end: __import__("hashlib").sha256(code[offset:end]).hexdigest())


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--arc", type=Path, required=True)
    parser.add_argument("--letter", required=True, choices=sorted(HEROINE_TABLE))
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    archive = Archive(args.arc)
    recipe = draft(archive, args.letter)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(recipe, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"ok": True, "out": str(args.out), "letter": args.letter,
                       "guard_offset": recipe["guard"]["offset"]}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
