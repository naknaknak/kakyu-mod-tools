from __future__ import annotations

import copy
import sys
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

import prove_mes_call_families as call_prover  # noqa: E402
from tests import test_prove_mes_control_flow as flow_tests  # noqa: E402


class MesCallFamilyProofTests(unittest.TestCase):
    def node(
        self, op: str, statement: dict, start: int = 0, end: int = 5
    ) -> dict:
        return {
            "id": f"linear_{start:08x}",
            "kind": "statement",
            "source": {
                "entry": "TEST.MES",
                "region": "entry_0000",
                "start": start,
                "end": end,
            },
            "statement": {
                "kind": "instruction",
                "op": op,
                **statement,
            },
        }

    def resume(self, offset: int = 5) -> dict:
        return {
            "id": f"linear_{offset:08x}",
            "kind": "statement",
            "source": {
                "entry": "TEST.MES",
                "region": "entry_0000",
                "start": offset,
                "end": offset + 1,
            },
            "statement": {"kind": "instruction", "op": "command_00"},
        }

    def external_node(self) -> dict:
        target = "train.mes"
        return self.node(
            "script_dispatch",
            {
                "metadata": {"script_target": target},
                "operands": [
                    {
                        "type": "record_list",
                        "records": [
                            {
                                "type": "string_record",
                                "value": {
                                    "raw_hex": target.encode("ascii").hex()
                                },
                            }
                        ],
                    }
                ],
            },
        )

    def registered_node(self, ast: dict) -> dict:
        return self.node(
            "definition_invoke",
            {
                "metadata": {},
                "operands": [
                    {
                        "type": "record_list",
                        "records": [
                            {
                                "type": "expression_record",
                                "value": {"ast": ast},
                            }
                        ],
                    }
                ],
            },
        )

    def test_proves_external_call_site_without_return_edge(self) -> None:
        node = self.external_node()
        call, reason = call_prover._external_script_call(node, self.resume())
        self.assertEqual("", reason)
        self.assertEqual("TRAIN.MES", call["target_entry"])
        self.assertEqual(0, call["target_entry_coordinate"])
        self.assertEqual(5, call["physical_resume_offset"])
        self.assertFalse(call["cfg_edge_emitted"])
        self.assertEqual(
            "unproved_callee_total_return_not_supplied", call["return_edge"]
        )

    def test_rejects_external_target_metadata_or_bytes_mismatch(self) -> None:
        node = self.external_node()
        node["statement"]["operands"][0]["records"][0]["value"][
            "raw_hex"
        ] = "782e6d6573"
        call, reason = call_prover._external_script_call(node, self.resume())
        self.assertIsNone(call)
        self.assertEqual(
            "external_mes_target_metadata_disagrees_with_record", reason
        )

    def test_proves_literal_and_dynamic_registered_selectors(self) -> None:
        literal = self.registered_node({"type": "literal", "value": 11})
        call, reason = call_prover._registered_definition_call(
            literal, self.resume()
        )
        self.assertEqual("", reason)
        self.assertEqual({"kind": "literal", "value": 11}, call["selector"])
        self.assertFalse(call["cfg_edge_emitted"])

        dynamic = self.registered_node(
            {
                "type": "state_ref",
                "storage": "global_u8",
                "bank": 0,
                "index": {"type": "literal", "value": 2},
            }
        )
        call, reason = call_prover._registered_definition_call(
            dynamic, self.resume()
        )
        self.assertEqual("", reason)
        self.assertEqual("expression", call["selector"]["kind"])
        self.assertEqual("not_supplied", call["registry_binding"])

    def test_rejects_missing_or_ambiguous_physical_resume(self) -> None:
        node = self.external_node()
        resume, reason = call_prover._resume_node(node, {})
        self.assertIsNone(resume)
        self.assertEqual("physical_resume_node_missing", reason)
        resume, reason = call_prover._resume_node(
            node, {5: [self.resume(), copy.deepcopy(self.resume())]}
        )
        self.assertIsNone(resume)
        self.assertEqual("physical_resume_node_ambiguous", reason)
        other_entry = self.resume()
        other_entry["source"]["entry"] = "OTHER.MES"
        resume, reason = call_prover._resume_node(node, {5: [other_entry]})
        self.assertIsNone(resume)
        self.assertEqual("physical_resume_entry_changed", reason)

    def test_rejects_registered_selector_record_shape_change(self) -> None:
        node = self.registered_node({"type": "literal", "value": 11})
        node["statement"]["operands"][0]["records"].append(
            {"type": "expression_record", "value": {"ast": {}}}
        )
        call, reason = call_prover._registered_definition_call(
            node, self.resume()
        )
        self.assertIsNone(call)
        self.assertEqual(
            "registered_selector_is_not_one_expression_record", reason
        )

    def test_pipeline_is_deterministic_and_rejects_rehashed_mutation(self) -> None:
        linear_ir = flow_tests.MesControlFlowProofTests().fixture()
        first = call_prover.prove(linear_ir)
        second = call_prover.prove(copy.deepcopy(linear_ir))
        self.assertEqual(first, second)
        self.assertEqual(0, first["coverage"]["typed_call_family_count"])
        first["compatibility"]["return_edge_policy"] = "invent_return"
        first["payload_sha256"] = call_prover.fingerprint(first)
        with self.assertRaisesRegex(
            call_prover.CallFamilyProofError, "projection changed"
        ):
            call_prover.validate(first, linear_ir)


if __name__ == "__main__":
    unittest.main()
