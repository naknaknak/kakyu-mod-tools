from __future__ import annotations

import struct
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

from audit_mes_ax_bindings import audit_archive  # noqa: E402
from extract_kakyu_arc import NAME_KEY, OFFSET_KEY, SIZE_KEY  # noqa: E402


class AxBindingAuditTests(unittest.TestCase):
    def test_counts_only_exact_binding_envelopes(self) -> None:
        prefix = bytes.fromhex("0d03ff0200ff0200ff02")
        suffix = bytes.fromhex("ff0202f900ff00")
        exact = b"".join(prefix + bytes((column,)) + suffix for column in range(3))
        invalidate_all = bytes.fromhex("0d03ff0207ff00")
        changed_column = prefix + b"\x03" + suffix
        changed_buffer = prefix + b"\x00" + bytes.fromhex("ff0203f900ff00")
        missing_outer = prefix[1:] + b"\x00" + suffix
        mes = (
            struct.pack("<I", 0)
            + exact
            + invalidate_all
            + changed_column
            + changed_buffer
            + missing_outer
        )

        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "mes.arc"
            _write_arc(path, [("D_TEST.MES", mes)])
            result = audit_archive(path)

        self.assertEqual("kakyu_mes_ax_binding_audit/v2", result["schema"])
        self.assertEqual(64, len(result["archive_sha256"]))
        self.assertTrue(result["source_unchanged"])
        self.assertEqual(3, result["bindings"])
        self.assertEqual(1, result["binding_entries"])
        self.assertEqual({"0": 1, "1": 1, "2": 1}, result["column_counts"])
        self.assertEqual([0, 1, 2], [row["cell_column"] for row in result["rows"]])
        self.assertEqual(0x0D, result["rows"][0]["outer_command"])
        self.assertEqual(3, result["rows"][0]["presentation_subcommand"])
        self.assertEqual(0, result["rows"][0]["execution_selector"])
        self.assertEqual(0x08, result["rows"][0]["consumer_virtual_slot"])
        self.assertEqual("banked_i32[0][2]", result["rows"][0]["buffer_argument"])
        self.assertEqual(
            "ax_binding_table_cell_install_confirmed",
            result["rows"][0]["native_consumer_semantics"],
        )
        self.assertEqual("unresolved", result["rows"][0]["native_rendering_semantics"])
        self.assertEqual(1, result["invalidations"])
        self.assertEqual(1, result["invalidation_entries"])
        invalidation = result["invalidation_rows"][0]
        self.assertEqual(7, invalidation["execution_selector"])
        self.assertEqual(0x20, invalidation["consumer_virtual_slot"])
        self.assertEqual(10, invalidation["cell_rows"])
        self.assertEqual(32, invalidation["cell_columns"])
        self.assertEqual(0x2C, invalidation["cell_record_bytes"])
        self.assertEqual(0xFF, invalidation["inactive_state"])
        self.assertEqual(
            "ax_binding_table_all_cells_invalidate_confirmed",
            invalidation["native_consumer_semantics"],
        )


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
