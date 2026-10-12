extends "res://tests/test_case.gd"

const DecoderScript := preload("res://content_core/mes_instruction_decoder.gd")


func _ready() -> void:
	var decoder := DecoderScript.new()
	var code := PackedByteArray()
	code.append_array(PackedByteArray([0x17, 2, 0, 0, 0]))
	code.append_array(PackedByteArray([0x01, 0x41, 0x42, 0]))
	code.append_array(PackedByteArray([0x0B, 0xF1, 1, 0, 0xFF, 0x20, 0, 0, 0]))
	code.append_array(PackedByteArray([0x0C, 0x30, 0, 0, 0]))
	code.append_array(PackedByteArray([0x0F, 1, 0x54, 0x45, 0x53, 0x54, 0, 2, 5, 0xFF, 0]))
	code.append_array(PackedByteArray([0x82, 0xA0, 0]))
	code.append_array(PackedByteArray([0x07, 2, 0xFF, 1, 3, 0xFF, 0]))
	code.append_array(PackedByteArray([0x08, 4, 0xFF, 2, 5, 0xFF, 0]))
	code.append_array(PackedByteArray([0x03, 0x34, 0x12, 20, 0xFF, 1, 4, 0xFF, 0]))
	code.append(0x0D)
	code.append_array(PackedByteArray([0x09, 0xFF, 0x01, 0x44, 0x2E, 0x4D, 0x4D, 0x4F, 0x00, 0x00]))
	code.append_array(PackedByteArray([0x07, 0x01, 0xFF, 0x00, 0x07, 0xFF, 0x00]))
	code.append_array(PackedByteArray([0x09, 0x01, 0x00, 0x21, 0xFF, 0x00]))
	code.append_array(PackedByteArray([0x1F, 0x15, 0x00, 0x00, 0x00]))
	code.append(0x0D)
	code.append_array(PackedByteArray([0x0E, 0xFF, 0x02, 0x00, 0xF9, 0x00, 0x00, 0xA0, 0x00, 0xE0, 0xF1, 0x40, 0x0B, 0xE0, 0xFF, 0x00]))
	code.append_array(PackedByteArray([0x13, 0xFF]))
	code.append_array(PackedByteArray([0x07, 0x02, 0xFF, 0x00, 0x02, 0xA0, 0x00, 0xF1, 0x80, 0x00, 0xE9, 0xFF, 0x00]))
	code.append(0x0D)
	code.append_array(PackedByteArray([0x07, 0xFF, 0x02, 0x02, 0xFF, 0x01]))
	code.append_array("d0977.ogg".to_ascii_buffer())
	code.append_array(PackedByteArray([0x00, 0x02, 0x00, 0xFF, 0x00]))
	code.append_array(PackedByteArray([0x07, 0x02, 0xFF, 0x00, 0x02, 0xA0, 0x00, 0xF1, 0x7F, 0xFF, 0xE8, 0xFF, 0x00]))
	var region := decoder.decode_region(code, 0, code.size())
	_check(region.ok, "confirmed instruction forms decode as one region")
	if region.ok:
		var instructions: Array = region.instructions
		_check(instructions.size() == 18, "instruction count reflects the native presentation record boundary")
		_check(instructions[0].op == "entry_label" and instructions[0].operands[0].value == 2, "entry label decodes")
		_check(
			instructions[1].op == "text"
			and instructions[1].operands[0].raw_hex == "4142"
			and not instructions[1].native_stream_projection_match
			and instructions[1].native_stream_probe.stop_reason == "single_byte_marker_deferred",
			"text bytes remain lossless while an ASCII body is marked beyond the native pair probe"
		)
		_check(instructions[2].op == "branch_if_not_true" and instructions[2].operands[1].value == 0x20, "condition branch target decodes")
		_check(instructions[3].op == "continuation_transfer" and instructions[3].operands[0].value == 0x30, "continuation target decodes")
		_check(instructions[4].op == "command_0f" and instructions[4].operands[0].records.size() == 2, "unbounded command 0x0F record lists remain numeric")
		_check(instructions[5].op == "dispatcher_character_text" and instructions[5].operands[0].raw_hex == "82a0", "character-lead bytes remain joined")
		_check(
			instructions[6].op == "banked_u16_write_run"
			and instructions[6].operands.size() == 3
			and instructions[6].operands[0].value.ast.value == 2
			and instructions[6].operands[1].value == 1
			and instructions[6].operands[2].pairs.size() == 1
			and instructions[6].end_offset == instructions[7].source_offset,
			"command 0x07 retains its u16 destination, bank, and complete write run"
		)
		_check(instructions[7].op == "banked_i32_write_run" and instructions[7].command_id == 0x08, "command 0x08 retains its distinct i32 write run")
		_check(instructions[8].op == "global_u8_write_run" and instructions[8].operands[1].pairs.size() == 2, "command 0x03 retains its complete write run")
		_check(
			instructions[9].op == "mmo_resource_marker"
			and instructions[9].operands[0].name == "D.MMO"
			and instructions[9].operands[0].outer_command == 0x0D
			and instructions[9].operands[0].presentation_subcommand == 9
			and instructions[9].operands[0].native_playback_semantics == "named_mmo_load_into_active_surface_confirmed"
			and instructions[9].operands[0].native_default_origin_arguments == [-1, -1]
			and instructions[9].raw_hex == "0d09ff01442e4d4d4f0000"
			and instructions[9].command_id == 0x0D
			and instructions[9].system_function == 9,
			"bounded 0x0D/subcommand-9 MMO presentation decodes without consuming the following MES command"
		)
		_check(
			instructions[10].op == "banked_u16_write_run"
			and instructions[10].operands[0].value.ast.value == 1
			and instructions[10].operands[2].pairs[0].expression.ast.value == 7,
			"MMO presentation leaves its adjacent banked-u16 write as an independent instruction"
		)
		_check(
			instructions[11].op == "argument_slot_write_run"
			and instructions[11].operands[0].value == 1
			and instructions[11].operands[1].pairs[0].expression.ast.value == 33
			and instructions[11].raw_hex == "09010021ff00",
			"command 0x09 decodes its native indexed dword slot run losslessly"
		)
		_check(
			instructions[12].op == "source_line_marker"
			and instructions[12].operands[0].type == "source_line"
			and instructions[12].operands[0].value == 21
			and instructions[12].raw_hex == "1f15000000",
			"command 0x1F retains its source-line marker and exact bytes"
		)
		_check(
			instructions[13].op == "protagonist_name_insert"
			and instructions[13].command_id == 0x0D
			and instructions[13].system_function == 14
			and instructions[13].raw_hex == "0d0eff0200f90000a000e0f1400be0ff00",
			"command 0x0D with function 14 and the protagonist-name expression is one name-insert call"
		)
		var message_wait := decoder.decode_at(PackedByteArray([0x0D, 0x13, 0xFF, 0x02, 0x02, 0xFF, 0x00]), 0)
		_check(
			message_wait.ok
			and message_wait.op == "system_call"
			and message_wait.system_function == 19
			and message_wait.end_offset == 7
			and message_wait.native_handler_family == "character_stream_presentation"
			and message_wait.native_stream_consumption == decoder.SYSTEM_CALL_CONSUMPTION
			and not message_wait.has("native_stream_probe")
			and message_wait.operands[0].type == "expression"
			and message_wait.operands[1].records.size() == 1,
			"command 0x0D decodes as one system call: a selector expression and its record list"
		)
		_check(
			instructions[14].op == "message_cursor_no_advance"
			and instructions[14].raw_hex == "13ff",
			"exact command 0x13 FF cursor-control form is distinguished"
		)
		_check(
			instructions[16].op == "voice_marker"
			and instructions[16].command_id == 0x0D
			and instructions[16].operands[0].name == "D0977.OGG"
			and instructions[16].operands[0].source_name == "d0977.ogg"
			and instructions[16].operands[0].presentation_subcommand == 7
			and instructions[16].operands[0].queue_selector == 2
			and instructions[16].operands[0].playback_selector == 3
			and instructions[16].operands[0].native_consumer_semantics == "presentation_queue_and_stream_handoff_confirmed"
			and instructions[16].operands[0].native_audible_output == "confirmed_directsound_play_dispatch"
			and instructions[16].operands[0].native_host_device_output == "not_observed_by_static_audit",
			"native 0x0D/subcommand-7 voice record retains the confirmed queue and DirectSound dispatch boundaries"
		)
		_check(instructions[17].op == "banked_u16_write_run", "voice marker leaves its following clear write as a separate instruction")
	var banked_u8 := decoder.decode_at(PackedByteArray([0x06, 2, 0xFF, 1, 3, 0xFF, 1, 4, 0xFF, 0]), 0)
	_check(
		banked_u8.ok
		and banked_u8.schema == "ai5_mes_instruction/v45"
		and banked_u8.op == "banked_u8_write_run"
		and banked_u8.operands[0].value.ast.value == 2
		and banked_u8.operands[1].value == 1
		and banked_u8.operands[2].pairs.size() == 2
		and banked_u8.end_offset == 10,
		"command 0x06 retains its destination, bank selector, and continuation-controlled byte run"
	)
	var script_dispatch := decoder.decode_at(PackedByteArray([0x0F, 0x01, 0x54, 0x52, 0x41, 0x49, 0x4E, 0x2E, 0x4D, 0x45, 0x53, 0x00, 0x00]), 0)
	_check(
		script_dispatch.ok
		and script_dispatch.schema == "ai5_mes_instruction/v45"
		and script_dispatch.op == "script_dispatch"
		and script_dispatch.script_target == "TRAIN.MES",
		"one safe ASCII MES string record is a bounded script dispatch target"
	)
	var unsafe_script_dispatch := decoder.decode_at(PackedByteArray([0x0F, 0x01, 0x2E, 0x2E, 0x2F, 0x58, 0x2E, 0x4D, 0x45, 0x53, 0x00, 0x00]), 0)
	_check(unsafe_script_dispatch.ok and unsafe_script_dispatch.op == "command_0f", "unsafe command 0x0F paths never become script dispatch targets")
	var broad_voice := PackedByteArray([0x07, 0x02, 0xFF, 0x00, 0x02, 0xA0, 0x00, 0xF1, 0x80, 0x00, 0xE9, 0xFF, 0x00, 0x0D, 0x07, 0xFF, 0x02, 0x02, 0xFF, 0x01])
	broad_voice.append_array("menu.ogg".to_ascii_buffer())
	broad_voice.append_array(PackedByteArray([0x00, 0x02, 0x00, 0xFF, 0x00, 0x07, 0x02, 0xFF, 0x00, 0x02, 0xA0, 0x00, 0xF1, 0x7F, 0xFF, 0xE8, 0xFF, 0x00]))
	var broad_voice_marker := decoder.decode_resource_marker_at(broad_voice, 13)
	_check(
		broad_voice_marker.matched
		and broad_voice_marker.result.ok
		and broad_voice_marker.result.operands[0].name == "MENU.OGG",
		"native typed voice records accept the full safe ASCII Ogg name grammar"
	)
	var inline_library_code := PackedByteArray([0x0D, 0x08, 0xFF, 0x02, 0x02, 0xFF, 0x01])
	inline_library_code.append_array("liblary.lib".to_ascii_buffer())
	inline_library_code.append_array(PackedByteArray([0x00, 0x00]))
	var inline_library := decoder.decode_at(inline_library_code, 0)
	_check(
		inline_library.ok
		and inline_library.op == "inline_script_execution"
		and inline_library.command_id == 0x0D
		and inline_library.operands[0].name == "LIBLARY.LIB"
		and inline_library.operands[0].presentation_subcommand == 8
		and inline_library.operands[0].execution_selector == 2
		and inline_library.operands[0].execution_role == "library_bootstrap"
		and inline_library.operands[0].native_consumer_semantics == "archive_entry_load_inline_execute_restore_confirmed"
		and inline_library.operands[0].native_context_restore == "confirmed"
		and inline_library.operands[0].tool_execution_semantics == "not_executed"
		and inline_library.end_offset == inline_library_code.size(),
		"native subcommand-8 selector-2 library execution decodes as one bounded record"
	)
	var inline_definition_code := PackedByteArray([0x0D, 0x08, 0xFF, 0x02, 0x03, 0xFF, 0x01])
	inline_definition_code.append_array("def_main.mes".to_ascii_buffer())
	inline_definition_code.append_array(PackedByteArray([0x00, 0x00]))
	var inline_definition := decoder.decode_at(inline_definition_code, 0)
	_check(
		inline_definition.ok
		and inline_definition.operands[0].name == "DEF_MAIN.MES"
		and inline_definition.operands[0].execution_selector == 3
		and inline_definition.operands[0].execution_role == "definition_bootstrap",
		"native subcommand-8 selector-3 definition execution retains its distinct role"
	)
	var state_transfer_code := PackedByteArray([
		0x0D, 0x04, 0xFF, 0x02, 0x0D, 0xFF,
		0x02, 0xF8, 0x2B, 0xFF,
		0x01, 0x48, 0x54, 0x45, 0x00,
		0x00,
	])
	var state_transfer := decoder.decode_at(state_transfer_code, 0)
	_check(
		state_transfer.ok
		and state_transfer.schema == "ai5_mes_instruction/v45"
		and state_transfer.op == "named_state_transfer"
		and state_transfer.command_id == 0x0D
		and state_transfer.end_offset == state_transfer_code.size()
		and state_transfer.operands[0].presentation_subcommand == 4
		and state_transfer.operands[0].transfer_selector == 13
		and state_transfer.operands[0].snapshot_selector.ast.storage == "state_i32"
		and state_transfer.operands[0].snapshot_selector.ast.index.value == 43
		and state_transfer.operands[0].mapping_string == "HTE"
		and state_transfer.operands[0].mappings.size() == 3
		and state_transfer.operands[0].mappings[0].name == "H"
		and state_transfer.operands[0].mappings[0].slot_offset == 0x2092
		and state_transfer.operands[0].native_copy_scope == "relative_offsets_only"
		and state_transfer.operands[0].tool_execution_semantics == "not_executed",
		"native subcommand-4 selector-13 transfer retains its named relative-offset mapping without executing it"
	)
	var i32_state_transfer_code := PackedByteArray([
		0x0D, 0x04, 0xFF, 0x02, 0x0D, 0xFF,
		0x02, 0x01, 0xFF,
		0x01, 0x5F, 0x5A, 0x00,
		0x00,
	])
	var i32_state_transfer := decoder.decode_at(i32_state_transfer_code, 0)
	_check(
		i32_state_transfer.op == "named_state_transfer"
		and i32_state_transfer.operands[0].mappings[0].name == "_Z"
		and i32_state_transfer.operands[0].mappings[0].table == "i32_relative_offset"
		and i32_state_transfer.operands[0].mappings[0].slot_offset == 0x2150,
		"underscore-prefixed native mappings retain the separately confirmed i32 relative-offset slot"
	)
	var invalid_state_transfer := state_transfer_code.duplicate()
	invalid_state_transfer[11] = 0x68
	var unpromoted_state_transfer := decoder.decode_at(invalid_state_transfer, 0)
	_check(
		unpromoted_state_transfer.op == "system_call"
		and unpromoted_state_transfer.system_function == 4
		and unpromoted_state_transfer.end_offset == invalid_state_transfer.size(),
		"unconfirmed lowercase state-transfer mappings are not promoted"
	)
	var wrong_inline_extension := inline_library_code.duplicate()
	wrong_inline_extension[inline_library_code.size() - 5] = 0x4D
	var mismatched_inline := decoder.decode_at(wrong_inline_extension, 0)
	_check(
		mismatched_inline.op == "system_call" and mismatched_inline.system_function == 8,
		"subcommand-8-like bytes with a selector/extension mismatch are not promoted"
	)
	var unsafe_inline_code := PackedByteArray([0x0D, 0x08, 0xFF, 0x02, 0x02, 0xFF, 0x01])
	unsafe_inline_code.append_array("../BOOT.LIB".to_ascii_buffer())
	unsafe_inline_code.append_array(PackedByteArray([0x00, 0x00]))
	var unsafe_inline := decoder.decode_at(unsafe_inline_code, 0)
	_check(
		unsafe_inline.op == "system_call" and unsafe_inline.system_function == 8,
		"unsafe subcommand-8 entry paths are never promoted"
	)
	var truncated_inline_code := inline_definition_code.slice(0, inline_definition_code.size() - 1)
	var truncated_inline := decoder.decode_at(truncated_inline_code, 0)
	_check(
		not truncated_inline.ok
		and str(truncated_inline.error).contains("envelope is truncated"),
		"recognized subcommand-8 envelopes fail closed when their record-list terminator is missing"
	)
	var ax_code := PackedByteArray([0x0D, 0x08, 0xFF, 0x02, 0x00, 0xFF, 0x01])
	ax_code.append_array("d01x.ax".to_ascii_buffer())
	ax_code.append_array(PackedByteArray([0x00, 0x02, 0x02, 0xF9, 0x00, 0xFF, 0x00]))
	var ax_marker := decoder.decode_at(ax_code, 0)
	_check(
		ax_marker.ok
		and ax_marker.op == "ax_resource_marker"
		and ax_marker.command_id == 0x0D
		and ax_marker.operands[0].name == "D01X.AX"
		and ax_marker.operands[0].source_name == "d01x.ax"
		and ax_marker.operands[0].presentation_subcommand == 8
		and ax_marker.operands[0].execution_selector == 0
		and ax_marker.operands[0].data_archive_index == 0
		and ax_marker.operands[0].native_consumer_semantics == "data_arc_named_entry_load_confirmed"
		and ax_marker.operands[0].native_loader_argument == "banked_i32[0][2]"
		and ax_marker.operands[0].native_loader_argument_semantics == "engine_initialized_destination_buffer_pointer"
		and ax_marker.operands[0].native_payload_semantics == "unresolved"
		and ax_marker.native_stream_consumption == "typed_presentation_subcommand_8_selector_0_record_list"
		and ax_marker.end_offset == ax_code.size(),
		"exact presentation-subcommand-8 selector-0 AX envelope exposes the confirmed Data loader boundary"
	)
	var malformed_ax := ax_code.duplicate()
	malformed_ax[malformed_ax.size() - 1] = 1
	_check(
		decoder.decode_at(malformed_ax, 0).op == "statement_separator",
		"AX-like presentation bytes with a changed suffix are not promoted"
	)
	_check(
		not decoder.decode_at(ax_code.slice(1), 0).ok,
		"the subcommand-8 AX payload is never promoted without its outer presentation command"
	)
	var ax_binding_code := PackedByteArray([
		0x0D, 0x03, 0xFF,
		0x02, 0x00, 0xFF,
		0x02, 0x00, 0xFF,
		0x02, 0x02, 0xFF,
		0x02, 0x02, 0xF9, 0x00, 0xFF,
		0x00,
	])
	var ax_binding := decoder.decode_at(ax_binding_code, 0)
	_check(
		ax_binding.ok
		and ax_binding.op == "ax_presentation_binding"
		and ax_binding.command_id == 0x0D
		and ax_binding.operands[0].presentation_subcommand == 3
		and ax_binding.operands[0].execution_selector == 0
		and ax_binding.operands[0].consumer_index == 0
		and ax_binding.operands[0].consumer_virtual_slot == 0x08
		and ax_binding.operands[0].cell_row == 0
		and ax_binding.operands[0].cell_column == 2
		and ax_binding.operands[0].buffer_argument == "banked_i32[0][2]"
		and ax_binding.operands[0].binding_table_entries == 320
		and ax_binding.operands[0].binding_table_bytes == 0x500
		and ax_binding.operands[0].native_consumer_semantics == "ax_binding_table_cell_install_confirmed"
		and ax_binding.operands[0].native_rendering_semantics == "unresolved"
		and ax_binding.native_stream_consumption == "typed_presentation_subcommand_3_selector_0_ax_binding_record_list"
		and ax_binding.end_offset == ax_binding_code.size(),
		"exact presentation-subcommand-3 selector-0 AX buffer envelope exposes the bounded native consumer cell bind"
	)
	var invalid_ax_binding := ax_binding_code.duplicate()
	invalid_ax_binding[10] = 3
	var unpromoted_ax_binding := decoder.decode_at(invalid_ax_binding, 0)
	_check(
		unpromoted_ax_binding.op == "system_call" and unpromoted_ax_binding.system_function == 3,
		"AX binding-like bytes outside the confirmed column range are not promoted"
	)
	var ax_selected_cell := decoder.decode_at(PackedByteArray([
		0x0D, 0x03, 0xFF, 0x02, 0x02, 0xFF, 0x00,
	]), 0)
	_check(
		ax_selected_cell.ok
		and ax_selected_cell.op == "ax_presentation_control"
		and ax_selected_cell.end_offset == 7
		and ax_selected_cell.operands[0].execution_selector == 2
		and ax_selected_cell.operands[0].consumer_vector_offset == 0x4B578
		and ax_selected_cell.operands[0].native_dispatch_table == 0x00429338
		and ax_selected_cell.operands[0].native_dispatch_branch == 0x004290DD
		and ax_selected_cell.operands[0].native_consumer_virtual_slot == 0x10
		and ax_selected_cell.operands[0].native_consumer_handler == 0x00410C10
		and ax_selected_cell.operands[0].cell_rows == 10
		and ax_selected_cell.operands[0].cell_columns == 32
		and ax_selected_cell.operands[0].cell_record_bytes == 0x2C
		and ax_selected_cell.operands[0].cell_state_offset == 0
		and ax_selected_cell.operands[0].cell_state_value == 1
		and ax_selected_cell.operands[0].native_bounded_effect == "set_selected_ax_cell_state_to_1"
		and ax_selected_cell.native_stream_consumption == "typed_presentation_subcommand_3_selector_2_literal_record"
		and not ax_selected_cell.has("native_stream_probe"),
		"exact selector-2 literal control exposes the bounded selected AX-cell state update"
	)
	var ax_mark_active := decoder.decode_at(PackedByteArray([
		0x0D, 0x03, 0xFF, 0x02, 0x06, 0xFF, 0x00,
	]), 0)
	_check(
		ax_mark_active.ok
		and ax_mark_active.op == "ax_presentation_control"
		and ax_mark_active.end_offset == 7
		and ax_mark_active.operands[0].execution_selector == 6
		and ax_mark_active.operands[0].consumer_vector_offset == 0x4B578
		and ax_mark_active.operands[0].native_consumer_virtual_slot == 0x1C
		and ax_mark_active.operands[0].native_consumer_handler == 0x00410C80
		and ax_mark_active.operands[0].native_nested_cell_virtual_slot == 0x10
		and ax_mark_active.operands[0].native_nested_cell_handler == 0x00410C10
		and ax_mark_active.operands[0].cell_state_offset == 0
		and ax_mark_active.operands[0].inactive_state == 0xFF
		and ax_mark_active.operands[0].cell_update_flag_offset == 0x10
		and ax_mark_active.operands[0].cell_update_flag_value == 1
		and ax_mark_active.operands[0].native_bounded_effect == "set_update_flag_1_on_noninactive_10x32_ax_cells"
		and ax_mark_active.native_stream_consumption == "typed_presentation_subcommand_3_selector_6_literal_record"
		and not ax_mark_active.has("native_stream_probe"),
		"exact selector-6 literal control exposes bounded noninactive AX-cell update metadata"
	)
	var ax_invalidate := decoder.decode_at(PackedByteArray([
		0x0D, 0x03, 0xFF, 0x02, 0x07, 0xFF, 0x00,
	]), 0)
	_check(
		ax_invalidate.ok
		and ax_invalidate.op == "ax_presentation_control"
		and ax_invalidate.end_offset == 7
		and ax_invalidate.operands[0].execution_selector == 7
		and ax_invalidate.operands[0].consumer_virtual_slot == 0x20
		and ax_invalidate.operands[0].cell_rows == 10
		and ax_invalidate.operands[0].cell_columns == 32
		and ax_invalidate.operands[0].cell_record_bytes == 0x2C
		and ax_invalidate.operands[0].inactive_state == 0xFF
		and ax_invalidate.operands[0].native_consumer_handler == 0x00410CC0
		and ax_invalidate.operands[0].native_bounded_effect == "set_all_10x32_cell_states_to_inactive_0xff"
		and ax_invalidate.operands[0].gameplay_state_effect == "none_observed"
		and ax_invalidate.native_stream_consumption == "typed_presentation_subcommand_3_selector_7_literal_record"
		and not ax_invalidate.has("native_stream_probe"),
		"exact selector-7 literal control exposes bounded AX-cell invalidation metadata"
	)
	var ax_activate := decoder.decode_at(PackedByteArray([
		0x0D, 0x03, 0xFF, 0x02, 0x08, 0xFF, 0x00,
	]), 0)
	_check(
		ax_activate.ok
		and ax_activate.op == "ax_presentation_control"
		and ax_activate.end_offset == 7
		and ax_activate.operands[0].execution_selector == 8
		and ax_activate.operands[0].consumer_vector_offset == 0x4B578
		and ax_activate.operands[0].native_dispatch_table == 0x00429338
		and ax_activate.operands[0].native_dispatch_branch == 0x0042924B
		and ax_activate.operands[0].native_activation_handler == 0x00411140
		and ax_activate.operands[0].native_wait_helper == 0x00411290
		and ax_activate.operands[0].native_initial_transition == "state_0_to_3"
		and ax_activate.operands[0].native_ordinary_wait_transition == "state_3_to_4"
		and ax_activate.operands[0].native_bounded_effect == "activate_bound_ax_cells_and_wait_for_terminal_states"
		and ax_activate.native_stream_consumption == "typed_presentation_subcommand_3_selector_8_literal_record",
		"exact selector-8 literal control exposes bounded AX activation and wait metadata"
	)
	var surface_composition_control := decoder.decode_at(PackedByteArray([
		0x0D, 0x0A, 0xFF, 0x02, 0x01, 0xFF, 0x00,
	]), 0)
	_check(
		surface_composition_control.ok
		and surface_composition_control.op == "surface_composition_control"
		and surface_composition_control.end_offset == 7
		and surface_composition_control.operands[0].presentation_subcommand == 10
		and surface_composition_control.operands[0].literal_mode == 1
		and surface_composition_control.operands[0].native_public_context_virtual_slot == 0x34
		and surface_composition_control.operands[0].native_control_word_offset == 0x20BC
		and surface_composition_control.operands[0].native_surface_indices == [11, 0, 10]
		and surface_composition_control.operands[0].native_copy_helper == 0x004254D0
		and surface_composition_control.operands[0].native_copy_call_sites == [0x0042AA5E, 0x0042AACB, 0x0042AB5A]
		and not surface_composition_control.operands[0].native_optional_fill_path_taken
		and surface_composition_control.operands[0].native_bounded_effect == "opaque_surface_composition_then_host_refresh"
		and surface_composition_control.native_stream_consumption == "typed_presentation_subcommand_10_mode_1_literal_record",
		"exact subcommand-10 mode-1 literal control exposes guarded native surface composition metadata"
	)
	var unconfirmed_ax_control := PackedByteArray([
		0x0D, 0x03, 0xFF, 0x02, 0x09, 0xFF, 0x00,
	])
	var unconfirmed_surface_control := PackedByteArray([
		0x0D, 0x0A, 0xFF, 0x02, 0x02, 0xFF, 0x00,
	])
	var unconfirmed_ax := decoder.decode_at(unconfirmed_ax_control, 0)
	var unconfirmed_surface := decoder.decode_at(unconfirmed_surface_control, 0)
	_check(
		unconfirmed_ax.op == "system_call" and unconfirmed_ax.system_function == 3
		and unconfirmed_surface.op == "system_call" and unconfirmed_surface.system_function == 10,
		"nearby unconfirmed selector and mode values remain generic native boundaries"
	)
	var surface_copy_code := PackedByteArray([0x0D, 0x0B, 0xFF])
	for value in [0, 10, 20, 29, 39, 1, 40, 50, 2]:
		surface_copy_code.append_array(PackedByteArray([0x02, value, 0xFF]))
	surface_copy_code.append(0x00)
	var surface_copy := decoder.decode_at(surface_copy_code, 0)
	_check(
		surface_copy.ok
		and surface_copy.op == "surface_operation"
		and surface_copy.command_id == 0x0D
		and surface_copy.end_offset == surface_copy_code.size()
		and surface_copy.operands[0].presentation_subcommand == 11
		and surface_copy.operands[0].mode == 0
		and surface_copy.operands[0].record_count == 9
		and surface_copy.operands[0].native_operation_semantics == "opaque_rectangle_copy_confirmed"
		and surface_copy.operands[0].native_endpoint_semantics == "inclusive_width_height_expansion_confirmed"
		and surface_copy.operands[0].native_pixel_helper == 0x004254D0
		and surface_copy.operands[0].source_surface_index.ast.value == 1
		and surface_copy.operands[0].destination_surface_index.ast.value == 2
		and surface_copy.native_stream_consumption == "typed_presentation_subcommand_11_record_list",
		"exact subcommand-11 mode-0 envelope retains its opaque rectangle-copy boundary"
	)
	var surface_key_code := surface_copy_code.duplicate()
	surface_key_code[4] = 1
	var surface_key := decoder.decode_at(surface_key_code, 0)
	_check(
		surface_key.op == "surface_operation"
		and surface_key.operands[0].mode == 1
		and surface_key.operands[0].native_operation_semantics == "rgb_chroma_key_rectangle_copy_confirmed"
		and surface_key.operands[0].native_pixel_helper == 0x004255D0
		and surface_key.operands[0].native_transparency_key_source == "presentation_context_rgb_key",
		"exact subcommand-11 mode-1 envelope retains its RGB-key rectangle-copy boundary"
	)
	var surface_fill_code := PackedByteArray([0x0D, 0x0B, 0xFF])
	for value in [2, 3, 4, 7, 9]:
		surface_fill_code.append_array(PackedByteArray([0x02, value, 0xFF]))
	surface_fill_code.append(0x00)
	var surface_fill := decoder.decode_at(surface_fill_code, 0)
	_check(
		surface_fill.op == "surface_operation"
		and surface_fill.operands[0].mode == 2
		and surface_fill.operands[0].record_count == 5
		and surface_fill.operands[0].native_operation_semantics == "active_surface_rectangle_fill_confirmed"
		and surface_fill.operands[0].native_active_surface_state_offset == 0x20BA
		and surface_fill.operands[0].native_pixel_helper == 0x00425B10,
		"exact subcommand-11 mode-2 envelope retains its active-surface fill boundary"
	)
	var mmo_marker := decoder.decode_at(PackedByteArray([
		0x0D, 0x09, 0xFF, 0x01,
		0x41, 0x4E, 0x2E, 0x4D, 0x4D, 0x4F, 0x00, 0x00,
	]), 1)
	_check(
		mmo_marker.ok
		and mmo_marker.schema == "ai5_mes_instruction/v45"
		and mmo_marker.op == "mmo_resource_marker"
		and mmo_marker.operands[0].native_active_surface_state_offset == 0x20BA
		and mmo_marker.operands[0].native_active_surface_storage == "banked_u16"
		and mmo_marker.operands[0].native_active_surface_bank == 0
		and mmo_marker.operands[0].native_active_surface_storage_index == 1,
		"MMO marker exposes the EXE-bound banked-u16 active-surface storage identity"
	)
	var malformed_surface := surface_fill_code.duplicate()
	malformed_surface.insert(malformed_surface.size() - 1, 0x02)
	malformed_surface.insert(malformed_surface.size() - 1, 0x00)
	malformed_surface.insert(malformed_surface.size() - 1, 0xFF)
	var unresolved_shape := decoder.decode_at(malformed_surface, 0)
	_check(
		unresolved_shape.op == "surface_dispatch_unresolved"
		and unresolved_shape.end_offset == malformed_surface.size()
		and unresolved_shape.operands[0].mode == 2
		and unresolved_shape.operands[0].record_count == 6,
		"noncanonical subcommand-11 records retain one unresolved native dispatch boundary"
	)
	var empty_surface_dispatch := decoder.decode_at(PackedByteArray([0x0D, 0x0B, 0xFF, 0x00]), 0)
	_check(
		empty_surface_dispatch.op == "surface_dispatch_unresolved"
		and empty_surface_dispatch.end_offset == 4
		and empty_surface_dispatch.operands[0].mode == -1
		and empty_surface_dispatch.operands[0].mode_source == "native_record_default_unresolved"
		and empty_surface_dispatch.operands[0].record_count == 0,
		"empty original-style subcommand-11 list retains unresolved native record defaults"
	)
	var mode_13_dispatch := decoder.decode_at(PackedByteArray([
		0x0D, 0x0B, 0xFF,
		0x02, 0x0D, 0xFF,
		0x02, 0x3D, 0xFF,
		0x00,
	]), 0)
	_check(
		mode_13_dispatch.op == "surface_dispatch_unresolved"
		and mode_13_dispatch.end_offset == 10
		and mode_13_dispatch.operands[0].mode == 13
		and mode_13_dispatch.operands[0].native_dispatch_max_mode == 7
		and mode_13_dispatch.operands[0].native_out_of_range_target == 0x0042AFDD
		and mode_13_dispatch.operands[0].native_common_tail == 0x0042AFE5,
		"out-of-range mode retains the EXE-confirmed switch-default and common-tail boundary"
	)
	var mode_13_refresh_code := PackedByteArray([0x0D, 0x0B, 0xFF])
	for value in [13, 10, 20, 29, 39, 0]:
		mode_13_refresh_code.append_array(PackedByteArray([0x02, value, 0xFF]))
	mode_13_refresh_code.append(0x00)
	var mode_13_refresh := decoder.decode_at(mode_13_refresh_code, 0)
	_check(
		mode_13_refresh.ok
		and mode_13_refresh.schema == "ai5_mes_instruction/v45"
		and mode_13_refresh.op == "surface_display_refresh"
		and mode_13_refresh.operands[0].mode == 13
		and mode_13_refresh.operands[0].record_count == 6
		and mode_13_refresh.operands[0].refresh_origin_default == [0, 0]
		and mode_13_refresh.operands[0].native_record_workspace_clear_size == 0x546
		and mode_13_refresh.operands[0].native_refresh_adapter == 0x004059E0
		and mode_13_refresh.operands[0].native_rectangle_helper == 0x00427640
		and mode_13_refresh.operands[0].native_raster_operation == 0x00CC0020
		and mode_13_refresh.operands[0].native_operation_semantics == "conditional_attached_display_rectangle_refresh_confirmed",
		"six-record mode-13 envelope retains its confirmed attached-display refresh contract"
	)
	_check(not decoder.decode_at(PackedByteArray([0x01, 0x41]), 0).ok, "unterminated text is rejected")
	var internal_push := decoder.decode_at(PackedByteArray([0x19]), 0)
	var internal_pop := decoder.decode_at(PackedByteArray([0x1A]), 0)
	_check(
		internal_push.ok and internal_push.op == "internal_record_push" and internal_push.end_offset == 1
		and internal_pop.ok and internal_pop.op == "internal_record_pop" and internal_pop.end_offset == 1,
		"commands 0x19/0x1A retain their operand-free internal-record push/pop boundaries"
	)
	var definition_invoke := decoder.decode_at(PackedByteArray([0x11, 0x02, 0x0B, 0xFF, 0x00, 0x1F]), 0)
	_check(
		definition_invoke.ok
		and definition_invoke.schema == "ai5_mes_instruction/v45"
		and definition_invoke.op == "definition_invoke"
		and definition_invoke.operands[0].records[0].value.ast.value == 11
		and definition_invoke.end_offset == 5,
		"command 0x11 consumes the EXE-confirmed common record list before the following command"
	)
	var native_selection := decoder.decode_at(PackedByteArray([0x15, 0x01, 0x41, 0x00, 0x02, 0x05, 0xFF, 0x00]), 0)
	_check(
		native_selection.ok
		and native_selection.op == "native_selection"
		and native_selection.operands[0].records.size() == 2,
		"command 0x15 retains the native selection handler's common record list"
	)
	var argument_run := decoder.decode_at(PackedByteArray([0x16, 0x09, 0x21, 0xFF, 0x01, 0x22, 0xFF, 0x00]), 0)
	_check(
		argument_run.ok
		and argument_run.op == "argument_slot_write_run"
		and argument_run.operands[0].value == 9
		and argument_run.operands.size() == 3,
		"command 0x16 retains its starting slot and continuation-controlled value run"
	)
	var command_09_run := decoder.decode_at(PackedByteArray([0x09, 0x02, 0x00, 0x02, 0xFF, 0x01, 0x03, 0xFF, 0x00]), 0)
	_check(
		command_09_run.ok
		and command_09_run.op == "argument_slot_write_run"
		and command_09_run.operands[0].value == 2
		and command_09_run.operands[1].pairs.size() == 2
		and command_09_run.operands[1].pairs[0].expression.ast.value == 2
		and command_09_run.operands[1].pairs[1].expression.ast.value == 3,
		"command 0x09 retains its u16 starting slot and complete native continuation run"
	)
	var command_05_run := decoder.decode_at(PackedByteArray([0x05, 0x02, 0xFF, 0x21, 0xFF, 0x01, 0x22, 0xFF, 0x00]), 0)
	_check(
		command_05_run.ok
		and command_05_run.op == "dynamic_global_u8_write_run"
		and command_05_run.operands[0].value.ast.value == 2
		and command_05_run.operands.size() == 3
		and command_05_run.operands[1].expression.ast.value == 33
		and command_05_run.operands[2].expression.ast.value == 34,
		"command 0x05 retains its expression destination and continuation-controlled byte values"
	)
	var native_pair_text := decoder.decode_at(PackedByteArray([0x01, 0x81, 0x6D, 0xFA, 0x40, 0x00]), 0)
	_check(
		native_pair_text.native_handler_family == "double_byte_character_stream_presentation"
		and native_pair_text.native_stream_consumption == "double_byte_pairs_until_nul_or_nonlead"
		and native_pair_text.native_stream_probe.character_count == 2
		and native_pair_text.native_stream_probe.consumed_byte_count == 5
		and native_pair_text.native_stream_probe.stop_reason == "nul_consumed"
		and native_pair_text.native_stream_projection_match,
		"command 0x01 retains an EXE-matched double-byte pair run through NUL"
	)
	var empty_native_text := decoder.decode_at(PackedByteArray([0x01, 0xFF, 0x02, 0x00]), 0)
	_check(
		empty_native_text.op == "command_01"
		and empty_native_text.end_offset == 1
		and empty_native_text.native_stream_probe.character_count == 0
		and empty_native_text.native_stream_probe.stop_reason == "single_byte_marker_deferred",
		"command 0x01 before FF remains an empty native token instead of a false message"
	)
	var lead_dispatch := decoder.decode_at(PackedByteArray([0x82, 0xA0, 0x00]), 0)
	_check(
		lead_dispatch.op == "dispatcher_character_text"
		and lead_dispatch.native_stream_probe.character_count == 1
		and lead_dispatch.native_stream_projection_match,
		"native lead dispatch token probes the following double-byte pair payload"
	)
	var lead_before_ff := decoder.decode_at(PackedByteArray([0x82, 0xA0, 0xFF, 0x00]), 0)
	_check(
		lead_before_ff.op == "dispatcher_character_text"
		and lead_before_ff.end_offset == 2
		and lead_before_ff.operands[0].raw_hex == "82a0"
		and lead_before_ff.native_stream_projection_match,
		"native lead text projection ends before a deferred FF boundary"
	)
	var command_02 := decoder.decode_at(PackedByteArray([0x02]), 0)
	var command_12 := decoder.decode_at(PackedByteArray([
		0x12,
		0x02, 0x01, 0xFF,
		0x02, 0x2B, 0xFF,
		0x02, 0x00, 0xFF,
		0x00,
		0x00,
	]), 0)
	_check(
		command_02.ok and command_02.end_offset == 1
		and command_02.native_handler_family == "character_stream_presentation"
		and command_02.native_stream_probe.stop_reason == "decode_limit"
		and command_12.ok and command_12.end_offset == 11
		and command_12.op == "native_record_dispatch"
		and command_12.native_handler_family == "native_record_dispatch"
		and command_12.native_record_consumption == "typed_record_list_until_zero"
		and command_12.native_record_count == 3
		and command_12.native_record_terminator_consumed
		and command_12.operands[0].records.size() == 3
		and command_12.operands[0].records[2].value.ast.value == 0,
		"command 0x12 consumes its complete typed record list while command 0x02 retains the character-stream probe"
	)
	var deferred_lead := decoder.decode_at(PackedByteArray([0x02, 0x41, 0x82, 0xA0]), 0)
	_check(
		deferred_lead.native_stream_probe.consumed_byte_count == 1
		and deferred_lead.native_stream_probe.stop_offset == 2
		and deferred_lead.native_stream_probe.stop_reason == "double_byte_lead_deferred",
		"native stream probe stops before the primary double-byte lead without consuming it"
	)
	var extended_single_byte := decoder.decode_at(PackedByteArray([0x02, 0xFA, 0x00]), 0)
	_check(
		extended_single_byte.native_stream_probe.consumed_byte_count == 2
		and extended_single_byte.native_stream_probe.stop_reason == "nul_consumed",
		"native single-byte handler probe follows the EXE and does not defer lead 0xFA"
	)
	var default_byte := decoder.decode_at(PackedByteArray([0x41, 0x42, 0x00]), 0)
	_check(
		default_byte.native_handler_family == "character_stream_presentation"
		and default_byte.native_stream_probe.consumed_byte_count == 2,
		"ordinary dispatcher bytes retain the same native single-byte presentation probe"
	)
	var state_write := decoder.decode_at(PackedByteArray([
		0x04, 0xFE,
		0xF1, 20, 0, 0xFF, 1,
		0x80, 0xFE, 5, 0xE0, 0xFF, 0,
	]), 0)
	_check(
		state_write.ok
		and state_write.op == "state_u16_write_run"
		and state_write.operands[0].value == 0xFE
		and state_write.operands[1].pairs.size() == 2
		and state_write.end_offset == 13,
		"command 0x04 retains its u8 start index and complete dynamic write run"
	)
	_check(not decoder.decode_at(PackedByteArray([0x04, 1, 2, 0xFF, 1]), 0).ok, "command 0x04 rejects a truncated continued write run")
	_check(not decoder.decode_at(PackedByteArray([0x0B, 1, 0xFF]), 0).ok, "truncated branch target is rejected")
	_check(not decoder.decode_at(PackedByteArray([0x09, 0xFF, 0x01, 0x44, 0x2E, 0x4D, 0x4D, 0x4F, 0x00, 0x00]), 0).ok, "standalone subcommand-9 bytes without outer command 0x0D are not promoted to an MMO presentation")
	var literal_0e := decoder.decode_at(PackedByteArray([0x0E, 0x01, 0x58, 0x00, 0x00]), 0)
	_check(
		literal_0e.ok
		and literal_0e.op == "literal_text_insert"
		and literal_0e.operands[0].records[0].value.raw_hex == "58",
		"single-string command 0x0E is distinguished as a native literal text insertion"
	)
	var handoff_0e := decoder.decode_at(PackedByteArray([
		0x0E, 0x01, 0x4D, 0x41, 0x43, 0x48, 0x49, 0x2E, 0x4D, 0x45, 0x53, 0x00, 0x00,
	]), 0)
	_check(
		handoff_0e.ok
		and handoff_0e.op == "script_handoff_marker"
		and handoff_0e.script_target == "MACHI.MES",
		"safe ASCII MES command 0x0E records are distinguished from presented literal text"
	)
	var unresolved_13 := decoder.decode_at(PackedByteArray([0x13, 0x00]), 0)
	_check(unresolved_13.ok and unresolved_13.op == "command_13", "other command 0x13 operands remain numeric")
	var library_registration := decoder.decode_at(PackedByteArray([0x1C, 0x28, 0xFF, 9, 0, 0, 0]), 0)
	_check(
		library_registration.ok
		and library_registration.op == "library_register_skip"
		and library_registration.operands[0].value.ast.value == 40
		and library_registration.operands[1].value == 9,
		"command 0x1C retains its literal library registration and forward skip target"
	)
	var global_i32_write := decoder.decode_at(PackedByteArray([0x0A, 0x02, 0xFF, 0x03, 0xFF, 1, 0x04, 0xFF, 0]), 0)
	_check(
		global_i32_write.ok
		and global_i32_write.op == "global_i32_write_run"
		and global_i32_write.end_offset == 9
		and global_i32_write.operands[0].value.ast.value == 2
		and global_i32_write.operands[1].pairs.size() == 2
		and global_i32_write.operands[1].pairs[0].continuation == 1
		and global_i32_write.operands[1].pairs[1].continuation == 0,
		"command 0x0A retains one destination plus its complete repeated dword value run"
	)
	var non_strict_write := PackedByteArray([0x0A, 0xFF, 0x02, 0x01, 0xFF, 0x00, 0x0D])
	var strict_region := decoder.decode_region(non_strict_write, 0, non_strict_write.size())
	var structural_region := decoder.decode_region_structural(non_strict_write, 0, non_strict_write.size())
	_check(
		not strict_region.ok
		and strict_region.decoded_end_offset == 0
		and structural_region.ok
		and structural_region.instructions.size() == 2
		and structural_region.instructions[0].structural_only
		and structural_region.instructions[0].end_offset == 6
		and structural_region.instructions[1].op == "statement_separator",
		"structural-only decode crosses a retained non-singleton expression without making it executable"
	)
	var shadow_stream := PackedByteArray([
		0x0D,
		0x0B, 0x02, 0xFF, 0x01, 0x01, 0x01, 0x01,
		0x00,
		0x01, 0x52, 0x45, 0x41, 0x4C, 0x00,
	])
	var legacy_shadow_region := decoder.decode_region(shadow_stream, 0, shadow_stream.size())
	var aligned_shadow_region := decoder.decode_region_aligned(shadow_stream, 0, shadow_stream.size())
	_check(
		legacy_shadow_region.ok
		and legacy_shadow_region.instructions.size() == 4
		and aligned_shadow_region.ok
		and aligned_shadow_region.instructions.size() == 2
		and aligned_shadow_region.instructions[0].source_offset == 0
		and aligned_shadow_region.instructions[0].native_dispatch_instruction_end_offset == 1
		and aligned_shadow_region.instructions[0].native_payload_start_offset == 1
		and aligned_shadow_region.instructions[0].native_payload_end_offset == 9
		and aligned_shadow_region.instructions[0].native_payload_raw_hex == "0b02ff0101010100"
		and aligned_shadow_region.instructions[0].native_payload_boundary == "bounded_byte_preserving_opaque_stream"
		and aligned_shadow_region.instructions[0].native_shadow_control_offsets == [1]
		and aligned_shadow_region.instructions[0].end_offset == 9
		and aligned_shadow_region.instructions[1].source_offset == 9
		and aligned_shadow_region.instructions[1].op == "text",
		"aligned region decode owns a bounded native payload and resumes at its exact end"
	)
	var internal_shadow_stream := PackedByteArray([
		0x0D,
		0x01, 0xFF, 0x02, 0x80, 0x39, 0xFF, 0x00,
		0x01, 0x52, 0x45, 0x41, 0x4C, 0x00,
	])
	var aligned_internal_shadow := decoder.decode_region_aligned(
		internal_shadow_stream, 0, internal_shadow_stream.size()
	)
	# The 0x0C inside this stream is an argument byte of System.function[1](…):
	# the call grammar owns the whole record, so no shadow alignment is needed.
	_check(
		aligned_internal_shadow.ok
		and aligned_internal_shadow.instructions.size() == 2
		and aligned_internal_shadow.instructions[0].source_offset == 0
		and aligned_internal_shadow.instructions[0].op == "system_call"
		and aligned_internal_shadow.instructions[0].system_function == 1
		and aligned_internal_shadow.instructions[0].end_offset == 8
		and not aligned_internal_shadow.instructions[0].has("native_payload_start_offset")
		and aligned_internal_shadow.instructions[1].source_offset == 8
		and aligned_internal_shadow.instructions[1].op == "text",
		"a system call owns the control byte inside its arguments; no shadow alignment remains"
	)
	var unwrapped_marker := PackedByteArray([0x07, 0xFF, 0x02, 0x02, 0xFF, 0x01])
	unwrapped_marker.append_array("d0977.ogg".to_ascii_buffer())
	unwrapped_marker.append_array(PackedByteArray([0x00, 0x02, 0x00, 0xFF, 0x00]))
	_check(not decoder.decode_at(unwrapped_marker, 0).ok, "filename bytes without outer presentation control 0x0D are not promoted to a voice marker")
	_test_ax_selected_cell_boundaries(decoder)
	_test_effect_dispatch_boundaries(decoder)
	await get_tree().process_frame
	get_tree().quit(1 if _failed else 0)


func _test_ax_selected_cell_boundaries(decoder: RefCounted) -> void:
	for selector in [1, 2]:
		for coordinates in [[0, 0], [0, 1], [0, 2], [0, 12], [9, 31]]:
			var code := _ax_selected_cell_envelope([selector, coordinates[0], coordinates[1]])
			code.append(0)
			for structural in [false, true]:
				var result: Dictionary = decoder.decode_at_structural(code, 0) if structural else decoder.decode_at(code, 0)
				_check(result.ok and result.op == "ax_presentation_control" and result.end_offset == 13
					and result.operands[0].execution_selector == selector
					and result.operands[0].cell_row == coordinates[0]
					and result.operands[0].cell_column == coordinates[1]
					and result.operands[0].consumer_index == 0
					and result.operands[0].cell_state_value == selector - 1
					and result.operands[0].native_record_count == 3
					and result.operands[0].native_defaulted_arguments == 1
					and not result.has("native_stream_probe"),
					"AX selector %d cell %s complete 13-byte envelope structural=%s" % [selector, coordinates, structural])
			var region: Dictionary = decoder.decode_region_aligned(code, 0, code.size())
			_check(region.ok and region.instructions.size() == 2
				and region.instructions[0].op == "ax_presentation_control"
				and region.instructions[1].source_offset == 13,
				"AX payload cannot create sibling global writes or column-12 continuation commands")
		for arguments in [[selector, 0], [selector, 0, 0, 0]]:
			var code := _ax_selected_cell_envelope(arguments)
			var result: Dictionary = decoder.decode_at_structural(code, 0)
			_check(result.ok and result.end_offset == code.size()
				and result.operands[0].cell_row == 0 and result.operands[0].cell_column == 0
				and result.operands[0].native_defaulted_arguments == 4 - arguments.size(),
				"AX selected-cell omitted and explicit consumer-zero arguments have exact boundaries")
		var full := _ax_selected_cell_envelope([selector, 0, 12])
		for limit in range(6, full.size()):
			_check(not decoder.decode_at_structural(full.slice(0, limit), 0).ok,
				"recognized truncated AX selector %d control fails closed at %d bytes" % [selector, limit])
		for arguments in [[selector, 10, 0], [selector, 0, 32], [selector, 0, 0, 1], [selector, 0, 0, 0, 0]]:
			_check(not decoder.decode_at_structural(_ax_selected_cell_envelope(arguments), 0).ok,
				"AX out-of-domain literal argument remains fail-closed: %s" % str(arguments))
	var implicit_activate: Dictionary = decoder.decode_at_structural(_ax_selected_cell_envelope([1]), 0)
	_check(implicit_activate.ok and implicit_activate.end_offset == 7
		and implicit_activate.operands[0].native_defaulted_arguments == 3
		and implicit_activate.operands[0].native_consumer_handler == 0x00410BF0,
		"selector-1 short form uses native zero-filled default arguments")
	var nonliteral := PackedByteArray([0x0D, 3, 0xFF, 2, 1, 0xFF, 2, 0x80, 0, 0xFF, 0])
	_check(not decoder.decode_at_structural(nonliteral, 0).ok,
		"recognized nonliteral AX row is not downgraded to shadow commands")


func _test_effect_dispatch_boundaries(decoder: RefCounted) -> void:
	var channel := PackedByteArray([0xF6, 2, 0, 0xFF])
	var request := _effect_envelope(PackedByteArray([0, 0xFF]), "tool_hit.wav".to_ascii_buffer(), channel)
	for structural in [false, true]:
		var decoded: Dictionary = decoder.decode_at_structural(request, 0) if structural else decoder.decode_at(request, 0)
		_check(decoded.ok and decoded.op == "effect_request" and decoded.end_offset == request.size()
			and decoded.operands[0].execution_selector == 0
			and decoded.operands[0].name == "TOOL_HIT.WAV"
			and decoded.operands[0].source_name == "tool_hit.wav"
			and decoded.operands[0].resource_archive == "se.arc"
			and decoded.operands[0].channel_expression.ast.storage == "global_i32"
			and decoded.operands[0].channel_expression.ast.index.value == 2
			and decoded.operands[0].native_record_count == 3
			and decoded.operands[0].native_record_terminator_consumed
			and not decoded.has("native_stream_probe"),
			"effect selector-zero named request owns its complete typed records structural=%s" % structural)
	var followed := request.duplicate()
	followed.append_array(PackedByteArray([0x03, 42, 0, 9, 0xFF, 0, 0]))
	var region: Dictionary = decoder.decode_region_structural_aligned(followed, 0, followed.size())
	_check(region.ok and region.instructions.size() == 3
		and region.instructions[1].source_offset == request.size()
		and region.instructions[1].op == "global_u8_write_run",
		"effect payload has no shadow bank writes and preserves the following actual command")
	for length in range(3, request.size()):
		for structural in [false, true]:
			var truncated: Dictionary = decoder.decode_at_structural(request, 0, length) if structural else decoder.decode_at(request, 0, length)
			_check(not truncated.ok, "recognized effect envelope truncation fails closed at %d structural=%s" % [length, structural])
	for selector in [1, 2, 3, 127, 256, 65535]:
		var selector_expression := PackedByteArray([0xF1, selector & 255, (selector >> 8) & 255, 0xFF])
		var opaque := _effect_envelope(selector_expression, "tool_hit.wav".to_ascii_buffer(), channel)
		var decoded: Dictionary = decoder.decode_at_structural(opaque, 0)
		_check(decoded.ok and decoded.op == "effect_dispatch" and decoded.end_offset == opaque.size()
			and decoded.operands[0].execution_selector == selector and not decoded.operands[0].has("name"),
			"unpromoted effect selector %d retains the complete opaque envelope" % selector)
	for raw_name in [PackedByteArray(), "../tool.wav".to_ascii_buffer(), "other.ogg".to_ascii_buffer(), PackedByteArray([0x03, 42, 0x12, 0xFF]), PackedByteArray([0x81, 0x40, 46, 119, 97, 118])]:
		var unsafe := _effect_envelope(PackedByteArray([0, 0xFF]), raw_name, channel)
		var decoded: Dictionary = decoder.decode_at_structural(unsafe, 0)
		_check(decoded.ok and decoded.op == "effect_dispatch" and decoded.end_offset == unsafe.size(),
			"unsafe or unsupported effect name remains opaque without exposing its payload")
	for opaque in [
		PackedByteArray([0x0D, 6, 0xFF, 0]),
		PackedByteArray([0x0D, 6, 0xFF, 2, 1, 0xFF, 2, 43, 0xFF, 0]),
		PackedByteArray([0x0D, 6, 0xFF, 2, 0xF6, 1, 0, 0xFF, 0]),
		PackedByteArray([0x0D, 6, 0xFF, 0xFE, 2, 0, 0xFF, 0]),
	]:
		var decoded: Dictionary = decoder.decode_at_structural(opaque, 0)
		_check(decoded.ok and decoded.op == "effect_dispatch" and decoded.end_offset == opaque.size(),
			"empty, stop, nonliteral selector, and unknown-tag effect lists stay bounded and opaque")
	var non_strict := _effect_envelope(PackedByteArray([0, 0xFF]), "tool_hit.wav".to_ascii_buffer(), PackedByteArray([1, 2, 0xFF]))
	var non_strict_decoded: Dictionary = decoder.decode_at_structural(non_strict, 0)
	_check(not decoder.decode_at(non_strict, 0).ok and non_strict_decoded.ok
		and non_strict_decoded.op == "effect_dispatch" and non_strict_decoded.structural_only
		and non_strict_decoded.end_offset == non_strict.size(),
		"non-strict effect arguments retain structural ownership without becoming a playback request")
	var extra := request.slice(0, request.size() - 1)
	extra.append_array(PackedByteArray([2, 0, 0xFF, 0]))
	_check(decoder.decode_at_structural(extra, 0).op == "effect_dispatch",
		"extra effect arguments do not inherit the confirmed three-record request meaning")
	_check(decoder.decode_at(request.slice(1), 0).get("op", "") != "effect_request",
		"effect payload without its outer command cannot become an effect request")


func _effect_envelope(selector: PackedByteArray, name_bytes: PackedByteArray, channel: PackedByteArray) -> PackedByteArray:
	var code := PackedByteArray([0x0D, 6, 0xFF, 2])
	code.append_array(selector)
	code.append(1)
	code.append_array(name_bytes)
	code.append_array(PackedByteArray([0, 2]))
	code.append_array(channel)
	code.append(0)
	return code


func _ax_selected_cell_envelope(arguments: Array) -> PackedByteArray:
	var result := PackedByteArray([0x0D, 3, 0xFF])
	for value in arguments:
		result.append_array(PackedByteArray([2, value, 0xFF]))
	result.append(0)
	return result
