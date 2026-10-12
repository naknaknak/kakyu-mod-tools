from __future__ import annotations

import copy
import json
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
sys.path.insert(0, str(ROOT / "tools"))

import audit_mes_noop_compile_corpus as corpus  # noqa: E402
import compile_mes_noop as compiler  # noqa: E402
from tests import test_audit_mes_decompiler_corpus as source_tests  # noqa: E402


class MesNoopCompileCorpusTests(unittest.TestCase):
    def fixture(self, directory: Path) -> dict:
        manifest, _library = source_tests.MesDecompilerCorpusAuditTests().fixture(
            directory
        )
        return manifest

    def test_builds_deterministic_byte_identical_compile_spool(self) -> None:
        with tempfile.TemporaryDirectory() as raw_directory:
            root = Path(raw_directory)
            source = root / "source"
            source.mkdir()
            manifest = self.fixture(source)
            first = corpus.build(manifest, source, root / "first")
            second = corpus.build(copy.deepcopy(manifest), source, root / "second")

            self.assertEqual(first, second)
            self.assertEqual(corpus.COMPILE_SPOOL_SCHEMA, first["schema"])
            self.assertEqual(1, first["entry_count"])
            self.assertTrue(first["complete_archive"])
            self.assertEqual(3, first["coverage"]["node_count"])
            self.assertEqual(1, first["coverage"]["opaque_node_count"])
            self.assertEqual(first["payload_sha256"], corpus.fingerprint(first))
            row = first["entries"][0]
            output = (root / "first" / row["mes_file"]).read_bytes()
            audit = json.loads(
                (root / "first" / row["audit_file"]).read_text(encoding="utf-8")
            )
            compiler.validate_audit(audit, output=output)
            self.assertEqual(row["entry_sha256"], audit["output"]["entry_sha256"])
            self.assertTrue((root / "first" / corpus.MANIFEST_NAME).is_file())

    def test_parallel_build_matches_serial_manifest(self) -> None:
        with tempfile.TemporaryDirectory() as raw_directory:
            root = Path(raw_directory)
            source = root / "source"
            source.mkdir()
            manifest = self.fixture(source)
            first_row = manifest["entries"][0]
            second_handoff = json.loads(
                (source / first_row["file"]).read_text(encoding="utf-8")
            )
            second_handoff["source_identity"]["entry"] = "SECOND.MES"
            second_handoff["payload_sha256"] = corpus.handoff_validator.fingerprint(
                second_handoff
            )
            second_file = "0001-second-mes.json"
            (source / second_file).write_text(
                json.dumps(second_handoff, sort_keys=True, separators=(",", ":"))
                + "\n",
                encoding="utf-8",
            )
            manifest["entries"].append(
                {
                    "position": 1,
                    "archive_index": 8,
                    "entry": "SECOND.MES",
                    "file": second_file,
                    "handoff_sha256": second_handoff["payload_sha256"],
                }
            )
            manifest["entry_count"] = 2
            manifest["source_entry_count"] = 2
            manifest["complete_archive"] = True
            manifest["payload_sha256"] = corpus.decompiler_corpus.fingerprint(manifest)
            serial = corpus.build(manifest, source, root / "serial", jobs=1)
            parallel = corpus.build(manifest, source, root / "parallel", jobs=2)

        self.assertEqual(serial, parallel)

    def test_refuses_existing_output_directory(self) -> None:
        with tempfile.TemporaryDirectory() as raw_directory:
            root = Path(raw_directory)
            source = root / "source"
            source.mkdir()
            manifest = self.fixture(source)
            output = root / "existing"
            output.mkdir()
            with self.assertRaisesRegex(corpus.NoopCorpusError, "already exists"):
                corpus.build(manifest, source, output)

    def test_failure_leaves_no_completion_manifest(self) -> None:
        with tempfile.TemporaryDirectory() as raw_directory:
            root = Path(raw_directory)
            source = root / "source"
            source.mkdir()
            manifest = self.fixture(source)
            manifest["entries"][0]["file"] = "missing.json"
            manifest["payload_sha256"] = corpus.decompiler_corpus.fingerprint(manifest)
            output = root / "failed"
            with self.assertRaisesRegex(corpus.NoopCorpusError, "missing"):
                corpus.build(manifest, source, output)
            self.assertTrue(output.is_dir())
            self.assertFalse((output / corpus.MANIFEST_NAME).exists())

    def test_rejects_rehashed_aggregate_change(self) -> None:
        with tempfile.TemporaryDirectory() as raw_directory:
            root = Path(raw_directory)
            source = root / "source"
            source.mkdir()
            document = corpus.build(self.fixture(source), source, root / "output")
        document["coverage"]["node_count"] += 1
        document["payload_sha256"] = corpus.fingerprint(document)
        with self.assertRaisesRegex(corpus.NoopCorpusError, "coverage"):
            corpus.validate(document)


if __name__ == "__main__":
    unittest.main()
