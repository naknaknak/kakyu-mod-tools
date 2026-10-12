from __future__ import annotations

import copy
import hashlib
import json
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
sys.path.insert(0, str(ROOT / "tools"))

import decompile_mes_handoff as decompiler  # noqa: E402
import plan_mes_message_relocation as planner  # noqa: E402
import prepare_mes_editable_ir as editable_ir  # noqa: E402
import validate_mes_analyzer_handoff as handoff_validator  # noqa: E402


class MesMessageRelocationPlanTests(unittest.TestCase):
    def fixture(
        self,
        *,
        code_reference: bool | str = False,
        opaque_suffix: bool = False,
        definition_target: bool = False,
    ) -> tuple[dict, dict]:
        if sum(bool(value) for value in (code_reference, opaque_suffix, definition_target)) > 1:
            raise ValueError("control, definition, and opaque suffix fixtures are mutually exclusive")
        control_kind = "branch" if code_reference == "branch" else "continuation"
        preamble = (
            (2).to_bytes(4, "little")
            + (0).to_bytes(4, "little")
            + (4).to_bytes(4, "little")
        )
        if definition_target:
            code = bytes.fromhex("0182a000100200ff000d00000000")
        elif code_reference:
            control_hex = "0b01ff04000000" if control_kind == "branch" else "0c04000000"
            code = bytes.fromhex("0182a000" + control_hex)
        else:
            code = bytes.fromhex("0182a00082a200")
        raw = preamble + code
        message_raw = bytes.fromhex("82a0")
        instructions = [
            self._instruction(
                0,
                4,
                "0182a000",
                "entry_0000",
                "text",
                1,
                [{
                    "type": "cp932_bytes",
                    "source_offset": 1,
                    "raw_hex": "82a0",
                    "raw_bytes": {"$packed_byte_array_hex": "82a0"},
                }],
                {
                    "native_handler_family": "double_byte_character_stream_presentation",
                    "native_stream_consumption": "double_byte_pairs_until_nul_or_nonlead",
                    "native_stream_projection_match": True,
                    "native_stream_probe": {
                        "start_offset": 1,
                        "stop_offset": 3,
                        "probe_end_offset": 4,
                        "stop_reason": "nul_consumed",
                        "character_count": 1,
                        "consumed_byte_count": 3,
                    },
                },
            ),
        ]
        opaque_boundaries = []
        if opaque_suffix:
            opaque_boundaries.append({
                "source_offset": 4,
                "end_offset": 7,
                "raw_hex": "82a200",
                "raw_sha256": hashlib.sha256(bytes.fromhex("82a200")).hexdigest(),
                "region": "entry_0001",
                "boundary": "byte_preserving_fail_closed",
            })
        elif definition_target:
            instructions.append(
                self._instruction(
                    4,
                    13,
                    "100200ff000d000000",
                    "entry_0001",
                    "command_10",
                    0x10,
                    [
                        {
                            "type": "record_list",
                            "source_offset": 5,
                            "end_offset": 9,
                            "records": [{
                                "tag": 2,
                                "type": "expression_record",
                                "source_offset": 5,
                                "value": {
                                    "ok": True,
                                    "offset": 6,
                                    "end_offset": 8,
                                    "byte_length": 2,
                                    "raw_hex": "00ff",
                                    "ast": {"type": "literal", "value": 0, "width": 8},
                                },
                            }],
                        },
                        {"type": "u8_array", "value": [13, 0, 0, 0]},
                    ],
                )
            )
            instructions.append(
                self._instruction(13, 14, "00", "entry_0001", "command_00", 0, [])
            )
        elif code_reference:
            if control_kind == "branch":
                control_operands = [
                    {
                        "type": "condition",
                        "value": {
                            "ok": True,
                            "offset": 5,
                            "end_offset": 7,
                            "byte_length": 2,
                            "raw_hex": "01ff",
                            "ast": {"type": "literal", "value": 1, "width": 8},
                        },
                    },
                    {"type": "code_offset", "value": 4},
                ]
                control_raw = "0b01ff04000000"
                control_op = "branch_if_not_true"
                command_id = 0x0B
            else:
                control_operands = [{"type": "code_offset", "value": 4}]
                control_raw = "0c04000000"
                control_op = "continuation_transfer"
                command_id = 0x0C
            instructions.append(
                self._instruction(
                    4,
                    len(code),
                    control_raw,
                    "entry_0001",
                    control_op,
                    command_id,
                    control_operands,
                    {},
                )
            )
        else:
            instructions.append(
                self._instruction(
                    4,
                    7,
                    "82a200",
                    "entry_0001",
                    "dispatcher_character_text",
                    0x82,
                    [{
                        "type": "cp932_bytes",
                        "source_offset": 4,
                        "raw_hex": "82a2",
                        "raw_bytes": {"$packed_byte_array_hex": "82a2"},
                    }],
                    {
                        "native_handler_family": "double_byte_character_stream_presentation",
                        "native_stream_consumption": "double_byte_pairs_until_nul_or_nonlead",
                        "native_stream_projection_match": True,
                        "native_stream_probe": {
                            "start_offset": 4,
                            "stop_offset": 6,
                            "probe_end_offset": 7,
                            "stop_reason": "nul_consumed",
                            "character_count": 1,
                            "consumed_byte_count": 3,
                        },
                    },
                )
            )
        code_rows = []
        if code_reference:
            code_rows.append({
                "source_offset": 4,
                "op": "branch_if_not_true" if control_kind == "branch" else "continuation_transfer",
                "kind": "condition_false_target" if control_kind == "branch" else "continuation_target",
                "target_offset": 4,
                "in_code": True,
                "aligned": True,
                "target_region": "entry_0001",
            })
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
                "entry": "RELOCATE.MES",
                "source_kind": "original_arc",
                "archive_sha256": "a" * 64,
            },
            "container": {
                "schema": "ai5_mes_container/v1",
                "header": {"code_offset": len(preamble), "code_size": len(code)},
                "bootstrap": {"offset": 0, "end_offset": 0, "size": 0},
                "entries": [
                    {"id": "entry_0000", "index": 0, "offset": 0, "end_offset": 4, "size": 4},
                    {
                        "id": "entry_0001",
                        "index": 1,
                        "offset": 4,
                        "end_offset": len(code),
                        "size": len(code) - 4,
                    },
                ],
                "entry_sha256": hashlib.sha256(raw).hexdigest(),
                "bytecode_sha256": hashlib.sha256(code).hexdigest(),
                "raw_hex": raw.hex(),
            },
            "record_alignment": {"schema": "kakyu_mes_record_alignment_audit/v1"},
            "typed_ir": {
                "schema": "kakyu_mes_analysis/v19",
                "complete": not opaque_suffix,
                "instructions": instructions,
                "diagnostics": [],
                "opaque_boundaries": opaque_boundaries,
            },
            "references": {
                "messages": [{
                    "source_offset": 0,
                    "end_offset": 4,
                    "region": "entry_0000",
                    "kind": "text",
                    "raw_bytes": {"$packed_byte_array_hex": "82a0"},
                    "raw_hex": "82a0",
                    "raw_sha256": hashlib.sha256(message_raw).hexdigest(),
                    "native_handler_family": "double_byte_character_stream_presentation",
                    "native_stream_consumption": "double_byte_pairs_until_nul_or_nonlead",
                    "native_stream_projection_match": True,
                    "native_stream_probe": {
                        "start_offset": 1,
                        "stop_offset": 3,
                        "probe_end_offset": 4,
                        "stop_reason": "nul_consumed",
                        "character_count": 1,
                        "consumed_byte_count": 3,
                    },
                }] + ([] if opaque_suffix or code_reference or definition_target else [{
                    "source_offset": 4,
                    "end_offset": 7,
                    "region": "entry_0001",
                    "kind": "dispatcher_character_text",
                    "raw_bytes": {"$packed_byte_array_hex": "82a2"},
                    "raw_hex": "82a2",
                    "raw_sha256": hashlib.sha256(bytes.fromhex("82a2")).hexdigest(),
                    "native_handler_family": "double_byte_character_stream_presentation",
                    "native_stream_consumption": "double_byte_pairs_until_nul_or_nonlead",
                    "native_stream_projection_match": True,
                    "native_stream_probe": {
                        "start_offset": 4,
                        "stop_offset": 6,
                        "probe_end_offset": 7,
                        "stop_reason": "nul_consumed",
                        "character_count": 1,
                        "consumed_byte_count": 3,
                    },
                }]),
                "code": code_rows,
                "state": [],
                "resources": [],
            },
            "cfg": [],
            "calls": [],
            "traces": [],
        }
        handoff["payload_sha256"] = handoff_validator.fingerprint(handoff)
        document = editable_ir.prepare(decompiler.lift(handoff))
        operation = {
            "kind": "replace_message",
            "source_offset": 0,
            "raw_sha256": hashlib.sha256(message_raw).hexdigest(),
            "text": "いう",
            "encoding": "cp932",
            "native_projection": "require_match",
        }
        return document, operation

    def test_plans_variable_length_message_and_address_table_shift(self) -> None:
        document, operation = self.fixture()
        result = planner.plan(document, operation)

        self.assertTrue(result["assembly_ready"])
        self.assertEqual(2, result["relocation"]["delta"])
        self.assertEqual(9, result["relocation"]["output_code_size"])
        self.assertEqual(
            [{"index": 1, "source_offset": 4, "output_offset": 6}],
            result["relocation"]["address_table_updates"],
        )
        self.assertEqual("0182a282a400", result["target"]["replacement_node_raw_hex"])
        self.assertEqual(result["payload_sha256"], planner.fingerprint(result))

    def test_plan_is_deterministic_and_json_validated(self) -> None:
        document, operation = self.fixture()
        first = planner.plan(document, operation)
        second = planner.plan(copy.deepcopy(document), copy.deepcopy(operation))
        transported = json.loads(json.dumps(first, ensure_ascii=False))

        self.assertEqual(first, second)
        self.assertEqual(first, transported)
        planner.validate(transported, document)

    def test_marks_encoded_code_target_as_mw03_blocker(self) -> None:
        document, operation = self.fixture(code_reference=True)
        result = planner.plan(document, operation)

        self.assertFalse(result["assembly_ready"])
        self.assertEqual("encoded_code_target_requires_mw03", result["blockers"][0]["code"])
        code_row = next(row for row in result["affected_references"] if row["kind"] == "code")
        self.assertEqual((4, 6), (code_row["target_offset"], code_row["output_target_offset"]))

    def test_marks_shifted_opaque_suffix_as_blocker(self) -> None:
        document, operation = self.fixture(opaque_suffix=True)
        result = planner.plan(document, operation)

        self.assertFalse(result["assembly_ready"])
        self.assertEqual("opaque_boundary_would_shift", result["blockers"][0]["code"])

    def test_rejects_stale_source_hash_and_equal_length_edit(self) -> None:
        document, operation = self.fixture()
        stale = copy.deepcopy(operation)
        stale["raw_sha256"] = "0" * 64
        with self.assertRaisesRegex(planner.MessageRelocationPlanError, "stale"):
            planner.plan(document, stale)
        equal = copy.deepcopy(operation)
        equal["text"] = "い"
        with self.assertRaisesRegex(planner.MessageRelocationPlanError, "variable-length"):
            planner.plan(document, equal)

    def test_rejects_non_cp932_and_non_native_projection_text(self) -> None:
        document, operation = self.fixture()
        emoji = copy.deepcopy(operation)
        emoji["text"] = "😀"
        with self.assertRaisesRegex(planner.MessageRelocationPlanError, "CP932"):
            planner.plan(document, emoji)
        ascii_text = copy.deepcopy(operation)
        ascii_text["text"] = "ABC"
        with self.assertRaisesRegex(planner.MessageRelocationPlanError, "double-byte"):
            planner.plan(document, ascii_text)

    def test_rejects_unknown_operation_and_plan_fields(self) -> None:
        document, operation = self.fixture()
        unknown = copy.deepcopy(operation)
        unknown["ignored"] = True
        with self.assertRaisesRegex(planner.MessageRelocationPlanError, "fields"):
            planner.plan(document, unknown)
        result = planner.plan(document, operation)
        result["ignored"] = True
        result["payload_sha256"] = planner.fingerprint(result)
        with self.assertRaisesRegex(planner.MessageRelocationPlanError, "fields"):
            planner.validate(result, document)

    def test_cli_publication_uses_new_file_contract(self) -> None:
        document, operation = self.fixture()
        with tempfile.TemporaryDirectory() as raw_directory:
            root = Path(raw_directory)
            output = root / "plan.json"
            editable_ir.publish_new(
                output,
                editable_ir.canonical_json_bytes(planner.plan(document, operation)) + b"\n",
            )
            with self.assertRaisesRegex(editable_ir.EditableIrError, "already exists"):
                editable_ir.publish_new(output, b"replacement")

    @staticmethod
    def _instruction(
        start: int,
        end: int,
        raw_hex: str,
        region: str,
        op: str,
        command_id: int,
        operands: list,
        metadata: dict | None = None,
    ) -> dict:
        return {
            "ok": True,
            "schema": "ai5_mes_instruction/v45",
            "source_offset": start,
            "end_offset": end,
            "byte_length": end - start,
            "raw_hex": raw_hex,
            "region": region,
            "op": op,
            "command_id": command_id,
            "operands": operands,
            **(metadata or {}),
        }


if __name__ == "__main__":
    unittest.main()
