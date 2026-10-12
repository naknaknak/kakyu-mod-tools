"""Fixture-set tests for `kakyu_mod_event_definition/v1` (mod event
definition unit A).

The fixture set is run the way v3/v4's are: the stored `contract_fingerprint`
is checked against a fresh computation, every fixture under `valid/` and
`invalid/` is validated against `expected.json` (the `base_bound` fixtures
with `--definitions-dir base/`), the names-registry gate is exercised for
both document kinds, and a live check runs an `override` against a real
tracked v4 document.
"""
from __future__ import annotations

import json
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from tools.contract_fingerprint import compute, stored  # noqa: E402
from tools.validate_event_definition import load_names_registry  # noqa: E402
from tools.validate_mod_event_definition import document_sha256, validate  # noqa: E402

FIXTURE_DIR = ROOT / "config" / "contracts" / "mod_event_definition_v1"
BASE_DIR = FIXTURE_DIR / "base"
NAMES_DIR = ROOT / "config" / "contracts" / "event_names_v1"
STATE_CELLS_DIR = ROOT / "config" / "contracts" / "state_cells_v1"
V4_DEFINITIONS_DIR = ROOT / "config" / "event_definitions" / "v4"

BASE_BOUND = {
    "valid/override_results.json",
    "invalid/target_missing.json",
    "invalid/target_changed.json",
    "invalid/unknown_result.json",
    "invalid/result_exists.json",
    "invalid/override_results_choice_mismatch.json",
}


def _names_registry() -> dict | None:
    if not NAMES_DIR.is_dir():
        return None
    return load_names_registry(NAMES_DIR)


def _cells_fingerprint() -> str:
    return (STATE_CELLS_DIR / "cells_fingerprint").read_text(encoding="utf-8").strip()


class ModEventDefinitionContractTest(unittest.TestCase):
    def test_stored_fingerprint_matches_computed(self) -> None:
        self.assertEqual(stored(FIXTURE_DIR), compute(FIXTURE_DIR))

    def test_fixture_set_matches_expected(self) -> None:
        expected = json.loads((FIXTURE_DIR / "expected.json").read_text(encoding="utf-8"))
        fingerprint = compute(FIXTURE_DIR)
        cells_fingerprint = _cells_fingerprint()
        names_registry = _names_registry()
        if names_registry is None:
            self.skipTest("event_names_v1 registry not present")

        seen = set()
        for subdir in ("valid", "invalid"):
            for path in sorted((FIXTURE_DIR / subdir).glob("*.json")):
                relative = f"{subdir}/{path.name}"
                seen.add(relative)
                self.assertIn(relative, expected, f"{relative} has no expectation in expected.json")
                document = json.loads(path.read_text(encoding="utf-8"))
                base_documents = BASE_DIR if relative in BASE_BOUND else None
                result = validate(
                    document,
                    fingerprint=fingerprint,
                    cells_fingerprint=cells_fingerprint,
                    names_registry=names_registry,
                    base_documents=base_documents,
                )
                self.assertEqual(
                    result["ok"], expected[relative]["ok"],
                    f"{relative}: ok={result['ok']!r} reason={result['reason']!r} detail={result.get('detail')!r}",
                )
                self.assertEqual(
                    result["reason"], expected[relative]["reason"],
                    f"{relative}: reason={result['reason']!r} detail={result.get('detail')!r}",
                )

        self.assertEqual(seen, set(expected.keys()))

    def test_new_event_trigger_names_gate(self) -> None:
        names_registry = _names_registry()
        if names_registry is None:
            self.skipTest("event_names_v1 registry not present")
        fingerprint = compute(FIXTURE_DIR)
        cells_fingerprint = _cells_fingerprint()

        document = json.loads((FIXTURE_DIR / "valid" / "new_event_plain.json").read_text(encoding="utf-8"))
        document = dict(document)
        document["display"] = dict(document["display"], category="special", place="no_such_place_at_all")
        document["trigger"] = dict(document["trigger"], category="special", place="no_such_place_at_all")
        self.assertNotIn(("special", "no_such_place_at_all"), names_registry["pairs"])

        result = validate(
            document,
            fingerprint=fingerprint,
            cells_fingerprint=cells_fingerprint,
            names_registry=names_registry,
        )
        self.assertFalse(result["ok"])
        self.assertEqual(result["reason"], "trigger")

    def test_override_target_names_gate(self) -> None:
        names_registry = _names_registry()
        if names_registry is None:
            self.skipTest("event_names_v1 registry not present")
        fingerprint = compute(FIXTURE_DIR)
        cells_fingerprint = _cells_fingerprint()

        document = json.loads((FIXTURE_DIR / "valid" / "override_disable.json").read_text(encoding="utf-8"))
        document = dict(document)
        document["target"] = dict(document["target"], id="ai.school.gate.99.9")
        self.assertNotIn("ai.school.gate.99.9", names_registry["ids"])

        result = validate(
            document,
            fingerprint=fingerprint,
            cells_fingerprint=cells_fingerprint,
            names_registry=names_registry,
        )
        self.assertFalse(result["ok"])
        self.assertEqual(result["reason"], "names")

    def test_override_against_a_real_tracked_v4_document(self) -> None:
        target_path = V4_DEFINITIONS_DIR / "ai.school.gate.09.1.json"
        if not target_path.is_file():
            self.skipTest("config/event_definitions/v4/ai.school.gate.09.1.json not present")
        real_hash = document_sha256(target_path)

        document = {
            "schema_version": "kakyu_mod_event_definition/v1",
            "contract_fingerprint": "self",
            "cells_fingerprint": "self",
            "kind": "override",
            "mod": {"id": "samplemod", "revision": 1},
            "id": "mod.samplemod.override_live_check",
            "target": {"id": "ai.school.gate.09.1", "contract": "kakyu_event_definition/v4", "document_sha256": real_hash},
            "operations": [{"op": "disable"}],
        }
        fingerprint = compute(FIXTURE_DIR)
        cells_fingerprint = _cells_fingerprint()

        result = validate(
            document,
            fingerprint=fingerprint,
            cells_fingerprint=cells_fingerprint,
            base_documents=V4_DEFINITIONS_DIR,
        )
        self.assertTrue(result["ok"], result)

        bad_document = dict(document)
        bad_hash = list(real_hash)
        bad_hash[0] = "0" if bad_hash[0] != "0" else "1"
        bad_document["target"] = dict(document["target"], document_sha256="".join(bad_hash))
        result = validate(
            bad_document,
            fingerprint=fingerprint,
            cells_fingerprint=cells_fingerprint,
            base_documents=V4_DEFINITIONS_DIR,
        )
        self.assertFalse(result["ok"])
        self.assertEqual(result["reason"], "target_changed")

    def test_main_exits_zero_on_valid_document(self) -> None:
        import subprocess

        completed = subprocess.run(
            [
                sys.executable,
                str(ROOT / "tools" / "validate_mod_event_definition.py"),
                str(FIXTURE_DIR / "valid" / "new_event_plain.json"),
            ],
            capture_output=True,
            text=True,
        )
        self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)


if __name__ == "__main__":
    unittest.main()
