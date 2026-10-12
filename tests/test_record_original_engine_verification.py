from __future__ import annotations

import hashlib
import json
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools" / "content_suite"))

from record_original_engine_verification import record_verification  # noqa: E402


KINDS = {
    "mes_equal_length_cp932": "mes.arc",
    "dat_pal_marker": "data.arc",
    "ogg_no_reencode_swap": "voice.arc",
}
PASS_OBSERVATIONS = {kind: "pass" for kind in KINDS}


class OriginalEngineVerificationResultTests(unittest.TestCase):
    def test_records_path_free_all_pass_result_without_promotion(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            batch = _write_batch(root / "batch")
            output = root / "result.json"
            result = record_verification(
                batch, output, PASS_OBSERVATIONS, "pass", attested=True
            )
            saved_text = output.read_text(encoding="utf-8")

        self.assertEqual("all_observations_passed", result["status"])
        self.assertEqual("not_performed", result["compatibility_promotion"])
        self.assertEqual("manual_observation_only", result["evidence_boundary"])
        self.assertNotIn(str(batch), saved_text)
        self.assertNotIn("prepared batch", saved_text)

    def test_records_fail_and_incomplete_without_inferring_pass(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            batch = _write_batch(root / "batch")
            failed = dict(PASS_OBSERVATIONS)
            failed["ogg_no_reencode_swap"] = "fail"
            failed_result = record_verification(
                batch, root / "failed.json", failed, "pass", attested=True
            )
            incomplete = dict(PASS_OBSERVATIONS)
            incomplete["dat_pal_marker"] = "not_observed"
            incomplete_result = record_verification(
                batch, root / "incomplete.json", incomplete, "pass", attested=True
            )

        self.assertEqual("failed", failed_result["status"])
        self.assertEqual("incomplete", incomplete_result["status"])

    def test_rejects_tampered_candidate_archive(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            batch = _write_batch(root / "batch")
            (batch / "candidates" / "voice.arc").write_bytes(b"tampered")
            with self.assertRaisesRegex(ValueError, "byte size changed"):
                record_verification(
                    batch,
                    root / "result.json",
                    PASS_OBSERVATIONS,
                    "pass",
                    attested=True,
                )

    def test_rejects_unsafe_candidate_manifest_path(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            batch = _write_batch(root / "batch")
            manifest_path = batch / "manifest.json"
            manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
            manifest["candidates"][0]["path"] = "candidates/../outside.arc"
            manifest_path.write_text(json.dumps(manifest), encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "unsafe candidate path"):
                record_verification(
                    batch,
                    root / "result.json",
                    PASS_OBSERVATIONS,
                    "pass",
                    attested=True,
                )

    def test_rejects_machine_path_disguised_as_target_entry(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            batch = _write_batch(root / "batch")
            manifest_path = batch / "manifest.json"
            manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
            manifest["candidates"][0]["target_entries"] = [r"D:\private\mes.arc"]
            manifest_path.write_text(json.dumps(manifest), encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "target entries"):
                record_verification(
                    batch,
                    root / "result.json",
                    PASS_OBSERVATIONS,
                    "pass",
                    attested=True,
                )

    def test_requires_attestation_and_new_output_outside_batch(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            batch = _write_batch(root / "batch")
            with self.assertRaisesRegex(ValueError, "attestation"):
                record_verification(
                    batch,
                    root / "result.json",
                    PASS_OBSERVATIONS,
                    "pass",
                    attested=False,
                )
            with self.assertRaisesRegex(ValueError, "outside"):
                record_verification(
                    batch,
                    batch / "result.json",
                    PASS_OBSERVATIONS,
                    "pass",
                    attested=True,
                )
            existing = root / "existing.json"
            existing.write_text("keep", encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "already exists"):
                record_verification(
                    batch,
                    existing,
                    PASS_OBSERVATIONS,
                    "pass",
                    attested=True,
                )
            self.assertEqual("keep", existing.read_text(encoding="utf-8"))


def _write_batch(batch: Path) -> Path:
    candidates_root = batch / "candidates"
    candidates_root.mkdir(parents=True)
    candidates = []
    for index, (kind, name) in enumerate(KINDS.items(), start=1):
        payload = (name.encode("ascii") + bytes([index])) * 4
        path = candidates_root / name
        path.write_bytes(payload)
        candidates.append(
            {
                "kind": kind,
                "path": f"candidates/{name}",
                "source_sha256": hashlib.sha256(b"source-" + payload).hexdigest(),
                "candidate_sha256": hashlib.sha256(payload).hexdigest(),
                "bytes": len(payload),
                "target_entries": [name.upper()],
                "expected_observation": f"observe {kind}",
                "compatibility": "original_engine_unverified",
            }
        )
    manifest = {
        "schema": "kakyu_original_engine_verification_batch/v1",
        "status": "prepared_unverified",
        "launcher_sha256": hashlib.sha256(b"launcher").hexdigest(),
        "launches_original_engine": False,
        "source_unchanged": True,
        "candidates": candidates,
    }
    (batch / "manifest.json").write_text(
        json.dumps(manifest, sort_keys=True), encoding="utf-8"
    )
    return batch


if __name__ == "__main__":
    unittest.main()
