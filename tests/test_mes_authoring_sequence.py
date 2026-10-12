from __future__ import annotations

import copy
import json
from pathlib import Path
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
import diff_mes_sequence_semantics as sequence_diff  # noqa: E402
import mes_authoring_workflow as workflow  # noqa: E402

# MW-11 sequence spec synthetic entry: nodes at 0 global_u8_write_run, 6
# continuation_transfer (target 0x10), 11 text ("あ"), 15/16 command_00.
# Measured through the real pipeline (analysis/mw11_sequence_synthetic_probe.py):
# one state literal (pair 0, value 1), one control target (current 16,
# command_00), one message ("あ"). Sequence S = [state literal value 2,
# retarget 16 -> 11, replace_message "変更確認"].
RAW = bytes.fromhex("0100000000000000031e0101ff000c100000000182a0000000")
FINAL_HEX = "0100000000000000031e0102ff000c0b0000000195cf8d588a6d9446000000"
SOURCE_IDENTITY = {"archive": "mes.arc", "entry": "AUTHORED.MES", "source_kind": "original_arc", "archive_sha256": "a" * 64}


class MesAuthoringSequenceTests(unittest.TestCase):
    def fixture(self):
        files = workflow.analyze(RAW, SOURCE_IDENTITY)
        model = json.loads(files["editable.json"])
        state_rows = workflow.state_controls(model)
        control_rows = workflow.control_target_controls(model)
        message_rows = workflow.message_controls(model)
        self.assertEqual(1, len(state_rows))
        self.assertEqual(0, state_rows[0]["operation"]["pair_index"])
        self.assertEqual(1, state_rows[0]["operation"]["value"])
        self.assertEqual(1, len(control_rows))
        self.assertEqual(16, control_rows[0]["current_target_offset"])
        self.assertEqual("command_00", control_rows[0]["current_target_op"])
        self.assertEqual(1, len(message_rows))
        self.assertEqual("あ", message_rows[0]["operation"]["text"])
        state_op = dict(state_rows[0]["operation"], value=2)
        control_op = dict(control_rows[0]["operation"], replacement_target_offset=11)
        message_op = dict(message_rows[0]["operation"], text="変更確認")
        return files, state_op, control_op, message_op

    # 1. N = 1 equals compile_edit + sequence.json; publish/read_bundle round
    #    trip; summary step_count 1 and operations [op].
    def test_single_step_sequence_equals_compile_edit_plus_sequence_member(self):
        files, state_op, _control_op, _message_op = self.fixture()
        sequenced = workflow.compile_sequence(files, [state_op])
        edited = workflow.compile_edit(files, state_op)
        self.assertEqual(workflow.SEQUENCE_MEMBER, "sequence.json")
        self.assertEqual({**edited, workflow.SEQUENCE_MEMBER: sequenced[workflow.SEQUENCE_MEMBER]}, sequenced)
        sequence = json.loads(sequenced[workflow.SEQUENCE_MEMBER])
        self.assertEqual("kakyu_mes_authoring_sequence/v1", sequence["schema"])
        self.assertEqual(1, len(sequence["steps"]))
        self.assertEqual(state_op, sequence["steps"][0]["operation"])

        with tempfile.TemporaryDirectory() as tmp:
            destination = Path(tmp) / "n1"
            manifest = workflow.publish(destination, sequenced)
            self.assertEqual(workflow.SCHEMA, manifest["schema"])
            self.assertEqual(1, manifest["summary"]["step_count"])
            self.assertEqual([state_op], manifest["summary"]["operations"])
            reopened, payloads = workflow.read_bundle(destination)
            self.assertEqual(manifest, reopened)
            self.assertEqual(sequenced, payloads)

    # 2. N = 3 stepped: layout, step hashes chain, chain proof validates,
    #    relocation_step_index 3, two original-coordinate patches, final
    #    output = hand-computed bytes, publish/read_bundle round trip.
    def test_three_step_sequence_chains_to_hand_computed_final_bytes(self):
        files, state_op, control_op, message_op = self.fixture()
        built = workflow.compile_sequence(files, [state_op, control_op, message_op])
        self.assertEqual(FINAL_HEX, built["output.mes"].hex())
        self.assertEqual(len(RAW) + 6, len(built["output.mes"]))

        expected_members = set(workflow.SOURCE_FILES) | {
            "output.mes", "output.handoff.json", "semantic.diff.json", "sequence.json",
        }
        for index, suffix_set in enumerate(
            [workflow.STEP_SUFFIXES, workflow.STEP_SUFFIXES, workflow.STEP_SUFFIXES + ("control.plan.json",)],
            start=1,
        ):
            for suffix in suffix_set:
                expected_members.add(workflow.step_member(index, suffix))
        self.assertEqual(expected_members, set(built))

        sequence = json.loads(built["sequence.json"])
        self.assertEqual(3, len(sequence["steps"]))
        for index, row in enumerate(sequence["steps"], start=1):
            self.assertEqual(index, row["index"])
        # Step hashes chain: each step's source hash is the previous step's
        # output hash, and step 1's source hash is the original entry.
        self.assertEqual(workflow._sha(RAW), sequence["steps"][0]["source_entry_sha256"])
        self.assertEqual(sequence["steps"][0]["output_entry_sha256"], sequence["steps"][1]["source_entry_sha256"])
        self.assertEqual(sequence["steps"][1]["output_entry_sha256"], sequence["steps"][2]["source_entry_sha256"])
        self.assertEqual(sequence["steps"][2]["output_entry_sha256"], workflow._sha(built["output.mes"]))
        self.assertEqual(sequence["steps"][2]["control_plan_sha256"], json.loads(built["step-03.control.plan.json"])["payload_sha256"])
        self.assertEqual("", sequence["steps"][0]["control_plan_sha256"])
        self.assertEqual("", sequence["steps"][1]["control_plan_sha256"])

        proof = json.loads(built["semantic.diff.json"])
        self.assertEqual(sequence_diff.DIFF_SCHEMA, proof["schema"])
        self.assertEqual(3, proof["composition"]["step_count"])
        self.assertEqual(2, proof["composition"]["same_size_step_count"])
        self.assertEqual(3, proof["composition"]["relocation_step_index"])
        patches = proof["composition"]["original_coordinate_patches"]
        self.assertEqual(2, len(patches))
        self.assertEqual([1, 2], [row["step"] for row in patches])
        self.assertEqual(["state_literal_edit", "control_target_edit"], [row["family"] for row in patches])
        sequence_diff.validate(proof)  # shape-only, no rebuild inputs

        # Chain proof validates with rebuild inputs reconstructed from the
        # persisted bundle (a stepped bundle keeps no per-step editable.json;
        # every step's source model is re-derived from its source handoff,
        # exactly as `compile_sequence` itself derives it).
        def _step_source(index: int) -> tuple[bytes, bytes]:
            handoff_bytes = built["handoff.json"] if index == 1 else built[workflow.step_member(index - 1, "output.handoff.json")]
            handoff = json.loads(handoff_bytes)
            model = sequence_diff.editable_ir.prepare(sequence_diff.decompiler.lift(handoff))
            return handoff_bytes, workflow._json(model)

        step_files = []
        for index in (1, 2, 3):
            handoff_bytes, editable_bytes = _step_source(index)
            step_files.append({
                "handoff.json": handoff_bytes, "editable.json": editable_bytes,
                "compile.audit.json": built[workflow.step_member(index, "compile.audit.json")],
                "semantic.diff.json": built[workflow.step_member(index, "semantic.diff.json")],
                "output.handoff.json": built[workflow.step_member(index, "output.handoff.json")],
            })
        source_subset = {"handoff.json": built["handoff.json"], "editable.json": built["editable.json"]}
        sequence_diff.validate(proof, source_subset, step_files)

        with tempfile.TemporaryDirectory() as tmp:
            destination = Path(tmp) / "n3"
            manifest = workflow.publish(destination, built)
            self.assertEqual(3, manifest["summary"]["step_count"])
            self.assertEqual(
                ["replace_state_write_literal", "retarget_control_flow", "replace_message"],
                [op["kind"] for op in manifest["summary"]["operations"]],
            )
            reopened, payloads = workflow.read_bundle(destination)
            self.assertEqual(manifest, reopened)
            self.assertEqual(built, payloads)

    # 3. Rejections.
    def test_relocation_must_be_last(self):
        files, state_op, control_op, message_op = self.fixture()
        with self.assertRaisesRegex(ValueError, "must be the last operation"):
            workflow.compile_sequence(files, [message_op, state_op])
        with self.assertRaisesRegex(ValueError, "must be the last operation"):
            workflow.compile_sequence(files, [state_op, message_op, control_op])

    def test_second_operation_on_an_already_edited_instruction_names_its_step(self):
        files, _state_op, control_op, _message_op = self.fixture()
        with self.assertRaisesRegex(ValueError, r"^Step 2 \(retarget_control_flow"):
            workflow.compile_sequence(files, [control_op, control_op])

    def test_empty_operation_list_is_rejected(self):
        files, _state_op, _control_op, _message_op = self.fixture()
        with self.assertRaisesRegex(ValueError, "non-empty"):
            workflow.compile_sequence(files, [])

    def test_tampered_sequence_member_is_rejected(self):
        files, state_op, control_op, message_op = self.fixture()
        built = workflow.compile_sequence(files, [state_op, control_op, message_op])
        with tempfile.TemporaryDirectory() as tmp:
            destination = Path(tmp) / "tampered"
            manifest = workflow.publish(destination, built)
            sequence = json.loads((destination / "sequence.json").read_bytes())
            sequence["steps"][0]["source_entry_sha256"] = "f" * 64
            sequence["payload_sha256"] = workflow.editable.fingerprint(sequence)
            payload = workflow._json(sequence)
            (destination / "sequence.json").write_bytes(payload)
            for row in manifest["files"]:
                if row["name"] == "sequence.json":
                    row["size"] = len(payload)
                    row["sha256"] = workflow._sha(payload)
            manifest["payload_sha256"] = workflow.editable.fingerprint(manifest)
            (destination / "manifest.json").write_bytes(workflow._json(manifest))
            with self.assertRaises(ValueError):
                workflow.read_bundle(destination)

    def test_stepped_bundle_with_a_step_member_removed_or_renamed_is_rejected(self):
        files, state_op, control_op, message_op = self.fixture()
        built = workflow.compile_sequence(files, [state_op, control_op, message_op])
        with tempfile.TemporaryDirectory() as tmp:
            destination = Path(tmp) / "removed"
            manifest = workflow.publish(destination, built)
            manifest["files"] = [row for row in manifest["files"] if row["name"] != "step-02.output.mes"]
            manifest["payload_sha256"] = workflow.editable.fingerprint(manifest)
            (destination / "manifest.json").write_bytes(workflow._json(manifest))
            with self.assertRaisesRegex(ValueError, "differs from its exact inputs"):
                workflow.read_bundle(destination)
        with tempfile.TemporaryDirectory() as tmp:
            destination = Path(tmp) / "renamed"
            manifest = workflow.publish(destination, built)
            (destination / "step-02.output.mes").replace(destination / "step-04.output.mes")
            for row in manifest["files"]:
                if row["name"] == "step-02.output.mes":
                    row["name"] = "step-04.output.mes"
            manifest["payload_sha256"] = workflow.editable.fingerprint(manifest)
            (destination / "manifest.json").write_bytes(workflow._json(manifest))
            with self.assertRaisesRegex(ValueError, "differs from its exact inputs"):
                workflow.read_bundle(destination)

    # 4. Legacy.
    def test_legacy_v8_flat_bundle_without_sequence_reads_back_with_single_operation(self):
        files, state_op, _control_op, _message_op = self.fixture()
        edited = workflow.compile_edit(files, state_op)
        with tempfile.TemporaryDirectory() as tmp:
            destination = Path(tmp) / "legacy_v8"
            manifest = workflow.publish(destination, edited)
            manifest["schema"] = "kakyu_mes_authoring_bundle/v8"
            manifest["summary"].pop("step_count")
            manifest["summary"].pop("operations")
            manifest["payload_sha256"] = workflow.editable.fingerprint(manifest)
            (destination / "manifest.json").write_bytes(workflow._json(manifest))
            reopened, payloads = workflow.read_bundle(destination)
            self.assertEqual("kakyu_mes_authoring_bundle/v8", reopened["schema"])
            self.assertEqual(edited, payloads)

    def test_v9_single_step_bundle_relabelled_v8_is_refused_for_its_sequence_member(self):
        files, state_op, _control_op, _message_op = self.fixture()
        sequenced = workflow.compile_sequence(files, [state_op])
        with tempfile.TemporaryDirectory() as tmp:
            destination = Path(tmp) / "relabelled"
            manifest = workflow.publish(destination, sequenced)
            manifest["schema"] = "kakyu_mes_authoring_bundle/v8"
            manifest["payload_sha256"] = workflow.editable.fingerprint(manifest)
            (destination / "manifest.json").write_bytes(workflow._json(manifest))
            with self.assertRaisesRegex(ValueError, "Legacy authoring bundle cannot carry a sequence"):
                workflow.read_bundle(destination)


if __name__ == "__main__":
    unittest.main()
