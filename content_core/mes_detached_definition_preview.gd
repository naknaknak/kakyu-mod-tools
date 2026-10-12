class_name KakyuMesDetachedDefinitionPreview
extends RefCounted

const EventRunnerScript := preload("res://content_core/mes_event_runner.gd")
const RegisteredDefinitionRunnerScript := preload("res://content_core/mes_registered_definition_runner.gd")
const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")
const ContractValues := preload("res://content_core/contract_values.gd")

const DEFAULT_MAX_STEPS := 10000
const MAX_SEGMENTS := 1024

var _runner := EventRunnerScript.new()
var _registered_definition_runner := RegisteredDefinitionRunnerScript.new()


func run(
	code: PackedByteArray,
	definition: Dictionary,
	state: KakyuMesSandboxState,
	max_steps := DEFAULT_MAX_STEPS,
	context := {}
) -> Dictionary:
	var definition_id := int(definition.get("definition_id", -1))
	var body_offset := int(definition.get("body_offset", -1))
	var target_offset := int(definition.get("target_offset", -1))
	var expected_sha := str(definition.get("body_sha256", ""))
	if (
		state == null
		or definition_id < 0
		or body_offset < 0
		or target_offset <= body_offset
		or target_offset > code.size()
		or max_steps <= 0
		or expected_sha.length() != 64
		or ContractValues.sha256(code.slice(body_offset, target_offset)) != expected_sha
	):
		return _result(
			"invalid_definition",
			false,
			definition_id,
			body_offset,
			target_offset,
			body_offset,
			[],
			[],
			[],
			{},
			[],
			"Detached DEF body coordinates or hash are invalid."
		)
	var preview_state := state.duplicate_state()
	var before := preview_state.snapshot()
	var cursor := body_offset
	var trace: Array[Dictionary] = []
	var messages: Array[Dictionary] = []
	var definitions: Array[Dictionary] = []
	var registered_definition_calls: Array[Dictionary] = []
	var registered_definitions: Dictionary = context.get("registered_definitions", {}).duplicate(false)
	var argument_slots: Dictionary = context.get("argument_slots", {}).duplicate(true)
	var expression_stack: Array = context.get("persistent_expression_stack", []).duplicate()
	var terminal_status := "completed"
	var terminal_error := ""
	var terminal_command := -1
	var terminal_resume := -1
	var complete := false
	for _segment_index in range(MAX_SEGMENTS):
		if cursor >= target_offset:
			complete = true
			terminal_status = "completed"
			break
		var remaining_steps := max_steps - trace.size()
		if remaining_steps <= 0:
			terminal_status = "step_limit"
			terminal_error = "Detached DEF preview reached the aggregate step limit."
			break
		var segment := _runner.run(
			code,
			cursor,
			preview_state,
			target_offset,
			remaining_steps,
			{
				"address_table_offsets": context.get("address_table_offsets", []).duplicate(),
				"argument_slots": argument_slots,
				"persistent_expression_stack": expression_stack,
				"protagonist_name": str(context.get("protagonist_name", "")),
				"native_stream_policy": "skip_bounded",
				"native_record_policy": "omit_bounded",
			}
		)
		var segment_trace: Array = segment.get("trace", [])
		if (
			str(segment.get("status", "")) == "definition_invoke_boundary"
			and not segment_trace.is_empty()
			and registered_definitions.has(int(segment_trace[-1].get("definition_id", -1)))
		):
			for record_index in range(segment_trace.size() - 1):
				var prefix_record: Dictionary = segment_trace[record_index].duplicate(true)
				prefix_record["step"] = trace.size()
				prefix_record["detached_definition_id"] = definition_id
				trace.append(prefix_record)
			for untyped_message in segment.get("messages", []):
				var prefix_message: Dictionary = untyped_message.duplicate(true)
				prefix_message["detached_definition_id"] = definition_id
				messages.append(prefix_message)
			for untyped_definition in segment.get("definitions", []):
				definitions.append((untyped_definition as Dictionary).duplicate(true))
			argument_slots = segment.get("argument_slots", argument_slots).duplicate(true)
			expression_stack = segment.get("persistent_expression_stack", expression_stack).duplicate()
			remaining_steps = max_steps - trace.size()
			if remaining_steps <= 0:
				terminal_status = "step_limit"
				terminal_error = "Detached DEF preview reached the aggregate step limit before a registered DEF call."
				break
			cursor = int(segment.get("offset", cursor))
			segment = _registered_definition_runner.run(
				code,
				cursor,
				preview_state,
				target_offset,
				{
					"registered_definitions": registered_definitions,
					"argument_slots": argument_slots,
					"persistent_expression_stack": expression_stack,
					"native_stream_policy": "skip_bounded",
					"native_record_policy": "omit_bounded",
					"registered_definition_native_stream_policy": "skip_bounded",
					"registered_definition_native_record_policy": "omit_bounded",
					"address_table_offsets": context.get("address_table_offsets", []).duplicate(),
				},
				remaining_steps
			)
		for untyped_record in segment.get("trace", []):
			var record: Dictionary = untyped_record.duplicate(true)
			record["step"] = trace.size()
			record["detached_definition_id"] = definition_id
			trace.append(record)
		for untyped_message in segment.get("messages", []):
			var message: Dictionary = untyped_message.duplicate(true)
			message["detached_definition_id"] = definition_id
			messages.append(message)
		for untyped_definition in segment.get("definitions", []):
			definitions.append((untyped_definition as Dictionary).duplicate(true))
		for untyped_call in segment.get("registered_definition_calls", []):
			registered_definition_calls.append((untyped_call as Dictionary).duplicate(true))
		argument_slots = segment.get("argument_slots", argument_slots).duplicate(true)
		expression_stack = segment.get("persistent_expression_stack", expression_stack).duplicate()
		terminal_status = str(segment.get("status", "unknown"))
		terminal_error = str(segment.get("error", ""))
		terminal_command = int(segment.get("command_id", -1))
		terminal_resume = int(segment.get("resume_offset", -1))
		if terminal_status == "dialogue_boundary":
			var resume_offset := int(segment.get("resume_offset", -1))
			if resume_offset <= cursor or resume_offset > target_offset:
				terminal_status = "invalid_dialogue_resume"
				terminal_error = "Detached DEF dialogue continuation left its bounded body."
				break
			cursor = resume_offset
			continue
		cursor = int(segment.get("offset", cursor))
		if terminal_status in ["completed", "script_return"]:
			complete = true
		break
		break
	if terminal_status == "dialogue_boundary":
		if cursor >= target_offset:
			complete = true
			terminal_status = "completed"
		else:
			terminal_status = "segment_limit"
			terminal_error = "Detached DEF preview reached the segment limit."

	var status := "detached_definition_complete" if complete else "detached_definition_%s" % terminal_status
	var result := _result(
		status,
		complete,
		definition_id,
		body_offset,
		target_offset,
		cursor,
		trace,
		messages,
		preview_state.diff(before),
		argument_slots,
		expression_stack,
		terminal_error
	)
	result["terminal_status"] = terminal_status
	result["definitions"] = definitions
	result["registered_definition_calls"] = registered_definition_calls
	result["detached_definition_preview"]["body_sha256"] = expected_sha
	result["detached_definition_preview"]["registered_definition_call_count"] = registered_definition_calls.size()
	result["detached_definition_preview"]["registered_definition_registry_used"] = not registered_definition_calls.is_empty()
	if terminal_command >= 0:
		result["command_id"] = terminal_command
	if terminal_resume >= 0:
		result["resume_offset"] = terminal_resume
	return result


func _result(
	status: String,
	ok: bool,
	definition_id: int,
	body_offset: int,
	target_offset: int,
	offset: int,
	trace: Array[Dictionary],
	messages: Array[Dictionary],
	state_diff: Array[Dictionary],
	argument_slots: Dictionary,
	expression_stack: Array,
	error := ""
) -> Dictionary:
	var result := {
		"ok": ok,
		"schema": ContentCoreVersionScript.MES_DETACHED_DEFINITION_PREVIEW_SCHEMA,
		"status": status,
		"offset": offset,
		"trace": trace,
		"messages": messages,
		"state_diff": state_diff,
		"argument_slots": argument_slots,
		"persistent_expression_stack": expression_stack,
		"registered_definition_calls": [],
		"detached_definition_preview": {
			"definition_id": definition_id,
			"body_offset": body_offset,
			"target_offset": target_offset,
			"selection_source": "explicit_tool_input",
			"caller_resume_executed": false,
			"native_result_mapping_executed": false,
			"sandbox_persisted": false,
			"registered_definition_call_count": 0,
			"registered_definition_registry_used": false,
			"registered_definition_invocation_policy": "explicit_caller_registry_only",
		},
	}
	if not error.is_empty():
		result["error"] = error
	return result
