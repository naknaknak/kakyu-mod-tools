extends "res://tests/test_case.gd"

const StartupContextScript := preload("res://content_core/mes_startup_context.gd")


func _ready() -> void:
	var code := PackedByteArray([0x14, 0x07, 0xFF, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00])
	var document := {
		"ok": true,
		"bytecode": code,
		"entry_sha256": "synthetic-sha",
		"source": {"entry": "DEF_TEST.MES"},
	}
	var projection := StartupContextScript.new().build(document)
	_check(
		projection.ok
		and projection.schema == "kakyu_mes_startup_context/v2"
		and projection.registration_count == 1
		and projection.selector_order == [7]
		and projection.trace_count == 2
		and projection.trace_effect_counts == {"bootstrap_transfer": 1, "script_return": 1}
		and projection.message_count == 0
		and projection.gameplay_state_diff_count == 0,
		"startup context projection follows only the bounded zero-start registration path"
	)
	if projection.ok:
		var registration: Dictionary = projection.registrations[0]
		var registered_definition: Dictionary = projection.registered_definitions[7]
		_check(
			registration.registration_offset == 0
			and registration.body_offset == 7
			and registration.skip_target == 8
			and registration.body_size == 1
			and registration.source == "DEF_TEST.MES:0x0"
			and registration.source_entry == "DEF_TEST.MES"
			and registered_definition.code == code
			and registered_definition.body_offset == 7
			and registered_definition.end_offset == 8
			and registered_definition.source == "DEF_TEST.MES:0x0"
			and registered_definition.source_entry == "DEF_TEST.MES",
			"startup context projection retains runtime-only body bounds for the library runner"
		)
		_check(
			projection.serialization_policy == "runtime_only_contains_source_bytecode"
			and projection.body_execution_semantics == "not_executed_during_projection",
			"startup context projection labels its non-cache and non-execution policy"
		)

	var dialogue_code := PackedByteArray([0x14, 0x07, 0xFF, 0x08, 0x00, 0x00, 0x00, 0x00, 0x01, 0x41, 0x00])
	var dialogue_document := document.duplicate(true)
	dialogue_document["bytecode"] = dialogue_code
	var dialogue_projection := StartupContextScript.new().build(dialogue_document)
	_check(
		not dialogue_projection.ok
		and str(dialogue_projection.error).contains("confirmed script return"),
		"startup context projection fails closed when the zero-start path reaches dialogue"
	)

	var invalid_document := document.duplicate(true)
	invalid_document["bytecode"] = PackedByteArray([0x14, 0x07, 0xFF, 0xFF, 0xFF, 0xFF, 0x7F, 0x00])
	var invalid_projection := StartupContextScript.new().build(invalid_document)
	_check(
		not invalid_projection.ok,
		"startup context projection rejects an out-of-bounds registration path"
	)

	var state_write_code := PackedByteArray([0x14, 0x07, 0xFF, 0x08, 0x00, 0x00, 0x00, 0x00])
	state_write_code.append_array(PackedByteArray([
		0x04, 0x04,
		0xF1, 20, 0, 0xFF, 1,
		0x80, 4, 5, 0xE0, 0xFF, 0,
		0x00,
	]))
	var state_write_document := document.duplicate(true)
	state_write_document["bytecode"] = state_write_code
	var state_write_projection := StartupContextScript.new().build(state_write_document)
	_check(
		not state_write_projection.ok
		and str(state_write_projection.error).contains("changed gameplay sandbox state"),
		"startup context projection rejects a returning path that changes gameplay state"
	)

	var duplicate_code := PackedByteArray([
		0x14, 0x07, 0xFF, 0x08, 0x00, 0x00, 0x00, 0x00,
		0x14, 0x07, 0xFF, 0x10, 0x00, 0x00, 0x00, 0x00,
		0x00,
	])
	var duplicate_document := document.duplicate(true)
	duplicate_document["bytecode"] = duplicate_code
	var duplicate_projection := StartupContextScript.new().build(duplicate_document)
	_check(
		not duplicate_projection.ok
		and str(duplicate_projection.error).contains("Duplicate startup context selector 7"),
		"startup context projection rejects ambiguous duplicate selectors"
	)
	await get_tree().process_frame
	get_tree().quit(1 if _failed else 0)
