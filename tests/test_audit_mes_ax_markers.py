from __future__ import annotations

import struct
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

from audit_mes_ax_markers import audit_archive, normalize_ax_name  # noqa: E402
from extract_kakyu_arc import NAME_KEY, OFFSET_KEY, SIZE_KEY  # noqa: E402


class AxMarkerAuditTests(unittest.TestCase):
    def test_normalizes_ax_names(self) -> None:
        self.assertEqual("D01X.AX", normalize_ax_name(b"d01x.ax"))

    def test_counts_only_exact_marker_envelopes(self) -> None:
        marker = bytes.fromhex("0d08ff0200ff01") + b"d01x.ax\0" + bytes.fromhex("0202f900ff00")
        unresolved = bytes.fromhex("0d08ff0200ff01") + b"missing.ax\0" + bytes.fromhex("0202f900ff00")
        missing_outer = bytes.fromhex("08ff0200ff01") + b"orphan.ax\0" + bytes.fromhex("0202f900ff00")
        code = marker + unresolved + missing_outer + b"loose.ax"
        mes = struct.pack("<I", 0) + code
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            _write_arc(root / "mes.arc", [("D_TEST.MES", mes)])
            _write_arc(root / "data.arc", [("D01X.AX", b"AX payload")])
            result = audit_archive(root / "mes.arc", root / "data.arc")

        self.assertEqual("kakyu_mes_ax_marker_audit/v3", result["schema"])
        self.assertEqual(4, result["ax_tokens"])
        self.assertEqual(2, result["markers"])
        self.assertEqual(1, result["resolved_markers"])
        self.assertEqual(0, result["rows"][0]["offset"])
        self.assertEqual("D01X.AX", result["rows"][0]["normalized"])
        self.assertEqual(0x0D, result["rows"][0]["outer_command"])
        self.assertEqual(8, result["rows"][0]["presentation_subcommand"])
        self.assertEqual(0, result["rows"][0]["execution_selector"])
        self.assertEqual("data_arc_named_entry_load_confirmed", result["rows"][0]["native_consumer_semantics"])
        self.assertEqual("banked_i32[0][2]", result["rows"][0]["native_loader_argument"])
        self.assertEqual(
            "engine_initialized_destination_buffer_pointer",
            result["rows"][0]["native_loader_argument_semantics"],
        )
        self.assertEqual("unresolved", result["rows"][0]["native_payload_semantics"])
        self.assertTrue(result["rows"][0]["resolved"])
        self.assertFalse(result["rows"][1]["resolved"])


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
