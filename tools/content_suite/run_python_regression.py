"""Run the repository's independent Python unittest cases in bounded shards."""

from __future__ import annotations

import argparse
import os
import subprocess
import sys
import time
import unittest
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable, Sequence


DEFAULT_TIMEOUT_SECONDS = 3600
DEFAULT_MAX_JOBS = 4
HEAVY_TEST_MODULES = ("test_audit_ai5_mes_exe.",)
# WD-25 item 1: the native-audit tests rebuild their fixtures from the user's own
# executable, which they find through this variable (and only this variable).
ORIGINAL_EXECUTABLE_VARIABLE = "KAKYU_ORIGINAL_EXE"
# WD-25 item 1b: the archive-literal guard reads the user's own `mes.arc` and `data.arc`,
# which it finds through these two variables (and only these; both are required).
ORIGINAL_MES_ARC_VARIABLE = "KAKYU_MES_ARC"
ORIGINAL_DATA_ARC_VARIABLE = "KAKYU_DATA_ARC"

# Windows caps one process command line at 32,767 characters and refuses a
# longer one with WinError 206 at launch, before any Python in the child runs.
# A shard is therefore two separate things: the unit of parallelism, which the
# balancing policy sizes, and the unit a single process can be started with,
# which the operating system sizes. The budget keeps a margin for the
# interpreter path and the fixed arguments.
MAX_COMMAND_LINE_CHARS = 24000


@dataclass(frozen=True)
class BatchResult:
    return_code: int | None
    status: str
    output: str


@dataclass(frozen=True)
class ShardResult:
    index: int
    test_count: int
    batch_count: int
    return_code: int | None
    status: str
    duration_seconds: float
    output: str


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Run discovered Python unittest cases in parallel subprocess shards."
    )
    parser.add_argument(
        "--jobs",
        type=int,
        default=min(DEFAULT_MAX_JOBS, os.cpu_count() or 1),
        help=f"Maximum parallel shards (default: at most {DEFAULT_MAX_JOBS}).",
    )
    parser.add_argument(
        "--timeout",
        type=int,
        default=DEFAULT_TIMEOUT_SECONDS,
        help="Per-shard timeout in seconds.",
    )
    parser.add_argument(
        "--exe",
        type=Path,
        default=None,
        help=(
            "The user's original executable. It is handed to every shard as "
            f"{ORIGINAL_EXECUTABLE_VARIABLE}; without it any inherited value is "
            "removed and the native-audit tests skip."
        ),
    )
    parser.add_argument(
        "--mes-arc",
        type=Path,
        default=None,
        help=(
            "The user's original mes.arc. It is handed to every shard as "
            f"{ORIGINAL_MES_ARC_VARIABLE} and must be given with --data-arc; without the "
            "pair any inherited value is removed and the archive-literal guard skips."
        ),
    )
    parser.add_argument(
        "--data-arc",
        type=Path,
        default=None,
        help=(
            "The user's original data.arc. It is handed to every shard as "
            f"{ORIGINAL_DATA_ARC_VARIABLE} and must be given with --mes-arc."
        ),
    )
    return parser.parse_args()


def _flatten_suite(suite: unittest.TestSuite) -> list[str]:
    test_ids: list[str] = []
    pending: list[unittest.TestSuite | unittest.TestCase] = list(suite)
    while pending:
        item = pending.pop()
        if isinstance(item, unittest.TestSuite):
            pending.extend(item)
        else:
            test_ids.append(item.id())
    return test_ids


def discover_test_ids(test_root: Path) -> list[str]:
    suite = unittest.defaultTestLoader.discover(
        str(test_root),
        pattern="test_*.py",
    )
    return sorted(_flatten_suite(suite))


def _test_weight(test_id: str) -> int:
    return 100 if test_id.startswith(HEAVY_TEST_MODULES) else 1


def balanced_shards(test_ids: Iterable[str], jobs: int) -> list[list[str]]:
    if jobs <= 0:
        raise ValueError(
            "Parallel Python regression jobs must be greater than zero."
        )
    weighted = sorted(test_ids, key=lambda value: (-_test_weight(value), value))
    if not weighted:
        return []
    shard_count = min(jobs, len(weighted))
    shards: list[list[str]] = [[] for _ in range(shard_count)]
    loads = [0] * shard_count
    for test_id in weighted:
        target = min(range(shard_count), key=lambda index: (loads[index], index))
        shards[target].append(test_id)
        loads[target] += _test_weight(test_id)
    return shards


def command_length(prefix: Sequence[str], test_ids: Sequence[str]) -> int:
    """Length of the command line the operating system would actually receive."""
    return len(subprocess.list2cmdline([*prefix, *test_ids]))


def command_batches(
    test_ids: Sequence[str],
    prefix: Sequence[str],
    limit: int = MAX_COMMAND_LINE_CHARS,
) -> list[list[str]]:
    """Split one shard into runs whose command line fits within `limit`.

    Every test appears exactly once and order is preserved. A single test whose
    own command line exceeds the limit is still emitted, alone, so that it fails
    with a named launch diagnostic instead of disappearing from the run.
    """
    if limit <= 0:
        raise ValueError("The command-line budget must be greater than zero.")
    batches: list[list[str]] = []
    current: list[str] = []
    for test_id in test_ids:
        if current and command_length(prefix, [*current, test_id]) > limit:
            batches.append(current)
            current = [test_id]
        else:
            current.append(test_id)
    if current:
        batches.append(current)
    return batches


def _run_batch(
    prefix: Sequence[str],
    test_ids: Sequence[str],
    project: Path,
    environment: dict[str, str],
    timeout: float,
) -> BatchResult:
    try:
        process = subprocess.run(
            (*prefix, *test_ids),
            cwd=project,
            env=environment,
            text=True,
            encoding="utf-8",
            errors="replace",
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            timeout=timeout,
            check=False,
        )
    except subprocess.TimeoutExpired as error:
        return BatchResult(
            return_code=None,
            status="timeout",
            output=error.stdout if isinstance(error.stdout, str) else "",
        )
    except OSError as error:
        # A launch failure is not a test failure, and it must not escape as an
        # unhandled traceback out of the worker thread.
        return BatchResult(
            return_code=None,
            status="launch_failed",
            output=(
                "PYTHON_REGRESSION_LAUNCH_ERROR: could not start a process for "
                f"{len(test_ids)} tests with a "
                f"{command_length(prefix, test_ids)}-character command line "
                f"(budget {MAX_COMMAND_LINE_CHARS}): {error}"
            ),
        )
    return BatchResult(
        return_code=process.returncode,
        status="passed" if process.returncode == 0 else "failed",
        output=process.stdout or "",
    )


def _run_shard(
    index: int,
    test_ids: list[str],
    project: Path,
    test_root: Path,
    timeout: int,
    original_executable: Path | None = None,
    original_archives: tuple[Path, Path] | None = None,
) -> ShardResult:
    environment = os.environ.copy()
    environment["PYTHONIOENCODING"] = "utf-8"
    # The executable is an input of the run: a shard sees it only when the
    # caller named it, never through an inherited variable the result cache
    # cannot see.
    environment.pop(ORIGINAL_EXECUTABLE_VARIABLE, None)
    if original_executable is not None:
        environment[ORIGINAL_EXECUTABLE_VARIABLE] = str(original_executable)
    # The archives are inputs of the run in the same way: a shard sees them only as a pair
    # the caller named, never through inherited variables the result cache cannot see.
    environment.pop(ORIGINAL_MES_ARC_VARIABLE, None)
    environment.pop(ORIGINAL_DATA_ARC_VARIABLE, None)
    if original_archives is not None:
        environment[ORIGINAL_MES_ARC_VARIABLE] = str(original_archives[0])
        environment[ORIGINAL_DATA_ARC_VARIABLE] = str(original_archives[1])
    python_path = environment.get("PYTHONPATH", "")
    environment["PYTHONPATH"] = os.pathsep.join(
        value for value in (str(test_root), python_path) if value
    )
    prefix = (sys.executable, "-m", "unittest")
    batches = command_batches(test_ids, prefix)
    started = time.monotonic()
    deadline = started + timeout
    outputs: list[str] = []
    return_code: int | None = 0
    status = "passed"
    for batch in batches:
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            status = "timeout"
            return_code = None
            break
        result = _run_batch(prefix, batch, project, environment, remaining)
        if result.output:
            outputs.append(result.output.rstrip())
        if result.status != "passed" and status == "passed":
            # The shard reports its first non-passing batch; the remaining
            # batches still run so one failure does not hide the others.
            status = result.status
            return_code = result.return_code
    return ShardResult(
        index=index,
        test_count=len(test_ids),
        batch_count=len(batches),
        return_code=return_code,
        status=status,
        duration_seconds=round(time.monotonic() - started, 3),
        output="\n".join(outputs),
    )


def main() -> int:
    arguments = parse_args()
    if arguments.jobs <= 0:
        print("PYTHON_REGRESSION_CONFIGURATION_ERROR: jobs must be greater than zero.")
        return 2
    if arguments.timeout <= 0:
        print("PYTHON_REGRESSION_CONFIGURATION_ERROR: timeout must be greater than zero.")
        return 2
    original_executable: Path | None = None
    if arguments.exe is not None:
        original_executable = arguments.exe.expanduser().resolve()
        if not original_executable.is_file():
            print("PYTHON_REGRESSION_CONFIGURATION_ERROR: --exe is not an existing file.")
            return 2
    original_archives: tuple[Path, Path] | None = None
    if (arguments.mes_arc is None) != (arguments.data_arc is None):
        print("PYTHON_REGRESSION_CONFIGURATION_ERROR: --mes-arc and --data-arc are given together or not at all.")
        return 2
    if arguments.mes_arc is not None and arguments.data_arc is not None:
        original_archives = (
            arguments.mes_arc.expanduser().resolve(),
            arguments.data_arc.expanduser().resolve(),
        )
        if not all(path.is_file() for path in original_archives):
            print("PYTHON_REGRESSION_CONFIGURATION_ERROR: --mes-arc and --data-arc must each name an existing file.")
            return 2

    project = Path(__file__).resolve().parents[2]
    test_root = project / "tests"
    test_ids = discover_test_ids(test_root)
    if not test_ids:
        print("PYTHON_REGRESSION_CONFIGURATION_ERROR: no tests were discovered.")
        return 2
    shards = balanced_shards(test_ids, arguments.jobs)
    started = time.monotonic()
    with ThreadPoolExecutor(max_workers=len(shards) or 1) as executor:
        futures = [
            executor.submit(
                _run_shard,
                index,
                shard,
                project,
                test_root,
                arguments.timeout,
                original_executable,
                original_archives,
            )
            for index, shard in enumerate(shards)
        ]
        results = sorted(
            (future.result() for future in futures),
            key=lambda item: item.index,
        )

    for result in results:
        batches = "" if result.batch_count <= 1 else f", {result.batch_count} batches"
        print(
            f"\n=== Python shard {result.index + 1}/{len(results)} "
            f"({result.test_count} tests{batches}) ==="
        )
        if result.output:
            print(result.output.rstrip())
        print(f"--- {result.status.upper()} ({result.duration_seconds:.3f}s) ---")

    elapsed = round(time.monotonic() - started, 3)
    failures = [result for result in results if result.status != "passed"]
    print(
        f"\nPython regression: {'PASSED' if not failures else 'FAILED'}; "
        f"{len(test_ids)} tests, {len(shards)} shards, {elapsed:.3f}s"
    )
    return 0 if not failures else 1


if __name__ == "__main__":
    raise SystemExit(main())
