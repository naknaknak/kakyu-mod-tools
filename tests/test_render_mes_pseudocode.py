from __future__ import annotations

import copy
import sys
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
sys.path.insert(0, str(ROOT / "tools"))

import compose_mes_renderer_loops as loop_composer  # noqa: E402
import render_mes_pseudocode as renderer  # noqa: E402
from tests import test_compose_mes_renderer_loops as loop_tests  # noqa: E402


class MesPseudocodeRendererTests(unittest.TestCase):
    def fixture(self) -> dict:
        return loop_composer.compose(*loop_tests.MesRendererLoopTests().fixture())

    def test_renders_every_linear_node_once_with_source_reversal(self) -> None:
        source = self.fixture()
        document = renderer.render(source)

        self.assertEqual(renderer.PSEUDOCODE_SCHEMA, document["schema"])
        self.assertEqual(3, document["coverage"]["node_line_count"])
        self.assertEqual(0, document["coverage"]["unmapped_linear_node_count"])
        self.assertTrue(document["coverage"]["all_linear_nodes_rendered_once"])
        node_lines = [row for row in document["lines"] if row["linear_node_ids"]]
        rendered_nodes = [
            row["linear_node_ids"][0]
            for row in node_lines
            if len(row["linear_node_ids"]) == 1
            and row["text"].startswith("0x")
        ]
        self.assertEqual(
            [row["id"] for row in source["program"]["nodes"]], rendered_nodes
        )
        self.assertTrue(
            all(item["sources"] for item in node_lines)
        )

    def test_renders_proved_control_without_guessing_surface_syntax(self) -> None:
        document = renderer.render(self.fixture())
        text = "\n".join(row["text"] for row in document["lines"])

        self.assertIn("branch_if_not_true", text)
        self.assertIn("branch ast=", text)
        self.assertNotIn("while (", text)
        self.assertNotIn("switch (", text)
        self.assertEqual(0, document["coverage"]["guessed_surface_control_count"])

    def test_messages_remain_source_coordinates_not_decoded_dialogue(self) -> None:
        document = renderer.render(self.fixture())
        text = "\n".join(row["text"] for row in document["lines"])

        self.assertIn("message@0x00000003", text)
        self.assertEqual(0, document["coverage"]["decoded_dialogue_count"])
        self.assertEqual(0, document["coverage"]["semantic_alias_count"])

    def test_rendering_is_deterministic(self) -> None:
        source = self.fixture()
        first = renderer.render(source)
        second = renderer.render(copy.deepcopy(source))
        self.assertEqual(first, second)
        self.assertEqual(first["payload_sha256"], renderer.fingerprint(first))

    def test_rejects_rehashed_renderer_node_annotation_mismatch(self) -> None:
        source = self.fixture()
        source["program"]["nodes"][0]["statement"]["op"] = "guessed_dialogue"
        source["payload_sha256"] = loop_composer.fingerprint(source)
        with self.assertRaisesRegex(
            renderer.PseudocodeRenderError, "typed operation annotation changed"
        ):
            renderer.render(source)

    def test_rejects_rehashed_overlay_source_map_mismatch(self) -> None:
        source = self.fixture()
        source["source_map"][0]["overlay_ids"] = ["guessed_overlay"]
        source["payload_sha256"] = loop_composer.fingerprint(source)
        with self.assertRaisesRegex(
            renderer.PseudocodeRenderError, "overlay source-map reversal changed"
        ):
            renderer.render(source)


if __name__ == "__main__":
    unittest.main()
