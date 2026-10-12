from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path
import random
import struct
import sys
import unittest
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

import mes_analyzer_handoff as producer
import mes_handoff_transport as transport
import validate_mes_analyzer_handoff as validator
from tests.test_mes_instruction_ir import run_godot_oracle
from tests import test_validate_mes_analyzer_handoff as validator_tests


def descriptor_to_python(value):
    """Shared counterpart to the GD oracle's typed synthetic-value descriptors."""
    if isinstance(value, list):
        return [descriptor_to_python(child) for child in value]
    if not isinstance(value, dict):
        return value
    kind = value.get("$oracle_type")
    if kind == "int64":
        return int(value["value"])
    if kind == "float64_bits":
        return struct.unpack("<d", bytes.fromhex(value["value"]))[0]
    if kind == "packed_bytes":
        return bytes.fromhex(value["value"])
    if kind == "dictionary":
        return {descriptor_to_python(key): descriptor_to_python(child) for key, child in value["value"]}
    if kind == "vector2":
        return object()
    return {key: descriptor_to_python(child) for key, child in value.items()}


def float_descriptor(value):
    return {"$oracle_type": "float64_bits", "value": struct.pack("<d", value).hex()}


def transport_fixtures():
    values = [
        None, True, False, "", "quotes\" backslash\\ slash/", "\b\t\n\f\r",
        "\u0085\u2028\u2029\u007f\u00ff 한글 😀", [], {},
        {"😀": True, "\uffff": False, "é": None, "a": "z"},
        {"z": [{"$oracle_type": "packed_bytes", "value": "0001ff"}], "a": "first"},
    ]
    values.extend({"$oracle_type": "int64", "value": str(value)} for value in (
        -(1 << 63), -(1 << 53) - 1, -1, 0, 1, (1 << 53) + 1, (1 << 63) - 1,
    ))
    values.extend(float_descriptor(value) for value in (
        0.0, -0.0, 1.0, -1.0, 0.1, 0.3, 0.1 + 0.2, math.pi,
        1e-5, 1e-4, 1e14, 1e15, 1e16, 1e20, 1e21, 1e-100, 1e100,
    ))
    # Every binary exponent, at each side of the mantissa interval, exercises
    # subnormals, unequal predecessor spacing and all cached-power selections.
    bit_patterns = {1, (1 << 52) - 1, 1 << 52, 0x7FEFFFFFFFFFFFFF}
    for exponent in range(2047):
        for fraction in (0, 1, (1 << 52) - 1):
            bit_patterns.add((exponent << 52) | fraction)
    generator = random.Random(20260906)
    for _ in range(4096):
        bits = generator.getrandbits(64)
        if (bits >> 52) & 0x7FF != 0x7FF:
            bit_patterns.add(bits)
    values.extend(
        {"$oracle_type": "float64_bits", "value": struct.pack("<Q", bits).hex()}
        for bits in sorted(bit_patterns)
    )
    return [
        {"name": f"transport_{index}", "hex": "", "mode": "transport", "value": value}
        for index, value in enumerate(values)
    ]


class HandoffTransportTests(unittest.TestCase):
    def test_normalization_is_sorted_independent_and_packed_bytes_preserving(self):
        value = {"z": [bytearray(b"\x00\xff")], "a": {"β": 1, "a": True}}
        result = transport.normalize(value)
        self.assertEqual(["a", "z"], list(result))
        self.assertEqual(["a", "β"], list(result["a"]))
        self.assertEqual({"$packed_byte_array_hex": "00ff"}, result["z"][0])
        result["a"]["a"] = False
        self.assertTrue(value["a"]["a"])

    def test_repeated_shared_children_are_not_cycles(self):
        child = [1, "a"]
        self.assertEqual([[1, "a"], [1, "a"]], transport.normalize([child, child]))

    def test_cycles_fail_closed(self):
        cycle = []
        cycle.append(cycle)
        indirect = {"child": []}
        indirect["child"].append(indirect)
        for value in (cycle, indirect):
            with self.subTest(value_type=type(value).__name__):
                with self.assertRaisesRegex(transport.TransportError, "cycle"):
                    transport.canonical_json_bytes(value)

    def test_unsupported_keys_and_types_are_rejected_without_coercion(self):
        for value in ({1: "a"}, {1: "a", "1": "b"}, {True: "a"}, (1, 2), {1, 2}, object()):
            with self.subTest(value=repr(value)):
                with self.assertRaises(transport.TransportError):
                    transport.normalize(value)

    def test_nonfinite_and_out_of_range_numbers_fail_closed(self):
        for value in (float("nan"), float("inf"), -float("inf"), -(1 << 63) - 1, 1 << 63):
            with self.subTest(value=value):
                with self.assertRaises(transport.TransportError):
                    transport.canonical_json_bytes(value)

    def test_invalid_unicode_and_nonstandard_json_controls_are_rejected(self):
        values = [chr(code) for code in range(32) if chr(code) not in "\b\t\n\f\r"]
        values.extend(("\ud800", "\udfff", "\ud800\udc00"))
        for value in values:
            with self.subTest(value=repr(value)):
                with self.assertRaises(transport.TransportError):
                    transport.canonical_json_bytes({"value": value})

    def test_depth_limit_applies_before_python_recursion_limit(self):
        nested = None
        for _ in range(transport.MAX_DEPTH):
            nested = [nested]
        transport.canonical_json_bytes(nested)
        with self.assertRaisesRegex(transport.TransportError, "depth"):
            transport.normalize([nested])

    def test_node_and_byte_limits_include_expansion_and_repeated_children(self):
        with patch.object(transport, "MAX_NODES", 4):
            with self.assertRaisesRegex(transport.TransportError, "node"):
                transport.normalize([[1], [1]])
        with patch.object(transport, "MAX_BYTES", 32):
            self.assertEqual(32, len(transport.canonical_json_bytes("a" * 30)))
            for value in ("a" * 31, bytes(16), ["a" * 15, "a" * 15], "\n" * 16):
                with self.subTest(value=value):
                    with self.assertRaisesRegex(transport.TransportError, "byte"):
                        transport.canonical_json_bytes(value)

    def test_producer_and_validator_share_float_transport_and_roundtrip(self):
        document = validator_tests.MesAnalyzerHandoffTests().fixture()
        document["traces"].append({"zero": -0.0, "large": 1e15, "decimal": 0.1})
        document.pop("payload_sha256")
        document["payload_sha256"] = producer.fingerprint(document)
        encoded = transport.canonical_json_bytes(document)
        reopened = json.loads(encoded)
        self.assertTrue(validator.validate(reopened)["ok"])
        self.assertEqual(validator.fingerprint(document), document["payload_sha256"])
        payload = {key: value for key, value in document.items() if key != "payload_sha256"}
        old_bytes = json.dumps(payload, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode()
        self.assertNotEqual(hashlib.sha256(old_bytes).hexdigest(), document["payload_sha256"])


class HandoffTransportGodotOracleTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.fixtures = transport_fixtures()
        cls.expected = run_godot_oracle(cls.fixtures)

    def test_exact_bytes_and_python_json_roundtrip_for_supported_transport(self):
        for row in self.fixtures:
            with self.subTest(name=row["name"], value=row["value"]):
                expected = self.expected[row["name"]]
                self.assertTrue(expected["validation"]["ok"])
                value = descriptor_to_python(row["value"])
                encoded = transport.canonical_json_bytes(value)
                self.assertEqual(expected["json_utf8_hex"], encoded.hex())
                self.assertEqual(transport.normalize(value), json.loads(encoded))


if __name__ == "__main__":
    unittest.main()
