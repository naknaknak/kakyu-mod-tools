"""Generate the shared event name registry (WD-22 part 1).

    py tools/build_event_names.py --profiles config/event_catalog/analysis_groups
        --catalog config/event_catalog/original_events_v1.json
        --out config/contracts/event_names_v1

A *site* is one callee dispatched from one place in one caller: the key is
(callee entry, caller entry, site ordinal), the ordinal being the 1-based
position of the caller's dispatch offset among the distinct offsets declared
for that (callee, caller) pair, sorted ascending. Sites are gathered from
every analysis-group profile under ``--profiles`` and from every event of the
catalog at ``--catalog``; a catalog event that coincides with a profile site
carries both aliases in the same row.

The registry is written deterministically (sorted keys, ``indent=1``,
``ensure_ascii=False``, LF line endings, trailing newline) so that running
the tool twice produces identical bytes, and a ``names_fingerprint`` is
written beside it with ``contract_fingerprint.compute``. When the output file
already exists, a row's ``title_ko``/``title_en`` are preserved across
regeneration unless they still match the provisional pattern this tool
itself generates (the owner edits titles in place).
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from contract_fingerprint import compute as fingerprint_compute
from payload_values import TALK_STEM, talk_script_parts  # noqa: F401  (TALK_STEM: the one shared pattern, re-exported)

FINGERPRINT_NAME = "names_fingerprint"

# Gallery-menu letter table (docs/spec/mes/duplicate_entries.md), heroine
# letter -> (english name, korean name).
HEROINE_TABLE = {
    "A": ("Miko", "미코"),
    "B": ("Mahoko", "마호코"),
    "C": ("Nana", "나나"),
    "D": ("Maki", "마키"),
    "E": ("Mizuho", "미즈호"),
    "F": ("Reiko", "레이코"),
    "G": ("Ryoko", "료코"),
    "H": ("Miyuki", "미유키"),
    "I": ("Mayumi", "마유미"),
    "J": ("Minatu", "미나츠"),
    "K": ("Ai", "아이"),
    "L": ("Sizuka", "시즈카"),
    "M": ("Tina", "티나"),
}

# EP-12 gallery (2026-10-04): the album menus are `<ENGLISH NAME>_M.MES`
# (MIKO_M, MINATU_M, ...); a flow route whose first dispatch is one of their
# `SCENE_*` calls is a gallery route. The id keeps the `special` category
# fall-through (`ID_RE` enumerates the category values); the row's display
# metadata, not its id, carries the `gallery` tag (`promote_analysis_groups.py`).
SCENE_PREFIX = "SCENE_"
GALLERY_MENU_STEMS = {f"{english.upper()}_M" for english, _korean in HEROINE_TABLE.values()}
GALLERY_PLACE_DISPLAY = ("the album", "앨범")

# EP-12 H (2026-10-04): the 13 `<NAME>_H.MES` recollection ladders are called
# only by `43C.MES` (the protagonist's room, answer 3 of its room-action menu;
# `docs/spec/mes/43c_caller_group.md`). Their callee stem is the heroine's
# English name, not a letter, so the heroine comes from the table in reverse;
# the number is `h` (`miko.town.43c.h.1`) and a flow route's id must spell the
# same heroine (`a-h`).
RECOLLECTION_SUFFIX = "_H"
RECOLLECTION_CALLER_STEM = "43C"
RECOLLECTION_HEROINE_BY_STEM = {f"{english.upper()}{RECOLLECTION_SUFFIX}": letter
                                for letter, (english, _korean) in HEROINE_TABLE.items()}
RECOLLECTION_NUMBER = "h"

# EP-12 TALK (2026-10-04, extended 2026-10-05): the conversation scripts
# `<letter>_TALK<band>` (the eight affection-banded rungs `30`..`90`, `00`), the
# once-only plain `<letter>_TALK`, Tina's `M_TALK` and the non-heroine characters'
# `<letter N..Q>_TALK[<digit>]` (`TALK_STEM`, shared through `payload_values.py` with
# the `is_talk_registry_row` predicate) are called from their confirmed callers
# (`01M.MES`'s ladder block, `27C_EV.MES`, ...); a heroine's (A..M) callee is numbered
# `talk-<band>` (`talk-plain` for a band-less script) by its flow route id
# `<letter>-talk-<band>`, so the row reads `ai.town.station.talk-30.1`. A character
# (N..Q) has no heroine key: the row is `common.<category>.<place>.talk-<letter><digit>`
# (`talk-n`, `talk-n1`, `talk-q1`), its route id `<letter>-talk-<digit or plain>`.
# The id regex's one hyphenated number shape already holds both.
TALK_PLAIN_BAND = "plain"
TALK_NUMBER_PREFIX = "talk-"

COMMON_HEROINE_KEY = "common"
COMMON_HEROINE_EN, COMMON_HEROINE_KO = "Common", "공통"

FLOOR_STEMS = {f"FLOOR{n}" for n in range(1, 6)}

PLACE_DISPLAY = {
    "gate": ("the school gate", "교문"),
    "entry": ("the school grounds", "교정"),
    "station": ("the station", "역"),
    "machi": ("the town", "마을"),
}
for _n in range(1, 6):
    PLACE_DISPLAY[f"floor{_n}"] = (f"school floor {_n}", f"학교 {_n}층")

DIGIT_MC_STEM = re.compile(r"^\d+[MC]")

# EP-12 catalog part (2026-09-24): the `number` segment gained one optional
# hyphenated tail (`date-town`, `date-date5`, `date-hotel`) for a v14 flow
# route's own id rule (`build_rows`'s `route_id` branch) - a flow route has
# no callee-stem suffix of its own to number by.
ID_RE = re.compile(r"^[a-z]+\.(school|town|date|special)\.[a-z0-9_]+\.[a-z0-9]+(?:-[a-z0-9]+)?\.[1-9]$")

EXPECTED_PAIR_COUNT = 646  # EP-12 TALK rest unit (2026-10-05): +105, one (<script>.MES, <caller>.MES) site per rung script of the other eleven heroines (88), their plain scripts (8), Tina's M_TALK, the characters' N_TALK, N_TALK1, N_TALK2, N_TALK3, O_TALK, P_TALK, Q_TALK and Q_TALK1; before it 541, EP-12 TALK K unit (2026-10-04): +9, one (K_TALK<band>.MES, 01M.MES) site per rung script and the plain (K_TALK.MES, 27C_EV.MES) site; before it 532, EP-12 H unit (2026-10-04): +13, one new (<NAME>_H.MES, 43C.MES) site per recollection ladder; before it 519, EP-12 SCENE all-menus: +340 (one (SCENE_*.MES, <NAME>_M.MES) site per album scene of the other twelve menus; J: +25 earlier)
EXPECTED_MULTI_SITE = {
    ("EVENTA08.MES", "21C.MES"): 2,
    ("EVENTA20.MES", "17M.MES"): 2,
    ("EVENTC12.MES", "GROUND.MES"): 2,
    ("EVENTE15.MES", "FLOOR5.MES"): 2,
    ("EVENTG01.MES", "30C.MES"): 3,
    ("EVENTH01.MES", "GROUND.MES"): 2,
    ("EVENTH02.MES", "GROUND.MES"): 2,
    ("EVENTI04.MES", "FLOOR1.MES"): 2,
    ("EVENTJ14.MES", "03C.MES"): 2,
    ("EVENTK01.MES", "GROUND.MES"): 2,
    ("EVENTM10.MES", "44C.MES"): 2,
}
EXPECTED_CATALOG_COUNT = 681  # EP-12 TALK rest unit (2026-10-05): +105 TALK rows of the other eleven heroines, Tina and the characters N..Q (105 playable); before it 576, EP-12 TALK K unit (2026-10-04): +9 TALK rows of heroine K (9 playable); before it 567, EP-12 H unit (2026-10-04): +13 recollection-ladder rows of the room (13 playable); before it 554 (EP-12 SCENE all-menus unit: +340 album-scene rows of the other twelve menus, 310 playable, 30 duplicate_route; 365 album rows in all, 33 duplicate_route)


class BuildError(RuntimeError):
    """Raised when a premise or an id rule does not hold; the tool stops."""


def stem_of(entry: str) -> str:
    return entry[:-4] if entry.lower().endswith(".mes") or entry.lower().endswith(".lib") else entry


def heroine_letter_and_number(callee_stem: str) -> tuple[str, str, bool]:
    """Returns (letter, number, is_common).

    A callee whose stem is `<ENGLISH NAME>_H` (a recollection ladder, number
    `h`), `SCENE_<letter>...` (a gallery scene),
    `EVENT<letter><suffix>` or `<letter>_<suffix>` resolves a heroine letter; if that letter is in the gallery table, the
    number is the suffix. If the shape is recognised but the letter is not
    in the table (the staged, non-heroine EVENTQ01 today), the row gets the
    `common` heroine and keeps its whole stem suffix as the number, so ids
    stay unique. Any other shape (no `EVENT` prefix and no `<letter>_`
    prefix) still stops the tool.
    """
    if callee_stem in RECOLLECTION_HEROINE_BY_STEM:
        # EP-12 H (2026-10-04): a recollection ladder, `<ENGLISH NAME>_H`.
        return RECOLLECTION_HEROINE_BY_STEM[callee_stem], RECOLLECTION_NUMBER, False
    if callee_stem.startswith(SCENE_PREFIX):
        # EP-12 gallery (2026-10-04): a gallery scene callee is
        # `SCENE_<letter><number>` (a page scene) or `SCENE_<letter>_H<nn>`
        # (an H slot). The number keeps the H marker (`h01`) so the two
        # numberings of one heroine cannot collide, and the letter is always
        # a heroine of the gallery table.
        remainder = callee_stem[len(SCENE_PREFIX):]
        if len(remainder) < 2 or not remainder[0].isalpha() or remainder[0] not in HEROINE_TABLE:
            raise BuildError(f"gallery scene stem has no heroine letter and number: {callee_stem}")
        letter = remainder[0]
        tail = remainder[2:] if remainder[1] == "_" else remainder[1:]
        if not tail or not tail.isalnum():
            raise BuildError(f"gallery scene stem has no usable number: {callee_stem}")
        return letter, tail.lower(), False
    if callee_stem.startswith("EVENT"):
        remainder = callee_stem[len("EVENT"):]
        if not remainder:
            raise BuildError(f"callee stem has no letter after EVENT: {callee_stem}")
        letter, mapped_number, whole_suffix_number = remainder[0], remainder[1:].lower(), remainder.lower()
    elif len(callee_stem) >= 2 and callee_stem[1] == "_":
        letter = callee_stem[0]
        mapped_number = callee_stem[2:].lower()
        whole_suffix_number = callee_stem.lower()
    else:
        raise BuildError(f"unexpected callee stem shape (no EVENT prefix or <letter>_ prefix): {callee_stem}")

    if letter in HEROINE_TABLE:
        return letter, mapped_number, False
    return letter, whole_suffix_number, True


def category_and_place(caller_stem: str, has_ground_gate: bool) -> tuple[str, str]:
    if caller_stem == "GROUND":
        return "school", ("gate" if has_ground_gate else "entry")
    if caller_stem in FLOOR_STEMS:
        return "school", caller_stem.lower()
    if caller_stem == "MACHI":
        return "town", "machi"
    if caller_stem == "01M":
        return "town", "station"
    if "_DATE" in caller_stem:
        return "date", caller_stem.lower()
    if DIGIT_MC_STEM.match(caller_stem):
        return "town", caller_stem.lower()
    return "special", caller_stem.lower()


def place_display(category: str, place: str) -> tuple[str, str]:
    if place in PLACE_DISPLAY:
        return PLACE_DISPLAY[place]
    if category == "special" and place.upper() in GALLERY_MENU_STEMS:
        return GALLERY_PLACE_DISPLAY
    return place, place


def scene_kind_for_contract(entry: str, locations: list) -> str | None:
    if entry == "TRAIN.MES":
        return "train_ride"
    if entry == "GROUND.MES":
        return "school_gate" if 0 in locations else None
    if entry in FLOOR_STEMS_MES:
        return "school_floor"
    if entry == "MACHI.MES":
        return "town"
    return None


FLOOR_STEMS_MES = {f"{stem}.MES" for stem in FLOOR_STEMS}


FLOW_SCHEMA = "kakyu_event_analysis_group/v14"


def load_profiles(profiles_dir: Path) -> list[tuple[Path, dict]]:
    out = []
    for path in sorted(profiles_dir.glob("*.json")):
        out.append((path, json.loads(path.read_text(encoding="utf-8"))))
    return out


def collect_sites(profiles_dir: Path, catalog_path: Path):
    """Returns (sites, pair_offsets, multi_site_pairs, catalog_event_count)."""
    profiles = load_profiles(profiles_dir)
    catalog = json.loads(catalog_path.read_text(encoding="utf-8"))
    # EP-10 unit 5b/c: every catalog row is now EP-10 generated (each carries
    # `analysis_group`), so every row feeds the site/alias collection below -
    # the `catalog_event_id` alias now names every registry site, not only a
    # hand-qualified one.

    # pair -> offset -> accumulated site data
    pair_offsets: dict[tuple[str, str], set[int]] = {}
    profile_pair_offsets: dict[tuple[str, str], set[int]] = {}
    # EP-12 catalog part (2026-09-24): the key gained a 4th element, the
    # route id, empty ("") for an ordinary caller/callee site and the flow's
    # own route_id for a v14 route - three v14 routes share one
    # (callee, caller, offset) triple (the flow's first dispatch) but each
    # is its own registry row, disambiguated by route_id alone.
    site_data: dict[tuple[str, str, int, str], dict] = {}

    def site_slot(callee_entry: str, caller_entry: str, offset: int, route_id: str = "") -> dict:
        key = (callee_entry, caller_entry, offset, route_id)
        return site_data.setdefault(key, {
            "groups": {},          # group_id -> set(route_id)
            "dispatch_end": None,
            "command": None,
            "contracts": [],       # list of (entry, locations)
            "catalog_event_id": None,
            "flow_route_id": route_id,
        })

    # EP-12 catalog part: command 15 is the only command that produces a
    # `script_dispatch_boundary` outcome and 14 the only one that produces a
    # `script_handoff_boundary` outcome (content_core/mes_event_runner.gd's
    # own command 0x0F/0x0E handling) - confirmed directly against the real
    # archive for 01M.MES's own dispatch at 11148 too
    # (mes_basic_block_ir_v6.decode_mes: commandId 15, sourceOffset 11148,
    # endOffset 11161, target a_pic.mes). A v14 hop's own outcome record
    # carries no `command` field (only `op`/`status`), unlike a v8/v9
    # route's `caller.command` or a catalog event's `source.caller.command`.
    flow_dispatch_command_by_status = {"script_dispatch_boundary": 15, "script_handoff_boundary": 14}

    flow_group_ids: set[str] = set()
    for path, profile in profiles:
        group_id = profile["group_id"]
        if str(profile.get("schema", "")) == FLOW_SCHEMA:
            flow_group_ids.add(group_id)
            # EP-12 catalog part (2026-09-24): a v14 flow adds one site per
            # route - the flow's first dispatch (hop0's own outcome), keyed
            # additionally by route_id since every route of this flow shares
            # that same dispatch.
            for route in profile["routes"]:
                route_id = route["route_id"]
                outcome = route["hops"][0]["expected"]["outcome"]
                caller_entry = route["origin"]["entry"]
                callee_entry = outcome["target"]
                offset = outcome["offset"]
                end = outcome["end"]
                status = str(outcome["status"])
                if status not in flow_dispatch_command_by_status:
                    raise BuildError(
                        f"unsupported flow hop0 outcome status for site naming: {status} in {path.name}"
                    )
                command = flow_dispatch_command_by_status[status]
                pair_offsets.setdefault((callee_entry, caller_entry), set()).add(offset)
                profile_pair_offsets.setdefault((callee_entry, caller_entry), set()).add(offset)
                slot = site_slot(callee_entry, caller_entry, offset, route_id)
                slot["groups"].setdefault(group_id, set()).add(route_id)
                slot["dispatch_end"] = end
                slot["command"] = command
                for hop in route["hops"]:
                    for contract in hop.get("map_locations") or []:
                        entry = contract["source_identity"]["entry"]
                        locations = contract["locations"]
                        slot["contracts"].append((entry, tuple(locations)))
            continue
        for route in profile["routes"]:
            caller_entry = route["caller"]["entry"]
            callee_entry = route["callee"]["entry"]
            offset = route["caller"]["offset"]
            pair_offsets.setdefault((callee_entry, caller_entry), set()).add(offset)
            profile_pair_offsets.setdefault((callee_entry, caller_entry), set()).add(offset)
            slot = site_slot(callee_entry, caller_entry, offset)
            slot["groups"].setdefault(group_id, set()).add(route["route_id"])
            end = route["caller"]["end"]
            command = route["caller"]["command"]
            if slot["dispatch_end"] is None:
                slot["dispatch_end"] = end
                slot["command"] = command
            elif slot["dispatch_end"] != end or slot["command"] != command:
                raise BuildError(
                    f"inconsistent dispatch end/command for site "
                    f"({callee_entry}, {caller_entry}, {offset}) in {path.name}"
                )
            for contract in route.get("map_location_contracts") or []:
                entry = contract["source_identity"]["entry"]
                locations = contract["locations"]
                slot["contracts"].append((entry, tuple(locations)))

    for event in catalog["events"]:
        source = event["source"]
        callee_entry = source["callee"]["entry"]
        caller_entry = source["caller"]["entry"]
        offset = source["caller"]["dispatch_offset"]
        end = source["caller"]["resume_offset"]
        command = source["caller"]["command"]
        # EP-12 catalog part: a promoted flow row's own `source.caller` is
        # the flow's shared first-dispatch site, identical across the whole
        # flow's rows - only `analysis_group.groups[0].route_ids[0]` tells
        # them apart, so a flow-backed event resolves its site by that route
        # id, not by (callee, caller, offset) alone.
        route_id = ""
        event_groups = event.get("analysis_group", {}).get("groups", [])
        if event_groups and event_groups[0].get("group_id") in flow_group_ids:
            event_route_ids = event_groups[0].get("route_ids", [])
            if len(event_route_ids) == 1:
                route_id = event_route_ids[0]
        pair_offsets.setdefault((callee_entry, caller_entry), set()).add(offset)
        slot = site_slot(callee_entry, caller_entry, offset, route_id)
        if slot["dispatch_end"] is None:
            slot["dispatch_end"] = end
            slot["command"] = command
        elif slot["dispatch_end"] != end or slot["command"] != command:
            raise BuildError(
                f"inconsistent dispatch end/command for site "
                f"({callee_entry}, {caller_entry}, {offset}) against catalog event {event['event_id']}"
            )
        if slot["catalog_event_id"] is not None and slot["catalog_event_id"] != event["event_id"]:
            raise BuildError(
                f"site ({callee_entry}, {caller_entry}, {offset}) already holds catalog_event_id "
                f"{slot['catalog_event_id']!r}, cannot also hold {event['event_id']!r}"
            )
        slot["catalog_event_id"] = event["event_id"]

    multi_site_pairs = {
        pair: len(offsets) for pair, offsets in profile_pair_offsets.items() if len(offsets) > 1
    }

    return site_data, pair_offsets, profile_pair_offsets, multi_site_pairs, len(catalog["events"])


def assert_premises(profile_pair_offsets, multi_site_pairs, catalog_event_count):
    profile_pair_count = len(profile_pair_offsets)
    problems = []
    if profile_pair_count != EXPECTED_PAIR_COUNT:
        problems.append(
            f"expected {EXPECTED_PAIR_COUNT} distinct (callee, caller) pairs, measured {profile_pair_count}"
        )
    if multi_site_pairs != EXPECTED_MULTI_SITE:
        problems.append(
            f"multi-site pairs differ: expected {sorted(EXPECTED_MULTI_SITE.items())}, "
            f"measured {sorted(multi_site_pairs.items())}"
        )
    if catalog_event_count != EXPECTED_CATALOG_COUNT:
        problems.append(f"expected {EXPECTED_CATALOG_COUNT} catalog events, measured {catalog_event_count}")
    if problems:
        raise BuildError("premise mismatch: " + "; ".join(problems))


def provisional_titles(place_disp_en: str, place_disp_ko: str, heroine_en: str, heroine_ko: str, callee_stem: str,
                        is_common: bool = False, is_gallery: bool = False):
    if is_gallery:
        return f"{place_disp_ko}의 {heroine_ko} ({callee_stem})", f"{heroine_en} in {place_disp_en} ({callee_stem})"
    if is_common:
        title_ko = f"{place_disp_ko}에서 {heroine_ko} 이벤트 ({callee_stem})"
        title_en = f"{heroine_en} event at {place_disp_en} ({callee_stem})"
        return title_ko, title_en
    title_ko = f"{place_disp_ko}에서 {heroine_ko} ({callee_stem})"
    title_en = f"{heroine_en} at {place_disp_en} ({callee_stem})"
    return title_ko, title_en


def build_rows(site_data, pair_offsets):
    rows: dict[str, dict] = {}
    for (callee_entry, caller_entry, offset, flow_route_id), slot in site_data.items():
        offsets_sorted = sorted(pair_offsets[(callee_entry, caller_entry)])
        site_ordinal = offsets_sorted.index(offset) + 1

        callee_stem = stem_of(callee_entry)
        caller_stem = stem_of(caller_entry)

        letter, number, is_common = heroine_letter_and_number(callee_stem)
        is_gallery = callee_stem.startswith(SCENE_PREFIX) and caller_stem in GALLERY_MENU_STEMS
        if callee_stem.startswith(SCENE_PREFIX) and not is_gallery:
            raise BuildError(f"gallery scene {callee_stem} is dispatched from {caller_stem}, which is not an album menu")
        is_recollection = callee_stem in RECOLLECTION_HEROINE_BY_STEM
        talk = talk_script_parts(callee_stem)
        if talk and not flow_route_id:
            raise BuildError(f"talk script {callee_stem} has no flow route: its row is numbered by the route id")
        if is_recollection and caller_stem != RECOLLECTION_CALLER_STEM:
            raise BuildError(f"recollection ladder {callee_stem} is dispatched from {caller_stem}, not from the room ({RECOLLECTION_CALLER_STEM})")
        if is_recollection and not flow_route_id:
            raise BuildError(f"recollection ladder {callee_stem} has no flow route: its row is numbered by the route id")
        if flow_route_id and is_recollection:
            # EP-12 H: the ladder's route id must spell the same heroine
            # (`a-h` for `MIKO_H`), so a route cannot drift from its callee.
            if flow_route_id != f"{letter.lower()}-{RECOLLECTION_NUMBER}":
                raise BuildError(
                    f"recollection route id does not match its ladder {callee_stem}: {flow_route_id}"
                )
        elif flow_route_id and is_gallery:
            # EP-12 gallery: a scene route is numbered by its callee stem
            # (above); its route id must spell the same scene so the two
            # cannot drift (`j-scene-01`, `j-scene-h01`).
            if flow_route_id != f"{letter.lower()}-scene-{number}":
                raise BuildError(
                    f"gallery route id does not match its scene {callee_stem}: {flow_route_id}"
                )
        elif flow_route_id and talk:
            # EP-12 TALK: numbered by the callee's band; the route id must spell
            # the same script (`k-talk-30`, `k-talk-plain`).
            talk_letter, talk_band = talk
            band = talk_band or TALK_PLAIN_BAND
            if flow_route_id != f"{talk_letter.lower()}-talk-{band}":
                raise BuildError(f"talk route id does not match its script {callee_stem}: {flow_route_id}")
            number = (f"{TALK_NUMBER_PREFIX}{band}" if talk_letter in HEROINE_TABLE
                      else f"{TALK_NUMBER_PREFIX}{talk_letter.lower()}{talk_band}")
        elif flow_route_id:
            # EP-12 catalog part (2026-09-24): a flow route has no callee-stem
            # suffix of its own to number by (every route dispatches the same
            # first callee) - the id rule extension numbers it by its own
            # route id tail instead: "<heroine letter>-date-<tail>" ->
            # "date-<tail>" ("a-date-town" -> "date-town").
            flow_prefix = f"{letter.lower()}-date-"
            if not flow_route_id.startswith(flow_prefix):
                raise BuildError(
                    f"flow route id does not match the expected <letter>-date-<tail> shape: {flow_route_id}"
                )
            number = f"date-{flow_route_id[len(flow_prefix):]}"
        if is_common:
            heroine_en, heroine_ko = COMMON_HEROINE_EN, COMMON_HEROINE_KO
            heroine_key = COMMON_HEROINE_KEY
        else:
            heroine_en, heroine_ko = HEROINE_TABLE[letter]
            heroine_key = heroine_en.lower()

        has_ground_gate = any(
            entry == "GROUND.MES" and 0 in locations for entry, locations in slot["contracts"]
        )
        category, place = category_and_place(caller_stem, has_ground_gate)
        place_disp_en, place_disp_ko = place_display(category, place)

        scene_kinds = sorted({
            kind for entry, locations in slot["contracts"]
            if (kind := scene_kind_for_contract(entry, list(locations))) is not None
        })

        row_id = f"{heroine_key}.{category}.{place}.{number}.{site_ordinal}"
        if not ID_RE.match(row_id):
            raise BuildError(f"generated id does not match the id regex: {row_id}")
        if row_id in rows:
            raise BuildError(f"duplicate generated id: {row_id}")

        title_ko, title_en = provisional_titles(
            place_disp_en, place_disp_ko, heroine_en, heroine_ko, callee_stem, is_common, is_gallery
        )

        aliases = {"groups": sorted(
            ({"group_id": gid, "route_ids": sorted(route_ids)} for gid, route_ids in slot["groups"].items()),
            key=lambda g: g["group_id"],
        )}
        if slot["catalog_event_id"]:
            aliases["catalog_event_id"] = slot["catalog_event_id"]

        rows[row_id] = {
            "id": row_id,
            "title_ko": title_ko,
            "title_en": title_en,
            "heroine": heroine_key,
            "category": category,
            "place": place,
            "number": number,
            "site": site_ordinal,
            "scene_kinds": scene_kinds,
            "aliases": aliases,
            "evidence": {
                "callee": callee_entry,
                "caller": caller_entry,
                "dispatch_offset": offset,
                "dispatch_end": slot["dispatch_end"],
                "command": slot["command"],
            },
        }
    return rows


def preserve_titles(rows: dict, existing_path: Path):
    if not existing_path.is_file():
        return
    try:
        existing = json.loads(existing_path.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError):
        return
    existing_rows = existing.get("rows", {})
    for row_id, row in rows.items():
        old = existing_rows.get(row_id)
        if not old:
            continue
        fresh_ko, fresh_en = row["title_ko"], row["title_en"]
        if old.get("title_ko") and old["title_ko"] != fresh_ko:
            row["title_ko"] = old["title_ko"]
        if old.get("title_en") and old["title_en"] != fresh_en:
            row["title_en"] = old["title_en"]


def write_registry(rows: dict, out_dir: Path):
    out_dir.mkdir(parents=True, exist_ok=True)
    out_path = out_dir / "event_names.json"
    document = {"schema": "kakyu_event_names_registry/v1", "rows": rows}
    text = json.dumps(document, indent=1, sort_keys=True, ensure_ascii=False) + "\n"
    out_path.write_bytes(text.encode("utf-8"))
    value = fingerprint_compute(out_dir, FINGERPRINT_NAME)
    (out_dir / FINGERPRINT_NAME).write_bytes((value + "\n").encode("utf-8"))
    return out_path, value


def run(profiles_dir: Path, catalog_path: Path, out_dir: Path):
    site_data, pair_offsets, profile_pair_offsets, multi_site_pairs, catalog_event_count = collect_sites(
        profiles_dir, catalog_path
    )
    assert_premises(profile_pair_offsets, multi_site_pairs, catalog_event_count)
    rows = build_rows(site_data, pair_offsets)

    preserve_titles(rows, out_dir / "event_names.json")
    out_path, value = write_registry(rows, out_dir)
    return rows, multi_site_pairs, out_path, value


def summarize(rows: dict, multi_site_pairs: dict) -> str:
    from collections import Counter
    by_category = Counter(row["category"] for row in rows.values())
    by_place = Counter((row["category"], row["place"]) for row in rows.values())
    lines = [
        f"rows: {len(rows)}",
        f"by category: {dict(sorted(by_category.items()))}",
        f"by place: {sorted((f'{c}.{p}', n) for (c, p), n in by_place.items())}",
        f"multi-site pairs: {sorted(multi_site_pairs.items())}",
    ]
    return "\n".join(lines)


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--profiles", type=Path, required=True)
    parser.add_argument("--catalog", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args(argv)

    try:
        rows, multi_site_pairs, out_path, value = run(args.profiles, args.catalog, args.out)
    except BuildError as exc:
        print(f"STOP: {exc}")
        return 1

    print(summarize(rows, multi_site_pairs))
    print(f"wrote {out_path}")
    print(f"names_fingerprint: {value}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
