from __future__ import annotations

import copy
import sys
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
sys.path.insert(0, str(ROOT / "tools"))

import audit_mes_decompiler_equivalence as auditor  # noqa: E402
import render_mes_pseudocode as renderer  # noqa: E402
from tests import test_render_mes_pseudocode as renderer_tests  # noqa: E402


class MesDecompilerEquivalenceAuditTests(unittest.TestCase):
    def fixture(self) -> tuple[dict, dict]:
        renderer_input = renderer_tests.MesPseudocodeRendererTests().fixture()
        return renderer_input, renderer.render(renderer_input)

    def test_audits_complete_node_fallback_and_line_equivalence(self) -> None:
        renderer_input, pseudocode = self.fixture()
        document = auditor.audit(renderer_input, pseudocode)

        self.assertEqual(auditor.EQUIVALENCE_AUDIT_SCHEMA, document["schema"])
        self.assertTrue(document["equivalent"])
        self.assertEqual(3, document["coverage"]["linear_node_count"])
        self.assertEqual(11, document["coverage"]["linear_byte_count"])
        self.assertEqual(2, document["coverage"]["fallback_statement_count"])
        self.assertTrue(document["coverage"]["all_linear_nodes_rendered_once"])
        self.assertTrue(document["coverage"]["all_rendered_sources_reverse"])

    def test_publishes_opaque_and_semantic_unresolved_inventory(self) -> None:
        document = auditor.audit(*self.fixture())
        inventory = document["unresolved_inventory"]

        self.assertEqual(1, document["coverage"]["opaque_node_count"])
        self.assertEqual(
            "linear_00000007", inventory["opaque_nodes"][0]["linear_node_id"]
        )
        self.assertIn("state_meaning", inventory["semantic_categories"])
        self.assertGreaterEqual(document["coverage"]["unresolved_control_count"], 1)

    def test_audit_is_deterministic(self) -> None:
        inputs = self.fixture()
        first = auditor.audit(*inputs)
        second = auditor.audit(*(copy.deepcopy(value) for value in inputs))
        self.assertEqual(first, second)
        self.assertEqual(first["payload_sha256"], auditor.fingerprint(first))

    def test_rejects_rehashed_audit_mutation(self) -> None:
        renderer_input, pseudocode = self.fixture()
        document = auditor.audit(renderer_input, pseudocode)
        document["coverage"]["all_linear_nodes_rendered_once"] = False
        document["payload_sha256"] = auditor.fingerprint(document)
        with self.assertRaisesRegex(
            auditor.EquivalenceAuditError, "projection changed"
        ):
            auditor.validate(document, renderer_input, pseudocode)

    def test_rejects_linear_partition_gap(self) -> None:
        with self.assertRaisesRegex(
            auditor.EquivalenceAuditError, "partition changed"
        ):
            auditor._source_partition(
                [
                    {
                        "id": "linear_00000001",
                        "source": {
                            "start": 1,
                            "end": 2,
                            "raw_hex": "00",
                            "raw_sha256": "0" * 64,
                        },
                    }
                ],
                [{"node_ids": ["linear_00000001"]}],
            )

    def test_rejects_pseudocode_from_another_renderer_input(self) -> None:
        renderer_input, pseudocode = self.fixture()
        pseudocode["input"]["renderer_input_sha256"] = "0" * 64
        pseudocode["payload_sha256"] = renderer.fingerprint(pseudocode)
        with self.assertRaisesRegex(
            renderer.PseudocodeRenderError, "projection changed"
        ):
            auditor.audit(renderer_input, pseudocode)


if __name__ == "__main__":
    unittest.main()
