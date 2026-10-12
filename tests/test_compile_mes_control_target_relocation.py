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

import compile_mes_control_target_relocation as compiler  # noqa: E402
import compile_mes_noop as noop_compiler  # noqa: E402
import plan_mes_control_target_relocation as control_planner  # noqa: E402
import plan_mes_message_relocation as message_planner  # noqa: E402
import prepare_mes_editable_ir as editable_ir  # noqa: E402
from tests import test_plan_mes_message_relocation as message_tests  # noqa: E402


class MesControlTargetRelocationCompilerTests(unittest.TestCase):
    def fixture(self, kind: str = "continuation") -> tuple[dict, dict, dict]:
        control = "branch" if kind == "branch" else True
        editable_document, operation = (
            message_tests.MesMessageRelocationPlanTests().fixture(
                code_reference=control
            )
        )
        message_plan = message_planner.plan(editable_document, operation)
        control_plan = control_planner.plan(editable_document, message_plan)
        return editable_document, message_plan, control_plan

    def test_compiles_message_and_shifted_continuation_target(self) -> None:
        editable_document, message_plan, control_plan = self.fixture()
        output, audit = compiler.compile_message_with_targets(
            editable_document, message_plan, control_plan
        )
        reopened = noop_compiler.reopen_container(output)

        self.assertEqual([0, 6], reopened["entry_offsets"])
        self.assertEqual(11, reopened["code_size"])
        self.assertEqual(bytes.fromhex("0182a282a4000c06000000"), output[12:])
        self.assertEqual(1, audit["relocation"]["target_patch_count"])
        self.assertEqual("06000000", audit["target_patches"][0]["output_raw_hex"])
        self.assertTrue(all(audit["invariants"].values()))

    def test_compiles_message_and_shifted_branch_target(self) -> None:
        editable_document, message_plan, control_plan = self.fixture("branch")
        output, audit = compiler.compile_message_with_targets(
            editable_document, message_plan, control_plan
        )

        self.assertEqual(bytes.fromhex("0182a282a4000b01ff06000000"), output[12:])
        self.assertEqual("condition_false_target", audit["target_patches"][0]["reference_kind"])
        self.assertEqual(13, audit["output"]["code_size"])

    def test_compiles_message_and_definition_skip_target(self) -> None:
        editable_document, operation = (
            message_tests.MesMessageRelocationPlanTests().fixture(
                definition_target=True
            )
        )
        message_plan = message_planner.plan(editable_document, operation)
        control_plan = control_planner.plan(editable_document, message_plan)
        output, audit = compiler.compile_message_with_targets(
            editable_document, message_plan, control_plan
        )

        self.assertEqual(
            bytes.fromhex("0182a282a400100200ff000f00000000"), output[12:]
        )
        self.assertEqual("definition_skip_target", audit["target_patches"][0]["reference_kind"])
        self.assertEqual(16, audit["output"]["code_size"])

    def test_compile_is_deterministic_and_audit_survives_json(self) -> None:
        editable_document, message_plan, control_plan = self.fixture()
        first_output, first_audit = compiler.compile_message_with_targets(
            editable_document, message_plan, control_plan
        )
        second_output, second_audit = compiler.compile_message_with_targets(
            copy.deepcopy(editable_document),
            copy.deepcopy(message_plan),
            copy.deepcopy(control_plan),
        )
        transported = json.loads(json.dumps(first_audit, ensure_ascii=False))

        self.assertEqual(first_output, second_output)
        self.assertEqual(first_audit, second_audit)
        compiler.validate_audit(
            transported,
            editable_document,
            message_plan,
            control_plan,
            first_output,
        )

    def test_rejects_remaining_opaque_blocker(self) -> None:
        editable_document, operation = (
            message_tests.MesMessageRelocationPlanTests().fixture(opaque_suffix=True)
        )
        message_plan = message_planner.plan(editable_document, operation)
        control_plan = control_planner.plan(editable_document, message_plan)

        with self.assertRaisesRegex(compiler.ControlTargetCompileError, "blocked"):
            compiler.compile_message_with_targets(
                editable_document, message_plan, control_plan
            )

    def test_rejects_stale_rehashed_operand_patch(self) -> None:
        editable_document, message_plan, control_plan = self.fixture()
        control_plan["target_patches"][0]["source_raw_hex"] = "05000000"
        control_plan["payload_sha256"] = control_planner.fingerprint(control_plan)

        with self.assertRaisesRegex(
            control_planner.ControlTargetRelocationPlanError, "boundary|source"
        ):
            compiler.compile_message_with_targets(
                editable_document, message_plan, control_plan
            )

    def test_rejects_changed_output_audit_and_unknown_field(self) -> None:
        editable_document, message_plan, control_plan = self.fixture()
        output, audit = compiler.compile_message_with_targets(
            editable_document, message_plan, control_plan
        )
        changed = copy.deepcopy(audit)
        changed["output"]["entry_sha256"] = "0" * 64
        changed["payload_sha256"] = compiler.fingerprint(changed)
        with self.assertRaisesRegex(compiler.ControlTargetCompileError, "differs"):
            compiler.validate_audit(
                changed,
                editable_document,
                message_plan,
                control_plan,
                output,
            )
        unknown = copy.deepcopy(audit)
        unknown["ignored"] = True
        unknown["payload_sha256"] = compiler.fingerprint(unknown)
        with self.assertRaisesRegex(compiler.ControlTargetCompileError, "fields"):
            compiler.validate_audit(unknown)

    def test_cli_publishes_mes_and_audit_once(self) -> None:
        editable_document, message_plan, control_plan = self.fixture()
        with tempfile.TemporaryDirectory() as raw_directory:
            root = Path(raw_directory)
            editable_path = root / "editable.json"
            message_path = root / "message-plan.json"
            control_path = root / "control-plan.json"
            output_path = root / "compiled.mes"
            audit_path = root / "compiled.audit.json"
            editable_path.write_bytes(editable_ir.canonical_json_bytes(editable_document) + b"\n")
            message_path.write_bytes(editable_ir.canonical_json_bytes(message_plan) + b"\n")
            control_path.write_bytes(editable_ir.canonical_json_bytes(control_plan) + b"\n")
            command = [
                sys.executable,
                str(ROOT / "tools" / "compile_mes_control_target_relocation.py"),
                str(editable_path),
                str(message_path),
                str(control_path),
                str(output_path),
                str(audit_path),
            ]
            first = subprocess.run(command, check=False, capture_output=True, text=True)
            second = subprocess.run(command, check=False, capture_output=True, text=True)

            self.assertEqual(0, first.returncode, first.stderr)
            self.assertIn("patches=1", first.stdout)
            self.assertNotEqual(0, second.returncode)
            compiler.validate_audit(
                json.loads(audit_path.read_text(encoding="utf-8")),
                editable_document,
                message_plan,
                control_plan,
                output_path.read_bytes(),
            )


if __name__ == "__main__":
    unittest.main()
