from __future__ import annotations

import struct
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

from audit_mes_startup_bootstrap import audit_startup_bootstrap  # noqa: E402
from extract_kakyu_arc import ENTRY_SIZE, NAME_KEY, OFFSET_KEY, SIZE_KEY  # noqa: E402


def _encoded_name(name: str) -> bytes:
    encoded = bytearray([NAME_KEY] * 256)
    for index, value in enumerate(name.encode("ascii")):
        encoded[index] = value ^ NAME_KEY
    return bytes(encoded)


def _write_arc(path: Path, entries: list[tuple[str, bytes]]) -> None:
    payload_offset = 4 + len(entries) * ENTRY_SIZE
    records = bytearray()
    payloads = bytearray()
    for name, payload in entries:
        records.extend(_encoded_name(name))
        records.extend(struct.pack("<I", len(payload) ^ SIZE_KEY))
        records.extend(struct.pack("<I", payload_offset ^ OFFSET_KEY))
        payloads.extend(payload)
        payload_offset += len(payload)
    path.write_bytes(struct.pack("<I", len(entries)) + records + payloads)


def _startup_mes(second_selector: int = 3, terminal_target: str = "open.mes") -> bytes:
    code = bytearray(0xBEB)
    code[0:8] = b"\x14\x12\xFF\x08\x00\x00\x00\x00"
    code[8:13] = b"\x17\x00\x00\x00\x00"
    code[0x14C:0x160] = b"\x0D\x08\xFF\x02\x02\xFF\x01LIBLARY.LIB\0\0"
    code[0x165:0x17A] = (
        b"\x0D\x08\xFF\x02"
        + bytes((second_selector,))
        + b"\xFF\x01DEF_MAIN.MES\0\0"
    )
    encoded_target = terminal_target.encode("ascii")
    code[0xBCA : 0xBCA + 4 + len(encoded_target)] = b"\x0E\x01" + encoded_target + b"\0\0"
    code[0xBEA] = 0
    return struct.pack("<II", 1, 8) + code


class MesStartupBootstrapAuditTests(unittest.TestCase):
    def test_reports_bounded_startup_execution_order(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            archive = Path(directory) / "mes.arc"
            _write_arc(
                archive,
                [
                    ("START.MES", _startup_mes()),
                    ("LIBLARY.LIB", b"library"),
                    ("DEF_MAIN.MES", b"definition"),
                    ("OPEN.MES", b"open"),
                ],
            )
            result = audit_startup_bootstrap(archive)

        self.assertEqual("kakyu_mes_startup_bootstrap_audit/v2", result["schema"])
        self.assertEqual(["LIBLARY.LIB", "DEF_MAIN.MES"], result["execution_order"])
        self.assertEqual([0x14C, 0x165], [row["command_coordinate"] for row in result["records"]])
        self.assertEqual([2, 3], [row["selector"] for row in result["records"]])
        self.assertEqual(8, result["code_file_offset"])
        self.assertEqual(0xBEB, result["code_size"])
        self.assertEqual(18, result["root_bootstrap"]["registered_selector"])
        self.assertEqual(8, result["root_bootstrap"]["target_coordinate"])
        self.assertEqual(0xBCA, result["terminal_handoff"]["command_coordinate"])
        self.assertEqual("OPEN.MES", result["terminal_handoff"]["target_entry"])
        self.assertEqual(0xBEA, result["terminal_handoff"]["tail_return_coordinate"])

    def test_rejects_changed_definition_selector(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            archive = Path(directory) / "mes.arc"
            _write_arc(
                archive,
                [
                    ("START.MES", _startup_mes(second_selector=2)),
                    ("LIBLARY.LIB", b"library"),
                    ("DEF_MAIN.MES", b"definition"),
                    ("OPEN.MES", b"open"),
                ],
            )
            with self.assertRaisesRegex(ValueError, "record changed at 0x0165"):
                audit_startup_bootstrap(archive)

    def test_rejects_missing_target_entry(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            archive = Path(directory) / "mes.arc"
            _write_arc(
                archive,
                [("START.MES", _startup_mes()), ("LIBLARY.LIB", b"library")],
            )
            with self.assertRaisesRegex(ValueError, "required ARC entry is missing: DEF_MAIN.MES"):
                audit_startup_bootstrap(archive)

    def test_rejects_changed_root_bootstrap(self) -> None:
        changed = bytearray(_startup_mes())
        changed[8] = 0x15
        with tempfile.TemporaryDirectory() as directory:
            archive = Path(directory) / "mes.arc"
            _write_arc(
                archive,
                [
                    ("START.MES", bytes(changed)),
                    ("LIBLARY.LIB", b"library"),
                    ("DEF_MAIN.MES", b"definition"),
                    ("OPEN.MES", b"open"),
                ],
            )
            with self.assertRaisesRegex(ValueError, "root bootstrap transfer changed"):
                audit_startup_bootstrap(archive)

    def test_rejects_changed_terminal_handoff(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            archive = Path(directory) / "mes.arc"
            _write_arc(
                archive,
                [
                    ("START.MES", _startup_mes(terminal_target="exit.mes")),
                    ("LIBLARY.LIB", b"library"),
                    ("DEF_MAIN.MES", b"definition"),
                    ("OPEN.MES", b"open"),
                ],
            )
            with self.assertRaisesRegex(ValueError, "terminal handoff changed"):
                audit_startup_bootstrap(archive)


if __name__ == "__main__":
    unittest.main()
