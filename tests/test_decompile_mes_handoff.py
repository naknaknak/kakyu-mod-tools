from __future__ import annotations

import copy
import hashlib
import sys
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

import decompile_mes_handoff as decompiler  # noqa: E402
import validate_mes_analyzer_handoff as handoff_validator  # noqa: E402


class MesDecompilerLinearIrTests(unittest.TestCase):
    def fixture(self) -> tuple[dict, bytes]:
        preamble = bytes.fromhex("0100000002000000")
        code = bytes.fromhex("01ff1700000000aabbccdd")
        raw = preamble + code
        document = {
            "ok": True,
            "schema": handoff_validator.HANDOFF_SCHEMA,
            "producer": {"implementation": "test", "contract": handoff_validator.HANDOFF_SCHEMA},
            "compatibility": {
                "policy": "exact_component_schema_match",
                "component_schemas": {
                    **handoff_validator.COMPONENT_SCHEMAS,
                    "accepted_call_evidence": handoff_validator.CALL_EVIDENCE_SCHEMAS,
                    "accepted_trace_evidence": handoff_validator.TRACE_EVIDENCE_SCHEMAS,
                },
            },
            "source_identity": {"archive": "mes.arc", "entry": "TEST.MES"},
            "container": {
                "schema": "ai5_mes_container/v1",
                "header": {"code_offset": len(preamble), "code_size": len(code)},
                "bootstrap": {"offset": 0, "end_offset": 2, "size": 2},
                "entries": [
                    {"id": "entry_0000", "index": 0, "offset": 2, "end_offset": len(code), "size": len(code) - 2}
                ],
                "entry_sha256": hashlib.sha256(raw).hexdigest(),
                "bytecode_sha256": hashlib.sha256(code).hexdigest(),
                "raw_hex": raw.hex(),
            },
            "record_alignment": {"schema": "kakyu_mes_record_alignment_audit/v1"},
            "typed_ir": {
                "schema": "kakyu_mes_analysis/v19",
                "complete": False,
                "instructions": [
                    {
                        "ok": True,
                        "schema": "ai5_mes_instruction/v45",
                        "source_offset": 0,
                        "end_offset": 2,
                        "byte_length": 2,
                        "raw_hex": "01ff",
                        "region": "bootstrap",
                        "op": "expression_probe",
                        "command_id": 1,
                        "operands": [
                            {
                                "type": "expression",
                                "value": {
                                    "ast": {"type": "literal", "value": 1, "width": 8},
                                    "raw_hex": "01ff",
                                },
                            }
                        ],
                    },
                    {
                        "ok": True,
                        "schema": "ai5_mes_instruction/v45",
                        "source_offset": 2,
                        "end_offset": 7,
                        "byte_length": 5,
                        "raw_hex": "1700000000",
                        "region": "entry_0000",
                        "op": "entry_label",
                        "command_id": 23,
                        "operands": [{"type": "entry_index", "value": 0}],
                        "native_handler_family": "retained_test_metadata",
                    },
                ],
                "diagnostics": [{"code": "test_boundary"}],
                "opaque_boundaries": [
                    {
                        "source_offset": 7,
                        "end_offset": 11,
                        "raw_hex": "aabbccdd",
                        "raw_sha256": hashlib.sha256(bytes.fromhex("aabbccdd")).hexdigest(),
                        "region": "entry_0000",
                        "boundary": "byte_preserving_fail_closed",
                        "reason": "synthetic unresolved tail",
                    }
                ],
            },
            "references": {
                "messages": [{"source_offset": 3, "kind": "text", "raw_hex": "00"}],
                "code": [{"source_offset": 0, "kind": "test_target", "target_offset": 2}],
                "state": [{"source_offset": 6, "storage": "global_u8", "index": "1"}],
                "resources": [{"source_offset": 8, "resource_kind": "opaque_test"}],
            },
            "cfg": [
                {
                    "ok": True,
                    "schema": "kakyu_mes_reference_graph/v1",
                    "nodes": [
                        {"id": "instruction_00000002", "offset": 2},
                        {"id": "opaque_00000007", "offset": 7},
                    ],
                    "edges": [],
                }
            ],
            "calls": [],
            "traces": [],
            "capability_report": {"product_ui_data": "forbidden"},
        }
        document["payload_sha256"] = handoff_validator.fingerprint(document)
        return document, raw

    def test_lifts_typed_and_opaque_records_without_losing_source(self) -> None:
        handoff, raw = self.fixture()
        document = decompiler.lift(handoff)

        self.assertEqual(decompiler.DECOMPILER_IR_SCHEMA, document["schema"])
        self.assertEqual(raw, decompiler.reconstruct_container(document))
        self.assertEqual(3, document["coverage"]["node_count"])
        self.assertEqual(1, document["coverage"]["opaque_node_count"])
        self.assertTrue(document["coverage"]["complete"])
        self.assertEqual("literal", document["nodes"][0]["statement"]["operands"][0]["value"]["ast"]["type"])
        self.assertEqual(
            "retained_test_metadata",
            document["nodes"][1]["statement"]["metadata"]["native_handler_family"],
        )
        self.assertEqual("opaque", document["nodes"][2]["statement"]["kind"])
        self.assertNotIn("op", document["nodes"][2]["statement"])
        self.assertEqual(
            [{"graph_index": 0, "node_id": "instruction_00000002"}],
            document["nodes"][1]["cfg_nodes"],
        )
        self.assertEqual(4, sum(len(node["reference_ids"]) for node in document["nodes"]))

    def test_identical_handoff_produces_identical_fingerprint(self) -> None:
        handoff, _raw = self.fixture()
        first = decompiler.lift(handoff)
        second = decompiler.lift(copy.deepcopy(handoff))
        self.assertEqual(first, second)
        self.assertEqual(decompiler.fingerprint(first), first["payload_sha256"])

    def test_rejects_rehashed_handoff_with_changed_record_bytes(self) -> None:
        handoff, _raw = self.fixture()
        handoff["typed_ir"]["instructions"][0]["raw_hex"] = "02ff"
        handoff["payload_sha256"] = handoff_validator.fingerprint(handoff)
        with self.assertRaisesRegex(decompiler.DecompilerIrError, "record raw bytes"):
            decompiler.lift(handoff)

    def test_rejects_gap_between_typed_and_opaque_records(self) -> None:
        handoff, _raw = self.fixture()
        boundary = handoff["typed_ir"]["opaque_boundaries"][0]
        boundary["source_offset"] = 8
        boundary["raw_hex"] = "bbccdd"
        boundary["raw_sha256"] = hashlib.sha256(bytes.fromhex("bbccdd")).hexdigest()
        handoff["payload_sha256"] = handoff_validator.fingerprint(handoff)
        with self.assertRaisesRegex(decompiler.DecompilerIrError, "do not partition"):
            decompiler.lift(handoff)

    def test_rejects_mutated_output_even_when_raw_source_still_matches(self) -> None:
        handoff, _raw = self.fixture()
        document = decompiler.lift(handoff)
        document["nodes"][1]["statement"]["op"] = "guessed_command"
        with self.assertRaisesRegex(decompiler.DecompilerIrError, "fingerprint changed"):
            decompiler.validate(document)

    def test_rejects_rehashed_output_with_wrong_reference_source_map(self) -> None:
        handoff, _raw = self.fixture()
        document = decompiler.lift(handoff)
        document["nodes"][0]["reference_ids"].append(document["nodes"][1]["reference_ids"].pop())
        document["payload_sha256"] = decompiler.fingerprint(document)
        with self.assertRaisesRegex(decompiler.DecompilerIrError, "reference source mapping"):
            decompiler.validate(document)

    def test_rejects_rehashed_output_with_wrong_cfg_source_map(self) -> None:
        handoff, _raw = self.fixture()
        document = decompiler.lift(handoff)
        document["nodes"][0]["cfg_nodes"] = document["nodes"][1]["cfg_nodes"]
        document["nodes"][1]["cfg_nodes"] = []
        document["payload_sha256"] = decompiler.fingerprint(document)
        with self.assertRaisesRegex(decompiler.DecompilerIrError, "CFG source mapping"):
            decompiler.validate(document)


if __name__ == "__main__":
    unittest.main()
