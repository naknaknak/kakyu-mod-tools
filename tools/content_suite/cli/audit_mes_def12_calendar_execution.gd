extends "res://tools/content_suite/cli_script.gd"

const ArcReaderScript := preload("res://content_core/arc_reader.gd")
const CalendarStateScript := preload("res://content_core/mes_calendar_state.gd")
const MesContainerScript := preload("res://content_core/mes_container.gd")
const MesEventRunnerScript := preload("res://content_core/mes_event_runner.gd")
const MesStartupContextScript := preload("res://content_core/mes_startup_context.gd")
const SandboxStateScript := preload("res://content_core/mes_sandbox_state.gd")

const SCHEMA := "kakyu_mes_def12_calendar_execution_audit/v1"
const ARCHIVE_SHA256 := "31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6"
const START_ENTRY_SHA256 := "ba57bf666fbd9db9b3110f2bf1c70e80e11a35de00e82256aaaf35921c77038f"
const DEFINITION_ENTRY_SHA256 := "f2012ce5d90f60a5d1ca8190e03571341c0384c2d3d96e9aec2b3ab949db0ef0"
const TABLE_SHA256 := "f21ee0fcb09e960046878e35ad0410aed88680f849ace471b713ef7a12525b4a"
const CASE_DATES := [101, 201, 301, 401, 501, 601, 701, 801, 901, 1001, 1101, 1201, 1301]
const CASE_LENGTHS := [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31, 31]
const EXPECTED_STATUS := "shared_routine_boundary"
const EXPECTED_BOUNDARY := "0xEF0>26"


func _init() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() != 1:
		_fail("Usage: audit_mes_def12_calendar_execution.gd <mes.arc>")
		return
	var reader := ArcReaderScript.new()
	if not reader.open(arguments[0]):
		_fail(reader.last_error)
		return
	var archive_before := reader.get_archive_fingerprint()
	var start_before := reader.get_entry_fingerprint("START.MES")
	var definition_before := reader.get_entry_fingerprint("DEF_MAIN.MES")
	if (
		archive_before != ARCHIVE_SHA256
		or start_before != START_ENTRY_SHA256
		or definition_before != DEFINITION_ENTRY_SHA256
	):
		reader.close()
		_fail("DEF12 calendar execution source hashes do not match the audited original set.")
		return
	var parser := MesContainerScript.new()
	var start_document := parser.parse(reader.read_entry("START.MES"), {"archive": "mes.arc", "entry": "START.MES"})
	var definition_document := parser.parse(reader.read_entry("DEF_MAIN.MES"), {"archive": "mes.arc", "entry": "DEF_MAIN.MES"})
	var calendar := CalendarStateScript.new()
	var projection := calendar.build(start_document)
	var startup_context := MesStartupContextScript.new().build(definition_document)
	var definition: Dictionary = startup_context.get("registered_definitions", {}).get(12, {})
	var failures: Array[String] = []
	var case_reports: Array[String] = []
	var status_counts := {}
	var boundary_counts := {}
	if (
		not projection.get("ok", false)
		or str(projection.get("table_sha256", "")) != TABLE_SHA256
		or not startup_context.get("ok", false)
		or definition.is_empty()
	):
		failures.append("Required START calendar or registered DEF12 projection failed.")
	else:
		for case_index in range(CASE_DATES.size()):
			var state := SandboxStateScript.new(1)
			var applied := calendar.apply_to_state(projection, state)
			state.write_value("state_u16", 7, int(CASE_DATES[case_index]))
			var result := MesEventRunnerScript.new().run(
				definition.code,
				int(definition.body_offset),
				state,
				int(definition.end_offset),
				2000,
				{"native_stream_policy": "skip_bounded"}
			)
			var true_count := 0
			var exit_count := 0
			for record in result.get("trace", []):
				if int(record.get("source_offset", -1)) != 0x04DC:
					continue
				if int(record.get("condition_value", -1)) == 1 and str(record.get("effect", "")) == "fallthrough":
					true_count += 1
				elif (
					int(record.get("condition_value", -1)) == 0
					and str(record.get("effect", "")) == "branch"
					and int(record.get("next_offset", -1)) == 0x04F5
				):
					exit_count += 1
			var expected_length := int(CASE_LENGTHS[case_index])
			var status := str(result.get("status", "unknown"))
			status_counts[status] = int(status_counts.get(status, 0)) + 1
			var result_trace: Array = result.get("trace", [])
			var terminal: Dictionary = result_trace[-1] if not result_trace.is_empty() else {}
			var boundary_key := "0x%X>%d" % [int(terminal.get("source_offset", -1)), int(terminal.get("routine_id", -1))]
			boundary_counts[boundary_key] = int(boundary_counts.get(boundary_key, 0)) + 1
			case_reports.append("%d:%d:%s:%s" % [int(CASE_DATES[case_index]), true_count, status, boundary_key])
			if (
				not applied.get("ok", false)
				or true_count != expected_length
				or exit_count != 1
				or status != EXPECTED_STATUS
				or boundary_key != EXPECTED_BOUNDARY
			):
				failures.append(
					"date %d expected %d scanned bytes and one 0x4F5 exit, got true=%d exits=%d status=%s offset=0x%X"
					% [int(CASE_DATES[case_index]), expected_length, true_count, exit_count, status, int(result.get("offset", -1))]
				)
	var archive_after := reader.get_archive_fingerprint()
	var start_after := reader.get_entry_fingerprint("START.MES")
	var definition_after := reader.get_entry_fingerprint("DEF_MAIN.MES")
	reader.close()
	if archive_after != archive_before or start_after != start_before or definition_after != definition_before:
		failures.append("Original mes.arc changed during DEF12 calendar execution audit.")
	if not failures.is_empty():
		for failure in failures:
			push_error(failure)
		quit(1)
		return
	print(
		"MES_DEF12_CALENDAR_EXECUTION schema=%s cases=%s statuses=%s boundaries=%s table_sha256=%s source_unchanged=true"
		% [SCHEMA, ",".join(case_reports), str(status_counts), str(boundary_counts), TABLE_SHA256]
	)
	quit(0)
