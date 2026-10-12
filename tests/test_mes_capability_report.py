"""Capability aggregation parity, separate from handoff evidence validation.

Container fixtures pass through the complete GDScript producer. The explicitly
named aggregate fixtures call its private counter only: those fixtures specify
counter defaults and do not claim that their evidence is valid for a handoff.
All MES containers are authored and no test reads an original archive.
"""

from __future__ import annotations

from copy import deepcopy
from pathlib import Path
import sys
import unittest


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
sys.path.insert(0, str(ROOT / "tests"))

import mes_analyzer_handoff as handoff  # noqa: E402
from mes_capability_report import build_capability_report  # noqa: E402
from mes_record_alignment import build_record_alignment  # noqa: E402
from mes_references import build_references  # noqa: E402
from test_mes_instruction_ir import fixture, run_godot_oracle, synthetic_container  # noqa: E402
from test_mes_record_alignment import STRUCTURAL_RECOVERY, alignment_fixtures  # noqa: E402
from test_mes_references import AX_MARKER, VOICE_MARKER, reference_fixtures  # noqa: E402


CALL_SCHEMAS = (
    "kakyu_mes_registered_definition_call/v5", "kakyu_mes_caller_route/v1",
    "kakyu_mes_routine40_reachability/v1",
)
TRACE_SCHEMAS = (
    "kakyu_mes_event_trace/v68", "kakyu_mes_script_call_trace/v3",
    "kakyu_mes_registered_definition_trace/v7", "kakyu_mes_library_trace/v10",
)


def evidence_inputs() -> dict:
    graph = {
        "ok": True, "schema": "kakyu_mes_reference_graph/v1",
        "nodes": [{"id": "source"}, {"id": "target"}],
        "edges": [{"from_id": "source", "to_id": "target"}],
    }
    return {
        "graphs": [graph, deepcopy(graph)],
        "call_evidence": [{"schema": schema} for schema in (*CALL_SCHEMAS, CALL_SCHEMAS[0])],
        "trace_evidence": [{"schema": schema} for schema in (*TRACE_SCHEMAS, TRACE_SCHEMAS[-1])],
    }


def capability_container_fixtures() -> list[dict]:
    rows = []
    for group, factory in (("references", reference_fixtures), ("alignment", alignment_fixtures)):
        rows.extend({**row, "name": "capability_" + group + "_" + row["name"], "mode": "capability_report"}
                    for row in factory())
    rows.append(fixture("capability_validated_nonempty_evidence", synthetic_container(AX_MARKER + VOICE_MARKER),
                        mode="capability_report", **evidence_inputs()))
    return rows


def aggregate_fixtures() -> list[dict]:
    # All explicitly present label values are canonical strings. Non-dictionary
    # rows and missing labels test GD's defaults, without broadening the Python
    # contract to Godot's generic Variant-to-string conversion.
    return [
        fixture("capability_aggregate_empty_defaults", b"", mode="capability_report_aggregate"),
        fixture("capability_aggregate_duplicates_and_missing", b"", mode="capability_report_aggregate",
                typed_ir={
                    "instructions": [{"op": "insert_text"}, {"op": "insert_text"}, {}, {"op": ""}, None, 3, "ignored"],
                    "opaque_boundaries": [{"type": "opaque_region_tail"}, {}, {"type": "opaque_region_tail"}, []],
                },
                alignment={"compound_families": {"family_b": 7, "family_a": 2}},
                references={
                    "code": [{"kind": "condition_false_target"}, {}, {"kind": "condition_false_target"}, False],
                    "resources": [{"resource_kind": "voice"}, {"resource_kind": "voice"}, {}, 1],
                    "messages": [{"ignored": True}], "state": [{"ignored": True}],
                }, **evidence_inputs()),
        fixture("capability_aggregate_does_not_validate_evidence", b"", mode="capability_report_aggregate",
                graphs=[None, "not_a_valid_graph"],
                call_evidence=[{"schema": "authored_unknown/v1"}, {}, None, "ignored"],
                trace_evidence=[{"schema": ""}, {"schema": "authored_unknown/v2"}, {}, False]),
    ]


def _components(code: bytes) -> tuple[dict, dict, dict]:
    container = handoff.build_container(synthetic_container(code))
    typed_ir = handoff.build_typed_ir(container)
    alignment = build_record_alignment(container)
    return typed_ir, alignment, build_references(container, typed_ir)


def _aggregate_fixture(row: dict) -> dict:
    return build_capability_report(
        row.get("typed_ir", {}), row.get("alignment", {}), row.get("references", {}),
        row.get("graphs", ()), row.get("call_evidence", ()), row.get("trace_evidence", ()),
    )


class CapabilityReportBoundaryTests(unittest.TestCase):
    def test_strict_opaque_and_structural_families_remain_separate(self) -> None:
        typed_ir, alignment, references = _components(STRUCTURAL_RECOVERY)
        report = build_capability_report(typed_ir, alignment, references)
        self.assertFalse(typed_ir["complete"])
        self.assertTrue(alignment["ok"])
        self.assertEqual(0, alignment["opaque_boundary_count"])
        self.assertEqual(1, sum(report["opaque_boundary_types"].values()))
        self.assertEqual(len(typed_ir["instructions"]), sum(report["typed_instruction_ops"].values()))
        self.assertEqual(alignment["compound_families"], report["compound_record_families"])
        self.assertGreater(alignment["instruction_count"], sum(report["typed_instruction_ops"].values()))

    def test_duplicate_kinds_are_counted_and_untyped_rows_are_ignored(self) -> None:
        report = _aggregate_fixture(aggregate_fixtures()[1])
        self.assertEqual({"insert_text": 2, "unresolved": 1, "": 1}, report["typed_instruction_ops"])
        self.assertEqual({"opaque_region_tail": 2, "unresolved": 1}, report["opaque_boundary_types"])
        self.assertEqual({"condition_false_target": 2, "unresolved": 1}, report["code_reference_kinds"])
        self.assertEqual({"voice": 2, "unresolved": 1}, report["resource_reference_kinds"])
        self.assertEqual({"family_b": 7, "family_a": 2}, report["compound_record_families"])

    def test_nonempty_graph_call_and_trace_counts_preserve_schema_duplicates(self) -> None:
        typed_ir, alignment, references = _components(AX_MARKER + VOICE_MARKER)
        report = build_capability_report(typed_ir, alignment, references, **evidence_inputs())
        self.assertEqual(2, report["cfg_count"])
        self.assertEqual({schema: 2 if schema == CALL_SCHEMAS[0] else 1 for schema in CALL_SCHEMAS},
                         report["call_evidence_schemas"])
        self.assertEqual({schema: 2 if schema == TRACE_SCHEMAS[-1] else 1 for schema in TRACE_SCHEMAS},
                         report["trace_evidence_schemas"])

    def test_report_mutation_does_not_change_inputs_or_later_reports(self) -> None:
        row = aggregate_fixtures()[1]
        original = deepcopy(row)
        expected = _aggregate_fixture(row)
        report = _aggregate_fixture(row)
        report["compound_record_families"]["family_a"] = -1
        report["typed_instruction_ops"].clear()
        report["call_evidence_schemas"].clear()
        report["phase_range"].append(99)
        report["remaining_numeric_or_unresolved_meanings"].clear()
        self.assertEqual(original, row)
        self.assertEqual(expected, _aggregate_fixture(row))
        row["alignment"]["compound_families"]["family_a"] = 99
        self.assertEqual(2, expected["compound_record_families"]["family_a"])

    def test_missing_components_produce_empty_counts_and_preserve_policy(self) -> None:
        report = build_capability_report({}, {}, {})
        for field in ("typed_instruction_ops", "compound_record_families", "opaque_boundary_types",
                      "code_reference_kinds", "resource_reference_kinds", "call_evidence_schemas", "trace_evidence_schemas"):
            self.assertEqual({}, report[field], field)
        self.assertEqual(0, report["cfg_count"])
        self.assertEqual([1, 2, 3, 4], report["phase_range"])
        self.assertEqual("safe_reproducible_low_level_structure", report["completion_scope"])
        self.assertEqual("numeric_or_source_qualified_only", report["semantic_policy"])
        self.assertEqual("forbidden", report["product_ui_data"])
        self.assertEqual("forbidden", report["source_mutation"])

    def test_aggregating_evidence_does_not_claim_to_validate_it(self) -> None:
        report = _aggregate_fixture(aggregate_fixtures()[2])
        self.assertEqual(2, report["cfg_count"])
        self.assertEqual({"authored_unknown/v1": 1, "unresolved": 1}, report["call_evidence_schemas"])
        self.assertEqual({"": 1, "authored_unknown/v2": 1, "unresolved": 1}, report["trace_evidence_schemas"])

    def test_noncanonical_label_values_are_rejected_without_variant_coercion(self) -> None:
        for value in (None, False, 3, [], {}):
            with self.subTest(value=value), self.assertRaises(ValueError):
                build_capability_report({"instructions": [{"op": value}]}, {}, {})

    def test_message_and_state_rows_do_not_invent_capability_categories(self) -> None:
        typed_ir, alignment, references = _components(b"\x19\x00")
        expected = build_capability_report(typed_ir, alignment, references)
        references["messages"] = [{"type": "authored_unknown"}] * 7
        references["state"] = [{"storage": "authored_unknown"}] * 9
        self.assertEqual(expected, build_capability_report(typed_ir, alignment, references))


class CapabilityReportGodotOracleTests(unittest.TestCase):
    maxDiff = 5000

    @classmethod
    def setUpClass(cls) -> None:
        cls.containers = capability_container_fixtures()
        cls.aggregates = aggregate_fixtures()
        cls.expected = run_godot_oracle(cls.containers + cls.aggregates)

    def test_authored_containers_match_validated_gdscript_handoff_reports(self) -> None:
        for row in self.containers:
            with self.subTest(fixture=row["name"]):
                container = handoff.build_container(bytes.fromhex(row["hex"]))
                typed_ir = handoff.build_typed_ir(container)
                actual = build_capability_report(
                    typed_ir, build_record_alignment(container), build_references(container, typed_ir),
                    row.get("graphs", ()), row.get("call_evidence", ()), row.get("trace_evidence", ()),
                )
                self.assertEqual(self.expected[row["name"]], handoff.normalize(actual))

    def test_private_aggregation_defaults_match_without_evidence_validation(self) -> None:
        for row in self.aggregates:
            with self.subTest(fixture=row["name"]):
                self.assertEqual(self.expected[row["name"]], handoff.normalize(_aggregate_fixture(row)))


if __name__ == "__main__":
    unittest.main()
