from __future__ import annotations

import sys
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

import mes_expression as expression  # noqa: E402


class ExpressionIrSuccessTests(unittest.TestCase):
    def test_strict_result_has_the_analyzer_fields_and_absolute_coordinates(self) -> None:
        self.assertEqual(
            expression.parse_expression_ir(bytes.fromhex("0000f13412ff00"), 2, 6),
            {
                "ok": True,
                "offset": 2,
                "end_offset": 6,
                "byte_length": 4,
                "raw_hex": "f13412ff",
                "ast": {
                    "type": "literal",
                    "value": 0x1234,
                    "width": 16,
                    "source": {"offset": 2, "token": "0xf1"},
                },
            },
        )

    def test_unsigned_32_bit_literal_is_preserved(self) -> None:
        result = expression.parse_expression_ir(bytes.fromhex("f2ffffffff ff"), 0)
        self.assertEqual(result["ast"]["value"], 0xFFFFFFFF)
        self.assertEqual(result["ast"]["width"], 32)

    def test_binary_operators_keep_source_and_operand_order(self) -> None:
        for token, operation in expression.BINARY_OPS.items():
            with self.subTest(token=token):
                result = expression.parse_expression_ir(bytes([3, 4, token, 0xFF]), 0)
                self.assertTrue(result["ok"])
                self.assertEqual(result["ast"], {
                    "type": "binary",
                    "op": operation,
                    "lhs": {"type": "literal", "value": 3, "width": 8,
                            "source": {"offset": 0, "token": "0x03"}},
                    "rhs": {"type": "literal", "value": 4, "width": 8,
                            "source": {"offset": 1, "token": "0x04"}},
                    "source": {"offset": 2, "token": f"0x{token:02x}"},
                })

    def test_random_call_preserves_its_argument(self) -> None:
        result = expression.parse_expression_ir(bytes.fromhex("05e5ff"), 0)
        self.assertEqual(result["ast"]["name"], "random_below")
        self.assertEqual(result["ast"]["args"][0]["value"], 5)

    def test_direct_state_references_include_the_default_bank(self) -> None:
        for raw_hex, storage, index in [
            ("8007ff", "state_u16", 7),
            ("f807ff", "state_i32", 7),
            ("f33412ff", "global_u8", 0x1234),
            ("f63412ff", "global_i32", 0x1234),
        ]:
            with self.subTest(storage=storage):
                result = expression.parse_expression_ir(bytes.fromhex(raw_hex), 0)
                self.assertEqual(result["ast"]["bank"], 0)
                self.assertEqual(result["ast"]["storage"], storage)
                self.assertEqual(result["ast"]["index"], {"type": "literal", "value": index})

    def test_dynamic_and_banked_references_preserve_nested_default_banks(self) -> None:
        for token, storage, suffix, bank in [
            (0xF5, "global_u8", b"", 0),
            (0xF7, "global_i32", b"", 0),
            (0xA0, "banked_u16", b"\x06", 6),
            (0xC0, "banked_u8", b"\x06", 6),
            (0xF9, "banked_i32", b"\x06", 6),
        ]:
            with self.subTest(storage=storage):
                result = expression.parse_expression_ir(b"\x80\x07" + bytes([token]) + suffix + b"\xff", 0)
                self.assertEqual(result["ast"]["storage"], storage)
                self.assertEqual(result["ast"]["bank"], bank)
                self.assertEqual(result["ast"]["index"]["bank"], 0)

    def test_default_bank_projection_handles_deep_valid_asts(self) -> None:
        result = expression.parse_expression_ir(b"\x80\x01" + b"\xf5" * 1500 + b"\xff", 0)
        self.assertTrue(result["ok"])
        node = result["ast"]
        count = 0
        while node["type"] == "state_ref":
            self.assertEqual(node["bank"], 0)
            node = node["index"]
            count += 1
        self.assertEqual(count, 1501)

    def test_structural_single_result_carries_validity(self) -> None:
        result = expression.parse_expression_ir(b"\x01\xff", 0, structural=True)
        self.assertTrue(result["valid"])
        self.assertEqual(result["diagnostics"], [])

    def test_structural_non_single_stack_is_boundary_only(self) -> None:
        for raw, depth in [(b"\xff", 0), (b"\x01\x02\xff", 2)]:
            with self.subTest(depth=depth):
                result = expression.parse_expression_ir(raw, 0, structural=True)
                self.assertTrue(result["ok"])
                self.assertFalse(result["valid"])
                self.assertEqual(result["ast"]["type"], "stack")
                self.assertEqual(len(result["ast"]["items"]), depth)
                self.assertEqual(result["diagnostics"], [
                    f"Expression ended with stack depth {depth}, expected 1.",
                ])


class ExpressionIrFailureTests(unittest.TestCase):
    def assert_ir_error(self, raw: bytes, message: str, end: int, *, limit: int = -1) -> None:
        # The nonzero start distinguishes expression coordinates from the
        # current token and from a slice-relative implementation.
        for structural in (False, True):
            with self.subTest(structural=structural):
                self.assertEqual(
                    expression.parse_expression_ir(b"\x00\x00" + raw, 2, limit, structural),
                    {"ok": False, "error": message, "offset": 2, "end_offset": end + 2},
                )

    def test_invalid_offsets_have_no_consumed_coordinate(self) -> None:
        for data, offset in [(b"", 0), (b"\xff", -1), (b"\xff", 1), (b"\xff", 2)]:
            with self.subTest(data=data, offset=offset):
                self.assertEqual(expression.parse_expression_ir(data, offset), {
                    "ok": False, "error": "Expression offset is outside bytecode.",
                })

    def test_strict_wrong_stack_depth_reports_consumed_terminator(self) -> None:
        for raw, depth in [(b"\xff", 0), (b"\x01\x02\xff", 2)]:
            with self.subTest(depth=depth):
                self.assertEqual(expression.parse_expression_ir(raw, 0), {
                    "ok": False,
                    "error": f"Expression ended with stack depth {depth}, expected 1.",
                    "offset": 0,
                    "end_offset": len(raw),
                })

    def test_binary_underflow_is_reported_after_the_token(self) -> None:
        for token in expression.BINARY_OPS:
            for prefix in (b"", b"\x01"):
                with self.subTest(token=token, prefix=prefix):
                    self.assert_ir_error(prefix + bytes([token, 0xFF]),
                                         f"Expression stack underflow for token 0x{token:02X}.",
                                         len(prefix) + 1)

    def test_random_and_dynamic_global_underflow(self) -> None:
        for token, name in [(0xE5, "random_below"), (0xF5, "dynamic global index"), (0xF7, "dynamic global index")]:
            with self.subTest(token=token):
                self.assert_ir_error(bytes([token, 0xFF]), f"Expression stack underflow for {name}.", 1)

    def test_truncated_operands_keep_the_cursor_before_the_read(self) -> None:
        for raw, kind in [
            (b"\xf1\x00", "literal"),
            (b"\xf2\x00\x00\x00", "literal"),
            (b"\x80", "state index"),
            (b"\xf8", "state index"),
            (b"\xf3\x00", "global index"),
            (b"\xf6\x00", "global index"),
        ]:
            with self.subTest(raw=raw):
                self.assert_ir_error(raw, f"Expression {kind} is truncated.", 1)

    def test_banked_reference_errors_have_one_authoritative_diagnostic(self) -> None:
        for token in (0xA0, 0xC0, 0xF9):
            with self.subTest(token=token):
                self.assert_ir_error(bytes([token, 0, 0xFF]), "Expression banked state reference is truncated.", 1)
                self.assert_ir_error(bytes([1, token]), "Expression banked state reference is truncated.", 2)

    def test_absolute_limit_can_truncate_an_operand_before_buffer_end(self) -> None:
        self.assert_ir_error(b"\xf1\x34\x12\xff", "Expression literal is truncated.", 1, limit=4)

    def test_limit_at_or_before_start_reports_an_unread_expression(self) -> None:
        for limit in (0, 2):
            with self.subTest(limit=limit):
                self.assert_ir_error(b"\x01\xff", "Expression is missing its 0xFF terminator.", 0, limit=limit)

    def test_missing_terminator_and_maximum_scan_length(self) -> None:
        self.assert_ir_error(b"\x01", "Expression is missing its 0xFF terminator.", 1)
        raw = b"\x01" * (expression.MAX_EXPRESSION_BYTES + 1) + b"\xff"
        self.assert_ir_error(raw, "Expression is missing its 0xFF terminator.", expression.MAX_EXPRESSION_BYTES)


class LegacyExpressionContractTests(unittest.TestCase):
    def test_legacy_success_shape_and_ast_remain_unchanged(self) -> None:
        result = expression.parse_expression(b"\x80\x01\xff", 0, strict=True)
        self.assertNotIn("ok", result)
        self.assertNotIn("bank", result["ast"])
        self.assertTrue(result["valid"])
        self.assertEqual(result["diagnostics"], [])

    def test_legacy_diagnostic_spelling_remains_unchanged(self) -> None:
        result = expression.parse_expression(b"\xff", 0)
        self.assertEqual(result["diagnostics"], ["expression ended with stack depth 0, expected 1"])

    def test_exception_text_is_preserved_with_structured_error_attached(self) -> None:
        with self.assertRaises(expression.ExpressionError) as caught:
            expression.parse_expression(b"\x00\xf1\x00", 1)
        self.assertEqual(str(caught.exception), "truncated 2-byte operand at 0x2")
        self.assertEqual(caught.exception.ir_error, {
            "ok": False, "error": "Expression literal is truncated.", "offset": 1, "end_offset": 2,
        })

    def test_strict_stack_exception_text_is_preserved(self) -> None:
        with self.assertRaises(expression.ExpressionError) as caught:
            expression.parse_expression(b"\xff", 0, strict=True)
        self.assertEqual(str(caught.exception), "expression at 0x0 ended with stack depth 0, expected 1")

    def test_legacy_outside_offset_keeps_text_and_has_the_ir_range_error(self) -> None:
        with self.assertRaises(expression.ExpressionError) as caught:
            expression.parse_expression(b"\x01", 1, strict=True)
        self.assertEqual(str(caught.exception), "missing 0xff expression terminator before end of file (start 0x1)")
        self.assertEqual(caught.exception.ir_error, {
            "ok": False, "error": "Expression offset is outside bytecode.",
        })


if __name__ == "__main__":
    unittest.main()
