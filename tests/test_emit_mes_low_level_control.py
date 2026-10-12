from __future__ import annotations

import copy
import sys
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

import emit_mes_low_level_control as emitter  # noqa: E402
import prove_mes_control_flow as prover  # noqa: E402
from tests.test_prove_mes_control_flow import MesControlFlowProofTests  # noqa: E402


class MesLowLevelControlIrTests(unittest.TestCase):
    def fixture(self) -> dict:
        linear_ir = MesControlFlowProofTests().fixture()
        return prover.prove(linear_ir)

    def test_emits_stable_labels_conditional_goto_and_boundary(self) -> None:
        document = emitter.emit(self.fixture())
        graph = document["graphs"][0]

        self.assertEqual(["L_00000002", "L_00000007"], [row["id"] for row in graph["labels"]])
        conditional = next(row for row in graph["statements"] if row["kind"] == "conditional_goto")
        boundary = next(row for row in graph["statements"] if row["kind"] == "boundary")
        self.assertEqual("L_00000007", conditional["true_label"])
        self.assertEqual("L_00000007", conditional["false_label"])
        self.assertTrue(conditional["true_is_instruction_fallthrough"])
        self.assertEqual("byte_preserving_fail_closed", boundary["boundary"])
        self.assertTrue(document["coverage"]["all_graph_nodes_labeled"])
        self.assertTrue(document["coverage"]["all_proof_constructs_emitted"])

    def test_emission_is_deterministic(self) -> None:
        proof = self.fixture()
        first = emitter.emit(proof)
        second = emitter.emit(copy.deepcopy(proof))
        self.assertEqual(first, second)
        self.assertEqual(emitter.fingerprint(first), first["payload_sha256"])

    def test_unconfirmed_transfer_retains_all_target_labels(self) -> None:
        proof = self.fixture()
        source = next(
            row
            for row in proof["graphs"][0]["constructs"]
            if row["kind"] == "conditional_branch"
        )
        source["kind"] = "unresolved_transfer"
        source["reason"] = "synthetic_unconfirmed_shape"
        for key in ("condition", "true_target", "false_target", "proof"):
            source.pop(key, None)
        proof["graphs"][0]["coverage"]["proven_edge_count"] = 0
        proof["graphs"][0]["coverage"]["unresolved_construct_count"] = 1
        proof["coverage"]["proven_edge_count"] = 0
        proof["coverage"]["unresolved_construct_count"] = 1
        proof["payload_sha256"] = prover.fingerprint(proof)
        prover.validate(proof)

        document = emitter.emit(proof)
        unresolved = next(
            row
            for row in document["graphs"][0]["statements"]
            if row["kind"] == "unresolved_transfer"
        )
        self.assertEqual(2, len(unresolved["targets"]))
        self.assertEqual({"L_00000007"}, {row["target_label"] for row in unresolved["targets"]})

    def test_rejects_rehashed_output_with_changed_label_target(self) -> None:
        document = emitter.emit(self.fixture())
        conditional = next(
            row
            for row in document["graphs"][0]["statements"]
            if row["kind"] == "conditional_goto"
        )
        conditional["false_label"] = "L_GUESSED"
        document["payload_sha256"] = emitter.fingerprint(document)
        with self.assertRaisesRegex(emitter.LowLevelControlIrError, "projection changed"):
            emitter.validate(document)


if __name__ == "__main__":
    unittest.main()
