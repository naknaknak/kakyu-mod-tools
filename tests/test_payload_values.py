from __future__ import annotations

import hashlib
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

import payload_values  # noqa: E402


class PayloadValuesTests(unittest.TestCase):
    def test_canonical_bytes_are_sorted_compact_utf8_without_the_stored_hash(self) -> None:
        document = {"b": [1, 2.5, None], "a": "가", "payload_sha256": "ignored"}
        self.assertEqual(
            '{"a":"가","b":[1,2.5,null]}'.encode("utf-8"),
            payload_values.canonical_payload_bytes(document),
        )
        self.assertIn("payload_sha256", document)

    def test_canonical_bytes_refuse_nan(self) -> None:
        with self.assertRaises(ValueError):
            payload_values.canonical_payload_bytes({"value": float("nan")})

    def test_fingerprint_is_the_hash_of_the_canonical_bytes(self) -> None:
        document = {"schema": "example/v1", "count": 3}
        expected = hashlib.sha256(b'{"count":3,"schema":"example/v1"}').hexdigest()
        self.assertEqual(expected, payload_values.fingerprint(document))
        stored = dict(document, payload_sha256=expected)
        self.assertEqual(expected, payload_values.fingerprint(stored))

    def test_is_sha256_accepts_only_lower_case_64_hex_strings(self) -> None:
        digest = hashlib.sha256(b"abc").hexdigest()
        self.assertTrue(payload_values.is_sha256(digest))
        self.assertFalse(payload_values.is_sha256(digest.upper()))
        self.assertFalse(payload_values.is_sha256(digest[:-1]))
        self.assertFalse(payload_values.is_sha256(digest[:-1] + "g"))
        self.assertFalse(payload_values.is_sha256(bytes.fromhex(digest)))
        self.assertFalse(payload_values.is_sha256(None))

    def test_is_safe_leaf_is_the_catalogs_rule(self) -> None:
        for good in ("A", "01M.MES", "LIBLARY.LIB", "V0001.OGG", "a b", "A.B.C", ".X", "X."):
            self.assertTrue(payload_values.is_safe_leaf(good), good)
        for bad in ("", "A/B", "/A", "A\\B", "..", "A..B", "C:X", ":", None, 5, ["A"], b"A"):
            self.assertFalse(payload_values.is_safe_leaf(bad), bad)

    def test_is_gallery_registry_row_names_an_album_scene_row(self) -> None:
        row = {"category": "special", "evidence": {"callee": "SCENE_J03.MES", "caller": "MINATU_M.MES"}}
        self.assertTrue(payload_values.is_gallery_registry_row(row))
        self.assertTrue(payload_values.is_gallery_registry_row({"category": "special", "evidence": {"callee": "scene_j_h01.mes"}}))
        for other in (
            {"category": "town", "evidence": {"callee": "SCENE_J03.MES"}},
            {"category": "special", "evidence": {"callee": "EVENTQ01.MES"}},
            {"category": "town", "evidence": {"callee": "A_PIC.MES"}},
            {"category": "special"},
            {},
            None,
        ):
            self.assertFalse(payload_values.is_gallery_registry_row(other), other)

    def test_sha256_file_hashes_across_chunk_boundaries(self) -> None:
        data = bytes(range(256)) * 4097 + b"tail"
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "blob.bin"
            path.write_bytes(data)
            self.assertEqual(hashlib.sha256(data).hexdigest(), payload_values.sha256_file(path))
            empty = Path(directory) / "empty.bin"
            empty.write_bytes(b"")
            self.assertEqual(hashlib.sha256(b"").hexdigest(), payload_values.sha256_file(empty))

    def test_tools_share_the_same_functions(self) -> None:
        import annotate_mes_decompiler
        import audit_mes_decompiler_corpus

        self.assertIs(payload_values.fingerprint, annotate_mes_decompiler.fingerprint)
        self.assertIs(
            payload_values.canonical_payload_bytes,
            annotate_mes_decompiler.canonical_payload_bytes,
        )
        self.assertIs(payload_values.is_sha256, audit_mes_decompiler_corpus._is_sha256)

    def test_typed_record_builders_decode_to_the_documented_records(self) -> None:
        """The G builders (WD-25 item 1b) produce records the Phase 1-4 decoder reads back as
        the documented expression records, with no byte quoted in this test."""
        from mes_structured_ir import decode_record_list

        def signature(record: bytes) -> list[tuple[str, int]]:
            self.assertEqual(payload_values.COMMAND_NATIVE_RECORD_DISPATCH, record[0])
            rows, end = decode_record_list(record, 1, len(record))
            self.assertEqual(len(record), end)
            result = []
            for row in rows["records"]:
                self.assertEqual("expression_record", row["type"])
                ast = row["value"]["ast"]
                if ast["type"] == "literal":
                    result.append(("literal", ast["value"]))
                else:
                    self.assertEqual("state_u16", ast["storage"])
                    result.append(("state_u16", ast["index"]["value"]))
            return result

        self.assertEqual(
            [("literal", payload_values.MAP_MODULE), ("literal", payload_values.MAP_GET_LOCATION)],
            signature(payload_values.map_location_poll()),
        )
        self.assertEqual(payload_values.map_location_poll(), payload_values.native_record_dispatch(6, 13))
        self.assertEqual(
            [("literal", 1), ("literal", 21), ("literal", 0)],
            signature(payload_values.routine_40_selection(0)),
        )
        self.assertEqual(
            [("literal", 1), ("literal", 21), ("state_u16", 21)],
            signature(payload_values.routine_40_selection(payload_values.state_u16_expression(21))),
        )
        self.assertEqual(payload_values.RECORD_LIST_END, payload_values.map_location_poll()[-1])

    def test_the_drafter_searches_for_the_grammar_built_poll(self) -> None:
        import draft_event_route_spec

        self.assertEqual(payload_values.map_location_poll(), draft_event_route_spec.MAP_LOCATION_POLL_BYTES)


if __name__ == "__main__":
    unittest.main()
