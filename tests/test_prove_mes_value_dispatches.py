from __future__ import annotations

import copy
import sys
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

import prove_mes_control_flow as flow_prover  # noqa: E402
import prove_mes_guard_chains as guard_prover  # noqa: E402
import prove_mes_if_regions as region_prover  # noqa: E402
import prove_mes_value_dispatches as dispatch_prover  # noqa: E402
from tests.test_prove_mes_control_flow import MesControlFlowProofTests  # noqa: E402


class MesValueDispatchProofTests(unittest.TestCase):
    def state_ref(self, index: int) -> dict:
        return {
            "type": "state_ref",
            "storage": "global_u8",
            "bank": 0,
            "index": {"type": "literal", "value": index},
        }

    def equality(
        self, index: int, value: int, reversed_operands: bool = False
    ) -> dict:
        state = self.state_ref(index)
        literal = {"type": "literal", "value": value}
        return {
            "type": "binary",
            "op": "equal",
            "lhs": literal if reversed_operands else state,
            "rhs": state if reversed_operands else literal,
        }

    def chain_fixture(self) -> dict:
        return {
            "id": "guard_chain_g00_00000000",
            "guards": [
                {
                    "label": "L_A",
                    "source_start": 0,
                    "source_region": "entry_0000",
                    "condition": {"ast": self.equality(350, 0)},
                    "case_label": "L_CASE_0",
                    "next_false_label": "L_B",
                },
                {
                    "label": "L_B",
                    "source_start": 20,
                    "source_region": "entry_0001",
                    "condition": {"ast": self.equality(350, 1, True)},
                    "case_label": "L_CASE_1",
                    "next_false_label": "L_DEFAULT",
                },
            ],
            "default_label": "L_DEFAULT",
            "external_entry_guard_labels": [],
        }

    def test_proves_same_state_unique_literal_dispatch(self) -> None:
        dispatch, reason = dispatch_prover._value_dispatch(self.chain_fixture())
        self.assertEqual("", reason)
        self.assertIsNotNone(dispatch)
        self.assertEqual(
            {"storage": "global_u8", "bank": 0, "index": 350},
            dispatch["discriminator"],
        )
        self.assertEqual([0, 1], [row["literal"] for row in dispatch["cases"]])
        self.assertTrue(dispatch["labels_retained"])
        self.assertEqual("unresolved", dispatch["case_body_extent"])

    def test_rejects_changed_discriminator(self) -> None:
        chain = self.chain_fixture()
        chain["guards"][1]["condition"]["ast"] = self.equality(351, 1)
        dispatch, reason = dispatch_prover._value_dispatch(chain)
        self.assertIsNone(dispatch)
        self.assertEqual("guard_discriminator_changed", reason)

    def test_rejects_duplicate_case_literal(self) -> None:
        chain = self.chain_fixture()
        chain["guards"][1]["condition"]["ast"] = self.equality(350, 0)
        dispatch, reason = dispatch_prover._value_dispatch(chain)
        self.assertIsNone(dispatch)
        self.assertEqual("guard_case_literal_repeated", reason)

    def test_rejects_compound_guard(self) -> None:
        chain = self.chain_fixture()
        chain["guards"][0]["condition"]["ast"] = {
            "type": "binary",
            "op": "logical_and",
            "lhs": self.equality(350, 0),
            "rhs": self.equality(351, 0),
        }
        dispatch, reason = dispatch_prover._value_dispatch(chain)
        self.assertIsNone(dispatch)
        self.assertEqual("guard_condition_is_not_simple_state_equality", reason)

    def test_rejects_non_numeric_state_coordinate(self) -> None:
        chain = self.chain_fixture()
        chain["guards"][0]["condition"]["ast"]["lhs"]["bank"] = "0"
        dispatch, reason = dispatch_prover._value_dispatch(chain)
        self.assertIsNone(dispatch)
        self.assertEqual("guard_condition_is_not_simple_state_equality", reason)

    def test_projection_is_deterministic_and_rejects_rehashed_mutation(self) -> None:
        linear_ir = MesControlFlowProofTests().fixture()
        transfer = flow_prover.prove(linear_ir)
        conditional = region_prover.prove(linear_ir, transfer)
        guards = guard_prover.prove(linear_ir, transfer, conditional)
        first = dispatch_prover.prove(linear_ir, transfer, conditional, guards)
        second = dispatch_prover.prove(
            copy.deepcopy(linear_ir),
            copy.deepcopy(transfer),
            copy.deepcopy(conditional),
            copy.deepcopy(guards),
        )
        self.assertEqual(first, second)
        first["coverage"]["case_count"] = 99
        first["payload_sha256"] = dispatch_prover.fingerprint(first)
        with self.assertRaisesRegex(
            dispatch_prover.ValueDispatchProofError, "projection changed"
        ):
            dispatch_prover.validate(
                first, linear_ir, transfer, conditional, guards
            )


if __name__ == "__main__":
    unittest.main()
