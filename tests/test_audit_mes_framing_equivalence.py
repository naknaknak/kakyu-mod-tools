from __future__ import annotations

import hashlib
import json
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

import audit_mes_framing_equivalence as framing  # noqa: E402


def mes_entry(code: bytes, entry_offsets: list[int]) -> bytes:
    """A minimal MES container: entry count, address table, then code."""
    header = len(entry_offsets).to_bytes(4, "little")
    table = b"".join(offset.to_bytes(4, "little") for offset in entry_offsets)
    return header + table + code


def digest_file(path: Path, rows: list[dict], archive_sha256: str = "a" * 64) -> None:
    lines = [
        json.dumps(
            {
                "schema": framing.DIGEST_SCHEMA,
                "kind": "header",
                "archive_sha256": archive_sha256,
                "entry_count": len(rows),
                "decode_mode": "aligned_strict",
            }
        )
    ]
    lines.extend(json.dumps(row) for row in rows)
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


class ContainerRegionTests(unittest.TestCase):
    def test_regions_are_a_non_empty_bootstrap_then_each_entry(self) -> None:
        payload = mes_entry(b"\x00" * 32, [8, 20])
        container = framing.parse_mes_container(payload)

        self.assertEqual([(0, 8), (8, 20), (20, 32)], framing.container_regions(container))

    def test_an_empty_bootstrap_contributes_no_region(self) -> None:
        # The authoritative exporter omits an empty bootstrap and mes_cfg_seed
        # always emits one; agreeing on omission is what lets the two compare.
        payload = mes_entry(b"\x00" * 16, [0, 8])
        container = framing.parse_mes_container(payload)

        self.assertEqual([(0, 8), (8, 16)], framing.container_regions(container))

    def test_an_entryless_container_is_one_bootstrap_region(self) -> None:
        payload = mes_entry(b"\x00" * 12, [])
        container = framing.parse_mes_container(payload)

        self.assertEqual([(0, 12)], framing.container_regions(container))


class PythonFramingTests(unittest.TestCase):
    def test_framing_lines_are_canonical_and_hashed_over_their_text(self) -> None:
        payload = mes_entry(b"\x00\x00\x00\x00", [])
        result = framing.python_framing(payload)

        self.assertEqual(
            hashlib.sha256(result["framing"].encode("utf-8")).hexdigest(),
            result["framing_sha256"],
        )
        for line in result["framing"].split("\n"):
            kind, start, end = line.split(" ")
            self.assertIn(kind, {"i", "o"})
            self.assertLess(int(start), int(end))

    def test_an_undecodable_region_becomes_one_opaque_line(self) -> None:
        # 0x1B has no Python grammar, so the whole region is refused rather
        # than partly guessed.
        payload = mes_entry(b"\x1b\x1b\x1b\x1b", [])
        result = framing.python_framing(payload)

        self.assertEqual("o 0 4", result["framing"])
        self.assertEqual(0, result["instruction_count"])
        self.assertEqual(1, result["opaque_count"])

    def test_decoded_bytes_never_exceed_the_code_size(self) -> None:
        payload = mes_entry(b"\x00" * 64, [16, 32])
        result = framing.python_framing(payload)

        self.assertLessEqual(result["decoded_bytes"], result["code_size"])


class FirstDivergenceTests(unittest.TestCase):
    def test_identical_framings_have_no_divergence(self) -> None:
        self.assertIsNone(framing.first_divergence("i 0 4\ni 4 8", "i 0 4\ni 4 8"))

    def test_divergence_names_the_offset_and_the_opcode_there(self) -> None:
        code = b"\x00\x00\x00\x00\x1b\x00"
        result = framing.first_divergence("i 0 4\ni 4 6", "i 0 4\no 4 6", code)

        assert result is not None
        self.assertEqual(1, result["line"])
        self.assertEqual(4, result["offset"])
        self.assertEqual("0x1B", result["command_id"])
        self.assertEqual("i 4 6", result["authoritative"])
        self.assertEqual("o 4 6", result["python"])

    def test_a_shorter_side_diverges_at_the_first_missing_line(self) -> None:
        result = framing.first_divergence("i 0 4\ni 4 8", "i 0 4")

        assert result is not None
        self.assertEqual(1, result["line"])
        self.assertEqual("one side stops earlier", result["reason"])
        self.assertEqual("", result["python"])

    def test_an_offset_outside_the_code_yields_no_opcode(self) -> None:
        result = framing.first_divergence("i 99 100", "i 0 1", b"\x00")

        assert result is not None
        self.assertEqual("", result["command_id"])


class DigestReadingTests(unittest.TestCase):
    def test_a_digest_without_a_header_fails_closed(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "d.jsonl"
            path.write_text(json.dumps({"kind": "entry"}) + "\n", encoding="utf-8")
            with self.assertRaisesRegex(framing.FramingError, "header"):
                framing.read_digest(path)

    def test_a_foreign_schema_fails_closed(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "d.jsonl"
            path.write_text(
                json.dumps({"kind": "header", "schema": "something/v9"}) + "\n",
                encoding="utf-8",
            )
            with self.assertRaisesRegex(framing.FramingError, "schema"):
                framing.read_digest(path)


class AuditReportTests(unittest.TestCase):
    def _run(self, code: bytes, entry_offsets: list[int], authoritative: str) -> dict:
        """Audit one synthetic entry against a supplied authoritative framing."""
        payload = mes_entry(code, entry_offsets)
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            digest = root / "framing.jsonl"
            digest_file(
                digest,
                [
                    {
                        "ok": True,
                        "kind": "entry",
                        "entry": "SYNTHETIC.MES",
                        "code_size": len(code),
                        "instruction_count": authoritative.count("i "),
                        "opaque_count": authoritative.count("o "),
                        "framing": authoritative,
                        "framing_sha256": hashlib.sha256(
                            authoritative.encode("utf-8")
                        ).hexdigest(),
                    }
                ],
            )
            original = framing.load_archive_entry
            framing.load_archive_entry = lambda _arc, _entry: (payload, {})
            try:
                return framing.audit(digest, root / "unused.arc")
            finally:
                framing.load_archive_entry = original

    def test_matching_framing_is_reported_equivalent(self) -> None:
        code = b"\x1b\x1b"
        report = self._run(code, [], "o 0 2")

        self.assertTrue(report["equivalent"])
        self.assertEqual(1, report["equal"])
        self.assertEqual(0, report["diverged"])
        self.assertEqual({}, report["divergence_commands"])

    def test_a_divergence_is_measured_not_raised(self) -> None:
        code = b"\x1b\x1b"
        report = self._run(code, [], "i 0 2")

        self.assertFalse(report["equivalent"])
        self.assertEqual(1, report["diverged"])
        self.assertEqual({"0x1B": 1}, report["divergence_commands"])
        self.assertEqual("0x1B", report["entries"][0]["first_divergence"]["command_id"])

    def test_unframed_authoritative_rows_are_skipped_not_counted(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            digest = root / "framing.jsonl"
            digest_file(digest, [{"ok": False, "kind": "entry", "entry": "X.MES"}])
            report = framing.audit(digest, root / "unused.arc")

        self.assertEqual(1, report["skipped_unframed"])
        self.assertEqual(0, report["entry_count"])
        self.assertFalse(report["equivalent"])

    def test_an_empty_comparison_is_not_equivalent(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            digest = root / "framing.jsonl"
            digest_file(digest, [])
            report = framing.audit(digest, root / "unused.arc")

        self.assertFalse(report["equivalent"])


class CommandLineTests(unittest.TestCase):
    def test_a_non_positive_limit_fails_closed(self) -> None:
        arguments = ["--digest", "d.jsonl", "--arc", "a.arc", "--limit", "0"]
        self.assertEqual(2, framing.main(arguments))

    def test_a_missing_digest_reports_rather_than_raises(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            missing = Path(directory) / "absent.jsonl"
            arguments = ["--digest", str(missing), "--arc", "a.arc"]
            self.assertEqual(2, framing.main(arguments))


if __name__ == "__main__":
    unittest.main()
