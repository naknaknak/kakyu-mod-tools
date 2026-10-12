from __future__ import annotations

import struct
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

from audit_mes_command03 import audit_archive  # noqa: E402
from extract_kakyu_arc import NAME_KEY, OFFSET_KEY, SIZE_KEY  # noqa: E402


def _write_arc(path: Path, entries: list[tuple[str, bytes]]) -> None:
    header_size = 4 + len(entries) * 264
    offset = header_size
    records = bytearray()
    payload = bytearray()
    for name, data in entries:
        encoded_name = bytearray(256)
        raw_name = name.encode("ascii") + b"\0"
        for index in range(256):
            encoded_name[index] = (raw_name[index] if index < len(raw_name) else 0) ^ NAME_KEY
        records.extend(encoded_name)
        records.extend(struct.pack("<I", len(data) ^ SIZE_KEY))
        records.extend(struct.pack("<I", offset ^ OFFSET_KEY))
        payload.extend(data)
        offset += len(data)
    path.write_bytes(struct.pack("<I", len(entries)) + records + payload)


class Command03AuditTests(unittest.TestCase):
    def test_focus_index_reports_the_covering_pair(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            archive = Path(temporary) / "mes.arc"
            code = bytes([0x03, 0x34, 0x12, 20, 0xFF, 2, 4, 0xFF, 0])
            _write_arc(archive, [("TEST.MES", struct.pack("<I", 0) + code)])

            result = audit_archive(archive, 0x1235)

        self.assertEqual("kakyu_mes_command03_audit/v3", result["schema"])
        self.assertEqual("global_u8", result["storage"])
        self.assertEqual(1, result["summary"]["command_03_runs"])
        self.assertEqual(2, result["summary"]["write_values"])
        self.assertEqual(1, result["focus_index"]["write_count"])
        self.assertEqual(1, result["focus_index"]["strict_valid_write_count"])
        record = result["focus_index"]["records"][0]
        self.assertEqual("TEST.MES", record["entry"])
        self.assertEqual(0, record["source_offset"])
        self.assertEqual(0x1234, record["start_index"])
        self.assertEqual(1, record["pair_index"])
        self.assertEqual(0, record["continuation"])
        self.assertEqual({"type": "literal", "value": 4, "width": 8, "source": {"offset": 6, "token": "0x04"}}, record["expression_ast"])

    def test_multiple_focus_indices_share_one_archive_scan_and_preserve_order(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            archive = Path(temporary) / "mes.arc"
            code = bytes([0x03, 0x34, 0x12, 20, 0xFF, 2, 4, 0xFF, 0])
            _write_arc(archive, [("TEST.MES", struct.pack("<I", 0) + code)])

            result = audit_archive(archive, [0x1235, 0x1234, 0x1235, 9])

        self.assertNotIn("focus_index", result)
        self.assertEqual([0x1235, 0x1234, 9], [row["index"] for row in result["focus_indices"]])
        self.assertEqual([1, 1, 0], [row["write_count"] for row in result["focus_indices"]])
        self.assertEqual(1, result["focus_indices"][0]["records"][0]["pair_index"])
        self.assertEqual(0, result["focus_indices"][1]["records"][0]["pair_index"])

    def test_rejects_out_of_range_focus_index(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            archive = Path(temporary) / "mes.arc"
            _write_arc(archive, [("TEST.MES", struct.pack("<I", 0))])

            with self.assertRaisesRegex(ValueError, "outside 0..65535"):
                audit_archive(archive, [0x10000])

    def test_focus_index_follows_native_u16_wrap(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            archive = Path(temporary) / "mes.arc"
            code = bytes([0x03, 0xFF, 0xFF, 1, 0xFF, 1, 2, 0xFF, 0])
            _write_arc(archive, [("WRAP.MES", struct.pack("<I", 0) + code)])

            result = audit_archive(archive, 0)

        self.assertEqual(1, result["summary"]["index_overflow_runs"])
        self.assertEqual(1, result["focus_index"]["write_count"])
        self.assertEqual(1, result["focus_index"]["records"][0]["pair_index"])


if __name__ == "__main__":
    unittest.main()
