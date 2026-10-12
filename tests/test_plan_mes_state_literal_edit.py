from __future__ import annotations

import copy
import hashlib
import sys
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

import decompile_mes_handoff as decompiler  # noqa: E402
import plan_mes_state_literal_edit as planner  # noqa: E402
import prepare_mes_editable_ir as editable_ir  # noqa: E402
import validate_mes_analyzer_handoff as handoff_validator  # noqa: E402


class MesStateLiteralEditPlanTests(unittest.TestCase):
    def fixture(
        self,
        *,
        operation_name: str = "global_u8_write_run",
        command_id: int = 0x03,
        source_value: int = 1,
        width: int = 8,
        replacement_value: int = 2,
    ) -> tuple[dict, dict]:
        expression = self._literal(source_value, width)
        if operation_name == "global_u8_write_run":
            prefix = bytes.fromhex("031e01")
            storage = "global_u8"
            destination = {"type": "u16_index", "value": 286, "source_offset": 1}
            expression_offset = 3
            operands = [destination]
        elif operation_name == "state_u16_write_run":
            prefix = bytes.fromhex("0402")
            storage = "state_u16"
            destination = {"type": "u8_index", "value": 2, "source_offset": 1}
            expression_offset = 2
            operands = [destination]
        elif operation_name == "banked_u16_write_run":
            destination_expression = self._expression(1, self._literal(0, 8), 0)
            prefix = bytes.fromhex("0700ff00")
            storage = "banked_u16"
            destination = {"type": "expression_index", "value": destination_expression}
            expression_offset = 4
            operands = [destination, {"type": "u8_bank", "value": 0, "source_offset": 3}]
        else:
            raise ValueError(operation_name)
        code = prefix + expression + b"\x00"
        expression_value = self._expression(expression_offset, expression, source_value, width)
        operands.append({
            "type": "expression_byte_pairs",
            "pairs": [{
                "type": "expression_byte_pair",
                "expression": expression_value,
                "continuation": 0,
            }],
        })
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
            "op": operation_name,
            "command_id": command_id,
            "operands": operands,
        }
        handoff = {
            "ok": True,
            "schema": handoff_validator.HANDOFF_SCHEMA,
            "producer": {"implementation": "test", "contract": handoff_validator.HANDOFF_SCHEMA},
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
                "entry": "STATE.MES",
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
            "record_alignment": {"schema": handoff_validator.COMPONENT_SCHEMAS["record_alignment"]},
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
                "state": [{
                    "source_offset": 0,
                    "access": "write",
                    "storage": storage,
                    "bank": 0,
                    "index": "286" if storage == "global_u8" else "2",
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
            "kind": "replace_state_write_literal",
            "source_offset": 0,
            "instruction_raw_sha256": hashlib.sha256(code).hexdigest(),
            "pair_index": 0,
            "value": replacement_value,
        }
        return document, operation

    def test_plans_exact_unambiguous_u8_literal_without_publishing_mes(self) -> None:
        editable, operation = self.fixture()
        document = planner.plan(editable, operation)

        self.assertEqual(planner.PLAN_SCHEMA, document["schema"])
        self.assertTrue(document["assembly_ready"])
        self.assertEqual("global_u8", document["target"]["storage"])
        self.assertEqual({"kind": "fixed_index", "index": 286, "bank": 0}, document["target"]["destination"])
        self.assertEqual(3, document["target"]["expression_start"])
        self.assertEqual("01ff", document["target"]["expression_raw_hex"])
        self.assertEqual("02ff", document["replacement"]["expression_raw_hex"])
        self.assertEqual("031e0102ff00", document["replacement"]["instruction_raw_hex"])
        self.assertEqual(planner.fingerprint(document), document["payload_sha256"])

    def test_plans_same_width_u16_literal(self) -> None:
        editable, operation = self.fixture(
            operation_name="state_u16_write_run",
            command_id=0x04,
            source_value=0x1234,
            width=16,
            replacement_value=0x5678,
        )
        document = planner.plan(editable, operation)

        self.assertEqual("state_u16", document["target"]["storage"])
        self.assertEqual(16, document["target"]["width"])
        self.assertEqual("f13412ff", document["target"]["expression_raw_hex"])
        self.assertEqual("f17856ff", document["replacement"]["expression_raw_hex"])

    def test_retains_expression_destination_and_bank_identity(self) -> None:
        editable, operation = self.fixture(
            operation_name="banked_u16_write_run",
            command_id=0x07,
        )
        document = planner.plan(editable, operation)

        self.assertEqual("banked_u16", document["target"]["storage"])
        self.assertEqual("expression_index", document["target"]["destination"]["kind"])
        self.assertEqual("00ff", document["target"]["destination"]["expression_raw_hex"])
        self.assertEqual(0, document["target"]["destination"]["bank"])

    def test_identical_source_and_operation_produce_identical_plan(self) -> None:
        editable, operation = self.fixture()
        self.assertEqual(planner.plan(editable, operation), planner.plan(copy.deepcopy(editable), copy.deepcopy(operation)))

    def test_rejects_stale_instruction_hash(self) -> None:
        editable, operation = self.fixture()
        operation["instruction_raw_sha256"] = "0" * 64
        with self.assertRaisesRegex(planner.StateLiteralEditPlanError, "hash is stale"):
            planner.plan(editable, operation)

    def test_rejects_non_literal_expression(self) -> None:
        editable, operation = self.fixture()
        expression = editable["source_ir"]["nodes"][0]["statement"]["operands"][1]["pairs"][0]["expression"]
        expression["ast"] = {"type": "state_ref"}
        editable["source_ir"]["payload_sha256"] = decompiler.fingerprint(editable["source_ir"])
        editable["payload_sha256"] = editable_ir.fingerprint(editable)
        with self.assertRaisesRegex(planner.StateLiteralEditPlanError, "not one literal"):
            planner.plan(editable, operation)

    def test_rejects_ambiguous_u8_replacement_token(self) -> None:
        editable, operation = self.fixture(replacement_value=0x80)
        with self.assertRaisesRegex(planner.StateLiteralEditPlanError, "unambiguous token"):
            planner.plan(editable, operation)

    def test_rejects_unknown_operation_field(self) -> None:
        editable, operation = self.fixture()
        operation["ignored"] = True
        with self.assertRaisesRegex(planner.StateLiteralEditPlanError, "operation fields"):
            planner.plan(editable, operation)

    def test_standalone_validation_rejects_destination_shape_for_wrong_write(self) -> None:
        editable, operation = self.fixture()
        document = planner.plan(editable, operation)
        destination_raw = bytes.fromhex("00ff")
        document["target"]["destination"] = {
            "kind": "expression_index",
            "expression_raw_hex": destination_raw.hex(),
            "expression_raw_sha256": hashlib.sha256(destination_raw).hexdigest(),
            "bank": 0,
        }
        document["payload_sha256"] = planner.fingerprint(document)
        with self.assertRaisesRegex(planner.StateLiteralEditPlanError, "write form"):
            planner.validate(document)

    def test_rejects_rehashed_plan_that_differs_from_source(self) -> None:
        editable, operation = self.fixture()
        document = planner.plan(editable, operation)
        document["source_identity"]["entry"] = "OTHER.MES"
        document["payload_sha256"] = planner.fingerprint(document)
        with self.assertRaisesRegex(planner.StateLiteralEditPlanError, "differs from its source"):
            planner.validate(document, editable)

    @staticmethod
    def _literal(value: int, width: int) -> bytes:
        if width == 8:
            return bytes((value, 0xFF))
        if width == 16:
            return b"\xF1" + value.to_bytes(2, "little") + b"\xFF"
        if width == 32:
            return b"\xF2" + value.to_bytes(4, "little") + b"\xFF"
        raise ValueError(width)

    @staticmethod
    def _expression(offset: int, raw: bytes, value: int, width: int = 8) -> dict:
        return {
            "ok": True,
            "offset": offset,
            "end_offset": offset + len(raw),
            "byte_length": len(raw),
            "raw_hex": raw.hex(),
            "ast": {
                "type": "literal",
                "value": value,
                "width": width,
                "source": {"offset": offset, "token": f"0x{raw[0]:02x}"},
            },
        }


if __name__ == "__main__":
    unittest.main()
