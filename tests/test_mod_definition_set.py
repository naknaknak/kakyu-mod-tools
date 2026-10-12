"""Tests for `tools/mod_definition_set.py` (mod event definition unit C):
the `kakyu_mod_definition_set/v1` transport file, built from a workspace
directory written by hand in a temporary directory (as
`tests/test_validate_workspace_definitions.py` builds one), validated,
published and read back.
"""
from __future__ import annotations

import copy
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

from tools import mod_definition_set as modset  # noqa: E402

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


class ModDefinitionSetTest(unittest.TestCase):
    def setUp(self) -> None:
        self._temp = tempfile.mkdtemp(prefix="moddef_set_")
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

    def _write_project(self, project_id: str = "moddef.set.workspace") -> None:
        project = {"project_id": project_id, "project_version": "0.1.0"}
        (self.root / "project.json").write_text(json.dumps(project, indent=2) + "\n", encoding="utf-8")

    def _build_valid_workspace(self) -> dict:
        _, record1 = self._write_definition("valid/new_event_plain.json")
        _, record2 = self._write_definition("valid/new_event_choice.json")
        self._write_manifest([record1, record2])
        self._write_project()
        return modset.build(self.root, NAMES_DIR, V4_DEFINITIONS_DIR)

    def test_build_from_workspace_produces_a_valid_set(self) -> None:
        document = self._build_valid_workspace()
        self.assertEqual(document["schema"], modset.SCHEMA)
        self.assertEqual(document["mod"], {"id": "samplemod", "revision": 1})
        self.assertEqual(document["source_project_id"], "moddef.set.workspace")
        self.assertEqual(len(document["definitions"]), 2)
        ids = [row["definition_id"] for row in document["definitions"]]
        self.assertEqual(ids, sorted(ids))
        self.assertEqual(len(ids), len(set(ids)))
        modset.validate(document, names_dir=NAMES_DIR, definitions_dir=V4_DEFINITIONS_DIR)

    def test_build_refuses_when_workspace_definitions_fail(self) -> None:
        _, record = self._write_definition("valid/new_event_plain.json")
        record["definition_sha256"] = "0" * 64
        self._write_manifest([record])
        self._write_project()
        with self.assertRaises(ValueError):
            modset.build(self.root, NAMES_DIR, V4_DEFINITIONS_DIR)

    def test_build_refuses_mixed_mod_revision(self) -> None:
        _, record1 = self._write_definition("valid/new_event_plain.json")
        _, record2 = self._write_definition(
            "valid/new_event_choice.json",
            mod={"id": "samplemod", "revision": 2},
        )
        self._write_manifest([record1, record2])
        self._write_project()
        with self.assertRaises(ValueError):
            modset.build(self.root, NAMES_DIR, V4_DEFINITIONS_DIR)

    def test_build_refuses_without_project_json(self) -> None:
        _, record = self._write_definition("valid/new_event_plain.json")
        self._write_manifest([record])
        with self.assertRaises(ValueError):
            modset.build(self.root, NAMES_DIR, V4_DEFINITIONS_DIR)

    def test_tampering_fails_with_its_message(self) -> None:
        document = self._build_valid_workspace()

        def expect_fail(mutate, needle: str) -> None:
            changed = copy.deepcopy(document)
            mutate(changed)
            with self.assertRaises(ValueError, msg=needle):
                modset.validate(changed)

        expect_fail(lambda d: d["definitions"][0]["document"].update(id="mod.samplemod.tampered"), "document field")
        expect_fail(lambda d: d["definitions"][0].update(definition_sha256="0" * 64), "definition_sha256")
        expect_fail(lambda d: d.update(unexpected_key=1), "extra key")

        unsorted = copy.deepcopy(document)
        unsorted["definitions"].reverse()
        with self.assertRaises(ValueError):
            modset.validate(unsorted)

        duplicate = copy.deepcopy(document)
        duplicate["definitions"].append(copy.deepcopy(duplicate["definitions"][0]))
        with self.assertRaises(ValueError):
            modset.validate(duplicate)

        expect_fail(lambda d: d["definitions"][0]["document"].update(contract_fingerprint="self"), "self fingerprint")
        expect_fail(
            lambda d: d["definitions"][0]["document"]["mod"].update(revision=d["mod"]["revision"] + 1),
            "different mod.revision",
        )
        expect_fail(lambda d: d.update(payload_sha256="f" * 64), "payload_sha256")

    def test_publish_refuses_an_existing_path_and_reopens_exactly(self) -> None:
        document = self._build_valid_workspace()
        with tempfile.TemporaryDirectory() as out_root:
            path = Path(out_root) / "set.json"
            modset.publish(path, document)
            self.assertEqual(document, modset.read(path))
            before = path.read_bytes()
            with self.assertRaises(FileExistsError):
                modset.publish(path, document)
            self.assertEqual(before, path.read_bytes())
            self.assertEqual([path], list(Path(out_root).iterdir()))

            tampered = json.loads(path.read_text(encoding="utf-8"))
            tampered["definitions"][0]["definition_sha256"] = "0" * 64
            path.write_text(json.dumps(tampered), encoding="utf-8")
            with self.assertRaises(ValueError):
                modset.read(path)

    def test_extract_writes_canonical_bytes_whose_hashes_match(self) -> None:
        document = self._build_valid_workspace()
        with tempfile.TemporaryDirectory() as out_root:
            path = Path(out_root) / "set.json"
            modset.publish(path, document)
            extract_dir = Path(out_root) / "extract"
            extract_dir.mkdir()
            for row in document["definitions"]:
                target = extract_dir / f"{row['definition_id']}.json"
                target.write_bytes(modset.workflow._json(row["document"]))
                self.assertEqual(hashlib.sha256(target.read_bytes()).hexdigest(), row["definition_sha256"])

    def test_main_build_and_validate_exit_codes(self) -> None:
        self._build_valid_workspace()
        with tempfile.TemporaryDirectory() as out_root:
            out_path = Path(out_root) / "set.json"
            build_code = self._run_main(["build", str(self.root), str(out_path), "--names", str(NAMES_DIR), "--definitions-dir", str(V4_DEFINITIONS_DIR)])
            self.assertEqual(build_code, 0)
            self.assertTrue(out_path.is_file())

            validate_code = self._run_main(["validate", str(out_path), "--names", str(NAMES_DIR), "--definitions-dir", str(V4_DEFINITIONS_DIR)])
            self.assertEqual(validate_code, 0)

            tampered_path = Path(out_root) / "tampered.json"
            tampered = json.loads(out_path.read_text(encoding="utf-8"))
            tampered["mod"]["revision"] = 99
            tampered_path.write_text(json.dumps(tampered), encoding="utf-8")
            fail_code = self._run_main(["validate", str(tampered_path)])
            self.assertEqual(fail_code, 1)

    def _run_main(self, argv: list[str]) -> int:
        old_argv = sys.argv
        sys.argv = ["mod_definition_set.py", *argv]
        try:
            modset.main()
            return 0
        except SystemExit as exit_signal:
            return int(exit_signal.code or 0)
        finally:
            sys.argv = old_argv


if __name__ == "__main__":
    unittest.main()
