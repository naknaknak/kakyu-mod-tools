from __future__ import annotations

import copy
import hashlib
import sys
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

import decompile_mes_handoff as decompiler  # noqa: E402
import plan_mes_resource_name_edit as planner  # noqa: E402
import prepare_mes_editable_ir as editable_ir  # noqa: E402
import validate_mes_analyzer_handoff as handoff_validator  # noqa: E402


class MesResourceNameEditPlanTests(unittest.TestCase):
    def fixture(
        self,
        *,
        op: str = "mmo_resource_marker",
        source_name: str = "w.mmo",
        replacement_name: str = "y.mmo",
    ) -> tuple[dict, dict]:
        forms = {
            "mmo_resource_marker": {
                # 0x0D framing since Core 0.316.0; formerly a separator plus a 0x09 record.
                "command_id": 0x0D,
                "resource_kind": "mmo",
                "operand_kind": "mmo_marker",
                "prefix": bytes.fromhex("0d09ff01"),
                "suffix": bytes.fromhex("0000"),
                "normalized": source_name,
                "archives": ["mmo.arc"],
            },
            "ax_resource_marker": {
                "command_id": 0x0D,
                "resource_kind": "ax",
                "operand_kind": "ax_marker",
                "prefix": bytes.fromhex("0d08ff0200ff01"),
                "suffix": bytes.fromhex("000202f900ff00"),
                "normalized": source_name.rsplit(".", 1)[0].upper() + ".AX",
                "archives": ["data.arc"],
            },
            "voice_marker": {
                "command_id": 0x0D,
                "resource_kind": "voice",
                "operand_kind": "voice_marker",
                "prefix": bytes.fromhex("0d07ff0202ff01"),
                "suffix": bytes.fromhex("000200ff00"),
                "normalized": source_name.rsplit(".", 1)[0].upper() + ".OGG",
                "archives": ["voice.arc", "tina1.arc", "tina2.arc"],
            },
        }
        form = forms[op]
        name_raw = source_name.encode("ascii")
        code = form["prefix"] + name_raw + form["suffix"]
        name_offset = len(form["prefix"])
        preamble = (1).to_bytes(4, "little") + (0).to_bytes(4, "little")
        raw = preamble + code
        operand = {
            "type": "resource_name",
            "resource_kind": form["operand_kind"],
            "name": form["normalized"],
            "raw_bytes": {"$packed_byte_array_hex": name_raw.hex()},
            "raw_hex": name_raw.hex(),
            "source_offset": name_offset,
        }
        if op != "mmo_resource_marker":
            operand["source_name"] = source_name
        instruction = {
            "ok": True,
            "schema": handoff_validator.COMPONENT_SCHEMAS["instruction"],
            "source_offset": 0,
            "end_offset": len(code),
            "byte_length": len(code),
            "raw_hex": code.hex(),
            "region": "entry_0000",
            "op": op,
            "command_id": form["command_id"],
            "operands": [operand],
        }
        resource_reference = {
            "source_offset": 0,
            "region": "entry_0000",
            "op": op,
            "resource_kind": form["resource_kind"],
            "name": form["normalized"],
            "source_name": source_name,
            "archive_candidates": form["archives"],
            "boundary": "strict_indexed",
            "native_semantics": "fixture_only",
        }
        handoff = {
            "ok": True,
            "schema": handoff_validator.HANDOFF_SCHEMA,
            "producer": {
                "implementation": "test",
                "contract": handoff_validator.HANDOFF_SCHEMA,
            },
            "compatibility": {
                "policy": "exact_component_schema_match",
                "component_schemas": {
                    **handoff_validator.COMPONENT_SCHEMAS,
                    "accepted_call_evidence": handoff_validator.CALL_EVIDENCE_SCHEMAS,
                    "accepted_trace_evidence": handoff_validator.TRACE_EVIDENCE_SCHEMAS,
                },
            },
            "source_identity": {
                "archive": "mes.arc",
                "entry": "RESOURCE.MES",
                "source_kind": "original_arc",
                "archive_sha256": "a" * 64,
            },
            "container": {
                "schema": handoff_validator.COMPONENT_SCHEMAS["container"],
                "header": {"code_offset": len(preamble), "code_size": len(code)},
                "bootstrap": {"offset": 0, "end_offset": 0, "size": 0},
                "entries": [{
                    "id": "entry_0000",
                    "index": 0,
                    "offset": 0,
                    "end_offset": len(code),
                    "size": len(code),
                }],
                "entry_sha256": hashlib.sha256(raw).hexdigest(),
                "bytecode_sha256": hashlib.sha256(code).hexdigest(),
                "raw_hex": raw.hex(),
            },
            "record_alignment": {
                "schema": handoff_validator.COMPONENT_SCHEMAS["record_alignment"]
            },
            "typed_ir": {
                "schema": handoff_validator.COMPONENT_SCHEMAS["analysis"],
                "complete": True,
                "instructions": [instruction],
                "diagnostics": [],
                "opaque_boundaries": [],
            },
            "references": {
                "messages": [],
                "code": [],
                "state": [],
                "resources": [resource_reference],
            },
            "cfg": [],
            "calls": [],
            "traces": [],
            "capability_report": {"product_ui_data": "forbidden"},
        }
        handoff["payload_sha256"] = handoff_validator.fingerprint(handoff)
        document = editable_ir.prepare(decompiler.lift(handoff))
        operation = {
            "kind": "replace_resource_name",
            "source_offset": 0,
            "instruction_raw_sha256": hashlib.sha256(code).hexdigest(),
            "reference_id": "resource_00000000",
            "name": replacement_name,
        }
        return document, operation

    def test_plans_exact_mmo_name_without_publishing_mes(self) -> None:
        editable, operation = self.fixture()
        document = planner.plan(editable, operation)

        self.assertEqual(planner.PLAN_SCHEMA, document["schema"])
        self.assertTrue(document["assembly_ready"])
        self.assertEqual("mmo", document["target"]["resource_kind"])
        self.assertEqual("strict_indexed", document["target"]["reference_boundary"])
        self.assertEqual("0d09ff01", document["target"]["prefix_raw_hex"])
        self.assertEqual("0000", document["target"]["suffix_raw_hex"])
        self.assertEqual("772e6d6d6f", document["target"]["name_raw_hex"])
        self.assertEqual("792e6d6d6f", document["replacement"]["name_raw_hex"])
        self.assertEqual("0d09ff01792e6d6d6f0000", document["replacement"]["instruction_raw_hex"])
        self.assertEqual(planner.fingerprint(document), document["payload_sha256"])

    def test_plans_ax_name_and_retains_numeric_suffix(self) -> None:
        editable, operation = self.fixture(
            op="ax_resource_marker", source_name="w.ax", replacement_name="z.ax"
        )
        document = planner.plan(editable, operation)

        self.assertEqual("ax", document["target"]["resource_kind"])
        self.assertEqual("W.AX", document["target"]["normalized_name"])
        self.assertEqual("Z.AX", document["replacement"]["normalized_name"])
        self.assertEqual("000202f900ff00", document["target"]["suffix_raw_hex"])
        self.assertTrue(document["replacement"]["instruction_raw_hex"].endswith("000202f900ff00"))

    def test_plans_voice_name_and_retains_selector_envelope(self) -> None:
        editable, operation = self.fixture(
            op="voice_marker",
            source_name="j0009.ogg",
            replacement_name="k0009.ogg",
        )
        document = planner.plan(editable, operation)

        self.assertEqual("voice", document["target"]["resource_kind"])
        self.assertEqual("J0009.OGG", document["target"]["normalized_name"])
        self.assertEqual("0d07ff0202ff01", document["target"]["prefix_raw_hex"])
        self.assertEqual("000200ff00", document["target"]["suffix_raw_hex"])

    def test_identical_source_and_operation_produce_identical_plan(self) -> None:
        editable, operation = self.fixture()
        self.assertEqual(
            planner.plan(editable, operation),
            planner.plan(copy.deepcopy(editable), copy.deepcopy(operation)),
        )

    def test_rejects_stale_instruction_hash(self) -> None:
        editable, operation = self.fixture()
        operation["instruction_raw_sha256"] = "0" * 64
        with self.assertRaisesRegex(planner.ResourceNameEditPlanError, "hash is stale"):
            planner.plan(editable, operation)

    def test_rejects_changed_name_length(self) -> None:
        editable, operation = self.fixture()
        operation["name"] = "long.mmo"
        with self.assertRaisesRegex(planner.ResourceNameEditPlanError, "changes name length"):
            planner.plan(editable, operation)

    def test_rejects_changed_extension(self) -> None:
        editable, operation = self.fixture()
        operation["name"] = "x.ogg"
        with self.assertRaisesRegex(planner.ResourceNameEditPlanError, "extension"):
            planner.plan(editable, operation)

    def test_rejects_scan_only_reference(self) -> None:
        editable, operation = self.fixture()
        editable["source_ir"]["references"][0]["value"]["boundary"] = "bounded_envelope_scan"
        editable["source_ir"]["payload_sha256"] = decompiler.fingerprint(editable["source_ir"])
        editable["payload_sha256"] = editable_ir.fingerprint(editable)
        with self.assertRaisesRegex(planner.ResourceNameEditPlanError, "reference changed"):
            planner.plan(editable, operation)

    def test_rejects_wrong_reference_id(self) -> None:
        editable, operation = self.fixture()
        operation["reference_id"] = "resource_99999999"
        with self.assertRaisesRegex(planner.ResourceNameEditPlanError, "no unique indexed"):
            planner.plan(editable, operation)

    def test_rejects_unknown_operation_field(self) -> None:
        editable, operation = self.fixture()
        operation["ignored"] = True
        with self.assertRaisesRegex(planner.ResourceNameEditPlanError, "operation fields"):
            planner.plan(editable, operation)

    def test_standalone_validation_rejects_numeric_prefix_change(self) -> None:
        editable, operation = self.fixture(
            op="ax_resource_marker", source_name="w.ax", replacement_name="z.ax"
        )
        document = planner.plan(editable, operation)
        changed_prefix = bytearray.fromhex(document["target"]["prefix_raw_hex"])
        changed_prefix[4] = 1
        source_name = bytes.fromhex(document["target"]["name_raw_hex"])
        suffix = bytes.fromhex(document["target"]["suffix_raw_hex"])
        replacement_name = bytes.fromhex(document["replacement"]["name_raw_hex"])
        source_instruction = bytes(changed_prefix) + source_name + suffix
        output_instruction = bytes(changed_prefix) + replacement_name + suffix
        document["target"]["prefix_raw_hex"] = bytes(changed_prefix).hex()
        document["target"]["prefix_raw_sha256"] = hashlib.sha256(changed_prefix).hexdigest()
        document["target"]["instruction_raw_hex"] = source_instruction.hex()
        document["target"]["instruction_raw_sha256"] = hashlib.sha256(source_instruction).hexdigest()
        document["operation"]["instruction_raw_sha256"] = hashlib.sha256(source_instruction).hexdigest()
        document["replacement"]["instruction_raw_hex"] = output_instruction.hex()
        document["replacement"]["instruction_raw_sha256"] = hashlib.sha256(output_instruction).hexdigest()
        document["payload_sha256"] = planner.fingerprint(document)
        with self.assertRaisesRegex(planner.ResourceNameEditPlanError, "boundary"):
            planner.validate(document)

    def test_rejects_rehashed_plan_that_differs_from_source(self) -> None:
        editable, operation = self.fixture()
        document = planner.plan(editable, operation)
        document["source_identity"]["entry"] = "OTHER.MES"
        document["payload_sha256"] = planner.fingerprint(document)
        with self.assertRaisesRegex(planner.ResourceNameEditPlanError, "differs from its source"):
            planner.validate(document, editable)


if __name__ == "__main__":
    unittest.main()
