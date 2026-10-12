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

import compile_mes_inline_script_name_edit as compiler  # noqa: E402
import plan_mes_inline_script_name_edit as planner  # noqa: E402
from tests import test_plan_mes_inline_script_name_edit as plan_tests  # noqa: E402


class MesInlineScriptNameCompilerTests(unittest.TestCase):
    def fixture(self, **kwargs: object) -> tuple[dict, dict]:
        editable, operation = plan_tests.MesInlineScriptNameEditPlanTests().fixture(**kwargs)
        return editable, planner.plan(editable, operation)

    def test_compiles_name_inside_opaque_owner_and_preserves_envelope(self) -> None:
        editable, plan = self.fixture(replacement_name="synth01.lib")
        output, audit = compiler.compile_inline_script_name(editable, plan)
        code_offset = editable["source_ir"]["container"]["code_offset"]

        self.assertEqual(
            bytes.fromhex("00130d08ff0202ff0173796e746830312e6c696200001900"),
            output[code_offset:],
        )
        self.assertEqual(compiler.AUDIT_SCHEMA, audit["schema"])
        self.assertEqual("opaque", audit["target"]["owner_kind"])
        self.assertEqual("bounded_envelope_scan", audit["target"]["reference_boundary"])
        self.assertEqual("liblary.lib", audit["operation"]["source_name"])
        self.assertEqual("synth01.lib", audit["operation"]["replacement_name"])
        self.assertTrue(all(audit["invariants"].values()))
        compiler.validate_audit(audit, editable, plan, output)

    def test_compiles_typed_definition_target(self) -> None:
        editable, plan = self.fixture(
            selector=3,
            source_name="def_main.mes",
            replacement_name="synthzzz.mes",
            typed=True,
        )
        output, audit = compiler.compile_inline_script_name(editable, plan)
        code_offset = editable["source_ir"]["container"]["code_offset"]

        self.assertEqual(
            bytes.fromhex("0d08ff0203ff0173796e74687a7a7a2e6d65730000"),
            output[code_offset:],
        )
        self.assertEqual("statement", audit["target"]["owner_kind"])
        self.assertEqual("strict_indexed", audit["target"]["reference_boundary"])

    def test_compile_is_deterministic_and_preserves_inputs(self) -> None:
        editable, plan = self.fixture()
        retained_editable = copy.deepcopy(editable)
        retained_plan = copy.deepcopy(plan)
        first = compiler.compile_inline_script_name(editable, plan)
        second = compiler.compile_inline_script_name(
            copy.deepcopy(editable), copy.deepcopy(plan)
        )

        self.assertEqual(first, second)
        self.assertEqual(retained_editable, editable)
        self.assertEqual(retained_plan, plan)

    def test_rejects_plan_rebound_to_another_source(self) -> None:
        editable, plan = self.fixture()
        plan["source_identity"]["entry"] = "OTHER.MES"
        plan["payload_sha256"] = planner.fingerprint(plan)
        with self.assertRaisesRegex(
            planner.InlineScriptNameEditPlanError, "differs from its source"
        ):
            compiler.compile_inline_script_name(editable, plan)

    def test_rejects_rehashed_audit_owner_boundary_mutation(self) -> None:
        editable, plan = self.fixture()
        _output, audit = compiler.compile_inline_script_name(editable, plan)
        audit["target"]["owner_end"] -= 1
        audit["payload_sha256"] = compiler.fingerprint(audit)
        with self.assertRaisesRegex(compiler.InlineScriptNameCompileError, "target changed"):
            compiler.validate_audit(audit)

    def test_rejects_rehashed_audit_layout_mutation(self) -> None:
        editable, plan = self.fixture()
        _output, audit = compiler.compile_inline_script_name(editable, plan)
        audit["output"]["size"] += 1
        audit["payload_sha256"] = compiler.fingerprint(audit)
        with self.assertRaisesRegex(
            compiler.InlineScriptNameCompileError, "container summary"
        ):
            compiler.validate_audit(audit)

    def test_rejects_unknown_audit_field(self) -> None:
        editable, plan = self.fixture()
        _output, audit = compiler.compile_inline_script_name(editable, plan)
        audit["ignored"] = True
        audit["payload_sha256"] = compiler.fingerprint(audit)
        with self.assertRaisesRegex(
            compiler.InlineScriptNameCompileError, "schema or fields"
        ):
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
                "compile_mes_inline_script_name_edit.py",
                str(editable_path), str(plan_path), str(output_path), str(audit_path),
            ]
            with mock.patch.object(sys, "argv", argv):
                compiler.main()
            published = json.loads(audit_path.read_text(encoding="utf-8"))
            compiler.validate_audit(
                published, editable, plan, output_path.read_bytes()
            )
            with mock.patch.object(sys, "argv", argv):
                with self.assertRaisesRegex(
                    compiler.InlineScriptNameCompileError, "already exists"
                ):
                    compiler.main()


if __name__ == "__main__":
    unittest.main()
