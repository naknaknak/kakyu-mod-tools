extends "res://tests/test_case.gd"

const LibraryIndexScript := preload("res://content_core/mes_library_index.gd")
const LibraryRunnerScript := preload("res://content_core/mes_library_runner.gd")
const SandboxStateScript := preload("res://content_core/mes_sandbox_state.gd")
const SyntheticArc := preload("res://tests/synthetic_arc.gd")


func _ready() -> void:
	var code := PackedByteArray()
	SyntheticArc.append_registration(code, 28, PackedByteArray([
		0x03, 0x05, 0x00, 0x03, 0xFF, 0x00,
		0x1D, 0x02, 0x1D, 0xFF, 0x00,
		0x00,
	]))
	SyntheticArc.append_registration(code, 29, PackedByteArray([0x0D, 0x41, 0x00, 0x00]))
	var surface_body := PackedByteArray([0x0D, 0x0B, 0xFF])
	for value in [2, 3, 4, 7, 9]:
		surface_body.append_array(PackedByteArray([0x02, value, 0xFF]))
	surface_body.append_array(PackedByteArray([0x00, 0x00]))
	SyntheticArc.append_registration(code, 30, surface_body)
	SyntheticArc.append_registration(code, 31, PackedByteArray([
		0x0D, 0x0B, 0xFF,
		0x02, 0x0D, 0xFF,
		0x02, 0x0A, 0xFF,
		0x02, 0x14, 0xFF,
		0x02, 0x1D, 0xFF,
		0x02, 0x27, 0xFF,
		0x02, 0x00, 0xFF,
		0x00,
		0x00,
	]))
	SyntheticArc.append_registration(code, 32, PackedByteArray([
		0x0D, 0x0B, 0xFF,
		0x02, 0x0D, 0xFF,
		0x02, 0x3D, 0xFF,
		0x00,
		0x00,
	]))
	code.append(0x00)
	var index := LibraryIndexScript.new().build(code)
	_check(index.ok, "synthetic nested shared library indexes")
	var state := SandboxStateScript.new(1)
	var result := LibraryRunnerScript.new().run(code, index, 28, state, {"persistent_expression_stack": [2]})
	_check(
		result.ok
		and result.status == "library_return"
		and result.schema == "kakyu_mes_library_trace/v10"
		and result.routine_id == 28,
		"library runner returns through a nested native routine"
	)
	_check(
		result.calls.size() == 1
		and result.calls[0].caller_routine_id == 28
		and result.calls[0].callee_routine_id == 29
		and result.trace.any(func(record: Dictionary) -> bool: return int(record.library_routine_id) == 29 and str(record.effect) == "native_presentation_omitted"),
		"library runner records the nested call and omitted bounded presentation span"
	)
	_check(
		state.read_value("global_u8", 5) == 3
		and result.state_diff.size() == 1
		and result.omitted_native_presentation_count == 1
		and result.persistent_expression_stack == [2],
		"library runner applies only isolated gameplay writes and preserves the evaluator carry"
	)
	var surface_state := SandboxStateScript.new(1)
	var surface_result := LibraryRunnerScript.new().run(code, index, 30, surface_state)
	_check(
		surface_result.ok
		and surface_result.status == "library_return"
		and surface_result.decoded_surface_operation_count == 1
		and surface_result.omitted_native_presentation_count == 0
		and surface_result.trace[0].effect == "surface_operation_omitted"
		and surface_result.trace[0].surface_mode == 2
		and surface_result.state_diff.is_empty(),
		"library runner counts exact surface operations while leaving native pixels and sandbox state unchanged"
	)
	var display_refresh_result := LibraryRunnerScript.new().run(
		code, index, 31, SandboxStateScript.new(1)
	)
	_check(
		display_refresh_result.ok
		and display_refresh_result.status == "library_return"
		and display_refresh_result.decoded_surface_operation_count == 0
		and display_refresh_result.decoded_surface_display_refresh_count == 1
		and display_refresh_result.unresolved_surface_dispatch_count == 0
		and display_refresh_result.trace[0].effect == "surface_display_refresh_omitted"
		and display_refresh_result.trace[0].surface_mode == 13
		and display_refresh_result.state_diff.is_empty(),
		"library runner counts confirmed display refreshes separately from pixel operations"
	)
	var unresolved_surface_result := LibraryRunnerScript.new().run(
		code, index, 32, SandboxStateScript.new(1)
	)
	_check(
		unresolved_surface_result.ok
		and unresolved_surface_result.status == "library_return"
		and unresolved_surface_result.decoded_surface_operation_count == 0
		and unresolved_surface_result.decoded_surface_display_refresh_count == 0
		and unresolved_surface_result.unresolved_surface_dispatch_count == 1
		and unresolved_surface_result.trace[0].effect == "surface_dispatch_omitted"
		and unresolved_surface_result.state_diff.is_empty(),
		"library runner keeps incomplete mode-13 dispatches unresolved"
	)
	_check(not LibraryRunnerScript.new().run(code, index, 99, SandboxStateScript.new(1)).ok, "library runner rejects a missing root routine")

	var def_code := PackedByteArray([0x12, 0x41, 0x00, 0x00])
	var def_library := PackedByteArray()
	SyntheticArc.append_registration(def_library, 25, PackedByteArray([
		0x11, 0x02, 0x1A, 0xFF, 0x00,
		0x03, 0x09, 0x00, 0x04, 0xFF, 0x00,
		0x00,
	]))
	def_library.append(0x00)
	var def_index := LibraryIndexScript.new().build(def_library)
	var stopped := LibraryRunnerScript.new().run(def_library, def_index, 25, SandboxStateScript.new(1))
	_check(stopped.status == "library_definition_invoke_boundary", "library runner remains fail-closed without an explicit registered DEF body")
	var def_state := SandboxStateScript.new(1)
	var composed := LibraryRunnerScript.new().run(def_library, def_index, 25, def_state, {
		"registered_definitions": {26: {
			"code": def_code,
			"body_offset": 0,
			"end_offset": def_code.size(),
			"source": "synthetic DEF26",
			"source_entry": "DEF_TEST.MES",
		}},
	})
	_check(
		composed.ok
		and composed.status == "library_return"
		and def_state.read_value("global_u8", 9) == 4
		and composed.omitted_native_presentation_count == 0
		and composed.omitted_native_record_count == 1,
		"explicit bounded registered DEF body returns into its library caller"
	)
	var external_definition_found := false
	for record in composed.trace:
		if (
			int(record.get("external_definition_id", -1)) == 26
			and str(record.get("external_definition_source", "")) == "synthetic DEF26"
			and str(record.get("source_entry", "")) == "DEF_TEST.MES"
			and str(record.get("effect", "")) == "native_record_effects_omitted"
		):
			external_definition_found = true
	_check(
		external_definition_found,
		"composed library trace labels external DEF rows and omitted native record effects"
	)
	var invalid_definition := LibraryRunnerScript.new().run(def_library, def_index, 25, SandboxStateScript.new(1), {
		"registered_definitions": {26: {
			"code": def_code,
			"body_offset": 0,
			"end_offset": def_code.size() + 1,
		}},
	})
	_check(
		invalid_definition.status == "invalid_registered_definition"
		and invalid_definition.trace.size() == 1,
		"library runner preserves its fail-closed invalid registered DEF result through the shared primitive"
	)

	var dialogue_library := PackedByteArray()
	SyntheticArc.append_registration(dialogue_library, 32, PackedByteArray([
		0x03, 0x01, 0x00, 0x06, 0xFF, 0x00,
		0x1D, 0x02, 0x21, 0xFF, 0x00,
		0x03, 0x02, 0x00, 0x04, 0xFF, 0x00,
		0x00,
	]))
	SyntheticArc.append_registration(dialogue_library, 33, PackedByteArray([
		0x1D, 0x02, 0x22, 0xFF, 0x00,
		0x03, 0x03, 0x00, 0x06, 0xFF, 0x00,
		0x00,
	]))
	SyntheticArc.append_registration(dialogue_library, 34, PackedByteArray([
		0x01, 0x41, 0x00, 0x13, 0xFF, 0x02, 0x02, 0xFF, 0x00,
		0x03, 0x04, 0x00, 0x08, 0xFF, 0x00,
		0x00,
	]))
	dialogue_library.append(0x00)
	var dialogue_index := LibraryIndexScript.new().build(dialogue_library)
	var dialogue_state := SandboxStateScript.new(1)
	var dialogue_stop := LibraryRunnerScript.new().run(
		dialogue_library,
		dialogue_index,
		32,
		dialogue_state,
		{"argument_slots": {2: 7}, "persistent_expression_stack": [19]}
	)
	var dialogue_continuation: Dictionary = dialogue_stop.get("continuation", {})
	_check(
		not dialogue_stop.ok
		and dialogue_stop.status == "library_dialogue_boundary"
		and dialogue_stop.messages.size() == 1
		and dialogue_continuation.get("schema", "") == "kakyu_mes_library_continuation/v2"
		and dialogue_continuation.get("root_routine_id", -1) == 32
		and dialogue_continuation.get("current_routine_id", -1) == 34
		and dialogue_continuation.get("frames", []).size() == 2
		and dialogue_state.read_value("global_u8", 1) == 6
		and dialogue_state.read_value("global_u8", 2) == 0,
		"library dialogue returns a source-bound continuation with nested caller frames"
	)
	var dialogue_resume := LibraryRunnerScript.new().resume(
		dialogue_library,
		dialogue_index,
		dialogue_continuation,
		dialogue_state
	)
	_check(
		dialogue_resume.ok
		and dialogue_resume.status == "library_return"
		and dialogue_resume.calls.size() == 2
		and dialogue_resume.argument_slots == {2: 7}
		and dialogue_resume.persistent_expression_stack == [19]
		and dialogue_state.read_value("global_u8", 4) == 8
		and dialogue_state.read_value("global_u8", 3) == 6
		and dialogue_state.read_value("global_u8", 2) == 4,
		"library continuation resumes the active routine and unwinds callers in LIFO order"
	)
	var changed_dialogue_library: PackedByteArray = dialogue_library.duplicate()
	changed_dialogue_library[8] = 0x02
	var changed_dialogue_index := LibraryIndexScript.new().build(changed_dialogue_library)
	var changed_dialogue_resume := LibraryRunnerScript.new().resume(
		changed_dialogue_library,
		changed_dialogue_index,
		dialogue_continuation,
		SandboxStateScript.new(1)
	)
	_check(
		not changed_dialogue_resume.ok and changed_dialogue_resume.status == "invalid_continuation",
		"library continuation rejects changed source bytecode before restoring callers"
	)
	var changed_dialogue_index_binding: Dictionary = dialogue_index.duplicate(true)
	changed_dialogue_index_binding["by_id"][34]["end_offset"] = int(changed_dialogue_index_binding.by_id[34].end_offset) - 1
	var changed_index_resume := LibraryRunnerScript.new().resume(
		dialogue_library,
		changed_dialogue_index_binding,
		dialogue_continuation,
		SandboxStateScript.new(1)
	)
	_check(
		not changed_index_resume.ok and changed_index_resume.status == "invalid_continuation",
		"library continuation rejects a changed routine-index binding"
	)
	var shifted_dialogue_continuation: Dictionary = dialogue_continuation.duplicate(true)
	shifted_dialogue_continuation["cursor"] = int(shifted_dialogue_continuation.end_offset)
	var shifted_dialogue_resume := LibraryRunnerScript.new().resume(
		dialogue_library,
		dialogue_index,
		shifted_dialogue_continuation,
		SandboxStateScript.new(1)
	)
	_check(
		not shifted_dialogue_resume.ok and shifted_dialogue_resume.status == "invalid_continuation",
		"library continuation rejects a shifted active-routine resume coordinate"
	)
	var shifted_caller_continuation: Dictionary = dialogue_continuation.duplicate(true)
	shifted_caller_continuation["frames"][0]["resume_offset"] = int(shifted_caller_continuation.frames[0].resume_offset) + 1
	var shifted_caller_resume := LibraryRunnerScript.new().resume(
		dialogue_library,
		dialogue_index,
		shifted_caller_continuation,
		SandboxStateScript.new(1)
	)
	_check(
		not shifted_caller_resume.ok and shifted_caller_resume.status == "invalid_continuation",
		"library continuation rejects a caller resume that no longer matches command 0x1D"
	)
	var direct_dialogue_state := SandboxStateScript.new(1)
	var direct_dialogue_stop := LibraryRunnerScript.new().run(
		dialogue_library, dialogue_index, 34, direct_dialogue_state
	)
	var direct_dialogue_continuation: Dictionary = direct_dialogue_stop.get("continuation", {})
	var direct_dialogue_resume := LibraryRunnerScript.new().resume(
		dialogue_library,
		dialogue_index,
		direct_dialogue_continuation,
		direct_dialogue_state
	)
	_check(
		direct_dialogue_stop.status == "library_dialogue_boundary"
		and direct_dialogue_continuation.get("frames", [1]).is_empty()
		and direct_dialogue_resume.ok
		and direct_dialogue_resume.status == "library_return"
		and direct_dialogue_state.read_value("global_u8", 4) == 8,
		"root shared routine can pause at dialogue and resume without a fabricated caller frame"
	)
	var changed_call_continuation: Dictionary = dialogue_continuation.duplicate(true)
	changed_call_continuation["calls"][0]["callee_routine_id"] = 34
	var changed_call_resume := LibraryRunnerScript.new().resume(
		dialogue_library,
		dialogue_index,
		changed_call_continuation,
		SandboxStateScript.new(1)
	)
	_check(
		not changed_call_resume.ok and changed_call_resume.status == "invalid_continuation",
		"library continuation rejects a changed nested call trace"
	)
	var malformed_arguments: Dictionary = dialogue_continuation.duplicate(true)
	malformed_arguments["argument_slots"] = {2: "seven"}
	var malformed_argument_resume := LibraryRunnerScript.new().resume(
		dialogue_library,
		dialogue_index,
		malformed_arguments,
		SandboxStateScript.new(1)
	)
	_check(
		not malformed_argument_resume.ok and malformed_argument_resume.status == "invalid_continuation",
		"library continuation rejects malformed temporary argument slots"
	)
	var changed_registry_resume := LibraryRunnerScript.new().resume(
		dialogue_library,
		dialogue_index,
		dialogue_continuation,
		SandboxStateScript.new(1),
		{"registered_definitions": {26: {
			"code": def_code,
			"body_offset": 0,
			"end_offset": def_code.size(),
			"source": "late synthetic DEF26",
		}}}
	)
	_check(
		not changed_registry_resume.ok and changed_registry_resume.status == "invalid_continuation",
		"library continuation rejects a changed registered-definition map before later calls"
	)

	var mixed_library := PackedByteArray()
	SyntheticArc.append_registration(mixed_library, 35, PackedByteArray([
		0x03, 0x0A, 0x00, 0x02, 0xFF, 0x00,
		0x1D, 0x02, 0x24, 0xFF, 0x00,
		0x03, 0x0B, 0x00, 0x04, 0xFF, 0x00,
		0x00,
	]))
	SyntheticArc.append_registration(mixed_library, 36, PackedByteArray([
		0x11, 0x02, 0x0B, 0xFF, 0x00,
		0x03, 0x0D, 0x00, 0x06, 0xFF, 0x00,
		0x00,
	]))
	mixed_library.append(0x00)
	var mixed_index := LibraryIndexScript.new().build(mixed_library)
	var mixed_definition_code := PackedByteArray([
		0x01, 0x41, 0x00, 0x13, 0xFF, 0x02, 0x02, 0xFF, 0x00,
		0x03, 0x0C, 0x00, 0x03, 0xFF, 0x00,
		0x00,
	])
	var mixed_definition := {
		"code": mixed_definition_code,
		"body_offset": 0,
		"end_offset": mixed_definition_code.size(),
		"source": "synthetic mixed DEF11",
		"source_entry": "DEF_MIXED.MES",
	}
	var mixed_state := SandboxStateScript.new(1)
	var mixed_stop := LibraryRunnerScript.new().run(
		mixed_library,
		mixed_index,
		35,
		mixed_state,
		{"registered_definitions": {11: mixed_definition}}
	)
	var mixed_continuation: Dictionary = mixed_stop.get("continuation", {})
	_check(
		not mixed_stop.ok
		and mixed_stop.status == "library_dialogue_boundary"
		and mixed_stop.messages.size() == 1
		and mixed_continuation.get("schema", "") == "kakyu_mes_library_continuation/v2"
		and mixed_continuation.get("current_routine_id", -1) == 36
		and mixed_continuation.get("frames", []).size() == 1
		and str(mixed_continuation.get("registered_definition_continuation", {}).get("schema", "")) == "kakyu_mes_registered_definition_continuation/v1"
		and mixed_state.read_value("global_u8", 10) == 2
		and mixed_state.read_value("global_u8", 12) == 0
		and mixed_state.read_value("global_u8", 13) == 0
		and mixed_state.read_value("global_u8", 11) == 0,
		"library continuation composes an active registered-DEF dialogue with its outer routine frame"
	)
	var mixed_resume := LibraryRunnerScript.new().resume(
		mixed_library,
		mixed_index,
		mixed_continuation,
		mixed_state,
		{"registered_definitions": {11: mixed_definition}}
	)
	_check(
		mixed_resume.ok
		and mixed_resume.status == "library_return"
		and mixed_resume.calls.size() == 1
		and mixed_state.read_value("global_u8", 12) == 3
		and mixed_state.read_value("global_u8", 13) == 6
		and mixed_state.read_value("global_u8", 11) == 4,
		"mixed continuation resumes the DEF, current routine, and outer library caller in order"
	)
	var changed_mixed_definition := mixed_definition.duplicate(true)
	var changed_mixed_code: PackedByteArray = mixed_definition_code.duplicate()
	changed_mixed_code[1] = 0x42
	changed_mixed_definition["code"] = changed_mixed_code
	var changed_mixed_resume := LibraryRunnerScript.new().resume(
		mixed_library,
		mixed_index,
		mixed_continuation,
		SandboxStateScript.new(1),
		{"registered_definitions": {11: changed_mixed_definition}}
	)
	_check(
		not changed_mixed_resume.ok and changed_mixed_resume.status == "invalid_continuation",
		"mixed library/DEF continuation rejects a changed registered body before either caller resumes"
	)
	var shifted_mixed_continuation: Dictionary = mixed_continuation.duplicate(true)
	shifted_mixed_continuation["registered_definition_continuation"]["current_frame"]["cursor"] = mixed_definition_code.size()
	var shifted_mixed_resume := LibraryRunnerScript.new().resume(
		mixed_library,
		mixed_index,
		shifted_mixed_continuation,
		SandboxStateScript.new(1),
		{"registered_definitions": {11: mixed_definition}}
	)
	_check(
		not shifted_mixed_resume.ok and shifted_mixed_resume.status == "library_invalid_continuation",
		"mixed library/DEF continuation rejects a shifted active DEF frame before caller restoration"
	)
	await get_tree().process_frame
	get_tree().quit(1 if _failed else 0)
