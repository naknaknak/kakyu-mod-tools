from __future__ import annotations

import copy
import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
sys.path.insert(0, str(ROOT / "tests"))
import mes_authoring_workflow as workflow

import test_plan_mes_registered_definition_call_edit as call_plan_tests  # noqa: E402
import test_plan_mes_shared_routine_call_edit as shared_call_plan_tests  # noqa: E402


class MesAuthoringWorkflowTests(unittest.TestCase):
    def fixture(self):
        # Authored: global_u8[286] = 1; one CP932 message; return.
        raw = bytes.fromhex("0100000000000000031e0101ff000182a00000")
        source = {"archive": "mes.arc", "entry": "AUTHORED.MES",
                  "archive_sha256": "a" * 64, "source_kind": "original_arc"}
        files = workflow.analyze(raw, source)
        controls = workflow.state_controls(json.loads(files["editable.json"]))
        self.assertEqual(1, len(controls))
        operation = copy.deepcopy(controls[0]["operation"])
        operation["value"] = 2
        return raw, files, operation

    def test_python_authority_to_reopened_semantic_proof(self):
        raw, source_files, operation = self.fixture()
        built = workflow.compile_edit(source_files, operation)
        self.assertEqual("python_phase1_4", json.loads(built["handoff.json"])["producer"]["implementation"])
        self.assertEqual(raw[:11] + b"\x02" + raw[12:], built["output.mes"])
        proof = json.loads(built["semantic.diff.json"])
        self.assertEqual("state_literal_edit", proof["operation"]["family"])
        self.assertEqual(hashlib.sha256(built["output.mes"]).hexdigest(), proof["output_binding"]["entry_sha256"])
        self.assertEqual(0, proof["container_diff"]["code_delta"])
        self.assertEqual(source_files, {key: built[key] for key in source_files})

    def test_stale_unsupported_or_nonliteral_edits_do_not_compile(self):
        _raw, source_files, operation = self.fixture()
        for field, value in (("instruction_raw_sha256", "f" * 64), ("source_offset", 1),
                             ("value", True), ("value", 256), ("kind", "delete_instruction")):
            with self.subTest(field=field, value=value):
                changed = dict(operation, **{field: value})
                with self.assertRaises(ValueError):
                    workflow.compile_edit(source_files, changed)

    def test_publish_reopen_tamper_and_existing_destination(self):
        _raw, files, operation = self.fixture()
        built = workflow.compile_edit(files, operation)
        with tempfile.TemporaryDirectory() as tmp:
            destination = Path(tmp) / "bundle"
            manifest = workflow.publish(destination, built)
            reopened, payloads = workflow.read_bundle(destination)
            self.assertEqual(manifest, reopened)
            self.assertEqual(built, payloads)
            before = {p.name: p.read_bytes() for p in destination.iterdir()}
            with self.assertRaisesRegex(ValueError, "already exists"):
                workflow.publish(destination, built)
            self.assertEqual(before, {p.name: p.read_bytes() for p in destination.iterdir()})
            (destination / "output.mes").write_bytes(b"changed")
            with self.assertRaisesRegex(ValueError, "bytes changed"):
                workflow.read_bundle(destination)

    def test_failed_reopen_removes_only_new_stage(self):
        _raw, files, _operation = self.fixture()
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            sentinel = root / "keep.txt"
            sentinel.write_text("keep")
            with mock.patch.object(workflow, "read_bundle", side_effect=ValueError("injected")):
                with self.assertRaisesRegex(ValueError, "injected"):
                    workflow.publish(root / "new", files)
            self.assertEqual([sentinel], list(root.iterdir()))

    def condition_fixture(self):
        # Authored: branch_if_not_true(global_u8[1] == 1) -> false target at the
        # return instruction; one CP932 message; return. Condition bytes from
        # tests/test_compile_mes_condition_literal_edit.py
        # (0b f3 01 00 01 ef ff + false target u32); the false target (0x0f) is
        # the return instruction's code-relative offset, verified empirically
        # against workflow.analyze: branch (11 bytes, offset 0-10), message
        # (4 bytes, offset 11-14), return (1 byte, offset 15).
        raw = bytes.fromhex("01000000000000000bf3010001efff0f0000000182a00000")
        source = {"archive": "mes.arc", "entry": "AUTHORED.MES",
                  "archive_sha256": "a" * 64, "source_kind": "original_arc"}
        files = workflow.analyze(raw, source)
        controls = workflow.condition_controls(json.loads(files["editable.json"]))
        self.assertEqual(1, len(controls))
        operation = copy.deepcopy(controls[0]["operation"])
        operation["value"] = 2
        return raw, files, operation

    def test_condition_literal_candidate_and_compile_to_reopened_semantic_proof(self):
        raw, files, operation = self.condition_fixture()
        model = json.loads(files["editable.json"])
        condition_rows = workflow.condition_controls(model)
        self.assertEqual(1, len(condition_rows))
        row = condition_rows[0]
        self.assertEqual(0, row["operation"]["source_offset"])
        self.assertEqual(4, row["operation"]["literal_offset"])
        self.assertEqual(1, row["operation"]["value"])
        self.assertEqual(8, row["width"])
        self.assertEqual(1, len(workflow.message_controls(model)))

        built = workflow.compile_edit(files, operation)
        self.assertEqual(raw[:12] + b"\x02" + raw[13:], built["output.mes"])
        proof = json.loads(built["semantic.diff.json"])
        self.assertEqual("condition_literal_edit", proof["operation"]["family"])
        self.assertEqual(0, proof["container_diff"]["code_delta"])
        self.assertEqual(files, {key: built[key] for key in files})

    def test_condition_literal_rejects_stale_offset_or_nonliteral_edits(self):
        _raw, files, operation = self.condition_fixture()
        for field, value in (("instruction_raw_sha256", "f" * 64), ("literal_offset", 5),
                             ("value", 256), ("value", True), ("kind", "delete_instruction")):
            with self.subTest(field=field, value=value):
                changed = dict(operation, **{field: value})
                with self.assertRaises(ValueError):
                    workflow.compile_edit(files, changed)

    def test_condition_literal_publish_read_bundle_and_legacy_bundle_round_trip(self):
        raw, files, operation = self.condition_fixture()
        built = workflow.compile_edit(files, operation)
        with tempfile.TemporaryDirectory() as tmp:
            destination = Path(tmp) / "bundle"
            manifest = workflow.publish(destination, built)
            self.assertEqual(workflow.SCHEMA, manifest["schema"])
            self.assertEqual(
                {"state_controls", "message_controls", "condition_controls"},
                set(manifest["summary"]) & {"state_controls", "message_controls", "condition_controls"},
            )
            reopened, payloads = workflow.read_bundle(destination)
            self.assertEqual(manifest, reopened)
            self.assertEqual(built, payloads)

        with tempfile.TemporaryDirectory() as tmp:
            destination = Path(tmp) / "legacy_v2"
            manifest = workflow.publish(destination, built)
            manifest["schema"] = "kakyu_mes_authoring_bundle/v2"
            manifest["summary"].pop("step_count")
            manifest["summary"].pop("operations")
            manifest["summary"].pop("control_target_controls")
            manifest["summary"].pop("shared_call_controls")
            manifest["summary"].pop("call_controls")
            manifest["summary"].pop("choice_controls")
            manifest["summary"].pop("resource_controls")
            manifest["summary"].pop("condition_controls")
            manifest["payload_sha256"] = workflow.editable.fingerprint(manifest)
            (destination / "manifest.json").write_bytes(workflow._json(manifest))
            self.assertEqual(built, workflow.read_bundle(destination)[1])

        with tempfile.TemporaryDirectory() as tmp:
            destination = Path(tmp) / "legacy_v1"
            manifest = workflow.publish(destination, built)
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
            (destination / "manifest.json").write_bytes(workflow._json(manifest))
            self.assertEqual(built, workflow.read_bundle(destination)[1])

    def resource_fixture(self):
        # Authored: MMO resource marker `z.mmo` (0x0D framing since Core
        # 0.316.0; command 0D 09 FF 01 <name> 00 00, one system-call record,
        # not a separator plus a 0x09 record); one CP932 message; return.
        # Verified empirically against workflow.analyze: MMO marker (11
        # bytes, offset 0-10), message (4 bytes, offset 11-14), return (1
        # byte, offset 15).
        raw = bytes.fromhex("01000000000000000d09ff017a2e6d6d6f00000182a00000")
        source = {"archive": "mes.arc", "entry": "AUTHORED.MES",
                  "archive_sha256": "a" * 64, "source_kind": "original_arc"}
        files = workflow.analyze(raw, source)
        controls = workflow.resource_controls(json.loads(files["editable.json"]))
        self.assertEqual(1, len(controls))
        operation = copy.deepcopy(controls[0]["operation"])
        operation["name"] = "x.mmo"
        return raw, files, operation

    def test_resource_name_candidate_and_compile_to_reopened_semantic_proof(self):
        raw, files, operation = self.resource_fixture()
        model = json.loads(files["editable.json"])
        resource_rows = workflow.resource_controls(model)
        self.assertEqual(1, len(resource_rows))
        row = resource_rows[0]
        self.assertEqual(0, row["operation"]["source_offset"])
        self.assertEqual("z.mmo", row["operation"]["name"])
        self.assertEqual("mmo", row["resource_kind"])
        self.assertEqual(5, row["name_length"])
        self.assertEqual("mmo", row["extension"])
        self.assertEqual(1, len(workflow.message_controls(model)))

        built = workflow.compile_edit(files, operation)
        diff_positions = [index for index in range(len(raw)) if raw[index] != built["output.mes"][index]]
        self.assertEqual(1, len(diff_positions))
        proof = json.loads(built["semantic.diff.json"])
        self.assertEqual("resource_name_edit", proof["operation"]["family"])
        self.assertEqual(0, proof["container_diff"]["code_delta"])
        self.assertEqual(files, {key: built[key] for key in files})

    def test_resource_name_rejects_stale_wrong_length_extension_or_unsafe_edits(self):
        _raw, files, operation = self.resource_fixture()
        for field, value in (("instruction_raw_sha256", "f" * 64), ("reference_id", "resource_99999999"),
                             ("name", "xy.mmo"), ("name", "x.ogg"), ("name", "../x.mmo"),
                             ("kind", "delete_instruction")):
            with self.subTest(field=field, value=value):
                changed = dict(operation, **{field: value})
                with self.assertRaises(ValueError):
                    workflow.compile_edit(files, changed)

    def test_resource_name_publish_read_bundle_and_legacy_bundle_round_trip(self):
        raw, files, operation = self.resource_fixture()
        built = workflow.compile_edit(files, operation)
        with tempfile.TemporaryDirectory() as tmp:
            destination = Path(tmp) / "bundle"
            manifest = workflow.publish(destination, built)
            self.assertEqual(workflow.SCHEMA, manifest["schema"])
            self.assertEqual(
                {"state_controls", "message_controls", "condition_controls", "resource_controls"},
                set(manifest["summary"]) & {"state_controls", "message_controls",
                                             "condition_controls", "resource_controls"},
            )
            reopened, payloads = workflow.read_bundle(destination)
            self.assertEqual(manifest, reopened)
            self.assertEqual(built, payloads)

        with tempfile.TemporaryDirectory() as tmp:
            destination = Path(tmp) / "legacy_v3"
            manifest = workflow.publish(destination, built)
            manifest["schema"] = "kakyu_mes_authoring_bundle/v3"
            manifest["summary"].pop("step_count")
            manifest["summary"].pop("operations")
            manifest["summary"].pop("control_target_controls")
            manifest["summary"].pop("shared_call_controls")
            manifest["summary"].pop("call_controls")
            manifest["summary"].pop("choice_controls")
            manifest["summary"].pop("resource_controls")
            manifest["payload_sha256"] = workflow.editable.fingerprint(manifest)
            (destination / "manifest.json").write_bytes(workflow._json(manifest))
            self.assertEqual(built, workflow.read_bundle(destination)[1])

    def choice_fixture(self):
        # Authored: tests.test_prove_mes_choice_group_authoring._fixture()'s
        # own container (two routine-40 groups: group 0 definition 0 text
        # "FIRST", 5 bytes; group 1 definition 0 text "SECOND02", 8 bytes) as
        # address entry 0 - its original hex is
        # 010000000000000017000000001b0200ff00100200ff001b00000001464952535400
        # 001b0201ff00100200ff0034000000015345434f4e44303200001d0228ff000b801501ef
        # 800d01efe6ff49000000000c4f0000000000 - plus a second address entry
        # (five-byte 0x17 label prologue, one CP932 message "0182a000", one
        # return "00") so message_controls has a candidate alongside the
        # choice family. Verified empirically against workflow.analyze:
        # entry 0's code is the prover fixture's 78 bytes with the second
        # group's text lengthened by two characters (80 bytes, its targets
        # moved with it); entry 1's code is 10 bytes (prologue 5 + message 4 +
        # return 1) at code-relative offset 80..90 (message payload at
        # code-relative offset 85..87, decodes to "あ").
        raw = bytes.fromhex(
            "02000000000000005000000017000000001b0200ff00100200ff001b0000000146"
            "4952535400001b0201ff00100200ff0034000000015345434f4e44303200001d0228ff"
            "000b801501ef800d01efe6ff49000000000c4f000000000017010000000182a000"
            "00"
        )
        source = {"archive": "mes.arc", "entry": "AUTHORED.MES",
                  "archive_sha256": "a" * 64, "source_kind": "original_arc"}
        files = workflow.analyze(raw, source)
        model = json.loads(files["editable.json"])
        controls = workflow.choice_controls(model)
        self.assertEqual(2, len(controls))
        self.assertEqual(["FIRST", "SECOND02"], [row["operation"]["text"] for row in controls])
        self.assertEqual([0, 1], [row["operation"]["group_selector"] for row in controls])
        self.assertEqual(1, len(workflow.message_controls(model)))
        operation = copy.deepcopy(controls[0]["operation"])
        operation["text"] = "OTHER"
        return raw, files, operation

    def test_choice_option_candidate_and_compile_to_reopened_semantic_proof(self):
        raw, files, operation = self.choice_fixture()
        model = json.loads(files["editable.json"])
        choice_rows = workflow.choice_controls(model)
        self.assertEqual(2, len(choice_rows))
        row = choice_rows[0]
        self.assertEqual(0, row["operation"]["group_selector"])
        self.assertEqual(0, row["operation"]["definition_id"])
        self.assertEqual(5, row["payload_size"])
        self.assertEqual(0, row["address_entry_index"])
        message_rows = workflow.message_controls(model)
        self.assertEqual(1, len(message_rows))
        self.assertEqual("あ", message_rows[0]["operation"]["text"])

        built = workflow.compile_edit(files, operation)
        diff_positions = [index for index in range(len(raw)) if raw[index] != built["output.mes"][index]]
        self.assertEqual(5, len(diff_positions))
        proof = json.loads(built["semantic.diff.json"])
        self.assertEqual("choice_option_edit", proof["operation"]["family"])
        self.assertEqual(0, proof["container_diff"]["code_delta"])
        self.assertEqual(files, {key: built[key] for key in files})

    def test_choice_option_rejects_stale_wrong_group_definition_or_unsafe_edits(self):
        _raw, files, operation = self.choice_fixture()
        for field, value in (("source_payload_sha256", "f" * 64), ("definition_id", 9),
                             ("text", "LONGER"), ("text", "FIRST"),
                             ("text", "ЀЀЀЀЀ"),
                             ("kind", "delete_instruction")):
            with self.subTest(field=field, value=value):
                changed = dict(operation, **{field: value})
                with self.assertRaises(ValueError):
                    workflow.compile_edit(files, changed)

    def test_choice_option_publish_read_bundle_and_legacy_bundle_round_trip(self):
        raw, files, operation = self.choice_fixture()
        built = workflow.compile_edit(files, operation)
        with tempfile.TemporaryDirectory() as tmp:
            destination = Path(tmp) / "bundle"
            manifest = workflow.publish(destination, built)
            self.assertEqual(workflow.SCHEMA, manifest["schema"])
            self.assertEqual(
                {"state_controls", "message_controls", "condition_controls",
                 "resource_controls", "choice_controls"},
                set(manifest["summary"]) & {"state_controls", "message_controls", "condition_controls",
                                             "resource_controls", "choice_controls"},
            )
            reopened, payloads = workflow.read_bundle(destination)
            self.assertEqual(manifest, reopened)
            self.assertEqual(built, payloads)

        with tempfile.TemporaryDirectory() as tmp:
            destination = Path(tmp) / "legacy_v4"
            manifest = workflow.publish(destination, built)
            manifest["schema"] = "kakyu_mes_authoring_bundle/v4"
            manifest["summary"].pop("step_count")
            manifest["summary"].pop("operations")
            manifest["summary"].pop("control_target_controls")
            manifest["summary"].pop("shared_call_controls")
            manifest["summary"].pop("call_controls")
            manifest["summary"].pop("choice_controls")
            manifest["payload_sha256"] = workflow.editable.fingerprint(manifest)
            (destination / "manifest.json").write_bytes(workflow._json(manifest))
            self.assertEqual(built, workflow.read_bundle(destination)[1])

    def registered_call_fixture(self):
        # Authored: a registered-definition call (command 0x11, `11 02 03 ff
        # 00`, selector 3); one CP932 message; a return. The registry payload
        # is tests/test_plan_mes_registered_definition_call_edit.py's
        # MesRegisteredDefinitionCallEditPlanTests.registry_payload(3, 4)
        # (two command-0x14 registrations for selectors 3 and 4), proved as
        # the archive's DEF_MAIN.MES. Verified empirically against
        # workflow.analyze: call (5 bytes, offset 0-4), message (4 bytes,
        # offset 5-8), return (1 byte, offset 9).
        raw = bytes.fromhex("0100000000000000110203ff000182a00000")
        source = {"archive": "mes.arc", "entry": "AUTHORED.MES",
                  "archive_sha256": "a" * 64, "source_kind": "original_arc"}
        registry_payload = call_plan_tests.MesRegisteredDefinitionCallEditPlanTests.registry_payload(3, 4)
        registry_identity = {"archive": "mes.arc", "archive_sha256": "a" * 64,
                             "entry": "DEF_MAIN.MES",
                             "entry_sha256": hashlib.sha256(registry_payload).hexdigest()}
        registry_proof = workflow.registry_prover.prove_entry(registry_payload, registry_identity)
        files = workflow.analyze(raw, source, registry_proof)
        model = json.loads(files["editable.json"])
        controls = workflow.call_controls(model, files)
        self.assertEqual(1, len(controls))
        operation = copy.deepcopy(controls[0]["operation"])
        operation["selector"] = 4
        return raw, files, operation, registry_payload

    def test_registered_call_candidate_and_compile_to_reopened_semantic_proof(self):
        raw, files, operation, _registry_payload = self.registered_call_fixture()
        model = json.loads(files["editable.json"])
        call_rows = workflow.call_controls(model, files)
        self.assertEqual(1, len(call_rows))
        row = call_rows[0]
        self.assertEqual(0, row["operation"]["source_offset"])
        self.assertEqual(3, row["operation"]["selector"])
        self.assertEqual(5, row["end_offset"])
        self.assertEqual(5, row["physical_resume_offset"])
        self.assertEqual([3, 4], row["registered_selectors"])
        self.assertEqual("DEF_MAIN.MES", row["registry_entry"])
        self.assertEqual(1, len(workflow.message_controls(model)))

        source = json.loads(files["handoff.json"])["source_identity"]
        no_registry_files = workflow.analyze(raw, source)
        no_registry_model = json.loads(no_registry_files["editable.json"])
        self.assertEqual([], workflow.call_controls(no_registry_model, no_registry_files))
        with self.assertRaisesRegex(ValueError, "DEF_MAIN.MES registry proof"):
            workflow.compile_edit(no_registry_files, operation)

        built = workflow.compile_edit(files, operation)
        diff_positions = [index for index in range(len(raw)) if raw[index] != built["output.mes"][index]]
        self.assertEqual(1, len(diff_positions))
        proof = json.loads(built["semantic.diff.json"])
        self.assertEqual("registered_definition_call_edit", proof["operation"]["family"])
        self.assertEqual(0, proof["container_diff"]["code_delta"])
        self.assertEqual(files, {key: built[key] for key in files})

    def test_registered_call_rejects_stale_unregistered_unchanged_or_unsafe_edits(self):
        _raw, files, operation, _registry_payload = self.registered_call_fixture()
        for field, value in (("instruction_raw_sha256", "f" * 64), ("selector", 9),
                             ("kind", "delete_instruction")):
            with self.subTest(field=field, value=value):
                changed = dict(operation, **{field: value})
                with self.assertRaises(ValueError):
                    workflow.compile_edit(files, changed)
        unchanged = dict(operation, selector=3)
        with self.assertRaisesRegex(ValueError, "unchanged"):
            workflow.compile_edit(files, unchanged)

    def test_registered_call_publish_read_bundle_and_legacy_bundle_round_trip(self):
        raw, files, operation, _registry_payload = self.registered_call_fixture()
        built = workflow.compile_edit(files, operation)
        with tempfile.TemporaryDirectory() as tmp:
            destination = Path(tmp) / "bundle"
            manifest = workflow.publish(destination, built)
            self.assertEqual(workflow.SCHEMA, manifest["schema"])
            self.assertEqual(
                {"state_controls", "message_controls", "condition_controls",
                 "resource_controls", "choice_controls", "call_controls"},
                set(manifest["summary"]) & {"state_controls", "message_controls", "condition_controls",
                                             "resource_controls", "choice_controls", "call_controls"},
            )
            self.assertIn(workflow.REGISTRY_MEMBER, {row["name"] for row in manifest["files"]})
            reopened, payloads = workflow.read_bundle(destination)
            self.assertEqual(manifest, reopened)
            self.assertEqual(built, payloads)

        # A registered-call bundle's own compiled operation needs the
        # registry member to recompile (compile_edit requires it for
        # `replace_registered_definition_literal`), so relabeling to a
        # legacy schema while keeping the member can only be exercised as
        # the "refused" direction on this bundle.
        with tempfile.TemporaryDirectory() as tmp:
            destination = Path(tmp) / "legacy_v5_with_registry"
            manifest = workflow.publish(destination, built)
            manifest["schema"] = "kakyu_mes_authoring_bundle/v5"
            manifest["summary"].pop("step_count")
            manifest["summary"].pop("operations")
            manifest["summary"].pop("control_target_controls")
            manifest["summary"].pop("shared_call_controls")
            manifest["summary"].pop("call_controls")
            manifest["payload_sha256"] = workflow.editable.fingerprint(manifest)
            (destination / "manifest.json").write_bytes(workflow._json(manifest))
            with self.assertRaisesRegex(ValueError, "cannot carry a registry proof"):
                workflow.read_bundle(destination)

    def shared_call_fixture(self):
        # Authored: a shared-routine call (command 0x1D, `1d 02 05 ff 00`,
        # routine 5); one CP932 message; a return. The library audit is a
        # synthetic LIBLARY.LIB audit built the way
        # tests/test_plan_mes_shared_routine_call_edit.py's
        # MesSharedRoutineCallEditPlanTests.return_routine() builds one,
        # wrapped exactly as its own fixture() wraps a library (schema,
        # archive_name "mes.arc", archive_sha256 "a"*64, entry "LIBLARY.LIB",
        # entry_sha256 "b"*64, source_archive_unchanged True) with routines 5
        # and 4 (both return-only, so both have proved total-return
        # contracts). Verified empirically against workflow.analyze: call (5
        # bytes, offset 0-4), message (4 bytes, offset 5-8), return (1 byte,
        # offset 9).
        raw = bytes.fromhex("0100000000000000" + "1d0205ff00" + "0182a000" + "00")
        source = {"archive": "mes.arc", "entry": "AUTHORED.MES",
                  "archive_sha256": "a" * 64, "source_kind": "original_arc"}
        library_audit = {
            "ok": True,
            "schema": workflow.shared_call_prover.LIBRARY_AUDIT_SCHEMA,
            "archive_name": "mes.arc",
            "archive_sha256": "a" * 64,
            "entry": "LIBLARY.LIB",
            "entry_sha256": "b" * 64,
            "source_archive_unchanged": True,
            "routines": [
                shared_call_plan_tests.MesSharedRoutineCallEditPlanTests.return_routine(5, 100, 90),
                shared_call_plan_tests.MesSharedRoutineCallEditPlanTests.return_routine(4, 200, 190),
            ],
        }
        files = workflow.analyze(raw, source, None, library_audit)
        model = json.loads(files["editable.json"])
        controls = workflow.shared_call_controls(model, files)
        self.assertEqual(1, len(controls))
        operation = copy.deepcopy(controls[0]["operation"])
        operation["routine_id"] = 4
        return raw, files, operation, library_audit

    def test_shared_call_candidate_and_compile_to_reopened_semantic_proof(self):
        raw, files, operation, _library_audit = self.shared_call_fixture()
        model = json.loads(files["editable.json"])
        shared_rows = workflow.shared_call_controls(model, files)
        self.assertEqual(1, len(shared_rows))
        row = shared_rows[0]
        self.assertEqual(0, row["operation"]["source_offset"])
        self.assertEqual(5, row["operation"]["routine_id"])
        self.assertEqual(5, row["end_offset"])
        self.assertEqual(5, row["physical_resume_offset"])
        self.assertEqual([4, 5], row["replaceable_routine_ids"])
        self.assertEqual(1, len(workflow.message_controls(model)))

        source = json.loads(files["handoff.json"])["source_identity"]
        no_library_files = workflow.analyze(raw, source)
        no_library_model = json.loads(no_library_files["editable.json"])
        self.assertEqual([], workflow.shared_call_controls(no_library_model, no_library_files))
        with self.assertRaisesRegex(ValueError, "Godot-built LIBLARY.LIB audit"):
            workflow.compile_edit(no_library_files, operation)

        built = workflow.compile_edit(files, operation)
        diff_positions = [index for index in range(len(raw)) if raw[index] != built["output.mes"][index]]
        self.assertEqual(1, len(diff_positions))
        proof = json.loads(built["semantic.diff.json"])
        self.assertEqual("shared_routine_call_edit", proof["operation"]["family"])
        self.assertEqual(0, proof["container_diff"]["code_delta"])
        self.assertEqual(files, {key: built[key] for key in files})

    def test_shared_call_rejects_stale_unknown_unchanged_or_unsafe_edits(self):
        _raw, files, operation, _library_audit = self.shared_call_fixture()
        for field, value in (("instruction_raw_sha256", "f" * 64), ("routine_id", 9),
                             ("kind", "delete_instruction")):
            with self.subTest(field=field, value=value):
                changed = dict(operation, **{field: value})
                with self.assertRaises(ValueError):
                    workflow.compile_edit(files, changed)
        unchanged = dict(operation, routine_id=5)
        with self.assertRaisesRegex(ValueError, "unchanged"):
            workflow.compile_edit(files, unchanged)

    def test_shared_call_publish_read_bundle_and_legacy_bundle_round_trip(self):
        raw, files, operation, _library_audit = self.shared_call_fixture()
        built = workflow.compile_edit(files, operation)
        with tempfile.TemporaryDirectory() as tmp:
            destination = Path(tmp) / "bundle"
            manifest = workflow.publish(destination, built)
            self.assertEqual(workflow.SCHEMA, manifest["schema"])
            self.assertEqual(
                {"state_controls", "message_controls", "condition_controls", "resource_controls",
                 "choice_controls", "call_controls", "shared_call_controls"},
                set(manifest["summary"]) & {"state_controls", "message_controls", "condition_controls",
                                             "resource_controls", "choice_controls", "call_controls",
                                             "shared_call_controls"},
            )
            self.assertIn(workflow.LIBRARY_MEMBER, {row["name"] for row in manifest["files"]})
            reopened, payloads = workflow.read_bundle(destination)
            self.assertEqual(manifest, reopened)
            self.assertEqual(built, payloads)

        # A shared-call bundle's own compiled operation needs the library
        # member to recompile (compile_edit requires it for
        # `replace_shared_routine_literal`), so relabeling to a legacy schema
        # while keeping the member can only be exercised as the "refused"
        # direction on this bundle.
        with tempfile.TemporaryDirectory() as tmp:
            destination = Path(tmp) / "legacy_v6_with_library"
            manifest = workflow.publish(destination, built)
            manifest["schema"] = "kakyu_mes_authoring_bundle/v6"
            manifest["summary"].pop("step_count")
            manifest["summary"].pop("operations")
            manifest["summary"].pop("control_target_controls")
            manifest["summary"].pop("shared_call_controls")
            manifest["payload_sha256"] = workflow.editable.fingerprint(manifest)
            (destination / "manifest.json").write_bytes(workflow._json(manifest))
            with self.assertRaisesRegex(ValueError, "cannot carry a library audit"):
                workflow.read_bundle(destination)

    def test_library_member_is_carried_for_other_kinds_and_prunable_to_legacy(self):
        # The library member is carried through any compiled bundle when the
        # source bundle had it (it is a source file, independent of which
        # control family was edited). Here it rides along a plain
        # state-literal edit: the "member removed - reads back as legacy"
        # direction from the spec exercises this bystander case, since a
        # shared-call-kind bundle cannot drop its own member and still
        # recompile.
        raw = bytes.fromhex("0100000000000000031e0101ff000182a00000")
        source = {"archive": "mes.arc", "entry": "AUTHORED.MES",
                  "archive_sha256": "a" * 64, "source_kind": "original_arc"}
        _raw, _files, _operation, library_audit = self.shared_call_fixture()
        files = workflow.analyze(raw, source, None, library_audit)
        self.assertIn(workflow.LIBRARY_MEMBER, files)
        operation = copy.deepcopy(workflow.state_controls(json.loads(files["editable.json"]))[0]["operation"])
        operation["value"] = 2
        built = workflow.compile_edit(files, operation)
        self.assertIn(workflow.LIBRARY_MEMBER, built)

        with tempfile.TemporaryDirectory() as tmp:
            destination = Path(tmp) / "legacy_v6"
            manifest = workflow.publish(destination, built)
            manifest["schema"] = "kakyu_mes_authoring_bundle/v6"
            manifest["summary"].pop("step_count")
            manifest["summary"].pop("operations")
            manifest["summary"].pop("control_target_controls")
            manifest["summary"].pop("shared_call_controls")
            manifest["files"] = [row for row in manifest["files"] if row["name"] != workflow.LIBRARY_MEMBER]
            manifest["payload_sha256"] = workflow.editable.fingerprint(manifest)
            (destination / "manifest.json").write_bytes(workflow._json(manifest))
            (destination / workflow.LIBRARY_MEMBER).unlink()
            expected = {key: value for key, value in built.items() if key != workflow.LIBRARY_MEMBER}
            self.assertEqual(expected, workflow.read_bundle(destination)[1])

    def test_registry_member_is_carried_for_other_kinds_and_prunable_to_legacy(self):
        # The registry member is carried through any compiled bundle when
        # the source bundle had it (it is a source file, independent of
        # which control family was edited) - the real CLI attaches it to
        # every inspected entry that has a DEF_MAIN.MES registry, regardless
        # of the edit the author later makes. Here it rides along a plain
        # state-literal edit: the "member removed - reads back as legacy"
        # direction from the spec exercises this bystander case, since a
        # registered-call-kind bundle cannot drop its own member and still
        # recompile.
        raw = bytes.fromhex("0100000000000000031e0101ff000182a00000")
        source = {"archive": "mes.arc", "entry": "AUTHORED.MES",
                  "archive_sha256": "a" * 64, "source_kind": "original_arc"}
        registry_payload = call_plan_tests.MesRegisteredDefinitionCallEditPlanTests.registry_payload(3, 4)
        registry_identity = {"archive": "mes.arc", "archive_sha256": "a" * 64,
                             "entry": "DEF_MAIN.MES",
                             "entry_sha256": hashlib.sha256(registry_payload).hexdigest()}
        registry_proof = workflow.registry_prover.prove_entry(registry_payload, registry_identity)
        files = workflow.analyze(raw, source, registry_proof)
        self.assertIn(workflow.REGISTRY_MEMBER, files)
        operation = copy.deepcopy(workflow.state_controls(json.loads(files["editable.json"]))[0]["operation"])
        operation["value"] = 2
        built = workflow.compile_edit(files, operation)
        self.assertIn(workflow.REGISTRY_MEMBER, built)

        with tempfile.TemporaryDirectory() as tmp:
            destination = Path(tmp) / "legacy_v5"
            manifest = workflow.publish(destination, built)
            manifest["schema"] = "kakyu_mes_authoring_bundle/v5"
            manifest["summary"].pop("step_count")
            manifest["summary"].pop("operations")
            manifest["summary"].pop("control_target_controls")
            manifest["summary"].pop("shared_call_controls")
            manifest["summary"].pop("call_controls")
            manifest["files"] = [row for row in manifest["files"] if row["name"] != workflow.REGISTRY_MEMBER]
            manifest["payload_sha256"] = workflow.editable.fingerprint(manifest)
            (destination / "manifest.json").write_bytes(workflow._json(manifest))
            (destination / workflow.REGISTRY_MEMBER).unlink()
            expected = {key: value for key, value in built.items() if key != workflow.REGISTRY_MEMBER}
            self.assertEqual(expected, workflow.read_bundle(destination)[1])

    def test_choice_controls_is_empty_without_a_group_clear(self):
        # State, condition and resource fixtures have no routine-40 group
        # clear (command 0x1B); choice_controls must return [] without ever
        # calling the CFG-prologue-sensitive group-entry prover.
        _raw, state_files, _op = self.fixture()
        _raw, condition_files, _op = self.condition_fixture()
        _raw, resource_files, _op = self.resource_fixture()
        for files in (state_files, condition_files, resource_files):
            model = json.loads(files["editable.json"])
            self.assertEqual([], workflow.choice_controls(model))

    def test_call_controls_is_empty_for_the_other_five_fixtures(self):
        # Only the registered-call fixture carries the archive's DEF_MAIN.MES
        # registry proof; call_controls must return [] for every other
        # family's bundle, without needing one.
        _raw, state_files, _op = self.fixture()
        _raw, condition_files, _op = self.condition_fixture()
        _raw, resource_files, _op = self.resource_fixture()
        _raw, choice_files, _op = self.choice_fixture()
        for files in (state_files, condition_files, resource_files, choice_files):
            model = json.loads(files["editable.json"])
            self.assertEqual([], workflow.call_controls(model, files))

    def test_shared_call_controls_is_empty_for_the_other_six_fixtures(self):
        # Only the shared-call fixture carries the Godot-built LIBLARY.LIB
        # audit; shared_call_controls must return [] for every other
        # family's bundle, without needing one.
        _raw, state_files, _op = self.fixture()
        _raw, condition_files, _op = self.condition_fixture()
        _raw, resource_files, _op = self.resource_fixture()
        _raw, choice_files, _op = self.choice_fixture()
        _raw, call_files, _op, _registry_payload = self.registered_call_fixture()
        message_raw = (2).to_bytes(4, "little") + bytes(4) + (4).to_bytes(4, "little")
        message_raw += bytes.fromhex("0182a000") + bytes.fromhex("0182a2000b01ff") + (4).to_bytes(4, "little") + b"\0"
        message_source = {"archive": "mes.arc", "entry": "AUTHORED.MES",
                          "archive_sha256": "a" * 64, "source_kind": "original_arc"}
        message_files = workflow.analyze(message_raw, message_source)
        for files in (state_files, condition_files, resource_files, choice_files, call_files, message_files):
            model = json.loads(files["editable.json"])
            self.assertEqual([], workflow.shared_call_controls(model, files))

    def control_target_fixture(self, kind="continuation"):
        # Authored: a continuation transfer (command 0x0C) or a conditional
        # branch (command 0x0B) retargeting to the message start; one CP932
        # message; two returns. Verified empirically against
        # workflow.analyze and analysis/mw11_control_target_synthetic_probe.py:
        # continuation - nodes at 0 (continuation_transfer), 5 (text), 9
        # (command_00), 10 (command_00); current target 10, code_size 11.
        # branch - nodes at 0 (branch_if_not_true), 7 (text), 11
        # (command_00), 12 (command_00); current target 12, code_size 13.
        hex_payload = {
            "continuation": "0100000000000000" + "0c0a000000" + "0182a000" + "00" + "00",
            "branch": "0100000000000000" + "0b01ff0c000000" + "0182a000" + "00" + "00",
        }[kind]
        raw = bytes.fromhex(hex_payload)
        source = {"archive": "mes.arc", "entry": "AUTHORED.MES",
                  "archive_sha256": "a" * 64, "source_kind": "original_arc"}
        files = workflow.analyze(raw, source)
        controls = workflow.control_target_controls(json.loads(files["editable.json"]))
        self.assertEqual(1, len(controls))
        operation = copy.deepcopy(controls[0]["operation"])
        operation["replacement_target_offset"] = 5 if kind == "continuation" else 7
        return raw, files, operation

    def test_control_target_candidate_and_compile_to_reopened_semantic_proof(self):
        for kind, current, code_size, replacement, expected_output in (
            ("continuation", 10, 11, 5, "01000000000000000c050000000182a0000000"),
            ("branch", 12, 13, 7, "01000000000000000b01ff070000000182a0000000"),
        ):
            with self.subTest(kind=kind):
                raw, files, operation = self.control_target_fixture(kind)
                model = json.loads(files["editable.json"])
                rows = workflow.control_target_controls(model)
                self.assertEqual(1, len(rows))
                row = rows[0]
                self.assertEqual(0, row["operation"]["source_offset"])
                self.assertEqual(
                    "continuation_target" if kind == "continuation" else "condition_false_target",
                    row["operation"]["reference_kind"],
                )
                self.assertEqual(current, row["current_target_offset"])
                self.assertEqual("command_00", row["current_target_op"])
                self.assertEqual(code_size, row["code_size"])

                built = workflow.compile_edit(files, operation)
                self.assertEqual(bytes.fromhex(expected_output), built["output.mes"])
                diff_positions = [index for index in range(len(raw)) if raw[index] != built["output.mes"][index]]
                self.assertEqual(1, len(diff_positions))
                audit = json.loads(built["compile.audit.json"])
                self.assertEqual("kakyu_mes_control_target_edit_compile_audit/v1", audit["schema"])
                self.assertEqual(replacement, audit["operation"]["replacement_target_offset"])
                plan = json.loads(built["plan.json"])
                self.assertEqual(
                    {"kind", "source_offset", "reference_kind", "source_instruction_raw_sha256",
                     "replacement_target_offset", "replacement_target_instruction_raw_sha256"},
                    set(plan["operation"]),
                )
                message_node = next(
                    node for node in model["source_ir"]["nodes"] if node["source"]["start"] == replacement
                )
                self.assertEqual(
                    message_node["source"]["raw_sha256"],
                    plan["operation"]["replacement_target_instruction_raw_sha256"],
                )
                proof = json.loads(built["semantic.diff.json"])
                self.assertEqual("kakyu_mes_semantic_diff/v2", proof["schema"])
                self.assertEqual(files, {key: built[key] for key in files})

                with tempfile.TemporaryDirectory() as tmp:
                    destination = Path(tmp) / f"bundle_{kind}"
                    manifest = workflow.publish(destination, built)
                    self.assertEqual(workflow.SCHEMA, manifest["schema"])
                    self.assertIn("control_target_controls", manifest["summary"])
                    reopened, payloads = workflow.read_bundle(destination)
                    self.assertEqual(manifest, reopened)
                    self.assertEqual(built, payloads)

    def test_control_target_rejects_stale_out_of_range_unchanged_or_bad_reference_edits(self):
        _raw, files, operation = self.control_target_fixture("continuation")
        for field, value in (("source_instruction_raw_sha256", "f" * 64),
                             ("replacement_target_offset", 6), ("replacement_target_offset", 999),
                             ("replacement_target_instruction_raw_sha256", "f" * 64),
                             ("reference_kind", "bogus_reference_kind"),
                             ("kind", "delete_instruction")):
            with self.subTest(field=field, value=value):
                changed = dict(operation, **{field: value})
                with self.assertRaises(ValueError):
                    workflow.compile_edit(files, changed)
        unchanged = dict(operation, replacement_target_offset=10)
        with self.assertRaisesRegex(ValueError, "unchanged"):
            workflow.compile_edit(files, unchanged)

    def test_control_target_publish_read_bundle_and_legacy_bundle_round_trip(self):
        _raw, files, operation = self.control_target_fixture("continuation")
        built = workflow.compile_edit(files, operation)
        with tempfile.TemporaryDirectory() as tmp:
            destination = Path(tmp) / "legacy_v7"
            manifest = workflow.publish(destination, built)
            manifest["schema"] = "kakyu_mes_authoring_bundle/v7"
            manifest["summary"].pop("step_count")
            manifest["summary"].pop("operations")
            manifest["summary"].pop("control_target_controls")
            manifest["payload_sha256"] = workflow.editable.fingerprint(manifest)
            (destination / "manifest.json").write_bytes(workflow._json(manifest))
            self.assertEqual(built, workflow.read_bundle(destination)[1])

    def test_control_target_controls_matches_measured_rows_for_the_other_seven_fixtures(self):
        # The condition fixture's branch and the choice/message fixtures'
        # transfers give them real control-target candidates too; only the
        # state, resource, registered-call and shared-call fixtures (no
        # branch or continuation transfer) are empty.
        _raw, state_files, _op = self.fixture()
        _raw, condition_files, _op = self.condition_fixture()
        _raw, resource_files, _op = self.resource_fixture()
        _raw, choice_files, _op = self.choice_fixture()
        _raw, call_files, _op, _registry_payload = self.registered_call_fixture()
        _raw, _files, _op, _library_audit = self.shared_call_fixture()
        shared_call_files = _files
        message_raw = (2).to_bytes(4, "little") + bytes(4) + (4).to_bytes(4, "little")
        message_raw += bytes.fromhex("0182a000") + bytes.fromhex("0182a2000b01ff") + (4).to_bytes(4, "little") + b"\0"
        message_source = {"archive": "mes.arc", "entry": "AUTHORED.MES",
                          "archive_sha256": "a" * 64, "source_kind": "original_arc"}
        message_files = workflow.analyze(message_raw, message_source)
        for files in (state_files, resource_files, call_files, shared_call_files):
            model = json.loads(files["editable.json"])
            self.assertEqual([], workflow.control_target_controls(model))

        condition_model = json.loads(condition_files["editable.json"])
        condition_rows = workflow.control_target_controls(condition_model)
        self.assertEqual(1, len(condition_rows))
        self.assertEqual(0, condition_rows[0]["operation"]["source_offset"])
        self.assertEqual("condition_false_target", condition_rows[0]["operation"]["reference_kind"])
        self.assertEqual(15, condition_rows[0]["current_target_offset"])
        self.assertEqual("command_00", condition_rows[0]["current_target_op"])
        self.assertEqual(16, condition_rows[0]["code_size"])

        choice_model = json.loads(choice_files["editable.json"])
        choice_rows = workflow.control_target_controls(choice_model)
        self.assertEqual(2, len(choice_rows))
        self.assertEqual([57, 73], [row["operation"]["source_offset"] for row in choice_rows])
        self.assertEqual(["condition_false_target", "continuation_target"],
                         [row["operation"]["reference_kind"] for row in choice_rows])
        self.assertEqual([73, 79], [row["current_target_offset"] for row in choice_rows])
        self.assertEqual(["continuation_transfer", "command_00"], [row["current_target_op"] for row in choice_rows])

        message_model = json.loads(message_files["editable.json"])
        message_rows = workflow.control_target_controls(message_model)
        self.assertEqual(1, len(message_rows))
        self.assertEqual(8, message_rows[0]["operation"]["source_offset"])
        self.assertEqual("condition_false_target", message_rows[0]["operation"]["reference_kind"])
        self.assertEqual(4, message_rows[0]["current_target_offset"])
        self.assertEqual("text", message_rows[0]["current_target_op"])
        self.assertEqual(16, message_rows[0]["code_size"])

    def test_source_paths_and_rehashed_evidence_are_rejected(self):
        raw, files, _operation = self.fixture()
        source = json.loads(files["handoff.json"])["source_identity"]
        with self.assertRaisesRegex(ValueError, "path-free"):
            workflow.analyze(raw, dict(source, entry="../AUTHORED.MES"))
        edited = json.loads(files["editable.json"])
        edited["source_ir"]["source_identity"]["entry"] = "OTHER.MES"
        changed = dict(files, **{"editable.json": workflow._json(edited)})
        with self.assertRaises(ValueError):
            workflow._validate_files(changed)


if __name__ == "__main__":
    unittest.main()
