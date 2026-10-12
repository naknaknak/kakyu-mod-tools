from __future__ import annotations

import copy
import sys
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

import plan_mes_choice_option_edit as planner  # noqa: E402
import prove_mes_choice_group_authoring as prover  # noqa: E402
from tests.test_prove_mes_choice_group_authoring import _fixture  # noqa: E402


def _plan_fixture() -> tuple[bytes, dict, dict]:
    payload, source, _offsets = _fixture()
    proof = prover.prove_entry(payload, source, 0)
    definition = proof["groups"][0]["definitions"][0]
    operation = {
        "kind": "replace_choice_option_cp932_same_length",
        "group_selector": 0,
        "definition_id": 0,
        "source_payload_sha256": definition["message"]["payload_raw_sha256"],
        "text": "OTHER",
        "encoding": "cp932",
    }
    return payload, proof, operation


class ChoiceOptionEditPlanTests(unittest.TestCase):
    def test_plans_one_exact_same_length_choice_payload(self) -> None:
        payload, proof, operation = _plan_fixture()

        document = planner.plan(payload, proof, operation)

        self.assertEqual(document["schema"], planner.PLAN_SCHEMA)
        self.assertEqual(document["target"]["group_selector"], 0)
        self.assertEqual(document["target"]["definition_id"], 0)
        self.assertEqual(document["target"]["payload_size"], 5)
        self.assertEqual(document["replacement"]["payload_raw_hex"], b"OTHER".hex())
        self.assertEqual(document["replacement"]["byte_delta"], 0)
        self.assertTrue(document["retained_contract"]["all_coordinates_unchanged"])
        self.assertTrue(document["assembly_ready"])
        self.assertNotEqual(
            document["source_identity"]["entry_sha256"],
            document["replacement"]["output_entry_sha256"],
        )

    def test_is_deterministic(self) -> None:
        payload, proof, operation = _plan_fixture()

        first = planner.plan(payload, proof, operation)
        second = planner.plan(payload, copy.deepcopy(proof), copy.deepcopy(operation))

        self.assertEqual(first, second)

    def test_rejects_stale_and_ambiguous_targets(self) -> None:
        payload, proof, operation = _plan_fixture()
        operation["source_payload_sha256"] = "0" * 64
        with self.assertRaisesRegex(planner.ChoiceOptionEditPlanError, "hash is stale"):
            planner.plan(payload, proof, operation)

        _payload, _proof, operation = _plan_fixture()
        operation["definition_id"] = 9
        with self.assertRaisesRegex(
            planner.ChoiceOptionEditPlanError, "not one unique grouped definition"
        ):
            planner.plan(payload, proof, operation)

    def test_rejects_length_change_unchanged_and_non_cp932_text(self) -> None:
        payload, proof, operation = _plan_fixture()
        operation["text"] = "LONGER"
        with self.assertRaisesRegex(planner.ChoiceOptionEditPlanError, "exact payload length"):
            planner.plan(payload, proof, operation)

        _payload, _proof, operation = _plan_fixture()
        operation["text"] = "FIRST"
        with self.assertRaisesRegex(planner.ChoiceOptionEditPlanError, "unchanged"):
            planner.plan(payload, proof, operation)

        _payload, _proof, operation = _plan_fixture()
        operation["text"] = "😀😀😀😀😀"
        with self.assertRaisesRegex(planner.ChoiceOptionEditPlanError, "not representable"):
            planner.plan(payload, proof, operation)

    def test_rejects_unknown_operation_and_plan_fields(self) -> None:
        payload, proof, operation = _plan_fixture()
        operation["unknown"] = True
        with self.assertRaisesRegex(planner.ChoiceOptionEditPlanError, "operation fields"):
            planner.plan(payload, proof, operation)

        payload, proof, operation = _plan_fixture()
        document = planner.plan(payload, proof, operation)
        document["target"]["unknown"] = True
        document["payload_sha256"] = planner.fingerprint(document)
        with self.assertRaisesRegex(planner.ChoiceOptionEditPlanError, "target boundary"):
            planner.validate(document)

    def test_standalone_validation_rejects_rehashed_cross_link_mutation(self) -> None:
        payload, proof, operation = _plan_fixture()
        document = planner.plan(payload, proof, operation)
        document["target"]["payload_end"] += 1
        document["payload_sha256"] = planner.fingerprint(document)

        with self.assertRaisesRegex(planner.ChoiceOptionEditPlanError, "target boundary"):
            planner.validate(document)

    def test_source_validation_rejects_rehashed_source_mutation(self) -> None:
        payload, proof, operation = _plan_fixture()
        document = planner.plan(payload, proof, operation)
        changed = bytearray(payload)
        absolute = (
            proof["container"]["code_offset"]
            + proof["groups"][0]["definitions"][0]["message"]["payload_start"]
        )
        changed[absolute] ^= 1

        with self.assertRaises((planner.ChoiceOptionEditPlanError, prover.ChoiceGroupAuthoringProofError)):
            planner.validate(document, bytes(changed), proof)


if __name__ == "__main__":
    unittest.main()
