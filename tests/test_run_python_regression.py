from __future__ import annotations

import contextlib
import io
import os
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools" / "content_suite"))

import run_python_regression as regression  # noqa: E402


class ParallelPythonRegressionTests(unittest.TestCase):
    def test_balanced_shards_cover_every_test_once(self) -> None:
        test_ids = [
            "test_audit_ai5_mes_exe.Case.test_a",
            "test_audit_ai5_mes_exe.Case.test_b",
            "test_audit_ai5_mes_exe.Case.test_c",
            "test_audit_ai5_mes_exe.Case.test_d",
            "test_other.Case.test_fast_a",
            "test_other.Case.test_fast_b",
        ]
        shards = regression.balanced_shards(test_ids, 2)

        flattened = [test_id for shard in shards for test_id in shard]
        self.assertEqual(sorted(test_ids), sorted(flattened))
        self.assertEqual(len(test_ids), len(set(flattened)))
        self.assertTrue(
            all(
                any(test_id.startswith("test_audit_ai5_mes_exe.") for test_id in shard)
                for shard in shards
            )
        )

    def test_invalid_job_count_fails_closed(self) -> None:
        with self.assertRaisesRegex(ValueError, "greater than zero"):
            regression.balanced_shards(["test_module.Case.test_method"], 0)


class CommandBatchTests(unittest.TestCase):
    PREFIX = ("python", "-m", "unittest")

    def test_batches_cover_every_test_once_in_order(self) -> None:
        test_ids = [f"test_module.Case.test_{index:04d}" for index in range(500)]
        batches = regression.command_batches(test_ids, self.PREFIX, limit=400)

        self.assertGreater(len(batches), 1)
        self.assertEqual(
            test_ids, [test_id for batch in batches for test_id in batch]
        )

    def test_every_batch_fits_the_budget(self) -> None:
        test_ids = [f"test_module.Case.test_{index:04d}" for index in range(500)]
        batches = regression.command_batches(test_ids, self.PREFIX, limit=400)

        for batch in batches:
            self.assertLessEqual(
                regression.command_length(self.PREFIX, batch), 400
            )

    def test_discovered_suite_fits_at_the_default_job_count(self) -> None:
        # The regression that motivated the budget: one shard's command line
        # measured 35,343 characters against the Windows limit of 32,767.
        prefix = (sys.executable, "-m", "unittest")
        test_ids = regression.discover_test_ids(ROOT / "tests")
        shards = regression.balanced_shards(test_ids, regression.DEFAULT_MAX_JOBS)

        for shard in shards:
            for batch in regression.command_batches(shard, prefix):
                self.assertLessEqual(
                    regression.command_length(prefix, batch),
                    regression.MAX_COMMAND_LINE_CHARS,
                )

    def test_oversized_single_test_is_still_emitted_alone(self) -> None:
        test_ids = ["test_module.Case." + "x" * 600]
        batches = regression.command_batches(test_ids, self.PREFIX, limit=100)

        self.assertEqual([test_ids], batches)

    def test_invalid_budget_fails_closed(self) -> None:
        with self.assertRaisesRegex(ValueError, "greater than zero"):
            regression.command_batches(["a.B.c"], self.PREFIX, limit=0)


class BatchLaunchFailureTests(unittest.TestCase):
    def test_launch_failure_is_reported_rather_than_raised(self) -> None:
        with mock.patch.object(
            regression.subprocess, "run", side_effect=OSError(206, "too long")
        ):
            result = regression._run_batch(
                ("python", "-m", "unittest"),
                ["test_module.Case.test_method"],
                ROOT,
                {},
                timeout=5,
            )

        self.assertEqual("launch_failed", result.status)
        self.assertIsNone(result.return_code)
        self.assertIn("PYTHON_REGRESSION_LAUNCH_ERROR", result.output)

    def test_a_failed_launch_fails_the_run(self) -> None:
        results = [
            regression.ShardResult(
                index=0,
                test_count=1,
                batch_count=1,
                return_code=None,
                status="launch_failed",
                duration_seconds=0.0,
                output="",
            )
        ]

        self.assertTrue([item for item in results if item.status != "passed"])


class OriginalExecutableEnvironmentTests(unittest.TestCase):
    """WD-25 item 1: the executable reaches the shards only when `--exe` names it."""

    VARIABLE = "KAKYU_ORIGINAL_EXE"

    def _shard_environment(self, **keywords: object) -> dict[str, str]:
        captured: list[dict[str, str]] = []

        def fake_run_batch(prefix, test_ids, project, environment, timeout):  # type: ignore[no-untyped-def]
            captured.append(dict(environment))
            return regression.BatchResult(return_code=0, status="passed", output="")

        with mock.patch.object(regression, "_run_batch", side_effect=fake_run_batch):
            result = regression._run_shard(
                0, ["test_module.Case.test_method"], ROOT, ROOT / "tests", 5, **keywords
            )
        self.assertEqual("passed", result.status)
        self.assertEqual(1, len(captured))
        return captured[0]

    def test_exe_sets_the_variable_in_the_shard_environment(self) -> None:
        with mock.patch.dict(os.environ, {self.VARIABLE: "inherited"}):
            environment = self._shard_environment(original_executable=Path("named.exe"))
        self.assertEqual(str(Path("named.exe")), environment[self.VARIABLE])

    def test_without_exe_an_inherited_value_is_removed(self) -> None:
        with mock.patch.dict(os.environ, {self.VARIABLE: "inherited"}):
            environment = self._shard_environment()
        self.assertNotIn(self.VARIABLE, environment)

    def test_without_exe_and_without_an_inherited_value_nothing_is_set(self) -> None:
        with mock.patch.dict(os.environ):
            os.environ.pop(self.VARIABLE, None)
            environment = self._shard_environment()
        self.assertNotIn(self.VARIABLE, environment)

    def test_a_missing_path_is_a_configuration_error(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            absent = Path(directory) / "absent.exe"
            output = io.StringIO()
            with (
                mock.patch.object(sys, "argv", ["run_python_regression.py", "--exe", str(absent)]),
                mock.patch.object(
                    regression, "discover_test_ids", side_effect=AssertionError("must not discover")
                ),
                contextlib.redirect_stdout(output),
            ):
                return_code = regression.main()
        self.assertEqual(2, return_code)
        self.assertIn("PYTHON_REGRESSION_CONFIGURATION_ERROR", output.getvalue())

    def test_a_directory_is_not_an_executable(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            output = io.StringIO()
            with (
                mock.patch.object(sys, "argv", ["run_python_regression.py", "--exe", directory]),
                mock.patch.object(
                    regression, "discover_test_ids", side_effect=AssertionError("must not discover")
                ),
                contextlib.redirect_stdout(output),
            ):
                return_code = regression.main()
        self.assertEqual(2, return_code)

    def test_main_hands_the_resolved_path_to_every_shard(self) -> None:
        seen: list[Path | None] = []

        def fake_run_shard(index, test_ids, project, test_root, timeout, original_executable=None, original_archives=None):  # type: ignore[no-untyped-def]
            seen.append(original_executable)
            return regression.ShardResult(
                index=index, test_count=len(test_ids), batch_count=1, return_code=0,
                status="passed", duration_seconds=0.0, output="",
            )

        with tempfile.TemporaryDirectory() as directory:
            executable = Path(directory) / "AI5WIN.exe"
            executable.write_bytes(b"fixture")
            ids = ["test_module.Case.test_a", "test_module.Case.test_b", "test_module.Case.test_c"]
            with (
                mock.patch.object(
                    sys, "argv", ["run_python_regression.py", "--jobs", "2", "--exe", str(executable)]
                ),
                mock.patch.object(regression, "discover_test_ids", return_value=ids),
                mock.patch.object(regression, "_run_shard", side_effect=fake_run_shard),
                contextlib.redirect_stdout(io.StringIO()),
            ):
                return_code = regression.main()
            expected = executable.resolve()
        self.assertEqual(0, return_code)
        self.assertEqual([expected, expected], seen)

    def test_main_without_exe_passes_none(self) -> None:
        seen: list[Path | None] = []

        def fake_run_shard(index, test_ids, project, test_root, timeout, original_executable=None, original_archives=None):  # type: ignore[no-untyped-def]
            seen.append(original_executable)
            return regression.ShardResult(
                index=index, test_count=len(test_ids), batch_count=1, return_code=0,
                status="passed", duration_seconds=0.0, output="",
            )

        with (
            mock.patch.object(sys, "argv", ["run_python_regression.py", "--jobs", "1"]),
            mock.patch.object(regression, "discover_test_ids", return_value=["test_module.Case.test_a"]),
            mock.patch.object(regression, "_run_shard", side_effect=fake_run_shard),
            contextlib.redirect_stdout(io.StringIO()),
        ):
            return_code = regression.main()
        self.assertEqual(0, return_code)
        self.assertEqual([None], seen)


class OriginalArchivesEnvironmentTests(unittest.TestCase):
    """WD-25 item 1b: the archives reach the shards only as the pair `--mes-arc`/`--data-arc` names."""

    MES = "KAKYU_MES_ARC"
    DATA = "KAKYU_DATA_ARC"

    def _shard_environment(self, **keywords: object) -> dict[str, str]:
        captured: list[dict[str, str]] = []

        def fake_run_batch(prefix, test_ids, project, environment, timeout):  # type: ignore[no-untyped-def]
            captured.append(dict(environment))
            return regression.BatchResult(return_code=0, status="passed", output="")

        with mock.patch.object(regression, "_run_batch", side_effect=fake_run_batch):
            result = regression._run_shard(
                0, ["test_module.Case.test_method"], ROOT, ROOT / "tests", 5, **keywords
            )
        self.assertEqual("passed", result.status)
        return captured[0]

    def _main(self, arguments: list[str], **patches: object) -> tuple[int, str]:
        output = io.StringIO()
        with (
            mock.patch.object(sys, "argv", ["run_python_regression.py", *arguments]),
            mock.patch.object(regression, "discover_test_ids", **patches),
            contextlib.redirect_stdout(output),
        ):
            return regression.main(), output.getvalue()

    def test_the_pair_sets_both_variables_over_inherited_values(self) -> None:
        with mock.patch.dict(os.environ, {self.MES: "inherited", self.DATA: "inherited"}):
            environment = self._shard_environment(original_archives=(Path("m.arc"), Path("d.arc")))
        self.assertEqual(str(Path("m.arc")), environment[self.MES])
        self.assertEqual(str(Path("d.arc")), environment[self.DATA])

    def test_without_the_pair_every_inherited_value_is_removed(self) -> None:
        with mock.patch.dict(os.environ, {self.MES: "inherited", self.DATA: "inherited"}):
            environment = self._shard_environment()
        self.assertNotIn(self.MES, environment)
        self.assertNotIn(self.DATA, environment)
        with mock.patch.dict(os.environ, {self.MES: "inherited"}):
            os.environ.pop(self.DATA, None)
            environment = self._shard_environment()
        self.assertNotIn(self.MES, environment)
        self.assertNotIn(self.DATA, environment)

    def test_the_executable_and_the_archives_are_independent(self) -> None:
        environment = self._shard_environment(original_archives=(Path("m.arc"), Path("d.arc")))
        self.assertNotIn("KAKYU_ORIGINAL_EXE", environment)
        environment = self._shard_environment(original_executable=Path("named.exe"))
        self.assertEqual(str(Path("named.exe")), environment["KAKYU_ORIGINAL_EXE"])
        self.assertNotIn(self.MES, environment)

    def test_one_archive_without_the_other_is_a_configuration_error(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            archive = Path(directory) / "mes.arc"
            archive.write_bytes(b"fixture")
            for option in ("--mes-arc", "--data-arc"):
                code, output = self._main(
                    [option, str(archive)], side_effect=AssertionError("must not discover")
                )
                self.assertEqual(2, code, option)
                self.assertIn("PYTHON_REGRESSION_CONFIGURATION_ERROR", output)
                self.assertIn("together or not at all", output)

    def test_a_missing_or_directory_archive_is_a_configuration_error(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            present = Path(directory) / "present.arc"
            present.write_bytes(b"fixture")
            for mes, data in ((Path(directory) / "absent.arc", present), (present, directory)):
                code, output = self._main(
                    ["--mes-arc", str(mes), "--data-arc", str(data)],
                    side_effect=AssertionError("must not discover"),
                )
                self.assertEqual(2, code)
                self.assertIn("must each name an existing file", output)

    def test_main_hands_the_resolved_pair_to_every_shard(self) -> None:
        seen: list[tuple[Path, Path] | None] = []

        def fake_run_shard(index, test_ids, project, test_root, timeout, original_executable=None, original_archives=None):  # type: ignore[no-untyped-def]
            seen.append(original_archives)
            return regression.ShardResult(
                index=index, test_count=len(test_ids), batch_count=1, return_code=0,
                status="passed", duration_seconds=0.0, output="",
            )

        ids = ["test_module.Case.test_a", "test_module.Case.test_b", "test_module.Case.test_c"]
        with tempfile.TemporaryDirectory() as directory:
            mes, data = Path(directory) / "mes.arc", Path(directory) / "data.arc"
            mes.write_bytes(b"fixture")
            data.write_bytes(b"fixture")
            with mock.patch.object(regression, "_run_shard", side_effect=fake_run_shard):
                code, _output = self._main(
                    ["--jobs", "2", "--mes-arc", str(mes), "--data-arc", str(data)], return_value=ids
                )
            expected = (mes.resolve(), data.resolve())
        self.assertEqual(0, code)
        self.assertEqual([expected, expected], seen)

    def test_main_without_the_pair_passes_none(self) -> None:
        seen: list[tuple[Path, Path] | None] = []

        def fake_run_shard(index, test_ids, project, test_root, timeout, original_executable=None, original_archives=None):  # type: ignore[no-untyped-def]
            seen.append(original_archives)
            return regression.ShardResult(
                index=index, test_count=len(test_ids), batch_count=1, return_code=0,
                status="passed", duration_seconds=0.0, output="",
            )

        with mock.patch.object(regression, "_run_shard", side_effect=fake_run_shard):
            code, _output = self._main(["--jobs", "1"], return_value=["test_module.Case.test_a"])
        self.assertEqual(0, code)
        self.assertEqual([None], seen)


if __name__ == "__main__":
    unittest.main()
