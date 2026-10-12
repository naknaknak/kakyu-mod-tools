"""Batch-projects every row of the event name registry into a
`kakyu_event_definition/v3` document (WD-22 widening, part B).

A catalog row (`aliases.catalog_event_id` present) runs the catalog path of
`tools/project_event_definition.py`, replaying it first with
`tools/content_suite/cli/replay_event_dialogue.gd` through the Godot console
executable when `analysis/replays/catalog_<stem>.json` does not already
exist; every other row runs the profile ("--site") path. Each projection is
a subprocess of `project_event_definition.py`. Every written document is
then validated (default on) with `tools/validate_event_definition.py`.
Writes `<out>/index.json` and exits 1 when any document is invalid or any
projection/replay failed.

    py tools/project_event_definitions_batch.py --names config/contracts/event_names_v1 \
        --catalog config/event_catalog/original_events_v1.json \
        --profiles-dir config/event_catalog/analysis_groups --replays-dir analysis/replays \
        --package analysis/playback_package_0323 --arc "<mes.arc>" --out analysis/event_definitions_0323 \
        [--elfimage "<ELFIMAGE dir>"] [--only <id> ...] [--no-validate] [--jobs N]

`--only` projects just those ids and **merges** their rows into the `index.json` already in `--out`
(rows replaced by id, `summary` recomputed over the merged rows, fingerprints kept); the existing index
must be bound to the same contract, names registry, package and cells fingerprints, else the run is
refused before it projects anything. Without an existing index `--only` writes one holding only those
rows. A site whose projection fails is recorded as `projection_failed` with its subprocess `exit_code`
and the last lines of its `stdout_tail` and `stderr_tail` (the producers print their refusals on
stdout), in its index row and under its line of the summary table.
"""
from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TOOLS_DIR = Path(__file__).resolve().parent
PROJECT_SCRIPT = TOOLS_DIR / "project_event_definition.py"
PROJECT_SCRIPT_V4 = TOOLS_DIR / "project_event_definition_v4.py"
PROJECT_SCRIPT_V5 = TOOLS_DIR / "project_event_definition_v5.py"
PROJECT_SCRIPT_V6 = TOOLS_DIR / "project_event_definition_v6.py"
PROJECT_SCRIPT_V7 = TOOLS_DIR / "project_event_definition_v7.py"
VALIDATE_SCRIPT = TOOLS_DIR / "validate_event_definition.py"

# EP-12 / WD unit 2 (2026-09-25): a `kakyu_event_analysis_group/v14` flow
# route (the three `01m-a-date` sites) carries no `caller`/`callee` pair, so
# neither `ped.resolve_site` (now schema-guarded, see project_event_definition.py)
# nor `ped4.resolve_site_v4`'s evidence fallback ever matches one; both
# return an empty match list for such a row instead of raising. This helper
# tells the batch driver's own dispatch (never the site-evidence path) which
# rows those are, purely from the registry row's own `aliases.groups` and
# the profiles' own `schema` field - no crash, no v4/v5 behaviour change
# (neither ever saw these rows before this unit).
FLOW_PROFILE_SCHEMA = "kakyu_event_analysis_group/v14"
REPLAY_CLI = "res://tools/content_suite/cli/replay_event_dialogue.gd"

sys.path.insert(0, str(TOOLS_DIR))
import project_event_definition as ped  # noqa: E402
import project_event_definition_v4 as ped4  # noqa: E402
from payload_values import MEDIA_KINDS as RESOURCE_KINDS  # noqa: E402

# The station replay analysis/replay_j04.json (Core 0.323.0) predates this
# tool's analysis/replays/catalog_<stem>.json convention; reuse it for
# EVENTJ04 instead of running Godot a 13th time.
J04_EVENT_ID = "original/eventj04/01m-00009b85"
J04_EXISTING_REPLAY = ROOT / "analysis" / "replay_j04.json"


# How many trailing non-empty lines of a failed projection's stdout and stderr its index row keeps.
FAILURE_TAIL_LINES = 6
FAILURE_LINE_LIMIT = 300
# The header fields an existing index must share with the run for `--only` to merge into it.
INDEX_HEADER_FIELDS = ("schema", "contract_fingerprint", "names_fingerprint", "package_sha256", "cells_fingerprint")


def output_tail(text, lines=FAILURE_TAIL_LINES):
    """The last `lines` non-empty lines of a subprocess stream, each cut to `FAILURE_LINE_LIMIT`."""
    if isinstance(text, bytes):
        text = text.decode("utf-8", "replace")
    kept = [line.rstrip() for line in (text or "").splitlines() if line.strip()]
    return [line[:FAILURE_LINE_LIMIT] for line in kept[-lines:]]


def merge_index_documents(existing_rows, new_rows):
    """`existing_rows` with the rows of `new_rows` replacing the ones of the same `id` (and inserted
    when absent). An existing list in id order stays in id order, which is the registry's; any other
    order keeps its rows in place and appends the new ones."""
    by_id = {row["id"]: row for row in existing_rows}
    existing_ids = [row["id"] for row in existing_rows]
    for row in new_rows:
        by_id[row["id"]] = row
    if existing_ids == sorted(existing_ids):
        return [by_id[doc_id] for doc_id in sorted(by_id)]
    appended = [row["id"] for row in new_rows if row["id"] not in existing_ids]
    return [by_id[doc_id] for doc_id in existing_ids + appended]


def index_summary(documents):
    projected = sum(1 for d in documents if d.get("kind") is not None)
    valid = sum(1 for d in documents if d.get("ok"))
    return {"projected": projected, "valid": valid, "invalid": len(documents) - valid}


def index_merge_refusal(existing, header):
    """Why `existing` (a parsed `index.json`) cannot take `--only` rows of a run whose index header
    is `header`; None when it can."""
    if not isinstance(existing, dict) or not isinstance(existing.get("documents"), list):
        return "the existing index.json is not an index (no documents list)"
    for field in INDEX_HEADER_FIELDS:
        if existing.get(field) != header.get(field):
            return "the existing index.json differs in %s (%s, this run %s); regenerate without --only" % (
                field, existing.get(field), header.get(field))
    return None


def positive_int(text):
    value = int(text)
    if value < 1:
        raise argparse.ArgumentTypeError("must be at least 1")
    return value


def load_json(path):
    with open(path, "r", encoding="utf-8") as fh:
        return json.load(fh)


def registry_rows(names_dir):
    registry = load_json(Path(names_dir) / "event_names.json")
    rows = registry["rows"]
    return [rows[key] for key in sorted(rows.keys())]


def find_godot(explicit):
    """Same discovery order as tools/content_suite/run_headless_validation.py,
    copied (not imported) to keep this tool a standalone subprocess driver."""
    if explicit:
        candidate = Path(explicit).expanduser().resolve()
        if candidate.is_file():
            return candidate
        raise ValueError("Godot executable does not exist: %s" % candidate)
    configured = os.environ.get("GODOT4_CONSOLE")
    if configured:
        candidate = Path(configured).expanduser().resolve()
        if candidate.is_file():
            return candidate
        raise ValueError("GODOT4_CONSOLE does not exist: %s" % candidate)
    for name in ("godot4.7", "godot4", "godot", "Godot_v4.7-stable_win64_console.exe"):
        resolved = shutil.which(name)
        if resolved:
            return Path(resolved).resolve()
    if os.name == "nt":
        local_app_data = os.environ.get("LOCALAPPDATA")
        if local_app_data:
            package_root = Path(local_app_data) / "Microsoft" / "WinGet" / "Packages"
            matches = sorted(package_root.glob("GodotEngine.GodotEngine_*/*_console.exe"), reverse=True)
            if matches:
                return matches[0].resolve()
    return None


def catalog_stem(event_id):
    """`original/eventb15/11m-0000347b` -> `eventb15`: the filesystem-safe
    stem for `analysis/replays/catalog_<stem>.json`."""
    parts = event_id.split("/")
    return parts[1] if len(parts) > 1 else event_id.replace("/", "_")


def ensure_catalog_replay(event_id, replays_dir, elfimage_dir, catalog_path, godot_exe):
    """Returns the replay file path for `event_id`, generating it with Godot
    if neither the conventional path nor (for EVENTJ04 only) the pre-existing
    analysis/replay_j04.json already carries it."""
    stem = catalog_stem(event_id)
    target = Path(replays_dir) / ("catalog_%s.json" % stem)
    if target.is_file():
        return target
    if event_id == J04_EVENT_ID and J04_EXISTING_REPLAY.is_file():
        return J04_EXISTING_REPLAY
    if not elfimage_dir:
        raise RuntimeError("no replay for %s and --elfimage was not given" % event_id)
    if not godot_exe:
        raise RuntimeError("no replay for %s and Godot was not found (pass --godot)" % event_id)
    target.parent.mkdir(parents=True, exist_ok=True)
    cmd = [
        str(godot_exe), "--headless", "--path", str(ROOT),
        "--script", REPLAY_CLI, "--",
        str(elfimage_dir), str(catalog_path), event_id, str(target),
    ]
    # Every Godot subprocess is wrapped in a timeout: a SCRIPT ERROR raised
    # from _init (e.g. a missing analysis_route before the WD-22 fallback)
    # leaves headless Godot idle forever rather than exiting, so a timeout
    # is a real, expected failure mode here, not just a slow run.
    try:
        completed = subprocess.run(cmd, capture_output=True, text=True, cwd=str(ROOT), timeout=600)
    except subprocess.TimeoutExpired as exc:
        tail = _tail_text(exc.stdout, exc.stderr)
        raise RuntimeError(
            "replay_event_dialogue.gd timed out after 600s for %s (a SCRIPT ERROR in _init leaves headless "
            "Godot idle forever instead of exiting): %s" % (event_id, tail)
        )
    if completed.returncode != 0 or not target.is_file():
        raise RuntimeError(
            "replay_event_dialogue.gd failed for %s (exit %s): %s" % (
                event_id, completed.returncode, _tail_text(completed.stdout, completed.stderr),
            )
        )
    return target


def _tail_text(stdout, stderr, limit=2000):
    def _text(value):
        if value is None:
            return ""
        if isinstance(value, bytes):
            return value.decode("utf-8", "replace")
        return value
    return (_text(stdout) + _text(stderr))[-limit:]


def run_projection(cmd_args, script=PROJECT_SCRIPT):
    return subprocess.run(
        [sys.executable, str(script)] + cmd_args,
        capture_output=True, text=True, cwd=str(ROOT),
    )


def run_validation(doc_path, names_dir, package_dir, fingerprint):
    completed = subprocess.run(
        [sys.executable, str(VALIDATE_SCRIPT), str(doc_path), "--names", str(names_dir),
         "--package", str(package_dir), "--fingerprint", fingerprint],
        capture_output=True, text=True, cwd=str(ROOT),
    )
    try:
        lines = [line for line in completed.stdout.splitlines() if line.strip()]
        return json.loads(lines[-1])
    except Exception:
        return {
            "ok": False, "reason": "validator_crashed",
            "detail": (completed.stdout + completed.stderr)[-2000:],
        }


def compute_shared_lines(rows, names_dir, profiles_dir, replays_v2_dir):
    """The v4 batch driver's shared-line index (`docs/spec/data/
    event_definition_v4_design.md`'s "Location lines"): `{"<CALLER>":
    [[entry, at], ...]}` of a caller's own prefix messages (`entry`/`at`
    from its first reached, first-listed variant's `prefix_messages`) that
    precede more than one event site of that caller (evidence kind
    `analysis_group` only: a catalog row's prefix was never replayed)."""
    profiles = ped.load_profiles(profiles_dir)
    by_caller: dict[str, dict[str, set]] = {}
    for row in rows:
        matches = ped4.resolve_site_v4(row, profiles)
        if not matches:
            continue
        preferred = ped.choose_preferred(matches)
        stem = preferred["stem"]
        r1 = preferred["routes"][0]
        caller_entry = r1["caller"]["entry"]
        replay_path = Path(replays_v2_dir) / ("%s.json" % stem)
        if not replay_path.is_file():
            continue
        replay_doc = load_json(replay_path)
        replay_route = next((r for r in replay_doc.get("routes", []) if r["route_id"] == r1["route_id"]), None)
        if replay_route is None:
            continue
        first_variant = next((v for v in replay_route.get("variants", []) if v.get("reached", True)), None)
        if first_variant is None:
            continue
        prefix_offsets = {
            (m["entry"], int(m["offset"])) for m in (first_variant.get("prefix_messages") or [])
        }
        by_caller.setdefault(caller_entry, {})[row["id"]] = prefix_offsets

    shared: dict[str, list] = {}
    for caller_entry, site_offsets in by_caller.items():
        counts: dict[tuple, int] = {}
        for offsets in site_offsets.values():
            for pair in offsets:
                counts[pair] = counts.get(pair, 0) + 1
        lines = sorted([list(pair) for pair, n in counts.items() if n > 1])
        if lines:
            shared[caller_entry] = lines
    return shared


def flow_group_ids(profiles):
    return {doc.get("group_id") for doc in profiles.values() if doc.get("schema") == FLOW_PROFILE_SCHEMA}


def row_is_flow(row, flow_gids):
    return any(g.get("group_id") in flow_gids for g in row.get("aliases", {}).get("groups", []) or [])


def count_results(results):
    n = 0
    for result in (results or {}).values():
        n += 1
        if result.get("results"):
            n += count_results(result["results"])
    return n


def summarize_document(doc_path):
    doc = load_json(doc_path)
    return {
        "kind": doc.get("kind"),
        "results": count_results(doc.get("results", {})),
        "terminals": len(doc.get("terminals", {})),
        "body_messages": len(doc.get("dialogue", [])),
    }


def _walk_effect_rows(document):
    for row in document.get("after") or []:
        yield row

    def walk_results(results):
        for result in (results or {}).values():
            for row in result.get("after") or []:
                yield row
            yield from walk_results(result.get("results"))

    yield from walk_results(document.get("results"))


def _walk_dialogue_entries(document):
    for entry in document.get("dialogue") or []:
        yield entry

    def walk_results(results):
        for result in (results or {}).values():
            for entry in result.get("dialogue") or []:
                yield entry
            yield from walk_results(result.get("results"))

    yield from walk_results(document.get("results"))


def summarize_document_v4(doc_path):
    doc = load_json(doc_path)
    row_types = {}
    row_bases = {}
    declared_false = 0
    for row in _walk_effect_rows(doc):
        row_types[row.get("type")] = row_types.get(row.get("type"), 0) + 1
    for witness in (doc.get("evidence") or {}).get("effect_witnesses", []) or []:
        row_bases[witness.get("basis")] = row_bases.get(witness.get("basis"), 0) + 1
        if witness.get("declared") is False:
            declared_false += 1
    location_lines = 0
    choice_points = 0
    scene_ends = 0
    for entry in _walk_dialogue_entries(doc):
        kind = entry.get("kind")
        if entry.get("location_line"):
            location_lines += 1
        if kind == "choice_point":
            choice_points += 1
        elif kind == "scene_end":
            scene_ends += 1
    order_hint = (doc.get("trigger") or {}).get("order_hint")
    done_cell_source = None
    for condition in doc.get("conditions") or []:
        if condition.get("type") == "event_not_completed" and "done_cell" in condition:
            done_cell_source = condition.get("source")
            break
    return {
        "kind": doc.get("kind"),
        "results": count_results(doc.get("results", {})),
        "terminals": len(doc.get("terminals", {})),
        "body_messages": len(doc.get("dialogue", [])),
        "effect_rows_by_type": row_types,
        "effect_rows_by_basis": row_bases,
        "effect_rows_declared_false": declared_false,
        "location_lines": location_lines,
        "choice_points": choice_points,
        "scene_ends": scene_ends,
        "order_hint": order_hint is not None,
        "order_hint_chain_confirmed": bool(order_hint and order_hint.get("chain_confirmed")),
        "done_cell_source": done_cell_source,
        "unresolved": list(doc.get("unresolved") or []),
    }


WITNESS_STATUS_PREFIX = "WITNESS_STATUS "


def witness_preflight(witnesses_dir):
    """TD-37: `None` when both halves of the witness corpus exist, else the
    refusal text. The producer reads `<witnesses_dir>/<stem>.json` and
    `<witnesses_dir>/../witness_requests/<stem>.json`; a regeneration whose
    corpus directories are absent must not silently drop every witness-derived
    row (the v6 set lost them from `f9a2454` to `TD-37`)."""
    requests_dir = os.path.normpath(os.path.join(witnesses_dir, "..", "witness_requests"))
    missing = [d for d in (witnesses_dir, requests_dir) if not os.path.isdir(d)]
    if not missing:
        return None
    return ("witness corpus directory not found: %s; regenerate it (tools/plan_event_effect_witnesses.py, then "
            "validate_event_analysis_group.gd --witness) or pass --allow-missing-witnesses" % ", ".join(missing))


def parse_witness_status(stdout):
    """The producer's `WITNESS_STATUS site=... stems=N requests=N
    results_used=N missing=N` line as a dict of ints (`None` when absent)."""
    for line in (stdout or "").splitlines():
        if not line.startswith(WITNESS_STATUS_PREFIX):
            continue
        fields = dict(part.split("=", 1) for part in line[len(WITNESS_STATUS_PREFIX):].split() if "=" in part)
        try:
            return {key: int(fields[key]) for key in ("stems", "requests", "results_used", "missing")}
        except (KeyError, ValueError):
            return None
    return None


def witness_summary_line(statuses, documents):
    """The v6 batch's witness summary: how many sites had witness results,
    how many requests/results the producers read, and the witness-derived
    rows the documents carry (`shift_witness`-basis evidence rows, documents
    whose done cell came from the re-entry probe), counted from the index
    entries. The index itself carries no new field."""
    shift_rows = sum(int((d.get("effect_rows_by_basis") or {}).get("shift_witness", 0)) for d in documents)
    reentry = sum(1 for d in documents if d.get("done_cell_source") == "reentry_probe")
    return (
        "witnesses: sites_with_results=%d sites_without_witnesses=%d requests=%d results_used=%d "
        "shift_witness_rows=%d reentry_probe_documents=%d" % (
            sum(1 for s in statuses if s["results_used"] > 0), sum(1 for s in statuses if s["missing"] > 0),
            sum(s["requests"] for s in statuses), sum(s["results_used"] for s in statuses),
            shift_rows, reentry,
        )
    )


RESOURCES_STATUS_PREFIX = "RESOURCES_STATUS "


def parse_resources_status(stdout):
    """The v7 producer's `RESOURCES_STATUS site=... items=N runs=N route=N def=N
    lib_excluded=N mmo=N ... unclassified=N` line (`project_event_definition_v7.py`) as a dict
    (`site` a string, the rest ints); `None` when absent or malformed."""
    for line in (stdout or "").splitlines():
        if not line.startswith(RESOURCES_STATUS_PREFIX):
            continue
        fields = dict(part.split("=", 1) for part in line[len(RESOURCES_STATUS_PREFIX):].split() if "=" in part)
        try:
            status = {key: int(fields[key]) for key in ("items", "runs", "route", "def", "lib_excluded") + RESOURCE_KINDS}
            status["site"] = fields["site"]
            return status
        except (KeyError, ValueError):
            return None
    return None


def resources_summary_line(statuses, expected_sites):
    """The v7 batch's resources summary: the document count, how many have an empty list, the
    per-kind and per-entry-class item totals (summed over documents, so an occurrence two
    documents share counts in both), the library occurrences left out by the TD-56 rule and the
    largest list. `expected_sites` is the number of documents the batch projected; a site whose
    producer printed no status line is counted as `without_status`."""
    kinds = {kind: sum(s[kind] for s in statuses) for kind in RESOURCE_KINDS}
    largest = max(statuses, key=lambda s: (s["items"], s["site"]), default=None)
    return (
        "resources: documents=%d without_status=%d empty=%d items=%d route=%d def=%d lib_excluded=%d "
        "kinds={%s} largest=%d (%s)" % (
            len(statuses), expected_sites - len(statuses), sum(1 for s in statuses if s["items"] == 0),
            sum(s["items"] for s in statuses), sum(s["route"] for s in statuses), sum(s["def"] for s in statuses),
            sum(s["lib_excluded"] for s in statuses),
            ", ".join("%s: %d" % (kind, kinds[kind]) for kind in RESOURCE_KINDS if kinds[kind]),
            largest["items"] if largest else 0, largest["site"] if largest else "-",
        )
    )


def plan_site(row, ctx):
    """One site's dispatch decision (serial: it may generate a catalog replay
    through Godot). Returns a slot: `{"entry": <failed document entry>}` when
    the replay could not be produced, else `{"work": <item>}` with everything
    `run_site` needs (`id`, `evidence_kind`, `cmd_args`, `script`, `doc_path`)."""
    args = ctx["args"]
    v4, v5, v6, v7 = ctx["v4"], ctx["v5"], ctx["v6"], ctx["v7"]
    doc_id = row["id"]
    catalog_event_id = row.get("aliases", {}).get("catalog_event_id")
    # A declared analysis group covers the site with a typed guard, per
    # variant effects, witnesses and the caller's own lines; the catalog
    # path replays the callee's scene alone. Under v4 a row both declare
    # goes through the profile path (2026-09-19) and the catalog path is
    # for a row no profile declares; v3 keeps its frozen dispatch. Under
    # v6, a row whose group names a `kakyu_event_analysis_group/v14` flow
    # route (the three `01m-a-date` sites) always goes through the site
    # path too - `project_event_definition_v6.py`'s own flow dispatch,
    # never `resolve_site_v4`'s site-evidence path, which cannot resolve
    # a flow route at all (EP-12 / WD unit 2).
    if v6 and row_is_flow(row, ctx["flow_gids"]):
        catalog_event_id = None
    elif v4 and catalog_event_id and ped4.resolve_site_v4(row, ctx["profiles_for_dispatch"]):
        catalog_event_id = None
    doc_path = Path(args.out) / ("%s.json" % doc_id)
    script = PROJECT_SCRIPT_V7 if v7 else (
        PROJECT_SCRIPT_V6 if v6 else (PROJECT_SCRIPT_V5 if v5 else (PROJECT_SCRIPT_V4 if v4 else PROJECT_SCRIPT)))
    resolved_args = ctx["resolved_args"]
    shared_lines_path = ctx["shared_lines_path"]

    if catalog_event_id:
        evidence_kind = "catalog_event"
        try:
            replay_path = ensure_catalog_replay(
                catalog_event_id, args.replays_dir if not v4 else os.path.join("analysis", "replays"),
                args.elfimage, args.catalog, ctx["godot_exe"])
        except (RuntimeError, ValueError) as exc:
            return {"entry": {
                "id": doc_id, "kind": None, "evidence_kind": evidence_kind,
                "results": 0, "terminals": 0, "body_messages": 0,
                "ok": False, "reason": "replay_failed", "detail": str(exc),
            }}
        cmd_args = [
            "--catalog", args.catalog, "--event", catalog_event_id,
            "--names", args.names, "--package", args.package,
            "--replay", str(replay_path), "--arc", args.arc, "--out", args.out,
        ] + resolved_args
    else:
        evidence_kind = "analysis_group"
        cmd_args = [
            "--site", doc_id, "--profiles-dir", args.profiles_dir,
            "--replays-dir", args.replays_dir, "--names", args.names,
            "--package", args.package, "--arc", args.arc, "--out", args.out,
        ] + resolved_args
        if v4:
            cmd_args += ["--witnesses-dir", args.witnesses_dir]
            if v6 and args.allow_missing_witnesses:
                cmd_args.append("--allow-missing-witnesses")
            if shared_lines_path is not None:
                cmd_args += ["--shared-lines", str(shared_lines_path)]
    return {"work": {
        "id": doc_id, "evidence_kind": evidence_kind, "cmd_args": cmd_args,
        "script": script, "doc_path": doc_path,
    }}


def run_site(item, ctx):
    """One planned site's projection subprocess, summary and validation.
    Safe to run concurrently: a site's producer writes only `<out>/<id>.json`
    and `<resolved>/<id>.resolved.json`, and everything else it reads
    (shared-line index, witnesses, package, profiles) is complete before the
    first site starts. Returns `{"entry": ..., "witness_status": ...|None,
    "failed": bool}`."""
    args = ctx["args"]
    doc_id, evidence_kind, doc_path = item["id"], item["evidence_kind"], item["doc_path"]
    completed = run_projection(item["cmd_args"], script=item["script"])
    witness_status = parse_witness_status(completed.stdout) if ctx["v6"] else None
    if ctx["v7"]:
        resources_status = parse_resources_status(completed.stdout)
        if resources_status is not None:
            ctx["resource_statuses"].append(resources_status)  # list.append is atomic; the totals do not depend on order
    if completed.returncode != 0 or not doc_path.is_file():
        return {"entry": {
            "id": doc_id, "kind": None, "evidence_kind": evidence_kind,
            "results": 0, "terminals": 0, "body_messages": 0,
            "ok": False, "reason": "projection_failed",
            "detail": (completed.stdout + completed.stderr)[-2000:],
            "exit_code": completed.returncode,
            "stdout_tail": output_tail(completed.stdout), "stderr_tail": output_tail(completed.stderr),
        }, "witness_status": witness_status, "failed": True}

    summary = summarize_document_v4(doc_path) if ctx["v4"] else summarize_document(doc_path)
    entry = {
        "id": doc_id, "kind": summary["kind"], "evidence_kind": evidence_kind,
        "results": summary["results"], "terminals": summary["terminals"],
        "body_messages": summary["body_messages"],
    }
    failed = False
    if ctx["v4"]:
        entry.update({
            "effect_rows_by_type": summary["effect_rows_by_type"],
            "effect_rows_by_basis": summary["effect_rows_by_basis"],
            "effect_rows_declared_false": summary["effect_rows_declared_false"],
            "location_lines": summary["location_lines"],
            "choice_points": summary["choice_points"],
            "scene_ends": summary["scene_ends"],
            "order_hint": summary["order_hint"],
            "order_hint_chain_confirmed": summary["order_hint_chain_confirmed"],
            "done_cell_source": summary["done_cell_source"],
        })
    if args.validate:
        verdict = run_validation(doc_path, args.names, args.package, ctx["contract_fingerprint"])
        entry["ok"] = bool(verdict.get("ok", False))
        if not entry["ok"]:
            entry["reason"] = verdict.get("reason")
            entry["detail"] = verdict.get("detail")
            failed = True
    else:
        entry["ok"] = True
    return {"entry": entry, "witness_status": witness_status, "failed": failed}


def run_sites(items, ctx, jobs):
    """`run_site` for every item, results in item order whatever the
    completion order. `jobs` 1 runs them inline; more uses a thread pool (the
    work is subprocesses, so threads are enough). An exception from a site
    propagates, as in the serial run, after the pool drops the unstarted
    sites."""
    if jobs <= 1 or len(items) <= 1:
        return [run_site(item, ctx) for item in items]
    executor = ThreadPoolExecutor(max_workers=jobs, thread_name_prefix="site")
    try:
        futures = [executor.submit(run_site, item, ctx) for item in items]
        return [future.result() for future in futures]
    finally:
        executor.shutdown(wait=True, cancel_futures=True)


def assemble_documents(slots, results):
    """The serial run's `documents`, `witness_statuses` and failure flag from
    the plan's slots and the work results (both in registry-row order)."""
    documents = []
    witness_statuses = []
    any_failed = False
    results_iter = iter(results)
    for slot in slots:
        if "entry" in slot:
            documents.append(slot["entry"])
            any_failed = True
            continue
        result = next(results_iter)
        if result["witness_status"] is not None:
            witness_statuses.append(result["witness_status"])
        documents.append(result["entry"])
        if result["failed"]:
            any_failed = True
    return documents, witness_statuses, any_failed


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--names", required=True)
    parser.add_argument("--catalog", required=True)
    parser.add_argument("--profiles-dir", required=True)
    parser.add_argument("--replays-dir", required=True)
    parser.add_argument("--package", required=True)
    parser.add_argument("--arc", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--resolved-out", default=None,
                        help="directory for the local .resolved.json documents (dialogue text); defaults to --out")
    parser.add_argument("--elfimage", default=None, help="ELFIMAGE directory, for catalog replays")
    parser.add_argument("--godot", default=None, help="Godot 4.7 console executable (auto-discovered otherwise)")
    parser.add_argument("--only", action="append", default=[], metavar="ID", help="project only this id; repeatable")
    parser.add_argument("--validate", dest="validate", action="store_true", default=True)
    parser.add_argument("--no-validate", dest="validate", action="store_false")
    parser.add_argument("--contract", choices=["v3", "v4", "v5", "v6", "v7"], default="v3",
                        help="kakyu_event_definition schema version to project (default v3, unchanged behaviour)")
    parser.add_argument("--witnesses-dir", default=os.path.join("analysis", "witnesses"),
                         help="v4/v5/v6/v7 only: kakyu_event_effect_witness/v1 results directory")
    parser.add_argument("--shared-lines-out", default=os.path.join("analysis", "shared_lines_v4.json"),
                         help="v4/v5/v6/v7 only: where the computed shared-line index is written")
    parser.add_argument("--allow-missing-witnesses", action="store_true", default=False,
                         help="v6 only: project without the witness corpus (a loud per-site warning and a summary "
                              "count instead of a refusal, TD-37); stale witness results are still refused")
    parser.add_argument("--jobs", type=positive_int, default=1, metavar="N",
                        help="project and validate up to N sites at once (default 1, serial). Everything shared "
                             "is prepared before the first site starts and the index and summary are assembled in "
                             "registry order, so the output is byte-identical to --jobs 1 (TD-41)")
    args = parser.parse_args(argv)

    # WD-23: v5 is v4 plus `visits`, projected by `project_event_definition_v5.py`
    # (which calls straight into project_event_definition_v4's own pipeline
    # for the v4 body). EP-12 / WD unit 2: v6 is v5 plus `flow` for the three
    # `01m-a-date` sites, projected by `project_event_definition_v6.py` (which
    # wraps v5's own pipeline the same way v5 wraps v4's). Every v4-shared
    # branch below (`resolve_site_v4` dispatch, the shared-line index, the
    # witnesses dir, the v2 index schema and its per-document v4 summary
    # fields) reuses the same `v4` flag for v5/v6 too; only the producer
    # script and the contract-fingerprint directory are each version's own.
    # WD-21 U2 C4: v7 is v6 plus `presentation.resources`, projected by
    # `project_event_definition_v7.py` (which wraps v6's pipeline); every v6
    # branch (flow dispatch, witnesses, index schema, summaries) applies to it
    # unchanged, and it reads the v3 replays (`--replays-dir analysis/replays_v3`).
    v7 = args.contract == "v7"
    v6 = args.contract in ("v6", "v7")
    v5 = args.contract == "v5"
    v4 = args.contract in ("v4", "v5", "v6", "v7")
    if v7:
        contract_fingerprint = ped.resolve_contract_fingerprint(
            os.path.join("config", "contracts", "event_definition_v7", "contract_fingerprint"))
    elif v6:
        contract_fingerprint = ped.resolve_contract_fingerprint(
            os.path.join("config", "contracts", "event_definition_v6", "contract_fingerprint"))
    elif v5:
        contract_fingerprint = ped.resolve_contract_fingerprint(
            os.path.join("config", "contracts", "event_definition_v5", "contract_fingerprint"))
    elif v4:
        contract_fingerprint = ped.resolve_contract_fingerprint(
            os.path.join("config", "contracts", "event_definition_v4", "contract_fingerprint"))
    else:
        contract_fingerprint = ped.resolve_contract_fingerprint(ped.DEFAULT_CONTRACT_FINGERPRINT_PATH)
    if v6 and not args.allow_missing_witnesses:
        refusal = witness_preflight(args.witnesses_dir)
        if refusal is not None:
            print("REFUSED: %s" % refusal)
            return 1
    names_fingerprint_path = Path(args.names) / "names_fingerprint"
    names_fingerprint = (
        names_fingerprint_path.read_text(encoding="utf-8").strip() if names_fingerprint_path.is_file() else "unrecorded"
    )
    manifest = load_json(Path(args.package) / "manifest.json")
    package_sha256 = manifest["package_sha256"]

    rows = registry_rows(args.names)
    if args.only:
        wanted = set(args.only)
        rows = [row for row in rows if row["id"] in wanted]
        unknown = sorted(wanted - {row["id"] for row in rows})
        if unknown:
            print("REFUSED: --only names no registry row: %s" % ", ".join(unknown))
            return 1

    header = {
        "schema": "kakyu_event_definition_index/v2" if v4 else "kakyu_event_definition_index/v1",
        "contract_fingerprint": contract_fingerprint,
        "names_fingerprint": names_fingerprint,
        "package_sha256": package_sha256,
    }
    if v4:
        cells_fingerprint_path = ROOT / "config" / "contracts" / "state_cells_v1" / "cells_fingerprint"
        header["cells_fingerprint"] = (
            cells_fingerprint_path.read_text(encoding="utf-8").strip() if cells_fingerprint_path.is_file() else "unrecorded"
        )
    index_path = Path(args.out) / "index.json"
    existing_index = None
    if args.only and index_path.is_file():
        # Fail closed before anything is projected: a merge into an index bound to something else would
        # leave rows that do not describe the documents beside them.
        existing_index = load_json(index_path)
        refusal = index_merge_refusal(existing_index, header)
        if refusal is not None:
            print("REFUSED: %s" % refusal)
            return 1

    try:
        godot_exe = find_godot(args.godot)
    except ValueError as exc:
        print("WARNING: %s" % exc)
        godot_exe = None

    os.makedirs(args.out, exist_ok=True)
    resolved_args = ["--resolved-out", args.resolved_out] if args.resolved_out else []

    shared_lines_path = None
    if v4:
        shared_lines = compute_shared_lines(rows, args.names, args.profiles_dir, args.replays_dir)
        shared_lines_path = Path(args.shared_lines_out)
        shared_lines_path.parent.mkdir(parents=True, exist_ok=True)
        with open(shared_lines_path, "w", encoding="utf-8", newline="\n") as fh:
            json.dump(shared_lines, fh, indent=2, ensure_ascii=False, sort_keys=True)
            fh.write("\n")
        print("WROTE %s (%d callers)" % (shared_lines_path, len(shared_lines)))

    profiles_for_dispatch = ped.load_profiles(args.profiles_dir)
    ctx = {
        "args": args, "v4": v4, "v5": v5, "v6": v6, "v7": v7, "godot_exe": godot_exe,
        "resource_statuses": [],
        "resolved_args": resolved_args, "shared_lines_path": shared_lines_path,
        "profiles_for_dispatch": profiles_for_dispatch,
        "flow_gids": flow_group_ids(profiles_for_dispatch) if v6 else set(),
        "contract_fingerprint": contract_fingerprint,
    }
    # Plan serially (dispatch decisions and any Godot catalog replay), run the
    # sites on the pool, then assemble in registry-row order.
    slots = [plan_site(row, ctx) for row in rows]
    results = run_sites([slot["work"] for slot in slots if "work" in slot], ctx, args.jobs)
    documents, witness_statuses, any_failed = assemble_documents(slots, results)

    projected = sum(1 for d in documents if d.get("kind") is not None)
    valid = sum(1 for d in documents if d.get("ok"))
    invalid = len(documents) - valid

    index = {
        "schema": header["schema"],
        "contract_fingerprint": contract_fingerprint,
        "names_fingerprint": names_fingerprint,
        "package_sha256": package_sha256,
        "documents": documents,
        "summary": {"projected": projected, "valid": valid, "invalid": invalid},
    }
    if v4:
        index["cells_fingerprint"] = header["cells_fingerprint"]
    if existing_index is not None:
        # `--only`: the run's rows replace their ids in the index already there; the header is the existing
        # one (checked equal above), the summary is recomputed over the merged rows.
        merged = merge_index_documents(existing_index["documents"], documents)
        index = dict(existing_index, documents=merged, summary=index_summary(merged))
    with open(index_path, "w", encoding="utf-8", newline="\n") as fh:
        json.dump(index, fh, indent=2, ensure_ascii=False, sort_keys=False)
        fh.write("\n")

    print("%-34s %-13s %-15s %8s  %s" % ("id", "kind", "evidence", "results", "ok/reason"))
    for entry in documents:
        status = "ok" if entry.get("ok") else ("FAIL:%s" % entry.get("reason"))
        print("%-34s %-13s %-15s %8s  %s" % (
            entry["id"], entry.get("kind") or "-", entry["evidence_kind"], entry["results"], status,
        ))
        if entry.get("reason") == "projection_failed":
            # Never silent: the exit code and the producers' last lines (they print refusals on stdout).
            print("    exit=%s" % entry.get("exit_code"))
            for stream in ("stderr_tail", "stdout_tail"):
                for line in entry.get(stream) or []:
                    print("    %s| %s" % (stream.split("_")[0], line))
    print("projected=%d valid=%d invalid=%d" % (projected, valid, invalid))
    if existing_index is not None:
        print("merged into the existing index: documents=%d projected=%d valid=%d invalid=%d" % (
            len(index["documents"]), index["summary"]["projected"], index["summary"]["valid"],
            index["summary"]["invalid"]))
    if v7:
        print(resources_summary_line(ctx["resource_statuses"], projected))
    if v6:
        print(witness_summary_line(witness_statuses, documents))
        without = sum(1 for s in witness_statuses if s["missing"] > 0)
        if without:
            print("WARNING: %d site(s) projected WITHOUT their witness evidence (--allow-missing-witnesses); "
                  "this set carries fewer witness-derived rows than a full corpus run" % without)
    print("WROTE %s" % index_path)

    return 1 if any_failed else 0


if __name__ == "__main__":
    sys.exit(main())
