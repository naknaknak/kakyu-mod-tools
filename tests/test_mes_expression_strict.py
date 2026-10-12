from __future__ import annotations

import sys
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

import mes_expression  # noqa: E402
import mes_partial_decoder as decoder  # noqa: E402


LITERAL_7 = bytes([0xF1, 0x07, 0x00])
TERMINATOR = bytes([0xFF])


class StrictStackDepthTests(unittest.TestCase):
    """Strict parsing fails closed where the permissive mode only complains."""

    def test_one_result_parses_in_both_modes(self) -> None:
        code = LITERAL_7 + TERMINATOR
        for strict in (False, True):
            with self.subTest(strict=strict):
                expression = mes_expression.parse_expression(code, 0, strict=strict)
                self.assertEqual(expression["end_offset"], len(code))
                self.assertEqual(expression["ast"]["value"], 7)

    def test_an_empty_stack_is_a_diagnostic_permissively(self) -> None:
        expression = mes_expression.parse_expression(TERMINATOR, 0)
        self.assertFalse(expression["valid"])
        self.assertEqual(expression["ast"], {"type": "stack", "items": []})

    def test_an_empty_stack_fails_closed_strictly(self) -> None:
        with self.assertRaises(mes_expression.ExpressionError):
            mes_expression.parse_expression(TERMINATOR, 0, strict=True)

    def test_a_deep_stack_fails_closed_strictly(self) -> None:
        code = LITERAL_7 + LITERAL_7 + TERMINATOR
        self.assertEqual(len(mes_expression.parse_expression(code, 0)["ast"]["items"]), 2)
        with self.assertRaises(mes_expression.ExpressionError):
            mes_expression.parse_expression(code, 0, strict=True)

    def test_the_default_mode_stays_permissive(self) -> None:
        # Other consumers read this parser structurally; only the framing
        # decoder opts into strict, so the default must not change under them.
        self.assertFalse(mes_expression.parse_expression(TERMINATOR, 0)["valid"])


class ExpressionBoundTests(unittest.TestCase):
    """Every operand read stops at the expression's own limit."""

    def test_a_literal_crossing_the_limit_is_truncated(self) -> None:
        code = bytes([0xF1, 0x07, 0x00, 0xFF])
        with self.assertRaises(mes_expression.ExpressionError):
            mes_expression.parse_expression(code, 0, max_bytes=2)

    def test_a_bank_byte_crossing_the_limit_is_truncated(self) -> None:
        code = LITERAL_7 + bytes([0xA0, 0x00, 0xFF])
        self.assertEqual(mes_expression.parse_expression(code, 0)["end_offset"], len(code))
        with self.assertRaises(mes_expression.ExpressionError):
            mes_expression.parse_expression(code, 0, max_bytes=4)

    def test_the_scan_never_runs_past_the_format_maximum(self) -> None:
        # No terminator inside 0x1000 bytes, and a caller that would allow more.
        code = bytes([0x01]) * (mes_expression.MAX_EXPRESSION_BYTES + 16) + TERMINATOR
        with self.assertRaises(mes_expression.ExpressionError):
            mes_expression.parse_expression(code, 0, max_bytes=len(code))


class DecoderUsesStrictTests(unittest.TestCase):
    """The framing decoder is the strict consumer."""

    def test_a_wrong_depth_expression_stops_the_decoder(self) -> None:
        # Command 0x0B reads a condition; two results where one is required.
        code = bytes([0x0B]) + LITERAL_7 + LITERAL_7 + TERMINATOR + bytes([0, 0, 0, 0])
        with self.assertRaises(decoder.MesDecodeError):
            decoder.decode_instruction(code, 0, len(code))

    def test_a_single_result_expression_still_decodes(self) -> None:
        code = bytes([0x0B]) + LITERAL_7 + TERMINATOR + bytes([8, 0, 0, 0])
        instruction = decoder.decode_instruction(code, 0, len(code))
        self.assertEqual(instruction["op"], "branch_if_not_true")
        self.assertEqual(instruction["endOffset"], len(code))


if __name__ == "__main__":
    unittest.main()
