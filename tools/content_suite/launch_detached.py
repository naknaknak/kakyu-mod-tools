"""Start a long command that survives the session which launched it (TD-40 b).

A background process an agent shell starts dies with that shell's job object
when the session exits - two whole-batch runs were lost that way. A process
created through WMI (`Win32_Process.Create`) has the WMI provider host, not the
caller, as its parent and so lives outside that job object. This tool starts
one such process, writes a marker beside its log, and reports on markers later:

    py tools/content_suite/launch_detached.py [--name NAME] [--log PATH] -- <command...>
    py tools/content_suite/launch_detached.py --status [--all]

The command runs with the project root as its working directory, its window
hidden, and stdout+stderr redirected to the log (`cmd.exe /c "... > log 2>&1"`,
since `Win32_Process.Create` has no handle redirection). The command line is
built from the argument list; no temporary script is written. The launched
process gets WMI's default environment, not the calling shell's, so name
every executable and path the command needs as an argument (for the validation
batch: `--godot`, `--elfimage`, `--exe`); the first word is resolved to an
absolute path here, in the caller's environment, when it is not one already.

Markers are `analysis/_undoc/detached/<stamp>.json` (`kakyu_detached_run/v1`),
logs `<stamp>.log` beside them; both are untracked. `--status` lists each
marker with whether its process is still running, the log's first and last
line, and (a hint, never acted on) any `*_console.exe` or Python process
that mentions the project and has lost its parent - a timed-out child's own
children can be left behind outside the agent's job object; stop one with
`Stop-Process -Id <pid>`.
"""
from __future__ import annotations

import argparse
import datetime
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[2]
MARKER_SCHEMA = "kakyu_detached_run/v1"
MARKER_DIRECTORY = Path("analysis") / "_undoc" / "detached"
# Characters that cannot be carried safely through `cmd.exe /c` even inside
# double quotes: a quote ends the quoting, `%` expands, a newline ends the line.
FORBIDDEN_ARGUMENT_CHARACTERS = re.compile(r'["%\r\n\x00]')
# The marker's `started_at` follows the create call by well under a second; a
# live process whose creation time is further from it than this is a reused pid.
PID_REUSE_TOLERANCE_SECONDS = 120

CREATE_SCRIPT = (
    "$ErrorActionPreference = 'Stop';"
    "$startup = New-CimInstance -ClassName Win32_ProcessStartup -ClientOnly -Property @{ShowWindow=[uint16]0};"
    "$result = Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{"
    "CommandLine=$env:KAKYU_DETACHED_COMMAND_LINE;CurrentDirectory=$env:KAKYU_DETACHED_CWD;"
    "ProcessStartupInformation=$startup};"
    "[Console]::Out.Write((@{ReturnValue=[int]$result.ReturnValue;ProcessId=[int]$result.ProcessId} | ConvertTo-Json -Compress))"
)
PROCESS_TABLE_SCRIPT = (
    "$ErrorActionPreference = 'Stop';"
    "[Console]::OutputEncoding = [System.Text.Encoding]::UTF8;"
    "$rows = @(Get-CimInstance Win32_Process | ForEach-Object {"
    "@{ProcessId=[int]$_.ProcessId;ParentProcessId=[int]$_.ParentProcessId;Name=[string]$_.Name;"
    "CreationDate=$(if ($_.CreationDate) {$_.CreationDate.ToUniversalTime().ToString('o')} else {$null});"
    "CommandLine=[string]$_.CommandLine}});"
    "[Console]::Out.Write(($rows | ConvertTo-Json -Compress -Depth 3))"
)


class LaunchError(RuntimeError):
    pass


def quote_argument(argument: str) -> str:
    """One argument as a double-quoted word for `cmd.exe /c` and the C runtime:
    always quoted, trailing backslashes doubled so they cannot escape the
    closing quote. An argument `cmd.exe` would still reinterpret raises."""
    if FORBIDDEN_ARGUMENT_CHARACTERS.search(argument):
        raise LaunchError("argument cannot be passed through cmd.exe safely (quote, percent or newline): %r" % argument)
    trailing = len(argument) - len(argument.rstrip("\\"))
    return '"' + argument + "\\" * trailing + '"'


def resolve_executable(word: str) -> str:
    """The first word of the command as an absolute path when it is not one
    already, resolved in the caller's environment (`py`, a bare script)."""
    if os.path.isabs(word):
        return word
    found = shutil.which(word)
    if found is None:
        raise LaunchError("cannot find the command's executable on PATH: %s" % word)
    return str(Path(found).resolve())


def build_command_line(argv: list[str], log_path: str | Path) -> str:
    """The full `CommandLine` handed to `Win32_Process.Create`."""
    if not argv:
        raise LaunchError("no command given after --")
    words = " ".join(quote_argument(word) for word in argv)
    # `cmd /s /c "<words> > log 2>&1"`: with /s the outer pair of quotes is
    # stripped and everything between is the command, so the inner quotes stay.
    return 'cmd.exe /d /s /c "%s > %s 2>&1"' % (words, quote_argument(str(log_path)))


def utc_now() -> datetime.datetime:
    return datetime.datetime.now(datetime.timezone.utc)


def make_stamp(now: datetime.datetime, name: str | None, directory: Path) -> str:
    """`<UTC time>[_<name>]`, made unique among the markers already in `directory`."""
    base = now.strftime("%Y%m%dT%H%M%SZ")
    if name:
        base += "_" + re.sub(r"[^A-Za-z0-9._-]+", "-", name).strip("-")
    stamp, counter = base, 1
    while (directory / (stamp + ".json")).exists() or (directory / (stamp + ".log")).exists():
        counter += 1
        stamp = "%s-%d" % (base, counter)
    return stamp


def project_relative(path: Path, root: Path) -> str:
    try:
        return path.resolve().relative_to(root.resolve()).as_posix()
    except ValueError:
        return str(path.resolve())


def build_marker(
    stamp: str, name: str | None, argv: list[str], command_line: str, log_path: Path, pid: int,
    started_at: datetime.datetime, root: Path,
) -> dict:
    return {
        "schema": MARKER_SCHEMA,
        "stamp": stamp,
        "name": name,
        "command": argv,
        "command_line": command_line,
        "working_directory": ".",
        "pid": pid,
        "log": project_relative(log_path, root),
        "started_at": started_at.isoformat(),
    }


def parse_create_output(text: str) -> int:
    """The new process's id from the PowerShell create script's one JSON line."""
    try:
        result = json.loads(text.strip().splitlines()[-1])
    except (IndexError, json.JSONDecodeError) as exc:
        raise LaunchError("unreadable output from the WMI create call: %r" % text[-300:]) from exc
    if result.get("ReturnValue") != 0:
        raise LaunchError("Win32_Process.Create failed with return value %s" % result.get("ReturnValue"))
    pid = result.get("ProcessId")
    if not isinstance(pid, int) or pid <= 0:
        raise LaunchError("Win32_Process.Create returned no process id: %r" % result)
    return pid


def run_powershell(script: str, extra_environment: dict[str, str] | None = None) -> str:
    environment = dict(os.environ)
    environment.update(extra_environment or {})
    completed = subprocess.run(
        ["powershell", "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-Command", script],
        capture_output=True, env=environment, timeout=120,
    )
    stdout = completed.stdout.decode("utf-8", "replace").lstrip("\ufeff")
    if completed.returncode != 0:
        raise LaunchError("powershell failed (exit %d): %s" % (
            completed.returncode, (stdout + completed.stderr.decode("utf-8", "replace"))[-600:]))
    return stdout


def wmi_create(command_line: str, working_directory: Path) -> int:
    """Create the process through WMI and return its pid (not unit-tested:
    it needs a real WMI provider)."""
    output = run_powershell(CREATE_SCRIPT, {
        "KAKYU_DETACHED_COMMAND_LINE": command_line,
        "KAKYU_DETACHED_CWD": str(working_directory),
    })
    return parse_create_output(output)


def launch(argv: list[str], name: str | None, log: Path | None, root: Path = PROJECT_ROOT) -> dict:
    """Start `argv` detached and write its marker; returns the marker."""
    argv = [resolve_executable(argv[0])] + list(argv[1:]) if argv else argv
    directory = root / MARKER_DIRECTORY
    directory.mkdir(parents=True, exist_ok=True)
    started_at = utc_now()
    stamp = make_stamp(started_at, name, directory)
    log_path = Path(log).resolve() if log else directory / (stamp + ".log")
    log_path.parent.mkdir(parents=True, exist_ok=True)
    command_line = build_command_line(argv, log_path)
    pid = wmi_create(command_line, root)
    marker = build_marker(stamp, name, argv, command_line, log_path, pid, started_at, root)
    marker_path = directory / (stamp + ".json")
    marker_path.write_text(json.dumps(marker, indent=2, ensure_ascii=False) + "\n", encoding="utf-8", newline="\n")
    return marker


def parse_process_table(text: str) -> list[dict]:
    text = text.strip()
    if not text:
        return []
    rows = json.loads(text)
    if isinstance(rows, dict):
        rows = [rows]
    return [row for row in rows if isinstance(row, dict) and isinstance(row.get("ProcessId"), int)]


def process_table() -> list[dict]:
    return parse_process_table(run_powershell(PROCESS_TABLE_SCRIPT))


def parse_timestamp(text: str | None) -> datetime.datetime | None:
    if not text:
        return None
    try:
        parsed = datetime.datetime.fromisoformat(text.replace("Z", "+00:00"))
    except ValueError:
        return None
    return parsed if parsed.tzinfo else parsed.replace(tzinfo=datetime.timezone.utc)


def marker_is_running(marker: dict, table: list[dict]) -> bool:
    """The marker's process exists and was created when the marker says (a
    reused pid has another creation time)."""
    started = parse_timestamp(marker.get("started_at"))
    for row in table:
        if row["ProcessId"] != marker.get("pid"):
            continue
        created = parse_timestamp(row.get("CreationDate"))
        if started is None or created is None:
            return True
        return abs((created - started).total_seconds()) <= PID_REUSE_TOLERANCE_SECONDS
    return False


def log_edges(path: Path) -> tuple[str, str]:
    """The log's first and last non-empty line (empty strings when absent)."""
    try:
        raw = path.read_bytes()
    except OSError:
        return "", ""
    try:
        text = raw.decode("utf-8")
    except UnicodeDecodeError:
        # A child writes the console's ANSI code page, not UTF-8, unless it was told to.
        text = raw.decode("mbcs" if os.name == "nt" else "utf-8", errors="replace")
    lines = [line.strip() for line in text.splitlines() if line.strip()]
    return (lines[0], lines[-1]) if lines else ("", "")


def possible_orphans(table: list[dict], root: Path) -> list[dict]:
    """`*_console.exe` and Python processes that mention the project and whose
    parent is gone - a hint, never a verdict."""
    alive = {row["ProcessId"] for row in table}
    root_text = str(root.resolve()).lower()
    found = []
    for row in table:
        name = str(row.get("Name") or "").lower()
        if not (name.endswith("_console.exe") or name in ("python.exe", "pythonw.exe")):
            continue
        if row.get("ParentProcessId") in alive:
            continue
        command = str(row.get("CommandLine") or "").lower()
        if root_text in command or "tools\\" in command or "tools/" in command:
            found.append(row)
    return found


def load_markers(root: Path) -> list[dict]:
    markers = []
    directory = root / MARKER_DIRECTORY
    for path in sorted(directory.glob("*.json")) if directory.is_dir() else []:
        try:
            marker = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            continue
        if isinstance(marker, dict) and marker.get("schema") == MARKER_SCHEMA:
            markers.append(marker)
    return markers


def format_status(markers: list[dict], table: list[dict], root: Path, show_all: bool) -> list[str]:
    lines = []
    shown = 0
    for marker in markers:
        running = marker_is_running(marker, table)
        if not running and not show_all:
            continue
        shown += 1
        first, last = log_edges(root / marker.get("log", ""))
        lines.append("%s  pid=%s  %s  started=%s" % (
            marker.get("stamp"), marker.get("pid"), "RUNNING" if running else "finished", marker.get("started_at")))
        lines.append("    command: %s" % " ".join(str(word) for word in marker.get("command", [])))
        lines.append("    log:     %s" % marker.get("log"))
        lines.append("    first:   %s" % first[:200])
        lines.append("    last:    %s" % last[:200])
    if not shown:
        lines.append("no running detached runs (--all lists finished ones too)")
    orphans = possible_orphans(table, root)
    if orphans:
        lines.append("possible orphans (parent gone; stop with Stop-Process -Id <pid>):")
        for row in orphans:
            lines.append("    pid=%s %s created=%s %s" % (
                row["ProcessId"], row.get("Name"), row.get("CreationDate"), str(row.get("CommandLine"))[:160]))
    return lines


def main(argv: list[str] | None = None) -> int:
    for stream in (sys.stdout, sys.stderr):
        try:
            stream.reconfigure(encoding="utf-8", errors="replace")  # a localized user profile in the paths
        except (AttributeError, ValueError):
            pass
    arguments = sys.argv[1:] if argv is None else argv
    command: list[str] = []
    if "--" in arguments:
        split = arguments.index("--")
        arguments, command = arguments[:split], arguments[split + 1:]
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--name", help="a short label added to the stamp")
    parser.add_argument("--log", type=Path, help="log path (default: <stamp>.log beside the marker)")
    parser.add_argument("--status", action="store_true", help="list detached runs instead of starting one")
    parser.add_argument("--all", action="store_true", help="with --status, include runs that have finished")
    parsed = parser.parse_args(arguments)
    try:
        if parsed.status:
            for line in format_status(load_markers(PROJECT_ROOT), process_table(), PROJECT_ROOT, parsed.all):
                print(line)
            return 0
        if not command:
            parser.error("give the command after --, or use --status")
        marker = launch(command, parsed.name, parsed.log)
    except (LaunchError, OSError, subprocess.SubprocessError) as exc:
        print("LAUNCH_DETACHED_ERROR: %s" % exc, file=sys.stderr)
        return 2
    print(json.dumps(marker, indent=2, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
