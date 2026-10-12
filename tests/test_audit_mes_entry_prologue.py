from __future__ import annotations

import struct
import sys
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

import audit_mes_entry_prologue as prologue  # noqa: E402


def container(code: bytes, entry_offsets: list[int]) -> bytes:
    """A minimal MES container: entry count, address table, then code."""
    header = struct.pack("<I", len(entry_offsets))
    table = b"".join(struct.pack("<I", offset) for offset in entry_offsets)
    return header + table + code


def entry_prologue(index: int) -> bytes:
    return bytes([0x17]) + struct.pack("<I", index)


RETURN = bytes([0x00])


class EntryPrologueTests(unittest.TestCase):
    def test_an_entry_starting_with_its_own_index_is_a_prologue(self) -> None:
        code = entry_prologue(0) + RETURN + entry_prologue(1) + RETURN
        report = prologue.audit_payload(container(code, [0, 6]), "T.MES")
        self.assertEqual(report["prologues"], 2)
        self.assertEqual(report["entries_without"], [])
        self.assertEqual(report["outside"], [])

    def test_an_entry_without_one_is_named(self) -> None:
        code = entry_prologue(0) + RETURN + RETURN
        report = prologue.audit_payload(container(code, [0, 6]), "T.MES")
        self.assertEqual(report["prologues"], 1)
        self.assertEqual([row["index"] for row in report["entries_without"]], [1])

    def test_a_wrong_index_is_not_a_prologue(self) -> None:
        code = entry_prologue(0) + RETURN + entry_prologue(7) + RETURN
        report = prologue.audit_payload(container(code, [0, 6]), "T.MES")
        self.assertEqual(report["prologues"], 1)
        self.assertEqual([row["index"] for row in report["entries_without"]], [1])
        self.assertEqual([row["value"] for row in report["outside"]], [7])

    def test_one_later_inside_an_entry_is_reported_outside(self) -> None:
        code = entry_prologue(0) + entry_prologue(0) + RETURN
        report = prologue.audit_payload(container(code, [0]), "T.MES")
        self.assertEqual(report["prologues"], 1)
        self.assertEqual([row["position"] for row in report["outside"]], [1])

    def test_a_bootstrap_prefix_is_not_an_entry(self) -> None:
        # Eight bootstrap bytes, then entry zero at 8 -- the archive's own shape.
        code = RETURN * 8 + entry_prologue(0) + RETURN
        report = prologue.audit_payload(container(code, [8]), "T.MES")
        self.assertEqual(report["entries"], 1)
        self.assertEqual(report["prologues"], 1)
        self.assertEqual(report["entries_without"], [])

    def test_a_container_with_no_address_table_has_no_entries(self) -> None:
        # `LIBLARY.LIB`'s shape: the whole code is bootstrap, so a 0x17 inside it
        # is outside an entry rather than a missing prologue for an invented one.
        code = RETURN + entry_prologue(0) + RETURN
        report = prologue.audit_payload(container(code, []), "LIBLARY.LIB")
        self.assertEqual(report["entries"], 0)
        self.assertEqual(report["prologues"], 0)
        self.assertEqual(report["entries_without"], [])
        self.assertEqual([row["region"] for row in report["outside"]], ["bootstrap"])

    def test_an_undecodable_entry_does_not_claim_a_prologue(self) -> None:
        code = entry_prologue(0) + bytes([0x0B, 0xFF])
        report = prologue.audit_payload(container(code, [0]), "T.MES")
        self.assertEqual(report["prologues"], 1)


class ArchiveReportTests(unittest.TestCase):
    def test_a_non_positive_limit_fails_closed(self) -> None:
        self.assertEqual(prologue.main(["--arc", str(ROOT), "--limit", "0"]), 2)

    def test_a_missing_archive_reports_rather_than_raises(self) -> None:
        self.assertEqual(prologue.main(["--arc", str(ROOT / "nope.arc")]), 2)


if __name__ == "__main__":
    unittest.main()
