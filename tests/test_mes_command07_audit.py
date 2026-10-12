from __future__ import annotations

import struct
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

from audit_mes_command07 import audit_archive  # noqa: E402
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


class Command07AuditTests(unittest.TestCase):
    def test_focus_range_reports_each_literal_write_and_dynamic_candidates(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            archive = Path(temporary) / "mes.arc"
            literal_run = bytes([0x07, 0xF1, 199, 0, 0xFF, 0, 10, 0xFF, 1, 11, 0xFF, 1, 12, 0xFF, 0])
            dynamic_run = bytes([0x07, 1, 0xA0, 0, 0xFF, 0, 13, 0xFF, 0])
            _write_arc(archive, [("TEST.MES", struct.pack("<I", 0) + literal_run + dynamic_run + b"\x00")])

            result = audit_archive(archive, 0x07, 200, 201, 0)

        self.assertEqual("kakyu_mes_banked_write_audit/v3", result["schema"])
        self.assertEqual("banked_u16", result["storage"])
        self.assertEqual(2, result["summary"]["command_runs"])
        self.assertEqual(1, result["summary"]["dynamic_destination_runs"])
        focus = result["focus_range"]
        self.assertEqual(2, focus["literal_write_count"])
        self.assertEqual({"200": 1, "201": 1}, focus["literal_write_counts_by_index"])
        self.assertEqual({"TEST.MES": 2}, focus["literal_write_counts_by_entry"])
        self.assertFalse(focus["records_truncated"])
        self.assertEqual([200, 201], [record["written_index"] for record in focus["records"]])
        self.assertEqual([1, 2], [record["pair_index"] for record in focus["records"]])
        self.assertEqual(1, focus["potential_dynamic_run_count"])
        self.assertEqual({"TEST.MES": 1}, focus["potential_dynamic_counts_by_entry"])
        self.assertFalse(focus["potential_dynamic_records_truncated"])
        self.assertEqual("state_ref", focus["potential_dynamic_records"][0]["destination_ast"]["type"])

    def test_focus_limit_keeps_complete_counts(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            archive = Path(temporary) / "mes.arc"
            code = bytes([0x07, 200, 0xFF, 0, 10, 0xFF, 1, 11, 0xFF, 0, 0x00])
            _write_arc(archive, [("LIMIT.MES", struct.pack("<I", 0) + code)])
            result = audit_archive(archive, 0x07, 200, 201, 0, 1)

        focus = result["focus_range"]
        self.assertEqual(2, focus["literal_write_count"])
        self.assertEqual(1, len(focus["records"]))
        self.assertTrue(focus["records_truncated"])

    def test_focus_bank_excludes_other_static_and_dynamic_banks(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            archive = Path(temporary) / "mes.arc"
            literal_run = bytes([0x07, 200, 0xFF, 1, 10, 0xFF, 0])
            dynamic_run = bytes([0x07, 1, 1, 11, 0xFF, 0])
            _write_arc(archive, [("BANK.MES", struct.pack("<I", 0) + literal_run + dynamic_run + b"\x00")])
            result = audit_archive(archive, 0x07, 200, 200, 0)

        self.assertEqual(0, result["focus_range"]["literal_write_count"])
        self.assertEqual(0, result["focus_range"]["potential_dynamic_run_count"])


if __name__ == "__main__":
    unittest.main()
