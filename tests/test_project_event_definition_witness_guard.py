"""TD-37: the v6 projection fails closed on absent or stale witness
evidence instead of silently dropping its witness-derived rows.

Synthetic fixtures only - no archive, no original data. Covers the shared
loader's checked variant and resolver in `tools/project_event_definition_v4.py`
(the legacy `load_witness_index` keeps its silent behaviour for the frozen
v4/v5 producers), the v6 producer's flag wiring, and the batch driver's
preflight, status parsing and summary line.
"""
from __future__ import annotations

import argparse
import contextlib
import io
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

import project_event_definition_v4 as p4  # noqa: E402
import project_event_definition_v5 as p5  # noqa: E402
import project_event_definition_v6 as p6  # noqa: E402
import project_event_definitions_batch as batch  # noqa: E402

HASH = "a" * 64
OTHER_HASH = "b" * 64
FLOW_SCHEMA = "kakyu_event_analysis_group/v14"


def _write(path: Path, document: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(document), encoding="utf-8")


def _request(route_id="r1", variant_id="v1", index=204):
    return {"kind": "shift", "route_id": route_id, "variant_id": variant_id,
            "cell": {"storage": "banked_u16", "bank": 0, "index": index}, "entry": 80, "steps": [7, -7, 1, -1]}


def _done_probe(route_id="r1", variant_id="v1"):
    return {"kind": "done_probe", "route_id": route_id, "variant_id": variant_id, "cells": []}


class Corpus:
    """A temporary `<root>/witnesses` + `<root>/witness_requests` pair."""

    def __init__(self, testcase: unittest.TestCase):
        self._tmp = tempfile.TemporaryDirectory()
        testcase.addCleanup(self._tmp.cleanup)
        self.root = Path(self._tmp.name)
        self.witnesses_dir = str(self.root / "witnesses")

    def add_requests(self, stem, requests, payload_sha256=HASH):
        _write(self.root / "witness_requests" / ("%s.json" % stem), {
            "schema": "kakyu_event_effect_witness_request/v1", "group_id": stem, "profile": stem,
            "payload_sha256": payload_sha256, "requests": requests,
        })

    def add_results(self, stem, results, payload_sha256=HASH):
        _write(self.root / "witnesses" / ("%s.json" % stem), {
            "schema": "kakyu_event_effect_witness/v1", "group_id": stem, "profile": stem,
            "payload_sha256": payload_sha256, "results": results,
        })

    def add_whole(self, stem, payload_sha256=HASH):
        self.add_requests(stem, [_request(), _done_probe()], payload_sha256)
        self.add_results(stem, [
            {"request_index": 0, "kind": "set", "entry": 80, "final": 81},
            {"request_index": 1, "gates": [{"storage": "global_u8", "bank": 0, "index": 905}]},
        ], payload_sha256)


def _match(stem, payload_sha256=HASH, schema="kakyu_event_analysis_group/v6"):
    return {"stem": stem, "doc": {"schema": schema, "payload_sha256": payload_sha256}, "group_id": stem, "routes": []}


class LegacyLoaderTests(unittest.TestCase):
    def test_the_frozen_loader_still_returns_empty_indexes_for_an_absent_corpus(self):
        corpus = Corpus(self)
        self.assertEqual(p4.load_witness_index("s1", corpus.witnesses_dir), ({}, {}))

    def test_the_frozen_loader_does_not_check_the_profile_hash(self):
        corpus = Corpus(self)
        corpus.add_whole("s1", payload_sha256=OTHER_HASH)
        shift, done = p4.load_witness_index("s1", corpus.witnesses_dir)
        self.assertEqual(len(shift), 1)
        self.assertEqual(len(done), 1)


class CheckedLoaderTests(unittest.TestCase):
    def test_no_request_file_means_the_plan_was_not_run(self):
        corpus = Corpus(self)
        shift, done, status = p4.load_witness_index_checked("s1", corpus.witnesses_dir, HASH)
        self.assertEqual((shift, done), ({}, {}))
        self.assertEqual(status["problem"], "no_request_file")
        self.assertFalse(status["request_file"])

    def test_requests_without_a_witness_file(self):
        corpus = Corpus(self)
        corpus.add_requests("s1", [_request()])
        _shift, _done, status = p4.load_witness_index_checked("s1", corpus.witnesses_dir, HASH)
        self.assertEqual(status["problem"], "no_witness_file")
        self.assertEqual(status["requests"], 1)

    def test_an_empty_plan_needs_no_witness_file(self):
        corpus = Corpus(self)
        corpus.add_requests("s1", [])
        _shift, _done, status = p4.load_witness_index_checked("s1", corpus.witnesses_dir, HASH)
        self.assertIsNone(status["problem"])
        self.assertEqual(status["requests"], 0)

    def test_a_request_file_with_another_profile_hash_is_stale(self):
        corpus = Corpus(self)
        corpus.add_whole("s1", payload_sha256=OTHER_HASH)
        shift, done, status = p4.load_witness_index_checked("s1", corpus.witnesses_dir, HASH)
        self.assertEqual(status["problem"], "stale")
        self.assertIs(status["hash_match"], False)
        self.assertEqual((shift, done), ({}, {}))

    def test_a_witness_file_with_another_profile_hash_is_stale(self):
        corpus = Corpus(self)
        corpus.add_requests("s1", [_request()])
        corpus.add_results("s1", [{"request_index": 0, "kind": "set", "entry": 80, "final": 81}], OTHER_HASH)
        _shift, _done, status = p4.load_witness_index_checked("s1", corpus.witnesses_dir, HASH)
        self.assertEqual(status["problem"], "stale")

    def test_a_profile_without_a_payload_hash_never_matches(self):
        corpus = Corpus(self)
        corpus.add_whole("s1")
        for missing in (None, ""):
            _s, _d, status = p4.load_witness_index_checked("s1", corpus.witnesses_dir, missing)
            self.assertEqual(status["problem"], "stale")

    def test_whole_evidence_indexes_and_counts_the_results_used(self):
        corpus = Corpus(self)
        corpus.add_requests("s1", [_request(), _request(index=205), _done_probe()])
        corpus.add_results("s1", [
            {"request_index": 0, "kind": "set", "entry": 80, "final": 81},
            {"request_index": 1, "error": "unknown route_id r1"},
            {"request_index": 2, "gates": []},
        ])
        shift, done, status = p4.load_witness_index_checked("s1", corpus.witnesses_dir, HASH)
        self.assertIsNone(status["problem"])
        self.assertIs(status["hash_match"], True)
        self.assertEqual(status["requests"], 3)
        self.assertEqual(status["results_used"], 2)  # the error row is not a used result
        self.assertIn(("r1", "v1", ("banked_u16", 0, 204)), shift)
        self.assertIn(("r1", "v1"), done)


class ResolveWitnessIndexesTests(unittest.TestCase):
    def test_an_absent_corpus_directory_is_refused(self):
        corpus = Corpus(self)
        with self.assertRaises(p4.WitnessRefusal) as ctx:
            p4.resolve_witness_indexes("site.1", [_match("s1")], corpus.witnesses_dir, allow_missing=False)
        self.assertIn("--allow-missing-witnesses", str(ctx.exception))

    def test_a_missing_pair_for_a_witness_capable_site_is_refused(self):
        corpus = Corpus(self)
        corpus.add_whole("other")  # the directories exist; this site's own pair does not
        with self.assertRaises(p4.WitnessRefusal) as ctx:
            p4.resolve_witness_indexes("site.1", [_match("s1")], corpus.witnesses_dir, allow_missing=False)
        self.assertIn("s1", str(ctx.exception))
        self.assertIn("plan_event_effect_witnesses", str(ctx.exception))

    def test_every_matched_profile_is_checked_not_only_the_first(self):
        corpus = Corpus(self)
        corpus.add_whole("s1")
        with self.assertRaises(p4.WitnessRefusal) as ctx:
            p4.resolve_witness_indexes(
                "site.1", [_match("s1"), _match("s2")], corpus.witnesses_dir, allow_missing=False)
        self.assertIn("s2", str(ctx.exception))

    def test_a_hash_mismatched_result_is_refused(self):
        corpus = Corpus(self)
        corpus.add_whole("s1", payload_sha256=OTHER_HASH)
        with self.assertRaises(p4.WitnessRefusal) as ctx:
            p4.resolve_witness_indexes("site.1", [_match("s1")], corpus.witnesses_dir, allow_missing=False)
        self.assertIn("payload_sha256", str(ctx.exception))

    def test_the_opt_out_still_refuses_stale_evidence(self):
        corpus = Corpus(self)
        corpus.add_whole("s1", payload_sha256=OTHER_HASH)
        with self.assertRaises(p4.WitnessRefusal):
            p4.resolve_witness_indexes("site.1", [_match("s1")], corpus.witnesses_dir, allow_missing=True)

    def test_the_opt_out_reports_missing_evidence_instead_of_refusing(self):
        corpus = Corpus(self)  # neither directory exists
        shift, done, report = p4.resolve_witness_indexes(
            "site.1", [_match("s1"), _match("s2")], corpus.witnesses_dir, allow_missing=True)
        self.assertEqual((shift, done), ({}, {}))
        self.assertEqual(report["missing"], [("s1", "no_request_file"), ("s2", "no_request_file")])
        self.assertEqual((report["stems"], report["requests"], report["results_used"]), (2, 0, 0))

    def test_whole_evidence_merges_every_matched_profile(self):
        corpus = Corpus(self)
        corpus.add_whole("s1")
        corpus.add_requests("s2", [_request(route_id="r2", index=300)])
        corpus.add_results("s2", [{"request_index": 0, "kind": "add", "entry": 5, "final": 9}])
        shift, done, report = p4.resolve_witness_indexes(
            "site.1", [_match("s1"), _match("s2")], corpus.witnesses_dir, allow_missing=False)
        self.assertEqual(report["missing"], [])
        self.assertEqual((report["stems"], report["requests"], report["results_used"]), (2, 3, 3))
        self.assertEqual(len(shift), 2)
        self.assertEqual(len(done), 1)

    def test_a_flow_profile_carries_no_witnesses_and_is_skipped(self):
        corpus = Corpus(self)  # no corpus at all
        shift, done, report = p4.resolve_witness_indexes(
            "site.1", [_match("flow", schema=FLOW_SCHEMA)], corpus.witnesses_dir, allow_missing=False)
        self.assertEqual((shift, done), ({}, {}))
        self.assertEqual(report["stems"], 0)


class ProducerWiringTests(unittest.TestCase):
    """`run_site_v6` decides `args.require_witnesses`; v4/v5 never define it."""

    def _run(self, allow_missing):
        args = argparse.Namespace(site="site.1", names="n", profiles_dir="p", allow_missing_witnesses=allow_missing)
        seen = {}

        def fake_v5(received):
            seen["require_witnesses"] = received.require_witnesses
            return 0

        with mock.patch.object(p6.ped, "load_registry", return_value=({}, "x")), \
                mock.patch.object(p6.ped, "find_registry_row_by_id", return_value={"id": "site.1"}), \
                mock.patch.object(p6.ped, "load_profiles", return_value={}), \
                mock.patch.object(p5, "run_site_v5", side_effect=fake_v5),                 contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(p6.run_site_v6(args), 0)
        return seen["require_witnesses"]

    def test_v6_requires_witnesses_by_default(self):
        self.assertIs(self._run(allow_missing=False), True)

    def test_the_opt_out_flag_turns_the_requirement_off(self):
        self.assertIs(self._run(allow_missing=True), False)

    def test_the_v6_parser_defines_the_opt_out_and_v4_v5_do_not(self):
        source_v4 = (ROOT / "tools" / "project_event_definition_v4.py").read_text(encoding="utf-8")
        source_v5 = (ROOT / "tools" / "project_event_definition_v5.py").read_text(encoding="utf-8")
        source_v6 = (ROOT / "tools" / "project_event_definition_v6.py").read_text(encoding="utf-8")
        self.assertNotIn('add_argument("--allow-missing-witnesses"', source_v4)
        self.assertNotIn('add_argument("--allow-missing-witnesses"', source_v5)
        self.assertIn('add_argument("--allow-missing-witnesses"', source_v6)


class BatchGuardTests(unittest.TestCase):
    def test_preflight_names_each_absent_corpus_directory(self):
        corpus = Corpus(self)
        refusal = batch.witness_preflight(corpus.witnesses_dir)
        self.assertIsNotNone(refusal)
        self.assertIn("--allow-missing-witnesses", refusal)
        (corpus.root / "witnesses").mkdir()
        self.assertIn("witness_requests", batch.witness_preflight(corpus.witnesses_dir))
        (corpus.root / "witness_requests").mkdir()
        self.assertIsNone(batch.witness_preflight(corpus.witnesses_dir))

    def test_the_v6_batch_refuses_before_projecting_when_the_corpus_is_absent(self):
        corpus = Corpus(self)
        out = corpus.root / "out"
        completed = subprocess.run(
            [sys.executable, str(ROOT / "tools" / "project_event_definitions_batch.py"),
             "--names", "n", "--catalog", "c", "--profiles-dir", "p", "--replays-dir", "r",
             "--package", "pk", "--arc", "a", "--out", str(out), "--contract", "v6",
             "--witnesses-dir", corpus.witnesses_dir],
            capture_output=True, text=True, encoding="utf-8", errors="replace", cwd=str(ROOT),
            # The temp path may hold non-ASCII (a localized user profile): pin both ends to UTF-8.
            env=dict(os.environ, PYTHONUTF8="1"),
        )
        self.assertEqual(completed.returncode, 1, "%s%s" % (completed.stdout, completed.stderr))
        self.assertIn("REFUSED", completed.stdout)
        self.assertFalse(out.exists())

    def test_parse_witness_status(self):
        stdout = "names_fingerprint=x\nWITNESS_STATUS site=a.1 stems=2 requests=7 results_used=5 missing=0\nPROJECTED a.1\n"
        self.assertEqual(batch.parse_witness_status(stdout),
                         {"stems": 2, "requests": 7, "results_used": 5, "missing": 0})
        self.assertIsNone(batch.parse_witness_status("PROJECTED a.1\n"))
        self.assertIsNone(batch.parse_witness_status("WITNESS_STATUS site=a.1 stems=oops\n"))

    def test_the_summary_line_counts_sites_requests_results_and_rows(self):
        statuses = [
            {"stems": 1, "requests": 10, "results_used": 8, "missing": 0},
            {"stems": 1, "requests": 0, "results_used": 0, "missing": 1},
        ]
        documents = [
            {"effect_rows_by_basis": {"shift_witness": 3, "variants": 1}, "done_cell_source": "reentry_probe"},
            {"effect_rows_by_basis": {"flag_pattern": 2}, "done_cell_source": "guard_flag"},
            {"effect_rows_by_basis": {"shift_witness": 2}, "done_cell_source": None},
        ]
        self.assertEqual(
            batch.witness_summary_line(statuses, documents),
            "witnesses: sites_with_results=1 sites_without_witnesses=1 requests=10 results_used=8 "
            "shift_witness_rows=5 reentry_probe_documents=1")


if __name__ == "__main__":
    unittest.main()
