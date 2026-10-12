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

import compile_mes_control_body_edit as compiler  # noqa: E402
import plan_mes_control_body_edit as planner  # noqa: E402
from tests import test_plan_mes_control_body_edit as plan_tests  # noqa: E402


class MesControlBodyEditCompilerTests(unittest.TestCase):
    def fixture(self, kind: str = "insert") -> tuple[dict, dict]:
        editable, insert, remove = plan_tests.MesControlBodyEditPlanTests().fixture()
        operation = insert if kind == "insert" else remove
        return editable, planner.plan(editable, operation)

    def test_compiles_exact_body_insertion_and_target_patch(self) -> None:
        editable, plan = self.fixture()
        output, audit = compiler.compile_body_edit(editable, plan)
        code_offset = audit["output"]["code_offset"]
        code = output[code_offset:]

        self.assertEqual(27, len(code))
        self.assertEqual(bytes.fromhex("1f01000000"), code[6:11])
        self.assertEqual(bytes.fromhex("0c1a000000"), code[16:21])
        self.assertEqual([17], audit["changed_output_code_offsets"])
        self.assertEqual(7, audit["coverage"]["expected_output_node_count"])
        self.assertTrue(all(audit["invariants"].values()))
        compiler.validate_audit(audit, editable, plan, output)

    def test_compiles_exact_body_removal_and_target_patch(self) -> None:
        editable, plan = self.fixture("remove")
        output, audit = compiler.compile_body_edit(editable, plan)
        code_offset = audit["output"]["code_offset"]
        code = output[code_offset:]

        self.assertEqual(17, len(code))
        self.assertEqual(bytes.fromhex("1f02000000"), code[1:6])
        self.assertEqual(bytes.fromhex("0c10000000"), code[6:11])
        self.assertEqual([7], audit["changed_output_code_offsets"])
        self.assertEqual(5, audit["coverage"]["expected_output_node_count"])
        compiler.validate_audit(audit, editable, plan, output)

    def test_compile_is_deterministic_and_preserves_source_documents(self) -> None:
        editable, plan = self.fixture()
        retained_editable = copy.deepcopy(editable)
        retained_plan = copy.deepcopy(plan)
        first = compiler.compile_body_edit(editable, plan)
        second = compiler.compile_body_edit(copy.deepcopy(editable), copy.deepcopy(plan))

        self.assertEqual(first, second)
        self.assertEqual(retained_editable, editable)
        self.assertEqual(retained_plan, plan)

    def test_rejects_blocked_plan(self) -> None:
        editable, insert, _remove = plan_tests.MesControlBodyEditPlanTests().fixture(target_offset=6)
        blocked = planner.plan(editable, insert)
        self.assertFalse(blocked["assembly_ready"])
        with self.assertRaisesRegex(compiler.ControlBodyEditCompileError, "blocked"):
            compiler.compile_body_edit(editable, blocked)

    def test_rejects_rehashed_audit_patch_offset_and_layout_mutations(self) -> None:
        editable, plan = self.fixture()
        output, audit = compiler.compile_body_edit(editable, plan)
        changed_patch = copy.deepcopy(audit)
        changed_patch["target_patches"][0]["output_raw_hex"] = "19000000"
        changed_patch["relocation"]["target_patch_stream_sha256"] = compiler._json_sha256(
            changed_patch["target_patches"]
        )
        changed_patch["payload_sha256"] = compiler.fingerprint(changed_patch)
        with self.assertRaisesRegex(compiler.ControlBodyEditCompileError, "target patch|changed offsets"):
            compiler.validate_audit(changed_patch)
        changed_layout = copy.deepcopy(audit)
        changed_layout["output"]["code_size"] += 1
        changed_layout["payload_sha256"] = compiler.fingerprint(changed_layout)
        with self.assertRaisesRegex(compiler.ControlBodyEditCompileError, "summary"):
            compiler.validate_audit(changed_layout)
        changed_output = bytearray(output)
        changed_output[-1] ^= 0xFF
        with self.assertRaisesRegex(compiler.ControlBodyEditCompileError, "differs"):
            compiler.validate_audit(audit, editable, plan, bytes(changed_output))

    def test_rejects_unknown_audit_field(self) -> None:
        editable, plan = self.fixture()
        _output, audit = compiler.compile_body_edit(editable, plan)
        audit["ignored"] = True
        audit["payload_sha256"] = compiler.fingerprint(audit)
        with self.assertRaisesRegex(compiler.ControlBodyEditCompileError, "fields"):
            compiler.validate_audit(audit)

    def test_cli_publishes_new_mes_and_audit_once(self) -> None:
        editable, plan = self.fixture("remove")
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            editable_path = root / "editable.json"
            plan_path = root / "plan.json"
            output_path = root / "changed.mes"
            audit_path = root / "audit.json"
            editable_path.write_text(json.dumps(editable), encoding="utf-8")
            plan_path.write_text(json.dumps(plan), encoding="utf-8")
            argv = [
                "compile_mes_control_body_edit.py", str(editable_path), str(plan_path),
                str(output_path), str(audit_path),
            ]
            with mock.patch.object(sys, "argv", argv):
                compiler.main()
            compiler.validate_audit(
                json.loads(audit_path.read_text(encoding="utf-8")), editable,
                plan, output_path.read_bytes(),
            )
            with mock.patch.object(sys, "argv", argv):
                with self.assertRaisesRegex(
                    compiler.ControlBodyEditCompileError, "already exists"
                ):
                    compiler.main()


if __name__ == "__main__":
    unittest.main()
