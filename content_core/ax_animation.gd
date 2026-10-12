class_name KakyuAxAnimation
extends RefCounted

const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")
const AxBindingTableScript := preload("res://content_core/ax_binding_table.gd")

const SHARED_RECORD_BYTES := 0x1C
const LOGICAL_WIDTH := 640
const LOGICAL_HEIGHT := 400
const SOURCE_SURFACE_INDEX := 8
const SOURCE_SURFACE_WIDTH := 2688
const SOURCE_SURFACE_HEIGHT := 864
const DESTINATION_SURFACE_INDEX := 0
const U32_OPERAND_OPCODES := [1, 2, 5, 7]
const TERMINAL_OPCODE_04 := 0x04
const TERMINAL_OPCODE_FF := 0xFF

var _binding_reader := AxBindingTableScript.new()


func inspect(data: PackedByteArray) -> Dictionary:
	var binding := _binding_reader.inspect(data)
	if not binding.ok:
		return _error("AX binding table: %s" % str(binding.error))
	if not binding.strictly_increasing or not binding.all_targets_unique:
		return _error("AX cell stream targets must be strictly increasing and unique for bounded inspection.")

	var shared_bytes := int(binding.minimum_target_offset) - int(binding.table_bytes)
	if shared_bytes <= 0 or shared_bytes % SHARED_RECORD_BYTES != 0:
		return _error("AX shared-record region is not a positive multiple of 0x1C bytes.")
	var shared_record_count := floori(float(shared_bytes) / float(SHARED_RECORD_BYTES))
	var shared_records: Array[Dictionary] = []
	var shared_type_counts: Dictionary = {}
	var logical_rect_count := 0
	var source_rect_count := 0
	for record_index in range(shared_record_count):
		var offset := int(binding.table_bytes) + record_index * SHARED_RECORD_BYTES
		var dispatch_type := int(data.decode_u32(offset))
		var source_x := int(data.decode_u32(offset + 4))
		var source_y := int(data.decode_u32(offset + 8))
		var width := int(data.decode_u32(offset + 12))
		var height := int(data.decode_u32(offset + 16))
		var destination_x := int(data.decode_u32(offset + 20))
		var destination_y := int(data.decode_u32(offset + 24))
		var logical_rect_bounded := (
			width > 0 and height > 0
			and destination_x >= 0 and destination_y >= 0
			and destination_x <= LOGICAL_WIDTH
			and destination_y <= LOGICAL_HEIGHT
			and width <= LOGICAL_WIDTH - destination_x
			and height <= LOGICAL_HEIGHT - destination_y
		)
		var source_rect_bounded := (
			width > 0 and height > 0
			and source_x >= 0 and source_y >= 0
			and source_x <= SOURCE_SURFACE_WIDTH
			and source_y <= SOURCE_SURFACE_HEIGHT
			and width <= SOURCE_SURFACE_WIDTH - source_x
			and height <= SOURCE_SURFACE_HEIGHT - source_y
		)
		if logical_rect_bounded:
			logical_rect_count += 1
		if source_rect_bounded:
			source_rect_count += 1
		shared_type_counts[dispatch_type] = int(shared_type_counts.get(dispatch_type, 0)) + 1
		shared_records.append({
			"index": record_index,
			"offset": offset,
			"dispatch_type": dispatch_type,
			"source_x": source_x,
			"source_y": source_y,
			"width": width,
			"height": height,
			"destination_x": destination_x,
			"destination_y": destination_y,
			"destination_within_640x400": logical_rect_bounded,
			"source_within_surface_8_2688x864": source_rect_bounded,
			"native_consumer": "24bit_green_key_copy" if dispatch_type in [0, 1] else "consumer_noop",
		})

	var streams: Array[Dictionary] = []
	var opcode_counts: Dictionary = {}
	var terminal_counts: Dictionary = {}
	var command_count := 0
	var dispatch_count := 0
	for stream_index in range(int(binding.entry_count)):
		var start := int(binding.entries[stream_index].target_offset)
		var end := data.size()
		if stream_index + 1 < int(binding.entry_count):
			end = int(binding.entries[stream_index + 1].target_offset)
		var parsed := _parse_stream(data, start, end, shared_record_count, opcode_counts)
		if not parsed.ok:
			return _error(
				"AX cell stream (%d,%d) at 0x%X: %s"
				% [int(binding.entries[stream_index].row), int(binding.entries[stream_index].column), start, parsed.error]
			)
		command_count += int(parsed.commands.size())
		dispatch_count += int(parsed.shared_record_dispatch_count)
		terminal_counts[parsed.terminal_opcode] = int(terminal_counts.get(parsed.terminal_opcode, 0)) + 1
		streams.append({
			"index": stream_index,
			"row": int(binding.entries[stream_index].row),
			"column": int(binding.entries[stream_index].column),
			"start_offset": start,
			"end_offset": end,
			"byte_count": end - start,
			"commands": parsed.commands,
			"terminal_opcode": int(parsed.terminal_opcode),
			"trailing_stop_ff": bool(parsed.trailing_stop_ff),
		})

	return {
		"ok": true,
		"schema": ContentCoreVersionScript.AX_ANIMATION_SCHEMA,
		"binding_table": binding,
		"shared_record_bytes": SHARED_RECORD_BYTES,
		"shared_record_count": shared_record_count,
		"shared_records": shared_records,
		"shared_type_counts": shared_type_counts,
		"logical_destination_rect_count": logical_rect_count,
		"all_destination_rects_within_640x400": logical_rect_count == shared_record_count,
		"source_surface_index": SOURCE_SURFACE_INDEX,
		"source_surface_width": SOURCE_SURFACE_WIDTH,
		"source_surface_height": SOURCE_SURFACE_HEIGHT,
		"source_rect_count": source_rect_count,
		"all_source_rects_within_surface_8_2688x864": source_rect_count == shared_record_count,
		"destination_surface_index": DESTINATION_SURFACE_INDEX,
		"destination_surface_width": LOGICAL_WIDTH,
		"destination_surface_height": LOGICAL_HEIGHT,
		"stream_count": streams.size(),
		"streams": streams,
		"command_count": command_count,
		"shared_record_dispatch_count": dispatch_count,
		"opcode_counts": opcode_counts,
		"terminal_counts": terminal_counts,
		"transparent_rgb": 0x00FF00,
		"pixel_bytes": 3,
		"native_source_surface_content_producer": "unresolved",
		"native_tick_and_host_surface_lifetime": "surface_indices_and_dimensions_confirmed_content_and_tick_not_simulated",
	}


func compile_tool_timeline(animation: Dictionary, row: int, column: int, max_steps := 4096) -> Dictionary:
	if not animation.get("ok", false):
		return _error("AX animation inspection is required before timeline compilation.")
	if max_steps <= 0:
		return _error("AX tool timeline step limit must be positive.")
	var selected_stream: Dictionary = {}
	for candidate in animation.get("streams", []):
		if int(candidate.get("row", -1)) == row and int(candidate.get("column", -1)) == column:
			selected_stream = candidate
			break
	if selected_stream.is_empty():
		return _error("AX cell (%d,%d) is not present." % [row, column])
	var commands: Array = selected_stream.get("commands", [])
	var events: Array[Dictionary] = []
	var program_counter := 0
	var tool_tick := 0
	var executed_steps := 0
	var loop_start := -1
	var loop_remaining := 0
	var reset_at_end := false
	while program_counter < commands.size():
		if executed_steps >= max_steps:
			return _error("AX tool timeline exceeded %d expanded command steps." % max_steps)
		var command: Dictionary = commands[program_counter]
		var opcode := int(command.get("opcode", -1))
		executed_steps += 1
		if opcode >= 9 and opcode <= 254:
			events.append({
				"tick": tool_tick,
				"shared_record_index": int(command.get("shared_record_index", -1)),
				"source_offset": int(command.get("offset", -1)),
			})
		elif opcode in [0, 1, 2]:
			pass
		elif opcode == 3:
			reset_at_end = true
			tool_tick += 1
			break
		elif opcode == 5:
			if loop_start >= 0:
				return _error("nested AX control-0x05 loops are not supported by the bounded tool timeline.")
			loop_start = program_counter + 1
			loop_remaining = int(command.get("operand", 0))
			if loop_remaining <= 0:
				return _error("AX control-0x05 loop count must be positive.")
		elif opcode == 6:
			if loop_start < 0 or loop_remaining <= 0:
				return _error("AX control-0x06 has no active control-0x05 loop.")
			loop_remaining -= 1
			if loop_remaining > 0:
				tool_tick += 1
				program_counter = loop_start
				continue
			loop_start = -1
		elif opcode in [4, 0xFF]:
			tool_tick += 1
			break
		else:
			return _error("AX opcode 0x%02X is outside the bounded tool-timeline subset." % opcode)
		tool_tick += 1
		program_counter += 1
	if events.is_empty():
		return _error("AX cell (%d,%d) contains no shared-record dispatch." % [row, column])
	return {
		"ok": true,
		"schema": ContentCoreVersionScript.AX_ANIMATION_SCHEMA,
		"row": row,
		"column": column,
		"stream_start_offset": int(selected_stream.get("start_offset", -1)),
		"stream_end_offset": int(selected_stream.get("end_offset", -1)),
		"tool_ticks_per_cycle": maxi(1, tool_tick),
		"expanded_command_steps": executed_steps,
		"dispatch_events": events,
		"reset_at_end": reset_at_end,
		"timing_basis": "one_tool_tick_per_expanded_ax_command_native_host_cadence_unconfirmed",
	}


func _parse_stream(
	data: PackedByteArray,
	start: int,
	end: int,
	shared_record_count: int,
	opcode_counts: Dictionary
) -> Dictionary:
	var commands: Array[Dictionary] = []
	var cursor := start
	var terminal_opcode := -1
	var trailing_stop_ff := false
	var dispatch_count := 0
	while cursor < end:
		var offset := cursor
		var opcode := int(data[cursor])
		cursor += 1
		opcode_counts[opcode] = int(opcode_counts.get(opcode, 0)) + 1
		var command := {
			"offset": offset,
			"opcode": opcode,
			"kind": _opcode_kind(opcode),
		}
		if opcode in U32_OPERAND_OPCODES or (opcode >= 9 and opcode <= 254):
			if cursor + 4 > end:
				return _error("opcode 0x%02X has a truncated u32 operand." % opcode)
			var operand := int(data.decode_u32(cursor))
			command["operand"] = operand
			cursor += 4
			if opcode >= 9:
				if operand < 0 or operand >= shared_record_count:
					return _error("shared-record index %d exceeds count %d." % [operand, shared_record_count])
				command["shared_record_index"] = operand
				dispatch_count += 1
		commands.append(command)
		if opcode == TERMINAL_OPCODE_04 or opcode == TERMINAL_OPCODE_FF:
			terminal_opcode = opcode
			if opcode == TERMINAL_OPCODE_04 and cursor + 1 == end and data[cursor] == TERMINAL_OPCODE_FF:
				cursor += 1
				trailing_stop_ff = true
			break
	if terminal_opcode < 0:
		return _error("stream has no 0x04 or 0xFF terminal opcode.")
	if cursor != end:
		return _error("%d unconsumed byte(s) follow the terminal opcode." % (end - cursor))
	return {
		"ok": true,
		"commands": commands,
		"terminal_opcode": terminal_opcode,
		"trailing_stop_ff": trailing_stop_ff,
		"shared_record_dispatch_count": dispatch_count,
	}


func _opcode_kind(opcode: int) -> String:
	if opcode >= 9 and opcode <= 254:
		return "shared_record_dispatch"
	match opcode:
		0: return "control_00"
		1: return "control_01_u32"
		2: return "control_02_u32"
		3: return "control_03_cursor_reset"
		4: return "control_04_stop"
		5: return "control_05_loop_begin_u32"
		6: return "control_06_loop_repeat"
		7: return "control_07_loop_begin_u32"
		8: return "control_08_loop_repeat"
		0xFF: return "control_ff_stop"
		_: return "unreachable"


func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message}
