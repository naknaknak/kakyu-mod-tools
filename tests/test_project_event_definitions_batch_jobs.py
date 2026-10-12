"""TD-41: `project_event_definitions_batch.py --jobs N` is deterministic. TD-56 C4c: `--only`
merges into an existing index and a failed projection records its cause.

Synthetic fixtures only - no archive, no original data, no subprocesses: the
projection and validation calls are replaced by fakes that finish in a
scrambled order, so a pool that appended results as they completed (instead
of in registry-row order) would show up as a different index or table.
"""
from __future__ import annotations

import contextlib
import io
import json
import sys
import tempfile
import threading
import time
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

import project_event_definitions_batch as batch  # noqa: E402

SITE_IDS = ["site.a.1", "site.b.1", "site.c.1", "site.d.1", "site.e.1", "site.f.1", "site.g.1"]
CATALOG_OK = "site.b.1"
CATALOG_NO_REPLAY = "site.c.1"
PROJECTION_FAILS = "site.e.1"
VALIDATION_FAILS = "site.f.1"


def _argument(cmd_args, flag):
    return cmd_args[cmd_args.index(flag) + 1]


class FakeWorld:
    """Registry, package and fakes for one `main()` run."""

    def __init__(self, root: Path):
        self.root = root
        self.names = root / "names"
        self.names.mkdir()
        rows = {}
        for index, site_id in enumerate(SITE_IDS):
            aliases = {}
            if site_id in (CATALOG_OK, CATALOG_NO_REPLAY):
                aliases["catalog_event_id"] = "original/event%d/x" % index
            rows[site_id] = {"id": site_id, "aliases": aliases, "evidence": []}
        (self.names / "event_names.json").write_text(json.dumps({"rows": rows}), encoding="utf-8")
        (self.names / "names_fingerprint").write_text("n" * 64 + "\n", encoding="utf-8")
        self.package = root / "package"
        self.package.mkdir()
        (self.package / "manifest.json").write_text(json.dumps({"package_sha256": "p" * 64}), encoding="utf-8")
        self.profiles = root / "profiles"
        self.profiles.mkdir()
        (root / "witnesses").mkdir()
        (root / "witness_requests").mkdir()
        self.active = 0
        self.heal = set()   # sites whose projection succeeds on this world's later runs
        self.max_active = 0
        self.scripts = []
        self.lock = threading.Lock()

    def fake_replay(self, event_id, replays_dir, elfimage_dir, catalog_path, godot_exe):
        if event_id.endswith("event%d/x" % SITE_IDS.index(CATALOG_NO_REPLAY)):
            raise RuntimeError("no replay for %s" % event_id)
        return Path(replays_dir) / "catalog_fake.json"

    def fake_projection(self, cmd_args, script=None):
        doc_id = _argument(cmd_args, "--site") if "--site" in cmd_args else CATALOG_OK
        with self.lock:
            self.active += 1
            self.max_active = max(self.max_active, self.active)
        # Later rows finish first, so completion order is the reverse of row order.
        time.sleep(0.02 * (len(SITE_IDS) - SITE_IDS.index(doc_id)))
        try:
            if doc_id == PROJECTION_FAILS and doc_id not in self.heal:
                return SimpleNamespace(returncode=1, stdout="boom\n", stderr="trace\n")
            out = Path(_argument(cmd_args, "--out"))
            document = {
                "kind": "event", "results": {"r1": {"results": {"r2": {}}}},
                "terminals": {"t": 1}, "dialogue": [{"kind": "message"}] * (1 + SITE_IDS.index(doc_id)),
                "after": [{"type": "set"}], "evidence": {"effect_witnesses": [{"basis": "shift_witness"}]},
            }
            (out / ("%s.json" % doc_id)).write_text(json.dumps(document), encoding="utf-8")
            status = ""
            if script in (batch.PROJECT_SCRIPT_V6, batch.PROJECT_SCRIPT_V7):
                status = "WITNESS_STATUS site=%s stems=1 requests=%d results_used=%d missing=0\n" % (
                    doc_id, 2 + SITE_IDS.index(doc_id), 1)
            if script == batch.PROJECT_SCRIPT_V7:
                count = SITE_IDS.index(doc_id)
                status += ("RESOURCES_STATUS site=%s items=%d runs=1 route=%d def=0 lib_excluded=1 mmo=%d ax=0 voice=0 se=0 "
                           "a6=0 bgm=0 unclassified=0\n" % (doc_id, count, count, count))
            self.scripts.append(script)
            return SimpleNamespace(returncode=0, stdout=status + "PROJECTED %s\n" % doc_id, stderr="")
        finally:
            with self.lock:
                self.active -= 1

    def fake_validation(self, doc_path, names_dir, package_dir, fingerprint):
        if Path(doc_path).stem == VALIDATION_FAILS:
            return {"ok": False, "reason": "schema", "detail": "bad field"}
        return {"ok": True}

    def argv(self, out: Path, contract: str, jobs: int, only=()):
        return [
            "--names", str(self.names), "--catalog", "catalog.json", "--profiles-dir", str(self.profiles),
            "--replays-dir", str(self.root / "replays"), "--package", str(self.package), "--arc", "mes.arc",
            "--out", str(out), "--contract", contract, "--witnesses-dir", str(self.root / "witnesses"),
            "--shared-lines-out", str(self.root / "shared_lines.json"), "--jobs", str(jobs),
        ] + [part for doc_id in only for part in ("--only", doc_id)]

    def run_main(self, out: Path, contract: str, jobs: int, only=()):
        stdout = io.StringIO()
        with mock.patch.object(batch, "ensure_catalog_replay", self.fake_replay), \
                mock.patch.object(batch, "run_projection", self.fake_projection), \
                mock.patch.object(batch, "run_validation", self.fake_validation), \
                mock.patch.object(batch, "find_godot", lambda explicit: None), \
                mock.patch.object(batch, "compute_shared_lines", lambda *a, **k: {"CALLER": [["e", 1]]}), \
                contextlib.redirect_stdout(stdout):
            code = batch.main(self.argv(out, contract, jobs, only))
        return code, stdout.getvalue().replace(str(out), "<OUT>")


class MainDeterminismTests(unittest.TestCase):
    def _compare(self, contract: str):
        with tempfile.TemporaryDirectory() as tmp:
            world = FakeWorld(Path(tmp))
            serial_out, parallel_out = Path(tmp) / "serial", Path(tmp) / "parallel"
            serial_code, serial_stdout = world.run_main(serial_out, contract, 1)
            self.assertEqual(world.max_active, 1)
            parallel_code, parallel_stdout = world.run_main(parallel_out, contract, 4)
            self.assertGreater(world.max_active, 1, "--jobs 4 never ran two sites at once")
            self.assertEqual(serial_code, 1)
            self.assertEqual(parallel_code, serial_code)
            self.assertEqual(parallel_stdout, serial_stdout)
            names = sorted(path.name for path in serial_out.iterdir())
            self.assertEqual(sorted(path.name for path in parallel_out.iterdir()), names)
            for name in names:
                self.assertEqual((parallel_out / name).read_bytes(), (serial_out / name).read_bytes(), name)
            index = json.loads((serial_out / "index.json").read_text(encoding="utf-8"))
            self.assertEqual([d["id"] for d in index["documents"]], SITE_IDS)
            by_id = {d["id"]: d for d in index["documents"]}
            self.assertEqual(by_id[CATALOG_NO_REPLAY]["reason"], "replay_failed")
            self.assertEqual(by_id[PROJECTION_FAILS]["reason"], "projection_failed")
            self.assertEqual(by_id[VALIDATION_FAILS]["reason"], "schema")
            self.assertEqual(index["summary"], {"projected": 5, "valid": 4, "invalid": 3})
            return serial_stdout

    def test_v3_parallel_run_equals_serial_run(self):
        self._compare("v3")

    def test_v6_parallel_run_equals_serial_run_including_the_witness_summary(self):
        stdout = self._compare("v6")
        # The failed projection printed no status line and the failed replay never ran, so 5 of the 7 report.
        self.assertIn("witnesses: sites_with_results=5 sites_without_witnesses=0 requests=25 ", stdout)

    def test_v7_uses_its_own_producer_and_prints_the_resources_summary(self):
        stdout = self._compare("v7")
        # The same 5 sites report (the failed projection and the failed replay print nothing); items 0+1+3+5+6.
        self.assertIn("resources: documents=5 without_status=0 empty=1 items=15 route=15 def=0 lib_excluded=5 "
                      "kinds={mmo: 15} largest=6 (site.g.1)", stdout)
        self.assertIn("witnesses: sites_with_results=5 ", stdout)

    def test_v7_dispatch_and_fingerprint_directory(self):
        with tempfile.TemporaryDirectory() as tmp:
            world = FakeWorld(Path(tmp))
            world.run_main(Path(tmp) / "out", "v7", 1)
            self.assertTrue(world.scripts)
            self.assertEqual(set(world.scripts), {batch.PROJECT_SCRIPT_V7})
            index = json.loads((Path(tmp) / "out" / "index.json").read_text(encoding="utf-8"))
            expected = (ROOT / "config" / "contracts" / "event_definition_v7" / "contract_fingerprint").read_text(encoding="utf-8").strip()
            self.assertEqual(index["contract_fingerprint"], expected)
            self.assertEqual(index["schema"], "kakyu_event_definition_index/v2")

    def test_jobs_must_be_positive(self):
        with self.assertRaises(SystemExit), contextlib.redirect_stderr(io.StringIO()):
            batch.main(["--names", "n", "--catalog", "c", "--profiles-dir", "p", "--replays-dir", "r",
                        "--package", "k", "--arc", "a", "--out", "o", "--jobs", "0"])


class FailureCauseTests(unittest.TestCase):
    """A failed projection is never silent (TD-56 C4c): the exit code and the last lines of its stdout
    and stderr are in its index row and under its line of the table."""

    def test_the_row_and_the_table_carry_the_cause(self):
        with tempfile.TemporaryDirectory() as tmp:
            world = FakeWorld(Path(tmp))
            code, stdout = world.run_main(Path(tmp) / "out", "v7", 1)
            self.assertEqual(code, 1)
            index = json.loads((Path(tmp) / "out" / "index.json").read_text(encoding="utf-8"))
            row = {d["id"]: d for d in index["documents"]}[PROJECTION_FAILS]
            self.assertEqual((row["reason"], row["exit_code"]), ("projection_failed", 1))
            self.assertEqual((row["stderr_tail"], row["stdout_tail"]), (["trace"], ["boom"]))
            lines = stdout.splitlines()
            at = next(i for i, line in enumerate(lines) if line.startswith(PROJECTION_FAILS))
            self.assertTrue(lines[at].endswith("FAIL:projection_failed"))
            self.assertEqual(lines[at + 1:at + 4], ["    exit=1", "    stderr| trace", "    stdout| boom"])

    def test_other_failures_keep_their_rows_and_lines(self):
        with tempfile.TemporaryDirectory() as tmp:
            world = FakeWorld(Path(tmp))
            _code, stdout = world.run_main(Path(tmp) / "out", "v7", 1)
            index = json.loads((Path(tmp) / "out" / "index.json").read_text(encoding="utf-8"))
            by_id = {d["id"]: d for d in index["documents"]}
            for doc_id in (VALIDATION_FAILS, CATALOG_NO_REPLAY):
                self.assertNotIn("exit_code", by_id[doc_id])
            self.assertEqual(stdout.count("    exit="), 1)

    def test_the_tail_keeps_the_last_non_empty_lines_cut_short(self):
        text = "\n".join("line %d" % n for n in range(20)) + "\n\n   \n"
        self.assertEqual(batch.output_tail(text), ["line %d" % n for n in range(14, 20)])
        self.assertEqual(batch.output_tail(text, 2), ["line 18", "line 19"])
        self.assertEqual(batch.output_tail("x" * 1000), ["x" * batch.FAILURE_LINE_LIMIT])
        self.assertEqual(batch.output_tail(b"caf\xc3\xa9\n"), ["caf\u00e9"])
        self.assertEqual((batch.output_tail(None), batch.output_tail("")), ([], []))


class OnlyMergeTests(unittest.TestCase):
    """`--only` merges its rows into the index already in `--out` instead of overwriting it."""

    def full_run(self, world, tmp):
        out = Path(tmp) / "out"
        world.run_main(out, "v7", 1)
        return out, json.loads((out / "index.json").read_text(encoding="utf-8"))

    def test_the_run_rows_replace_their_ids_and_the_rest_stays(self):
        with tempfile.TemporaryDirectory() as tmp:
            world = FakeWorld(Path(tmp))
            out, before = self.full_run(world, tmp)
            self.assertEqual(before["summary"], {"projected": 5, "valid": 4, "invalid": 3})
            world.heal.add(PROJECTION_FAILS)
            code, stdout = world.run_main(out, "v7", 1, only=[PROJECTION_FAILS])
            self.assertEqual(code, 0)
            after = json.loads((out / "index.json").read_text(encoding="utf-8"))
            self.assertEqual([d["id"] for d in after["documents"]], SITE_IDS)
            by_before = {d["id"]: d for d in before["documents"]}
            for row in after["documents"]:
                if row["id"] == PROJECTION_FAILS:
                    self.assertTrue(row["ok"])
                    self.assertNotIn("exit_code", row)
                else:
                    self.assertEqual(row, by_before[row["id"]])
            self.assertEqual(after["summary"], {"projected": 6, "valid": 5, "invalid": 2})
            for field in ("schema", "contract_fingerprint", "names_fingerprint", "package_sha256"):
                self.assertEqual(after[field], before[field])
            self.assertEqual(list(after.keys()), list(before.keys()))
            self.assertTrue((out / ("%s.json" % PROJECTION_FAILS)).is_file())
            self.assertIn("projected=1 valid=1 invalid=0", stdout)
            self.assertIn("merged into the existing index: documents=7 projected=6 valid=5 invalid=2", stdout)

    def test_a_failure_still_exits_nonzero_and_is_recorded_in_the_merged_row(self):
        with tempfile.TemporaryDirectory() as tmp:
            world = FakeWorld(Path(tmp))
            out, _before = self.full_run(world, tmp)
            code, _stdout = world.run_main(out, "v7", 1, only=[PROJECTION_FAILS])
            self.assertEqual(code, 1)
            after = json.loads((out / "index.json").read_text(encoding="utf-8"))
            row = {d["id"]: d for d in after["documents"]}[PROJECTION_FAILS]
            self.assertEqual((row["reason"], row["exit_code"]), ("projection_failed", 1))
            self.assertEqual(len(after["documents"]), 7)

    def test_an_index_bound_to_another_package_is_refused_untouched(self):
        with tempfile.TemporaryDirectory() as tmp:
            world = FakeWorld(Path(tmp))
            out, _before = self.full_run(world, tmp)
            stale = (out / "index.json").read_bytes()
            document = (out / ("%s.json" % SITE_IDS[0])).read_bytes()
            (world.package / "manifest.json").write_text(json.dumps({"package_sha256": "q" * 64}), encoding="utf-8")
            code, stdout = world.run_main(out, "v7", 1, only=[SITE_IDS[0]])
            self.assertEqual(code, 1)
            self.assertIn("REFUSED: the existing index.json differs in package_sha256", stdout)
            self.assertEqual((out / "index.json").read_bytes(), stale)
            self.assertEqual((out / ("%s.json" % SITE_IDS[0])).read_bytes(), document)

    def test_an_index_of_another_contract_is_refused(self):
        with tempfile.TemporaryDirectory() as tmp:
            world = FakeWorld(Path(tmp))
            out, _before = self.full_run(world, tmp)
            code, stdout = world.run_main(out, "v6", 1, only=[SITE_IDS[0]])
            self.assertEqual(code, 1)
            self.assertIn("REFUSED: the existing index.json differs in contract_fingerprint", stdout)

    def test_an_unknown_id_is_refused(self):
        with tempfile.TemporaryDirectory() as tmp:
            world = FakeWorld(Path(tmp))
            code, stdout = world.run_main(Path(tmp) / "out", "v7", 1, only=["no.such.1"])
            self.assertEqual(code, 1)
            self.assertIn("REFUSED: --only names no registry row: no.such.1", stdout)

    def test_without_an_existing_index_only_writes_the_rows_it_ran(self):
        with tempfile.TemporaryDirectory() as tmp:
            world = FakeWorld(Path(tmp))
            out = Path(tmp) / "out"
            code, stdout = world.run_main(out, "v7", 1, only=["site.a.1"])
            self.assertEqual(code, 0)
            index = json.loads((out / "index.json").read_text(encoding="utf-8"))
            self.assertEqual([d["id"] for d in index["documents"]], ["site.a.1"])
            self.assertEqual(index["summary"], {"projected": 1, "valid": 1, "invalid": 0})
            self.assertNotIn("merged into", stdout)

    def test_the_merge_keeps_id_order_and_inserts_a_new_row(self):
        rows = lambda ids: [{"id": i, "ok": True, "kind": "event"} for i in ids]
        merged = batch.merge_index_documents(rows(["a", "c", "e"]), [{"id": "d", "ok": False, "kind": None}, {"id": "a", "ok": False, "kind": None}])
        self.assertEqual([d["id"] for d in merged], ["a", "c", "d", "e"])
        self.assertEqual([d["ok"] for d in merged], [False, True, False, True])
        # an existing list that is not in id order keeps it and takes the new rows at the end
        merged = batch.merge_index_documents(rows(["c", "a"]), rows(["b", "c"]))
        self.assertEqual([d["id"] for d in merged], ["c", "a", "b"])
        self.assertEqual(batch.index_summary(merged + [{"id": "z", "ok": False, "kind": None}]), {"projected": 3, "valid": 3, "invalid": 1})


class ResourcesStatusTests(unittest.TestCase):
    LINE = ("RESOURCES_STATUS site=a.b.1 items=7 runs=3 route=6 def=1 lib_excluded=2 mmo=1 ax=2 voice=3 se=0 a6=0 bgm=1 "
            "unclassified=0")

    def test_the_status_line_is_parsed(self):
        status = batch.parse_resources_status("noise\n" + self.LINE + "\nmore\n")
        self.assertEqual(status["site"], "a.b.1")
        self.assertEqual((status["items"], status["runs"], status["route"], status["def"], status["lib_excluded"]), (7, 3, 6, 1, 2))
        self.assertEqual((status["mmo"], status["ax"], status["voice"], status["bgm"]), (1, 2, 3, 1))

    def test_an_absent_or_malformed_line_is_none(self):
        self.assertIsNone(batch.parse_resources_status(""))
        self.assertIsNone(batch.parse_resources_status(None))
        self.assertIsNone(batch.parse_resources_status("RESOURCES_STATUS site=x items=1"))
        self.assertIsNone(batch.parse_resources_status(self.LINE.replace("items=7", "items=seven")))

    def test_the_summary_counts_a_site_without_a_status_line(self):
        zero = self.LINE.replace("a.b.1", "c.d.1").replace("items=7", "items=0")
        statuses = [batch.parse_resources_status(self.LINE), batch.parse_resources_status(zero)]
        self.assertEqual(
            batch.resources_summary_line(statuses, 3),
            "resources: documents=2 without_status=1 empty=1 items=7 route=12 def=2 lib_excluded=4 "
            "kinds={mmo: 2, ax: 4, voice: 6, bgm: 2} largest=7 (a.b.1)")

    def test_the_summary_of_nothing(self):
        self.assertEqual(
            batch.resources_summary_line([], 0),
            "resources: documents=0 without_status=0 empty=0 items=0 route=0 def=0 lib_excluded=0 kinds={} largest=0 (-)")


class RunSitesTests(unittest.TestCase):
    def test_results_follow_item_order_whatever_the_completion_order(self):
        items = list(range(8))

        def fake(item, ctx):
            time.sleep(0.01 * (8 - item))
            return item

        with mock.patch.object(batch, "run_site", fake):
            self.assertEqual(batch.run_sites(items, {}, 4), items)
            self.assertEqual(batch.run_sites(items, {}, 1), items)

    def test_an_exception_propagates_and_unstarted_sites_are_dropped(self):
        started = []

        def fake(item, ctx):
            started.append(item)
            if item == 0:
                raise ValueError("site 0 broke")
            time.sleep(0.05)
            return item

        with mock.patch.object(batch, "run_site", fake):
            with self.assertRaises(ValueError):
                batch.run_sites(list(range(40)), {}, 2)
        self.assertLess(len(started), 40)


class AssembleTests(unittest.TestCase):
    def test_slots_and_results_are_interleaved_in_row_order(self):
        failed_replay = {"id": "b", "kind": None, "evidence_kind": "catalog_event", "ok": False, "reason": "replay_failed"}
        slots = [{"work": {"id": "a"}}, {"entry": failed_replay}, {"work": {"id": "c"}}, {"work": {"id": "d"}}]
        results = [
            {"entry": {"id": "a", "ok": True}, "witness_status": {"missing": 0}, "failed": False},
            {"entry": {"id": "c", "ok": False}, "witness_status": None, "failed": True},
            {"entry": {"id": "d", "ok": True}, "witness_status": {"missing": 1}, "failed": False},
        ]
        documents, statuses, any_failed = batch.assemble_documents(slots, results)
        self.assertEqual([d["id"] for d in documents], ["a", "b", "c", "d"])
        self.assertEqual(statuses, [{"missing": 0}, {"missing": 1}])
        self.assertTrue(any_failed)

    def test_no_failure_means_no_flag(self):
        documents, statuses, any_failed = batch.assemble_documents(
            [{"work": {}}], [{"entry": {"id": "a"}, "witness_status": None, "failed": False}])
        self.assertEqual((len(documents), statuses, any_failed), (1, [], False))


if __name__ == "__main__":
    unittest.main()
