"""The cache of green validation results (TD-32 part 3b).

A green (`status == "passed"`, `return_code == 0`) check result, keyed by
`validation_inputs.fingerprint()`'s digest, stored under
`analysis/validation_cache/` (the gitignored `analysis/` tree; created on
first write) so a later run with `--cached` can skip re-running a check
whose inputs have not changed since it last passed. A red result (`failed`,
`timeout`, `error`) is never written and never read back as green - this
module enforces that, not just its caller.

One entry file per fingerprint: `<fingerprint[:2]>/<fingerprint>.json`, kept
two levels deep so no directory ever holds more entries than there are
distinct first-two-hex-character prefixes (256 at most). A malformed entry
file is ignored on `lookup()` (treated as a miss, not an error) and silently
overwritten on `store()`.
"""

from __future__ import annotations

import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

CACHE_ENTRY_SCHEMA = "kakyu_validation_cache_entry/v1"
_ENTRY_FIELDS = frozenset({
    "schema", "name", "fingerprint", "status", "duration_seconds", "recorded_at", "run_id", "core_version",
})


def _entry_path(directory: Path, fingerprint: str) -> Path:
    return Path(directory) / fingerprint[:2] / f"{fingerprint}.json"


def _is_well_formed(entry: Any) -> bool:
    return (
        isinstance(entry, dict)
        and set(entry) == _ENTRY_FIELDS
        and entry.get("schema") == CACHE_ENTRY_SCHEMA
        and isinstance(entry.get("name"), str) and entry["name"]
        and isinstance(entry.get("fingerprint"), str) and entry["fingerprint"]
        and entry.get("status") == "passed"
        and type(entry.get("duration_seconds")) in (int, float)
        and isinstance(entry.get("recorded_at"), str) and entry["recorded_at"]
        and isinstance(entry.get("run_id"), str) and entry["run_id"]
        and isinstance(entry.get("core_version"), str) and entry["core_version"]
    )


def lookup(directory: Path, name: str, fingerprint: str) -> dict | None:
    """The cached green entry for `name`/`fingerprint`, or `None` on a miss:
    no entry file, a malformed one (ignored, not an error), or one whose own
    `name` disagrees with `name` (a fingerprint already covers the command,
    so this cannot happen for distinct checks in practice - the guard is
    kept anyway).
    """
    path = _entry_path(directory, fingerprint)
    try:
        raw = path.read_text(encoding="utf-8")
    except OSError:
        return None
    try:
        entry = json.loads(raw)
    except json.JSONDecodeError:
        return None
    if not _is_well_formed(entry):
        return None
    if entry["fingerprint"] != fingerprint or entry["name"] != name:
        return None
    return entry


def store(
    directory: Path, name: str, fingerprint: str, result: dict[str, Any], run_id: str, core_version: str,
) -> None:
    """Write `result` as a green cache entry for `name`/`fingerprint`, unless
    `result` is not a passed, zero-exit result - `failed`/`timeout`/`error`
    are never written, silently (the caller may call this unconditionally
    after every executed check). An existing entry for the same fingerprint
    is overwritten.
    """
    if result.get("status") != "passed" or result.get("return_code") != 0:
        return
    entry = {
        "schema": CACHE_ENTRY_SCHEMA,
        "name": name,
        "fingerprint": fingerprint,
        "status": "passed",
        "duration_seconds": result.get("duration_seconds", 0.0),
        "recorded_at": datetime.now(timezone.utc).isoformat(),
        "run_id": run_id,
        "core_version": core_version,
    }
    path = _entry_path(directory, fingerprint)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(entry, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def clear(directory: Path) -> None:
    """Delete the entire cache directory (`--cache-clear`), if it exists."""
    directory = Path(directory)
    if not directory.is_dir():
        return
    for path in sorted(directory.rglob("*"), key=lambda p: len(p.parts), reverse=True):
        if path.is_file():
            path.unlink(missing_ok=True)
        elif path.is_dir():
            path.rmdir()
    directory.rmdir()
