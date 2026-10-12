from __future__ import annotations

import sys
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

from audit_mes_def_routes import scan_code  # noqa: E402


def _definition(code: bytearray, definition_id: int, text: bytes, marker: int) -> None:
    source_offset = len(code)
    code.extend(bytes([0x10, 0x02, definition_id, 0xFF, 0x00]))
    code.extend(b"\0\0\0\0")
    code.extend(b"\x01" + text + b"\0\0")
    target = len(code)
    code[source_offset + 5 : source_offset + 9] = target.to_bytes(4, "little")
    code.extend(b"\x1f" + marker.to_bytes(4, "little"))


def _state_21_result_branch(code: bytearray, result: int) -> int:
    source_offset = len(code)
    code.extend(bytes([0x0B, 0x80, 21, result, 0xEF, 0xFF]))
    code.extend(b"\0\0\0\0")
    return source_offset


def _gated_state_21_result_branch(
    code: bytearray, result: int, gate_storage: str, gate_index: int, gate_value: int
) -> int:
    source_offset = len(code)
    condition = bytearray([0x80, 21, result, 0xEF])
    if gate_storage == "global_u8":
        condition.extend(bytes([0xF3, gate_index & 0xFF, (gate_index >> 8) & 0xFF]))
    elif gate_storage == "state_u16":
        condition.extend(bytes([0x80, gate_index]))
    else:
        raise ValueError(f"unsupported test gate storage: {gate_storage}")
    condition.extend(bytes([gate_value, 0xEF, 0xE6, 0xFF]))
    code.extend(b"\x0b" + condition)
    code.extend(b"\0\0\0\0")
    return source_offset


def _patch_branch_target(code: bytearray, source_offset: int, target: int) -> None:
    target_offset = source_offset + 1
    while target_offset < len(code) and code[target_offset] != 0xFF:
        target_offset += 1
    target_offset += 1
    code[target_offset : target_offset + 4] = target.to_bytes(4, "little")


class MesDefRouteAuditTests(unittest.TestCase):
    def test_exact_route_collects_ordered_definitions(self) -> None:
        code = bytearray()
        _definition(code, 0, b"A", 1)
        _definition(code, 1, b"B", 2)
        code.extend(b"\x1d\x02\x28\xff\x00")

        result = scan_code(bytes(code))

        self.assertEqual(result["command_10_candidates"], 2)
        self.assertEqual(result["exact_definitions"], 2)
        self.assertEqual(result["rejected"], {})
        self.assertEqual(len(result["routes"]), 1)
        route = result["routes"][0]
        self.assertEqual(route["definition_ids"], [0, 1])
        self.assertEqual(route["message_counts"], [1, 1])
        self.assertTrue(route["zero_based_sequential_ids"])
        self.assertEqual(route["resume_offset"], len(code))
        self.assertEqual(route["result_consumer"]["kind"], "unresolved")
        self.assertEqual(route["result_consumer"]["reason"], "missing_result_branch")

    def test_exact_one_based_state_21_result_consumer_is_projected(self) -> None:
        code = bytearray()
        _definition(code, 0, b"A", 1)
        _definition(code, 1, b"B", 2)
        _definition(code, 2, b"C", 3)
        code.extend(b"\x1d\x02\x28\xff\x00")
        code.extend(b"\x1f\x04\x00\x00\x00")
        first_branch = _state_21_result_branch(code, 1)
        first_option = len(code)
        code.extend(b"\x00")
        second_branch = len(code)
        code[first_branch + 6 : first_branch + 10] = second_branch.to_bytes(4, "little")
        second_branch = _state_21_result_branch(code, 2)
        second_option = len(code)
        code.extend(b"\x00")
        third_option = len(code)
        code.extend(b"\x00")
        code[second_branch + 6 : second_branch + 10] = third_option.to_bytes(4, "little")

        result = scan_code(bytes(code))

        self.assertEqual(len(result["routes"]), 1)
        consumer = result["routes"][0]["result_consumer"]
        self.assertEqual(consumer["kind"], "one_based_state_u16_21_branch_chain")
        self.assertEqual(consumer["result_values"], [1, 2, 3])
        self.assertEqual(consumer["option_entry_offsets"], [first_option, second_option, third_option])
        self.assertEqual(
            [row["source_offset"] for row in consumer["comparisons"]],
            [first_branch, second_branch],
        )
        self.assertEqual(consumer["native_producer"], "unresolved")

    def test_noncanonical_result_consumer_remains_unresolved(self) -> None:
        code = bytearray()
        _definition(code, 0, b"A", 1)
        _definition(code, 1, b"B", 2)
        code.extend(b"\x1d\x02\x28\xff\x00")
        branch = _state_21_result_branch(code, 2)
        code.extend(b"\x00")
        fallback = len(code)
        code.extend(b"\x00")
        code[branch + 6 : branch + 10] = fallback.to_bytes(4, "little")

        result = scan_code(bytes(code))

        consumer = result["routes"][0]["result_consumer"]
        self.assertEqual(consumer["kind"], "unresolved")
        self.assertEqual(consumer["reason"], "nonsequential_result_literal")

    def test_gated_result_matrix_is_projected_separately(self) -> None:
        code = bytearray()
        _definition(code, 0, b"A", 1)
        _definition(code, 1, b"B", 2)
        code.extend(b"\x1d\x02\x28\xff\x00")
        branches: list[tuple[int, int, int]] = []
        for result in (1, 2):
            for gate_value in (0, 1):
                branch = _gated_state_21_result_branch(code, result, "global_u8", 7, gate_value)
                option = len(code)
                code.extend(b"\x00")
                branches.append((branch, result, option))
        fallback = len(code)
        code.extend(b"\x00")
        for index, (branch, _result, _option) in enumerate(branches):
            next_branch = branches[index + 1][0] if index + 1 < len(branches) else fallback
            _patch_branch_target(code, branch, next_branch)

        result = scan_code(bytes(code))

        consumer = result["routes"][0]["result_consumer"]
        self.assertEqual(consumer["kind"], "gated_one_based_state_u16_21_branch_matrix")
        self.assertEqual(consumer["result_values"], [1, 2])
        self.assertEqual(
            consumer["gate"],
            {"storage": "global_u8", "index": 7, "values": [0, 1]},
        )
        self.assertEqual(
            [(row["result"], row["gate_value"]) for row in consumer["variants"]],
            [(1, 0), (1, 1), (2, 0), (2, 1)],
        )
        self.assertEqual(consumer["fallback_offset"], fallback)

    def test_native_secondary_state_13_dependency_remains_unresolved(self) -> None:
        code = bytearray()
        _definition(code, 0, b"A", 1)
        _definition(code, 1, b"B", 2)
        _definition(code, 2, b"C", 3)
        code.extend(b"\x1d\x02\x28\xff\x00")
        first = _state_21_result_branch(code, 1)
        code.extend(b"\x00")
        second = _gated_state_21_result_branch(code, 2, "state_u16", 13, 1)
        code.extend(b"\x00")
        fallback = len(code)
        code.extend(b"\x00")
        code[first + 6 : first + 10] = second.to_bytes(4, "little")
        _patch_branch_target(code, second, fallback)

        result = scan_code(bytes(code))

        consumer = result["routes"][0]["result_consumer"]
        self.assertEqual(consumer["kind"], "unresolved")
        self.assertEqual(consumer["reason"], "native_secondary_state_u16_13_gate")
        self.assertEqual(
            consumer["gate_dependencies"],
            [{"storage": "state_u16", "index": 13, "values": [1]}],
        )

    def test_single_definition_requires_exact_one_based_result_branch(self) -> None:
        code = bytearray()
        _definition(code, 3, b"A", 1)
        code.extend(b"\x1d\x02\x28\xff\x00")
        branch = _state_21_result_branch(code, 1)
        option = len(code)
        code.extend(b"\x00")
        fallback = len(code)
        code.extend(b"\x00")
        _patch_branch_target(code, branch, fallback)

        result = scan_code(bytes(code))

        consumer = result["routes"][0]["result_consumer"]
        self.assertEqual(consumer["kind"], "one_based_state_u16_21_branch_chain")
        self.assertEqual(consumer["native_producer"], "unresolved")
        self.assertEqual(consumer["result_storage"], "state_u16")
        self.assertEqual(consumer["result_values"], [1])
        self.assertEqual(consumer["option_entry_offsets"], [option])
        self.assertEqual(consumer["fallback_offset"], fallback)
        self.assertEqual(consumer["comparisons"][0]["source_offset"], branch)

    def test_single_definition_without_exact_branch_remains_unresolved(self) -> None:
        code = bytearray()
        _definition(code, 3, b"A", 1)
        code.extend(b"\x1d\x02\x28\xff\x00\x00")

        result = scan_code(bytes(code))

        consumer = result["routes"][0]["result_consumer"]
        self.assertEqual(consumer["kind"], "unresolved")
        self.assertEqual(consumer["reason"], "noncanonical_result_branch")

    def test_single_definition_rejects_same_true_and_false_target(self) -> None:
        code = bytearray()
        _definition(code, 3, b"A", 1)
        code.extend(b"\x1d\x02\x28\xff\x00")
        branch = _state_21_result_branch(code, 1)
        option = len(code)
        code.extend(b"\x00")
        _patch_branch_target(code, branch, option)

        result = scan_code(bytes(code))

        consumer = result["routes"][0]["result_consumer"]
        self.assertEqual(consumer["kind"], "unresolved")
        self.assertEqual(consumer["reason"], "single_result_targets_not_distinct")

    def test_malformed_body_is_rejected_without_a_route(self) -> None:
        code = bytearray(b"\x10\x02\x00\xff\x00")
        code.extend((12).to_bytes(4, "little"))
        code.extend(b"\x01AB")

        result = scan_code(bytes(code))

        self.assertEqual(result["command_10_candidates"], 1)
        self.assertEqual(result["exact_definitions"], 0)
        self.assertEqual(result["routes"], [])
        self.assertEqual(sum(result["rejected"].values()), 1)
        self.assertEqual(result["rejected_rows"][0]["source_offset"], 0)

    def test_non_routine_40_terminal_is_not_promoted(self) -> None:
        code = bytearray()
        _definition(code, 0, b"A", 1)
        code.extend(b"\x1d\x02\x17\xff\x00")

        result = scan_code(bytes(code))

        self.assertEqual(result["exact_definitions"], 1)
        self.assertEqual(result["routes"], [])

    def test_invalid_cp932_body_is_rejected(self) -> None:
        code = bytearray()
        _definition(code, 0, b"\x81", 1)
        code.extend(b"\x1d\x02\x28\xff\x00")

        result = scan_code(bytes(code))

        self.assertEqual(result["exact_definitions"], 0)
        self.assertEqual(result["rejected"], {"body_invalid_cp932": 1})


if __name__ == "__main__":
    unittest.main()
