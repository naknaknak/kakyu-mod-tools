from __future__ import annotations

import copy
import sys
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

import prove_mes_cross_region_joins as join_prover  # noqa: E402
import prove_mes_control_flow as flow_prover  # noqa: E402
import prove_mes_if_regions as if_prover  # noqa: E402
from tests import test_prove_mes_control_flow as flow_tests  # noqa: E402


class MesCrossRegionJoinProofTests(unittest.TestCase):
    def fixture(self) -> tuple[dict, dict, dict, dict, dict]:
        source = {
            "id": "source",
            "label": "L_00000000",
            "kind": "conditional_goto",
            "condition": {"ast": {"type": "literal", "value": 1}},
            "true_label": "L_00000007",
            "false_label": "L_0000000C",
        }
        labels = {
            "L_00000000": {
                "id": "L_00000000",
                "offset": 0,
                "region": "entry_0000",
            },
            "L_00000007": {
                "id": "L_00000007",
                "offset": 7,
                "region": "entry_0000",
            },
            "L_0000000C": {
                "id": "L_0000000C",
                "offset": 12,
                "region": "entry_0001",
            },
            "L_00000011": {
                "id": "L_00000011",
                "offset": 17,
                "region": "entry_0002",
            },
        }
        statements = {
            "L_00000000": source,
            "L_00000007": {
                "id": "true_body",
                "label": "L_00000007",
                "kind": "goto",
            },
            "L_0000000C": {
                "id": "false_body",
                "label": "L_0000000C",
                "kind": "goto",
            },
            "L_00000011": {
                "id": "join",
                "label": "L_00000011",
                "kind": "anchor",
            },
        }
        outgoing = {
            "L_00000000": ["L_00000007", "L_0000000C"],
            "L_00000007": ["L_00000011"],
            "L_0000000C": ["L_00000011"],
            "L_00000011": [],
        }
        linear_ir = {"references": []}
        return linear_ir, source, labels, statements, outgoing

    def test_proves_unique_total_cross_region_join(self) -> None:
        linear_ir, source, labels, statements, outgoing = self.fixture()
        candidate, reason = join_prover._cross_region_join_candidate(
            linear_ir, source, labels, statements, outgoing, True
        )
        self.assertEqual("", reason)
        self.assertIsNotNone(candidate)
        self.assertEqual("L_00000011", candidate["join_label"])
        self.assertEqual(
            ["entry_0000", "entry_0001"], candidate["path_region_ids"]
        )
        self.assertEqual(
            "unresolved_low_level_fallback_retained", candidate["surface_syntax"]
        )

    def test_rejects_external_arm_entry_or_nonconverging_path(self) -> None:
        linear_ir, source, labels, statements, outgoing = self.fixture()
        labels["L_00000020"] = {
            "id": "L_00000020",
            "offset": 32,
            "region": "entry_0003",
        }
        statements["L_00000020"] = {
            "id": "external",
            "label": "L_00000020",
            "kind": "goto",
        }
        outgoing["L_00000020"] = ["L_00000007"]
        candidate, reason = join_prover._cross_region_join_candidate(
            linear_ir, source, labels, statements, outgoing, True
        )
        self.assertIsNone(candidate)
        self.assertEqual("cross_region_arm_has_external_graph_entry", reason)

        outgoing["L_00000020"] = []
        outgoing["L_0000000C"] = []
        candidate, reason = join_prover._cross_region_join_candidate(
            linear_ir, source, labels, statements, outgoing, True
        )
        self.assertIsNone(candidate)
        self.assertEqual("branches_have_no_common_total_join", reason)

    def test_helpers_reject_cycle_and_projection_fingerprint_is_stable(self) -> None:
        _linear_ir, _source, _labels, _statements, outgoing = self.fixture()
        outgoing["L_00000007"] = ["L_00000007", "L_00000011"]
        self.assertFalse(
            join_prover._all_paths_reach(
                "L_00000007", "L_00000011", outgoing
            )
        )
        document = {
            "ok": True,
            "schema": join_prover.CROSS_REGION_JOIN_PROOF_SCHEMA,
            "graphs": [],
        }
        first = join_prover.fingerprint(document)
        second = join_prover.fingerprint(copy.deepcopy(document))
        self.assertEqual(first, second)

    def test_pipeline_is_deterministic_and_rejects_rehashed_mutation(self) -> None:
        linear_ir = flow_tests.MesControlFlowProofTests().fixture()
        transfers = flow_prover.prove(linear_ir)
        regions = if_prover.prove(linear_ir, transfers)
        first = join_prover.prove(linear_ir, transfers, regions)
        second = join_prover.prove(
            copy.deepcopy(linear_ir),
            copy.deepcopy(transfers),
            copy.deepcopy(regions),
        )
        self.assertEqual(first, second)
        self.assertEqual(0, first["coverage"]["cross_region_candidate_count"])
        first["compatibility"]["surface_syntax_policy"] = "guessed_if"
        first["payload_sha256"] = join_prover.fingerprint(first)
        with self.assertRaisesRegex(
            join_prover.CrossRegionJoinProofError, "projection changed"
        ):
            join_prover.validate(first, linear_ir, transfers, regions)


if __name__ == "__main__":
    unittest.main()
