"""Tests for `tools/text_rules.py` (mod event definition unit A): the four
reason codes, the line-break switch, the placeholder switch, NFC."""
from __future__ import annotations

import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from tools.text_rules import check_text  # noqa: E402


class TextRulesTest(unittest.TestCase):
    def test_valid_text_passes(self) -> None:
        self.assertIsNone(check_text("Hello there."))

    def test_text_not_nfc(self) -> None:
        # "A" + combining acute accent (U+0301): NFC would fold it to U+00C1.
        result = check_text("Á")
        self.assertIsNotNone(result)
        reason, detail = result
        self.assertEqual(reason, "text_not_nfc")
        self.assertIn("NFC", detail)

    def test_text_line_break_by_default(self) -> None:
        result = check_text("line one\nline two")
        self.assertIsNotNone(result)
        reason, detail = result
        self.assertEqual(reason, "text_line_break")

    def test_text_line_break_carriage_return_by_default(self) -> None:
        result = check_text("line one\rline two")
        self.assertIsNotNone(result)
        self.assertEqual(result[0], "text_line_break")

    def test_text_control_character(self) -> None:
        result = check_text("bellsound")
        self.assertIsNotNone(result)
        reason, detail = result
        self.assertEqual(reason, "text_control_character")
        self.assertIn("U+0007", detail)

    def test_text_control_character_feff_and_fffd(self) -> None:
        self.assertEqual(check_text("﻿")[0], "text_control_character")
        self.assertEqual(check_text("�")[0], "text_control_character")

    def test_text_control_character_noncharacter(self) -> None:
        self.assertEqual(check_text("﷐")[0], "text_control_character")
        self.assertEqual(check_text("￾")[0], "text_control_character")

    def test_text_control_character_private_use(self) -> None:
        self.assertEqual(check_text("")[0], "text_control_character")

    def test_bad_placeholder_not_checked_without_placeholder_argument(self) -> None:
        # No `placeholder=` given: a brace is not checked at all (the
        # resolved-projection path is unaffected).
        self.assertIsNone(check_text("see {other} here"))

    def test_allow_line_break_switch(self) -> None:
        # U+000A passes with allow_line_break=True ...
        self.assertIsNone(check_text("line one\nline two", allow_line_break=True))
        # ... but U+000D still fails, as any other control character does.
        result = check_text("line one\rline two", allow_line_break=True)
        self.assertIsNotNone(result)
        self.assertEqual(result[0], "text_control_character")
        self.assertIn("U+000D", result[1])

    def test_placeholder_switch_accepts_name(self) -> None:
        self.assertIsNone(check_text("Hello, {name}.", placeholder="name"))

    def test_placeholder_switch_rejects_other_brace_content(self) -> None:
        result = check_text("Hello, {other}.", placeholder="name")
        self.assertIsNotNone(result)
        reason, detail = result
        self.assertEqual(reason, "bad_placeholder")

    def test_placeholder_switch_rejects_unbalanced_brace(self) -> None:
        result = check_text("Hello, {name.", placeholder="name")
        self.assertIsNotNone(result)
        self.assertEqual(result[0], "bad_placeholder")

        result = check_text("Hello, name}.", placeholder="name")
        self.assertIsNotNone(result)
        self.assertEqual(result[0], "bad_placeholder")

    def test_placeholder_switch_combined_with_line_break(self) -> None:
        self.assertIsNone(check_text("Hi {name},\nsee you.", allow_line_break=True, placeholder="name"))


if __name__ == "__main__":
    unittest.main()
