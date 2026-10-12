from __future__ import annotations

import copy
import sys
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

import mes_partial_decoder as decoder  # noqa: E402
from mes_instruction_ir import INSTRUCTION_SCHEMA, _canonical_value, decode_instruction_ir  # noqa: E402
from mes_presentation_ir import enrich_presentation  # noqa: E402


def _decode(code: bytes, offset: int = 0) -> tuple[dict, dict]:
    parsed = decoder.decode_instruction(code, offset, len(code))
    assert parsed is not None
    canonical = {"ok": True, "schema": INSTRUCTION_SCHEMA, **_canonical_value(parsed, code)}
    return canonical, decode_instruction_ir(code, offset, len(code))


def _records(*values: int) -> bytes:
    return b"".join(bytes((2, value, 0xFF)) for value in values) + b"\x00"


class PresentationEvidenceTests(unittest.TestCase):
    def test_named_effect_promotes_only_safe_wav_and_preserves_record_boundary(self):
        for source_name, expected in (
            (b"sample.wav", "effect_request"),
            (b"sample.ogg", "effect_dispatch"),
            (b"../sample.wav", "effect_dispatch"),
            (b"", "effect_dispatch"),
            (b"\x81\x40.wav", "effect_dispatch"),
        ):
            with self.subTest(name=source_name):
                code = b"\x0d\x06\xff\x02\x00\xff\x01" + source_name + b"\x00\x02\x03\xff\x00\x00"
                before, after = _decode(code)
                self.assertEqual(expected, after["op"])
                self.assertEqual(before["end_offset"], after["end_offset"])
                self.assertEqual(before["raw_hex"], after["raw_hex"])
                self.assertEqual("effect_dispatch", before["op"])
                operand = after["operands"][0]
                self.assertEqual(0x0043E800, operand["native_record_parser"])
                self.assertEqual(3, operand["native_record_count"])
                self.assertNotIn("native_stream_probe", after)
                if expected == "effect_request":
                    self.assertEqual("SAMPLE.WAV", operand["name"])
                    self.assertEqual("se.arc", operand["resource_archive"])
                    self.assertEqual(operand["records"][2]["value"], operand["channel_expression"])
                else:
                    self.assertNotIn("name", operand)

    def test_invalid_channel_remains_effect_dispatch(self):
        code = b"\x0d\x06\xff\x02\x00\xff\x01sample.wav\x00\x02\x03\xff\x00"
        before, _ = _decode(code)
        before["operands"][0]["records"][2]["value"]["valid"] = False
        after = enrich_presentation(before, code, len(code))
        self.assertEqual("effect_dispatch", after["op"])

    def test_empty_and_unknown_effect_lists_keep_opaque_effect_meaning(self):
        for code in (b"\x0d\x06\xff\x00", b"\x0d\x06\xff\x7f\x00"):
            _, after = _decode(code)
            self.assertEqual("effect_dispatch", after["op"])
            self.assertEqual("unresolved_not_executed", after["operands"][0]["native_effect_semantics"])

    def test_exact_ax_controls_keep_their_distinct_contracts(self):
        expected_fields = {
            2: ("native_consumer_handler", 0x00410C10),
            6: ("native_nested_cell_handler", 0x00410C10),
            7: ("native_nested_cell_handler", 0x00410C30),
            8: ("native_activation_handler", 0x00411140),
        }
        for selector, (field, value) in expected_fields.items():
            with self.subTest(selector=selector):
                _, after = _decode(b"\x0d\x03\xff" + _records(selector))
                operand = after["operands"][0]
                self.assertEqual(value, operand[field])
                self.assertNotIn("native_record_count", operand)
                self.assertEqual(f"typed_presentation_subcommand_3_selector_{selector}_literal_record", after["native_stream_consumption"])
                self.assertEqual((10, 32), (operand["cell_rows"], operand["cell_columns"]))

    def test_selected_cell_controls_preserve_defaulted_and_explicit_arguments(self):
        for selector, values in ((1, (1,)), (1, (1, 3, 4)), (2, (2, 3, 4, 0))):
            with self.subTest(values=values):
                _, after = _decode(b"\x0d\x03\xff" + _records(*values))
                operand = after["operands"][0]
                self.assertEqual(len(values), operand["native_record_count"])
                self.assertEqual(4 - len(values), operand["native_defaulted_arguments"])
                self.assertEqual(0x00410BF0 if selector == 1 else 0x00410C10, operand["native_consumer_handler"])
                self.assertEqual(f"typed_presentation_subcommand_3_selector_{selector}_literal_record_list", after["native_stream_consumption"])

    def test_composition_is_not_reported_as_ax_control(self):
        before, after = _decode(b"\x0d\x0a\xff" + _records(1))
        self.assertEqual("ax_presentation_control", before["op"])
        self.assertEqual("surface_composition_control", after["op"])
        operand = after["operands"][0]
        self.assertNotIn("execution_selector", operand)
        self.assertEqual(1, operand["literal_mode"])
        self.assertEqual([11, 0, 10], operand["native_surface_indices"])
        self.assertEqual("unresolved", operand["native_surface_content_and_lifetime"])

    def test_surface_copy_fill_and_refresh_decompose_existing_expressions(self):
        for values, op in (
            ((0, 1, 2, 3, 4, 5, 6, 7), "surface_operation"),
            ((0, 1, 2, 3, 4, 5, 6, 7, 8), "surface_operation"),
            ((1, 1, 2, 3, 4, 5, 6, 7, 8), "surface_operation"),
            ((2, 1, 2, 3, 4), "surface_operation"),
            ((13, 1, 2, 3, 4, 5), "surface_display_refresh"),
        ):
            with self.subTest(values=values):
                before, after = _decode(b"\x0d\x0b\xff" + _records(*values))
                self.assertEqual(op, after["op"])
                operand = after["operands"][0]
                self.assertNotIn("mode_source", operand)
                self.assertEqual(before["operands"][0]["expressions"][3], operand["inclusive_right"])
                if values[0] in (0, 1):
                    if len(values) == 8:
                        self.assertEqual(0, operand["destination_surface_default"])
                        self.assertNotIn("destination_surface_index", operand)
                    else:
                        self.assertEqual(operand["expressions"][8], operand["destination_surface_index"])
                elif values[0] == 2:
                    self.assertEqual(0x20BA, operand["native_active_surface_state_offset"])
                else:
                    self.assertEqual("return_without_refresh", operand["native_attached_target_null_effect"])
                    self.assertEqual(0x00CC0020, operand["native_raster_operation"])

    def test_unresolved_surface_mode_does_not_invent_a_pixel_operation(self):
        for values in ((), (0,), (13,)):
            _, after = _decode(b"\x0d\x0b\xff" + _records(*values))
            operand = after["operands"][0]
            self.assertEqual("surface_dispatch_unresolved", after["op"])
            self.assertNotIn("source_x", operand)
            self.assertEqual("unresolved_not_applied", operand["gameplay_state_effect"])
            expected = "out_of_range_mode_skips_switch_body_then_reaches_common_tail" if values == (13,) else "mode_or_default_argument_effect_unresolved"
            self.assertEqual(expected, operand["native_dispatch_semantics"])

    def test_binding_and_named_state_transfer_keep_unresolved_effects(self):
        _, binding = _decode(decoder.AX_BINDING_PREFIX + b"\x02" + decoder.AX_BINDING_SUFFIX)
        operand = binding["operands"][0]
        self.assertEqual(2, operand["cell_column"])
        self.assertEqual(320, operand["binding_table_entries"])
        self.assertEqual("unresolved", operand["native_rendering_semantics"])
        _, transfer = _decode(b"\x0d\x04\xff\x02\x0d\xff\x02\x00\xff\x01A_B\x00\x00")
        operand = transfer["operands"][0]
        self.assertEqual("relative_offsets_only", operand["native_copy_scope"])
        self.assertEqual([0x2084, 0x20F0], [item["slot_offset"] for item in operand["mappings"]])
        self.assertEqual("unresolved", operand["native_source_record_contents"])

    def test_resource_markers_preserve_exact_names_and_bounded_metadata(self):
        fixtures = (
            (decoder.VOICE_MARKER_HEADER + b"sample.ogg\x00" + decoder.VOICE_MARKER_SUFFIX, 0, "voice_marker", "SAMPLE.OGG"),
            (decoder.AX_MARKER_HEADER + b"sample.ax\x00" + decoder.AX_MARKER_SUFFIX, 0, "ax_resource_marker", "SAMPLE.AX"),
            (b"\x0d\x08\xff\x02\x02\xff\x01sample.lib\x00\x00", 0, "inline_script_execution", "SAMPLE.LIB"),
            (b"\x0d\x08\xff\x02\x03\xff\x01sample.mes\x00\x00", 0, "inline_script_execution", "SAMPLE.MES"),
            (b"\x0d\x09\xff\x01sample.mmo\x00\x00", 1, "mmo_resource_marker", "sample.mmo"),
        )
        for code, offset, op, name in fixtures:
            with self.subTest(op=op, name=name):
                before, after = _decode(code + b"\x00", offset)
                self.assertEqual(op, after["op"])
                operand = after["operands"][0]
                self.assertEqual(name, operand["name"])
                self.assertEqual(name.lower().encode("ascii"), operand["raw_bytes"])
                self.assertEqual(len(code), after["end_offset"])
                self.assertEqual(before["source_offset"], after["source_offset"])
                if op == "mmo_resource_marker":
                    self.assertEqual([-1, -1], operand["native_default_origin_arguments"])
                    self.assertNotIn("native_stream_consumption", after)
                elif op == "voice_marker":
                    self.assertEqual("not_observed_by_static_audit", operand["native_host_device_output"])

    def test_enrichment_does_not_mutate_input_and_rejects_foreign_name_bytes(self):
        code = decoder.AX_MARKER_HEADER + b"sample.ax\x00" + decoder.AX_MARKER_SUFFIX
        before, _ = _decode(code)
        frozen = copy.deepcopy(before)
        enrich_presentation(before, code, len(code))
        self.assertEqual(frozen, before)
        with self.assertRaisesRegex(ValueError, "disagrees"):
            enrich_presentation(before, code.replace(b"sample", b"tamper"), len(code))
        with self.assertRaisesRegex(ValueError, "outside"):
            enrich_presentation(before, code, len(code) - 1)

    def test_unpromoted_separator_and_other_commands_keep_their_native_probe(self):
        for code in (b"\x0d\x00", b"\x09\x00\x00\x00\xff\x00"):
            before, after = _decode(code)
            self.assertEqual(before, after)

    def test_mutating_returned_metadata_does_not_change_the_next_projection(self):
        code = b"\x0d\x0a\xff" + _records(1)
        _, first = _decode(code)
        first["operands"][0]["native_surface_indices"].append(99)
        _, second = _decode(code)
        self.assertEqual([11, 0, 10], second["operands"][0]["native_surface_indices"])


if __name__ == "__main__":
    unittest.main()
