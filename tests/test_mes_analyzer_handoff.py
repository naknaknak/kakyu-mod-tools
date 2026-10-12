from __future__ import annotations

import json
import struct
import sys
import tempfile
import unittest
from unittest.mock import patch
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

import audit_mes_handoff_equivalence as audit  # noqa: E402
import mes_analyzer_handoff as handoff  # noqa: E402


def container(code: bytes, entry_offsets: list[int]) -> bytes:
    header = struct.pack("<I", len(entry_offsets))
    table = b"".join(struct.pack("<I", offset) for offset in entry_offsets)
    return header + table + code


class NormalizationTests(unittest.TestCase):
    """The fingerprint must be the handoff's rule, not a second one."""

    def test_dictionary_keys_are_sorted(self) -> None:
        self.assertEqual(handoff.fingerprint({"b": 1, "a": 2}), handoff.fingerprint({"a": 2, "b": 1}))

    def test_byte_arrays_become_the_hex_object(self) -> None:
        self.assertEqual(
            handoff.normalize(b"\x01\xff"), {"$packed_byte_array_hex": "01ff"}
        )

    def test_nesting_is_normalized_all_the_way_down(self) -> None:
        self.assertEqual(
            handoff.normalize({"z": [{"b": 1, "a": b"\x02"}]}),
            {"z": [{"a": {"$packed_byte_array_hex": "02"}, "b": 1}]},
        )

    def test_list_order_is_preserved(self) -> None:
        self.assertNotEqual(handoff.fingerprint([1, 2]), handoff.fingerprint([2, 1]))


class ContainerComponentTests(unittest.TestCase):
    def test_the_header_is_derived_from_the_address_table(self) -> None:
        component = handoff.build_container(container(b"\x00" * 12, [0, 6]))["header"]
        self.assertEqual(component["entry_count"], 2)
        self.assertEqual(component["table_offset"], 4)
        self.assertEqual(component["table_size"], 8)
        self.assertEqual(component["code_offset"], 12)
        self.assertEqual(component["code_size"], 12)
        self.assertEqual(component["entry_offsets"], [0, 6])
        self.assertEqual(component["offset_basis"], "code_start")

    def test_entries_carry_ids_offsets_and_sizes(self) -> None:
        entries = handoff.build_container(container(b"\x00" * 12, [0, 6]))["entries"]
        self.assertEqual([entry["id"] for entry in entries], ["entry_0000", "entry_0001"])
        self.assertEqual([entry["size"] for entry in entries], [6, 6])
        self.assertEqual([entry["file_offset"] for entry in entries], [12, 18])
        self.assertEqual(entries[-1]["end_offset"], 12)

    def test_a_bootstrap_prefix_is_measured(self) -> None:
        bootstrap = handoff.build_container(container(b"\x00" * 12, [8]))["bootstrap"]
        self.assertEqual((bootstrap["offset"], bootstrap["end_offset"], bootstrap["size"]), (0, 8, 8))

    def test_an_empty_address_table_makes_the_whole_code_bootstrap(self) -> None:
        component = handoff.build_container(container(b"\x00" * 4, []))
        self.assertEqual(component["bootstrap"]["size"], 4)
        self.assertEqual(component["entries"], [])

    def test_a_table_larger_than_the_payload_fails_closed(self) -> None:
        with self.assertRaises(handoff.HandoffError):
            handoff.build_container(struct.pack("<I", 99) + b"\x00" * 4)

    def test_an_address_outside_the_code_fails_closed(self) -> None:
        with self.assertRaises(handoff.HandoffError):
            handoff.build_container(container(b"\x00" * 4, [99]))

    def test_addresses_must_strictly_increase(self) -> None:
        with self.assertRaises(handoff.HandoffError):
            handoff.build_container(container(b"\x00" * 12, [4, 4]))

    def test_a_short_payload_fails_closed(self) -> None:
        with self.assertRaises(handoff.HandoffError):
            handoff.build_container(b"\x01")

    def test_the_component_carries_no_local_helper_fields(self) -> None:
        component = handoff.build_components(container(b"\x00" * 8, [0]))["container"]
        self.assertEqual(
            sorted(component),
            ["bootstrap", "bytecode_sha256", "entries", "entry_sha256", "header", "raw_hex", "schema"],
        )


class NotProducedTests(unittest.TestCase):
    """An absent producer must never read as agreement."""

    def test_only_the_written_components_are_produced(self) -> None:
        produced = handoff.build_components(container(b"\x00" * 8, [0]))
        self.assertEqual(set(produced), set(handoff.COMPONENTS))
        self.assertNotIn("payload_sha256", produced)

    def test_invalid_alignment_cannot_be_published_as_a_component(self) -> None:
        for alignment in ({"ok": False}, {"ok": True}, {"ok": True, "schema": "unknown/v9"}):
            with self.subTest(alignment=alignment), patch("mes_record_alignment.build_record_alignment", return_value=alignment):
                with self.assertRaisesRegex(handoff.HandoffError, "record alignment is not complete"):
                    handoff.build_components(container(b"\x00", [0]))

    def test_an_absent_component_is_reported_not_produced(self) -> None:
        row = {
            "entry": "T.MES",
            "entry_sha256": "",
            "components": {"container": "deadbeef", "capability_report": "deadbeef"},
        }
        payload = container(b"\x00" * 8, [0])
        incomplete = handoff.build_components(payload)
        del incomplete["capability_report"]
        with patch.object(audit, "build_components", return_value=incomplete):
            result = audit.compare_entry(payload, row)
        self.assertEqual(result["verdicts"]["capability_report"], "not_produced")
        self.assertEqual(result["verdicts"]["container"], "diverged")

    def test_a_matching_component_is_equal(self) -> None:
        payload = container(b"\x00" * 8, [0])
        component = handoff.build_components(payload)["container"]
        row = {
            "entry": "T.MES",
            "entry_sha256": component["entry_sha256"],
            "components": {"container": handoff.fingerprint(component)},
        }
        result = audit.compare_entry(payload, row)
        self.assertEqual(result["verdicts"]["container"], "equal")
        self.assertTrue(result["entry_sha256_equal"])

    def test_a_payload_python_cannot_parse_reports_rather_than_raises(self) -> None:
        row = {"entry": "T.MES", "entry_sha256": "", "components": {"container": "x"}}
        result = audit.compare_entry(b"\x01", row)
        self.assertEqual(result["verdicts"]["container"], "not_produced")
        self.assertIsNotNone(result["python_error"])


class DigestReadingTests(unittest.TestCase):
    def test_a_foreign_schema_fails_closed(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "d.jsonl"
            path.write_text(
                json.dumps({"kind": "header", "schema": "other/v1", "archive_sha256": "a"}) + "\n",
                encoding="utf-8",
            )
            with self.assertRaises(audit.HandoffAuditError):
                audit.read_digest(path)

    def test_a_digest_without_a_header_fails_closed(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "d.jsonl"
            path.write_text(json.dumps({"kind": "entry", "entry": "T.MES"}) + "\n", encoding="utf-8")
            with self.assertRaises(audit.HandoffAuditError):
                audit.read_digest(path)

    def test_a_non_positive_limit_fails_closed(self) -> None:
        self.assertEqual(
            audit.main(["--digest", str(ROOT), "--arc", str(ROOT), "--limit", "0"]), 2
        )


if __name__ == "__main__":
    unittest.main()
