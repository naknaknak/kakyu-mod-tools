"""Guards the tracked event definitions under config/event_definitions/v3
and config/event_definitions/v4 (WD-22; v4 added by event definition v4
unit 2b).

Every tracked document must validate against its own contract under the
recorded fingerprints, carry no dialogue text (only `text_ref`s), and agree
with the index the batch driver wrote; the index must name the recorded
contract and registry fingerprints. The documents were placed here by the
owner's decision of 2026-09-16 (v3) and by unit 2b (v4); the resolved twins
with text are local. v3's own checks and behaviour are unchanged by this
file's v4 addition - `TrackedEventDefinitionsTest` (v3) is the same class
it always was, parametrized only for readability.
"""
from __future__ import annotations

import collections
import json
import re
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from tools.contract_fingerprint import stored  # noqa: E402
from tools.validate_event_definition import validate  # noqa: E402

NAMES_DIR = ROOT / "config" / "contracts" / "event_names_v1"
# Japanese and full-width ranges: original dialogue would show up as these.
NON_LATIN = re.compile(r"[぀-ヿ㐀-鿿＀-￯]")


def _documents(tracked_dir: Path) -> dict[str, dict]:
    documents = {}
    for path in sorted(tracked_dir.glob("*.json")):
        if path.name == "index.json":
            continue
        documents[path.stem] = json.loads(path.read_text(encoding="utf-8"))
    return documents


def _names_registry() -> dict:
    registry = json.loads((NAMES_DIR / "event_names.json").read_text(encoding="utf-8"))
    rows = registry["rows"]
    ids = {row["id"] if isinstance(row, dict) and "id" in row else key for key, row in rows.items()}
    return {"fingerprint": (NAMES_DIR / "names_fingerprint").read_text(encoding="utf-8").strip(), "ids": ids}


# EP-12 SCENE (2026-10-04): the album scenes of the 13 `<name>_m` menus, one
# registry site each (`<heroine>.special.<menu>_m.<number>.1`, the H slots
# `h01`..`h09`), and how many each menu holds (365 in all; the drafter's
# `scenes` count per menu in `docs/spec/mes/gallery_families.md`, "Declared").
ALBUM_SCENES_PER_MENU = {
    "miko_m": 30, "mahoko_m": 26, "nana_m": 30, "maki_m": 28, "mizuho_m": 33, "reiko_m": 30, "ryoko_m": 26,
    "miyuki_m": 30, "mayumi_m": 33, "minatu_m": 25, "ai_m": 25, "sizuka_m": 33, "tina_m": 16,
}
ALBUM_SITE = re.compile(r"^[a-z]+\.special\.([a-z]+_m)\.(?:h\d+|\d+)\.1$")


def _album_scene_sites() -> list[str]:
    return sorted(site for site in _names_registry()["ids"] if ALBUM_SITE.match(site))


# EP-12 H (2026-10-04): the 13 recollection ladders the protagonist's room calls,
# one registry site each (`<name>.town.43c.h.1`), each a two-hop flow (the room
# to the ladder's call, then the ladder to its own return).
RECOLLECTION_SITE = re.compile(r"^[a-z]+\.town\.43c\.h\.1$")


def _recollection_sites() -> list[str]:
    return sorted(site for site in _names_registry()["ids"] if RECOLLECTION_SITE.match(site))


# EP-12 TALK (2026-10-04 heroine K, 2026-10-05 the rest): the conversation scripts, one registry site
# each, derived from the registry like the album and recollection sites. A heroine's eight rung scripts
# are `<name>.town.station.talk-<band>.1` (three hops: the `01M.MES` ladder block to the call, the
# script to its return, the caller resuming to the town handoff); the band-less scripts (a heroine's
# plain one, Tina's, the characters N..Q's) are `<name-or-common>.town.<caller>.talk-<plain or letter>.1`
# at the caller that anchors them (two hops where the caller resumes into a day loop; three where it
# reaches a handoff, `THREE_HOP_BAND_LESS_TALK_SITES`).
TALK_SITE = re.compile(r"^[a-z]+\.town\.[a-z0-9_]+\.talk-[a-z0-9]+\.1$")
LADDER_TALK_SITE = re.compile(r"^([a-z]+)\.town\.station\.talk-(\d\d)\.1$")
TALK_BANDS = ("30", "40", "50", "60", "70", "80", "90", "00")
# Tina's `M_TALK` and `Q_TALK` are the band-less scripts whose caller (`01M.MES`) reaches the `MACHI.MES`
# handoff, so their routes keep the third hop, and `N_TALK1` (EP-12 TALK follow-ups, 2026-10-05: its
# `27C_EV.MES` block is the entry's last, the caller reaches the `FLOOR5.MES` handoff); every other
# band-less route ends at the script's own return.
THREE_HOP_BAND_LESS_TALK_SITES: set[str] = {"tina.town.station.talk-plain.1", "common.town.station.talk-q.1",
                                            "common.town.27c_ev.talk-n1.1"}
# EP-12 TALK rest (2026-10-05): the 114 declared scripts - a heroine's eight rungs at `01M.MES`, the nine
# plain scripts and the eight Tina/character scripts at their anchors.
TALK_HEROINES = ("miko", "mahoko", "nana", "maki", "mizuho", "reiko", "ryoko", "miyuki", "mayumi", "minatu", "ai", "sizuka")
TALK_PLAIN_HEROINES = ("miko", "nana", "mizuho", "reiko", "ryoko", "miyuki", "mayumi", "ai", "sizuka")
TALK_BAND_LESS_OTHERS = (
    "tina.town.station.talk-plain.1", "common.town.27c_ev.talk-n.1", "common.town.27c_ev.talk-n1.1",
    "common.town.11m.talk-n2.1", "common.town.11m.talk-n3.1", "common.town.27c_ev.talk-o.1",
    "common.town.27c_ev.talk-p.1", "common.town.station.talk-q.1", "common.town.27c_ev.talk-q1.1")


def _talk_sites() -> list[str]:
    return sorted(site for site in _names_registry()["ids"] if TALK_SITE.match(site))


def _talk_hop_count(site: str) -> int:
    return 3 if LADDER_TALK_SITE.match(site) or site in THREE_HOP_BAND_LESS_TALK_SITES else 2


def _walk_strings(value, path=""):
    if isinstance(value, dict):
        for key, item in value.items():
            yield from _walk_strings(item, f"{path}.{key}")
    elif isinstance(value, list):
        for index, item in enumerate(value):
            yield from _walk_strings(item, f"{path}[{index}]")
    elif isinstance(value, str):
        yield path, value


# TD-56 C4b (owner ruling 2026-10-11): the v7 set against the frozen v6 set, as delta classes.
#
# Until TD-56 the v7 documents equalled the v6 documents in every field but `presentation` and the
# binding hash. Core 0.377.0 makes the replays carry the persistent flags the shared library's
# ladders set (`global_u8[4000]`, `[4090]`, `[4091]` = 1) and the `global_i32` call-argument
# storage, so the definitions gain exactly these differences and nothing else:
#   1. an added `write_legacy_value` flag row in `after` (top, `flow.hops[]`, `results[*]`, `visits[]`);
#   2. an added `evidence.effect_witnesses` row, `flag_pattern`, for those cells;
#   3. an added `unresolved` line that is D11's argument-storage record, or - in a flow document,
#      whose projection never reads witnesses - a flag line "no matching shift witness (entry=1
#      final=0)" (the flows' hop clears the flags, so the three flags are net-changed 1 to 0 and
#      only a witness could decide them); or a removed `[4000]` "witness outcome 'other'" line (the
#      cell is now a flag-pattern write);
#   4. for the 13 documents whose profile TD-56 C3 re-derived: `evidence.groups[].profile_sha256`, and
#      the `after` and `effect_witnesses` rows of the cells those profiles' pins moved on
#      (`REDERIVED_CELLS`: the three flags, the routine-39 cells `global_u8[3020]`, `[3041]` to
#      `[3046]` and `state_u16[8]`), added or removed, as their regenerated witness corpus decides;
#   5. `presentation`, `schema_version`, `contract_fingerprint` and `package_binding.package_sha256`;
#   6. in any document, the selector-0 clear of a library flag as the witnesses decide it: an `after`
#      row `write global_u8[4000|4090|4091] = 0` and its `shift_witness` row (entry 1, final 0), added
#      (where the regenerated witness answers `set`, the old one `other`, and the "witness outcome
#      'other'" `unresolved` line of `[4000]` goes) or removed (where the flag-pattern write 1 replaces
#      the clear).
# Anything else is a violation; `v7_delta_violations` returns them.
LIBRARY_FLAG_INDEXES = (4000, 4090, 4091)
SUPERSEDED_BY_TD56 = frozenset({
    "minatu.town.station.04.1", "nana.town.15c.06.1", "mizuho.town.15c.11.1", "miko.town.17m.02.1",
    "nana.town.23m.17.1", "nana.town.27c1a.03.1", "tina.town.27c_ev.14.1", "reiko.school.gate.02.1",
    "ryoko.school.gate.08.1", "ai.school.gate.09.1", "miyuki.school.gate.17.1", "miyuki.date.h_date3.19.1",
    "ai.date.k_date3.15.1",
})
REDERIVED_CELLS = frozenset(
    [("global_u8", index) for index in (3020, 3041, 3042, 3043, 3044, 3045, 3046) + LIBRARY_FLAG_INDEXES]
    + [("state_u16", 8)])
ARGUMENT_STORAGE_LINE = re.compile(
    r"^argument storage: global_i32\[\d+\] = -?\d+ written by command 0x09 at [A-Z0-9_.]+:\d+; "
    r"not an event effect \(TD-56 D11\)$")
FLOW_FLAG_LINE = re.compile(
    r"^effect on global_u8\[(4000|4090|4091)\] for result \S+: no matching shift witness \(entry=1 final=0\)$")
RETIRED_FLAG_LINE = re.compile(r"^effect on global_u8\[4000\] for result \S+: witness outcome 'other', not set/add$")


def _canon(row) -> str:
    return json.dumps(row, sort_keys=True)


def _is_flag_write(row) -> bool:
    return (isinstance(row, dict) and row.get("type") == "write_legacy_value" and row.get("storage") == "global_u8"
            and row.get("index") in LIBRARY_FLAG_INDEXES and row.get("value") == 1)


def _is_flag_evidence(row) -> bool:
    cell = row.get("cell") or {} if isinstance(row, dict) else {}
    return (cell.get("storage") == "global_u8" and cell.get("index") in LIBRARY_FLAG_INDEXES
            and row.get("basis") == "flag_pattern" and row.get("entry") == 0 and row.get("final") == 1)


def _is_retired_clear(row, kind) -> bool:
    """Class 6: the selector-0 clear of a library flag (`write 0` in `after`, its `shift_witness`), whichever
    way the delta goes."""
    if kind == "after":
        return (row.get("type") == "write_legacy_value" and row.get("storage") == "global_u8"
                and row.get("index") in LIBRARY_FLAG_INDEXES and row.get("value") == 0)
    cell = row.get("cell") or {}
    return (cell.get("storage") == "global_u8" and cell.get("index") in LIBRARY_FLAG_INDEXES
            and row.get("basis") == "shift_witness" and row.get("entry") == 1 and row.get("final") == 0)


def _cell_of(row, kind):
    if not isinstance(row, dict):
        return None
    if kind == "after":
        return (row.get("storage"), row.get("index"))
    cell = row.get("cell") or {}
    return (cell.get("storage"), cell.get("index"))


def _delta_kind(path):
    if path and path[-1] == "after":
        return "after"
    if path == ("evidence", "effect_witnesses"):
        return "evidence"
    if path == ("unresolved",):
        return "unresolved"
    return None


def v7_delta_violations(new: dict, old: dict, doc_id: str) -> list[str]:
    """The ways the v7 document `new` differs from its frozen v6 document `old` that no delta
    class allows (an empty list when it differs in the classes only)."""
    violations: list[str] = []
    superseded = doc_id in SUPERSEDED_BY_TD56
    is_flow = "flow" in new

    def where(path):
        return "/".join(str(part) for part in path) or "(document)"

    def set_array(a, b, path, kind):
        ca, cb = collections.Counter(map(_canon, a)), collections.Counter(map(_canon, b))
        added = list((ca - cb).elements())
        removed = list((cb - ca).elements())
        common = set(ca) & set(cb)
        if [r for r in map(_canon, a) if r in common] != [r for r in map(_canon, b) if r in common]:
            violations.append(f"{where(path)}: the rows both sets carry changed their order")
        for text in removed:
            row = json.loads(text)
            if kind == "unresolved" and isinstance(row, str) and RETIRED_FLAG_LINE.match(row):
                continue
            if kind in ("after", "evidence") and isinstance(row, dict):
                if _is_retired_clear(row, kind):
                    continue
                if superseded and _cell_of(row, kind) in REDERIVED_CELLS:
                    continue
            violations.append(f"{where(path)}: a row was removed: {text[:120]}")
        for text in added:
            row = json.loads(text)
            if kind == "after" and (_is_flag_write(row) or _is_retired_clear(row, kind)):
                continue
            if kind == "evidence" and (_is_flag_evidence(row) or _is_retired_clear(row, kind)):
                continue
            if kind == "unresolved" and isinstance(row, str) and (
                    ARGUMENT_STORAGE_LINE.match(row) or (is_flow and FLOW_FLAG_LINE.match(row))):
                continue
            if superseded and kind in ("after", "evidence") and _cell_of(row, kind) in REDERIVED_CELLS:
                continue
            violations.append(f"{where(path)}: a row was added outside the delta classes: {text[:120]}")

    def walk(a, b, path):
        if path == ("presentation",) or path in (("schema_version",), ("contract_fingerprint",), ("package_binding", "package_sha256")):
            return
        if isinstance(a, dict) and isinstance(b, dict):
            if set(a) != set(b):
                violations.append(f"{where(path)}: keys differ {sorted(set(a) ^ set(b))}")
            for key in a.keys() & b.keys():
                walk(a[key], b[key], path + (key,))
        elif isinstance(a, list) and isinstance(b, list):
            kind = _delta_kind(path)
            if kind is not None:
                set_array(a, b, path, kind)
            elif len(a) != len(b):
                violations.append(f"{where(path)}: length {len(b)} -> {len(a)}")
            else:
                for index, (x, y) in enumerate(zip(a, b)):
                    walk(x, y, path + (index,))
        elif a != b:
            if superseded and len(path) == 4 and path[:2] == ("evidence", "groups") and path[3] == "profile_sha256":
                return
            violations.append(f"{where(path)}: {str(b)[:60]!r} -> {str(a)[:60]!r}")

    walk(new, old, ())
    return violations


class TrackedEventDefinitionsTest(unittest.TestCase):
    """v3: `config/event_definitions/v3`, `kakyu_event_definition_index/v1`."""

    TRACKED_DIR = ROOT / "config" / "event_definitions" / "v3"
    FIXTURE_DIR = ROOT / "config" / "contracts" / "event_definition_v3"
    INDEX_SCHEMA = "kakyu_event_definition_index/v1"
    # v3 is frozen: its documents validate against the names fingerprint
    # they recorded (the 2026-09-15 agreement), not the live registry, whose
    # ids are unchanged but whose fingerprint moved when the 44M B14 group
    # gave its row a group alias (2026-09-19). v4 follows the live registry.
    RECORDED_NAMES_FINGERPRINT: str | None = "b7ffcea3abac019a78f8ac19e98d5259fc778a0eb3c7123424f257b435163e1a"

    @classmethod
    def setUpClass(cls) -> None:
        cls.documents = _documents(cls.TRACKED_DIR)
        cls.index = json.loads((cls.TRACKED_DIR / "index.json").read_text(encoding="utf-8"))
        cls.contract_fingerprint = stored(cls.FIXTURE_DIR)
        cls.names = _names_registry()
        if cls.RECORDED_NAMES_FINGERPRINT is not None:
            cls.names = dict(cls.names, fingerprint=cls.RECORDED_NAMES_FINGERPRINT)

    def test_directory_holds_documents_and_an_index(self) -> None:
        self.assertTrue(self.documents, "no tracked documents")
        self.assertEqual(self.index.get("schema"), self.INDEX_SCHEMA)
        self.assertFalse(list(self.TRACKED_DIR.glob("*.resolved.json")), "a resolved document (with text) is tracked")

    def test_index_records_the_recorded_fingerprints(self) -> None:
        self.assertEqual(self.index.get("contract_fingerprint"), self.contract_fingerprint)
        self.assertEqual(self.index.get("names_fingerprint"), self.names["fingerprint"])
        self.assertRegex(self.index.get("package_sha256", ""), r"^[0-9a-f]{64}$")

    def test_index_rows_match_the_files(self) -> None:
        rows = {row["id"]: row for row in self.index["documents"]}
        self.assertEqual(len(rows), len(self.index["documents"]), "duplicate ids in the index")
        for doc_id, row in rows.items():
            if row.get("ok"):
                self.assertIn(doc_id, self.documents, f"index says {doc_id} is valid but no document is tracked")
            else:
                self.assertNotIn(doc_id, self.documents, f"index says {doc_id} failed but a document is tracked")
                self.assertTrue(row.get("reason"), f"{doc_id}: failed row without a reason")
        for doc_id in self.documents:
            self.assertIn(doc_id, rows, f"{doc_id} is tracked but absent from the index")
        summary = self.index["summary"]
        self.assertEqual(summary["valid"], sum(1 for row in rows.values() if row.get("ok")))
        self.assertEqual(summary["invalid"], len(rows) - summary["valid"])
        self.assertEqual(summary["valid"], len(self.documents))

    def test_every_document_validates_under_the_recorded_fingerprints(self) -> None:
        failures = []
        for doc_id, document in self.documents.items():
            self.assertEqual(document.get("id"), doc_id, f"{doc_id}: id differs from the file name")
            verdict = validate(
                document,
                fingerprint=self.contract_fingerprint,
                names_registry=self.names,
                expected_names_fingerprint=self.names["fingerprint"],
            )
            if not verdict.get("ok"):
                failures.append((doc_id, verdict.get("reason"), verdict.get("detail")))
        self.assertEqual(failures, [], "tracked documents failing the contract")

    def test_documents_carry_references_only_never_text(self) -> None:
        offenders = []
        for doc_id, document in self.documents.items():
            for path, value in _walk_strings(document):
                key = path.rsplit(".", 1)[-1].split("[", 1)[0]
                if key in ("text", "script"):
                    offenders.append((doc_id, path, "text key"))
                elif NON_LATIN.search(value) and not path.endswith(".title_ko"):
                    offenders.append((doc_id, path, "non-Latin string"))
        self.assertEqual(offenders, [], "tracked documents must reference text, never embed it")

    def test_every_document_binds_the_indexed_package(self) -> None:
        package_sha256 = self.index["package_sha256"]
        for doc_id, document in self.documents.items():
            binding = document.get("package_binding", {})
            self.assertEqual(binding.get("package_sha256"), package_sha256, f"{doc_id}: bound to another package")


class TrackedEventDefinitionsV4Test(TrackedEventDefinitionsTest):
    """v4: `config/event_definitions/v4`, `kakyu_event_definition_index/v2`
    (event definition v4 unit 2b). Inherits every v3 check unchanged; adds
    the v2 index fields and the v4-only document shapes."""

    TRACKED_DIR = ROOT / "config" / "event_definitions" / "v4"
    FIXTURE_DIR = ROOT / "config" / "contracts" / "event_definition_v4"
    INDEX_SCHEMA = "kakyu_event_definition_index/v2"
    RECORDED_NAMES_FINGERPRINT = None

    def test_index_records_the_cells_fingerprint(self) -> None:
        cells_fingerprint_path = ROOT / "config" / "contracts" / "state_cells_v1" / "cells_fingerprint"
        expected = cells_fingerprint_path.read_text(encoding="utf-8").strip()
        self.assertEqual(self.index.get("cells_fingerprint"), expected)

    def test_index_rows_carry_the_v4_counts(self) -> None:
        for row in self.index["documents"]:
            if not row.get("ok"):
                continue
            for key in (
                "effect_rows_by_type", "effect_rows_by_basis", "effect_rows_declared_false",
                "location_lines", "choice_points", "scene_ends", "order_hint",
                "order_hint_chain_confirmed", "done_cell_source",
            ):
                self.assertIn(key, row, f"{row['id']}: index row missing {key!r}")

    def test_a_document_with_an_order_hint_only_when_its_guard_is_typed(self) -> None:
        for doc_id, document in self.documents.items():
            order_hint = (document.get("trigger") or {}).get("order_hint")
            if order_hint is not None:
                self.assertIsNotNone(document.get("guard"), f"{doc_id}: order_hint without a typed guard")

    def test_a_played_result_has_at_most_one_scene_end(self) -> None:
        # The validator's own _check_flow_v4 already enforces this per
        # document at validation time (test_every_document_validates_...);
        # this test re-affirms it directly over the dialogue trees so the
        # rule is visible from this file too.
        def count_scene_ends(entries):
            return sum(1 for e in entries if isinstance(e, dict) and e.get("kind") == "scene_end")

        def walk(results, prefix_count):
            for result in (results or {}).values():
                own = count_scene_ends(result.get("dialogue") or [])
                self.assertLessEqual(prefix_count + own, 1)
                walk(result.get("results"), prefix_count + own)

        for doc_id, document in self.documents.items():
            body_count = count_scene_ends(document.get("dialogue") or [])
            walk(document.get("results"), body_count)


class TrackedEventDefinitionsV5Test(TrackedEventDefinitionsV4Test):
    """v5 (WD-23): `config/event_definitions/v5`, still
    `kakyu_event_definition_index/v2` (v5 adds no new index field - a
    document's own `visits` count is visible in the document, not indexed).
    Inherits every v3/v4 check unchanged; adds the exactly-two-sites rule
    for `visits`."""

    TRACKED_DIR = ROOT / "config" / "event_definitions" / "v5"
    FIXTURE_DIR = ROOT / "config" / "contracts" / "event_definition_v5"
    RECORDED_NAMES_FINGERPRINT = None

    VISIT_SITE_IDS = {"tina.town.44c.10.2", "tina.town.44c.03.1"}

    def test_only_the_two_declared_sites_carry_visits(self) -> None:
        for doc_id, document in self.documents.items():
            visits = document.get("visits")
            if doc_id in self.VISIT_SITE_IDS:
                self.assertTrue(visits, f"{doc_id}: expected a declared visits chain")
            else:
                self.assertFalse(visits, f"{doc_id}: unexpected visits (only the two WD-23 sites declare them)")

    def test_visit_chains_are_well_formed(self) -> None:
        for doc_id in self.VISIT_SITE_IDS:
            document = self.documents.get(doc_id)
            if document is None:
                continue
            visits = document["visits"]
            ids_seen: set[str] = set()
            repeats_seen = False
            for visit in visits:
                follows = visit["follows"]
                self.assertTrue(
                    follows in ("reentry", "first") or follows in ids_seen,
                    f"{doc_id}: visit {visit['visit_id']!r} follows {follows!r} before it is declared",
                )
                ids_seen.add(visit["visit_id"])
                self.assertTrue(visit["select"], f"{doc_id}: visit {visit['visit_id']!r} has an empty select")
                scene_ends = sum(1 for e in visit["dialogue"] if e.get("kind") == "scene_end")
                self.assertEqual(scene_ends, 1, f"{doc_id}: visit {visit['visit_id']!r} scene_end count")
                if visit["repeats"]:
                    self.assertFalse(repeats_seen, f"{doc_id}: more than one repeats: true")
                    repeats_seen = True
            self.assertTrue(repeats_seen, f"{doc_id}: no visit carries repeats: true")


class TrackedEventDefinitionsV6Test(TrackedEventDefinitionsV5Test):
    """v6 (EP-12 / WD unit 2, 2026-09-25): `config/event_definitions/v6`,
    still `kakyu_event_definition_index/v2`. Inherits every v3/v4/v5 check
    unchanged (including the two WD-23 visit sites, carried through
    unmodified); adds the three `01m-a-date` flow documents' own `flow`
    block."""

    TRACKED_DIR = ROOT / "config" / "event_definitions" / "v6"
    FIXTURE_DIR = ROOT / "config" / "contracts" / "event_definition_v6"
    RECORDED_NAMES_FINGERPRINT = None

    # Measured (not assumed) from the tracked documents themselves: each
    # flow id's own `flow.hops` length, from its own v14 profile
    # (`config/event_catalog/analysis_groups/01m_<letter>_date_v14.json`)'s
    # own routes. A and B declare all three routes each; the C..L batch
    # (2026-09-25) left one route out for D (hotel), J (hotel) and L
    # (date5) where it could not be measured generically - see
    # docs/spec/mes/heroine_date_flows.md's "Departures" sections.
    FLOW_SITE_HOP_COUNTS = {
        "miko.town.station.date-town.1": 23,
        "miko.town.station.date-date5.1": 21,
        "miko.town.station.date-hotel.1": 23,
        "mahoko.town.station.date-town.1": 23,
        "mahoko.town.station.date-date5.1": 21,
        "mahoko.town.station.date-hotel.1": 23,
        "nana.town.station.date-town.1": 23,
        "nana.town.station.date-date5.1": 21,
        "nana.town.station.date-hotel.1": 23,
        "maki.town.station.date-town.1": 23,
        "maki.town.station.date-date5.1": 21,
        "maki.town.station.date-hotel.1": 23,
        "mizuho.town.station.date-town.1": 23,
        "mizuho.town.station.date-date5.1": 21,
        "mizuho.town.station.date-hotel.1": 23,
        "reiko.town.station.date-town.1": 23,
        "reiko.town.station.date-date5.1": 21,
        "reiko.town.station.date-hotel.1": 23,
        "ryoko.town.station.date-town.1": 23,
        "ryoko.town.station.date-date5.1": 21,
        "ryoko.town.station.date-hotel.1": 23,
        "miyuki.town.station.date-town.1": 23,
        "miyuki.town.station.date-date5.1": 21,
        "miyuki.town.station.date-hotel.1": 23,
        "mayumi.town.station.date-town.1": 23,
        "mayumi.town.station.date-date5.1": 21,
        "mayumi.town.station.date-hotel.1": 23,
        "minatu.town.station.date-town.1": 23,
        "minatu.town.station.date-date5.1": 21,
        "ai.town.station.date-town.1": 23,
        "ai.town.station.date-date5.1": 21,
        "ai.town.station.date-hotel.1": 23,
        "sizuka.town.station.date-town.1": 23,
        "sizuka.town.station.date-date5.1": 21,
        "sizuka.town.station.date-hotel.1": 23,
        # EP-12 SCENE (2026-10-04): every album scene (365, heroine J's 25 since
        # the J unit, the other twelve menus since the all-menus unit) is a
        # two-hop flow - the menu, then the scene to its own return.
        **{site: 2 for site in _album_scene_sites()},
        # EP-12 H (2026-10-04): the 13 recollection ladders of the room.
        **{site: 2 for site in _recollection_sites()},
        # EP-12 TALK (2026-10-04, 2026-10-05): the three-hop rungs and the (mostly) two-hop band-less scripts.
        **{site: _talk_hop_count(site) for site in _talk_sites()},
    }

    def test_the_album_scenes_are_declared_per_menu(self) -> None:
        per_menu: dict = {}
        for site in _album_scene_sites():
            menu = ALBUM_SITE.match(site).group(1)
            per_menu[menu] = per_menu.get(menu, 0) + 1
        self.assertEqual(per_menu, ALBUM_SCENES_PER_MENU)
        self.assertEqual(sum(per_menu.values()), 365)

    def test_the_recollection_ladders_are_the_thirteen_heroines_of_the_room(self) -> None:
        sites = _recollection_sites()
        self.assertEqual(len(sites), 13)
        self.assertEqual({site.split(".")[0] for site in sites},
                         {"miko", "mahoko", "nana", "maki", "mizuho", "reiko", "ryoko", "miyuki", "mayumi", "minatu",
                          "ai", "sizuka", "tina"})

    def test_every_heroine_with_talk_rows_has_a_complete_ladder(self) -> None:
        ladders: dict = {}
        for site in _talk_sites():
            match = LADDER_TALK_SITE.match(site)
            if match:
                ladders.setdefault(match.group(1), []).append(match.group(2))
        self.assertTrue(ladders, "no TALK ladder row in the registry")
        for heroine, bands in ladders.items():
            self.assertEqual(sorted(bands, key=TALK_BANDS.index), list(TALK_BANDS), heroine)

    def test_the_talk_sites_are_the_114_declared_scripts(self) -> None:
        expected = sorted(
            [f"{name}.town.station.talk-{band}.1" for name in TALK_HEROINES for band in TALK_BANDS]
            + [f"{name}.town.27c_ev.talk-plain.1" for name in TALK_PLAIN_HEROINES]
            + list(TALK_BAND_LESS_OTHERS))
        self.assertEqual(len(expected), 114)
        self.assertEqual(_talk_sites(), expected)
        for site in expected:
            self.assertIn(site, self.documents, site)

    def test_a_talk_documents_dependencies_are_the_entries_its_route_runs(self) -> None:
        # The group declares every rung script of the heroine as a member; a rung's document lists
        # only what its own route runs (`docs/spec/data/event_definition_v6.md`, "TALK flows"): never
        # another rung script (`<L>_TALK30` .. `<L>_TALK00`; a follow-on a rung calls - `K_TALKXX`,
        # `A_TALK51` - is a dependency of the rungs that call it), its own callee being a hop entry,
        # excluded as for every flow. Heroine K's rungs 50..00 depend on `K_TALKXX.MES`.
        for site in _talk_sites():
            dependencies = {d["entry"] for d in self.documents[site]["dependencies"]}
            self.assertFalse(any(re.match(r"^[A-L]_TALK(?:[3-9]0|00)\.MES$", entry) for entry in dependencies), site)
            self.assertFalse(any(re.match(r"^[A-Q]_TALK\d?\.MES$", entry) for entry in dependencies), site)
            match = LADDER_TALK_SITE.match(site)
            if match and match.group(1) == "ai":
                self.assertIn("K_PIC.MES", dependencies, site)
                self.assertEqual("K_TALKXX.MES" in dependencies, match.group(2) in ("50", "60", "70", "80", "90", "00"), site)

    def test_only_the_flow_sites_carry_flow(self) -> None:
        for doc_id, document in self.documents.items():
            flow = document.get("flow")
            if doc_id in self.FLOW_SITE_HOP_COUNTS:
                self.assertIsNotNone(flow, f"{doc_id}: expected a flow block")
            else:
                self.assertIsNone(flow, f"{doc_id}: unexpected flow (only the FLOW_SITE_HOP_COUNTS sites declare it)")

    def test_flow_documents_carry_the_measured_hop_counts(self) -> None:
        for doc_id, expected_hops in self.FLOW_SITE_HOP_COUNTS.items():
            document = self.documents.get(doc_id)
            self.assertIsNotNone(document, f"{doc_id}: not tracked")
            hops = document["flow"]["hops"]
            self.assertEqual(len(hops), expected_hops, f"{doc_id}: hop count")
            seen_ids: set[str] = set()
            for i, hop in enumerate(hops):
                self.assertNotIn(hop["hop_id"], seen_ids, f"{doc_id}: duplicate hop_id {hop['hop_id']!r}")
                seen_ids.add(hop["hop_id"])
                self.assertEqual(
                    hop["entered_by"]["kind"] == "origin", i == 0,
                    f"{doc_id}: hop[{i}] entered_by.kind == 'origin' iff it is the first hop",
                )

    def test_flow_documents_carry_no_visits(self) -> None:
        for doc_id in self.FLOW_SITE_HOP_COUNTS:
            document = self.documents.get(doc_id)
            self.assertFalse(document.get("visits"), f"{doc_id}: a flow document must not also carry visits")

    # TD-37 (2026-10-03): a regeneration without the witness corpus once
    # dropped every witness-derived row from this set without a trace
    # (`shift_witness` 1,251 -> 0 and `reentry_probe` 34 -> 0 between
    # `97382f2` and `f9a2454`). The corpus is untracked, so the committed
    # documents themselves are what is guarded: the floors are the counts
    # `97382f2` carried, every one of which the TD-37 re-projection
    # reproduced (`config/event_definitions/v6/README.md`). Per-site coverage
    # is not asserted - some sites' witness results are all `other` or
    # `path_changes`, and the requests are untracked.
    MIN_SHIFT_WITNESS_ROWS = 1251
    MIN_REENTRY_PROBE_DOCUMENTS = 34

    def test_the_witness_derived_rows_are_present(self) -> None:
        shift_witness = 0
        reentry_probe = 0
        for document in self.documents.values():
            for entry in (document.get("evidence") or {}).get("effect_witnesses") or []:
                if entry.get("basis") == "shift_witness":
                    shift_witness += 1
            for condition in document.get("conditions") or []:
                if condition.get("type") == "event_not_completed" and condition.get("source") == "reentry_probe":
                    reentry_probe += 1
        self.assertGreaterEqual(
            shift_witness, self.MIN_SHIFT_WITNESS_ROWS,
            "the set lost its shift_witness rows (a projection without the witness corpus?)")
        self.assertGreaterEqual(
            reentry_probe, self.MIN_REENTRY_PROBE_DOCUMENTS,
            "the set lost its reentry_probe done cells (a projection without the witness corpus?)")
        # The index records the same totals (its derived v2 fields).
        index_shift = sum((row.get("effect_rows_by_basis") or {}).get("shift_witness", 0)
                          for row in self.index["documents"])
        index_probe = sum(1 for row in self.index["documents"] if row.get("done_cell_source") == "reentry_probe")
        self.assertEqual(index_shift, shift_witness)
        self.assertEqual(index_probe, reentry_probe)


class TrackedEventDefinitionsV7Test(TrackedEventDefinitionsV6Test):
    """v7 (WD-21 U2 C4, 2026-10-08): `config/event_definitions/v7`, still
    `kakyu_event_definition_index/v2`. Inherits every v3-v6 check (the embedded-dialogue
    guard included: a resource item carries a package entry, an offset, a kind and an
    upper-case ASCII name, never text) and adds the v7 ones: the field v7 fills, the library
    items TD-56 restored, and that the set is the frozen v6 set outside `presentation` except
    for the delta classes of `v7_delta_violations` (TD-56 C4b). It was produced against
    `b638bd7d...`, rebound by WD-21 U2 C6 to the revision-41 package `874f53ca...`, by TD-57 C4 to
    the Core 0.374.0 export `5ae6aabe...`, by TD-64 C4 to the Core 0.375.0 export `ede69366...` and
    by TD-64 part 2 C4 to the Core 0.376.0 export `47b1ee8d...`, and re-projected by TD-56 C4b
    against the Core 0.377.0 export `3af3779f...` (catalog revision 42), where the Core change
    does move runs, rebound by TD-56 C5 to the revision-43 export `0e47e063...` (`--pair
    catalog-revision`), and rebound by EP-14 C4 to the Core 0.378.0 export `fe9bb6bd...` (`--pair
    core-version`: the timeline change cannot move a run, proved by 227 of 227 byte-identical replays)."""

    TRACKED_DIR = ROOT / "config" / "event_definitions" / "v7"
    FIXTURE_DIR = ROOT / "config" / "contracts" / "event_definition_v7"
    RECORDED_NAMES_FINGERPRINT = None
    V6_DIR = ROOT / "config" / "event_definitions" / "v6"

    def test_every_document_is_v7_and_fills_the_presentation_field(self) -> None:
        for doc_id, document in self.documents.items():
            self.assertEqual(document["schema_version"], "kakyu_event_definition/v7", doc_id)
            presentation = document["presentation"]
            self.assertEqual(list(presentation.keys()), ["status", "resources"], doc_id)
            self.assertEqual(presentation["status"], "deferred", doc_id)
            # Measured 2026-10-08: every one of the 681 routes reaches at least one medium.
            self.assertTrue(presentation["resources"], f"{doc_id}: an empty resources list (the projection lost its replays?)")

    # TD-56 C4b (2026-10-11): the floors the restored library items carry (counts measured by the
    # projection; the corpus is untracked, so the committed lists are what is guarded).
    MIN_DISTINCT_LIBRARY_ITEMS = 251
    MIN_DOCUMENTS_WITH_LIBRARY_ITEMS = 293

    def test_the_library_items_are_listed_and_are_library_occurrences(self) -> None:
        """TD-56 (Core 0.377.0) models the feed of command `0x09` into `global_i32`, so the shared
        library's ladders select by the caller's real selector and the measured routes reach their
        real arms: the `LIBLARY.LIB` items the owner's ruling of 2026-10-08 held back are listed,
        beside the `DEF_MAIN.MES` ones. Without the package only what the lists themselves carry can
        be checked here (the validator, run against the bound package, confirms each item is an
        occurrence of its inventory): the items exist; one library coordinate carries each name under
        one kind, so a `DEF_MAIN.MES`-relative offset under the library's name (TD-55) would show as
        one name under two kinds; and the sound-effect kind, absent while the library was left out,
        is present."""
        classes_at = {}
        library_items = set()
        definition_items = set()
        documents_with_library = 0
        for document in self.documents.values():
            listed = False
            for item in document["presentation"]["resources"]:
                if item["entry"] == "LIBLARY.LIB":
                    listed = True
                    library_items.add((item["source_offset"], item["kind"], item["name"]))
                    classes_at.setdefault(item["source_offset"], set()).add((item["kind"], item["name"]))
                elif item["entry"] == "DEF_MAIN.MES":
                    definition_items.add((item["source_offset"], item["kind"], item["name"]))
            documents_with_library += 1 if listed else 0
        self.assertGreaterEqual(len(library_items), self.MIN_DISTINCT_LIBRARY_ITEMS)
        self.assertGreaterEqual(documents_with_library, self.MIN_DOCUMENTS_WITH_LIBRARY_ITEMS)
        self.assertTrue(definition_items, "no DEF_MAIN.MES item in the whole set")
        for at, classes in classes_at.items():
            names = [name for _kind, name in classes]
            self.assertEqual(len(names), len(set(names)), f"LIBLARY.LIB:{at}: one name under two kinds")
        kinds = {kind for _at, kind, _name in library_items}
        self.assertTrue({"se", "mmo"} <= kinds, f"the library kinds are {sorted(kinds)}")

    def test_the_set_is_the_v6_set_outside_the_presentation_field_but_for_the_delta_classes(self) -> None:
        """WD-21 U2 D7 held v7 equal to v6 outside `presentation`, `schema_version`,
        `contract_fingerprint` and `package_binding.package_sha256`; TD-56 C4b (owner ruling
        2026-10-11) re-projected the set against the Core 0.377.0 export, whose replays carry the
        library-set flags and the call-argument storage. Each document may now differ from its frozen
        v6 document only in the classes `v7_delta_violations` documents; the rest of
        `package_binding` is still compared."""
        v6 = _documents(self.V6_DIR)
        self.assertEqual(sorted(v6), sorted(self.documents))
        failures = []
        for doc_id, document in self.documents.items():
            self.assertEqual(v6[doc_id]["presentation"], {"status": "deferred", "resources": []}, doc_id)
            failures.extend(f"{doc_id}: {text}" for text in v7_delta_violations(document, v6[doc_id], doc_id))
        self.assertEqual(failures, [], "documents differ from v6 outside the delta classes")

    def test_the_thirteen_re_derived_profiles_are_the_documents_whose_group_hash_moved(self) -> None:
        """TD-56 C3 re-derived 13 analysis-group profiles; the documents projected from them are
        exactly `SUPERSEDED_BY_TD56`, the only ones whose `evidence.groups[].profile_sha256` differs from
        v6's (the exception list cannot go stale in either direction)."""
        v6 = _documents(self.V6_DIR)
        moved = set()
        for doc_id, document in self.documents.items():
            new_hashes = [group["profile_sha256"] for group in document["evidence"]["groups"]]
            old_hashes = [group["profile_sha256"] for group in v6[doc_id]["evidence"]["groups"]]
            if new_hashes != old_hashes:
                moved.add(doc_id)
        self.assertEqual(moved, set(SUPERSEDED_BY_TD56))


class DeltaClassWalkerTest(unittest.TestCase):
    """`v7_delta_violations` on small invented documents: every class passes and anything else fails."""

    @staticmethod
    def doc(**fields):
        base = {
            "schema_version": "kakyu_event_definition/v6", "contract_fingerprint": "x", "id": "a.b.1",
            "package_binding": {"package_sha256": "h1", "schema": "s"},
            "presentation": {"status": "deferred", "resources": []},
            "evidence": {"groups": [{"group_id": "g", "profile_sha256": "p1"}], "effect_witnesses": []},
            "after": [], "unresolved": ["old line"], "results": {"body": {"after": []}},
        }
        base.update(fields)
        return base

    def new(self, **fields):
        document = self.doc(**fields)
        document["schema_version"] = "kakyu_event_definition/v7"
        if "package_binding" not in fields:
            document["package_binding"] = {"package_sha256": "h2", "schema": "s"}
        document["presentation"] = {"status": "deferred", "resources": [{"entry": "LIBLARY.LIB"}]}
        return document

    FLAG = {"type": "write_legacy_value", "storage": "global_u8", "bank": 0, "index": 4090, "value": 1, "cell_class": "flag"}
    EVIDENCE = {"result": "body", "cell": {"storage": "global_u8", "bank": 0, "index": 4090}, "basis": "flag_pattern",
                "entry": 0, "final": 1, "declared": False}
    D11 = "argument storage: global_i32[1] = 67616 written by command 0x09 at GROUND.MES:6610; not an event effect (TD-56 D11)"

    def test_the_fifth_class_alone_passes(self) -> None:
        self.assertEqual(v7_delta_violations(self.new(), self.doc(), "a.b.1"), [])

    def test_a_flag_write_and_its_evidence_pass_anywhere_after_appears(self) -> None:
        new = self.new(after=[self.FLAG], results={"body": {"after": [self.FLAG]}},
                       evidence={"groups": [{"group_id": "g", "profile_sha256": "p1"}], "effect_witnesses": [self.EVIDENCE]})
        self.assertEqual(v7_delta_violations(new, self.doc(), "a.b.1"), [])

    def test_a_flow_hop_flag_write_passes(self) -> None:
        old = self.doc(flow={"hops": [{"hop_id": "h0", "after": []}]})
        new = self.new(flow={"hops": [{"hop_id": "h0", "after": [self.FLAG]}]})
        self.assertEqual(v7_delta_violations(new, old, "a.b.1"), [])

    def test_a_non_flag_or_a_changed_flag_row_fails(self) -> None:
        for row in (dict(self.FLAG, index=4001), dict(self.FLAG, value=2), dict(self.FLAG, storage="global_u16"),
                    dict(self.FLAG, type="add_legacy_value")):
            violations = v7_delta_violations(self.new(after=[row]), self.doc(), "a.b.1")
            self.assertEqual(len(violations), 1, row)
            self.assertIn("outside the delta classes", violations[0])

    def test_a_removed_row_or_a_reordered_pair_fails(self) -> None:
        other = dict(self.FLAG, index=4091)
        old = self.doc(after=[self.FLAG, other])
        self.assertTrue(v7_delta_violations(self.new(after=[self.FLAG]), old, "a.b.1"))
        self.assertTrue(v7_delta_violations(self.new(after=[other, self.FLAG]), old, "a.b.1"))

    def test_the_unresolved_classes(self) -> None:
        old = self.doc(unresolved=["old line", "effect on global_u8[4000] for result r: witness outcome 'other', not set/add"])
        new = self.new(unresolved=["old line", self.D11])
        self.assertEqual(v7_delta_violations(new, old, "a.b.1"), [])
        # a different added line, or a removed ordinary line, fails
        self.assertTrue(v7_delta_violations(self.new(unresolved=["old line", "something else"]), self.doc(), "a.b.1"))
        self.assertTrue(v7_delta_violations(self.new(unresolved=[]), self.doc(), "a.b.1"))
        # a D11 line with a changed shape fails
        self.assertTrue(v7_delta_violations(self.new(unresolved=["old line", self.D11.replace("0x09", "0x0A")]), self.doc(), "a.b.1"))

    def test_the_flow_flag_line_is_only_a_delta_in_a_flow_document(self) -> None:
        line = "effect on global_u8[4000] for result h13_dispatch_c_pic: no matching shift witness (entry=1 final=0)"
        self.assertTrue(v7_delta_violations(self.new(unresolved=["old line", line]), self.doc(), "a.b.1"))
        flow = {"hops": []}
        self.assertEqual(v7_delta_violations(self.new(unresolved=["old line", line], flow=flow), self.doc(flow=flow), "a.b.1"), [])

    def test_any_other_field_changing_fails(self) -> None:
        for key, value in (("id", "a.b.2"), ("package_binding", {"package_sha256": "h2", "schema": "other"})):
            self.assertTrue(v7_delta_violations(self.new(**{key: value}), self.doc(), "a.b.1"), key)
        changed = self.new()
        changed["evidence"]["groups"][0]["profile_sha256"] = "p2"
        self.assertTrue(v7_delta_violations(changed, self.doc(), "a.b.1"), "profile hash outside the 13")
        self.assertEqual(v7_delta_violations(changed, self.doc(), "minatu.town.station.04.1"), [])

    def test_a_re_derived_profiles_cells_may_be_replaced_in_the_thirteen_only(self) -> None:
        old_row = {"type": "write_legacy_value", "storage": "global_u8", "bank": 0, "index": 3041, "value": 1, "cell_class": "flag"}
        new_row = dict(old_row, value=6, cell_class="counter")
        old = self.doc(after=[old_row])
        new = self.new(after=[new_row])
        self.assertEqual(v7_delta_violations(new, old, "mizuho.town.15c.11.1"), [])
        self.assertEqual(len(v7_delta_violations(new, old, "a.b.1")), 2)
        other = dict(new_row, index=3100)
        self.assertTrue(v7_delta_violations(self.new(after=[other]), self.doc(after=[dict(old_row, index=3100)]), "mizuho.town.15c.11.1"))

    def test_a_selector_zero_clear_decided_by_a_witness_may_be_added_in_any_document(self) -> None:
        clear = {"type": "write_legacy_value", "storage": "global_u8", "bank": 0, "index": 4000, "value": 0, "cell_class": "counter"}
        witness = {"result": "body", "cell": {"storage": "global_u8", "bank": 0, "index": 4000}, "basis": "shift_witness",
                   "entry": 1, "final": 0, "declared": False}
        line = "effect on global_u8[4000] for result body: witness outcome 'other', not set/add"
        old = self.doc(unresolved=["old line", line])
        new = self.new(after=[clear], unresolved=["old line"],
                       evidence={"groups": [{"group_id": "g", "profile_sha256": "p1"}], "effect_witnesses": [witness]})
        self.assertEqual(v7_delta_violations(new, old, "a.b.1"), [])
        # a clear of another cell or value, or a witness row of another shape, is not that class
        for row in (dict(clear, index=4001), dict(clear, value=2)):
            self.assertTrue(v7_delta_violations(self.new(after=[row]), self.doc(), "a.b.1"), row)
        for row in (dict(witness, entry=0), dict(witness, final=1), dict(witness, basis="variants")):
            self.assertTrue(v7_delta_violations(self.new(evidence={"groups": [{"group_id": "g", "profile_sha256": "p1"}], "effect_witnesses": [row]}), self.doc(), "a.b.1"), row)

    def test_a_retired_selector_zero_clear_may_be_removed_in_any_document(self) -> None:
        clear = {"type": "write_legacy_value", "storage": "global_u8", "bank": 0, "index": 4000, "value": 0, "cell_class": "counter"}
        witness = {"result": "body", "cell": {"storage": "global_u8", "bank": 0, "index": 4000}, "basis": "shift_witness",
                   "entry": 1, "final": 0, "declared": False}
        old = self.doc(after=[clear], evidence={"groups": [{"group_id": "g", "profile_sha256": "p1"}], "effect_witnesses": [witness]})
        new = self.new(after=[self.FLAG], evidence={"groups": [{"group_id": "g", "profile_sha256": "p1"}], "effect_witnesses": [self.EVIDENCE]})
        self.assertEqual(v7_delta_violations(new, old, "a.b.1"), [])
        # a clear of another cell or another value is not the retired one
        self.assertTrue(v7_delta_violations(self.new(), self.doc(after=[dict(clear, index=4001)]), "a.b.1"))
        self.assertTrue(v7_delta_violations(self.new(), self.doc(after=[dict(clear, value=3)]), "a.b.1"))

    def test_the_thirteen_are_the_documents_the_brief_names(self) -> None:
        self.assertEqual(len(SUPERSEDED_BY_TD56), 13)


if __name__ == "__main__":
    unittest.main()
