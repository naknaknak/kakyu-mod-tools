from __future__ import annotations

import copy
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

import compile_mes_registered_definition_call_edit as compiler  # noqa: E402
import decompile_mes_handoff as decompiler  # noqa: E402
import plan_mes_registered_definition_call_edit as planner  # noqa: E402
from tests.test_plan_mes_registered_definition_call_edit import (  # noqa: E402
    MesRegisteredDefinitionCallEditPlanTests,
)


class MesRegisteredDefinitionCallCompileTests(unittest.TestCase):
    def fixture(self) -> tuple[dict, dict, dict, dict]:
        editable, call_family, registry, operation = (
            MesRegisteredDefinitionCallEditPlanTests().fixture()
        )
        return editable, call_family, registry, planner.plan(
            editable, call_family, registry, operation
        )

    def test_compiles_only_literal_byte_and_preserves_all_certificates(self) -> None:
        editable, call_family, registry, plan = self.fixture()
        output, audit = compiler.compile_registered_definition_call(
            editable, call_family, registry, plan
        )

        source = decompiler.reconstruct_container(editable["source_ir"])
        code_offset = len(source) - editable["source_ir"]["coverage"]["code_bytes"]
        changed = [
            index for index, (before, after) in enumerate(zip(source, output))
            if before != after
        ]
        self.assertEqual([code_offset + 2], changed)
        self.assertEqual(
            bytes.fromhex("110204ff00"), output[code_offset:code_offset + 5]
        )
        self.assertEqual(b"\x00", output[code_offset + 5:code_offset + 6])
        self.assertEqual(5, audit["operation"]["physical_resume_offset"])
        self.assertEqual("linear_00000005", audit["target"]["resume_node_id"])
        self.assertEqual(7, audit["target"]["source_registry_binding"]["body_start"])
        self.assertEqual(
            20, audit["target"]["replacement_registry_binding"]["body_start"]
        )
        self.assertTrue(all(audit["invariants"].values()))
        self.assertEqual(compiler.fingerprint(audit), audit["payload_sha256"])

    def test_compile_is_deterministic(self) -> None:
        editable, call_family, registry, plan = self.fixture()
        first = compiler.compile_registered_definition_call(
            editable, call_family, registry, plan
        )
        second = compiler.compile_registered_definition_call(
            copy.deepcopy(editable), copy.deepcopy(call_family),
            copy.deepcopy(registry), copy.deepcopy(plan),
        )
        self.assertEqual(first, second)

    def test_rejects_stale_plan_instruction(self) -> None:
        editable, call_family, registry, plan = self.fixture()
        plan["target"]["instruction_raw_hex"] = "110202ff00"
        plan["payload_sha256"] = planner.fingerprint(plan)
        with self.assertRaisesRegex(
            planner.RegisteredDefinitionCallEditPlanError, "planned hash changed"
        ):
            compiler.compile_registered_definition_call(
                editable, call_family, registry, plan
            )

    def test_audit_rejects_changed_resume_and_registry_binding(self) -> None:
        editable, call_family, registry, plan = self.fixture()
        _output, audit = compiler.compile_registered_definition_call(
            editable, call_family, registry, plan
        )
        audit["operation"]["physical_resume_offset"] += 1
        audit["payload_sha256"] = compiler.fingerprint(audit)
        with self.assertRaisesRegex(
            compiler.RegisteredDefinitionCallCompileError, "target changed"
        ):
            compiler.validate_audit(audit)

        _output, audit = compiler.compile_registered_definition_call(
            editable, call_family, registry, plan
        )
        audit["target"]["replacement_registry_binding"]["body_raw_sha256"] = "x" * 64
        audit["payload_sha256"] = compiler.fingerprint(audit)
        with self.assertRaisesRegex(
            compiler.RegisteredDefinitionCallCompileError, "target changed"
        ):
            compiler.validate_audit(audit)

        _output, audit = compiler.compile_registered_definition_call(
            editable, call_family, registry, plan
        )
        audit["target"]["replacement_registry_binding"]["selector"] = 5
        audit["payload_sha256"] = compiler.fingerprint(audit)
        with self.assertRaisesRegex(
            compiler.RegisteredDefinitionCallCompileError, "target changed"
        ):
            compiler.validate_audit(audit)

    def test_audit_rejects_unknown_field_and_fractional_coordinate(self) -> None:
        editable, call_family, registry, plan = self.fixture()
        _output, audit = compiler.compile_registered_definition_call(
            editable, call_family, registry, plan
        )
        audit["ignored"] = True
        audit["payload_sha256"] = compiler.fingerprint(audit)
        with self.assertRaisesRegex(
            compiler.RegisteredDefinitionCallCompileError, "schema or fields"
        ):
            compiler.validate_audit(audit)

        _output, audit = compiler.compile_registered_definition_call(
            editable, call_family, registry, plan
        )
        audit["target"]["literal_start"] = 2.5
        audit["payload_sha256"] = compiler.fingerprint(audit)
        with self.assertRaisesRegex(
            compiler.RegisteredDefinitionCallCompileError, "target changed"
        ):
            compiler.validate_audit(audit)

    def test_cli_publishes_new_files_and_refuses_overwrite(self) -> None:
        editable, call_family, registry, plan = self.fixture()
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            editable_path = root / "editable.json"
            call_family_path = root / "call-family.json"
            registry_path = root / "registry.json"
            plan_path = root / "plan.json"
            output_path = root / "output.mes"
            audit_path = root / "audit.json"
            for path, value in (
                (editable_path, editable), (call_family_path, call_family),
                (registry_path, registry), (plan_path, plan),
            ):
                path.write_text(json.dumps(value), encoding="utf-8")
            command = [
                sys.executable,
                str(
                    ROOT / "tools"
                    / "compile_mes_registered_definition_call_edit.py"
                ),
                str(editable_path), str(call_family_path), str(registry_path),
                str(plan_path), str(output_path), str(audit_path),
            ]
            completed = subprocess.run(
                command, cwd=ROOT, text=True, capture_output=True, check=False
            )
            self.assertEqual(0, completed.returncode, completed.stderr)
            self.assertIn(
                "MES_REGISTERED_DEFINITION_CALL_COMPILE_PASS", completed.stdout
            )
            self.assertTrue(output_path.is_file())
            self.assertTrue(audit_path.is_file())

            repeated = subprocess.run(
                command, cwd=ROOT, text=True, capture_output=True, check=False
            )
            self.assertNotEqual(0, repeated.returncode)
            self.assertIn("output already exists", repeated.stderr)


if __name__ == "__main__":
    unittest.main()
