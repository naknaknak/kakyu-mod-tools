from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools" / "content_suite"))

import validation_cache as vc  # noqa: E402


class ValidationCacheTests(unittest.TestCase):
    def setUp(self) -> None:
        self._temp = tempfile.TemporaryDirectory()
        self.addCleanup(self._temp.cleanup)
        self.directory = Path(self._temp.name) / "validation_cache"

    def test_store_then_lookup_round_trips_a_passed_result(self) -> None:
        result = {"name": "fixture", "status": "passed", "return_code": 0, "duration_seconds": 1.5}
        vc.store(self.directory, "fixture", "abc123", result, "run-1", "0.359.0")
        entry = vc.lookup(self.directory, "fixture", "abc123")
        self.assertIsNotNone(entry)
        self.assertEqual("fixture", entry["name"])
        self.assertEqual("abc123", entry["fingerprint"])
        self.assertEqual("passed", entry["status"])
        self.assertEqual(1.5, entry["duration_seconds"])
        self.assertEqual("run-1", entry["run_id"])
        self.assertEqual("0.359.0", entry["core_version"])
        self.assertTrue(entry["recorded_at"])
        self.assertEqual(vc.CACHE_ENTRY_SCHEMA, entry["schema"])
        expected_path = self.directory / "ab" / "abc123.json"
        self.assertTrue(expected_path.is_file())

    def test_lookup_misses_when_nothing_was_stored(self) -> None:
        self.assertIsNone(vc.lookup(self.directory, "fixture", "does-not-exist"))

    def test_a_red_result_is_never_stored(self) -> None:
        for status, return_code in (("failed", 1), ("timeout", None), ("error", None)):
            result = {"name": "fixture", "status": status, "return_code": return_code, "duration_seconds": 0.2}
            vc.store(self.directory, "fixture", "red" + status, result, "run-1", "0.359.0")
            self.assertIsNone(vc.lookup(self.directory, "fixture", "red" + status))
        self.assertFalse(self.directory.exists())

    def test_a_passed_result_with_a_nonzero_return_code_is_never_stored(self) -> None:
        # Defensive: a well-formed result never actually looks like this, but
        # store() must not trust "status": "passed" alone.
        result = {"name": "fixture", "status": "passed", "return_code": 1, "duration_seconds": 0.2}
        vc.store(self.directory, "fixture", "oddball", result, "run-1", "0.359.0")
        self.assertIsNone(vc.lookup(self.directory, "fixture", "oddball"))

    def test_a_malformed_entry_file_is_ignored_not_an_error(self) -> None:
        path = self.directory / "de" / "deadbeef.json"
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text("{not json", encoding="utf-8")
        self.assertIsNone(vc.lookup(self.directory, "fixture", "deadbeef"))

        path.write_text(json.dumps({"schema": vc.CACHE_ENTRY_SCHEMA, "name": "fixture"}), encoding="utf-8")
        self.assertIsNone(vc.lookup(self.directory, "fixture", "deadbeef"))

    def test_a_name_mismatch_is_a_miss(self) -> None:
        result = {"name": "fixture", "status": "passed", "return_code": 0, "duration_seconds": 0.2}
        vc.store(self.directory, "fixture", "fingerprintvalue", result, "run-1", "0.359.0")
        self.assertIsNone(vc.lookup(self.directory, "a different check", "fingerprintvalue"))
        self.assertIsNotNone(vc.lookup(self.directory, "fixture", "fingerprintvalue"))

    def test_store_overwrites_an_existing_entry(self) -> None:
        first = {"name": "fixture", "status": "passed", "return_code": 0, "duration_seconds": 1.0}
        vc.store(self.directory, "fixture", "samefp", first, "run-1", "0.359.0")
        second = {"name": "fixture", "status": "passed", "return_code": 0, "duration_seconds": 2.0}
        vc.store(self.directory, "fixture", "samefp", second, "run-2", "0.359.0")
        entry = vc.lookup(self.directory, "fixture", "samefp")
        self.assertEqual(2.0, entry["duration_seconds"])
        self.assertEqual("run-2", entry["run_id"])

    def test_clear_removes_the_entire_directory(self) -> None:
        result = {"name": "fixture", "status": "passed", "return_code": 0, "duration_seconds": 1.0}
        vc.store(self.directory, "fixture", "abc123", result, "run-1", "0.359.0")
        vc.store(self.directory, "other", "def456", result, "run-1", "0.359.0")
        self.assertTrue(self.directory.is_dir())
        vc.clear(self.directory)
        self.assertFalse(self.directory.exists())

    def test_clear_on_a_missing_directory_is_not_an_error(self) -> None:
        vc.clear(self.directory / "does-not-exist")


if __name__ == "__main__":
    unittest.main()
