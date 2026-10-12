"""Authored structural-mode and alignment parity against the GDScript oracle.

The fixture builders and oracle transport are shared with the strict IR suite.
No test reads an original archive or keeps original payloads in the repository.
"""

from __future__ import annotations

import hashlib
import sys
from pathlib import Path
import unittest
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
sys.path.insert(0, str(ROOT / "tests"))

import mes_analyzer_handoff as handoff  # noqa: E402
from test_mes_instruction_ir import (  # noqa: E402
    SHADOW_BRANCH, SHADOW_INTERNAL, fixture, instruction_fixtures,
    presentation_fixtures, region_fixtures, run_godot_oracle,
    synthetic_container, typed_ir_fixtures,
)


STRUCTURAL_RECOVERY = bytes.fromhex("190aff0201ff00191a00")
SAMPLE_RUN = b"\x11\x00" * 30
SPLIT_STRING = b"\x12\x01QA\x00\x00\x19\x1a\x00"


def structural_instruction_fixtures() -> list[dict[str, object]]:
    rows = instruction_fixtures()
    rows.extend([
        fixture("structural_effect_invalid_channel", b"\x0d\x06\xff\x02\x00\xff\x01qa.wav\x00\x02\xe0\xff\x00"),
        fixture("structural_effect_multiple_channel_results", b"\x0d\x06\xff\x02\x00\xff\x01qa.wav\x00\x02\x01\x02\xff\x00"),
    ])
    return [{**row, "mode": "structural_instruction"} for row in rows]


def structural_region_fixtures() -> list[dict[str, object]]:
    rows = region_fixtures()
    rows.extend([
        fixture("structural_recover_then_continue", STRUCTURAL_RECOVERY),
        fixture("structural_recovery_limit", STRUCTURAL_RECOVERY, max_instructions=2),
        fixture("structural_zero_step_limit", b"\x19", max_instructions=0),
        fixture("structural_unterminated_expression", b"\x19\x18\x01\x02"),
    ])
    return [{**row, "mode": "structural_region"} for row in rows]


def alignment_fixtures() -> list[dict[str, object]]:
    rows = [{**row, "mode": "record_alignment"} for row in typed_ir_fixtures()]
    examples = [
        ("samples_capped", SAMPLE_RUN, (20, 40)),
        ("samples_then_opaque", SAMPLE_RUN + b"\x0c\x01\x02", (20, 40)),
        ("split_string", SPLIT_STRING, (4, 6)),
        ("strict_structural_divergence", STRUCTURAL_RECOVERY, ()),
        ("strict_structural_entry_divergence", STRUCTURAL_RECOVERY, (7,)),
        ("shadow_in_second_region", b"\x19\x1a" + SHADOW_BRANCH + SHADOW_INTERNAL, (2, 2 + len(SHADOW_BRANCH))),
        ("compound_native_and_typed", b"\x12\x00\x11\x00\x15\x00\x1b\x00", (2, 4)),
        ("bounded_invalid_record_expression", b"\x12\x02\xff\x00\x19\x00", (2, 4)),
    ]
    for name, code, offsets in examples:
        rows.append(fixture("alignment_" + name, synthetic_container(code, offsets), mode="record_alignment"))
    # A mixed sequence verifies family attribution in decode order, including
    # both presentation metadata and the MMO marker's outer-command context.
    mixed = b"".join(bytes.fromhex(row["hex"]) for row in presentation_fixtures())
    rows.append(fixture("alignment_mixed_presentation", synthetic_container(mixed), mode="record_alignment"))
    return rows


def _alignment(code: bytes, offsets: tuple[int, ...] = ()) -> dict:
    from mes_record_alignment import build_record_alignment

    return build_record_alignment(handoff.build_container(synthetic_container(code, offsets)))


class RecordAlignmentBoundaryTests(unittest.TestCase):
    def test_inexact_decoder_records_cannot_certify_coverage(self) -> None:
        record = {"source_offset": 0, "end_offset": 1, "byte_length": 1, "raw_hex": "19"}
        for changed in ({"source_offset": 1}, {"end_offset": 0}, {"byte_length": 2}, {"raw_hex": "00"}):
            with self.subTest(changed=changed), patch("mes_record_alignment.decode_region_ir", return_value={
                "ok": True, "decoded_end_offset": 1, "instructions": [{**record, **changed}],
            }):
                result = _alignment(b"\x19")
                self.assertFalse(result["ok"])
                self.assertGreater(result["failure_count"], 0)
                self.assertEqual(0, result["framed_bytes"])

    def test_an_opaque_tail_cannot_hide_a_gap_after_the_last_record(self) -> None:
        with patch("mes_record_alignment.decode_region_ir", return_value={
            "ok": False, "decoded_end_offset": 2, "instructions": [
                {"source_offset": 0, "end_offset": 1, "byte_length": 1, "raw_hex": "19"},
            ], "error": "synthetic stop",
        }):
            result = _alignment(b"\x19\x1a\x00")
        self.assertFalse(result["ok"])
        self.assertEqual(0, result["opaque_boundary_count"])
        self.assertEqual(1, result["framed_bytes"])

    def test_selected_cell_literal_gate_applies_after_both_expression_modes(self) -> None:
        from mes_instruction_ir import decode_instruction_ir

        code = bytes.fromhex("0d03ff0201ff02ff00")
        for structural in (False, True):
            with self.subTest(structural=structural):
                result = decode_instruction_ir(code, 0, len(code), structural=structural)
                self.assertFalse(result["ok"])
                self.assertEqual("AX selected-cell control has an unqualified nonliteral argument.", result["error"])

    def test_structural_diagnostics_are_typed_while_strict_analysis_stops(self) -> None:
        strict = handoff.build_typed_ir(handoff.build_container(synthetic_container(STRUCTURAL_RECOVERY)))
        structural = _alignment(STRUCTURAL_RECOVERY)
        self.assertFalse(strict["complete"])
        self.assertEqual(1, len(strict["opaque_boundaries"]))
        self.assertTrue(structural["ok"])
        self.assertEqual(0, structural["opaque_boundary_count"])
        self.assertGreater(structural["instruction_count"], len(strict["instructions"]))
        self.assertEqual(len(STRUCTURAL_RECOVERY), structural["framed_bytes"])

    def test_samples_cap_is_global_and_does_not_cap_family_counts(self) -> None:
        result = _alignment(SAMPLE_RUN, (20, 40))
        self.assertEqual(3, result["region_count"])
        self.assertEqual(30, result["compound_record_count"])
        self.assertEqual({"typed_record_list_command_11": 30}, result["compound_families"])
        self.assertEqual({"typed_record_list_command_11": 60}, result["compound_family_bytes"])
        self.assertEqual(24, len(result["samples"]))
        self.assertEqual(list(range(0, 48, 2)), [row["source_offset"] for row in result["samples"]])
        self.assertEqual(["bootstrap"] * 10 + ["entry_0000"] * 10 + ["entry_0001"] * 4,
                         [row["region"] for row in result["samples"]])

    def test_opaque_tail_preserves_exact_bytes_hash_and_coverage(self) -> None:
        code = SAMPLE_RUN + b"\x0c\x01\x02"
        result = _alignment(code, (20, 40))
        self.assertTrue(result["ok"])
        self.assertEqual((1, 3), (result["opaque_boundary_count"], result["opaque_bytes"]))
        tail = result["opaque_boundaries"][0]
        self.assertEqual((60, 63, "entry_0001"), (tail["source_offset"], tail["end_offset"], tail["region"]))
        self.assertEqual(code[60:].hex(), tail["raw_hex"])
        self.assertEqual(hashlib.sha256(code[60:]).hexdigest(), tail["raw_sha256"])
        self.assertEqual(len(code), result["instruction_bytes"] + result["opaque_bytes"])
        self.assertEqual(len(code), result["framed_bytes"])

    def test_each_address_region_is_an_independent_limit(self) -> None:
        result = _alignment(SPLIT_STRING, (4, 6))
        self.assertTrue(result["ok"])
        self.assertEqual(3, result["region_count"])
        self.assertEqual(1, result["opaque_boundary_count"])
        tail = result["opaque_boundaries"][0]
        self.assertEqual((0, 4, "bootstrap"), (tail["source_offset"], tail["end_offset"], tail["region"]))
        self.assertEqual(SPLIT_STRING[:4].hex(), tail["raw_hex"])
        self.assertEqual(len(SPLIT_STRING), result["framed_bytes"])

    def test_shadow_control_payload_is_counted_as_one_compound_record(self) -> None:
        result = _alignment(SHADOW_BRANCH)
        self.assertTrue(result["ok"])
        self.assertEqual({"opaque_native_stream_branch_guard": 1}, result["compound_families"])
        self.assertEqual(9, result["compound_record_bytes"])
        self.assertEqual(2, result["instruction_count"])
        self.assertEqual(0, result["opaque_boundary_count"])

    def test_empty_container_has_zero_regions_and_no_phantom_record(self) -> None:
        result = _alignment(b"")
        self.assertTrue(result["ok"])
        for field in ("region_count", "instruction_count", "compound_record_count", "opaque_boundary_count", "code_bytes", "framed_bytes"):
            self.assertEqual(0, result[field], field)
        self.assertEqual([], result["samples"])


class StructuralAlignmentGodotOracleTests(unittest.TestCase):
    maxDiff = 4000

    @classmethod
    def setUpClass(cls) -> None:
        cls.fixtures = structural_instruction_fixtures() + structural_region_fixtures() + alignment_fixtures()
        cls.expected = run_godot_oracle(cls.fixtures)

    def test_all_authored_instructions_match_structural_gdscript(self) -> None:
        from mes_instruction_ir import decode_instruction_ir

        for row in self.fixtures:
            if row["mode"] != "structural_instruction":
                continue
            with self.subTest(fixture=row["name"]):
                code = bytes.fromhex(row["hex"])
                actual = decode_instruction_ir(code, row.get("start", 0), row.get("end", len(code)), structural=True)
                self.assertEqual(self.expected[row["name"]], handoff.normalize(actual))

    def test_all_authored_regions_match_structural_gdscript(self) -> None:
        from mes_instruction_ir import decode_region_ir

        for row in self.fixtures:
            if row["mode"] != "structural_region":
                continue
            with self.subTest(fixture=row["name"]):
                code = bytes.fromhex(row["hex"])
                actual = decode_region_ir(code, row.get("start", 0), row.get("end", len(code)),
                                          row.get("max_instructions", 100000), structural=True)
                self.assertEqual(self.expected[row["name"]], handoff.normalize(actual))

    def test_alignment_counts_families_samples_and_opaque_boundaries_match_gdscript(self) -> None:
        from mes_record_alignment import build_record_alignment

        for row in self.fixtures:
            if row["mode"] != "record_alignment":
                continue
            with self.subTest(fixture=row["name"]):
                actual = build_record_alignment(handoff.build_container(bytes.fromhex(row["hex"])))
                self.assertEqual(self.expected[row["name"]], handoff.normalize(actual))


if __name__ == "__main__":
    unittest.main()
