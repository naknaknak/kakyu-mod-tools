from __future__ import annotations

import argparse
import contextlib
import hashlib
import io
import json
import shutil
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools" / "content_suite"))

import run_headless_validation as validation  # noqa: E402
import validation_inputs  # noqa: E402
from test_validation_report import sample_report  # noqa: E402
from validation_report import validate_payload  # noqa: E402

# The native executable audits are not part of the public source snapshot
# (WD-25 item 7a): its registry drops their checks, so an assertion about one
# of those checks runs only when the check's script exists. In this repository
# every script exists and every assertion runs.
NATIVE_AUDIT_SCRIPT_OF_CHECK = {
    "original executable native ARC contract": "tools/audit_ai5_arc_exe.py",
    "original executable native MES contract": "tools/audit_ai5_mes_exe.py",
    "original MES logical exact-one truth contract": "tools/audit_mes_logical_truth.py",
    "original EVENTB03 camera and AX boundary contract": "tools/audit_eventb03_camera.py",
    "original EVENTB03 SE occurrences and native wait contract": "tools/audit_eventb03_sound.py",
    "original MES calendar state-layout contract": "tools/audit_mes_calendar_rows.py",
    "original MES promise calendar-field contract": "tools/audit_mes_promise_calendar_fields.py",
    "original MES promise location-route contract": "tools/audit_mes_promise_location_routes.py",
    "original MES PROMIS caller/native contract": "tools/audit_mes_promise_callers.py",
    "original executable native Ogg voice contract": "tools/audit_ai5_audio_exe.py",
}


def has_native_audit(check_name: str) -> bool:
    return (ROOT / NATIVE_AUDIT_SCRIPT_OF_CHECK[check_name]).is_file()


class _KeepCheckoutClean:
    """TD-52: `main()` resolves the real project root, so every test that runs
    it would otherwise write `analysis/.gdignore` into the checkout through
    `ensure_editor_ignore()`. Patch the helper out; `EditorIgnoreTests` pins it."""

    def setUp(self) -> None:
        super().setUp()
        patcher = mock.patch.object(validation, "ensure_editor_ignore", return_value=False)
        patcher.start()
        self.addCleanup(patcher.stop)


class HeadlessValidationBatchTests(_KeepCheckoutClean, unittest.TestCase):
    def test_output_stream_configuration_is_supported(self) -> None:
        validation.configure_output_streams()
        self.assertEqual("utf-8", sys.stdout.encoding.lower())

    def test_base_batch_covers_every_independent_app(self) -> None:
        arguments = argparse.Namespace(
            elfimage=None,
            exe=None,
            skip_event_corpus=False,
        )
        checks = validation.build_checks(arguments, ROOT, Path("godot"))
        names = {check.name for check in checks}
        self.assertIn("Godot test_mes_caller_route.tscn", names)
        self.assertIn("Godot test_mes_script_call_runner.tscn", names)
        self.assertIn("Godot test_mes_startup_context.tscn", names)
        self.assertIn("Godot test_mes_calendar_state.tscn", names)
        self.assertIn("Godot test_mes_station_background_plan.tscn", names)
        self.assertIn("Godot test_mes_mahoko_standing_plan.tscn", names)
        self.assertIn("Godot test_mes_eventb03_candidate_plan.tscn", names)
        self.assertIn("Godot test_mes_station_candidate_priority_plan.tscn", names)
        self.assertIn("Godot test_mes_station_candidate_prefix_plan.tscn", names)
        self.assertIn("Godot test_mes_station_eventb03_decision_plan.tscn", names)
        self.assertIn("Godot test_mes_routine40_group_preview_contract.tscn", names)
        self.assertIn("Godot test_mes_control_target_relocation_plan.tscn", names)
        self.assertIn("Godot test_mes_control_target_compile_reopen.tscn", names)
        self.assertIn("Godot test_mes_state_literal_edit_plan.tscn", names)
        self.assertIn("Godot test_mes_state_literal_compile_reopen.tscn", names)
        self.assertIn("Godot test_mes_condition_literal_edit_plan.tscn", names)
        self.assertIn("Godot test_mes_condition_literal_compile_reopen.tscn", names)
        self.assertIn("Godot test_mes_resource_name_edit_plan.tscn", names)
        self.assertIn("Godot test_mes_resource_name_compile_reopen.tscn", names)
        self.assertIn("Godot test_mes_inline_script_name_edit_plan.tscn", names)
        self.assertIn("Godot test_mes_inline_script_name_compile_reopen.tscn", names)
        self.assertIn("Godot test_mes_shared_routine_call_edit_plan.tscn", names)
        self.assertIn("Godot test_mes_shared_routine_call_compile_reopen.tscn", names)
        self.assertIn("Godot test_logical_surface_compositor.tscn", names)
        self.assertIn("Godot test_oversized_cg_camera.tscn", names)
        self.assertIn("Godot test_arc_browser.tscn", names)
        self.assertIn("Godot test_mes_editor.tscn", names)
        self.assertIn("Godot test_event_player.tscn", names)
        self.assertIn("Godot test_event_player_run_request.tscn", names)
        self.assertIn("Godot test_image_arc_editor.tscn", names)
        self.assertIn("Godot test_audio_arc_editor.tscn", names)
        self.assertIn("Godot project parse check", names)
        self.assertNotIn("original MES analyzer handoff corpus", names)
        self.assertNotIn("original Python Phase 1-4 full handoff equivalence", names)
        python_check = next(
            check for check in checks if check.name == "python regression suite"
        )
        self.assertEqual(
            validation.PYTHON_REGRESSION_TIMEOUT_SECONDS,
            python_check.timeout,
        )
        self.assertEqual(3600, python_check.timeout)
        self.assertIn(
            "tools/content_suite/run_python_regression.py",
            python_check.command,
        )
        self.assertIn("--jobs", python_check.command)

    def test_every_test_scene_on_disk_is_in_the_batch(self) -> None:
        arguments = argparse.Namespace(
            elfimage=None,
            exe=None,
            skip_event_corpus=False,
        )
        checks = validation.build_checks(arguments, ROOT, Path("godot"))
        batched = {
            check.name.removeprefix("Godot ")
            for check in checks
            if check.name.startswith("Godot test_")
        }
        on_disk = {path.name for path in (ROOT / "tests").glob("*.tscn")}

        self.assertTrue(on_disk)
        self.assertEqual(on_disk, batched)

    def test_the_batch_names_no_absent_scene(self) -> None:
        arguments = argparse.Namespace(
            elfimage=None,
            exe=None,
            skip_event_corpus=False,
        )
        checks = validation.build_checks(arguments, ROOT, Path("godot"))

        for check in checks:
            if not check.name.startswith("Godot test_"):
                continue
            scene = check.name.removeprefix("Godot ")
            self.assertTrue(
                (ROOT / "tests" / scene).is_file(),
                f"{scene} is in the batch but not on disk",
            )

    def test_original_batch_covers_every_analysis_profile_exactly_once(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            source_root = Path(directory)
            for name in ("mes.arc", "mmo.arc", "data.arc"):
                (source_root / name).write_bytes(b"fixture")
            arguments = argparse.Namespace(
                elfimage=source_root, exe=None, skip_event_corpus=False,
            )
            checks = validation.build_checks(arguments, ROOT, Path("godot"))
        validator = "res://tools/content_suite/validators/validate_event_analysis_group.gd"
        profiles = [
            check.command[-1] for check in checks if validator in check.command
        ]
        expected = {
            path.relative_to(ROOT).as_posix()
            for path in (ROOT / "config/event_catalog/analysis_groups").glob("*.json")
        }
        self.assertEqual(expected, set(profiles))
        self.assertEqual(len(expected), len(profiles), "Duplicate analysis profile checks")

    def test_missing_scene_directory_fails_closed(self) -> None:
        arguments = argparse.Namespace(
            elfimage=None,
            exe=None,
            skip_event_corpus=False,
        )
        with tempfile.TemporaryDirectory() as empty:
            with self.assertRaisesRegex(ValueError, "No Godot test scenes"):
                validation.build_checks(arguments, Path(empty), Path("godot"))

    def test_python_regression_timeout_is_explicitly_overridable(self) -> None:
        arguments = argparse.Namespace(
            elfimage=None,
            exe=None,
            skip_event_corpus=False,
            python_timeout=4200,
        )
        checks = validation.build_checks(arguments, ROOT, Path("godot"))
        python_check = next(
            check for check in checks if check.name == "python regression suite"
        )
        self.assertEqual(4200, python_check.timeout)

        arguments.python_timeout = 0
        with self.assertRaisesRegex(ValueError, "greater than zero"):
            validation.build_checks(arguments, ROOT, Path("godot"))

    def test_python_regression_jobs_are_explicitly_overridable(self) -> None:
        arguments = argparse.Namespace(
            elfimage=None,
            exe=None,
            skip_event_corpus=False,
            python_timeout=4200,
            python_jobs=3,
        )
        checks = validation.build_checks(arguments, ROOT, Path("godot"))
        python_check = next(
            check for check in checks if check.name == "python regression suite"
        )
        jobs_index = python_check.command.index("--jobs")
        self.assertEqual("3", python_check.command[jobs_index + 1])

        arguments.python_jobs = 0
        with self.assertRaisesRegex(ValueError, "greater than zero"):
            validation.build_checks(arguments, ROOT, Path("godot"))

    def test_python_regression_receives_the_executable_only_when_given(self) -> None:
        """WD-25 item 1: the native-audit tests read the user's executable, so
        the suite is handed `--exe` when the run has one, and not otherwise."""
        arguments = argparse.Namespace(elfimage=None, exe=None, skip_event_corpus=False)
        python_check = next(
            check
            for check in validation.build_checks(arguments, ROOT, Path("godot"))
            if check.name == "python regression suite"
        )
        self.assertNotIn("--exe", python_check.command)
        self.assertNotIn("exe", python_check.requires)
        self.assertNotIn("native_executable", python_check.groups)

        with tempfile.TemporaryDirectory() as directory:
            executable = Path(directory) / "AI5WIN.exe"
            executable.write_bytes(b"fixture")
            arguments = argparse.Namespace(elfimage=None, exe=executable, skip_event_corpus=False)
            planned = validation.build_checks(arguments, ROOT, Path("godot"))
            python_checks = [check for check in planned if check.name == "python regression suite"]
            self.assertEqual(1, len(python_checks))
            python_check = python_checks[0]
            self.assertEqual(("--exe", str(executable.resolve())), python_check.command[-2:])
            self.assertIn("exe", python_check.requires)
            self.assertIn("native_executable", python_check.groups)
            self.assertEqual("local", python_check.tier)

            # The executable is then an input of the suite's cache fingerprint.
            context, _available = validation._registry_placeholder_context(
                arguments=arguments, project=ROOT, godot=Path("godot"), python_jobs=1, python_timeout=100,
            )
            inputs = validation_inputs.check_inputs(python_check, ROOT, context)
            self.assertIn("exe", inputs.external)
            self.assertEqual(executable.resolve(), inputs.external_paths["exe"].resolve())

    def test_python_regression_receives_the_archives_only_with_elfimage(self) -> None:
        """WD-25 item 1b: the archive-literal guard reads the user's `mes.arc` and `data.arc`, so
        the suite is handed the pair when the run has an ELFIMAGE, and nothing otherwise."""
        arguments = argparse.Namespace(elfimage=None, exe=None, skip_event_corpus=False)
        python_check = next(
            check
            for check in validation.build_checks(arguments, ROOT, Path("godot"))
            if check.name == "python regression suite"
        )
        self.assertNotIn("--mes-arc", python_check.command)
        self.assertNotIn("--data-arc", python_check.command)
        self.assertNotIn("elfimage", python_check.requires)
        self.assertNotIn("original_corpus", python_check.groups)

        with tempfile.TemporaryDirectory() as directory:
            source_root = Path(directory) / "ELFIMAGE"
            source_root.mkdir()
            for archive_name in ("mes.arc", "mmo.arc", "data.arc", "voice.arc", "se.arc"):
                (source_root / archive_name).write_bytes(b"fixture")
            executable = Path(directory) / "AI5WIN.exe"
            executable.write_bytes(b"fixture")
            arguments = argparse.Namespace(elfimage=source_root, exe=executable, skip_event_corpus=False)
            planned = validation.build_checks(arguments, ROOT, Path("godot"))
            python_checks = [check for check in planned if check.name == "python regression suite"]
            self.assertEqual(1, len(python_checks))
            python_check = python_checks[0]
            root = source_root.resolve()
            self.assertEqual(
                ("--exe", str(executable.resolve()), "--mes-arc", str(root / "mes.arc"), "--data-arc", str(root / "data.arc")),
                python_check.command[-6:],
            )
            # The command never names the ELFIMAGE directory, so the fingerprint does not hash every archive.
            self.assertNotIn(str(root), python_check.command)
            self.assertIn("elfimage", python_check.requires)
            self.assertIn("exe", python_check.requires)
            self.assertIn("original_corpus", python_check.groups)
            self.assertIn("native_executable", python_check.groups)
            self.assertEqual("local", python_check.tier)

            context, _available = validation._registry_placeholder_context(
                arguments=arguments, project=ROOT, godot=Path("godot"), python_jobs=1, python_timeout=100,
            )
            inputs = validation_inputs.check_inputs(python_check, ROOT, context)
            self.assertEqual(("data_arc", "exe", "mes_arc"), inputs.external)
            self.assertEqual((root / "mes.arc"), inputs.external_paths["mes_arc"].resolve())
            self.assertEqual((root / "data.arc"), inputs.external_paths["data_arc"].resolve())

            # ELFIMAGE alone adds the pair and the group, not the executable.
            arguments = argparse.Namespace(elfimage=source_root, exe=None, skip_event_corpus=False)
            planned = validation.build_checks(arguments, ROOT, Path("godot"))
            python_check = next(check for check in planned if check.name == "python regression suite")
            self.assertNotIn("--exe", python_check.command)
            self.assertEqual("--mes-arc", python_check.command[-4])
            self.assertNotIn("native_executable", python_check.groups)

    def test_original_batch_requires_and_routes_read_only_sources(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            source_root = Path(directory) / "ELFIMAGE"
            source_root.mkdir()
            for archive_name in ("mes.arc", "mmo.arc", "data.arc", "voice.arc", "se.arc"):
                (source_root / archive_name).write_bytes(b"fixture")
            executable = Path(directory) / "AI5WIN.exe"
            executable.write_bytes(b"fixture")
            arguments = argparse.Namespace(
                elfimage=source_root,
                exe=executable,
                skip_event_corpus=False,
            )
            checks = validation.build_checks(arguments, ROOT, Path("godot"))

        names = {check.name for check in checks}
        self.assertIn("original ARC corpus", names)
        self.assertIn("original MES record-alignment corpus", names)
        handoff_checks = [
            check for check in checks if check.name == "original MES analyzer handoff corpus"
        ]
        self.assertEqual(len(handoff_checks), 1)
        handoff_check = handoff_checks[0]
        self.assertIn("res://tools/content_suite/cli/audit_mes_analyzer_handoff_corpus.gd", handoff_check.command)
        self.assertEqual(handoff_check.command[-2:], ("--", str((source_root / "mes.arc").resolve())))
        self.assertEqual(handoff_check.timeout, 3000)
        python_handoff = next(check for check in checks if check.name == "original Python Phase 1-4 full handoff equivalence")
        self.assertIn("tools/audit_mes_handoff_equivalence.py", python_handoff.command)
        self.assertIn(validation.FROZEN_HANDOFF_DIGEST, python_handoff.command)
        self.assertIn(str((source_root / "mes.arc").resolve()), python_handoff.command)
        self.assertIn("--require-full-equivalent", python_handoff.command)
        self.assertNotIn("--limit", python_handoff.command)
        self.assertEqual(validation.PYTHON_HANDOFF_TIMEOUT_SECONDS, python_handoff.timeout)
        self.assertIn("original MES Event Runner exhaustive corpus", names)
        self.assertIn("original MES library routine-28 execution", names)
        self.assertIn("original MES routine-40 gated result contract", names)
        self.assertIn("original MES library DEF routes", names)
        self.assertIn("original MES DEF26 context", names)
        self.assertIn("original MES startup execution records", names)
        self.assertIn("original MES surface-operation core audit", names)
        self.assertIn("original MES calendar state", names)
        self.assertIn("original MES DEF12 calendar execution", names)
        self.assertIn("original MES DEF12 library-26 execution", names)
        self.assertIn("original MES library routine-26/24 execution", names)
        self.assertIn("original MES PROMIS writer owner boundaries", names)
        self.assertIn("original MES PROMIS date library resumes", names)
        self.assertIn("original MES PROMIS C/E/I date routes", names)
        self.assertIn("original MES PROMIS caller reachability", names)
        self.assertIn("original MES PROMIS nested call routes", names)
        self.assertIn("original MES startup context path", names)
        self.assertIn("original MES presentation state transfers", names)
        self.assertIn("original MES detached DEF previews", names)
        self.assertIn("original MES F_DATE2 nested DEF", names)
        self.assertIn("original Event Player DEF26 isolated body", names)
        self.assertIn("original Event Player F_DATE2 detached DEF", names)
        self.assertIn("original Event Player PROMIS scheduling routes", names)
        self.assertIn("original Event Player nested PROMIS callers", names)
        self.assertIn("original MES DEF registry audit", names)
        self.assertIn("original MES startup bootstrap audit", names)
        self.assertIn("original MES surface-operation audit", names)
        self.assertIn("original EVENTD08 composed choice routes", names)
        self.assertIn("original EVENTB03 state12 source branch matrix", names)
        self.assertIn("original EVENTB03 affection source branch matrix", names)
        self.assertIn("original EVENTB03 preset choices source matrix", names)
        flag_check = next(check for check in checks if check.name == "original EVENTB03 face flags source matrix")
        self.assertIn("res://tools/content_suite/cli/audit_eventb03_face_flags.gd", flag_check.command)
        self.assertEqual(str(source_root.resolve()), flag_check.command[-1])
        self.assertEqual(120, flag_check.timeout)
        station_check = next(check for check in checks if check.name == "original station background selection source matrix")
        self.assertIn("res://tools/content_suite/cli/validate_mes_station_background_plan.gd", station_check.command)
        self.assertEqual(str(source_root.resolve()), station_check.command[-1])
        self.assertEqual(180, station_check.timeout)
        standing_check = next(check for check in checks if check.name == "original Mahoko standing selection source matrix")
        self.assertIn("res://tools/content_suite/cli/validate_mes_mahoko_standing_plan.gd", standing_check.command)
        self.assertEqual(str(source_root.resolve()), standing_check.command[-1])
        self.assertEqual(180, standing_check.timeout)
        candidate_check = next(check for check in checks if check.name == "original EVENTB03 station candidate source route")
        self.assertIn("res://tools/content_suite/cli/validate_mes_eventb03_candidate_plan.gd", candidate_check.command)
        self.assertEqual(str(source_root.resolve()), candidate_check.command[-1])
        self.assertEqual(180, candidate_check.timeout)
        priority_check = next(check for check in checks if check.name == "original station candidate priority source route")
        self.assertIn("res://tools/content_suite/cli/validate_mes_station_candidate_priority_plan.gd", priority_check.command)
        self.assertEqual(str(source_root.resolve()), priority_check.command[-1])
        self.assertEqual(180, priority_check.timeout)
        prefix_check = next(check for check in checks if check.name == "original station candidate prefix source route")
        self.assertIn("res://tools/content_suite/cli/validate_mes_station_candidate_prefix_plan.gd", prefix_check.command)
        self.assertEqual(str(source_root.resolve()), prefix_check.command[-1])
        self.assertEqual(180, prefix_check.timeout)
        decision_check = next(check for check in checks if check.name == "original station EVENTB03 frozen decision source route")
        self.assertIn("res://tools/content_suite/cli/validate_mes_station_eventb03_decision_plan.gd", decision_check.command)
        self.assertEqual(str(source_root.resolve()), decision_check.command[-1])
        self.assertEqual(180, decision_check.timeout)
        export_check = next(check for check in checks if check.name == "original playback package export")
        self.assertIn("res://tools/content_suite/cli/export_playback_package.gd", export_check.command)
        self.assertEqual(str(source_root.resolve()), export_check.command[-1])
        self.assertEqual(900, export_check.timeout)
        playback_check = next(check for check in checks if check.name == "original playback package playback")
        self.assertIn("res://tools/content_suite/cli/validate_playback_package_playback.gd", playback_check.command)
        self.assertEqual(str(source_root.resolve()), playback_check.command[-1])
        self.assertEqual(1800, playback_check.timeout)
        self.assertFalse(playback_check.exclusive)  # TD-64 part 2 D5: runs beside other checks
        self.assertIn("original Event Player fragment catalogs", names)
        self.assertIn("original ARC Browser original integration", names)
        self.assertIn("original Image Editor original integration", names)
        self.assertIn("original Audio Editor original integration", names)
        if has_native_audit("original executable native ARC contract"):
            self.assertIn("original executable native ARC contract", names)
        if has_native_audit("original executable native MES contract"):
            self.assertIn("original executable native MES contract", names)
        if has_native_audit("original MES logical exact-one truth contract"):
            logical_check = next(check for check in checks if check.name == "original MES logical exact-one truth contract")
            self.assertIn("tools/audit_mes_logical_truth.py", logical_check.command)
            self.assertEqual(("--exe", str(executable.resolve())), logical_check.command[-2:])
            self.assertEqual(180, logical_check.timeout)
        if has_native_audit("original EVENTB03 camera and AX boundary contract"):
            camera_check = next(check for check in checks if check.name == "original EVENTB03 camera and AX boundary contract")
            self.assertIn(str((source_root / "mes.arc").resolve()), camera_check.command)
            self.assertIn(str(executable.resolve()), camera_check.command)
            self.assertEqual(("--godot-console", "godot"), camera_check.command[-2:])
        if has_native_audit("original EVENTB03 SE occurrences and native wait contract"):
            sound_check = next(check for check in checks if check.name == "original EVENTB03 SE occurrences and native wait contract")
            self.assertIn(str((source_root / "se.arc").resolve()), sound_check.command)
            self.assertIn(str((source_root / "mmo.arc").resolve()), sound_check.command)
            self.assertIn(str(executable.resolve()), sound_check.command)
            self.assertEqual(("--godot-console", "godot"), sound_check.command[-2:])
        for later_audit in (
            "original MES calendar state-layout contract",
            "original MES promise calendar-field contract",
            "original MES promise location-route contract",
            "original MES PROMIS caller/native contract",
            "original executable native Ogg voice contract",
        ):
            if has_native_audit(later_audit):
                self.assertIn(later_audit, names)
        arc_check = next(check for check in checks if check.name == "original ARC corpus")
        self.assertIn(str(source_root.resolve()), arc_check.command)
        if has_native_audit("original executable native Ogg voice contract"):
            audio_exe_check = next(
                check
                for check in checks
                if check.name == "original executable native Ogg voice contract"
            )
            self.assertIn("--voice-arc", audio_exe_check.command)
            self.assertIn(str((source_root / "voice.arc").resolve()), audio_exe_check.command)
            self.assertIn("--mes-arc", audio_exe_check.command)
            self.assertIn(str((source_root / "mes.arc").resolve()), audio_exe_check.command)

    @unittest.skipUnless(
        has_native_audit("original executable native Ogg voice contract"),
        "the native executable audits are not in the public source snapshot",
    )
    def test_optional_voice_archive_does_not_block_original_batch(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            source_root = Path(directory) / "ELFIMAGE"
            source_root.mkdir()
            for archive_name in ("mes.arc", "mmo.arc", "data.arc"):
                (source_root / archive_name).write_bytes(b"fixture")
            executable = Path(directory) / "AI5WIN.exe"
            executable.write_bytes(b"fixture")
            arguments = argparse.Namespace(
                elfimage=source_root,
                exe=executable,
                skip_event_corpus=False,
            )
            checks = validation.build_checks(arguments, ROOT, Path("godot"))

        audio_exe_check = next(
            check
            for check in checks
            if check.name == "original executable native Ogg voice contract"
        )
        self.assertNotIn("--voice-arc", audio_exe_check.command)
        self.assertIn("--mes-arc", audio_exe_check.command)

    def test_report_write_is_valid_and_replaces_existing_file(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory) / "validation.json"
            target.write_text("stale", encoding="utf-8")
            report = sample_report()
            validation.write_report(target, report)
            envelope = json.loads(target.read_text(encoding="utf-8"))
            self.assertEqual(report, json.loads(envelope["payload_json"]))
            self.assertEqual(hashlib.sha256(envelope["payload_json"].encode("utf-8")).hexdigest(), envelope["payload_sha256"])
            self.assertEqual([], list(target.parent.glob("*.tmp-*")))

    def test_frozen_comparison_digest_is_complete_and_contains_only_fingerprints_and_counts(self) -> None:
        sys.path.insert(0, str(ROOT / "tools"))
        from audit_mes_handoff_equivalence import read_digest
        header, entries, footer = read_digest(ROOT / validation.FROZEN_HANDOFF_DIGEST)
        self.assertEqual("31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6", header["archive_sha256"])
        self.assertEqual(1016, len(entries))
        self.assertEqual("74f1408836440b7194ffb25aaa498aa8b61bda695326ed148ccd35a562a1dff8", footer["corpus_handoff_sha256"])
        for row in entries.values():
            self.assertEqual({"kind", "entry", "ok", "entry_sha256", "payload_sha256", "components", "counts"}, set(row))
            self.assertTrue(all(type(value) is int for value in row["counts"].values()))

    def test_audit_failure_remains_failed_in_the_batch_result(self) -> None:
        check = validation.Check("original MES analyzer handoff corpus", ("godot",), 1800)
        failed_audit = validation.subprocess.CompletedProcess(
            check.command, 1, stdout="MES_ANALYZER_COMPLETION status=failed failures=1\n"
        )
        with mock.patch.object(validation.subprocess, "run", return_value=failed_audit):
            result = validation.run_check(check, ROOT)
        self.assertEqual(result["status"], "failed")
        self.assertEqual(result["return_code"], 1)

    def test_zero_exit_godot_script_errors_fail_and_keep_the_reason(self) -> None:
        check = validation.Check("parse", validation.godot_command(Path("godot"), ROOT), 30)
        for message in (
            "SCRIPT ERROR: Parse Error: Expected expression.",
            "SCRIPT ERROR: Invalid call to a nonexistent function.",
            'ERROR: Failed to load script "res://broken.gd" with error "Parse error".',
            "ERROR: Failed to create an autoload, script does not inherit from Node.",
            "\x1b[31mSCRIPT ERROR:\x1b[0m Compile Error: unresolved preload.",
        ):
            with self.subTest(message=message):
                output = message + "\n" + "later output\n" * 500
                process = validation.subprocess.CompletedProcess(check.command, 0, stdout=output)
                with mock.patch.object(validation.subprocess, "run", return_value=process), contextlib.redirect_stdout(io.StringIO()):
                    result = validation.run_check(check, ROOT)
                self.assertEqual("error", result["status"])
                self.assertIsNone(result["return_code"])
                self.assertIn("GODOT_SCRIPT_FAILURE:", result["output_tail"])
                self.assertIn("process exit code 0;", result["output_tail"])
                self.assertLessEqual(len(result["output_tail"]), validation.OUTPUT_TAIL_LIMIT)

    def test_expected_application_errors_and_python_negative_tests_do_not_fail(self) -> None:
        for command, output in (
            (validation.godot_command(Path("godot"), ROOT), "ERROR: Fixture rejects a bad input.\nTests passed."),
            ((sys.executable, "fixture.py"), "SCRIPT ERROR: Parse Error: captured negative test\nOK"),
        ):
            check = validation.Check("fixture", command, 30)
            process = validation.subprocess.CompletedProcess(command, 0, stdout=output)
            with mock.patch.object(validation.subprocess, "run", return_value=process), contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual("passed", validation.run_check(check, ROOT)["status"])

    def test_real_godot_autoload_parse_failure_is_not_a_pass(self) -> None:
        try:
            godot = validation.find_godot(None)
        except ValueError as error:
            self.skipTest(str(error))
        with tempfile.TemporaryDirectory() as directory:
            fixture = Path(directory)
            (fixture / "project.godot").write_text(
                'config_version=5\n[application]\nconfig/name="parse rejection fixture"\n'
                '[autoload]\nBroken="*res://invalid.gd"\n', encoding="utf-8",
            )
            (fixture / "invalid.gd").write_text("extends Node\nvar broken =\n", encoding="utf-8")
            check = validation.Check("invalid project", validation.godot_command(
                godot, fixture, "--editor", "--quit-after", "2"), 30)
            with contextlib.redirect_stdout(io.StringIO()):
                result = validation.run_check(check, fixture)
            self.assertIn(result["status"], ("failed", "error"))
            self.assertIn("GODOT_SCRIPT_FAILURE:", result["output_tail"])

    def test_failure_output_is_bounded_and_success_output_is_not_saved(self) -> None:
        check = validation.Check("fixture", ("synthetic",), 1)
        output = "prefix" + "x" * 5000 + " meaningful failure"
        with mock.patch.object(validation.subprocess, "run", return_value=validation.subprocess.CompletedProcess(check.command, 1, stdout=output)):
            with contextlib.redirect_stdout(io.StringIO()):
                result = validation.run_check(check, ROOT)
        self.assertEqual(output[-4096:], result["output_tail"])
        with mock.patch.object(validation.subprocess, "run", return_value=validation.subprocess.CompletedProcess(check.command, 0, stdout="passed")):
            with contextlib.redirect_stdout(io.StringIO()):
                self.assertNotIn("output_tail", validation.run_check(check, ROOT))

    def test_launch_error_and_byte_timeout_output_remain_actionable(self) -> None:
        check = validation.Check("fixture", ("missing",), 3)
        for error, status, message in (
            (OSError("fixture launch denied"), "error", "fixture launch denied"),
            (validation.subprocess.TimeoutExpired(check.command, 3, output=b"partial output\xff"), "timeout", "partial output"),
        ):
            with self.subTest(status=status), mock.patch.object(validation.subprocess, "run", side_effect=error):
                with contextlib.redirect_stdout(io.StringIO()):
                    result = validation.run_check(check, ROOT)
            self.assertEqual(status, result["status"])
            self.assertIsNone(result["return_code"])
            self.assertIn(message, result["output_tail"])
            if status == "timeout":
                self.assertIn("TIMEOUT after 3s", result["output_tail"])

    def test_coverage_matches_the_plan_for_source_and_executable_combinations(self) -> None:
        # The groups `native_corpus` and `voice_payload` are filled only by native audits
        # (absent from the public source snapshot); their assertions need a member's script.
        native_corpus_audits = has_native_audit("original EVENTB03 camera and AX boundary contract")
        voice_audit = has_native_audit("original executable native Ogg voice contract")
        with tempfile.TemporaryDirectory() as directory:
            source_root = Path(directory) / "ELFIMAGE"
            source_root.mkdir()
            for archive in ("mes.arc", "mmo.arc", "data.arc"):
                (source_root / archive).write_bytes(b"fixture")
            executable = Path(directory) / "AI5WIN.exe"
            executable.write_bytes(b"fixture")
            for with_source in (False, True):
                for with_executable in (False, True):
                    for skip_event in (False, True):
                        args = argparse.Namespace(elfimage=source_root if with_source else None,
                                                  exe=executable if with_executable else None,
                                                  skip_event_corpus=skip_event)
                        with self.subTest(source=with_source, exe=with_executable, skip_event=skip_event):
                            checks = validation.build_checks(args, ROOT, Path("godot"))
                            coverage = {row["id"]: row for row in validation.build_coverage(args, "full", checks, checks, checks)}
                            for group_id, row in coverage.items():
                                self.assertEqual(sum(group_id in check.groups for check in checks), row["check_count"])
                                self.assertEqual("included" if row["check_count"] else "not_run", row["status"])
                            self.assertEqual(with_source, coverage["original_corpus"]["status"] == "included")
                            self.assertEqual(with_source and not skip_event, coverage["event_corpus"]["status"] == "included")
                            self.assertEqual(with_executable, coverage["native_executable"]["status"] == "included")
                            if native_corpus_audits:
                                self.assertEqual(with_source and with_executable, coverage["native_corpus"]["status"] == "included")
                            self.assertEqual("not_run", coverage["voice_payload"]["status"])
                            if with_source and with_executable and voice_audit:
                                self.assertIn("voice.arc is missing", coverage["voice_payload"]["reason"])
                            if with_source and with_executable and native_corpus_audits:
                                self.assertIn("se.arc is missing", coverage["native_corpus"]["reason"])
            for archive in ("voice.arc", "se.arc"):
                (source_root / archive).write_bytes(b"fixture")
            args = argparse.Namespace(elfimage=source_root, exe=executable, skip_event_corpus=False)
            checks = validation.build_checks(args, ROOT, Path("godot"))
            coverage = {row["id"]: row for row in validation.build_coverage(args, "full", checks, checks, checks)}
            if voice_audit:
                self.assertEqual(1, coverage["voice_payload"]["check_count"])
            if native_corpus_audits:
                self.assertNotIn("missing", coverage["native_corpus"]["reason"])

    def test_focused_selection_preserves_plan_order_and_reports_filtered_groups(self) -> None:
        checks = [validation.Check("one", (), 1), validation.Check("two", (), 1),
                  validation.Check("original", (), 1, ("original_corpus", "event_corpus"))]
        selected = validation.select_checks(checks, ["two", "one", "two"])
        self.assertEqual(["one", "two"], [check.name for check in selected])
        with self.assertRaisesRegex(ValueError, "Unknown or unavailable"):
            validation.select_checks(checks, ["wrong"])
        args = argparse.Namespace(elfimage=Path("fixture"), exe=None, skip_event_corpus=False)
        coverage = {row["id"]: row for row in validation.build_coverage(args, "full", checks, checks, selected)}
        self.assertEqual(2, coverage["synthetic"]["check_count"])
        self.assertEqual("not_run", coverage["original_corpus"]["status"])
        self.assertIn("filtered out by --check", coverage["original_corpus"]["reason"])
        coverage = {row["id"]: row for row in validation.build_coverage(args, "full", checks, checks, selected[:1])}
        self.assertIn("1 check(s) filtered out", coverage["synthetic"]["reason"])

    def test_main_tier_local_with_elfimage_excludes_original_corpus_by_tier(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            report_path = Path(directory) / "tier-local.json"
            source_root = Path(directory) / "ELFIMAGE"
            source_root.mkdir()
            for archive in ("mes.arc", "mmo.arc", "data.arc"):
                (source_root / archive).write_bytes(b"fixture")
            run_id = "5c7c6f1c-8f0e-4c1b-9a2a-2f6a2b1d9a10"

            def fake_run_check(check: validation.Check, project: Path) -> dict[str, object]:
                return {"name": check.name, "status": "passed", "return_code": 0, "duration_seconds": 0.001}

            with mock.patch.object(sys, "argv", [
                "validation", "--elfimage", str(source_root), "--tier", "local",
                "--report", str(report_path), "--run-id", run_id,
                # This test plans real checks through the real `build_checks()`
                # (only `run_check` is faked), so TD-32 part 3b's own
                # fingerprinting/storing runs for real too; an explicit,
                # isolated `--cache-dir` keeps it out of the repository's own
                # `analysis/validation_cache` (the default).
                "--cache-dir", str(Path(directory) / "cache"),
            ]):
                with mock.patch.object(validation, "find_godot", return_value=Path("godot")):
                    with mock.patch.object(validation, "run_check", side_effect=fake_run_check):
                        with contextlib.redirect_stdout(io.StringIO()):
                            exit_code = validation.main()
            self.assertEqual(0, exit_code)
            report = json.loads(json.loads(report_path.read_text(encoding="utf-8"))["payload_json"])
            self.assertFalse(report["original_corpus"])
            self.assertFalse(report["native_executable_audit"])
            self.assertEqual("local", report["context"]["tier"])
            coverage = {row["id"]: row for row in report["coverage"]}
            # WD-25 item 1b: the corpus checks are excluded by the tier, but the local-tier Python
            # suite reads the archives (the archive-literal guard) and so carries the group: it is
            # the one `original_corpus` check this run plans, and the coverage row says so.
            self.assertEqual("included", coverage["original_corpus"]["status"])
            self.assertEqual(1, coverage["original_corpus"]["check_count"])
            self.assertEqual("Included 1 check(s) in this run.", coverage["original_corpus"]["reason"])

    def test_analysis_group_all_selection_without_elfimage_is_a_configuration_error(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            report_path = Path(directory) / "no-elfimage.json"
            with mock.patch.object(sys, "argv", [
                "validation", "--check", "original event analysis groups", "--report", str(report_path),
            ]):
                with mock.patch.object(validation, "find_godot", return_value=Path("godot")):
                    with mock.patch.object(validation, "run_check") as run_check, \
                            contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
                        exit_code = validation.main()
            run_check.assert_not_called()
            self.assertEqual(2, exit_code)
            report = json.loads(json.loads(report_path.read_text(encoding="utf-8"))["payload_json"])
            self.assertEqual("configuration_error", report["status"])
            self.assertIn(
                "no analysis-group check is planned in this run (requires --elfimage)",
                report["configuration_error"],
            )

    def test_analysis_group_all_selection_excluded_by_tier_is_a_configuration_error(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            report_path = Path(directory) / "tier-excluded.json"
            source_root = Path(directory) / "ELFIMAGE"
            source_root.mkdir()
            for archive in ("mes.arc", "mmo.arc", "data.arc"):
                (source_root / archive).write_bytes(b"fixture")
            with mock.patch.object(sys, "argv", [
                "validation", "--elfimage", str(source_root), "--tier", "local",
                "--check", "original event analysis groups", "--report", str(report_path),
            ]):
                with mock.patch.object(validation, "find_godot", return_value=Path("godot")):
                    with mock.patch.object(validation, "run_check") as run_check, \
                            contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
                        exit_code = validation.main()
            run_check.assert_not_called()
            self.assertEqual(2, exit_code)
            report = json.loads(json.loads(report_path.read_text(encoding="utf-8"))["payload_json"])
            self.assertEqual("configuration_error", report["status"])
            self.assertIn(
                "no analysis-group check is planned in this run (excluded by --tier local)",
                report["configuration_error"],
            )

    def test_configuration_failure_writes_a_report_without_running_checks(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            report_path = Path(directory) / "configuration.json"
            run_id = "ea6f7417-6aad-4d51-ac8e-474cf0a6d3cb"
            godot_path = Path(directory) / "godot.exe"
            godot_path.write_bytes(b"not executed")
            cases = (
                (["--godot", str(Path(directory) / "absent.exe")], "Godot executable does not exist"),
                (["--python-jobs", "not-a-number"], "invalid int value"),
                (["--python-jobs", "0"], "jobs must be greater than zero"),
                (["--python-timeout", "0"], "timeout must be greater than zero"),
                (["--unknown-option"], "unrecognized arguments"),
                (["--check", "not a real check"], "Unknown or unavailable --check"),
                (["--elfimage", str(Path(directory) / "absent_source")], "ELFIMAGE directory does not exist"),
                (["--exe", str(Path(directory) / "absent_game.exe")], "Original executable does not exist"),
            )
            for options, expected_error in cases:
                with self.subTest(options=options), mock.patch.object(sys, "argv", ["validation", "--godot", str(godot_path), *options, "--report", str(report_path), "--run-id", run_id]):
                    with mock.patch.object(validation, "run_check") as run_check, contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
                        result = validation.main()
                    run_check.assert_not_called()
                    self.assertEqual(2, result)
                    envelope = json.loads(report_path.read_text(encoding="utf-8"))
                    report = json.loads(envelope["payload_json"])
                    self.assertEqual("configuration_error", report["status"])
                    self.assertEqual(run_id, report["run_id"])
                    self.assertEqual([], report["checks"])
                    self.assertTrue(report["configuration_error"])
                    self.assertIn(expected_error, report["configuration_error"])
                    self.assertTrue(all(row["status"] == "not_run" and row["check_count"] == 0 for row in report["coverage"]))

    def test_main_runs_only_selected_checks_and_prints_the_unwrapped_summary(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            report_path = Path(directory) / "focused.json"
            run_id = "dd07e587-f2b6-438c-b528-4c1735f7a7da"
            checks = [validation.Check("first", (), 1), validation.Check("second", (), 1)]
            output = io.StringIO()
            with mock.patch.object(sys, "argv", ["validation", "--report", str(report_path), "--run-id", run_id, "--check", "second"]):
                with mock.patch.object(validation, "find_godot", return_value=Path("godot")), mock.patch.object(validation, "build_checks", return_value=checks):
                    with mock.patch.object(validation, "run_check", return_value={"name": "second", "status": "passed", "return_code": 0, "duration_seconds": 0.1}) as run_check:
                        with contextlib.redirect_stdout(output):
                            self.assertEqual(0, validation.main())
            run_check.assert_called_once_with(checks[1], ROOT)
            report = json.loads(json.loads(report_path.read_text(encoding="utf-8"))["payload_json"])
            self.assertEqual(run_id, report["run_id"])
            self.assertEqual(1, report["check_count"])
            self.assertEqual("not_performed", report["context"]["workspace_validation"])
            self.assertIn('"schema": "kakyu_content_tools_validation/v6"', output.getvalue())
            self.assertNotIn('"payload_json"', output.getvalue())

    def test_main_writes_one_report_row_per_shard_when_its_base_name_is_selected(self) -> None:
        # TD-33 part 2: `--check "<a sharded entry's own name>"` runs every
        # one of its planned shards, and the report keeps one row per shard
        # (like an ordinary check, never collapsed the way a process
        # family's members are).
        with tempfile.TemporaryDirectory() as directory:
            report_path = Path(directory) / "sharded.json"
            checks = [
                validation.Check("sharded check [1/3]", (), 1, registry_name="sharded check"),
                validation.Check("sharded check [2/3]", (), 1, registry_name="sharded check"),
                validation.Check("sharded check [3/3]", (), 1, registry_name="sharded check"),
                validation.Check("other check", (), 1, registry_name="other check"),
            ]

            def fake_run_check(check: validation.Check, project: Path) -> dict[str, object]:
                return {"name": check.name, "status": "passed", "return_code": 0, "duration_seconds": 0.001}

            with mock.patch.object(sys, "argv", ["validation", "--report", str(report_path), "--check", "sharded check"]):
                with mock.patch.object(validation, "find_godot", return_value=Path("godot")), \
                        mock.patch.object(validation, "build_checks", return_value=checks):
                    with mock.patch.object(validation, "run_check", side_effect=fake_run_check), \
                            contextlib.redirect_stdout(io.StringIO()):
                        self.assertEqual(0, validation.main())
            report = json.loads(json.loads(report_path.read_text(encoding="utf-8"))["payload_json"])
            self.assertEqual(3, report["check_count"])
            self.assertEqual(3, report["passed"])
            self.assertEqual(
                ["sharded check [1/3]", "sharded check [2/3]", "sharded check [3/3]"],
                [check["name"] for check in report["checks"]],
            )

    def test_main_persists_zero_exit_script_failure_as_a_v3_error(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            report_path = Path(directory) / "script-error.json"
            check = validation.Check("script fixture", validation.godot_command(Path("godot"), ROOT), 30)
            child = validation.subprocess.CompletedProcess(check.command, 0, stdout="SCRIPT ERROR: fixture failure")
            with mock.patch.object(sys, "argv", ["validation", "--report", str(report_path)]):
                with mock.patch.object(validation, "find_godot", return_value=Path("godot")), mock.patch.object(validation, "build_checks", return_value=[check]):
                    with mock.patch.object(validation.subprocess, "run", return_value=child), contextlib.redirect_stdout(io.StringIO()):
                        self.assertEqual(1, validation.main())
            envelope = json.loads(report_path.read_text(encoding="utf-8"))
            report = json.loads(envelope["payload_json"])
            self.assertEqual("failed", report["status"])
            self.assertEqual("error", report["checks"][0]["status"])
            self.assertIsNone(report["checks"][0]["return_code"])
            self.assertIn("process exit code 0;", report["checks"][0]["output_tail"])
            self.assertEqual(1, report["failed"])

    def test_main_persists_failed_check_diagnostics_and_returns_failure(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            report_path = Path(directory) / "failed.json"
            checks = [validation.Check("fixture", (), 1)]
            failure = {"name": "fixture", "status": "error", "return_code": None,
                       "duration_seconds": 0.01, "output_tail": "Could not launch check: fixture denied"}
            with mock.patch.object(sys, "argv", ["validation", "--report", str(report_path)]):
                with mock.patch.object(validation, "find_godot", return_value=Path("godot")), mock.patch.object(validation, "build_checks", return_value=checks):
                    with mock.patch.object(validation, "run_check", return_value=failure), contextlib.redirect_stdout(io.StringIO()):
                        self.assertEqual(1, validation.main())
            report = json.loads(json.loads(report_path.read_text(encoding="utf-8"))["payload_json"])
            self.assertEqual("failed", report["status"])
            self.assertEqual((1, 0, 1), (report["check_count"], report["passed"], report["failed"]))
            self.assertEqual(failure, report["checks"][0])

    def test_main_with_jobs_reports_a_worker_exception_as_an_error_and_returns_failure(self) -> None:
        # Coordinator review of TD-33: a worker-thread exception used to
        # kill its own thread silently - no result row, no printed block -
        # and a run missing one check's row could still exit 0. `main()`
        # itself always resolves `project` to this repository's own root
        # (not a fixture directory), so `--jobs 2` here creates a real
        # `analysis/validation_workers/<run-id>` scratch directory; cleaned
        # up explicitly since a red run does not self-clean (by design).
        run_id = "6a15a3f2-6f8e-4b8b-9c0a-7a6a2f6a9b31"
        worker_root = ROOT / "analysis" / "validation_workers" / run_id
        self.addCleanup(shutil.rmtree, worker_root, True)
        with tempfile.TemporaryDirectory() as directory:
            report_path = Path(directory) / "worker-exception.json"
            checks = [
                validation.Check("boom", (), 1, ("synthetic",), "local", "boom"),
                validation.Check("ok", (), 1, ("synthetic",), "local", "ok"),
            ]

            def fake_run_check(check, project, env=None):
                if check.name == "boom":
                    raise RuntimeError("kaboom")
                return {"name": "ok", "status": "passed", "return_code": 0, "duration_seconds": 0.01}

            argv = ["validation", "--report", str(report_path), "--run-id", run_id, "--jobs", "2"]
            with mock.patch.object(sys, "argv", argv):
                with mock.patch.object(validation, "find_godot", return_value=Path("godot")), \
                     mock.patch.object(validation, "build_checks", return_value=checks):
                    with mock.patch.object(validation, "run_check", side_effect=fake_run_check), \
                         contextlib.redirect_stdout(io.StringIO()):
                        self.assertEqual(1, validation.main())
            report = json.loads(json.loads(report_path.read_text(encoding="utf-8"))["payload_json"])
            self.assertEqual("failed", report["status"])
            by_name = {row["name"]: row for row in report["checks"]}
            self.assertEqual(2, report["check_count"])
            self.assertEqual("error", by_name["boom"]["status"])
            self.assertIsNone(by_name["boom"]["return_code"])
            self.assertIn("kaboom", by_name["boom"]["output_tail"])
            self.assertEqual("passed", by_name["ok"]["status"])

    def test_fingerprints_lists_every_planned_check_exactly_once_and_runs_nothing(self) -> None:
        arguments = argparse.Namespace(elfimage=None, exe=None, skip_event_corpus=False, tier="local")
        expected_names = [check.name for check in validation.build_checks(arguments, ROOT, Path("godot"))]
        output = io.StringIO()
        with mock.patch.object(sys, "argv", ["validation", "--tier", "local", "--fingerprints"]):
            with mock.patch.object(validation, "find_godot", return_value=Path("godot")):
                with mock.patch.object(validation.subprocess, "run") as run:
                    with contextlib.redirect_stdout(output):
                        exit_code = validation.main()
        run.assert_not_called()
        self.assertEqual(0, exit_code)
        lines = [line for line in output.getvalue().splitlines() if line.strip()]
        summary_lines = [line for line in lines if line.startswith("Fingerprinted ")]
        self.assertEqual(1, len(summary_lines))
        check_lines = [line for line in lines if line not in summary_lines]
        printed_names = [line.split("\t")[-1] for line in check_lines]
        self.assertEqual(sorted(expected_names), sorted(printed_names))
        self.assertEqual(len(expected_names), len(set(printed_names)))
        for line in check_lines:
            digest, file_count, unresolved_count, dynamic_flag, _name = line.split("\t")
            self.assertEqual(64, len(digest))
            self.assertTrue(file_count.isdigit())
            self.assertTrue(unresolved_count.isdigit())
            self.assertIn(dynamic_flag, ("yes", "no"))

    def test_fingerprint_inputs_prints_one_checks_sorted_inputs_and_exits(self) -> None:
        output = io.StringIO()
        with mock.patch.object(sys, "argv", [
            "validation", "--tier", "local", "--fingerprint-inputs", "Godot project parse check",
        ]):
            with mock.patch.object(validation, "find_godot", return_value=Path("godot")):
                with mock.patch.object(validation.subprocess, "run") as run:
                    with contextlib.redirect_stdout(output):
                        exit_code = validation.main()
        run.assert_not_called()
        self.assertEqual(0, exit_code)
        self.assertIn("project.godot", output.getvalue())
        self.assertIn("UNRESOLVED:", output.getvalue())

    def test_fingerprints_operates_on_the_check_selection_not_every_planned_check(self) -> None:
        """TD-32 part 3c, section 2(c): `--fingerprints` with `--check` prints
        only the selected check(s), not every planned one."""
        output = io.StringIO()
        with mock.patch.object(sys, "argv", [
            "validation", "--tier", "local", "--check", "Godot project parse check", "--fingerprints",
        ]):
            with mock.patch.object(validation, "find_godot", return_value=Path("godot")):
                with mock.patch.object(validation.subprocess, "run") as run:
                    with contextlib.redirect_stdout(output):
                        exit_code = validation.main()
        run.assert_not_called()
        self.assertEqual(0, exit_code)
        lines = [line for line in output.getvalue().splitlines() if line.strip()]
        check_lines = [line for line in lines if not line.startswith("Fingerprinted ")]
        printed_names = [line.split("\t")[-1] for line in check_lines]
        self.assertEqual(["Godot project parse check"], printed_names)

    def test_fingerprint_inputs_for_a_name_outside_the_check_selection_uses_the_check_error(self) -> None:
        """TD-32 part 3c, section 2(c): `--fingerprint-inputs` for a name
        `--check` already excluded from this run's selection fails through
        the very same `select_checks()` call (and so the identical message)
        an unknown/excluded `--check` name itself would raise."""
        arguments = argparse.Namespace(elfimage=None, exe=None, skip_event_corpus=False, tier="local")
        registry = validation.load_validation_registry()
        available = validation._availability(arguments)
        planned = validation.build_checks(arguments, ROOT, Path("godot"))
        selected = validation.select_checks(
            planned, ["Godot project parse check"], registry=registry, tier="local", available=available,
        )
        try:
            validation.select_checks(
                selected, ["python regression suite"], registry=registry, tier="local", available=available,
            )
            self.fail("expected python regression suite to be outside the narrowed selection")
        except ValueError as error:
            expected_message = str(error)

        error_stream = io.StringIO()
        with mock.patch.object(sys, "argv", [
            "validation", "--tier", "local", "--check", "Godot project parse check",
            "--fingerprint-inputs", "python regression suite",
        ]):
            with mock.patch.object(validation, "find_godot", return_value=Path("godot")):
                with mock.patch.object(validation.subprocess, "run") as run:
                    with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(error_stream):
                        exit_code = validation.main()
        run.assert_not_called()
        self.assertEqual(2, exit_code)
        self.assertIn(f"VALIDATION_CONFIGURATION_ERROR: {expected_message}", error_stream.getvalue())

    def test_fingerprint_context_is_computed_once_inside_the_guarded_configuration_block(self) -> None:
        """TD-32 part 3c, section 2(d): `_fingerprint_context()` runs exactly
        once, inside `main()`'s own configuration `try` - never again after
        it - so a source that goes missing between planning and fingerprint
        computation fails closed as a configuration error, not an unhandled
        traceback raised from outside any guard."""
        calls: list[int] = []
        real_fingerprint_context = validation._fingerprint_context

        def counting(*args, **kwargs):
            calls.append(1)
            return real_fingerprint_context(*args, **kwargs)

        with mock.patch.object(sys, "argv", ["validation", "--tier", "local", "--fingerprints"]):
            with mock.patch.object(validation, "find_godot", return_value=Path("godot")), \
                 mock.patch.object(validation, "_fingerprint_context", side_effect=counting), \
                 mock.patch.object(validation.subprocess, "run") as run, \
                 contextlib.redirect_stdout(io.StringIO()):
                exit_code = validation.main()
        run.assert_not_called()
        self.assertEqual(0, exit_code)
        self.assertEqual(1, len(calls))


_EIGHT_ARCHIVE_STEMS = ("mes", "mmo", "data", "voice", "se", "bgm", "tina1", "tina2")


class ArchiveInputFingerprintTests(_KeepCheckoutClean, unittest.TestCase):
    """TD-53: the placeholder context carries every original archive a
    `{source_root}` check can read, so the cache fingerprints all eight."""

    def _elfimage(self, stems: tuple[str, ...] = _EIGHT_ARCHIVE_STEMS) -> tuple[Path, Path]:
        directory = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, directory, True)
        source_root = directory / "ELFIMAGE"
        source_root.mkdir()
        for stem in stems:
            (source_root / f"{stem}.arc").write_bytes(b"fixture-" + stem.encode())
        executable = directory / "AI5WIN.exe"
        executable.write_bytes(b"fixture")
        return source_root, executable

    def _arguments(self, source_root: Path, executable: Path) -> argparse.Namespace:
        return argparse.Namespace(elfimage=source_root, exe=executable, skip_event_corpus=False)

    def test_placeholder_context_carries_every_archive_the_inputs_library_names(self) -> None:
        source_root, executable = self._elfimage()
        context, _available = validation._registry_placeholder_context(
            arguments=self._arguments(source_root, executable), project=ROOT, godot=Path("godot"),
            python_jobs=1, python_timeout=100,
        )
        archive_names = {name for name in context if name.endswith("_arc")}
        self.assertEqual(set(validation_inputs._ARCHIVE_CONTEXT_NAMES), archive_names)
        for stem in _EIGHT_ARCHIVE_STEMS:
            self.assertEqual(str(source_root.resolve() / f"{stem}.arc"), context[f"{stem}_arc"])

    def test_the_three_media_archives_are_context_only_and_never_required(self) -> None:
        """A root without `bgm.arc`, `tina1.arc` or `tina2.arc` still plans
        every check (`voice.arc`/`se.arc` behave the same way); the three names
        are not registry placeholders, so no command can require them."""
        source_root, executable = self._elfimage(("mes", "mmo", "data"))
        arguments = self._arguments(source_root, executable)
        context, available = validation._registry_placeholder_context(
            arguments=arguments, project=ROOT, godot=Path("godot"), python_jobs=1, python_timeout=100,
        )
        for name in ("bgm_arc", "tina1_arc", "tina2_arc"):
            self.assertIn(name, context)
            self.assertNotIn(name, validation.KNOWN_CHECK_PLACEHOLDERS)
            self.assertNotIn(name, available)
        self.assertTrue(validation.build_checks(arguments, ROOT, Path("godot")))

    def test_source_root_checks_list_all_eight_archives_and_a_change_moves_the_fingerprint(self) -> None:
        source_root, executable = self._elfimage()
        arguments = self._arguments(source_root, executable)
        context = validation._fingerprint_context(arguments, ROOT, Path("godot"))
        planned = {check.name: check for check in validation.build_checks(arguments, ROOT, Path("godot"))}
        core_version = validation_inputs.read_core_version(ROOT)
        expected = sorted(f"{stem}_arc" for stem in _EIGHT_ARCHIVE_STEMS)
        for name in ("original playback package export", "original catalog group routes [1/20]"):
            check = planned[name]
            self.assertIn(context["source_root"], check.command)
            inputs = validation_inputs.check_inputs(check, ROOT, context)
            with self.subTest(check=name):
                self.assertEqual(expected, list(inputs.external))
                command_text = validation_inputs.normalize_command(check.command, context)
                baseline = validation_inputs.fingerprint(inputs, core_version, command_text)
                for stem in ("bgm", "tina1", "tina2"):
                    path = source_root / f"{stem}.arc"
                    original = path.read_bytes()
                    path.write_bytes(original + b"!")
                    try:
                        changed = validation_inputs.fingerprint(inputs, core_version, command_text)
                    finally:
                        path.write_bytes(original)
                    self.assertNotEqual(baseline, changed, f"{stem}.arc change did not move the fingerprint")

    def test_fingerprint_inputs_query_lists_the_media_archives_and_omits_an_absent_one(self) -> None:
        def inputs_query(source_root: Path, executable: Path) -> list[str]:
            output = io.StringIO()
            argv = [
                "validation", "--elfimage", str(source_root), "--exe", str(executable),
                "--fingerprint-inputs", "original playback package export",
            ]
            with mock.patch.object(sys, "argv", argv):
                with mock.patch.object(validation, "find_godot", return_value=Path("godot")):
                    with mock.patch.object(validation.subprocess, "run") as run:
                        with contextlib.redirect_stdout(output):
                            exit_code = validation.main()
            run.assert_not_called()
            self.assertEqual(0, exit_code)
            return [line for line in output.getvalue().splitlines() if line.endswith("_arc")]

        source_root, executable = self._elfimage()
        self.assertEqual(sorted(f"{stem}_arc" for stem in _EIGHT_ARCHIVE_STEMS), inputs_query(source_root, executable))
        (source_root / "tina2.arc").unlink()
        self.assertNotIn("tina2_arc", inputs_query(source_root, executable))


_ANALYSIS_GROUP_FAMILIES = {
    "analysis_group": {
        "check": "original event analysis groups",
        "script": "res://tools/content_suite/validators/validate_event_analysis_groups.gd",
        "process_timeout": 3600, "groups": ["original_corpus"], "tier": "full",
    }
}


def _analysis_member(name: str, profile: str) -> "validation.Check":
    command = (
        "godot", "--headless", "--path", "/project", "--script",
        "res://tools/content_suite/validators/validate_event_analysis_group.gd",
        "--", "/elfimage", profile,
    )
    return validation.Check(name, command, 300, ("original_corpus",), "full", name,
                             family="analysis_group", profile=profile,
                             godot="godot", project="/project", source_root="/elfimage",
                             kind="godot_script", requires=("elfimage",))


class CollapseFamiliesTests(unittest.TestCase):
    def test_collapse_replaces_every_member_with_one_process_check_at_the_first_position(self) -> None:
        members = [_analysis_member(f"member {i}", f"config/event_catalog/analysis_groups/m{i}.json") for i in range(3)]
        checks = [validation.Check("before", (), 1), members[0], members[1], validation.Check("between", (), 1), members[2]]
        collapsed = validation.collapse_families(checks, _ANALYSIS_GROUP_FAMILIES)
        self.assertEqual(["before", "original event analysis groups", "between"], [c.name for c in collapsed])
        process_check = collapsed[1]
        self.assertEqual(tuple(members), process_check.members)
        self.assertEqual(3600, process_check.timeout)
        self.assertEqual(("original_corpus",), process_check.groups)
        self.assertEqual("full", process_check.tier)
        self.assertEqual(
            ("godot", "--headless", "--path", "/project", "--script",
             "res://tools/content_suite/validators/validate_event_analysis_groups.gd",
             "--", "/elfimage", *[m.profile for m in members]),
            process_check.command,
        )

    def test_collapse_leaves_a_selection_with_no_member_unchanged(self) -> None:
        checks = [validation.Check("one", (), 1), validation.Check("two", (), 1)]
        self.assertEqual(checks, validation.collapse_families(checks, _ANALYSIS_GROUP_FAMILIES))

    def test_collapse_still_builds_a_one_profile_process_for_a_single_member(self) -> None:
        member = _analysis_member("solo", "config/event_catalog/analysis_groups/solo.json")
        collapsed = validation.collapse_families([member], _ANALYSIS_GROUP_FAMILIES)
        self.assertEqual(1, len(collapsed))
        self.assertEqual((member,), collapsed[0].members)
        self.assertEqual("original event analysis groups", collapsed[0].name)


_SHARDED_FAMILIES = {
    "analysis_group": {**_ANALYSIS_GROUP_FAMILIES["analysis_group"], "process_shards": 2},
}


def _numbered_members(count: int) -> list["validation.Check"]:
    return [_analysis_member(f"member {i}", f"config/event_catalog/analysis_groups/m{i}.json") for i in range(count)]


def _shard_member_names(shards: list["validation.Check"]) -> list[tuple[str, ...]]:
    return [tuple(member.name for member in shard.members) for shard in shards]


class ProcessShardPartitionTests(unittest.TestCase):
    """TD-58 D1-D3: `collapse_families()` splits the selected members across
    up to `process_shards` process checks by LPT on the recorded durations."""

    def test_lpt_balances_the_shards_and_is_deterministic(self) -> None:
        members = _numbered_members(8)
        durations = {f"member {i}": float(10 - i) for i in range(8)}  # 10, 9, ... 3
        first = validation.collapse_families(members, _SHARDED_FAMILIES, jobs=6, durations=durations)
        second = validation.collapse_families(list(members), _SHARDED_FAMILIES, jobs=6, durations=dict(durations))
        self.assertEqual(first, second)
        self.assertEqual(
            [("member 0", "member 3", "member 4", "member 7"), ("member 1", "member 2", "member 5", "member 6")],
            _shard_member_names(first),
        )
        seconds = [sum(durations[member.name] for member in shard.members) for shard in first]
        self.assertEqual([26.0, 26.0], seconds)

    def test_lpt_puts_the_heaviest_member_alone_against_the_rest(self) -> None:
        # The heaviest member is last in registry order: only the duration sort puts it first.
        members = _numbered_members(4)
        durations = {"member 0": 1.0, "member 1": 1.0, "member 2": 1.0, "member 3": 10.0}
        shards = validation.collapse_families(members, _SHARDED_FAMILIES, jobs=6, durations=durations)
        self.assertEqual([("member 3",), ("member 0", "member 1", "member 2")], _shard_member_names(shards))

    def test_each_shard_lists_its_members_in_registry_order_and_every_member_once(self) -> None:
        members = _numbered_members(9)
        durations = {member.name: float(index * 7 % 5) + 0.5 for index, member in enumerate(members)}
        shards = validation.collapse_families(members, _SHARDED_FAMILIES, jobs=6, durations=durations)
        registry_position = {member.name: index for index, member in enumerate(members)}
        for shard in shards:
            positions = [registry_position[member.name] for member in shard.members]
            self.assertEqual(sorted(positions), positions)
        self.assertEqual(
            [member.name for member in members],
            sorted((member.name for shard in shards for member in shard.members), key=registry_position.get),
        )

    def test_with_no_durations_the_shards_differ_by_at_most_one_member_and_none_is_empty(self) -> None:
        families = {"analysis_group": {**_SHARDED_FAMILIES["analysis_group"], "process_shards": 3}}
        for count in (3, 4, 7, 8, 9):
            with self.subTest(members=count):
                members = _numbered_members(count)
                for durations in (None, {}):
                    shards = validation.collapse_families(members, families, jobs=6, durations=durations)
                    sizes = [len(shard.members) for shard in shards]
                    self.assertEqual(3, len(shards))
                    self.assertGreaterEqual(min(sizes), 1)
                    self.assertLessEqual(max(sizes) - min(sizes), 1)
                    self.assertEqual(count, sum(sizes))

    def test_unknown_durations_keep_registry_order_and_count_as_unknown_in_the_plan(self) -> None:
        members = _numbered_members(4)
        shards = validation.collapse_families(members, _SHARDED_FAMILIES, jobs=6, durations={"member 2": 5.0})
        # The one known member seeds shard 1; the unknown ones, in registry order, all
        # land on the shard with the fewest known seconds.
        self.assertEqual([("member 2",), ("member 0", "member 1", "member 3")], _shard_member_names(shards))
        self.assertEqual("shard plan: 1/2, 1 member(s), 5.000s known, 0 unknown", shards[0].shard_plan)
        self.assertEqual("shard plan: 2/2, 3 member(s), 0.000s known, 3 unknown", shards[1].shard_plan)

    def test_shards_are_named_and_planned_at_the_first_members_position(self) -> None:
        members = _numbered_members(3)
        checks = [validation.Check("before", (), 1), members[0], members[1], validation.Check("between", (), 1), members[2]]
        durations = {"member 0": 3.0, "member 1": 2.0, "member 2": 1.0}
        collapsed = validation.collapse_families(checks, _SHARDED_FAMILIES, jobs=6, durations=durations)
        self.assertEqual(
            ["before", "original event analysis groups [1/2]", "original event analysis groups [2/2]", "between"],
            [check.name for check in collapsed],
        )
        self.assertEqual(
            "shard plan: 1/2, 1 member(s), 3.000s known, 0 unknown", collapsed[1].shard_plan,
        )
        self.assertEqual(
            "shard plan: 2/2, 2 member(s), 3.000s known, 0 unknown", collapsed[2].shard_plan,
        )

    def test_every_shard_carries_the_process_timeout_and_only_its_own_profiles(self) -> None:
        members = _numbered_members(5)
        durations = {member.name: float(5 - index) for index, member in enumerate(members)}
        shards = validation.collapse_families(members, _SHARDED_FAMILIES, jobs=6, durations=durations)
        seen_profiles: list[str] = []
        for shard in shards:
            self.assertEqual(3600, shard.timeout)
            self.assertEqual(("original_corpus",), shard.groups)
            self.assertEqual("full", shard.tier)
            self.assertIsNone(shard.registry_name)
            self.assertEqual("", shard.profile)
            self.assertEqual(
                ("godot", "--headless", "--path", "/project", "--script",
                 "res://tools/content_suite/validators/validate_event_analysis_groups.gd",
                 "--", "/elfimage", *[member.profile for member in shard.members]),
                shard.command,
            )
            seen_profiles.extend(member.profile for member in shard.members)
        self.assertEqual(sorted(member.profile for member in members), sorted(seen_profiles))

    def test_jobs_one_or_a_single_member_keeps_one_process_and_todays_name(self) -> None:
        members = _numbered_members(4)
        durations = {member.name: 1.0 for member in members}
        for label, selection, jobs in (
            ("jobs 1", members, 1), ("jobs default", members, None), ("one member", members[:1], 6),
        ):
            with self.subTest(label):
                keywords = {} if jobs is None else {"jobs": jobs}
                collapsed = validation.collapse_families(selection, _SHARDED_FAMILIES, durations=durations, **keywords)
                self.assertEqual(1, len(collapsed))
                self.assertEqual("original event analysis groups", collapsed[0].name)
                self.assertEqual(tuple(selection), collapsed[0].members)
                self.assertEqual("", collapsed[0].shard_plan)

    def test_the_shard_count_is_capped_by_jobs_and_by_the_member_count(self) -> None:
        families = {"analysis_group": {**_SHARDED_FAMILIES["analysis_group"], "process_shards": 4}}
        cases = (
            (6, 2, ["original event analysis groups [1/2]", "original event analysis groups [2/2]"]),  # jobs
            (6, 3, [f"original event analysis groups [{k}/3]" for k in (1, 2, 3)]),  # member count
            (3, 6, [f"original event analysis groups [{k}/3]" for k in (1, 2, 3)]),  # jobs
            (6, 8, [f"original event analysis groups [{k}/4]" for k in (1, 2, 3, 4)]),  # process_shards
        )
        for jobs, member_count, expected_names in cases:
            with self.subTest(jobs=jobs, members=member_count):
                collapsed = validation.collapse_families(
                    _numbered_members(member_count), families, jobs=jobs, durations={},
                )
                self.assertEqual(expected_names, [check.name for check in collapsed])

    def test_a_family_without_process_shards_stays_one_process_at_any_jobs(self) -> None:
        collapsed = validation.collapse_families(
            _numbered_members(4), _ANALYSIS_GROUP_FAMILIES, jobs=6, durations={},
        )
        self.assertEqual(["original event analysis groups"], [check.name for check in collapsed])
        self.assertEqual("", collapsed[0].shard_plan)

    def test_shard_names_given_to_check_are_refused_naming_the_all_members_name(self) -> None:
        families = _SHARDED_FAMILIES
        for name in ("original event analysis groups [1/2]", "original event analysis groups [3/3]",
                     "original event analysis groups [x"):
            with self.subTest(name=name):
                with self.assertRaisesRegex(ValueError, r"process shard.*--check 'original event analysis groups'"):
                    validation._refuse_process_shard_names(["other", name], families)
        for name in ("original event analysis groups", "original event analysis groups x", "other"):
            with self.subTest(name=name):
                validation._refuse_process_shard_names([name], families)


def _groups_summary_output() -> str:
    passed_report = json.dumps({"ok": True, "schema": "fixture/v1"})
    failed_report = json.dumps({"ok": False, "schema": "fixture/v1"})
    summary = {
        "schema": "kakyu_event_analysis_groups_run/v1", "profiles": 3, "passed": 1, "failed": 1,
        "groups": [
            {"profile": "a.json", "status": "passed", "duration_seconds": 1.5, "checks": 10, "failures": []},
            {"profile": "b.json", "status": "failed", "duration_seconds": 2.25, "checks": 8, "failures": ["x"]},
        ],
    }
    return "\n".join([
        "=== GROUP a.json ===", passed_report, "--- GROUP PASSED (1.500s) ---",
        "=== GROUP b.json ===", failed_report, "--- GROUP FAILED (2.250s) ---",
        "GROUPS_SUMMARY " + json.dumps(summary),
    ]) + "\n"


class ProcessCheckMemberResultsTests(unittest.TestCase):
    def _members(self) -> list["validation.Check"]:
        return [
            _analysis_member("member a", "a.json"),
            _analysis_member("member b", "b.json"),
            _analysis_member("member c", "c.json"),
        ]

    def test_two_passed_one_failed_one_missing_from_the_summary(self) -> None:
        output = _groups_summary_output()
        members = self._members() + [_analysis_member("member d", "d.json")]
        process = validation.subprocess.CompletedProcess(("godot",), 1, stdout=output)
        printed = io.StringIO()
        with mock.patch.object(validation.subprocess, "run", return_value=process), contextlib.redirect_stdout(printed):
            check = validation.Check("original event analysis groups", ("godot",), 3600, members=tuple(members))
            results = validation.run_check(check, Path("."))
        self.assertEqual(4, len(results))
        # TD-51: one `process:` line, after the member lines, for the process itself.
        lines = printed.getvalue().splitlines()
        process_lines = [line for line in lines if line.startswith("process:")]
        self.assertEqual(1, len(process_lines))
        self.assertRegex(
            process_lines[0],
            r"^process: original event analysis groups completed in \d+\.\d{3}s \(4 member\(s\), timeout 3600s\)$",
        )
        self.assertEqual(len(lines) - 1, lines.index(process_lines[0]))
        self.assertEqual(4, sum(1 for line in lines if line.startswith("member:")))
        by_name = {result["name"]: result for result in results}
        self.assertEqual(("passed", 0, 1.5), (by_name["member a"]["status"], by_name["member a"]["return_code"], by_name["member a"]["duration_seconds"]))
        self.assertNotIn("output_tail", by_name["member a"])
        self.assertEqual(("failed", 1, 2.25), (by_name["member b"]["status"], by_name["member b"]["return_code"], by_name["member b"]["duration_seconds"]))
        self.assertIn("=== GROUP b.json ===", by_name["member b"]["output_tail"])
        self.assertIn("--- GROUP FAILED", by_name["member b"]["output_tail"])
        self.assertEqual(("error", None), (by_name["member c"]["status"], by_name["member c"]["return_code"]))
        self.assertEqual(("error", None), (by_name["member d"]["status"], by_name["member d"]["return_code"]))

    def test_process_timeout_marks_every_member_timeout(self) -> None:
        members = self._members()
        check = validation.Check("original event analysis groups", ("godot",), 3600, members=tuple(members))
        error = validation.subprocess.TimeoutExpired(check.command, 3600, output=b"partial\n")
        printed = io.StringIO()
        with mock.patch.object(validation.subprocess, "run", side_effect=error), contextlib.redirect_stdout(printed):
            results = validation.run_check(check, Path("."))
        self.assertEqual(3, len(results))
        for result in results:
            self.assertEqual("timeout", result["status"])
            self.assertIsNone(result["return_code"])
            self.assertIn("TIMEOUT after 3600s", result["output_tail"])
        # TD-51: a timed-out process still prints its own `process:` line (the one place its elapsed time shows).
        process_lines = [line for line in printed.getvalue().splitlines() if line.startswith("process:")]
        self.assertEqual(1, len(process_lines))
        self.assertRegex(
            process_lines[0],
            r"^process: original event analysis groups timeout in \d+\.\d{3}s \(3 member\(s\), timeout 3600s\)$",
        )

    def test_process_launch_error_marks_every_member_error_and_prints_the_process_line(self) -> None:
        members = self._members()
        check = validation.Check("original event analysis groups", ("godot",), 3600, members=tuple(members))
        printed = io.StringIO()
        with mock.patch.object(validation.subprocess, "run", side_effect=OSError("fixture")), contextlib.redirect_stdout(printed):
            results = validation.run_check(check, Path("."))
        self.assertEqual(3, len(results))
        for result in results:
            self.assertEqual("error", result["status"])
            self.assertIsNone(result["return_code"])
        process_lines = [line for line in printed.getvalue().splitlines() if line.startswith("process:")]
        self.assertEqual(1, len(process_lines))
        self.assertRegex(
            process_lines[0],
            r"^process: original event analysis groups error in \d+\.\d{3}s \(3 member\(s\), timeout 3600s\)$",
        )

    def test_script_error_inside_one_members_block_marks_only_that_member_error(self) -> None:
        summary = {
            "schema": "kakyu_event_analysis_groups_run/v1", "profiles": 3, "passed": 3, "failed": 0,
            "groups": [
                {"profile": "a.json", "status": "passed", "duration_seconds": 1.0, "checks": 5, "failures": []},
                {"profile": "b.json", "status": "passed", "duration_seconds": 1.0, "checks": 5, "failures": []},
                {"profile": "c.json", "status": "passed", "duration_seconds": 1.0, "checks": 5, "failures": []},
            ],
        }
        output = "\n".join([
            "=== GROUP a.json ===", '{"ok": true}', "--- GROUP PASSED (1.000s) ---",
            "=== GROUP b.json ===", "SCRIPT ERROR: Parse Error: fixture failure inside member b",
            "--- GROUP PASSED (1.000s) ---",
            "=== GROUP c.json ===", '{"ok": true}', "--- GROUP PASSED (1.000s) ---",
            "GROUPS_SUMMARY " + json.dumps(summary),
        ]) + "\n"
        members = self._members()
        process = validation.subprocess.CompletedProcess(("godot",), 0, stdout=output)
        check = validation.Check("original event analysis groups", ("godot",), 3600, members=tuple(members))
        with mock.patch.object(validation.subprocess, "run", return_value=process), contextlib.redirect_stdout(io.StringIO()):
            results = validation.run_check(check, Path("."))
        by_name = {result["name"]: result for result in results}
        self.assertEqual("passed", by_name["member a"]["status"])
        self.assertNotIn("output_tail", by_name["member a"])
        self.assertEqual("error", by_name["member b"]["status"])
        self.assertIsNone(by_name["member b"]["return_code"])
        self.assertIn("GODOT_SCRIPT_FAILURE:", by_name["member b"]["output_tail"])
        self.assertIn("=== GROUP b.json ===", by_name["member b"]["output_tail"])
        self.assertEqual("passed", by_name["member c"]["status"])
        self.assertNotIn("output_tail", by_name["member c"])

    def test_script_error_after_the_summary_is_trusted_against_complete_summary_rows(self) -> None:
        summary = {
            "schema": "kakyu_event_analysis_groups_run/v1", "profiles": 3, "passed": 2, "failed": 1,
            "groups": [
                {"profile": "a.json", "status": "passed", "duration_seconds": 1.0, "checks": 5, "failures": []},
                {"profile": "b.json", "status": "failed", "duration_seconds": 1.0, "checks": 5, "failures": ["x"]},
                {"profile": "c.json", "status": "passed", "duration_seconds": 1.0, "checks": 5, "failures": []},
            ],
        }
        output = "\n".join([
            "=== GROUP a.json ===", '{"ok": true}', "--- GROUP PASSED (1.000s) ---",
            "=== GROUP b.json ===", '{"ok": false}', "--- GROUP FAILED (1.000s) ---",
            "=== GROUP c.json ===", '{"ok": true}', "--- GROUP PASSED (1.000s) ---",
            "GROUPS_SUMMARY " + json.dumps(summary),
            "SCRIPT ERROR: Parse Error: fixture failure after the summary",
        ]) + "\n"
        members = self._members()
        process = validation.subprocess.CompletedProcess(("godot",), 0, stdout=output)
        check = validation.Check("original event analysis groups", ("godot",), 3600, members=tuple(members))
        with mock.patch.object(validation.subprocess, "run", return_value=process), contextlib.redirect_stdout(io.StringIO()):
            results = validation.run_check(check, Path("."))
        by_name = {result["name"]: result for result in results}
        self.assertEqual("passed", by_name["member a"]["status"])
        self.assertEqual("failed", by_name["member b"]["status"])
        self.assertEqual("passed", by_name["member c"]["status"])

    def test_script_error_line_marks_every_member_error(self) -> None:
        members = self._members()
        output = "SCRIPT ERROR: Parse Error: fixture failure\n"
        process = validation.subprocess.CompletedProcess(("godot",), 0, stdout=output)
        check = validation.Check("original event analysis groups", ("godot",), 3600, members=tuple(members))
        with mock.patch.object(validation.subprocess, "run", return_value=process), contextlib.redirect_stdout(io.StringIO()):
            results = validation.run_check(check, Path("."))
        self.assertEqual(3, len(results))
        for result in results:
            self.assertEqual("error", result["status"])
            self.assertIsNone(result["return_code"])
            self.assertIn("GODOT_SCRIPT_FAILURE:", result["output_tail"])


def _summary_output_for(command: tuple[str, ...], *, failed: tuple[str, ...] = ()) -> str:
    """The output a process check's `validate_event_analysis_groups.gd` would
    print for the profiles named in `command` (everything after the source
    root that follows `--`): a passed block per profile, a failed one for those
    in `failed`, and the `GROUPS_SUMMARY` line."""
    profiles = list(command[command.index("--") + 2:])
    lines: list[str] = []
    groups: list[dict] = []
    for profile in profiles:
        status = "failed" if profile in failed else "passed"
        lines += [f"=== GROUP {profile} ===", json.dumps({"ok": status == "passed"}), f"--- GROUP {status.upper()} (1.000s) ---"]
        groups.append({
            "profile": profile, "status": status, "duration_seconds": 1.0, "checks": 1,
            "failures": [] if status == "passed" else ["x"],
        })
    summary = {
        "schema": "kakyu_event_analysis_groups_run/v1", "profiles": len(profiles),
        "passed": len(profiles) - len(failed), "failed": len(failed), "groups": groups,
    }
    return "\n".join([*lines, "GROUPS_SUMMARY " + json.dumps(summary)]) + "\n"


class ProcessShardRunTests(unittest.TestCase):
    """TD-58 D5: each shard runs as its own process check - its own header,
    plan line, member lines, `process:` line and member rows - and a failure
    of one shard marks only that shard's members."""

    def _shards(self) -> list["validation.Check"]:
        members = _numbered_members(4)
        durations = {"member 0": 8.0, "member 1": 5.0, "member 2": 4.0, "member 3": 3.0}
        shards = validation.collapse_families(members, _SHARDED_FAMILIES, jobs=2, durations=durations)
        self.assertEqual(
            [("member 0", "member 3"), ("member 1", "member 2")], _shard_member_names(shards),
        )
        return shards

    def test_each_shard_prints_its_plan_and_process_lines_and_returns_only_its_members_rows(self) -> None:
        shards = self._shards()
        failing = "config/event_catalog/analysis_groups/m3.json"

        def fake_run(command, **keywords):
            return validation.subprocess.CompletedProcess(command, 0, stdout=_summary_output_for(command, failed=(failing,)))

        expected_plans = (
            "shard plan: 1/2, 2 member(s), 11.000s known, 0 unknown",
            "shard plan: 2/2, 2 member(s), 9.000s known, 0 unknown",
        )
        for shard, expected_plan in zip(shards, expected_plans):
            with self.subTest(shard=shard.name):
                printed = io.StringIO()
                with mock.patch.object(validation.subprocess, "run", side_effect=fake_run), contextlib.redirect_stdout(printed):
                    results = validation.run_check(shard, Path("."))
                self.assertEqual([member.name for member in shard.members], [row["name"] for row in results])
                self.assertEqual(
                    {"member 3": "failed"}.get(shard.members[-1].name, "passed"), results[-1]["status"],
                )
                lines = printed.getvalue().splitlines()
                header = lines.index(f"=== {shard.name} ===")
                self.assertEqual(expected_plan, lines[header + 1])
                member_lines = [line for line in lines if line.startswith("member:")]
                self.assertEqual(
                    [f"member: {row['name']} {row['status']} (1.000s)" for row in results], member_lines,
                )
                self.assertTrue(lines[-1].startswith(f"process: {shard.name} completed in "), lines[-1])
                self.assertTrue(lines[-1].endswith("(2 member(s), timeout 3600s)"), lines[-1])

    def test_a_timeout_or_launch_error_in_one_shard_marks_only_that_shards_members(self) -> None:
        shards = self._shards()
        failures = (
            ("timeout", validation.subprocess.TimeoutExpired(("godot",), 3600, output=b"partial\n")),
            ("error", OSError("fixture")),
        )
        for status, failure in failures:
            with self.subTest(status=status):
                def fake_run(command, **keywords):
                    if any(argument.endswith("m0.json") for argument in command):
                        raise failure
                    return validation.subprocess.CompletedProcess(command, 0, stdout=_summary_output_for(command))

                printed = io.StringIO()
                with mock.patch.object(validation.subprocess, "run", side_effect=fake_run), contextlib.redirect_stdout(printed):
                    rows = [row for shard in shards for row in validation.run_check(shard, Path("."))]
                by_name = {row["name"]: row["status"] for row in rows}
                self.assertEqual(
                    {"member 0": status, "member 3": status, "member 1": "passed", "member 2": "passed"}, by_name,
                )
                process_lines = [line for line in printed.getvalue().splitlines() if line.startswith("process:")]
                self.assertEqual(2, len(process_lines))
                self.assertIn(f"original event analysis groups [1/2] {status} in ", process_lines[0])
                self.assertIn("original event analysis groups [2/2] completed in ", process_lines[1])


class ProcessShardMainTests(_KeepCheckoutClean, unittest.TestCase):
    """TD-58: `main()` reads the member durations once and hands them to the
    partition and to the scheduler, caps the split by `--jobs`, and refuses a
    shard name."""

    _FAMILY_ALL_NAME = "original event analysis groups"

    def _run_main(self, argv: list[str], *, run_check=None, run_checks_scheduled=None, members=None):
        planned = members if members is not None else _numbered_members(4)
        patches = [
            mock.patch.object(sys, "argv", ["validation", *argv]),
            mock.patch.object(validation, "find_godot", return_value=Path("godot")),
            mock.patch.object(validation, "build_checks", return_value=planned),
            mock.patch.object(validation, "load_validation_registry", return_value=[]),
            mock.patch.object(validation, "load_validation_families", return_value=_SHARDED_FAMILIES),
            contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()),
        ]
        if run_check is not None:
            patches.append(mock.patch.object(validation, "run_check", side_effect=run_check))
        if run_checks_scheduled is not None:
            patches.append(mock.patch.object(validation, "run_checks_scheduled", side_effect=run_checks_scheduled))
        with contextlib.ExitStack() as stack:
            for patch in patches:
                stack.enter_context(patch)
            return validation.main()

    @staticmethod
    def _rows_for(checks) -> list[dict]:
        return [
            {"name": member.name, "status": "passed", "return_code": 0, "duration_seconds": 1.0}
            for check in checks for member in check.members
        ]

    @staticmethod
    def _write_cache_entry(cache_dir: Path, name: str, duration: float) -> None:
        (cache_dir / "fp").mkdir(parents=True, exist_ok=True)
        (cache_dir / "fp" / f"{name}.json").write_text(json.dumps({
            "name": name, "duration_seconds": duration, "recorded_at": "2026-10-09T00:00:00+00:00",
        }), encoding="utf-8")

    def test_jobs_two_splits_the_members_by_the_durations_read_once_report_before_cache(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            cache_dir = Path(directory) / "cache"
            report_path = Path(directory) / "groups.json"
            for name, duration in (("member 0", 1.0), ("member 1", 5.0), ("member 2", 4.0), ("member 3", 3.0)):
                self._write_cache_entry(cache_dir, name, duration)
            # The previous report's run row for member 0 wins over the cache's 1.0 s.
            payload = {"checks": [{"name": "member 0", "duration_seconds": 8.0}]}
            report_path.write_text(json.dumps({"payload_json": json.dumps(payload)}), encoding="utf-8")
            captured: dict[str, object] = {}

            def fake_run_checks_scheduled(checks_to_run, project, **keywords):
                captured["names"] = [check.name for check in checks_to_run]
                captured["members"] = _shard_member_names(checks_to_run)
                captured["keywords"] = keywords
                return self._rows_for(checks_to_run), None, None

            exit_code = self._run_main(
                ["--jobs", "2", "--report", str(report_path), "--cache-dir", str(cache_dir),
                 "--check", self._FAMILY_ALL_NAME],
                run_checks_scheduled=fake_run_checks_scheduled,
            )
            self.assertEqual(0, exit_code)
            self.assertEqual(
                ["original event analysis groups [1/2]", "original event analysis groups [2/2]"], captured["names"],
            )
            self.assertEqual([("member 0", "member 3"), ("member 1", "member 2")], captured["members"])
            keywords = captured["keywords"]
            self.assertEqual(2, keywords["jobs"])
            self.assertEqual(
                {"member 0": 8.0, "member 1": 5.0, "member 2": 4.0, "member 3": 3.0}, keywords["durations"],
            )
            report = json.loads(json.loads(report_path.read_text(encoding="utf-8"))["payload_json"])
            self.assertEqual(4, report["check_count"])
            validate_payload(report)

    def test_jobs_one_keeps_one_process_with_todays_name_and_reads_no_durations(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            captured: list[validation.Check] = []

            def fake_run_check(check, project):
                captured.append(check)
                return self._rows_for([check])

            with mock.patch.object(validation, "_recorded_durations") as recorded:
                exit_code = self._run_main(
                    ["--report", str(Path(directory) / "groups.json"), "--cache-dir", str(Path(directory) / "cache"),
                     "--check", self._FAMILY_ALL_NAME],
                    run_check=fake_run_check,
                )
            recorded.assert_not_called()
            self.assertEqual(0, exit_code)
            self.assertEqual([self._FAMILY_ALL_NAME], [check.name for check in captured])
            self.assertEqual(4, len(captured[0].members))
            self.assertEqual("", captured[0].shard_plan)

    def test_a_cached_run_with_partial_hits_splits_only_the_misses(self) -> None:
        # The collapse follows the cache filter: two of four members are cached, so the
        # two misses become two shards of one member each, and the report still has four rows.
        with tempfile.TemporaryDirectory() as directory:
            cache_dir = Path(directory) / "cache"

            def fake_run_check(check, project):
                return self._rows_for([check])

            store_exit = self._run_main(
                ["--report", str(Path(directory) / "store.json"), "--cache-dir", str(cache_dir), "--cache-store",
                 "--check", "member 0", "--check", "member 1"],
                run_check=fake_run_check,
            )
            self.assertEqual(0, store_exit)
            captured: dict[str, object] = {}

            def fake_run_checks_scheduled(checks_to_run, project, **keywords):
                captured["names"] = [check.name for check in checks_to_run]
                captured["members"] = _shard_member_names(checks_to_run)
                return self._rows_for(checks_to_run), None, None

            report_path = Path(directory) / "partial.json"
            exit_code = self._run_main(
                ["--jobs", "2", "--report", str(report_path), "--cache-dir", str(cache_dir), "--cached",
                 "--check", self._FAMILY_ALL_NAME],
                run_checks_scheduled=fake_run_checks_scheduled,
            )
            self.assertEqual(0, exit_code)
            self.assertEqual(
                ["original event analysis groups [1/2]", "original event analysis groups [2/2]"], captured["names"],
            )
            self.assertEqual([("member 2",), ("member 3",)], captured["members"])
            report = json.loads(json.loads(report_path.read_text(encoding="utf-8"))["payload_json"])
            validate_payload(report)
            self.assertEqual(4, report["check_count"])
            self.assertEqual(2, report["cached"])
            self.assertEqual(["member 0", "member 1", "member 2", "member 3"], [row["name"] for row in report["checks"]])

    def test_a_shard_name_given_to_check_is_a_configuration_error_naming_the_all_members_name(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            report_path = Path(directory) / "refused.json"
            ran: list[validation.Check] = []

            def fake_run_checks_scheduled(checks_to_run, project, **keywords):
                # A configuration error still reaches the scheduler, with nothing planned to run.
                ran.extend(checks_to_run)
                return [], None, None

            exit_code = self._run_main(
                ["--jobs", "2", "--report", str(report_path), "--cache-dir", str(Path(directory) / "cache"),
                 "--check", "original event analysis groups [1/2]"],
                run_checks_scheduled=fake_run_checks_scheduled,
            )
            self.assertEqual(2, exit_code)
            self.assertEqual([], ran)
            report = json.loads(json.loads(report_path.read_text(encoding="utf-8"))["payload_json"])
            self.assertEqual("configuration_error", report["status"])
            self.assertIn("names a process shard", report["configuration_error"])
            self.assertIn("--check 'original event analysis groups'", report["configuration_error"])


class ProcessCheckMainEndToEndTests(_KeepCheckoutClean, unittest.TestCase):
    def test_main_runs_a_process_check_and_writes_a_v4_report_with_one_row_per_member(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            report_path = Path(directory) / "groups.json"
            members = [
                _analysis_member("member a", "a.json"),
                _analysis_member("member b", "b.json"),
            ]
            planned = [validation.Check("other", (), 1)] + members
            process = validation.subprocess.CompletedProcess(("godot",), 0, stdout=_groups_summary_output())
            # `subprocess.run` is mocked once for both the ordinary check
            # ("other", command `()`) and the process check: the ordinary
            # check's own command is irrelevant here since its result comes
            # from the same mocked `CompletedProcess`, so give it its own
            # expected report row through `run_check()`'s own zero-exit path
            # (`()` as a command exits 0 with the same fixture stdout, which
            # `run_check()` treats as a passed check since it never matches
            # `check.command[1:2] == ("--headless",)`).
            # An explicit, isolated `--cache-dir` keeps TD-32 part 3b's own
            # fingerprinting/storing (the members now carry a real `kind`/
            # `requires`, so it runs for real here) out of the repository's
            # own `analysis/validation_cache` (the default).
            with mock.patch.object(sys, "argv", ["validation", "--report", str(report_path), "--check", "other",
                                                  "--check", "member a", "--check", "member b",
                                                  "--cache-dir", str(Path(directory) / "cache")]):
                with mock.patch.object(validation, "find_godot", return_value=Path("godot")), \
                     mock.patch.object(validation, "build_checks", return_value=planned), \
                     mock.patch.object(validation, "load_validation_registry", return_value=[]), \
                     mock.patch.object(validation, "load_validation_families", return_value={
                         "analysis_group": {
                             "check": "original event analysis groups",
                             "script": "res://tools/content_suite/validators/validate_event_analysis_groups.gd",
                             "process_timeout": 3600, "groups": ["original_corpus"], "tier": "full",
                         }
                     }), \
                     mock.patch.object(validation.subprocess, "run", return_value=process), \
                     contextlib.redirect_stdout(io.StringIO()):
                    exit_code = validation.main()
            report = json.loads(json.loads(report_path.read_text(encoding="utf-8"))["payload_json"])
            self.assertEqual(1, exit_code)
            self.assertEqual(3, report["check_count"])
            names = {row["name"] for row in report["checks"]}
            self.assertEqual({"other", "member a", "member b"}, names)
            validate_payload(report)


def _cache_check(name: str) -> "validation.Check":
    # The extra `--fixture <name>` argument keeps two differently-named
    # checks' fingerprints distinct (`fingerprint()` hashes the command
    # text, not `check.name`) - without it, two checks whose command is
    # otherwise identical would collide onto the same cache entry.
    return validation.Check(
        name, (sys.executable, "tools/content_suite/validation_cache.py", "--fixture", name), 30,
        kind="python", requires=(),
    )


class CachedRunTests(_KeepCheckoutClean, unittest.TestCase):
    """TD-32 part 3b, section 3: `--cached` end to end, with `subprocess.run`
    patched so no Godot process actually launches."""

    def test_first_run_stores_second_run_hits_every_check_and_runs_nothing(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            cache_dir = Path(directory) / "cache"
            checks = [_cache_check("alpha"), _cache_check("beta")]
            passed = validation.subprocess.CompletedProcess(("fixture",), 0, stdout="")

            with mock.patch.object(sys, "argv", [
                "validation", "--report", str(Path(directory) / "first.json"),
                "--cache-dir", str(cache_dir), "--cached",
            ]):
                with mock.patch.object(validation, "find_godot", return_value=Path("godot")), \
                     mock.patch.object(validation, "build_checks", return_value=checks), \
                     mock.patch.object(validation, "load_validation_registry", return_value=[]), \
                     mock.patch.object(validation, "load_validation_families", return_value={}), \
                     mock.patch.object(validation.subprocess, "run", return_value=passed) as run_one, \
                     contextlib.redirect_stdout(io.StringIO()):
                    exit_code_one = validation.main()
            self.assertEqual(0, exit_code_one)
            self.assertEqual(2, run_one.call_count)  # nothing cached yet: both run

            with mock.patch.object(sys, "argv", [
                "validation", "--report", str(Path(directory) / "second.json"),
                "--cache-dir", str(cache_dir), "--cached",
            ]):
                with mock.patch.object(validation, "find_godot", return_value=Path("godot")), \
                     mock.patch.object(validation, "build_checks", return_value=checks), \
                     mock.patch.object(validation, "load_validation_registry", return_value=[]), \
                     mock.patch.object(validation, "load_validation_families", return_value={}), \
                     mock.patch.object(validation.subprocess, "run") as run_two, \
                     contextlib.redirect_stdout(io.StringIO()):
                    exit_code_two = validation.main()
            run_two.assert_not_called()
            self.assertEqual(0, exit_code_two)
            report = json.loads(json.loads((Path(directory) / "second.json").read_text(encoding="utf-8"))["payload_json"])
            validate_payload(report)
            self.assertEqual("kakyu_content_tools_validation/v6", report["schema"])
            self.assertEqual(2, report["check_count"])
            self.assertEqual(2, report["cached"])
            self.assertEqual("consulted", report["context"]["cache"])
            for row in report["checks"]:
                self.assertTrue(row["cached"])
                self.assertEqual(0, row["duration_seconds"])
                self.assertEqual(0, row["return_code"])

    def test_run_without_cached_after_a_store_still_runs_everything_and_reports_not_consulted(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            cache_dir = Path(directory) / "cache"
            checks = [_cache_check("gamma")]
            passed = validation.subprocess.CompletedProcess(("fixture",), 0, stdout="")

            with mock.patch.object(sys, "argv", [
                "validation", "--report", str(Path(directory) / "first.json"),
                "--cache-dir", str(cache_dir), "--cached",
            ]):
                with mock.patch.object(validation, "find_godot", return_value=Path("godot")), \
                     mock.patch.object(validation, "build_checks", return_value=checks), \
                     mock.patch.object(validation, "load_validation_registry", return_value=[]), \
                     mock.patch.object(validation, "load_validation_families", return_value={}), \
                     mock.patch.object(validation.subprocess, "run", return_value=passed), \
                     contextlib.redirect_stdout(io.StringIO()):
                    validation.main()

            with mock.patch.object(sys, "argv", [
                "validation", "--report", str(Path(directory) / "second.json"), "--cache-dir", str(cache_dir),
            ]):
                with mock.patch.object(validation, "find_godot", return_value=Path("godot")), \
                     mock.patch.object(validation, "build_checks", return_value=checks), \
                     mock.patch.object(validation, "load_validation_registry", return_value=[]), \
                     mock.patch.object(validation, "load_validation_families", return_value={}), \
                     mock.patch.object(validation.subprocess, "run", return_value=passed) as run_two, \
                     contextlib.redirect_stdout(io.StringIO()):
                    exit_code = validation.main()
            run_two.assert_called_once()
            self.assertEqual(0, exit_code)
            report = json.loads(json.loads((Path(directory) / "second.json").read_text(encoding="utf-8"))["payload_json"])
            validate_payload(report)
            self.assertEqual(0, report["cached"])
            self.assertEqual("not_consulted", report["context"]["cache"])
            self.assertNotIn("cached", report["checks"][0])

    def test_run_without_either_cache_flag_writes_nothing_even_when_run_check_is_faked(self) -> None:
        """TD-32 part 3c, section 2(a): with neither `--cached` nor
        `--cache-store`, the cache is not engaged at all - nothing is
        fingerprinted, looked up or written, even for a check whose result
        `run_check` fakes as a pass (a real Godot check would also never
        run here)."""
        with tempfile.TemporaryDirectory() as directory:
            cache_dir = Path(directory) / "cache"
            checks = [_cache_check("epsilon")]

            def fake_run_check(check: validation.Check, project: Path) -> dict[str, object]:
                return {"name": check.name, "status": "passed", "return_code": 0, "duration_seconds": 0.001}

            with mock.patch.object(sys, "argv", [
                "validation", "--report", str(Path(directory) / "report.json"), "--cache-dir", str(cache_dir),
            ]):
                with mock.patch.object(validation, "find_godot", return_value=Path("godot")), \
                     mock.patch.object(validation, "build_checks", return_value=checks), \
                     mock.patch.object(validation, "load_validation_registry", return_value=[]), \
                     mock.patch.object(validation, "load_validation_families", return_value={}), \
                     mock.patch.object(validation, "run_check", side_effect=fake_run_check), \
                     contextlib.redirect_stdout(io.StringIO()):
                    exit_code = validation.main()
            self.assertEqual(0, exit_code)
            self.assertFalse(cache_dir.exists())
            report = json.loads(json.loads((Path(directory) / "report.json").read_text(encoding="utf-8"))["payload_json"])
            validate_payload(report)
            self.assertEqual(0, report["cached"])
            self.assertEqual("not_consulted", report["context"]["cache"])

    def test_cache_store_writes_without_reading_and_a_later_cached_run_hits(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            cache_dir = Path(directory) / "cache"
            checks = [_cache_check("zeta")]
            passed = validation.subprocess.CompletedProcess(("fixture",), 0, stdout="")

            with mock.patch.object(sys, "argv", [
                "validation", "--report", str(Path(directory) / "first.json"),
                "--cache-dir", str(cache_dir), "--cache-store",
            ]):
                with mock.patch.object(validation, "find_godot", return_value=Path("godot")), \
                     mock.patch.object(validation, "build_checks", return_value=checks), \
                     mock.patch.object(validation, "load_validation_registry", return_value=[]), \
                     mock.patch.object(validation, "load_validation_families", return_value={}), \
                     mock.patch.object(validation.subprocess, "run", return_value=passed) as run_one, \
                     contextlib.redirect_stdout(io.StringIO()):
                    exit_code_one = validation.main()
            self.assertEqual(0, exit_code_one)
            self.assertEqual(1, run_one.call_count)  # --cache-store never skips a check
            first_report = json.loads(
                json.loads((Path(directory) / "first.json").read_text(encoding="utf-8"))["payload_json"]
            )
            validate_payload(first_report)
            self.assertEqual(0, first_report["cached"])
            self.assertEqual("not_consulted", first_report["context"]["cache"])
            self.assertTrue(list(cache_dir.rglob("*.json")))  # stored despite never reading

            with mock.patch.object(sys, "argv", [
                "validation", "--report", str(Path(directory) / "second.json"),
                "--cache-dir", str(cache_dir), "--cached",
            ]):
                with mock.patch.object(validation, "find_godot", return_value=Path("godot")), \
                     mock.patch.object(validation, "build_checks", return_value=checks), \
                     mock.patch.object(validation, "load_validation_registry", return_value=[]), \
                     mock.patch.object(validation, "load_validation_families", return_value={}), \
                     mock.patch.object(validation.subprocess, "run") as run_two, \
                     contextlib.redirect_stdout(io.StringIO()):
                    exit_code_two = validation.main()
            run_two.assert_not_called()
            self.assertEqual(0, exit_code_two)
            second_report = json.loads(
                json.loads((Path(directory) / "second.json").read_text(encoding="utf-8"))["payload_json"]
            )
            validate_payload(second_report)
            self.assertEqual(1, second_report["cached"])
            self.assertEqual("consulted", second_report["context"]["cache"])

    def test_a_failed_check_is_never_stored_and_a_third_run_still_runs_it(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            cache_dir = Path(directory) / "cache"
            checks = [_cache_check("delta")]
            failed = validation.subprocess.CompletedProcess(("fixture",), 1, stdout="")

            for label in ("first", "second", "third"):
                with mock.patch.object(sys, "argv", [
                    "validation", "--report", str(Path(directory) / f"{label}.json"),
                    "--cache-dir", str(cache_dir), "--cached",
                ]):
                    with mock.patch.object(validation, "find_godot", return_value=Path("godot")), \
                         mock.patch.object(validation, "build_checks", return_value=checks), \
                         mock.patch.object(validation, "load_validation_registry", return_value=[]), \
                         mock.patch.object(validation, "load_validation_families", return_value={}), \
                         mock.patch.object(validation.subprocess, "run", return_value=failed) as run, \
                         contextlib.redirect_stdout(io.StringIO()):
                        exit_code = validation.main()
                self.assertEqual(1, exit_code)
                run.assert_called_once()  # every run is a miss - a failed check is never cached
                report = json.loads(json.loads((Path(directory) / f"{label}.json").read_text(encoding="utf-8"))["payload_json"])
                validate_payload(report)
                self.assertEqual(0, report["cached"])

    def test_hit_and_miss_rows_keep_the_planned_check_order(self) -> None:
        """TD-32 part 3c, section 2(b): an interleaving of cache hits and
        misses still reports rows in `checks`' own planned order - not every
        hit before every miss."""
        with tempfile.TemporaryDirectory() as directory:
            cache_dir = Path(directory) / "cache"
            checks = [_cache_check(name) for name in ("alpha", "beta", "gamma", "delta")]
            passed = validation.subprocess.CompletedProcess(("fixture",), 0, stdout="")

            def store(names: list[str]) -> None:
                with mock.patch.object(sys, "argv", [
                    "validation", "--report", str(Path(directory) / "store.json"), "--cache-dir", str(cache_dir),
                    "--cache-store", *[token for name in names for token in ("--check", name)],
                ]):
                    with mock.patch.object(validation, "find_godot", return_value=Path("godot")), \
                         mock.patch.object(validation, "build_checks", return_value=checks), \
                         mock.patch.object(validation, "load_validation_registry", return_value=[]), \
                         mock.patch.object(validation, "load_validation_families", return_value={}), \
                         mock.patch.object(validation.subprocess, "run", return_value=passed), \
                         contextlib.redirect_stdout(io.StringIO()):
                        self.assertEqual(0, validation.main())

            # beta and delta are cached; alpha and gamma will be misses.
            store(["beta", "delta"])

            with mock.patch.object(sys, "argv", [
                "validation", "--report", str(Path(directory) / "second.json"),
                "--cache-dir", str(cache_dir), "--cached",
            ]):
                with mock.patch.object(validation, "find_godot", return_value=Path("godot")), \
                     mock.patch.object(validation, "build_checks", return_value=checks), \
                     mock.patch.object(validation, "load_validation_registry", return_value=[]), \
                     mock.patch.object(validation, "load_validation_families", return_value={}), \
                     mock.patch.object(validation.subprocess, "run", return_value=passed), \
                     contextlib.redirect_stdout(io.StringIO()):
                    exit_code = validation.main()
            self.assertEqual(0, exit_code)
            report = json.loads(json.loads((Path(directory) / "second.json").read_text(encoding="utf-8"))["payload_json"])
            validate_payload(report)
            self.assertEqual(["alpha", "beta", "gamma", "delta"], [row["name"] for row in report["checks"]])
            self.assertEqual(2, report["cached"])

    def test_a_family_with_one_cached_member_runs_a_process_over_the_other_members_only(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            cache_dir = Path(directory) / "cache"
            members = [
                _analysis_member(f"member {i}", f"config/event_catalog/analysis_groups/fixture_m{i}.json")
                for i in range(3)
            ]
            member_zero_summary = json.dumps({
                "schema": "kakyu_event_analysis_groups_run/v1", "profiles": 1, "passed": 1, "failed": 0,
                "groups": [{"profile": members[0].profile, "status": "passed", "duration_seconds": 1.0, "checks": 5, "failures": []}],
            })
            store_output = "\n".join([
                f"=== GROUP {members[0].profile} ===", '{"ok": true}', "--- GROUP PASSED (1.000s) ---",
                "GROUPS_SUMMARY " + member_zero_summary,
            ]) + "\n"
            store_process = validation.subprocess.CompletedProcess(("fixture",), 0, stdout=store_output)

            with mock.patch.object(sys, "argv", [
                "validation", "--report", str(Path(directory) / "store.json"),
                "--cache-dir", str(cache_dir), "--check", "member 0", "--cache-store",
            ]):
                with mock.patch.object(validation, "find_godot", return_value=Path("godot")), \
                     mock.patch.object(validation, "build_checks", return_value=[members[0]]), \
                     mock.patch.object(validation, "load_validation_registry", return_value=[]), \
                     mock.patch.object(validation, "load_validation_families", return_value=_ANALYSIS_GROUP_FAMILIES), \
                     mock.patch.object(validation.subprocess, "run", return_value=store_process), \
                     contextlib.redirect_stdout(io.StringIO()):
                    store_exit = validation.main()
            self.assertEqual(0, store_exit)

            remaining_summary = json.dumps({
                "schema": "kakyu_event_analysis_groups_run/v1", "profiles": 2, "passed": 2, "failed": 0,
                "groups": [
                    {"profile": members[1].profile, "status": "passed", "duration_seconds": 1.0, "checks": 5, "failures": []},
                    {"profile": members[2].profile, "status": "passed", "duration_seconds": 1.0, "checks": 5, "failures": []},
                ],
            })
            remaining_output = "\n".join([
                f"=== GROUP {members[1].profile} ===", '{"ok": true}', "--- GROUP PASSED (1.000s) ---",
                f"=== GROUP {members[2].profile} ===", '{"ok": true}', "--- GROUP PASSED (1.000s) ---",
                "GROUPS_SUMMARY " + remaining_summary,
            ]) + "\n"
            remaining_process = validation.subprocess.CompletedProcess(("fixture",), 0, stdout=remaining_output)

            with mock.patch.object(sys, "argv", [
                "validation", "--report", str(Path(directory) / "second.json"), "--cache-dir", str(cache_dir),
                "--cached", "--check", "member 0", "--check", "member 1", "--check", "member 2",
            ]):
                with mock.patch.object(validation, "find_godot", return_value=Path("godot")), \
                     mock.patch.object(validation, "build_checks", return_value=members), \
                     mock.patch.object(validation, "load_validation_registry", return_value=[]), \
                     mock.patch.object(validation, "load_validation_families", return_value=_ANALYSIS_GROUP_FAMILIES), \
                     mock.patch.object(validation.subprocess, "run", return_value=remaining_process) as run, \
                     contextlib.redirect_stdout(io.StringIO()):
                    exit_code = validation.main()
            self.assertEqual(0, exit_code)
            run.assert_called_once()
            process_command = run.call_args[0][0]
            self.assertNotIn(members[0].profile, process_command)
            self.assertIn(members[1].profile, process_command)
            self.assertIn(members[2].profile, process_command)
            report = json.loads(json.loads((Path(directory) / "second.json").read_text(encoding="utf-8"))["payload_json"])
            validate_payload(report)
            self.assertEqual(3, report["check_count"])
            self.assertEqual(1, report["cached"])
            names = {row["name"] for row in report["checks"]}
            self.assertEqual({"member 0", "member 1", "member 2"}, names)


class EditorIgnoreTests(unittest.TestCase):
    """TD-52: the runner keeps an empty `analysis/.gdignore` so the Godot
    project parse check's editor scan does not walk the untracked tree."""

    def test_creates_an_empty_marker_when_the_directory_exists(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory)
            self.assertTrue(validation.ensure_editor_ignore(target))
            marker = target / ".gdignore"
            self.assertTrue(marker.is_file())
            self.assertEqual(b"", marker.read_bytes())

    def test_does_nothing_when_the_directory_is_absent(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory) / "analysis"
            # The OSError fallback alone would also return False for an absent
            # directory; patching `open` pins the `is_dir()` guard itself: no
            # create is attempted.
            with mock.patch.object(Path, "open") as opened:
                self.assertFalse(validation.ensure_editor_ignore(target))
            opened.assert_not_called()
            self.assertFalse(target.exists())

    def test_leaves_an_existing_marker_untouched(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            marker = Path(directory) / ".gdignore"
            marker.write_bytes(b"owner-written\n")
            before = marker.stat().st_mtime_ns
            self.assertFalse(validation.ensure_editor_ignore(Path(directory)))
            self.assertEqual(b"owner-written\n", marker.read_bytes())
            self.assertEqual(before, marker.stat().st_mtime_ns)

    def test_returns_false_when_the_marker_cannot_be_written(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory)
            with mock.patch.object(Path, "open", side_effect=PermissionError("read-only")):
                self.assertFalse(validation.ensure_editor_ignore(target))
            self.assertFalse((target / ".gdignore").exists())

    def test_main_ensures_the_marker_for_the_projects_analysis_before_the_first_check(self) -> None:
        passed = {"name": "first", "status": "passed", "return_code": 0, "duration_seconds": 0.1}
        for jobs in ("1", "2"):
            with self.subTest(jobs=jobs), tempfile.TemporaryDirectory() as directory:
                events: list[tuple] = []
                checks = [validation.Check("first", (), 1)]

                def fake_ensure(path: Path) -> bool:
                    events.append(("ensure", Path(path).resolve()))
                    return False

                def fake_run_check(check: validation.Check, project: Path) -> dict[str, object]:
                    events.append(("run_check", check.name))
                    return passed

                def fake_run_checks_scheduled(checks_to_run, project, **keywords):
                    events.append(("run_checks_scheduled", [check.name for check in checks_to_run]))
                    return [passed], None, None

                with mock.patch.object(sys, "argv", [
                    "validation", "--jobs", jobs, "--report", str(Path(directory) / "report.json"),
                    "--cache-dir", str(Path(directory) / "cache"),
                ]):
                    with mock.patch.object(validation, "find_godot", return_value=Path("godot")), \
                         mock.patch.object(validation, "build_checks", return_value=checks), \
                         mock.patch.object(validation, "ensure_editor_ignore", side_effect=fake_ensure), \
                         mock.patch.object(validation, "run_check", side_effect=fake_run_check), \
                         mock.patch.object(validation, "run_checks_scheduled", side_effect=fake_run_checks_scheduled), \
                         contextlib.redirect_stdout(io.StringIO()):
                        self.assertEqual(0, validation.main())
                self.assertEqual(("ensure", (ROOT / "analysis").resolve()), events[0])
                self.assertEqual(2, len(events))
                self.assertEqual("run_check" if jobs == "1" else "run_checks_scheduled", events[1][0])


if __name__ == "__main__":
    unittest.main()
