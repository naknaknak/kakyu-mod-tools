"""No tracked file holds an 8-byte window of an original MES or data archive entry (WD-25 item 1b).

The rule, one for bytes and text. A window of 8 bytes is rare when 1 to 99 entries of the user's
`mes.arc` or `data.arc` hold it, and no tracked file may contain a literal in which rare windows
form an interval that is not a chance class. Overlapping rare windows merge into one interval; an
interval is a chance class when it is printable ASCII (tab, CR and LF anywhere, NUL only as trailing
padding), holds fewer than 5 distinct byte values, or is a small-integer progression
(`tracked_literals.is_chance`). Windows held by 100 or more entries are the format's command
encoding and may stay: that bar is a tool decision, measured at 78-94% of entries (the protagonist
name insertion in 948, the voice-bit records in 788-822), not a fact about authorship.

- Bytes are the tracked byte literals: `bytes.fromhex`, `bytes` constants, hex-string constants and
  integer lists in Python; contiguous and spaced hex runs, bracketed integer lists (decimal or hex,
  across lines) and `\\x` escapes in other text.
- Text is every run of 4 or more Japanese-script characters in tracked text, encoded to cp932 (4
  double-byte characters are 8 bytes): Python string constants, parsed JSON and JSONL strings, `\\u`
  escapes in other text, and raw text. A run cp932 cannot encode (Hangul, for example) cannot be
  original text and is skipped.

Part A is local and always runs: a self-test of the scanner on synthetic entries and the extractors.
Part B needs the user's own archives (`KAKYU_MES_ARC` and `KAKYU_DATA_ARC`, both required, read from
the environment only) and asserts that no tracked file under `tools/`, `tests/`, `content_core/`,
`docs/`, `config/` or the root `*.md` files breaks the rule. It must finish within 90 seconds.

Out of scope, recorded: base64 strings and tracked binary files are not scanned. The companion
inventory (`analysis/_docs/archive_literals_inventory.py`, with the author) covers them and found
nothing. `docs/` and the root `*.md` files lie outside the validation suite's fingerprint roots
(`tools/content_suite/validation_inputs.py`), so a cached batch does not notice a document change.

How a test author stays inside the rule: a test-authored MES fixture or text must not reproduce an
8-byte run (4 Japanese characters) held by fewer than 100 original entries. Change an operand the
test does not depend on (a constant, a flag or slot index, a target, a resource or script name, text
characters) to a synthetic value; where an asserted value moves with the operand, move only that
expected value. A record whose exact encoding is the subject and which has no free operand is built
once from named grammar constants (`tests/mes_record_grammar.gd`, `tools/payload_values.py`). There is
no allowlist.
"""

from __future__ import annotations

import os
import random
import struct
import sys
import tempfile
import time
import unittest
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tests"))
sys.path.insert(0, str(ROOT / "tools"))

import original_archives  # noqa: E402
import tracked_literals  # noqa: E402
from tracked_literals import (  # noqa: E402
    GRAM,
    IDIOM_HOLDERS,
    escaped_byte_literals,
    integer_list_literals,
    japanese_text_runs,
    listed_files,
    python_byte_literals,
    python_hex_strings,
    python_integer_lists,
    text_hex_literals,
    window_findings,
)

SCANNED_PREFIXES = ("tools/", "tests/", "content_core/", "docs/", "config/")
TEXT_SUFFIXES = (".gd", ".md", ".json", ".jsonl", ".tscn", ".ps1", ".cs", ".c", ".cfg", ".txt", ".godot", ".gdshader")
SCAN_BUDGET_SECONDS = 90

RULE_FOR_AUTHORS = (
    "A test-authored MES fixture or text must not reproduce an 8-byte run (4 Japanese characters) held "
    "by fewer than 100 original entries: change an operand the test does not depend on (a constant, a "
    "flag or slot index, a target, a resource or script name, text characters) to a synthetic value. "
    "Records held by 100 or more entries are the format's command encoding and may stay (a tool "
    "decision). There is no allowlist."
)


@dataclass(frozen=True)
class Finding:
    path: str
    line: int
    form: str
    length: int
    intervals: tuple[tuple[int, int], ...]
    fewest_holders: int

    def describe(self) -> str:
        spans = ", ".join(f"{begin}-{end}" for begin, end in self.intervals)
        return (
            f"{self.path}:{self.line} ({self.form}, {self.length} bytes, rare at offsets {spans}, "
            f"fewest holders {self.fewest_holders})"
        )


def scanned_files(names: Iterable[str]) -> list[str]:
    return tracked_literals.scanned_files(names, SCANNED_PREFIXES, (".py", *TEXT_SUFFIXES))


def file_candidates(name: str, text: str) -> list[tuple[int, str, bytes]]:
    """`(line, form, value)` for every byte literal of 8 bytes or more and every Japanese run."""
    if name.endswith(".py"):
        try:
            found = (
                python_byte_literals(text, module_level_only=False, hex_strings=True)
                + python_hex_strings(text)
                + python_integer_lists(text)
            )
        except SyntaxError:
            found = text_hex_literals(text) + integer_list_literals(text) + escaped_byte_literals(text)
    else:
        found = text_hex_literals(text) + integer_list_literals(text) + escaped_byte_literals(text)
    candidates = [(line, "bytes", value) for line, value in dict.fromkeys(found) if len(value) >= GRAM]
    candidates.extend((line, "text", payload) for line, _kind, payload in japanese_text_runs(name, text))
    return candidates


def tree_candidates(root: Path, names: Iterable[str]) -> list[tuple[str, int, str, bytes]]:
    rows: list[tuple[str, int, str, bytes]] = []
    for name in names:
        text = (root / name).read_text(encoding="utf-8", errors="replace")
        rows.extend((name, line, form, value) for line, form, value in file_candidates(name, text))
    return rows


def holder_counts(windows: set[bytes], payloads: Iterable[bytes]) -> dict[int, int]:
    """For each wanted 8-byte window, the number of payloads that hold it (keyed by the
    little-endian integer, the form `window_findings` reads). One pass over every position."""
    counts: dict[bytes, int] = dict.fromkeys(windows, 0)
    for payload in payloads:
        seen: set[bytes] = set()
        for index in range(len(payload) - GRAM + 1):
            window = payload[index : index + GRAM]
            if window in counts:
                seen.add(window)
        for window in seen:
            counts[window] += 1
    return {int.from_bytes(window, "little"): count for window, count in counts.items() if count}


def archive_findings(rows: list[tuple[str, int, str, bytes]], payloads: Iterable[bytes]) -> list[Finding]:
    """Apply the rule to every candidate literal against the entries `payloads`."""
    windows = {value[index : index + GRAM] for _n, _l, _f, value in rows for index in range(len(value) - GRAM + 1)}
    holders = holder_counts(windows, payloads)
    findings: list[Finding] = []
    cache: dict[bytes, tuple[list[tuple[int, int]], int | None]] = {}
    for name, line, form, value in rows:
        if value not in cache:
            cache[value] = window_findings(value, holders)
        intervals, fewest = cache[value]
        if intervals and fewest is not None:
            findings.append(Finding(name, line, form, len(value), tuple(intervals), fewest))
    return findings


def scan_tree(root: Path, payloads: Iterable[bytes]) -> list[Finding]:
    """The whole of Part B over `root`; the negative control runs it on an old worktree."""
    return archive_findings(tree_candidates(root, scanned_files(listed_files(root))), payloads)


def failure_message(findings: list[Finding]) -> str:
    return (
        "tracked files hold a window of an original archive entry that fewer than "
        f"{IDIOM_HOLDERS} entries share:\n  "
        + "\n  ".join(finding.describe() for finding in findings)
        + "\n"
        + RULE_FOR_AUTHORS
    )


def japanese(*code_points: int) -> str:
    return "".join(chr(code_point) for code_point in code_points)


class ScannerSelfTests(unittest.TestCase):
    """The scanner against synthetic entries; always runs. No original byte or text is used."""

    def setUp(self) -> None:
        generator = random.Random(1999)
        self.generator = generator
        self.rare = generator.randbytes(16)
        self.idiom = generator.randbytes(16)
        self.entries = [generator.randbytes(400) for _ in range(IDIOM_HOLDERS + 4)]
        self.entries[0] = self.entries[0][:60] + self.rare + self.entries[0][76:]
        for index in range(IDIOM_HOLDERS):
            self.entries[index + 2] = self.entries[index + 2][:100] + self.idiom + self.entries[index + 2][116:]
        # A Japanese run (hiragana and katakana) in one entry's cp932 bytes, and a Hangul string in no entry.
        self.run = japanese(0x3042, 0x3044, 0x3046, 0x3048, 0x30A2)
        self.entries[1] = self.entries[1][:30] + self.run.encode("cp932") + self.entries[1][40:]

    def _scan(self, files: dict[str, str]) -> list[Finding]:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for name, text in files.items():
                path = root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(text, encoding="utf-8")
            return archive_findings(tree_candidates(root, scanned_files(sorted(files))), self.entries)

    def test_a_planted_rare_run_is_found_in_every_extractable_form(self) -> None:
        digits = self.rare.hex()
        spaced = " ".join(f"{value:02x}" for value in self.rare)
        decimal = ",\n    ".join(str(value) for value in self.rare)
        hexed = ", ".join(f"0x{value:02X}" for value in self.rare)
        escaped = "".join(f"\\x{value:02x}" for value in self.rare)
        findings = self._scan(
            {
                "tests/a.py": f"X = bytes.fromhex({digits!r})\n",
                "tests/b.py": f"Y = {self.rare!r}\n",
                "tests/c.py": f"Z = [{decimal}]\n",
                "tests/d.py": f"TABLE = {{'site': {digits!r}}}\n",
                "docs/e.md": f"line one\nhex {digits} here\n",
                "tests/f.gd": f"var x = \"{spaced}\"\n",
                "tests/g.gd": f"var x = PackedByteArray([\n\t{hexed},\n])\n",
                "config/h.json": f'{{"bytes": "{digits}"}}\n',
                "docs/i.md": f"escapes {escaped} end\n",
                "tests/j.py": f"K = bytes.fromhex({digits[:10]!r} + {digits[10:]!r})\n",
            }
        )
        self.assertEqual(
            {"tests/a.py", "tests/b.py", "tests/c.py", "tests/d.py", "docs/e.md", "tests/f.gd", "tests/g.gd", "config/h.json", "docs/i.md", "tests/j.py"},
            {item.path for item in findings},
        )
        by_path = {item.path: item for item in findings}
        self.assertEqual(2, by_path["docs/e.md"].line)
        self.assertEqual(1, by_path["tests/c.py"].line)
        whole = [item for item in findings if item.path != "tests/j.py"]
        self.assertTrue(all(item.form == "bytes" and item.length == 16 and item.fewest_holders == 1 for item in whole))
        self.assertTrue(all(item.intervals == ((0, 16),) for item in whole))
        # A composed string is read as the whole it forms (and its larger piece is a literal too).
        self.assertIn(16, [item.length for item in findings if item.path == "tests/j.py"])

    def test_what_the_rule_does_not_cover_is_not_reported(self) -> None:
        # Each run is planted in an entry, so the windows are rare, but the interval is a chance class.
        ascii_run = b"ABCDEFGHIJKLMNOPQRSTUVWX"
        padded = b"EnumDisplayModes" + bytes(3)
        low = bytes([7, 9, 7, 9, 9, 7, 7, 9, 7, 9, 9, 9, 7, 7, 9, 7])
        ladder = bytes([0x05, 0x06, 0x07, 0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E])
        entries = list(self.entries)
        entries[3] = entries[3][:10] + ascii_run + padded + low + ladder + entries[3][10 + len(ascii_run) + len(padded) + len(low) + len(ladder):]
        seven = self.rare[:7]
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "tests").mkdir()
            (root / "tests" / "chance.py").write_text(
                f"A = {ascii_run!r}\nB = {padded!r}\nC = {low!r}\nD = {ladder!r}\nE = bytes.fromhex({seven.hex()!r})\n"
                f"F = bytes.fromhex({self.idiom.hex()!r})\n",
                encoding="utf-8",
            )
            (root / "tests" / "other.md").write_text(f"hex {seven.hex()}\nvalue 0x{self.rare.hex()}\n", encoding="utf-8")
            (root / "analysis").mkdir()
            (root / "analysis" / "pasted.md").write_text(f"hex {self.rare.hex()}\n", encoding="utf-8")
            (root / "other.json").write_text(f'{{"x": "{self.rare.hex()}"}}\n', encoding="utf-8")
            findings = archive_findings(tree_candidates(root, scanned_files(["tests/chance.py", "tests/other.md", "analysis/pasted.md", "other.json"])), entries)
        self.assertEqual([], findings)

    def test_a_run_held_by_the_idiom_bar_is_the_format_and_not_reported(self) -> None:
        source = f"A = bytes.fromhex({self.idiom.hex()!r})\n"
        self.assertEqual([], self._scan({"tests/idiom.py": source}), "100 holders is the bar: the format's command encoding")
        # One holder fewer makes the same run a finding, and the finding counts the holders.
        for removed, expected in ((1, IDIOM_HOLDERS - 1), (6, IDIOM_HOLDERS - 6)):
            fewer = list(self.entries)
            for index in range(2, 2 + removed):
                fewer[index] = self.generator.randbytes(400)
            with tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                (root / "tests").mkdir()
                (root / "tests" / "idiom.py").write_text(source, encoding="utf-8")
                counted = archive_findings(tree_candidates(root, ["tests/idiom.py"]), fewer)
            self.assertEqual([expected], [item.fewest_holders for item in counted])

    def test_a_japanese_run_is_found_as_text_and_what_is_not_original_is_not(self) -> None:
        hangul = japanese(0xAC00, 0xAC01, 0xAC02, 0xAC03, 0xAC04)
        short = self.run[:3]
        findings = self._scan(
            {
                "docs/text.md": f"title\nthe run {self.run} inside prose\n",
                "tests/text.py": f"NAME = {self.run!r}\nHANGUL = {hangul!r}\nSHORT = {short!r}\n",
                "config/text.json": '{"label": "' + self.run + '"}\n',
                "tests/escaped.gd": "var x = \"" + "".join(f"\\u{ord(char):04x}" for char in self.run) + "\"\n",
            }
        )
        self.assertEqual(
            {"docs/text.md", "tests/text.py", "config/text.json", "tests/escaped.gd"}, {item.path for item in findings}
        )
        self.assertTrue(all(item.form == "text" and item.length == 10 and item.fewest_holders == 1 for item in findings))
        self.assertEqual(2, {item.path: item for item in findings}["docs/text.md"].line)

    def test_a_failure_names_no_byte_and_no_text(self) -> None:
        digits = self.rare.hex()
        findings = self._scan({"tests/a.py": f"X = bytes.fromhex({digits!r})\n", "docs/t.md": f"{self.run}\n"})
        message = failure_message(findings)
        self.assertNotIn(digits, message)
        self.assertNotIn(self.run, message)
        self.assertNotIn(self.run.encode("cp932").hex(), message)
        self.assertIn("tests/a.py:1 (bytes, 16 bytes, rare at offsets 0-16, fewest holders 1)", message)
        self.assertIn("docs/t.md:1 (text, 10 bytes", message)
        self.assertIn("There is no allowlist.", message)
        self.assertIn("100", message)

    def test_the_file_list_follows_git_and_covers_config(self) -> None:
        names = listed_files(ROOT)
        self.assertIn("tests/test_no_original_archive_bytes.py", names)
        self.assertFalse([name for name in names if name.startswith(("analysis/", "assets/", "data/"))])
        scanned = scanned_files(names)
        self.assertIn("tools/inspect_normal_talk.py", scanned)
        self.assertTrue([name for name in scanned if name.startswith("config/")])
        self.assertTrue([name for name in scanned if "/" not in name and name.endswith(".md")])
        self.assertFalse([name for name in scanned if name.startswith(("analysis/", "assets/"))])

    def test_the_helper_needs_both_variables_and_reads_nothing_else(self) -> None:
        self.assertEqual("KAKYU_MES_ARC", original_archives.MES_VARIABLE)
        self.assertEqual("KAKYU_DATA_ARC", original_archives.DATA_VARIABLE)
        self.assertIn("KAKYU_MES_ARC and KAKYU_DATA_ARC are not set", original_archives.SKIP_REASON)
        names = {original_archives.MES_VARIABLE, original_archives.DATA_VARIABLE}
        with mock.patch.dict(os.environ):
            for name in names:
                os.environ.pop(name, None)
            self.assertIsNone(original_archives.environment_paths())
            os.environ[original_archives.MES_VARIABLE] = "mes.arc"
            self.assertIsNone(original_archives.environment_paths(), "one variable alone is not enough")
            os.environ[original_archives.DATA_VARIABLE] = "   "
            self.assertIsNone(original_archives.environment_paths(), "a blank value is not a path")
            os.environ[original_archives.DATA_VARIABLE] = "data.arc"
            self.assertEqual((Path("mes.arc"), Path("data.arc")), original_archives.environment_paths())
        with mock.patch.dict(os.environ):
            for name in names:
                os.environ.pop(name, None)
            with self.assertRaises(original_archives.OriginalArchivesError):
                original_archives.entries()

    def test_the_helper_reads_the_payloads_of_a_synthetic_archive_in_order(self) -> None:
        from extract_kakyu_arc import ENTRY_SIZE, NAME_KEY, OFFSET_KEY, SIZE_KEY

        payloads = [bytes([1, 2, 3, 4]), b"", bytes(range(9))]
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "synthetic.arc"
            offset = 4 + len(payloads) * ENTRY_SIZE
            records = bytearray()
            for index, payload in enumerate(payloads):
                name = bytearray([NAME_KEY] * 256)
                for position, value in enumerate(f"E{index}.MES".encode("ascii")):
                    name[position] = value ^ NAME_KEY
                records += bytes(name) + struct.pack("<I", len(payload) ^ SIZE_KEY) + struct.pack("<I", offset ^ OFFSET_KEY)
                offset += len(payload)
            path.write_bytes(struct.pack("<I", len(payloads)) + bytes(records) + b"".join(payloads))
            self.assertEqual(payloads, original_archives.read_archive_entries(path))
            path.write_bytes(path.read_bytes()[:-3])
            with self.assertRaises(original_archives.OriginalArchivesError):
                original_archives.read_archive_entries(path)


@original_archives.requires_original_archives
class ArchiveGuardTests(unittest.TestCase):
    """Part B: no tracked file holds a rare window of the user's own archives."""

    def test_no_tracked_file_holds_a_rare_window_of_an_original_archive_entry(self) -> None:
        payloads = original_archives.entries()
        started = time.monotonic()
        findings = scan_tree(ROOT, payloads)
        elapsed = time.monotonic() - started
        self.assertEqual([], findings, failure_message(findings))
        self.assertLess(elapsed, SCAN_BUDGET_SECONDS, f"the scan took {elapsed:.1f} s of its {SCAN_BUDGET_SECONDS} s budget")


if __name__ == "__main__":
    unittest.main()
