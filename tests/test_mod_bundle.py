"""Tests for `tools/mod_bundle.py` (WD-10): the `kakyu_mod_bundle/v1` file, built
from a workspace written by hand in a temporary directory (as
`tests/test_mod_definition_set.py` writes one) over a synthetic `mes.arc`,
validated against its source, extracted, published and read back - and the
shared `payload_values.publish_new_document` helper with its three wrappers.
"""
from __future__ import annotations

import contextlib
import copy
import hashlib
import io
import json
import os
from pathlib import Path
import re
import shutil
import sys
import tempfile
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
sys.path.insert(0, str(ROOT / "tests"))
import authored_mod_delta as delta  # noqa: E402
import mes_authoring_workflow as workflow  # noqa: E402
import mod_bundle  # noqa: E402
import mod_definition_set as modset  # noqa: E402
import payload_values  # noqa: E402
import prepare_mes_editable_ir as editable_ir  # noqa: E402
import test_mes_command03_audit as arc_tests  # noqa: E402
import test_mod_definition_set as set_tests  # noqa: E402
import test_plan_mes_registered_definition_call_edit as call_plan_tests  # noqa: E402

NAMES_DIR = set_tests.NAMES_DIR
DEFINITIONS_DIR = set_tests.V4_DEFINITIONS_DIR

# One state write and one message each; the three differ in the message only.
SOURCE_A = bytes.fromhex("0100000000000000031e0101ff000182a00000")
SOURCE_B = bytes.fromhex("0100000000000000031e0101ff000182a20000")
SOURCE_C = bytes.fromhex("0100000000000000031e0101ff000182a40000")
# Two messages (code offsets 0 and 4); the first is relocated by the delta.
SOURCE_D = ((2).to_bytes(4, "little") + bytes(4) + (4).to_bytes(4, "little")
            + bytes.fromhex("0182a000") + bytes.fromhex("0182a2000b01ff") + (4).to_bytes(4, "little") + b"\0")
# A registered-definition call (selector 3 -> 4) over a DEF_MAIN.MES registry.
SOURCE_E = bytes.fromhex("0100000000000000110203ff000182a00000")
MESSAGE_A, MESSAGE_B, MESSAGE_C = (bytes.fromhex(raw) for raw in ("82a0", "82a2", "82a4"))


def _sha(payload: bytes) -> str:
    return hashlib.sha256(payload).hexdigest()


def _edit(offset: int, raw: bytes, text: str) -> dict:
    return {"source_offset": offset, "raw_sha256": _sha(raw), "text": text}


class Fixture:
    """The synthetic ARC, the compiled authoring evidence and workspace writers."""

    def __init__(self, root: Path) -> None:
        self.root = root
        self.registry_payload = call_plan_tests.MesRegisteredDefinitionCallEditPlanTests.registry_payload(3, 4)
        self.entries = {
            "EVENT_A.MES": SOURCE_A, "EVENT_B.MES": SOURCE_B, "EVENT_C.MES": SOURCE_C,
            "EVENT_D.MES": SOURCE_D, "EVENT_E.MES": SOURCE_E, "DEF_MAIN.MES": self.registry_payload,
        }
        self.arc_dir = root / "original"
        self.arc_dir.mkdir()
        self.arc_path = self.arc_dir / "mes.arc"
        arc_tests._write_arc(self.arc_path, sorted(self.entries.items()))
        self.archive_sha = _sha(self.arc_path.read_bytes())
        self.compiled = {
            "EVENT_A.MES": self._state("EVENT_A.MES", 2),
            "EVENT_B.MES": self._state("EVENT_B.MES", 3),
            "EVENT_D.MES": self._relocation("EVENT_D.MES"),
            "EVENT_E.MES": self._registered_call("EVENT_E.MES"),
        }

    def identity(self, entry: str) -> dict:
        return {"archive": "mes.arc", "entry": entry, "source_kind": "original_arc", "archive_sha256": self.archive_sha}

    def read_entry(self, name: str) -> bytes:
        for stored, payload in self.entries.items():
            if stored.casefold() == str(name).casefold():
                return payload
        raise KeyError(name)

    def _state(self, entry: str, value: int) -> dict[str, bytes]:
        files = workflow.analyze(self.entries[entry], self.identity(entry))
        operation = workflow.state_controls(json.loads(files["editable.json"]))[0]["operation"]
        operation["value"] = value
        return workflow.compile_sequence(files, [operation])

    def _relocation(self, entry: str) -> dict[str, bytes]:
        files = workflow.analyze(self.entries[entry], self.identity(entry))
        operation = dict(workflow.message_controls(json.loads(files["editable.json"]))[0]["operation"], text="変更確認")
        return workflow.compile_sequence(files, [operation])

    def _registered_call(self, entry: str) -> dict[str, bytes]:
        proof = workflow.registry_prover.prove_entry(self.registry_payload, {
            "archive": "mes.arc", "archive_sha256": self.archive_sha, "entry": "DEF_MAIN.MES",
            "entry_sha256": _sha(self.registry_payload)})
        files = workflow.analyze(self.entries[entry], self.identity(entry), proof)
        operation = dict(workflow.call_controls(json.loads(files["editable.json"]), files)[0]["operation"], selector=4)
        return workflow.compile_sequence(files, [operation])

    def workspace(self, name: str) -> "Workspace":
        return Workspace(self, self.root / name)


class Workspace:
    """A workspace directory written by hand: project, manifest, authoring
    bundles, replacement and projection files, definition files."""

    def __init__(self, fixture: Fixture, root: Path) -> None:
        self.fixture = fixture
        self.root = root
        self.replacements: list[dict] = []
        self.projections: list[dict] = []
        self.definitions: list[dict] = []
        self.archive_sha = fixture.archive_sha
        (root / "definitions").mkdir(parents=True)

    def replace(self, entry: str, *, authored: bool = True, files: dict | None = None,
                archive: str = "mes.arc") -> dict:
        files = files if files is not None else self.fixture.compiled[entry]
        output = files["output.mes"]
        if authored:
            name = _sha(entry.encode() + output)[:32]
            workflow.publish(self.root / "authoring" / name, files)
        relative = f"replacements/{archive}/{_sha(output)}-{entry}"
        (self.root / relative).parent.mkdir(parents=True, exist_ok=True)
        (self.root / relative).write_bytes(output)
        record = {
            "base_archive_sha256": self.fixture.archive_sha,
            "original_entry_sha256": _sha(self.fixture.entries[entry]), "replacement_sha256": _sha(output),
            "target_archive": archive, "target_entry": entry, "replacement_path": relative,
            "compatibility": "remake_only", "text_encoding": "not_applicable",
        }
        self.replacements.append(record)
        return record

    def project(self, entry: str, edits: list[dict], *, archive: str = "mes.arc") -> dict:
        original = _sha(self.fixture.entries[entry])
        document = {"schema": mod_bundle.PROJECTION_SCHEMA, "base_archive_sha256": self.fixture.archive_sha,
                    "entry_sha256": original, "target_archive": archive, "target_entry": entry, "edits": edits}
        payload = (json.dumps(document, ensure_ascii=False, indent=2) + "\n").encode("utf-8")
        relative = f"projections/mes/{_sha(payload)}-{entry}.json"
        (self.root / relative).parent.mkdir(parents=True, exist_ok=True)
        (self.root / relative).write_bytes(payload)
        record = {
            "kind": "mes_text", "schema": mod_bundle.PROJECTION_SCHEMA,
            "base_archive_sha256": self.fixture.archive_sha, "original_entry_sha256": original,
            "projection_sha256": _sha(payload), "target_archive": archive, "target_entry": entry,
            "projection_path": relative, "compatibility": "remake_only", "text_encoding": "utf8",
        }
        self.projections.append(record)
        return record

    def define(self, *relatives: str) -> None:
        for relative in relatives:
            document = json.loads((set_tests.FIXTURE_DIR / relative).read_text(encoding="utf-8"))
            document["contract_fingerprint"] = set_tests.CONTRACT_FINGERPRINT
            document["cells_fingerprint"] = set_tests.CELLS_FINGERPRINT
            payload = (json.dumps(document, ensure_ascii=False, indent=2) + "\n").encode("utf-8")
            target = document.get("target", {}).get("id", "") if document.get("kind") == "override" else ""
            record = set_tests._record(document, payload, target_id=target)
            (self.root / record["definition_path"]).write_bytes(payload)
            self.definitions.append(record)

    def write(self, project_id: str = "bundle.test.workspace") -> "Workspace":
        project = {
            "schema": "kakyu_content_project/v1", "project_id": project_id, "project_version": "0.1.0",
            "source_content_set": {"profile_id": "test", "fingerprint_sha256": "0" * 64, "archives": [
                {"archive": "mes.arc", "sha256": self.archive_sha, "required": True}]},
        }
        manifest = {"schema": "kakyu_content_overlay/v1", "editor_version": "0.377.0",
                    "replacements": self.replacements, "projections": self.projections,
                    "definitions": self.definitions}
        (self.root / "project.json").write_text(json.dumps(project, indent=2) + "\n", encoding="utf-8")
        (self.root / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
        return self

    def build(self, **kwargs) -> dict:
        kwargs.setdefault("names_dir", NAMES_DIR)
        kwargs.setdefault("definitions_dir", DEFINITIONS_DIR)
        return mod_bundle.build(self.root, self.fixture.read_entry, self.archive_sha, **kwargs)


def _rehash(bundle: dict) -> dict:
    bundle["payload_sha256"] = mod_bundle.fingerprint(bundle)
    return bundle


def _fix_delta_row(row: dict) -> None:
    """Re-sign a delta row's document after a change, as a forger would."""
    row["document"]["payload_sha256"] = delta.fingerprint(row["document"])
    row["delta_sha256"] = _sha(workflow._json(row["document"]))


class BundleCase(unittest.TestCase):
    fixture: Fixture

    @classmethod
    def setUpClass(cls) -> None:
        cls._temp = tempfile.mkdtemp(prefix="mod_bundle_")
        cls.fixture = Fixture(Path(cls._temp))
        workspace = cls.fixture.workspace("base")
        workspace.replace("EVENT_A.MES")
        workspace.replace("EVENT_B.MES")
        workspace.project("EVENT_B.MES", [_edit(6, MESSAGE_B, "번들 확인 B")])
        workspace.project("EVENT_C.MES", [_edit(6, MESSAGE_C, "번들 확인 C")])
        workspace.define("valid/new_event_plain.json", "valid/new_event_choice.json")
        cls.base_workspace = workspace.write()
        cls.base = workspace.build()
        cls.dependency_workspace = cls.fixture.workspace("dependency")
        cls.dependency_workspace.replace("EVENT_E.MES")
        cls.dependency_workspace.write()
        cls.with_dependency = cls.dependency_workspace.build(mod_id="depmod")

    @classmethod
    def tearDownClass(cls) -> None:
        shutil.rmtree(cls._temp, ignore_errors=True)

    def validate(self, bundle: dict) -> None:
        mod_bundle.validate(bundle, names_dir=NAMES_DIR, definitions_dir=DEFINITIONS_DIR)

    def assert_refused(self, mutate, pattern: str, *, bundle: dict | None = None, rehash: bool = True) -> None:
        changed = copy.deepcopy(bundle if bundle is not None else self.base)
        mutate(changed)
        if rehash:
            _rehash(changed)
        with self.assertRaisesRegex(ValueError, pattern):
            self.validate(changed)


class BuildTests(BundleCase):
    def test_a_whole_workspace_becomes_one_valid_bundle(self) -> None:
        bundle = self.base
        self.assertEqual(mod_bundle.SCHEMA, bundle["schema"])
        self.assertEqual({"id": "samplemod", "revision": 1}, bundle["mod"])
        self.assertEqual("bundle.test.workspace", bundle["source_project_id"])
        self.assertEqual({"archive": "mes.arc", "archive_sha256": self.fixture.archive_sha,
                          "source_kind": "original_arc"}, bundle["source"])
        self.assertEqual([], bundle["dependencies"])
        self.assertEqual(["EVENT_A.MES", "EVENT_B.MES"], [row["entry"] for row in bundle["deltas"]])
        self.assertEqual(["EVENT_C.MES"], [row["entry"] for row in bundle["text_projections"]])
        self.assertEqual(2, bundle["definition_set"]["definition_count"])
        self.assertEqual(mod_bundle.COMPATIBILITY, bundle["compatibility"])
        self.validate(bundle)
        mod_bundle.check_source(bundle, self.fixture.read_entry, self.fixture.archive_sha)

    def test_a_projection_on_a_replaced_entry_becomes_the_deltas_text_edits(self) -> None:
        by_entry = {row["entry"]: row["document"] for row in self.base["deltas"]}
        self.assertEqual([], by_entry["EVENT_A.MES"]["text_edits"])
        self.assertEqual([_edit(6, MESSAGE_B, "번들 확인 B")], by_entry["EVENT_B.MES"]["text_edits"])
        self.assertEqual([_edit(6, MESSAGE_C, "번들 확인 C")], self.base["text_projections"][0]["text_edits"])

    def test_every_delta_reconstructs_against_the_matching_original(self) -> None:
        for row in self.base["deltas"]:
            entry = row["entry"]
            files = delta.reconstruct(row["document"], self.fixture.read_entry(entry), self.fixture.identity(entry))
            self.assertEqual(self.fixture.compiled[entry], files)

    def test_the_build_is_deterministic(self) -> None:
        again = self.base_workspace.build()
        self.assertEqual(workflow._json(self.base), workflow._json(again))

    def test_the_bundle_leaks_no_original_payload_or_evidence(self) -> None:
        serialized = workflow._json(self.base)
        for entry, files in self.fixture.compiled.items():
            if entry in ("EVENT_A.MES", "EVENT_B.MES"):
                self.assertNotIn(self.fixture.read_entry(entry).hex().encode(), serialized)
                self.assertNotIn(files["output.mes"].hex().encode(), serialized)
        for forbidden in (b'"raw_hex"', b'"handoff"', b'"source_path"'):
            self.assertNotIn(forbidden, serialized)
        self.assertIn("번들 확인 B".encode(), serialized)
        self.assertIn("번들 확인 C".encode(), serialized)

    def test_the_canonical_form_is_the_delta_and_set_form(self) -> None:
        bundle = self.base
        self.assertEqual(delta.fingerprint(bundle), bundle["payload_sha256"])
        self.assertEqual(modset.fingerprint(bundle), bundle["payload_sha256"])
        self.assertNotEqual(payload_values.fingerprint(bundle), bundle["payload_sha256"])
        body = {key: value for key, value in bundle.items() if key != "payload_sha256"}
        self.assertEqual(bundle["payload_sha256"], _sha(workflow._json(body)))
        self.assertTrue(workflow._json(body).endswith(b"\n"))
        self.assertEqual(workflow._json(body)[:-1], payload_values.canonical_payload_bytes(bundle))
        for row in bundle["deltas"]:
            self.assertEqual(row["delta_sha256"], _sha(workflow._json(row["document"])))
        self.assertEqual(bundle["definition_set"]["set_sha256"],
                         _sha(workflow._json(bundle["definition_set"]["document"])))

    def test_a_bundle_with_a_dependency_carries_it_once(self) -> None:
        self.assertEqual([{"entry": "DEF_MAIN.MES", "entry_sha256": _sha(self.fixture.registry_payload)}],
                         self.with_dependency["dependencies"])
        self.validate(self.with_dependency)
        mod_bundle.check_source(self.with_dependency, self.fixture.read_entry, self.fixture.archive_sha)

    def test_a_deltas_only_bundle_needs_and_declares_its_mod_identity(self) -> None:
        workspace = self.fixture.workspace("deltas_only")
        workspace.replace("EVENT_A.MES")
        workspace.write()
        with self.assertRaisesRegex(ValueError, "needs a mod id"):
            workspace.build()
        bundle = workspace.build(mod_id="onlydeltas")
        self.assertEqual({"id": "onlydeltas", "revision": 1}, bundle["mod"])
        self.assertIsNone(bundle["definition_set"])
        self.assertEqual({"id": "onlydeltas", "revision": 4},
                         workspace.build(mod_id="onlydeltas", mod_revision=4)["mod"])
        self.validate(bundle)

    def test_a_definitions_only_bundle_takes_the_sets_identity(self) -> None:
        workspace = self.fixture.workspace("definitions_only")
        workspace.define("valid/new_event_plain.json")
        workspace.write()
        bundle = workspace.build()
        self.assertEqual({"id": "samplemod", "revision": 1}, bundle["mod"])
        self.assertEqual(([], []), (bundle["deltas"], bundle["text_projections"]))
        self.assertEqual(1, bundle["definition_set"]["definition_count"])
        self.validate(bundle)
        self.assertEqual("samplemod", workspace.build(mod_id="samplemod", mod_revision=1)["mod"]["id"])
        for kwargs in ({"mod_id": "another"}, {"mod_revision": 2}):
            with self.assertRaisesRegex(ValueError, "disagrees with the workspace definitions"):
                workspace.build(**kwargs)

    def test_a_translation_only_bundle_builds(self) -> None:
        workspace = self.fixture.workspace("text_only")
        workspace.project("EVENT_C.MES", [_edit(6, MESSAGE_C, "번들 확인 C")])
        workspace.write()
        bundle = workspace.build(mod_id="textonly")
        self.assertEqual(([], 1, None), (bundle["deltas"], len(bundle["text_projections"]), bundle["definition_set"]))
        self.validate(bundle)

    def test_a_projection_beside_a_relocated_message_is_carried(self) -> None:
        workspace = self.fixture.workspace("relocation_ok")
        workspace.replace("EVENT_D.MES")
        workspace.project("EVENT_D.MES", [_edit(4, MESSAGE_B, "번들 확인 D")])
        workspace.write()
        bundle = workspace.build(mod_id="relocmod")
        self.assertEqual("replace_message", bundle["deltas"][0]["document"]["operations"][-1]["kind"])
        self.assertEqual([_edit(4, MESSAGE_B, "번들 확인 D")], bundle["deltas"][0]["document"]["text_edits"])

    def test_the_link_takes_an_authoring_bundle_whose_summary_binds_the_entry_and_hashes(self) -> None:
        workspace = self.fixture.workspace("stale_authoring")
        record = workspace.replace("EVENT_A.MES")
        # A stale preview of another edit of the same entry, and a bundle of another entry.
        stale = self.fixture._state("EVENT_A.MES", 5)
        workflow.publish(workspace.root / "authoring" / ("0" * 32), stale)
        workflow.publish(workspace.root / "authoring" / ("1" * 32), self.fixture.compiled["EVENT_B.MES"])
        workspace.write()
        bundle = workspace.build(mod_id="stalemod")
        self.assertEqual(record["replacement_sha256"], bundle["deltas"][0]["output_entry_sha256"])

    def test_authoring_bundles_naming_different_operations_are_ambiguous(self) -> None:
        workspace = self.fixture.workspace("ambiguous")
        workspace.replace("EVENT_A.MES")
        workspace.write()
        genuine = next((workspace.root / "authoring").iterdir())
        manifest = json.loads((genuine / "manifest.json").read_bytes())
        manifest["summary"]["operations"] = [dict(manifest["summary"]["operations"][0], value=9)]
        twin = workspace.root / "authoring" / ("0" * 32)
        twin.mkdir()
        (twin / "manifest.json").write_bytes(workflow._json(manifest))
        with self.assertRaisesRegex(ValueError, "different operations"):
            workspace.build(mod_id="ambiguous")


class BuildRefusalTests(BundleCase):
    def assert_build_refused(self, workspace: Workspace, pattern: str, **kwargs) -> None:
        with self.assertRaisesRegex(ValueError, pattern):
            workspace.build(mod_id="refusedmod", **kwargs)

    def test_a_raw_unauthored_mes_replacement_is_refused_naming_it(self) -> None:
        workspace = self.fixture.workspace("raw_mes")
        workspace.replace("EVENT_A.MES", authored=False)
        self.assert_build_refused(workspace.write(), "mes.arc/EVENT_A.MES has no linked authoring bundle")

    def test_a_replacement_outside_mes_arc_is_refused_naming_it(self) -> None:
        workspace = self.fixture.workspace("raw_media")
        workspace.replace("EVENT_A.MES", authored=False, archive="mmo.arc")
        self.assert_build_refused(workspace.write(), "mmo.arc/EVENT_A.MES is outside mes.arc")

    def test_a_projection_outside_mes_arc_is_refused_naming_it(self) -> None:
        workspace = self.fixture.workspace("foreign_projection")
        workspace.project("EVENT_C.MES", [_edit(6, MESSAGE_C, "번들 확인 C")], archive="data.arc")
        self.assert_build_refused(workspace.write(), "data.arc/EVENT_C.MES is outside mes.arc")

    def test_an_empty_workspace_is_refused(self) -> None:
        self.assert_build_refused(self.fixture.workspace("empty").write(), "nothing to carry")

    def test_a_projection_on_the_relocated_message_is_refused_naming_entry_and_offset(self) -> None:
        workspace = self.fixture.workspace("relocation_overlap")
        workspace.replace("EVENT_D.MES")
        workspace.project("EVENT_D.MES", [_edit(0, MESSAGE_A, "번들 확인 D")])
        self.assert_build_refused(
            workspace.write(), r"mes\.arc/EVENT_D\.MES: the projection edits the message at 0x0 that the replacement relocates")

    def test_a_missing_or_unbound_workspace_is_refused(self) -> None:
        missing = self.fixture.workspace("no_project")
        missing.replace("EVENT_A.MES")
        missing.write()
        (missing.root / "project.json").unlink()
        self.assert_build_refused(missing, "project.json is missing")
        other = self.fixture.workspace("other_archive")
        other.replace("EVENT_A.MES")
        other.write()
        other.archive_sha = "c" * 64
        self.assert_build_refused(other, "does not bind this mes.arc")

    def test_records_that_disagree_with_their_files_or_the_archive_are_refused(self) -> None:
        workspace = self.fixture.workspace("changed_replacement")
        record = workspace.replace("EVENT_A.MES")
        workspace.write()
        (workspace.root / record["replacement_path"]).write_bytes(b"changed")
        self.assert_build_refused(workspace, "file hash mismatch")
        stale = self.fixture.workspace("stale_original")
        record = stale.replace("EVENT_A.MES")
        record["original_entry_sha256"] = "d" * 64
        self.assert_build_refused(stale.write(), "original entry differs from the archive")
        foreign = self.fixture.workspace("foreign_base")
        foreign.replace("EVENT_A.MES")["base_archive_sha256"] = "e" * 64
        self.assert_build_refused(foreign.write(), "belongs to another archive")
        unsafe = self.fixture.workspace("unsafe_path")
        unsafe.replace("EVENT_A.MES")["replacement_path"] = "../outside.bin"
        self.assert_build_refused(unsafe.write(), "unsafe replacement path")

    def test_an_authoring_bundle_of_another_archive_is_refused(self) -> None:
        other_files = workflow.analyze(SOURCE_A, dict(self.fixture.identity("EVENT_A.MES"), archive_sha256="f" * 64))
        operation = workflow.state_controls(json.loads(other_files["editable.json"]))[0]["operation"]
        operation["value"] = 2
        compiled = workflow.compile_sequence(other_files, [operation])
        workspace = self.fixture.workspace("foreign_authoring")
        workspace.replace("EVENT_A.MES", files=compiled)
        self.assert_build_refused(workspace.write(), "authoring bundle belongs to another archive")

    def test_a_workspace_that_changes_during_the_build_is_refused(self) -> None:
        workspace = self.fixture.workspace("changing")
        workspace.replace("EVENT_A.MES")
        workspace.write()
        real_build = delta.build

        def touch_then_build(*args, **kwargs):
            with (workspace.root / "manifest.json").open("ab") as stream:
                stream.write(b"\n")
            return real_build(*args, **kwargs)

        with mock.patch.object(delta, "build", side_effect=touch_then_build):
            self.assert_build_refused(workspace, "changed during the build")


class ValidateTests(BundleCase):
    def test_an_unsupported_schema_version_is_refused_by_name_first(self) -> None:
        self.assert_refused(lambda d: d.update(schema="kakyu_mod_bundle/v2"), "schema version is unsupported")
        self.assert_refused(lambda d: d.update(schema="kakyu_mod_bundle/v2", brand_new_field=[]),
                            "schema version is unsupported")
        self.assert_refused(lambda d: d.pop("schema"), "schema version is unsupported")
        with self.assertRaisesRegex(ValueError, "schema or fields changed"):
            self.validate([])

    def test_extra_missing_and_changed_fields_are_refused(self) -> None:
        self.assert_refused(lambda d: d.update(raw_hex="00"), "schema or fields changed")
        self.assert_refused(lambda d: d.pop("text_projections"), "schema or fields changed")
        self.assert_refused(lambda d: d.update(payload_sha256="f" * 64), "payload changed", rehash=False)
        self.assert_refused(lambda d: d.update(payload_sha256="F" * 64), "payload_sha256 is invalid", rehash=False)
        self.assert_refused(lambda d: d["mod"].update(owner="x"), "mod fields changed")
        self.assert_refused(lambda d: d["source"].update(path="C:/x"), "source must name the original mes.arc")

    def test_an_incompatible_core_is_refused(self) -> None:
        for compatibility in (dict(mod_bundle.COMPATIBILITY, minimum_core="0.378.0"),
                              dict(mod_bundle.COMPATIBILITY, minimum_core="0.329.0"), {}):
            self.assert_refused(lambda d: d.update(compatibility=compatibility), "compatibility requirement")

    def test_the_identity_and_source_blocks_are_checked(self) -> None:
        self.assert_refused(lambda d: d["mod"].update(id="Bad Id"), "mod id pattern")
        self.assert_refused(lambda d: d["mod"].update(revision=0), "mod.revision")
        self.assert_refused(lambda d: d["mod"].update(revision=True), "mod.revision")
        for project_id in ("C:\\workspace", "../workspace", "", ".hidden"):
            self.assert_refused(lambda d: d.update(source_project_id=project_id), "not a project id")
        self.assert_refused(lambda d: d["source"].update(archive="mmo.arc"), "original mes.arc")
        self.assert_refused(lambda d: d["source"].update(source_kind="local"), "original mes.arc")
        self.assert_refused(lambda d: d["source"].update(archive_sha256="abc"), "original mes.arc")

    def test_original_payload_and_evidence_keys_are_refused_at_every_level(self) -> None:
        self.assert_refused(lambda d: d["deltas"][0].update(handoff={}), "delta row fields changed")
        self.assert_refused(lambda d: d["text_projections"][0].update(source_path="C:/x"),
                            "text projection row fields changed")
        self.assert_refused(lambda d: d["text_projections"][0]["text_edits"][0].update(raw_hex="82a4"),
                            "text edit is invalid")
        self.assert_refused(lambda d: d["definition_set"].update(raw_hex="00"), "definition_set fields changed")

        def forge_member(d: dict) -> None:
            d["deltas"][0]["document"]["raw_hex"] = "00"
            _fix_delta_row(d["deltas"][0])

        self.assert_refused(forge_member, "Delta schema or fields changed")

    def test_entries_are_unique_case_insensitively_across_deltas_and_text_rows(self) -> None:
        def lowercase_twin(d: dict) -> None:
            twin = copy.deepcopy(d["deltas"][0])
            twin["entry"] = twin["document"]["source"]["entry"] = twin["entry"].lower()
            _fix_delta_row(twin)
            d["deltas"].append(twin)

        def text_twin(d: dict) -> None:
            d["text_projections"].insert(0, {
                "entry": "EVENT_A.MES", "source_entry_sha256": d["deltas"][0]["source_entry_sha256"],
                "text_edits": [_edit(6, MESSAGE_A, "번들 확인 A")]})

        def text_lowercase_twin(d: dict) -> None:
            d["text_projections"].append(dict(copy.deepcopy(d["text_projections"][0]), entry="event_c.mes"))

        self.assert_refused(lowercase_twin, "more than once")
        self.assert_refused(text_twin, "more than once")
        self.assert_refused(text_lowercase_twin, "more than once")
        self.assert_refused(lambda d: d["deltas"].append(copy.deepcopy(d["deltas"][1])),
                            "sorted by entry with no duplicate")
        self.assert_refused(lambda d: d["deltas"].reverse(), "sorted by entry with no duplicate")

    def test_delta_rows_must_agree_with_their_documents(self) -> None:
        self.assert_refused(lambda d: d["deltas"][0].update(source_entry_sha256="f" * 64), "disagrees with its document")
        self.assert_refused(lambda d: d["deltas"][0].update(output_entry_sha256="f" * 64), "disagrees with its document")
        self.assert_refused(lambda d: d["deltas"][0].update(delta_sha256="0" * 64), "delta_sha256 does not match")
        self.assert_refused(lambda d: d["deltas"][0].update(delta_sha256="short"), "delta_sha256 does not match")

        def retarget_entry(d: dict) -> None:
            d["deltas"][0]["document"]["source"]["entry"] = "EVENT_Z.MES"
            _fix_delta_row(d["deltas"][0])

        def foreign_archive(d: dict) -> None:
            d["deltas"][0]["document"]["source"]["archive_sha256"] = "b" * 64
            _fix_delta_row(d["deltas"][0])

        def old_schema(d: dict) -> None:
            d["deltas"][0]["document"]["schema"] = delta.LEGACY_SCHEMA_V8
            _fix_delta_row(d["deltas"][0])

        self.assert_refused(retarget_entry, "bound to another entry")
        self.assert_refused(foreign_archive, "belongs to another archive")
        self.assert_refused(old_schema, "is not a kakyu_authored_mod_delta/v9 delta")

    def test_a_tampered_member_under_a_rehashed_bundle_is_refused(self) -> None:
        self.assert_refused(lambda d: d["deltas"][0]["document"]["operations"][0].update(value=5),
                            "EVENT_A.MES: Delta payload changed")
        self.assert_refused(lambda d: d["deltas"][1]["document"]["text_edits"][0].update(text="바뀐 번역"),
                            "EVENT_B.MES: Delta payload changed")

        def resign_member_only(d: dict) -> None:
            d["deltas"][1]["document"]["text_edits"][0]["text"] = "바뀐 번역"
            d["deltas"][1]["document"]["payload_sha256"] = delta.fingerprint(d["deltas"][1]["document"])

        self.assert_refused(resign_member_only, "delta_sha256 does not match")

    def test_text_projection_rows_obey_the_deltas_text_edit_rules(self) -> None:
        edits = lambda d: d["text_projections"][0]["text_edits"]  # noqa: E731
        self.assert_refused(lambda d: edits(d).clear(), "non-empty")
        self.assert_refused(lambda d: edits(d).append(copy.deepcopy(edits(d)[0])), "invalid, duplicated or unsorted")
        self.assert_refused(lambda d: edits(d).insert(0, _edit(9, MESSAGE_C, "앞")), "invalid, duplicated or unsorted")
        self.assert_refused(lambda d: edits(d)[0].update(text="a\0b"), "invalid, duplicated or unsorted")
        self.assert_refused(lambda d: edits(d)[0].update(source_offset=True), "invalid, duplicated or unsorted")
        self.assert_refused(lambda d: edits(d)[0].update(raw_sha256="xyz"), "invalid, duplicated or unsorted")
        self.assert_refused(lambda d: d["text_projections"][0].update(source_entry_sha256="abc"),
                            "source_entry_sha256 is invalid")

        def unsorted_rows(d: dict) -> None:
            d["text_projections"].append(dict(copy.deepcopy(d["text_projections"][0]), entry="EVENT_Z.MES"))
            d["text_projections"].reverse()

        self.assert_refused(unsorted_rows, "text projections must be sorted")

    def test_entries_are_path_free_mes_names(self) -> None:
        for entry in ("../EVENT_C.MES", "EVENT_C.TXT", "C:\\EVENT_C.MES", "dir/EVENT_C.MES", "", 7):
            self.assert_refused(lambda d: d["text_projections"][0].update(entry=entry), "unsafe or non-MES entry name")
            self.assert_refused(lambda d: d["deltas"][0].update(entry=entry), "unsafe or non-MES entry name")

    def test_the_definition_set_must_belong_to_the_header(self) -> None:
        self.assert_refused(lambda d: d["mod"].update(id="othermod"), "definition set is for another mod")
        self.assert_refused(lambda d: d["mod"].update(revision=2), "definition set is for another mod")
        self.assert_refused(lambda d: d.update(source_project_id="other.project"), "built from another project")
        self.assert_refused(lambda d: d["definition_set"].update(set_sha256="0" * 64), "set_sha256 does not match")
        self.assert_refused(lambda d: d["definition_set"].update(definition_count=1), "definition_count does not match")
        self.assert_refused(lambda d: d["definition_set"].update(definition_count=2.0), "definition_count does not match")
        self.assert_refused(lambda d: d["definition_set"]["document"]["definitions"][0].update(definition_sha256="0" * 64),
                            "Mod bundle definition set: .*definition_sha256 does not match")
        self.assert_refused(lambda d: d["definition_set"]["document"].update(payload_sha256="f" * 64),
                            "Mod bundle definition set: Definition set payload changed")

    def test_the_full_definition_contract_check_runs_when_directories_are_given(self) -> None:
        bundle = copy.deepcopy(self.base)
        definition_set = bundle["definition_set"]
        row = definition_set["document"]["definitions"][0]
        row["document"]["conditions"] = [{"type": "no_such_condition"}]
        row["definition_sha256"] = _sha(workflow._json(row["document"]))
        definition_set["document"]["payload_sha256"] = modset.fingerprint(definition_set["document"])
        definition_set["set_sha256"] = _sha(workflow._json(definition_set["document"]))
        _rehash(bundle)
        mod_bundle.validate(bundle)  # the structure and every hash are consistent
        with self.assertRaisesRegex(ValueError, "Mod bundle definition set: mod.samplemod.new_event_choice"):
            self.validate(bundle)

    def test_dependencies_must_equal_the_deltas_union(self) -> None:
        bundle = self.with_dependency
        self.validate(bundle)
        self.assert_refused(lambda d: d["dependencies"].clear(), "differ from its deltas' union", bundle=bundle)
        self.assert_refused(lambda d: d["dependencies"][0].update(entry_sha256="0" * 64),
                            "differ from its deltas' union", bundle=bundle)
        self.assert_refused(lambda d: d["dependencies"].append({"entry": "LIBLARY.LIB", "entry_sha256": "1" * 64}),
                            "differ from its deltas' union", bundle=bundle)
        self.assert_refused(lambda d: d["dependencies"][0].update(entry="../DEF_MAIN.MES"),
                            "dependency is invalid", bundle=bundle)
        self.assert_refused(lambda d: d["dependencies"][0].update(source_path="x"),
                            "dependency is invalid", bundle=bundle)
        self.assert_refused(lambda d: d["dependencies"].append(copy.deepcopy(d["dependencies"][0])),
                            "dependency is invalid or unsorted", bundle=bundle)
        # A delta whose dependency hash disagrees with another delta's.
        twin = copy.deepcopy(bundle["deltas"][0])
        twin["entry"] = twin["document"]["source"]["entry"] = "EVENT_F.MES"
        twin["document"]["dependencies"][0]["entry_sha256"] = "2" * 64
        _fix_delta_row(twin)
        changed = copy.deepcopy(bundle)
        changed["deltas"].append(twin)
        _rehash(changed)
        with self.assertRaisesRegex(ValueError, "disagrees with another delta"):
            self.validate(changed)

    def test_a_bundle_with_no_member_is_refused(self) -> None:
        def empty(d: dict) -> None:
            d.update(deltas=[], text_projections=[], definition_set=None, dependencies=[])

        self.assert_refused(empty, "has no member")

    def test_a_non_array_member_list_is_refused(self) -> None:
        self.assert_refused(lambda d: d.update(deltas={}), "deltas must be an array")
        self.assert_refused(lambda d: d.update(text_projections=None), "text_projections must be an array")
        self.assert_refused(lambda d: d.update(dependencies="x"), "dependencies must be an array")


class SourceTests(BundleCase):
    def check(self, bundle: dict, read_entry=None, archive_sha256: str | None = None) -> None:
        mod_bundle.check_source(bundle, read_entry or self.fixture.read_entry,
                                archive_sha256 or self.fixture.archive_sha)

    def test_the_matching_archive_verifies(self) -> None:
        self.check(self.base)

    def test_another_archive_is_refused(self) -> None:
        with self.assertRaisesRegex(ValueError, "another archive than the one supplied"):
            self.check(self.base, archive_sha256="9" * 64)

    def test_a_changed_or_missing_member_entry_is_refused(self) -> None:
        def changed(name: str) -> bytes:
            payload = self.fixture.read_entry(name)
            return payload + b"\0" if name == "EVENT_B.MES" else payload

        def missing(name: str) -> bytes:
            if name == "EVENT_C.MES":
                raise KeyError(name)
            return self.fixture.read_entry(name)

        with self.assertRaisesRegex(ValueError, "source entry EVENT_B.MES differs"):
            self.check(self.base, changed)
        with self.assertRaisesRegex(ValueError, "entry EVENT_C.MES is missing from the archive"):
            self.check(self.base, missing)

    def test_a_changed_or_missing_dependency_is_refused(self) -> None:
        bundle = self.with_dependency

        def changed(name: str) -> bytes:
            payload = self.fixture.read_entry(name)
            return payload + b"\0" if name == "DEF_MAIN.MES" else payload

        def missing(name: str) -> bytes:
            if name == "DEF_MAIN.MES":
                raise KeyError(name)
            return self.fixture.read_entry(name)

        with self.assertRaisesRegex(ValueError, "dependency DEF_MAIN.MES is missing or changed"):
            self.check(bundle, changed)
        with self.assertRaisesRegex(ValueError, "entry DEF_MAIN.MES is missing from the archive"):
            self.check(bundle, missing)

    def test_text_edits_must_bind_exact_source_messages(self) -> None:
        text_row = copy.deepcopy(self.base)
        text_row["text_projections"][0]["text_edits"][0]["raw_sha256"] = "f" * 64
        _rehash(text_row)
        self.validate(text_row)  # well-formed: only the source can tell
        with self.assertRaisesRegex(ValueError, "EVENT_C.MES: Authored text does not bind an exact source message"):
            self.check(text_row)

        delta_edit = copy.deepcopy(self.base)
        delta_edit["deltas"][1]["document"]["text_edits"][0]["source_offset"] = 7
        _fix_delta_row(delta_edit["deltas"][1])
        _rehash(delta_edit)
        self.validate(delta_edit)
        with self.assertRaisesRegex(ValueError, "EVENT_B.MES: Authored text does not bind an exact source message"):
            self.check(delta_edit)


class FileTests(BundleCase):
    def setUp(self) -> None:
        self.out = Path(tempfile.mkdtemp(prefix="mod_bundle_out_"))
        self.addCleanup(shutil.rmtree, self.out, ignore_errors=True)

    def test_an_oversize_file_is_refused_on_its_size_before_any_parse(self) -> None:
        path = self.out / "huge.json"
        with path.open("wb") as stream:
            stream.truncate(mod_bundle.MAX_BYTES + 1)
        with mock.patch.object(json, "loads", side_effect=AssertionError("parsed")), \
                mock.patch.object(Path, "read_text", side_effect=AssertionError("read")):
            with self.assertRaisesRegex(ValueError, "exceeds the bounded import size"):
                mod_bundle.read(path)

    def test_extract_writes_the_exact_canonical_bytes_the_rows_name(self) -> None:
        directory = self.out / "extract"
        mod_bundle.extract(self.base, directory)
        written = sorted(str(path.relative_to(directory)).replace("\\", "/") for path in directory.rglob("*") if path.is_file())
        self.assertEqual(["definition_set.json", "deltas/EVENT_A.MES.json", "deltas/EVENT_B.MES.json"], written)
        for row in self.base["deltas"]:
            payload = (directory / "deltas" / f"{row['entry']}.json").read_bytes()
            self.assertEqual(row["delta_sha256"], _sha(payload))
            self.assertEqual(workflow._json(row["document"]), payload)
            self.assertEqual(row["document"], delta.read(directory / "deltas" / f"{row['entry']}.json"))
        payload = (directory / "definition_set.json").read_bytes()
        self.assertEqual(self.base["definition_set"]["set_sha256"], _sha(payload))
        self.assertEqual(self.base["definition_set"]["document"],
                         modset.read(directory / "definition_set.json", NAMES_DIR, DEFINITIONS_DIR))

    def test_publish_reopens_exactly_and_never_replaces_an_existing_name(self) -> None:
        path = self.out / "nested" / "bundle.json"
        mod_bundle.publish(path, self.base)
        self.assertEqual(self.base, mod_bundle.read(path, NAMES_DIR, DEFINITIONS_DIR))
        self.assertEqual(workflow._json(self.base), path.read_bytes())
        before = path.read_bytes()
        other = copy.deepcopy(self.with_dependency)
        with self.assertRaises(FileExistsError):
            mod_bundle.publish(path, other)
        self.assertEqual(before, path.read_bytes())
        self.assertEqual([path], list(path.parent.iterdir()))

    def test_a_staged_file_that_does_not_reopen_exactly_is_never_published(self) -> None:
        path = self.out / "bundle.json"
        with mock.patch.object(mod_bundle, "read", return_value={}):
            with self.assertRaisesRegex(ValueError, "could not be reopened exactly"):
                mod_bundle.publish(path, self.base)
        self.assertEqual([], list(self.out.iterdir()))

    def test_publish_refuses_an_invalid_document_without_writing(self) -> None:
        path = self.out / "bundle.json"
        with self.assertRaises(ValueError):
            mod_bundle.publish(path, dict(self.base, payload_sha256="0" * 64))
        self.assertEqual([], list(self.out.iterdir()))

    def test_a_tampered_file_is_refused_on_read(self) -> None:
        path = self.out / "bundle.json"
        mod_bundle.publish(path, self.base)
        tampered = json.loads(path.read_text(encoding="utf-8"))
        tampered["text_projections"][0]["text_edits"][0]["text"] = "바뀐 번역"
        path.write_text(json.dumps(tampered, ensure_ascii=False), encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "payload changed"):
            mod_bundle.read(path)
        path.write_text("{" * 50000, encoding="utf-8")
        with self.assertRaises(ValueError):
            mod_bundle.read(path)


class PublishHelperTests(unittest.TestCase):
    def setUp(self) -> None:
        self.directory = Path(tempfile.mkdtemp(prefix="publish_helper_"))
        self.addCleanup(shutil.rmtree, self.directory, ignore_errors=True)

    def test_publishes_and_removes_the_temporary(self) -> None:
        seen: list[Path] = []
        target = self.directory / "out.bin"
        payload_values.publish_new_document(target, b"payload", self.directory / ".out.tmp", seen.append)
        self.assertEqual(b"payload", target.read_bytes())
        self.assertEqual([self.directory / ".out.tmp"], seen)
        self.assertEqual([target], list(self.directory.iterdir()))

    def test_takes_over_a_descriptor_the_caller_created(self) -> None:
        descriptor, temporary = tempfile.mkstemp(prefix=".caller-", dir=self.directory)
        target = self.directory / "out.bin"
        payload_values.publish_new_document(target, b"payload", Path(temporary), lambda staged: None,
                                            descriptor=descriptor)
        self.assertEqual(b"payload", target.read_bytes())
        self.assertEqual([target], list(self.directory.iterdir()))

    def test_an_existing_name_survives_and_the_temporary_goes(self) -> None:
        target = self.directory / "out.bin"
        target.write_bytes(b"first")
        with self.assertRaises(FileExistsError):
            payload_values.publish_new_document(target, b"second", self.directory / ".out.tmp", lambda staged: None)
        self.assertEqual(b"first", target.read_bytes())
        self.assertEqual([target], list(self.directory.iterdir()))

    def test_a_failed_verification_publishes_nothing(self) -> None:
        def refuse(staged: Path) -> None:
            raise ValueError("mismatch")

        with self.assertRaisesRegex(ValueError, "mismatch"):
            payload_values.publish_new_document(self.directory / "out.bin", b"payload", self.directory / ".out.tmp", refuse)
        self.assertEqual([], list(self.directory.iterdir()))

    def test_the_temporary_is_created_exclusively(self) -> None:
        temporary = self.directory / ".out.tmp"
        temporary.write_bytes(b"taken")
        with self.assertRaises(FileExistsError):
            payload_values.publish_new_document(self.directory / "out.bin", b"payload", temporary, lambda staged: None)
        self.assertEqual([], [path for path in self.directory.iterdir() if path.name == "out.bin"])

    def test_a_temporary_left_behind_after_the_link_is_not_a_failed_publication(self) -> None:
        # Once linked, the temporary is a second name for the published file; a
        # failed removal (Windows refuses while a handle is open) must not report
        # a published file as unpublished.
        target = self.directory / "out.bin"
        with mock.patch.object(Path, "unlink", side_effect=PermissionError("in use")):
            payload_values.publish_new_document(target, b"payload", self.directory / ".out.tmp", lambda staged: None)
        self.assertEqual(b"payload", target.read_bytes())

    def test_a_failed_removal_before_the_link_still_propagates(self) -> None:
        def refuse(staged: Path) -> None:
            raise ValueError("mismatch")

        with mock.patch.object(Path, "unlink", side_effect=PermissionError("in use")):
            with self.assertRaises(PermissionError):
                payload_values.publish_new_document(self.directory / "out.bin", b"payload",
                                                    self.directory / ".out.tmp", refuse)
        self.assertFalse((self.directory / "out.bin").exists())


class PublishWrapperTests(BundleCase):
    """The three writers keep their messages and temporary names when they
    publish through `payload_values.publish_new_document`."""

    def setUp(self) -> None:
        self.directory = Path(tempfile.mkdtemp(prefix="publish_wrappers_"))
        self.addCleanup(shutil.rmtree, self.directory, ignore_errors=True)

    def blocked_link(self, call) -> str:
        """Run `call` with the hard link refused; returns the staged temporary's name."""
        names: list[str] = []

        def refuse(source, destination, *args, **kwargs):
            names.append(Path(source).name)
            raise OSError("blocked")

        with mock.patch.object(payload_values.os, "link", side_effect=refuse):
            call()
        self.assertEqual(1, len(names))
        return names[0]

    def test_publish_new_keeps_its_three_messages_and_its_temporary_name(self) -> None:
        target = self.directory / "out.bin"
        editable_ir.publish_new(target, b"payload")
        self.assertEqual(b"payload", target.read_bytes())
        with self.assertRaisesRegex(editable_ir.EditableIrError, "^MES editable IR output already exists$"):
            editable_ir.publish_new(target, b"again")
        with self.assertRaisesRegex(editable_ir.EditableIrError, "^MES editable IR output directory does not exist$"):
            editable_ir.publish_new(self.directory / "missing" / "out.bin", b"payload")

        def blocked() -> None:
            with self.assertRaisesRegex(editable_ir.EditableIrError, "^MES editable IR output could not be published$"):
                editable_ir.publish_new(self.directory / "second.bin", b"payload")

        name = self.blocked_link(blocked)
        self.assertRegex(name, r"^\.second\.bin\.tmp-%d-[0-9a-f]{32}$" % os.getpid())
        with mock.patch.object(Path, "read_bytes", return_value=b"other"):
            with self.assertRaisesRegex(editable_ir.EditableIrError, "^MES editable IR temporary verification failed$"):
                editable_ir.publish_new(self.directory / "third.bin", b"payload")
        self.assertEqual(["out.bin"], sorted(path.name for path in self.directory.iterdir()))

    def test_the_delta_and_the_set_keep_their_temporary_prefixes_and_messages(self) -> None:
        delta_document = self.base["deltas"][0]["document"]
        set_document = self.base["definition_set"]["document"]
        for prefix, publish, document in ((".authored-delta-", delta.publish, delta_document),
                                          (".mod-definition-set-", modset.publish, set_document)):
            target = self.directory / f"{prefix}out.json"

            def blocked() -> None:
                with self.assertRaisesRegex(OSError, "blocked"):
                    publish(target, document)

            self.assertTrue(self.blocked_link(blocked).startswith(prefix))
            publish(target, document)
            with self.assertRaises(FileExistsError):
                publish(target, document)
        for module, document, message in ((delta, delta_document, "^Staged delta could not be reopened exactly$"),
                                          (modset, set_document, "^Staged definition set could not be reopened exactly$")):
            with mock.patch.object(module, "read", return_value={}):
                with self.assertRaisesRegex(ValueError, message):
                    module.publish(self.directory / "never.json", document)
        self.assertEqual(sorted([f"{prefix}out.json" for prefix in (".authored-delta-", ".mod-definition-set-")]),
                         sorted(path.name for path in self.directory.iterdir()))


class CommandLineTests(BundleCase):
    def setUp(self) -> None:
        self.out = Path(tempfile.mkdtemp(prefix="mod_bundle_cli_"))
        self.addCleanup(shutil.rmtree, self.out, ignore_errors=True)

    def run_main(self, *argv: str) -> tuple[int, dict]:
        stdout = io.StringIO()
        old_argv = sys.argv
        sys.argv = ["mod_bundle.py", *argv]
        try:
            with contextlib.redirect_stdout(stdout):
                mod_bundle.main()
            code = 0
        except SystemExit as exit_signal:
            code = int(exit_signal.code or 0)
        finally:
            sys.argv = old_argv
        lines = stdout.getvalue().strip().splitlines()
        self.assertEqual(1, len(lines), stdout.getvalue())
        return code, json.loads(lines[0])

    def directories(self) -> list[str]:
        return ["--names", str(NAMES_DIR), "--definitions-dir", str(DEFINITIONS_DIR)]

    def build(self, name: str = "bundle.json") -> tuple[int, dict, Path]:
        path = self.out / name
        code, report = self.run_main("build", str(self.fixture.arc_path), str(self.base_workspace.root), str(path),
                                     *self.directories())
        return code, report, path

    def test_build_and_validate_print_one_json_line_and_exit_zero(self) -> None:
        code, report, path = self.build()
        self.assertEqual(0, code)
        self.assertEqual({
            "ok": True, "schema": "kakyu_mod_bundle/v1", "mod_id": "samplemod", "mod_revision": 1, "delta_count": 2,
            "text_projection_count": 1, "definition_count": 2, "payload_sha256": self.base["payload_sha256"],
        }, report)
        self.assertEqual(workflow._json(self.base), path.read_bytes())
        for extra in ([], ["--arc", str(self.fixture.arc_path)]):
            self.assertEqual((0, report), self.run_main("validate", str(path), *extra, *self.directories()))

    def test_validate_extracts_after_a_successful_check(self) -> None:
        _, _, path = self.build()
        directory = self.out / "extract"
        code, report = self.run_main("validate", str(path), "--arc", str(self.fixture.arc_path),
                                     "--extract", str(directory), *self.directories())
        self.assertEqual((0, True), (code, report["ok"]))
        for row in self.base["deltas"]:
            self.assertEqual(row["delta_sha256"], _sha((directory / "deltas" / f"{row['entry']}.json").read_bytes()))
        self.assertEqual(self.base["definition_set"]["set_sha256"], _sha((directory / "definition_set.json").read_bytes()))

    def test_a_failing_run_prints_the_error_and_exits_one(self) -> None:
        _, _, path = self.build()
        tampered = json.loads(path.read_text(encoding="utf-8"))
        tampered["mod"]["revision"] = 99
        bad = self.out / "tampered.json"
        bad.write_text(json.dumps(tampered, ensure_ascii=False), encoding="utf-8")
        code, report = self.run_main("validate", str(bad), *self.directories())
        self.assertEqual(1, code)
        self.assertEqual({"ok", "error"}, set(report))
        self.assertFalse(report["ok"])
        self.assertRegex(report["error"], "payload changed")
        code, report = self.run_main("validate", str(self.out / "missing.json"), *self.directories())
        self.assertEqual((1, False), (code, report["ok"]))

    def test_validate_against_a_different_archive_exits_one(self) -> None:
        _, _, path = self.build()
        other = self.out / "other" / "mes.arc"
        other.parent.mkdir()
        arc_tests._write_arc(other, [("EVENT_A.MES", SOURCE_A)])
        code, report = self.run_main("validate", str(path), "--arc", str(other), *self.directories())
        self.assertEqual(1, code)
        self.assertRegex(report["error"], "another archive")

    def test_validate_refuses_an_oversize_file_before_parsing(self) -> None:
        huge = self.out / "huge.json"
        with huge.open("wb") as stream:
            stream.truncate(mod_bundle.MAX_BYTES + 1)
        code, report = self.run_main("validate", str(huge), *self.directories())
        self.assertEqual(1, code)
        self.assertRegex(report["error"], "bounded import size")

    def test_build_refuses_an_output_inside_the_workspace_the_original_directory_or_the_definitions(self) -> None:
        for output in (self.base_workspace.root / "bundle.json", self.fixture.arc_dir / "bundle.json",
                       DEFINITIONS_DIR / "bundle.json"):
            code, report = self.run_main("build", str(self.fixture.arc_path), str(self.base_workspace.root),
                                         str(output), *self.directories())
            self.assertEqual(1, code, output)
            self.assertRegex(report["error"], "must be outside")
            self.assertFalse(output.exists())

    def test_build_never_replaces_an_existing_output(self) -> None:
        _, _, path = self.build()
        before = path.read_bytes()
        code, report, _ = self.build()
        self.assertEqual(1, code)
        self.assertFalse(report["ok"])
        self.assertEqual(before, path.read_bytes())

    def test_a_deltas_only_build_takes_its_identity_from_the_command_line(self) -> None:
        workspace = self.fixture.workspace("cli_deltas_only")
        workspace.replace("EVENT_A.MES")
        workspace.write()
        path = self.out / "deltas.json"
        args = ["build", str(self.fixture.arc_path), str(workspace.root), str(path), *self.directories()]
        code, report = self.run_main(*args)
        self.assertEqual(1, code)
        self.assertRegex(report["error"], "needs a mod id")
        code, report = self.run_main(*args, "--mod-id", "clionly", "--mod-revision", "2")
        self.assertEqual((0, "clionly", 2, 0), (code, report["mod_id"], report["mod_revision"], report["definition_count"]))

    def test_the_archive_reader_is_case_insensitive_and_hashes_the_whole_file(self) -> None:
        sha, read_entry = mod_bundle._open_archive(self.fixture.arc_path)
        self.assertEqual(self.fixture.archive_sha, sha)
        self.assertEqual(SOURCE_A, read_entry("event_a.mes"))
        with self.assertRaises(KeyError):
            read_entry("EVENT_Z.MES")

    def test_main_declares_the_documented_sub_commands(self) -> None:
        with mock.patch.object(sys, "argv", ["mod_bundle.py"]), contextlib.redirect_stderr(io.StringIO()):
            with self.assertRaises(SystemExit) as raised:
                mod_bundle.main()
        self.assertEqual(2, raised.exception.code)
        self.assertTrue(re.search(r"build", mod_bundle.__doc__ or ""))


if __name__ == "__main__":
    unittest.main()
