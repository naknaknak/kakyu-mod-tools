"""Read-only source and atomic destination boundaries for the Python exporter."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
sys.path.insert(0, str(ROOT / "tests"))

import export_mes_analyzer_handoff as exporter  # noqa: E402
import mes_analyzer_handoff as handoff  # noqa: E402
from test_extract_kakyu_arc import _build_archive  # noqa: E402
from test_mes_instruction_ir import synthetic_container  # noqa: E402


class HandoffExporterTests(unittest.TestCase):
    def setUp(self) -> None:
        temporary = tempfile.TemporaryDirectory(prefix="authored-handoff-export-")
        self.addCleanup(temporary.cleanup)
        self.temporary = Path(temporary.name).resolve()
        self.project = self.temporary / "project"
        self.source = self.temporary / "source"
        self.project.mkdir()
        self.source.mkdir()
        self.archive = self.source / "authored.arc"
        self.payload = synthetic_container(b"\x01QA\x00\x19\x00")
        _build_archive(self.archive, [("SAMPLE.MES", self.payload)])
        self.original = self.archive.read_bytes()
        self.output = self.project / "handoffs" / "sample.json"
        project_root = patch.object(exporter, "ROOT", self.project)
        project_root.start()
        self.addCleanup(project_root.stop)

    def test_exported_actual_python_payload_round_trips_without_source_changes(self) -> None:
        result = exporter.export_handoff(self.archive, "sample.mes", self.output)
        saved = json.loads(self.output.read_text(encoding="utf-8"))
        self.assertTrue(handoff.verify(saved)["ok"])
        self.assertEqual("python_phase1_4", saved["producer"]["implementation"])
        self.assertEqual(saved["payload_sha256"], result["payload_sha256"])
        self.assertTrue(result["source_unchanged"])
        self.assertEqual(self.payload.hex(), saved["container"]["raw_hex"])
        self.assertEqual({
            "archive": "authored.arc", "entry": "SAMPLE.MES",
            "archive_sha256": hashlib.sha256(self.original).hexdigest(),
        }, saved["source_identity"])
        self.assertEqual(self.original, self.archive.read_bytes())
        self.assertFalse(self.output.with_name(self.output.name + ".tmp").exists())
        self.assertNotIn(str(self.temporary), self.output.read_text(encoding="utf-8"))

    def test_source_directory_and_output_or_temporary_hardlinks_are_rejected(self) -> None:
        # Both destination paths must be checked before the atomic writer opens
        # its temporary path: resolving path strings alone does not find aliases.
        self.output.parent.mkdir()
        for label, output, alias in (
            ("source_directory", self.source / "new.json", None),
            ("source_archive", self.archive, None),
            ("output_alias", self.output.parent / "alias.json", self.output.parent / "alias.json"),
            ("temporary_alias", self.output.parent / "temp_alias.json", self.output.parent / "temp_alias.json.tmp"),
        ):
            with self.subTest(case=label):
                if alias is not None:
                    alias.hardlink_to(self.archive)
                with patch.object(exporter, "write_json_atomic") as write, self.assertRaises(handoff.HandoffError):
                    exporter.export_handoff(self.archive, "SAMPLE.MES", output)
                write.assert_not_called()
                self.assertEqual(self.original, self.archive.read_bytes())
                if alias is not None:
                    self.assertEqual(self.original, alias.read_bytes())

    def test_destination_outside_the_project_is_rejected_before_writing(self) -> None:
        outside = self.temporary / "unrelated.json"
        outside.write_bytes(b"retained destination")
        for output in (outside, self.project / ".." / "unrelated.json"):
            with self.subTest(output=output), patch.object(exporter, "write_json_atomic") as write:
                with self.assertRaises(handoff.HandoffError):
                    exporter.export_handoff(self.archive, "SAMPLE.MES", output)
                write.assert_not_called()
                self.assertEqual(b"retained destination", outside.read_bytes())
        self.assertEqual(self.original, self.archive.read_bytes())

    def test_archive_change_during_export_preserves_the_existing_destination(self) -> None:
        self.output.parent.mkdir()
        self.output.write_bytes(b"previous artifact")
        load_entry = exporter.load_archive_entry

        def changed_source(archive: Path, entry: str) -> tuple:
            loaded = load_entry(archive, entry)
            # Simulate an independent writer after the exporter reads this
            # wholly authored source. The exporter must not publish that run.
            archive.write_bytes(archive.read_bytes() + b"authored concurrent change")
            return loaded

        with patch.object(exporter, "load_archive_entry", side_effect=changed_source), \
                patch.object(exporter, "write_json_atomic") as write:
            with self.assertRaisesRegex(handoff.HandoffError, "Source archive changed"):
                exporter.export_handoff(self.archive, "SAMPLE.MES", self.output)
            write.assert_not_called()
        self.assertEqual(b"previous artifact", self.output.read_bytes())
        self.assertFalse(self.output.with_name(self.output.name + ".tmp").exists())


if __name__ == "__main__":
    unittest.main()
