"""Run the Content Core and independent-tool validation suite without a GUI.

The local synthetic suite is always available.  Passing a user-owned ELFIMAGE
directory adds read-only original-corpus checks; passing the original launcher
also cross-checks the native ARC and MES contracts recorded by the executable
auditors.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import threading
import time
import traceback
import uuid
from collections import deque
from dataclasses import dataclass
from pathlib import Path
from typing import Sequence

import validation_cache
import validation_inputs
from validation_report import COVERAGE_TITLES, OUTPUT_TAIL_LIMIT, SCHEMA, TIERS, make_report, write_report

# TD-32 part 3b: the cache of green results, keyed by a check's own
# fingerprint. Relative to the project root unless given as an absolute path.
DEFAULT_CACHE_DIR = Path("analysis/validation_cache")

PYTHON_REGRESSION_TIMEOUT_SECONDS = 3600
PYTHON_REGRESSION_MAX_JOBS = 4
PYTHON_HANDOFF_TIMEOUT_SECONDS = 6000
FROZEN_HANDOFF_DIGEST = "config/mes_analyzer/frozen_gd_instruction_v45.jsonl"
GODOT_SCRIPT_ERROR = re.compile(
    r"^[ \t]*(?:SCRIPT ERROR:|ERROR:[ \t]+(?:Failed to load script|Failed to create an autoload))",
    re.MULTILINE,
)
ANSI_ESCAPE = re.compile(r"\x1b\[[0-?]*[ -/]*[@-~]")

# TD-32 part 1: build_checks() loads this tracked registry instead of carrying
# the checks as tuples. Documented in tools/README.md, "Content Suite
# validation" (report only; the registry itself is the data contract).
REGISTRY_SCHEMA = "kakyu_validation_checks/v1"
REGISTRY_PATH = "config/validation/checks_v1.json"
# The registry ships with this tool, not with whatever `project` a caller asks
# a check to run against (a test exercises `build_checks()` against a bare
# temporary directory to isolate scene discovery). Load and validate it
# against this file's own repository, independently of that parameter.
REGISTRY_ROOT = Path(__file__).resolve().parents[2]
TIER_CHOICES = TIERS
TIER_SCOPES = {
    "local": frozenset({"local"}),
    "archive_quick": frozenset({"local", "archive_quick"}),
    "full": frozenset({"local", "archive_quick", "full"}),
}
KNOWN_CHECK_KINDS = frozenset({"python", "godot_editor", "godot_script", "godot_scene"})
KNOWN_CHECK_FAMILIES = frozenset({"godot_scenes", "analysis_group"})
# TD-32 part 2: the top-level `families` block collapses every selected
# member of a *process* family into one Godot process at run time; only
# `analysis_group` has one so far (`validate_event_analysis_groups.gd`).
# `godot_scenes` stays a build_checks()-time expansion, not a process family.
KNOWN_CHECK_PROCESS_FAMILIES = frozenset({"analysis_group"})
# TD-33: revision 3 adds the per-entry optional `exclusive` boolean (a check
# that cannot share the machine with anything else) and, on the `godot_scenes`
# family entry only, the optional `exclusive_scenes` list naming which
# expanded scenes carry it (the three Godot test scenes that spawn and time
# real sibling processes: overlay_publication_lock, process_liveness,
# workspace_multiprocess - the only three that spawn and time real sibling
# OS processes; the rest of the tracked test scenes only touch their own
# per-process `user://` tree). TD-33 part 2: revision 4 adds the per-entry
# optional `shards` integer (>= 2, `godot_script` only) - `build_checks()`
# expands such an entry into that many checks, each named `<name> [K/N]` and
# passed the extra argument `shard=K/N`, the way `godot_scenes` already
# expands one entry into one check per discovered scene. TD-58: revision 5
# adds the `families.<name>` block's optional `process_shards` integer
# (>= 2) - `collapse_families()` splits a run's selected members across that
# many process checks (never more than `--jobs` or the member count).
REGISTRY_REVISION = 5
KNOWN_CHECK_REQUIRES = frozenset({"elfimage", "exe", "voice_arc", "se_arc", "mmo_arc", "event_corpus"})
KNOWN_CHECK_TIERS = frozenset(TIER_CHOICES)
KNOWN_CHECK_PLACEHOLDERS = frozenset({
    "source_root", "mes_arc", "mmo_arc", "data_arc", "voice_arc", "se_arc", "exe",
    "godot", "python", "project", "frozen_handoff_digest", "python_jobs",
    "python_child_timeout", "python_timeout", "python_handoff_timeout",
})
# Every placeholder here requires the paired condition, either unconditionally
# (in `entry["requires"]`) or, for `voice_arc`/`se_arc`, exclusively inside an
# `optional_arguments` clause keyed with that same condition.
PLACEHOLDER_REQUIREMENT = {
    "source_root": "elfimage", "mes_arc": "elfimage", "mmo_arc": "elfimage", "data_arc": "elfimage",
    "voice_arc": "voice_arc", "se_arc": "se_arc", "exe": "exe",
}
_PLACEHOLDER_RE = re.compile(r"\{(\w+)\}")


def discover_scene_names(test_root: Path) -> tuple[str, ...]:
    """Every Godot test scene under `test_root`, in a stable order.

    The batch used to carry a hand-written list beside the directory it was
    supposed to describe, and the two drifted in both directions: the list named
    one scene that no longer exists, which failed the whole batch, and omitted
    thirteen that do, which therefore never ran. Discovering the scenes removes
    the second copy rather than correcting it, so adding a test scene needs no
    edit here.
    """
    return tuple(sorted(path.name for path in test_root.glob("*.tscn")))


@dataclass(frozen=True)
class Check:
    name: str
    command: tuple[str, ...]
    timeout: int
    groups: tuple[str, ...] = ("synthetic",)
    tier: str = "local"
    registry_name: str | None = None
    # TD-32 part 2: `family`/`profile` are carried straight from the registry
    # entry (empty for a check with neither). `members` is populated only on
    # the process check `collapse_families()` builds in place of every
    # selected `analysis_group` member; such a check's own `profile` is empty
    # and its `command` runs every member's profile in one Godot process.
    family: str = ""
    profile: str = ""
    members: tuple["Check", ...] = ()
    # TD-32 part 2c: the process command `collapse_families()` builds for a
    # selection of `analysis_group` members needs the shared godot/project
    # binary and the elfimage source root, so every check carries them
    # (empty strings where not applicable) instead of `collapse_families()`
    # indexing a member's own `command` tuple.
    godot: str = ""
    project: str = ""
    source_root: str = ""
    # TD-32 part 3b, section 1: the registry entry's own `kind` and its
    # effective `requires` (the entry's `requires` widened by every
    # `optional_arguments` condition this run actually satisfied for this
    # check) - `validation_inputs.check_inputs()` reads these instead of
    # inferring a kind from the command's shape or an archive requirement
    # from literal path strings in the command.
    requires: tuple[str, ...] = ()
    kind: str = ""
    # TD-33: `weight` is how many of `--jobs N`'s concurrency units this
    # check occupies while it runs (1 for an ordinary check; the Python
    # regression suite's own shard count - it is already internally
    # parallel, so it should not also run alongside N other checks).
    # `exclusive` (the registry's own optional boolean, or, for an expanded
    # `godot_scenes` member, membership in that entry's `exclusive_scenes`)
    # means this check runs with nothing else in flight at all.
    weight: int = 1
    exclusive: bool = False
    # TD-58: set only on a process check `collapse_families()` split off a
    # family's members (`original event analysis groups [K/N]`): the one
    # `shard plan:` line `_run_process_check()` prints at its `===` header.
    shard_plan: str = ""


class ConfigurationParser(argparse.ArgumentParser):
    def error(self, message: str) -> None:
        raise ValueError(message)


def parse_args() -> argparse.Namespace:
    parser = ConfigurationParser(
        description="Run the Kakyu Content Core/tool checks headlessly as one batch."
    )
    parser.add_argument(
        "--godot",
        type=Path,
        help="Godot 4.7 console executable (auto-detected when omitted).",
    )
    parser.add_argument(
        "--elfimage",
        type=Path,
        help="User-owned ELFIMAGE directory; enables read-only original-corpus checks.",
    )
    parser.add_argument(
        "--exe",
        type=Path,
        help="Original AI5WIN.exe; enables the bounded native ARC and MES contract audits.",
    )
    parser.add_argument(
        "--skip-event-corpus",
        action="store_true",
        help="Skip the exhaustive MES intro-anchor runner audit.",
    )
    parser.add_argument(
        "--tier",
        choices=TIER_CHOICES,
        default="full",
        help="Plan only checks in this tier or narrower (default: full, today's behaviour).",
    )
    parser.add_argument(
        "--python-timeout",
        type=int,
        default=PYTHON_REGRESSION_TIMEOUT_SECONDS,
        help=(
            "Python regression child-process timeout in seconds "
            f"(default: {PYTHON_REGRESSION_TIMEOUT_SECONDS})."
        ),
    )
    parser.add_argument(
        "--python-jobs",
        type=int,
        default=min(PYTHON_REGRESSION_MAX_JOBS, os.cpu_count() or 1),
        help=(
            "Worker processes of each check that parallelizes itself - the Python "
            "regression shards and the full handoff equivalence's comparison pool - "
            "and the number of scheduler slots each of those checks occupies "
            f"(default: at most {PYTHON_REGRESSION_MAX_JOBS})."
        ),
    )
    parser.add_argument(
        "--jobs",
        type=int,
        default=1,
        help=(
            "Run this many checks concurrently (default: 1, today's sequential "
            "behaviour). A check's own weight and any registry 'exclusive' "
            "marking still bound what actually overlaps. Each check's own "
            "timeout still applies per check, not per batch, so a heavy check "
            "run alongside others can reach it sooner than it would running "
            "alone on an otherwise idle machine."
        ),
    )
    parser.add_argument(
        "--report",
        type=Path,
        help="Optional JSON report path. Keep machine-specific reports outside Git.",
    )
    parser.add_argument("--check", action="append", default=[], metavar="NAME",
                        help="Run only this named check; repeat to select multiple checks. "
                             "\"original event analysis groups\" selects every planned "
                             "analysis-group member (they run in one Godot process, or in "
                             "up to the registry's process_shards processes under --jobs).")
    parser.add_argument("--run-id", help="Optional UUID supplied by the validation viewer.")
    parser.add_argument(
        "--fingerprints",
        action="store_true",
        help=(
            "Plan as usual (tier, availability, --check) and print each selected check's "
            "input fingerprint instead of running it. Writes no report."
        ),
    )
    parser.add_argument(
        "--fingerprint-inputs",
        metavar="NAME",
        help="Print one selected check's sorted inputs and unresolved references, and exit. Writes no report.",
    )
    parser.add_argument(
        "--cached",
        action="store_true",
        help="Consult the cache of green results; a check whose fingerprint already recorded a pass is skipped.",
    )
    parser.add_argument(
        "--cache-store",
        action="store_true",
        help=(
            "Write results to the cache of green results without reading it first "
            "(seed a clean run's cache without skipping any check)."
        ),
    )
    parser.add_argument(
        "--cache-dir",
        type=Path,
        default=DEFAULT_CACHE_DIR,
        help=f"Directory for the cache of green results (default: {DEFAULT_CACHE_DIR}).",
    )
    parser.add_argument(
        "--cache-clear",
        action="store_true",
        help="Delete the cache directory before this run (allowed with or without --cached/--cache-store).",
    )
    return parser.parse_args()


def find_godot(explicit: Path | None) -> Path:
    if explicit is not None:
        candidate = explicit.expanduser().resolve()
        if candidate.is_file():
            return candidate
        raise ValueError(f"Godot executable does not exist: {candidate}")
    configured = os.environ.get("GODOT4_CONSOLE")
    if configured:
        candidate = Path(configured).expanduser().resolve()
        if candidate.is_file():
            return candidate
        raise ValueError(f"GODOT4_CONSOLE does not exist: {candidate}")
    for name in (
        "godot4.7",
        "godot4",
        "godot",
        "Godot_v4.7-stable_win64_console.exe",
    ):
        resolved = shutil.which(name)
        if resolved:
            return Path(resolved).resolve()
    if os.name == "nt":
        local_app_data = os.environ.get("LOCALAPPDATA")
        if local_app_data:
            package_root = Path(local_app_data) / "Microsoft" / "WinGet" / "Packages"
            matches = sorted(
                package_root.glob(
                    "GodotEngine.GodotEngine_*/*_console.exe"
                ),
                reverse=True,
            )
            if matches:
                return matches[0].resolve()
    raise ValueError("Godot 4.7 console executable was not found; pass --godot.")


def godot_command(godot: Path, project: Path, *arguments: str) -> tuple[str, ...]:
    return (str(godot), "--headless", "--path", str(project), *arguments)


def load_validation_registry(project: Path | None = None) -> list[dict]:
    """Load and structurally validate `config/validation/checks_v1.json`.

    Every failure names the offending entry (or its index, if even its name
    is unusable) so a malformed registry fails closed with an actionable
    message, per TD-32 part 1. `project` is real: the registry is read from
    `project / "config/validation/checks_v1.json"` when a caller supplies it.
    `build_checks()` does not forward its own `project` argument here, so
    every caller of `build_checks()` today gets the registry from
    `REGISTRY_ROOT` (this tool's own repository) - the registry ships with
    the tool, not with whatever checkout a check is asked to run against.
    Documented in `tools/README.md`, "Content Suite validation".
    """
    registry_root = project if project is not None else REGISTRY_ROOT
    raw = _read_registry_document(registry_root)
    return _validate_registry_document(raw, registry_root)


def load_validation_families(project: Path | None = None) -> dict[str, dict]:
    """Load and structurally validate the registry's top-level `families`
    block (TD-32 part 2, registry revision 2): the process families
    `collapse_families()` collapses a selection's members into, keyed by
    family name (only `analysis_group` exists today). Reads the same
    tracked registry `load_validation_registry()` does; kept as its own
    entry point because `collapse_families()` needs the families block, not
    the per-check entries `load_validation_registry()` returns.
    """
    registry_root = project if project is not None else REGISTRY_ROOT
    raw = _read_registry_document(registry_root)
    return _validate_families_document(raw, registry_root)


def _read_registry_document(registry_root: Path) -> object:
    registry_path = registry_root / REGISTRY_PATH
    try:
        return json.loads(registry_path.read_text(encoding="utf-8"))
    except OSError as error:
        raise ValueError(f"Validation checks registry could not be read: {error}") from error
    except json.JSONDecodeError as error:
        raise ValueError(f"Validation checks registry is not valid JSON: {error}") from error


_FAMILY_REQUIRED_KEYS = frozenset({"check", "script", "process_timeout", "groups", "tier"})
_FAMILY_OPTIONAL_KEYS = frozenset({"process_shards"})


def _validate_families_document(raw: object, registry_root: Path) -> dict[str, dict]:
    if not isinstance(raw, dict) or raw.get("schema") != REGISTRY_SCHEMA:
        raise ValueError(
            f"Validation checks registry has an unsupported schema (expected {REGISTRY_SCHEMA!r})."
        )
    families = raw.get("families")
    if not isinstance(families, dict) or not families:
        raise ValueError("Validation checks registry is missing its families block.")
    known_groups = frozenset(COVERAGE_TITLES)
    validated: dict[str, dict] = {}
    for family_name, family in families.items():
        if family_name not in KNOWN_CHECK_PROCESS_FAMILIES:
            raise ValueError(f"Validation checks registry family '{family_name}': unknown family.")
        if not isinstance(family, dict) or not (
            _FAMILY_REQUIRED_KEYS <= set(family) <= _FAMILY_REQUIRED_KEYS | _FAMILY_OPTIONAL_KEYS
        ):
            raise ValueError(f"Validation checks registry family '{family_name}': malformed entry.")
        check_name = family.get("check")
        if not isinstance(check_name, str) or not check_name:
            raise ValueError(f"Validation checks registry family '{family_name}': missing its check name.")
        script = family.get("script")
        if not isinstance(script, str) or not script:
            raise ValueError(f"Validation checks registry family '{family_name}': missing a script path.")
        script_relative = script[len("res://"):] if script.startswith("res://") else script
        if not (registry_root / script_relative).is_file():
            raise ValueError(f"Validation checks registry family '{family_name}': script does not exist: {script_relative}")
        timeout = family.get("process_timeout")
        if not (isinstance(timeout, int) and not isinstance(timeout, bool) and timeout > 0):
            raise ValueError(f"Validation checks registry family '{family_name}': process_timeout must be a positive integer.")
        groups = family.get("groups")
        if not isinstance(groups, list) or not groups or any(group not in known_groups for group in groups):
            raise ValueError(f"Validation checks registry family '{family_name}': groups must be known coverage groups.")
        tier = family.get("tier")
        if tier not in KNOWN_CHECK_TIERS:
            raise ValueError(f"Validation checks registry family '{family_name}': unknown tier {tier!r}.")
        # TD-58: `process_shards` (registry revision 5) is the most processes
        # `collapse_families()` splits this family's selected members across.
        if "process_shards" in family:
            process_shards = family["process_shards"]
            if not (isinstance(process_shards, int) and not isinstance(process_shards, bool) and process_shards >= 2):
                raise ValueError(f"Validation checks registry family '{family_name}': process_shards must be an integer >= 2.")
        validated[family_name] = family
    return validated


def _validate_registry_document(raw: object, registry_root: Path) -> list[dict]:
    _validate_families_document(raw, registry_root)
    if not isinstance(raw, dict) or raw.get("schema") != REGISTRY_SCHEMA:
        raise ValueError(
            f"Validation checks registry has an unsupported schema (expected {REGISTRY_SCHEMA!r})."
        )
    if raw.get("revision") != REGISTRY_REVISION:
        raise ValueError("Validation checks registry has an unsupported revision.")
    entries = raw.get("checks")
    if not isinstance(entries, list) or not entries:
        raise ValueError("Validation checks registry has no checks.")

    known_groups = frozenset(COVERAGE_TITLES)
    seen_names: set[str] = set()
    validated: list[dict] = []
    for index, entry in enumerate(entries):
        label = entry.get("name") if isinstance(entry, dict) else None
        label = label if isinstance(label, str) and label else f"<entry {index}>"
        if not isinstance(entry, dict):
            raise ValueError(f"Registry entry {label}: must be an object.")
        name = entry.get("name")
        if not isinstance(name, str) or not name:
            raise ValueError(f"Registry entry {label}: missing a name.")
        if name in seen_names:
            raise ValueError(f"Registry entry '{name}': duplicate name.")
        seen_names.add(name)
        kind = entry.get("kind")
        if kind not in KNOWN_CHECK_KINDS:
            raise ValueError(f"Registry entry '{name}': unknown kind {kind!r}.")
        script = entry.get("script")
        if not isinstance(script, str):
            raise ValueError(f"Registry entry '{name}': script must be a string.")
        family = entry.get("family")
        if family is not None and family not in KNOWN_CHECK_FAMILIES:
            raise ValueError(f"Registry entry '{name}': unknown family {family!r}.")
        if family == "godot_scenes" and kind != "godot_scene":
            raise ValueError(f"Registry entry '{name}': family 'godot_scenes' requires kind 'godot_scene'.")
        if kind == "godot_scene" and family != "godot_scenes":
            raise ValueError(f"Registry entry '{name}': kind 'godot_scene' requires family 'godot_scenes'.")
        if family == "analysis_group" and kind != "godot_script":
            raise ValueError(f"Registry entry '{name}': family 'analysis_group' requires kind 'godot_script'.")
        if kind != "godot_editor" and not script:
            raise ValueError(f"Registry entry '{name}': missing a script path.")
        if family != "godot_scenes" and script:
            script_relative = script[len("res://"):] if script.startswith("res://") else script
            if not (registry_root / script_relative).is_file():
                raise ValueError(f"Registry entry '{name}': script does not exist: {script_relative}")
        profile = entry.get("profile")
        if family == "analysis_group":
            if not isinstance(profile, str) or not (registry_root / profile).is_file():
                raise ValueError(f"Registry entry '{name}': profile does not exist: {profile!r}")
        elif profile is not None:
            raise ValueError(f"Registry entry '{name}': profile is only valid on an analysis_group entry.")
        # TD-33 part 2: `shards` (registry revision 4) splits one
        # `godot_script` entry's rows across N independent processes,
        # `build_checks()` expanding it into N checks named `<name> [K/N]`
        # instead of building one command for it here.
        shards = entry.get("shards")
        if shards is not None:
            if kind != "godot_script":
                raise ValueError(f"Registry entry '{name}': shards is only valid on a 'godot_script' entry.")
            if not (isinstance(shards, int) and not isinstance(shards, bool) and shards >= 2):
                raise ValueError(f"Registry entry '{name}': shards must be an integer >= 2.")
        arguments_field = entry.get("arguments")
        if not isinstance(arguments_field, list) or not all(isinstance(a, str) for a in arguments_field):
            raise ValueError(f"Registry entry '{name}': arguments must be a list of strings.")
        timeout = entry.get("timeout")
        if isinstance(timeout, str):
            if timeout not in ("{python_timeout}", "{python_handoff_timeout}"):
                raise ValueError(f"Registry entry '{name}': unsupported timeout placeholder {timeout!r}.")
        elif not (isinstance(timeout, int) and not isinstance(timeout, bool) and timeout > 0):
            raise ValueError(f"Registry entry '{name}': timeout must be a positive integer.")
        groups = entry.get("groups")
        if not isinstance(groups, list) or not groups or any(group not in known_groups for group in groups):
            raise ValueError(f"Registry entry '{name}': groups must be known coverage groups.")
        requires = entry.get("requires")
        if not isinstance(requires, list) or any(item not in KNOWN_CHECK_REQUIRES for item in requires):
            raise ValueError(f"Registry entry '{name}': requires an unknown condition.")
        tier = entry.get("tier")
        if tier not in KNOWN_CHECK_TIERS:
            raise ValueError(f"Registry entry '{name}': unknown tier {tier!r}.")
        optional_groups = entry.get("optional_groups", [])
        if not isinstance(optional_groups, list):
            raise ValueError(f"Registry entry '{name}': optional_groups must be a list.")
        for pair in optional_groups:
            if (
                not isinstance(pair, list) or len(pair) != 2
                or pair[0] not in KNOWN_CHECK_REQUIRES or pair[1] not in known_groups
            ):
                raise ValueError(f"Registry entry '{name}': malformed optional_groups entry {pair!r}.")
        optional_arguments = entry.get("optional_arguments", [])
        if not isinstance(optional_arguments, list):
            raise ValueError(f"Registry entry '{name}': optional_arguments must be a list.")
        extra_argument_texts: list[str] = []
        for pair in optional_arguments:
            if (
                not isinstance(pair, list) or len(pair) != 2 or pair[0] not in KNOWN_CHECK_REQUIRES
                or not isinstance(pair[1], list) or not all(isinstance(a, str) for a in pair[1])
            ):
                raise ValueError(f"Registry entry '{name}': malformed optional_arguments entry {pair!r}.")
            extra_argument_texts.extend(pair[1])
        texts = [*arguments_field, *extra_argument_texts, script, name]
        if isinstance(timeout, str):
            texts.append(timeout)
        allowed_placeholders = KNOWN_CHECK_PLACEHOLDERS | ({"scene"} if family == "godot_scenes" else set())
        for text in texts:
            for placeholder in _PLACEHOLDER_RE.findall(text):
                if placeholder not in allowed_placeholders:
                    raise ValueError(f"Registry entry '{name}': unknown placeholder '{{{placeholder}}}'.")
        # A placeholder implies its requirement: used unconditionally, the
        # entry's own `requires` must cover it; used only inside an
        # `optional_arguments` clause, that clause's own condition key must be
        # the placeholder's requirement (the clause already gates whether the
        # context has a value for it).
        unconditional_texts = [*arguments_field, script, name]
        if isinstance(timeout, str):
            unconditional_texts.append(timeout)
        unconditional_placeholders = {
            placeholder for text in unconditional_texts for placeholder in _PLACEHOLDER_RE.findall(text)
        }
        for placeholder, condition in PLACEHOLDER_REQUIREMENT.items():
            if placeholder in unconditional_placeholders and condition not in requires:
                raise ValueError(
                    f"Registry entry '{name}': placeholder '{{{placeholder}}}' requires '{condition}'."
                )
        for clause_condition, extra in optional_arguments:
            for argument in extra:
                for placeholder in _PLACEHOLDER_RE.findall(argument):
                    condition = PLACEHOLDER_REQUIREMENT.get(placeholder)
                    if condition is None or placeholder in unconditional_placeholders:
                        continue
                    if clause_condition != condition:
                        raise ValueError(
                            f"Registry entry '{name}': placeholder '{{{placeholder}}}' in an "
                            f"optional_arguments clause keyed '{clause_condition}' requires '{condition}'."
                        )
        # TD-33: `exclusive` (a check that cannot share the machine with
        # anything else while it runs) is optional on any entry and must be
        # a plain boolean - never an int, even though `bool` is technically
        # an `int` subclass in Python, so `isinstance(exclusive, int)` alone
        # would silently accept `1`/`0`.
        exclusive = entry.get("exclusive", False)
        if not isinstance(exclusive, bool):
            raise ValueError(f"Registry entry '{name}': exclusive must be a boolean.")
        exclusive_scenes = entry.get("exclusive_scenes")
        if exclusive_scenes is not None:
            if family != "godot_scenes":
                raise ValueError(
                    f"Registry entry '{name}': exclusive_scenes is only valid on a 'godot_scenes' family entry."
                )
            if (
                not isinstance(exclusive_scenes, list) or not exclusive_scenes
                or not all(isinstance(scene, str) and scene for scene in exclusive_scenes)
                or len(exclusive_scenes) != len(set(exclusive_scenes))
            ):
                raise ValueError(f"Registry entry '{name}': exclusive_scenes must be a list of distinct scene names.")
            for scene in exclusive_scenes:
                if not (registry_root / "tests" / scene).is_file():
                    raise ValueError(f"Registry entry '{name}': exclusive_scenes names a scene that does not exist: {scene}")
        validated.append(entry)
    return validated


def _availability(arguments: argparse.Namespace) -> dict[str, bool]:
    """Which `requires`/`optional_groups`/`optional_arguments` conditions this
    run's arguments make available. Never raises: it only inspects what was
    given, so it is safe to call for diagnostics (e.g. `select_checks()`
    naming why a requested `--check` is unavailable) as well as from
    `_registry_placeholder_context()`, which additionally verifies the
    sources it accepts actually exist.
    """
    available: dict[str, bool] = {
        "elfimage": arguments.elfimage is not None,
        "exe": arguments.exe is not None,
        "voice_arc": False,
        "se_arc": False,
        "mmo_arc": False,
        "event_corpus": not getattr(arguments, "skip_event_corpus", False),
    }
    if arguments.elfimage is not None:
        source_root = arguments.elfimage.expanduser().resolve()
        available["mmo_arc"] = (source_root / "mmo.arc").is_file()
        available["voice_arc"] = (source_root / "voice.arc").is_file()
        available["se_arc"] = (source_root / "se.arc").is_file()
    return available


def _registry_placeholder_context(
    *, arguments: argparse.Namespace, project: Path, godot: Path,
    python_jobs: int, python_timeout: int,
) -> tuple[dict[str, str], dict[str, bool]]:
    """Resolve every registry placeholder and every `requires`/`optional_groups`
    condition from the run's arguments, raising the same configuration errors
    `build_checks()` raised before the registry existed.
    """
    context: dict[str, str] = {
        "godot": str(godot),
        "python": sys.executable,
        "project": str(project),
        "frozen_handoff_digest": FROZEN_HANDOFF_DIGEST,
        "python_jobs": str(python_jobs),
        "python_child_timeout": str(max(1, python_timeout - 10)),
        "python_timeout": str(python_timeout),
    }
    available = _availability(arguments)
    if arguments.elfimage is not None:
        source_root = arguments.elfimage.expanduser().resolve()
        if not source_root.is_dir():
            raise ValueError(f"ELFIMAGE directory does not exist: {source_root}")
        archives = {
            "mes": source_root / "mes.arc",
            "mmo": source_root / "mmo.arc",
            "data": source_root / "data.arc",
        }
        missing = [str(path) for path in archives.values() if not path.is_file()]
        if missing:
            raise ValueError("Required original archive is missing: " + ", ".join(missing))
        if not (project / FROZEN_HANDOFF_DIGEST).is_file():
            raise ValueError("Frozen Phase 1-4 comparison digest is missing.")
        context["source_root"] = str(source_root)
        context["mes_arc"] = str(archives["mes"])
        context["mmo_arc"] = str(archives["mmo"])
        context["data_arc"] = str(archives["data"])
        context["voice_arc"] = str(source_root / "voice.arc")
        context["se_arc"] = str(source_root / "se.arc")
        # TD-53: the three archives the playback package export and the
        # group-routes playback pass also read. They are *context only* - input
        # fingerprinting (`validation_inputs._ARCHIVE_CONTEXT_NAMES`) hashes them
        # for a check that names `{source_root}` - and deliberately not registry
        # placeholders (`KNOWN_CHECK_PLACEHOLDERS`) or `requires` conditions: no
        # command names them, and a run whose ELFIMAGE lacks one stays valid
        # (`check_inputs()` skips a name whose file is absent, as for voice/se).
        context["bgm_arc"] = str(source_root / "bgm.arc")
        context["tina1_arc"] = str(source_root / "tina1.arc")
        context["tina2_arc"] = str(source_root / "tina2.arc")
    if arguments.exe is not None:
        executable = arguments.exe.expanduser().resolve()
        if not executable.is_file():
            raise ValueError(f"Original executable does not exist: {executable}")
        context["exe"] = str(executable)
    return context, available


def _interpolate(text: str, context: dict[str, str], entry_name: str) -> str:
    def substitute(match: re.Match[str]) -> str:
        key = match.group(1)
        try:
            return context[key]
        except KeyError as error:
            raise ValueError(
                f"Registry entry '{entry_name}': no value is available for placeholder '{{{key}}}'."
            ) from error

    return _PLACEHOLDER_RE.sub(substitute, text)


def _requirement_met(item: str, available: dict[str, bool]) -> bool:
    return available[item]


def _python_execution_settings(arguments: argparse.Namespace) -> tuple[int, int]:
    """`(python_timeout, python_jobs)`, validated the same way for
    `build_checks()` and for `--fingerprints`/`--fingerprint-inputs`, which
    need the same placeholder context without planning checks a second time
    through `build_checks()` itself.
    """
    python_timeout = int(
        getattr(
            arguments,
            "python_timeout",
            PYTHON_REGRESSION_TIMEOUT_SECONDS,
        )
    )
    if python_timeout <= 0:
        raise ValueError("Python regression timeout must be greater than zero.")
    python_jobs = int(
        getattr(
            arguments,
            "python_jobs",
            min(PYTHON_REGRESSION_MAX_JOBS, os.cpu_count() or 1),
        )
    )
    if python_jobs <= 0:
        raise ValueError("Parallel Python regression jobs must be greater than zero.")
    return python_timeout, python_jobs


def build_checks(
    arguments: argparse.Namespace, project: Path, godot: Path, *, apply_tier: bool = True,
) -> list[Check]:
    """Load `config/validation/checks_v1.json` and plan the checks it names.

    TD-32 part 1: this used to carry every check as a `Check(...)` tuple
    directly. It now loads the tracked registry, skips an entry whose
    `requires` are unavailable, expands the two computed families (the
    discovered Godot test scenes and the per-profile analysis groups already
    live one-per-entry), and interpolates the registry's placeholders. For
    every argument combination this produces exactly the checks the old
    hand-written `build_checks()` produced, in the same order, with the same
    names, commands, timeouts and groups.

    TD-32 part 1b: with `apply_tier=False` the `--tier` scope is not applied,
    so the result is every check whose `requires` are met regardless of tier
    (used to tell a coverage group excluded by `--tier` apart from one that
    was never available at all).
    """
    python_timeout, python_jobs = _python_execution_settings(arguments)

    registry = load_validation_registry()
    context, available = _registry_placeholder_context(
        arguments=arguments, project=project, godot=godot,
        python_jobs=python_jobs, python_timeout=python_timeout,
    )
    tier = getattr(arguments, "tier", "full")
    allowed_tiers = TIER_SCOPES[tier]

    scenes: tuple[str, ...] | None = None

    def discovered_scenes() -> tuple[str, ...]:
        nonlocal scenes
        if scenes is None:
            scenes = discover_scene_names(project / "tests")
            if not scenes:
                raise ValueError(f"No Godot test scenes were found under {project / 'tests'}.")
        return scenes

    checks: list[Check] = []
    for entry in registry:
        if not all(_requirement_met(item, available) for item in entry["requires"]):
            continue
        if apply_tier and entry["tier"] not in allowed_tiers:
            continue

        groups = list(entry["groups"])
        for condition, group in entry.get("optional_groups", []):
            if _requirement_met(condition, available) and group not in groups:
                groups.append(group)
        # TD-32 part 3b: the check's *effective* requires - its entry's own
        # `requires` widened by every `optional_arguments` condition this run
        # actually satisfied (an archive/executable an available-but-optional
        # clause added to the command is still an input this check reads).
        effective_requires = list(entry["requires"])
        for condition, _extra in entry.get("optional_arguments", []):
            if _requirement_met(condition, available) and condition not in effective_requires:
                effective_requires.append(condition)
        effective_requires = tuple(effective_requires)
        timeout_value = entry["timeout"]
        if timeout_value == "{python_timeout}":
            resolved_timeout = python_timeout
        elif timeout_value == "{python_handoff_timeout}":
            resolved_timeout = PYTHON_HANDOFF_TIMEOUT_SECONDS
        else:
            resolved_timeout = timeout_value

        family = entry.get("family") or ""
        if family == "godot_scenes":
            # TD-33: the family entry's own `exclusive_scenes` (if any) names
            # which expanded scenes cannot share the machine, per-scene - a
            # bare `exclusive: true` on this one templated entry would make
            # every discovered scene exclusive, which is not what item 1's
            # isolation measurement found.
            exclusive_scenes = frozenset(entry.get("exclusive_scenes") or ())
            for scene in discovered_scenes():
                checks.append(
                    Check(
                        entry["name"].replace("{scene}", scene),
                        godot_command(godot, project, entry["script"].replace("{scene}", scene)),
                        resolved_timeout,
                        tuple(groups),
                        entry["tier"],
                        entry["name"],
                        family=family,
                        godot=context["godot"], project=context["project"],
                        source_root=context.get("source_root", ""),
                        requires=effective_requires, kind=entry["kind"],
                        exclusive=scene in exclusive_scenes,
                    )
                )
            continue

        script = _interpolate(entry["script"], context, entry["name"]) if entry["script"] else ""
        args = [_interpolate(argument, context, entry["name"]) for argument in entry["arguments"]]
        for condition, extra in entry.get("optional_arguments", []):
            if _requirement_met(condition, available):
                args.extend(_interpolate(argument, context, entry["name"]) for argument in extra)
        kind = entry["kind"]
        shards = entry.get("shards")
        if shards:
            # TD-33 part 2: split one `godot_script` entry's rows across
            # `shards` independent processes - the same build_checks()-time
            # expansion `godot_scenes` already does per discovered scene,
            # keyed here by shard index instead. Every shard keeps the
            # entry's own timeout/groups/tier/requirements; only the command
            # (the extra `shard=K/N` argument) and the check's own name
            # differ, so each shard's fingerprint differs too.
            for shard_index in range(1, shards + 1):
                shard_command = godot_command(
                    godot, project, "--script", script, "--", *args, f"shard={shard_index}/{shards}",
                )
                checks.append(
                    Check(
                        f"{entry['name']} [{shard_index}/{shards}]", shard_command, resolved_timeout,
                        tuple(groups), entry["tier"], entry["name"],
                        family=family, profile=entry.get("profile") or "",
                        godot=context["godot"], project=context["project"],
                        source_root=context.get("source_root", ""),
                        requires=effective_requires, kind=kind,
                        exclusive=bool(entry.get("exclusive", False)),
                    )
                )
            continue
        if kind == "python":
            command = (context["python"], script, *args)
        elif kind == "godot_editor":
            command = godot_command(godot, project, *args)
        elif kind == "godot_script":
            command = godot_command(godot, project, "--script", script, "--", *args)
        else:
            raise ValueError(f"Registry entry '{entry['name']}': unsupported kind {kind!r} for a single check.")
        # TD-33: the Python regression suite shards itself up to
        # `python_jobs` already-parallel child processes, so its own
        # scheduling weight is that shard count, not 1 - it should not also
        # run alongside other checks as if it were a single-core check.
        weight = python_jobs if "{python_jobs}" in entry["arguments"] else 1
        checks.append(
            Check(entry["name"], command, resolved_timeout, tuple(groups), entry["tier"], entry["name"],
                  family=family, profile=entry.get("profile") or "",
                  godot=context["godot"], project=context["project"],
                  source_root=context.get("source_root", ""),
                  requires=effective_requires, kind=kind,
                  weight=weight, exclusive=bool(entry.get("exclusive", False)))
        )
    return checks


def expand_family_all_selection(names: Sequence[str], planned: Sequence[Check], families: dict[str, dict]) -> list[str]:
    """`--check "<family's all-members name>"` (e.g. "original event analysis
    groups") names every planned member of that process family, not a literal
    check name; expand it here, before `select_checks()` sees the names, to
    every planned member's own name. A name that is not a family's all-members
    name passes through unchanged. Expanding to zero names (no member planned,
    e.g. no `--elfimage`) is not an error - it means "no member is available".
    """
    all_names_by_family = {family["check"]: family_key for family_key, family in families.items()}
    expanded: list[str] = []
    for name in names:
        family_key = all_names_by_family.get(name)
        if family_key is None:
            expanded.append(name)
            continue
        expanded.extend(check.name for check in planned if check.family == family_key)
    return expanded


def expand_shard_all_selection(names: Sequence[str], planned: Sequence[Check]) -> list[str]:
    """`--check "<a sharded entry's own name>"` (e.g. "original catalog group
    routes") names every planned shard of that entry, not a literal check
    name - each shard's own name carries a trailing `" [K/N]"` `build_checks()`
    appended. Expand it here, before `select_checks()` sees the names, to
    every planned shard's own name, in shard order.

    A name that already matches a planned check's own name (an unsharded
    check, or one specific `"<name> [K/N]"`) passes through unchanged, and so
    does a name that matches no currently planned shard at all - unlike
    `expand_family_all_selection()`, this never turns a name into an empty
    expansion: a sharded entry excluded this run (by `--tier`, or a missing
    `--elfimage`) has none of its shard checks in `planned` at all, so its
    bare name is not a key below and passes through for `select_checks()`'s
    own registry-based diagnostic (the same message an unsharded excluded
    check's name gets).
    """
    planned_names = {check.name for check in planned}
    shards_by_registry_name: dict[str, list[str]] = {}
    for check in planned:
        if check.registry_name and check.name != check.registry_name and check.name.startswith(check.registry_name + " ["):
            shards_by_registry_name.setdefault(check.registry_name, []).append(check.name)
    expanded: list[str] = []
    for name in names:
        if name in planned_names:
            expanded.append(name)
            continue
        shard_names = shards_by_registry_name.get(name)
        if shard_names:
            expanded.extend(shard_names)
        else:
            expanded.append(name)
    return expanded


def _check_family_all_selection_is_available(
    names: Sequence[str], families: dict[str, dict],
    planned_before_tier: Sequence[Check], planned: Sequence[Check], tier: str,
) -> None:
    """TD-32 part 2c: `--check "<family's all-members name>"` when no member
    of that family is planned this run is a configuration error naming the
    reason, never an empty request that `select_checks()` reads as "run
    everything" - the failure mode `expand_family_all_selection()` expanding
    to zero names would otherwise produce silently.
    """
    all_names_by_family = {family["check"]: family_key for family_key, family in families.items()}
    for name in names:
        family_key = all_names_by_family.get(name)
        if family_key is None:
            continue
        if any(check.family == family_key for check in planned):
            continue
        if any(check.family == family_key for check in planned_before_tier):
            raise ValueError(
                f"no analysis-group check is planned in this run (excluded by --tier {tier})"
            )
        raise ValueError("no analysis-group check is planned in this run (requires --elfimage)")


def _refuse_process_shard_names(names: Sequence[str], families: dict[str, dict]) -> None:
    """TD-58 (D5): a process shard (`original event analysis groups [K/N]`) is
    made at run time from whatever members the run selected, so it is not a
    check a caller can name. Refuse it before `expand_family_all_selection()`
    would pass it through to `select_checks()`'s generic "unknown" message;
    the error names the family's all-members name instead.
    """
    for name in names:
        for family in families.values():
            if name.startswith(family["check"] + " ["):
                raise ValueError(
                    f"--check {name!r} names a process shard, which exists only at run time "
                    f"(the split depends on the selection and the recorded durations); "
                    f"select every member with --check {family['check']!r}"
                )


def _process_shard_count(family: dict, jobs: int, member_count: int) -> int:
    """TD-58 (D3): how many process checks a family's `member_count` selected
    members are split across - the registry's own `process_shards` (absent
    means 1), never more than `--jobs` (a sequential run would pay every
    process's shared start-up for nothing) or than the members there are
    (no process is ever empty). `1` is today's single process."""
    return max(1, min(int(family.get("process_shards", 1)), max(1, jobs), member_count))


def _partition_members(
    members: Sequence[Check], durations: dict[str, float], shard_count: int,
) -> list[tuple[Check, ...]]:
    """TD-58 (D2): split `members` (registry order) across `shard_count`
    shards by longest-processing-time-first on their recorded durations.

    Members go in by known seconds, descending (a tie, or a member with no
    recorded duration, keeps registry order - the sort is stable and an
    unknown member counts 0 s); each is given to the shard with the smallest
    `(known seconds, member count, shard index)`, so an empty shard always
    wins and, with no durations at all, the shards differ by at most one
    member. Each shard's members come back in registry order. A pure function
    of its arguments, so one run's partition is deterministic.
    """
    seconds = [0.0] * shard_count
    counts = [0] * shard_count
    assigned: list[list[int]] = [[] for _ in range(shard_count)]

    def known_seconds(index: int) -> float:
        return durations.get(members[index].name, 0.0)

    for index in sorted(range(len(members)), key=lambda member_index: -known_seconds(member_index)):
        shard = min(range(shard_count), key=lambda candidate: (seconds[candidate], counts[candidate], candidate))
        assigned[shard].append(index)
        seconds[shard] += known_seconds(index)
        counts[shard] += 1
    return [tuple(members[index] for index in sorted(indexes)) for indexes in assigned]


def collapse_families(
    checks: list[Check], families: dict[str, dict], *,
    jobs: int = 1, durations: dict[str, float] | None = None,
) -> list[Check]:
    """TD-32 part 2: replace every selected `analysis_group` member check, at
    the position of the first one, with one process check that runs
    `validate_event_analysis_groups.gd` for all of them in a single Godot
    process (the archive opened once). A selection with no member is
    returned unchanged; one member alone still becomes a one-profile process,
    so the process path is exercised even for a single `--check`. The
    process check's own report row is never produced - `run_check()` parses
    its `GROUPS_SUMMARY` line back into one row per member - so the v4
    report keeps one row per group either way.

    TD-32 part 2c: `families` is the mapping the caller already loaded
    (inside its own configuration `try`), not loaded again here. Every
    member's own `godot`/`project`/`source_root` fields (stamped by
    `build_checks()`) build the process command; a member's `command` tuple
    is never indexed for them.

    TD-58: a family with `process_shards` N splits the members across
    `min(N, jobs, member count)` process checks named `<check> [K/N]`, at the
    first member's position and in shard order, each with the family's own
    `process_timeout` and a `shard_plan` line (`_partition_members()`: LPT by
    `durations`, the member durations `main()` read once). With one process -
    no `process_shards`, `jobs` 1 (the default) or one member - the name is
    the family's own `check`, as before, with no plan line. The members stay
    the report's rows, fingerprinted and cached one by one, whichever process
    runs them.
    """
    members = [check for check in checks if check.family == "analysis_group"]
    if not members:
        return list(checks)
    family = families["analysis_group"]
    sample = members[0]
    known_durations = durations or {}
    shard_count = _process_shard_count(family, jobs, len(members))
    partition = (
        _partition_members(members, known_durations, shard_count) if shard_count > 1 else [tuple(members)]
    )
    process_checks: list[Check] = []
    for shard_index, shard_members in enumerate(partition, start=1):
        command = (
            sample.godot, "--headless", "--path", sample.project, "--script", family["script"],
            "--", sample.source_root, *[member.profile for member in shard_members],
        )
        name = family["check"]
        shard_plan = ""
        if shard_count > 1:
            name = f"{name} [{shard_index}/{shard_count}]"
            known = [known_durations[member.name] for member in shard_members if member.name in known_durations]
            shard_plan = (
                f"shard plan: {shard_index}/{shard_count}, {len(shard_members)} member(s), "
                f"{sum(known):.3f}s known, {len(shard_members) - len(known)} unknown"
            )
        process_checks.append(Check(
            name=name, command=command, timeout=family["process_timeout"],
            groups=tuple(family["groups"]), tier=family["tier"], registry_name=None,
            family="analysis_group", profile="", members=shard_members, shard_plan=shard_plan,
        ))
    collapsed: list[Check] = []
    inserted = False
    for check in checks:
        if check.family == "analysis_group":
            if not inserted:
                collapsed.extend(process_checks)
                inserted = True
            continue
        collapsed.append(check)
    return collapsed


# The `requires` vocabulary is registry conditions, not always literal CLI
# flags; only these two have one. An unmet condition without an entry here is
# still named by its registry spelling (e.g. "requires voice_arc").
_REQUIREMENT_FLAGS = {"elfimage": "--elfimage", "exe": "--exe"}


def select_checks(
    checks: Sequence[Check], names: Sequence[str], *,
    registry: Sequence[dict] | None = None, tier: str = "full",
    available: dict[str, bool] | None = None,
) -> list[Check]:
    """Keep composition simple - a caller either runs everything planned or
    names an exact subset of it, with no partial override - but if a name is
    a real registry entry that this run's `--tier`/availability excluded, say
    why instead of folding it into the generic "unknown" message.
    """
    requested = set(names)
    unknown = requested - {check.name for check in checks}
    if unknown and registry is not None:
        registry_by_name = {entry["name"]: entry for entry in registry}
        for name in sorted(unknown):
            entry = registry_by_name.get(name)
            if entry is None:
                continue
            reasons: list[str] = []
            if entry["tier"] not in TIER_SCOPES[tier]:
                reasons.append(f"excluded by --tier {tier}")
            if available is not None:
                for item in entry["requires"]:
                    if not available.get(item, False):
                        reasons.append(f"requires {_REQUIREMENT_FLAGS.get(item, item)}")
            if reasons:
                raise ValueError(f"--check name not in this run: {name} ({'; '.join(reasons)})")
    if unknown:
        raise ValueError("Unknown or unavailable --check name: " + ", ".join(sorted(unknown)))
    return [check for check in checks if not requested or check.name in requested]


def build_coverage(
    arguments: argparse.Namespace, tier: str, planned_before_tier: Sequence[Check],
    planned: Sequence[Check], selected: Sequence[Check], configuration_error: str = "",
) -> list[dict[str, object]]:
    """Coverage describes actual check membership, including selected subsets.

    `planned_before_tier` is every check whose `requires` were met regardless
    of `--tier` (`build_checks(..., apply_tier=False)`); `planned` is the same
    set narrowed to `tier`. A group with checks in the first but none in the
    second was excluded by the tier, not by a missing source.
    """
    source = getattr(arguments, "elfimage", None)
    executable = getattr(arguments, "exe", None)
    skipped_event = getattr(arguments, "skip_event_corpus", False)
    missing_source = "--elfimage was not supplied."
    missing_executable = "--exe was not supplied."
    unavailable = {
        "synthetic": "No synthetic checks were planned.",
        "original_corpus": missing_source,
        "event_corpus": "Disabled by --skip-event-corpus." if skipped_event else missing_source,
        "native_executable": missing_executable,
        "native_corpus": " ".join(reason for absent, reason in (
            (source is None, missing_source), (executable is None, missing_executable)
        ) if absent),
        "voice_payload": " ".join(reason for absent, reason in (
            (source is None, missing_source), (executable is None, missing_executable)
        ) if absent),
    }
    if source is not None and executable is not None and not (source / "voice.arc").is_file():
        unavailable["voice_payload"] = "Optional voice.arc is missing; voice payload was not checked."
    coverage = []
    for group_id, title in COVERAGE_TITLES.items():
        planned_before_tier_count = sum(group_id in check.groups for check in planned_before_tier)
        planned_count = sum(group_id in check.groups for check in planned)
        selected_count = sum(group_id in check.groups for check in selected)
        if configuration_error:
            selected_count = 0
            reason = "Configuration failed: " + configuration_error
        elif selected_count:
            reason = f"Included {selected_count} check(s) in this run."
            if selected_count < planned_count:
                reason += f" {planned_count - selected_count} check(s) filtered out by --check."
        elif planned_count:
            reason = f"All {planned_count} planned check(s) filtered out by --check."
        elif planned_before_tier_count:
            reason = f"Excluded by --tier {tier}."
        else:
            reason = unavailable[group_id] or "No checks were available for this group."
        if (
            not configuration_error and group_id == "native_corpus"
            and source is not None and executable is not None and not (source / "se.arc").is_file()
        ):
            reason += " Optional se.arc is missing; the EVENTB03 sound/native wait check was not run."
        coverage.append({
            "id": group_id, "title": title,
            "status": "included" if selected_count else "not_run",
            "reason": reason, "check_count": selected_count,
        })
    return coverage


def _parse_groups_summary(output: str) -> dict | None:
    """The `GROUPS_SUMMARY <json>` line `validate_event_analysis_groups.gd`
    prints once, at the end, or `None` if the process never printed one (a
    crash, or a script error that stopped it first)."""
    for line in output.splitlines():
        if line.startswith("GROUPS_SUMMARY "):
            try:
                return json.loads(line[len("GROUPS_SUMMARY "):])
            except json.JSONDecodeError:
                return None
    return None


def _group_block_span(output: str, profile: str) -> tuple[int, int] | None:
    """The character span of a member's own block, from its
    `=== GROUP <profile> ===` line to its `--- GROUP ... ---` line, or
    `None` if that opening marker never printed."""
    marker = f"=== GROUP {profile} ==="
    start = output.find(marker)
    if start == -1:
        return None
    end = output.find("\n--- GROUP", start)
    if end == -1:
        return start, len(output)
    line_end = output.find("\n", end + 1)
    return start, (line_end if line_end != -1 else len(output))


def _extract_group_block(output: str, profile: str) -> str:
    """A failed member's own block, bounded the same way a normal failing
    check's `output_tail` is."""
    span = _group_block_span(output, profile)
    if span is None:
        return output[-OUTPUT_TAIL_LIMIT:]
    return output[span[0]:span[1]][-OUTPUT_TAIL_LIMIT:]


def _member_results_from_summary(
    members: Sequence[Check], summary: dict | None, output: str,
    script_error: bool, process_returncode: int | None, elapsed: float,
) -> list[dict[str, object]]:
    """TD-32 part 2c: a `SCRIPT ERROR` is attributed to the one member whose
    own block contains it - that member alone becomes `error` - rather than
    to every member in the process. A member whose summary row is `passed`
    or `failed` stays that way unless the error fell inside its own block.
    A script error outside every block (before the first `=== GROUP` or
    after the last `--- GROUP`) only touches members with no summary row at
    all; a summary row that exists is trusted for the rest. The process's
    own exit code never decides a member's status.
    """
    groups_by_profile: dict[str, dict] = {}
    if summary is not None:
        for group in summary.get("groups", []):
            groups_by_profile[str(group.get("profile", ""))] = group

    match = GODOT_SCRIPT_ERROR.search(output) if script_error else None
    script_diagnostic = ""
    error_index: int | None = None
    if match is not None:
        error_index = match.start()
        line = output[error_index:].splitlines()[0].strip()
        script_diagnostic = f"GODOT_SCRIPT_FAILURE: process exit code {process_returncode}; " + line[:1000]
    missing_summary_diagnostic = (
        f"GROUPS_SUMMARY missing or malformed; process exit code {process_returncode}"
        if summary is None and match is None else ""
    )

    results: list[dict[str, object]] = []
    for member in members:
        span = _group_block_span(output, member.profile)
        error_in_block = error_index is not None and span is not None and span[0] <= error_index < span[1]
        if error_in_block:
            block = output[span[0]:span[1]] if span is not None else output
            tail = (block + "\n" + script_diagnostic)[-OUTPUT_TAIL_LIMIT:]
            results.append({
                "name": member.name, "status": "error", "return_code": None,
                "duration_seconds": elapsed, "output_tail": tail,
            })
            continue
        group = groups_by_profile.get(member.profile)
        if group is not None:
            status = "passed" if group.get("status") == "passed" else "failed"
            result: dict[str, object] = {
                "name": member.name, "status": status,
                "return_code": 0 if status == "passed" else 1,
                "duration_seconds": round(float(group.get("duration_seconds", 0.0)), 3),
            }
            if status != "passed":
                result["output_tail"] = _extract_group_block(output, member.profile)
            results.append(result)
            continue
        tail = script_diagnostic or missing_summary_diagnostic or f"GROUPS_SUMMARY has no group for profile {member.profile}"
        results.append({
            "name": member.name, "status": "error", "return_code": None,
            "duration_seconds": elapsed, "output_tail": tail[-OUTPUT_TAIL_LIMIT:],
        })
    return results


def _launch(
    check: Check, project: Path, *, env: dict[str, str] | None = None,
) -> tuple[str, int | None, str]:
    """Run `check.command` once; shared by `run_check()` and
    `_run_process_check()` (TD-32 part 2c) so the `TimeoutExpired`
    bytes/str decoding and the `OSError` branch live in exactly one place.

    `env` is the child's own environment (TD-33: a worker's own
    `APPDATA`/`TEMP`/`TMP`, everything else unchanged); `None` (every caller
    outside `run_checks_scheduled()`) means "inherit this process's own
    environment unchanged", exactly as before `--jobs` existed.

    Returns `(output, return_code, failure_kind)`: a completed process
    returns its own exit code with `failure_kind` `""`; a `TimeoutExpired`
    or `OSError` returns `return_code=None` with `failure_kind`
    `"timeout"`/`"error"` and its diagnostic line already appended to and
    printed with `output`.
    """
    try:
        process = subprocess.run(
            check.command,
            cwd=project,
            text=True,
            encoding="utf-8",
            errors="replace",
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            timeout=check.timeout,
            check=False,
            creationflags=subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0,
            env=env,
        )
        output = process.stdout or ""
        if output:
            print(output.rstrip(), flush=True)
        return output, process.returncode, ""
    except subprocess.TimeoutExpired as error:
        output = error.stdout or ""
        if isinstance(output, bytes):
            output = output.decode("utf-8", errors="replace")
        if output:
            print(output.rstrip(), flush=True)
        diagnostic = f"TIMEOUT after {check.timeout}s"
        print(diagnostic, flush=True)
        return output + "\n" + diagnostic, None, "timeout"
    except OSError as error:
        output = f"Could not launch check: {type(error).__name__}: {error}"
        print(output, flush=True)
        return output, None, "error"


def _run_process_check(
    check: Check, project: Path, *, env: dict[str, str] | None = None,
) -> list[dict[str, object]]:
    """The process form of `run_check()`: `check.members` (one per selected
    `analysis_group` profile) all run together as `check.command`, and this
    prints one summary line per member instead of one `--- PASSED/FAILED
    (N.NNNs) ---` line for the whole process (there is no single verdict for
    a process that verifies several unrelated groups), then one `process:`
    line with the process's own elapsed time and outcome (`completed`,
    `timeout` or `error`; TD-51). `completed` means only that the process
    ended by itself: its exit code is not on the line, and the verdicts are
    the member lines and the report's per-member statuses.

    TD-58: a shard of a split family (`check.shard_plan`) prints its one
    `shard plan:` line right after the `===` header; a timeout or launch
    error marks only that shard's own `check.members`."""
    print(f"\n=== {check.name} ===", flush=True)
    if check.shard_plan:
        print(check.shard_plan, flush=True)
    started = time.monotonic()
    output, return_code, failure_kind = _launch(check, project, env=env)
    elapsed = round(time.monotonic() - started, 3)
    if failure_kind == "timeout":
        tail = output[-OUTPUT_TAIL_LIMIT:]
        results = [
            {"name": member.name, "status": "timeout", "return_code": None,
             "duration_seconds": elapsed, "output_tail": tail}
            for member in check.members
        ]
    elif failure_kind == "error":
        results = [
            {"name": member.name, "status": "error", "return_code": None,
             "duration_seconds": elapsed, "output_tail": output[-OUTPUT_TAIL_LIMIT:]}
            for member in check.members
        ]
    else:
        plain_output = ANSI_ESCAPE.sub("", output)
        script_error = GODOT_SCRIPT_ERROR.search(plain_output) is not None
        summary = _parse_groups_summary(plain_output)
        results = _member_results_from_summary(
            check.members, summary, plain_output, script_error, return_code, elapsed,
        )
    for result in results:
        print(f"member: {result['name']} {result['status']} ({result['duration_seconds']:.3f}s)", flush=True)
    # TD-51: the process's own loaded duration, for every outcome. A member's
    # `duration_seconds` is its in-process time, and a timeout or error stamps
    # every member with this elapsed time, so the process's duration was
    # otherwise visible only as a timeout.
    outcome = failure_kind or "completed"
    print(
        f"process: {check.name} {outcome} in {elapsed:.3f}s "
        f"({len(check.members)} member(s), timeout {check.timeout}s)",
        flush=True,
    )
    return results


def run_check(
    check: Check, project: Path, *, env: dict[str, str] | None = None,
) -> dict[str, object] | list[dict[str, object]]:
    if check.members:
        return _run_process_check(check, project, env=env)
    print(f"\n=== {check.name} ===", flush=True)
    started = time.monotonic()
    output, return_code, failure_kind = _launch(check, project, env=env)
    if failure_kind:
        status = failure_kind
    else:
        status = "passed" if return_code == 0 else "failed"
        # Godot's editor can return zero after an autoload/preload parse failure.
        # Inspect direct Godot output only: Python's negative tests deliberately
        # print captured failing subprocesses and establish their own verdict.
        if check.command[1:2] == ("--headless",):
            plain_output = ANSI_ESCAPE.sub("", output)
            match = GODOT_SCRIPT_ERROR.search(plain_output)
            if match is not None:
                # v3 reports require a nonzero child exit for "failed". A
                # zero-exit script diagnostic is a validation error instead;
                # retain the actual child code in its bounded evidence tail.
                line = plain_output[match.start():].splitlines()[0].strip()
                diagnostic = f"GODOT_SCRIPT_FAILURE: process exit code {return_code}; " + line[:1000]
                output += "\n" + diagnostic
                print(diagnostic, flush=True)
                status = "error" if return_code == 0 else "failed"
                return_code = None if return_code == 0 else return_code
    duration = round(time.monotonic() - started, 3)
    print(f"--- {status.upper()} ({duration:.3f}s) ---", flush=True)
    result: dict[str, object] = {
        "name": check.name,
        "status": status,
        "return_code": return_code,
        "duration_seconds": duration,
    }
    if status != "passed":
        result["output_tail"] = output[-OUTPUT_TAIL_LIMIT:]
    return result


def run_checks(checks: Sequence[Check], project: Path) -> list[dict[str, object]]:
    """Run every planned check, flattening a process check's member results
    (`run_check()` returns `list[dict]` for one, `dict` for an ordinary
    check) into the same one-row-per-check-or-member list `main()` used to
    build with a plain list comprehension over `run_check()`."""
    results: list[dict[str, object]] = []
    for check in checks:
        outcome = run_check(check, project)
        if isinstance(outcome, list):
            results.extend(outcome)
        else:
            results.append(outcome)
    return results


# TD-33 follow-up: a planned check whose name is in neither `hit_rows` nor
# `run_results` when `_assemble_results()` builds the report's own rows -
# never reachable via `run_checks()`'s sequential path, and now (after the
# `_run_one_scheduled()` fix above) not reachable via the scheduler's own
# `except Exception` either, but kept as a fail-closed backstop against a
# future gap in either path silently dropping a check from the report and
# letting the run report green regardless.
NO_RESULT_OUTPUT_TAIL = "no result recorded for a planned check"


def _assemble_results(
    checks: Sequence[Check], hit_rows: Sequence[dict[str, object]], run_results: Sequence[dict[str, object]],
) -> list[dict[str, object]]:
    """`checks`' own planned order, one row per check: a cache hit's row
    from `hit_rows`, a miss's row from `run_results`, or - the backstop
    above - a synthetic `error` row naming the gap.
    """
    hit_by_name = {row["name"]: row for row in hit_rows}
    run_by_name = {result["name"]: result for result in run_results}
    results: list[dict[str, object]] = []
    for check in checks:
        if check.name in hit_by_name:
            results.append(hit_by_name[check.name])
        elif check.name in run_by_name:
            results.append(run_by_name[check.name])
        else:
            results.append({
                "name": check.name, "status": "error", "return_code": None,
                "duration_seconds": 0.0, "output_tail": NO_RESULT_OUTPUT_TAIL,
            })
    return results


# TD-33: `--jobs N` runs several checks' `run_check()`/`_launch()` calls on
# separate threads. Those functions still call the plain `print(...)` they
# always have (never touched below) - what changes is what that name
# resolves to. `_threaded_print()` shadows the builtin only for this module:
# with no worker buffer active (jobs=1, or any direct call to `run_check()`
# from a test or another tool) it forwards straight to the real
# `builtins.print()`, so sequential behaviour and every existing caller are
# byte-for-byte unchanged; a worker thread that has installed a buffer (see
# `_run_one_scheduled()`) has its check's whole output sequence collected
# instead, so the scheduler can print it as one block, never interleaved
# with another thread's.
import builtins as _builtins  # noqa: E402

_worker_output = threading.local()


def _threaded_print(*args: object, sep: str = " ", end: str = "\n", file: object = None, flush: bool = False) -> None:
    buffer = getattr(_worker_output, "buffer", None)
    if buffer is None or file is not None:
        _builtins.print(*args, sep=sep, end=end, file=file, flush=flush)
        return
    buffer.append(sep.join(str(a) for a in args) + end)


print = _threaded_print


class _WorkerGate:
    """Bounds concurrent check execution to `jobs` weight-units (TD-33) and
    hands each running check a set of free integer slot ids (`0..jobs-1`,
    sized to its own weight) for its exclusive use while it runs, so two
    checks running at the same time never share a worker scratch directory.
    An `exclusive` check takes every slot, so nothing else runs alongside it.

    Waiters are served strictly in arrival order (TD-65): a waiter takes its
    slots only when every earlier waiter has been served and enough slots are
    free for it, so a later waiter never takes slots while an earlier one is
    still waiting. The worker threads pop the scheduler's ordered queue
    (`_order_checks_for_run()`) and call `acquire` straight away, so arrival
    follows that order. The price is idling: a multi-slot head waiter with
    fewer slots free than it needs leaves those slots unused, up to
    `weight - 1` of them, until enough running checks end - which is why the
    weight-4 checks are ordered early, when the single-slot checks beside them
    are few, and kept back to back (TD-67). Before this a freed slot went to whichever woken waiter fitted
    first, so a weight-4 waiter could be overtaken by single-slot checks until
    the queue had drained (the 2026-10-10 closing batch lost about one worker
    of six for ~1,800 s that way).
    """

    def __init__(self, jobs: int) -> None:
        self._jobs = max(1, jobs)
        self._condition = threading.Condition()
        self._free_slots: list[int] = list(range(self._jobs))
        self._exclusive_active = False
        # One ticket per `acquire` call that has not yet been served, oldest first.
        self._waiters: deque[object] = deque()

    def acquire(self, weight: int, exclusive: bool) -> tuple[int, ...]:
        needed = self._jobs if exclusive else max(1, min(weight, self._jobs))
        ticket = object()
        with self._condition:
            self._waiters.append(ticket)
            try:
                while (
                    self._waiters[0] is not ticket
                    or self._exclusive_active
                    or len(self._free_slots) < needed
                ):
                    self._condition.wait()
                slots = tuple(sorted(self._free_slots[:needed]))
                for slot in slots:
                    self._free_slots.remove(slot)
                if exclusive:
                    self._exclusive_active = True
                return slots
            finally:
                # Served or abandoned (an exception out of `wait()`), the
                # ticket leaves the queue so it can never block the waiters
                # behind it, and the next head re-checks whether it fits now.
                self._waiters.remove(ticket)
                self._condition.notify_all()

    def release(self, slots: Sequence[int], exclusive: bool) -> None:
        with self._condition:
            self._free_slots.extend(slots)
            if exclusive:
                self._exclusive_active = False
            self._condition.notify_all()


def _worker_env(*, appdata_root: Path, temp_root: Path, slot: int) -> dict[str, str]:
    """The environment a worker slot's child runs with: its own `APPDATA`
    (moves Godot's `user://` on Windows - confirmed with
    `analysis/td33_probe_userdir.gd`) and its own `TEMP`/`TMP`, everything
    else passed through unchanged.

    `appdata_root` and `temp_root` are deliberately allowed to differ
    (TD-33 follow-up): a Python child's `TEMP`/`TMP` is rooted outside the
    tracked project (`tempfile.gettempdir()`'s own per-run subdirectory),
    never under `analysis/validation_workers/...` - `tempfile.gettempdir()`
    caches the resolved directory for the whole child process, and several
    tools (`tools/collect_mes_runtime_trace.py`'s `ensure_safe_output()`,
    exercised by `tests/test_collect_mes_runtime_trace.py`) reasonably
    assume that directory is never inside the repository; measured by
    running this scheduler with `--jobs 4` before this fix, which failed
    `test_capture_output_must_stay_outside_project_and_sources` for exactly
    that reason. A Godot child has no such assumption, so its `APPDATA` and
    `TEMP`/`TMP` both stay under the project's own per-run scratch tree, per
    the TD-33 spec.
    """
    appdata_directory = appdata_root / str(slot)
    appdata_directory.mkdir(parents=True, exist_ok=True)
    temp_directory = temp_root / str(slot)
    temp_directory.mkdir(parents=True, exist_ok=True)
    env = dict(os.environ)
    env["APPDATA"] = str(appdata_directory)
    env["TEMP"] = str(temp_directory)
    env["TMP"] = str(temp_directory)
    return env


def _cache_recorded_durations(cache_dir: Path) -> dict[str, float]:
    """The last recorded duration for every check name the cache of green
    results has ever stored an entry for (TD-33 ordering: "the duration last
    recorded for that check ... the cache records ... whichever the runner
    already reads"). A name with more than one cache entry (different
    fingerprints over time) keeps the most recently recorded one. Malformed
    entries are ignored, exactly as `validation_cache.lookup()` ignores them.
    """
    durations: dict[str, tuple[str, float]] = {}
    if not cache_dir.is_dir():
        return {}
    for entry_path in cache_dir.rglob("*.json"):
        try:
            entry = json.loads(entry_path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            continue
        if not isinstance(entry, dict):
            continue
        name = entry.get("name")
        recorded_at = entry.get("recorded_at")
        duration = entry.get("duration_seconds")
        if not isinstance(name, str) or not name or not isinstance(recorded_at, str):
            continue
        if not isinstance(duration, (int, float)):
            continue
        previous = durations.get(name)
        if previous is None or recorded_at > previous[0]:
            durations[name] = (recorded_at, float(duration))
    return {name: duration for name, (_recorded_at, duration) in durations.items()}


def _report_recorded_durations(report_path: Path | None) -> dict[str, float]:
    """Non-cached durations from a previous run's own report at
    `report_path`, if one already exists there and still parses (the other
    source `_order_checks_for_run()` reads, per TD-33's "the last report").
    A cached row's own `duration_seconds` is always `0` (it did not run), so
    it is not a usable duration measurement and is skipped.
    """
    if report_path is None:
        return {}
    try:
        raw = json.loads(Path(report_path).read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return {}
    payload = raw.get("payload_json") if isinstance(raw, dict) else None
    try:
        report = json.loads(payload) if isinstance(payload, str) else None
    except json.JSONDecodeError:
        return {}
    if not isinstance(report, dict):
        return {}
    checks = report.get("checks")
    if not isinstance(checks, list):
        return {}
    durations: dict[str, float] = {}
    for row in checks:
        if not isinstance(row, dict) or row.get("cached"):
            continue
        name = row.get("name")
        duration = row.get("duration_seconds")
        if isinstance(name, str) and name and isinstance(duration, (int, float)):
            durations[name] = float(duration)
    return durations


def _recorded_durations(cache_dir: Path, report_path: Path | None) -> dict[str, float]:
    """The duration last recorded for every check name either source knows
    (TD-58: the one place the lookup lives, read once by `main()` for both
    the family partition and the scheduler's ordering): the last report at
    `report_path`, if it already exists and names the check as a run (not a
    cached row); otherwise the green-result cache. The two sources merge per
    check (TD-40): a reused report in which some rows were cached no longer
    discards the cache's duration for those checks, which are exactly the
    ones a `--cached` rerun cannot time. A name neither source records is
    absent.
    """
    durations = _cache_recorded_durations(cache_dir)
    durations.update(_report_recorded_durations(report_path))
    return durations


def _order_checks_for_run(
    checks: Sequence[Check], *, cache_dir: Path, report_path: Path | None,
    durations: dict[str, float] | None = None, jobs: int = 1,
) -> list[Check]:
    """Longest-first by the recorded duration times the slots a check
    occupies (TD-33 scheduling order, TD-58 D9), so a check that holds
    several of `jobs` slots for its run starts early instead of parking a
    worker thread behind a shorter single-slot one. Every `exclusive` check
    runs after every other check (TD-64 D4): see the last paragraph.

    The recorded duration is `_recorded_durations()`: the last report at
    `report_path`, then the green-result cache, then the check's own
    position in `checks` (registry order - `sorted()` is stable, so every
    check with no recorded duration keeps its relative registry order,
    sorted after every check a duration is known for). `durations`, when the
    caller already read them (`main()` does, once), replaces that lookup; the
    order is the same either way.

    A process check (`members`, the `original event analysis groups` process
    or shard `collapse_families()` builds) has no duration under its own
    name - the report and the cache record one row per member - so its
    duration is the sum of its members' known durations, each found as above
    (TD-42). The member sum underestimates the process (its wall time also
    covers the Godot startup and the members' shared work), which is enough
    to start it in the first wave; no report or cache schema carries the
    process time. A check with `members` counts at weight 1, so it sorts by
    its member sum alone. Any other check sorts by its duration times
    `min(weight, jobs)`, the slots it will occupy.

    An `exclusive` check sorts after every non-exclusive one, by its duration
    alone among the exclusive ones (TD-64 D4). It takes every slot while it
    runs and `_WorkerGate.acquire` serves waiters in arrival order (TD-65),
    so an exclusive check ordered anywhere but last would drain the machine
    at its turn and hold every check behind it back until it had run. Last,
    it holds nothing back, and the machine is otherwise idle while it runs.

    The multi-slot checks then run back to back (TD-67, at every `--jobs`).
    Under strict FIFO a multi-slot head idles exactly when it reaches the head
    while fewer slots are free than it needs, and a single-slot check whose
    key lands between two multi-slot ones (the transfer-direction corpus
    against the Python suite, TD-56) puts one such head behind it: three slots
    idled for 839 s. After the sort above, M0 is the first non-exclusive check
    whose slot count (`min(weight, jobs)`, one for a check with `members`)
    exceeds one, at index `i0`; the next `max(0, jobs - slots(M0) - i0)`
    non-exclusive single-slot checks stay right behind it (the window: the
    fillers that run beside M0, the shards and the critical path among them);
    every later multi-slot check follows the window, in sorted order; the rest
    keep the sorted order. With fewer than two multi-slot checks, and at
    `--jobs 1`, this is the sorted order unchanged, and the exclusive checks
    stay last. The gate is not changed. The rule is `fix1_order` of the
    TD-67 model (`todo/code_health.md`, `docs/spec/data/validation_checks.md`).
    """
    if durations is None:
        durations = _recorded_durations(cache_dir, report_path)

    def duration_of(check: Check) -> float:
        if check.members:
            member_sum = sum(duration_of(member) for member in check.members)
            if member_sum > 0.0:
                return member_sum
        return durations.get(check.name, 0.0)

    def slots_of(check: Check) -> int:
        return 1 if check.members else max(1, min(check.weight, jobs))

    def sort_key(check: Check) -> tuple[int, float]:
        if check.exclusive:
            return (1, -duration_of(check))
        return (0, -duration_of(check) * slots_of(check))

    ordered = sorted(checks, key=sort_key)
    multi = [index for index, check in enumerate(ordered) if not check.exclusive and slots_of(check) > 1]
    if len(multi) < 2:
        return ordered
    first = multi[0]
    window_size = max(0, jobs - slots_of(ordered[first]) - first)
    later_multi_indexes = set(multi[1:])
    rest = [check for index, check in enumerate(ordered) if index > first and index not in later_multi_indexes]
    window: list[Check] = []
    while rest and len(window) < window_size and not rest[0].exclusive:
        window.append(rest.pop(0))
    return ordered[:first + 1] + window + [ordered[index] for index in multi[1:]] + rest


def _scheduler_exception_results(
    check: Check, exception_text: str, duration: float,
) -> dict[str, object] | list[dict[str, object]]:
    """A worker-thread exception that happened outside `_launch()`'s own
    `TimeoutExpired`/`OSError` handling (TD-33 follow-up: `_worker_env()`'s
    `mkdir`, or any other unexpected failure) must still produce a result
    row for the check it was running - never silently drop it, which could
    let the whole run report green with a planned check missing (the
    fail-open regression this closes). Shaped exactly like `_launch()`'s own
    `OSError` branch: status `error`, `return_code` `None`, the traceback
    text in `output_tail`. A process-family check (`check.members`) yields
    one such row per member, the same shape `_run_process_check()`'s own
    `failure_kind == "error"` branch gives every member on a launch failure.
    """
    tail = exception_text[-OUTPUT_TAIL_LIMIT:]
    if check.members:
        return [
            {"name": member.name, "status": "error", "return_code": None,
             "duration_seconds": duration, "output_tail": tail}
            for member in check.members
        ]
    return {
        "name": check.name, "status": "error", "return_code": None,
        "duration_seconds": duration, "output_tail": tail,
    }


def _run_one_scheduled(
    check: Check, project: Path, gate: "_WorkerGate", jobs: int,
    repo_worker_root: Path, external_worker_root: Path, print_lock: threading.Lock,
) -> list[dict[str, object]]:
    """Run one check on the calling (worker) thread: reserve its weight's
    worth of worker slots (every slot when `check.exclusive`), give it its
    own `APPDATA`/`TEMP`/`TMP` for the duration, and print its whole output
    block atomically once it finishes - never interleaved with another
    thread's block (TD-33).

    TD-33 follow-up: any exception this raises - `_worker_env()`'s `mkdir`,
    or any other unexpected failure `run_check()`/`_launch()`'s own guarding
    does not already turn into a `timeout`/`error` result - is caught here,
    turned into an `error` result via `_scheduler_exception_results()`, and
    still printed as this check's own block (with the traceback appended);
    it never propagates out of this function. Before this fix an
    unanticipated exception here killed the worker thread silently: the
    check's buffered output was never printed (the print happened after the
    now-unreached `try`), no result row was produced for it, and `main()`'s
    row assembly simply omitted the check from the report - a fail-open
    regression, since a run missing one check's row could still report
    green. The gate slots are still released in every case (the outer
    `finally` does not change).
    """
    weight = max(1, min(check.weight, jobs))
    slots = gate.acquire(weight, check.exclusive)
    started = time.monotonic()
    exception_text: str | None = None
    block = ""
    try:
        _worker_output.buffer = []
        try:
            temp_root = external_worker_root if check.kind == "python" else repo_worker_root
            env = _worker_env(appdata_root=repo_worker_root, temp_root=temp_root, slot=slots[0])
            outcome = run_check(check, project, env=env)
        except Exception:
            exception_text = traceback.format_exc()
            outcome = _scheduler_exception_results(check, exception_text, round(time.monotonic() - started, 3))
        finally:
            block = "".join(_worker_output.buffer)
            _worker_output.buffer = None
    finally:
        gate.release(slots, check.exclusive)
    if exception_text is not None:
        if not block:
            block = f"\n=== {check.name} ===\n"
        duration = round(time.monotonic() - started, 3)
        block += f"SCHEDULER_EXCEPTION: {exception_text.rstrip()}\n--- ERROR ({duration:.3f}s) ---\n"
    with print_lock:
        _builtins.print(block, end="", flush=True)
    return outcome if isinstance(outcome, list) else [outcome]


def run_checks_scheduled(
    checks: Sequence[Check], project: Path, *, jobs: int, cache_dir: Path, report_path: Path | None,
    run_id: str, durations: dict[str, float] | None = None,
) -> tuple[list[dict[str, object]], Path, Path]:
    """The `--jobs N` (`N > 1`) form of `run_checks()`: the same planned,
    already-family-collapsed `checks`, run by up to `jobs` worker threads
    instead of one after another. Every result row for every check is still
    returned (`main()` re-keys them by name into the report's own
    registry-order rows, so this function's own return order does not need
    to match the checks' registry order - only that every row is present).
    `durations` is the recorded-duration lookup `main()` already read (and
    partitioned the analysis-group members by); omitted, it is read here from
    `cache_dir` and `report_path`, which gives the same order.

    Returns `(results, repo_worker_root, external_worker_root)`:
    `repo_worker_root` (`analysis/validation_workers/<run>`) is every Godot
    child's own `APPDATA`/`TEMP`/`TMP` root, per the TD-33 spec;
    `external_worker_root` (under `tempfile.gettempdir()`, never under the
    tracked project) is where a Python child's own `TEMP`/`TMP` is rooted
    instead - see `_worker_env()`. The caller removes both once it knows the
    run finished green.
    """
    repo_worker_root = project / "analysis" / "validation_workers" / run_id
    external_worker_root = Path(tempfile.gettempdir()) / "kakyu_validation_workers" / run_id
    gate = _WorkerGate(jobs)
    print_lock = threading.Lock()
    ordered = _order_checks_for_run(
        checks, cache_dir=cache_dir, report_path=report_path, durations=durations, jobs=jobs,
    )
    pending = list(ordered)
    pending_lock = threading.Lock()
    results: list[dict[str, object]] = []
    results_lock = threading.Lock()

    def worker_loop() -> None:
        while True:
            with pending_lock:
                if not pending:
                    return
                check = pending.pop(0)
            rows = _run_one_scheduled(
                check, project, gate, jobs, repo_worker_root, external_worker_root, print_lock,
            )
            with results_lock:
                results.extend(rows)

    thread_count = max(1, min(jobs, len(checks))) if checks else 0
    threads = [threading.Thread(target=worker_loop, name=f"validation-worker-{index}") for index in range(thread_count)]
    for thread in threads:
        thread.start()
    for thread in threads:
        thread.join()
    return results, repo_worker_root, external_worker_root


def configure_output_streams() -> None:
    for stream in (sys.stdout, sys.stderr):
        reconfigure = getattr(stream, "reconfigure", None)
        if reconfigure is not None:
            reconfigure(encoding="utf-8", errors="replace")


def _report_options_after_parse_error() -> argparse.Namespace:
    """Recover report routing even if an earlier numeric/unknown option failed."""
    parser = ConfigurationParser(add_help=False)
    for option in ("--report", "--elfimage", "--exe"):
        parser.add_argument(option, type=Path)
    parser.add_argument("--run-id")
    parser.add_argument("--skip-event-corpus", action="store_true")
    parser.add_argument("--tier", choices=TIER_CHOICES, default="full")
    try:
        return parser.parse_known_args()[0]
    except ValueError:
        return argparse.Namespace(
            report=None, elfimage=None, exe=None, run_id=None,
            skip_event_corpus=False, tier="full",
        )


def _context(arguments: argparse.Namespace, tier: str) -> dict[str, str]:
    def source_path(value: Path | None) -> str:
        if value is None:
            return ""
        try:
            return str(value.expanduser().resolve())
        except (OSError, RuntimeError, ValueError):
            # A malformed source path is itself a configuration error. Keep
            # its entered spelling available without blocking that report.
            return str(value)

    cache_dir_value = getattr(arguments, "cache_dir", DEFAULT_CACHE_DIR)
    return {
        "kind": "repository_suite",
        "elfimage": source_path(arguments.elfimage),
        "executable": source_path(arguments.exe),
        "workspace_validation": "not_performed",
        "tier": tier,
        "cache": "consulted" if getattr(arguments, "cached", False) else "not_consulted",
        "cache_dir": str(cache_dir_value),
        "jobs": int(getattr(arguments, "jobs", 1)),
    }


def _resolve_cache_dir(arguments: argparse.Namespace, project: Path) -> Path:
    """The actual directory `validation_cache` reads/writes: `--cache-dir`
    (default `DEFAULT_CACHE_DIR`) resolved against `project` unless given as
    an absolute path. `_context()`'s own `cache_dir` report field keeps the
    argument's own spelling instead ("as given").
    """
    cache_dir = Path(getattr(arguments, "cache_dir", DEFAULT_CACHE_DIR))
    return cache_dir if cache_dir.is_absolute() else project / cache_dir


def ensure_editor_ignore(directory: Path) -> bool:
    """Keep the Godot editor's first filesystem scan out of `directory`
    (TD-52); returns whether this call wrote the marker.

    Tool decision, not an original-engine fact. The `Godot project parse
    check` (`--editor --quit-after 2`) is nothing but the editor's
    `first_scan_filesystem`, and the quit aborts the threaded scan, so the
    editor's filesystem cache never completes and every run re-walks the
    whole tree. The untracked `analysis/` (about 22,400 files, no marker) was
    about 87% of that walk: the check took 79.9 s in the TD-51 closing batch
    and about 39 s solo (TD-52 baselines 40.3 s and 38.6 s), against a 120 s
    timeout. An empty `.gdignore` hides the directory from the editor's scan;
    nothing loads `analysis/` through the editor filesystem (the one
    `res://analysis` reader globalizes it to an OS path).

    The marker is written only when `directory` already exists and has none:
    this never creates the directory and never rewrites an existing marker
    (the exclusive create also holds if two runs race on it). The marker only
    saves scan time, so any other `OSError` (a read-only or ACL-restricted
    `directory`) is treated as "not written" rather than aborting the batch.
    """
    try:
        # `is_dir()` re-raises a stat error other than "absent" (an
        # ACL-restricted `directory`), so it sits inside the same handler.
        if not directory.is_dir():
            return False
        with (directory / ".gdignore").open("x", encoding="utf-8"):
            pass
    except OSError:
        # FileExistsError is the common case (the marker is already there).
        return False
    return True


def _fingerprint_context(arguments: argparse.Namespace, project: Path, godot: Path) -> dict[str, str]:
    """The same placeholder context `build_checks()` interpolates commands
    with, rebuilt here (cheaply - it only validates and stat()s a handful of
    paths) because `build_checks()` does not return it.
    """
    python_timeout, python_jobs = _python_execution_settings(arguments)
    context, _available = _registry_placeholder_context(
        arguments=arguments, project=project, godot=godot,
        python_jobs=python_jobs, python_timeout=python_timeout,
    )
    return context


def _print_fingerprints(checks: Sequence[Check], project: Path, context: dict[str, str]) -> int:
    """TD-32 part 3a `--fingerprints`: one line per planned check (members
    of the analysis-group family individually, before `collapse_families()`)
    - `<fingerprint>\\t<input file count>\\t<unresolved count>\\t<dynamic
    yes|no>\\t<name>` - then a summary line, and exit 0. Writes no report.
    """
    core_version = validation_inputs.read_core_version(project)
    file_memo: dict[str, str] = {}
    external_memo: dict[str, str] = {}
    started = time.monotonic()
    for check in checks:
        inputs = validation_inputs.check_inputs(check, project, context)
        command_text = validation_inputs.normalize_command(check.command, context)
        digest = validation_inputs.fingerprint(
            inputs, core_version, command_text, file_memo=file_memo, external_memo=external_memo,
        )
        dynamic_flag = "yes" if inputs.dynamic else "no"
        print(f"{digest}\t{len(inputs.files)}\t{len(inputs.unresolved)}\t{dynamic_flag}\t{check.name}")
    elapsed = round(time.monotonic() - started, 3)
    print(f"Fingerprinted {len(checks)} check(s) in {elapsed}s.")
    return 0


def _print_fingerprint_inputs(name: str, selected: Sequence[Check], project: Path, context: dict[str, str]) -> int:
    """TD-32 part 3c, section 2(c): `--fingerprint-inputs "<name>"` operates
    on the *selected* checks (`select_checks()`'s own result - after `--tier`
    and `--check`), the same population `--fingerprints` prints, not every
    planned check regardless of selection. `main()` already validated `name`
    is in that selection (the same `select_checks()` call, and so the same
    error, `--check` itself uses) before calling this, so the fallback below
    is defensive only.
    """
    by_name = {check.name: check for check in selected}
    check = by_name.get(name)
    if check is None:
        print(f"VALIDATION_CONFIGURATION_ERROR: --fingerprint-inputs name not in this run: {name}", file=sys.stderr)
        return 2
    inputs = validation_inputs.check_inputs(check, project, context)
    for relative_path in inputs.files:
        print(relative_path)
    for external_name in inputs.external:
        print(external_name)
    print("UNRESOLVED:")
    for reference in inputs.unresolved:
        print(reference)
    return 0


def main() -> int:
    configure_output_streams()
    project = Path(__file__).resolve().parents[2]
    run_id = str(uuid.uuid4())
    arguments = None
    configuration_error = ""
    planned_before_tier: list[Check] = []
    planned: list[Check] = []
    checks: list[Check] = []
    families: dict[str, dict] = {}
    # TD-32 part 3c, section 2(d): computed once, inside this configuration
    # `try`, right after `checks` itself - never again afterwards. A missing
    # archive directory removed between planning and here is exactly the
    # same configuration error `build_checks()` already raises for it; the
    # old second call, made outside this guard, would instead surface as an
    # unhandled traceback.
    fingerprint_context: dict[str, str] = {}
    try:
        arguments = parse_args()
        if arguments.run_id is not None:
            try:
                run_id = str(uuid.UUID(arguments.run_id))
            except ValueError as error:
                raise ValueError("--run-id must be a UUID.") from error
        # TD-32 part 3b: `--cache-clear` is allowed alone (with or without
        # `--cached`/`--cache-store`) and does not depend on planning
        # succeeding.
        if arguments.cache_clear:
            validation_cache.clear(_resolve_cache_dir(arguments, project))
        if arguments.jobs <= 0:
            raise ValueError("--jobs must be greater than zero.")
        godot = find_godot(arguments.godot)
        planned_before_tier = build_checks(arguments, project, godot, apply_tier=False)
        tier = getattr(arguments, "tier", "full")
        allowed_tiers = TIER_SCOPES[tier]
        planned = [check for check in planned_before_tier if check.tier in allowed_tiers]
        registry = load_validation_registry()
        families = load_validation_families()
        available = _availability(arguments)
        _refuse_process_shard_names(arguments.check, families)
        _check_family_all_selection_is_available(arguments.check, families, planned_before_tier, planned, tier)
        requested = expand_family_all_selection(arguments.check, planned, families)
        requested = expand_shard_all_selection(requested, planned)
        checks = select_checks(planned, requested, registry=registry, tier=tier, available=available)
        # TD-32 part 3c, section 2(c): `--fingerprint-inputs NAME` names a
        # check within this run's own *selection* (after `--check`/`--tier`),
        # not merely a planned one; an out-of-selection name fails exactly
        # the way an unknown/excluded `--check` name does, through the same
        # `select_checks()` call (its return value is not used here - only
        # its validation, against the already-`--check`-filtered `checks`).
        fingerprint_inputs_name = getattr(arguments, "fingerprint_inputs", None)
        if fingerprint_inputs_name is not None:
            select_checks(checks, [fingerprint_inputs_name], registry=registry, tier=tier, available=available)
        fingerprint_context = _fingerprint_context(arguments, project, godot)
    except (ValueError, OSError) as error:
        configuration_error = str(error)
        if arguments is None:
            arguments = _report_options_after_parse_error()
            try:
                if arguments.run_id is not None:
                    run_id = str(uuid.UUID(arguments.run_id))
            except ValueError:
                pass
        print(f"VALIDATION_CONFIGURATION_ERROR: {error}", file=sys.stderr)

    fingerprints_requested = getattr(arguments, "fingerprints", False)
    fingerprint_inputs_requested = getattr(arguments, "fingerprint_inputs", None)
    if fingerprints_requested or fingerprint_inputs_requested:
        if configuration_error:
            return 2
        if fingerprints_requested:
            return _print_fingerprints(checks, project, fingerprint_context)
        return _print_fingerprint_inputs(fingerprint_inputs_requested, checks, project, fingerprint_context)

    tier = getattr(arguments, "tier", "full")
    print(f"TIER: {tier}")
    cache_dir = _resolve_cache_dir(arguments, project)
    # TD-52: before any check (either scheduler, every tier) so the Godot
    # project parse check's editor scan skips the untracked analysis/ tree.
    ensure_editor_ignore(project / "analysis")
    started = time.monotonic()
    # TD-32 part 3c, section 2(a): the cache is engaged - fingerprinted,
    # read and/or written - only when `--cached` and/or `--cache-store` ask
    # for it; with neither, nothing is fingerprinted, looked up or stored,
    # and `context.cache` stays `not_consulted` (`_context()`).
    cache_engaged = bool(getattr(arguments, "cached", False)) or bool(getattr(arguments, "cache_store", False))
    # TD-32 part 3b: every selected check's own fingerprint is computed once,
    # before running anything - `--cached` looks each up as a candidate hit;
    # every check `--cached`/`--cache-store` runs is stored after it passes.
    # `checks` is still the pre-collapse, one-row-per-member list.
    fingerprint_by_name: dict[str, str] = {}
    hit_rows: list[dict[str, object]] = []
    miss_checks: list[Check] = list(checks)
    core_version = ""
    if not configuration_error and checks and cache_engaged:
        core_version = validation_inputs.read_core_version(project)
        file_memo: dict[str, str] = {}
        external_memo: dict[str, str] = {}
        for check in checks:
            # A check this run's own `build_checks()` planned always has a
            # `kind`/`requires` the classifier understands; a synthetic
            # `Check(...)` a caller builds by hand (a test fixture, never a
            # planned check in an actual run) may not - skip caching for it
            # rather than failing the whole run over an unfingerprintable
            # check ("...whose fingerprint was computed").
            try:
                inputs = validation_inputs.check_inputs(check, project, fingerprint_context)
                command_text = validation_inputs.normalize_command(check.command, fingerprint_context)
                fingerprint_by_name[check.name] = validation_inputs.fingerprint(
                    inputs, core_version, command_text, file_memo=file_memo, external_memo=external_memo,
                )
            except (ValueError, OSError):
                continue
        if arguments.cached:
            miss_checks = []
            for check in checks:
                digest = fingerprint_by_name.get(check.name)
                entry = validation_cache.lookup(cache_dir, check.name, digest) if digest is not None else None
                if entry is None:
                    miss_checks.append(check)
                    continue
                print(f"\n=== {check.name} ===", flush=True)
                print(f"--- CACHED (recorded {entry['recorded_at']}) ---", flush=True)
                hit_rows.append({
                    "name": check.name, "status": "passed", "return_code": 0, "duration_seconds": 0.0,
                    "cached": True, "cached_at": entry["recorded_at"], "cached_run_id": entry["run_id"],
                })
    # `collapse_families()` only changes what actually runs (every selected
    # `analysis_group` member still planned to run becomes one shared-process
    # check); coverage and the row count stay keyed to `checks`, the
    # pre-collapse member list, so `check_count` in the report still equals
    # the number of member checks.
    jobs = int(getattr(arguments, "jobs", 1))
    repo_worker_root: Path | None = None
    external_worker_root: Path | None = None
    # TD-58: the member durations are read once (report first, else cache -
    # the scheduler's own sources) and shared by the partition of the
    # analysis-group members and the scheduler's ordering. A sequential run
    # needs neither: it keeps one process and the registry order.
    durations = _recorded_durations(cache_dir, arguments.report) if jobs > 1 else None
    collapsed_miss_checks = collapse_families(miss_checks, families, jobs=jobs, durations=durations)
    if jobs <= 1:
        # TD-33: unchanged from before `--jobs` existed - same order, same
        # direct prints, no scheduler, no scratch directory.
        run_results = run_checks(collapsed_miss_checks, project)
    else:
        run_results, repo_worker_root, external_worker_root = run_checks_scheduled(
            collapsed_miss_checks, project, jobs=jobs, cache_dir=cache_dir,
            report_path=arguments.report, run_id=run_id, durations=durations,
        )
    if not configuration_error and checks and cache_engaged:
        for result in run_results:
            digest = fingerprint_by_name.get(result["name"])
            if digest is not None:
                validation_cache.store(cache_dir, result["name"], digest, result, run_id, core_version)
    # TD-32 part 3c, section 2(b): result rows keep `checks`' own planned
    # order - a hit's row from `hit_rows`, a miss's row from `run_results` -
    # instead of every hit before every miss. TD-33 follow-up: a planned
    # check with neither becomes a synthetic `error` row instead of being
    # silently omitted (`_assemble_results()`).
    results = _assemble_results(checks, hit_rows, run_results)
    elapsed = round(time.monotonic() - started, 3)
    report = make_report(
        results, duration_seconds=elapsed, run_id=run_id,
        coverage=build_coverage(arguments, tier, planned_before_tier, planned, checks, configuration_error),
        context=_context(arguments, tier),
        original_corpus=arguments.elfimage is not None and tier != "local",
        native_executable_audit=arguments.exe is not None and tier != "local",
        configuration_error=configuration_error,
    )
    print("\n=== CONTENT TOOLS VALIDATION SUMMARY ===")
    print(json.dumps(report, ensure_ascii=False, indent=2))
    if arguments.report is not None:
        try:
            write_report(arguments.report, report)
        except (OSError, ValueError) as error:
            print(f"VALIDATION_REPORT_ERROR: {error}", file=sys.stderr)
            return 2
        print(f"Report: {arguments.report.expanduser().resolve()}")
    exit_code = 2 if configuration_error else 1 if report["failed"] else 0
    # TD-33: the per-run worker scratch trees are removed only once the run
    # is known green - a red run keeps them, so a worker's own output/env is
    # still there to inspect.
    if exit_code == 0:
        for scratch_root in (repo_worker_root, external_worker_root):
            if scratch_root is not None and scratch_root.is_dir():
                shutil.rmtree(scratch_root, ignore_errors=True)
    return exit_code


if __name__ == "__main__":
    raise SystemExit(main())
