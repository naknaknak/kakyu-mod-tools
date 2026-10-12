"""Classify caller-derived route candidates without inventing unresolved semantics."""
from __future__ import annotations

import argparse
from collections import Counter, defaultdict
import hashlib
import json
from pathlib import Path

from extract_kakyu_arc import read_entries
from mes_archive_ir import parse_mes_container
from mes_instruction_ir import decode_instruction_ir, INSTRUCTION_SCHEMA

SCHEMA = "kakyu_event_route_classification/v1"
ARCHIVE_SHA = "31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6"
NAMING_SCHEMA = "kakyu_mes_dispatch_naming_audit/v1"
DEFAULT_NAMING = Path("config/event_catalog/dispatch_naming_v1.json")
TAIL_ENVELOPE_COUNT = 0
INLINE_SITE_COUNT = 2
DEFAULT_GROUPS = Path("config/event_catalog/analysis_groups")
UNREFERENCED_SCHEMA = "kakyu_unreferenced_entries_audit/v2"
DEFAULT_UNREFERENCED = Path("config/event_catalog/unreferenced_entries_v1.json")
# Measured over the archive, not chosen: no EVENT-named target is dispatched
# from more than this many distinct callers. It is the threshold above which
# "shared" is a property no event in this archive has.
MAX_EVENT_CALLERS = 2


def canonical(value):
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"), allow_nan=False).encode("utf-8")


def analysis_group_roles(groups_dir: Path, entries: dict) -> tuple:
    """Per-entry roles the committed analysis-group profiles already bind,
    and (EP-11 part 1b) the visit-dispatch index: entry -> the v13
    `(group_id, route_id, visit_id)` triples whose visit dispatches it. A
    visit's dispatch target gets the same `measured_callee` role a route's
    own callee gets, for the confidence rule; the visit-dispatch index is
    kept separately because it also names which row's visit reaches the
    entry, not just that one does."""
    bound = defaultdict(dict)
    visits = defaultdict(list)
    for path in sorted(groups_dir.glob("*.json")):
        profile = json.loads(path.read_text(encoding="utf-8"))
        if not str(profile.get("schema", "")).startswith("kakyu_event_analysis_group/"):
            raise ValueError(f"{path.name} is not an analysis group profile")
        if profile.get("archive_sha256") != ARCHIVE_SHA:
            raise ValueError(f"{path.name} binds a different archive")
        group = {"group_id": profile["group_id"], "schema": profile["schema"],
                 "payload_sha256": profile["payload_sha256"]}
        for member in profile.get("source_members", []):
            if member["entry"] not in entries:
                raise ValueError(f"{path.name} names a missing entry")
            if hashlib.sha256(entries[member["entry"]]).hexdigest() != member["entry_sha256"]:
                raise ValueError(f"{path.name} no longer matches the original {member['entry']}")
            bound[member["entry"]].setdefault(profile["group_id"], {**group, "roles": set()})
            bound[member["entry"]][profile["group_id"]]["roles"].add("source_member")
        for route in profile.get("routes", []):
            for key, role in (("caller", "measured_caller"), ("callee", "measured_callee")):
                name = route.get(key, {}).get("entry", "")
                if name:
                    bound[name].setdefault(profile["group_id"], {**group, "roles": set()})
                    bound[name][profile["group_id"]]["roles"].add(role)
            target = route.get("outcome", {}).get("target", "")
            if target:
                bound[target].setdefault(profile["group_id"], {**group, "roles": set()})
                bound[target][profile["group_id"]]["roles"].add("measured_terminal")
            for visit in route.get("visits", []):
                for dispatch in visit.get("dispatches", []):
                    dispatch_entry = dispatch.get("entry", "")
                    if not dispatch_entry:
                        continue
                    bound[dispatch_entry].setdefault(profile["group_id"], {**group, "roles": set()})
                    bound[dispatch_entry][profile["group_id"]]["roles"].add("measured_callee")
                    visits[dispatch_entry].append({
                        "group_id": profile["group_id"], "route_id": route.get("route_id", ""),
                        "visit_id": visit.get("visit_id", ""),
                    })
    roles = {entry: [{**g, "roles": sorted(g["roles"])} for _, g in sorted(by_group.items())]
             for entry, by_group in bound.items()}
    return roles, dict(visits)


def classify(arc: Path, inventory: dict, catalog: dict, naming: dict, groups_dir: Path,
             unreferenced: dict) -> dict:
    archive = arc.read_bytes()
    if hashlib.sha256(archive).hexdigest() != ARCHIVE_SHA or inventory.get("archive_sha256") != ARCHIVE_SHA:
        raise ValueError("The authoritative archive identity differs")
    if inventory.get("schema") != "kakyu_mes_event_corpus_inventory/v1":
        raise ValueError("Unsupported caller inventory schema")
    if naming.get("schema") != NAMING_SCHEMA or naming.get("archive_sha256") != ARCHIVE_SHA:
        raise ValueError("Unsupported or foreign dispatch naming audit")
    if naming.get("strict_dispatch_count") != len(inventory.get("dispatches", [])):
        raise ValueError("The naming audit and the caller inventory disagree on the strict row count")
    if (unreferenced.get("schema") != UNREFERENCED_SCHEMA
            or unreferenced.get("archive_sha256") != ARCHIVE_SHA
            or unreferenced.get("unreferenced_entries") != naming.get("unnamed_after_archive_forms")):
        raise ValueError("Unsupported unreferenced-entry audit, or it disagrees with the naming audit")
    named_nowhere = set(unreferenced.get("named_nowhere", []))
    twins = {row["entry"]: row for row in unreferenced.get("duplicates", [])
             if row.get("message_digest_equal") and row.get("message_count_equal")}
    entries = {name: archive[offset:offset + size] for name, offset, size in read_entries(arc)}
    codes = {}
    incoming = defaultdict(list)
    outgoing = defaultdict(list)
    seen = set()
    dispatches = inventory.get("dispatches", [])
    if len(entries) != 1016 or len(dispatches) != 11124:
        raise ValueError("Complete caller inventory counts changed")
    for row in dispatches:
        caller, target, start = row["caller_entry"], row["target_entry"], row["source_offset"]
        if caller not in entries or target not in entries or (caller, start) in seen:
            raise ValueError("Missing/duplicate caller evidence")
        seen.add((caller, start))
        if caller not in codes:
            source = entries[caller]
            parsed = parse_mes_container(source)
            codes[caller] = source[parsed["header"]["codeOffset"]:]
        instruction = decode_instruction_ir(codes[caller], start)
        if (not instruction.get("ok") or instruction.get("schema") != INSTRUCTION_SCHEMA
                or instruction.get("command_id") != row["command_id"]
                or instruction.get("end_offset") != row["end_offset"]
                or instruction.get("op") != row["op"]
                or instruction.get("script_target", "").upper() != target):
            raise ValueError(f"Python source audit rejected {caller} at {start:#x}")
        evidence = {"caller_entry": caller, "caller_entry_sha256": hashlib.sha256(entries[caller]).hexdigest(),
                    "source_offset": start, "end_offset": row["end_offset"], "command_id": row["command_id"]}
        incoming[target].append(evidence)
        outgoing[caller].append(target)
    if len(incoming) != 1005 or len(outgoing) != 360:
        raise ValueError("Caller/target partition changed")
    event_targets = {name for name in incoming if name.startswith("EVENT")}
    if len(event_targets) != 130:
        raise ValueError("Reachable EVENT target coverage changed")
    tail_incoming = defaultdict(list)
    tail_outgoing = defaultdict(set)
    tail_rows = naming.get("opaque_tail_envelopes", [])
    if len(tail_rows) != TAIL_ENVELOPE_COUNT:
        raise ValueError("Opaque-tail envelope count changed")
    for row in tail_rows:
        caller, target, start = row["caller"], row["target"], row["offset"]
        if caller not in entries or target not in entries or (caller, start) in seen:
            raise ValueError("Missing/duplicate opaque-tail evidence")
        seen.add((caller, start))
        if caller not in codes:
            source = entries[caller]
            codes[caller] = source[parse_mes_container(source)["header"]["codeOffset"]:]
        # Held to the same standard as the strictly decoded rows: the record is
        # re-decoded from the original bytes rather than taken from the audit.
        instruction = decode_instruction_ir(codes[caller], start)
        if (not instruction.get("ok") or instruction.get("schema") != INSTRUCTION_SCHEMA
                or instruction.get("command_id") != row["command"]
                or instruction.get("end_offset") != row["end_offset"]
                or instruction.get("script_target", "").upper() != target):
            raise ValueError(f"Python source audit rejected opaque-tail {caller} at {start:#x}")
        tail_incoming[target].append({
            "caller_entry": caller, "caller_entry_sha256": hashlib.sha256(entries[caller]).hexdigest(),
            "source_offset": start, "end_offset": row["end_offset"], "command_id": row["command"],
            "decode_scope": "opaque_tail"})
        tail_outgoing[caller].add(target)
    tail_event_targets = {name for name in tail_incoming if name.startswith("EVENT")} - event_targets
    inline_incoming = defaultdict(list)
    inline_rows = naming.get("inline_script_execution", [])
    if len(inline_rows) != INLINE_SITE_COUNT:
        raise ValueError("Inline script execution site count changed")
    for row in inline_rows:
        caller, target, start = row["caller"], row["target"], row["offset"]
        if caller not in entries or target not in entries:
            raise ValueError("Missing inline script execution evidence")
        if caller not in codes:
            source = entries[caller]
            codes[caller] = source[parse_mes_container(source)["header"]["codeOffset"]:]
        instruction = decode_instruction_ir(codes[caller], start)
        operand = (instruction.get("operands") or [{}])[0]
        if (not instruction.get("ok") or instruction.get("schema") != INSTRUCTION_SCHEMA
                or instruction.get("op") != "inline_script_execution"
                or str(operand.get("name", "")).upper() != target
                or operand.get("execution_selector") != row["selector"]
                or operand.get("execution_role") != row["role"]):
            raise ValueError(f"Python source audit rejected inline execution {caller} at {start:#x}")
        inline_incoming[target].append({
            "caller_entry": caller, "caller_entry_sha256": hashlib.sha256(entries[caller]).hexdigest(),
            "source_offset": start, "end_offset": instruction["end_offset"],
            "command_id": instruction["command_id"], "execution_selector": row["selector"],
            "execution_role": row["role"], "decode_scope": "inline_script_execution"})
    catalog_events = defaultdict(list)
    minimal_playback_events_by_group = defaultdict(list)
    for event in catalog["events"]:
        callee = event["source"]["callee"]
        if hashlib.sha256(entries[callee["entry"]]).hexdigest() != callee["entry_sha256"]:
            raise ValueError("Catalog callee no longer matches the original")
        catalog_events[callee["entry"]].append(event)
        # Since EP-10 unit 5 (2026-09-21) every row is generated with an
        # `analysis_group` block; a generated row's `required_entries` are
        # its package members under the one role `analysis_group_member`,
        # which the profiles already give the classifier with their measured
        # roles (analysis_group_roles below). Catalog-declared dependency
        # roles no longer feed this index at all: LIBLARY.LIB and
        # DEF_MAIN.MES, which only the retired hand-authored rows declared
        # by role, left the index on 2026-09-21 for that reason.
        if event.get("playback_status") == "minimal_playback":
            for group_ref in event.get("analysis_group", {}).get("groups", []):
                minimal_playback_events_by_group[group_ref["group_id"]].append(event["event_id"])
    undispatched_events = {
        name for name in entries
        if name.startswith("EVENT") and name not in incoming and name not in tail_incoming
    }
    named_events = event_targets | tail_event_targets
    non_event = {
        target for name in named_events
        for target in set(outgoing.get(name, ())) | tail_outgoing.get(name, set())
        if not target.startswith("EVENT")
    }
    groups, visit_dispatches = analysis_group_roles(groups_dir, entries)
    caller_sets = defaultdict(set)
    forms = defaultdict(set)
    for target, evidence in list(incoming.items()) + list(tail_incoming.items()):
        for row in evidence:
            caller_sets[target].add(row["caller_entry"])
            forms[target].add(row["command_id"])
    measured_max = max((len(caller_sets[name]) for name in named_events), default=0)
    if measured_max != MAX_EVENT_CALLERS:
        raise ValueError("The maximum distinct-caller count for an EVENT-named target changed")
    rows = []
    for entry in sorted(named_events | undispatched_events | non_event):
        events = catalog_events.get(entry, [])
        playable = [event for event in events if event["playback_status"] == "minimal_playback"]
        group_evidence = groups.get(entry, [])
        group_roles = {role for g in group_evidence for role in g["roles"]}
        hosted_groups = [g["group_id"] for g in group_evidence if "measured_caller" in g["roles"]]
        classification = "unresolved_route"
        reason = "Caller boundary confirmed; preset, full route meaning and terminal qualification remain open."
        if playable:
            classification = "playable_event"
            reason = "A catalog row plays this entry to its ending through the shared call frame (minimal playback)."
        elif entry not in named_events and len(caller_sets[entry]) > measured_max:
            # Shared by measurement rather than by filename: dispatched from more
            # distinct callers than any EVENT-named target in the archive reaches.
            classification = "system_script"
            resumes = forms[entry] == {0x0F}
            reason = (
                f"Dispatched from {len(caller_sets[entry])} distinct callers, more than the "
                f"{measured_max} that is the maximum for any EVENT-named target in this archive, "
                + ("only through command-0x0F nested calls that resume the caller, so it is a shared "
                   "presentation or conversation callee rather than an event."
                   if resumes else
                   "only through command-0x0E root handoffs that replace the root, so it is a shared "
                   "destination or map script rather than an event."
                   if forms[entry] == {0x0E} else
                   "through both dispatch forms.")
            )
        elif entry not in named_events and entry not in undispatched_events and hosted_groups:
            # Owner ruling of 2026-09-23 (tool decision): a non-EVENT script
            # that is the measured caller of a committed analysis group hosts
            # an EVENT intro - it is a place script, not an event, even when
            # no more distinct callers reach it than reach an EVENT target
            # (05C.MES: two callers, the EVENT maximum).
            classification = "system_script"
            reason = (
                "Hosts the measured intro of an EVENT route as the caller of a committed analysis group"
                f" ({', '.join(hosted_groups)}), so it is a place script rather than an event; reached from"
                f" {len(caller_sets[entry])} distinct callers, which the caller-count rule alone does not"
                " separate from an event."
            )
        elif entry in visit_dispatches and any(
                v["group_id"] in minimal_playback_events_by_group for v in visit_dispatches[entry]):
            # EP-11 part 1b (owner-approved direction, tool decision): a
            # minimal_playback row's visit dispatches this entry directly
            # (a declared `dispatches` entry of a v13 visit), so it plays
            # through that row's visit preset even though it is not the
            # row's own callee.
            classification = "playable_event"
            named = "; ".join(
                f"{event_id}'s visit {v['visit_id']} of route {v['route_id']} (group {v['group_id']})"
                for v in visit_dispatches[entry]
                for event_id in minimal_playback_events_by_group.get(v["group_id"], [])
            )
            reason = (
                "A minimal_playback row's visit dispatches this entry to its own exact return, so it"
                f" plays through that row's visit preset: {named}."
            )
        elif entry in undispatched_events and entry in named_nowhere:
            classification = "unreachable_stored_route"
            twin = twins.get(entry)
            scanned = len(unreferenced.get("scanned_files", []))
            reason = (
                f"The name does not occur once in any of the {scanned} shipped files scanned -"
                " every archive, the configuration and the executable - so nothing names it by a"
                " dispatch record, an inline script execution or a host reference."
            )
            if twin:
                reason += (
                    f" Its {twin['entry_profile']['message_records']} message records are"
                    f" byte-identical to {twin['twin']}, which is dispatched, so this is a stored"
                    " earlier build of that scene rather than an orphan: the twin carries"
                    f" {twin['twin_profile']['op_counts'].get('voice_marker', 0)} voice markers"
                    f" where this entry carries {twin['entry_profile']['op_counts'].get('voice_marker', 0)}."
                )
            reason += (" This bounds naming, not the native host's ability to construct a name at"
                       " runtime.")
        elif entry in undispatched_events:
            reason = "No dispatch record names it anywhere in the archive, and neither inline script execution nor the native host names it; semantic reachability remains open."
        elif entry in tail_event_targets:
            reason = "Named only inside a preserved opaque tail. The record is byte-exact and independently decoded, but the strict decoder does not read it, so the dispatch is not shown to execute."
        elif events:
            reason = "Existing catalog retains analysis-only status; no playable route is qualified."
        strict_intro = incoming.get(entry, [])
        tail_intro = tail_incoming.get(entry, [])
        inline_intro = inline_incoming.get(entry, [])
        present = [label for label, rows_ in (
            ("strict_decode", strict_intro),
            ("opaque_tail", tail_intro),
            ("inline_script_execution", inline_intro),
        ) if rows_]
        intro_scope = "_and_".join(present) if present else "none"
        if entry in event_targets:
            scope = "event_named_target"
        elif entry in tail_event_targets:
            scope = "event_named_tail_target"
        elif entry in undispatched_events:
            scope = "event_named_undispatched"
        else:
            scope = "non_event_dependency"
        seen_forms = forms.get(entry, set())
        dispatch_form = ("nested_call_only" if seen_forms == {0x0F}
                         else "root_handoff_only" if seen_forms == {0x0E}
                         else "both_forms" if seen_forms else "not_dispatched")
        # The confidence says what the committed evidence establishes for the
        # row, by the role the profiles give the entry (owner ruling (b),
        # 2026-09-14): a declared route of its own, a measured part in another
        # entry's route, or membership only. None of them promotes playback.
        if classification != "unresolved_route":
            confidence = "qualified_catalog_scope"
        elif "measured_callee" in group_roles:
            confidence = "analysis_group_qualified_route"
        elif group_roles & {"measured_caller", "measured_terminal"}:
            confidence = "analysis_group_measured_participant"
        elif group_evidence:
            confidence = "analysis_group_member_unmeasured"
        else:
            confidence = "structural_confirmed_semantics_unresolved"
        if group_evidence and classification == "unresolved_route":
            named = ", ".join(f"{g['group_id']} ({'/'.join(g['roles'])})" for g in group_evidence)
            if confidence == "analysis_group_qualified_route":
                reason = (
                    "Qualified by a committed analysis group: its intro guard, branch and choice"
                    " states, state effects and terminal are declared and re-verified against the"
                    f" original by the audit and the validator ({named}). Catalog playback is not"
                    " promoted, and how the host reaches the origin is measured only where the"
                    " group declares it."
                )
                if events:
                    reason += " The existing catalog entry retains its analysis-only status."
            elif confidence == "analysis_group_measured_participant":
                reason = (
                    "Measured as the caller or the terminal of a committed analysis group's route,"
                    f" with no route of its own declared ({named}). Catalog playback is not promoted."
                )
            else:
                reason = (
                    "Bound as a source member of a committed analysis group only; no measured path"
                    f" reaches it ({named}). Catalog playback is not promoted."
                )
        rows.append({"entry": entry, "entry_sha256": hashlib.sha256(entries[entry]).hexdigest(),
                     "class": classification, "reason": reason,
                     "scope": scope,
                     "intro_evidence": strict_intro,
                     "opaque_tail_intro_evidence": tail_intro,
                     "inline_intro_evidence": inline_intro,
                     "intro_scope": intro_scope,
                     "literal_targets": sorted(set(outgoing.get(entry, []))),
                     "opaque_tail_targets": sorted(tail_outgoing.get(entry, set())),
                     "multiple_intro_candidate": len(strict_intro) + len(tail_intro) > 1,
                     "catalog_routes": [{"event_id": e["event_id"], "playback_status": e["playback_status"]} for e in events],
                     "catalog_dependency_roles": [],
                     "distinct_caller_count": len(caller_sets[entry]),
                     "dispatch_form": dispatch_form,
                     "analysis_group_evidence": group_evidence,
                     "evidence_type": "original_archive_python_instruction_v45_and_source_bound_catalog",
                     "confidence": confidence})
    report = {"schema": SCHEMA, "archive_sha256": ARCHIVE_SHA,
              "inventory_structure_sha256": hashlib.sha256(canonical({k: v for k, v in inventory.items() if k not in {"content_core_version", "report_sha256"}})).hexdigest(),
              "naming_structure_sha256": hashlib.sha256(canonical({k: v for k, v in naming.items() if k not in {"content_core_version", "report_sha256"}})).hexdigest(),
              "catalog_sha256": hashlib.sha256(canonical(catalog)).hexdigest(), "audited_dispatches": len(seen),
              "event_target_count": len(event_targets),
              "event_named_tail_target_count": len(tail_event_targets),
              "opaque_tail_dispatches": len(tail_rows), "inline_script_executions": len(inline_rows),
              "unreferenced_structure_sha256": hashlib.sha256(canonical(
                  {k: v for k, v in unreferenced.items() if k != "payload_sha256"})).hexdigest(),
              "max_event_named_distinct_callers": measured_max,
              "analysis_group_bound_entries": sum(1 for r in rows if r["analysis_group_evidence"]),
              "unreachable_claims": sum(1 for r in rows if r["class"] == "unreachable_stored_route"),
              "duplicate_route_claims": 0, "class_counts": dict(sorted(Counter(r["class"] for r in rows).items())),
              "rows": rows}
    report["payload_sha256"] = hashlib.sha256(canonical(report)).hexdigest()
    if hashlib.sha256(arc.read_bytes()).hexdigest() != ARCHIVE_SHA:
        raise ValueError("Original archive changed during classification")
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("arc", type=Path)
    parser.add_argument("inventory", type=Path)
    parser.add_argument("--catalog", type=Path, default=Path("config/event_catalog/original_events_v1.json"))
    parser.add_argument("--naming", type=Path, default=DEFAULT_NAMING,
                        help="Dispatch naming audit report supplying opaque-tail intro evidence")
    parser.add_argument("--groups", type=Path, default=DEFAULT_GROUPS,
                        help="Directory of committed analysis-group profiles")
    parser.add_argument("--unreferenced", type=Path, default=DEFAULT_UNREFERENCED,
                        help="Audit of entries no shipped file names")
    parser.add_argument("--output", type=Path)
    parser.add_argument("--check", type=Path, help="Reproduce an existing classification exactly")
    args = parser.parse_args()
    report = classify(args.arc, json.loads(args.inventory.read_text(encoding="utf-8")),
                      json.loads(args.catalog.read_text(encoding="utf-8")),
                      json.loads(args.naming.read_text(encoding="utf-8")), args.groups,
                      json.loads(args.unreferenced.read_text(encoding="utf-8")))
    if args.check and json.loads(args.check.read_text(encoding="utf-8")) != report:
        raise ValueError("Tracked route classification does not reproduce from original evidence")
    if args.output:
        if args.output.resolve().is_relative_to(args.arc.resolve().parent):
            raise ValueError("Classification output must be outside the originals")
        with args.output.open("x", encoding="utf-8") as stream:
            stream.write(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps({key: value for key, value in report.items() if key != "rows"}, indent=2))


if __name__ == "__main__":
    main()
