class_name KakyuMesInstructionDecoder
extends RefCounted

const ExpressionScript := preload("res://content_core/mes_expression.gd")
const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")
const ArcReaderScript := preload("res://content_core/arc_reader.gd")
const FIXED_GRAMMARS := {
	0x00: "",
	0x02: "",
	0x13: "b",
	0x19: "",
	0x1A: "",
	0x1E: "",
}
const STRUCTURED_COMMANDS := {
	0x0E: "command_0e",
	0x0F: "command_0f",
	0x10: "command_10",
	0x11: "definition_invoke",
	0x12: "native_record_dispatch",
	0x15: "native_selection",
	0x1B: "command_1b",
	0x1D: "script_transfer",
}
const NATIVE_HANDLER_FAMILIES := {
	0x02: "character_stream_presentation",
	0x0D: "character_stream_presentation",
}

var _expression := ExpressionScript.new()


func decode_at(code: PackedByteArray, offset: int, limit := -1) -> Dictionary:
	return _decode_at(code, offset, limit, false)


func decode_at_structural(code: PackedByteArray, offset: int, limit := -1) -> Dictionary:
	return _decode_at(code, offset, limit, true)


func decode_resource_marker_at(code: PackedByteArray, offset: int, limit := -1) -> Dictionary:
	var end_limit := code.size() if limit < 0 else mini(limit, code.size())
	if offset < 0 or offset >= end_limit:
		return {"matched": false}
	match int(code[offset]):
		0x0D:
			var ax_marker := _decode_confirmed_ax_marker(code, offset, end_limit)
			if ax_marker.get("matched", false):
				return ax_marker
			var voice_marker := _decode_confirmed_voice_marker(code, offset, end_limit)
			if voice_marker.get("matched", false):
				return voice_marker
			var inline_script := _decode_confirmed_inline_script_execution(code, offset, end_limit)
			if inline_script.get("matched", false):
				return inline_script
			# The MMO marker is the system call 0D 09 FF 01 <name> 00 00, one record
			# from the 0x0D; the marker-only scan claims it here so it aligns with
			# the strict instruction index.
			var system_call := _decode_system_call(code, offset, end_limit, false)
			if system_call.get("matched", false) and str(system_call.result.get("op", "")) == "mmo_resource_marker":
				return system_call
			return {"matched": false}
		0x09:
			return _decode_confirmed_mmo_marker(code, offset, end_limit)
		_:
			return {"matched": false}


func _decode_at(code: PackedByteArray, offset: int, limit: int, allow_non_strict_expressions: bool) -> Dictionary:
	var end_limit := code.size() if limit < 0 else mini(limit, code.size())
	if offset < 0 or offset >= end_limit:
		return _error("Instruction offset is outside the decode range.", offset)
	var command_id := int(code[offset])
	var cursor := offset + 1
	if command_id == 0x01:
		var native_probe := _probe_native_double_byte_stream(code, cursor, end_limit)
		if _is_deferred_ff_boundary(code, native_probe, end_limit):
			var native_end := int(native_probe.probe_end_offset)
			if int(native_probe.character_count) == 0:
				return _finish_native_double_byte_stream(
					code, offset, cursor, cursor, "command_01", command_id, [], end_limit
				)
			var native_bytes := code.slice(cursor, native_end)
			return _finish_native_double_byte_stream(
				code,
				offset,
				cursor,
				native_end,
				"text",
				command_id,
				[_cp932_operand(native_bytes, cursor)],
				end_limit
			)
		var string_result := _decode_cstring(code, cursor, end_limit)
		if not string_result.ok:
			return string_result
		return _finish_native_double_byte_stream(
			code,
			offset,
			cursor,
			int(string_result.end_offset),
			"text",
			command_id,
			[string_result.operand],
			end_limit
		)
	if command_id > 0x1F:
		if _is_character_lead(command_id):
			var native_probe := _probe_native_double_byte_stream(code, offset, end_limit)
			if _is_deferred_ff_boundary(code, native_probe, end_limit):
				var native_end := int(native_probe.probe_end_offset)
				var native_bytes := code.slice(offset, native_end)
				return _finish_native_double_byte_stream(
					code,
					offset,
					offset,
					native_end,
					"dispatcher_character_text",
					command_id,
					[_cp932_operand(native_bytes, offset)],
					end_limit
				)
			var string_result := _decode_cstring(code, cursor, end_limit)
			if not string_result.ok:
				return string_result
			var full_bytes := PackedByteArray([command_id])
			full_bytes.append_array(string_result.operand.raw_bytes)
			return _finish_native_double_byte_stream(
				code,
				offset,
				offset,
				int(string_result.end_offset),
				"dispatcher_character_text",
				command_id,
				[{
					"type": "cp932_bytes",
					"raw_bytes": full_bytes,
					"raw_hex": full_bytes.hex_encode(),
					"source_offset": offset,
				}],
				end_limit
			)
		var op := "separator_ff" if command_id == 0xFF else "dispatcher_default_byte"
		return _finish(code, offset, cursor, op, command_id, [], end_limit)
	if STRUCTURED_COMMANDS.has(command_id):
		var record_result := _decode_record_list(code, cursor, end_limit, allow_non_strict_expressions)
		if not record_result.ok:
			return record_result
		cursor = int(record_result.end_offset)
		var operands: Array[Dictionary] = [record_result.operand]
		if command_id == 0x10:
			if cursor + 4 > end_limit:
				return _error("Command 0x10 fields are truncated.", offset)
			operands.append({"type": "u8_array", "value": Array(code.slice(cursor, cursor + 4))})
			cursor += 4
		var op := str(STRUCTURED_COMMANDS[command_id])
		var script_target := ""
		if command_id in [0x0E, 0x0F]:
			script_target = _literal_script_target(record_result.operand)
		if command_id == 0x0E and not script_target.is_empty():
			op = "script_handoff_marker"
		elif command_id == 0x0E and _is_protagonist_name_insert(record_result.operand):
			op = "protagonist_name_insert"
		elif command_id == 0x0E and _is_literal_text_insert(record_result.operand):
			op = "literal_text_insert"
		var result := _finish(code, offset, cursor, op, command_id, operands)
		if command_id == 0x12:
			result["native_handler_family"] = "native_record_dispatch"
			result["native_record_consumption"] = "typed_record_list_until_zero"
			result["native_record_count"] = (record_result.operand.get("records", []) as Array).size()
			result["native_record_terminator_consumed"] = true
			result["native_record_dispatch_semantics"] = "unresolved_not_executed"
		if not script_target.is_empty():
			if command_id == 0x0F:
				result["op"] = "script_dispatch"
			result["script_target"] = script_target
		return result
	if command_id == 0x0D:
		var effect_dispatch := _decode_effect_dispatch(
			code, offset, end_limit, allow_non_strict_expressions
		)
		if effect_dispatch.get("matched", false):
			return effect_dispatch.result
		var native_control := _decode_confirmed_native_presentation_control(
			code, offset, end_limit
		)
		if native_control.get("matched", false):
			return native_control.result
		var surface_operation := _decode_confirmed_surface_dispatch(
			code, offset, end_limit, allow_non_strict_expressions
		)
		if surface_operation.get("matched", false):
			return surface_operation.result
		var ax_binding := _decode_confirmed_ax_binding(code, offset, end_limit)
		if ax_binding.get("matched", false):
			return ax_binding.result
		var state_transfer := _decode_confirmed_named_state_transfer(
			code, offset, end_limit, allow_non_strict_expressions
		)
		if state_transfer.get("matched", false):
			return state_transfer.result
		var voice_marker := decode_resource_marker_at(code, offset, end_limit)
		if voice_marker.matched:
			return voice_marker.result
		var system_call := _decode_system_call(code, offset, end_limit, allow_non_strict_expressions)
		if system_call.get("matched", false):
			return system_call.result
		return _finish(code, offset, cursor, "statement_separator", command_id, [], end_limit)
	if command_id == 0x0B:
		var expression_result := _parse_expression(code, cursor, end_limit, allow_non_strict_expressions)
		if not expression_result.ok:
			return _nested_error("Command 0x0B condition", expression_result, offset)
		cursor = int(expression_result.end_offset)
		if cursor + 4 > end_limit:
			return _error("Command 0x0B target is truncated.", offset)
		var target := int(code.decode_u32(cursor))
		cursor += 4
		return _finish(code, offset, cursor, "branch_if_not_true", command_id, [
			{"type": "condition", "value": expression_result},
			{"type": "code_offset", "value": target},
		])
	if command_id == 0x0C:
		if cursor + 4 > end_limit:
			return _error("Command 0x0C target is truncated.", offset)
		var target := int(code.decode_u32(cursor))
		cursor += 4
		return _finish(code, offset, cursor, "continuation_transfer", command_id, [
			{"type": "code_offset", "value": target},
		])
	if command_id == 0x14 or command_id == 0x1C:
		var expression_result := _parse_expression(code, cursor, end_limit, allow_non_strict_expressions)
		if not expression_result.ok:
			return _nested_error("Command 0x%02X expression" % command_id, expression_result, offset)
		cursor = int(expression_result.end_offset)
		if cursor + 4 > end_limit:
			return _error("Command 0x%02X target is truncated." % command_id, offset)
		var target := int(code.decode_u32(cursor))
		cursor += 4
		return _finish(
			code,
			offset,
			cursor,
			"bootstrap_transfer" if command_id == 0x14 else "library_register_skip",
			command_id,
			[
				{"type": "expression", "value": expression_result},
				{"type": "code_offset", "value": target},
			]
		)
	if command_id == 0x17 or command_id == 0x1F:
		if cursor + 4 > end_limit:
			return _error("Command 0x%02X u32 is truncated." % command_id, offset)
		var value := int(code.decode_u32(cursor))
		cursor += 4
		return _finish(
			code,
			offset,
			cursor,
			"entry_label" if command_id == 0x17 else "source_line_marker",
			command_id,
			[{"type": "entry_index" if command_id == 0x17 else "source_line", "value": value}]
		)
	if command_id == 0x18:
		var expression_result := _parse_expression(code, cursor, end_limit, allow_non_strict_expressions)
		if not expression_result.ok:
			return _nested_error("Command 0x18 expression", expression_result, offset)
		return _finish(code, offset, int(expression_result.end_offset), "jump_table", command_id, [
			{"type": "expression", "value": expression_result},
		])
	if command_id == 0x03:
		if cursor + 2 > end_limit:
			return _error("Command 0x03 index is truncated.", offset)
		var start_index := int(code.decode_u16(cursor))
		cursor += 2
		var pairs_result := _decode_expression_byte_pairs(code, cursor, end_limit, command_id, 1, allow_non_strict_expressions)
		if not pairs_result.ok:
			return pairs_result
		return _finish(code, offset, int(pairs_result.end_offset), "global_u8_write_run", command_id, [
			{"type": "u16_index", "value": start_index, "source_offset": offset + 1},
			{"type": "expression_byte_pairs", "pairs": pairs_result.operands},
		])
	if command_id == 0x04:
		if cursor >= end_limit:
			return _error("Command 0x04 start index is truncated.", offset)
		var start_index := int(code[cursor])
		cursor += 1
		var pairs_result := _decode_expression_byte_pairs(code, cursor, end_limit, command_id, 1, allow_non_strict_expressions)
		if not pairs_result.ok:
			return pairs_result
		return _finish(code, offset, int(pairs_result.end_offset), "state_u16_write_run", command_id, [
			{"type": "u8_index", "value": start_index, "source_offset": offset + 1},
			{"type": "expression_byte_pairs", "pairs": pairs_result.operands},
		])
	if command_id == 0x0A:
		var destination_result := _parse_expression(code, cursor, end_limit, allow_non_strict_expressions)
		if not destination_result.ok:
			return _nested_error("Command 0x0A destination", destination_result, offset)
		cursor = int(destination_result.end_offset)
		var pairs_result := _decode_expression_byte_pairs(code, cursor, end_limit, command_id, 1, allow_non_strict_expressions)
		if not pairs_result.ok:
			return pairs_result
		return _finish(code, offset, int(pairs_result.end_offset), "global_i32_write_run", command_id, [
			{"type": "expression_index", "value": destination_result},
			{"type": "expression_byte_pairs", "pairs": pairs_result.operands},
		])
	if command_id == 0x05:
		var first_expression := _parse_expression(code, cursor, end_limit, allow_non_strict_expressions)
		if not first_expression.ok:
			return _nested_error("Command 0x05 expression", first_expression, offset)
		cursor = int(first_expression.end_offset)
		var operands: Array[Dictionary] = [{"type": "expression", "value": first_expression}]
		var pairs_result := _decode_expression_byte_pairs(code, cursor, end_limit, command_id, 1, allow_non_strict_expressions)
		if not pairs_result.ok:
			return pairs_result
		operands.append_array(pairs_result.operands)
		return _finish(code, offset, int(pairs_result.end_offset), "dynamic_global_u8_write_run", command_id, operands)
	if command_id in [0x06, 0x07, 0x08]:
		var destination_result := _parse_expression(code, cursor, end_limit, allow_non_strict_expressions)
		if not destination_result.ok:
			return _nested_error("Command 0x%02X destination" % command_id, destination_result, offset)
		cursor = int(destination_result.end_offset)
		if cursor >= end_limit:
			return _error("Command 0x%02X bank is truncated." % command_id, offset)
		var bank := int(code[cursor])
		cursor += 1
		var pairs_result := _decode_expression_byte_pairs(code, cursor, end_limit, command_id, 1, allow_non_strict_expressions)
		if not pairs_result.ok:
			return pairs_result
		var operation: String = str({
			0x06: "banked_u8_write_run",
			0x07: "banked_u16_write_run",
			0x08: "banked_i32_write_run",
		}[command_id])
		return _finish(code, offset, int(pairs_result.end_offset), operation, command_id, [
			{"type": "expression_index", "value": destination_result},
			{"type": "u8_bank", "value": bank, "source_offset": cursor - 1},
			{"type": "expression_byte_pairs", "pairs": pairs_result.operands},
		])
	if command_id == 0x16:
		if cursor >= end_limit:
			return _error("Command 0x16 selector is truncated.", offset)
		var operands: Array[Dictionary] = [{"type": "u8", "value": int(code[cursor]), "source_offset": cursor}]
		cursor += 1
		var pairs_result := _decode_expression_byte_pairs(code, cursor, end_limit, command_id, 1, allow_non_strict_expressions)
		if not pairs_result.ok:
			return pairs_result
		operands.append_array(pairs_result.operands)
		return _finish(code, offset, int(pairs_result.end_offset), "argument_slot_write_run", command_id, operands)
	if command_id == 0x09:
		var mmo_marker := decode_resource_marker_at(code, offset, end_limit)
		if mmo_marker.matched:
			return mmo_marker.result
		if cursor + 2 > end_limit:
			return _error("Command 0x09 start slot is truncated.", offset)
		var start_slot := int(code.decode_u16(cursor))
		cursor += 2
		var pairs_result := _decode_expression_byte_pairs(code, cursor, end_limit, command_id, 1, allow_non_strict_expressions)
		if not pairs_result.ok:
			return pairs_result
		return _finish(code, offset, int(pairs_result.end_offset), "argument_slot_write_run", command_id, [
			{"type": "u16_index", "value": start_slot, "source_offset": offset + 1},
			{"type": "expression_byte_pairs", "pairs": pairs_result.operands},
		])
	if FIXED_GRAMMARS.has(command_id):
		var fixed := _decode_fixed(
			code,
			offset,
			end_limit,
			command_id,
			str(FIXED_GRAMMARS[command_id]),
			allow_non_strict_expressions
		)
		if fixed.ok and command_id == 0x13 and int(fixed.operands[0].value) == 0xFF:
			fixed["op"] = "message_cursor_no_advance"
		if fixed.ok and command_id == 0x19:
			fixed["op"] = "internal_record_push"
		if fixed.ok and command_id == 0x1A:
			fixed["op"] = "internal_record_pop"
		return fixed
	return _error("Unsupported structural opcode 0x%02X." % command_id, offset)


func _decode_effect_dispatch(
	code: PackedByteArray,
	offset: int,
	limit: int,
	allow_non_strict_expressions: bool
) -> Dictionary:
	# Subcommand 6 owns the entire native typed-record list, including unknown
	# selectors. Never expose its tag/filename/expression bytes as MES writes.
	var prefix := PackedByteArray([0x0D, 0x06, 0xFF])
	if offset + prefix.size() > limit or code.slice(offset, offset + prefix.size()) != prefix:
		return {"matched": false}
	var parsed := _decode_record_list(code, offset + prefix.size(), limit, allow_non_strict_expressions)
	if not parsed.get("ok", false):
		return {"matched": true, "result": _nested_error("Effect typed-record dispatch", parsed, offset)}
	var records: Array = parsed.operand.records
	var selector := -1
	var selector_is_literal := false
	if not records.is_empty() and str(records[0].get("type", "")) == "expression_record":
		var selector_expression: Dictionary = records[0].value
		var selector_ast: Dictionary = selector_expression.get("ast", {})
		selector_is_literal = bool(selector_expression.get("valid", true)) and str(selector_ast.get("type", "")) == "literal"
		if selector_is_literal:
			selector = int(selector_ast.value)
	var operand := {
		"type": "effect_dispatch",
		"presentation_subcommand": 6,
		"execution_selector": selector,
		"selector_source": "literal" if selector_is_literal else "expression_or_native_default_unresolved",
		"records": records,
		"native_record_count": records.size(),
		"native_record_terminator_consumed": true,
		"native_record_parser": 0x0043E800,
		"native_adapter": 0x00429D70,
		"native_dispatcher": 0x00429E00,
		"native_effect_semantics": "unresolved_not_executed",
		"tool_execution_semantics": "metadata_only_native_effect_omitted",
	}
	var op := "effect_dispatch"
	# Promote only the observed named-load shape; every other complete list
	# remains opaque at the same exact boundary, including unsafe filenames.
	if (
		selector_is_literal and selector == 0 and records.size() == 3
		and str(records[1].get("type", "")) == "string_record"
		and str(records[2].get("type", "")) == "expression_record"
		and bool(records[2].value.get("valid", true))
	):
		var raw_name: PackedByteArray = records[1].value.raw_bytes
		var printable_ascii := not raw_name.is_empty() and raw_name.size() <= 255
		for character in raw_name:
			if character < 0x20 or character > 0x7E:
				printable_ascii = false
				break
		var source_name := raw_name.get_string_from_ascii() if printable_ascii else ""
		if (
			printable_ascii
			and ArcReaderScript.is_safe_entry_name(source_name)
			and source_name.get_extension().to_lower() == "wav"
		):
			op = "effect_request"
			operand["type"] = op
			operand["resource_kind"] = "effect"
			operand["resource_archive"] = "se.arc"
			operand["name"] = source_name.get_basename().to_upper() + ".WAV"
			operand["source_name"] = source_name
			operand["channel_expression"] = records[2].value.duplicate(true)
			operand["native_effect_semantics"] = "named_effect_request_host_playback_not_executed"
	var result := _finish(code, offset, int(parsed.end_offset), op, 0x0D, [operand])
	result["native_stream_consumption"] = "typed_presentation_subcommand_6_record_list"
	result.erase("native_stream_probe")
	return {"matched": true, "result": result}


func _decode_confirmed_native_presentation_control(
	code: PackedByteArray,
	offset: int,
	limit: int
) -> Dictionary:
	var selected_cell_control := _decode_ax_selected_cell_control(code, offset, limit)
	if selected_cell_control.get("matched", false):
		return selected_cell_control
	# These literal one-record envelopes occur on the audited EVENTB03 shared-
	# library prefix or on the adjacent event routes used to validate it. They
	# are promoted only as complete exact byte sequences: nearby selector/mode
	# values retain the generic native boundary.
	var ax_selector_2 := PackedByteArray([0x0D, 0x03, 0xFF, 0x02, 0x02, 0xFF, 0x00])
	var ax_selector_6 := PackedByteArray([0x0D, 0x03, 0xFF, 0x02, 0x06, 0xFF, 0x00])
	var ax_selector_7 := PackedByteArray([0x0D, 0x03, 0xFF, 0x02, 0x07, 0xFF, 0x00])
	var ax_selector_8 := PackedByteArray([0x0D, 0x03, 0xFF, 0x02, 0x08, 0xFF, 0x00])
	var surface_mode_1 := PackedByteArray([0x0D, 0x0A, 0xFF, 0x02, 0x01, 0xFF, 0x00])
	if offset + ax_selector_2.size() <= limit and code.slice(
		offset, offset + ax_selector_2.size()
	) == ax_selector_2:
		var selected_cell_result := _finish(
			code,
			offset,
			offset + ax_selector_2.size(),
			"ax_presentation_control",
			0x0D,
			[{
				"type": "ax_presentation_control",
				"presentation_subcommand": 3,
				"execution_selector": 2,
				"consumer_selection_semantics": "bounds_checked_owner_vector_entry",
				"consumer_vector_offset": 0x4B578,
				"cell_rows": 10,
				"cell_columns": 32,
				"cell_record_bytes": 0x2C,
				"cell_state_offset": 0,
				"cell_state_value": 1,
				"native_dispatch_table": 0x00429338,
				"native_dispatch_branch": 0x004290DD,
				"native_consumer_virtual_slot": 0x10,
				"native_consumer_handler": 0x00410C10,
				"native_bounded_effect": "set_selected_ax_cell_state_to_1",
				"gameplay_state_effect": "none_observed",
				"tool_execution_semantics": "metadata_only_native_effect_omitted",
			}]
		)
		selected_cell_result["native_stream_consumption"] = (
			"typed_presentation_subcommand_3_selector_2_literal_record"
		)
		selected_cell_result.erase("native_stream_probe")
		return {"matched": true, "result": selected_cell_result}
	if offset + ax_selector_6.size() <= limit and code.slice(
		offset, offset + ax_selector_6.size()
	) == ax_selector_6:
		var mark_active_result := _finish(
			code,
			offset,
			offset + ax_selector_6.size(),
			"ax_presentation_control",
			0x0D,
			[{
				"type": "ax_presentation_control",
				"presentation_subcommand": 3,
				"execution_selector": 6,
				"consumer_selection_semantics": "bounds_checked_owner_vector_entry",
				"consumer_vector_offset": 0x4B578,
				"cell_rows": 10,
				"cell_columns": 32,
				"cell_record_bytes": 0x2C,
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
				"gameplay_state_effect": "none_observed",
				"tool_execution_semantics": "metadata_only_native_effect_omitted",
			}]
		)
		mark_active_result["native_stream_consumption"] = (
			"typed_presentation_subcommand_3_selector_6_literal_record"
		)
		mark_active_result.erase("native_stream_probe")
		return {"matched": true, "result": mark_active_result}
	if offset + ax_selector_7.size() <= limit and code.slice(
		offset, offset + ax_selector_7.size()
	) == ax_selector_7:
		var invalidate_result := _finish(
			code,
			offset,
			offset + ax_selector_7.size(),
			"ax_presentation_control",
			0x0D,
			[{
				"type": "ax_presentation_control",
				"presentation_subcommand": 3,
				"execution_selector": 7,
				"consumer_index": 0,
				"consumer_selection_semantics": "only_registered_consumer",
				"consumer_virtual_slot": 0x20,
				"cell_rows": 10,
				"cell_columns": 32,
				"cell_record_bytes": 0x2C,
				"cell_state_offset": 0,
				"inactive_state": 0xFF,
				"native_dispatch_branch": 0x0042920F,
				"native_consumer_handler": 0x00410CC0,
				"native_nested_cell_handler": 0x00410C30,
				"native_nested_cell_virtual_slot": 0x14,
				"native_bounded_effect": "set_all_10x32_cell_states_to_inactive_0xff",
				"gameplay_state_effect": "none_observed",
				"tool_execution_semantics": "metadata_only_native_effect_omitted",
			}]
		)
		invalidate_result["native_stream_consumption"] = (
			"typed_presentation_subcommand_3_selector_7_literal_record"
		)
		invalidate_result.erase("native_stream_probe")
		return {"matched": true, "result": invalidate_result}
	if offset + ax_selector_8.size() <= limit and code.slice(
		offset, offset + ax_selector_8.size()
	) == ax_selector_8:
		var activate_result := _finish(
			code,
			offset,
			offset + ax_selector_8.size(),
			"ax_presentation_control",
			0x0D,
			[{
				"type": "ax_presentation_control",
				"presentation_subcommand": 3,
				"execution_selector": 8,
				"consumer_selection_semantics": "bounds_checked_owner_vector_entry",
				"consumer_vector_offset": 0x4B578,
				"cell_rows": 10,
				"cell_columns": 32,
				"cell_record_bytes": 0x2C,
				"native_dispatch_table": 0x00429338,
				"native_dispatch_branch": 0x0042924B,
				"native_activation_handler": 0x00411140,
				"native_wait_helper": 0x00411290,
				"native_initial_transition": "state_0_to_3",
				"native_ordinary_wait_transition": "state_3_to_4",
				"native_bounded_effect": "activate_bound_ax_cells_and_wait_for_terminal_states",
				"native_tick_and_rendering": "not_simulated",
				"gameplay_state_effect": "none_observed",
				"tool_execution_semantics": "metadata_only_native_effect_omitted",
			}]
		)
		activate_result["native_stream_consumption"] = (
			"typed_presentation_subcommand_3_selector_8_literal_record"
		)
		activate_result.erase("native_stream_probe")
		return {"matched": true, "result": activate_result}
	if offset + surface_mode_1.size() <= limit and code.slice(
		offset, offset + surface_mode_1.size()
	) == surface_mode_1:
		var composition_result := _finish(
			code,
			offset,
			offset + surface_mode_1.size(),
			"surface_composition_control",
			0x0D,
			[{
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
				"native_optional_fill_path_taken": false,
				"native_bounded_effect": "opaque_surface_composition_then_host_refresh",
				"native_surface_content_and_lifetime": "unresolved",
				"gameplay_state_effect": "none_observed",
				"tool_execution_semantics": "metadata_only_pixel_effect_omitted",
			}]
		)
		composition_result["native_stream_consumption"] = (
			"typed_presentation_subcommand_10_mode_1_literal_record"
		)
		composition_result.erase("native_stream_probe")
		return {"matched": true, "result": composition_result}
	return {"matched": false}


func _decode_ax_selected_cell_control(code: PackedByteArray, offset: int, limit: int) -> Dictionary:
	# Native 0x428F50/0x428FD9 owns the complete typed record list for
	# selectors 1/2. Its payload is not a sibling command-03 global write.
	# Missing row/column/consumer fields are zero-filled by 0x43E800.
	var prefix := PackedByteArray([0x0D, 0x03, 0xFF, 0x02])
	if offset + 6 > limit or code.slice(offset, offset + 4) != prefix:
		return {"matched": false}
	var selector := int(code[offset + 4])
	if selector not in [1, 2] or int(code[offset + 5]) != 0xFF:
		return {"matched": false}
	# Preserve the existing seven-byte selector-2 metadata contract.
	if selector == 2 and offset + 7 <= limit and int(code[offset + 6]) == 0:
		return {"matched": false}
	var parsed := _decode_record_list(code, offset + 3, limit, true)
	if not parsed.get("ok", false):
		return {"matched": true, "result": _nested_error("AX selected-cell control", parsed, offset)}
	var records: Array = parsed.operand.records
	if records.is_empty() or records.size() > 4:
		return {"matched": true, "result": _error("AX selected-cell control requires one to four literal records.", offset)}
	var values: Array[int] = [selector, 0, 0, 0]
	for index in records.size():
		var record: Dictionary = records[index]
		var expression: Dictionary = record.get("value", {})
		var ast: Dictionary = expression.get("ast", {})
		if str(record.get("type", "")) != "expression_record" or not expression.get("valid", false) or str(ast.get("type", "")) != "literal":
			return {"matched": true, "result": _error("AX selected-cell control has an unqualified nonliteral argument.", offset)}
		values[index] = int(ast.value)
	if values[1] < 0 or values[1] >= 10 or values[2] < 0 or values[2] >= 32 or values[3] != 0:
		return {"matched": true, "result": _error("AX selected-cell control is outside the bounded 10x32, consumer-zero domain.", offset)}
	var result := _finish(code, offset, int(parsed.end_offset), "ax_presentation_control", 0x0D, [{
		"type": "ax_presentation_control",
		"presentation_subcommand": 3,
		"execution_selector": selector,
		"consumer_index": values[3],
		"consumer_selection_semantics": "bounds_checked_owner_vector_entry",
		"consumer_vector_offset": 0x4B578,
		"cell_row": values[1],
		"cell_column": values[2],
		"cell_rows": 10,
		"cell_columns": 32,
		"cell_record_bytes": 0x2C,
		"cell_state_offset": 0,
		"cell_state_value": selector - 1,
		"native_dispatch_table": 0x00429338,
		"native_dispatch_branch": 0x0042909F if selector == 1 else 0x004290DD,
		"native_consumer_virtual_slot": 0x0C if selector == 1 else 0x10,
		"native_consumer_handler": 0x00410BF0 if selector == 1 else 0x00410C10,
		"native_bounded_effect": "set_selected_ax_cell_state_to_%d" % (selector - 1),
		"native_state_transition_semantics": "activate_current_cell_cursor" if selector == 1 else "request_inactive_at_wait_boundary_not_immediate_freeze",
		"native_record_count": records.size(),
		"native_defaulted_arguments": 4 - records.size(),
		"native_record_parser": 0x0043E800,
		"gameplay_state_effect": "none_observed",
		"tool_execution_semantics": "metadata_only_native_effect_omitted",
	}])
	result["native_stream_consumption"] = "typed_presentation_subcommand_3_selector_%d_literal_record_list" % selector
	result.erase("native_stream_probe")
	return {"matched": true, "result": result}


func _decode_confirmed_surface_dispatch(
	code: PackedByteArray,
	offset: int,
	limit: int,
	allow_non_strict_expressions: bool
) -> Dictionary:
	# Outer presentation command 0x0D evaluates subcommand 11, then parses a
	# typed expression-record list.  The original Kakyu corpus uses only three
	# exact pixel-operation shapes: mode 0 with 8/9 records, mode 1 with 9,
	# and mode 2 with 5. Two original envelopes are structurally complete but
	# do not have one of those shapes; they retain the whole native boundary as
	# an unresolved dispatch rather than exposing nested record bytes as MES.
	# The native adapter turns inclusive endpoints into width/height and calls
	# an opaque copy, RGB-key copy, or active-surface fill helper respectively.
	var header := PackedByteArray([0x0D, 0x0B, 0xFF])
	if offset + header.size() > limit or code.slice(offset, offset + header.size()) != header:
		return {"matched": false}
	var record_result := _decode_record_list(
		code,
		offset + header.size(),
		limit,
		allow_non_strict_expressions
	)
	if not record_result.ok:
		return {"matched": true, "result": record_result}
	var records: Array = record_result.operand.get("records", [])
	for record in records:
		if str(record.get("type", "")) != "expression_record":
			return {"matched": false}
	var expressions: Array[Dictionary] = []
	for record in records:
		expressions.append((record as Dictionary).get("value", {}).duplicate(true))
	var mode := -1
	var mode_is_literal := false
	if not records.is_empty():
		var mode_ast: Dictionary = records[0].get("value", {}).get("ast", {})
		mode_is_literal = str(mode_ast.get("type", "")) == "literal"
		if mode_is_literal:
			mode = int(mode_ast.get("value", -1))
	var valid_shape := (
		mode_is_literal
		and ((mode == 0 and records.size() in [8, 9])
		or (mode == 1 and records.size() == 9)
		or (mode == 2 and records.size() == 5))
	)
	var valid_display_refresh_shape := mode_is_literal and mode == 13 and records.size() == 6
	if valid_display_refresh_shape:
		var refresh_operand := {
			"type": "native_surface_display_refresh",
			"presentation_subcommand": 11,
			"mode": mode,
			"record_count": records.size(),
			"expressions": expressions,
			"inclusive_left": expressions[1],
			"inclusive_top": expressions[2],
			"inclusive_right": expressions[3],
			"inclusive_bottom": expressions[4],
			"refresh_origin_default": [0, 0],
			"native_endpoint_semantics": "inclusive_width_height_expansion_confirmed",
			"native_operation_semantics": "conditional_attached_display_rectangle_refresh_confirmed",
			"native_adapter": 0x0042ABA0,
			"native_consumer": 0x0042AC30,
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
			"gameplay_state_effect": "none_observed",
			"tool_execution_semantics": "native_display_refresh_omitted",
		}
		var refresh_result := _finish(
			code,
			offset,
			int(record_result.end_offset),
			"surface_display_refresh",
			0x0D,
			[refresh_operand]
		)
		refresh_result["native_stream_consumption"] = "typed_presentation_subcommand_11_record_list"
		refresh_result.erase("native_stream_probe")
		return {"matched": true, "result": refresh_result}
	if not valid_shape:
		var dispatch_operand := {
			"type": "native_surface_dispatch",
			"presentation_subcommand": 11,
			"record_count": records.size(),
			"expressions": expressions,
			"mode": mode,
			"mode_source": "literal" if mode_is_literal else "native_record_default_unresolved",
			"native_adapter": 0x0042ABA0,
			"native_consumer": 0x0042AC30,
			"native_dispatch_max_mode": 7,
			"native_out_of_range_target": 0x0042AFDD,
			"native_common_tail": 0x0042AFE5,
			"native_dispatch_semantics": (
				"out_of_range_mode_skips_switch_body_then_reaches_common_tail"
				if mode_is_literal and mode > 7
				else "mode_or_default_argument_effect_unresolved"
			),
			"native_effect_semantics": "unresolved_not_executed",
			"gameplay_state_effect": "unresolved_not_applied",
			"tool_execution_semantics": "native_effects_omitted",
		}
		var dispatch_result := _finish(
			code,
			offset,
			int(record_result.end_offset),
			"surface_dispatch_unresolved",
			0x0D,
			[dispatch_operand]
		)
		dispatch_result["native_stream_consumption"] = "typed_presentation_subcommand_11_record_list"
		dispatch_result.erase("native_stream_probe")
		return {"matched": true, "result": dispatch_result}
	var semantics := {
		0: "opaque_rectangle_copy_confirmed",
		1: "rgb_chroma_key_rectangle_copy_confirmed",
		2: "active_surface_rectangle_fill_confirmed",
	}
	var helper := {
		0: 0x004254D0,
		1: 0x004255D0,
		2: 0x00425B10,
	}
	var operand := {
		"type": "native_surface_operation",
		"presentation_subcommand": 11,
		"mode": mode,
		"record_count": records.size(),
		"expressions": expressions,
		"source_x": expressions[1],
		"source_y": expressions[2],
		"inclusive_right": expressions[3],
		"inclusive_bottom": expressions[4],
		"native_endpoint_semantics": "inclusive_width_height_expansion_confirmed",
		"native_operation_semantics": str(semantics[mode]),
		"native_adapter": 0x0042ABA0,
		"native_consumer": 0x0042AC30,
		"native_pixel_helper": int(helper[mode]),
		"native_surface_vector_offset": 0x128,
		"native_pixel_bytes": 3,
		"gameplay_state_effect": "none_observed",
		"tool_execution_semantics": "native_pixel_effect_omitted",
	}
	if mode in [0, 1]:
		operand["source_surface_index"] = expressions[5]
		operand["destination_x"] = expressions[6]
		operand["destination_y"] = expressions[7]
		if records.size() == 9:
			operand["destination_surface_index"] = expressions[8]
		else:
			operand["destination_surface_default"] = 0
		if mode == 1:
			operand["native_transparency_key_source"] = "presentation_context_rgb_key"
	else:
		operand["native_target_surface"] = "active_surface_state_index"
		operand["native_active_surface_state_offset"] = 0x20BA
		operand["native_fill_color_source"] = "presentation_context_rgb_color"
	var result := _finish(
		code,
		offset,
		int(record_result.end_offset),
		"surface_operation",
		0x0D,
		[operand]
	)
	result["native_stream_consumption"] = "typed_presentation_subcommand_11_record_list"
	result.erase("native_stream_probe")
	return {"matched": true, "result": result}


func _decode_confirmed_voice_marker(code: PackedByteArray, offset: int, limit: int) -> Dictionary:
	# The outer 0x0D enters native presentation dispatch. Subcommand 7 parses
	# typed records: selector value 2, one NUL-terminated name, then value 0.
	var marker_header := PackedByteArray([0x0D, 0x07, 0xFF, 0x02, 0x02, 0xFF, 0x01])
	var marker_suffix := PackedByteArray([0x02, 0x00, 0xFF, 0x00])
	if offset + marker_header.size() > limit:
		return {"matched": false}
	if code.slice(offset, offset + marker_header.size()) != marker_header:
		return {"matched": false}
	var name_start := offset + marker_header.size()
	var cursor := name_start
	while cursor < limit and cursor - name_start <= 255 and code[cursor] != 0:
		if code[cursor] < 0x20 or code[cursor] > 0x7E:
			return {"matched": false}
		cursor += 1
	if cursor >= limit or code[cursor] != 0:
		return {"matched": true, "result": _error("Voice marker filename is unterminated.", offset)}
	var raw_name := code.slice(name_start, cursor)
	var source_name := raw_name.get_string_from_ascii()
	var extension := source_name.get_extension().to_lower()
	if (
		extension != "ogg"
		or not ArcReaderScript.is_safe_entry_name(source_name)
	):
		return {"matched": false}
	var suffix_start := cursor + 1
	var marker_end := suffix_start + marker_suffix.size()
	if marker_end > limit:
		return {"matched": true, "result": _error("Voice marker envelope is truncated.", offset)}
	if code.slice(suffix_start, marker_end) != marker_suffix:
		return {"matched": false}
	var normalized_name := source_name.get_basename().to_upper() + ".OGG"
	var result := _finish(code, offset, marker_end, "voice_marker", 0x0D, [{
		"type": "resource_name",
		"resource_kind": "voice_marker",
		"name": normalized_name,
		"source_name": source_name,
		"raw_bytes": raw_name,
		"raw_hex": raw_name.hex_encode(),
		"source_offset": name_start,
		"presentation_subcommand": 7,
		"queue_selector": 2,
		"playback_selector": 3,
		"native_consumer_semantics": "presentation_queue_and_stream_handoff_confirmed",
		"native_audible_output": "confirmed_directsound_play_dispatch",
		"native_audible_evidence": "static_executable_rtti_vtable_and_idirectsoundbuffer_abi",
		"native_host_device_output": "not_observed_by_static_audit",
		"tool_preview_semantics": "godot_only",
	}])
	result["native_stream_consumption"] = "typed_presentation_subcommand_7_record_list"
	result.erase("native_stream_probe")
	return {
		"matched": true,
		"result": result,
	}


func _decode_confirmed_inline_script_execution(
	code: PackedByteArray,
	offset: int,
	limit: int
) -> Dictionary:
	# Presentation subcommand 8 selector 2 loads a library script and selector 3
	# loads a definition script. The native handler runs the loaded stream
	# synchronously, then restores the prior coordinate/context pair.
	var header := PackedByteArray([0x0D, 0x08, 0xFF, 0x02])
	if offset + header.size() + 3 > limit:
		return {"matched": false}
	if code.slice(offset, offset + header.size()) != header:
		return {"matched": false}
	var selector := int(code[offset + 4])
	if selector not in [2, 3] or code[offset + 5] != 0xFF or code[offset + 6] != 0x01:
		return {"matched": false}
	var name_start := offset + 7
	var cursor := name_start
	while cursor < limit and cursor - name_start <= 255 and code[cursor] != 0:
		if code[cursor] < 0x20 or code[cursor] > 0x7E:
			return {"matched": false}
		cursor += 1
	if cursor >= limit or code[cursor] != 0:
		return {
			"matched": true,
			"result": _error("Inline script execution filename is unterminated.", offset),
		}
	var raw_name := code.slice(name_start, cursor)
	var source_name := raw_name.get_string_from_ascii()
	var expected_extension := "lib" if selector == 2 else "mes"
	if (
		source_name.get_extension().to_lower() != expected_extension
		or not ArcReaderScript.is_safe_entry_name(source_name)
	):
		return {"matched": false}
	var marker_end := cursor + 2
	if marker_end > limit:
		return {
			"matched": true,
			"result": _error("Inline script execution envelope is truncated.", offset),
		}
	if code[cursor + 1] != 0:
		return {"matched": false}
	var result := _finish(code, offset, marker_end, "inline_script_execution", 0x0D, [{
		"type": "resource_name",
		"resource_kind": "mes_script",
		"name": source_name.to_upper(),
		"source_name": source_name,
		"raw_bytes": raw_name,
		"raw_hex": raw_name.hex_encode(),
		"source_offset": name_start,
		"presentation_subcommand": 8,
		"execution_selector": selector,
		"execution_role": "library_bootstrap" if selector == 2 else "definition_bootstrap",
		"native_consumer_semantics": "archive_entry_load_inline_execute_restore_confirmed",
		"native_context_restore": "confirmed",
		"tool_execution_semantics": "not_executed",
	}])
	result["native_stream_consumption"] = "typed_presentation_subcommand_8_record_list"
	result.erase("native_stream_probe")
	return {
		"matched": true,
		"result": result,
	}


func _decode_confirmed_named_state_transfer(
	code: PackedByteArray,
	offset: int,
	limit: int,
	allow_non_strict_expressions: bool
) -> Dictionary:
	# Presentation subcommand 4 selector 13 deserializes one host state record,
	# then restores only the relative-offset slots named by an A..Z/_A.._Z
	# mapping string. Executable audit v22 confirms the offset-copy loop; it
	# does not prove the source record's contents or authorize sandbox mutation.
	var header := PackedByteArray([0x0D, 0x04, 0xFF, 0x02, 0x0D, 0xFF])
	if offset + header.size() > limit or code.slice(offset, offset + header.size()) != header:
		return {"matched": false}
	var record_result := _decode_record_list(
		code,
		offset + header.size(),
		limit,
		allow_non_strict_expressions
	)
	if not record_result.ok:
		return {"matched": true, "result": record_result}
	var records: Array = record_result.operand.get("records", [])
	if (
		records.size() != 2
		or str(records[0].get("type", "")) != "expression_record"
		or str(records[1].get("type", "")) != "string_record"
	):
		return {"matched": false}
	var mapping_raw: PackedByteArray = records[1].get("value", {}).get(
		"raw_bytes", PackedByteArray()
	)
	var mapping_result := _decode_named_offset_mappings(mapping_raw)
	if not mapping_result.ok:
		return {"matched": false}
	var result := _finish(
		code,
		offset,
		int(record_result.end_offset),
		"named_state_transfer",
		0x0D,
		[{
			"type": "native_state_transfer",
			"presentation_subcommand": 4,
			"transfer_selector": 13,
			"snapshot_selector": records[0].value,
			"mapping_string": mapping_raw.get_string_from_ascii(),
			"mappings": mapping_result.mappings,
			"native_consumer_semantics": "named_relative_offset_restore_confirmed",
			"native_copy_scope": "relative_offsets_only",
			"native_source_record_contents": "unresolved",
			"tool_execution_semantics": "not_executed",
		}]
	)
	result["native_stream_consumption"] = "typed_presentation_subcommand_4_record_list"
	result.erase("native_stream_probe")
	return {"matched": true, "result": result}


func _decode_named_offset_mappings(raw_bytes: PackedByteArray) -> Dictionary:
	if raw_bytes.is_empty():
		return {"ok": false}
	var cursor := 0
	var mappings: Array[Dictionary] = []
	while cursor < raw_bytes.size():
		var uses_i32_table := false
		if int(raw_bytes[cursor]) == 0x5F:
			uses_i32_table = true
			cursor += 1
			if cursor >= raw_bytes.size():
				return {"ok": false}
		var letter := int(raw_bytes[cursor])
		if letter < 0x41 or letter > 0x5A:
			return {"ok": false}
		var letter_index := letter - 0x41
		var name := String.chr(letter)
		if uses_i32_table:
			name = "_" + name
		mappings.append({
			"name": name,
			"letter_index": letter_index,
			"table": "i32_relative_offset" if uses_i32_table else "u16_relative_offset",
			"slot_offset": (
				0x20EC + letter_index * 4
				if uses_i32_table
				else 0x2084 + letter_index * 2
			),
		})
		cursor += 1
	return {"ok": true, "mappings": mappings}


func _decode_confirmed_ax_marker(code: PackedByteArray, offset: int, limit: int) -> Dictionary:
	# Outer command 0x0D enters presentation subcommand 8. Selector 0 passes
	# the AX name and banked_i32[0][2] argument to the document Data loader.
	# The latter is an engine-initialized destination-buffer pointer; the loaded
	# AX payload's token semantics remain unresolved.
	var header := PackedByteArray([0x0D, 0x08, 0xFF, 0x02, 0x00, 0xFF, 0x01])
	var suffix := PackedByteArray([0x02, 0x02, 0xF9, 0x00, 0xFF, 0x00])
	if offset + header.size() > limit or code.slice(offset, offset + header.size()) != header:
		return {"matched": false}
	var name_start := offset + header.size()
	var cursor := name_start
	while cursor < limit and cursor - name_start <= 255 and code[cursor] != 0:
		if code[cursor] < 0x20 or code[cursor] > 0x7E:
			return {"matched": false}
		cursor += 1
	if cursor >= limit or code[cursor] != 0:
		return {"matched": true, "result": _error("AX marker filename is unterminated.", offset)}
	var raw_name := code.slice(name_start, cursor)
	var source_name := raw_name.get_string_from_ascii()
	if source_name.get_extension().to_lower() != "ax" or not ArcReaderScript.is_safe_entry_name(source_name):
		return {"matched": false}
	var suffix_start := cursor + 1
	if suffix_start + suffix.size() > limit:
		return {"matched": true, "result": _error("AX marker envelope is truncated.", offset)}
	if code.slice(suffix_start, suffix_start + suffix.size()) != suffix:
		return {"matched": false}
	var normalized_name := source_name.get_basename().to_upper() + ".AX"
	var result := _finish(code, offset, suffix_start + suffix.size(), "ax_resource_marker", 0x0D, [{
			"type": "resource_name",
			"resource_kind": "ax_marker",
			"name": normalized_name,
			"source_name": source_name,
			"raw_bytes": raw_name,
			"raw_hex": raw_name.hex_encode(),
			"source_offset": name_start,
			"presentation_subcommand": 8,
			"execution_selector": 0,
			"data_archive_index": 0,
			"native_consumer_semantics": "data_arc_named_entry_load_confirmed",
			"native_loader_argument": "banked_i32[0][2]",
			"native_loader_argument_semantics": "engine_initialized_destination_buffer_pointer",
			"native_payload_semantics": "unresolved",
		}])
	result["native_stream_consumption"] = "typed_presentation_subcommand_8_selector_0_record_list"
	result.erase("native_stream_probe")
	return {"matched": true, "result": result}


func _decode_confirmed_ax_binding(code: PackedByteArray, offset: int, limit: int) -> Dictionary:
	# Outer command 0x0D enters presentation subcommand 3. Selector 0 routes
	# row 0, column 0..2, and the AX destination buffer to the only registered
	# consumer's virtual slot +0x08. The native method installs one entry-relative
	# table record in a 10x32 cell; drawing and AX subrecord semantics remain
	# outside this bounded contract.
	var prefix := PackedByteArray([
		0x0D, 0x03, 0xFF,
		0x02, 0x00, 0xFF,
		0x02, 0x00, 0xFF,
		0x02,
	])
	var suffix := PackedByteArray([0xFF, 0x02, 0x02, 0xF9, 0x00, 0xFF, 0x00])
	if offset + prefix.size() + 1 + suffix.size() > limit:
		return {"matched": false}
	if code.slice(offset, offset + prefix.size()) != prefix:
		return {"matched": false}
	var column := int(code[offset + prefix.size()])
	if column < 0 or column > 2:
		return {"matched": false}
	var suffix_start := offset + prefix.size() + 1
	if code.slice(suffix_start, suffix_start + suffix.size()) != suffix:
		return {"matched": false}
	var result := _finish(
		code,
		offset,
		suffix_start + suffix.size(),
		"ax_presentation_binding",
		0x0D,
		[{
			"type": "ax_presentation_binding",
			"presentation_subcommand": 3,
			"execution_selector": 0,
			"consumer_index": 0,
			"consumer_virtual_slot": 0x08,
			"cell_row": 0,
			"cell_column": column,
			"buffer_argument": "banked_i32[0][2]",
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
			"tool_execution_semantics": "not_executed",
		}]
	)
	result["native_stream_consumption"] = "typed_presentation_subcommand_3_selector_0_ax_binding_record_list"
	result.erase("native_stream_probe")
	return {"matched": true, "result": result}


func _decode_confirmed_mmo_marker(code: PackedByteArray, offset: int, limit: int) -> Dictionary:
	if (
		offset <= 0
		or int(code[offset - 1]) != 0x0D
		or offset + 3 > limit
		or code[offset + 1] != 0xFF
		or code[offset + 2] != 0x01
	):
		return {"matched": false}
	var name_start := offset + 3
	var cursor := name_start
	while cursor < limit and cursor - name_start <= 255 and code[cursor] != 0:
		cursor += 1
	if cursor >= limit or code[cursor] != 0:
		return {"matched": false}
	var raw_name := code.slice(name_start, cursor)
	var resource_name := raw_name.get_string_from_ascii()
	if resource_name.get_extension().to_lower() != "mmo" or not ArcReaderScript.is_safe_entry_name(resource_name):
		return {"matched": false}
	# The first NUL terminates the filename and the second terminates the native
	# presentation argument list. Any following byte begins a separate MES
	# instruction and must not be consumed as part of this record.
	var suffix := PackedByteArray([0x00])
	var suffix_start := cursor + 1
	if suffix_start + suffix.size() > limit:
		return {"matched": true, "result": _error("Presentation subcommand 9 MMO argument-list terminator is truncated.", offset)}
	if code.slice(suffix_start, suffix_start + suffix.size()) != suffix:
		return {"matched": false}
	var end_offset := suffix_start + suffix.size()
	return {
		"matched": true,
		"result": _finish(code, offset, end_offset, "mmo_resource_marker", 0x09, [
			_mmo_marker_operand(name_start, raw_name, resource_name, offset - 1),
		]),
	}


func _mmo_marker_operand(
	name_start: int, raw_name: PackedByteArray, resource_name: String, outer_offset: int
) -> Dictionary:
	return {
		"type": "resource_name",
		"resource_kind": "mmo_marker",
		"name": resource_name,
		"raw_bytes": raw_name,
		"raw_hex": raw_name.hex_encode(),
		"source_offset": name_start,
		"outer_command": 0x0D,
		"outer_command_source_offset": outer_offset,
		"presentation_subcommand": 9,
		"argument_count": 1,
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
		"tool_preview_semantics": "decoded_frame_without_native_surface_composition",
	}


const NAME_INSERT_EXPRESSION_HEX := "00f90000a000e0f1400be0ff"
const SYSTEM_CALL_CONSUMPTION := "system_call_selector_expression_and_record_list"


func _decode_system_call(
	code: PackedByteArray, offset: int, limit: int, allow_non_strict_expressions: bool
) -> Dictionary:
	# Command 0x0D as the engine reads it: one system call. A selector expression
	# names the system function, then the same typed record list every structured
	# command carries supplies its arguments. Every confirmed presentation form
	# above is an instance of this grammar; this rule frames the rest, so the
	# bytes after the selector are never read as further commands. An explicit
	# empty selector (`0D FF`, two library bootstraps) selects function 0.
	var cursor := offset + 1
	if cursor >= limit:
		return {"matched": false}
	var selector: Dictionary
	var function := -1
	if int(code[cursor]) == 0xFF:
		selector = {"type": "empty_selector", "value": 0, "source_offset": cursor, "end_offset": cursor + 1}
		function = 0
		cursor += 1
	else:
		var expression_result := _parse_expression(code, cursor, limit, allow_non_strict_expressions)
		if not expression_result.ok:
			return {"matched": false}
		if expression_result.has("valid") and not bool(expression_result.valid):
			# A structural decode keeps a malformed expression's framing; a
			# selector that is not one value is not a call, so the bytes keep
			# their separator reading rather than claiming a false call.
			return {"matched": false}
		cursor = int(expression_result.end_offset)
		selector = {"type": "expression", "value": expression_result}
		function = _literal_expression_value(expression_result)
	var record_result := _decode_record_list(code, cursor, limit, allow_non_strict_expressions)
	if not record_result.ok:
		return {"matched": false}
	var classified := _classify_system_call(offset, function, selector, record_result.operand)
	var result := _finish(code, offset, int(record_result.end_offset), str(classified.op), 0x0D, classified.operands)
	# The call owns its whole envelope; the character-stream probe that a bare
	# 0x0D otherwise carries does not describe it. The three calls the runner
	# and the presentation tools already name keep the shape they had.
	result.erase("native_stream_probe")
	if str(classified.op) == "system_call":
		result["native_stream_consumption"] = SYSTEM_CALL_CONSUMPTION
	else:
		result.erase("native_stream_consumption")
		result.erase("native_handler_family")
	if function >= 0:
		result["system_function"] = function
	return {"matched": true, "result": result}


func _literal_expression_value(expression: Dictionary) -> int:
	var ast: Dictionary = expression.get("ast", {})
	if str(ast.get("type", "")) != "literal":
		return -1
	return int(ast.get("value", -1))


func _classify_system_call(
	offset: int, function: int, selector: Dictionary, record_list: Dictionary
) -> Dictionary:
	# Function 14 with the protagonist-name expression is the name insert the
	# runner presents (formerly a separator plus a 0x0E record), a lone string
	# argument the literal insert; function 9 with one safe .MMO name is the
	# presentation-9 marker (formerly a separator plus a 0x09 record), which
	# keeps its single resource operand so its consumers are unchanged.
	var records: Array = record_list.get("records", [])
	if function == 14 and records.size() == 1:
		var row: Dictionary = records[0]
		if str(row.get("type", "")) == "expression_record" and str(row.value.get("raw_hex", "")) == NAME_INSERT_EXPRESSION_HEX:
			return {"op": "protagonist_name_insert", "operands": [record_list]}
		if str(row.get("type", "")) == "string_record":
			return {"op": "literal_text_insert", "operands": [record_list]}
	if function == 9 and records.size() == 1 and str(records[0].get("type", "")) == "string_record":
		var row: Dictionary = records[0]
		var raw_name: PackedByteArray = row.value.raw_bytes
		var resource_name := raw_name.get_string_from_ascii()
		if (
			raw_name.size() <= 255
			and resource_name.get_extension().to_lower() == "mmo"
			and ArcReaderScript.is_safe_entry_name(resource_name)
		):
			return {"op": "mmo_resource_marker", "operands": [
				_mmo_marker_operand(int(row.value.source_offset), raw_name, resource_name, offset),
			]}
	return {"op": "system_call", "operands": [selector, record_list]}


func _decode_expression_byte_pairs(
	code: PackedByteArray,
	offset: int,
	limit: int,
	command_id: int,
	minimum_pairs: int,
	allow_non_strict_expressions: bool
) -> Dictionary:
	var cursor := offset
	var operands: Array[Dictionary] = []
	while true:
		var expression_result := _parse_expression(code, cursor, limit, allow_non_strict_expressions)
		if not expression_result.ok:
			return _nested_error("Command 0x%02X expression pair" % command_id, expression_result, offset)
		cursor = int(expression_result.end_offset)
		if cursor >= limit:
			return _error("Command 0x%02X continuation is truncated." % command_id, offset)
		var continuation := int(code[cursor])
		cursor += 1
		operands.append({
			"type": "expression_byte_pair",
			"expression": expression_result,
			"continuation": continuation,
		})
		if operands.size() >= minimum_pairs and continuation == 0:
			break
	return {"ok": true, "end_offset": cursor, "operands": operands}


func decode_region(code: PackedByteArray, start: int, end: int, max_instructions := 100000) -> Dictionary:
	return _decode_region(code, start, end, max_instructions, false, false)


func decode_region_structural(code: PackedByteArray, start: int, end: int, max_instructions := 100000) -> Dictionary:
	return _decode_region(code, start, end, max_instructions, true, false)


func decode_region_aligned(code: PackedByteArray, start: int, end: int, max_instructions := 100000) -> Dictionary:
	return _decode_region(code, start, end, max_instructions, false, true)


func decode_region_structural_aligned(
	code: PackedByteArray,
	start: int,
	end: int,
	max_instructions := 100000
) -> Dictionary:
	return _decode_region(code, start, end, max_instructions, true, true)


func _decode_region(
	code: PackedByteArray,
	start: int,
	end: int,
	max_instructions: int,
	allow_non_strict_expressions: bool,
	align_bounded_native_streams: bool
) -> Dictionary:
	if start < 0 or end < start or end > code.size():
		return _error("Instruction region is outside bytecode.", start)
	var instructions: Array[Dictionary] = []
	var cursor := start
	while cursor < end and instructions.size() < max_instructions:
		var instruction := _decode_at(code, cursor, end, allow_non_strict_expressions)
		if not instruction.ok:
			return {
				"ok": false,
				"error": instruction.error,
				"decoded_end_offset": cursor,
				"instructions": instructions,
			}
		if align_bounded_native_streams:
			instruction = _align_bounded_native_stream(code, instruction, end)
		instructions.append(instruction)
		cursor = int(instruction.end_offset)
	if cursor < end:
		return {
			"ok": false,
			"error": "Instruction region exceeded its step limit.",
			"decoded_end_offset": cursor,
			"instructions": instructions,
		}
	return {"ok": true, "decoded_end_offset": cursor, "instructions": instructions}


func _align_bounded_native_stream(
	code: PackedByteArray,
	instruction: Dictionary,
	limit: int
) -> Dictionary:
	var probe: Dictionary = instruction.get("native_stream_probe", {})
	var payload_end := int(probe.get("probe_end_offset", -1))
	var instruction_end := int(instruction.get("end_offset", -1))
	if (
		int(probe.get("consumed_byte_count", 0)) <= 0
		or payload_end <= instruction_end
		or payload_end > limit
	):
		return instruction
	# Only the EXE/runner-qualified separator case is promoted here. A generic
	# character-stream probe is not proof that every following byte belongs to
	# that dispatch; broad promotion changes valid instruction alignment. A
	# 0x0B/0x0C anywhere in the handler-consumed single-byte run is distinct:
	# leaving the prefix as sibling bytes can expose that internal payload byte
	# as MES control flow even when it is not the first byte after command 0x0D.
	var shadow_control_offsets: Array[int] = []
	for payload_offset in range(instruction_end, payload_end):
		if int(code[payload_offset]) in [0x0B, 0x0C]:
			shadow_control_offsets.append(payload_offset)
	if (
		int(instruction.get("command_id", -1)) != 0x0D
		or shadow_control_offsets.is_empty()
	):
		return instruction
	var aligned := instruction.duplicate(true)
	aligned["native_dispatch_instruction_end_offset"] = instruction_end
	aligned["native_payload_start_offset"] = instruction_end
	aligned["native_payload_end_offset"] = payload_end
	aligned["native_payload_byte_length"] = payload_end - instruction_end
	aligned["native_payload_raw_hex"] = code.slice(instruction_end, payload_end).hex_encode()
	aligned["native_payload_boundary"] = "bounded_byte_preserving_opaque_stream"
	aligned["native_shadow_control_offsets"] = shadow_control_offsets
	aligned["end_offset"] = payload_end
	aligned["byte_length"] = payload_end - int(instruction.source_offset)
	aligned["raw_hex"] = code.slice(int(instruction.source_offset), payload_end).hex_encode()
	return aligned


func _decode_fixed(
	code: PackedByteArray,
	offset: int,
	limit: int,
	command_id: int,
	grammar: String,
	allow_non_strict_expressions: bool
) -> Dictionary:
	var cursor := offset + 1
	var operands: Array[Dictionary] = []
	for field in grammar:
		if field == "b":
			if cursor >= limit:
				return _error("Command 0x%02X u8 is truncated." % command_id, offset)
			operands.append({"type": "u8", "value": int(code[cursor]), "source_offset": cursor})
			cursor += 1
		else:
			var expression_result := _parse_expression(code, cursor, limit, allow_non_strict_expressions)
			if not expression_result.ok:
				return _nested_error("Command 0x%02X expression" % command_id, expression_result, offset)
			operands.append({"type": "expression", "value": expression_result})
			cursor = int(expression_result.end_offset)
	return _finish(code, offset, cursor, "command_%02x" % command_id, command_id, operands, limit)


func _decode_cstring(code: PackedByteArray, offset: int, limit: int) -> Dictionary:
	var cursor := offset
	while cursor < limit and code[cursor] != 0:
		cursor += 1
	if cursor >= limit:
		return _error("CP932 byte string is unterminated.", offset)
	var raw := code.slice(offset, cursor)
	return {
		"ok": true,
		"end_offset": cursor + 1,
		"operand": {
			"type": "cp932_bytes",
			"raw_bytes": raw,
			"raw_hex": raw.hex_encode(),
			"source_offset": offset,
		},
	}


func _decode_record_list(
	code: PackedByteArray,
	offset: int,
	limit: int,
	allow_non_strict_expressions: bool
) -> Dictionary:
	var cursor := offset
	var records: Array[Dictionary] = []
	while cursor < limit:
		var tag_offset := cursor
		var tag := int(code[cursor])
		cursor += 1
		if tag == 0:
			return {
				"ok": true,
				"end_offset": cursor,
				"operand": {
					"type": "record_list",
					"source_offset": offset,
					"end_offset": cursor,
					"records": records,
				},
			}
		if tag == 1:
			var string_result := _decode_cstring(code, cursor, limit)
			if not string_result.ok:
				return string_result
			cursor = int(string_result.end_offset)
			records.append({"tag": tag, "type": "string_record", "source_offset": tag_offset, "value": string_result.operand})
		elif tag == 2:
			var expression_result := _parse_expression(code, cursor, limit, allow_non_strict_expressions)
			if not expression_result.ok:
				return _nested_error("Record-list expression", expression_result, tag_offset)
			cursor = int(expression_result.end_offset)
			records.append({"tag": tag, "type": "expression_record", "source_offset": tag_offset, "value": expression_result})
		else:
			records.append({"tag": tag, "type": "unknown_tag", "source_offset": tag_offset})
	return _error("Structured record list is unterminated.", offset)


func _literal_script_target(operand: Dictionary) -> String:
	var records: Array = operand.get("records", [])
	if records.size() != 1 or str(records[0].get("type", "")) != "string_record":
		return ""
	var raw: PackedByteArray = records[0].get("value", {}).get("raw_bytes", PackedByteArray())
	var target := raw.get_string_from_ascii()
	if raw.is_empty() or target.to_ascii_buffer() != raw:
		return ""
	if not ArcReaderScript.is_safe_entry_name(target) or target.get_extension().to_lower() != "mes":
		return ""
	return target


func _is_protagonist_name_insert(record_list: Dictionary) -> bool:
	var records: Array = record_list.get("records", [])
	if records.size() != 2:
		return false
	if int(records[0].get("tag", -1)) != 0xFF or str(records[0].get("type", "")) != "unknown_tag":
		return false
	if int(records[1].get("tag", -1)) != 0x02 or str(records[1].get("type", "")) != "expression_record":
		return false
	return str(records[1].value.get("raw_hex", "")) == "00f90000a000e0f1400be0ff"


func _is_literal_text_insert(record_list: Dictionary) -> bool:
	var records: Array = record_list.get("records", [])
	return records.size() == 1 and str(records[0].get("type", "")) == "string_record"


func _parse_expression(
	code: PackedByteArray,
	offset: int,
	limit: int,
	allow_non_strict_expressions: bool
) -> Dictionary:
	if allow_non_strict_expressions:
		return _expression.parse_structural(code, offset, limit)
	return _expression.parse(code, offset, limit)


func _finish(
	code: PackedByteArray,
	start: int,
	end: int,
	op: String,
	command_id: int,
	operands: Array,
	native_limit := -1
) -> Dictionary:
	var result := {
		"ok": true,
		"schema": ContentCoreVersionScript.MES_INSTRUCTION_SCHEMA,
		"op": op,
		"command_id": command_id,
		"source_offset": start,
		"end_offset": end,
		"byte_length": end - start,
		"raw_hex": code.slice(start, end).hex_encode(),
		"operands": operands,
	}
	var native_family := str(NATIVE_HANDLER_FAMILIES.get(command_id, ""))
	if native_family.is_empty() and command_id > 0x1F and not _is_character_lead(command_id):
		native_family = "character_stream_presentation"
	if not native_family.is_empty():
		result["native_handler_family"] = native_family
		result["native_stream_consumption"] = "single_byte_run_until_nul_or_primary_double_byte_lead"
		result["native_stream_probe"] = _probe_native_single_byte_stream(
			code,
			end,
			code.size() if native_limit < 0 else mini(native_limit, code.size())
		)
	if _contains_non_strict_expression(operands):
		result["structural_only"] = true
	return result


func _probe_native_single_byte_stream(code: PackedByteArray, offset: int, limit: int) -> Dictionary:
	var cursor := offset
	while cursor < limit:
		var value := int(code[cursor])
		if value == 0:
			cursor += 1
			return {
				"start_offset": offset,
				"probe_end_offset": cursor,
				"consumed_byte_count": cursor - offset,
				"stop_offset": cursor - 1,
				"stop_reason": "nul_consumed",
			}
		if _is_primary_character_lead(value):
			return {
				"start_offset": offset,
				"probe_end_offset": cursor,
				"consumed_byte_count": cursor - offset,
				"stop_offset": cursor,
				"stop_reason": "double_byte_lead_deferred",
			}
		cursor += 1
	return {
		"start_offset": offset,
		"probe_end_offset": cursor,
		"consumed_byte_count": cursor - offset,
		"stop_offset": cursor,
		"stop_reason": "decode_limit",
	}


func _finish_native_double_byte_stream(
	code: PackedByteArray,
	start: int,
	payload_offset: int,
	decoded_end: int,
	op: String,
	command_id: int,
	operands: Array,
	limit: int
) -> Dictionary:
	var result := _finish(code, start, decoded_end, op, command_id, operands)
	var probe := _probe_native_double_byte_stream(code, payload_offset, limit)
	result["native_handler_family"] = "double_byte_character_stream_presentation"
	result["native_stream_consumption"] = "double_byte_pairs_until_nul_or_nonlead"
	result["native_stream_probe"] = probe
	result["native_stream_projection_match"] = (
		str(probe.stop_reason) in ["nul_consumed", "single_byte_marker_deferred"]
		and int(probe.probe_end_offset) == decoded_end
	)
	return result


func _is_deferred_ff_boundary(code: PackedByteArray, probe: Dictionary, limit: int) -> bool:
	var stop_offset := int(probe.get("stop_offset", -1))
	return (
		str(probe.get("stop_reason", "")) == "single_byte_marker_deferred"
		and stop_offset >= 0
		and stop_offset < limit
		and int(code[stop_offset]) == 0xFF
	)


func _cp932_operand(raw_bytes: PackedByteArray, source_offset: int) -> Dictionary:
	return {
		"type": "cp932_bytes",
		"raw_bytes": raw_bytes,
		"raw_hex": raw_bytes.hex_encode(),
		"source_offset": source_offset,
	}


func _probe_native_double_byte_stream(code: PackedByteArray, offset: int, limit: int) -> Dictionary:
	var cursor := offset
	var character_count := 0
	while cursor < limit:
		var value := int(code[cursor])
		if value == 0:
			cursor += 1
			return {
				"start_offset": offset,
				"probe_end_offset": cursor,
				"consumed_byte_count": cursor - offset,
				"character_count": character_count,
				"stop_offset": cursor - 1,
				"stop_reason": "nul_consumed",
			}
		if not _is_character_lead(value):
			return {
				"start_offset": offset,
				"probe_end_offset": cursor,
				"consumed_byte_count": cursor - offset,
				"character_count": character_count,
				"stop_offset": cursor,
				"stop_reason": "single_byte_marker_deferred",
			}
		if cursor + 1 >= limit:
			return {
				"start_offset": offset,
				"probe_end_offset": cursor,
				"consumed_byte_count": cursor - offset,
				"character_count": character_count,
				"stop_offset": cursor,
				"stop_reason": "truncated_pair",
			}
		cursor += 2
		character_count += 1
	return {
		"start_offset": offset,
		"probe_end_offset": cursor,
		"consumed_byte_count": cursor - offset,
		"character_count": character_count,
		"stop_offset": cursor,
		"stop_reason": "decode_limit",
	}


func _contains_non_strict_expression(value: Variant) -> bool:
	if value is Dictionary:
		var dictionary: Dictionary = value
		if dictionary.has("ast") and dictionary.has("valid") and not bool(dictionary.valid):
			return true
		for nested in dictionary.values():
			if _contains_non_strict_expression(nested):
				return true
	elif value is Array:
		for nested in value:
			if _contains_non_strict_expression(nested):
				return true
	return false


func _is_character_lead(command_id: int) -> bool:
	return (
		(command_id >= 0x81 and command_id <= 0x9F)
		or (command_id >= 0xE0 and command_id <= 0xEF)
		or (command_id >= 0xFA and command_id <= 0xFC)
	)


func _is_primary_character_lead(value: int) -> bool:
	return (value >= 0x81 and value <= 0x9F) or (value >= 0xE0 and value <= 0xEF)


func _nested_error(prefix: String, nested: Dictionary, offset: int) -> Dictionary:
	return _error("%s: %s" % [prefix, nested.error], offset)


func _error(message: String, offset := -1) -> Dictionary:
	return {"ok": false, "error": message, "source_offset": offset}
