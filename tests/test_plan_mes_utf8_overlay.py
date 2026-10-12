from __future__ import annotations

import copy
import json
from pathlib import Path
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
TOOLS = ROOT / "tools"
for candidate in (str(TOOLS), str(Path(__file__).resolve().parent)):
    if candidate not in sys.path:
        sys.path.insert(0, candidate)

import plan_mes_utf8_overlay as planner  # noqa: E402
import prepare_mes_editable_ir as editable_ir  # noqa: E402
import test_plan_mes_message_relocation as relocation_tests  # noqa: E402


class MesUtf8OverlayPlanTests(unittest.TestCase):
    def fixture(self) -> tuple[dict, dict]:
        document, cp932_operation = relocation_tests.MesMessageRelocationPlanTests().fixture()
        operation = {
            "kind": "replace_message_utf8_overlay",
            "source_offset": cp932_operation["source_offset"],
            "raw_sha256": cp932_operation["raw_sha256"],
            "text": "리메이크 전용 😀",
            "encoding": "utf8",
            "compatibility": "remake_only",
            "container_policy": "do_not_assemble_mes",
        }
        return document, operation

    def test_plans_distinct_remake_only_projection_without_mes_bytes(self) -> None:
        document, operation = self.fixture()
        result = planner.plan(document, operation)

        self.assertEqual(planner.PLAN_SCHEMA, result["schema"])
        self.assertEqual("replace_message_utf8_overlay", result["operation"]["kind"])
        self.assertEqual("forbidden", result["compatibility"]["mes_container_output"])
        self.assertTrue(result["invariants"]["mes_container_bytes_not_emitted"])
        self.assertEqual(
            {
                "schema": planner.PROJECTION_SCHEMA,
                "base_archive_sha256": "a" * 64,
                "entry_sha256": document["source_ir"]["container"]["entry_sha256"],
                "target_archive": "mes.arc",
                "target_entry": "RELOCATE.MES",
                "edits": [{
                    "source_offset": 0,
                    "raw_sha256": operation["raw_sha256"],
                    "text": operation["text"],
                }],
            },
            result["projection_document"],
        )

    def test_plan_is_deterministic_and_json_validated(self) -> None:
        document, operation = self.fixture()
        first = planner.plan(document, operation)
        second = planner.plan(copy.deepcopy(document), copy.deepcopy(operation))
        transported = json.loads(json.dumps(first, ensure_ascii=False))

        self.assertEqual(first, second)
        self.assertEqual(first, transported)
        planner.validate(transported, document)

    def test_rejects_cp932_or_original_compatible_operation(self) -> None:
        document, operation = self.fixture()
        cp932 = copy.deepcopy(operation)
        cp932["encoding"] = "cp932"
        with self.assertRaisesRegex(planner.MesUtf8OverlayPlanError, "encoding"):
            planner.plan(document, cp932)
        original = copy.deepcopy(operation)
        original["compatibility"] = "original_engine_compatible"
        with self.assertRaisesRegex(planner.MesUtf8OverlayPlanError, "compatibility"):
            planner.plan(document, original)

    def test_rejects_mes_assembly_policy_and_unknown_fields(self) -> None:
        document, operation = self.fixture()
        assembled = copy.deepcopy(operation)
        assembled["container_policy"] = "assemble_mes"
        with self.assertRaisesRegex(planner.MesUtf8OverlayPlanError, "container policy"):
            planner.plan(document, assembled)
        unknown = copy.deepcopy(operation)
        unknown["ignored"] = True
        with self.assertRaisesRegex(planner.MesUtf8OverlayPlanError, "fields"):
            planner.plan(document, unknown)

    def test_rejects_stale_message_hash(self) -> None:
        document, operation = self.fixture()
        operation["raw_sha256"] = "0" * 64
        with self.assertRaisesRegex(planner.MesUtf8OverlayPlanError, "stale"):
            planner.plan(document, operation)

    def test_requires_archive_bound_source_identity(self) -> None:
        document, operation = self.fixture()
        document["source_ir"]["source_identity"].pop("archive_sha256")
        document["source_ir"]["payload_sha256"] = self._source_fingerprint(document)
        document["payload_sha256"] = editable_ir.fingerprint(document)
        with self.assertRaisesRegex(planner.MesUtf8OverlayPlanError, "archive-bound"):
            planner.plan(document, operation)

    def test_rejects_changed_plan_and_projection_fields(self) -> None:
        document, operation = self.fixture()
        result = planner.plan(document, operation)
        result["projection_document"]["target_entry"] = "OTHER.MES"
        result["payload_sha256"] = planner.fingerprint(result)
        with self.assertRaisesRegex(planner.MesUtf8OverlayPlanError, "projection"):
            planner.validate(result)
        result = planner.plan(document, operation)
        result["ignored"] = True
        result["payload_sha256"] = planner.fingerprint(result)
        with self.assertRaisesRegex(planner.MesUtf8OverlayPlanError, "fields"):
            planner.validate(result)

    def test_cli_publication_uses_new_file_contract(self) -> None:
        document, operation = self.fixture()
        with tempfile.TemporaryDirectory() as raw_directory:
            output = Path(raw_directory) / "utf8-overlay-plan.json"
            encoded = editable_ir.canonical_json_bytes(planner.plan(document, operation)) + b"\n"
            editable_ir.publish_new(output, encoded)
            with self.assertRaisesRegex(editable_ir.EditableIrError, "already exists"):
                editable_ir.publish_new(output, encoded)

    @staticmethod
    def _source_fingerprint(document: dict) -> str:
        import decompile_mes_handoff as decompiler

        return decompiler.fingerprint(document["source_ir"])


if __name__ == "__main__":
    unittest.main()
