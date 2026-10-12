from __future__ import annotations

import struct
import sys
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

import mes_basic_block_ir_v6  # noqa: E402
import mes_structured_ir  # noqa: E402


COMMAND_12_RECORD = bytes.fromhex("120201ff0203ff0200ff00")
MMO_AND_SURFACE_ENVELOPES = (
    b"\x0D\x09\xFF\x01B03.MMO\x00\x00"
    + bytes.fromhex(
        "0d0bff0201ff0200ff0200ff02f17f02ff02f18f01ff0202ff0200ff0200ff0201ff00"
    )
)


class MesStructuredIrTests(unittest.TestCase):
    def test_command_12_consumes_complete_typed_record_list(self) -> None:
        instruction = mes_structured_ir.decode_instruction(
            COMMAND_12_RECORD,
            0,
            len(COMMAND_12_RECORD),
        )
        self.assertIsNotNone(instruction)
        self.assertEqual("native_record_dispatch", instruction["op"])
        self.assertEqual(0x12, instruction["commandId"])
        self.assertEqual(len(COMMAND_12_RECORD), instruction["endOffset"])
        records = instruction["operands"][0]["records"]
        self.assertEqual(3, len(records))
        self.assertEqual(
            [1, 3, 0],
            [record["value"]["ast"]["value"] for record in records],
        )
        document = mes_structured_ir.decode_mes(
            struct.pack("<I", 0) + COMMAND_12_RECORD,
            {"entry": "synthetic.MES"},
        )
        self.assertEqual("ai5_mes_partial_ir/v4", document["schema"])

    def test_command_12_payload_does_not_create_shadow_branch(self) -> None:
        code = COMMAND_12_RECORD + b"\x00"
        document = mes_basic_block_ir_v6.decode_mes(
            struct.pack("<I", 0) + code,
            {"entry": "synthetic.MES"},
        )
        instructions = [
            instruction
            for node in document["nodes"]
            for instruction in node.get("instructions", [])
        ]
        self.assertEqual(
            [(0, len(COMMAND_12_RECORD), "native_record_dispatch")],
            [
                (
                    instruction["sourceOffset"],
                    instruction["endOffset"],
                    instruction["op"],
                )
                for instruction in instructions
                if instruction["op"] == "native_record_dispatch"
            ],
        )
        self.assertEqual(
            [],
            [
                edge
                for edge in document["blockEdges"]
                if edge.get("commandId") == 0x0B
            ],
        )

    def test_presentation_envelopes_do_not_create_shadow_branch(self) -> None:
        document = mes_basic_block_ir_v6.decode_mes(
            struct.pack("<I", 0) + MMO_AND_SURFACE_ENVELOPES,
            {"entry": "synthetic.MES"},
        )
        instructions = [
            instruction
            for node in document["nodes"]
            for instruction in node.get("instructions", [])
        ]
        self.assertIn(
            (0, 13, "mmo_resource_marker"),
            [
                (
                    instruction["sourceOffset"],
                    instruction["endOffset"],
                    instruction["op"],
                )
                for instruction in instructions
            ],
        )
        self.assertIn(
            (13, len(MMO_AND_SURFACE_ENVELOPES), "surface_dispatch_record_list"),
            [
                (
                    instruction["sourceOffset"],
                    instruction["endOffset"],
                    instruction["op"],
                )
                for instruction in instructions
            ],
        )
        self.assertEqual(
            [],
            [
                edge
                for edge in document["blockEdges"]
                if edge.get("commandId") == 0x0B
            ],
        )


if __name__ == "__main__":
    unittest.main()
