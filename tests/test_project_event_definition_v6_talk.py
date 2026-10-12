"""The v6 producer's TALK branch (EP-12 TALK, 2026-10-04): the entries that resolve a flow's
lines include the scripts a hop dispatches inline, and a TALK row's `dependencies` are the
entries its own route runs - on a synthetic ladder, no archive, no package."""
from __future__ import annotations

import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

import project_event_definition_v6 as v6  # noqa: E402


def dispatch(offset, end, target):
    return {"source_offset": offset, "end_offset": end, "op": "script_dispatch",
            "operands": [{"records": [{"value": {"raw_bytes": {"$packed_byte_array_hex": target.lower().encode().hex()}}}]}]}


class FakeArchive:
    """Just what `facts` reads: `instructions(entry)`."""

    def __init__(self, instructions):
        self._instructions = instructions

    def instructions(self, entry):
        return self._instructions[entry]


# `01M.MES`: the block (picture, intro), the rung calls (30 at 200, 50 at 240), the PROMIS call
# (a script the group does not run) and the outro. Rung 50 calls the follow-on at 150.
CALLER = [dispatch(100, 113, "K_PIC.MES"), dispatch(120, 135, "K_INTRO.MES"), dispatch(200, 216, "K_TALK30.MES"),
          dispatch(240, 256, "K_TALK50.MES"), dispatch(280, 296, "K_PROMIS.MES"), dispatch(300, 315, "K_OUTRO.MES")]
ARCHIVE = FakeArchive({"01M.MES": CALLER, "K_TALK30.MES": [], "K_TALK50.MES": [dispatch(150, 165, "K_TALKXX.MES")]})
MEMBERS = [{"entry": name, "entry_sha256": name.lower()} for name in (
    "01M.MES", "K_TALK30.MES", "K_PIC.MES", "K_INTRO.MES", "K_OUTRO.MES", "K_TALK50.MES", "K_TALKXX.MES",
    "LIBLARY.LIB", "DEF_MAIN.MES", "START.MES")]


def route(route_id, callee, dispatch_offset, dispatch_end, terminal_offset=400):
    return {"route_id": route_id, "origin": {"entry": "01M.MES", "offset": 50}, "hops": [
        {"hop_id": "h1", "entry": "01M.MES", "entered_by": {"kind": "origin"},
         "expected": {"outcome": {"offset": dispatch_offset, "end": dispatch_end}}},
        {"hop_id": "h2", "entry": callee, "entered_by": {"kind": "nested_call", "end": dispatch_end},
         "expected": {"outcome": {"offset": 450, "end": 451}}},
        {"hop_id": "h3", "entry": "01M.MES", "entered_by": {"kind": "resume", "end": dispatch_end},
         "expected": {"outcome": {"offset": terminal_offset, "end": terminal_offset + 13}}},
    ]}


R30, R50 = route("k-talk-30", "K_TALK30.MES", 200, 216), route("k-talk-50", "K_TALK50.MES", 240, 256)
PROFILE = {"routes": [R30, R50]}


def message(entry):
    return {"entry": entry, "offset": 1, "end": 2, "raw_sha256": "x"}


def replay(messages_by_hop):
    return {"variants": [{"hops": [{"hop_id": h, "messages": [message(e) for e in entries]} for h, entries in messages_by_hop]}]}


class TalkRowPredicateTests(unittest.TestCase):
    def test_talk_rows_and_only_talk_rows(self):
        # EP-12 TALK (2026-10-05): Tina's `M_TALK` and the characters' `N_TALK`..`Q_TALK1` are TALK rows too.
        for number, callee in (("talk-30", "K_TALK30.MES"), ("talk-00", "A_TALK00.MES"), ("talk-plain", "K_TALK.MES"),
                               ("talk-90", "l_talk90.mes"), ("talk-plain", "M_TALK.MES"), ("talk-n", "N_TALK.MES"),
                               ("talk-n3", "N_TALK3.MES"), ("talk-q1", "Q_TALK1.MES")):
            self.assertTrue(v6.is_talk_registry_row({"number": number, "evidence": {"callee": callee}}), callee)
        for row in ({"number": "talk-30", "evidence": {"callee": "K_TALKXX.MES"}},
                    {"number": "talk-30", "evidence": {"callee": "M_TALK30.MES"}},
                    {"number": "talk-r", "evidence": {"callee": "R_TALK.MES"}},
                    {"number": "talk-n12", "evidence": {"callee": "N_TALK12.MES"}},
                    {"number": "date-town", "evidence": {"callee": "N_TALK.MES"}},
                    {"number": "date-town", "evidence": {"callee": "A_PIC.MES"}},
                    {"number": "h", "evidence": {"callee": "MIKO_H.MES"}},
                    {"number": "03", "evidence": {"callee": "SCENE_J03.MES"}}, {}):
            self.assertFalse(v6.is_talk_registry_row(row), row)

    def test_the_producer_the_promoter_and_the_registry_builder_share_one_definition(self):
        import build_event_names
        import payload_values
        import promote_analysis_groups as pag
        self.assertIs(v6.is_talk_registry_row, payload_values.is_talk_registry_row)
        self.assertIs(pag.is_talk_registry_row, payload_values.is_talk_registry_row)
        self.assertIs(build_event_names.TALK_STEM, payload_values.TALK_STEM)


class InvolvedEntriesTests(unittest.TestCase):
    def test_inline_nested_scripts_that_played_lines_are_involved(self):
        hops = R30["hops"]
        variant = replay([("h1", ["K_INTRO.MES"] * 3), ("h2", ["K_TALK30.MES"]), ("h3", ["K_OUTRO.MES"])])["variants"][0]
        self.assertEqual(v6.flow_involved_entries(hops, variant),
                         ["01M.MES", "K_INTRO.MES", "K_OUTRO.MES", "K_TALK30.MES"])

    def test_a_flow_whose_lines_all_come_from_its_hop_entries_keeps_exactly_those(self):
        hops = R30["hops"]
        variant = replay([("h1", []), ("h2", ["K_TALK30.MES"]), ("h3", ["01M.MES"])])["variants"][0]
        self.assertEqual(v6.flow_involved_entries(hops, variant), ["01M.MES", "K_TALK30.MES"])


class DependencyTests(unittest.TestCase):
    EXCLUDED = {"01M.MES", "K_TALK30.MES", "START.MES", "DEF_MAIN.MES", "LIBLARY.LIB"}

    def entries(self, dependencies):
        return [d["entry"] for d in dependencies]

    def test_a_date_flow_keeps_every_member_its_hops_do_not_account_for(self):
        deps = v6.flow_dependencies(MEMBERS, self.EXCLUDED)
        self.assertEqual(self.entries(deps), ["K_PIC.MES", "K_INTRO.MES", "K_OUTRO.MES", "K_TALK50.MES", "K_TALKXX.MES"])
        self.assertTrue(all(d["role"] == "nested_presentation" for d in deps))

    def test_an_album_or_talk_flow_keeps_only_what_its_route_runs(self):
        deps = v6.flow_dependencies(MEMBERS, self.EXCLUDED, {"01M.MES", "K_TALK30.MES", "K_INTRO.MES"})
        self.assertEqual(self.entries(deps), ["K_INTRO.MES"])


class TalkRouteEntriesTests(unittest.TestCase):
    def entries(self, route_, messages):
        return v6.talk_route_entries(ARCHIVE, route_, PROFILE, replay(messages), MEMBERS)

    def test_rung_30_runs_the_picture_intro_and_outro_but_not_the_other_rungs_or_the_follow_on(self):
        found = self.entries(R30, [("h1", ["K_INTRO.MES"]), ("h2", ["K_TALK30.MES"]), ("h3", ["K_OUTRO.MES"])])
        # the silent picture script is found by its dispatch inside hop 1; the other rung's call sits
        # statically inside the same span and is not this route's; PROMIS is no member of the group.
        self.assertEqual(found, {"01M.MES", "K_TALK30.MES", "K_PIC.MES", "K_INTRO.MES", "K_OUTRO.MES"})

    def test_rung_50_also_runs_the_follow_on_it_dispatches_and_still_not_rung_30(self):
        found = self.entries(R50, [("h1", ["K_INTRO.MES"]), ("h2", ["K_TALK50.MES", "K_TALKXX.MES"]), ("h3", ["K_OUTRO.MES"])])
        self.assertEqual(found, {"01M.MES", "K_TALK50.MES", "K_PIC.MES", "K_INTRO.MES", "K_OUTRO.MES", "K_TALKXX.MES"})
        self.assertNotIn("K_TALK30.MES", found)
        self.assertNotIn("K_PROMIS.MES", found)

    def test_an_entry_that_played_a_line_in_any_variant_counts(self):
        two_variants = {"variants": [
            {"hops": [{"hop_id": "h2", "messages": [message("K_TALK30.MES")]}]},
            {"hops": [{"hop_id": "h2", "messages": [message("K_TALKXX.MES")]}]}]}
        found = v6.talk_route_entries(ARCHIVE, R30, PROFILE, two_variants, MEMBERS)
        self.assertIn("K_TALKXX.MES", found)

    def test_the_resume_hop_starts_at_the_calls_end(self):
        # K_OUTRO is dispatched at 300, inside hop 3's span (216..400) and outside hop 1's (50..200).
        found = self.entries(R30, [("h2", ["K_TALK30.MES"])])
        self.assertIn("K_OUTRO.MES", found)


if __name__ == "__main__":
    unittest.main()
