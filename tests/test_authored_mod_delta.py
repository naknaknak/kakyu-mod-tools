from __future__ import annotations

import copy
import json
from pathlib import Path
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
sys.path.insert(0, str(ROOT / "tests"))
import authored_mod_delta as delta
import mes_authoring_workflow as workflow

import test_plan_mes_registered_definition_call_edit as call_plan_tests  # noqa: E402
import test_plan_mes_shared_routine_call_edit as shared_call_plan_tests  # noqa: E402


class AuthoredDeltaTests(unittest.TestCase):
    def fixture(self):
        source = bytes.fromhex("0100000000000000031e0101ff000182a00000")
        identity = {"archive": "mes.arc", "entry": "AUTHORED.MES", "source_kind": "original_arc", "archive_sha256": "a" * 64}
        files = workflow.analyze(source, identity)
        operation = workflow.state_controls(json.loads(files["editable.json"]))[0]["operation"]
        operation["value"] = 2
        built = workflow.compile_sequence(files, [operation])
        edits = [{"source_offset": 6, "raw_sha256": workflow._sha(bytes.fromhex("82a0")), "text": "새로운 번역"}]
        return source, identity, built, delta.build(built, source, edits)

    def test_delta_reconstructs_exact_output_and_proof_without_original_payload(self):
        source, identity, files, document = self.fixture()
        self.assertEqual(files, delta.reconstruct(document, source, identity))
        serialized = workflow._json(document)
        for original in (source.hex().encode(), files["output.mes"].hex().encode(), b'"raw_hex"', b'"handoff"', b'"source_path"'):
            self.assertNotIn(original, serialized)
        self.assertIn("새로운 번역".encode(), serialized)

    def test_rehashed_extra_payload_fields_wrong_sources_and_changed_outputs_fail(self):
        source, identity, _, document = self.fixture()
        for mutate in (lambda d: d.update(raw_hex=source.hex()),
                       lambda d: d["operations"][0].update(value=True),
                       lambda d: d["text_edits"][0].update(source_offset=7),
                       lambda d: d.update(output_entry_sha256="f" * 64),
                       lambda d: d.update(compatibility={}),
                       lambda d: d["source"].update(entry="../AUTHORED.MES")):
            changed = copy.deepcopy(document)
            mutate(changed)
            changed["payload_sha256"] = delta.fingerprint(changed)
            with self.assertRaises(ValueError):
                delta.reconstruct(changed, source, identity)
        with self.assertRaises(ValueError):
            delta.reconstruct(document, source + b"\0", identity)
        with self.assertRaises(ValueError):
            delta.reconstruct(document, source, dict(identity, archive_sha256="b" * 64))

    def condition_fixture(self):
        source = bytes.fromhex("01000000000000000bf3010001efff0f0000000182a00000")
        identity = {"archive": "mes.arc", "entry": "AUTHORED.MES", "source_kind": "original_arc", "archive_sha256": "a" * 64}
        files = workflow.analyze(source, identity)
        operation = workflow.condition_controls(json.loads(files["editable.json"]))[0]["operation"]
        operation["value"] = 2
        built = workflow.compile_sequence(files, [operation])
        return source, identity, built, delta.build(built, source, [])

    def test_condition_delta_reconstructs_exact_output(self):
        source, identity, files, document = self.condition_fixture()
        self.assertEqual(delta.SCHEMA, document["schema"])
        self.assertEqual("replace_condition_literal", document["operations"][0]["kind"])
        self.assertEqual([], document["dependencies"])
        self.assertEqual(files, delta.reconstruct(document, source, identity))

    def test_condition_delta_relabeled_v2_is_rejected(self):
        _source, _identity, _files, document = self.condition_fixture()
        document = dict(document, schema=delta.LEGACY_SCHEMA_V2, compatibility=delta.LEGACY_COMPATIBILITY_V2)
        document["payload_sha256"] = delta.fingerprint(document)
        with self.assertRaises(ValueError):
            delta.validate(document)

    def test_condition_delta_relabeled_v3_validates_with_v3_compatibility(self):
        source, identity, files, document = self.condition_fixture()
        self.assertEqual(delta.SCHEMA, document["schema"])
        document["operation"] = document.pop("operations")[0]
        document = dict(document, schema=delta.LEGACY_SCHEMA_V3, compatibility=delta.LEGACY_COMPATIBILITY_V3)
        del document["dependencies"]
        document["payload_sha256"] = delta.fingerprint(document)
        delta.validate(document)
        self.assertEqual(files, delta.reconstruct(document, source, identity))

    def resource_fixture(self):
        source = bytes.fromhex("01000000000000000d09ff017a2e6d6d6f00000182a00000")
        identity = {"archive": "mes.arc", "entry": "AUTHORED.MES", "source_kind": "original_arc", "archive_sha256": "a" * 64}
        files = workflow.analyze(source, identity)
        operation = dict(workflow.resource_controls(json.loads(files["editable.json"]))[0]["operation"], name="x.mmo")
        built = workflow.compile_sequence(files, [operation])
        return source, identity, built, delta.build(built, source, [])

    def test_resource_name_delta_reconstructs_exact_output(self):
        source, identity, files, document = self.resource_fixture()
        self.assertEqual(delta.SCHEMA, document["schema"])
        self.assertEqual("replace_resource_name", document["operations"][0]["kind"])
        self.assertEqual(files, delta.reconstruct(document, source, identity))

    def test_resource_name_delta_relabeled_v3_is_rejected(self):
        _source, _identity, _files, document = self.resource_fixture()
        document = dict(document, schema=delta.LEGACY_SCHEMA_V3, compatibility=delta.LEGACY_COMPATIBILITY_V3)
        document["payload_sha256"] = delta.fingerprint(document)
        with self.assertRaises(ValueError):
            delta.validate(document)

    def test_v2_message_delta_relabeled_from_v3_build_validates_with_v2_compatibility(self):
        source = (2).to_bytes(4, "little") + bytes(4) + (4).to_bytes(4, "little")
        source += bytes.fromhex("0182a000") + bytes.fromhex("0182a2000b01ff") + (4).to_bytes(4, "little") + b"\0"
        identity = {"archive": "mes.arc", "entry": "AUTHORED.MES", "source_kind": "original_arc", "archive_sha256": "a" * 64}
        files = workflow.analyze(source, identity)
        operation = dict(workflow.message_controls(json.loads(files["editable.json"]))[0]["operation"], text="変更確認")
        built = workflow.compile_sequence(files, [operation])
        document = delta.build(built, source, [])
        self.assertEqual(delta.SCHEMA, document["schema"])
        document["operation"] = document.pop("operations")[0]
        document = dict(document, schema=delta.LEGACY_SCHEMA_V2, compatibility=delta.LEGACY_COMPATIBILITY_V2)
        del document["dependencies"]
        document["payload_sha256"] = delta.fingerprint(document)
        delta.validate(document)
        self.assertEqual(built, delta.reconstruct(document, source, identity))

    def test_v3_message_delta_relabeled_from_v4_build_validates_with_v3_compatibility(self):
        source = (2).to_bytes(4, "little") + bytes(4) + (4).to_bytes(4, "little")
        source += bytes.fromhex("0182a000") + bytes.fromhex("0182a2000b01ff") + (4).to_bytes(4, "little") + b"\0"
        identity = {"archive": "mes.arc", "entry": "AUTHORED.MES", "source_kind": "original_arc", "archive_sha256": "a" * 64}
        files = workflow.analyze(source, identity)
        operation = dict(workflow.message_controls(json.loads(files["editable.json"]))[0]["operation"], text="変更確認")
        built = workflow.compile_sequence(files, [operation])
        document = delta.build(built, source, [])
        document["operation"] = document.pop("operations")[0]
        document = dict(document, schema=delta.LEGACY_SCHEMA_V3, compatibility=delta.LEGACY_COMPATIBILITY_V3)
        del document["dependencies"]
        document["payload_sha256"] = delta.fingerprint(document)
        delta.validate(document)
        self.assertEqual(built, delta.reconstruct(document, source, identity))

    def choice_fixture(self):
        # Authored: tests.test_prove_mes_choice_group_authoring._fixture()'s
        # own container (two routine-40 groups: group 0 definition 0 text
        # "FIRST", 5 bytes; group 1 definition 0 text "SECOND02", 8 bytes).
        source = bytes.fromhex(
            "010000000000000017000000001b0200ff00100200ff001b00000001464952"
            "535400001b0201ff00100200ff0034000000015345434f4e44303200001d0228ff"
            "000b801501ef800d01efe6ff49000000000c4f0000000000"
        )
        identity = {"archive": "mes.arc", "entry": "AUTHORED.MES", "source_kind": "original_arc", "archive_sha256": "a" * 64}
        files = workflow.analyze(source, identity)
        operation = dict(workflow.choice_controls(json.loads(files["editable.json"]))[0]["operation"], text="OTHER")
        built = workflow.compile_sequence(files, [operation])
        return source, identity, built, delta.build(built, source, [])

    def test_choice_delta_build_validate_and_reconstruct(self):
        source, identity, files, document = self.choice_fixture()
        self.assertEqual(delta.SCHEMA, document["schema"])
        self.assertEqual("replace_choice_option_cp932_same_length", document["operations"][0]["kind"])
        delta.validate(document)
        self.assertEqual(files, delta.reconstruct(document, source, identity))

    def test_choice_delta_relabeled_v4_is_rejected(self):
        _source, _identity, _files, document = self.choice_fixture()
        document = dict(document, schema=delta.LEGACY_SCHEMA_V4, compatibility=delta.LEGACY_COMPATIBILITY_V4)
        document["payload_sha256"] = delta.fingerprint(document)
        with self.assertRaises(ValueError):
            delta.validate(document)

    def test_resource_name_delta_relabeled_v4_from_v5_build_validates_with_v4_compatibility(self):
        source, identity, files, document = self.resource_fixture()
        self.assertEqual(delta.SCHEMA, document["schema"])
        document["operation"] = document.pop("operations")[0]
        document = dict(document, schema=delta.LEGACY_SCHEMA_V4, compatibility=delta.LEGACY_COMPATIBILITY_V4)
        del document["dependencies"]
        document["payload_sha256"] = delta.fingerprint(document)
        delta.validate(document)
        self.assertEqual(files, delta.reconstruct(document, source, identity))

    def test_choice_delta_relabeled_v5_from_v6_build_validates_with_v5_compatibility(self):
        source, identity, files, document = self.choice_fixture()
        self.assertEqual(delta.SCHEMA, document["schema"])
        document["operation"] = document.pop("operations")[0]
        document = dict(document, schema=delta.LEGACY_SCHEMA_V5, compatibility=delta.LEGACY_COMPATIBILITY_V5)
        del document["dependencies"]
        document["payload_sha256"] = delta.fingerprint(document)
        delta.validate(document)
        self.assertEqual(files, delta.reconstruct(document, source, identity))

    def registered_call_fixture(self):
        # Authored: a registered-definition call (selector 3) over the
        # registry payload from
        # tests/test_plan_mes_registered_definition_call_edit.py's
        # MesRegisteredDefinitionCallEditPlanTests.registry_payload(3, 4)
        # (registrations for selectors 3 and 4), proved as the archive's
        # DEF_MAIN.MES; one CP932 message; a return.
        source = bytes.fromhex("0100000000000000110203ff000182a00000")
        identity = {"archive": "mes.arc", "entry": "AUTHORED.MES", "source_kind": "original_arc", "archive_sha256": "a" * 64}
        registry_payload = call_plan_tests.MesRegisteredDefinitionCallEditPlanTests.registry_payload(3, 4)
        registry_identity = {"archive": "mes.arc", "archive_sha256": "a" * 64, "entry": "DEF_MAIN.MES",
                             "entry_sha256": workflow._sha(registry_payload)}
        registry_proof = workflow.registry_prover.prove_entry(registry_payload, registry_identity)
        files = workflow.analyze(source, identity, registry_proof)
        operation = dict(workflow.call_controls(json.loads(files["editable.json"]), files)[0]["operation"], selector=4)
        built = workflow.compile_sequence(files, [operation])
        return source, identity, registry_payload, built, delta.build(built, source, [])

    def test_registered_call_delta_build_validate_and_reconstruct(self):
        source, identity, registry_payload, files, document = self.registered_call_fixture()
        self.assertEqual(delta.SCHEMA, document["schema"])
        self.assertEqual("replace_registered_definition_literal", document["operations"][0]["kind"])
        self.assertEqual(
            [{"entry": "DEF_MAIN.MES", "entry_sha256": workflow._sha(registry_payload)}],
            document["dependencies"],
        )
        delta.validate(document)
        self.assertEqual(files, delta.reconstruct(document, source, identity, {"DEF_MAIN.MES": registry_payload}))

    def test_registered_call_delta_reconstruct_needs_the_matching_dependency(self):
        source, identity, registry_payload, _files, document = self.registered_call_fixture()
        with self.assertRaisesRegex(ValueError, "missing or changed"):
            delta.reconstruct(document, source, identity)
        with self.assertRaisesRegex(ValueError, "missing or changed"):
            delta.reconstruct(document, source, identity, {"DEF_MAIN.MES": registry_payload + b"\0"})
        with self.assertRaisesRegex(ValueError, "missing or changed"):
            delta.reconstruct(document, source, identity, {"OTHER.MES": registry_payload})

    def test_registered_call_delta_relabeled_v5_is_rejected(self):
        _source, _identity, _registry_payload, _files, document = self.registered_call_fixture()
        document = dict(document, schema=delta.LEGACY_SCHEMA_V5, compatibility=delta.LEGACY_COMPATIBILITY_V5)
        document["payload_sha256"] = delta.fingerprint(document)
        with self.assertRaises(ValueError):
            delta.validate(document)

    def shared_call_fixture(self):
        # Authored: a shared-routine call (command 0x1D, `1d 02 05 ff 00`,
        # routine 5) over a synthetic LIBLARY.LIB audit (routines 5 and 4,
        # both return-only) built the way
        # tests/test_plan_mes_shared_routine_call_edit.py's
        # MesSharedRoutineCallEditPlanTests.return_routine() builds one; one
        # CP932 message; a return.
        source = bytes.fromhex("0100000000000000" + "1d0205ff00" + "0182a000" + "00")
        identity = {"archive": "mes.arc", "entry": "AUTHORED.MES", "source_kind": "original_arc", "archive_sha256": "a" * 64}
        library_payload = b"synthetic-library-payload"
        library_audit = {
            "ok": True,
            "schema": workflow.shared_call_prover.LIBRARY_AUDIT_SCHEMA,
            "archive_name": "mes.arc",
            "archive_sha256": "a" * 64,
            "entry": "LIBLARY.LIB",
            "entry_sha256": workflow._sha(library_payload),
            "source_archive_unchanged": True,
            "routines": [
                shared_call_plan_tests.MesSharedRoutineCallEditPlanTests.return_routine(5, 100, 90),
                shared_call_plan_tests.MesSharedRoutineCallEditPlanTests.return_routine(4, 200, 190),
            ],
        }
        files = workflow.analyze(source, identity, None, library_audit)
        operation = dict(workflow.shared_call_controls(json.loads(files["editable.json"]), files)[0]["operation"], routine_id=4)
        built = workflow.compile_sequence(files, [operation])
        return source, identity, library_payload, library_audit, built, delta.build(built, source, [])

    def test_shared_call_delta_build_validate_and_reconstruct(self):
        source, identity, library_payload, library_audit, files, document = self.shared_call_fixture()
        self.assertEqual(delta.SCHEMA, document["schema"])
        self.assertEqual("replace_shared_routine_literal", document["operations"][0]["kind"])
        self.assertEqual(
            [{"entry": "LIBLARY.LIB", "entry_sha256": library_audit["entry_sha256"]}],
            document["dependencies"],
        )
        delta.validate(document)
        self.assertEqual(
            files,
            delta.reconstruct(document, source, identity, {"LIBLARY.LIB": library_payload}, library_audit),
        )

    def test_shared_call_delta_reconstruct_needs_the_matching_library_audit(self):
        source, identity, library_payload, library_audit, _files, document = self.shared_call_fixture()
        with self.assertRaisesRegex(ValueError, "Godot-built library audit"):
            delta.reconstruct(document, source, identity, {"LIBLARY.LIB": library_payload})
        changed_audit = dict(library_audit, entry_sha256="f" * 64)
        with self.assertRaisesRegex(ValueError, "Godot-built library audit"):
            delta.reconstruct(document, source, identity, {"LIBLARY.LIB": library_payload}, changed_audit)
        with self.assertRaisesRegex(ValueError, "missing or changed"):
            delta.reconstruct(document, source, identity, {}, library_audit)

    def test_shared_call_delta_relabeled_v6_is_rejected(self):
        _source, _identity, _library_payload, _library_audit, _files, document = self.shared_call_fixture()
        document = dict(document, schema=delta.LEGACY_SCHEMA_V6, compatibility=delta.LEGACY_COMPATIBILITY_V6)
        document["payload_sha256"] = delta.fingerprint(document)
        with self.assertRaises(ValueError):
            delta.validate(document)

    def control_target_fixture(self):
        # Authored: a continuation transfer (command 0x0C) retargeting to
        # the message start; one CP932 message; two returns. Same caller
        # hex as tests/test_mes_authoring_workflow.py's
        # control_target_fixture()'s continuation entry.
        source = bytes.fromhex("0100000000000000" + "0c0a000000" + "0182a000" + "00" + "00")
        identity = {"archive": "mes.arc", "entry": "AUTHORED.MES", "source_kind": "original_arc", "archive_sha256": "a" * 64}
        files = workflow.analyze(source, identity)
        operation = dict(workflow.control_target_controls(json.loads(files["editable.json"]))[0]["operation"],
                         replacement_target_offset=5)
        built = workflow.compile_sequence(files, [operation])
        return source, identity, built, delta.build(built, source, [])

    def test_control_target_delta_build_validate_and_reconstruct(self):
        source, identity, files, document = self.control_target_fixture()
        self.assertEqual(delta.SCHEMA, document["schema"])
        self.assertEqual("retarget_control_flow", document["operations"][0]["kind"])
        self.assertEqual([], document["dependencies"])
        delta.validate(document)
        self.assertEqual(files, delta.reconstruct(document, source, identity))

    def test_control_target_delta_relabeled_v7_is_rejected(self):
        _source, _identity, _files, document = self.control_target_fixture()
        document = dict(document, schema=delta.LEGACY_SCHEMA_V7, compatibility=delta.LEGACY_COMPATIBILITY_V7)
        document["payload_sha256"] = delta.fingerprint(document)
        with self.assertRaises(ValueError):
            delta.validate(document)

    def test_control_target_delta_operation_keys_are_validated(self):
        _source, _identity, _files, document = self.control_target_fixture()
        for mutate in (
            lambda op: op.pop("source_instruction_raw_sha256"),
            lambda op: op.update(reference_kind="bogus_reference_kind"),
            lambda op: op.update(source_offset=True),
        ):
            changed = copy.deepcopy(document)
            mutate(changed["operations"][0])
            changed["payload_sha256"] = delta.fingerprint(changed)
            with self.assertRaises(ValueError):
                delta.validate(changed)

    def test_allowed_kinds_admits_replace_message_from_v2_through_v9(self):
        source = (2).to_bytes(4, "little") + bytes(4) + (4).to_bytes(4, "little")
        source += bytes.fromhex("0182a000") + bytes.fromhex("0182a2000b01ff") + (4).to_bytes(4, "little") + b"\0"
        identity = {"archive": "mes.arc", "entry": "AUTHORED.MES", "source_kind": "original_arc", "archive_sha256": "a" * 64}
        files = workflow.analyze(source, identity)
        operation = dict(workflow.message_controls(json.loads(files["editable.json"]))[0]["operation"], text="変更確認")
        built = workflow.compile_sequence(files, [operation])
        document = delta.build(built, source, [])
        self.assertEqual(delta.SCHEMA, document["schema"])
        for schema, compatibility in (
            (delta.SCHEMA, delta.COMPATIBILITY),
            (delta.LEGACY_SCHEMA_V2, delta.LEGACY_COMPATIBILITY_V2),
            (delta.LEGACY_SCHEMA_V3, delta.LEGACY_COMPATIBILITY_V3),
            (delta.LEGACY_SCHEMA_V4, delta.LEGACY_COMPATIBILITY_V4),
            (delta.LEGACY_SCHEMA_V5, delta.LEGACY_COMPATIBILITY_V5),
            (delta.LEGACY_SCHEMA_V6, delta.LEGACY_COMPATIBILITY_V6),
            (delta.LEGACY_SCHEMA_V7, delta.LEGACY_COMPATIBILITY_V7),
            (delta.LEGACY_SCHEMA_V8, delta.LEGACY_COMPATIBILITY_V8),
        ):
            with self.subTest(schema=schema):
                if schema == delta.SCHEMA:
                    relabeled = dict(document, schema=schema, compatibility=compatibility)
                else:
                    relabeled = dict(document, operation=document["operations"][0], schema=schema, compatibility=compatibility)
                    del relabeled["operations"]
                    if schema not in delta.SCHEMAS_WITH_DEPENDENCIES:
                        del relabeled["dependencies"]
                relabeled["payload_sha256"] = delta.fingerprint(relabeled)
                delta.validate(relabeled)
                self.assertEqual(built, delta.reconstruct(relabeled, source, identity))

    def sequence_fixture(self):
        # Authored: the MW-11 sequence spec's synthetic entry (nodes at 0
        # global_u8_write_run, 6 continuation_transfer target 0x10, 11 text
        # "あ", 15/16 command_00). Sequence S = [state literal value 2,
        # retarget 16 -> 11, replace_message "変更確認"].
        source = bytes.fromhex("0100000000000000031e0101ff000c100000000182a0000000")
        identity = {"archive": "mes.arc", "entry": "AUTHORED.MES", "source_kind": "original_arc", "archive_sha256": "a" * 64}
        files = workflow.analyze(source, identity)
        model = json.loads(files["editable.json"])
        state_op = dict(workflow.state_controls(model)[0]["operation"], value=2)
        control_op = dict(workflow.control_target_controls(model)[0]["operation"], replacement_target_offset=11)
        message_op = dict(workflow.message_controls(model)[0]["operation"], text="変更確認")
        operations = [state_op, control_op, message_op]
        built = workflow.compile_sequence(files, operations)
        return source, identity, built, delta.build(built, source, [])

    def test_sequence_delta_build_validate_and_reconstruct(self):
        source, identity, files, document = self.sequence_fixture()
        self.assertEqual(delta.SCHEMA, document["schema"])
        self.assertEqual(3, len(document["operations"]))
        self.assertEqual(
            ["replace_state_write_literal", "retarget_control_flow", "replace_message"],
            [op["kind"] for op in document["operations"]],
        )
        self.assertEqual([], document["dependencies"])
        delta.validate(document)
        reconstructed = delta.reconstruct(document, source, identity)
        self.assertEqual(files, reconstructed)
        self.assertEqual(files["output.mes"], reconstructed["output.mes"])
        self.assertEqual(
            json.loads(files["semantic.diff.json"])["payload_sha256"],
            json.loads(reconstructed["semantic.diff.json"])["payload_sha256"],
        )

    def test_sequence_delta_relabeled_v8_is_rejected(self):
        _source, _identity, _files, document = self.sequence_fixture()
        document = dict(document, schema=delta.LEGACY_SCHEMA_V8, compatibility=delta.LEGACY_COMPATIBILITY_V8)
        document["payload_sha256"] = delta.fingerprint(document)
        with self.assertRaises(ValueError):
            delta.validate(document)

    def test_v9_single_operation_delta_round_trips(self):
        source, identity, files, document = self.fixture()
        self.assertEqual(delta.SCHEMA, document["schema"])
        self.assertEqual(1, len(document["operations"]))
        delta.validate(document)
        self.assertEqual(files, delta.reconstruct(document, source, identity))

    def test_legacy_v8_single_operation_document_still_reconstructs(self):
        source, identity, files, document = self.fixture()
        document["operation"] = document.pop("operations")[0]
        document.update(schema=delta.LEGACY_SCHEMA_V8, compatibility=delta.LEGACY_COMPATIBILITY_V8)
        document["payload_sha256"] = delta.fingerprint(document)
        delta.validate(document)
        self.assertEqual(files, delta.reconstruct(document, source, identity))

    def test_atomic_publication_preserves_existing_output_and_rejects_tampering(self):
        _, _, _, document = self.fixture()
        with tempfile.TemporaryDirectory() as root:
            path = Path(root) / "authored.delta.json"
            delta.publish(path, document)
            self.assertEqual(document, delta.read(path))
            before = path.read_bytes()
            with self.assertRaises(FileExistsError):
                delta.publish(path, document)
            self.assertEqual(before, path.read_bytes())
            self.assertEqual([path], list(Path(root).iterdir()))
            changed = copy.deepcopy(document)
            changed["text_edits"][0]["text"] = "tampered"
            path.write_text(json.dumps(changed), encoding="utf-8")
            with self.assertRaises(ValueError):
                delta.read(path)


if __name__ == "__main__":
    unittest.main()
