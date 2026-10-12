from __future__ import annotations

import copy
import hashlib
import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

import compile_mes_control_body_edit as compiler  # noqa: E402
import compile_mes_noop as noop_compiler  # noqa: E402
import diff_mes_control_body_semantics as semantic_diff  # noqa: E402
import plan_mes_control_body_edit as planner  # noqa: E402
import validate_mes_analyzer_handoff as handoff_validator  # noqa: E402
from tests import test_plan_mes_control_body_edit as plan_tests  # noqa: E402


class MesControlBodySemanticDiffTests(unittest.TestCase):
    def fixture(self, kind: str = "insert") -> tuple[dict, dict, dict]:
        editable, insert, remove = plan_tests.MesControlBodyEditPlanTests().fixture(
            opaque_head=True
        )
        operation = insert if kind == "insert" else remove
        plan = planner.plan(editable, operation)
        output, audit = compiler.compile_body_edit(editable, plan)
        return editable, audit, self._output_handoff(editable, output, audit)

    def test_diffs_inserted_body_and_preserves_unrelated_opaque_node(self) -> None:
        editable, audit, output_handoff = self.fixture()

        result = semantic_diff.build(editable, audit, output_handoff)

        self.assertEqual((1, 0, 1), (
            result["node_diff"]["inserted_node_count"],
            result["node_diff"]["removed_node_count"],
            result["node_diff"]["patched_node_count"],
        ))
        self.assertEqual((1, 1, 1), (
            result["preservation"]["source_opaque_node_count"],
            result["preservation"]["output_opaque_node_count"],
            result["preservation"]["exact_opaque_node_count"],
        ))
        self.assertEqual(1, len(result["semantic_changes"]["target_changes"]))
        self.assertTrue(result["semantic_changes"]["target_changes"][0]["output_reference_verified"])

    def test_diffs_removed_body_and_survives_json_transport(self) -> None:
        editable, audit, output_handoff = self.fixture("remove")
        result = semantic_diff.build(editable, audit, output_handoff)
        transported = json.loads(json.dumps(result))

        self.assertEqual((0, 1, 1), (
            result["node_diff"]["inserted_node_count"],
            result["node_diff"]["removed_node_count"],
            result["node_diff"]["patched_node_count"],
        ))
        self.assertEqual(1, result["preservation"]["exact_opaque_node_count"])
        semantic_diff.validate(transported, editable, audit, output_handoff)

    def test_rejects_rehashed_output_reference_that_does_not_match_patch(self) -> None:
        editable, audit, output_handoff = self.fixture()
        changed = copy.deepcopy(output_handoff)
        changed["references"]["code"][0]["target_offset"] -= 1
        changed["payload_sha256"] = handoff_validator.fingerprint(changed)

        with self.assertRaisesRegex(semantic_diff.MesSemanticDiffError, "reference"):
            semantic_diff.build(editable, audit, changed)

    def test_rejects_rehashed_unrelated_output_byte_mutation(self) -> None:
        editable, audit, output_handoff = self.fixture()
        changed = copy.deepcopy(output_handoff)
        raw = bytearray.fromhex(changed["container"]["raw_hex"])
        code_offset = changed["container"]["header"]["code_offset"]
        raw[code_offset] ^= 0x01
        code = bytes(raw[code_offset:])
        changed["container"]["raw_hex"] = bytes(raw).hex()
        changed["container"]["entry_sha256"] = hashlib.sha256(raw).hexdigest()
        changed["container"]["bytecode_sha256"] = hashlib.sha256(code).hexdigest()
        changed["typed_ir"]["opaque_boundaries"][0]["raw_hex"] = code[0:1].hex()
        changed["typed_ir"]["opaque_boundaries"][0]["raw_sha256"] = hashlib.sha256(code[0:1]).hexdigest()
        changed["payload_sha256"] = handoff_validator.fingerprint(changed)

        with self.assertRaisesRegex(semantic_diff.MesSemanticDiffError, "output container"):
            semantic_diff.build(editable, audit, changed)

    def test_cli_publishes_new_diff_once(self) -> None:
        editable, audit, output_handoff = self.fixture("remove")
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            editable_path = root / "editable.json"
            audit_path = root / "compile.json"
            handoff_path = root / "handoff.json"
            output_path = root / "semantic-diff.json"
            editable_path.write_text(json.dumps(editable), encoding="utf-8")
            audit_path.write_text(json.dumps(audit), encoding="utf-8")
            handoff_path.write_text(json.dumps(output_handoff), encoding="utf-8")
            argv = [
                "diff_mes_control_body_semantics.py", str(editable_path),
                str(audit_path), str(handoff_path), str(output_path),
            ]
            with mock.patch.object(sys, "argv", argv):
                semantic_diff.main()
            semantic_diff.validate(
                json.loads(output_path.read_text(encoding="utf-8")),
                editable, audit, output_handoff,
            )
            with mock.patch.object(sys, "argv", argv):
                with self.assertRaisesRegex(
                    semantic_diff.MesSemanticDiffError, "new distinct"
                ):
                    semantic_diff.main()

    @staticmethod
    def _output_handoff(
        editable: dict, output: bytes, audit: dict
    ) -> dict:
        source_ir = editable["source_ir"]
        reopened = noop_compiler.reopen_container(output)
        code_offset = int(reopened["code_offset"])
        code = output[code_offset:]
        offsets = [int(value) for value in reopened["entry_offsets"]]
        bootstrap_region = next(
            row for row in source_ir["regions"] if row["kind"] == "bootstrap"
        )
        entries = []
        for index, offset in enumerate(offsets):
            end = offsets[index + 1] if index + 1 < len(offsets) else len(code)
            entries.append({
                "id": f"entry_{index:04d}", "index": index,
                "offset": offset, "end_offset": end, "size": end - offset,
            })
        operation = audit["operation"]
        pivot, delta = (
            int(audit["relocation"]["pivot"]),
            int(audit["relocation"]["delta"]),
        )
        patches = {
            int(row["source_instruction_start"]): row
            for row in audit["target_patches"]
        }
        instructions = []
        opaque_boundaries = []

        def append_node(node: dict, start: int, end: int) -> None:
            source = node["source"]
            raw = code[start:end]
            if node["kind"] == "opaque":
                opaque_boundaries.append({
                    "source_offset": start, "end_offset": end,
                    "raw_hex": raw.hex(),
                    "raw_sha256": hashlib.sha256(raw).hexdigest(),
                    "region": MesControlBodySemanticDiffTests._region(entries, start),
                    "boundary": node["statement"]["boundary"],
                    **copy.deepcopy(node["statement"]["details"]),
                })
                return
            statement = node["statement"]
            operands = copy.deepcopy(statement["operands"])
            patch = patches.get(int(source["start"]))
            if patch is not None:
                for operand in operands:
                    if operand.get("type") == "code_offset":
                        operand["value"] = int(patch["output_target_offset"])
            instructions.append({
                "ok": True,
                "schema": handoff_validator.COMPONENT_SCHEMAS["instruction"],
                "source_offset": start, "end_offset": end,
                "byte_length": end - start, "raw_hex": raw.hex(),
                "region": MesControlBodySemanticDiffTests._region(entries, start),
                "op": statement["op"], "command_id": statement["command_id"],
                "operands": operands,
                **copy.deepcopy(statement["metadata"]),
            })

        source_start, source_end = (
            int(operation["source_start"]), int(operation["source_end"]),
        )
        for node in source_ir["nodes"]:
            start, end = int(node["source"]["start"]), int(node["source"]["end"])
            if operation["kind"] == "remove_typed_body" and source_start <= start < source_end:
                continue
            output_start = start + (delta if start >= pivot else 0)
            append_node(node, output_start, output_start + end - start)
        if operation["kind"] == "insert_typed_body_copy":
            insert_start = int(operation["output_start"])
            for node in source_ir["nodes"]:
                start, end = int(node["source"]["start"]), int(node["source"]["end"])
                if source_start <= start < source_end:
                    output_start = insert_start + start - source_start
                    append_node(node, output_start, output_start + end - start)
        instructions.sort(key=lambda row: row["source_offset"])
        opaque_boundaries.sort(key=lambda row: row["source_offset"])

        references = {"messages": [], "code": [], "state": [], "resources": []}
        patches_by_id = {row["reference_id"]: row for row in audit["target_patches"]}
        for reference in source_ir["references"]:
            value = copy.deepcopy(reference["value"])
            start = int(value["source_offset"])
            value["source_offset"] = start + (delta if start >= pivot else 0)
            patch = patches_by_id.get(reference["id"])
            if patch is not None:
                value["source_offset"] = int(patch["output_instruction_start"])
                value["target_offset"] = int(patch["output_target_offset"])
                value["target_region"] = MesControlBodySemanticDiffTests._region(
                    entries, int(value["target_offset"])
                )
            references[reference["kind"]].append(value)
        handoff = {
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
            "source_identity": copy.deepcopy(source_ir["source_identity"]),
            "container": {
                "schema": "ai5_mes_container/v1",
                "header": {"code_offset": code_offset, "code_size": len(code)},
                "bootstrap": {
                    "offset": int(bootstrap_region["source_start"]),
                    "end_offset": int(bootstrap_region["source_end"]),
                    "size": int(bootstrap_region["source_end"])
                    - int(bootstrap_region["source_start"]),
                },
                "entries": entries,
                "entry_sha256": hashlib.sha256(output).hexdigest(),
                "bytecode_sha256": hashlib.sha256(code).hexdigest(),
                "raw_hex": output.hex(),
            },
            "record_alignment": {"schema": "kakyu_mes_record_alignment_audit/v1"},
            "typed_ir": {
                "schema": "kakyu_mes_analysis/v19", "complete": True,
                "instructions": instructions, "diagnostics": [],
                "opaque_boundaries": opaque_boundaries,
            },
            "references": references,
            "cfg": [], "calls": [], "traces": [],
        }
        handoff["payload_sha256"] = handoff_validator.fingerprint(handoff)
        handoff_validator.validate(handoff)
        return handoff

    @staticmethod
    def _region(entries: list[dict], offset: int) -> str:
        for entry in entries:
            if int(entry["offset"]) <= offset < int(entry["end_offset"]):
                return str(entry["id"])
        raise AssertionError(f"no output region for code offset {offset}")


if __name__ == "__main__":
    unittest.main()
