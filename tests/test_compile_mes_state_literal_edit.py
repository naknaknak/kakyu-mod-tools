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

import compile_mes_state_literal_edit as compiler  # noqa: E402
import plan_mes_state_literal_edit as planner  # noqa: E402
from tests import test_plan_mes_state_literal_edit as plan_tests  # noqa: E402


class MesStateLiteralCompilerTests(unittest.TestCase):
    def fixture(self, **kwargs: object) -> tuple[dict, dict]:
        editable, operation = plan_tests.MesStateLiteralEditPlanTests().fixture(**kwargs)
        return editable, planner.plan(editable, operation)

    def test_compiles_exact_same_width_u8_literal_and_audit(self) -> None:
        editable, plan = self.fixture()
        output, audit = compiler.compile_state_literal(editable, plan)
        code_offset = editable["source_ir"]["container"]["code_offset"]

        self.assertEqual(bytes.fromhex("031e0102ff00"), output[code_offset:])
        container = editable["source_ir"]["container"]
        self.assertEqual(container["code_offset"] + container["code_size"], len(output))
        self.assertEqual(compiler.AUDIT_SCHEMA, audit["schema"])
        self.assertEqual("global_u8", audit["operation"]["storage"])
        self.assertEqual(1, audit["operation"]["source_value"])
        self.assertEqual(2, audit["operation"]["replacement_value"])
        self.assertTrue(all(audit["invariants"].values()))
        compiler.validate_audit(audit, editable, plan, output)

    def test_compiles_exact_same_width_u16_literal(self) -> None:
        editable, plan = self.fixture(
            operation_name="state_u16_write_run",
            command_id=0x04,
            source_value=0x1234,
            width=16,
            replacement_value=0x5678,
        )
        output, audit = compiler.compile_state_literal(editable, plan)
        code_offset = editable["source_ir"]["container"]["code_offset"]

        self.assertEqual(bytes.fromhex("0402f17856ff00"), output[code_offset:])
        self.assertEqual(16, audit["operation"]["width"])

    def test_compile_is_deterministic_and_preserves_source_document(self) -> None:
        editable, plan = self.fixture()
        retained_editable = copy.deepcopy(editable)
        retained_plan = copy.deepcopy(plan)
        first = compiler.compile_state_literal(editable, plan)
        second = compiler.compile_state_literal(copy.deepcopy(editable), copy.deepcopy(plan))

        self.assertEqual(first, second)
        self.assertEqual(retained_editable, editable)
        self.assertEqual(retained_plan, plan)

    def test_rejects_plan_rebound_to_another_source(self) -> None:
        editable, plan = self.fixture()
        plan["source_identity"]["entry"] = "OTHER.MES"
        plan["payload_sha256"] = planner.fingerprint(plan)
        with self.assertRaisesRegex(planner.StateLiteralEditPlanError, "differs from its source"):
            compiler.compile_state_literal(editable, plan)

    def test_rejects_rehashed_audit_layout_mutation(self) -> None:
        editable, plan = self.fixture()
        _output, audit = compiler.compile_state_literal(editable, plan)
        audit["output"]["size"] += 1
        audit["payload_sha256"] = compiler.fingerprint(audit)
        with self.assertRaisesRegex(compiler.StateLiteralCompileError, "container summary"):
            compiler.validate_audit(audit)

    def test_rejects_unknown_audit_field(self) -> None:
        editable, plan = self.fixture()
        _output, audit = compiler.compile_state_literal(editable, plan)
        audit["ignored"] = True
        audit["payload_sha256"] = compiler.fingerprint(audit)
        with self.assertRaisesRegex(compiler.StateLiteralCompileError, "schema or fields"):
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
                "compile_mes_state_literal_edit.py",
                str(editable_path),
                str(plan_path),
                str(output_path),
                str(audit_path),
            ]
            with mock.patch.object(sys, "argv", argv):
                compiler.main()
            published = json.loads(audit_path.read_text(encoding="utf-8"))
            compiler.validate_audit(
                published,
                editable,
                plan,
                output_path.read_bytes(),
            )
            with mock.patch.object(sys, "argv", argv):
                with self.assertRaisesRegex(
                    compiler.StateLiteralCompileError, "already exists"
                ):
                    compiler.main()


if __name__ == "__main__":
    unittest.main()
