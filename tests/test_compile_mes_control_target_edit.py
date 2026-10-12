from __future__ import annotations

import copy
import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

import compile_mes_control_target_edit as compiler  # noqa: E402
import plan_mes_control_target_edit as planner  # noqa: E402
from tests import test_plan_mes_control_target_edit as plan_tests  # noqa: E402


class MesControlTargetEditCompilerTests(unittest.TestCase):
    def fixture(self, kind: str = "continuation") -> tuple[dict, dict]:
        editable, operation = plan_tests.MesControlTargetEditPlanTests().fixture(kind)
        return editable, planner.plan(editable, operation)

    def test_compiles_exact_continuation_target_and_audit(self) -> None:
        editable, plan = self.fixture()
        output, audit = compiler.compile_target_edit(editable, plan)
        code_offset = editable["source_ir"]["container"]["code_offset"]

        self.assertEqual(bytes.fromhex("0c060000000000"), output[code_offset:])
        self.assertEqual([1], audit["patch"]["changed_code_offsets"])
        self.assertEqual("continuation_target", audit["operation"]["reference_kind"])
        self.assertTrue(all(audit["invariants"].values()))
        compiler.validate_audit(audit, editable, plan, output)

    def test_compiles_exact_branch_target(self) -> None:
        editable, plan = self.fixture("branch")
        output, audit = compiler.compile_target_edit(editable, plan)
        code_offset = editable["source_ir"]["container"]["code_offset"]

        self.assertEqual(bytes.fromhex("0b01ff080000000000"), output[code_offset:])
        self.assertEqual([3], audit["patch"]["changed_code_offsets"])
        self.assertEqual("condition_false_target", audit["operation"]["reference_kind"])

    def test_compile_is_deterministic_and_preserves_source_documents(self) -> None:
        editable, plan = self.fixture()
        retained_editable = copy.deepcopy(editable)
        retained_plan = copy.deepcopy(plan)
        first = compiler.compile_target_edit(editable, plan)
        second = compiler.compile_target_edit(copy.deepcopy(editable), copy.deepcopy(plan))

        self.assertEqual(first, second)
        self.assertEqual(retained_editable, editable)
        self.assertEqual(retained_plan, plan)

    def test_rejects_plan_rebound_to_another_source(self) -> None:
        editable, plan = self.fixture()
        plan["source_identity"]["entry"] = "OTHER.MES"
        plan["payload_sha256"] = planner.fingerprint(plan)
        with self.assertRaisesRegex(planner.ControlTargetEditPlanError, "differs"):
            compiler.compile_target_edit(editable, plan)

    def test_rejects_rehashed_audit_patch_and_layout_mutations(self) -> None:
        editable, plan = self.fixture()
        _output, audit = compiler.compile_target_edit(editable, plan)
        changed_patch = copy.deepcopy(audit)
        changed_patch["patch"]["changed_code_offsets"] = [2]
        changed_patch["payload_sha256"] = compiler.fingerprint(changed_patch)
        with self.assertRaisesRegex(compiler.ControlTargetEditCompileError, "patch"):
            compiler.validate_audit(changed_patch)
        changed_layout = copy.deepcopy(audit)
        changed_layout["output"]["code_size"] += 1
        changed_layout["payload_sha256"] = compiler.fingerprint(changed_layout)
        with self.assertRaisesRegex(compiler.ControlTargetEditCompileError, "summary"):
            compiler.validate_audit(changed_layout)

    def test_rejects_unknown_audit_field(self) -> None:
        editable, plan = self.fixture()
        _output, audit = compiler.compile_target_edit(editable, plan)
        audit["ignored"] = True
        audit["payload_sha256"] = compiler.fingerprint(audit)
        with self.assertRaisesRegex(compiler.ControlTargetEditCompileError, "fields"):
            compiler.validate_audit(audit)

    def test_cli_publishes_new_mes_and_audit_once(self) -> None:
        editable, plan = self.fixture("branch")
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            editable_path = root / "editable.json"
            plan_path = root / "plan.json"
            output_path = root / "changed.mes"
            audit_path = root / "audit.json"
            editable_path.write_text(json.dumps(editable), encoding="utf-8")
            plan_path.write_text(json.dumps(plan), encoding="utf-8")
            argv = [
                "compile_mes_control_target_edit.py", str(editable_path),
                str(plan_path), str(output_path), str(audit_path),
            ]
            with mock.patch.object(sys, "argv", argv):
                compiler.main()
            compiler.validate_audit(
                json.loads(audit_path.read_text(encoding="utf-8")), editable,
                plan, output_path.read_bytes(),
            )
            with mock.patch.object(sys, "argv", argv):
                with self.assertRaisesRegex(
                    compiler.ControlTargetEditCompileError, "already exists"
                ):
                    compiler.main()


if __name__ == "__main__":
    unittest.main()
