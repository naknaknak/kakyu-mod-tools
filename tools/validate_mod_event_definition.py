"""Local validator for a `kakyu_mod_event_definition/v1` document (mod event
definition unit A: the definitions a mod writes itself - a `new_event` or an
`override` of a projected `kakyu_event_definition/v4` document).

    py tools/validate_mod_event_definition.py <document.json> [--names <registry dir>]
        [--definitions-dir <tracked v4 directory>] [--fingerprint <fp>]
        [--cells-fingerprint <fp>] [--allow-unrecorded]

Prints one JSON line ``{"ok": bool, "reason": code, "detail": str}`` and
exits 0 when ``ok`` is true, 1 otherwise - the same convention
``tools/validate_event_definition.py`` uses. See
``docs/spec/data/mod_event_definition_design.md`` for the design and
``docs/spec/data/mod_event_definition.md`` for the exact document shape and
the check order this module follows (the order is fixed so that the first
offending field always produces the same reason).

A document's own ``contract_fingerprint`` and ``cells_fingerprint`` may each
be the literal string ``"self"`` (the fixture convention, as in v3/v4) or
``"unrecorded"`` (accepted only with ``--allow-unrecorded``, again as in
v3/v4). Without ``--fingerprint``, the expected contract fingerprint is read
from ``config/contracts/mod_event_definition_v1/contract_fingerprint``;
without ``--cells-fingerprint``, from
``config/contracts/state_cells_v1/cells_fingerprint``.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sys
from pathlib import Path
from typing import Any, Callable

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import state_cells  # noqa: E402
from text_rules import check_text  # noqa: E402
from validate_event_definition import (  # noqa: E402
    CELL_COMPARISON_OP,
    ID_RE,
    Fail,
    _check_choice_points_v4,
    _collect_choice_targets_v4,
    _count_scene_ends_v4,
    _check_flow_v4,
    fail,
    _is_int,
    load_names_registry,
)

ROOT = Path(__file__).resolve().parents[1]

SCHEMA_VERSION = "kakyu_mod_event_definition/v1"

MOD_ID_RE = re.compile(r"^[a-z][a-z0-9_]{1,31}$")
NAME_SEGMENT_RE = re.compile(r"^[a-z][a-z0-9_]{0,63}$")
DOC_ID_RE = re.compile(r"^mod\.([a-z][a-z0-9_]{1,31})\.([a-z][a-z0-9_]{0,63})$")
FLAG_RE = re.compile(r"^mod\.[a-z][a-z0-9_]{1,31}\.[a-z][a-z0-9_]{0,63}$")
PLACE_RE = re.compile(r"^[a-z0-9_]+$")
RESULT_ID_RE = re.compile(r"^[a-z][a-z0-9_]{0,63}$")
DOCUMENT_SHA256_RE = re.compile(r"^[0-9a-f]{64}$")
VOICE_RE = re.compile(r"^[A-Za-z0-9_.-]+$")

CATEGORY_VALUES = {"school", "town", "date", "special"}
KIND_VALUES = {"new_event", "override"}
TERMINAL_KIND_VALUES = {"return_to_map", "continue_caller"}
SELECTED_BY_KINDS = {"choice", "condition", "default"}
CONDITION_TYPES = {
    "always",
    "event_not_completed",
    "event_completed",
    "flag_equals",
    "weekday_equals",
    "date_equals",
    "date_in_range",
    "time_at_or_after",
    "time_before",
    "legacy_cell",
    "mes_expression",
}
EFFECT_TYPES = {"write_legacy_value", "add_legacy_value", "consume_time", "set_flag"}
CLOCK_CELLS = {("state_u16", 0), ("state_u16", 1), ("state_u16", 19)}
DONE_CELL_CLASSES = {"flag", "counter", "unnamed"}
OP_TYPES = {
    "replace_conditions",
    "replace_after",
    "replace_result",
    "append_result",
    "replace_order_hint",
    "disable",
}

HEADER_KEYS = {"schema_version", "contract_fingerprint", "cells_fingerprint", "kind", "mod", "id", "display"}
NEW_EVENT_KEYS = {"trigger", "conditions", "presentation", "dialogue", "after", "choice", "results", "terminals", "done"}
OVERRIDE_KEYS = {"target", "operations"}
REQUIRED_HEADER = {"schema_version", "contract_fingerprint", "cells_fingerprint", "kind", "mod", "id"}
REQUIRED_NEW_EVENT = {"trigger", "conditions", "dialogue", "after", "results", "terminals"}
REQUIRED_OVERRIDE = {"target", "operations"}

PRESENTATION_STRING_KEYS = ("background", "bgm", "hud", "message_window")


# ---------------------------------------------------------------------------
# Small helpers
# ---------------------------------------------------------------------------


def _heroines(table: dict) -> set:
    return {row.get("heroine") for row in table.get("cells", []) if row.get("heroine")}


def _is_valid_date_code(value: Any) -> bool:
    if not _is_int(value) or value < 101:
        return False
    month, day = value // 100, value % 100
    return 1 <= month <= 12 and 1 <= day <= 31


def _is_valid_time_code(value: Any) -> bool:
    if not _is_int(value):
        return False
    hour, minute = value // 100, value % 100
    return 0 <= hour <= 23 and 0 <= minute <= 59


def _check_extra_keys(obj: dict, allowed: set, reason: str, where: str) -> None:
    extra = set(obj) - allowed
    if extra:
        fail(reason, f"{where}: unexpected keys {sorted(extra)}")


def document_sha256(path: Path | str) -> str:
    """SHA-256 hex digest of the file at `path` with every CRLF normalized
    to LF, used by the `override` target check and by tests."""
    data = Path(path).read_bytes().replace(b"\r\n", b"\n")
    return hashlib.sha256(data).hexdigest()


# ---------------------------------------------------------------------------
# A.4 conditions
# ---------------------------------------------------------------------------


def _check_condition_row(row: Any, where: str, *, mod_id: str, state_cells_table: dict) -> None:
    if not isinstance(row, dict):
        fail("conditions", f"{where}: not an object")
    ctype = row.get("type")
    if ctype not in CONDITION_TYPES:
        fail("conditions", f"{where}: unknown type {ctype!r}")
    allowed = {"type", "failure_reason"}
    if "failure_reason" in row and not isinstance(row.get("failure_reason"), str):
        fail("conditions", f"{where}: failure_reason is not a string")

    if ctype == "always":
        pass
    elif ctype in ("event_not_completed", "event_completed"):
        allowed |= {"event_id"}
        if ctype == "event_completed" and "event_id" not in row:
            fail("conditions", f"{where}: event_completed requires event_id")
        if "event_id" in row:
            event_id = row.get("event_id")
            if not isinstance(event_id, str) or not (DOC_ID_RE.match(event_id) or ID_RE.match(event_id)):
                fail("conditions", f"{where}: event_id {event_id!r} is not a mod id or a registry id")
    elif ctype == "flag_equals":
        allowed |= {"name", "value"}
        name = row.get("name")
        if not isinstance(name, str) or not FLAG_RE.match(name):
            fail("flag_name", f"{where}: name {name!r} is not a mod flag name")
        if not isinstance(row.get("value"), bool):
            fail("conditions", f"{where}: value is not a bool")
    elif ctype == "weekday_equals":
        allowed |= {"weekday"}
        weekday = row.get("weekday")
        if not (_is_int(weekday) and 0 <= weekday <= 6):
            fail("conditions", f"{where}: weekday must be an integer 0..6")
    elif ctype == "date_equals":
        allowed |= {"date_code"}
        if not _is_valid_date_code(row.get("date_code")):
            fail("conditions", f"{where}: date_code must be a valid MMDD integer")
    elif ctype == "date_in_range":
        allowed |= {"from_date_code", "to_date_code"}
        from_code, to_code = row.get("from_date_code"), row.get("to_date_code")
        if not (_is_valid_date_code(from_code) and _is_valid_date_code(to_code)):
            fail("conditions", f"{where}: from_date_code/to_date_code must be valid MMDD integers")
        if from_code > to_code:
            fail("conditions", f"{where}: from_date_code must be <= to_date_code")
    elif ctype in ("time_at_or_after", "time_before"):
        allowed |= {"time_code"}
        if not _is_valid_time_code(row.get("time_code")):
            fail("conditions", f"{where}: time_code must be a valid HHMM integer")
    elif ctype == "legacy_cell":
        allowed |= {"storage", "bank", "index", "operator", "value", "cell_class"}
        if not isinstance(row.get("storage"), str):
            fail("conditions", f"{where}: storage missing or not a string")
        for key in ("bank", "index", "value"):
            if not _is_int(row.get(key)):
                fail("conditions", f"{where}: {key} missing or not an integer")
        if row.get("operator") not in CELL_COMPARISON_OP:
            fail("conditions", f"{where}: operator {row.get('operator')!r} not in the vocabulary")
        expected_class = state_cells.classify(row.get("storage"), row.get("bank"), row.get("index"), table=state_cells_table)
        if row.get("cell_class") != expected_class:
            fail("bad_cell_class", f"{where}: cell_class {row.get('cell_class')!r} != {expected_class!r}")
    elif ctype == "mes_expression":
        allowed |= {"ast"}
        if not isinstance(row.get("ast"), dict) or not row.get("ast"):
            fail("conditions", f"{where}: ast missing or empty")

    _check_extra_keys(row, allowed, "conditions", where)


def _check_condition_rows(rows: Any, where: str, *, mod_id: str, state_cells_table: dict) -> None:
    if not isinstance(rows, list):
        fail("conditions", f"{where}: not a list")
    for i, row in enumerate(rows):
        _check_condition_row(row, f"{where}[{i}]", mod_id=mod_id, state_cells_table=state_cells_table)


# ---------------------------------------------------------------------------
# A.5 dialogue
# ---------------------------------------------------------------------------


def _check_dialogue_entries(entries: Any, where: str) -> None:
    if not isinstance(entries, list):
        fail("text", f"{where}: not a list")
    for i, entry in enumerate(entries):
        row_where = f"{where}[{i}]"
        if not isinstance(entry, dict):
            fail("text", f"{row_where}: not an object")
        kind = entry.get("kind")
        if kind == "line":
            _check_extra_keys(entry, {"kind", "text", "speaker", "voice"}, "text", row_where)
            text = entry.get("text")
            if not isinstance(text, str):
                fail("text", f"{row_where}.text: missing or not a string")
            if text == "":
                fail("text_empty", f"{row_where}.text: empty")
            result = check_text(text, allow_line_break=True, placeholder="name")
            if result is not None:
                reason, detail = result
                fail(reason, f"{row_where}.text: {detail}")
            if "speaker" in entry:
                speaker = entry.get("speaker")
                if not isinstance(speaker, str) or speaker == "":
                    fail("text", f"{row_where}.speaker: missing or not a non-empty string")
                result = check_text(speaker, allow_line_break=False, placeholder="name")
                if result is not None:
                    reason, detail = result
                    fail(reason, f"{row_where}.speaker: {detail}")
            if "voice" in entry:
                voice = entry.get("voice")
                if not isinstance(voice, str) or not VOICE_RE.match(voice):
                    fail("text", f"{row_where}.voice: does not match the pattern")
        elif kind == "choice_point":
            _check_extra_keys(entry, {"kind", "choice"}, "text", row_where)
            if "choice" not in entry:
                fail("text", f"{row_where}: choice_point missing choice")
        elif kind == "scene_end":
            _check_extra_keys(entry, {"kind"}, "text", row_where)
        else:
            fail("text", f"{row_where}: kind {kind!r} not in the vocabulary")


# ---------------------------------------------------------------------------
# A.6 effects
# ---------------------------------------------------------------------------


def _collect_observed_values(document: dict) -> dict[tuple, set]:
    """Every value a cell is known to hold anywhere in `document`: a
    `write_legacy_value` row's `value`, a `legacy_cell` condition row's
    `value`, and a `done.cell`'s `value` - used to tell `global_u8` `flag`
    from `counter` (`tools/state_cells.classify`)."""
    observed: dict[tuple, set] = {}

    def add(storage, bank, index, value):
        if not (_is_int(bank) and _is_int(index) and _is_int(value)):
            return
        observed.setdefault((storage, bank, index), set()).add(value)

    def walk(node):
        if isinstance(node, dict):
            if node.get("type") in ("write_legacy_value", "legacy_cell"):
                add(node.get("storage"), node.get("bank"), node.get("index"), node.get("value"))
            for value in node.values():
                walk(value)
        elif isinstance(node, list):
            for item in node:
                walk(item)

    walk(document)
    done = document.get("done")
    if isinstance(done, dict):
        cell = done.get("cell")
        if isinstance(cell, dict):
            add(cell.get("storage"), cell.get("bank"), cell.get("index"), cell.get("value"))
    return observed


def _check_effect_rows(rows: Any, where: str, *, mod_id: str, state_cells_table: dict, observed: dict) -> None:
    if not isinstance(rows, list):
        fail("effects", f"{where}: not a list")
    seen_cells: set = set()
    consume_time_seen = False
    for i, row in enumerate(rows):
        row_where = f"{where}[{i}]"
        if not isinstance(row, dict):
            fail("effects", f"{row_where}: not an object")
        etype = row.get("type")
        if etype not in EFFECT_TYPES:
            fail("effects", f"{row_where}: type {etype!r} not in {sorted(EFFECT_TYPES)}")

        if etype == "consume_time":
            if consume_time_seen:
                fail("effects", f"{row_where}: more than one consume_time row in one list")
            consume_time_seen = True
            _check_extra_keys(row, {"type", "minutes", "cell_class"}, "effects", row_where)
            minutes = row.get("minutes")
            if not (_is_int(minutes) and minutes > 0):
                fail("bad_consume_time", f"{row_where}: minutes must be a positive integer")
            if row.get("cell_class") != "clock":
                fail("bad_consume_time", f"{row_where}: cell_class must be 'clock'")
            continue

        if etype == "set_flag":
            _check_extra_keys(row, {"type", "name", "value"}, "effects", row_where)
            name = row.get("name")
            if not isinstance(name, str) or not FLAG_RE.match(name):
                fail("flag_name", f"{row_where}: name {name!r} is not a mod flag name")
            if not isinstance(row.get("value"), bool):
                fail("effects", f"{row_where}: value is not a bool")
            mod_segment = name.split(".")[1]
            if mod_segment != mod_id:
                fail("foreign_flag_write", f"{row_where}: flag {name!r} is not owned by mod {mod_id!r}")
            continue

        storage = row.get("storage")
        if not isinstance(storage, str):
            fail("effects", f"{row_where}: storage missing or not a string")
        for key in ("bank", "index"):
            if not _is_int(row.get(key)):
                fail("effects", f"{row_where}: {key} missing or not an integer")
        bank, index = row.get("bank"), row.get("index")

        if (storage, index) in CLOCK_CELLS:
            fail("clock_cell_effect", f"{row_where}: {storage}[{index}] is a clock cell and never carries a write/add row")

        key = (storage, bank, index)
        if key in seen_cells:
            fail("duplicate_effect_cell", f"{row_where}: {storage}[{index}] already has an effect row in this list")
        seen_cells.add(key)

        if etype == "write_legacy_value":
            _check_extra_keys(row, {"type", "storage", "bank", "index", "value", "cell_class"}, "effects", row_where)
            if not _is_int(row.get("value")):
                fail("effects", f"{row_where}: value missing or not an integer")
        else:  # add_legacy_value
            _check_extra_keys(row, {"type", "storage", "bank", "index", "delta", "cell_class", "min", "max"}, "effects", row_where)
            delta = row.get("delta")
            if not _is_int(delta):
                fail("effects", f"{row_where}: delta missing or not an integer")
            if delta == 0:
                fail("zero_delta", f"{row_where}: delta is zero")
            has_min, has_max = "min" in row, "max" in row
            if has_min and not _is_int(row.get("min")):
                fail("effects", f"{row_where}: min is not an integer")
            if has_max and not _is_int(row.get("max")):
                fail("effects", f"{row_where}: max is not an integer")
            if has_min and has_max and row.get("min") > row.get("max"):
                fail("bad_clamp", f"{row_where}: min must be <= max")

        expected_class = state_cells.classify(storage, bank, index, observed.get(key), table=state_cells_table)
        if row.get("cell_class") != expected_class:
            fail("bad_cell_class", f"{row_where}: cell_class {row.get('cell_class')!r} != {expected_class!r}")


# ---------------------------------------------------------------------------
# A.2 choice / results / terminals / done, new_event only
# ---------------------------------------------------------------------------


def _check_choice_block(choice: Any, results: dict, where: str) -> None:
    if not isinstance(choice, dict):
        fail("choice", f"{where}: not an object")
    _check_extra_keys(choice, {"prompt", "options"}, "choice", where)
    if "prompt" in choice:
        prompt = choice.get("prompt")
        if not isinstance(prompt, str):
            fail("choice", f"{where}.prompt: not a string")
        if prompt != "":
            result = check_text(prompt, allow_line_break=False, placeholder="name")
            if result is not None:
                reason, detail = result
                fail(reason, f"{where}.prompt: {detail}")
    options = choice.get("options")
    if not isinstance(options, list) or not options:
        fail("choice", f"{where}.options: missing or empty")
    seen_values: set = set()
    for i, option in enumerate(options):
        row_where = f"{where}.options[{i}]"
        if not isinstance(option, dict):
            fail("choice", f"{row_where}: not an object")
        _check_extra_keys(option, {"value", "label", "result"}, "choice", row_where)
        value = option.get("value")
        if not (_is_int(value) and value >= 0):
            fail("choice", f"{row_where}.value: must be an integer >= 0")
        if value in seen_values:
            fail("choice", f"{row_where}.value: {value!r} is not distinct")
        seen_values.add(value)
        label = option.get("label")
        if not isinstance(label, str) or label == "":
            fail("choice", f"{row_where}.label: missing or empty")
        result_check = check_text(label, allow_line_break=False, placeholder="name")
        if result_check is not None:
            reason, detail = result_check
            fail(reason, f"{row_where}.label: {detail}")
        result_id = option.get("result")
        if result_id not in results:
            fail("choice", f"{row_where}.result: {result_id!r} not in results")
        target_result = results.get(result_id)
        selected_by = target_result.get("selected_by") if isinstance(target_result, dict) else None
        if not (isinstance(selected_by, dict) and selected_by.get("kind") == "choice" and selected_by.get("value") == value):
            fail("choice", f"{row_where}: result {result_id!r}'s selected_by does not name choice value {value!r}")


def _check_results_map(results: Any, *, choice: dict | None, terminals: dict, where: str, mod_id: str, state_cells_table: dict, observed: dict) -> None:
    if not isinstance(results, dict) or not results:
        fail("results", f"{where}: missing or empty")
    valid_choice_values = None
    if choice is not None and isinstance(choice.get("options"), list):
        valid_choice_values = {opt.get("value") for opt in choice.get("options") if isinstance(opt, dict)}
    default_seen = False
    for result_id, result in results.items():
        row_where = f"{where}[{result_id}]"
        if not RESULT_ID_RE.match(result_id):
            fail("results", f"{row_where}: result id does not match the pattern")
        if not isinstance(result, dict):
            fail("results", f"{row_where}: not an object")
        _check_extra_keys(result, {"selected_by", "event_played", "dialogue", "after", "terminal", "choice", "results"}, "results", row_where)

        selected_by = result.get("selected_by")
        if not isinstance(selected_by, dict):
            fail("results", f"{row_where}.selected_by: missing or not an object")
        sb_kind = selected_by.get("kind")
        if sb_kind == "choice":
            _check_extra_keys(selected_by, {"kind", "value"}, "results", f"{row_where}.selected_by")
            if choice is None or valid_choice_values is None:
                fail("results", f"{row_where}.selected_by: kind is choice but there is no owning choice")
            if selected_by.get("value") not in valid_choice_values:
                fail("results", f"{row_where}.selected_by.value: {selected_by.get('value')!r} not an option value")
        elif sb_kind == "condition":
            _check_extra_keys(selected_by, {"kind", "conditions"}, "results", f"{row_where}.selected_by")
            conditions = selected_by.get("conditions")
            if not isinstance(conditions, list) or not conditions:
                fail("results", f"{row_where}.selected_by.conditions: missing or empty")
            for j, cond in enumerate(conditions):
                _check_condition_row(cond, f"{row_where}.selected_by.conditions[{j}]", mod_id=mod_id, state_cells_table=state_cells_table)
        elif sb_kind == "default":
            _check_extra_keys(selected_by, {"kind"}, "results", f"{row_where}.selected_by")
            if default_seen:
                fail("results", f"{row_where}.selected_by: a second default result in this map")
            default_seen = True
        else:
            fail("results", f"{row_where}.selected_by.kind: {sb_kind!r} not in the vocabulary")

        if not isinstance(result.get("event_played"), bool):
            fail("results", f"{row_where}.event_played: not a bool")
        terminal_id = result.get("terminal")
        if terminal_id not in terminals:
            fail("results", f"{row_where}.terminal: {terminal_id!r} not in terminals")
        _check_dialogue_entries(result.get("dialogue", []), f"{row_where}.dialogue")
        _check_effect_rows(result.get("after", []), f"{row_where}.after", mod_id=mod_id, state_cells_table=state_cells_table, observed=observed)

        nested_choice = result.get("choice")
        nested_results = result.get("results")
        if nested_choice is not None:
            _check_choice_block(nested_choice, nested_results if isinstance(nested_results, dict) else {}, f"{row_where}.choice")
        if nested_results is not None:
            _check_results_map(nested_results, choice=nested_choice, terminals=terminals, where=f"{row_where}.results", mod_id=mod_id, state_cells_table=state_cells_table, observed=observed)


def _check_terminals(terminals: Any) -> None:
    if not isinstance(terminals, dict) or not terminals:
        fail("terminals", "terminals: missing or empty")
    for terminal_id, terminal in terminals.items():
        where = f"terminals[{terminal_id}]"
        if not isinstance(terminal, dict):
            fail("terminals", f"{where}: not an object")
        _check_extra_keys(terminal, {"kind"}, "terminals", where)
        if terminal.get("kind") not in TERMINAL_KIND_VALUES:
            fail("terminals", f"{where}.kind: {terminal.get('kind')!r} not in {sorted(TERMINAL_KIND_VALUES)}")


def _check_done(done: Any, *, state_cells_table: dict, observed: dict) -> None:
    if done is None:
        return
    if not isinstance(done, dict):
        fail("done", "done: not an object")
    _check_extra_keys(done, {"cell"}, "done", "done")
    cell = done.get("cell")
    if cell is None:
        fail("done", "done.cell: missing")
    if not isinstance(cell, dict):
        fail("done", "done.cell: not an object")
    if not isinstance(cell.get("storage"), str):
        fail("done", "done.cell.storage missing or not a string")
    for key in ("bank", "index", "value"):
        if not _is_int(cell.get(key)):
            fail("done", f"done.cell.{key} missing or not an integer")
    cls = state_cells.classify(cell.get("storage"), cell.get("bank"), cell.get("index"), observed.get((cell.get("storage"), cell.get("bank"), cell.get("index"))), table=state_cells_table)
    if cls not in DONE_CELL_CLASSES:
        fail("done", f"done.cell class {cls!r} not in {sorted(DONE_CELL_CLASSES)}")


def _check_order_hint(order_hint: Any) -> None:
    if order_hint is None:
        return
    if not isinstance(order_hint, dict):
        fail("bad_order_hint", "trigger.order_hint: not an object")
    _check_extra_keys(order_hint, {"rank"}, "bad_order_hint", "trigger.order_hint")
    rank = order_hint.get("rank")
    if not (_is_int(rank) and rank >= 1):
        fail("bad_order_hint", "trigger.order_hint.rank must be an integer >= 1")


# ---------------------------------------------------------------------------
# A.2 trigger / presentation
# ---------------------------------------------------------------------------


def _check_trigger(trigger: Any, *, display: dict, names_registry: dict | None) -> None:
    if not isinstance(trigger, dict):
        fail("trigger", "trigger: not an object")
    _check_extra_keys(trigger, {"type", "category", "place", "order_hint"}, "trigger", "trigger")
    if trigger.get("type") != "place":
        fail("trigger", f"trigger.type {trigger.get('type')!r} is not 'place'")
    category, place = trigger.get("category"), trigger.get("place")
    if not isinstance(category, str) or category not in CATEGORY_VALUES:
        fail("trigger", f"trigger.category {category!r} not in {sorted(CATEGORY_VALUES)}")
    if not isinstance(place, str) or not PLACE_RE.match(place):
        fail("trigger", f"trigger.place {place!r} does not match the pattern")
    display_category = display.get("category") if isinstance(display, dict) else None
    display_place = display.get("place") if isinstance(display, dict) else None
    if category != display_category or place != display_place:
        fail("trigger", "trigger.category/place must equal display.category/place")
    if names_registry is not None:
        pairs = names_registry.get("pairs", set())
        if (category, place) not in pairs:
            fail("trigger", f"trigger (category={category!r}, place={place!r}) is on no registry row")


def _check_presentation(presentation: Any) -> None:
    if presentation is None:
        return
    if not isinstance(presentation, dict):
        fail("presentation", "presentation: not an object")
    _check_extra_keys(presentation, {"mode", "background", "bgm", "characters", "hud", "message_window"}, "presentation", "presentation")
    mode = presentation.get("mode")
    if not isinstance(mode, str) or mode == "":
        fail("presentation", "presentation.mode missing or not a non-empty string")
    for key in PRESENTATION_STRING_KEYS:
        if key in presentation:
            value = presentation[key]
            if not isinstance(value, str) or value == "":
                fail("presentation", f"presentation.{key} must be a non-empty string")
    if "characters" in presentation:
        characters = presentation["characters"]
        if not isinstance(characters, list) or not all(isinstance(c, str) and c for c in characters):
            fail("presentation", "presentation.characters must be a list of non-empty strings")


# ---------------------------------------------------------------------------
# Header: mod / id / display
# ---------------------------------------------------------------------------


def _check_mod(mod: Any) -> str:
    if not isinstance(mod, dict):
        fail("mod", "mod: not an object")
    _check_extra_keys(mod, {"id", "revision"}, "mod", "mod")
    mod_id = mod.get("id")
    if not isinstance(mod_id, str) or not MOD_ID_RE.match(mod_id):
        fail("mod", f"mod.id {mod_id!r} does not match the mod id pattern")
    revision = mod.get("revision")
    if not (_is_int(revision) and revision >= 1):
        fail("mod", "mod.revision must be an integer >= 1")
    return mod_id


def _check_id(doc_id: Any, *, mod_id: str) -> None:
    if not isinstance(doc_id, str):
        fail("id", f"id {doc_id!r} is not a string")
    match = DOC_ID_RE.match(doc_id)
    if not match:
        fail("id", f"id {doc_id!r} does not match the mod document id pattern")
    if match.group(1) != mod_id:
        fail("id", f"id {doc_id!r}: the middle segment != mod.id {mod_id!r}")


def _check_display(display: Any, *, required: bool, state_cells_table: dict) -> None:
    if display is None:
        if required:
            fail("display", "display: required for a new_event")
        return
    if not isinstance(display, dict):
        fail("display", "display: not an object")
    _check_extra_keys(display, {"title_ko", "title_en", "heroine", "category", "place"}, "display", "display")
    for key in ("title_ko", "title_en", "category", "place"):
        if key not in display:
            fail("display", f"display.{key} missing")
    title_ko, title_en = display.get("title_ko"), display.get("title_en")
    if not isinstance(title_ko, str) or not isinstance(title_en, str):
        fail("display", "display.title_ko/title_en must be strings")
    if title_ko == "" and title_en == "":
        fail("display", "display.title_ko/title_en: at least one must be non-empty")
    for label, value in (("title_ko", title_ko), ("title_en", title_en)):
        if value != "":
            result = check_text(value, allow_line_break=False, placeholder="name")
            if result is not None:
                reason, detail = result
                fail(reason, f"display.{label}: {detail}")
    heroine = display.get("heroine")
    if heroine is not None and heroine not in _heroines(state_cells_table):
        fail("display", f"display.heroine {heroine!r} is not one of the thirteen heroine names")
    category = display.get("category")
    if category not in CATEGORY_VALUES:
        fail("display", f"display.category {category!r} not in {sorted(CATEGORY_VALUES)}")
    place = display.get("place")
    if not isinstance(place, str) or not PLACE_RE.match(place):
        fail("display", f"display.place {place!r} does not match the pattern")


def _sweep_text_ref(document: dict) -> None:
    def walk(node, where):
        if isinstance(node, dict):
            if "text_ref" in node or "raw_sha256" in node:
                fail("text_ref_in_mod_document", f"{where}: carries text_ref or raw_sha256")
            for key, value in node.items():
                walk(value, f"{where}.{key}")
        elif isinstance(node, list):
            for i, item in enumerate(node):
                walk(item, f"{where}[{i}]")

    walk(document, "$")


# ---------------------------------------------------------------------------
# A.2 new_event
# ---------------------------------------------------------------------------


def _validate_new_event(document: dict, *, mod_id: str, state_cells_table: dict, names_registry: dict | None) -> None:
    display = document.get("display")
    trigger = document.get("trigger")
    _check_trigger(trigger, display=display, names_registry=names_registry)

    _check_condition_rows(document.get("conditions"), "conditions", mod_id=mod_id, state_cells_table=state_cells_table)

    _check_presentation(document.get("presentation"))

    _check_dialogue_entries(document.get("dialogue"), "dialogue")

    observed = _collect_observed_values(document)
    _check_effect_rows(document.get("after"), "after", mod_id=mod_id, state_cells_table=state_cells_table, observed=observed)

    choice = document.get("choice")
    results = document.get("results")
    if choice is not None:
        _check_choice_block(choice, results if isinstance(results, dict) else {}, "choice")

    terminals = document.get("terminals")
    _check_results_map(results, choice=choice, terminals=terminals if isinstance(terminals, dict) else {}, where="results", mod_id=mod_id, state_cells_table=state_cells_table, observed=observed)

    _check_terminals(terminals)

    _check_done(document.get("done"), state_cells_table=state_cells_table, observed=observed)

    _check_flow_v4(document)

    _check_order_hint(trigger.get("order_hint") if isinstance(trigger, dict) else None)


# ---------------------------------------------------------------------------
# A.3 override
# ---------------------------------------------------------------------------


def _check_target(target: Any) -> str:
    if not isinstance(target, dict):
        fail("target", "target: not an object")
    _check_extra_keys(target, {"id", "contract", "document_sha256"}, "target", "target")
    target_id = target.get("id")
    if not isinstance(target_id, str) or not ID_RE.match(target_id):
        fail("target", f"target.id {target_id!r} does not match the registry id pattern")
    if target.get("contract") != "kakyu_event_definition/v4":
        fail("target", f"target.contract {target.get('contract')!r} != 'kakyu_event_definition/v4'")
    doc_sha = target.get("document_sha256")
    if not isinstance(doc_sha, str) or not DOCUMENT_SHA256_RE.match(doc_sha):
        fail("target", "target.document_sha256 must be 64 lowercase hex characters")
    return target_id


def _resolve_base_document_bytes(base_documents, target_id: str) -> bytes | None:
    if base_documents is None:
        return None
    if callable(base_documents):
        return base_documents(target_id)
    base_dir = Path(base_documents)
    path = base_dir / f"{target_id}.json"
    if not path.is_file():
        return None
    return path.read_bytes()


def _check_result_document(result_document: Any, where: str, *, mod_id: str, state_cells_table: dict, observed: dict) -> None:
    if not isinstance(result_document, dict):
        fail("operations", f"{where}: not an object")
    _check_extra_keys(result_document, {"selected_by", "event_played", "dialogue", "after", "terminal", "choice", "results"}, "operations", where)

    selected_by = result_document.get("selected_by")
    if not isinstance(selected_by, dict) or selected_by.get("kind") not in SELECTED_BY_KINDS:
        fail("operations", f"{where}.selected_by: kind not in the vocabulary")
    if selected_by.get("kind") == "condition":
        conditions = selected_by.get("conditions")
        if not isinstance(conditions, list) or not conditions:
            fail("operations", f"{where}.selected_by.conditions: missing or empty")
        for j, cond in enumerate(conditions):
            _check_condition_row(cond, f"{where}.selected_by.conditions[{j}]", mod_id=mod_id, state_cells_table=state_cells_table)

    if not isinstance(result_document.get("event_played"), bool):
        fail("operations", f"{where}.event_played: not a bool")
    terminal = result_document.get("terminal")
    if terminal not in TERMINAL_KIND_VALUES:
        fail("operations", f"{where}.terminal: {terminal!r} not in {sorted(TERMINAL_KIND_VALUES)}")

    _check_dialogue_entries(result_document.get("dialogue", []), f"{where}.dialogue")
    _check_effect_rows(result_document.get("after", []), f"{where}.after", mod_id=mod_id, state_cells_table=state_cells_table, observed=observed)

    nested_choice = result_document.get("choice")
    nested_results = result_document.get("results")
    if nested_choice is not None:
        _check_choice_block(nested_choice, nested_results if isinstance(nested_results, dict) else {}, f"{where}.choice")
    if nested_results is not None:
        if not isinstance(nested_results, dict) or not nested_results:
            fail("operations", f"{where}.results: empty")
        default_seen = False
        for nested_id, nested_result in nested_results.items():
            nested_where = f"{where}.results[{nested_id}]"
            if not RESULT_ID_RE.match(nested_id):
                fail("operations", f"{nested_where}: result id does not match the pattern")
            _check_result_document(nested_result, nested_where, mod_id=mod_id, state_cells_table=state_cells_table, observed=observed)
            nested_sb = nested_result.get("selected_by") if isinstance(nested_result, dict) else {}
            if isinstance(nested_sb, dict) and nested_sb.get("kind") == "default":
                if default_seen:
                    fail("operations", f"{nested_where}.selected_by: a second default result in this map")
                default_seen = True


def _collect_result_document_targets(result_document: dict, *, top_allowed: bool) -> set:
    targets = set()
    if top_allowed:
        targets.add("top")

    def walk(results):
        if not isinstance(results, dict):
            return
        for result_id, result in results.items():
            if not isinstance(result, dict):
                continue
            if result.get("choice") is not None:
                targets.add(result_id)
            walk(result.get("results"))

    walk(result_document.get("results"))
    return targets


def _check_result_document_flow(result_document: dict, where: str, *, base_document: dict | None, base_documents) -> None:
    if not isinstance(result_document, dict):
        return
    if base_documents is not None:
        top_allowed = isinstance(base_document, dict) and base_document.get("choice") is not None
    else:
        # Without --definitions-dir, whether the base carries a choice is
        # unverifiable; "top" is shape-checked only (A.3).
        top_allowed = True
    valid_targets = _collect_result_document_targets(result_document, top_allowed=top_allowed)

    _check_choice_points_v4(result_document.get("dialogue"), valid_targets, f"{where}.dialogue")
    body_scene_ends = _count_scene_ends_v4(result_document.get("dialogue"))
    if result_document.get("event_played") is False and body_scene_ends:
        fail("scene_end_in_skipped_result", f"{where}: event_played is false but dialogue has a scene_end")

    def walk(results, prefix_scene_ends, walk_where):
        if not isinstance(results, dict):
            return
        for result_id, result in results.items():
            if not isinstance(result, dict):
                continue
            row_where = f"{walk_where}[{result_id}]"
            own_dialogue = result.get("dialogue")
            _check_choice_points_v4(own_dialogue, valid_targets, f"{row_where}.dialogue")
            own_scene_ends = _count_scene_ends_v4(own_dialogue)
            if result.get("event_played") is False and own_scene_ends:
                fail("scene_end_in_skipped_result", f"{row_where}: event_played is false but dialogue has a scene_end")
            total = prefix_scene_ends + own_scene_ends
            if total > 1:
                fail("second_scene_end", f"{row_where}: flow carries {total} scene_end entries")
            walk(result.get("results"), total, f"{row_where}.results")

    walk(result_document.get("results"), body_scene_ends, f"{where}.results")


def _check_result_document_choice_gate(result_document: dict, *, base_choice: dict | None, base_choice_option_values: set, where: str) -> None:
    if not isinstance(result_document, dict):
        return
    selected_by = result_document.get("selected_by")
    if isinstance(selected_by, dict) and selected_by.get("kind") == "choice":
        if base_choice is None or selected_by.get("value") not in base_choice_option_values:
            fail("results", f"{where}.selected_by.value: not an option value of the base's top-level choice")


def _validate_override(document: dict, *, mod_id: str, state_cells_table: dict, names_registry: dict | None, base_documents) -> None:
    target = document.get("target")
    target_id = _check_target(target)

    if names_registry is not None:
        if target_id not in names_registry.get("ids", set()):
            fail("names", f"target.id {target_id!r} not in the registry")

    base_document = None
    if base_documents is not None:
        base_bytes = _resolve_base_document_bytes(base_documents, target_id)
        if base_bytes is None:
            fail("target_missing", f"target.id {target_id!r} has no file under the definitions dir")
        actual_hash = hashlib.sha256(base_bytes.replace(b"\r\n", b"\n")).hexdigest()
        if actual_hash != target.get("document_sha256"):
            fail("target_changed", f"target.document_sha256 {target.get('document_sha256')!r} != {actual_hash!r}")
        base_document = json.loads(base_bytes.decode("utf-8"))

    operations = document.get("operations")
    if not isinstance(operations, list) or not operations:
        fail("operations", "operations: missing or empty")

    disable_ops = [op for op in operations if isinstance(op, dict) and op.get("op") == "disable"]
    if disable_ops and len(operations) != 1:
        fail("disable_not_alone", "disable must be the only operation")

    base_choice = base_document.get("choice") if isinstance(base_document, dict) else None
    base_results_keys = set((base_document.get("results") or {}).keys()) if isinstance(base_document, dict) else set()
    base_choice_option_values: set = set()
    if isinstance(base_choice, dict) and isinstance(base_choice.get("options"), list):
        base_choice_option_values = {opt.get("value") for opt in base_choice.get("options") if isinstance(opt, dict)}

    observed = _collect_observed_values(document)

    seen_replace_conditions = False
    seen_replace_after_scopes: set = set()
    seen_replace_result_ids: set = set()
    seen_append_result_ids: set = set()
    seen_replace_order_hint = False

    for i, op in enumerate(operations):
        where = f"operations[{i}]"
        if not isinstance(op, dict):
            fail("operations", f"{where}: not an object")
        op_type = op.get("op")
        if op_type not in OP_TYPES:
            fail("operations", f"{where}: unknown op {op_type!r}")

        if op_type == "replace_conditions":
            _check_extra_keys(op, {"op", "conditions"}, "operations", where)
            conditions = op.get("conditions")
            if not isinstance(conditions, list):
                fail("operations", f"{where}.conditions: missing or not a list")
            if seen_replace_conditions:
                fail("duplicate_operation", f"{where}: a second replace_conditions")
            seen_replace_conditions = True
            for j, cond in enumerate(conditions):
                _check_condition_row(cond, f"{where}.conditions[{j}]", mod_id=mod_id, state_cells_table=state_cells_table)

        elif op_type == "replace_after":
            _check_extra_keys(op, {"op", "scope", "after"}, "operations", where)
            scope = op.get("scope")
            if not isinstance(scope, str) or scope == "":
                fail("operations", f"{where}.scope: missing or not a string")
            if scope in seen_replace_after_scopes:
                fail("duplicate_operation", f"{where}: a second replace_after for scope {scope!r}")
            seen_replace_after_scopes.add(scope)
            after = op.get("after")
            if not isinstance(after, list):
                fail("operations", f"{where}.after: missing or not a list")
            _check_effect_rows(after, f"{where}.after", mod_id=mod_id, state_cells_table=state_cells_table, observed=observed)
            if base_document is not None and scope != "body" and scope not in base_results_keys:
                fail("unknown_result", f"{where}: scope {scope!r} not among the base's top-level results")

        elif op_type == "replace_result":
            _check_extra_keys(op, {"op", "result", "result_document"}, "operations", where)
            result_id = op.get("result")
            if not isinstance(result_id, str) or not RESULT_ID_RE.match(result_id):
                fail("operations", f"{where}.result: malformed")
            if result_id in seen_replace_result_ids:
                fail("duplicate_operation", f"{where}: a second replace_result for {result_id!r}")
            seen_replace_result_ids.add(result_id)
            result_document = op.get("result_document")
            _check_result_document(result_document, f"{where}.result_document", mod_id=mod_id, state_cells_table=state_cells_table, observed=observed)
            _check_result_document_flow(result_document, f"{where}.result_document", base_document=base_document, base_documents=base_documents)
            if base_document is not None:
                if result_id not in base_results_keys:
                    fail("unknown_result", f"{where}: result {result_id!r} not among the base's top-level results")
                _check_result_document_choice_gate(result_document, base_choice=base_choice, base_choice_option_values=base_choice_option_values, where=f"{where}.result_document")

        elif op_type == "append_result":
            _check_extra_keys(op, {"op", "result", "result_document"}, "operations", where)
            result_id = op.get("result")
            if not isinstance(result_id, str) or not RESULT_ID_RE.match(result_id):
                fail("operations", f"{where}.result: malformed")
            if result_id in seen_append_result_ids:
                fail("duplicate_operation", f"{where}: a second append_result for {result_id!r}")
            seen_append_result_ids.add(result_id)
            result_document = op.get("result_document")
            if isinstance(result_document, dict):
                sb_kind = (result_document.get("selected_by") or {}).get("kind") if isinstance(result_document.get("selected_by"), dict) else None
                if sb_kind not in ("choice", "condition"):
                    fail("operations", f"{where}.result_document.selected_by: an append_result's kind must be choice or condition")
            _check_result_document(result_document, f"{where}.result_document", mod_id=mod_id, state_cells_table=state_cells_table, observed=observed)
            _check_result_document_flow(result_document, f"{where}.result_document", base_document=base_document, base_documents=base_documents)
            if base_document is not None:
                if result_id in base_results_keys:
                    fail("result_exists", f"{where}: result {result_id!r} already exists in the base")
                _check_result_document_choice_gate(result_document, base_choice=base_choice, base_choice_option_values=base_choice_option_values, where=f"{where}.result_document")

        elif op_type == "replace_order_hint":
            _check_extra_keys(op, {"op", "rank"}, "operations", where)
            rank = op.get("rank")
            if not (_is_int(rank) and rank >= 1):
                fail("operations", f"{where}.rank: must be an integer >= 1")
            if seen_replace_order_hint:
                fail("duplicate_operation", f"{where}: a second replace_order_hint")
            seen_replace_order_hint = True

        elif op_type == "disable":
            _check_extra_keys(op, {"op"}, "operations", where)


# ---------------------------------------------------------------------------
# Top-level dispatch
# ---------------------------------------------------------------------------


def validate(
    document: dict,
    *,
    fingerprint: str | None = None,
    cells_fingerprint: str | None = None,
    allow_unrecorded: bool = False,
    names_registry: dict | None = None,
    base_documents: Callable[[str], bytes | None] | Path | str | None = None,
    state_cells_table: dict | None = None,
) -> dict:
    try:
        if not isinstance(document, dict):
            fail("schema", "document: not an object")
        if document.get("schema_version") != SCHEMA_VERSION:
            fail("schema", f"schema_version {document.get('schema_version')!r} != {SCHEMA_VERSION!r}")

        stored_fp = document.get("contract_fingerprint")
        if not stored_fp:
            fail("fingerprint", "contract_fingerprint missing")
        if stored_fp == "unrecorded":
            if not allow_unrecorded:
                fail("fingerprint", "contract_fingerprint is unrecorded without --allow-unrecorded")
        elif fingerprint is not None:
            effective = fingerprint if stored_fp == "self" else stored_fp
            if effective != fingerprint:
                fail("fingerprint", f"contract_fingerprint {stored_fp!r} != {fingerprint!r}")

        stored_cfp = document.get("cells_fingerprint")
        if not stored_cfp:
            fail("cells", "cells_fingerprint missing")
        if stored_cfp == "unrecorded":
            if not allow_unrecorded:
                fail("cells", "cells_fingerprint is unrecorded without --allow-unrecorded")
        elif cells_fingerprint is not None:
            effective_cfp = cells_fingerprint if stored_cfp == "self" else stored_cfp
            if effective_cfp != cells_fingerprint:
                fail("cells", f"cells_fingerprint {stored_cfp!r} != {cells_fingerprint!r}")

        kind = document.get("kind")
        if kind not in KIND_VALUES:
            fail("kind", f"kind {kind!r} not in {sorted(KIND_VALUES)}")

        kind_keys = NEW_EVENT_KEYS if kind == "new_event" else OVERRIDE_KEYS
        allowed_keys = HEADER_KEYS | kind_keys
        extra = set(document) - allowed_keys
        if extra:
            fail("unknown_field", f"unknown top-level keys {sorted(extra)}")

        required_keys = REQUIRED_HEADER | (REQUIRED_NEW_EVENT if kind == "new_event" else REQUIRED_OVERRIDE)
        for key in required_keys:
            if key not in document:
                fail("required", f"required field {key!r} missing")

        mod_id = _check_mod(document.get("mod"))
        _check_id(document.get("id"), mod_id=mod_id)

        table = state_cells_table if state_cells_table is not None else state_cells.load()

        _check_display(document.get("display"), required=(kind == "new_event"), state_cells_table=table)

        _sweep_text_ref(document)

        if kind == "new_event":
            _validate_new_event(document, mod_id=mod_id, state_cells_table=table, names_registry=names_registry)
        else:
            _validate_override(document, mod_id=mod_id, state_cells_table=table, names_registry=names_registry, base_documents=base_documents)

    except Fail as f:
        return {"ok": False, "reason": f.reason, "detail": f.detail}
    return {"ok": True, "reason": "ok", "detail": ""}


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("document", type=Path)
    parser.add_argument("--names", type=Path, default=None, help="event name registry directory")
    parser.add_argument("--definitions-dir", type=Path, default=None, help="tracked v4 definitions directory")
    parser.add_argument("--fingerprint", default=None, help="expected contract_fingerprint")
    parser.add_argument("--cells-fingerprint", default=None, help="expected cells_fingerprint")
    parser.add_argument("--allow-unrecorded", action="store_true")
    args = parser.parse_args(argv)

    document = json.loads(args.document.read_text(encoding="utf-8"))

    names_registry = None
    if args.names is not None:
        if args.names.is_dir():
            names_registry = load_names_registry(args.names)
        else:
            print(json.dumps({"ok": False, "reason": "names", "detail": "registry not found, skipped"}))
            names_registry = None

    fingerprint = args.fingerprint
    if fingerprint is None:
        fingerprint_path = ROOT / "config" / "contracts" / "mod_event_definition_v1" / "contract_fingerprint"
        if fingerprint_path.is_file():
            fingerprint = fingerprint_path.read_text(encoding="utf-8").strip()

    cells_fingerprint = args.cells_fingerprint
    if cells_fingerprint is None:
        cells_fingerprint_path = ROOT / "config" / "contracts" / "state_cells_v1" / "cells_fingerprint"
        if cells_fingerprint_path.is_file():
            cells_fingerprint = cells_fingerprint_path.read_text(encoding="utf-8").strip()

    base_documents = args.definitions_dir if args.definitions_dir is not None else None

    result = validate(
        document,
        fingerprint=fingerprint,
        cells_fingerprint=cells_fingerprint,
        allow_unrecorded=args.allow_unrecorded,
        names_registry=names_registry,
        base_documents=base_documents,
    )
    print(json.dumps(result))
    return 0 if result["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
