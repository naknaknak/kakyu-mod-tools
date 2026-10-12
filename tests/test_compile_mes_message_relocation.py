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

import compile_mes_message_relocation as compiler  # noqa: E402
import compile_mes_noop as noop_compiler  # noqa: E402
import plan_mes_message_relocation as planner  # noqa: E402
import prepare_mes_editable_ir as editable_ir  # noqa: E402
from tests import test_plan_mes_message_relocation as plan_tests  # noqa: E402


class MesMessageRelocationCompilerTests(unittest.TestCase):
    def fixture(self, **kwargs) -> tuple[dict, dict]:
        editable_document, operation = plan_tests.MesMessageRelocationPlanTests().fixture(
            **kwargs
        )
        return editable_document, planner.plan(editable_document, operation)

    def test_compiles_blocker_free_variable_length_message(self) -> None:
        editable_document, plan = self.fixture()
        output, audit = compiler.compile_message(editable_document, plan)
        reopened = noop_compiler.reopen_container(output)

        self.assertEqual([0, 6], reopened["entry_offsets"])
        self.assertEqual(9, reopened["code_size"])
        self.assertEqual(bytes.fromhex("0182a282a40082a200"), output[12:])
        self.assertEqual(compiler.AUDIT_SCHEMA, audit["schema"])
        self.assertEqual(2, audit["relocation"]["delta"])
        self.assertTrue(all(audit["invariants"].values()))
        self.assertEqual(hashlib.sha256(output).hexdigest(), audit["output"]["entry_sha256"])

    def test_compile_is_deterministic_and_audit_survives_json(self) -> None:
        editable_document, plan = self.fixture()
        first_output, first_audit = compiler.compile_message(editable_document, plan)
        second_output, second_audit = compiler.compile_message(
            copy.deepcopy(editable_document), copy.deepcopy(plan)
        )
        transported = json.loads(json.dumps(first_audit, ensure_ascii=False))

        self.assertEqual(first_output, second_output)
        self.assertEqual(first_audit, second_audit)
        compiler.validate_audit(transported, editable_document, plan, first_output)

    def test_rejects_plan_with_mw03_blocker(self) -> None:
        editable_document, plan = self.fixture(code_reference=True)
        self.assertFalse(plan["assembly_ready"])
        with self.assertRaisesRegex(compiler.MessageCompileError, "blocked"):
            compiler.compile_message(editable_document, plan)

    def test_rejects_plan_with_opaque_shift_blocker(self) -> None:
        editable_document, plan = self.fixture(opaque_suffix=True)
        self.assertFalse(plan["assembly_ready"])
        with self.assertRaisesRegex(compiler.MessageCompileError, "blocked"):
            compiler.compile_message(editable_document, plan)

    def test_rejects_rehashed_plan_coordinate_change(self) -> None:
        editable_document, plan = self.fixture()
        plan["relocation"]["output_code_size"] += 1
        plan["payload_sha256"] = planner.fingerprint(plan)
        with self.assertRaisesRegex(
            planner.MessageRelocationPlanError, "differs from its source"
        ):
            compiler.compile_message(editable_document, plan)

    def test_rejects_rehashed_audit_output_change(self) -> None:
        editable_document, plan = self.fixture()
        output, audit = compiler.compile_message(editable_document, plan)
        audit["output"]["entry_sha256"] = "0" * 64
        audit["payload_sha256"] = compiler.fingerprint(audit)
        with self.assertRaisesRegex(compiler.MessageCompileError, "differs"):
            compiler.validate_audit(audit, editable_document, plan, output)

    def test_rejects_unknown_audit_field(self) -> None:
        editable_document, plan = self.fixture()
        output, audit = compiler.compile_message(editable_document, plan)
        audit["ignored"] = True
        audit["payload_sha256"] = compiler.fingerprint(audit)
        with self.assertRaisesRegex(compiler.MessageCompileError, "fields"):
            compiler.validate_audit(audit, editable_document, plan, output)

    def test_new_file_publication_refuses_existing_outputs(self) -> None:
        editable_document, plan = self.fixture()
        output, audit = compiler.compile_message(editable_document, plan)
        with tempfile.TemporaryDirectory() as raw_directory:
            root = Path(raw_directory)
            mes_path = root / "compiled.mes"
            audit_path = root / "compiled.audit.json"
            mes_path.write_bytes(b"existing")
            with self.assertRaisesRegex(editable_ir.EditableIrError, "already exists"):
                editable_ir.publish_new(mes_path, output)
            self.assertEqual(b"existing", mes_path.read_bytes())
            self.assertFalse(audit_path.exists())
            self.assertEqual(audit["payload_sha256"], compiler.fingerprint(audit))


if __name__ == "__main__":
    unittest.main()
