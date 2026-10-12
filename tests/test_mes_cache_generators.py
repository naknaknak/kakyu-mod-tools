from __future__ import annotations

import os
from pathlib import Path
import sys
import tempfile
import time
import unittest


TOOLS = Path(__file__).resolve().parents[1] / "tools"
sys.path.insert(0, str(TOOLS))

import export_mes_instruction_oracle as oracle  # noqa: E402
import export_mes_text_cache as text_cache  # noqa: E402
import mes_basic_block_ir_v6  # noqa: E402


class MesCacheGeneratorTests(unittest.TestCase):
    def test_exact_protagonist_name_insert_is_distinguished(self) -> None:
        code = bytes.fromhex("0eff0200f90000a000e0f1400be0ff00")
        instruction = mes_basic_block_ir_v6.decode_instruction(code, 0, len(code))
        self.assertEqual("protagonist_name_insert", instruction["op"])
        self.assertEqual(len(code), instruction["endOffset"])

        unresolved = bytes([0x0E, 0x01]) + b"ROOM.MES\0\0"
        other = mes_basic_block_ir_v6.decode_instruction(unresolved, 0, len(unresolved))
        self.assertEqual("command_0e", other["op"])

    def test_statement_separator_is_operand_free(self) -> None:
        instruction = mes_basic_block_ir_v6.decode_instruction(bytes([0x0D]), 0, 1)
        self.assertEqual("statement_separator", instruction["op"])
        self.assertEqual([], instruction["operands"])
        self.assertEqual(1, instruction["endOffset"])
        self.assertEqual("character_stream_presentation", instruction["nativeHandlerFamily"])

    def test_operand_free_native_presentation_family_is_retained(self) -> None:
        instruction = mes_basic_block_ir_v6.decode_instruction(bytes([0x02]), 0, 1)
        self.assertEqual(1, instruction["endOffset"])
        self.assertEqual("character_stream_presentation", instruction["nativeHandlerFamily"])
        self.assertEqual(
            "single_byte_run_until_nul_or_primary_double_byte_lead",
            instruction["nativeStreamConsumption"],
        )

    def test_native_single_byte_stream_probe_matches_handler_stops(self) -> None:
        nul = mes_basic_block_ir_v6.decode_instruction(bytes([0x02, 0x41, 0x42, 0, 0x82]), 0, 5)
        self.assertEqual("nul_consumed", nul["nativeStreamProbe"]["stopReason"])
        self.assertEqual(3, nul["nativeStreamProbe"]["consumedByteCount"])

        lead = mes_basic_block_ir_v6.decode_instruction(bytes([0x02, 0x41, 0x82, 0xA0]), 0, 4)
        self.assertEqual("double_byte_lead_deferred", lead["nativeStreamProbe"]["stopReason"])
        self.assertEqual(1, lead["nativeStreamProbe"]["consumedByteCount"])

        extended = mes_basic_block_ir_v6.decode_instruction(bytes([0x02, 0xFA, 0]), 0, 3)
        self.assertEqual(2, extended["nativeStreamProbe"]["consumedByteCount"])

    def test_native_double_byte_stream_defers_ff_without_false_text(self) -> None:
        empty = mes_basic_block_ir_v6.decode_instruction(bytes([0x01, 0xFF, 0x02, 0]), 0, 4)
        self.assertEqual("command_01", empty["op"])
        self.assertEqual(1, empty["endOffset"])
        self.assertEqual([], empty["operands"])
        self.assertEqual("single_byte_marker_deferred", empty["nativeStreamProbe"]["stopReason"])

        lead = mes_basic_block_ir_v6.decode_instruction(bytes([0x82, 0xA0, 0xFF, 0]), 0, 4)
        self.assertEqual("dispatcher_character_text", lead["op"])
        self.assertEqual(2, lead["endOffset"])
        self.assertEqual("82a0", lead["operands"][0]["rawHex"])
        self.assertTrue(lead["nativeStreamProjectionMatch"])

    def test_text_cache_keeps_the_last_pair_before_deferred_ff(self) -> None:
        code = bytes([0x82, 0xA0, 0xFF, 0])
        instruction = mes_basic_block_ir_v6.decode_instruction(code, 0, len(code))
        document = {"nodes": [{"instructions": [instruction]}]}
        data = (0).to_bytes(4, "little") + code
        messages = text_cache.text_messages(data, document)
        self.assertEqual(1, len(messages))
        self.assertEqual("あ", messages[0]["text"])

    def test_source_line_marker_retains_fixed_u32_operand(self) -> None:
        code = bytes([0x1F, 0x15, 0, 0, 0])
        instruction = mes_basic_block_ir_v6.decode_instruction(code, 0, len(code))
        self.assertEqual("source_line_marker", instruction["op"])
        self.assertEqual("source_line", instruction["operands"][0]["type"])
        self.assertEqual(21, instruction["operands"][0]["value"])
        self.assertEqual(len(code), instruction["endOffset"])

    def test_library_registration_retains_literal_and_skip_target(self) -> None:
        code = bytes([0x1C, 0x28, 0xFF, 9, 0, 0, 0])
        instruction = mes_basic_block_ir_v6.decode_instruction(code, 0, len(code))
        self.assertEqual("library_register_skip", instruction["op"])
        self.assertEqual(40, instruction["operands"][0]["value"]["ast"]["value"])
        self.assertEqual(9, instruction["operands"][1]["value"])

    def test_definition_invoke_consumes_common_record_list(self) -> None:
        code = bytes([0x11, 0x02, 0x0B, 0xFF, 0x00, 0x1F])
        instruction = mes_basic_block_ir_v6.decode_instruction(code, 0, len(code))
        self.assertEqual("definition_invoke", instruction["op"])
        self.assertEqual(11, instruction["operands"][0]["records"][0]["value"]["ast"]["value"])
        self.assertEqual(5, instruction["endOffset"])

    def test_command_0a_retains_dynamic_dword_write_run(self) -> None:
        code = bytes([0x0A, 2, 0xFF, 3, 0xFF, 1, 4, 0xFF, 0])
        instruction = mes_basic_block_ir_v6.decode_instruction(code, 0, len(code))
        self.assertEqual("global_i32_write_run", instruction["op"])
        self.assertEqual(len(code), instruction["endOffset"])
        self.assertEqual(2, instruction["operands"][0]["value"]["ast"]["value"])
        self.assertEqual([1, 0], [pair["continuation"] for pair in instruction["operands"][1]["pairs"]])

    def test_v5_command03_retains_complete_write_run(self) -> None:
        code = bytes([0x03, 0x34, 0x12, 20, 0xFF, 2, 4, 0xFF, 0])
        instruction = mes_basic_block_ir_v6.decode_instruction(code, 0, len(code))
        self.assertEqual("global_u8_write_run", instruction["op"])
        self.assertEqual(0x1234, instruction["operands"][0]["value"])
        self.assertEqual(2, len(instruction["operands"][1]["pairs"]))
        self.assertEqual(len(code), instruction["endOffset"])

    def test_v6_banked_writes_separate_destination_bank_and_storage_width(self) -> None:
        u8_code = bytes([0x06, 2, 0xFF, 1, 3, 0xFF, 1, 4, 0xFF, 0])
        u8_instruction = mes_basic_block_ir_v6.decode_instruction(u8_code, 0, len(u8_code))
        self.assertEqual("banked_u8_write_run", u8_instruction["op"])
        self.assertEqual(1, u8_instruction["operands"][1]["value"])
        self.assertEqual(2, len(u8_instruction["operands"][2]["pairs"]))
        self.assertEqual(len(u8_code), u8_instruction["endOffset"])

        code = bytes([0x07, 0xF1, 0xD4, 0, 0xFF, 2, 3, 0xFF, 1, 4, 0xFF, 0])
        instruction = mes_basic_block_ir_v6.decode_instruction(code, 0, len(code))
        self.assertEqual("banked_u16_write_run", instruction["op"])
        self.assertEqual(212, instruction["operands"][0]["value"]["ast"]["value"])
        self.assertEqual(2, instruction["operands"][1]["value"])
        self.assertEqual(2, len(instruction["operands"][2]["pairs"]))
        self.assertEqual(len(code), instruction["endOffset"])

        i32_code = bytes([0x08, 2, 0xFF, 1, 3, 0xFF, 0])
        i32_instruction = mes_basic_block_ir_v6.decode_instruction(i32_code, 0, len(i32_code))
        self.assertEqual("banked_i32_write_run", i32_instruction["op"])
        self.assertEqual(0x08, i32_instruction["commandId"])
        self.assertEqual(len(i32_code), i32_instruction["endOffset"])

    def test_oracle_rejects_invalid_expression_candidates(self) -> None:
        self.assertTrue(oracle.expression_is_valid({"valid": True, "ast": {"value": 1}}))
        self.assertFalse(oracle.expression_is_valid({"operand": {"valid": False}}))

    def test_cache_lock_rejects_live_writer_and_recovers_stale_lock(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary) / "cache"
            with text_cache.cache_write_lock(root, 60):
                with self.assertRaises(RuntimeError):
                    with text_cache.cache_write_lock(root, 60):
                        pass
            lock = root / ".write.lock"
            lock.write_text("stale", encoding="utf-8")
            old = time.time() - 120
            os.utime(lock, (old, old))
            with text_cache.cache_write_lock(root, 60):
                self.assertTrue(lock.exists())
            self.assertFalse(lock.exists())

    def test_atomic_json_writer_recovers_existing_temporary(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary) / "manifest.json"
            output.with_name("manifest.json.tmp").write_text("incomplete", encoding="utf-8")
            text_cache.write_json_atomic(output, {"schema": "test/v1"})
            self.assertIn('"schema": "test/v1"', output.read_text(encoding="utf-8"))
            self.assertFalse(output.with_name("manifest.json.tmp").exists())


if __name__ == "__main__":
    unittest.main()
