from __future__ import annotations

import copy
import hashlib
import struct
import sys
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

import decompile_mes_handoff as decompiler  # noqa: E402
import plan_mes_registered_definition_call_edit as planner  # noqa: E402
import prepare_mes_editable_ir as editable_ir  # noqa: E402
import prove_mes_call_families as call_prover  # noqa: E402
import prove_mes_registered_definition_registry as registry_prover  # noqa: E402
import validate_mes_analyzer_handoff as handoff_validator  # noqa: E402


class MesRegisteredDefinitionCallEditPlanTests(unittest.TestCase):
    def fixture(
        self,
        *,
        source_selector: int = 3,
        replacement_selector: int = 4,
    ) -> tuple[dict, dict, dict, dict]:
        call_raw = bytes((0x11, 0x02, source_selector, 0xFF, 0x00))
        resume_raw = b"\x00"
        code = call_raw + resume_raw
        preamble = (1).to_bytes(4, "little") + (0).to_bytes(4, "little")
        raw = preamble + code
        call = {
            "ok": True,
            "schema": handoff_validator.COMPONENT_SCHEMAS["instruction"],
            "source_offset": 0,
            "end_offset": len(call_raw),
            "byte_length": len(call_raw),
            "raw_hex": call_raw.hex(),
            "region": "entry_0000",
            "op": "definition_invoke",
            "command_id": 0x11,
            "operands": [{
                "type": "record_list",
                "source_offset": 1,
                "end_offset": 5,
                "records": [{
                    "type": "expression_record",
                    "tag": 0x02,
                    "source_offset": 1,
                    "value": {
                        "ok": True,
                        "offset": 2,
                        "end_offset": 4,
                        "byte_length": 2,
                        "raw_hex": bytes((source_selector, 0xFF)).hex(),
                        "ast": {
                            "type": "literal",
                            "value": source_selector,
                            "width": 8,
                            "source": {
                                "offset": 2,
                                "token": f"0x{source_selector:02x}",
                            },
                        },
                    },
                }],
            }],
        }
        resume = {
            "ok": True,
            "schema": handoff_validator.COMPONENT_SCHEMAS["instruction"],
            "source_offset": 5,
            "end_offset": 6,
            "byte_length": 1,
            "raw_hex": resume_raw.hex(),
            "region": "entry_0000",
            "op": "command_00",
            "command_id": 0,
            "operands": [],
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
                "entry": "CALL.MES",
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
                "instructions": [call, resume],
                "diagnostics": [],
                "opaque_boundaries": [],
            },
            "references": {"messages": [], "code": [], "state": [], "resources": []},
            "cfg": [],
            "calls": [],
            "traces": [],
            "capability_report": {"product_ui_data": "forbidden"},
        }
        handoff["payload_sha256"] = handoff_validator.fingerprint(handoff)
        linear = decompiler.lift(handoff)
        editable = editable_ir.prepare(linear)
        call_family = call_prover.prove(linear)
        registry_payload = self.registry_payload(source_selector, replacement_selector)
        registry_identity = {
            "archive": "mes.arc",
            "archive_sha256": "a" * 64,
            "entry": "DEF_TEST.MES",
            "entry_sha256": hashlib.sha256(registry_payload).hexdigest(),
        }
        registry = registry_prover.prove_entry(registry_payload, registry_identity)
        operation = {
            "kind": "replace_registered_definition_literal",
            "source_offset": 0,
            "instruction_raw_sha256": hashlib.sha256(call_raw).hexdigest(),
            "selector": replacement_selector,
        }
        return editable, call_family, registry, operation

    @staticmethod
    def registry_payload(first: int, second: int) -> bytes:
        code = (
            bytes((0x14, first, 0xFF))
            + (8).to_bytes(4, "little")
            + b"\x00"
            + b"\x17\x00\x00\x00\x00"
            + bytes((0x14, second, 0xFF))
            + (21).to_bytes(4, "little")
            + b"\x00\x00"
        )
        return struct.pack("<II", 1, 8) + code

    def test_plans_exact_literal_call_with_both_registry_body_bindings(self) -> None:
        editable, call_family, registry, operation = self.fixture()
        document = planner.plan(editable, call_family, registry, operation)
        self.assertEqual(planner.PLAN_SCHEMA, document["schema"])
        self.assertEqual("110203ff00", document["target"]["instruction_raw_hex"])
        self.assertEqual("110204ff00", document["replacement"]["instruction_raw_hex"])
        self.assertEqual(5, document["target"]["call_proof"]["physical_resume_offset"])
        self.assertEqual((7, 8), (
            document["target"]["registry_binding"]["body_start"],
            document["target"]["registry_binding"]["body_end"],
        ))
        self.assertEqual((20, 21), (
            document["replacement"]["registry_binding"]["body_start"],
            document["replacement"]["registry_binding"]["body_end"],
        ))
        self.assertTrue(document["assembly_ready"])

    def test_identical_inputs_produce_identical_plan(self) -> None:
        editable, call_family, registry, operation = self.fixture()
        first = planner.plan(editable, call_family, registry, operation)
        second = planner.plan(
            copy.deepcopy(editable), copy.deepcopy(call_family),
            copy.deepcopy(registry), copy.deepcopy(operation),
        )
        self.assertEqual(first, second)

    def test_rejects_stale_instruction_hash(self) -> None:
        editable, call_family, registry, operation = self.fixture()
        operation["instruction_raw_sha256"] = "0" * 64
        with self.assertRaisesRegex(planner.RegisteredDefinitionCallEditPlanError, "hash is stale"):
            planner.plan(editable, call_family, registry, operation)

    def test_rejects_dynamic_source_selector(self) -> None:
        editable, _call_family, registry, operation = self.fixture()
        expression = editable["source_ir"]["nodes"][0]["statement"]["operands"][0]["records"][0]["value"]
        expression["ast"] = {"type": "state_ref", "storage": "state_u16", "index": 3}
        editable["source_ir"]["payload_sha256"] = decompiler.fingerprint(editable["source_ir"])
        editable["payload_sha256"] = editable_ir.fingerprint(editable)
        call_family = call_prover.prove(editable["source_ir"])
        with self.assertRaisesRegex(
            planner.RegisteredDefinitionCallEditPlanError,
            "typed literal expression",
        ):
            planner.plan(editable, call_family, registry, operation)

    def test_rejects_unregistered_replacement_and_changed_archive(self) -> None:
        editable, call_family, registry, operation = self.fixture()
        operation["selector"] = 5
        with self.assertRaisesRegex(
            planner.RegisteredDefinitionCallEditPlanError,
            "no unique registry body",
        ):
            planner.plan(editable, call_family, registry, operation)

        operation["selector"] = 4
        registry["source_identity"]["archive_sha256"] = "b" * 64
        registry["payload_sha256"] = registry_prover.fingerprint(registry)
        with self.assertRaisesRegex(
            planner.RegisteredDefinitionCallEditPlanError,
            "archives differ",
        ):
            planner.plan(editable, call_family, registry, operation)

    def test_rejects_unchanged_ambiguous_and_unknown_operation(self) -> None:
        editable, call_family, registry, operation = self.fixture()
        operation["selector"] = 3
        with self.assertRaisesRegex(planner.RegisteredDefinitionCallEditPlanError, "unchanged"):
            planner.plan(editable, call_family, registry, operation)

        operation["selector"] = 0x80
        with self.assertRaisesRegex(planner.RegisteredDefinitionCallEditPlanError, "unambiguous token"):
            planner.plan(editable, call_family, registry, operation)

        operation["selector"] = 4
        operation["ignored"] = True
        with self.assertRaisesRegex(planner.RegisteredDefinitionCallEditPlanError, "operation fields"):
            planner.plan(editable, call_family, registry, operation)

    def test_standalone_validation_rejects_changed_resume(self) -> None:
        editable, call_family, registry, operation = self.fixture()
        document = planner.plan(editable, call_family, registry, operation)
        document["target"]["call_proof"]["physical_resume_offset"] += 1
        document["payload_sha256"] = planner.fingerprint(document)
        with self.assertRaisesRegex(planner.RegisteredDefinitionCallEditPlanError, "call proof changed"):
            planner.validate(document)

    def test_source_validation_rejects_rehashed_changed_body_binding(self) -> None:
        editable, call_family, registry, operation = self.fixture()
        document = planner.plan(editable, call_family, registry, operation)
        document["replacement"]["registry_binding"]["body_raw_sha256"] = "0" * 64
        document["payload_sha256"] = planner.fingerprint(document)
        with self.assertRaisesRegex(
            planner.RegisteredDefinitionCallEditPlanError,
            "differs from its source",
        ):
            planner.validate(document, editable, call_family, registry)


if __name__ == "__main__":
    unittest.main()
