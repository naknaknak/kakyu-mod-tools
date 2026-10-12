class_name KakyuMesEventRunner
extends RefCounted

const PersistentExpressionScript := preload("res://content_core/mes_persistent_expression.gd")
const SandboxStateScript := preload("res://content_core/mes_sandbox_state.gd")
const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")
const BgmCatalogScript := preload("res://content_core/mes_bgm_catalog.gd")
const Cp932CodecScript := preload("res://content_core/cp932_codec.gd")

const DEFAULT_MAX_STEPS := 10000
const STEP_PROVENANCE_COMMANDS := {0x1F: true, 0x17: true}

var _persistent_expression := PersistentExpressionScript.new()
var _cp932 := Cp932CodecScript.new()


func run(
	code: PackedByteArray,
	start_offset: int,
	state: KakyuMesSandboxState,
	end_offset := -1,
	max_steps := DEFAULT_MAX_STEPS,
	preview_context := {}
) -> Dictionary:
	var before := state.snapshot()
	# A caller may supply its own instruction source; the default is this
	# bytecode, decoded exactly as before. See mes_code_source.gd.
	var source: KakyuMesCodeSource = preview_context.get("code_source", null)
	if source == null:
		source = KakyuMesCodeSource.for_bytecode(code)
	if source == null:
		# for_bytecode declares this failure, so it is handled rather than
		# dereferenced. A build without the bytecode implementation must fail
		# closed here, not run against an absent instruction supply.
		return _result("missing_code_source", false, start_offset, [], [], state.diff(before), "No MES code source is available for this bytecode.")
	var limit := source.size() if end_offset < 0 else mini(end_offset, source.size())
	var trace: Array[Dictionary] = []
	var messages: Array[Dictionary] = []
	var definitions: Array[Dictionary] = []
	var definition_groups: Dictionary = {}
	var definition_group_order: Array[int] = []
	var active_definition_group := -1
	var argument_slots: Dictionary = preview_context.get("argument_slots", {}).duplicate(true)
	var has_address_table := preview_context.has("address_table_offsets")
	var address_table_offsets: Array[int] = []
	for untyped_offset in preview_context.get("address_table_offsets", []):
		address_table_offsets.append(int(untyped_offset))
	var expression_stack: Array[int] = []
	for untyped_value in preview_context.get("persistent_expression_stack", []):
		expression_stack.append(int(untyped_value))
	var native_stream_policy := str(preview_context.get("native_stream_policy", "stop"))
	var skip_bounded_native_streams := native_stream_policy in ["skip_bounded", "skip_bounded_preserve_dialogue"]
	var preserve_dialogue_boundaries := native_stream_policy == "skip_bounded_preserve_dialogue"
	var omit_bounded_native_records := str(preview_context.get("native_record_policy", "stop")) == "omit_bounded"
	# Consumer-selected command starts only: never split an envelope or execute
	# its payload. This permits presentation to own a native boundary while
	# retaining omission of other structurally bounded native records.
	var native_record_stop_offsets: Array = preview_context.get("native_record_stop_offsets", [])
	if start_offset < 0 or start_offset >= limit:
		return _result("invalid_start", false, start_offset, trace, messages, state.diff(before), "Start offset is outside the execution range.")
	if max_steps <= 0:
		return _result("step_limit", false, start_offset, trace, messages, state.diff(before), "Step limit must be positive.")

	var cursor := start_offset
	var step := 0
	var budget_steps := 0
	var exclude_provenance := bool(preview_context.get("exclude_provenance_steps", false))
	while budget_steps < max_steps:
		if cursor < 0 or cursor >= limit:
			return _result("completed", true, cursor, trace, messages, state.diff(before))
		var instruction := source.decode_at_structural(cursor, limit)
		if not instruction.ok:
			return _result("decode_error", false, cursor, trace, messages, state.diff(before), str(instruction.error))
		# A record source resolves a target that no longer has a record forward
		# to the next one; for bytecode this is always the cursor itself.
		cursor = int(instruction.source_offset)
		var trace_record := _trace_record(instruction, step)
		step += 1
		# A package omits these inert records. Analysis may budget observable
		# commands so source metadata cannot move a bounded stop or its state.
		if not exclude_provenance or not STEP_PROVENANCE_COMMANDS.has(int(instruction.command_id)):
			budget_steps += 1
		var next_offset := int(instruction.end_offset)
		match int(instruction.command_id):
			0x00:
				trace_record["effect"] = "script_return"
				trace.append(trace_record)
				var return_result := _result("script_return", true, cursor, trace, messages, state.diff(before))
				return_result["argument_slots"] = argument_slots.duplicate(true)
				return_result["persistent_expression_stack"] = expression_stack.duplicate()
				return return_result
			0x12:
				trace_record["effect"] = "native_record_boundary"
				trace_record["native_handler_family"] = str(instruction.get("native_handler_family", ""))
				trace_record["native_record_consumption"] = str(instruction.get("native_record_consumption", ""))
				trace_record["native_record_count"] = int(instruction.get("native_record_count", 0))
				trace_record["native_record_terminator_consumed"] = bool(instruction.get("native_record_terminator_consumed", false))
				trace_record["gameplay_sandbox_changed"] = false
				var supplied := _supplied_map_location(preview_context, cursor)
				if not supplied.is_empty():
					# 0.318.0: a declared map-location contract names this record
					# as a Map.get_location poll and supplies the next location the
					# player reaches; the runner writes it into the cell the native
					# map module writes (state_u16[18], 0xFFFF for none - ai5-sdl2's
					# Kakyuusei map module, System.Map.function[13]) and omits every
					# other effect of the record. Without a contract, or once its
					# locations are spent, the record stays an omitted native.
					var value := int(supplied.value)
					state.write_value(str(supplied.storage), int(supplied.index), value)
					trace_record["effect"] = "map_location_supplied"
					trace_record["map_location_value"] = value
					trace_record["write_storage"] = str(supplied.storage)
					trace_record["write_start"] = int(supplied.index)
					trace_record["write_count"] = 1
					trace_record["write_bank"] = 0
					trace_record["gameplay_sandbox_changed"] = true
					trace_record["next_offset"] = int(instruction.end_offset)
					next_offset = int(instruction.end_offset)
				elif omit_bounded_native_records and cursor not in native_record_stop_offsets:
					trace_record["effect"] = "native_record_effects_omitted"
					trace_record["next_offset"] = int(instruction.end_offset)
					next_offset = int(instruction.end_offset)
				else:
					trace.append(trace_record)
					var boundary_result := _result(
						"native_record_boundary",
						false,
						cursor,
						trace,
						messages,
						state.diff(before),
						"Command 0x12 entered the native typed-record dispatcher; its state and presentation effects are not executed.",
						0x12
					)
					boundary_result["argument_slots"] = argument_slots.duplicate(true)
					boundary_result["persistent_expression_stack"] = expression_stack.duplicate()
					return boundary_result
			0x02:
				var is_dialogue_boundary := _is_confirmed_dialogue_boundary(source, cursor, limit, trace, messages)
				var native_skip_end := _native_skip_end(instruction, limit) if skip_bounded_native_streams else -1
				if preserve_dialogue_boundaries and is_dialogue_boundary:
					var boundary_end := cursor + 4
					trace_record["op"] = "dialogue_boundary_trailer"
					trace_record["effect"] = "dialogue_boundary"
					trace_record["end_offset"] = boundary_end
					trace_record["raw_hex"] = source.hex_range(cursor, boundary_end)
					trace_record["next_offset"] = boundary_end
					trace.append(trace_record)
					var boundary_result := _result(
						"dialogue_boundary",
						true,
						cursor,
						trace,
						messages,
						state.diff(before)
					)
					boundary_result["resume_offset"] = boundary_end
					boundary_result["argument_slots"] = argument_slots.duplicate(true)
					boundary_result["persistent_expression_stack"] = expression_stack.duplicate()
					return boundary_result
				elif native_skip_end > cursor:
					_configure_native_skip(trace_record, instruction, native_skip_end)
					next_offset = native_skip_end
				elif is_dialogue_boundary:
					var boundary_end := cursor + 4
					trace_record["op"] = "dialogue_boundary_trailer"
					trace_record["effect"] = "dialogue_boundary"
					trace_record["end_offset"] = boundary_end
					trace_record["raw_hex"] = source.hex_range(cursor, boundary_end)
					trace_record["next_offset"] = boundary_end
					trace.append(trace_record)
					var boundary_result := _result(
						"dialogue_boundary",
						true,
						cursor,
						trace,
						messages,
						state.diff(before)
					)
					boundary_result["resume_offset"] = boundary_end
					boundary_result["argument_slots"] = argument_slots.duplicate(true)
					boundary_result["persistent_expression_stack"] = expression_stack.duplicate()
					return boundary_result
				else:
					var native_probe: Dictionary = instruction.get("native_stream_probe", {})
					trace_record["effect"] = "native_presentation_boundary"
					trace_record["native_stream_consumption"] = str(instruction.get("native_stream_consumption", ""))
					trace_record["native_stream_probe"] = native_probe.duplicate(true)
					trace_record["gameplay_sandbox_changed"] = false
					trace.append(trace_record)
					return _result(
						"native_presentation_boundary",
						false,
						cursor,
						trace,
						messages,
						state.diff(before),
						"Command 0x02 entered the native character-stream presentation handler; display and cursor effects are not simulated.",
						0x02
					)
			0x17:
				trace_record["effect"] = "fallthrough"
			0x18:
				var address_selector := _evaluate_expression(
					instruction.operands[0].value,
					state,
					expression_stack,
					trace_record,
					"address_table_index"
				)
				if not address_selector.ok:
					trace.append(trace_record)
					return _result("expression_error", false, cursor, trace, messages, state.diff(before), str(address_selector.error))
				var table_index := int(address_selector.value)
				trace_record["address_table_index"] = table_index
				trace_record["gameplay_sandbox_changed"] = false
				if not has_address_table:
					trace_record["effect"] = "address_table_dispatch_boundary"
					trace.append(trace_record)
					var boundary_result := _result(
						"address_table_dispatch_boundary",
						false,
						cursor,
						trace,
						messages,
						state.diff(before),
						"Command 0x18 requires the active MES address table; no table was supplied by the caller.",
						0x18
					)
					boundary_result["argument_slots"] = argument_slots.duplicate(true)
					boundary_result["persistent_expression_stack"] = expression_stack.duplicate()
					return boundary_result
				if table_index < 0 or table_index >= address_table_offsets.size():
					trace_record["effect"] = "invalid_address_table_index"
					trace.append(trace_record)
					return _result(
						"invalid_address_table_index",
						false,
						cursor,
						trace,
						messages,
						state.diff(before),
						"Command 0x18 selected address-table index %d outside 0..%d."
						% [table_index, address_table_offsets.size() - 1],
						0x18
					)
				next_offset = address_table_offsets[table_index]
				if next_offset < 0 or next_offset >= limit:
					trace_record["effect"] = "invalid_address_table_target"
					trace_record["address_table_target"] = next_offset
					trace.append(trace_record)
					return _result(
						"invalid_target",
						false,
						cursor,
						trace,
						messages,
						state.diff(before),
						"Command 0x18 address-table target 0x%X is outside the execution range." % next_offset,
						0x18
					)
				trace_record["effect"] = "address_table_dispatch"
				trace_record["address_table_target"] = next_offset
			0x1F:
				trace_record["effect"] = "source_line_marker"
				trace_record["source_line"] = int(instruction.operands[0].value)
			0x0D:
				if str(instruction.op) in ["effect_request", "effect_dispatch"]:
					var effect_operand: Dictionary = instruction.operands[0]
					trace_record["effect"] = "effect_dispatch_omitted"
					for field in ["presentation_subcommand", "execution_selector", "selector_source", "native_record_count", "native_record_terminator_consumed", "native_record_parser", "native_adapter", "native_dispatcher", "native_effect_semantics", "tool_execution_semantics"]:
						_copy_operand_field(trace_record, effect_operand, field, field)
					trace_record["native_effect_omitted"] = true
					trace_record["gameplay_sandbox_changed"] = false
					if str(instruction.op) == "effect_request":
						var channel := _evaluate_expression(
							effect_operand.channel_expression, state, expression_stack,
							trace_record, "effect_channel"
						)
						if not channel.get("ok", false):
							trace.append(trace_record)
							return _result("expression_error", false, cursor, trace, messages, state.diff(before), str(channel.get("error", "Effect channel expression failed.")))
						trace_record["effect"] = "effect_request"
						trace_record["resource_kind"] = "effect"
						_copy_operand_field(trace_record, effect_operand, "resource_archive", "resource_archive")
						_copy_operand_field(trace_record, effect_operand, "resource_name", "name")
						trace_record["channel_index"] = int(channel.value)
						_copy_operand_field(trace_record, effect_operand, "channel_expression", "channel_expression")
					trace_record["next_offset"] = next_offset
					trace.append(trace_record)
					cursor = next_offset
					continue
				if str(instruction.op) == "ax_presentation_control":
					var control_operand: Dictionary = instruction.operands[0]
					var execution_selector := int(control_operand.execution_selector)
					trace_record["effect"] = {
						1: "ax_selected_cell_state_0_omitted",
						2: "ax_selected_cell_state_1_omitted",
						6: "ax_cells_mark_active_omitted",
						7: "ax_cells_invalidate_omitted",
						8: "ax_cells_activate_wait_omitted",
					}.get(execution_selector, "ax_presentation_control_omitted")
					_copy_operand_field(trace_record, control_operand, "presentation_subcommand", "presentation_subcommand")
					trace_record["execution_selector"] = execution_selector
					_copy_operand_field(trace_record, control_operand, "consumer_selection_semantics", "consumer_selection_semantics")
					_copy_operand_field(trace_record, control_operand, "cell_rows", "cell_rows")
					_copy_operand_field(trace_record, control_operand, "cell_columns", "cell_columns")
					_copy_operand_field(trace_record, control_operand, "cell_record_bytes", "cell_record_bytes")
					_copy_operand_field(trace_record, control_operand, "native_dispatch_branch", "native_dispatch_branch")
					_copy_operand_field(trace_record, control_operand, "native_bounded_effect", "native_bounded_effect")
					_copy_operand_field(trace_record, control_operand, "gameplay_state_effect", "gameplay_state_effect")
					_copy_operand_field(trace_record, control_operand, "tool_execution_semantics", "tool_execution_semantics")
					if execution_selector in [1, 2]:
						for field in ["cell_row", "cell_column", "cell_state_value", "native_state_transition_semantics", "native_defaulted_arguments", "native_record_count"]:
							if control_operand.has(field):
								trace_record[field] = control_operand[field]
						_copy_operand_field(trace_record, control_operand, "consumer_vector_offset", "consumer_vector_offset")
						_copy_operand_field(trace_record, control_operand, "native_dispatch_table", "native_dispatch_table")
						_copy_operand_field(trace_record, control_operand, "native_consumer_virtual_slot", "native_consumer_virtual_slot")
						_copy_operand_field(trace_record, control_operand, "native_consumer_handler", "native_consumer_handler")
						_copy_operand_field(trace_record, control_operand, "cell_state_offset", "cell_state_offset")
						_copy_operand_field(trace_record, control_operand, "cell_state_value", "cell_state_value")
					elif execution_selector == 6:
						_copy_operand_field(trace_record, control_operand, "consumer_vector_offset", "consumer_vector_offset")
						_copy_operand_field(trace_record, control_operand, "native_dispatch_table", "native_dispatch_table")
						_copy_operand_field(trace_record, control_operand, "native_consumer_virtual_slot", "native_consumer_virtual_slot")
						_copy_operand_field(trace_record, control_operand, "native_consumer_handler", "native_consumer_handler")
						_copy_operand_field(trace_record, control_operand, "native_nested_cell_virtual_slot", "native_nested_cell_virtual_slot")
						_copy_operand_field(trace_record, control_operand, "native_nested_cell_handler", "native_nested_cell_handler")
						_copy_operand_field(trace_record, control_operand, "cell_state_offset", "cell_state_offset")
						_copy_operand_field(trace_record, control_operand, "inactive_state", "inactive_state")
						_copy_operand_field(trace_record, control_operand, "cell_update_flag_offset", "cell_update_flag_offset")
						_copy_operand_field(trace_record, control_operand, "cell_update_flag_value", "cell_update_flag_value")
					elif execution_selector == 7:
						_copy_operand_field(trace_record, control_operand, "consumer_index", "consumer_index")
						_copy_operand_field(trace_record, control_operand, "consumer_virtual_slot", "consumer_virtual_slot")
						_copy_operand_field(trace_record, control_operand, "cell_state_offset", "cell_state_offset")
						_copy_operand_field(trace_record, control_operand, "inactive_state", "inactive_state")
						_copy_operand_field(trace_record, control_operand, "native_consumer_handler", "native_consumer_handler")
						_copy_operand_field(trace_record, control_operand, "native_nested_cell_handler", "native_nested_cell_handler")
					else:
						_copy_operand_field(trace_record, control_operand, "consumer_vector_offset", "consumer_vector_offset")
						_copy_operand_field(trace_record, control_operand, "native_dispatch_table", "native_dispatch_table")
						_copy_operand_field(trace_record, control_operand, "native_activation_handler", "native_activation_handler")
						_copy_operand_field(trace_record, control_operand, "native_wait_helper", "native_wait_helper")
						_copy_operand_field(trace_record, control_operand, "native_initial_transition", "native_initial_transition")
						_copy_operand_field(trace_record, control_operand, "native_ordinary_wait_transition", "native_ordinary_wait_transition")
						_copy_operand_field(trace_record, control_operand, "native_tick_and_rendering", "native_tick_and_rendering")
					trace_record["native_effect_omitted"] = true
					trace_record["gameplay_sandbox_changed"] = false
					trace_record["next_offset"] = next_offset
					trace.append(trace_record)
					cursor = next_offset
					continue
				if str(instruction.op) == "surface_composition_control":
					var composition_operand: Dictionary = instruction.operands[0]
					trace_record["effect"] = "surface_composition_control_omitted"
					_copy_operand_field(trace_record, composition_operand, "presentation_subcommand", "presentation_subcommand")
					_copy_operand_field(trace_record, composition_operand, "surface_mode", "literal_mode")
					_copy_operand_field(trace_record, composition_operand, "native_dispatch_route", "native_dispatch_route")
					_copy_operand_field(trace_record, composition_operand, "native_adapter", "native_adapter")
					_copy_operand_field(trace_record, composition_operand, "native_public_context_virtual_slot", "native_public_context_virtual_slot")
					_copy_operand_field(trace_record, composition_operand, "native_control_word_offset", "native_control_word_offset")
					_copy_operand_field(trace_record, composition_operand, "native_control_word_guard", "native_control_word_guard")
					_copy_operand_field(trace_record, composition_operand, "native_surface_indices", "native_surface_indices")
					_copy_operand_field(trace_record, composition_operand, "native_copy_helper", "native_copy_helper")
					_copy_operand_field(trace_record, composition_operand, "native_copy_call_sites", "native_copy_call_sites")
					_copy_operand_field(trace_record, composition_operand, "native_optional_fill_path_taken", "native_optional_fill_path_taken")
					_copy_operand_field(trace_record, composition_operand, "native_bounded_effect", "native_bounded_effect")
					_copy_operand_field(trace_record, composition_operand, "native_surface_content_and_lifetime", "native_surface_content_and_lifetime")
					_copy_operand_field(trace_record, composition_operand, "gameplay_state_effect", "gameplay_state_effect")
					_copy_operand_field(trace_record, composition_operand, "tool_execution_semantics", "tool_execution_semantics")
					trace_record["native_effect_omitted"] = true
					trace_record["gameplay_sandbox_changed"] = false
					trace_record["next_offset"] = next_offset
					trace.append(trace_record)
					cursor = next_offset
					continue
				if str(instruction.op) == "surface_display_refresh":
					var refresh_operand: Dictionary = instruction.operands[0]
					var refresh_values: Array[int] = []
					for expression_index in range((refresh_operand.expressions as Array).size()):
						var evaluated_refresh := _evaluate_expression(
							refresh_operand.expressions[expression_index],
							state,
							expression_stack,
							trace_record,
							"surface_display_refresh_argument_%d" % expression_index
						)
						if not evaluated_refresh.ok:
							trace.append(trace_record)
							return _result(
								"expression_error",
								false,
								cursor,
								trace,
								messages,
								state.diff(before),
								str(evaluated_refresh.error)
							)
						refresh_values.append(int(evaluated_refresh.value))
					var refresh_width := (refresh_values[3] - refresh_values[1] + 1) & 0xFFFF
					var refresh_height := (refresh_values[4] - refresh_values[2] + 1) & 0xFFFF
					trace_record["effect"] = "surface_display_refresh_omitted"
					_copy_operand_field(trace_record, refresh_operand, "presentation_subcommand", "presentation_subcommand")
					_copy_operand_field(trace_record, refresh_operand, "surface_mode", "mode")
					_copy_operand_field(trace_record, refresh_operand, "surface_record_count", "record_count")
					trace_record["surface_arguments"] = refresh_values
					trace_record["refresh_input_bounds"] = [
						refresh_values[1], refresh_values[2], refresh_width, refresh_height,
					]
					trace_record["refresh_rectangle"] = [0, 0, refresh_width, refresh_height]
					_copy_operand_field(trace_record, refresh_operand, "native_operation_semantics", "native_operation_semantics")
					_copy_operand_field(trace_record, refresh_operand, "native_endpoint_semantics", "native_endpoint_semantics")
					_copy_operand_field(trace_record, refresh_operand, "native_refresh_adapter", "native_refresh_adapter")
					_copy_operand_field(trace_record, refresh_operand, "native_rectangle_helper", "native_rectangle_helper")
					_copy_operand_field(trace_record, refresh_operand, "native_raster_operation", "native_raster_operation")
					trace_record["native_display_refresh_omitted"] = true
					trace_record["gameplay_sandbox_changed"] = false
					trace_record["next_offset"] = next_offset
					trace.append(trace_record)
					cursor = next_offset
					continue
				if str(instruction.op) == "surface_dispatch_unresolved":
					var dispatch_operand: Dictionary = instruction.operands[0]
					var dispatch_values: Array[int] = []
					for expression_index in range((dispatch_operand.expressions as Array).size()):
						var evaluated_dispatch := _evaluate_expression(
							dispatch_operand.expressions[expression_index],
							state,
							expression_stack,
							trace_record,
							"surface_dispatch_argument_%d" % expression_index
						)
						if not evaluated_dispatch.ok:
							trace.append(trace_record)
							return _result(
								"expression_error",
								false,
								cursor,
								trace,
								messages,
								state.diff(before),
								str(evaluated_dispatch.error)
							)
						dispatch_values.append(int(evaluated_dispatch.value))
					trace_record["effect"] = "surface_dispatch_omitted"
					_copy_operand_field(trace_record, dispatch_operand, "presentation_subcommand", "presentation_subcommand")
					_copy_operand_field(trace_record, dispatch_operand, "surface_mode", "mode")
					_copy_operand_field(trace_record, dispatch_operand, "surface_mode_source", "mode_source")
					_copy_operand_field(trace_record, dispatch_operand, "surface_record_count", "record_count")
					trace_record["surface_arguments"] = dispatch_values
					_copy_operand_field(trace_record, dispatch_operand, "native_dispatch_semantics", "native_dispatch_semantics")
					_copy_operand_field(trace_record, dispatch_operand, "native_effect_semantics", "native_effect_semantics")
					trace_record["native_effects_omitted"] = true
					trace_record["gameplay_sandbox_changed"] = false
					trace_record["next_offset"] = next_offset
					trace.append(trace_record)
					cursor = next_offset
					continue
				if str(instruction.op) == "surface_operation":
					var surface_operand: Dictionary = instruction.operands[0]
					var surface_values: Array[int] = []
					for expression_index in range((surface_operand.expressions as Array).size()):
						var evaluated_surface := _evaluate_expression(
							surface_operand.expressions[expression_index],
							state,
							expression_stack,
							trace_record,
							"surface_argument_%d" % expression_index
						)
						if not evaluated_surface.ok:
							trace.append(trace_record)
							return _result(
								"expression_error",
								false,
								cursor,
								trace,
								messages,
								state.diff(before),
								str(evaluated_surface.error)
							)
						surface_values.append(int(evaluated_surface.value))
					var source_width := (surface_values[3] - surface_values[1] + 1) & 0xFFFF
					var source_height := (surface_values[4] - surface_values[2] + 1) & 0xFFFF
					trace_record["effect"] = "surface_operation_omitted"
					_copy_operand_field(trace_record, surface_operand, "presentation_subcommand", "presentation_subcommand")
					_copy_operand_field(trace_record, surface_operand, "surface_mode", "mode")
					trace_record["surface_arguments"] = surface_values
					trace_record["source_rectangle"] = [
						surface_values[1], surface_values[2], source_width, source_height,
					]
					_copy_operand_field(trace_record, surface_operand, "native_operation_semantics", "native_operation_semantics")
					_copy_operand_field(trace_record, surface_operand, "native_endpoint_semantics", "native_endpoint_semantics")
					_copy_operand_field(trace_record, surface_operand, "native_pixel_helper", "native_pixel_helper")
					trace_record["native_pixel_effect_omitted"] = true
					trace_record["gameplay_sandbox_changed"] = false
					trace_record["next_offset"] = next_offset
					trace.append(trace_record)
					cursor = next_offset
					continue
				if str(instruction.op) == "ax_resource_marker":
					var ax_operand: Dictionary = instruction.operands[0]
					trace_record["effect"] = "ax_resource_marker"
					trace_record["resource_kind"] = "ax"
					_copy_operand_field(trace_record, ax_operand, "resource_name", "name")
					_copy_operand_field(trace_record, ax_operand, "marker_source_name", "source_name")
					_copy_operand_field(trace_record, ax_operand, "presentation_subcommand", "presentation_subcommand")
					_copy_operand_field(trace_record, ax_operand, "execution_selector", "execution_selector")
					_copy_operand_field(trace_record, ax_operand, "data_archive_index", "data_archive_index")
					_copy_operand_field(trace_record, ax_operand, "native_consumer_semantics", "native_consumer_semantics")
					_copy_operand_field(trace_record, ax_operand, "native_loader_argument", "native_loader_argument")
					_copy_operand_field(trace_record, ax_operand, "native_loader_argument_semantics", "native_loader_argument_semantics")
					_copy_operand_field(trace_record, ax_operand, "native_payload_semantics", "native_payload_semantics")
					trace_record["gameplay_sandbox_changed"] = false
					trace_record["next_offset"] = next_offset
					trace.append(trace_record)
					cursor = next_offset
					continue
				if str(instruction.op) == "ax_presentation_binding":
					var binding_operand: Dictionary = instruction.operands[0]
					trace_record["effect"] = "ax_presentation_binding"
					_copy_operand_field(trace_record, binding_operand, "presentation_subcommand", "presentation_subcommand")
					_copy_operand_field(trace_record, binding_operand, "execution_selector", "execution_selector")
					_copy_operand_field(trace_record, binding_operand, "consumer_index", "consumer_index")
					_copy_operand_field(trace_record, binding_operand, "consumer_virtual_slot", "consumer_virtual_slot")
					_copy_operand_field(trace_record, binding_operand, "cell_row", "cell_row")
					_copy_operand_field(trace_record, binding_operand, "cell_column", "cell_column")
					_copy_operand_field(trace_record, binding_operand, "buffer_argument", "buffer_argument")
					_copy_operand_field(trace_record, binding_operand, "buffer_argument_semantics", "buffer_argument_semantics")
					_copy_operand_field(trace_record, binding_operand, "binding_table_entries", "binding_table_entries")
					_copy_operand_field(trace_record, binding_operand, "binding_table_bytes", "binding_table_bytes")
					_copy_operand_field(trace_record, binding_operand, "binding_offsets", "binding_offsets")
					_copy_operand_field(trace_record, binding_operand, "native_consumer_semantics", "native_consumer_semantics")
					_copy_operand_field(trace_record, binding_operand, "native_bounded_effect", "native_bounded_effect")
					_copy_operand_field(trace_record, binding_operand, "native_rendering_semantics", "native_rendering_semantics")
					_copy_operand_field(trace_record, binding_operand, "native_subrecord_semantics", "native_subrecord_semantics")
					_copy_operand_field(trace_record, binding_operand, "tool_execution_semantics", "tool_execution_semantics")
					trace_record["gameplay_sandbox_changed"] = false
					trace_record["next_offset"] = next_offset
					trace.append(trace_record)
					cursor = next_offset
					continue
				if str(instruction.op) == "named_state_transfer":
					var transfer_operand: Dictionary = instruction.operands[0]
					trace_record["effect"] = "native_state_transfer_boundary"
					_copy_operand_field(trace_record, transfer_operand, "presentation_subcommand", "presentation_subcommand")
					_copy_operand_field(trace_record, transfer_operand, "transfer_selector", "transfer_selector")
					_copy_operand_field(trace_record, transfer_operand, "snapshot_selector", "snapshot_selector")
					_copy_operand_field(trace_record, transfer_operand, "mapping_string", "mapping_string")
					_copy_operand_field(trace_record, transfer_operand, "mappings", "mappings")
					_copy_operand_field(trace_record, transfer_operand, "native_consumer_semantics", "native_consumer_semantics")
					_copy_operand_field(trace_record, transfer_operand, "native_copy_scope", "native_copy_scope")
					_copy_operand_field(trace_record, transfer_operand, "native_source_record_contents", "native_source_record_contents")
					_copy_operand_field(trace_record, transfer_operand, "tool_execution_semantics", "tool_execution_semantics")
					trace_record["gameplay_sandbox_changed"] = false
					trace_record["next_offset"] = next_offset
					trace.append(trace_record)
					return _result(
						"native_state_transfer_boundary",
						false,
						cursor,
						trace,
						messages,
						state.diff(before),
						"Native presentation subcommand 4 selector 13 restores named relative offsets from a host state record; source contents and physical bank aliasing are not simulated.",
						0x0D
					)
				if str(instruction.op) == "voice_marker":
					var voice_operand: Dictionary = instruction.operands[0]
					trace_record["effect"] = "voice_marker"
					trace_record["resource_kind"] = "voice"
					_copy_operand_field(trace_record, voice_operand, "resource_name", "name")
					_copy_operand_field(trace_record, voice_operand, "marker_source_name", "source_name")
					_copy_operand_field(trace_record, voice_operand, "presentation_subcommand", "presentation_subcommand")
					_copy_operand_field(trace_record, voice_operand, "queue_selector", "queue_selector")
					_copy_operand_field(trace_record, voice_operand, "playback_selector", "playback_selector")
					_copy_operand_field(trace_record, voice_operand, "native_consumer_semantics", "native_consumer_semantics")
					_copy_operand_field(trace_record, voice_operand, "native_audible_output", "native_audible_output")
					_copy_operand_field(trace_record, voice_operand, "native_audible_evidence", "native_audible_evidence")
					_copy_operand_field(trace_record, voice_operand, "native_host_device_output", "native_host_device_output")
					_copy_operand_field(trace_record, voice_operand, "tool_preview_semantics", "tool_preview_semantics")
					trace_record["gameplay_sandbox_changed"] = false
					trace_record["next_offset"] = next_offset
					trace.append(trace_record)
					cursor = next_offset
					continue
				if str(instruction.op) == "inline_script_execution":
					var script_operand: Dictionary = instruction.operands[0]
					trace_record["effect"] = "inline_script_execution_boundary"
					trace_record["resource_kind"] = "mes_script"
					_copy_operand_field(trace_record, script_operand, "resource_name", "name")
					_copy_operand_field(trace_record, script_operand, "marker_source_name", "source_name")
					_copy_operand_field(trace_record, script_operand, "presentation_subcommand", "presentation_subcommand")
					_copy_operand_field(trace_record, script_operand, "execution_selector", "execution_selector")
					_copy_operand_field(trace_record, script_operand, "execution_role", "execution_role")
					_copy_operand_field(trace_record, script_operand, "native_consumer_semantics", "native_consumer_semantics")
					_copy_operand_field(trace_record, script_operand, "native_context_restore", "native_context_restore")
					_copy_operand_field(trace_record, script_operand, "tool_execution_semantics", "tool_execution_semantics")
					trace_record["gameplay_sandbox_changed"] = false
					trace_record["next_offset"] = next_offset
					trace.append(trace_record)
					return _result(
						"native_script_execution_boundary",
						false,
						cursor,
						trace,
						messages,
						state.diff(before),
						"Native presentation subcommand 8 would execute %s and restore the prior script context; isolated execution is not enabled."
						% str(script_operand.name),
						0x0D
					)
				if str(instruction.op) == "system_call":
					# Command 0x0D as the engine reads it: one system call. Its
					# selector and arguments are decoded; its presentation effect is
					# omitted like every other native presentation form.
					var system_function := int(instruction.get("system_function", -1))
					trace_record["system_function"] = system_function
					trace_record["argument_count"] = _system_call_argument_count(instruction)
					trace_record["gameplay_sandbox_changed"] = false
					if system_function == 19:
						# Function 19 is the message wait - formerly framed as command
						# 0x13 operand FF - and with argument 2 after a message it is
						# the dialogue boundary the 02 02 FF 00 trailer used to mark.
						trace_record["effect"] = "message_cursor_no_advance"
						# The source answers the pattern so a playback package, which
						# carries the resolved pattern rather than the bytes, agrees.
						var is_dialogue_boundary := (
							not messages.is_empty()
							and source.dialogue_boundary_end(cursor, limit) == next_offset
						)
						if is_dialogue_boundary and (preserve_dialogue_boundaries or not skip_bounded_native_streams):
							trace_record["next_offset"] = next_offset
							trace.append(trace_record)
							var boundary_record := _trace_record(instruction, step)
							step += 1
							boundary_record["op"] = "dialogue_boundary_trailer"
							boundary_record["effect"] = "dialogue_boundary"
							boundary_record["next_offset"] = next_offset
							trace.append(boundary_record)
							var boundary_result := _result(
								"dialogue_boundary",
								true,
								cursor,
								trace,
								messages,
								state.diff(before)
							)
							boundary_result["resume_offset"] = next_offset
							boundary_result["argument_slots"] = argument_slots.duplicate(true)
							boundary_result["persistent_expression_stack"] = expression_stack.duplicate()
							return boundary_result
					else:
						trace_record["effect"] = "system_call_omitted"
						# Counted with the other omitted presentation effects by
						# the script-call, library and registered-DEF runners.
						trace_record["native_effect_omitted"] = true
					trace_record["next_offset"] = next_offset
					trace.append(trace_record)
					cursor = next_offset
					continue
				if str(instruction.op) in ["protagonist_name_insert", "literal_text_insert"]:
					_apply_text_insert(instruction, trace_record, messages, preview_context)
					trace_record["next_offset"] = next_offset
					trace.append(trace_record)
					cursor = next_offset
					continue
				if str(instruction.op) == "mmo_resource_marker":
					_apply_mmo_marker(instruction, trace_record, state)
					trace_record["next_offset"] = next_offset
					trace.append(trace_record)
					cursor = next_offset
					continue
				var separator_probe: Dictionary = instruction.get("native_stream_probe", {})
				var separator_consumed := int(separator_probe.get("consumed_byte_count", 0))
				var separator_payload_lead := source.byte_at(cursor + 1, limit)
				var native_skip_end := _native_skip_end(instruction, limit) if skip_bounded_native_streams else -1
				if native_skip_end > cursor:
					_configure_native_skip(trace_record, instruction, native_skip_end)
					next_offset = native_skip_end
				elif separator_consumed > 1 and separator_payload_lead in [0x0B, 0x0C]:
					trace_record["effect"] = "native_presentation_boundary"
					trace_record["native_stream_consumption"] = str(instruction.get("native_stream_consumption", ""))
					trace_record["native_stream_probe"] = separator_probe.duplicate(true)
					trace_record["gameplay_sandbox_changed"] = false
					trace.append(trace_record)
					return _result(
						"native_presentation_boundary",
						false,
						cursor,
						trace,
						messages,
						state.diff(before),
						"Command 0x0D entered a native single-byte presentation stream whose first payload byte resembles a branch command; it cannot be reinterpreted as MES control flow.",
						0x0D
					)
				else:
					trace_record["effect"] = "statement_separator"
					trace_record["native_stream_probe"] = separator_probe.duplicate(true)
			0x0A:
				var destination := _evaluate_expression(instruction.operands[0].value, state, expression_stack, trace_record, "destination")
				if not destination.ok:
					trace.append(trace_record)
					return _result("expression_error", false, cursor, trace, messages, state.diff(before), str(destination.error))
				var start_index := int(destination.value) & 0xFFFF
				var pairs: Array = instruction.operands[1].pairs
				if start_index + pairs.size() > 0x10000:
					trace.append(trace_record)
					return _result("invalid_write", false, cursor, trace, messages, state.diff(before), "Command 0x0A write run exceeds its safe addressable index range.")
				for pair_index in range(pairs.size()):
					var pair: Dictionary = pairs[pair_index]
					var evaluated := _evaluate_expression(pair.expression, state, expression_stack, trace_record, "value_%d" % pair_index)
					if not evaluated.ok:
						trace.append(trace_record)
						return _result("expression_error", false, cursor, trace, messages, state.diff(before), str(evaluated.error))
					state.write_value("global_i32", start_index + pair_index, int(evaluated.value))
				trace_record["effect"] = "global_i32_write_run"
				trace_record["write_start"] = start_index
				trace_record["write_count"] = pairs.size()
				trace_record["write_storage"] = "global_i32"
				trace_record["write_bank"] = 0
			0x05:
				var destination := _evaluate_expression(instruction.operands[0].value, state, expression_stack, trace_record, "destination")
				if not destination.ok:
					trace.append(trace_record)
					return _result("expression_error", false, cursor, trace, messages, state.diff(before), str(destination.error))
				var start_index := int(destination.value) & 0xFFFF
				var pairs: Array = instruction.operands.slice(1)
				for pair_index in range(pairs.size()):
					var pair: Dictionary = pairs[pair_index]
					var evaluated := _evaluate_expression(pair.expression, state, expression_stack, trace_record, "value_%d" % pair_index)
					if not evaluated.ok:
						trace.append(trace_record)
						return _result("expression_error", false, cursor, trace, messages, state.diff(before), str(evaluated.error))
					state.write_value("global_u8", (start_index + pair_index) & 0xFFFF, int(evaluated.value))
				trace_record["effect"] = "dynamic_global_u8_write_run"
				trace_record["write_start"] = start_index
				trace_record["write_count"] = pairs.size()
				trace_record["write_storage"] = "global_u8"
				trace_record["write_index_mask"] = 0xFFFF
			0x19, 0x1A:
				var is_push := int(instruction.command_id) == 0x19
				trace_record["effect"] = "internal_record_push" if is_push else "internal_record_pop"
				trace_record["internal_record_delta"] = 1 if is_push else -1
				trace_record["native_active_string_changed"] = not is_push
				trace_record["native_internal_string_resolved"] = false
				trace_record["state_scope"] = "native_script_manager_internal"
				trace_record["gameplay_sandbox_changed"] = false
			0x1B:
				var record_value := _evaluate_single_record(instruction, state, expression_stack, trace_record)
				if not record_value.ok:
					trace_record["effect"] = "unsupported_stop"
					trace.append(trace_record)
					return _result(
						"unsupported_opcode",
						false,
						cursor,
						trace,
						messages,
						state.diff(before),
						"Command 0x1B is outside the confirmed single-expression record envelope: %s" % str(record_value.error),
						0x1B
					)
				trace_record["effect"] = "internal_vector_clear"
				trace_record["internal_vector_selector"] = int(record_value.value)
				trace_record["record_value"] = int(record_value.value)
				active_definition_group = int(record_value.value)
				definition_groups[active_definition_group] = []
				if active_definition_group not in definition_group_order:
					definition_group_order.append(active_definition_group)
				trace_record["definition_group_cleared"] = active_definition_group
				trace_record["state_scope"] = "native_script_manager_internal"
				trace_record["gameplay_sandbox_changed"] = false
			0x10:
				var definition := _decode_bounded_def_definition(source, instruction, limit)
				if not definition.ok:
					trace_record["effect"] = "unsupported_stop"
					trace.append(trace_record)
					return _result(
						"unsupported_opcode",
						false,
						cursor,
						trace,
						messages,
						state.diff(before),
						"Command 0x10 is outside the bounded DEF definition envelope: %s" % definition.error,
						0x10
					)
				definitions.append(definition.record)
				if active_definition_group >= 0:
					var grouped_definitions: Array = definition_groups.get(active_definition_group, [])
					grouped_definitions.append(definition.record)
					definition_groups[active_definition_group] = grouped_definitions
				next_offset = int(definition.record.target_offset)
				trace_record["effect"] = "def_register_skip"
				trace_record["definition_id"] = int(definition.record.definition_id)
				trace_record["definition_target"] = next_offset
				if active_definition_group >= 0:
					trace_record["definition_group_selector"] = active_definition_group
			0x11:
				var definition_selector := _evaluate_single_record(instruction, state, expression_stack, trace_record)
				if definition_selector.ok:
					trace_record["definition_id"] = int(definition_selector.value)
					trace_record["selector_resolved"] = true
				else:
					trace_record["selector_resolved"] = false
					trace_record["selector_error"] = str(definition_selector.error)
				trace_record["effect"] = "definition_invoke_boundary"
				trace.append(trace_record)
				var definition_boundary := _result(
					"definition_invoke_boundary",
					false,
					cursor,
					trace,
					messages,
					state.diff(before),
					"Command 0x11 selects a registered native DEF body; invocation requires an explicit caller-provided registry.",
					0x11
				)
				definition_boundary["resume_offset"] = int(instruction.end_offset)
				definition_boundary["resume_policy"] = "registered_definition_call_restore"
				definition_boundary["argument_slots"] = argument_slots.duplicate(true)
				definition_boundary["persistent_expression_stack"] = expression_stack.duplicate()
				return definition_boundary
			0x13:
				if str(instruction.op) != "message_cursor_no_advance":
					trace_record["effect"] = "unsupported_stop"
					trace.append(trace_record)
					return _result(
						"unsupported_opcode",
						false,
						cursor,
						trace,
						messages,
						state.diff(before),
						"Command 0x13 operand form has no confirmed runner semantics.",
						0x13
					)
				trace_record["effect"] = "message_cursor_no_advance"
			0x14:
				var selector := _evaluate_expression(instruction.operands[0].value, state, expression_stack, trace_record, "selector")
				if not selector.ok:
					trace.append(trace_record)
					return _result("expression_error", false, cursor, trace, messages, state.diff(before), str(selector.error))
				next_offset = int(instruction.operands[1].value)
				trace_record["effect"] = "bootstrap_transfer"
				trace_record["bootstrap_selector"] = int(selector.value)
				trace_record["native_context_map_changed"] = true
				trace_record["state_scope"] = "native_script_manager_internal"
				trace_record["gameplay_sandbox_changed"] = false
			0x15:
				trace_record["effect"] = "native_selection_boundary"
				var selection_counts := _record_type_counts(instruction)
				trace_record["record_count"] = int(selection_counts.record_count)
				trace_record["string_record_count"] = int(selection_counts.string_record_count)
				trace_record["expression_record_count"] = int(selection_counts.expression_record_count)
				trace_record["gameplay_sandbox_changed"] = false
				trace.append(trace_record)
				return _result(
					"native_selection_boundary",
					false,
					cursor,
					trace,
					messages,
					state.diff(before),
					"Command 0x15 entered the native interactive selection loop; input and result effects are not simulated.",
					0x15
				)
			0x16:
				# Core 0.377.0 (TD-56): command 0x16 deliberately stays argument-slot
				# only. Its write site has not been audited with addresses (the
				# evidence covers command 0x09 and token 0xF6 only), so whether it
				# shares the `global_i32` storage is UNRESOLVED; nothing in the
				# corpus reads the index it writes.
				var start_slot := int(instruction.operands[0].value)
				var pairs: Array = instruction.operands.slice(1)
				if start_slot + pairs.size() > 0x100:
					trace.append(trace_record)
					return _result("invalid_write", false, cursor, trace, messages, state.diff(before), "Command 0x16 argument-slot run exceeds the u8 slot range.")
				var values: Array[int] = []
				for pair_index in range(pairs.size()):
					var pair: Dictionary = pairs[pair_index]
					var evaluated := _evaluate_expression(pair.expression, state, expression_stack, trace_record, "value_%d" % pair_index)
					if not evaluated.ok:
						trace.append(trace_record)
						return _result("expression_error", false, cursor, trace, messages, state.diff(before), str(evaluated.error))
					var value := int(evaluated.value)
					argument_slots[start_slot + pair_index] = value
					values.append(value)
				trace_record["effect"] = "argument_slot_write_run"
				trace_record["argument_slot_start"] = start_slot
				trace_record["argument_slot_count"] = pairs.size()
				trace_record["argument_values"] = values
			0x0E:
				if str(instruction.op) == "script_handoff_marker":
					trace_record["effect"] = "script_handoff_boundary"
					trace_record["target_entry"] = str(instruction.script_target)
					trace_record["native_active_string_changed"] = true
					trace_record["gameplay_sandbox_changed"] = false
					trace.append(trace_record)
					return _result(
						"script_handoff_boundary",
						false,
						cursor,
						trace,
						messages,
						state.diff(before),
						"Command 0x0E stored the MES target %s in the native active-string path; its host-side consumer is not simulated." % str(instruction.script_target),
						0x0E
					)
				elif str(instruction.op) == "literal_text_insert":
					var literal_record: Dictionary = instruction.operands[0].records[0]
					var literal_value: Dictionary = literal_record.value
					messages.append({
						"source_offset": int(literal_record.source_offset),
						"raw_bytes": literal_value.raw_bytes,
						"raw_hex": str(literal_value.raw_hex),
						"encoding": "cp932",
						"dynamic_kind": "literal_record",
					})
					trace_record["effect"] = "literal_text_insert"
					trace_record["record_byte_count"] = literal_value.raw_bytes.size()
					trace_record["next_offset"] = next_offset
					trace.append(trace_record)
					cursor = next_offset
					continue
				elif str(instruction.op) != "protagonist_name_insert":
					trace_record["effect"] = "unsupported_stop"
					trace.append(trace_record)
					return _result(
						"unsupported_opcode",
						false,
						cursor,
						trace,
						messages,
						state.diff(before),
						"Command 0x0E record form has no confirmed runner semantics.",
						0x0E
					)
				var protagonist_name := str(preview_context.get("protagonist_name", "")).strip_edges()
				var name_resolved := not protagonist_name.is_empty()
				if not name_resolved:
					protagonist_name = "〈主人公名〉"
				messages.append({
					"source_offset": int(instruction.source_offset),
					"dynamic_kind": "protagonist_name",
					"text": protagonist_name,
					"resolved": name_resolved,
					"encoding": "utf-8",
				})
				trace_record["effect"] = "protagonist_name_insert"
				trace_record["resolved"] = name_resolved
			0x0F:
				if str(instruction.op) != "script_dispatch":
					trace_record["effect"] = "unsupported_stop"
					trace.append(trace_record)
					return _result(
						"unsupported_opcode",
						false,
						cursor,
						trace,
						messages,
						state.diff(before),
						"Command 0x0F record form has no bounded script target.",
						0x0F
					)
				trace_record["effect"] = "script_dispatch_boundary"
				trace_record["target_entry"] = str(instruction.script_target)
				trace_record["gameplay_sandbox_changed"] = false
				trace.append(trace_record)
				var dispatch_result := _result(
					"script_dispatch_boundary",
					false,
					cursor,
					trace,
					messages,
					state.diff(before),
					"Command 0x0F dispatches %s in a nested native script context; target execution and caller restoration are not simulated." % str(instruction.script_target),
					0x0F
				)
				dispatch_result["resume_offset"] = int(instruction.end_offset)
				dispatch_result["argument_slots"] = argument_slots.duplicate(true)
				dispatch_result["persistent_expression_stack"] = expression_stack.duplicate()
				return dispatch_result
			0x01:
				if not _has_presentable_message_operand(instruction):
					var native_probe: Dictionary = instruction.get("native_stream_probe", {})
					trace_record["effect"] = "native_presentation_boundary"
					trace_record["native_stream_consumption"] = str(instruction.get("native_stream_consumption", ""))
					trace_record["native_stream_probe"] = native_probe.duplicate(true)
					trace_record["gameplay_sandbox_changed"] = false
					trace.append(trace_record)
					return _result(
						"native_presentation_boundary",
						false,
						cursor,
						trace,
						messages,
						state.diff(before),
						"Command 0x01 entered the native double-byte character-stream presentation handler without a bounded message operand; display and cursor effects are not simulated.",
						0x01
					)
				messages.append(_message_record(instruction))
				trace_record["effect"] = "message"
			0x03:
				var start_index := int(instruction.operands[0].value)
				var pairs: Array = instruction.operands[1].pairs
				if start_index + pairs.size() > 0x10000:
					trace.append(trace_record)
					return _result("invalid_write", false, cursor, trace, messages, state.diff(before), "Command 0x03 write run exceeds the u16 global index range.")
				for pair_index in range(pairs.size()):
					var pair: Dictionary = pairs[pair_index]
					var evaluated := _evaluate_expression(pair.expression, state, expression_stack, trace_record, "value_%d" % pair_index)
					if not evaluated.ok:
						trace.append(trace_record)
						return _result("expression_error", false, cursor, trace, messages, state.diff(before), str(evaluated.error))
					state.write_value("global_u8", start_index + pair_index, clampi(int(evaluated.value), 0, 15))
				trace_record["effect"] = "global_u8_write_run"
				trace_record["write_start"] = start_index
				trace_record["write_count"] = pairs.size()
				trace_record["write_storage"] = "global_u8"
				trace_record["write_bank"] = 0
			0x04:
				var start_index := int(instruction.operands[0].value)
				var pairs: Array = instruction.operands[1].pairs
				for pair_index in range(pairs.size()):
					var pair: Dictionary = pairs[pair_index]
					var evaluated := _evaluate_expression(pair.expression, state, expression_stack, trace_record, "value_%d" % pair_index)
					if not evaluated.ok:
						trace.append(trace_record)
						return _result("expression_error", false, cursor, trace, messages, state.diff(before), str(evaluated.error))
					state.write_value("state_u16", (start_index + pair_index) & 0xFF, int(evaluated.value))
				trace_record["effect"] = "state_u16_write_run"
				trace_record["write_start"] = start_index
				trace_record["write_count"] = pairs.size()
				trace_record["write_storage"] = "state_u16"
				trace_record["write_bank"] = 0
				trace_record["write_index_mask"] = 0xFF
				trace_record["write_wrapped"] = start_index + pairs.size() > 0x100
			0x06, 0x07, 0x08:
				var destination := _evaluate_expression(instruction.operands[0].value, state, expression_stack, trace_record, "destination")
				if not destination.ok:
					trace.append(trace_record)
					return _result("expression_error", false, cursor, trace, messages, state.diff(before), str(destination.error))
				var start_index := int(destination.value)
				var bank := int(instruction.operands[1].value)
				var pairs: Array = instruction.operands[2].pairs
				var storage: String = str({
					0x06: "banked_u8",
					0x07: "banked_u16",
					0x08: "banked_i32",
				}[int(instruction.command_id)])
				var maximum_index: int = int({
					"banked_u8": 0x7FFFFFFF,
					"banked_u16": 0x7FFFFFFF,
					"banked_i32": 0x3FFFFFFF,
				}[storage])
				if start_index < 0 or pairs.size() > maximum_index - start_index + 1:
					trace.append(trace_record)
					return _result("invalid_write", false, cursor, trace, messages, state.diff(before), "Command 0x%02X write run exceeds its safe addressable index range." % int(instruction.command_id))
				for pair_index in range(pairs.size()):
					var pair: Dictionary = pairs[pair_index]
					var evaluated := _evaluate_expression(pair.expression, state, expression_stack, trace_record, "value_%d" % pair_index)
					if not evaluated.ok:
						trace.append(trace_record)
						return _result("expression_error", false, cursor, trace, messages, state.diff(before), str(evaluated.error))
					state.write_value(storage, start_index + pair_index, int(evaluated.value), bank)
				trace_record["effect"] = str(instruction.op)
				trace_record["write_start"] = start_index
				trace_record["write_count"] = pairs.size()
				trace_record["write_storage"] = storage
				trace_record["write_bank"] = bank
			0x09:
				if str(instruction.op) == "argument_slot_write_run":
					var start_slot := int(instruction.operands[0].value)
					var pairs: Array = instruction.operands[1].pairs
					if start_slot + pairs.size() > 0x10000:
						trace.append(trace_record)
						return _result("invalid_write", false, cursor, trace, messages, state.diff(before), "Command 0x09 argument-slot run exceeds the u16 slot range.")
					var values: Array[int] = []
					for pair_index in range(pairs.size()):
						var pair: Dictionary = pairs[pair_index]
						var evaluated := _evaluate_expression(pair.expression, state, expression_stack, trace_record, "value_%d" % pair_index)
						if not evaluated.ok:
							trace.append(trace_record)
							return _result("expression_error", false, cursor, trace, messages, state.diff(before), str(evaluated.error))
						var value := int(evaluated.value)
						# Core 0.377.0 (TD-56): command 0x09 and token 0xF6 address one
						# original storage, `common_state + 0x3000 + index * 4`, so the
						# write lands in `global_i32` (docs/spec/mes/format_and_method.md).
						# `argument_slots` keeps only which indices this run wrote and
						# the value written, as provenance for traces, previews and
						# continuations; it is never read for meaning.
						state.write_value("global_i32", start_slot + pair_index, value)
						argument_slots[start_slot + pair_index] = value
						values.append(value)
					trace_record["argument_slot_start"] = start_slot
					trace_record["argument_slot_count"] = pairs.size()
					trace_record["argument_values"] = values
					trace_record["write_storage"] = "global_i32"
					trace_record["write_start"] = start_slot
					trace_record["write_count"] = pairs.size()
					trace_record["write_bank"] = 0
					if pairs.size() == 1:
						trace_record["effect"] = "argument_slot_assignment"
						trace_record["argument_slot"] = start_slot
						trace_record["argument_value"] = values[0]
					else:
						trace_record["effect"] = "argument_slot_write_run"
				elif str(instruction.op) == "mmo_resource_marker":
					_apply_mmo_marker(instruction, trace_record, state)
				else:
					trace_record["effect"] = "unsupported_stop"
					trace.append(trace_record)
					return _result(
						"unsupported_opcode",
						false,
						cursor,
						trace,
						messages,
						state.diff(before),
						"Opcode 0x09 form has no confirmed runner semantics.",
						0x09
					)
			0x1D:
				var routine := _literal_transfer_routine(instruction)
				trace_record["routine_id"] = routine
				trace_record["persistent_expression_stack_depth"] = expression_stack.size()
				trace_record["persistent_expression_stack"] = expression_stack.duplicate()
				# Core 0.377.0 (TD-56): the routine's argument 1 is read from the one
				# original storage (`global_i32[1]`, written by command 0x09 or 0x0A),
				# not from the provenance slots. The native storage always holds a
				# value, so there is no "slot 1 unwritten" gate. TOOL ASSUMPTION: a
				# sandbox that has not written index 1 reads the sandbox's 0; the
				# original's value before the first write is not established.
				if routine == 0:
					trace_record["effect"] = "message_record_id"
					trace_record["message_record_id"] = state.read_value("global_i32", 1)
				elif routine == 23:
					var selector := state.read_value("global_i32", 1)
					var resource_name := BgmCatalogScript.resolve_entry(selector)
					if resource_name.is_empty():
						trace_record["effect"] = "unsupported_stop"
						trace.append(trace_record)
						return _result(
							"unsupported_opcode",
							false,
							cursor,
							trace,
							messages,
							state.diff(before),
							"BGM routine 23 received an unmapped selector: %d." % selector,
							0x1D
						)
					trace_record["effect"] = "bgm_request"
					trace_record["resource_kind"] = "bgm"
					trace_record["resource_name"] = resource_name
					trace_record["bgm_selector"] = selector
				elif routine == 40 and not definitions.is_empty():
					var presented_definitions: Array = definitions
					var selection_group := -1
					var registered_definition_count := definitions.size()
					if not definition_groups.is_empty():
						registered_definition_count = 0
						for untyped_group_definitions in definition_groups.values():
							registered_definition_count += (untyped_group_definitions as Array).size()
					if definition_groups.has(0) and not (definition_groups[0] as Array).is_empty():
						presented_definitions = definition_groups[0]
						selection_group = 0
					trace_record["effect"] = "def_selection_boundary"
					trace_record["definition_count"] = presented_definitions.size()
					trace_record["registered_definition_count"] = registered_definition_count
					trace_record["observed_definition_count"] = definitions.size()
					trace_record["definition_group_count"] = definition_groups.size()
					trace_record["selection_definition_group"] = selection_group
					trace.append(trace_record)
					var definition_result := _result(
						"def_selection_boundary",
						true,
						cursor,
						trace,
						messages,
						state.diff(before)
					)
					definition_result["definitions"] = presented_definitions.duplicate(true)
					definition_result["definition_groups"] = definition_groups.duplicate(true)
					definition_result["definition_group_order"] = definition_group_order.duplicate()
					definition_result["selection_definition_group"] = selection_group
					definition_result["registered_definition_count"] = registered_definition_count
					definition_result["observed_definition_count"] = definitions.size()
					definition_result["argument_slots"] = argument_slots.duplicate(true)
					definition_result["persistent_expression_stack"] = expression_stack.duplicate()
					return definition_result
				elif routine >= 0:
					trace_record["effect"] = "shared_routine_boundary"
					trace_record["gameplay_sandbox_changed"] = false
					trace.append(trace_record)
					var shared_result := _result(
						"shared_routine_boundary",
						false,
						cursor,
						trace,
						messages,
						state.diff(before),
						"Shared routine %d requires its native library call frame; the body is not executed." % routine,
						0x1D
					)
					shared_result["argument_slots"] = argument_slots.duplicate(true)
					shared_result["persistent_expression_stack"] = expression_stack.duplicate()
					shared_result["resume_offset"] = int(instruction.end_offset)
					return shared_result
				else:
					trace_record["effect"] = "unsupported_stop"
					trace.append(trace_record)
					return _result(
						"unsupported_opcode",
						false,
						cursor,
						trace,
						messages,
						state.diff(before),
						"Script transfer has no resolvable literal shared-routine selector.",
						0x1D
					)
			0x0B:
				# EP-12 (2026-09-24, tool decision): a hop's own `poll_supplies`
				# names this exact branch record (a `branch_if_not_true` whose
				# condition reads one storage cell) and writes its own value into
				# that cell before the condition below evaluates - the same seam
				# `_supplied_map_location` uses for a command-0x12 Util(6,13) poll,
				# generalised to a plain equality branch inside a registered
				# definition's own wait loop (definition 17's `state_u16[18]`
				# poll, docs/spec/tech/a_date_flow.md). It does not touch the
				# native-record omission path above.
				var supplied_poll := _supplied_poll(preview_context, cursor)
				if not supplied_poll.is_empty():
					state.write_value(str(supplied_poll.storage), int(supplied_poll.index), int(supplied_poll.value))
					trace_record["poll_supplied"] = true
					trace_record["poll_supply_value"] = int(supplied_poll.value)
					trace_record["write_storage"] = str(supplied_poll.storage)
					trace_record["write_start"] = int(supplied_poll.index)
					trace_record["write_count"] = 1
					trace_record["write_bank"] = 0
				var condition: Dictionary = instruction.operands[0].value
				var evaluated := _evaluate_expression(condition, state, expression_stack, trace_record, "condition")
				if not evaluated.ok:
					trace.append(trace_record)
					return _result("expression_error", false, cursor, trace, messages, state.diff(before), str(evaluated.error))
				var condition_value := int(evaluated.value)
				trace_record["condition_value"] = condition_value
				if condition_value != 1:
					next_offset = int(instruction.operands[1].value)
					trace_record["effect"] = "branch"
				else:
					trace_record["effect"] = "fallthrough"
			0x0C:
				next_offset = int(instruction.operands[0].value)
				trace_record["effect"] = "continuation"
			_:
				if str(instruction.op) == "dispatcher_character_text" and _has_presentable_message_operand(instruction):
					messages.append(_message_record(instruction))
					trace_record["effect"] = "message"
				elif instruction.has("native_handler_family"):
					var native_skip_end := _native_skip_end(instruction, limit) if skip_bounded_native_streams else -1
					if native_skip_end > cursor:
						_configure_native_skip(trace_record, instruction, native_skip_end)
						next_offset = native_skip_end
					else:
						trace_record["effect"] = "native_presentation_boundary"
						trace_record["native_stream_consumption"] = str(instruction.get("native_stream_consumption", ""))
						trace_record["native_stream_probe"] = instruction.get("native_stream_probe", {}).duplicate(true)
						trace_record["gameplay_sandbox_changed"] = false
						trace.append(trace_record)
						return _result(
							"native_presentation_boundary",
							false,
							cursor,
							trace,
							messages,
							state.diff(before),
							_native_dispatch_boundary_message(instruction),
							int(instruction.command_id)
						)
				else:
					trace_record["effect"] = "unsupported_stop"
					trace.append(trace_record)
					return _result(
						"unsupported_opcode",
						false,
						cursor,
						trace,
						messages,
						state.diff(before),
						_native_dispatch_boundary_message(instruction),
						int(instruction.command_id)
					)
		trace_record["next_offset"] = next_offset
		trace.append(trace_record)
		if next_offset < 0 or next_offset > limit:
			return _result("invalid_target", false, cursor, trace, messages, state.diff(before), "Control-flow target 0x%X is outside the execution range." % next_offset)
		cursor = next_offset
	return _result("step_limit", false, cursor, trace, messages, state.diff(before), "Execution reached the step limit.")


func _native_skip_end(instruction: Dictionary, limit: int) -> int:
	var probe: Dictionary = instruction.get("native_stream_probe", {})
	if int(probe.get("consumed_byte_count", 0)) <= 0:
		return -1
	var probe_end := int(probe.get("probe_end_offset", -1))
	return probe_end if probe_end > int(instruction.source_offset) and probe_end <= limit else -1


func _configure_native_skip(trace_record: Dictionary, instruction: Dictionary, next_offset: int) -> void:
	trace_record["effect"] = "native_presentation_omitted"
	trace_record["native_stream_consumption"] = str(instruction.get("native_stream_consumption", ""))
	trace_record["native_stream_probe"] = instruction.get("native_stream_probe", {}).duplicate(true)
	trace_record["native_dispatch_next_offset"] = next_offset
	trace_record["gameplay_sandbox_changed"] = false


func _is_confirmed_dialogue_boundary(
	source: KakyuMesCodeSource,
	offset: int,
	limit: int,
	trace: Array[Dictionary],
	messages: Array[Dictionary]
) -> bool:
	if messages.is_empty() or trace.is_empty() or offset + 4 > limit:
		return false
	if str(trace[-1].get("effect", "")) != "message_cursor_no_advance":
		return false
	return source.is_dialogue_boundary_pattern(offset, limit)


func _literal_transfer_routine(instruction: Dictionary) -> int:
	return _literal_record_value(instruction)


func _record_type_counts(instruction: Dictionary) -> Dictionary:
	var result := {
		"record_count": 0,
		"string_record_count": 0,
		"expression_record_count": 0,
	}
	if instruction.operands.size() != 1:
		return result
	var records: Array = instruction.operands[0].get("records", [])
	result.record_count = records.size()
	for record in records:
		match str(record.get("type", "")):
			"string_record":
				result.string_record_count += 1
			"expression_record":
				result.expression_record_count += 1
	return result


func _literal_record_value(instruction: Dictionary) -> int:
	if instruction.operands.size() != 1:
		return -1
	var records: Array = instruction.operands[0].records
	if records.size() != 1 or str(records[0].get("type", "")) != "expression_record":
		return -1
	var ast: Dictionary = records[0].value.ast
	if str(ast.get("type", "")) != "literal":
		return -1
	return int(ast.get("value", -1))


func _evaluate_expression(
	expression: Dictionary,
	state: KakyuMesSandboxState,
	expression_stack: Array[int],
	trace_record: Dictionary,
	role: String
) -> Dictionary:
	var evaluated := _persistent_expression.evaluate_fragment(expression, state, expression_stack)
	if not evaluated.ok:
		return evaluated
	var steps: Array = trace_record.get("persistent_expression_steps", [])
	steps.append({
		"role": role,
		"local_depth": int(evaluated.local_depth),
		"stack_depth_before": int(evaluated.stack_depth_before),
		"stack_depth_after": int(evaluated.stack_depth_after),
		"used_empty_fallback": bool(evaluated.used_empty_fallback),
	})
	trace_record["persistent_expression_steps"] = steps
	trace_record["persistent_expression_stack_depth"] = int(evaluated.stack_depth_after)
	return evaluated


func _evaluate_single_record(
	instruction: Dictionary,
	state: KakyuMesSandboxState,
	expression_stack: Array[int],
	trace_record: Dictionary
) -> Dictionary:
	if instruction.operands.size() != 1:
		return {"ok": false, "error": "operand count differs"}
	var records: Array = instruction.operands[0].records
	if records.size() != 1 or str(records[0].get("type", "")) != "expression_record":
		return {"ok": false, "error": "selector is not one expression record"}
	var evaluated := _evaluate_expression(records[0].value, state, expression_stack, trace_record, "record")
	if not evaluated.ok:
		return {"ok": false, "error": str(evaluated.error)}
	return {"ok": true, "value": int(evaluated.value)}


func _decode_bounded_def_definition(
	source: KakyuMesCodeSource,
	instruction: Dictionary,
	limit: int
) -> Dictionary:
	if instruction.operands.size() != 2:
		return {"ok": false, "error": "operand count differs"}
	var records: Array = instruction.operands[0].records
	if records.size() != 1 or str(records[0].get("type", "")) != "expression_record":
		return {"ok": false, "error": "DEF selector is not one expression record"}
	var ast: Dictionary = records[0].value.ast
	if str(ast.get("type", "")) != "literal":
		return {"ok": false, "error": "DEF selector is not literal"}
	var target_bytes: Array = instruction.operands[1].value
	if target_bytes.size() != 4:
		return {"ok": false, "error": "target field is not four bytes"}
	var target := (
		int(target_bytes[0])
		| (int(target_bytes[1]) << 8)
		| (int(target_bytes[2]) << 16)
		| (int(target_bytes[3]) << 24)
	)
	var body_offset := int(instruction.end_offset)
	if target <= body_offset or target > limit:
		return {"ok": false, "error": "target 0x%X is not a forward in-range coordinate" % target}
	var projection := _project_definition_body(source, body_offset, target)
	if not projection.ok:
		return {"ok": false, "error": str(projection.error)}
	return {
		"ok": true,
		"record": {
			"definition_id": int(ast.value),
			"source_offset": int(instruction.source_offset),
			"body_offset": body_offset,
			"target_offset": target,
			"body_size": target - body_offset,
			"body_sha256": source.sha256_range(body_offset, target),
			"body_instruction_count": int(projection.instruction_count),
			"messages": projection.messages,
			"native_role": "def_registration_skip",
			"selection_semantics": "unresolved",
		},
	}


func _project_definition_body(
	source: KakyuMesCodeSource,
	body_offset: int,
	target: int
) -> Dictionary:
	var body_messages: Array[Dictionary] = []
	var cursor := body_offset
	var instruction_count := 0
	while cursor < target:
		var body_instruction := source.decode_at(cursor, target)
		if not body_instruction.ok:
			return {"ok": false, "error": "body decode stopped at 0x%X" % cursor}
		if (
			(int(body_instruction.command_id) == 0x01 or str(body_instruction.op) == "dispatcher_character_text")
			and _has_presentable_message_operand(body_instruction)
		):
			body_messages.append(_message_record(body_instruction))
		cursor = int(body_instruction.end_offset)
		instruction_count += 1
	return {
		"ok": cursor == target and instruction_count > 0,
		"error": "body does not end at its forward target" if cursor != target else "body is empty",
		"instruction_count": instruction_count,
		"messages": body_messages,
	}


# Trace evidence copied from a typed operand. A packaged operand carries only
# the fields that select playback; the analysis labels and native addresses the
# export drops are simply absent, and the trace says so by omission rather than
# by inventing a value.
func _copy_operand_field(
	record: Dictionary,
	operand: Dictionary,
	key: String,
	field: String
) -> void:
	if operand.has(field):
		record[key] = operand[field]


func _supplied_map_location(preview_context: Dictionary, cursor: int) -> Dictionary:
	# Contracts arrive as {poll_offset, result_storage, result_index, values};
	# `values` is consumed in place so a queue survives segment boundaries.
	for untyped_contract in preview_context.get("map_locations", []):
		var contract: Dictionary = untyped_contract
		if int(contract.get("poll_offset", -1)) != cursor:
			continue
		var values: Array = contract.get("values", [])
		if values.is_empty():
			return {}
		return {"value": int(values.pop_front()), "storage": str(contract.get("result_storage", "state_u16")),
			"index": int(contract.get("result_index", 18))}
	return {}


func _supplied_poll(preview_context: Dictionary, cursor: int) -> Dictionary:
	# Contracts arrive as {poll_offset, result_storage, result_index, value}: a
	# fixed value written every time this exact branch is reached (not a
	# consumed queue - a wait loop asks the same question every pass).
	for untyped_supply in preview_context.get("poll_supplies", []):
		var supply: Dictionary = untyped_supply
		if int(supply.get("poll_offset", -1)) != cursor:
			continue
		return {"value": int(supply.get("value", 0)), "storage": str(supply.get("result_storage", "state_u16")),
			"index": int(supply.get("result_index", 18))}
	return {}


func _trace_record(instruction: Dictionary, step: int) -> Dictionary:
	var record := {
		"step": step,
		"source_offset": int(instruction.source_offset),
		"end_offset": int(instruction.end_offset),
		"command_id": int(instruction.command_id),
		"op": str(instruction.op),
		"raw_hex": str(instruction.raw_hex),
	}
	if instruction.has("native_handler_family"):
		record["native_handler_family"] = str(instruction.native_handler_family)
	if instruction.get("structural_only", false):
		record["structural_only"] = true
	return record


func _native_dispatch_boundary_message(instruction: Dictionary) -> String:
	if str(instruction.get("native_handler_family", "")) == "double_byte_character_stream_presentation":
		return (
			"Opcode 0x%02X enters the native double-byte character-stream handler "
			+ "without a bounded message operand; its presentation effects are not simulated."
		) % int(instruction.command_id)
	if str(instruction.get("native_handler_family", "")) == "character_stream_presentation":
		return (
			"Opcode 0x%02X enters the native character-stream presentation handler; "
			+ "its display and cursor effects are not simulated."
		) % int(instruction.command_id)
	return "Opcode 0x%02X has no confirmed runner semantics." % int(instruction.command_id)


func _has_message_operand(instruction: Dictionary) -> bool:
	var operands: Array = instruction.get("operands", [])
	return operands.size() == 1 and str(operands[0].get("type", "")) == "cp932_bytes"


func _has_presentable_message_operand(instruction: Dictionary) -> bool:
	if not _has_message_operand(instruction):
		return false
	var raw_bytes: PackedByteArray = instruction.operands[0].raw_bytes
	return bool(_cp932.decode(raw_bytes).get("ok", false))


func _message_record(instruction: Dictionary) -> Dictionary:
	var operand: Dictionary = instruction.operands[0]
	return {
		"source_offset": int(instruction.source_offset),
		"raw_bytes": operand.raw_bytes,
		"raw_hex": str(operand.raw_hex),
		"encoding": "cp932",
	}


func _result(
	status: String,
	ok: bool,
	offset: int,
	trace: Array[Dictionary],
	messages: Array[Dictionary],
	state_diff: Array[Dictionary],
	error := "",
	command_id := -1
) -> Dictionary:
	var result := {
		"ok": ok,
		"schema": ContentCoreVersionScript.MES_EVENT_TRACE_SCHEMA,
		"status": status,
		"offset": offset,
		"trace": trace,
		"messages": messages,
		"state_diff": state_diff,
	}
	if not error.is_empty():
		result["error"] = error
	if command_id >= 0:
		result["command_id"] = command_id
	return result


func _system_call_literal_arguments(instruction: Dictionary) -> Array:
	# The literal arguments of a system call, or an empty array when any argument is not a literal.
	var values := []
	if instruction.operands.size() != 2:
		return values
	for record in instruction.operands[1].get("records", []):
		if str(record.get("type", "")) != "expression_record":
			return []
		var ast: Dictionary = record.value.get("ast", {})
		if str(ast.get("type", "")) != "literal":
			return []
		values.append(int(ast.get("value", -1)))
	return values


func _system_call_argument_count(instruction: Dictionary) -> int:
	if instruction.operands.size() != 2:
		return 0
	return (instruction.operands[1].get("records", []) as Array).size()


func _apply_text_insert(
	instruction: Dictionary,
	trace_record: Dictionary,
	messages: Array[Dictionary],
	preview_context: Dictionary
) -> void:
	# System function 14: the protagonist name, or one literal string, enters the message stream.
	if str(instruction.op) == "literal_text_insert":
		var literal_record: Dictionary = instruction.operands[0].records[0]
		var literal_value: Dictionary = literal_record.value
		messages.append({
			"source_offset": int(literal_record.source_offset),
			"raw_bytes": literal_value.raw_bytes,
			"raw_hex": str(literal_value.raw_hex),
			"encoding": "cp932",
			"dynamic_kind": "literal_record",
		})
		trace_record["effect"] = "literal_text_insert"
		trace_record["record_byte_count"] = literal_value.raw_bytes.size()
		return
	var protagonist_name := str(preview_context.get("protagonist_name", "")).strip_edges()
	var name_resolved := not protagonist_name.is_empty()
	if not name_resolved:
		protagonist_name = "〈主人公名〉"
	messages.append({
		"source_offset": int(instruction.source_offset),
		"dynamic_kind": "protagonist_name",
		"text": protagonist_name,
		"resolved": name_resolved,
		"encoding": "utf-8",
	})
	trace_record["effect"] = "protagonist_name_insert"
	trace_record["resolved"] = name_resolved


func _apply_mmo_marker(instruction: Dictionary, trace_record: Dictionary, state: KakyuMesSandboxState) -> void:
	# System function 9 with one .MMO name: the presentation-9 marker, effects omitted.
	var mmo_operand: Dictionary = instruction.operands[0]
	trace_record["effect"] = "mmo_resource_marker"
	trace_record["resource_kind"] = "mmo"
	_copy_operand_field(trace_record, mmo_operand, "resource_name", "name")
	_copy_operand_field(trace_record, mmo_operand, "outer_command", "outer_command")
	_copy_operand_field(trace_record, mmo_operand, "outer_command_source_offset", "outer_command_source_offset")
	_copy_operand_field(trace_record, mmo_operand, "presentation_subcommand", "presentation_subcommand")
	_copy_operand_field(trace_record, mmo_operand, "argument_count", "argument_count")
	_copy_operand_field(trace_record, mmo_operand, "native_adapter", "native_adapter")
	_copy_operand_field(trace_record, mmo_operand, "native_consumer", "native_consumer")
	_copy_operand_field(trace_record, mmo_operand, "native_surface_blit", "native_surface_blit")
	_copy_operand_field(trace_record, mmo_operand, "native_default_origin_arguments", "native_default_origin_arguments")
	_copy_operand_field(trace_record, mmo_operand, "native_active_surface_state_offset", "native_active_surface_state_offset")
	_copy_operand_field(trace_record, mmo_operand, "native_active_surface_storage", "native_active_surface_storage")
	_copy_operand_field(trace_record, mmo_operand, "native_active_surface_bank", "native_active_surface_bank")
	_copy_operand_field(trace_record, mmo_operand, "native_active_surface_storage_index", "native_active_surface_storage_index")
	if (
		mmo_operand.has("native_active_surface_storage")
		and mmo_operand.has("native_active_surface_storage_index")
		and mmo_operand.has("native_active_surface_bank")
	):
		trace_record["native_active_surface_value"] = state.read_value(
			str(mmo_operand.native_active_surface_storage),
			int(mmo_operand.native_active_surface_storage_index),
			int(mmo_operand.native_active_surface_bank)
		)
	_copy_operand_field(trace_record, mmo_operand, "native_playback_semantics", "native_playback_semantics")
	_copy_operand_field(trace_record, mmo_operand, "native_active_surface_identity", "native_active_surface_identity")
	_copy_operand_field(trace_record, mmo_operand, "tool_preview_semantics", "tool_preview_semantics")
