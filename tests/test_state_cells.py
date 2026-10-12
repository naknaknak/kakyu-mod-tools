"""Tests for the `kakyu_state_cells/v1` table (event definition v4 unit 2a)."""
from __future__ import annotations

import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from tools.contract_fingerprint import compute, stored  # noqa: E402
from tools.state_cells import classify, heroine, load  # noqa: E402

TABLE_DIR = ROOT / "config" / "contracts" / "state_cells_v1"

NAMED_AFFECTION = {
    200: ("reiko", "F"),
    201: ("miko", "A"),
    202: ("mizuho", "E"),
    203: ("mayumi", "I"),
    204: ("ryoko", "G"),
    205: ("tina", "M"),
    206: ("nana", "C"),
    207: ("miyuki", "H"),
    208: ("ai", "K"),
    209: ("sizuka", "L"),
    210: ("mahoko", "B"),
    211: ("minatu", "J"),
    212: ("maki", "D"),
}


class StateCellsTest(unittest.TestCase):
    def test_stored_fingerprint_matches_computed(self) -> None:
        self.assertEqual(
            stored(TABLE_DIR, "cells_fingerprint"),
            compute(TABLE_DIR, "cells_fingerprint"),
        )

    def test_schema_and_classes(self) -> None:
        table = load()
        self.assertEqual(table["schema"], "kakyu_state_cells/v1")
        self.assertEqual(
            table["classes"],
            [
                "weekday", "date", "clock", "clock_part", "choice_result",
                "map_poll_result", "affection", "flag", "counter", "unnamed",
            ],
        )

    def test_named_cells(self) -> None:
        self.assertEqual(classify("state_u16", 0, 4), "weekday")
        self.assertEqual(classify("state_u16", 0, 7), "date")
        self.assertEqual(classify("state_u16", 0, 19), "clock")
        self.assertEqual(classify("state_u16", 0, 0), "clock_part")
        self.assertEqual(classify("state_u16", 0, 1), "clock_part")
        self.assertEqual(classify("state_u16", 0, 21), "choice_result")
        self.assertEqual(classify("state_u16", 0, 18), "map_poll_result")

    def test_affection_cells_and_heroines(self) -> None:
        for index, (name, letter) in NAMED_AFFECTION.items():
            self.assertEqual(classify("banked_u16", 0, index), "affection", index)
            self.assertEqual(heroine("banked_u16", 0, index), name, index)

    def test_213_is_not_affection(self) -> None:
        self.assertEqual(classify("banked_u16", 0, 213), "unnamed")
        self.assertIsNone(heroine("banked_u16", 0, 213))

    def test_global_u8_flag_vs_counter_rule(self) -> None:
        self.assertEqual(classify("global_u8", 0, 900, observed_values=[0, 1]), "flag")
        self.assertEqual(classify("global_u8", 0, 900, observed_values=[0]), "flag")
        self.assertEqual(classify("global_u8", 0, 900, observed_values=[0, 5]), "counter")
        self.assertEqual(classify("global_u8", 0, 900, observed_values=None), "counter")
        self.assertEqual(classify("global_u8", 0, 900, observed_values=[]), "counter")

    def test_other_storages_are_unnamed_by_the_rules(self) -> None:
        self.assertEqual(classify("state_u16", 0, 25), "unnamed")
        self.assertEqual(classify("banked_u16", 0, 1), "unnamed")
        self.assertEqual(classify("banked_u8", 0, 3), "unnamed")
        self.assertEqual(classify("global_i32", 0, 3), "unnamed")

    def test_unknown_storage_is_unclassified(self) -> None:
        self.assertIsNone(classify("mystery_storage", 0, 0))


if __name__ == "__main__":
    unittest.main()
