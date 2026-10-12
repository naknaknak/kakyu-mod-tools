from __future__ import annotations

import copy
import sys
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

import prove_mes_choice_group_authoring as prover  # noqa: E402


def _group_clear(code: bytearray, selector: int) -> int:
    offset = len(code)
    code.extend(bytes([0x1B, 0x02, selector, 0xFF, 0x00]))
    return offset


def _definition(code: bytearray, definition_id: int, text: bytes) -> tuple[int, int]:
    offset = len(code)
    code.extend(bytes([0x10, 0x02, definition_id, 0xFF, 0x00]))
    code.extend(b"\0\0\0\0")
    code.extend(b"\x01" + text + b"\0\0")
    target = len(code)
    code[offset + 5 : offset + 9] = target.to_bytes(4, "little")
    return offset, target


def _compound_result_branch(
    code: bytearray,
    first_result: int,
    second_result: int,
) -> int:
    offset = len(code)
    code.extend(
        bytes(
            [
                0x0B,
                0x80,
                21,
                first_result,
                0xEF,
                0x80,
                13,
                second_result,
                0xEF,
                0xE6,
                0xFF,
            ]
        )
    )
    code.extend(b"\0\0\0\0")
    return offset


def _fixture() -> tuple[bytes, dict[str, str], dict[str, int]]:
    code = bytearray(b"\x17\0\0\0\0")
    group_zero_clear = _group_clear(code, 0)
    first_registration, _first_target = _definition(code, 0, b"FIRST")
    group_one_clear = _group_clear(code, 1)
    second_registration, _second_target = _definition(code, 0, b"SECOND")
    routine_40 = len(code)
    code.extend(bytes([0x1D, 0x02, 40, 0xFF, 0x00]))
    result_branch = _compound_result_branch(code, 1, 1)
    stored_consumer = len(code)
    code.extend(b"\x00")
    default_continuation = len(code)
    final_destination = default_continuation + 6
    code.extend(b"\x0C" + final_destination.to_bytes(4, "little") + b"\0")
    code.extend(b"\x00")
    code[result_branch + 11 : result_branch + 15] = default_continuation.to_bytes(
        4, "little"
    )
    payload = (1).to_bytes(4, "little") + (0).to_bytes(4, "little") + bytes(code)
    source = {
        "archive": "mes.arc",
        "archive_sha256": "a" * 64,
        "entry": "CHOICE.MES",
    }
    offsets = {
        "group_zero_clear": group_zero_clear,
        "first_registration": first_registration,
        "group_one_clear": group_one_clear,
        "second_registration": second_registration,
        "routine_40": routine_40,
        "result_branch": result_branch,
        "stored_consumer": stored_consumer,
        "default_continuation": default_continuation,
        "final_destination": final_destination,
    }
    return payload, source, offsets


class ChoiceGroupAuthoringProofTests(unittest.TestCase):
    def test_proves_exact_group_message_result_and_resume_boundaries(self) -> None:
        payload, source, offsets = _fixture()

        proof = prover.prove_entry(payload, source, 0)

        self.assertTrue(proof["ok"])
        self.assertEqual(proof["coverage"]["group_count"], 2)
        self.assertEqual(proof["coverage"]["definition_count"], 2)
        self.assertEqual(proof["coverage"]["first_stage_option_count"], 1)
        self.assertEqual(proof["coverage"]["stored_second_route_count"], 1)
        self.assertEqual(proof["coverage"]["fallback_second_route_count"], 0)
        self.assertEqual(proof["groups"][0]["clear"]["start"], offsets["group_zero_clear"])
        self.assertEqual(
            proof["groups"][0]["definitions"][0]["registration"]["start"],
            offsets["first_registration"],
        )
        self.assertEqual(
            proof["groups"][1]["definitions"][0]["registration"]["start"],
            offsets["second_registration"],
        )
        self.assertEqual(proof["boundary"]["terminal_start"], offsets["routine_40"])
        self.assertEqual(
            proof["boundary"]["physical_resume_start"], offsets["result_branch"]
        )
        route = proof["result_mapping"]["groups"][0]["second_routes"][0]
        self.assertEqual(route["consumer_entry_offset"], offsets["stored_consumer"])
        self.assertEqual(route["false_target_offset"], offsets["default_continuation"])
        self.assertEqual(
            proof["result_mapping"]["default_continuation"]["destination_offset"],
            offsets["final_destination"],
        )
        self.assertEqual(
            proof["groups"][0]["definitions"][0]["message"]["native_projection"],
            "typed_cp932_string_source_decoder",
        )
        self.assertNotIn("FIRST", str(proof))
        self.assertNotIn("SECOND", str(proof))

    def test_is_deterministic(self) -> None:
        payload, source, _offsets = _fixture()

        first = prover.prove_entry(payload, source, 0)
        second = prover.prove_entry(payload, source, 0)

        self.assertEqual(first, second)

    def test_source_validation_rejects_message_mutation(self) -> None:
        payload, source, _offsets = _fixture()
        proof = prover.prove_entry(payload, source, 0)
        changed = bytearray(payload)
        changed[proof["container"]["code_offset"] + proof["groups"][0]["definitions"][0]["message"]["payload_start"]] ^= 1

        with self.assertRaises(prover.ChoiceGroupAuthoringProofError):
            prover.validate(proof, bytes(changed), source, 0)

    def test_rehashed_cross_link_mutation_is_rejected(self) -> None:
        payload, source, _offsets = _fixture()
        proof = prover.prove_entry(payload, source, 0)
        changed = copy.deepcopy(proof)
        changed["first_stage_options"][0]["selected_group_selector"] = 2
        changed["payload_sha256"] = prover.fingerprint(changed)

        with self.assertRaises(prover.ChoiceGroupAuthoringProofError):
            prover.validate_document(changed)

    def test_group_entry_indices_finds_the_grouped_route(self) -> None:
        payload, source, _offsets = _fixture()

        self.assertEqual(prover.group_entry_indices(payload, source), [0])

    def test_group_entry_indices_skips_an_entry_without_a_group_clear(self) -> None:
        code = bytes([0x17]) + (0).to_bytes(4, "little") + bytes([0x00])
        payload = (1).to_bytes(4, "little") + (0).to_bytes(4, "little") + code
        source = {
            "archive": "mes.arc",
            "archive_sha256": "a" * 64,
            "entry": "NOCHOICE.MES",
        }

        self.assertEqual(prover.group_entry_indices(payload, source), [])

    def test_unknown_field_is_rejected(self) -> None:
        payload, source, _offsets = _fixture()
        proof = prover.prove_entry(payload, source, 0)
        changed = copy.deepcopy(proof)
        changed["groups"][0]["unknown"] = True
        changed["payload_sha256"] = prover.fingerprint(changed)

        with self.assertRaises(prover.ChoiceGroupAuthoringProofError):
            prover.validate_document(changed)


if __name__ == "__main__":
    unittest.main()
