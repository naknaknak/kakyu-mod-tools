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

import compile_mes_address_entry_insert as compiler  # noqa: E402
import plan_mes_address_entry_insert as planner  # noqa: E402
from tests import test_plan_mes_address_entry_insert as plan_tests  # noqa: E402


class MesAddressEntryInsertCompilerTests(unittest.TestCase):
    def fixture(self) -> tuple[dict, dict]:
        document, operation = plan_tests.MesAddressEntryInsertPlanTests().fixture()
        return document, planner.plan(document, operation)

    def test_compiles_one_new_address_entry_without_changing_bytecode(self) -> None:
        document, plan = self.fixture()
        output, audit = compiler.compile_address_entry_insert(document, plan)

        self.assertEqual(
            bytes.fromhex("03000000000000000100000002000000000000"), output
        )
        self.assertEqual((2, 3), (
            audit["source"]["entry_count"], audit["output"]["entry_count"]
        ))
        self.assertEqual((12, 16), (
            audit["source"]["code_offset"], audit["output"]["code_offset"]
        ))
        self.assertEqual(
            audit["source"]["bytecode_sha256"],
            audit["output"]["bytecode_sha256"],
        )
        self.assertEqual(1, audit["table_change"]["insertion_index"])

    def test_compile_is_deterministic_and_audit_survives_json(self) -> None:
        document, plan = self.fixture()
        first_output, first_audit = compiler.compile_address_entry_insert(
            document, plan
        )
        second_output, second_audit = compiler.compile_address_entry_insert(
            copy.deepcopy(document), copy.deepcopy(plan)
        )
        transported = json.loads(json.dumps(first_audit, ensure_ascii=False))

        self.assertEqual(first_output, second_output)
        self.assertEqual(first_audit, second_audit)
        self.assertEqual(first_audit, transported)
        compiler.validate_audit(transported, document, plan, first_output)

    def test_rejects_changed_output_and_changed_plan(self) -> None:
        document, plan = self.fixture()
        output, audit = compiler.compile_address_entry_insert(document, plan)
        changed_output = bytearray(output)
        changed_output[-1] = 1
        with self.assertRaisesRegex(
            compiler.AddressEntryInsertCompileError, "output changed"
        ):
            compiler.validate_audit(audit, document, plan, bytes(changed_output))
        changed_plan = copy.deepcopy(plan)
        changed_plan["table_change"]["inserted_raw_hex"] = "02000000"
        changed_plan["payload_sha256"] = planner.fingerprint(changed_plan)
        with self.assertRaises(planner.AddressEntryInsertPlanError):
            compiler.compile_address_entry_insert(document, changed_plan)

    def test_rejects_unknown_fields_and_stale_fingerprint(self) -> None:
        document, plan = self.fixture()
        output, audit = compiler.compile_address_entry_insert(document, plan)
        unknown = copy.deepcopy(audit)
        unknown["ignored"] = True
        unknown["payload_sha256"] = compiler.fingerprint(unknown)
        with self.assertRaisesRegex(
            compiler.AddressEntryInsertCompileError, "fields"
        ):
            compiler.validate_audit(unknown)
        stale = copy.deepcopy(audit)
        stale["payload_sha256"] = "0" * 64
        with self.assertRaisesRegex(
            compiler.AddressEntryInsertCompileError, "fingerprint"
        ):
            compiler.validate_audit(stale)
        compiler.validate_audit(audit, document, plan, output)

    def test_cli_publishes_new_mes_then_audit_and_refuses_existing_paths(self) -> None:
        document, plan = self.fixture()
        with tempfile.TemporaryDirectory() as raw_directory:
            root = Path(raw_directory)
            editable_path = root / "editable.json"
            plan_path = root / "plan.json"
            output_path = root / "output.mes"
            audit_path = root / "audit.json"
            editable_path.write_text(json.dumps(document), encoding="utf-8")
            plan_path.write_text(json.dumps(plan), encoding="utf-8")
            command = [
                sys.executable,
                str(ROOT / "tools" / "compile_mes_address_entry_insert.py"),
                str(editable_path),
                str(plan_path),
                str(output_path),
                str(audit_path),
            ]
            completed = subprocess.run(command, check=False, capture_output=True, text=True)
            self.assertEqual(0, completed.returncode, completed.stderr)
            self.assertIn("MES_ADDRESS_ENTRY_INSERT_COMPILE_PASS", completed.stdout)
            self.assertTrue(output_path.is_file())
            self.assertTrue(audit_path.is_file())
            refused = subprocess.run(command, check=False, capture_output=True, text=True)
            self.assertNotEqual(0, refused.returncode)
            compiler.validate_audit(
                json.loads(audit_path.read_text("utf-8")),
                document,
                plan,
                output_path.read_bytes(),
            )


if __name__ == "__main__":
    unittest.main()
