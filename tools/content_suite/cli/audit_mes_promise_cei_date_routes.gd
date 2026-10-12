extends "res://tools/content_suite/cli_script.gd"

const ArcReaderScript := preload("res://content_core/arc_reader.gd")
const CalendarStateScript := preload("res://content_core/mes_calendar_state.gd")
const LibraryIndexScript := preload("res://content_core/mes_library_index.gd")
const LibraryRunnerScript := preload("res://content_core/mes_library_runner.gd")
const MesContainerScript := preload("res://content_core/mes_container.gd")
const MesEventRunnerScript := preload("res://content_core/mes_event_runner.gd")
const SandboxStateScript := preload("res://content_core/mes_sandbox_state.gd")

const SCHEMA := "kakyu_mes_promise_cei_date_routes_audit/v1"
const ARCHIVE_SHA256 := "31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6"
const ENTRY_SHA256 := {
	"START.MES": "ba57bf666fbd9db9b3110f2bf1c70e80e11a35de00e82256aaaf35921c77038f",
	"LIBLARY.LIB": "d9aba6eb8dab51fe321e22c868ed0cf38416bba1f0cf2f5d7d719f48e89b8b4d",
	"C_PROMIS.MES": "485e997c7c328277de5dbdd11f32bcff291a20005825a26d5aecfbc172eb3fba",
	"E_PROMIS.MES": "0c72ae3a7977cb61753d73a3bee118ee230546f16752412081f63f054beca711",
	"I_PROMIS.MES": "afad7ff835232442f2d366fc3d4a0960a4b60fc74a6ceaf4cb8c365b1f5d7e30",
}
const CASES := [
	{"entry": "C_PROMIS.MES", "intro": 0x1B97, "boundary": 0x1C0B, "resume": 0x1C10, "writer": 0x1C15, "field": 225, "choice": 0x2655, "return": 0x463E},
	{"entry": "E_PROMIS.MES", "intro": 0x1D50, "boundary": 0x1DBA, "resume": 0x1DBF, "writer": 0x1DC4, "field": 217, "choice": 0x2817, "return": 0x4866},
	{"entry": "I_PROMIS.MES", "intro": 0x2554, "boundary": 0x25C4, "resume": 0x25C9, "writer": 0x25CE, "field": 219, "choice": 0x3039, "return": 0x5168},
]


func _init() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() != 1:
		_fail("Usage: audit_mes_promise_cei_date_routes.gd <mes.arc>")
		return
	var reader := ArcReaderScript.new()
	if not reader.open(arguments[0]):
		_fail(reader.last_error)
		return
	var archive_before := reader.get_archive_fingerprint()
	if archive_before != ARCHIVE_SHA256:
		reader.close()
		_fail("Unexpected mes.arc SHA-256.")
		return
	for entry_name in ENTRY_SHA256:
		if reader.get_entry_fingerprint(entry_name) != ENTRY_SHA256[entry_name]:
			reader.close()
			_fail("%s fingerprint changed." % entry_name)
			return
	var parser := MesContainerScript.new()
	var start_document := parser.parse(reader.read_entry("START.MES"), {"archive": "mes.arc", "entry": "START.MES"})
	var library_document := parser.parse(reader.read_entry("LIBLARY.LIB"), {"archive": "mes.arc", "entry": "LIBLARY.LIB"})
	var library_index := LibraryIndexScript.new().build(library_document.bytecode, int(library_document.header.code_size))
	var calendar := CalendarStateScript.new()
	var calendar_projection := calendar.build(start_document)
	if not start_document.ok or not library_document.ok or not library_index.ok or not calendar_projection.get("ok", false):
		reader.close()
		_fail("Required original calendar/library projections could not be built.")
		return
	var reports: Array[String] = []
	var failures: Array[String] = []
	for specification in CASES:
		var entry_name := str(specification.entry)
		var document := parser.parse(reader.read_entry(entry_name), {"archive": "mes.arc", "entry": entry_name})
		var state := SandboxStateScript.new(1)
		calendar.apply_to_state(calendar_projection, state)
		state.write_value("state_u16", 7, 401)
		state.write_value("state_u16", 19, 77)
		state.write_value("banked_u16", int(specification.field), 0xFFFF, 0)
		var runner := MesEventRunnerScript.new()
		var cursor := int(specification.intro)
		var context := {
			"address_table_offsets": document.header.entry_offsets.duplicate(),
			"protagonist_name": "Audit",
		}
		var dialogue_boundaries := 0
		var library_calls := 0
		var library_contract_ok := true
		var date_writer_hits := 0
		var terminal: Dictionary = {}
		for _segment in range(128):
			var result := runner.run(
				document.bytecode,
				cursor,
				state,
				int(document.header.code_size),
				2000,
				context
			)
			var status := str(result.get("status", ""))
			for record in result.get("trace", []):
				if int(record.get("source_offset", -1)) == int(specification.writer):
					date_writer_hits += 1
			if status == "dialogue_boundary":
				dialogue_boundaries += 1
				cursor = int(result.get("resume_offset", -1))
				context = {
					"address_table_offsets": document.header.entry_offsets.duplicate(),
					"protagonist_name": "Audit",
					"argument_slots": result.get("argument_slots", {}).duplicate(true),
					"persistent_expression_stack": result.get("persistent_expression_stack", []).duplicate(),
				}
				continue
			if status == "shared_routine_boundary":
				var trace: Array = result.get("trace", [])
				var routine_id := int(trace[-1].get("routine_id", -1)) if not trace.is_empty() else -1
				if routine_id != 24 or int(result.get("offset", -1)) != int(specification.boundary):
					terminal = result
					break
				var library_result := LibraryRunnerScript.new().run(
					library_document.bytecode,
					library_index,
					routine_id,
					state,
					{
						"argument_slots": result.get("argument_slots", {}).duplicate(true),
						"persistent_expression_stack": result.get("persistent_expression_stack", []).duplicate(),
					}
				)
				if not library_result.get("ok", false) or str(library_result.get("status", "")) != "library_return":
					terminal = library_result
					break
				library_contract_ok = library_contract_ok and (
					(library_result.get("trace", []) as Array).size() == 102
					and (library_result.get("calls", []) as Array).is_empty()
					and (library_result.get("messages", []) as Array).is_empty()
					and int(library_result.get("omitted_native_presentation_count", -1)) == 0
				)
				library_calls += 1
				cursor = int(result.get("resume_offset", -1))
				context = {
					"address_table_offsets": document.header.entry_offsets.duplicate(),
					"protagonist_name": "Audit",
					"argument_slots": library_result.get("argument_slots", {}).duplicate(true),
					"persistent_expression_stack": library_result.get("persistent_expression_stack", []).duplicate(),
				}
				continue
			terminal = result
			break
		var terminal_definitions: Array = terminal.get("definitions", [])
		var choice_reports: Array[String] = []
		var choices_ok := true
		if str(terminal.get("status", "")) == "def_selection_boundary" and terminal_definitions.size() == 10:
			var choice_snapshot: Dictionary = state.snapshot()
			for option in range(1, 11):
				state.restore(choice_snapshot)
				state.write_value("state_u16", 21, option)
				var choice_cursor := int(terminal.get("offset", -1)) + 5
				var choice_context := {"protagonist_name": "Audit"}
				var choice_dialogues := 0
				var choice_terminal: Dictionary = {}
				for _choice_segment in range(64):
					var choice_result := runner.run(
						document.bytecode,
						choice_cursor,
						state,
						int(document.header.code_size),
						2000,
						choice_context
					)
					if str(choice_result.get("status", "")) != "dialogue_boundary":
						choice_terminal = choice_result
						break
					choice_dialogues += 1
					choice_cursor = int(choice_result.get("resume_offset", -1))
					choice_context = {
						"protagonist_name": "Audit",
						"argument_slots": choice_result.get("argument_slots", {}).duplicate(true),
						"persistent_expression_stack": choice_result.get("persistent_expression_stack", []).duplicate(),
					}
				choice_reports.append("%d:d%d/%s@0x%X/f%d=%d/h%d/a%d" % [
					option,
					choice_dialogues,
					str(choice_terminal.get("status", "missing")),
					int(choice_terminal.get("offset", -1)),
					609 + option,
					state.read_value("global_u8", 609 + option),
					state.read_value("state_u16", 19),
					state.read_value("banked_u16", int(specification.field) + 1, 0),
				])
				if option == 1:
					choices_ok = choices_ok and (
						choice_dialogues == 2
						and str(choice_terminal.get("status", "")) == "def_selection_boundary"
						and int(choice_terminal.get("offset", -1)) == int(specification.choice)
						and state.read_value("global_u8", 610) == 0
						and state.read_value("state_u16", 19) == 77
						and state.read_value("banked_u16", int(specification.field) + 1, 0) == 0
					)
				else:
					var expected_hhmm := 800 + option * 100
					choices_ok = choices_ok and (
						choice_dialogues == 3
						and str(choice_terminal.get("status", "")) == "script_return"
						and int(choice_terminal.get("offset", -1)) == int(specification["return"])
						and state.read_value("global_u8", 609 + option) == 1
						and state.read_value("state_u16", 19) == 0
						and state.read_value("banked_u16", int(specification.field) + 1, 0) == expected_hhmm
					)
		reports.append("%s:intro0x%X/dialogue%d/r24=%d/field%d=%d/state10=%d/terminal=%s@0x%X/defs=%d" % [
			entry_name,
			int(specification.intro),
			dialogue_boundaries,
			library_calls,
			int(specification.field),
			state.read_value("banked_u16", int(specification.field), 0),
			state.read_value("state_u16", 10),
			str(terminal.get("status", "missing")),
			int(terminal.get("offset", -1)),
			terminal_definitions.size(),
		] + ("/choices=" + ",".join(choice_reports) if not choice_reports.is_empty() else ""))
		if (
			not document.ok
			or dialogue_boundaries != 4
			or library_calls != 1
			or not library_contract_ok
			or date_writer_hits != 1
			or state.read_value("banked_u16", int(specification.field), 0) != 402
			or state.read_value("state_u16", 10) != 402
			or str(terminal.get("status", "")) != "def_selection_boundary"
			or int(terminal.get("offset", -1)) != int(specification.choice)
			or terminal_definitions.size() != 10
			or not choices_ok
		):
			failures.append("%s did not retain its C/E/I date/time route contract." % entry_name)
	var archive_after := reader.get_archive_fingerprint()
	reader.close()
	if archive_after != archive_before:
		failures.append("Original mes.arc changed during the read-only C/E/I probe.")
	if not failures.is_empty():
		print("MES_PROMISE_CEI_DATE_DIAGNOSTIC " + " | ".join(reports))
		for failure in failures:
			push_error(failure)
		quit(1)
		return
	print("MES_PROMISE_CEI_DATE_ROUTES schema=%s cases=%s source_unchanged=true" % [SCHEMA, " | ".join(reports)])
	quit(0)
