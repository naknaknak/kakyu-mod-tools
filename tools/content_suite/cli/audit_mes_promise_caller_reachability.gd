extends SceneTree

const ArcReaderScript := preload("res://content_core/arc_reader.gd")
const MesContainerScript := preload("res://content_core/mes_container.gd")
const MesEventRunnerScript := preload("res://content_core/mes_event_runner.gd")
const LibraryIndexScript := preload("res://content_core/mes_library_index.gd")
const LibraryRunnerScript := preload("res://content_core/mes_library_runner.gd")
const ContextIndexScript := preload("res://content_core/mes_context_index.gd")
const SandboxStateScript := preload("res://content_core/mes_sandbox_state.gd")

const SCHEMA := "kakyu_mes_promise_caller_reachability_audit/v3"
const ARCHIVE_SHA256 := "31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6"
const EXPECTED_CALL_COUNT := 500
const EXPECTED_OWNER_COUNT := 146
# Core 0.316.0 (2026-09-13): the 140 zero-state "returns" this audit once
# recorded were the 00 that ends a message wait's record list, read as command
# 0x00 under the separator framing. Every owner now runs on to a real boundary
# - a DEF selection, a root handoff, another script's dispatch, a shared
# routine or a native record - and still none reaches its PROMIS call.
const EXPECTED_ZERO_STATE_STATUSES := {
	"def_selection_boundary": 41,
	"native_record_boundary": 1,
	"other_script_dispatch": 21,
	"script_handoff_boundary": 76,
	"shared_routine_boundary": 7,
}
const EXPECTED_LIBRARY_CONTINUATIONS := {
	21: 2,
	25: 2,
	27: 2,
}
# Core 0.377.0 (TD-56): 3,747 -> 3,877 (+130). Statuses, library continuations and
# the unreached PROMIS calls are unchanged; the extra rows are the library
# routines (21, 25, 27) reading the selector the owner's command 0x09 assigned
# (global_i32[1]) instead of the unwritten 0, which selects other rungs.
const EXPECTED_TRACE_STEPS := 3877
const EXPECTED_GATE_SEEDED_CASES := 499
const EXPECTED_GATE_SEEDED_STATUSES := {
	"def_selection_boundary": 184,
	"native_record_boundary": 1,
	"other_script_dispatch": 21,
	"script_handoff_boundary": 271,
	"shared_routine_boundary": 22,
}
# Core 0.377.0 (TD-56): 12,457 -> 12,587 (+130, the same library-path delta as the zero-state pass).
const EXPECTED_GATE_SEEDED_TRACE_STEPS := 12587
const COMPOSABLE_LIBRARY_ROUTINES := {
	21: true,
	25: true,
	27: true,
}
const GATE_BY_TARGET := {
	"A_PROMIS.MES": 1010,
	"B_PROMIS.MES": 598,
	"C_PROMIS.MES": 1669,
	"D_PROMIS.MES": 721,
	"E_PROMIS.MES": 1808,
	"F_PROMIS.MES": 1520,
	"G_PROMIS.MES": 1381,
	"H_PROMIS.MES": 2099,
	"I_PROMIS.MES": 1235,
	"J_PROMIS.MES": 803,
	"K_PROMIS.MES": 2200,
	"L_PROMIS.MES": 1941,
}
const MAX_SEGMENTS := 128
const MAX_STEPS_PER_SEGMENT := 4000
const PROMISE_SUFFIX := "_promis.mes"


func _init() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() != 1:
		push_error("Usage: audit_mes_promise_caller_reachability.gd <mes.arc>")
		quit(2)
		return
	var reader := ArcReaderScript.new()
	if not reader.open(str(arguments[0])):
		push_error(reader.last_error)
		quit(1)
		return
	var source_sha := reader.get_archive_fingerprint()
	if source_sha != ARCHIVE_SHA256:
		push_error("Unexpected original mes.arc SHA-256: %s" % source_sha)
		quit(1)
		return

	var parser := MesContainerScript.new()
	var library_document := parser.parse(reader.read_entry("LIBLARY.LIB"), {
		"archive": "mes.arc",
		"entry": "LIBLARY.LIB",
	})
	if not library_document.get("ok", false):
		push_error("LIBLARY.LIB could not be parsed")
		quit(1)
		return
	var library_index := LibraryIndexScript.new().build(
		library_document.bytecode,
		int(library_document.header.code_size)
	)
	if not library_index.get("ok", false):
		push_error("LIBLARY.LIB index could not be built")
		quit(1)
		return
	var def_document := parser.parse(reader.read_entry("DEF_MAIN.MES"), {
		"archive": "mes.arc",
		"entry": "DEF_MAIN.MES",
	})
	if not def_document.get("ok", false):
		push_error("DEF_MAIN.MES could not be parsed")
		quit(1)
		return
	var def_index := ContextIndexScript.new().build(def_document, [0x01FC])
	var def_matches: Array = def_index.get("by_id", {}).get(26, [])
	if def_matches.size() != 1:
		push_error("DEF_MAIN.MES selector-26 body could not be indexed")
		quit(1)
		return
	var def_registration: Dictionary = def_matches[0]
	var registered_definitions := {26: {
		"code": def_document.bytecode,
		"body_offset": int(def_registration.body_offset),
		"end_offset": int(def_registration.skip_target),
		"source": "DEF_MAIN.MES:0x1FC",
	}}
	var owners := {}
	var call_count := 0
	for entry in reader.get_entries():
		var entry_name := str(entry.name)
		if entry_name.get_extension().to_lower() != "mes":
			continue
		var document := parser.parse(reader.read_entry(entry_name), {
			"archive": "mes.arc",
			"entry": entry_name,
		})
		if not document.get("ok", false):
			push_error("%s could not be parsed: %s" % [entry_name, str(document.get("error", "unknown"))])
			quit(1)
			return
		var calls := _find_promise_calls(document.bytecode, document.header.entry_offsets)
		call_count += calls.size()
		for call in calls:
			var key := "%s#%d" % [entry_name, int(call.owner_entry_index)]
			if not owners.has(key):
				owners[key] = {
					"entry": entry_name,
					"entry_sha256": str(document.entry_sha256),
					"owner_entry_index": int(call.owner_entry_index),
					"owner_entry_offset": int(call.owner_entry_offset),
					"code": document.bytecode,
					"code_size": int(document.header.code_size),
					"address_table_offsets": document.header.entry_offsets.duplicate(),
					"calls": [],
				}
			owners[key].calls.append(call)
	if call_count != EXPECTED_CALL_COUNT or owners.size() != EXPECTED_OWNER_COUNT:
		push_error("PROMIS call corpus changed: calls=%d owners=%d" % [call_count, owners.size()])
		quit(1)
		return

	var status_counts := {}
	var target_hits := {}
	var reached: Array[String] = []
	var boundary_samples: Array[String] = []
	var total_dialogues := 0
	var total_trace_steps := 0
	var library_continuations := {}
	for key in owners:
		var owner: Dictionary = owners[key]
		var result := _run_owner(owner, library_document, library_index, registered_definitions, {})
		var status := str(result.status)
		status_counts[status] = int(status_counts.get(status, 0)) + 1
		total_dialogues += int(result.dialogues)
		total_trace_steps += int(result.trace_steps)
		for routine_id in result.get("library_continuations", {}):
			library_continuations[routine_id] = int(library_continuations.get(routine_id, 0)) + int(result.library_continuations[routine_id])
		if result.get("reached", false):
			var target := str(result.target_entry).to_upper()
			target_hits[target] = int(target_hits.get(target, 0)) + 1
			reached.append("%s#%04d:0x%X->%s@0x%X" % [
				str(owner.entry),
				int(owner.owner_entry_index),
				int(owner.owner_entry_offset),
				target,
				int(result.command_offset),
			])
		elif status != "script_return":
			boundary_samples.append("%s#%04d:0x%X status=%s stop=0x%X target=%s" % [
				str(owner.entry),
				int(owner.owner_entry_index),
				int(owner.owner_entry_offset),
				status,
				int(result.get("offset", -1)),
				str(result.get("target_entry", "-")),
			])

	var seeded_cases := 0
	var seeded_reached := 0
	var seeded_statuses := {}
	var seeded_targets := {}
	var seeded_dialogues := 0
	var seeded_trace_steps := 0
	var seeded_samples: Array[String] = []
	for key in owners:
		var owner: Dictionary = owners[key]
		var owner_targets := {}
		for call in owner.calls:
			owner_targets[str(call.target_entry)] = true
		for target in owner_targets:
			seeded_cases += 1
			var gate_index := int(GATE_BY_TARGET.get(target, -1))
			if gate_index < 0:
				push_error("Missing target gate for %s" % target)
				quit(1)
				return
			var result := _run_owner(
				owner,
				library_document,
				library_index,
				registered_definitions,
				{gate_index: 1}
			)
			seeded_dialogues += int(result.dialogues)
			seeded_trace_steps += int(result.trace_steps)
			if result.get("reached", false) and str(result.target_entry) == target:
				seeded_reached += 1
				seeded_targets[target] = int(seeded_targets.get(target, 0)) + 1
			else:
				var seeded_status := str(result.status)
				seeded_statuses[seeded_status] = int(seeded_statuses.get(seeded_status, 0)) + 1
				if seeded_samples.size() < 32:
					seeded_samples.append("%s#%04d target=%s gate=%d status=%s stop=0x%X actual=%s" % [
						str(owner.entry),
						int(owner.owner_entry_index),
						target,
						gate_index,
						seeded_status,
						int(result.get("offset", result.get("command_offset", -1))),
						str(result.get("target_entry", "-")),
					])

	if reader.get_archive_fingerprint() != source_sha:
		push_error("Original mes.arc changed during the read-only reachability audit")
		quit(1)
		return
	if (
		status_counts != EXPECTED_ZERO_STATE_STATUSES
		or library_continuations != EXPECTED_LIBRARY_CONTINUATIONS
		or total_trace_steps != EXPECTED_TRACE_STEPS
		or not reached.is_empty()
		or total_dialogues != 0
	):
		push_error("Zero-state PROMIS owner reachability changed: statuses=%s libraries=%s trace=%d reached=%d dialogues=%d" % [
			_format_counts(status_counts),
			_format_counts(library_continuations),
			total_trace_steps,
			reached.size(),
			total_dialogues,
		])
		quit(1)
		return
	if (
		seeded_cases != EXPECTED_GATE_SEEDED_CASES
		or seeded_statuses != EXPECTED_GATE_SEEDED_STATUSES
		or seeded_trace_steps != EXPECTED_GATE_SEEDED_TRACE_STEPS
		or seeded_reached != 0
		or not seeded_targets.is_empty()
		or seeded_dialogues != 0
	):
		push_error("Gate-seeded PROMIS owner reachability changed: cases=%d statuses=%s trace=%d reached=%d dialogues=%d" % [
			seeded_cases,
			_format_counts(seeded_statuses),
			seeded_trace_steps,
			seeded_reached,
			seeded_dialogues,
		])
		quit(1)
		return
	print("PROMISE_CALLER_REACHABILITY schema=%s calls=%d owners=%d reached=%d dialogues=%d libraries=%s trace_steps=%d statuses=%s targets=%s source_unchanged=true" % [
		SCHEMA,
		call_count,
		owners.size(),
		reached.size(),
		total_dialogues,
		_format_counts(library_continuations),
		total_trace_steps,
		_format_counts(status_counts),
		_format_counts(target_hits),
	])
	for sample in reached.slice(0, 24):
		print("PROMISE_CALLER_REACHABLE_SAMPLE %s" % sample)
	for sample in boundary_samples:
		print("PROMISE_CALLER_BOUNDARY_SAMPLE %s" % sample)
	print("PROMISE_GATE_REACHABILITY cases=%d reached=%d dialogues=%d trace_steps=%d targets=%s terminal_statuses=%s source_unchanged=true" % [
		seeded_cases,
		seeded_reached,
		seeded_dialogues,
		seeded_trace_steps,
		_format_counts(seeded_targets),
		_format_counts(seeded_statuses),
	])
	for sample in seeded_samples:
		print("PROMISE_GATE_BOUNDARY_SAMPLE %s" % sample)
	quit(0)


func _find_promise_calls(code: PackedByteArray, entry_offsets: Array) -> Array[Dictionary]:
	var calls: Array[Dictionary] = []
	var suffix_bytes := PROMISE_SUFFIX.to_ascii_buffer()
	var target_size := 1 + suffix_bytes.size()
	for string_offset in range(2, code.size() - target_size - 1):
		var initial := int(code[string_offset])
		if initial < 0x61 or initial > 0x6C:
			continue
		if not _matches(code, string_offset + 1, suffix_bytes):
			continue
		var command_offset := string_offset - 2
		var resume_offset := string_offset + target_size + 2
		if (
			code[command_offset] != 0x0F
			or code[command_offset + 1] != 0x01
			or code[resume_offset - 2] != 0
			or code[resume_offset - 1] != 0
		):
			push_error("PROMIS name occurred outside an exact command-0x0F envelope")
			return []
		var owner_index := _owner_index(entry_offsets, command_offset)
		if owner_index < 0:
			push_error("PROMIS command-0x0F occurred in a bootstrap prefix")
			return []
		calls.append({
			"owner_entry_index": owner_index,
			"owner_entry_offset": int(entry_offsets[owner_index]),
			"command_offset": command_offset,
			"resume_offset": resume_offset,
			"target_entry": (String.chr(initial) + PROMISE_SUFFIX).to_upper(),
		})
	return calls


func _run_owner(
	owner: Dictionary,
	library_document: Dictionary,
	library_index: Dictionary,
	registered_definitions: Dictionary,
	initial_global_u8: Dictionary
) -> Dictionary:
	var runner := MesEventRunnerScript.new()
	var state := SandboxStateScript.new(1)
	for index in initial_global_u8:
		state.write_value("global_u8", int(index), int(initial_global_u8[index]))
	var cursor := int(owner.owner_entry_offset)
	var context := {
		"address_table_offsets": owner.address_table_offsets.duplicate(),
		"protagonist_name": "Audit",
		"native_stream_policy": "skip_bounded",
	}
	var dialogues := 0
	var trace_steps := 0
	var library_continuations := {}
	for _segment in range(MAX_SEGMENTS):
		var result := runner.run(
			owner.code,
			cursor,
			state,
			int(owner.code_size),
			MAX_STEPS_PER_SEGMENT,
			context
		)
		trace_steps += (result.get("trace", []) as Array).size()
		var status := str(result.get("status", "unknown"))
		if status == "dialogue_boundary":
			dialogues += 1
			cursor = int(result.get("resume_offset", -1))
			if cursor < 0:
				return _owner_result("dialogue_without_resume", dialogues, trace_steps, -1, "", library_continuations)
			context = _continuation_context(owner, result)
			continue
		if status == "script_dispatch_boundary":
			var trace: Array = result.get("trace", [])
			var target := str(trace[-1].get("target_entry", "")).to_upper() if not trace.is_empty() else ""
			var command_offset := int(result.get("offset", -1))
			for call in owner.calls:
				if int(call.command_offset) == command_offset and str(call.target_entry) == target:
					return {
						"status": "promise_dispatch",
						"reached": true,
						"target_entry": target,
						"command_offset": command_offset,
						"dialogues": dialogues,
						"trace_steps": trace_steps,
						"library_continuations": library_continuations,
					}
			return _owner_result("other_script_dispatch", dialogues, trace_steps, command_offset, target, library_continuations)
		if status == "shared_routine_boundary":
			var trace: Array = result.get("trace", [])
			var routine_id := int(trace[-1].get("routine_id", -1)) if not trace.is_empty() else -1
			if COMPOSABLE_LIBRARY_ROUTINES.has(routine_id):
				var library_result := LibraryRunnerScript.new().run(
					library_document.bytecode,
					library_index,
					routine_id,
					state,
					{
						"argument_slots": result.get("argument_slots", {}).duplicate(true),
						"persistent_expression_stack": result.get("persistent_expression_stack", []).duplicate(),
						"registered_definitions": registered_definitions,
					}
				)
				trace_steps += (library_result.get("trace", []) as Array).size()
				if not library_result.get("ok", false) or str(library_result.get("status", "")) != "library_return":
					return _owner_result("routine%d_%s" % [routine_id, str(library_result.get("status", "stop"))], dialogues, trace_steps, int(result.get("offset", -1)), str(routine_id), library_continuations)
				library_continuations[routine_id] = int(library_continuations.get(routine_id, 0)) + 1
				cursor = int(result.get("resume_offset", -1))
				if cursor < 0:
					return _owner_result("routine%d_without_resume" % routine_id, dialogues, trace_steps, int(result.get("offset", -1)), str(routine_id), library_continuations)
				context = _carry_context(
					owner,
					library_result.get("argument_slots", {}),
					library_result.get("persistent_expression_stack", [])
				)
				continue
		var trace: Array = result.get("trace", [])
		var target := ""
		if not trace.is_empty():
			target = str(trace[-1].get("target_entry", trace[-1].get("routine_id", "")))
		return _owner_result(status, dialogues, trace_steps, int(result.get("offset", -1)), target, library_continuations)
	return _owner_result("segment_limit", dialogues, trace_steps, -1, "", library_continuations)


func _continuation_context(owner: Dictionary, result: Dictionary) -> Dictionary:
	return _carry_context(
		owner,
		result.get("argument_slots", {}),
		result.get("persistent_expression_stack", [])
	)


func _carry_context(owner: Dictionary, argument_slots: Dictionary, expression_stack: Array) -> Dictionary:
	return {
		"address_table_offsets": owner.address_table_offsets.duplicate(),
		"protagonist_name": "Audit",
		"native_stream_policy": "skip_bounded",
		"argument_slots": argument_slots.duplicate(true),
		"persistent_expression_stack": expression_stack.duplicate(),
	}


func _owner_result(
	status: String,
	dialogues: int,
	trace_steps: int,
	offset: int,
	target_entry: String,
	library_continuations: Dictionary
) -> Dictionary:
	return {
		"status": status,
		"reached": false,
		"dialogues": dialogues,
		"trace_steps": trace_steps,
		"offset": offset,
		"target_entry": target_entry,
		"library_continuations": library_continuations.duplicate(),
	}


func _matches(code: PackedByteArray, offset: int, needle: PackedByteArray) -> bool:
	if offset < 0 or offset + needle.size() > code.size():
		return false
	for index in range(needle.size()):
		if code[offset + index] != needle[index]:
			return false
	return true


func _owner_index(entry_offsets: Array, coordinate: int) -> int:
	var owner := -1
	for index in range(entry_offsets.size()):
		if int(entry_offsets[index]) > coordinate:
			break
		owner = index
	return owner


func _format_counts(counts: Dictionary) -> String:
	var keys := counts.keys()
	keys.sort()
	var parts: Array[String] = []
	for key in keys:
		parts.append("%s:%d" % [str(key), int(counts[key])])
	return ",".join(parts) if not parts.is_empty() else "none"
