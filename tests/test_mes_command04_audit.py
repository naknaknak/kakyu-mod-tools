from __future__ import annotations

import struct
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

from audit_mes_command04 import audit_archive  # noqa: E402
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


class Command04AuditTests(unittest.TestCase):
    def test_reports_dynamic_state_u16_run(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            archive = root / "mes.arc"
            code = bytes([0x04, 4, 1, 0xFF, 1, 2, 0xFF, 0, 0x00])
            _write_arc(archive, [("TEST.MES", struct.pack("<I", 0) + code)])
            result = audit_archive(archive, 5)
            summary = result["summary"]
            self.assertEqual("kakyu_mes_command04_audit/v2", result["schema"])
            self.assertEqual("state_u16", result["storage"])
            self.assertEqual(1, summary["command_04_runs"])
            self.assertEqual(2, summary["write_values"])
            self.assertEqual(1, summary["multi_write_runs"])
            self.assertEqual(1, summary["strict_valid_runs"])
            self.assertEqual(1, summary["strict_valid_multi_write_runs"])
            self.assertEqual(0, summary["strict_valid_index_overflow_runs"])
            self.assertEqual(2, summary["strict_valid_max_run_length"])
            self.assertEqual({"1": 1, "0": 1}, summary["strict_valid_continuation_values"])
            self.assertEqual(0, summary["structural_only_multi_write_runs"])
            self.assertEqual(0, summary["index_overflow_runs"])
            self.assertEqual({"4": 1, "5": 1}, summary["written_indices"])
            self.assertEqual([1, 0], result["samples"][0]["continuations"])
            self.assertEqual(1, result["focus_index"]["write_count"])
            self.assertEqual(1, result["focus_index"]["strict_valid_write_count"])
            self.assertEqual(1, result["focus_index"]["records"][0]["pair_index"])
            self.assertEqual(
                {"type": "literal", "value": 2, "width": 8, "source": {"offset": 5, "token": "0x02"}},
                result["focus_index"]["records"][0]["expression_ast"],
            )

    def test_focus_index_follows_native_u8_wrap(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            archive = Path(temporary) / "mes.arc"
            code = bytes([0x04, 0xFF, 1, 0xFF, 1, 2, 0xFF, 0, 0x00])
            _write_arc(archive, [("WRAP.MES", struct.pack("<I", 0) + code)])
            result = audit_archive(archive, 0)

        self.assertEqual({"255": 1, "0": 1}, result["summary"]["written_indices"])
        self.assertEqual(1, result["focus_index"]["write_count"])
        self.assertEqual(1, result["focus_index"]["records"][0]["pair_index"])


if __name__ == "__main__":
    unittest.main()
