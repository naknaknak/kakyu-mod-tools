"""Tests for `tools/plan_event_effect_witnesses.py` (event definition v4,
unit 1b, part A): grouping, the three skip reasons, the request shapes, and
determinism. Pure Python, a hand-made replay - no Godot, no archive access.
See `analysis/_docs/v4_unit1b_witness_spec.md`.
"""
from __future__ import annotations

import json
import unittest
from pathlib import Path

from tools.plan_event_effect_witnesses import (
    cell_key,
    group_key,
    group_route_variants,
    is_flow_replay,
    net_changes_for_variant,
    plan_directory,
    plan_replay,
    plan_route,
)


def _terminal(offset=100, status="script_return", entry="EVENTX01.MES", end=104, target=""):
    return {"entry": entry, "status": status, "offset": offset, "end": end, "target": target}


def _row(storage, index, before, after, bank=0):
    return {"storage": storage, "bank": bank, "index": index, "before": before, "after": after}


def _variant(variant_id, prefix, callee, resume_changes=None, resume_messages=None,
             reentry_message_count=0, terminal=None, messages=None, reached=True):
    resume = None
    if resume_changes is not None or resume_messages is not None:
        resume = {
            "messages": resume_messages or [],
            "terminal": _terminal(offset=200),
        }
    variant = {
        "variant_id": variant_id,
        "reached": reached,
        "prefix_messages": [{"entry": "01X.MES", "offset": 10}],
        "messages": messages if messages is not None else [{"entry": "EVENTX01.MES", "offset": 20}],
        "terminal": terminal or _terminal(),
        "reentry": {"message_count": reentry_message_count, "terminal": _terminal()},
        "state_changes": {
            "prefix": prefix,
            "callee": callee,
            "resume": resume_changes or [],
        },
    }
    if resume is not None:
        variant["resume"] = resume
    return variant


class NetChangesTests(unittest.TestCase):
    def test_concatenates_prefix_callee_resume_in_order(self):
        variant = _variant("v1",
            prefix=[_row("global_u8", 100, 0, 1)],
            callee=[_row("global_u8", 100, 1, 1)],  # would not appear (before==after), kept for round-trip test below
        )
        # A round trip across lists nets to zero and must be dropped.
        variant["state_changes"]["callee"] = [_row("banked_u16", 204, 80, 85)]
        variant["state_changes"]["resume"] = [_row("banked_u16", 204, 85, 80)]
        net = net_changes_for_variant(variant)
        self.assertNotIn(("banked_u16", 0, 204), net)

    def test_first_before_last_after_across_lists(self):
        variant = _variant("v1",
            prefix=[_row("banked_u16", 204, 80, 81)],
            callee=[_row("banked_u16", 204, 81, 83)],
        )
        net = net_changes_for_variant(variant)
        row = net[("banked_u16", 0, 204)]
        self.assertEqual(row["before"], 80)
        self.assertEqual(row["after"], 83)

    def test_cell_key(self):
        self.assertEqual(cell_key(_row("global_u8", 5, 0, 1)), ("global_u8", 0, 5))


class GroupingTests(unittest.TestCase):
    def test_unreached_variants_are_excluded(self):
        route = {"route_id": "r1", "variants": [
            _variant("skip", prefix=[], callee=[], reached=False),
            _variant("keep", prefix=[], callee=[_row("global_u8", 1, 0, 1)]),
        ]}
        groups = group_route_variants(route)
        self.assertEqual(len(groups), 1)
        _key, variants = groups[0]
        self.assertEqual([v["variant_id"] for v in variants], ["keep"])

    def test_same_messages_and_terminal_group_together(self):
        route = {"route_id": "r1", "variants": [
            _variant("a", prefix=[], callee=[_row("global_u8", 1, 0, 1)]),
            _variant("b", prefix=[], callee=[_row("global_u8", 1, 0, 1)]),
        ]}
        groups = group_route_variants(route)
        self.assertEqual(len(groups), 1)
        self.assertEqual(len(groups[0][1]), 2)

    def test_different_terminal_makes_a_new_group(self):
        route = {"route_id": "r1", "variants": [
            _variant("a", prefix=[], callee=[]),
            _variant("b", prefix=[], callee=[], terminal=_terminal(offset=999)),
        ]}
        groups = group_route_variants(route)
        self.assertEqual(len(groups), 2)

    def test_resume_terminal_used_over_callee_terminal_when_present(self):
        variant = _variant("a", prefix=[], callee=[], resume_messages=[{"entry": "01X.MES", "offset": 500}])
        self.assertEqual(group_key(variant)[1], ("EVENTX01.MES", "script_return", 200, 104, ""))


class PlanRouteTests(unittest.TestCase):
    def test_clock_cell_is_skipped(self):
        route = {"route_id": "r1", "variants": [
            _variant("a", prefix=[], callee=[_row("state_u16", 19, 1200, 1215)]),
        ]}
        shift, done_probe, skipped = plan_route(route)
        self.assertEqual(skipped["clock"], 1)
        self.assertEqual(shift, [])

    def test_entries_vary_is_skipped(self):
        route = {"route_id": "r1", "variants": [
            _variant("a", prefix=[], callee=[_row("banked_u16", 204, 80, 81)]),
            _variant("b", prefix=[], callee=[_row("banked_u16", 204, 90, 91)]),
        ]}
        shift, done_probe, skipped = plan_route(route)
        self.assertEqual(skipped["entries_vary"], 1)
        self.assertEqual(shift, [])

    def test_flag_pattern_is_skipped(self):
        route = {"route_id": "r1", "variants": [
            _variant("a", prefix=[], callee=[_row("global_u8", 905, 0, 1)]),
            _variant("b", prefix=[], callee=[_row("global_u8", 905, 0, 1)]),
        ]}
        shift, done_probe, skipped = plan_route(route)
        self.assertEqual(skipped["flag_pattern"], 1)
        self.assertEqual(shift, [])

    def test_alike_non_flag_cell_gets_a_shift_request(self):
        route = {"route_id": "r1", "variants": [
            _variant("first", prefix=[], callee=[_row("banked_u16", 204, 80, 81)]),
            _variant("second", prefix=[], callee=[_row("banked_u16", 204, 80, 81)]),
        ]}
        shift, done_probe, skipped = plan_route(route)
        self.assertEqual(len(shift), 1)
        request = shift[0]
        self.assertEqual(request["kind"], "shift")
        self.assertEqual(request["route_id"], "r1")
        self.assertEqual(request["variant_id"], "first")
        self.assertEqual(request["cell"], {"storage": "banked_u16", "bank": 0, "index": 204})
        self.assertEqual(request["entry"], 80)
        self.assertEqual(request["steps"], [7, -7, 1, -1])

    def test_a_u8_flag_written_to_something_other_than_1_is_not_flag_pattern(self):
        route = {"route_id": "r1", "variants": [
            _variant("a", prefix=[], callee=[_row("global_u8", 905, 0, 2)]),
        ]}
        shift, done_probe, skipped = plan_route(route)
        self.assertEqual(skipped["flag_pattern"], 0)
        self.assertEqual(len(shift), 1)

    def test_done_probe_request_when_every_variant_reentry_is_silent(self):
        route = {"route_id": "r1", "variants": [
            _variant("first", prefix=[_row("state_u16", 19, 1200, 1215)],
                      callee=[_row("banked_u16", 204, 80, 81), _row("global_u8", 905, 0, 1)],
                      reentry_message_count=0),
            _variant("second", prefix=[_row("state_u16", 19, 1200, 1215)],
                      callee=[_row("banked_u16", 204, 80, 81), _row("global_u8", 905, 0, 1)],
                      reentry_message_count=0),
        ]}
        shift, done_probe, skipped = plan_route(route)
        self.assertEqual(len(done_probe), 1)
        request = done_probe[0]
        self.assertEqual(request["kind"], "done_probe")
        self.assertEqual(request["variant_id"], "first")
        # The clock cell (state_u16 19) is excluded; the first variant's own
        # two non-clock changed cells are listed, each with its own entry.
        self.assertEqual(request["cells"], [
            {"storage": "banked_u16", "bank": 0, "index": 204, "entry": 80},
            {"storage": "global_u8", "bank": 0, "index": 905, "entry": 0},
        ])

    def test_no_done_probe_request_when_any_variant_reentry_emits_messages(self):
        route = {"route_id": "r1", "variants": [
            _variant("a", prefix=[], callee=[_row("banked_u16", 204, 80, 81)], reentry_message_count=0),
            _variant("b", prefix=[], callee=[_row("banked_u16", 204, 80, 81)], reentry_message_count=3),
        ]}
        _shift, done_probe, _skipped = plan_route(route)
        self.assertEqual(done_probe, [])


class DeterminismTests(unittest.TestCase):
    def test_planning_the_same_replay_twice_is_identical(self):
        replay = {
            "group_id": "g1", "profile": "p1", "payload_sha256": "a" * 64,
            "routes": [{"route_id": "r1", "variants": [
                _variant("a", prefix=[], callee=[_row("banked_u16", 204, 80, 81)]),
                _variant("b", prefix=[], callee=[_row("global_u8", 905, 0, 1)]),
            ]}],
        }
        first, first_summary = plan_replay(replay)
        second, second_summary = plan_replay(replay)
        self.assertEqual(first, second)
        self.assertEqual(first_summary, second_summary)

    def test_request_document_shape(self):
        replay = {
            "group_id": "g1", "profile": "p1", "payload_sha256": "b" * 64,
            "routes": [{"route_id": "r1", "variants": [
                _variant("a", prefix=[], callee=[_row("banked_u16", 204, 80, 81)]),
            ]}],
        }
        document, _summary = plan_replay(replay)
        self.assertEqual(document["schema"], "kakyu_event_effect_witness_request/v1")
        self.assertEqual(document["group_id"], "g1")
        self.assertEqual(document["profile"], "p1")
        self.assertEqual(document["payload_sha256"], "b" * 64)
        # One shift request (the changed cell) and one done-probe request
        # (the lone variant's reentry.message_count defaults to 0), shift
        # requests first.
        self.assertEqual([r["kind"] for r in document["requests"]], ["shift", "done_probe"])


class PlanDirectoryTests(unittest.TestCase):
    def test_writes_one_request_file_per_replay(self):
        import tempfile
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            replays_dir = tmp_path / "replays"
            out_dir = tmp_path / "requests"
            replays_dir.mkdir()
            replay = {
                "group_id": "g1", "profile": "sample", "payload_sha256": "c" * 64,
                "routes": [{"route_id": "r1", "variants": [
                    _variant("a", prefix=[], callee=[_row("banked_u16", 204, 80, 81)]),
                ]}],
            }
            with (replays_dir / "sample.json").open("w", encoding="utf-8") as fh:
                json.dump(replay, fh)
            result = plan_directory(replays_dir, out_dir)
            self.assertEqual(result["files"], 1)
            out_path = out_dir / "sample.json"
            self.assertTrue(out_path.is_file())
            with out_path.open("r", encoding="utf-8") as fh:
                written = json.load(fh)
            self.assertEqual(written["schema"], "kakyu_event_effect_witness_request/v1")
            # One shift request and one done-probe request (see
            # test_request_document_shape).
            self.assertEqual([r["kind"] for r in written["requests"]], ["shift", "done_probe"])

    def test_a_flow_replay_is_skipped_not_crashed_on_and_counted(self):
        import tempfile
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            replays_dir = tmp_path / "replays"
            out_dir = tmp_path / "requests"
            replays_dir.mkdir()
            ordinary = {
                "group_id": "g1", "profile": "z_ordinary", "payload_sha256": "c" * 64,
                "runtime_schema": "kakyu_event_analysis_group_runtime/v6",
                "routes": [{"route_id": "r1", "variants": [
                    _variant("a", prefix=[], callee=[_row("banked_u16", 204, 80, 81)]),
                ]}],
            }
            # A flow replay sorts first and carries `state_changes` as a list
            # (per-hop), which `net_changes_for_variant` cannot read (TD-37).
            flow = {
                "group_id": "g2", "profile": "a_flow_v14", "payload_sha256": "d" * 64,
                "runtime_schema": "kakyu_event_analysis_group_runtime/v14",
                "routes": [{"route_id": "r2", "variants": [
                    {"variant_id": "v", "reached": True, "state_changes": [_row("banked_u16", 1, 0, 1)]},
                ]}],
            }
            for name, doc in (("z_ordinary", ordinary), ("a_flow_v14", flow)):
                with (replays_dir / ("%s.json" % name)).open("w", encoding="utf-8") as fh:
                    json.dump(doc, fh)
            self.assertTrue(is_flow_replay(flow))
            self.assertFalse(is_flow_replay(ordinary))
            result = plan_directory(replays_dir, out_dir)
            self.assertEqual(result["files"], 1)
            self.assertEqual(result["skipped_flow_replays"], ["a_flow_v14"])
            self.assertTrue((out_dir / "z_ordinary.json").is_file())
            self.assertFalse((out_dir / "a_flow_v14.json").exists())


if __name__ == "__main__":
    unittest.main()
