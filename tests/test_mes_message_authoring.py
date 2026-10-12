from __future__ import annotations

import copy
import json
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
import authored_mod_delta as delta
import mes_authoring_binding as binding
import mes_authoring_workflow as workflow


class MessageAuthoringTests(unittest.TestCase):
    def fixture(self, shrink=False):
        first = bytes.fromhex("0182a082a000" if shrink else "0182a000")
        raw = (2).to_bytes(4, "little") + bytes(4) + len(first).to_bytes(4, "little")
        raw += first + bytes.fromhex("0182a2000b01ff") + len(first).to_bytes(4, "little") + b"\0"
        identity = dict(archive="mes.arc", entry="AUTHORED.MES", source_kind="original_arc", archive_sha256="a" * 64)
        files = workflow.analyze(raw, identity)
        controls = workflow.message_controls(json.loads(files["editable.json"]))
        operation = dict(controls[0]["operation"], text="あ" if shrink else "変更確認")
        edits = [dict(source_offset=controls[1]["operation"]["source_offset"],
                      raw_sha256=controls[1]["operation"]["raw_sha256"], text="뒤쪽 번역")]
        return raw, identity, files, operation, edits

    def test_grow_and_shrink_reproduce_branch_address_and_message_mapping(self):
        for shrink in (False, True):
            with self.subTest(shrink=shrink):
                raw, identity, files, operation, edits = self.fixture(shrink)
                built = workflow.compile_edit(files, operation)
                proof = json.loads(built["semantic.diff.json"])
                bound = binding.bind(raw, built["output.mes"], proof)
                shift = -2 if shrink else 6
                self.assertEqual(shift, proof["container_diff"]["byte_delta"])
                self.assertEqual(1, proof["preservation"]["target_change_count"])
                self.assertEqual(1, proof["preservation"]["address_change_count"])
                self.assertEqual(edits[0]["source_offset"] + shift, bound["messages"][1]["output"])
                document = delta.build(built, raw, edits)
                self.assertEqual(delta.SCHEMA, document["schema"])
                sequenced = workflow.compile_sequence(files, [operation])
                self.assertEqual(sequenced, delta.reconstruct(document, raw, identity))
                with tempfile.TemporaryDirectory() as root:
                    path = Path(root) / "bundle"
                    workflow.publish(path, built)
                    self.assertEqual(built, workflow.read_bundle(path)[1])

    def test_rehashed_forgery_and_unrelated_output_bytes_are_rejected(self):
        raw, _, files, operation, _ = self.fixture()
        built = workflow.compile_edit(files, operation)
        proof = json.loads(built["semantic.diff.json"])
        for mutate in (lambda d: d["semantic_changes"].update(target_changes_sha256="f" * 64),
                       lambda d: d["node_diff"].update(mapping_sha256="f" * 64)):
            changed = copy.deepcopy(proof)
            mutate(changed)
            changed["payload_sha256"] = workflow.editable.fingerprint(changed)
            with self.assertRaises(ValueError):
                binding.bind(raw, built["output.mes"], changed)
        with self.assertRaises(ValueError):
            binding.bind(raw, built["output.mes"][:-1] + b"\xff", proof)
        with self.assertRaises(ValueError):
            workflow.compile_edit(files, dict(operation, raw_sha256="f" * 64))

    def test_overlapping_translation_and_shadow_command_text_are_rejected(self):
        raw, _, files, operation, _ = self.fixture()
        built = workflow.compile_edit(files, operation)
        with self.assertRaisesRegex(ValueError, "overlaps"):
            delta.build(built, raw, [dict(source_offset=operation["source_offset"], raw_sha256=operation["raw_sha256"], text="겹침")])
        for text in ("ASCII", "あ\0い", "한국어", "あ"):
            with self.subTest(text=text), self.assertRaises(ValueError):
                workflow.compile_edit(files, dict(operation, text=text))

    def test_legacy_state_bundle_and_delta_remain_readable(self):
        raw = bytes.fromhex("0100000000000000031e0101ff000182a00000")
        identity = dict(archive="mes.arc", entry="AUTHORED.MES", source_kind="original_arc", archive_sha256="a" * 64)
        files = workflow.analyze(raw, identity)
        operation = dict(workflow.state_controls(json.loads(files["editable.json"]))[0]["operation"], value=2)
        built = workflow.compile_edit(files, operation)
        document = delta.build(built, raw, [])
        document["operation"] = document.pop("operations")[0]
        document.update(schema=delta.LEGACY_SCHEMA, compatibility=delta.LEGACY_COMPATIBILITY)
        del document["dependencies"]
        document["payload_sha256"] = delta.fingerprint(document)
        self.assertEqual(workflow.compile_sequence(files, [operation]), delta.reconstruct(document, raw, identity))
        with tempfile.TemporaryDirectory() as root:
            path = Path(root) / "legacy"
            manifest = workflow.publish(path, built)
            manifest["schema"] = workflow.LEGACY_SCHEMA
            manifest["summary"].pop("step_count")
            manifest["summary"].pop("operations")
            manifest["summary"].pop("control_target_controls")
            manifest["summary"].pop("shared_call_controls")
            manifest["summary"].pop("call_controls")
            manifest["summary"].pop("choice_controls")
            manifest["summary"].pop("resource_controls")
            manifest["summary"].pop("condition_controls")
            manifest["summary"].pop("message_controls")
            manifest["payload_sha256"] = workflow.editable.fingerprint(manifest)
            (path / "manifest.json").write_bytes(workflow._json(manifest))
            self.assertEqual(built, workflow.read_bundle(path)[1])


if __name__ == "__main__":
    unittest.main()
