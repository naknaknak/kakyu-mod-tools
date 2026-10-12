from __future__ import annotations

import sys
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

import mes_partial_decoder as decoder  # noqa: E402
import mes_tolerant_ir as tolerant_decoder  # noqa: E402


# One 16-bit literal expression: token 0xf1, the value, then the 0xff terminator.
LITERAL_7 = bytes([0xF1, 0x07, 0x00, 0xFF])


def decode_one(code: bytes) -> dict:
    instruction = decoder.decode_instruction(code, 0, len(code))
    assert instruction is not None
    return instruction


class LegacyExpressionHookTests(unittest.TestCase):
    def test_legacy_projection_retains_underflow_through_the_three_argument_hook(self) -> None:
        # These fallback forms use the base decoder through the existing legacy
        # wrapper. Its tolerant AST deliberately retains operator underflow.
        samples = (
            bytes.fromhex("14e0ff00000000"),
            bytes.fromhex("18e0ff"),
            bytes.fromhex("0ae0ff01ff00"),
            bytes.fromhex("0400e0ff00"),
        )
        original_hook = decoder.decode_expression
        for code in samples:
            with self.subTest(code=code.hex()):
                instruction = tolerant_decoder.decode_instruction(code, 0, len(code))
                self.assertEqual(instruction["endOffset"], len(code))
                operand = instruction["operands"][0]
                expression = (
                    instruction["operands"][-1]["pairs"][0]["expression"]
                    if code[0] == 0x04 else operand["value"]
                )
                self.assertFalse(expression["valid"])
                self.assertEqual(expression["ast"]["type"], "binary")
                self.assertEqual(expression["ast"]["lhs"]["type"], "underflow")
                self.assertTrue(expression["diagnostics"])
                self.assertIs(decoder.decode_expression, original_hook)

    def test_authority_modes_still_reject_operator_underflow_after_legacy_decode(self) -> None:
        code = bytes.fromhex("18e0ff")
        tolerant_decoder.decode_instruction(code, 0, len(code))
        for structural in (False, True):
            with self.subTest(structural=structural):
                with self.assertRaisesRegex(decoder.MesDecodeError, "stack underflow"):
                    decoder.decode_instruction(code, 0, len(code), structural=structural)

    def test_explicit_structural_mode_retains_final_stack_without_changing_strict_default(self) -> None:
        code = bytes.fromhex("180102ff")
        legacy = tolerant_decoder.decode_instruction(code, 0, len(code))
        structural = decoder.decode_instruction(code, 0, len(code), structural=True)
        for instruction in (legacy, structural):
            expression = instruction["operands"][0]["value"]
            self.assertFalse(expression["valid"])
            self.assertEqual(len(expression["ast"]["items"]), 2)
            self.assertEqual(instruction["endOffset"], len(code))
        with self.assertRaises(decoder.MesDecodeError):
            decode_one(code)


class RecordListFramingTests(unittest.TestCase):
    """The record list is what eight commands share, so it is framed once."""

    def test_every_record_list_command_is_framed(self) -> None:
        for command_id in decoder.RECORD_LIST_COMMANDS:
            if command_id == 0x10:
                continue
            with self.subTest(command=f"0x{command_id:02x}"):
                instruction = decode_one(bytes([command_id, 0x00]))
                self.assertEqual(instruction["endOffset"], 2)
                self.assertEqual(instruction["operands"][0]["records"], [])

    def test_the_zero_tag_is_consumed_and_ends_the_list(self) -> None:
        instruction = decode_one(bytes([0x1B, 0x00, 0x99]))
        self.assertEqual(instruction["endOffset"], 2)
        self.assertEqual(instruction["operands"][0]["endOffset"], 2)

    def test_tag_one_is_a_nul_terminated_byte_string(self) -> None:
        instruction = decode_one(bytes([0x1D]) + b"\x01A.MES\x00" + b"\x00")
        record = instruction["operands"][0]["records"][0]
        self.assertEqual(record["type"], "string_record")
        self.assertEqual(bytes.fromhex(record["value"]["rawHex"]), b"A.MES")
        self.assertEqual(instruction["endOffset"], 9)

    def test_tag_two_is_an_expression(self) -> None:
        instruction = decode_one(bytes([0x1B, 0x02]) + LITERAL_7 + bytes([0x00]))
        record = instruction["operands"][0]["records"][0]
        self.assertEqual(record["type"], "expression_record")
        self.assertEqual(record["value"]["ast"]["value"], 7)
        self.assertEqual(instruction["endOffset"], 7)

    def test_an_unknown_tag_is_one_byte_and_does_not_end_the_list(self) -> None:
        instruction = decode_one(bytes([0x0E, 0xFF, 0x02]) + LITERAL_7 + bytes([0x00]))
        records = instruction["operands"][0]["records"]
        self.assertEqual([record["type"] for record in records], ["unknown_tag", "expression_record"])
        self.assertEqual(instruction["endOffset"], 8)

    def test_records_carry_the_offset_of_their_own_tag(self) -> None:
        instruction = decode_one(bytes([0x1B, 0xFF, 0xFE, 0x00]))
        records = instruction["operands"][0]["records"]
        self.assertEqual([record["sourceOffset"] for record in records], [1, 2])

    def test_command_10_carries_four_bytes_after_the_list(self) -> None:
        instruction = decode_one(bytes([0x10, 0x00, 1, 2, 3, 4]))
        self.assertEqual(instruction["endOffset"], 6)
        self.assertEqual(instruction["operands"][1], {"type": "u8_array", "value": [1, 2, 3, 4]})

    def test_command_10_fails_closed_when_its_four_bytes_are_short(self) -> None:
        with self.assertRaises(decoder.MesDecodeError):
            decode_one(bytes([0x10, 0x00, 1, 2, 3]))

    def test_an_unterminated_list_fails_closed(self) -> None:
        with self.assertRaises(decoder.MesDecodeError):
            decode_one(bytes([0x1B, 0xFF, 0xFF]))

    def test_an_unterminated_string_record_fails_closed(self) -> None:
        with self.assertRaises(decoder.MesDecodeError):
            decode_one(bytes([0x1B, 0x01]) + b"NOSTOP")

    def test_a_record_list_never_reads_past_its_limit(self) -> None:
        code = bytes([0x1B, 0x00, 0x00])
        with self.assertRaises(decoder.MesDecodeError):
            decoder.decode_instruction(code, 0, 1)


class NativeRecordDispatchTests(unittest.TestCase):
    """0x12 is the typed-record dispatcher, not a character stream."""

    def test_command_12_is_a_record_list_rather_than_an_empty_grammar(self) -> None:
        self.assertNotIn(0x12, decoder.FIXED_GRAMMARS)
        instruction = decode_one(bytes([0x12, 0x02]) + LITERAL_7 + bytes([0x02]) + LITERAL_7 + bytes([0x00]))
        self.assertEqual(instruction["nativeRecordCount"], 2)
        self.assertEqual(instruction["endOffset"], 12)

    def test_command_12_declares_the_dispatcher_family_and_terminator(self) -> None:
        instruction = decode_one(bytes([0x12, 0x00]))
        self.assertEqual(instruction["nativeHandlerFamily"], "native_record_dispatch")
        self.assertEqual(instruction["nativeRecordConsumption"], "typed_record_list_until_zero")
        self.assertTrue(instruction["nativeRecordTerminatorConsumed"])
        self.assertEqual(instruction["nativeRecordDispatchSemantics"], "unresolved_not_executed")

    def test_command_12_is_no_longer_a_character_stream(self) -> None:
        instruction = decode_one(bytes([0x12, 0x00]))
        self.assertNotIn("nativeStreamProbe", instruction)

    def test_the_character_stream_commands_keep_their_probe(self) -> None:
        for command_id in (0x02, 0x0D):
            with self.subTest(command=f"0x{command_id:02x}"):
                instruction = decode_one(bytes([command_id, 0x41, 0x00]))
                self.assertEqual(instruction["nativeHandlerFamily"], "character_stream_presentation")
                self.assertIn("nativeStreamProbe", instruction)


class ExpressionBytePairRunTests(unittest.TestCase):
    """Nine write-run commands differ only in the header before one shared run."""

    def test_a_run_continues_until_a_zero_continuation(self) -> None:
        code = bytes([0x0A]) + LITERAL_7 + LITERAL_7 + bytes([0x01]) + LITERAL_7 + bytes([0x00])
        instruction = decode_one(code)
        pairs = instruction["operands"][-1]["pairs"]
        self.assertEqual([pair["continuation"] for pair in pairs], [1, 0])
        self.assertEqual(instruction["endOffset"], len(code))

    def test_a_single_pair_run_ends_at_its_first_zero(self) -> None:
        code = bytes([0x0A]) + LITERAL_7 + LITERAL_7 + bytes([0x00, 0x99])
        instruction = decode_one(code)
        self.assertEqual(len(instruction["operands"][-1]["pairs"]), 1)
        self.assertEqual(instruction["endOffset"], 10)

    def test_a_u16_header_command_reads_two_bytes(self) -> None:
        code = bytes([0x03, 0x34, 0x12]) + LITERAL_7 + bytes([0x00])
        instruction = decode_one(code)
        self.assertEqual(instruction["operands"][0], {"type": "u16_index", "value": 0x1234, "sourceOffset": 1})
        self.assertEqual(instruction["endOffset"], len(code))

    def test_a_u8_header_command_reads_one_byte(self) -> None:
        code = bytes([0x04, 0x09]) + LITERAL_7 + bytes([0x00])
        instruction = decode_one(code)
        self.assertEqual(instruction["operands"][0], {"type": "u8_index", "value": 9, "sourceOffset": 1})
        self.assertEqual(instruction["endOffset"], len(code))

    def test_a_banked_command_reads_a_destination_then_a_bank(self) -> None:
        code = bytes([0x07]) + LITERAL_7 + bytes([0x02]) + LITERAL_7 + bytes([0x00])
        instruction = decode_one(code)
        self.assertEqual(instruction["operands"][0]["type"], "expression_index")
        self.assertEqual(instruction["operands"][1], {"type": "u8_bank", "value": 2, "sourceOffset": 5})
        self.assertEqual(instruction["endOffset"], len(code))

    def test_every_pair_run_command_frames_a_two_pair_run(self) -> None:
        headers = {"": b"", "u8": bytes([0]), "u16": bytes([0, 0]), "e": LITERAL_7, "e+b": LITERAL_7 + bytes([0])}
        for command_id, (header, _op) in decoder.PAIR_RUN_OPS.items():
            with self.subTest(command=f"0x{command_id:02x}"):
                code = (
                    bytes([command_id])
                    + headers[header]
                    + LITERAL_7
                    + bytes([0x01])
                    + LITERAL_7
                    + bytes([0x00])
                )
                instruction = decode_one(code)
                self.assertEqual(instruction["endOffset"], len(code))
                self.assertEqual(len(instruction["operands"][-1]["pairs"]), 2)

    def test_a_truncated_continuation_fails_closed(self) -> None:
        with self.assertRaises(decoder.MesDecodeError):
            decode_one(bytes([0x0A]) + LITERAL_7 + LITERAL_7)

    def test_the_moved_commands_are_no_longer_fixed_grammars(self) -> None:
        self.assertEqual(set(decoder.FIXED_GRAMMARS) & set(decoder.PAIR_RUN_OPS), set())


class BranchAndTransferTests(unittest.TestCase):
    """0x0B carries a u32 target, which the fixed grammar read as five bytes."""

    def test_a_branch_reads_a_condition_then_a_u32_target(self) -> None:
        code = bytes([0x0B]) + LITERAL_7 + bytes([0x08, 0x00, 0x00, 0x00])
        instruction = decode_one(code)
        self.assertEqual(instruction["op"], "branch_if_not_true")
        self.assertEqual(instruction["operands"][1], {"type": "code_offset", "value": 8})
        self.assertEqual(instruction["endOffset"], 9)

    def test_a_branch_no_longer_swallows_a_fifth_byte(self) -> None:
        code = bytes([0x0B]) + LITERAL_7 + bytes([0x08, 0x00, 0x00, 0x00, 0x00])
        self.assertEqual(decode_one(code)["endOffset"], len(code) - 1)

    def test_a_truncated_branch_target_fails_closed(self) -> None:
        with self.assertRaises(decoder.MesDecodeError):
            decode_one(bytes([0x0B]) + LITERAL_7 + bytes([0x08, 0x00]))

    def test_a_continuation_transfer_is_one_u32(self) -> None:
        instruction = decode_one(bytes([0x0C, 0x10, 0x00, 0x00, 0x00]))
        self.assertEqual(instruction["op"], "continuation_transfer")
        self.assertEqual(instruction["operands"][0], {"type": "code_offset", "value": 16})
        self.assertEqual(instruction["endOffset"], 5)


class DoubleByteCharacterStreamTests(unittest.TestCase):
    """0x01 and the bytes above the command range share one CP932 run."""

    def test_a_nul_terminated_run_ends_inside_the_instruction(self) -> None:
        instruction = decode_one(bytes([0x01, 0x82, 0xA0, 0x82, 0xA2, 0x00]))
        self.assertEqual(instruction["op"], "text")
        self.assertEqual(instruction["endOffset"], 6)
        self.assertEqual(instruction["nativeStreamProbe"]["stopReason"], "nul_consumed")

    def test_a_deferred_ff_leaves_the_marker_to_the_next_instruction(self) -> None:
        instruction = decode_one(bytes([0x01, 0x82, 0xA0, 0xFF]))
        self.assertEqual(instruction["endOffset"], 3)
        self.assertEqual(instruction["nativeStreamProbe"]["stopReason"], "single_byte_marker_deferred")
        self.assertTrue(instruction["nativeStreamProjectionMatch"])

    def test_an_empty_deferred_run_is_the_bare_command(self) -> None:
        instruction = decode_one(bytes([0x01, 0xFF]))
        self.assertEqual(instruction["op"], "command_01")
        self.assertEqual(instruction["endOffset"], 1)
        self.assertEqual(instruction["operands"], [])

    def test_a_non_ff_stop_falls_back_to_the_byte_string(self) -> None:
        instruction = decode_one(bytes([0x01, 0x41, 0x42, 0x00]))
        self.assertEqual(instruction["op"], "text")
        self.assertEqual(instruction["endOffset"], 4)

    def test_a_character_lead_byte_is_itself_the_first_text_byte(self) -> None:
        instruction = decode_one(bytes([0x82, 0xA0, 0x82, 0xA2, 0xFF]))
        self.assertEqual(instruction["op"], "dispatcher_character_text")
        self.assertEqual(instruction["endOffset"], 4)
        self.assertEqual(
            bytes.fromhex(instruction["operands"][0]["rawHex"]), bytes([0x82, 0xA0, 0x82, 0xA2])
        )

    def test_a_character_lead_run_without_a_deferred_ff_keeps_its_lead(self) -> None:
        instruction = decode_one(bytes([0x82, 0x41, 0x42, 0x00]))
        self.assertEqual(instruction["endOffset"], 4)
        self.assertEqual(bytes.fromhex(instruction["operands"][0]["rawHex"]), bytes([0x82, 0x41, 0x42]))

    def test_ff_is_the_separator_and_consumes_one_byte(self) -> None:
        instruction = decode_one(bytes([0xFF, 0x00]))
        self.assertEqual(instruction["op"], "separator_ff")
        self.assertEqual(instruction["endOffset"], 1)

    def test_another_high_byte_is_a_one_byte_dispatcher_default(self) -> None:
        instruction = decode_one(bytes([0xA0, 0x00]))
        self.assertEqual(instruction["op"], "dispatcher_default_byte")
        self.assertEqual(instruction["endOffset"], 1)

    def test_the_lead_ranges_are_the_authoritative_ones(self) -> None:
        leads = [value for value in range(0x100) if decoder.is_character_lead(value)]
        self.assertEqual(
            leads,
            list(range(0x81, 0xA0)) + list(range(0xE0, 0xF0)) + list(range(0xFA, 0xFD)),
        )

    def test_a_truncated_pair_stops_the_probe_without_consuming_it(self) -> None:
        probe = decoder.probe_native_double_byte_stream(bytes([0x82]), 0, 1)
        self.assertEqual(probe["stopReason"], "truncated_pair")
        self.assertEqual(probe["probeEndOffset"], 0)


class PresentationCommandTests(unittest.TestCase):
    """0x0D is a tree of confirmed forms ending in a one-byte separator."""

    def test_an_unmatched_shape_is_one_statement_separator(self) -> None:
        instruction = decode_one(bytes([0x0D, 0x99, 0x00]))
        self.assertEqual(instruction["op"], "statement_separator")
        self.assertEqual(instruction["endOffset"], 1)

    def test_effect_dispatch_owns_its_whole_record_list(self) -> None:
        code = bytes([0x0D, 0x06, 0xFF, 0x02]) + LITERAL_7 + bytes([0x00])
        instruction = decode_one(code)
        self.assertEqual(instruction["op"], "effect_dispatch")
        self.assertEqual(instruction["endOffset"], len(code))
        self.assertEqual(instruction["operands"][0]["executionSelector"], 7)

    def test_a_structured_form_drops_the_generic_character_probe(self) -> None:
        instruction = decode_one(bytes([0x0D, 0x06, 0xFF, 0x00]))
        self.assertNotIn("nativeStreamProbe", instruction)
        self.assertEqual(
            instruction["nativeStreamConsumption"], "typed_presentation_subcommand_6_record_list"
        )

    def test_each_exact_ax_envelope_frames_seven_bytes(self) -> None:
        for envelope in decoder.AX_EXACT_ENVELOPES:
            with self.subTest(envelope=envelope.hex()):
                instruction = decode_one(envelope + bytes([0x99]))
                self.assertEqual(instruction["op"], "ax_presentation_control")
                self.assertEqual(instruction["endOffset"], 7)

    def test_the_selected_cell_control_reads_its_literal_records(self) -> None:
        code = bytes([0x0D, 0x03, 0xFF, 0x02, 0x01, 0xFF, 0x02, 0xF1, 0x03, 0x00, 0xFF, 0x00])
        instruction = decode_one(code)
        operand = instruction["operands"][0]
        self.assertEqual(operand["executionSelector"], 1)
        self.assertEqual(operand["cellRow"], 3)
        self.assertEqual(instruction["endOffset"], len(code))

    def test_a_selected_cell_control_outside_its_domain_fails_closed(self) -> None:
        code = bytes([0x0D, 0x03, 0xFF, 0x02, 0x01, 0xFF, 0x02, 0xF1, 0x63, 0x00, 0xFF, 0x00])
        with self.assertRaises(decoder.MesDecodeError):
            decode_one(code)

    def test_the_seven_byte_selector_2_shape_keeps_its_own_contract(self) -> None:
        instruction = decode_one(bytes([0x0D, 0x03, 0xFF, 0x02, 0x02, 0xFF, 0x00]))
        self.assertEqual(instruction["endOffset"], 7)
        self.assertNotIn("cellRow", instruction["operands"][0])

    def test_a_surface_dispatch_with_a_nonexpression_record_is_a_plain_system_call(self) -> None:
        code = bytes([0x0D, 0x0B, 0xFF, 0x01]) + b"X\x00" + bytes([0x00])
        instruction = decode_one(code)
        self.assertEqual(instruction["op"], "system_call")
        self.assertEqual(instruction["systemFunction"], 11)
        self.assertEqual(instruction["endOffset"], len(code))

    def test_a_shaped_surface_operation_is_promoted(self) -> None:
        # Mode 2 is shaped at five records, the mode record included.
        records = b"".join(bytes([0x02]) + LITERAL_7 for _ in range(4))
        code = bytes([0x0D, 0x0B, 0xFF, 0x02, 0xF1, 0x02, 0x00, 0xFF]) + records + bytes([0x00])
        instruction = decode_one(code)
        self.assertEqual(instruction["op"], "surface_operation")
        self.assertEqual(instruction["operands"][0]["mode"], 2)

    def test_an_unshaped_surface_dispatch_stays_unresolved_at_the_same_end(self) -> None:
        code = bytes([0x0D, 0x0B, 0xFF, 0x02, 0xF1, 0x02, 0x00, 0xFF, 0x00])
        instruction = decode_one(code)
        self.assertEqual(instruction["op"], "surface_dispatch_unresolved")
        self.assertEqual(instruction["endOffset"], len(code))

    def test_an_ax_binding_reads_its_bounded_column(self) -> None:
        code = decoder.AX_BINDING_PREFIX + bytes([2]) + decoder.AX_BINDING_SUFFIX
        instruction = decode_one(code)
        self.assertEqual(instruction["op"], "ax_presentation_binding")
        self.assertEqual(instruction["operands"][0]["cellColumn"], 2)

    def test_an_ax_binding_outside_its_column_range_is_not_claimed(self) -> None:
        code = decoder.AX_BINDING_PREFIX + bytes([3]) + decoder.AX_BINDING_SUFFIX
        self.assertNotEqual(decode_one(code)["op"], "ax_presentation_binding")

    def test_a_voice_marker_normalizes_its_name(self) -> None:
        code = decoder.VOICE_MARKER_HEADER + b"d1028.ogg\x00" + decoder.VOICE_MARKER_SUFFIX
        instruction = decode_one(code)
        self.assertEqual(instruction["op"], "voice_marker")
        self.assertEqual(instruction["operands"][0]["name"], "D1028.OGG")
        self.assertEqual(instruction["endOffset"], len(code))

    def test_a_marker_with_the_wrong_extension_is_a_plain_system_call(self) -> None:
        code = decoder.VOICE_MARKER_HEADER + b"d1028.wav\x00" + decoder.VOICE_MARKER_SUFFIX
        instruction = decode_one(code)
        self.assertEqual(instruction["op"], "system_call")
        self.assertEqual(instruction["systemFunction"], 7)
        self.assertEqual(instruction["endOffset"], len(code))

    def test_an_ax_marker_frames_its_envelope(self) -> None:
        code = decoder.AX_MARKER_HEADER + b"b05ss.ax\x00" + decoder.AX_MARKER_SUFFIX
        instruction = decode_one(code)
        self.assertEqual(instruction["op"], "ax_resource_marker")
        self.assertEqual(instruction["operands"][0]["name"], "B05SS.AX")

    def test_inline_script_execution_selects_by_extension(self) -> None:
        for selector, name, role in ((2, b"liblary.lib", "library_bootstrap"), (3, b"def_main.mes", "definition_bootstrap")):
            with self.subTest(selector=selector):
                code = bytes([0x0D, 0x08, 0xFF, 0x02, selector, 0xFF, 0x01]) + name + b"\x00\x00"
                instruction = decode_one(code)
                self.assertEqual(instruction["op"], "inline_script_execution")
                self.assertEqual(instruction["operands"][0]["executionRole"], role)
                self.assertEqual(instruction["endOffset"], len(code))

    def test_a_named_state_transfer_maps_its_letters(self) -> None:
        code = bytes([0x0D, 0x04, 0xFF, 0x02, 0x0D, 0xFF, 0x02]) + LITERAL_7 + b"\x01A_B\x00\x00"
        instruction = decode_one(code)
        self.assertEqual(instruction["op"], "named_state_transfer")
        mappings = instruction["operands"][0]["mappings"]
        self.assertEqual([mapping["name"] for mapping in mappings], ["A", "_B"])
        self.assertEqual(mappings[0]["slotOffset"], 0x2084)
        self.assertEqual(mappings[1]["slotOffset"], 0x20EC + 4)

    def test_an_unmappable_transfer_string_is_a_plain_system_call(self) -> None:
        code = bytes([0x0D, 0x04, 0xFF, 0x02, 0x0D, 0xFF, 0x02]) + LITERAL_7 + b"\x01a\x00\x00"
        instruction = decode_one(code)
        self.assertEqual(instruction["op"], "system_call")
        self.assertEqual(instruction["systemFunction"], 4)
        self.assertEqual(instruction["endOffset"], len(code))


class SystemCallTests(unittest.TestCase):
    """0x0D is one system call: a selector expression, then the typed record list."""

    def test_a_call_owns_its_selector_and_arguments(self) -> None:
        # System.function[24](4, 0, "bll.mmo", 0, 0) - EVENTJ11.MES:15362, once an opaque tail.
        code = bytes.fromhex("0d18ff0204ff0200ff01") + b"bll.mmo\x00" + bytes.fromhex("0200ff0200ff00")
        instruction = decode_one(code)
        self.assertEqual(instruction["op"], "system_call")
        self.assertEqual(instruction["systemFunction"], 24)
        self.assertEqual(instruction["endOffset"], len(code))
        self.assertEqual(instruction["operands"][0]["type"], "expression")
        self.assertEqual(
            [record["type"] for record in instruction["operands"][1]["records"]],
            ["expression_record", "expression_record", "string_record", "expression_record", "expression_record"],
        )
        self.assertNotIn("nativeStreamProbe", instruction)
        self.assertEqual(instruction["nativeStreamConsumption"], decoder.SYSTEM_CALL_CONSUMPTION)

    def test_the_message_wait_is_one_call(self) -> None:
        # System.function[19](2): formerly a separator, command 0x13 FF and a 02 02 FF 00 trailer.
        instruction = decode_one(bytes.fromhex("0d13ff0202ff00"))
        self.assertEqual(instruction["op"], "system_call")
        self.assertEqual(instruction["systemFunction"], 19)
        self.assertEqual(instruction["endOffset"], 7)

    def test_the_name_insert_and_the_mmo_marker_keep_their_names(self) -> None:
        insert = decode_one(bytes.fromhex("0d0eff02" + decoder.NAME_INSERT_EXPRESSION_HEX + "00"))
        self.assertEqual(insert["op"], "protagonist_name_insert")
        self.assertEqual(insert["systemFunction"], 14)
        self.assertEqual(len(insert["operands"][0]["records"]), 1)
        literal = decode_one(bytes.fromhex("0d0eff01") + b"ab\x00\x00")
        self.assertEqual(literal["op"], "literal_text_insert")
        marker = decode_one(bytes.fromhex("0d09ff01") + b"sample.mmo\x00\x00")
        self.assertEqual(marker["op"], "mmo_resource_marker")
        self.assertEqual(marker["commandId"], 0x0D)
        self.assertEqual(marker["operands"][0]["name"], "sample.mmo")
        self.assertEqual(marker["operands"][0]["outerCommandSourceOffset"], 0)
        self.assertNotIn("nativeStreamConsumption", marker)

    def test_an_empty_selector_selects_function_zero(self) -> None:
        # LIBLARY.LIB:139 and START.MES:419 - the only two such calls in the archive.
        instruction = decode_one(bytes.fromhex("0dff0200ff02f2d3ffff00ff00"))
        self.assertEqual(instruction["op"], "system_call")
        self.assertEqual(instruction["systemFunction"], 0)
        self.assertEqual(instruction["operands"][0]["type"], "empty_selector")
        self.assertEqual(instruction["endOffset"], 13)

    def test_bytes_the_grammar_cannot_frame_stay_a_separator(self) -> None:
        instruction = decode_one(bytes([0x0D, 0x99, 0x00]))
        self.assertEqual(instruction["op"], "statement_separator")


class BoundedStreamAlignmentTests(unittest.TestCase):
    """A separator whose consumed run hides 0x0B/0x0C swallows that run."""

    def test_a_run_hiding_a_shadow_control_byte_is_promoted(self) -> None:
        code = bytes([0x0D, 0x41, 0x0B, 0x42, 0x00])
        instruction = decode_one(code)
        self.assertEqual(instruction["endOffset"], 5)
        self.assertEqual(instruction["nativePayloadBoundary"], "bounded_byte_preserving_opaque_stream")
        self.assertEqual(instruction["nativeShadowControlOffsets"], [2])

    def test_a_run_without_a_shadow_control_byte_stays_one_byte(self) -> None:
        instruction = decode_one(bytes([0x0D, 0x41, 0x42, 0x00]))
        self.assertEqual(instruction["endOffset"], 1)
        self.assertNotIn("nativePayloadBoundary", instruction)

    def test_alignment_stops_at_the_region_limit(self) -> None:
        code = bytes([0x0D, 0x41, 0x0B, 0x42, 0x00])
        self.assertEqual(decoder.decode_instruction(code, 0, 3)["endOffset"], 3)

    def test_a_run_reaching_past_the_region_is_not_promoted(self) -> None:
        code = bytes([0x0D, 0x41, 0x0B, 0x42, 0x00])
        self.assertEqual(decoder.decode_instruction(code, 0, 2)["endOffset"], 1)


class MmoMarkerTests(unittest.TestCase):
    """0x09 straight after a 0x0D naming an MMO is the presentation-9 marker."""

    def test_a_marker_after_a_separator_is_framed(self) -> None:
        code = bytes([0x0D, 0x09, 0xFF, 0x01]) + b"D07.MMO\x00\x00"
        instruction = decoder.decode_instruction(code, 1, len(code))
        self.assertEqual(instruction["op"], "mmo_resource_marker")
        self.assertEqual(instruction["operands"][0]["name"], "D07.MMO")
        self.assertEqual(instruction["endOffset"], len(code))

    def test_the_marker_exists_only_after_a_0x0d(self) -> None:
        # The same bytes without the outer separator are not a marker at all;
        # they fall through to the write run, which fails closed on them.
        code = bytes([0x09, 0xFF, 0x01]) + b"D07.MMO\x00\x00"
        with self.assertRaises(decoder.MesDecodeError):
            decoder.decode_instruction(code, 0, len(code))

    def test_a_non_marker_shape_falls_through_to_the_write_run(self) -> None:
        code = bytes([0x0D, 0x09, 0x00, 0x00]) + LITERAL_7 + bytes([0x00])
        instruction = decoder.decode_instruction(code, 1, len(code))
        self.assertEqual(instruction["op"], "argument_slot_write_run")
        self.assertEqual(instruction["endOffset"], len(code))


if __name__ == "__main__":
    unittest.main()
