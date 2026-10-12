from __future__ import annotations

import copy
import hashlib
import sys
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

import prove_mes_control_flow as flow_prover  # noqa: E402
import prove_mes_execution_fallthroughs as fallthrough_prover  # noqa: E402
import prove_mes_shared_call_returns as call_prover  # noqa: E402
from tests import test_prove_mes_control_flow as control_flow_tests  # noqa: E402


class MesExecutionFallthroughProofTests(unittest.TestCase):
    @staticmethod
    def node(
        start: int,
        raw_hex: str,
        op: str,
        command_id: int,
        metadata: dict | None = None,
    ) -> dict:
        raw = bytes.fromhex(raw_hex)
        return {
            "id": f"linear_{start:08x}",
            "kind": "statement",
            "source": {
                "region": "entry_0000",
                "start": start,
                "end": start + len(raw),
                "raw_hex": raw_hex,
            },
            "statement": {
                "op": op,
                "command_id": command_id,
                "metadata": metadata or {},
            },
        }

    def span_fixture(self) -> tuple[dict, dict[str, dict]]:
        metadata = {
            "native_handler_family": "character_stream_presentation",
            "native_stream_consumption": (
                "single_byte_run_until_nul_or_primary_double_byte_lead"
            ),
            "native_stream_probe": {
                "start_offset": 6,
                "probe_end_offset": 10,
                "consumed_byte_count": 4,
                "stop_offset": 9,
                "stop_reason": "nul_consumed",
            },
        }
        nodes = [
            self.node(5, "0d", "statement_separator", 0x0D, metadata),
            self.node(6, "02", "command_02", 0x02),
            self.node(7, "ff", "separator_ff", 0xFF),
            self.node(8, "02", "command_02", 0x02),
            self.node(9, "00", "command_00", 0x00),
            self.node(10, "1d0203ff00", "script_transfer", 0x1D),
            self.node(15, "1f01000000", "source_line_marker", 0x1F),
        ]
        call = {
            "call_node_id": "linear_0000000a",
            "caller_region": "entry_0000",
            "call_start": 10,
            "call_end": 15,
            "physical_resume_offset": 15,
            "routine_id": 3,
            "callee_entry": "LIBLARY.LIB",
            "callee_body_start": 100,
            "callee_body_end": 101,
            "callee_return_offsets": [100],
        }
        return {"nodes": nodes}, {"linear_0000000a": call}

    def test_proves_native_payload_mask_and_shared_call_return(self) -> None:
        linear_ir, calls = self.span_fixture()
        result, reason = fallthrough_prover._prove_span(
            linear_ir, "entry_0000", 5, 20, calls
        )
        self.assertEqual("", reason)
        self.assertIsNotNone(result)
        self.assertEqual(
            ["native_stream_payload", "shared_call_return", "linear_fallthrough"],
            [row["kind"] for row in result["segments"]],
        )
        self.assertEqual(10, result["segments"][0]["end"])
        self.assertEqual(15, result["segments"][1]["end"])

    def test_rejects_unproved_call_or_changed_native_terminator(self) -> None:
        linear_ir, _calls = self.span_fixture()
        missing, reason = fallthrough_prover._prove_span(
            linear_ir, "entry_0000", 5, 20, {}
        )
        self.assertIsNone(missing)
        self.assertEqual("shared_call_return_is_not_proven", reason)

        linear_ir, calls = self.span_fixture()
        linear_ir["nodes"][4]["source"]["raw_hex"] = "01"
        changed, reason = fallthrough_prover._prove_span(
            linear_ir, "entry_0000", 5, 20, calls
        )
        self.assertIsNone(changed)
        self.assertEqual(
            "native_stream_payload_terminator_or_extent_changed", reason
        )

    def test_projects_exact_call_return_edge_and_retains_unproved_fallback(self) -> None:
        linear_ir, calls = self.span_fixture()
        certified = calls["linear_0000000a"]
        certified["fallback_linear_node_id"] = "linear_0000000a"
        shared_calls = {
            "proved_calls": [certified],
            "unresolved_calls": [
                {
                    "call_node_id": "linear_00000014",
                    "caller_region": "entry_0000",
                    "call_start": 20,
                    "call_end": 25,
                    "routine_id": 40,
                    "reason": "shared_routine_native_cfg_is_cyclic",
                    "fallback_linear_node_id": "linear_00000014",
                }
            ],
        }
        edges, rejected = fallthrough_prover._prove_call_return_edges(
            linear_ir, shared_calls
        )
        self.assertEqual(1, len(edges))
        self.assertEqual("linear_0000000f", edges[0]["target_node_id"])
        self.assertEqual(15, edges[0]["physical_resume_offset"])
        self.assertEqual(
            "shared_call_returns_to_physical_resume", edges[0]["edge_kind"]
        )
        self.assertEqual(1, len(rejected))
        self.assertEqual(
            "shared_routine_native_cfg_is_cyclic", rejected[0]["reason"]
        )

    def test_rejects_certified_call_without_exact_resume_node(self) -> None:
        linear_ir, calls = self.span_fixture()
        certified = calls["linear_0000000a"]
        certified["fallback_linear_node_id"] = "linear_0000000a"
        linear_ir["nodes"] = [
            node for node in linear_ir["nodes"] if node["id"] != "linear_0000000f"
        ]
        edges, rejected = fallthrough_prover._prove_call_return_edges(
            linear_ir,
            {"proved_calls": [certified], "unresolved_calls": []},
        )
        self.assertEqual([], edges)
        self.assertEqual(
            "physical_resume_has_no_linear_ir_node", rejected[0]["reason"]
        )

    def test_full_projection_is_deterministic_and_rejects_mutation(self) -> None:
        linear_ir = control_flow_tests.MesControlFlowProofTests().fixture()
        transfers = flow_prover.prove(linear_ir)
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
        first = fallthrough_prover.prove(
            linear_ir, transfers, shared_calls, library
        )
        second = fallthrough_prover.prove(
            copy.deepcopy(linear_ir),
            copy.deepcopy(transfers),
            copy.deepcopy(shared_calls),
            copy.deepcopy(library),
        )
        self.assertEqual(first, second)
        self.assertEqual(0, first["coverage"]["proved_call_return_edge_count"])
        self.assertEqual(
            hashlib.sha256(
                fallthrough_prover.canonical_payload_bytes(first)
            ).hexdigest(),
            first["payload_sha256"],
        )
        first["coverage"]["proved_fallthrough_count"] += 1
        first["payload_sha256"] = fallthrough_prover.fingerprint(first)
        with self.assertRaisesRegex(
            fallthrough_prover.ExecutionFallthroughProofError,
            "projection changed",
        ):
            fallthrough_prover.validate(
                first, linear_ir, transfers, shared_calls, library
            )


if __name__ == "__main__":
    unittest.main()
