from __future__ import annotations

import copy
import hashlib
import sys
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

import decompile_mes_handoff as decompiler  # noqa: E402
import plan_mes_condition_literal_edit as planner  # noqa: E402
import prepare_mes_editable_ir as editable_ir  # noqa: E402
import validate_mes_analyzer_handoff as handoff_validator  # noqa: E402


class MesConditionLiteralEditPlanTests(unittest.TestCase):
    def fixture(
        self,
        *,
        source_value: int = 1,
        width: int = 8,
        replacement_value: int = 2,
    ) -> tuple[dict, dict]:
        literal = self._literal_token(source_value, width)
        condition = bytes.fromhex("f30100") + literal + bytes.fromhex("efff")
        code = b"\x0b" + condition + (0).to_bytes(4, "little")
        literal_offset = 4
        condition_value = {
            "ok": True,
            "offset": 1,
            "end_offset": 1 + len(condition),
            "byte_length": len(condition),
            "raw_hex": condition.hex(),
            "ast": {
                "type": "binary",
                "op": "equal",
                "lhs": {
                    "type": "state_ref",
                    "storage": "global_u8",
                    "bank": 0,
                    "index": {"type": "literal", "value": 1},
                    "source": {"offset": 1, "token": "0xf3"},
                },
                "rhs": {
                    "type": "literal",
                    "value": source_value,
                    "width": width,
                    "source": {
                        "offset": literal_offset,
                        "token": f"0x{literal[0]:02x}",
                    },
                },
                "source": {
                    "offset": literal_offset + len(literal),
                    "token": "0xef",
                },
            },
        }
        preamble = (1).to_bytes(4, "little") + (0).to_bytes(4, "little")
        raw = preamble + code
        instruction = {
            "ok": True,
            "schema": handoff_validator.COMPONENT_SCHEMAS["instruction"],
            "source_offset": 0,
            "end_offset": len(code),
            "byte_length": len(code),
            "raw_hex": code.hex(),
            "region": "entry_0000",
            "op": "branch_if_not_true",
            "command_id": 0x0B,
            "operands": [
                {"type": "condition", "value": condition_value},
                {"type": "code_offset", "value": 0},
            ],
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
                "entry": "CONDITION.MES",
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
                "code": [
                    {
                        "source_offset": 0,
                        "op": "branch_if_not_true",
                        "kind": "condition_false_target",
                        "target_offset": 0,
                        "in_code": True,
                        "aligned": True,
                        "target_region": "entry_0000",
                    },
                    {
                        "source_offset": 0,
                        "op": "branch_if_not_true",
                        "kind": "condition_true_fallthrough",
                        "target_offset": len(code),
                        "in_code": False,
                        "aligned": False,
                        "target_region": "outside",
                    },
                ],
                "state": [{
                    "source_offset": 0,
                    "access": "read",
                    "storage": "global_u8",
                    "bank": 0,
                    "index": "1",
                    "count": 1,
                }],
                "resources": [],
            },
            "cfg": [],
            "calls": [],
            "traces": [],
            "capability_report": {"product_ui_data": "forbidden"},
        }
        handoff["payload_sha256"] = handoff_validator.fingerprint(handoff)
        document = editable_ir.prepare(decompiler.lift(handoff))
        operation = {
            "kind": "replace_condition_literal",
            "source_offset": 0,
            "instruction_raw_sha256": hashlib.sha256(code).hexdigest(),
            "literal_offset": literal_offset,
            "value": replacement_value,
        }
        return document, operation

    def test_plans_exact_u8_condition_literal_without_publishing_mes(self) -> None:
        editable, operation = self.fixture()
        document = planner.plan(editable, operation)

        self.assertEqual(planner.PLAN_SCHEMA, document["schema"])
        self.assertTrue(document["assembly_ready"])
        self.assertEqual("branch_if_not_true", document["target"]["op"])
        self.assertEqual(4, document["target"]["literal_start"])
        self.assertEqual("01", document["target"]["literal_raw_hex"])
        self.assertEqual("02", document["replacement"]["literal_raw_hex"])
        self.assertEqual("0bf3010002efff00000000", document["replacement"]["instruction_raw_hex"])
        self.assertEqual("code_00000000", document["target"]["false_target"]["reference_id"])
        self.assertEqual("00000000", document["target"]["false_target"]["operand_raw_hex"])
        self.assertEqual(planner.fingerprint(document), document["payload_sha256"])

    def test_plans_same_width_u16_condition_literal(self) -> None:
        editable, operation = self.fixture(
            source_value=0x1234,
            width=16,
            replacement_value=0x5678,
        )
        document = planner.plan(editable, operation)

        self.assertEqual(16, document["target"]["width"])
        self.assertEqual("f13412", document["target"]["literal_raw_hex"])
        self.assertEqual("f17856", document["replacement"]["literal_raw_hex"])
        self.assertEqual("00000000", document["replacement"]["instruction_raw_hex"][-8:])

    def test_identical_source_and_operation_produce_identical_plan(self) -> None:
        editable, operation = self.fixture()
        self.assertEqual(
            planner.plan(editable, operation),
            planner.plan(copy.deepcopy(editable), copy.deepcopy(operation)),
        )

    def test_rejects_stale_instruction_hash(self) -> None:
        editable, operation = self.fixture()
        operation["instruction_raw_sha256"] = "0" * 64
        with self.assertRaisesRegex(planner.ConditionLiteralEditPlanError, "hash is stale"):
            planner.plan(editable, operation)

    def test_rejects_offset_that_is_not_one_ast_literal(self) -> None:
        editable, operation = self.fixture()
        operation["literal_offset"] = 5
        with self.assertRaisesRegex(planner.ConditionLiteralEditPlanError, "one exact AST literal"):
            planner.plan(editable, operation)

    def test_rejects_ambiguous_u8_replacement_token(self) -> None:
        editable, operation = self.fixture(replacement_value=0x80)
        with self.assertRaisesRegex(planner.ConditionLiteralEditPlanError, "unambiguous token"):
            planner.plan(editable, operation)

    def test_rejects_missing_false_target_reference(self) -> None:
        editable, operation = self.fixture()
        reference = next(
            row
            for row in editable["source_ir"]["references"]
            if row["id"] == "code_00000000"
        )
        reference["value"]["kind"] = "condition_true_fallthrough"
        editable["source_ir"]["payload_sha256"] = decompiler.fingerprint(editable["source_ir"])
        editable["payload_sha256"] = editable_ir.fingerprint(editable)
        with self.assertRaisesRegex(planner.ConditionLiteralEditPlanError, "unique indexed false-target"):
            planner.plan(editable, operation)

    def test_rejects_unknown_operation_field(self) -> None:
        editable, operation = self.fixture()
        operation["ignored"] = True
        with self.assertRaisesRegex(planner.ConditionLiteralEditPlanError, "operation fields"):
            planner.plan(editable, operation)

    def test_standalone_validation_rejects_changed_false_target(self) -> None:
        editable, operation = self.fixture()
        document = planner.plan(editable, operation)
        document["target"]["false_target"]["value"] = 1
        document["payload_sha256"] = planner.fingerprint(document)
        with self.assertRaisesRegex(planner.ConditionLiteralEditPlanError, "length or target"):
            planner.validate(document)

    def test_standalone_validation_rejects_condition_slice_mismatch(self) -> None:
        editable, operation = self.fixture()
        document = planner.plan(editable, operation)
        raw = bytearray.fromhex(document["target"]["condition_raw_hex"])
        raw[0] ^= 1
        document["target"]["condition_raw_hex"] = raw.hex()
        document["target"]["condition_raw_sha256"] = hashlib.sha256(raw).hexdigest()
        document["payload_sha256"] = planner.fingerprint(document)
        with self.assertRaisesRegex(planner.ConditionLiteralEditPlanError, "source slices"):
            planner.validate(document)

    def test_rejects_rehashed_plan_that_differs_from_source(self) -> None:
        editable, operation = self.fixture()
        document = planner.plan(editable, operation)
        document["source_identity"]["entry"] = "OTHER.MES"
        document["payload_sha256"] = planner.fingerprint(document)
        with self.assertRaisesRegex(planner.ConditionLiteralEditPlanError, "differs from its source"):
            planner.validate(document, editable)

    @staticmethod
    def _literal_token(value: int, width: int) -> bytes:
        if width == 8:
            return bytes((value,))
        if width == 16:
            return b"\xF1" + value.to_bytes(2, "little")
        if width == 32:
            return b"\xF2" + value.to_bytes(4, "little")
        raise ValueError(width)


if __name__ == "__main__":
    unittest.main()
