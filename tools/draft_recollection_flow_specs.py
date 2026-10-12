"""Draft the measurement recipe for the 13 `?_H.MES` recollection ladders of the
protagonist's room (EP-12 H, owner ruling 2026-10-04), from the original
archive's own bytecode - no execution.

    py tools/draft_recollection_flow_specs.py --arc "<mes.arc>" --out analysis/_undoc/ep12_h_recipe.json

`43C.MES` (the protagonist's room) calls one `<NAME>_H.MES` per picker id 1..13
behind `state_u16[13] == id`, reached through answer 3 of the room-action menu
(the routine-40 question at 20161; `docs/spec/mes/43c_caller_group.md`). A
ladder is a fixed sequence of flag-gated segments, each segment a recollection
the ordinary events unlocked, then a tail that converges on one return. This
tool finds, statically (`tools/mes_route_decode.py`'s `facts()` against the Phase
1-4 typed IR):

- the room's side: for every ladder its id test (the route's origin guard) and
  nested `CALL` (command `0x0F`), the clock save the id tests start after (the
  route's origin), the answer chain `state_u16[21] == 1 / 2 / 3` back to the
  routine-40 question and the return chain the call goes back through (to the
  room's loop head);
- the ladder's side: its own heroine guard, the **gates** and the branch cells
  that are not gates (reported, never seeded), the tail returns and the helper
  entries it nests (`nested_members`).

A **gate** (owner/advisor ruling 2026-10-04) is a single `global_u8` flag test -
`global_u8[c] == 1` or `global_u8[c] != 0` - on the ladder's main path:

- not a tail cell (`[11]`, `[2573]`: the segment-done marker and the gallery-mode
  cell the tail tests) and not a presentation cell (`[4000]`, `[3006]`, `[2847]`
  flip an arm of a segment's own staging);
- not a selector: a cell the script also compares with any other value (`[3201..3206]`
  pick one of several arms, the recap cells `[2676..2679]` are 1 or 2) is not a flag;
- not enclosed by the skip span of a branch that is not itself a gate (a
  flag test inside a conditional arm - a recap segment, a picture arm - is not
  on the main path); the ladder's own heroine guard encloses everything and is
  the one exception. Gates nest: a gate inside another gate's span is a gate.

Addendum to the rule (advisor, 2026-10-04): a compound condition that is a pure
`logical_or` chain whose every operand is such a single-flag test of a cell
that may be a flag, and which is itself on the main path, is **transparent** - a
guard of the block, neither a gate nor an enclosing non-gate (MIYUKI_H 64394 over
`[2176 2177 2179 2180 2181]`, MINATU_H 33672 over `[923 924]`). A single-flag test
of one of its member cells inside its span is an ordinary gate; a member cell
tested only inside the guard (`[924]`) is reported as `guard_only_cells` and not
seeded. Every other compound condition (over selector cells, such as the recap
cells) stays an enclosing non-gate. A transparent guard with no gate of its own
cells inside it stops the tool.

It is a byte-position rule, not a byte-skip one: a segment shorter than 1,000
bytes is still a segment, and a prologue segment is one. The recipe lists
every gate, every transparent guard and, per ladder, every other branch cell
grouped by the reason it is not a gate.

The recipe is the only input of
`tools/content_suite/cli/measure_recollection_flow.gd`, which seeds the room's
selection (`state_u16[13]` = the id, `[21]` = 3 - a tool decision: `43C.MES`
never writes `[13]`, and the question's shape is not one the contract tool can
name) and the ambient cells of the room in the evening, runs each route's two
hops and writes the `tools/build_event_flow_profile.py` spec files. The tool
stops with a named error, instead of guessing, when the room or a ladder does not
match the shape above.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from build_event_names import HEROINE_TABLE, RECOLLECTION_HEROINE_BY_STEM  # noqa: E402
from mes_route_decode import Archive, facts  # noqa: E402

ROOM_ENTRY = "43C.MES"
SUPPORT_MEMBERS = ["LIBLARY.LIB", "DEF_MAIN.MES", "START.MES"]

# The room's evening and what the recollection row finds when it is chosen: a
# tool decision recorded in the profile's `unresolved` list. `state_u16[19]` is
# the clock (HHMM, the room-action menu is offered at 20:15 in
# `docs/spec/mes/room_screen.md`), `[8]` is rewritten before it is read, and
# `global_u8[2573]` is the gallery-mode cell the ladder's tail tests.
AMBIENT = [("state_u16", 19, 2015), ("state_u16", 8, 0), ("global_u8", 2573, 0)]
ID_CELL = ("state_u16", 13)
ANSWER_CELL = ("state_u16", 21)
ANSWER_VALUE = 3
CLOCK_SAVE = ("banked_u16", 195, "state_u16[19]")
# The probe's per-frame budget is 512 segments; the ladders need 417..649 (one
# per message), so every ladder's second hop asks for this (a limit, not a
# measurement: docs/spec/tech/content_tools.md, "Hop `segment_budget`").
SEGMENT_BUDGET = 1024

TAIL_CELLS = {11, 2573}
PRESENTATION_CELLS = {4000, 3006, 2847}

ID_RE = re.compile(r"^\(state_u16\[13\] equal (\d+)\)$")
ANSWER_RE = re.compile(r"^\(state_u16\[21\] equal (\d+)\)$")
FLAG_RE = re.compile(r"^\(global_u8\[(\d+)\] (equal 1|not_equal 0)\)$")
FLAG_OPERAND_RE = re.compile(r"\(global_u8\[(\d+)\] (?:equal 1|not_equal 0)\)")
FLAG_FORMS = {("equal", 1), ("not_equal", 0)}
COMPARE_RE = re.compile(r"global_u8\[(\d+)\] ([a-z_]+) (\d+)")


class ShapeError(SystemExit):
    """The room or a ladder does not match the template this tool reads."""

    def __init__(self, message: str):
        super().__init__(f"recollection shape mismatch: {message}")


def _rows_of(archive: Archive, entry: str, kind: str) -> list[dict]:
    return [row for row in facts(archive, entry) if row["kind"] == kind]


def _room(archive: Archive) -> dict:
    """The room's side: the 13 id tests and calls, the origin, the answer chain
    and the return chain."""
    if ROOM_ENTRY not in archive.entries:
        raise ShapeError(f"{ROOM_ENTRY} is not in the archive")
    rows = facts(archive, ROOM_ENTRY)
    branches = [row for row in rows if row["kind"] == "branch"]
    jumps = [row for row in rows if row["kind"] == "jump"]
    dispatches = [row for row in rows if row["kind"] == "dispatch" and row["target"] in
                  {f"{stem}.MES" for stem in RECOLLECTION_HEROINE_BY_STEM}]
    if len(dispatches) != 13 or len({row["target"] for row in dispatches}) != 13:
        raise ShapeError(f"{ROOM_ENTRY} calls {len(dispatches)} ladders, expected 13 distinct ones")
    return_targets = set()
    ladders = []
    for expected_id, dispatch in enumerate(dispatches, 1):
        guards = [b for b in branches if b["end"] == dispatch["offset"] and ID_RE.match(b["condition"])]
        if len(guards) != 1:
            raise ShapeError(f"{ROOM_ENTRY}:{dispatch['offset']} has no id test ending exactly at the call")
        guard = guards[0]
        picker = int(ID_RE.match(guard["condition"]).group(1))
        if picker != expected_id or guard["false_target"] <= dispatch["end"]:
            raise ShapeError(f"{ROOM_ENTRY}:{guard['offset']} tests picker id {picker}, expected {expected_id} "
                             f"with a false target past the call")
        after = [j for j in jumps if j["offset"] == dispatch["end"]]
        if len(after) != 1:
            raise ShapeError(f"{ROOM_ENTRY}:{dispatch['end']} is not the jump that follows the call to {dispatch['target']}")
        return_targets.add(after[0]["target"])
        ladders.append({"id": picker, "entry": dispatch["target"], "guard": guard, "dispatch": dispatch,
                        "return_jump": after[0]})
    if len(return_targets) != 1:
        raise ShapeError(f"the 13 calls return to {len(return_targets)} places, expected one")
    return_target = return_targets.pop()

    # The id tests run in one chain: each test's false target is the next one.
    for current, following in zip(ladders, ladders[1:]):
        if current["guard"]["false_target"] != following["guard"]["offset"]:
            raise ShapeError(f"{ROOM_ENTRY}:{current['guard']['offset']} does not fall to the next id test")

    # The origin: the clock save every id test runs after (the typed record
    # before the chain, `banked_u16[195] = state_u16[19]`), not the jump before a
    # test - the audit takes the origin as a record preceding the guard.
    first_guard = ladders[0]["guard"]
    saves = [row for row in rows if row["kind"] == "write" and row["storage"] == CLOCK_SAVE[0]
             and row["index"] == CLOCK_SAVE[1] and row["values"] == [CLOCK_SAVE[2]]
             and 0 < first_guard["offset"] - row["offset"] <= 64]
    if not saves:
        raise ShapeError(f"no {CLOCK_SAVE[0]}[{CLOCK_SAVE[1]}] = {CLOCK_SAVE[2]} before the first id test")
    origin = saves[-1]

    # The answer chain: answer 3 of the room-action menu's routine-40 question.
    answer_tests = {}
    for branch in branches:
        match = ANSWER_RE.match(branch["condition"])
        if match:
            answer_tests.setdefault(int(match.group(1)), []).append(branch)
    answer3 = [b for b in answer_tests.get(ANSWER_VALUE, []) if b["end"] <= origin["offset"]]
    if not answer3:
        raise ShapeError(f"no state_u16[21] == {ANSWER_VALUE} test before the clock save")
    answer3 = answer3[-1]
    answer2 = [b for b in answer_tests.get(2, []) if b["false_target"] == answer3["offset"]]
    answer1 = [b for b in answer_tests.get(1, []) if answer2 and b["false_target"] == answer2[0]["offset"]]
    questions = [row for row in rows if row["kind"] == "routine" and row.get("routine") == 40
                 and answer1 and row["offset"] < answer1[0]["offset"]]
    if len(answer2) != 1 or len(answer1) != 1 or not questions:
        raise ShapeError("the state_u16[21] == 1 / 2 / 3 chain does not lead back to a routine-40 question")
    question = questions[-1]
    if any(ANSWER_RE.match(b["condition"]) and question["offset"] < b["offset"] < answer1[0]["offset"] for b in branches):
        raise ShapeError("another state_u16[21] test sits between the question and its answer chain")

    # The return chain: the call goes back to `return_target`, then jumps to the
    # room's shared tail and from there to the loop head (the place menu).
    first_jump = [j for j in jumps if j["offset"] >= return_target]
    if not first_jump:
        raise ShapeError(f"no jump after {return_target}")
    shared_tail = first_jump[0]
    second_jump = [j for j in jumps if j["offset"] >= shared_tail["target"]]
    if not second_jump:
        raise ShapeError(f"no jump after {shared_tail['target']}")
    loop_jump = second_jump[0]
    loop_head = [b for b in branches if b["offset"] == loop_jump["target"]]
    if len(loop_head) != 1 or loop_head[0]["condition"] != "1":
        raise ShapeError(f"{ROOM_ENTRY}:{loop_jump['target']} is not the room's loop head")
    return {
        "origin": {"offset": origin["offset"], "end": origin["end"]},
        "question": {"offset": question["offset"]},
        "answer_chain": [{"value": value, "offset": b["offset"], "false_target": b["false_target"]}
                         for value, b in ((1, answer1[0]), (2, answer2[0]), (3, answer3))],
        "return_chain": {"after_call": return_target, "shared_tail": shared_tail["target"],
                         "loop_jump": loop_jump["offset"], "loop_head": loop_jump["target"]},
        "ladders": ladders,
    }


def _tested_values(branches: list[dict]) -> dict[int, set]:
    """Every `global_u8` cell the branches test -> the set of (op, value) it is
    compared with; a comparison with anything but a literal is `("?", -1)`."""
    tested: dict[int, set] = {}
    for branch in branches:
        text = branch["condition"]
        literal = 0
        for match in COMPARE_RE.finditer(text):
            tested.setdefault(int(match.group(1)), set()).add((match.group(2), int(match.group(3))))
            literal += 1
        for storage, cell in branch["cells"]:
            if storage == "global_u8":
                tested.setdefault(int(cell), set())
        for cell in {int(c) for s, c in branch["cells"] if s == "global_u8"}:
            if text.count(f"global_u8[{cell}]") != sum(1 for m in COMPARE_RE.finditer(text) if int(m.group(1)) == cell):
                tested[cell].add(("?", -1))
    return tested


def _gates(rows: list[dict], heroine_guard: dict) -> dict:
    """The ladder's gates, its transparent guards and, per reason, the branch
    cells that are not gates."""
    branches = [row for row in rows if row["kind"] == "branch"]
    tested = _tested_values(branches)

    def may_be_flag(cell: int) -> bool:
        return cell not in TAIL_CELLS and cell not in PRESENTATION_CELLS and tested[cell] <= FLAG_FORMS

    def single_flag(branch: dict):
        match = FLAG_RE.match(branch["condition"])
        if match is None or not may_be_flag(int(match.group(1))):
            return None
        return int(match.group(1))

    def transparent_members(branch: dict):
        """The member cells of a pure `logical_or` chain of single-flag tests,
        else None (advisor addendum to correction 5, 2026-10-04)."""
        text = branch["condition"]
        operands = list(FLAG_OPERAND_RE.finditer(text))
        parts = FLAG_OPERAND_RE.sub("X", text).replace("(", "").replace(")", "").split(" logical_or ")
        if len(operands) < 2 or len(parts) != len(operands) or any(part != "X" for part in parts):
            return None
        cells = [int(match.group(1)) for match in operands]
        return cells if all(may_be_flag(cell) for cell in cells) else None

    gates: list[dict] = []
    transparent: list[dict] = []
    gate_spans: list[tuple[int, int]] = []
    other_spans: list[tuple[int, int]] = []
    plain: list[dict] = []  # every branch that is neither a gate nor a transparent guard
    for branch in sorted(branches, key=lambda b: b["offset"]):
        if branch["offset"] == heroine_guard["offset"]:
            continue
        span = (branch["end"], branch["false_target"])
        enclosed = any(lo <= branch["offset"] < hi for lo, hi in other_spans)
        cell = single_flag(branch)
        if cell is not None and not enclosed:
            depth = sum(1 for lo, hi in gate_spans if lo <= branch["offset"] < hi)
            gates.append({"offset": branch["offset"], "end": branch["end"], "cell": cell,
                          "op": FLAG_RE.match(branch["condition"]).group(2), "false_target": branch["false_target"],
                          "skip": branch["false_target"] - branch["end"], "depth": depth})
            gate_spans.append(span)
            continue
        members = transparent_members(branch) if cell is None and not enclosed else None
        if members is not None:
            transparent.append({"offset": branch["offset"], "end": branch["end"], "false_target": branch["false_target"],
                                "cells": members})
            continue
        plain.append(branch)
        if branch["false_target"] > branch["end"]:
            other_spans.append(span)
    gate_cells = sorted({gate["cell"] for gate in gates})

    # A transparent guard exists to skip the block of gates inside it: one with
    # no gate in its span is not a shape this tool seeds.
    for guard in transparent:
        if not any(guard["end"] <= gate["offset"] < guard["false_target"] and gate["cell"] in guard["cells"]
                   for gate in gates):
            raise ShapeError(f"the flag-only condition at {guard['offset']} guards no gate of its own cells")
    guard_only = sorted({cell for guard in transparent for cell in guard["cells"]} - set(gate_cells))

    tail, presentation, selector, flag_arms, state = set(), set(), set(), set(), set()
    for branch in plain:
        for storage, cell in branch["cells"]:
            cell = int(cell)
            if storage != "global_u8":
                state.add(f"{storage}[{cell}]")
            elif cell in TAIL_CELLS:
                tail.add(cell)
            elif cell in PRESENTATION_CELLS:
                presentation.add(cell)
            elif cell in gate_cells or cell in guard_only:
                continue
            elif may_be_flag(cell):
                flag_arms.add(cell)
            else:
                selector.add(cell)
    return {
        "gates": gates, "gate_cells": gate_cells, "transparent_guards": transparent,
        "excluded": {
            "tail_cells": sorted(tail), "presentation_cells": sorted(presentation),
            "selector_cells": sorted(selector), "flag_tests_inside_arms": sorted(flag_arms),
            "guard_only_cells": guard_only, "state_cells": sorted(state),
        },
    }


def _nested_members(archive: Archive, entry: str) -> list[str]:
    found: list[str] = []
    pending = [entry]
    while pending:
        current = pending.pop(0)
        for row in facts(archive, current):
            if row["kind"] != "dispatch":
                continue
            target = row["target"]
            if target not in archive.entries:
                raise ShapeError(f"{current}:{row['offset']} nests {target}, which is not in the archive")
            if target != entry and target not in found:
                found.append(target)
                pending.append(target)
    return found


def draft(archive: Archive) -> dict:
    room = _room(archive)
    letters = RECOLLECTION_HEROINE_BY_STEM
    ladders = []
    for site in room["ladders"]:
        entry = site["entry"]
        stem = entry[:-4]
        if entry not in archive.entries:
            raise ShapeError(f"{entry} is not in the archive")
        letter = letters[stem]
        english = HEROINE_TABLE[letter][0].lower()
        rows = facts(archive, entry)
        branches = [row for row in rows if row["kind"] == "branch"]
        if not branches:
            raise ShapeError(f"{entry} holds no branch")
        heroine_guard = branches[0]
        match = ID_RE.match(heroine_guard["condition"])
        if match is None or int(match.group(1)) != site["id"]:
            raise ShapeError(f"{entry}:{heroine_guard['offset']} is not the heroine guard state_u16[13] == {site['id']}")
        analysis = _gates(rows, heroine_guard)
        if not analysis["gates"]:
            raise ShapeError(f"{entry} has no gate by the structural rule")
        returns = sorted(row["offset"] for row in rows if row["kind"] == "return")
        questions = sorted(row["offset"] for row in rows if row["kind"] == "routine" and row.get("routine") == 40)
        if questions:
            raise ShapeError(f"{entry} asks a routine-40 question at {questions[0]}; a ladder asks nothing")
        guard, dispatch = site["guard"], site["dispatch"]
        ladders.append({
            "id": site["id"], "letter": letter, "name": english, "entry": entry,
            "route_id": f"{letter.lower()}-h", "group_id": f"43c-{english}-h", "profile_stem": f"43c_{english}_h_v14",
            "guard_offset": guard["offset"], "guard_end": guard["end"], "false_target": guard["false_target"],
            "dispatch_offset": dispatch["offset"], "dispatch_end": dispatch["end"],
            "ladder_guard": {"offset": heroine_guard["offset"], "end": heroine_guard["end"],
                             "false_target": heroine_guard["false_target"]},
            "returns": returns, "nested_members": _nested_members(archive, entry),
            "code_size": len(archive.entries[entry]),
            **analysis,
        })
    return {
        "room_entry": ROOM_ENTRY, "archive_sha256": archive.sha,
        "origin": room["origin"], "question": room["question"], "answer_chain": room["answer_chain"],
        "return_chain": room["return_chain"],
        "ambient": [{"storage": s, "index": i, "value": v} for s, i, v in AMBIENT],
        "id_cell": list(ID_CELL), "answer_cell": list(ANSWER_CELL), "answer_value": ANSWER_VALUE,
        "support_members": SUPPORT_MEMBERS, "segment_budget": SEGMENT_BUDGET,
        "ladders": ladders,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--arc", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    recipe = draft(Archive(args.arc))
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(recipe, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")
    print(json.dumps({"ok": True, "out": str(args.out), "ladders": len(recipe["ladders"]),
                      "gates": sum(len(ladder["gates"]) for ladder in recipe["ladders"])}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
