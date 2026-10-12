"""Local validator for a `kakyu_event_definition/v3` document (WD-22 part 3).

    py tools/validate_event_definition.py <document.json> [--names <registry dir>]
        [--package <package dir>] [--fingerprint <expected contract fingerprint>]
        [--allow-unrecorded]

Prints one JSON line ``{"ok": bool, "reason": code, "detail": str}`` and
exits 0 when ``ok`` is true, 1 otherwise. See
``docs/spec/data/event_definition_projection.md`` for the document shape and
the exact rule each reason code enforces; this module keeps the same check
order the spec lists so that the first offending field always produces the
same reason.

A document's own ``contract_fingerprint`` and ``names_fingerprint`` may each
be the literal string ``"self"``: with ``--fingerprint``/``--names`` given,
``"self"`` is accepted as equal to the expected value (the fixture set's own
convention, since a fixture cannot record its own directory's fingerprint or
embed the registry's fingerprint without moving it whenever a title is
renamed). Without ``--names``, ``names_fingerprint`` need only be present
and non-empty.
"""
from __future__ import annotations

import argparse
import json
import os
import sys
import unicodedata
from pathlib import Path
from typing import Any

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import state_cells  # noqa: E402
from payload_values import MEDIA_INVENTORY_SCHEMA, MEDIA_KINDS, is_safe_leaf  # noqa: E402
from text_rules import check_text  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]

SCHEMA_VERSION = "kakyu_event_definition/v3"
PACKAGE_SCHEMA = "kakyu_playback_package/v7"

ID_PATTERN_PARTS = (
    "school",
    "town",
    "date",
    "special",
)

import re


# The same pattern `tools/build_event_names.py`'s own `ID_RE` uses (the
# registry builder that actually assigns `row["id"]`): a copy that had drifted
# from the builder's own widening for a hyphenated route number (the
# `01m-a-date` flow rows' `date-town`/`date-date5`/`date-hotel`, added when the
# EP-12 catalog part promoted them - `config/contracts/event_names_v1/
# event_names.json`), found while EP-12 / WD unit 2 (2026-09-25) validated the
# first `kakyu_event_definition/v6` flow documents against those exact ids.
# Not a v6 contract rule (the id-shape check predates v6 by several schema
# versions and applies uniformly to every schema this module validates); the
# fix only widens what a previously-merged, already-committed registry id can
# match, so no currently tracked v3/v4/v5 document's id is affected.
ID_RE = re.compile(
    r"^[a-z]+\.(school|town|date|special)\.[a-z0-9_]+\.[a-z0-9]+(?:-[a-z0-9]+)?\.[1-9]$"
)

KIND_VALUES = {"event", "choice_event"}
EVIDENCE_KINDS = {"catalog_event", "analysis_group"}
CALLER_KIND_VALUES = {"root_handoff", "nested_call", "nested_root_handoff"}
ORIGIN_KINDS = {"typed_guard", "map_arrival", "caller_prefix"}
SCENE_KINDS = {"train_ride", "school_gate", "school_floor", "town"}
CONJUNCT_KINDS = {"weekday", "date", "clock", "choice", "affection", "cell", "mes_expression"}
CELL_COMPARISON_OP = {"equal", "not_equal", "less_than", "greater_than"}
CONDITION_TYPES = {
    "always",
    "event_not_completed",
    "event_completed",
    "flag_equals",
    "protagonist_name_set",
    "opening_sequence_completed",
    "character_info_known",
    "character_info_unknown",
    "character_talked_today",
    "character_not_talked_today",
    "character_can_converse",
    "weekday_equals",
    "date_equals",
    "date_in_range",
    "date_in_period",
    "calendar_role",
    "time_at_or_after",
    "time_before",
    "mes_expression",
    "mes_expression_file",
}
EFFECT_TYPE = "write_legacy_value"
CHOICE_POSITIONS = {"in_event", "before_event"}
SELECTED_BY_KINDS = {"choice", "condition", "default"}
TERMINAL_KINDS = {
    "root_handoff",
    "callee_return",
    "natural_handoff",
    "def_selection_boundary",
    "caller_menu_loop",
    "dependency_stop",
}

REQUIRED_TOP_LEVEL = (
    "schema_version",
    "contract_fingerprint",
    "names_fingerprint",
    "id",
    "kind",
    "display",
    "evidence",
    "package_binding",
    "trigger",
    "conditions",
    "dialogue",
    "after",
    "results",
    "terminals",
    "presentation",
    "unresolved",
)


class Fail(Exception):
    def __init__(self, reason: str, detail: str):
        super().__init__(detail)
        self.reason = reason
        self.detail = detail


def fail(reason: str, detail: str):
    raise Fail(reason, detail)


def _is_int(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool)


def _check_effect_row(row: Any, where: str) -> None:
    if not isinstance(row, dict):
        fail("effects", f"{where}: not an object")
    if row.get("type") != EFFECT_TYPE:
        fail("effects", f"{where}: type {row.get('type')!r} is not {EFFECT_TYPE!r}")
    if not isinstance(row.get("storage"), str):
        fail("effects", f"{where}: storage missing or not a string")
    for key in ("bank", "index", "value"):
        if not _is_int(row.get(key)):
            fail("effects", f"{where}: {key} missing or not an integer")


def _check_effect_rows(rows: Any, where: str) -> None:
    if not isinstance(rows, list):
        fail("effects", f"{where}: not a list")
    for i, row in enumerate(rows):
        _check_effect_row(row, f"{where}[{i}]")


def _check_cell_row(row: Any, where: str, reason: str, *, with_operator: bool = False) -> None:
    """A plain cell row: `{storage, bank, index, value}`, no `type`. A
    condition row (`with_operator`) carries `operator` instead of a bare
    value comparison target being implicit equality."""
    if not isinstance(row, dict):
        fail(reason, f"{where}: not an object")
    if not isinstance(row.get("storage"), str):
        fail(reason, f"{where}: storage missing or not a string")
    for key in ("bank", "index", "value"):
        if not _is_int(row.get(key)):
            fail(reason, f"{where}: {key} missing or not an integer")
    if with_operator:
        if not isinstance(row.get("operator"), str) or not row.get("operator"):
            fail(reason, f"{where}: operator missing")


def _check_cell_rows(rows: Any, where: str, reason: str, *, with_operator: bool = False) -> None:
    if not isinstance(rows, list):
        fail(reason, f"{where}: not a list")
    for i, row in enumerate(rows):
        _check_cell_row(row, f"{where}[{i}]", reason, with_operator=with_operator)


def _check_required_state_rows(rows: Any, where: str) -> None:
    if rows is None:
        return
    _check_cell_rows(rows, where, "terminals")


DIALOGUE_ENTRY_KINDS = {"text", "name_insert"}


def _package_record(package: dict, entry: str, at: Any, where: str):
    member_records = package.get(entry)
    if member_records is None:
        fail("text", f"{where}: entry {entry!r} not in package")
    record = member_records.get(at) if isinstance(member_records, dict) else None
    if record is None:
        fail("text", f"{where}: at {at!r} not in package member {entry!r}")
    return record


def _check_dialogue_entries(entries: Any, where: str, package: dict | None) -> None:
    if not isinstance(entries, list):
        fail("text", f"{where}: dialogue is not a list")
    for i, entry in enumerate(entries):
        row_where = f"{where}[{i}]"
        if not isinstance(entry, dict):
            fail("text", f"{row_where}: not an object")
        if "text" in entry:
            fail("text", f"{row_where}: inline text key present")
        kind = entry.get("kind")
        if kind not in DIALOGUE_ENTRY_KINDS:
            fail("text", f"{row_where}: kind {kind!r} not in {sorted(DIALOGUE_ENTRY_KINDS)}")
        if kind == "text":
            ref = entry.get("text_ref")
            if not isinstance(ref, dict):
                fail("text", f"{row_where}: text_ref missing")
            for key in ("entry", "at", "s", "raw_sha256"):
                if key not in ref:
                    fail("text", f"{row_where}: text_ref missing {key}")
            if package is not None:
                record = _package_record(package, ref.get("entry"), ref.get("at"), row_where)
                operands = record.get("operands") or []
                operand = operands[0] if operands else {}
                if not (operand.get("t") == "text" and operand.get("s") == ref.get("s")):
                    fail("text", f"{row_where}: package record at {ref.get('at')!r} does not carry t=text s={ref.get('s')!r}")
        else:  # name_insert
            if "text_ref" in entry or "s" in entry:
                fail("text", f"{row_where}: name_insert carries text_ref or s")
            for key in ("entry", "at", "raw_sha256"):
                if key not in entry:
                    fail("text", f"{row_where}: name_insert missing {key}")
            if package is not None:
                record = _package_record(package, entry.get("entry"), entry.get("at"), row_where)
                if record.get("op") != "protagonist_name_insert":
                    fail("text", f"{row_where}: package record at {entry.get('at')!r} op is not protagonist_name_insert")


def _check_guard(guard: Any, where: str) -> None:
    if not isinstance(guard, dict):
        fail("guard", f"{where}: not an object")
    conjuncts = guard.get("conjuncts")
    if not isinstance(conjuncts, list):
        fail("guard", f"{where}: conjuncts missing or not a list")
    for i, conjunct in enumerate(conjuncts):
        row_where = f"{where}.conjuncts[{i}]"
        if not isinstance(conjunct, dict):
            fail("guard", f"{row_where}: not an object")
        kind = conjunct.get("kind")
        if kind not in CONJUNCT_KINDS:
            fail("guard", f"{row_where}: unknown conjunct kind {kind!r}")
        if kind == "mes_expression":
            if not conjunct.get("ast"):
                fail("guard", f"{row_where}: mes_expression without ast")
        else:
            if conjunct.get("op") not in CELL_COMPARISON_OP:
                fail("guard", f"{row_where}: op {conjunct.get('op')!r} not in the vocabulary")
    witnesses = guard.get("witnesses")
    if witnesses is not None:
        if not isinstance(witnesses, list):
            fail("guard", f"{where}: witnesses not a list")
        for i, witness in enumerate(witnesses):
            row_where = f"{where}.witnesses[{i}]"
            if not isinstance(witness, dict):
                fail("guard", f"{row_where}: not an object")
            if witness.get("expected") not in (0, 1):
                fail("guard", f"{row_where}: expected {witness.get('expected')!r} is not 0/1")
            _check_cell_rows(witness.get("writes", []), f"{row_where}.writes", "guard")


def _check_conditions(conditions: Any, where: str) -> None:
    if not isinstance(conditions, list):
        fail("conditions", f"{where}: not a list")
    for i, condition in enumerate(conditions):
        row_where = f"{where}[{i}]"
        if not isinstance(condition, dict):
            fail("conditions", f"{row_where}: not an object")
        condition_type = condition.get("type")
        if condition_type not in CONDITION_TYPES:
            fail("conditions", f"{row_where}: unknown condition type {condition_type!r}")
        if condition_type in ("mes_expression", "mes_expression_file"):
            if not condition.get("ast"):
                fail("conditions", f"{row_where}: mes_expression without ast")
        if condition_type == "event_not_completed" and "done_cell" in condition:
            done_cell = condition.get("done_cell")
            if not isinstance(done_cell, dict) or not isinstance(done_cell.get("storage"), str):
                fail("conditions", f"{row_where}: done_cell malformed")
            for key in ("bank", "index", "value"):
                if not _is_int(done_cell.get(key)):
                    fail("conditions", f"{row_where}: done_cell.{key} missing or not an integer")


def _check_scenes(scenes: Any, where: str) -> None:
    if scenes is None:
        return
    if not isinstance(scenes, list):
        fail("scenes", f"{where}: not a list")
    for i, scene in enumerate(scenes):
        row_where = f"{where}[{i}]"
        if not isinstance(scene, dict):
            fail("scenes", f"{row_where}: not an object")
        if scene.get("kind") not in SCENE_KINDS:
            fail("scenes", f"{row_where}: unknown scene kind {scene.get('kind')!r}")


def _check_trigger(trigger: Any) -> None:
    if not isinstance(trigger, dict):
        fail("trigger", "trigger: not an object")
    if trigger.get("type") != "caller_dispatch":
        fail("trigger", f"trigger.type {trigger.get('type')!r} is not caller_dispatch")
    caller = trigger.get("caller")
    if not isinstance(caller, dict):
        fail("trigger", "trigger.caller: missing")
    if caller.get("command") not in (14, 15):
        fail("trigger", f"trigger.caller.command {caller.get('command')!r} is not 14/15")
    if caller.get("kind") not in CALLER_KIND_VALUES:
        fail("trigger", f"trigger.caller.kind {caller.get('kind')!r} not in the vocabulary")
    origin = trigger.get("origin")
    if not isinstance(origin, dict):
        fail("trigger", "trigger.origin: missing")
    if origin.get("kind") not in ORIGIN_KINDS:
        fail("trigger", f"trigger.origin.kind {origin.get('kind')!r} not in the vocabulary")


def _check_choice(choice: Any, results: dict, where: str) -> None:
    if choice is None:
        return
    if not isinstance(choice, dict):
        fail("choice", f"{where}: not an object")
    if not choice.get("owner"):
        fail("choice", f"{where}: owner missing")
    if "boundary" not in choice or choice.get("boundary") in (None, ""):
        fail("choice", f"{where}: boundary missing")
    if choice.get("position") not in CHOICE_POSITIONS:
        fail("choice", f"{where}: position {choice.get('position')!r} not in the vocabulary")
    options = choice.get("options")
    if not isinstance(options, list) or not options:
        fail("choice", f"{where}: options missing or empty")
    for i, option in enumerate(options):
        row_where = f"{where}.options[{i}]"
        if not isinstance(option, dict):
            fail("choice", f"{row_where}: not an object")
        if "value" not in option:
            fail("choice", f"{row_where}: value missing")
        result_id = option.get("result")
        if not result_id:
            fail("choice", f"{row_where}: result missing")
        if result_id not in results:
            fail("choice", f"{row_where}: result {result_id!r} not in results")


def _check_result(result_id: str, result: Any, terminals: dict, results: dict, package: dict | None, where: str) -> None:
    if not isinstance(result, dict):
        fail("results", f"{where}: not an object")
    selected_by = result.get("selected_by")
    if not isinstance(selected_by, dict) or selected_by.get("kind") not in SELECTED_BY_KINDS:
        fail("results", f"{where}: selected_by kind not in the vocabulary")
    if selected_by.get("kind") == "condition":
        _check_cell_rows(selected_by.get("conditions", []), f"{where}.selected_by.conditions", "results", with_operator=True)
    if not isinstance(result.get("event_played"), bool):
        fail("results", f"{where}: event_played is not a bool")
    terminal_id = result.get("terminal")
    if terminal_id not in terminals:
        fail("results", f"{where}: terminal {terminal_id!r} not in terminals")
    _check_dialogue_entries(result.get("dialogue", []), f"{where}.dialogue", package)
    _check_effect_rows(result.get("after", []), f"{where}.after")
    if "choice" in result and result.get("choice") is not None:
        nested_results = result.get("results") or {}
        _check_choice(result.get("choice"), nested_results, f"{where}.choice")
    if "results" in result and result.get("results") is not None:
        nested_results = result.get("results")
        if not isinstance(nested_results, dict) or not nested_results:
            fail("results", f"{where}.results: empty")
        for nested_id, nested_result in nested_results.items():
            _check_result(nested_id, nested_result, terminals, nested_results, package, f"{where}.results[{nested_id}]")


def _check_terminals(terminals: Any) -> None:
    if not isinstance(terminals, dict) or not terminals:
        fail("terminals", "terminals: missing or empty")
    for terminal_id, terminal in terminals.items():
        where = f"terminals[{terminal_id}]"
        if not isinstance(terminal, dict):
            fail("terminals", f"{where}: not an object")
        if terminal.get("kind") not in TERMINAL_KINDS:
            fail("terminals", f"{where}: unknown terminal kind {terminal.get('kind')!r}")
        _check_required_state_rows(terminal.get("required_state"), where)


def _load_package(package_dir: Path | None) -> dict | None:
    """Load a minimal package view: manifest and per-entry text records.

    Returns ``None`` when no --package was given. Returns
    ``{"__manifest__": {...}, "<entry>": {<at>: {"s": ...}, ...}, ...}``.
    """
    if package_dir is None:
        return None
    manifest_path = package_dir / "manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8")) if manifest_path.is_file() else {}
    result: dict[str, Any] = {"__manifest__": manifest}
    events_dir = package_dir / "events"
    if events_dir.is_dir():
        for events_file in events_dir.glob("*.json"):
            records = json.loads(events_file.read_text(encoding="utf-8"))
            by_offset: dict[Any, Any] = {}
            if isinstance(records, dict):
                items = records.get("records", records)
            else:
                items = records
            if isinstance(items, list):
                for record in items:
                    if isinstance(record, dict) and "at" in record:
                        by_offset[record["at"]] = record
            elif isinstance(items, dict):
                by_offset = items
            # The member's own `entry` name (e.g. "EVENTJ04.MES") is what
            # text_ref.entry names; the file's stem (e.g. "EVENTJ04") is a
            # fallback for a package whose per-entry document omits it.
            entry_name = records.get("entry") if isinstance(records, dict) else None
            result[entry_name or events_file.stem] = by_offset
            if entry_name:
                result.setdefault(events_file.stem, by_offset)

    # v4 text-encoding checks (text_encoding.md) resolve a text_ref's string
    # from text/<STEM>.json's `strings`, keyed by `s`; kept under a key no
    # package member name can collide with. Unused by the v3 path.
    text_by_entry: dict[str, list] = {}
    text_dir = package_dir / "text"
    if text_dir.is_dir():
        for text_file in text_dir.glob("*.json"):
            table = json.loads(text_file.read_text(encoding="utf-8"))
            strings = table.get("strings", []) if isinstance(table, dict) else []
            entry_name = table.get("entry") if isinstance(table, dict) else None
            text_by_entry[entry_name or text_file.stem] = strings
            if entry_name:
                text_by_entry.setdefault(text_file.stem, strings)
    result["__text__"] = text_by_entry
    return result


def _validate_v3(
    document: dict,
    *,
    fingerprint: str | None = None,
    allow_unrecorded: bool = False,
    names_registry: dict | None = None,
    expected_names_fingerprint: str | None = None,
    package: dict | None = None,
) -> dict:
    try:
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

        names_fp = document.get("names_fingerprint")
        if not names_fp:
            fail("names", "names_fingerprint missing")
        if names_registry is not None:
            expected_names_fp = (
                expected_names_fingerprint if expected_names_fingerprint is not None else names_registry.get("fingerprint")
            )
            effective_names_fp = expected_names_fp if names_fp == "self" else names_fp
            if effective_names_fp != expected_names_fp:
                fail("names", f"names_fingerprint {names_fp!r} != registry fingerprint")

        doc_id = document.get("id")
        if not isinstance(doc_id, str) or not ID_RE.match(doc_id):
            fail("id", f"id {doc_id!r} does not match the id pattern")

        # A malformed id is reported as `id`, never masked by a registry
        # lookup; a well-formed id the registry does not carry is `names`.
        if names_registry is not None and doc_id not in names_registry.get("ids", set()):
            fail("names", f"id {doc_id!r} not in the registry")

        kind = document.get("kind")
        if kind not in KIND_VALUES:
            fail("kind", f"kind {kind!r} not in {sorted(KIND_VALUES)}")
        has_choice = "choice" in document and document.get("choice") is not None
        if kind == "choice_event" and not has_choice:
            fail("kind", "choice_event without choice")
        if kind == "event" and has_choice:
            fail("kind", "event with choice")

        for field in REQUIRED_TOP_LEVEL:
            if field not in document:
                fail("required", f"required field {field!r} missing")

        evidence = document.get("evidence")
        if not isinstance(evidence, dict) or evidence.get("kind") not in EVIDENCE_KINDS:
            fail("evidence", f"evidence.kind {evidence.get('kind') if isinstance(evidence, dict) else evidence!r} not in the vocabulary")
        members = evidence.get("members")
        if not isinstance(members, list):
            fail("evidence", "evidence.members missing or not a list")
        for i, member in enumerate(members):
            if not isinstance(member, dict) or "entry" not in member or "entry_sha256" not in member:
                fail("evidence", f"evidence.members[{i}] malformed")

        package_binding = document.get("package_binding")
        if not isinstance(package_binding, dict) or package_binding.get("schema") != PACKAGE_SCHEMA:
            fail("package", f"package_binding.schema {package_binding.get('schema') if isinstance(package_binding, dict) else package_binding!r} != {PACKAGE_SCHEMA!r}")
        if package is not None:
            manifest = package.get("__manifest__", {})
            if package_binding.get("package_sha256") != manifest.get("package_sha256"):
                fail("package", "package_binding.package_sha256 != manifest.package_sha256")
            manifest_members = {
                m.get("entry"): m.get("entry_sha256")
                for m in manifest.get("entries", manifest.get("members", []))
            }
            for i, member in enumerate(members):
                entry = member.get("entry")
                if entry in manifest_members and manifest_members[entry] != member.get("entry_sha256"):
                    fail("package", f"evidence.members[{i}] entry_sha256 != the manifest's")

        _check_trigger(document.get("trigger"))
        _check_scenes(document.get("scenes"), "scenes")
        if document.get("guard") is not None:
            _check_guard(document.get("guard"), "guard")
        _check_conditions(document.get("conditions"), "conditions")

        for i, preset in enumerate(document.get("presets") or []):
            if not isinstance(preset, dict):
                fail("presets", f"presets[{i}]: not an object")
            _check_cell_rows(preset.get("writes", []), f"presets[{i}].writes", "presets")

        _check_effect_rows(document.get("after"), "after")

        _check_dialogue_entries(document.get("dialogue"), "dialogue", package)

        results_raw = document.get("results")
        results = results_raw if isinstance(results_raw, dict) else {}

        if has_choice:
            _check_choice(document.get("choice"), results, "choice")

        if not results:
            fail("results", "results: empty")

        terminals = document.get("terminals")
        for result_id, result in results.items():
            _check_result(result_id, result, terminals if isinstance(terminals, dict) else {}, results, package, f"results[{result_id}]")

        _check_terminals(terminals)

    except Fail as f:
        return {"ok": False, "reason": f.reason, "detail": f.detail}
    return {"ok": True, "reason": "ok", "detail": ""}


# ---------------------------------------------------------------------------
# kakyu_event_definition/v4 (event definition v4 unit 2a). Everything above
# this line is the v3 path, unchanged. v4 is v3 plus the changes described in
# docs/spec/data/event_definition_v4_design.md; every v3 rule not mentioned
# there still applies, so the functions below reuse the v3 vocabulary
# constants (KIND_VALUES, ORIGIN_KINDS, SCENE_KINDS, CONJUNCT_KINDS,
# CONDITION_TYPES, TERMINAL_KINDS, CHOICE_POSITIONS, SELECTED_BY_KINDS,
# EVIDENCE_KINDS, PACKAGE_SCHEMA, ID_RE) and only add what the design
# document changes.
# ---------------------------------------------------------------------------

SCHEMA_VERSION_V4 = "kakyu_event_definition/v4"

# ---------------------------------------------------------------------------
# kakyu_event_definition/v5 (WD-23): v4 plus one optional top-level `visits`
# list (a document-level visit ladder selected by state conditions). Every
# v4 rule above still applies to a v5 document unchanged; `_check_visits_v5`
# below is the only new rule set.
# ---------------------------------------------------------------------------
SCHEMA_VERSION_V5 = "kakyu_event_definition/v5"
VISIT_FOLLOWS_SPECIAL_V5 = {"reentry", "first"}

EFFECT_TYPES_V4 = {"write_legacy_value", "add_legacy_value", "consume_time"}
CLOCK_CELLS_V4 = {("state_u16", 0), ("state_u16", 1), ("state_u16", 19)}
DIALOGUE_ENTRY_KINDS_V4 = {"text", "name_insert", "choice_point", "scene_end"}
WITNESS_BASIS_V4 = {"variants", "shift_witness", "flag_pattern", "clock"}
DONE_CELL_SOURCES_V4 = {"guard_flag", "reentry_probe"}
ORDER_HINT_BASIS_V4 = {"guard_offset"}

_CONTROL_RANGES = ((0x0000, 0x001F), (0x007F, 0x009F))


def _text_encoding_fail(reason: str, where: str, detail: str) -> None:
    fail(reason, f"{where}: {detail}")


def _check_resolved_text(text: str, where: str) -> None:
    """Rules 2 to 4 of text_encoding.md: NFC-stable, no control character
    (U+0000..U+001F, U+007F..U+009F), no U+FEFF, no U+FFFD, no noncharacter,
    no private-use character, no line break. A thin call to
    `tools.text_rules.check_text` (mod event definition unit A); the rule
    implementation itself lives there now so the mod event definition
    contract can reuse it with its own switches."""
    result = check_text(text)
    if result is not None:
        reason, detail = result
        _text_encoding_fail(reason, where, detail)


def _cell_key(row: dict) -> tuple:
    return (row.get("storage"), row.get("bank"), row.get("index"))


def _collect_observed_values(document: dict) -> dict[tuple, set]:
    """Every value a cell is known to hold anywhere in `document`: a
    `write_legacy_value` row's `value`, a preset write's `value`, and an
    `evidence.effect_witnesses` row's `entry`/`final`/`shifted_entry`/
    `shifted_final`. Used to tell `global_u8` `flag` from `counter`
    (`tools/state_cells.classify`)."""
    observed: dict[tuple, set] = {}

    def add(storage, bank, index, value):
        if not (_is_int(bank) and _is_int(index)) or value is None or not _is_int(value):
            return
        observed.setdefault((storage, bank, index), set()).add(value)

    def walk_effects(rows):
        for row in rows or []:
            if not isinstance(row, dict):
                continue
            if row.get("type") == "write_legacy_value":
                add(row.get("storage"), row.get("bank"), row.get("index"), row.get("value"))

    def walk_cell_rows(rows):
        for row in rows or []:
            if isinstance(row, dict):
                add(row.get("storage"), row.get("bank"), row.get("index"), row.get("value"))

    def walk_result(result):
        if not isinstance(result, dict):
            return
        walk_effects(result.get("after"))
        reentry = result.get("reentry")
        if isinstance(reentry, dict):
            walk_cell_rows(reentry.get("after"))
        nested = result.get("results")
        if isinstance(nested, dict):
            for nested_result in nested.values():
                walk_result(nested_result)

    walk_effects(document.get("after"))
    for preset in document.get("presets") or []:
        if isinstance(preset, dict):
            walk_cell_rows(preset.get("writes"))
    for result in (document.get("results") or {}).values():
        walk_result(result)
    for visit in document.get("visits") or []:
        if isinstance(visit, dict):
            walk_effects(visit.get("after"))
    # kakyu_event_definition/v6 (EP-12 / WD unit 2, 2026-09-25): a flow
    # document's own per-hop `after` rows are one more place a cell's value
    # is observed - the producer's `recompute_cell_classes` walks the same
    # `flow.hops[].after` list, so this function must agree or a hop-only
    # cell's `cell_class` would disagree between the two.
    flow = document.get("flow")
    if isinstance(flow, dict):
        for hop in flow.get("hops") or []:
            if isinstance(hop, dict):
                walk_effects(hop.get("after"))

    for witness in (document.get("evidence") or {}).get("effect_witnesses", []) or []:
        if not isinstance(witness, dict):
            continue
        cell = witness.get("cell") or {}
        storage, bank, index = cell.get("storage"), cell.get("bank"), cell.get("index")
        for key in ("entry", "final", "shifted_entry", "shifted_final"):
            if key in witness:
                add(storage, bank, index, witness.get(key))

    return observed


def _check_effect_rows_v4(rows: Any, where: str, state_cells_table: dict, observed: dict) -> None:
    if not isinstance(rows, list):
        fail("effects", f"{where}: not a list")
    seen_cells: set = set()
    consume_time_seen = False
    for i, row in enumerate(rows):
        row_where = f"{where}[{i}]"
        if not isinstance(row, dict):
            fail("effects", f"{row_where}: not an object")
        effect_type = row.get("type")
        if effect_type not in EFFECT_TYPES_V4:
            fail("effects", f"{row_where}: type {effect_type!r} not in {sorted(EFFECT_TYPES_V4)}")

        if effect_type == "consume_time":
            if consume_time_seen:
                fail("effects", f"{row_where}: more than one consume_time row in one list")
            consume_time_seen = True
            minutes = row.get("minutes")
            if not (_is_int(minutes) and minutes > 0):
                fail("bad_consume_time", f"{row_where}: minutes must be a positive integer")
            if row.get("cell_class") != "clock":
                fail("bad_consume_time", f"{row_where}: cell_class must be 'clock'")
            continue

        storage = row.get("storage")
        if not isinstance(storage, str):
            fail("effects", f"{row_where}: storage missing or not a string")
        for key in ("bank", "index"):
            if not _is_int(row.get(key)):
                fail("effects", f"{row_where}: {key} missing or not an integer")
        bank, index = row.get("bank"), row.get("index")

        if (storage, index) in CLOCK_CELLS_V4:
            fail("clock_cell_effect", f"{row_where}: {storage}[{index}] is a clock cell and never carries a write/add row")

        key = (storage, bank, index)
        if key in seen_cells:
            fail("duplicate_effect_cell", f"{row_where}: {storage}[{index}] already has an effect row in this list")
        seen_cells.add(key)

        if effect_type == "write_legacy_value":
            if not _is_int(row.get("value")):
                fail("effects", f"{row_where}: value missing or not an integer")
        else:  # add_legacy_value
            delta = row.get("delta")
            if not _is_int(delta):
                fail("effects", f"{row_where}: delta missing or not an integer")
            if delta == 0:
                fail("zero_delta", f"{row_where}: delta is zero")

        expected_class = state_cells.classify(storage, bank, index, observed.get(key), table=state_cells_table)
        if row.get("cell_class") != expected_class:
            fail("bad_cell_class", f"{row_where}: cell_class {row.get('cell_class')!r} != {expected_class!r}")


def _check_order_hint_v4(order_hint: Any, caller_entry: Any, where: str) -> None:
    if order_hint is None:
        return
    if not isinstance(order_hint, dict):
        fail("bad_order_hint", f"{where}: not an object")
    if order_hint.get("scope") != caller_entry:
        fail("bad_order_hint", f"{where}: scope {order_hint.get('scope')!r} != trigger.caller.entry {caller_entry!r}")
    rank, of = order_hint.get("rank"), order_hint.get("of")
    if not (_is_int(rank) and rank >= 1):
        fail("bad_order_hint", f"{where}: rank must be an integer >= 1")
    if not (_is_int(of) and of >= rank):
        fail("bad_order_hint", f"{where}: of must be an integer >= rank")
    if order_hint.get("basis") not in ORDER_HINT_BASIS_V4:
        fail("bad_order_hint", f"{where}: basis {order_hint.get('basis')!r} not in {sorted(ORDER_HINT_BASIS_V4)}")
    if not isinstance(order_hint.get("chain_confirmed"), bool):
        fail("bad_order_hint", f"{where}: chain_confirmed is not a bool")


def _check_trigger_v4(trigger: Any) -> None:
    _check_trigger(trigger)
    caller = trigger.get("caller") or {}
    _check_order_hint_v4(trigger.get("order_hint"), caller.get("entry"), "trigger.order_hint")


def _check_conditions_v4(conditions: Any, where: str) -> None:
    _check_conditions(conditions, where)
    for i, condition in enumerate(conditions):
        if condition.get("type") == "event_not_completed" and "done_cell" in condition:
            source = condition.get("source")
            if source not in DONE_CELL_SOURCES_V4:
                fail("bad_done_cell_source", f"{where}[{i}]: source {source!r} not in {sorted(DONE_CELL_SOURCES_V4)}")


def _dialogue_flat_where(where: str, i: int) -> str:
    return f"{where}[{i}]"


def _check_dialogue_entries_v4(entries: Any, where: str, package: dict | None, text_package: dict | None) -> None:
    if not isinstance(entries, list):
        fail("text", f"{where}: dialogue is not a list")
    for i, entry in enumerate(entries):
        row_where = _dialogue_flat_where(where, i)
        if not isinstance(entry, dict):
            fail("text", f"{row_where}: not an object")
        if "text" in entry:
            fail("text", f"{row_where}: inline text key present")
        kind = entry.get("kind")
        if kind not in DIALOGUE_ENTRY_KINDS_V4:
            fail("text", f"{row_where}: kind {kind!r} not in {sorted(DIALOGUE_ENTRY_KINDS_V4)}")

        if entry.get("location_line") is not None and kind not in ("text", "name_insert"):
            fail("location_line_on_marker", f"{row_where}: location_line on a {kind!r} entry")

        if kind == "text":
            ref = entry.get("text_ref")
            if not isinstance(ref, dict):
                fail("text", f"{row_where}: text_ref missing")
            for key in ("entry", "at", "s", "raw_sha256"):
                if key not in ref:
                    fail("text", f"{row_where}: text_ref missing {key}")
            if package is not None:
                record = _package_record(package, ref.get("entry"), ref.get("at"), row_where)
                operands = record.get("operands") or []
                operand = operands[0] if operands else {}
                if not (operand.get("t") == "text" and operand.get("s") == ref.get("s")):
                    fail("text", f"{row_where}: package record at {ref.get('at')!r} does not carry t=text s={ref.get('s')!r}")
                if text_package is not None:
                    strings = text_package.get(ref.get("entry")) or []
                    s_index = ref.get("s")
                    if isinstance(s_index, int) and 0 <= s_index < len(strings):
                        _check_resolved_text(strings[s_index], f"{row_where}.text")
        elif kind == "name_insert":
            if "text_ref" in entry or "s" in entry:
                fail("text", f"{row_where}: name_insert carries text_ref or s")
            for key in ("entry", "at", "raw_sha256"):
                if key not in entry:
                    fail("text", f"{row_where}: name_insert missing {key}")
            if package is not None:
                record = _package_record(package, entry.get("entry"), entry.get("at"), row_where)
                if record.get("op") != "protagonist_name_insert":
                    fail("text", f"{row_where}: package record at {entry.get('at')!r} op is not protagonist_name_insert")
        # choice_point and scene_end carry no further per-entry shape rule
        # here: choice_point's `choice` reference and scene_end's flow rules
        # are checked over the whole document by _check_flow_v4.


def _collect_choice_targets_v4(document: dict) -> set:
    """Every valid `choice_point.choice` reference: `"top"` when the
    document itself carries a top-level `choice`, plus every result id
    (at any nesting depth) whose own `results[<id>]` carries a `choice`."""
    targets = set()
    if document.get("choice") is not None:
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

    walk(document.get("results"))
    return targets


def _check_choice_points_v4(entries: Any, valid_targets: set, where: str) -> None:
    if not isinstance(entries, list):
        return
    for i, entry in enumerate(entries):
        if isinstance(entry, dict) and entry.get("kind") == "choice_point":
            choice = entry.get("choice")
            if choice not in valid_targets:
                fail("choice_point_without_choice", f"{_dialogue_flat_where(where, i)}: choice {choice!r} names no existing choice")


def _count_scene_ends_v4(entries: Any) -> int:
    if not isinstance(entries, list):
        return 0
    return sum(1 for entry in entries if isinstance(entry, dict) and entry.get("kind") == "scene_end")


def _check_flow_v4(document: dict) -> None:
    """`choice_point` names an existing choice; a flow from the body through
    one result contains at most one `scene_end`; a result with
    `event_played: false` reaches no `scene_end`."""
    valid_targets = _collect_choice_targets_v4(document)
    _check_choice_points_v4(document.get("dialogue"), valid_targets, "dialogue")
    body_scene_ends = _count_scene_ends_v4(document.get("dialogue"))

    def walk(results, prefix_scene_ends: int, where: str) -> None:
        if not isinstance(results, dict):
            return
        for result_id, result in results.items():
            if not isinstance(result, dict):
                continue
            result_where = f"{where}[{result_id}]"
            own_dialogue = result.get("dialogue")
            _check_choice_points_v4(own_dialogue, valid_targets, f"{result_where}.dialogue")
            own_scene_ends = _count_scene_ends_v4(own_dialogue)
            if result.get("event_played") is False and own_scene_ends:
                fail("scene_end_in_skipped_result", f"{result_where}: event_played is false but dialogue has a scene_end")
            total = prefix_scene_ends + own_scene_ends
            if total > 1:
                fail("second_scene_end", f"{result_where}: flow carries {total} scene_end entries")
            walk(result.get("results"), total, f"{result_where}.results")

    walk(document.get("results"), body_scene_ends, "results")


def _check_effect_witnesses_v4(document: dict, where: str) -> None:
    witnesses = (document.get("evidence") or {}).get("effect_witnesses")
    if witnesses is None:
        return
    if not isinstance(witnesses, list):
        fail("witness_contradicts_effect", f"{where}: not a list")

    def find_in_results(results, result_id):
        if not isinstance(results, dict):
            return None
        result = results.get(result_id)
        if isinstance(result, dict):
            return result
        for candidate in results.values():
            if isinstance(candidate, dict):
                found = find_in_results(candidate.get("results"), result_id)
                if found is not None:
                    return found
        return None

    def find_effect_row(result_id, cell):
        # A witness's cell may sit in the body's `after` (shared by every
        # result) or in the named result's own `after`; either can hold the
        # effect row the witness supports.
        candidates = list(document.get("after") or [])
        if result_id not in (None, "body"):
            result = find_in_results(document.get("results"), result_id)
            if isinstance(result, dict):
                candidates += result.get("after") or []
        for row in candidates:
            if isinstance(row, dict) and _cell_key(row) == cell:
                return row
        return None

    for i, witness in enumerate(witnesses):
        row_where = f"{where}[{i}]"
        if not isinstance(witness, dict):
            fail("witness_contradicts_effect", f"{row_where}: not an object")
        basis = witness.get("basis")
        if basis not in WITNESS_BASIS_V4:
            fail("witness_contradicts_effect", f"{row_where}: basis {basis!r} not in {sorted(WITNESS_BASIS_V4)}")
        if not isinstance(witness.get("declared"), bool):
            fail("witness_contradicts_effect", f"{row_where}: declared is not a bool")
        for key in ("entry", "final"):
            if key not in witness:
                fail("witness_contradicts_effect", f"{row_where}: missing {key}")
        cell = witness.get("cell") or {}
        cell_key = (cell.get("storage"), cell.get("bank"), cell.get("index"))

        if basis == "shift_witness":
            for key in ("step", "shifted_entry", "shifted_final"):
                if key not in witness:
                    fail("witness_contradicts_effect", f"{row_where}: shift_witness missing {key}")
            effect_row = find_effect_row(witness.get("result"), cell_key)
            final = witness.get("final")
            shifted_final = witness.get("shifted_final")
            step = witness.get("step")
            if effect_row is not None and _is_int(final) and _is_int(shifted_final) and _is_int(step):
                if effect_row.get("type") == "add_legacy_value":
                    if shifted_final - final != step:
                        fail("witness_contradicts_effect", f"{row_where}: shifted_final - final != step for an add")
                elif effect_row.get("type") == "write_legacy_value":
                    if shifted_final != final:
                        fail("witness_contradicts_effect", f"{row_where}: shifted_final != final for a write")
        elif basis == "flag_pattern":
            if any(key in witness for key in ("step", "shifted_entry", "shifted_final")):
                fail("witness_contradicts_effect", f"{row_where}: flag_pattern carries step fields")


def _check_mes_ast_node_v5(node: Any, where: str) -> None:
    """One node of a `select` row's `mes_expression` ast: an `and`/`or`
    node with an `args` list of further nodes, or a `cell` leaf in the same
    vocabulary `_check_guard`'s conjuncts use (`storage`/`bank`/`index`/`op`
    in `CELL_COMPARISON_OP`/`value`). No new expression language: this is
    the guard's own tree shape, just nested instead of flat."""
    if not isinstance(node, dict):
        fail("bad_visit_select", f"{where}: not an object")
        return
    op = node.get("op")
    if op in ("and", "or"):
        args = node.get("args")
        if not isinstance(args, list):
            fail("bad_visit_select", f"{where}.args: missing or not a list")
            return
        for i, arg in enumerate(args):
            _check_mes_ast_node_v5(arg, f"{where}.args[{i}]")
        return
    if node.get("kind") == "cell":
        if not isinstance(node.get("storage"), str):
            fail("bad_visit_select", f"{where}: storage missing or not a string")
        for key in ("bank", "index", "value"):
            if not _is_int(node.get(key)):
                fail("bad_visit_select", f"{where}: {key} missing or not an integer")
        if node.get("op") not in CELL_COMPARISON_OP:
            fail("bad_visit_select", f"{where}: op {node.get('op')!r} not in the vocabulary")
        return
    fail("bad_visit_select", f"{where}: not in v4's condition vocabulary")


def _check_select_row_v5(row: Any, where: str) -> None:
    """A `select` row is one of v4's own two cell-test shapes: the plain
    equality row `results[].selected_by.conditions` uses (`storage`/`bank`/
    `index`/`operator`/`value`, `operator` `"equals"` - the counter cell's
    own value), or the `conditions[]`/guard `mes_expression` shape
    (`{"type": "mes_expression", "ast": {...}}` - the seed_writes cell's
    whole branch condition, `and`/`or` of `cell` leaves)."""
    if not isinstance(row, dict):
        fail("bad_visit_select", f"{where}: not an object")
        return
    if row.get("type") == "mes_expression":
        if not row.get("ast"):
            fail("bad_visit_select", f"{where}: mes_expression without ast")
        else:
            _check_mes_ast_node_v5(row["ast"], f"{where}.ast")
        return
    if "storage" in row:
        _check_cell_row(row, where, "bad_visit_select", with_operator=True)
        if row.get("operator") != "equals":
            fail("bad_visit_select", f"{where}: operator {row.get('operator')!r} is not 'equals'")
        return
    fail("bad_visit_select", f"{where}: not in v4's condition vocabulary")


def _check_visit_evidence_v5(evidence: Any, where: str) -> None:
    if not isinstance(evidence, dict):
        fail("visits", f"{where}: not an object")
        return
    for key in ("group", "profile_sha256", "route", "seed_basis"):
        if not isinstance(evidence.get(key), str) or not evidence.get(key):
            fail("visits", f"{where}: {key} missing or not a string")


def _check_visits_v5(visits: Any, where: str, package: dict | None, text_package: dict | None,
                      state_cells_table: dict, observed: dict) -> None:
    """The v5 `visits` list (WD-23): absent or empty is valid (a site
    without declared visits). Fails closed on an unknown `follows`, a cycle
    or forward reference (both ruled out by requiring `follows` to be
    `"reentry"`, `"first"`, or a `visit_id` already declared earlier in this
    same list), a duplicate `visit_id`, an empty `select`, a `select` row
    outside v4's condition vocabulary, more than one `repeats: true` in the
    chain, a visit whose dialogue does not carry exactly one `scene_end`,
    and every v4 dialogue/effect rule applied inside a visit (reusing
    `_check_dialogue_entries_v4`/`_check_effect_rows_v4` directly)."""
    if visits is None:
        return
    if not isinstance(visits, list):
        fail("visits", f"{where}: not a list")
        return
    declared_ids: set = set()
    repeats_seen = False
    for i, visit in enumerate(visits):
        vwhere = f"{where}[{i}]"
        if not isinstance(visit, dict):
            fail("visits", f"{vwhere}: not an object")
            continue

        visit_id = visit.get("visit_id")
        if not isinstance(visit_id, str) or not visit_id:
            fail("visits", f"{vwhere}: visit_id missing or not a string")
        elif visit_id in declared_ids:
            fail("duplicate_visit_id", f"{vwhere}: duplicate visit_id {visit_id!r}")

        follows = visit.get("follows")
        if follows not in VISIT_FOLLOWS_SPECIAL_V5 and follows not in declared_ids:
            fail("bad_visit_follows", f"{vwhere}: follows {follows!r} is not 'reentry', 'first', or an earlier visit_id (unknown, forward reference or cycle)")

        if isinstance(visit_id, str) and visit_id:
            declared_ids.add(visit_id)

        select = visit.get("select")
        if not isinstance(select, list) or not select:
            fail("empty_visit_select", f"{vwhere}.select: empty or not a list")
        else:
            for j, row in enumerate(select):
                _check_select_row_v5(row, f"{vwhere}.select[{j}]")

        dialogue = visit.get("dialogue")
        _check_dialogue_entries_v4(dialogue, f"{vwhere}.dialogue", package, text_package)
        scene_ends = _count_scene_ends_v4(dialogue)
        if scene_ends != 1:
            fail("bad_visit_scene_end", f"{vwhere}.dialogue: exactly one scene_end required, found {scene_ends}")

        _check_effect_rows_v4(visit.get("after", []), f"{vwhere}.after", state_cells_table, observed)

        repeats = visit.get("repeats")
        if not isinstance(repeats, bool):
            fail("visits", f"{vwhere}: repeats missing or not a bool")
        elif repeats:
            if repeats_seen:
                fail("duplicate_visit_repeats", f"{vwhere}: more than one repeats: true in this chain")
            repeats_seen = True

        _check_visit_evidence_v5(visit.get("evidence"), f"{vwhere}.evidence")


# ---------------------------------------------------------------------------
# kakyu_event_definition/v6 (EP-12 / WD, 2026-09-25): v5 plus an optional
# top-level `flow` block (a v14 analysis-group route's hop chain, carried as
# data the way v4 carries `after`). Every v5 rule above still applies to a v6
# document unchanged; a v6 document without `flow` behaves exactly as a v5
# document (including `visits`, still checked by `_check_visits_v5`). The
# functions below are the only new rule set, described in
# docs/spec/data/event_definition_v6.md.
# ---------------------------------------------------------------------------
SCHEMA_VERSION_V6 = "kakyu_event_definition/v6"
HOP_ENTERED_BY_KINDS_V6 = {"origin", "nested_call", "root_handoff", "resume"}
HOP_LEGACY_STORAGES_V6 = {"global_u8", "state_u16", "banked_u16"}
STATE_CONTEXT_KINDS_V6 = {"fresh", "original_calendar"}


def _check_flow_evidence_v6(evidence: Any, where: str) -> None:
    """`flow.evidence`: `{group, profile_sha256, route}`, the v14 profile and
    route this document projects from (`bad_flow_evidence` for a missing or
    non-string field)."""
    if not isinstance(evidence, dict):
        fail("bad_flow_evidence", f"{where}: not an object")
    for key in ("group", "profile_sha256", "route"):
        if not isinstance(evidence.get(key), str) or not evidence.get(key):
            fail("bad_flow_evidence", f"{where}: {key} missing or not a string")


def _check_flow_origin_v6(origin: Any, where: str) -> None:
    """`flow.origin`: `{entry, entry_sha256, offset, guard: {offset, end,
    false_target, record_sha256}}` - the flow's own origin guard record. Its
    conjuncts are the document's own top-level `guard`, checked by
    `_check_guard` already, so they are not repeated here. Malformed shape
    here is not one of v6's own named reasons; it reuses the generic `flow`
    reason the same way `_check_visits_v5` reuses `visits` for a malformed
    visit shape not covered by one of v5's own named reasons."""
    if not isinstance(origin, dict):
        fail("flow", f"{where}: not an object")
    if not isinstance(origin.get("entry"), str) or not origin.get("entry"):
        fail("flow", f"{where}: entry missing or not a string")
    if not isinstance(origin.get("entry_sha256"), str) or not origin.get("entry_sha256"):
        fail("flow", f"{where}: entry_sha256 missing or not a string")
    if not _is_int(origin.get("offset")):
        fail("flow", f"{where}: offset missing or not an integer")
    guard = origin.get("guard")
    if not isinstance(guard, dict):
        fail("flow", f"{where}.guard: not an object")
    for key in ("offset", "end", "false_target"):
        if not _is_int(guard.get(key)):
            fail("flow", f"{where}.guard: {key} missing or not an integer")
    if not isinstance(guard.get("record_sha256"), str) or not guard.get("record_sha256"):
        fail("flow", f"{where}.guard: record_sha256 missing or not a string")


def _check_state_context_v6(state_context: Any, where: str) -> None:
    """`flow.state_context`: `{"kind": "fresh"}` or `{"kind":
    "original_calendar", "entry": "START.MES", "table_sha256": <64 hex>}`
    (`bad_state_context`), the same shape v8/v6 analysis-group routes carry."""
    if not isinstance(state_context, dict) or state_context.get("kind") not in STATE_CONTEXT_KINDS_V6:
        fail("bad_state_context", f"{where}: kind not in {sorted(STATE_CONTEXT_KINDS_V6)}")
    if state_context.get("kind") == "original_calendar":
        if not isinstance(state_context.get("entry"), str) or not state_context.get("entry"):
            fail("bad_state_context", f"{where}: entry missing or not a string")
        if not isinstance(state_context.get("table_sha256"), str) or not state_context.get("table_sha256"):
            fail("bad_state_context", f"{where}: table_sha256 missing or not a string")


def _check_hop_entered_by_v6(entered_by: Any, is_first: bool, where: str) -> None:
    """A hop's own `entered_by`: `{kind, offset, end}`. `kind` is `origin`
    only for the first hop (and the first hop must be `origin`),
    `nested_call`, `root_handoff` or `resume` otherwise (`bad_hop_entered_by`
    for anything else, including `origin` on a later hop or a non-`origin`
    first hop)."""
    if not isinstance(entered_by, dict):
        fail("bad_hop_entered_by", f"{where}: not an object")
    kind = entered_by.get("kind")
    if kind not in HOP_ENTERED_BY_KINDS_V6:
        fail("bad_hop_entered_by", f"{where}: kind {kind!r} not in {sorted(HOP_ENTERED_BY_KINDS_V6)}")
    if is_first and kind != "origin":
        fail("bad_hop_entered_by", f"{where}: the flow's first hop must be entered_by kind 'origin'")
    if not is_first and kind == "origin":
        fail("bad_hop_entered_by", f"{where}: only the flow's first hop may be entered_by kind 'origin'")
    for key in ("offset", "end"):
        if not _is_int(entered_by.get(key)):
            fail("bad_hop_entered_by", f"{where}: {key} missing or not an integer")


def _check_hop_answers_v6(answers: Any, where: str) -> None:
    """A hop's own `answers`: rows `{boundary_offset, result_value}`,
    `result_value` an integer (`bad_hop_answer`)."""
    if not isinstance(answers, list):
        fail("bad_hop_answer", f"{where}: not a list")
    for i, row in enumerate(answers):
        row_where = f"{where}[{i}]"
        if not isinstance(row, dict) or not _is_int(row.get("boundary_offset")) or not _is_int(row.get("result_value")):
            fail("bad_hop_answer", f"{row_where}: malformed")


def _check_hop_gates_v6(gates: Any, earlier_hop_ids: set, where: str) -> None:
    """A hop's own `gates`: rows `{storage, bank, index, value, basis}`,
    `storage` one of v4's legacy storages; `basis` is `"tool_seeded"` or
    `{"written_by": <an earlier hop_id>}` (`bad_gate_basis` for anything
    else, including a later or unknown hop)."""
    if not isinstance(gates, list):
        fail("bad_gate_basis", f"{where}: not a list")
    for i, row in enumerate(gates):
        row_where = f"{where}[{i}]"
        if not isinstance(row, dict) or row.get("storage") not in HOP_LEGACY_STORAGES_V6:
            fail("bad_gate_basis", f"{row_where}: storage missing or not one of v4's legacy storages")
        for key in ("bank", "index", "value"):
            if not _is_int(row.get(key)):
                fail("bad_gate_basis", f"{row_where}: {key} missing or not an integer")
        basis = row.get("basis")
        if basis == "tool_seeded":
            continue
        if isinstance(basis, dict) and set(basis.keys()) == {"written_by"} and basis.get("written_by") in earlier_hop_ids:
            continue
        fail("bad_gate_basis", f"{row_where}: basis is not 'tool_seeded' or a written_by naming an earlier hop")


def _check_hop_map_locations_v6(rows: Any, where: str) -> None:
    """A hop's own `map_locations`: rows `{entry, poll_offset, values:
    [ints]}` (`bad_map_location`)."""
    if not isinstance(rows, list):
        fail("bad_map_location", f"{where}: not a list")
    for i, row in enumerate(rows):
        row_where = f"{where}[{i}]"
        if not isinstance(row, dict) or not isinstance(row.get("entry"), str) or not row.get("entry"):
            fail("bad_map_location", f"{row_where}: entry missing or not a string")
        if not _is_int(row.get("poll_offset")):
            fail("bad_map_location", f"{row_where}: poll_offset missing or not an integer")
        values = row.get("values")
        if not isinstance(values, list) or not all(_is_int(v) for v in values):
            fail("bad_map_location", f"{row_where}: values missing or not a list of integers")


def _check_hop_poll_supplies_v6(rows: Any, where: str) -> None:
    """A hop's own `poll_supplies`: rows `{definition, entry, poll_offset,
    result_storage, result_index, value}` (`bad_poll_supply`)."""
    if not isinstance(rows, list):
        fail("bad_poll_supply", f"{where}: not a list")
    for i, row in enumerate(rows):
        row_where = f"{where}[{i}]"
        if not isinstance(row, dict):
            fail("bad_poll_supply", f"{row_where}: not an object")
        if not _is_int(row.get("definition")):
            fail("bad_poll_supply", f"{row_where}: definition missing or not an integer")
        if not isinstance(row.get("entry"), str) or not row.get("entry"):
            fail("bad_poll_supply", f"{row_where}: entry missing or not a string")
        if not _is_int(row.get("poll_offset")):
            fail("bad_poll_supply", f"{row_where}: poll_offset missing or not an integer")
        if row.get("result_storage") not in HOP_LEGACY_STORAGES_V6:
            fail("bad_poll_supply", f"{row_where}: result_storage missing or not one of v4's legacy storages")
        if not _is_int(row.get("result_index")):
            fail("bad_poll_supply", f"{row_where}: result_index missing or not an integer")
        if not _is_int(row.get("value")):
            fail("bad_poll_supply", f"{row_where}: value missing or not an integer")


def _check_hop_dialogue_v6(entries: Any, where: str, package: dict | None, text_package: dict | None) -> None:
    """A hop's own `dialogue`: v4's entry form (`text`/`name_insert`
    through `text_ref`, `location_line` allowed), reusing
    `_check_dialogue_entries_v4` unchanged; no `scene_end` (`hop_scene_end`)
    and no `choice_point` (`hop_choice_point`) inside a hop; may be empty."""
    _check_dialogue_entries_v4(entries, where, package, text_package)
    for i, entry in enumerate(entries or []):
        if not isinstance(entry, dict):
            continue
        if entry.get("kind") == "scene_end":
            fail("hop_scene_end", f"{where}[{i}]: scene_end is not allowed inside a hop")
        if entry.get("kind") == "choice_point":
            fail("hop_choice_point", f"{where}[{i}]: choice_point is not allowed inside a hop")


def _check_flow_hops_v6(hops: Any, package: dict | None, text_package: dict | None,
                         state_cells_table: dict, observed: dict) -> list:
    """The flow's own `hops`: a non-empty list (`flow_without_hops`), each
    hop's own `hop_id` unique in the list (`duplicate_hop_id`), its own
    `entered_by`/`answers`/`gates`/`map_locations`/`poll_supplies`/
    `dialogue`/`after` checked by the functions above, and its own
    `message_count` equal to the number of `text`/`name_insert` entries of
    its own `dialogue` (`hop_message_count`) - checked on entry count alone,
    the way a tracked (unresolved) document is checked."""
    if not isinstance(hops, list) or not hops:
        fail("flow_without_hops", "flow.hops: missing, not a list, or empty")
    seen_ids: set = set()
    for index, hop in enumerate(hops):
        where = f"flow.hops[{index}]"
        if not isinstance(hop, dict):
            fail("flow", f"{where}: not an object")
        hop_id = hop.get("hop_id")
        if not isinstance(hop_id, str) or not hop_id:
            fail("flow", f"{where}.hop_id: missing or not a string")
        if hop_id in seen_ids:
            fail("duplicate_hop_id", f"{where}: duplicate hop_id {hop_id!r}")
        _check_hop_entered_by_v6(hop.get("entered_by"), index == 0, f"{where}.entered_by")
        _check_hop_answers_v6(hop.get("answers", []), f"{where}.answers")
        _check_hop_gates_v6(hop.get("gates", []), seen_ids, f"{where}.gates")
        _check_hop_map_locations_v6(hop.get("map_locations", []), f"{where}.map_locations")
        _check_hop_poll_supplies_v6(hop.get("poll_supplies", []), f"{where}.poll_supplies")
        dialogue = hop.get("dialogue", [])
        _check_hop_dialogue_v6(dialogue, f"{where}.dialogue", package, text_package)
        _check_effect_rows_v4(hop.get("after", []), f"{where}.after", state_cells_table, observed)
        text_count = sum(1 for e in (dialogue or []) if isinstance(e, dict) and e.get("kind") in ("text", "name_insert"))
        if hop.get("message_count") != text_count:
            fail("hop_message_count", f"{where}.message_count: {hop.get('message_count')!r} != {text_count}")
        seen_ids.add(hop_id)
    return hops


def _check_flow_block_v6(flow: Any, document: dict, package: dict | None, text_package: dict | None,
                          state_cells_table: dict, observed: dict) -> list:
    """The whole `flow` block: `evidence`, `origin`, `state_context`,
    `hops`, and `terminal` naming one entry of the document's own
    `terminals` (`bad_flow_terminal`)."""
    if not isinstance(flow, dict):
        fail("flow", "flow: not an object")
    _check_flow_evidence_v6(flow.get("evidence"), "flow.evidence")
    _check_flow_origin_v6(flow.get("origin"), "flow.origin")
    _check_state_context_v6(flow.get("state_context", {}), "flow.state_context")
    hops = _check_flow_hops_v6(flow.get("hops"), package, text_package, state_cells_table, observed)
    terminal = flow.get("terminal")
    terminals = document.get("terminals")
    if not isinstance(terminal, str) or not isinstance(terminals, dict) or terminal not in terminals:
        fail("bad_flow_terminal", "flow.terminal must name an entry of the document's own terminals")
    return hops


def _check_flow_dialogue_v6(entries: Any, hops: list, where: str, package: dict | None, text_package: dict | None) -> None:
    """The document's own top-level `dialogue` when `flow` is present:
    exactly, for each hop in order, one marker `{"kind": "hop", "hop_id":
    <id>}` followed by that hop's own `dialogue` entries verbatim, then
    exactly one `{"kind": "scene_end"}` and nothing else
    (`hop_marker_mismatch` for any marker, interleaved-entry, or
    trailing-scene_end mismatch - folding what the design draft called out
    as a `bad_scene_end`-shaped case into this one reason, since v4/v5 name
    no such reason and the rule is the same interleaving-shape check either
    way). The underlying `text`/`name_insert` entries are still checked by
    `_check_dialogue_entries_v4` for package resolution and text encoding."""
    if not isinstance(entries, list):
        fail("hop_marker_mismatch", f"{where}: dialogue is not a list")
    pos = 0
    n = len(entries)
    for hop in hops:
        hop_id = hop.get("hop_id")
        if pos >= n or entries[pos] != {"kind": "hop", "hop_id": hop_id}:
            fail("hop_marker_mismatch", f"{where}[{pos}]: expected a hop marker for {hop_id!r}")
        pos += 1
        for own_entry in hop.get("dialogue") or []:
            if pos >= n or entries[pos] != own_entry:
                fail("hop_marker_mismatch", f"{where}[{pos}]: does not match hop {hop_id!r}'s own dialogue verbatim")
            pos += 1
    if pos != n - 1 or entries[pos] != {"kind": "scene_end"}:
        fail("hop_marker_mismatch", f"{where}: exactly one trailing scene_end is expected after every hop")
    _check_dialogue_entries_v4(
        [e for e in entries if not (isinstance(e, dict) and e.get("kind") == "hop")],
        where, package, text_package,
    )


def _check_top_level_dialogue_v6(entries: Any, flow: dict | None, hops: list | None,
                                  package: dict | None, text_package: dict | None) -> None:
    """Dispatches the document's own top-level `dialogue` check: v4's own
    rule when `flow` is absent, except that a stray `{"kind": "hop"}` marker
    fails closed with `hop_marker_outside_flow` (the `hop` marker is a new
    dialogue entry kind allowed only in a flow document's top-level list);
    `_check_flow_dialogue_v6`'s own interleaving-shape rule when `flow` is
    present."""
    if flow is None:
        if isinstance(entries, list):
            for i, entry in enumerate(entries):
                if isinstance(entry, dict) and entry.get("kind") == "hop":
                    fail("hop_marker_outside_flow", f"dialogue[{i}]: hop marker outside a flow document")
        _check_dialogue_entries_v4(entries, "dialogue", package, text_package)
        return
    _check_flow_dialogue_v6(entries, hops or [], "dialogue", package, text_package)


def _check_flow_results_v6(document: dict, flow: dict) -> None:
    """`results` holds exactly `result_default` with `selected_by.kind ==
    "default"`, `event_played: true`, `dialogue: []` (the flow's own lines
    live in the top-level list), and `terminal == flow.terminal`
    (`bad_flow_terminal` when the terminal disagrees; the generic `results`
    reason otherwise - the same reason the rest of this shape's own checks
    already use for a malformed `results` map)."""
    results = document.get("results")
    if not isinstance(results, dict) or set(results.keys()) != {"result_default"}:
        fail("results", "a flow document's results must hold exactly result_default")
    result = results["result_default"]
    selected_by = result.get("selected_by") if isinstance(result, dict) else None
    if not isinstance(selected_by, dict) or selected_by.get("kind") != "default":
        fail("results", "a flow document's result_default.selected_by.kind must be 'default'")
    if not isinstance(result, dict) or result.get("event_played") is not True:
        fail("results", "a flow document's result_default.event_played must be true")
    if result.get("dialogue"):
        fail("results", "a flow document's result_default.dialogue must be empty")
    if result.get("terminal") != flow.get("terminal"):
        fail("bad_flow_terminal", "a flow document's result_default.terminal must equal flow.terminal")


# ---------------------------------------------------------------------------
# kakyu_event_definition/v7 (WD-21 U2 C3): v6 plus exactly one rule, the
# shape of `presentation.resources` - the media the document's measured route
# reaches, each item `{entry, source_offset, kind, name}` in the vocabulary
# and normalization of the package's `media_inventory`. Every v6 rule above
# applies to a v7 document unchanged (a flow, `visits`, text resolution, ...);
# `_check_presentation_v7` is the only new rule set, described in
# docs/spec/data/event_definition_v7.md. v3 to v6 never looked inside
# `presentation`, and still do not.
# ---------------------------------------------------------------------------
SCHEMA_VERSION_V7 = "kakyu_event_definition/v7"
PRESENTATION_STATUS_V7 = "deferred"
RESOURCE_KEYS_V7 = ("entry", "source_offset", "kind", "name")
# The vocabulary and the schema id are the package inventory's own
# (`payload_values`, shared with the register writer and the v7 projector).
RESOURCE_KINDS_V7 = frozenset(MEDIA_KINDS)
KNOWN_MEDIA_INVENTORY_SCHEMAS_V7 = frozenset({MEDIA_INVENTORY_SCHEMA})


def _check_resource_item_v7(item: Any, where: str) -> tuple:
    """One `presentation.resources` item: exactly `{entry, source_offset, kind,
    name}`, `entry` a safe leaf (the catalog's rule, `payload_values.is_safe_leaf`),
    `source_offset` an integer >= 0, `kind` in the inventory's vocabulary, `name`
    upper-case, non-empty and a safe leaf too (the promoter maps it to a catalog
    item's `entry`, which the catalog refuses otherwise). Returns the sort key
    `(entry, source_offset, kind, name)`."""
    if not isinstance(item, dict):
        fail("bad_resource_item", f"{where}: not an object")
    keys = set(item.keys())
    missing = [key for key in RESOURCE_KEYS_V7 if key not in keys]
    if missing:
        fail("bad_resource_item", f"{where}: missing {missing}")
    extra = sorted(keys - set(RESOURCE_KEYS_V7))
    if extra:
        fail("bad_resource_item", f"{where}: unexpected {extra}")
    if not is_safe_leaf(item["entry"]):
        fail("bad_resource_entry", f"{where}: entry {item['entry']!r} is not a safe leaf name")
    if not _is_int(item["source_offset"]) or item["source_offset"] < 0:
        fail("bad_resource_offset", f"{where}: source_offset {item['source_offset']!r} is not an integer >= 0")
    if not isinstance(item["kind"], str) or item["kind"] not in RESOURCE_KINDS_V7:
        fail("bad_resource_kind", f"{where}: kind {item['kind']!r} not in {sorted(RESOURCE_KINDS_V7)}")
    name = item["name"]
    if not isinstance(name, str) or name == "":
        fail("bad_resource_name", f"{where}: name {name!r} is not a non-empty string")
    if name != name.upper():
        fail("bad_resource_name", f"{where}: name {name!r} is not upper-case")
    if not is_safe_leaf(name):
        fail("bad_resource_name", f"{where}: name {name!r} is not a safe leaf name")
    return (item["entry"], item["source_offset"], item["kind"], name)


def _package_entry_names(manifest: dict) -> set:
    """The package manifest's member entry names (`entries[]`; `members` is the
    older spelling `_validate_v4_family`'s own binding check also accepts)."""
    rows = manifest.get("entries", manifest.get("members", []))
    return {row.get("entry") for row in rows if isinstance(row, dict)} if isinstance(rows, list) else set()


def _inventory_occurrences_v7(manifest: dict, entries: set) -> dict:
    """`{entry: {(at, kind, name), ...}}` for the named entries, from the
    manifest's `media_inventory.members` (a list of `{entry, occurrences:
    [{at, kind, name, evidence?}]}`; a member with no row has no occurrences).
    Refuses (`unknown_media_inventory`) a manifest whose block is absent, is not
    an object, carries a schema id this validator does not know, or whose
    `members` is not that list."""
    inventory = manifest.get("media_inventory")
    if not isinstance(inventory, dict):
        fail("unknown_media_inventory", "the bound package carries no media_inventory block")
    if inventory.get("schema") not in KNOWN_MEDIA_INVENTORY_SCHEMAS_V7:
        fail(
            "unknown_media_inventory",
            f"media_inventory.schema {inventory.get('schema')!r} not in {sorted(KNOWN_MEDIA_INVENTORY_SCHEMAS_V7)}",
        )
    members = inventory.get("members")
    if not isinstance(members, list):
        fail("unknown_media_inventory", "media_inventory.members is not a list")
    found: dict = {entry: set() for entry in entries}
    for position, row in enumerate(members):
        if not isinstance(row, dict) or not isinstance(row.get("entry"), str) or not isinstance(row.get("occurrences"), list):
            fail("unknown_media_inventory", f"media_inventory.members[{position}] is not {{entry, occurrences}}")
        if row["entry"] not in found:
            continue
        for occurrence in row["occurrences"]:
            if isinstance(occurrence, dict):
                found[row["entry"]].add((occurrence.get("at"), occurrence.get("kind"), occurrence.get("name")))
    return found


def _check_presentation_v7(presentation: Any, where: str, package: dict | None) -> None:
    """`presentation` of a v7 document: exactly `{status, resources}`, `status`
    the literal `"deferred"` (media extraction stays deferred), `resources` a list
    of items (see `_check_resource_item_v7`) sorted by `(entry, source_offset,
    kind, name)` with no duplicate; `[]` is allowed (a route that reaches none).
    With `--package`, every item's `entry` is one of the bound package's
    `entries[]` and the item is an occurrence of the package's `media_inventory`."""
    if not isinstance(presentation, dict):
        fail("bad_presentation", f"{where}: not an object")
    if set(presentation.keys()) != {"status", "resources"}:
        fail("bad_presentation", f"{where}: keys {sorted(presentation.keys())} are not exactly ['resources', 'status']")
    if presentation.get("status") != PRESENTATION_STATUS_V7:
        fail("bad_presentation", f"{where}.status {presentation.get('status')!r} is not {PRESENTATION_STATUS_V7!r}")
    resources = presentation.get("resources")
    if not isinstance(resources, list):
        fail("bad_presentation", f"{where}.resources: not a list")
    keys = [_check_resource_item_v7(item, f"{where}.resources[{i}]") for i, item in enumerate(resources)]
    for i in range(1, len(keys)):
        if keys[i] == keys[i - 1]:
            fail("duplicate_resource", f"{where}.resources[{i}] repeats resources[{i - 1}]")
        if keys[i] < keys[i - 1]:
            fail("unsorted_resources", f"{where}.resources[{i}] sorts before resources[{i - 1}]")
    if package is None or not keys:
        return
    manifest = package.get("__manifest__", {})
    entries = {key[0] for key in keys}
    occurrences = _inventory_occurrences_v7(manifest, entries)
    package_entries = _package_entry_names(manifest)
    for i, (entry, at, kind, name) in enumerate(keys):
        if entry not in package_entries:
            fail("resource_entry_not_in_package", f"{where}.resources[{i}]: entry {entry!r} is not an entry of the bound package")
        if (at, kind, name) not in occurrences[entry]:
            fail(
                "resource_not_in_inventory",
                f"{where}.resources[{i}]: {kind} {name!r} at {entry}:{at} is not an occurrence of the bound package's media_inventory",
            )


def _validate_v4_family(
    document: dict,
    *,
    schema_version: str,
    fingerprint: str | None = None,
    allow_unrecorded: bool = False,
    names_registry: dict | None = None,
    expected_names_fingerprint: str | None = None,
    package: dict | None = None,
    state_cells_table: dict | None = None,
) -> dict:
    """The v4 body, shared by `validate_v4` (unchanged behaviour, `visits`
    never checked) and `validate_v5` (the same body plus `_check_visits_v5`
    at the end, gated on `schema_version == SCHEMA_VERSION_V5` so a v4
    document's own behaviour cannot change)."""
    try:
        if document.get("schema_version") != schema_version:
            fail("schema", f"schema_version {document.get('schema_version')!r} != {schema_version!r}")

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

        names_fp = document.get("names_fingerprint")
        if not names_fp:
            fail("names", "names_fingerprint missing")
        if names_registry is not None:
            expected_names_fp = (
                expected_names_fingerprint if expected_names_fingerprint is not None else names_registry.get("fingerprint")
            )
            effective_names_fp = expected_names_fp if names_fp == "self" else names_fp
            if effective_names_fp != expected_names_fp:
                fail("names", f"names_fingerprint {names_fp!r} != registry fingerprint")

        doc_id = document.get("id")
        if not isinstance(doc_id, str) or not ID_RE.match(doc_id):
            fail("id", f"id {doc_id!r} does not match the id pattern")

        if names_registry is not None and doc_id not in names_registry.get("ids", set()):
            fail("names", f"id {doc_id!r} not in the registry")

        kind = document.get("kind")
        if kind not in KIND_VALUES:
            fail("kind", f"kind {kind!r} not in {sorted(KIND_VALUES)}")
        has_choice = "choice" in document and document.get("choice") is not None
        if kind == "choice_event" and not has_choice:
            fail("kind", "choice_event without choice")
        if kind == "event" and has_choice:
            fail("kind", "event with choice")

        for field in REQUIRED_TOP_LEVEL:
            if field not in document:
                fail("required", f"required field {field!r} missing")

        evidence = document.get("evidence")
        if not isinstance(evidence, dict) or evidence.get("kind") not in EVIDENCE_KINDS:
            fail("evidence", f"evidence.kind {evidence.get('kind') if isinstance(evidence, dict) else evidence!r} not in the vocabulary")
        members = evidence.get("members")
        if not isinstance(members, list):
            fail("evidence", "evidence.members missing or not a list")
        for i, member in enumerate(members):
            if not isinstance(member, dict) or "entry" not in member or "entry_sha256" not in member:
                fail("evidence", f"evidence.members[{i}] malformed")

        package_binding = document.get("package_binding")
        if not isinstance(package_binding, dict) or package_binding.get("schema") != PACKAGE_SCHEMA:
            fail("package", f"package_binding.schema {package_binding.get('schema') if isinstance(package_binding, dict) else package_binding!r} != {PACKAGE_SCHEMA!r}")
        text_package = None
        if package is not None:
            manifest = package.get("__manifest__", {})
            if package_binding.get("package_sha256") != manifest.get("package_sha256"):
                fail("package", "package_binding.package_sha256 != manifest.package_sha256")
            manifest_members = {
                m.get("entry"): m.get("entry_sha256")
                for m in manifest.get("entries", manifest.get("members", []))
            }
            for i, member in enumerate(members):
                entry = member.get("entry")
                if entry in manifest_members and manifest_members[entry] != member.get("entry_sha256"):
                    fail("package", f"evidence.members[{i}] entry_sha256 != the manifest's")
            text_package = package.get("__text__")

        _check_trigger_v4(document.get("trigger"))
        _check_scenes(document.get("scenes"), "scenes")
        if document.get("guard") is not None:
            _check_guard(document.get("guard"), "guard")
        _check_conditions_v4(document.get("conditions"), "conditions")

        for i, preset in enumerate(document.get("presets") or []):
            if not isinstance(preset, dict):
                fail("presets", f"presets[{i}]: not an object")
            _check_cell_rows(preset.get("writes", []), f"presets[{i}].writes", "presets")

        state_cells_table = state_cells_table if state_cells_table is not None else state_cells.load()
        observed = _collect_observed_values(document)

        _check_effect_rows_v4(document.get("after"), "after", state_cells_table, observed)

        flow = document.get("flow") if schema_version in (SCHEMA_VERSION_V6, SCHEMA_VERSION_V7) else None
        flow_hops: list | None = None
        if flow is not None:
            if document.get("visits"):
                fail("flow_with_visits", "a flow document cannot also carry a non-empty visits list")
            flow_hops = _check_flow_block_v6(flow, document, package, text_package, state_cells_table, observed)

        if schema_version in (SCHEMA_VERSION_V6, SCHEMA_VERSION_V7):
            _check_top_level_dialogue_v6(document.get("dialogue"), flow, flow_hops, package, text_package)
        else:
            _check_dialogue_entries_v4(document.get("dialogue"), "dialogue", package, text_package)

        results_raw = document.get("results")
        results = results_raw if isinstance(results_raw, dict) else {}

        if has_choice:
            _check_choice(document.get("choice"), results, "choice")

        if not results:
            fail("results", "results: empty")

        terminals = document.get("terminals")

        def check_result_v4(result_id: str, result: Any, terminals_map: dict, results_map: dict, where: str) -> None:
            if not isinstance(result, dict):
                fail("results", f"{where}: not an object")
            selected_by = result.get("selected_by")
            if not isinstance(selected_by, dict) or selected_by.get("kind") not in SELECTED_BY_KINDS:
                fail("results", f"{where}: selected_by kind not in the vocabulary")
            if selected_by.get("kind") == "condition":
                _check_cell_rows(selected_by.get("conditions", []), f"{where}.selected_by.conditions", "results", with_operator=True)
            if not isinstance(result.get("event_played"), bool):
                fail("results", f"{where}: event_played is not a bool")
            terminal_id = result.get("terminal")
            if terminal_id not in terminals_map:
                fail("results", f"{where}: terminal {terminal_id!r} not in terminals")
            _check_dialogue_entries_v4(result.get("dialogue", []), f"{where}.dialogue", package, text_package)
            _check_effect_rows_v4(result.get("after", []), f"{where}.after", state_cells_table, observed)
            if "choice" in result and result.get("choice") is not None:
                nested_results = result.get("results") or {}
                _check_choice(result.get("choice"), nested_results, f"{where}.choice")
            if "results" in result and result.get("results") is not None:
                nested_results = result.get("results")
                if not isinstance(nested_results, dict) or not nested_results:
                    fail("results", f"{where}.results: empty")
                for nested_id, nested_result in nested_results.items():
                    check_result_v4(nested_id, nested_result, terminals_map, nested_results, f"{where}.results[{nested_id}]")

        for result_id, result in results.items():
            check_result_v4(result_id, result, terminals if isinstance(terminals, dict) else {}, results, f"results[{result_id}]")

        _check_terminals(terminals)
        _check_flow_v4(document)
        _check_effect_witnesses_v4(document, "evidence.effect_witnesses")

        if schema_version in (SCHEMA_VERSION_V5, SCHEMA_VERSION_V6, SCHEMA_VERSION_V7):
            _check_visits_v5(document.get("visits"), "visits", package, text_package, state_cells_table, observed)

        if schema_version in (SCHEMA_VERSION_V6, SCHEMA_VERSION_V7) and flow is not None:
            _check_flow_results_v6(document, flow)

        if schema_version == SCHEMA_VERSION_V7:
            _check_presentation_v7(document.get("presentation"), "presentation", package)

    except Fail as f:
        return {"ok": False, "reason": f.reason, "detail": f.detail}
    return {"ok": True, "reason": "ok", "detail": ""}


def validate_v4(
    document: dict,
    *,
    fingerprint: str | None = None,
    allow_unrecorded: bool = False,
    names_registry: dict | None = None,
    expected_names_fingerprint: str | None = None,
    package: dict | None = None,
    state_cells_table: dict | None = None,
) -> dict:
    return _validate_v4_family(
        document,
        schema_version=SCHEMA_VERSION_V4,
        fingerprint=fingerprint,
        allow_unrecorded=allow_unrecorded,
        names_registry=names_registry,
        expected_names_fingerprint=expected_names_fingerprint,
        package=package,
        state_cells_table=state_cells_table,
    )


def validate_v5(
    document: dict,
    *,
    fingerprint: str | None = None,
    allow_unrecorded: bool = False,
    names_registry: dict | None = None,
    expected_names_fingerprint: str | None = None,
    package: dict | None = None,
    state_cells_table: dict | None = None,
) -> dict:
    return _validate_v4_family(
        document,
        schema_version=SCHEMA_VERSION_V5,
        fingerprint=fingerprint,
        allow_unrecorded=allow_unrecorded,
        names_registry=names_registry,
        expected_names_fingerprint=expected_names_fingerprint,
        package=package,
        state_cells_table=state_cells_table,
    )


def validate_v6(
    document: dict,
    *,
    fingerprint: str | None = None,
    allow_unrecorded: bool = False,
    names_registry: dict | None = None,
    expected_names_fingerprint: str | None = None,
    package: dict | None = None,
    state_cells_table: dict | None = None,
) -> dict:
    return _validate_v4_family(
        document,
        schema_version=SCHEMA_VERSION_V6,
        fingerprint=fingerprint,
        allow_unrecorded=allow_unrecorded,
        names_registry=names_registry,
        expected_names_fingerprint=expected_names_fingerprint,
        package=package,
        state_cells_table=state_cells_table,
    )


def validate_v7(
    document: dict,
    *,
    fingerprint: str | None = None,
    allow_unrecorded: bool = False,
    names_registry: dict | None = None,
    expected_names_fingerprint: str | None = None,
    package: dict | None = None,
    state_cells_table: dict | None = None,
) -> dict:
    return _validate_v4_family(
        document,
        schema_version=SCHEMA_VERSION_V7,
        fingerprint=fingerprint,
        allow_unrecorded=allow_unrecorded,
        names_registry=names_registry,
        expected_names_fingerprint=expected_names_fingerprint,
        package=package,
        state_cells_table=state_cells_table,
    )


def validate(
    document: dict,
    *,
    fingerprint: str | None = None,
    allow_unrecorded: bool = False,
    names_registry: dict | None = None,
    expected_names_fingerprint: str | None = None,
    package: dict | None = None,
    state_cells_table: dict | None = None,
) -> dict:
    """Dispatches on `schema_version`: `kakyu_event_definition/v7` goes to
    the v7 path (v6 plus the `presentation.resources` rule),
    `kakyu_event_definition/v6` to the v6 path, `kakyu_event_definition/v5` to
    the v5 path, `kakyu_event_definition/v4` to the v4 path (all unchanged);
    every other value (including v3's own, and an unknown one) goes to the
    unchanged v3 path, exactly as before this dispatcher existed."""
    if document.get("schema_version") == SCHEMA_VERSION_V7:
        return validate_v7(
            document,
            fingerprint=fingerprint,
            allow_unrecorded=allow_unrecorded,
            names_registry=names_registry,
            expected_names_fingerprint=expected_names_fingerprint,
            package=package,
            state_cells_table=state_cells_table,
        )
    if document.get("schema_version") == SCHEMA_VERSION_V6:
        return validate_v6(
            document,
            fingerprint=fingerprint,
            allow_unrecorded=allow_unrecorded,
            names_registry=names_registry,
            expected_names_fingerprint=expected_names_fingerprint,
            package=package,
            state_cells_table=state_cells_table,
        )
    if document.get("schema_version") == SCHEMA_VERSION_V5:
        return validate_v5(
            document,
            fingerprint=fingerprint,
            allow_unrecorded=allow_unrecorded,
            names_registry=names_registry,
            expected_names_fingerprint=expected_names_fingerprint,
            package=package,
            state_cells_table=state_cells_table,
        )
    if document.get("schema_version") == SCHEMA_VERSION_V4:
        return validate_v4(
            document,
            fingerprint=fingerprint,
            allow_unrecorded=allow_unrecorded,
            names_registry=names_registry,
            expected_names_fingerprint=expected_names_fingerprint,
            package=package,
            state_cells_table=state_cells_table,
        )
    return _validate_v3(
        document,
        fingerprint=fingerprint,
        allow_unrecorded=allow_unrecorded,
        names_registry=names_registry,
        expected_names_fingerprint=expected_names_fingerprint,
        package=package,
    )


def load_names_registry(path: Path) -> dict:
    """Load the event name registry directory at `path`
    (`event_names.json` and `names_fingerprint`) into
    `{"fingerprint", "ids", "pairs"}`: `ids` the set of every row's `id`;
    `pairs` the set of every row's `(category, place)` (the mod event
    definition contract's `--names` trigger gate; unused by this module's
    own `validate`, which only reads `fingerprint` and `ids`). Factored out
    of `main` (mod event definition unit A) so both this module's `main`
    and `tools.validate_mod_event_definition`'s `main` load the registry
    the same way; behaviour for this module is unchanged."""
    registry_path = path / "event_names.json"
    fingerprint_path = path / "names_fingerprint"
    registry = json.loads(registry_path.read_text(encoding="utf-8")) if registry_path.is_file() else {}
    ids: set = set()
    pairs: set = set()
    if isinstance(registry, dict):
        rows = registry.get("events", registry.get("rows", []))
    else:
        rows = registry
    if isinstance(rows, list):
        for row in rows:
            if isinstance(row, dict) and "id" in row:
                ids.add(row["id"])
                if "category" in row and "place" in row:
                    pairs.add((row.get("category"), row.get("place")))
    elif isinstance(rows, dict):
        for key, row in rows.items():
            ids.add(row["id"] if isinstance(row, dict) and "id" in row else key)
            if isinstance(row, dict) and "category" in row and "place" in row:
                pairs.add((row.get("category"), row.get("place")))
    return {
        "fingerprint": fingerprint_path.read_text(encoding="utf-8").strip() if fingerprint_path.is_file() else "",
        "ids": ids,
        "pairs": pairs,
    }


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("document", type=Path)
    parser.add_argument("--names", type=Path, default=None, help="event name registry directory")
    parser.add_argument("--package", type=Path, default=None, help="playback package directory")
    parser.add_argument("--fingerprint", default=None, help="expected contract_fingerprint")
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

    package = _load_package(args.package) if args.package is not None else None

    fingerprint = args.fingerprint
    if fingerprint is None and document.get("schema_version") == SCHEMA_VERSION_V4:
        # --contract-fingerprint resolution reads the v4 directory for a v4
        # document (unit 2a): v3 keeps its own default of "no check" when
        # --fingerprint is omitted, unchanged.
        v4_fingerprint_path = ROOT / "config" / "contracts" / "event_definition_v4" / "contract_fingerprint"
        if v4_fingerprint_path.is_file():
            fingerprint = v4_fingerprint_path.read_text(encoding="utf-8").strip()
    if fingerprint is None and document.get("schema_version") == SCHEMA_VERSION_V5:
        # WD-23: the same auto-resolution, from the v5 directory beside v4.
        v5_fingerprint_path = ROOT / "config" / "contracts" / "event_definition_v5" / "contract_fingerprint"
        if v5_fingerprint_path.is_file():
            fingerprint = v5_fingerprint_path.read_text(encoding="utf-8").strip()
    if fingerprint is None and document.get("schema_version") == SCHEMA_VERSION_V6:
        # EP-12 / WD (2026-09-25): the same auto-resolution, from the v6
        # directory beside v5.
        v6_fingerprint_path = ROOT / "config" / "contracts" / "event_definition_v6" / "contract_fingerprint"
        if v6_fingerprint_path.is_file():
            fingerprint = v6_fingerprint_path.read_text(encoding="utf-8").strip()
    if fingerprint is None and document.get("schema_version") == SCHEMA_VERSION_V7:
        # WD-21 U2 C3: the same auto-resolution, from the v7 directory beside v6.
        v7_fingerprint_path = ROOT / "config" / "contracts" / "event_definition_v7" / "contract_fingerprint"
        if v7_fingerprint_path.is_file():
            fingerprint = v7_fingerprint_path.read_text(encoding="utf-8").strip()

    result = validate(
        document,
        fingerprint=fingerprint,
        allow_unrecorded=args.allow_unrecorded,
        names_registry=names_registry,
        package=package,
    )
    print(json.dumps(result))
    return 0 if result["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
