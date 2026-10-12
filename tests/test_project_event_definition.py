"""Unit tests for the profile ("--site") path of project_event_definition.py
(WD-22 widening, part B). Synthetic inputs only: no archive, no package on
disk beyond what a test writes itself."""
from __future__ import annotations

import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

import project_event_definition as ped  # noqa: E402


def literal(value):
    return {"type": "literal", "value": value}


def cell(storage, index):
    return {"type": "state_ref", "storage": storage, "bank": 0, "index": literal(index)}


def binary(op, lhs, rhs):
    return {"type": "binary", "op": op, "lhs": lhs, "rhs": rhs}


def part(ast, text="part"):
    return {"text": text, "cells": [], "ast": ast}


def msg(entry, offset, end=None):
    return {"entry": entry, "offset": offset, "end": end if end is not None else offset + 1, "raw_sha256": "h%d" % offset}


def make_route(route_id, caller_entry="CALLER.MES", callee_entry="CALLEE.MES",
                expected_state=None, outcome=None, resume=None, reentry=None, variants=None):
    return {
        "route_id": route_id,
        "caller": {"entry": caller_entry, "offset": 100, "end": 110, "command": 15},
        "callee": {"entry": callee_entry, "offset": 0},
        "expected_state": expected_state or [],
        "outcome": outcome or {"offset": 500, "end": 501, "op": "command_00", "status": "script_return"},
        "resume": resume,
        "reentry": reentry,
        "variants": variants or [],
    }


def make_variant(variant_id, writes=None, expected_state=None, message_count=0):
    return {
        "variant_id": variant_id, "writes": writes or [],
        "expected_state": expected_state or [], "message_count": message_count,
    }


def make_replay_variant(messages, final_state=None, terminal=None, selections=None):
    return {
        "messages": messages,
        "final_state": final_state or [],
        "terminal": terminal or {"entry": "CALLEE.MES", "status": "script_return", "offset": 500, "target": ""},
        "selections": selections or [],
    }


class MapConjunctTests(unittest.TestCase):
    def test_weekday(self):
        row = ped.map_conjunct(part(binary("equal", cell("state_u16", 4), literal(6))))
        self.assertEqual(row, {"kind": "weekday", "op": "equal", "value": 6})

    def test_date(self):
        row = ped.map_conjunct(part(binary("not_equal", cell("state_u16", 7), literal(501))))
        self.assertEqual(row, {"kind": "date", "op": "not_equal", "value": 501})

    def test_clock(self):
        row = ped.map_conjunct(part(binary("greater_than", cell("state_u16", 19), literal(1530))))
        self.assertEqual(row, {"kind": "clock", "op": "greater_than", "value": 1530})

    def test_choice(self):
        row = ped.map_conjunct(part(binary("equal", cell("state_u16", 21), literal(1))))
        self.assertEqual(row, {"kind": "choice", "op": "equal", "value": 1})

    def test_affection_uses_supplied_letter_table(self):
        row = ped.map_conjunct(
            part(binary("greater_than", cell("banked_u16", 208), literal(80))),
            affection_letters={208: "ai"},
        )
        self.assertEqual(row, {"kind": "affection", "heroine": "ai", "op": "greater_than", "value": 80})

    def test_affection_index_without_a_verified_letter_falls_back_to_cell(self):
        # Production always calls with affection_letters=None (see
        # AFFECTION_HEROINE_LETTERS): no verified banked_u16 index -> letter
        # table exists, so every affection-range conjunct is a `cell` row.
        row = ped.map_conjunct(part(binary("greater_than", cell("banked_u16", 208), literal(80))))
        self.assertEqual(
            row, {"kind": "cell", "storage": "banked_u16", "bank": 0, "index": 208, "op": "greater_than", "value": 80}
        )

    def test_cell(self):
        row = ped.map_conjunct(part(binary("equal", cell("global_u8", 351), literal(8))))
        self.assertEqual(row, {"kind": "cell", "storage": "global_u8", "bank": 0, "index": 351, "op": "equal", "value": 8})

    def test_mes_expression_for_a_non_simple_conjunct(self):
        ast = binary("logical_or", binary("equal", cell("state_u16", 4), literal(0)),
                     binary("equal", cell("state_u16", 4), literal(6)))
        row = ped.map_conjunct(part(ast))
        self.assertEqual(row, {"kind": "mes_expression", "ast": ast})

    def test_mes_expression_for_a_cell_compared_with_a_cell(self):
        ast = binary("equal", cell("state_u16", 8), cell("state_u16", 9))
        row = ped.map_conjunct(part(ast))
        self.assertEqual(row["kind"], "mes_expression")


class CatalogTerminalKindTests(unittest.TestCase):
    def test_root_replacement_stays_root_handoff(self):
        self.assertEqual(ped.catalog_terminal_kind({"kind": "root_replacement"}), "root_handoff")

    def test_normal_completion_is_root_handoff(self):
        self.assertEqual(ped.catalog_terminal_kind({"kind": "normal_completion"}), "root_handoff")

    def test_callee_return_only_is_callee_return(self):
        self.assertEqual(ped.catalog_terminal_kind({"kind": "callee_return_only"}), "callee_return")

    def test_caller_handoff_is_natural_handoff(self):
        self.assertEqual(ped.catalog_terminal_kind({"kind": "caller_handoff"}), "natural_handoff")

    def test_caller_postlude_is_natural_handoff(self):
        self.assertEqual(ped.catalog_terminal_kind({"kind": "caller_postlude"}), "natural_handoff")

    def test_analysis_boundary_with_def_selection_boundary_status(self):
        row = {"kind": "analysis_boundary", "runtime_status": "def_selection_boundary"}
        self.assertEqual(ped.catalog_terminal_kind(row), "def_selection_boundary")

    def test_analysis_boundary_with_any_other_status_is_dependency_stop(self):
        row = {"kind": "analysis_boundary", "runtime_status": "shared_routine_boundary"}
        self.assertEqual(ped.catalog_terminal_kind(row), "dependency_stop")

    def test_unknown_kind_passes_through_unmapped(self):
        self.assertEqual(ped.catalog_terminal_kind({"kind": "something_else"}), "something_else")


class TerminalFromRouteTests(unittest.TestCase):
    def test_script_handoff_boundary_is_root_handoff_owned_by_callee(self):
        route = make_route("r1", outcome={"offset": 10, "end": 20, "status": "script_handoff_boundary", "target": "MACHI.MES"})
        terminals = ped.terminal_from_route(route, "CALLER.MES", "CALLEE.MES")
        self.assertEqual(terminals["r1.outcome"], {
            "kind": "root_handoff", "owner_entry": "CALLEE.MES", "offset": 10, "end": 20,
            "next_target": "MACHI.MES", "required_state": [],
        })

    def test_script_return_is_callee_return(self):
        route = make_route("r1", outcome={"offset": 30, "end": 31, "status": "script_return"})
        terminals = ped.terminal_from_route(route, "CALLER.MES", "CALLEE.MES")
        self.assertEqual(terminals["r1.outcome"], {
            "kind": "callee_return", "owner_entry": "CALLEE.MES", "offset": 30, "end": 31, "required_state": [],
        })

    def test_def_selection_boundary_outcome_falls_back_to_callee_owner(self):
        route = make_route("r1", outcome={"offset": 40, "end": 45, "status": "def_selection_boundary"})
        terminals = ped.terminal_from_route(route, "CALLER.MES", "CALLEE.MES")
        self.assertEqual(terminals["r1.outcome"]["owner_entry"], "CALLEE.MES")
        self.assertEqual(terminals["r1.outcome"]["kind"], "def_selection_boundary")

    def test_natural_handoff_resume_is_owned_by_caller(self):
        route = make_route("r1", resume={
            "boundary_policy": "natural_handoff",
            "outcome": {"offset": 200, "end": 210, "target": "MACHI.MES"},
        })
        terminals = ped.terminal_from_route(route, "CALLER.MES", "CALLEE.MES")
        self.assertEqual(terminals["r1.resume"], {
            "kind": "natural_handoff", "owner_entry": "CALLER.MES", "offset": 200, "end": 210,
            "next_target": "MACHI.MES", "required_state": [],
        })

    def test_def_selection_boundary_resume_is_owned_by_caller(self):
        route = make_route("r1", resume={
            "boundary_policy": "def_selection_boundary",
            "outcome": {"offset": 300, "end": 305},
        })
        terminals = ped.terminal_from_route(route, "CALLER.MES", "CALLEE.MES")
        self.assertEqual(terminals["r1.resume"], {
            "kind": "def_selection_boundary", "owner_entry": "CALLER.MES", "offset": 300, "end": 305,
            "required_state": [],
        })

    def test_caller_menu_loop_resume_carries_period_and_cycle(self):
        route = make_route("r1", resume={
            "boundary_policy": "caller_menu_loop",
            "outcome": {"offset": 400, "end": 405},
            "loop": {"period": 7, "period_message_count": 9, "cycle": [{"entry": "X.MES", "offset": 1}]},
        })
        terminals = ped.terminal_from_route(route, "CALLER.MES", "CALLEE.MES")
        self.assertEqual(terminals["r1.resume"]["kind"], "caller_menu_loop")
        self.assertEqual(terminals["r1.resume"]["owner_entry"], "CALLER.MES")
        self.assertEqual(terminals["r1.resume"]["resume"], {"period": 7, "cycle": [{"entry": "X.MES", "offset": 1}]})

    def test_stop_before_unprovided_dependency_resume_is_dependency_stop(self):
        route = make_route("r1", resume={
            "boundary_policy": "stop_before_unprovided_dependency",
            "outcome": {"offset": 500, "end": 516, "target": "EVENTK01.MES"},
        })
        terminals = ped.terminal_from_route(route, "CALLER.MES", "CALLEE.MES")
        self.assertEqual(terminals["r1.resume"], {
            "kind": "dependency_stop", "owner_entry": "CALLER.MES", "offset": 500, "end": 516,
            "required_state": [],
        })

    def test_unknown_boundary_policy_raises(self):
        route = make_route("r1", resume={"boundary_policy": "mystery", "outcome": {"offset": 1, "end": 2}})
        with self.assertRaises(ValueError):
            ped.terminal_from_route(route, "CALLER.MES", "CALLEE.MES")


class DedupeTerminalsTests(unittest.TestCase):
    def test_identical_terminals_across_routes_collapse_to_one_id(self):
        route1 = make_route("r1", outcome={"offset": 500, "end": 501, "status": "script_return"})
        route2 = make_route("r2", outcome={"offset": 500, "end": 501, "status": "script_return"})
        raw = {}
        raw.update(ped.terminal_from_route(route1, "CALLER.MES", "CALLEE.MES"))
        raw.update(ped.terminal_from_route(route2, "CALLER.MES", "CALLEE.MES"))
        deduped, remap = ped.dedupe_terminals(raw)
        self.assertEqual(len(deduped), 1)
        self.assertEqual(remap["r1.outcome"], remap["r2.outcome"])
        self.assertIn(remap["r1.outcome"], deduped)


class GroupResultsTests(unittest.TestCase):
    def test_two_variants_with_identical_outcomes_collapse_into_one_default_result(self):
        route = make_route("r1", expected_state=[{"storage": "global_u8", "bank": 0, "index": 50, "value": 0}])
        candidates = [
            ped.build_candidate(route, make_variant("baseline"),
                                 make_replay_variant([msg("CALLEE.MES", 10)],
                                                      final_state=[{"storage": "global_u8", "bank": 0, "index": 50, "value": 1}])),
            ped.build_candidate(route, make_variant("edge", writes=[{"storage": "global_u8", "bank": 0, "index": 60, "value": 5}]),
                                 make_replay_variant([msg("CALLEE.MES", 10)],
                                                      final_state=[{"storage": "global_u8", "bank": 0, "index": 50, "value": 1}])),
        ]
        results, choice_info, kind, unresolved = ped.group_results(candidates, None, None, consumed=0)
        self.assertIsNone(choice_info)
        self.assertEqual(kind, "event")
        self.assertEqual(unresolved, [])
        self.assertEqual(list(results.keys()), ["result_default"])
        self.assertEqual(results["result_default"]["selected_by"], {"kind": "default"})
        self.assertEqual(len(results["result_default"]["group"]), 2)

    def test_a_differing_final_state_no_longer_splits_the_result(self):
        # Rule A (2026-09-16 correction): the signature is the message
        # sequence and the callee terminal only. Two candidates that share
        # both, but disagree on a variant-declared expected_state cell,
        # still collapse into one result; the disagreement is reported in
        # `unresolved`, not as a second result.
        route = make_route("r1")
        variant_a = make_variant("baseline", expected_state=[{"storage": "global_u8", "bank": 0, "index": 50, "value": 0}])
        variant_b = make_variant("other", writes=[{"storage": "global_u8", "bank": 0, "index": 60, "value": 5}],
                                  expected_state=[{"storage": "global_u8", "bank": 0, "index": 50, "value": 0}])
        candidates = [
            ped.build_candidate(route, variant_a,
                                 make_replay_variant([msg("CALLEE.MES", 10)],
                                                      final_state=[{"storage": "global_u8", "bank": 0, "index": 50, "value": 1}])),
            ped.build_candidate(route, variant_b,
                                 make_replay_variant([msg("CALLEE.MES", 10)],
                                                      final_state=[{"storage": "global_u8", "bank": 0, "index": 50, "value": 2}])),
        ]
        results, choice_info, kind, unresolved = ped.group_results(candidates, None, None, consumed=0)
        self.assertEqual(list(results.keys()), ["result_default"])
        self.assertEqual(results["result_default"]["selected_by"], {"kind": "default"})
        self.assertEqual(len(results["result_default"]["group"]), 2)
        self.assertEqual(unresolved, [])  # group_results itself is silent; group_after_effects reports it

    def test_several_groups_use_writes_exclusive_to_the_group_not_merely_common_within_it(self):
        # W1 is common to every candidate in both groups (not distinguishing
        # at all); W2 is exclusive to group 1. Rule A: group 1's condition
        # is W2 only; group 2 has nothing exclusive, so it falls back to
        # cond_unresolved. Neither group is `default` - there are two of them.
        route = make_route("r1")
        w1 = {"storage": "global_u8", "bank": 0, "index": 70, "value": 9}
        w2 = {"storage": "global_u8", "bank": 0, "index": 71, "value": 3}

        def cand(offset, writes):
            return ped.build_candidate(route, make_variant("v", writes=writes), make_replay_variant([msg("CALLEE.MES", offset)]))

        candidates = [
            cand(10, [w1, w2]), cand(10, [w1, w2]),  # group 1 (message offset 10)
            cand(20, [w1]), cand(20, [w1]),           # group 2 (message offset 20)
        ]
        results, choice_info, kind, unresolved = ped.group_results(candidates, None, None, consumed=0)
        self.assertEqual(len(results), 2)
        self.assertNotIn({"kind": "default"}, [r["selected_by"] for r in results.values()])
        self.assertIn("cond_global_u8_71_3", results)
        self.assertEqual(results["cond_global_u8_71_3"]["selected_by"], {
            "kind": "condition",
            "conditions": [{"storage": "global_u8", "bank": 0, "index": 71, "operator": "equals", "value": 3}],
        })
        unresolved_ids = [rid for rid in results if rid.startswith("result_unresolved_")]
        self.assertEqual(len(unresolved_ids), 1)
        self.assertEqual(results[unresolved_ids[0]]["selected_by"], {"kind": "condition", "conditions": []})
        self.assertEqual(len(unresolved), 1)
        self.assertIn("differ without a distinguishing write", unresolved[0])

    def test_a_caller_question_partition_nests_a_second_boundary(self):
        route_a = make_route("route-a")
        route_b = make_route("route-b")
        top_contract = {"boundary_offset": 900}
        second_contract = {"boundary_offset": 950}

        def cand(route, variant_id, offset, top_value, second_value):
            variant = make_variant(variant_id)
            replay = make_replay_variant(
                [msg("CALLEE.MES", offset)],
                selections=[
                    {"boundary_offset": 900, "owner_entry": "CALLER.MES", "result_value": top_value},
                    {"boundary_offset": 950, "owner_entry": "CALLEE.MES", "result_value": second_value},
                ],
            )
            return ped.build_candidate(route, variant, replay)

        candidates = [
            cand(route_a, "baseline", 10, 1, 1),
            cand(route_b, "baseline", 20, 1, 2),
        ]
        results, choice_info, kind, unresolved = ped.group_results(candidates, top_contract, second_contract, consumed=0)
        self.assertEqual(kind, "choice_event")
        self.assertEqual(choice_info["order"], [1])
        self.assertEqual(list(results.keys()), ["answer1"])
        outer = results["answer1"]
        self.assertEqual(outer["selected_by"], {"kind": "choice", "value": 1})
        self.assertIsNotNone(outer["choice"])
        self.assertEqual(outer["choice"]["boundary"], 950)
        self.assertEqual(outer["choice"]["order"], [1, 2])
        self.assertEqual(set(outer["results"].keys()), {"answer1", "answer2"})
        self.assertEqual(outer["results"]["answer1"]["selected_by"], {"kind": "choice", "value": 1})
        self.assertEqual(outer["results"]["answer2"]["selected_by"], {"kind": "choice", "value": 2})

    def test_a_caller_question_answer_with_no_messages_and_no_callee_entry_skips_the_event(self):
        route = make_route("route-skip")
        top_contract = {"boundary_offset": 900}
        variant = make_variant("baseline", message_count=0)
        replay = make_replay_variant([], selections=[{"boundary_offset": 900, "owner_entry": "CALLER.MES", "result_value": 2}])
        candidate = ped.build_candidate(route, variant, replay)
        results, choice_info, kind, unresolved = ped.group_results([candidate], top_contract, None, consumed=0)
        self.assertFalse(results["answer2"]["event_played"])
        self.assertEqual(results["answer2"]["dialogue_messages"], [])


class GroupAfterEffectsTests(unittest.TestCase):
    def test_a_cell_every_candidate_in_the_group_agrees_on_becomes_an_after_row(self):
        route = make_route("r1")
        variant_a = make_variant("a", expected_state=[{"storage": "global_u8", "bank": 0, "index": 50, "value": 0}])
        variant_b = make_variant("b", expected_state=[{"storage": "global_u8", "bank": 0, "index": 50, "value": 0}])
        ca = ped.build_candidate(route, variant_a, make_replay_variant(
            [msg("CALLEE.MES", 10)], final_state=[{"storage": "global_u8", "bank": 0, "index": 50, "value": 1}]))
        cb = ped.build_candidate(route, variant_b, make_replay_variant(
            [msg("CALLEE.MES", 10)], final_state=[{"storage": "global_u8", "bank": 0, "index": 50, "value": 1}]))
        unresolved = []
        after = ped.group_after_effects([ca, cb], set(), unresolved)
        self.assertEqual(after, [{"type": "write_legacy_value", "storage": "global_u8", "bank": 0, "index": 50, "value": 1}])
        self.assertEqual(unresolved, [])

    def test_a_cell_the_group_disagrees_on_is_reported_unresolved_not_written(self):
        route = make_route("r1")
        variant_a = make_variant("a", expected_state=[{"storage": "global_u8", "bank": 0, "index": 50, "value": 0}])
        variant_b = make_variant("b", expected_state=[{"storage": "global_u8", "bank": 0, "index": 50, "value": 0}])
        ca = ped.build_candidate(route, variant_a, make_replay_variant(
            [msg("CALLEE.MES", 10)], final_state=[{"storage": "global_u8", "bank": 0, "index": 50, "value": 1}]))
        cb = ped.build_candidate(route, variant_b, make_replay_variant(
            [msg("CALLEE.MES", 10)], final_state=[{"storage": "global_u8", "bank": 0, "index": 50, "value": 2}]))
        unresolved = []
        after = ped.group_after_effects([ca, cb], set(), unresolved)
        self.assertEqual(after, [])
        self.assertEqual(
            unresolved,
            ["effect on global_u8[50] depends on the entry state (observed final values [1, 2]); v3 has no delta effect"],
        )

    def test_a_cell_already_in_the_body_after_is_skipped(self):
        route = make_route("r1")
        variant_a = make_variant("a", expected_state=[{"storage": "global_u8", "bank": 0, "index": 50, "value": 0}])
        ca = ped.build_candidate(route, variant_a, make_replay_variant(
            [msg("CALLEE.MES", 10)], final_state=[{"storage": "global_u8", "bank": 0, "index": 50, "value": 1}]))
        unresolved = []
        after = ped.group_after_effects([ca], {("global_u8", 0, 50)}, unresolved)
        self.assertEqual(after, [])
        self.assertEqual(unresolved, [])


class FindDoneCellTests(unittest.TestCase):
    def test_matches_a_guard_conjunct_to_the_routes_own_expected_state(self):
        route = make_route("r1", expected_state=[{"storage": "global_u8", "bank": 0, "index": 905, "value": 1}])
        conjunct_rows = [{"kind": "cell", "storage": "global_u8", "bank": 0, "index": 905, "op": "equal", "value": 0}]
        self.assertEqual(ped.find_done_cell(conjunct_rows, route), 905)

    def test_matches_a_guard_conjunct_when_every_variant_agrees(self):
        route = make_route("r1", variants=[
            {"variant_id": "a", "writes": [],
             "expected_state": [{"storage": "global_u8", "bank": 0, "index": 905, "value": 1}]},
            {"variant_id": "b", "writes": [],
             "expected_state": [{"storage": "global_u8", "bank": 0, "index": 905, "value": 1}]},
        ])
        conjunct_rows = [{"kind": "cell", "storage": "global_u8", "bank": 0, "index": 905, "op": "equal", "value": 0}]
        self.assertEqual(ped.find_done_cell(conjunct_rows, route), 905)

    def test_no_match_when_not_every_variant_agrees(self):
        route = make_route("r1", variants=[
            {"variant_id": "a", "writes": [],
             "expected_state": [{"storage": "global_u8", "bank": 0, "index": 905, "value": 1}]},
            {"variant_id": "b", "writes": [], "expected_state": []},
        ])
        conjunct_rows = [{"kind": "cell", "storage": "global_u8", "bank": 0, "index": 905, "op": "equal", "value": 0}]
        self.assertIsNone(ped.find_done_cell(conjunct_rows, route))

    def test_no_match_without_a_qualifying_conjunct(self):
        route = make_route("r1", expected_state=[{"storage": "global_u8", "bank": 0, "index": 905, "value": 1}])
        conjunct_rows = [{"kind": "weekday", "op": "equal", "value": 2}]
        self.assertIsNone(ped.find_done_cell(conjunct_rows, route))

    def test_wrong_operator_or_value_does_not_match(self):
        route = make_route("r1", expected_state=[{"storage": "global_u8", "bank": 0, "index": 905, "value": 1}])
        conjunct_rows = [{"kind": "cell", "storage": "global_u8", "bank": 0, "index": 905, "op": "not_equal", "value": 0}]
        self.assertIsNone(ped.find_done_cell(conjunct_rows, route))


class ReproductionAssertionTests(unittest.TestCase):
    def test_leaf_raises_when_group_members_do_not_share_the_full_message_list(self):
        route = make_route("r1")
        candidates = [
            ped.build_candidate(route, make_variant("a"), make_replay_variant([msg("CALLEE.MES", 10)])),
            ped.build_candidate(route, make_variant("b"), make_replay_variant([msg("CALLEE.MES", 20)])),
        ]
        with self.assertRaises(ped.ReproductionMismatch):
            ped._leaf(candidates, consumed=0)

    def test_leaf_accepts_a_group_that_shares_the_full_message_list(self):
        route = make_route("r1")
        shared = [msg("CALLEE.MES", 10), msg("CALLEE.MES", 20)]
        candidates = [
            ped.build_candidate(route, make_variant("a"), make_replay_variant(list(shared))),
            ped.build_candidate(route, make_variant("b"), make_replay_variant(list(shared))),
        ]
        node = ped._leaf(candidates, consumed=1)
        self.assertEqual(node["dialogue_messages"], [shared[1]])


class ChooseContractsTests(unittest.TestCase):
    def test_caller_owned_contract_is_top_level(self):
        route = make_route("r1", variants=[{
            "variant_id": "baseline", "writes": [],
            "selections": [
                {"boundary_offset": 900, "owner_entry": "CALLER.MES"},
                {"boundary_offset": 950, "owner_entry": "CALLEE.MES"},
            ],
        }])
        route["choice_contracts"] = [{"boundary_offset": 950}, {"boundary_offset": 900}]
        top, second = ped.choose_contracts(route)
        self.assertEqual(top["boundary_offset"], 900)
        self.assertEqual(second["boundary_offset"], 950)

    def test_no_caller_owned_contract_falls_back_to_smallest_boundary(self):
        route = make_route("r1", variants=[{
            "variant_id": "baseline", "writes": [],
            "selections": [
                {"boundary_offset": 900, "owner_entry": "CALLEE.MES"},
                {"boundary_offset": 950, "owner_entry": "CALLEE.MES"},
            ],
        }])
        route["choice_contracts"] = [{"boundary_offset": 950}, {"boundary_offset": 900}]
        top, second = ped.choose_contracts(route)
        self.assertEqual(top["boundary_offset"], 900)
        self.assertEqual(second["boundary_offset"], 950)

    def test_no_contracts_returns_none(self):
        route = make_route("r1")
        self.assertEqual(ped.choose_contracts(route), (None, None))


if __name__ == "__main__":
    unittest.main()
