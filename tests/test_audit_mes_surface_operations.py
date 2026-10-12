from __future__ import annotations

import struct
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

from audit_mes_surface_operations import (  # noqa: E402
    SCHEMA,
    audit_archive,
    parse_display_refresh,
    parse_surface_dispatch,
    parse_surface_operation,
)
from extract_kakyu_arc import NAME_KEY, OFFSET_KEY, SIZE_KEY  # noqa: E402


class SurfaceOperationAuditTests(unittest.TestCase):
    def test_parses_complete_expression_envelope(self) -> None:
        arguments = [0, 1, 2, 5, 8, 0, 3, 4, 1]
        operation = bytes.fromhex("0d0bff") + b"".join(
            bytes((2, value, 0xFF)) for value in arguments
        ) + b"\0"

        row = parse_surface_operation(operation + b"\x07", 0)
        self.assertIsNotNone(row)
        assert row is not None
        self.assertEqual(0, row["mode"])
        self.assertEqual(arguments, row["literal_arguments"])
        self.assertEqual(len(operation), row["end_offset"])
        self.assertIsNone(parse_surface_operation(operation[:-1], 0))
        self.assertIsNone(parse_surface_operation(bytes.fromhex("0bff") + operation, 0))

        fill = bytes.fromhex("0d0bff") + b"".join(
            bytes((2, value, 0xFF)) for value in [2, 10, 20, 30, 40]
        ) + b"\0"
        fill_row = parse_surface_operation(fill, 0)
        self.assertIsNotNone(fill_row)
        assert fill_row is not None
        self.assertEqual("active_surface_rectangle_fill_confirmed", fill_row["operation"])

        empty = bytes.fromhex("0d0bff00")
        empty_row = parse_surface_dispatch(empty, 0)
        self.assertIsNotNone(empty_row)
        assert empty_row is not None
        self.assertIsNone(empty_row["mode"])
        self.assertEqual(0, empty_row["argument_count"])
        self.assertIsNone(parse_surface_operation(empty, 0))

        unknown = bytes.fromhex("0d0bff0236ff0222ff00")
        unknown_row = parse_surface_dispatch(unknown, 0)
        self.assertIsNotNone(unknown_row)
        assert unknown_row is not None
        self.assertEqual(54, unknown_row["mode"])
        self.assertEqual(2, unknown_row["argument_count"])
        self.assertIsNone(parse_surface_operation(unknown, 0))

        refresh = bytes.fromhex("0d0bff") + b"".join(
            bytes((2, value, 0xFF)) for value in [13, 10, 20, 29, 39, 0]
        ) + b"\0"
        refresh_row = parse_display_refresh(refresh, 0)
        self.assertIsNotNone(refresh_row)
        assert refresh_row is not None
        self.assertEqual(
            "conditional_attached_display_rectangle_refresh_confirmed",
            refresh_row["operation"],
        )
        self.assertEqual([0, 0], refresh_row["refresh_origin"])
        self.assertEqual([20, 20], refresh_row["refresh_extent"])
        self.assertIsNone(parse_surface_operation(refresh, 0))

    def test_audits_exact_rows_without_folding_next_command(self) -> None:
        literal = lambda value: bytes((2, value, 0xFF))
        operation = bytes.fromhex("0d0bff") + b"".join(literal(value) for value in range(9)) + b"\0"
        branch_like_noise = bytes.fromhex("0d0bff0209ff00")
        refresh = bytes.fromhex("0d0bff") + b"".join(
            literal(value) for value in [13, 10, 20, 29, 39, 0]
        ) + b"\0"
        mes = (
            struct.pack("<I", 0)
            + operation
            + b"\x07"
            + refresh
            + b"\x0d"
            + branch_like_noise
        )

        with tempfile.TemporaryDirectory() as directory:
            archive = Path(directory) / "mes.arc"
            _write_arc(archive, [("SURFACE.MES", mes)])
            result = audit_archive(archive)

        self.assertEqual(SCHEMA, result["schema"])
        self.assertEqual(3, result["raw_markers"])
        self.assertEqual(3, result["dispatch_candidates"])
        self.assertEqual(1, result["operations"])
        self.assertEqual(1, result["display_refreshes"])
        self.assertEqual(1, result["unresolved_candidates"])
        self.assertEqual({0: 1}, result["mode_counts"])
        self.assertEqual({9: 1}, result["record_count_counts"])
        self.assertEqual({0: 1}, result["dynamic_argument_counts"])
        self.assertEqual(0x07, result["rows"][0]["next_command"])
        self.assertEqual(0x0D, result["display_refresh_rows"][0]["next_command"])


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
