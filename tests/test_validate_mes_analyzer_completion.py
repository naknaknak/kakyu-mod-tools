from __future__ import annotations

import sys
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

import validate_mes_analyzer_completion as completion  # noqa: E402
from validate_mes_analyzer_handoff import fingerprint  # noqa: E402


class MesAnalyzerCompletionTests(unittest.TestCase):
    def fixture(self) -> dict:
        document = {
            "schema": completion.COMPLETION_SCHEMA,
            "handoff_schema": completion.HANDOFF_SCHEMA,
            "component_schemas": completion.COMPONENT_SCHEMAS.copy(),
            "source_archive_sha256": "source",
            "corpus_handoff_sha256": completion.CORPUS_HANDOFF_SHA256,
            "phase_status": {str(phase): "closed" for phase in range(1, 5)},
            "counts": completion.EXPECTED_COUNTS.copy(),
            "supported_typed_forms": {"text": 1},
            "explicit_native_boundaries": {"typed_record": 1},
            "code_reference_kinds": {"continuation_target": 1},
            "resource_reference_kinds": {"mmo": 1},
            "explicit_opaque_boundaries": {
                "strict": {"count": 1, "bytes": 1, "policy": "byte_preserving_fail_closed"}
            },
            "remaining_numeric_or_unresolved_meanings": ["state_and_bank_indices"],
            "compatibility_policy": "exact_handoff_and_component_schema_match",
            "phase5_default_consumer": "python_offline_decompiler",
            "godot_role": "gdscript_phase1_4_producer_and_runtime_validator",
            "product_ui_data": "forbidden",
            "source_mutation": "forbidden",
        }
        document["payload_sha256"] = fingerprint(document)
        return document

    def test_accepts_current_completion_contract(self) -> None:
        self.assertTrue(completion.validate(self.fixture())["ok"])

    def test_rejects_corpus_drift(self) -> None:
        document = self.fixture()
        document["corpus_handoff_sha256"] = "0" * 64
        document["payload_sha256"] = fingerprint(document)
        with self.assertRaisesRegex(completion.HandoffValidationError, "corpus"):
            completion.validate(document)

    def test_rejects_incomplete_phase_status(self) -> None:
        document = self.fixture()
        document["phase_status"]["4"] = "open"
        document["payload_sha256"] = fingerprint(document)
        with self.assertRaisesRegex(completion.HandoffValidationError, "not closed"):
            completion.validate(document)

    def test_rejects_inventory_mutation(self) -> None:
        document = self.fixture()
        document["counts"]["entries"] += 1
        document["payload_sha256"] = fingerprint(document)
        with self.assertRaisesRegex(completion.HandoffValidationError, "counts changed"):
            completion.validate(document)


if __name__ == "__main__":
    unittest.main()
