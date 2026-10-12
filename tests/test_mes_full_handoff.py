"""Signed full-handoff parity with an explicit producer-only baseline view.

The Python result always retains its truthful producer and actual signature.
Only baseline_projection is compared with the GDScript oracle; that projection
is a comparison object, never the Python producer's exported payload.
"""

from __future__ import annotations

from copy import deepcopy
import hashlib
import json
from pathlib import Path
import sys
import unittest


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
sys.path.insert(0, str(ROOT / "tests"))

import mes_analyzer_handoff as handoff  # noqa: E402
from test_mes_capability_report import CALL_SCHEMAS, TRACE_SCHEMAS, evidence_inputs  # noqa: E402
from test_mes_instruction_ir import fixture, run_godot_oracle, synthetic_container  # noqa: E402
from test_mes_record_alignment import alignment_fixtures  # noqa: E402
from test_mes_references import AX_MARKER, VOICE_MARKER, focused_reference_fixtures  # noqa: E402


AUTHORED_SOURCE = {
    "archive": "authored.arc", "entry": "AUTHORED.MES", "source_kind": "synthetic",
    "archive_sha256": "a" * 64, "local_note": "not part of source identity",
}
SMALL_PAYLOAD = synthetic_container(b"\x19\x1a\x00")


def full_handoff_fixtures() -> list[dict]:
    rows = []
    for group, factory in (("alignment", alignment_fixtures), ("references", focused_reference_fixtures)):
        rows.extend({**row, "name": "full_" + group + "_" + row["name"], "mode": "full_handoff"}
                    for row in factory())
    rows.extend([
        fixture("full_source_identity", SMALL_PAYLOAD, mode="full_handoff", source=deepcopy(AUTHORED_SOURCE)),
        fixture("full_attached_evidence", synthetic_container(AX_MARKER + VOICE_MARKER), mode="full_handoff",
                source=deepcopy(AUTHORED_SOURCE), **evidence_inputs()),
        fixture("full_attached_transport_values", SMALL_PAYLOAD, mode="full_handoff", call_evidence=[{
            "schema": CALL_SCHEMAS[0], "authored_observations": {
                "bytes": {"$oracle_type": "packed_bytes", "value": "0081ff"},
                "count": {"$oracle_type": "int64", "value": "9223372036854775807"},
                "negative_zero": {"$oracle_type": "float64_bits", "value": "0000000000000080"},
                "fraction": {"$oracle_type": "float64_bits", "value": "000000000000c03f"},
                "note": "authored\t\u0085\u2028\u2029", "optional": None, "present": True,
            },
        }]),
    ])
    return rows


def invalid_attachment_fixtures() -> list[dict]:
    valid_graph = evidence_inputs()["graphs"][0]
    cases = [
        ("graph_schema", {"graphs": [{**valid_graph, "schema": "kakyu_mes_reference_graph/v999"}]}),
        ("graph_not_ok", {"graphs": [{**valid_graph, "ok": False}]}),
        ("graph_nondictionary", {"graphs": ["invalid"]}),
        ("graph_dangling_edge", {"graphs": [{**valid_graph, "edges": [{"from_id": "source", "to_id": "absent"}]}]}),
        ("call_schema", {"call_evidence": [{"schema": "authored_unknown/v1"}]}),
        ("trace_schema", {"trace_evidence": [{"schema": "authored_unknown/v1"}]}),
        ("call_nondictionary", {"call_evidence": [None]}),
        ("trace_nondictionary", {"trace_evidence": [False]}),
        ("call_nested_ui", {"call_evidence": [{"schema": CALL_SCHEMAS[0], "nested": [{"ui_label": "forbidden"}]}]}),
        ("trace_nested_ui", {"trace_evidence": [{"schema": TRACE_SCHEMAS[0], "nested": {"event_player": {}}}]}),
    ]
    return [fixture("full_reject_" + name, SMALL_PAYLOAD, mode="full_handoff", **values)
            for name, values in cases]


def _build_fixture(row: dict) -> dict:
    from test_mes_handoff_transport import descriptor_to_python

    return handoff.build_handoff(
        bytes.fromhex(row["hex"]), descriptor_to_python(row.get("source")),
        graphs=descriptor_to_python(row.get("graphs")),
        call_evidence=descriptor_to_python(row.get("call_evidence")),
        trace_evidence=descriptor_to_python(row.get("trace_evidence")),
    )


def _reseal(payload: dict) -> dict:
    result = deepcopy(payload)
    result.pop("payload_sha256", None)
    result["payload_sha256"] = handoff.fingerprint(result)
    return result


class FullHandoffBoundaryTests(unittest.TestCase):
    def test_actual_python_identity_and_signature_are_retained(self) -> None:
        from mes_handoff_transport import canonical_json_bytes

        actual = handoff.build_handoff(SMALL_PAYLOAD)
        self.assertEqual("python_phase1_4", actual["producer"]["implementation"])
        self.assertEqual(actual["schema"], actual["producer"]["contract"])
        unsigned = {key: value for key, value in actual.items() if key != "payload_sha256"}
        self.assertEqual(hashlib.sha256(canonical_json_bytes(unsigned)).hexdigest(), actual["payload_sha256"])
        self.assertEqual({"ok": True, "schema": actual["schema"], "payload_sha256": actual["payload_sha256"]},
                         handoff.verify(actual))

    def test_baseline_projection_changes_only_producer_and_signature(self) -> None:
        actual = handoff.build_handoff(SMALL_PAYLOAD, AUTHORED_SOURCE, **evidence_inputs())
        retained = deepcopy(actual)
        baseline = handoff.baseline_projection(actual)
        self.assertEqual(retained, actual)
        self.assertEqual("godot_gdscript_phase1_4", baseline["producer"]["implementation"])
        self.assertNotEqual(actual["payload_sha256"], baseline["payload_sha256"])
        expected = deepcopy(actual)
        expected["producer"]["implementation"] = "godot_gdscript_phase1_4"
        self.assertEqual(_reseal(expected), baseline)
        self.assertTrue(handoff.verify(baseline)["ok"])
        baseline["cfg"][0]["nodes"].clear()
        baseline["source_identity"]["entry"] = "CHANGED.MES"
        self.assertEqual(retained, actual)

    def test_baseline_projection_rejects_stale_signatures_and_non_python_producers(self) -> None:
        actual = handoff.build_handoff(SMALL_PAYLOAD)
        changed = deepcopy(actual)
        changed["source_identity"]["entry"] = "CHANGED.MES"
        with self.assertRaises(handoff.HandoffError):
            handoff.baseline_projection(changed)
        with self.assertRaises(handoff.HandoffError):
            handoff.baseline_projection(handoff.baseline_projection(actual))
        for field, value in (("implementation", "pretend_python"), ("contract", "unsupported/v1")):
            changed = deepcopy(actual)
            changed["producer"][field] = value
            with self.subTest(field=field), self.assertRaises(handoff.HandoffError):
                handoff.baseline_projection(_reseal(changed))

    def test_source_identity_uses_only_declared_fields_and_preserves_input(self) -> None:
        source = deepcopy(AUTHORED_SOURCE)
        expected = {key: value for key, value in source.items() if key != "local_note"}
        actual = handoff.build_handoff(SMALL_PAYLOAD, source)
        self.assertEqual(expected, actual["source_identity"])
        self.assertEqual(AUTHORED_SOURCE, source)
        actual["source_identity"]["entry"] = "CHANGED.MES"
        self.assertEqual("AUTHORED.MES", source["entry"])

    def test_build_output_and_attachment_inputs_do_not_alias(self) -> None:
        evidence = evidence_inputs()
        original = deepcopy(evidence)
        actual = handoff.build_handoff(SMALL_PAYLOAD, **evidence)
        expected = deepcopy(actual)
        evidence["graphs"][0]["nodes"].clear()
        evidence["call_evidence"][0]["schema"] = "changed/v1"
        self.assertEqual(expected, actual)
        retained_input = deepcopy(evidence)
        actual["cfg"][1]["nodes"].clear()
        actual["traces"][0]["schema"] = "changed/v1"
        self.assertEqual(retained_input, evidence)
        self.assertEqual(expected, handoff.build_handoff(SMALL_PAYLOAD, **original))

    def test_json_output_is_verified_canonical_and_round_trips(self) -> None:
        actual = handoff.build_handoff(SMALL_PAYLOAD, AUTHORED_SOURCE, **evidence_inputs())
        encoded = handoff.to_json(actual)
        self.assertFalse(encoded.endswith("\n"))
        self.assertEqual(actual, json.loads(encoded))
        self.assertEqual(handoff.verify(actual), handoff.verify(json.loads(encoded)))
        actual["calls"].clear()
        with self.assertRaises(handoff.HandoffError):
            handoff.to_json(actual)

    def test_verify_rejects_signature_and_version_drift_even_after_resealing(self) -> None:
        actual = handoff.build_handoff(SMALL_PAYLOAD)
        for field, value in (("payload_sha256", "0" * 64), ("payload_sha256", ""), ("schema", "unsupported/v1")):
            changed = deepcopy(actual)
            changed[field] = value
            with self.subTest(field=field, value=value), self.assertRaises(handoff.HandoffError):
                handoff.verify(changed)
        for key in ("container", "instruction", "analysis", "record_alignment", "reference_graph"):
            changed = deepcopy(actual)
            changed["compatibility"]["component_schemas"][key] = "unsupported/v1"
            with self.subTest(component=key), self.assertRaises(handoff.HandoffError):
                handoff.verify(_reseal(changed))
        for key in ("accepted_call_evidence", "accepted_trace_evidence"):
            changed = deepcopy(actual)
            changed["compatibility"]["component_schemas"][key].reverse()
            with self.subTest(component=key), self.assertRaises(handoff.HandoffError):
                handoff.verify(_reseal(changed))

    def test_verify_rejects_resealed_boundary_and_product_ui_changes(self) -> None:
        actual = handoff.build_handoff(SMALL_PAYLOAD)
        changed = deepcopy(actual)
        changed["typed_ir"]["instructions"][0]["raw_hex"] = "00"
        with self.assertRaises(handoff.HandoffError):
            handoff.verify(_reseal(changed))
        changed = deepcopy(actual)
        changed["calls"] = [{"schema": CALL_SCHEMAS[0], "nested": [{"ui_state": {}}]}]
        with self.assertRaises(handoff.HandoffError):
            handoff.verify(_reseal(changed))

    def test_unsupported_transport_and_top_level_input_shapes_fail_closed(self) -> None:
        for value in (object(), {1, 2}, (1, 2)):
            with self.subTest(kind=type(value).__name__), self.assertRaises(handoff.HandoffError):
                handoff.build_handoff(SMALL_PAYLOAD, call_evidence=[{"schema": CALL_SCHEMAS[0], "value": value}])
        for kwargs in ({"graphs": {}}, {"call_evidence": "invalid"}, {"trace_evidence": {}}):
            with self.subTest(kwargs=kwargs), self.assertRaises(handoff.HandoffError):
                handoff.build_handoff(SMALL_PAYLOAD, **kwargs)
        with self.assertRaises(handoff.HandoffError):
            handoff.build_handoff("not bytes")
        with self.assertRaises(handoff.HandoffError):
            handoff.build_handoff(SMALL_PAYLOAD, "not a dictionary")


class FullHandoffGodotOracleTests(unittest.TestCase):
    maxDiff = 6000

    @classmethod
    def setUpClass(cls) -> None:
        cls.valid = full_handoff_fixtures()
        cls.invalid = invalid_attachment_fixtures()
        cls.expected = run_godot_oracle(cls.valid + cls.invalid)

    def test_only_explicit_baseline_projection_matches_full_gdscript_payloads(self) -> None:
        for row in self.valid:
            with self.subTest(fixture=row["name"]):
                expected = self.expected[row["name"]]
                self.assertTrue(expected["ok"])
                actual = _build_fixture(row)
                self.assertTrue(handoff.verify(actual)["ok"])
                self.assertEqual("python_phase1_4", actual["producer"]["implementation"])
                self.assertNotEqual(expected["payload_sha256"], actual["payload_sha256"])
                self.assertEqual(expected, handoff.baseline_projection(actual))
                self.assertTrue(handoff.verify(expected)["ok"])

    def test_invalid_attachments_are_rejected_by_both_producers(self) -> None:
        for row in self.invalid:
            with self.subTest(fixture=row["name"]):
                self.assertFalse(self.expected[row["name"]]["ok"])
                with self.assertRaises(handoff.HandoffError):
                    _build_fixture(row)


if __name__ == "__main__":
    unittest.main()
