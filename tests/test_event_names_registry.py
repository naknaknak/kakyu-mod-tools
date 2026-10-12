"""Tests for the shared event name registry (WD-22 part 1)."""
from __future__ import annotations

import json
import re
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

import build_event_names as builder  # noqa: E402
from contract_fingerprint import compute, stored  # noqa: E402
from payload_values import talk_script_parts  # noqa: E402

PROFILES_DIR = ROOT / "config" / "event_catalog" / "analysis_groups"
CATALOG_PATH = ROOT / "config" / "event_catalog" / "original_events_v1.json"
COMMITTED_DIR = ROOT / "config" / "contracts" / "event_names_v1"
COMMITTED_JSON = COMMITTED_DIR / "event_names.json"


class EventNamesRegistryTests(unittest.TestCase):
    def test_regeneration_is_byte_identical(self):
        # The fingerprint covers every file in the committed directory
        # (including README.md), but the generator only ever writes
        # event_names.json and the fingerprint file itself; a fresh,
        # README-less output directory is compared on event_names.json
        # bytes only. The fingerprint itself is checked against the
        # committed directory (README included) in the next test.
        self.assertTrue(COMMITTED_JSON.is_file(), f"committed registry missing: {COMMITTED_JSON}")
        with tempfile.TemporaryDirectory() as tmp:
            out_dir = Path(tmp)
            builder.run(PROFILES_DIR, CATALOG_PATH, out_dir)
            self.assertEqual(
                (out_dir / "event_names.json").read_bytes(),
                COMMITTED_JSON.read_bytes(),
            )

    def test_committed_fingerprint_matches(self):
        self.assertEqual(compute(COMMITTED_DIR, builder.FINGERPRINT_NAME), stored(COMMITTED_DIR, builder.FINGERPRINT_NAME))

    def test_every_route_and_catalog_event_maps_to_one_row(self):
        site_data, pair_offsets, profile_pair_offsets, multi_site_pairs, catalog_event_count = (
            builder.collect_sites(PROFILES_DIR, CATALOG_PATH)
        )
        rows = builder.build_rows(site_data, pair_offsets)

        # Every profile route belongs to exactly one row's aliases.groups.
        route_keys = set()
        for path in sorted(PROFILES_DIR.glob("*.json")):
            profile = json.loads(path.read_text(encoding="utf-8"))
            for route in profile["routes"]:
                # EP-12 catalog part (2026-09-24): a v14 flow route is now one
                # dispatch site (its own hop0), same as any other route.
                route_keys.add((profile["group_id"], route["route_id"]))

        covered_routes = set()
        catalog_event_ids = set()
        for row in rows.values():
            self.assertTrue(builder.ID_RE.match(row["id"]), row["id"])
            for group in row["aliases"]["groups"]:
                for route_id in group["route_ids"]:
                    covered_routes.add((group["group_id"], route_id))
            if "catalog_event_id" in row["aliases"]:
                catalog_event_ids.add(row["aliases"]["catalog_event_id"])

        self.assertEqual(covered_routes, route_keys)

        catalog = json.loads(CATALOG_PATH.read_text(encoding="utf-8"))
        # EP-10 unit 5b/c: every catalog row is now EP-10 generated, so the
        # `catalog_event_id` alias names every one of them.
        expected_event_ids = {event["event_id"] for event in catalog["events"]}
        self.assertEqual(catalog_event_ids, expected_event_ids)

        ids = [row["id"] for row in rows.values()]
        self.assertEqual(len(ids), len(set(ids)))

    def test_collect_sites_rejects_a_site_claimed_by_two_different_event_ids(self):
        # EP-10 unit 5bc part 5, item 4: `catalog_event_id` must be unique
        # per site; a second, differently-id'd catalog row landing on the
        # same (callee, caller, offset) site is a BuildError, not a silent
        # last-writer-wins overwrite.
        catalog = json.loads(CATALOG_PATH.read_text(encoding="utf-8"))
        first = catalog["events"][0]
        duplicate = json.loads(json.dumps(first))
        duplicate["event_id"] = first["event_id"] + "-duplicate-test"
        mutated = dict(catalog)
        mutated["events"] = catalog["events"] + [duplicate]
        with tempfile.TemporaryDirectory() as tmp:
            mutated_catalog_path = Path(tmp) / "mutated_catalog.json"
            mutated_catalog_path.write_text(json.dumps(mutated), encoding="utf-8")
            with self.assertRaises(builder.BuildError):
                builder.collect_sites(PROFILES_DIR, mutated_catalog_path)

    def test_projection_examples_exist(self):
        self.assertTrue(COMMITTED_JSON.is_file(), f"committed registry missing: {COMMITTED_JSON}")
        document = json.loads(COMMITTED_JSON.read_text(encoding="utf-8"))
        rows = document["rows"]

        for example_id in (
            "nana.school.gate.07.1",
            "ai.school.gate.09.1",
            "ai.school.gate.pic.1",
        ):
            self.assertIn(example_id, rows)

        station = rows["miyuki.town.station.07.1"]
        self.assertIn("train_ride", station["scene_kinds"])

        minatu = rows["minatu.town.station.04.1"]
        self.assertEqual(
            minatu["aliases"].get("catalog_event_id"),
            "original/eventj04/01m-00009b85",
        )

        common = rows["common.town.16m.q01.1"]
        self.assertEqual(common["heroine"], "common")


class GalleryNamesTests(unittest.TestCase):
    """EP-12 gallery (2026-10-04): a `SCENE_<letter>...` callee dispatched from
    an album menu is a registry site with the `special` category fall-through."""

    def test_scene_stems_resolve_a_heroine_and_a_number(self):
        self.assertEqual(builder.heroine_letter_and_number("SCENE_J01"), ("J", "01", False))
        self.assertEqual(builder.heroine_letter_and_number("SCENE_J16"), ("J", "16", False))
        # An H slot keeps its marker so the two numberings cannot collide.
        self.assertEqual(builder.heroine_letter_and_number("SCENE_J_H01"), ("J", "h01", False))
        self.assertEqual(builder.heroine_letter_and_number("SCENE_A_H09"), ("A", "h09", False))

    def test_malformed_scene_stems_stop_the_tool(self):
        for stem in ("SCENE_", "SCENE_J", "SCENE_Z01", "SCENE_j01", "SCENE_J_", "SCENE_1A"):
            with self.assertRaises(builder.BuildError, msg=stem):
                builder.heroine_letter_and_number(stem)

    def _site(self, callee, caller, offset, route_id):
        key = (callee, caller, offset, route_id)
        data = {key: {"groups": {"minatu-m-scene": {route_id}}, "dispatch_end": offset + 17, "command": 15,
                      "contracts": [], "catalog_event_id": None, "flow_route_id": route_id}}
        return data, {(callee, caller): {offset}}

    def test_a_gallery_route_becomes_one_special_row(self):
        site_data, pair_offsets = self._site("SCENE_J01.MES", "MINATU_M.MES", 1174, "j-scene-01")
        rows = builder.build_rows(site_data, pair_offsets)
        self.assertEqual(list(rows), ["minatu.special.minatu_m.01.1"])
        row = rows["minatu.special.minatu_m.01.1"]
        self.assertEqual((row["heroine"], row["category"], row["place"], row["number"], row["site"]),
                         ("minatu", "special", "minatu_m", "01", 1))
        self.assertEqual(row["aliases"]["groups"], [{"group_id": "minatu-m-scene", "route_ids": ["j-scene-01"]}])
        self.assertEqual(row["title_en"], "Minatu in the album (SCENE_J01)")
        self.assertTrue(builder.ID_RE.match(row["id"]))
        site_data, pair_offsets = self._site("SCENE_J_H09.MES", "MINATU_M.MES", 4127, "j-scene-h09")
        self.assertEqual(list(builder.build_rows(site_data, pair_offsets)), ["minatu.special.minatu_m.h09.1"])

    def test_a_route_id_that_names_another_scene_stops_the_tool(self):
        site_data, pair_offsets = self._site("SCENE_J01.MES", "MINATU_M.MES", 1174, "j-scene-02")
        with self.assertRaises(builder.BuildError):
            builder.build_rows(site_data, pair_offsets)

    def test_a_scene_dispatched_outside_an_album_menu_stops_the_tool(self):
        site_data, pair_offsets = self._site("SCENE_J01.MES", "GIRLS.MES", 1174, "j-scene-01")
        with self.assertRaises(builder.BuildError):
            builder.build_rows(site_data, pair_offsets)

    def test_the_album_menus_are_the_thirteen_heroine_menus(self):
        self.assertEqual(len(builder.GALLERY_MENU_STEMS), 13)
        self.assertIn("MIKO_M", builder.GALLERY_MENU_STEMS)
        self.assertIn("MINATU_M", builder.GALLERY_MENU_STEMS)
        self.assertEqual(builder.place_display("special", "minatu_m"), ("the album", "앨범"))
        self.assertEqual(builder.place_display("special", "01m"), ("01m", "01m"))


class RecollectionNamesTests(unittest.TestCase):
    """EP-12 H (2026-10-04): a `<ENGLISH NAME>_H` callee dispatched from `43C.MES`
    (the room's recollection ladder) is an ordinary town site numbered `h`."""

    def test_ladder_stems_resolve_their_heroine_from_the_table_in_reverse(self):
        self.assertEqual(builder.heroine_letter_and_number("MIKO_H"), ("A", "h", False))
        self.assertEqual(builder.heroine_letter_and_number("AI_H"), ("K", "h", False))
        self.assertEqual(builder.heroine_letter_and_number("TINA_H"), ("M", "h", False))
        self.assertEqual(len(builder.RECOLLECTION_HEROINE_BY_STEM), 13)
        self.assertEqual(sorted(builder.RECOLLECTION_HEROINE_BY_STEM.values()), sorted(builder.HEROINE_TABLE))

    def test_other_stems_are_not_mistaken_for_a_ladder(self):
        self.assertEqual(builder.heroine_letter_and_number("A_PIC"), ("A", "pic", False))
        self.assertEqual(builder.heroine_letter_and_number("EVENTA01"), ("A", "01", False))
        with self.assertRaises(builder.BuildError):
            builder.heroine_letter_and_number("MIKO_X")

    def _site(self, callee, caller, offset, route_id):
        key = (callee, caller, offset, route_id)
        data = {key: {"groups": {f"43c-{route_id}": {route_id}}, "dispatch_end": offset + 14, "command": 15,
                      "contracts": [], "catalog_event_id": None, "flow_route_id": route_id}}
        return data, {(callee, caller): {offset}}

    def test_a_ladder_route_becomes_one_town_row_of_the_room(self):
        site_data, pair_offsets = self._site("MIKO_H.MES", "43C.MES", 37004, "a-h")
        rows = builder.build_rows(site_data, pair_offsets)
        self.assertEqual(list(rows), ["miko.town.43c.h.1"])
        row = rows["miko.town.43c.h.1"]
        self.assertEqual((row["heroine"], row["category"], row["place"], row["number"], row["site"]),
                         ("miko", "town", "43c", "h", 1))
        self.assertTrue(builder.ID_RE.match(row["id"]))
        self.assertEqual(row["evidence"]["callee"], "MIKO_H.MES")

    def test_a_route_id_that_names_another_heroine_stops_the_tool(self):
        site_data, pair_offsets = self._site("MIKO_H.MES", "43C.MES", 37004, "b-h")
        with self.assertRaises(builder.BuildError):
            builder.build_rows(site_data, pair_offsets)

    def test_a_ladder_dispatched_outside_the_room_or_without_a_flow_route_stops_the_tool(self):
        site_data, pair_offsets = self._site("MIKO_H.MES", "44C.MES", 37004, "a-h")
        with self.assertRaises(builder.BuildError):
            builder.build_rows(site_data, pair_offsets)
        site_data, pair_offsets = self._site("MIKO_H.MES", "43C.MES", 37004, "")
        with self.assertRaises(builder.BuildError):
            builder.build_rows(site_data, pair_offsets)


class TalkNamesTests(unittest.TestCase):
    """EP-12 TALK (2026-10-04): a `<letter>_TALK<band>` or plain `<letter>_TALK` callee
    dispatched from its confirmed caller is an ordinary town site numbered
    `talk-<band>`, its flow route id `<letter>-talk-<band>`."""

    def _site(self, callee, caller, offset, route_id):
        key = (callee, caller, offset, route_id)
        data = {key: {"groups": {"01m-k-talk": {route_id}}, "dispatch_end": offset + 16, "command": 15,
                      "contracts": [], "catalog_event_id": None, "flow_route_id": route_id}}
        return data, {(callee, caller): {offset}}

    def test_a_rung_route_becomes_one_station_row(self):
        site_data, pair_offsets = self._site("K_TALK30.MES", "01M.MES", 83522, "k-talk-30")
        rows = builder.build_rows(site_data, pair_offsets)
        self.assertEqual(list(rows), ["ai.town.station.talk-30.1"])
        row = rows["ai.town.station.talk-30.1"]
        self.assertEqual((row["heroine"], row["category"], row["place"], row["number"], row["site"]),
                         ("ai", "town", "station", "talk-30", 1))
        self.assertTrue(builder.ID_RE.match(row["id"]))
        self.assertEqual(row["evidence"]["callee"], "K_TALK30.MES")
        site_data, pair_offsets = self._site("K_TALK00.MES", "01M.MES", 83830, "k-talk-00")
        self.assertEqual(list(builder.build_rows(site_data, pair_offsets)), ["ai.town.station.talk-00.1"])

    def test_the_plain_script_is_numbered_plain_at_its_own_caller(self):
        site_data, pair_offsets = self._site("K_TALK.MES", "27C_EV.MES", 31343, "k-talk-plain")
        self.assertEqual(list(builder.build_rows(site_data, pair_offsets)), ["ai.town.27c_ev.talk-plain.1"])

    def test_a_route_id_that_names_another_script_or_heroine_stops_the_tool(self):
        for callee, route_id in (("K_TALK30.MES", "k-talk-40"), ("K_TALK30.MES", "a-talk-30"),
                                 ("K_TALK30.MES", "k-talk-plain"), ("K_TALK.MES", "k-talk-30")):
            site_data, pair_offsets = self._site(callee, "01M.MES", 83522, route_id)
            with self.assertRaises(builder.BuildError, msg=(callee, route_id)):
                builder.build_rows(site_data, pair_offsets)

    def test_a_talk_script_without_a_flow_route_stops_the_tool(self):
        site_data, pair_offsets = self._site("K_TALK30.MES", "01M.MES", 83522, "")
        with self.assertRaises(builder.BuildError):
            builder.build_rows(site_data, pair_offsets)

    def test_tinas_script_and_the_characters_scripts_are_talk_rows(self):
        # EP-12 TALK (2026-10-05): `M_TALK` is Tina's (a heroine key: `tina.town.station.talk-plain.1`);
        # the characters N..Q have no heroine key, the row is `common...talk-<letter><digit>`.
        for callee, caller, offset, route_id, expected in (
                ("M_TALK.MES", "01M.MES", 47934, "m-talk-plain", "tina.town.station.talk-plain.1"),
                ("N_TALK.MES", "27C_EV.MES", 1678, "n-talk-plain", "common.town.27c_ev.talk-n.1"),
                ("N_TALK1.MES", "27C_EV.MES", 82509, "n-talk-1", "common.town.27c_ev.talk-n1.1"),
                ("N_TALK3.MES", "11M.MES", 35558, "n-talk-3", "common.town.11m.talk-n3.1"),
                ("Q_TALK1.MES", "27C_EV.MES", 37984, "q-talk-1", "common.town.27c_ev.talk-q1.1"),
                ("Q_TALK.MES", "01M.MES", 48530, "q-talk-plain", "common.town.station.talk-q.1")):
            site_data, pair_offsets = self._site(callee, caller, offset, route_id)
            rows = builder.build_rows(site_data, pair_offsets)
            self.assertEqual(list(rows), [expected], callee)
            self.assertTrue(builder.ID_RE.match(expected), expected)
            self.assertEqual(rows[expected]["heroine"], expected.split(".")[0])
        for callee, route_id in (("N_TALK1.MES", "n-talk-plain"), ("N_TALK.MES", "n-talk-1"), ("O_TALK.MES", "p-talk-plain"),
                                 ("M_TALK.MES", "m-talk-1"), ("Q_TALK1.MES", "q-talk-plain")):
            site_data, pair_offsets = self._site(callee, "27C_EV.MES", 100, route_id)
            with self.assertRaises(builder.BuildError, msg=(callee, route_id)):
                builder.build_rows(site_data, pair_offsets)

    def test_the_follow_on_and_other_stems_are_not_talk_scripts(self):
        for stem in ("K_TALKXX", "K_TALK3", "N_TALK12", "R_TALK", "M_TALK30", "EVENTK01"):
            self.assertIsNone(builder.TALK_STEM.match(stem), stem)
        for stem, expected in (("K_TALK30", ("K", "30")), ("K_TALK", ("K", "")), ("M_TALK", ("M", "")),
                               ("N_TALK", ("N", "")), ("N_TALK2", ("N", "2")), ("Q_TALK1", ("Q", "1"))):
            self.assertEqual(talk_script_parts(stem), expected, stem)
        self.assertEqual(builder.heroine_letter_and_number("K_TALK30"), ("K", "talk30", False))


if __name__ == "__main__":
    unittest.main()
