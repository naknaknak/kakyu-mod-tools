"""Unit tests for `tools/project_event_definition_v4.py` (event definition
v4 unit 2b): the rules of `analysis/_docs/v4_unit2b_producer_spec.md`
section A on synthetic inputs only - no archive, no package on disk beyond
what a test writes itself. v3's own tests
(`tests.test_project_event_definition`) are untouched and keep passing."""
from __future__ import annotations

import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

import project_event_definition_v4 as p4  # noqa: E402
import state_cells  # noqa: E402


def msg(entry, offset, end=None):
    return {"entry": entry, "offset": offset, "end": end if end is not None else offset + 1, "raw_sha256": "h%d" % offset}


def state_change(storage, index, before, after, bank=0):
    return {"storage": storage, "bank": bank, "index": index, "before": before, "after": after}


class MarkedTimelineTests(unittest.TestCase):
    """rule 1: candidates and the flow - marker placement."""

    def _replay_variant(self, prefix, scene, resume_messages=None, selections=None, terminal=None,
                         resume_terminal=None):
        resume = None
        if resume_messages is not None:
            resume = {"messages": resume_messages, "terminal": resume_terminal or {
                "entry": "CALLER.MES", "status": "script_handoff_boundary", "offset": 9000, "target": "MACHI.MES",
            }}
        return {
            "prefix_messages": prefix, "messages": scene, "resume": resume,
            "selections": selections or [], "state_changes": {},
            "terminal": terminal or {"entry": "CALLEE.MES", "status": "script_return", "offset": 500, "target": ""},
        }

    def test_scene_end_after_the_scene_when_the_callee_emitted_something(self):
        prefix = [msg("CALLER.MES", 10)]
        scene = [msg("CALLEE.MES", 100), msg("CALLEE.MES", 101)]
        rv = self._replay_variant(prefix, scene)
        route = {"route_id": "r0"}
        variant = {"variant_id": "v0", "writes": [], "expected_state": []}
        c = p4.build_candidate_v4(route, variant, rv, None, None, "CALLER.MES", "CALLEE.MES")
        kinds = [m.get("_marker_kind") or m["entry"] for m in c["messages"]]
        self.assertEqual(kinds, ["CALLER.MES", "CALLEE.MES", "CALLEE.MES", "scene_end"])
        self.assertTrue(c["event_played"])

    def test_no_scene_end_when_the_callee_emits_nothing(self):
        rv = self._replay_variant([msg("CALLER.MES", 10)], [])
        route = {"route_id": "r0"}
        variant = {"variant_id": "v0", "writes": [], "expected_state": []}
        c = p4.build_candidate_v4(route, variant, rv, None, None, "CALLER.MES", "CALLEE.MES")
        self.assertFalse(any(m.get("_marker_kind") == "scene_end" for m in c["messages"]))
        self.assertFalse(c["event_played"])

    def test_resume_messages_follow_the_scene_end_marker(self):
        prefix = [msg("CALLER.MES", 10)]
        scene = [msg("CALLEE.MES", 100)]
        resume = [msg("CALLER.MES", 900), msg("CALLER.MES", 901)]
        rv = self._replay_variant(prefix, scene, resume_messages=resume)
        route = {"route_id": "r0"}
        variant = {"variant_id": "v0", "writes": [], "expected_state": []}
        c = p4.build_candidate_v4(route, variant, rv, None, None, "CALLER.MES", "CALLEE.MES")
        offsets = [m.get("_marker_kind") or m["offset"] for m in c["messages"]]
        self.assertEqual(offsets, [10, 100, "scene_end", 900, 901])
        # the resume terminal, not the scene terminal, is the candidate's own
        self.assertEqual(c["terminal_sig"], ("CALLER.MES", "script_handoff_boundary", 9000, "MACHI.MES"))

    def test_choice_point_before_the_first_owner_message_past_the_boundary(self):
        prefix = [msg("CALLER.MES", 10), msg("CALLER.MES", 20), msg("CALLER.MES", 30)]
        scene = [msg("CALLEE.MES", 100)]
        rv = self._replay_variant(prefix, scene, selections=[{"boundary_offset": 15, "result_value": 0}])
        route = {"route_id": "r0", "caller": {"entry": "CALLER.MES"}}
        variant = {"variant_id": "v0", "writes": [], "expected_state": []}
        top_contract = {"boundary_offset": 15, "source_identity": {"entry": "CALLER.MES"}}
        c = p4.build_candidate_v4(route, variant, rv, top_contract, None, "CALLER.MES", "CALLEE.MES")
        markers = [(i, m.get("_marker_choice")) for i, m in enumerate(c["messages"]) if m.get("_marker_kind") == "choice_point"]
        self.assertEqual(markers, [(1, "top")])  # before offset 20, the first CALLER message past boundary 15

    def test_choice_point_at_the_end_of_the_owner_segment_when_nothing_follows(self):
        prefix = [msg("CALLER.MES", 10)]
        scene = [msg("CALLEE.MES", 100), msg("CALLEE.MES", 101)]
        rv = self._replay_variant(prefix, scene, selections=[{"boundary_offset": 105, "result_value": 0}])
        route = {"route_id": "r0", "caller": {"entry": "CALLER.MES"}}
        variant = {"variant_id": "v0", "writes": [], "expected_state": []}
        # owner is the callee, whose last message is at offset 101, so nothing
        # of its own exceeds the boundary (105): marker lands right after it.
        top_contract = {"boundary_offset": 105, "source_identity": {"entry": "CALLEE.MES"}}
        c = p4.build_candidate_v4(route, variant, rv, top_contract, None, "CALLER.MES", "CALLEE.MES")
        idx = next(i for i, m in enumerate(c["messages"]) if m.get("_marker_kind") == "choice_point")
        self.assertEqual(idx, 3)  # after CALLER@10, CALLEE@100, CALLEE@101, then the marker, then scene_end

    def test_build_candidate_only_inserts_the_top_marker(self):
        # A nested (second-boundary) marker is not inserted here at all: see
        # build_candidate_v4's own docstring and _insert_choice_marker below
        # for where and why (run_site inserts it once a genuine nested
        # `choice` is known to exist for that node).
        prefix = [msg("CALLER.MES", 10)]
        scene = [msg("CALLEE.MES", 100), msg("CALLEE.MES", 200), msg("CALLEE.MES", 300)]
        rv = self._replay_variant(prefix, scene, selections=[
            {"boundary_offset": 15, "result_value": 2},
            {"boundary_offset": 150, "result_value": 5},
        ])
        route = {"route_id": "r0", "caller": {"entry": "CALLER.MES"}}
        variant = {"variant_id": "v0", "writes": [], "expected_state": []}
        top_contract = {"boundary_offset": 15, "source_identity": {"entry": "CALLER.MES"}}
        second_contract = {"boundary_offset": 150, "source_identity": {"entry": "CALLEE.MES"}}
        c = p4.build_candidate_v4(route, variant, rv, top_contract, second_contract, "CALLER.MES", "CALLEE.MES")
        choices = [m.get("_marker_choice") for m in c["messages"] if m.get("_marker_kind") == "choice_point"]
        self.assertEqual(choices, ["top"])

    def test_insert_choice_marker_labels_a_nested_choice_by_its_containing_result(self):
        pairs = [(msg("CALLEE.MES", 100), False), (msg("CALLEE.MES", 200), False), (msg("CALLEE.MES", 300), False)]
        p4._insert_choice_marker(pairs, 150, "CALLEE.MES", "answer2")
        choices = [(i, m.get("_marker_choice")) for i, (m, _pfx) in enumerate(pairs) if m.get("_marker_kind") == "choice_point"]
        self.assertEqual(choices, [(1, "answer2")])  # before CALLEE@200, the first past boundary 150


class ClockAdvanceTests(unittest.TestCase):
    def test_plain_advance(self):
        self.assertEqual(p4.clock_advance_minutes(930, 1000), 30)

    def test_wrap_past_midnight_is_positive(self):
        self.assertEqual(p4.clock_advance_minutes(2340, 10), 30)

    def test_non_hhmm_value_is_none(self):
        self.assertIsNone(p4.clock_advance_minutes(2500, 10))
        self.assertIsNone(p4.clock_advance_minutes(930, 9961))

    def test_zero_net_advance_is_none(self):
        self.assertIsNone(p4.clock_advance_minutes(930, 930))


class DecideEffectsTests(unittest.TestCase):
    def _candidate(self, route_id, variant_id, net_changes, declared_keys=None):
        return {
            "route_id": route_id, "variant_id": variant_id,
            "net_changes": net_changes, "declared_keys": declared_keys or set(),
        }

    def test_clock_cell_becomes_consume_time(self):
        group = [self._candidate("r", "baseline", {("state_u16", 0, 19): {"before": 930, "after": 1000}})]
        unresolved = []
        rows, evidence = p4.decide_effects_for_group(group, "result_default", state_cells.load(), {}, unresolved)
        self.assertEqual(rows, [{"type": "consume_time", "minutes": 30, "cell_class": "clock"}])
        self.assertEqual(evidence[0]["basis"], "clock")
        self.assertEqual(unresolved, [])

    def test_clock_cell_inconsistent_advance_is_unresolved(self):
        group = [
            self._candidate("r", "v1", {("state_u16", 0, 19): {"before": 930, "after": 1000}}),
            self._candidate("r", "v2", {("state_u16", 0, 19): {"before": 930, "after": 1030}}),
        ]
        unresolved = []
        rows, evidence = p4.decide_effects_for_group(group, "result_default", state_cells.load(), {}, unresolved)
        self.assertEqual(rows, [])
        self.assertEqual(len(unresolved), 1)

    def test_flag_pattern_needs_no_witness(self):
        group = [self._candidate("r", "baseline", {("global_u8", 0, 905): {"before": 0, "after": 1}})]
        rows, evidence = p4.decide_effects_for_group(group, "result_default", state_cells.load(), {}, [])
        self.assertEqual(rows, [{"type": "write_legacy_value", "storage": "global_u8", "bank": 0, "index": 905, "value": 1, "cell_class": "flag"}])
        self.assertEqual(evidence[0]["basis"], "flag_pattern")

    def test_entries_vary_single_final_is_a_write(self):
        group = [
            self._candidate("r", "v1", {("banked_u16", 0, 201): {"before": 10, "after": 92}}),
            self._candidate("r", "v2", {("banked_u16", 0, 201): {"before": 50, "after": 92}}),
        ]
        rows, evidence = p4.decide_effects_for_group(group, "result_default", state_cells.load(), {}, [])
        self.assertEqual(rows[0], {"type": "write_legacy_value", "storage": "banked_u16", "bank": 0, "index": 201, "value": 92, "cell_class": "affection"})
        self.assertEqual(evidence[0]["basis"], "variants")

    def test_entries_vary_single_delta_is_an_add(self):
        group = [
            self._candidate("r", "v1", {("banked_u16", 0, 204): {"before": 10, "after": 11}}),
            self._candidate("r", "v2", {("banked_u16", 0, 204): {"before": 50, "after": 51}}),
        ]
        rows, evidence = p4.decide_effects_for_group(group, "result_default", state_cells.load(), {}, [])
        self.assertEqual(rows[0]["type"], "add_legacy_value")
        self.assertEqual(rows[0]["delta"], 1)
        self.assertEqual(evidence[0]["basis"], "variants")

    def test_entries_vary_without_a_single_final_or_delta_is_unresolved(self):
        group = [
            self._candidate("r", "v1", {("banked_u16", 0, 204): {"before": 10, "after": 12}}),
            self._candidate("r", "v2", {("banked_u16", 0, 204): {"before": 50, "after": 53}}),
        ]
        unresolved = []
        rows, evidence = p4.decide_effects_for_group(group, "result_default", state_cells.load(), {}, unresolved)
        self.assertEqual(rows, [])
        self.assertEqual(len(unresolved), 1)

    def test_ambiguous_entries_use_the_shift_witness_set(self):
        group = [self._candidate("r", "baseline", {("banked_u16", 0, 203): {"before": 60, "after": 25}})]
        witness_index = {("r", "baseline", ("banked_u16", 0, 203)): {
            "kind": "set", "entry": 60, "final": 25, "step": 7, "shifted_entry": 67, "shifted_final": 25,
        }}
        rows, evidence = p4.decide_effects_for_group(group, "answer3", state_cells.load(), witness_index, [])
        self.assertEqual(rows[0], {"type": "write_legacy_value", "storage": "banked_u16", "bank": 0, "index": 203, "value": 25, "cell_class": "affection"})
        self.assertEqual(evidence[0]["basis"], "shift_witness")

    def test_ambiguous_entries_use_the_shift_witness_add(self):
        group = [self._candidate("r", "baseline", {("banked_u16", 0, 204): {"before": 80, "after": 81}})]
        witness_index = {("r", "baseline", ("banked_u16", 0, 204)): {
            "kind": "add", "entry": 80, "final": 81, "step": 7, "shifted_entry": 87, "shifted_final": 88,
        }}
        rows, evidence = p4.decide_effects_for_group(group, "result_default", state_cells.load(), witness_index, [])
        self.assertEqual(rows[0]["type"], "add_legacy_value")
        self.assertEqual(rows[0]["delta"], 1)

    def test_ambiguous_entries_other_kind_is_unresolved(self):
        group = [self._candidate("r", "baseline", {("banked_u16", 0, 207): {"before": 5, "after": 8}})]
        witness_index = {("r", "baseline", ("banked_u16", 0, 207)): {
            "kind": "other", "entry": 5, "final": 8, "step": 7, "shifted_entry": 12, "shifted_final": 12,
        }}
        unresolved = []
        rows, evidence = p4.decide_effects_for_group(group, "result_default", state_cells.load(), witness_index, unresolved)
        self.assertEqual(rows, [])
        self.assertEqual(len(unresolved), 1)

    def test_missing_witness_is_unresolved(self):
        group = [self._candidate("r", "baseline", {("banked_u16", 0, 207): {"before": 5, "after": 8}})]
        unresolved = []
        rows, evidence = p4.decide_effects_for_group(group, "result_default", state_cells.load(), {}, unresolved)
        self.assertEqual(rows, [])
        self.assertEqual(len(unresolved), 1)


class PromoteSharedRowsTests(unittest.TestCase):
    def test_a_row_every_leaf_shares_moves_to_the_body_and_prefers_the_shift_witness(self):
        row_a = {"type": "add_legacy_value", "storage": "banked_u16", "bank": 0, "index": 204, "delta": 1, "cell_class": "affection"}
        ev_variants = {"result": "leaf_a", "cell": {"storage": "banked_u16", "bank": 0, "index": 204}, "basis": "variants", "entry": 71, "final": 72, "declared": True}
        ev_shift = {"result": "leaf_b", "cell": {"storage": "banked_u16", "bank": 0, "index": 204}, "basis": "shift_witness", "entry": 80, "final": 81, "step": 7, "shifted_entry": 87, "shifted_final": 88, "declared": True}
        leaf_pairs = {"leaf_a": [(row_a, ev_variants)], "leaf_b": [(dict(row_a), ev_shift)]}
        body_rows, body_evidence, remaining = p4.promote_shared_rows_with_evidence(leaf_pairs)
        self.assertEqual(len(body_rows), 1)
        self.assertEqual(body_evidence[0]["basis"], "shift_witness")
        self.assertEqual(body_evidence[0]["result"], "body")
        self.assertEqual(remaining["leaf_a"], [])
        self.assertEqual(remaining["leaf_b"], [])

    def test_a_row_only_one_leaf_has_stays_with_it(self):
        row = {"type": "write_legacy_value", "storage": "state_u16", "bank": 0, "index": 6, "value": 1, "cell_class": "unnamed"}
        ev = {"result": "leaf_a", "cell": {"storage": "state_u16", "bank": 0, "index": 6}, "basis": "flag_pattern", "entry": 0, "final": 1, "declared": False}
        leaf_pairs = {"leaf_a": [(row, ev)], "leaf_b": []}
        body_rows, body_evidence, remaining = p4.promote_shared_rows_with_evidence(leaf_pairs)
        self.assertEqual(body_rows, [])
        self.assertEqual(remaining["leaf_a"], [(row, ev)])


class WitnessDoneCellTests(unittest.TestCase):
    def test_exactly_one_gate(self):
        done_index = {("r", "baseline"): {"gates": [{"storage": "global_u8", "bank": 0, "index": 2438}]}}
        index, result = p4.witness_done_cell(done_index, "r", "baseline")
        self.assertEqual(index, 2438)

    def test_no_gates(self):
        done_index = {("r", "baseline"): {"gates": []}}
        index, result = p4.witness_done_cell(done_index, "r", "baseline")
        self.assertIsNone(index)
        self.assertIsNotNone(result)

    def test_several_gates(self):
        done_index = {("r", "baseline"): {"gates": [
            {"storage": "global_u8", "bank": 0, "index": 1},
            {"storage": "global_u8", "bank": 0, "index": 2},
        ]}}
        index, result = p4.witness_done_cell(done_index, "r", "baseline")
        self.assertIsNone(index)
        self.assertEqual(len(result["gates"]), 2)

    def test_missing_request(self):
        index, result = p4.witness_done_cell({}, "r", "baseline")
        self.assertIsNone(index)
        self.assertIsNone(result)


class RecomputeCellClassesTests(unittest.TestCase):
    def test_a_cell_written_non_01_elsewhere_becomes_a_counter(self):
        document = {
            "after": [{"type": "write_legacy_value", "storage": "global_u8", "bank": 0, "index": 244, "value": 1, "cell_class": "flag"}],
            "results": {
                "r1": {
                    "after": [],
                    "reentry": {"after": [{"storage": "global_u8", "bank": 0, "index": 244, "value": 2}]},
                },
            },
        }
        p4.recompute_cell_classes(document, state_cells.load())
        self.assertEqual(document["after"][0]["cell_class"], "counter")

    def test_a_cell_only_ever_01_stays_a_flag(self):
        document = {
            "after": [{"type": "write_legacy_value", "storage": "global_u8", "bank": 0, "index": 905, "value": 1, "cell_class": "flag"}],
            "results": {},
        }
        p4.recompute_cell_classes(document, state_cells.load())
        self.assertEqual(document["after"][0]["cell_class"], "flag")


class OrderHintTests(unittest.TestCase):
    def _registry(self, rows):
        return {"rows": {r["id"]: r for r in rows}}

    def test_chain_confirmed_when_false_target_matches_the_next_guard(self):
        registry = self._registry([
            {"id": "a.1", "evidence": {"caller": "CALLER.MES"}},
            {"id": "a.2", "evidence": {"caller": "CALLER.MES"}},
        ])
        profiles = {}
        # This site is "a.1" itself: this_offset=100, false_target=200; "a.2"
        # resolves via resolve_site/choose_preferred, which needs a profile -
        # patch through a minimal fake by monkeypatching resolve_site/choose_preferred.
        orig_resolve = p4.ped.resolve_site
        orig_choose = p4.ped.choose_preferred
        try:
            def fake_resolve(row, _profiles):
                if row["id"] == "a.2":
                    return [{"stem": "s", "doc": {}, "group_id": "g", "routes": [{"guard": {"offset": 200, "false_target": 900}}]}]
                return []
            p4.ped.resolve_site = fake_resolve
            p4.ped.choose_preferred = lambda matches: matches[0]
            hint = p4.compute_order_hint(registry, profiles, "a.1", "CALLER.MES", 100, 200)
        finally:
            p4.ped.resolve_site = orig_resolve
            p4.ped.choose_preferred = orig_choose
        self.assertEqual(hint, {"scope": "CALLER.MES", "rank": 1, "of": 2, "basis": "guard_offset", "chain_confirmed": True})

    def test_no_hint_without_a_typed_guard(self):
        registry = self._registry([{"id": "a.1", "evidence": {"caller": "CALLER.MES"}}])
        self.assertIsNone(p4.compute_order_hint(registry, {}, "a.1", "CALLER.MES", None, None))


if __name__ == "__main__":
    unittest.main()
