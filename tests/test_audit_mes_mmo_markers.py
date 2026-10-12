from __future__ import annotations

import struct
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

from audit_mes_mmo_markers import audit_archive, normalize_mmo_name  # noqa: E402
from extract_kakyu_arc import NAME_KEY, OFFSET_KEY, SIZE_KEY  # noqa: E402


class MmoMarkerAuditTests(unittest.TestCase):
    def test_normalizes_mmo_names(self) -> None:
        self.assertEqual("D03.MMO", normalize_mmo_name(b"d03.mmo"))
        self.assertEqual("12C_1.MMO", normalize_mmo_name(b"12c_1.MmO"))

    def test_counts_only_exact_presentation_records(self) -> None:
        presentation = bytes.fromhex("0d09ff01") + b"d03.mmo\0" + bytes.fromhex("00")
        following_write = bytes.fromhex("0701ff0007ff00")
        code = (
            presentation
            + following_write
            + b"loose.mmo"
            + bytes.fromhex("0d09ff01")
            + b"bad-name.mmo\0\0"
        )
        mes = struct.pack("<I", 0) + code
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            _write_arc(root / "mes.arc", [("EVENTD03.MES", mes)])
            _write_arc(root / "mmo.arc", [("D03.MMO", b"MMO payload")])
            result = audit_archive(root / "mes.arc", root / "mmo.arc")

        self.assertEqual("kakyu_mes_mmo_presentation_audit/v2", result["schema"])
        self.assertEqual(3, result["mmo_tokens"])
        self.assertEqual(1, result["presentations"])
        self.assertEqual(1, result["markers"])
        self.assertEqual(1, result["resolved_markers"])
        self.assertEqual({"0x07": 1}, result["next_command_counts"])
        row = result["rows"][0]
        self.assertEqual(0, row["outer_offset"])
        self.assertEqual(1, row["offset"])
        self.assertEqual(len(presentation), row["end_offset"])
        self.assertEqual(0x0D, row["outer_command"])
        self.assertEqual(9, row["presentation_subcommand"])
        self.assertEqual(1, row["argument_count"])
        self.assertEqual(0x07, row["next_command"])
        self.assertEqual("D03.MMO", row["normalized"])
        self.assertTrue(row["resolved"])


def _write_arc(path: Path, entries: list[tuple[str, bytes]]) -> None:
    header_size = 4 + len(entries) * 264
    payload_offset = header_size
    records = bytearray()
    payloads = bytearray()
    for name, payload in entries:
        encoded_name = bytearray(256)
        raw_name = name.encode("ascii") + b"\0"
        for index, value in enumerate(raw_name):
            encoded_name[index] = value ^ NAME_KEY
        for index in range(len(raw_name), 256):
            encoded_name[index] = NAME_KEY
        records.extend(encoded_name)
        records.extend(struct.pack("<I", len(payload) ^ SIZE_KEY))
        records.extend(struct.pack("<I", payload_offset ^ OFFSET_KEY))
        payloads.extend(payload)
        payload_offset += len(payload)
    path.write_bytes(struct.pack("<I", len(entries)) + records + payloads)


if __name__ == "__main__":
    unittest.main()
