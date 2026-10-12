"""Projects one event site into a `kakyu_event_definition/v4` document
(event definition v4, unit 2b).

Imports the helpers of `tools/project_event_definition.py` (the v3 module)
it needs; v3's own module, documents, index and tests stay byte-identical.
See `docs/spec/data/event_definition_v4_design.md` (the design) and
`analysis/_docs/v4_unit2b_producer_spec.md` (the rules this module follows).

    py tools/project_event_definition_v4.py --site <id> --names <dir> \
        --profiles-dir <dir> --replays-dir analysis/replays_v2 \
        --witnesses-dir analysis/witnesses --package <dir> --arc <mes.arc> \
        --out <dir> [--shared-lines <json>] [--resolved-out <dir>]

Same command line as the v3 tool (`--site`/`--event`, `--names`,
`--profiles-dir`, `--replays-dir`, `--package`, `--arc`, `--out`,
`--resolved-out`) plus `--witnesses-dir` and `--shared-lines`.
"""
from __future__ import annotations

import argparse
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import project_event_definition as ped  # noqa: E402


def resolve_site_v4(row, profiles):
    """`ped.resolve_site` (the registry row's group aliases), and when the
    row lists no group, every profile whose route matches the row's site
    evidence - caller entry, dispatch offset and callee entry - in the same
    `[{"stem", "doc", "group_id", "routes"}]` shape. The registry's aliases
    are regenerated only when the registry itself is rebuilt (a new
    `names_fingerprint`), so a profile declared after the last rebuild is
    found by evidence until then. v3 keeps `ped.resolve_site` alone."""
    matches = ped.resolve_site(row, profiles)
    if matches or row.get("aliases", {}).get("groups"):
        return matches
    evidence = row.get("evidence", {})
    for stem, doc in profiles.items():
        matched_routes = [
            route for route in doc.get("routes", [])
            if route.get("caller", {}).get("entry") == evidence.get("caller")
            and route.get("callee", {}).get("entry") == evidence.get("callee")
            and int(route.get("caller", {}).get("offset", -1)) == int(evidence.get("dispatch_offset", -2))
        ]
        if matched_routes:
            matches.append({"stem": stem, "doc": doc, "group_id": doc.get("group_id"), "routes": matched_routes})
    matches.sort(key=lambda m: m["stem"])
    return matches
from mes_route_decode import Archive  # noqa: E402
import state_cells  # noqa: E402
import validate_event_definition as ved  # noqa: E402

SCHEMA_VERSION = "kakyu_event_definition/v4"

CLOCK_INDEXES = {0, 1, 19}
CLOCK_STEP = 7  # unused directly here; recorded by the witness planner

MARKER_SCENE_END = "__marker__scene_end"
MARKER_CHOICE_PREFIX = "__marker__choice_point:"


# ---------------------------------------------------------------------------
# Small helpers
# ---------------------------------------------------------------------------


def load_json(path):
    return ped.load_json(path)


def _marker_message(kind, choice=None):
    """A synthetic message-shaped dict so v3's `message_key`/grouping
    machinery (unchanged) can treat a marker as one more entry to compare
    for the longest-common-prefix and outcome-signature logic: `entry` is a
    string no real package entry can collide with, `offset`/`end` are 0."""
    if kind == "scene_end":
        entry = MARKER_SCENE_END
    else:
        entry = MARKER_CHOICE_PREFIX + str(choice)
    return {"entry": entry, "offset": 0, "end": 0, "raw_sha256": "", "_marker_kind": kind, "_marker_choice": choice}


def _is_marker(message):
    return message.get("entry", "").startswith("__marker__")


def cell_key3(row):
    return (row["storage"], int(row.get("bank", 0)), int(row["index"]))


def net_changes_for_replay_variant(replay_variant):
    """The variant's net change per cell over prefix + callee(scene) + resume
    `state_changes`, in that order: first `before` seen, last `after` seen.
    Cells whose net effect is zero are dropped (a round trip)."""
    net = {}
    changes = replay_variant.get("state_changes") or {}
    for name in ("prefix", "callee", "resume"):
        for row in changes.get(name) or []:
            key = cell_key3(row)
            if key not in net:
                net[key] = {"storage": row["storage"], "bank": int(row.get("bank", 0)), "index": int(row["index"]),
                            "before": int(row["before"]), "after": int(row["after"])}
            else:
                net[key]["after"] = int(row["after"])
    return {key: value for key, value in net.items() if value["before"] != value["after"]}


def _hhmm_minutes(value):
    if not isinstance(value, int) or value < 0:
        return None
    hh, mm = divmod(value, 100)
    if not (0 <= hh <= 23 and 0 <= mm <= 59):
        return None
    return hh * 60 + mm


def clock_advance_minutes(before, after):
    """Minutes the clock (state_u16[19], HHMM) advanced from `before` to
    `after`, treating a wrap past midnight as a positive advance. None when
    either value is not a plausible HHMM value or the advance is zero
    (0 and 1440 are indistinguishable, so a zero net advance is refused)."""
    b = _hhmm_minutes(before)
    a = _hhmm_minutes(after)
    if b is None or a is None:
        return None
    diff = (a - b) % 1440
    if diff == 0:
        return None
    return diff


# ---------------------------------------------------------------------------
# Marked message timeline (rule 1: candidates and the flow)
# ---------------------------------------------------------------------------


def _insert_choice_marker(pairs, boundary, owner_entry, choice_key):
    """Inserts a `{kind: choice_point}` marker into `pairs` (a list of
    `(message, is_prefix)` tuples), in place, before the first non-marker
    message of `owner_entry` whose offset is greater than `boundary`, else
    right after the last message of `owner_entry` (its segment's end)."""
    marker = _marker_message("choice_point", choice_key)
    insert_at = None
    for i, (m, _is_pfx) in enumerate(pairs):
        if _is_marker(m):
            continue
        if m["entry"] == owner_entry and int(m["offset"]) > boundary:
            insert_at = i
            break
    if insert_at is None:
        last_owner = None
        for i, (m, _is_pfx) in enumerate(pairs):
            if not _is_marker(m) and m["entry"] == owner_entry:
                last_owner = i
        insert_at = (last_owner + 1) if last_owner is not None else len(pairs)
    pairs.insert(insert_at, (marker, False))


def build_candidate_v4(route, variant, replay_variant, top_contract, second_contract, caller_entry, callee_entry,
                       argument_storage=None):
    """One (route, variant) v4 candidate. `messages` is the full marked
    timeline: `prefix_messages` + `messages` + `resume.messages`, with
    `{kind: scene_end}` and the top-level `{kind: choice_point}` marker (when
    the site has one) spliced in as synthetic message-shaped dicts (see
    `_marker_message`), so v3's grouping machinery (`message_key`,
    `longest_common_prefix`, `group_by_signature`, `_leaf`,
    `build_condition_node`, `build_choice_node`, `group_results`) applies
    unchanged. `is_prefix` parallels `messages`: True for an entry that came
    from `prefix_messages` (location-line eligible). A *nested*
    (second-boundary) choice_point marker is not inserted here: whether it
    ends up naming a real document-level `choice` at all depends on how the
    candidates of its containing top-level result group (built_choice_node
    may collapse to a single leaf with no `choice` even when the raw
    selection values differ, when every candidate's message signature still
    matches) - `run_site` inserts it once that is known, directly into a
    genuine choice node's own `dialogue_messages`."""
    prefix = list(replay_variant.get("prefix_messages") or [])
    scene = list(replay_variant.get("messages") or [])
    resume_block = replay_variant.get("resume") or {}
    resume_messages = list(resume_block.get("messages") or [])
    resume_terminal = resume_block.get("terminal")

    declared_keys = {
        (row["storage"], int(row.get("bank", 0)), int(row["index"]))
        for row in (variant.get("expected_state", []) or [])
    }
    net_changes = net_changes_for_replay_variant(replay_variant)
    if argument_storage is not None:
        # TD-56 D11: the net spans the prefix, callee and resume runs, so their `executed` maps
        # are the runs that may have written a `global_i32` change (absent in a v2 replay).
        net_changes = argument_storage.split(net_changes, [
            replay_variant.get("prefix_executed"), replay_variant.get("executed"),
            (replay_variant.get("resume") or {}).get("executed"),
        ])

    terminal = resume_terminal if resume_terminal is not None else replay_variant["terminal"]
    terminal_sig = (terminal.get("entry", ""), terminal.get("status", ""), int(terminal.get("offset", -1)), terminal.get("target", ""))

    event_played = len(scene) > 0

    timeline = [(m, True) for m in prefix] + [(m, False) for m in scene]
    if event_played:
        timeline.append((_marker_message("scene_end"), False))
    timeline += [(m, False) for m in resume_messages]

    selections = {}
    for row in replay_variant.get("selections") or []:
        selections[int(row["boundary_offset"])] = int(row["result_value"])

    if top_contract is not None:
        boundary = int(top_contract["boundary_offset"])
        if boundary in selections:
            owner = ped.contract_owner(top_contract, route)
            owner_entry = caller_entry if owner == "caller" else callee_entry
            _insert_choice_marker(timeline, boundary, owner_entry, "top")

    messages = [m for m, _is_pfx in timeline]
    is_prefix = [is_pfx for _m, is_pfx in timeline]

    writes = [
        {"storage": w["storage"], "bank": int(w.get("bank", 0)), "index": int(w["index"]), "value": int(w["value"])}
        for w in (variant.get("writes") or [])
    ]

    return {
        "route_id": route["route_id"], "variant_id": variant["variant_id"],
        "route": route, "variant": variant,
        "messages": messages, "is_prefix": is_prefix,
        "declared_keys": declared_keys,
        "net_changes": net_changes,
        "terminal_sig": terminal_sig,
        "selections": selections,
        "writes": writes,
        "is_baseline": not writes,
        "event_played": event_played,
    }


# ---------------------------------------------------------------------------
# Rule 2: effects, decided per net-changed cell of the group's leaf
# ---------------------------------------------------------------------------


def decide_effects_for_group(group, result_label, state_cells_table, witness_index, unresolved_out):
    """`(rows, evidence_rows)` for one leaf group (rule 2). `witness_index`
    maps `(route_id, variant_id, (storage, bank, index))` to one shift-witness
    result dict."""
    candidate_cells = {}
    for c in group:
        for key in c["net_changes"]:
            candidate_cells.setdefault(key, None)

    rows = []
    evidence = []
    consume_time_emitted = False
    representative = group[0]

    for key in sorted(candidate_cells):
        storage, bank, index = key
        contributors = [(c, c["net_changes"][key]) for c in group if key in c["net_changes"]]
        if not contributors:
            continue
        declared = any(key in c["declared_keys"] for c in group)

        if storage == "state_u16" and index in CLOCK_INDEXES:
            if index != 19:
                continue  # state_u16[0]/[1] are the clock's parts, not listed again
            if consume_time_emitted:
                continue
            diffs = set()
            ok = True
            for _c, chg in contributors:
                d = clock_advance_minutes(chg["before"], chg["after"])
                if d is None:
                    ok = False
                    break
                diffs.add(d)
            if ok and len(diffs) == 1:
                minutes = diffs.pop()
                rows.append({"type": "consume_time", "minutes": minutes, "cell_class": "clock"})
                evidence.append({
                    "result": result_label, "cell": {"storage": storage, "bank": bank, "index": index},
                    "basis": "clock", "entry": contributors[0][1]["before"], "final": contributors[0][1]["after"],
                    "declared": declared,
                })
                consume_time_emitted = True
            else:
                unresolved_out.append(
                    "clock state_u16[19] advance unresolved for result %s (before/after pairs %s)" % (
                        result_label, sorted((c["variant_id"], chg["before"], chg["after"]) for c, chg in contributors),
                    )
                )
            continue

        if storage == "global_u8" and all(chg["before"] == 0 and chg["after"] == 1 for _c, chg in contributors):
            cls = state_cells.classify(storage, bank, index, [0, 1], table=state_cells_table)
            rows.append({"type": "write_legacy_value", "storage": storage, "bank": bank, "index": index, "value": 1, "cell_class": cls})
            evidence.append({
                "result": result_label, "cell": {"storage": storage, "bank": bank, "index": index},
                "basis": "flag_pattern", "entry": 0, "final": 1, "declared": declared,
            })
            continue

        befores = {chg["before"] for _c, chg in contributors}
        finals = {chg["after"] for _c, chg in contributors}

        if len(befores) >= 2:
            deltas = {chg["after"] - chg["before"] for _c, chg in contributors}
            if len(finals) == 1:
                value = finals.pop()
                cls = state_cells.classify(storage, bank, index, [value], table=state_cells_table)
                rows.append({"type": "write_legacy_value", "storage": storage, "bank": bank, "index": index, "value": value, "cell_class": cls})
                evidence.append({
                    "result": result_label, "cell": {"storage": storage, "bank": bank, "index": index},
                    "basis": "variants", "entry": sorted(befores)[0], "final": value, "declared": declared,
                })
            elif len(deltas) == 1:
                delta = deltas.pop()
                cls = state_cells.classify(storage, bank, index, sorted(finals), table=state_cells_table)
                rows.append({"type": "add_legacy_value", "storage": storage, "bank": bank, "index": index, "delta": delta, "cell_class": cls})
                evidence.append({
                    "result": result_label, "cell": {"storage": storage, "bank": bank, "index": index},
                    "basis": "variants", "entry": sorted(befores)[0], "final": sorted(finals)[0], "declared": declared,
                })
            else:
                unresolved_out.append(
                    "effect on %s[%d] varies without a single final or delta across entries for result %s "
                    "(observed before/after pairs %s)" % (
                        storage, index, result_label,
                        sorted((chg["before"], chg["after"]) for _c, chg in contributors),
                    )
                )
            continue

        # Entries agree: ambiguous without a witness.
        if len(finals) != 1:
            unresolved_out.append(
                "effect on %s[%d] for result %s: variants with the same entry state end on different final "
                "values %s (non-deterministic replay)" % (storage, index, result_label, sorted(finals))
            )
            continue
        entry_value = sorted(befores)[0]
        final_value = finals.pop()
        witness = witness_index.get((representative["route_id"], representative["variant_id"], key))
        if witness is None or witness.get("entry") != entry_value or witness.get("final") != final_value:
            unresolved_out.append(
                "effect on %s[%d] for result %s: no matching shift witness (entry=%d final=%d)" % (
                    storage, index, result_label, entry_value, final_value,
                )
            )
            continue
        kind = witness.get("kind")
        cls = state_cells.classify(storage, bank, index, [entry_value, final_value], table=state_cells_table)
        if kind == "set":
            rows.append({"type": "write_legacy_value", "storage": storage, "bank": bank, "index": index, "value": final_value, "cell_class": cls})
        elif kind == "add":
            delta = final_value - entry_value
            rows.append({"type": "add_legacy_value", "storage": storage, "bank": bank, "index": index, "delta": delta, "cell_class": cls})
        else:
            unresolved_out.append(
                "effect on %s[%d] for result %s: witness outcome %r, not set/add" % (storage, index, result_label, kind)
            )
            continue
        evidence.append({
            "result": result_label, "cell": {"storage": storage, "bank": bank, "index": index},
            "basis": "shift_witness", "entry": witness.get("entry"), "final": witness.get("final"),
            "step": witness.get("step"), "shifted_entry": witness.get("shifted_entry"),
            "shifted_final": witness.get("shifted_final"), "declared": declared,
        })

    return rows, evidence


def _row_signature(row):
    if row["type"] == "consume_time":
        return ("consume_time", row["minutes"])
    if row["type"] == "write_legacy_value":
        return ("write", row["storage"], row["bank"], row["index"], row["value"])
    return ("add", row["storage"], row["bank"], row["index"], row["delta"])


# ---------------------------------------------------------------------------
# Witness index and done-cell probe
# ---------------------------------------------------------------------------


FLOW_PROFILE_SCHEMA = "kakyu_event_analysis_group/v14"


class WitnessRefusal(Exception):
    """A site's witness evidence is absent or stale and the caller did not
    opt out (TD-37). The message names the profile stem and what to run."""


def _witness_paths(stem, witnesses_dir):
    requests_path = os.path.normpath(os.path.join(witnesses_dir, "..", "witness_requests", "%s.json" % stem))
    witnesses_path = os.path.join(witnesses_dir, "%s.json" % stem)
    return requests_path, witnesses_path


def _index_witness_documents(requests_doc, witnesses_doc):
    """`(shift_index, done_index, results_used)`: the request file's
    `route_id`/`variant_id` per request (in request order) joined to the
    witness file's `results` by `request_index`. `results_used` counts the
    requests answered by a result row that carries no `error`."""
    shift_index = {}
    done_index = {}
    requests = requests_doc.get("requests") or []
    results_by_index = {}
    for row in witnesses_doc.get("results") or []:
        idx = row.get("request_index")
        if idx is not None:
            results_by_index[int(idx)] = row
    results_used = 0
    for i, request in enumerate(requests):
        result = results_by_index.get(i)
        if result is None:
            continue
        if "error" not in result:
            results_used += 1
        if request.get("kind") == "shift":
            cell = request["cell"]
            key = (request["route_id"], request["variant_id"], (cell["storage"], int(cell["bank"]), int(cell["index"])))
            shift_index[key] = result
        elif request.get("kind") == "done_probe":
            key = (request["route_id"], request["variant_id"])
            done_index[key] = result
    return shift_index, done_index, results_used


def load_witness_index(stem, witnesses_dir):
    """`{(route_id, variant_id, (storage, bank, index)): witness_result}` and
    `{(route_id, variant_id): done_probe_result}` for one profile stem, from
    its `witness_requests/<stem>.json` (route_id/variant_id per request, in
    request order) and `witnesses/<stem>.json` (`results`, aligned by
    `request_index`). Empty indexes when either file is missing, with no
    warning and no profile-hash check: the v4/v5 producers (frozen) keep
    this behaviour; the v6 producer uses `load_witness_index_checked`
    (TD-37)."""
    requests_path, witnesses_path = _witness_paths(stem, witnesses_dir)
    if not (os.path.isfile(requests_path) and os.path.isfile(witnesses_path)):
        return {}, {}
    shift_index, done_index, _used = _index_witness_documents(load_json(requests_path), load_json(witnesses_path))
    return shift_index, done_index


def load_witness_index_checked(stem, witnesses_dir, payload_sha256):
    """`(shift_index, done_index, status)` for one profile stem, with the
    evidence's own health reported instead of swallowed (TD-37). `status`:
    `stem`, `request_file` (bool), `requests` (count), `witness_file`
    (bool), `hash_match` (`None` while undecided, else bool; both
    documents' `payload_sha256` must equal `payload_sha256`), `results_used`
    (see `_index_witness_documents`) and `problem`: `None` when the
    evidence is whole, else `"no_request_file"` (the plan was not run),
    `"no_witness_file"` (a non-empty plan was not run) or `"stale"` (a
    document's `payload_sha256` is not the profile's). Indexes are empty
    whenever `problem` is not `None`."""
    requests_path, witnesses_path = _witness_paths(stem, witnesses_dir)
    status = {"stem": stem, "request_file": False, "requests": 0, "witness_file": False,
              "hash_match": None, "results_used": 0, "problem": None}
    if not os.path.isfile(requests_path):
        status["problem"] = "no_request_file"
        return {}, {}, status
    status["request_file"] = True
    requests_doc = load_json(requests_path)
    status["requests"] = len(requests_doc.get("requests") or [])
    if not payload_sha256 or requests_doc.get("payload_sha256") != payload_sha256:
        status["hash_match"] = False
        status["problem"] = "stale"
        return {}, {}, status
    if status["requests"] == 0:
        status["hash_match"] = True
        return {}, {}, status
    if not os.path.isfile(witnesses_path):
        status["problem"] = "no_witness_file"
        return {}, {}, status
    status["witness_file"] = True
    witnesses_doc = load_json(witnesses_path)
    if not payload_sha256 or witnesses_doc.get("payload_sha256") != payload_sha256:
        status["hash_match"] = False
        status["problem"] = "stale"
        return {}, {}, status
    status["hash_match"] = True
    shift_index, done_index, status["results_used"] = _index_witness_documents(requests_doc, witnesses_doc)
    return shift_index, done_index, status


_WITNESS_PROBLEM_TEXT = {
    "no_request_file": "no witness_requests/%s.json (run tools/plan_event_effect_witnesses.py)",
    "no_witness_file": "requests exist but no witnesses/%s.json (run validate_event_analysis_group.gd --witness)",
    "stale": "witness_requests/%s.json or witnesses/%s.json carries a payload_sha256 that is not the profile's "
             "(regenerate the corpus for the current profile)",
}


def resolve_witness_indexes(site_id, matches, witnesses_dir, allow_missing):
    """`(shift_index, done_index, report)` for every non-flow profile a site
    matches (the loader merges all of them: `matches` is every profile
    declaring the site, not only the preferred one). A flow (v14) profile
    carries no witnesses and is skipped. Raises `WitnessRefusal` when the
    witnesses directory or a profile's evidence is absent (unless
    `allow_missing`), and always when a profile's evidence is stale: stale
    evidence is wrong data, not absent data. With `allow_missing` an absent
    profile's evidence is recorded in `report["missing"]` for the caller's
    warning. `report`: `stems`, `requests`, `results_used`, `missing`
    (`[(stem, problem)]`)."""
    report = {"stems": 0, "requests": 0, "results_used": 0, "missing": []}
    shift_index = {}
    done_index = {}
    witness_capable = [m for m in matches if m["doc"].get("schema") != FLOW_PROFILE_SCHEMA]
    if not witness_capable:
        return shift_index, done_index, report
    requests_dir = os.path.normpath(os.path.join(witnesses_dir, "..", "witness_requests"))
    if not allow_missing and not (os.path.isdir(witnesses_dir) and os.path.isdir(requests_dir)):
        raise WitnessRefusal(
            "site %s: witness corpus directories not found (%s, %s); regenerate the corpus or pass "
            "--allow-missing-witnesses" % (site_id, witnesses_dir, requests_dir))
    for m in witness_capable:
        s_idx, d_idx, status = load_witness_index_checked(m["stem"], witnesses_dir, m["doc"].get("payload_sha256"))
        problem = status["problem"]
        if problem == "stale" or (problem is not None and not allow_missing):
            text = _WITNESS_PROBLEM_TEXT[problem].replace("%s", m["stem"])
            raise WitnessRefusal("site %s, profile %s: %s%s" % (
                site_id, m["stem"], text,
                "" if problem == "stale" else "; or pass --allow-missing-witnesses to project without them"))
        report["stems"] += 1
        report["requests"] += status["requests"]
        report["results_used"] += status["results_used"]
        if problem is not None:
            report["missing"].append((m["stem"], problem))
        shift_index.update(s_idx)
        done_index.update(d_idx)
    return shift_index, done_index, report


def witness_done_cell(done_index, route_id, variant_id):
    """`(index, evidence)` from the done-probe witness result for
    `(route_id, variant_id)`: exactly one gate cell (always `global_u8`,
    per the unit 1b measurement) -> that index; none or several -> `(None,
    evidence)`."""
    result = done_index.get((route_id, variant_id))
    if result is None:
        return None, None
    gates = result.get("gates") or []
    if len(gates) == 1 and gates[0].get("storage") == "global_u8":
        return int(gates[0]["index"]), result
    return None, result


# ---------------------------------------------------------------------------
# Order hint
# ---------------------------------------------------------------------------


def compute_order_hint(registry, profiles, doc_id, caller_entry, this_offset, this_false_target):
    """`trigger.order_hint` (rule 5), or `None` when `this_offset` is `None`
    (no typed guard). Scans every registry row sharing `caller_entry` for its
    own resolved guard offset (via `resolve_site`/`choose_preferred`, the
    same helpers `run_site` uses); a row that fails to resolve or carries no
    typed guard is excluded from the ranking."""
    if this_offset is None:
        return None
    candidate_rows = []
    all_rows = []
    if isinstance(registry.get("rows"), dict):
        all_rows = list(registry["rows"].values())
    elif isinstance(registry.get("events"), list):
        all_rows = registry["events"]
    for row in all_rows:
        if row.get("evidence", {}).get("caller") != caller_entry:
            continue
        if row.get("id") == doc_id:
            candidate_rows.append((doc_id, this_offset, this_false_target))
            continue
        matches = resolve_site_v4(row, profiles)
        if not matches:
            continue
        preferred = ped.choose_preferred(matches)
        r1 = preferred["routes"][0]
        guard = r1.get("guard")
        if not guard:
            continue
        candidate_rows.append((row["id"], int(guard["offset"]), int(guard["false_target"])))

    candidate_rows.sort(key=lambda t: t[1])
    offsets = [t[1] for t in candidate_rows]
    ids = [t[0] for t in candidate_rows]
    if doc_id not in ids:
        return None
    rank_index = ids.index(doc_id)
    rank = rank_index + 1
    of = len(candidate_rows)
    chain_confirmed = False
    if rank_index + 1 < len(candidate_rows):
        next_offset = offsets[rank_index + 1]
        false_target = candidate_rows[rank_index][2]
        if false_target == next_offset:
            chain_confirmed = True
        elif this_offset < false_target < next_offset:
            between = any(this_offset < o < next_offset for j, o in enumerate(offsets) if j not in (rank_index, rank_index + 1))
            chain_confirmed = not between
    return {"scope": caller_entry, "rank": rank, "of": of, "basis": "guard_offset", "chain_confirmed": chain_confirmed}


# ---------------------------------------------------------------------------
# Dialogue construction with markers and location lines
# ---------------------------------------------------------------------------


def build_dialogue_entry_v4(message, prefix_ids, events_doc_by_entry, report, guard_offset, caller_entry, shared_lines_for_caller):
    if _is_marker(message):
        kind = message["_marker_kind"]
        if kind == "scene_end":
            return {"kind": "scene_end"}
        return {"kind": "choice_point", "choice": message["_marker_choice"]}
    entry = ped.build_dialogue_entry(message, events_doc_by_entry, report)
    if entry is None:
        return None
    is_prefix = id(message) in prefix_ids
    if is_prefix and entry.get("kind") in ("text", "name_insert"):
        location = False
        if guard_offset is not None and message["entry"] == caller_entry and int(message["offset"]) < guard_offset:
            location = True
        elif (message["entry"], int(message["offset"])) in shared_lines_for_caller:
            location = True
        if location:
            entry["location_line"] = True
    return entry


def build_dialogue_list_v4(messages, prefix_ids, events_doc_by_entry, report, guard_offset, caller_entry, shared_lines_for_caller):
    entries = []
    for message in messages:
        entry = build_dialogue_entry_v4(message, prefix_ids, events_doc_by_entry, report, guard_offset, caller_entry, shared_lines_for_caller)
        if entry is None:
            return None
        entries.append(entry)
    return entries


_BASIS_PRIORITY = {"shift_witness": 0, "flag_pattern": 1, "clock": 2, "variants": 3}


def promote_shared_rows_with_evidence(leaf_pairs_by_id):
    """`(body_rows, body_evidence, remaining_by_id)`: a row every leaf result
    shares (by `_row_signature`) moves to the body `after`. When more than
    one leaf independently decided the same row by a different basis (e.g.
    one leaf's group had entries agree, deciding it by `shift_witness`,
    while another's had entries vary, deciding the same numeric row by
    `variants`), the most directly evidenced basis is kept
    (`shift_witness` > `flag_pattern`/`clock` > `variants`); every other
    row/evidence stays with its own leaf's result id."""
    if not leaf_pairs_by_id:
        return [], [], {}
    leaf_ids = list(leaf_pairs_by_id.keys())
    sig_sets = [{_row_signature(row) for row, _ev in leaf_pairs_by_id[lid]} for lid in leaf_ids]
    common_sigs = set.intersection(*sig_sets) if sig_sets else set()

    best_by_sig = {}
    for lid in leaf_ids:
        for row, ev in leaf_pairs_by_id[lid]:
            sig = _row_signature(row)
            if sig not in common_sigs:
                continue
            priority = _BASIS_PRIORITY.get(ev.get("basis"), 99)
            if sig not in best_by_sig or priority < best_by_sig[sig][2]:
                best_by_sig[sig] = (row, ev, priority)

    body_rows = []
    body_evidence = []
    for sig in dict.fromkeys(_row_signature(row) for row, _ev in leaf_pairs_by_id[leaf_ids[0]] if _row_signature(row) in common_sigs):
        row, ev, _priority = best_by_sig[sig]
        body_rows.append(row)
        ev = dict(ev)
        ev["result"] = "body"
        body_evidence.append(ev)

    remaining = {}
    for lid in leaf_ids:
        remaining[lid] = [(row, ev) for row, ev in leaf_pairs_by_id[lid] if _row_signature(row) not in common_sigs]
    return body_rows, body_evidence, remaining


# ---------------------------------------------------------------------------
# The site path
# ---------------------------------------------------------------------------


def recompute_cell_classes(document, state_cells_table):
    """Overwrites every effect row's `cell_class` from the document's own
    observed values (`validate_event_definition._collect_observed_values`,
    the same function the validator recomputes it with), so a cell_class
    decided from one result's own witness values agrees with the class the
    validator derives from the whole document (e.g. a `global_u8` cell also
    written to a non-0/1 value in a `reentry.after` row is a `counter`, not
    a `flag`, even where this row's own evidence only ever saw 0/1)."""
    observed = ved._collect_observed_values(document)

    def fix_rows(rows):
        for row in rows or []:
            if not isinstance(row, dict) or row.get("type") == "consume_time":
                continue
            key = (row.get("storage"), row.get("bank"), row.get("index"))
            row["cell_class"] = state_cells.classify(*key, observed.get(key), table=state_cells_table)

    def walk_result(result):
        fix_rows(result.get("after"))
        for nested in (result.get("results") or {}).values():
            walk_result(nested)

    fix_rows(document.get("after"))
    for result in (document.get("results") or {}).values():
        walk_result(result)
    # WD-23: a v5 document's `visits[].after` rows share the same cell-class
    # recomputation (harmless no-op for a v4 document, which never carries
    # `visits`).
    for visit in document.get("visits") or []:
        if isinstance(visit, dict):
            fix_rows(visit.get("after"))
    # EP-12 / WD unit 2 (2026-09-25): a v6 flow document's own per-hop
    # `after` rows share the same recomputation (harmless no-op for a v3/v4/v5
    # document, which never carries `flow`).
    flow = document.get("flow")
    if isinstance(flow, dict):
        for hop in flow.get("hops") or []:
            if isinstance(hop, dict):
                fix_rows(hop.get("after"))


def _collect_leaf_ids(results_tree):
    """Every leaf node id (a node with no nested `results`) at any depth of
    `results_tree` (from `group_results`/`build_condition_node`/
    `build_choice_node`), depth-first."""
    leaves = []

    def walk(tree):
        for rid, node in tree.items():
            if node.get("results") is not None:
                walk(node["results"])
            else:
                leaves.append((rid, node))

    walk(results_tree)
    return leaves


def run_site(args):
    registry, names_fingerprint = ped.load_registry(args.names)
    row = ped.find_registry_row_by_id(registry, args.site)
    if row is None:
        print("REGISTRY ROW NOT FOUND for %s" % args.site)
        return 1
    if names_fingerprint == "unrecorded":
        print("names_fingerprint: unrecorded (registry at %s has no names_fingerprint file)" % args.names)
    else:
        print("names_fingerprint=%s" % names_fingerprint)

    profiles = ped.load_profiles(args.profiles_dir)
    matches = resolve_site_v4(row, profiles)
    if not matches:
        print("NO PROFILE MATCHES site %s (evidence=%s)" % (args.site, row["evidence"]))
        return 1
    preferred = ped.choose_preferred(matches)
    routes = preferred["routes"]
    r1 = routes[0]
    profile_doc = preferred["doc"]
    stem = preferred["stem"]
    doc_id = row["id"]

    manifest = ped.load_json(os.path.join(args.package, "manifest.json"))
    replay_doc = ped.load_json(os.path.join(args.replays_dir, "%s.json" % stem))
    if replay_doc["archive_sha256"] != manifest["source"]["archive_sha256"]:
        print("ARCHIVE MISMATCH between replay and package manifest")
        return 1
    if replay_doc["archive_sha256"] != profile_doc["archive_sha256"]:
        print("ARCHIVE MISMATCH between replay and profile")
        return 1

    replay_route_by_id = {r["route_id"]: r for r in replay_doc["routes"]}
    for route in routes:
        if route["route_id"] not in replay_route_by_id:
            print("REPLAY MISSING route %s" % route["route_id"])
            return 1

    display = {
        "title_ko": row.get("title_ko", ""), "title_en": row.get("title_en", ""),
        "heroine": row.get("heroine", ""), "category": row.get("category", ""), "place": row.get("place", ""),
    }

    members = profile_doc.get("source_members", [])
    members_by_entry = {m["entry"]: m["entry_sha256"] for m in members}

    manifest_members = {e["entry"]: e["entry_sha256"] for e in manifest.get("entries", [])}
    for m in members:
        if m["entry"] in manifest_members and manifest_members[m["entry"]] != m["entry_sha256"]:
            print("PACKAGE MEMBER MISMATCH for %s" % m["entry"])
            return 1
    package_binding = {"schema": manifest["schema"], "package_sha256": manifest["package_sha256"]}

    groups_evidence = [
        {"group_id": m["group_id"], "profile_sha256": m["doc"]["payload_sha256"],
         "route_ids": [r["route_id"] for r in m["routes"]]}
        for m in matches
    ]
    groups_evidence.sort(key=lambda g: (g["group_id"], g["profile_sha256"]))

    evidence = {
        "kind": "analysis_group",
        "archive_sha256": profile_doc["archive_sha256"],
        "groups": groups_evidence,
        "members": [{"entry": m["entry"], "entry_sha256": m["entry_sha256"]} for m in members],
        "document_refs": [],
    }

    caller_entry = r1["caller"]["entry"]
    callee_entry = r1["callee"]["entry"]
    inference_unresolved = []

    caller_outcome_kind = (r1.get("caller_outcome") or {}).get("kind")
    caller_kind_map = {
        "dispatch": "nested_call", "root_handoff": "root_handoff",
        "nested_root_handoff": "nested_root_handoff", "blocked_definition": "nested_call",
    }
    trigger_caller_kind = caller_kind_map.get(caller_outcome_kind)
    if trigger_caller_kind is None:
        print("UNKNOWN caller_outcome.kind %r" % caller_outcome_kind)
        return 1
    if caller_outcome_kind == "blocked_definition":
        inference_unresolved.append("caller outcome blocked_definition")

    trigger = {
        "type": "caller_dispatch",
        "caller": {
            "entry": caller_entry, "entry_sha256": members_by_entry.get(caller_entry, ""),
            "offset": int(r1["caller"]["offset"]), "end": int(r1["caller"]["end"]),
            "command": int(r1["caller"]["command"]), "kind": trigger_caller_kind,
        },
        "callee": {
            "entry": callee_entry, "entry_sha256": members_by_entry.get(callee_entry, ""),
            "start_coordinate": int(r1["callee"]["offset"]),
        },
    }
    if "origin_offset" in r1:
        origin_offset = int(r1["origin_offset"])
    elif r1.get("guard"):
        origin_offset = int(r1["guard"]["offset"])
        inference_unresolved.append(
            "origin not determined: historical v1-v4 GROUND group declares no origin_offset; "
            "the guard's own offset %d is used as a fallback origin (docs/spec/data/"
            "event_definition_projection.md, \"What stays unresolved\")" % origin_offset
        )
    else:
        origin_offset = int(r1["caller"]["offset"])
        inference_unresolved.append(
            "origin not determined: historical v1-v4 GROUND group declares no origin_offset and no "
            "guard; the caller's dispatch offset %d is used as a fallback origin (docs/spec/data/"
            "event_definition_projection.md, \"What stays unresolved\")" % origin_offset
        )
    map_contracts = r1.get("map_location_contracts") or []
    if map_contracts:
        trigger["origin"] = {
            "kind": "map_arrival", "offset": origin_offset,
            "contracts": [
                {"map": c["source_identity"]["entry"], "poll_offset": int(c["poll_offset"]),
                 "locations": [int(x) for x in c.get("locations", [])]}
                for c in map_contracts
            ],
        }
    elif r1.get("guard") and origin_offset == int(r1["guard"]["offset"]):
        trigger["origin"] = {"kind": "typed_guard", "offset": origin_offset}
    else:
        trigger["origin"] = {"kind": "caller_prefix", "offset": origin_offset}

    scenes = [ped.scene_from_map_contract(c) for c in map_contracts]

    archive = Archive(args.arc)

    guard = None
    conditions = []
    conjunct_rows = []
    if r1.get("guard"):
        g = r1["guard"]
        from mes_route_decode import conjuncts as _conjuncts
        parts = _conjuncts(archive, caller_entry, int(g["offset"]))
        conjunct_rows = [ped.map_conjunct(p, ped.AFFECTION_HEROINE_LETTERS) for p in parts]
        witnesses = [
            {"case_id": case["case_id"], "writes": ped.absolute_rows(case.get("writes", [])), "expected": int(case["expected"])}
            for case in r1.get("guard_cases", [])
        ]
        record_sha256 = g.get("record_sha256")
        if record_sha256 is None:
            record_sha256 = g.get("prefix_sha256", "")
            inference_unresolved.append(
                "guard.record_sha256 not declared (historical v1-v4 GROUND group); "
                "guard.prefix_sha256 is used in its place"
            )
        guard = {
            "offset": int(g["offset"]), "end": int(g["end"]), "false_target": int(g["false_target"]),
            "record_sha256": record_sha256, "conjuncts": conjunct_rows, "witnesses": witnesses,
        }
        ast = ped.guard_ast(archive, caller_entry, int(g["offset"]))
        conditions.append({
            "type": "mes_expression", "ast": ast, "source_offset": int(g["offset"]),
            "failure_reason": "guard_rejected",
        })

    # --- witness index (v4 rule 2/3) ---------------------------------------
    # `args.require_witnesses` is defined only by the v6 producer (TD-37):
    # `True` refuses absent or stale evidence, `False` is its explicit
    # `--allow-missing-witnesses` opt-out (warns loudly per site), and
    # undefined (v4/v5, frozen) keeps the silent legacy loader.
    require_witnesses = getattr(args, "require_witnesses", None)
    if require_witnesses is None:
        shift_index = {}
        done_index = {}
        for m in matches:
            s_idx, d_idx = load_witness_index(m["stem"], args.witnesses_dir)
            shift_index.update(s_idx)
            done_index.update(d_idx)
    else:
        try:
            shift_index, done_index, witness_report = resolve_witness_indexes(
                doc_id, matches, args.witnesses_dir, allow_missing=not require_witnesses)
        except WitnessRefusal as exc:
            print("WITNESSES REFUSED: %s" % exc)
            return 1
        for stem, problem in witness_report["missing"]:
            print("WARNING: site %s projected WITHOUT witnesses for profile %s (%s); shift_witness and "
                  "reentry_probe rows are not produced" % (doc_id, stem, problem))
        print("WITNESS_STATUS site=%s stems=%d requests=%d results_used=%d missing=%d" % (
            doc_id, witness_report["stems"], witness_report["requests"], witness_report["results_used"],
            len(witness_report["missing"])))

    # --- done cell (rule 3) -------------------------------------------------
    reentry_r1 = r1.get("reentry")
    if reentry_r1 is not None:
        done_index_guard = ped.find_done_cell(conjunct_rows, r1)
        if done_index_guard is not None:
            conditions.append({
                "type": "event_not_completed", "event_id": doc_id, "failure_reason": "already_completed",
                "done_cell": {"storage": "global_u8", "bank": 0, "index": done_index_guard, "value": 1},
                "source": "guard_flag",
            })
            inference_unresolved.append("done_cell = the guard's cleared flag the event sets")
        else:
            replay_route_r1 = replay_route_by_id[r1["route_id"]]
            representative_variant_id = None
            for v in replay_route_r1["variants"]:
                if v.get("reached", True):
                    representative_variant_id = v["variant_id"]
                    break
            gate_index, probe_result = witness_done_cell(done_index, r1["route_id"], representative_variant_id)
            if gate_index is not None:
                conditions.append({
                    "type": "event_not_completed", "event_id": doc_id, "failure_reason": "already_completed",
                    "done_cell": {"storage": "global_u8", "bank": 0, "index": gate_index, "value": 1},
                    "source": "reentry_probe",
                })
                inference_unresolved.append("done_cell = the witness done-cell probe's single gate")
            elif probe_result is not None and len(probe_result.get("gates") or []) > 1:
                print("SEVERAL DONE-CELL GATES for %s: %s" % (doc_id, probe_result.get("gates")))
                return 2
            else:
                inference_unresolved.append(
                    "no done flag identified in the guard, and the witness done-cell probe named no exact gate; "
                    "the reentry is gated inside the callee (reentry emits %d messages)" % int(reentry_r1["message_count"])
                )

    presets = [{"preset_id": "baseline", "label": "baseline", "writes": ped.absolute_rows(r1.get("baseline", []))}]
    seen_write_keys = set()
    for route in routes:
        for variant in route.get("variants", []):
            writes = variant.get("writes") or []
            if not writes:
                continue
            key = frozenset((w["storage"], int(w.get("bank", 0)), int(w["index"]), int(w["value"])) for w in writes)
            if key in seen_write_keys:
                continue
            seen_write_keys.add(key)
            presets.append({
                "preset_id": "%s/%s" % (route["route_id"], variant["variant_id"]),
                "label": variant["variant_id"], "writes": ped.absolute_rows(writes),
            })

    top_contract, second_contract = ped.choose_contracts(r1)

    argument_storage = ped.ArgumentStorage(lambda entry: ped.load_events_document(args.package, entry))
    candidates = []
    for route in routes:
        replay_route = replay_route_by_id[route["route_id"]]
        replay_variant_by_id = {v["variant_id"]: v for v in replay_route["variants"]}
        for variant in route.get("variants", []):
            vid = variant["variant_id"]
            if vid not in replay_variant_by_id:
                print("REPLAY MISSING variant %s/%s" % (route["route_id"], vid))
                return 1
            replay_variant = replay_variant_by_id[vid]
            if not replay_variant.get("reached", True):
                inference_unresolved.append("variant %s/%s not reached in the v2 replay; excluded" % (route["route_id"], vid))
                continue
            candidates.append(build_candidate_v4(
                route, variant, replay_variant, top_contract, second_contract, caller_entry, callee_entry,
                argument_storage=argument_storage,
            ))

    if not candidates:
        print("NO REACHED CANDIDATES for %s" % doc_id)
        return 1

    prefix_ids = set()
    for c in candidates:
        for m, is_pfx in zip(c["messages"], c["is_prefix"]):
            if is_pfx:
                prefix_ids.add(id(m))

    body_messages = ped.longest_common_prefix([c["messages"] for c in candidates])
    try:
        results_tree, choice_info, kind, group_unresolved = ped.group_results(
            candidates, top_contract, second_contract, consumed=len(body_messages))
    except ped.ReproductionMismatch as exc:
        print("REPRODUCTION MISMATCH: %s" % exc)
        return 1

    terminals_raw = {}
    for route in routes:
        terminals_raw.update(ped.terminal_from_route(route, caller_entry, callee_entry))
    terminals, terminal_remap = ped.dedupe_terminals(terminals_raw)

    involved_entries = {callee_entry, caller_entry}
    for c in candidates:
        for m in c["messages"]:
            if not _is_marker(m):
                involved_entries.add(m["entry"])
    events_doc_by_entry = {entry: ped.load_events_document(args.package, entry) for entry in involved_entries}

    guard_offset = guard["offset"] if guard else None
    shared_lines = {}
    if args.shared_lines and os.path.isfile(args.shared_lines):
        shared_lines = ped.load_json(args.shared_lines)
    shared_lines_for_caller = {(row[0], int(row[1])) for row in shared_lines.get(caller_entry, [])}

    report = {"missing_records": [], "missing_text_operand": []}
    body_dialogue = build_dialogue_list_v4(body_messages, prefix_ids, events_doc_by_entry, report, guard_offset, caller_entry, shared_lines_for_caller)
    if body_dialogue is None:
        print("FATAL missing_text_operand in the body: %s" % report["missing_text_operand"])
        return 1

    after_unresolved = []

    def resolve_node(node, result_label):
        rep = node["representative"]
        dialogue_messages = node["dialogue_messages"]
        if node.get("choice") is not None:
            # A genuine nested (second-boundary) choice: insert its
            # choice_point marker into this node's own dialogue, now that it
            # is known to name a real `choice` object (build_candidate_v4
            # never inserts a nested marker itself - see its docstring).
            c = node["choice"]
            owner = ped.contract_owner(c["contract"], rep["route"])
            owner_entry = caller_entry if owner == "caller" else callee_entry
            pairs = [(m, id(m) in prefix_ids) for m in dialogue_messages]
            _insert_choice_marker(pairs, c["boundary"], owner_entry, result_label)
            dialogue_messages = [m for m, _is_pfx in pairs]
        dialogue = build_dialogue_list_v4(dialogue_messages, prefix_ids, events_doc_by_entry, report, guard_offset, caller_entry, shared_lines_for_caller)
        if dialogue is None:
            return None
        route = rep["route"]
        terminal_key = route["route_id"] + (".resume" if route.get("resume") else ".outcome")
        result = {
            "selected_by": node["selected_by"],
            "event_played": node["event_played"],
            "dialogue": dialogue,
            "after": [],
            "terminal": terminal_remap[terminal_key],
        }
        route_reentry = route.get("reentry")
        if route_reentry is not None:
            same = int(route_reentry["outcome"]["offset"]) == int(route["outcome"]["offset"])
            result["reentry"] = {
                "outcome": "same" if same else "other",
                "message_count": int(route_reentry["message_count"]),
                "after": ped.effect_rows(route_reentry.get("expected_state", []) or []),
            }
        if node.get("results") is not None:
            sub_results = {}
            for rid, sub_node in node["results"].items():
                sub_result = resolve_node(sub_node, rid)
                if sub_result is None:
                    return None
                sub_results[rid] = sub_result
            result["results"] = sub_results
        if node.get("choice") is not None:
            c = node["choice"]
            owner = ped.contract_owner(c["contract"], rep["route"])
            result["choice"] = {
                "owner": owner, "boundary": c["boundary"],
                "position": "before_event" if owner == "caller" else "in_event",
                "options": [{"value": v, "result": "answer%d" % v} for v in c["order"]],
            }
        return result

    results = {}
    for rid, node in results_tree.items():
        resolved = resolve_node(node, rid)
        if resolved is None:
            print("FATAL missing_text_operand in result %s: %s" % (rid, report["missing_text_operand"]))
            return 1
        results[rid] = resolved

    # --- effects (rule 2), decided per leaf, then promoted to the body -----
    leaf_infos = _collect_leaf_ids(results_tree)
    leaf_pairs_by_id = {}
    for rid, node in leaf_infos:
        rows, evidence_rows = decide_effects_for_group(node["group"], rid, state_cells.load(), shift_index, after_unresolved)
        leaf_pairs_by_id[rid] = list(zip(rows, evidence_rows))

    body_rows, body_evidence, remaining_by_id = promote_shared_rows_with_evidence(leaf_pairs_by_id)

    def apply_effects(tree_results):
        for rid, result in tree_results.items():
            if rid in remaining_by_id:
                pairs = remaining_by_id[rid]
                result["after"] = [row for row, _ev in pairs]
            if result.get("results") is not None:
                apply_effects(result["results"])

    apply_effects(results)
    all_evidence = list(body_evidence)
    for rid in remaining_by_id:
        all_evidence.extend(ev for _row, ev in remaining_by_id[rid])

    document_choice = None
    if choice_info is not None:
        owner = ped.contract_owner(choice_info["contract"], r1)
        document_choice = {
            "owner": owner, "boundary": choice_info["boundary"],
            "position": "before_event" if owner == "caller" else "in_event",
            "options": [{"value": v, "result": "answer%d" % v} for v in choice_info["order"]],
        }

    exclude_entries = {caller_entry, callee_entry, "START.MES", "DEF_MAIN.MES", "LIBLARY.LIB"}
    dependencies = [
        {"entry": m["entry"], "entry_sha256": m["entry_sha256"], "role": "nested_presentation"}
        for m in members if m["entry"] not in exclude_entries
    ]

    order_hint = compute_order_hint(registry, profiles, doc_id, caller_entry, guard_offset, guard["false_target"] if guard else None)
    if order_hint is not None:
        trigger["order_hint"] = order_hint

    final_unresolved = []
    for route in routes:
        final_unresolved.extend(route.get("unresolved", []) or [])
    final_unresolved.extend(inference_unresolved)
    if len(matches) > 1:
        final_unresolved.append("site declared by %d profiles; trigger and results from %s" % (len(matches), stem))
    final_unresolved.extend(group_unresolved)
    final_unresolved.extend(after_unresolved)
    final_unresolved.extend(argument_storage.lines())
    final_unresolved = ped.merge_unresolved(final_unresolved)

    document = {
        "schema_version": SCHEMA_VERSION,
        "contract_fingerprint": ped.resolve_contract_fingerprint(args.contract_fingerprint),
        "names_fingerprint": names_fingerprint,
        "id": doc_id,
        "kind": kind,
        "display": display,
        "evidence": dict(evidence, effect_witnesses=all_evidence),
        "package_binding": package_binding,
        "trigger": trigger,
        "scenes": scenes,
        "guard": guard,
        "conditions": conditions,
        "presets": presets,
        "dialogue": body_dialogue,
        "after": body_rows,
        "results": results,
        "terminals": terminals,
        "dependencies": dependencies,
        "presentation": {"status": "deferred", "resources": []},
        "unresolved": final_unresolved,
    }
    if document_choice is not None:
        document["choice"] = document_choice

    recompute_cell_classes(document, state_cells.load())

    os.makedirs(args.out, exist_ok=True)
    tracked_path = os.path.join(args.out, "%s.json" % doc_id)
    with open(tracked_path, "w", encoding="utf-8", newline="\n") as fh:
        json.dump(document, fh, indent=2, ensure_ascii=False, sort_keys=False)
        fh.write("\n")

    # --- resolved document ---------------------------------------------
    text_doc_by_entry = {entry: ped.load_text_document(args.package, entry) for entry in involved_entries}

    def resolve_dialogue_entry(entry):
        resolved = json.loads(json.dumps(entry))
        if resolved.get("kind") == "text":
            text_ref = resolved["text_ref"]
            strings = text_doc_by_entry[text_ref["entry"]]["strings"]
            text_ref["text"] = strings[text_ref["s"]]
        return resolved

    def dialogue_script(dialogue_entries):
        lines = []
        for entry in dialogue_entries:
            if entry.get("kind") == "text":
                text_ref = entry["text_ref"]
                strings = text_doc_by_entry[text_ref["entry"]]["strings"]
                lines.append("-: %s" % strings[text_ref["s"]])
            elif entry.get("kind") == "name_insert":
                lines.append("-: {name}")
            elif entry.get("kind") == "choice_point":
                lines.append("[choice_point %s]" % entry.get("choice"))
            elif entry.get("kind") == "scene_end":
                lines.append("[scene_end]")
        return lines

    def resolve_result_tree(result):
        resolved = dict(result)
        resolved["dialogue"] = [resolve_dialogue_entry(e) for e in result["dialogue"]]
        script_lines = dialogue_script(result["dialogue"])
        script_lines.append("[terminal %s]" % result["terminal"])
        resolved["script"] = script_lines
        if result.get("results"):
            resolved["results"] = {rid: resolve_result_tree(sub) for rid, sub in result["results"].items()}
        return resolved

    resolved_document = json.loads(json.dumps(document))
    resolved_document["dialogue"] = [resolve_dialogue_entry(e) for e in body_dialogue]
    resolved_document["script"] = dialogue_script(body_dialogue)
    for result_id in results.keys():
        resolved_document["results"][result_id] = resolve_result_tree(results[result_id])

    resolved_dir = args.resolved_out or args.out
    os.makedirs(resolved_dir, exist_ok=True)
    resolved_path = os.path.join(resolved_dir, "%s.resolved.json" % doc_id)
    with open(resolved_path, "w", encoding="utf-8", newline="\n") as fh:
        json.dump(resolved_document, fh, indent=2, ensure_ascii=False)
        fh.write("\n")

    def count_messages(result):
        total = len(result["dialogue"])
        for sub in (result.get("results") or {}).values():
            total += count_messages(sub)
        return total

    print("PROJECTED %s" % doc_id)
    print("body_messages=%d" % len(body_dialogue))
    for result_id, result in results.items():
        print("result %s messages=%d terminal=%s" % (result_id, count_messages(result), result["terminal"]))
    print("results=%d terminals=%d" % (len(results), len(terminals)))
    if report["missing_records"]:
        print("UNRESOLVED missing_records=%s" % [
            "%s@%d" % (r["entry"], r["at"]) for r in report["missing_records"]
        ])
    print("WROTE %s" % tracked_path)
    print("WROTE %s" % resolved_path)
    return 0


# ---------------------------------------------------------------------------
# The catalog path (rule 6). The catalog replay CLI
# (tools/content_suite/cli/replay_event_dialogue.gd) captures no caller
# prefix/resume messages (only EVENTJ04 declares an `analysis_route`, and
# even that only replays the caller's own state diff, not its messages), so
# a catalog document's flow stays scene-only, as v3's did; this is recorded
# per document in `unresolved`, the same way v3 already notes the missing
# analysis route. No witnesses exist for a catalog row (rule 6): every
# effect is decided by the `variants` rule or left `unresolved`, never by a
# shift witness; a catalog row has no typed guard, so no `order_hint` and no
# `location_line`.
# ---------------------------------------------------------------------------


def net_changes_catalog(run):
    """Net change per cell over a catalog run's own `state_changes.prefix`
    and `.callee` lists (the `.reentry` list is the done-probe's own state,
    not part of this visit)."""
    net = {}
    changes = run.get("state_changes") or {}
    for name in ("prefix", "callee"):
        for row in changes.get(name) or []:
            key = cell_key3(row)
            if key not in net:
                net[key] = {"storage": row["storage"], "bank": int(row.get("bank", 0)), "index": int(row["index"]),
                            "before": int(row["before"]), "after": int(row["after"])}
            else:
                net[key]["after"] = int(row["after"])
    return {key: value for key, value in net.items() if value["before"] != value["after"]}


def decide_effects_catalog(runs, result_label, state_cells_table, unresolved_out):
    """Rule 6's effect decision for one catalog result group: `variants`
    basis where the presets vary, else `unresolved` (no witnesses exist for
    a catalog row)."""
    nets = [net_changes_catalog(run) for run in runs]
    candidate_cells = {}
    for net in nets:
        for key in net:
            candidate_cells.setdefault(key, None)

    rows = []
    evidence = []
    for key in sorted(candidate_cells):
        storage, bank, index = key
        contributors = [net[key] for net in nets if key in net]
        if not contributors:
            continue
        if storage == "state_u16" and index in CLOCK_INDEXES:
            if index != 19:
                continue
            diffs = {clock_advance_minutes(c["before"], c["after"]) for c in contributors}
            if None not in diffs and len(diffs) == 1:
                minutes = next(iter(diffs))
                rows.append({"type": "consume_time", "minutes": minutes, "cell_class": "clock"})
                evidence.append({
                    "result": result_label, "cell": {"storage": storage, "bank": bank, "index": index},
                    "basis": "clock", "entry": contributors[0]["before"], "final": contributors[0]["after"],
                    "declared": False,
                })
            else:
                unresolved_out.append("clock state_u16[19] advance unresolved for result %s" % result_label)
            continue
        if storage == "global_u8" and all(c["before"] == 0 and c["after"] == 1 for c in contributors):
            cls = state_cells.classify(storage, bank, index, [0, 1], table=state_cells_table)
            rows.append({"type": "write_legacy_value", "storage": storage, "bank": bank, "index": index, "value": 1, "cell_class": cls})
            evidence.append({
                "result": result_label, "cell": {"storage": storage, "bank": bank, "index": index},
                "basis": "flag_pattern", "entry": 0, "final": 1, "declared": False,
            })
            continue
        befores = {c["before"] for c in contributors}
        finals = {c["after"] for c in contributors}
        deltas = {c["after"] - c["before"] for c in contributors}
        if len(befores) == 1 and len(finals) == 1:
            value = finals.pop()
            cls = state_cells.classify(storage, bank, index, [value], table=state_cells_table)
            rows.append({"type": "write_legacy_value", "storage": storage, "bank": bank, "index": index, "value": value, "cell_class": cls})
            evidence.append({
                "result": result_label, "cell": {"storage": storage, "bank": bank, "index": index},
                "basis": "variants", "entry": sorted(befores)[0], "final": value, "declared": False,
            })
        elif len(finals) == 1:
            value = finals.pop()
            cls = state_cells.classify(storage, bank, index, [value], table=state_cells_table)
            rows.append({"type": "write_legacy_value", "storage": storage, "bank": bank, "index": index, "value": value, "cell_class": cls})
            evidence.append({
                "result": result_label, "cell": {"storage": storage, "bank": bank, "index": index},
                "basis": "variants", "entry": sorted(befores)[0], "final": value, "declared": False,
            })
        elif len(deltas) == 1:
            delta = deltas.pop()
            cls = state_cells.classify(storage, bank, index, sorted(finals), table=state_cells_table)
            rows.append({"type": "add_legacy_value", "storage": storage, "bank": bank, "index": index, "delta": delta, "cell_class": cls})
            evidence.append({
                "result": result_label, "cell": {"storage": storage, "bank": bank, "index": index},
                "basis": "variants", "entry": sorted(befores)[0], "final": sorted(finals)[0], "declared": False,
            })
        else:
            unresolved_out.append(
                "effect on %s[%d] for result %s: no witnesses exist for a catalog row and the presets do not "
                "agree on a single final value or delta" % (storage, index, result_label)
            )
    return rows, evidence


def run_catalog(args):
    catalog = ped.load_json(args.catalog)
    event = ped.find_event(catalog, args.event)
    if event is None:
        print("EVENT NOT FOUND: %s" % args.event)
        return 1

    registry, names_fingerprint = ped.load_registry(args.names)
    row = ped.find_registry_row(registry, args.event)
    if row is None:
        print("REGISTRY ROW NOT FOUND for %s" % args.event)
        return 1
    if names_fingerprint == "unrecorded":
        print("names_fingerprint: unrecorded (registry at %s has no names_fingerprint file)" % args.names)
    else:
        print("names_fingerprint=%s" % names_fingerprint)

    manifest = ped.load_json(os.path.join(args.package, "manifest.json"))
    replay = ped.load_json(args.replay)
    if replay["archive_sha256"] != manifest["source"]["archive_sha256"]:
        print("ARCHIVE MISMATCH between replay and package manifest")
        return 1

    report = {"missing_records": [], "missing_text_operand": []}

    doc_id = row["id"]
    display = {
        "title_ko": row.get("title_ko", ""), "title_en": row.get("title_en", ""),
        "heroine": row.get("heroine", ""), "category": row.get("category", ""), "place": row.get("place", ""),
    }

    callee = event["source"]["callee"]
    caller = event["source"]["caller"]
    event_presets = event.get("presets") or [{"preset_id": "baseline", "label": "baseline", "writes": []}]
    members = [{"entry": callee["entry"], "entry_sha256": callee["entry_sha256"]}]
    for required in event["source"].get("required_entries", []):
        members.append({"entry": required["entry"], "entry_sha256": required["entry_sha256"]})

    package_binding = {"schema": manifest["schema"], "package_sha256": manifest["package_sha256"]}

    catalog_extra_unresolved = [
        "catalog replay carries no caller prefix or resume messages (tools/content_suite/cli/"
        "replay_event_dialogue.gd replays the callee scene only); the flow is scene-only",
    ]
    if "analysis_route" in event:
        origin_offset = int(event["analysis_route"]["caller_start_coordinate"])
    else:
        origin_offset = int(event["source"]["caller"]["dispatch_offset"])
        catalog_extra_unresolved.append(
            "no analysis route recorded in the catalog: the caller prefix was not replayed; "
            "origin is the dispatch record itself"
        )

    trigger = {
        "type": "caller_dispatch",
        "caller": {
            "entry": caller["entry"], "entry_sha256": caller["entry_sha256"],
            "offset": int(caller["dispatch_offset"]), "end": int(caller["resume_offset"]),
            "command": int(caller["command"]), "kind": "root_handoff" if int(caller["command"]) == 14 else "nested_call",
        },
        "callee": {
            "entry": callee["entry"], "entry_sha256": callee["entry_sha256"],
            "start_coordinate": int(callee["start_coordinate"]),
        },
        "origin": {"kind": "caller_prefix", "offset": origin_offset},
    }

    choices = event.get("choices", [])
    if len(choices) > 1:
        print("MULTIPLE CHOICE ROWS not supported: %s" % [c.get("choice_id") for c in choices])
        return 1
    kind = "choice_event" if choices else "event"

    done_flag = None
    for terminal in event.get("terminals", []):
        for req in terminal.get("required_state", []):
            if req.get("operator") == "equals" and int(req.get("value", -1)) == 1:
                done_flag = req
                break
        if done_flag:
            break
    conditions = []
    if done_flag is not None:
        conditions.append({
            "type": "event_not_completed", "event_id": doc_id, "failure_reason": "already_completed",
            "done_cell": {
                "storage": done_flag["storage"], "bank": int(done_flag.get("bank", 0)),
                "index": int(done_flag["index"]), "value": int(done_flag["value"]),
            },
            "source": "reentry_probe",
        })

    presets = []
    presets_by_id = {}
    for preset in event_presets:
        presets_by_id[preset["preset_id"]] = preset
        presets.append({
            "preset_id": preset["preset_id"], "label": preset.get("label", ""),
            "writes": ped.absolute_rows(preset["writes"]),
        })

    runs_by_preset = {run["preset_id"]: run for run in replay["runs"]}

    terminals = {}
    terminal_id_by_offset = {}
    for terminal in event.get("terminals", []):
        v3_kind = ped.catalog_terminal_kind(terminal)
        terminals[terminal["terminal_id"]] = {
            "kind": v3_kind, "owner_entry": terminal["owner_entry"],
            "offset": int(terminal["offset"]), "end": int(terminal["caller_resume_offset"]),
            "next_target": terminal.get("next_target", ""),
            "required_state": ped.absolute_rows([
                {"storage": r["storage"], "bank": r.get("bank", 0), "index": r["index"], "value": r["value"]}
                for r in terminal.get("required_state", [])
            ]),
        }
        terminal_id_by_offset[int(terminal["offset"])] = terminal["terminal_id"]

    involved_entries = {callee["entry"]}
    for run in replay["runs"]:
        for message in run["messages"]:
            involved_entries.add(message["entry"])
    events_doc_by_entry = {entry: ped.load_events_document(args.package, entry) for entry in involved_entries}

    def marked_messages(messages, event_played, choice_marker=None):
        out = list(messages)
        if event_played:
            out.append(_marker_message("scene_end"))
        if choice_marker is not None:
            boundary, owner_entry = choice_marker
            insert_at = None
            for i, m in enumerate(out):
                if not _is_marker(m) and m["entry"] == owner_entry and int(m["offset"]) > boundary:
                    insert_at = i
                    break
            if insert_at is None:
                last_owner = None
                for i, m in enumerate(out):
                    if not _is_marker(m) and m["entry"] == owner_entry:
                        last_owner = i
                insert_at = (last_owner + 1) if last_owner is not None else len(out)
            out.insert(insert_at, _marker_message("choice_point", "top"))
        return out

    all_message_lists = [marked_messages(run["messages"], len(run["messages"]) > 0) for run in replay["runs"]]
    body_messages = ped.longest_common_prefix(all_message_lists)

    empty_shared_lines = set()
    body_dialogue = build_dialogue_list_v4(body_messages, set(), events_doc_by_entry, report, None, caller["entry"], empty_shared_lines)
    if body_dialogue is None:
        print("FATAL missing_text_operand in the body: %s" % report["missing_text_operand"])
        return 1

    document_choice = None
    leaf_pairs_by_id = {}
    results = {}

    if choices:
        choice_row = choices[0]
        owner_entry = callee["entry"] if choice_row["owner_entry"] == callee["entry"] else caller["entry"]
        owner = "callee" if owner_entry == callee["entry"] else "caller"
        boundary = int(choice_row["boundary_offset"])
        body_len = len(body_messages)

        candidates = []
        for run in replay["runs"]:
            option = run.get("option")
            option_int = int(option) if option is not None else None
            marked = marked_messages(run["messages"], len(run["messages"]) > 0, (boundary, owner_entry))
            candidates.append({
                "preset_id": run["preset_id"], "option": option_int,
                "messages": marked, "run": run,
                "terminal_sig": (
                    run["terminal"]["entry"], run["terminal"]["status"],
                    int(run["terminal"]["offset"]), run["terminal"].get("target", ""),
                ),
            })

        def resolve_catalog_node(result_id, node):
            rep_run = node["representative"]["run"]
            dialogue = build_dialogue_list_v4(node["dialogue_messages"], set(), events_doc_by_entry, report, None, caller["entry"], empty_shared_lines)
            if dialogue is None:
                return None
            terminal_offset = int(rep_run["terminal"].get("offset", -1))
            reentry_source = rep_run.get("reentry")
            reentry = None
            if reentry_source is not None:
                reentry = {"kind": "callee_return", "message_count": int(reentry_source["message_count"]), "effects": []}
            resolved = {
                "selected_by": node["selected_by"], "event_played": node["event_played"],
                "dialogue": dialogue, "after": [], "terminal": terminal_id_by_offset.get(terminal_offset),
                "reentry": reentry,
            }
            if node.get("results") is not None:
                sub_results = {}
                for sub_id, sub_node in node["results"].items():
                    sub_resolved = resolve_catalog_node(sub_id, sub_node)
                    if sub_resolved is None:
                        return None
                    sub_results[sub_id] = sub_resolved
                resolved["results"] = sub_results
            else:
                runs_for_group = [c["run"] for c in node["group"]]
                rows, evidence_rows = decide_effects_catalog(runs_for_group, result_id, state_cells.load(), after_unresolved)
                leaf_pairs_by_id[result_id] = list(zip(rows, evidence_rows))
            return resolved

        after_unresolved = []
        try:
            option_values = sorted({c["option"] for c in candidates if c["option"] is not None})
            for value in option_values:
                group = [c for c in candidates if c["option"] == value]
                node = ped.build_condition_node_catalog(event, group, body_len, presets_by_id)
                node["selected_by"] = {"kind": "choice", "value": value}
                resolved = resolve_catalog_node("answer%d" % value, node)
                if resolved is None:
                    print("FATAL missing_text_operand in result answer%d: %s" % (value, report["missing_text_operand"]))
                    return 1
                results["answer%d" % value] = resolved
        except ped.ReproductionMismatch as exc:
            print("REPRODUCTION MISMATCH: %s" % exc)
            return 1

        document_choice = {
            "owner": owner, "boundary": boundary,
            "position": "in_event" if owner == "callee" else "before_event",
            "options": [{"value": v, "result": "answer%d" % v} for v in option_values],
        }
    else:
        after_unresolved = []
        groups = {}
        group_order = []
        for preset in event_presets:
            preset_id = preset["preset_id"]
            run = runs_by_preset.get(preset_id)
            if run is None:
                continue
            marked = marked_messages(run["messages"], len(run["messages"]) > 0)
            msg_keys = tuple(ped.message_key(m) for m in marked)
            terminal_sig = (
                run["terminal"].get("offset"), run["terminal"].get("end"),
                run["terminal"].get("target"), run["terminal"].get("status"),
            )
            signature = (msg_keys, terminal_sig)
            groups.setdefault(signature, []).append((preset_id, marked, run))
            if signature not in group_order:
                group_order.append(signature)

        for signature in group_order:
            members_in_group = groups[signature]
            representative_id, representative_marked, representative_run = members_in_group[0]
            representative_preset = presets_by_id[representative_id]
            arms = ped.matched_branches(event, representative_preset)
            result_id = ".".join(b["branch_id"] for b in arms) if arms else representative_id

            body_len = len(body_messages)
            if [ped.message_key(m) for m in representative_marked[:body_len]] != [ped.message_key(m) for m in body_messages]:
                print("BODY PREFIX MISMATCH for %s" % result_id)
                return 1
            remainder = representative_marked[body_len:]
            result_dialogue = build_dialogue_list_v4(remainder, set(), events_doc_by_entry, report, None, caller["entry"], empty_shared_lines)
            if result_dialogue is None:
                print("FATAL missing_text_operand in result %s: %s" % (result_id, report["missing_text_operand"]))
                return 1

            conditions_rows = []
            for branch in arms:
                for c in branch.get("conditions", []):
                    conditions_rows.append({
                        "storage": c["storage"], "bank": int(c.get("bank", 0)),
                        "index": int(c["index"]), "operator": c["operator"], "value": int(c["value"]),
                    })

            terminal_offset = int(representative_run["terminal"].get("offset", -1))
            terminal_id = terminal_id_by_offset.get(terminal_offset)
            reentry_source = representative_run.get("reentry")
            reentry = None
            if reentry_source is not None:
                reentry = {"kind": "callee_return", "message_count": int(reentry_source["message_count"]), "effects": []}

            runs_for_group = [run for _pid, _marked, run in members_in_group]
            rows, evidence_rows = decide_effects_catalog(runs_for_group, result_id, state_cells.load(), after_unresolved)
            leaf_pairs_by_id[result_id] = list(zip(rows, evidence_rows))

            results[result_id] = {
                "selected_by": {"kind": "condition", "conditions": conditions_rows},
                "event_played": True,
                "dialogue": result_dialogue,
                "after": [],
                "terminal": terminal_id,
                "reentry": reentry,
            }

    body_rows, body_evidence, remaining_by_id = promote_shared_rows_with_evidence(leaf_pairs_by_id)

    def apply_effects(tree_results):
        for rid, result in tree_results.items():
            if rid in remaining_by_id:
                result["after"] = [row for row, _ev in remaining_by_id[rid]]
            if result.get("results") is not None:
                apply_effects(result["results"])

    apply_effects(results)
    all_evidence = list(body_evidence)
    for rid in remaining_by_id:
        all_evidence.extend(ev for _row, ev in remaining_by_id[rid])

    dependencies = []
    for required in event["source"].get("required_entries", []):
        dependencies.append({
            "entry": required["entry"], "entry_sha256": required["entry_sha256"], "role": required.get("role", ""),
        })

    presentation = {"status": "deferred", "resources": event.get("resources", [])}
    unresolved = [blocker["summary"] for blocker in event.get("blockers", [])] + catalog_extra_unresolved + after_unresolved

    evidence = {
        "kind": "catalog_event", "archive_sha256": replay["archive_sha256"],
        "catalog_id": catalog["catalog_id"], "catalog_revision": catalog["catalog_revision"],
        "groups": [], "members": members, "document_refs": event.get("activation", {}).get("document_refs", []),
        "effect_witnesses": all_evidence,
    }

    document = {
        "schema_version": SCHEMA_VERSION,
        "contract_fingerprint": ped.resolve_contract_fingerprint(args.contract_fingerprint),
        "names_fingerprint": names_fingerprint,
        "id": doc_id, "kind": kind, "display": display, "evidence": evidence,
        "package_binding": package_binding, "trigger": trigger, "scenes": [], "guard": None,
        "conditions": conditions, "presets": presets, "dialogue": body_dialogue, "after": body_rows,
        "results": results, "terminals": terminals, "dependencies": dependencies,
        "presentation": presentation, "unresolved": list(dict.fromkeys(unresolved)),
    }
    if document_choice is not None:
        document["choice"] = document_choice

    recompute_cell_classes(document, state_cells.load())

    os.makedirs(args.out, exist_ok=True)
    tracked_path = os.path.join(args.out, "%s.json" % doc_id)
    with open(tracked_path, "w", encoding="utf-8", newline="\n") as fh:
        json.dump(document, fh, indent=2, ensure_ascii=False, sort_keys=False)
        fh.write("\n")

    text_doc_by_entry = {entry: ped.load_text_document(args.package, entry) for entry in involved_entries}

    def resolve_dialogue_entry(entry):
        resolved = json.loads(json.dumps(entry))
        if resolved.get("kind") == "text":
            text_ref = resolved["text_ref"]
            strings = text_doc_by_entry[text_ref["entry"]]["strings"]
            text_ref["text"] = strings[text_ref["s"]]
        return resolved

    def resolve_result_tree(result_id, result_node):
        resolved = dict(result_node)
        resolved["dialogue"] = [resolve_dialogue_entry(e) for e in result_node["dialogue"]]
        if result_node.get("results"):
            resolved["results"] = {sid: resolve_result_tree(sid, sub) for sid, sub in result_node["results"].items()}
        return resolved

    resolved_document = json.loads(json.dumps(document))
    resolved_document["dialogue"] = [resolve_dialogue_entry(e) for e in body_dialogue]
    resolved_document["results"] = {rid: resolve_result_tree(rid, result) for rid, result in results.items()}

    resolved_dir = args.resolved_out or args.out
    os.makedirs(resolved_dir, exist_ok=True)
    resolved_path = os.path.join(resolved_dir, "%s.resolved.json" % doc_id)
    with open(resolved_path, "w", encoding="utf-8", newline="\n") as fh:
        json.dump(resolved_document, fh, indent=2, ensure_ascii=False)
        fh.write("\n")

    print("PROJECTED %s" % doc_id)
    print("body_messages=%d results=%d" % (len(body_dialogue), len(results)))
    print("WROTE %s" % tracked_path)
    print("WROTE %s" % resolved_path)
    return 0


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--catalog")
    parser.add_argument("--event")
    parser.add_argument("--site")
    parser.add_argument("--profiles-dir", default=os.path.join("config", "event_catalog", "analysis_groups"))
    parser.add_argument("--replays-dir", default=os.path.join("analysis", "replays_v2"))
    parser.add_argument("--witnesses-dir", default=os.path.join("analysis", "witnesses"))
    parser.add_argument("--names", required=True)
    parser.add_argument("--package", required=True)
    parser.add_argument("--replay")
    parser.add_argument("--arc", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--resolved-out", default=None)
    parser.add_argument("--shared-lines", default=None)
    parser.add_argument(
        "--contract-fingerprint",
        default=os.path.join("config", "contracts", "event_definition_v4", "contract_fingerprint"),
    )
    args = parser.parse_args()

    if bool(args.event) == bool(args.site):
        print("exactly one of --event or --site is required")
        return 1
    if args.event:
        if not args.catalog or not args.replay:
            print("--event requires --catalog and --replay")
            return 1
        return run_catalog(args)
    return run_site(args)


if __name__ == "__main__":
    sys.exit(main())
