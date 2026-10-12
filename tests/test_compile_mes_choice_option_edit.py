from __future__ import annotations

import copy
import sys
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

import compile_mes_choice_option_edit as compiler  # noqa: E402
import plan_mes_choice_option_edit as planner  # noqa: E402
from tests.test_plan_mes_choice_option_edit import _plan_fixture  # noqa: E402


class ChoiceOptionCompileTests(unittest.TestCase):
    def test_compiles_only_selected_payload_and_rebuilds_group_proof(self) -> None:
        source, proof, operation = _plan_fixture()
        plan = planner.plan(source, proof, operation)

        output, audit = compiler.compile_choice_option(source, proof, plan)

        code_offset = proof["container"]["code_offset"]
        start = code_offset + plan["target"]["payload_start"]
        end = code_offset + plan["target"]["payload_end"]
        self.assertEqual(output[:start], source[:start])
        self.assertEqual(output[end:], source[end:])
        self.assertEqual(output[start:end], b"OTHER")
        self.assertEqual(audit["patch"]["byte_delta"], 0)
        self.assertEqual(audit["output"]["entry_sha256"], plan["replacement"]["output_entry_sha256"])
        self.assertNotEqual(
            audit["source"]["choice_proof_sha256"],
            audit["output"]["choice_proof_sha256"],
        )
        self.assertEqual(
            audit["retained_contract"]["source_structure_sha256"],
            audit["retained_contract"]["output_structure_sha256"],
        )
        self.assertEqual(audit["retained_contract"]["unchanged_definition_count"], 1)
        self.assertEqual(source, _plan_fixture()[0])

    def test_is_deterministic_and_source_revalidatable(self) -> None:
        source, proof, operation = _plan_fixture()
        plan = planner.plan(source, proof, operation)

        first_output, first_audit = compiler.compile_choice_option(source, proof, plan)
        second_output, second_audit = compiler.compile_choice_option(
            source, copy.deepcopy(proof), copy.deepcopy(plan)
        )

        self.assertEqual(first_output, second_output)
        self.assertEqual(first_audit, second_audit)
        self.assertTrue(
            compiler.validate_audit(
                first_audit, source, proof, plan, first_output
            )["ok"]
        )

    def test_rejects_stale_plan_and_changed_source(self) -> None:
        source, proof, operation = _plan_fixture()
        plan = planner.plan(source, proof, operation)
        changed_plan = copy.deepcopy(plan)
        changed_plan["replacement"]["payload_raw_hex"] = b"THERE".hex()
        with self.assertRaises((compiler.ChoiceOptionCompileError, planner.ChoiceOptionEditPlanError)):
            compiler.compile_choice_option(source, proof, changed_plan)

        changed_source = bytearray(source)
        absolute = proof["container"]["code_offset"] + plan["target"]["payload_start"]
        changed_source[absolute] ^= 1
        with self.assertRaises(Exception):
            compiler.compile_choice_option(bytes(changed_source), proof, plan)

    def test_rejects_rehashed_audit_patch_mutation(self) -> None:
        source, proof, operation = _plan_fixture()
        plan = planner.plan(source, proof, operation)
        _output, audit = compiler.compile_choice_option(source, proof, plan)
        changed = copy.deepcopy(audit)
        changed["patch"]["code_end"] += 1
        changed["payload_sha256"] = compiler.fingerprint(changed)

        with self.assertRaisesRegex(compiler.ChoiceOptionCompileError, "patch changed"):
            compiler.validate_audit(changed)

    def test_rejects_unknown_audit_field_and_changed_output(self) -> None:
        source, proof, operation = _plan_fixture()
        plan = planner.plan(source, proof, operation)
        output, audit = compiler.compile_choice_option(source, proof, plan)
        changed = copy.deepcopy(audit)
        changed["unknown"] = True
        changed["payload_sha256"] = compiler.fingerprint(changed)
        with self.assertRaisesRegex(compiler.ChoiceOptionCompileError, "schema or fields"):
            compiler.validate_audit(changed)

        changed_output = bytearray(output)
        changed_output[-1] ^= 1
        with self.assertRaisesRegex(compiler.ChoiceOptionCompileError, "differs from its source"):
            compiler.validate_audit(
                audit, source, proof, plan, bytes(changed_output)
            )


if __name__ == "__main__":
    unittest.main()
