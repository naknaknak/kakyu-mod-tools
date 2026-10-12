extends "res://tools/content_suite/cli_script.gd"

const ArcReaderScript := preload("res://content_core/arc_reader.gd")
const CalendarStateScript := preload("res://content_core/mes_calendar_state.gd")
const LibraryIndexScript := preload("res://content_core/mes_library_index.gd")
const LibraryRunnerScript := preload("res://content_core/mes_library_runner.gd")
const MesContainerScript := preload("res://content_core/mes_container.gd")
const MesEventRunnerScript := preload("res://content_core/mes_event_runner.gd")
const SandboxStateScript := preload("res://content_core/mes_sandbox_state.gd")

const SCHEMA := "kakyu_mes_promise_date_library_resume_audit/v1"
const ARCHIVE_SHA256 := "31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6"
const ENTRY_SHA256 := {
	"START.MES": "ba57bf666fbd9db9b3110f2bf1c70e80e11a35de00e82256aaaf35921c77038f",
	"LIBLARY.LIB": "d9aba6eb8dab51fe321e22c868ed0cf38416bba1f0cf2f5d7d719f48e89b8b4d",
	"A_PROMIS.MES": "81d3de790b2a1542f09dfedd753c5010970971acb38e64b9e0241c6c2f31ca19",
	"B_PROMIS.MES": "c1270051a6ea49bcc84fae4d9060e6d2bc114b672dc8beecdf5e97dc552c446d",
	"D_PROMIS.MES": "5d5a09ad7cb4a2a3af70cc6d32588d67445de5db585144c796bb0b722e661f68",
	"F_PROMIS.MES": "60d8638c9d422a189dbd2b08ee6127ccdcb18a38370be0d965b8dfdd62492f08",
	"G_PROMIS.MES": "a3bb5f57e28def5baea46271813ea4529472a5568b48f05384468d9f4442ca8e",
	"H_PROMIS.MES": "395a8c8290c57bf2cabfe679fa866369c2af5a9069527dfeb29cef245b25cdf8",
	"J_PROMIS.MES": "e64748323d69b53cd5db38ce1bb44353ec719d0c80d41bc3c04c39a0598672f2",
	"K_PROMIS.MES": "0a06c7efea59f44ca3bea815f7a8f25bfa5e08397e6c774f976811500582f90b",
	"L_PROMIS.MES": "4dd0cfd93a2f0146764a3086ba5dec1429775e22ce9e1c511fdb013faf14e40c",
}
const CASES := [
	{"entry": "A_PROMIS.MES", "intro": 0x2036, "boundary": 0x2091, "resume": 0x2096, "writer": 0x209B, "choice": 0x2C6B, "suffix_steps": 103, "field": 215},
	{"entry": "B_PROMIS.MES", "intro": 0x253A, "boundary": 0x2591, "resume": 0x2596, "writer": 0x259B, "choice": 0x2F88, "suffix_steps": 70, "field": 233},
	{"entry": "D_PROMIS.MES", "intro": 0x1CD0, "boundary": 0x1D2D, "resume": 0x1D32, "writer": 0x1D37, "choice": 0x2726, "suffix_steps": 70, "field": 237},
	{"entry": "F_PROMIS.MES", "intro": 0x1DDE, "boundary": 0x1E3F, "resume": 0x1E44, "writer": 0x1E49, "choice": 0x289B, "suffix_steps": 78, "field": 213},
	{"entry": "G_PROMIS.MES", "intro": 0x2648, "boundary": 0x269D, "resume": 0x26A2, "writer": 0x26A7, "choice": 0x3114, "suffix_steps": 80, "field": 221},
	{"entry": "H_PROMIS.MES", "intro": 0x1D7D, "boundary": 0x1DDC, "resume": 0x1DE1, "writer": 0x1DE6, "choice": 0x2855, "suffix_steps": 80, "field": 227},
	{"entry": "J_PROMIS.MES", "intro": 0x1DBB, "boundary": 0x1E12, "resume": 0x1E17, "writer": 0x1E1C, "choice": 0x281D, "suffix_steps": 70, "field": 235},
	{"entry": "K_PROMIS.MES", "intro": 0x21CF, "boundary": 0x221A, "resume": 0x221F, "writer": 0x2224, "choice": 0x2C9B, "suffix_steps": 80, "field": 229},
	{"entry": "L_PROMIS.MES", "intro": 0x1C13, "boundary": 0x1C72, "resume": 0x1C77, "writer": 0x1C7C, "choice": 0x26F5, "suffix_steps": 80, "field": 231},
]


func _init() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() != 1:
		_fail("Usage: audit_mes_promise_date_library_resume.gd <mes.arc>")
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
	var projection := calendar.build(start_document)
	if not start_document.ok or not library_document.ok or not library_index.ok or not projection.get("ok", false):
		reader.close()
		_fail("Required original calendar/library projections could not be built.")
		return
	var reports: Array[String] = []
	var failures: Array[String] = []
	for specification in CASES:
		var entry_name := str(specification.entry)
		var document := parser.parse(reader.read_entry(entry_name), {"archive": "mes.arc", "entry": entry_name})
		var state := SandboxStateScript.new(1)
		calendar.apply_to_state(projection, state)
		state.write_value("state_u16", 7, 401)
		state.write_value("state_u16", 19, 77)
		state.write_value("banked_u16", int(specification.field), 0xFFFF, 0)
		var prefix := MesEventRunnerScript.new().run(
			document.bytecode,
			int(specification.intro),
			state,
			int(document.header.code_size),
			2000,
			{"address_table_offsets": document.header.entry_offsets, "native_stream_policy": "skip_bounded"}
		)
		var prefix_trace: Array = prefix.get("trace", [])
		var terminal: Dictionary = prefix_trace[-1] if not prefix_trace.is_empty() else {}
		var routine_id := int(terminal.get("routine_id", -1))
		var prefix_state_0 := state.read_value("state_u16", 0)
		var prefix_state_9 := state.read_value("state_u16", 9)
		var prefix_state_10 := state.read_value("state_u16", 10)
		var prefix_arguments: Dictionary = prefix.get("argument_slots", {}).duplicate(true)
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
			document.bytecode,
			int(prefix.get("resume_offset", -1)),
			state,
			int(document.header.code_size),
			2000,
			{
				"argument_slots": library_result.get("argument_slots", {}).duplicate(true),
				"persistent_expression_stack": library_result.get("persistent_expression_stack", []).duplicate(),
				"native_stream_policy": "skip_bounded",
			}
		)
		var writer_rows: Array = suffix.get("trace", []).filter(
			func(record: Dictionary) -> bool: return int(record.get("source_offset", -1)) == int(specification.writer)
		)
		var library_trace: Array = library_result.get("trace", [])
		var field_value := state.read_value("banked_u16", int(specification.field), 0)
		reports.append("%s:prefix=%d@0x%X:s0=%d/s9=%d/s10=%d/args=%s/routine%d=%s:%d/suffix=%s:%d@0x%X/field%d=%d/state10=%d" % [
			entry_name,
			prefix_trace.size(),
			int(prefix.get("offset", -1)),
			prefix_state_0,
			prefix_state_9,
			prefix_state_10,
			str(prefix_arguments),
			routine_id,
			str(library_result.get("status", "unknown")),
			library_trace.size(),
			str(suffix.get("status", "unknown")),
			(suffix.get("trace", []) as Array).size(),
			int(suffix.get("offset", -1)),
			int(specification.field),
			field_value,
			state.read_value("state_u16", 10),
		])
		if (
			not document.ok
			or str(prefix.get("status", "")) != "shared_routine_boundary"
			or prefix_trace.size() != 9
			or int(prefix.get("offset", -1)) != int(specification.boundary)
			or int(prefix.get("resume_offset", -1)) != int(specification.resume)
			or routine_id != 24
			or prefix_state_0 != 0
			or prefix_state_9 != 1
			or prefix_state_10 != 401
			or not library_result.get("ok", false)
			or str(library_result.get("status", "")) != "library_return"
			or library_trace.size() != 102
			or not (library_result.get("calls", []) as Array).is_empty()
			or not (library_result.get("messages", []) as Array).is_empty()
			or int(library_result.get("omitted_native_presentation_count", -1)) != 0
			# Core 0.316.0 (2026-09-13): the 13-row "return" this audit once
			# recorded after the date writer was the 00 that ends a message
			# wait's record list, read as command 0x00 under the separator
			# framing. The caller suffix runs on from the writer to the time
			# selector's DEF selection boundary, the `choice_boundary` the
			# Event Player's PROMIS route table already names.
			or str(suffix.get("status", "")) != "def_selection_boundary"
			or (suffix.get("trace", []) as Array).size() != int(specification["suffix_steps"])
			or int(suffix.get("offset", -1)) != int(specification["choice"])
			or writer_rows.size() != 1
			or field_value != 402
			or state.read_value("state_u16", 10) != 402
		):
			failures.append("%s did not compose its owner intro through routine 24 to the date writer." % entry_name)
	var archive_after := reader.get_archive_fingerprint()
	reader.close()
	if archive_after != archive_before:
		failures.append("Original mes.arc changed during read-only date-writer audit.")
	if not failures.is_empty():
		print("MES_PROMISE_DATE_LIBRARY_RESUME_DIAGNOSTIC " + " | ".join(reports))
		for failure in failures:
			push_error(failure)
		quit(1)
		return
	print("MES_PROMISE_DATE_LIBRARY_RESUME schema=%s cases=%s source_unchanged=true" % [SCHEMA, " | ".join(reports)])
	quit(0)
