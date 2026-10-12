"""The known-absent media register writer (WD-21 U1 C3, D7): a full package's
`shipped: false` rows become the register, and anything that is not a full
original package is refused."""
from __future__ import annotations

import copy
import io
import json
import sys
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

import build_known_absent_media as writer  # noqa: E402
from payload_values import fingerprint  # noqa: E402

SHA = {name: character * 64 for name, character in (
    ("mmo.arc", "1"), ("data.arc", "2"), ("bgm.arc", "3"), ("se.arc", "4"),
    ("voice.arc", "5"), ("tina1.arc", "6"), ("tina2.arc", "7"),
)}


def manifest() -> dict:
    """A small full-export manifest: two shipped rows, one absent row of each of
    three kinds (one with a two-archive search list given out of order)."""
    return {
        "schema": "kakyu_playback_package/v7",
        "membership": {
            "rule": writer.MEMBERSHIP_RULE_FULL,
            "catalog_events": 2,
            "catalog_members": 1,
            "analysis_group_members": 1,
            "analysis_groups": [{"profile": "p", "group_id": "g", "schema": "s", "payload_sha256": "a" * 64}],
        },
        "media_inventory": {
            "schema": writer.INVENTORY_SCHEMA,
            "normalization": "upper_case",
            "archives": dict(SHA),
            "names": [
                {"kind": "mmo", "name": "PRESENT.MMO", "shipped": True,
                 "rows": [{"archive": "mmo.arc", "entry": "PRESENT.MMO", "size": 1, "entry_sha256": "b" * 64}]},
                {"kind": "mmo", "name": "ZZZ.MMO", "shipped": False, "searched": ["mmo.arc"]},
                {"kind": "ax", "name": "B02Z.AX", "shipped": False, "searched": ["data.arc"]},
                {"kind": "unclassified", "name": "BOALING.WAV", "shipped": False, "searched": ["se.arc", "bgm.arc"]},
                {"kind": "voice", "name": "M0001.OGG", "shipped": True,
                 "rows": [{"archive": "tina1.arc", "entry": "M0001.OGG", "size": 1, "entry_sha256": "c" * 64}]},
            ],
        },
    }


class BuildRegisterTests(unittest.TestCase):
    def test_positive_rows_header_and_fingerprint(self) -> None:
        register = writer.build_register(manifest())
        self.assertEqual(register["schema"], "kakyu_known_absent_media/v1")
        self.assertEqual(register["inventory_schema"], "kakyu_media_inventory/v1")
        self.assertEqual(register["archives"], SHA)
        self.assertEqual(list(register["archives"]), sorted(SHA))
        # Rows are the absent ones only, sorted by (kind, name); the search list is sorted.
        self.assertEqual(register["rows"], [
            {"kind": "ax", "name": "B02Z.AX", "searched": ["data.arc"]},
            {"kind": "mmo", "name": "ZZZ.MMO", "searched": ["mmo.arc"]},
            {"kind": "unclassified", "name": "BOALING.WAV", "searched": ["bgm.arc", "se.arc"]},
        ])
        self.assertEqual(register["payload_sha256"], fingerprint(register))
        self.assertEqual(writer.counts_by_kind(register), {"ax": 1, "mmo": 1, "unclassified": 1})

    def test_rows_carry_no_evidence(self) -> None:
        for row in writer.build_register(manifest())["rows"]:
            self.assertEqual(set(row), {"kind", "name", "searched"})

    def test_a_full_export_with_no_absent_row_is_an_empty_register(self) -> None:
        document = manifest()
        document["media_inventory"]["names"] = [row for row in document["media_inventory"]["names"] if row["shipped"]]
        self.assertEqual(writer.build_register(document)["rows"], [])

    def test_missing_media_inventory_fails_closed(self) -> None:
        document = manifest()
        del document["media_inventory"]
        with self.assertRaisesRegex(writer.RegisterError, "no media_inventory"):
            writer.build_register(document)

    def test_non_object_media_inventory_fails_closed(self) -> None:
        document = manifest()
        document["media_inventory"] = []
        with self.assertRaisesRegex(writer.RegisterError, "not an object"):
            writer.build_register(document)

    def test_unknown_block_schema_id_fails_closed(self) -> None:
        for schema in ("kakyu_media_inventory/v2", "kakyu_media_inventory/v0", "", None):
            document = manifest()
            document["media_inventory"]["schema"] = schema
            with self.assertRaisesRegex(writer.RegisterError, "this tool only knows that block"):
                writer.build_register(document)

    def test_other_normalization_fails_closed(self) -> None:
        document = manifest()
        document["media_inventory"]["normalization"] = "lower_case"
        with self.assertRaisesRegex(writer.RegisterError, "normalization"):
            writer.build_register(document)

    def test_selected_event_export_fails_closed(self) -> None:
        document = manifest()
        document["membership"]["rule"] = "selected_catalog_events"
        with self.assertRaisesRegex(writer.RegisterError, "selected-event export"):
            writer.build_register(document)

    def test_missing_membership_fails_closed(self) -> None:
        document = manifest()
        del document["membership"]
        with self.assertRaisesRegex(writer.RegisterError, "membership rule"):
            writer.build_register(document)

    def test_export_without_analysis_groups_fails_closed(self) -> None:
        document = manifest()
        document["membership"]["analysis_groups"] = []
        document["membership"]["analysis_group_members"] = 0
        with self.assertRaisesRegex(writer.RegisterError, "no analysis-group members"):
            writer.build_register(document)

    def test_undecided_row_fails_closed(self) -> None:
        document = manifest()
        document["media_inventory"]["names"].append(
            {"kind": "voice", "name": "M0002.OGG", "shipped": None, "unavailable": ["tina2.arc"]}
        )
        with self.assertRaisesRegex(writer.RegisterError, "undecided"):
            writer.build_register(document)

    def test_other_shipped_state_fails_closed(self) -> None:
        document = manifest()
        document["media_inventory"]["names"][1]["shipped"] = "no"
        with self.assertRaisesRegex(writer.RegisterError, "shipped state"):
            writer.build_register(document)

    def test_malformed_header_fails_closed(self) -> None:
        for archives in ({}, [], {"mmo.arc": "nothex"}, {"mmo.arc": "A" * 64}):
            document = manifest()
            document["media_inventory"]["archives"] = archives
            with self.assertRaises(writer.RegisterError, msg=repr(archives)):
                writer.build_register(document)

    def test_searched_archive_without_a_header_hash_fails_closed(self) -> None:
        document = manifest()
        del document["media_inventory"]["archives"]["data.arc"]
        with self.assertRaisesRegex(writer.RegisterError, "data.arc"):
            writer.build_register(document)

    def test_malformed_absent_row_fails_closed(self) -> None:
        mutations = {
            "unknown kind": lambda row: row.update(kind="movie"),
            "lower-case name": lambda row: row.update(name="zzz.mmo"),
            "empty name": lambda row: row.update(name=""),
            "no searched": lambda row: row.pop("searched"),
            "empty searched": lambda row: row.update(searched=[]),
            "duplicate searched": lambda row: row.update(searched=["mmo.arc", "mmo.arc"]),
            "non-string searched": lambda row: row.update(searched=[1]),
        }
        for label, mutate in mutations.items():
            document = manifest()
            mutate(document["media_inventory"]["names"][1])
            with self.assertRaises(writer.RegisterError, msg=label):
                writer.build_register(document)

    def test_duplicate_absent_row_fails_closed(self) -> None:
        document = manifest()
        document["media_inventory"]["names"].append(dict(document["media_inventory"]["names"][1]))
        with self.assertRaisesRegex(writer.RegisterError, "two absent rows"):
            writer.build_register(document)

    def test_names_that_is_not_an_array_fails_closed(self) -> None:
        document = manifest()
        document["media_inventory"]["names"] = {}
        with self.assertRaisesRegex(writer.RegisterError, "names is not an array"):
            writer.build_register(document)

    def test_input_manifest_is_not_modified(self) -> None:
        document = manifest()
        before = copy.deepcopy(document)
        writer.build_register(document)
        self.assertEqual(document, before)


class DeterminismTests(unittest.TestCase):
    def test_row_order_of_the_manifest_does_not_change_the_register(self) -> None:
        first = manifest()
        second = manifest()
        second["media_inventory"]["names"].reverse()
        self.assertEqual(
            writer.serialize(writer.build_register(first)),
            writer.serialize(writer.build_register(second)),
        )

    def test_archive_order_of_the_manifest_does_not_change_the_register(self) -> None:
        first = manifest()
        second = manifest()
        second["media_inventory"]["archives"] = dict(reversed(list(SHA.items())))
        self.assertEqual(
            writer.serialize(writer.build_register(first)),
            writer.serialize(writer.build_register(second)),
        )

    def test_serialization_is_lf_with_one_trailing_newline_and_round_trips(self) -> None:
        register = writer.build_register(manifest())
        payload = writer.serialize(register)
        self.assertNotIn(b"\r", payload)
        self.assertTrue(payload.endswith(b"}\n") and not payload.endswith(b"\n\n"))
        self.assertEqual(json.loads(payload.decode("utf-8")), register)
        self.assertEqual(payload, writer.serialize(writer.build_register(manifest())))

    def test_written_file_has_no_carriage_return(self) -> None:
        register = writer.build_register(manifest())
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "nested" / "register.json"
            writer.write_register(path, register)
            self.assertNotIn(b"\r", path.read_bytes())
            self.assertEqual(json.loads(path.read_text(encoding="utf-8")), register)


class CommandLineTests(unittest.TestCase):
    def _package(self, directory: str, document: dict) -> Path:
        package = Path(directory) / "package"
        package.mkdir()
        (package / "manifest.json").write_text(json.dumps(document), encoding="utf-8")
        return package

    def test_main_writes_the_register_and_prints_counts(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            package = self._package(directory, manifest())
            out = Path(directory) / "register.json"
            stdout = io.StringIO()
            with redirect_stdout(stdout):
                self.assertEqual(writer.main([str(package), "--out", str(out)]), 0)
            report = json.loads(stdout.getvalue())
            self.assertEqual(report["rows"], 3)
            self.assertEqual(report["rows_by_kind"], {"ax": 1, "mmo": 1, "unclassified": 1})
            self.assertEqual(json.loads(out.read_text(encoding="utf-8"))["payload_sha256"], report["payload_sha256"])

    def test_main_returns_one_and_writes_nothing_on_a_refusal(self) -> None:
        document = manifest()
        document["membership"]["rule"] = "selected_catalog_events"
        with tempfile.TemporaryDirectory() as directory:
            package = self._package(directory, document)
            out = Path(directory) / "register.json"
            stderr = io.StringIO()
            with redirect_stderr(stderr):
                self.assertEqual(writer.main([str(package), "--out", str(out)]), 1)
            self.assertIn("FAIL", stderr.getvalue())
            self.assertFalse(out.exists())

    def test_main_refuses_a_directory_without_a_manifest(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            with redirect_stderr(io.StringIO()):
                self.assertEqual(writer.main([directory, "--out", str(Path(directory) / "x.json")]), 1)


if __name__ == "__main__":
    unittest.main()
