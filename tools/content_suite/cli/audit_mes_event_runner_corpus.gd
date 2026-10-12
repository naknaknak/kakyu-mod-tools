extends SceneTree

const ArcReaderScript := preload("res://content_core/arc_reader.gd")
const MesContainerScript := preload("res://content_core/mes_container.gd")
const MesEventRunnerScript := preload("res://content_core/mes_event_runner.gd")
const MesInstructionDecoderScript := preload("res://content_core/mes_instruction_decoder.gd")
const SandboxStateScript := preload("res://content_core/mes_sandbox_state.gd")

const SCHEMA := "kakyu_mes_event_runner_corpus_audit/v39"
const SAMPLE_LIMIT := 24


func _init() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.is_empty() or arguments.size() > 3:
		push_error("Usage: audit_mes_event_runner_corpus.gd <mes.arc> [max-anchors|0] [max-steps]")
		quit(2)
		return
	var max_anchors := _parse_nonnegative(arguments[1] if arguments.size() >= 2 else "0")
	var max_steps := _parse_positive(arguments[2] if arguments.size() >= 3 else "2000")
	if max_anchors < 0 or max_steps < 1:
		push_error("max-anchors must be nonnegative and max-steps must be positive")
		quit(2)
		return

	var reader := ArcReaderScript.new()
	if not reader.open(arguments[0]):
		push_error(reader.last_error)
		quit(1)
		return
	var source_sha := reader.get_archive_fingerprint()
	var parser := MesContainerScript.new()
	var runner := MesEventRunnerScript.new()
	var decoder := MesInstructionDecoderScript.new()
	var status_counts := {}
	var decode_error_commands := {}
	var decode_error_reasons := {}
	var decode_error_samples: Array[String] = []
	var invalid_write_commands := {}
	var invalid_write_reasons := {}
	var invalid_write_samples: Array[String] = []
	var invalid_target_commands := {}
	var invalid_target_deltas := {}
	var invalid_target_samples: Array[String] = []
	var unsupported_counts := {}
	var unsupported_samples := {}
	var command_0f_entries := {}
	var command_0f_targets := {}
	var command_0f_record_shapes := {}
	var command_0f_next_commands := {}
	var command_0f_missing_targets := 0
	var command_0f_samples: Array[String] = []
	var command_0e_handoff_entries := {}
	var command_0e_handoff_targets := {}
	var command_0e_handoff_missing_targets := 0
	var command_0e_handoff_samples: Array[String] = []
	var command_1b_selectors := {}
	var command_1b_record_values := {}
	var command_1b_unresolved_records := 0
	var command_11_entries := {}
	var command_11_entry_zero := 0
	var command_11_predecessors := {}
	var command_11_next_commands := {}
	var command_11_recent_writes := {}
	var command_11_selectors := {}
	var command_11_unresolved_selectors := 0
	var command_1d_routines := {}
	var command_1d_entries := {}
	var command_1d_recent_arguments := {}
	var command_1d_with_messages := 0
	var command_1d_stack_signatures := {}
	var command_1d_routine_28_empty_stack := 0
	var command_1d_routine_28_stack_tops := {}
	var native_selection_entries := {}
	var native_selection_record_counts := {}
	var native_selection_string_counts := {}
	var native_selection_expression_counts := {}
	var surface_operation_omissions := 0
	var surface_display_refresh_omissions := 0
	var unresolved_surface_dispatch_omissions := 0
	var unresolved_surface_dispatch_samples: Array[String] = []
	var bootstrap_entries := {}
	var bootstrap_selectors := {}
	var bootstrap_target_commands := {}
	var bootstrap_address_table_targets := 0
	var bootstrap_samples: Array[String] = []
	var address_dispatch_entries := {}
	var address_dispatch_indexes := {}
	var address_dispatch_count := 0
	var argument_run_entries := {}
	var argument_run_starts := {}
	var argument_run_counts := {}
	var native_presentation_entries := {}
	var native_presentation_stop_reasons := {}
	var native_presentation_consumed_counts := {}
	var native_presentation_families := {}
	var native_presentation_samples: Array[String] = []
	var samples: Array[String] = []
	var entry_count := 0
	var anchor_count := 0
	var traced_steps := 0
	var anchors_with_messages := 0
	var message_count := 0
	var persistent_expression_fragments := 0
	var persistent_expression_empty_fallbacks := 0
	var persistent_expression_max_depth := 0
	var structural_instructions := 0
	var fatal_failures: Array[String] = []
	var stopped_at_limit := false

	for entry in reader.get_entries():
		if str(entry.name).get_extension().to_lower() != "mes":
			continue
		var document := parser.parse(reader.read_entry(str(entry.name)), {
			"archive": reader.archive_path.replace("\\", "/").get_file(),
			"entry": str(entry.name),
		})
		if not document.ok:
			fatal_failures.append("%s container: %s" % [str(entry.name), str(document.error)])
			continue
		entry_count += 1
		for anchor in document.entries:
			if max_anchors > 0 and anchor_count >= max_anchors:
				stopped_at_limit = true
				break
			var state := SandboxStateScript.new(1)
			var result := runner.run(
				document.bytecode,
				int(anchor.offset),
				state,
				int(document.header.code_size),
				max_steps,
				{"address_table_offsets": document.header.entry_offsets}
			)
			anchor_count += 1
			traced_steps += result.get("trace", []).size()
			for trace_record in result.get("trace", []):
				if trace_record.get("structural_only", false):
					structural_instructions += 1
				for expression_step in trace_record.get("persistent_expression_steps", []):
					persistent_expression_fragments += 1
					persistent_expression_max_depth = maxi(
						persistent_expression_max_depth,
						maxi(
							int(expression_step.get("stack_depth_before", 0)),
							int(expression_step.get("stack_depth_after", 0))
						)
					)
					if expression_step.get("used_empty_fallback", false):
						persistent_expression_empty_fallbacks += 1
				var trace_effect := str(trace_record.get("effect", ""))
				if trace_effect == "surface_operation_omitted":
					surface_operation_omissions += 1
				elif trace_effect == "surface_display_refresh_omitted":
					surface_display_refresh_omissions += 1
				elif trace_effect == "surface_dispatch_omitted":
					unresolved_surface_dispatch_omissions += 1
					if unresolved_surface_dispatch_samples.size() < SAMPLE_LIMIT:
						unresolved_surface_dispatch_samples.append(
							"%s#%04d intro=0x%X dispatch=0x%X mode=%d records=%d" % [
								str(entry.name),
								int(anchor.index),
								int(anchor.offset),
								int(trace_record.get("source_offset", -1)),
								int(trace_record.get("surface_mode", -1)),
								int(trace_record.get("surface_record_count", -1)),
							]
						)
				if trace_effect == "internal_vector_clear":
					var selector := int(trace_record.get("internal_vector_selector", -1))
					command_1b_selectors[selector] = int(command_1b_selectors.get(selector, 0)) + 1
					var record_value := int(trace_record.get("record_value", -1))
					command_1b_record_values[record_value] = int(command_1b_record_values.get(record_value, 0)) + 1
				elif trace_effect == "bootstrap_transfer":
					bootstrap_entries[str(entry.name)] = true
					var selector := int(trace_record.get("bootstrap_selector", -1))
					var target := int(trace_record.get("next_offset", -1))
					bootstrap_selectors[selector] = int(bootstrap_selectors.get(selector, 0)) + 1
					if document.header.entry_offsets.has(target):
						bootstrap_address_table_targets += 1
					var target_command := int(document.bytecode[target]) if target >= 0 and target < int(document.header.code_size) else -1
					bootstrap_target_commands[target_command] = int(bootstrap_target_commands.get(target_command, 0)) + 1
					if bootstrap_samples.size() < 12:
						bootstrap_samples.append("%s#%04d intro=0x%X stop=0x%X selector=%d target=0x%X target_command=%s table_target=%s" % [
							str(entry.name), int(anchor.index), int(anchor.offset), int(trace_record.get("source_offset", -1)),
							selector, target, _format_command(target_command), str(document.header.entry_offsets.has(target)),
						])
				elif trace_effect == "address_table_dispatch":
					address_dispatch_count += 1
					address_dispatch_entries[str(entry.name)] = true
					var table_index := int(trace_record.get("address_table_index", -1))
					address_dispatch_indexes[table_index] = int(address_dispatch_indexes.get(table_index, 0)) + 1
				elif trace_effect == "argument_slot_write_run":
					argument_run_entries[str(entry.name)] = true
					var start := int(trace_record.get("argument_slot_start", -1))
					var count := int(trace_record.get("argument_slot_count", 0))
					argument_run_starts[start] = int(argument_run_starts.get(start, 0)) + 1
					argument_run_counts[count] = int(argument_run_counts.get(count, 0)) + 1
			var status := str(result.get("status", "unknown"))
			status_counts[status] = int(status_counts.get(status, 0)) + 1
			var messages: Array = result.get("messages", [])
			if not messages.is_empty():
				anchors_with_messages += 1
				message_count += messages.size()
			if status == "invalid_target":
				var stop_offset := int(result.get("offset", -1))
				var stopped_command := int(document.bytecode[stop_offset]) if stop_offset >= 0 and stop_offset < int(document.header.code_size) else -1
				var result_trace: Array = result.get("trace", [])
				var target := int(result_trace[-1].get("next_offset", -1)) if not result_trace.is_empty() else -1
				var target_delta := target - int(document.header.code_size)
				invalid_target_commands[stopped_command] = int(invalid_target_commands.get(stopped_command, 0)) + 1
				invalid_target_deltas[target_delta] = int(invalid_target_deltas.get(target_delta, 0)) + 1
				if invalid_target_samples.size() < SAMPLE_LIMIT:
					invalid_target_samples.append("%s#%04d intro=0x%X stop=0x%X command=%s target=0x%X code_size=0x%X delta=%d" % [
						str(entry.name),
						int(anchor.index),
						int(anchor.offset),
						stop_offset,
						_format_command(stopped_command),
						target,
						int(document.header.code_size),
						target_delta,
					])
			elif status == "invalid_write":
				var stop_offset := int(result.get("offset", -1))
				var stopped_command := int(document.bytecode[stop_offset]) if stop_offset >= 0 and stop_offset < int(document.header.code_size) else -1
				var reason := _normalize_decode_error(str(result.get("error", "missing_error")))
				invalid_write_commands[stopped_command] = int(invalid_write_commands.get(stopped_command, 0)) + 1
				invalid_write_reasons[reason] = int(invalid_write_reasons.get(reason, 0)) + 1
				if invalid_write_samples.size() < SAMPLE_LIMIT:
					invalid_write_samples.append("%s#%04d intro=0x%X stop=0x%X command=%s reason=%s" % [
						str(entry.name),
						int(anchor.index),
						int(anchor.offset),
						stop_offset,
						_format_command(stopped_command),
						reason,
					])
			elif status == "decode_error":
				var stop_offset := int(result.get("offset", -1))
				var stopped_command := int(document.bytecode[stop_offset]) if stop_offset >= 0 and stop_offset < int(document.header.code_size) else -1
				var reason := _normalize_decode_error(str(result.get("error", "missing_error")))
				decode_error_commands[stopped_command] = int(decode_error_commands.get(stopped_command, 0)) + 1
				decode_error_reasons[reason] = int(decode_error_reasons.get(reason, 0)) + 1
				if decode_error_samples.size() < SAMPLE_LIMIT:
					decode_error_samples.append("%s#%04d intro=0x%X stop=0x%X command=%s reason=%s" % [
						str(entry.name),
						int(anchor.index),
						int(anchor.offset),
						stop_offset,
						_format_command(stopped_command),
						reason,
					])
			elif status == "unsupported_opcode":
				var command_id := int(result.get("command_id", -1))
				unsupported_counts[command_id] = int(unsupported_counts.get(command_id, 0)) + 1
				var stop_offset := int(result.get("offset", -1))
				var unsupported_instruction := decoder.decode_at_structural(document.bytecode, stop_offset, int(document.header.code_size))
				var command_samples: Array = unsupported_samples.get(command_id, [])
				if command_samples.size() < 8:
					command_samples.append("%s#%04d intro=0x%X stop=0x%X %s" % [
						str(entry.name),
						int(anchor.index),
						int(anchor.offset),
						stop_offset,
						_unsupported_signature(unsupported_instruction),
					])
					unsupported_samples[command_id] = command_samples
				if command_id == 0x1B:
					command_1b_unresolved_records += 1
			elif status == "script_handoff_boundary":
				var handoff_trace: Array = result.get("trace", [])
				var target := str(handoff_trace[-1].get("target_entry", "")) if not handoff_trace.is_empty() else ""
				command_0e_handoff_entries[str(entry.name)] = true
				command_0e_handoff_targets[target] = int(command_0e_handoff_targets.get(target, 0)) + 1
				if reader.get_entry(target).is_empty():
					command_0e_handoff_missing_targets += 1
				if command_0e_handoff_samples.size() < 12:
					command_0e_handoff_samples.append("%s#%04d intro=0x%X stop=0x%X target=%s" % [
						str(entry.name), int(anchor.index), int(anchor.offset), int(result.get("offset", -1)), target,
					])
			elif status == "script_dispatch_boundary":
				var stop_offset := int(result.get("offset", -1))
				var instruction := decoder.decode_at(document.bytecode, stop_offset, int(document.header.code_size))
				if instruction.ok:
					command_0f_entries[str(entry.name)] = true
					var signature := _command_0f_signature(instruction)
					var target := str(signature.target)
					var shape := str(signature.shape)
					command_0f_targets[target] = int(command_0f_targets.get(target, 0)) + 1
					if reader.get_entry(target).is_empty():
						command_0f_missing_targets += 1
					command_0f_record_shapes[shape] = int(command_0f_record_shapes.get(shape, 0)) + 1
					var next_offset := int(instruction.end_offset)
					var next_command := int(document.bytecode[next_offset]) if next_offset < int(document.header.code_size) else -1
					command_0f_next_commands[next_command] = int(command_0f_next_commands.get(next_command, 0)) + 1
					if command_0f_samples.size() < 12:
						command_0f_samples.append("%s#%04d intro=0x%X stop=0x%X target=%s shape=%s next=%s" % [
							str(entry.name),
							int(anchor.index),
							int(anchor.offset),
							stop_offset,
							target,
							shape,
							_format_command(next_command),
						])
			elif status == "definition_invoke_boundary":
				command_11_entries[str(entry.name)] = true
				if int(anchor.index) == 0:
					command_11_entry_zero += 1
				var result_trace: Array = result.get("trace", [])
				var predecessor := "none" if result_trace.size() < 2 else str(result_trace[-2].get("effect", "unknown"))
				command_11_predecessors[predecessor] = int(command_11_predecessors.get(predecessor, 0)) + 1
				var stopped_record: Dictionary = result_trace[-1]
				if stopped_record.get("selector_resolved", false):
					var selector := int(stopped_record.get("definition_id", -1))
					command_11_selectors[selector] = int(command_11_selectors.get(selector, 0)) + 1
				else:
					command_11_unresolved_selectors += 1
				var next_offset := int(stopped_record.get("end_offset", -1))
				var next_command := int(document.bytecode[next_offset]) if next_offset < int(document.header.code_size) else -1
				command_11_next_commands[next_command] = int(command_11_next_commands.get(next_command, 0)) + 1
				var write_signature := _recent_write_signature(result_trace, state)
				command_11_recent_writes[write_signature] = int(command_11_recent_writes.get(write_signature, 0)) + 1
			elif status == "shared_routine_boundary":
				command_1d_entries[str(entry.name)] = true
				var result_trace: Array = result.get("trace", [])
				var routine_id := int(result_trace[-1].get("routine_id", -1))
				command_1d_routines[routine_id] = int(command_1d_routines.get(routine_id, 0)) + 1
				var argument_signature := _recent_argument_signature(result_trace)
				command_1d_recent_arguments[argument_signature] = int(command_1d_recent_arguments.get(argument_signature, 0)) + 1
				var stack: Array = result_trace[-1].get("persistent_expression_stack", [])
				var stack_signature := "routine%d:depth%d" % [routine_id, stack.size()]
				command_1d_stack_signatures[stack_signature] = int(command_1d_stack_signatures.get(stack_signature, 0)) + 1
				if routine_id == 28:
					if stack.is_empty():
						command_1d_routine_28_empty_stack += 1
					else:
						var stack_top := int(stack[-1])
						command_1d_routine_28_stack_tops[stack_top] = int(command_1d_routine_28_stack_tops.get(stack_top, 0)) + 1
				if not messages.is_empty():
					command_1d_with_messages += 1
			elif status == "native_selection_boundary":
				native_selection_entries[str(entry.name)] = true
				var selection_record: Dictionary = result.get("trace", [])[-1]
				var record_count := int(selection_record.get("record_count", 0))
				var string_count := int(selection_record.get("string_record_count", 0))
				var expression_count := int(selection_record.get("expression_record_count", 0))
				native_selection_record_counts[record_count] = int(native_selection_record_counts.get(record_count, 0)) + 1
				native_selection_string_counts[string_count] = int(native_selection_string_counts.get(string_count, 0)) + 1
				native_selection_expression_counts[expression_count] = int(native_selection_expression_counts.get(expression_count, 0)) + 1
			elif status == "native_presentation_boundary":
				native_presentation_entries[str(entry.name)] = true
				var presentation_record: Dictionary = result.get("trace", [])[-1]
				var native_probe: Dictionary = presentation_record.get("native_stream_probe", {})
				var stop_reason := str(native_probe.get("stop_reason", "unknown"))
				var consumed_count := int(native_probe.get("consumed_byte_count", -1))
				var handler_family := str(presentation_record.get("native_handler_family", "unknown"))
				native_presentation_stop_reasons[stop_reason] = int(native_presentation_stop_reasons.get(stop_reason, 0)) + 1
				native_presentation_consumed_counts[consumed_count] = int(native_presentation_consumed_counts.get(consumed_count, 0)) + 1
				native_presentation_families[handler_family] = int(native_presentation_families.get(handler_family, 0)) + 1
				if native_presentation_samples.size() < 8:
					native_presentation_samples.append("%s#%04d intro=0x%X stop=0x%X consumed=%d reason=%s" % [
						str(entry.name),
						int(anchor.index),
						int(anchor.offset),
						int(result.get("offset", -1)),
						consumed_count,
						stop_reason,
					])
			if samples.size() < SAMPLE_LIMIT and status not in ["script_return", "completed", "dialogue_boundary"]:
				samples.append("%s#%04d intro=0x%X stop=0x%X status=%s command=%s steps=%d messages=%d" % [
					str(entry.name),
					int(anchor.index),
					int(anchor.offset),
					int(result.get("offset", -1)),
					status,
					_format_command(int(result.get("command_id", -1))),
					result.get("trace", []).size(),
					messages.size(),
				])
		if stopped_at_limit:
			break

	if reader.get_archive_fingerprint() != source_sha:
		fatal_failures.append("source mes.arc changed during read-only runner audit")
	reader.close()
	print("MES_EVENT_RUNNER_CORPUS schema=%s entries=%d anchors=%d max_steps=%d limited=%s traced_steps=%d anchors_with_messages=%d messages=%d fatal_failures=%d" % [
		SCHEMA,
		entry_count,
		anchor_count,
		max_steps,
		str(stopped_at_limit),
		traced_steps,
		anchors_with_messages,
		message_count,
		fatal_failures.size(),
	])
	print("MES_EVENT_RUNNER_STATUS " + _format_string_counts(status_counts))
	print("MES_EVENT_RUNNER_ADDRESS_TABLE_DISPATCH count=%d entries=%d indexes=%s" % [
		address_dispatch_count,
		address_dispatch_entries.size(),
		_format_int_counts(address_dispatch_indexes),
	])
	print("MES_EVENT_RUNNER_DECODE_ERRORS commands=%s reasons=%s" % [
		_format_command_counts(decode_error_commands),
		_format_string_counts(decode_error_reasons),
	])
	print("MES_EVENT_RUNNER_INVALID_WRITES commands=%s reasons=%s" % [
		_format_command_counts(invalid_write_commands),
		_format_string_counts(invalid_write_reasons),
	])
	for sample in invalid_write_samples:
		print("MES_EVENT_RUNNER_INVALID_WRITE_SAMPLE ", sample)
	print("MES_EVENT_RUNNER_INVALID_TARGETS commands=%s target_minus_code_size=%s" % [
		_format_command_counts(invalid_target_commands),
		_format_int_counts(invalid_target_deltas),
	])
	for sample in invalid_target_samples:
		print("MES_EVENT_RUNNER_INVALID_TARGET_SAMPLE ", sample)
	for sample in decode_error_samples:
		print("MES_EVENT_RUNNER_DECODE_ERROR_SAMPLE ", sample)
	print("MES_EVENT_RUNNER_PERSISTENT_EXPRESSIONS fragments=%d structural_instructions=%d empty_fallbacks=%d max_stack_depth=%d" % [
		persistent_expression_fragments,
		structural_instructions,
		persistent_expression_empty_fallbacks,
		persistent_expression_max_depth,
	])
	print("MES_EVENT_RUNNER_SURFACE_OPERATIONS omitted=%d display_refreshes=%d unresolved_dispatches=%d" % [
		surface_operation_omissions,
		surface_display_refresh_omissions,
		unresolved_surface_dispatch_omissions,
	])
	for sample in unresolved_surface_dispatch_samples:
		print("MES_EVENT_RUNNER_SURFACE_DISPATCH_SAMPLE ", sample)
	print("MES_EVENT_RUNNER_UNSUPPORTED " + _format_command_counts(unsupported_counts))
	_print_unsupported_samples(unsupported_samples)
	print("MES_EVENT_RUNNER_COMMAND_0E_HANDOFF entries=%d targets=%s missing_targets=%d" % [
		command_0e_handoff_entries.size(),
		_format_string_counts(command_0e_handoff_targets),
		command_0e_handoff_missing_targets,
	])
	print("MES_EVENT_RUNNER_COMMAND_0F entries=%d targets=%s missing_targets=%d record_shapes=%s next=%s" % [
		command_0f_entries.size(),
		_format_string_counts(command_0f_targets),
		command_0f_missing_targets,
		_format_string_counts(command_0f_record_shapes),
		_format_command_counts(command_0f_next_commands),
	])
	print("MES_EVENT_RUNNER_COMMAND_1B native_selectors=%s record_values=%s unresolved_records=%d" % [
		_format_int_counts(command_1b_selectors),
		_format_int_counts(command_1b_record_values),
		command_1b_unresolved_records,
	])
	print("MES_EVENT_RUNNER_COMMAND_11 entries=%d entry_zero=%d selectors=%s unresolved=%d predecessors=%s next=%s recent_writes=%s" % [
		command_11_entries.size(),
		command_11_entry_zero,
		_format_int_counts(command_11_selectors),
		command_11_unresolved_selectors,
		_format_string_counts(command_11_predecessors),
		_format_command_counts(command_11_next_commands),
		_format_string_counts(command_11_recent_writes),
	])
	print("MES_EVENT_RUNNER_COMMAND_1D entries=%d routines=%s recent_arguments=%s stack_depths=%s routine28_empty=%d routine28_tops=%s with_messages=%d" % [
		command_1d_entries.size(),
		_format_int_counts(command_1d_routines),
		_format_string_counts(command_1d_recent_arguments),
		_format_string_counts(command_1d_stack_signatures),
		command_1d_routine_28_empty_stack,
		_format_int_counts(command_1d_routine_28_stack_tops),
		command_1d_with_messages,
	])
	print("MES_EVENT_RUNNER_NATIVE_SELECTION entries=%s record_counts=%s string_counts=%s expression_counts=%s" % [
		",".join(native_selection_entries.keys()) if not native_selection_entries.is_empty() else "none",
		_format_int_counts(native_selection_record_counts),
		_format_int_counts(native_selection_string_counts),
		_format_int_counts(native_selection_expression_counts),
	])
	print("MES_EVENT_RUNNER_COMMAND_14 entries=%d selectors=%s target_commands=%s table_targets=%d" % [
		bootstrap_entries.size(),
		_format_int_counts(bootstrap_selectors),
		_format_command_counts(bootstrap_target_commands),
		bootstrap_address_table_targets,
	])
	print("MES_EVENT_RUNNER_COMMAND_16 entries=%d starts=%s counts=%s" % [
		argument_run_entries.size(),
		_format_int_counts(argument_run_starts),
		_format_int_counts(argument_run_counts),
	])
	print("MES_EVENT_RUNNER_NATIVE_PRESENTATION entries=%d families=%s stop_reasons=%s consumed_counts=%s" % [
		native_presentation_entries.size(),
		_format_string_counts(native_presentation_families),
		_format_string_counts(native_presentation_stop_reasons),
		_format_int_counts(native_presentation_consumed_counts),
	])
	for sample in native_presentation_samples:
		print("MES_EVENT_RUNNER_NATIVE_PRESENTATION_SAMPLE ", sample)
	for sample in command_0f_samples:
		print("MES_EVENT_RUNNER_COMMAND_0F_SAMPLE ", sample)
	for sample in command_0e_handoff_samples:
		print("MES_EVENT_RUNNER_COMMAND_0E_HANDOFF_SAMPLE ", sample)
	for sample in bootstrap_samples:
		print("MES_EVENT_RUNNER_COMMAND_14_SAMPLE ", sample)
	for sample in samples:
		print("MES_EVENT_RUNNER_SAMPLE ", sample)
	for failure in fatal_failures:
		push_error(failure)
	quit(1 if not fatal_failures.is_empty() else 0)


func _parse_nonnegative(value: String) -> int:
	return value.to_int() if value.is_valid_int() and value.to_int() >= 0 else -1


func _parse_positive(value: String) -> int:
	return value.to_int() if value.is_valid_int() and value.to_int() > 0 else -1


func _format_command(command_id: int) -> String:
	return "0x%02X" % command_id if command_id >= 0 else "none"


func _format_string_counts(counts: Dictionary) -> String:
	var labels: Array[String] = []
	var keys: Array = counts.keys()
	keys.sort()
	for key in keys:
		labels.append("%s:%d" % [str(key), int(counts[key])])
	return ",".join(labels) if not labels.is_empty() else "none"


func _format_command_counts(counts: Dictionary) -> String:
	var labels: Array[String] = []
	var keys: Array = counts.keys()
	keys.sort()
	for key in keys:
		labels.append("%s:%d" % [_format_command(int(key)), int(counts[key])])
	return ",".join(labels) if not labels.is_empty() else "none"


func _format_int_counts(counts: Dictionary) -> String:
	var labels: Array[String] = []
	var keys: Array = counts.keys()
	keys.sort()
	for key in keys:
		labels.append("%d:%d" % [int(key), int(counts[key])])
	return ",".join(labels) if not labels.is_empty() else "none"


func _normalize_decode_error(error: String) -> String:
	var normalized := error.replace("\r", " ").replace("\n", " ").replace(",", ";").strip_edges()
	var address_pattern := RegEx.new()
	if address_pattern.compile("0x[0-9A-Fa-f]+") == OK:
		normalized = address_pattern.sub(normalized, "0x#", true)
	while normalized.contains("  "):
		normalized = normalized.replace("  ", " ")
	return normalized.left(160) if not normalized.is_empty() else "missing_error"


func _recent_write_signature(trace: Array, state: KakyuMesSandboxState) -> String:
	for index in range(trace.size() - 2, -1, -1):
		var record: Dictionary = trace[index]
		if not record.has("write_storage"):
			continue
		var storage := str(record.write_storage)
		var bank := int(record.get("write_bank", 0))
		var start := int(record.get("write_start", -1))
		var count := int(record.get("write_count", 0))
		var values: Array[String] = []
		for value_index in range(count):
			values.append(str(state.read_value(storage, start + value_index, bank)))
		return "%s[%d:%d..%d]=%s" % [storage, bank, start, start + count - 1, "/".join(values)]
	return "none"


func _recent_argument_signature(trace: Array) -> String:
	for index in range(trace.size() - 2, -1, -1):
		var record: Dictionary = trace[index]
		if str(record.get("effect", "")) == "argument_slot_assignment":
			return "slot%d=%d" % [int(record.get("argument_slot", -1)), int(record.get("argument_value", 0))]
	return "none"


func _command_0f_signature(instruction: Dictionary) -> Dictionary:
	var records: Array = instruction.get("operands", [])[0].get("records", [])
	var parts: Array[String] = []
	var target := "none"
	for record in records:
		var record_type := str(record.get("type", "unknown"))
		if record_type == "string_record":
			var raw: PackedByteArray = record.get("value", {}).get("raw_bytes", PackedByteArray())
			var text := _safe_ascii(raw)
			parts.append("string[%d]" % raw.size())
			if target == "none":
				target = text
		elif record_type == "expression_record":
			var ast: Dictionary = record.get("value", {}).get("ast", {})
			parts.append("expr:%s" % str(ast.get("type", "unknown")))
		else:
			parts.append(record_type)
	return {"target": target, "shape": "+".join(parts) if not parts.is_empty() else "empty"}


func _safe_ascii(raw: PackedByteArray) -> String:
	if raw.is_empty() or raw.size() > 64:
		return "invalid_ascii"
	for value in raw:
		if int(value) < 0x20 or int(value) > 0x7E:
			return "non_ascii"
	return raw.get_string_from_ascii()


func _print_unsupported_samples(samples_by_command: Dictionary) -> void:
	var command_ids: Array = samples_by_command.keys()
	command_ids.sort()
	for command_id in command_ids:
		for sample in samples_by_command[command_id]:
			print("MES_EVENT_RUNNER_UNSUPPORTED_SAMPLE command=%s %s" % [_format_command(int(command_id)), str(sample)])


func _unsupported_signature(instruction: Dictionary) -> String:
	if not instruction.get("ok", false):
		return "decode=failed"
	var parts: Array[String] = ["op=%s" % str(instruction.get("op", "unknown"))]
	var command_id := int(instruction.get("command_id", -1))
	var operands: Array = instruction.get("operands", [])
	if command_id == 0x14 and operands.size() == 2:
		parts.append("expr=%s" % _expression_signature(operands[0].get("value", {})))
		parts.append("target=0x%X" % int(operands[1].get("value", -1)))
	elif command_id in [0x0E, 0x10] and not operands.is_empty():
		parts.append("records=%s" % str(_command_0f_signature({"operands": [operands[0]]}).shape))
	elif command_id == 0x02:
		var native_probe: Dictionary = instruction.get("native_stream_probe", {})
		parts.append("probe=%d:%s" % [
			int(native_probe.get("consumed_byte_count", -1)),
			str(native_probe.get("stop_reason", "unknown")),
		])
	else:
		parts.append("operands=%d" % operands.size())
	parts.append("bytes=%d" % int(instruction.get("byte_length", 0)))
	return " ".join(parts)


func _expression_signature(expression: Dictionary) -> String:
	var ast: Dictionary = expression.get("ast", {})
	var ast_type := str(ast.get("type", "unknown"))
	return "%s:%d" % [ast_type, int(ast.get("value", 0))] if ast_type == "literal" else ast_type
