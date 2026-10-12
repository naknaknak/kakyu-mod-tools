from __future__ import annotations

import copy
import hashlib
import sys
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

import compile_mes_condition_literal_edit as condition_compiler  # noqa: E402
import compile_mes_control_target_edit as control_target_compiler  # noqa: E402
import compile_mes_choice_option_edit as choice_compiler  # noqa: E402
import compile_mes_inline_script_name_edit as inline_compiler  # noqa: E402
import compile_mes_noop as noop_compiler  # noqa: E402
import compile_mes_registered_definition_call_edit as registered_call_compiler  # noqa: E402
import compile_mes_resource_name_edit as resource_compiler  # noqa: E402
import compile_mes_shared_routine_call_edit as shared_call_compiler  # noqa: E402
import compile_mes_state_literal_edit as state_compiler  # noqa: E402
import diff_mes_byte_patch_semantics as semantic_diff  # noqa: E402
import decompile_mes_handoff as decompiler  # noqa: E402
import plan_mes_choice_option_edit as choice_planner  # noqa: E402
import prepare_mes_editable_ir as editable_ir  # noqa: E402
import validate_mes_analyzer_handoff as handoff_validator  # noqa: E402
from tests.test_compile_mes_condition_literal_edit import MesConditionLiteralCompilerTests  # noqa: E402
from tests.test_compile_mes_control_target_edit import MesControlTargetEditCompilerTests  # noqa: E402
from tests.test_compile_mes_inline_script_name_edit import MesInlineScriptNameCompilerTests  # noqa: E402
from tests.test_compile_mes_registered_definition_call_edit import MesRegisteredDefinitionCallCompileTests  # noqa: E402
from tests.test_compile_mes_resource_name_edit import MesResourceNameCompilerTests  # noqa: E402
from tests.test_compile_mes_shared_routine_call_edit import MesSharedRoutineCallCompileTests  # noqa: E402
from tests.test_compile_mes_state_literal_edit import MesStateLiteralCompilerTests  # noqa: E402
from tests.test_plan_mes_choice_option_edit import _plan_fixture as choice_plan_fixture  # noqa: E402


class MesBytePatchSemanticDiffTests(unittest.TestCase):
    def fixture(self, family: str) -> tuple[dict, dict, dict]:
        if family == "choice":
            source, proof, operation = choice_plan_fixture()
            plan = choice_planner.plan(source, proof, operation)
            output, audit = choice_compiler.compile_choice_option(source, proof, plan)
            editable = self._choice_editable(source, proof)
        elif family == "shared_call":
            editable, proof, library, plan = MesSharedRoutineCallCompileTests().fixture()
            output, audit = shared_call_compiler.compile_shared_routine_call(
                editable, proof, library, plan
            )
        elif family == "registered_call":
            editable, call_family, registry, plan = MesRegisteredDefinitionCallCompileTests().fixture()
            output, audit = registered_call_compiler.compile_registered_definition_call(
                editable, call_family, registry, plan
            )
        elif family == "control_target":
            editable, plan = MesControlTargetEditCompilerTests().fixture()
            output, audit = control_target_compiler.compile_target_edit(editable, plan)
        else:
            cases = {
                "state": (MesStateLiteralCompilerTests, state_compiler.compile_state_literal),
                "condition": (MesConditionLiteralCompilerTests, condition_compiler.compile_condition_literal),
                "resource": (MesResourceNameCompilerTests, resource_compiler.compile_resource_name),
                "inline": (MesInlineScriptNameCompilerTests, inline_compiler.compile_inline_script_name),
            }
            test_class, compile_function = cases[family]
            editable, plan = test_class().fixture()
            output, audit = compile_function(editable, plan)
        return editable, audit, self._output_handoff(editable, output, audit)

    def test_covers_all_initial_same_layout_families(self) -> None:
        expected = {
            "state": ("state_literal_edit", "statement"),
            "condition": ("condition_literal_edit", "statement"),
            "resource": ("resource_name_edit", "statement"),
            "inline": ("inline_script_name_edit", "opaque"),
            "shared_call": ("shared_routine_call_edit", "statement"),
            "registered_call": ("registered_definition_call_edit", "statement"),
            "control_target": ("control_target_edit", "statement"),
            "choice": ("choice_option_edit", "statement"),
        }
        for name, (family, owner_kind) in expected.items():
            with self.subTest(name=name):
                editable, audit, handoff = self.fixture(name)
                result = semantic_diff.build(editable, audit, handoff)
                self.assertEqual(family, result["operation"]["family"])
                self.assertEqual(owner_kind, result["semantic_changes"]["patch"]["owner_kind"])
                self.assertEqual(1, result["node_diff"]["patched_node_count"])
                self.assertTrue(result["semantic_changes"]["assertion"]["verified"])
                semantic_diff.validate(copy.deepcopy(result), editable, audit, handoff)

    def test_distinguishes_intended_opaque_patch_from_unrelated_opaque(self) -> None:
        editable, audit, handoff = self.fixture("inline")
        result = semantic_diff.build(editable, audit, handoff)

        self.assertEqual((1, 1, 0, 1), (
            result["preservation"]["source_opaque_node_count"],
            result["preservation"]["output_opaque_node_count"],
            result["preservation"]["exact_opaque_node_count"],
            result["preservation"]["patched_opaque_node_count"],
        ))
        self.assertEqual(
            "bounded_envelope_scan",
            result["semantic_changes"]["assertion"]["reference_boundary"],
        )

    def test_binds_call_literals_and_explicit_control_target(self) -> None:
        for name, source_key, output_key in (
            ("shared_call", "source_routine_id", "replacement_routine_id"),
            ("registered_call", "source_selector", "replacement_selector"),
        ):
            with self.subTest(name=name):
                editable, audit, handoff = self.fixture(name)
                result = semantic_diff.build(editable, audit, handoff)
                assertion = result["semantic_changes"]["assertion"]
                self.assertEqual("literal_value", assertion["kind"])
                self.assertEqual(audit["operation"][source_key], assertion["source_value"])
                self.assertEqual(audit["operation"][output_key], assertion["output_value"])

        editable, audit, handoff = self.fixture("control_target")
        result = semantic_diff.build(editable, audit, handoff)
        assertion = result["semantic_changes"]["assertion"]
        self.assertEqual("code_reference_target", assertion["kind"])
        self.assertEqual(audit["source_control"]["reference_id"], assertion["reference_id"])
        self.assertEqual(
            audit["operation"]["replacement_target_offset"], assertion["output_value"]
        )

        editable, audit, handoff = self.fixture("choice")
        result = semantic_diff.build(editable, audit, handoff)
        assertion = result["semantic_changes"]["assertion"]
        self.assertEqual("choice_option_cp932_payload", assertion["kind"])
        self.assertEqual(audit["patch"]["source_payload_sha256"], assertion["source_value"])
        self.assertEqual(
            audit["patch"]["replacement_payload_sha256"], assertion["output_value"]
        )

    def test_rejects_rehashed_family_assertion_mismatch(self) -> None:
        editable, audit, handoff = self.fixture("control_target")
        result = semantic_diff.build(editable, audit, handoff)
        result["semantic_changes"]["assertion"]["kind"] = "literal_value"
        result["payload_sha256"] = semantic_diff.fingerprint(result)
        with self.assertRaisesRegex(
            semantic_diff.MesBytePatchSemanticDiffError, "family semantic rule"
        ):
            semantic_diff.validate(result)

    def test_rejects_rehashed_changed_choice_operand_projection(self) -> None:
        editable, audit, handoff = self.fixture("choice")
        instruction = next(
            row for row in handoff["typed_ir"]["instructions"]
            if row["source_offset"] == 19
        )
        operand = instruction["operands"][0]
        operand["raw_hex"] = audit["patch"]["source_payload_sha256"][:10]
        operand["raw_bytes"] = {"$packed_byte_array_hex": operand["raw_hex"]}
        handoff["payload_sha256"] = handoff_validator.fingerprint(handoff)
        with self.assertRaisesRegex(
            semantic_diff.MesBytePatchSemanticDiffError, "choice-option semantic assertion"
        ):
            semantic_diff.build(editable, audit, handoff)

    def test_choice_family_builds_when_editable_identity_carries_source_kind(self) -> None:
        # The real mes_authoring_workflow editable model's source_identity
        # always carries source_kind (mes_authoring_workflow._source()); the
        # choice proof's own identity never does (prove_mes_choice_group_
        # authoring._normalize_source_identity fixes it to exactly archive,
        # archive_sha256, entry, entry_sha256). build() must still match the
        # two by normalizing source_kind out of the comparison.
        source, proof, operation = choice_plan_fixture()
        plan = choice_planner.plan(source, proof, operation)
        output, audit = choice_compiler.compile_choice_option(source, proof, plan)
        editable = self._choice_editable(source, proof, source_kind="original_arc")
        self.assertEqual(
            "original_arc", editable["source_ir"]["source_identity"]["source_kind"]
        )
        handoff = self._output_handoff(editable, output, audit)

        result = semantic_diff.build(editable, audit, handoff)

        self.assertEqual("choice_option_edit", result["operation"]["family"])
        semantic_diff.validate(copy.deepcopy(result), editable, audit, handoff)

    def test_rejects_rehashed_changed_resource_assertion(self) -> None:
        editable, audit, handoff = self.fixture("resource")
        changed = copy.deepcopy(handoff)
        reference = next(row for row in changed["references"]["resources"] if row["source_offset"] == audit["operation"]["source_offset"])
        reference["source_name"] = "wrong.mmo"
        reference["name"] = "wrong.mmo"
        changed["payload_sha256"] = handoff_validator.fingerprint(changed)

        with self.assertRaisesRegex(semantic_diff.MesBytePatchSemanticDiffError, "semantic assertion"):
            semantic_diff.build(editable, audit, changed)

    def test_rejects_rehashed_unrelated_output_byte(self) -> None:
        editable, audit, handoff = self.fixture("state")
        changed = copy.deepcopy(handoff)
        code_offset = int(changed["container"]["header"]["code_offset"])
        raw = bytearray.fromhex(changed["container"]["raw_hex"])
        changed_offset = int(audit["target"]["instruction_start"])
        raw[code_offset + changed_offset] ^= 1
        code = bytes(raw[code_offset:])
        changed["container"]["raw_hex"] = bytes(raw).hex()
        changed["container"]["entry_sha256"] = hashlib.sha256(raw).hexdigest()
        changed["container"]["bytecode_sha256"] = hashlib.sha256(code).hexdigest()
        instruction = next(
            row for row in changed["typed_ir"]["instructions"]
            if row["source_offset"] == changed_offset
        )
        instruction["raw_hex"] = code[
            instruction["source_offset"]:instruction["end_offset"]
        ].hex()
        changed["payload_sha256"] = handoff_validator.fingerprint(changed)

        with self.assertRaisesRegex(Exception, "record raw bytes|output container"):
            semantic_diff.build(editable, audit, changed)

    @staticmethod
    def _output_handoff(editable: dict, output: bytes, audit: dict) -> dict:
        source_ir = editable["source_ir"]
        reopened = noop_compiler.reopen_container(output)
        code_offset = int(reopened["code_offset"])
        code = output[code_offset:]
        offsets = [int(value) for value in reopened["entry_offsets"]]
        entries = []
        for index, offset in enumerate(offsets):
            end = offsets[index + 1] if index + 1 < len(offsets) else len(code)
            entries.append({"id": f"entry_{index:04d}", "index": index, "offset": offset,
                            "end_offset": end, "size": end - offset})
        target = audit.get("target", audit.get("source_control", audit.get("patch")))
        if audit["schema"] == choice_compiler.AUDIT_SCHEMA:
            owner_start = next(
                int(node["source"]["start"])
                for node in source_ir["nodes"]
                if node["source"]["raw_sha256"] == target["source_instruction_sha256"]
            )
        else:
            owner_start = int(target.get("owner_start", target.get("instruction_start")))
        patch_start = int(target.get(
            "expression_start",
            target.get(
                "literal_start",
                target.get("name_start", target.get("operand_start", target.get("code_start"))),
            ),
        ))
        instructions, opaque = [], []

        for node in source_ir["nodes"]:
            start, end = int(node["source"]["start"]), int(node["source"]["end"])
            raw = code[start:end]
            if node["kind"] == "opaque":
                opaque.append({"source_offset": start, "end_offset": end, "raw_hex": raw.hex(),
                               "raw_sha256": hashlib.sha256(raw).hexdigest(), "region": node["source"]["region"],
                               "boundary": node["statement"]["boundary"], **copy.deepcopy(node["statement"]["details"])})
                continue
            statement = copy.deepcopy(node["statement"])
            operation_kind = audit.get("operation", {}).get("kind", "")
            if start == owner_start and operation_kind in {
                "replace_state_write_literal", "replace_condition_literal",
                "replace_shared_routine_literal", "replace_registered_definition_literal",
            }:
                replacement_value = audit["operation"].get(
                    "replacement_value",
                    audit["operation"].get(
                        "replacement_routine_id", audit["operation"].get("replacement_selector")
                    ),
                )
                MesBytePatchSemanticDiffTests._replace_literal(
                    statement, patch_start, int(replacement_value)
                )
            elif start == owner_start and operation_kind == "retarget_control_flow":
                MesBytePatchSemanticDiffTests._replace_code_offset(
                    statement, int(audit["operation"]["current_target_offset"]),
                    int(audit["operation"]["replacement_target_offset"]),
                )
            elif start == owner_start and audit["schema"] == choice_compiler.AUDIT_SCHEMA:
                replacement = output[
                    int(audit["source"]["code_offset"]) + int(target["code_start"]):
                    int(audit["source"]["code_offset"]) + int(target["code_end"])
                ]
                for operand in statement.get("operands", []):
                    if operand.get("type") == "cp932_bytes" and operand.get("source_offset") == patch_start:
                        operand["raw_hex"] = replacement.hex()
                        operand["raw_bytes"] = {"$packed_byte_array_hex": replacement.hex()}
            instructions.append({"ok": True, "schema": handoff_validator.COMPONENT_SCHEMAS["instruction"],
                                 "source_offset": start, "end_offset": end, "byte_length": end - start,
                                 "raw_hex": raw.hex(), "region": node["source"]["region"],
                                 "op": statement["op"], "command_id": statement["command_id"],
                                 "operands": statement["operands"], **statement["metadata"]})
        references = {"messages": [], "code": [], "state": [], "resources": []}
        for row in source_ir["references"]:
            value = copy.deepcopy(row["value"])
            if row["id"] == audit["operation"].get("reference_id"):
                replacement = str(audit["operation"]["replacement_name"])
                value["source_name"] = replacement
                if "name" in value:
                    value["name"] = replacement.upper() if value["name"].isupper() else replacement
            if (
                audit["operation"]["kind"] == "retarget_control_flow"
                and row["id"] == audit["source_control"]["reference_id"]
            ):
                value["target_offset"] = int(audit["operation"]["replacement_target_offset"])
                value["target_region"] = audit["replacement_target"]["source_region_id"]
            bucket = {"message": "messages", "resource": "resources"}.get(
                row["kind"], row["kind"]
            )
            references[bucket].append(value)
        bootstrap = next(row for row in source_ir["regions"] if row["kind"] == "bootstrap")
        handoff = {"ok": True, "schema": handoff_validator.HANDOFF_SCHEMA,
            "producer": {"implementation": "test", "contract": handoff_validator.HANDOFF_SCHEMA},
            "compatibility": {"policy": "exact_component_schema_match", "component_schemas": {
                **handoff_validator.COMPONENT_SCHEMAS,
                "accepted_call_evidence": handoff_validator.CALL_EVIDENCE_SCHEMAS,
                "accepted_trace_evidence": handoff_validator.TRACE_EVIDENCE_SCHEMAS}},
            "source_identity": copy.deepcopy(source_ir["source_identity"]),
            "container": {"schema": "ai5_mes_container/v1", "header": {"code_offset": code_offset, "code_size": len(code)},
                "bootstrap": {"offset": int(bootstrap["source_start"]), "end_offset": int(bootstrap["source_end"]),
                              "size": int(bootstrap["source_end"]) - int(bootstrap["source_start"])},
                "entries": entries, "entry_sha256": hashlib.sha256(output).hexdigest(),
                "bytecode_sha256": hashlib.sha256(code).hexdigest(), "raw_hex": output.hex()},
            "record_alignment": {"schema": "kakyu_mes_record_alignment_audit/v1"},
            "typed_ir": {"schema": "kakyu_mes_analysis/v19", "complete": True,
                         "instructions": instructions, "diagnostics": [], "opaque_boundaries": opaque},
            "references": references, "cfg": [], "calls": [], "traces": []}
        handoff["payload_sha256"] = handoff_validator.fingerprint(handoff)
        return handoff

    @staticmethod
    def _choice_editable(source: bytes, proof: dict, source_kind: str | None = None) -> dict:
        container = proof["container"]
        code_offset = int(container["code_offset"])
        code = source[code_offset:]
        message = proof["groups"][0]["definitions"][0]["message"]
        owner_start = int(message["instruction_start"])
        owner_end = int(message["instruction_end"])
        payload_start = int(message["payload_start"])
        payload_end = int(message["payload_end"])
        identity = copy.deepcopy(proof["source_identity"])
        identity.pop("entry_sha256", None)
        if source_kind is not None:
            # The real authoring workflow's editable identity always carries
            # source_kind (mes_authoring_workflow._source()); the choice
            # proof's own identity never does. semantic_diff must still match
            # the two by normalizing source_kind away, not by requiring it.
            identity["source_kind"] = source_kind
        opaque = []
        for start, end in ((0, owner_start), (owner_end, len(code))):
            if end <= start:
                continue
            raw = code[start:end]
            opaque.append({
                "source_offset": start, "end_offset": end, "raw_hex": raw.hex(),
                "raw_sha256": hashlib.sha256(raw).hexdigest(), "region": "entry_0000",
                "boundary": "byte_preserving_fail_closed", "reason": "synthetic choice fixture",
            })
        payload = code[payload_start:payload_end]
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
            "source_identity": identity,
            "container": {
                "schema": "ai5_mes_container/v1",
                "header": {"code_offset": code_offset, "code_size": len(code)},
                "bootstrap": {"offset": 0, "end_offset": 0, "size": 0},
                "entries": [{
                    "id": "entry_0000", "index": 0, "offset": 0,
                    "end_offset": len(code), "size": len(code),
                }],
                "entry_sha256": hashlib.sha256(source).hexdigest(),
                "bytecode_sha256": hashlib.sha256(code).hexdigest(), "raw_hex": source.hex(),
            },
            "record_alignment": {"schema": "kakyu_mes_record_alignment_audit/v1"},
            "typed_ir": {
                "schema": "kakyu_mes_analysis/v19", "complete": False,
                "instructions": [{
                    "ok": True, "schema": handoff_validator.COMPONENT_SCHEMAS["instruction"],
                    "source_offset": owner_start, "end_offset": owner_end,
                    "byte_length": owner_end - owner_start,
                    "raw_hex": code[owner_start:owner_end].hex(), "region": "entry_0000",
                    "op": "text", "command_id": 1,
                    "operands": [{
                        "type": "cp932_bytes", "source_offset": payload_start,
                        "raw_hex": payload.hex(),
                        "raw_bytes": {"$packed_byte_array_hex": payload.hex()},
                    }],
                }],
                "diagnostics": [{"code": "synthetic_choice_fixture"}],
                "opaque_boundaries": opaque,
            },
            "references": {"messages": [], "code": [], "state": [], "resources": []},
            "cfg": [], "calls": [], "traces": [],
            "capability_report": {"product_data": "forbidden"},
        }
        handoff["payload_sha256"] = handoff_validator.fingerprint(handoff)
        return editable_ir.prepare(decompiler.lift(handoff))

    @staticmethod
    def _replace_literal(value: object, offset: int, replacement: int) -> None:
        if isinstance(value, dict):
            if value.get("type") == "literal" and value.get("source", {}).get("offset") == offset:
                value["value"] = replacement
            for child in value.values():
                MesBytePatchSemanticDiffTests._replace_literal(child, offset, replacement)
        elif isinstance(value, list):
            for child in value:
                MesBytePatchSemanticDiffTests._replace_literal(child, offset, replacement)

    @staticmethod
    def _replace_code_offset(value: object, source: int, replacement: int) -> None:
        if isinstance(value, dict):
            if value.get("type") == "code_offset" and value.get("value") == source:
                value["value"] = replacement
            for child in value.values():
                MesBytePatchSemanticDiffTests._replace_code_offset(child, source, replacement)
        elif isinstance(value, list):
            for child in value:
                MesBytePatchSemanticDiffTests._replace_code_offset(child, source, replacement)


if __name__ == "__main__":
    unittest.main()
