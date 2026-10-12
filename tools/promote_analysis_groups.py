"""Promotes every measured analysis-group v4 event definition into a
generated Event Catalog row (EP-10 unit 5b, owner ruling 2026-09-21,
option 1: every hand-authored catalog row moves to the shared path). See
`analysis/_docs/ep10_unit5bc_spec.md` for the full rule set this tool
follows (superseding `analysis/_docs/ep10_unit1_promotion_spec.md`'s
"skip a site that has a hand-authored row" rule, which is gone: every v4
document becomes a generated row, and the catalog carries no hand-authored
rows at all).

Pure standard library (json, hashlib, pathlib, argparse), style of
`tools/project_event_definitions_batch.py`. `event_outcome_vocabulary`
(sibling module in this directory) supplies `profile_route_outcome`, used
to derive each row's `playback_status`/`classification` from the winning
route of its default option.

    py tools/promote_analysis_groups.py [--catalog config/event_catalog/original_events_v1.json]
        [--definitions-dir config/event_definitions/v7] [--profiles-dir config/event_catalog/analysis_groups]
        [--out <path>] [--check]

`--definitions-dir` (alias `--v4-dir`, kept for existing callers) defaults to
the live v7 definition set, not the frozen v4 or v6 (checkpoint C, 2026-09-25:
v6 over v4; WD-21 U2 C5, 2026-10-08: v7 over v6). v7 is v6 plus one field,
`presentation.resources`, and this tool reads the v4-shape fields it always
read plus that one: each row's `resources` is the document's measured media
list, mapped to the catalog's resource item (`resource_id` `res-<ordinal>`,
`request_entry`, `request_offset`, `entry`; `docs/spec/tech/event_player.md`).
A definitions directory that is not v7 is refused: a v6 set would silently
promote empty lists.

`--out` defaults to `--catalog` (in-place). `--check` regenerates into
memory and exits 0 only when the result equals the file at `--catalog`
byte for byte (prints a one-line diff summary otherwise, exit 1).
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

from event_outcome_vocabulary import event_intro_index, flow_route_outcome, profile_route_outcome
from payload_values import is_gallery_registry_row, is_safe_leaf, is_talk_registry_row

ROOT = Path(__file__).resolve().parents[1]

DEFAULT_CATALOG = "config/event_catalog/original_events_v1.json"
# EP-12 PROMIS checkpoint C (2026-09-25): the promoter's document source is
# the live definition set, not the frozen v4. v6 is a superset of v4's shape
# (`docs/spec/data/event_definition_v6.md`, "v3's, v4's and v5's own
# producers, documents, indexes and tests stay byte-identical") and this
# tool reads only v4-shape fields, so pointing it at v6 changes nothing for
# the 175 existing rows and lets a v6-only site (no v4/v5 document of its
# own) be promoted too. `--v4-dir` stays as an alias for `--definitions-dir`.
# WD-21 U2 C5 (2026-10-08): the live set is v7 (v6 plus `presentation.resources`,
# the measured media list the catalog's `resources` come from); v6 is frozen.
DEFAULT_DEFINITIONS_DIR = "config/event_definitions/v7"
DEFINITION_SCHEMA = "kakyu_event_definition/v7"
DEFAULT_V4_DIR = DEFAULT_DEFINITIONS_DIR
DEFAULT_PROFILES_DIR = "config/event_catalog/analysis_groups"
DEFAULT_REGISTRY = "config/contracts/event_names_v1/event_names.json"
# EP-12 gallery (2026-10-04): the census of byte-identical message groups
# (`tools/audit_duplicate_entries.py`) the `duplicate_route` rule reads.
DEFAULT_DUPLICATES = "config/event_catalog/duplicate_entries_v1.json"

CATALOG_REVISION = 43  # TD-56 C5 (2026-10-11): each row's `resources` gains the restored `LIBLARY.LIB` items (v7 `presentation.resources` re-projected at Core 0.377.0), 17,020 -> 18,113 items in 293 rows; no row added or changed otherwise; before it 42, TD-56 C4 bridge (2026-10-10): the 13 analysis-group profiles C3 re-derived are rebound in the rows that name them (14 `profile_sha256` values), rows otherwise as 41; before it 41, WD-21 U2 C5 (2026-10-08): each row's `resources` is its event definition's measured media list (v7 `presentation.resources`), 17,020 items in 681 rows; no row added or changed otherwise; before it 40, EP-12 TALK follow-ups (2026-10-05): `N_TALK1`'s resume measured to reach the `FLOOR5.MES` handoff, its row three hops and `map_return` (the `27c-ev-n-talk` group re-hashed; no row added); before it 39, EP-12 TALK rest unit (2026-10-05): +105 rows, the other eleven heroines' conversation scripts (88 rung scripts at the 01M.MES ladder blocks, 8 plain scripts at 27C_EV.MES), Tina's M_TALK and the characters' N_TALK..Q_TALK1 (8 rows); before it 38, EP-12 TALK K unit (2026-10-04): +9 rows, heroine K's conversation scripts (the eight rung scripts at the 01M.MES ladder block, the plain K_TALK at 27C_EV.MES); before it 37, EP-12 H unit (2026-10-04): +13 rows, the recollection ladders of the room; before it 36 (EP-12 SCENE all-menus unit: +340 rows, the other twelve album menus, 365 album scenes in all; 33 duplicate_route)

# EP-12 catalog part (2026-09-24): a `kakyu_event_analysis_group/v14` flow
# profile yields rows directly (there is no v4 document for it) - see
# `build_flow_row` and `generate_flow_rows`, the promoter's own flow branch.
FLOW_SCHEMA = "kakyu_event_analysis_group/v14"
GALLERY_CATEGORY = "gallery"

# WD-21 U2 C5: the v7 `presentation.resources` item's keys, and the largest list
# the catalog's four-digit `resource_id` ordinal can number.
RESOURCE_ITEM_KEYS = ("entry", "source_offset", "kind", "name")
MAX_RESOURCE_ORDINAL = 9999

# v4 terminal kind -> (catalog kind, outcome, runtime_status, sequence)
TERMINAL_KIND_MAP = {
    "root_handoff": ("root_replacement", "normal_completion", "script_handoff_boundary", 10),
    "natural_handoff": ("caller_handoff", "normal_completion", "script_handoff_boundary", 30),
    "callee_return": ("callee_return_only", "continue", "script_return", 10),
    "def_selection_boundary": ("analysis_boundary", "unresolved", "def_selection_boundary", 30),
    "caller_menu_loop": ("analysis_boundary", "unresolved", "loop_boundary", 30),
    "dependency_stop": ("analysis_boundary", "unresolved", "script_dispatch_boundary", 30),
}

SLUG_ALPHABET = set("abcdefghijklmnopqrstuvwxyz0123456789-_")


def load_json(path) -> dict:
    with open(path, "r", encoding="utf-8") as fh:
        return json.load(fh)


def slugify(value: str) -> str:
    lowered = str(value).lower()
    return "".join(ch if ch in SLUG_ALPHABET else "-" for ch in lowered)


def hex8(value: int) -> str:
    return "%08x" % int(value)


def stem_of(entry: str) -> str:
    return Path(str(entry)).stem.lower()


def load_profiles(profiles_dir: Path) -> dict:
    """`group_id -> [profile document, ...]`. A `group_id` can be declared
    by more than one profile file (e.g. a superseded and a current version);
    callers disambiguate by `payload_sha256`."""
    by_group: dict = {}
    for path in sorted(Path(profiles_dir).glob("*.json")):
        doc = load_json(path)
        group_id = doc.get("group_id")
        if not group_id:
            continue
        by_group.setdefault(group_id, []).append(doc)
    return by_group


def find_profile(by_group: dict, group_id: str, profile_sha256: str):
    for doc in by_group.get(group_id, []):
        if doc.get("payload_sha256") == profile_sha256:
            return doc
    return None


def find_route(profile_doc: dict, route_id: str):
    for route in profile_doc.get("routes", []):
        if route.get("route_id") == route_id:
            return route
    return None


def load_definition_documents(definitions_dir: Path) -> tuple:
    """`(site documents, flow documents by id)` of a definitions directory, in
    one pass over its files. Checkpoint C (2026-09-25): a v14 flow route's own
    document carries a top-level `flow` block (v4/v5 never do, and a flow
    route has no v4/v5 document of its own) - `generate_flow_rows` promotes
    those from the profile directly, so the site list skips them or
    `build_row` would misread the flow shape and duplicate the row. WD-21 U2
    C5: the flow documents are kept, by id, because their `presentation`
    carries the row's `resources`."""
    sites = []
    flows: dict = {}
    for path in sorted(Path(definitions_dir).glob("*.json")):
        if path.name == "index.json":
            continue
        document = load_json(path)
        if "flow" in document:
            flows[document["id"]] = document
        else:
            sites.append(document)
    return sites, flows


def load_v4_documents(v4_dir: Path) -> list:
    return load_definition_documents(v4_dir)[0]


def catalog_resources(document: dict) -> list:
    """The catalog `resources` of a v7 definition: its `presentation.resources`
    (the media its measured route reaches; `docs/spec/data/event_definition_v7.md`)
    mapped to the catalog's resource item as `content_core/event_catalog.gd`
    validates it (WD-21 U2 C5, tool decision D8, no Core change):

    - `resource_id`: `res-<4-digit ordinal in the document's sorted list, from
      0001>`. The ordinals shift whenever a row's list changes; nothing
      references them (only a branch could, and `branches` is empty);
    - `request_entry`: the item's `entry`, `request_offset`: its `source_offset`;
    - `entry`: the item's `name`, a safe leaf (a failure stops the tool).

    There is no `kind` (a catalog schema change, not part of this unit), no
    `original_entry_sha256` (identity lives in the package's inventory) and no
    `branch_ids`. A catalog consumer joins `(request_entry, request_offset,
    entry)` to the definition or the inventory."""
    definition_id = document.get("id", "?")
    if document.get("schema_version") != DEFINITION_SCHEMA:
        raise SystemExit(
            "%s: schema_version %r is not %s; the catalog's resources come from a v7 definition set"
            % (definition_id, document.get("schema_version"), DEFINITION_SCHEMA)
        )
    presentation = document.get("presentation")
    items = presentation.get("resources") if isinstance(presentation, dict) else None
    if not isinstance(items, list):
        raise SystemExit("%s: presentation.resources is not a list" % definition_id)
    if len(items) > MAX_RESOURCE_ORDINAL:
        raise SystemExit("%s: %d resources exceed the four-digit ordinal" % (definition_id, len(items)))
    resources = []
    previous = None
    for ordinal, item in enumerate(items, start=1):
        if not isinstance(item, dict) or set(item) != set(RESOURCE_ITEM_KEYS):
            raise SystemExit("%s: resource %d does not have exactly the keys %s" % (definition_id, ordinal, ", ".join(RESOURCE_ITEM_KEYS)))
        entry, offset, kind, name = item["entry"], item["source_offset"], item["kind"], item["name"]
        if not is_safe_leaf(entry):
            raise SystemExit("%s: resource %d entry %r is not a safe leaf" % (definition_id, ordinal, entry))
        if not is_safe_leaf(name):
            raise SystemExit("%s: resource %d name %r is not a safe leaf" % (definition_id, ordinal, name))
        if isinstance(offset, bool) or not isinstance(offset, int) or offset < 0:
            raise SystemExit("%s: resource %d source_offset %r is not an integer >= 0" % (definition_id, ordinal, offset))
        key = (entry, offset, kind, name)
        if previous is not None and key <= previous:
            raise SystemExit("%s: resource %d is not in sorted order (the ordinal ids would not be stable)" % (definition_id, ordinal))
        previous = key
        resources.append({
            "resource_id": "res-%04d" % ordinal,
            "request_entry": entry,
            "request_offset": offset,
            "entry": name,
        })
    return resources


def default_route_for_playback(route_entries: list, choices: list):
    """The route selected for the row's default option (unit 5bc, part 5):
    mirrors the runtime default in `event_catalog.gd`
    `_build_group_route_request`, which is the first option whose
    `terminal_ids` is non-empty, not `choices[0]["options"][0]`. With
    choices, take `choices[0]`'s first option with a non-empty
    `terminal_ids`; if one is found, return the route among `route_entries`
    that has a variant selecting it (`owner_entry`, `boundary_offset`,
    `result_value` via `route_has_selection`). If no option is measured, or
    no route selects the measured option, fall through to the row's first
    referenced route (`route_entries[0]`), same as before. `None` when the
    document names no route at all."""
    if not route_entries:
        return None
    if choices:
        first_choice = choices[0]
        owner_entry = first_choice["owner_entry"]
        boundary = int(first_choice["boundary_offset"])
        measured_option = None
        for option in first_choice["options"]:
            if option.get("terminal_ids"):
                measured_option = option
                break
        if measured_option is not None:
            value = int(measured_option["result_value"])
            for group_id, profile_sha256, route_id, route in route_entries:
                if route_has_selection(route, owner_entry, boundary, value):
                    return route
    return route_entries[0][3]


def playback_status_and_classification(route_entries: list, choices: list, intros: dict | None = None) -> tuple:
    """Unit 5b's `playback_status`/`classification` rule: `minimal_playback`
    / `playable_event` when the default option's winning route ends
    `map_return`, `place_menu` or `chain` (`profile_route_outcome`);
    `analysis_only` / `unresolved_route` otherwise (an `unresolved` ending -
    a dependency stop or an undeclared continuation - or no route at all).
    `intros` (see `event_outcome_vocabulary.event_intro_index`) reclassifies
    a dependency stop landing exactly on another event's intro dispatch as
    `chain` (owner ruling 2026-09-23, EP-03 step 2)."""
    route = default_route_for_playback(route_entries, choices)
    if route is None:
        return "analysis_only", "unresolved_route"
    outcome = profile_route_outcome(route, intros)["outcome"]
    if outcome in ("map_return", "place_menu", "chain"):
        return "minimal_playback", "playable_event"
    return "analysis_only", "unresolved_route"


def build_event_id(doc: dict) -> str:
    callee_stem = stem_of(doc["trigger"]["callee"]["entry"])
    caller_stem = stem_of(doc["trigger"]["caller"]["entry"])
    offset_hex = hex8(doc["trigger"]["caller"]["offset"])
    return "original/%s/%s-%s" % (callee_stem, caller_stem, offset_hex)


def build_display(doc: dict) -> dict:
    display = doc.get("display", {})
    heroine = str(display.get("heroine") or "").strip()
    character_ids = [heroine] if heroine else []
    category = display.get("category", "")
    return {
        "title": display.get("title_en", ""),
        "character_ids": character_ids,
        "categories": ["character_event", category],
    }


def build_source(doc: dict, by_group: dict, winners: set) -> dict:
    # Owner ruling (2026-09-20, item 2a): required_entries is the union of
    # the document's own `evidence.members` and every entry each referenced
    # profile's `source_members` names (minus the caller and callee), not
    # just the document's own member list - a row can promise a route from
    # one group (e.g. an arrival) while a sibling group (e.g. its
    # continuation) needs entries the document itself never lists.
    caller = doc["trigger"]["caller"]
    callee = doc["trigger"]["callee"]
    caller_upper = str(caller["entry"]).upper()
    callee_upper = str(callee["entry"]).upper()
    ordered: list = []
    seen: set = set()

    def add(member: dict) -> None:
        entry_upper = str(member["entry"]).upper()
        if entry_upper in (caller_upper, callee_upper) or entry_upper in seen:
            return
        seen.add(entry_upper)
        ordered.append(member)

    for member in doc["evidence"]["members"]:
        add(member)
    for index, group in enumerate(doc["evidence"]["groups"]):
        if index not in winners:
            continue
        profile_doc = find_profile(by_group, group["group_id"], group["profile_sha256"])
        if profile_doc is None:
            raise SystemExit(
                "%s: no profile for group %s matches profile_sha256 %s"
                % (doc["id"], group["group_id"], group["profile_sha256"])
            )
        for member in profile_doc.get("source_members", []):
            add(member)
    required = ordered
    return {
        "caller": {
            "archive": "mes.arc",
            "entry": caller["entry"],
            "entry_sha256": caller["entry_sha256"],
            "dispatch_offset": caller["offset"],
            "resume_offset": caller["end"],
            "command": caller["command"],
        },
        "callee": {
            "archive": "mes.arc",
            "entry": callee["entry"],
            "entry_sha256": callee["entry_sha256"],
            "start_coordinate": callee["start_coordinate"],
            "address_index": -1,
        },
        "required_entries": [
            {
                "archive": "mes.arc",
                "entry": member["entry"],
                "entry_sha256": member["entry_sha256"],
                "role": "analysis_group_member",
            }
            for member in required
        ],
    }


def build_activation(doc: dict) -> dict:
    caller = doc["trigger"]["caller"]
    kind = "host_handoff" if int(caller["command"]) == 14 else "nested_zero_start"
    caller_stem = stem_of(caller["entry"])
    ref_path = "docs/spec/mes/%s_caller_group.md" % caller_stem
    document_refs = [ref_path] if (ROOT / ref_path).is_file() else []
    groups = doc["evidence"]["groups"]
    group_ids = ", ".join(str(group["group_id"]) for group in groups)
    origin = doc["trigger"]["origin"]
    notes = "origin %s at %s; analysis group %s" % (origin["kind"], origin["offset"], group_ids)
    return {
        "kind": kind,
        "evidence_level": "confirmed",
        "evidence_types": ["authoritative_arc", "headless_replay"],
        "document_refs": document_refs,
        "notes": notes,
    }


def all_terminal_ids(doc: dict) -> list:
    """Owner ruling (2026-09-20, item 2b): every entry of the v4 `terminals`
    map, in the document's own order - not only the ones a `results` entry
    references (`results` nests choice branches inconsistently; the row
    must expose every coordinate a referenced route can actually stop at)."""
    return list(doc.get("terminals", {}).keys())


def _schema_version(profile_doc: dict) -> int:
    schema = str(profile_doc.get("schema", ""))
    if "/v" in schema:
        try:
            return int(schema.rsplit("/v", 1)[1])
        except ValueError:
            return -1
    return -1


def winning_group_indexes(doc: dict, by_group: dict) -> set:
    """The indexes into `doc['evidence']['groups']` that win their group_id
    (owner ruling 2026-09-20, round 7): when a group_id is named by more
    than one profile hash in the row, only the reference whose profile has
    the highest analysis-group schema version contributes routes (presets,
    choices, required entries); a tie keeps the first reference in the
    row's own order. The losing reference stays in the row's
    `analysis_group.groups` block (it is evidence) but contributes no
    routes. A group_id named only once always wins by itself."""
    groups = doc["evidence"]["groups"]
    by_group_id: dict = {}
    for index, group in enumerate(groups):
        by_group_id.setdefault(group["group_id"], []).append(index)
    winners: set = set()
    for group_id, indexes in by_group_id.items():
        if len(indexes) == 1:
            winners.add(indexes[0])
            continue
        best_index = None
        best_version = None
        for index in indexes:
            group = groups[index]
            profile_doc = find_profile(by_group, group["group_id"], group["profile_sha256"])
            if profile_doc is None:
                raise SystemExit(
                    "%s: no profile for group %s matches profile_sha256 %s"
                    % (doc["id"], group["group_id"], group["profile_sha256"])
                )
            version = _schema_version(profile_doc)
            if best_version is None or version > best_version:
                best_version = version
                best_index = index
        winners.add(best_index)
    return winners


def referenced_route_entries(doc: dict, by_group: dict, winners: set) -> list:
    """`[(group_id, profile_sha256, route_id, route), ...]` for every route
    every *winning* one of the document's `evidence.groups` names (see
    `winning_group_indexes`), in the row's own declared order (groups in
    order, each group's route_ids in order). A route id is not unique
    across a row's groups (the same id can legitimately appear under more
    than one group naming a genuinely different measured route), so every
    `(group_id, profile_sha256, route_id)` triple is kept as its own entry
    - the primary key `resolve_group_route_reference` resolves by at
    runtime."""
    entries: list = []
    for index, group in enumerate(doc["evidence"]["groups"]):
        if index not in winners:
            continue
        profile_doc = find_profile(by_group, group["group_id"], group["profile_sha256"])
        if profile_doc is None:
            raise SystemExit(
                "%s: no profile for group %s matches profile_sha256 %s"
                % (doc["id"], group["group_id"], group["profile_sha256"])
            )
        for route_id in group.get("route_ids", []):
            route = find_route(profile_doc, route_id)
            if route is not None:
                entries.append((group["group_id"], group["profile_sha256"], route_id, route))
    return entries


def route_terminal_coordinates(route: dict) -> list:
    """The `(owner_entry, offset)` coordinates the row's own terminals map
    can name for this route (owner ruling 2026-09-20, round 4, rule 2):
    `route.outcome` (owned by the route's callee) and, when the route has a
    `resume`, `route.resume.outcome` (owned by the route's caller)."""
    coordinates: list = []
    outcome = route.get("outcome")
    if isinstance(outcome, dict) and "offset" in outcome:
        callee_entry = str(route.get("callee", {}).get("entry", "")).upper()
        coordinates.append((callee_entry, int(outcome["offset"])))
    resume = route.get("resume")
    if isinstance(resume, dict):
        resume_outcome = resume.get("outcome")
        if isinstance(resume_outcome, dict) and "offset" in resume_outcome:
            caller_entry = str(route.get("caller", {}).get("entry", "")).upper()
            coordinates.append((caller_entry, int(resume_outcome["offset"])))
    return coordinates


def compose_writes(baseline_writes: list, variant_writes: list) -> list:
    """Unit 1's preset composition rule: the baseline writes in their own
    order, each key the variant overrides in place, new keys appended in
    the variant's order."""
    order = []
    by_key = {}
    for write in baseline_writes:
        key = (write["storage"], int(write["bank"]), int(write["index"]))
        order.append(key)
        by_key[key] = dict(write)
    for write in variant_writes:
        key = (write["storage"], int(write["bank"]), int(write["index"]))
        if key not in by_key:
            order.append(key)
        by_key[key] = dict(write)
    return [dict(by_key[key], evidence_level="confirmed") for key in order]


def _route_selection_owner(route: dict, selection: dict) -> str:
    owner = selection.get("owner_entry")
    if owner:
        return str(owner)
    # Owner ruling (2026-09-20, item 3): an old-schema profile's selection
    # without an owner_entry belongs to the route's own callee.
    return str(route.get("callee", {}).get("entry", ""))


def route_has_selection(route: dict, owner_entry: str, boundary: int, value: int) -> bool:
    for variant in route.get("variants", []):
        for selection in variant.get("selections", []):
            if (
                _route_selection_owner(route, selection) == owner_entry
                and int(selection["boundary_offset"]) == boundary
                and int(selection["result_value"]) == value
            ):
                return True
    return False


def build_terminals(doc: dict, ordered_ids: list, intros: dict | None = None) -> list:
    """`intros` (see `event_outcome_vocabulary.event_intro_index`): a
    `dependency_stop` terminal whose `(owner_entry, offset)` is in the index
    gets `next_target` = the indexed callee entry (owner ruling 2026-09-23,
    EP-03 step 2). The terminal's own kind/outcome/runtime_status
    (`analysis_boundary`/`unresolved`/`script_dispatch_boundary`) is
    unchanged - only `next_target` is written."""
    terms = doc["terminals"]
    rows = []
    for terminal_id in ordered_ids:
        term = terms[terminal_id]
        catalog_kind, outcome, runtime_status, sequence = TERMINAL_KIND_MAP[term["kind"]]
        required_state = [dict(row, operator="equals") for row in term.get("required_state", [])]
        next_target = term.get("next_target", "")
        if term["kind"] == "dependency_stop" and intros:
            owner_entry = str(term["owner_entry"]).upper()
            offset = term["offset"]
            callee_entry = intros.get((owner_entry, int(offset)))
            if callee_entry:
                next_target = callee_entry
        rows.append({
            "terminal_id": slugify(terminal_id),
            "kind": catalog_kind,
            "sequence": sequence,
            "outcome": outcome,
            "runtime_status": runtime_status,
            "owner_entry": term["owner_entry"],
            "offset": term["offset"],
            "required_state": required_state,
            "caller_resume_offset": term["end"],
            "next_target": next_target,
            "evidence_level": "confirmed",
        })
    return rows


def build_blockers(doc: dict, ordered_terminal_ids: list, intros: dict | None = None) -> list:
    blockers = [{
        "blocker_id": "bounded-native-presentation",
        "class": "native_presentation",
        "offset": 0,
        "blocks_playback": False,
        "summary": "Analysis omits native presentation: music, images, cadence and the host are not played.",
        "todo_id": "EP-10",
        "document_refs": [],
    }]
    terms = doc["terminals"]
    for terminal_id in ordered_terminal_ids:
        term = terms[terminal_id]
        if term["kind"] == "dependency_stop":
            if intros:
                owner_entry = str(term["owner_entry"]).upper()
                offset = term["offset"]
                if intros.get((owner_entry, int(offset))):
                    # Owner ruling (2026-09-23, EP-03 step 2): this stop
                    # lands exactly on another catalog event's intro
                    # dispatch, so the route continues into it (`chain`) -
                    # it is not a missing dependency any more.
                    continue
            blockers.append({
                "blocker_id": "dependency-stop-%s" % slugify(terminal_id),
                "class": "shared_library_call_frame",
                "offset": term["offset"],
                # Owner ruling (2026-09-20, round 9, item 5): the unbroken
                # run reaches this boundary and stops there on purpose - a
                # legitimate `unresolved` ending (see
                # `KakyuEventOutcomeVocabulary`), not a blocked route.
                "blocks_playback": False,
                "summary": "The route stops before a dependency the measurement did not provide.",
                "todo_id": "EP-10",
                "document_refs": [],
            })
    results = doc.get("results", {}) or {}
    for result_id, result in results.items():
        terminal_id = result.get("terminal")
        if terminal_id and terms.get(terminal_id, {}).get("kind") == "callee_return":
            blockers.append({
                "blocker_id": "continuation-undeclared-%s" % slugify(result_id),
                "class": "other",
                "offset": terms[terminal_id]["offset"],
                "blocks_playback": False,
                "summary": "The callee returns; the caller's continuation is not declared.",
                "todo_id": "EP-10",
                "document_refs": [],
            })
    seen_ids = set()
    for blocker in blockers:
        if blocker["blocker_id"] in seen_ids:
            raise SystemExit("%s: duplicate blocker id %s" % (doc["id"], blocker["blocker_id"]))
        seen_ids.add(blocker["blocker_id"])
    return blockers


def build_presets(route_entries: list) -> list:
    # Owner ruling (2026-09-20): presets come from the profiles, not the v4
    # document. Round 6/7: a route id is not unique across a row's groups
    # (the eventk09 row names a route literally called "eventk09" under
    # more than one group id), so the preset is the primary key of a run.
    # The notes always carry the exact profile
    # (`<group_id>@<hash12>/<route_id>/<variant_id>`, hash12 = the first 12
    # hex characters of that route's winning profile_sha256 - see
    # `winning_group_indexes`). The preset id is `<route_id>/<variant_id>`,
    # qualified with the group id only when the route id recurs across
    # *different* group ids of the row.
    #
    # Round 8: every variant of a winning route gets its own preset,
    # **empty writes included** - a variant that differs from its siblings
    # only by its `selections` (which choice it measures) is a measured
    # state of its own, not an interchangeable "baseline" (eventh02's
    # `choice-1`/`choice-2`/`choice-3`, all with empty writes, each measure
    # a different answer). The special collapsed `.../baseline` preset
    # (rounds 4-7, "one baseline preset per route, named after the first
    # empty-writes variant") is gone.
    route_id_group_ids: dict = {}
    for group_id, profile_sha256, route_id, route in route_entries:
        route_id_group_ids.setdefault(route_id, set()).add(group_id)

    rows = []
    for group_id, profile_sha256, route_id, route in route_entries:
        qualify = len(route_id_group_ids[route_id]) > 1
        hash12 = str(profile_sha256)[:12]
        baseline_writes = route.get("baseline", [])
        for variant in route.get("variants", []):
            variant_id = str(variant["variant_id"])
            writes = variant.get("writes", [])
            notes = "analysis-group variant %s@%s/%s/%s" % (group_id, hash12, route_id, variant_id)
            if qualify:
                id_key = "%s/%s/%s" % (group_id, route_id, variant_id)
            else:
                id_key = "%s/%s" % (route_id, variant_id)
            rows.append({
                "preset_id": slugify(id_key),
                "label": variant_id,
                "kind": "original_branch",
                "writes": compose_writes(baseline_writes, writes),
                "expected_branch_ids": [],
                "notes": notes,
            })
    return rows


def _default_variant_for_route(route: dict, choices: list):
    """The variant a row's default option resolves to within one specific
    route - `default_route_for_playback`'s selection rule applied inside a
    single route rather than across `route_entries`: the first variant
    whose own selection matches the row's default (first-measured) option,
    or the route's first variant when no choice or match applies."""
    variants = route.get("variants", [])
    if not variants:
        return None
    if choices:
        first_choice = choices[0]
        owner_entry = first_choice["owner_entry"]
        boundary = int(first_choice["boundary_offset"])
        measured_option = None
        for option in first_choice["options"]:
            if option.get("terminal_ids"):
                measured_option = option
                break
        if measured_option is not None:
            value = int(measured_option["result_value"])
            for variant in variants:
                for selection in variant.get("selections", []):
                    owner = _route_selection_owner(route, selection)
                    if owner == owner_entry and int(selection["boundary_offset"]) == boundary and int(selection["result_value"]) == value:
                        return variant
    return variants[0]


def _guard_declared_cells(route: dict) -> set:
    """EP-11 part 1c (owner ruling 2026-09-23, tool decision): the
    `(storage, bank, index)` cells a route's own `guard_cases` demonstrate
    the local guard is sensitive to - the union of every case's `writes`,
    read from the profile's own declared guard evidence, never a hard-coded
    cell list. A visit's `entry_state` excludes these: between visits the
    day change (DEF_MAIN.MES's registered definition 12, `44c_caller_group.md`)
    clears the day flags a guard like this one reads, not the callee itself,
    so the row's default preset's own accepting value for such a cell - not
    the value the callee's dispatch happened to leave it at - is what a
    visit preset should carry forward."""
    cells = set()
    for case in route.get("guard_cases", []):
        for write in case.get("writes", []):
            cells.add((write["storage"], int(write["bank"]), int(write["index"])))
    return cells


def build_visit_presets(route_entries: list, choices: list) -> list:
    """EP-11 part 1b/1c (owner rulings 2026-09-23): one preset for every v13
    `visits` entry of the route a row's default option uses - the route
    `default_route_for_playback` returns; nothing else in the row changes,
    and a route without `visits` contributes nothing here (part 1c removed
    `visits` from `44c-m10a`: that site's own guard closes itself for good
    once entered, so it has no later visits of its own - see
    `44c_caller_group.md`).

    `preset_id` is `<route_id>-<visit_id>`; `writes` is the row's default
    measured preset's own composed writes (the default route's `baseline`
    plus its default variant's `writes`), with the visit's `entry_state`
    composed on top - excluding any cell the route's own `guard_cases`
    declare the local guard reads (`_guard_declared_cells`; those keep the
    default preset's own accepting value) - then the visit's `seed_writes`
    (later writes win - the same `compose_writes` rule chained). `kind` is
    `tool_seeded_analysis` when the visit's `seed_basis` is `tool_seeded`,
    else `original_branch`. `notes` name the group, route and visit
    (`analysis-group variant <group_id>@<hash12>/<route_id>/<visit_id>`,
    the same shape an ordinary preset's notes use with the visit's own id in
    the variant slot) so `resolve_group_route_reference` finds the route: a
    visit carries no `selections` of its own, so it stands in for a variant
    there with none."""
    default_route = default_route_for_playback(route_entries, choices)
    if default_route is None:
        return []
    default_entry = next((entry for entry in route_entries if entry[3] is default_route), None)
    if default_entry is None:
        return []
    default_variant = _default_variant_for_route(default_route, choices)
    if default_variant is None:
        return []
    group_id, profile_sha256, route_id, route = default_entry
    default_writes = compose_writes(route.get("baseline", []), default_variant.get("writes", []))
    guard_cells = _guard_declared_cells(route)
    hash12 = str(profile_sha256)[:12]
    rows = []
    for visit in route.get("visits", []):
        visit_id = str(visit["visit_id"])
        entry_state = [
            cell for cell in visit.get("entry_state", [])
            if (cell["storage"], int(cell["bank"]), int(cell["index"])) not in guard_cells
        ]
        writes = compose_writes(compose_writes(default_writes, entry_state), visit.get("seed_writes", []))
        kind = "tool_seeded_analysis" if visit.get("seed_basis") == "tool_seeded" else "original_branch"
        notes = "analysis-group variant %s@%s/%s/%s" % (group_id, hash12, route_id, visit_id)
        rows.append({
            "preset_id": slugify("%s-%s" % (route_id, visit_id)),
            "label": "visit %s" % visit_id,
            "kind": kind,
            "writes": writes,
            "expected_branch_ids": [],
            "notes": notes,
        })
    return rows


def build_choices(doc: dict, unmatched_report: list, ordered_terminal_ids: list, route_entries: list):
    # Owner ruling (2026-09-20, round 4, rule 2): an option's `terminal_ids`
    # is driven by the routes' own coordinates, not by a terminal-id naming
    # convention (which ties a shared terminal to only one of the routes
    # that reach it - see `miko.town.44m.22.1`, whose result1 and result3
    # routes share one resume the v4 document only names under result1's
    # id). For each boundary that appears in any referenced route's
    # variants, option value v's terminal_ids is the row's own terminal ids
    # at every coordinate (`route.outcome`, and `route.resume.outcome` when
    # present) of every referenced route with a variant whose selections
    # contain (owner, boundary, v).
    any_contracts = False
    candidates: dict = {}
    ambiguous = False
    for group_id, profile_sha256, route_id, route in route_entries:
        if route.get("choice_contracts"):
            any_contracts = True
        route_callee_entry = str(route.get("callee", {}).get("entry", ""))
        owners_by_boundary: dict = {}
        for variant in route.get("variants", []):
            for selection in variant.get("selections", []):
                boundary = int(selection["boundary_offset"])
                # A selection's own owner_entry is authoritative when present
                # (a caller can own a choice over its own callee, e.g. GROUND's
                # outer selection). Some routes record the choice's boundary
                # without repeating the owner on every selection; those
                # boundaries belong to the route's own callee routine.
                owner_entry = _route_selection_owner(route, selection)
                owners_by_boundary.setdefault(boundary, set()).add(owner_entry)
        for contract in route.get("choice_contracts", []):
            boundary = int(contract["boundary_offset"])
            owners = owners_by_boundary.get(boundary)
            if not owners:
                continue
            if len(owners) != 1:
                ambiguous = True
                continue
            owner_entry = next(iter(owners))
            key = (owner_entry, boundary)
            existing = candidates.get(key)
            if existing is not None and existing.get("result_values") != contract.get("result_values"):
                ambiguous = True
                continue
            candidates[key] = contract

    if not any_contracts:
        return []
    if ambiguous or not candidates:
        unmatched_report.append(doc["id"])
        return None

    # (owner_entry, offset) -> the row's own (slugified) terminal ids at it.
    terminal_ids_by_coordinate: dict = {}
    terms = doc["terminals"]
    for raw_terminal_id in ordered_terminal_ids:
        term = terms[raw_terminal_id]
        coordinate = (str(term["owner_entry"]).upper(), int(term["offset"]))
        terminal_ids_by_coordinate.setdefault(coordinate, []).append(slugify(raw_terminal_id))

    choices = []
    for (owner_entry, boundary), contract in sorted(candidates.items(), key=lambda item: item[0][1]):
        options = []
        for index, value in enumerate(contract.get("result_values", [])):
            terminal_ids: list = []
            for group_id, profile_sha256, route_id, route in route_entries:
                if not route_has_selection(route, owner_entry, boundary, int(value)):
                    continue
                for coordinate in route_terminal_coordinates(route):
                    for terminal_id in terminal_ids_by_coordinate.get(coordinate, []):
                        if terminal_id not in terminal_ids:
                            terminal_ids.append(terminal_id)
            options.append({
                "option_id": "option-%d" % int(value),
                "source_row": index,
                "result_value": value,
                "branch_id": "",
                "terminal_ids": terminal_ids,
            })
        choices.append({
            "choice_id": "choice-%d" % boundary,
            "owner_entry": owner_entry,
            "boundary_offset": boundary,
            "result_interface": "routine40_result",
            "evidence_level": "confirmed",
            "options": options,
        })
    return choices


def build_row(doc: dict, by_group: dict, unmatched_choice_report: list, intros: dict | None = None) -> dict:
    # Round 9 code review, item 9: the winning (group, profile) pairs are
    # computed once per document and threaded into every builder that
    # needs them, instead of each recomputing its own copy.
    winners = winning_group_indexes(doc, by_group)
    ordered_terminal_ids = all_terminal_ids(doc)
    route_entries = referenced_route_entries(doc, by_group, winners)
    choices = build_choices(doc, unmatched_choice_report, ordered_terminal_ids, route_entries)
    playback_status, classification = playback_status_and_classification(
        route_entries, choices if choices else [], intros
    )
    row = {
        "event_id": build_event_id(doc),
        "canonical_event_id": "",
        "classification": classification,
        "playback_status": playback_status,
        "display": build_display(doc),
        "source": build_source(doc, by_group, winners),
        "activation": build_activation(doc),
        "presets": build_presets(route_entries) + build_visit_presets(route_entries, choices if choices else []),
        "branches": [],
        "choices": choices if choices else [],
        "resources": catalog_resources(doc),
        "terminals": build_terminals(doc, ordered_terminal_ids, intros),
        "blockers": build_blockers(doc, ordered_terminal_ids, intros),
        "compatibility": {
            "media_replacements": "source_bound_allowed",
            "mes_replacements": "exact_only",
            "mes_interface_id": "",
            "required_control_points": [],
            "remake_extensions": [],
        },
        "verification": {
            "automated": [{
                "kind": "headless_validator",
                "path": "res://tools/content_suite/validators/validate_event_analysis_group.gd",
                "scope": ["route", "variants", "reentry"],
            }],
            "manual": [],
            "expected_absent_entries": [],
            "notes": "analysis group %s; definition %s" % (
                ", ".join(str(group["group_id"]) for group in doc["evidence"]["groups"]), doc["id"],
            ),
        },
        "analysis_group": {
            "definition_id": doc["id"],
            "groups": [
                {
                    "group_id": group["group_id"],
                    "profile_sha256": group["profile_sha256"],
                    "route_ids": list(group.get("route_ids", [])),
                }
                for group in doc["evidence"]["groups"]
            ],
        },
    }
    assert_unique_ids(doc["id"], row)
    return row


def assert_unique_ids(definition_id: str, row: dict) -> None:
    """Owner ruling (2026-09-20, round 7): a collision must fail the
    generator, not the catalog load - check preset, terminal and (per
    choice) option ids before the row is ever written."""
    preset_ids = [preset["preset_id"] for preset in row["presets"]]
    if len(preset_ids) != len(set(preset_ids)):
        dupes = sorted({value for value in preset_ids if preset_ids.count(value) > 1})
        raise SystemExit("%s (%s): duplicate preset ids: %s" % (definition_id, row["event_id"], ", ".join(dupes)))
    terminal_ids = [terminal["terminal_id"] for terminal in row["terminals"]]
    if len(terminal_ids) != len(set(terminal_ids)):
        dupes = sorted({value for value in terminal_ids if terminal_ids.count(value) > 1})
        raise SystemExit("%s (%s): duplicate terminal ids: %s" % (definition_id, row["event_id"], ", ".join(dupes)))
    for choice in row.get("choices") or []:
        option_ids = [option["option_id"] for option in choice["options"]]
        if len(option_ids) != len(set(option_ids)):
            dupes = sorted({value for value in option_ids if option_ids.count(value) > 1})
            raise SystemExit(
                "%s (%s): duplicate option ids in %s: %s"
                % (definition_id, row["event_id"], choice["choice_id"], ", ".join(dupes))
            )


# EP-12 catalog part (2026-09-24): the same "command 15 dispatches, 14 hands
# off" invariant `build_event_names.py` uses (content_core/mes_event_runner.gd's
# own command 0x0F/0x0E handling; confirmed directly against the real archive
# for 01M.MES's dispatch at 11148) - a v14 hop's own outcome record carries
# no `command` field of its own.
FLOW_DISPATCH_COMMAND_BY_STATUS = {"script_dispatch_boundary": 15, "script_handoff_boundary": 14}


def find_registry_row(registry: dict, group_id: str, route_id: str) -> dict | None:
    for row in registry.get("rows", {}).values():
        for group in row.get("aliases", {}).get("groups", []):
            if group.get("group_id") == group_id and route_id in group.get("route_ids", []):
                return row
    return None


def build_flow_event_id(route: dict) -> str:
    origin = route["origin"]
    caller_stem = stem_of(origin["entry"])
    offset_hex = hex8(origin["offset"])
    return "original/%s/%s-%s" % (route["route_id"], caller_stem, offset_hex)


def build_flow_display(registry_row: dict) -> dict:
    heroine = str(registry_row.get("heroine") or "")
    character_ids = [heroine] if heroine and heroine != "common" else []
    # The registry's own `number` rule extension already spells out
    # "date-<tail>"; `categories` keeps the fixed "date" tag the
    # generator's own `scene_kinds` (e.g. "train_ride" for TRAIN.MES) add to,
    # "gallery" for an album scene, `conversation` plus the registry category for a
    # TALK row (EP-12 TALK, `<name>.town.station.talk-30.1`), and - EP-12 H
    # (2026-10-04) - the ordinary site row's own pair, `character_event` and the
    # registry category, for a flow that is none of those (the 13 recollection
    # ladders of the room, `<name>.town.43c.h.1`).
    scene_kinds = list(registry_row.get("scene_kinds", []))
    if is_gallery_registry_row(registry_row):
        return {"title": registry_row.get("title_en", ""), "character_ids": character_ids,
                "categories": [GALLERY_CATEGORY] + scene_kinds}
    if str(registry_row.get("number", "")).startswith("date-"):
        return {"title": registry_row.get("title_en", ""), "character_ids": character_ids,
                "categories": ["date"] + scene_kinds}
    if is_talk_registry_row(registry_row):
        # EP-12 TALK (2026-10-04): a heroine's conversation script at its confirmed
        # caller (`<name>.town.station.talk-30.1`) is a `conversation` row; the
        # registry category (`town`) follows as for an ordinary site row.
        return {"title": registry_row.get("title_en", ""), "character_ids": character_ids,
                "categories": ["conversation", str(registry_row.get("category", ""))] + scene_kinds}
    return {"title": registry_row.get("title_en", ""), "character_ids": character_ids,
            "categories": ["character_event", str(registry_row.get("category", ""))] + scene_kinds}


def build_flow_source(profile: dict, route: dict) -> dict:
    hop0 = route["hops"][0]
    outcome = hop0["expected"]["outcome"]
    caller_entry = route["origin"]["entry"]
    callee_entry = outcome["target"]
    status = str(outcome["status"])
    if status not in FLOW_DISPATCH_COMMAND_BY_STATUS:
        raise SystemExit("flow route %s: unsupported hop0 outcome status %s" % (route["route_id"], status))
    command = FLOW_DISPATCH_COMMAND_BY_STATUS[status]
    members_by_entry = {member["entry"]: member["entry_sha256"] for member in profile["source_members"]}
    return {
        "caller": {
            "archive": "mes.arc", "entry": caller_entry, "entry_sha256": members_by_entry[caller_entry],
            "dispatch_offset": outcome["offset"], "resume_offset": outcome["end"], "command": command,
        },
        "callee": {
            "archive": "mes.arc", "entry": callee_entry, "entry_sha256": members_by_entry[callee_entry],
            "start_coordinate": 0, "address_index": -1,
        },
        # Owner spec (EP-12 catalog part): every `source_members` entry, not
        # the caller/callee-excluded union the v4 path uses - a flow's own
        # members list is already exactly what every hop needs.
        "required_entries": [
            {"archive": "mes.arc", "entry": member["entry"], "entry_sha256": member["entry_sha256"], "role": "analysis_group_member"}
            for member in profile["source_members"]
        ],
    }


def build_flow_activation(route: dict) -> dict:
    origin = route["origin"]
    return {
        "kind": "nested_zero_start",
        "evidence_level": "confirmed",
        "evidence_types": ["authoritative_arc", "headless_replay"],
        "document_refs": [],
        "notes": "origin typed_guard at %s:%s; the run starts there" % (origin["entry"], origin["offset"]),
    }


def build_flow_presets(group_id: str, profile_sha256: str, route: dict) -> list:
    """One preset per variant of the route: the baseline, the variant's own
    `writes` and every hop's tool-seeded gate writes. A variant that only
    answers another option of a scene's question (EP-12, 2026-10-04) is a
    preset with no writes of its own - the option it measures is bound by
    `build_flow_choices` and resolved from the variant's `answers` - and a
    recap scene's second path is a preset carrying its cell writes."""
    hash12 = str(profile_sha256)[:12]
    baseline_writes = route.get("baseline", [])
    gate_writes = [
        {"storage": gate["storage"], "bank": gate.get("bank", 0), "index": gate["index"], "value": gate["value"]}
        for hop in route["hops"]
        for gate in hop.get("gates", [])
        if gate.get("basis") == "tool_seeded"
    ]
    rows = []
    for variant in route.get("variants", []):
        variant_id = str(variant["variant_id"])
        writes = compose_writes(compose_writes(baseline_writes, variant.get("writes", [])), gate_writes)
        rows.append({
            "preset_id": slugify("%s/%s" % (route["route_id"], variant_id)),
            "label": variant_id,
            "kind": "original_branch",
            "writes": writes,
            "expected_branch_ids": [],
            "notes": "analysis-group variant %s@%s/%s/%s" % (group_id, hash12, route["route_id"], variant_id),
        })
    return rows


def build_flow_choices(route: dict, terminal_id: str) -> list:
    """One choice per question a hop answers - owner is the hop's own entry.
    Its options are the answers the route measures: the hop's own
    `result_value` first (the default variant's, so the default option and the
    default preset stay what they were), then every other value a variant's
    `answers` gives that hop at that boundary (EP-12, 2026-10-04, additive to
    v14: a scene question's other options are variants of the row, each the
    preset of the variant that answers it), in the variants' own order. Every
    option leads to the row's own one terminal (the flow's own completed,
    measured chain - a variant ends at the route's `terminal`, the stop rule
    of `docs/spec/tech/content_tools.md`). `source_row` is the option's
    position among the choice's measured options (0 for the single answer
    every flow row had before variants). A route whose variants carry no
    `answers` yields exactly the choices it always did."""
    choices = []
    variants = route.get("variants", [])
    for hop in route["hops"]:
        owner_entry = str(hop["entry"])
        values_by_boundary: dict = {}
        for answer in hop.get("answers", []):
            values_by_boundary.setdefault(int(answer["boundary_offset"]), []).append(int(answer["result_value"]))
        for variant in variants:
            for answer in variant.get("answers", []):
                if str(answer["hop_id"]) != str(hop["hop_id"]):
                    continue
                values = values_by_boundary.setdefault(int(answer["boundary_offset"]), [])
                if int(answer["result_value"]) not in values:
                    values.append(int(answer["result_value"]))
        for boundary, values in values_by_boundary.items():
            choices.append({
                "choice_id": "choice-%s-%d" % (slugify(owner_entry), boundary),
                "owner_entry": owner_entry,
                "boundary_offset": boundary,
                "result_interface": "routine40_result",
                "evidence_level": "confirmed",
                "options": [{
                    "option_id": "option-%d" % value,
                    "source_row": position,
                    "result_value": value,
                    "branch_id": "",
                    "terminal_ids": [terminal_id],
                } for position, value in enumerate(values)],
            })
    return choices


def build_flow_return_terminals(route: dict) -> list:
    """A flow whose last hop is a nested-called scene ending in its own
    `script_return` (an album scene, EP-12 gallery, owner ruling 2026-10-04) -
    the same pair of terminals a returning callee whose caller resumes into
    its own input loop already has (`TERMINAL_KIND_MAP` `callee_return` then
    `caller_menu_loop`):

    - terminal 0, `callee_return_only` (`script_return`, sequence 10): the
      scene's own closing record, the one a flow run observes (the choice
      options and the terminal match bind to it);
    - terminal 1, `analysis_boundary`/`loop_boundary` (sequence 30): the
      origin menu resuming after the scene and running into its next
      selection - a measured fact of the study, not run by the flow. Tool
      decision: its coordinate is the origin's own resume point (the first
      hop's dispatch record end), which a flow run never observes; its only
      effect is that the row's route outcome is `place_menu`."""
    terminal = route["terminal"]
    origin_resume = route["hops"][0]["expected"]["outcome"]["end"]
    route_slug = route["route_id"]
    rows = []
    for key, owner, offset, resume, suffix in (
        ("callee_return", terminal["entry"], terminal["offset"], terminal["end"], "outcome"),
        ("caller_menu_loop", route["origin"]["entry"], origin_resume, origin_resume, "resume"),
    ):
        catalog_kind, outcome, runtime_status, sequence = TERMINAL_KIND_MAP[key]
        rows.append({
            "terminal_id": slugify("%s-%s" % (route_slug, suffix)),
            "kind": catalog_kind,
            "sequence": sequence,
            "outcome": outcome,
            "runtime_status": runtime_status,
            "owner_entry": owner,
            "offset": offset,
            "required_state": [],
            "caller_resume_offset": resume,
            "next_target": "",
            "evidence_level": "confirmed",
        })
    return rows


def build_flow_terminals(route: dict) -> list:
    terminal = route["terminal"]
    if str(terminal.get("status", "")) == "script_return":
        return build_flow_return_terminals(route)
    catalog_kind, outcome, runtime_status, _sequence = TERMINAL_KIND_MAP["root_handoff"]
    return [{
        "terminal_id": slugify("%s-outcome" % route["route_id"]),
        "kind": catalog_kind,
        "sequence": 0,
        "outcome": outcome,
        "runtime_status": runtime_status,
        "owner_entry": terminal["entry"],
        "offset": terminal["offset"],
        "required_state": [],
        "caller_resume_offset": terminal["end"],
        "next_target": terminal["target"],
        "evidence_level": "confirmed",
    }]


def build_flow_row(group_id: str, profile: dict, route: dict, registry: dict, flow_documents: dict) -> dict:
    """A v14 flow route's own promoted row - a function of its own, not `if`
    arms inside the v4 `build_row` path (EP-12 catalog part): the shape
    (event_id, source, terminals, ...) it needs has no v4 document, no
    per-route caller/callee pair, and no `outcome`/`resume` coordinates to
    read `route_terminal_coordinates` from."""
    route_id = route["route_id"]
    registry_row = find_registry_row(registry, group_id, route_id)
    if registry_row is None:
        raise SystemExit("flow route %s/%s has no registry row; regenerate config/contracts/event_names_v1 first" % (group_id, route_id))
    flow_document = flow_documents.get(registry_row["id"])
    if flow_document is None:
        raise SystemExit("flow route %s/%s has no flow document %s in the definitions directory" % (group_id, route_id, registry_row["id"]))
    terminals = build_flow_terminals(route)
    terminal_id = terminals[0]["terminal_id"]
    outcome = flow_route_outcome(route)["outcome"]
    if outcome in ("map_return", "place_menu", "chain"):
        playback_status, classification = "minimal_playback", "playable_event"
    else:
        playback_status, classification = "analysis_only", "unresolved_route"
    row = {
        "event_id": build_flow_event_id(route),
        "canonical_event_id": "",
        "classification": classification,
        "playback_status": playback_status,
        "display": build_flow_display(registry_row),
        "source": build_flow_source(profile, route),
        "activation": build_flow_activation(route),
        "presets": build_flow_presets(group_id, profile["payload_sha256"], route),
        "branches": [],
        "choices": build_flow_choices(route, terminal_id),
        "resources": catalog_resources(flow_document),
        "terminals": terminals,
        "blockers": [{
            "blocker_id": "bounded-native-presentation",
            "class": "native_presentation",
            "offset": 0,
            "blocks_playback": False,
            "summary": "Analysis omits native presentation: music, images, cadence and the host are not played.",
            "todo_id": "EP-10",
            "document_refs": [],
        }],
        "compatibility": {
            "media_replacements": "source_bound_allowed",
            "mes_replacements": "exact_only",
            "mes_interface_id": "",
            "required_control_points": [],
            "remake_extensions": [],
        },
        "verification": {
            "automated": [{
                "kind": "headless_validator",
                "path": "res://tools/content_suite/validators/validate_event_analysis_group.gd",
                "scope": ["route", "hops", "terminal"],
            }],
            "manual": [],
            "expected_absent_entries": [],
            "notes": "analysis group %s; definition %s" % (group_id, registry_row["id"]),
        },
        "analysis_group": {
            "definition_id": registry_row["id"],
            "groups": [{"group_id": group_id, "profile_sha256": profile["payload_sha256"], "route_ids": [route_id]}],
        },
    }
    assert_unique_ids(registry_row["id"], row)
    return row


def generate_flow_rows(by_group: dict, registry: dict, flow_documents: dict) -> list:
    rows = []
    for group_id, profiles in by_group.items():
        for profile in profiles:
            if str(profile.get("schema", "")) != FLOW_SCHEMA:
                continue
            for route in profile.get("routes", []):
                rows.append(build_flow_row(group_id, profile, route, registry, flow_documents))
    return rows


def resolve_duplicate_routes(rows: list, duplicates: dict) -> list:
    """EP-12 gallery `duplicate_route` rule (tool decision, owner ruling
    2026-10-04): a gallery scene whose callee is message-identical (the
    `audit_duplicate_entries.py` census: byte-identical message records) to a
    callee that already has an ordinary row becomes a `duplicate_route` of
    that row - `classification` and `canonical_event_id` change, nothing else:
    the scene stays its own playable route.

    - A `gallery_copy_of_event` group: every `gallery_members` scene is a copy
      of the group's `source` EVENT callee. The canonical row is that
      callee's one row; a callee with several rows is ambiguous (stop), one
      with none leaves the copy an ordinary row.
    - A `gallery_internal` group (scenes only): the member whose entry name
      sorts first is canonical, the others are its copies (the four pairs are
      H/K: the H scene is canonical).
    - A `gallery_copy_of_other` group (a scene copy of an `?_END` script) is
      not a duplicate here: the ending has no row, so the scene is an ordinary
      row. Any other group kind is not a gallery relation and is ignored.

    A copy is only reclassified when it has a row of its own, and a canonical
    row is never itself a duplicate. Returns one report entry per rule
    application, in the groups' own order."""
    by_callee: dict = {}
    for row in rows:
        by_callee.setdefault(str(row["source"]["callee"]["entry"]).upper(), []).append(row)
    report = []
    for group in duplicates.get("groups", []):
        kind = str(group.get("kind", ""))
        if kind == "gallery_copy_of_event":
            canonical_entry, copies = str(group["source"]).upper(), [str(e).upper() for e in group["gallery_members"]]
        elif kind == "gallery_internal":
            ordered = sorted(str(e).upper() for e in group["entries"])
            canonical_entry, copies = ordered[0], ordered[1:]
        else:
            continue
        canonical_rows = [row for row in by_callee.get(canonical_entry, []) if row["classification"] != "duplicate_route"]
        if len(canonical_rows) > 1:
            raise SystemExit("ambiguous duplicate_route canonical: %s has %d rows (%s)" % (
                canonical_entry, len(canonical_rows), ", ".join(sorted(row["event_id"] for row in canonical_rows))))
        for copy_entry in copies:
            copy_rows = by_callee.get(copy_entry, [])
            if not copy_rows or not canonical_rows:
                continue
            if len(copy_rows) > 1:
                raise SystemExit("ambiguous duplicate_route copy: %s has %d rows" % (copy_entry, len(copy_rows)))
            copy_row, canonical_row = copy_rows[0], canonical_rows[0]
            copy_row["classification"] = "duplicate_route"
            copy_row["canonical_event_id"] = canonical_row["event_id"]
            report.append({"event_id": copy_row["event_id"], "canonical_event_id": canonical_row["event_id"],
                           "callee": copy_entry, "canonical_callee": canonical_entry, "group_kind": kind})
    return report


def generate(catalog_path: Path, v4_dir: Path, profiles_dir: Path, registry_path: Path | None = None,
             duplicates_path: Path | None = None):
    catalog = load_json(catalog_path)

    by_group = load_profiles(profiles_dir)
    documents, flow_documents = load_definition_documents(v4_dir)
    intros = event_intro_index(documents)
    registry = load_json(registry_path or (ROOT / DEFAULT_REGISTRY))

    unmatched_choice_report: list = []
    generated_rows = []
    for doc in documents:
        generated_rows.append(build_row(doc, by_group, unmatched_choice_report, intros))
    flow_rows = generate_flow_rows(by_group, registry, flow_documents)
    generated_rows.extend(flow_rows)
    # Every flow document of the definitions directory must have been promoted
    # (the ids line up one for one), or the set and the profiles disagree.
    promoted_flow_ids = {row["analysis_group"]["definition_id"] for row in flow_rows}
    if promoted_flow_ids != set(flow_documents):
        stray = sorted(set(flow_documents) - promoted_flow_ids)
        raise SystemExit("%d flow document(s) of the definitions directory are not promoted: %s" % (len(stray), ", ".join(stray[:5])))

    generated_rows.sort(key=lambda row: row["event_id"])
    duplicates = load_json(duplicates_path or (ROOT / DEFAULT_DUPLICATES))
    duplicate_report = resolve_duplicate_routes(generated_rows, duplicates)

    seen_ids = set()
    for row in generated_rows:
        if row["event_id"] in seen_ids:
            raise SystemExit("duplicate event_id across the catalog: %s" % row["event_id"])
        seen_ids.add(row["event_id"])

    new_catalog = dict(catalog)
    new_catalog["catalog_revision"] = CATALOG_REVISION
    new_catalog["events"] = generated_rows

    report = {
        "hand_rows": 0,
        "documents": len(documents),
        "skipped": 0,
        "generated": len(generated_rows),
        "duplicate_routes": duplicate_report,
        "unmatched_choice_documents": unmatched_choice_report,
    }
    return new_catalog, report


def serialize(catalog: dict) -> bytes:
    text = json.dumps(catalog, indent=2, ensure_ascii=False) + "\n"
    return text.encode("utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--catalog", default=DEFAULT_CATALOG)
    parser.add_argument("--definitions-dir", "--v4-dir", dest="definitions_dir", default=DEFAULT_DEFINITIONS_DIR)
    parser.add_argument("--profiles-dir", default=DEFAULT_PROFILES_DIR)
    parser.add_argument("--registry", default=DEFAULT_REGISTRY)
    parser.add_argument("--duplicates", default=DEFAULT_DUPLICATES)
    parser.add_argument("--out", default=None)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()

    catalog_path = Path(args.catalog)
    out_path = Path(args.out) if args.out else catalog_path

    new_catalog, report = generate(catalog_path, Path(args.definitions_dir), Path(args.profiles_dir), Path(args.registry),
                                   Path(args.duplicates))
    serialized = serialize(new_catalog)

    print(
        "hand_rows=%d documents=%d skipped=%d generated=%d duplicate_routes=%d unmatched_choices=%d"
        % (
            report["hand_rows"], report["documents"], report["skipped"], report["generated"],
            len(report["duplicate_routes"]), len(report["unmatched_choice_documents"]),
        )
    )
    if report["unmatched_choice_documents"]:
        print("documents whose choices could not be matched to exactly one contract: %s" % ", ".join(report["unmatched_choice_documents"]))

    if args.check:
        if not catalog_path.is_file():
            print("CHECK FAILED: %s does not exist" % catalog_path)
            return 1
        with open(catalog_path, "rb") as fh:
            current = fh.read()
        if current == serialized:
            print("CHECK OK: regenerated catalog equals %s byte for byte" % catalog_path)
            return 0
        print(
            "CHECK FAILED: regenerated catalog differs from %s (current %d bytes, sha256 %s; "
            "regenerated %d bytes, sha256 %s)"
            % (
                catalog_path, len(current), hashlib.sha256(current).hexdigest(),
                len(serialized), hashlib.sha256(serialized).hexdigest(),
            )
        )
        return 1

    out_path.parent.mkdir(parents=True, exist_ok=True)
    with open(out_path, "wb") as fh:
        fh.write(serialized)
    print("WROTE %s" % out_path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
