"""Tests for `tools/validate_workspace_definitions.py` (mod event
definition unit B, section D): a workspace `definitions/` directory built by
hand in a temporary directory, checked through `check_workspace`.
"""
from __future__ import annotations

import hashlib
import json
import shutil
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from tools.validate_workspace_definitions import check_workspace  # noqa: E402

FIXTURE_DIR = ROOT / "config" / "contracts" / "mod_event_definition_v1"
NAMES_DIR = ROOT / "config" / "contracts" / "event_names_v1"
V4_DEFINITIONS_DIR = ROOT / "config" / "event_definitions" / "v4"
CONTRACT_FINGERPRINT = (FIXTURE_DIR / "contract_fingerprint").read_text(encoding="utf-8").strip()
CELLS_FINGERPRINT = (ROOT / "config" / "contracts" / "state_cells_v1" / "cells_fingerprint").read_text(encoding="utf-8").strip()


def _record(document: dict, document_bytes: bytes, *, target_id: str = "") -> dict:
    sha = hashlib.sha256(document_bytes).hexdigest()
    return {
        "kind": "mod_event_definition",
        "schema": "kakyu_mod_event_definition/v1",
        "definition_id": document["id"],
        "definition_kind": document["kind"],
        "mod_id": document["mod"]["id"],
        "mod_revision": document["mod"]["revision"],
        "target_id": target_id,
        "definition_sha256": sha,
        "definition_path": f"definitions/{sha}-{document['id']}.json",
        "contract_fingerprint": document["contract_fingerprint"],
        "cells_fingerprint": document["cells_fingerprint"],
        "compatibility": "remake_only",
        "text_encoding": "utf8",
    }


class ValidateWorkspaceDefinitionsTest(unittest.TestCase):
    def setUp(self) -> None:
        self._temp = tempfile.mkdtemp(prefix="moddef_workspace_")
        self.root = Path(self._temp)
        (self.root / "definitions").mkdir()

    def tearDown(self) -> None:
        shutil.rmtree(self._temp, ignore_errors=True)

    def _write_definition(self, source_relative: str, **overrides) -> tuple[dict, dict]:
        document = json.loads((FIXTURE_DIR / source_relative).read_text(encoding="utf-8"))
        document["contract_fingerprint"] = CONTRACT_FINGERPRINT
        document["cells_fingerprint"] = CELLS_FINGERPRINT
        document.update(overrides)
        document_bytes = (json.dumps(document, ensure_ascii=False, indent=2) + "\n").encode("utf-8")
        target_id = document.get("target", {}).get("id", "") if document.get("kind") == "override" else ""
        record = _record(document, document_bytes, target_id=target_id)
        (self.root / record["definition_path"]).write_bytes(document_bytes)
        return document, record

    def _write_manifest(self, records: list[dict]) -> None:
        manifest = {
            "schema": "kakyu_content_overlay/v1",
            "editor_version": "0.347.0",
            "replacements": [],
            "projections": [],
            "definitions": records,
        }
        (self.root / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")

    def test_valid_workspace_passes(self) -> None:
        _, record = self._write_definition("valid/new_event_plain.json")
        self._write_manifest([record])
        result = check_workspace(self.root, NAMES_DIR, V4_DEFINITIONS_DIR)
        self.assertTrue(result["ok"], result)
        self.assertEqual(result["definitions"], 1)
        self.assertEqual(result["failures"], [])

    def test_hash_mismatch_fails_at_manifest_stage(self) -> None:
        _, record = self._write_definition("valid/new_event_plain.json")
        record["definition_sha256"] = "0" * 64
        self._write_manifest([record])
        result = check_workspace(self.root, NAMES_DIR, V4_DEFINITIONS_DIR)
        self.assertFalse(result["ok"])
        self.assertEqual(len(result["failures"]), 1)
        self.assertEqual(result["failures"][0]["stage"], "manifest")

    def test_foreign_mod_id_fails_at_manifest_stage(self) -> None:
        first_document, first_record = self._write_definition("valid/new_event_plain.json")
        second_document, second_record = self._write_definition(
            "valid/new_event_choice.json",
            mod={"id": "othermod", "revision": 1},
            id="mod.othermod.new_event_choice",
        )
        self._write_manifest([first_record, second_record])
        result = check_workspace(self.root, NAMES_DIR, V4_DEFINITIONS_DIR)
        self.assertFalse(result["ok"])
        reasons = {failure["reason"] for failure in result["failures"]}
        self.assertIn("mixed_mod_id", reasons)
        stages = {failure["stage"] for failure in result["failures"]}
        self.assertEqual(stages, {"manifest"})

    def test_contract_failure_fails_at_contract_stage(self) -> None:
        document, record = self._write_definition("valid/new_event_plain.json")
        # Overwrite the stored bytes with a `{other}` placeholder the shape
        # checks (A.1) accept but the full contract validator rejects.
        document["dialogue"][1]["text"] = "See {other} here."
        document_bytes = (json.dumps(document, ensure_ascii=False, indent=2) + "\n").encode("utf-8")
        sha = hashlib.sha256(document_bytes).hexdigest()
        # The manifest record's own hash must still match its stored bytes to
        # pass the manifest stage before the contract stage is reached.
        (self.root / record["definition_path"]).unlink()
        record["definition_sha256"] = sha
        record["definition_path"] = f"definitions/{sha}-{document['id']}.json"
        (self.root / record["definition_path"]).write_bytes(document_bytes)
        self._write_manifest([record])
        result = check_workspace(self.root, NAMES_DIR, V4_DEFINITIONS_DIR)
        self.assertFalse(result["ok"])
        self.assertEqual(len(result["failures"]), 1)
        self.assertEqual(result["failures"][0]["stage"], "contract")
        self.assertEqual(result["failures"][0]["reason"], "bad_placeholder")


if __name__ == "__main__":
    unittest.main()
