"""Fixture-set tests for `kakyu_event_definition/v3` to `v7` (WD-22 part 3; v4
event definition unit 2a; v7 is WD-21 U2 C3, with its own rule tests at the end).

Both fixture sets are run the same way: the stored `contract_fingerprint`
is checked against a fresh computation, every fixture under `valid/` and
`invalid/` is validated against `expected.json`, and the names-registry gate
is exercised against a real registry row. v4 additionally loads its own
fixture package (`config/contracts/event_definition_v4/package/`) so its
package-dependent checks (text resolution, the text-encoding rules) run too;
v3 carries no such fixture and is exercised without one, exactly as before
this module also covered v4.
"""
from __future__ import annotations

import copy
import json
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from tools.contract_fingerprint import compute, stored  # noqa: E402
from tools.validate_event_definition import _load_package, validate  # noqa: E402

V3_FIXTURE_DIR = ROOT / "config" / "contracts" / "event_definition_v3"
V4_FIXTURE_DIR = ROOT / "config" / "contracts" / "event_definition_v4"
V4_PACKAGE_DIR = V4_FIXTURE_DIR / "package"
V5_FIXTURE_DIR = ROOT / "config" / "contracts" / "event_definition_v5"
V5_PACKAGE_DIR = V5_FIXTURE_DIR / "package"
V6_FIXTURE_DIR = ROOT / "config" / "contracts" / "event_definition_v6"
V6_PACKAGE_DIR = V6_FIXTURE_DIR / "package"
V7_FIXTURE_DIR = ROOT / "config" / "contracts" / "event_definition_v7"
V7_PACKAGE_DIR = V7_FIXTURE_DIR / "package"
V7_UNKNOWN_INVENTORY_PACKAGE_DIR = V7_FIXTURE_DIR / "package_unknown_inventory"
NAMES_DIR = ROOT / "config" / "contracts" / "event_names_v1"


def _load_names_registry(names_dir: Path) -> dict | None:
    """Return `{"fingerprint": ..., "ids": {...}}` for the registry at
    `names_dir`, or `None` if it is not present/complete yet."""
    registry_path = names_dir / "event_names.json"
    fingerprint_path = names_dir / "names_fingerprint"
    if not names_dir.is_dir() or not registry_path.is_file() or not fingerprint_path.is_file():
        return None

    registry = json.loads(registry_path.read_text(encoding="utf-8"))
    rows = registry.get("events", registry.get("rows", registry if isinstance(registry, list) else []))
    if isinstance(rows, dict):
        ids = {
            (row["id"] if isinstance(row, dict) and "id" in row else key)
            for key, row in rows.items()
        }
    else:
        ids = {row["id"] for row in rows if isinstance(row, dict) and "id" in row}
    return {
        "fingerprint": fingerprint_path.read_text(encoding="utf-8").strip(),
        "ids": ids,
    }


class _FixtureSetMixin:
    """Shared test bodies; mixed into one `unittest.TestCase` per fixture
    set below. Not a `TestCase` itself, so the loader never tries to
    collect it directly (it has no `FIXTURE_DIR`)."""

    FIXTURE_DIR: Path
    PACKAGE_DIR: Path | None = None
    # A frozen fixture set records the names fingerprint of the registry it
    # was agreed with; v3's real projection fixture carries that literal
    # value, so the set is checked against it, not the live registry (whose
    # ids are the same). None follows the live registry.
    RECORDED_NAMES_FINGERPRINT: str | None = None
    # Only these fixtures bind this directory's own package (its
    # package-dependent checks); every other fixture keeps the v3-style
    # synthetic `package_binding` and is validated without a package. A
    # subclass whose own set adds package-dependent fixtures (WD-23's v5
    # `visits` dialogue fixtures) extends this set.
    PACKAGE_BOUND_FIXTURES = frozenset({"package_resolved.json", "text_control_character.json", "text_not_nfc.json", "text_line_break.json"})

    def _package(self, package_name: str | None = None):
        """The package a fixture is checked against: `PACKAGE_DIR`, or, when the
        fixture's `expected.json` entry carries a `package` key (v7's
        unknown-`media_inventory`-schema refusal), that directory of the set."""
        if self.PACKAGE_DIR is None:
            return None
        return _load_package(self.FIXTURE_DIR / package_name if package_name else self.PACKAGE_DIR)

    def _names_registry(self):
        names_registry = _load_names_registry(NAMES_DIR)
        if names_registry is not None and self.RECORDED_NAMES_FINGERPRINT is not None:
            names_registry = dict(names_registry, fingerprint=self.RECORDED_NAMES_FINGERPRINT)
        return names_registry

    def test_stored_fingerprint_matches_computed(self) -> None:
        self.assertEqual(stored(self.FIXTURE_DIR), compute(self.FIXTURE_DIR))

    def test_fixture_set_matches_expected(self) -> None:
        expected = json.loads((self.FIXTURE_DIR / "expected.json").read_text(encoding="utf-8"))
        fingerprint = compute(self.FIXTURE_DIR)
        names_registry = self._names_registry()
        if names_registry is None:
            self.skipTest("event_names_v1 registry not present or incomplete yet (part 1 not landed)")

        package_bound = self.PACKAGE_BOUND_FIXTURES

        seen = set()
        for subdir in ("valid", "invalid"):
            for path in sorted((self.FIXTURE_DIR / subdir).glob("*.json")):
                relative = f"{subdir}/{path.name}"
                seen.add(relative)
                self.assertIn(relative, expected, f"{relative} has no expectation in expected.json")
                document = json.loads(path.read_text(encoding="utf-8"))
                package_name = expected[relative].get("package")
                package = self._package(package_name) if package_name or path.name in package_bound else None
                result = validate(document, fingerprint=fingerprint, names_registry=names_registry, package=package)
                self.assertEqual(
                    result["ok"], expected[relative]["ok"],
                    f"{relative}: ok={result['ok']!r} reason={result['reason']!r} detail={result.get('detail')!r}",
                )
                self.assertEqual(
                    result["reason"], expected[relative]["reason"],
                    f"{relative}: reason={result['reason']!r} detail={result.get('detail')!r}",
                )

        self.assertEqual(seen, set(expected.keys()))

    def test_names_registry_gate(self) -> None:
        names_registry = self._names_registry()
        if names_registry is None:
            self.skipTest("event_names_v1 registry not present or incomplete yet (part 1 not landed)")
        ids = names_registry["ids"]

        fingerprint = compute(self.FIXTURE_DIR)
        base_document = json.loads((self.FIXTURE_DIR / "valid" / "plain_event.json").read_text(encoding="utf-8"))

        # An id the registry does not carry fails closed, even with the
        # fixture's own "self" names_fingerprint (equal to the registry's).
        absent_document = dict(base_document)
        absent_document["id"] = "reiko.school.floor4.99.9"
        self.assertNotIn(absent_document["id"], ids)
        result = validate(absent_document, fingerprint=fingerprint, names_registry=names_registry)
        self.assertFalse(result["ok"])
        self.assertEqual(result["reason"], "names")

        # A document naming a real registry row and the registry's own
        # fingerprint passes the names check.
        present_document = dict(base_document)
        present_document["id"] = next(iter(ids))
        present_document["names_fingerprint"] = names_registry["fingerprint"]
        result = validate(present_document, fingerprint=fingerprint, names_registry=names_registry)
        self.assertTrue(result["ok"], result)

        # "self" is also accepted against a real, named registry row.
        self_document = dict(base_document)
        self_document["id"] = next(iter(ids))
        self_document["names_fingerprint"] = "self"
        result = validate(self_document, fingerprint=fingerprint, names_registry=names_registry)
        self.assertTrue(result["ok"], result)

    def test_main_exits_zero_on_valid_document(self) -> None:
        import subprocess

        fingerprint = compute(self.FIXTURE_DIR)
        completed = subprocess.run(
            [
                sys.executable,
                str(ROOT / "tools" / "validate_event_definition.py"),
                str(self.FIXTURE_DIR / "valid" / "plain_event.json"),
                "--fingerprint",
                fingerprint,
            ],
            capture_output=True,
            text=True,
        )
        self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)


class EventDefinitionV3ContractTest(_FixtureSetMixin, unittest.TestCase):
    FIXTURE_DIR = V3_FIXTURE_DIR
    PACKAGE_DIR = None
    RECORDED_NAMES_FINGERPRINT = "b7ffcea3abac019a78f8ac19e98d5259fc778a0eb3c7123424f257b435163e1a"


class EventDefinitionV4ContractTest(_FixtureSetMixin, unittest.TestCase):
    FIXTURE_DIR = V4_FIXTURE_DIR
    PACKAGE_DIR = V4_PACKAGE_DIR


class EventDefinitionV5ContractTest(_FixtureSetMixin, unittest.TestCase):
    """WD-23: `kakyu_event_definition/v5` (v4 plus an optional `visits`
    list). Same shared test bodies as v3/v4; the fixture set's own
    `expected.json` carries the eight new visit-only failure fixtures
    alongside v4's own (re-versioned) set."""

    FIXTURE_DIR = V5_FIXTURE_DIR
    PACKAGE_DIR = V5_PACKAGE_DIR
    PACKAGE_BOUND_FIXTURES = _FixtureSetMixin.PACKAGE_BOUND_FIXTURES | {"visit_chain_event.json"}


class EventDefinitionV6ContractTest(_FixtureSetMixin, unittest.TestCase):
    """EP-12 / WD (2026-09-25): `kakyu_event_definition/v6` (v5 plus an
    optional top-level `flow` block). Same shared test bodies as v3/v4/v5;
    the fixture set's own `expected.json` carries the sixteen new flow-only
    failure fixtures alongside v5's own (re-versioned) set."""

    FIXTURE_DIR = V6_FIXTURE_DIR
    PACKAGE_DIR = V6_PACKAGE_DIR
    PACKAGE_BOUND_FIXTURES = _FixtureSetMixin.PACKAGE_BOUND_FIXTURES | {"visit_chain_event.json", "flow_event.json"}


class EventDefinitionV7ContractTest(_FixtureSetMixin, unittest.TestCase):
    """WD-21 U2 C3 (2026-10-08): `kakyu_event_definition/v7` (v6 plus the
    `presentation.resources` item rule). Same shared test bodies; the set's
    `expected.json` carries v6's fixtures re-versioned plus the resources
    fixtures. The package-dependent resources fixtures bind the fixture package
    (the unknown-inventory-schema one names a second package in its
    `expected.json` entry); the other resources failures are shape rules and
    run without a package."""

    FIXTURE_DIR = V7_FIXTURE_DIR
    PACKAGE_DIR = V7_PACKAGE_DIR
    PACKAGE_BOUND_FIXTURES = _FixtureSetMixin.PACKAGE_BOUND_FIXTURES | {
        "visit_chain_event.json",
        "flow_event.json",
        "flow_resources.json",
        "resource_not_in_inventory.json",
        "resource_member_without_row.json",
        "resource_entry_not_in_package.json",
    }

    def test_the_package_key_names_a_directory_of_the_set(self) -> None:
        expected = json.loads((self.FIXTURE_DIR / "expected.json").read_text(encoding="utf-8"))
        named = {relative: row["package"] for relative, row in expected.items() if "package" in row}
        self.assertEqual(named, {"invalid/resource_unknown_inventory_schema.json": "package_unknown_inventory"})
        for directory in named.values():
            self.assertTrue((self.FIXTURE_DIR / directory / "manifest.json").is_file(), directory)


def _load_fixture(name: str) -> dict:
    return json.loads((V7_FIXTURE_DIR / name).read_text(encoding="utf-8"))


class EventDefinitionV7ResourcesTest(unittest.TestCase):
    """The `presentation.resources` rule of `docs/spec/data/event_definition_v7.md`,
    exercised by mutating the fixture document in memory."""

    @classmethod
    def setUpClass(cls) -> None:
        cls.fingerprint = compute(V7_FIXTURE_DIR)
        cls.package = _load_package(V7_PACKAGE_DIR)
        cls.base = _load_fixture("valid/flow_resources.json")
        cls.expected = json.loads((V7_FIXTURE_DIR / "expected.json").read_text(encoding="utf-8"))
        cls.new_invalid = sorted(
            name for name in cls.expected
            if name.startswith("invalid/resource") or name.startswith("invalid/presentation")
        )

    def _validate(self, document: dict, package=None) -> dict:
        return validate(document, fingerprint=self.fingerprint, package=package)

    def _with(self, resources=None, **presentation) -> dict:
        document = json.loads(json.dumps(self.base))
        if resources is not None:
            document["presentation"]["resources"] = resources
        document["presentation"].update(presentation)
        return document

    def _items(self) -> list:
        return json.loads(json.dumps(self.base["presentation"]["resources"]))

    def _expect(self, document: dict, reason: str, package=None) -> None:
        result = self._validate(document, package)
        self.assertFalse(result["ok"], result)
        self.assertEqual(result["reason"], reason, result)

    def test_reused_vocabulary_is_the_inventory_readers(self) -> None:
        from tools import validate_event_definition as validator
        import payload_values  # the module object the validator imported (tools/ is on sys.path)

        self.assertEqual(validator.RESOURCE_KINDS_V7, set(payload_values.MEDIA_KINDS))
        self.assertEqual(validator.KNOWN_MEDIA_INVENTORY_SCHEMAS_V7, {payload_values.MEDIA_INVENTORY_SCHEMA})
        self.assertIs(validator.is_safe_leaf, payload_values.is_safe_leaf)
        self.assertEqual(self.package["__manifest__"]["media_inventory"]["schema"], payload_values.MEDIA_INVENTORY_SCHEMA)

    def test_the_resources_fixture_spans_both_flow_entries_and_the_library(self) -> None:
        entries = {item["entry"] for item in self.base["presentation"]["resources"]}
        self.assertEqual(entries, {"CALLER", "CALLEE", "LIBLARY.LIB"})
        evidence_entries = {member["entry"] for member in self.base["evidence"]["members"]}
        self.assertEqual(evidence_entries, {"CALLER", "CALLEE"})
        package_entries = {row["entry"] for row in self.package["__manifest__"]["entries"]}
        self.assertTrue({"LIBLARY.LIB", "DEF_MAIN.MES"} <= package_entries)

    def test_valid_with_and_without_the_package(self) -> None:
        self.assertTrue(self._validate(self.base)["ok"])
        self.assertTrue(self._validate(self.base, self.package)["ok"])

    def test_empty_resources_are_valid_against_an_inventory_that_has_occurrences(self) -> None:
        document = self._with(resources=[])
        self.assertTrue(self._validate(document)["ok"])
        self.assertTrue(self._validate(document, self.package)["ok"])
        self.assertTrue(self.package["__manifest__"]["media_inventory"]["members"])

    def test_empty_resources_do_not_need_an_inventory_in_the_package(self) -> None:
        package = copy.deepcopy(self.package)
        del package["__manifest__"]["media_inventory"]
        self.assertTrue(self._validate(self._with(resources=[]), package)["ok"])

    def test_every_kind_of_the_vocabulary_is_accepted(self) -> None:
        for kind in ("mmo", "ax", "voice", "se", "a6", "bgm", "unclassified"):
            item = {"entry": "CALLEE", "source_offset": 0, "kind": kind, "name": "X.BIN"}
            self.assertTrue(self._validate(self._with(resources=[item]))["ok"], kind)

    def test_item_shape(self) -> None:
        for bad in (None, [], "CALLEE", 3):
            self._expect(self._with(resources=[bad]), "bad_resource_item")
        for key in ("entry", "source_offset", "kind", "name"):
            items = self._items()
            del items[0][key]
            self._expect(self._with(resources=items), "bad_resource_item")
        items = self._items()
        items[0]["note"] = "x"
        self._expect(self._with(resources=items), "bad_resource_item")

    def test_entry_must_be_a_safe_leaf(self) -> None:
        for entry in ("", "A/B.MES", "A\\B.MES", "..", "A..B", "C:X.MES", 5, None):
            items = self._items()
            items[0]["entry"] = entry
            self._expect(self._with(resources=items), "bad_resource_entry")

    def test_offset_must_be_a_non_negative_integer(self) -> None:
        for offset in (-1, 1.5, "70", True, None):
            items = self._items()
            items[0]["source_offset"] = offset
            self._expect(self._with(resources=items), "bad_resource_offset")

    def test_kind_must_be_in_the_vocabulary(self) -> None:
        for kind in ("music", "VOICE", "", None, 3):
            items = self._items()
            items[0]["kind"] = kind
            self._expect(self._with(resources=items), "bad_resource_kind")

    def test_name_must_be_upper_case_non_empty_and_a_safe_leaf(self) -> None:
        for name in ("", "v0001.ogg", "V0001.ogg", None, 7, "SUB/V0001.OGG", "SUB\\V0001.OGG", "..", "A..OGG", "C:V0001.OGG"):
            items = self._items()
            items[0]["name"] = name
            self._expect(self._with(resources=items), "bad_resource_name")

    def test_order_is_entry_offset_kind_name(self) -> None:
        ordered = [
            {"entry": "A", "source_offset": 5, "kind": "ax", "name": "A.AX"},
            {"entry": "A", "source_offset": 5, "kind": "ax", "name": "B.AX"},
            {"entry": "A", "source_offset": 5, "kind": "mmo", "name": "A.MMO"},
            {"entry": "A", "source_offset": 6, "kind": "ax", "name": "A.AX"},
            {"entry": "A", "source_offset": 10, "kind": "ax", "name": "A.AX"},
            {"entry": "B", "source_offset": 0, "kind": "ax", "name": "A.AX"},
        ]
        self.assertTrue(self._validate(self._with(resources=ordered))["ok"])
        for first in range(len(ordered) - 1):
            swapped = [dict(item) for item in ordered]
            swapped[first], swapped[first + 1] = swapped[first + 1], swapped[first]
            self._expect(self._with(resources=swapped), "unsorted_resources")
        # An offset sorts as a number, not as text: 6 comes before 10.
        self._expect(self._with(resources=[ordered[4], ordered[3]]), "unsorted_resources")

    def test_a_repeated_item_is_a_duplicate(self) -> None:
        items = self._items()
        self._expect(self._with(resources=items + [dict(items[-1])]), "duplicate_resource")
        self._expect(self._with(resources=[dict(items[0]), dict(items[0])]), "duplicate_resource")

    def test_status_is_the_literal_deferred(self) -> None:
        for status in ("extracted", "Deferred", "", None):
            self._expect(self._with(status=status), "bad_presentation")

    def test_presentation_shape(self) -> None:
        for presentation in (None, [], "deferred"):
            document = self._with()
            document["presentation"] = presentation
            self._expect(document, "bad_presentation")
        for resources in (None, {}, "none"):
            document = self._with()
            document["presentation"]["resources"] = resources
            self._expect(document, "bad_presentation")
        # Exactly {status, resources}: an extra key and a missing key both fail.
        document = self._with()
        document["presentation"]["note"] = "x"
        self._expect(document, "bad_presentation")
        document = self._with()
        del document["presentation"]["resources"]
        self._expect(document, "bad_presentation")
        document = self._with()
        del document["presentation"]["status"]
        self._expect(document, "bad_presentation")
        document = self._with()
        del document["presentation"]
        self._expect(document, "required")

    def test_with_the_package_an_item_is_an_inventory_occurrence(self) -> None:
        for key, value in (("source_offset", 71), ("kind", "mmo"), ("name", "V0009.OGG")):
            items = self._items()
            items[0][key] = value
            self._expect(self._with(resources=items), "resource_not_in_inventory", self.package)
            # The same item is well formed on its own: only the package says no.
            self.assertTrue(self._validate(self._with(resources=items))["ok"], key)

    def test_a_member_without_a_row_has_no_occurrence(self) -> None:
        manifest = self.package["__manifest__"]
        self.assertTrue(any(row["entry"] == "DEF_MAIN.MES" for row in manifest["entries"]))
        self.assertFalse(any(row["entry"] == "DEF_MAIN.MES" for row in manifest["media_inventory"]["members"]))
        item = {"entry": "DEF_MAIN.MES", "source_offset": 4997, "kind": "unclassified", "name": "CHARA2.DAT"}
        self._expect(self._with(resources=[item]), "resource_not_in_inventory", self.package)

    def test_with_the_package_an_entry_is_one_of_its_entries(self) -> None:
        item = {"entry": "NOPE.MES", "source_offset": 10, "kind": "voice", "name": "V0003.OGG"}
        self._expect(self._with(resources=[item]), "resource_entry_not_in_package", self.package)
        # An entry of the package that is not in evidence.members is fine (LIBLARY.LIB).
        self.assertTrue(self._validate(self.base, self.package)["ok"])

    def test_an_inventory_that_is_not_a_known_one_refuses_a_document_with_items(self) -> None:
        cases = {
            "unknown schema id": lambda m: m["media_inventory"].update(schema="kakyu_media_inventory/v2"),
            "no schema id": lambda m: m["media_inventory"].pop("schema"),
            "no block": lambda m: m.pop("media_inventory"),
            "block not an object": lambda m: m.update(media_inventory=[]),
            "members not a list": lambda m: m["media_inventory"].update(members={}),
            "member not a row": lambda m: m["media_inventory"]["members"].append("CALLEE"),
            "row without occurrences": lambda m: m["media_inventory"]["members"].append({"entry": "X"}),
        }
        for label, change in cases.items():
            with self.subTest(label):
                package = copy.deepcopy(self.package)
                change(package["__manifest__"])
                self._expect(self.base, "unknown_media_inventory", package)

    def test_the_new_invalid_fixtures_fail_the_same_way_with_the_package(self) -> None:
        """A shape rule fires before any package check, so supplying the package changes
        no verdict; only the package rules need it."""
        self.assertEqual(len(self.new_invalid), 16)
        for relative in self.new_invalid:
            package_name = self.expected[relative].get("package")
            package = _load_package(V7_FIXTURE_DIR / package_name) if package_name else self.package
            result = self._validate(_load_fixture(relative), package)
            self.assertFalse(result["ok"], relative)
            self.assertEqual(result["reason"], self.expected[relative]["reason"], relative)

    def test_the_package_rules_need_the_package(self) -> None:
        names = (
            "resource_not_in_inventory",
            "resource_member_without_row",
            "resource_entry_not_in_package",
            "resource_unknown_inventory_schema",
        )
        for name in names:
            self.assertTrue(self._validate(_load_fixture(f"invalid/{name}.json"))["ok"], name)

    def test_v6_never_looked_inside_presentation_and_still_does_not(self) -> None:
        document = self._with(resources=[{"anything": "goes"}])
        document["schema_version"] = "kakyu_event_definition/v6"
        self.assertTrue(validate(document, fingerprint=compute(V6_FIXTURE_DIR))["ok"])

    def test_the_command_line_resolves_the_v7_fingerprint_and_checks_the_package(self) -> None:
        import subprocess

        def run(path: Path, *extra: str):
            return subprocess.run(
                [sys.executable, str(ROOT / "tools" / "validate_event_definition.py"), str(path), *extra],
                capture_output=True,
                text=True,
            )

        completed = run(V7_FIXTURE_DIR / "valid" / "flow_resources.json", "--package", str(V7_PACKAGE_DIR))
        self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
        self.assertEqual(json.loads(completed.stdout), {"ok": True, "reason": "ok", "detail": ""})

        completed = run(V7_FIXTURE_DIR / "invalid" / "resource_not_in_inventory.json", "--package", str(V7_PACKAGE_DIR))
        self.assertEqual(completed.returncode, 1, completed.stdout + completed.stderr)
        self.assertEqual(json.loads(completed.stdout)["reason"], "resource_not_in_inventory")

        completed = run(
            V7_FIXTURE_DIR / "invalid" / "resource_unknown_inventory_schema.json",
            "--package",
            str(V7_UNKNOWN_INVENTORY_PACKAGE_DIR),
        )
        self.assertEqual(completed.returncode, 1, completed.stdout + completed.stderr)
        self.assertEqual(json.loads(completed.stdout)["reason"], "unknown_media_inventory")

        # No --fingerprint: the command line reads the v7 directory's own value, so a foreign one fails.
        completed = run(V7_FIXTURE_DIR / "invalid" / "foreign_contract_fingerprint.json")
        self.assertEqual(completed.returncode, 1, completed.stdout + completed.stderr)
        self.assertEqual(json.loads(completed.stdout)["reason"], "fingerprint")


if __name__ == "__main__":
    unittest.main()
