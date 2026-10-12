from __future__ import annotations

import copy
import hashlib
import sys
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

import decompile_mes_handoff as decompiler  # noqa: E402
import plan_mes_inline_script_name_edit as planner  # noqa: E402
import prepare_mes_editable_ir as editable_ir  # noqa: E402
import validate_mes_analyzer_handoff as handoff_validator  # noqa: E402


class MesInlineScriptNameEditPlanTests(unittest.TestCase):
    def fixture(
        self,
        *,
        selector: int = 2,
        source_name: str = "liblary.lib",
        replacement_name: str = "libxary.lib",
        typed: bool = False,
    ) -> tuple[dict, dict]:
        roles = {2: "library_bootstrap", 3: "definition_bootstrap"}
        envelope = bytes.fromhex("0d08ff02") + bytes([selector]) + bytes.fromhex("ff01")
        envelope += source_name.encode("ascii") + b"\x00\x00"
        prefix = b"\x00\x13" if not typed else b""
        suffix = b"\x19\x00" if not typed else b""
        code = prefix + envelope + suffix
        source_offset = len(prefix)
        preamble = (1).to_bytes(4, "little") + (0).to_bytes(4, "little")
        raw = preamble + code
        instruction = {
            "ok": True,
            "schema": handoff_validator.COMPONENT_SCHEMAS["instruction"],
            "source_offset": source_offset,
            "end_offset": source_offset + len(envelope),
            "byte_length": len(envelope),
            "raw_hex": envelope.hex(),
            "region": "entry_0000",
            "op": "inline_script_execution",
            "command_id": 0x0D,
            "operands": [{
                "type": "resource_name",
                "resource_kind": "mes_script",
                "name": source_name.upper(),
                "source_name": source_name,
                "raw_bytes": {
                    "$packed_byte_array_hex": source_name.encode("ascii").hex()
                },
                "raw_hex": source_name.encode("ascii").hex(),
                "source_offset": source_offset + 7,
                "presentation_subcommand": 8,
                "execution_selector": selector,
                "execution_role": roles[selector],
                "native_consumer_semantics": planner.NATIVE_SEMANTICS,
                "native_context_restore": "confirmed",
                "tool_execution_semantics": "not_executed",
            }],
        }
        resource_reference = {
            "source_offset": source_offset,
            "region": "entry_0000",
            "op": "inline_script_execution",
            "resource_kind": "mes_script",
            "name": source_name.upper(),
            "source_name": source_name,
            "archive_candidates": ["mes.arc"],
            "boundary": "strict_indexed" if typed else "bounded_envelope_scan",
            "presentation_subcommand": 8,
            "execution_selector": selector,
            "execution_role": roles[selector],
            "native_semantics": planner.NATIVE_SEMANTICS,
            "native_context_restore": "confirmed",
            "tool_execution_semantics": "not_executed",
        }
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
                "archive": "mes.arc",
                "entry": "START.MES",
                "source_kind": "original_arc",
                "archive_sha256": "a" * 64,
            },
            "container": {
                "schema": handoff_validator.COMPONENT_SCHEMAS["container"],
                "header": {"code_offset": len(preamble), "code_size": len(code)},
                "bootstrap": {"offset": 0, "end_offset": 0, "size": 0},
                "entries": [{
                    "id": "entry_0000", "index": 0, "offset": 0,
                    "end_offset": len(code), "size": len(code),
                }],
                "entry_sha256": hashlib.sha256(raw).hexdigest(),
                "bytecode_sha256": hashlib.sha256(code).hexdigest(),
                "raw_hex": raw.hex(),
            },
            "record_alignment": {
                "schema": handoff_validator.COMPONENT_SCHEMAS["record_alignment"]
            },
            "typed_ir": {
                "schema": handoff_validator.COMPONENT_SCHEMAS["analysis"],
                "complete": True,
                "instructions": [instruction] if typed else [],
                "diagnostics": [],
                "opaque_boundaries": [] if typed else [{
                    "source_offset": 0,
                    "end_offset": len(code),
                    "raw_hex": code.hex(),
                    "raw_sha256": hashlib.sha256(code).hexdigest(),
                    "region": "entry_0000",
                    "boundary": "byte_preserving_fail_closed",
                }],
            },
            "references": {
                "messages": [], "code": [], "state": [],
                "resources": [resource_reference],
            },
            "cfg": [], "calls": [], "traces": [],
            "capability_report": {"product_ui_data": "forbidden"},
        }
        handoff["payload_sha256"] = handoff_validator.fingerprint(handoff)
        document = editable_ir.prepare(decompiler.lift(handoff))
        owner = document["source_ir"]["nodes"][0]
        operation = {
            "kind": "replace_inline_script_name",
            "source_offset": source_offset,
            "owner_raw_sha256": owner["source"]["raw_sha256"],
            "reference_id": "resource_00000000",
            "name": replacement_name,
        }
        return document, operation

    def test_plans_bounded_library_name_inside_opaque_owner(self) -> None:
        editable, operation = self.fixture()
        document = planner.plan(editable, operation)

        self.assertEqual(planner.PLAN_SCHEMA, document["schema"])
        self.assertEqual("opaque", document["target"]["owner_kind"])
        self.assertEqual("bounded_envelope_scan", document["target"]["reference_boundary"])
        self.assertEqual(2, document["target"]["execution_selector"])
        self.assertEqual("library_bootstrap", document["target"]["execution_role"])
        self.assertEqual("0d08ff0202ff01", document["target"]["prefix_raw_hex"])
        self.assertEqual("0000", document["target"]["suffix_raw_hex"])
        self.assertTrue(document["assembly_ready"])

    def test_plans_typed_definition_name(self) -> None:
        editable, operation = self.fixture(
            selector=3,
            source_name="def_main.mes",
            replacement_name="synthzzz.mes",
            typed=True,
        )
        document = planner.plan(editable, operation)

        self.assertEqual("statement", document["target"]["owner_kind"])
        self.assertEqual("strict_indexed", document["target"]["reference_boundary"])
        self.assertEqual("definition_bootstrap", document["target"]["execution_role"])
        self.assertEqual("SYNTHZZZ.MES", document["replacement"]["normalized_name"])

    def test_identical_source_and_operation_are_deterministic(self) -> None:
        editable, operation = self.fixture()
        self.assertEqual(
            planner.plan(editable, operation),
            planner.plan(copy.deepcopy(editable), copy.deepcopy(operation)),
        )

    def test_rejects_stale_owner_hash(self) -> None:
        editable, operation = self.fixture()
        operation["owner_raw_sha256"] = "0" * 64
        with self.assertRaisesRegex(planner.InlineScriptNameEditPlanError, "hash is stale"):
            planner.plan(editable, operation)

    def test_rejects_changed_name_length(self) -> None:
        editable, operation = self.fixture()
        operation["name"] = "longer_name.lib"
        with self.assertRaisesRegex(planner.InlineScriptNameEditPlanError, "changes name length"):
            planner.plan(editable, operation)

    def test_rejects_selector_extension_change(self) -> None:
        editable, operation = self.fixture()
        operation["name"] = "libxary.mes"
        with self.assertRaisesRegex(planner.InlineScriptNameEditPlanError, "extension"):
            planner.plan(editable, operation)

    def test_rejects_opaque_owner_with_strict_reference(self) -> None:
        editable, operation = self.fixture()
        editable["source_ir"]["references"][0]["value"]["boundary"] = "strict_indexed"
        editable["source_ir"]["payload_sha256"] = decompiler.fingerprint(editable["source_ir"])
        editable["payload_sha256"] = editable_ir.fingerprint(editable)
        with self.assertRaisesRegex(planner.InlineScriptNameEditPlanError, "boundary differ"):
            planner.plan(editable, operation)

    def test_rejects_unknown_operation_field(self) -> None:
        editable, operation = self.fixture()
        operation["ignored"] = True
        with self.assertRaisesRegex(planner.InlineScriptNameEditPlanError, "operation fields"):
            planner.plan(editable, operation)

    def test_standalone_validation_rejects_selector_mutation(self) -> None:
        editable, operation = self.fixture()
        document = planner.plan(editable, operation)
        prefix = bytearray.fromhex(document["target"]["prefix_raw_hex"])
        prefix[4] = 3
        source_name = bytes.fromhex(document["target"]["name_raw_hex"])
        suffix = bytes.fromhex(document["target"]["suffix_raw_hex"])
        replacement_name = bytes.fromhex(document["replacement"]["name_raw_hex"])
        source_envelope = bytes(prefix) + source_name + suffix
        output_envelope = bytes(prefix) + replacement_name + suffix
        document["target"]["prefix_raw_hex"] = bytes(prefix).hex()
        document["target"]["prefix_raw_sha256"] = hashlib.sha256(prefix).hexdigest()
        document["target"]["envelope_raw_hex"] = source_envelope.hex()
        document["target"]["envelope_raw_sha256"] = hashlib.sha256(source_envelope).hexdigest()
        document["replacement"]["envelope_raw_hex"] = output_envelope.hex()
        document["replacement"]["envelope_raw_sha256"] = hashlib.sha256(output_envelope).hexdigest()
        document["payload_sha256"] = planner.fingerprint(document)
        with self.assertRaisesRegex(planner.InlineScriptNameEditPlanError, "boundary"):
            planner.validate(document)

    def test_rejects_rehashed_plan_that_differs_from_source(self) -> None:
        editable, operation = self.fixture()
        document = planner.plan(editable, operation)
        document["source_identity"]["entry"] = "OTHER.MES"
        document["payload_sha256"] = planner.fingerprint(document)
        with self.assertRaisesRegex(planner.InlineScriptNameEditPlanError, "differs from its source"):
            planner.validate(document, editable)


if __name__ == "__main__":
    unittest.main()
