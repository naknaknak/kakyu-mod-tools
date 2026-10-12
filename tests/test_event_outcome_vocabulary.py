"""Tests for `tools/event_outcome_vocabulary.py` (EP-09): every rule row of
`analysis/_docs/ep09_outcome_vocab_spec.md`, both branches of each map/non-map
split, the reason strings exactly, `phrase` for each outcome, and a pinned
census over the tracked data (`config/event_definitions/v4/`,
`config/event_catalog/analysis_groups/`,
`config/event_catalog/original_events_v1.json`)."""
from __future__ import annotations

import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from tools.event_outcome_vocabulary import (  # noqa: E402
    GAME_OUTCOMES,
    catalog_intro_index,
    catalog_route_outcome,
    catalog_terminal_outcome,
    event_intro_index,
    matched_terminal_outcome,
    phrase,
    profile_reentry_outcome,
    profile_route_outcome,
    v4_reentry_outcome,
    v4_result_outcome,
    v4_terminal_outcome,
    _catalog_records,
    _load_v4_documents,
    _profile_records,
    _v4_records,
)

V4_DIR = ROOT / "config" / "event_definitions" / "v4"
PROFILES_DIR = ROOT / "config" / "event_catalog" / "analysis_groups"
CATALOG_PATH = ROOT / "config" / "event_catalog" / "original_events_v1.json"


class IntroIndexTest(unittest.TestCase):
    """EP-03 step 2 (owner ruling 2026-09-23): `(CALLER_ENTRY_UPPER, offset)
    -> callee_entry` index builders used to reclassify a dependency stop
    landing exactly on another event's intro dispatch as `chain`."""

    def test_event_intro_index_keys_by_caller_entry_upper_and_offset(self) -> None:
        documents = [
            {
                "trigger": {
                    "caller": {"entry": "ground.mes", "offset": 6308},
                    "callee": {"entry": "EVENTK01.MES"},
                }
            }
        ]
        self.assertEqual(event_intro_index(documents), {("GROUND.MES", 6308): "EVENTK01.MES"})

    def test_event_intro_index_skips_a_document_with_no_trigger(self) -> None:
        self.assertEqual(event_intro_index([{}, {"trigger": {}}]), {})

    def test_catalog_intro_index_keys_by_caller_entry_upper_and_dispatch_offset(self) -> None:
        events = [
            {
                "source": {
                    "caller": {"entry": "ground.mes", "dispatch_offset": 6308},
                    "callee": {"entry": "EVENTK01.MES"},
                }
            }
        ]
        self.assertEqual(catalog_intro_index(events), {("GROUND.MES", 6308): "EVENTK01.MES"})

    def test_catalog_intro_index_skips_a_row_with_no_caller(self) -> None:
        self.assertEqual(catalog_intro_index([{"source": {}}]), {})


class V4TerminalOutcomeTest(unittest.TestCase):
    def test_root_handoff_to_a_map_is_map_return_event(self) -> None:
        record = v4_terminal_outcome({"kind": "root_handoff", "next_target": "MACHI.MES"})
        self.assertEqual(record["outcome"], "map_return")
        self.assertEqual(record["postlude"], "event")
        self.assertEqual(record["map"], "town")
        self.assertEqual(record["next_target"], "MACHI.MES")

    def test_root_handoff_to_a_non_map_is_chain(self) -> None:
        record = v4_terminal_outcome({"kind": "root_handoff", "next_target": "13C.MES"})
        self.assertEqual(record["outcome"], "chain")
        self.assertEqual(record["next_target"], "13C.MES")

    def test_natural_handoff_to_a_map_is_map_return_place(self) -> None:
        record = v4_terminal_outcome({"kind": "natural_handoff", "next_target": "GROUND.MES"})
        self.assertEqual(record["outcome"], "map_return")
        self.assertEqual(record["postlude"], "place")
        self.assertEqual(record["map"], "campus")

    def test_natural_handoff_to_a_non_map_is_chain(self) -> None:
        record = v4_terminal_outcome({"kind": "natural_handoff", "next_target": "EVENTK01.MES"})
        self.assertEqual(record["outcome"], "chain")

    def test_def_selection_boundary_is_place_menu(self) -> None:
        self.assertEqual(v4_terminal_outcome({"kind": "def_selection_boundary"})["outcome"], "place_menu")

    def test_caller_menu_loop_is_place_menu(self) -> None:
        self.assertEqual(v4_terminal_outcome({"kind": "caller_menu_loop"})["outcome"], "place_menu")

    def test_dependency_stop_is_unresolved(self) -> None:
        record = v4_terminal_outcome({"kind": "dependency_stop"})
        self.assertEqual(record["outcome"], "unresolved")
        self.assertEqual(record["reason"], "dependency_stop")

    def test_dependency_stop_on_an_intro_dispatch_is_chain(self) -> None:
        terminal = {"kind": "dependency_stop", "owner_entry": "ground.mes", "offset": 6308}
        intros = {("GROUND.MES", 6308): "EVENTK01.MES"}
        record = v4_terminal_outcome(terminal, intros)
        self.assertEqual(record["outcome"], "chain")
        self.assertEqual(record["next_target"], "EVENTK01.MES")

    def test_dependency_stop_off_an_intro_dispatch_stays_unresolved(self) -> None:
        terminal = {"kind": "dependency_stop", "owner_entry": "GROUND.MES", "offset": 1}
        intros = {("GROUND.MES", 6308): "EVENTK01.MES"}
        record = v4_terminal_outcome(terminal, intros)
        self.assertEqual(record["outcome"], "unresolved")
        self.assertEqual(record["reason"], "dependency_stop")

    def test_callee_return_is_unresolved_continuation_undeclared(self) -> None:
        record = v4_terminal_outcome({"kind": "callee_return"})
        self.assertEqual(record["outcome"], "unresolved")
        self.assertEqual(record["reason"], "continuation_undeclared")

    def test_unknown_kind_is_unresolved_with_kind_named(self) -> None:
        record = v4_terminal_outcome({"kind": "something_else"})
        self.assertEqual(record["outcome"], "unresolved")
        self.assertEqual(record["reason"], "unknown_kind:something_else")

    def test_unknown_shape_does_not_raise(self) -> None:
        record = v4_terminal_outcome([])
        self.assertEqual(record["outcome"], "unresolved")


class V4ResultOutcomeTest(unittest.TestCase):
    def test_resolves_the_result_terminal_and_applies_terminal_rules(self) -> None:
        document = {
            "terminals": {"t1": {"kind": "root_handoff", "next_target": "MACHI.MES"}},
            "results": {"r1": {"terminal": "t1"}},
        }
        record = v4_result_outcome(document, "r1")
        self.assertEqual(record["outcome"], "map_return")
        self.assertEqual(record["map"], "town")

    def test_missing_result_id_is_terminal_missing(self) -> None:
        document = {"terminals": {}, "results": {}}
        record = v4_result_outcome(document, "absent")
        self.assertEqual(record["outcome"], "unresolved")
        self.assertEqual(record["reason"], "terminal_missing")

    def test_missing_terminal_is_terminal_missing(self) -> None:
        document = {"terminals": {}, "results": {"r1": {"terminal": "absent"}}}
        record = v4_result_outcome(document, "r1")
        self.assertEqual(record["outcome"], "unresolved")
        self.assertEqual(record["reason"], "terminal_missing")


class V4ReentryOutcomeTest(unittest.TestCase):
    def test_no_reentry_block_is_reentry_undeclared(self) -> None:
        document = {"terminals": {}, "results": {"r1": {}}}
        record = v4_reentry_outcome(document, "r1")
        self.assertEqual(record["outcome"], "unresolved")
        self.assertEqual(record["reason"], "reentry_undeclared")

    def test_flow_route_ends_on_its_terminal(self) -> None:
        flow = {"origin": {"entry": "01M.MES"}, "hops": [], "terminal": {
            "status": "script_handoff_boundary", "target": "MACHI.MES"}}
        record = profile_route_outcome(flow)
        self.assertEqual((record["outcome"], record["map"], record["postlude"]), ("map_return", "town", "event"))
        flow["terminal"] = {"status": "script_handoff_boundary", "target": "A_HOTEL.MES"}
        self.assertEqual(profile_route_outcome(flow)["outcome"], "chain")
        flow["terminal"] = {"status": "script_return", "target": ""}
        record = profile_route_outcome(flow)
        self.assertEqual((record["outcome"], record["reason"]), ("unresolved", "flow_return"))
        self.assertEqual(profile_reentry_outcome(flow)["reason"], "flow_reentry_undeclared")

    def test_flow_scene_returning_to_its_dispatching_origin_is_place_menu(self) -> None:
        # EP-12 gallery (2026-10-04, tool decision): a two-hop flow whose
        # origin dispatches one callee that returns. Any other returning shape
        # keeps `flow_return`.
        flow = {"origin": {"entry": "MINATU_M.MES"}, "terminal": {"status": "script_return"}, "hops": [
            {"entered_by": {"kind": "origin"}, "expected": {"outcome": {"status": "script_dispatch_boundary"}}},
            {"entered_by": {"kind": "nested_call"}, "expected": {"outcome": {"status": "script_return"}}}]}
        self.assertEqual(profile_route_outcome(flow)["outcome"], "place_menu")
        flow["hops"][1]["entered_by"]["kind"] = "root_handoff"
        self.assertEqual(profile_route_outcome(flow)["reason"], "flow_return")
        flow["hops"][1]["entered_by"]["kind"] = "nested_call"
        flow["hops"][0]["expected"]["outcome"]["status"] = "script_handoff_boundary"
        self.assertEqual(profile_route_outcome(flow)["reason"], "flow_return")
        flow["hops"][0]["expected"]["outcome"]["status"] = "script_dispatch_boundary"
        flow["hops"].append(dict(flow["hops"][1]))
        self.assertEqual(profile_route_outcome(flow)["reason"], "flow_return")

    def test_a_three_hop_talk_flow_ending_at_the_town_handoff_keeps_the_handoff_outcome(self) -> None:
        # EP-12 TALK (2026-10-04): the caller's block (guard through the script's call), the
        # script to its return and the caller resuming to the town handoff. The terminal is the
        # handoff, so the existing handoff rule reads it (map_return / town), not `place_menu`
        # (that is the two-hop returning shape of an album scene or a plain script).
        flow = {"origin": {"entry": "01M.MES"}, "terminal": {"status": "script_handoff_boundary", "target": "MACHI.MES"},
                "hops": [
                    {"entered_by": {"kind": "origin"}, "expected": {"outcome": {"status": "script_dispatch_boundary"}}},
                    {"entered_by": {"kind": "nested_call"}, "expected": {"outcome": {"status": "script_return"}}},
                    {"entered_by": {"kind": "resume"}, "expected": {"outcome": {"status": "script_handoff_boundary"}}}]}
        record = profile_route_outcome(flow)
        self.assertEqual((record["outcome"], record["map"], record["postlude"]), ("map_return", "town", "event"))
        self.assertEqual(phrase(record), "Back to the town map")
        # The plain script's two-hop shape (caller guard to the call, the script to its return) is
        # the existing returning-callee shape.
        two_hop = {"origin": {"entry": "27C_EV.MES"}, "terminal": {"status": "script_return"}, "hops": flow["hops"][:2]}
        self.assertEqual(profile_route_outcome(two_hop)["outcome"], "place_menu")

    def test_zero_messages_is_not_triggered_done_gate(self) -> None:
        document = {"terminals": {}, "results": {"r1": {"reentry": {"message_count": 0}}}}
        record = v4_reentry_outcome(document, "r1")
        self.assertEqual(record["outcome"], "not_triggered")
        self.assertEqual(record["reason"], "done_gate")

    def test_nonzero_messages_carries_the_route_outcome_with_repeat(self) -> None:
        document = {
            "terminals": {"t1": {"kind": "root_handoff", "next_target": "MACHI.MES"}},
            "results": {"r1": {"terminal": "t1", "reentry": {"message_count": 9}}},
        }
        record = v4_reentry_outcome(document, "r1")
        self.assertEqual(record["outcome"], "map_return")
        self.assertTrue(record["repeat"])


class CatalogRouteOutcomeTest(unittest.TestCase):
    def test_caller_handoff_to_a_map_is_map_return_place(self) -> None:
        record = catalog_route_outcome([{"kind": "caller_handoff", "next_target": "MACHI.MES", "sequence": 10}])
        self.assertEqual(record["outcome"], "map_return")
        self.assertEqual(record["postlude"], "place")

    def test_root_replacement_to_a_map_is_map_return_event(self) -> None:
        record = catalog_route_outcome([{"kind": "root_replacement", "next_target": "MACHI.MES", "sequence": 10}])
        self.assertEqual(record["outcome"], "map_return")
        self.assertEqual(record["postlude"], "event")

    def test_normal_completion_to_a_map_is_map_return_event(self) -> None:
        record = catalog_route_outcome([{"kind": "normal_completion", "next_target": "GROUND.MES", "sequence": 10}])
        self.assertEqual(record["outcome"], "map_return")
        self.assertEqual(record["postlude"], "event")

    def test_caller_handoff_to_a_non_map_is_chain(self) -> None:
        record = catalog_route_outcome([{"kind": "caller_handoff", "next_target": "13C.MES", "sequence": 10}])
        self.assertEqual(record["outcome"], "chain")

    def test_caller_handoff_with_empty_target_is_target_missing(self) -> None:
        record = catalog_route_outcome([{"kind": "caller_handoff", "next_target": "", "sequence": 10}])
        self.assertEqual(record["outcome"], "unresolved")
        self.assertEqual(record["reason"], "target_missing")

    def test_analysis_boundary_def_selection_is_place_menu(self) -> None:
        record = catalog_route_outcome(
            [{"kind": "analysis_boundary", "runtime_status": "def_selection_boundary", "sequence": 10}]
        )
        self.assertEqual(record["outcome"], "place_menu")

    def test_analysis_boundary_loop_boundary_is_place_menu(self) -> None:
        # The catalog form of a profile's `caller_menu_loop` resume - the
        # place script's own input loop - reads as the place menu, as the v4
        # and profile rules already read it (2026-09-23).
        record = catalog_route_outcome(
            [{"kind": "analysis_boundary", "runtime_status": "loop_boundary", "sequence": 30}]
        )
        self.assertEqual(record["outcome"], "place_menu")
        self.assertEqual(record["reason"], "")

    def test_analysis_boundary_other_status_is_unresolved_with_status_named(self) -> None:
        record = catalog_route_outcome(
            [{"kind": "analysis_boundary", "runtime_status": "shared_routine_boundary", "sequence": 10}]
        )
        self.assertEqual(record["outcome"], "unresolved")
        self.assertEqual(record["reason"], "shared_routine_boundary")

    def test_analysis_boundary_script_dispatch_boundary_with_next_target_is_chain(self) -> None:
        record = catalog_route_outcome(
            [{
                "kind": "analysis_boundary",
                "runtime_status": "script_dispatch_boundary",
                "next_target": "EVENTK01.MES",
                "sequence": 10,
            }]
        )
        self.assertEqual(record["outcome"], "chain")
        self.assertEqual(record["next_target"], "EVENTK01.MES")

    def test_analysis_boundary_script_dispatch_boundary_without_next_target_is_unresolved(self) -> None:
        record = catalog_route_outcome(
            [{"kind": "analysis_boundary", "runtime_status": "script_dispatch_boundary", "sequence": 10}]
        )
        self.assertEqual(record["outcome"], "unresolved")
        self.assertEqual(record["reason"], "script_dispatch_boundary")

    def test_rejection_return_is_not_triggered(self) -> None:
        record = catalog_route_outcome([{"kind": "rejection_return", "sequence": 10}])
        self.assertEqual(record["outcome"], "not_triggered")
        self.assertEqual(record["reason"], "rejection_return")

    def test_early_return_to_a_map_is_map_return_event(self) -> None:
        record = catalog_route_outcome([{"kind": "early_return", "next_target": "MACHI.MES", "sequence": 10}])
        self.assertEqual(record["outcome"], "map_return")
        self.assertEqual(record["postlude"], "event")

    def test_early_return_to_a_non_map_is_unresolved_early_end(self) -> None:
        record = catalog_route_outcome([{"kind": "early_return", "next_target": "", "sequence": 10}])
        self.assertEqual(record["outcome"], "unresolved")
        self.assertEqual(record["reason"], "early_end")

    def test_callee_return_only_as_last_terminal_is_continuation_undeclared(self) -> None:
        record = catalog_route_outcome([{"kind": "callee_return_only", "sequence": 10}])
        self.assertEqual(record["outcome"], "unresolved")
        self.assertEqual(record["reason"], "continuation_undeclared")

    def test_caller_postlude_as_last_terminal_is_continuation_undeclared(self) -> None:
        record = catalog_route_outcome([{"kind": "caller_postlude", "sequence": 10}])
        self.assertEqual(record["outcome"], "unresolved")
        self.assertEqual(record["reason"], "continuation_undeclared")

    def test_prefix_end_is_unresolved_with_kind_named(self) -> None:
        record = catalog_route_outcome([{"kind": "prefix_end", "sequence": 10}])
        self.assertEqual(record["outcome"], "unresolved")
        self.assertEqual(record["reason"], "prefix_end")

    def test_unresolved_host_handoff_is_unresolved_with_kind_named(self) -> None:
        record = catalog_route_outcome([{"kind": "unresolved_host_handoff", "sequence": 10}])
        self.assertEqual(record["outcome"], "unresolved")
        self.assertEqual(record["reason"], "unresolved_host_handoff")

    def test_orders_by_sequence_before_taking_the_last(self) -> None:
        record = catalog_route_outcome(
            [
                {"kind": "caller_handoff", "next_target": "MACHI.MES", "sequence": 30},
                {"kind": "caller_postlude", "sequence": 20},
                {"kind": "callee_return_only", "sequence": 10},
            ]
        )
        self.assertEqual(record["outcome"], "map_return")

    def test_empty_list_is_terminals_missing(self) -> None:
        record = catalog_route_outcome([])
        self.assertEqual(record["outcome"], "unresolved")
        self.assertEqual(record["reason"], "terminals_missing")


class CatalogTerminalOutcomeTest(unittest.TestCase):
    def test_caller_handoff_postlude_place(self) -> None:
        record = catalog_terminal_outcome({"kind": "caller_handoff", "next_target": "MACHI.MES"})
        self.assertEqual(record["outcome"], "map_return")
        self.assertEqual(record["postlude"], "place")

    def test_root_replacement_postlude_event(self) -> None:
        record = catalog_terminal_outcome({"kind": "root_replacement", "next_target": "MACHI.MES"})
        self.assertEqual(record["outcome"], "map_return")
        self.assertEqual(record["postlude"], "event")

    def test_normal_completion_postlude_event(self) -> None:
        record = catalog_terminal_outcome({"kind": "normal_completion", "next_target": "GROUND.MES"})
        self.assertEqual(record["outcome"], "map_return")
        self.assertEqual(record["postlude"], "event")

    def test_analysis_boundary_script_dispatch_boundary_with_next_target_is_chain(self) -> None:
        record = catalog_terminal_outcome(
            {"kind": "analysis_boundary", "runtime_status": "script_dispatch_boundary", "next_target": "K_PIC.MES"}
        )
        self.assertEqual(record["outcome"], "chain")
        self.assertEqual(record["next_target"], "K_PIC.MES")


class ProfileRouteOutcomeTest(unittest.TestCase):
    def test_root_handoff_to_a_map_is_map_return_event(self) -> None:
        record = profile_route_outcome({"caller_outcome": {"kind": "root_handoff"}, "outcome": {"target": "MACHI.MES"}})
        self.assertEqual(record["outcome"], "map_return")
        self.assertEqual(record["postlude"], "event")

    def test_nested_root_handoff_to_a_map_is_map_return_event(self) -> None:
        record = profile_route_outcome(
            {"caller_outcome": {"kind": "nested_root_handoff"}, "outcome": {"target": "GROUND.MES"}}
        )
        self.assertEqual(record["outcome"], "map_return")
        self.assertEqual(record["postlude"], "event")

    def test_root_handoff_to_a_non_map_is_chain(self) -> None:
        record = profile_route_outcome({"caller_outcome": {"kind": "root_handoff"}, "outcome": {"target": "13C.MES"}})
        self.assertEqual(record["outcome"], "chain")

    def test_dispatch_natural_handoff_to_a_map_is_map_return_place(self) -> None:
        record = profile_route_outcome(
            {
                "caller_outcome": {"kind": "dispatch"},
                "resume": {"boundary_policy": "natural_handoff", "outcome": {"target": "MACHI.MES"}},
            }
        )
        self.assertEqual(record["outcome"], "map_return")
        self.assertEqual(record["postlude"], "place")

    def test_dispatch_natural_handoff_to_a_non_map_is_chain(self) -> None:
        record = profile_route_outcome(
            {
                "caller_outcome": {"kind": "dispatch"},
                "resume": {"boundary_policy": "natural_handoff", "outcome": {"target": "EVENTK01.MES"}},
            }
        )
        self.assertEqual(record["outcome"], "chain")

    def test_dispatch_def_selection_boundary_is_place_menu(self) -> None:
        record = profile_route_outcome(
            {"caller_outcome": {"kind": "dispatch"}, "resume": {"boundary_policy": "def_selection_boundary"}}
        )
        self.assertEqual(record["outcome"], "place_menu")

    def test_dispatch_caller_menu_loop_is_place_menu(self) -> None:
        record = profile_route_outcome(
            {"caller_outcome": {"kind": "dispatch"}, "resume": {"boundary_policy": "caller_menu_loop"}}
        )
        self.assertEqual(record["outcome"], "place_menu")

    def test_dispatch_stop_before_unprovided_dependency_is_unresolved(self) -> None:
        record = profile_route_outcome(
            {
                "caller_outcome": {"kind": "dispatch"},
                "resume": {"boundary_policy": "stop_before_unprovided_dependency"},
            }
        )
        self.assertEqual(record["outcome"], "unresolved")
        self.assertEqual(record["reason"], "dependency_stop")

    def test_dispatch_stop_on_an_intro_dispatch_is_chain(self) -> None:
        route = {
            "caller": {"entry": "ground.mes"},
            "caller_outcome": {"kind": "dispatch"},
            "resume": {
                "boundary_policy": "stop_before_unprovided_dependency",
                "outcome": {"offset": 6308},
            },
        }
        intros = {("GROUND.MES", 6308): "EVENTK01.MES"}
        record = profile_route_outcome(route, intros)
        self.assertEqual(record["outcome"], "chain")
        self.assertEqual(record["next_target"], "EVENTK01.MES")

    def test_dispatch_stop_off_an_intro_dispatch_stays_unresolved(self) -> None:
        route = {
            "caller": {"entry": "GROUND.MES"},
            "caller_outcome": {"kind": "dispatch"},
            "resume": {
                "boundary_policy": "stop_before_unprovided_dependency",
                "outcome": {"offset": 1},
            },
        }
        intros = {("GROUND.MES", 6308): "EVENTK01.MES"}
        record = profile_route_outcome(route, intros)
        self.assertEqual(record["outcome"], "unresolved")
        self.assertEqual(record["reason"], "dependency_stop")

    def test_dispatch_resume_without_policy_but_with_map_target_is_map_return_place(self) -> None:
        record = profile_route_outcome(
            {"caller_outcome": {"kind": "dispatch"}, "resume": {"outcome": {"target": "MACHI.MES"}}}
        )
        self.assertEqual(record["outcome"], "map_return")
        self.assertEqual(record["postlude"], "place")

    def test_dispatch_without_resume_is_unresolved_continuation_undeclared(self) -> None:
        record = profile_route_outcome({"caller_outcome": {"kind": "dispatch"}})
        self.assertEqual(record["outcome"], "unresolved")
        self.assertEqual(record["reason"], "continuation_undeclared")

    def test_blocked_definition_is_unresolved(self) -> None:
        record = profile_route_outcome({"caller_outcome": {"kind": "blocked_definition"}})
        self.assertEqual(record["outcome"], "unresolved")
        self.assertEqual(record["reason"], "blocked_definition")

    def test_unknown_kind_is_unresolved_with_kind_named(self) -> None:
        record = profile_route_outcome({"caller_outcome": {"kind": "something_else"}})
        self.assertEqual(record["outcome"], "unresolved")
        self.assertEqual(record["reason"], "unknown_kind:something_else")


class ProfileReentryOutcomeTest(unittest.TestCase):
    def test_no_reentry_block_is_reentry_undeclared(self) -> None:
        record = profile_reentry_outcome({})
        self.assertEqual(record["outcome"], "unresolved")
        self.assertEqual(record["reason"], "reentry_undeclared")

    def test_script_return_with_zero_messages_is_not_triggered(self) -> None:
        record = profile_reentry_outcome({"reentry": {"outcome": {"status": "script_return"}, "message_count": 0}})
        self.assertEqual(record["outcome"], "not_triggered")
        self.assertEqual(record["reason"], "done_gate")

    def test_map_target_is_map_return_event(self) -> None:
        record = profile_reentry_outcome(
            {"reentry": {"outcome": {"status": "script_handoff_boundary", "target": "MACHI.MES"}, "message_count": 0}}
        )
        self.assertEqual(record["outcome"], "map_return")
        self.assertEqual(record["postlude"], "event")

    def test_non_map_non_empty_target_is_chain(self) -> None:
        record = profile_reentry_outcome(
            {"reentry": {"outcome": {"status": "other", "target": "13C.MES"}, "message_count": 5}}
        )
        self.assertEqual(record["outcome"], "chain")

    def test_otherwise_unresolved_with_status_named(self) -> None:
        record = profile_reentry_outcome(
            {"reentry": {"outcome": {"status": "def_selection_boundary"}, "message_count": 20}}
        )
        self.assertEqual(record["outcome"], "unresolved")
        self.assertEqual(record["reason"], "def_selection_boundary")


class MatchedTerminalOutcomeTest(unittest.TestCase):
    """EP-12 gallery (2026-10-04, tool decision): the Event Player phrases a
    matched `callee_return_only` terminal by the row's decided route outcome
    instead of an undeclared continuation."""

    SCENE_ROW = [
        {"kind": "callee_return_only", "outcome": "continue", "runtime_status": "script_return", "sequence": 10,
         "next_target": ""},
        {"kind": "analysis_boundary", "outcome": "unresolved", "runtime_status": "loop_boundary", "sequence": 30,
         "next_target": ""},
    ]

    def test_a_scene_return_is_phrased_as_the_place_menu(self) -> None:
        record = matched_terminal_outcome(self.SCENE_ROW[0], self.SCENE_ROW)
        self.assertEqual(record, catalog_route_outcome(self.SCENE_ROW))
        self.assertEqual(phrase(record), "Back to the place menu")

    def test_a_callee_return_before_a_map_handoff_is_phrased_by_the_handoff(self) -> None:
        terminals = [
            self.SCENE_ROW[0],
            {"kind": "caller_handoff", "outcome": "normal_completion", "runtime_status": "script_handoff_boundary",
             "sequence": 30, "next_target": "MACHI.MES"},
        ]
        record = matched_terminal_outcome(terminals[0], terminals)
        self.assertEqual((record["outcome"], record["map"], record["postlude"]), ("map_return", "town", "place"))

    def test_a_row_whose_route_outcome_is_unresolved_keeps_the_terminals_own_reading(self) -> None:
        only = [self.SCENE_ROW[0]]
        record = matched_terminal_outcome(only[0], only)
        self.assertEqual((record["outcome"], record["reason"]), ("unresolved", "continuation_undeclared"))

    def test_any_other_terminal_is_read_as_before(self) -> None:
        for terminal in self.SCENE_ROW[1:] + [
                {"kind": "caller_postlude", "runtime_status": "script_return", "sequence": 20, "next_target": ""},
                {"kind": "caller_handoff", "runtime_status": "script_handoff_boundary", "sequence": 30,
                 "next_target": "MACHI.MES"}]:
            with self.subTest(kind=terminal["kind"]):
                self.assertEqual(matched_terminal_outcome(terminal, self.SCENE_ROW), catalog_terminal_outcome(terminal))

    def test_a_malformed_terminal_does_not_raise(self) -> None:
        self.assertEqual(matched_terminal_outcome("x", self.SCENE_ROW)["reason"], "unknown_shape")

    def test_over_the_tracked_catalog_only_callee_returns_move(self) -> None:
        # Every tracked terminal is read as `catalog_terminal_outcome` reads it,
        # except a `callee_return_only` one of a row with a decided route
        # outcome, which takes the row's own (the 365 album scenes, the two
        # `15C.MES` returning-callee rows and the other callee-return-first rows).
        import json
        events = json.loads(CATALOG_PATH.read_text(encoding="utf-8"))["events"]
        moved = 0
        for event in events:
            route = catalog_route_outcome(event["terminals"])
            for terminal in event["terminals"]:
                record = matched_terminal_outcome(terminal, event["terminals"])
                if terminal["kind"] == "callee_return_only" and route["outcome"] != "unresolved":
                    self.assertEqual(record, route, event["event_id"])
                    moved += 1
                else:
                    self.assertEqual(record, catalog_terminal_outcome(terminal), event["event_id"])
        self.assertGreaterEqual(moved, 25)


class PhraseTest(unittest.TestCase):
    def test_map_return_town(self) -> None:
        self.assertEqual(phrase({"outcome": "map_return", "map": "town", "postlude": "event"}), "Back to the town map")

    def test_map_return_campus(self) -> None:
        self.assertEqual(phrase({"outcome": "map_return", "map": "campus", "postlude": "event"}), "Back to the campus map")

    def test_map_return_train(self) -> None:
        self.assertEqual(phrase({"outcome": "map_return", "map": "train", "postlude": "event"}), "Back to the train")

    def test_map_return_school_floor(self) -> None:
        self.assertEqual(
            phrase({"outcome": "map_return", "map": "school floor 3", "postlude": "event"}),
            "Back to school floor 3",
        )

    def test_map_return_place_postlude_adds_suffix(self) -> None:
        self.assertEqual(
            phrase({"outcome": "map_return", "map": "town", "postlude": "place"}),
            "Back to the town map after the place's own lines",
        )

    def test_place_menu(self) -> None:
        self.assertEqual(phrase({"outcome": "place_menu"}), "Back to the place menu")

    def test_chain(self) -> None:
        self.assertEqual(phrase({"outcome": "chain", "next_target": "13C.MES"}), "Continues into 13C.MES")

    def test_not_triggered(self) -> None:
        self.assertEqual(phrase({"outcome": "not_triggered"}), "Not triggered")

    def test_unresolved(self) -> None:
        self.assertEqual(phrase({"outcome": "unresolved", "reason": "dependency_stop"}), "Unresolved: dependency_stop")


class PinnedCensusTest(unittest.TestCase):
    """Measured 2026-09-20 over the tracked data with the module's own CLI
    logic (`py tools/event_outcome_vocabulary.py --v4-dir
    config/event_definitions/v4 --profiles-dir
    config/event_catalog/analysis_groups --catalog
    config/event_catalog/original_events_v1.json`). Re-measured 2026-09-20
    after EP-10 unit 1 promoted 129 measured sites to `analysis_only`
    catalog rows (Core 0.352.0): the full catalog census below now covers
    all 142 rows, and a second census is pinned over the thirteen
    hand-authored rows only (no `analysis_group` block) so the original
    thirteen-row shape stays checked on its own. Re-measured 2026-09-21
    after EP-10 unit 5a declared the ten 13C/12C/11M/01M hand-authored
    sites' analysis groups (`analysis/_undoc/ep10_unit5a_round2_report.md`);
    the catalog rows and catalog-hand-authored-rows censuses are unchanged
    (the catalog JSON itself did not change). Re-measured 2026-09-23 (EP-03
    step 2, owner ruling: a dependency stop landing exactly on another
    catalog event's intro dispatch is `chain`, catalog revision 26): the
    v4/profile censuses below are built with the v4 intro index
    (`event_intro_index`) the CLI itself threads through; the three affected
    v4 results, one v4 reentry and three profile routes moved from
    `unresolved` to `chain`, and the catalog rows census reflects the
    regenerated catalog's three `analysis_boundary` terminals that now carry
    `next_target`. The same day the catalog-side rule read `loop_boundary`
    (the catalog form of `caller_menu_loop`) as `place_menu`, as the v4 and
    profile rules already did: EVENTC06 and EVENTE11 at 15C moved from
    `unresolved` to `place_menu` in the catalog rows census. Re-measured
    2026-09-24 (EP-12 catalog part): `promote_analysis_groups.py` promotes
    one row per `01m-a-date` flow route (145 catalog rows total); the
    profile-side census already counted these three routes as `map_return`
    since the flow's own `terminal` classification landed
    (`event_outcome_vocabulary.py`'s `_is_flow_route`/`flow_route_outcome`,
    2026-09-24) - only the catalog rows census moves, +3 `map_return`.
    Re-measure and update these numbers if the tracked data changes."""

    @classmethod
    def setUpClass(cls) -> None:
        intros = event_intro_index(_load_v4_documents(V4_DIR))
        cls.v4_results, cls.v4_reentries = _v4_records(V4_DIR, intros)
        cls.profile_routes, cls.profile_reentries = _profile_records(PROFILES_DIR, intros)
        cls.catalog_rows = _catalog_records(CATALOG_PATH)

    @staticmethod
    def _census(records: list) -> dict:
        counts = {outcome: 0 for outcome in GAME_OUTCOMES}
        for record in records:
            counts[record["outcome"]] += 1
        return counts

    def test_v4_results_census(self) -> None:
        self.assertEqual(
            self._census(self.v4_results),
            {"map_return": 177, "place_menu": 39, "chain": 15, "not_triggered": 0, "unresolved": 0},
        )

    def test_v4_reentries_census(self) -> None:
        self.assertEqual(
            self._census(self.v4_reentries),
            {"map_return": 63, "place_menu": 9, "chain": 5, "not_triggered": 154, "unresolved": 0},
        )

    def test_profile_routes_census(self) -> None:
        # Re-measured 2026-09-25 (EP-12 C..L date batch): the 27 newly
        # declared c..l-date routes are 10 town + 9 date5 (all ten heroines
        # except L, which left date5 out) + 8 hotel (all ten heroines except
        # D and J, which left hotel out) - 24 map_return
        # (`script_handoff_boundary` to MACHI.MES: every town, every date5,
        # and hotel for C/F/G/H/K) and 3 chain (hotel's own terminal to
        # `44C.MES` for E/I, each through its own HOTEL2 open choice, and for
        # L, a plain unconditional handoff reached under baseline state - a
        # chain outcome in all three cases, since the terminal is not a map
        # handoff).
        # Re-measured 2026-09-25 (EP-12 PROMIS): +117 map_return, one per
        # declared 01m-<letter>-promis route (7 for A - options 8-10 need
        # A's own latch and are named unresolved in the profile rather than
        # declared; 10 each for B..L), every one a nested_call whose caller
        # resume is `natural_handoff` to `MACHI.MES`.
        # Re-measured 2026-09-26 (EP-12 leftovers unit): +4 map_return
        # (d-date-hotel, plus A's own three newly-declared promis results
        # 8-10, each `natural_handoff` to `MACHI.MES` like A's other seven)
        # and +1 chain (l-date-date5, ending at `44C.MES` like L's own hotel
        # route already does).
        # Re-measured 2026-10-04 (EP-12 SCENE J unit): +25 place_menu, one per
        # route of `minatu-m-scene` (a two-hop flow whose first hop dispatches
        # the scene and whose scene hop returns to its menu).
        # Re-measured 2026-10-04 (EP-12 SCENE all-menus unit): +340 place_menu,
        # one per route of the other twelve `<menu>-scene` profiles.
        # Re-measured 2026-10-04 (EP-12 H unit): +13 place_menu, one per route of
        # the `43c-<name>-h` profiles (a two-hop flow whose first hop dispatches
        # the ladder from the room and whose ladder hop returns to the room).
        # Re-measured 2026-10-04 (EP-12 TALK K unit): +8 map_return, one per rung route
        # of `01m-k-talk` (a three-hop flow ending at the `MACHI.MES` handoff), and +1
        # place_menu, the plain script's `27c-ev-k-talk` route (a two-hop returning flow).
        # Re-measured 2026-10-05 (EP-12 TALK rest unit): +90 map_return - the 88 rung routes of the
        # other eleven heroines' `01m-<letter>-talk` groups plus the three-hop `M_TALK` and `Q_TALK`
        # routes (`01m-m-talk`, `01m-q-talk`) - and +15 place_menu: their 8 plain scripts and the
        # characters' two-hop `N_TALK`, `N_TALK1`, `N_TALK2`, `N_TALK3`, `O_TALK`, `P_TALK`, `Q_TALK1`.
        # Re-measured 2026-10-05 (EP-12 TALK follow-ups): `n-talk-1` moves place_menu -> map_return (its
        # caller reaches the `FLOOR5.MES` handoff, a third hop): 432 / 427.
        self.assertEqual(
            self._census(self.profile_routes),
            {"map_return": 432, "place_menu": 427, "chain": 17, "not_triggered": 0, "unresolved": 2},
        )

    def test_profile_reentries_census(self) -> None:
        # Re-measured 2026-09-25 (EP-12 C..L date batch): +27 unresolved, one
        # per newly declared c..l-date route (a flow route's own hops are not
        # re-entered by another route the way a v6/v13 profile's own variants
        # are, so each route's own reentry census cell reads unresolved).
        # Re-measured 2026-09-25 (EP-12 PROMIS): +117 not_triggered, one per
        # declared 01m-<letter>-promis route (the callee returns at its own
        # `script_return` and a direct reentry from that exact record replays
        # no further message, the same shape as every other nested_call
        # route's own reentry cell).
        # Re-measured 2026-09-26 (EP-12 leftovers unit): +3 not_triggered
        # (A's own three newly-declared promis results 8-10, the same
        # not_triggered reentry shape every other declared promis route
        # already has) and +2 unresolved (d-date-hotel, l-date-date5 - two
        # more flow routes whose own reentry cell is unresolved, the same
        # shape every other flow route's own reentry cell already has).
        # Re-measured 2026-10-04 (EP-12 SCENE J unit): +25 unresolved, one per
        # `minatu-m-scene` flow route (`flow_reentry_undeclared`).
        # Re-measured 2026-10-04 (EP-12 SCENE all-menus unit): +340 unresolved,
        # one per route of the other twelve `<menu>-scene` profiles.
        # Re-measured 2026-10-04 (EP-12 H unit): +13 unresolved, one per
        # `43c-<name>-h` flow route (`flow_reentry_undeclared`).
        # Re-measured 2026-10-04 (EP-12 TALK K unit): +9 unresolved, one per K TALK
        # flow route (`flow_reentry_undeclared`).
        # Re-measured 2026-10-05 (EP-12 TALK rest unit): +105 unresolved, one per TALK
        # flow route of the other eleven heroines, Tina and the characters.
        self.assertEqual(
            self._census(self.profile_reentries),
            {"map_return": 52, "place_menu": 0, "chain": 2, "not_triggered": 263, "unresolved": 561},
        )

    def test_catalog_rows_census(self) -> None:
        # Re-measured 2026-09-24 (EP-12 catalog part): +3 map_return for the
        # three promoted a-date flow rows (each ends `script_handoff_boundary`
        # to MACHI.MES). Re-measured 2026-09-25 (EP-12 B date template unit):
        # +3 more map_return for the three promoted b-date flow rows, the
        # same terminal shape. Re-measured 2026-09-25 (EP-12 C..L date
        # batch): +24 map_return and +3 chain for the 27 newly promoted
        # c..l-date flow rows (the same split as test_profile_routes_census
        # above). Re-measured 2026-09-25 (EP-12 PROMIS checkpoint C): +12
        # map_return for the twelve newly promoted 01m-<letter>-promis rows
        # (each row's default option is a nested_call whose caller resume is
        # `natural_handoff` to `MACHI.MES`).
        # Re-measured 2026-09-26 (EP-12 leftovers unit): +1 map_return
        # (the newly promoted d-date-hotel flow row, `script_handoff_boundary`
        # to `MACHI.MES`) and +1 chain (the newly promoted l-date-date5 flow
        # row, ending at `44C.MES` like L's own hotel row already does).
        # Re-measured 2026-10-04 (EP-12 SCENE J unit): +25 place_menu, the
        # twenty-five `minatu-m-scene` rows (the last terminal of each is the
        # menu loop boundary that follows the scene's own return).
        # Re-measured 2026-10-04 (EP-12 SCENE all-menus unit): +340 place_menu,
        # the album scenes of the other twelve menus (365 album rows in all).
        # Re-measured 2026-10-04 (EP-12 H unit): +13 place_menu, the recollection
        # ladders of the room (`<name>.town.43c.h.1`).
        # Re-measured 2026-10-04 (EP-12 TALK K unit): +8 map_return, the eight rung rows
        # (`ai.town.station.talk-<band>.1`, each ending at the `MACHI.MES` handoff), and +1
        # place_menu, the plain script's row (`ai.town.27c_ev.talk-plain.1`).
        # Re-measured 2026-10-05 (EP-12 TALK rest unit): +90 map_return (the 88 rung rows of the other
        # eleven heroines, `tina.town.station.talk-plain.1`, `common.town.station.talk-q.1`) and +15
        # place_menu (the 8 plain rows and the seven two-hop character rows).
        # Re-measured 2026-10-05 (EP-12 TALK follow-ups): `n-talk-1` moves place_menu -> map_return
        # (its resume reaches the `FLOOR5.MES` handoff, a third hop): 255 / 415.
        self.assertEqual(
            self._census(self.catalog_rows),
            {"map_return": 255, "place_menu": 415, "chain": 11, "not_triggered": 0, "unresolved": 0},
        )

    def test_every_record_outcome_is_a_game_outcome(self) -> None:
        for records in (
            self.v4_results,
            self.v4_reentries,
            self.profile_routes,
            self.profile_reentries,
            self.catalog_rows,
        ):
            for record in records:
                self.assertIn(record["outcome"], GAME_OUTCOMES)

    def test_no_record_has_an_unknown_kind_reason(self) -> None:
        for records in (
            self.v4_results,
            self.v4_reentries,
            self.profile_routes,
            self.profile_reentries,
            self.catalog_rows,
        ):
            for record in records:
                self.assertFalse(
                    record["reason"].startswith("unknown_kind"),
                    f"unexpected unknown_kind reason: {record}",
                )


if __name__ == "__main__":
    unittest.main()
