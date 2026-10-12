from __future__ import annotations

import copy
import sys
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

import decompile_mes_handoff as decompiler  # noqa: E402
import prove_mes_control_flow as prover  # noqa: E402
from tests.test_decompile_mes_handoff import MesDecompilerLinearIrTests  # noqa: E402


class MesControlFlowProofTests(unittest.TestCase):
    def fixture(self) -> dict:
        handoff, _raw = MesDecompilerLinearIrTests().fixture()
        instruction = handoff["typed_ir"]["instructions"][1]
        instruction["op"] = "branch_if_not_true"
        instruction["command_id"] = 11
        instruction["operands"] = [
            {
                "type": "condition",
                "value": {
                    "ast": {"type": "literal", "value": 1, "width": 8},
                    "raw_hex": "01ff",
                },
            },
            {"type": "code_offset", "value": 7},
        ]
        graph = handoff["cfg"][0]
        graph.update(
            {
                "range_start": 2,
                "range_end": 11,
                "node_count": 2,
                "edge_count": 2,
                "reference_count": 2,
                "stop_count": 0,
                "expansion_depth": 0,
                "expanded_regions": [],
                "expanded_region_count": 0,
                "max_expanded_regions": 0,
                "skipped_expansion_regions": [],
                "truncated": False,
                "skipped_references": 0,
                "skipped_stops": 0,
                "edges": [
                    {
                        "from_id": "instruction_00000002",
                        "to_id": "opaque_00000007",
                        "kind": "condition_true_fallthrough",
                        "confirmed_flow": True,
                        "source_depth": 0,
                    },
                    {
                        "from_id": "instruction_00000002",
                        "to_id": "opaque_00000007",
                        "kind": "condition_false_target",
                        "confirmed_flow": True,
                        "source_depth": 0,
                    },
                ],
            }
        )
        handoff["payload_sha256"] = decompiler.analyzer_handoff.fingerprint(handoff)
        return decompiler.lift(handoff)

    def test_proves_exact_conditional_and_retains_opaque_boundary(self) -> None:
        document = prover.prove(self.fixture())
        constructs = document["graphs"][0]["constructs"]
        conditional = next(row for row in constructs if row["kind"] == "conditional_branch")
        boundary = next(row for row in constructs if row["kind"] == "boundary_anchor")

        self.assertEqual("literal", conditional["condition"]["ast"]["type"])
        self.assertEqual(7, conditional["true_target"]["offset"])
        self.assertEqual(7, conditional["false_target"]["offset"])
        self.assertEqual("confirmed_flow_bounded", conditional["proof"]["status"])
        self.assertEqual("byte_preserving_fail_closed", boundary["boundary"])
        self.assertEqual(2, document["coverage"]["proven_edge_count"])
        self.assertTrue(document["coverage"]["all_graph_edges_accounted"])

    def test_deterministic_proof_fingerprint(self) -> None:
        linear_ir = self.fixture()
        first = prover.prove(linear_ir)
        second = prover.prove(copy.deepcopy(linear_ir))
        self.assertEqual(first, second)
        self.assertEqual(prover.fingerprint(first), first["payload_sha256"])

    def test_proves_exact_continuation_target(self) -> None:
        linear_ir = self.fixture()
        source = linear_ir["nodes"][1]
        source["statement"]["op"] = "continuation_transfer"
        source["statement"]["command_id"] = 12
        source["statement"]["operands"] = [{"type": "code_offset", "value": 7}]
        graph = linear_ir["analysis_evidence"]["control_flow"][0]
        graph["edges"] = [
            {
                "from_id": "instruction_00000002",
                "to_id": "opaque_00000007",
                "kind": "continuation_target",
                "confirmed_flow": True,
                "source_depth": 0,
            }
        ]
        graph["edge_count"] = 1
        graph["reference_count"] = 1
        linear_ir["payload_sha256"] = decompiler.fingerprint(linear_ir)

        document = prover.prove(linear_ir)
        transfer = next(
            row
            for row in document["graphs"][0]["constructs"]
            if row["kind"] == "continuation_transfer"
        )
        self.assertEqual(7, transfer["target"]["offset"])
        self.assertEqual("confirmed_flow_bounded", transfer["proof"]["status"])
        self.assertEqual(1, document["coverage"]["proven_edge_count"])

    def test_changed_false_target_falls_back_without_guessing(self) -> None:
        linear_ir = self.fixture()
        linear_ir["nodes"][1]["statement"]["operands"][1]["value"] = 8
        linear_ir["payload_sha256"] = decompiler.fingerprint(linear_ir)
        document = prover.prove(linear_ir)
        unresolved = [
            row
            for row in document["graphs"][0]["constructs"]
            if row["kind"] == "unresolved_transfer"
        ]
        self.assertEqual(1, len(unresolved))
        self.assertEqual(
            "conditional_shape_or_target_not_proven", unresolved[0]["reason"]
        )
        self.assertEqual(0, document["coverage"]["proven_edge_count"])

    def test_unconfirmed_edge_is_explicit_unresolved_transfer(self) -> None:
        linear_ir = self.fixture()
        graph = linear_ir["analysis_evidence"]["control_flow"][0]
        graph["edges"][0]["confirmed_flow"] = False
        linear_ir["payload_sha256"] = decompiler.fingerprint(linear_ir)
        document = prover.prove(linear_ir)
        unresolved = [
            row
            for row in document["graphs"][0]["constructs"]
            if row["kind"] == "unresolved_transfer"
        ]
        self.assertEqual(1, len(unresolved))
        self.assertEqual(0, document["coverage"]["proven_edge_count"])
        self.assertEqual(1, document["coverage"]["unresolved_construct_count"])
        self.assertTrue(document["coverage"]["all_graph_edges_accounted"])

    def test_rejects_rehashed_proof_with_mutated_condition(self) -> None:
        document = prover.prove(self.fixture())
        conditional = next(
            row
            for row in document["graphs"][0]["constructs"]
            if row["kind"] == "conditional_branch"
        )
        conditional["condition"]["ast"]["value"] = 0
        document["payload_sha256"] = prover.fingerprint(document)
        with self.assertRaisesRegex(prover.ControlFlowProofError, "conditional proof payload"):
            prover.validate(document)

    def test_bounded_graph_leaf_transfer_is_unexpanded_anchor(self) -> None:
        linear_ir = self.fixture()
        graph = linear_ir["analysis_evidence"]["control_flow"][0]
        graph["edges"] = []
        graph["edge_count"] = 0
        linear_ir["payload_sha256"] = decompiler.fingerprint(linear_ir)
        document = prover.prove(linear_ir)
        anchors = [
            row
            for row in document["graphs"][0]["constructs"]
            if row["kind"] == "unexpanded_transfer_anchor"
        ]
        self.assertEqual(1, len(anchors))
        self.assertEqual([], anchors[0]["edge_indices"])
        self.assertEqual(
            "outgoing_edges_not_supplied_by_bounded_graph", anchors[0]["reason"]
        )

    def test_rejects_rehashed_proof_with_missing_graph_anchor(self) -> None:
        document = prover.prove(self.fixture())
        document["graphs"][0]["constructs"] = [
            row
            for row in document["graphs"][0]["constructs"]
            if row["kind"] != "boundary_anchor"
        ]
        document["graphs"][0]["coverage"]["boundary_anchor_count"] = 0
        document["coverage"]["boundary_anchor_count"] = 0
        document["payload_sha256"] = prover.fingerprint(document)
        with self.assertRaisesRegex(prover.ControlFlowProofError, "construct coverage"):
            prover.validate(document)


if __name__ == "__main__":
    unittest.main()
