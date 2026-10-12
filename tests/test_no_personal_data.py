"""No personal data in tracked files (WD-25 item 1b, D7). Local: it needs no archive and no executable.

It refuses, in every file `git ls-files --cached --others --exclude-standard` lists:

1. **Profile paths.** A drive path into a user profile (`Users`, `Documents and Settings`), anywhere.
2. **Machine paths outside `tests/`.** Any drive-letter absolute path in `docs/`, `tools/`,
   `content_core/`, `config/` or the root files, except the `C:\\Windows` SystemRoot fallback. Documents
   use the placeholders `<ELFIMAGE>`, `<EXE>` and `<GODOT>`. A bare drive prefix (`"C:\\"` with no path
   after it) is a prefix test, not a path.
3. **The user name.** `USERNAME` and the last component of `USERPROFILE`, read at run time. Skipped when
   absent, generic, or an ASCII name shorter than 6 characters; ASCII names match case-insensitively,
   others exactly.
4. **E-mail addresses.** (a) Any address that is not in the allowed set. (b) The address of
   `git config user.email`, read at run time, wherever it appears - unless it is in the allowed set,
   which takes precedence.

Rules 1, 2 and 4a are portable: the same on every machine. Rules 3 and 4b depend on the machine by design
(they read the environment and the git configuration), so a clean run on one machine says nothing about
another user's name. This file holds no personal value: its examples are assembled at run time from
parts, so none of the patterns appears in it whole. A failure names the file, the line and the rule,
never the matched value.
"""

from __future__ import annotations

import os
import re
import subprocess
import sys
import tempfile
import unittest
from dataclasses import dataclass, field
from pathlib import Path, PureWindowsPath
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tests"))

from tracked_literals import listed_files  # noqa: E402

PROFILE_FOLDERS = ("users", "documents and settings")
SYSTEM_ROOT_TAIL = re.compile(r"windows(?![A-Za-z0-9_])", re.IGNORECASE)
LOCAL_PART_CHARACTERS = frozenset("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._%+-")
DOMAIN = re.compile(r"[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,}")
PATH_CHARACTER_AFTER_SEPARATOR = frozenset("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_.$~-")
ALLOWED_EMAIL = re.compile(
    r"(?:[^@]+@users\.noreply\.github\.com"
    r"|noreply@anthropic\.com"
    r"|git@github\.com"
    r"|[^@]+@example\.(?:com|net|org)"
    r"|[^@]+@(?:[A-Za-z0-9-]+\.)*[A-Za-z0-9-]+\.(?:example|invalid|test|localhost))",
    re.IGNORECASE,
)
GENERIC_USER_NAMES = frozenset(
    {"user", "admin", "administrator", "runneradmin", "guest", "default", "public", "test"}
)
MINIMUM_ASCII_NAME_LENGTH = 6
RULE_NAMES = {
    "1": "profile path",
    "2": "machine path outside tests/",
    "3": "user name",
    "4a": "e-mail address",
    "4b": "configured git e-mail",
}


@dataclass(frozen=True)
class Violation:
    rule: str
    path: str
    line: int

    def describe(self) -> str:
        return f"{self.path}:{self.line} rule {self.rule} ({RULE_NAMES[self.rule]})"


@dataclass(frozen=True)
class Context:
    """What rules 3 and 4b read at run time."""

    user_names: frozenset[str] = field(default_factory=frozenset)
    git_email: str | None = None


def usable_user_names(candidates: list[str]) -> frozenset[str]:
    names = set()
    for candidate in candidates:
        name = candidate.strip()
        if not name or name.lower() in GENERIC_USER_NAMES:
            continue
        if name.isascii() and len(name) < MINIMUM_ASCII_NAME_LENGTH:
            continue
        names.add(name)
    return frozenset(names)


def git_user_email(root: Path) -> str | None:
    try:
        result = subprocess.run(
            ["git", "config", "user.email"], cwd=root, capture_output=True, text=True, check=False
        )
    except OSError:
        return None
    value = result.stdout.strip() if result.returncode == 0 else ""
    return value or None


def current_context(root: Path = ROOT) -> Context:
    profile_name = PureWindowsPath(os.environ.get("USERPROFILE", "")).name
    return Context(
        user_names=usable_user_names([os.environ.get("USERNAME", ""), profile_name]),
        git_email=git_user_email(root),
    )


def _line(text: str, position: int) -> int:
    return text.count("\n", 0, position) + 1


def _ascii_alphanumeric(character: str) -> bool:
    return character.isascii() and character.isalnum()


def _drive_paths(text: str):
    """`(position, drive letter, index after the separators)` for every drive-letter path start: a letter
    not preceded by a letter or digit, a colon and one or more slashes or backslashes."""
    seen: set[int] = set()
    for separator in (":/", ":\\"):
        index = text.find(separator)
        while index >= 0:
            drive = index - 1
            if (
                drive >= 0
                and text[drive].isascii()
                and text[drive].isalpha()
                and (drive == 0 or not _ascii_alphanumeric(text[drive - 1]))
                and drive not in seen
            ):
                seen.add(drive)
                end = index + 1
                while end < len(text) and text[end] in "\\/":
                    end += 1
                yield drive, text[drive], end
            index = text.find(separator, index + 1)


def _email_matches(text: str):
    """`(position, address)` for every address-shaped string: the maximal local part before an at sign
    and the longest domain with a letters-only top-level domain after it."""
    index = text.find("@")
    while index >= 0:
        begin = index
        while begin > 0 and text[begin - 1] in LOCAL_PART_CHARACTERS and index - begin < 64:
            begin -= 1
        domain = DOMAIN.match(text, index + 1)
        if begin < index and domain:
            yield begin, text[begin : domain.end()]
        index = text.find("@", index + 1)


def scan_text(path: str, text: str, context: Context) -> list[Violation]:
    found: list[Violation] = []
    for position, drive, end in _drive_paths(text):
        tail = text[end : end + 24].lower()
        for folder in PROFILE_FOLDERS:
            if tail.startswith(folder) and not _ascii_alphanumeric_or_underscore(text, end + len(folder)):
                found.append(Violation("1", path, _line(text, position)))
        if path.startswith("tests/") or end >= len(text) or text[end] not in PATH_CHARACTER_AFTER_SEPARATOR:
            continue
        if drive.upper() == "C" and SYSTEM_ROOT_TAIL.match(text[end : end + 8]):
            continue
        found.append(Violation("2", path, _line(text, position)))
    folded = None
    for name in sorted(context.user_names):
        if name.isascii():
            folded = text.lower() if folded is None else folded
            needle, haystack = name.lower(), folded
        else:
            needle, haystack = name, text
        position = haystack.find(needle)
        while position >= 0:
            found.append(Violation("3", path, _line(text, position)))
            position = haystack.find(needle, position + len(needle))
    for position, address in _email_matches(text):
        if not ALLOWED_EMAIL.fullmatch(address):
            found.append(Violation("4a", path, _line(text, position)))
    email = context.git_email
    if email and not ALLOWED_EMAIL.fullmatch(email):
        folded = text.lower() if folded is None else folded
        needle = email.lower()
        position = folded.find(needle)
        while position >= 0:
            found.append(Violation("4b", path, _line(text, position)))
            position = folded.find(needle, position + len(needle))
    return found


def _ascii_alphanumeric_or_underscore(text: str, index: int) -> bool:
    return index < len(text) and (_ascii_alphanumeric(text[index]) or text[index] == "_")


def scan_tree(root: Path, context: Context) -> list[Violation]:
    violations: list[Violation] = []
    for name in listed_files(root):
        data = (root / name).read_bytes()
        if b"\0" in data[:8192]:
            continue
        violations.extend(scan_text(name, data.decode("utf-8", errors="replace"), context))
    return violations


def failure_message(violations: list[Violation]) -> str:
    return (
        "tracked files hold personal data:\n  "
        + "\n  ".join(item.describe() for item in violations)
        + "\nUse a synthetic value (a made-up directory or name) in tests and the <ELFIMAGE>, <EXE> and "
        "<GODOT> placeholders in documents. Rules 3 and 4b read this machine's user name and git e-mail at "
        "run time; the failure never prints the value."
    )


def _assemble(*parts: str) -> str:
    return "".join(parts)


class PortableRuleTests(unittest.TestCase):
    """Rules 1, 2 and 4a: the same on every machine."""

    def _scan(self, path: str, text: str, context: Context = Context()) -> list[tuple[str, int]]:
        return [(item.rule, item.line) for item in scan_text(path, text, context)]

    def test_profile_paths_are_refused_anywhere_in_either_slash_and_escaped_form(self) -> None:
        for separator in ("\\", "/", "\\\\"):
            for folder in ("Users", "users", "Documents and Settings"):
                text = _assemble("see D", ":", separator, folder, separator, "someone", separator, "x\n")
                with self.subTest(separator=separator, folder=folder):
                    self.assertEqual([("1", 1)], [r for r in self._scan("tests/a.py", text) if r[0] == "1"])
                    self.assertEqual(
                        [("1", 1)], [r for r in self._scan("docs/a.md", text) if r[0] == "1"]
                    )

    def test_a_profile_word_without_a_drive_or_with_a_longer_name_is_not_a_profile_path(self) -> None:
        for text in (
            _assemble("res", "://", "Users", "/x"),
            _assemble("C", ":", "\\", "Usersettings"),
            _assemble("see the Users folder"),
            _assemble("user", "://", "Users"),
        ):
            with self.subTest(text=text):
                self.assertEqual([], [r for r in self._scan("docs/a.md", text) if r[0] == "1"])

    def test_machine_paths_are_refused_outside_tests_but_not_inside(self) -> None:
        text = _assemble("--elfimage \"D", ":", "/", "games/dir\"\n")
        self.assertEqual([("2", 1)], self._scan("docs/a.md", text))
        self.assertEqual([("2", 1)], self._scan("tools/a.py", text))
        self.assertEqual([("2", 1)], self._scan("config/a.json", text))
        self.assertEqual([("2", 1)], self._scan("README.md", text))
        self.assertEqual([], self._scan("tests/a.py", text))

    def test_the_system_root_fallback_and_bare_drive_prefixes_are_allowed(self) -> None:
        allowed = (
            _assemble("C", ":", "\\", "Windows"),
            _assemble("c", ":", "/", "WINDOWS", "/System32"),
            _assemble("C", ":", "\\\\", "Windows"),
            _assemble("Contains(\"C", ":", "\\", "\")"),
            _assemble("path = \"D", ":", "/", "\""),
        )
        for text in allowed:
            with self.subTest(text=text):
                self.assertEqual([], self._scan("tools/a.py", text))
        self.assertEqual(
            [("2", 1)], self._scan("tools/a.py", _assemble("D", ":", "\\", "Windows"))
        )
        self.assertEqual(
            [("2", 1)], self._scan("tools/a.py", _assemble("C", ":", "\\", "Windowsish"))
        )

    def test_url_schemes_and_godot_paths_are_not_drive_paths(self) -> None:
        for text in ("res://tools/a.gd", "user://save", "uid://abc", "https://example.org/x", "file:///tmp/x"):
            with self.subTest(text=text):
                self.assertEqual([], self._scan("docs/a.md", text))

    def test_email_addresses_outside_the_allowed_set_are_refused(self) -> None:
        refused = (
            _assemble("someone", "@", "company", ".com"),
            _assemble("a.b+c", "@", "mail.corp", ".co.kr"),
            _assemble("name", "@", "gmail", ".com"),
        )
        for address in refused:
            with self.subTest(address="refused"):
                self.assertEqual([("4a", 2)], self._scan("docs/a.md", f"line\ncontact {address}\n"))

    def test_the_allowed_set_passes(self) -> None:
        allowed = (
            _assemble("12345+someone", "@", "users.noreply.github", ".com"),
            _assemble("noreply", "@", "anthropic", ".com"),
            _assemble("git", "@", "github", ".com"),
            _assemble("a", "@", "example", ".com"),
            _assemble("a", "@", "example", ".net"),
            _assemble("a", "@", "example", ".org"),
            _assemble("a", "@", "host.example"),
            _assemble("a", "@", "host.invalid"),
            _assemble("a", "@", "host.test"),
            _assemble("a", "@", "box.localhost"),
        )
        for address in allowed:
            with self.subTest(address="allowed"):
                self.assertEqual([], self._scan("docs/a.md", f"mail {address}\n"))

    def test_decorators_version_pins_and_identifiers_are_not_addresses(self) -> None:
        text = (
            "@export var x\n@dataclass\npip install pkg@1.2.3\nnpm i left@latest\n"
            "uid://b8k2ndtv\nres://a@b\nclass A: @staticmethod\n"
        )
        self.assertEqual([], self._scan("tests/a.gd", text))


class MachineDependentRuleTests(unittest.TestCase):
    """Rules 3 and 4b read the machine; here they run on synthetic values."""

    def test_user_name_candidates_skip_absent_generic_and_short_ascii_names(self) -> None:
        korean = _assemble(chr(0xAC00), chr(0xAC01))
        names = usable_user_names(
            ["", "Admin", "runneradmin", "Guest", "bob", "tester", "longername", korean]
        )
        self.assertEqual(frozenset({"tester", "longername", korean}), names)

    def test_ascii_names_match_case_insensitively_and_others_exactly(self) -> None:
        context = Context(user_names=frozenset({"zzsynthuser", _assemble(chr(0xAC00), chr(0xAC01))}))
        found = scan_text("docs/a.md", "x ZzSynthUser y\nlast\nZZSYNTHUSER\n", context)
        self.assertEqual([("3", 1), ("3", 3)], sorted((item.rule, item.line) for item in found))
        hangul = _assemble(chr(0xAC00), chr(0xAC01))
        self.assertEqual([("3", 1)], [(i.rule, i.line) for i in scan_text("docs/a.md", f"{hangul}\n", context)])
        self.assertEqual([], scan_text("docs/a.md", _assemble(chr(0xAC00), chr(0xAC02)), context))

    def test_the_configured_address_is_refused_wherever_it_appears(self) -> None:
        address = _assemble("owner.person", "@", "private-mail", ".com")
        context = Context(git_email=address)
        found = scan_text("tests/a.py", f"first\nx = '{address.upper()}'\n", context)
        self.assertEqual(
            [("4a", 2), ("4b", 2)], sorted((item.rule, item.line) for item in found)
        )

    def test_the_allowed_set_takes_precedence_over_the_configured_address(self) -> None:
        address = _assemble("12345+owner", "@", "users.noreply.github", ".com")
        self.assertEqual([], scan_text("docs/a.md", f"co-author {address}\n", Context(git_email=address)))
        self.assertEqual([], scan_text("docs/a.md", "plain text\n", Context(git_email=None)))

    def test_the_context_reads_the_environment_and_git_at_run_time(self) -> None:
        profile = _assemble("C", ":", "\\", "Users", "\\", "synthlongname")
        with mock.patch.dict(os.environ, {"USERNAME": "synthaccount", "USERPROFILE": profile}):
            with mock.patch.object(sys.modules[__name__], "git_user_email", return_value=None):
                context = current_context()
        self.assertEqual(frozenset({"synthaccount", "synthlongname"}), context.user_names)
        self.assertIsNone(context.git_email)

    def test_the_context_survives_an_unset_environment(self) -> None:
        with mock.patch.dict(os.environ):
            os.environ.pop("USERNAME", None)
            os.environ.pop("USERPROFILE", None)
            with mock.patch.object(sys.modules[__name__], "git_user_email", return_value=None):
                self.assertEqual(Context(), current_context())

    def test_git_without_the_setting_or_without_git_gives_none(self) -> None:
        with mock.patch.object(subprocess, "run", side_effect=OSError("no git")):
            self.assertIsNone(git_user_email(ROOT))
        failed = subprocess.CompletedProcess(["git"], 1, stdout="", stderr="")
        with mock.patch.object(subprocess, "run", return_value=failed):
            self.assertIsNone(git_user_email(ROOT))


class TreeScanTests(unittest.TestCase):
    def test_a_temporary_tree_reports_each_rule_with_file_line_and_no_value(self) -> None:
        profile_line = _assemble("D", ":", "/", "Users", "/", "someone", "/", "dir")
        machine_line = _assemble("E", ":", "\\", "games", "\\", "dir")
        address = _assemble("person", "@", "company", ".com")
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "docs").mkdir()
            (root / "tests").mkdir()
            (root / "docs" / "a.md").write_text(f"ok\n{machine_line}\nname zzsynthuser\n", encoding="utf-8")
            (root / "tests" / "b.py").write_text(f"x = '{profile_line}'\n# {address}\n", encoding="utf-8")
            (root / "tests" / "blob.bin").write_bytes(bytes(100) + machine_line.encode("ascii"))
            violations = scan_tree(root, Context(user_names=frozenset({"zzsynthuser"})))
        self.assertEqual(
            [("docs/a.md", 2, "2"), ("docs/a.md", 3, "3"), ("tests/b.py", 1, "1"), ("tests/b.py", 2, "4a")],
            sorted((item.path, item.line, item.rule) for item in violations),
        )
        message = failure_message(violations)
        for value in (profile_line, machine_line, address, "zzsynthuser", "someone"):
            self.assertNotIn(value, message)
        self.assertIn("docs/a.md:2 rule 2", message)

    def test_the_tracked_tree_holds_no_personal_data(self) -> None:
        violations = scan_tree(ROOT, current_context())
        self.assertEqual([], violations, failure_message(violations))


if __name__ == "__main__":
    unittest.main()
