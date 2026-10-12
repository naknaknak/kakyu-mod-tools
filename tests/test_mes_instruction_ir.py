"""Exact instruction/region/typed-IR parity against the GDScript producer.

Every byte sequence here is small and authored. No fixture reads an archive or
contains original game dialogue. Godot runs once for the complete oracle table;
only the oracle tests skip when a console executable cannot be found. Pure
Python boundary canaries remain available without Godot.
"""

from __future__ import annotations

import json
import os
from pathlib import Path
import struct
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
sys.path.insert(0, str(ROOT / "tools" / "content_suite"))
sys.path.insert(0, str(ROOT / "tests"))

import mes_analyzer_handoff as handoff  # noqa: E402
import run_headless_validation as validation  # noqa: E402


def fixture(name: str, code: bytes, **options: object) -> dict[str, object]:
    return {"name": name, "hex": code.hex(), **options}


def synthetic_container(code: bytes, offsets: tuple[int, ...] = ()) -> bytes:
    return struct.pack("<I", len(offsets)) + b"".join(
        struct.pack("<I", offset) for offset in offsets
    ) + code


def instruction_fixtures() -> list[dict[str, object]]:
    rows = [fixture(f"singleton_{value:02x}", bytes([value])) for value in range(256)]
    examples = {
        "text_ascii": b"\x01QA\x00",
        "text_pair": bytes.fromhex("018140824100"),
        "text_extension_pair": bytes.fromhex("01fa4000"),
        "text_nul_pair": bytes.fromhex("01810000"),
        "text_deferred_empty": bytes.fromhex("01ff0200"),
        "text_deferred_pair": bytes.fromhex("018140ff0200"),
        "lead_text": bytes.fromhex("814000"),
        "lead_deferred_ff": bytes.fromhex("8140ff00"),
        "single_stream_nul": bytes.fromhex("02414200"),
        "single_stream_lead": bytes.fromhex("02418140"),
        "separator_stream": bytes.fromhex("0d010200"),
        "default_stream": b"QA\x00",
        "global_u8_run": bytes.fromhex("03120021ff0122ff00"),
        "state_u16_run": bytes.fromhex("0405f11200ff01800503e0ff00"),
        "dynamic_u8_run": bytes.fromhex("0502ff21ff0122ff00"),
        "banked_u8_run": bytes.fromhex("0602ff0321ff0122ff00"),
        "banked_u16_run": bytes.fromhex("0702ff0321ff0122ff00"),
        "banked_i32_run": bytes.fromhex("0802ff0321ff0122ff00"),
        "slot_u16_run": bytes.fromhex("09020021ff0122ff00"),
        "global_i32_run": bytes.fromhex("0a02ff21ff0122ff00"),
        "slot_u8_run": bytes.fromhex("160321ff0122ff00"),
        "condition_transfer": bytes.fromhex("0b01ff78563412"),
        "continuation_transfer": bytes.fromhex("0c78563412"),
        "bootstrap_transfer": bytes.fromhex("1401ff78563412"),
        "library_registration": bytes.fromhex("1c05ff78563412"),
        "entry_label": bytes.fromhex("1778563412"),
        "source_line": bytes.fromhex("1f78563412"),
        "jump_table": bytes.fromhex("188005ff"),
        "cursor_hold": bytes.fromhex("13ff"),
        "cursor_numeric": bytes.fromhex("1307"),
        "literal_insert": b"\x0e\x01QA\x00\x00",
        "script_handoff": b"\x0e\x01QA.MES\x00\x00",
        "script_dispatch": b"\x0f\x01Qa.mes\x00\x00",
        "unsafe_script": b"\x0f\x01../QA.MES\x00\x00",
        "multiple_script_records": b"\x0f\x01QA.MES\x00\x02\x05\xff\x00",
        "name_insert": bytes.fromhex("0eff0200f90000a000e0f1400be0ff00"),
        "unknown_record_tags": bytes.fromhex("12fe030201ff00"),
        "record_strings": b"\x12\x01QA\x00\x01\x81\x40\x00\x00",
        "command10_fields": bytes.fromhex("100001020304"),
        "native_selection": b"\x15\x01Q\x00\x02\x05\xff\x00",
        "inline_library": b"\x0d\x08\xff\x02\x02\xff\x01QA.LIB\x00\x00",
        "inline_script": b"\x0d\x08\xff\x02\x01\xff\x01QA.MES\x00\x00",
        "ax_resource": b"\x0d\x08\xff\x02\x00\xff\x01QA.AX\x00\x02\x02\xf9\x00\xff\x00",
        "effect_request": b"\x0d\x06\xff\x02\x00\xff\x01qa.wav\x00\x02\xf6\x29\x00\xff\x00",
        "effect_unsafe_name": b"\x0d\x06\xff\x02\x00\xff\x01../qa.wav\x00\x02\x01\xff\x00",
        "effect_selector_only": bytes.fromhex("0d06ff0201ff00"),
        "surface_empty": bytes.fromhex("0d0bff00"),
        "surface_numeric": bytes.fromhex("0d0bff0236ff0222ff00"),
        "surface_composition": bytes.fromhex("0d0aff0201ff00"),
        "ax_invalid_cell_argument": bytes.fromhex("0d03ff0201ff02ff00"),
        "write_continuation_ff": bytes.fromhex("040121ffff"),
        "write_empty_expression": bytes.fromhex("0401ff00"),
        "write_multiple_results": bytes.fromhex("04010102ff00"),
        "bank_destination_empty": bytes.fromhex("06ff0001ff00"),
        "record_expression_empty": bytes.fromhex("1202ff00"),
        "record_expression_underflow": bytes.fromhex("1202e0ff00"),
        "record_missing_terminator": bytes.fromhex("120201ff"),
        "record_unterminated_string": b"\x12\x01QA",
        "expression_banked_missing_bank": bytes.fromhex("1801a0"),
        "expression_dynamic_underflow": bytes.fromhex("18f5ff"),
        "expression_literal_u32_truncated": bytes.fromhex("18f2010203"),
    }
    for command in (0x0E, 0x0F, 0x11, 0x12, 0x15, 0x1B, 0x1D):
        examples[f"empty_records_{command:02x}"] = bytes([command, 0])
    for selector in (1, 2, 6, 7, 8):
        examples[f"ax_selector_{selector}"] = bytes([0x0D, 3, 0xFF, 2, selector, 0xFF, 0])
    for selector in (1, 2):
        examples[f"ax_coordinates_{selector}"] = (
            bytes([0x0D, 3, 0xFF, 2, selector, 0xFF, 2, 3, 0xFF, 2, 4, 0xFF, 0])
        )
    for token in range(0xE0, 0xF1):
        # E5 consumes one argument; the others consume two.
        values = bytes([7]) if token == 0xE5 else bytes([7, 3])
        examples[f"expression_operator_{token:02x}"] = b"\x18" + values + bytes([token, 0xFF])
        examples[f"expression_underflow_{token:02x}"] = bytes([0x18, token, 0xFF])
    for name, expression in {
        "u16": "f13412ff", "u32": "f278563412ff", "state_u16": "8003ff",
        "state_i32": "f803ff", "global_u8": "f33412ff", "global_i32": "f63412ff",
        "dynamic_u8": "03f5ff", "dynamic_i32": "03f7ff", "banked_u16": "03a002ff",
        "banked_u8": "03c002ff", "banked_i32": "03f902ff",
        "nested": "03a0028001e0ff",
    }.items():
        examples[f"expression_{name}"] = b"\x18" + bytes.fromhex(expression)
    for name, code in examples.items():
        rows.append(fixture(name, code))
        # Nonzero coordinates detect AST/operand offsets accidentally made relative.
        rows.append(fixture(name + "_offset", b"\x19\x1a" + code + b"\x00", start=2, end=2 + len(code)))
    for name in ("global_u8_run", "banked_u16_run", "condition_transfer", "command10_fields", "record_strings"):
        code = examples[name]
        for end in range(len(code)):
            rows.append(fixture(f"{name}_limit_{end}", code, end=end))
    rows.extend([
        fixture("negative_offset", b"\x00", start=-1),
        fixture("offset_at_end", b"\x00", start=1),
        fixture("empty_code", b""),
        fixture("unbounded_limit", b"\x01QA\x00", end=-1),
        fixture("clamped_limit", b"\x01QA\x00", end=100),
        fixture("mmo_outer_context", b"\x0d\x09\xff\x01QA.MMO\x00\x00", start=1),
        fixture("mmo_without_outer", b"\x09\xff\x01QA.MMO\x00\x00"),
        fixture("expression_byte_budget", b"\x18" + b"\x01" * 0x1000 + b"\xff"),
    ])
    promoted = presentation_fixtures()
    for row in promoted:
        code = bytes.fromhex(row["hex"])
        start = row.get("start", 0)
        rows.append(row)
        rows.append(fixture(row["name"] + "_offset", b"\x19\x1a" + code + b"\x00",
                            start=start + 2, end=len(code) + 2))
    # Every authored 0x0D envelope is checked at every prefix, both when the
    # source still contains its suffix and when the physical bytes end there.
    # A recognizer must honor the caller's limit before specializing metadata.
    envelopes = {}
    for row in rows:
        code = bytes.fromhex(row["hex"])
        start = row.get("start", 0)
        if code.startswith(b"\x0d") and (code, start) not in envelopes:
            envelopes[code, start] = row["name"]
    for (code, start), name in envelopes.items():
        for end in range(start, len(code)):
            rows.append(fixture(f"{name}_presentation_limit_{end}", code, start=start, end=end))
            rows.append(fixture(f"{name}_presentation_cut_{end}", code[:end], start=start))
            rows.append(fixture(f"{name}_presentation_offset_limit_{end}", b"\x19\x1a" + code,
                                start=start + 2, end=end + 2))
    return rows


def presentation_fixtures() -> list[dict[str, object]]:
    # Reuse the presentation suite's authored record helper and marker framing
    # constants. The expected values still come only from the GDScript oracle.
    from test_mes_presentation_ir import _records, decoder

    rows = []
    for label, source_name in (
        ("wav", b"sample.wav"), ("ogg", b"sample.ogg"),
        ("unsafe", b"../sample.wav"), ("empty", b""), ("cp932", b"\x81\x40.wav"),
    ):
        code = b"\x0d\x06\xff\x02\x00\xff\x01" + source_name + b"\x00\x02\x03\xff\x00\x00"
        rows.append(fixture("presentation_effect_" + label, code))
    for label, code in (
        ("empty", b"\x0d\x06\xff\x00"), ("unknown_tag", b"\x0d\x06\xff\x7f\x00"),
    ):
        rows.append(fixture("presentation_effect_" + label + "_records", code))
    for selector in (2, 6, 7, 8):
        rows.append(fixture(f"presentation_ax_exact_{selector}", b"\x0d\x03\xff" + _records(selector)))
    for values in ((1,), (1, 3, 4), (2, 3, 4, 0)):
        rows.append(fixture("presentation_ax_selected_" + "_".join(map(str, values)),
                            b"\x0d\x03\xff" + _records(*values)))
    rows.append(fixture("presentation_composition", b"\x0d\x0a\xff" + _records(1)))
    for label, values in (
        ("copy_default", (0, 1, 2, 3, 4, 5, 6, 7)),
        ("copy_explicit", (0, 1, 2, 3, 4, 5, 6, 7, 8)),
        ("copy_alternate", (1, 1, 2, 3, 4, 5, 6, 7, 8)),
        ("fill", (2, 1, 2, 3, 4)), ("refresh", (13, 1, 2, 3, 4, 5)),
        ("empty", ()), ("missing_arguments", (0,)), ("out_of_range", (13,)),
    ):
        rows.append(fixture("presentation_surface_" + label, b"\x0d\x0b\xff" + _records(*values)))
    rows.extend([
        fixture("presentation_ax_binding", decoder.AX_BINDING_PREFIX + b"\x02" + decoder.AX_BINDING_SUFFIX),
        fixture("presentation_named_transfer", b"\x0d\x04\xff\x02\x0d\xff\x02\x00\xff\x01A_B\x00\x00"),
        fixture("presentation_voice", decoder.VOICE_MARKER_HEADER + b"sample.ogg\x00" + decoder.VOICE_MARKER_SUFFIX),
        fixture("presentation_ax_marker", decoder.AX_MARKER_HEADER + b"sample.ax\x00" + decoder.AX_MARKER_SUFFIX),
        fixture("presentation_inline_library", b"\x0d\x08\xff\x02\x02\xff\x01sample.lib\x00\x00"),
        fixture("presentation_inline_script", b"\x0d\x08\xff\x02\x03\xff\x01sample.mes\x00\x00"),
        fixture("presentation_mmo", b"\x0d\x09\xff\x01sample.mmo\x00\x00", start=1),
        fixture("presentation_plain_separator", b"\x0d\x00"),
        fixture("presentation_plain_slot_run", b"\x09\x00\x00\x00\xff\x00"),
    ])
    return rows


SHADOW_BRANCH = bytes.fromhex("0d0b02ff0101010100") + b"\x01QA\x00"
SHADOW_INTERNAL = bytes.fromhex("0d25ff02800cff00") + b"\x01QA\x00"


def region_fixtures() -> list[dict[str, object]]:
    rows = [
        fixture("region_shadow_branch", SHADOW_BRANCH, mode="region"),
        fixture("region_shadow_internal", SHADOW_INTERNAL, mode="region"),
        fixture("region_shadow_truncated", SHADOW_BRANCH, mode="region", end=6),
        fixture("region_shadow_offset", b"\x19" + SHADOW_INTERNAL, mode="region", start=1),
        fixture("region_plain_stream", bytes.fromhex("0d130000"), mode="region"),
        fixture("region_deferred_ff", bytes.fromhex("018140ff00"), mode="region"),
        fixture("region_strict_failure", bytes.fromhex("190aff0201ff000d"), mode="region"),
        fixture("region_truncated_tail", bytes.fromhex("190c0203"), mode="region"),
        fixture("region_step_limit", bytes.fromhex("191a1900"), mode="region", max_instructions=2),
        fixture("region_empty", b"", mode="region"),
        fixture("region_bad_start", b"\x00", mode="region", start=-1),
        fixture("region_bad_end", b"\x00", mode="region", end=2),
        fixture("region_reversed", b"\x00", mode="region", start=1, end=0),
    ]
    # Start from the outer command even for an MMO marker. This also checks
    # whether the next command remains outside the promoted payload.
    for row in presentation_fixtures():
        code = bytes.fromhex(row["hex"]) + b"\x19\x1a\x00"
        rows.append(fixture("region_" + row["name"], code, mode="region"))
    return rows


def typed_ir_fixtures() -> list[dict[str, object]]:
    examples = [
        ("bootstrap", b"\x19\x01QA\x00\x00", ()),
        ("no_code", b"", ()),
        ("entry_only", bytes.fromhex("191a00"), (0,)),
        ("bootstrap_entries", bytes.fromhex("191a0003190007ff001901510000"), (3, 10)),
        ("opaque_tail", bytes.fromhex("190b01ff"), (0,)),
        ("strict_then_entry", bytes.fromhex("190aff0201ff00191a00"), (7,)),
        ("shadow_branch", SHADOW_BRANCH, (0,)),
        ("shadow_internal", SHADOW_INTERNAL, (0,)),
        ("bounded_string", b"\x01QA\x00\x19\x00", (2, 4)),
    ]
    rows = [fixture("typed_" + name, synthetic_container(code, offsets), mode="typed_ir")
            for name, code, offsets in examples]
    for row in presentation_fixtures():
        code = bytes.fromhex(row["hex"]) + b"\x19\x1a\x00"
        rows.append(fixture("typed_" + row["name"], synthetic_container(code, (0,)), mode="typed_ir"))
    return rows


class InstructionIrBoundaryTests(unittest.TestCase):
    def test_empty_text_before_ff_is_not_an_owned_message(self) -> None:
        from mes_instruction_ir import decode_instruction_ir

        result = decode_instruction_ir(bytes.fromhex("01ff0200"), 0, 4)
        self.assertTrue(result["ok"])
        self.assertEqual("command_01", result["op"])
        self.assertEqual(1, result["end_offset"])
        self.assertEqual([], result["operands"])

    def test_instruction_and_region_have_distinct_shadow_boundaries(self) -> None:
        from mes_instruction_ir import decode_instruction_ir, decode_region_ir

        instruction = decode_instruction_ir(SHADOW_BRANCH, 0, len(SHADOW_BRANCH))
        region = decode_region_ir(SHADOW_BRANCH, 0, len(SHADOW_BRANCH))
        self.assertEqual(1, instruction["end_offset"])
        self.assertTrue(region["ok"])
        self.assertEqual([0, 9], [row["source_offset"] for row in region["instructions"]])
        self.assertEqual([1], region["instructions"][0]["native_shadow_control_offsets"])
        self.assertFalse(any(row["op"] == "branch_if_not_true" for row in region["instructions"]))

    def test_invalid_expression_preserves_the_entire_region_tail(self) -> None:
        code = bytes.fromhex("190aff0201ff000d")
        result = handoff.build_typed_ir(handoff.build_container(synthetic_container(code)))
        self.assertFalse(result["complete"])
        self.assertEqual([0], [row["source_offset"] for row in result["instructions"]])
        self.assertEqual(1, len(result["opaque_boundaries"]))
        tail = result["opaque_boundaries"][0]
        self.assertEqual(1, tail["source_offset"])
        self.assertEqual(len(code), tail["end_offset"])
        self.assertEqual(code[1:].hex(), tail["raw_hex"])


def run_godot_oracle(fixtures: list[dict[str, object]]) -> dict[str, object]:
    """Run one shared authored-fixture oracle; only absent Godot permits a skip."""
    try:
        godot = validation.find_godot(None)
    except ValueError as error:
        if os.environ.get("GODOT4_CONSOLE"):
            raise RuntimeError(str(error)) from error
        raise unittest.SkipTest(str(error)) from error
    with tempfile.TemporaryDirectory(prefix="mes-ir-oracle-") as directory:
        path = Path(directory) / "synthetic.json"
        path.write_text(json.dumps(fixtures), encoding="utf-8")
        command = validation.godot_command(
            godot, ROOT, "--script", "res://tools/content_suite/cli/validate_mes_instruction_ir.gd", "--", str(path)
        )
        process = subprocess.run(
            command, cwd=ROOT, text=True, encoding="utf-8", errors="replace",
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=120,
            creationflags=subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0,
            check=False,
        )
    if process.returncode != 0:
        raise RuntimeError(f"GDScript instruction oracle failed ({process.returncode}):\n{process.stdout[-4000:]}")
    prefix = "MES_INSTRUCTION_IR_ORACLE "
    # Unicode separators such as U+0085 can occur inside a valid JSON name.
    # Only physical stdout newlines separate protocol records.
    output = [line[len(prefix):] for line in process.stdout.split("\n") if line.startswith(prefix)]
    if len(output) != 1:
        raise RuntimeError(f"GDScript oracle did not emit exactly one result:\n{process.stdout[-4000:]}")
    report = json.loads(output[0])
    if report.get("schema") != "kakyu_mes_instruction_ir_oracle/v1":
        raise RuntimeError("GDScript instruction oracle schema changed.")
    rows = report["results"]
    expected = {row["name"]: row["result"] for row in rows}
    names = [row["name"] for row in fixtures]
    if len(expected) != len(rows) or set(expected) != set(names):
        raise RuntimeError("GDScript instruction oracle omitted or duplicated a fixture.")
    return expected


class InstructionIrGodotOracleTests(unittest.TestCase):
    maxDiff = 4000

    @classmethod
    def setUpClass(cls) -> None:
        cls.fixtures = instruction_fixtures() + region_fixtures() + typed_ir_fixtures()
        cls.expected = run_godot_oracle(cls.fixtures)

    def test_complete_instruction_values_match_gdscript(self) -> None:
        from mes_instruction_ir import decode_instruction_ir

        for row in self.fixtures:
            if row.get("mode", "instruction") != "instruction":
                continue
            with self.subTest(fixture=row["name"]):
                code = bytes.fromhex(row["hex"])
                actual = decode_instruction_ir(code, row.get("start", 0), row.get("end", len(code)))
                self.assertEqual(self.expected[row["name"]], handoff.normalize(actual))

    def test_aligned_regions_match_gdscript(self) -> None:
        from mes_instruction_ir import decode_region_ir

        for row in self.fixtures:
            if row.get("mode") != "region":
                continue
            with self.subTest(fixture=row["name"]):
                code = bytes.fromhex(row["hex"])
                actual = decode_region_ir(code, row.get("start", 0), row.get("end", len(code)),
                                          row.get("max_instructions", 100000))
                self.assertEqual(self.expected[row["name"]], handoff.normalize(actual))

    def test_typed_ir_matches_the_handoff_component(self) -> None:
        for row in self.fixtures:
            if row.get("mode") != "typed_ir":
                continue
            with self.subTest(fixture=row["name"]):
                container = handoff.build_container(bytes.fromhex(row["hex"]))
                self.assertEqual(self.expected[row["name"]], handoff.normalize(handoff.build_typed_ir(container)))


if __name__ == "__main__":
    unittest.main()
