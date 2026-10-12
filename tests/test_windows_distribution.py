from __future__ import annotations

import json
from pathlib import Path
import sys
import tempfile
import unittest
import zipfile

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
from build_windows_distribution import SCHEMA, inventory, unpack, verify_distribution, write_manifest


class WindowsDistributionTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)

    def fixture(self):
        (self.root / "app.exe").write_bytes(b"authored fixture")
        return write_manifest(self.root / "manifest.json", {"schema": SCHEMA, "files": inventory(self.root)})

    def test_manifest_reopens_exact_file_inventory(self):
        manifest = self.fixture()
        self.assertEqual(verify_distribution(self.root)["payload_sha256"], manifest["payload_sha256"])

    def test_modified_executable_or_extra_file_is_rejected(self):
        self.fixture()
        (self.root / "app.exe").write_bytes(b"modified fixture")
        with self.assertRaises(ValueError):
            verify_distribution(self.root)
        (self.root / "app.exe").write_bytes(b"authored fixture")
        (self.root / "extra.py").write_text("pass")
        with self.assertRaises(ValueError):
            verify_distribution(self.root)

    def test_wrong_schema_and_modified_manifest_are_rejected(self):
        manifest = self.fixture()
        manifest["schema"] = "unknown/v1"
        (self.root / "manifest.json").write_text(json.dumps(manifest))
        with self.assertRaises(ValueError):
            verify_distribution(self.root)

    def test_zip_traversal_cannot_write_outside_destination(self):
        archive = self.root / "input.zip"
        with zipfile.ZipFile(archive, "w") as stream:
            stream.writestr("../escape.py", "pass")
        with self.assertRaises(ValueError):
            unpack(archive, self.root / "target")
        self.assertFalse((self.root / "escape.py").exists())

    def test_existing_zip_destination_is_never_overwritten(self):
        archive = self.root / "input.zip"
        target = self.root / "target"
        target.mkdir()
        (target / "keep.py").write_text("keep")
        with zipfile.ZipFile(archive, "w") as stream:
            stream.writestr("keep.py", "changed")
        with self.assertRaises(FileExistsError):
            unpack(archive, target)
        self.assertEqual((target / "keep.py").read_text(), "keep")


if __name__ == "__main__":
    unittest.main()
