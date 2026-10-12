extends SceneTree

const ArcReaderScript := preload("res://content_core/arc_reader.gd")
const MesContainerScript := preload("res://content_core/mes_container.gd")
const ScriptCallRunnerScript := preload("res://content_core/mes_script_call_runner.gd")
const SandboxStateScript := preload("res://content_core/mes_sandbox_state.gd")

const SCHEMA := "kakyu_mes_promise_nested_call_audit/v1"
const ARCHIVE_SHA256 := "31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6"
const SOURCE_HASHES := {
	"44C.MES": "49b5ae569923d6b0e58bf6bf64786f2e96fe9de00c9bad56cd450cb4a487d0ce",
	"L_HOTEL2.MES": "5ed3ba5238949f180a8da82961df9d9fe6b8bf818dbc7cf464c84ac38de85e49",
	"L_TALK30.MES": "c66e0b8ecfbf86d5022885033b4737d8e672c87ae352f39c4d03557220956a54",
}
const CASES := [
	{
		"entry": "44C.MES",
		"owner_index": 376,
		"intro": 0xC52A,
		"talk_call": 0xC593,
		"talk_resume": 0xC5A3,
		"promise_gate": 0xC6DC,
		"promise_call": 0xC6EC,
		"promise_resume": 0xC6FC,
		"trace_count": 164,
		"argument_1": 10152,
	},
	{
		"entry": "L_HOTEL2.MES",
		"owner_index": 142,
		"intro": 0x421C,
		"talk_call": 0x4292,
		"talk_resume": 0x42A2,
		"promise_gate": 0x43DB,
		"promise_call": 0x43EB,
		"promise_resume": 0x43FB,
		"trace_count": 166,
		"argument_1": 106289,
	},
]
const CHOICES := {
	0: {"body": 0x276, "target": 0x285, "return": 0x284},
	1: {"body": 0x2B1, "target": 0x2C2, "return": 0x2C1},
}


func _init() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() != 1:
		push_error("Usage: audit_mes_promise_nested_calls.gd <mes.arc>")
		quit(2)
		return
	var reader := ArcReaderScript.new()
	if not reader.open(str(arguments[0])):
		_fail(reader, reader.last_error)
		return
	var source_sha := reader.get_archive_fingerprint()
	if source_sha != ARCHIVE_SHA256:
		_fail(reader, "Unexpected original mes.arc SHA-256: %s" % source_sha)
		return

	var scripts := {}
	var parser := MesContainerScript.new()
	for entry_name in SOURCE_HASHES:
		if reader.get_entry_fingerprint(entry_name) != str(SOURCE_HASHES[entry_name]):
			_fail(reader, "%s hash does not match the audited original entry." % entry_name)
			return
		var document := parser.parse(reader.read_entry(entry_name), {
			"archive": "mes.arc",
			"entry": entry_name,
		})
		if not document.get("ok", false):
			_fail(reader, "%s could not be parsed: %s" % [entry_name, str(document.get("error", "unknown"))])
			return
		scripts[entry_name] = document
	for case in CASES:
		var root_document: Dictionary = scripts[str(case.entry)]
		var offsets: Array = root_document.header.entry_offsets
		if (
			int(case.owner_index) < 0
			or int(case.owner_index) >= offsets.size()
			or int(offsets[int(case.owner_index)]) != int(case.intro)
		):
			_fail(reader, "%s owner address-table coordinate changed." % str(case.entry))
			return

	var reports: Array[String] = []
	var total_trace := 0
	var total_messages := 0
	for case in CASES:
		for choice_id in CHOICES:
			var state := SandboxStateScript.new(1)
			state.write_value("banked_u16", 209, 21, 0)
			state.write_value("global_u8", 1941, 1)
			var result := ScriptCallRunnerScript.new().run(
				scripts,
				str(case.entry),
				int(case.intro),
				state,
				{
					"dialogue_policy": "continue",
					"native_stream_policy": "skip_bounded",
					"local_definition_choices": [choice_id],
					"protagonist_name": "Audit",
				},
				20000,
				32,
				8
			)
			var error := _validate_case(case, int(choice_id), result, state)
			if not error.is_empty():
				_fail(reader, error)
				return
			total_trace += (result.trace as Array).size()
			total_messages += (result.messages as Array).size()
			reports.append("%s#%d:0x%X->L_TALK30.MES->L_PROMIS.MES@0x%X" % [
				str(case.entry),
				int(choice_id),
				int(case.intro),
				int(case.promise_call),
			])

	if reader.get_archive_fingerprint() != source_sha:
		_fail(reader, "Original mes.arc changed during the read-only nested-call audit.")
		return
	for entry_name in SOURCE_HASHES:
		if reader.get_entry_fingerprint(entry_name) != str(SOURCE_HASHES[entry_name]):
			_fail(reader, "%s changed during the read-only nested-call audit." % entry_name)
			return
	reader.close()
	if total_trace != 660 or total_messages != 8:
		push_error("Nested-call aggregate changed: trace=%d messages=%d" % [total_trace, total_messages])
		quit(1)
		return
	print("MES_PROMISE_NESTED_CALLS schema=%s cases=%d trace=%d messages=%d choices=explicit_tool_input native_selection=unresolved routes=%s source_unchanged=true" % [
		SCHEMA,
		reports.size(),
		total_trace,
		total_messages,
		" | ".join(reports),
	])
	quit(0)


func _validate_case(case: Dictionary, choice_id: int, result: Dictionary, state: RefCounted) -> String:
	if (
		result.get("ok", true)
		or str(result.get("schema", "")) != "kakyu_mes_script_call_trace/v3"
		or str(result.get("status", "")) != "script_dispatch_boundary"
		or str(result.get("current_entry", "")) != str(case.entry)
		or int(result.get("offset", -1)) != int(case.promise_call)
		or int(result.get("resume_offset", -1)) != int(case.promise_resume)
		or (result.get("trace", []) as Array).size() != int(case.trace_count)
		or (result.get("messages", []) as Array).size() != 2
		or int(result.get("dialogue_boundary_count", -1)) != 0
		# Core 0.316.0 (2026-09-13): the one "omitted native presentation" was
		# the message wait's record list skipped as a bounded stream; the wait
		# is executed as a cursor no-advance now and nothing on this route is
		# omitted.
		or int(result.get("omitted_native_presentation_count", -1)) != 0
		or not (result.get("definitions", []) as Array).is_empty()
	):
		return "%s choice %d terminal result changed." % [str(case.entry), choice_id]
	var calls: Array = result.get("script_calls", [])
	if calls.size() != 1:
		return "%s choice %d nested-call count changed." % [str(case.entry), choice_id]
	var call: Dictionary = calls[0]
	if (
		str(call.get("caller_entry", "")) != str(case.entry)
		or str(call.get("callee_entry", "")) != "L_TALK30.MES"
		or int(call.get("call_depth", -1)) != 1
		or int(call.get("call_offset", -1)) != int(case.talk_call)
		or int(call.get("resume_offset", -1)) != int(case.talk_resume)
		or int(call.get("return_offset", -1)) != int(CHOICES[choice_id].get("return", -1))
		or not call.get("returned", false)
	):
		return "%s choice %d caller restoration changed." % [str(case.entry), choice_id]
	var trace: Array = result.get("trace", [])
	var selection := _trace_at(trace, "L_TALK30.MES", 0x561)
	if (
		selection.is_empty()
		or str(selection.get("effect", "")) != "def_selection_boundary"
		or str(selection.get("selection_policy", "")) != "explicit_tool_choice"
		or int(selection.get("selected_definition_id", -1)) != choice_id
		or int(selection.get("selected_definition_body_offset", -1)) != int(CHOICES[choice_id].body)
		or int(selection.get("selected_definition_target_offset", -1)) != int(CHOICES[choice_id].target)
	):
		return "%s choice %d explicit local selection changed." % [str(case.entry), choice_id]
	var promise_gate := _trace_at(trace, str(case.entry), int(case.promise_gate))
	var promise_call := _trace_at(trace, str(case.entry), int(case.promise_call))
	if (
		promise_gate.is_empty()
		or int(promise_gate.get("command_id", -1)) != 0x0B
		or int(promise_gate.get("condition_value", -1)) != 1
		or str(promise_gate.get("effect", "")) != "fallthrough"
		or promise_call.is_empty()
		or str(promise_call.get("effect", "")) != "script_dispatch_boundary"
		or str(promise_call.get("target_entry", "")).to_upper() != "L_PROMIS.MES"
	):
		return "%s choice %d PROMIS gate/call changed." % [str(case.entry), choice_id]
	var differences: Array = result.get("state_diff", [])
	# Core 0.377.0 (TD-56): the route's command-0x09 argument assignments land in
	# global_i32, and the last one, `argument_1` (the message record id the
	# L_TALK30 conversation leaves in index 1), survives the nested frame's
	# return. The global_u8 write is the unchanged one.
	var expected_differences: Array = [
		{"storage": "global_i32", "bank": 0, "index": 1, "before": 0, "after": int(case.argument_1)},
		{"storage": "global_u8", "bank": 0, "index": 2006, "before": 0, "after": 1},
	]
	if (
		differences != expected_differences
		or int(state.call("read_value", "banked_u16", 209, 0)) != 21
		or int(state.call("read_value", "global_u8", 1941, 0)) != 1
	):
		return "%s choice %d isolated state result changed: %s" % [str(case.entry), choice_id, JSON.stringify(differences)]
	return ""


func _trace_at(trace: Array, entry_name: String, offset: int) -> Dictionary:
	for untyped_record in trace:
		var record: Dictionary = untyped_record
		if str(record.get("source_entry", "")) == entry_name and int(record.get("source_offset", -1)) == offset:
			return record
	return {}


func _fail(reader: RefCounted, message: String) -> void:
	reader.call("close")
	push_error(message)
	quit(1)
