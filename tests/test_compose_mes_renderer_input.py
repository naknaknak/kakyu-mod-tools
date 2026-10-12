from __future__ import annotations

import copy
import sys
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
sys.path.insert(0, str(ROOT / "tools"))

import annotate_mes_decompiler as annotator  # noqa: E402
import compose_mes_renderer_input as composer  # noqa: E402
import decompile_mes_handoff as decompiler  # noqa: E402
import prove_mes_control_flow as flow_prover  # noqa: E402
import prove_mes_if_regions as if_prover  # noqa: E402
from tests import test_prove_mes_control_flow as flow_tests  # noqa: E402


class MesRendererInputTests(unittest.TestCase):
    def fixture(self) -> tuple[dict, dict, dict, dict]:
        linear_ir = flow_tests.MesControlFlowProofTests().fixture()
        annotations = annotator.annotate(linear_ir)
        flow = flow_prover.prove(linear_ir)
        regions = if_prover.prove(linear_ir, flow)
        return linear_ir, annotations, flow, regions

    def test_composes_complete_program_fallback_and_semantics(self) -> None:
        inputs = self.fixture()
        document = composer.compose(*inputs)

        self.assertEqual(composer.RENDERER_INPUT_SCHEMA, document["schema"])
        self.assertEqual(3, document["coverage"]["linear_node_count"])
        self.assertEqual(3, document["coverage"]["source_mapped_node_count"])
        self.assertEqual(2, document["coverage"]["control_mapped_node_count"])
        self.assertTrue(document["coverage"]["all_linear_nodes_source_mapped"])
        self.assertTrue(
            document["coverage"]["complete_low_level_fallback_retained"]
        )
        self.assertEqual(
            inputs[3]["fallback_control"], document["fallback_control"]
        )
        self.assertEqual(inputs[0]["nodes"], document["program"]["nodes"])
        self.assertEqual(
            inputs[1]["symbols"], document["semantic_annotations"]["symbols"]
        )

    def test_source_map_reverses_to_annotation_and_control_location(self) -> None:
        document = composer.compose(*self.fixture())
        rows = {row["linear_node_id"]: row for row in document["source_map"]}

        self.assertEqual("annotation_00000000", rows["linear_00000000"]["annotation_id"])
        self.assertEqual([], rows["linear_00000000"]["control_locations"])
        branch = rows["linear_00000002"]
        self.assertEqual(2, branch["source"]["start"])
        self.assertEqual("L_00000002", branch["control_locations"][0]["label"])
        self.assertEqual(
            "conditional_goto",
            branch["control_locations"][0]["statement_kind"],
        )

    def test_composition_is_deterministic(self) -> None:
        inputs = self.fixture()
        first = composer.compose(*inputs)
        second = composer.compose(*(copy.deepcopy(value) for value in inputs))
        self.assertEqual(first, second)
        self.assertEqual(first["payload_sha256"], composer.fingerprint(first))

    def test_rejects_rehashed_output_mutation(self) -> None:
        inputs = self.fixture()
        document = composer.compose(*inputs)
        document["coverage"]["complete_low_level_fallback_retained"] = False
        document["payload_sha256"] = composer.fingerprint(document)
        with self.assertRaisesRegex(
            composer.RendererInputError, "projection changed"
        ):
            composer.validate(document, *inputs)

    def test_rejects_control_flow_bound_to_another_linear_ir(self) -> None:
        linear_ir, annotations, flow, regions = self.fixture()
        flow["input_decompiler"]["payload_sha256"] = "0" * 64
        flow["payload_sha256"] = flow_prover.fingerprint(flow)
        with self.assertRaisesRegex(
            composer.RendererInputError, "belongs to another linear IR"
        ):
            composer.compose(linear_ir, annotations, flow, regions)

    def test_rejects_semantics_from_another_source_projection(self) -> None:
        linear_ir, _annotations, flow, regions = self.fixture()
        changed = copy.deepcopy(linear_ir)
        changed["source_identity"]["entry"] = "OTHER.MES"
        changed["payload_sha256"] = decompiler.fingerprint(changed)
        annotations = annotator.annotate(changed)
        with self.assertRaisesRegex(
            annotator.SemanticAnnotationError, "projection changed"
        ):
            composer.compose(linear_ir, annotations, flow, regions)


if __name__ == "__main__":
    unittest.main()
