from __future__ import annotations

import copy
import sys
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
sys.path.insert(0, str(ROOT / "tools"))

import compose_mes_renderer_loops as composer  # noqa: E402
import prove_mes_execution_fallthroughs as execution_prover  # noqa: E402
import prove_mes_natural_loops as loop_prover  # noqa: E402
import prove_mes_shared_call_returns as shared_call_prover  # noqa: E402
from tests import test_compose_mes_renderer_overlays as overlay_tests  # noqa: E402


class MesRendererLoopTests(unittest.TestCase):
    def fixture(self) -> tuple[dict, ...]:
        base = overlay_tests.MesRendererOverlayTests().fixture()
        linear_ir, _annotations, flow, regions = base[:4]
        library = {
            "ok": True,
            "schema": shared_call_prover.LIBRARY_AUDIT_SCHEMA,
            "archive_name": "mes.arc",
            "archive_sha256": "1" * 64,
            "entry": "LIBLARY.LIB",
            "entry_sha256": "2" * 64,
            "source_archive_unchanged": True,
            "routines": [],
        }
        shared = shared_call_prover.prove(linear_ir, library)
        execution = execution_prover.prove(linear_ir, flow, shared, library)
        loops = loop_prover.prove(
            linear_ir, flow, regions, execution, shared, library
        )
        return (*base, library, shared, execution, loops)

    def test_composes_loop_family_and_retains_supporting_proofs(self) -> None:
        inputs = self.fixture()
        document = composer.compose(*inputs)

        self.assertEqual(composer.RENDERER_INPUT_SCHEMA, document["schema"])
        self.assertEqual(0, document["coverage"]["natural_loop_overlay_count"])
        self.assertTrue(document["coverage"]["all_loop_rejections_retained"])
        self.assertEqual(
            inputs[9], document["proof_layers"]["library_audit"]
        )
        self.assertEqual(
            inputs[12], document["proof_layers"]["natural_loops"]
        )

    def test_loop_overlay_reverses_complete_envelope(self) -> None:
        fallback = {
            "graphs": [
                {
                    "graph_index": 0,
                    "statements": [
                        {
                            "label": "L_HEADER",
                            "source_node": {"id": "linear_00000000"},
                        },
                        {
                            "label": "L_LATCH",
                            "source_node": {"id": "linear_00000007"},
                        },
                    ],
                }
            ]
        }
        proof = {
            "graphs": [
                {
                    "graph_index": 0,
                    "natural_loops": [
                        {
                            "id": "natural_loop_00000000",
                            "kind": "natural_loop",
                            "header_label": "L_HEADER",
                            "latch_labels": ["L_LATCH"],
                            "envelope_linear_node_ids": [
                                "linear_00000000",
                                "linear_00000007",
                            ],
                            "envelope_start": 0,
                        }
                    ],
                }
            ]
        }
        overlays = composer._loop_overlays(
            fallback,
            proof,
            [
                {"id": "linear_00000000"},
                {"id": "linear_00000007"},
            ],
        )
        self.assertEqual(1, len(overlays))
        self.assertEqual("natural_loop", overlays[0]["layer"])
        self.assertEqual(
            ["linear_00000000", "linear_00000007"],
            overlays[0]["member_linear_node_ids"],
        )

    def test_loop_composition_is_deterministic(self) -> None:
        inputs = self.fixture()
        first = composer.compose(*inputs)
        second = composer.compose(*(copy.deepcopy(value) for value in inputs))
        self.assertEqual(first, second)
        self.assertEqual(first["payload_sha256"], composer.fingerprint(first))

    def test_rejects_rehashed_output_mutation(self) -> None:
        inputs = self.fixture()
        document = composer.compose(*inputs)
        document["coverage"]["all_loop_rejections_retained"] = False
        document["payload_sha256"] = composer.fingerprint(document)
        with self.assertRaisesRegex(
            composer.RendererLoopError, "projection changed"
        ):
            composer.validate(document, *inputs)

    def test_rejects_natural_loop_from_another_execution_family(self) -> None:
        inputs = list(self.fixture())
        inputs[12]["inputs"]["execution_fallthrough_sha256"] = "0" * 64
        inputs[12]["payload_sha256"] = loop_prover.fingerprint(inputs[12])
        with self.assertRaisesRegex(
            loop_prover.NaturalLoopProofError, "projection changed"
        ):
            composer.compose(*inputs)

    def test_rejects_loop_graph_without_fallback_graph(self) -> None:
        with self.assertRaisesRegex(
            composer.RendererLoopError, "has no fallback graph"
        ):
            composer._loop_overlays(
                {"graphs": []},
                {"graphs": [{"graph_index": 1, "natural_loops": []}]},
                [],
            )


if __name__ == "__main__":
    unittest.main()
