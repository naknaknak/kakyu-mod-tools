"""Draft the measurement recipe for one album menu's `SCENE_*` flows (EP-12
gallery, owner ruling 2026-10-04), from the original archive's own bytecode -
no execution.

    py tools/draft_menu_flow_specs.py --arc "<mes.arc>" --letter J --out analysis/_undoc/ep12_j_menu_recipe.json

The 13 `<NAME>_M.MES` menus are one template (`docs/spec/mes/gallery_families.md`):
one native selection record (command `0x15`, result in `state_u16[18]`), then
for every scene a page test (`global_u8[20] == page`, ordinary scenes only), a
slot test (`state_u16[18] == slot`; slots 1..4 on a page, 9..17 for the nine H
scenes), the scene's unlock test (`global_u8[flag] == 1`) and the nested
`CALL SCENE_*` (command `0x0F`). This tool finds, for every `CALL` in the menu,
the exact records of that chain (static discovery with
`tools/mes_route_decode.py`'s `facts()` against the Phase 1-4 typed IR), plus
what a scene's measurement needs to know about the scene itself: its
routine-40 question sites, the helper entries it nests (`nested_members`, the
`*_PIC.MES` standing-picture scripts: source members of that scene's flow) and,
for a recap scene, the state cells that select which of two texts plays.

The recipe is the only input of `tools/content_suite/cli/measure_menu_flow.gd`,
which seeds the menu selection (`state_u16[18]` = the slot id, `global_u8[20]`
= the page - a tool decision, because command `0x15` cannot run), runs each
route's two hops through the shared call frame and writes the
`tools/build_event_flow_profile.py` spec files. The tool stops with a named
error, instead of guessing, when a menu does not match the shape above.

Premises checked statically, not assumed:

- the ambient state a gallery visit starts from: `GIRLS.MES` writes
  `state_u16[19] = 1200` and `state_u16[8] = 0` before handing off to the menu
  (`docs/spec/mes/gallery_families.md`, "How the album is reached"); the title
  answer 4 that leads to `GIRLS.MES` leaves `state_u16[21] = 4` (measured, not
  re-derived here).
- the scene flags are one consecutive run in dispatch order.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from mes_route_decode import Archive, facts  # noqa: E402

# Heroine letter -> menu entry (the English names of `build_event_names.HEROINE_TABLE`).
MENU_ENTRIES = {
    "A": "MIKO_M.MES", "B": "MAHOKO_M.MES", "C": "NANA_M.MES", "D": "MAKI_M.MES", "E": "MIZUHO_M.MES",
    "F": "REIKO_M.MES", "G": "RYOKO_M.MES", "H": "MIYUKI_M.MES", "I": "MAYUMI_M.MES", "J": "MINATU_M.MES",
    "K": "AI_M.MES", "L": "SIZUKA_M.MES", "M": "TINA_M.MES",
}

# `state_u16[19]` is the clock, `[8]` and `[21]` the cells GIRLS.MES / the title
# answer leave; the same ambient the study's route probe used for all 365 scenes.
AMBIENT = [("state_u16", 19, 1200), ("state_u16", 8, 0), ("state_u16", 21, 4)]
PAGE_CELL = ("global_u8", 20)
SLOT_CELL = ("state_u16", 18)
PAGE_SLOT_RANGE = range(1, 5)
H_SLOT_RANGE = range(9, 18)

GUARD_RE = re.compile(r"^\(global_u8\[(\d+)\] equal 1\)$")
PAGE_RE = re.compile(r"^\(global_u8\[20\] equal (\d+)\)$")
SLOT_RE = re.compile(r"^\(state_u16\[18\] equal (\d+)\)$")
SCENE_RE = re.compile(r"^SCENE_([A-Z])(_H)?(\d+)\.MES$")


class ShapeError(SystemExit):
    """The menu (or a scene) does not match the template this tool reads."""

    def __init__(self, message: str):
        super().__init__(f"menu shape mismatch: {message}")


def _branches(rows: list[dict]) -> list[dict]:
    return [row for row in rows if row["kind"] == "branch"]


def _check_ambient(archive: Archive) -> None:
    """`GIRLS.MES` is the menu's only host: it must still write the ambient
    clock cell before it hands off to a menu."""
    rows = facts(archive, "GIRLS.MES")
    wrote_clock = any(row["kind"] == "write" and row["storage"] == "state_u16" and row["index"] == 19
                      and row["values"] == ["1200"] for row in rows)
    wrote_cell8 = any(row["kind"] == "write" and row["storage"] == "state_u16" and row["index"] == 8
                      and row["values"] == ["0"] for row in rows)
    if not (wrote_clock and wrote_cell8):
        raise ShapeError("GIRLS.MES no longer writes the ambient state_u16[19] = 1200 / state_u16[8] = 0 "
                         "the gallery visit is seeded with")


def _scene_questions(archive: Archive, scene: str) -> list[int]:
    return sorted(row["offset"] for row in facts(archive, scene) if row["kind"] == "routine" and row.get("routine") == 40)


def _scene_returns(archive: Archive, scene: str) -> list[int]:
    return sorted(row["offset"] for row in facts(archive, scene) if row["kind"] == "return")


def _nested_members(archive: Archive, scene: str) -> list[str]:
    """The entries a scene runs as nested calls (script dispatch), transitively and
    in first-seen order - the helper scripts (the `*_PIC.MES` standing-picture
    scripts) that must be source members of the scene's flow for the scene to
    run to its own return. A scene that hands off instead of returning, or
    nests an entry the archive lacks, is not the template."""
    found: list[str] = []
    pending = [scene]
    while pending:
        entry = pending.pop(0)
        for row in facts(archive, entry):
            if row["kind"] != "dispatch":
                continue
            target = row["target"]
            if target not in archive.entries:
                raise ShapeError(f"{entry}:{row['offset']} nests {target}, which is not in the archive")
            if target != scene and target not in found:
                found.append(target)
                pending.append(target)
    return found


def _recap_cells(archive: Archive, scene: str, letter: str) -> list[int]:
    """The cells a recap scene reads: `global_u8` cells its branches test that
    the heroine's `<letter>_DATE5.MES` writes 1 to and her `<letter>_HOTEL.MES`
    writes 2 to (the two paths a recap summarizes). Empty for any other scene."""
    read = {cell[1] for row in _branches(facts(archive, scene)) for cell in row["cells"] if cell[0] == "global_u8"}

    def literal_writes(entry: str, value: str) -> set[int]:
        if entry not in archive.entries:
            return set()
        return {row["index"] for row in facts(archive, entry)
                if row["kind"] == "write" and row["storage"] == "global_u8" and row["index"] is not None
                and row["values"] == [value]}

    return sorted(read & literal_writes(f"{letter}_DATE5.MES", "1") & literal_writes(f"{letter}_HOTEL.MES", "2"))


def _duplicate_index(path: Path | None) -> dict:
    """`SCENE_*` entry -> {kind, with: [...]} from the duplicate-entries census."""
    if path is None or not path.is_file():
        return {}
    census = json.loads(path.read_text(encoding="utf-8"))
    index = {}
    for group in census.get("groups", []):
        kind = str(group.get("kind", ""))
        for entry in group.get("entries", []):
            if str(entry).startswith("SCENE_"):
                index[entry] = {"kind": kind, "with": sorted(e for e in group["entries"] if e != entry)}
    return index


def draft(archive: Archive, letter: str, duplicates_path: Path | None = None) -> dict:
    if letter not in MENU_ENTRIES:
        raise ShapeError(f"unknown heroine letter {letter}")
    menu = MENU_ENTRIES[letter]
    if menu not in archive.entries:
        raise ShapeError(f"{menu} is not in the archive")
    _check_ambient(archive)

    instructions = archive.instructions(menu)
    selections = [ins for ins in instructions if ins["op"] == "native_selection"]
    if len(selections) != 1:
        raise ShapeError(f"{menu} has {len(selections)} native selection records, expected exactly 1")
    selection = selections[0]

    rows = facts(archive, menu)
    dispatches = [row for row in rows if row["kind"] == "dispatch"]
    if not dispatches:
        raise ShapeError(f"{menu} dispatches nothing")
    for row in dispatches:
        if SCENE_RE.match(row["target"]) is None:
            raise ShapeError(f"{menu}:{row['offset']} dispatches {row['target']}, not a SCENE_ entry")
        if row["offset"] <= selection["end_offset"]:
            raise ShapeError(f"{menu}:{row['offset']} dispatch precedes the selection record")
    branches = _branches(rows)
    duplicates = _duplicate_index(duplicates_path)

    scenes = []
    previous_end = int(selection["end_offset"])
    previous_flag = None
    for index, dispatch in enumerate(dispatches):
        target = dispatch["target"]
        match = SCENE_RE.match(target)
        if match.group(1) != letter:
            raise ShapeError(f"{menu}:{dispatch['offset']} dispatches {target}, a scene of heroine {match.group(1)}")
        if target not in archive.entries:
            raise ShapeError(f"{target} is not in the archive")
        own = [b for b in branches if previous_end <= b["offset"] and b["end"] <= dispatch["offset"]]
        guards = [b for b in own if GUARD_RE.match(b["condition"]) and b["false_target"] > dispatch["end"]]
        if not guards:
            raise ShapeError(f"{menu}:{dispatch['offset']} ({target}) has no unlock test global_u8[flag] == 1 before it")
        guard = guards[-1]
        flag = int(GUARD_RE.match(guard["condition"]).group(1))
        if previous_flag is not None and flag != previous_flag + 1:
            raise ShapeError(f"{target}: unlock flag {flag} does not follow {previous_flag} (flags are one consecutive run)")
        previous_flag = flag
        # The slot and page tests enclose the dispatch (their false target lies
        # beyond it) and may sit before the previous scene's dispatch.
        enclosing = [b for b in branches if b["end"] <= guard["offset"] and b["false_target"] > dispatch["end"]]
        slots = [b for b in enclosing if SLOT_RE.match(b["condition"])]
        if not slots:
            raise ShapeError(f"{menu}:{dispatch['offset']} ({target}) has no slot test state_u16[18] == slot before its unlock test")
        slot_test = slots[-1]
        slot = int(SLOT_RE.match(slot_test["condition"]).group(1))
        pages = [b for b in enclosing if PAGE_RE.match(b["condition"]) and b["offset"] < slot_test["offset"]]
        is_h = match.group(2) is not None
        if is_h:
            if slot not in H_SLOT_RANGE or pages:
                raise ShapeError(f"{target}: an H scene must sit in slot 9..17 with no page test (slot {slot}, pages {len(pages)})")
            page, origin = None, slot_test
        else:
            if slot not in PAGE_SLOT_RANGE or not pages:
                raise ShapeError(f"{target}: a page scene must sit in slot 1..4 behind a page test (slot {slot}, pages {len(pages)})")
            page_test = pages[-1]
            page, origin = int(PAGE_RE.match(page_test["condition"]).group(1)), page_test
        questions = _scene_questions(archive, target)
        returns = _scene_returns(archive, target)
        if not returns:
            raise ShapeError(f"{target} holds no closing return record")
        number = match.group(3)
        route_id = f"{letter.lower()}-scene-{'h' if is_h else ''}{number}"
        scenes.append({
            "index": index, "scene": target, "route_id": route_id, "kind": "h" if is_h else "page",
            "page": page, "slot": slot, "flag": flag,
            "origin_offset": origin["offset"], "slot_test_offset": slot_test["offset"],
            "guard_offset": guard["offset"], "guard_end": guard["end"], "false_target": guard["false_target"],
            "dispatch_offset": dispatch["offset"], "dispatch_end": dispatch["end"],
            "questions": questions, "recap_cells": _recap_cells(archive, target, letter),
            "nested_members": _nested_members(archive, target),
            "duplicate": duplicates.get(target),
        })
        previous_end = dispatch["end"]
    # Slot ids must be distinct per page (a page holds slots 1..4 once each).
    seen = set()
    for scene in scenes:
        key = (scene["page"], scene["slot"])
        if key in seen:
            raise ShapeError(f"{scene['scene']}: page {scene['page']} slot {scene['slot']} is used twice")
        seen.add(key)
    return {
        "letter": letter, "menu_entry": menu, "archive_sha256": archive.sha,
        "group_id": f"{Path(menu).stem.lower().replace('_', '-')}-scene",
        "profile_stem": f"{Path(menu).stem.lower()}_scene_v14",
        "selection": {"offset": int(selection["source_offset"]), "end": int(selection["end_offset"])},
        "ambient": [{"storage": s, "index": i, "value": v} for s, i, v in AMBIENT],
        "page_cell": list(PAGE_CELL), "slot_cell": list(SLOT_CELL),
        "support_members": ["LIBLARY.LIB", "DEF_MAIN.MES", "START.MES"],
        "scenes": scenes,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--arc", type=Path, required=True)
    parser.add_argument("--letter", required=True, choices=sorted(MENU_ENTRIES))
    parser.add_argument("--duplicates", type=Path, default=Path(__file__).resolve().parents[1] / "config" / "event_catalog" / "duplicate_entries_v1.json")
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    recipe = draft(Archive(args.arc), args.letter, args.duplicates)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(recipe, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"ok": True, "out": str(args.out), "letter": args.letter, "scenes": len(recipe["scenes"]),
                      "recap_scenes": sum(1 for s in recipe["scenes"] if s["recap_cells"]),
                      "question_scenes": sum(1 for s in recipe["scenes"] if s["questions"])}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
