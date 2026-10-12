"""No tracked file holds a copy of a region of the original executable (WD-25 item 1).

Part A is local and always runs. In every `tools/*.py` that reads the executable
there must be no module-level byte literal of 8 bytes or more.

Part B needs the user's own executable (`KAKYU_ORIGINAL_EXE`) and asserts that no
literal of 8 bytes or more, with at least 5 distinct values and not printable
ASCII, occurs verbatim in it, anywhere in the files the release build would ship
or this repository tracks (`tools/`, `tests/`, `content_core/`, `docs/`,
`config/ai5_exe_audit/` and the root `*.md` files).

This module imports no audit module: Part B needs only the variable and the raw
file, so the guard keeps working in a tree without the native audits.

How a test author stays inside the rule: a synthetic byte sequence of 8 bytes or
more must carry a synthetic immediate (for example a pointer such as
0x01234567); generic x86 idioms of that length occur in the original
executable. There is no allowlist.
"""

from __future__ import annotations

import ast
import random
import sys
import tempfile
import unittest
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tests"))

import original_executable  # noqa: E402
import tracked_literals  # noqa: E402
from tracked_literals import (  # noqa: E402
    is_printable_ascii,
    listed_files,
    python_byte_literals,
    python_hex_strings,
    text_hex_literals,
)

MINIMUM_BYTES = 8
MINIMUM_DISTINCT_VALUES = 5
SCANNED_PREFIXES = ("tools/", "tests/", "content_core/", "docs/", "config/ai5_exe_audit/")
TEXT_SUFFIXES = (".gd", ".md", ".json")

RULE_FOR_AUTHORS = (
    "A synthetic byte sequence of 8 bytes or more must carry a synthetic immediate (for example a "
    "pointer such as 0x01234567); generic x86 idioms of that length occur in the original "
    "executable. There is no allowlist."
)


@dataclass(frozen=True)
class Finding:
    path: str
    line: int
    length: int
    occurrences: int = 0

    def describe(self) -> str:
        counted = f", {self.occurrences} occurrence(s) in the executable" if self.occurrences else ""
        return f"{self.path}:{self.line} ({self.length} bytes{counted})"


def reads_the_executable(source: str) -> bool:
    """True when a tool defines or imports `PeImage` or imports an `audit_ai5_*` module."""
    tree = ast.parse(source)
    for node in ast.walk(tree):
        if isinstance(node, ast.ClassDef) and node.name == "PeImage":
            return True
        if isinstance(node, ast.ImportFrom):
            if (node.module or "").startswith("audit_ai5_") or any(alias.name == "PeImage" for alias in node.names):
                return True
        if isinstance(node, ast.Import) and any(alias.name.startswith("audit_ai5_") for alias in node.names):
            return True
    return False


def structural_findings(root: Path) -> list[Finding]:
    """Part A: module-level byte literals of 8 bytes or more in the tools that read the executable."""
    findings: list[Finding] = []
    for path in sorted((root / "tools").glob("*.py")):
        source = path.read_text(encoding="utf-8")
        if not reads_the_executable(source):
            continue
        for line, value in python_byte_literals(source, module_level_only=True):
            if len(value) >= MINIMUM_BYTES and not is_printable_ascii(value):
                findings.append(Finding(path.relative_to(root).as_posix(), line, len(value)))
    return findings


def scanned_files(names: list[str]) -> list[str]:
    return tracked_literals.scanned_files(names, SCANNED_PREFIXES, (".py", *TEXT_SUFFIXES))


def executable_findings(root: Path, names: list[str], executable: bytes) -> list[Finding]:
    """Part B: literals of 8+ bytes, 5+ distinct values, not printable ASCII, verbatim in `executable`."""
    findings: list[Finding] = []
    cache: dict[bytes, int] = {}
    for name in names:
        text = (root / name).read_text(encoding="utf-8", errors="replace")
        if name.endswith(".py"):
            literals = list(
                dict.fromkeys(
                    python_byte_literals(text, module_level_only=False, hex_strings=True)
                    + python_hex_strings(text)
                )
            )
        else:
            literals = text_hex_literals(text)
        for line, value in literals:
            if len(value) < MINIMUM_BYTES or len(set(value)) < MINIMUM_DISTINCT_VALUES:
                continue
            if is_printable_ascii(value):
                continue
            if value not in cache:
                cache[value] = executable.count(value)
            if cache[value]:
                findings.append(Finding(name, line, len(value), cache[value]))
    return findings


def scan_tree(root: Path, executable: bytes) -> list[Finding]:
    """The whole of Part B over `root`; the negative control runs it on an old worktree."""
    return executable_findings(root, scanned_files(listed_files(root)), executable)


def failure_message(findings: list[Finding]) -> str:
    return (
        "tracked files hold a copy of the original executable:\n  "
        + "\n  ".join(finding.describe() for finding in findings)
        + "\n"
        + RULE_FOR_AUTHORS
    )


class StructuralGuardTests(unittest.TestCase):
    """Part A: local, always runs."""

    def test_tools_that_read_the_executable_hold_no_module_level_byte_literal(self) -> None:
        findings = structural_findings(ROOT)
        self.assertEqual([], findings, failure_message(findings))

    def test_the_guard_covers_the_tools_that_read_the_executable(self) -> None:
        covered = [
            path.name
            for path in (ROOT / "tools").glob("*.py")
            if reads_the_executable(path.read_text(encoding="utf-8"))
        ]
        for name in ("audit_ai5_arc_exe.py", "audit_ai5_audio_exe.py", "audit_ai5_mes_exe.py"):
            if (ROOT / "tools" / name).is_file():
                self.assertIn(name, covered)

    def test_the_guard_imports_no_audit_module(self) -> None:
        tree = ast.parse(Path(__file__).read_text(encoding="utf-8"))
        for node in ast.walk(tree):
            if isinstance(node, ast.ImportFrom):
                self.assertFalse((node.module or "").startswith("audit_ai5_"))
            if isinstance(node, ast.Import):
                self.assertFalse(any(alias.name.startswith("audit_ai5_") for alias in node.names))

    def test_the_structural_scanner_finds_only_what_the_rule_names(self) -> None:
        planted = random.Random(11).randbytes(16)
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "tools").mkdir()
            (root / "tools" / "reader.py").write_text(
                "from audit_ai5_arc_exe import PeImage\n"
                f"PLANTED = bytes.fromhex({planted.hex()!r})\n"
                f"EIGHT = bytes.fromhex({planted[:8].hex()!r})\n"
                f"SEVEN = bytes.fromhex({planted[:7].hex()!r})\n"
                f"TEXT = {b'ABCDEFGHIJKLMNOPQRSTUVWX'!r}\n"
                f"NAME = {b'EnumDisplayModes' + bytes(1)!r}\n"
                f"INTERIOR = {b'ABCDEFGH' + bytes(1) + b'IJKLMNOP'!r}\n"
                "def local():\n"
                f"    return bytes.fromhex({planted.hex()!r})\n",
                encoding="utf-8",
            )
            (root / "tools" / "other.py").write_text(
                f"PLANTED = bytes.fromhex({planted.hex()!r})\n", encoding="utf-8"
            )
            findings = structural_findings(root)
        self.assertEqual(
            [("tools/reader.py", 2, 16), ("tools/reader.py", 3, 8), ("tools/reader.py", 7, 17)],
            sorted((item.path, item.line, item.length) for item in findings),
        )

    def test_the_scanners_name_no_byte_in_a_failure(self) -> None:
        planted = random.Random(12).randbytes(16)
        message = failure_message([Finding("tools/x.py", 3, len(planted), 2)])
        self.assertNotIn(planted.hex(), message)
        self.assertIn("tools/x.py:3 (16 bytes, 2 occurrence(s)", message)
        self.assertIn("synthetic immediate", message)
        self.assertIn("There is no allowlist.", message)


class ExecutableScannerSelfTests(unittest.TestCase):
    """The Part B scanner against a synthetic executable of random bytes; always runs."""

    def setUp(self) -> None:
        generator = random.Random(2026)
        self.interior = b"ABCDEFGH" + bytes(1) + b"IJKLMNOP"
        self.padded = b"EnumDisplayModes" + bytes(3)
        self.executable = (
            generator.randbytes(2048)
            + bytes(48)
            + b"ABCDEFGHIJKLMNOPQRSTUVWX"
            + self.interior
            + self.padded
            + generator.randbytes(2048)
        )
        self.planted = self.executable[100:116]

    def _scan(self, files: dict[str, str]) -> list[Finding]:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for name, text in files.items():
                path = root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(text, encoding="utf-8")
            return executable_findings(root, scanned_files(sorted(files)), self.executable)

    def test_a_planted_verbatim_literal_is_found_in_every_extractable_form(self) -> None:
        digits = self.planted.hex()
        spaced = " ".join(f"{value:02x}" for value in self.planted)
        findings = self._scan(
            {
                "tools/a.py": f"X = bytes.fromhex({digits!r})\n",
                "tests/b.py": f"Y = bytes.fromhex({digits[:16]!r} {digits[16:]!r})\n",
                "tests/c.py": f"Z = {self.planted!r}\n",
                "tests/h.py": f"TABLE = {{'site': {digits!r}}}\n",
                "docs/d.md": f"line one\nhex {digits} here\n",
                "tests/e.gd": f"var x = \"{spaced}\"\n",
                "config/ai5_exe_audit/f.json": f'{{"bytes": "{digits}"}}\n',
                "tests/j.py": f"K = bytes.fromhex({digits[:10]!r} + {digits[10:20]!r} + {digits[20:]!r})\n",
            }
        )
        self.assertEqual(
            {
                "tools/a.py",
                "tests/b.py",
                "tests/j.py",
                "tests/c.py",
                "docs/d.md",
                "tests/e.gd",
                "tests/h.py",
                "config/ai5_exe_audit/f.json",
            },
            {item.path for item in findings},
        )
        by_path = {item.path: item for item in findings}
        self.assertEqual(2, by_path["docs/d.md"].line)
        self.assertTrue(all(item.length == 16 and item.occurrences == 1 for item in findings))

    def test_what_the_rule_does_not_cover_is_not_reported(self) -> None:
        zeros = bytes(16)
        ascii_text = b"ABCDEFGHIJKLMNOPQRSTUVWX"
        seven = self.executable[200:207]
        partial = self.executable[300:308] + bytes([0xA5, 0x5A, 0xA5, 0x5A])
        decimal_list = list(self.executable[400:410])
        findings = self._scan(
            {
                "tools/low_entropy.py": f"A = bytes.fromhex({zeros.hex()!r})\n",
                "tools/ascii.py": f"B = {ascii_text!r}\nC = bytes.fromhex({ascii_text.hex()!r})\n",
                "tools/seven.py": f"D = bytes.fromhex({seven.hex()!r})\n",
                "tools/partial.py": f"E = bytes.fromhex({partial.hex()!r})\n",
                "docs/seven.md": f"hex {seven.hex()}\n",
                "docs/hex_number.md": f"value 0x{self.planted.hex()}\n",
                "tests/ints.py": f"F = bytes({decimal_list!r})\nG = {decimal_list!r}\n",
                "tests/ints.gd": f"var x = {decimal_list!r}\n",
                "analysis/pasted.md": f"hex {self.planted.hex()}\n",
                "assets/pasted.json": f'{{"x": "{self.planted.hex()}"}}\n',
                "config/other.json": f'{{"x": "{self.planted.hex()}"}}\n',
            }
        )
        self.assertEqual([], findings)

    def test_an_interior_nul_is_not_text_but_trailing_padding_is(self) -> None:
        findings = self._scan(
            {
                "tools/interior.py": f"A = {self.interior!r}\n",
                "tools/padded.py": f"B = {self.padded!r}\n",
                "tools/padded_hex.py": f"C = bytes.fromhex({self.padded.hex()!r})\n",
            }
        )
        self.assertEqual(["tools/interior.py"], [item.path for item in findings])
        self.assertEqual(17, findings[0].length)

    def test_root_markdown_files_are_scanned_and_other_root_files_are_not(self) -> None:
        findings = self._scan(
            {"NOTES.md": f"hex {self.planted.hex()}\n", "notes.json": f'{{"x": "{self.planted.hex()}"}}\n'}
        )
        self.assertEqual(["NOTES.md"], [item.path for item in findings])

    def test_the_file_list_follows_git_and_skips_ignored_trees(self) -> None:
        names = listed_files(ROOT)
        self.assertIn("tests/test_no_original_executable_bytes.py", names)
        self.assertFalse([name for name in names if name.startswith(("analysis/", "assets/", "data/"))])
        scanned = scanned_files(names)
        self.assertIn("tests/tracked_literals.py", scanned)
        self.assertFalse([name for name in scanned if name.startswith(("analysis/", "assets/"))])


@original_executable.requires_original_executable
class ExecutableGuardTests(unittest.TestCase):
    """Part B: no literal of the user's own executable is tracked."""

    def test_no_tracked_file_holds_a_copy_of_the_original_executable(self) -> None:
        findings = scan_tree(ROOT, original_executable.raw_bytes())
        self.assertEqual([], findings, failure_message(findings))


if __name__ == "__main__":
    unittest.main()
