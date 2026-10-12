from __future__ import annotations

import copy
import sys
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
sys.path.insert(0, str(ROOT / "tools"))

import annotate_mes_decompiler as annotator  # noqa: E402
import decompile_mes_handoff as decompiler  # noqa: E402
from tests import test_decompile_mes_handoff as decompiler_tests  # noqa: E402


class MesSemanticAnnotationTests(unittest.TestCase):
    def linear_fixture(self) -> dict:
        handoff, _raw = decompiler_tests.MesDecompilerLinearIrTests().fixture()
        return decompiler.lift(handoff)

    def test_annotates_every_node_and_reference_with_source_identity(self) -> None:
        linear_ir = self.linear_fixture()
        document = annotator.annotate(linear_ir)

        self.assertEqual(annotator.SEMANTIC_ANNOTATION_SCHEMA, document["schema"])
        self.assertEqual("reject", document["compatibility"]["unknown_v1_field"])
        self.assertEqual(3, document["coverage"]["node_annotation_count"])
        self.assertEqual(4, document["coverage"]["symbol_annotation_count"])
        self.assertTrue(document["coverage"]["all_linear_nodes_annotated"])
        self.assertTrue(document["coverage"]["all_references_annotated"])
        self.assertEqual(
            ["code[0x00000002]", "message@0x00000003", "global_u8[1]", "resource@0x00000008"],
            [symbol["canonical_name"] for symbol in document["symbols"]],
        )
        self.assertTrue(
            all(node["source"]["entry"] == "TEST.MES" for node in document["nodes"])
        )
        self.assertTrue(
            all(symbol["semantic_alias"] is None for symbol in document["symbols"])
        )

    def test_formats_banked_state_and_literal_resource_without_aliases(self) -> None:
        linear_ir = self.linear_fixture()
        state = next(row for row in linear_ir["references"] if row["kind"] == "state")
        state["value"].update({"storage": "banked_u16", "bank": 3, "index": "17"})
        resource = next(
            row for row in linear_ir["references"] if row["kind"] == "resource"
        )
        resource["value"].update(
            {"name": "B3.MMO", "resource_kind": "mmo", "archive_candidates": ["mmo.arc"]}
        )
        linear_ir["payload_sha256"] = decompiler.fingerprint(linear_ir)

        document = annotator.annotate(linear_ir)
        symbols = {row["kind"]: row for row in document["symbols"]}
        self.assertEqual(
            "banked_u16[bank=3,index=17]", symbols["state"]["canonical_name"]
        )
        self.assertEqual(
            'resource["B3.MMO"]', symbols["resource"]["canonical_name"]
        )
        self.assertEqual(
            "literal_resource_identity", symbols["resource"]["annotation_status"]
        )
        self.assertIsNone(symbols["resource"]["semantic_alias"])

    def test_retains_unresolved_reference_shape_explicitly(self) -> None:
        linear_ir = self.linear_fixture()
        state = next(row for row in linear_ir["references"] if row["kind"] == "state")
        state["value"].pop("storage")
        state["value"].pop("index")
        linear_ir["payload_sha256"] = decompiler.fingerprint(linear_ir)

        document = annotator.annotate(linear_ir)
        symbol = next(row for row in document["symbols"] if row["kind"] == "state")
        self.assertEqual("state@0x00000006", symbol["canonical_name"])
        self.assertEqual("unresolved_reference_shape", symbol["annotation_status"])

        state["value"].update({"storage": "global_u8", "index": "expression_1"})
        linear_ir["payload_sha256"] = decompiler.fingerprint(linear_ir)
        symbolic = annotator.annotate(linear_ir)
        symbolic_state = next(
            row for row in symbolic["symbols"] if row["kind"] == "state"
        )
        self.assertEqual("state@0x00000006", symbolic_state["canonical_name"])
        self.assertEqual(
            "unresolved_reference_shape", symbolic_state["annotation_status"]
        )

    def test_annotation_is_deterministic(self) -> None:
        linear_ir = self.linear_fixture()
        first = annotator.annotate(linear_ir)
        second = annotator.annotate(copy.deepcopy(linear_ir))
        self.assertEqual(first, second)
        self.assertEqual(first["payload_sha256"], annotator.fingerprint(first))

    def test_rejects_rehashed_semantic_alias_injection(self) -> None:
        linear_ir = self.linear_fixture()
        document = annotator.annotate(linear_ir)
        document["symbols"][0]["semantic_alias"] = "guessed_scene_name"
        document["payload_sha256"] = annotator.fingerprint(document)
        with self.assertRaisesRegex(
            annotator.SemanticAnnotationError, "projection changed"
        ):
            annotator.validate(document, linear_ir)

    def test_rejects_unknown_source_reference_kind(self) -> None:
        linear_ir = self.linear_fixture()
        reference = {
            "id": "character_00000000",
            "kind": "character",
            "source_offset": 0,
            "value": {"id": 1},
        }
        linear_ir["references"].append(reference)
        linear_ir["nodes"][0]["reference_ids"].append(reference["id"])
        linear_ir["payload_sha256"] = decompiler.fingerprint(linear_ir)
        with self.assertRaisesRegex(
            annotator.SemanticAnnotationError, "unsupported source reference kind"
        ):
            annotator.annotate(linear_ir)


if __name__ == "__main__":
    unittest.main()
