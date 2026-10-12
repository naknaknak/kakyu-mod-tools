"""Tests for `tools/regenerate_group_replays.py` (WD-21 U2 C2).

Synthetic only: no archive, no Godot. `subprocess.run` is replaced by a fake that
writes (or fails to write) the replay file the real validator would write, so the
driver's command line, its failure rules, its run log and its refusals are pinned
without running a validator.

    py tests/test_regenerate_group_replays.py
"""
from __future__ import annotations

import contextlib
import io
import json
import subprocess
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

import regenerate_group_replays as regen  # noqa: E402

STEMS = ["alpha_v5", "bravo_v14", "charlie_v6", "delta_v13", "echo_v8"]


def replay_document(stem: str, schema: str = regen.REPLAY_SCHEMA, profile: str | None = None) -> dict:
    return {"schema": schema, "profile": stem if profile is None else profile, "routes": []}


class FakeWorld:
    """A project-less sandbox: an ELFIMAGE stand-in with a `mes.arc`, a profiles directory and an output directory."""

    def __init__(self, base: Path, stems=STEMS):
        self.base = base
        self.elfimage = base / "ELFIMAGE"
        self.elfimage.mkdir()
        (self.elfimage / "mes.arc").write_bytes(b"")
        self.profiles = base / "profiles"
        self.profiles.mkdir()
        for stem in stems:
            (self.profiles / f"{stem}.json").write_text("{}", encoding="utf-8")
        self.out = base / "out"
        self.godot = base / "godot.exe"
        self.godot.write_bytes(b"")
        self.calls: list[list[str]] = []
        self.lock = threading.Lock()
        self.behaviour = {}  # stem -> "ok" | "exit1" | "no_file" | "wrong_schema" | "wrong_profile" | "bad_json" | "timeout"
        self.delays = {}

    def fake_run(self, command, **kwargs):
        stem = Path(command[command.index("--") + 2]).stem
        replay = Path(command[command.index("--replay") + 1])
        with self.lock:
            self.calls.append(list(command))
        time.sleep(self.delays.get(stem, 0))
        mode = self.behaviour.get(stem, "ok")
        if mode == "timeout":
            raise subprocess.TimeoutExpired(command, kwargs.get("timeout", 1), output="partial out", stderr=b"partial err")
        if mode == "exit1":
            return SimpleNamespace(returncode=1, stdout="boom\n", stderr="err\n")
        if mode == "ok":
            replay.write_text(json.dumps(replay_document(stem)), encoding="utf-8")
        elif mode == "wrong_schema":
            replay.write_text(json.dumps(replay_document(stem, schema="kakyu_event_analysis_group_replay/v2")), encoding="utf-8")
        elif mode == "wrong_profile":
            replay.write_text(json.dumps(replay_document(stem, profile="other")), encoding="utf-8")
        elif mode == "bad_json":
            replay.write_text("{not json", encoding="utf-8")
        return SimpleNamespace(returncode=0, stdout=f"REPLAY_WRITTEN {replay} routes=0 variants=0 runs=0 definition_runs=0\n", stderr="")

    def run(self, jobs=1, **kwargs):
        with mock.patch.object(regen.subprocess, "run", side_effect=self.fake_run):
            return regen.regenerate(self.elfimage, self.profiles, self.out, jobs, self.godot, **kwargs)


class RegenerateGroupReplaysTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.world = FakeWorld(Path(self.temp.name))

    def test_command_line_of_one_validator_process(self) -> None:
        profile = self.world.profiles / "alpha_v5.json"
        replay = self.world.out / "alpha_v5.json"
        command = regen.validator_command(self.world.godot, regen.ROOT, self.world.elfimage, profile, replay)
        self.assertEqual(
            [str(self.world.godot), "--headless", "--path", str(regen.ROOT), "--script",
             "res://tools/content_suite/validators/validate_event_analysis_group.gd", "--",
             str(self.world.elfimage), str(profile), "--replay", str(replay)], command)

    def test_every_profile_runs_once_and_the_run_log_has_one_line_each(self) -> None:
        summary = self.world.run(jobs=3)
        self.assertEqual({"profiles": 5, "failed": [], "seconds": summary["seconds"]}, summary)
        self.assertEqual(5, len(self.world.calls))
        lines = (self.world.out / "_run_log.txt").read_text(encoding="utf-8").splitlines()
        self.assertEqual(sorted(STEMS), sorted(line.split("\t")[0] for line in lines))
        for line in lines:
            stem, code, seconds = line.split("\t")
            self.assertEqual("exit=0", code)
            self.assertRegex(seconds, r"^\d+\.\ds$")
        for stem in STEMS:
            self.assertEqual(regen.REPLAY_SCHEMA, json.loads((self.world.out / f"{stem}.json").read_text(encoding="utf-8"))["schema"])
            log = (self.world.out / "_logs" / f"{stem}.log").read_text(encoding="utf-8")
            self.assertIn("REPLAY_WRITTEN", log)

    def test_every_call_runs_in_the_project_root_with_absolute_paths(self) -> None:
        captured = []

        def fake(command, **kwargs):
            captured.append(kwargs)
            return self.world.fake_run(command, **kwargs)

        with mock.patch.object(regen.subprocess, "run", side_effect=fake):
            regen.regenerate(self.world.elfimage, self.world.profiles, self.world.out, 1, self.world.godot)
        self.assertEqual(5, len(captured))
        for kwargs in captured:
            self.assertEqual(regen.ROOT, kwargs["cwd"])
            self.assertEqual(regen.DEFAULT_TIMEOUT_SECONDS, kwargs["timeout"])
        for command in self.world.calls:
            self.assertTrue(Path(command[command.index("--") + 1]).is_absolute())
            self.assertTrue(Path(command[command.index("--") + 2]).is_absolute())
            self.assertTrue(Path(command[command.index("--replay") + 1]).is_absolute())

    def test_a_nonzero_exit_fails_the_run_but_not_the_other_profiles(self) -> None:
        self.world.behaviour["charlie_v6"] = "exit1"
        summary = self.world.run(jobs=2)
        self.assertEqual([{"stem": "charlie_v6", "error": "validator exited 1"}], summary["failed"])
        lines = (self.world.out / "_run_log.txt").read_text(encoding="utf-8").splitlines()
        self.assertEqual(5, len(lines))
        self.assertIn("charlie_v6\texit=1\t", "\n".join(lines))
        for stem in STEMS:
            if stem != "charlie_v6":
                self.assertTrue((self.world.out / f"{stem}.json").is_file())
        self.assertFalse((self.world.out / "charlie_v6.json").exists())
        self.assertIn("boom", (self.world.out / "_logs" / "charlie_v6.log").read_text(encoding="utf-8"))

    def test_exit_zero_without_a_valid_v3_replay_is_a_failure(self) -> None:
        for stem, mode, fragment in (
            ("alpha_v5", "no_file", "no replay file"),
            ("bravo_v14", "wrong_schema", "replay schema is"),
            ("charlie_v6", "wrong_profile", "names profile"),
            ("delta_v13", "bad_json", "does not parse"),
        ):
            self.world.behaviour[stem] = mode
        summary = self.world.run(jobs=1)
        reasons = {row["stem"]: row["error"] for row in summary["failed"]}
        self.assertEqual({"alpha_v5", "bravo_v14", "charlie_v6", "delta_v13"}, set(reasons))
        self.assertIn("no replay file", reasons["alpha_v5"])
        self.assertIn("replay schema is", reasons["bravo_v14"])
        self.assertIn("names profile", reasons["charlie_v6"])
        self.assertIn("does not parse", reasons["delta_v13"])
        self.assertEqual(sorted(reasons), [row["stem"] for row in summary["failed"]])

    def test_a_timeout_is_a_failure_and_keeps_the_partial_output(self) -> None:
        self.world.behaviour["echo_v8"] = "timeout"
        summary = self.world.run(jobs=1, timeout=7)
        self.assertEqual([{"stem": "echo_v8", "error": "timed out after 7 s"}], summary["failed"])
        self.assertIn("echo_v8\texit=-1\t", (self.world.out / "_run_log.txt").read_text(encoding="utf-8"))
        log = (self.world.out / "_logs" / "echo_v8.log").read_text(encoding="utf-8")
        self.assertIn("partial out", log)
        self.assertIn("partial err", log)

    def test_a_stale_replay_cannot_survive_a_failed_run(self) -> None:
        self.world.out.mkdir()
        (self.world.out / "alpha_v5.json").write_text(json.dumps(replay_document("alpha_v5")), encoding="utf-8")
        self.world.behaviour["alpha_v5"] = "exit1"
        summary = self.world.run(jobs=1)
        self.assertEqual(["alpha_v5"], [row["stem"] for row in summary["failed"]])
        self.assertFalse((self.world.out / "alpha_v5.json").exists())

    def test_only_selects_profiles_and_refuses_an_unknown_stem(self) -> None:
        summary = self.world.run(jobs=1, only=["echo_v8", "alpha_v5"])
        self.assertEqual(2, summary["profiles"])
        self.assertEqual(["alpha_v5", "echo_v8"], sorted(Path(c[c.index("--") + 2]).stem for c in self.world.calls))
        with self.assertRaisesRegex(regen.UsageError, "unknown profile stem"):
            self.world.run(jobs=1, only=["nope"])

    def test_refusals(self) -> None:
        with self.assertRaisesRegex(regen.UsageError, "--jobs"):
            self.world.run(jobs=0)
        with self.assertRaisesRegex(regen.UsageError, "inside the original game directory"):
            with mock.patch.object(regen.subprocess, "run", side_effect=self.world.fake_run):
                regen.regenerate(self.world.elfimage, self.world.profiles, self.world.elfimage / "replays", 1, self.world.godot)
        with self.assertRaisesRegex(regen.UsageError, "holds no mes.arc"):
            with mock.patch.object(regen.subprocess, "run", side_effect=self.world.fake_run):
                regen.regenerate(self.world.base, self.world.profiles, self.world.out, 1, self.world.godot)
        empty = self.world.base / "empty"
        empty.mkdir()
        with self.assertRaisesRegex(regen.UsageError, "no profiles"):
            with mock.patch.object(regen.subprocess, "run", side_effect=self.world.fake_run):
                regen.regenerate(self.world.elfimage, empty, self.world.out, 1, self.world.godot)
        with self.assertRaisesRegex(regen.UsageError, "does not exist"):
            with mock.patch.object(regen.subprocess, "run", side_effect=self.world.fake_run):
                regen.regenerate(self.world.elfimage, self.world.base / "missing", self.world.out, 1, self.world.godot)
        self.assertEqual([], self.world.calls)

    def test_scrambled_finish_order_still_reports_every_profile_sorted(self) -> None:
        for index, stem in enumerate(STEMS):
            self.world.delays[stem] = 0.05 * (len(STEMS) - index)
        self.world.behaviour["alpha_v5"] = "exit1"
        self.world.behaviour["echo_v8"] = "exit1"
        summary = self.world.run(jobs=5)
        self.assertEqual(["alpha_v5", "echo_v8"], [row["stem"] for row in summary["failed"]])
        stems_in_log = [line.split("\t")[0] for line in (self.world.out / "_run_log.txt").read_text(encoding="utf-8").splitlines()]
        self.assertEqual(sorted(STEMS), sorted(stems_in_log))

    def test_main_exit_codes_and_the_summary_line(self) -> None:
        argv = [str(self.world.elfimage), "--profiles-dir", str(self.world.profiles), "--out", str(self.world.out),
                "--jobs", "2", "--godot", str(self.world.godot)]
        stdout = io.StringIO()
        with mock.patch.object(regen.subprocess, "run", side_effect=self.world.fake_run), contextlib.redirect_stdout(stdout):
            code = regen.main(argv)
        self.assertEqual(0, code)
        self.assertEqual(5, json.loads(stdout.getvalue())["profiles"])
        self.world.behaviour["bravo_v14"] = "exit1"
        stdout = io.StringIO()
        with mock.patch.object(regen.subprocess, "run", side_effect=self.world.fake_run), contextlib.redirect_stdout(stdout):
            code = regen.main(argv)
        self.assertEqual(1, code)
        self.assertEqual("bravo_v14", json.loads(stdout.getvalue())["failed"][0]["stem"])
        stderr = io.StringIO()
        with contextlib.redirect_stderr(stderr):
            code = regen.main([str(self.world.elfimage), "--profiles-dir", str(self.world.profiles), "--out", str(self.world.out),
                               "--jobs", "0", "--godot", str(self.world.godot)])
        self.assertEqual(2, code)
        self.assertIn("--jobs", stderr.getvalue())

    def test_godot_is_discovered_by_the_validation_runner_when_not_given(self) -> None:
        argv = [str(self.world.elfimage), "--profiles-dir", str(self.world.profiles), "--out", str(self.world.out), "--only", "alpha_v5"]
        with mock.patch.object(regen.validation, "find_godot", return_value=self.world.godot) as find, \
                mock.patch.object(regen.subprocess, "run", side_effect=self.world.fake_run), contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(0, regen.main(argv))
        find.assert_called_once_with(None)
        self.assertEqual(str(self.world.godot), self.world.calls[0][0])

    def test_no_machine_path_is_written_into_the_tool(self) -> None:
        source = (ROOT / "tools" / "regenerate_group_replays.py").read_text(encoding="utf-8")
        for fragment in ("C:\\", "C:/", "Users", "eroge", "WinGet"):
            self.assertNotIn(fragment, source)


if __name__ == "__main__":
    unittest.main()
