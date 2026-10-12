class_name KakyuMesScriptCallRunner
extends RefCounted

const EventRunnerScript := preload("res://content_core/mes_event_runner.gd")
const InstructionDecoderScript := preload("res://content_core/mes_instruction_decoder.gd")
const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")
const ContractValues := preload("res://content_core/contract_values.gd")

const DEFAULT_MAX_STEPS := 10000
const DEFAULT_MAX_SCRIPT_CALLS := 64
const DEFAULT_MAX_SCRIPT_DEPTH := 16

var _runner := EventRunnerScript.new()


func resume(
	scripts: Dictionary,
	continuation: Dictionary,
	state: KakyuMesSandboxState,
	context_override := {},
	max_steps := DEFAULT_MAX_STEPS,
	max_script_calls := DEFAULT_MAX_SCRIPT_CALLS,
	max_script_depth := DEFAULT_MAX_SCRIPT_DEPTH
) -> Dictionary:
	if str(continuation.get("schema", "")) != ContentCoreVersionScript.MES_SCRIPT_CALL_CONTINUATION_SCHEMA:
		return _result("invalid_continuation", false, "", -1, [], [], [], [], {}, [], 0, 0, "Nested MES continuation schema is unsupported.")
	if not context_override is Dictionary:
		return _result("invalid_continuation", false, "", -1, [], [], [], [], {}, [], 0, 0, "Nested MES continuation override must be a dictionary.")
	var runner_context_value = continuation.get("runner_context", {})
	if not runner_context_value is Dictionary:
		return _result("invalid_continuation", false, "", -1, [], [], [], [], {}, [], 0, 0, "Nested MES continuation has no valid runner context.")
	var runner_context: Dictionary = runner_context_value.duplicate(true)
	for untyped_key in context_override:
		var key := str(untyped_key)
		if key not in ["dialogue_policy", "native_stream_policy", "protagonist_name", "local_definition_choices"]:
			return _result("invalid_continuation", false, "", -1, [], [], [], [], {}, [], 0, 0, "Nested MES continuation override is unsupported: %s" % key)
		runner_context[key] = context_override[untyped_key]
	runner_context["_script_call_continuation"] = continuation.duplicate(true)
	return run(
		scripts,
		str(continuation.get("root_entry", "")),
		0,
		state,
		runner_context,
		max_steps,
		max_script_calls,
		max_script_depth
	)


func run(
	scripts: Dictionary,
	root_entry: String,
	start_offset: int,
	state: KakyuMesSandboxState,
	context := {},
	max_steps := DEFAULT_MAX_STEPS,
	max_script_calls := DEFAULT_MAX_SCRIPT_CALLS,
	max_script_depth := DEFAULT_MAX_SCRIPT_DEPTH
) -> Dictionary:
	var before := state.snapshot()
	var normalized := _normalize_scripts(scripts)
	if not normalized.ok:
		return _result("invalid_scripts", false, root_entry, start_offset, [], [], [], state.diff(before), {}, [], 0, 0, str(normalized.error))
	var script_map: Dictionary = normalized.scripts
	var script_bindings := _script_bindings(script_map)
	var root := root_entry.to_upper()
	if not script_map.has(root):
		return _result("missing_root", false, root, start_offset, [], [], [], state.diff(before), {}, [], 0, 0, "Root MES entry is absent from the explicit script map.")
	if max_steps <= 0 or max_script_calls <= 0 or max_script_depth <= 0:
		return _result("invalid_limits", false, root, start_offset, [], [], [], state.diff(before), {}, [], 0, 0, "Step, script-call, and call-depth limits must be positive.")
	var native_stream_policy := str(context.get("native_stream_policy", "stop"))
	var dialogue_policy := str(context.get("dialogue_policy", "stop"))
	if native_stream_policy not in ["stop", "skip_bounded"] or dialogue_policy not in ["stop", "continue"]:
		return _result("invalid_policy", false, root, start_offset, [], [], [], state.diff(before), {}, [], 0, 0, "Nested-script presentation policy is invalid.")
	var local_choice_value = context.get("local_definition_choices", [])
	if not local_choice_value is Array:
		return _result("invalid_context", false, root, start_offset, [], [], [], state.diff(before), {}, [], 0, 0, "Local definition choices must be an array of non-negative integer IDs.")
	var local_definition_choices: Array[int] = []
	for untyped_choice in local_choice_value:
		if typeof(untyped_choice) != TYPE_INT or int(untyped_choice) < 0:
			return _result("invalid_context", false, root, start_offset, [], [], [], state.diff(before), {}, [], 0, 0, "Local definition choices must be an array of non-negative integer IDs.")
		local_definition_choices.append(int(untyped_choice))
	var local_choice_index := int(context.get("_local_choice_index", 0))
	if local_choice_index < 0 or local_choice_index > local_definition_choices.size():
		return _result("invalid_context", false, root, start_offset, [], [], [], state.diff(before), {}, [], 0, 0, "Local definition choice cursor is invalid.")
	var protagonist_name := str(context.get("protagonist_name", ""))
	var argument_slots: Dictionary = context.get("argument_slots", {}).duplicate(true)
	var expression_stack: Array[int] = []
	for untyped_value in context.get("persistent_expression_stack", []):
		expression_stack.append(int(untyped_value))
	var trace: Array[Dictionary] = []
	var messages: Array[Dictionary] = []
	var calls: Array[Dictionary] = []
	var frames: Array[Dictionary] = []
	var omitted_native_presentations := 0
	var dialogue_boundaries := 0
	var current_entry := root
	var cursor := start_offset
	var continuation_value = context.get("_script_call_continuation", {})
	if continuation_value is Dictionary and not (continuation_value as Dictionary).is_empty():
		var restored := _restore_continuation(continuation_value, script_map, script_bindings)
		if not restored.get("ok", false):
			return _result("invalid_continuation", false, root, start_offset, [], [], [], state.diff(before), argument_slots, expression_stack, 0, 0, str(restored.get("error", "Nested MES continuation is invalid.")))
		current_entry = str(restored.current_entry)
		cursor = int(restored.cursor)
		calls.assign(restored.calls)
		frames.assign(restored.frames)
		argument_slots = restored.argument_slots.duplicate(true)
		expression_stack.assign(restored.persistent_expression_stack)
		omitted_native_presentations = int(restored.omitted_native_presentation_count)
		dialogue_boundaries = int(restored.dialogue_boundary_count)
		local_choice_index = int(restored.local_choice_index)
		if calls.size() > max_script_calls or frames.size() > max_script_depth:
			return _result("invalid_continuation", false, current_entry, cursor, [], [], calls, state.diff(before), argument_slots, expression_stack, omitted_native_presentations, dialogue_boundaries, "Nested MES continuation exceeds the requested call or depth limit.")
	elif continuation_value != null and (not continuation_value is Dictionary or not (continuation_value as Dictionary).is_empty()):
		return _result("invalid_continuation", false, root, start_offset, [], [], [], state.diff(before), argument_slots, expression_stack, 0, 0, "Nested MES continuation must be a dictionary.")
	var current_script: Dictionary = script_map[current_entry]
	if cursor < 0 or cursor >= int(current_script.code_size):
		return _result("invalid_start", false, current_entry, cursor, [], [], calls, state.diff(before), argument_slots, expression_stack, omitted_native_presentations, dialogue_boundaries, "MES start or resume offset is outside the code range.")
	while trace.size() < max_steps:
		var script: Dictionary = script_map[current_entry]
		var runner_context := {
			"argument_slots": argument_slots,
			"persistent_expression_stack": expression_stack,
			"native_stream_policy": native_stream_policy,
			"protagonist_name": protagonist_name,
		}
		if not (script.address_table_offsets as Array).is_empty():
			runner_context["address_table_offsets"] = script.address_table_offsets
		var segment := _runner.run(
			script.code,
			cursor,
			state,
			int(script.code_size),
			max_steps - trace.size(),
			runner_context
		)
		for untyped_record in segment.get("trace", []):
			var record: Dictionary = untyped_record.duplicate(true)
			record["step"] = trace.size()
			record["source_entry"] = current_entry
			record["script_call_depth"] = frames.size()
			if _is_native_presentation_omission(record):
				omitted_native_presentations += 1
			trace.append(record)
		for untyped_message in segment.get("messages", []):
			var message: Dictionary = (untyped_message as Dictionary).duplicate(true)
			message["source_entry"] = current_entry
			message["script_call_depth"] = frames.size()
			messages.append(message)
		argument_slots = segment.get("argument_slots", argument_slots).duplicate(true)
		var next_stack: Array = segment.get("persistent_expression_stack", expression_stack.duplicate())
		expression_stack.clear()
		for untyped_value in next_stack:
			expression_stack.append(int(untyped_value))
		var status := str(segment.get("status", "unknown"))

		if status == "dialogue_boundary" and dialogue_policy == "continue":
			dialogue_boundaries += 1
			var dialogue_resume := int(segment.get("resume_offset", -1))
			if dialogue_resume <= cursor or dialogue_resume > int(script.code_size):
				return _result("invalid_dialogue_resume", false, current_entry, int(segment.get("offset", cursor)), trace, messages, calls, state.diff(before), argument_slots, expression_stack, omitted_native_presentations, dialogue_boundaries, "Dialogue resume coordinate is invalid.")
			cursor = dialogue_resume
			continue

		if status == "def_selection_boundary" and local_choice_index < local_definition_choices.size():
			var selected_id := local_definition_choices[local_choice_index]
			var selected_definition := {}
			for untyped_definition in segment.get("definitions", []):
				var definition: Dictionary = untyped_definition
				if int(definition.get("definition_id", -1)) == selected_id:
					selected_definition = definition
					break
			if selected_definition.is_empty():
				var invalid_choice := _terminal_result(segment, current_entry, trace, messages, calls, frames, state.diff(before), argument_slots, expression_stack, omitted_native_presentations, dialogue_boundaries)
				invalid_choice["ok"] = false
				invalid_choice["status"] = "invalid_definition_choice"
				invalid_choice["error"] = "Explicit local definition ID %d is absent from this selection boundary." % selected_id
				return invalid_choice
			var body_offset := int(selected_definition.get("body_offset", -1))
			var target_offset := int(selected_definition.get("target_offset", -1))
			if body_offset < 0 or body_offset >= target_offset or target_offset > int(script.code_size):
				var invalid_body := _terminal_result(segment, current_entry, trace, messages, calls, frames, state.diff(before), argument_slots, expression_stack, omitted_native_presentations, dialogue_boundaries)
				invalid_body["ok"] = false
				invalid_body["status"] = "invalid_definition_body"
				invalid_body["error"] = "Explicit local definition has an invalid bounded body."
				return invalid_body
			if not trace.is_empty():
				trace[-1]["selection_policy"] = "explicit_tool_choice"
				trace[-1]["selected_definition_id"] = selected_id
				trace[-1]["selected_definition_body_offset"] = body_offset
				trace[-1]["selected_definition_target_offset"] = target_offset
			cursor = body_offset
			local_choice_index += 1
			continue

		if status == "script_dispatch_boundary":
			var segment_trace: Array = segment.get("trace", [])
			var target_entry := str(segment_trace[-1].get("target_entry", "")).to_upper() if not segment_trace.is_empty() else ""
			if not script_map.has(target_entry):
				return _terminal_result(segment, current_entry, trace, messages, calls, frames, state.diff(before), argument_slots, expression_stack, omitted_native_presentations, dialogue_boundaries)
			if calls.size() >= max_script_calls:
				return _result("script_call_limit", false, current_entry, int(segment.get("offset", cursor)), trace, messages, calls, state.diff(before), argument_slots, expression_stack, omitted_native_presentations, dialogue_boundaries, "Nested MES call count exceeded its limit.")
			if frames.size() >= max_script_depth:
				return _result("script_call_depth_limit", false, current_entry, int(segment.get("offset", cursor)), trace, messages, calls, state.diff(before), argument_slots, expression_stack, omitted_native_presentations, dialogue_boundaries, "Nested MES call depth exceeded its limit.")
			var resume_offset := int(segment.get("resume_offset", -1))
			if resume_offset <= cursor or resume_offset > int(script.code_size):
				return _result("invalid_script_resume", false, current_entry, int(segment.get("offset", cursor)), trace, messages, calls, state.diff(before), argument_slots, expression_stack, omitted_native_presentations, dialogue_boundaries, "Nested MES caller resume coordinate is invalid.")
			var call_index := calls.size()
			calls.append({
				"caller_entry": current_entry,
				"callee_entry": target_entry,
				"call_depth": frames.size() + 1,
				"call_offset": int(segment.get("offset", cursor)),
				"resume_offset": resume_offset,
				"returned": false,
			})
			frames.append({
				"entry": current_entry,
				"cursor": resume_offset,
				"argument_slots": argument_slots.duplicate(true),
				"persistent_expression_stack": expression_stack.duplicate(),
				"call_index": call_index,
			})
			current_entry = target_entry
			cursor = 0
			argument_slots = {}
			expression_stack.clear()
			continue

		if status == "script_return" and not frames.is_empty():
			var caller: Dictionary = frames.pop_back()
			var call_index := int(caller.call_index)
			calls[call_index]["returned"] = true
			calls[call_index]["return_offset"] = int(segment.get("offset", -1))
			current_entry = str(caller.entry)
			cursor = int(caller.cursor)
			argument_slots = caller.argument_slots.duplicate(true)
			expression_stack.clear()
			for untyped_value in caller.persistent_expression_stack:
				expression_stack.append(int(untyped_value))
			continue

		if status == "script_return" and frames.is_empty():
			return _result("script_return", true, current_entry, int(segment.get("offset", cursor)), trace, messages, calls, state.diff(before), argument_slots, expression_stack, omitted_native_presentations, dialogue_boundaries)
		var terminal := _terminal_result(segment, current_entry, trace, messages, calls, frames, state.diff(before), argument_slots, expression_stack, omitted_native_presentations, dialogue_boundaries)
		if status == "dialogue_boundary":
			var visible_resume := int(segment.get("resume_offset", -1))
			if visible_resume > cursor and visible_resume < int(script.code_size):
				terminal["continuation"] = _make_continuation(
					root,
					current_entry,
					visible_resume,
					frames,
					calls,
					argument_slots,
					expression_stack,
					omitted_native_presentations,
					dialogue_boundaries + 1,
					local_definition_choices,
					local_choice_index,
					native_stream_policy,
					dialogue_policy,
					protagonist_name,
					script_bindings
				)
		return terminal
	return _result("step_limit", false, current_entry, cursor, trace, messages, calls, state.diff(before), argument_slots, expression_stack, omitted_native_presentations, dialogue_boundaries, "Nested MES execution reached the aggregate step limit.")


func _normalize_scripts(scripts: Dictionary) -> Dictionary:
	var normalized := {}
	for untyped_name in scripts:
		var entry_name := str(untyped_name)
		if not _is_safe_mes_entry(entry_name):
			return {"ok": false, "error": "Script-map keys must be safe ASCII MES basenames."}
		var canonical := entry_name.to_upper()
		if normalized.has(canonical):
			return {"ok": false, "error": "Script-map keys must be unique case-insensitively."}
		var untyped_record = scripts[untyped_name]
		if not untyped_record is Dictionary:
			return {"ok": false, "error": "%s script record is not a dictionary." % entry_name}
		var record: Dictionary = untyped_record
		var code_value = record.get("bytecode", record.get("code", null))
		if not code_value is PackedByteArray:
			return {"ok": false, "error": "%s script record has no MES bytecode." % entry_name}
		var code: PackedByteArray = code_value
		var header_value = record.get("header", {})
		if not header_value is Dictionary:
			return {"ok": false, "error": "%s script header is not a dictionary." % entry_name}
		var header: Dictionary = header_value
		var code_size := int(record.get("code_size", header.get("code_size", code.size())))
		if code.is_empty() or code_size != code.size():
			return {"ok": false, "error": "%s code size does not match its bytecode." % entry_name}
		var address_source_value = record.get("address_table_offsets", header.get("entry_offsets", []))
		if not address_source_value is Array:
			return {"ok": false, "error": "%s address table is not an array." % entry_name}
		var address_source: Array = address_source_value
		var address_offsets: Array[int] = []
		for untyped_offset in address_source:
			var offset := int(untyped_offset)
			if (
				offset < 0
				or offset >= code_size
				or (not address_offsets.is_empty() and offset <= address_offsets[-1])
			):
				return {"ok": false, "error": "%s has an invalid or unordered address-table coordinate." % entry_name}
			address_offsets.append(offset)
		normalized[canonical] = {
			"code": code,
			"code_size": code_size,
			"address_table_offsets": address_offsets,
		}
	return {"ok": true, "scripts": normalized}


func _script_bindings(script_map: Dictionary) -> Dictionary:
	var result := {}
	var names: Array = script_map.keys()
	names.sort()
	for untyped_name in names:
		var name := str(untyped_name)
		var script: Dictionary = script_map[name]
		result[name] = {
			"code_sha256": ContractValues.sha256_lenient(script.code),
			"code_size": int(script.code_size),
			"address_table_offsets": (script.address_table_offsets as Array).duplicate(),
		}
	return result


func _make_continuation(
	root_entry: String,
	current_entry: String,
	resume_offset: int,
	frames: Array[Dictionary],
	calls: Array[Dictionary],
	argument_slots: Dictionary,
	expression_stack: Array[int],
	omitted_native_presentations: int,
	dialogue_boundaries: int,
	local_definition_choices: Array[int],
	local_choice_index: int,
	native_stream_policy: String,
	dialogue_policy: String,
	protagonist_name: String,
	script_bindings: Dictionary
) -> Dictionary:
	return {
		"schema": ContentCoreVersionScript.MES_SCRIPT_CALL_CONTINUATION_SCHEMA,
		"root_entry": root_entry,
		"current_entry": current_entry,
		"resume_offset": resume_offset,
		"script_bindings": script_bindings.duplicate(true),
		"frames": frames.duplicate(true),
		"script_calls": calls.duplicate(true),
		"argument_slots": argument_slots.duplicate(true),
		"persistent_expression_stack": expression_stack.duplicate(),
		"omitted_native_presentation_count": omitted_native_presentations,
		"dialogue_boundary_count": dialogue_boundaries,
		"local_choice_index": local_choice_index,
		"runner_context": {
			"native_stream_policy": native_stream_policy,
			"dialogue_policy": dialogue_policy,
			"protagonist_name": protagonist_name,
			"local_definition_choices": local_definition_choices.duplicate(),
			"_local_choice_index": local_choice_index,
		},
	}


func _restore_continuation(continuation: Dictionary, script_map: Dictionary, script_bindings: Dictionary) -> Dictionary:
	if str(continuation.get("schema", "")) != ContentCoreVersionScript.MES_SCRIPT_CALL_CONTINUATION_SCHEMA:
		return {"ok": false, "error": "Nested MES continuation schema is unsupported."}
	var stored_bindings_value = continuation.get("script_bindings", null)
	if not stored_bindings_value is Dictionary or stored_bindings_value != script_bindings:
		return {"ok": false, "error": "Nested MES continuation script identities changed."}
	var root_entry := str(continuation.get("root_entry", "")).to_upper()
	var current_entry := str(continuation.get("current_entry", "")).to_upper()
	if not script_map.has(root_entry) or not script_map.has(current_entry):
		return {"ok": false, "error": "Nested MES continuation refers to an unavailable script."}
	var cursor := int(continuation.get("resume_offset", -1))
	if cursor < 0 or cursor >= int((script_map[current_entry] as Dictionary).code_size):
		return {"ok": false, "error": "Nested MES continuation resume coordinate is invalid."}
	var calls_value = continuation.get("script_calls", null)
	var frames_value = continuation.get("frames", null)
	var argument_slots_value = continuation.get("argument_slots", null)
	var expression_stack_value = continuation.get("persistent_expression_stack", null)
	if (
		not calls_value is Array
		or not frames_value is Array
		or not argument_slots_value is Dictionary
		or not expression_stack_value is Array
	):
		return {"ok": false, "error": "Nested MES continuation frame data is malformed."}
	var calls: Array[Dictionary] = []
	for untyped_call in calls_value:
		if not untyped_call is Dictionary:
			return {"ok": false, "error": "Nested MES continuation call trace is malformed."}
		calls.append((untyped_call as Dictionary).duplicate(true))
	var frames: Array[Dictionary] = []
	for frame_index in range((frames_value as Array).size()):
		var untyped_frame = (frames_value as Array)[frame_index]
		if not untyped_frame is Dictionary:
			return {"ok": false, "error": "Nested MES continuation call frame is malformed."}
		var frame: Dictionary = untyped_frame
		var frame_entry := str(frame.get("entry", "")).to_upper()
		var frame_cursor := int(frame.get("cursor", -1))
		var call_index := int(frame.get("call_index", -1))
		var expected_callee := (
			str(((frames_value as Array)[frame_index + 1] as Dictionary).get("entry", "")).to_upper()
			if frame_index + 1 < (frames_value as Array).size() and (frames_value as Array)[frame_index + 1] is Dictionary
			else current_entry
		)
		var call: Dictionary = calls[call_index] if call_index >= 0 and call_index < calls.size() else {}
		var call_offset := int(call.get("call_offset", -1))
		var decoded := (
			InstructionDecoderScript.new().decode_at((script_map[frame_entry] as Dictionary).code, call_offset)
			if script_map.has(frame_entry) and call_offset >= 0
			else {}
		)
		if (
			not script_map.has(frame_entry)
			or frame_cursor < 0
			or frame_cursor >= int((script_map[frame_entry] as Dictionary).code_size)
			or call_index < 0
			or call_index >= calls.size()
			or not frame.get("argument_slots", null) is Dictionary
			or not frame.get("persistent_expression_stack", null) is Array
			or str(call.get("caller_entry", "")).to_upper() != frame_entry
			or str(call.get("callee_entry", "")).to_upper() != expected_callee
			or int(call.get("resume_offset", -1)) != frame_cursor
			or bool(call.get("returned", false))
			or not decoded.get("ok", false)
			or str(decoded.get("op", "")) != "script_dispatch"
			or str(decoded.get("script_target", "")).to_upper() != expected_callee
			or int(decoded.get("end_offset", -1)) != frame_cursor
		):
			return {"ok": false, "error": "Nested MES continuation call frame no longer matches its caller."}
		frames.append(frame.duplicate(true))
	if frames.is_empty() or frames.size() > calls.size():
		return {"ok": false, "error": "Nested MES continuation has no active caller frame."}
	var expression_stack: Array[int] = []
	for untyped_value in expression_stack_value:
		if typeof(untyped_value) != TYPE_INT:
			return {"ok": false, "error": "Nested MES continuation expression stack is malformed."}
		expression_stack.append(int(untyped_value))
	var omitted_count := int(continuation.get("omitted_native_presentation_count", -1))
	var dialogue_count := int(continuation.get("dialogue_boundary_count", -1))
	var local_choice_index := int(continuation.get("local_choice_index", -1))
	if omitted_count < 0 or dialogue_count < 0 or local_choice_index < 0:
		return {"ok": false, "error": "Nested MES continuation counters are invalid."}
	return {
		"ok": true,
		"root_entry": root_entry,
		"current_entry": current_entry,
		"cursor": cursor,
		"calls": calls,
		"frames": frames,
		"argument_slots": (argument_slots_value as Dictionary).duplicate(true),
		"persistent_expression_stack": expression_stack,
		"omitted_native_presentation_count": omitted_count,
		"dialogue_boundary_count": dialogue_count,
		"local_choice_index": local_choice_index,
	}


func _terminal_result(
	segment: Dictionary,
	current_entry: String,
	trace: Array[Dictionary],
	messages: Array[Dictionary],
	calls: Array[Dictionary],
	frames: Array[Dictionary],
	state_diff: Array[Dictionary],
	argument_slots: Dictionary,
	expression_stack: Array[int],
	omitted_native_presentations: int,
	dialogue_boundaries: int
) -> Dictionary:
	var result := _result(
		str(segment.get("status", "unknown")),
		bool(segment.get("ok", false)),
		current_entry,
		int(segment.get("offset", -1)),
		trace,
		messages,
		calls,
		state_diff,
		argument_slots,
		expression_stack,
		omitted_native_presentations,
		dialogue_boundaries,
		str(segment.get("error", ""))
	)
	result["script_call_depth"] = frames.size()
	if segment.has("command_id"):
		result["command_id"] = int(segment.command_id)
	if segment.has("resume_offset"):
		result["resume_offset"] = int(segment.resume_offset)
	if segment.has("definitions"):
		var definitions: Array[Dictionary] = []
		for untyped_definition in segment.get("definitions", []):
			var definition: Dictionary = (untyped_definition as Dictionary).duplicate(true)
			definition["source_entry"] = current_entry
			definition["script_call_depth"] = frames.size()
			var definition_messages: Array[Dictionary] = []
			for untyped_message in definition.get("messages", []):
				var message: Dictionary = (untyped_message as Dictionary).duplicate(true)
				message["source_entry"] = current_entry
				message["script_call_depth"] = frames.size()
				definition_messages.append(message)
			definition["messages"] = definition_messages
			definitions.append(definition)
		result["definitions"] = definitions
	if segment.has("definition_groups"):
		var source_groups: Dictionary = segment.get("definition_groups", {})
		var decorated_groups := {}
		for untyped_selector in source_groups:
			var selector := int(untyped_selector)
			var decorated_definitions: Array[Dictionary] = []
			for untyped_definition in source_groups[untyped_selector]:
				var definition: Dictionary = (untyped_definition as Dictionary).duplicate(true)
				definition["source_entry"] = current_entry
				definition["script_call_depth"] = frames.size()
				var definition_messages: Array[Dictionary] = []
				for untyped_message in definition.get("messages", []):
					var message: Dictionary = (untyped_message as Dictionary).duplicate(true)
					message["source_entry"] = current_entry
					message["script_call_depth"] = frames.size()
					definition_messages.append(message)
				definition["messages"] = definition_messages
				decorated_definitions.append(definition)
			decorated_groups[selector] = decorated_definitions
		result["definition_groups"] = decorated_groups
		result["definition_group_order"] = (segment.get("definition_group_order", []) as Array).duplicate()
		result["selection_definition_group"] = int(segment.get("selection_definition_group", -1))
		result["registered_definition_count"] = int(segment.get("registered_definition_count", 0))
		result["observed_definition_count"] = int(segment.get("observed_definition_count", 0))
	return result


func _result(
	status: String,
	ok: bool,
	current_entry: String,
	offset: int,
	trace: Array[Dictionary],
	messages: Array[Dictionary],
	calls: Array[Dictionary],
	state_diff: Array[Dictionary],
	argument_slots: Dictionary,
	expression_stack: Array[int],
	omitted_native_presentations: int,
	dialogue_boundaries: int,
	error := ""
) -> Dictionary:
	var result := {
		"ok": ok,
		"schema": ContentCoreVersionScript.MES_SCRIPT_CALL_TRACE_SCHEMA,
		"status": status,
		"current_entry": current_entry,
		"offset": offset,
		"trace": trace,
		"messages": messages,
		"script_calls": calls,
		"state_diff": state_diff,
		"argument_slots": argument_slots.duplicate(true),
		"persistent_expression_stack": expression_stack.duplicate(),
		"omitted_native_presentation_count": omitted_native_presentations,
		"dialogue_boundary_count": dialogue_boundaries,
	}
	if not error.is_empty():
		result["error"] = error
	return result


func _is_safe_mes_entry(entry_name: String) -> bool:
	return (
		not entry_name.is_empty()
		and entry_name.get_file() == entry_name
		and not entry_name.contains("..")
		and entry_name.get_extension().to_lower() == "mes"
		and entry_name.to_ascii_buffer().get_string_from_ascii() == entry_name
	)


func _is_native_presentation_omission(record: Dictionary) -> bool:
	return (
		str(record.get("effect", "")) == "native_presentation_omitted"
		or bool(record.get("native_effect_omitted", false))
	)
