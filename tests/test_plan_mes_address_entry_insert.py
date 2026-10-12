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
import plan_mes_address_entry_insert as planner  # noqa: E402
import prepare_mes_editable_ir as editable_ir  # noqa: E402
import validate_mes_analyzer_handoff as handoff_validator  # noqa: E402
from tests import test_plan_mes_message_relocation as message_tests  # noqa: E402


class MesAddressEntryInsertPlanTests(unittest.TestCase):
    def fixture(self) -> tuple[dict, dict]:
        preamble = (
            (2).to_bytes(4, "little")
            + (0).to_bytes(4, "little")
            + (2).to_bytes(4, "little")
        )
        code = bytes.fromhex("000000")
        raw = preamble + code
        instructions = [
            message_tests.MesMessageRelocationPlanTests._instruction(
                0, 1, "00", "entry_0000", "command_00", 0, []
            ),
            message_tests.MesMessageRelocationPlanTests._instruction(
                1, 2, "00", "entry_0000", "command_00", 0, []
            ),
            message_tests.MesMessageRelocationPlanTests._instruction(
                2, 3, "00", "entry_0001", "command_00", 0, []
            ),
        ]
        handoff = {
            "ok": True,
            "schema": handoff_validator.HANDOFF_SCHEMA,
            "producer": {
                "implementation": "test",
                "contract": handoff_validator.HANDOFF_SCHEMA,
            },
            "compatibility": {
                "policy": "exact_component_schema_match",
                "component_schemas": {
                    **handoff_validator.COMPONENT_SCHEMAS,
                    "accepted_call_evidence": handoff_validator.CALL_EVIDENCE_SCHEMAS,
                    "accepted_trace_evidence": handoff_validator.TRACE_EVIDENCE_SCHEMAS,
                },
            },
            "source_identity": {
                "archive": "mes.arc",
                "entry": "ENTRY_INSERT.MES",
                "source_kind": "original_arc",
                "archive_sha256": "a" * 64,
            },
            "container": {
                "schema": "ai5_mes_container/v1",
                "header": {"code_offset": len(preamble), "code_size": len(code)},
                "bootstrap": {"offset": 0, "end_offset": 0, "size": 0},
                "entries": [
                    {"id": "entry_0000", "index": 0, "offset": 0, "end_offset": 2, "size": 2},
                    {"id": "entry_0001", "index": 1, "offset": 2, "end_offset": 3, "size": 1},
                ],
                "entry_sha256": hashlib.sha256(raw).hexdigest(),
                "bytecode_sha256": hashlib.sha256(code).hexdigest(),
                "raw_hex": raw.hex(),
            },
            "record_alignment": {"schema": "kakyu_mes_record_alignment_audit/v1"},
            "typed_ir": {
                "schema": "kakyu_mes_analysis/v19",
                "complete": True,
                "instructions": instructions,
                "diagnostics": [],
                "opaque_boundaries": [],
            },
            "references": {
                "messages": [],
                "code": [],
                "state": [],
                "resources": [],
            },
            "cfg": [],
            "calls": [],
            "traces": [],
        }
        handoff["payload_sha256"] = handoff_validator.fingerprint(handoff)
        document = editable_ir.prepare(decompiler.lift(handoff))
        operation = {
            "kind": "insert_address_entry",
            "owner_entry_index": 0,
            "target_offset": 1,
            "instruction_raw_sha256": hashlib.sha256(b"\x00").hexdigest(),
        }
        return document, operation

    def test_plans_strict_typed_address_entry_insertion(self) -> None:
        document, operation = self.fixture()
        result = planner.plan(document, operation)

        self.assertTrue(result["assembly_ready"])
        self.assertEqual((2, 3), (
            result["table_change"]["source_entry_count"],
            result["table_change"]["output_entry_count"],
        ))
        self.assertEqual(1, result["table_change"]["insertion_index"])
        self.assertEqual("01000000", result["table_change"]["inserted_raw_hex"])
        self.assertEqual((12, 16), (
            result["table_change"]["source_code_offset"],
            result["table_change"]["output_code_offset"],
        ))
        self.assertEqual((1, 0), (
            result["coverage"]["moved_node_count"],
            result["coverage"]["moved_reference_count"],
        ))

    def test_plan_is_deterministic_and_json_validated(self) -> None:
        document, operation = self.fixture()
        first = planner.plan(document, operation)
        second = planner.plan(copy.deepcopy(document), copy.deepcopy(operation))
        transported = json.loads(json.dumps(first, ensure_ascii=False))

        self.assertEqual(first, second)
        self.assertEqual(first, transported)
        self.assertEqual(first["payload_sha256"], planner.fingerprint(first))
        planner.validate(transported, document)

    def test_rejects_existing_entry_boundary_and_wrong_owner(self) -> None:
        document, operation = self.fixture()
        existing = copy.deepcopy(operation)
        existing["owner_entry_index"] = 1
        existing["target_offset"] = 2
        with self.assertRaisesRegex(planner.AddressEntryInsertPlanError, "strictly inside"):
            planner.plan(document, existing)
        wrong_owner = copy.deepcopy(operation)
        wrong_owner["owner_entry_index"] = 1
        with self.assertRaisesRegex(planner.AddressEntryInsertPlanError, "strictly inside"):
            planner.plan(document, wrong_owner)

    def test_rejects_unaligned_target_and_stale_hash(self) -> None:
        document, operation = self.fixture()
        unaligned = copy.deepcopy(operation)
        unaligned["target_offset"] = 0
        with self.assertRaisesRegex(planner.AddressEntryInsertPlanError, "strictly inside"):
            planner.plan(document, unaligned)
        stale = copy.deepcopy(operation)
        stale["instruction_raw_sha256"] = "0" * 64
        with self.assertRaisesRegex(planner.AddressEntryInsertPlanError, "stale"):
            planner.plan(document, stale)

    def test_rejects_structural_only_target(self) -> None:
        document, operation = self.fixture()
        source_ir = document["source_ir"]
        target = next(
            node for node in source_ir["nodes"]
            if node["source"]["start"] == operation["target_offset"]
        )
        target["statement"]["metadata"] = {"structural_only": True}
        source_ir["payload_sha256"] = decompiler.fingerprint(source_ir)
        document["payload_sha256"] = editable_ir.fingerprint(document)

        with self.assertRaisesRegex(planner.AddressEntryInsertPlanError, "strict typed"):
            planner.plan(document, operation)

    def test_rejects_changed_plan_and_unknown_fields(self) -> None:
        document, operation = self.fixture()
        result = planner.plan(document, operation)
        changed = copy.deepcopy(result)
        changed["table_change"]["inserted_raw_hex"] = "02000000"
        changed["payload_sha256"] = planner.fingerprint(changed)
        with self.assertRaisesRegex(planner.AddressEntryInsertPlanError, "differs"):
            planner.validate(changed, document)
        unknown = copy.deepcopy(result)
        unknown["ignored"] = True
        unknown["payload_sha256"] = planner.fingerprint(unknown)
        with self.assertRaisesRegex(planner.AddressEntryInsertPlanError, "fields"):
            planner.validate(unknown, document)

    def test_cli_publishes_only_to_a_new_output(self) -> None:
        document, operation = self.fixture()
        with tempfile.TemporaryDirectory() as raw_directory:
            root = Path(raw_directory)
            editable_path = root / "editable.json"
            operation_path = root / "operation.json"
            output_path = root / "plan.json"
            editable_path.write_text(json.dumps(document), encoding="utf-8")
            operation_path.write_text(json.dumps(operation), encoding="utf-8")
            command = [
                sys.executable,
                str(ROOT / "tools" / "plan_mes_address_entry_insert.py"),
                str(editable_path),
                str(operation_path),
                str(output_path),
            ]
            completed = subprocess.run(command, check=False, capture_output=True, text=True)
            self.assertEqual(0, completed.returncode, completed.stderr)
            self.assertIn("MES_ADDRESS_ENTRY_INSERT_PLAN_PASS", completed.stdout)
            self.assertTrue(output_path.is_file())
            refused = subprocess.run(command, check=False, capture_output=True, text=True)
            self.assertNotEqual(0, refused.returncode)
            self.assertEqual(
                planner.plan(document, operation),
                json.loads(output_path.read_text("utf-8")),
            )


if __name__ == "__main__":
    unittest.main()
