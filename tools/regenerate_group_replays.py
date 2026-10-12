"""Regenerates the analysis-group replay files (WD-21 U2 C2).

One validator process per profile: the committed single-profile CLI
`tools/content_suite/validators/validate_event_analysis_group.gd` with `--replay`,
which writes `kakyu_event_analysis_group_replay/v3` (v2 plus, per run, `executed`
and `resource_rows`; see `analysis/_docs/wd21_u2_spec.md` D2). Every profile of
`--profiles-dir` runs, `--jobs` of them at a time; nothing is written into the
original archive's directory.

    py tools/regenerate_group_replays.py "<ELFIMAGE directory>" ^
        --profiles-dir config/event_catalog/analysis_groups --out analysis/replays_v3 ^
        --jobs 4 [--godot "<Godot 4.7 console executable>"] [--only <profile stem> ...] [--timeout SECONDS]

The ELFIMAGE directory and the Godot executable come in as arguments only (the
Godot executable is discovered like `run_headless_validation.py --godot` when it
is not given). Output, all under `--out`:

* `<profile stem>.json` - the replay (a stale one is deleted before its profile
  runs, so a failed run can never leave an old file looking fresh);
* `_run_log.txt` - one line per profile in completion order,
  `<stem>\\texit=<code>\\t<seconds>s`, the format of `analysis/replays_v2/_run_log.txt`;
* `_logs/<stem>.log` - the validator's stdout and stderr (its `REPLAY_WRITTEN` line
  carries the run and library-invoked-definition counters).

A profile fails when its process exits non-zero, times out, or exits zero without
leaving a parseable replay of the v3 schema for that profile. The tool prints one
JSON summary line and exits 1 when any profile failed, 2 on a usage error.
"""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
import threading
import time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools" / "content_suite"))

import run_headless_validation as validation  # noqa: E402  (find_godot, one discovery rule)

VALIDATOR_SCRIPT = "res://tools/content_suite/validators/validate_event_analysis_group.gd"
REPLAY_SCHEMA = "kakyu_event_analysis_group_replay/v3"
RUN_LOG_NAME = "_run_log.txt"
LOG_DIRECTORY_NAME = "_logs"
DEFAULT_TIMEOUT_SECONDS = 3600


class UsageError(ValueError):
    pass


def list_profiles(profiles_dir: Path, only: list[str] | None) -> list[Path]:
    """Every `*.json` of `profiles_dir` by name, or just the `only` stems (each must exist)."""
    if not profiles_dir.is_dir():
        raise UsageError(f"profiles directory does not exist: {profiles_dir}")
    profiles = sorted(path for path in profiles_dir.glob("*.json") if path.is_file())
    if only:
        by_stem = {path.stem: path for path in profiles}
        unknown = sorted(set(only) - set(by_stem))
        if unknown:
            raise UsageError(f"unknown profile stem(s): {', '.join(unknown)}")
        profiles = [by_stem[stem] for stem in sorted(set(only))]
    if not profiles:
        raise UsageError(f"no profiles found in {profiles_dir}")
    return profiles


def validator_command(godot: Path, project: Path, elfimage: Path, profile: Path, replay: Path) -> list[str]:
    """The exact command line of one profile's validator process."""
    return [
        *validation.godot_command(godot, project, "--script", VALIDATOR_SCRIPT),
        "--", str(elfimage), str(profile), "--replay", str(replay),
    ]


def check_replay_file(replay: Path, stem: str) -> str:
    """Empty when `replay` is a parseable v3 replay of profile `stem`, else the reason."""
    if not replay.is_file():
        return "no replay file was written"
    try:
        document = json.loads(replay.read_text(encoding="utf-8"))
    except (OSError, ValueError) as error:
        return f"replay file does not parse: {error}"
    if not isinstance(document, dict):
        return "replay file is not a JSON object"
    if document.get("schema") != REPLAY_SCHEMA:
        return f"replay schema is {document.get('schema')!r}, expected {REPLAY_SCHEMA!r}"
    if document.get("profile") != stem:
        return f"replay names profile {document.get('profile')!r}, expected {stem!r}"
    if not isinstance(document.get("routes"), list):
        return "replay file has no routes list"
    return ""


def run_profile(godot: Path, project: Path, elfimage: Path, profile: Path, out: Path, timeout: int) -> dict:
    """Runs one validator process; returns `{stem, exit_code, seconds, error, log}`."""
    stem = profile.stem
    replay = out / f"{stem}.json"
    if replay.exists():
        replay.unlink()
    command = validator_command(godot, project, elfimage, profile, replay)
    started = time.time()
    error = ""
    exit_code: int
    text = ""
    try:
        completed = subprocess.run(
            command, cwd=project, capture_output=True, text=True, encoding="utf-8",
            errors="replace", timeout=timeout)
        exit_code = completed.returncode
        text = (completed.stdout or "") + (completed.stderr or "")
    except subprocess.TimeoutExpired as expired:
        exit_code = -1
        error = f"timed out after {timeout} s"
        for part in (expired.stdout, expired.stderr):
            if part:
                text += part if isinstance(part, str) else part.decode("utf-8", errors="replace")
    seconds = time.time() - started
    if exit_code != 0 and not error:
        error = f"validator exited {exit_code}"
    if exit_code == 0:
        error = check_replay_file(replay, stem)
    return {"stem": stem, "exit_code": exit_code, "seconds": seconds, "error": error, "log": text}


def regenerate(
    elfimage: Path, profiles_dir: Path, out: Path, jobs: int, godot: Path,
    only: list[str] | None = None, timeout: int = DEFAULT_TIMEOUT_SECONDS, project: Path = ROOT,
) -> dict:
    """Runs every selected profile; returns `{profiles, failed: [{stem, error}], seconds}`."""
    if jobs < 1:
        raise UsageError("--jobs must be at least 1")
    # The validator runs with the project root as its working directory, so every path it
    # is given is absolute.
    elfimage, profiles_dir, out = elfimage.resolve(), profiles_dir.resolve(), out.resolve()
    if not (elfimage / "mes.arc").is_file():
        raise UsageError(f"{elfimage} holds no mes.arc")
    profiles = list_profiles(profiles_dir, only)
    if out == elfimage or elfimage in out.parents:
        raise UsageError("--out must not be inside the original game directory")
    out.mkdir(parents=True, exist_ok=True)
    log_directory = out / LOG_DIRECTORY_NAME
    log_directory.mkdir(exist_ok=True)
    run_log = out / RUN_LOG_NAME
    lock = threading.Lock()
    started = time.time()
    failed: list[dict] = []
    with run_log.open("w", encoding="utf-8", newline="\n") as log_file:
        def work(profile: Path) -> None:
            result = run_profile(godot, project, elfimage, profile, out, timeout)
            (log_directory / f"{result['stem']}.log").write_text(result["log"], encoding="utf-8", newline="\n")
            with lock:
                log_file.write(f"{result['stem']}\texit={result['exit_code']}\t{result['seconds']:.1f}s\n")
                log_file.flush()
                if result["error"]:
                    failed.append({"stem": result["stem"], "error": result["error"]})

        with ThreadPoolExecutor(max_workers=jobs) as pool:
            for future in [pool.submit(work, profile) for profile in profiles]:
                future.result()
    failed.sort(key=lambda row: row["stem"])
    return {"profiles": len(profiles), "failed": failed, "seconds": round(time.time() - started, 1)}


def parse_arguments(argv: list[str] | None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("elfimage", type=Path, help="the user-owned ELFIMAGE directory (read-only input; holds mes.arc)")
    parser.add_argument("--profiles-dir", type=Path, required=True, help="directory of analysis-group profiles (config/event_catalog/analysis_groups)")
    parser.add_argument("--out", type=Path, required=True, help="directory the replays, _run_log.txt and _logs/ are written to")
    parser.add_argument("--jobs", type=int, default=1, help="validator processes at a time")
    parser.add_argument("--godot", type=Path, default=None, help="Godot 4.7 console executable (discovered when omitted)")
    parser.add_argument("--only", action="append", default=None, metavar="STEM", help="run only this profile stem (repeatable)")
    parser.add_argument("--timeout", type=int, default=DEFAULT_TIMEOUT_SECONDS, help="seconds one validator process may take")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    arguments = parse_arguments(argv)
    try:
        godot = validation.find_godot(arguments.godot)
        summary = regenerate(
            arguments.elfimage, arguments.profiles_dir, arguments.out, arguments.jobs, godot,
            only=arguments.only, timeout=arguments.timeout)
    except (UsageError, ValueError) as error:
        print(f"regenerate_group_replays: {error}", file=sys.stderr)
        return 2
    print(json.dumps(summary, sort_keys=True))
    return 1 if summary["failed"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
