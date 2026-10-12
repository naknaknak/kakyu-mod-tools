extends SceneTree

const ArcReaderScript := preload("res://content_core/arc_reader.gd")
const AxDwordStreamScript := preload("res://content_core/ax_dword_stream.gd")
const AxBindingTableScript := preload("res://content_core/ax_binding_table.gd")
const AxAnimationScript := preload("res://content_core/ax_animation.gd")
const AxWriterScript := preload("res://content_core/ax_writer.gd")
const EDIT_REOPEN_CANDIDATE_COUNT := 10


func _initialize() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.is_empty():
		push_error("Usage: godot --headless --path . --script res://tools/content_suite/cli/validate_ax_corpus.gd -- <data.arc>")
		quit(2)
		return
	var reader := ArcReaderScript.new()
	if not reader.open(arguments[0].replace("\\", "/")):
		push_error("AX_CORPUS_FAIL reader: %s" % reader.last_error)
		quit(2)
		return
	var codec := AxDwordStreamScript.new()
	var binding_codec := AxBindingTableScript.new()
	var animation_codec := AxAnimationScript.new()
	var writer := AxWriterScript.new()
	var source_sha := reader.get_archive_fingerprint()
	var inspected := 0
	var failures := 0
	var noop_identical := 0
	var edit_reopened := 0
	var edit_candidates_seen := 0
	var total_tokens := 0
	var minimum_tokens := 0x7FFFFFFF
	var maximum_tokens := 0
	var minimum_padding := 0x7FFFFFFF
	var maximum_padding := 0
	var total_cells := 0
	var non_ff_cells := 0
	var target_first_byte_counts: Dictionary = {}
	var monotonic_entries := 0
	var unique_target_entries := 0
	var minimum_entry_bytes := 0x7FFFFFFF
	var maximum_entry_bytes := 0
	var total_shared_records := 0
	var shared_type_counts: Dictionary = {}
	var total_streams := 0
	var total_commands := 0
	var total_dispatches := 0
	var opcode_counts: Dictionary = {}
	var bounded_destination_rects := 0
	var bounded_source_rects := 0
	for entry in reader.get_entries():
		if str(entry.name).get_extension().to_lower() != "ax":
			continue
		var data := reader.read_entry(str(entry.name))
		var result := codec.inspect(data)
		if not result.ok:
			failures += 1
			push_error("AX_CORPUS_FAIL %s: %s" % [entry.name, result.error])
			continue
		var binding := binding_codec.inspect(data)
		if not binding.ok:
			failures += 1
			push_error("AX_CORPUS_FAIL %s binding table: %s" % [entry.name, binding.error])
			continue
		var animation := animation_codec.inspect(data)
		if not animation.ok:
			failures += 1
			push_error("AX_CORPUS_FAIL %s animation: %s" % [entry.name, animation.error])
			continue
		inspected += 1
		total_tokens += int(result.token_count)
		minimum_tokens = mini(minimum_tokens, int(result.token_count))
		maximum_tokens = maxi(maximum_tokens, int(result.token_count))
		minimum_padding = mini(minimum_padding, int(result.padding_bytes))
		maximum_padding = maxi(maximum_padding, int(result.padding_bytes))
		total_cells += int(binding.entry_count)
		non_ff_cells += int(binding.non_ff_entry_count)
		if binding.strictly_increasing:
			monotonic_entries += 1
		if binding.all_targets_unique:
			unique_target_entries += 1
		minimum_entry_bytes = mini(minimum_entry_bytes, data.size())
		maximum_entry_bytes = maxi(maximum_entry_bytes, data.size())
		for target_first_byte in binding.target_first_byte_counts:
			target_first_byte_counts[target_first_byte] = int(target_first_byte_counts.get(target_first_byte, 0)) + int(binding.target_first_byte_counts[target_first_byte])
		total_shared_records += int(animation.shared_record_count)
		total_streams += int(animation.stream_count)
		total_commands += int(animation.command_count)
		total_dispatches += int(animation.shared_record_dispatch_count)
		bounded_destination_rects += int(animation.logical_destination_rect_count)
		bounded_source_rects += int(animation.source_rect_count)
		for dispatch_type in animation.shared_type_counts:
			shared_type_counts[dispatch_type] = int(shared_type_counts.get(dispatch_type, 0)) + int(animation.shared_type_counts[dispatch_type])
		for opcode in animation.opcode_counts:
			opcode_counts[opcode] = int(opcode_counts.get(opcode, 0)) + int(animation.opcode_counts[opcode])

		var serialized := writer.serialize(animation)
		if not serialized.ok:
			failures += 1
			push_error("AX_CORPUS_FAIL %s writer serialize: %s" % [entry.name, serialized.error])
		elif serialized.data == data:
			noop_identical += 1
		else:
			failures += 1
			push_error(
				"AX_CORPUS_FAIL %s writer serialize is not byte-identical (source %d bytes, output %d bytes) at offset 0x%X"
				% [entry.name, data.size(), serialized.data.size(), _first_difference(data, serialized.data)]
			)

		if edit_candidates_seen < EDIT_REOPEN_CANDIDATE_COUNT:
			edit_candidates_seen += 1
			if int(binding.non_ff_entry_count) == 0:
				print("AX_WRITER_SKIP %s: no non-FF cell to edit" % entry.name)
			elif _check_edit_reopen(writer, animation, binding, data, str(entry.name)):
				edit_reopened += 1
			else:
				failures += 1
	if reader.get_archive_fingerprint() != source_sha:
		failures += 1
		push_error("AX_CORPUS_FAIL source archive hash changed")
	print(
		"AX_CORPUS_SUMMARY entries=%d tokens=%d token_range=%d..%d padding_range=%d..%d failures=%d" % [
			inspected, total_tokens, minimum_tokens, maximum_tokens,
			minimum_padding, maximum_padding, failures,
		]
	)
	var shared_type_keys: Array = shared_type_counts.keys()
	shared_type_keys.sort()
	var shared_type_parts: Array[String] = []
	for type_key in shared_type_keys:
		shared_type_parts.append("%d:%d" % [int(type_key), int(shared_type_counts[type_key])])
	var opcode_keys: Array = opcode_counts.keys()
	opcode_keys.sort()
	var opcode_parts: Array[String] = []
	for opcode_key in opcode_keys:
		opcode_parts.append("%02X:%d" % [int(opcode_key), int(opcode_counts[opcode_key])])
	print(
		"AX_ANIMATION_SUMMARY entries=%d shared_records=%d types=%s source8_rects_2688x864=%d destination0_rects_640x400=%d streams=%d commands=%d dispatches=%d opcodes=%s failures=%d" % [
			inspected, total_shared_records, ",".join(shared_type_parts), bounded_source_rects, bounded_destination_rects,
			total_streams, total_commands, total_dispatches, ",".join(opcode_parts), failures,
		]
	)
	var type_keys: Array = target_first_byte_counts.keys()
	type_keys.sort()
	var type_parts: Array[String] = []
	for type_key in type_keys:
		type_parts.append("%02X:%d" % [int(type_key), int(target_first_byte_counts[type_key])])
	print(
		"AX_BINDING_TABLE_SUMMARY entries=%d cells=%d non_ff=%d types=%s monotonic=%d unique=%d entry_bytes=%d..%d failures=%d" % [
			inspected, total_cells, non_ff_cells, ",".join(type_parts), monotonic_entries,
			unique_target_entries, minimum_entry_bytes, maximum_entry_bytes, failures,
		]
	)
	print(
		"AX_WRITER_SUMMARY entries=%d noop_identical=%d edit_reopened=%d failures=%d" % [
			inspected, noop_identical, edit_reopened, failures,
		]
	)
	reader.close()
	quit(1 if failures > 0 else 0)


func _first_difference(source: PackedByteArray, output: PackedByteArray) -> int:
	var shortest := mini(source.size(), output.size())
	for offset in range(shortest):
		if source[offset] != output[offset]:
			return offset
	return shortest


## Grows the first non-FF cell's stream by one byte (an extra 0x00 control
## before its terminal), reserializes, reopens, and checks the writer's
## contract: only that cell's command count and the later cells' table
## targets change, every other stream's bytes are identical, and the audit
## names the one changed cell with a one-byte delta.
func _check_edit_reopen(
	writer: KakyuAxWriter, animation: Dictionary, binding: Dictionary, source: PackedByteArray, entry_name: String
) -> bool:
	var cell: Dictionary = binding.non_ff_entries[0]
	var cell_index := int(cell.index)
	var row := int(cell.row)
	var column := int(cell.column)
	var original_stream: Dictionary = animation.streams[cell_index]
	var original_commands: Array = original_stream.commands
	var grown_commands: Array = original_commands.slice(0, original_commands.size() - 1)
	grown_commands.append({"opcode": 0})
	grown_commands.append(original_commands[original_commands.size() - 1])
	var edited := writer.replace_stream(animation, row, column, grown_commands, bool(original_stream.trailing_stop_ff))
	if not edited.ok:
		push_error("AX_CORPUS_FAIL %s writer replace_stream (%d,%d): %s" % [entry_name, row, column, edited.error])
		return false
	var serialized := writer.serialize(edited)
	if not serialized.ok:
		push_error("AX_CORPUS_FAIL %s writer re-serialize (%d,%d): %s" % [entry_name, row, column, serialized.error])
		return false
	var serialized_data: PackedByteArray = serialized.data
	var reopened := writer.reopen(serialized_data)
	if not reopened.ok:
		push_error("AX_CORPUS_FAIL %s writer reopen (%d,%d): %s" % [entry_name, row, column, reopened.error])
		return false
	var final_animation: Dictionary = reopened.animation

	var new_command_count := int((final_animation.streams[cell_index].commands as Array).size())
	if new_command_count != original_commands.size() + 1:
		push_error(
			"AX_CORPUS_FAIL %s writer edit (%d,%d) command count %d did not grow by exactly one from %d"
			% [entry_name, row, column, new_command_count, original_commands.size()]
		)
		return false

	for check_index in range(320):
		var original_target := int(animation.binding_table.entries[check_index].target_offset)
		var new_target := int(final_animation.binding_table.entries[check_index].target_offset)
		var expected_target := original_target + (1 if check_index > cell_index else 0)
		if new_target != expected_target:
			push_error(
				"AX_CORPUS_FAIL %s writer edit (%d,%d) cell %d target 0x%X, expected 0x%X"
				% [entry_name, row, column, check_index, new_target, expected_target]
			)
			return false
		if check_index == cell_index:
			continue
		var original_bytes := source.slice(int(animation.streams[check_index].start_offset), int(animation.streams[check_index].end_offset))
		var new_bytes := serialized_data.slice(int(final_animation.streams[check_index].start_offset), int(final_animation.streams[check_index].end_offset))
		if original_bytes != new_bytes:
			push_error("AX_CORPUS_FAIL %s writer edit (%d,%d) cell %d bytes changed" % [entry_name, row, column, check_index])
			return false

	var audit := writer.write_audit(source, serialized_data, [{"row": row, "column": column}])
	if not audit.ok:
		push_error("AX_CORPUS_FAIL %s writer audit (%d,%d): %s" % [entry_name, row, column, audit.error])
		return false
	if int(audit.byte_delta) != 1 or audit.changed_cells != [{"row": row, "column": column}]:
		push_error(
			"AX_CORPUS_FAIL %s writer audit (%d,%d) byte_delta=%d changed_cells=%s"
			% [entry_name, row, column, audit.byte_delta, str(audit.changed_cells)]
		)
		return false
	return true
