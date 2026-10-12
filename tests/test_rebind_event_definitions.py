"""WD-21 U2 C6: `tools/rebind_event_definitions.py` - the definition set rebound to a re-exported package.
TD-57 C3 adds the Core-version pair (`--pair core-version`).

Synthetic sets and manifests only. The documents are written the way the projectors write them
(`json.dump(..., indent=2, ensure_ascii=False)` and a final LF, with a non-ASCII title), so the
byte-layout checks mean something. Two tests dry-run the tracked v7 set against a manifest pair
made from the machine-local package it is bound to when it is present.
"""
from __future__ import annotations

import contextlib
import copy
import io
import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

import rebind_event_definitions as rebind  # noqa: E402

OLD = "a" * 8 + "1" * 56
NEW = "b" * 8 + "2" * 56
THIRD = "c" * 8 + "3" * 56
PACKAGE_SCHEMA = "kakyu_playback_package/v7"
IDS = ["x.town.a.1.1", "y.town.b.2.1", "z.date.c.3.1"]


def manifest(package_sha256, revision):
    return {
        "schema": PACKAGE_SCHEMA,
        "content_core_version": "0.373.0",
        "source": {"archive": "mes.arc", "archive_sha256": "d" * 64, "catalog_id": "cat", "catalog_revision": revision},
        "entries": [{"entry": "A.MES", "entry_sha256": "e" * 64}, {"entry": "B.MES", "entry_sha256": "f" * 64}],
        "media_inventory": {"schema": "kakyu_media_inventory/v1", "members": [{"entry": "A.MES", "occurrences": [{"at": 1, "kind": "voice", "name": "V.OGG"}]}]},
        "files": [{"name": "events/A.json", "size": 5, "sha256": "0" * 64}],
        "package_sha256": package_sha256,
    }


def write_json(path, value):
    with open(path, "w", encoding="utf-8", newline="\n") as fh:
        json.dump(value, fh, indent=2, ensure_ascii=False)
        fh.write("\n")


def document(doc_id, schema="kakyu_event_definition/v7", package_sha256=OLD):
    return {
        "schema_version": schema, "contract_fingerprint": "self", "id": doc_id,
        "display": {"title_ko": "한글 제목", "title_en": "English"},
        "package_binding": {"schema": PACKAGE_SCHEMA, "package_sha256": package_sha256},
        "presentation": {"status": "deferred", "resources": [{"entry": "A.MES", "source_offset": 1, "kind": "voice", "name": "V.OGG"}]},
    }


def index_of(ids, package_sha256=OLD, ok=None):
    ok = set(ids) if ok is None else ok
    return {
        "schema": "kakyu_event_definition_index/v2", "contract_fingerprint": "self", "package_sha256": package_sha256,
        "documents": [{"id": doc_id, "ok": doc_id in ok} for doc_id in ids],
        "summary": {"projected": len(ids), "valid": len(ok), "invalid": len(ids) - len(ok)},
    }


class World:
    def __init__(self, root, schema="kakyu_event_definition/v7"):
        root = Path(root)
        self.defs, self.old, self.new = root / "defs", root / "old", root / "new"
        for directory in (self.defs, self.old, self.new):
            directory.mkdir()
        write_json(self.old / "manifest.json", manifest(OLD, 40))
        write_json(self.new / "manifest.json", manifest(NEW, 41))
        for doc_id in IDS:
            write_json(self.defs / ("%s.json" % doc_id), document(doc_id, schema))
        write_json(self.defs / "index.json", index_of(IDS))
        (self.defs / "README.md").write_text("bound to %s\n" % OLD, encoding="utf-8")

    def snapshot(self):
        return {path.name: path.read_bytes() for path in sorted(self.defs.iterdir())}

    def run(self, *extra):
        stdout = io.StringIO()
        with contextlib.redirect_stdout(stdout):
            code = rebind.main([str(self.defs), "--from-package", str(self.old), "--to-package", str(self.new), *extra])
        return code, json.loads(stdout.getvalue())

    def set_manifest(self, which, change):
        path = (self.old if which == "old" else self.new) / "manifest.json"
        value = json.loads(path.read_text(encoding="utf-8"))
        change(value)
        write_json(path, value)

    def make_core_pair(self):
        """The two manifests as a re-export under another Core makes them: one catalog revision, the
        Core version and the package hash the only differences."""
        self.set_manifest("old", lambda m: m["source"].update(catalog_revision=41))
        self.set_manifest("new", lambda m: m.update(content_core_version="0.374.0"))


class RebindTests(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.world = World(self._tmp.name)

    def refused(self, text, *extra):
        before = self.world.snapshot()
        code, summary = self.world.run(*extra)
        self.assertEqual(code, 1, summary)
        self.assertFalse(summary["ok"])
        self.assertIn(text, summary["reason"])
        self.assertEqual(self.world.snapshot(), before, "a refused rebind wrote something")
        self.assertEqual([p.name for p in self.world.defs.iterdir() if p.name.endswith(".rebind-tmp")], [])

    def test_an_equal_pair_rebinds_every_document_and_the_index(self) -> None:
        before = self.world.snapshot()
        code, summary = self.world.run()
        self.assertEqual(code, 0, summary)
        self.assertEqual(summary, {
            "ok": True, "dry_run": False, "contract": "kakyu_event_definition/v7", "documents": 3, "index": 1,
            "from": OLD, "to": NEW, "differing_manifest_fields": ["package_sha256", "source.catalog_revision"],
            "catalog_revision": [40, 41],
        })
        after = self.world.snapshot()
        self.assertEqual(sorted(after), sorted(before))
        for doc_id in IDS:
            value = json.loads(after["%s.json" % doc_id].decode("utf-8"))
            self.assertEqual(value["package_binding"]["package_sha256"], NEW)
        self.assertEqual(json.loads(after["index.json"].decode("utf-8"))["package_sha256"], NEW)
        self.assertEqual(after["README.md"], before["README.md"], "only .json files are rebound")

    def test_the_byte_layout_is_preserved_apart_from_the_hash(self) -> None:
        before = self.world.snapshot()
        self.world.run()
        after = self.world.snapshot()
        for name in [f"{doc_id}.json" for doc_id in IDS] + ["index.json"]:
            self.assertEqual(after[name].replace(NEW.encode(), OLD.encode()), before[name], name)
            self.assertEqual(len(after[name]), len(before[name]))
            self.assertNotIn(b"\r", after[name])
            self.assertTrue(after[name].endswith(b"}\n"))
        self.assertIn("한글 제목".encode("utf-8"), after[f"{IDS[0]}.json"])

    def test_the_written_files_are_what_the_projector_would_write(self) -> None:
        self.world.run()
        for doc_id in IDS:
            path = self.world.defs / ("%s.json" % doc_id)
            expected = io.StringIO()
            json.dump(document(doc_id, package_sha256=NEW), expected, indent=2, ensure_ascii=False)
            self.assertEqual(path.read_bytes(), (expected.getvalue() + "\n").encode("utf-8"))

    def test_v6_sets_are_accepted_too(self) -> None:
        world = World(tempfile.mkdtemp(dir=self._tmp.name), schema="kakyu_event_definition/v6")
        code, summary = world.run()
        self.assertEqual((code, summary["contract"], summary["documents"]), (0, "kakyu_event_definition/v6", 3))

    def test_a_dry_run_checks_and_writes_nothing(self) -> None:
        before = self.world.snapshot()
        code, summary = self.world.run("--dry-run")
        self.assertEqual((code, summary["dry_run"], summary["documents"], summary["index"]), (0, True, 3, 1))
        self.assertEqual(self.world.snapshot(), before)

    def test_a_second_run_is_refused_because_the_set_is_bound_to_the_new_hash(self) -> None:
        self.world.run()
        self.refused("not to the old package")

    # ----- the manifest pair

    def test_a_pair_that_differs_in_another_field_is_refused(self) -> None:
        cases = {
            "content_core_version": lambda m: m.update(content_core_version="0.374.0"),
            "entries[1].entry_sha256": lambda m: m["entries"][1].update(entry_sha256="9" * 64),
            "media_inventory.members[0].occurrences[0].name": lambda m: m["media_inventory"]["members"][0]["occurrences"][0].update(name="W.OGG"),
            "files": lambda m: m["files"].append({"name": "events/B.json", "size": 1, "sha256": "1" * 64}),
            "source.archive_sha256": lambda m: m["source"].update(archive_sha256="8" * 64),
            "source.catalog_id": lambda m: m["source"].update(catalog_id="other"),
            "extra": lambda m: m.update(extra=1),
        }
        for path, change in cases.items():
            with self.subTest(path):
                world = World(tempfile.mkdtemp(dir=self._tmp.name))
                world.set_manifest("new", change)
                before = world.snapshot()
                code, summary = world.run()
                self.assertEqual(code, 1)
                self.assertIn("differ outside package_sha256 and source.catalog_revision", summary["reason"])
                self.assertIn(path, summary["reason"])
                self.assertEqual(world.snapshot(), before)

    def test_the_differing_paths_are_named(self) -> None:
        self.world.set_manifest("new", lambda m: m["entries"][1].update(entry_sha256="9" * 64))
        self.refused("entries[1].entry_sha256")

    def test_a_pair_with_one_hash_is_refused(self) -> None:
        self.world.set_manifest("new", lambda m: m.update(package_sha256=OLD))
        self.refused("nothing to rebind")

    def test_a_pair_that_differs_in_the_hash_alone_is_refused(self) -> None:
        self.world.set_manifest("new", lambda m: m["source"].update(catalog_revision=40))
        self.refused("not a catalog-revision pair")

    def test_a_manifest_without_a_hash_or_revision_or_schema(self) -> None:
        for which, change, text in (
            ("new", lambda m: m.pop("package_sha256"), "no package_sha256"),
            ("old", lambda m: m.update(package_sha256="nope"), "no package_sha256"),
            ("new", lambda m: m["source"].pop("catalog_revision"), "source.catalog_revision"),
            ("old", lambda m: m["source"].update(catalog_revision="40"), "source.catalog_revision"),
            ("new", lambda m: m.update(schema="kakyu_playback_package/v8"), "one package schema"),
        ):
            with self.subTest(text, which=which):
                world = World(tempfile.mkdtemp(dir=self._tmp.name))
                world.set_manifest(which, change)
                code, summary = world.run()
                self.assertEqual(code, 1)
                self.assertIn(text, summary["reason"])

    def test_a_missing_or_unreadable_manifest(self) -> None:
        (self.world.new / "manifest.json").unlink()
        self.refused("is not a file")
        (self.world.new / "manifest.json").write_text("[", encoding="utf-8")
        self.refused("could not be read")
        (self.world.new / "manifest.json").write_text("[]", encoding="utf-8")
        self.refused("not a JSON object")

    # ----- the Core-version pair (TD-57 D5)

    def test_a_core_pair_rebinds_every_document_and_the_index_and_preserves_their_bytes(self) -> None:
        self.world.make_core_pair()
        before = self.world.snapshot()
        code, summary = self.world.run("--pair", "core-version")
        self.assertEqual(code, 0, summary)
        self.assertEqual(summary, {
            "ok": True, "dry_run": False, "contract": "kakyu_event_definition/v7", "documents": 3, "index": 1,
            "from": OLD, "to": NEW, "differing_manifest_fields": ["package_sha256", "content_core_version"],
            "content_core_version": ["0.373.0", "0.374.0"],
        })
        self.assertNotIn("catalog_revision", summary)
        after = self.world.snapshot()
        self.assertEqual(sorted(after), sorted(before))
        for name in [f"{doc_id}.json" for doc_id in IDS] + ["index.json"]:
            self.assertEqual(after[name].replace(NEW.encode(), OLD.encode()), before[name], name)
            self.assertEqual(len(after[name]), len(before[name]))
        for doc_id in IDS:
            expected = io.StringIO()
            json.dump(document(doc_id, package_sha256=NEW), expected, indent=2, ensure_ascii=False)
            self.assertEqual(after["%s.json" % doc_id], (expected.getvalue() + "\n").encode("utf-8"))
        self.assertEqual(json.loads(after["index.json"].decode("utf-8"))["package_sha256"], NEW)
        self.assertEqual(after["README.md"], before["README.md"], "only .json files are rebound")

    def test_a_core_pair_dry_run_checks_and_writes_nothing(self) -> None:
        self.world.make_core_pair()
        before = self.world.snapshot()
        code, summary = self.world.run("--pair", "core-version", "--dry-run")
        self.assertEqual((code, summary["dry_run"], summary["documents"], summary["content_core_version"]),
                         (0, True, 3, ["0.373.0", "0.374.0"]))
        self.assertEqual(self.world.snapshot(), before)

    def test_a_core_pair_that_also_differs_elsewhere_is_refused(self) -> None:
        cases = {
            "entries[1].entry_sha256": lambda m: m["entries"][1].update(entry_sha256="9" * 64),
            "media_inventory.members[0].occurrences[0].name": lambda m: m["media_inventory"]["members"][0]["occurrences"][0].update(name="W.OGG"),
            "files": lambda m: m["files"].append({"name": "events/B.json", "size": 1, "sha256": "1" * 64}),
            "source.archive_sha256": lambda m: m["source"].update(archive_sha256="8" * 64),
            # Only the top-level `content_core_version` is the pair's field: a nested one that differs is a
            # difference elsewhere.
            "source.content_core_version": lambda m: m["source"].update(content_core_version="0.374.0"),
            "extra": lambda m: m.update(extra=1),
        }
        for path, change in cases.items():
            with self.subTest(path):
                world = World(tempfile.mkdtemp(dir=self._tmp.name))
                world.make_core_pair()
                world.set_manifest("new", change)
                before = world.snapshot()
                code, summary = world.run("--pair", "core-version")
                self.assertEqual(code, 1)
                self.assertIn("differ outside package_sha256 and content_core_version", summary["reason"])
                self.assertNotIn("source.catalog_revision", summary["reason"])
                self.assertIn(path, summary["reason"])
                self.assertEqual(world.snapshot(), before)

    def test_a_core_only_difference_without_the_flag_is_refused_and_points_at_the_flag(self) -> None:
        self.world.make_core_pair()
        self.refused("differ outside package_sha256 and source.catalog_revision")
        self.refused("content_core_version")
        self.refused("--pair core-version")
        self.refused("--pair core-version", "--pair", "catalog-revision")

    def test_the_flag_hint_is_withheld_when_the_pair_mixes_both_differences(self) -> None:
        self.world.set_manifest("new", lambda m: m.update(content_core_version="0.374.0"))
        code, summary = self.world.run()
        self.assertEqual(code, 1)
        self.assertIn("content_core_version", summary["reason"])
        self.assertNotIn("--pair core-version", summary["reason"])

    def test_equal_core_versions_under_the_flag_are_refused(self) -> None:
        self.world.make_core_pair()
        self.world.set_manifest("new", lambda m: m.update(content_core_version="0.373.0"))
        self.refused("same content_core_version (0.373.0)", "--pair", "core-version")
        self.refused("not a Core-version pair", "--pair", "core-version")

    def test_a_catalog_revision_difference_under_the_core_flag_is_refused(self) -> None:
        # The default fixture differs in the catalog revision alone: the other pair.
        self.refused("differ in source.catalog_revision (40, 41)", "--pair", "core-version")
        # Mixed with a Core difference: one reason, the catalog revision, not a second one.
        self.world.set_manifest("new", lambda m: m.update(content_core_version="0.374.0"))
        code, summary = self.world.run("--pair", "core-version")
        self.assertEqual(code, 1)
        self.assertIn("differ in source.catalog_revision (40, 41)", summary["reason"])
        self.assertIn("never mixed", summary["reason"])
        self.assertNotIn("differ outside", summary["reason"])

    def test_a_manifest_without_a_core_version_string_is_refused_under_the_core_flag(self) -> None:
        for which in ("old", "new"):
            for label, change in (
                ("missing", lambda m: m.pop("content_core_version")),
                ("empty", lambda m: m.update(content_core_version="")),
                ("not a string", lambda m: m.update(content_core_version=374)),
            ):
                with self.subTest(label, which=which):
                    world = World(tempfile.mkdtemp(dir=self._tmp.name))
                    world.make_core_pair()
                    world.set_manifest(which, change)
                    before = world.snapshot()
                    code, summary = world.run("--pair", "core-version")
                    self.assertEqual(code, 1)
                    self.assertIn("the %s manifest has no non-empty content_core_version string" % which, summary["reason"])
                    self.assertEqual(world.snapshot(), before)

    def test_the_core_pair_keeps_the_shared_manifest_checks(self) -> None:
        self.world.make_core_pair()
        self.world.set_manifest("new", lambda m: m.update(package_sha256=OLD))
        self.refused("nothing to rebind", "--pair", "core-version")
        self.world.set_manifest("new", lambda m: m.update(package_sha256=NEW, schema="kakyu_playback_package/v8"))
        self.refused("one package schema", "--pair", "core-version")
        self.world.set_manifest("new", lambda m: m.update(schema=PACKAGE_SCHEMA))
        self.world.set_manifest("new", lambda m: m["source"].pop("catalog_revision"))
        self.refused("source.catalog_revision", "--pair", "core-version")

    def test_a_core_pair_still_stops_on_a_set_bound_to_another_hash(self) -> None:
        self.world.make_core_pair()
        write_json(self.world.defs / ("%s.json" % IDS[1]), document(IDS[1], package_sha256=THIRD))
        self.refused("%s.json: bound to %s" % (IDS[1], THIRD[:8]), "--pair", "core-version")

    def test_an_unknown_pair_is_refused(self) -> None:
        with self.assertRaises(rebind.RebindError):
            rebind.check_manifests(manifest(OLD, 40), manifest(NEW, 41), pair="other")
        with contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit):
            self.world.run("--pair", "other")

    # ----- the set

    def test_a_document_bound_to_a_third_hash_stops_the_whole_rebind(self) -> None:
        write_json(self.world.defs / ("%s.json" % IDS[1]), document(IDS[1], package_sha256=THIRD))
        self.refused("%s.json: bound to %s" % (IDS[1], THIRD[:8]))

    def test_a_document_already_bound_to_the_new_hash_stops_the_whole_rebind(self) -> None:
        write_json(self.world.defs / ("%s.json" % IDS[2]), document(IDS[2], package_sha256=NEW))
        self.refused("not to the old package")

    def test_an_index_bound_to_another_hash(self) -> None:
        write_json(self.world.defs / "index.json", index_of(IDS, package_sha256=THIRD))
        self.refused("index.json: bound to %s" % THIRD[:8])

    def test_an_unknown_or_mixed_contract(self) -> None:
        write_json(self.world.defs / ("%s.json" % IDS[0]), document(IDS[0], schema="kakyu_event_definition/v5"))
        self.refused("not a known contract")
        write_json(self.world.defs / ("%s.json" % IDS[0]), document(IDS[0], schema="kakyu_event_definition/v6"))
        self.refused("mixes contracts")

    def test_a_document_bound_to_another_package_schema(self) -> None:
        value = document(IDS[0])
        value["package_binding"]["schema"] = "kakyu_playback_package/v6"
        write_json(self.world.defs / ("%s.json" % IDS[0]), value)
        self.refused("package_binding does not name the package schema")

    def test_the_index_must_list_exactly_the_documents(self) -> None:
        write_json(self.world.defs / "index.json", index_of(IDS[:2]))
        self.refused("are not the set's documents")
        write_json(self.world.defs / "index.json", index_of(IDS + ["extra.town.d.4.1"]))
        self.refused("are not the set's documents")
        write_json(self.world.defs / "index.json", index_of(IDS, ok=set(IDS[:2])))
        self.refused("are not the set's documents")
        index = index_of(IDS)
        index["schema"] = "kakyu_event_definition_index/v1"
        write_json(self.world.defs / "index.json", index)
        self.refused("index.json: schema")

    def test_a_missing_index_a_resolved_twin_or_an_empty_set(self) -> None:
        (self.world.defs / "index.json").unlink()
        self.refused("has no index.json")
        write_json(self.world.defs / "index.json", index_of(IDS))
        write_json(self.world.defs / ("%s.resolved.json" % IDS[0]), document(IDS[0]))
        self.refused("resolved twin")
        (self.world.defs / ("%s.resolved.json" % IDS[0])).unlink()
        for doc_id in IDS:
            (self.world.defs / ("%s.json" % doc_id)).unlink()
        write_json(self.world.defs / "index.json", index_of([]))
        self.refused("has no document")
        self.assertEqual(self.world.run()[0], 1)

    def test_a_directory_that_is_not_one(self) -> None:
        stdout = io.StringIO()
        with contextlib.redirect_stdout(stdout):
            code = rebind.main([str(self.world.defs / "nope"), "--from-package", str(self.world.old), "--to-package", str(self.world.new)])
        self.assertEqual(code, 1)
        self.assertIn("is not a directory", json.loads(stdout.getvalue())["reason"])

    def test_the_hash_must_occur_exactly_once_in_a_file(self) -> None:
        path = self.world.defs / ("%s.json" % IDS[0])
        value = document(IDS[0])
        value["display"]["title_en"] = "mentions %s" % OLD
        write_json(path, value)
        self.refused("occurs 2 times")
        value = document(IDS[0])
        value["display"]["title_en"] = "mentions %s" % NEW
        write_json(path, value)
        self.refused("already mentions the new hash")

    def test_an_unparseable_document(self) -> None:
        (self.world.defs / ("%s.json" % IDS[0])).write_text("{", encoding="utf-8")
        self.refused("not JSON")
        (self.world.defs / ("%s.json" % IDS[0])).write_text("[]", encoding="utf-8")
        self.refused("not an object")

    def test_a_document_whose_id_differs_from_its_file_name(self) -> None:
        write_json(self.world.defs / ("%s.json" % IDS[0]), document("other.town.a.1.1"))
        self.refused("differs from the file name")

    def test_a_failure_while_writing_the_new_contents_leaves_the_set_as_it_was(self) -> None:
        before = self.world.snapshot()
        original = Path.write_bytes
        calls = []

        def failing(path, data):
            calls.append(path)
            if len(calls) == 3:
                raise OSError("disk full")
            return original(path, data)

        with mock.patch.object(Path, "write_bytes", failing), self.assertRaises(OSError):
            rebind.rebind(self.world.defs, self.world.old, self.world.new)
        self.assertEqual(self.world.snapshot(), before)

    def test_a_failure_in_the_replace_phase_removes_the_leftovers(self) -> None:
        # Every temporary file is written; the first replace happens, the second fails. The temporaries not yet
        # moved are removed. A replace that already happened cannot be undone, and the failure is reported.
        before = self.world.snapshot()
        original = rebind.os.replace
        calls = []

        def failing(source, target):
            calls.append(target)
            if len(calls) == 2:
                raise OSError("busy")
            return original(source, target)

        with mock.patch.object(rebind.os, "replace", failing), self.assertRaises(OSError):
            rebind.rebind(self.world.defs, self.world.old, self.world.new)
        self.assertEqual([p.name for p in self.world.defs.iterdir() if p.name.endswith(".rebind-tmp")], [])
        self.assertEqual(sum(1 for name, content in self.world.snapshot().items() if content != before[name]), 1)


class DifferingPathsTests(unittest.TestCase):
    def test_paths_into_dicts_and_lists(self) -> None:
        a = {"x": {"y": [1, 2, {"z": 1}]}, "k": 1, "only_a": 1}
        b = {"x": {"y": [1, 3, {"z": 2}]}, "k": 1, "only_b": 1}
        self.assertEqual(rebind.differing_paths(a, b), ["only_a", "only_b", "x.y[1]", "x.y[2].z"])

    def test_a_list_of_another_length_is_one_path_and_the_limit_holds(self) -> None:
        self.assertEqual(rebind.differing_paths({"l": [1]}, {"l": [1, 2]}), ["l"])
        many = {str(i): 0 for i in range(40)}
        self.assertEqual(len(rebind.differing_paths(many, {k: 1 for k in many})), rebind.DIFFERENCE_LIMIT)

    def test_equal_values_differ_nowhere(self) -> None:
        self.assertEqual(rebind.differing_paths({"a": [1, {"b": None}]}, {"a": [1, {"b": None}]}), [])


class TrackedSetTests(unittest.TestCase):
    """The tracked v7 set against a manifest pair made from whichever machine-local WD-21 package it is bound
    to (the U1 export before the C6 rebind, the U2 export after it, the TD-57 export after its Core-pair
    rebind, the TD-64 export after its own, the TD-64 part 2 export after its own, the TD-56 export B after
    the catalog-revision rebind that followed the re-projection against export A); skipped when none is
    present."""

    PACKAGES = (
        ROOT / "analysis" / "playback_package_td56b",
        ROOT / "analysis" / "playback_package_td56a",
        ROOT / "analysis" / "playback_package_td64p2",
        ROOT / "analysis" / "playback_package_td64",
        ROOT / "analysis" / "playback_package_td57",
        ROOT / "analysis" / "playback_package_wd21_u2",
        ROOT / "analysis" / "playback_package_wd21_u1",
    )
    SET = ROOT / "config" / "event_definitions" / "v7"

    def bound_package(self):
        """`(package directory, its manifest)` for the package the tracked set is bound to, or a skip."""
        bound = json.loads((self.SET / "index.json").read_text(encoding="utf-8"))["package_sha256"]
        for package in self.PACKAGES:
            path = package / "manifest.json"
            if path.is_file():
                old = json.loads(path.read_text(encoding="utf-8"))
                if old.get("package_sha256") == bound:
                    return package, old
        self.skipTest("the machine-local package the tracked set is bound to is absent")

    def dry_run_against(self, package, new, **options):
        with tempfile.TemporaryDirectory() as tmp:
            (Path(tmp) / "new").mkdir()
            write_json(Path(tmp) / "new" / "manifest.json", new)
            before = {p.name: p.read_bytes() for p in self.SET.glob("*.json")}
            summary = rebind.rebind(self.SET, package, Path(tmp) / "new", dry_run=True, **options)
            self.assertEqual({p.name: p.read_bytes() for p in self.SET.glob("*.json")}, before)
        self.assertEqual((summary["documents"], summary["index"], summary["contract"]), (681, 1, "kakyu_event_definition/v7"))
        return summary

    def test_the_tracked_v7_set_dry_runs_against_a_revised_copy_of_its_package_manifest(self) -> None:
        package, old = self.bound_package()
        new = copy.deepcopy(old)
        new["source"]["catalog_revision"] += 1
        new["package_sha256"] = "9" * 64
        self.dry_run_against(package, new)

    def test_the_tracked_v7_set_dry_runs_against_a_core_revised_copy_of_its_package_manifest(self) -> None:
        package, old = self.bound_package()
        new = copy.deepcopy(old)
        new["content_core_version"] = old["content_core_version"] + "-next"
        new["package_sha256"] = "9" * 64
        summary = self.dry_run_against(package, new, pair="core-version")
        self.assertEqual(summary["content_core_version"], [old["content_core_version"], new["content_core_version"]])


if __name__ == "__main__":
    unittest.main()
