extends "res://tests/test_case.gd"

const LibraryIndexScript := preload("res://content_core/mes_library_index.gd")
const LibraryAuditScript := preload("res://content_core/mes_library_audit.gd")
const SyntheticArc := preload("res://tests/synthetic_arc.gd")


func _ready() -> void:
	var code := PackedByteArray()
	SyntheticArc.append_registration(code, 0, PackedByteArray([
		0x04, 0x92, 2, 0xF6, 1, 0, 0xFF, 0,
		0x12,
		0x00,
		0x03, 0, 0, 1, 0xFF, 0,
		0x00,
	]))
	SyntheticArc.append_registration(code, 28, PackedByteArray([0x0A, 0xFF, 1, 2, 0xFF, 0, 0x00]))
	var definition_body_offset := code.size() + 7
	var definition_body := PackedByteArray([
		0x14, 0x0B, 0xFF, 0, 0, 0, 0,
		0x00,
		0x11, 0x02, 0x0B, 0xFF, 0x00,
		0x00,
	])
	definition_body.encode_u32(3, definition_body_offset + 8)
	SyntheticArc.append_registration(code, 25, definition_body)
	var control_flow_body_offset := code.size() + 7
	var control_flow_body := PackedByteArray([0x0C, 0, 0, 0, 0, 0x00, 0x00])
	control_flow_body.encode_u32(1, control_flow_body_offset + 6)
	SyntheticArc.append_registration(code, 41, control_flow_body)
	var branch_body_offset := code.size() + 7
	var branch_body := PackedByteArray([0x0B, 0x01, 0xFF, 0, 0, 0, 0, 0x00])
	branch_body.encode_u32(3, branch_body_offset + 7)
	SyntheticArc.append_registration(code, 42, branch_body)
	SyntheticArc.append_registration(code, 43, PackedByteArray([0x04, 21, 0x80, 18, 0xFF, 0, 0x00]))
	var surface_body := PackedByteArray([0x0D, 0x0B, 0xFF])
	for value in [2, 3, 4, 7, 9]:
		surface_body.append_array(PackedByteArray([0x02, value, 0xFF]))
	surface_body.append_array(PackedByteArray([0x00, 0x00]))
	SyntheticArc.append_registration(code, 44, surface_body)
	code.append(0x00)
	var index := LibraryIndexScript.new().build(code)
	_check(index.ok, "synthetic shared library indexes before audit")
	var report := LibraryAuditScript.new().audit(code, index, [0, 28, 25, 41, 42, 43, 44])
	_check(report.ok and report.schema == "kakyu_mes_library_audit/v17", "library audit uses a versioned Content Core record")
	if report.ok:
		var split_routine: Dictionary = report.routines[0]
		_check(
			split_routine.linear_stack_effect_scope == "structural_instruction_order_not_cfg_path"
			and split_routine.return_delimited_segments.size() == 1
			and split_routine.return_delimited_segments[0].ends_in_return
			and split_routine.return_delimited_segments[0].stack_effect.net_delta == 1
			and split_routine.return_delimited_segments[0].instruction_count == 4,
			"library audit does not split a segment at the record-list terminator inside command 0x12"
		)
		_check(
			split_routine.native_stream_scope == "dispatch_token_probe_resolved_execution_path_unresolved"
			and split_routine.native_stream_boundaries.is_empty()
			and split_routine.native_record_scope == "typed_record_extent_confirmed_dispatch_effects_not_executed"
			and split_routine.native_record_boundaries.size() == 1
			and split_routine.native_record_boundaries[0].source_offset == split_routine.body_offset + 8
			and split_routine.native_record_boundaries[0].payload_start_offset == split_routine.body_offset + 9
			and split_routine.native_record_boundaries[0].end_offset == split_routine.body_offset + 10
			and split_routine.native_record_boundaries[0].record_count == 0
			and split_routine.native_record_boundaries[0].terminator_consumed,
			"library audit records the complete typed-record boundary separately from character streams"
		)
		_check(
			split_routine.native_dispatch_flow.complete
			and split_routine.native_dispatch_flow.instruction_count == 4
			and split_routine.native_dispatch_flow.native_spans.size() == 1
			and split_routine.native_dispatch_flow.native_spans[0].source_offset == split_routine.body_offset + 8
			and split_routine.native_dispatch_flow.native_spans[0].payload_start_offset == split_routine.body_offset + 9
			and split_routine.native_dispatch_flow.native_spans[0].payload_end_offset == split_routine.body_offset + 10
			and split_routine.native_dispatch_flow.native_spans[0].end_offset == split_routine.body_offset + 10
			and split_routine.native_dispatch_flow.native_spans[0].payload_byte_count == 1
			and split_routine.native_dispatch_flow.native_spans[0].record_count == 0
			and split_routine.native_dispatch_flow.native_spans[0].consumption_kind == "typed_record_list_until_zero"
			and split_routine.native_dispatch_flow.native_spans[0].terminator_consumed
			and not (split_routine.body_offset + 9) in split_routine.native_dispatch_flow.instructions.map(func(row: Dictionary) -> int: return int(row.source_offset))
			and split_routine.native_dispatch_flow.return_offsets == [split_routine.body_offset + 16],
			"native dispatch flow retains the complete record-list span and the next real command boundary"
		)
		var shadowed_rows: Array = split_routine.native_dispatch_flow.shadowed_structural_instructions
		_check(
			shadowed_rows.is_empty(),
			"record payload bytes are not misreported as stored-order MES instructions"
		)
		var control_flow_routine: Dictionary = report.routines[3]
		var control_flow_unreached: Array = control_flow_routine.native_dispatch_flow.unreached_structural_instructions
		_check(
			control_flow_routine.native_dispatch_flow.instruction_count == 2
			and control_flow_unreached.size() == 1
			and int(control_flow_unreached[0].source_offset) == int(control_flow_routine.body_offset) + 5
			and str(control_flow_unreached[0].reason) == "control_flow_not_reached"
			and (control_flow_routine.native_dispatch_flow.shadowed_structural_instructions as Array).is_empty(),
			"library audit distinguishes control-flow-unreached stored rows from native payload rows"
		)
		var branch_routine: Dictionary = report.routines[4]
		var branch_row: Dictionary = branch_routine.native_dispatch_flow.instructions[0]
		_check(
			int(branch_row.command_id) == 0x0B
			and int(branch_row.branch_target) == int(branch_routine.body_offset) + 7
			and str(branch_row.condition_ast.type) == "literal"
			and int(branch_row.condition_ast.value) == 1,
			"native dispatch audit retains branch-condition ASTs without choosing an edge"
		)
		var write_routine: Dictionary = report.routines[5]
		var write_row: Dictionary = write_routine.native_dispatch_flow.instructions[0]
		_check(
			str(write_row.write_storage) == "state_u16"
			and int(write_row.write_start) == 21
			and int(write_row.write_count) == 1
			and (write_row.write_expressions as Array).size() == 1
			and str(write_row.write_expressions[0].ast.type) == "state_ref"
			and str(write_row.write_expressions[0].ast.storage) == "state_u16"
			and int(write_row.write_expressions[0].ast.index.value) == 18,
			"native dispatch audit retains state-u16 write expressions without evaluating them"
		)
		var surface_routine: Dictionary = report.routines[6]
		var surface_row: Dictionary = surface_routine.instructions[0]
		_check(
			str(surface_row.op) == "surface_operation"
			and str(surface_row.native_stream_consumption) == "typed_presentation_subcommand_11_record_list"
			and not surface_row.has("native_stream_probe")
			and surface_routine.native_stream_boundaries.is_empty(),
			"library audit retains exact surface-operation consumption without inventing a character-stream probe"
		)
		var routine: Dictionary = report.routines[1]
		_check(not routine.strict.complete and routine.strict.decoded_end_offset == routine.body_offset, "strict audit stops before a carried-stack expression")
		_check(routine.structural.complete and routine.structural.instruction_count == 2, "structural audit reaches the registered routine end")
		_check(
			routine.linear_stack_effect.minimum_incoming == 1
			and routine.linear_stack_effect.net_delta == 0
			and routine.instructions[0].structural_only,
			"routine audit reports the linear persistent-stack requirement without executing it"
		)
		_check(
			routine.native_dispatch_flow.complete
			and routine.native_dispatch_flow.instruction_count == 2
			and routine.native_dispatch_flow.instructions[0].write_storage == "global_i32"
			and routine.native_dispatch_flow.return_offsets == [routine.end_offset - 1],
			"native dispatch flow retains carried-stack commands as coordinates without evaluating them"
		)
		var definition_routine: Dictionary = report.routines[2]
		var definition_flow: Dictionary = definition_routine.native_dispatch_flow
		_check(
			definition_flow.definition_link_scope == "command14_context_map_coordinates_without_registration_dominance_or_lifetime"
			and definition_flow.definition_registrations.size() == 1
			and definition_flow.definition_registrations[0].definition_id == 11
			and definition_flow.definition_invocations.size() == 1
			and definition_flow.definition_invocations[0].definition_id == 11
			and definition_flow.definition_invocations[0].matching_registration_offsets == [definition_routine.body_offset],
			"native dispatch flow links matching DEF coordinates without claiming runtime registration lifetime"
		)
	_check(not LibraryAuditScript.new().audit(code, index, [99]).ok, "audit rejects an unregistered routine ID")
	_check(not LibraryAuditScript.new().audit(code, index, [28, 28]).ok, "audit rejects duplicate routine requests")
	await get_tree().process_frame
	get_tree().quit(1 if _failed else 0)
