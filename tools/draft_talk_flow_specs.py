"""Draft the measurement recipe for the `?_TALK*.MES` conversation scripts of the
heroines (EP-12 TALK, owner ruling 2026-10-04), from the original archive's own
bytecode - no execution.

    py tools/draft_talk_flow_specs.py --arc "<mes.arc>" --letters K --out analysis/_undoc/ep12_talk_k/recipe.json
    py tools/draft_talk_flow_specs.py --arc "<mes.arc>" --letters A,B,C,D,E,F,G,H,I,J,K,L,M,N,O,P,Q --out <recipe.json>

The ruling (`todo/event_player.md`, EP-12): one row per called script, anchored
at the script's confirmed caller. For a heroine that is the `01M.MES` ladder
block (`docs/spec/mes/talk_family.md`): the block guard, `?_PIC`, `?_INTRO`, the
gate (the heroine's affection word above 20 and her today flag clear), the
fixed eight-rung ladder on the affection word (`< 31` ... `< 91`, then `> 90`),
`?_PROMIS`, `?_OUTRO` and a jump to the place script's shared tail. A rung is a
route (a variant cannot change a hop's outcome), so a ladder is eight routes of
one group `01m-<letter>-talk`, three hops each:

- hop 1: `01M.MES` from the block guard (the route's origin) through `?_PIC`,
  `?_INTRO`, the gate and the rung's test to the rung's nested call;
- hop 2: the rung script from its start to its return;
- hop 3: `01M.MES` resuming after the call through `?_PROMIS` (when the PROMIS flag
  the script may set is up) and `?_OUTRO` to the town handoff.

A band-less script - a heroine's plain `?_TALK.MES` (once-only, gates itself),
Tina's `M_TALK` and the characters' `N_TALK`..`Q_TALK1` - is one route of a small
group per (caller, letter) at the anchor `PLAIN_ANCHORS` records: hop 1 the caller's
guard through its picture script to the call, hop 2 the script, hop 3 the caller
resuming where it reaches a handoff (the measurer decides; a `27C_EV.MES` caller
resumes into a day loop with no natural end: two hops). A heroine's plain script is
seeded from the guard and its own once-only gate; a character's, which is a chain of
flag- and date-selected bodies, from the guard alone.

This tool finds, statically (`tools/mes_route_decode.py`'s `facts()` and the
Phase 1-4 typed IR), every record of those chains and the **seeded state** that
satisfies the block guard, the gate and the rung's test (tool decisions, labelled
in each route's `unresolved`): the place's draw `global_u8[351]` = id - 1, the
heroine's presence flag 1, her today flag and block flag 0 (the guard's own
conjuncts), the affection word in the rung's band, the calendar window (the
guard's own first alternative: weekday 0, the clock in its window), the
**natural presence state** (every topic done-flag 0, the cells the scripts clear
at entry). The recipe is the only input of
`tools/content_suite/cli/measure_talk_flow.gd`. The tool stops with a named
error (`talk shape mismatch: ...`) when a block is not that template.

For every rung script it also lists the follow-on call sites (`<L>_TALKXX.MES`,
nested) with the conditions enclosing each, so the measurer can tell an answer
arm from a flag test.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from build_event_names import HEROINE_TABLE  # noqa: E402
from mes_route_decode import Archive, facts  # noqa: E402
from payload_values import TALK_STEM, talk_script_parts  # noqa: E402

CALLER = "01M.MES"
SUPPORT_MEMBERS = ["LIBLARY.LIB", "DEF_MAIN.MES", "START.MES"]

# The heroine letter -> picker id (docs/spec/mes/talk_family.md; the ids of the
# gallery families). Every cell below is derived from the id and checked
# against the archive, never trusted.
PICKER_ID = {"F": 1, "A": 2, "E": 3, "I": 4, "G": 5, "C": 7, "H": 8, "K": 9, "L": 10, "B": 11, "J": 12, "D": 13}
BANDS = ["30", "40", "50", "60", "70", "80", "90", "00"]
RUNG_LIMITS = [31, 41, 51, 61, 71, 81, 91]  # `affection < limit`; the eighth rung is `affection > 90`
TOP_BAND_AFFECTION = 100
GATE_AFFECTION_FLOOR = 20

# The confirmed callers of the band-less scripts (EP-12 TALK, 2026-10-05): the nine
# heroines' once-only `<letter>_TALK` that gate themselves, Tina's `M_TALK` and the
# non-heroine characters' `N_TALK`..`Q_TALK1`, each a (caller, call offset) pair.
# The rule: the preferred caller is `27C_EV.MES` (the day-loop script every plain
# script has a site in, heroine K's anchor of the K unit; `01M.MES` for `M_TALK`, the
# study's anchor, and `Q_TALK`, which has no site in `27C_EV.MES`; `11M.MES`, the
# first place script, for `N_TALK2` and `N_TALK3`, which have none either) and the
# anchor is its lowest-offset site whose block is the script's own - a guard that
# encloses the call, with nothing but picture scripts dispatched between the guard
# and the call (`_plain_route` stops on a site that is not). Every row names the
# one site it anchors; the script's other sites are recorded as equivalents in
# `docs/spec/mes/talk_family.md`.
PLAIN_ANCHORS: dict[str, tuple[str, int]] = {
    "A_TALK": ("27C_EV.MES", 16416),
    "C_TALK": ("27C_EV.MES", 29752),
    "E_TALK": ("27C_EV.MES", 17697),   # 1746: the block plays N_TALK first
    "F_TALK": ("27C_EV.MES", 13077),   # 1814: the block plays N_TALK and E_TALK first
    "G_TALK": ("27C_EV.MES", 10691),
    "H_TALK": ("27C_EV.MES", 30778),
    "I_TALK": ("27C_EV.MES", 21537),   # 11661, 12390: a special-date block its own gate cannot satisfy
    "K_TALK": ("27C_EV.MES", 31343),
    "L_TALK": ("27C_EV.MES", 31922),
    "M_TALK": ("01M.MES", 47934),
    "N_TALK": ("27C_EV.MES", 1678),
    "N_TALK1": ("27C_EV.MES", 82509),
    "N_TALK2": ("11M.MES", 34692),
    "N_TALK3": ("11M.MES", 35558),
    "O_TALK": ("27C_EV.MES", 35736),
    "P_TALK": ("27C_EV.MES", 40244),
    "Q_TALK": ("01M.MES", 48530),
    "Q_TALK1": ("27C_EV.MES", 37984),
}
# The anchors whose resume after the call was measured to run into the 27C_EV.MES day loop and
# stop there with no natural end (`definition 12 stopped at definition_step_limit`): heroine K's
# (2026-10-04) and the other eleven (2026-10-05, hop 3 re-run with `resume_hop: "auto"`, not inherited
# from K's site). Their routes are two hops. Every other anchor decides by measurement (the measurer's
# `resume_hop: "auto"`): `N_TALK` (27C_EV.MES:1678) meets a question of the next block's script
# (`E_TALK`) the probe cannot answer, `N_TALK1` (27C_EV.MES:82509, the entry's last block) reaches the
# `FLOOR5.MES` handoff at 83150 (three hops), and every anchor of another caller likewise.
DAY_LOOP_ANCHORS = {
    ("27C_EV.MES", 16416),  # A_TALK
    ("27C_EV.MES", 29752),  # C_TALK
    ("27C_EV.MES", 17697),  # E_TALK
    ("27C_EV.MES", 13077),  # F_TALK
    ("27C_EV.MES", 10691),  # G_TALK
    ("27C_EV.MES", 30778),  # H_TALK
    ("27C_EV.MES", 21537),  # I_TALK
    ("27C_EV.MES", 31343),  # K_TALK
    ("27C_EV.MES", 31922),  # L_TALK
    ("27C_EV.MES", 35736),  # O_TALK
    ("27C_EV.MES", 40244),  # P_TALK
    ("27C_EV.MES", 37984),  # Q_TALK1
}
# Ambient cells no guard names: the date (`state_u16[7]`), the cell the scripts
# rewrite before reading (`state_u16[8]`) and the place's own level-0 draw
# (`global_u8[350]`, 0 satisfies the place's gate and is not evaluated by the
# route, whose origin is the block guard).
AMBIENT_DATE = 401
AMBIENT_CELLS = [("state_u16", 8, 0), ("global_u8", 350, 0)]
CLOCK_CELL = ("state_u16", 19)
WEEKDAY_CELL = ("state_u16", 4)
DATE_CELL = ("state_u16", 7)
DRAW_CELL = ("global_u8", 351)

COMPARE_OPS = {"equal", "not_equal", "greater_than", "less_than"}
NESTED_DEPTH_LIMIT = 2


class ShapeError(SystemExit):
    """A block or script does not match the template this tool reads."""

    def __init__(self, message: str):
        super().__init__(f"talk shape mismatch: {message}")


# --- the typed condition -------------------------------------------------------------------


def _branch_ast(archive: Archive, entry: str, offset: int) -> dict:
    for instruction in archive.instructions(entry):
        if int(instruction["source_offset"]) == offset and instruction.get("op") == "branch_if_not_true":
            condition = next(o["value"] for o in instruction["operands"] if o.get("type") == "condition")
            return condition.get("ast", condition)
    raise ShapeError(f"{entry}:{offset} is not a branch")


def _cell_of(node: dict) -> tuple[str, int] | None:
    if not isinstance(node, dict) or node.get("type") != "state_ref":
        return None
    index = node.get("index")
    if isinstance(index, dict):
        if index.get("type") != "literal":
            return None
        index = index.get("value")
    return (str(node.get("storage")), int(index))


def seed_atoms(node: dict, where: str) -> list[tuple[str, int, str, int]]:
    """The atoms of one satisfying choice of a condition: every conjunct of an AND,
    the first alternative of an OR, a comparison of a cell with a literal."""
    if not isinstance(node, dict) or node.get("type") != "binary":
        raise ShapeError(f"{where}: not a comparison tree")
    op = node.get("op")
    if op == "logical_and":
        return seed_atoms(node["lhs"], where) + seed_atoms(node["rhs"], where)
    if op == "logical_or":
        return seed_atoms(node["lhs"], where)
    if op not in COMPARE_OPS:
        raise ShapeError(f"{where}: unsupported operator {op}")
    cell = _cell_of(node.get("lhs"))
    rhs = node.get("rhs")
    if cell is None or not isinstance(rhs, dict) or rhs.get("type") != "literal":
        raise ShapeError(f"{where}: a comparison is not a cell against a literal")
    return [(cell[0], cell[1], str(op), int(rhs["value"]))]


def all_atoms(node: dict) -> list[tuple[str, int, str, int]]:
    """Every comparison of a cell with a literal anywhere in the condition."""
    if not isinstance(node, dict) or node.get("type") != "binary":
        return []
    if node.get("op") in ("logical_and", "logical_or"):
        return all_atoms(node["lhs"]) + all_atoms(node["rhs"])
    cell = _cell_of(node.get("lhs"))
    rhs = node.get("rhs")
    if cell is not None and isinstance(rhs, dict) and rhs.get("type") == "literal":
        return [(cell[0], cell[1], str(node.get("op")), int(rhs["value"]))]
    return []


def solve(atoms: list[tuple[str, int, str, int]], where: str) -> dict[tuple[str, int], int]:
    """One value per cell satisfying every atom (a tool decision, labelled in the
    route): an equality's value; inside a window the first full hour for the
    clock and the middle otherwise; above a bound the next multiple of 10; a
    not-equal alone the next value (0 for a nonzero test of zero)."""
    by_cell: dict[tuple[str, int], list[tuple[str, int]]] = {}
    for storage, index, op, value in atoms:
        by_cell.setdefault((storage, index), []).append((op, value))
    solved: dict[tuple[str, int], int] = {}
    for cell, constraints in by_cell.items():
        equal = [v for op, v in constraints if op == "equal"]
        if len(set(equal)) > 1:
            raise ShapeError(f"{where}: {cell} is required to equal two values")
        lo = max([v for op, v in constraints if op == "greater_than"], default=None)
        hi = min([v for op, v in constraints if op == "less_than"], default=None)
        excluded = {v for op, v in constraints if op == "not_equal"}
        if equal:
            value = equal[0]
        elif lo is not None and hi is not None:
            value = ((lo // 100) + 1) * 100 if cell == CLOCK_CELL else (lo + hi) // 2
        elif lo is not None:
            value = (lo // 10 + 1) * 10
        elif hi is not None:
            value = hi - 1
        else:
            value = 1 if 0 in excluded else 0
            while value in excluded:
                value += 1
        if (lo is not None and not value > lo) or (hi is not None and not value < hi) or value in excluded:
            raise ShapeError(f"{where}: no value of {cell} satisfies {constraints}")
        solved[cell] = value
    return solved


def _write(storage: str, index: int, value: int) -> dict:
    return {"storage": storage, "bank": 0, "index": index, "value": value}


# --- the static facts of one entry ---------------------------------------------------------


def _dispatches(rows: list[dict], target: str | None = None) -> list[dict]:
    return [r for r in rows if r["kind"] == "dispatch" and (target is None or r["target"] == target)]


def _nested_members(archive: Archive, entry: str, depth: int = 0, found: list[str] | None = None) -> list[str]:
    found = [] if found is None else found
    for row in facts(archive, entry):
        if row["kind"] != "dispatch":
            continue
        target = row["target"]
        if target not in archive.entries:
            raise ShapeError(f"{entry}:{row['offset']} nests {target}, which is not in the archive")
        if target != entry and target not in found:
            found.append(target)
            if depth < NESTED_DEPTH_LIMIT:
                _nested_members(archive, target, depth + 1, found)
    return found


def _block_members(archive: Archive, names: list[str]) -> list[str]:
    """The entries the caller's own block dispatches (`?_PIC`, `?_INTRO`, `?_PROMIS`, `?_OUTRO`)
    and, transitively, what they nest: what the measurer must load to run the block. Which of
    them a route actually runs is measured; only those become the route's source members."""
    found: list[str] = []
    for name in names:
        if name not in archive.entries:
            raise ShapeError(f"{name} is not in the archive")
        if name not in found:
            found.append(name)
        for nested in _nested_members(archive, name, 1):
            if nested not in found:
                found.append(nested)
    return found


def _follow_ons(archive: Archive, entry: str, letter: str) -> list[dict]:
    """Every follow-on call of a rung script - `<L>_TALKXX.MES` (heroines H and K) or the
    rung's own `<L>_TALK<nn>.MES` (`A_TALK51`, `B_TALK61`, ...) - with the branches enclosing
    it (offset, false target, condition, and, for a single-cell test, the cell)."""
    rows = facts(archive, entry)
    branches = [r for r in rows if r["kind"] == "branch"]
    follow_on = re.compile(rf"^{letter}_TALK(?:XX|\d\d)\.MES$")
    out = []
    for dispatch in [d for d in _dispatches(rows) if follow_on.match(d["target"]) and d["target"] != entry]:
        enclosing = []
        for branch in branches:
            if not branch["end"] <= dispatch["offset"] < branch["false_target"]:
                continue
            record = {"offset": branch["offset"], "false_target": branch["false_target"], "condition": branch["condition"]}
            if branch["condition"] != "1":
                atoms = all_atoms(_branch_ast(archive, entry, branch["offset"]))
                record["atoms"] = [{"storage": s, "index": i, "op": op, "value": v} for s, i, op, v in atoms]
            enclosing.append(record)
        out.append({"target": dispatch["target"], "offset": dispatch["offset"], "end": dispatch["end"],
                    "enclosing": enclosing})
    return out


def _return_offsets(rows: list[dict]) -> list[int]:
    return sorted(r["offset"] for r in rows if r["kind"] == "return")


# --- the ladder of one heroine in 01M.MES --------------------------------------------------


def _ladder(archive: Archive, letter: str, caller_rows: list[dict]) -> dict:
    heroine_id = PICKER_ID[letter]
    english = HEROINE_TABLE[letter][0].lower()
    affection_cell = ("banked_u16", 199 + heroine_id)
    today_cell = ("global_u8", 94 + 10 * heroine_id)
    block_cell = ("global_u8", 90 + 10 * heroine_id)
    presence_cell = ("global_u8", 390 + heroine_id if heroine_id <= 5 else 389 + heroine_id)
    branches = [r for r in caller_rows if r["kind"] == "branch"]

    rungs = []
    for band in BANDS:
        target = f"{letter}_TALK{band}.MES"
        if target not in archive.entries:
            raise ShapeError(f"{target} is not in the archive")
        found = _dispatches(caller_rows, target)
        if len(found) != 1:
            raise ShapeError(f"{CALLER} calls {target} from {len(found)} sites, expected one")
        rungs.append({"band": band, "entry": target, "dispatch": found[0]})
    offsets = [rung["dispatch"]["offset"] for rung in rungs]
    if offsets != sorted(offsets):
        raise ShapeError(f"{letter}: the eight rung calls are not in ladder order")

    # Each rung's test is the branch ending just before its call (a marker record sits between).
    tests = []
    for index, rung in enumerate(rungs):
        before = [b for b in branches if b["end"] <= rung["dispatch"]["offset"] and rung["dispatch"]["offset"] - b["end"] <= 8]
        if len(before) != 1:
            raise ShapeError(f"{letter}: no single test before the {rung['band']} call")
        test = before[0]
        atoms = all_atoms(_branch_ast(archive, CALLER, test["offset"]))
        expected = (affection_cell[0], affection_cell[1], "less_than", RUNG_LIMITS[index]) if index < 7 \
            else (affection_cell[0], affection_cell[1], "greater_than", 90)
        if atoms != [expected]:
            raise ShapeError(f"{CALLER}:{test['offset']} is not the rung test {expected}: {atoms}")
        tests.append(test)
    for current, following in zip(tests, tests[1:]):
        if current["false_target"] != following["offset"]:
            raise ShapeError(f"{CALLER}:{current['offset']} does not fall to the next rung test")

    # The gate: the branch before the first test that skips the whole ladder.
    gate_candidates = [b for b in branches if b["end"] <= tests[0]["offset"] and tests[0]["offset"] - b["end"] <= 16]
    if len(gate_candidates) != 1:
        raise ShapeError(f"{letter}: no single gate before the first rung test")
    gate = gate_candidates[0]
    gate_ast = _branch_ast(archive, CALLER, gate["offset"])
    gate_atoms = all_atoms(gate_ast)
    expected_gate = [(affection_cell[0], affection_cell[1], "greater_than", GATE_AFFECTION_FLOOR),
                     (today_cell[0], today_cell[1], "equal", 0)]
    if gate_atoms[:len(expected_gate)] != expected_gate:
        raise ShapeError(f"{CALLER}:{gate['offset']} is not the gate {expected_gate}: {gate_atoms}")
    # The gate of heroines C and J carries further conjuncts of its own (cells their blocks test
    # besides the two); each is seeded by `solve` like the guard's (an AND chain of single-cell
    # comparisons: an alternative or any other shape stops the tool).
    gate_extra = [list(a) for a in seed_atoms(gate_ast, f"{CALLER}:{gate['offset']}")[len(expected_gate):]]
    if len(seed_atoms(gate_ast, f"{CALLER}:{gate['offset']}")) != len(gate_atoms):
        raise ShapeError(f"{CALLER}:{gate['offset']}: the gate holds an alternative")
    if gate["false_target"] < rungs[-1]["dispatch"]["end"]:
        raise ShapeError(f"{CALLER}:{gate['offset']} does not skip the ladder")

    # The block around it: PIC, INTRO, the guard, PROMIS, OUTRO.
    intro = [d for d in _dispatches(caller_rows, f"{letter}_INTRO.MES") if d["end"] <= gate["offset"]]
    if not intro:
        raise ShapeError(f"{letter}: no {letter}_INTRO.MES call before the gate")
    intro = intro[-1]
    pic = [d for d in _dispatches(caller_rows, f"{letter}_PIC.MES") if d["end"] <= intro["offset"] and intro["offset"] - d["end"] < 64]
    if len(pic) != 1:
        raise ShapeError(f"{letter}: no {letter}_PIC.MES call just before {letter}_INTRO.MES")
    pic = pic[0]
    promis_candidates = [d for d in _dispatches(caller_rows, f"{letter}_PROMIS.MES") if d["offset"] > rungs[-1]["dispatch"]["end"]]
    outro_candidates = [d for d in _dispatches(caller_rows, f"{letter}_OUTRO.MES") if d["offset"] > rungs[-1]["dispatch"]["end"]]
    if not promis_candidates or not outro_candidates:
        raise ShapeError(f"{letter}: no PROMIS or OUTRO call after the ladder")
    promis, outro = promis_candidates[0], outro_candidates[0]
    promis_guard = [b for b in branches if b["end"] <= promis["offset"] and promis["offset"] - b["end"] <= 16]
    if len(promis_guard) != 1:
        raise ShapeError(f"{letter}: no single guard before {letter}_PROMIS.MES")
    promis_atoms = all_atoms(_branch_ast(archive, CALLER, promis_guard[0]["offset"]))
    if len(promis_atoms) != 1 or promis_atoms[0][:1] != ("global_u8",) or promis_atoms[0][2:] != ("equal", 1):
        raise ShapeError(f"{CALLER}:{promis_guard[0]['offset']} is not a single PROMIS flag test")
    promis_cell = ("global_u8", promis_atoms[0][1])

    guards = []
    for branch in branches:
        if branch["end"] > pic["offset"] or branch["false_target"] <= outro["end"]:
            continue
        atoms = all_atoms(_branch_ast(archive, CALLER, branch["offset"]))
        if (DRAW_CELL[0], DRAW_CELL[1], "equal", heroine_id - 1) in atoms:
            guards.append(branch)
    if not guards:
        raise ShapeError(f"{letter}: no block guard on {DRAW_CELL} == {heroine_id - 1} before {letter}_PIC.MES")
    guard = max(guards, key=lambda b: b["offset"])
    guard_ast = _branch_ast(archive, CALLER, guard["offset"])
    guard_atoms = seed_atoms(guard_ast, f"{CALLER}:{guard['offset']}")
    every_atom = all_atoms(guard_ast)
    for cell, value, name in ((presence_cell, 1, "presence flag"), (block_cell, 0, "block flag")):
        if (cell[0], cell[1], "equal", value) not in guard_atoms:
            raise ShapeError(f"{CALLER}:{guard['offset']} does not test the {name} {cell} == {value}")
    # Every arm of the guard needs the presence flag up: writing it 0 rejects the guard.
    arms_with_presence = sum(1 for a in every_atom if a[:2] == presence_cell and a[2:] == ("equal", 1))

    # Calls the block makes besides the picture, intro, rung, PROMIS and outro (heroine J's block
    # calls `J_MINORU.MES` before the outro): they run inline in hop 3 and are loaded as members.
    named = {pic["offset"], intro["offset"], promis["offset"], outro["offset"]} | {r["dispatch"]["offset"] for r in rungs}
    extra_calls = [{"offset": d["offset"], "end": d["end"], "target": d["target"]}
                   for d in _dispatches(caller_rows)
                   if guard["end"] <= d["offset"] < guard["false_target"] and d["offset"] not in named]

    return {
        "letter": letter, "name": english, "id": heroine_id,
        "cells": {"affection": list(affection_cell), "today": list(today_cell), "block": list(block_cell),
                  "presence": list(presence_cell), "promis": list(promis_cell), "draw_value": heroine_id - 1},
        "guard": {"offset": guard["offset"], "end": guard["end"], "false_target": guard["false_target"],
                  "seed_atoms": [list(a) for a in guard_atoms], "presence_tests": arms_with_presence},
        "pic": {"offset": pic["offset"], "end": pic["end"]},
        "intro": {"offset": intro["offset"], "end": intro["end"]},
        "gate": {"offset": gate["offset"], "end": gate["end"], "false_target": gate["false_target"]},
        "gate_extra_atoms": gate_extra,
        "promis": {"guard_offset": promis_guard[0]["offset"], "offset": promis["offset"], "end": promis["end"]},
        "outro": {"offset": outro["offset"], "end": outro["end"]},
        "extra_calls": extra_calls,
        "rungs": [{"band": rung["band"], "entry": rung["entry"], "test": {"offset": test["offset"], "end": test["end"],
                                                                       "false_target": test["false_target"]},
                   "dispatch": {"offset": rung["dispatch"]["offset"], "end": rung["dispatch"]["end"]}}
                  for rung, test in zip(rungs, tests)],
    }


def _intro_affection_cap(archive: Archive, letter: str, affection_cell: tuple[str, int]) -> dict | None:
    """The cap heroine C's `<L>_INTRO.MES` puts on her affection word: a branch `date < D and
    affection > A` whose body writes the affection word (`C_INTRO.MES` 241: `date < 916 and
    affection > 50` -> 50). The intro runs before the rung test, so while the cap holds no rung above
    `A` can be reached: the natural state of a rung above it is a date on which the cap is off
    (`date >= D`). `None` when the intro has none; the highest such `D` when it has several."""
    entry = f"{letter}_INTRO.MES"
    rows = facts(archive, entry)
    writes = [r for r in rows if r["kind"] == "write" and r["storage"] == affection_cell[0] and r["index"] == affection_cell[1]]
    found = None
    for branch in (r for r in rows if r["kind"] == "branch"):
        atoms = all_atoms(_branch_ast(archive, entry, branch["offset"]))
        floor = [v for s, i, op, v in atoms if (s, i, op) == (DATE_CELL[0], DATE_CELL[1], "less_than")]
        above = [v for s, i, op, v in atoms if (s, i) == affection_cell and op == "greater_than"]
        if floor and above and any(branch["end"] <= w["offset"] < branch["false_target"] for w in writes):
            if found is None or floor[0] > found["date_below"]:
                found = {"entry": entry, "offset": branch["offset"], "date_below": floor[0], "affection_above": above[0]}
    return found


def _ladder_routes(archive: Archive, letter: str, caller_rows: list[dict]) -> list[dict]:
    block = _ladder(archive, letter, caller_rows)
    english = block["name"]
    cells = block["cells"]
    guard = block["guard"]
    solved = solve([tuple(a) for a in guard["seed_atoms"]], f"{CALLER}:{guard['offset']}")
    cap = _intro_affection_cap(archive, letter, tuple(cells["affection"]))
    date = AMBIENT_DATE
    if cap is not None:
        # The rungs above the cap are reachable only on a date the intro's cap is off.
        date = max(AMBIENT_DATE, cap["date_below"])
        if DATE_CELL in solved and solved[DATE_CELL] < cap["date_below"]:
            raise ShapeError(f"{CALLER}:{guard['offset']}: the guard fixes the date {solved[DATE_CELL]}, below the intro's cap at {cap['date_below']}")
    routes = []
    for index, rung in enumerate(block["rungs"]):
        affection = TOP_BAND_AFFECTION if index == 7 else RUNG_LIMITS[index] - 6
        script_rows = facts(archive, rung["entry"])
        # Seeds in the order the audit and the flow runner apply them: the
        # ambient cells, the guard's own cells, the heroine's today flag (the
        # gate) and the affection word of the rung's band.
        baseline = [_write(CLOCK_CELL[0], CLOCK_CELL[1], solved[CLOCK_CELL]),
                    _write(DATE_CELL[0], DATE_CELL[1], date)]
        for storage, index_, value in AMBIENT_CELLS:
            baseline.append(_write(storage, index_, value))
        for cell, value in solved.items():
            if cell == CLOCK_CELL:
                continue
            baseline.append(_write(cell[0], cell[1], value))
        baseline.append(_write(cells["today"][0], cells["today"][1], 0))
        baseline.append(_write(cells["affection"][0], cells["affection"][1], affection))
        # One write per cell, in first-write order (a cell the guard and the ambient both name).
        merged: dict[tuple[str, int], dict] = {}
        for item in baseline:
            merged[(item["storage"], item["index"])] = item
        # The gate's further conjuncts (heroines C and J) are seeded after the rest; one that names a
        # cell the guard, the today flag or the band already fixed must agree with it.
        gate_solved = solve([tuple(a) for a in block["gate_extra_atoms"]], f"{CALLER}:{block['gate']['offset']}")
        for cell, value in gate_solved.items():
            if cell in merged and merged[cell]["value"] != value:
                raise ShapeError(f"{CALLER}:{block['gate']['offset']}: the gate needs {cell} = {value}, "
                                 f"the block's seeds have {merged[cell]['value']}")
            merged.setdefault(cell, _write(cell[0], cell[1], value))
        baseline = list(merged.values())
        routes.append({
            "kind": "ladder", "letter": letter, "name": english, "band": rung["band"],
            "route_id": f"{letter.lower()}-talk-{rung['band']}", "group_id": f"01m-{letter.lower()}-talk",
            "profile_stem": f"01m_{letter.lower()}_talk_v14",
            "caller": CALLER, "callee": rung["entry"],
            "origin": {"offset": guard["offset"], "guard_offset": guard["offset"], "guard_end": guard["end"],
                       "false_target": guard["false_target"]},
            "dispatch": rung["dispatch"],
            "baseline": baseline,
            "guard_rejected_writes": [_write(cells["presence"][0], cells["presence"][1], 0)],
            "affection": affection,
            "block": {"pic": block["pic"], "intro": block["intro"], "gate": block["gate"], "test": rung["test"],
                      "promis": block["promis"], "outro": block["outro"], "cells": cells,
                      "guard_presence_tests": guard["presence_tests"],
                      **({"intro_affection_cap": cap} if cap is not None else {}),
                      **({"gate_extra_atoms": block["gate_extra_atoms"]} if block["gate_extra_atoms"] else {}),
                      **({"extra_calls": block["extra_calls"]} if block["extra_calls"] else {})},
            "resume_hop": True,
            "callee_returns": _return_offsets(script_rows),
            "follow_ons": _follow_ons(archive, rung["entry"], letter),
            "callee_nested": _nested_members(archive, rung["entry"]),
            "block_members": _block_members(archive, [f"{letter}_PIC.MES", f"{letter}_INTRO.MES",
                                                      f"{letter}_PROMIS.MES", f"{letter}_OUTRO.MES"]
                                            + [call["target"] for call in block["extra_calls"]]),
        })
    return routes


# --- a band-less script at its confirmed caller --------------------------------------------


def _top_level_alternatives(node: dict) -> list[dict]:
    """The operands of the guard's top-level `logical_or` chain (the guard itself when it is none)."""
    if isinstance(node, dict) and node.get("type") == "binary" and node.get("op") == "logical_or":
        return _top_level_alternatives(node["lhs"]) + _top_level_alternatives(node["rhs"])
    return [node]


def _conjunct_atoms(node: dict) -> list[tuple[str, int, str, int]]:
    """The comparisons of a cell with a literal that every satisfying state of `node` must hold:
    the operands of its AND chain, nothing under an OR."""
    if not isinstance(node, dict) or node.get("type") != "binary":
        return []
    if node.get("op") == "logical_and":
        return _conjunct_atoms(node["lhs"]) + _conjunct_atoms(node["rhs"])
    if node.get("op") == "logical_or":
        return []
    cell = _cell_of(node.get("lhs"))
    rhs = node.get("rhs")
    if cell is not None and isinstance(rhs, dict) and rhs.get("type") == "literal":
        return [(cell[0], cell[1], str(node.get("op")), int(rhs["value"]))]
    return []


def holds(node: dict, values: dict[tuple[str, int], int], where: str) -> bool:
    """Evaluate a guard (comparisons of a cell with a literal under AND / OR) over `values`, a cell
    that is not in it reading 0 (a fresh sandbox state)."""
    if not isinstance(node, dict) or node.get("type") != "binary":
        raise ShapeError(f"{where}: not a comparison tree")
    op = node.get("op")
    if op == "logical_and":
        return holds(node["lhs"], values, where) and holds(node["rhs"], values, where)
    if op == "logical_or":
        return holds(node["lhs"], values, where) or holds(node["rhs"], values, where)
    cell = _cell_of(node.get("lhs"))
    rhs = node.get("rhs")
    if op not in COMPARE_OPS or cell is None or not isinstance(rhs, dict) or rhs.get("type") != "literal":
        raise ShapeError(f"{where}: a comparison is not a cell against a literal")
    current, literal = values.get(cell, 0), int(rhs["value"])
    return {"equal": current == literal, "not_equal": current != literal,
            "greater_than": current > literal, "less_than": current < literal}[op]


def _rejecting_write(guard_ast: dict, where: str) -> dict:
    """One write that makes the guard false: a cell that every top-level alternative of the guard
    pins with an `equal` conjunct (a pure AND chain has one alternative), written to a value none
    of them holds - preferring a `global_u8` flag tested against 0 (written 1, heroine K's own
    witness). `_prove_guard` evaluates it."""
    pinned = None
    for alternative in _top_level_alternatives(guard_ast):
        by_cell: dict[tuple[str, int], set[int]] = {}
        for storage, index, op, value in _conjunct_atoms(alternative):
            if op == "equal":
                by_cell.setdefault((storage, index), set()).add(value)
        pinned = by_cell if pinned is None else {c: pinned[c] | v for c, v in by_cell.items() if c in pinned}
    if not pinned:
        raise ShapeError(f"{where}: no cell is pinned by an `equal` conjunct in every alternative of the guard")
    flags = [c for c, v in pinned.items() if c[0] == "global_u8" and v == {0}]
    cell = (flags or list(pinned))[0]
    value = next(v for v in range(0, 65536) if v not in pinned[cell])
    return _write(cell[0], cell[1], value)


def _prove_guard(guard_ast: dict, baseline: list[dict], rejected: list[dict], where: str) -> None:
    """The seeded baseline satisfies the guard and the rejecting writes falsify it (the measurer
    runs both witnesses against the bytecode; this is the static check of the same facts)."""
    values = {(w["storage"], w["index"]): w["value"] for w in baseline}
    if not holds(guard_ast, values, where):
        raise ShapeError(f"{where}: the seeded baseline does not satisfy the guard")
    values.update({(w["storage"], w["index"]): w["value"] for w in rejected})
    if holds(guard_ast, values, where):
        raise ShapeError(f"{where}: the rejecting write does not falsify the guard")


def _plain_route(archive: Archive, stem: str) -> dict:
    """One band-less script at its anchor (`PLAIN_ANCHORS`): the heroine's once-only `<L>_TALK`
    (hop 1 the caller's block guard through its picture script to the call, hop 2 the script,
    the script's own once-only gate seeded satisfied), or a character's `M_TALK`, `N_TALK`.. (a
    chain of flag- and date-selected bodies, seeded by the guard alone: the body the state
    selects plays). Two hops where the caller resumes into a day loop with no natural end, else
    the measurer decides by running hop 3."""
    caller, site = PLAIN_ANCHORS[stem]
    callee = f"{stem}.MES"
    parts = talk_script_parts(stem)
    if parts is None or (parts[1] and parts[0] in PICKER_ID):
        raise ShapeError(f"{stem} is not a band-less TALK script")
    letter, digit = parts
    heroine = letter in PICKER_ID
    if caller not in archive.entries or callee not in archive.entries:
        raise ShapeError(f"{caller} or {callee} is not in the archive")
    english = HEROINE_TABLE[letter][0].lower() if letter in HEROINE_TABLE else "common"
    rows = facts(archive, caller)
    branches = [r for r in rows if r["kind"] == "branch"]
    dispatch = [d for d in _dispatches(rows, callee) if d["offset"] == site]
    if len(dispatch) != 1:
        raise ShapeError(f"{caller} has no call of {callee} at {site}")
    dispatch = dispatch[0]
    pics = [d for d in _dispatches(rows) if d["target"].endswith("_PIC.MES") and d["end"] <= dispatch["offset"]
            and dispatch["offset"] - d["end"] < 64]
    pic = pics[-1] if pics else None
    limit = pic["offset"] if pic else dispatch["offset"]
    enclosing = [b for b in branches if b["end"] <= limit and b["false_target"] > dispatch["end"] and b["condition"] != "1"]
    if not enclosing:
        raise ShapeError(f"{caller}: no guard encloses the call at {site}")
    guard = max(enclosing, key=lambda b: b["offset"])
    # The block is the script's own: nothing but picture scripts is dispatched between the guard and
    # the call (a block that plays another script first would run it inside hop 1).
    pre_call = [d for d in _dispatches(rows) if guard["end"] <= d["offset"] < dispatch["offset"]]
    stray = [d["target"] for d in pre_call if not d["target"].endswith("_PIC.MES")]
    if stray:
        raise ShapeError(f"{caller}:{site}: the block of the call dispatches {stray} between its guard and the call")
    guard_ast = _branch_ast(archive, caller, guard["offset"])
    guard_atoms = seed_atoms(guard_ast, f"{caller}:{guard['offset']}")

    callee_rows = facts(archive, callee)
    callee_branches = [b for b in callee_rows if b["kind"] == "branch"]
    own_gate = None
    own_atoms: list[tuple[str, int, str, int]] = []
    if heroine:
        own_gate = callee_branches[0]
        own_atoms = seed_atoms(_branch_ast(archive, callee, own_gate["offset"]), f"{callee}:{own_gate['offset']}")
    solved = solve(guard_atoms + own_atoms,
                   f"{caller}:{guard['offset']}" + (f" with {callee}:{own_gate['offset']}" if own_gate else ""))
    baseline = [_write(cell[0], cell[1], value) for cell, value in solved.items()]
    rejected = _rejecting_write(guard_ast, f"{caller}:{guard['offset']}")
    _prove_guard(guard_ast, baseline, [rejected], f"{caller}:{guard['offset']}")
    route_band = digit or "plain"
    caller_stem = caller[:-4]
    block: dict = {"guard_seed_atoms": [list(a) for a in guard_atoms]}
    if pic:
        block["pic"] = {"offset": pic["offset"], "end": pic["end"]}
    if pre_call:
        block["pre_call"] = [{"offset": d["offset"], "end": d["end"], "target": d["target"]} for d in pre_call]
    if own_gate:
        block["callee_gate"] = {"offset": own_gate["offset"], "end": own_gate["end"], "false_target": own_gate["false_target"]}
        block["callee_seed_atoms"] = [list(a) for a in own_atoms]
    return {
        "kind": "plain" if heroine else "character", "letter": letter, "name": english, "band": route_band,
        "route_id": f"{letter.lower()}-talk-{route_band}",
        "group_id": f"{caller_stem.lower().replace('_', '-')}-{letter.lower()}-talk",
        "profile_stem": f"{caller_stem.lower()}_{letter.lower()}_talk_v14",
        "caller": caller, "callee": callee,
        "origin": {"offset": guard["offset"], "guard_offset": guard["offset"], "guard_end": guard["end"],
                   "false_target": guard["false_target"]},
        "dispatch": {"offset": dispatch["offset"], "end": dispatch["end"]},
        "baseline": baseline, "guard_rejected_writes": [rejected], "affection": None,
        "block": block,
        # An anchor measured to stop in the 27C_EV.MES day loop (`DAY_LOOP_ANCHORS`): the flow ends at the
        # script's own return, like an album scene. Any other anchor: the measurer runs hop 3 and keeps it
        # when the caller reaches a handoff.
        "resume_hop": False if (caller, site) in DAY_LOOP_ANCHORS else "auto",
        "callee_returns": _return_offsets(callee_rows),
        "follow_ons": [],
        "callee_nested": _nested_members(archive, callee),
        "block_members": _block_members(archive, [d["target"] for d in pre_call]),
    }


def draft(archive: Archive, letters: list[str]) -> dict:
    caller_rows = facts(archive, CALLER)
    routes: list[dict] = []
    for letter in letters:
        if letter not in PICKER_ID and letter not in "MNOPQ":
            raise ShapeError(f"{letter} is not a TALK letter this tool knows")
        if letter in PICKER_ID:
            routes.extend(_ladder_routes(archive, letter, caller_rows))
        for stem in PLAIN_ANCHORS:
            parts = talk_script_parts(stem)
            if parts is not None and parts[0] == letter:
                routes.append(_plain_route(archive, stem))
    return {"archive_sha256": archive.sha, "support_members": SUPPORT_MEMBERS, "routes": routes}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--arc", type=Path, required=True)
    parser.add_argument("--letters", default="K", help="TALK letters, e.g. K or A,B,K (heroines A..L, Tina M, characters N..Q)")
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    letters = [part.strip().upper() for part in args.letters.split(",") if part.strip()]
    recipe = draft(Archive(args.arc), letters)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(recipe, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")
    print(json.dumps({"ok": True, "out": str(args.out), "routes": len(recipe["routes"]),
                      "ladder_routes": sum(1 for r in recipe["routes"] if r["kind"] == "ladder"),
                      "plain_routes": sum(1 for r in recipe["routes"] if r["kind"] == "plain"),
                      "character_routes": sum(1 for r in recipe["routes"] if r["kind"] == "character")}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
