extends SceneTree

const ArcReaderScript := preload("res://content_core/arc_reader.gd")
const MesContainerScript := preload("res://content_core/mes_container.gd")
const MesStartupContextScript := preload("res://content_core/mes_startup_context.gd")
const MesInstructionDecoderScript := preload("res://content_core/mes_instruction_decoder.gd")
const RegisteredDefinitionRunnerScript := preload("res://content_core/mes_registered_definition_runner.gd")
const SandboxStateScript := preload("res://content_core/mes_sandbox_state.gd")

const SCHEMA := "kakyu_mes_startup_definition_calls_audit/v3"
const ARCHIVE_SHA256 := "31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6"
const DEFINITION_ENTRY := "DEF_MAIN.MES"
const DEFINITION_ENTRY_SHA256 := "f2012ce5d90f60a5d1ca8190e03571341c0384c2d3d96e9aec2b3ab949db0ef0"
const EXPECTED_ENTRY_COUNT := 1015
const EXPECTED_COMPOSED_ENTRY_COUNT := 103
const EXPECTED_CALL_COUNT := 201
const EXPECTED_SELECTOR_COUNTS := {11: 91, 12: 91, 22: 7, 23: 12}
const EXPECTED_STATUS_COUNTS := {
	"registered_definition_shared_routine_boundary": 7,
	"registered_definition_step_limit": 91,
	"shared_routine_boundary": 5,
}
const EXPECTED_BODY_TRACE_COUNTS := {11: 1092, 12: 176845, 22: 28, 23: 156}
const EXPECTED_NESTED_DEFINITION_BOUNDARIES := {"11@0x48F>12": 91}
const EXPECTED_BODY_SHARED_ROUTINE_BOUNDARIES := {"22@0x1163>3": 7}
const EXPECTED_ROOT_SHARED_ROUTINE_BOUNDARIES := {28: 5}
const EXPECTED_TRACE_DEPTH_COUNTS := {0: 4725, 1: 1276, 2: 176845}
const EXPECTED_TERMINAL_TRACE_COUNTS := {
	"registered_definition_shared_routine_boundary:d1:def22@0x1163:shared_routine_boundary": 7,
	"registered_definition_step_limit:d2:def12@0x4DC:fallthrough": 51,
	"registered_definition_step_limit:d2:def12@0x4E8:state_u16_write_run": 14,
	"registered_definition_step_limit:d2:def12@0x4F0:continuation": 26,
	"shared_routine_boundary:d0:def-1@0x1DE:shared_routine_boundary": 1,
	"shared_routine_boundary:d0:def-1@0x203:shared_routine_boundary": 1,
	"shared_routine_boundary:d0:def-1@0xBBF:shared_routine_boundary": 1,
	"shared_routine_boundary:d0:def-1@0xEB:shared_routine_boundary": 2,
}
# Core 0.377.0 (TD-56): command 0x09 writes global_i32, so 13 of the audited
# composed runs now end with that cell changed (their command-0x09 argument
# assignments); the global_u8 and state_u16 counts, every row count and every
# terminal are unchanged.
const EXPECTED_STATE_DIFF_STORAGE_COUNTS := {"global_i32": 13, "global_u8": 91, "state_u16": 352}
const EXPECTED_DEF12_COORDINATE_COUNTS := {
	"0x4A1:source_line_marker": 91,
	"0x4A6:state_u16_write_run": 91,
	"0x4AC:branch": 91,
	"0x4C2:state_u16_write_run": 91,
	"0x4D2:source_line_marker": 91,
	"0x4D7:state_u16_write_run": 91,
	"0x4DC:fallthrough": 58805,
	"0x4E8:state_u16_write_run": 58754,
	"0x4F0:continuation": 58740,
}
const EXPECTED_DEF12_TRANSITION_COUNTS := {
	"0x4A1>0x4A6": 91,
	"0x4A6>0x4AC": 91,
	"0x4AC>0x4C2": 91,
	"0x4C2>0x4D2": 91,
	"0x4D2>0x4D7": 91,
	"0x4D7>0x4DC": 91,
	"0x4DC>0x4E8": 58754,
	"0x4E8>0x4F0": 58740,
	"0x4F0>0x4DC": 58714,
}
const EXPECTED_DEF12_WRITE_COUNTS := {
	"state_u16[0:10]+1": 91,
	"state_u16[0:1]+1": 58845,
	"state_u16[0:25]+1": 91,
}
const EXPECTED_DEF12_CONDITION_COUNTS := {
	"0x4AC=0:branch": 91,
	"0x4DC=1:fallthrough": 58805,
}
const EXPECTED_DEF12_FINAL_STATE_COUNTS := {
	"state1=637/state10=0/state25=65504": 1,
	"state1=640/state10=0/state25=65504": 1,
	"state1=643/state10=0/state25=65504": 3,
	"state1=644/state10=0/state25=65504": 6,
	"state1=645/state10=0/state25=65504": 43,
	"state1=646/state10=0/state25=65504": 15,
	"state1=647/state10=0/state25=65504": 4,
	"state1=648/state10=0/state25=65504": 15,
	"state1=649/state10=0/state25=65504": 1,
	"state1=651/state10=0/state25=65504": 2,
}


func _init() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() != 1:
		push_error("Usage: audit_mes_startup_definition_calls.gd <mes.arc>")
		quit(2)
		return
	var reader := ArcReaderScript.new()
	if not reader.open(arguments[0]):
		_fail(reader, reader.last_error)
		return
	var archive_before := reader.get_archive_fingerprint()
	var definition_before := reader.get_entry_fingerprint(DEFINITION_ENTRY)
	if archive_before != ARCHIVE_SHA256 or definition_before != DEFINITION_ENTRY_SHA256:
		_fail(reader, "Startup definition-call source hashes do not match the audited original set.")
		return
	var parser := MesContainerScript.new()
	var definition_document := parser.parse(
		reader.read_entry(DEFINITION_ENTRY),
		{"archive": "mes.arc", "entry": DEFINITION_ENTRY}
	)
	if not definition_document.get("ok", false):
		_fail(reader, str(definition_document.get("error", "DEF_MAIN.MES parse failed.")))
		return
	var startup_context := MesStartupContextScript.new().build(definition_document)
	if not startup_context.get("ok", false):
		_fail(reader, "Startup context projection failed: %s" % str(startup_context.get("error", "unknown error")))
		return
	var def12_loop_shape_matches := _matches_def12_host_scan_loop(definition_document)
	var definitions: Dictionary = startup_context.get("registered_definitions", {})
	var entry_count := 0
	var composed_entry_count := 0
	var call_count := 0
	var selector_counts := {}
	var status_counts := {}
	var body_trace_counts := {}
	var omitted_counts := {}
	var nested_definition_boundaries := {}
	var body_shared_routine_boundaries := {}
	var root_shared_routine_boundaries := {}
	var trace_depth_counts := {}
	var terminal_trace_counts := {}
	var def12_coordinate_counts := {}
	var def12_transition_counts := {}
	var def12_write_counts := {}
	var def12_condition_counts := {}
	var def12_final_state_counts := {}
	var state_diff_storage_counts := {}
	var message_count := 0
	var fatal_failures: Array[String] = []
	for entry in reader.get_entries():
		if str(entry.name).get_extension().to_lower() != "mes":
			continue
		var document := parser.parse(
			reader.read_entry(str(entry.name)),
			{"archive": "mes.arc", "entry": str(entry.name)}
		)
		if not document.get("ok", false):
			fatal_failures.append("%s container parse failed" % str(entry.name))
			continue
		entry_count += 1
		var entries: Array = document.get("entries", [])
		if entries.is_empty():
			continue
		var address_table_offsets: Array[int] = []
		for untyped_offset in document.get("header", {}).get("entry_offsets", []):
			address_table_offsets.append(int(untyped_offset))
		var state := SandboxStateScript.new(1)
		var result := RegisteredDefinitionRunnerScript.new().run(
			document.bytecode,
			int(entries[0].offset),
			state,
			int(document.header.code_size),
			{
				"registered_definitions": definitions,
				"registered_definition_native_stream_policy": "skip_bounded",
				"address_table_offsets": address_table_offsets,
			},
			2000,
			16
		)
		var calls: Array = result.get("registered_definition_calls", [])
		if calls.is_empty():
			continue
		composed_entry_count += 1
		call_count += calls.size()
		_inc(status_counts, str(result.get("status", "unknown")))
		message_count += result.get("messages", []).size()
		for call in calls:
			var selector := int(call.get("definition_id", -1))
			_inc(selector_counts, selector)
		var previous_def12_coordinate := -1
		for record in result.get("trace", []):
			var call_depth := int(record.get("registered_definition_call_depth", 0))
			_inc(trace_depth_counts, call_depth)
			if call_depth == 0:
				if str(record.get("effect", "")) == "shared_routine_boundary":
					_inc(root_shared_routine_boundaries, int(record.get("routine_id", -1)))
				continue
			var selector := int(record.get("external_definition_id", -1))
			_inc(body_trace_counts, selector)
			if selector == 12:
				var coordinate := int(record.get("source_offset", -1))
				_inc(def12_coordinate_counts, "0x%X:%s" % [coordinate, str(record.get("effect", "unknown"))])
				if previous_def12_coordinate >= 0:
					_inc(def12_transition_counts, "0x%X>0x%X" % [previous_def12_coordinate, coordinate])
				previous_def12_coordinate = coordinate
				if record.has("write_storage"):
					_inc(
						def12_write_counts,
						"%s[%d:%d]+%d" % [
							str(record.get("write_storage", "unknown")),
							int(record.get("write_bank", 0)),
							int(record.get("write_start", -1)),
							int(record.get("write_count", 0)),
						]
					)
				if record.has("condition_value"):
					_inc(
						def12_condition_counts,
						"0x%X=%d:%s" % [
							coordinate,
							int(record.condition_value),
							str(record.get("effect", "unknown")),
						]
					)
			if str(record.get("effect", "")) == "native_presentation_omitted":
				_inc(omitted_counts, selector)
			elif str(record.get("effect", "")) == "definition_invoke_boundary":
				_inc(nested_definition_boundaries, "%d@0x%X>%d" % [selector, int(record.get("source_offset", -1)), int(record.get("definition_id", -1))])
			elif str(record.get("effect", "")) == "shared_routine_boundary":
				_inc(body_shared_routine_boundaries, "%d@0x%X>%d" % [selector, int(record.get("source_offset", -1)), int(record.get("routine_id", -1))])
		var result_trace: Array = result.get("trace", [])
		if not result_trace.is_empty():
			var terminal: Dictionary = result_trace[-1]
			_inc(
				terminal_trace_counts,
				"%s:d%d:def%d@0x%X:%s" % [
					str(result.get("status", "unknown")),
					int(terminal.get("registered_definition_call_depth", 0)),
					int(terminal.get("external_definition_id", -1)),
					int(terminal.get("source_offset", -1)),
					str(terminal.get("effect", "unknown")),
				]
			)
		for difference in result.get("state_diff", []):
			_inc(state_diff_storage_counts, str(difference.get("storage", "unknown")))
		if calls.any(func(call: Dictionary) -> bool: return int(call.get("definition_id", -1)) == 12):
			_inc(
				def12_final_state_counts,
				"state1=%d/state10=%d/state25=%d" % [
					state.read_value("state_u16", 1),
					state.read_value("state_u16", 10),
					state.read_value("state_u16", 25),
				]
			)
	var archive_after := reader.get_archive_fingerprint()
	var definition_after := reader.get_entry_fingerprint(DEFINITION_ENTRY)
	reader.close()
	if (
		str(startup_context.get("schema", "")) != "kakyu_mes_startup_context/v2"
		or int(startup_context.get("registration_count", 0)) != 14
		or entry_count != EXPECTED_ENTRY_COUNT
		or composed_entry_count != EXPECTED_COMPOSED_ENTRY_COUNT
		or call_count != EXPECTED_CALL_COUNT
		or selector_counts != EXPECTED_SELECTOR_COUNTS
		or status_counts != EXPECTED_STATUS_COUNTS
		or body_trace_counts != EXPECTED_BODY_TRACE_COUNTS
		or not omitted_counts.is_empty()
		or nested_definition_boundaries != EXPECTED_NESTED_DEFINITION_BOUNDARIES
		or body_shared_routine_boundaries != EXPECTED_BODY_SHARED_ROUTINE_BOUNDARIES
		or root_shared_routine_boundaries != EXPECTED_ROOT_SHARED_ROUTINE_BOUNDARIES
		or trace_depth_counts != EXPECTED_TRACE_DEPTH_COUNTS
		or terminal_trace_counts != EXPECTED_TERMINAL_TRACE_COUNTS
		or message_count != 0
		or state_diff_storage_counts != EXPECTED_STATE_DIFF_STORAGE_COUNTS
		or not def12_loop_shape_matches
		or def12_coordinate_counts != EXPECTED_DEF12_COORDINATE_COUNTS
		or def12_transition_counts != EXPECTED_DEF12_TRANSITION_COUNTS
		or def12_write_counts != EXPECTED_DEF12_WRITE_COUNTS
		or def12_condition_counts != EXPECTED_DEF12_CONDITION_COUNTS
		or def12_final_state_counts != EXPECTED_DEF12_FINAL_STATE_COUNTS
	):
		fatal_failures.append(
			"Startup definition-call composition changed from the audited original contract: entries=%d calls=%d selectors=%s statuses=%s body_rows=%s nested=%s body_shared=%s root_shared=%s depths=%s terminals=%s messages=%d diffs=%s def12_coordinates=%s def12_transitions=%s def12_writes=%s def12_conditions=%s def12_final=%s"
			% [
				composed_entry_count,
				call_count,
				_format_counts(selector_counts),
				_format_counts(status_counts),
				_format_counts(body_trace_counts),
				_format_counts(nested_definition_boundaries),
				_format_counts(body_shared_routine_boundaries),
				_format_counts(root_shared_routine_boundaries),
				_format_counts(trace_depth_counts),
				_format_counts(terminal_trace_counts),
				message_count,
				_format_counts(state_diff_storage_counts),
				_format_counts(def12_coordinate_counts),
				_format_counts(def12_transition_counts),
				_format_counts(def12_write_counts),
				_format_counts(def12_condition_counts),
				_format_counts(def12_final_state_counts),
			]
		)
	if archive_after != archive_before or definition_after != definition_before:
		fatal_failures.append("Original mes.arc changed during startup definition-call audit.")
	if not fatal_failures.is_empty():
		for failure in fatal_failures:
			push_error(failure)
		quit(1)
		return
	print(
		"MES_STARTUP_DEFINITION_CALLS schema=%s entries=%d composed_entries=%d calls=%d selectors=%s statuses=%s body_rows=%s omitted=%s nested_defs=%s body_shared=%s root_shared=%s depths=%s terminals=%s messages=%d state_diff_storages=%s def12_coordinates=%s def12_transitions=%s def12_writes=%s def12_conditions=%s def12_final=%s def12_dependency=banked_u8[25][state_u16[1]]_sentinel_15 source_unchanged=true"
		% [
			SCHEMA,
			entry_count,
			composed_entry_count,
			call_count,
			_format_counts(selector_counts),
			_format_counts(status_counts),
			_format_counts(body_trace_counts),
			_format_counts(omitted_counts),
			_format_counts(nested_definition_boundaries),
			_format_counts(body_shared_routine_boundaries),
			_format_counts(root_shared_routine_boundaries),
			_format_counts(trace_depth_counts),
			_format_counts(terminal_trace_counts),
			message_count,
			_format_counts(state_diff_storage_counts),
			_format_counts(def12_coordinate_counts),
			_format_counts(def12_transition_counts),
			_format_counts(def12_write_counts),
			_format_counts(def12_condition_counts),
			_format_counts(def12_final_state_counts),
		]
	)
	quit(0)


func _matches_def12_host_scan_loop(document: Dictionary) -> bool:
	var decoder := MesInstructionDecoderScript.new()
	var code: PackedByteArray = document.get("bytecode", PackedByteArray())
	var limit := int(document.get("header", {}).get("code_size", 0))
	var write_10: Dictionary = decoder.decode_at_structural(code, 0x04A6, limit)
	var branch_limit: Dictionary = decoder.decode_at_structural(code, 0x04AC, limit)
	var write_25: Dictionary = decoder.decode_at_structural(code, 0x04C2, limit)
	var write_cursor: Dictionary = decoder.decode_at_structural(code, 0x04D7, limit)
	var branch_sentinel: Dictionary = decoder.decode_at_structural(code, 0x04DC, limit)
	var increment_cursor: Dictionary = decoder.decode_at_structural(code, 0x04E8, limit)
	var loop_back: Dictionary = decoder.decode_at_structural(code, 0x04F0, limit)
	for instruction in [write_10, branch_limit, write_25, write_cursor, branch_sentinel, increment_cursor, loop_back]:
		if not instruction.get("ok", false):
			return false
	var limit_condition := _condition_ast(branch_limit)
	var sentinel_condition := _condition_ast(branch_sentinel)
	var position_ast := _write_ast(write_25)
	var position_rhs: Dictionary = position_ast.get("rhs", {})
	var scaled_index: Dictionary = position_rhs.get("lhs", {})
	var row_minus_one: Dictionary = scaled_index.get("lhs", {})
	return (
		int(write_10.command_id) == 0x04
		and int(write_10.operands[0].value) == 10
		and _is_state_ref(_write_ast(write_10), "state_u16", 0, 7)
		and int(branch_limit.command_id) == 0x0B
		and int(branch_limit.operands[1].value) == 0x04C2
		and str(limit_condition.get("type", "")) == "binary"
		and str(limit_condition.get("op", "")) == "greater_than"
		and _is_state_ref(limit_condition.get("lhs", {}), "state_u16", 0, 10)
		and _is_literal(limit_condition.get("rhs", {}), 1299)
		and int(write_25.command_id) == 0x04
		and int(write_25.operands[0].value) == 25
		and str(position_ast.get("type", "")) == "binary"
		and str(position_ast.get("op", "")) == "add"
		and _is_state_ref(position_ast.get("lhs", {}), "banked_u16", 0, 0)
		and str(position_rhs.get("type", "")) == "binary"
		and str(position_rhs.get("op", "")) == "multiply"
		and _is_literal(position_rhs.get("rhs", {}), 32)
		and str(scaled_index.get("type", "")) == "binary"
		and str(scaled_index.get("op", "")) == "subtract"
		and _is_literal(scaled_index.get("rhs", {}), 1)
		and str(row_minus_one.get("type", "")) == "binary"
		and str(row_minus_one.get("op", "")) == "divide_unsigned"
		and _is_state_ref(row_minus_one.get("lhs", {}), "state_u16", 0, 10)
		and _is_literal(row_minus_one.get("rhs", {}), 100)
		and int(write_cursor.command_id) == 0x04
		and int(write_cursor.operands[0].value) == 1
		and _is_literal(_write_ast(write_cursor), 0)
		and int(branch_sentinel.command_id) == 0x0B
		and int(branch_sentinel.operands[1].value) == 0x04F5
		and str(sentinel_condition.get("type", "")) == "binary"
		and str(sentinel_condition.get("op", "")) == "not_equal"
		and _is_dynamic_banked_u8_cursor(sentinel_condition.get("lhs", {}))
		and _is_literal(sentinel_condition.get("rhs", {}), 15)
		and int(increment_cursor.command_id) == 0x04
		and int(increment_cursor.operands[0].value) == 1
		and str(_write_ast(increment_cursor).get("type", "")) == "binary"
		and str(_write_ast(increment_cursor).get("op", "")) == "add"
		and _is_state_ref(_write_ast(increment_cursor).get("lhs", {}), "state_u16", 0, 1)
		and _is_literal(_write_ast(increment_cursor).get("rhs", {}), 1)
		and int(loop_back.command_id) == 0x0C
		and int(loop_back.operands[0].value) == 0x04DC
	)


func _condition_ast(instruction: Dictionary) -> Dictionary:
	var operands: Array = instruction.get("operands", [])
	return operands[0].get("value", {}).get("ast", {}) if operands.size() >= 1 else {}


func _write_ast(instruction: Dictionary) -> Dictionary:
	var operands: Array = instruction.get("operands", [])
	if operands.size() < 2:
		return {}
	var pairs: Array = operands[1].get("pairs", [])
	return pairs[0].get("expression", {}).get("ast", {}) if pairs.size() == 1 else {}


func _is_literal(ast: Dictionary, value: int) -> bool:
	return str(ast.get("type", "")) == "literal" and int(ast.get("value", 0)) == value


func _is_state_ref(ast: Dictionary, storage: String, bank: int, index: int) -> bool:
	return (
		str(ast.get("type", "")) == "state_ref"
		and str(ast.get("storage", "")) == storage
		and int(ast.get("bank", 0)) == bank
		and _is_literal(ast.get("index", {}), index)
	)


func _is_dynamic_banked_u8_cursor(ast: Dictionary) -> bool:
	return (
		str(ast.get("type", "")) == "state_ref"
		and str(ast.get("storage", "")) == "banked_u8"
		and int(ast.get("bank", -1)) == 25
		and _is_state_ref(ast.get("index", {}), "state_u16", 0, 1)
	)


func _inc(counts: Dictionary, key: Variant) -> void:
	counts[key] = int(counts.get(key, 0)) + 1


func _format_counts(counts: Dictionary) -> String:
	var labels: Array[String] = []
	var keys: Array = counts.keys()
	keys.sort_custom(func(left: Variant, right: Variant) -> bool: return str(left) < str(right))
	for key in keys:
		labels.append("%s:%d" % [str(key), int(counts[key])])
	return ",".join(labels) if not labels.is_empty() else "none"


func _fail(reader: RefCounted, message: String) -> void:
	reader.call("close")
	push_error(message)
	quit(1)
