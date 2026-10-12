"""Projects one event site into a `kakyu_event_definition/v6` document
(EP-12 / WD unit 2, 2026-09-25). Shares `project_event_definition_v5.py`'s
whole pipeline for the v5 body exactly as v5 shares v4's (schema and
`contract_fingerprint` only; `visits` still injected for the two WD-23
sites) - this module has no copy of the v3/v4/v5 candidate/effect/dialogue
machinery. The only new code here is `flow`, built for the three sites whose
registry row names the `01m-a-date` group (`config/event_catalog/
analysis_groups/01m_a_date_v14.json`, the promise-date group
`docs/spec/mes/a_date_flow.md` measured and declared):
`miko.town.station.date-town.1`, `miko.town.station.date-date5.1`,
`miko.town.station.date-hotel.1`. Every other site's v6 document is v5's own
plus the v6 schema fields only.

    py tools/project_event_definition_v6.py --site <id> --names <dir> \
        --profiles-dir <dir> --replays-dir analysis/replays_v2 \
        --witnesses-dir analysis/witnesses --package <dir> --arc <mes.arc> \
        --out <dir> [--shared-lines <json>] [--resolved-out <dir>] \
        [--allow-missing-witnesses]

Same command line as `project_event_definition_v5.py` plus
`--allow-missing-witnesses`; `--contract-fingerprint` defaults to
`config/contracts/event_definition_v6/contract_fingerprint`.

TD-37: unlike v4/v5 (frozen, silent when the witness corpus is absent), a v6
site whose profile's `<witnesses-dir>/../witness_requests/<stem>.json` or
`<witnesses-dir>/<stem>.json` is absent, or carries a `payload_sha256` that
is not the profile's, is refused (exit 1); `--allow-missing-witnesses`
projects absent evidence without it and prints a `WARNING` per site. Stale
evidence is refused either way. Every projected site prints one
`WITNESS_STATUS` line (profiles, requests, results used).
"""
from __future__ import annotations

import argparse
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import project_event_definition as ped  # noqa: E402
import project_event_definition_v4 as pv4  # noqa: E402
import project_event_definition_v5 as pv5  # noqa: E402
import state_cells  # noqa: E402
from mes_route_decode import Archive, facts  # noqa: E402
from payload_values import is_gallery_registry_row, is_talk_registry_row  # noqa: E402

SCHEMA_VERSION = "kakyu_event_definition/v6"
DEFAULT_CONTRACT_FINGERPRINT_PATH = os.path.join(
    "config", "contracts", "event_definition_v6", "contract_fingerprint")

# ---------------------------------------------------------------------------
# EP-12 / WD unit 2's flow sites (heroine A, 2026-09-24), widened by the B
# date template unit (2026-09-25) and the C..L batch unit (2026-09-25).
# Evidence: `config/event_catalog/analysis_groups/01m_<letter>_date_v14.json`
# (each heroine's own promise-date group, `schema
# kakyu_event_analysis_group/v14`) and its v2 flow replay
# (`validate_event_analysis_group.gd --replay`, written under
# `<replays_dir>/01m_<letter>_date_v14.json` the same way a catalog replay
# is), and the registry rows themselves
# (`config/contracts/event_names_v1/event_names.json`), each naming its own
# group (e.g. `01m-<letter>-date`) with exactly one `route_ids` entry.
#
# `_flow_meta` derives a site's own `{route_id, profile_stem, group_id}` from
# its registry row plus the declared profiles themselves - the same
# `schema == FLOW_PROFILE_SCHEMA` test `tools/project_event_definitions_batch.py`'s
# own `flow_group_ids`/`row_is_flow` already use to route a row to the flow
# path, not a second, hand-kept table naming the same fact (C..L batch unit,
# 2026-09-25) - so a new heroine's flow group needs no code change here,
# only its own declared profile and registry row. Proven byte-for-byte
# identical to the previous hand table's own A/B documents before this
# batch's own new documents were projected (see
# docs/spec/tech/content_tools.md).
# ---------------------------------------------------------------------------

FLOW_PROFILE_SCHEMA = "kakyu_event_analysis_group/v14"


def _flow_meta(row, profiles):
    """None for a non-flow row; otherwise `{route_id, profile_stem,
    group_id}` for the one flow group its own registry row aliases (a flow
    site's row names exactly one group with exactly one `route_ids` entry,
    per this table's own evidence note above)."""
    group_id_to_stem = {doc.get("group_id"): stem for stem, doc in profiles.items()
                         if doc.get("schema") == FLOW_PROFILE_SCHEMA}
    for group in row.get("aliases", {}).get("groups", []) or []:
        group_id = group.get("group_id")
        if group_id in group_id_to_stem:
            route_ids = group.get("route_ids") or []
            if len(route_ids) != 1:
                raise ValueError("flow group %s on row %s must name exactly one route_id, found %r"
                                  % (group_id, row.get("id"), route_ids))
            return {"route_id": route_ids[0], "profile_stem": group_id_to_stem[group_id], "group_id": group_id}
    return None


def _gate_basis(basis):
    """The v14 profile's own gate `basis` string (`"tool_seeded"` or
    `"written_by:<hop_id>"`) into the v6 document's own vocabulary
    (`"tool_seeded"` or `{"written_by": <hop_id>}`)."""
    if basis == "tool_seeded":
        return "tool_seeded"
    if isinstance(basis, str) and basis.startswith("written_by:"):
        return {"written_by": basis.split(":", 1)[1]}
    raise ValueError("unknown gate basis %r" % (basis,))


def _hop_net_changes(state_changes):
    net = {}
    for row in state_changes or []:
        before, after = int(row["before"]), int(row["after"])
        if before == after:
            continue
        key = (row["storage"], int(row.get("bank", 0)), int(row["index"]))
        net[key] = {
            "storage": row["storage"], "bank": int(row.get("bank", 0)), "index": int(row["index"]),
            "before": before, "after": after,
        }
    return net


def flow_hop_net_changes(argument_storage, replay_variant, index):
    """Hop `index`'s net changes without call-argument storage (TD-56 D11): a `global_i32`
    change is left out when a command-`0x09` literal of this hop, or of an earlier hop of
    the same variant, wrote it (the hops' `executed` maps; absent in a v2 replay)."""
    net_changes = _hop_net_changes(replay_variant["hops"][index].get("state_changes"))
    return argument_storage.split(net_changes, [hop.get("executed") for hop in replay_variant["hops"][:index + 1]])


def flow_body_net_changes(argument_storage, replay_variant):
    """The variant's whole-run net changes without call-argument storage: the covering
    `0x09` may sit in any hop."""
    net_changes = _hop_net_changes(replay_variant.get("state_changes"))
    return argument_storage.split(net_changes, [hop.get("executed") for hop in replay_variant["hops"]])


def _resolve_dialogue_list(dialogue, text_doc_by_entry):
    resolved = []
    for entry in dialogue:
        entry = json.loads(json.dumps(entry))
        if entry.get("kind") == "text":
            text_ref = entry["text_ref"]
            strings = text_doc_by_entry[text_ref["entry"]]["strings"]
            text_ref["text"] = strings[text_ref["s"]]
        resolved.append(entry)
    return resolved


def flow_involved_entries(hops, replay_variant):
    """The entries whose package documents resolve a flow's replayed lines: its hop entries and
    every entry that played a line in the replayed variant - a hop runs the scripts it
    dispatches inline (`K_PIC`, `K_INTRO` inside the caller's hop 1, EP-12 TALK, 2026-10-04).
    Every earlier flow's lines came from its hop entries, so its documents do not move."""
    return sorted({h["entry"] for h in hops}
                  | {m["entry"] for replay_hop in replay_variant["hops"] for m in replay_hop.get("messages", [])})


def flow_dependencies(members, exclude_entries, restrict_to=None):
    """The `nested_presentation` dependencies of a flow document: the group's members its own
    hops and supports do not account for (`exclude_entries`); `restrict_to`, when given, keeps
    only the entries a route runs (the album branch: the hop entries, a group that declares
    every scene of its menu; the TALK branch: `talk_route_entries`, a group that declares
    every rung script of a heroine). Date flows pass none and keep every such member."""
    return [
        {"entry": m["entry"], "entry_sha256": m["entry_sha256"], "role": "nested_presentation"}
        for m in members if m["entry"] not in exclude_entries and (restrict_to is None or m["entry"] in restrict_to)
    ]


def talk_route_entries(archive, route, profile, replay_route, members):
    """The entries one TALK route runs (EP-12 TALK, 2026-10-04, tool decision, the album
    branch's counterpart): the group declares every rung script of a heroine as a member, and
    a rung depends on none of the others. The route's own entries are its hop entries, every
    entry that played a line in any of its replayed variants (the inline nested scripts and the
    follow-on a variant reaches, `K_TALKXX` for the rungs that call it) and the silent nested
    scripts its hops dispatch (`K_PIC`): a dispatch inside the span a hop runs - the origin hop
    from the origin to its outcome, a nested call from the start of its script, a resume from
    the call's end - whose target is a group member, minus the callee scripts of the profile's
    other routes (the ladder's other rungs sit statically inside the caller's span, behind
    branches this route does not take)."""
    own = {h["entry"] for h in route["hops"]}
    entries = set(own)
    for variant in replay_route.get("variants", []):
        for replay_hop in variant.get("hops", []):
            entries.update(m["entry"] for m in replay_hop.get("messages", []))
    siblings = {r["hops"][1]["entry"] for r in profile["routes"] if len(r["hops"]) > 1} - own
    member_entries = {m["entry"] for m in members}
    origin_offset = int(route["origin"]["offset"])
    for index, hop in enumerate(route["hops"]):
        outcome_offset = int(hop["expected"]["outcome"]["offset"])
        entered_by = hop.get("entered_by", {})
        if index == 0:
            start = origin_offset
        elif entered_by.get("kind") == "resume":
            start = int(route["hops"][index - 1]["entered_by"]["end"])
        else:
            start = 0
        for fact in facts(archive, hop["entry"], start, outcome_offset):
            if fact["kind"] == "dispatch" and fact["target"] in member_entries and fact["target"] not in siblings:
                entries.add(fact["target"])
    return entries


def flow_done_flag_line(conjunct_texts):
    """The first `unresolved` line of a non-album flow document (TD-43, closed
    by the EP-12 H unit, 2026-10-04): the flow's own origin guard, spelled by
    the conjuncts this producer already reads from it, names no cleared
    completion flag. Until then every such document carried heroine A's
    town-date guard text, whatever its own guard was."""
    return ("no done flag identified in the guard: the flow's own origin guard (%s) "
            "names no cleared completion flag" % "; ".join(conjunct_texts))


def build_flow_document(doc_id, row, meta, args, registry, names_fingerprint, profiles, state_cells_table):
    profile = profiles[meta["profile_stem"]]
    route = next(r for r in profile["routes"] if r["route_id"] == meta["route_id"])

    manifest = ped.load_json(os.path.join(args.package, "manifest.json"))
    replay_path = os.path.join(args.replays_dir, "%s.json" % meta["profile_stem"])
    replay_doc = ped.load_json(replay_path)
    if replay_doc["archive_sha256"] != manifest["source"]["archive_sha256"]:
        print("ARCHIVE MISMATCH between replay and package manifest")
        return 1
    if replay_doc["archive_sha256"] != profile["archive_sha256"]:
        print("ARCHIVE MISMATCH between replay and profile")
        return 1
    replay_route = next((r for r in replay_doc["routes"] if r["route_id"] == meta["route_id"]), None)
    if replay_route is None:
        print("REPLAY MISSING route %s" % meta["route_id"])
        return 1

    variant = route["variants"][0]
    replay_variant = next((v for v in replay_route["variants"] if v["variant_id"] == variant["variant_id"]), None)
    if replay_variant is None:
        print("REPLAY MISSING variant %s/%s" % (meta["route_id"], variant["variant_id"]))
        return 1
    if not replay_variant.get("reached", True):
        print("VARIANT NOT REACHED for %s" % doc_id)
        return 1

    members = profile.get("source_members", [])
    members_by_entry = {m["entry"]: m["entry_sha256"] for m in members}
    manifest_members = {e["entry"]: e["entry_sha256"] for e in manifest.get("entries", [])}
    for m in members:
        if m["entry"] in manifest_members and manifest_members[m["entry"]] != m["entry_sha256"]:
            print("PACKAGE MEMBER MISMATCH for %s" % m["entry"])
            return 1
    package_binding = {"schema": manifest["schema"], "package_sha256": manifest["package_sha256"]}

    display = {
        "title_ko": row.get("title_ko", ""), "title_en": row.get("title_en", ""),
        "heroine": row.get("heroine", ""), "category": row.get("category", ""), "place": row.get("place", ""),
    }

    origin = route["origin"]
    origin_entry = origin["entry"]
    guard_info = origin["guard"]
    archive = Archive(args.arc)
    parts = ped.conjuncts(archive, origin_entry, int(guard_info["offset"]))
    conjunct_rows = [ped.map_conjunct(p, ped.AFFECTION_HEROINE_LETTERS) for p in parts]
    witnesses = [
        {"case_id": c["case_id"], "writes": ped.absolute_rows(c.get("writes", [])), "expected": int(c["expected"])}
        for c in origin.get("guard_cases", [])
    ]
    guard = {
        "offset": int(guard_info["offset"]), "end": int(guard_info["end"]),
        "false_target": int(guard_info["false_target"]), "record_sha256": guard_info["record_sha256"],
        "conjuncts": conjunct_rows, "witnesses": witnesses,
    }
    ast = ped.guard_ast(archive, origin_entry, int(guard_info["offset"]))
    conditions = [{
        "type": "mes_expression", "ast": ast, "source_offset": int(guard_info["offset"]),
        "failure_reason": "guard_rejected",
    }]

    gallery = is_gallery_registry_row(row)  # an album scene: two hops (the menu, the scene to its return)
    if gallery:
        # An album scene replays whenever its unlock flag is set; the flag is
        # set by ordinary play and no literal write clears it
        # (docs/spec/mes/gallery_families.md).
        unresolved = [
            "no done flag identified in the guard: the origin guard is the scene's own unlock test, "
            "set by ordinary play and never cleared by a literal write; the scene replays whenever it holds",
        ]
    else:
        unresolved = [flow_done_flag_line([part["text"] for part in parts])]
    unresolved.extend(route.get("unresolved", []) or [])

    hops = route["hops"]
    hop0 = hops[0]
    hop1 = hops[1]
    hop0_outcome = hop0["expected"]["outcome"]
    evidence_row = row.get("evidence", {})

    trigger = {
        "type": "caller_dispatch",
        "caller": {
            "entry": origin_entry, "entry_sha256": members_by_entry.get(origin_entry, ""),
            "offset": int(hop0_outcome["offset"]), "end": int(hop0_outcome["end"]),
            "command": int(evidence_row["command"]), "kind": "nested_call",
        },
        "callee": {
            "entry": hop1["entry"], "entry_sha256": members_by_entry.get(hop1["entry"], ""),
            "start_coordinate": 0,
        },
        "origin": {"kind": "typed_guard", "offset": int(guard_info["offset"])},
    }
    order_hint = pv4.compute_order_hint(
        registry, profiles, doc_id, origin_entry, int(guard_info["offset"]), int(guard_info["false_target"]))
    if order_hint is not None:
        trigger["order_hint"] = order_hint

    presets = [{"preset_id": "baseline", "label": "baseline", "writes": ped.absolute_rows(route.get("baseline", []))}]
    seeded_writes = []
    for hop in hops:
        for gate in hop.get("gates", []) or []:
            if gate.get("basis") == "tool_seeded":
                seeded_writes.append({
                    "storage": gate["storage"], "bank": int(gate.get("bank", 0)),
                    "index": int(gate["index"]), "value": int(gate["value"]),
                })
    if seeded_writes:
        presets.append({"preset_id": "seeded_gates", "label": "seeded_gates", "writes": ped.absolute_rows(seeded_writes)})

    involved_entries = flow_involved_entries(hops, replay_variant)
    events_doc_by_entry = {entry: ped.load_events_document(args.package, entry) for entry in involved_entries}

    report = {"missing_records": [], "missing_text_operand": []}
    hops_out = []
    top_dialogue = []
    hop_after_unresolved = []
    all_evidence = []
    argument_storage = ped.ArgumentStorage(lambda entry: ped.load_events_document(args.package, entry))

    for index, hop in enumerate(hops):
        hop_id = hop["hop_id"]
        replay_hop = replay_variant["hops"][index]
        if replay_hop.get("hop_id") != hop_id:
            print("REPLAY HOP MISMATCH at index %d: %r != %r" % (index, replay_hop.get("hop_id"), hop_id))
            return 1

        entered_by_raw = hop["entered_by"]
        if index == 0:
            entered_by = {"kind": "origin", "offset": int(guard_info["offset"]), "end": int(guard_info["end"])}
        else:
            entered_by = {
                "kind": entered_by_raw["kind"],
                "offset": int(entered_by_raw["offset"]), "end": int(entered_by_raw["end"]),
            }

        answers = [
            {"boundary_offset": int(a["boundary_offset"]), "result_value": int(a["result_value"])}
            for a in hop.get("answers", []) or []
        ]
        gates = [
            {
                "storage": g["storage"], "bank": int(g.get("bank", 0)), "index": int(g["index"]),
                "value": int(g["value"]), "basis": _gate_basis(g["basis"]),
            }
            for g in hop.get("gates", []) or []
        ]
        map_locations = [
            {
                "entry": g["source_identity"]["entry"], "poll_offset": int(g["poll_offset"]),
                "values": [int(x) for x in g.get("locations", [])],
            }
            for g in hop.get("map_locations", []) or []
        ]
        poll_supplies = [
            {
                "definition": int(p["definition"]), "entry": p["entry"], "poll_offset": int(p["poll_offset"]),
                "result_storage": p["result_storage"], "result_index": int(p["result_index"]),
                "value": int(p["value"]),
            }
            for p in hop.get("poll_supplies", []) or []
        ]

        hop_dialogue = []
        for message in replay_hop.get("messages", []):
            entry = ped.build_dialogue_entry(message, events_doc_by_entry, report)
            if entry is None:
                print("FATAL missing_text_operand in hop %s: %s" % (hop_id, report["missing_text_operand"]))
                return 1
            hop_dialogue.append(entry)

        declared_keys = {
            (w["storage"], int(w.get("bank", 0)), int(w["index"]))
            for w in (hop.get("expected", {}).get("expected_state", []) or [])
        }
        net_changes = flow_hop_net_changes(argument_storage, replay_variant, index)
        candidate = {
            "net_changes": net_changes, "declared_keys": declared_keys,
            "route_id": meta["route_id"], "variant_id": hop_id,
        }
        hop_after_rows, hop_evidence = pv4.decide_effects_for_group(
            [candidate], hop_id, state_cells_table, {}, hop_after_unresolved)
        all_evidence.extend(hop_evidence)

        hops_out.append({
            "hop_id": hop_id, "entry": hop["entry"], "entry_sha256": members_by_entry.get(hop["entry"], ""),
            "entered_by": entered_by, "answers": answers, "gates": gates,
            "map_locations": map_locations, "poll_supplies": poll_supplies,
            "dialogue": hop_dialogue, "after": hop_after_rows,
            "message_count": len(hop_dialogue),
        })
        top_dialogue.append({"kind": "hop", "hop_id": hop_id})
        top_dialogue.extend(hop_dialogue)
    top_dialogue.append({"kind": "scene_end"})

    top_after_unresolved = []
    top_net_changes = flow_body_net_changes(argument_storage, replay_variant)
    top_candidate = {
        "net_changes": top_net_changes, "declared_keys": set(),
        "route_id": meta["route_id"], "variant_id": "body",
    }
    top_after_rows, top_evidence = pv4.decide_effects_for_group(
        [top_candidate], "body", state_cells_table, {}, top_after_unresolved)
    all_evidence = list(top_evidence) + all_evidence

    flow_terminal_id = "flow"
    route_terminal = route["terminal"]
    # A flow that ends in the last hop's own `script_return` (an album scene
    # going back to its menu, EP-12 gallery) is a `callee_return` terminal; a
    # handoff-ended flow keeps `natural_handoff`.
    terminals = {
        flow_terminal_id: {
            "kind": "callee_return" if route_terminal.get("status") == "script_return" else "natural_handoff",
            "owner_entry": route_terminal["entry"],
            "offset": int(route_terminal["offset"]), "end": int(route_terminal["end"]),
            "next_target": route_terminal.get("target", ""), "required_state": [],
        },
    }

    flow_block = {
        "evidence": {"group": meta["group_id"], "profile_sha256": profile["payload_sha256"], "route": meta["route_id"]},
        "origin": {
            "entry": origin_entry, "entry_sha256": members_by_entry.get(origin_entry, ""),
            "offset": int(origin["offset"]),
            "guard": {
                "offset": int(guard_info["offset"]), "end": int(guard_info["end"]),
                "false_target": int(guard_info["false_target"]), "record_sha256": guard_info["record_sha256"],
            },
        },
        "state_context": route.get("state_context", {"kind": "fresh"}),
        "hops": hops_out,
        "terminal": flow_terminal_id,
    }

    results = {
        "result_default": {
            "selected_by": {"kind": "default"}, "event_played": True,
            "dialogue": [], "after": [], "terminal": flow_terminal_id,
        },
    }

    exclude_entries = {origin_entry, hop1["entry"], "START.MES", "DEF_MAIN.MES", "LIBLARY.LIB"}
    # An album group declares every scene of its menu as a member; a scene
    # route depends on none of the others, only on the entries its own hops run.
    # A TALK group declares every rung script of a heroine as a member (EP-12 TALK): a rung
    # depends only on the entries its own route runs (`talk_route_entries`).
    talk = is_talk_registry_row(row)
    if talk:
        restrict_to = talk_route_entries(archive, route, profile, replay_route, members)
    elif gallery:
        restrict_to = {h["entry"] for h in hops}
    else:
        restrict_to = None
    dependencies = flow_dependencies(members, exclude_entries, restrict_to)

    evidence = {
        "kind": "analysis_group",
        "archive_sha256": profile["archive_sha256"],
        "groups": [{"group_id": meta["group_id"], "profile_sha256": profile["payload_sha256"], "route_ids": [meta["route_id"]]}],
        "members": [{"entry": m["entry"], "entry_sha256": m["entry_sha256"]} for m in members],
        "document_refs": [],
        "effect_witnesses": all_evidence,
    }

    final_unresolved = ped.merge_unresolved(unresolved + hop_after_unresolved + top_after_unresolved + argument_storage.lines())

    document = {
        "schema_version": SCHEMA_VERSION,
        "contract_fingerprint": ped.resolve_contract_fingerprint(args.contract_fingerprint),
        "names_fingerprint": names_fingerprint,
        "id": doc_id,
        "kind": "event",
        "display": display,
        "evidence": evidence,
        "package_binding": package_binding,
        "trigger": trigger,
        "scenes": [],
        "guard": guard,
        "conditions": conditions,
        "presets": presets,
        "dialogue": top_dialogue,
        "after": top_after_rows,
        "results": results,
        "terminals": terminals,
        "dependencies": dependencies,
        "presentation": {"status": "deferred", "resources": []},
        "unresolved": final_unresolved,
        "flow": flow_block,
    }

    pv4.recompute_cell_classes(document, state_cells_table)

    os.makedirs(args.out, exist_ok=True)
    tracked_path = os.path.join(args.out, "%s.json" % doc_id)
    with open(tracked_path, "w", encoding="utf-8", newline="\n") as fh:
        json.dump(document, fh, indent=2, ensure_ascii=False, sort_keys=False)
        fh.write("\n")

    text_doc_by_entry = {entry: ped.load_text_document(args.package, entry) for entry in involved_entries}
    resolved_document = json.loads(json.dumps(document))
    resolved_document["dialogue"] = _resolve_dialogue_list(top_dialogue, text_doc_by_entry)
    for hop_out, resolved_hop in zip(hops_out, resolved_document["flow"]["hops"]):
        resolved_hop["dialogue"] = _resolve_dialogue_list(hop_out["dialogue"], text_doc_by_entry)

    resolved_dir = args.resolved_out or args.out
    os.makedirs(resolved_dir, exist_ok=True)
    resolved_path = os.path.join(resolved_dir, "%s.resolved.json" % doc_id)
    with open(resolved_path, "w", encoding="utf-8", newline="\n") as fh:
        json.dump(resolved_document, fh, indent=2, ensure_ascii=False)
        fh.write("\n")

    print("PROJECTED %s (flow)" % doc_id)
    print("hops=%d top_dialogue=%d" % (len(hops_out), len(top_dialogue)))
    print("WROTE %s" % tracked_path)
    print("WROTE %s" % resolved_path)
    return 0


def run_site_v6(args):
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
    meta = _flow_meta(row, profiles)
    if meta is not None:
        if meta["profile_stem"] not in profiles:
            print("FLOW PROFILE NOT FOUND: %s" % meta["profile_stem"])
            return 1
        return build_flow_document(
            args.site, row, meta, args, registry, names_fingerprint, profiles, state_cells.load())

    # TD-37: the v6 projection fails closed on absent or stale witness
    # evidence unless the caller opted out (`pv4.resolve_witness_indexes`).
    # The flow path above never reads witnesses.
    args.require_witnesses = not args.allow_missing_witnesses
    previous_schema = pv5.SCHEMA_VERSION
    pv5.SCHEMA_VERSION = SCHEMA_VERSION
    try:
        rc = pv5.run_site_v5(args)
    finally:
        pv5.SCHEMA_VERSION = previous_schema
    return rc


def run_catalog_v6(args):
    previous_schema = pv5.SCHEMA_VERSION
    pv5.SCHEMA_VERSION = SCHEMA_VERSION
    try:
        return pv5.run_catalog_v5(args)
    finally:
        pv5.SCHEMA_VERSION = previous_schema


def build_parser():
    """The command line shared by v6 and its wrapper `project_event_definition_v7.py`
    (which overrides the `--replays-dir` and `--contract-fingerprint` defaults)."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--catalog")
    parser.add_argument("--event")
    parser.add_argument("--site")
    parser.add_argument("--profiles-dir", default=os.path.join("config", "event_catalog", "analysis_groups"))
    parser.add_argument("--replays-dir", default=os.path.join("analysis", "replays_v2"))
    parser.add_argument("--witnesses-dir", default=os.path.join("analysis", "witnesses"))
    parser.add_argument("--allow-missing-witnesses", action="store_true", default=False,
                        help="project a site whose witness evidence is absent without it (loud per-site "
                             "warning); stale evidence (a payload_sha256 that is not the profile's) is "
                             "still refused (TD-37)")
    parser.add_argument("--names", required=True)
    parser.add_argument("--package", required=True)
    parser.add_argument("--replay")
    parser.add_argument("--arc", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--resolved-out", default=None)
    parser.add_argument("--shared-lines", default=None)
    parser.add_argument("--contract-fingerprint", default=DEFAULT_CONTRACT_FINGERPRINT_PATH)
    return parser


def main():
    args = build_parser().parse_args()

    if bool(args.event) == bool(args.site):
        print("exactly one of --event or --site is required")
        return 1
    if args.event:
        if not args.catalog or not args.replay:
            print("--event requires --catalog and --replay")
            return 1
        return run_catalog_v6(args)
    return run_site_v6(args)


if __name__ == "__main__":
    sys.exit(main())
