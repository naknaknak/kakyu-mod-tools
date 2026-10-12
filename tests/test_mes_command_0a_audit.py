from __future__ import annotations

import sys
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
TOOLS = ROOT / "tools"
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))

import audit_mes_command_0a


class MesCommand0AAuditTests(unittest.TestCase):
    def test_reports_complete_valid_write_run_without_payload_bytes(self) -> None:
        code = bytes([0x0A, 2, 0xFF, 3, 0xFF, 1, 4, 0xFF, 0, 0x00])
        result = audit_mes_command_0a.scan_code(code)
        self.assertEqual(1, len(result["rows"]))
        row = result["rows"][0]
        self.assertTrue(row["strict_valid"])
        self.assertEqual(9, row["end_offset"])
        self.assertEqual([1, 0], row["continuations"])
        self.assertEqual([1, 1], row["value_stack_depths"])
        self.assertEqual([1, 1, 1], row["isolated_expression_stack_depths"])
        self.assertEqual(0, row["minimum_incoming_stack"])
        self.assertEqual(0, row["net_stack_delta"])
        self.assertNotIn("raw_hex", row)

    def test_retains_non_strict_final_stack_depths(self) -> None:
        code = bytes([0x0A, 0xFF, 2, 1, 0xFF, 0, 0x00])
        result = audit_mes_command_0a.scan_code(code)
        row = result["rows"][0]
        self.assertFalse(row["strict_valid"])
        self.assertEqual(0, row["destination_stack_depth"])
        self.assertEqual([2], row["value_stack_depths"])
        self.assertEqual([0, 2], row["isolated_expression_stack_depths"])
        self.assertEqual(1, row["minimum_incoming_stack"])
        self.assertEqual(0, row["net_stack_delta"])

    def test_deferred_ff_boundary_exposes_the_following_write(self) -> None:
        code = bytes([0x01, 0xFF, 0x0A, 0xFF, 2, 1, 0xFF, 0, 0x00])
        result = audit_mes_command_0a.scan_code(code)
        self.assertEqual(1, len(result["rows"]))
        self.assertEqual(2, result["rows"][0]["source_offset"])
        self.assertEqual([0, 2], result["rows"][0]["isolated_expression_stack_depths"])


if __name__ == "__main__":
    unittest.main()
