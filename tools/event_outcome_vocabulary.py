"""EP-09: the game-outcome vocabulary (owner ruling of 2026-09-20).

The event definitions, catalog and analysis-group profiles describe how a
route ends in the code's own terms - terminal ``kind`` values, catalog
``runtime_status`` values, profile ``caller_outcome.kind`` values. Nothing
here re-measures anything: the code-level terminal markers stay exactly as
they are, and this module derives one of five game outcomes from them, for
display to a user who does not know what a `root_handoff` is.

    from tools.event_outcome_vocabulary import v4_terminal_outcome, phrase
    record = v4_terminal_outcome(terminal)
    print(phrase(record))

Every function returns the same outcome record shape and never raises on a
well-formed dict; an unrecognized or missing shape comes back as
``unresolved`` with a reason instead of an exception:

    {"outcome": <one of GAME_OUTCOMES>, "postlude": "event"|"place"|"",
     "next_target": str, "map": <map label or "">, "reason": str}

See `analysis/_docs/ep09_outcome_vocab_spec.md` for the full rule table this
module implements (functions 1 to 9 below correspond to that spec's list).
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

GAME_OUTCOMES = ("map_return", "place_menu", "chain", "not_triggered", "unresolved")

MAP_ENTRIES = {
    "MACHI.MES": "town",
    "GROUND.MES": "campus",
    "TRAIN.MES": "train",
    "FLOOR1.MES": "school floor 1",
    "FLOOR2.MES": "school floor 2",
    "FLOOR3.MES": "school floor 3",
    "FLOOR4.MES": "school floor 4",
    "FLOOR5.MES": "school floor 5",
}


def _map_label(target: Any) -> str:
    """The map label for `target` (a `next_target`/`outcome.target` string),
    or empty when `target` is not one of the map entries."""
    return MAP_ENTRIES.get(str(target).upper(), "")


def _record(
    outcome: str,
    *,
    postlude: str = "",
    next_target: str = "",
    map_label: str = "",
    reason: str = "",
) -> dict[str, Any]:
    return {
        "outcome": outcome,
        "postlude": postlude,
        "next_target": next_target,
        "map": map_label,
        "reason": reason,
    }


def event_intro_index(v4_documents: list) -> dict:
    """`(CALLER_ENTRY_UPPER, offset) -> callee_entry` built from each v4
    document's `trigger.caller.entry` / `trigger.caller.offset` and
    `trigger.callee.entry` - the coordinate of that document's own intro
    dispatch. Owner ruling of 2026-09-23 (EP-03 step 2): a dependency stop
    that lands exactly on another event's intro dispatch continues into it."""
    index: dict = {}
    for document in v4_documents:
        if not isinstance(document, dict):
            continue
        trigger = document.get("trigger", {})
        if not isinstance(trigger, dict):
            continue
        caller = trigger.get("caller", {})
        callee = trigger.get("callee", {})
        if not isinstance(caller, dict) or not isinstance(callee, dict):
            continue
        entry = str(caller.get("entry", "")).upper()
        offset = caller.get("offset")
        callee_entry = str(callee.get("entry", ""))
        if entry and callee_entry and offset is not None:
            index[(entry, int(offset))] = callee_entry
    return index


def catalog_intro_index(events: list) -> dict:
    """`(CALLER_ENTRY_UPPER, dispatch_offset) -> callee_entry` built from
    each catalog row's `source.caller.entry` / `source.caller.dispatch_offset`
    and `source.callee.entry`."""
    index: dict = {}
    for event in events:
        if not isinstance(event, dict):
            continue
        source = event.get("source", {})
        if not isinstance(source, dict):
            continue
        caller = source.get("caller", {})
        callee = source.get("callee", {})
        if not isinstance(caller, dict) or not isinstance(callee, dict):
            continue
        entry = str(caller.get("entry", "")).upper()
        offset = caller.get("dispatch_offset")
        callee_entry = str(callee.get("entry", ""))
        if entry and callee_entry and offset is not None:
            index[(entry, int(offset))] = callee_entry
    return index


def v4_terminal_outcome(terminal: dict, intros: dict | None = None) -> dict:
    """A `terminals[...]` value of a v4 document (`kind`, `next_target`).
    `intros` (see `event_intro_index`) reclassifies a `dependency_stop`
    landing exactly on another event's intro dispatch as `chain`."""
    if not isinstance(terminal, dict):
        return _record("unresolved", reason="unknown_shape")
    kind = str(terminal.get("kind", ""))
    next_target = str(terminal.get("next_target", ""))
    label = _map_label(next_target)
    if kind == "root_handoff":
        if label:
            return _record("map_return", postlude="event", next_target=next_target, map_label=label)
        return _record("chain", next_target=next_target)
    if kind == "natural_handoff":
        if label:
            return _record("map_return", postlude="place", next_target=next_target, map_label=label)
        return _record("chain", next_target=next_target)
    if kind in ("def_selection_boundary", "caller_menu_loop"):
        return _record("place_menu")
    if kind == "dependency_stop":
        if intros:
            owner_entry = str(terminal.get("owner_entry", "")).upper()
            offset = terminal.get("offset")
            if offset is not None:
                callee_entry = intros.get((owner_entry, int(offset)))
                if callee_entry:
                    return _record("chain", next_target=callee_entry)
        return _record("unresolved", reason="dependency_stop")
    if kind == "callee_return":
        return _record("unresolved", reason="continuation_undeclared")
    return _record("unresolved", reason=f"unknown_kind:{kind}")


def v4_result_outcome(document: dict, result_id: str, intros: dict | None = None) -> dict:
    """The result's `terminal` id resolved in `document["terminals"]`, then
    `v4_terminal_outcome`."""
    results = document.get("results", {}) if isinstance(document, dict) else {}
    result = results.get(result_id) if isinstance(results, dict) else None
    if not isinstance(result, dict):
        return _record("unresolved", reason="terminal_missing")
    terminal_id = result.get("terminal")
    terminals = document.get("terminals", {}) if isinstance(document, dict) else {}
    terminal = terminals.get(terminal_id) if isinstance(terminals, dict) and terminal_id is not None else None
    if not isinstance(terminal, dict):
        return _record("unresolved", reason="terminal_missing")
    return v4_terminal_outcome(terminal, intros)


def v4_reentry_outcome(document: dict, result_id: str, intros: dict | None = None) -> dict:
    """The result's `reentry` block: no block -> `unresolved`, reason
    `reentry_undeclared`; `message_count == 0` -> `not_triggered`, reason
    `done_gate`; otherwise the route's own outcome from `v4_result_outcome`
    with an added key `"repeat": True`."""
    results = document.get("results", {}) if isinstance(document, dict) else {}
    result = results.get(result_id) if isinstance(results, dict) else None
    reentry = result.get("reentry") if isinstance(result, dict) else None
    if not isinstance(reentry, dict):
        return _record("unresolved", reason="reentry_undeclared")
    if reentry.get("message_count") == 0:
        return _record("not_triggered", reason="done_gate")
    record = dict(v4_result_outcome(document, result_id, intros))
    record["repeat"] = True
    return record


def _catalog_kind_outcome(terminal: dict) -> dict:
    """Per-`kind` rules shared by `catalog_route_outcome` (over the last
    terminal of a route) and `catalog_terminal_outcome` (over one matched
    terminal, which is always its own "last terminal")."""
    kind = str(terminal.get("kind", ""))
    next_target = str(terminal.get("next_target", ""))
    label = _map_label(next_target)
    if kind in ("caller_handoff", "root_replacement", "normal_completion"):
        if label:
            postlude = "place" if kind == "caller_handoff" else "event"
            return _record("map_return", postlude=postlude, next_target=next_target, map_label=label)
        if next_target:
            return _record("chain", next_target=next_target)
        return _record("unresolved", reason="target_missing")
    if kind == "analysis_boundary":
        status = str(terminal.get("runtime_status", ""))
        # `loop_boundary` is the catalog form of a profile's
        # `caller_menu_loop` resume (the place script's own input loop,
        # `promote_analysis_groups.TERMINAL_KIND_MAP`), which the v4 and
        # profile rules already read as `place_menu` (EP-03 step 2,
        # 2026-09-23: the catalog side now agrees).
        if status in ("def_selection_boundary", "loop_boundary"):
            return _record("place_menu")
        # Tool decision (owner ruling 2026-09-23, EP-03 step 2): a
        # script_dispatch_boundary terminal already carrying a next_target
        # (written only when it is exactly another catalog event's intro
        # dispatch - see `event_intro_index`/`catalog_intro_index`) continues
        # into that event. No index lookup here: the promotion tool is the
        # only writer of this next_target, so its mere presence is the rule.
        if status == "script_dispatch_boundary" and next_target:
            return _record("chain", next_target=next_target)
        return _record("unresolved", reason=status)
    if kind == "rejection_return":
        return _record("not_triggered", reason="rejection_return")
    if kind == "early_return":
        if label:
            return _record("map_return", postlude="event", next_target=next_target, map_label=label)
        return _record("unresolved", reason="early_end")
    if kind in ("callee_return_only", "caller_postlude"):
        return _record("unresolved", reason="continuation_undeclared")
    if kind in ("prefix_end", "unresolved_host_handoff"):
        return _record("unresolved", reason=kind)
    return _record("unresolved", reason=f"unknown_kind:{kind}")


def catalog_route_outcome(terminals: list) -> dict:
    """A catalog row's `terminals` (fields `kind`, `outcome`,
    `runtime_status`, `next_target`, `sequence`): order by `sequence`, take
    the last, then the per-kind rules of `_catalog_kind_outcome`."""
    if not terminals:
        return _record("unresolved", reason="terminals_missing")
    ordered = sorted(terminals, key=lambda terminal: int(terminal.get("sequence", 0)) if isinstance(terminal, dict) else 0)
    last = ordered[-1]
    if not isinstance(last, dict):
        return _record("unresolved", reason="unknown_shape")
    return _catalog_kind_outcome(last)


def catalog_terminal_outcome(terminal: dict) -> dict:
    """One matched terminal (the Event Player's `_catalog_terminal_match`
    shape: `kind`, `next_target`, `runtime_status`)."""
    if not isinstance(terminal, dict):
        return _record("unresolved", reason="unknown_shape")
    return _catalog_kind_outcome(terminal)


def matched_terminal_outcome(terminal: dict, row_terminals: list) -> dict:
    """The outcome the Event Player phrases for the one terminal a run matched
    (EP-12 gallery, 2026-10-04, tool decision). Ordinarily that is
    `catalog_terminal_outcome(terminal)`; a `callee_return_only` terminal is the
    callee's own return, which that rule reads as an undeclared continuation,
    but a row that also declares where the flow goes next (its later terminals:
    the menu loop of an album scene, the caller's handoff) has a decided
    `catalog_route_outcome` - then the row's route outcome is the phrase. A row
    whose route outcome is itself `unresolved` keeps the terminal's own reading.
    Port: `KakyuEventOutcomeVocabulary.matched_terminal_outcome`."""
    if isinstance(terminal, dict) and terminal.get("kind") == "callee_return_only":
        route_outcome = catalog_route_outcome(row_terminals)
        if route_outcome["outcome"] != "unresolved":
            return route_outcome
    return catalog_terminal_outcome(terminal)


def profile_route_outcome(route: dict, intros: dict | None = None) -> dict:
    """An analysis-group profile route (`caller_outcome.kind`,
    `outcome{status,target}`, `resume{boundary_policy, outcome{target}}`).
    `intros` (see `event_intro_index`) reclassifies a
    `stop_before_unprovided_dependency` resume landing exactly on another
    event's intro dispatch as `chain`, keyed by
    `(route.caller.entry.upper(), route.resume.outcome.offset)`."""
    if not isinstance(route, dict):
        return _record("unresolved", reason="unknown_shape")
    if _is_flow_route(route):
        return flow_route_outcome(route)
    caller_outcome = route.get("caller_outcome", {})
    kind = str(caller_outcome.get("kind", "")) if isinstance(caller_outcome, dict) else ""
    if kind in ("root_handoff", "nested_root_handoff"):
        outcome_block = route.get("outcome", {})
        target = str(outcome_block.get("target", "")) if isinstance(outcome_block, dict) else ""
        label = _map_label(target)
        if label:
            return _record("map_return", postlude="event", next_target=target, map_label=label)
        return _record("chain", next_target=target)
    if kind == "dispatch":
        resume = route.get("resume")
        if not isinstance(resume, dict):
            return _record("unresolved", reason="continuation_undeclared")
        policy = resume.get("boundary_policy")
        resume_outcome = resume.get("outcome", {})
        target = str(resume_outcome.get("target", "")) if isinstance(resume_outcome, dict) else ""
        if policy == "natural_handoff":
            label = _map_label(target)
            if label:
                return _record("map_return", postlude="place", next_target=target, map_label=label)
            return _record("chain", next_target=target)
        if policy in ("def_selection_boundary", "caller_menu_loop"):
            return _record("place_menu")
        if policy == "stop_before_unprovided_dependency":
            if intros:
                caller = route.get("caller", {})
                caller_entry = str(caller.get("entry", "")).upper() if isinstance(caller, dict) else ""
                stop_offset = resume_outcome.get("offset") if isinstance(resume_outcome, dict) else None
                if stop_offset is not None:
                    callee_entry = intros.get((caller_entry, int(stop_offset)))
                    if callee_entry:
                        return _record("chain", next_target=callee_entry)
            return _record("unresolved", reason="dependency_stop")
        if policy is None:
            label = _map_label(target)
            if label:
                return _record("map_return", postlude="place", next_target=target, map_label=label)
            return _record("unresolved", reason="continuation_undeclared")
        return _record("unresolved", reason=f"unknown_kind:{policy}")
    if kind == "blocked_definition":
        return _record("unresolved", reason="blocked_definition")
    return _record("unresolved", reason=f"unknown_kind:{kind}")


def _is_flow_route(route: dict) -> bool:
    """A `kakyu_event_analysis_group/v14` flow route: an `origin`, `hops` and
    one `terminal` instead of a caller/callee pair (EP-12, 2026-09-24)."""
    return isinstance(route.get("hops"), list) and isinstance(route.get("terminal"), dict) \
        and "caller_outcome" not in route


def flow_route_outcome(route: dict) -> dict:
    """A v14 flow route ends where its `terminal` record does: a
    `script_handoff_boundary` to a map is `map_return` (the flow is the
    event), to any other script `chain`; a plain return is `unresolved`
    (`flow_return`) until a flow declares what its origin does next - except
    a two-hop flow whose origin dispatches one callee that returns (an album
    scene), which is `place_menu`."""
    terminal = route.get("terminal", {})
    status = str(terminal.get("status", ""))
    target = str(terminal.get("target", ""))
    if status == "script_handoff_boundary" and target:
        label = _map_label(target)
        if label:
            return _record("map_return", postlude="event", next_target=target, map_label=label)
        return _record("chain", next_target=target)
    if status == "script_return":
        # EP-12 gallery (2026-10-04, tool decision): a two-hop flow whose
        # origin dispatches one callee (hop 0 ends in `script_dispatch_boundary`)
        # and whose callee (hop 1, `nested_call`) returns - an album scene. The
        # origin menu resumes into its own input loop (`caller_menu_loop`, the
        # same continuation the profile and catalog rules read as `place_menu`).
        # Any other returning flow keeps `flow_return`.
        hops = route.get("hops")
        if (isinstance(hops, list) and len(hops) == 2
                and _hop_outcome_status(hops[0]) == "script_dispatch_boundary"
                and isinstance(hops[1], dict) and hops[1].get("entered_by", {}).get("kind") == "nested_call"):
            return _record("place_menu")
        return _record("unresolved", reason="flow_return")
    return _record("unresolved", reason=f"unknown_kind:{status}")


def _hop_outcome_status(hop: Any) -> str:
    if not isinstance(hop, dict):
        return ""
    outcome = hop.get("expected", {}).get("outcome", {})
    return str(outcome.get("status", "")) if isinstance(outcome, dict) else ""


def profile_reentry_outcome(route: dict) -> dict:
    """A profile route's `reentry` block. A v14 flow has no reentry block -
    its origin guard decides each run - so it reports `unresolved`
    (`flow_reentry_undeclared`) rather than pretending a done-gate."""
    if not isinstance(route, dict):
        return _record("unresolved", reason="unknown_shape")
    if _is_flow_route(route):
        return _record("unresolved", reason="flow_reentry_undeclared")
    reentry = route.get("reentry")
    if not isinstance(reentry, dict):
        return _record("unresolved", reason="reentry_undeclared")
    outcome_block = reentry.get("outcome", {})
    outcome_block = outcome_block if isinstance(outcome_block, dict) else {}
    status = str(outcome_block.get("status", ""))
    if status == "script_return" and reentry.get("message_count") == 0:
        return _record("not_triggered", reason="done_gate")
    target = str(outcome_block.get("target", ""))
    label = _map_label(target)
    if label:
        return _record("map_return", postlude="event", next_target=target, map_label=label)
    if target:
        return _record("chain", next_target=target)
    return _record("unresolved", reason=status)


def phrase(record: dict) -> str:
    """The English UI phrase for an outcome record."""
    outcome = record.get("outcome")
    if outcome == "map_return":
        label = str(record.get("map", ""))
        if label == "town":
            base = "Back to the town map"
        elif label == "campus":
            base = "Back to the campus map"
        elif label == "train":
            base = "Back to the train"
        else:
            base = f"Back to {label}"
        if record.get("postlude") == "place":
            base += " after the place's own lines"
        return base
    if outcome == "place_menu":
        return "Back to the place menu"
    if outcome == "chain":
        return f"Continues into {record.get('next_target', '')}"
    if outcome == "not_triggered":
        return "Not triggered"
    return f"Unresolved: {record.get('reason', '')}"


def _load_json(path: Path) -> Any:
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def _load_v4_documents(v4_dir: Path) -> list[dict]:
    """Every v4 document under `v4_dir`, in file order (`index.json`
    excluded) - the one loader `_v4_records` and the CLI's intro-index
    construction share."""
    return [
        _load_json(path)
        for path in sorted(v4_dir.glob("*.json"))
        if path.name != "index.json"
    ]


def _v4_records(v4_dir: Path, intros: dict | None = None) -> tuple[list[dict], list[dict]]:
    results: list[dict] = []
    reentries: list[dict] = []
    for document in _load_v4_documents(v4_dir):
        for result_id in document.get("results", {}):
            results.append(v4_result_outcome(document, result_id, intros))
            reentries.append(v4_reentry_outcome(document, result_id, intros))
    return results, reentries


def _profile_records(profiles_dir: Path, intros: dict | None = None) -> tuple[list[dict], list[dict]]:
    routes: list[dict] = []
    reentries: list[dict] = []
    for path in sorted(profiles_dir.glob("*.json")):
        document = _load_json(path)
        for route in document.get("routes", []):
            routes.append(profile_route_outcome(route, intros))
            reentries.append(profile_reentry_outcome(route))
    return routes, reentries


def _catalog_rows(catalog_path: Path) -> list[dict]:
    """Every event dict from the tracked catalog, in its own order - the
    one loader `_catalog_records` and `catalog_outcomes_gdscript` share."""
    document = _load_json(catalog_path)
    return document.get("events", [])


def _catalog_records(catalog_path: Path) -> list[dict]:
    return [catalog_route_outcome(event.get("terminals", [])) for event in _catalog_rows(catalog_path)]


def _gdscript_string(value: str) -> str:
    escaped = value.replace("\\", "\\\\").replace('"', '\\"')
    return f'"{escaped}"'


def catalog_outcomes_gdscript(catalog_path: Path) -> str:
    """The `PYTHON_CATALOG_ROUTE_OUTCOMES` GDScript dictionary literal body
    (one row per tracked catalog event, keyed by `event_id`, in the
    catalog's own row order), for pasting into
    `tests/test_event_outcome_vocabulary.gd`."""
    lines = []
    for event in _catalog_rows(catalog_path):
        event_id = str(event.get("event_id", ""))
        record = catalog_route_outcome(event.get("terminals", []))
        fields = ", ".join(
            f"{_gdscript_string(key)}: {_gdscript_string(str(record.get(key, '')))}"
            for key in ("outcome", "postlude", "next_target", "map", "reason")
        )
        lines.append(f"\t{_gdscript_string(event_id)}: {{{fields}}},")
    return "\n".join(lines)


def _census(records: list[dict]) -> dict[str, int]:
    counts = {outcome: 0 for outcome in GAME_OUTCOMES}
    for record in records:
        counts[record["outcome"]] = counts.get(record["outcome"], 0) + 1
    return counts


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Census of the derived game outcomes over the tracked event data.")
    parser.add_argument("--v4-dir", type=Path, default=None)
    parser.add_argument("--profiles-dir", type=Path, default=None)
    parser.add_argument("--catalog", type=Path, default=None)
    parser.add_argument("--json", action="store_true")
    parser.add_argument(
        "--catalog-outcomes-gd",
        action="store_true",
        help=(
            "Print the PYTHON_CATALOG_ROUTE_OUTCOMES GDScript dictionary "
            "literal body for every row of --catalog, then exit."
        ),
    )
    args = parser.parse_args(argv)

    if args.catalog_outcomes_gd:
        if args.catalog is None:
            parser.error("--catalog-outcomes-gd requires --catalog")
        print(catalog_outcomes_gdscript(args.catalog))
        return 0

    sources: dict[str, list[dict]] = {}
    intros: dict | None = None
    if args.v4_dir is not None:
        intros = event_intro_index(_load_v4_documents(args.v4_dir))
        results, reentries = _v4_records(args.v4_dir, intros)
        sources["v4 results"] = results
        sources["v4 reentries"] = reentries
    if args.profiles_dir is not None:
        routes, reentries = _profile_records(args.profiles_dir, intros)
        sources["profile routes"] = routes
        sources["profile reentries"] = reentries
    if args.catalog is not None:
        sources["catalog rows"] = _catalog_records(args.catalog)

    census = {source: _census(records) for source, records in sources.items()}

    if args.json:
        print(json.dumps(census, indent=2, sort_keys=True))
        return 0

    header = ["outcome"] + list(census.keys())
    print(" | ".join(header))
    for outcome in GAME_OUTCOMES:
        row = [outcome] + [str(census[source][outcome]) for source in census]
        print(" | ".join(row))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
