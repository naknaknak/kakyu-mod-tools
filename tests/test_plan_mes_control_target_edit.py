from __future__ import annotations

import copy
import hashlib
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
sys.path.insert(0, str(ROOT / "tools"))

import decompile_mes_handoff as decompiler  # noqa: E402
import plan_mes_control_target_edit as planner  # noqa: E402
import prepare_mes_editable_ir as editable_ir  # noqa: E402
import validate_mes_analyzer_handoff as handoff_validator  # noqa: E402
from tests import test_plan_mes_message_relocation as message_tests  # noqa: E402


class MesControlTargetEditPlanTests(unittest.TestCase):
    def fixture(self, kind: str = "continuation") -> tuple[dict, dict]:
        if kind == "branch":
            code = bytes.fromhex("0b01ff070000000000")
            control_end = 7
            reference_kind = "condition_false_target"
            op = "branch_if_not_true"
            command_id = 0x0B
            operands = [
                {
                    "type": "condition",
                    "value": {
                        "ok": True,
                        "offset": 1,
                        "end_offset": 3,
                        "byte_length": 2,
                        "raw_hex": "01ff",
                        "ast": {"type": "literal", "value": 1, "width": 8},
                    },
                },
                {"type": "code_offset", "value": 7},
            ]
        else:
            code = bytes.fromhex("0c050000000000")
            control_end = 5
            reference_kind = "continuation_target"
            op = "continuation_transfer"
            command_id = 0x0C
            operands = [{"type": "code_offset", "value": 5}]
        target_offset = control_end
        replacement_offset = control_end + 1
        preamble = (1).to_bytes(4, "little") + (0).to_bytes(4, "little")
        raw = preamble + code
        instructions = [
            message_tests.MesMessageRelocationPlanTests._instruction(
                0, control_end, code[:control_end].hex(), "entry_0000",
                op, command_id, operands, {},
            ),
            message_tests.MesMessageRelocationPlanTests._instruction(
                target_offset, target_offset + 1, "00", "entry_0000",
                "command_00", 0, [], {},
            ),
            message_tests.MesMessageRelocationPlanTests._instruction(
                replacement_offset, replacement_offset + 1, "00", "entry_0000",
                "command_00", 0, [], {},
            ),
        ]
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
                "archive": "mes.arc", "entry": "CONTROL_EDIT.MES",
                "source_kind": "original_arc", "archive_sha256": "a" * 64,
            },
            "container": {
                "schema": "ai5_mes_container/v1",
                "header": {"code_offset": len(preamble), "code_size": len(code)},
                "bootstrap": {"offset": 0, "end_offset": 0, "size": 0},
                "entries": [{
                    "id": "entry_0000", "index": 0, "offset": 0,
                    "end_offset": len(code), "size": len(code),
                }],
                "entry_sha256": hashlib.sha256(raw).hexdigest(),
                "bytecode_sha256": hashlib.sha256(code).hexdigest(),
                "raw_hex": raw.hex(),
            },
            "record_alignment": {"schema": "kakyu_mes_record_alignment_audit/v1"},
            "typed_ir": {
                "schema": "kakyu_mes_analysis/v19", "complete": True,
                "instructions": instructions, "diagnostics": [], "opaque_boundaries": [],
            },
            "references": {
                "messages": [],
                "code": [{
                    "source_offset": 0, "op": op, "kind": reference_kind,
                    "target_offset": target_offset, "in_code": True, "aligned": True,
                    "target_region": "entry_0000",
                }],
                "state": [], "resources": [],
            },
            "cfg": [], "calls": [], "traces": [],
        }
        handoff["payload_sha256"] = handoff_validator.fingerprint(handoff)
        document = editable_ir.prepare(decompiler.lift(handoff))
        source_node = next(row for row in document["source_ir"]["nodes"] if row["source"]["start"] == 0)
        replacement_node = next(
            row for row in document["source_ir"]["nodes"]
            if row["source"]["start"] == replacement_offset
        )
        operation = {
            "kind": "retarget_control_flow",
            "source_offset": 0,
            "reference_kind": reference_kind,
            "source_instruction_raw_sha256": source_node["source"]["raw_sha256"],
            "replacement_target_offset": replacement_offset,
            "replacement_target_instruction_raw_sha256": replacement_node["source"]["raw_sha256"],
        }
        return document, operation

    def test_plans_exact_continuation_target_edit(self) -> None:
        document, operation = self.fixture()
        result = planner.plan(document, operation)

        self.assertTrue(result["assembly_ready"])
        self.assertEqual("continuation_target", result["source_control"]["reference_kind"])
        self.assertEqual("none", result["source_control"]["expression_kind"])
        self.assertEqual((1, 5), (
            result["source_control"]["operand_start"],
            result["source_control"]["operand_end"],
        ))
        self.assertEqual((5, 6), (
            result["source_control"]["current_target_offset"],
            result["replacement_target"]["instruction_start"],
        ))
        self.assertEqual(("05000000", "06000000"), (
            result["patch"]["source_raw_hex"], result["patch"]["output_raw_hex"],
        ))
        self.assertEqual(result["coverage"]["source_code_size"], result["coverage"]["output_code_size"])

    def test_plans_branch_and_binds_condition_bytes(self) -> None:
        document, operation = self.fixture("branch")
        result = planner.plan(document, operation)

        self.assertEqual("condition_false_target", result["source_control"]["reference_kind"])
        self.assertEqual("condition", result["source_control"]["expression_kind"])
        self.assertEqual((1, 3), (
            result["source_control"]["expression_start"],
            result["source_control"]["expression_end"],
        ))
        self.assertEqual(
            hashlib.sha256(bytes.fromhex("01ff")).hexdigest(),
            result["source_control"]["expression_raw_sha256"],
        )
        self.assertEqual((3, 7), (
            result["patch"]["operand_start"], result["patch"]["operand_end"],
        ))

    def test_plan_is_deterministic_and_survives_json(self) -> None:
        document, operation = self.fixture()
        first = planner.plan(document, operation)
        second = planner.plan(copy.deepcopy(document), copy.deepcopy(operation))
        transported = json.loads(json.dumps(first))

        self.assertEqual(first, second)
        self.assertEqual(first, transported)
        planner.validate(transported, document)

    def test_rejects_stale_source_and_replacement_hashes(self) -> None:
        document, operation = self.fixture()
        stale_source = copy.deepcopy(operation)
        stale_source["source_instruction_raw_sha256"] = "0" * 64
        with self.assertRaisesRegex(planner.ControlTargetEditPlanError, "stale"):
            planner.plan(document, stale_source)
        stale_target = copy.deepcopy(operation)
        stale_target["replacement_target_instruction_raw_sha256"] = "0" * 64
        with self.assertRaisesRegex(planner.ControlTargetEditPlanError, "stale"):
            planner.plan(document, stale_target)

    def test_rejects_unchanged_unaligned_and_wrong_form(self) -> None:
        document, operation = self.fixture()
        unchanged = copy.deepcopy(operation)
        unchanged["replacement_target_offset"] = 5
        target = next(row for row in document["source_ir"]["nodes"] if row["source"]["start"] == 5)
        unchanged["replacement_target_instruction_raw_sha256"] = target["source"]["raw_sha256"]
        with self.assertRaisesRegex(planner.ControlTargetEditPlanError, "unchanged"):
            planner.plan(document, unchanged)
        unaligned = copy.deepcopy(operation)
        unaligned["replacement_target_offset"] = 4
        with self.assertRaisesRegex(planner.ControlTargetEditPlanError, "unique"):
            planner.plan(document, unaligned)
        wrong = copy.deepcopy(operation)
        wrong["reference_kind"] = "condition_false_target"
        with self.assertRaisesRegex(planner.ControlTargetEditPlanError, "form"):
            planner.plan(document, wrong)

    def test_rejects_changed_plan_and_unknown_fields(self) -> None:
        document, operation = self.fixture()
        result = planner.plan(document, operation)
        changed = copy.deepcopy(result)
        changed["patch"]["output_raw_hex"] = "05000000"
        changed["payload_sha256"] = planner.fingerprint(changed)
        with self.assertRaisesRegex(planner.ControlTargetEditPlanError, "differs"):
            planner.validate(changed, document)
        unknown = copy.deepcopy(result)
        unknown["ignored"] = True
        unknown["payload_sha256"] = planner.fingerprint(unknown)
        with self.assertRaisesRegex(planner.ControlTargetEditPlanError, "fields"):
            planner.validate(unknown)

    def test_cli_publishes_only_to_a_new_output(self) -> None:
        document, operation = self.fixture("branch")
        with tempfile.TemporaryDirectory() as raw_directory:
            root = Path(raw_directory)
            editable_path = root / "editable.json"
            operation_path = root / "operation.json"
            output_path = root / "plan.json"
            editable_path.write_text(json.dumps(document), encoding="utf-8")
            operation_path.write_text(json.dumps(operation), encoding="utf-8")
            command = [
                sys.executable, str(ROOT / "tools" / "plan_mes_control_target_edit.py"),
                str(editable_path), str(operation_path), str(output_path),
            ]
            completed = subprocess.run(command, check=False, capture_output=True, text=True)
            self.assertEqual(0, completed.returncode, completed.stderr)
            self.assertIn("MES_CONTROL_TARGET_EDIT_PLAN_PASS", completed.stdout)
            refused = subprocess.run(command, check=False, capture_output=True, text=True)
            self.assertNotEqual(0, refused.returncode)
            self.assertEqual(
                planner.plan(document, operation),
                json.loads(output_path.read_text(encoding="utf-8")),
            )


if __name__ == "__main__":
    unittest.main()
