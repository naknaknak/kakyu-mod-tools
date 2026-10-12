from __future__ import annotations

import struct
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

from audit_mes_voice_markers import (  # noqa: E402
    CLEAR_VOICE_BIT,
    SET_VOICE_BIT,
    audit_archive,
    normalize_voice_name,
)
from extract_kakyu_arc import NAME_KEY, OFFSET_KEY, SIZE_KEY  # noqa: E402


class VoiceMarkerAuditTests(unittest.TestCase):
    def test_normalizes_short_and_full_numeric_ids(self) -> None:
        self.assertEqual("D0977.OGG", normalize_voice_name(b"d0977.ogg"))
        self.assertEqual("A0018.OGG", normalize_voice_name(b"a018.og"))

    def test_counts_only_exact_wrapped_marker_envelopes(self) -> None:
        marker = bytes.fromhex("07ff0202ff01") + b"d0977.ogg\0" + bytes.fromhex("0200ff00")
        code = SET_VOICE_BIT + marker + CLEAR_VOICE_BIT + b"x9999.ogg"
        mes = struct.pack("<I", 0) + code
        voice_payload = b"OggS"
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            _write_arc(root / "mes.arc", [("EVENTD03.MES", mes)])
            _write_arc(root / "voice.arc", [("D0977.OGG", voice_payload)])
            result = audit_archive(root / "mes.arc", root)

        self.assertEqual(2, result["voice_tokens"])
        self.assertEqual(1, result["markers"])
        self.assertEqual(1, result["fully_wrapped"])
        self.assertEqual(1, result["resolved_markers"])
        row = result["rows"][0]
        self.assertEqual(len(SET_VOICE_BIT), row["offset"])
        self.assertEqual(("voice.arc",), row["resolved_archives"])


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
