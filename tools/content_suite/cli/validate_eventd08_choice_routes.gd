extends "res://tools/content_suite/cli_script.gd"

const ArcReaderScript := preload("res://content_core/arc_reader.gd")
const MesContainerScript := preload("res://content_core/mes_container.gd")
const MesEventRunnerScript := preload("res://content_core/mes_event_runner.gd")
const MesLibraryIndexScript := preload("res://content_core/mes_library_index.gd")
const MesLibraryRunnerScript := preload("res://content_core/mes_library_runner.gd")
const SandboxStateScript := preload("res://content_core/mes_sandbox_state.gd")

const SOURCE_ENTRY := "EVENTD08.MES"
const LIBRARY_ENTRY := "LIBLARY.LIB"
const ENTRY_SHA256 := "add5a481c407c863b646799d961033c5ce62da1b1874c227fd41d5685e7fd31c"
const RESUME_OFFSET := 0x073A
const SHARED_ROUTINE_OFFSET := 0x0A25
const SHARED_ROUTINE_ID := 28
const MAX_BOUNDARIES := 64
# Core 0.316.0 (2026-09-13): a dialogue boundary is reported at the wait call
# `0D 13 FF 02 02 FF 00`, three bytes before the `02` the separator framing
# stopped on (resume offsets unchanged), and shared routine 27 - which the
# separator framing cut after four rows at the 00 of a message wait read as
# command 0x00, with `banked_u16[0][1]` at 2 - runs its nineteen rows with
# three nested calls and five omitted presentation calls and leaves that cell
# at 7 before routine 25 stops at the DEF-26 boundary as before.
# Core 0.377.0 (TD-56): command 0x09 writes global_i32 (the storage token 0xF6
# reads), so the route's last argument assignment is the one sandbox change after
# the projected selection, and routine 28 - whose ladder selects on that cell -
# now runs the selector-1 arm instead of the unwritten-0 arm. Its steps, the
# three global_u8 flags that arm sets (4000, 4090, 4091), and routine 27's rows
# below (46, from 19: the picture ladder reads the selector the route assigned)
# are the values for that arm; before the feed routine 28 ran 8 steps with no
# state change.
const EXPECTED_ROUTE_DIFF := "global_i32[0:1]=0->1"
const EXPECTED_ROUTINE_28_BASELINE := "21/29,30/7/global_u8[0:4000]=0->1,global_u8[0:4090]=0->1,global_u8[0:4091]=0->1/[]"
const EXPECTED_POST_LIBRARY := "library25_library_definition_invoke_boundary@0xA66 prior=27:46/3/5/banked_u16[0:1]=1->7 stopped_steps=3 stopped_diff=none"
const EXPECTED := {
	1: {"boundaries": [0x077D, 0x07DF], "messages": 4, "voices": ["D1033.OGG"]},
	2: {"boundaries": [0x0832, 0x0862, 0x08B1, 0x0925], "messages": 8, "voices": ["D1034.OGG"]},
	3: {"boundaries": [0x09A4, 0x0A06], "messages": 4, "voices": ["D1033.OGG"]},
}


func _initialize() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() != 1:
		_fail("Usage: <mes.arc>")
		return
	var archive_path := ProjectSettings.globalize_path(str(arguments[0]))
	var reader := ArcReaderScript.new()
	if not reader.open(archive_path):
		_fail("mes.arc rejected: %s" % reader.last_error)
		return
	var archive_sha := reader.get_archive_fingerprint()
	if reader.get_entry_fingerprint(SOURCE_ENTRY) != ENTRY_SHA256:
		reader.close()
		_fail("EVENTD08.MES hash does not match the audited original entry.")
		return
	var document := MesContainerScript.new().parse(
		reader.read_entry(SOURCE_ENTRY),
		{"archive": "mes.arc", "entry": SOURCE_ENTRY}
	)
	if not document.ok:
		reader.close()
		_fail("EVENTD08.MES parse failed: %s" % str(document.error))
		return
	var library_document := MesContainerScript.new().parse(
		reader.read_entry(LIBRARY_ENTRY),
		{"archive": "mes.arc", "entry": LIBRARY_ENTRY}
	)
	if not library_document.ok or int(library_document.header.entry_count) != 0:
		reader.close()
		_fail("LIBLARY.LIB parse failed.")
		return
	var library_index := MesLibraryIndexScript.new().build(
		library_document.bytecode,
		int(library_document.header.code_size)
	)
	if not library_index.ok:
		reader.close()
		_fail("LIBLARY.LIB index failed: %s" % str(library_index.error))
		return

	var failures: Array[String] = []
	var library_reports: Array[String] = []
	for selection in range(1, 4):
		_validate_route(document, library_document, library_index, selection, failures, library_reports)
	if reader.get_archive_fingerprint() != archive_sha:
		failures.append("Source mes.arc changed during EVENTD08 route validation.")
	reader.close()
	if not failures.is_empty():
		_fail("; ".join(failures))
		return
	print(
		"PASS: EVENTD08 choices 1/2/3 reach 2/4/2 dialogue boundaries, 4/8/4 messages, D1033/D1034/D1033 voices, then shared routine 28 at 0xA25; library=%s; sandbox changed only by the route's own global_i32[1] argument; source archive unchanged" % " | ".join(library_reports)
	)
	quit(0)


func _validate_route(
	document: Dictionary,
	library_document: Dictionary,
	library_index: Dictionary,
	selection: int,
	failures: Array[String],
	library_reports: Array[String]
) -> void:
	var expected: Dictionary = EXPECTED[selection]
	var sandbox := SandboxStateScript.new(1)
	sandbox.write_value("state_u16", 21, selection)
	var initial := sandbox.snapshot()
	var cursor := RESUME_OFFSET
	var context := {}
	var dialogue_boundaries: Array[int] = []
	var message_count := 0
	var voice_names: Array[String] = []
	var final_result := {}
	for _boundary_index in range(MAX_BOUNDARIES):
		var result := MesEventRunnerScript.new().run(
			document.bytecode,
			cursor,
			sandbox,
			int(document.header.code_size),
			MesEventRunnerScript.DEFAULT_MAX_STEPS,
			context
		)
		final_result = result
		message_count += result.messages.size()
		for record in result.trace:
			if str(record.get("effect", "")) == "voice_marker":
				voice_names.append(str(record.resource_name))
		if str(result.status) != "dialogue_boundary":
			break
		dialogue_boundaries.append(int(result.offset))
		cursor = int(result.resume_offset)
		context = {"argument_slots": result.get("argument_slots", {}).duplicate(true)}
	if dialogue_boundaries != expected.boundaries:
		failures.append("choice %d dialogue boundaries differ: %s" % [selection, str(dialogue_boundaries)])
	if message_count != int(expected.messages):
		failures.append("choice %d message count differs: %d" % [selection, message_count])
	if voice_names != expected.voices:
		failures.append("choice %d voice markers differ: %s" % [selection, str(voice_names)])
	if (
		str(final_result.get("status", "")) != "shared_routine_boundary"
		or int(final_result.get("offset", -1)) != SHARED_ROUTINE_OFFSET
		or final_result.get("trace", []).is_empty()
		or int(final_result.trace[-1].get("routine_id", -1)) != SHARED_ROUTINE_ID
	):
		failures.append("choice %d did not stop at shared routine 28 / 0xA25" % selection)
	if _diff_signature(sandbox.diff(initial)) != EXPECTED_ROUTE_DIFF:
		failures.append("choice %d sandbox change after its projected selection differs: %s" % [selection, _diff_signature(sandbox.diff(initial))])
	var library_result := MesLibraryRunnerScript.new().run(
		library_document.bytecode,
		library_index,
		SHARED_ROUTINE_ID,
		sandbox,
		{
			"argument_slots": final_result.get("argument_slots", {}).duplicate(true),
			"persistent_expression_stack": final_result.get("persistent_expression_stack", []).duplicate(),
		}
	)
	if not library_result.ok or str(library_result.status) != "library_return":
		failures.append("choice %d routine 28 stopped: %s %s" % [selection, str(library_result.status), str(library_result.get("error", ""))])
		return
	var baseline := "%d/%s/%d/%s/%s" % [
		(library_result.trace as Array).size(),
		_call_signature(library_result.calls),
		int(library_result.omitted_native_presentation_count),
		_diff_signature(library_result.state_diff),
		str(library_result.persistent_expression_stack),
	]
	if baseline != EXPECTED_ROUTINE_28_BASELINE:
		failures.append("choice %d routine 28 bounded baseline differs: %s" % [selection, baseline])
		return
	var post_library := _resume_after_library(document, library_document, library_index, final_result, library_result, sandbox)
	if post_library != EXPECTED_POST_LIBRARY:
		failures.append("choice %d post-library boundary differs: %s" % [selection, post_library])
		return
	library_reports.append(
		"choice%d steps=%d calls=%s omitted=%d diff=%s stack=%s post=%s"
		% [
			selection,
			(library_result.trace as Array).size(),
			_call_signature(library_result.calls),
			int(library_result.omitted_native_presentation_count),
			_diff_signature(library_result.state_diff),
			str(library_result.persistent_expression_stack),
			post_library,
		]
	)


func _resume_after_library(
	document: Dictionary,
	library_document: Dictionary,
	library_index: Dictionary,
	caller_boundary: Dictionary,
	library_result: Dictionary,
	sandbox: KakyuMesSandboxState
) -> String:
	var cursor := int(caller_boundary.get("resume_offset", -1))
	if cursor < 0:
		return "missing_resume"
	var context := {
		"argument_slots": library_result.get("argument_slots", {}).duplicate(true),
		"persistent_expression_stack": library_result.get("persistent_expression_stack", []).duplicate(),
	}
	var dialogue_count := 0
	var message_count := 0
	var library_summaries: Array[String] = []
	for _boundary_index in range(MAX_BOUNDARIES):
		var result := MesEventRunnerScript.new().run(
			document.bytecode,
			cursor,
			sandbox,
			int(document.header.code_size),
			MesEventRunnerScript.DEFAULT_MAX_STEPS,
			context
		)
		message_count += result.messages.size()
		if str(result.status) == "dialogue_boundary":
			dialogue_count += 1
			cursor = int(result.resume_offset)
			context = {
				"argument_slots": result.get("argument_slots", {}).duplicate(true),
				"persistent_expression_stack": result.get("persistent_expression_stack", []).duplicate(),
			}
			continue
		if str(result.status) == "shared_routine_boundary" and not (result.trace as Array).is_empty():
			var routine_id := int(result.trace[-1].get("routine_id", -1))
			var nested_library := MesLibraryRunnerScript.new().run(
				library_document.bytecode,
				library_index,
				routine_id,
				sandbox,
				{
					"argument_slots": result.get("argument_slots", {}).duplicate(true),
					"persistent_expression_stack": result.get("persistent_expression_stack", []).duplicate(),
				}
			)
			if not nested_library.ok:
				return "library%d_%s@0x%X prior=%s stopped_steps=%d stopped_diff=%s" % [
					routine_id,
					str(nested_library.status),
					int(result.offset),
					",".join(library_summaries) if not library_summaries.is_empty() else "none",
					(nested_library.trace as Array).size(),
					_diff_signature(nested_library.state_diff),
				]
			library_summaries.append("%d:%d/%d/%d/%s" % [
				routine_id,
				(nested_library.trace as Array).size(),
				(nested_library.calls as Array).size(),
				int(nested_library.omitted_native_presentation_count),
				_diff_signature(nested_library.state_diff),
			])
			cursor = int(result.resume_offset)
			context = {
				"argument_slots": nested_library.get("argument_slots", {}).duplicate(true),
				"persistent_expression_stack": nested_library.get("persistent_expression_stack", []).duplicate(),
			}
			continue
		return "%s@0x%X dialogues=%d messages=%d libraries=%s" % [
			str(result.status),
			int(result.offset),
			dialogue_count,
			message_count,
			",".join(library_summaries) if not library_summaries.is_empty() else "none",
		]
	return "boundary_limit dialogues=%d messages=%d" % [dialogue_count, message_count]


func _call_signature(calls: Array) -> String:
	var parts: Array[String] = []
	for untyped_call in calls:
		parts.append(str(int((untyped_call as Dictionary).callee_routine_id)))
	return ",".join(parts) if not parts.is_empty() else "none"


func _diff_signature(diff: Array) -> String:
	var parts: Array[String] = []
	for untyped_change in diff:
		var change: Dictionary = untyped_change
		parts.append(
			"%s[%d:%d]=%d->%d"
			% [
				str(change.storage),
				int(change.bank),
				int(change.index),
				int(change.before),
				int(change.after),
			]
		)
	return ",".join(parts) if not parts.is_empty() else "none"
