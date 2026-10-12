from __future__ import annotations

import sys
import tempfile
import types
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools" / "content_suite"))

import validation_inputs as vi  # noqa: E402


def _write(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")


def _fake_check(
    name: str, command: tuple[str, ...], family: str = "", profile: str = "",
    requires: tuple[str, ...] = (), kind: str = "",
) -> types.SimpleNamespace:
    return types.SimpleNamespace(
        name=name, command=command, family=family, profile=profile, requires=requires, kind=kind,
    )


# TD-53: every original archive a `{source_root}` check can read, in the order
# `validation_inputs._ARCHIVE_CONTEXT_NAMES` lists them.
_ARCHIVE_STEMS = ("mes", "mmo", "data", "voice", "se", "bgm", "tina1", "tina2")


def _archive_context(root: Path) -> dict[str, str]:
    """The placeholder context the runner builds for an ELFIMAGE root: the
    archives it names, whether or not each file exists (an absent optional
    archive is skipped by `check_inputs()`, not an error)."""
    context = {"python": "py", "godot": "godot", "source_root": str(root)}
    for stem in _ARCHIVE_STEMS:
        context[f"{stem}_arc"] = str(root / f"{stem}.arc")
    return context


class SyntheticProjectTests(unittest.TestCase):
    """A scene -> script -> preload -> class-name reference -> data
    directory, plus a Python tool importing another and naming a config
    file, under a temporary project tree - never the real repository.
    """

    def setUp(self) -> None:
        self._temp = tempfile.TemporaryDirectory()
        self.addCleanup(self._temp.cleanup)
        self.project = Path(self._temp.name)

        _write(self.project / "project.godot", "[application]\n")

        _write(
            self.project / "content_core" / "a.gd",
            "\n".join([
                "class_name ClassA",
                "extends RefCounted",
                "",
                'const BScript := preload("res://content_core/b.gd")',
                'const DATA_DIR := "res://content_core/data"',
                'const STALE := "res://content_core/missing.gd"',
                "",
                "var typed_b: ClassB",
                "",
            ]),
        )
        _write(
            self.project / "content_core" / "b.gd",
            "class_name ClassB\nextends RefCounted\n",
        )
        _write(self.project / "content_core" / "data" / "x.json", "{}\n")

        _write(
            self.project / "content_core" / "dynamic_case.gd",
            "\n".join([
                "class_name DynamicCase",
                "extends RefCounted",
                "",
                "func pick(path):",
                "\treturn load(path)",
                "",
            ]),
        )
        _write(
            self.project / "content_core" / "const_case.gd",
            "\n".join([
                "class_name ConstCase",
                "extends RefCounted",
                "",
                'const TARGET := "res://content_core/b.gd"',
                "",
                "func fetch():",
                "\treturn load(TARGET)",
                "",
            ]),
        )
        # TD-32 part 3c, section 1(c): a dynamic-load argument that itself
        # contains a call with its own parentheses - the previous
        # closing-paren regex (`[^()]*\)`) never matched these at all, so
        # they were silently treated as no `load(` call and never flagged
        # dynamic.
        _write(
            self.project / "content_core" / "nested_paren_case.gd",
            "\n".join([
                "class_name NestedParenCase",
                "extends RefCounted",
                "",
                "func fetch(base_dir, name):",
                "\treturn load(base_dir.path_join(name))",
                "",
            ]),
        )
        _write(
            self.project / "content_core" / "nested_call_case.gd",
            "\n".join([
                "class_name NestedCallCase",
                "extends RefCounted",
                "",
                "func fetch(kind):",
                "\treturn load(_resolve(kind))",
                "",
            ]),
        )
        _write(
            self.project / "content_core" / "literal_case.gd",
            "\n".join([
                "class_name LiteralCase",
                "extends RefCounted",
                "",
                "func fetch():",
                '\treturn load("res://content_core/b.gd")',
                "",
            ]),
        )

        _write(
            self.project / "tests" / "scene.tscn",
            "\n".join([
                "[gd_scene load_steps=2 format=3]",
                "",
                '[ext_resource type="Script" path="res://content_core/a.gd" id="1_a"]',
                "",
                '[node name="Scene" type="Node"]',
                'script = ExtResource("1_a")',
                "",
            ]),
        )

        _write(
            self.project / "tools" / "tool_one.py",
            "\n".join([
                "from tool_two import helper",
                "",
                'CONFIG_PATH = "config/thing.json"',
                "",
            ]),
        )
        _write(self.project / "tools" / "tool_two.py", "def helper():\n\treturn 1\n")
        _write(self.project / "config" / "thing.json", "{}\n")

    def test_class_index_finds_declared_classes(self) -> None:
        index = vi.class_index(self.project)
        self.assertEqual(Path("content_core/a.gd"), index["ClassA"])
        self.assertEqual(Path("content_core/b.gd"), index["ClassB"])

    def test_scan_gd_finds_literals_and_class_references_excluding_self(self) -> None:
        index = vi.class_index(self.project)
        text = (self.project / "content_core" / "a.gd").read_text(encoding="utf-8")
        found = vi.scan_gd(text, index)
        self.assertIn("content_core/b.gd", found)
        self.assertIn("content_core/data", found)
        self.assertIn("content_core/missing.gd", found)
        # ClassA is a.gd's own declared class: it must not add a.gd to its
        # own reference set via the class-name path.
        self.assertNotIn("content_core/a.gd", found)

    def test_scan_py_resolves_bare_import_and_path_literal(self) -> None:
        text = (self.project / "tools" / "tool_one.py").read_text(encoding="utf-8")
        found = vi.scan_py(text, self.project)
        self.assertEqual({"tools/tool_two.py", "config/thing.json"}, found)

    def test_closure_from_scene_follows_script_preload_class_and_data_dir(self) -> None:
        result = vi.closure(["res://tests/scene.tscn"], self.project)
        self.assertIn("tests/scene.tscn", result.files)
        self.assertIn("content_core/a.gd", result.files)
        self.assertIn("content_core/b.gd", result.files)
        self.assertIn("content_core/data/x.json", result.files)
        self.assertIn("content_core/missing.gd", result.unresolved)
        self.assertEqual((), result.dynamic)

    def test_closure_from_python_tool_follows_import_and_config_literal(self) -> None:
        result = vi.closure(["tools/tool_one.py"], self.project)
        self.assertEqual(
            {"tools/tool_one.py", "tools/tool_two.py", "config/thing.json"},
            set(result.files),
        )
        self.assertEqual((), result.unresolved)
        self.assertEqual((), result.dynamic)

    def test_conservative_rule_triggers_on_variable_load_not_on_const_literal(self) -> None:
        constant_only = vi.closure(["content_core/const_case.gd"], self.project)
        self.assertEqual((), constant_only.dynamic)
        self.assertEqual({"content_core/const_case.gd", "content_core/b.gd"}, set(constant_only.files))

        dynamic_result = vi.closure(["content_core/dynamic_case.gd"], self.project)
        self.assertIn("content_core/dynamic_case.gd", dynamic_result.dynamic)
        # The widening rule: every .gd under content_core/ becomes an input.
        self.assertIn("content_core/a.gd", dynamic_result.files)
        self.assertIn("content_core/b.gd", dynamic_result.files)
        self.assertIn("content_core/const_case.gd", dynamic_result.files)

    def test_a_load_method_on_another_receiver_is_not_a_resource_load(self) -> None:
        # `ConfigFile.load(path)` and `config.load(path)` are file loads of
        # another object; only the global `load(` and `ResourceLoader.load(`
        # widen a closure.
        self.assertFalse(vi._has_dynamic_load(
            'var config := ConfigFile.new()\nvar status := config.load(path)\n'))
        self.assertFalse(vi._has_dynamic_load('ConfigFile.load(path)\n'))
        self.assertTrue(vi._has_dynamic_load('var s := load(path)\n'))
        self.assertTrue(vi._has_dynamic_load('ResourceLoader.load(path)\n'))

    def test_dynamic_load_detection_finds_a_call_with_nested_parens_in_its_argument(self) -> None:
        """TD-32 part 3c, section 1(c): `load(base_dir.path_join(name))` and
        `load(_resolve(kind))` are dynamic (their argument's first non-space
        character starts an identifier that is not immediately followed by
        the closing paren); a plain string-literal `load(...)` is not."""
        nested_paren = vi.closure(["content_core/nested_paren_case.gd"], self.project)
        self.assertIn("content_core/nested_paren_case.gd", nested_paren.dynamic)

        nested_call = vi.closure(["content_core/nested_call_case.gd"], self.project)
        self.assertIn("content_core/nested_call_case.gd", nested_call.dynamic)

        literal = vi.closure(["content_core/literal_case.gd"], self.project)
        self.assertEqual((), literal.dynamic)

    def test_scan_gd_ignores_bare_top_level_directory_references(self) -> None:
        index = vi.class_index(self.project)
        text = "\n".join([
            "class_name AssertionOnly",
            "extends RefCounted",
            "",
            'const TOOLS_ROOT := "res://tools"',
            'const TESTS_ROOT := "res://tests/"',
            'const CONTENT_CORE_ROOT := "res://content_core"',
            'const CONFIG_ROOT := "res://config/"',
            'const REAL_FILE := "res://tools/content_suite/validation_inputs.py"',
            "",
        ])
        found = vi.scan_gd(text, index)
        self.assertEqual({"tools/content_suite/validation_inputs.py"}, found)

    def test_tree_files_skips_pycache_directories_and_compiled_suffixes(self) -> None:
        """TD-32 part 3c, section 1(b): a local interpreter's `__pycache__`
        (and `.pytest_cache`/`.godot`/`.git`, and a `.pyc`/`.pyo`/`.tmp`/
        `.log` file anywhere else) is not a tracked source and must not
        enter a tree-glob check's fingerprint."""
        _write(self.project / "tools" / "__pycache__" / "tool_one.cpython-313.pyc", "junk")
        _write(self.project / "tools" / "content_suite" / "__pycache__" / "validation_inputs.cpython-313.pyc", "junk")
        _write(self.project / "tools" / "fixture_stray.tmp", "junk")
        _write(self.project / "tools" / ".pytest_cache" / "README.md", "junk")
        files = vi._tree_files(self.project, vi.PYTHON_REGRESSION_ROOTS)
        self.assertFalse(any("__pycache__" in path for path in files))
        self.assertFalse(any(".pytest_cache" in path for path in files))
        self.assertFalse(any(path.endswith((".pyc", ".pyo", ".tmp", ".log")) for path in files))
        self.assertIn("tools/tool_one.py", files)

    def test_scan_tscn_ignores_bare_top_level_directory_references(self) -> None:
        text = "\n".join([
            "[gd_scene load_steps=1 format=3]",
            "",
            '[node name="Root" type="Node"]',
            'assertion_only = "res://tools"',
            'ext_resource_path = "res://content_core/a.gd"',
            "",
        ])
        found = vi.scan_tscn(text)
        self.assertEqual({"content_core/a.gd"}, found)

    def test_check_inputs_python_kind_includes_baseline_and_import_closure(self) -> None:
        check = _fake_check("fixture python check", ("py", "tools/tool_one.py"), kind="python")
        context = {"python": "py", "godot": "godot"}
        inputs = vi.check_inputs(check, self.project, context)
        self.assertIn("tools/tool_one.py", inputs.files)
        self.assertIn("tools/tool_two.py", inputs.files)
        self.assertIn("config/thing.json", inputs.files)
        for baseline in vi.BASELINE_FILES:
            self.assertIn(baseline, inputs.files)
        self.assertEqual((), inputs.external)

    def test_check_inputs_godot_script_kind_includes_project_path_arguments(self) -> None:
        command = (
            "godot", "--headless", "--path", str(self.project),
            "--script", "res://content_core/a.gd", "--", "content_core/data",
        )
        check = _fake_check("fixture script check", command, kind="godot_script")
        context = {"python": "py", "godot": "godot"}
        inputs = vi.check_inputs(check, self.project, context)
        self.assertIn("content_core/a.gd", inputs.files)
        self.assertIn("content_core/data/x.json", inputs.files)

    def test_check_inputs_marks_external_only_when_command_requires_it(self) -> None:
        elfimage = Path(self._temp.name) / "ELFIMAGE"
        elfimage.mkdir()
        mes_arc = elfimage / "mes.arc"
        mes_arc.write_bytes(b"fixture-mes-arc-bytes")

        context = {
            "python": "py", "godot": "godot",
            "source_root": str(elfimage), "mes_arc": str(mes_arc),
            "mmo_arc": str(elfimage / "mmo.arc"), "data_arc": str(elfimage / "data.arc"),
            "voice_arc": str(elfimage / "voice.arc"), "se_arc": str(elfimage / "se.arc"),
        }

        requiring = _fake_check(
            "fixture requiring", ("py", "tools/tool_one.py", "--arc", str(mes_arc)),
            requires=("elfimage",), kind="python",
        )
        inputs = vi.check_inputs(requiring, self.project, context)
        self.assertEqual(("mes_arc",), inputs.external)

        not_requiring = _fake_check("fixture not requiring", ("py", "tools/tool_one.py"), kind="python")
        inputs2 = vi.check_inputs(not_requiring, self.project, context)
        self.assertEqual((), inputs2.external)

    def test_check_inputs_hashes_only_the_archive_the_command_names_not_every_present_one(self) -> None:
        """TD-32 part 3c, section 1(d): every archive is present under the
        ELFIMAGE root, but a command naming only `{mes_arc}` hashes `mes.arc`
        alone - not every archive that merely exists on disk (the previous
        rule)."""
        elfimage = Path(self._temp.name) / "ELFIMAGE_FULL"
        elfimage.mkdir()
        for stem in _ARCHIVE_STEMS:
            (elfimage / f"{stem}.arc").write_bytes(b"fixture-" + stem.encode())
        context = _archive_context(elfimage)
        mes_only = _fake_check(
            "fixture mes only", ("py", "tools/tool_one.py", str(elfimage / "mes.arc")),
            requires=("elfimage",), kind="python",
        )
        self.assertEqual(("mes_arc",), vi.check_inputs(mes_only, self.project, context).external)

        directory_scan = _fake_check(
            "fixture directory scan", ("py", "tools/tool_one.py", str(elfimage)),
            requires=("elfimage",), kind="python",
        )
        self.assertEqual(
            ("bgm_arc", "data_arc", "mes_arc", "mmo_arc", "se_arc", "tina1_arc", "tina2_arc", "voice_arc"),
            vi.check_inputs(directory_scan, self.project, context).external,
        )

    def test_check_inputs_source_root_check_includes_the_bgm_and_tina_archives(self) -> None:
        """TD-53: a `{source_root}` check's input set holds all eight archives,
        the three the cache did not fingerprint (`bgm.arc`, `tina1.arc`,
        `tina2.arc`) among them, each resolved to its own file."""
        elfimage = Path(self._temp.name) / "ELFIMAGE_EIGHT"
        elfimage.mkdir()
        for stem in _ARCHIVE_STEMS:
            (elfimage / f"{stem}.arc").write_bytes(b"fixture-" + stem.encode())
        context = _archive_context(elfimage)
        check = _fake_check(
            "fixture source root", ("py", "tools/tool_one.py", str(elfimage)),
            requires=("elfimage",), kind="python",
        )
        inputs = vi.check_inputs(check, self.project, context)
        self.assertEqual(sorted(f"{stem}_arc" for stem in _ARCHIVE_STEMS), list(inputs.external))
        self.assertEqual(8, len(inputs.external))
        for name in ("bgm_arc", "tina1_arc", "tina2_arc"):
            self.assertIn(name, vi._ARCHIVE_CONTEXT_NAMES)
            self.assertEqual(elfimage / f"{name[:-4]}.arc", inputs.external_paths[name])

    def test_check_inputs_skips_an_optional_archive_the_elfimage_root_lacks(self) -> None:
        """TD-53: the three archives are optional like `voice.arc`/`se.arc` - a
        root without them plans and fingerprints, listing only what exists."""
        elfimage = Path(self._temp.name) / "ELFIMAGE_NO_MEDIA"
        elfimage.mkdir()
        for stem in ("mes", "mmo", "data"):
            (elfimage / f"{stem}.arc").write_bytes(b"fixture-" + stem.encode())
        context = _archive_context(elfimage)
        check = _fake_check(
            "fixture source root", ("py", "tools/tool_one.py", str(elfimage)),
            requires=("elfimage",), kind="python",
        )
        inputs = vi.check_inputs(check, self.project, context)
        self.assertEqual(("data_arc", "mes_arc", "mmo_arc"), inputs.external)
        self.assertNotIn("bgm_arc", inputs.external_paths)

    def test_check_inputs_python_kind_includes_remaining_existing_path_arguments(self) -> None:
        """TD-32 part 3c, section 1(a): a `python`-kind check's start set
        also includes every remaining command argument that resolves to an
        existing project path, matching the `godot_script` branch."""
        check = _fake_check(
            "fixture python with extra path",
            ("py", "tools/tool_one.py", "--check", "content_core/data/x.json"),
            kind="python",
        )
        context = {"python": "py", "godot": "godot"}
        inputs = vi.check_inputs(check, self.project, context)
        self.assertIn("content_core/data/x.json", inputs.files)


class FingerprintTests(unittest.TestCase):
    def setUp(self) -> None:
        self._temp = tempfile.TemporaryDirectory()
        self.addCleanup(self._temp.cleanup)
        self.project = Path(self._temp.name)
        _write(self.project / "project.godot", "[application]\n")
        _write(self.project / "content_core" / "content_core_version.gd", 'const CORE_VERSION := "0.1.0"\n')
        _write(self.project / "tools" / "content_suite" / "run_headless_validation.py", "# fixture\n")
        _write(self.project / "tools" / "content_suite" / "validation_inputs.py", "# fixture\n")
        _write(self.project / "config" / "validation" / "checks_v1.json", "{}\n")
        _write(self.project / "tools" / "fixture_script.py", "x = 1\n")

    def _inputs(self) -> vi.Inputs:
        check = _fake_check("fixture", ("py", "tools/fixture_script.py"), kind="python")
        context = {"python": "py", "godot": "godot"}
        return vi.check_inputs(check, self.project, context)

    def test_fingerprint_is_stable_across_two_computations(self) -> None:
        inputs = self._inputs()
        first = vi.fingerprint(inputs, "0.1.0", "py tools/fixture_script.py")
        second = vi.fingerprint(inputs, "0.1.0", "py tools/fixture_script.py")
        self.assertEqual(first, second)

    def test_fingerprint_changes_when_a_file_byte_changes(self) -> None:
        inputs = self._inputs()
        before = vi.fingerprint(inputs, "0.1.0", "py tools/fixture_script.py")
        (self.project / "tools" / "fixture_script.py").write_text("x = 2\n", encoding="utf-8")
        after = vi.fingerprint(inputs, "0.1.0", "py tools/fixture_script.py")
        self.assertNotEqual(before, after)

    def test_fingerprint_changes_when_core_version_changes(self) -> None:
        inputs = self._inputs()
        one = vi.fingerprint(inputs, "0.1.0", "py tools/fixture_script.py")
        two = vi.fingerprint(inputs, "0.2.0", "py tools/fixture_script.py")
        self.assertNotEqual(one, two)

    def test_fingerprint_changes_when_command_changes(self) -> None:
        inputs = self._inputs()
        one = vi.fingerprint(inputs, "0.1.0", "py tools/fixture_script.py")
        two = vi.fingerprint(inputs, "0.1.0", "py tools/fixture_script.py --flag")
        self.assertNotEqual(one, two)

    def test_fingerprint_ignores_elfimage_root_path_when_archive_bytes_match(self) -> None:
        first_root = Path(self._temp.name) / "ELFIMAGE_ONE"
        second_root = Path(self._temp.name) / "ELFIMAGE_TWO"
        first_root.mkdir()
        second_root.mkdir()
        (first_root / "mes.arc").write_bytes(b"identical-bytes")
        (second_root / "mes.arc").write_bytes(b"identical-bytes")

        context_one = {
            "python": "py", "godot": "godot", "source_root": str(first_root),
            "mes_arc": str(first_root / "mes.arc"),
        }
        context_two = {
            "python": "py", "godot": "godot", "source_root": str(second_root),
            "mes_arc": str(second_root / "mes.arc"),
        }
        command_one = ("py", "tools/fixture_script.py", "--arc", str(first_root / "mes.arc"))
        command_two = ("py", "tools/fixture_script.py", "--arc", str(second_root / "mes.arc"))
        check_one = _fake_check("fixture", command_one, requires=("elfimage",), kind="python")
        check_two = _fake_check("fixture", command_two, requires=("elfimage",), kind="python")
        inputs_one = vi.check_inputs(check_one, self.project, context_one)
        inputs_two = vi.check_inputs(check_two, self.project, context_two)
        self.assertEqual(("mes_arc",), inputs_one.external)
        self.assertEqual(("mes_arc",), inputs_two.external)

        text_one = vi.normalize_command(command_one, context_one)
        text_two = vi.normalize_command(command_two, context_two)
        self.assertEqual(text_one, text_two)

        digest_one = vi.fingerprint(inputs_one, "0.1.0", text_one)
        digest_two = vi.fingerprint(inputs_two, "0.1.0", text_two)
        self.assertEqual(digest_one, digest_two)

    def test_fingerprint_changes_when_the_bgm_or_a_tina_archive_changes(self) -> None:
        """TD-53: a change of `bgm.arc`, `tina1.arc` or `tina2.arc` moves the
        fingerprint of a `{source_root}` check - and only that archive's change
        is needed to move it."""
        elfimage = Path(self._temp.name) / "ELFIMAGE_FP"
        elfimage.mkdir()
        for stem in _ARCHIVE_STEMS:
            (elfimage / f"{stem}.arc").write_bytes(b"fixture-" + stem.encode())
        context = _archive_context(elfimage)
        check = _fake_check(
            "fixture source root", ("py", "tools/fixture_script.py", str(elfimage)),
            requires=("elfimage",), kind="python",
        )
        inputs = vi.check_inputs(check, self.project, context)
        command = vi.normalize_command(check.command, context)
        baseline = vi.fingerprint(inputs, "0.1.0", command)
        self.assertEqual(baseline, vi.fingerprint(inputs, "0.1.0", command))
        for stem in ("bgm", "tina1", "tina2"):
            path = elfimage / f"{stem}.arc"
            original = path.read_bytes()
            with self.subTest(archive=f"{stem}.arc"):
                path.write_bytes(original + b"!")
                changed = vi.fingerprint(inputs, "0.1.0", command)
                self.assertNotEqual(baseline, changed)
                path.write_bytes(original)
                self.assertEqual(baseline, vi.fingerprint(inputs, "0.1.0", command))

    def test_fingerprint_changes_when_an_absent_optional_archive_appears(self) -> None:
        """TD-53: a root lacking `bgm.arc` fingerprints without it, and the
        archive appearing later is a different input set - an absent archive
        is never a silent "same"."""
        elfimage = Path(self._temp.name) / "ELFIMAGE_LATE"
        elfimage.mkdir()
        for stem in ("mes", "mmo", "data"):
            (elfimage / f"{stem}.arc").write_bytes(b"fixture-" + stem.encode())
        context = _archive_context(elfimage)
        check = _fake_check(
            "fixture source root", ("py", "tools/fixture_script.py", str(elfimage)),
            requires=("elfimage",), kind="python",
        )
        command = vi.normalize_command(check.command, context)
        before = vi.fingerprint(vi.check_inputs(check, self.project, context), "0.1.0", command)
        (elfimage / "bgm.arc").write_bytes(b"fixture-bgm")
        after_inputs = vi.check_inputs(check, self.project, context)
        self.assertIn("bgm_arc", after_inputs.external)
        self.assertNotEqual(before, vi.fingerprint(after_inputs, "0.1.0", command))

    def test_project_root_is_normalised_in_both_slash_forms(self) -> None:
        # TD-33 follow-up: a whole batch run on a detached worktree must key
        # its green results the way the main checkout does.
        main = {"python": "py", "godot": "godot", "project": r"C:\project\kakyu-mod-tools"}
        worktree = {"python": "py", "godot": "godot", "project": r"C:\scratch\wt_full4"}
        command_main = ("godot", "--headless", "--path", r"C:\project\kakyu-mod-tools", "--script", "res://x.gd")
        command_worktree = ("godot", "--headless", "--path", r"C:\scratch\wt_full4", "--script", "res://x.gd")
        self.assertEqual(vi.normalize_command(command_main, main), vi.normalize_command(command_worktree, worktree))
        forward = ("godot", "--path", "C:/project/kakyu-mod-tools/tests", "--script", "res://x.gd")
        self.assertIn("<PROJECT>/tests", vi.normalize_command(forward, main))
        self.assertNotIn("kakyu-mod-tools", vi.normalize_command(forward, main))


if __name__ == "__main__":
    unittest.main()
