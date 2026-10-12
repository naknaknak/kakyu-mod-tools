"""The v6 producer's album-scene branch (EP-12 gallery, 2026-10-04)."""
from __future__ import annotations

import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

import project_event_definition_v6 as v6  # noqa: E402


class GalleryRowTests(unittest.TestCase):
    def test_a_scene_row_of_an_album_menu_is_a_gallery_row(self):
        row = {"category": "special", "evidence": {"callee": "SCENE_J03.MES", "caller": "MINATU_M.MES"}}
        self.assertTrue(v6.is_gallery_registry_row(row))
        self.assertTrue(v6.is_gallery_registry_row({"category": "special", "evidence": {"callee": "scene_j_h01.mes"}}))

    def test_the_producer_and_the_promoter_share_one_predicate(self):
        import payload_values
        import promote_analysis_groups as pag
        self.assertIs(v6.is_gallery_registry_row, payload_values.is_gallery_registry_row)
        self.assertIs(pag.is_gallery_registry_row, payload_values.is_gallery_registry_row)

    def test_date_and_ordinary_rows_are_not(self):
        self.assertFalse(v6.is_gallery_registry_row({"category": "town", "evidence": {"callee": "A_PIC.MES"}}))
        self.assertFalse(v6.is_gallery_registry_row({"category": "special", "evidence": {"callee": "EVENTQ01.MES"}}))
        self.assertFalse(v6.is_gallery_registry_row({"category": "town", "evidence": {"callee": "SCENE_J03.MES"}}))
        self.assertFalse(v6.is_gallery_registry_row({}))


class FlowDoneFlagLineTests(unittest.TestCase):
    """TD-43 (closed by the EP-12 H unit, 2026-10-04): a non-album flow
    document's first `unresolved` line names its own guard, not heroine A's."""

    def test_the_line_spells_the_flows_own_guard_conjuncts(self):
        line = v6.flow_done_flag_line(["(state_u16[13] equal 2)"])
        self.assertIn("(state_u16[13] equal 2)", line)
        self.assertTrue(line.startswith("no done flag identified in the guard:"))
        self.assertTrue(line.endswith("names no cleared completion flag"))

    def test_two_guards_give_two_lines_and_a_conjunction_lists_each_part(self):
        a = v6.flow_done_flag_line(["(state_u16[13] equal 2)"])
        b = v6.flow_done_flag_line(["(state_u16[13] equal 9)"])
        self.assertNotEqual(a, b)
        both = v6.flow_done_flag_line(["(global_u8[110] equal 1)", "(global_u8[117] equal 2)"])
        self.assertIn("(global_u8[110] equal 1); (global_u8[117] equal 2)", both)

    def test_no_heroine_a_cell_text_is_left_in_the_producer(self):
        source = (ROOT / "tools" / "project_event_definition_v6.py").read_text(encoding="utf-8")
        self.assertNotIn("banked_u16[215] promise day", source)


if __name__ == "__main__":
    unittest.main()
