from __future__ import annotations

import copy
import sys
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
sys.path.insert(0, str(ROOT / "tools"))

import annotate_mes_decompiler as annotator  # noqa: E402
import compose_mes_renderer_overlays as composer  # noqa: E402
import prove_mes_call_families as call_prover  # noqa: E402
import prove_mes_control_flow as flow_prover  # noqa: E402
import prove_mes_cross_region_joins as join_prover  # noqa: E402
import prove_mes_guard_chains as guard_prover  # noqa: E402
import prove_mes_if_regions as region_prover  # noqa: E402
import prove_mes_predicate_dispatches as predicate_prover  # noqa: E402
import prove_mes_value_dispatches as value_prover  # noqa: E402
from tests import test_prove_mes_control_flow as flow_tests  # noqa: E402


class MesRendererOverlayTests(unittest.TestCase):
    def fixture(self) -> tuple[dict, ...]:
        linear_ir = flow_tests.MesControlFlowProofTests().fixture()
        annotations = annotator.annotate(linear_ir)
        flow = flow_prover.prove(linear_ir)
        regions = region_prover.prove(linear_ir, flow)
        guards = guard_prover.prove(linear_ir, flow, regions)
        values = value_prover.prove(linear_ir, flow, regions, guards)
        predicates = predicate_prover.prove(
            linear_ir, flow, regions, guards, values
        )
        joins = join_prover.prove(linear_ir, flow, regions)
        calls = call_prover.prove(linear_ir)
        return (
            linear_ir,
            annotations,
            flow,
            regions,
            guards,
            values,
            predicates,
            joins,
            calls,
        )

    def test_composes_validated_proof_family_and_retains_rejections(self) -> None:
        inputs = self.fixture()
        document = composer.compose(*inputs)

        self.assertEqual(composer.RENDERER_INPUT_SCHEMA, document["schema"])
        self.assertEqual(0, document["coverage"]["overlay_count"])
        self.assertTrue(document["coverage"]["all_proof_rejections_retained"])
        self.assertEqual(
            inputs[4], document["proof_layers"]["guard_chains"]
        )
        self.assertEqual(
            inputs[8], document["proof_layers"]["call_families"]
        )
        self.assertTrue(
            all("overlay_ids" in row for row in document["source_map"])
        )

    def test_overlay_record_reverses_labels_and_direct_node_ids(self) -> None:
        record = composer._overlay_record(
            "guard_chain",
            2,
            {
                "id": "guard_test",
                "kind": "guard_chain",
                "guards": [{"label": "L_A", "case_label": "L_B"}],
                "fallback_linear_node_id": "linear_00000007",
            },
            {"L_A": "linear_00000000", "L_B": "linear_00000007"},
            {"linear_00000000", "linear_00000007"},
        )
        self.assertEqual(["L_A", "L_B"], record["source_labels"])
        self.assertEqual(
            ["linear_00000007", "linear_00000000"],
            record["member_linear_node_ids"],
        )

    def test_overlay_composition_is_deterministic(self) -> None:
        inputs = self.fixture()
        first = composer.compose(*inputs)
        second = composer.compose(*(copy.deepcopy(value) for value in inputs))
        self.assertEqual(first, second)
        self.assertEqual(first["payload_sha256"], composer.fingerprint(first))

    def test_rejects_rehashed_output_mutation(self) -> None:
        inputs = self.fixture()
        document = composer.compose(*inputs)
        document["coverage"]["all_proof_rejections_retained"] = False
        document["payload_sha256"] = composer.fingerprint(document)
        with self.assertRaisesRegex(
            composer.RendererOverlayError, "projection changed"
        ):
            composer.validate(document, *inputs)

    def test_rejects_proof_from_another_linear_family(self) -> None:
        inputs = list(self.fixture())
        inputs[8]["input"]["linear_ir_sha256"] = "0" * 64
        inputs[8]["payload_sha256"] = call_prover.fingerprint(inputs[8])
        with self.assertRaisesRegex(
            call_prover.CallFamilyProofError, "projection changed"
        ):
            composer.compose(*inputs)

    def test_rejects_overlay_without_reversible_source(self) -> None:
        with self.assertRaisesRegex(
            composer.RendererOverlayError,
            "no reversible source node: layer=value_dispatch proof_id=orphan",
        ):
            composer._overlay_record(
                "value_dispatch",
                0,
                {"id": "orphan", "kind": "value_dispatch"},
                {},
                {"linear_00000000"},
            )


if __name__ == "__main__":
    unittest.main()
