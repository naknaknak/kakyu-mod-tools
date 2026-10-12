"""Each validation check's inputs and how they are fingerprinted (TD-32 part 3a).

A pure library - no Godot dependency - importable by
``run_headless_validation.py`` (the ``--fingerprints``/``--fingerprint-inputs``
runner flags) and by its own tests. Part 3a builds the measurement only; there
is no cache here yet (that is part 3b).

The shape: a check's *inputs* are the tracked files its command can read plus
any external archive/executable it needs. `class_index()`/`scan_gd()`/
`scan_tscn()`/`scan_py()` find the references a single file makes; `closure()`
walks them to a fixed point (a BFS with a visited set); `check_inputs()`
decides the closure's start set from a planned check's own command and
context; `fingerprint()` hashes the result into one content-addressed digest.

Every path this module hands back as a "file" is relative to the project root
using forward slashes (``pathlib.Path.as_posix()``), whether it came from a
``res://`` literal (the prefix is stripped) or a bare Python path.
"""

from __future__ import annotations

import functools
import hashlib
import json
import re
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Iterable, Mapping, Sequence

FINGERPRINT_SCHEMA = "kakyu_validation_fingerprint/v1"
CORE_VERSION_PATH = "content_core/content_core_version.gd"

# Every check's fingerprint also covers the machinery that could change what
# it measures even when the check's own script does not: the project file,
# the Core version stamp, this library and its caller, and the registry that
# decides what runs.
BASELINE_FILES = (
    "project.godot",
    "content_core/content_core_version.gd",
    "tools/content_suite/run_headless_validation.py",
    "tools/content_suite/validation_inputs.py",
    "config/validation/checks_v1.json",
)

# `class_index()` looks under these three trees, matching the tracked tree a
# `.gd` file can live in.
CLASS_INDEX_ROOTS = ("content_core", "tools", "tests")
# The `godot_editor` (project parse) check's own tracked tree.
EDITOR_TREE_ROOTS = ("content_core", "tools", "tests")
# The `python regression suite` check's own tracked tree.
PYTHON_REGRESSION_ROOTS = ("tools", "tests", "config")
# The conservative-rule widening directories: a dynamic `load()` may resolve
# to anything under either.
CONSERVATIVE_WIDENING_ROOTS = ("content_core", "tools/content_suite")

_RES_PATH_RE = re.compile(r"res://[A-Za-z0-9_./-]+")
_CLASS_NAME_RE = re.compile(r"^class_name\s+(\w+)", re.MULTILINE)
_IMPORT_RE = re.compile(r"^[ \t]*(?:from (\w+) import|import (\w+))", re.MULTILINE)
_PATH_LITERAL_RE = re.compile(r"(?:config|tests|tools|content_core)/[A-Za-z0-9_./-]+")
# TD-32 part 3c, section 1(c): `\bload\(` alone finds every `load(`/
# `ResourceLoader.load(` call site without requiring a closing-paren match
# (the previous `[^()]*\)` form silently treated a nested-paren argument -
# `load(base_dir.path_join(name))` - as no call at all, never flagging it
# dynamic). The word boundary already excludes `preload(`/`_load(`/
# `xload(` (each has a word character immediately before "load", so `\b`
# does not match there) while still matching `ResourceLoader.load(` (a `.`
# immediately before "load" is not a word character).
# A `load(` reached through another receiver (`config.load(path)`,
# `ConfigFile.load`) is not a resource load: only the global `load(` and
# `ResourceLoader.load(` count (part 3c, the planning session's ruling on
# the 37 launcher-reaching checks the bare pattern widened).
_LOAD_CALL_RE = re.compile(r"(?:(?<=ResourceLoader\.)|(?<![\w.]))load\(")
# The argument's first non-space character, from right after the "(".
_LOAD_ARGUMENT_HEAD_RE = re.compile(r"[ \t]*(\S)")
# Only when the entire argument is one bare `\w+` identifier immediately
# followed by the closing paren (only whitespace between) is it eligible
# for the same-file `const ... := "res://..."` literal exception; anything
# else starting with that identifier (`kind + ".gd"`, `_resolve(kind)`) is
# not a bare identifier argument and is dynamic.
_LOAD_BARE_IDENTIFIER_ARGUMENT_RE = re.compile(r"[ \t]*(\w+)[ \t]*\)")

# TD-32 part 3b, section 1: a `res://` literal that names one of these bare
# top-level directories (with or without a trailing slash), or `res://`
# itself (empty after the prefix - unreachable through `_RES_PATH_RE`, which
# requires at least one character, but excluded here for the same reason),
# is never a load: it is an assertion or a prefix a `.gd`/`.tscn` file
# builds a path under at runtime (e.g. `ProjectSettings.globalize_path("res://tools")`
# in a test asserting a path-globbing property). Treating it as a directory
# reference pulled the whole tree into a closure that never actually loads
# it (`test_mod_definition_panel.gd`/`test_mod_definition_form.gd`, part 3a).
_BARE_TOP_LEVEL_NAMES = frozenset({"", "content_core", "tools", "tests", "config"})

# Every original archive a `{source_root}` check can read: the placeholder
# context (`run_headless_validation._registry_placeholder_context()`) carries
# one entry per name here. `bgm_arc`, `tina1_arc` and `tina2_arc` joined in
# TD-53 (a `{source_root}` check - the playback package export, the group-routes
# playback pass - reads them, and the cache did not notice a change).
_ARCHIVE_CONTEXT_NAMES = (
    "mes_arc", "mmo_arc", "data_arc", "voice_arc", "se_arc", "bgm_arc", "tina1_arc", "tina2_arc",
)


@dataclass(frozen=True)
class Closure:
    """The result of walking a start set of references to a fixed point.

    `files` and `unresolved` and `dynamic` are all sorted, de-duplicated,
    project-relative POSIX path tuples.
    """

    files: tuple[str, ...]
    unresolved: tuple[str, ...]
    dynamic: tuple[str, ...]


@dataclass(frozen=True)
class Inputs:
    """One check's resolved inputs: `check_inputs()`'s return value.

    `files`/`unresolved`/`dynamic` are the closure's own tuples, widened by
    `BASELINE_FILES`. `external` is the sorted external context names
    (`"mes_arc"`, `"exe"`, ...) this check's command actually references;
    `external_paths` maps each of those names to the absolute path
    `fingerprint()` reads to hash it. `project` is the resolved project root
    `files` is relative to, carried here so `fingerprint()` does not need its
    own `project` argument.
    """

    project: Path
    files: tuple[str, ...]
    unresolved: tuple[str, ...]
    dynamic: tuple[str, ...]
    external: tuple[str, ...]
    external_paths: dict[str, Path] = field(default_factory=dict)


def read_core_version(project: Path) -> str:
    """The `ContentCoreVersion.CORE_VERSION` string, read without Godot."""
    path = Path(project) / CORE_VERSION_PATH
    text = path.read_text(encoding="utf-8")
    match = re.search(r'const\s+CORE_VERSION\s*:?=\s*"([^"]+)"', text)
    if match is None:
        raise ValueError(f"{CORE_VERSION_PATH}: CORE_VERSION was not found.")
    return match.group(1)


@functools.lru_cache(maxsize=None)
def _class_index_cached(project_key: str) -> dict[str, Path]:
    project = Path(project_key)
    index: dict[str, Path] = {}
    for root in CLASS_INDEX_ROOTS:
        base = project / root
        if not base.is_dir():
            continue
        for gd_path in sorted(base.rglob("*.gd")):
            try:
                text = gd_path.read_text(encoding="utf-8")
            except (OSError, UnicodeDecodeError):
                continue
            match = _CLASS_NAME_RE.search(text)
            if match:
                index[match.group(1)] = gd_path.relative_to(project)
    return index


def class_index(project: Path) -> dict[str, Path]:
    """Every `class_name <Name>` declared by a `.gd` file under
    `content_core/`, `tools/` and `tests/`, keyed by the declared name, value
    a project-relative `Path`. Cached per resolved project root: `closure()`
    calls this once per check otherwise (it does not carry its own index
    between calls), and rescanning ~150 files from scratch for every one of
    a run's ~130 checks is the difference between this being a sub-second
    measurement and a multi-minute one.
    """
    return dict(_class_index_cached(str(Path(project).resolve())))


@functools.lru_cache(maxsize=None)
def _combined_class_pattern(index_key: tuple[str, ...]) -> re.Pattern[str]:
    """One alternation regex over every class name, longest first (word
    boundaries already prevent a shorter name matching inside a longer one,
    this is just a stable, deterministic order). `scan_gd()` used to run one
    `re.search()` per class name per file - `O(files * names)` - which is
    the same cost this cache removes: one `finditer()` pass per file.
    """
    if not index_key:
        return re.compile(r"(?!x)x")
    names = sorted(index_key, key=len, reverse=True)
    return re.compile(r"\b(" + "|".join(re.escape(name) for name in names) + r")\b")


def _is_bare_top_level_reference(relative: str) -> bool:
    """True when `relative` (a `res://`-stripped literal) names nothing more
    than a bare top-level tracked directory - `_BARE_TOP_LEVEL_NAMES`, with
    or without a trailing slash - never a load."""
    return relative.rstrip("/") in _BARE_TOP_LEVEL_NAMES


def scan_gd(text: str, class_index: Mapping[str, Path]) -> set[str]:
    """Every `res://...` literal in `text` that is not a bare top-level
    directory reference (`_is_bare_top_level_reference()`), plus the files
    of every class-name identifier `text` uses (word-bounded, excluding
    `text`'s own declared class). Returned paths are project-relative POSIX
    strings with no `res://` prefix.
    """
    found: set[str] = set()
    for match in _RES_PATH_RE.finditer(text):
        relative = match.group(0)[len("res://"):]
        if _is_bare_top_level_reference(relative):
            continue
        found.add(relative)
    own_match = _CLASS_NAME_RE.search(text)
    own_name = own_match.group(1) if own_match else None
    if class_index:
        pattern = _combined_class_pattern(tuple(sorted(class_index.keys())))
        for match in pattern.finditer(text):
            name = match.group(1)
            if name == own_name:
                continue
            path = class_index[name]
            found.add(path.as_posix() if isinstance(path, Path) else str(path))
    return found


def scan_tscn(text: str) -> set[str]:
    """Every `res://...` literal in a `.tscn` (ext_resource paths and any
    other), `res://`-stripped, excluding a bare top-level directory
    reference (`_is_bare_top_level_reference()`).
    """
    found: set[str] = set()
    for match in _RES_PATH_RE.finditer(text):
        relative = match.group(0)[len("res://"):]
        if _is_bare_top_level_reference(relative):
            continue
        found.add(relative)
    return found


def scan_py(text: str, project: Path) -> set[str]:
    """`^from <name> import` / `^import <name>` resolved to whichever of
    `tools/<name>.py`, `tools/<name>/__init__.py` or
    `tools/content_suite/<name>.py` exists, plus every
    `(config|tests|tools|content_core)/...` string literal that exists as a
    file or a directory.
    """
    project = Path(project)
    found: set[str] = set()
    for match in _IMPORT_RE.finditer(text):
        name = match.group(1) or match.group(2)
        if not name:
            continue
        for candidate in (
            f"tools/{name}.py", f"tools/{name}/__init__.py", f"tools/content_suite/{name}.py",
        ):
            if (project / candidate).is_file():
                found.add(candidate)
                break
    for match in _PATH_LITERAL_RE.finditer(text):
        candidate = match.group(0)
        target = project / candidate
        if target.is_file() or target.is_dir():
            found.add(candidate)
    return found


def _has_dynamic_load(text: str) -> bool:
    """True when `text` calls `load(`/`ResourceLoader.load(` with an
    argument that is neither a string literal nor a same-file `const`
    assigned a `res://` literal (the conservative rule).
    """
    for match in _LOAD_CALL_RE.finditer(text):
        rest = text[match.end():]
        head_match = _LOAD_ARGUMENT_HEAD_RE.match(rest)
        if head_match is None:
            # `load(` with nothing after it before end of text: no real
            # argument to classify.
            continue
        head = head_match.group(1)
        if head in ("\"", "'"):
            continue
        bare_match = _LOAD_BARE_IDENTIFIER_ARGUMENT_RE.match(rest)
        if bare_match is not None:
            argument = bare_match.group(1)
            const_re = re.compile(
                r"const\s+" + re.escape(argument) + r"\s*:?=\s*([\"'])res://(?:[^\"'\\]|\\.)*\1"
            )
            if const_re.search(text):
                continue
        return True
    return False


def _directory_files(base: Path, project: Path) -> Iterable[str]:
    for sub in sorted(base.rglob("*")):
        if sub.is_file():
            yield sub.relative_to(project).as_posix()


# `closure()` is called once per check (~130-360 checks a run); most reach
# a largely-overlapping set of `content_core/` files, and every check pays
# to scan whichever of those it reaches. Caching a file's own scan result by
# its resolved path - the reference set a `.gd`/`.tscn`/`.py` file
# contributes, plus a `.gd` file's own dynamic-load flag - once per process
# turns that from "scanned once per check" into "scanned once per run",
# which is what made the full-plan run's `--fingerprints` measurement go
# from multiple minutes to under 20s. The file's content does not change
# mid-run (`AGENTS.md`: never edit project files while a batch is running),
# so caching by path alone is sound for one process's lifetime.
_SCAN_REFERENCE_CACHE: dict[str, frozenset[str]] = {}
_SCAN_DYNAMIC_CACHE: dict[str, bool] = {}


def closure(start: Iterable[str], project: Path) -> Closure:
    """BFS from `start` (each item a `res://...` literal, a project-relative
    path, or a directory reference) to a fixed point, scanning every `.gd`,
    `.tscn` and `.py` file it reaches for further references. A referenced
    directory contributes every file under it recursively (not further
    scanned). Files are scanned once each within this call; `_SCAN_REFERENCE_CACHE`/`_SCAN_DYNAMIC_CACHE` additionally reuse a file's scan result across separate `closure()` calls in the same process.
    """
    project = Path(project).resolve()
    index = class_index(project)
    text_cache: dict[str, str] = {}

    def read_text(path: Path) -> str:
        key = str(path)
        cached = text_cache.get(key)
        if cached is None:
            try:
                cached = path.read_text(encoding="utf-8")
            except (OSError, UnicodeDecodeError):
                cached = ""
            text_cache[key] = cached
        return cached

    def scan_cached(path: Path, suffix: str) -> tuple[frozenset[str], bool]:
        key = str(path)
        references = _SCAN_REFERENCE_CACHE.get(key)
        if references is not None:
            return references, _SCAN_DYNAMIC_CACHE.get(key, False)
        text = read_text(path)
        is_dynamic = False
        if suffix == ".gd":
            is_dynamic = _has_dynamic_load(text)
            references = frozenset(scan_gd(text, index))
        elif suffix == ".tscn":
            references = frozenset(scan_tscn(text))
        elif suffix == ".py":
            references = frozenset(scan_py(text, project))
        else:
            references = frozenset()
        _SCAN_REFERENCE_CACHE[key] = references
        if suffix == ".gd":
            _SCAN_DYNAMIC_CACHE[key] = is_dynamic
        return references, is_dynamic

    visited: set[str] = set()
    files: set[str] = set()
    unresolved: set[str] = set()
    dynamic: set[str] = set()
    queue: list[str] = []
    seen_queue: set[str] = set()
    for item in start:
        if item and item not in seen_queue:
            queue.append(item)
            seen_queue.add(item)

    while queue:
        ref = queue.pop(0)
        rel = ref[len("res://"):] if ref.startswith("res://") else ref
        rel = rel.strip().replace("\\", "/")
        if not rel or rel in visited:
            continue
        visited.add(rel)
        if Path(rel).is_absolute():
            # Defensive: an absolute reference is always external, never a
            # project path (`project / rel` would silently discard
            # `project` and return `rel` unchanged - `pathlib`'s own join
            # rule for an absolute right-hand side).
            unresolved.add(rel)
            continue
        abs_path = project / rel
        if abs_path.is_dir():
            files.update(_directory_files(abs_path, project))
            continue
        if not abs_path.is_file():
            unresolved.add(rel)
            continue
        files.add(rel)
        suffix = abs_path.suffix
        references, is_dynamic = scan_cached(abs_path, suffix)
        if is_dynamic:
            dynamic.add(rel)
        for reference in references:
            if reference not in visited and reference not in seen_queue:
                queue.append(reference)
                seen_queue.add(reference)

    if dynamic:
        for widen_root in CONSERVATIVE_WIDENING_ROOTS:
            base = project / widen_root
            if not base.is_dir():
                continue
            for sub in base.rglob("*"):
                if sub.is_file() and sub.suffix in (".gd", ".tscn"):
                    files.add(sub.relative_to(project).as_posix())

    return Closure(
        files=tuple(sorted(files)),
        unresolved=tuple(sorted(unresolved)),
        dynamic=tuple(sorted(dynamic)),
    )


# TD-32 part 3c, section 1(b): a tree glob (`_tree_files()`) walks every
# tracked source file under its roots, but also crosses whatever a local
# interpreter/editor/VCS has written beside them - a `.pyc` cache, an
# editor import cache - which are not tracked sources and must not make a
# fingerprint depend on a machine's own build/import history.
_SKIPPED_TREE_DIR_NAMES = frozenset({"__pycache__", ".pytest_cache", ".godot", ".git"})
_SKIPPED_TREE_FILE_SUFFIXES = frozenset({".pyc", ".pyo", ".tmp", ".log"})


def _tree_files(project: Path, roots: Sequence[str], suffixes: tuple[str, ...] | None = None) -> tuple[str, ...]:
    found: set[str] = set()
    for root in roots:
        base = project / root
        if not base.is_dir():
            continue
        for sub in base.rglob("*"):
            if not sub.is_file():
                continue
            if sub.suffix in _SKIPPED_TREE_FILE_SUFFIXES:
                continue
            relative = sub.relative_to(project)
            if any(part in _SKIPPED_TREE_DIR_NAMES for part in relative.parts[:-1]):
                continue
            if suffixes is None or sub.suffix in suffixes:
                found.add(relative.as_posix())
    return tuple(sorted(found))


# TD-32 part 3c, section 1(a): every remaining command argument that
# resolves to an existing project path is a start-set member too (`--check
# config/event_catalog/duplicate_entries_v1.json` alongside a `python`-kind
# check's `{mes_arc}` argument, e.g.) - shared by the `python` and
# `godot_script` branches of `_command_start_and_closure()`.
def _existing_project_path_arguments(arguments: Sequence[str], project: Path) -> list[str]:
    found: list[str] = []
    for argument in arguments:
        if argument.startswith("res://"):
            found.append(argument[len("res://"):])
            continue
        # An absolute argument (the ELFIMAGE source root, an archive, the
        # executable) is external, never a project path: `Path(project) /
        # argument` silently discards `project` and returns `argument`
        # unchanged for an absolute `argument` (`pathlib`'s own join rule),
        # so testing existence without first excluding it would treat an
        # absolute external path as if it were project-relative.
        if Path(argument).is_absolute():
            continue
        if (Path(project) / argument).exists():
            found.append(argument)
    return found


def _command_start_and_closure(check: Any, project: Path, context: Mapping[str, str]) -> Closure:
    """The start set for `check.kind`, then its closure (TD-32 part 3b,
    section 1: `check.kind` is the registry's own `kind` field, set by
    `run_headless_validation.build_checks()`; this no longer infers a kind
    from the command's shape, per the part-3a report). The `python
    regression suite` and the project-parse (`godot_editor`) checks are
    their own tracked-tree glob (`_tree_files()`, not `closure()`, so they
    are never marked `dynamic` - they already cover everything a dynamic
    load could reach); a `godot_scene` check's start is its `.tscn`; a
    `python`-kind check's start is its script plus every remaining command
    argument that resolves to an existing project path (TD-32 part 3c,
    section 1(a)); a `godot_script` check's start is its script plus the
    same.
    """
    command = tuple(getattr(check, "command", ()) or ())
    name = getattr(check, "name", "")
    kind = getattr(check, "kind", "") or ""

    if name == "python regression suite":
        files = _tree_files(project, PYTHON_REGRESSION_ROOTS)
        return Closure(files=files, unresolved=(), dynamic=())

    if kind == "godot_editor":
        files = set(_tree_files(project, EDITOR_TREE_ROOTS, suffixes=(".gd", ".tscn")))
        files.add("project.godot")
        return Closure(files=tuple(sorted(files)), unresolved=(), dynamic=())

    if kind == "godot_scene":
        scene_arg = command[-1] if command else ""
        return closure([scene_arg], project)

    if kind == "python":
        script_arg = command[1] if len(command) > 1 else ""
        start = [script_arg]
        start.extend(_existing_project_path_arguments(command[2:], project))
        return closure(start, project)

    if kind == "godot_script":
        if "--script" not in command:
            raise ValueError(f"validation_inputs.check_inputs: '{name}' has no --script in its command.")
        script_index = command.index("--script")
        script_arg = command[script_index + 1] if script_index + 1 < len(command) else ""
        start = [script_arg]
        remainder = command[script_index:]
        if "--" in remainder:
            separator_index = command.index("--", script_index)
            extra_args = command[separator_index + 1:]
        else:
            extra_args = ()
        start.extend(_existing_project_path_arguments(extra_args, project))
        return closure(start, project)

    raise ValueError(f"validation_inputs.check_inputs: cannot classify check '{name}' (kind {kind!r}).")


def check_inputs(check: Any, project: Path, context: Mapping[str, str]) -> Inputs:
    """`check`'s resolved inputs: the start set by kind (see
    `_command_start_and_closure()`), widened by `BASELINE_FILES`, plus the
    external context names (`"mes_arc"`, `"exe"`, ...) this check's own
    `requires` (TD-32 part 3b, section 1: the registry's own `requires`,
    widened by `run_headless_validation.build_checks()` with every
    `optional_arguments` condition it actually satisfied - so a check whose
    command only conditionally references an archive still requires it here)
    names, restricted to the archives that are actually present as files.

    `context` is the same placeholder context
    `run_headless_validation._registry_placeholder_context()` builds
    (`python`, `godot`, `source_root`, `mes_arc`, `exe`, ...); `check_inputs`
    never re-derives it.

    TD-32 part 3c, section 1(d): an `elfimage`-requiring check hashes only
    the archives its own command actually names - a command naming
    `{source_root}` (the directory) hashes every archive present under it,
    since a directory-scanning check can read any of them; a command
    naming only `{mes_arc}` (or any other single archive placeholder) hashes
    that one archive alone. This is decided from `check.command`'s own
    tokens against `context`'s resolved paths, not from `requires` alone -
    `requires` only says the check needs *some* archive, not which one its
    command actually reads.
    """
    project = Path(project).resolve()
    requires = frozenset(getattr(check, "requires", ()) or ())
    command = tuple(getattr(check, "command", ()) or ())

    resolved = _command_start_and_closure(check, project, context)
    files = tuple(sorted(set(resolved.files) | set(BASELINE_FILES)))

    external: list[str] = []
    external_paths: dict[str, Path] = {}
    if "elfimage" in requires:
        source_root_text = context.get("source_root")
        names_referenced: list[str]
        if source_root_text and source_root_text in command:
            names_referenced = list(_ARCHIVE_CONTEXT_NAMES)
        else:
            names_referenced = [
                archive_name for archive_name in _ARCHIVE_CONTEXT_NAMES
                if context.get(archive_name) and context[archive_name] in command
            ]
        for archive_name in names_referenced:
            path_text = context.get(archive_name)
            if not path_text:
                continue
            path = Path(path_text)
            if path.is_file():
                external.append(archive_name)
                external_paths[archive_name] = path
    if "exe" in requires:
        exe_text = context.get("exe")
        if exe_text:
            exe_path = Path(exe_text)
            if exe_path.is_file():
                external.append("exe")
                external_paths["exe"] = exe_path

    return Inputs(
        project=project,
        files=files,
        unresolved=resolved.unresolved,
        dynamic=resolved.dynamic,
        external=tuple(sorted(external)),
        external_paths=external_paths,
    )


def normalize_command(command: Sequence[str], context: Mapping[str, str]) -> str:
    """`command`, space-joined, with the ELFIMAGE root and the executable
    path replaced by `<ELFIMAGE>`/`<EXE>`, the Python and Godot executables
    by `<PYTHON>`/`<GODOT>` and the project root by `<PROJECT>` - so a
    different install path does not change the fingerprint.

    TD-33 follow-up (2026-09-23): the project root is normalised too (in
    both slash forms), so a whole batch run on a detached worktree - how
    whole batches are run here - stores green results the main checkout can
    reuse. The inputs themselves are hashed by content under paths relative
    to the project, so two checkouts share a fingerprint only when every
    input file is byte-identical.
    """
    project = context.get("project") or ""
    substitutions = (
        (context.get("source_root"), "<ELFIMAGE>"),
        (context.get("exe"), "<EXE>"),
        (context.get("python"), "<PYTHON>"),
        (context.get("godot"), "<GODOT>"),
        (project, "<PROJECT>"),
        (project.replace("\\", "/"), "<PROJECT>"),
    )
    tokens = []
    for token in command:
        replaced = token
        for value, placeholder in substitutions:
            if value:
                replaced = replaced.replace(value, placeholder)
        tokens.append(replaced)
    return " ".join(tokens)


def fingerprint(
    inputs: Inputs, core_version: str, command: str, *,
    file_memo: dict[str, str] | None = None, external_memo: dict[str, str] | None = None,
) -> str:
    """sha256 over the canonical JSON of `inputs`, `core_version` and the
    already-normalized `command` text (see `normalize_command()`). File and
    external archive contents are hashed once per run through `file_memo`/
    `external_memo` (a caller running many checks passes the same dicts
    through every call).
    """
    file_memo = {} if file_memo is None else file_memo
    external_memo = {} if external_memo is None else external_memo

    files_payload = []
    for relative_path in sorted(inputs.files):
        absolute_path = inputs.project / relative_path
        key = str(absolute_path)
        digest = file_memo.get(key)
        if digest is None:
            digest = hashlib.sha256(absolute_path.read_bytes()).hexdigest()
            file_memo[key] = digest
        files_payload.append([relative_path, digest])

    external_payload: dict[str, str] = {}
    for name in sorted(inputs.external):
        absolute_path = inputs.external_paths[name]
        key = str(absolute_path)
        digest = external_memo.get(key)
        if digest is None:
            digest = hashlib.sha256(absolute_path.read_bytes()).hexdigest()
            external_memo[key] = digest
        external_payload[name] = digest

    payload = {
        "schema": FINGERPRINT_SCHEMA,
        "core_version": core_version,
        "command": command,
        "files": files_payload,
        "external": external_payload,
    }
    canonical = json.dumps(payload, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
    return hashlib.sha256(canonical.encode("utf-8")).hexdigest()
