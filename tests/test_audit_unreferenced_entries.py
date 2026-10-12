"""The unreferenced-entry scan is invariant under machine-local file facts."""
from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

from audit_unreferenced_entries import EXECUTABLE_LABEL, scan_files  # noqa: E402

NAMES = ["ONE.MES", "TWO.MES"]


def _scan(exe_name: str, ini_text: bytes) -> list[dict]:
    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory)
        (root / "a.arc").write_bytes(b"xx one.mes xx")
        (root / "AI5WIN.INI").write_bytes(ini_text)
        exe = root / exe_name
        exe.write_bytes(b"MZ-synthetic")
        return scan_files(root, NAMES, exe)


class UnreferencedScanInvarianceTests(unittest.TestCase):
    def test_invariant_under_executable_rename_and_ini_size(self) -> None:
        first = _scan("AI5WIN.original.exe", b"[a]\n")
        second = _scan("AI5WIN.exe", b"[a]\nmuch=longer\n")
        self.assertEqual(first, second)

    def test_rows_keep_counts_and_mark_mutable(self) -> None:
        rows = {row["file"]: row for row in _scan("x.exe", b"two.mes")}
        self.assertEqual(rows["a.arc"]["occurrences"], {"ONE.MES": 1, "TWO.MES": 0})
        self.assertTrue(rows["AI5WIN.INI"]["mutable"])
        self.assertNotIn("size", rows["AI5WIN.INI"])
        self.assertEqual(rows["AI5WIN.INI"]["occurrences"]["TWO.MES"], 1)
        self.assertIn("size", rows[EXECUTABLE_LABEL])


if __name__ == "__main__":
    unittest.main()
