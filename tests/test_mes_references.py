"""Exact ordered reference lists from authored MES containers and the GD oracle."""

from __future__ import annotations

import hashlib
from pathlib import Path
import struct
import sys
import unittest


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
sys.path.insert(0, str(ROOT / "tests"))

import mes_analyzer_handoff as handoff  # noqa: E402
from test_mes_instruction_ir import (  # noqa: E402
    SHADOW_BRANCH, SHADOW_INTERNAL, fixture, instruction_fixtures,
    run_godot_oracle, synthetic_container, typed_ir_fixtures,
)
from test_mes_presentation_ir import decoder  # noqa: E402


AX_MARKER = decoder.AX_MARKER_HEADER + b"sample.ax\x00" + decoder.AX_MARKER_SUFFIX
VOICE_MARKER = decoder.VOICE_MARKER_HEADER + b"sample.ogg\x00" + decoder.VOICE_MARKER_SUFFIX
MMO_MARKER = b"\x0d\x09\xff\x01sample.mmo\x00\x00"
INLINE_MARKER = b"\x0d\x08\xff\x02\x02\xff\x01sample.lib\x00\x00"
BRANCH_REGIONS = b"\x0b\x01\xff" + struct.pack("<I", 8) + b"\x19\x0c\x02\x00\x00\x00\x00"
GLOBAL_WRITE_READS = bytes.fromhex("0312008003ff018004ff00")
BANKED_WRITE_READS = bytes.fromhex("078005ff028006ff00")
NESTED_STATE = bytes.fromhex("188003f5ff")
BINARY_STATE = bytes.fromhex("1880038004e0ff")
EFFECT_STATE = b"\x0d\x06\xff\x02\x00\xff\x01sample.wav\x00\x02\x80\x03\xff\x00"


def _surface_reads(mode: int, count: int) -> bytes:
    # Every expression position has a distinct state read, so duplicated alias
    # traversal order is observable even when instruction dictionaries compare equal.
    return b"\x0d\x0b\xff\x02" + bytes([mode, 0xFF]) + b"".join(
        bytes([2, 0x80, index, 0xFF]) for index in range(1, count)
    ) + b"\x00"


def focused_reference_fixtures() -> list[dict[str, object]]:
    examples = [
        ("cp932_messages", bytes.fromhex("018140824100"), ()),
        ("dispatcher_messages", b"QA\x00", ()),
        ("empty_ff_text", bytes.fromhex("01ff0200"), ()),
        ("shadow_branch", SHADOW_BRANCH, ()),
        ("shadow_internal", SHADOW_INTERNAL, ()),
        ("global_write_reads", GLOBAL_WRITE_READS, ()),
        ("banked_write_reads", BANKED_WRITE_READS, ()),
        # MA-11: the other state-storage write runs carry write rows too.
        ("state_u16_write_reads", bytes.fromhex("0405f11200ff01800503e0ff00"), ()),
        ("dynamic_u8_write", bytes.fromhex("0502ff21ff0122ff00"), ()),
        ("banked_u8_write", bytes.fromhex("0602ff0321ff0122ff00"), ()),
        ("global_i32_write", bytes.fromhex("0a02ff21ff0122ff00"), ()),
        ("nested_state", NESTED_STATE, ()),
        ("binary_state", BINARY_STATE, ()),
        ("duplicate_channel_state", EFFECT_STATE, ()),
        ("surface_alias_state", _surface_reads(0, 9), ()),
        ("surface_refresh_alias_state", _surface_reads(13, 6), ()),
        ("branch_regions", BRANCH_REGIONS, (7, 8)),
        ("branch_outside", b"\x0b\x01\xff\xff\xff\xff\xff", ()),
        ("registered_target", b"\x1c\x05\xff\x00\x00\x00\x00\x19", ()),
        ("bootstrap_target", b"\x14\x01\xff\x00\x00\x00\x00\x19", ()),
        ("labels_not_targets", b"\x17\x00\x00\x00\x00\x1f\x00\x00\x00\x00", ()),
        ("resources_indexed", AX_MARKER + VOICE_MARKER + MMO_MARKER + INLINE_MARKER, ()),
        ("resources_after_opaque", b"\x18\xff" + AX_MARKER + VOICE_MARKER, ()),
        ("resource_inside_text", b"\x01" + AX_MARKER + b"\x00", ()),
        ("resource_after_text_address", b"\x01" + AX_MARKER + b"\x00", (1,)),
        ("resource_cross_address", AX_MARKER, (3,)),
        ("resource_cross_address_name", VOICE_MARKER, (10,)),
        ("resource_invalid_then_valid", b"\x0d\x08\xff\x02\x00\xff\x01../bad.ax\x00" + decoder.AX_MARKER_SUFFIX + AX_MARKER, ()),
        ("resource_incomplete_then_valid", b"\x0d\x08\xff\x02\x00\xff\x01" + AX_MARKER, ()),
        ("resource_long_name", decoder.AX_MARKER_HEADER + b"a" * 256 + b".ax\x00" + decoder.AX_MARKER_SUFFIX + VOICE_MARKER, ()),
        ("resource_lower_mmo", MMO_MARKER, ()),
        ("resource_non_ascii_mmo", b"\x0d\x09\xff\x01\x81\x40.mmo\x00\x00", ()),
        ("resource_non_ascii_mmo_after_opaque", b"\x18\xff\x0d\x09\xff\x01\x81\x40.mmo\x00\x00", ()),
        ("pseudo_marker_08", b"\x08\xff\x02\x00\xff\x01sample.ax\x00" + decoder.AX_MARKER_SUFFIX, ()),
        ("effect_and_script_are_not_resource_refs", EFFECT_STATE + b"\x0e\x01QA.MES\x00\x00\x0f\x01QA.MES\x00\x00", ()),
        ("truncated_condition_before_entry", b"\x0b\x01\xff\x00\x00\x00\x00\x19", (3, 7)),
    ]
    return [fixture("references_" + name, synthetic_container(code, offsets), mode="references")
            for name, code, offsets in examples]


def reference_fixtures() -> list[dict[str, object]]:
    rows = [{**row, "mode": "references"} for row in typed_ir_fixtures()]
    for row in instruction_fixtures():
        code = bytes.fromhex(row["hex"])
        # Preserve both sides of authored caller limits as independent address
        # regions. The resource inventory intentionally scans the whole code.
        offsets = tuple(sorted({value for value in (row.get("start", 0), row.get("end", len(code)))
                                if isinstance(value, int) and 0 < value < len(code)}))
        rows.append(fixture("references_instruction_" + row["name"], synthetic_container(code, offsets), mode="references"))
    rows.extend(focused_reference_fixtures())
    return rows


def marker_fixtures() -> list[dict[str, object]]:
    # The shared factory already covers every presentation envelope prefix as
    # a physical truncation, explicit limit and shifted nonzero coordinate.
    rows = [{**row, "name": "marker_" + row["name"], "mode": "resource_marker"}
            for row in instruction_fixtures()]
    for label, header, suffix, extension, start in (
        ("ax", decoder.AX_MARKER_HEADER, decoder.AX_MARKER_SUFFIX, b".ax", 0),
        ("voice", decoder.VOICE_MARKER_HEADER, decoder.VOICE_MARKER_SUFFIX, b".ogg", 0),
        ("inline", b"\x0d\x08\xff\x02\x02\xff\x01", b"\x00", b".lib", 0),
        ("mmo", b"\x0d\x09\xff\x01", b"\x00", b".mmo", 1),
    ):
        for name_label, name in (
            ("255", b"a" * (255 - len(extension)) + extension),
            ("256", b"a" * (256 - len(extension)) + extension),
            ("unsafe", b"../sample" + extension),
            ("non_ascii", b"\x81\x40" + extension),
            ("wrong_extension", b"sample.txt"),
        ):
            rows.append(fixture(f"marker_{label}_name_{name_label}", header + name + b"\x00" + suffix,
                                start=start, mode="resource_marker"))
        rows.append(fixture(f"marker_{label}_wrong_suffix", header + b"sample" + extension + b"\x00\x7f",
                            start=start, mode="resource_marker"))
    return rows


def marker_name_byte_fixtures() -> list[dict[str, object]]:
    # Exercise the MMO-specific name conversion/safety contract through both
    # marker-only scanning and the shared strict/structural instruction paths.
    # Zero is excluded because it is the filename terminator.
    rows = []
    for value in range(1, 256):
        code = b"\x0d\x09\xff\x01" + bytes([value]) + b"q.mmo\x00\x00"
        for mode in ("resource_marker", "instruction", "structural_instruction", "region", "structural_region"):
            start = 0 if mode in ("region", "structural_region") else 1
            rows.append(fixture(f"mmo_name_byte_{value:02x}_{mode}", code, start=start, mode=mode))
    return rows


def _references(code: bytes, offsets: tuple[int, ...] = ()) -> dict:
    from mes_references import build_references

    container = handoff.build_container(synthetic_container(code, offsets))
    return build_references(container, handoff.build_typed_ir(container))


class ReferenceBoundaryTests(unittest.TestCase):
    def test_messages_preserve_cp932_bytes_without_decoding_or_inventing_text(self) -> None:
        raw = bytes.fromhex("81408241")
        result = _references(b"\x01" + raw + b"\x00")
        self.assertEqual(1, len(result["messages"]))
        message = result["messages"][0]
        self.assertEqual(raw, message["raw_bytes"])
        self.assertEqual(raw.hex(), message["raw_hex"])
        self.assertEqual(hashlib.sha256(raw).hexdigest(), message["raw_sha256"])
        self.assertEqual((0, 6, "bootstrap"), (message["source_offset"], message["end_offset"], message["region"]))
        self.assertNotIn("text", message)

    def test_shadow_payload_does_not_create_messages_or_branch_references(self) -> None:
        for code, message_offset in ((SHADOW_BRANCH, 9), (SHADOW_INTERNAL, 8)):
            with self.subTest(offset=message_offset):
                result = _references(code)
                self.assertEqual([message_offset], [row["source_offset"] for row in result["messages"]])
                self.assertEqual([], result["code"])

    def test_write_rows_precede_reads_and_every_state_write_run_has_one(self) -> None:
        result = _references(GLOBAL_WRITE_READS + BANKED_WRITE_READS)
        rows = result["state"]
        self.assertEqual(["write", "read", "read", "write", "read", "read"], [row["access"] for row in rows])
        self.assertEqual(["18", "3", "4", "expression", "5", "6"], [row["index"] for row in rows])
        self.assertEqual(2, rows[0]["count"])
        self.assertEqual(("banked_u16", 2, 1), (rows[3]["storage"], rows[3]["bank"], rows[3]["count"]))
        factory_rows = instruction_fixtures()
        by_name = {row["name"]: row for row in factory_rows}
        # MA-11: every write run whose destination is a state storage carries a
        # write row first - the u8/u16 index as a decimal string, an expression
        # destination summarised like a banked one - followed by its reads.
        expected = {
            "state_u16_run": [("write", "state_u16", 0, "5", 2), ("read", "state_u16", 0, "5", 1)],
            "dynamic_u8_run": [("write", "global_u8", 0, "2", 2)],
            "banked_u8_run": [("write", "banked_u8", 3, "2", 2)],
            "global_i32_run": [("write", "global_i32", 0, "2", 2)],
        }
        for name, rows in expected.items():
            with self.subTest(command=name):
                references = _references(bytes.fromhex(by_name[name]["hex"]))
                self.assertEqual(rows, [(row["access"], row["storage"], row["bank"], row["index"], row["count"])
                                        for row in references["state"]])
        # Argument slots are not state storage: no write row, as before.
        for name in ("slot_u16_run", "slot_u8_run"):
            with self.subTest(command=name):
                references = _references(bytes.fromhex(by_name[name]["hex"]))
                self.assertFalse(any(row["access"] == "write" for row in references["state"]))

    def test_state_reads_keep_depth_first_order_and_expression_duplicates(self) -> None:
        nested = _references(NESTED_STATE)["state"]
        self.assertEqual([("global_u8", "expression"), ("state_u16", "3")], [(row["storage"], row["index"]) for row in nested])
        self.assertEqual(["3", "4"], [row["index"] for row in _references(BINARY_STATE)["state"]])
        self.assertEqual(["3", "3"], [row["index"] for row in _references(EFFECT_STATE)["state"]])
        self.assertEqual([str(index) for index in range(1, 9)] * 2,
                         [row["index"] for row in _references(_surface_reads(0, 9))["state"]])
        self.assertEqual(["1", "2", "3", "4", "5", "1", "2", "3", "4"],
                         [row["index"] for row in _references(_surface_reads(13, 6))["state"]])

    def test_code_references_distinguish_target_fallthrough_region_and_alignment(self) -> None:
        rows = _references(BRANCH_REGIONS, (7, 8))["code"]
        self.assertEqual(["condition_false_target", "condition_true_fallthrough", "continuation_target"], [row["kind"] for row in rows])
        self.assertEqual([8, 7, 2], [row["target_offset"] for row in rows])
        self.assertEqual(["entry_0001", "entry_0000", "bootstrap"], [row["target_region"] for row in rows])
        self.assertEqual([True, True, False], [row["aligned"] for row in rows])
        outside = _references(b"\x0b\x01\xff\xff\xff\xff\xff")["code"]
        self.assertEqual([0xFFFFFFFF, 7], [row["target_offset"] for row in outside])
        self.assertTrue(all(not row["in_code"] and row["target_region"] == "outside" for row in outside))

    def test_resources_have_ordered_archive_candidates_and_native_evidence(self) -> None:
        rows = _references(AX_MARKER + VOICE_MARKER + MMO_MARKER + INLINE_MARKER)["resources"]
        self.assertEqual(["ax", "voice", "mmo", "mes_script"], [row["resource_kind"] for row in rows])
        self.assertEqual(["voice.arc", "tina1.arc", "tina2.arc"], rows[1]["archive_candidates"])
        self.assertEqual("not_observed_by_static_audit", rows[1]["native_host_device_output"])
        self.assertEqual("sample.mmo", rows[2]["name"])
        self.assertEqual("SAMPLE.AX", rows[0]["name"])
        self.assertEqual("confirmed", rows[3]["native_context_restore"])
        # The MMO authority retains byte values in this name representation;
        # unlike AX/voice, this recognizer has no printable-ASCII name gate.
        non_ascii = _references(b"\x0d\x09\xff\x01\x81\x40.mmo\x00\x00")["resources"]
        self.assertEqual("\u0081@.mmo", non_ascii[0]["name"])

    def test_resource_scan_preserves_opaque_and_cross_region_evidence_without_messages(self) -> None:
        opaque = _references(b"\x18\xff" + AX_MARKER)
        self.assertEqual([], opaque["messages"])
        self.assertEqual([(2, "bounded_envelope_scan")], [(row["source_offset"], row["boundary"]) for row in opaque["resources"]])
        text = _references(b"\x01" + AX_MARKER + b"\x00")
        self.assertEqual("bounded_envelope_scan", text["resources"][0]["boundary"])
        crossing = _references(AX_MARKER, (3,))
        self.assertEqual((0, "bootstrap", "strict_indexed"), (crossing["resources"][0]["source_offset"], crossing["resources"][0]["region"], crossing["resources"][0]["boundary"]))
        # Indexed describes membership of the start coordinate, not validation
        # of this entire envelope by the strict region decoder.
        container = handoff.build_container(synthetic_container(AX_MARKER, (3,)))
        self.assertFalse(handoff.build_typed_ir(container)["complete"])

    def test_effects_and_script_dispatches_are_not_added_to_the_resource_inventory(self) -> None:
        code = EFFECT_STATE + b"\x0e\x01QA.MES\x00\x00\x0f\x01QA.MES\x00\x00"
        self.assertEqual([], _references(code)["resources"])

    def test_marker_api_distinguishes_no_match_from_a_matched_truncated_envelope(self) -> None:
        from mes_instruction_ir import decode_resource_marker_ir

        self.assertEqual({"matched": False}, decode_resource_marker_ir(AX_MARKER, 0, 6))
        self.assertEqual({"matched": False}, decode_resource_marker_ir(AX_MARKER[1:], 0))
        self.assertEqual({"matched": False}, decode_resource_marker_ir(MMO_MARKER[1:], 0))
        self.assertEqual({"matched": False}, decode_resource_marker_ir(MMO_MARKER, 1, len(MMO_MARKER) - 2))
        for code, start in ((AX_MARKER, 0), (VOICE_MARKER, 0), (INLINE_MARKER, 0), (MMO_MARKER, 1)):
            with self.subTest(code=code.hex()):
                complete = decode_resource_marker_ir(code, start)
                self.assertTrue(complete["matched"])
                self.assertTrue(complete["result"]["ok"])
                truncated = decode_resource_marker_ir(code, start, len(code) - 1)
                self.assertTrue(truncated["matched"])
                self.assertFalse(truncated["result"]["ok"])
                self.assertIn("truncated", truncated["result"]["error"])


class ReferenceGodotOracleTests(unittest.TestCase):
    maxDiff = 5000

    @classmethod
    def setUpClass(cls) -> None:
        cls.fixtures = reference_fixtures()
        cls.markers = marker_fixtures()
        cls.name_bytes = marker_name_byte_fixtures()
        cls.expected = run_godot_oracle(cls.fixtures + cls.markers + cls.name_bytes)

    def test_complete_reference_lists_and_order_match_gdscript(self) -> None:
        from mes_references import build_references

        for row in self.fixtures:
            with self.subTest(fixture=row["name"]):
                container = handoff.build_container(bytes.fromhex(row["hex"]))
                actual = build_references(container, handoff.build_typed_ir(container))
                self.assertEqual(self.expected[row["name"]], handoff.normalize(actual))

    def test_marker_results_match_gdscript_at_every_authored_prefix_and_limit(self) -> None:
        from mes_instruction_ir import decode_resource_marker_ir

        for row in self.markers:
            with self.subTest(fixture=row["name"]):
                code = bytes.fromhex(row["hex"])
                actual = decode_resource_marker_ir(code, row.get("start", 0), row.get("end", len(code)))
                self.assertEqual(self.expected[row["name"]], handoff.normalize(actual))

    def test_mmo_name_bytes_match_marker_and_strict_structural_paths(self) -> None:
        from mes_instruction_ir import decode_instruction_ir, decode_region_ir, decode_resource_marker_ir

        for row in self.name_bytes:
            with self.subTest(fixture=row["name"]):
                code = bytes.fromhex(row["hex"])
                mode, start = row["mode"], row["start"]
                if mode == "resource_marker":
                    actual = decode_resource_marker_ir(code, start)
                elif mode in ("instruction", "structural_instruction"):
                    actual = decode_instruction_ir(code, start, structural=mode == "structural_instruction")
                else:
                    actual = decode_region_ir(code, start, len(code), structural=mode == "structural_region")
                self.assertEqual(self.expected[row["name"]], handoff.normalize(actual))


if __name__ == "__main__":
    unittest.main()
