from __future__ import annotations

from contextlib import redirect_stderr, redirect_stdout
import hashlib
import io
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

import audit_mes_handoff_equivalence as audit  # noqa: E402
import mes_analyzer_handoff as handoff  # noqa: E402
from tests.test_extract_kakyu_arc import _build_archive  # noqa: E402


def complete_components(payload: bytes) -> dict:
    """Synthetic complete producer used to exercise the final approval gate."""
    return {
        "container": handoff.handoff_container_component(handoff.build_container(payload)),
        "typed_ir": {"synthetic": "typed"},
        "record_alignment": {"synthetic": "alignment"},
        "references": {name: [] for name in ("messages", "code", "state", "resources")},
        "capability_report": {"synthetic": "capability"},
    }


def digest_row(name: str, payload: bytes) -> dict:
    components = complete_components(payload)
    hashes = {name: handoff.fingerprint(value) for name, value in components.items()}
    hashes.update({f"references.{name}": handoff.fingerprint(value)
                   for name, value in components["references"].items()})
    return {
        "kind": "entry", "entry": name, "ok": True,
        "entry_sha256": hashlib.sha256(payload).hexdigest(),
        "payload_sha256": handoff.fingerprint(components),
        "components": hashes, "counts": {},
    }


def footer(rows: list[dict]) -> dict:
    encoded = "".join(f"{row['entry']}\t{row['entry_sha256']}\t{row['payload_sha256']}\n" for row in rows)
    return {"kind": "footer", "entry_count": len(rows), "failed": 0,
            "corpus_handoff_sha256": hashlib.sha256(encoded.encode("utf-8")).hexdigest()}


class HandoffAuditFixture(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.arc = self.root / "mes.arc"
        self.digest = self.root / "digest.jsonl"
        payloads = [("A.MES", b"\0\0\0\0\0"), ("B.LIB", b"\0\0\0\0\0\0")]
        _build_archive(self.arc, [*payloads, ("IGNORED.DAT", b"synthetic")])
        self.rows = [digest_row(name, payload) for name, payload in payloads]
        self.header = {
            "kind": "header", "schema": audit.DIGEST_SCHEMA,
            "handoff_schema": audit.HANDOFF_SCHEMA,
            "archive_sha256": hashlib.sha256(self.arc.read_bytes()).hexdigest(),
            "components": list(audit.COMPONENTS),
        }
        self.write_digest()

    def write_lines(self, lines: list[dict]) -> None:
        self.digest.write_text("\n".join(json.dumps(line) for line in lines) + "\n", encoding="utf-8")

    def write_digest(self, rows: list[dict] | None = None) -> None:
        selected = self.rows if rows is None else rows
        self.write_lines([self.header, *selected, footer(selected)])

    def run_audit(self, limit: int | None = None) -> dict:
        with patch.object(audit, "build_components", side_effect=complete_components):
            return audit.audit(self.digest, self.arc, limit)

    def run_cli(self, *extra: str) -> int:
        with patch.object(audit, "build_components", side_effect=complete_components):
            with redirect_stdout(io.StringIO()), redirect_stderr(io.StringIO()):
                return audit.main(["--digest", str(self.digest), "--arc", str(self.arc), *extra])


class DigestValidationTests(HandoffAuditFixture):
    def test_valid_exporter_v1_shape_roundtrips(self) -> None:
        header, rows, tail = audit.read_digest(self.digest)
        self.assertEqual(header, self.header)
        self.assertEqual(list(rows), ["A.MES", "B.LIB"])
        self.assertEqual(tail, footer(self.rows))

    def test_missing_footer_and_truncated_json_fail_closed(self) -> None:
        for encoded in (json.dumps(self.header) + "\n", self.digest.read_text()[:-5]):
            with self.subTest(encoded=encoded[-25:]):
                self.digest.write_text(encoded, encoding="utf-8")
                self.assertEqual(self.run_cli("--require-equivalent"), 2)

    def test_invalid_row_order_and_non_objects_are_rejected(self) -> None:
        cases = [
            [self.rows[0], self.header, footer(self.rows[:1])],
            [self.header, self.header, *self.rows, footer(self.rows)],
            [self.header, *self.rows, footer(self.rows), footer(self.rows)],
            [self.header, *self.rows, footer(self.rows), self.rows[0]],
            [self.header, {"kind": "unknown"}, footer([])],
            [self.header, [], footer([])],
        ]
        for lines in cases:
            with self.subTest(lines=lines):
                self.write_lines(lines)
                with self.assertRaises(audit.HandoffAuditError):
                    audit.read_digest(self.digest)

    def test_duplicate_entry_names_are_case_insensitively_rejected(self) -> None:
        rows = [self.rows[0], {**self.rows[0], "entry": "a.mes"}]
        self.write_digest(rows)
        with self.assertRaisesRegex(audit.HandoffAuditError, "duplicate"):
            audit.read_digest(self.digest)

    def test_duplicate_json_keys_are_rejected_before_shadowing(self) -> None:
        self.digest.write_text('{"kind":"header","kind":"footer"}\n', encoding="utf-8")
        with self.assertRaisesRegex(audit.HandoffAuditError, "duplicate JSON key"):
            audit.read_digest(self.digest)

    def test_header_schema_components_and_hash_must_be_valid(self) -> None:
        for field, value in [
            ("schema", "foreign/v1"), ("handoff_schema", "foreign/v1"),
            ("components", ["container"]),
            ("components", [*audit.COMPONENTS, "container"]),
            ("components", [*audit.COMPONENTS[:-1], "unknown"]),
            ("components", {name: 1 for name in audit.COMPONENTS}),
            ("archive_sha256", "deadbeef"), ("archive_sha256", None),
        ]:
            with self.subTest(field=field, value=value):
                header = {**self.header, field: value}
                self.write_lines([header, *self.rows, footer(self.rows)])
                with self.assertRaises(audit.HandoffAuditError):
                    audit.read_digest(self.digest)

    def test_failed_entry_or_footer_cannot_be_skipped(self) -> None:
        for lines in [
            [self.header, {"kind": "entry", "entry": "A.MES", "ok": False}, footer([])],
            [self.header, *self.rows, {**footer(self.rows), "failed": 1}],
            [self.header, *self.rows, {**footer(self.rows), "failed": False}],
            [self.header, *self.rows, {key: value for key, value in footer(self.rows).items() if key != "failed"}],
        ]:
            with self.subTest(lines=lines):
                self.write_lines(lines)
                with self.assertRaises(audit.HandoffAuditError):
                    audit.read_digest(self.digest)

    def test_footer_count_and_ordered_corpus_hash_are_verified(self) -> None:
        for tail in [
            {**footer(self.rows), "entry_count": 1},
            {**footer(self.rows), "entry_count": True},
            {**footer(self.rows), "corpus_handoff_sha256": "0" * 64},
            footer(list(reversed(self.rows))),
        ]:
            with self.subTest(tail=tail):
                self.write_lines([self.header, *self.rows, tail])
                with self.assertRaises(audit.HandoffAuditError):
                    audit.read_digest(self.digest)

    def test_missing_extra_or_malformed_component_hash_is_rejected(self) -> None:
        for components in [
            {name: value for name, value in self.rows[0]["components"].items() if name != "typed_ir"},
            {**self.rows[0]["components"], "unknown": "0" * 64},
            {**self.rows[0]["components"], "typed_ir": "broken"},
            [],
        ]:
            with self.subTest(components=components):
                self.write_digest([{**self.rows[0], "components": components}, self.rows[1]])
                with self.assertRaises(audit.HandoffAuditError):
                    audit.read_digest(self.digest)

    def test_invalid_entry_names_and_identity_hashes_are_rejected(self) -> None:
        for field, value in [("entry", "../A.MES"), ("entry", "A.DAT"), ("entry", "A\t.MES"),
                             ("entry_sha256", "bad"), ("payload_sha256", "bad")]:
            with self.subTest(field=field, value=value):
                self.write_digest([{**self.rows[0], field: value}])
                with self.assertRaises(audit.HandoffAuditError):
                    audit.read_digest(self.digest)


class SourceAndCoverageTests(HandoffAuditFixture):
    def test_full_bound_corpus_with_all_components_is_equivalent(self) -> None:
        report = self.run_audit()
        self.assertTrue(report["equivalent"])
        self.assertEqual(report["compared"], 2)
        self.assertEqual(report["missing_from_archive"], [])
        self.assertEqual(report["schema"], "kakyu_mes_handoff_equivalence/v1")
        self.assertEqual(set(report["per_component"]), set(audit.COMPARISON_COMPONENTS))

    def test_source_hash_mismatch_and_changes_during_audit_fail_closed(self) -> None:
        self.header["archive_sha256"] = "0" * 64
        self.write_digest()
        with self.assertRaisesRegex(audit.HandoffAuditError, "archive SHA-256"):
            self.run_audit()
        self.header["archive_sha256"] = hashlib.sha256(self.arc.read_bytes()).hexdigest()
        self.write_digest()
        with patch.object(audit, "sha256_file", return_value="0" * 64):
            with self.assertRaisesRegex(audit.HandoffAuditError, "changed during"):
                self.run_audit()

    def test_invalid_arc_is_a_reported_error(self) -> None:
        self.arc.write_bytes(b"bad")
        self.header["archive_sha256"] = hashlib.sha256(self.arc.read_bytes()).hexdigest()
        self.write_digest()
        self.assertEqual(self.run_cli("--require-equivalent"), 2)

    def test_selected_digest_never_claims_whole_corpus_equivalence(self) -> None:
        self.write_digest(self.rows[:1])
        report = self.run_audit()
        self.assertFalse(report["equivalent"])
        self.assertTrue(audit.required_components_equal(report, ["typed_ir"]))
        self.assertEqual(self.run_cli("--require-equivalent"), 1)
        self.assertEqual(self.run_cli("--require-components", "container", "typed_ir"), 0)

    def test_limit_cannot_certify_unmeasured_rows(self) -> None:
        report = self.run_audit(1)
        self.assertFalse(report["equivalent"])
        self.assertEqual(report["missing_from_archive"], [])
        self.assertFalse(audit.required_components_equal(report, ["typed_ir"]))
        self.assertEqual(self.run_cli("--require-components", "typed_ir", "--limit", "1"), 1)

    def test_explicit_limit_is_measurement_even_when_it_covers_the_archive(self) -> None:
        self.assertFalse(self.run_audit(10)["equivalent"])

    def test_digest_entry_missing_from_archive_prevents_both_gates(self) -> None:
        self.write_digest([*self.rows, {**self.rows[0], "entry": "MISSING.MES"}])
        report = self.run_audit()
        self.assertFalse(report["equivalent"])
        self.assertEqual(report["missing_from_archive"], ["MISSING.MES"])
        self.assertFalse(audit.required_components_equal(report, ["typed_ir"]))

    def test_entry_identity_mismatch_prevents_all_approval(self) -> None:
        self.rows[0]["entry_sha256"] = "0" * 64
        self.write_digest()
        report = self.run_audit()
        self.assertEqual(report["entry_sha256_mismatches"], ["A.MES"])
        self.assertFalse(report["equivalent"])
        self.assertFalse(audit.required_components_equal(report, ["typed_ir"]))

    def test_empty_digest_cannot_certify_a_component(self) -> None:
        self.write_digest([])
        report = self.run_audit()
        self.assertFalse(report["equivalent"])
        self.assertFalse(audit.required_components_equal(report, ["typed_ir"]))

    def test_absent_producer_is_not_equal_even_when_authority_hashes_an_empty_object(self) -> None:
        for row in self.rows:
            row["components"]["record_alignment"] = handoff.fingerprint({})
        self.write_digest()
        def without_alignment(payload: bytes) -> dict:
            result = complete_components(payload)
            result.pop("record_alignment")
            return result
        with patch.object(audit, "build_components", side_effect=without_alignment):
            report = audit.audit(self.digest, self.arc)
        self.assertEqual(report["per_component"]["record_alignment"], {"not_produced": 2})
        self.assertFalse(report["equivalent"])
        self.assertFalse(audit.required_components_equal(report, ["record_alignment"]))
        self.assertTrue(audit.required_components_equal(report, ["typed_ir"]))

    def test_dotted_reference_component_can_be_gated_from_nested_producer(self) -> None:
        self.assertEqual(self.run_cli("--require-components", "references.state"), 0)

    def test_component_divergence_is_a_measurement_and_fails_selected_gate(self) -> None:
        self.rows[0]["components"]["typed_ir"] = "0" * 64
        self.write_digest()
        self.assertEqual(self.run_cli(), 0)
        self.assertEqual(self.run_cli("--require-components", "typed_ir"), 1)

    def test_report_is_atomically_written_with_parent_directories(self) -> None:
        output = self.root / "new" / "subdirectory" / "report.json"
        self.assertEqual(self.run_cli("--json", str(output)), 0)
        self.assertTrue(json.loads(output.read_text(encoding="utf-8"))["equivalent"])
        self.assertFalse(output.with_name(output.name + ".tmp").exists())

    def test_output_cannot_replace_either_input(self) -> None:
        for output in (self.arc, self.digest):
            with self.subTest(output=output):
                before = output.read_bytes()
                self.assertEqual(self.run_cli("--json", str(output)), 2)
                self.assertEqual(output.read_bytes(), before)

    def test_both_gates_can_be_requested_and_whole_corpus_still_required(self) -> None:
        self.write_digest(self.rows[:1])
        self.assertEqual(self.run_cli("--require-equivalent", "--require-components", "typed_ir"), 1)


if __name__ == "__main__":
    unittest.main()
