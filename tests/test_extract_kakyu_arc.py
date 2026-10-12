from __future__ import annotations

import struct
import sys
import tempfile
import unittest
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PROJECT_ROOT / "tools"))

from extract_kakyu_arc import (  # noqa: E402
    ENTRY_SIZE,
    NAME_KEY,
    OFFSET_KEY,
    SIZE_KEY,
    extract_arc,
    read_entries,
)


def _encoded_name(name: str) -> bytes:
    raw = bytearray([NAME_KEY] * 256)
    for index, value in enumerate(name.encode("ascii")):
        raw[index] = value ^ NAME_KEY
    return bytes(raw)


def _build_archive(path: Path, entries: list[tuple[str, bytes]]) -> None:
    payload_offset = 4 + len(entries) * ENTRY_SIZE
    records = bytearray()
    payload = bytearray()
    for name, data in entries:
        records.extend(_encoded_name(name))
        records.extend(struct.pack("<I", len(data) ^ SIZE_KEY))
        records.extend(struct.pack("<I", payload_offset ^ OFFSET_KEY))
        payload.extend(data)
        payload_offset += len(data)
    path.write_bytes(struct.pack("<I", len(entries)) + records + payload)


class ArcExtractorTests(unittest.TestCase):
    def test_reads_and_stream_extracts_synthetic_archive(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            archive = root / "synthetic.arc"
            output = root / "output"
            _build_archive(archive, [("ONE.MES", b"first"), ("TWO.OGG", b"second")])

            self.assertEqual(
                [(name, size) for name, _offset, size in read_entries(archive)],
                [("ONE.MES", 5), ("TWO.OGG", 6)],
            )
            self.assertEqual(extract_arc(archive, output), (2, 0))
            self.assertEqual((output / "ONE.MES").read_bytes(), b"first")
            self.assertEqual((output / "TWO.OGG").read_bytes(), b"second")
            self.assertEqual(extract_arc(archive, output), (0, 2))

    def test_rejects_traversal_name(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            archive = Path(temporary_directory) / "unsafe.arc"
            _build_archive(archive, [("../ESCAPE.MES", b"bad")])
            with self.assertRaisesRegex(ValueError, "unsafe or invalid"):
                read_entries(archive)

    def test_rejects_out_of_bounds_entry(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            archive = Path(temporary_directory) / "broken.arc"
            record = _encoded_name("BROKEN.MES")
            record += struct.pack("<I", 10 ^ SIZE_KEY)
            record += struct.pack("<I", (4 + ENTRY_SIZE) ^ OFFSET_KEY)
            archive.write_bytes(struct.pack("<I", 1) + record)
            with self.assertRaisesRegex(ValueError, "outside archive"):
                read_entries(archive)


if __name__ == "__main__":
    unittest.main()
