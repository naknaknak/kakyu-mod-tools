"""TD-32 part 1: the validation checks registry is data, not hand-written
tuples. These tests exercise the registry and the loader directly; the
outcome-level behaviour (the actual planned checks for every argument
combination) stays pinned by `tests/test_run_headless_validation.py`.
"""
from __future__ import annotations

import argparse
import copy
import json
import re
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools" / "content_suite"))

import run_headless_validation as validation  # noqa: E402


# The native executable audits are not part of the public source snapshot
# (WD-25 item 7a): its registry drops their checks, and these two placeholders
# are then used by no entry. A placeholder may go unused only when the script
# of the check that needs it is absent; here every script exists, so every
# known placeholder must still be used.
PLACEHOLDERS_OF_NATIVE_AUDIT_CHECKS = {
    "se_arc": "tools/audit_eventb03_sound.py",
    "voice_arc": "tools/audit_ai5_audio_exe.py",
}


def load_raw_registry() -> dict:
    return json.loads((ROOT / validation.REGISTRY_PATH).read_text(encoding="utf-8"))


class ValidationRegistryTests(unittest.TestCase):
    def test_registry_loads_and_validates(self) -> None:
        entries = validation.load_validation_registry()
        self.assertTrue(entries)
        self.assertEqual(len(entries), len({entry["name"] for entry in entries}))

    def test_every_script_and_profile_path_exists(self) -> None:
        for entry in validation.load_validation_registry():
            if entry.get("family") == "godot_scenes":
                continue
            script = entry["script"]
            if script:
                relative = script.removeprefix("res://")
                self.assertTrue((ROOT / relative).is_file(), f"{entry['name']}: missing script {relative}")
            if entry.get("family") == "analysis_group":
                self.assertTrue((ROOT / entry["profile"]).is_file(), entry["name"])

    def test_every_profile_on_disk_has_exactly_one_entry(self) -> None:
        arguments = argparse.Namespace(elfimage=None, exe=None, skip_event_corpus=False)
        with tempfile.TemporaryDirectory() as directory:
            source_root = Path(directory)
            for name in ("mes.arc", "mmo.arc", "data.arc"):
                (source_root / name).write_bytes(b"fixture")
            arguments = argparse.Namespace(elfimage=source_root, exe=None, skip_event_corpus=False)
            checks = validation.build_checks(arguments, ROOT, Path("godot"))
        validator = "res://tools/content_suite/validators/validate_event_analysis_group.gd"
        profiles = [check.command[-1] for check in checks if validator in check.command]
        expected = {
            path.relative_to(ROOT).as_posix()
            for path in (ROOT / "config/event_catalog/analysis_groups").glob("*.json")
        }
        self.assertEqual(expected, set(profiles))
        self.assertEqual(len(expected), len(profiles))

    def test_scene_family_expands_to_every_scene_on_disk(self) -> None:
        arguments = argparse.Namespace(elfimage=None, exe=None, skip_event_corpus=False)
        checks = validation.build_checks(arguments, ROOT, Path("godot"))
        batched = {
            check.name.removeprefix("Godot ")
            for check in checks
            if check.registry_name == "Godot {scene}"
        }
        on_disk = {path.name for path in (ROOT / "tests").glob("*.tscn")}
        self.assertTrue(on_disk)
        self.assertEqual(on_disk, batched)

    def test_shards_entry_expands_to_named_checks_each_with_its_own_shard_argument(self) -> None:
        # TD-33 part 2: the real registry's own sharded entry
        # ("original catalog group routes", `"shards": 4`) expands the same
        # way `build_checks()` expands `godot_scenes` - one check per shard,
        # named "<name> [K/N]", every other field carried from the entry
        # unchanged, only the command gaining a trailing `shard=K/N`.
        raw = load_raw_registry()
        sharded_entry = next(entry for entry in raw["checks"] if entry.get("shards"))
        with tempfile.TemporaryDirectory() as directory:
            source_root = Path(directory)
            for name in ("mes.arc", "mmo.arc", "data.arc"):
                (source_root / name).write_bytes(b"fixture")
            arguments = argparse.Namespace(elfimage=source_root, exe=None, skip_event_corpus=False)
            checks = validation.build_checks(arguments, ROOT, Path("godot"))
        shard_checks = [check for check in checks if check.registry_name == sharded_entry["name"]]
        self.assertEqual(sharded_entry["shards"], len(shard_checks))
        for shard_index, check in enumerate(shard_checks, start=1):
            self.assertEqual(
                "%s [%d/%d]" % (sharded_entry["name"], shard_index, sharded_entry["shards"]), check.name,
            )
            self.assertEqual("shard=%d/%d" % (shard_index, sharded_entry["shards"]), check.command[-1])
            self.assertEqual(sharded_entry["timeout"], check.timeout)
            self.assertEqual(tuple(sharded_entry["groups"]), check.groups)
            self.assertEqual(sharded_entry["tier"], check.tier)
            self.assertEqual(tuple(sharded_entry["requires"]), check.requires)

    def test_documented_placeholders_are_exactly_used(self) -> None:
        raw = load_raw_registry()
        used: set[str] = set()
        for entry in raw["checks"]:
            if entry.get("family") == "godot_scenes":
                continue  # {scene} is a family-expansion token, not a documented placeholder
            texts = list(entry["arguments"]) + [entry["script"], entry["name"]]
            if isinstance(entry["timeout"], str):
                texts.append(entry["timeout"])
            for _, extra in entry.get("optional_arguments", []):
                texts.extend(extra)
            for text in texts:
                used.update(re.findall(r"\{(\w+)\}", text))
        # {project}, {python} and {godot} are not stored literally in any
        # entry's arguments: build_checks() always plugs them into the fixed
        # per-`kind` command shape (godot_command()/sys.executable), so every
        # entry of that kind uses them without repeating them 242 times.
        implied_by_every_entry = {"project", "godot", "python"}
        unused_with_their_check = {
            placeholder
            for placeholder, script in PLACEHOLDERS_OF_NATIVE_AUDIT_CHECKS.items()
            if not (ROOT / script).is_file()
        }
        self.assertEqual(
            validation.KNOWN_CHECK_PLACEHOLDERS - unused_with_their_check,
            (used | implied_by_every_entry) - unused_with_their_check,
        )
        kinds_seen = {entry["kind"] for entry in raw["checks"]}
        self.assertEqual({"python", "godot_editor", "godot_script", "godot_scene"}, kinds_seen)

    def test_tier_ordering(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            source_root = Path(directory) / "ELFIMAGE"
            source_root.mkdir()
            for archive_name in ("mes.arc", "mmo.arc", "data.arc", "voice.arc", "se.arc"):
                (source_root / archive_name).write_bytes(b"fixture")
            executable = Path(directory) / "AI5WIN.exe"
            executable.write_bytes(b"fixture")

            local_args = argparse.Namespace(
                elfimage=source_root, exe=executable, skip_event_corpus=False, tier="local",
            )
            local_checks = validation.build_checks(local_args, ROOT, Path("godot"))
            self.assertTrue(local_checks)
            self.assertTrue(all(check.tier == "local" for check in local_checks))
            # WD-25 item 1b: the local-tier Python suite reads the archives (the archive-literal
            # guard) when the run has an ELFIMAGE, so it is the one local check that carries the group.
            self.assertEqual(
                ["python regression suite"],
                [check.name for check in local_checks if "original_corpus" in check.groups],
            )

            quick_args = argparse.Namespace(
                elfimage=source_root, exe=executable, skip_event_corpus=False, tier="archive_quick",
            )
            quick_checks = validation.build_checks(quick_args, ROOT, Path("godot"))
            self.assertTrue(all(check.tier in ("local", "archive_quick") for check in quick_checks))
            self.assertTrue(
                all(check.timeout <= 600 for check in quick_checks if check.tier == "archive_quick")
            )
            self.assertFalse(any(check.tier == "full" for check in quick_checks))

            full_args = argparse.Namespace(
                elfimage=source_root, exe=executable, skip_event_corpus=False, tier="full",
            )
            full_checks = validation.build_checks(full_args, ROOT, Path("godot"))
            default_args = argparse.Namespace(
                elfimage=source_root, exe=executable, skip_event_corpus=False,
            )
            default_checks = validation.build_checks(default_args, ROOT, Path("godot"))
            self.assertEqual(
                [(check.name, check.command, check.timeout, check.groups) for check in full_checks],
                [(check.name, check.command, check.timeout, check.groups) for check in default_checks],
            )
            self.assertGreater(len(full_checks), len(quick_checks))
            self.assertGreater(len(quick_checks), len(local_checks))

    def _default_families(self) -> dict:
        # The real registry's own families block: valid, so a fixture that
        # only means to break a check entry does not also fail on this.
        return {
            "analysis_group": {
                "check": "original event analysis groups",
                "script": "res://tools/content_suite/validators/validate_event_analysis_groups.gd",
                "process_timeout": 8000,
                "groups": ["original_corpus"],
                "tier": "full",
            }
        }

    def _validate(self, checks: list[dict], families: dict | None = None) -> list[dict]:
        # Validate against the real repository root, so a fixture entry can
        # name a script/profile that genuinely exists there, and only the
        # deliberately introduced defect trips a failure.
        raw = {
            "schema": validation.REGISTRY_SCHEMA, "revision": validation.REGISTRY_REVISION, "checks": checks,
            "families": families if families is not None else self._default_families(),
        }
        return validation._validate_registry_document(raw, ROOT)

    def _minimal_entry(self, **overrides: object) -> dict:
        entry = {
            "name": "fixture check",
            "kind": "python",
            "script": "tools/content_suite/run_python_regression.py",
            "arguments": [],
            "timeout": 60,
            "groups": ["synthetic"],
            "requires": [],
            "tier": "local",
        }
        entry.update(overrides)
        return entry

    def test_malformed_registry_unknown_kind_fails_closed_naming_the_entry(self) -> None:
        with self.assertRaisesRegex(ValueError, "fixture check.*unknown kind"):
            self._validate([self._minimal_entry(kind="not_a_kind")])

    def test_malformed_registry_missing_script_fails_closed_naming_the_entry(self) -> None:
        with self.assertRaisesRegex(ValueError, "fixture check.*script does not exist"):
            self._validate([self._minimal_entry(script="tools/does_not_exist.py")])

    def test_malformed_registry_duplicate_name_fails_closed_naming_the_entry(self) -> None:
        with self.assertRaisesRegex(ValueError, "fixture check.*duplicate name"):
            self._validate([self._minimal_entry(), self._minimal_entry()])

    def test_malformed_registry_unknown_placeholder_fails_closed_naming_the_entry(self) -> None:
        with self.assertRaisesRegex(ValueError, "fixture check.*unknown placeholder"):
            self._validate([self._minimal_entry(arguments=["{not_a_placeholder}"])])

    def test_malformed_registry_unsupported_schema_fails_closed(self) -> None:
        with self.assertRaisesRegex(ValueError, "unsupported schema"):
            validation._validate_registry_document({"schema": "wrong/v1", "revision": 1, "checks": []}, ROOT)

    def test_malformed_registry_placeholder_without_its_requirement_fails_closed(self) -> None:
        with self.assertRaisesRegex(ValueError, r"fixture check.*\{mes_arc\}.*requires 'elfimage'"):
            self._validate([self._minimal_entry(arguments=["{mes_arc}"])])

    def test_malformed_registry_placeholder_in_a_mismatched_optional_clause_fails_closed(self) -> None:
        with self.assertRaisesRegex(ValueError, r"fixture check.*\{exe\}.*'elfimage'.*requires 'exe'"):
            self._validate([self._minimal_entry(
                requires=["elfimage"],
                optional_arguments=[["elfimage", ["{exe}"]]],
            )])

    def test_malformed_registry_godot_scene_kind_requires_godot_scenes_family(self) -> None:
        with self.assertRaisesRegex(ValueError, "fixture check.*kind 'godot_scene' requires family 'godot_scenes'"):
            self._validate([self._minimal_entry(kind="godot_scene")])

    def test_malformed_registry_godot_scenes_family_requires_godot_scene_kind(self) -> None:
        with self.assertRaisesRegex(ValueError, "fixture check.*family 'godot_scenes' requires kind 'godot_scene'"):
            self._validate([self._minimal_entry(family="godot_scenes", kind="python")])

    def test_malformed_registry_analysis_group_family_requires_godot_script_kind(self) -> None:
        with self.assertRaisesRegex(ValueError, "fixture check.*family 'analysis_group' requires kind 'godot_script'"):
            self._validate([self._minimal_entry(
                family="analysis_group",
                profile="config/event_catalog/analysis_groups/does_not_exist.json",
            )])

    def test_malformed_registry_exclusive_must_be_boolean(self) -> None:
        with self.assertRaisesRegex(ValueError, "fixture check.*exclusive must be a boolean"):
            self._validate([self._minimal_entry(exclusive=1)])

    def test_exclusive_true_is_accepted(self) -> None:
        self._validate([self._minimal_entry(exclusive=True)])

    def test_malformed_registry_exclusive_scenes_requires_godot_scenes_family(self) -> None:
        with self.assertRaisesRegex(ValueError, "fixture check.*exclusive_scenes is only valid on a 'godot_scenes'"):
            self._validate([self._minimal_entry(exclusive_scenes=["test_process_liveness.tscn"])])

    def test_malformed_registry_exclusive_scenes_must_name_existing_scenes(self) -> None:
        with self.assertRaisesRegex(ValueError, "fixture check.*names a scene that does not exist"):
            self._validate([self._minimal_entry(
                kind="godot_scene", family="godot_scenes", script="res://tests/{scene}",
                exclusive_scenes=["does_not_exist.tscn"],
            )])

    def test_real_registry_scene_family_exclusive_scenes_are_a_subset_of_discovered_scenes(self) -> None:
        raw = load_raw_registry()
        scene_entry = next(entry for entry in raw["checks"] if entry.get("family") == "godot_scenes")
        exclusive_scenes = set(scene_entry.get("exclusive_scenes", []))
        on_disk = {path.name for path in (ROOT / "tests").glob("*.tscn")}
        self.assertTrue(exclusive_scenes)
        self.assertTrue(exclusive_scenes <= on_disk)

    def test_real_registry_playback_check_is_not_exclusive(self) -> None:
        # TD-64 part 2 D5: the lazy reader holds about 2 GB, so the check runs
        # beside others; the field stays in the vocabulary (see
        # `test_exclusive_true_is_accepted`) but no check needs it today.
        raw = load_raw_registry()
        entry = next(entry for entry in raw["checks"] if entry["name"] == "original playback package playback")
        self.assertNotIn("exclusive", entry)

    def test_malformed_registry_analysis_group_missing_profile_fails_closed(self) -> None:
        with self.assertRaisesRegex(ValueError, "fixture check.*profile does not exist"):
            self._validate([self._minimal_entry(
                kind="godot_script",
                script="res://tools/content_suite/validators/validate_event_analysis_group.gd",
                family="analysis_group",
                profile="config/event_catalog/analysis_groups/does_not_exist.json",
            )])

    def test_shards_valid_is_accepted(self) -> None:
        self._validate([self._minimal_entry(
            kind="godot_script",
            script="res://tools/content_suite/validators/validate_catalog_group_routes.gd",
            shards=2,
        )])

    def test_malformed_registry_shards_wrong_type_fails_closed(self) -> None:
        with self.assertRaisesRegex(ValueError, "fixture check.*shards must be an integer"):
            self._validate([self._minimal_entry(
                kind="godot_script",
                script="res://tools/content_suite/validators/validate_catalog_group_routes.gd",
                shards="4",
            )])

    def test_malformed_registry_shards_too_small_fails_closed(self) -> None:
        with self.assertRaisesRegex(ValueError, "fixture check.*shards must be an integer >= 2"):
            self._validate([self._minimal_entry(
                kind="godot_script",
                script="res://tools/content_suite/validators/validate_catalog_group_routes.gd",
                shards=1,
            )])

    def test_malformed_registry_shards_on_non_godot_script_entry_fails_closed(self) -> None:
        with self.assertRaisesRegex(ValueError, "fixture check.*shards is only valid on a 'godot_script' entry"):
            self._validate([self._minimal_entry(shards=2)])

    def test_families_block_loads_and_validates(self) -> None:
        families = validation.load_validation_families()
        self.assertEqual({"analysis_group"}, set(families))
        family = families["analysis_group"]
        self.assertEqual("original event analysis groups", family["check"])
        self.assertEqual(
            "res://tools/content_suite/validators/validate_event_analysis_groups.gd", family["script"],
        )
        self.assertGreater(family["process_timeout"], 0)
        self.assertIn("full", (family["tier"],))
        # TD-58: the tracked registry splits the family across two processes.
        self.assertEqual(2, family["process_shards"])

    def test_tracked_registry_is_at_the_current_revision(self) -> None:
        self.assertEqual(5, validation.REGISTRY_REVISION)
        self.assertEqual(validation.REGISTRY_REVISION, load_raw_registry()["revision"])

    def test_families_block_accepts_process_shards_and_leaves_it_optional(self) -> None:
        with_shards = {"analysis_group": {**self._default_families()["analysis_group"], "process_shards": 4}}
        self._validate([self._minimal_entry()], families=with_shards)
        self._validate([self._minimal_entry()])  # the default block carries none

    def test_malformed_registry_family_bad_process_shards_fails_closed(self) -> None:
        for bad in (True, False, 1, 0, -2, "2", 2.0, 2.5, None, [2]):
            with self.subTest(process_shards=bad):
                broken = {**self._default_families()["analysis_group"], "process_shards": bad}
                with self.assertRaisesRegex(ValueError, "analysis_group.*process_shards must be an integer >= 2"):
                    self._validate([self._minimal_entry()], families={"analysis_group": broken})

    def test_malformed_registry_family_unknown_extra_key_fails_closed(self) -> None:
        # The key set is required plus the one optional `process_shards`, not open-ended.
        broken = {**self._default_families()["analysis_group"], "process_shard": 2}
        with self.assertRaisesRegex(ValueError, "analysis_group.*malformed entry"):
            self._validate([self._minimal_entry()], families={"analysis_group": broken})
        broken = {**self._default_families()["analysis_group"], "process_shards": 2, "shards": 2}
        with self.assertRaisesRegex(ValueError, "analysis_group.*malformed entry"):
            self._validate([self._minimal_entry()], families={"analysis_group": broken})

    def test_a_revision_four_document_is_refused(self) -> None:
        # Revision 5 added `process_shards`; revisions 3 and 4 were refused the same way.
        raw = {
            "schema": validation.REGISTRY_SCHEMA, "revision": 4, "checks": [self._minimal_entry()],
            "families": self._default_families(),
        }
        with self.assertRaisesRegex(ValueError, "unsupported revision"):
            validation._validate_registry_document(raw, ROOT)
        raw["revision"] = validation.REGISTRY_REVISION
        validation._validate_registry_document(raw, ROOT)

    def test_malformed_registry_missing_families_block_fails_closed(self) -> None:
        with self.assertRaisesRegex(ValueError, "missing its families block"):
            self._validate([self._minimal_entry()], families={})

    def test_malformed_registry_unknown_family_key_fails_closed(self) -> None:
        with self.assertRaisesRegex(ValueError, "godot_scenes.*unknown family"):
            self._validate([self._minimal_entry()], families={"godot_scenes": self._default_families()["analysis_group"]})

    def test_malformed_registry_family_missing_script_fails_closed(self) -> None:
        broken = dict(self._default_families()["analysis_group"])
        broken["script"] = "res://tools/does_not_exist.gd"
        with self.assertRaisesRegex(ValueError, "analysis_group.*script does not exist"):
            self._validate([self._minimal_entry()], families={"analysis_group": broken})

    def test_malformed_registry_family_bad_timeout_fails_closed(self) -> None:
        broken = dict(self._default_families()["analysis_group"])
        broken["process_timeout"] = 0
        with self.assertRaisesRegex(ValueError, "analysis_group.*process_timeout must be a positive integer"):
            self._validate([self._minimal_entry()], families={"analysis_group": broken})

    def test_malformed_registry_family_unknown_tier_fails_closed(self) -> None:
        broken = dict(self._default_families()["analysis_group"])
        broken["tier"] = "not_a_tier"
        with self.assertRaisesRegex(ValueError, "analysis_group.*unknown tier"):
            self._validate([self._minimal_entry()], families={"analysis_group": broken})

    def test_malformed_registry_family_malformed_entry_fails_closed(self) -> None:
        broken = dict(self._default_families()["analysis_group"])
        del broken["groups"]
        with self.assertRaisesRegex(ValueError, "analysis_group.*malformed entry"):
            self._validate([self._minimal_entry()], families={"analysis_group": broken})

    def test_expand_family_all_selection_expands_to_every_planned_member(self) -> None:
        planned = [
            validation.Check("a", (), 1, family="analysis_group", profile="a.json"),
            validation.Check("b", (), 1, family="analysis_group", profile="b.json"),
            validation.Check("c", (), 1),
        ]
        families = self._default_families()
        expanded = validation.expand_family_all_selection(
            ["original event analysis groups", "c"], planned, families,
        )
        self.assertEqual(["a", "b", "c"], expanded)
        self.assertEqual(["c"], validation.expand_family_all_selection(["c"], planned, families))
        self.assertEqual([], validation.expand_family_all_selection(["original event analysis groups"], [], families))

    def test_expand_shard_all_selection_by_base_name_and_by_shard_name(self) -> None:
        planned = [
            validation.Check("sharded check [1/2]", (), 1, registry_name="sharded check"),
            validation.Check("sharded check [2/2]", (), 1, registry_name="sharded check"),
            validation.Check("c", (), 1, registry_name="c"),
        ]
        # The base (unsharded) name expands to every planned shard, in order.
        self.assertEqual(
            ["sharded check [1/2]", "sharded check [2/2]", "c"],
            validation.expand_shard_all_selection(["sharded check", "c"], planned),
        )
        # One shard's own name selects only that shard.
        self.assertEqual(
            ["sharded check [1/2]"], validation.expand_shard_all_selection(["sharded check [1/2]"], planned),
        )
        # A name that matches no planned shard (an out-of-range shard, or a
        # base name with none of its shards planned) passes through
        # unchanged - select_checks() gives it the usual diagnostic rather
        # than this silently expanding to an empty, "run everything" request.
        self.assertEqual(
            ["sharded check [3/2]"], validation.expand_shard_all_selection(["sharded check [3/2]"], planned),
        )
        self.assertEqual([], validation.expand_shard_all_selection([], planned))

    def test_select_checks_names_tier_exclusion_for_a_registered_but_unavailable_name(self) -> None:
        registry = [
            {"name": "archive check", "tier": "archive_quick", "requires": ["elfimage"]},
            {"name": "full check", "tier": "full", "requires": []},
        ]
        checks = [validation.Check("local check", (), 1, ("synthetic",), "local", "local check")]
        with self.assertRaisesRegex(ValueError, r"--check name not in this run: archive check \(excluded by --tier local\)"):
            validation.select_checks(
                checks, ["archive check"], registry=registry, tier="local",
                available={"elfimage": True, "exe": False},
            )
        with self.assertRaisesRegex(ValueError, r"--check name not in this run: full check \(excluded by --tier archive_quick\)"):
            validation.select_checks(
                checks, ["full check"], registry=registry, tier="archive_quick",
                available={"elfimage": True, "exe": False},
            )

    def test_select_checks_names_a_missing_requirement_for_a_registered_but_unavailable_name(self) -> None:
        registry = [
            {"name": "elfimage check", "tier": "full", "requires": ["elfimage"]},
            {"name": "exe check", "tier": "full", "requires": ["exe"]},
        ]
        checks = [validation.Check("local check", (), 1, ("synthetic",), "local", "local check")]
        with self.assertRaisesRegex(ValueError, r"--check name not in this run: elfimage check \(requires --elfimage\)"):
            validation.select_checks(
                checks, ["elfimage check"], registry=registry, tier="full",
                available={"elfimage": False, "exe": True},
            )
        with self.assertRaisesRegex(ValueError, r"--check name not in this run: exe check \(requires --exe\)"):
            validation.select_checks(
                checks, ["exe check"], registry=registry, tier="full",
                available={"elfimage": True, "exe": False},
            )

    def test_select_checks_keeps_the_generic_message_for_a_genuinely_unknown_name(self) -> None:
        checks = [validation.Check("local check", (), 1, ("synthetic",), "local", "local check")]
        with self.assertRaisesRegex(ValueError, "Unknown or unavailable --check name: wrong"):
            validation.select_checks(
                checks, ["wrong"], registry=[{"name": "local check", "tier": "local", "requires": []}],
                tier="full", available={"elfimage": False, "exe": False},
            )

    def test_registry_is_deep_copy_safe(self) -> None:
        # The loader must not hand back references an in-process caller could
        # mutate to affect a later load; a defensive copy is cheap insurance.
        first = validation.load_validation_registry()
        first[0]["name"] = "mutated"
        second = validation.load_validation_registry()
        self.assertNotEqual("mutated", second[0]["name"])


if __name__ == "__main__":
    unittest.main()
