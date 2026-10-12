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
from tests.test_prove_mes_control_flow import MesControlFlowProofTests  # noqa: E402


class MesGuardChainProofTests(unittest.TestCase):
    def graph_fixture(self) -> tuple[dict, dict, dict]:
        control_graph = {
            "labels": [
                {"id": "L_A", "offset": 0, "region": "entry_0000"},
                {"id": "L_A_TRUE", "offset": 7, "region": "entry_0000"},
                {"id": "L_B", "offset": 20, "region": "entry_0001"},
                {"id": "L_B_TRUE", "offset": 27, "region": "entry_0001"},
                {"id": "L_DEFAULT", "offset": 40, "region": "entry_0002"},
            ],
            "statements": [
                {
                    "label": "L_A",
                    "kind": "conditional_goto",
                    "condition": {"ast": {"type": "literal", "value": 1}},
                    "true_label": "L_A_TRUE",
                    "false_label": "L_B",
                    "source_node": {"source": {"start": 0, "end": 7}},
                },
                {
                    "label": "L_B",
                    "kind": "conditional_goto",
                    "condition": {"ast": {"type": "literal", "value": 2}},
                    "true_label": "L_B_TRUE",
                    "false_label": "L_DEFAULT",
                    "source_node": {"source": {"start": 20, "end": 27}},
                },
            ],
        }
        conditional_graph = {"if_then_regions": [], "if_else_regions": []}
        linear_ir = {
            "references": [
                {
                    "kind": "code",
                    "value": {
                        "kind": "condition_false_target",
                        "source_offset": 0,
                        "target_offset": 20,
                    },
                }
            ]
        }
        return linear_ir, conditional_graph, control_graph

    def test_proves_ordered_false_edge_chain_without_dispatch_semantics(self) -> None:
        linear_ir, conditional_graph, control_graph = self.graph_fixture()
        result = guard_prover._prove_graph(
            0, linear_ir, conditional_graph, control_graph
        )
        self.assertEqual(1, len(result["guard_chains"]))
        chain = result["guard_chains"][0]
        self.assertEqual(["L_A", "L_B"], [row["label"] for row in chain["guards"]])
        self.assertEqual("L_DEFAULT", chain["default_label"])
        self.assertEqual("unresolved", chain["semantic_dispatch"])
        self.assertFalse(chain["reducible_region"])
        self.assertEqual(1, result["cross_region_false_edge_count"])

    def test_records_external_entry_to_later_guard(self) -> None:
        linear_ir, conditional_graph, control_graph = self.graph_fixture()
        linear_ir["references"].append(
            {
                "kind": "code",
                "value": {
                    "kind": "continuation_target",
                    "source_offset": 99,
                    "target_offset": 20,
                },
            }
        )
        result = guard_prover._prove_graph(
            0, linear_ir, conditional_graph, control_graph
        )
        self.assertEqual(
            ["L_B"], result["guard_chains"][0]["external_entry_guard_labels"]
        )

    def test_excludes_already_structured_condition(self) -> None:
        linear_ir, conditional_graph, control_graph = self.graph_fixture()
        conditional_graph["if_then_regions"] = [{"source_label": "L_A"}]
        result = guard_prover._prove_graph(
            0, linear_ir, conditional_graph, control_graph
        )
        self.assertEqual([], result["guard_chains"])
        self.assertEqual(1, result["unchained_conditional_count"])

    def test_rejects_cyclic_false_edge_component(self) -> None:
        linear_ir, conditional_graph, control_graph = self.graph_fixture()
        control_graph["statements"][1]["false_label"] = "L_A"
        result = guard_prover._prove_graph(
            0, linear_ir, conditional_graph, control_graph
        )
        self.assertEqual([], result["guard_chains"])
        self.assertEqual(
            "cyclic_or_merged_false_guard_component",
            result["rejected_components"][0]["kind"],
        )

    def test_rejects_merged_false_guard_component(self) -> None:
        linear_ir, conditional_graph, control_graph = self.graph_fixture()
        control_graph["labels"].extend(
            [
                {"id": "L_C", "offset": 50, "region": "entry_0003"},
                {"id": "L_C_TRUE", "offset": 57, "region": "entry_0003"},
            ]
        )
        control_graph["statements"].append(
            {
                "label": "L_C",
                "kind": "conditional_goto",
                "condition": {"ast": {"type": "literal", "value": 3}},
                "true_label": "L_C_TRUE",
                "false_label": "L_B",
                "source_node": {"source": {"start": 50, "end": 57}},
            }
        )
        result = guard_prover._prove_graph(
            0, linear_ir, conditional_graph, control_graph
        )
        merged = next(
            row
            for row in result["rejected_components"]
            if row["kind"] == "merged_false_guard_component"
        )
        self.assertEqual("L_B", merged["merge_label"])
        self.assertEqual(["L_A", "L_C"], merged["predecessor_labels"])

    def test_projection_is_deterministic_and_rejects_rehashed_mutation(self) -> None:
        linear_ir = MesControlFlowProofTests().fixture()
        transfer = flow_prover.prove(linear_ir)
        conditional = region_prover.prove(linear_ir, transfer)
        first = guard_prover.prove(linear_ir, transfer, conditional)
        second = guard_prover.prove(
            copy.deepcopy(linear_ir),
            copy.deepcopy(transfer),
            copy.deepcopy(conditional),
        )
        self.assertEqual(first, second)
        first["coverage"]["unchained_conditional_count"] = 99
        first["payload_sha256"] = guard_prover.fingerprint(first)
        with self.assertRaisesRegex(
            guard_prover.GuardChainProofError, "projection changed"
        ):
            guard_prover.validate(first, linear_ir, transfer, conditional)


if __name__ == "__main__":
    unittest.main()
