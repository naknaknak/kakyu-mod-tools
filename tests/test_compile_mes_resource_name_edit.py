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

import compile_mes_resource_name_edit as compiler  # noqa: E402
import plan_mes_resource_name_edit as planner  # noqa: E402
from tests import test_plan_mes_resource_name_edit as plan_tests  # noqa: E402


class MesResourceNameCompilerTests(unittest.TestCase):
    def fixture(self, **kwargs: object) -> tuple[dict, dict]:
        editable, operation = plan_tests.MesResourceNameEditPlanTests().fixture(**kwargs)
        return editable, planner.plan(editable, operation)

    def test_compiles_exact_same_length_mmo_name_and_audit(self) -> None:
        editable, plan = self.fixture()
        output, audit = compiler.compile_resource_name(editable, plan)
        code_offset = editable["source_ir"]["container"]["code_offset"]

        self.assertEqual(bytes.fromhex("0d09ff01792e6d6d6f0000"), output[code_offset:])
        self.assertEqual(compiler.AUDIT_SCHEMA, audit["schema"])
        self.assertEqual("mmo", audit["operation"]["resource_kind"])
        self.assertEqual("w.mmo", audit["operation"]["source_name"])
        self.assertEqual("y.mmo", audit["operation"]["replacement_name"])
        self.assertTrue(all(audit["invariants"].values()))
        compiler.validate_audit(audit, editable, plan, output)

    def test_compiles_ax_name_without_changing_numeric_envelope(self) -> None:
        editable, plan = self.fixture(
            op="ax_resource_marker", source_name="w.ax", replacement_name="z.ax"
        )
        output, audit = compiler.compile_resource_name(editable, plan)
        code_offset = editable["source_ir"]["container"]["code_offset"]

        self.assertEqual(
            bytes.fromhex("0d08ff0200ff017a2e6178000202f900ff00"),
            output[code_offset:],
        )
        self.assertTrue(audit["invariants"]["marker_prefix_preserved"])
        self.assertTrue(audit["invariants"]["marker_suffix_preserved"])

    def test_compile_is_deterministic_and_preserves_source_documents(self) -> None:
        editable, plan = self.fixture()
        retained_editable = copy.deepcopy(editable)
        retained_plan = copy.deepcopy(plan)
        first = compiler.compile_resource_name(editable, plan)
        second = compiler.compile_resource_name(copy.deepcopy(editable), copy.deepcopy(plan))

        self.assertEqual(first, second)
        self.assertEqual(retained_editable, editable)
        self.assertEqual(retained_plan, plan)

    def test_rejects_plan_rebound_to_another_source(self) -> None:
        editable, plan = self.fixture()
        plan["source_identity"]["entry"] = "OTHER.MES"
        plan["payload_sha256"] = planner.fingerprint(plan)
        with self.assertRaisesRegex(planner.ResourceNameEditPlanError, "differs from its source"):
            compiler.compile_resource_name(editable, plan)

    def test_rejects_rehashed_audit_layout_mutation(self) -> None:
        editable, plan = self.fixture()
        _output, audit = compiler.compile_resource_name(editable, plan)
        audit["output"]["size"] += 1
        audit["payload_sha256"] = compiler.fingerprint(audit)
        with self.assertRaisesRegex(compiler.ResourceNameCompileError, "container summary"):
            compiler.validate_audit(audit)

    def test_rejects_rehashed_audit_name_boundary_mutation(self) -> None:
        editable, plan = self.fixture()
        _output, audit = compiler.compile_resource_name(editable, plan)
        audit["target"]["name_start"] -= 1
        audit["payload_sha256"] = compiler.fingerprint(audit)
        with self.assertRaisesRegex(compiler.ResourceNameCompileError, "target changed"):
            compiler.validate_audit(audit)

    def test_rejects_unknown_audit_field(self) -> None:
        editable, plan = self.fixture()
        _output, audit = compiler.compile_resource_name(editable, plan)
        audit["ignored"] = True
        audit["payload_sha256"] = compiler.fingerprint(audit)
        with self.assertRaisesRegex(compiler.ResourceNameCompileError, "schema or fields"):
            compiler.validate_audit(audit)

    def test_cli_publishes_new_mes_and_audit_once(self) -> None:
        editable, plan = self.fixture()
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            editable_path = root / "editable.json"
            plan_path = root / "plan.json"
            output_path = root / "changed.mes"
            audit_path = root / "audit.json"
            editable_path.write_text(json.dumps(editable), encoding="utf-8")
            plan_path.write_text(json.dumps(plan), encoding="utf-8")
            argv = [
                "compile_mes_resource_name_edit.py",
                str(editable_path), str(plan_path), str(output_path), str(audit_path),
            ]
            with mock.patch.object(sys, "argv", argv):
                compiler.main()
            published = json.loads(audit_path.read_text(encoding="utf-8"))
            compiler.validate_audit(published, editable, plan, output_path.read_bytes())
            with mock.patch.object(sys, "argv", argv):
                with self.assertRaisesRegex(compiler.ResourceNameCompileError, "already exists"):
                    compiler.main()


if __name__ == "__main__":
    unittest.main()
