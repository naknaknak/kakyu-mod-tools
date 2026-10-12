from __future__ import annotations

import copy
import sys
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

import validate_mes_analyzer_handoff as handoff  # noqa: E402


class MesAnalyzerHandoffTests(unittest.TestCase):
    def fixture(self) -> dict:
        document = {
            "ok": True,
            "schema": handoff.HANDOFF_SCHEMA,
            "compatibility": {
                "policy": "exact_component_schema_match",
                "component_schemas": {
                    **handoff.COMPONENT_SCHEMAS,
                    "accepted_call_evidence": handoff.CALL_EVIDENCE_SCHEMAS,
                    "accepted_trace_evidence": handoff.TRACE_EVIDENCE_SCHEMAS,
                },
            },
            "source_identity": {"archive": "mes.arc", "entry": "TEST.MES"},
            "container": {"raw_hex": "00000000"},
            "record_alignment": {"framed_bytes": 0},
            "typed_ir": {"instructions": [], "opaque_boundaries": []},
            "references": {"messages": [], "code": [], "state": [], "resources": []},
            "cfg": [],
            "calls": [],
            "traces": [],
            "capability_report": {"product_ui_data": "forbidden"},
        }
        document["payload_sha256"] = handoff.fingerprint(document)
        return document

    def test_accepts_current_language_neutral_contract(self) -> None:
        document = self.fixture()
        result = handoff.validate(document)
        self.assertTrue(result["ok"])
        self.assertEqual(handoff.HANDOFF_SCHEMA, result["schema"])

    def test_rejects_payload_mutation(self) -> None:
        document = self.fixture()
        document["container"]["raw_hex"] = "01"
        with self.assertRaisesRegex(handoff.HandoffValidationError, "fingerprint changed"):
            handoff.validate(document)

    def test_rejects_component_schema_drift(self) -> None:
        document = self.fixture()
        document["compatibility"]["component_schemas"]["instruction"] = "future/v1"
        document["payload_sha256"] = handoff.fingerprint(document)
        with self.assertRaisesRegex(handoff.HandoffValidationError, "component schema"):
            handoff.validate(document)

    def test_rejects_previous_instruction_boundary_schema(self) -> None:
        document = self.fixture()
        self.assertEqual(
            "ai5_mes_instruction/v45", handoff.COMPONENT_SCHEMAS["instruction"]
        )
        document["compatibility"]["component_schemas"]["instruction"] = "ai5_mes_instruction/v44"
        document["payload_sha256"] = handoff.fingerprint(document)
        with self.assertRaisesRegex(handoff.HandoffValidationError, "component schema"):
            handoff.validate(document)

    def test_rejects_product_ui_fields_even_with_valid_hash(self) -> None:
        document = self.fixture()
        document["traces"].append({"status_label": "not analyzer data"})
        document["payload_sha256"] = handoff.fingerprint(document)
        with self.assertRaisesRegex(handoff.HandoffValidationError, "product UI"):
            handoff.validate(document)

    def test_rejects_previous_event_trace_schema(self) -> None:
        document = self.fixture()
        self.assertEqual("kakyu_mes_event_trace/v68", handoff.TRACE_EVIDENCE_SCHEMAS[0])
        document["compatibility"]["component_schemas"]["accepted_trace_evidence"] = [
            "kakyu_mes_event_trace/v67", *handoff.TRACE_EVIDENCE_SCHEMAS[1:]
        ]
        document["payload_sha256"] = handoff.fingerprint(document)
        with self.assertRaisesRegex(handoff.HandoffValidationError, "trace evidence schemas"):
            handoff.validate(document)

    def test_fingerprint_is_key_order_independent(self) -> None:
        document = self.fixture()
        reordered = {key: copy.deepcopy(document[key]) for key in reversed(document)}
        self.assertEqual(handoff.fingerprint(document), handoff.fingerprint(reordered))


if __name__ == "__main__":
    unittest.main()
