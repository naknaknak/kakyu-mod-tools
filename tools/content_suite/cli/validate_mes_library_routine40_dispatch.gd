extends "res://tools/content_suite/cli_script.gd"

const ArcReaderScript := preload("res://content_core/arc_reader.gd")
const MesContainerScript := preload("res://content_core/mes_container.gd")
const LibraryAuditScript := preload("res://content_core/mes_library_audit.gd")
const LibraryIndexScript := preload("res://content_core/mes_library_index.gd")

const SOURCE_ENTRY := "LIBLARY.LIB"
const SOURCE_ENTRY_SHA256 := "d9aba6eb8dab51fe321e22c868ed0cf38416bba1f0cf2f5d7d719f48e89b8b4d"
const ROUTINE_ID := 40
const BODY_OFFSET := 0x1C8E
const END_OFFSET := 0x1D67
const CONTROL_FLOW_UNREACHED_OFFSET := 0x1CB5


func _initialize() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() != 1:
		_fail("Usage: <mes.arc>")
		return
	var reader := ArcReaderScript.new()
	if not reader.open(ProjectSettings.globalize_path(str(arguments[0]))):
		_fail(reader.last_error)
		return
	var archive_sha := reader.get_archive_fingerprint()
	if reader.get_entry_fingerprint(SOURCE_ENTRY) != SOURCE_ENTRY_SHA256:
		reader.close()
		_fail("LIBLARY.LIB hash does not match the audited original entry.")
		return
	var document := MesContainerScript.new().parse(
		reader.read_entry(SOURCE_ENTRY),
		{"archive": "mes.arc", "entry": SOURCE_ENTRY}
	)
	if not document.ok or int(document.header.entry_count) != 0:
		reader.close()
		_fail("LIBLARY.LIB container is invalid.")
		return
	var index := LibraryIndexScript.new().build(document.bytecode, int(document.header.code_size))
	var audit := LibraryAuditScript.new().audit(document.bytecode, index, [ROUTINE_ID])
	if not index.ok or not audit.ok or audit.routines.size() != 1:
		reader.close()
		_fail("Routine-40 library audit failed.")
		return
	var routine: Dictionary = audit.routines[0]
	var flow: Dictionary = routine.native_dispatch_flow
	var reached_command_15_offsets: Array[int] = []
	var routine_20_offsets: Array[int] = []
	for untyped_row in flow.instructions:
		var row: Dictionary = untyped_row
		if int(row.command_id) == 0x15:
			reached_command_15_offsets.append(int(row.source_offset))
		if int(row.get("routine_id", -1)) == 20:
			routine_20_offsets.append(int(row.source_offset))
	var spans: Array = flow.native_spans
	var rows := {}
	for untyped_row in flow.instructions:
		var row: Dictionary = untyped_row
		rows[int(row.source_offset)] = row
	var control_flow_unreached: Array = []
	for untyped_row in flow.unreached_structural_instructions:
		var row: Dictionary = untyped_row
		if str(row.get("reason", "")) == "control_flow_not_reached":
			control_flow_unreached.append(row)
	if (
		str(audit.schema) != "kakyu_mes_library_audit/v17"
		or int(routine.body_offset) != BODY_OFFSET
		or int(routine.end_offset) != END_OFFSET
		or not bool(routine.strict.complete)
		or int(routine.strict.instruction_count) != 36
		or not bool(flow.complete)
		or int(flow.instruction_count) != 35
		or int(flow.edge_count) != 39
		or (flow.boundaries as Array).size() != 0
		or (flow.failures as Array).size() != 0
		or spans.size() != 2
		or int(spans[0].source_offset) != 0x1C95
		or int(spans[0].end_offset) != 0x1CA0
		or int(spans[1].source_offset) != 0x1CC4
		or int(spans[1].end_offset) != 0x1CD0
		or not _matches_native_spans(spans)
		or not (flow.shadowed_structural_instructions as Array).is_empty()
		or (flow.unreached_structural_instructions as Array).size() != 1
		or control_flow_unreached.size() != 1
		or int(control_flow_unreached[0].source_offset) != CONTROL_FLOW_UNREACHED_OFFSET
		or int(control_flow_unreached[0].command_id) != 0x0C
		or not reached_command_15_offsets.is_empty()
		or routine_20_offsets != [0x1D07]
		or not _matches_script_envelope(rows)
	):
		reader.close()
		_fail("Routine-40 native dispatcher boundary differs from the audited original.")
		return
	var source_unchanged := reader.get_archive_fingerprint() == archive_sha
	reader.close()
	if not source_unchanged:
		_fail("Source mes.arc changed during read-only validation.")
		return
	print(
		"PASS: routine40 native dispatch schema=%s archive=%s entry=%s flow=%d spans=%d typed_records=3/3+list_terminator shadowed=%d control_unreached=0x1CB5:command0C reached_command15=none state18_to21/zero_loop/lt17_native/state13_output routine20=0x1D07 clear_records=1..17 source_unchanged=true"
		% [
			str(audit.schema),
			archive_sha,
			SOURCE_ENTRY_SHA256,
			int(flow.instruction_count),
			spans.size(),
			(flow.shadowed_structural_instructions as Array).size(),
		]
	)
	quit(0)


func _matches_script_envelope(rows: Dictionary) -> bool:
	for required_offset in [
		0x1C8E, 0x1C95, 0x1CA0, 0x1CA6, 0x1CB0, 0x1CBA, 0x1CC4, 0x1CD0, 0x1CD5,
		0x1CE1, 0x1CE8, 0x1CED, 0x1CF7, 0x1CFD, 0x1D02, 0x1D07, 0x1D0C, 0x1D66,
	]:
		if not rows.has(required_offset):
			return false
	if (
		not _matches_branch(rows[0x1C8E], "literal", -1, "", 1, 0x1D07)
		or not _matches_native_record_dispatch(rows[0x1C95], 0x1CA0, 3)
		or not _matches_write(rows[0x1CA0], 21, "state_ref", 18, 0)
		or not _matches_branch(rows[0x1CA6], "binary", 21, "equal", 0, 0x1CBA)
		or int(rows[0x1CB0].get("continuation_target", -1)) != 0x1C8E
		or not _matches_branch(rows[0x1CBA], "binary", 21, "less_than", 17, 0x1CD5)
		or not _matches_native_record_dispatch(rows[0x1CC4], 0x1CD0, 3)
		or int(rows[0x1CD0].get("continuation_target", -1)) != 0x1CED
		or not _matches_branch(rows[0x1CD5], "binary", 21, "equal", 0xFFFF, 0x1CED)
		or not _matches_write(rows[0x1CE1], 13, "literal", -1, 0xFFFF)
		or int(rows[0x1CE8].get("continuation_target", -1)) != 0x1D07
		or not _matches_branch(rows[0x1CED], "binary", 18, "not_equal", 0, 0x1D02)
		or not _matches_write(rows[0x1CF7], 13, "state_ref", 18, 0)
		or int(rows[0x1CFD].get("continuation_target", -1)) != 0x1D07
		or int(rows[0x1D02].get("continuation_target", -1)) != 0x1C8E
		or int(rows[0x1D07].get("routine_id", -1)) != 20
		or int(rows[0x1D0C].get("entry_index", -1)) != 0
		or int(rows[0x1D66].get("command_id", -1)) != 0x00
	):
		return false
	for selector in range(1, 18):
		var offset := 0x1D11 + (selector - 1) * 5
		if (
			not rows.has(offset)
			or int(rows[offset].get("command_id", -1)) != 0x1B
			or int(rows[offset].get("record_value", -1)) != selector
		):
			return false
	return true


func _matches_native_spans(spans: Array) -> bool:
	var expected := [
		{"source": 0x1C95, "payload": 0x1C96, "end": 0x1CA0, "payload_bytes": 10, "records": 3},
		{"source": 0x1CC4, "payload": 0x1CC5, "end": 0x1CD0, "payload_bytes": 11, "records": 3},
	]
	if spans.size() != expected.size():
		return false
	for index in range(expected.size()):
		var span: Dictionary = spans[index]
		var wanted: Dictionary = expected[index]
		if (
			int(span.get("source_offset", -1)) != int(wanted.source)
			or int(span.get("payload_start_offset", -1)) != int(wanted.payload)
			or int(span.get("payload_end_offset", -1)) != int(wanted.end)
			or int(span.get("end_offset", -1)) != int(wanted.end)
			or int(span.get("command_id", -1)) != 0x12
			or str(span.get("handler_family", "")) != "native_record_dispatch"
			or str(span.get("consumption_kind", "")) != "typed_record_list_until_zero"
			or int(span.get("payload_byte_count", -1)) != int(wanted.payload_bytes)
			or int(span.get("record_count", -1)) != int(wanted.records)
			or not bool(span.get("terminator_consumed", false))
			or str(span.get("dispatch_semantics", "")) != "unresolved_not_executed"
		):
			return false
	return true


func _matches_native_record_dispatch(row: Dictionary, end_offset: int, record_count: int) -> bool:
	return (
		int(row.get("command_id", -1)) == 0x12
		and int(row.get("native_payload_end_offset", -1)) == end_offset
		and str(row.get("native_handler_family", "")) == "native_record_dispatch"
		and str(row.get("native_record_consumption", "")) == "typed_record_list_until_zero"
		and int(row.get("native_record_count", -1)) == record_count
		and bool(row.get("native_terminator_consumed", false))
	)


func _matches_branch(row: Dictionary, ast_type: String, state_index: int, operation: String, value: int, target: int) -> bool:
	if int(row.get("command_id", -1)) != 0x0B or int(row.get("branch_target", -1)) != target:
		return false
	var ast: Dictionary = row.get("condition_ast", {})
	if str(ast.get("type", "")) != ast_type:
		return false
	if ast_type == "literal":
		return int(ast.get("value", -1)) == value
	return (
		str(ast.get("op", "")) == operation
		and _is_state_u16_ref(ast.get("lhs", {}), state_index)
		and str(ast.get("rhs", {}).get("type", "")) == "literal"
		and int(ast.get("rhs", {}).get("value", -1)) == value
	)


func _matches_write(row: Dictionary, write_start: int, ast_type: String, state_index: int, value: int) -> bool:
	var expressions: Array = row.get("write_expressions", [])
	if (
		str(row.get("write_storage", "")) != "state_u16"
		or int(row.get("write_start", -1)) != write_start
		or int(row.get("write_count", 0)) != 1
		or expressions.size() != 1
	):
		return false
	var ast: Dictionary = expressions[0].get("ast", {})
	if str(ast.get("type", "")) != ast_type:
		return false
	return _is_state_u16_ref(ast, state_index) if ast_type == "state_ref" else int(ast.get("value", -1)) == value


func _is_state_u16_ref(ast: Dictionary, index: int) -> bool:
	return (
		str(ast.get("type", "")) == "state_ref"
		and str(ast.get("storage", "")) == "state_u16"
		and str(ast.get("index", {}).get("type", "")) == "literal"
		and int(ast.get("index", {}).get("value", -1)) == index
	)
