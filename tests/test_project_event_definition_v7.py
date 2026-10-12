"""WD-21 U2 C4: `tools/project_event_definition_v7.py` - the measured route's resources.

Synthetic profiles, replays and package only: no archive, no original data, no
subprocess. The D1 join, the D6 union, the library items (left out until TD-56 closed
that, 2026-10-10; the exclusion seam stays, empty) and every D7 fail-closed check are
exercised on a small invented world:

- `ROUTE.MES` has records at 10, 20, 30, 40, 50, 60 and the inventory occurrences
  10 mmo `PIC.MMO`; 20 voice `V1.OGG` and voice `V2.OGG` (one record, two names);
  30 bgm `SONG.WAV`; 40 se `BELL.WAV`; 50 ax `ANIM.AX`; 60 unclassified `X.WAV`.
- `OTHER.MES` has records at 5 and 15 and 5 voice `V9.OGG`.
- `LIBLARY.LIB` (a library: records inside routines) has records at 100 and 200 and
  100 mmo `BLACK.MMO`, 200 se `LIBBELL.WAV`; `DEF_MAIN.MES` has records at 7 and 8
  and 7 unclassified `CHARA.DAT`.
"""
from __future__ import annotations

import contextlib
import copy
import io
import json
import sys
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

import project_event_definition_v6 as pv6  # noqa: E402
import project_event_definition_v7 as pv7  # noqa: E402
import validate_event_definition as validator  # noqa: E402

PROFILE_SHA = "a" * 64
STEM = "world_v6"
GROUP = "world"


def occurrence(at, kind, name):
    return {"at": at, "kind": kind, "name": name}


def make_manifest():
    return {
        "schema": "kakyu_playback_package/v7",
        "package_sha256": "b" * 64,
        "entries": [{"entry": name, "entry_sha256": "c" * 64} for name in ("OTHER.MES", "ROUTE.MES", "LIBLARY.LIB", "DEF_MAIN.MES")],
        "media_inventory": {
            "schema": "kakyu_media_inventory/v1",
            "normalization": "upper_case",
            "members": [
                {"entry": "LIBLARY.LIB", "occurrences": [occurrence(100, "mmo", "BLACK.MMO"), occurrence(200, "se", "LIBBELL.WAV")]},
                {"entry": "DEF_MAIN.MES", "occurrences": [occurrence(7, "unclassified", "CHARA.DAT")]},
                {"entry": "OTHER.MES", "occurrences": [occurrence(5, "voice", "V9.OGG")]},
                {"entry": "ROUTE.MES", "occurrences": [
                    occurrence(10, "mmo", "PIC.MMO"), occurrence(20, "voice", "V1.OGG"), occurrence(20, "voice", "V2.OGG"),
                    occurrence(30, "bgm", "SONG.WAV"), occurrence(40, "se", "BELL.WAV"), occurrence(50, "ax", "ANIM.AX"),
                    occurrence(60, "unclassified", "X.WAV"),
                ]},
            ],
        },
    }


MEMBER_DOCUMENTS = {
    "ROUTE.MES": {"records": [{"at": at} for at in (10, 20, 30, 40, 50, 60)]},
    "OTHER.MES": {"records": [{"at": 5}, {"at": 15}]},
    "LIBLARY.LIB": {"kind": "library", "routines": [{"records": [{"at": 100}]}, {"records": [{"at": 200}]}]},
    "DEF_MAIN.MES": {"records": [{"at": 7}, {"at": 8}]},
}


def make_media(manifest=None, documents=None):
    documents = MEMBER_DOCUMENTS if documents is None else documents
    return pv7.PackageMedia(manifest or make_manifest(), lambda entry: documents[entry])


def site_variant(variant_id="v1", **overrides):
    variant = {
        "variant_id": variant_id, "reached": True,
        "prefix_executed": {"OTHER.MES": [5]}, "prefix_resource_rows": [],
        "executed": {"ROUTE.MES": [10, 20]}, "resource_rows": [
            {"entry": "ROUTE.MES", "at": 10, "effect": "mmo_resource_marker", "name": "PIC.MMO"},
            {"entry": "ROUTE.MES", "at": 20, "effect": "voice_marker", "name": "V1.OGG"},
        ],
        "resume": None, "reentry": None, "visits": [],
    }
    variant.update(overrides)
    return variant


def make_profile(variant_ids=("v1",), route_id="r1"):
    return {"group_id": GROUP, "payload_sha256": PROFILE_SHA,
            "routes": [{"route_id": route_id, "variants": [{"variant_id": v} for v in variant_ids]}]}


def make_replay(variants, route_id="r1"):
    return {"schema": pv7.REPLAY_SCHEMA, "group_id": GROUP, "payload_sha256": PROFILE_SHA,
            "routes": [{"route_id": route_id, "variants": variants}]}


def make_document(route_ids=("r1",)):
    return {"evidence": {"groups": [{"group_id": GROUP, "profile_sha256": PROFILE_SHA, "route_ids": list(route_ids)}]},
            "presentation": {"status": "deferred", "resources": []}}


class World:
    """A temp replays directory holding one replay file, plus the profile table."""

    def __init__(self, tmp, replay, profile=None):
        self.directory = Path(tmp)
        (self.directory / ("%s.json" % STEM)).write_text(json.dumps(replay), encoding="utf-8")
        self.profiles = {STEM: profile or make_profile()}

    def resources(self, document=None, media=None, **kwargs):
        return pv7.resources_for_document(document or make_document(), self.profiles, str(self.directory), media or make_media(), **kwargs)


def items_of(result):
    return [(i["entry"], i["source_offset"], i["kind"], i["name"]) for i in result["items"]]


class JoinTests(unittest.TestCase):
    def test_a_route_record_joins_every_occurrence_at_its_offset(self) -> None:
        joined = pv7.join_run({"ROUTE.MES": [10, 20]}, [], make_media(), "run")
        self.assertEqual(joined, {("ROUTE.MES", 10, "mmo", "PIC.MMO"), ("ROUTE.MES", 20, "voice", "V1.OGG"), ("ROUTE.MES", 20, "voice", "V2.OGG")})

    def test_library_and_definition_entries_join_like_route_entries(self) -> None:
        joined = pv7.join_run({"LIBLARY.LIB": [100, 200], "DEF_MAIN.MES": [7, 8]}, [], make_media(), "run")
        self.assertEqual(joined, {("LIBLARY.LIB", 100, "mmo", "BLACK.MMO"), ("LIBLARY.LIB", 200, "se", "LIBBELL.WAV"),
                                  ("DEF_MAIN.MES", 7, "unclassified", "CHARA.DAT")})

    def test_a_record_without_an_occurrence_joins_nothing_and_an_unexecuted_one_is_not_listed(self) -> None:
        self.assertEqual(pv7.join_run({"OTHER.MES": [15]}, [], make_media(), "run"), set())
        self.assertNotIn(("ROUTE.MES", 30, "bgm", "SONG.WAV"), pv7.join_run({"ROUTE.MES": [10]}, [], make_media(), "run"))

    def test_the_marker_effects_and_the_bgm_request_are_cross_checked(self) -> None:
        rows = [
            {"entry": "ROUTE.MES", "at": 10, "effect": "mmo_resource_marker", "name": "PIC.MMO"},
            {"entry": "ROUTE.MES", "at": 20, "effect": "voice_marker", "name": "V2.OGG"},
            {"entry": "ROUTE.MES", "at": 40, "effect": "effect_request", "name": "BELL.WAV"},
            {"entry": "ROUTE.MES", "at": 50, "effect": "ax_resource_marker", "name": "ANIM.AX"},
            {"entry": "ROUTE.MES", "at": 31, "effect": "bgm_request", "name": "SONG.WAV"},
        ]
        joined = pv7.join_run({"ROUTE.MES": [10, 20, 30, 40, 50]}, rows, make_media(), "run")
        self.assertEqual(len(joined), 6)

    def test_the_entry_classes(self) -> None:
        self.assertEqual([pv7.entry_class(e) for e in ("01M.MES", "LIBLARY.LIB", "DEF_MAIN.MES")], ["route", "lib", "def"])


class FailClosedJoinTests(unittest.TestCase):
    def fails(self, executed, rows=(), media=None, text=""):
        with self.assertRaises(pv7.ResourceError) as caught:
            pv7.join_run(executed, list(rows), media or make_media(), "run")
        self.assertIn(text, str(caught.exception))

    def test_an_executed_member_that_is_not_a_package_entry(self) -> None:
        self.fails({"GHOST.MES": [1]}, text="not an entry of the package")

    def test_an_executed_offset_that_is_not_a_record_start(self) -> None:
        self.fails({"ROUTE.MES": [11]}, text="not a record start")
        self.fails({"LIBLARY.LIB": [101]}, text="not a record start")
        self.fails({"DEF_MAIN.MES": [9]}, text="not a record start")

    def test_an_offset_that_is_not_an_integer(self) -> None:
        self.fails({"ROUTE.MES": ["10"]}, text="not an integer")
        self.fails({"ROUTE.MES": [True]}, text="not an integer")

    def test_a_joined_occurrence_with_an_empty_name(self) -> None:
        manifest = make_manifest()
        manifest["media_inventory"]["members"][3]["occurrences"][0]["name"] = ""
        self.fails({"ROUTE.MES": [10]}, media=make_media(manifest), text="empty name")

    def test_a_marker_row_with_no_occurrence_of_the_mapped_kind_and_name(self) -> None:
        for row in (
            {"entry": "ROUTE.MES", "at": 10, "effect": "mmo_resource_marker", "name": "OTHER.MMO"},   # name
            {"entry": "ROUTE.MES", "at": 10, "effect": "ax_resource_marker", "name": "PIC.MMO"},       # kind
            {"entry": "ROUTE.MES", "at": 11, "effect": "mmo_resource_marker", "name": "PIC.MMO"},      # offset
            {"entry": "OTHER.MES", "at": 10, "effect": "mmo_resource_marker", "name": "PIC.MMO"},      # entry
            {"entry": "ROUTE.MES", "at": 40, "effect": "voice_marker", "name": "BELL.WAV"},            # se is not voice
        ):
            self.fails({"ROUTE.MES": [10]}, rows=[row], text="in the inventory")

    def test_a_bgm_request_whose_name_is_not_a_joined_bgm_of_the_same_run(self) -> None:
        row = {"entry": "ROUTE.MES", "at": 31, "effect": "bgm_request", "name": "SONG.WAV"}
        self.fails({"ROUTE.MES": [10]}, rows=[row], text="bgm_request")           # the slot write (30) was not executed
        row["name"] = "OTHER.WAV"
        self.fails({"ROUTE.MES": [30]}, rows=[row], text="bgm_request")           # another name
        self.assertEqual(len(pv7.join_run({"ROUTE.MES": [30]}, [dict(row, name="SONG.WAV")], make_media(), "run")), 1)

    def test_an_effect_that_is_not_a_media_effect(self) -> None:
        self.fails({"ROUTE.MES": [10]}, rows=[{"entry": "ROUTE.MES", "at": 10, "effect": "inline_script_execution_boundary", "name": "X"}],
                   text="not a media effect")


class RunsTests(unittest.TestCase):
    def test_a_site_variant_has_prefix_callee_resume_reentry_and_each_visit(self) -> None:
        extra = {"executed": {"ROUTE.MES": [30]}, "resource_rows": []}
        variant = site_variant(resume=extra, reentry=extra, visits=[dict(extra, visit_id="a"), dict(extra, visit_id="b")])
        self.assertEqual([role for role, _e, _r in pv7.runs_of(variant, "w")],
                         ["prefix", "callee", "resume", "reentry", "visit:a", "visit:b"])

    def test_an_unreached_prefix_is_not_a_run(self) -> None:
        variant = site_variant(reached=False, prefix_executed={}, prefix_resource_rows=[])
        self.assertEqual([role for role, _e, _r in pv7.runs_of(variant, "w")], ["callee"])

    def test_an_unreached_prefix_that_carries_rows_is_refused(self) -> None:
        with self.assertRaisesRegex(pv7.ResourceError, "unreached prefix"):
            pv7.runs_of(site_variant(reached=False), "w")

    def test_a_flow_variant_has_one_run_per_hop(self) -> None:
        hop = {"hop_id": "h1", "executed": {"ROUTE.MES": [10]}, "resource_rows": []}
        variant = {"variant_id": "v", "hops": [hop, dict(hop, hop_id="h2")]}
        self.assertEqual([role for role, _e, _r in pv7.runs_of(variant, "w")], ["hop:h1", "hop:h2"])

    def test_a_run_without_or_with_an_empty_executed_is_refused(self) -> None:
        for change in ({"executed": {}}, {"executed": None}, {"executed": []}):
            with self.assertRaisesRegex(pv7.ResourceError, "no `executed`"):
                pv7.runs_of(site_variant(**change), "w")
        variant = site_variant()
        del variant["executed"]
        with self.assertRaisesRegex(pv7.ResourceError, "no `executed`"):
            pv7.runs_of(variant, "w")
        with self.assertRaisesRegex(pv7.ResourceError, "no `prefix_executed`"):
            pv7.runs_of(site_variant(prefix_executed={}), "w")
        with self.assertRaisesRegex(pv7.ResourceError, "run resume"):
            pv7.runs_of(site_variant(resume={"executed": {}, "resource_rows": []}), "w")
        with self.assertRaisesRegex(pv7.ResourceError, "run visit:a"):
            pv7.runs_of(site_variant(visits=[{"visit_id": "a", "resource_rows": []}]), "w")
        with self.assertRaisesRegex(pv7.ResourceError, "run hop:h1"):
            pv7.runs_of({"hops": [{"hop_id": "h1", "executed": {}, "resource_rows": []}]}, "w")

    def test_a_present_but_empty_resume_or_reentry_is_a_run_without_executed_not_an_absent_one(self) -> None:
        # `{}` is a present run object (a writer that emitted a run and nothing in it), not the
        # absent `null`: it must fail the R6 refusal rather than be skipped silently.
        for name in ("resume", "reentry"):
            with self.assertRaisesRegex(pv7.ResourceError, "run %s has no `executed`" % name):
                pv7.runs_of(site_variant(**{name: {}}), "w")
            with self.assertRaisesRegex(pv7.ResourceError, "run %s is not an object" % name):
                pv7.runs_of(site_variant(**{name: False}), "w")
            with self.assertRaisesRegex(pv7.ResourceError, "run %s is not an object" % name):
                pv7.runs_of(site_variant(**{name: []}), "w")
            self.assertEqual([role for role, _e, _r in pv7.runs_of(site_variant(**{name: None}), "w")], ["prefix", "callee"])
        # a variant with no `resume`/`reentry` key at all (a v3 writer's absent run) is not a run either
        variant = site_variant()
        del variant["resume"], variant["reentry"]
        self.assertEqual([role for role, _e, _r in pv7.runs_of(variant, "w")], ["prefix", "callee"])

    def test_a_run_without_resource_rows_is_refused(self) -> None:
        variant = site_variant()
        del variant["resource_rows"]
        with self.assertRaisesRegex(pv7.ResourceError, "no `resource_rows`"):
            pv7.runs_of(variant, "w")

    def test_a_variant_without_a_boolean_reached(self) -> None:
        variant = site_variant()
        del variant["reached"]
        with self.assertRaisesRegex(pv7.ResourceError, "reached"):
            pv7.runs_of(variant, "w")


class DocumentTests(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)

    def world(self, variants, profile=None, replay_overrides=None):
        replay = make_replay(variants)
        replay.update(replay_overrides or {})
        return World(self._tmp.name, replay, profile)

    def test_the_union_over_variants_and_runs_is_sorted_and_de_duplicated(self) -> None:
        resume = {"executed": {"ROUTE.MES": [30, 10]}, "resource_rows": []}
        visit = {"visit_id": "a", "executed": {"OTHER.MES": [5], "ROUTE.MES": [20]}, "resource_rows": []}
        world = self.world([
            site_variant("v1"),
            site_variant("v2", executed={"ROUTE.MES": [60]}, resource_rows=[], resume=resume, visits=[visit]),
        ], make_profile(("v1", "v2")))
        result = world.resources()
        self.assertEqual(items_of(result), [
            ("OTHER.MES", 5, "voice", "V9.OGG"),
            ("ROUTE.MES", 10, "mmo", "PIC.MMO"),
            ("ROUTE.MES", 20, "voice", "V1.OGG"),
            ("ROUTE.MES", 20, "voice", "V2.OGG"),
            ("ROUTE.MES", 30, "bgm", "SONG.WAV"),
            ("ROUTE.MES", 60, "unclassified", "X.WAV"),
        ])
        self.assertEqual(result["runs"], 6)   # v1: prefix, callee; v2: prefix, callee, resume, one visit

    def test_a_flow_unions_its_hops(self) -> None:
        variant = {"variant_id": "v1", "hops": [
            {"hop_id": "h1", "executed": {"ROUTE.MES": [10]}, "resource_rows": []},
            {"hop_id": "h2", "executed": {"OTHER.MES": [5], "ROUTE.MES": [50]}, "resource_rows": []},
        ]}
        result = self.world([variant]).resources()
        self.assertEqual(items_of(result), [("OTHER.MES", 5, "voice", "V9.OGG"), ("ROUTE.MES", 10, "mmo", "PIC.MMO"), ("ROUTE.MES", 50, "ax", "ANIM.AX")])

    def test_the_unreached_prefix_contributes_nothing(self) -> None:
        reached = self.world([site_variant()]).resources()
        self.assertIn(("OTHER.MES", 5, "voice", "V9.OGG"), items_of(reached))
        unreached = self.world([site_variant(reached=False, prefix_executed={}, prefix_resource_rows=[])]).resources()
        self.assertNotIn(("OTHER.MES", 5, "voice", "V9.OGG"), items_of(unreached))

    def test_library_occurrences_are_joined_and_listed(self) -> None:
        """TD-56 (2026-10-10) closed the 2026-10-08 exclusion: the library ladders now select by the
        caller's real selector, so `LIBLARY.LIB` items are listed like any other occurrence."""
        variant = site_variant(executed={"ROUTE.MES": [10], "LIBLARY.LIB": [100, 200], "DEF_MAIN.MES": [7]})
        result = self.world([variant]).resources()
        self.assertEqual(pv7.EXCLUDED_ENTRIES, frozenset())
        self.assertEqual([i[0] for i in items_of(result)], ["DEF_MAIN.MES", "LIBLARY.LIB", "LIBLARY.LIB", "OTHER.MES", "ROUTE.MES"])
        self.assertEqual([i for i in items_of(result) if i[0] == "LIBLARY.LIB"],
                         [("LIBLARY.LIB", 100, "mmo", "BLACK.MMO"), ("LIBLARY.LIB", 200, "se", "LIBBELL.WAV")])
        self.assertEqual(result["excluded"], [])

    def test_the_exclusion_seam_is_one_constant(self) -> None:
        """The mechanism is kept, empty: ruling an exclusion again is one reviewed constant."""
        variant = site_variant(executed={"ROUTE.MES": [10], "LIBLARY.LIB": [100, 200]})
        world = self.world([variant])
        with mock.patch.object(pv7, "EXCLUDED_ENTRIES", frozenset({"LIBLARY.LIB"})):
            left_out = world.resources()
        self.assertEqual([i[0] for i in items_of(left_out)], ["OTHER.MES", "ROUTE.MES"])
        self.assertEqual([(i["entry"], i["source_offset"]) for i in left_out["excluded"]], [("LIBLARY.LIB", 100), ("LIBLARY.LIB", 200)])

    def test_a_library_offset_must_be_a_library_record_start(self) -> None:
        world = self.world([site_variant(executed={"ROUTE.MES": [10], "LIBLARY.LIB": [101]})])
        with self.assertRaisesRegex(pv7.ResourceError, "not a record start"):
            world.resources()

    def test_the_list_satisfies_the_v7_contract_against_the_package(self) -> None:
        variant = site_variant(executed={"ROUTE.MES": [10, 20, 30, 40, 50, 60], "DEF_MAIN.MES": [7]})
        result = self.world([variant]).resources()
        validator._check_presentation_v7({"status": "deferred", "resources": result["items"]}, "presentation", {"__manifest__": make_manifest()})
        # And the library items are valid v7 items too (the contract keeps LIBLARY.LIB an entry).
        library = [dict(entry="LIBLARY.LIB", source_offset=100, kind="mmo", name="BLACK.MMO")]
        validator._check_presentation_v7({"status": "deferred", "resources": library}, "presentation", {"__manifest__": make_manifest()})

    def test_an_empty_list_is_a_result_not_an_error(self) -> None:
        manifest = make_manifest()
        manifest["media_inventory"]["members"] = []
        result = self.world([site_variant(resource_rows=[])]).resources(media=make_media(manifest))
        self.assertEqual(result, {"items": [], "excluded": [], "runs": 2})

    def fails(self, world, text, **kwargs):
        with self.assertRaises(pv7.ResourceError) as caught:
            world.resources(**kwargs)
        self.assertIn(text, str(caught.exception))

    def test_a_replay_that_is_not_v3_or_not_the_profiles(self) -> None:
        self.fails(self.world([site_variant()], replay_overrides={"schema": "kakyu_event_analysis_group_replay/v2"}), "not kakyu_event_analysis_group_replay/v3")
        self.fails(self.world([site_variant()], replay_overrides={"payload_sha256": "d" * 64}), "not the profile's")
        self.fails(self.world([site_variant()], replay_overrides={"group_id": "other"}), "not the profile's")

    def test_a_missing_replay_file_route_or_variant(self) -> None:
        world = self.world([site_variant()])
        (world.directory / ("%s.json" % STEM)).unlink()
        self.fails(world, "no replay")
        self.fails(self.world([site_variant()]), "has no replay", document=make_document(("r1", "r2")))
        self.fails(self.world([site_variant("v1")], make_profile(("v1", "v2"))), "variants ['v2'] have no replay")
        self.fails(self.world([], make_profile(())), "no replayed variant")

    def test_a_document_bound_to_another_profile_or_without_groups(self) -> None:
        document = make_document()
        document["evidence"]["groups"][0]["profile_sha256"] = "e" * 64
        self.fails(self.world([site_variant()]), "matches 0 profiles", document=document)
        self.fails(self.world([site_variant()]), "no evidence.groups", document={"evidence": {"kind": "catalog_event"}})
        document = make_document()
        document["evidence"]["groups"][0]["route_ids"] = []
        self.fails(self.world([site_variant()]), "names no route", document=document)

    def test_two_profiles_of_one_group_are_told_apart_by_the_payload_hash(self) -> None:
        world = self.world([site_variant()])
        world.profiles["world_v5"] = dict(make_profile(), payload_sha256="f" * 64)
        self.assertTrue(world.resources()["items"])
        world.profiles["world_v5"] = make_profile()   # the same hash twice is ambiguous
        self.fails(world, "matches 2 profiles")

    def test_a_run_that_fails_names_its_route_variant_and_role(self) -> None:
        world = self.world([site_variant("v1", executed={})], make_profile())
        with self.assertRaisesRegex(pv7.ResourceError, r"world_v6/r1/v1.*run callee"):
            world.resources()


class WrapperTests(unittest.TestCase):
    """`run_site_v7`: v6's pipeline under the v7 schema, then the resources injected."""

    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        root = Path(self._tmp.name)
        self.out, self.resolved = root / "out", root / "resolved"
        self.out.mkdir()
        self.resolved.mkdir()
        self.replays = root / "replays"
        self.replays.mkdir()
        self.profiles_dir = root / "profiles"
        self.profiles_dir.mkdir()
        (self.profiles_dir / ("%s.json" % STEM)).write_text(json.dumps(make_profile()), encoding="utf-8")
        (self.replays / ("%s.json" % STEM)).write_text(json.dumps(make_replay([site_variant(executed={"ROUTE.MES": [10], "LIBLARY.LIB": [100]})])), encoding="utf-8")
        self.package = root / "package"
        (self.package / "events").mkdir(parents=True)
        (self.package / "manifest.json").write_text(json.dumps(make_manifest()), encoding="utf-8")
        for entry, document in MEMBER_DOCUMENTS.items():
            stem = entry.rsplit(".", 1)[0]
            (self.package / "events" / ("%s.json" % stem)).write_text(json.dumps(document), encoding="utf-8")
        self.args = SimpleNamespace(site="world.1", out=str(self.out), resolved_out=str(self.resolved),
                                    replays_dir=str(self.replays), profiles_dir=str(self.profiles_dir), package=str(self.package))
        self.schema_seen = []

    def fake_v6(self, rc=0, presentation=None):
        def run(args):
            self.schema_seen.append(pv6.SCHEMA_VERSION)
            document = dict(make_document(), schema_version=pv6.SCHEMA_VERSION, id=args.site)
            if presentation is not None:
                document["presentation"] = presentation
            for directory, name in ((self.out, "world.1.json"), (self.resolved, "world.1.resolved.json")):
                (directory / name).write_text(json.dumps(document, indent=2), encoding="utf-8")
            return rc
        return run

    def run_wrapper(self, fake):
        stdout = io.StringIO()
        with mock.patch.object(pv6, "run_site_v6", fake), contextlib.redirect_stdout(stdout):
            rc = pv7.run_site_v7(self.args)
        return rc, stdout.getvalue()

    def test_the_document_gets_the_v7_schema_and_the_resources(self) -> None:
        previous = pv6.SCHEMA_VERSION
        rc, out = self.run_wrapper(self.fake_v6())
        self.assertEqual(rc, 0, out)
        self.assertEqual(self.schema_seen, [pv7.SCHEMA_VERSION])
        self.assertEqual(pv6.SCHEMA_VERSION, previous)
        document = json.loads((self.out / "world.1.json").read_text(encoding="utf-8"))
        self.assertEqual(document["schema_version"], "kakyu_event_definition/v7")
        self.assertEqual(list(document["presentation"].keys()), ["status", "resources"])
        self.assertEqual(document["presentation"]["resources"], [
            {"entry": "LIBLARY.LIB", "source_offset": 100, "kind": "mmo", "name": "BLACK.MMO"},
            {"entry": "OTHER.MES", "source_offset": 5, "kind": "voice", "name": "V9.OGG"},
            {"entry": "ROUTE.MES", "source_offset": 10, "kind": "mmo", "name": "PIC.MMO"},
        ])
        resolved = json.loads((self.resolved / "world.1.resolved.json").read_text(encoding="utf-8"))
        self.assertEqual(resolved["presentation"], document["presentation"])
        self.assertTrue((self.out / "world.1.json").read_text(encoding="utf-8").endswith("}\n"))
        self.assertIn(
            "RESOURCES_STATUS site=world.1 items=3 runs=2 route=2 def=0 lib_excluded=0 "
            "mmo=2 ax=0 voice=1 se=0 a6=0 bgm=0 unclassified=0", out)

    def test_the_status_line_round_trips_through_the_batch_parser(self) -> None:
        import project_event_definitions_batch as batch
        _rc, out = self.run_wrapper(self.fake_v6())
        status = batch.parse_resources_status(out)
        self.assertEqual((status["site"], status["items"], status["runs"], status["lib_excluded"], status["voice"]), ("world.1", 3, 2, 0, 1))

    def test_a_refused_route_removes_the_written_document(self) -> None:
        (self.replays / ("%s.json" % STEM)).write_text(json.dumps(make_replay([site_variant(executed={})])), encoding="utf-8")
        rc, out = self.run_wrapper(self.fake_v6())
        self.assertEqual(rc, 1)
        self.assertIn("RESOURCES FAILED world.1:", out)
        self.assertFalse((self.out / "world.1.json").exists())
        self.assertFalse((self.resolved / "world.1.resolved.json").exists())

    def test_a_v6_failure_is_passed_through(self) -> None:
        rc, out = self.run_wrapper(self.fake_v6(rc=1))
        self.assertEqual(rc, 1)
        self.assertNotIn("RESOURCES_STATUS", out)

    def test_the_v6_pipeline_must_leave_the_empty_deferred_presentation(self) -> None:
        rc, out = self.run_wrapper(self.fake_v6(presentation={"status": "deferred", "resources": [{"x": 1}]}))
        self.assertEqual(rc, 1)
        self.assertIn("did not leave the empty deferred presentation", out)

    def test_a_catalog_event_projection_is_refused(self) -> None:
        stdout = io.StringIO()
        with mock.patch.object(sys, "argv", ["project_event_definition_v7.py", "--event", "x", "--catalog", "c", "--replay", "r",
                                             "--names", "n", "--package", "p", "--arc", "a", "--out", "o"]), \
                contextlib.redirect_stdout(stdout):
            self.assertEqual(pv7.main(), 1)
        self.assertIn("analysis-group sites only", stdout.getvalue())

    def test_the_defaults_are_the_v7_replays_and_fingerprint(self) -> None:
        parser = pv6.build_parser()
        parser.set_defaults(replays_dir=pv7.DEFAULT_REPLAYS_DIR, contract_fingerprint=pv7.DEFAULT_CONTRACT_FINGERPRINT_PATH)
        args = parser.parse_args(["--site", "x", "--names", "n", "--package", "p", "--arc", "a", "--out", "o"])
        self.assertTrue(args.replays_dir.endswith("replays_v3"))
        self.assertIn("event_definition_v7", args.contract_fingerprint)
        self.assertIn("event_definition_v6", pv6.build_parser().parse_args(["--site", "x", "--names", "n", "--package", "p", "--arc", "a", "--out", "o"]).contract_fingerprint)
        self.assertTrue(Path(ROOT / pv7.DEFAULT_CONTRACT_FINGERPRINT_PATH).is_file())


class PackageMediaTests(unittest.TestCase):
    def test_it_refuses_a_manifest_without_the_known_inventory(self) -> None:
        for change in (lambda m: m.pop("media_inventory"), lambda m: m["media_inventory"].update(schema="kakyu_media_inventory/v2")):
            manifest = make_manifest()
            change(manifest)
            with self.assertRaisesRegex(pv7.ResourceError, "media_inventory"):
                make_media(manifest)

    def test_a_member_with_no_records_cannot_vouch_for_an_offset(self) -> None:
        media = make_media(documents=dict(MEMBER_DOCUMENTS, **{"ROUTE.MES": {"records": []}}))
        with self.assertRaisesRegex(pv7.ResourceError, "no records"):
            media.record_starts("ROUTE.MES")

    def test_record_starts_are_read_once(self) -> None:
        calls = []

        def load(entry):
            calls.append(entry)
            return MEMBER_DOCUMENTS[entry]

        media = pv7.PackageMedia(make_manifest(), load)
        media.record_starts("ROUTE.MES")
        media.record_starts("ROUTE.MES")
        self.assertEqual(calls, ["ROUTE.MES"])


if __name__ == "__main__":
    unittest.main()
