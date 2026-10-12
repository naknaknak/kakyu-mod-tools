from copy import deepcopy
import hashlib
import json
from pathlib import Path
import struct
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
from build_event_analysis_inventory import build, fingerprint, INDEX_SCHEMA, summarize_entry
from classify_event_routes import canonical


class EventAnalysisInventoryTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.arc = Path(self.temp.name) / "mes.arc"
        # Entirely authored fixture. Payload bytes are never intro coordinates.
        dispatch = b"\x0f\x01EVENTQA.MES\0\0"
        code = b"\x0b\x01\xff" + struct.pack("<I", 7 + len(dispatch)) + dispatch + b"\0"
        self.caller, self.callee = b"\0" * 4 + code, b"\0" * 5
        self.arc.write_bytes(self.caller + self.callee)
        self.entries = [("CALLER.MES", 0, len(self.caller)), ("EVENTQA.MES", len(self.caller), len(self.callee))]
        sha = hashlib.sha256(self.arc.read_bytes()).hexdigest()
        self.catalog = {"schema_version": "kakyu_event_player_catalog/v8", "source_profile": {"mes_archive": {"sha256": sha}}}
        self.index = {"schema": INDEX_SCHEMA, "archive_sha256": sha,
            "catalog_sha256": hashlib.sha256(canonical(self.catalog)).hexdigest(),
            "rows": [{"entry": "EVENTQA.MES", "entry_sha256": hashlib.sha256(self.callee).hexdigest(),
                "scope": "event_named_target", "class": "unresolved_route", "catalog_routes": [],
                "intro_evidence": [{"caller_entry": "CALLER.MES", "caller_entry_sha256": hashlib.sha256(self.caller).hexdigest(),
                    "source_offset": 7, "end_offset": len(code) - 1, "command_id": 15}]}]}
        self.sign()

    def sign(self):
        self.index["payload_sha256"] = fingerprint(self.index)

    def run_build(self, jobs=1):
        with patch("build_event_analysis_inventory.read_entries", return_value=self.entries):
            return build(self.arc, self.index, self.catalog, jobs)

    def test_reproducible_serial_and_process_pool(self):
        serial = self.run_build()
        self.assertEqual(serial, self.run_build(2))
        self.assertEqual(serial["payload_sha256"], fingerprint(serial))
        self.assertEqual(serial["counts"]["event_intro_sites"], 1)
        self.assertEqual(serial["runtime_coverage"], "not_measured")
        for entry in serial["entries"]:
            self.assertEqual(entry["producer"], "python_phase1_4")
        self.assertNotIn('"raw_hex"', json.dumps(serial))
        self.assertNotIn('"text_hex"', json.dumps(serial))
        intro = serial["routes"][0]["intros"][0]
        self.assertEqual(intro["lexical_guard_candidates"], [0])
        self.assertEqual(intro["guard_qualification"], "not_proven")

    def test_command_zero_is_return_candidate_but_write_is_not(self):
        # 0A dword write followed by the actual 00 return.
        code = bytes([0x0A, 2, 0xFF, 3, 0xFF, 1, 4, 0xFF, 0, 0])
        summary = summarize_entry(("SYNTH.MES", b"\0" * 4 + code, "a" * 64))
        self.assertEqual([row["offset"] for row in summary["terminal_candidates"]], [9])
        self.assertEqual(len(summary["write_sites"]), 1)

    def test_exact_intro_record_rejects_payload_start_and_wrong_end(self):
        for field, value in [("source_offset", 8), ("end_offset", 8), ("command_id", 14)]:
            with self.subTest(field=field):
                original = deepcopy(self.index)
                self.index["rows"][0]["intro_evidence"][0][field] = value
                self.sign()
                with self.assertRaises(ValueError): self.run_build()
                self.index = original

    def test_duplicate_or_omitted_source_records_fail_closed(self):
        original = deepcopy(self.index)
        for mutation in ("row", "intro", "missing_event", "entry_sha", "caller_sha"):
            self.index = deepcopy(original)
            row = self.index["rows"][0]
            if mutation == "row": self.index["rows"].append(deepcopy(row))
            elif mutation == "intro": row["intro_evidence"].append(deepcopy(row["intro_evidence"][0]))
            elif mutation == "missing_event": self.index["rows"] = []
            elif mutation == "entry_sha": row["entry_sha256"] = "0" * 64
            else: row["intro_evidence"][0]["caller_entry_sha256"] = "0" * 64
            self.sign()
            with self.subTest(mutation=mutation), self.assertRaises(ValueError): self.run_build()

    def test_unversioned_stale_or_tampered_inputs_fail_closed(self):
        original = deepcopy(self.index)
        for key, value in [("schema", "unknown/v2"), ("payload_sha256", "0" * 64),
                           ("catalog_sha256", "0" * 64), ("archive_sha256", "0" * 64)]:
            self.index = deepcopy(original)
            self.index[key] = value
            if key != "payload_sha256": self.sign()
            with self.subTest(key=key), self.assertRaises(ValueError): self.run_build()


if __name__ == "__main__":
    unittest.main()
