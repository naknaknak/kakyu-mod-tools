"""Tests for `tools/draft_recollection_flow_specs.py` (EP-12 H, 2026-10-04) on a
synthetic room and synthetic ladders - no archive, no Godot."""
from __future__ import annotations

import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

import draft_recollection_flow_specs as drafter  # noqa: E402
from build_event_names import RECOLLECTION_HEROINE_BY_STEM  # noqa: E402


def literal(value):
    return {"type": "literal", "value": value}


def cell(storage, index):
    return {"type": "state_ref", "storage": storage, "bank": 0, "index": literal(index)}


def compare(op, storage, index, value):
    return {"type": "binary", "op": op, "lhs": cell(storage, index), "rhs": literal(value)}


def equal(storage, index, value):
    return compare("equal", storage, index, value)


def either(*operands):
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


def jump(offset, end, target):
    return {"source_offset": offset, "end_offset": end, "op": "continuation_transfer",
            "operands": [{"value": target}]}


def plain(offset, end, op):
    return {"source_offset": offset, "end_offset": end, "op": op, "operands": []}


def routine40(offset, end):
    return {"source_offset": offset, "end_offset": end, "op": "script_transfer",
            "operands": [{"records": [{"value": {"ast": literal(40)}}]}]}


def write(offset, end, storage, index, ast):
    return {"source_offset": offset, "end_offset": end, "op": f"{storage}_write_run",
            "operands": [{"type": "u16_index", "value": index},
                         {"type": "expression_byte_pairs", "pairs": [{"expression": {"ast": ast}}]}]}


class FakeArchive:
    """Just what `draft` reads: `sha`, `entries` and `instructions(entry)`."""

    sha = "cd" * 32

    def __init__(self, instructions):
        self._instructions = instructions
        self.entries = {name: b"" for name in instructions}

    def instructions(self, entry):
        return self._instructions[entry]


# The room's calls follow the picker ids 1..13, not the heroine letters.
STEMS = [f"{name}_H" for name in ("REIKO", "MIKO", "MIZUHO", "MAYUMI", "RYOKO", "TINA", "NANA", "MIYUKI", "AI",
                                  "SIZUKA", "MAHOKO", "MINATU", "MAKI")]
assert set(STEMS) == set(RECOLLECTION_HEROINE_BY_STEM)
RETURN_TARGET, SHARED_TAIL, LOOP_HEAD = 3000, 3100, 100


def room_instructions(skip_clock_save=False, shuffle_ids=False):
    """A room: the routine-40 question, the `state_u16[21] == 1 / 2 / 3` chain,
    the clock save, 13 id tests each followed by its call and the jump to the
    return target, then the return chain to the loop head."""
    rows = [
        branch(LOOP_HEAD, LOOP_HEAD + 7, literal(1), 9000),
        routine40(1000, 1005),
        branch(1030, 1040, equal("state_u16", 21, 1), 1200),
        branch(1200, 1210, equal("state_u16", 21, 2), 1500),
        branch(1500, 1510, equal("state_u16", 21, 3), 9000),
    ]
    if not skip_clock_save:
        rows.append(write(1560, 1570, "banked_u16", 195, cell("state_u16", 19)))
    base = 1600
    for number, stem in enumerate(STEMS, 1):
        picker = (number + 1 if shuffle_ids and number == 2 else number)
        rows.append(branch(base, base + 10, equal("state_u16", 13, picker), base + 40 if number < 13 else 2900))
        rows.append(dispatch(base + 10, base + 25, f"{stem}.MES"))
        rows.append(jump(base + 25, base + 30, RETURN_TARGET))
        base += 40
    rows.append(plain(2950, 2951, "command_00"))
    rows.append(write(RETURN_TARGET, RETURN_TARGET + 6, "global_u8", 5, literal(5)))
    rows.append(jump(RETURN_TARGET + 10, RETURN_TARGET + 15, SHARED_TAIL))
    rows.append(jump(SHARED_TAIL + 10, SHARED_TAIL + 15, LOOP_HEAD))
    return sorted(rows, key=lambda r: r["source_offset"])


def ladder_instructions(picker, extra=None):
    """A ladder: its heroine guard, a prologue segment, a nested gate pair, a
    selector tested against 1 and 2, a flag test inside a selector arm, a
    presentation test, tail cells and two returns."""
    rows = [
        plain(0, 1, "command_00"),
        branch(100, 110, equal("state_u16", 13, picker), 9500),
        branch(200, 210, equal("global_u8", 2573, 0), 300),           # tail cell: never a gate
        branch(300, 310, equal("global_u8", 1000, 1), 2000),           # prologue gate
        branch(320, 330, equal("global_u8", 4000, 1), 390),            # presentation cell
        branch(2000, 2010, equal("global_u8", 1001, 1), 6000),         # gate with nested gates
        branch(2100, 2110, equal("global_u8", 1002, 1), 3000),         # nested gate (depth 1)
        branch(3000, 3010, compare("not_equal", "global_u8", 1003, 0), 4000),  # `!= 0` form, nested
        branch(4100, 4110, equal("global_u8", 3201, 1), 4200),         # selector: also tested == 2 below
        branch(4200, 4210, equal("global_u8", 3201, 2), 4300),
        branch(6000, 6030, either(equal("global_u8", 2676, 1), equal("global_u8", 2677, 1)), 7500),  # over selector cells
        branch(6100, 6110, equal("global_u8", 2676, 1), 6200),
        branch(6200, 6210, equal("global_u8", 2676, 2), 6300),
        branch(6300, 6310, equal("global_u8", 2677, 2), 6400),
        branch(6400, 6410, equal("global_u8", 1100, 1), 6500),         # a flag test inside the selector arm
        branch(7500, 7510, equal("global_u8", 1004, 1), 9000),         # a gate after the recap block
        branch(9000, 9010, equal("global_u8", 11, 1), 9400),           # tail
        plain(9500, 9501, "command_00"),
        plain(9520, 9521, "command_00"),
    ]
    rows.extend(extra or [])
    return sorted(rows, key=lambda r: r["source_offset"])


def archive(ladder_extra=None, room=None, ladders=None):
    instructions = {"43C.MES": room if room is not None else room_instructions()}
    for number, stem in enumerate(STEMS, 1):
        instructions[f"{stem}.MES"] = ladders[stem] if ladders and stem in ladders else ladder_instructions(
            number, ladder_extra if ladder_extra and stem == "MIKO_H" else None)
    return FakeArchive(instructions)


class RoomTests(unittest.TestCase):
    def setUp(self):
        self.recipe = drafter.draft(archive())

    def test_the_room_names_the_origin_the_answer_chain_and_the_return_chain(self):
        recipe = self.recipe
        self.assertEqual(recipe["origin"], {"offset": 1560, "end": 1570})
        self.assertEqual(recipe["question"], {"offset": 1000})
        self.assertEqual([(a["value"], a["offset"], a["false_target"]) for a in recipe["answer_chain"]],
                         [(1, 1030, 1200), (2, 1200, 1500), (3, 1500, 9000)])
        self.assertEqual(recipe["return_chain"], {"after_call": RETURN_TARGET, "shared_tail": SHARED_TAIL,
                                                  "loop_jump": SHARED_TAIL + 10, "loop_head": LOOP_HEAD})

    def test_every_ladder_has_its_id_test_call_and_route(self):
        ladders = self.recipe["ladders"]
        self.assertEqual([ladder["id"] for ladder in ladders], list(range(1, 14)))
        miko = ladders[1]
        self.assertEqual((miko["entry"], miko["letter"], miko["name"], miko["route_id"], miko["group_id"], miko["profile_stem"]),
                         ("MIKO_H.MES", "A", "miko", "a-h", "43c-miko-h", "43c_miko_h_v14"))
        self.assertEqual((miko["guard_offset"], miko["guard_end"], miko["dispatch_offset"], miko["dispatch_end"]),
                         (1640, 1650, 1650, 1665))
        self.assertEqual(miko["false_target"], 1680)
        self.assertEqual(ladders[12]["entry"], "MAKI_H.MES")
        self.assertEqual({ladder["letter"] for ladder in ladders}, set("ABCDEFGHIJKLM"))

    def test_the_seeded_selection_and_ambient_are_the_tool_decisions(self):
        recipe = self.recipe
        self.assertEqual(recipe["id_cell"], ["state_u16", 13])
        self.assertEqual((recipe["answer_cell"], recipe["answer_value"]), (["state_u16", 21], 3))
        self.assertEqual([(a["storage"], a["index"], a["value"]) for a in recipe["ambient"]],
                         [("state_u16", 19, 2015), ("state_u16", 8, 0), ("global_u8", 2573, 0)])
        self.assertEqual(recipe["segment_budget"], 1024)

    def test_a_room_that_does_not_match_stops_the_tool(self):
        with self.assertRaisesRegex(SystemExit, "recollection shape mismatch"):
            drafter.draft(archive(room=room_instructions(skip_clock_save=True)))
        with self.assertRaisesRegex(SystemExit, "picker id 3, expected 2"):
            drafter.draft(archive(room=room_instructions(shuffle_ids=True)))
        without_question = [row for row in room_instructions() if row["op"] != "script_transfer"]
        with self.assertRaisesRegex(SystemExit, "routine-40"):
            drafter.draft(archive(room=without_question))
        short = [row for row in room_instructions() if not (row["op"] == "script_dispatch" and row["source_offset"] == 1650)]
        with self.assertRaisesRegex(SystemExit, "calls 12 ladders"):
            drafter.draft(archive(room=short))


class LadderTests(unittest.TestCase):
    def setUp(self):
        self.miko = drafter.draft(archive())["ladders"][1]

    def test_gates_are_single_flag_tests_on_the_main_path(self):
        gates = [(g["offset"], g["cell"], g["op"], g["depth"]) for g in self.miko["gates"]]
        self.assertEqual(gates, [
            (300, 1000, "equal 1", 0),
            (2000, 1001, "equal 1", 0),
            (2100, 1002, "equal 1", 1),
            (3000, 1003, "not_equal 0", 1),
            (7500, 1004, "equal 1", 0),
        ])
        self.assertEqual(self.miko["gate_cells"], [1000, 1001, 1002, 1003, 1004])
        self.assertEqual(self.miko["gates"][0]["skip"], 2000 - 310)

    def test_a_short_prologue_segment_is_a_gate_too(self):
        self.assertEqual(self.miko["gates"][0]["false_target"] - self.miko["gates"][0]["end"], 1690)
        rows = ladder_instructions(2, [branch(500, 510, equal("global_u8", 1999, 1), 540)])
        gate_offsets = [g["offset"] for g in drafter.draft(archive(ladders={"MIKO_H": rows}))["ladders"][1]["gates"]]
        self.assertIn(500, gate_offsets)  # a 30-byte segment: no byte-skip threshold

    def test_every_other_branch_cell_is_reported_under_its_reason(self):
        excluded = self.miko["excluded"]
        self.assertEqual(excluded["tail_cells"], [11, 2573])
        self.assertEqual(excluded["presentation_cells"], [4000])
        self.assertEqual(excluded["selector_cells"], [2676, 2677, 3201])
        self.assertEqual(excluded["flag_tests_inside_arms"], [1100])
        self.assertEqual(excluded["guard_only_cells"], [])
        self.assertEqual(excluded["state_cells"], [])
        self.assertEqual(self.miko["transparent_guards"], [])

    def test_a_flag_only_or_is_transparent_and_its_members_are_gates(self):
        guard = branch(500, 520, either(equal("global_u8", 1200, 1), equal("global_u8", 1201, 1)), 800)
        inside = branch(530, 540, equal("global_u8", 1200, 1), 600)
        rows = ladder_instructions(2, [guard, inside])
        ladder = drafter.draft(archive(ladders={"MIKO_H": rows}))["ladders"][1]
        self.assertEqual(ladder["transparent_guards"], [{"offset": 500, "end": 520, "false_target": 800,
                                                         "cells": [1200, 1201]}])
        self.assertIn(530, [g["offset"] for g in ladder["gates"]])
        self.assertEqual(ladder["gates"][[g["offset"] for g in ladder["gates"]].index(530)]["depth"], 1)  # inside the prologue gate at 300; the transparent guard adds no span
        # The member tested only inside the guard is reported, never seeded.
        self.assertEqual(ladder["excluded"]["guard_only_cells"], [1201])
        self.assertNotIn(1201, ladder["gate_cells"])
        self.assertIn(1200, ladder["gate_cells"])

    def test_a_transparent_guard_with_no_gate_of_its_cells_stops_the_tool(self):
        guard = branch(500, 520, either(equal("global_u8", 1200, 1), equal("global_u8", 1201, 1)), 800)
        rows = ladder_instructions(2, [guard])
        with self.assertRaisesRegex(SystemExit, "guards no gate of its own cells"):
            drafter.draft(archive(ladders={"MIKO_H": rows}))

    def test_an_or_over_selector_cells_stays_an_enclosing_non_gate(self):
        # The recap block (6000..7500) holds a flag test of cell 1100: not a gate.
        self.assertNotIn(6400, [g["offset"] for g in self.miko["gates"]])

    def test_nested_helper_entries_are_listed(self):
        rows = ladder_instructions(2, [dispatch(8000, 8012, "O_PIC.MES")])
        instructions = archive(ladders={"MIKO_H": rows}).__dict__["_instructions"]
        instructions["O_PIC.MES"] = [plain(0, 1, "command_00")]
        fake = FakeArchive(instructions)
        self.assertEqual(drafter.draft(fake)["ladders"][1]["nested_members"], ["O_PIC.MES"])
        self.assertEqual(self.miko["nested_members"], [])

    def test_a_ladder_that_does_not_match_stops_the_tool(self):
        wrong_guard = ladder_instructions(5)  # MIKO_H must test picker id 2
        with self.assertRaisesRegex(SystemExit, "is not the heroine guard state_u16\\[13\\] == 2"):
            drafter.draft(archive(ladders={"MIKO_H": wrong_guard}))
        asking = ladder_instructions(2, [routine40(8100, 8105)])
        with self.assertRaisesRegex(SystemExit, "asks a routine-40 question"):
            drafter.draft(archive(ladders={"MIKO_H": asking}))
        flat = [row for row in ladder_instructions(2) if row["source_offset"] in (0, 100, 9500, 9520)]
        with self.assertRaisesRegex(SystemExit, "no gate by the structural rule"):
            drafter.draft(archive(ladders={"MIKO_H": flat}))

    def test_the_ladders_own_returns_are_listed(self):
        self.assertEqual(self.miko["returns"], [0, 9500, 9520])


if __name__ == "__main__":
    unittest.main()
