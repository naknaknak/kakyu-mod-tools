from __future__ import annotations

import copy
import hashlib
import sys
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
sys.path.insert(0, str(ROOT / "tools"))

import compile_mes_address_entry_insert as compiler  # noqa: E402
import compile_mes_noop as noop_compiler  # noqa: E402
import diff_mes_address_entry_semantics as semantic_diff  # noqa: E402
import validate_mes_analyzer_handoff as handoff_validator  # noqa: E402
from tests.test_compile_mes_address_entry_insert import (  # noqa: E402
    MesAddressEntryInsertCompilerTests,
)


class MesAddressEntrySemanticDiffTests(unittest.TestCase):
    def fixture(self) -> tuple[dict, dict, dict]:
        editable, plan = MesAddressEntryInsertCompilerTests().fixture()
        output, audit = compiler.compile_address_entry_insert(editable, plan)
        return editable, audit, self._output_handoff(editable, output)

    def test_maps_byte_identical_nodes_across_one_inserted_entry_boundary(self) -> None:
        editable, audit, handoff = self.fixture()
        result = semantic_diff.build(editable, audit, handoff)

        self.assertEqual("kakyu_mes_semantic_diff/v3", result["schema"])
        self.assertEqual("address_entry_insert", result["operation"]["family"])
        self.assertEqual(4, result["container_diff"]["byte_delta"])
        self.assertEqual(3, result["node_diff"]["exact_raw_node_count"])
        self.assertEqual(2, result["node_diff"]["region_changed_node_count"])
        self.assertTrue(result["preservation"]["bytecode_exact"])
        self.assertEqual("entry_0001", result["semantic_changes"]["address_entry"]["output_new_region"])
        semantic_diff.validate(copy.deepcopy(result), editable, audit, handoff)

    def test_rejects_rehashed_changed_output_statement(self) -> None:
        editable, audit, handoff = self.fixture()
        handoff["typed_ir"]["instructions"][1]["op"] = "changed_semantic_op"
        handoff["payload_sha256"] = handoff_validator.fingerprint(handoff)
        with self.assertRaisesRegex(
            semantic_diff.MesAddressEntrySemanticDiffError, "outside region ownership"
        ):
            semantic_diff.build(editable, audit, handoff)

    def test_rejects_rehashed_node_accounting_drift(self) -> None:
        editable, audit, handoff = self.fixture()
        result = semantic_diff.build(editable, audit, handoff)
        result["node_diff"]["region_changed_node_count"] += 1
        result["payload_sha256"] = semantic_diff.fingerprint(result)
        with self.assertRaisesRegex(
            semantic_diff.MesAddressEntrySemanticDiffError, "accounting"
        ):
            semantic_diff.validate(result)

    def test_rejects_compile_audit_rebound_to_another_editable(self) -> None:
        editable, audit, handoff = self.fixture()
        audit["inputs"]["editable_ir_sha256"] = "0" * 64
        audit["payload_sha256"] = compiler.fingerprint(audit)
        with self.assertRaisesRegex(
            semantic_diff.MesAddressEntrySemanticDiffError, "source binding"
        ):
            semantic_diff.build(editable, audit, handoff)

    def test_reference_coordinates_survive_derived_region_changes(self) -> None:
        source = [
            {
                "id": "resource_00000000", "kind": "resource", "source_offset": 1,
                "value": {"source_offset": 1, "region": "entry_0000", "name": "A.MMO"},
            },
            {
                "id": "code_00000000", "kind": "code", "source_offset": 0,
                "value": {"source_offset": 0, "target_offset": 1,
                          "target_region": "entry_0000", "op": "transfer"},
            },
        ]
        output = copy.deepcopy(source)
        output[0]["value"]["region"] = "entry_0001"
        output[1]["value"]["target_region"] = "entry_0001"
        regions = [
            {"id": "entry_0000", "source_start": 0, "source_end": 1},
            {"id": "entry_0001", "source_start": 1, "source_end": 2},
        ]

        changes = semantic_diff._reference_region_changes(source, output, regions)
        self.assertEqual(["region", "target_region"], [row["field"] for row in changes])
        changed_coordinate = copy.deepcopy(output)
        changed_coordinate[1]["value"]["target_offset"] = 0
        with self.assertRaisesRegex(
            semantic_diff.MesAddressEntrySemanticDiffError, "coordinate"
        ):
            semantic_diff._reference_region_changes(source, changed_coordinate, regions)

    @staticmethod
    def _output_handoff(editable: dict, output: bytes) -> dict:
        source_ir = editable["source_ir"]
        reopened = noop_compiler.reopen_container(output)
        code_offset = int(reopened["code_offset"])
        code = output[code_offset:]
        offsets = [int(value) for value in reopened["entry_offsets"]]
        entries = []
        for index, offset in enumerate(offsets):
            end = offsets[index + 1] if index + 1 < len(offsets) else len(code)
            entries.append({
                "id": f"entry_{index:04d}", "index": index, "offset": offset,
                "end_offset": end, "size": end - offset,
            })
        instructions = []
        for node in source_ir["nodes"]:
            start = int(node["source"]["start"])
            end = int(node["source"]["end"])
            entry_index = max(index for index, offset in enumerate(offsets) if offset <= start)
            statement = node["statement"]
            instructions.append({
                "ok": True, "schema": handoff_validator.COMPONENT_SCHEMAS["instruction"],
                "source_offset": start, "end_offset": end, "byte_length": end - start,
                "raw_hex": code[start:end].hex(), "region": f"entry_{entry_index:04d}",
                "op": statement["op"], "command_id": statement["command_id"],
                "operands": copy.deepcopy(statement["operands"]),
                **copy.deepcopy(statement["metadata"]),
            })
        handoff = {
            "ok": True, "schema": handoff_validator.HANDOFF_SCHEMA,
            "producer": {"implementation": "test", "contract": handoff_validator.HANDOFF_SCHEMA},
            "compatibility": {
                "policy": "exact_component_schema_match",
                "component_schemas": {
                    **handoff_validator.COMPONENT_SCHEMAS,
                    "accepted_call_evidence": handoff_validator.CALL_EVIDENCE_SCHEMAS,
                    "accepted_trace_evidence": handoff_validator.TRACE_EVIDENCE_SCHEMAS,
                },
            },
            "source_identity": copy.deepcopy(source_ir["source_identity"]),
            "container": {
                "schema": "ai5_mes_container/v1",
                "header": {"code_offset": code_offset, "code_size": len(code)},
                "bootstrap": {"offset": 0, "end_offset": 0, "size": 0},
                "entries": entries,
                "entry_sha256": hashlib.sha256(output).hexdigest(),
                "bytecode_sha256": hashlib.sha256(code).hexdigest(), "raw_hex": output.hex(),
            },
            "record_alignment": {"schema": "kakyu_mes_record_alignment_audit/v1"},
            "typed_ir": {
                "schema": "kakyu_mes_analysis/v19", "complete": True,
                "instructions": instructions, "diagnostics": [], "opaque_boundaries": [],
            },
            "references": {"messages": [], "code": [], "state": [], "resources": []},
            "cfg": [], "calls": [], "traces": [],
        }
        handoff["payload_sha256"] = handoff_validator.fingerprint(handoff)
        return handoff


if __name__ == "__main__":
    unittest.main()
