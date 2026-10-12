"""Unit tests for the spec-driven event-route toolchain (no archive, no Godot)."""
from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

import build_event_route_profile as builder  # noqa: E402
import draft_event_route_spec as drafter  # noqa: E402
import mes_route_decode as decode  # noqa: E402
import qualify_event_route as driver  # noqa: E402
import register_analysis_group as register  # noqa: E402


def literal(value):
    return {"type": "literal", "value": value}


def cell(storage, index):
    return {"type": "state_ref", "storage": storage, "bank": 0, "index": literal(index)}


def binary(op, lhs, rhs):
    return {"type": "binary", "op": op, "lhs": lhs, "rhs": rhs}


class DecodeTests(unittest.TestCase):
    def test_render_and_cells(self):
        ast = binary("logical_and", binary("greater_than", cell("state_u16", 7), literal(400)),
                     binary("equal", cell("global_u8", 399), literal(1)))
        self.assertEqual(decode.render(ast), "((state_u16[7] greater_than 400) logical_and (global_u8[399] equal 1))")
        self.assertEqual(decode._condition_cells(ast), [["state_u16", 7], ["global_u8", 399]])

    def test_write_parts_render_expression_index_and_values(self):
        instruction = {"op": "banked_u16_write_run", "operands": [
            {"type": "expression_index", "value": {"ast": literal(209)}},
            {"type": "u8_bank", "value": 0},
            {"type": "expression_byte_pairs", "pairs": [{"expression": {"ast": binary("add", cell("banked_u16", 209), literal(1))}}]}]}
        self.assertEqual(decode._write_parts(instruction), ("banked_u16", "209", ["(banked_u16[209] add 1)"]))


class DrafterTests(unittest.TestCase):
    def test_derive_guard_seeds_and_witnesses(self):
        parts = [
            {"text": "", "ast": binary("equal", cell("state_u16", 4), literal(6))},
            {"text": "", "ast": binary("greater_than", cell("state_u16", 7), literal(400))},
            {"text": "", "ast": binary("less_than", cell("state_u16", 7), literal(616))},
            {"text": "", "ast": binary("less_than", cell("state_u16", 19), literal(1600))},
            {"text": "", "ast": binary("greater_than", cell("banked_u16", 209), literal(35))},
            {"text": "", "ast": binary("equal", cell("global_u8", 399), literal(1))},
            {"text": "", "ast": binary("equal", cell("global_u8", 2045), literal(0))},
            {"text": "", "ast": binary("not_equal", cell("banked_u16", 242), literal(29))},
        ]
        derived = drafter.derive_guard(parts)
        baseline = derived["baseline"]
        self.assertEqual(baseline[("state_u16", 4)], 6)
        self.assertTrue(400 < baseline[("state_u16", 7)] < 616)
        self.assertEqual(baseline[("state_u16", 19)], 1590)
        self.assertEqual(baseline[("banked_u16", 209)], 45)
        self.assertEqual(baseline[("global_u8", 399)], 1)
        self.assertEqual(baseline[("global_u8", 2045)], 0)
        self.assertEqual(baseline[("banked_u16", 242)], 0)
        ids = [x["case_id"] for x in derived["witnesses"]]
        for expected in ["weekday-0", "date-400", "date-401", "date-615", "date-616", "clock-1599", "clock-1600",
                         "word209-35", "word209-36", "global_u8-399-0", "global_u8-2045-1", "banked242-29"]:
            self.assertIn(expected, ids)
        self.assertEqual(derived["notes"], [])

    def test_derive_guard_flags_unsupported_conjuncts(self):
        parts = [{"text": "(state_u16[7] equal banked_u16[263])",
                  "ast": binary("equal", cell("state_u16", 7), cell("banked_u16", 263))}]
        derived = drafter.derive_guard(parts)
        self.assertEqual(derived["baseline"], {})
        self.assertTrue(derived["notes"][0].startswith("manual seed"))

    def test_or_arms_seed_first_arm_and_witness_every_edge(self):
        arm1 = binary("logical_and", binary("greater_than", cell("state_u16", 7), literal(1115)),
                      binary("less_than", cell("state_u16", 7), literal(1215)))
        arm2 = binary("logical_and", binary("greater_than", cell("state_u16", 7), literal(1307)),
                      binary("less_than", cell("state_u16", 7), literal(1511)))
        derived = drafter.derive_guard([{"text": "", "ast": binary("logical_or", arm1, arm2)}])
        self.assertTrue(1115 < derived["baseline"][("state_u16", 7)] < 1215)
        ids = [x["case_id"] for x in derived["witnesses"]]
        for expected in ["date-1115", "date-1116", "date-1214", "date-1215", "date-1307", "date-1308", "date-1510", "date-1511"]:
            self.assertIn(expected, ids)


class BuilderTests(unittest.TestCase):
    def test_intify_restores_integers_from_godot_json(self):
        self.assertEqual(builder.intify({"a": 7.0, "b": [1.0, 2.5, {"c": 0.0}]}), {"a": 7, "b": [1, 2.5, {"c": 0}]})

    def test_restricted_diff_drops_calendar_and_foreign_cells(self):
        cells = [("global_u8", 128), ("state_u16", 8)]
        diff = [{"storage": "global_u8", "index": 128, "before": 1, "after": 2},
                {"storage": "state_u16", "index": 2, "before": 0, "after": 1},
                {"storage": "global_u8", "index": 999, "before": 0, "after": 1}]
        self.assertEqual(builder.restricted(diff, cells, {("state_u16", 2)}), {("global_u8", 128): 2})

    def test_binding_for_uses_opaque_tail_when_record_lies_inside(self):
        handoff = {"typed_ir": {"opaque_boundaries": [{"source_offset": 2074, "end_offset": 3814, "raw_sha256": "x"}]}}
        self.assertEqual(builder.binding_for("F", handoff, 3008, 3022, b"")["kind"], "runtime_observation_in_opaque_tail")
        self.assertEqual(builder.binding_for("F", handoff, 100, 110, b""), {"kind": "typed_record"})


class NestedCallTests(unittest.TestCase):
    def test_schema_follows_the_resume_policy(self):
        self.assertEqual(builder.schema_for(False, set()), "kakyu_event_analysis_group/v6")
        self.assertEqual(builder.schema_for(True, {"natural_handoff"}), "kakyu_event_analysis_group/v5")
        self.assertEqual(builder.schema_for(True, {"stop_before_unprovided_dependency"}), "kakyu_event_analysis_group/v5")
        self.assertEqual(builder.schema_for(True, {"natural_handoff", "def_selection_boundary"}), "kakyu_event_analysis_group/v8")
        self.assertEqual(builder.schema_for(True, {"def_selection_boundary", "caller_menu_loop"}), "kakyu_event_analysis_group/v10")
        self.assertEqual(builder.schema_for(False, set(), True), "kakyu_event_analysis_group/v11")
        self.assertEqual(builder.schema_for(True, {"natural_handoff"}, True), "kakyu_event_analysis_group/v12")

    def test_resume_binding_names_the_policy_and_record(self):
        code = {"C.MES": bytes(range(64))}
        sha = lambda entry, lo, hi: "x" * 64  # noqa: E731
        handoff = {"typed_ir": {"opaque_boundaries": [],
                                "instructions": [{"source_offset": 40, "end_offset": 45, "op": "script_transfer"},
                                                 {"source_offset": 50, "end_offset": 57, "op": "system_call"}]}}
        policy, out = builder.resume_binding("C.MES", handoff, {"kind": "def_selection_boundary", "offset": 40, "end": -1}, code, sha)
        self.assertEqual(policy, "def_selection_boundary")
        self.assertEqual((out["offset"], out["end"], out["op"], out["target"]), (40, 45, "script_transfer", ""))
        policy, out = builder.resume_binding("C.MES", handoff, {"kind": "loop_boundary", "offset": 50, "end": 57}, code, sha)
        self.assertEqual(policy, "caller_menu_loop")
        self.assertEqual((out["offset"], out["end"], out["op"], out["status"], out["target"]), (50, 57, "system_call", "loop_boundary", ""))
        policy, out = builder.resume_binding("C.MES", handoff, {"kind": "script_handoff_boundary", "offset": 10, "end": 24,
                                                                "target": "machi.mes"}, code, sha)
        self.assertEqual((policy, out["op"], out["target"]), ("natural_handoff", "script_handoff_marker", "MACHI.MES"))
        with self.assertRaises(SystemExit):
            builder.resume_binding("C.MES", handoff, {"kind": "unresolved", "offset": -1, "end": -1}, code, sha)

    def test_loop_binding_binds_the_cycle_to_typed_caller_records(self):
        handoff = {"typed_ir": {"opaque_boundaries": [],
                                "instructions": [{"source_offset": 50, "end_offset": 57, "op": "system_call"},
                                                 {"source_offset": 60, "end_offset": 65, "op": "script_transfer"}]}}
        stop = {"kind": "loop_boundary", "offset": 50, "end": 57, "period": 2, "period_message_count": 3,
                "cycle": [{"entry": "C.MES", "offset": 50, "status": "dialogue_boundary"},
                          {"entry": "C.MES", "offset": 60, "status": "shared_routine_boundary"}]}
        self.assertEqual(builder.loop_binding("C.MES", handoff, stop),
                         {"period": 2, "period_message_count": 3,
                          "cycle": [{"entry": "C.MES", "offset": 50, "end": 57, "status": "dialogue_boundary"},
                                    {"entry": "C.MES", "offset": 60, "end": 65, "status": "shared_routine_boundary"}]})
        for broken in ({**stop, "period": 1},
                       {**stop, "cycle": [{"entry": "D.MES", "offset": 50, "status": "dialogue_boundary"}] + stop["cycle"][1:]},
                       {**stop, "cycle": [{"entry": "C.MES", "offset": 51, "status": "dialogue_boundary"}] + stop["cycle"][1:]},
                       {**stop, "cycle": [{"entry": "C.MES", "offset": 50, "status": "script_dispatch_boundary"}] + stop["cycle"][1:]}):
            with self.assertRaises(SystemExit):
                builder.loop_binding("C.MES", handoff, broken)

    def test_map_location_binding_binds_the_poll_record(self):
        def record(offset, literals):
            return {"source_offset": offset, "end_offset": offset + 8, "command_id": 0x12, "op": "native_record_dispatch",
                    "operands": [{"type": "record_list", "records": [
                        {"type": "expression_record", "value": {"ast": {"type": "literal", "value": v}}} for v in literals]}]}
        handoff = {"typed_ir": {"opaque_boundaries": [], "instructions": [record(886, [6, 13]), record(900, [6, 12])]}}
        sha = lambda entry, lo, hi: "%d-%d" % (lo, hi)  # noqa: E731
        bound = builder.map_location_binding("TRAIN.MES", handoff, {"entry": "TRAIN.MES", "poll_offset": 886, "locations": [0, 1]}, {}, sha)
        self.assertEqual(bound, {"schema": "kakyu_mes_map_location_contract/v1",
                                 "source_identity": {"archive": "mes.arc", "entry": "TRAIN.MES"},
                                 "poll_offset": 886, "poll_end": 894, "poll_function": [6, 13], "record_sha256": "886-894",
                                 "result_storage": "state_u16", "result_index": 18, "none_value": 0xFFFF, "locations": [0, 1]})
        for broken in ({"entry": "TRAIN.MES", "poll_offset": 900, "locations": [0]},
                       {"entry": "TRAIN.MES", "poll_offset": 887, "locations": [0]},
                       {"entry": "TRAIN.MES", "poll_offset": 886, "locations": []},
                       {"entry": "TRAIN.MES", "poll_offset": 886, "locations": [0xFFFF]}):
            with self.assertRaises(SystemExit):
                builder.map_location_binding("TRAIN.MES", handoff, broken, {}, sha)

    def test_spent_by_runs_names_the_runs_that_drain_a_contract(self):
        contract = {"source_identity": {"archive": "mes.arc", "entry": "FLOOR4.MES"}, "poll_offset": 2323, "locations": [4]}

        def run(remaining):
            return {"map_locations": [{"entry": "FLOOR4.MES", "poll_offset": 2323, "remaining": remaining}],
                    "map_locations_remaining": len(remaining)}
        # The chain carries one queue: the prefix starts with [4]; what it
        # leaves is what the callee starts with, and so on.
        arrival = [("prefix", run([])), ("callee", run([]))]
        self.assertEqual(builder.spent_by_runs(contract, arrival, run([])), ["prefix", "whole"])
        ride = [("prefix", run([4])), ("callee", run([])), ("resume", run([]))]
        self.assertEqual(builder.spent_by_runs(contract, ride, run([])), ["callee", "whole"])
        both = {**contract, "locations": [6, 0]}
        arrival_and_way_out = [("prefix", run([0])), ("callee", run([0])), ("resume", run([]))]
        self.assertEqual(builder.spent_by_runs(both, arrival_and_way_out, run([])), ["prefix", "resume", "whole"])
        legacy = [("prefix", {"map_locations_remaining": 1}), ("callee", {"map_locations_remaining": 0})]
        self.assertEqual(builder.spent_by_runs(contract, legacy, {"map_locations_remaining": 0}), ["callee", "whole"])
        for chain, whole in (([("prefix", run([4])), ("callee", run([4]))], run([])),
                             ([("prefix", run([])), ("callee", run([]))], run([4])),
                             ([("prefix", {"map_locations": []}), ("callee", run([]))], run([]))):
            with self.assertRaises(SystemExit):
                builder.spent_by_runs(contract, chain, whole)

    def test_drafter_finds_map_location_polls(self):
        class FakeArchive:
            def code(self, entry):
                poll = drafter.MAP_LOCATION_POLL_BYTES
                return {"TRAIN.MES": poll + b"\x00" + poll, "LIBLARY.LIB": None}[entry]
        self.assertEqual(drafter.map_location_polls(FakeArchive(), "TRAIN.MES"), [0, 9])
        self.assertEqual(drafter.map_location_polls(FakeArchive(), "LIBLARY.LIB"), [])

    def test_driver_profile_suffix_and_missing_members(self):
        root = {"form": "root_handoff", "call": {"command": 14}}
        nested = {"form": "nested_call", "call": {"command": 15}}
        self.assertEqual(driver.profile_suffix(root, {}), "v6")
        self.assertEqual(driver.profile_suffix(nested, {"resume": {"stop": {"kind": "script_handoff_boundary"}}}), "v5")
        self.assertEqual(driver.profile_suffix(nested, {"results": {"1": {"resume": {"stop": {"kind": "def_selection_boundary"}}}}}), "v8")
        self.assertEqual(driver.profile_suffix(nested, {"results": {"1": {"resume": {"stop": {"kind": "loop_boundary"}}},
                                                                    "2": {"resume": {"stop": {"kind": "def_selection_boundary"}}}}}), "v10")
        with_map = {"form": "root_handoff", "call": {"command": 14}, "map_location_contracts": [{"entry": "TRAIN.MES"}]}
        self.assertEqual(driver.profile_suffix(with_map, {}), "v11")
        self.assertEqual(driver.profile_suffix({**nested, "map_location_contracts": [{"entry": "TRAIN.MES"}]},
                                               {"resume": {"stop": {"kind": "script_handoff_boundary"}}}), "v12")
        reports = ["nested entry K_PIC.MES is not a package member", "root entry MACHI.MES is not a package member", "other"]
        self.assertEqual(driver.missing_members(reports, ["C.MES", "machi.mes"]), ["K_PIC.MES"])


class DriverTests(unittest.TestCase):
    def test_validator_line_extracts_fields(self):
        text = 'x {"checks":278,"failures":[],"identity":{},"ok":true} y'
        self.assertEqual(driver.validator_line(text), ("true", "278", "[]"))
        text = '{"checks":278,"failures":["callee message observation count"],"ok":false}'
        self.assertEqual(driver.validator_line(text)[2], '["callee message observation count"]')


class RegisterTests(unittest.TestCase):
    def test_register_inserts_after_anchor_and_refuses_duplicates(self):
        # Since TD-32 part 1 (Core 0.357.0) the checks are data
        # (config/validation/checks_v1.json, one analysis_group entry per
        # tracked profile) rather than a tuple literal in
        # run_headless_validation.py; register() edits that registry.
        original = register.REGISTRY
        with tempfile.TemporaryDirectory() as directory:
            registry = Path(directory) / "checks_v1.json"
            registry.write_text(json.dumps({
                "schema": "kakyu_validation_checks/v1",
                "revision": 5,
                "families": {},
                "checks": [
                    {"name": "original event analysis A B", "kind": "godot_script",
                     "script": "res://tools/content_suite/validators/validate_event_analysis_group.gd",
                     "arguments": ["{source_root}", "config/event_catalog/analysis_groups/a_b_v6.json"],
                     "timeout": 300, "groups": ["original_corpus"], "requires": ["elfimage"], "tier": "full",
                     "family": "analysis_group", "profile": "config/event_catalog/analysis_groups/a_b_v6.json"},
                    {"name": "original event analysis 44M H18", "kind": "godot_script",
                     "script": "res://tools/content_suite/validators/validate_event_analysis_group.gd",
                     "arguments": ["{source_root}", "config/event_catalog/analysis_groups/44m_h18_v8.json"],
                     "timeout": 300, "groups": ["original_corpus"], "requires": ["elfimage"], "tier": "full",
                     "family": "analysis_group", "profile": "config/event_catalog/analysis_groups/44m_h18_v8.json"},
                ],
            }), encoding="utf-8")
            register.REGISTRY = registry
            try:
                self.assertTrue(register.register("C D", "c_d_v6.json", "A B"))
                document = json.loads(registry.read_text(encoding="utf-8"))
                names = [c["name"] for c in document["checks"]]
                self.assertEqual(names, ["original event analysis A B", "original event analysis C D",
                                         "original event analysis 44M H18"])
                self.assertEqual(document["checks"][1]["profile"], "config/event_catalog/analysis_groups/c_d_v6.json")
                self.assertFalse(register.register("C D", "c_d_v6.json", "A B"))
            finally:
                register.REGISTRY = original


if __name__ == "__main__":
    unittest.main()
