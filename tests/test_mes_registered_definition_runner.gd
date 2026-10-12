extends "res://tests/test_case.gd"

const RegisteredDefinitionRunnerScript := preload("res://content_core/mes_registered_definition_runner.gd")
const SandboxStateScript := preload("res://content_core/mes_sandbox_state.gd")


func _ready() -> void:
	var root_code := PackedByteArray([
		0x03, 0x01, 0x00, 0x02, 0xFF, 0x00,
		0x11, 0x02, 0x29, 0xFF, 0x00,
		0x03, 0x02, 0x00, 0x04, 0xFF, 0x00,
		0x00,
	])
	var definition_code := PackedByteArray([
		0x12, 0x41, 0x00,
		0x03, 0x05, 0x00, 0x03, 0xFF, 0x00,
		0x00,
	])
	var definition := {
		"code": definition_code,
		"body_offset": 0,
		"end_offset": definition_code.size(),
		"source": "synthetic DEF 41",
		"source_entry": "DEF_TEST.MES",
	}
	var missing_state := SandboxStateScript.new(1)
	var missing := RegisteredDefinitionRunnerScript.new().run(root_code, 0, missing_state)
	_check(
		not missing.ok
		and missing.schema == "kakyu_mes_registered_definition_trace/v7"
		and missing.status == "definition_invoke_boundary"
		and missing.resume_offset == 11
		and missing.registered_definition_calls.is_empty()
		and missing_state.read_value("global_u8", 1) == 2
		and missing_state.read_value("global_u8", 2) == 0,
		"registered-definition runner remains fail-closed when the explicit map lacks a selector"
	)
	var root_record_code := PackedByteArray([0x12, 0x41, 0x00, 0x00])
	var root_record_stopped := RegisteredDefinitionRunnerScript.new().run(
		root_record_code, 0, SandboxStateScript.new(1)
	)
	_check(
		not root_record_stopped.ok
		and root_record_stopped.status == "native_record_boundary"
		and root_record_stopped.omitted_native_record_count == 0,
		"registered-definition runner keeps root typed records fail-closed by default"
	)
	var root_record_omitted := RegisteredDefinitionRunnerScript.new().run(
		root_record_code,
		0,
		SandboxStateScript.new(1),
		-1,
		{"native_record_policy": "omit_bounded"}
	)
	_check(
		root_record_omitted.ok
		and root_record_omitted.status == "script_return"
		and root_record_omitted.omitted_native_record_count == 1
		and root_record_omitted.omitted_native_presentation_count == 0,
		"registered-definition runner applies root typed-record omission only when requested"
	)
	var stopped_state := SandboxStateScript.new(1)
	var stopped := RegisteredDefinitionRunnerScript.new().run(
		root_code,
		0,
		stopped_state,
		-1,
		{"registered_definitions": {41: definition}}
	)
	_check(
		not stopped.ok
		and stopped.status == "registered_definition_native_record_boundary"
		and stopped.registered_definition_calls.size() == 1
		and stopped.trace.size() == 3
		and stopped_state.read_value("global_u8", 1) == 2
		and stopped_state.read_value("global_u8", 5) == 0
		and stopped.omitted_native_record_count == 0,
		"registered-definition runner stops inside a mapped body without explicit typed-record omission"
	)
	var state := SandboxStateScript.new(1)
	var composed := RegisteredDefinitionRunnerScript.new().run(
		root_code,
		0,
		state,
		-1,
		{
			"registered_definitions": {41: definition},
			"registered_definition_native_record_policy": "omit_bounded",
			"argument_slots": {2: 7},
			"persistent_expression_stack": [19],
		}
	)
	var composed_external_trace: Array = composed.trace.filter(
		func(record: Dictionary) -> bool: return record.has("external_definition_id")
	)
	_check(
		composed.ok
		and composed.status == "script_return"
		and composed.registered_definition_calls.size() == 1
		and composed.registered_definition_calls[0].definition_id == 41
		and composed.registered_definition_calls[0].call_offset == 6
		and composed.registered_definition_calls[0].resume_offset == 11
		and composed.registered_definition_calls[0].source_entry == "DEF_TEST.MES"
		and composed_external_trace.all(
			func(record: Dictionary) -> bool: return str(record.source_entry) == "DEF_TEST.MES"
		)
		and composed.trace.size() == 7
		and composed.omitted_native_presentation_count == 0
		and composed.omitted_native_record_count == 1
		and _has_trace_effect(composed.trace, "native_record_effects_omitted"),
		"explicit mapped DEF body returns to the exact root-script continuation"
	)
	_check(
		state.read_value("global_u8", 1) == 2
		and state.read_value("global_u8", 5) == 3
		and state.read_value("global_u8", 2) == 4
		and composed.state_diff.size() == 3
		and composed.argument_slots == {2: 7}
		and composed.persistent_expression_stack == [19],
		"registered-definition composition aggregates isolated body/caller writes and preserves caller context"
	)
	var two_calls := PackedByteArray([
		0x11, 0x02, 0x29, 0xFF, 0x00,
		0x11, 0x02, 0x29, 0xFF, 0x00,
		0x00,
	])
	var limited := RegisteredDefinitionRunnerScript.new().run(
		two_calls,
		0,
		SandboxStateScript.new(1),
		-1,
		{
			"registered_definitions": {41: definition},
			"registered_definition_native_record_policy": "omit_bounded",
		},
		100,
		1
	)
	_check(
		not limited.ok
		and limited.status == "definition_call_limit"
		and limited.registered_definition_calls.size() == 1,
		"registered-definition runner enforces an explicit call-count limit"
	)
	var nested_root := PackedByteArray([0x11, 0x02, 0x29, 0xFF, 0x00, 0x00])
	var nested_definition_11 := PackedByteArray([0x11, 0x02, 0x0C, 0xFF, 0x00, 0x00])
	var nested_definition_12 := PackedByteArray([0x03, 0x06, 0x00, 0x06, 0xFF, 0x00, 0x00])
	var nested_registry := {
		41: {
			"code": nested_definition_11,
			"body_offset": 0,
			"end_offset": nested_definition_11.size(),
			"source": "synthetic DEF 41",
			"source_entry": "DEF11.MES",
		},
		12: {
			"code": nested_definition_12,
			"body_offset": 0,
			"end_offset": nested_definition_12.size(),
			"source": "synthetic DEF 12",
			"source_entry": "DEF12.MES",
		},
	}
	var nested_state := SandboxStateScript.new(1)
	var nested := RegisteredDefinitionRunnerScript.new().run(
		nested_root,
		0,
		nested_state,
		-1,
		{"registered_definitions": nested_registry}
	)
	_check(
		nested.ok
		and nested.status == "script_return"
		and nested.registered_definition_calls.size() == 2
		and nested.registered_definition_calls[0].caller_definition_id == -1
		and nested.registered_definition_calls[0].call_depth == 1
		and nested.registered_definition_calls[1].definition_id == 12
		and nested.registered_definition_calls[1].caller_definition_id == 41
		and nested.registered_definition_calls[1].call_depth == 2
		and nested.registered_definition_calls[0].source_entry == "DEF11.MES"
		and nested.registered_definition_calls[1].source_entry == "DEF12.MES"
		and nested.trace.size() == 6
		and nested_state.read_value("global_u8", 6) == 6,
		"registered-definition runner restores nested DEF and root caller frames in order"
	)
	var dialogue_root := PackedByteArray([
		0x03, 0x01, 0x00, 0x02, 0xFF, 0x00,
		0x11, 0x02, 0x29, 0xFF, 0x00,
		0x03, 0x02, 0x00, 0x04, 0xFF, 0x00,
		0x00,
	])
	var dialogue_definition_code := PackedByteArray([
		0x01, 0x41, 0x00, 0x13, 0xFF, 0x02, 0x02, 0xFF, 0x00,
		0x03, 0x05, 0x00, 0x03, 0xFF, 0x00,
		0x00,
	])
	var dialogue_definition := {
		"code": dialogue_definition_code,
		"body_offset": 0,
		"end_offset": dialogue_definition_code.size(),
		"source": "synthetic dialogue DEF 41",
		"source_entry": "DEF_DIALOGUE.MES",
	}
	var dialogue_state := SandboxStateScript.new(1)
	var dialogue_stop := RegisteredDefinitionRunnerScript.new().run(
		dialogue_root,
		0,
		dialogue_state,
		-1,
		{
			"registered_definitions": {41: dialogue_definition},
			"argument_slots": {2: 7},
			"persistent_expression_stack": [19],
		}
	)
	_check(
		not dialogue_stop.ok
		and dialogue_stop.status == "registered_definition_dialogue_boundary"
		and dialogue_stop.messages.size() == 1
		and dialogue_stop.continuation.schema == "kakyu_mes_registered_definition_continuation/v1"
		and dialogue_stop.continuation.current_frame.definition_id == 41
		and dialogue_stop.continuation.frames.size() == 1
		and dialogue_stop.continuation.frames[0].kind == "root"
		and dialogue_state.read_value("global_u8", 1) == 2
		and dialogue_state.read_value("global_u8", 2) == 0,
		"registered DEF dialogue returns a source-bound continuation with its active root caller frame"
	)
	var dialogue_resume := RegisteredDefinitionRunnerScript.new().resume(
		dialogue_root,
		dialogue_stop.continuation,
		dialogue_state,
		{"registered_definitions": {41: dialogue_definition}}
	)
	_check(
		dialogue_resume.ok
		and dialogue_resume.status == "script_return"
		and dialogue_resume.registered_definition_calls.size() == 1
		and dialogue_resume.argument_slots == {2: 7}
		and dialogue_resume.persistent_expression_stack == [19]
		and dialogue_state.read_value("global_u8", 5) == 3
		and dialogue_state.read_value("global_u8", 2) == 4,
		"registered DEF continuation resumes its body and restores the exact root caller coordinate"
	)
	var changed_dialogue_definition := dialogue_definition.duplicate(true)
	var changed_dialogue_code: PackedByteArray = dialogue_definition_code.duplicate()
	changed_dialogue_code[1] = 0x42
	changed_dialogue_definition["code"] = changed_dialogue_code
	var changed_dialogue_resume := RegisteredDefinitionRunnerScript.new().resume(
		dialogue_root,
		dialogue_stop.continuation,
		SandboxStateScript.new(1),
		{"registered_definitions": {41: changed_dialogue_definition}}
	)
	_check(
		not changed_dialogue_resume.ok and changed_dialogue_resume.status == "invalid_continuation",
		"registered DEF continuation rejects a changed registered body before caller restoration"
	)
	var shifted_dialogue_continuation: Dictionary = dialogue_stop.continuation.duplicate(true)
	shifted_dialogue_continuation["current_frame"]["cursor"] = dialogue_definition_code.size()
	var shifted_dialogue_resume := RegisteredDefinitionRunnerScript.new().resume(
		dialogue_root,
		shifted_dialogue_continuation,
		SandboxStateScript.new(1),
		{"registered_definitions": {41: dialogue_definition}}
	)
	_check(
		not shifted_dialogue_resume.ok and shifted_dialogue_resume.status == "invalid_continuation",
		"registered DEF continuation rejects a shifted body resume coordinate"
	)
	var changed_dialogue_root: PackedByteArray = dialogue_root.duplicate()
	changed_dialogue_root[1] = 0x03
	var changed_root_resume := RegisteredDefinitionRunnerScript.new().resume(
		changed_dialogue_root,
		dialogue_stop.continuation,
		SandboxStateScript.new(1),
		{"registered_definitions": {41: dialogue_definition}}
	)
	_check(
		not changed_root_resume.ok and changed_root_resume.status == "invalid_continuation",
		"registered DEF continuation rejects changed root bytecode"
	)
	var missing_registry_resume := RegisteredDefinitionRunnerScript.new().resume(
		dialogue_root,
		dialogue_stop.continuation,
		SandboxStateScript.new(1),
		{"registered_definitions": {}}
	)
	_check(
		not missing_registry_resume.ok and missing_registry_resume.status == "invalid_continuation",
		"registered DEF continuation rejects a missing registered body"
	)
	var shifted_caller_continuation: Dictionary = dialogue_stop.continuation.duplicate(true)
	shifted_caller_continuation["frames"][0]["cursor"] = 12
	var shifted_caller_resume := RegisteredDefinitionRunnerScript.new().resume(
		dialogue_root,
		shifted_caller_continuation,
		SandboxStateScript.new(1),
		{"registered_definitions": {41: dialogue_definition}}
	)
	_check(
		not shifted_caller_resume.ok and shifted_caller_resume.status == "invalid_continuation",
		"registered DEF continuation rejects a caller resume that no longer matches command 0x11"
	)
	var nested_dialogue_definition_41 := {
		"code": PackedByteArray([
			0x11, 0x02, 0x0C, 0xFF, 0x00,
			0x03, 0x06, 0x00, 0x06, 0xFF, 0x00,
			0x00,
		]),
		"body_offset": 0,
		"end_offset": 12,
		"source": "nested dialogue DEF 41",
		"source_entry": "DEF11.MES",
	}
	var nested_dialogue_definition_12 := {
		"code": PackedByteArray([
			0x01, 0x42, 0x00, 0x13, 0xFF, 0x02, 0x02, 0xFF, 0x00,
			0x03, 0x07, 0x00, 0x07, 0xFF, 0x00,
			0x00,
		]),
		"body_offset": 0,
		"end_offset": 16,
		"source": "nested dialogue DEF 12",
		"source_entry": "DEF12.MES",
	}
	var nested_dialogue_registry := {
		41: nested_dialogue_definition_41,
		12: nested_dialogue_definition_12,
	}
	var nested_dialogue_state := SandboxStateScript.new(1)
	var nested_dialogue_stop := RegisteredDefinitionRunnerScript.new().run(
		nested_root,
		0,
		nested_dialogue_state,
		-1,
		{
			"registered_definitions": nested_dialogue_registry,
			"argument_slots": {3: 11},
			"persistent_expression_stack": [23],
		}
	)
	var nested_dialogue_resume := RegisteredDefinitionRunnerScript.new().resume(
		nested_root,
		nested_dialogue_stop.continuation,
		nested_dialogue_state,
		{"registered_definitions": nested_dialogue_registry}
	)
	_check(
		nested_dialogue_stop.status == "registered_definition_dialogue_boundary"
		and nested_dialogue_stop.continuation.frames.size() == 2
		and nested_dialogue_stop.continuation.current_frame.definition_id == 12
		and nested_dialogue_resume.ok
		and nested_dialogue_resume.status == "script_return"
		and nested_dialogue_resume.registered_definition_calls.size() == 2
		and nested_dialogue_resume.argument_slots == {3: 11}
		and nested_dialogue_resume.persistent_expression_stack == [23]
		and nested_dialogue_state.read_value("global_u8", 7) == 7
		and nested_dialogue_state.read_value("global_u8", 6) == 6,
		"registered DEF continuation unwinds nested definition and root frames in LIFO order"
	)
	var depth_limited := RegisteredDefinitionRunnerScript.new().run(
		nested_root,
		0,
		SandboxStateScript.new(1),
		-1,
		{"registered_definitions": nested_registry},
		100,
		4,
		1
	)
	_check(
		not depth_limited.ok
		and depth_limited.status == "definition_call_depth_limit"
		and depth_limited.registered_definition_calls.size() == 1,
		"registered-definition runner stops before exceeding its nested call-depth limit"
	)
	var invalid_record_policy := RegisteredDefinitionRunnerScript.new().run(
		root_record_code,
		0,
		SandboxStateScript.new(1),
		-1,
		{"registered_definition_native_record_policy": "invent_effects"}
	)
	_check(
		not invalid_record_policy.ok and invalid_record_policy.status == "invalid_policy",
		"registered-definition runner rejects an unknown typed-record policy"
	)
	await get_tree().process_frame
	get_tree().quit(1 if _failed else 0)


func _has_trace_effect(trace: Array, effect: String) -> bool:
	for record in trace:
		if str(record.get("effect", "")) == effect:
			return true
	return false
