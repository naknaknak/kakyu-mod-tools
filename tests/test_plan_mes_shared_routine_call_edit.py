from __future__ import annotations

import copy
import hashlib
import sys
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

import decompile_mes_handoff as decompiler  # noqa: E402
import plan_mes_shared_routine_call_edit as planner  # noqa: E402
import prepare_mes_editable_ir as editable_ir  # noqa: E402
import prove_mes_shared_call_returns as call_prover  # noqa: E402
import validate_mes_analyzer_handoff as handoff_validator  # noqa: E402


class MesSharedRoutineCallEditPlanTests(unittest.TestCase):
    def fixture(
        self,
        *,
        source_routine: int = 3,
        replacement_routine: int = 4,
    ) -> tuple[dict, dict, dict, dict]:
        call_raw = bytes((0x1D, 0x02, source_routine, 0xFF, 0x00))
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
            "op": "script_transfer",
            "command_id": 0x1D,
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
                        "raw_hex": bytes((source_routine, 0xFF)).hex(),
                        "ast": {
                            "type": "literal",
                            "value": source_routine,
                            "width": 8,
                            "source": {
                                "offset": 2,
                                "token": f"0x{source_routine:02x}",
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
            "references": {
                "messages": [], "code": [], "state": [], "resources": [],
            },
            "cfg": [],
            "calls": [],
            "traces": [],
            "capability_report": {"product_ui_data": "forbidden"},
        }
        handoff["payload_sha256"] = handoff_validator.fingerprint(handoff)
        linear = decompiler.lift(handoff)
        editable = editable_ir.prepare(linear)
        library = {
            "ok": True,
            "schema": call_prover.LIBRARY_AUDIT_SCHEMA,
            "archive_name": "mes.arc",
            "archive_sha256": "a" * 64,
            "entry": "LIBLARY.LIB",
            "entry_sha256": "b" * 64,
            "source_archive_unchanged": True,
            "routines": [
                self.return_routine(source_routine, 100, 90),
                self.return_routine(replacement_routine, 200, 190),
            ],
        }
        proof = call_prover.prove(linear, library)
        operation = {
            "kind": "replace_shared_routine_literal",
            "source_offset": 0,
            "instruction_raw_sha256": hashlib.sha256(call_raw).hexdigest(),
            "routine_id": replacement_routine,
        }
        return editable, proof, library, operation

    @staticmethod
    def return_routine(routine_id: int, body_offset: int, registration_offset: int) -> dict:
        return {
            "routine_id": routine_id,
            "registration_offset": registration_offset,
            "body_offset": body_offset,
            "end_offset": body_offset + 1,
            "strict": {"complete": True, "decoded_end_offset": body_offset + 1},
            "structural": {"complete": True, "decoded_end_offset": body_offset + 1},
            "native_dispatch_flow": {
                "complete": True,
                "instruction_count": 1,
                "edge_count": 0,
                "instructions": [{
                    "source_offset": body_offset,
                    "decoded_end_offset": body_offset + 1,
                    "command_id": 0,
                    "op": "command_00",
                }],
                "edges": [],
                "return_offsets": [body_offset],
                "exit_offsets": [],
                "boundaries": [],
                "failures": [],
            },
        }

    def test_plans_exact_literal_call_with_source_and_replacement_proofs(self) -> None:
        editable, proof, library, operation = self.fixture()
        document = planner.plan(editable, proof, library, operation)

        self.assertEqual(planner.PLAN_SCHEMA, document["schema"])
        self.assertEqual("1d0203ff00", document["target"]["instruction_raw_hex"])
        self.assertEqual("1d0204ff00", document["replacement"]["instruction_raw_hex"])
        self.assertEqual(5, document["target"]["call_proof"]["physical_resume_offset"])
        self.assertEqual(
            "linear_00000005",
            document["target"]["call_proof"]["physical_resume_node_id"],
        )
        self.assertEqual(100, document["target"]["call_proof"]["callee_body_start"])
        self.assertEqual(200, document["replacement"]["callee_proof"]["body_start"])
        self.assertTrue(document["assembly_ready"])
        self.assertEqual(planner.fingerprint(document), document["payload_sha256"])

    def test_identical_inputs_produce_identical_plan(self) -> None:
        editable, proof, library, operation = self.fixture()
        first = planner.plan(editable, proof, library, operation)
        second = planner.plan(
            copy.deepcopy(editable), copy.deepcopy(proof),
            copy.deepcopy(library), copy.deepcopy(operation),
        )
        self.assertEqual(first, second)

    def test_rejects_stale_instruction_hash(self) -> None:
        editable, proof, library, operation = self.fixture()
        operation["instruction_raw_sha256"] = "0" * 64
        with self.assertRaisesRegex(planner.SharedRoutineCallEditPlanError, "hash is stale"):
            planner.plan(editable, proof, library, operation)

    def test_rejects_dynamic_source_selector(self) -> None:
        editable, _proof, library, operation = self.fixture()
        expression = editable["source_ir"]["nodes"][0]["statement"]["operands"][0]["records"][0]["value"]
        expression["ast"] = {
            "type": "state_ref", "storage": "state_u16", "index": 3,
        }
        editable["source_ir"]["payload_sha256"] = decompiler.fingerprint(editable["source_ir"])
        editable["payload_sha256"] = editable_ir.fingerprint(editable)
        proof = call_prover.prove(editable["source_ir"], library)
        with self.assertRaisesRegex(planner.SharedRoutineCallEditPlanError, "typed literal expression"):
            planner.plan(editable, proof, library, operation)

    def test_rejects_unproved_source_call(self) -> None:
        editable, _proof, library, operation = self.fixture()
        source_flow = library["routines"][0]["native_dispatch_flow"]
        source_flow["return_offsets"] = []
        source_flow["instructions"][0]["command_id"] = 0x12
        source_flow["instructions"][0]["op"] = "native_record_dispatch"
        proof = call_prover.prove(editable["source_ir"], library)
        with self.assertRaisesRegex(planner.SharedRoutineCallEditPlanError, "unique proved source call"):
            planner.plan(editable, proof, library, operation)

    def test_rejects_unproved_replacement_callee(self) -> None:
        editable, _proof, library, operation = self.fixture()
        replacement_flow = library["routines"][1]["native_dispatch_flow"]
        replacement_flow["return_offsets"] = []
        replacement_flow["instructions"][0]["command_id"] = 0x12
        replacement_flow["instructions"][0]["op"] = "native_record_dispatch"
        proof = call_prover.prove(editable["source_ir"], library)
        with self.assertRaisesRegex(planner.SharedRoutineCallEditPlanError, "replacement callee"):
            planner.plan(editable, proof, library, operation)

    def test_rejects_unchanged_and_ambiguous_replacement(self) -> None:
        editable, proof, library, operation = self.fixture()
        operation["routine_id"] = 3
        with self.assertRaisesRegex(planner.SharedRoutineCallEditPlanError, "unchanged"):
            planner.plan(editable, proof, library, operation)

        operation["routine_id"] = 0x80
        with self.assertRaisesRegex(planner.SharedRoutineCallEditPlanError, "unambiguous token"):
            planner.plan(editable, proof, library, operation)

    def test_rejects_unknown_operation_field(self) -> None:
        editable, proof, library, operation = self.fixture()
        operation["ignored"] = True
        with self.assertRaisesRegex(planner.SharedRoutineCallEditPlanError, "operation fields"):
            planner.plan(editable, proof, library, operation)

    def test_standalone_validation_rejects_changed_resume(self) -> None:
        editable, proof, library, operation = self.fixture()
        document = planner.plan(editable, proof, library, operation)
        document["target"]["call_proof"]["physical_resume_offset"] += 1
        document["payload_sha256"] = planner.fingerprint(document)
        with self.assertRaisesRegex(planner.SharedRoutineCallEditPlanError, "call or callee proof"):
            planner.validate(document)

    def test_rejects_rehashed_plan_that_differs_from_source(self) -> None:
        editable, proof, library, operation = self.fixture()
        document = planner.plan(editable, proof, library, operation)
        document["source_identity"]["entry"] = "OTHER.MES"
        document["payload_sha256"] = planner.fingerprint(document)
        with self.assertRaisesRegex(planner.SharedRoutineCallEditPlanError, "differs from its source"):
            planner.validate(document, editable, proof, library)


if __name__ == "__main__":
    unittest.main()
