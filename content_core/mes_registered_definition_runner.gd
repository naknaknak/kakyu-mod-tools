class_name KakyuMesRegisteredDefinitionRunner
extends RefCounted

const EventRunnerScript := preload("res://content_core/mes_event_runner.gd")
const RegisteredDefinitionCallScript := preload("res://content_core/mes_registered_definition_call.gd")
const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")
const ContractValues := preload("res://content_core/contract_values.gd")

const DEFAULT_MAX_STEPS := 10000
const DEFAULT_MAX_DEFINITION_CALLS := 16
const DEFAULT_MAX_DEFINITION_DEPTH := 8

var _runner := EventRunnerScript.new()
var _definition_call := RegisteredDefinitionCallScript.new()


func resume(
	code: PackedByteArray,
	continuation: Dictionary,
	state: KakyuMesSandboxState,
	context := {},
	max_steps := DEFAULT_MAX_STEPS,
	max_definition_calls := DEFAULT_MAX_DEFINITION_CALLS,
	max_definition_depth := DEFAULT_MAX_DEFINITION_DEPTH
) -> Dictionary:
	if str(continuation.get("schema", "")) != ContentCoreVersionScript.MES_REGISTERED_DEFINITION_CONTINUATION_SCHEMA:
		return _result(
			"invalid_continuation", false, -1, [], [], [], [], {}, [], 0,
			"Registered-DEF continuation schema is unsupported."
		)
	if not context is Dictionary:
		return _result(
			"invalid_continuation", false, -1, [], [], [], [], {}, [], 0,
			"Registered-DEF continuation context must be a dictionary."
		)
	for untyped_key in context:
		if str(untyped_key) not in ["registered_definitions", "address_table_offsets", "code_source"]:
			return _result(
				"invalid_continuation", false, -1, [], [], [], [], {}, [], 0,
				"Registered-DEF continuation override is unsupported: %s" % str(untyped_key)
			)
	var runner_context_value = continuation.get("runner_context", null)
	if not runner_context_value is Dictionary:
		return _result(
			"invalid_continuation", false, -1, [], [], [], [], {}, [], 0,
			"Registered-DEF continuation has no runner context."
		)
	if (
		not context.get("registered_definitions", {}) is Dictionary
		or not context.get("address_table_offsets", []) is Array
	):
		return _result(
			"invalid_continuation", false, -1, [], [], [], [], {}, [], 0,
			"Registered-DEF continuation source context is malformed."
		)
	var runner_context: Dictionary = (runner_context_value as Dictionary).duplicate(true)
	runner_context["registered_definitions"] = context.get("registered_definitions", {}).duplicate(false)
	runner_context["address_table_offsets"] = context.get("address_table_offsets", []).duplicate()
	runner_context["_registered_definition_continuation"] = continuation.duplicate(true)
	if context.has("code_source"):
		runner_context["code_source"] = context.code_source
	return run(
		code,
		int(continuation.get("root_start_offset", -1)),
		state,
		int(continuation.get("root_end_offset", -1)),
		runner_context,
		max_steps,
		max_definition_calls,
		max_definition_depth
	)


func run(
	code: PackedByteArray,
	start_offset: int,
	state: KakyuMesSandboxState,
	end_offset := -1,
	context := {},
	max_steps := DEFAULT_MAX_STEPS,
	max_definition_calls := DEFAULT_MAX_DEFINITION_CALLS,
	max_definition_depth := DEFAULT_MAX_DEFINITION_DEPTH
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
		return _result("missing_code_source", false, start_offset, [], [], [], state.diff(before), {}, [], 0, "No MES code source is available for this bytecode.")
	var limit := source.size() if end_offset < 0 else mini(end_offset, source.size())
	if start_offset < 0 or start_offset >= limit:
		return _result("invalid_start", false, start_offset, [], [], [], state.diff(before), {}, [], 0, "Start offset is outside the execution range.")
	if max_steps <= 0 or max_definition_calls <= 0 or max_definition_depth <= 0:
		return _result("invalid_limits", false, start_offset, [], [], [], state.diff(before), {}, [], 0, "Step, registered-DEF call, and call-depth limits must be positive.")
	var registered_definitions: Dictionary = context.get("registered_definitions", {}).duplicate(false)
	var argument_slots: Dictionary = context.get("argument_slots", {}).duplicate(true)
	var expression_stack: Array[int] = []
	for untyped_value in context.get("persistent_expression_stack", []):
		expression_stack.append(int(untyped_value))
	var root_native_stream_policy := str(context.get("native_stream_policy", "stop"))
	var definition_native_stream_policy := str(context.get("registered_definition_native_stream_policy", "stop"))
	var root_native_record_policy := str(context.get("native_record_policy", "stop"))
	var definition_native_record_policy := str(
		context.get("registered_definition_native_record_policy", "stop")
	)
	if (
		root_native_stream_policy not in ["stop", "skip_bounded"]
		or definition_native_stream_policy not in ["stop", "skip_bounded"]
		or root_native_record_policy not in ["stop", "omit_bounded"]
		or definition_native_record_policy not in ["stop", "omit_bounded"]
	):
		return _result(
			"invalid_policy", false, start_offset, [], [], [], state.diff(before),
			argument_slots, expression_stack, 0,
			"Native presentation or typed-record policy is invalid."
		)
	var address_table_offsets: Array = context.get("address_table_offsets", []).duplicate()
	var trace: Array[Dictionary] = []
	var messages: Array[Dictionary] = []
	var calls: Array[Dictionary] = []
	var omitted_native_presentations := 0
	var omitted_native_records := 0
	var frames: Array[Dictionary] = []
	var current_frame := {
		"kind": "root",
		"code": source,
		"cursor": start_offset,
		"end_offset": limit,
		"definition_id": -1,
		"source": "root script",
	}
	var root_binding := _root_binding(source, start_offset, limit, address_table_offsets)
	var definition_bindings := _definition_bindings(registered_definitions)
	var continuation_value = context.get("_registered_definition_continuation", {})
	if continuation_value is Dictionary and not (continuation_value as Dictionary).is_empty():
		var restored := _restore_continuation(
			continuation_value,
			root_binding,
			definition_bindings,
			registered_definitions,
			source
		)
		if not restored.get("ok", false):
			return _result(
				"invalid_continuation", false, -1, [], [], [], state.diff(before),
				argument_slots, expression_stack, 0,
				str(restored.get("error", "Registered-DEF continuation is invalid."))
			)
		calls.assign(restored.calls)
		frames.assign(restored.frames)
		current_frame = restored.current_frame
		argument_slots = restored.argument_slots.duplicate(true)
		expression_stack.assign(restored.persistent_expression_stack)
		omitted_native_presentations = int(restored.omitted_native_presentation_count)
		omitted_native_records = int(restored.omitted_native_record_count)
		if calls.size() > max_definition_calls or frames.size() > max_definition_depth:
			return _result(
				"invalid_continuation", false, -1, [], [], calls, state.diff(before),
				argument_slots, expression_stack, omitted_native_presentations,
				"Registered-DEF continuation exceeds the requested call or depth limit.",
				-1, -1, omitted_native_records
			)
	elif continuation_value != null and (
		not continuation_value is Dictionary or not (continuation_value as Dictionary).is_empty()
	):
		return _result(
			"invalid_continuation", false, -1, [], [], [], state.diff(before),
			argument_slots, expression_stack, 0,
			"Registered-DEF continuation must be a dictionary."
		)
	while trace.size() < max_steps:
		var segment: Dictionary
		if str(current_frame.kind) == "root":
			var runner_context := {
				"argument_slots": argument_slots,
				"persistent_expression_stack": expression_stack,
				"native_stream_policy": root_native_stream_policy,
				"native_record_policy": root_native_record_policy,
			}
			if not address_table_offsets.is_empty():
				runner_context["address_table_offsets"] = address_table_offsets
			runner_context["code_source"] = _frame_source(current_frame)
			segment = _runner.run(
				PackedByteArray(),
				int(current_frame.cursor),
				state,
				int(current_frame.end_offset),
				max_steps - trace.size(),
				runner_context
			)
		else:
			var continuation: Dictionary = current_frame.definition.duplicate(false)
			continuation["body_offset"] = int(current_frame.cursor)
			segment = _definition_call.run(
				int(current_frame.definition_id),
				continuation,
				state,
				{
					"argument_slots": argument_slots,
					"persistent_expression_stack": expression_stack,
					"native_stream_policy": definition_native_stream_policy,
					"native_record_policy": definition_native_record_policy,
				},
				max_steps - trace.size()
			)
		for untyped_record in segment.get("trace", []):
			var record: Dictionary = untyped_record.duplicate(true)
			record["step"] = trace.size()
			record["registered_definition_call_depth"] = 0 if str(current_frame.kind) == "root" else frames.size()
			if _is_native_presentation_omission(record):
				omitted_native_presentations += 1
			elif str(record.get("effect", "")) == "native_record_effects_omitted":
				omitted_native_records += 1
			trace.append(record)
		for untyped_message in segment.get("messages", []):
			messages.append((untyped_message as Dictionary).duplicate(true))
		argument_slots = segment.get("argument_slots", argument_slots).duplicate(true)
		var next_expression_stack: Array = segment.get("persistent_expression_stack", expression_stack.duplicate())
		expression_stack.clear()
		for untyped_value in next_expression_stack:
			expression_stack.append(int(untyped_value))
		var status := str(segment.get("status", "unknown"))
		if str(current_frame.kind) == "definition" and status == "definition_return":
			if frames.is_empty():
				return _result(
					"invalid_definition_return", false, int(segment.get("offset", -1)),
					trace, messages, calls, state.diff(before), argument_slots,
					expression_stack, omitted_native_presentations,
					"Registered DEF returned without a caller frame.", -1, -1,
					omitted_native_records
				)
			current_frame = frames.pop_back()
			continue
		if status != "definition_invoke_boundary":
			if str(current_frame.kind) == "definition":
				var definition_boundary := _result(
					"registered_" + status,
					false,
					int(segment.get("offset", -1)),
					trace,
					messages,
					calls,
					state.diff(before),
					argument_slots,
					expression_stack,
					omitted_native_presentations,
					str(segment.get("error", "Registered DEF execution stopped.")),
					int(segment.get("command_id", -1)),
					int(segment.get("resume_offset", -1)),
					omitted_native_records
				)
				if status == "definition_dialogue_boundary":
					var dialogue_resume := int(segment.get("resume_offset", -1))
					if dialogue_resume > int(current_frame.cursor) and dialogue_resume < int(current_frame.end_offset):
						var resume_frame: Dictionary = current_frame.duplicate(false)
						resume_frame["cursor"] = dialogue_resume
						definition_boundary["continuation"] = _make_continuation(
							root_binding,
							definition_bindings,
							resume_frame,
							frames,
							calls,
							argument_slots,
							expression_stack,
							omitted_native_presentations,
							omitted_native_records,
							root_native_stream_policy,
							definition_native_stream_policy,
							root_native_record_policy,
							definition_native_record_policy,
							address_table_offsets
						)
				return definition_boundary
			return _terminal_result(
				segment,
				trace,
				messages,
				calls,
				state.diff(before),
				argument_slots,
				expression_stack,
				omitted_native_presentations,
				omitted_native_records
			)
		var boundary_trace: Array = segment.get("trace", [])
		var definition_id := int(boundary_trace[-1].get("definition_id", -1)) if not boundary_trace.is_empty() else -1
		var definition: Dictionary = registered_definitions.get(definition_id, {})
		if definition.is_empty():
			return _result(
				"registered_definition_invoke_boundary" if str(current_frame.kind) == "definition" else "definition_invoke_boundary",
				false,
				int(segment.get("offset", current_frame.cursor)),
				trace,
				messages,
				calls,
				state.diff(before),
				argument_slots,
				expression_stack,
				omitted_native_presentations,
				str(segment.get("error", "Registered DEF execution is unavailable.")),
				int(segment.get("command_id", 0x11)),
				int(segment.get("resume_offset", -1)),
				omitted_native_records
			)
		if calls.size() >= max_definition_calls:
			return _result(
				"definition_call_limit", false,
				int(segment.get("offset", current_frame.cursor)), trace, messages, calls,
				state.diff(before), argument_slots, expression_stack,
				omitted_native_presentations,
				"Registered-DEF call count exceeded its limit.", -1, -1,
				omitted_native_records
			)
		if frames.size() >= max_definition_depth:
			return _result(
				"definition_call_depth_limit", false,
				int(segment.get("offset", current_frame.cursor)), trace, messages, calls,
				state.diff(before), argument_slots, expression_stack,
				omitted_native_presentations,
				"Registered-DEF call depth exceeded its limit.", -1, -1,
				omitted_native_records
			)
		var resume_offset := int(segment.get("resume_offset", -1))
		if resume_offset <= int(current_frame.cursor) or resume_offset > int(current_frame.end_offset):
			return _result(
				"invalid_definition_resume", false,
				int(segment.get("offset", current_frame.cursor)), trace, messages, calls,
				state.diff(before), argument_slots, expression_stack,
				omitted_native_presentations,
				"Registered-DEF caller resume coordinate is invalid.", -1, -1,
				omitted_native_records
			)
		var call_index := calls.size()
		calls.append({
			"definition_id": definition_id,
			"caller_definition_id": int(current_frame.definition_id),
			"call_depth": frames.size() + 1,
			"call_offset": int(segment.get("offset", current_frame.cursor)),
			"resume_offset": resume_offset,
			"source": str(definition.get("source", "explicit registered definition")),
			"source_entry": str(definition.get("source_entry", "")),
		})
		current_frame["cursor"] = resume_offset
		current_frame["call_index"] = call_index
		frames.append(current_frame.duplicate(false))
		current_frame = {
			"kind": "definition",
			"definition": definition,
			"code": _definition_source(definition),
			"cursor": int(definition.get("body_offset", -1)),
			"end_offset": int(definition.get("end_offset", -1)),
			"definition_id": definition_id,
			"source": str(definition.get("source", "explicit registered definition")),
		}
	return _result(
		"step_limit", false, int(current_frame.cursor), trace, messages, calls,
		state.diff(before), argument_slots, expression_stack,
		omitted_native_presentations,
		"Registered-DEF script execution reached the step limit.", -1, -1,
		omitted_native_records
	)


func _root_binding(
	source: KakyuMesCodeSource,
	start_offset: int,
	end_offset: int,
	address_table_offsets: Array
) -> Dictionary:
	return {
		"code_sha256": source.sha256_range(0, source.size()),
		"code_size": source.size(),
		"start_offset": start_offset,
		"end_offset": end_offset,
		"address_table_offsets": address_table_offsets.duplicate(),
	}


func _definition_bindings(registered_definitions: Dictionary) -> Dictionary:
	var bindings := {}
	for untyped_id in registered_definitions:
		var definition_id := int(untyped_id)
		var binding_key := "%d:%s" % [typeof(untyped_id), str(untyped_id)]
		var definition_value = registered_definitions[untyped_id]
		if not definition_value is Dictionary:
			bindings[binding_key] = {"valid": false, "definition_id": definition_id}
			continue
		var definition: Dictionary = definition_value
		var definition_source := _definition_source(definition)
		bindings[binding_key] = {
			"definition_id": definition_id,
			"valid": definition_source != null,
			"code_sha256": definition_source.sha256_range(0, definition_source.size()) if definition_source != null else "",
			"code_size": definition_source.size() if definition_source != null else -1,
			"body_offset": int(definition.get("body_offset", -1)),
			"end_offset": int(definition.get("end_offset", -1)),
			"source": str(definition.get("source", "")),
			"source_entry": str(definition.get("source_entry", "")),
		}
	return bindings


func _make_continuation(
	root_binding: Dictionary,
	definition_bindings: Dictionary,
	current_frame: Dictionary,
	frames: Array[Dictionary],
	calls: Array[Dictionary],
	argument_slots: Dictionary,
	expression_stack: Array[int],
	omitted_native_presentations: int,
	omitted_native_records: int,
	root_native_stream_policy: String,
	definition_native_stream_policy: String,
	root_native_record_policy: String,
	definition_native_record_policy: String,
	address_table_offsets: Array
) -> Dictionary:
	var serialized_frames: Array[Dictionary] = []
	for frame in frames:
		serialized_frames.append(_serialize_frame(frame))
	return {
		"schema": ContentCoreVersionScript.MES_REGISTERED_DEFINITION_CONTINUATION_SCHEMA,
		"root_start_offset": int(root_binding.start_offset),
		"root_end_offset": int(root_binding.end_offset),
		"root_binding": root_binding.duplicate(true),
		"definition_bindings": definition_bindings.duplicate(true),
		"current_frame": _serialize_frame(current_frame),
		"frames": serialized_frames,
		"registered_definition_calls": calls.duplicate(true),
		"argument_slots": argument_slots.duplicate(true),
		"persistent_expression_stack": expression_stack.duplicate(),
		"omitted_native_presentation_count": omitted_native_presentations,
		"omitted_native_record_count": omitted_native_records,
		"runner_context": {
			"native_stream_policy": root_native_stream_policy,
			"registered_definition_native_stream_policy": definition_native_stream_policy,
			"native_record_policy": root_native_record_policy,
			"registered_definition_native_record_policy": definition_native_record_policy,
			"address_table_offsets": address_table_offsets.duplicate(),
		},
	}


func _serialize_frame(frame: Dictionary) -> Dictionary:
	var serialized := {
		"kind": str(frame.get("kind", "")),
		"cursor": int(frame.get("cursor", -1)),
		"end_offset": int(frame.get("end_offset", -1)),
		"definition_id": int(frame.get("definition_id", -1)),
	}
	if frame.has("call_index"):
		serialized["call_index"] = int(frame.call_index)
	return serialized


func _restore_continuation(
	continuation: Dictionary,
	root_binding: Dictionary,
	definition_bindings: Dictionary,
	registered_definitions: Dictionary,
	root_source: KakyuMesCodeSource
) -> Dictionary:
	if str(continuation.get("schema", "")) != ContentCoreVersionScript.MES_REGISTERED_DEFINITION_CONTINUATION_SCHEMA:
		return {"ok": false, "error": "Registered-DEF continuation schema is unsupported."}
	if (
		not continuation.get("root_binding", null) is Dictionary
		or continuation.get("root_binding", {}) != root_binding
		or not continuation.get("definition_bindings", null) is Dictionary
		or continuation.get("definition_bindings", {}) != definition_bindings
	):
		return {"ok": false, "error": "Registered-DEF continuation source identities changed."}
	var calls_value = continuation.get("registered_definition_calls", null)
	var frames_value = continuation.get("frames", null)
	var current_value = continuation.get("current_frame", null)
	var argument_slots_value = continuation.get("argument_slots", null)
	var expression_stack_value = continuation.get("persistent_expression_stack", null)
	if (
		not calls_value is Array
		or not frames_value is Array
		or not current_value is Dictionary
		or not argument_slots_value is Dictionary
		or not expression_stack_value is Array
	):
		return {"ok": false, "error": "Registered-DEF continuation frame data is malformed."}
	var calls: Array[Dictionary] = []
	for untyped_call in calls_value:
		if not untyped_call is Dictionary:
			return {"ok": false, "error": "Registered-DEF continuation call trace is malformed."}
		calls.append((untyped_call as Dictionary).duplicate(true))
	var current_result := _inflate_frame(current_value, registered_definitions, root_source, root_binding)
	if not current_result.get("ok", false) or str(current_result.frame.kind) != "definition":
		return {"ok": false, "error": "Registered-DEF continuation current frame is invalid."}
	var current_frame: Dictionary = current_result.frame
	var frames: Array[Dictionary] = []
	var prior_call_index := -1
	for frame_index in range((frames_value as Array).size()):
		var untyped_frame = (frames_value as Array)[frame_index]
		if not untyped_frame is Dictionary:
			return {"ok": false, "error": "Registered-DEF continuation caller frame is malformed."}
		var frame_result := _inflate_frame(untyped_frame, registered_definitions, root_source, root_binding)
		if not frame_result.get("ok", false):
			return {"ok": false, "error": "Registered-DEF continuation caller frame is invalid."}
		var frame: Dictionary = frame_result.frame
		var call_index := int(frame.get("call_index", -1))
		var expected_callee := (
			int(((frames_value as Array)[frame_index + 1] as Dictionary).get("definition_id", -1))
			if frame_index + 1 < (frames_value as Array).size() and (frames_value as Array)[frame_index + 1] is Dictionary
			else int(current_frame.definition_id)
		)
		var call: Dictionary = calls[call_index] if call_index >= 0 and call_index < calls.size() else {}
		var callee_value = registered_definitions.get(expected_callee, {})
		var callee_definition: Dictionary = callee_value if callee_value is Dictionary else {}
		var caller_source: KakyuMesCodeSource = frame.code
		var decoded := caller_source.decode_at(int(call.get("call_offset", -1)))
		if (
			call_index <= prior_call_index
			or call_index >= calls.size()
			or int(call.get("caller_definition_id", -2)) != int(frame.definition_id)
			or int(call.get("definition_id", -1)) != expected_callee
			or int(call.get("call_depth", -1)) != frame_index + 1
			or int(call.get("resume_offset", -1)) != int(frame.cursor)
			or callee_definition.is_empty()
			or str(call.get("source", "")) != str(callee_definition.get("source", "explicit registered definition"))
			or str(call.get("source_entry", "")) != str(callee_definition.get("source_entry", ""))
			or not decoded.get("ok", false)
			or str(decoded.get("op", "")) != "definition_invoke"
			or int(decoded.get("end_offset", -1)) != int(frame.cursor)
		):
			return {"ok": false, "error": "Registered-DEF continuation caller frame no longer matches its invocation."}
		prior_call_index = call_index
		frames.append(frame)
	if frames.is_empty() or frames.size() > calls.size():
		return {"ok": false, "error": "Registered-DEF continuation has no active caller frame."}
	var expression_stack: Array[int] = []
	for untyped_value in expression_stack_value:
		if typeof(untyped_value) != TYPE_INT:
			return {"ok": false, "error": "Registered-DEF continuation expression stack is malformed."}
		expression_stack.append(int(untyped_value))
	var omitted_presentations := int(continuation.get("omitted_native_presentation_count", -1))
	var omitted_records := int(continuation.get("omitted_native_record_count", -1))
	if omitted_presentations < 0 or omitted_records < 0:
		return {"ok": false, "error": "Registered-DEF continuation counters are invalid."}
	return {
		"ok": true,
		"current_frame": current_frame,
		"frames": frames,
		"calls": calls,
		"argument_slots": (argument_slots_value as Dictionary).duplicate(true),
		"persistent_expression_stack": expression_stack,
		"omitted_native_presentation_count": omitted_presentations,
		"omitted_native_record_count": omitted_records,
	}


func _inflate_frame(
	serialized: Dictionary,
	registered_definitions: Dictionary,
	root_source: KakyuMesCodeSource,
	root_binding: Dictionary
) -> Dictionary:
	var kind := str(serialized.get("kind", ""))
	var definition_id := int(serialized.get("definition_id", -1))
	var cursor := int(serialized.get("cursor", -1))
	var end_offset := int(serialized.get("end_offset", -1))
	if kind == "root":
		if definition_id != -1 or end_offset != int(root_binding.end_offset) or cursor < 0 or cursor >= end_offset:
			return {"ok": false}
		var root_frame := serialized.duplicate(true)
		root_frame["code"] = root_source
		root_frame["source"] = "root script"
		return {"ok": true, "frame": root_frame}
	if kind != "definition" or not registered_definitions.has(definition_id):
		return {"ok": false}
	var definition_value = registered_definitions[definition_id]
	if not definition_value is Dictionary:
		return {"ok": false}
	var definition: Dictionary = definition_value
	var definition_source := _definition_source(definition)
	var body_offset := int(definition.get("body_offset", -1))
	if (
		definition_source == null
		or end_offset != int(definition.get("end_offset", -1))
		or cursor < body_offset
		or cursor >= end_offset
	):
		return {"ok": false}
	var definition_frame := serialized.duplicate(true)
	definition_frame["definition"] = definition
	definition_frame["code"] = definition_source
	definition_frame["source"] = str(definition.get("source", "explicit registered definition"))
	return {"ok": true, "frame": definition_frame}


# A registered definition carries either the bytecode it was registered from
# or a code source supplied by a playback package. Both answer the same
# questions; anything else is not a usable definition.
func _definition_source(definition: Dictionary) -> KakyuMesCodeSource:
	var supplied = definition.get("code_source", null)
	if supplied is KakyuMesCodeSource:
		return supplied
	var code_value = definition.get("code", null)
	if code_value is KakyuMesCodeSource:
		return code_value
	if code_value is PackedByteArray:
		return KakyuMesCodeSource.for_bytecode(code_value)
	return null


func _frame_source(frame: Dictionary) -> KakyuMesCodeSource:
	var code_value = frame.get("code", null)
	if code_value is KakyuMesCodeSource:
		return code_value
	return KakyuMesCodeSource.for_bytecode(code_value if code_value is PackedByteArray else PackedByteArray())


func _is_native_presentation_omission(record: Dictionary) -> bool:
	return (
		str(record.get("effect", "")) == "native_presentation_omitted"
		or bool(record.get("native_effect_omitted", false))
	)


func _terminal_result(
	segment: Dictionary,
	trace: Array[Dictionary],
	messages: Array[Dictionary],
	calls: Array[Dictionary],
	state_diff: Array[Dictionary],
	argument_slots: Dictionary,
	expression_stack: Array[int],
	omitted_native_presentations: int,
	omitted_native_records: int
) -> Dictionary:
	return _result(
		str(segment.get("status", "unknown")),
		bool(segment.get("ok", false)),
		int(segment.get("offset", -1)),
		trace,
		messages,
		calls,
		state_diff,
		argument_slots,
		expression_stack,
		omitted_native_presentations,
		str(segment.get("error", "")),
		int(segment.get("command_id", -1)),
		int(segment.get("resume_offset", -1)),
		omitted_native_records
	)


func _result(
	status: String,
	ok: bool,
	offset: int,
	trace: Array[Dictionary],
	messages: Array[Dictionary],
	calls: Array[Dictionary],
	state_diff: Array[Dictionary],
	argument_slots: Dictionary,
	expression_stack: Array[int],
	omitted_native_presentations: int,
	error := "",
	command_id := -1,
	resume_offset := -1,
	omitted_native_records := 0
) -> Dictionary:
	var result := {
		"ok": ok,
		"schema": ContentCoreVersionScript.MES_REGISTERED_DEFINITION_TRACE_SCHEMA,
		"status": status,
		"offset": offset,
		"trace": trace,
		"messages": messages,
		"registered_definition_calls": calls,
		"state_diff": state_diff,
		"argument_slots": argument_slots.duplicate(true),
		"persistent_expression_stack": expression_stack.duplicate(),
		"omitted_native_presentation_count": omitted_native_presentations,
		"omitted_native_record_count": omitted_native_records,
	}
	if not error.is_empty():
		result["error"] = error
	if command_id >= 0:
		result["command_id"] = command_id
	if resume_offset >= 0:
		result["resume_offset"] = resume_offset
	return result
