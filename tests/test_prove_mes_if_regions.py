from __future__ import annotations

import copy
import sys
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

import prove_mes_control_flow as flow_prover  # noqa: E402
import prove_mes_if_regions as if_prover  # noqa: E402
from tests.test_prove_mes_control_flow import MesControlFlowProofTests  # noqa: E402


class MesReducibleIfRegionTests(unittest.TestCase):
    def candidate_fixture(self) -> tuple[dict, dict, dict, dict, dict]:
        source = {
            "label": "L_00000000",
            "kind": "conditional_goto",
            "condition": {"ast": {"type": "literal", "value": 1}},
            "true_label": "L_00000007",
            "false_label": "L_0000000C",
            "source_node": {"source": {"start": 0, "end": 7}},
        }
        labels = {
            "L_00000000": {"id": "L_00000000", "offset": 0, "region": "entry_0000"},
            "L_00000007": {"id": "L_00000007", "offset": 7, "region": "entry_0000"},
            "L_0000000C": {"id": "L_0000000C", "offset": 12, "region": "entry_0000"},
        }
        statements = {
            "L_00000000": source,
            "L_00000007": {"id": "body", "label": "L_00000007", "kind": "anchor"},
            "L_0000000C": {"id": "join", "label": "L_0000000C", "kind": "boundary"},
        }
        outgoing = {
            "L_00000000": ["L_00000007", "L_0000000C"],
            "L_00000007": ["L_0000000C"],
            "L_0000000C": [],
        }
        linear_ir = {
            "nodes": [
                {
                    "id": "linear_00000007",
                    "kind": "statement",
                    "source": {"region": "entry_0000", "start": 7, "end": 12},
                    "statement": {"kind": "instruction", "op": "source_line_marker"},
                }
            ],
            "references": [],
        }
        return linear_ir, source, labels, statements, outgoing

    def if_else_fixture(self) -> tuple[dict, dict, dict, dict, dict]:
        source = {
            "label": "L_00000000",
            "kind": "conditional_goto",
            "condition": {"ast": {"type": "literal", "value": 1}},
            "true_label": "L_00000007",
            "false_label": "L_0000000F",
            "source_node": {"source": {"start": 0, "end": 7}},
        }
        labels = {
            "L_00000000": {"id": "L_00000000", "offset": 0, "region": "entry_0000"},
            "L_00000007": {"id": "L_00000007", "offset": 7, "region": "entry_0000"},
            "L_0000000A": {"id": "L_0000000A", "offset": 10, "region": "entry_0000"},
            "L_0000000F": {"id": "L_0000000F", "offset": 15, "region": "entry_0000"},
            "L_00000014": {"id": "L_00000014", "offset": 20, "region": "entry_0000"},
        }
        statements = {
            "L_00000000": source,
            "L_00000007": {"id": "then_body", "label": "L_00000007", "kind": "anchor"},
            "L_0000000A": {"id": "then_exit", "label": "L_0000000A", "kind": "goto"},
            "L_0000000F": {"id": "else_body", "label": "L_0000000F", "kind": "anchor"},
            "L_00000014": {"id": "join", "label": "L_00000014", "kind": "anchor"},
        }
        outgoing = {
            "L_00000000": ["L_00000007", "L_0000000F"],
            "L_00000007": ["L_0000000A"],
            "L_0000000A": ["L_00000014"],
            "L_0000000F": ["L_00000014"],
            "L_00000014": [],
        }
        linear_ir = {
            "nodes": [
                {
                    "id": "linear_00000007",
                    "kind": "statement",
                    "source": {"region": "entry_0000", "start": 7, "end": 10},
                    "statement": {"kind": "instruction", "op": "source_line_marker"},
                },
                {
                    "id": "linear_0000000a",
                    "kind": "statement",
                    "source": {"region": "entry_0000", "start": 10, "end": 15},
                    "statement": {"kind": "instruction", "op": "continuation_transfer"},
                },
                {
                    "id": "linear_0000000f",
                    "kind": "statement",
                    "source": {"region": "entry_0000", "start": 15, "end": 20},
                    "statement": {"kind": "instruction", "op": "source_line_marker"},
                },
            ],
            "references": [],
        }
        return linear_ir, source, labels, statements, outgoing

    def test_proves_single_entry_acyclic_single_join_if(self) -> None:
        linear_ir, source, labels, statements, outgoing = self.candidate_fixture()
        candidate, reason = if_prover._if_candidate(
            linear_ir, source, labels, statements, outgoing
        )
        self.assertEqual("", reason)
        self.assertIsNotNone(candidate)
        self.assertEqual("single_entry_acyclic_single_join", candidate["proof_status"])
        self.assertEqual(["linear_00000007"], candidate["body_linear_node_ids"])

    def test_rejects_external_confirmed_entry(self) -> None:
        linear_ir, source, labels, statements, outgoing = self.candidate_fixture()
        linear_ir["references"] = [
            {
                "kind": "code",
                "value": {
                    "kind": "continuation_target",
                    "source_offset": 99,
                    "target_offset": 7,
                },
            }
        ]
        candidate, reason = if_prover._if_candidate(
            linear_ir, source, labels, statements, outgoing
        )
        self.assertIsNone(candidate)
        self.assertEqual("body_has_external_confirmed_entry", reason)

    def test_rejects_gap_in_linear_body_span(self) -> None:
        linear_ir, source, labels, statements, outgoing = self.candidate_fixture()
        linear_ir["nodes"][0]["source"]["start"] = 8
        candidate, reason = if_prover._if_candidate(
            linear_ir, source, labels, statements, outgoing
        )
        self.assertIsNone(candidate)
        self.assertEqual("linear_body_span_is_incomplete", reason)

    def test_proves_two_single_entry_arms_with_one_join(self) -> None:
        linear_ir, source, labels, statements, outgoing = self.if_else_fixture()
        candidate, reason = if_prover._if_else_candidate(
            linear_ir, source, labels, statements, outgoing
        )
        self.assertEqual("", reason)
        self.assertIsNotNone(candidate)
        self.assertEqual("two_single_entry_acyclic_arms_single_join", candidate["proof_status"])
        self.assertEqual(["L_0000000A"], candidate["then_exit_label_ids"])
        self.assertEqual(["L_0000000F"], candidate["else_exit_label_ids"])
        self.assertEqual(20, candidate["join_offset"])

    def test_rejects_if_else_arm_with_external_entry(self) -> None:
        linear_ir, source, labels, statements, outgoing = self.if_else_fixture()
        linear_ir["references"] = [
            {
                "kind": "code",
                "value": {
                    "kind": "continuation_target",
                    "source_offset": 99,
                    "target_offset": 15,
                },
            }
        ]
        candidate, reason = if_prover._if_else_candidate(
            linear_ir, source, labels, statements, outgoing
        )
        self.assertIsNone(candidate)
        self.assertEqual("else_arm_has_external_confirmed_entry", reason)

    def test_pipeline_keeps_unproved_empty_if_as_fallback(self) -> None:
        linear_ir = MesControlFlowProofTests().fixture()
        proof = flow_prover.prove(linear_ir)
        document = if_prover.prove(linear_ir, proof)
        self.assertEqual(0, document["coverage"]["if_then_region_count"])
        self.assertEqual(1, document["coverage"]["rejected_conditional_count"])
        self.assertEqual(
            "non_forward_or_empty_body",
            document["graphs"][0]["rejected_conditionals"][0]["reason"],
        )

    def test_projection_is_deterministic_and_rejects_rehashed_mutation(self) -> None:
        linear_ir = MesControlFlowProofTests().fixture()
        proof = flow_prover.prove(linear_ir)
        first = if_prover.prove(linear_ir, proof)
        second = if_prover.prove(copy.deepcopy(linear_ir), copy.deepcopy(proof))
        self.assertEqual(first, second)
        first["graphs"][0]["rejected_conditionals"][0]["reason"] = "guessed_if"
        first["payload_sha256"] = if_prover.fingerprint(first)
        with self.assertRaisesRegex(if_prover.ReducibleRegionProofError, "projection changed"):
            if_prover.validate(first, linear_ir, proof)


if __name__ == "__main__":
    unittest.main()
