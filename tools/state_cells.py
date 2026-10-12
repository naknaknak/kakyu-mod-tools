"""The tracked cell-class table (`kakyu_state_cells/v1`), event definition
v4 unit 2a.

    from tools.state_cells import load, classify, heroine

`config/contracts/state_cells_v1/state_cells.json` names every cell a v4
effect row or guard conjunct may refer to by class, the way
`docs/spec/data/event_definition_v4_design.md` fixes them (see its section
"The affection cells, fixed on 2026-09-18" for the affection rows and
`docs/spec/data/event_definition_projection.md`'s guard conjunct vocabulary
for the others). A cell not named in the table falls back to one of the
storage-wide rules the table also carries. This module does not re-derive
either table: it only reads and applies it.
"""
from __future__ import annotations

import json
from pathlib import Path
from typing import Any, Iterable

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_TABLE_PATH = ROOT / "config" / "contracts" / "state_cells_v1" / "state_cells.json"

_CACHE: dict[Path, dict] = {}


def load(path: Path | None = None) -> dict:
    """Load and cache the table at `path` (default
    `config/contracts/state_cells_v1/state_cells.json`). Returns the parsed
    JSON document: `{"schema", "classes", "cells", "rules"}`."""
    table_path = Path(path) if path is not None else DEFAULT_TABLE_PATH
    cached = _CACHE.get(table_path)
    if cached is None:
        cached = json.loads(table_path.read_text(encoding="utf-8"))
        _CACHE[table_path] = cached
    return cached


def _cell_key(storage: Any, bank: Any, index: Any) -> tuple:
    return (storage, bank, index)


def _table_lookup(table: dict, storage: Any, bank: Any, index: Any) -> dict | None:
    key = _cell_key(storage, bank, index)
    for row in table.get("cells", []):
        if _cell_key(row.get("storage"), row.get("bank"), row.get("index")) == key:
            return row
    return None


def classify(
    storage: Any,
    bank: Any,
    index: Any,
    observed_values: Iterable[int] | None = None,
    *,
    table: dict | None = None,
) -> str | None:
    """The cell class of `(storage, bank, index)`: the table's row when one
    names the cell, else the storage-wide rule. `global_u8` needs
    `observed_values` (every value the cell is known to hold in the
    document being checked) to decide `flag` (observed only as 0 to 1) from
    `counter` (otherwise, including when no observation is given). Returns
    `None` for a storage the table names no rule for."""
    table = table if table is not None else load()
    row = _table_lookup(table, storage, bank, index)
    if row is not None:
        return row["cell_class"]
    if storage == "global_u8":
        values = list(observed_values) if observed_values is not None else []
        if values and all(v in (0, 1) for v in values):
            return "flag"
        return "counter"
    if storage in ("state_u16", "banked_u16", "banked_u8", "global_i32"):
        return "unnamed"
    return None


def heroine(storage: Any, bank: Any, index: Any, *, table: dict | None = None) -> str | None:
    """The heroine name of an affection cell, or `None` when the cell is not
    one (including `banked_u16[213]`, which the table keeps `unnamed`)."""
    table = table if table is not None else load()
    row = _table_lookup(table, storage, bank, index)
    if row is not None and row.get("cell_class") == "affection":
        return row.get("heroine")
    return None
