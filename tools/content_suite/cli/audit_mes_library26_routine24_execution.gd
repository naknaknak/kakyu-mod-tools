extends "res://tools/content_suite/cli_script.gd"

const ArcReaderScript := preload("res://content_core/arc_reader.gd")
const CalendarStateScript := preload("res://content_core/mes_calendar_state.gd")
const LibraryIndexScript := preload("res://content_core/mes_library_index.gd")
const LibraryRunnerScript := preload("res://content_core/mes_library_runner.gd")
const MesContainerScript := preload("res://content_core/mes_container.gd")
const SandboxStateScript := preload("res://content_core/mes_sandbox_state.gd")

const SCHEMA := "kakyu_mes_library26_routine24_execution_audit/v2"
const ARCHIVE_SHA256 := "31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6"
const START_SHA256 := "ba57bf666fbd9db9b3110f2bf1c70e80e11a35de00e82256aaaf35921c77038f"
const LIBRARY_SHA256 := "d9aba6eb8dab51fe321e22c868ed0cf38416bba1f0cf2f5d7d719f48e89b8b4d"
const ROUTINE_24_BODY := 0x1D6E
const ROUTINE_24_END := 0x1DFD
const ROUTINE_26_BODY := 0x2020
const ROUTINE_26_END := 0x3541
const ROUTINE_26_FIRST_CALL_24 := 0x217D
const ROUTINE_26_BLOCK_STRIDE := 0x01A0
const ROUTINE_26_CALL_COUNT := 13
const DIRECT_TRACE_COUNT := 105
const COMPOSED_TRACE_COUNT := 140
const DIRECT_DIFF := "state_u16[0:0]=27,state_u16[0:10]=128,state_u16[0:25]=9376"


func _init() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() != 1:
		_fail("Usage: audit_mes_library26_routine24_execution.gd <mes.arc>")
		return
	var reader := ArcReaderScript.new()
	if not reader.open(arguments[0]):
		_fail(reader.last_error)
		return
	var archive_before := reader.get_archive_fingerprint()
	if (
		archive_before != ARCHIVE_SHA256
		or reader.get_entry_fingerprint("START.MES") != START_SHA256
		or reader.get_entry_fingerprint("LIBLARY.LIB") != LIBRARY_SHA256
	):
		reader.close()
		_fail("Routine-26/24 audit requires the hash-bound original MES sources.")
		return
	var parser := MesContainerScript.new()
	var start_document := parser.parse(reader.read_entry("START.MES"), {"archive": "mes.arc", "entry": "START.MES"})
	var library_document := parser.parse(reader.read_entry("LIBLARY.LIB"), {"archive": "mes.arc", "entry": "LIBLARY.LIB"})
	var library_index := LibraryIndexScript.new().build(library_document.bytecode, int(library_document.header.code_size))
	var calendar := CalendarStateScript.new()
	var projection := calendar.build(start_document)
	var routine_24: Dictionary = library_index.get("by_id", {}).get(24, {})
	var routine_26: Dictionary = library_index.get("by_id", {}).get(26, {})
	if (
		not start_document.ok
		or not library_document.ok
		or not library_index.ok
		or not projection.get("ok", false)
		or int(routine_24.get("body_offset", -1)) != ROUTINE_24_BODY
		or int(routine_24.get("end_offset", -1)) != ROUTINE_24_END
		or int(routine_26.get("body_offset", -1)) != ROUTINE_26_BODY
		or int(routine_26.get("end_offset", -1)) != ROUTINE_26_END
	):
		reader.close()
		_fail("Required calendar or library projection failed.")
		return
	var date_state := SandboxStateScript.new(1)
	calendar.apply_to_state(projection, date_state)
	date_state.write_value("state_u16", 10, 101)
	date_state.write_value("state_u16", 9, 27)
	var date_before := date_state.snapshot()
	var date_result := LibraryRunnerScript.new().run(library_document.bytecode, library_index, 24, date_state)
	var date_trace: Array = date_result.get("trace", [])
	var date_diff_signature := _diff_signature(date_state.diff(date_before))
	var failures: Array[String] = []
	if (
		not date_result.get("ok", false)
		or str(date_result.get("status", "")) != "library_return"
		or date_trace.size() != DIRECT_TRACE_COUNT
		or int((date_trace[0] as Dictionary).get("source_offset", -1)) != ROUTINE_24_BODY
		or int((date_trace[-1] as Dictionary).get("source_offset", -1)) != ROUTINE_24_END - 1
		or date_state.read_value("state_u16", 10) != 128
		or date_diff_signature != DIRECT_DIFF
		or not (date_result.get("calls", []) as Array).is_empty()
		or not (date_result.get("messages", []) as Array).is_empty()
		or int(date_result.get("omitted_native_presentation_count", -1)) != 0
	):
		failures.append("Direct routine 24 no longer advances 0101 by 27 days to 0128.")
	var case_reports: Array[String] = []
	for block_index in range(ROUTINE_26_CALL_COUNT):
		var expected_call := ROUTINE_26_FIRST_CALL_24 + block_index * ROUTINE_26_BLOCK_STRIDE
		var expected_resume := expected_call + 5
		if (
			int(library_document.bytecode[expected_call - 27]) != 0x0B
			or int(library_document.bytecode[expected_call - 26]) != 0xF1
			or int(library_document.bytecode[expected_call - 23]) != 0xA0
			or int(library_document.bytecode[expected_call]) != 0x1D
			or int(library_document.bytecode[expected_call + 16]) != 0x04
			or int(library_document.bytecode[expected_call + 17]) != 10
			or int(library_document.bytecode[expected_call + 18]) != 0xF1
		):
			failures.append("Routine-26 block %d no longer has the audited schedule/call/value shape." % block_index)
			continue
		var date_index := int(library_document.bytecode.decode_u16(expected_call - 25))
		var value_index := int(library_document.bytecode.decode_u16(expected_call + 19))
		var state := SandboxStateScript.new(1)
		calendar.apply_to_state(projection, state)
		state.write_value("state_u16", 7, 201)
		state.write_value("banked_u16", value_index, 100, 0)
		state.write_value("banked_u16", date_index, 101, 0)
		var before := state.snapshot()
		var result := LibraryRunnerScript.new().run(library_document.bytecode, library_index, 26, state)
		var calls: Array = result.get("calls", [])
		var trace: Array = result.get("trace", [])
		var nested_trace_count := trace.filter(
			func(record: Dictionary) -> bool: return int(record.get("library_routine_id", -1)) == 24
		).size()
		var composed_diff_signature := _diff_signature(state.diff(before))
		case_reports.append("%d/%d:0x%X>0x%X" % [value_index, date_index, expected_call, expected_resume])
		if (
			not result.get("ok", false)
			or str(result.get("status", "")) != "library_return"
			or trace.size() != COMPOSED_TRACE_COUNT
			or nested_trace_count != DIRECT_TRACE_COUNT
			or calls.size() != 1
			or int((calls[0] as Dictionary).get("caller_routine_id", -1)) != 26
			or int((calls[0] as Dictionary).get("callee_routine_id", -1)) != 24
			or int((calls[0] as Dictionary).get("call_offset", -1)) != expected_call
			or int((calls[0] as Dictionary).get("resume_offset", -1)) != expected_resume
			or int((calls[0] as Dictionary).get("call_depth", -1)) != 0
			or composed_diff_signature != _expected_composed_diff(value_index, date_index)
			or not (result.get("messages", []) as Array).is_empty()
			or int(result.get("omitted_native_presentation_count", -1)) != 0
		):
			failures.append(
				"Routine-26 block %d did not return through its exact routine-24 call: trace=%d nested=%d calls=%s diff=%s"
				% [block_index, trace.size(), nested_trace_count, str(calls), composed_diff_signature]
			)
	var archive_after := reader.get_archive_fingerprint()
	var start_after := reader.get_entry_fingerprint("START.MES")
	var library_after := reader.get_entry_fingerprint("LIBLARY.LIB")
	reader.close()
	if archive_after != archive_before or start_after != START_SHA256 or library_after != LIBRARY_SHA256:
		failures.append("Original MES sources changed during the read-only routine audit.")
	if not failures.is_empty():
		for failure in failures:
			push_error(failure)
		quit(1)
		return
	print(
		"MES_LIBRARY26_ROUTINE24_EXECUTION schema=%s direct24=%d:0101+27>0128 blocks=%s each=%d_rows/24x%d source_unchanged=true"
		% [
			SCHEMA,
			date_trace.size(),
			",".join(case_reports),
			COMPOSED_TRACE_COUNT,
			DIRECT_TRACE_COUNT,
		]
	)
	quit(0)


func _diff_signature(diff: Array) -> String:
	var parts: Array[String] = []
	for untyped_change in diff:
		var change: Dictionary = untyped_change
		parts.append(
			"%s[%d:%d]=%d"
			% [
				str(change.get("storage", "?")),
				int(change.get("bank", 0)),
				int(change.get("index", -1)),
				int(change.get("after", 0)),
			]
		)
	return ",".join(parts) if not parts.is_empty() else "none"


func _expected_composed_diff(value_index: int, date_index: int) -> String:
	return (
		"banked_u16[0:%d]=90,banked_u16[0:%d]=0,state_u16[0:0]=27,state_u16[0:10]=10,state_u16[0:25]=9376,state_u16[0:9]=27"
		% [value_index, date_index]
	)
