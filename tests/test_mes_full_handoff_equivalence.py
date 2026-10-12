from __future__ import annotations

from contextlib import redirect_stderr, redirect_stdout
from copy import deepcopy
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


def signed(payload: dict) -> dict:
    result = deepcopy(payload)
    result.pop("payload_sha256", None)
    result["payload_sha256"] = handoff.fingerprint(result)
    return result


def corpus_hash(rows: list[tuple[str, str, str]]) -> str:
    # Independent expression of the public digest's ordered line contract.
    text = "".join(f"{name}\t{entry_hash}\t{payload_hash}\n" for name, entry_hash, payload_hash in rows)
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


class FullHandoffAuditTests(unittest.TestCase):
    def setUp(self) -> None:
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.arc = self.root / "mes.arc"
        self.digest = self.root / "digest.jsonl"
        self.payloads = {"A.MES": b"\0\0\0\0\0", "B.LIB": b"\0\0\0\0\0\0"}
        _build_archive(self.arc, [*self.payloads.items(), ("IGNORED.DAT", b"authored")])
        self.archive_hash = hashlib.sha256(self.arc.read_bytes()).hexdigest()
        self.header = {
            "kind": "header", "schema": audit.DIGEST_SCHEMA,
            "handoff_schema": audit.HANDOFF_SCHEMA,
            "archive_sha256": self.archive_hash, "components": list(audit.COMPONENTS),
        }
        self.actual = {
            name: handoff.build_handoff(payload, self.source(name))
            for name, payload in self.payloads.items()
        }
        self.authoritative = {}
        self.rows = []
        for name, actual in self.actual.items():
            # A synthetic GD-shaped fixture; deliberately do not use the
            # projection under test when constructing its expected hash.
            expected = deepcopy(actual)
            expected["producer"]["implementation"] = "godot_gdscript_phase1_4"
            expected = signed(expected)
            self.authoritative[name] = expected
            components = {key: handoff.fingerprint(expected[key]) for key in audit.COMPONENTS}
            components.update({
                f"references.{key}": handoff.fingerprint(value)
                for key, value in expected["references"].items()
            })
            self.rows.append({
                "kind": "entry", "entry": name, "ok": True,
                "entry_sha256": hashlib.sha256(self.payloads[name]).hexdigest(),
                "payload_sha256": expected["payload_sha256"], "components": components,
            })
        self.write_digest()

    def source(self, name: str) -> dict[str, str]:
        return {"archive": self.arc.name, "entry": name, "archive_sha256": self.archive_hash}

    def write_digest(self, rows: list[dict] | None = None) -> None:
        rows = self.rows if rows is None else rows
        footer = {
            "kind": "footer", "entry_count": len(rows), "failed": 0,
            "corpus_handoff_sha256": corpus_hash([
                (row["entry"], row["entry_sha256"], row["payload_sha256"]) for row in rows
            ]),
        }
        lines = [self.header, *rows, footer]
        self.digest.write_text("\n".join(json.dumps(row) for row in lines) + "\n", encoding="utf-8")

    def run_audit(self, limit: int | None = None, jobs: int = 1) -> dict:
        return audit.audit(self.digest, self.arc, limit, full_payload=True, jobs=jobs)

    def run_cli(self, *extra: str) -> tuple[int, str, str]:
        stdout, stderr = io.StringIO(), io.StringIO()
        with redirect_stdout(stdout), redirect_stderr(stderr):
            code = audit.main(["--digest", str(self.digest), "--arc", str(self.arc), *extra])
        return code, stdout.getvalue(), stderr.getvalue()

    def test_producer_only_projection_separates_actual_and_baseline_hashes(self) -> None:
        report = self.run_audit()
        full = report["full_payload"]
        self.assertEqual(report["schema"], "kakyu_mes_handoff_equivalence/v2")
        self.assertTrue(report["equivalent"])
        self.assertTrue(full["equivalent"])
        self.assertEqual(full["policy"], "producer_implementation_only/v1")
        self.assertEqual(full["scope"], "complete_corpus")
        self.assertEqual(full["hash_scope"], "compared_entries_in_digest_order")
        self.assertEqual((full["source_entry_count"], full["compared"], full["verified_payloads"]), (2, 2, 2))
        self.assertEqual((full["payload_equal"], full["python_errors"]), (2, 0))
        self.assertEqual(full["authoritative_corpus_sha256"], full["measured_authoritative_corpus_sha256"])
        self.assertEqual(full["authoritative_corpus_sha256"], full["baseline_projected_python_corpus_sha256"])
        self.assertNotEqual(full["actual_python_corpus_sha256"], full["baseline_projected_python_corpus_sha256"])
        for entry in report["entries"]:
            name, detail = entry["entry"], entry["full_payload"]
            self.assertEqual(detail["producer_implementation"], "python_phase1_4")
            self.assertEqual(detail["actual_python_payload_sha256"], self.actual[name]["payload_sha256"])
            self.assertEqual(detail["authoritative_payload_sha256"], self.authoritative[name]["payload_sha256"])
            self.assertEqual(detail["authoritative_payload_sha256"], detail["baseline_projected_python_payload_sha256"])
            self.assertTrue(detail["source_identity_equal"])
            self.assertTrue(detail["payload_equal"])

    def test_full_mode_builds_once_per_entry_and_derives_components_from_that_payload(self) -> None:
        actual_builder = handoff.build_handoff
        with patch.object(audit, "build_components", side_effect=AssertionError("second decode")):
            with patch.object(audit, "build_handoff", wraps=actual_builder) as producer:
                report = self.run_audit()
        self.assertTrue(report["full_payload"]["equivalent"])
        self.assertEqual(producer.call_count, 2)
        self.assertEqual(producer.call_args_list[0].args, (self.payloads["A.MES"], self.source("A.MES")))
        self.assertEqual(producer.call_args_list[1].args, (self.payloads["B.LIB"], self.source("B.LIB")))

    def test_noncomponent_field_drift_is_not_hidden_by_component_equality(self) -> None:
        changed = deepcopy(self.authoritative["A.MES"])
        changed["compatibility"]["unknown_v1_field"] = "reject"
        self.rows[0]["payload_sha256"] = signed(changed)["payload_sha256"]
        self.write_digest()
        report = self.run_audit()
        self.assertTrue(report["equivalent"])
        self.assertFalse(report["full_payload"]["equivalent"])
        self.assertEqual(report["full_payload"]["payload_equal"], 1)
        self.assertEqual(report["full_payload"]["python_errors"], 0)
        self.assertFalse(report["entries"][0]["full_payload"]["payload_equal"])
        self.assertEqual(self.run_cli("--full-payload", "--require-equivalent")[0], 0)
        self.assertEqual(self.run_cli("--require-full-equivalent")[0], 1)

    def test_runtime_producer_cannot_impersonate_gd_even_with_a_valid_hash(self) -> None:
        def gd_producer(payload: bytes, source: dict) -> dict:
            return deepcopy(self.authoritative[source["entry"]])
        with patch.object(audit, "build_handoff", side_effect=gd_producer):
            report = self.run_audit()
            self.assertEqual(self.run_cli("--require-full-equivalent")[0], 1)
        full = report["full_payload"]
        self.assertFalse(full["equivalent"])
        self.assertEqual(full["python_errors"], 2)
        self.assertEqual(full["verified_payloads"], 0)
        self.assertIsNone(full["actual_python_corpus_sha256"])
        self.assertIsNone(full["baseline_projected_python_corpus_sha256"])
        self.assertIn("actual Python producer", report["entries"][0]["python_error"])

    def test_corrupt_actual_payload_signature_cannot_be_projected_or_partially_hashed(self) -> None:
        def corrupt_producer(payload: bytes, source: dict) -> dict:
            result = deepcopy(self.actual[source["entry"]])
            if source["entry"] == "A.MES":
                result["payload_sha256"] = "0" * 64
            return result
        with patch.object(audit, "build_handoff", side_effect=corrupt_producer):
            report = self.run_audit()
        full = report["full_payload"]
        self.assertFalse(full["equivalent"])
        self.assertEqual((full["verified_payloads"], full["python_errors"]), (1, 1))
        self.assertIsNone(full["actual_python_corpus_sha256"])
        self.assertIsNone(full["baseline_projected_python_corpus_sha256"])
        self.assertIsNotNone(full["measured_authoritative_corpus_sha256"])
        self.assertIsNone(report["entries"][0]["full_payload"]["actual_python_payload_sha256"])

    def test_malformed_or_incomplete_producer_results_are_reported_as_errors(self) -> None:
        for malformed in (None, [], {}, {"producer": None}, {"producer": "python_phase1_4"},
                          {"producer": {"implementation": "python_phase1_4"}}):
            with self.subTest(malformed=malformed):
                with patch.object(audit, "build_handoff", return_value=malformed):
                    report = self.run_audit()
                    self.assertEqual(self.run_cli("--require-full-equivalent")[0], 1)
                self.assertFalse(report["full_payload"]["equivalent"])
                self.assertEqual(report["full_payload"]["python_errors"], 2)
                self.assertIsNone(report["full_payload"]["actual_python_corpus_sha256"])
                self.assertTrue(all(entry["python_error"] for entry in report["entries"]))

    def test_wrong_source_identity_is_rejected_even_when_resigned(self) -> None:
        for key, value in (("archive", "other.arc"), ("entry", "OTHER.MES"), ("archive_sha256", "0" * 64)):
            with self.subTest(key=key):
                def wrong_source(payload: bytes, source: dict) -> dict:
                    result = deepcopy(self.actual[source["entry"]])
                    result["source_identity"][key] = value
                    return signed(result)
                with patch.object(audit, "build_handoff", side_effect=wrong_source):
                    report = self.run_audit()
                self.assertFalse(report["full_payload"]["equivalent"])
                self.assertEqual(report["full_payload"]["python_errors"], 2)
                self.assertFalse(report["entries"][0]["full_payload"]["source_identity_equal"])

    def test_digest_entry_name_must_match_exact_archive_spelling(self) -> None:
        self.rows[0]["entry"] = "a.mes"
        self.write_digest()
        report = self.run_audit()
        self.assertFalse(report["full_payload"]["equivalent"])
        detail = report["entries"][0]["full_payload"]
        self.assertEqual(detail["archive_entry"], "A.MES")
        self.assertFalse(detail["source_identity_equal"])

    def test_corrupt_source_and_source_changed_during_full_audit_fail_closed(self) -> None:
        self.header["archive_sha256"] = "0" * 64
        self.write_digest()
        with self.assertRaisesRegex(audit.HandoffAuditError, "archive SHA-256"):
            self.run_audit()
        self.header["archive_sha256"] = self.archive_hash
        self.write_digest()
        with patch.object(audit, "sha256_file", return_value="0" * 64):
            with self.assertRaisesRegex(audit.HandoffAuditError, "changed during"):
                self.run_audit()

    def test_entry_digest_source_hash_mismatch_cannot_pass_full_gate(self) -> None:
        self.rows[0]["entry_sha256"] = "0" * 64
        self.write_digest()
        report = self.run_audit()
        self.assertEqual(report["entry_sha256_mismatches"], ["A.MES"])
        self.assertFalse(report["full_payload"]["equivalent"])
        self.assertNotEqual(report["full_payload"]["authoritative_corpus_sha256"],
                            report["full_payload"]["baseline_projected_python_corpus_sha256"])

    def test_corpus_hash_and_limit_follow_digest_order_not_archive_order(self) -> None:
        self.write_digest(list(reversed(self.rows)))
        report = self.run_audit()
        self.assertEqual([entry["entry"] for entry in report["entries"]], ["B.LIB", "A.MES"])
        self.assertTrue(report["full_payload"]["equivalent"])
        expected = corpus_hash([
            (name, hashlib.sha256(self.payloads[name]).hexdigest(), self.actual[name]["payload_sha256"])
            for name in ("B.LIB", "A.MES")
        ])
        self.assertEqual(report["full_payload"]["actual_python_corpus_sha256"], expected)
        partial = self.run_audit(1)
        self.assertEqual([entry["entry"] for entry in partial["entries"]], ["B.LIB"])
        self.assertEqual(partial["full_payload"]["scope"], "partial")
        self.assertFalse(partial["full_payload"]["equivalent"])
        self.assertNotEqual(partial["full_payload"]["measured_authoritative_corpus_sha256"],
                            partial["full_payload"]["authoritative_corpus_sha256"])

    def test_explicit_limit_never_certifies_whole_corpus_even_when_every_entry_matches(self) -> None:
        for limit in (1, 2, 10):
            with self.subTest(limit=limit):
                report = self.run_audit(limit)
                self.assertFalse(report["full_payload"]["equivalent"])
                self.assertEqual(report["full_payload"]["scope"], "partial")
                self.assertEqual(self.run_cli("--require-full-equivalent", "--limit", str(limit))[0], 1)
        self.assertEqual(self.run_audit(10)["full_payload"]["baseline_projected_python_corpus_sha256"],
                         self.run_audit()["full_payload"]["authoritative_corpus_sha256"])

    def test_selected_missing_and_empty_digests_do_not_certify_whole_corpus(self) -> None:
        for rows in (self.rows[:1], [*self.rows, {**self.rows[0], "entry": "MISSING.MES"}], []):
            with self.subTest(count=len(rows)):
                self.write_digest(rows)
                report = self.run_audit()
                self.assertFalse(report["full_payload"]["equivalent"])
                self.assertEqual(report["full_payload"]["scope"], "partial")
                self.assertEqual(self.run_cli("--require-full-equivalent")[0], 1)
        self.assertIsNone(report["full_payload"]["actual_python_corpus_sha256"])
        self.assertIsNone(report["full_payload"]["measured_authoritative_corpus_sha256"])

    def test_full_gate_implies_v2_and_writes_atomic_report_with_explicit_cli_scope(self) -> None:
        destination = self.root / "new" / "report.json"
        code, stdout, stderr = self.run_cli("--require-full-equivalent", "--json", str(destination))
        self.assertEqual((code, stderr), (0, ""))
        report = json.loads(destination.read_text(encoding="utf-8"))
        self.assertEqual(report["schema"], audit.FULL_PAYLOAD_SCHEMA)
        self.assertTrue(report["full_payload"]["equivalent"])
        self.assertIn("scope=component_fingerprints full_payload=compared", stdout)
        self.assertIn("policy=producer_implementation_only/v1 scope=complete_corpus equivalent=true", stdout)
        self.assertIn("actual_python_corpus_sha256=", stdout)
        self.assertIn("baseline_projected_python_corpus_sha256=", stdout)
        self.assertFalse(destination.with_name(destination.name + ".tmp").exists())

    def test_default_mode_retains_v1_component_contract(self) -> None:
        with patch.object(audit, "build_handoff", side_effect=AssertionError("unexpected full producer")):
            report = audit.audit(self.digest, self.arc)
            code, stdout, stderr = self.run_cli("--require-equivalent")
        self.assertEqual((code, stderr), (0, ""))
        self.assertEqual(report["schema"], audit.SCHEMA)
        self.assertNotIn("full_payload", report)
        self.assertTrue(report["equivalent"])
        self.assertIn("scope=component_fingerprints full_payload=not_compared", stdout)
        self.assertTrue(all("full_payload" not in row for row in report["entries"]))

    def test_full_mode_reuses_digest_validation_and_source_output_protection(self) -> None:
        for destination in (self.arc, self.digest):
            with self.subTest(destination=destination):
                before = destination.read_bytes()
                self.assertEqual(self.run_cli("--require-full-equivalent", "--json", str(destination))[0], 2)
                self.assertEqual(destination.read_bytes(), before)
        lines = self.digest.read_text(encoding="utf-8").splitlines()
        footer = json.loads(lines[-1])
        footer["corpus_handoff_sha256"] = "0" * 64
        self.digest.write_text("\n".join([*lines[:-1], json.dumps(footer)]) + "\n", encoding="utf-8")
        self.assertEqual(self.run_cli("--require-full-equivalent")[0], 2)

    # TD-40 (c): `--jobs N` changes how entries are compared, never the report.

    def test_a_parallel_run_reports_exactly_what_the_serial_run_reports(self) -> None:
        serial = self.run_audit()
        parallel = self.run_audit(jobs=2)
        self.assertEqual(parallel, serial)
        self.assertEqual(json.dumps(parallel, sort_keys=False), json.dumps(serial, sort_keys=False))
        self.assertTrue(parallel["full_payload"]["equivalent"])

    def test_a_parallel_run_keeps_digest_order_limits_and_failures(self) -> None:
        self.write_digest(list(reversed(self.rows)))
        self.assertEqual(self.run_audit(jobs=2), self.run_audit())
        self.assertEqual([entry["entry"] for entry in self.run_audit(1, jobs=2)["entries"]], ["B.LIB"])
        self.assertEqual(self.run_audit(1, jobs=2), self.run_audit(1))
        changed = deepcopy(self.authoritative["A.MES"])
        changed["compatibility"]["unknown_v1_field"] = "reject"
        self.rows[0]["payload_sha256"] = signed(changed)["payload_sha256"]
        self.rows[0]["entry_sha256"] = "0" * 64
        self.write_digest()
        parallel = self.run_audit(jobs=2)
        self.assertEqual(parallel, self.run_audit())
        self.assertFalse(parallel["full_payload"]["equivalent"])
        self.assertEqual(parallel["entry_sha256_mismatches"], ["A.MES"])

    def test_the_component_only_mode_is_also_identical_in_parallel(self) -> None:
        serial = audit.audit(self.digest, self.arc)
        self.assertEqual(audit.audit(self.digest, self.arc, jobs=2), serial)
        self.assertNotIn("full_payload", serial)

    def test_the_cli_runs_parallel_and_prints_the_serial_lines(self) -> None:
        serial = self.run_cli("--require-full-equivalent")
        parallel = self.run_cli("--require-full-equivalent", "--jobs", "2")
        self.assertEqual(parallel, serial)
        self.assertEqual(serial[0], 0)

    def test_a_worker_failure_propagates_instead_of_dropping_the_entry(self) -> None:
        from concurrent.futures import Future

        class Boom(RuntimeError):
            pass

        with patch.object(audit, "ProcessPoolExecutor") as pool_class:
            pool = pool_class.return_value
            future = Future()
            future.set_exception(Boom("worker died"))
            pool.submit.return_value = future
            with self.assertRaises(Boom):
                self.run_audit(jobs=2)
            pool.shutdown.assert_called_once_with(wait=True, cancel_futures=True)

    def test_jobs_must_be_positive(self) -> None:
        with self.assertRaisesRegex(audit.HandoffAuditError, "--jobs"):
            self.run_audit(jobs=0)
        code, _stdout, stderr = self.run_cli("--require-full-equivalent", "--jobs", "0")
        self.assertEqual(code, 2)
        self.assertIn("--jobs must be positive", stderr)


class StartOrderTests(unittest.TestCase):
    @staticmethod
    def task(size: int):
        return (True, b"\0" * size, {}, None)

    def test_largest_payload_starts_first_and_ties_keep_digest_position(self) -> None:
        tasks = [self.task(size) for size in (5, 9, 5, 1, 9)]
        self.assertEqual(audit.start_order(tasks), [1, 4, 0, 2, 3])

    def test_the_schedule_is_a_pure_function_of_the_tasks(self) -> None:
        tasks = [self.task(size) for size in (3, 7, 7, 2, 3, 7)]
        first = audit.start_order(tasks)
        self.assertEqual(audit.start_order(list(tasks)), first)
        self.assertEqual(sorted(first), list(range(len(tasks))))

    def test_results_are_yielded_in_task_order_whatever_the_start_order(self) -> None:
        class FakePool:
            def __init__(self, max_workers):
                self.started = []

            def submit(self, function, task):
                from concurrent.futures import Future
                future = Future()
                self.started.append(len(task[1]))
                future.set_result({"size": len(task[1])})
                return future

            def shutdown(self, wait, cancel_futures):
                pass

        tasks = [self.task(size) for size in (2, 8, 4)]
        with patch.object(audit, "ProcessPoolExecutor", FakePool):
            results = list(audit.run_comparisons(iter(tasks), 3))
        self.assertEqual(results, [{"size": 2}, {"size": 8}, {"size": 4}])

    def test_no_tasks_start_no_pool(self) -> None:
        with patch.object(audit, "ProcessPoolExecutor", side_effect=AssertionError("pool for nothing")):
            self.assertEqual(list(audit.run_comparisons(iter([]), 4)), [])


if __name__ == "__main__":
    unittest.main()
