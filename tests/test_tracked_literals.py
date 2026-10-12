"""The shared literal extractors (`tests/tracked_literals.py`), on synthetic input only.

None of this needs the user's executable or archives. The Japanese text used here is built from code
points, so this file holds no Japanese text of its own.
"""

from __future__ import annotations

import random
import sys
import unittest
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tests"))

import tracked_literals as tl  # noqa: E402


def japanese(*code_points: int) -> str:
    return "".join(chr(point) for point in code_points)


HIRAGANA_4 = japanese(0x3042, 0x3044, 0x3046, 0x3048)
HIRAGANA_3 = japanese(0x3042, 0x3044, 0x3046)
HANGUL_4 = japanese(0xAC00, 0xAC01, 0xAC02, 0xAC03)


def holder_counts(entries: list[bytes]) -> dict[int, int]:
    """Window (little-endian integer) -> number of entries holding it, as the archive guard builds it."""
    counts: Counter[int] = Counter()
    for entry in entries:
        counts.update({int.from_bytes(entry[i : i + 8], "little") for i in range(len(entry) - 7)})
    return dict(counts)


class AsciiAndChanceClassTests(unittest.TestCase):
    def test_ascii_accepts_text_whitespace_and_trailing_nul_padding_only(self) -> None:
        self.assertTrue(tl.is_printable_ascii(b"AI5WIN.INI"))
        self.assertTrue(tl.is_printable_ascii(b"line\r\n\ttext"))
        self.assertTrue(tl.is_printable_ascii(b"EnumDisplayModes\0"))
        self.assertTrue(tl.is_printable_ascii(b"name\0\0\0\0"))
        self.assertTrue(tl.is_printable_ascii(bytes(8)))
        self.assertFalse(tl.is_printable_ascii(b"ABCD\0EFGH"))
        self.assertFalse(tl.is_printable_ascii(b"\0qzkvxj_w"))
        self.assertFalse(tl.is_printable_ascii(b"ABCDEFG\x80"))
        self.assertFalse(tl.is_printable_ascii(b"ABCDEFG\x7f"))
        self.assertFalse(tl.is_printable_ascii(b"ABC\x01DEFG"))

    def test_progression_needs_three_values_below_0x40_in_a_tight_span(self) -> None:
        self.assertTrue(tl.small_integer_progression(bytes([1, 2, 3, 4, 5, 6, 7, 8])))
        self.assertTrue(tl.small_integer_progression(bytes([0, 1, 2, 0, 1, 2, 1, 1])))
        self.assertFalse(tl.small_integer_progression(bytes([1, 1, 1, 2, 2, 2, 1, 1])))
        self.assertFalse(tl.small_integer_progression(bytes([1, 2, 3, 0x40, 5, 6, 7, 8])))
        self.assertFalse(tl.small_integer_progression(bytes([0, 0x3F, 1, 0x3E, 2, 0x3D, 3, 0x3C])))

    def test_chance_classes(self) -> None:
        self.assertTrue(tl.is_chance(b"printable text"))
        self.assertTrue(tl.is_chance(bytes([0x12, 0x80, 0x12, 0x80, 0x12, 0x80, 0x12, 0x80])))
        self.assertTrue(tl.is_chance(bytes([1, 2, 3, 4, 5, 6, 7, 8])))
        self.assertFalse(tl.is_chance(bytes([0x6B, 0x03, 0x09, 0xFF, 0x04, 0x0B, 0xFE, 0x01])))


class PythonExtractorTests(unittest.TestCase):
    def test_hex_strings_include_composed_fromhex_arguments(self) -> None:
        source = (
            "A = bytes.fromhex('b1c2d3e4f5061728' + '394a')\n"
            "B = bytes.fromhex('0011223344556677' if flag else 'ffeeddccbbaa9988')\n"
            "C = {'site': '0011223344556677'}\n"
            "D = 'not hex at all, just a sentence'\n"
            "E = '0011'\n"
            "F = '00112233445566778'\n"
        )
        found = sorted(tl.python_hex_strings(source))
        self.assertEqual(
            sorted(
                [
                    (1, bytes.fromhex("b1c2d3e4f5061728394a")),
                    (2, bytes.fromhex("0011223344556677")),
                    (2, bytes.fromhex("ffeeddccbbaa9988")),
                    (3, bytes.fromhex("0011223344556677")),
                ]
            ),
            found,
        )

    def test_integer_lists_need_eight_integers_in_range(self) -> None:
        source = (
            "A = bytes([0x6B, 3, 9, 255, 4, 11, 254, 1])\n"
            "B = [1, 2, 3, 4, 5, 6, 7]\n"
            "C = (1, 2, 3, 4, 5, 6, 7, 8, 9)\n"
            "D = [1, 2, 3, 4, 5, 6, 7, 256]\n"
            "E = [1, 2, 3, 4, 5, 6, 7, x]\n"
            "F = [True, 1, 2, 3, 4, 5, 6, 7]\n"
            "G = [\n    0x01, 0x02, 0x03,\n    0x04, 0x05, 0x06, 0x07, 0x08,\n]\n"
        )
        found = {line: value for line, value in tl.python_integer_lists(source)}
        self.assertEqual({1, 3, 7}, set(found))
        self.assertEqual(bytes([0x6B, 3, 9, 255, 4, 11, 254, 1]), found[1])
        self.assertEqual(bytes(range(1, 10)), found[3])
        self.assertEqual(bytes(range(1, 9)), found[7])

    def test_byte_literals_keep_the_item_one_behaviour(self) -> None:
        source = (
            "A = bytes.fromhex('0102030405060708')\n"
            "B = b'\\x01\\x02'\n"
            "C = '0102030405060708090a0b0c0d0e0f10'\n"
            "def f():\n    return bytes.fromhex('0102030405060708')\n"
        )
        everywhere = [line for line, _ in tl.python_byte_literals(source, module_level_only=False)]
        module_only = [line for line, _ in tl.python_byte_literals(source, module_level_only=True)]
        with_hex = [line for line, _ in tl.python_byte_literals(source, module_level_only=False, hex_strings=True)]
        self.assertEqual([1, 2, 5], sorted(everywhere))
        self.assertEqual([1, 2], sorted(module_only))
        self.assertEqual([1, 2, 3, 5], sorted(with_hex))


class TextExtractorTests(unittest.TestCase):
    def test_integer_lists_span_lines_mix_bases_and_refuse_out_of_range(self) -> None:
        text = (
            "var a = PackedByteArray([0x6B, 3, 9, 255,\n    4, 11, 254, 1])\n"
            "var short = [1, 2, 3, 4, 5, 6, 7]\n"
            "var big = [1, 2, 3, 4, 5, 6, 7, 300]\n"
            "var trailing = [9, 8, 7, 6, 5, 4, 3, 2,]\n"
        )
        found = tl.integer_list_literals(text)
        self.assertEqual([(1, bytes([0x6B, 3, 9, 255, 4, 11, 254, 1])), (5, bytes([9, 8, 7, 6, 5, 4, 3, 2]))], found)

    def test_hex_runs_spaced_hex_and_escapes(self) -> None:
        text = (
            "run 0102030405060708 here\n"
            "spaced 01 02 03 04 05 06 07 08 here\n"
            "number 0x0102030405060708 here\n"
            "short 010203040506\n"
            "escaped \\x01\\x02\\x03\\x04\\x05\\x06\\x07\\x08 here\n"
        )
        self.assertEqual([1, 2], [line for line, _ in tl.text_hex_literals(text)])
        self.assertEqual([5], [line for line, _ in tl.escaped_byte_literals(text)])


class JapaneseTextTests(unittest.TestCase):
    def test_a_run_of_four_characters_is_eight_bytes_and_three_is_not(self) -> None:
        runs = tl.japanese_text_runs("docs/x.md", f"a {HIRAGANA_4} b {HIRAGANA_3} c\n")
        self.assertEqual([(1, "text:raw", HIRAGANA_4.encode("cp932"))], runs)
        self.assertEqual(8, len(runs[0][2]))

    def test_python_json_and_escape_forms(self) -> None:
        escaped = "".join(f"\\u{ord(character):04x}" for character in HIRAGANA_4)
        runs = tl.japanese_text_runs("tests/x.py", f"A = '{escaped}'\n")
        self.assertEqual([(1, "text:py_str", HIRAGANA_4.encode("cp932"))], runs)
        runs = tl.japanese_text_runs("config/x.json", '{"k": "' + escaped + '"}\n')
        self.assertEqual([HIRAGANA_4.encode("cp932")], [payload for _, _, payload in runs])
        self.assertEqual({"text:json_str"}, {kind for _, kind, _ in runs})
        runs = tl.japanese_text_runs("tests/x.gd", f'var s = "{escaped}"\n')
        self.assertEqual(["text:u_escape"], [kind for _, kind, _ in runs])
        self.assertEqual([HIRAGANA_4.encode("cp932")], [payload for _, _, payload in runs])

    def test_characters_cp932_cannot_encode_are_skipped(self) -> None:
        self.assertEqual([], tl.japanese_text_runs("docs/x.md", f"{HANGUL_4}\n"))

    def test_each_run_is_reported_once_per_file(self) -> None:
        runs = tl.japanese_text_runs("docs/x.md", f"{HIRAGANA_4}\n{HIRAGANA_4}\n")
        self.assertEqual(1, len(runs))


class WindowRuleTests(unittest.TestCase):
    def setUp(self) -> None:
        generator = random.Random(1234)
        self.rare = generator.randbytes(20)
        self.filler = [generator.randbytes(64) for _ in range(3)]

    def test_a_planted_rare_run_is_a_finding_with_its_fewest_holders(self) -> None:
        entries = [self.filler[0] + self.rare, self.filler[1] + self.rare[:12], self.filler[2]]
        intervals, fewest = tl.window_findings(self.rare, holder_counts(entries))
        self.assertEqual([(0, 20)], intervals)
        self.assertEqual(1, fewest)

    def test_a_run_nobody_holds_is_not_a_finding(self) -> None:
        intervals, fewest = tl.window_findings(self.rare, holder_counts(self.filler))
        self.assertEqual(([], None), (intervals, fewest))

    def test_chance_classes_are_not_findings_even_when_held(self) -> None:
        classes = {
            "ascii": b"CAI5Doc.mmo and more",
            "padded name": b"EnumDisplayModes\0\0\0",
            "four values": bytes([0x12, 0x80, 0x12, 0x80, 0x34, 0x80, 0x12, 0x34]) * 2,
            "progression": bytes([1, 2, 3, 4, 5, 6, 7, 8, 9, 10]),
        }
        for label, literal in classes.items():
            with self.subTest(label):
                intervals, fewest = tl.window_findings(literal, holder_counts([literal]))
                self.assertEqual([], intervals)

    def test_ninety_nine_holders_are_rare_and_a_hundred_are_an_idiom(self) -> None:
        for holders, expected in ((99, [(0, 20)]), (100, [])):
            with self.subTest(holders=holders):
                entries = [bytes([index]) * 2 + self.rare for index in range(holders)]
                intervals, _ = tl.window_findings(self.rare, holder_counts(entries))
                self.assertEqual(expected, intervals)

    def test_intervals_merge_and_split_on_the_idiom_boundary(self) -> None:
        # Windows 0-1 are rare, 2-21 are held by a hundred more entries (idioms), 22-32 are rare again.
        literal = random.Random(77).randbytes(40)
        common = literal[2:29]
        entries = [self.filler[0] + literal]
        entries += [bytes([index]) * 2 + common for index in range(100)]
        intervals, fewest = tl.window_findings(literal, holder_counts(entries))
        self.assertEqual([(0, 9), (22, 40)], intervals)
        self.assertEqual(1, fewest)

    def test_literals_shorter_than_one_window_have_none(self) -> None:
        self.assertEqual(([], None), tl.window_findings(self.rare[:7], {}))


class ListingTests(unittest.TestCase):
    def test_root_markdown_and_prefixes_select_files(self) -> None:
        names = ["README.md", "notes.json", "docs/a.md", "analysis/b.md", "tools/c.py", "tools/d.bin", "config/e.json"]
        selected = tl.scanned_files(names, ("tools/", "docs/"), (".py", ".md", ".json"))
        self.assertEqual(["README.md", "docs/a.md", "tools/c.py"], selected)

    def test_the_listing_skips_ignored_trees(self) -> None:
        names = tl.listed_files(ROOT)
        self.assertIn("tests/tracked_literals.py", names)
        self.assertFalse([name for name in names if name.startswith(("analysis/", "assets/"))])


if __name__ == "__main__":
    unittest.main()
