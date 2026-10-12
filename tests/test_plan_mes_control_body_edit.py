from __future__ import annotations

import copy
import hashlib
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
sys.path.insert(0, str(ROOT / "tools"))

import decompile_mes_handoff as decompiler  # noqa: E402
import plan_mes_control_body_edit as planner  # noqa: E402
import prepare_mes_editable_ir as editable_ir  # noqa: E402
import validate_mes_analyzer_handoff as handoff_validator  # noqa: E402
from tests import test_plan_mes_message_relocation as message_tests  # noqa: E402


class MesControlBodyEditPlanTests(unittest.TestCase):
    def fixture(
        self, target_offset: int = 21, opaque_head: bool = False
    ) -> tuple[dict, dict, dict]:
        code = bytes.fromhex(
            "00"          # 0x00 command_00
            "1f01000000"  # 0x01 donor source-line marker
            "1f02000000"  # 0x06 insertion anchor
            "0c15000000"  # 0x0B continuation to 0x15
            "1f03000000"  # 0x10 following marker
            "00"          # 0x15 second entry
        )
        mutable = bytearray(code)
        mutable[12:16] = target_offset.to_bytes(4, "little")
        code = bytes(mutable)
        preamble = (2).to_bytes(4, "little") + (0).to_bytes(4, "little") + (21).to_bytes(4, "little")
        raw = preamble + code
        instruction = message_tests.MesMessageRelocationPlanTests._instruction
        instructions = [
            instruction(0, 1, code[0:1].hex(), "entry_0000", "command_00", 0, [], {}),
            instruction(1, 6, code[1:6].hex(), "entry_0000", "source_line_marker", 0x1F,
                        [{"type": "source_line", "value": 1}], {}),
            instruction(6, 11, code[6:11].hex(), "entry_0000", "source_line_marker", 0x1F,
                        [{"type": "source_line", "value": 2}], {}),
            instruction(11, 16, code[11:16].hex(), "entry_0000", "continuation_transfer", 0x0C,
                        [{"type": "code_offset", "value": target_offset}], {}),
            instruction(16, 21, code[16:21].hex(), "entry_0000", "source_line_marker", 0x1F,
                        [{"type": "source_line", "value": 3}], {}),
            instruction(21, 22, code[21:22].hex(), "entry_0001", "command_00", 0, [], {}),
        ]
        opaque_boundaries = []
        if opaque_head:
            instructions = instructions[1:]
            opaque_boundaries = [{
                "source_offset": 0,
                "end_offset": 1,
                "raw_hex": code[0:1].hex(),
                "raw_sha256": hashlib.sha256(code[0:1]).hexdigest(),
                "region": "entry_0000",
                "boundary": "byte_preserving_fail_closed",
                "reason": "synthetic unrelated unresolved head",
            }]
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
            "source_identity": {
                "archive": "mes.arc", "entry": "CONTROL_BODY.MES",
                "source_kind": "original_arc", "archive_sha256": "a" * 64,
            },
            "container": {
                "schema": "ai5_mes_container/v1",
                "header": {"code_offset": len(preamble), "code_size": len(code)},
                "bootstrap": {"offset": 0, "end_offset": 0, "size": 0},
                "entries": [
                    {"id": "entry_0000", "index": 0, "offset": 0, "end_offset": 21, "size": 21},
                    {"id": "entry_0001", "index": 1, "offset": 21, "end_offset": 22, "size": 1},
                ],
                "entry_sha256": hashlib.sha256(raw).hexdigest(),
                "bytecode_sha256": hashlib.sha256(code).hexdigest(),
                "raw_hex": raw.hex(),
            },
            "record_alignment": {"schema": "kakyu_mes_record_alignment_audit/v1"},
            "typed_ir": {
                "schema": "kakyu_mes_analysis/v19", "complete": True,
                "instructions": instructions, "diagnostics": [],
                "opaque_boundaries": opaque_boundaries,
            },
            "references": {
                "messages": [],
                "code": [{
                    "source_offset": 11, "op": "continuation_transfer",
                    "kind": "continuation_target", "target_offset": target_offset,
                    "in_code": True, "aligned": True,
                    "target_region": "entry_0000" if target_offset < 21 else "entry_0001",
                }],
                "state": [], "resources": [],
            },
            "cfg": [], "calls": [], "traces": [],
        }
        handoff["payload_sha256"] = handoff_validator.fingerprint(handoff)
        document = editable_ir.prepare(decompiler.lift(handoff))
        donor_hash = hashlib.sha256(code[1:6]).hexdigest()
        anchor_node = next(row for row in document["source_ir"]["nodes"] if row["source"]["start"] == 6)
        insert = {
            "kind": "insert_typed_body_copy",
            "anchor_offset": 6,
            "anchor_instruction_raw_sha256": anchor_node["source"]["raw_sha256"],
            "donor_start": 1,
            "donor_end": 6,
            "donor_span_raw_sha256": donor_hash,
        }
        remove = {
            "kind": "remove_typed_body",
            "body_start": 1,
            "body_end": 6,
            "body_span_raw_sha256": donor_hash,
        }
        return document, insert, remove

    def test_plans_exact_typed_body_copy_insertion(self) -> None:
        document, operation, _ = self.fixture()
        result = planner.plan(document, operation)

        self.assertTrue(result["assembly_ready"])
        self.assertEqual((5, 6, 22, 27), (
            result["relocation"]["delta"], result["relocation"]["pivot"],
            result["relocation"]["source_code_size"], result["relocation"]["output_code_size"],
        ))
        self.assertEqual([{"index": 1, "source_offset": 21, "output_offset": 26}], result["address_table_updates"])
        self.assertEqual(("linear_00000001", "linear_00000006", 6, 11), (
            result["body"]["inserted_node_map"][0]["source_node_id"],
            result["body"]["inserted_node_map"][0]["output_node_id"],
            result["body"]["output_start"], result["body"]["output_end"],
        ))
        anchor = next(row for row in result["node_map"] if row["source_start"] == 6)
        self.assertEqual((11, 16, "linear_0000000b"), (
            anchor["output_start"], anchor["output_end"], anchor["output_node_id"],
        ))
        self.assertEqual(("15000000", "1a000000"), (
            result["target_patches"][0]["source_raw_hex"],
            result["target_patches"][0]["output_raw_hex"],
        ))

    def test_plans_exact_typed_body_removal(self) -> None:
        document, _, operation = self.fixture()
        result = planner.plan(document, operation)

        self.assertTrue(result["assembly_ready"])
        self.assertEqual((-5, 6, 17), (
            result["relocation"]["delta"], result["relocation"]["pivot"],
            result["relocation"]["output_code_size"],
        ))
        removed = next(row for row in result["node_map"] if row["source_start"] == 1)
        self.assertEqual(("removed", "", -1, -1), (
            removed["status"], removed["output_node_id"],
            removed["output_start"], removed["output_end"],
        ))
        self.assertEqual(("15000000", "10000000"), (
            result["target_patches"][0]["source_raw_hex"],
            result["target_patches"][0]["output_raw_hex"],
        ))

    def test_plan_is_deterministic_and_survives_json(self) -> None:
        document, operation, _ = self.fixture()
        first = planner.plan(document, operation)
        second = planner.plan(copy.deepcopy(document), copy.deepcopy(operation))
        transported = json.loads(json.dumps(first))

        self.assertEqual(first, second)
        self.assertEqual(first, transported)
        planner.validate(transported, document)

    def test_rejects_stale_noncontiguous_and_entry_boundary_spans(self) -> None:
        document, operation, remove = self.fixture()
        stale = copy.deepcopy(operation)
        stale["donor_span_raw_sha256"] = "0" * 64
        with self.assertRaisesRegex(planner.ControlBodyEditPlanError, "stale"):
            planner.plan(document, stale)
        noncontiguous = copy.deepcopy(remove)
        noncontiguous["body_end"] = 5
        noncontiguous["body_span_raw_sha256"] = hashlib.sha256(bytes.fromhex("1f010000")).hexdigest()
        with self.assertRaisesRegex(planner.ControlBodyEditPlanError, "contiguous|boundary"):
            planner.plan(document, noncontiguous)
        entry_boundary = copy.deepcopy(remove)
        entry_boundary["body_start"] = 0
        entry_boundary["body_span_raw_sha256"] = hashlib.sha256(bytes.fromhex("001f01000000")).hexdigest()
        with self.assertRaisesRegex(planner.ControlBodyEditPlanError, "strictly inside"):
            planner.plan(document, entry_boundary)

    def test_fail_closed_for_incoming_anchor_and_owned_reference(self) -> None:
        document, operation, _ = self.fixture(target_offset=6)
        result = planner.plan(document, operation)
        self.assertFalse(result["assembly_ready"])
        self.assertIn("incoming_target_at_insert_anchor", {row["code"] for row in result["blockers"]})

        document, _, _ = self.fixture()
        continuation = next(row for row in document["source_ir"]["nodes"] if row["source"]["start"] == 11)
        remove_control = {
            "kind": "remove_typed_body",
            "body_start": 11,
            "body_end": 16,
            "body_span_raw_sha256": continuation["source"]["raw_sha256"],
        }
        blocked = planner.plan(document, remove_control)
        codes = {row["code"] for row in blocked["blockers"]}
        self.assertFalse(blocked["assembly_ready"])
        self.assertIn("body_owns_references", codes)
        self.assertIn("reference_source_inside_removed_body", codes)

    def test_rejects_unknown_fields_fractional_coordinates_and_stale_plan(self) -> None:
        document, operation, _ = self.fixture()
        unknown = copy.deepcopy(operation)
        unknown["ignored"] = True
        with self.assertRaisesRegex(planner.ControlBodyEditPlanError, "unsupported"):
            planner.plan(document, unknown)
        fractional = copy.deepcopy(operation)
        fractional["anchor_offset"] = 6.5
        with self.assertRaisesRegex(planner.ControlBodyEditPlanError, "coordinate"):
            planner.plan(document, fractional)
        result = planner.plan(document, operation)
        result["payload_sha256"] = "0" * 64
        with self.assertRaisesRegex(planner.ControlBodyEditPlanError, "fingerprint"):
            planner.validate(result)

    def test_cli_publishes_one_json_plan_exclusively(self) -> None:
        document, operation, _ = self.fixture()
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            editable_path = root / "editable.json"
            operation_path = root / "operation.json"
            output_path = root / "plan.json"
            editable_path.write_text(json.dumps(document), encoding="utf-8")
            operation_path.write_text(json.dumps(operation), encoding="utf-8")
            completed = subprocess.run(
                [sys.executable, str(ROOT / "tools" / "plan_mes_control_body_edit.py"),
                 str(editable_path), str(operation_path), str(output_path)],
                check=True, capture_output=True, text=True,
            )
            self.assertIn("MES_CONTROL_BODY_EDIT_PLAN_PASS", completed.stdout)
            planner.validate(json.loads(output_path.read_text(encoding="utf-8")), document)
            repeated = subprocess.run(
                [sys.executable, str(ROOT / "tools" / "plan_mes_control_body_edit.py"),
                 str(editable_path), str(operation_path), str(output_path)],
                capture_output=True, text=True,
            )
            self.assertNotEqual(0, repeated.returncode)
            self.assertIn("already exists", repeated.stderr)


if __name__ == "__main__":
    unittest.main()
