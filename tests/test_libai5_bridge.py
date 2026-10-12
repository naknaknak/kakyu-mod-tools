"""Unit tests for the libai5 bridge's output parsing (no archive, no binary)."""
from __future__ import annotations

import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools" / "libai5_bridge"))

import mes_libai5 as bridge  # noqa: E402


class BridgeParseTests(unittest.TestCase):
    def test_parse_output_reads_statements_and_status(self):
        text = ("STMT 15357 15362 29 \tcall_sub(8);\n"
                "STMT 15362 15387 13 \tSystem.function[24](4,0,\"bll.mmo\",0,0);\n"
                "STMT 26749 26762 14 \tjump(\"machi.mes\");\n"
                "OK 26768 2588\n")
        statements, status = bridge.parse_output(text)
        self.assertEqual(status, "OK 26768 2588")
        self.assertEqual([(s.address, s.end, s.op) for s in statements], [(15357, 15362, 29), (15362, 15387, 13), (26749, 26762, 14)])
        self.assertEqual(statements[1].sys_function, 24)
        self.assertIsNone(statements[0].sys_function)
        self.assertIn("CALL_SUB", statements[0].op_name)
        self.assertIn("root handoff", statements[2].op_name)

    def test_parse_output_keeps_a_failure_line(self):
        statements, status = bridge.parse_output("STMT 0 5 31 \tOP_0x1F 1;\nFAIL 5\n")
        self.assertEqual(len(statements), 1)
        self.assertEqual(status, "FAIL 5")


if __name__ == "__main__":
    unittest.main()
