"""Tests for `tools/promote_analysis_groups.py` (EP-10 unit 5b: every v4
event definition becomes a generated Event Catalog row; there are no more
hand-authored rows - see `analysis/_docs/ep10_unit5bc_spec.md`)."""
from __future__ import annotations

import json
import subprocess
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

import promote_analysis_groups as pag  # noqa: E402

CATALOG_PATH = ROOT / "config" / "event_catalog" / "original_events_v1.json"
# Checkpoint C (2026-09-25): the promoter's document source is the live
# definition set, not the frozen v4 (`tools/promote_analysis_groups.py`'s
# `--definitions-dir`, alias `--v4-dir`). WD-21 U2 C5 (2026-10-08): the live set
# is v7 - v6 plus `presentation.resources`, which the catalog rows' `resources`
# are mapped from; every other field the promoter reads is v6's own (the 681
# documents are equal outside `presentation`).
V4_DIR = ROOT / "config" / "event_definitions" / "v7"
PROFILES_DIR = ROOT / "config" / "event_catalog" / "analysis_groups"

TERMINAL_KIND_VOCABULARY = {
    "root_replacement", "caller_handoff", "callee_return_only", "analysis_boundary",
}


class PromoteAnalysisGroupsTests(unittest.TestCase):
    def setUp(self) -> None:
        self.catalog, self.report = pag.generate(CATALOG_PATH, V4_DIR, PROFILES_DIR)

    def test_regenerated_catalog_matches_tracked_file_byte_for_byte(self) -> None:
        serialized = pag.serialize(self.catalog)
        with open(CATALOG_PATH, "rb") as fh:
            current = fh.read()
        self.assertEqual(current, serialized)

    def test_every_row_carries_its_documents_measured_resources(self) -> None:
        # WD-21 U2 C5: each row's `resources` is its v7 document's
        # `presentation.resources`, mapped item by item and numbered
        # `res-0001`... in the document's sorted order. Flow rows read their
        # flow document by the registry id, site rows their own.
        by_id = {}
        for path in V4_DIR.glob("*.json"):
            if path.name == "index.json":
                continue
            doc = pag.load_json(path)
            by_id[doc["id"]] = doc
        total = 0
        for event in self.catalog["events"]:
            doc = by_id[event["analysis_group"]["definition_id"]]
            items = doc["presentation"]["resources"]
            self.assertEqual(
                [{"resource_id": "res-%04d" % (i + 1), "request_entry": item["entry"],
                  "request_offset": item["source_offset"], "entry": item["name"]}
                 for i, item in enumerate(items)],
                event["resources"], event["event_id"])
            total += len(items)
        # TD-56 C5: the v7 lists carry the restored `LIBLARY.LIB` items, 17,020 plus 1,093.
        self.assertEqual(18113, total)
        self.assertEqual(43, self.catalog["catalog_revision"])

    def test_resource_items_have_only_the_four_fields_and_unique_ids(self) -> None:
        for event in self.catalog["events"]:
            ids = [item["resource_id"] for item in event["resources"]]
            self.assertEqual(len(ids), len(set(ids)), event["event_id"])
            for item in event["resources"]:
                self.assertEqual(["resource_id", "request_entry", "request_offset", "entry"], list(item), event["event_id"])

    def test_145_rows_all_generated_ids_unique(self) -> None:
        # EP-12 C..L date batch (2026-09-25): +27 promoted c..l-date flow rows.
        # EP-12 PROMIS checkpoint C (2026-09-25): +12 promoted 01m-<letter>-promis rows.
        events = self.catalog["events"]
        # EP-12 SCENE J unit (2026-10-04): +25 album-scene rows of heroine J.
        # EP-12 SCENE all-menus unit (2026-10-04): +340, the other twelve menus.
        # EP-12 H unit (2026-10-04): +13, the recollection ladders of the room.
        # EP-12 TALK K unit (2026-10-04): +9, heroine K's conversation scripts.
        # EP-12 TALK rest unit (2026-10-05): +105, the other eleven heroines, Tina and the characters N..Q.
        self.assertEqual(681, len(events))
        generated = [event for event in events if "analysis_group" in event]
        self.assertEqual(681, len(generated))
        ids = [event["event_id"] for event in events]
        self.assertEqual(len(ids), len(set(ids)))

    def test_playback_status_and_classification_split(self) -> None:
        # Owner ruling 2026-09-21 (option 1): minimal_playback/playable_event
        # when the default option's winning route ends map_return,
        # place_menu or chain; analysis_only/unresolved_route otherwise.
        events = self.catalog["events"]
        minimal = [event for event in events if event["playback_status"] == "minimal_playback"]
        analysis_only = [event for event in events if event["playback_status"] == "analysis_only"]
        self.assertEqual(len(events), len(minimal) + len(analysis_only))
        for event in minimal:
            # A `duplicate_route` album scene is still its own playable route.
            self.assertIn(event["classification"], ("playable_event", "duplicate_route"), event["event_id"])
        for event in analysis_only:
            self.assertEqual("unresolved_route", event["classification"], event["event_id"])

    def test_every_generated_row_has_unique_preset_terminal_and_option_ids(self) -> None:
        # Owner ruling (2026-09-20, round 7): a collision must fail the
        # generator, not the catalog load - `assert_unique_ids` runs inside
        # `build_row` for every generated row already; re-check the tracked
        # result directly too, so a regression is caught here as well.
        for event in self.catalog["events"]:
            preset_ids = [preset["preset_id"] for preset in event["presets"]]
            self.assertEqual(len(preset_ids), len(set(preset_ids)), event["event_id"])
            terminal_ids = [terminal["terminal_id"] for terminal in event["terminals"]]
            self.assertEqual(len(terminal_ids), len(set(terminal_ids)), event["event_id"])
            for choice in event.get("choices", []):
                option_ids = [option["option_id"] for option in choice["options"]]
                self.assertEqual(len(option_ids), len(set(option_ids)), event["event_id"])

    def test_assert_unique_ids_raises_on_a_duplicate_preset_id(self) -> None:
        row = {
            "event_id": "original/synthetic/x-00000000",
            "presets": [{"preset_id": "a"}, {"preset_id": "a"}],
            "terminals": [{"terminal_id": "t1"}],
            "choices": [],
        }
        with self.assertRaises(SystemExit):
            pag.assert_unique_ids("synthetic.definition", row)

    def test_assert_unique_ids_raises_on_a_duplicate_option_id(self) -> None:
        row = {
            "event_id": "original/synthetic/x-00000000",
            "presets": [{"preset_id": "a"}, {"preset_id": "b"}],
            "terminals": [{"terminal_id": "t1"}],
            "choices": [{"choice_id": "choice-1", "options": [{"option_id": "option-1"}, {"option_id": "option-1"}]}],
        }
        with self.assertRaises(SystemExit):
            pag.assert_unique_ids("synthetic.definition", row)

    def test_assert_unique_ids_accepts_a_clean_row(self) -> None:
        row = {
            "event_id": "original/synthetic/x-00000000",
            "presets": [{"preset_id": "a"}, {"preset_id": "b"}],
            "terminals": [{"terminal_id": "t1"}, {"terminal_id": "t2"}],
            "choices": [{"choice_id": "choice-1", "options": [{"option_id": "option-1"}, {"option_id": "option-2"}]}],
        }
        pag.assert_unique_ids("synthetic.definition", row)  # must not raise

    def test_generated_terminals_use_only_the_six_mappings(self) -> None:
        for event in self.catalog["events"]:
            for terminal in event["terminals"]:
                self.assertIn(terminal["kind"], TERMINAL_KIND_VOCABULARY, event["event_id"])

    def test_generated_row_site_matches_its_v4_document(self) -> None:
        by_id = {}
        for path in V4_DIR.glob("*.json"):
            if path.name == "index.json":
                continue
            doc = pag.load_json(path)
            by_id[doc["id"]] = doc
        # EP-12 catalog part (2026-09-24): a v14 flow route has no v4/v5
        # document of its own in this unit (`build_flow_row`, not `build_row`)
        # - excluded here by its group's own profile schema, not by id shape.
        flow_group_ids = {
            doc["group_id"] for doc in (pag.load_json(path) for path in PROFILES_DIR.glob("*.json"))
            if doc.get("schema") == pag.FLOW_SCHEMA
        }
        for event in self.catalog["events"]:
            if event["analysis_group"]["groups"][0]["group_id"] in flow_group_ids:
                continue
            doc = by_id[event["analysis_group"]["definition_id"]]
            caller = doc["trigger"]["caller"]
            self.assertEqual(caller["entry"].upper(), event["source"]["caller"]["entry"].upper())
            self.assertEqual(int(caller["offset"]), int(event["source"]["caller"]["dispatch_offset"]))
            callee = doc["trigger"]["callee"]
            self.assertEqual(callee["entry"].upper(), event["source"]["callee"]["entry"].upper())

    def test_row_status_matches_the_outcome_rule_for_the_first_measured_option(self) -> None:
        # EP-10 unit 5bc part 5, item 2: `default_route_for_playback` must
        # pick the runtime's default option (the first measured one, not
        # `options[0]` unconditionally) before `playback_status_and_classification`
        # applies the outcome rule to it.
        by_group = pag.load_profiles(PROFILES_DIR)
        by_event_id = {event["event_id"]: event for event in self.catalog["events"]}
        checked_with_choices = 0
        for doc in pag.load_v4_documents(V4_DIR):
            winners = pag.winning_group_indexes(doc, by_group)
            route_entries = pag.referenced_route_entries(doc, by_group, winners)
            ordered_terminal_ids = pag.all_terminal_ids(doc)
            choices = pag.build_choices(doc, [], ordered_terminal_ids, route_entries)
            if not choices:
                continue
            checked_with_choices += 1
            expected_status, expected_classification = pag.playback_status_and_classification(route_entries, choices)
            event_id = pag.build_event_id(doc)
            event = by_event_id[event_id]
            self.assertEqual(expected_status, event["playback_status"], event_id)
            self.assertEqual(expected_classification, event["classification"], event_id)
        self.assertGreater(checked_with_choices, 0)

    def test_check_flag_exit_codes(self) -> None:
        ok = subprocess.run(
            [sys.executable, str(ROOT / "tools" / "promote_analysis_groups.py"), "--check"],
            capture_output=True, text=True, encoding="utf-8", cwd=str(ROOT),
        )
        self.assertEqual(0, ok.returncode, ok.stdout + ok.stderr)

        mutated_catalog = json.loads(json.dumps(self.catalog))
        # Mutating a hand-authored row would not be caught (hand rows pass
        # through untouched); swap two generated rows out of their canonical
        # event_id order instead, which regeneration always restores.
        generated_indexes = [
            index for index, event in enumerate(mutated_catalog["events"]) if "analysis_group" in event
        ]
        first, second = generated_indexes[0], generated_indexes[1]
        events = mutated_catalog["events"]
        events[first], events[second] = events[second], events[first]
        mutated_path = Path(ROOT / "analysis" / "_undoc" / "promote_analysis_groups_mutated_for_test.json")
        mutated_path.parent.mkdir(parents=True, exist_ok=True)
        with open(mutated_path, "w", encoding="utf-8", newline="\n") as fh:
            json.dump(mutated_catalog, fh, indent=2, ensure_ascii=False)
            fh.write("\n")
        try:
            failing = subprocess.run(
                [sys.executable, str(ROOT / "tools" / "promote_analysis_groups.py"),
                 "--check", "--catalog", str(mutated_path)],
                capture_output=True, text=True, encoding="utf-8", cwd=str(ROOT),
            )
            self.assertEqual(1, failing.returncode)
        finally:
            mutated_path.unlink(missing_ok=True)


def _definition(resources, schema="kakyu_event_definition/v7"):
    return {"id": "synthetic.definition", "schema_version": schema,
            "presentation": {"status": "deferred", "resources": resources}}


def _item(entry, offset, kind, name):
    return {"entry": entry, "source_offset": offset, "kind": kind, "name": name}


class CatalogResourcesTests(unittest.TestCase):
    """WD-21 U2 C5 (D8): a v7 `presentation.resources` item becomes the v8
    catalog's resource item; anything the catalog loader would refuse, or that
    would make the ordinal ids unstable, stops the tool."""

    def test_items_map_to_the_catalog_item_with_ordinal_ids(self):
        items = [_item("01M.MES", 12, "mmo", "A.MMO"), _item("01M.MES", 40, "voice", "V1.WAV"),
                 _item("DEF_MAIN.MES", 5, "unclassified", "X.DAT"), _item("SCENE.MES", 0, "bgm", "B.WAV")]
        self.assertEqual(
            [{"resource_id": "res-0001", "request_entry": "01M.MES", "request_offset": 12, "entry": "A.MMO"},
             {"resource_id": "res-0002", "request_entry": "01M.MES", "request_offset": 40, "entry": "V1.WAV"},
             {"resource_id": "res-0003", "request_entry": "DEF_MAIN.MES", "request_offset": 5, "entry": "X.DAT"},
             {"resource_id": "res-0004", "request_entry": "SCENE.MES", "request_offset": 0, "entry": "B.WAV"}],
            pag.catalog_resources(_definition(items)))

    def test_an_empty_list_is_an_empty_list_and_the_kind_is_not_carried(self):
        self.assertEqual([], pag.catalog_resources(_definition([])))
        (item,) = pag.catalog_resources(_definition([_item("A.MES", 1, "se", "S.WAV")]))
        self.assertNotIn("kind", item)
        self.assertNotIn("original_entry_sha256", item)
        self.assertNotIn("branch_ids", item)

    def test_two_kinds_at_one_offset_get_two_ordinals(self):
        # (entry, offset, kind, name) is the sort key: a Tina name has two rows.
        items = [_item("A.MES", 7, "mmo", "N.MMO"), _item("A.MES", 7, "voice", "N.MMO")]
        self.assertEqual(["res-0001", "res-0002"], [r["resource_id"] for r in pag.catalog_resources(_definition(items))])

    def test_the_catalog_id_is_a_slug(self):
        (item,) = pag.catalog_resources(_definition([_item("A.MES", 1, "se", "S.WAV")]))
        self.assertRegex(item["resource_id"], r"^[a-z0-9_-]+$")

    def test_a_name_that_is_not_a_safe_leaf_stops_the_tool(self):
        for bad in ("", "A/B.MMO", "A\\B.MMO", "A..MMO", "C:A.MMO"):
            with self.assertRaises(SystemExit, msg=repr(bad)) as raised:
                pag.catalog_resources(_definition([_item("A.MES", 1, "mmo", bad)]))
            self.assertIn("safe leaf", str(raised.exception))

    def test_an_entry_that_is_not_a_safe_leaf_stops_the_tool(self):
        with self.assertRaises(SystemExit):
            pag.catalog_resources(_definition([_item("../A.MES", 1, "mmo", "A.MMO")]))

    def test_a_set_that_is_not_v7_is_refused(self):
        for schema in ("kakyu_event_definition/v6", "kakyu_event_definition/v5", None):
            with self.assertRaises(SystemExit):
                pag.catalog_resources(_definition([], schema))

    def test_unsorted_duplicate_and_malformed_lists_stop_the_tool(self):
        unsorted = [_item("B.MES", 1, "mmo", "A.MMO"), _item("A.MES", 1, "mmo", "A.MMO")]
        duplicate = [_item("A.MES", 1, "mmo", "A.MMO")] * 2
        extra_key = [dict(_item("A.MES", 1, "mmo", "A.MMO"), original_entry_sha256="x")]
        negative = [_item("A.MES", -1, "mmo", "A.MMO")]
        boolean = [_item("A.MES", True, "mmo", "A.MMO")]
        for bad in (unsorted, duplicate, extra_key, negative, boolean):
            with self.assertRaises(SystemExit, msg=repr(bad)):
                pag.catalog_resources(_definition(bad))
        for broken in ({"id": "x", "schema_version": "kakyu_event_definition/v7"},
                       {"id": "x", "schema_version": "kakyu_event_definition/v7", "presentation": {"resources": "no"}}):
            with self.assertRaises(SystemExit):
                pag.catalog_resources(broken)

    def test_a_list_past_the_four_digit_ordinal_stops_the_tool(self):
        items = [_item("A.MES", offset, "mmo", "A.MMO") for offset in range(pag.MAX_RESOURCE_ORDINAL + 1)]
        with self.assertRaises(SystemExit):
            pag.catalog_resources(_definition(items))
        ok = pag.catalog_resources(_definition(items[:pag.MAX_RESOURCE_ORDINAL]))
        self.assertEqual("res-9999", ok[-1]["resource_id"])

    def test_the_definition_loader_splits_sites_from_flows_and_keeps_flows_by_id(self):
        sites, flows = pag.load_definition_documents(V4_DIR)
        self.assertEqual(154, len(sites))
        self.assertEqual(527, len(flows))
        self.assertTrue(all("flow" in doc and doc["id"] == key for key, doc in flows.items()))
        self.assertEqual(sites, pag.load_v4_documents(V4_DIR))

    def test_a_flow_row_without_its_flow_document_stops_the_tool(self):
        registry = {"rows": {"r1": {"id": "synthetic.flow", "aliases": {"groups": [{"group_id": "g", "route_ids": ["r"]}]}}}}
        with self.assertRaises(SystemExit) as raised:
            pag.build_flow_row("g", {"payload_sha256": "a" * 64}, {"route_id": "r"}, registry, {})
        self.assertIn("synthetic.flow", str(raised.exception))


def _row(event_id, callee, classification="playable_event"):
    return {"event_id": event_id, "classification": classification, "canonical_event_id": "",
            "source": {"callee": {"entry": callee}}}


class DuplicateRouteRuleTests(unittest.TestCase):
    """EP-12 gallery (2026-10-04): a scene message-identical to a callee that
    already has a row becomes a `duplicate_route` of it."""

    GROUPS = {"groups": [
        {"kind": "gallery_copy_of_event", "source": "EVENTJ04.MES", "gallery_members": ["SCENE_J03.MES"],
         "entries": ["EVENTJ04.MES", "SCENE_J03.MES"]},
        {"kind": "gallery_copy_of_event", "source": "EVENTH16.MES", "gallery_members": ["SCENE_H10.MES", "SCENE_K07.MES"],
         "entries": ["EVENTH16.MES", "SCENE_H10.MES", "SCENE_K07.MES"]},
        {"kind": "gallery_copy_of_other", "source": "J_END.MES", "gallery_members": ["SCENE_J16.MES"],
         "entries": ["J_END.MES", "SCENE_J16.MES"]},
        {"kind": "gallery_internal", "entries": ["SCENE_K03.MES", "SCENE_H06.MES"]},
        {"kind": "non_gallery", "entries": ["G_TIME.MES", "I_TIME.MES"]},
        {"kind": "event_only", "entries": ["EVENTL09.MES", "EVENTL10.MES"]},
    ]}

    def _rows(self):
        return [
            _row("e/eventj04", "EVENTJ04.MES"), _row("s/j03", "SCENE_J03.MES"),
            _row("e/eventh16", "EVENTH16.MES"), _row("s/h10", "SCENE_H10.MES"), _row("s/k07", "SCENE_K07.MES"),
            _row("s/j16", "SCENE_J16.MES"), _row("e/j_end", "J_END.MES"),
            _row("s/h06", "SCENE_H06.MES"), _row("s/k03", "SCENE_K03.MES"),
        ]

    def test_an_event_copy_points_at_its_event_row_and_nothing_else_changes(self):
        rows = self._rows()
        report = pag.resolve_duplicate_routes(rows, self.GROUPS)
        by_id = {row["event_id"]: row for row in rows}
        self.assertEqual(by_id["s/j03"]["classification"], "duplicate_route")
        self.assertEqual(by_id["s/j03"]["canonical_event_id"], "e/eventj04")
        self.assertEqual(by_id["e/eventj04"]["classification"], "playable_event")
        self.assertEqual(by_id["e/eventj04"]["canonical_event_id"], "")
        self.assertEqual({entry["event_id"] for entry in report}, {"s/j03", "s/h10", "s/k07", "s/k03"})

    def test_two_scene_copies_of_one_event_share_its_canonical_row(self):
        rows = self._rows()
        pag.resolve_duplicate_routes(rows, self.GROUPS)
        by_id = {row["event_id"]: row for row in rows}
        self.assertEqual(by_id["s/h10"]["canonical_event_id"], "e/eventh16")
        self.assertEqual(by_id["s/k07"]["canonical_event_id"], "e/eventh16")

    def test_an_end_script_twin_stays_an_ordinary_row(self):
        rows = self._rows()
        pag.resolve_duplicate_routes(rows, self.GROUPS)
        by_id = {row["event_id"]: row for row in rows}
        self.assertEqual(by_id["s/j16"]["classification"], "playable_event")
        self.assertEqual(by_id["s/j16"]["canonical_event_id"], "")

    def test_in_an_internal_pair_the_first_entry_name_is_canonical(self):
        # The four pairs are H/K scenes: the H scene is canonical whatever
        # order the census lists them in.
        rows = self._rows()
        pag.resolve_duplicate_routes(rows, self.GROUPS)
        by_id = {row["event_id"]: row for row in rows}
        self.assertEqual(by_id["s/h06"]["classification"], "playable_event")
        self.assertEqual(by_id["s/k03"]["classification"], "duplicate_route")
        self.assertEqual(by_id["s/k03"]["canonical_event_id"], "s/h06")

    def test_a_copy_without_a_canonical_row_or_a_row_of_its_own_is_left_alone(self):
        rows = [_row("s/j03", "SCENE_J03.MES")]  # EVENTJ04 has no row
        self.assertEqual(pag.resolve_duplicate_routes(rows, self.GROUPS), [])
        self.assertEqual(rows[0]["classification"], "playable_event")
        rows = [_row("e/eventj04", "EVENTJ04.MES")]  # the scene has no row
        self.assertEqual(pag.resolve_duplicate_routes(rows, self.GROUPS), [])
        self.assertEqual(rows[0]["classification"], "playable_event")

    def test_an_ambiguous_canonical_stops_the_tool(self):
        rows = self._rows() + [_row("e/eventj04-b", "EVENTJ04.MES")]
        with self.assertRaises(SystemExit) as raised:
            pag.resolve_duplicate_routes(rows, self.GROUPS)
        self.assertIn("ambiguous", str(raised.exception))

    def test_a_scene_with_two_rows_stops_the_tool(self):
        rows = self._rows() + [_row("s/j03-b", "SCENE_J03.MES")]
        with self.assertRaises(SystemExit):
            pag.resolve_duplicate_routes(rows, self.GROUPS)


class GalleryFlowRowTests(unittest.TestCase):
    """A scene flow (menu dispatch, then the scene to its own return)."""

    @staticmethod
    def _route():
        outcome = {"offset": 1394, "end": 1411, "op": "script_dispatch", "status": "script_dispatch_boundary",
                   "target": "SCENE_J03.MES"}
        terminal = {"offset": 1460, "end": 1461, "op": "command_00", "status": "script_return"}
        return {"route_id": "j-scene-03", "origin": {"entry": "MINATU_M.MES", "offset": 1127},
                "hops": [
                    {"hop_id": "h1", "entry": "MINATU_M.MES", "entered_by": {"kind": "origin"},
                     "expected": {"outcome": outcome}},
                    {"hop_id": "h2", "entry": "SCENE_J03.MES", "entered_by": {"kind": "nested_call"},
                     "expected": {"outcome": terminal}}],
                "terminal": {"entry": "SCENE_J03.MES", **terminal}}

    def test_a_returning_scene_has_the_callee_return_and_menu_loop_pair(self):
        terminals = pag.build_flow_terminals(self._route())
        self.assertEqual([t["kind"] for t in terminals], ["callee_return_only", "analysis_boundary"])
        self.assertEqual([t["runtime_status"] for t in terminals], ["script_return", "loop_boundary"])
        self.assertEqual([t["sequence"] for t in terminals], [10, 30])
        self.assertEqual((terminals[0]["owner_entry"], terminals[0]["offset"]), ("SCENE_J03.MES", 1460))
        self.assertEqual((terminals[1]["owner_entry"], terminals[1]["offset"]), ("MINATU_M.MES", 1411))
        self.assertEqual(len({t["terminal_id"] for t in terminals}), 2)

    def test_a_handoff_flow_keeps_its_single_terminal(self):
        route = self._route()
        route["terminal"] = {"entry": "A_HOTEL.MES", "offset": 5, "end": 16, "op": "script_handoff_marker",
                             "status": "script_handoff_boundary", "target": "MACHI.MES"}
        terminals = pag.build_flow_terminals(route)
        self.assertEqual(len(terminals), 1)
        self.assertEqual((terminals[0]["kind"], terminals[0]["next_target"]), ("root_replacement", "MACHI.MES"))

    def test_the_returning_scene_is_classified_place_menu(self):
        from event_outcome_vocabulary import flow_route_outcome
        self.assertEqual(flow_route_outcome(self._route())["outcome"], "place_menu")

    @staticmethod
    def _question_route():
        """The scene asks one question at 353 (option 1 by default); a second
        variant answers option 2, and a third is a recap-style path that
        writes cells and plays its own number of lines."""
        route = GalleryFlowRowTests._route()
        route["hops"][1]["answers"] = [{"boundary_offset": 353, "result_value": 1}]
        route["baseline"] = [{"storage": "global_u8", "bank": 0, "index": 20, "value": 1}]
        route["variants"] = [
            {"variant_id": "default", "writes": [], "expected_state": []},
            {"variant_id": "option-2", "writes": [], "expected_state": [],
             "answers": [{"hop_id": "h2", "boundary_offset": 353, "result_value": 2}]},
            {"variant_id": "hotel-path", "expected_state": [],
             "writes": [{"storage": "global_u8", "bank": 0, "index": 2708, "value": 2}],
             "message_counts": {"h2": 36}},
        ]
        return route

    def test_a_question_option_a_variant_answers_binds_as_an_option_of_the_row(self):
        choices = pag.build_flow_choices(self._question_route(), "j-scene-03-outcome")
        self.assertEqual(len(choices), 1)
        choice = choices[0]
        self.assertEqual((choice["owner_entry"], choice["boundary_offset"]), ("SCENE_J03.MES", 353))
        self.assertEqual([o["option_id"] for o in choice["options"]], ["option-1", "option-2"])
        self.assertEqual([o["result_value"] for o in choice["options"]], [1, 2])
        self.assertEqual([o["source_row"] for o in choice["options"]], [0, 1])
        self.assertTrue(all(o["terminal_ids"] == ["j-scene-03-outcome"] for o in choice["options"]))

    def test_a_route_without_variant_answers_keeps_its_single_option(self):
        route = self._question_route()
        route["variants"] = [route["variants"][0], route["variants"][2]]
        (choice,) = pag.build_flow_choices(route, "t")
        self.assertEqual(choice["options"], [{"option_id": "option-1", "source_row": 0, "result_value": 1,
                                              "branch_id": "", "terminal_ids": ["t"]}])
        route = self._route()  # no hop answers, no variants at all
        self.assertEqual(pag.build_flow_choices(route, "t"), [])

    def test_an_option_is_listed_once_and_a_variant_naming_another_hop_adds_nothing_here(self):
        route = self._question_route()
        route["variants"].append({"variant_id": "option-2-again", "writes": [], "expected_state": [],
                                  "answers": [{"hop_id": "h2", "boundary_offset": 353, "result_value": 2}]})
        route["variants"].append({"variant_id": "other-hop", "writes": [], "expected_state": [],
                                  "answers": [{"hop_id": "h1", "boundary_offset": 99, "result_value": 4}]})
        choices = {c["owner_entry"]: c for c in pag.build_flow_choices(route, "t")}
        self.assertEqual([o["result_value"] for o in choices["SCENE_J03.MES"]["options"]], [1, 2])
        # A variant may supply an answer a hop does not declare: it is the
        # owner hop's own choice, its option the variant's value.
        self.assertEqual([o["result_value"] for o in choices["MINATU_M.MES"]["options"]], [4])

    def test_every_variant_is_a_preset_and_a_recap_path_carries_its_writes(self):
        presets = pag.build_flow_presets("minatu-m-scene", "a" * 64, self._question_route())
        self.assertEqual([p["label"] for p in presets], ["default", "option-2", "hotel-path"])
        by_label = {p["label"]: p for p in presets}
        self.assertEqual(by_label["option-2"]["writes"], by_label["default"]["writes"])
        self.assertEqual(
            [(w["storage"], w["index"], w["value"]) for w in by_label["hotel-path"]["writes"]],
            [("global_u8", 20, 1), ("global_u8", 2708, 2)])
        self.assertTrue(all(p["notes"].startswith("analysis-group variant minatu-m-scene@aaaaaaaaaaaa/j-scene-03/")
                            for p in presets))
        self.assertEqual(len({p["preset_id"] for p in presets}), 3)

    def test_gallery_rows_carry_the_gallery_category(self):
        registry_row = {"heroine": "minatu", "title_en": "Minatu in the album (SCENE_J03)", "scene_kinds": [],
                        "category": "special", "evidence": {"callee": "SCENE_J03.MES"}}
        self.assertTrue(pag.is_gallery_registry_row(registry_row))
        self.assertEqual(pag.build_flow_display(registry_row)["categories"], ["gallery"])
        date_row = {"heroine": "miko", "title_en": "x", "scene_kinds": ["train_ride"], "category": "town",
                    "number": "date-town", "evidence": {"callee": "A_PIC.MES"}}
        self.assertFalse(pag.is_gallery_registry_row(date_row))
        self.assertEqual(pag.build_flow_display(date_row)["categories"], ["date", "train_ride"])
        # EP-12 H: a flow that is neither (a room recollection ladder) is an
        # ordinary site row: `character_event` and the registry category.
        ladder_row = {"heroine": "miko", "title_en": "Miko at 43c (MIKO_H)", "scene_kinds": [], "category": "town",
                      "number": "h", "place": "43c", "evidence": {"callee": "MIKO_H.MES", "caller": "43C.MES"}}
        self.assertFalse(pag.is_gallery_registry_row(ladder_row))
        display = pag.build_flow_display(ladder_row)
        self.assertEqual(display["categories"], ["character_event", "town"])
        self.assertEqual((display["character_ids"], display["title"]), (["miko"], "Miko at 43c (MIKO_H)"))
        # EP-12 TALK: a heroine's conversation script at its confirmed caller is a
        # `conversation` row (the registry category follows), neither a date, an
        # album scene nor an ordinary `character_event` site row.
        talk_row = {"heroine": "ai", "title_en": "Ai at the station (K_TALK30)", "scene_kinds": [], "category": "town",
                    "number": "talk-30", "place": "station", "evidence": {"callee": "K_TALK30.MES", "caller": "01M.MES"}}
        self.assertFalse(pag.is_gallery_registry_row(talk_row))
        display = pag.build_flow_display(talk_row)
        self.assertEqual(display["categories"], ["conversation", "town"])
        self.assertEqual((display["character_ids"], display["title"]), (["ai"], "Ai at the station (K_TALK30)"))
        plain_row = dict(talk_row, number="talk-plain", place="27c_ev", title_en="Ai at 27c_ev (K_TALK)")
        self.assertEqual(pag.build_flow_display(plain_row)["categories"], ["conversation", "town"])


if __name__ == "__main__":
    unittest.main()
