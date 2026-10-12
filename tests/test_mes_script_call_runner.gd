extends "res://tests/test_case.gd"

const ScriptCallRunnerScript := preload("res://content_core/mes_script_call_runner.gd")
const SandboxStateScript := preload("res://content_core/mes_sandbox_state.gd")


func _ready() -> void:
	var root_code := PackedByteArray([0x03, 0x01, 0x00, 0x02, 0xFF, 0x00])
	root_code.append_array(_dispatch("CHILD.MES"))
	root_code.append_array(PackedByteArray([0x03, 0x02, 0x00, 0x04, 0xFF, 0x00, 0x00]))
	var child_code := PackedByteArray([
		0x09, 0x02, 0x00, 0x09, 0xFF, 0x00,
		0x03, 0x05, 0x00, 0x03, 0xFF, 0x00,
	])
	child_code.append_array(_dispatch("GRAND.MES"))
	child_code.append_array(PackedByteArray([0x03, 0x06, 0x00, 0x06, 0xFF, 0x00, 0x00]))
	var grand_code := PackedByteArray([0x03, 0x07, 0x00, 0x07, 0xFF, 0x00, 0x00])
	var scripts := {
		"ROOT.MES": _script(root_code),
		"CHILD.MES": _script(child_code),
		"GRAND.MES": _script(grand_code),
	}
	var state := SandboxStateScript.new(1)
	var composed := ScriptCallRunnerScript.new().run(
		scripts,
		"root.mes",
		0,
		state,
		{"argument_slots": {2: 7}, "persistent_expression_stack": [19]}
	)
	_check(
		composed.ok
		and composed.schema == "kakyu_mes_script_call_trace/v3"
		and composed.status == "script_return"
		and composed.current_entry == "ROOT.MES"
		and composed.trace.size() == 11
		and composed.script_calls.size() == 2
		and composed.script_calls[0].caller_entry == "ROOT.MES"
		and composed.script_calls[0].callee_entry == "CHILD.MES"
		and composed.script_calls[0].call_depth == 1
		and composed.script_calls[0].returned
		and composed.script_calls[1].caller_entry == "CHILD.MES"
		and composed.script_calls[1].callee_entry == "GRAND.MES"
		and composed.script_calls[1].call_depth == 2
		and composed.script_calls[1].returned,
		"script-call runner composes two explicit nested MES targets and restores both callers"
	)
	_check(
		state.read_value("global_u8", 1) == 2
		and state.read_value("global_u8", 2) == 4
		and state.read_value("global_u8", 5) == 3
		and state.read_value("global_u8", 6) == 6
		and state.read_value("global_u8", 7) == 7
		and composed.state_diff.size() == 6,
		"nested MES scripts share only the isolated gameplay sandbox"
	)
	# Core 0.377.0 (TD-56): the child's command 0x09 wrote global_i32[2] = 9. That is the
	# one original storage, so the root's restored provenance slot {2: 7} does not
	# re-impose 7 over it when the frame returns.
	_check(
		state.read_value("global_i32", 2) == 9
		and composed.state_diff.filter(func(row: Dictionary) -> bool: return str(row.storage) == "global_i32") == [
			{"storage": "global_i32", "bank": 0, "index": 2, "before": 0, "after": 9},
		],
		"a callee's command 0x09 write lands in global_i32 and survives the caller frame's restore of its provenance slots"
	)
	_check(
		composed.argument_slots == {2: 7}
		and composed.persistent_expression_stack == [19]
		and composed.trace.any(func(record: Dictionary) -> bool: return str(record.source_entry) == "GRAND.MES" and int(record.script_call_depth) == 2),
		"fresh callee temporary contexts do not replace the restored root tool context"
	)

	var missing := ScriptCallRunnerScript.new().run(
		{"ROOT.MES": _script(root_code)},
		"ROOT.MES",
		0,
		SandboxStateScript.new(1)
	)
	_check(
		not missing.ok
		and missing.status == "script_dispatch_boundary"
		and missing.current_entry == "ROOT.MES"
		and missing.resume_offset == _dispatch("CHILD.MES").size() + 6
		and missing.script_calls.is_empty(),
		"script-call runner fails closed when a decoded target is absent from the explicit map"
	)

	var call_limited := ScriptCallRunnerScript.new().run(
		scripts,
		"ROOT.MES",
		0,
		SandboxStateScript.new(1),
		{},
		100,
		1
	)
	_check(
		not call_limited.ok
		and call_limited.status == "script_call_limit"
		and call_limited.script_calls.size() == 1,
		"script-call runner enforces its aggregate nested-call limit"
	)
	var depth_limited := ScriptCallRunnerScript.new().run(
		scripts,
		"ROOT.MES",
		0,
		SandboxStateScript.new(1),
		{},
		100,
		10,
		1
	)
	_check(
		not depth_limited.ok
		and depth_limited.status == "script_call_depth_limit"
		and depth_limited.script_calls.size() == 1,
		"script-call runner stops before exceeding its explicit call-depth limit"
	)

	var dialogue_root := _dispatch("TALK.MES")
	dialogue_root.append(0x00)
	var talk_code := PackedByteArray([0x01, 0x41, 0x00, 0x13, 0xFF, 0x02, 0x02, 0xFF, 0x00, 0x00])
	var dialogue_scripts := {
		"ROOT.MES": _script(dialogue_root),
		"TALK.MES": _script(talk_code),
	}
	var stopped_state := SandboxStateScript.new(1)
	var stopped_dialogue := ScriptCallRunnerScript.new().run(
		dialogue_scripts,
		"ROOT.MES",
		0,
		stopped_state,
		{"argument_slots": {2: 7}, "persistent_expression_stack": [19]}
	)
	_check(
		stopped_dialogue.status == "dialogue_boundary"
		and stopped_dialogue.current_entry == "TALK.MES"
		and stopped_dialogue.script_call_depth == 1
		and stopped_dialogue.messages.size() == 1
		and stopped_dialogue.continuation.schema == "kakyu_mes_script_call_continuation/v1"
		and stopped_dialogue.continuation.current_entry == "TALK.MES"
		and stopped_dialogue.continuation.frames.size() == 1,
		"nested dialogue remains a visible boundary by default"
	)
	var resumed_dialogue := ScriptCallRunnerScript.new().resume(
		dialogue_scripts,
		stopped_dialogue.continuation,
		stopped_state
	)
	_check(
		resumed_dialogue.ok
		and resumed_dialogue.status == "script_return"
		and resumed_dialogue.current_entry == "ROOT.MES"
		and resumed_dialogue.script_calls.size() == 1
		and resumed_dialogue.script_calls[0].returned
		and resumed_dialogue.argument_slots == {2: 7}
		and resumed_dialogue.persistent_expression_stack == [19]
		and resumed_dialogue.dialogue_boundary_count == 1,
		"resumable nested dialogue returns through the saved caller frame and restores its temporary context"
	)
	var changed_dialogue_scripts := dialogue_scripts.duplicate(true)
	var changed_talk: Dictionary = changed_dialogue_scripts["TALK.MES"]
	var changed_talk_code: PackedByteArray = changed_talk.bytecode.duplicate()
	changed_talk_code[1] = 0x42
	changed_talk["bytecode"] = changed_talk_code
	changed_dialogue_scripts["TALK.MES"] = changed_talk
	var changed_resume := ScriptCallRunnerScript.new().resume(
		changed_dialogue_scripts,
		stopped_dialogue.continuation,
		stopped_state
	)
	_check(
		not changed_resume.ok and changed_resume.status == "invalid_continuation",
		"nested dialogue continuation rejects a changed script map before restoring its caller"
	)
	var shifted_continuation: Dictionary = stopped_dialogue.continuation.duplicate(true)
	shifted_continuation["resume_offset"] = talk_code.size()
	var shifted_resume := ScriptCallRunnerScript.new().resume(
		dialogue_scripts,
		shifted_continuation,
		stopped_state
	)
	_check(
		not shifted_resume.ok and shifted_resume.status == "invalid_continuation",
		"nested dialogue continuation rejects a shifted callee resume coordinate"
	)
	var deep_root := _dispatch("CHILD.MES")
	deep_root.append(0x00)
	var deep_child := _dispatch("TALK.MES")
	deep_child.append(0x00)
	var deep_scripts := {
		"ROOT.MES": _script(deep_root),
		"CHILD.MES": _script(deep_child),
		"TALK.MES": _script(talk_code),
	}
	var deep_state := SandboxStateScript.new(1)
	var deep_stop := ScriptCallRunnerScript.new().run(
		deep_scripts,
		"ROOT.MES",
		0,
		deep_state,
		{"argument_slots": {3: 11}, "persistent_expression_stack": [23]}
	)
	var deep_resume := ScriptCallRunnerScript.new().resume(deep_scripts, deep_stop.continuation, deep_state)
	_check(
		deep_stop.status == "dialogue_boundary"
		and deep_stop.script_call_depth == 2
		and deep_stop.continuation.frames.size() == 2
		and deep_resume.ok
		and deep_resume.current_entry == "ROOT.MES"
		and deep_resume.script_calls.size() == 2
		and deep_resume.script_calls[0].returned
		and deep_resume.script_calls[1].returned
		and deep_resume.argument_slots == {3: 11}
		and deep_resume.persistent_expression_stack == [23],
		"nested dialogue continuation unwinds multiple caller frames in LIFO order"
	)
	var limited_deep_resume := ScriptCallRunnerScript.new().resume(
		deep_scripts,
		deep_stop.continuation,
		deep_state,
		{},
		100,
		10,
		1
	)
	_check(
		not limited_deep_resume.ok and limited_deep_resume.status == "invalid_continuation",
		"resuming a nested dialogue cannot bypass a lower explicit call-depth limit"
	)
	var changed_frame: Dictionary = deep_stop.continuation.duplicate(true)
	changed_frame.frames[0].cursor = int(changed_frame.frames[0].cursor) + 1
	var changed_frame_resume := ScriptCallRunnerScript.new().resume(deep_scripts, changed_frame, deep_state)
	_check(
		not changed_frame_resume.ok and changed_frame_resume.status == "invalid_continuation",
		"nested dialogue continuation rejects a caller frame whose physical resume changed"
	)
	var continued_dialogue := ScriptCallRunnerScript.new().run(
		dialogue_scripts,
		"ROOT.MES",
		0,
		SandboxStateScript.new(1),
		{"dialogue_policy": "continue"}
	)
	_check(
		continued_dialogue.ok
		and continued_dialogue.status == "script_return"
		and continued_dialogue.dialogue_boundary_count == 1
		and continued_dialogue.messages.size() == 1
		and continued_dialogue.script_calls[0].returned,
		"explicit continue policy crosses nested dialogue and restores its caller"
	)

	var menu_root := _dispatch("MENU.MES")
	menu_root.append(0x00)
	var menu_code := PackedByteArray([
		0x10, 0x02, 0x00, 0xFF, 0x00, 13, 0, 0, 0,
		0x01, 0x41, 0x00, 0x00,
		0x10, 0x02, 0x02, 0xFF, 0x00, 26, 0, 0, 0,
		0x01, 0x42, 0x00, 0x00,
		0x1D, 0x02, 0x28, 0xFF, 0x00,
	])
	var nested_definitions := ScriptCallRunnerScript.new().run(
		{"ROOT.MES": _script(menu_root), "MENU.MES": _script(menu_code)},
		"ROOT.MES",
		0,
		SandboxStateScript.new(1)
	)
	_check(
		nested_definitions.ok
		and nested_definitions.status == "def_selection_boundary"
		and nested_definitions.current_entry == "MENU.MES"
		and nested_definitions.script_call_depth == 1
		and nested_definitions.definitions.size() == 2
		and nested_definitions.definitions[0].source_entry == "MENU.MES"
		and nested_definitions.definitions[0].script_call_depth == 1
		and nested_definitions.definitions[0].messages[0].source_entry == "MENU.MES",
		"nested local DEF choices retain their source entry and call depth at the visible boundary"
	)
	var grouped_menu_code := PackedByteArray([
		0x1B, 0x02, 0x00, 0xFF, 0x00,
		0x10, 0x02, 0x00, 0xFF, 0x00, 18, 0, 0, 0,
		0x01, 0x41, 0x00, 0x00,
		0x10, 0x02, 0x31, 0xFF, 0x00, 31, 0, 0, 0,
		0x01, 0x42, 0x00, 0x00,
		0x1B, 0x02, 0x01, 0xFF, 0x00,
		0x10, 0x02, 0x00, 0xFF, 0x00, 49, 0, 0, 0,
		0x01, 0x43, 0x00, 0x00,
		0x1D, 0x02, 0x28, 0xFF, 0x00,
	])
	var nested_grouped_definitions := ScriptCallRunnerScript.new().run(
		{"ROOT.MES": _script(menu_root), "MENU.MES": _script(grouped_menu_code)},
		"ROOT.MES",
		0,
		SandboxStateScript.new(1)
	)
	var nested_groups: Dictionary = nested_grouped_definitions.get("definition_groups", {})
	_check(
		nested_grouped_definitions.status == "def_selection_boundary"
		and nested_grouped_definitions.definitions.size() == 2
		and nested_grouped_definitions.selection_definition_group == 0
		and nested_grouped_definitions.registered_definition_count == 3
		and nested_grouped_definitions.definition_group_order == [0, 1]
		and (nested_groups[0] as Array).size() == 2
		and (nested_groups[1] as Array).size() == 1
		and str((nested_groups[1] as Array)[0].source_entry) == "MENU.MES"
		and int((nested_groups[1] as Array)[0].script_call_depth) == 1
		and str((nested_groups[1] as Array)[0].messages[0].source_entry) == "MENU.MES",
		"nested MES terminals retain grouped DEF ownership and decorate every group with source provenance"
	)
	var selected_definition := ScriptCallRunnerScript.new().run(
		{"ROOT.MES": _script(menu_root), "MENU.MES": _script(menu_code)},
		"ROOT.MES",
		0,
		SandboxStateScript.new(1),
		{"local_definition_choices": [2]},
		100
	)
	var has_explicit_choice_trace := (selected_definition.get("trace", []) as Array).any(
		func(record: Dictionary) -> bool: return str(record.get("selection_policy", "")) == "explicit_tool_choice" and int(record.get("selected_definition_id", -1)) == 2 and str(record.get("source_entry", "")) == "MENU.MES"
	)
	_check(
		selected_definition.ok
		and selected_definition.status == "script_return"
		and selected_definition.current_entry == "ROOT.MES"
		and selected_definition.script_calls[0].returned
		and selected_definition.messages.size() == 1
		and selected_definition.messages[0].raw_hex == "42"
		and has_explicit_choice_trace,
		"an explicit local choice executes only its bounded body and then restores the script caller"
	)
	var invalid_definition := ScriptCallRunnerScript.new().run(
		{"ROOT.MES": _script(menu_root), "MENU.MES": _script(menu_code)},
		"ROOT.MES",
		0,
		SandboxStateScript.new(1),
		{"local_definition_choices": [9]}
	)
	_check(
		not invalid_definition.ok
		and invalid_definition.status == "invalid_definition_choice"
		and invalid_definition.current_entry == "MENU.MES"
		and invalid_definition.definitions.size() == 2,
		"an explicit local choice fails closed when its ID is absent from the reached boundary"
	)

	var unsafe := ScriptCallRunnerScript.new().run(
		{"../ROOT.MES": _script(PackedByteArray([0x00]))},
		"../ROOT.MES",
		0,
		SandboxStateScript.new(1)
	)
	_check(not unsafe.ok and unsafe.status == "invalid_scripts", "script-call runner rejects unsafe script-map names")

	await get_tree().process_frame
	get_tree().quit(1 if _failed else 0)


func _script(code: PackedByteArray) -> Dictionary:
	return {"bytecode": code, "code_size": code.size(), "address_table_offsets": []}


func _dispatch(entry_name: String) -> PackedByteArray:
	var result := PackedByteArray([0x0F, 0x01])
	result.append_array(entry_name.to_lower().to_ascii_buffer())
	result.append_array(PackedByteArray([0x00, 0x00]))
	return result
