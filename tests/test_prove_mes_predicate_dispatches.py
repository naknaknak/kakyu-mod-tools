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
import prove_mes_predicate_dispatches as predicate_prover  # noqa: E402
import prove_mes_value_dispatches as value_prover  # noqa: E402
from tests import test_prove_mes_control_flow as flow_tests  # noqa: E402


class MesPredicateDispatchProofTests(unittest.TestCase):
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

    def test_normalizes_conjunction_and_reversed_equality(self) -> None:
        ast = {
            "type": "binary",
            "op": "logical_and",
            "lhs": self.equality(227, 2),
            "rhs": self.equality(690, 1, True),
        }
        alternatives, reason = predicate_prover._state_equality_dnf(ast)
        self.assertEqual("", reason)
        self.assertEqual(1, len(alternatives))
        self.assertEqual([227, 690], [atom["index"] for atom in alternatives[0]])

    def test_distributes_or_inside_conjunction_without_guessing_exclusivity(self) -> None:
        ast = {
            "type": "binary",
            "op": "logical_and",
            "lhs": {
                "type": "binary",
                "op": "logical_or",
                "lhs": self.equality(226, 1),
                "rhs": self.equality(226, 3),
            },
            "rhs": self.equality(684, 0),
        }
        alternatives, reason = predicate_prover._state_equality_dnf(ast)
        self.assertEqual("", reason)
        self.assertEqual(
            [[(226, 1), (684, 0)], [(226, 3), (684, 0)]],
            [
                [(atom["index"], atom["literal"]) for atom in alternative]
                for alternative in alternatives
            ],
        )

    def test_rejects_non_equality_boolean_term_and_bounded_expansion(self) -> None:
        alternatives, reason = predicate_prover._state_equality_dnf(
            {"type": "literal", "value": 1}
        )
        self.assertIsNone(alternatives)
        self.assertEqual(
            "guard_contains_non_state_equality_boolean_term", reason
        )

        ast = self.equality(1, 0)
        for value in range(1, 7):
            ast = {
                "type": "binary",
                "op": "logical_or",
                "lhs": ast,
                "rhs": self.equality(1, value),
            }
        expanded = {
            "type": "binary",
            "op": "logical_and",
            "lhs": ast,
            "rhs": copy.deepcopy(ast),
        }
        alternatives, reason = predicate_prover._state_equality_dnf(expanded)
        self.assertIsNone(alternatives)
        self.assertEqual("guard_dnf_alternative_limit_exceeded", reason)

    def test_builds_ordered_predicate_dispatch_with_fallback_contract(self) -> None:
        chain = {
            "id": "guard_chain_g00_00000000",
            "guards": [
                {
                    "label": "L_A",
                    "source_start": 0,
                    "source_region": "entry_0000",
                    "condition": {
                        "ast": {
                            "type": "binary",
                            "op": "logical_and",
                            "lhs": self.equality(227, 2),
                            "rhs": self.equality(690, 1),
                        }
                    },
                    "case_label": "L_CASE_A",
                    "next_false_label": "L_B",
                },
                {
                    "label": "L_B",
                    "source_start": 20,
                    "source_region": "entry_0001",
                    "condition": {"ast": self.equality(227, 1)},
                    "case_label": "L_CASE_B",
                    "next_false_label": "L_DEFAULT",
                },
            ],
            "default_label": "L_DEFAULT",
            "external_entry_guard_labels": [],
        }
        dispatch, reason = predicate_prover._predicate_dispatch(chain)
        self.assertEqual("", reason)
        self.assertEqual("ordered_predicate_dispatch", dispatch["kind"])
        self.assertEqual(
            "first_true_guard_in_false_edge_order", dispatch["selection_order"]
        )
        self.assertEqual("unresolved", dispatch["mutual_exclusivity"])
        self.assertEqual(
            [227, 690], [row["index"] for row in dispatch["state_coordinates"]]
        )

    def test_pipeline_is_deterministic_and_rejects_rehashed_mutation(self) -> None:
        linear_ir = flow_tests.MesControlFlowProofTests().fixture()
        transfers = flow_prover.prove(linear_ir)
        regions = region_prover.prove(linear_ir, transfers)
        guards = guard_prover.prove(linear_ir, transfers, regions)
        values = value_prover.prove(linear_ir, transfers, regions, guards)
        first = predicate_prover.prove(
            linear_ir, transfers, regions, guards, values
        )
        second = predicate_prover.prove(
            copy.deepcopy(linear_ir),
            copy.deepcopy(transfers),
            copy.deepcopy(regions),
            copy.deepcopy(guards),
            copy.deepcopy(values),
        )
        self.assertEqual(first, second)
        self.assertEqual(0, first["coverage"]["predicate_dispatch_count"])
        first["compatibility"]["surface_syntax_policy"] = "guessed_switch"
        first["payload_sha256"] = predicate_prover.fingerprint(first)
        with self.assertRaisesRegex(
            predicate_prover.PredicateDispatchProofError, "projection changed"
        ):
            predicate_prover.validate(
                first, linear_ir, transfers, regions, guards, values
            )


if __name__ == "__main__":
    unittest.main()
