"""Extraction of byte and text literals from tracked files, shared by the repository's guards.

WD-25 items 1 and 1b. This is a helper, not a test module (test discovery skips it): the guard
`test_no_original_executable_bytes.py` (the user's executable) and the guard
`test_no_original_archive_bytes.py` (the user's `mes.arc` and `data.arc`) import it so that the
extraction exists once. The module level uses only the standard library.

What it extracts
- bytes: `bytes.fromhex(<constant>)`, `bytes` constants, hex-string constants, `bytes([...])` and
  other lists of integers in Python source; contiguous and spaced hex runs, bracketed lists of
  integers and `\\x` escapes in other text;
- text: runs of 4 or more Japanese-script characters, encoded to cp932 (4 double-byte characters are
  8 bytes), from Python string constants, parsed JSON and JSONL strings, `\\u` escapes in other text,
  and raw text. A run cp932 cannot encode (Hangul, for example) cannot be original text and is skipped.

Out of scope, recorded: base64 strings and tracked binary files are not extracted here. The companion
inventory (`analysis/_docs/archive_literals_inventory.py`, with the author) covers them and found nothing.
"""

from __future__ import annotations

import ast
import bisect
import json
import re
import subprocess
from pathlib import Path
from typing import Iterable, Iterator, Mapping

GRAM = 8
# Windows held by this many entries or more are the format's command encoding (a tool decision, with
# a measured basis: today's idioms are held by 78-94% of the 1,016 entries of mes.arc).
IDIOM_HOLDERS = 100
FUNCTION_NODES = (ast.FunctionDef, ast.AsyncFunctionDef, ast.Lambda)

# A contiguous hex run of 16 or more digits (8 or more bytes), delimited by non-identifier
# characters. A run after "0x" is a number, not a byte string: the "x" before it is alphanumeric.
HEX_RUN = re.compile(r"(?<![0-9A-Za-z_])[0-9a-fA-F]{16,}(?![0-9A-Za-z_])")
# A whole string constant that is a run of 16 or more hex digits (an even count).
HEX_STRING = re.compile(r"(?:[0-9a-fA-F]{2}){8,}")
# Eight or more two-digit pairs separated by single spaces.
SPACED_HEX = re.compile(r"(?<![0-9A-Za-z_])(?:[0-9a-fA-F]{2} ){7,}[0-9a-fA-F]{2}(?![0-9A-Za-z_])")
# A bracketed list of integers 0-255, decimal or hex, across lines; four or more items (the caller
# keeps the lists of 8 or more).
INTEGER_LIST = re.compile(
    r"\[((?:\s*(?:0[xX][0-9A-Fa-f]{1,2}|\d{1,3})\s*,){3,}\s*(?:0[xX][0-9A-Fa-f]{1,2}|\d{1,3})\s*,?\s*)\]"
)
ESCAPED_BYTES = re.compile(r"((?:\\x[0-9A-Fa-f]{2}){3,})")
UNICODE_ESCAPES = re.compile(r"(?:\\u[0-9a-fA-F]{4})+")
QUOTED = re.compile(r'"((?:[^"\\\n]|\\.){4,})"')
# Hiragana, katakana, CJK punctuation and ideographs, and full-width forms (written as escapes so this
# file holds no Japanese text).
JAPANESE_RUN = re.compile(
    "[　-〿぀-ゟ゠-ヿ㐀-䶿一-鿿＀-￯]{4,}"
)


def is_printable_ascii(data: bytes) -> bool:
    """Text such as an identifier or a NUL-padded name: printable ASCII, tab, CR and LF anywhere,
    and NUL only as trailing padding (an interior NUL is not text)."""
    return all(32 <= value < 127 or value in (9, 10, 13) for value in data.rstrip(b"\0"))


def small_integer_progression(data: bytes) -> bool:
    """At least 3 distinct values, all below 0x40, spanning at most their count plus one."""
    values = sorted(set(data))
    return len(values) >= 3 and values[-1] - values[0] <= len(values) + 1 and values[-1] < 0x40


def is_chance(data: bytes) -> bool:
    """The classes that can match an archive by chance, never by authorship: printable ASCII,
    fewer than 5 distinct byte values, and a small-integer progression."""
    return is_printable_ascii(data) or len(set(data)) < 5 or small_integer_progression(data)


def _parents(tree: ast.AST) -> dict[ast.AST, ast.AST]:
    parents: dict[ast.AST, ast.AST] = {}
    for parent in ast.walk(tree):
        for child in ast.iter_child_nodes(parent):
            parents[child] = parent
    return parents


def _inside_function(node: ast.AST, parents: dict[ast.AST, ast.AST]) -> bool:
    while node in parents:
        node = parents[node]
        if isinstance(node, FUNCTION_NODES):
            return True
    return False


def _fromhex_call(node: ast.AST) -> bool:
    return (
        isinstance(node, ast.Call)
        and isinstance(node.func, ast.Attribute)
        and node.func.attr == "fromhex"
        and len(node.args) == 1
    )


def _constant_strings(node: ast.AST) -> list[str] | None:
    """The values of a string expression built from constants, `+` and conditionals, or None."""
    if isinstance(node, ast.Constant) and isinstance(node.value, str):
        return [node.value]
    if isinstance(node, ast.IfExp):
        body, orelse = _constant_strings(node.body), _constant_strings(node.orelse)
        return None if body is None or orelse is None else body + orelse
    if isinstance(node, ast.BinOp) and isinstance(node.op, ast.Add):
        left, right = _constant_strings(node.left), _constant_strings(node.right)
        return None if left is None or right is None else [a + b for a in left for b in right]
    return None


def python_byte_literals(
    source: str, *, module_level_only: bool, hex_strings: bool = False
) -> list[tuple[int, bytes]]:
    """`(line, value)` for every `bytes.fromhex(<str constant>)` and every `bytes` constant.

    With `hex_strings`, a string constant that is itself a run of 16 or more hex digits
    counts too (a table of hex strings handed to `bytes.fromhex` through a variable).
    """
    tree = ast.parse(source)
    parents = _parents(tree) if module_level_only else {}
    found: list[tuple[int, bytes]] = []
    fromhex_arguments: set[int] = set()
    for node in ast.walk(tree):
        if _fromhex_call(node):
            fromhex_arguments.add(id(node.args[0]))
    for node in ast.walk(tree):
        value: bytes | None = None
        if (
            isinstance(node, ast.Call)
            and isinstance(node.func, ast.Attribute)
            and node.func.attr == "fromhex"
            and isinstance(node.func.value, ast.Name)
            and node.func.value.id == "bytes"
            and len(node.args) == 1
            and isinstance(node.args[0], ast.Constant)
            and isinstance(node.args[0].value, str)
        ):
            try:
                value = bytes.fromhex(node.args[0].value)
            except ValueError:
                value = None
        elif isinstance(node, ast.Constant) and isinstance(node.value, bytes):
            value = node.value
        elif (
            hex_strings
            and isinstance(node, ast.Constant)
            and isinstance(node.value, str)
            and id(node) not in fromhex_arguments
            and HEX_STRING.fullmatch(node.value)
        ):
            value = bytes.fromhex(node.value)
        if value is None:
            continue
        if module_level_only and _inside_function(node, parents):
            continue
        found.append((node.lineno, value))
    return found


def python_hex_strings(source: str) -> list[tuple[int, bytes]]:
    """`(line, value)` for every composed hex string handed to `bytes.fromhex` and every string
    constant that is a run of 16 or more hex digits (concatenations and conditionals included)."""
    tree = ast.parse(source)
    found: list[tuple[int, bytes]] = []
    consumed: set[int] = set()
    for node in ast.walk(tree):
        if _fromhex_call(node):
            values = _constant_strings(node.args[0])
            for inner in ast.walk(node.args[0]):
                consumed.add(id(inner))
            for text in values or []:
                try:
                    found.append((node.lineno, bytes.fromhex(text)))
                except ValueError:
                    continue
    for node in ast.walk(tree):
        if (
            isinstance(node, ast.Constant)
            and isinstance(node.value, str)
            and id(node) not in consumed
            and HEX_STRING.fullmatch(node.value)
        ):
            found.append((node.lineno, bytes.fromhex(node.value)))
    return found


def python_integer_lists(source: str) -> list[tuple[int, bytes]]:
    """`(line, value)` for every list or tuple of 8 or more integer constants 0-255 (`bytes([...])`
    included), in decimal or hex."""
    found: list[tuple[int, bytes]] = []
    for node in ast.walk(ast.parse(source)):
        if isinstance(node, (ast.List, ast.Tuple)) and len(node.elts) >= GRAM:
            values = []
            for element in node.elts:
                if (
                    isinstance(element, ast.Constant)
                    and type(element.value) is int
                    and 0 <= element.value <= 255
                ):
                    values.append(element.value)
                else:
                    break
            else:
                found.append((node.lineno, bytes(values)))
    return found


class _Lines:
    """Line numbers of offsets in one text, by bisection over its newline offsets (a count from the
    start for every match is quadratic on a multi-megabyte file)."""

    def __init__(self, text: str) -> None:
        self._newlines: list[int] = []
        at = text.find("\n")
        while at >= 0:
            self._newlines.append(at)
            at = text.find("\n", at + 1)

    def of(self, offset: int) -> int:
        return bisect.bisect_left(self._newlines, offset) + 1


def text_hex_literals(text: str) -> list[tuple[int, bytes]]:
    """`(line, value)` for every contiguous or spaced hex run of 8 or more bytes."""
    found: list[tuple[int, bytes]] = []
    lines = _Lines(text)
    for pattern in (HEX_RUN, SPACED_HEX):
        for match in pattern.finditer(text):
            digits = match.group(0).replace(" ", "")
            digits = digits[: len(digits) // 2 * 2]
            found.append((lines.of(match.start()), bytes.fromhex(digits)))
    return found


def integer_list_literals(text: str) -> list[tuple[int, bytes]]:
    """`(line, value)` for every bracketed list of 8 or more integers 0-255 (decimal or hex),
    including lists that span lines."""
    found: list[tuple[int, bytes]] = []
    lines = _Lines(text)
    for match in INTEGER_LIST.finditer(text):
        items = [item.strip() for item in match.group(1).split(",") if item.strip()]
        values = [int(item, 0) for item in items]
        if len(values) >= GRAM and all(0 <= value <= 255 for value in values):
            found.append((lines.of(match.start()), bytes(values)))
    return found


def escaped_byte_literals(text: str) -> list[tuple[int, bytes]]:
    """`(line, value)` for every run of 8 or more `\\xNN` escapes in text."""
    found: list[tuple[int, bytes]] = []
    lines = _Lines(text)
    for match in ESCAPED_BYTES.finditer(text):
        raw = match.group(1)
        if len(raw) // 4 >= GRAM:
            value = bytes(int(raw[index + 2 : index + 4], 16) for index in range(0, len(raw), 4))
            found.append((lines.of(match.start()), value))
    return found


def _json_strings(text: str, suffix: str) -> Iterator[str]:
    if suffix == ".json":
        documents = [text]
    else:
        documents = [line for line in text.splitlines() if line.strip()]
    stack: list[object] = []
    for document in documents:
        try:
            stack.append(json.loads(document))
        except ValueError:
            continue
    while stack:
        node = stack.pop()
        if isinstance(node, dict):
            for key, value in node.items():
                yield key
                stack.append(value)
        elif isinstance(node, list):
            stack.extend(node)
        elif isinstance(node, str):
            yield node


def _tracked_strings(name: str, text: str) -> Iterator[tuple[int, str, str]]:
    """`(line or 0, kind, value)`: the raw text, then the strings the format makes explicit."""
    suffix = Path(name).suffix.lower()
    yield 0, "raw", text
    if suffix == ".py":
        try:
            for node in ast.walk(ast.parse(text)):
                if isinstance(node, ast.Constant) and isinstance(node.value, str):
                    yield node.lineno, "py_str", node.value
        except SyntaxError:
            return
    elif suffix in (".json", ".jsonl"):
        for value in _json_strings(text, suffix):
            yield 0, "json_str", value
    else:
        lines = _Lines(text)
        for match in UNICODE_ESCAPES.finditer(text):
            decoded = match.group(0).encode("ascii").decode("unicode_escape")
            yield lines.of(match.start()), "u_escape", decoded
        for match in QUOTED.finditer(text):
            yield lines.of(match.start()), "quoted", match.group(1)


def japanese_text_runs(name: str, text: str) -> list[tuple[int, str, bytes]]:
    """`(line, kind, cp932 bytes)` for every run of 4 or more Japanese-script characters that
    cp932 can encode (8 or more bytes), once per distinct run per file."""
    found: list[tuple[int, str, bytes]] = []
    seen: set[bytes] = set()
    raw_lines = _Lines(text)
    for line, kind, value in _tracked_strings(name, text):
        for match in JAPANESE_RUN.finditer(value):
            try:
                payload = match.group(0).encode("cp932")
            except UnicodeEncodeError:
                continue
            if len(payload) < GRAM or payload in seen:
                continue
            seen.add(payload)
            at = line or (raw_lines.of(match.start()) if kind == "raw" else 0)
            found.append((at, "text:" + kind, payload))
    return found


def window_findings(
    literal: bytes, holders: Mapping[int, int]
) -> tuple[list[tuple[int, int]], int | None]:
    """The 1b rule for one literal: `(intervals, fewest holders)`.

    `holders` maps an 8-byte window (little-endian integer) to the number of archive entries that
    hold it; an absent window has none. A window is rare when 1 to `IDIOM_HOLDERS - 1` entries hold
    it. Overlapping rare windows merge into intervals, and an interval is a finding unless its
    bytes are a chance class (`is_chance`). Windows held by `IDIOM_HOLDERS` or more entries are the
    format's command encoding and never count.
    """
    rare: list[int] = []
    fewest: int | None = None
    for index in range(len(literal) - GRAM + 1):
        count = holders.get(int.from_bytes(literal[index : index + GRAM], "little"), 0)
        if 1 <= count < IDIOM_HOLDERS:
            rare.append(index)
            fewest = count if fewest is None else min(fewest, count)
    intervals: list[list[int]] = []
    for index in rare:
        if intervals and index <= intervals[-1][1]:
            intervals[-1][1] = index + GRAM
        else:
            intervals.append([index, index + GRAM])
    kept = [(begin, end) for begin, end in intervals if not is_chance(literal[begin:end])]
    return kept, fewest


def listed_files(root: Path) -> list[str]:
    """What the build ships plus what is tracked: `git ls-files --cached --others --exclude-standard`."""
    try:
        output = subprocess.run(
            ["git", "ls-files", "--cached", "--others", "--exclude-standard", "-z"],
            cwd=root,
            capture_output=True,
            check=True,
        ).stdout
        names = {name for name in output.decode("utf-8").split("\0") if name}
    except (OSError, subprocess.CalledProcessError):
        # Not a work tree (a source archive): walk the same trees.
        names = {
            path.relative_to(root).as_posix()
            for path in root.rglob("*")
            if path.is_file() and ".git" not in path.relative_to(root).parts
        }
    return sorted(name for name in names if (root / name).is_file())


def scanned_files(names: Iterable[str], prefixes: tuple[str, ...], suffixes: tuple[str, ...]) -> list[str]:
    """The files under `prefixes` or the root `*.md` files that end in one of `suffixes`."""
    selected = []
    for name in names:
        in_scope = name.startswith(prefixes) or ("/" not in name and name.endswith(".md"))
        if in_scope and name.endswith(suffixes):
            selected.append(name)
    return selected
