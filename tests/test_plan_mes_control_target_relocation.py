from __future__ import annotations

import copy
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
import plan_mes_control_target_relocation as planner  # noqa: E402
import plan_mes_message_relocation as message_planner  # noqa: E402
import prepare_mes_editable_ir as editable_ir  # noqa: E402
from tests import test_plan_mes_message_relocation as message_tests  # noqa: E402


class MesControlTargetRelocationPlanTests(unittest.TestCase):
    def fixture(self, kind: str = "continuation") -> tuple[dict, dict]:
        control = "branch" if kind == "branch" else True
        editable_document, operation = (
            message_tests.MesMessageRelocationPlanTests().fixture(
                code_reference=control
            )
        )
        return editable_document, message_planner.plan(editable_document, operation)

    def test_resolves_exact_continuation_u32_operand(self) -> None:
        editable_document, message_plan = self.fixture()
        result = planner.plan(editable_document, message_plan)

        self.assertTrue(result["assembly_ready"])
        self.assertEqual([], result["remaining_blockers"])
        self.assertEqual(["code_00000000"], result["resolved_blocker_reference_ids"])
        patch = result["target_patches"][0]
        self.assertEqual("continuation_target", patch["reference_kind"])
        self.assertEqual("continuation_transfer", patch["owner_op"])
        self.assertEqual((5, 9), (patch["source_operand_start"], patch["source_operand_end"]))
        self.assertEqual((7, 11), (patch["output_operand_start"], patch["output_operand_end"]))
        self.assertEqual((4, 6), (patch["source_target_offset"], patch["output_target_offset"]))
        self.assertEqual(("04000000", "06000000"), (patch["source_raw_hex"], patch["output_raw_hex"]))

    def test_resolves_branch_tail_after_variable_length_condition(self) -> None:
        editable_document, message_plan = self.fixture("branch")
        result = planner.plan(editable_document, message_plan)

        self.assertTrue(result["assembly_ready"])
        patch = result["target_patches"][0]
        self.assertEqual("condition_false_target", patch["reference_kind"])
        self.assertEqual("branch_if_not_true", patch["owner_op"])
        self.assertEqual((7, 11), (patch["source_operand_start"], patch["source_operand_end"]))
        self.assertEqual((9, 13), (patch["output_operand_start"], patch["output_operand_end"]))
        self.assertEqual(0x0B, patch["command_id"])

    def test_resolves_typed_command_10_definition_skip_target(self) -> None:
        editable_document, operation = (
            message_tests.MesMessageRelocationPlanTests().fixture(
                definition_target=True
            )
        )
        message_plan = message_planner.plan(editable_document, operation)
        result = planner.plan(editable_document, message_plan)

        self.assertTrue(result["assembly_ready"])
        self.assertEqual([], result["remaining_blockers"])
        self.assertEqual(1, len(result["target_patches"]))
        patch = result["target_patches"][0]
        self.assertEqual("definition_skip_target", patch["reference_kind"])
        self.assertEqual("command_10", patch["owner_op"])
        self.assertEqual((9, 13), (patch["source_operand_start"], patch["source_operand_end"]))
        self.assertEqual((11, 15), (patch["output_operand_start"], patch["output_operand_end"]))
        self.assertEqual((13, 15), (patch["source_target_offset"], patch["output_target_offset"]))

    def test_retains_unresolved_command_10_definition_target_as_blocker(self) -> None:
        editable_document, operation = (
            message_tests.MesMessageRelocationPlanTests().fixture(
                definition_target=True
            )
        )
        source_ir = editable_document["source_ir"]
        definition = next(
            node
            for node in source_ir["nodes"]
            if node.get("statement", {}).get("op") == "command_10"
        )
        definition["statement"]["operands"][1]["value"] = [13, 0, 0]
        source_ir["payload_sha256"] = decompiler.fingerprint(source_ir)
        editable_document["payload_sha256"] = editable_ir.fingerprint(editable_document)
        message_plan = message_planner.plan(editable_document, operation)
        result = planner.plan(editable_document, message_plan)

        self.assertFalse(result["assembly_ready"])
        self.assertEqual([], result["target_patches"])
        self.assertEqual(
            "definition_skip_target_unresolved",
            result["remaining_blockers"][0]["code"],
        )

    def test_plan_is_deterministic_and_survives_json(self) -> None:
        editable_document, message_plan = self.fixture()
        first = planner.plan(editable_document, message_plan)
        second = planner.plan(copy.deepcopy(editable_document), copy.deepcopy(message_plan))
        transported = json.loads(json.dumps(first, ensure_ascii=False))

        self.assertEqual(first, second)
        self.assertEqual(first, transported)
        self.assertEqual(first["payload_sha256"], planner.fingerprint(first))
        planner.validate(transported, editable_document, message_plan)

    def test_retains_non_control_blocker(self) -> None:
        editable_document, operation = (
            message_tests.MesMessageRelocationPlanTests().fixture(opaque_suffix=True)
        )
        message_plan = message_planner.plan(editable_document, operation)
        result = planner.plan(editable_document, message_plan)

        self.assertFalse(result["assembly_ready"])
        self.assertEqual([], result["target_patches"])
        self.assertEqual(
            "opaque_boundary_would_shift", result["remaining_blockers"][0]["code"]
        )

    def test_retains_unaligned_control_target(self) -> None:
        editable_document, _message_plan = self.fixture()
        source_ir = editable_document["source_ir"]
        code_reference = next(
            row for row in source_ir["references"] if row["kind"] == "code"
        )
        code_reference["value"]["aligned"] = False
        source_ir["payload_sha256"] = decompiler.fingerprint(source_ir)
        editable_document["payload_sha256"] = editable_ir.fingerprint(editable_document)
        operation = message_tests.MesMessageRelocationPlanTests().fixture(
            code_reference=True
        )[1]
        message_plan = message_planner.plan(editable_document, operation)
        result = planner.plan(editable_document, message_plan)

        self.assertFalse(result["assembly_ready"])
        self.assertEqual([], result["target_patches"])
        self.assertEqual(
            "encoded_code_target_requires_mw03",
            result["remaining_blockers"][0]["code"],
        )

    def test_rejects_changed_plan_and_unknown_fields(self) -> None:
        editable_document, message_plan = self.fixture()
        result = planner.plan(editable_document, message_plan)
        changed = copy.deepcopy(result)
        changed["target_patches"][0]["output_raw_hex"] = "07000000"
        changed["payload_sha256"] = planner.fingerprint(changed)
        with self.assertRaisesRegex(
            planner.ControlTargetRelocationPlanError, "bytes|boundary|source"
        ):
            planner.validate(changed, editable_document, message_plan)
        unknown = copy.deepcopy(result)
        unknown["ignored"] = True
        unknown["payload_sha256"] = planner.fingerprint(unknown)
        with self.assertRaisesRegex(planner.ControlTargetRelocationPlanError, "fields"):
            planner.validate(unknown)

    def test_cli_publishes_plan_once(self) -> None:
        editable_document, message_plan = self.fixture()
        with tempfile.TemporaryDirectory() as raw_directory:
            root = Path(raw_directory)
            editable_path = root / "editable.json"
            message_path = root / "message-plan.json"
            output_path = root / "control-plan.json"
            editable_path.write_bytes(editable_ir.canonical_json_bytes(editable_document) + b"\n")
            message_path.write_bytes(editable_ir.canonical_json_bytes(message_plan) + b"\n")
            command = [
                sys.executable,
                str(ROOT / "tools" / "plan_mes_control_target_relocation.py"),
                str(editable_path),
                str(message_path),
                str(output_path),
            ]
            first = subprocess.run(command, check=False, capture_output=True, text=True)
            second = subprocess.run(command, check=False, capture_output=True, text=True)

            self.assertEqual(0, first.returncode, first.stderr)
            self.assertIn("assembly_ready=true", first.stdout)
            self.assertNotEqual(0, second.returncode)
            planner.validate(
                json.loads(output_path.read_text(encoding="utf-8")),
                editable_document,
                message_plan,
            )


if __name__ == "__main__":
    unittest.main()
