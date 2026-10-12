"""Tests for `tools/draft_talk_flow_specs.py` (EP-12 TALK, 2026-10-04) on a synthetic
`01M.MES` ladder block and a synthetic plain-script caller - no archive, no Godot."""
from __future__ import annotations

import sys
import unittest
import unittest.mock
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

import draft_talk_flow_specs as drafter  # noqa: E402


def literal(value):
    return {"type": "literal", "value": value}


def cell(storage, index):
    return {"type": "state_ref", "storage": storage, "bank": 0, "index": literal(index)}


def compare(op, storage, index, value):
    return {"type": "binary", "op": op, "lhs": cell(storage, index), "rhs": literal(value)}


def conj(*operands):
    out = operands[0]
    for operand in operands[1:]:
        out = {"type": "binary", "op": "logical_and", "lhs": out, "rhs": operand}
    return out


def disj(*operands):
    out = operands[0]
    for operand in operands[1:]:
        out = {"type": "binary", "op": "logical_or", "lhs": out, "rhs": operand}
    return out


def branch(offset, end, ast, false_target):
    return {"source_offset": offset, "end_offset": end, "op": "branch_if_not_true",
            "operands": [{"type": "condition", "value": {"ast": ast}}, {"type": "code_offset", "value": false_target}]}


def dispatch(offset, end, target):
    return {"source_offset": offset, "end_offset": end, "op": "script_dispatch",
            "operands": [{"records": [{"value": {"raw_bytes": {"$packed_byte_array_hex": target.lower().encode().hex()}}}]}]}


def plain(offset, end, op):
    return {"source_offset": offset, "end_offset": end, "op": op, "operands": []}


class FakeArchive:
    """Just what `draft` reads: `sha`, `entries` and `instructions(entry)`."""

    sha = "ef" * 32

    def __init__(self, instructions):
        self._instructions = instructions
        self.entries = {name: b"" for name in instructions}

    def instructions(self, entry):
        return self._instructions[entry]


# K is picker id 9: affection banked_u16[208], draw [351] == 8, presence [398], block flag [180],
# today flag [184], PROMIS flag [2200].
LIMITS = [31, 41, 51, 61, 71, 81, 91]
BANDS = ["30", "40", "50", "60", "70", "80", "90", "00"]
GUARD = 1000


def block_guard(draw=8):
    first = conj(disj(compare("equal", "state_u16", 4, 0), compare("equal", "state_u16", 7, 1224)),
                 compare("greater_than", "state_u16", 19, 1100), compare("less_than", "state_u16", 19, 1801),
                 compare("equal", "global_u8", 351, draw), compare("equal", "global_u8", 398, 1),
                 compare("equal", "global_u8", 180, 0))
    second = conj(compare("equal", "state_u16", 4, 6), compare("greater_than", "state_u16", 19, 1500),
                  compare("less_than", "state_u16", 19, 1801), compare("equal", "global_u8", 351, draw),
                  compare("equal", "global_u8", 398, 1), compare("equal", "global_u8", 180, 0))
    return disj(first, second)


def caller_instructions(draw=8, limits=LIMITS, gate_floor=20, skip_rung=None, extra_site=None, gate_extra=(),
                        extra_call=None):
    gate = conj(compare("greater_than", "banked_u16", 208, gate_floor), compare("equal", "global_u8", 184, 0),
                *[compare("equal", "global_u8", index, value) for index, value in gate_extra])
    rows = [branch(GUARD, GUARD + 90, block_guard(draw), 9000),
            dispatch(1110, 1123, "K_PIC.MES"), dispatch(1130, 1145, "K_INTRO.MES"),
            branch(1180, 1195, gate, 3000)]
    offset = 1200
    for index, band in enumerate(BANDS):
        test = (compare("less_than", "banked_u16", 208, limits[index]) if index < 7
                else compare("greater_than", "banked_u16", 208, 90))
        rows.append(branch(offset, offset + 13, test, offset + 44 if index < 7 else 1600))
        if band != skip_rung:
            rows.append(dispatch(offset + 18, offset + 34, f"K_TALK{band}.MES"))
        offset += 44
    if extra_site is not None:
        rows.append(dispatch(extra_site, extra_site + 16, "K_TALK50.MES"))
    rows += [branch(1600, 1611, compare("equal", "global_u8", 2200, 1), 1700),
             dispatch(1620, 1636, "K_PROMIS.MES"), dispatch(1700, 1715, "K_OUTRO.MES"),
             plain(1800, 1801, "command_00")]
    if extra_call is not None:
        rows.append(dispatch(1680, 1695, extra_call))
    return sorted(rows, key=lambda r: r["source_offset"])


def talk_script(follow_on=False, numbered_follow_on=None):
    rows = [plain(7, 8, "command_00"), branch(588, 600, literal(1), 4000)]
    if numbered_follow_on:
        rows += [branch(1395, 1405, compare("equal", "state_u16", 21, 1), 3000), dispatch(2120, 2135, numbered_follow_on)]
    if follow_on:
        rows += [branch(1395, 1405, compare("equal", "state_u16", 21, 1), 3000),
                 branch(2097, 2108, compare("equal", "global_u8", 2194, 0), 2150),
                 dispatch(2120, 2135, "K_TALKXX.MES")]
    rows.append(plain(4000, 4001, "command_00"))
    return sorted(rows, key=lambda r: r["source_offset"])


def archive(numbered_follow_on=None, **caller_options):
    instructions = {"01M.MES": caller_instructions(**caller_options)}
    for band in BANDS:
        instructions[f"K_TALK{band}.MES"] = talk_script(follow_on=band in ("50", "90"),
                                                         numbered_follow_on=numbered_follow_on if band == "60" else None)
    for name in ("K_PIC", "K_INTRO", "K_PROMIS", "K_OUTRO", "K_TALKXX", "K_TALK61", "K_MINORU"):
        instructions[f"{name}.MES"] = [plain(7, 8, "command_00")]
    # The plain script's caller: the block guard, the picture, the call.
    instructions["27C_EV.MES"] = sorted([
        branch(31225, 31268, conj(compare("equal", "global_u8", 180, 0), compare("not_equal", "global_u8", 188, 0),
                                  compare("equal", "global_u8", 184, 0), compare("equal", "global_u8", 185, 0),
                                  compare("equal", "global_u8", 2225, 0), compare("greater_than", "banked_u16", 208, 30)), 31804),
        dispatch(31325, 31338, "K_PIC.MES"), dispatch(31343, 31357, "K_TALK.MES")], key=lambda r: r["source_offset"])
    instructions["K_TALK.MES"] = sorted([
        plain(7, 8, "command_00"),
        branch(229, 255, conj(compare("greater_than", "state_u16", 7, 1423), compare("greater_than", "banked_u16", 208, 70),
                              compare("equal", "global_u8", 2538, 0)), 1368), plain(1357, 1358, "command_00")],
        key=lambda r: r["source_offset"])
    return FakeArchive(instructions)


def route_by_id(recipe, route_id):
    return next(route for route in recipe["routes"] if route["route_id"] == route_id)


class SolveTests(unittest.TestCase):
    def test_equality_window_bound_and_not_equal(self):
        atoms = [("state_u16", 4, "equal", 0), ("state_u16", 19, "greater_than", 1100), ("state_u16", 19, "less_than", 1801),
                 ("global_u8", 188, "not_equal", 0), ("banked_u16", 208, "greater_than", 70), ("global_u8", 7, "equal", 3),
                 ("state_u16", 7, "greater_than", 1423), ("global_u8", 9, "not_equal", 5)]
        solved = drafter.solve(atoms, "test")
        self.assertEqual(solved[("state_u16", 4)], 0)
        self.assertEqual(solved[("state_u16", 19)], 1200)          # the first full hour inside the clock window
        self.assertEqual(solved[("global_u8", 188)], 1)            # a nonzero test of zero
        self.assertEqual(solved[("banked_u16", 208)], 80)          # the next multiple of ten above the bound
        self.assertEqual(solved[("global_u8", 7)], 3)
        self.assertEqual(solved[("state_u16", 7)], 1430)
        self.assertEqual(solved[("global_u8", 9)], 0)

    def test_contradictory_atoms_stop_the_tool(self):
        with self.assertRaises(SystemExit):
            drafter.solve([("global_u8", 1, "equal", 0), ("global_u8", 1, "equal", 1)], "test")
        with self.assertRaises(SystemExit):
            drafter.solve([("global_u8", 1, "greater_than", 10), ("global_u8", 1, "less_than", 5)], "test")

    def test_the_first_alternative_of_an_or_and_every_conjunct(self):
        ast = conj(disj(compare("equal", "state_u16", 4, 0), compare("equal", "state_u16", 7, 1224)),
                   compare("equal", "global_u8", 351, 8))
        self.assertEqual(drafter.seed_atoms(ast, "t"), [("state_u16", 4, "equal", 0), ("global_u8", 351, "equal", 8)])
        self.assertEqual(len(drafter.all_atoms(ast)), 3)


class LadderDraftTests(unittest.TestCase):
    def setUp(self):
        self.recipe = drafter.draft(archive(), ["K"])

    def test_one_group_of_eight_rungs_and_one_plain_route(self):
        ids = [route["route_id"] for route in self.recipe["routes"]]
        self.assertEqual(ids, [f"k-talk-{band}" for band in BANDS] + ["k-talk-plain"])
        ladder = [route for route in self.recipe["routes"] if route["kind"] == "ladder"]
        self.assertEqual({route["group_id"] for route in ladder}, {"01m-k-talk"})
        self.assertEqual({route["profile_stem"] for route in ladder}, {"01m_k_talk_v14"})
        self.assertTrue(all(route["resume_hop"] for route in ladder))
        plain_route = route_by_id(self.recipe, "k-talk-plain")
        self.assertEqual((plain_route["group_id"], plain_route["profile_stem"]), ("27c-ev-k-talk", "27c_ev_k_talk_v14"))
        self.assertFalse(plain_route["resume_hop"])

    def test_the_origin_is_the_block_guard_and_the_dispatch_is_the_rungs_call(self):
        route = route_by_id(self.recipe, "k-talk-30")
        self.assertEqual(route["origin"], {"offset": GUARD, "guard_offset": GUARD, "guard_end": GUARD + 90, "false_target": 9000})
        self.assertEqual(route["dispatch"], {"offset": 1218, "end": 1234})
        self.assertEqual(route["callee"], "K_TALK30.MES")
        self.assertEqual(route_by_id(self.recipe, "k-talk-00")["dispatch"], {"offset": 1200 + 7 * 44 + 18, "end": 1200 + 7 * 44 + 34})

    def test_the_seeded_state_is_the_guards_first_alternative_and_the_rungs_band(self):
        route = route_by_id(self.recipe, "k-talk-30")
        cells = {(w["storage"], w["index"]): w["value"] for w in route["baseline"]}
        self.assertEqual(cells[("state_u16", 4)], 0)
        self.assertEqual(cells[("state_u16", 19)], 1200)
        self.assertEqual(cells[("global_u8", 351)], 8)
        self.assertEqual(cells[("global_u8", 398)], 1)            # the natural presence state
        self.assertEqual(cells[("global_u8", 180)], 0)
        self.assertEqual(cells[("global_u8", 184)], 0)            # the gate's today flag
        self.assertEqual(len(route["baseline"]), len(cells), "one write per cell")
        affections = [{(w["storage"], w["index"]): w["value"] for w in route_by_id(self.recipe, f"k-talk-{band}")["baseline"]}[("banked_u16", 208)]
                      for band in BANDS]
        self.assertEqual(affections, [25, 35, 45, 55, 65, 75, 85, 100])
        self.assertEqual(route["guard_rejected_writes"], [{"storage": "global_u8", "bank": 0, "index": 398, "value": 0}])

    def test_follow_on_calls_carry_their_enclosing_conditions(self):
        self.assertEqual(route_by_id(self.recipe, "k-talk-30")["follow_ons"], [])
        follow = route_by_id(self.recipe, "k-talk-50")["follow_ons"]
        self.assertEqual(len(follow), 1)
        self.assertEqual(follow[0]["offset"], 2120)
        self.assertEqual([e["offset"] for e in follow[0]["enclosing"]], [588, 1395, 2097])
        self.assertNotIn("atoms", follow[0]["enclosing"][0])
        self.assertEqual(follow[0]["enclosing"][1]["atoms"], [{"storage": "state_u16", "index": 21, "op": "equal", "value": 1}])
        self.assertEqual(follow[0]["enclosing"][2]["atoms"], [{"storage": "global_u8", "index": 2194, "op": "equal", "value": 0}])
        self.assertEqual(route_by_id(self.recipe, "k-talk-50")["callee_nested"], ["K_TALKXX.MES"])

    def test_the_block_members_are_the_calls_of_the_caller_block(self):
        route = route_by_id(self.recipe, "k-talk-30")
        self.assertEqual(route["block_members"], ["K_PIC.MES", "K_INTRO.MES", "K_PROMIS.MES", "K_OUTRO.MES"])
        self.assertEqual(route["block"]["promis"], {"guard_offset": 1600, "offset": 1620, "end": 1636})
        self.assertEqual(route["block"]["cells"]["promis"], ["global_u8", 2200])

    def test_the_plain_route_solves_the_callers_guard_with_the_scripts_own_gate(self):
        route = route_by_id(self.recipe, "k-talk-plain")
        cells = {(w["storage"], w["index"]): w["value"] for w in route["baseline"]}
        self.assertEqual(cells[("global_u8", 188)], 1)
        self.assertEqual(cells[("banked_u16", 208)], 80)          # above 30 (the guard) and 70 (the script's gate)
        self.assertEqual(cells[("state_u16", 7)], 1430)
        self.assertEqual(cells[("global_u8", 2538)], 0)
        self.assertEqual(route["origin"], {"offset": 31225, "guard_offset": 31225, "guard_end": 31268, "false_target": 31804})
        self.assertEqual(route["dispatch"], {"offset": 31343, "end": 31357})
        self.assertEqual(route["guard_rejected_writes"], [{"storage": "global_u8", "bank": 0, "index": 180, "value": 1}])
        self.assertEqual(route["callee_returns"], [7, 1357])


class LadderGeneralisationTests(unittest.TestCase):
    """EP-12 TALK (2026-10-05): the gate of heroines C and J has further conjuncts, J's block makes
    a call of its own, a rung may call a numbered follow-on."""

    def test_the_gates_further_conjuncts_are_seeded_and_recorded(self):
        recipe = drafter.draft(archive(gate_extra=((1775, 0), (824, 0), (398, 1))), ["K"])
        route = route_by_id(recipe, "k-talk-30")
        cells = {(w["storage"], w["index"]): w["value"] for w in route["baseline"]}
        self.assertEqual((cells[("global_u8", 1775)], cells[("global_u8", 824)], cells[("global_u8", 398)]), (0, 0, 1))
        self.assertEqual(len(route["baseline"]), len(cells), "one write per cell")
        self.assertEqual(route["block"]["gate_extra_atoms"],
                         [["global_u8", 1775, "equal", 0], ["global_u8", 824, "equal", 0], ["global_u8", 398, "equal", 1]])
        # Heroine K's own gate has none: its recipe carries no such key.
        self.assertNotIn("gate_extra_atoms", route_by_id(drafter.draft(archive(), ["K"]), "k-talk-30")["block"])

    def test_a_gate_conjunct_that_contradicts_the_blocks_seeds_stops(self):
        with self.assertRaises(SystemExit) as caught:
            drafter.draft(archive(gate_extra=((398, 0),)), ["K"])   # the guard needs the presence flag 1
        self.assertIn("the gate needs", str(caught.exception))

    def test_a_call_the_block_makes_is_loaded_with_the_block(self):
        recipe = drafter.draft(archive(extra_call="K_MINORU.MES"), ["K"])
        route = route_by_id(recipe, "k-talk-30")
        self.assertEqual(route["block"]["extra_calls"], [{"offset": 1680, "end": 1695, "target": "K_MINORU.MES"}])
        self.assertEqual(route["block_members"], ["K_PIC.MES", "K_INTRO.MES", "K_PROMIS.MES", "K_OUTRO.MES", "K_MINORU.MES"])

    def test_an_intro_that_caps_the_affection_word_moves_the_date_off_the_cap(self):
        # Heroine C's `C_INTRO.MES` 241: `date < 916 and affection > 50` -> the word is written 50, before
        # the rung test runs: a rung above 50 is reachable only from a date the cap is off.
        arc = archive()
        cap_write = {"source_offset": 261, "end_offset": 270, "op": "banked_u16_write_run",
                     "operands": [{"type": "u16_index", "value": 208},
                                  {"type": "expression_byte_pairs", "pairs": [{"expression": literal(50)}]}]}
        arc._instructions["K_INTRO.MES"] = [plain(7, 8, "command_00"),
                                            branch(241, 261, conj(compare("less_than", "state_u16", 7, 916),
                                                                  compare("greater_than", "banked_u16", 208, 50)), 300),
                                            cap_write]
        recipe = drafter.draft(arc, ["K"])
        for band in BANDS:
            route = route_by_id(recipe, f"k-talk-{band}")
            cells = {(w["storage"], w["index"]): w["value"] for w in route["baseline"]}
            self.assertEqual(cells[("state_u16", 7)], 916, band)
            self.assertEqual(route["block"]["intro_affection_cap"],
                             {"entry": "K_INTRO.MES", "offset": 241, "date_below": 916, "affection_above": 50})
        # No cap, no key, and the date stays the ambient 401.
        plain_route = route_by_id(drafter.draft(archive(), ["K"]), "k-talk-60")
        self.assertNotIn("intro_affection_cap", plain_route["block"])
        self.assertEqual({(w["storage"], w["index"]): w["value"] for w in plain_route["baseline"]}[("state_u16", 7)], 401)
        # A branch that writes another cell, or has no date bound, is not the cap.
        arc._instructions["K_INTRO.MES"] = [branch(241, 261, compare("greater_than", "banked_u16", 208, 50), 300), cap_write]
        self.assertNotIn("intro_affection_cap", route_by_id(drafter.draft(arc, ["K"]), "k-talk-60")["block"])

    def test_a_numbered_follow_on_is_a_follow_on(self):
        recipe = drafter.draft(archive(numbered_follow_on="K_TALK61.MES"), ["K"])
        follow = route_by_id(recipe, "k-talk-60")["follow_ons"]
        self.assertEqual([(f["target"], f["offset"]) for f in follow], [("K_TALK61.MES", 2120)])
        self.assertEqual([e["offset"] for e in follow[0]["enclosing"]], [588, 1395])
        self.assertEqual(route_by_id(recipe, "k-talk-60")["callee_nested"], ["K_TALK61.MES"])
        self.assertEqual(route_by_id(recipe, "k-talk-30")["follow_ons"], [])


def band_less_archive(stem, caller, guard, callee_gate=None, pre=("K_PIC.MES",), site=5000, between=()):
    """A caller with one block (guard, the picture scripts, any `between` dispatch, the call) and the script."""
    rows = [branch(4900, 4950, guard, 6000)]
    offset = 4960
    for target in pre:
        rows.append(dispatch(offset, offset + 13, target))
        offset += 20
    for target in between:
        rows.append(dispatch(offset, offset + 16, target))
        offset += 20
    rows.append(dispatch(site, site + 14, f"{stem}.MES"))
    script = [plain(7, 8, "command_00")]
    if callee_gate is not None:
        script.append(branch(229, 255, callee_gate, 1368))
    script.append(plain(1357, 1358, "command_00"))
    instructions = {"01M.MES": [plain(7, 8, "command_00")], caller: sorted(rows, key=lambda r: r["source_offset"]),
                    f"{stem}.MES": script}
    for target in set(pre) | set(between):
        instructions[target] = [plain(7, 8, "command_00")]
    return FakeArchive(instructions)


class BandLessScriptTests(unittest.TestCase):
    """The plain `<L>_TALK`, Tina's `M_TALK` and the characters' `N_TALK`..`Q_TALK1` at their anchors."""

    def draft(self, stem, caller, archive_, site=5000):
        # The band-less route alone (a heroine letter would also draft her ladder).
        with unittest.mock.patch.dict(drafter.PLAIN_ANCHORS, {stem: (caller, site)}, clear=True):
            return {"routes": [drafter._plain_route(archive_, stem)]}

    def test_a_character_script_is_seeded_by_the_guard_alone(self):
        guard = conj(compare("equal", "state_u16", 4, 6), compare("greater_than", "state_u16", 7, 615), compare("equal", "global_u8", 150, 0))
        # The script's own first branch (date < 616) contradicts the guard: a character script is not seeded from it.
        arc = band_less_archive("M_TALK", "01M.MES", guard, callee_gate=compare("less_than", "state_u16", 7, 616), pre=("O_PIC.MES",))
        route = self.draft("M_TALK", "01M.MES", arc)["routes"][0]
        self.assertEqual((route["kind"], route["name"], route["route_id"], route["group_id"], route["profile_stem"]),
                         ("character", "tina", "m-talk-plain", "01m-m-talk", "01m_m_talk_v14"))
        cells = {(w["storage"], w["index"]): w["value"] for w in route["baseline"]}
        self.assertEqual(cells, {("state_u16", 4): 6, ("state_u16", 7): 620, ("global_u8", 150): 0})
        self.assertNotIn("callee_gate", route["block"])
        self.assertEqual(route["resume_hop"], "auto")           # `01M.MES` is not a measured day-loop anchor
        self.assertEqual(route["block_members"], ["O_PIC.MES"])  # the picture script of another letter
        self.assertEqual(route["guard_rejected_writes"], [{"storage": "global_u8", "bank": 0, "index": 150, "value": 1}])

    def test_a_numbered_character_script_is_drafted_with_its_group_and_band(self):
        guard = conj(compare("equal", "global_u8", 1624, 0), compare("equal", "global_u8", 1621, 1))
        arc = band_less_archive("N_TALK1", "27C_EV.MES", guard, pre=("N_PIC.MES",))
        route = self.draft("N_TALK1", "27C_EV.MES", arc)["routes"][0]
        self.assertEqual((route["kind"], route["name"], route["route_id"], route["band"], route["group_id"]),
                         ("character", "common", "n-talk-1", "1", "27c-ev-n-talk"))
        self.assertEqual(route["resume_hop"], "auto")  # (27C_EV.MES, 5000) is not a measured day-loop anchor

    def test_only_a_measured_day_loop_anchor_is_a_two_hop_route(self):
        guard = conj(compare("equal", "global_u8", 1624, 0), compare("equal", "global_u8", 1621, 1))
        arc = band_less_archive("N_TALK1", "27C_EV.MES", guard, pre=("N_PIC.MES",))
        with unittest.mock.patch.object(drafter, "DAY_LOOP_ANCHORS", {("27C_EV.MES", 5000)}):
            self.assertIs(self.draft("N_TALK1", "27C_EV.MES", arc)["routes"][0]["resume_hop"], False)
        with unittest.mock.patch.object(drafter, "DAY_LOOP_ANCHORS", {("27C_EV.MES", 5001)}):
            self.assertEqual(self.draft("N_TALK1", "27C_EV.MES", arc)["routes"][0]["resume_hop"], "auto")

    def test_the_measured_day_loop_anchors_are_band_less_anchors_and_exclude_the_two_that_decide_by_measurement(self):
        anchors = set(drafter.PLAIN_ANCHORS.values())
        self.assertLessEqual(drafter.DAY_LOOP_ANCHORS, anchors)
        self.assertEqual({drafter.PLAIN_ANCHORS[stem] for stem in ("N_TALK", "N_TALK1")} & drafter.DAY_LOOP_ANCHORS, set())
        self.assertEqual(len(drafter.DAY_LOOP_ANCHORS), 12)
        self.assertTrue(all(caller == "27C_EV.MES" for caller, _ in drafter.DAY_LOOP_ANCHORS))

    def test_a_heroines_plain_script_still_seeds_its_own_gate(self):
        guard = conj(compare("equal", "global_u8", 180, 0), compare("greater_than", "banked_u16", 208, 30))
        gate = conj(compare("greater_than", "state_u16", 7, 1423), compare("greater_than", "banked_u16", 208, 70))
        arc = band_less_archive("K_TALK", "27C_EV.MES", guard, callee_gate=gate)
        route = self.draft("K_TALK", "27C_EV.MES", arc)["routes"][0]
        self.assertEqual(route["kind"], "plain")
        cells = {(w["storage"], w["index"]): w["value"] for w in route["baseline"]}
        self.assertEqual((cells[("banked_u16", 208)], cells[("state_u16", 7)]), (80, 1430))
        self.assertEqual(route["block"]["callee_gate"], {"offset": 229, "end": 255, "false_target": 1368})

    def test_a_block_without_a_picture_script_is_anchored_at_its_guard(self):
        guard = conj(compare("equal", "state_u16", 4, 0), compare("less_than", "state_u16", 7, 817))
        arc = band_less_archive("N_TALK2", "11M.MES", guard, pre=())
        route = self.draft("N_TALK2", "11M.MES", arc)["routes"][0]
        self.assertNotIn("pic", route["block"])
        self.assertEqual(route["origin"], {"offset": 4900, "guard_offset": 4900, "guard_end": 4950, "false_target": 6000})
        self.assertEqual(route["block_members"], [])

    def test_a_block_that_plays_another_script_first_is_not_the_scripts_own(self):
        guard = compare("equal", "global_u8", 1, 0)
        arc = band_less_archive("E_TALK", "27C_EV.MES", guard, pre=("E_PIC.MES",), between=("N_TALK.MES",),
                                callee_gate=compare("greater_than", "banked_u16", 202, 30))
        with self.assertRaises(SystemExit) as caught:
            self.draft("E_TALK", "27C_EV.MES", arc)
        self.assertIn("dispatches ['N_TALK.MES'] between its guard and the call", str(caught.exception))

    def test_a_site_that_is_not_a_call_of_the_script_stops(self):
        arc = band_less_archive("K_TALK", "27C_EV.MES", compare("equal", "global_u8", 1, 0))
        with self.assertRaises(SystemExit) as caught:
            self.draft("K_TALK", "27C_EV.MES", arc, site=5001)
        self.assertIn("has no call of K_TALK.MES at 5001", str(caught.exception))
        for stem in ("K_TALK30", "M_TALK30", "K_TALKXX"):
            with self.assertRaises(SystemExit):
                with unittest.mock.patch.dict(drafter.PLAIN_ANCHORS, {stem: ("27C_EV.MES", 5000)}, clear=True):
                    drafter._plain_route(arc, stem)

    def test_draft_walks_the_anchors_of_the_requested_letters_only(self):
        guard = conj(compare("equal", "state_u16", 4, 6), compare("greater_than", "state_u16", 7, 615))
        arc = band_less_archive("M_TALK", "01M.MES", guard, pre=("O_PIC.MES",))
        with unittest.mock.patch.dict(drafter.PLAIN_ANCHORS, {"M_TALK": ("01M.MES", 5000), "N_TALK": ("27C_EV.MES", 5000)}, clear=True):
            recipe = drafter.draft(arc, ["M"])
            self.assertEqual([r["route_id"] for r in recipe["routes"]], ["m-talk-plain"])
            with self.assertRaises(SystemExit):
                drafter.draft(arc, ["Z"])


def _write_cell(index, value):
    return {"storage": "global_u8", "bank": 0, "index": index, "value": value}


class GuardWitnessTests(unittest.TestCase):
    def test_holds_evaluates_a_guard_over_the_seeded_cells(self):
        guard = disj(conj(compare("equal", "global_u8", 1, 0), compare("greater_than", "banked_u16", 2, 30)),
                     compare("not_equal", "global_u8", 3, 0))
        self.assertTrue(drafter.holds(guard, {("global_u8", 1): 0, ("banked_u16", 2): 40}, "t"))
        self.assertFalse(drafter.holds(guard, {("global_u8", 1): 0, ("banked_u16", 2): 30}, "t"))
        self.assertTrue(drafter.holds(guard, {("global_u8", 3): 5}, "t"))
        self.assertFalse(drafter.holds(guard, {}, "t"), "an unseeded cell reads 0")

    def test_a_guard_of_alternatives_is_rejected_by_a_cell_every_alternative_pins(self):
        # Heroine A's day-loop guard: three alternatives that each pin the block flag, to 0, 0 and 1.
        guard = disj(conj(compare("equal", "global_u8", 110, 0), compare("not_equal", "global_u8", 118, 0)),
                     conj(compare("equal", "global_u8", 110, 0), compare("equal", "global_u8", 115, 1)),
                     conj(compare("equal", "global_u8", 110, 1), compare("not_equal", "global_u8", 118, 0)))
        write = drafter._rejecting_write(guard, "t")
        self.assertEqual((write["storage"], write["index"], write["value"]), ("global_u8", 110, 2))
        baseline = [_write_cell(110, 0), _write_cell(118, 1)]
        drafter._prove_guard(guard, baseline, [write], "t")
        with self.assertRaises(SystemExit):
            drafter._prove_guard(guard, baseline, [_write_cell(115, 0)], "t")      # does not falsify the guard
        with self.assertRaises(SystemExit):
            drafter._prove_guard(guard, [_write_cell(110, 5)], [write], "t")       # the seeds do not satisfy it

    def test_a_pure_and_guard_is_rejected_by_its_first_flag_tested_for_zero(self):
        guard = conj(compare("equal", "state_u16", 4, 0), compare("equal", "global_u8", 180, 0), compare("equal", "global_u8", 7, 0))
        self.assertEqual(drafter._rejecting_write(guard, "t"), {"storage": "global_u8", "bank": 0, "index": 180, "value": 1})

    def test_a_guard_no_single_cell_rejects_stops(self):
        guard = disj(compare("equal", "global_u8", 1, 0), compare("equal", "global_u8", 2, 0))
        with self.assertRaises(SystemExit):
            drafter._rejecting_write(guard, "t")


class LadderShapeErrorTests(unittest.TestCase):
    def assert_stops(self, message_part, **options):
        with self.assertRaises(SystemExit) as caught:
            drafter.draft(archive(**options), ["K"])
        self.assertIn(message_part, str(caught.exception))

    def test_a_ladder_with_other_limits_stops(self):
        self.assert_stops("is not the rung test", limits=[31, 41, 51, 61, 71, 81, 92])

    def test_a_missing_rung_call_stops(self):
        self.assert_stops("calls K_TALK60.MES from 0 sites", skip_rung="60")

    def test_a_second_site_of_a_rung_stops(self):
        self.assert_stops("calls K_TALK50.MES from 2 sites", extra_site=1700 + 40)

    def test_another_gate_stops(self):
        self.assert_stops("is not the gate", gate_floor=30)

    def test_a_guard_without_the_heroines_draw_stops(self):
        self.assert_stops("no block guard", draw=3)

    def test_an_unknown_letter_stops(self):
        with self.assertRaises(SystemExit):
            drafter.draft(archive(), ["Z"])


if __name__ == "__main__":
    unittest.main()
