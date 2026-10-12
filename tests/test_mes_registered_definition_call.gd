extends "res://tests/test_case.gd"

const RegisteredDefinitionCallScript := preload("res://content_core/mes_registered_definition_call.gd")
const SandboxStateScript := preload("res://content_core/mes_sandbox_state.gd")


func _ready() -> void:
	var code := PackedByteArray([
		0x12, 0x41, 0x00,
		0x03, 0x05, 0x00, 0x03, 0xFF, 0x00,
		0x00,
	])
	var definition := {
		"code": code,
		"body_offset": 0,
		"end_offset": code.size(),
		"source": "synthetic DEF 11",
		"source_entry": "DEF_TEST.MES",
	}
	var stopped_state := SandboxStateScript.new(1)
	var stopped := RegisteredDefinitionCallScript.new().run(11, definition, stopped_state)
	_check(
		not stopped.ok
		and stopped.schema == "kakyu_mes_registered_definition_call/v5"
		and stopped.status == "definition_native_record_boundary"
		and stopped.offset == 0
		and stopped.command_id == 0x12
		and not stopped.has("resume_offset")
		and stopped.definition_id == 11
		and stopped_state.read_value("global_u8", 5) == 0
		and stopped.state_diff.is_empty()
		and stopped.omitted_native_record_count == 0,
		"registered DEF call remains fail-closed at a native typed-record dispatch by default"
	)
	var state := SandboxStateScript.new(1)
	var composed := RegisteredDefinitionCallScript.new().run(
		11,
		definition,
		state,
		{
			"argument_slots": {2: 7},
			"persistent_expression_stack": [19],
			"native_record_policy": "omit_bounded",
		}
	)
	_check(
		composed.ok
		and composed.status == "definition_return"
		and composed.source == "synthetic DEF 11"
		and composed.source_entry == "DEF_TEST.MES"
		and state.read_value("global_u8", 5) == 3
		and composed.state_diff.size() == 1
		and composed.omitted_native_presentation_count == 0
		and composed.omitted_native_record_count == 1
		and composed.trace[0].effect == "native_record_effects_omitted",
		"explicit typed-record policy composes one registered DEF body into isolated state"
	)
	_check(
		composed.argument_slots == {2: 7}
		and composed.persistent_expression_stack == [19]
		and composed.trace.size() == 3
		and composed.trace.all(
			func(record: Dictionary) -> bool: return int(record.external_definition_id) == 11 and str(record.external_definition_source) == "synthetic DEF 11" and str(record.source_entry) == "DEF_TEST.MES"
		),
		"registered DEF call preserves caller context and labels every external trace row"
	)
	var invalid_bounds := definition.duplicate(true)
	invalid_bounds["end_offset"] = code.size() + 1
	var invalid := RegisteredDefinitionCallScript.new().run(11, invalid_bounds, SandboxStateScript.new(1))
	_check(
		not invalid.ok and invalid.status == "invalid_definition" and invalid.trace.is_empty(),
		"registered DEF call rejects out-of-range body bounds before execution"
	)
	var invalid_policy := RegisteredDefinitionCallScript.new().run(
		11,
		definition,
		SandboxStateScript.new(1),
		{"native_stream_policy": "invent_effects"}
	)
	_check(
		not invalid_policy.ok and invalid_policy.status == "invalid_policy",
		"registered DEF call rejects an unknown native presentation policy"
	)
	var invalid_record_policy := RegisteredDefinitionCallScript.new().run(
		11,
		definition,
		SandboxStateScript.new(1),
		{"native_record_policy": "invent_effects"}
	)
	_check(
		not invalid_record_policy.ok and invalid_record_policy.status == "invalid_policy",
		"registered DEF call rejects an unknown native typed-record policy"
	)
	await get_tree().process_frame
	get_tree().quit(1 if _failed else 0)
