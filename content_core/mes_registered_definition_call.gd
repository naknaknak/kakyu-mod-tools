class_name KakyuMesRegisteredDefinitionCall
extends RefCounted

const EventRunnerScript := preload("res://content_core/mes_event_runner.gd")
const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")

const DEFAULT_MAX_STEPS := 10000

var _runner := EventRunnerScript.new()


func run(
	definition_id: int,
	definition: Dictionary,
	state: KakyuMesSandboxState,
	context := {},
	max_steps := DEFAULT_MAX_STEPS
) -> Dictionary:
	var before := state.snapshot()
	if max_steps <= 0:
		return _result(
			"invalid_limits",
			false,
			definition_id,
			[],
			[],
			state.diff(before),
			{},
			[],
			0,
			"Step limit must be positive."
		)
	var source := _definition_source(definition)
	var body_offset := int(definition.get("body_offset", -1))
	var end_offset := int(definition.get("end_offset", -1))
	if (
		source == null
		or body_offset < 0
		or end_offset <= body_offset
		or end_offset > source.size()
	):
		return _result(
			"invalid_definition",
			false,
			definition_id,
			[],
			[],
			state.diff(before),
			{},
			[],
			0,
			"Registered DEF %d has invalid bounded code coordinates." % definition_id
		)
	var native_stream_policy := str(context.get("native_stream_policy", "stop"))
	if native_stream_policy not in ["stop", "skip_bounded"]:
		return _result(
			"invalid_policy",
			false,
			definition_id,
			[],
			[],
			state.diff(before),
			{},
			[],
			0,
			"Registered DEF native-stream policy is invalid."
		)
	var native_record_policy := str(context.get("native_record_policy", "stop"))
	if native_record_policy not in ["stop", "omit_bounded"]:
		return _result(
			"invalid_policy",
			false,
			definition_id,
			[],
			[],
			state.diff(before),
			{},
			[],
			0,
			"Registered DEF native-record policy is invalid."
		)
	var segment := _runner.run(
		PackedByteArray(),
		body_offset,
		state,
		end_offset,
		max_steps,
		{
			"argument_slots": context.get("argument_slots", {}).duplicate(true),
			"persistent_expression_stack": context.get("persistent_expression_stack", []).duplicate(),
			"native_stream_policy": native_stream_policy,
			"native_record_policy": native_record_policy,
			"exclude_provenance_steps": bool(context.get("exclude_provenance_steps", false)),
			"poll_supplies": (context.get("poll_supplies", []) as Array).duplicate(true),
			"code_source": source,
		}
	)
	var trace: Array[Dictionary] = []
	var source_entry := str(definition.get("source_entry", ""))
	var omitted_native_presentations := 0
	var omitted_native_records := 0
	for untyped_record in segment.get("trace", []):
		var record: Dictionary = untyped_record.duplicate(true)
		record["step"] = trace.size()
		record["external_definition_id"] = definition_id
		record["external_definition_source"] = str(definition.get("source", "explicit registered definition"))
		if not source_entry.is_empty():
			record["source_entry"] = source_entry
		if str(record.get("effect", "")) == "native_presentation_omitted":
			omitted_native_presentations += 1
		elif str(record.get("effect", "")) == "native_record_effects_omitted":
			omitted_native_records += 1
		trace.append(record)
	var messages: Array[Dictionary] = []
	for untyped_message in segment.get("messages", []):
		var message: Dictionary = untyped_message.duplicate(true)
		message["external_definition_id"] = definition_id
		if not source_entry.is_empty():
			message["source_entry"] = source_entry
		messages.append(message)
	var argument_slots: Dictionary = segment.get(
		"argument_slots",
		context.get("argument_slots", {})
	).duplicate(true)
	var expression_stack: Array[int] = []
	for untyped_value in segment.get(
		"persistent_expression_stack",
		context.get("persistent_expression_stack", [])
	):
		expression_stack.append(int(untyped_value))
	var segment_status := str(segment.get("status", "unknown"))
	var status := "definition_return"
	if segment_status != "script_return":
		status = segment_status if segment_status.begins_with("definition_") else "definition_" + segment_status
	var result := _result(
		status,
		segment_status == "script_return",
		definition_id,
		trace,
		messages,
		state.diff(before),
		argument_slots,
		expression_stack,
		omitted_native_presentations,
		"" if segment_status == "script_return" else str(segment.get("error", "Registered DEF execution stopped.")),
		str(definition.get("source", "explicit registered definition")),
		omitted_native_records
	)
	result["offset"] = int(segment.get("offset", -1))
	result["source_entry"] = source_entry
	if segment.has("command_id"):
		result["command_id"] = int(segment.command_id)
	if segment.has("resume_offset"):
		result["resume_offset"] = int(segment.resume_offset)
	return result


# A registered definition carries either the bytecode it was registered from or
# a code source supplied by a playback package. See mes_code_source.gd.
func _definition_source(definition: Dictionary) -> KakyuMesCodeSource:
	var supplied = definition.get("code_source", null)
	if supplied is KakyuMesCodeSource:
		return supplied
	var code_value = definition.get("code", null)
	if code_value is PackedByteArray:
		return KakyuMesCodeSource.for_bytecode(code_value)
	return null


func _result(
	status: String,
	ok: bool,
	definition_id: int,
	trace: Array[Dictionary],
	messages: Array[Dictionary],
	state_diff: Array[Dictionary],
	argument_slots: Dictionary,
	expression_stack: Array[int],
	omitted_native_presentations: int,
	error := "",
	source := "",
	omitted_native_records := 0
) -> Dictionary:
	var result := {
		"ok": ok,
		"schema": ContentCoreVersionScript.MES_REGISTERED_DEFINITION_CALL_SCHEMA,
		"status": status,
		"definition_id": definition_id,
		"source": source,
		"trace": trace,
		"messages": messages,
		"state_diff": state_diff,
		"argument_slots": argument_slots.duplicate(true),
		"persistent_expression_stack": expression_stack.duplicate(),
		"omitted_native_presentation_count": omitted_native_presentations,
		"omitted_native_record_count": omitted_native_records,
	}
	if not error.is_empty():
		result["error"] = error
	return result
