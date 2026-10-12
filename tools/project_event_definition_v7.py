"""Projects one event site into a `kakyu_event_definition/v7` document
(WD-21 U2 C4, 2026-10-08). Shares `project_event_definition_v6.py`'s whole
pipeline for the v6 body (schema and `contract_fingerprint` only; the flow
dispatch, the witness rules and the v4/v5 pipeline underneath are v6's own)
and adds exactly the field v7 fills, `presentation.resources`
(`docs/spec/data/event_definition_v7.md`): the media the document's
**measured route** reaches, `{entry, source_offset, kind, name}` items in the
package inventory's vocabulary, sorted by that tuple with no duplicate.

    py tools/project_event_definition_v7.py --site <id> --names <dir> \\
        --profiles-dir <dir> --replays-dir analysis/replays_v3 \\
        --witnesses-dir analysis/witnesses --package <dir> --arc <mes.arc> \\
        --out <dir> [--shared-lines <json>] [--resolved-out <dir>] \\
        [--allow-missing-witnesses]

The v6 command line; `--replays-dir` defaults to `analysis/replays_v3` and must
hold `kakyu_event_analysis_group_replay/v3` files (v2 plus per-run `executed`
and `resource_rows`, `tools/content_suite/replay_run_media.gd`);
`--contract-fingerprint` defaults to
`config/contracts/event_definition_v7/contract_fingerprint`. A `--event`
(catalog-event) projection is refused: a catalog event has no measured replay.

The rule (spec WD-21 U2 D1, D6, D7): the document's resources are the bound
package's classified `media_inventory` occurrences whose record a measured run
executed, unioned over every run (site prefix when reached, callee, resume,
reentry, each visit; each flow hop) of every replayed variant of every route
`evidence.groups[].route_ids` names. Fail closed (exit 1, the written document
removed) when

- a replay is not v3 or not the profile's, a route or a declared variant has no
  replay, or a run that exists has no or an empty `executed` (an unreached
  prefix, `reached: false` with `{}`/`[]`, is not a run);
- an `executed` member is not a package entry, or an `executed` offset is not a
  record start of that member in the package's records (a coordinate-base
  sanity check, R2);
- a joined occurrence has an empty name;
- a `resource_rows` row of a marker effect (`mmo_resource_marker`,
  `ax_resource_marker`, `voice_marker`, `effect_request`) has no occurrence of
  the mapped kind and the same name at its `(entry, at)`, or a `bgm_request`
  row's name is not the name of a `bgm` occurrence joined from the same run.

`EXCLUDED_ENTRIES` (owner ruling of 2026-10-08, TD-56) once held `LIBLARY.LIB`:
the occurrences of the shared library were joined and checked like the others and
then left out of the list, because the measured library ladders all saw selector
0. TD-56 closed that (Core 0.377.0, the runner models command `0x09` and token
`0xF6` as one storage): the constant is now the empty set, the library items are
listed, and a `LIBLARY.LIB` item is checked like any other (it must be a
record start of the library, `PackageMedia.record_starts`). The empty seam is
kept so that an exclusion, should one be ruled again, is one reviewed constant
and the `lib_excluded` status field keeps its shape.

Every projected site prints one `RESOURCES_STATUS` line (items, runs, entry
classes, the excluded library count and the per-kind counts).
"""
from __future__ import annotations

import collections
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import project_event_definition as ped  # noqa: E402
import project_event_definition_v6 as pv6  # noqa: E402
from payload_values import MEDIA_INVENTORY_SCHEMA, MEDIA_KINDS  # noqa: E402

SCHEMA_VERSION = "kakyu_event_definition/v7"
DEFAULT_CONTRACT_FINGERPRINT_PATH = os.path.join(
    "config", "contracts", "event_definition_v7", "contract_fingerprint")
DEFAULT_REPLAYS_DIR = os.path.join("analysis", "replays_v3")
REPLAY_SCHEMA = "kakyu_event_analysis_group_replay/v3"
STATUS_PREFIX = "RESOURCES_STATUS "

LIBRARY_MEMBER = "LIBLARY.LIB"
DEFINITION_MEMBER = "DEF_MAIN.MES"
# TD-56 closed the owner's 2026-10-08 exclusion of the library items (Core 0.377.0): nothing is
# left out any more. The seam stays, empty, so an exclusion is one reviewed constant again.
EXCLUDED_ENTRIES = frozenset()

# The media effects of a run's own entries (`replay_run_media.gd` MEDIA_EFFECTS) and the
# inventory kind each marker effect maps to; `bgm_request` is checked against the run's
# joined `bgm` occurrences instead (the BGM occurrence sits at the slot write, not at the request).
MARKER_EFFECT_KINDS = {
    "mmo_resource_marker": "mmo",
    "ax_resource_marker": "ax",
    "voice_marker": "voice",
    "effect_request": "se",
}
BGM_EFFECT = "bgm_request"


class ResourceError(Exception):
    """The measured route cannot yield a list; the message says why."""


def entry_class(entry):
    if entry == LIBRARY_MEMBER:
        return "lib"
    if entry == DEFINITION_MEMBER:
        return "def"
    return "route"


class PackageMedia:
    """What the projector needs of the bound package: its member entries, its
    `media_inventory` occurrences by `(entry, at)` and the record starts of a member
    (loaded on demand through `load_member_document(entry)`)."""

    def __init__(self, manifest, load_member_document):
        inventory = manifest.get("media_inventory")
        if not isinstance(inventory, dict) or inventory.get("schema") != MEDIA_INVENTORY_SCHEMA:
            raise ResourceError("the package manifest has no %s media_inventory block" % MEDIA_INVENTORY_SCHEMA)
        self.package_sha256 = manifest.get("package_sha256")
        self.entries = {row["entry"] for row in manifest.get("entries", [])}
        self.occurrences = {}
        for row in inventory.get("members", []):
            by_offset = self.occurrences.setdefault(row["entry"], {})
            for occurrence in row["occurrences"]:
                by_offset.setdefault(occurrence["at"], []).append((occurrence["kind"], occurrence["name"]))
        self._load_member_document = load_member_document
        self._record_starts = {}

    @classmethod
    def from_directory(cls, package_dir):
        manifest = ped.load_json(os.path.join(package_dir, "manifest.json"))
        return cls(manifest, lambda entry: ped.load_events_document(package_dir, entry))

    def record_starts(self, member):
        """The `at` of every record of `member` (a library's records are inside its routines)."""
        if member not in self._record_starts:
            document = self._load_member_document(member)
            if document.get("kind") == "library":
                records = [r for routine in document.get("routines", []) for r in routine.get("records", [])]
            else:
                records = document.get("records")
            if not isinstance(records, list) or not records:
                raise ResourceError("package member %s has no records to check executed offsets against" % member)
            self._record_starts[member] = {record["at"] for record in records}
        return self._record_starts[member]


def runs_of(variant, where):
    """`[(role, executed, resource_rows)]` of every run that exists in one replay variant:
    a flow's hops; a site's prefix (only when `reached`), callee, resume, reentry and each
    visit. A run's `executed` must be a non-empty object (R6); an unreached prefix must
    carry the empty fields the writer gives it and is not a run."""
    blocks = []
    if "hops" in variant:
        for index, hop in enumerate(variant["hops"]):
            blocks.append(("hop:%s" % hop.get("hop_id", index), hop, "executed", "resource_rows"))
    else:
        reached = variant.get("reached")
        if not isinstance(reached, bool):
            raise ResourceError("%s: the variant has no boolean `reached`" % where)
        if reached:
            blocks.append(("prefix", variant, "prefix_executed", "prefix_resource_rows"))
        elif variant.get("prefix_executed") or variant.get("prefix_resource_rows"):
            raise ResourceError("%s: an unreached prefix carries executed rows" % where)
        blocks.append(("callee", variant, "executed", "resource_rows"))
        for name in ("resume", "reentry"):
            # Absent (null or missing) is no run; a present object - even an empty one - is a run
            # and must carry its `executed` (R6), so `{}` is refused below, not skipped.
            if variant.get(name) is not None:
                blocks.append((name, variant[name], "executed", "resource_rows"))
        for visit in variant.get("visits") or []:
            blocks.append(("visit:%s" % visit.get("visit_id"), visit, "executed", "resource_rows"))
    runs = []
    for role, block, executed_key, rows_key in blocks:
        if not isinstance(block, dict):
            raise ResourceError("%s: run %s is not an object" % (where, role))
        executed, rows = block.get(executed_key), block.get(rows_key)
        if not isinstance(executed, dict) or not executed:
            raise ResourceError("%s: run %s has no `%s` (a replay v3 run always executes something)" % (where, role, executed_key))
        if not isinstance(rows, list):
            raise ResourceError("%s: run %s has no `%s`" % (where, role, rows_key))
        runs.append((role, executed, rows))
    return runs


def join_run(executed, resource_rows, media, where):
    """The D1 join of one run: the set of `(entry, at, kind, name)` inventory occurrences at
    its executed offsets, after the coordinate checks and the D7 cross-check of its
    `resource_rows`."""
    joined = set()
    for member, offsets in executed.items():
        if member not in media.entries:
            raise ResourceError("%s: executed member %s is not an entry of the package" % (where, member))
        starts = media.record_starts(member)
        by_offset = media.occurrences.get(member, {})
        for at in offsets:
            if not isinstance(at, int) or isinstance(at, bool):
                raise ResourceError("%s: executed offset %r of %s is not an integer" % (where, at, member))
            if at not in starts:
                raise ResourceError("%s: executed offset %d of %s is not a record start" % (where, at, member))
            for kind, name in by_offset.get(at, ()):
                if name == "":
                    raise ResourceError("%s: the %s occurrence at %s:%d has an empty name" % (where, kind, member, at))
                joined.add((member, at, kind, name))
    joined_bgm = {name for (_member, _at, kind, name) in joined if kind == "bgm"}
    for row in resource_rows:
        effect, name = row.get("effect"), row.get("name")
        if effect in MARKER_EFFECT_KINDS:
            wanted = (MARKER_EFFECT_KINDS[effect], name)
            if wanted not in media.occurrences.get(row.get("entry"), {}).get(row.get("at"), ()):
                raise ResourceError("%s: %s row %s:%s %r has no %s occurrence of that name in the inventory" % (
                    where, effect, row.get("entry"), row.get("at"), name, wanted[0]))
        elif effect == BGM_EFFECT:
            if name not in joined_bgm:
                raise ResourceError("%s: bgm_request row %s:%s %r is not the name of a bgm occurrence joined from the same run" % (
                    where, row.get("entry"), row.get("at"), name))
        else:
            raise ResourceError("%s: resource_rows effect %r is not a media effect" % (where, effect))
    return joined


def _load_replay(replays_dir, stem, profile, cache):
    if stem not in cache:
        path = os.path.join(replays_dir, "%s.json" % stem)
        if not os.path.isfile(path):
            raise ResourceError("no replay %s" % path)
        replay = ped.load_json(path)
        if replay.get("schema") != REPLAY_SCHEMA:
            raise ResourceError("replay %s is %r, not %s" % (stem, replay.get("schema"), REPLAY_SCHEMA))
        if replay.get("payload_sha256") != profile.get("payload_sha256") or replay.get("group_id") != profile.get("group_id"):
            raise ResourceError("replay %s is not the profile's (group_id/payload_sha256)" % stem)
        cache[stem] = replay
    return cache[stem]


def resources_for_document(document, profiles, replays_dir, media, excluded_entries=None, replay_cache=None):
    """`{"items": [...], "excluded": [...], "runs": n}` for one projected document: the sorted,
    de-duplicated `presentation.resources` list, the joined occurrences left out by
    `excluded_entries` (default `EXCLUDED_ENTRIES`) and the number of runs joined."""
    excluded_entries = EXCLUDED_ENTRIES if excluded_entries is None else excluded_entries
    replay_cache = {} if replay_cache is None else replay_cache
    union = set()
    runs_total = 0
    groups = (document.get("evidence") or {}).get("groups")
    if not isinstance(groups, list) or not groups:
        raise ResourceError("the document has no evidence.groups (v7 projects analysis-group documents only)")
    for group in groups:
        group_id = group.get("group_id")
        # A group id can be declared by more than one profile (a v5 and a v6 of the same
        # group); the document's `profile_sha256` names the one it was projected from.
        stems = [stem for stem, profile in profiles.items()
                 if profile.get("group_id") == group_id and profile.get("payload_sha256") == group.get("profile_sha256")]
        if len(stems) != 1:
            raise ResourceError("group %r with profile_sha256 %s matches %d profiles" % (
                group_id, group.get("profile_sha256"), len(stems)))
        stem = stems[0]
        profile = profiles[stem]
        replay = _load_replay(replays_dir, stem, profile, replay_cache)
        replay_routes = {route["route_id"]: route for route in replay.get("routes", [])}
        profile_routes = {route["route_id"]: route for route in profile.get("routes", [])}
        route_ids = group.get("route_ids")
        if not isinstance(route_ids, list) or not route_ids:
            raise ResourceError("group %r names no route" % group_id)
        for route_id in route_ids:
            where = "%s/%s" % (stem, route_id)
            if route_id not in replay_routes or route_id not in profile_routes:
                raise ResourceError("%s: the route has no replay" % where)
            replay_variants = replay_routes[route_id].get("variants", [])
            declared = [variant["variant_id"] for variant in profile_routes[route_id].get("variants", [])]
            replayed = {variant["variant_id"] for variant in replay_variants}
            missing = [variant_id for variant_id in declared if variant_id not in replayed]
            if missing:
                raise ResourceError("%s: variants %s have no replay" % (where, missing))
            if not replay_variants:
                raise ResourceError("%s: the route has no replayed variant" % where)
            for variant in replay_variants:
                variant_where = "%s/%s" % (where, variant.get("variant_id"))
                for role, executed, rows in runs_of(variant, variant_where):
                    runs_total += 1
                    union |= join_run(executed, rows, media, "%s %s" % (variant_where, role))
    excluded = sorted(item for item in union if item[0] in excluded_entries)
    items = sorted(item for item in union if item[0] not in excluded_entries)
    return {
        "items": [{"entry": entry, "source_offset": at, "kind": kind, "name": name} for entry, at, kind, name in items],
        "excluded": [{"entry": entry, "source_offset": at, "kind": kind, "name": name} for entry, at, kind, name in excluded],
        "runs": runs_total,
    }


def status_line(site, result):
    kinds = collections.Counter(item["kind"] for item in result["items"])
    classes = collections.Counter(entry_class(item["entry"]) for item in result["items"])
    fields = [
        ("site", site), ("items", len(result["items"])), ("runs", result["runs"]),
        ("route", classes["route"]), ("def", classes["def"]), ("lib_excluded", len(result["excluded"])),
    ] + [(kind, kinds[kind]) for kind in MEDIA_KINDS]
    return STATUS_PREFIX + " ".join("%s=%s" % field for field in fields)


def _write_json(path, document):
    with open(path, "w", encoding="utf-8", newline="\n") as fh:
        json.dump(document, fh, indent=2, ensure_ascii=False, sort_keys=False)
        fh.write("\n")


def inject_resources(doc_id, args, profiles, media):
    """Fills `presentation.resources` of the document v6's pipeline just wrote (and of its
    resolved twin), the way v5's `inject_visits` fills `visits`. Returns the result."""
    tracked_path = os.path.join(args.out, "%s.json" % doc_id)
    document = ped.load_json(tracked_path)
    if document.get("presentation") != {"status": "deferred", "resources": []}:
        raise ResourceError("%s: the v6 pipeline did not leave the empty deferred presentation" % doc_id)
    result = resources_for_document(document, profiles, args.replays_dir, media)
    document["presentation"]["resources"] = result["items"]
    _write_json(tracked_path, document)
    resolved_path = os.path.join(args.resolved_out or args.out, "%s.resolved.json" % doc_id)
    if os.path.isfile(resolved_path):
        resolved = ped.load_json(resolved_path)
        resolved["presentation"] = document["presentation"]
        _write_json(resolved_path, resolved)
    return result


def _discard(doc_id, args):
    for path in (os.path.join(args.out, "%s.json" % doc_id),
                 os.path.join(args.resolved_out or args.out, "%s.resolved.json" % doc_id)):
        if os.path.isfile(path):
            os.remove(path)


def run_site_v7(args):
    previous_schema = pv6.SCHEMA_VERSION
    pv6.SCHEMA_VERSION = SCHEMA_VERSION
    try:
        rc = pv6.run_site_v6(args)
    finally:
        pv6.SCHEMA_VERSION = previous_schema
    if rc != 0:
        return rc
    try:
        media = PackageMedia.from_directory(args.package)
        result = inject_resources(args.site, args, ped.load_profiles(args.profiles_dir), media)
    except ResourceError as exc:
        _discard(args.site, args)
        print("RESOURCES FAILED %s: %s" % (args.site, exc))
        return 1
    print(status_line(args.site, result))
    return 0


def main():
    parser = pv6.build_parser()
    parser.set_defaults(replays_dir=DEFAULT_REPLAYS_DIR, contract_fingerprint=DEFAULT_CONTRACT_FINGERPRINT_PATH)
    args = parser.parse_args()
    if bool(args.event) == bool(args.site):
        print("exactly one of --event or --site is required")
        return 1
    if args.event:
        print("v7 projects analysis-group sites only (--site): a catalog event has no measured replay")
        return 1
    return run_site_v7(args)


if __name__ == "__main__":
    sys.exit(main())
