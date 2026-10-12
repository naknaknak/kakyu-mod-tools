from __future__ import annotations

import sys
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

import mes_basic_block_ir_v6  # noqa: E402
from audit_mes_def_routes import _unique_instructions  # noqa: E402
from audit_mes_routine40_groups import (  # noqa: E402
    bind_default_continuation_context,
    scan_group_entry,
    scan_host_activation_payload,
    scan_result_dispatch,
)


def _group_clear(code: bytearray, selector: int) -> int:
    offset = len(code)
    code.extend(bytes([0x1B, 0x02, selector, 0xFF, 0x00]))
    return offset


def _definition(code: bytearray, definition_id: int, text: bytes = b"A") -> tuple[int, int]:
    offset = len(code)
    code.extend(bytes([0x10, 0x02, definition_id, 0xFF, 0x00]))
    code.extend(b"\0\0\0\0")
    code.extend(b"\x01" + text + b"\0\0")
    target = len(code)
    code[offset + 5 : offset + 9] = target.to_bytes(4, "little")
    return offset, target


def _guard_global_u8_equal_one(code: bytearray, index: int, target: int = 0) -> int:
    offset = len(code)
    code.extend(bytes([0x0B, 0xF3, index & 0xFF, (index >> 8) & 0xFF, 0x01, 0xEF, 0xFF]))
    code.extend(target.to_bytes(4, "little"))
    return offset


def _patch_branch_target(code: bytearray, branch_offset: int, target: int) -> None:
    code[branch_offset + 7 : branch_offset + 11] = target.to_bytes(4, "little")


def _result_branch(code: bytearray, state_index: int, value: int) -> int:
    offset = len(code)
    code.extend(bytes([0x0B, 0x80, state_index, value, 0xEF, 0xFF]))
    code.extend(b"\0\0\0\0")
    return offset


def _compound_result_branch(code: bytearray, first_result: int, secondary_result: int) -> int:
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
                secondary_result,
                0xEF,
                0xE6,
                0xFF,
            ]
        )
    )
    code.extend(b"\0\0\0\0")
    return offset


def _patch_result_target(code: bytearray, branch_offset: int, target: int) -> None:
    target_offset = branch_offset + (11 if code[branch_offset + 6] == 13 else 6)
    code[target_offset : target_offset + 4] = target.to_bytes(4, "little")


def _dispatch_fixture(group_three_count: int = 2) -> tuple[bytes, int, list[dict]]:
    code = bytearray(b"\x1f\x01\0\0\0")
    resume = 0
    first_one = _result_branch(code, 21, 1)
    secondary_one = _result_branch(code, 13, 1)
    secondary_two = _result_branch(code, 13, 2)
    first_two = _result_branch(code, 21, 2)
    first_three = _compound_result_branch(code, 3, 1)
    secondary_three_two = _compound_result_branch(code, 3, 2)
    terminal = len(code)
    loop = terminal + 5
    code.extend(b"\x0c" + loop.to_bytes(4, "little") + b"\0")
    _patch_result_target(code, first_one, first_two)
    _patch_result_target(code, secondary_one, secondary_two)
    _patch_result_target(code, secondary_two, first_two)
    _patch_result_target(code, first_two, first_three)
    _patch_result_target(code, first_three, secondary_three_two)
    _patch_result_target(code, secondary_three_two, terminal)
    groups = [
        {"selector": 0, "registration_count": 3},
        {"selector": 1, "registration_count": 2},
        {"selector": 2, "registration_count": 0},
        {"selector": 3, "registration_count": group_three_count},
    ]
    return bytes(code), resume, groups


def _decode(code: bytes) -> dict[int, dict]:
    data = (0).to_bytes(4, "little") + code
    decoded = mes_basic_block_ir_v6.decode_mes(data, {"entry": "TEST.MES"})
    return _unique_instructions(decoded)[0]


class Routine40GroupRouteAuditTests(unittest.TestCase):
    def test_finds_only_exact_command_0e_host_activations(self) -> None:
        target = b"43c.mes"
        code = bytearray(b"\x17\0\0\0\0")
        code.extend(b"\x0e\x01" + target + b"\0\0")
        code.extend(b"\x0f\x01" + target + b"\0\0")
        code.extend(b"\x0e\x01other.mes\0\0")
        data = (1).to_bytes(4, "little") + (0).to_bytes(4, "little") + bytes(code)

        rows = scan_host_activation_payload(data, "CALLER.MES", "43C.MES")

        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0]["source_entry"], "CALLER.MES")
        self.assertEqual(rows[0]["owner_address_entry_index"], 0)
        self.assertEqual(rows[0]["command_id"], 0x0E)
        self.assertEqual(rows[0]["target_entry"], "43c.mes")
        self.assertEqual(rows[0]["callee_start_coordinate"], "unresolved")
        self.assertNotIn("other.mes", str(rows))

    def test_binds_constant_true_fallback_to_address_entry_owner(self) -> None:
        code, resume, groups = _dispatch_fixture()
        changed = bytearray(code)
        terminal = next(
            offset for offset, row in _decode(code).items() if int(row["commandId"]) == 0x0C
        )
        destination = len(changed)
        branch_target = destination + 7
        changed.extend(b"\x0b\x01\xff" + branch_target.to_bytes(4, "little") + b"\0")
        changed[terminal + 1 : terminal + 5] = destination.to_bytes(4, "little")
        by_offset = _decode(bytes(changed))
        dispatch = scan_result_dispatch(by_offset, resume, groups)

        context = bind_default_continuation_context(
            by_offset,
            [0, destination],
            len(changed),
            dispatch,
        )

        self.assertTrue(context["ok"])
        self.assertEqual(context["owner_address_entry_index"], 1)
        self.assertEqual(context["destination_offset"], destination)
        self.assertEqual(context["condition_literal"], 1)
        self.assertEqual(context["branch_target_offset"], branch_target)
        self.assertEqual(context["stored_path"], "constant_true_fallthrough")
        self.assertEqual(context["gameplay_meaning"], "dispatcher_reentry_unresolved")

    def test_collects_complete_two_stage_result_dispatch(self) -> None:
        code, resume, groups = _dispatch_fixture()

        result = scan_result_dispatch(_decode(code), resume, groups)

        self.assertTrue(result["ok"])
        self.assertEqual(result["first_result_values"], [1, 2, 3])
        self.assertEqual(result["first_result_index"], 21)
        self.assertEqual(result["secondary_result_index"], 13)
        self.assertTrue(result["complete_secondary_mapping"])
        self.assertEqual(
            [row["secondary_result_values"] for row in result["groups"]],
            [[1, 2], [], [1, 2]],
        )
        self.assertEqual(
            [row["first_branch_kind"] for row in result["groups"]],
            ["first_only", "first_only", "first_and_secondary"],
        )
        terminal = next(
            offset for offset, row in _decode(code).items() if int(row["commandId"]) == 0x0C
        )
        self.assertEqual(
            result["default_continuation"],
            {
                "kind": "unconditional_code_coordinate_transfer",
                "source_offset": terminal,
                "destination_offset": terminal + 5,
                "backward_transfer": False,
                "covers_unmatched_or_out_of_range_results": True,
                "gameplay_meaning": "unresolved",
            },
        )

    def test_retains_unmatched_registered_secondary_result(self) -> None:
        code, resume, groups = _dispatch_fixture(group_three_count=3)

        result = scan_result_dispatch(_decode(code), resume, groups)

        self.assertTrue(result["ok"])
        self.assertFalse(result["complete_secondary_mapping"])
        terminal = next(
            offset for offset, row in _decode(code).items() if int(row["commandId"]) == 0x0C
        )
        self.assertEqual(
            result["incomplete_secondary_mappings"],
            [
                {
                    "first_result": 3,
                    "unmatched_secondary_results": [3],
                    "stored_fallback_source_offset": terminal,
                    "stored_fallback_destination_offset": terminal + 5,
                }
            ],
        )

    def test_missing_default_continuation_fails_closed(self) -> None:
        code, resume, groups = _dispatch_fixture()
        changed = bytearray(code)
        terminal = next(
            offset for offset, row in _decode(code).items() if int(row["commandId"]) == 0x0C
        )
        changed[terminal] = 0x00

        result = scan_result_dispatch(_decode(bytes(changed)), resume, groups)

        self.assertFalse(result["ok"])
        self.assertEqual(result["reason"], "missing_result_default_continuation")

    def test_default_continuation_destination_must_decode(self) -> None:
        code, resume, groups = _dispatch_fixture()
        changed = bytearray(code)
        terminal = next(
            offset for offset, row in _decode(code).items() if int(row["commandId"]) == 0x0C
        )
        changed[terminal + 1 : terminal + 5] = (len(changed) + 10).to_bytes(4, "little")

        result = scan_result_dispatch(_decode(bytes(changed)), resume, groups)

        self.assertFalse(result["ok"])
        self.assertEqual(result["reason"], "result_default_destination_not_decoded")

    def test_nonsequential_first_result_fails_closed(self) -> None:
        code, resume, groups = _dispatch_fixture()
        changed = bytearray(code)
        first_two = 5 + 10 + 10 + 10
        changed[first_two + 3] = 3

        result = scan_result_dispatch(_decode(bytes(changed)), resume, groups)

        self.assertFalse(result["ok"])
        self.assertEqual(result["reason"], "nonsequential_first_result_branch")

    def test_group_selector_mismatch_fails_closed(self) -> None:
        code, resume, groups = _dispatch_fixture()
        groups[-1]["selector"] = 4

        result = scan_result_dispatch(_decode(code), resume, groups)

        self.assertFalse(result["ok"])
        self.assertEqual(result["reason"], "group_selectors_do_not_match_first_stage_results")

    def test_nonempty_group_without_secondary_branch_fails_closed(self) -> None:
        code, resume, groups = _dispatch_fixture()
        groups[2]["registration_count"] = 1

        result = scan_result_dispatch(_decode(code), resume, groups)

        self.assertFalse(result["ok"])
        self.assertEqual(result["reason"], "missing_secondary_result_branch")

    def test_empty_group_with_secondary_branch_fails_closed(self) -> None:
        code, resume, groups = _dispatch_fixture()
        groups[1]["registration_count"] = 0

        result = scan_result_dispatch(_decode(code), resume, groups)

        self.assertFalse(result["ok"])
        self.assertEqual(result["reason"], "empty_group_has_secondary_result_branch")

    def test_collects_unconditional_conditional_and_empty_groups_without_text(self) -> None:
        code = bytearray()
        clear_zero = _group_clear(code, 0)
        first, _ = _definition(code, 0, b"FIRST")
        clear_one = _group_clear(code, 1)
        clear_two = _group_clear(code, 2)
        guard = _guard_global_u8_equal_one(code, 376)
        second, second_target = _definition(code, 3, b"SECOND")
        _patch_branch_target(code, guard, second_target)
        routine = len(code)
        code.extend(b"\x1d\x02\x28\xff\x00")

        result = scan_group_entry(bytes(code), _decode(bytes(code)), 0, len(code))

        self.assertTrue(result["ok"])
        self.assertEqual(result["group_selectors"], [0, 1, 2])
        self.assertEqual(result["empty_group_selectors"], [1])
        self.assertEqual(result["registration_count"], 2)
        self.assertEqual(result["routine_40_offsets"], [routine])
        self.assertEqual(result["routine_40_route"]["source_offset"], second)
        self.assertEqual(result["routine_40_route"]["definition_count"], 1)
        groups = result["groups"]
        self.assertEqual(groups[0]["clear_offset"], clear_zero)
        self.assertEqual(groups[0]["definition_ids"], [0])
        self.assertEqual(groups[0]["registrations"][0]["source_offset"], first)
        self.assertEqual(groups[0]["registrations"][0]["guard"], {"kind": "unconditional"})
        self.assertEqual(groups[1]["clear_offset"], clear_one)
        self.assertEqual(groups[1]["definition_ids"], [])
        self.assertEqual(groups[2]["clear_offset"], clear_two)
        self.assertEqual(groups[2]["definition_ids"], [3])
        self.assertEqual(groups[2]["conditional_registration_count"], 1)
        self.assertEqual(
            groups[2]["registrations"][0]["guard"],
            {
                "kind": "state_predicate",
                "storage": "global_u8",
                "index": 376,
                "operator": "equal",
                "value": 1,
                "source_offset": guard,
                "false_target_offset": second_target,
            },
        )
        self.assertNotIn("FIRST", str(result))
        self.assertNotIn("SECOND", str(result))
        self.assertEqual(
            result["playback_promotion"],
            "blocked_native_input_and_gameplay_mapping_unresolved",
        )

    def test_guard_must_skip_the_same_definition_body(self) -> None:
        code = bytearray()
        _group_clear(code, 1)
        guard = _guard_global_u8_equal_one(code, 10)
        _definition(code, 0)
        _patch_branch_target(code, guard, len(code) + 1)
        code.extend(b"\x1d\x02\x28\xff\x00")

        result = scan_group_entry(bytes(code), _decode(bytes(code)), 0, len(code))

        self.assertFalse(result["ok"])
        self.assertEqual(result["issues"][0]["reason"], "guard_false_target_mismatch")

    def test_registration_before_group_fails_closed(self) -> None:
        code = bytearray()
        _definition(code, 0)
        code.extend(b"\x1d\x02\x28\xff\x00")

        result = scan_group_entry(bytes(code), _decode(bytes(code)), 0, len(code))

        self.assertFalse(result["ok"])
        self.assertEqual(result["issues"], [{"source_offset": 0, "reason": "registration_without_group"}])

    def test_repeated_group_clear_is_rejected(self) -> None:
        code = bytearray()
        _group_clear(code, 0)
        second = _group_clear(code, 0)
        code.extend(b"\x1d\x02\x28\xff\x00")

        result = scan_group_entry(bytes(code), _decode(bytes(code)), 0, len(code))

        self.assertFalse(result["ok"])
        self.assertEqual(
            result["issues"],
            [{"source_offset": second, "reason": "repeated_group_clear", "selector": 0}],
        )


if __name__ == "__main__":
    unittest.main()
