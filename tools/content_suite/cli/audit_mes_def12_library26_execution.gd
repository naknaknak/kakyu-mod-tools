extends "res://tools/content_suite/cli_script.gd"

const ArcReaderScript := preload("res://content_core/arc_reader.gd")
const CalendarStateScript := preload("res://content_core/mes_calendar_state.gd")
const LibraryIndexScript := preload("res://content_core/mes_library_index.gd")
const LibraryRunnerScript := preload("res://content_core/mes_library_runner.gd")
const MesContainerScript := preload("res://content_core/mes_container.gd")
const MesEventRunnerScript := preload("res://content_core/mes_event_runner.gd")
const MesStartupContextScript := preload("res://content_core/mes_startup_context.gd")
const SandboxStateScript := preload("res://content_core/mes_sandbox_state.gd")

const SCHEMA := "kakyu_mes_def12_library26_execution_audit/v1"
const ARCHIVE_SHA256 := "31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6"
const ENTRY_SHA256 := {
	"START.MES": "ba57bf666fbd9db9b3110f2bf1c70e80e11a35de00e82256aaaf35921c77038f",
	"DEF_MAIN.MES": "f2012ce5d90f60a5d1ca8190e03571341c0384c2d3d96e9aec2b3ab949db0ef0",
	"LIBLARY.LIB": "d9aba6eb8dab51fe321e22c868ed0cf38416bba1f0cf2f5d7d719f48e89b8b4d",
}
const CASE_DATES := [101, 201, 301, 401, 501, 601, 701, 801, 901, 1001, 1101, 1201, 1301]
const EXPECTED_PREFIX_TRACE_COUNTS := [172, 162, 171, 168, 171, 168, 171, 171, 168, 171, 168, 171, 172]
const EXPECTED_PREFIX_BOUNDARY := 0x0EF0
const EXPECTED_CALLER_RESUME := 0x0EF5
const EXPECTED_CALLER_RETURN := 0x0EFA
const EXPECTED_LIBRARY_BODY := 0x2020
const EXPECTED_LIBRARY_END := 0x3541
const EXPECTED_LIBRARY_RETURN := 0x3540
const EXPECTED_LIBRARY_TRACE_COUNT := 27


func _init() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() != 1:
		_fail("Usage: audit_mes_def12_library26_execution.gd <mes.arc>")
		return
	var reader := ArcReaderScript.new()
	if not reader.open(arguments[0]):
		_fail(reader.last_error)
		return
	var archive_before := reader.get_archive_fingerprint()
	if archive_before != ARCHIVE_SHA256:
		reader.close()
		_fail("DEF12/library-26 audit requires the hash-bound original mes.arc.")
		return
	for entry_name in ENTRY_SHA256:
		if reader.get_entry_fingerprint(entry_name) != ENTRY_SHA256[entry_name]:
			reader.close()
			_fail("%s does not match the audited original entry." % entry_name)
			return
	var parser := MesContainerScript.new()
	var start_document := parser.parse(reader.read_entry("START.MES"), {"archive": "mes.arc", "entry": "START.MES"})
	var definition_document := parser.parse(reader.read_entry("DEF_MAIN.MES"), {"archive": "mes.arc", "entry": "DEF_MAIN.MES"})
	var library_document := parser.parse(reader.read_entry("LIBLARY.LIB"), {"archive": "mes.arc", "entry": "LIBLARY.LIB"})
	var library_index := LibraryIndexScript.new().build(library_document.bytecode, int(library_document.header.code_size))
	var startup_context := MesStartupContextScript.new().build(definition_document)
	var definition: Dictionary = startup_context.get("registered_definitions", {}).get(12, {})
	var calendar := CalendarStateScript.new()
	var projection := calendar.build(start_document)
	var routine_26: Dictionary = library_index.get("by_id", {}).get(26, {})
	if (
		not start_document.ok
		or not definition_document.ok
		or not library_document.ok
		or not library_index.ok
		or not startup_context.ok
		or definition.is_empty()
		or not projection.get("ok", false)
		or int(routine_26.get("body_offset", -1)) != EXPECTED_LIBRARY_BODY
		or int(routine_26.get("end_offset", -1)) != EXPECTED_LIBRARY_END
	):
		reader.close()
		_fail("Required original MES projections could not be built.")
		return
	var reports: Array[String] = []
	var failures: Array[String] = []
	for case_index in range(CASE_DATES.size()):
		var date := int(CASE_DATES[case_index])
		var state := SandboxStateScript.new(1)
		calendar.apply_to_state(projection, state)
		state.write_value("state_u16", 7, date)
		var prefix := MesEventRunnerScript.new().run(
			definition.code,
			int(definition.body_offset),
			state,
			int(definition.end_offset),
			2000,
			{"native_stream_policy": "skip_bounded"}
		)
		var prefix_trace: Array = prefix.get("trace", [])
		var terminal: Dictionary = prefix_trace[-1] if not prefix_trace.is_empty() else {}
		var routine_id := int(terminal.get("routine_id", -1))
		var library_result := LibraryRunnerScript.new().run(
			library_document.bytecode,
			library_index,
			routine_id,
			state,
			{
				"argument_slots": prefix.get("argument_slots", {}).duplicate(true),
				"persistent_expression_stack": prefix.get("persistent_expression_stack", []).duplicate(),
			}
		)
		var suffix := MesEventRunnerScript.new().run(
			definition.code,
			int(prefix.get("resume_offset", -1)),
			state,
			int(definition.end_offset),
			2000,
			{
				"argument_slots": library_result.get("argument_slots", {}).duplicate(true),
				"persistent_expression_stack": library_result.get("persistent_expression_stack", []).duplicate(),
				"native_stream_policy": "skip_bounded",
			}
		)
		var call_counts := _call_counts(library_result.get("calls", []))
		var library_diff: Array = library_result.get("state_diff", [])
		var library_trace: Array = library_result.get("trace", [])
		var first_library_offset := int(library_trace[0].get("source_offset", -1)) if not library_trace.is_empty() else -1
		var last_library_offset := int(library_trace[-1].get("source_offset", -1)) if not library_trace.is_empty() else -1
		reports.append(
			"%d:prefix=%d@0x%X>routine%d=%d@0x%X..0x%X>caller=%d@0x%X"
			% [
				int(date),
				prefix_trace.size(),
				int(prefix.get("resume_offset", -1)),
				routine_id,
				library_trace.size(),
				first_library_offset,
				last_library_offset,
				(suffix.get("trace", []) as Array).size(),
				int(suffix.get("offset", -1)),
			]
		)
		if (
			str(prefix.get("status", "")) != "shared_routine_boundary"
			or prefix_trace.size() != int(EXPECTED_PREFIX_TRACE_COUNTS[case_index])
			or int(terminal.get("source_offset", -1)) != EXPECTED_PREFIX_BOUNDARY
			or int(prefix.get("resume_offset", -1)) != EXPECTED_CALLER_RESUME
			or routine_id != 26
			or not library_result.get("ok", false)
			or str(library_result.get("status", "")) != "library_return"
			or library_trace.size() != EXPECTED_LIBRARY_TRACE_COUNT
			or first_library_offset != EXPECTED_LIBRARY_BODY
			or last_library_offset != EXPECTED_LIBRARY_RETURN
			or not call_counts.is_empty()
			or not library_diff.is_empty()
			or not (library_result.get("messages", []) as Array).is_empty()
			or int(library_result.get("omitted_native_presentation_count", -1)) != 0
			or str(suffix.get("status", "")) != "script_return"
			or (suffix.get("trace", []) as Array).size() != 2
			or int(suffix.get("offset", -1)) != EXPECTED_CALLER_RETURN
			or not (suffix.get("state_diff", []) as Array).is_empty()
		):
			failures.append("Date %d did not complete the audited DEF12 -> shared routine 26 -> DEF12 route." % date)
	var archive_after := reader.get_archive_fingerprint()
	reader.close()
	if archive_after != archive_before:
		failures.append("Original mes.arc changed during the read-only audit.")
	if not failures.is_empty():
		print("MES_DEF12_LIBRARY26_PROBE schema=%s cases=%s" % [SCHEMA, " | ".join(reports)])
		for failure in failures:
			push_error(failure)
		quit(1)
		return
	print("MES_DEF12_LIBRARY26_EXECUTION schema=%s cases=%s source_unchanged=true" % [SCHEMA, " | ".join(reports)])
	quit(0)


func _call_counts(calls: Array) -> Dictionary:
	var counts := {}
	for untyped_call in calls:
		var call: Dictionary = untyped_call
		var routine_id := int(call.get("callee_routine_id", -1))
		counts[routine_id] = int(counts.get(routine_id, 0)) + 1
	return counts
