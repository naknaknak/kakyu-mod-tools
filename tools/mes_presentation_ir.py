"""Enrich already-framed presentation records to instruction schema v45.

The partial decoder owns framing and operand parsing. This projection only
attaches the evidence metadata of ``mes_instruction_decoder.gd`` and decomposes
its existing typed operands; it never parses a second record stream.
"""

from __future__ import annotations

import copy
from typing import Any

from mes_partial_decoder import is_safe_entry_name


_AX_GRID = {"cell_rows": 10, "cell_columns": 32, "cell_record_bytes": 0x2C}
_AX_OWNER = {
    "consumer_selection_semantics": "bounds_checked_owner_vector_entry",
    "consumer_vector_offset": 0x4B578,
}
_AX_COMMON = {
    **_AX_GRID,
    "gameplay_state_effect": "none_observed",
    "tool_execution_semantics": "metadata_only_native_effect_omitted",
}
_AX_EXACT = {
    2: {
        **_AX_OWNER,
        "cell_state_offset": 0,
        "cell_state_value": 1,
        "native_dispatch_table": 0x00429338,
        "native_dispatch_branch": 0x004290DD,
        "native_consumer_virtual_slot": 0x10,
        "native_consumer_handler": 0x00410C10,
        "native_bounded_effect": "set_selected_ax_cell_state_to_1",
    },
    6: {
        **_AX_OWNER,
        "cell_state_offset": 0,
        "inactive_state": 0xFF,
        "cell_update_flag_offset": 0x10,
        "cell_update_flag_value": 1,
        "native_dispatch_table": 0x00429338,
        "native_dispatch_branch": 0x004291D3,
        "native_consumer_virtual_slot": 0x1C,
        "native_consumer_handler": 0x00410C80,
        "native_nested_cell_virtual_slot": 0x10,
        "native_nested_cell_handler": 0x00410C10,
        "native_bounded_effect": "set_update_flag_1_on_noninactive_10x32_ax_cells",
    },
    7: {
        "consumer_index": 0,
        "consumer_selection_semantics": "only_registered_consumer",
        "consumer_virtual_slot": 0x20,
        "cell_state_offset": 0,
        "inactive_state": 0xFF,
        "native_dispatch_branch": 0x0042920F,
        "native_consumer_handler": 0x00410CC0,
        "native_nested_cell_handler": 0x00410C30,
        "native_nested_cell_virtual_slot": 0x14,
        "native_bounded_effect": "set_all_10x32_cell_states_to_inactive_0xff",
    },
    8: {
        **_AX_OWNER,
        "native_dispatch_table": 0x00429338,
        "native_dispatch_branch": 0x0042924B,
        "native_activation_handler": 0x00411140,
        "native_wait_helper": 0x00411290,
        "native_initial_transition": "state_0_to_3",
        "native_ordinary_wait_transition": "state_3_to_4",
        "native_bounded_effect": "activate_bound_ax_cells_and_wait_for_terminal_states",
        "native_tick_and_rendering": "not_simulated",
    },
}
_COMPOSITION = {
    "type": "surface_composition_control",
    "presentation_subcommand": 10,
    "literal_mode": 1,
    "native_dispatch_route": [0x004284F8, 0x00428288, 0x0042828E],
    "native_adapter": 0x0042A860,
    "native_public_context_virtual_slot": 0x34,
    "native_handler_start": 0x0042A8B0,
    "native_handler_end_exclusive": 0x0042ABA0,
    "native_control_word_offset": 0x20BC,
    "native_control_word_guard": "snapshot_clear_bit_0x0002_restore",
    "native_surface_vector_offset": 0x128,
    "native_surface_indices": [11, 0, 10],
    "native_copy_helper": 0x004254D0,
    "native_copy_call_sites": [0x0042AA5E, 0x0042AACB, 0x0042AB5A],
    "native_optional_fill_path_taken": False,
    "native_bounded_effect": "opaque_surface_composition_then_host_refresh",
    "native_surface_content_and_lifetime": "unresolved",
    "gameplay_state_effect": "none_observed",
    "tool_execution_semantics": "metadata_only_pixel_effect_omitted",
}
_SURFACE_COMMON = {"native_adapter": 0x0042ABA0, "native_consumer": 0x0042AC30}
_SURFACE_ENDPOINTS = {
    "native_endpoint_semantics": "inclusive_width_height_expansion_confirmed",
    "gameplay_state_effect": "none_observed",
}
_SURFACE_REFRESH = {
    "refresh_origin_default": [0, 0],
    "native_operation_semantics": "conditional_attached_display_rectangle_refresh_confirmed",
    "native_record_parser": 0x0043E800,
    "native_record_workspace_clear_size": 0x546,
    "native_missing_record_values": "zero_after_bounded_workspace_clear",
    "native_out_of_range_target": 0x0042AFDD,
    "native_common_tail": 0x0042AFE5,
    "native_root_object_pointer": 0x014A0550,
    "native_root_object_vtable": 0x0047A42C,
    "native_root_object_virtual_slot": 0x14,
    "native_refresh_adapter": 0x004059E0,
    "native_attached_target_offset": 0xEC,
    "native_attached_target_null_effect": "return_without_refresh",
    "native_rectangle_helper": 0x00427640,
    "native_bitblt_iat": 0x00472028,
    "native_raster_operation": 0x00CC0020,
    "tool_execution_semantics": "native_display_refresh_omitted",
}
_MARKER_METADATA = {
    "voice_marker": {
        "native_consumer_semantics": "presentation_queue_and_stream_handoff_confirmed",
        "native_audible_output": "confirmed_directsound_play_dispatch",
        "native_audible_evidence": "static_executable_rtti_vtable_and_idirectsoundbuffer_abi",
        "native_host_device_output": "not_observed_by_static_audit",
    },
    "inline_script_execution": {
        "native_consumer_semantics": "archive_entry_load_inline_execute_restore_confirmed",
        "native_context_restore": "confirmed",
    },
    "ax_resource_marker": {
        "native_consumer_semantics": "data_arc_named_entry_load_confirmed",
        "native_loader_argument": "banked_i32[0][2]",
        "native_loader_argument_semantics": "engine_initialized_destination_buffer_pointer",
        "native_payload_semantics": "unresolved",
    },
    "mmo_resource_marker": {
        "native_adapter": 0x0042A640,
        "native_consumer": 0x0042A6A0,
        "native_surface_blit": 0x00425190,
        "native_default_origin_arguments": [-1, -1],
        "native_active_surface_state_offset": 0x20BA,
        "native_active_surface_storage": "banked_u16",
        "native_active_surface_bank": 0,
        "native_active_surface_storage_index": 1,
        "native_playback_semantics": "named_mmo_load_into_active_surface_confirmed",
        "native_active_surface_identity": "state_dependent",
    },
}
_BINDING_METADATA = {
    "consumer_virtual_slot": 0x08,
    "buffer_argument_semantics": "engine_initialized_destination_buffer_pointer",
    "binding_table_entries": 320,
    "binding_table_entry_bytes": 4,
    "binding_table_bytes": 0x500,
    "binding_offsets": "entry_relative_u32",
    "consumer_table_rows": 10,
    "consumer_table_columns": 32,
    "consumer_cell_bytes": 0x2C,
    "native_consumer_semantics": "ax_binding_table_cell_install_confirmed",
    "native_bounded_effect": "install_entry_relative_ax_record_pointer_into_consumer_cell",
    "native_rendering_semantics": "unresolved",
    "native_subrecord_semantics": "unresolved",
}


def _effect(operand: dict[str, Any]) -> str:
    operand.update(
        native_record_parser=0x0043E800,
        native_adapter=0x00429D70,
        native_dispatcher=0x00429E00,
    )
    records = operand["records"]
    if not (
        operand["selector_source"] == "literal"
        and operand["execution_selector"] == 0
        and len(records) == 3
        and records[1].get("type") == "string_record"
        and records[2].get("type") == "expression_record"
        and records[2]["value"].get("valid", True)
    ):
        return "effect_dispatch"
    raw_name = records[1]["value"]["raw_bytes"]
    if not (0 < len(raw_name) <= 255 and all(0x20 <= byte <= 0x7E for byte in raw_name)):
        return "effect_dispatch"
    source_name = raw_name.decode("ascii")
    if not is_safe_entry_name(source_name) or source_name.rpartition(".")[2].lower() != "wav":
        return "effect_dispatch"
    operand.update(
        type="effect_request",
        resource_kind="effect",
        resource_archive="se.arc",
        name=source_name.rpartition(".")[0].upper() + ".WAV",
        source_name=source_name,
        channel_expression=records[2]["value"],
        native_effect_semantics="named_effect_request_host_playback_not_executed",
    )
    return "effect_request"


def _ax_control(operand: dict[str, Any]) -> str:
    selector = operand["execution_selector"]
    operand.update(_AX_COMMON)
    if "native_record_count" not in operand:
        operand.update(_AX_EXACT[selector])
        return f"typed_presentation_subcommand_3_selector_{selector}_literal_record"
    operand.update(_AX_OWNER)
    operand.update(
        cell_state_offset=0,
        native_dispatch_table=0x00429338,
        native_dispatch_branch=0x0042909F if selector == 1 else 0x004290DD,
        native_consumer_virtual_slot=0x0C if selector == 1 else 0x10,
        native_consumer_handler=0x00410BF0 if selector == 1 else 0x00410C10,
        native_bounded_effect=f"set_selected_ax_cell_state_to_{selector - 1}",
        native_state_transition_semantics=(
            "activate_current_cell_cursor"
            if selector == 1
            else "request_inactive_at_wait_boundary_not_immediate_freeze"
        ),
        native_record_parser=0x0043E800,
    )
    return f"typed_presentation_subcommand_3_selector_{selector}_literal_record_list"


def _surface(operand: dict[str, Any], op: str) -> None:
    operand.update(_SURFACE_COMMON)
    mode = operand["mode"]
    expressions = operand["expressions"]
    if op == "surface_dispatch_unresolved":
        operand.update(
            native_dispatch_max_mode=7,
            native_out_of_range_target=0x0042AFDD,
            native_common_tail=0x0042AFE5,
            native_dispatch_semantics=(
                "out_of_range_mode_skips_switch_body_then_reaches_common_tail"
                if operand["mode_source"] == "literal" and mode > 7
                else "mode_or_default_argument_effect_unresolved"
            ),
            native_effect_semantics="unresolved_not_executed",
            gameplay_state_effect="unresolved_not_applied",
            tool_execution_semantics="native_effects_omitted",
        )
        return
    operand.pop("mode_source", None)
    operand.update(_SURFACE_ENDPOINTS)
    # The analysis index walks dictionary values in insertion order. These
    # aliases must follow the expression list in the authority's coordinate
    # order so repeated state references retain that same order.
    if op == "surface_display_refresh":
        operand.update(
            inclusive_left=expressions[1], inclusive_top=expressions[2],
            inclusive_right=expressions[3], inclusive_bottom=expressions[4],
        )
        operand.update(copy.deepcopy(_SURFACE_REFRESH))
        return
    semantics = (
        "opaque_rectangle_copy_confirmed",
        "rgb_chroma_key_rectangle_copy_confirmed",
        "active_surface_rectangle_fill_confirmed",
    )
    helpers = (0x004254D0, 0x004255D0, 0x00425B10)
    operand.update(
        source_x=expressions[1],
        source_y=expressions[2],
        inclusive_right=expressions[3],
        inclusive_bottom=expressions[4],
        native_operation_semantics=semantics[mode],
        native_pixel_helper=helpers[mode],
        native_surface_vector_offset=0x128,
        native_pixel_bytes=3,
        tool_execution_semantics="native_pixel_effect_omitted",
    )
    if mode in (0, 1):
        operand.update(
            source_surface_index=expressions[5],
            destination_x=expressions[6],
            destination_y=expressions[7],
        )
        if operand["record_count"] == 9:
            operand["destination_surface_index"] = expressions[8]
        else:
            operand["destination_surface_default"] = 0
        if mode == 1:
            operand["native_transparency_key_source"] = "presentation_context_rgb_key"
    else:
        operand.update(
            native_target_surface="active_surface_state_index",
            native_active_surface_state_offset=0x20BA,
            native_fill_color_source="presentation_context_rgb_color",
        )


def enrich_presentation(
    instruction: dict[str, Any], code: bytes, limit: int
) -> dict[str, Any]:
    """Return v45 presentation evidence without changing framing or the input.

    ``instruction`` is the canonical snake_case projection of a successfully
    decoded record, including canonical expressions and CP932 raw bytes.
    Bytes are consulted only to preserve a previously parsed resource name.
    """
    op = instruction.get("op")
    if instruction.get("command_id") not in (0x09, 0x0D) or op == "statement_separator":
        return instruction
    known_ops = {
        "effect_dispatch", "effect_request", "ax_presentation_control",
        "surface_composition_control", "surface_operation", "surface_display_refresh",
        "surface_dispatch_unresolved", "ax_presentation_binding", "named_state_transfer",
        *_MARKER_METADATA,
    }
    if op not in known_ops:
        return instruction
    result = dict(instruction)
    operand = dict(instruction["operands"][0])
    result["operands"] = [operand]
    if op in ("effect_dispatch", "effect_request"):
        result["op"] = _effect(operand)
    elif op in ("ax_presentation_control", "surface_composition_control"):
        if operand["presentation_subcommand"] == 10:
            operand = copy.deepcopy(_COMPOSITION)
            result["operands"] = [operand]
            result["op"] = "surface_composition_control"
            result["native_stream_consumption"] = "typed_presentation_subcommand_10_mode_1_literal_record"
        else:
            result["native_stream_consumption"] = _ax_control(operand)
    elif op in ("surface_operation", "surface_display_refresh", "surface_dispatch_unresolved"):
        _surface(operand, op)
    elif op == "ax_presentation_binding":
        operand.update(_BINDING_METADATA)
        result["native_stream_consumption"] = "typed_presentation_subcommand_3_selector_0_ax_binding_record_list"
    elif op == "named_state_transfer":
        operand.update(
            native_consumer_semantics="named_relative_offset_restore_confirmed",
            native_copy_scope="relative_offsets_only",
            native_source_record_contents="unresolved",
        )
    elif op in _MARKER_METADATA:
        name = operand.get("source_name", operand["name"])
        start = operand["source_offset"]
        end = start + len(name)
        if not (instruction["source_offset"] <= start <= end < instruction["end_offset"] <= limit <= len(code)):
            raise ValueError("Presentation resource name is outside its framed instruction.")
        raw_name = code[start:end]
        encoding = "latin-1" if op == "mmo_resource_marker" else "ascii"
        if raw_name != name.encode(encoding):
            raise ValueError("Presentation resource name disagrees with its framed source bytes.")
        operand.update(raw_bytes=raw_name, raw_hex=raw_name.hex())
        operand.update(copy.deepcopy(_MARKER_METADATA[op]))
        if op == "ax_resource_marker":
            result["native_stream_consumption"] = "typed_presentation_subcommand_8_selector_0_record_list"
    return result
