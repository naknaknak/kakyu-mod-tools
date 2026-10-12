from __future__ import annotations

import copy
import hashlib
import json
import struct
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

import prove_mes_registered_definition_registry as registry  # noqa: E402


def fixture_payload() -> bytes:
    code = bytes.fromhex(
        "1403ff08000000"  # selector 3, body [7, 8)
        "00"
        "1700000000"
        "1404ff15000000"  # selector 4, body [20, 21)
        "00"
        "00"  # zero-start return at 21
    )
    return struct.pack("<II", 1, 8) + code


def source_identity(payload: bytes) -> dict[str, str]:
    return {
        "archive": "mes.arc",
        "archive_sha256": "a" * 64,
        "entry": "DEF_TEST.MES",
        "entry_sha256": hashlib.sha256(payload).hexdigest(),
    }


class RegisteredDefinitionRegistryProofTests(unittest.TestCase):
    def test_proves_literal_zero_start_registry_and_body_boundaries(self) -> None:
        payload = fixture_payload()
        document = registry.prove_entry(payload, source_identity(payload))
        self.assertEqual(registry.SCHEMA, document["schema"])
        self.assertEqual([3, 4], [row["selector"] for row in document["registrations"]])
        self.assertEqual((7, 8), (
            document["registrations"][0]["body_start"],
            document["registrations"][0]["body_end"],
        ))
        self.assertEqual(21, document["zero_start_path"]["return_offset"])
        self.assertEqual(0, document["coverage"]["excluded_command_10_count"])
        self.assertEqual(
            "excluded_choice_definition_body_family",
            document["compatibility"]["command_10_policy"],
        )
        self.assertTrue(registry.validate(document, payload, source_identity(payload))["ok"])

    def test_rejects_changed_body_bytes(self) -> None:
        payload = fixture_payload()
        document = registry.prove_entry(payload, source_identity(payload))
        changed = bytearray(payload)
        changed[8 + 7] = 0x02
        changed_payload = bytes(changed)
        with self.assertRaisesRegex(
            registry.RegisteredDefinitionRegistryProofError,
            "projection changed",
        ):
            registry.validate(document, changed_payload, source_identity(changed_payload))

    def test_rejects_dynamic_or_duplicate_selectors(self) -> None:
        dynamic_code = bytes.fromhex("148002ff0900000000170000000000")
        dynamic = struct.pack("<II", 1, 9) + dynamic_code
        with self.assertRaisesRegex(
            registry.RegisteredDefinitionRegistryProofError,
            "u8 literal",
        ):
            registry.prove_entry(dynamic, source_identity(dynamic))

        duplicate = bytearray(fixture_payload())
        duplicate[8 + 13 + 1] = 3
        duplicate_payload = bytes(duplicate)
        with self.assertRaisesRegex(
            registry.RegisteredDefinitionRegistryProofError,
            "not unique",
        ):
            registry.prove_entry(duplicate_payload, source_identity(duplicate_payload))

    def test_rejects_changed_fingerprint_and_unknown_fields(self) -> None:
        payload = fixture_payload()
        document = registry.prove_entry(payload, source_identity(payload))
        changed = copy.deepcopy(document)
        changed["registrations"][0]["body_size"] = 2
        with self.assertRaisesRegex(
            registry.RegisteredDefinitionRegistryProofError,
            "fingerprint changed",
        ):
            registry.validate(changed, payload, source_identity(payload))

        unknown = copy.deepcopy(document)
        unknown["ignored"] = True
        unknown["payload_sha256"] = registry.fingerprint(unknown)
        with self.assertRaisesRegex(
            registry.RegisteredDefinitionRegistryProofError,
            "schema or fields changed",
        ):
            registry.validate(unknown, payload, source_identity(payload))

    def test_json_roundtrip_and_exclusive_output(self) -> None:
        payload = fixture_payload()
        document = registry.prove_entry(payload, source_identity(payload))
        transported = json.loads(json.dumps(document))
        self.assertTrue(
            registry.validate(transported, payload, source_identity(payload))["ok"]
        )
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "registry.json"
            registry._write_new_json(output, document)
            self.assertEqual(document, json.loads(output.read_text(encoding="utf-8")))
            with self.assertRaises(FileExistsError):
                registry._write_new_json(output, document)


if __name__ == "__main__":
    unittest.main()
