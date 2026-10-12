"""Tests for the v2 analysis-group replay schema
(`kakyu_event_analysis_group_replay/v2`, event definition v4 unit 1a). The
schema is produced by
`tools/content_suite/validators/validate_event_analysis_group.gd --replay`;
see `analysis/_docs/v4_unit1a_replay_spec.md` and
`docs/spec/data/event_definition_v4_design.md`.

`KAKYU_REPLAY_V2_SAMPLE`, when set, names one regenerated replay file (for
example `analysis/replays_v2/01m_i16_v6.json`) to check structurally; the
test is skipped when it is unset, since `analysis/` is gitignored scratch
space and no v2 replay ships in the repository.
"""
from __future__ import annotations

import json
import os
import unittest

STATE_CHANGE_KEYS = {"storage", "bank", "index", "before", "after"}
STATE_CHANGE_LISTS = ("prefix", "callee", "resume")

# v1 fields every variant of a kakyu_event_analysis_group_replay/v1 file
# already carried (docs/spec/data/event_definition_v4_design.md, "Every v1
# field stays exactly as it is").
V1_VARIANT_FIELDS = {
    "variant_id", "writes", "selections", "reached", "prefix_messages",
    "messages", "terminal", "final_state", "resume", "reentry",
}


def read_state_changes(variant):
    """Returns `variant["state_changes"]`, validated: the three named lists
    (`prefix`, `callee`, `resume`), each row carrying exactly the five keys
    `storage`/`bank`/`index`/`before`/`after` with `before != after`. Raises
    `ValueError` on a shape violation."""
    state_changes = variant.get("state_changes")
    if not isinstance(state_changes, dict):
        raise ValueError("variant has no state_changes dict")
    for name in STATE_CHANGE_LISTS:
        if name not in state_changes:
            raise ValueError("state_changes is missing %r" % name)
        rows = state_changes[name]
        if not isinstance(rows, list):
            raise ValueError("state_changes[%r] is not a list" % name)
        for row in rows:
            if set(row.keys()) != STATE_CHANGE_KEYS:
                raise ValueError("state_changes[%r] row has keys %r, expected %r" % (
                    name, sorted(row.keys()), sorted(STATE_CHANGE_KEYS)))
            if row["before"] == row["after"]:
                raise ValueError("state_changes[%r] row does not change: %r" % (name, row))
    return state_changes


class ReadStateChangesUnitTests(unittest.TestCase):
    """Pure unit tests of the reader above: synthetic dicts, no file I/O."""

    def test_accepts_a_well_formed_variant(self):
        variant = {
            "state_changes": {
                "prefix": [],
                "callee": [{"storage": "global_u8", "bank": 0, "index": 905, "before": 0, "after": 1}],
                "resume": [],
            }
        }
        state_changes = read_state_changes(variant)
        self.assertEqual(state_changes["callee"][0]["after"], 1)

    def test_rejects_a_missing_list(self):
        variant = {"state_changes": {"prefix": [], "callee": []}}
        with self.assertRaises(ValueError):
            read_state_changes(variant)

    def test_rejects_a_row_missing_a_key(self):
        variant = {"state_changes": {"prefix": [], "callee": [
            {"storage": "global_u8", "bank": 0, "index": 905, "before": 0}], "resume": []}}
        with self.assertRaises(ValueError):
            read_state_changes(variant)

    def test_rejects_a_row_that_does_not_change(self):
        variant = {"state_changes": {"prefix": [], "callee": [
            {"storage": "global_u8", "bank": 0, "index": 905, "before": 1, "after": 1}], "resume": []}}
        with self.assertRaises(ValueError):
            read_state_changes(variant)

    def test_rejects_a_non_dict(self):
        with self.assertRaises(ValueError):
            read_state_changes({})


@unittest.skipUnless(os.environ.get("KAKYU_REPLAY_V2_SAMPLE"), "KAKYU_REPLAY_V2_SAMPLE is not set")
class RegeneratedSampleTests(unittest.TestCase):
    """Loads one regenerated `analysis/replays_v2/<profile>.json` file (named
    by `KAKYU_REPLAY_V2_SAMPLE`) and checks it structurally against the v2
    schema."""

    @classmethod
    def setUpClass(cls):
        path = os.environ["KAKYU_REPLAY_V2_SAMPLE"]
        with open(path, "r", encoding="utf-8") as fh:
            cls.doc = json.load(fh)

    def test_schema_string(self):
        self.assertEqual(self.doc.get("schema"), "kakyu_event_analysis_group_replay/v2")

    def test_every_variant_carries_the_v1_fields_and_state_changes(self):
        routes = self.doc.get("routes", [])
        self.assertGreater(len(routes), 0)
        checked = 0
        for route in routes:
            self.assertIn("guard", route)
            self.assertIn("origin_offset", route)
            for variant in route.get("variants", []):
                missing = V1_VARIANT_FIELDS - set(variant.keys())
                self.assertFalse(missing, "variant %s is missing v1 fields %r" % (
                    variant.get("variant_id"), missing))
                self.assertIn("seed_writes", variant)
                read_state_changes(variant)
                checked += 1
        self.assertGreater(checked, 0)


if __name__ == "__main__":
    unittest.main()
