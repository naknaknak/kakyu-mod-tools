from __future__ import annotations

import copy
import sys
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

import decompile_mes_handoff as decompiler  # noqa: E402
import prove_mes_shared_call_returns as call_prover  # noqa: E402
from tests import test_prove_mes_control_flow as control_flow_tests  # noqa: E402


class MesSharedCallReturnProofTests(unittest.TestCase):
    def linear_fixture(self) -> dict:
        linear_ir = control_flow_tests.MesControlFlowProofTests().fixture()
        node = linear_ir["nodes"][1]
        node["statement"]["op"] = "script_transfer"
        node["statement"]["command_id"] = 0x1D
        node["statement"]["operands"] = [
            {
                "type": "record_list",
                "records": [
                    {
                        "type": "expression_record",
                        "value": {"ast": {"type": "literal", "value": 3}},
                    }
                ],
            }
        ]
        linear_ir["payload_sha256"] = decompiler.fingerprint(linear_ir)
        return linear_ir

    def library_fixture(self) -> dict:
        return {
            "ok": True,
            "schema": call_prover.LIBRARY_AUDIT_SCHEMA,
            "archive_name": "mes.arc",
            "archive_sha256": "1" * 64,
            "entry": "LIBLARY.LIB",
            "entry_sha256": "2" * 64,
            "source_archive_unchanged": True,
            "routines": [self.return_routine(3, 100)],
        }

    def return_routine(self, routine_id: int, body_offset: int) -> dict:
        return {
            "routine_id": routine_id,
            "body_offset": body_offset,
            "end_offset": body_offset + 1,
            "strict": {"complete": True, "decoded_end_offset": body_offset + 1},
            "structural": {
                "complete": True,
                "decoded_end_offset": body_offset + 1,
            },
            "native_dispatch_flow": {
                "complete": True,
                "instruction_count": 1,
                "edge_count": 0,
                "instructions": [
                    {
                        "source_offset": body_offset,
                        "decoded_end_offset": body_offset + 1,
                        "command_id": 0,
                        "op": "command_00",
                    }
                ],
                "edges": [],
                "return_offsets": [body_offset],
                "exit_offsets": [],
                "boundaries": [],
                "failures": [],
            },
        }

    def test_proves_literal_call_when_every_callee_terminal_returns(self) -> None:
        result = call_prover.prove(self.linear_fixture(), self.library_fixture())
        self.assertEqual(1, result["coverage"]["script_transfer_count"])
        self.assertEqual(1, result["coverage"]["proved_call_return_count"])
        self.assertEqual([], result["unresolved_calls"])
        call = result["proved_calls"][0]
        self.assertEqual(3, call["routine_id"])
        self.assertEqual(7, call["physical_resume_offset"])
        self.assertEqual([100], call["callee_return_offsets"])
        self.assertEqual([], call["direct_callee_routine_ids"])
        self.assertEqual([], call["transitive_callee_routine_ids"])
        self.assertEqual(
            "literal_shared_call_all_callee_terminals_return_to_physical_resume",
            call["proof_status"],
        )

    def test_native_cfg_supersedes_incomplete_diagnostic_decodes(self) -> None:
        audit = self.library_fixture()
        routine = audit["routines"][0]
        routine["strict"] = {"complete": False, "decoded_end_offset": 100}
        routine["structural"] = {"complete": False, "decoded_end_offset": 100}
        result = call_prover.prove(self.linear_fixture(), audit)
        self.assertEqual(1, result["coverage"]["proved_call_return_count"])
        self.assertTrue(result["routine_return_contracts"][0]["proved"])

        routine["strict"]["decoded_end_offset"] = 102
        with self.assertRaisesRegex(
            call_prover.SharedCallReturnProofError, "strict decode bounds changed"
        ):
            call_prover.prove(self.linear_fixture(), audit)

    def test_proves_nested_calls_only_after_fixed_point_callee_proof(self) -> None:
        audit = self.library_fixture()
        caller = audit["routines"][0]
        caller["end_offset"] = 102
        caller["strict"]["decoded_end_offset"] = 102
        caller["structural"]["decoded_end_offset"] = 102
        flow = caller["native_dispatch_flow"]
        flow["instructions"] = [
            {
                "source_offset": 100,
                "decoded_end_offset": 101,
                "command_id": 0x1D,
                "op": "script_transfer",
                "routine_id": 4,
            },
            {
                "source_offset": 101,
                "decoded_end_offset": 102,
                "command_id": 0,
                "op": "command_00",
            },
        ]
        flow["edges"] = [{"from_offset": 100, "to_offset": 101}]
        flow["instruction_count"] = 2
        flow["edge_count"] = 1
        flow["return_offsets"] = [101]

        missing = call_prover.prove(self.linear_fixture(), audit)
        self.assertEqual(
            "shared_routine_nested_callee_is_absent_from_supplied_library_audit",
            missing["unresolved_calls"][0]["reason"],
        )
        self.assertEqual([4], missing["unresolved_calls"][0]["required_callee_routine_ids"])

        audit["routines"].append(self.return_routine(4, 200))
        proved = call_prover.prove(self.linear_fixture(), audit)
        call = proved["proved_calls"][0]
        self.assertEqual([4], call["direct_callee_routine_ids"])
        self.assertEqual([4], call["transitive_callee_routine_ids"])
        self.assertEqual(2, proved["coverage"]["proved_total_return_routine_count"])

    def test_rejects_nested_call_cycle(self) -> None:
        audit = self.library_fixture()
        routine = audit["routines"][0]
        routine["end_offset"] = 102
        routine["strict"]["decoded_end_offset"] = 102
        routine["structural"]["decoded_end_offset"] = 102
        flow = routine["native_dispatch_flow"]
        flow["instructions"] = [
            {
                "source_offset": 100,
                "decoded_end_offset": 101,
                "command_id": 0x1D,
                "op": "script_transfer",
                "routine_id": 3,
            },
            {
                "source_offset": 101,
                "decoded_end_offset": 102,
                "command_id": 0,
                "op": "command_00",
            },
        ]
        flow["edges"] = [{"from_offset": 100, "to_offset": 101}]
        flow["instruction_count"] = 2
        flow["edge_count"] = 1
        flow["return_offsets"] = [101]
        cyclic = call_prover.prove(self.linear_fixture(), audit)
        self.assertEqual(
            "shared_routine_nested_call_graph_is_cyclic_or_unresolved",
            cyclic["unresolved_calls"][0]["reason"],
        )

    def test_keeps_dynamic_or_missing_routine_calls_unresolved(self) -> None:
        linear_ir = self.linear_fixture()
        linear_ir["nodes"][1]["statement"]["operands"][0]["records"][0]["value"][
            "ast"
        ] = {"type": "state_ref", "storage": "state_u16", "index": 3}
        linear_ir["payload_sha256"] = decompiler.fingerprint(linear_ir)
        dynamic = call_prover.prove(linear_ir, self.library_fixture())
        self.assertEqual(
            "shared_routine_selector_is_dynamic",
            dynamic["unresolved_calls"][0]["reason"],
        )

        linear_ir = self.linear_fixture()
        linear_ir["nodes"][1]["statement"]["operands"][0]["records"][0]["value"][
            "ast"
        ]["value"] = 4
        linear_ir["payload_sha256"] = decompiler.fingerprint(linear_ir)
        missing = call_prover.prove(linear_ir, self.library_fixture())
        self.assertEqual(
            "shared_routine_is_absent_from_supplied_library_audit",
            missing["unresolved_calls"][0]["reason"],
        )

    def test_rejects_callee_boundary_and_nonreturn_terminal(self) -> None:
        audit = self.library_fixture()
        audit["routines"][0]["native_dispatch_flow"]["boundaries"] = [
            {"source_offset": 100}
        ]
        boundary = call_prover.prove(self.linear_fixture(), audit)
        self.assertEqual(
            "shared_routine_has_boundaries", boundary["unresolved_calls"][0]["reason"]
        )

        audit = self.library_fixture()
        instruction = audit["routines"][0]["native_dispatch_flow"]["instructions"][0]
        instruction["command_id"] = 18
        instruction["op"] = "native_record_dispatch"
        audit["routines"][0]["native_dispatch_flow"]["return_offsets"] = []
        nonreturn = call_prover.prove(self.linear_fixture(), audit)
        self.assertEqual(
            "shared_routine_has_no_return_terminal",
            nonreturn["unresolved_calls"][0]["reason"],
        )

    def test_rejects_unreachable_or_cyclic_callee_flow(self) -> None:
        audit = self.library_fixture()
        routine = audit["routines"][0]
        routine["end_offset"] = 102
        routine["strict"]["decoded_end_offset"] = 102
        routine["structural"]["decoded_end_offset"] = 102
        flow = routine["native_dispatch_flow"]
        flow["instructions"].append(
            {
                "source_offset": 101,
                "decoded_end_offset": 102,
                "command_id": 0,
                "op": "command_00",
            }
        )
        flow["instruction_count"] = 2
        flow["return_offsets"].append(101)
        unreachable = call_prover.prove(self.linear_fixture(), audit)
        self.assertEqual(
            "shared_routine_native_cfg_has_unreachable_instruction",
            unreachable["unresolved_calls"][0]["reason"],
        )

        audit = self.library_fixture()
        flow = audit["routines"][0]["native_dispatch_flow"]
        flow["edges"] = [{"from_offset": 100, "to_offset": 100}]
        flow["edge_count"] = 1
        cyclic = call_prover.prove(self.linear_fixture(), audit)
        self.assertEqual(
            "shared_routine_native_cfg_is_cyclic",
            cyclic["unresolved_calls"][0]["reason"],
        )

    def test_projection_is_deterministic_and_rejects_mutation(self) -> None:
        linear_ir = self.linear_fixture()
        library = self.library_fixture()
        first = call_prover.prove(linear_ir, library)
        second = call_prover.prove(copy.deepcopy(linear_ir), copy.deepcopy(library))
        self.assertEqual(first, second)
        first["proved_calls"][0]["physical_resume_offset"] += 1
        first["payload_sha256"] = call_prover.fingerprint(first)
        with self.assertRaisesRegex(
            call_prover.SharedCallReturnProofError, "projection changed"
        ):
            call_prover.validate(first, linear_ir, library)


if __name__ == "__main__":
    unittest.main()
