class_name KakyuMesLibraryRunner
extends RefCounted

const EventRunnerScript := preload("res://content_core/mes_event_runner.gd")
const RegisteredDefinitionCallScript := preload("res://content_core/mes_registered_definition_call.gd")
const RegisteredDefinitionRunnerScript := preload("res://content_core/mes_registered_definition_runner.gd")
const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")
const ContractValues := preload("res://content_core/contract_values.gd")

const DEFAULT_MAX_STEPS := 10000
const DEFAULT_MAX_CALL_DEPTH := 16

var _runner := EventRunnerScript.new()
var _registered_definition_call := RegisteredDefinitionCallScript.new()
var _registered_definition_runner := RegisteredDefinitionRunnerScript.new()


func resume(
	code: PackedByteArray,
	library_index: Dictionary,
	continuation: Dictionary,
	state: KakyuMesSandboxState,
	context := {},
	max_steps := DEFAULT_MAX_STEPS,
	max_call_depth := DEFAULT_MAX_CALL_DEPTH
) -> Dictionary:
	if str(continuation.get("schema", "")) != ContentCoreVersionScript.MES_LIBRARY_CONTINUATION_SCHEMA:
		return _result("invalid_continuation", false, -1, [], [], [], [], "Shared-library continuation schema is unsupported.")
	if not context is Dictionary:
		return _result("invalid_continuation", false, -1, [], [], [], [], "Shared-library continuation context must be a dictionary.")
	for untyped_key in context:
		if str(untyped_key) not in ["registered_definitions", "code_source"]:
			return _result("invalid_continuation", false, -1, [], [], [], [], "Shared-library continuation override is unsupported: %s" % str(untyped_key))
	if not context.get("registered_definitions", {}) is Dictionary:
		return _result("invalid_continuation", false, -1, [], [], [], [], "Shared-library registered definitions are malformed.")
	var resume_context := {
		"registered_definitions": context.get("registered_definitions", {}).duplicate(false),
		"_library_continuation": continuation.duplicate(true),
	}
	if context.has("code_source"):
		resume_context["code_source"] = context.code_source
	return run(
		code,
		library_index,
		int(continuation.get("root_routine_id", -1)),
		state,
		resume_context,
		max_steps,
		max_call_depth
	)


func run(
	code: PackedByteArray,
	library_index: Dictionary,
	routine_id: int,
	state: KakyuMesSandboxState,
	context := {},
	max_steps := DEFAULT_MAX_STEPS,
	max_call_depth := DEFAULT_MAX_CALL_DEPTH
) -> Dictionary:
	var before := state.snapshot()
	# A caller may supply its own instruction source; the default is this
	# bytecode, decoded exactly as before. See mes_code_source.gd.
	var source: KakyuMesCodeSource = context.get("code_source", null)
	if source == null:
		source = KakyuMesCodeSource.for_bytecode(code)
	if source == null:
		# for_bytecode declares this failure, so it is handled rather than
		# dereferenced. See mes_code_source.gd.
		return _result("missing_code_source", false, routine_id, [], [], [], state.diff(before), "No MES code source is available for this bytecode.")
	if not library_index.get("ok", false):
		return _result("invalid_library", false, routine_id, [], [], [], state.diff(before), "A valid MES library index is required.")
	var by_id: Dictionary = library_index.get("by_id", {})
	if not by_id.has(routine_id):
		return _result("missing_routine", false, routine_id, [], [], [], state.diff(before), "Shared routine %d is not registered." % routine_id)
	if max_steps <= 0 or max_call_depth < 0:
		return _result("invalid_limits", false, routine_id, [], [], [], state.diff(before), "Step and call-depth limits are invalid.")

	var trace: Array[Dictionary] = []
	var messages: Array[Dictionary] = []
	var calls: Array[Dictionary] = []
	var frames: Array[Dictionary] = []
	var argument_slots: Dictionary = context.get("argument_slots", {}).duplicate(true)
	var registered_definitions: Dictionary = context.get("registered_definitions", {}).duplicate(true)
	var expression_stack: Array[int] = []
	for untyped_value in context.get("persistent_expression_stack", []):
		expression_stack.append(int(untyped_value))
	var current_routine := routine_id
	var bounds: Dictionary = by_id[current_routine]
	var cursor := int(bounds.body_offset)
	var end_offset := int(bounds.end_offset)
	var root_routine := routine_id
	var omitted_native_presentations := 0
	var active_registered_definition_continuation := {}
	var continuation_value = context.get("_library_continuation", {})
	if continuation_value is Dictionary and not (continuation_value as Dictionary).is_empty():
		var restored := _restore_continuation(
			continuation_value,
			_library_binding(source, library_index),
			by_id,
			source,
			registered_definitions
		)
		if not restored.get("ok", false):
			return _result("invalid_continuation", false, routine_id, [], [], [], state.diff(before), str(restored.get("error", "Shared-library continuation is invalid.")))
		root_routine = int(restored.root_routine_id)
		current_routine = int(restored.current_routine_id)
		cursor = int(restored.cursor)
		end_offset = int(restored.end_offset)
		frames.assign(restored.frames)
		calls.assign(restored.calls)
		argument_slots = restored.argument_slots.duplicate(true)
		expression_stack.assign(restored.persistent_expression_stack)
		omitted_native_presentations = int(restored.omitted_native_presentation_count)
		active_registered_definition_continuation = restored.get(
			"registered_definition_continuation", {}
		).duplicate(true)
		if frames.size() > max_call_depth:
			return _result("invalid_continuation", false, root_routine, [], [], calls, state.diff(before), "Shared-library continuation exceeds the requested call-depth limit.")
	elif continuation_value != null and (not continuation_value is Dictionary or not (continuation_value as Dictionary).is_empty()):
		return _result("invalid_continuation", false, routine_id, [], [], [], state.diff(before), "Shared-library continuation must be a dictionary.")
	while trace.size() < max_steps:
		if not active_registered_definition_continuation.is_empty():
			var definition_resume_result := _registered_definition_runner.resume(
				code,
				active_registered_definition_continuation,
				state,
				{"registered_definitions": registered_definitions, "code_source": source}
			)
			_append_registered_definition_rows(
				trace, messages, definition_resume_result, current_routine, frames.size()
			)
			argument_slots = definition_resume_result.get(
				"argument_slots", argument_slots
			).duplicate(true)
			expression_stack.clear()
			for untyped_value in definition_resume_result.get("persistent_expression_stack", []):
				expression_stack.append(int(untyped_value))
			omitted_native_presentations = _count_native_presentation_omissions(trace)
			if str(definition_resume_result.get("status", "")) == "registered_definition_dialogue_boundary":
				return _registered_definition_dialogue_boundary(
					source, library_index, root_routine, current_routine, cursor,
					end_offset, frames, calls, trace, messages, state.diff(before),
					argument_slots, expression_stack, omitted_native_presentations,
					registered_definitions, definition_resume_result
				)
			if not definition_resume_result.get("ok", false) or str(definition_resume_result.get("status", "")) != "script_return":
				return _boundary_result(
					"library_" + str(definition_resume_result.get("status", "registered_definition_boundary")),
					root_routine, trace, messages, calls, state.diff(before),
					argument_slots, expression_stack, omitted_native_presentations,
					str(definition_resume_result.get("error", "Registered DEF continuation stopped."))
				)
			active_registered_definition_continuation.clear()
			if frames.is_empty():
				var completed := _result("library_return", true, root_routine, trace, messages, calls, state.diff(before))
				completed["argument_slots"] = argument_slots.duplicate(true)
				completed["persistent_expression_stack"] = expression_stack.duplicate()
				completed["omitted_native_presentation_count"] = omitted_native_presentations
				return completed
			var restored_frame: Dictionary = frames.pop_back()
			current_routine = int(restored_frame.routine_id)
			cursor = int(restored_frame.resume_offset)
			end_offset = int(restored_frame.end_offset)
			continue
		var segment := _runner.run(
			code,
			cursor,
			state,
			end_offset,
			max_steps - trace.size(),
			{
				"argument_slots": argument_slots,
				"persistent_expression_stack": expression_stack,
				"native_stream_policy": "skip_bounded_preserve_dialogue",
				"native_record_policy": "omit_bounded",
				"code_source": source,
			}
		)
		var depth := frames.size()
		for untyped_record in segment.get("trace", []):
			var record: Dictionary = untyped_record.duplicate(true)
			record["step"] = trace.size()
			record["library_routine_id"] = current_routine
			record["library_call_depth"] = depth
			if _is_native_presentation_omission(record):
				omitted_native_presentations += 1
			trace.append(record)
		for untyped_message in segment.get("messages", []):
			var message: Dictionary = untyped_message.duplicate(true)
			message["library_routine_id"] = current_routine
			messages.append(message)
		argument_slots = segment.get("argument_slots", argument_slots).duplicate(true)
		var next_expression_stack: Array = segment.get(
			"persistent_expression_stack", expression_stack.duplicate()
		)
		expression_stack.clear()
		for untyped_value in next_expression_stack:
			expression_stack.append(int(untyped_value))
		var status := str(segment.get("status", "unknown"))
		if status == "script_return":
			if frames.is_empty():
				var completed := _result("library_return", true, root_routine, trace, messages, calls, state.diff(before))
				completed["argument_slots"] = argument_slots.duplicate(true)
				completed["persistent_expression_stack"] = expression_stack.duplicate()
				completed["omitted_native_presentation_count"] = omitted_native_presentations
				return completed
			var frame: Dictionary = frames.pop_back()
			current_routine = int(frame.routine_id)
			cursor = int(frame.resume_offset)
			end_offset = int(frame.end_offset)
			continue
		if status == "shared_routine_boundary":
			var called_routine := int(segment.get("trace", [])[-1].get("routine_id", -1))
			if not by_id.has(called_routine):
				return _boundary_result("missing_nested_routine", root_routine, trace, messages, calls, state.diff(before), argument_slots, expression_stack, omitted_native_presentations, "Nested shared routine %d is not registered." % called_routine)
			if frames.size() >= max_call_depth:
				return _boundary_result("call_depth_limit", root_routine, trace, messages, calls, state.diff(before), argument_slots, expression_stack, omitted_native_presentations, "Shared routine call depth exceeded its limit.")
			var resume_offset := int(segment.get("resume_offset", -1))
			if resume_offset <= cursor or resume_offset > end_offset:
				return _boundary_result("invalid_resume", root_routine, trace, messages, calls, state.diff(before), argument_slots, expression_stack, omitted_native_presentations, "Shared routine caller resume coordinate is invalid.")
			var call_index := calls.size()
			calls.append({
				"caller_routine_id": current_routine,
				"callee_routine_id": called_routine,
				"call_offset": int(segment.offset),
				"resume_offset": resume_offset,
				"call_depth": frames.size(),
			})
			frames.append({
				"routine_id": current_routine,
				"resume_offset": resume_offset,
				"end_offset": end_offset,
				"call_index": call_index,
			})
			current_routine = called_routine
			bounds = by_id[current_routine]
			cursor = int(bounds.body_offset)
			end_offset = int(bounds.end_offset)
			continue
		if status == "definition_invoke_boundary":
			var definition_id := int(segment.get("trace", [])[-1].get("definition_id", -1))
			var definition: Dictionary = registered_definitions.get(definition_id, {})
			if definition.is_empty():
				return _boundary_result(
					"library_definition_invoke_boundary",
					root_routine,
					trace,
					messages,
					calls,
					state.diff(before),
					argument_slots,
					expression_stack,
					omitted_native_presentations,
					str(segment.get("error", "Registered DEF execution is unavailable."))
				)
			var definition_probe_before := state.snapshot()
			var definition_probe := _registered_definition_runner.run(
				code,
				int(segment.get("offset", -1)),
				state,
				end_offset,
				{
					"registered_definitions": registered_definitions,
					"argument_slots": argument_slots,
					"persistent_expression_stack": expression_stack,
					"native_stream_policy": "stop",
					"registered_definition_native_stream_policy": "stop",
					"native_record_policy": "omit_bounded",
					"registered_definition_native_record_policy": "omit_bounded",
					"code_source": source,
				},
				max_steps - trace.size() + 1,
				max_call_depth,
				max_call_depth
			)
			if str(definition_probe.get("status", "")) == "registered_definition_dialogue_boundary":
				if not trace.is_empty():
					trace.pop_back()
				_append_registered_definition_rows(
					trace, messages, definition_probe, current_routine, depth
				)
				argument_slots = definition_probe.get("argument_slots", argument_slots).duplicate(true)
				expression_stack.clear()
				for untyped_value in definition_probe.get("persistent_expression_stack", []):
					expression_stack.append(int(untyped_value))
				omitted_native_presentations = _count_native_presentation_omissions(trace)
				return _registered_definition_dialogue_boundary(
					source, library_index, root_routine, current_routine,
					int(segment.get("offset", -1)), end_offset, frames, calls,
					trace, messages, state.diff(before), argument_slots,
					expression_stack, omitted_native_presentations,
					registered_definitions, definition_probe
				)
			state.restore(definition_probe_before)
			var definition_result := _registered_definition_call.run(
				definition_id,
				definition,
				state,
				{
					"argument_slots": argument_slots,
					"persistent_expression_stack": expression_stack,
					"native_stream_policy": "skip_bounded",
					"native_record_policy": "omit_bounded",
				},
				max_steps - trace.size()
			)
			if str(definition_result.get("status", "")) == "invalid_definition":
				return _boundary_result("invalid_registered_definition", root_routine, trace, messages, calls, state.diff(before), argument_slots, expression_stack, omitted_native_presentations, str(definition_result.get("error", "Registered DEF coordinates are invalid.")))
			for untyped_record in definition_result.get("trace", []):
				var record: Dictionary = untyped_record.duplicate(true)
				record["step"] = trace.size()
				record["library_routine_id"] = current_routine
				record["library_call_depth"] = depth
				if _is_native_presentation_omission(record):
					omitted_native_presentations += 1
				trace.append(record)
			for untyped_message in definition_result.get("messages", []):
				var message: Dictionary = untyped_message.duplicate(true)
				message["library_routine_id"] = current_routine
				messages.append(message)
			argument_slots = definition_result.get("argument_slots", argument_slots).duplicate(true)
			expression_stack.clear()
			for untyped_value in definition_result.get("persistent_expression_stack", []):
				expression_stack.append(int(untyped_value))
			if not definition_result.get("ok", false):
				return _boundary_result(
					"registered_" + str(definition_result.get("status", "definition_boundary")),
					root_routine,
					trace,
					messages,
					calls,
					state.diff(before),
					argument_slots,
					expression_stack,
					omitted_native_presentations,
					str(definition_result.get("error", "Registered DEF execution stopped."))
				)
			var definition_resume := int(segment.get("trace", [])[-1].get("end_offset", -1))
			if definition_resume <= cursor or definition_resume > end_offset:
				return _boundary_result("invalid_definition_resume", root_routine, trace, messages, calls, state.diff(before), argument_slots, expression_stack, omitted_native_presentations, "Registered DEF caller resume coordinate is invalid.")
			cursor = definition_resume
			continue
		var boundary := _boundary_result(
			"library_" + status,
			root_routine,
			trace,
			messages,
			calls,
			state.diff(before),
			argument_slots,
			expression_stack,
			omitted_native_presentations,
			str(segment.get("error", "Nested library execution stopped."))
		)
		if status == "dialogue_boundary":
			var dialogue_resume := int(segment.get("resume_offset", -1))
			if dialogue_resume > cursor and dialogue_resume < end_offset:
				boundary["offset"] = int(segment.get("offset", -1))
				boundary["resume_offset"] = dialogue_resume
				boundary["continuation"] = _make_continuation(
					_library_binding(source, library_index),
					root_routine,
					current_routine,
					int(segment.get("offset", -1)),
					dialogue_resume,
					end_offset,
					frames,
					calls,
					argument_slots,
					expression_stack,
					omitted_native_presentations,
					registered_definitions
				)
		return boundary
	return _boundary_result("step_limit", root_routine, trace, messages, calls, state.diff(before), argument_slots, expression_stack, omitted_native_presentations, "Shared routine execution reached the step limit.")


func _library_binding(source: KakyuMesCodeSource, library_index: Dictionary) -> Dictionary:
	return {
		"code_sha256": source.sha256_range(0, source.size()),
		"code_size": source.size(),
		"index_schema": str(library_index.get("schema", "")),
		"registration_count": int(library_index.get("registration_count", -1)),
		"terminal_offset": int(library_index.get("terminal_offset", -1)),
		"routines": library_index.get("routines", []).duplicate(true),
		"by_id": library_index.get("by_id", {}).duplicate(true),
	}


func _make_continuation(
	library_binding: Dictionary,
	root_routine_id: int,
	current_routine_id: int,
	boundary_offset: int,
	cursor: int,
	end_offset: int,
	frames: Array[Dictionary],
	calls: Array[Dictionary],
	argument_slots: Dictionary,
	expression_stack: Array[int],
	omitted_native_presentations: int,
	registered_definitions: Dictionary,
	registered_definition_continuation := {}
) -> Dictionary:
	var continuation := {
		"schema": ContentCoreVersionScript.MES_LIBRARY_CONTINUATION_SCHEMA,
		"library_binding": library_binding.duplicate(true),
		"root_routine_id": root_routine_id,
		"current_routine_id": current_routine_id,
		"boundary_offset": boundary_offset,
		"cursor": cursor,
		"end_offset": end_offset,
		"frames": frames.duplicate(true),
		"calls": calls.duplicate(true),
		"argument_slots": argument_slots.duplicate(true),
		"persistent_expression_stack": expression_stack.duplicate(),
		"omitted_native_presentation_count": omitted_native_presentations,
		"registered_definition_bindings": _definition_bindings(registered_definitions),
	}
	if registered_definition_continuation is Dictionary and not registered_definition_continuation.is_empty():
		continuation["registered_definition_continuation"] = registered_definition_continuation.duplicate(true)
	return continuation


func _restore_continuation(
	continuation: Dictionary,
	library_binding: Dictionary,
	by_id: Dictionary,
	source: KakyuMesCodeSource,
	registered_definitions: Dictionary
) -> Dictionary:
	if (
		str(continuation.get("schema", "")) != ContentCoreVersionScript.MES_LIBRARY_CONTINUATION_SCHEMA
		or not continuation.get("library_binding", null) is Dictionary
		or continuation.get("library_binding", {}) != library_binding
	):
		return {"ok": false, "error": "Shared-library continuation source identity changed."}
	if (
		not continuation.get("registered_definition_bindings", null) is Dictionary
		or continuation.get("registered_definition_bindings", {}) != _definition_bindings(registered_definitions)
	):
		return {"ok": false, "error": "Shared-library continuation registered-definition identities changed."}
	var root_routine_id := int(continuation.get("root_routine_id", -1))
	var current_routine_id := int(continuation.get("current_routine_id", -1))
	var boundary_offset := int(continuation.get("boundary_offset", -1))
	var cursor := int(continuation.get("cursor", -1))
	var end_offset := int(continuation.get("end_offset", -1))
	var registered_definition_continuation_value = continuation.get(
		"registered_definition_continuation", {}
	)
	if not registered_definition_continuation_value is Dictionary:
		return {"ok": false, "error": "Shared-library registered-DEF continuation is malformed."}
	var registered_definition_continuation: Dictionary = (
		registered_definition_continuation_value as Dictionary
	)
	if not by_id.has(root_routine_id) or not by_id.has(current_routine_id):
		return {"ok": false, "error": "Shared-library continuation routine is no longer registered."}
	var current_bounds: Dictionary = by_id[current_routine_id]
	if registered_definition_continuation.is_empty():
		if (
			end_offset != int(current_bounds.end_offset)
			or cursor < int(current_bounds.body_offset)
			or cursor >= end_offset
			or boundary_offset < int(current_bounds.body_offset)
			or source.dialogue_boundary_end(boundary_offset, cursor) != cursor
		):
			return {"ok": false, "error": "Shared-library continuation coordinate is outside its routine."}
	else:
		if (
			str(registered_definition_continuation.get("schema", ""))
				!= ContentCoreVersionScript.MES_REGISTERED_DEFINITION_CONTINUATION_SCHEMA
			or end_offset != int(current_bounds.end_offset)
			or cursor != int(registered_definition_continuation.get("root_start_offset", -1))
			or int(registered_definition_continuation.get("root_end_offset", -1)) != end_offset
			or cursor < int(current_bounds.body_offset)
			or cursor >= end_offset
		):
			return {"ok": false, "error": "Shared-library registered-DEF frame is outside its routine."}
	var frames_value = continuation.get("frames", null)
	var calls_value = continuation.get("calls", null)
	var argument_slots_value = continuation.get("argument_slots", null)
	var expression_stack_value = continuation.get("persistent_expression_stack", null)
	if not frames_value is Array or not calls_value is Array or not argument_slots_value is Dictionary or not expression_stack_value is Array:
		return {"ok": false, "error": "Shared-library continuation frame data is malformed."}
	var calls: Array[Dictionary] = []
	for untyped_call in calls_value:
		if not untyped_call is Dictionary:
			return {"ok": false, "error": "Shared-library continuation call trace is malformed."}
		calls.append((untyped_call as Dictionary).duplicate(true))
	for call in calls:
		var caller_routine := int(call.get("caller_routine_id", -1))
		var callee_routine := int(call.get("callee_routine_id", -1))
		var call_offset := int(call.get("call_offset", -1))
		var resume_offset := int(call.get("resume_offset", -1))
		if not by_id.has(caller_routine) or not by_id.has(callee_routine) or int(call.get("call_depth", -1)) < 0:
			return {"ok": false, "error": "Shared-library continuation call trace references an unknown routine."}
		var caller_bounds: Dictionary = by_id[caller_routine]
		var decoded := source.decode_at(call_offset, int(caller_bounds.end_offset))
		if (
			call_offset < int(caller_bounds.body_offset)
			or not decoded.get("ok", false)
			or int(decoded.get("command_id", -1)) != 0x1D
			or str(decoded.get("op", "")) != "script_transfer"
			or int(decoded.get("end_offset", -1)) != resume_offset
			or _decoded_literal_routine(decoded) != callee_routine
		):
			return {"ok": false, "error": "Shared-library continuation call trace no longer matches its invocation."}
	var frames: Array[Dictionary] = []
	var prior_call_index := -1
	for frame_index in range((frames_value as Array).size()):
		var untyped_frame = (frames_value as Array)[frame_index]
		if not untyped_frame is Dictionary:
			return {"ok": false, "error": "Shared-library continuation caller frame is malformed."}
		var frame: Dictionary = (untyped_frame as Dictionary).duplicate(true)
		var caller_routine := int(frame.get("routine_id", -1))
		var resume_offset := int(frame.get("resume_offset", -1))
		var frame_end := int(frame.get("end_offset", -1))
		var call_index := int(frame.get("call_index", -1))
		var expected_callee := (
			int(((frames_value as Array)[frame_index + 1] as Dictionary).get("routine_id", -1))
			if frame_index + 1 < (frames_value as Array).size() and (frames_value as Array)[frame_index + 1] is Dictionary
			else current_routine_id
		)
		if not by_id.has(caller_routine):
			return {"ok": false, "error": "Shared-library continuation caller routine is missing."}
		var caller_bounds: Dictionary = by_id[caller_routine]
		var call: Dictionary = calls[call_index] if call_index >= 0 and call_index < calls.size() else {}
		var call_offset := int(call.get("call_offset", -1))
		var decoded := source.decode_at(call_offset, frame_end)
		if (
			call_index <= prior_call_index
			or call_index >= calls.size()
			or frame_end != int(caller_bounds.end_offset)
			or resume_offset <= int(caller_bounds.body_offset)
			or resume_offset > frame_end
			or int(call.get("caller_routine_id", -1)) != caller_routine
			or int(call.get("callee_routine_id", -1)) != expected_callee
			or int(call.get("call_depth", -1)) != frame_index
			or int(call.get("resume_offset", -1)) != resume_offset
			or not decoded.get("ok", false)
			or int(decoded.get("command_id", -1)) != 0x1D
			or str(decoded.get("op", "")) != "script_transfer"
			or int(decoded.get("end_offset", -1)) != resume_offset
			or _decoded_literal_routine(decoded) != expected_callee
		):
			return {"ok": false, "error": "Shared-library continuation caller frame is invalid."}
		prior_call_index = call_index
		frames.append(frame)
	if (
		frames.is_empty() and current_routine_id != root_routine_id
		or not frames.is_empty() and int(frames[0].routine_id) != root_routine_id
	):
		return {"ok": false, "error": "Shared-library continuation active frame chain does not start at its root routine."}
	for untyped_key in (argument_slots_value as Dictionary):
		if typeof(untyped_key) != TYPE_INT or typeof((argument_slots_value as Dictionary)[untyped_key]) != TYPE_INT:
			return {"ok": false, "error": "Shared-library continuation argument slots are malformed."}
	var expression_stack: Array[int] = []
	for untyped_value in expression_stack_value:
		if typeof(untyped_value) != TYPE_INT:
			return {"ok": false, "error": "Shared-library continuation expression stack is malformed."}
		expression_stack.append(int(untyped_value))
	var omitted_native_presentations := int(continuation.get("omitted_native_presentation_count", -1))
	if omitted_native_presentations < 0:
		return {"ok": false, "error": "Shared-library continuation counters are invalid."}
	return {
		"ok": true,
		"root_routine_id": root_routine_id,
		"current_routine_id": current_routine_id,
		"cursor": cursor,
		"end_offset": end_offset,
		"frames": frames,
		"calls": calls,
		"argument_slots": (argument_slots_value as Dictionary).duplicate(true),
		"persistent_expression_stack": expression_stack,
		"omitted_native_presentation_count": omitted_native_presentations,
		"registered_definition_continuation": registered_definition_continuation.duplicate(true),
	}


func _registered_definition_dialogue_boundary(
	source: KakyuMesCodeSource,
	library_index: Dictionary,
	root_routine: int,
	current_routine: int,
	root_start_offset: int,
	end_offset: int,
	frames: Array[Dictionary],
	calls: Array[Dictionary],
	trace: Array[Dictionary],
	messages: Array[Dictionary],
	state_diff: Array[Dictionary],
	argument_slots: Dictionary,
	expression_stack: Array[int],
	omitted_native_presentations: int,
	registered_definitions: Dictionary,
	definition_result: Dictionary
) -> Dictionary:
	var definition_continuation_value = definition_result.get("continuation", null)
	if not definition_continuation_value is Dictionary:
		return _boundary_result(
			"invalid_registered_definition_continuation", root_routine, trace,
			messages, calls, state_diff, argument_slots, expression_stack,
			omitted_native_presentations,
			"Registered DEF dialogue did not expose a continuation."
		)
	var boundary := _boundary_result(
		"library_dialogue_boundary", root_routine, trace, messages, calls,
		state_diff, argument_slots, expression_stack,
		omitted_native_presentations,
		str(definition_result.get("error", "Registered DEF dialogue boundary reached."))
	)
	boundary["offset"] = int(definition_result.get("offset", -1))
	boundary["registered_definition_calls"] = definition_result.get(
		"registered_definition_calls", []
	).duplicate(true)
	boundary["continuation"] = _make_continuation(
		_library_binding(source, library_index), root_routine, current_routine,
		int(definition_result.get("offset", -1)), root_start_offset, end_offset,
		frames, calls, argument_slots, expression_stack,
		omitted_native_presentations, registered_definitions,
		definition_continuation_value
	)
	return boundary


func _append_registered_definition_rows(
	trace: Array[Dictionary],
	messages: Array[Dictionary],
	definition_result: Dictionary,
	current_routine: int,
	depth: int
) -> void:
	for untyped_record in definition_result.get("trace", []):
		var record: Dictionary = untyped_record.duplicate(true)
		record["step"] = trace.size()
		record["library_routine_id"] = current_routine
		record["library_call_depth"] = depth
		trace.append(record)
	for untyped_message in definition_result.get("messages", []):
		var message: Dictionary = untyped_message.duplicate(true)
		message["library_routine_id"] = current_routine
		messages.append(message)


func _count_native_presentation_omissions(trace: Array[Dictionary]) -> int:
	var count := 0
	for record in trace:
		if _is_native_presentation_omission(record):
			count += 1
	return count


func _is_native_presentation_omission(record: Dictionary) -> bool:
	return (
		str(record.get("effect", "")) == "native_presentation_omitted"
		or bool(record.get("native_effect_omitted", false))
	)


func _definition_bindings(registered_definitions: Dictionary) -> Dictionary:
	var bindings := {}
	for untyped_id in registered_definitions:
		var definition_value = registered_definitions[untyped_id]
		var binding_key := "%d:%s" % [typeof(untyped_id), str(untyped_id)]
		if not definition_value is Dictionary:
			bindings[binding_key] = {"valid": false}
			continue
		var definition: Dictionary = definition_value
		var code_value = definition.get("code", null)
		bindings[binding_key] = {
			"valid": code_value is PackedByteArray,
			"code_sha256": ContractValues.sha256_lenient(code_value) if code_value is PackedByteArray else "",
			"code_size": (code_value as PackedByteArray).size() if code_value is PackedByteArray else -1,
			"body_offset": int(definition.get("body_offset", -1)),
			"end_offset": int(definition.get("end_offset", -1)),
			"source": str(definition.get("source", "")),
			"source_entry": str(definition.get("source_entry", "")),
		}
	return bindings


func _decoded_literal_routine(decoded: Dictionary) -> int:
	var operands_value = decoded.get("operands", [])
	if not operands_value is Array or (operands_value as Array).is_empty():
		return -1
	var operand = (operands_value as Array)[0]
	if not operand is Dictionary:
		return -1
	var records_value = (operand as Dictionary).get("records", null)
	if not records_value is Array or (records_value as Array).size() != 1:
		return -1
	var record = (records_value as Array)[0]
	if not record is Dictionary or str((record as Dictionary).get("type", "")) != "expression_record":
		return -1
	var expression_value = (record as Dictionary).get("value", null)
	if not expression_value is Dictionary or not (expression_value as Dictionary).get("ok", false):
		return -1
	var ast_value = (expression_value as Dictionary).get("ast", null)
	if not ast_value is Dictionary or str((ast_value as Dictionary).get("type", "")) != "literal":
		return -1
	return int((ast_value as Dictionary).get("value", -1))


func _boundary_result(
	status: String,
	routine_id: int,
	trace: Array[Dictionary],
	messages: Array[Dictionary],
	calls: Array[Dictionary],
	state_diff: Array[Dictionary],
	argument_slots: Dictionary,
	expression_stack: Array[int],
	omitted_native_presentations: int,
	error: String
) -> Dictionary:
	var result := _result(status, false, routine_id, trace, messages, calls, state_diff, error)
	result["argument_slots"] = argument_slots.duplicate(true)
	result["persistent_expression_stack"] = expression_stack.duplicate()
	result["omitted_native_presentation_count"] = omitted_native_presentations
	return result


func _result(
	status: String,
	ok: bool,
	routine_id: int,
	trace: Array[Dictionary],
	messages: Array[Dictionary],
	calls: Array[Dictionary],
	state_diff: Array[Dictionary],
	error := ""
) -> Dictionary:
	var result := {
		"ok": ok,
		"schema": ContentCoreVersionScript.MES_LIBRARY_TRACE_SCHEMA,
		"status": status,
		"routine_id": routine_id,
		"trace": trace,
		"messages": messages,
		"calls": calls,
		"omitted_native_record_count": _count_native_record_omissions(trace),
		"decoded_surface_operation_count": _count_surface_operations(trace),
		"decoded_surface_display_refresh_count": _count_surface_display_refreshes(trace),
		"unresolved_surface_dispatch_count": _count_unresolved_surface_dispatches(trace),
		"state_diff": state_diff,
	}
	if not error.is_empty():
		result["error"] = error
	return result


func _count_native_record_omissions(trace: Array[Dictionary]) -> int:
	var count := 0
	for record in trace:
		if str(record.get("effect", "")) == "native_record_effects_omitted":
			count += 1
	return count


func _count_surface_operations(trace: Array[Dictionary]) -> int:
	var count := 0
	for record in trace:
		if str(record.get("effect", "")) == "surface_operation_omitted":
			count += 1
	return count


func _count_surface_display_refreshes(trace: Array[Dictionary]) -> int:
	var count := 0
	for record in trace:
		if str(record.get("effect", "")) == "surface_display_refresh_omitted":
			count += 1
	return count


func _count_unresolved_surface_dispatches(trace: Array[Dictionary]) -> int:
	var count := 0
	for record in trace:
		if str(record.get("effect", "")) == "surface_dispatch_omitted":
			count += 1
	return count
