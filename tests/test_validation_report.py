from __future__ import annotations

import copy
import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest import mock


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools" / "content_suite"))

import validation_report as reports  # noqa: E402


def sample_report(*, tier: str = "full", cache: str = "not_consulted", cache_dir: str = "", jobs: int = 1) -> dict:
    return reports.make_report(
        [{"name": "합성 검사", "status": "passed", "return_code": 0, "duration_seconds": 0.125}],
        duration_seconds=0.25, run_id="eea84917-7a7f-4e3e-91e5-035a9b290f08",
        coverage=[{
            "id": group_id, "title": title,
            "status": "included" if group_id == "synthetic" else "not_run",
            "reason": "Included in this run." if group_id == "synthetic" else "Source not supplied.",
            "check_count": 1 if group_id == "synthetic" else 0,
        } for group_id, title in reports.COVERAGE_TITLES.items()],
        context={
            "kind": "repository_suite", "elfimage": "", "executable": "",
            "workspace_validation": "not_performed", "tier": tier,
            "cache": cache, "cache_dir": cache_dir, "jobs": jobs,
        },
        original_corpus=False, native_executable_audit=False,
    )


def sample_report_v5() -> dict:
    """A `v5` document as it actually shipped: no `context.jobs` - the
    schema TD-33 superseded."""
    report = sample_report()
    report["schema"] = reports.SCHEMA_V5
    del report["context"]["jobs"]
    return report


def sample_report_v4() -> dict:
    """A `v4` document as it actually shipped: no `context.cache`/`cache_dir`
    and no top-level `cached` - the schema TD-32 part 3b superseded."""
    report = sample_report_v5()
    report["schema"] = reports.SCHEMA_V4
    del report["cached"]
    del report["context"]["cache"]
    del report["context"]["cache_dir"]
    return report


def sample_report_v3() -> dict:
    """A `v3` document as it actually shipped: no `context.tier`, no
    `context.cache`/`cache_dir`, no top-level `cached`, and the old
    `original_corpus == bool(context.elfimage)` invariant (here vacuously
    true, since this fixture selects no source either way)."""
    report = sample_report_v4()
    report["schema"] = reports.SCHEMA_V3
    del report["context"]["tier"]
    return report


class ValidationReportTests(unittest.TestCase):
    def test_envelope_hashes_the_exact_utf8_payload_string(self) -> None:
        report = sample_report()
        envelope = reports.report_envelope(report)
        self.assertEqual({"schema", "payload_json", "payload_sha256"}, set(envelope))
        self.assertEqual(reports.SCHEMA, envelope["schema"])
        self.assertEqual(report, json.loads(envelope["payload_json"]))
        self.assertIn("합성 검사", envelope["payload_json"])
        self.assertEqual(hashlib.sha256(envelope["payload_json"].encode("utf-8")).hexdigest(), envelope["payload_sha256"])
        self.assertEqual(envelope, reports.report_envelope(dict(reversed(list(report.items())))))

    def test_writer_rejects_invalid_contract_before_replacing_existing_report(self) -> None:
        invalid = []
        for field, value in (
            ("schema", "kakyu_content_tools_validation/v99"), ("check_count", 2),
            ("status", "failed"), ("duration_seconds", float("nan")), ("run_id", "not-a-uuid"),
        ):
            report = sample_report()
            report[field] = value
            invalid.append((field, report))
        report = sample_report()
        report["coverage"][1].update(status="included", check_count=0)
        invalid.append(("unrun_coverage", report))
        report = sample_report()
        report["checks"][0]["output_tail"] = "x" * (reports.OUTPUT_TAIL_LIMIT + 1)
        invalid.append(("unbounded_tail", report))
        report = sample_report()
        report["checks"][0]["return_code"] = 1
        invalid.append(("false_pass", report))
        report = sample_report()
        report["coverage"][1] = copy.deepcopy(report["coverage"][0])
        invalid.append(("duplicate_coverage", report))
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "report.json"
            path.write_text("previous report", encoding="utf-8")
            for label, report in invalid:
                with self.subTest(field=label), self.assertRaises(ValueError):
                    reports.write_report(path, report)
                self.assertEqual("previous report", path.read_text(encoding="utf-8"))
                self.assertEqual([], list(path.parent.glob("*.tmp-*")))

    def test_atomic_replace_failure_preserves_old_report_and_cleans_temporary_file(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "report.json"
            path.write_text("previous report", encoding="utf-8")
            with mock.patch.object(reports.os, "replace", side_effect=OSError("locked")):
                with self.assertRaisesRegex(OSError, "locked"):
                    reports.write_report(path, sample_report())
            self.assertEqual("previous report", path.read_text(encoding="utf-8"))
            self.assertEqual([], list(path.parent.glob("*.tmp-*")))

    def test_configuration_error_cannot_carry_completed_checks(self) -> None:
        report = sample_report()
        report.update(status="configuration_error", configuration_error="Missing source.")
        with self.assertRaises(ValueError):
            reports.validate_payload(report)

    def test_overlapping_coverage_groups_are_permitted(self) -> None:
        report = sample_report()
        report["coverage"][1].update(status="included", check_count=1, reason="Same check has two scopes.")
        reports.validate_payload(report)

    def test_source_flags_must_match_nonempty_context_paths(self) -> None:
        for flag, path_field in (("original_corpus", "elfimage"), ("native_executable_audit", "executable")):
            for present_path in (False, True):
                report = sample_report()
                report[flag] = not present_path
                report["context"][path_field] = "fixture-source" if present_path else ""
                with self.subTest(flag=flag, path=present_path), self.assertRaisesRegex(ValueError, "source flags"):
                    reports.validate_payload(report)

    def test_v3_report_still_validates_and_normalizes_to_tier_full(self) -> None:
        v3_report = sample_report_v3()
        reports.validate_payload(v3_report)  # a v3 document remains a complete earlier form
        normalized = reports.normalize_report(v3_report)
        self.assertEqual("full", normalized["context"]["tier"])
        self.assertEqual(0, normalized["cached"])
        self.assertEqual("not_consulted", normalized["context"]["cache"])
        self.assertEqual("", normalized["context"]["cache_dir"])
        self.assertEqual(reports.SCHEMA_V3, normalized["schema"])
        self.assertEqual("full", reports.normalize_report(sample_report(tier="full"))["context"]["tier"])

    def test_v4_report_still_validates_and_normalizes_to_cache_not_consulted(self) -> None:
        v4_report = sample_report_v4()
        reports.validate_payload(v4_report)  # a v4 document remains a complete earlier form
        normalized = reports.normalize_report(v4_report)
        self.assertEqual("full", normalized["context"]["tier"])
        self.assertEqual(0, normalized["cached"])
        self.assertEqual("not_consulted", normalized["context"]["cache"])
        self.assertEqual("", normalized["context"]["cache_dir"])
        self.assertEqual(reports.SCHEMA_V4, normalized["schema"])

    def test_v5_report_still_validates_and_normalizes_to_jobs_one(self) -> None:
        v5_report = sample_report_v5()
        reports.validate_payload(v5_report)  # a v5 document remains a complete earlier form
        normalized = reports.normalize_report(v5_report)
        self.assertEqual(1, normalized["context"]["jobs"])
        self.assertEqual("not_consulted", normalized["context"]["cache"])
        self.assertEqual(reports.SCHEMA_V5, normalized["schema"])
        self.assertEqual(0, normalized["cached"])  # v5's own cached count is preserved, not reset

    def test_v6_cached_rows_are_counted_and_shaped(self) -> None:
        report = sample_report(cache="consulted", cache_dir="analysis/validation_cache")
        report["checks"].append({
            "name": "cached fixture", "status": "passed", "return_code": 0, "duration_seconds": 0,
            "cached": True, "cached_at": "2026-09-21T00:00:00+00:00",
            "cached_run_id": "eea84917-7a7f-4e3e-91e5-035a9b290f08",
        })
        report["check_count"] = 2
        report["passed"] = 2
        report["cached"] = 1
        for group in report["coverage"]:
            if group["id"] == "synthetic":
                group["check_count"] = 2
        reports.validate_payload(report)
        normalized = reports.normalize_report(report)
        self.assertIs(report, normalized)  # a v5 payload is returned unchanged

    def test_v5_cached_count_must_match_cached_rows(self) -> None:
        report = sample_report(cache="consulted", cache_dir="analysis/validation_cache")
        report["checks"][0].update(cached=True, cached_at="2026-09-21T00:00:00+00:00", cached_run_id="fixture-run")
        report["checks"][0]["duration_seconds"] = 0
        with self.assertRaisesRegex(ValueError, "cached"):
            reports.validate_payload(report)  # report["cached"] is still 0
        report["cached"] = 1
        reports.validate_payload(report)

    def test_v5_cache_fields_must_all_be_present_together(self) -> None:
        report = sample_report(cache="consulted", cache_dir="analysis/validation_cache")
        report["checks"][0]["cached"] = True
        with self.assertRaisesRegex(ValueError, "cached"):
            reports.validate_payload(report)

    def test_v5_not_consulted_cache_cannot_report_cached_checks(self) -> None:
        report = sample_report(cache="not_consulted")
        report["checks"][0].update(
            cached=True, cached_at="2026-09-21T00:00:00+00:00",
            cached_run_id="eea84917-7a7f-4e3e-91e5-035a9b290f08", duration_seconds=0,
        )
        report["cached"] = 1
        with self.assertRaisesRegex(ValueError, "not_consulted"):
            reports.validate_payload(report)

    def test_v5_source_flags_disagree_with_tier_are_rejected(self) -> None:
        for tier in ("archive_quick", "full"):
            report = sample_report(tier=tier)
            report["context"]["elfimage"] = "fixture-source"
            report["original_corpus"] = True
            reports.validate_payload(report)
            report["original_corpus"] = False
            with self.subTest(tier=tier), self.assertRaisesRegex(ValueError, "source flags"):
                reports.validate_payload(report)
        local_report = sample_report(tier="local")
        local_report["context"]["elfimage"] = "fixture-source"
        local_report["original_corpus"] = False
        reports.validate_payload(local_report)  # a local-tier run never claims original-corpus coverage
        local_report["original_corpus"] = True
        with self.assertRaisesRegex(ValueError, "source flags"):
            reports.validate_payload(local_report)

    def test_unknown_tier_is_rejected(self) -> None:
        report = sample_report()
        report["context"]["tier"] = "archive_slow"
        with self.assertRaisesRegex(ValueError, "context"):
            reports.validate_payload(report)

    def test_zero_checks_cannot_claim_success(self) -> None:
        report = sample_report()
        report.update(checks=[], check_count=0, passed=0, failed=0)
        for group in report["coverage"]:
            group.update(status="not_run", check_count=0)
        with self.assertRaisesRegex(ValueError, "status"):
            reports.validate_payload(report)
        report.update(status="configuration_error", configuration_error="No checks were planned.")
        reports.validate_payload(report)

    def test_launch_errors_and_timeouts_require_null_exit_codes(self) -> None:
        for status, return_code, valid in (
            ("error", None, True), ("timeout", None, True), ("failed", 7, True),
            ("failed", None, False), ("error", 7, False), ("timeout", 7, False),
        ):
            report = sample_report()
            report.update(status="failed", passed=0, failed=1)
            report["checks"][0].update(status=status, return_code=return_code)
            with self.subTest(status=status, code=return_code):
                if valid:
                    reports.validate_payload(report)
                else:
                    with self.assertRaisesRegex(ValueError, "check result"):
                        reports.validate_payload(report)


if __name__ == "__main__":
    unittest.main()
