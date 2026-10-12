from __future__ import annotations

import hashlib
import sys
import unittest
from pathlib import Path
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

from audit_mes_runtime_trace_terminal import (  # noqa: E402
    bind_choice_source,
    bind_choice_successor_source,
    build_report,
    find_root_replacement,
    summarize_choice,
)
from payload_values import routine_40_selection, state_u16_expression  # noqa: E402


def event(sequence: int, event_id: str, **captures: object) -> dict[str, object]:
    return {
        "sequence": sequence,
        "id": event_id,
        "evidence": event_id in {"command_0e_receiver_call", "target_execution_start"},
        "captures": captures,
    }


def fake_capture() -> dict[str, object]:
    library_base = 0x500000
    events = [
        event(
            0,
            "command_0e_receiver_call",
            target_name="eventb03.mes",
            active_state=0x2000,
            public_context_receiver=0x1000,
        ),
        event(1, "target_execution_start"),
        event(2, "mes_archive_loader_entry", filename="b_pic.mes"),
        event(3, "stream_installer_entry"),
        event(
            4,
            "command_0e_receiver_call",
            target_name="machi.mes",
            active_state=0x2000,
            public_context_receiver=0x1000,
        ),
        event(5, "mes_archive_loader_entry", filename="machi.mes"),
        event(6, "mes_archive_lookup_call", filename="machi.mes"),
        event(7, "stream_installer_entry"),
        event(8, "stream_coordinate_write"),
        event(9, "command_0e_flag_writer_1", target_name="machi.mes"),
        {
            **event(
                10,
                "target_choice_result",
                active_instruction_pointer=library_base + 0x1CA0,
                active_stream_offset=0x1CA0,
                context=library_base,
                one_based_result=3,
                result_path="selected_control_store",
                stream_binding="nested_stream_unresolved",
            ),
            "evidence": True,
        },
        {
            **event(
                11,
                "target_choice_result",
                active_instruction_pointer=library_base + 0x1CA0,
                active_stream_offset=0x1CA0,
                context=library_base,
                one_based_result=3,
                result_path="command_12_slot_18_store",
                state_u16_18_before=0,
                state_u16_21_before=16,
                stream_binding="nested_stream_unresolved",
            ),
            "evidence": True,
        },
        {
            **event(
                12,
                "target_choice_result",
                active_instruction_pointer=library_base + 0x1CD0,
                active_stream_offset=0x1CD0,
                context=library_base,
                one_based_result=0xFFFF,
                result_path="command_12_slot_18_store",
                state_u16_18_before=3,
                state_u16_21_before=3,
                stream_binding="nested_stream_unresolved",
            ),
            "evidence": True,
        },
    ]
    return {
        "schema": "kakyu_mes_runtime_trace_capture/v3",
        "target_entry": "EVENTB03.MES",
        "target_qualified": True,
        "stop_reason": "operator_stop",
        "events": events,
        "source": {
            "source_unchanged": True,
            "archive_sha256": "a" * 64,
            "target_entry_sha256": "b" * 64,
            "runtime_sha256": "c" * 64,
            "host_slice_anchor_sha256": "d" * 64,
        },
        "proof_obligations": [
            {"id": name, "complete": True}
            for name in (
                "target_identity",
                "host_consumption_timing",
                "archive_lookup",
                "stream_installation",
                "intro_coordinate",
                "caller_context_ownership",
            )
        ]
        + [{"id": "return_or_terminal", "complete": False}],
        "target_choice_results": [
            {"one_based_result": 3, "result_path": "selected_control_store"},
            {
                "one_based_result": 3,
                "result_path": "command_12_slot_18_store",
                "state_u16_18_before": 0,
                "state_u16_21_before": 16,
            },
            {
                "one_based_result": 0xFFFF,
                "result_path": "command_12_slot_18_store",
                "state_u16_18_before": 3,
                "state_u16_21_before": 3,
            },
        ],
        "target_native_path_observations": [
            {
                "probe_id": "command_1d_shared_script_call",
                "active_instruction_pointer": library_base + 0x10,
                "active_stream_offset": 0x10,
                "destination_first_dword": 0,
                "caller_stream_binding": "target_code_base_relative",
                "caller_code_base": 0x600000,
            },
            {
                "probe_id": "command_1d_shared_script_call",
                "active_instruction_pointer": library_base + 0x20,
                "active_stream_offset": 0x20,
                "destination_first_dword": 0,
                "caller_stream_binding": "caller_stream_unresolved",
                "caller_code_base": library_base,
            },
            {
                "probe_id": "command_1d_shared_script_call",
                "active_instruction_pointer": library_base + 0x30,
                "active_stream_offset": 0x30,
                "destination_first_dword": 0,
                "caller_stream_binding": "target_code_base_relative",
                "caller_code_base": 0x600000,
            },
        ],
    }


def fake_library() -> bytes:
    code = bytearray(0x1D80)
    code[0x1C95:0x1CA0] = routine_40_selection(0)
    code[0x1CA0:0x1CA6] = bytes.fromhex("04158012ff00")
    code[0x1CC4:0x1CD0] = routine_40_selection(state_u16_expression(21))
    code[0x1CD0:0x1CD5] = bytes.fromhex("0ced1c0000")
    return (0).to_bytes(4, "little") + bytes(code)


def fake_handoffs() -> list[dict[str, object]]:
    return [
        {
            "source_entry": "EVENTB03.MES",
            "source_offset": offset,
            "end_offset": offset + 13,
            "target_entry": "machi.mes",
            "envelope_sha256": "e" * 64,
        }
        for offset in (0x1BB6, 0x26F4, 0x3D46)
    ]


def choice_condition(value: int) -> dict[str, object]:
    return {
        "ast": {
            "type": "binary",
            "op": "equal",
            "lhs": {
                "type": "state_ref",
                "storage": "state_u16",
                "index": {"type": "literal", "value": 21},
            },
            "rhs": {"type": "literal", "value": value},
        }
    }


def fake_target_cfg() -> dict[str, object]:
    blocks = [
        {"id": "guard1", "instructionOffsets": [0x12DC]},
        {"id": "route1", "instructionOffsets": [0x1BB6]},
        {"id": "guard2", "instructionOffsets": [0x1BD2]},
        {"id": "route2", "instructionOffsets": [0x26F4]},
        {"id": "guard3", "instructionOffsets": [0x2710]},
        {"id": "route3", "instructionOffsets": [0x3D46]},
        {"id": "exit", "instructionOffsets": [0x3D5D]},
    ]
    edges: list[dict[str, object]] = []
    for guard, route, fallback, offset, value in (
        ("guard1", "route1", "guard2", 0x12DC, 1),
        ("guard2", "route2", "guard3", 0x1BD2, 2),
        ("guard3", "route3", "exit", 0x2710, 3),
    ):
        for edge_type, target in (
            ("condition_true", route),
            ("condition_false", fallback),
        ):
            edges.append(
                {
                    "type": edge_type,
                    "source": guard,
                    "sourceOffset": offset,
                    "condition": choice_condition(value),
                    "target": target,
                    "targetOffset": next(
                        row["instructionOffsets"][0]
                        for row in blocks
                        if row["id"] == target
                    ),
                    "resolved": True,
                }
            )
        edges.append(
            {
                "type": "transfer",
                "source": route,
                "sourceOffset": next(
                    row["instructionOffsets"][0]
                    for row in blocks
                    if row["id"] == route
                ),
                "target": "exit",
                "targetOffset": 0x3D5D,
                "resolved": True,
            }
        )
    return {
        "schema": "ai5_mes_basic_block_ir/v6",
        "basicBlocks": blocks,
        "blockEdges": edges,
    }


class MesRuntimeTraceTerminalAuditTests(unittest.TestCase):
    def test_complete_same_owner_handoff_is_root_replacement(self) -> None:
        capture = fake_capture()
        result = find_root_replacement(capture)
        self.assertEqual("machi.mes", result["successor_entry"])
        self.assertEqual("offline_reclassified", result["classification"])
        self.assertEqual(4, result["command_sequence"])
        self.assertEqual(9, result["terminal_sequence"])

    def test_nested_loader_is_not_enough(self) -> None:
        capture = fake_capture()
        capture["events"] = list(capture["events"][:4])
        with self.assertRaisesRegex(ValueError, "no complete"):
            find_root_replacement(capture)

    def test_choice_requires_mirror_reset_and_expected_result(self) -> None:
        capture = fake_capture()
        result = summarize_choice(capture, 3)
        self.assertEqual(3, result["one_based_result"])
        self.assertTrue(result["slot_18_reset_to_ffff"])
        with self.assertRaisesRegex(ValueError, "does not match"):
            summarize_choice(capture, 2)

    def test_choice_source_binds_to_library_routine_40(self) -> None:
        binding = bind_choice_source(fake_capture(), fake_library(), 3)
        self.assertEqual("LIBLARY.LIB", binding["source_entry"])
        self.assertEqual("library_code_base_relative", binding["stream_binding"])
        self.assertEqual(0x1C95, binding["first_native_record"]["source_offset"])
        self.assertEqual(0x1CA0, binding["selected_control_observation"]["source_offset"])
        self.assertEqual(0x1CD0, binding["slot_18_reset_observation"]["source_offset"])
        self.assertEqual([0x10, 0x20, 0x30], binding["matched_command_1d_anchor_offsets"])

    def test_choice_source_rejects_unbound_stream_base(self) -> None:
        capture = fake_capture()
        capture["target_native_path_observations"] = []
        with self.assertRaisesRegex(ValueError, "not sufficiently bound"):
            bind_choice_source(capture, fake_library(), 3)

    def test_choice_source_rejects_changed_record(self) -> None:
        library = bytearray(fake_library())
        library[4 + 0x1C9D] = 1
        with self.assertRaisesRegex(ValueError, "first routine-40"):
            bind_choice_source(fake_capture(), bytes(library), 3)

    def test_choice_successor_binds_result_three_to_third_handoff(self) -> None:
        target = b"synthetic eventb03"
        handoffs = fake_handoffs()
        for row in handoffs:
            row["source_entry_sha256"] = hashlib.sha256(target).hexdigest()
        with patch(
            "audit_mes_runtime_trace_terminal.mes_basic_block_ir_v6.decode_mes",
            return_value=fake_target_cfg(),
        ):
            binding = bind_choice_successor_source(target, handoffs, 3)
        self.assertEqual(0x3D46, binding["selected_handoff"]["source_offset"])
        self.assertEqual(0x3D5D, binding["common_exit_offset"])
        self.assertEqual(
            [0x1BB6, 0x26F4, 0x3D46],
            [row["successor_source_offset"] for row in binding["result_routes"]],
        )

    def test_choice_successor_rejects_changed_dispatch_slot(self) -> None:
        target = b"synthetic eventb03"
        handoffs = fake_handoffs()
        cfg = fake_target_cfg()
        for edge in cfg["blockEdges"][:2]:
            edge["condition"]["ast"]["lhs"]["index"]["value"] = 20
        with patch(
            "audit_mes_runtime_trace_terminal.mes_basic_block_ir_v6.decode_mes",
            return_value=cfg,
        ), self.assertRaisesRegex(ValueError, r"state_u16\[21\]"):
            bind_choice_successor_source(target, handoffs, 3)

    def test_report_promotes_only_host_activation_scope(self) -> None:
        capture = fake_capture()
        root = find_root_replacement(capture)
        choice = summarize_choice(capture, 3)
        choice_source = bind_choice_source(capture, fake_library(), 3)
        choice_successor = {
            "selected_handoff": {"source_offset": 0x3D46},
        }
        report = build_report(
            capture,
            root,
            fake_handoffs(),
            choice,
            choice_source,
            choice_successor,
            capture_name="capture.json",
            archive_name="mes.arc",
            archive_sha256="a" * 64,
        )
        self.assertEqual("kakyu_mes_runtime_trace_terminal_audit/v3", report["schema"])
        self.assertTrue(report["promotion_ready"])
        self.assertEqual("command_0e_host_activation", report["promotion_scope"])
        self.assertEqual(0x3D46, report["root_replacement"]["exact_source_offset"])
        self.assertEqual(
            "LIBLARY.LIB:0x1C95..0x1CA0",
            report["choice"]["source_coordinate"],
        )
        self.assertNotIn("choice_source_coordinate", report["unresolved_boundaries"])
        self.assertNotIn(
            "exact_successor_handoff_source_offset", report["unresolved_boundaries"]
        )
        self.assertNotIn("events", report)
        self.assertNotIn("state_snapshots", report)


if __name__ == "__main__":
    unittest.main()
