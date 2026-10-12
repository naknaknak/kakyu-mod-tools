from __future__ import annotations

import sys
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

import audit_mes_definition_registry as audit  # noqa: E402


class MesDefinitionRegistryAuditTests(unittest.TestCase):
    def test_definition_body_record_and_invocation_are_not_treated_as_same_registry(self) -> None:
        code = bytearray([0x10, 0x02, 0x1A, 0xFF, 0x00])
        code.extend((10).to_bytes(4, "little"))
        code.append(0x00)
        code.extend([0x11, 0x02, 0x1A, 0xFF, 0x00, 0x00])
        data = (0).to_bytes(4, "little") + bytes(code)
        result = audit.scan_payload("TEST.MES", data)
        self.assertTrue(result["ok"])
        self.assertEqual([], result["def26_context_registrations"])
        self.assertEqual([0], result["def26_definition_body_offsets"])
        self.assertEqual([10], result["def26_invocation_offsets"])
        self.assertEqual(1, result["raw_def26_definition_body_pattern_count"])

    def test_command14_registers_context_for_command11_selector(self) -> None:
        code = bytearray([0x14, 0x1A, 0xFF])
        code.extend((8).to_bytes(4, "little"))
        code.extend([0x00, 0x00])
        data = (0).to_bytes(4, "little") + bytes(code)
        result = audit.scan_payload("CONTEXT.MES", data)
        self.assertTrue(result["ok"])
        self.assertEqual(
            [{"source_offset": 0, "body_offset": 7, "skip_target": 8}],
            result["def26_context_registrations"],
        )
        self.assertEqual({26: 1}, result["literal_context_registration_id_counts"])

    def test_nonliteral_or_invalid_target_is_not_a_registration(self) -> None:
        code = bytes([0x10, 0x02, 0x1A, 0xFF, 0x00, 0xFF, 0xFF, 0xFF, 0x7F, 0x00])
        data = (0).to_bytes(4, "little") + code
        result = audit.scan_payload("BAD.MES", data)
        self.assertTrue(result["ok"])
        self.assertEqual(0, result["canonical_definition_body_count"])
        self.assertEqual(1, result["rejected_definition_body_count"])
        self.assertEqual({"target_out_of_bounds": 1}, result["rejected_definition_body_reason_counts"])
        self.assertEqual(
            {"out_of_bounds": 1}, result["rejected_definition_body_target_status_counts"]
        )

    def test_nonliteral_selector_is_reported_without_guessing_its_value(self) -> None:
        code = bytearray([0x10, 0x02, 0x80, 0x04, 0xFF, 0x00])
        code.extend((11).to_bytes(4, "little"))
        code.extend([0x00, 0x00])
        data = (0).to_bytes(4, "little") + bytes(code)
        result = audit.scan_payload("DYNAMIC.MES", data)
        self.assertTrue(result["ok"])
        self.assertEqual(0, result["canonical_definition_body_count"])
        self.assertEqual(
            {"selector_expression_nonliteral": 1},
            result["rejected_definition_body_reason_counts"],
        )
        self.assertNotEqual("", result["rejected_definition_body_samples"][0]["selector_ast_type"])
        self.assertEqual(
            ["tag_0x02:expression_record:valid:state_ref"],
            result["rejected_definition_body_samples"][0]["selector_record_shapes"],
        )
        self.assertEqual(
            "valid_forward_boundary",
            result["rejected_definition_body_samples"][0]["target_status"],
        )


if __name__ == "__main__":
    unittest.main()
