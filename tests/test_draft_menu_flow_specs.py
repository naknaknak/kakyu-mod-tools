"""Tests for `tools/draft_menu_flow_specs.py` (EP-12 gallery, 2026-10-04) on a
synthetic album menu - no archive, no Godot."""
from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

import draft_menu_flow_specs as drafter  # noqa: E402


def literal(value):
    return {"type": "literal", "value": value}


def cell(storage, index):
    return {"type": "state_ref", "storage": storage, "bank": 0, "index": literal(index)}


def equal(storage, index, value):
    return {"type": "binary", "op": "equal", "lhs": cell(storage, index), "rhs": literal(value)}


def branch(offset, end, ast, false_target):
    return {"source_offset": offset, "end_offset": end, "op": "branch_if_not_true",
            "operands": [{"type": "condition", "value": {"ast": ast}}, {"type": "code_offset", "value": false_target}]}


def dispatch(offset, end, target):
    return {"source_offset": offset, "end_offset": end, "op": "script_dispatch",
            "operands": [{"records": [{"value": {"raw_bytes": {"$packed_byte_array_hex": target.lower().encode().hex()}}}]}]}


def plain(offset, end, op):
    return {"source_offset": offset, "end_offset": end, "op": op, "operands": []}


def routine40(offset, end):
    return {"source_offset": offset, "end_offset": end, "op": "script_transfer",
            "operands": [{"records": [{"value": {"ast": literal(40)}}]}]}


def write(offset, end, storage, index, value):
    return {"source_offset": offset, "end_offset": end, "op": f"{storage}_write_run",
            "operands": [{"type": "u16_index", "value": index},
                         {"type": "expression_byte_pairs", "pairs": [{"expression": {"ast": literal(value)}}]}]}


class FakeArchive:
    """Just what `draft` reads: `sha`, `entries` and `instructions(entry)`."""

    sha = "ab" * 32

    def __init__(self, instructions):
        self._instructions = instructions
        self.entries = {name: b"" for name in instructions}

    def instructions(self, entry):
        return self._instructions[entry]


def menu_instructions():
    """A J menu: page 0 holds SCENE_J01/J02, page 1 holds SCENE_J03, and one
    H slot (9) holds SCENE_J_H01; flags 100..103."""
    return [
        plain(50, 55, "native_selection"),
        branch(100, 111, equal("global_u8", 20, 0), 300),
        branch(115, 125, equal("state_u16", 18, 1), 200),
        branch(130, 141, equal("global_u8", 100, 1), 190),
        dispatch(145, 162, "SCENE_J01.MES"),
        branch(200, 210, equal("state_u16", 18, 2), 300),
        branch(215, 226, equal("global_u8", 101, 1), 280),
        dispatch(230, 247, "SCENE_J02.MES"),
        branch(300, 311, equal("global_u8", 20, 1), 500),
        branch(315, 325, equal("state_u16", 18, 1), 400),
        branch(330, 341, equal("global_u8", 102, 1), 390),
        dispatch(345, 362, "SCENE_J03.MES"),
        branch(500, 510, equal("state_u16", 18, 9), 600),
        branch(515, 526, equal("global_u8", 103, 1), 590),
        dispatch(530, 549, "SCENE_J_H01.MES"),
    ]


def archive(menu=None, extra=None):
    instructions = {
        "MINATU_M.MES": menu if menu is not None else menu_instructions(),
        "GIRLS.MES": [write(10, 20, "state_u16", 19, 1200), write(30, 40, "state_u16", 8, 0)],
        "SCENE_J01.MES": [plain(70, 71, "command_00")],
        # The recap: reads global_u8[500] (written 1 by J_DATE5, 2 by J_HOTEL) and global_u8[4000].
        "SCENE_J02.MES": [branch(5, 15, equal("global_u8", 500, 1), 40), branch(45, 55, equal("global_u8", 4000, 1), 70),
                          plain(90, 91, "command_00")],
        "SCENE_J03.MES": [routine40(30, 35), plain(80, 81, "command_00")],
        "SCENE_J_H01.MES": [plain(60, 61, "command_00")],
        "J_DATE5.MES": [write(12, 22, "global_u8", 500, 1)],
        "J_HOTEL.MES": [write(12, 22, "global_u8", 500, 2)],
    }
    instructions.update(extra or {})
    return FakeArchive(instructions)


class DraftMenuFlowSpecsTests(unittest.TestCase):
    def draft(self, menu=None, extra=None, duplicates=None):
        return drafter.draft(archive(menu, extra), "J", duplicates)

    def test_every_call_becomes_a_scene_with_its_chain_of_records(self):
        recipe = self.draft()
        self.assertEqual((recipe["menu_entry"], recipe["group_id"], recipe["profile_stem"]),
                         ("MINATU_M.MES", "minatu-m-scene", "minatu_m_scene_v14"))
        self.assertEqual(recipe["selection"], {"offset": 50, "end": 55})
        scenes = {scene["scene"]: scene for scene in recipe["scenes"]}
        self.assertEqual(list(scenes), ["SCENE_J01.MES", "SCENE_J02.MES", "SCENE_J03.MES", "SCENE_J_H01.MES"])
        first = scenes["SCENE_J01.MES"]
        self.assertEqual((first["route_id"], first["kind"], first["page"], first["slot"], first["flag"]),
                         ("j-scene-01", "page", 0, 1, 100))
        self.assertEqual((first["origin_offset"], first["slot_test_offset"], first["guard_offset"], first["guard_end"],
                          first["false_target"], first["dispatch_offset"], first["dispatch_end"]),
                         (100, 115, 130, 141, 190, 145, 162))
        # The second slot of a page starts at the same page test.
        second = scenes["SCENE_J02.MES"]
        self.assertEqual((second["page"], second["slot"], second["origin_offset"], second["slot_test_offset"]), (0, 2, 100, 200))
        third = scenes["SCENE_J03.MES"]
        self.assertEqual((third["page"], third["slot"], third["origin_offset"]), (1, 1, 300))
        # An H slot has no page; its origin is the slot test itself.
        h_scene = scenes["SCENE_J_H01.MES"]
        self.assertEqual((h_scene["route_id"], h_scene["kind"], h_scene["page"], h_scene["slot"], h_scene["origin_offset"]),
                         ("j-scene-h01", "h", None, 9, 500))
        self.assertEqual(h_scene["flag"], 103)

    def test_questions_and_recap_cells_are_found_statically(self):
        scenes = {scene["scene"]: scene for scene in self.draft()["scenes"]}
        self.assertEqual(scenes["SCENE_J03.MES"]["questions"], [30])
        self.assertEqual(scenes["SCENE_J01.MES"]["questions"], [])
        # Only the cell the heroine's DATE5 path writes 1 and her hotel path writes 2 is a recap cell.
        self.assertEqual(scenes["SCENE_J02.MES"]["recap_cells"], [500])
        self.assertEqual(scenes["SCENE_J01.MES"]["recap_cells"], [])

    def test_a_scenes_nested_helper_entries_are_found_transitively(self):
        extra = {
            "SCENE_J01.MES": [dispatch(10, 27, "J_PIC.MES"), plain(70, 71, "command_00")],
            "J_PIC.MES": [dispatch(5, 22, "J_PIC2.MES")],
            "J_PIC2.MES": [plain(1, 2, "command_00")],
        }
        scenes = {scene["scene"]: scene for scene in self.draft(extra=extra)["scenes"]}
        self.assertEqual(scenes["SCENE_J01.MES"]["nested_members"], ["J_PIC.MES", "J_PIC2.MES"])
        self.assertEqual(scenes["SCENE_J02.MES"]["nested_members"], [])

    def test_a_nested_entry_missing_from_the_archive_stops(self):
        with self.assertRaises(SystemExit) as raised:
            self.draft(extra={"SCENE_J01.MES": [dispatch(10, 27, "NOWHERE.MES"), plain(70, 71, "command_00")]})
        self.assertIn("NOWHERE.MES", str(raised.exception))

    def test_the_duplicate_census_is_carried_into_the_scene_entries(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "duplicates.json"
            path.write_text(json.dumps({"groups": [
                {"kind": "gallery_copy_of_event", "entries": ["EVENTJ04.MES", "SCENE_J03.MES"]}]}), encoding="utf-8")
            scenes = {scene["scene"]: scene for scene in self.draft(duplicates=path)["scenes"]}
        self.assertEqual(scenes["SCENE_J03.MES"]["duplicate"], {"kind": "gallery_copy_of_event", "with": ["EVENTJ04.MES"]})
        self.assertIsNone(scenes["SCENE_J01.MES"]["duplicate"])

    def test_the_ambient_premise_is_checked_against_girls(self):
        with self.assertRaises(SystemExit) as raised:
            self.draft(extra={"GIRLS.MES": [write(10, 20, "state_u16", 19, 900)]})
        self.assertIn("ambient", str(raised.exception))

    def test_a_menu_without_exactly_one_selection_stops(self):
        without = [ins for ins in menu_instructions() if ins["op"] != "native_selection"]
        with self.assertRaises(SystemExit) as raised:
            self.draft(menu=without)
        self.assertIn("native selection", str(raised.exception))
        twice = menu_instructions() + [plain(600, 605, "native_selection")]
        with self.assertRaises(SystemExit):
            self.draft(menu=twice)

    def test_a_call_without_its_unlock_test_stops_naming_the_scene(self):
        broken = [ins for ins in menu_instructions() if ins["source_offset"] != 215]
        with self.assertRaises(SystemExit) as raised:
            self.draft(menu=broken)
        self.assertIn("SCENE_J02.MES", str(raised.exception))
        self.assertIn("unlock", str(raised.exception))

    def test_flags_must_be_one_consecutive_run(self):
        broken = menu_instructions()
        broken[6] = branch(215, 226, equal("global_u8", 150, 1), 280)
        with self.assertRaises(SystemExit) as raised:
            self.draft(menu=broken)
        self.assertIn("consecutive", str(raised.exception))

    def test_an_h_scene_behind_a_page_test_stops(self):
        broken = menu_instructions()
        # Widen the last page test so it encloses the H slot.
        broken[8] = branch(300, 311, equal("global_u8", 20, 1), 700)
        with self.assertRaises(SystemExit) as raised:
            self.draft(menu=broken)
        self.assertIn("H scene", str(raised.exception))

    def test_a_page_scene_without_a_page_test_stops(self):
        broken = [ins for ins in menu_instructions() if ins["source_offset"] != 300]
        with self.assertRaises(SystemExit) as raised:
            self.draft(menu=broken)
        self.assertIn("page scene", str(raised.exception))

    def test_a_dispatch_that_is_not_a_scene_stops(self):
        broken = menu_instructions() + [dispatch(560, 575, "MACHI.MES")]
        with self.assertRaises(SystemExit) as raised:
            self.draft(menu=broken)
        self.assertIn("not a SCENE_ entry", str(raised.exception))

    def test_a_scene_of_another_heroine_stops(self):
        broken = menu_instructions()
        broken[4] = dispatch(145, 162, "SCENE_A01.MES")
        with self.assertRaises(SystemExit) as raised:
            self.draft(menu=broken, extra={"SCENE_A01.MES": [plain(70, 71, "command_00")]})
        self.assertIn("heroine A", str(raised.exception))

    def test_a_scene_without_a_closing_return_stops(self):
        with self.assertRaises(SystemExit) as raised:
            self.draft(extra={"SCENE_J01.MES": []})
        self.assertIn("closing return", str(raised.exception))

    def test_the_same_slot_twice_on_a_page_stops(self):
        broken = menu_instructions()
        broken[5] = branch(200, 210, equal("state_u16", 18, 1), 300)
        with self.assertRaises(SystemExit) as raised:
            self.draft(menu=broken)
        self.assertIn("used twice", str(raised.exception))

    def test_an_unknown_letter_stops(self):
        with self.assertRaises(SystemExit):
            drafter.draft(archive(), "Z")


if __name__ == "__main__":
    unittest.main()
