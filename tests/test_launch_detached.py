"""TD-40 b: `tools/content_suite/launch_detached.py` marker and command construction.

The WMI call itself needs a real provider and is replaced by a fake that
returns a pid; everything the tool decides - the command line, the marker,
the stamp, the status text - is checked here without starting a process.
"""
from __future__ import annotations

import datetime
import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools" / "content_suite"))

import launch_detached as ld  # noqa: E402

NOW = datetime.datetime(2026, 10, 3, 12, 30, 5, tzinfo=datetime.timezone.utc)


class QuotingTests(unittest.TestCase):
    def test_every_argument_is_quoted(self) -> None:
        self.assertEqual('"plain"', ld.quote_argument("plain"))
        self.assertEqual('"with space"', ld.quote_argument("with space"))
        self.assertEqual('""', ld.quote_argument(""))

    def test_trailing_backslashes_are_doubled_so_they_cannot_escape_the_quote(self) -> None:
        self.assertEqual('"C:\\dir\\\\"', ld.quote_argument("C:\\dir\\"))
        self.assertEqual('"C:\\a\\b"', ld.quote_argument("C:\\a\\b"))

    def test_characters_cmd_would_reinterpret_are_refused(self) -> None:
        for bad in ('has"quote', "has%percent%", "two\nlines", "carriage\rreturn", "nul\x00"):
            with self.assertRaises(ld.LaunchError, msg=repr(bad)):
                ld.quote_argument(bad)

    def test_shell_metacharacters_inside_quotes_are_literal_and_allowed(self) -> None:
        self.assertEqual('"a&b|c>d<e^f"', ld.quote_argument("a&b|c>d<e^f"))


class CommandLineTests(unittest.TestCase):
    def test_the_command_is_wrapped_with_log_redirection(self) -> None:
        line = ld.build_command_line(["C:\\py\\py.exe", "tools\\x.py", "--name", "a b"], "C:\\logs\\run one.log")
        self.assertEqual(
            'cmd.exe /d /s /c ""C:\\py\\py.exe" "tools\\x.py" "--name" "a b" > "C:\\logs\\run one.log" 2>&1"', line)

    def test_an_empty_command_is_refused(self) -> None:
        with self.assertRaises(ld.LaunchError):
            ld.build_command_line([], "log")

    def test_non_ascii_paths_pass_through_unchanged(self) -> None:
        line = ld.build_command_line(["C:\\검증\\py.exe"], "C:\\검증\\run.log")
        self.assertIn("검증", line)

    def test_the_first_word_is_resolved_in_the_callers_environment(self) -> None:
        with mock.patch.object(ld.shutil, "which", return_value="C:\\Windows\\py.exe"):
            self.assertEqual(str(Path("C:\\Windows\\py.exe").resolve()), ld.resolve_executable("py"))
        self.assertEqual("C:\\abs\\tool.exe", ld.resolve_executable("C:\\abs\\tool.exe"))
        with mock.patch.object(ld.shutil, "which", return_value=None):
            with self.assertRaises(ld.LaunchError):
                ld.resolve_executable("no-such-tool")


class StampTests(unittest.TestCase):
    def test_stamp_is_utc_time_plus_a_sanitised_name(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            self.assertEqual("20261003T123005Z", ld.make_stamp(NOW, None, Path(directory)))
            self.assertEqual("20261003T123005Z_full-jobs6", ld.make_stamp(NOW, "full jobs6", Path(directory)))

    def test_a_taken_stamp_gets_a_counter(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            (Path(directory) / "20261003T123005Z.json").write_text("{}", encoding="utf-8")
            self.assertEqual("20261003T123005Z-2", ld.make_stamp(NOW, None, Path(directory)))
            (Path(directory) / "20261003T123005Z-2.log").write_text("", encoding="utf-8")
            self.assertEqual("20261003T123005Z-3", ld.make_stamp(NOW, None, Path(directory)))


class MarkerTests(unittest.TestCase):
    def test_the_marker_records_command_pid_log_and_start(self) -> None:
        root = Path("C:\\project")
        marker = ld.build_marker(
            "stamp", "name", ["py", "x.py"], "cmd.exe ...", root / "analysis" / "run.log", 4321, NOW, root)
        self.assertEqual(ld.MARKER_SCHEMA, marker["schema"])
        self.assertEqual(["py", "x.py"], marker["command"])
        self.assertEqual(4321, marker["pid"])
        self.assertEqual("analysis/run.log", marker["log"])
        self.assertEqual(".", marker["working_directory"])
        self.assertEqual(NOW.isoformat(), marker["started_at"])
        self.assertNotIn("project", json.dumps(marker).replace("analysis", ""))

    def test_a_log_outside_the_project_keeps_its_absolute_path(self) -> None:
        with tempfile.TemporaryDirectory() as directory, tempfile.TemporaryDirectory() as other:
            marker = ld.build_marker("s", None, ["x"], "c", Path(other) / "x.log", 1, NOW, Path(directory))
            self.assertEqual(str((Path(other) / "x.log").resolve()), marker["log"])

    def test_launch_writes_the_marker_and_hands_wmi_the_built_command_line(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            with mock.patch.object(ld, "wmi_create", return_value=777) as create, \
                    mock.patch.object(ld, "resolve_executable", side_effect=lambda word: word), \
                    mock.patch.object(ld, "utc_now", return_value=NOW):
                marker = ld.launch(["tool.exe", "--x", "a b"], "batch", None, root)
            self.assertEqual("20261003T123005Z_batch", marker["stamp"])
            self.assertEqual(777, marker["pid"])
            command_line, working_directory = create.call_args.args
            self.assertEqual(root, working_directory)
            log = root / "analysis" / "_undoc" / "detached" / "20261003T123005Z_batch.log"
            self.assertEqual(ld.build_command_line(["tool.exe", "--x", "a b"], log), command_line)
            written = json.loads((root / "analysis" / "_undoc" / "detached" / "20261003T123005Z_batch.json")
                                 .read_text(encoding="utf-8"))
            self.assertEqual(marker, written)
            self.assertEqual("analysis/_undoc/detached/20261003T123005Z_batch.log", written["log"])

    def test_a_refused_argument_writes_no_marker(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            with mock.patch.object(ld, "wmi_create") as create, \
                    mock.patch.object(ld, "resolve_executable", side_effect=lambda word: word):
                with self.assertRaises(ld.LaunchError):
                    ld.launch(["tool.exe", "50%"], None, None, Path(directory))
            create.assert_not_called()
            self.assertEqual([], list((Path(directory) / ld.MARKER_DIRECTORY).glob("*.json")))


class CreateOutputTests(unittest.TestCase):
    def test_the_pid_is_read_from_the_last_line(self) -> None:
        self.assertEqual(99, ld.parse_create_output('noise\n{"ReturnValue":0,"ProcessId":99}\n'))

    def test_a_nonzero_return_value_or_garbage_is_an_error(self) -> None:
        for text in ('{"ReturnValue":9,"ProcessId":0}', "", "not json", '{"ReturnValue":0,"ProcessId":0}'):
            with self.assertRaises(ld.LaunchError, msg=text):
                ld.parse_create_output(text)


def _process(pid, parent, name, created, command=""):
    return {"ProcessId": pid, "ParentProcessId": parent, "Name": name, "CreationDate": created, "CommandLine": command}


class StatusTests(unittest.TestCase):
    def _marker(self, pid=100, log="analysis/_undoc/detached/x.log"):
        return {"schema": ld.MARKER_SCHEMA, "stamp": "x", "pid": pid, "log": log, "command": ["py", "run.py"],
                "started_at": NOW.isoformat()}

    def test_a_live_pid_created_when_the_marker_says_is_running(self) -> None:
        table = [_process(100, 4, "cmd.exe", "2026-10-03T12:30:06.5+00:00")]
        self.assertTrue(ld.marker_is_running(self._marker(), table))

    def test_a_reused_pid_with_another_creation_time_is_not_running(self) -> None:
        table = [_process(100, 4, "notepad.exe", "2026-10-04T08:00:00+00:00")]
        self.assertFalse(ld.marker_is_running(self._marker(), table))

    def test_an_absent_pid_is_not_running(self) -> None:
        self.assertFalse(ld.marker_is_running(self._marker(), [_process(5, 4, "x.exe", None)]))

    def test_the_process_table_parses_an_array_a_single_object_and_nothing(self) -> None:
        one = {"ProcessId": 1, "ParentProcessId": 0, "Name": "a"}
        self.assertEqual([one], ld.parse_process_table(json.dumps(one)))
        self.assertEqual([one, one], ld.parse_process_table(json.dumps([one, one])))
        self.assertEqual([], ld.parse_process_table(" \n"))

    def test_log_edges_are_the_first_and_last_non_empty_lines(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "a.log"
            path.write_text("\nfirst line\nmiddle\nlast line\n\n", encoding="utf-8")
            self.assertEqual(("first line", "last line"), ld.log_edges(path))
            self.assertEqual(("", ""), ld.log_edges(Path(directory) / "absent.log"))

    def test_log_edges_survive_bytes_that_are_not_utf8(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "ansi.log"
            path.write_bytes(b"first " + bytes([0xc7, 0xd1, 0xb1, 0xdb, 10]) + b"last " + bytes([0xff, 0xfe, 10]))
            first, last = ld.log_edges(path)
            self.assertTrue(first.startswith("first"))
            self.assertTrue(last.startswith("last"))

    def test_status_shows_running_runs_with_first_and_last_log_lines(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            log = root / "analysis" / "_undoc" / "detached" / "x.log"
            log.parent.mkdir(parents=True)
            log.write_text("Run id 1\nrunning 12/400\n", encoding="utf-8")
            running = self._marker()
            finished = dict(self._marker(pid=200), stamp="y")
            table = [_process(100, 4, "cmd.exe", "2026-10-03T12:30:06+00:00")]
            text = "\n".join(ld.format_status([running, finished], table, root, False))
            self.assertIn("x  pid=100  RUNNING", text)
            self.assertIn("first:   Run id 1", text)
            self.assertIn("last:    running 12/400", text)
            self.assertNotIn("y  pid=200", text)
            both = "\n".join(ld.format_status([running, finished], table, root, True))
            self.assertIn("y  pid=200  finished", both)

    def test_status_with_nothing_running_says_so(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            self.assertEqual(
                ["no running detached runs (--all lists finished ones too)"],
                ld.format_status([self._marker()], [], Path(directory), False))

    def test_orphans_are_parentless_console_or_python_processes_that_mention_the_project(self) -> None:
        root = Path("C:\\proj")
        table = [
            _process(1, 0, "System", None),
            _process(10, 999, "Godot_v4.7_console.exe", None, '"godot" --headless --path "C:\\proj" --script x'),
            _process(11, 1, "Godot_v4.7_console.exe", None, '"godot" --path "C:\\proj"'),   # parent alive
            _process(12, 999, "python.exe", None, "python tools\\audit.py"),
            _process(13, 999, "python.exe", None, "python C:\\elsewhere\\server.py"),     # unrelated
            _process(14, 999, "notepad.exe", None, "notepad C:\\proj\\a.txt"),            # not a candidate
        ]
        self.assertEqual([10, 12], [row["ProcessId"] for row in ld.possible_orphans(table, root)])

    def test_load_markers_skips_other_documents_and_garbage(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            folder = Path(directory) / ld.MARKER_DIRECTORY
            folder.mkdir(parents=True)
            (folder / "a.json").write_text(json.dumps(self._marker()), encoding="utf-8")
            (folder / "b.json").write_text(json.dumps({"schema": "other"}), encoding="utf-8")
            (folder / "c.json").write_text("not json", encoding="utf-8")
            self.assertEqual(["x"], [m["stamp"] for m in ld.load_markers(Path(directory))])


if __name__ == "__main__":
    unittest.main()
