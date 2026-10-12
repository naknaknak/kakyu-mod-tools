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

import audit_mes_decompiler_corpus as corpus_auditor  # noqa: E402
import validate_mes_analyzer_handoff as handoff_validator  # noqa: E402
from tests import test_decompile_mes_handoff as handoff_tests  # noqa: E402
from tests import test_prove_mes_shared_call_returns as library_tests  # noqa: E402


class MesDecompilerCorpusAuditTests(unittest.TestCase):
    def fixture(self, directory: Path) -> tuple[dict, dict]:
        handoff, _raw = handoff_tests.MesDecompilerLinearIrTests().fixture()
        handoff["source_identity"]["archive_sha256"] = "1" * 64
        handoff["payload_sha256"] = handoff_validator.fingerprint(handoff)
        handoff_name = "0000-test-mes.json"
        (directory / handoff_name).write_text(
            json.dumps(handoff, sort_keys=True, separators=(",", ":")) + "\n",
            encoding="utf-8",
        )
        manifest = {
            "schema": corpus_auditor.HANDOFF_SPOOL_SCHEMA,
            "handoff_schema": handoff_validator.HANDOFF_SCHEMA,
            "source_identity": {
                "archive": "mes.arc",
                "archive_sha256": "1" * 64,
            },
            "entry_count": 1,
            "source_entry_count": 1,
            "complete_archive": True,
            "library_audit": {
                "schema": corpus_auditor.shared_call_returns.LIBRARY_AUDIT_SCHEMA,
                "input_sha256": "0" * 64,
            },
            "entries": [
                {
                    "position": 0,
                    "archive_index": 7,
                    "entry": "TEST.MES",
                    "file": handoff_name,
                    "handoff_sha256": handoff["payload_sha256"],
                }
            ],
        }
        library = library_tests.MesSharedCallReturnProofTests().library_fixture()
        manifest["library_audit"]["input_sha256"] = (
            corpus_auditor.shared_call_returns.input_fingerprint(library)
        )
        manifest["payload_sha256"] = corpus_auditor.fingerprint(manifest)
        return manifest, library

    def test_runs_complete_phase5_chain_and_compacts_entry_result(self) -> None:
        with tempfile.TemporaryDirectory() as raw_directory:
            directory = Path(raw_directory)
            manifest, library = self.fixture(directory)
            document = corpus_auditor.audit(manifest, directory, library)

        self.assertEqual(corpus_auditor.CORPUS_AUDIT_SCHEMA, document["schema"])
        self.assertTrue(document["equivalent"])
        self.assertEqual(1, document["entry_count"])
        self.assertTrue(document["complete_archive"])
        self.assertEqual(3, document["coverage"]["linear_node_count"])
        self.assertEqual(11, document["coverage"]["linear_byte_count"])
        self.assertEqual(1, document["coverage"]["opaque_node_count"])
        self.assertNotIn("raw_hex", json.dumps(document, sort_keys=True))
        self.assertNotIn("pseudocode", document["entries"][0])
        self.assertTrue(all(document["invariants"].values()))

    def test_is_deterministic(self) -> None:
        with tempfile.TemporaryDirectory() as raw_directory:
            directory = Path(raw_directory)
            manifest, library = self.fixture(directory)
            first = corpus_auditor.audit(manifest, directory, library)
            second = corpus_auditor.audit(
                copy.deepcopy(manifest), directory, copy.deepcopy(library)
            )
        self.assertEqual(first, second)
        self.assertEqual(first["payload_sha256"], corpus_auditor.fingerprint(first))

    def test_entry_validation_reuse_preserves_exact_output(self) -> None:
        with tempfile.TemporaryDirectory() as raw_directory:
            directory = Path(raw_directory)
            manifest, library = self.fixture(directory)
            handoff = json.loads(
                (directory / manifest["entries"][0]["file"]).read_text(
                    encoding="utf-8"
                )
            )
            cached = corpus_auditor._audit_entry(
                manifest["entries"][0], handoff, library, True
            )
            uncached = corpus_auditor._audit_entry(
                manifest["entries"][0], handoff, library, False
            )
        self.assertEqual(uncached, cached)

    def test_process_pool_preserves_serial_order_and_exact_output(self) -> None:
        with tempfile.TemporaryDirectory() as raw_directory:
            directory = Path(raw_directory)
            manifest, library = self.fixture(directory)
            first_handoff = json.loads(
                (directory / manifest["entries"][0]["file"]).read_text(
                    encoding="utf-8"
                )
            )
            second_handoff = copy.deepcopy(first_handoff)
            second_handoff["source_identity"]["entry"] = "TEST2.MES"
            second_handoff["payload_sha256"] = handoff_validator.fingerprint(
                second_handoff
            )
            second_name = "0001-test2-mes.json"
            (directory / second_name).write_text(
                json.dumps(second_handoff, sort_keys=True, separators=(",", ":"))
                + "\n",
                encoding="utf-8",
            )
            manifest["entries"].append(
                {
                    "position": 1,
                    "archive_index": 8,
                    "entry": "TEST2.MES",
                    "file": second_name,
                    "handoff_sha256": second_handoff["payload_sha256"],
                }
            )
            manifest["entry_count"] = 2
            manifest["source_entry_count"] = 2
            manifest["payload_sha256"] = corpus_auditor.fingerprint(manifest)
            serial = corpus_auditor.audit(manifest, directory, library, jobs=1)
            parallel = corpus_auditor.audit(manifest, directory, library, jobs=2)

        self.assertEqual(serial, parallel)
        self.assertEqual(
            ["TEST.MES", "TEST2.MES"],
            [row["entry"] for row in parallel["entries"]],
        )

    def test_rejects_unbounded_process_count(self) -> None:
        with tempfile.TemporaryDirectory() as raw_directory:
            directory = Path(raw_directory)
            manifest, library = self.fixture(directory)
            with self.assertRaisesRegex(
                corpus_auditor.CorpusAuditError, "between 1 and 4"
            ):
                corpus_auditor.audit(manifest, directory, library, jobs=5)

    def test_parallel_worker_fails_closed_on_missing_handoff(self) -> None:
        with tempfile.TemporaryDirectory() as raw_directory:
            directory = Path(raw_directory)
            manifest, library = self.fixture(directory)
            manifest["entries"].append(
                {
                    "position": 1,
                    "archive_index": 8,
                    "entry": "MISSING.MES",
                    "file": "0001-missing-mes.json",
                    "handoff_sha256": "0" * 64,
                }
            )
            manifest["entry_count"] = 2
            manifest["source_entry_count"] = 2
            manifest["payload_sha256"] = corpus_auditor.fingerprint(manifest)
            with self.assertRaisesRegex(
                corpus_auditor.CorpusAuditError, "spool file is missing"
            ):
                corpus_auditor.audit(manifest, directory, library, jobs=2)

    def test_rejects_manifest_path_traversal(self) -> None:
        with tempfile.TemporaryDirectory() as raw_directory:
            manifest, _library = self.fixture(Path(raw_directory))
            manifest["entries"][0]["file"] = "../handoff.json"
            manifest["payload_sha256"] = corpus_auditor.fingerprint(manifest)
            with self.assertRaisesRegex(corpus_auditor.CorpusAuditError, "file changed"):
                corpus_auditor.validate_manifest(manifest)

    def test_rejects_handoff_payload_mismatch(self) -> None:
        with tempfile.TemporaryDirectory() as raw_directory:
            directory = Path(raw_directory)
            manifest, library = self.fixture(directory)
            manifest["entries"][0]["handoff_sha256"] = "2" * 64
            manifest["payload_sha256"] = corpus_auditor.fingerprint(manifest)
            with self.assertRaisesRegex(
                corpus_auditor.CorpusAuditError, "payload identity changed"
            ):
                corpus_auditor.audit(manifest, directory, library)

    def test_rejects_library_from_another_archive(self) -> None:
        with tempfile.TemporaryDirectory() as raw_directory:
            directory = Path(raw_directory)
            manifest, library = self.fixture(directory)
            library["archive_sha256"] = "3" * 64
            with self.assertRaisesRegex(
                corpus_auditor.CorpusAuditError, "does not match"
            ):
                corpus_auditor.audit(manifest, directory, library)

    def test_rejects_rehashed_aggregate_mutation(self) -> None:
        with tempfile.TemporaryDirectory() as raw_directory:
            directory = Path(raw_directory)
            manifest, library = self.fixture(directory)
            document = corpus_auditor.audit(manifest, directory, library)
        document["coverage"]["linear_node_count"] += 1
        document["payload_sha256"] = corpus_auditor.fingerprint(document)
        with self.assertRaisesRegex(corpus_auditor.CorpusAuditError, "aggregate"):
            corpus_auditor.validate(document)

    def test_rejects_rehashed_corpus_scope_mutation(self) -> None:
        with tempfile.TemporaryDirectory() as raw_directory:
            directory = Path(raw_directory)
            manifest, library = self.fixture(directory)
            document = corpus_auditor.audit(manifest, directory, library)
        document["source_entry_count"] = 2
        document["payload_sha256"] = corpus_auditor.fingerprint(document)
        with self.assertRaisesRegex(corpus_auditor.CorpusAuditError, "scope"):
            corpus_auditor.validate(document)

    def test_rejects_changed_library_payload_with_same_archive_identity(self) -> None:
        with tempfile.TemporaryDirectory() as raw_directory:
            directory = Path(raw_directory)
            manifest, library = self.fixture(directory)
            library["routines"][0]["body_offset"] += 1
            with self.assertRaisesRegex(
                corpus_auditor.CorpusAuditError, "payload identity changed"
            ):
                corpus_auditor.audit(manifest, directory, library)


if __name__ == "__main__":
    unittest.main()
