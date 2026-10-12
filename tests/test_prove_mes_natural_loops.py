from __future__ import annotations

import copy
import sys
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

import prove_mes_control_flow as flow_prover  # noqa: E402
import prove_mes_execution_fallthroughs as execution_prover  # noqa: E402
import prove_mes_if_regions as region_prover  # noqa: E402
import prove_mes_natural_loops as loop_prover  # noqa: E402
import prove_mes_shared_call_returns as call_prover  # noqa: E402
from tests import test_prove_mes_control_flow as control_flow_tests  # noqa: E402


class MesNaturalLoopProofTests(unittest.TestCase):
    def graph_fixture(self) -> tuple[dict, dict, dict]:
        labels = [
            {"id": "L_HEADER", "offset": 0, "region": "entry_0000"},
            {"id": "L_BRANCH", "offset": 7, "region": "entry_0000"},
            {"id": "L_LATCH_A", "offset": 14, "region": "entry_0000"},
            {"id": "L_SECOND_PATH", "offset": 19, "region": "entry_0000"},
            {"id": "L_LATCH_B", "offset": 24, "region": "entry_0000"},
            {"id": "L_EXIT", "offset": 29, "region": "entry_0000"},
        ]

        def statement(
            label: str, kind: str, start: int, end: int, **values: object
        ) -> dict:
            return {
                "id": f"stmt_{start:08x}",
                "label": label,
                "kind": kind,
                "source_node": {"source": {"start": start, "end": end}},
                **values,
            }

        control_graph = {
            "labels": labels,
            "statements": [
                statement(
                    "L_HEADER",
                    "conditional_goto",
                    0,
                    7,
                    true_label="L_BRANCH",
                    false_label="L_EXIT",
                    condition={"ast": {"type": "literal", "value": 1}},
                ),
                statement(
                    "L_BRANCH",
                    "conditional_goto",
                    7,
                    14,
                    true_label="L_LATCH_A",
                    false_label="L_SECOND_PATH",
                    condition={"ast": {"type": "literal", "value": 1}},
                ),
                statement(
                    "L_LATCH_A", "goto", 14, 19, target_label="L_HEADER"
                ),
                statement("L_SECOND_PATH", "anchor", 19, 24),
                statement(
                    "L_LATCH_B", "goto", 24, 29, target_label="L_HEADER"
                ),
                statement("L_EXIT", "anchor", 29, 34),
            ],
        }
        conditional_graph = {
            "bounded_complete": True,
            "proved_fallthroughs": [
                {"source_label": "L_SECOND_PATH", "target_label": "L_LATCH_B"}
            ],
        }
        linear_ir = {
            "nodes": [
                {
                    "id": f"linear_{start:08x}",
                    "kind": "statement",
                    "source": {
                        "region": "entry_0000",
                        "start": start,
                        "end": end,
                    },
                    "statement": {"op": op},
                }
                for start, end, op in [
                    (0, 7, "branch_if_not_true"),
                    (7, 14, "branch_if_not_true"),
                    (14, 19, "continuation_transfer"),
                    (19, 24, "source_line_marker"),
                    (24, 29, "continuation_transfer"),
                    (29, 34, "source_line_marker"),
                ]
            ],
            "references": [
                self.reference("condition_true_fallthrough", 0, 7),
                self.reference("condition_false_target", 0, 29),
                self.reference("condition_true_fallthrough", 7, 14),
                self.reference("condition_false_target", 7, 19),
                self.reference("continuation_target", 14, 0),
                self.reference("continuation_target", 24, 0),
            ],
        }
        return linear_ir, conditional_graph, control_graph

    @staticmethod
    def reference(kind: str, source: int, target: int) -> dict:
        return {
            "kind": "code",
            "value": {
                "kind": kind,
                "source_offset": source,
                "target_offset": target,
            },
        }

    def test_proves_single_entry_multi_latch_natural_loop(self) -> None:
        linear_ir, conditional_graph, control_graph = self.graph_fixture()
        result = loop_prover._prove_graph(
            0, linear_ir, conditional_graph, {"proved_fallthroughs": []}, control_graph
        )
        self.assertEqual(2, result["back_edge_candidate_count"])
        self.assertEqual([], result["rejected_headers"])
        self.assertEqual(1, len(result["natural_loops"]))
        loop = result["natural_loops"][0]
        self.assertEqual(["L_LATCH_A", "L_LATCH_B"], loop["latch_labels"])
        self.assertEqual(2, len(loop["back_edges"]))
        self.assertEqual(0, loop["envelope_start"])
        self.assertEqual(29, loop["envelope_end"])
        self.assertEqual(
            "same_region_header_dominates_all_latches_single_entry",
            loop["proof_status"],
        )
        self.assertEqual("L_EXIT", loop["exit_edges"][0]["target_label"])
        self.assertEqual("unresolved_retain_label_goto_fallback", loop["surface_syntax"])

    def test_rejects_external_entry_that_breaks_header_dominance(self) -> None:
        linear_ir, conditional_graph, control_graph = self.graph_fixture()
        linear_ir["nodes"].append(
            {
                "id": "linear_00000064",
                "kind": "statement",
                "source": {"region": "entry_0001", "start": 100, "end": 105},
                "statement": {"op": "continuation_transfer"},
            }
        )
        linear_ir["references"].append(
            self.reference("continuation_target", 100, 19)
        )
        result = loop_prover._prove_graph(
            0, linear_ir, conditional_graph, {"proved_fallthroughs": []}, control_graph
        )
        self.assertEqual([], result["natural_loops"])
        self.assertEqual(
            "header_does_not_dominate_every_latch",
            result["rejected_headers"][0]["reason"],
        )

    def test_rejects_incomplete_graph_and_opaque_envelope(self) -> None:
        linear_ir, conditional_graph, control_graph = self.graph_fixture()
        conditional_graph["bounded_complete"] = False
        incomplete = loop_prover._prove_graph(
            0, linear_ir, conditional_graph, {"proved_fallthroughs": []}, control_graph
        )
        self.assertEqual(
            "control_graph_is_not_bounded_complete",
            incomplete["rejected_headers"][0]["reason"],
        )

        linear_ir, conditional_graph, control_graph = self.graph_fixture()
        linear_ir["nodes"][3]["kind"] = "opaque"
        opaque = loop_prover._prove_graph(
            0, linear_ir, conditional_graph, {"proved_fallthroughs": []}, control_graph
        )
        self.assertEqual(
            "linear_loop_envelope_contains_opaque_boundary",
            opaque["rejected_headers"][0]["reason"],
        )

    def test_execution_fallthrough_can_reconnect_a_bounded_loop(self) -> None:
        linear_ir, conditional_graph, control_graph = self.graph_fixture()
        conditional_graph["proved_fallthroughs"] = []
        execution_graph = {
            "proved_fallthroughs": [
                {
                    "source_label": "L_SECOND_PATH",
                    "target_label": "L_LATCH_B",
                }
            ]
        }
        result = loop_prover._prove_graph(
            0, linear_ir, conditional_graph, execution_graph, control_graph
        )
        self.assertEqual(1, len(result["natural_loops"]))
        self.assertEqual([], result["rejected_headers"])

    def test_full_projection_is_deterministic_and_rejects_mutation(self) -> None:
        linear_ir = control_flow_tests.MesControlFlowProofTests().fixture()
        transfer = flow_prover.prove(linear_ir)
        conditional = region_prover.prove(linear_ir, transfer)
        library = {
            "ok": True,
            "schema": call_prover.LIBRARY_AUDIT_SCHEMA,
            "archive_name": "mes.arc",
            "archive_sha256": "1" * 64,
            "entry": "LIBLARY.LIB",
            "entry_sha256": "2" * 64,
            "source_archive_unchanged": True,
            "routines": [],
        }
        shared_calls = call_prover.prove(linear_ir, library)
        execution = execution_prover.prove(
            linear_ir, transfer, shared_calls, library
        )
        first = loop_prover.prove(
            linear_ir, transfer, conditional, execution, shared_calls, library
        )
        second = loop_prover.prove(
            copy.deepcopy(linear_ir),
            copy.deepcopy(transfer),
            copy.deepcopy(conditional),
            copy.deepcopy(execution),
            copy.deepcopy(shared_calls),
            copy.deepcopy(library),
        )
        self.assertEqual(first, second)
        self.assertEqual(0, first["coverage"]["natural_loop_count"])
        first["compatibility"]["surface_syntax_policy"] = "guessed_while"
        first["payload_sha256"] = loop_prover.fingerprint(first)
        with self.assertRaisesRegex(
            loop_prover.NaturalLoopProofError, "projection changed"
        ):
            loop_prover.validate(
                first,
                linear_ir,
                transfer,
                conditional,
                execution,
                shared_calls,
                library,
            )


if __name__ == "__main__":
    unittest.main()
