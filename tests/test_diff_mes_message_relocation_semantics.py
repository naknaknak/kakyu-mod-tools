from __future__ import annotations

import copy
import hashlib
import sys
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
sys.path.insert(0, str(ROOT / "tools"))

import compile_mes_control_target_relocation as control_compiler  # noqa: E402
import compile_mes_message_relocation as message_compiler  # noqa: E402
import compile_mes_noop as noop_compiler  # noqa: E402
import diff_mes_message_relocation_semantics as semantic_diff  # noqa: E402
import validate_mes_analyzer_handoff as handoff_validator  # noqa: E402
from tests.test_compile_mes_control_target_relocation import (  # noqa: E402
    MesControlTargetRelocationCompilerTests,
)
from tests.test_compile_mes_message_relocation import (  # noqa: E402
    MesMessageRelocationCompilerTests,
)


class MesMessageRelocationSemanticDiffTests(unittest.TestCase):
    def fixture(self, with_targets: bool) -> tuple[dict, dict, dict]:
        if with_targets:
            editable, message_plan, control_plan = MesControlTargetRelocationCompilerTests().fixture()
            output, audit = control_compiler.compile_message_with_targets(
                editable, message_plan, control_plan
            )
        else:
            editable, message_plan = MesMessageRelocationCompilerTests().fixture()
            output, audit = message_compiler.compile_message(editable, message_plan)
        return editable, audit, self._output_handoff(editable, audit, output)

    def test_maps_message_only_relocation(self) -> None:
        editable, audit, handoff = self.fixture(False)
        result = semantic_diff.build(editable, audit, handoff)

        self.assertEqual("kakyu_mes_semantic_diff/v4", result["schema"])
        self.assertEqual("message_only", result["operation"]["compile_family"])
        self.assertEqual(2, result["container_diff"]["code_delta"])
        self.assertEqual(1, result["node_diff"]["message_replaced_node_count"])
        self.assertEqual(0, result["node_diff"]["target_patched_node_count"])

    def test_maps_message_and_control_target_relocation(self) -> None:
        editable, audit, handoff = self.fixture(True)
        result = semantic_diff.build(editable, audit, handoff)

        self.assertEqual(
            "message_with_control_targets", result["operation"]["compile_family"]
        )
        self.assertEqual(1, result["node_diff"]["target_patched_node_count"])
        self.assertEqual(1, result["preservation"]["target_change_count"])
        semantic_diff.validate(copy.deepcopy(result), editable, audit, handoff)

    def test_rejects_rehashed_reference_coordinate_drift(self) -> None:
        editable, audit, handoff = self.fixture(True)
        handoff["references"]["code"][0]["target_offset"] += 1
        handoff["payload_sha256"] = handoff_validator.fingerprint(handoff)
        with self.assertRaisesRegex(
            semantic_diff.MesMessageRelocationSemanticDiffError, "reference coordinate"
        ):
            semantic_diff.build(editable, audit, handoff)

    def test_rejects_rehashed_node_accounting_drift(self) -> None:
        editable, audit, handoff = self.fixture(False)
        result = semantic_diff.build(editable, audit, handoff)
        result["node_diff"]["exact_unrelated_node_count"] += 1
        result["payload_sha256"] = semantic_diff.fingerprint(result)
        with self.assertRaisesRegex(
            semantic_diff.MesMessageRelocationSemanticDiffError, "accounting"
        ):
            semantic_diff.validate(result)

    @staticmethod
    def _output_handoff(editable: dict, audit: dict, output: bytes) -> dict:
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
        relocation = audit["relocation"]
        pivot = int(relocation["source_instruction_end"])
        delta = int(relocation["delta"])
        target_start = int(relocation["source_instruction_start"])
        target_end = int(relocation["output_instruction_end"])
        patch_by_owner = {
            int(row["source_instruction_start"]): row
            for row in audit.get("target_patches", [])
        }
        instructions = []
        for node in source_ir["nodes"]:
            source_start = int(node["source"]["start"])
            source_end = int(node["source"]["end"])
            start = source_start + (delta if source_start >= pivot else 0)
            end = source_end + (delta if source_start >= pivot else 0)
            statement = copy.deepcopy(node["statement"])
            if source_start == target_start:
                start, end = target_start, target_end
                raw = code[start:end]
                payload = raw[1:-1]
                statement["operands"][0]["raw_hex"] = payload.hex()
                statement["operands"][0]["raw_bytes"] = {
                    "$packed_byte_array_hex": payload.hex()
                }
                probe = statement["metadata"]["native_stream_probe"]
                probe["character_count"] = len(payload) // 2
                probe["consumed_byte_count"] = len(payload) + 1
                probe["stop_offset"] += delta
                probe["probe_end_offset"] += delta
            else:
                raw = code[start:end]
                statement = MesMessageRelocationSemanticDiffTests._relocate_coordinates(
                    statement, pivot, delta
                )
                patch = patch_by_owner.get(source_start)
                if patch:
                    MesMessageRelocationSemanticDiffTests._replace_code_offset(
                        statement, int(patch["source_target_offset"]),
                        int(patch["output_target_offset"]),
                    )
            entry_index = max(index for index, offset in enumerate(offsets) if offset <= start)
            instructions.append({
                "ok": True, "schema": handoff_validator.COMPONENT_SCHEMAS["instruction"],
                "source_offset": start, "end_offset": end, "byte_length": end - start,
                "raw_hex": raw.hex(), "region": f"entry_{entry_index:04d}",
                "op": statement["op"], "command_id": statement["command_id"],
                "operands": statement["operands"], **statement["metadata"],
            })
        references = {"messages": [], "code": [], "state": [], "resources": []}
        target_ids = set(next(
            node["reference_ids"] for node in source_ir["nodes"]
            if int(node["source"]["start"]) == target_start
        ))
        for reference in source_ir["references"]:
            value = copy.deepcopy(reference["value"])
            if reference["id"] in target_ids:
                raw = code[target_start:target_end]
                payload = raw[1:-1]
                value["raw_hex"] = payload.hex()
                value["raw_bytes"] = {"$packed_byte_array_hex": payload.hex()}
                value["raw_sha256"] = hashlib.sha256(payload).hexdigest()
                value["end_offset"] += delta
                probe = value["native_stream_probe"]
                probe["character_count"] = len(payload) // 2
                probe["consumed_byte_count"] = len(payload) + 1
                probe["stop_offset"] += delta
                probe["probe_end_offset"] += delta
            else:
                value = MesMessageRelocationSemanticDiffTests._relocate_coordinates(
                    value, pivot, delta
                )
            plural = {
                "message": "messages", "code": "code", "state": "state",
                "resource": "resources",
            }[reference["kind"]]
            references[plural].append(value)
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
                "entries": entries, "entry_sha256": hashlib.sha256(output).hexdigest(),
                "bytecode_sha256": hashlib.sha256(code).hexdigest(), "raw_hex": output.hex(),
            },
            "record_alignment": {"schema": "kakyu_mes_record_alignment_audit/v1"},
            "typed_ir": {
                "schema": "kakyu_mes_analysis/v19", "complete": True,
                "instructions": instructions, "diagnostics": [], "opaque_boundaries": [],
            },
            "references": references, "cfg": [], "calls": [], "traces": [],
        }
        handoff["payload_sha256"] = handoff_validator.fingerprint(handoff)
        return handoff

    @staticmethod
    def _relocate_coordinates(value: object, pivot: int, delta: int, key: str = "") -> object:
        if isinstance(value, dict):
            return {
                name: MesMessageRelocationSemanticDiffTests._relocate_coordinates(
                    child, pivot, delta, name
                )
                for name, child in value.items()
            }
        if isinstance(value, list):
            return [
                MesMessageRelocationSemanticDiffTests._relocate_coordinates(
                    child, pivot, delta, key
                )
                for child in value
            ]
        if key in semantic_diff.COORDINATE_FIELDS and isinstance(value, int) and not isinstance(value, bool):
            return value + delta if value >= pivot else value
        return value

    @staticmethod
    def _replace_code_offset(value: object, source: int, output: int) -> None:
        if isinstance(value, dict):
            if value.get("type") == "code_offset" and value.get("value") == source:
                value["value"] = output
            for child in value.values():
                MesMessageRelocationSemanticDiffTests._replace_code_offset(child, source, output)
        elif isinstance(value, list):
            for child in value:
                MesMessageRelocationSemanticDiffTests._replace_code_offset(child, source, output)


if __name__ == "__main__":
    unittest.main()
