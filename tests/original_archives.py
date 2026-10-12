"""Read the user's own original MES and data archives for the archive-literal guard.

WD-25 item 1b: no tracked file holds an 8-byte window (4 Japanese characters) of an
original `mes.arc` or `data.arc` entry that fewer than 100 entries share. The guard
(`test_no_original_archive_bytes.py`) can only check that against the user's own
archives, which it reads at run time and never copies.

This is not a `test_*` module, so test discovery skips it. Its module level uses only the
standard library; `extract_kakyu_arc` is imported lazily inside `entries()`. The two
archives are named by environment variables alone, and both are required: there is
deliberately no fallback to `.agents/local/source_paths.md`, because the validation cache
fingerprints the archives only when the batch passes them (`--mes-arc` and `--data-arc` of
`tools/content_suite/run_python_regression.py`, forwarded as these variables).
"""

from __future__ import annotations

import os
import sys
import unittest
from pathlib import Path

MES_VARIABLE = "KAKYU_MES_ARC"
DATA_VARIABLE = "KAKYU_DATA_ARC"
SKIP_REASON = (
    f"{MES_VARIABLE} and {DATA_VARIABLE} are not set; the guard reads the user's own archives"
)

_TOOLS = Path(__file__).resolve().parents[1] / "tools"
_ENTRIES: dict[tuple[str, str], list[bytes]] = {}


class OriginalArchivesError(RuntimeError):
    """A variable is set but names something that is not a readable archive."""


def environment_paths() -> tuple[Path, Path] | None:
    """The two archives named by the environment, or None unless both are set and non-empty."""
    mes = os.environ.get(MES_VARIABLE, "")
    data = os.environ.get(DATA_VARIABLE, "")
    if not mes.strip() or not data.strip():
        return None
    return Path(mes), Path(data)


def read_archive_entries(path: Path) -> list[bytes]:
    """Every entry payload of one archive, in stored form, in archive order."""
    if str(_TOOLS) not in sys.path:
        sys.path.insert(0, str(_TOOLS))
    from extract_kakyu_arc import read_entries  # noqa: PLC0415 - lazy: the module level stays standard-library only

    try:
        with path.open("rb") as stream:
            payloads = []
            for _name, offset, size in read_entries(path):
                stream.seek(offset)
                payload = stream.read(size)
                if len(payload) != size:
                    raise OriginalArchivesError(f"an entry of {path.name} is truncated")
                payloads.append(payload)
            return payloads
    except OSError as error:
        raise OriginalArchivesError(f"{path.name} is not a readable archive: {error.strerror}") from error
    except ValueError as error:
        raise OriginalArchivesError(f"{path.name} is not a well-formed archive") from error


def entries() -> list[bytes]:
    """Every entry of `mes.arc`, then of `data.arc`, read once per process."""
    paths = environment_paths()
    if paths is None:
        raise OriginalArchivesError(SKIP_REASON)
    key = (str(paths[0]), str(paths[1]))
    if key not in _ENTRIES:
        _ENTRIES[key] = read_archive_entries(paths[0]) + read_archive_entries(paths[1])
    return _ENTRIES[key]


requires_original_archives = unittest.skipUnless(environment_paths() is not None, SKIP_REASON)
