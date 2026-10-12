extends "res://tests/test_case.gd"

const RunnerScript := preload("res://content_core/mes_event_runner.gd")
const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")
const DetachedDefinitionPreviewScript := preload("res://content_core/mes_detached_definition_preview.gd")
const SandboxStateScript := preload("res://content_core/mes_sandbox_state.gd")
const MesRecordGrammar := preload("res://tests/mes_record_grammar.gd")


func _ready() -> void:
	var runner := RunnerScript.new()
	var state := SandboxStateScript.new(123)
	state.write_value("state_u16", 4, 6)
	state.write_value("state_u16", 7, 0x120)
	state.set_native_relative_u8_aliases_enabled(true)
	state.write_relative_u8_block(0x120, PackedByteArray([9, 8]))
	state.set_native_banked_u16_zero_baseline(17)
	var cloned_state: KakyuMesSandboxState = state.duplicate_state()
	_check(
		cloned_state.read_value("state_u16", 4) == 6
		and cloned_state.read_value("banked_u8", 0, 7) == 9
		and cloned_state.read_value("banked_u16", 0, 0) == 17,
		"sandbox state duplication preserves stored values and native preview layout"
	)
	cloned_state.write_value("state_u16", 4, 99)
	_check(state.read_value("state_u16", 4) == 6, "sandbox state duplication isolates later writes")
	_check(state.random_below(10000) == cloned_state.random_below(10000), "sandbox state duplication preserves deterministic random position")
	var detached_code := PackedByteArray([
		0x01, 0x41, 0x00,
		0x0D, 0x13, 0xFF, 0x02, 0x02, 0xFF, 0x00,
		0x01, 0x42, 0x00,
		0x0D, 0x13, 0xFF, 0x02, 0x02, 0xFF, 0x00,
		0x00,
	])
	var detached_definition := {
		"definition_id": 4,
		"body_offset": 0,
		"target_offset": detached_code.size(),
		"body_sha256": _sha256(detached_code),
	}
	var detached_preview := DetachedDefinitionPreviewScript.new()
	var detached_result := detached_preview.run(detached_code, detached_definition, state)
	_check(
		detached_result.ok
		and detached_result.schema == "kakyu_mes_detached_definition_preview/v5"
		and detached_result.status == "detached_definition_complete"
		and detached_result.terminal_status == "script_return",
		"detached DEF preview reaches its bounded return through repeated dialogue boundaries"
	)
	_check(
		detached_result.messages.size() == 2
		and detached_result.messages[0].raw_hex == "41"
		and detached_result.messages[1].raw_hex == "42",
		"detached DEF preview collects every bounded dialogue message in order"
	)
	_check(
		detached_result.detached_definition_preview.definition_id == 4
		and detached_result.detached_definition_preview.body_sha256 == detached_definition.body_sha256
		and not detached_result.detached_definition_preview.caller_resume_executed
		and not detached_result.detached_definition_preview.native_result_mapping_executed
		and not detached_result.detached_definition_preview.sandbox_persisted
		and state.read_value("state_u16", 4) == 6,
		"detached DEF preview preserves its explicit non-caller, disposable-sandbox contract"
	)
	var stale_definition := detached_definition.duplicate(true)
	stale_definition["body_sha256"] = "0".repeat(64)
	var stale_result := detached_preview.run(detached_code, stale_definition, state)
	_check(
		not stale_result.ok and stale_result.status == "invalid_definition" and stale_result.trace.is_empty(),
		"detached DEF preview rejects a stale body hash before execution"
	)
	var nested_detached_code := PackedByteArray([
		0x01, 0x41, 0x00,
		0x11, 0x02, 0x63, 0xFF, 0x00,
		0x01, 0x42, 0x00,
		0x00,
	])
	var nested_registered_code := PackedByteArray([0x01, 0x43, 0x00, 0x00])
	var nested_detached_definition := {
		"definition_id": 1,
		"body_offset": 0,
		"target_offset": nested_detached_code.size(),
		"body_sha256": _sha256(nested_detached_code),
	}
	var missing_nested := detached_preview.run(nested_detached_code, nested_detached_definition, state)
	_check(
		not missing_nested.ok
		and missing_nested.terminal_status == "definition_invoke_boundary"
		and missing_nested.registered_definition_calls.is_empty(),
		"detached DEF preview keeps nested invocation fail-closed without an explicit registry"
	)
	var composed_nested := detached_preview.run(
		nested_detached_code,
		nested_detached_definition,
		state,
		DetachedDefinitionPreviewScript.DEFAULT_MAX_STEPS,
		{
			"registered_definitions": {
				99: {
					"code": nested_registered_code,
					"body_offset": 0,
					"end_offset": nested_registered_code.size(),
					"source": "synthetic registered DEF 99",
					"source_entry": "DEF_TEST.MES",
				},
			},
		}
	)
	_check(
		composed_nested.ok
		and composed_nested.status == "detached_definition_complete"
		and composed_nested.messages.size() == 3
		and composed_nested.messages[0].raw_hex == "41"
		and composed_nested.messages[1].raw_hex == "43"
		and composed_nested.messages[2].raw_hex == "42"
		and composed_nested.messages[1].source_entry == "DEF_TEST.MES"
		and composed_nested.registered_definition_calls.size() == 1
		and composed_nested.registered_definition_calls[0].definition_id == 99
		and composed_nested.registered_definition_calls[0].source_entry == "DEF_TEST.MES",
		"detached DEF preview composes an explicitly registered nested body and restores the outer body"
	)
	_check(
		composed_nested.detached_definition_preview.registered_definition_registry_used
		and composed_nested.detached_definition_preview.registered_definition_call_count == 1
		and not composed_nested.detached_definition_preview.sandbox_persisted
		and state.read_value("state_u16", 4) == 6,
		"nested detached composition reports registry provenance and discards the cloned sandbox"
	)
	var code := PackedByteArray()
	code.append_array(PackedByteArray([0x17, 3, 0, 0, 0]))
	code.append_array(PackedByteArray([0x01, 0x41, 0]))
	code.append_array(PackedByteArray([0x0B, 0x80, 4, 0xF1, 6, 0, 0xEF, 0xFF, 24, 0, 0, 0]))
	code.append_array(PackedByteArray([0x0C, 26, 0, 0, 0]))
	code.append(0x00)
	code.append_array(PackedByteArray([0x81, 0x40, 0]))
	code.append(0x00)

	var true_result := runner.run(code, 0, state)
	_check(true_result.ok and true_result.status == "script_return", "runner stops successfully at the confirmed script-return boundary")
	_check(true_result.offset == 29 and true_result.trace[-1].effect == "script_return", "script return reports its exact coordinate")
	_check(true_result.trace.size() == 6 and true_result.trace[2].effect == "fallthrough", "exact value 1 falls through")
	_check(true_result.trace[3].effect == "continuation", "confirmed continuation target is followed")
	_check(true_result.messages.size() == 2 and true_result.messages[0].raw_hex == "41", "message bytes remain lossless")
	_check(true_result.state_diff.is_empty(), "preview execution does not change sandbox state")

	state.write_value("state_u16", 4, 5)
	var false_result := runner.run(code, 0, state)
	_check(false_result.trace[2].effect == "branch" and false_result.trace[2].next_offset == 24, "non-1 condition takes the branch target")
	_check(false_result.messages.size() == 1, "branch skips the fallthrough continuation path")

	var loop_code := PackedByteArray([0x0C, 0, 0, 0, 0])
	var limited := runner.run(loop_code, 0, state, -1, 3)
	_check(limited.status == "step_limit" and limited.trace.size() == 3, "loop execution obeys the step limit")
	var bad_target := runner.run(PackedByteArray([0x0C, 9, 0, 0, 0]), 0, state)
	_check(bad_target.status == "invalid_target", "out-of-range control-flow target is rejected")

	var address_dispatch_code := PackedByteArray([0x18, 0x01, 0xFF, 0x00, 0x00])
	var address_dispatch_state := SandboxStateScript.new(1)
	var missing_address_table := runner.run(address_dispatch_code, 0, address_dispatch_state)
	_check(
		missing_address_table.status == "address_table_dispatch_boundary"
		and missing_address_table.command_id == 0x18
		and missing_address_table.trace[-1].effect == "address_table_dispatch_boundary"
		and missing_address_table.trace[-1].address_table_index == 1
		and missing_address_table.state_diff.is_empty(),
		"command 0x18 stops when its active MES address table was not supplied"
	)
	var address_dispatch := runner.run(
		address_dispatch_code,
		0,
		address_dispatch_state,
		-1,
		RunnerScript.DEFAULT_MAX_STEPS,
		{"address_table_offsets": [3, 4]}
	)
	_check(
		address_dispatch.status == "script_return"
		and address_dispatch.offset == 4
		and address_dispatch.trace[0].effect == "address_table_dispatch"
		and address_dispatch.trace[0].address_table_index == 1
		and address_dispatch.trace[0].address_table_target == 4
		and address_dispatch.state_diff.is_empty(),
		"command 0x18 dispatches only through the caller-supplied active MES address table"
	)
	var invalid_address_index := runner.run(
		PackedByteArray([0x18, 0x02, 0xFF, 0x00]),
		0,
		SandboxStateScript.new(1),
		-1,
		RunnerScript.DEFAULT_MAX_STEPS,
		{"address_table_offsets": [3]}
	)
	_check(
		invalid_address_index.status == "invalid_address_table_index"
		and invalid_address_index.command_id == 0x18
		and invalid_address_index.trace[-1].effect == "invalid_address_table_index",
		"command 0x18 rejects an expression-selected index outside the active table"
	)
	var invalid_address_target := runner.run(
		PackedByteArray([0x18, 0x00, 0xFF, 0x00]),
		0,
		SandboxStateScript.new(1),
		-1,
		RunnerScript.DEFAULT_MAX_STEPS,
		{"address_table_offsets": [99]}
	)
	_check(
		invalid_address_target.status == "invalid_target"
		and invalid_address_target.command_id == 0x18
		and invalid_address_target.trace[-1].effect == "invalid_address_table_target",
		"command 0x18 rejects an active-table coordinate outside the current bytecode"
	)

	var write_code := PackedByteArray([
		0x03, 0x34, 0x12,
		0xF1, 20, 0, 0xFF, 1,
		0xF3, 0x34, 0x12, 0xF1, 5, 0, 0xE1, 0xFF, 0,
		0x00,
	])
	var write_state := SandboxStateScript.new(1)
	var write_result := runner.run(write_code, 0, write_state)
	_check(write_result.status == "script_return" and write_result.offset == write_code.size() - 1, "write run falls through to the next exact return boundary")
	_check(write_state.read_value("global_u8", 0x1234) == 15, "command 0x03 clamps values above 15")
	_check(write_state.read_value("global_u8", 0x1235) == 10, "command 0x03 expressions observe earlier writes in the same run")
	_check(write_result.state_diff.size() == 2, "command 0x03 reports isolated state changes")
	var dynamic_u8_state := SandboxStateScript.new(1)
	var dynamic_u8_result := runner.run(PackedByteArray([
		0x05, 0x02, 0xFF,
		0x21, 0xFF, 0x01,
		0x22, 0xFF, 0x00,
		0x00,
	]), 0, dynamic_u8_state)
	_check(
		dynamic_u8_result.status == "script_return"
		and dynamic_u8_result.trace[0].effect == "dynamic_global_u8_write_run"
		and dynamic_u8_result.trace[0].write_start == 2
		and dynamic_u8_result.trace[0].write_count == 2
		and dynamic_u8_state.read_value("global_u8", 2) == 33
		and dynamic_u8_state.read_value("global_u8", 3) == 34
		and dynamic_u8_result.state_diff.size() == 2,
		"command 0x05 writes evaluated byte values through its native dynamic global_u8 destination"
	)
	var carried_u8_state := SandboxStateScript.new(1)
	var carried_u8_result := runner.run(PackedByteArray([
		0x05,
		0x01, 0x02, 0xFF,
		0xFF, 0x00,
		0x00,
	]), 0, carried_u8_state)
	_check(
		carried_u8_result.status == "script_return"
		and carried_u8_state.read_value("global_u8", 2) == 1
		and carried_u8_result.trace[0].persistent_expression_steps[0].local_depth == 2
		and carried_u8_result.trace[0].persistent_expression_steps[0].stack_depth_after == 1
		and carried_u8_result.trace[0].persistent_expression_steps[1].local_depth == 0
		and carried_u8_result.trace[0].persistent_expression_steps[1].stack_depth_after == 0
		and not carried_u8_result.trace[0].persistent_expression_steps[1].used_empty_fallback,
		"command 0x05 carries an extra native expression value into the next empty fragment"
	)
	var empty_u8_state := SandboxStateScript.new(1)
	var empty_u8_result := runner.run(PackedByteArray([
		0x05,
		0xFF,
		0x02, 0xFF, 0x00,
		0x00,
	]), 0, empty_u8_state)
	_check(
		empty_u8_result.status == "script_return"
		and empty_u8_state.read_value("global_u8", 0) == 2
		and empty_u8_result.trace[0].persistent_expression_steps[0].used_empty_fallback
		and empty_u8_result.trace[0].persistent_expression_stack_depth == 0,
		"an empty native destination expression falls back to zero when the isolated run has no carry"
	)
	var cross_instruction_state := SandboxStateScript.new(1)
	var cross_instruction_result := runner.run(PackedByteArray([
		0x0A,
		0xFF,
		0x01, 0x02, 0xFF, 0x00,
		0x05,
		0xFF,
		0x03, 0xFF, 0x00,
		0x00,
	]), 0, cross_instruction_state)
	_check(
		cross_instruction_result.status == "script_return"
		and cross_instruction_state.read_value("global_i32", 0) == 2
		and cross_instruction_state.read_value("global_u8", 1) == 3
		and cross_instruction_result.trace[0].persistent_expression_stack_depth == 1
		and cross_instruction_result.trace[1].persistent_expression_steps[0].stack_depth_before == 1
		and cross_instruction_result.trace[1].persistent_expression_steps[0].stack_depth_after == 0,
		"persistent expression carry crosses confirmed command boundaries within one isolated run"
	)
	var truncated_i32_state := SandboxStateScript.new(1)
	var truncated_i32_result := runner.run(PackedByteArray([
		0x0A,
		0xF2, 0x01, 0x00, 0x01, 0x00, 0xFF,
		0x04, 0xFF, 0x00,
		0x00,
	]), 0, truncated_i32_state)
	_check(
		truncated_i32_result.status == "script_return"
		and truncated_i32_result.trace[0].write_start == 1
		and truncated_i32_state.read_value("global_i32", 1) == 4,
		"command 0x0A truncates its native destination to the low 16 bits"
	)

	var state_write_code := PackedByteArray([
		0x04, 4,
		0xF1, 20, 0, 0xFF, 1,
		0x80, 4, 5, 0xE0, 0xFF, 0,
		0x00,
	])
	var state_write_state := SandboxStateScript.new(1)
	var state_write_result := runner.run(state_write_code, 0, state_write_state)
	_check(state_write_result.status == "script_return", "command 0x04 falls through to the next exact return boundary")
	_check(state_write_state.read_value("state_u16", 4) == 20, "command 0x04 writes the first evaluated u16 value")
	_check(state_write_state.read_value("state_u16", 5) == 25, "command 0x04 later values observe earlier writes in the same run")
	_check(
		state_write_result.trace[0].effect == "state_u16_write_run"
		and state_write_result.trace[0].write_count == 2
		and state_write_result.state_diff.size() == 2,
		"command 0x04 trace identifies the isolated state_u16 write range"
	)
	var state_write_wrap_state := SandboxStateScript.new(1)
	var state_write_wrap := runner.run(PackedByteArray([
		0x04, 0xFF, 1, 0xFF, 1, 2, 0xFF, 0,
		0x00,
	]), 0, state_write_wrap_state)
	_check(
		state_write_wrap.status == "script_return"
		and state_write_wrap_state.read_value("state_u16", 0xFF) == 1
		and state_write_wrap_state.read_value("state_u16", 0) == 2
		and state_write_wrap.trace[0].write_index_mask == 0xFF
		and state_write_wrap.trace[0].write_wrapped,
		"command 0x04 reproduces the native byte-index wrap from 255 to zero"
	)

	var banked_u8_code := PackedByteArray([
		0x06, 2, 0xFF, 1,
		3, 0xFF, 1,
		4, 0xFF, 0,
		0x00,
	])
	var banked_u8_state := SandboxStateScript.new(1)
	var banked_u8_result := runner.run(banked_u8_code, 0, banked_u8_state)
	_check(
		banked_u8_result.status == "script_return"
		and banked_u8_result.trace[0].effect == "banked_u8_write_run"
		and banked_u8_result.trace[0].write_storage == "banked_u8"
		and banked_u8_result.trace[0].write_bank == 1
		and banked_u8_state.read_value("banked_u8", 2, 1) == 3
		and banked_u8_state.read_value("banked_u8", 3, 1) == 4
		and banked_u8_result.state_diff.size() == 2,
		"command 0x06 writes continuation-controlled byte values to its selected bank"
	)

	var banked_write_code := PackedByteArray([
		0x07,
		0xF1, 0x9B, 0x00, 0xFF, 0,
		0xF1, 0x9B, 0x00, 0xA0, 0, 1, 0xE0, 0xFF, 1,
		0xF1, 0x9B, 0x00, 0xA0, 0, 0xF1, 2, 0, 0xE0, 0xFF, 0,
		0x00,
	])
	var banked_state := SandboxStateScript.new(1)
	banked_state.write_value("banked_u16", 155, 50, 0)
	var banked_result := runner.run(banked_write_code, 0, banked_state)
	_check(banked_result.status == "script_return" and banked_result.offset == banked_write_code.size() - 1, "command 0x07 falls through to the next exact return boundary")
	_check(banked_state.read_value("banked_u16", 155, 0) == 51, "command 0x07 writes the evaluated value directly to banked_u16")
	_check(banked_state.read_value("banked_u16", 156, 0) == 53, "command 0x07 values observe earlier u16 writes in the same run")
	_check(banked_state.read_value("banked_i32", 155, 0) == 0, "command 0x07 does not write the command 0x08 i32 storage")
	_check(banked_result.state_diff.size() == 2, "command 0x07 reports direct u16 state changes")

	var i32_code := PackedByteArray([
		0x08, 2, 0xFF, 1,
		2, 0xA0, 1, 0xFF, 0,
		0x00,
	])
	var i32_state := SandboxStateScript.new(1)
	i32_state.write_value("banked_u16", 2, 77, 1)
	var i32_result := runner.run(i32_code, 0, i32_state)
	_check(i32_result.status == "script_return" and i32_result.offset == i32_code.size() - 1, "command 0x08 falls through to the next exact return boundary")
	_check(i32_state.read_value("banked_i32", 2, 1) == 77, "command 0x08 writes its evaluated value to banked_i32")
	_check(i32_state.read_value("banked_u16", 2, 1) == 77, "command 0x08 keeps its u16 source distinct")

	var ax_code := PackedByteArray([0x0D, 0x08, 0xFF, 0x02, 0x00, 0xFF, 0x01])
	ax_code.append_array("d01x.ax".to_ascii_buffer())
	ax_code.append_array(PackedByteArray([0x00, 0x02, 0x02, 0xF9, 0x00, 0xFF, 0x00, 0x00]))
	var ax_result := runner.run(ax_code, 0, SandboxStateScript.new(1))
	_check(ax_result.status == "script_return" and ax_result.offset == ax_code.size() - 1, "bounded AX resource marker falls through to the next exact return boundary")
	_check(
		ax_result.trace[0].effect == "ax_resource_marker"
		and ax_result.trace[0].resource_name == "D01X.AX"
		and ax_result.trace[0].presentation_subcommand == 8
		and ax_result.trace[0].execution_selector == 0
		and ax_result.trace[0].data_archive_index == 0
		and ax_result.trace[0].native_consumer_semantics == "data_arc_named_entry_load_confirmed"
		and ax_result.trace[0].native_loader_argument == "banked_i32[0][2]"
		and ax_result.trace[0].native_loader_argument_semantics == "engine_initialized_destination_buffer_pointer"
		and ax_result.trace[0].native_payload_semantics == "unresolved"
		and ax_result.trace[0].gameplay_sandbox_changed == false,
		"runner preserves the confirmed AX Data loader request without applying native payload effects"
	)
	var ax_binding_code := PackedByteArray([
		0x0D, 0x03, 0xFF,
		0x02, 0x00, 0xFF,
		0x02, 0x00, 0xFF,
		0x02, 0x01, 0xFF,
		0x02, 0x02, 0xF9, 0x00, 0xFF,
		0x00,
		0x00,
	])
	var ax_binding_result := runner.run(ax_binding_code, 0, SandboxStateScript.new(1))
	_check(
		ax_binding_result.status == "script_return"
		and ax_binding_result.offset == ax_binding_code.size() - 1
		and ax_binding_result.state_diff.is_empty(),
		"bounded AX consumer binding falls through without applying false global-u8 writes"
	)
	_check(
		ax_binding_result.trace[0].effect == "ax_presentation_binding"
		and ax_binding_result.trace[0].presentation_subcommand == 3
		and ax_binding_result.trace[0].execution_selector == 0
		and ax_binding_result.trace[0].consumer_index == 0
		and ax_binding_result.trace[0].consumer_virtual_slot == 0x08
		and ax_binding_result.trace[0].cell_row == 0
		and ax_binding_result.trace[0].cell_column == 1
		and ax_binding_result.trace[0].buffer_argument == "banked_i32[0][2]"
		and ax_binding_result.trace[0].binding_table_entries == 320
		and ax_binding_result.trace[0].binding_table_bytes == 0x500
		and ax_binding_result.trace[0].native_consumer_semantics == "ax_binding_table_cell_install_confirmed"
		and ax_binding_result.trace[0].native_rendering_semantics == "unresolved"
		and ax_binding_result.trace[0].tool_execution_semantics == "not_executed"
		and ax_binding_result.trace[0].gameplay_sandbox_changed == false,
		"runner retains the exact native AX binding boundary without executing the host consumer"
	)
	var native_control_code := PackedByteArray([
		0x0D, 0x0A, 0xFF, 0x02, 0x01, 0xFF, 0x00,
		0x0D, 0x03, 0xFF, 0x02, 0x06, 0xFF, 0x00,
		0x1F, 0x34, 0x12, 0x56, 0x07,
		0x0D, 0x03, 0xFF, 0x02, 0x07, 0xFF, 0x00,
		0x0D, 0x03, 0xFF, 0x02, 0x08, 0xFF, 0x00,
		0x0D, 0x03, 0xFF, 0x02, 0x02, 0xFF, 0x00,
		0x00,
	])
	var native_control_state := SandboxStateScript.new(1)
	var native_control_result := runner.run(native_control_code, 0, native_control_state)
	_check(
		native_control_result.status == "script_return"
		and native_control_result.offset == native_control_code.size() - 1
		and native_control_result.trace.size() == 7
		and native_control_result.state_diff.is_empty(),
		"typed AX and EVENTB03 native controls fall through to the exact return without sandbox mutation"
	)
	_check(
		native_control_result.trace[5].effect == "ax_selected_cell_state_1_omitted"
		and native_control_result.trace[5].execution_selector == 2
		and native_control_result.trace[5].consumer_vector_offset == 0x4B578
		and native_control_result.trace[5].native_dispatch_table == 0x00429338
		and native_control_result.trace[5].native_consumer_virtual_slot == 0x10
		and native_control_result.trace[5].native_consumer_handler == 0x00410C10
		and native_control_result.trace[5].cell_state_offset == 0
		and native_control_result.trace[5].cell_state_value == 1
		and native_control_result.trace[5].native_bounded_effect == "set_selected_ax_cell_state_to_1"
		and native_control_result.trace[5].native_effect_omitted
		and not native_control_result.trace[5].gameplay_sandbox_changed,
		"runner reports selector-2 selected AX-cell state changes as an explicit omitted native effect"
	)
	_check(
		native_control_result.trace[1].effect == "ax_cells_mark_active_omitted"
		and native_control_result.trace[1].execution_selector == 6
		and native_control_result.trace[1].native_consumer_virtual_slot == 0x1C
		and native_control_result.trace[1].native_consumer_handler == 0x00410C80
		and native_control_result.trace[1].native_nested_cell_virtual_slot == 0x10
		and native_control_result.trace[1].native_nested_cell_handler == 0x00410C10
		and native_control_result.trace[1].inactive_state == 0xFF
		and native_control_result.trace[1].cell_update_flag_offset == 0x10
		and native_control_result.trace[1].cell_update_flag_value == 1
		and native_control_result.trace[1].native_bounded_effect == "set_update_flag_1_on_noninactive_10x32_ax_cells"
		and native_control_result.trace[1].native_effect_omitted
		and not native_control_result.trace[1].gameplay_sandbox_changed,
		"runner reports selector-6 noninactive AX-cell updates as an explicit omitted native effect"
	)
	_check(
		native_control_result.trace[3].effect == "ax_cells_invalidate_omitted"
		and native_control_result.trace[3].execution_selector == 7
		and native_control_result.trace[3].consumer_virtual_slot == 0x20
		and native_control_result.trace[3].inactive_state == 0xFF
		and native_control_result.trace[3].native_bounded_effect == "set_all_10x32_cell_states_to_inactive_0xff"
		and native_control_result.trace[3].native_effect_omitted
		and not native_control_result.trace[3].gameplay_sandbox_changed,
		"runner reports selector-7 AX invalidation as an explicit omitted native effect"
	)
	_check(
		native_control_result.trace[4].effect == "ax_cells_activate_wait_omitted"
		and native_control_result.trace[4].execution_selector == 8
		and native_control_result.trace[4].consumer_vector_offset == 0x4B578
		and native_control_result.trace[4].native_activation_handler == 0x00411140
		and native_control_result.trace[4].native_wait_helper == 0x00411290
		and native_control_result.trace[4].native_initial_transition == "state_0_to_3"
		and native_control_result.trace[4].native_ordinary_wait_transition == "state_3_to_4"
		and native_control_result.trace[4].native_effect_omitted
		and not native_control_result.trace[4].gameplay_sandbox_changed,
		"runner reports selector-8 AX activation and wait without simulating cadence"
	)
	_check(
		native_control_result.trace[0].effect == "surface_composition_control_omitted"
		and native_control_result.trace[0].presentation_subcommand == 10
		and native_control_result.trace[0].surface_mode == 1
		and native_control_result.trace[0].native_surface_indices == [11, 0, 10]
		and native_control_result.trace[0].native_copy_helper == 0x004254D0
		and native_control_result.trace[0].native_copy_call_sites == [0x0042AA5E, 0x0042AACB, 0x0042AB5A]
		and not native_control_result.trace[0].native_optional_fill_path_taken
		and native_control_result.trace[0].native_effect_omitted
		and not native_control_result.trace[0].gameplay_sandbox_changed,
		"runner reports guarded subcommand-10 composition without applying native pixels"
	)
	var surface_code := PackedByteArray([0x0D, 0x0B, 0xFF])
	for value in [1, 10, 20, 29, 39, 2, 40, 50, 0]:
		surface_code.append_array(PackedByteArray([0x02, value, 0xFF]))
	surface_code.append_array(PackedByteArray([0x00, 0x00]))
	var surface_state := SandboxStateScript.new(1)
	var surface_result := runner.run(surface_code, 0, surface_state)
	_check(
		surface_result.status == "script_return"
		and surface_result.offset == surface_code.size() - 1
		and surface_result.state_diff.is_empty(),
		"bounded surface composition falls through without mutating gameplay state"
	)
	_check(
		surface_result.trace[0].effect == "surface_operation_omitted"
		and surface_result.trace[0].presentation_subcommand == 11
		and surface_result.trace[0].surface_mode == 1
		and surface_result.trace[0].surface_arguments == [1, 10, 20, 29, 39, 2, 40, 50, 0]
		and surface_result.trace[0].source_rectangle == [10, 20, 20, 20]
		and surface_result.trace[0].native_operation_semantics == "rgb_chroma_key_rectangle_copy_confirmed"
		and surface_result.trace[0].native_pixel_helper == 0x004255D0
		and surface_result.trace[0].native_pixel_effect_omitted
		and not surface_result.trace[0].gameplay_sandbox_changed,
		"runner exposes the exact native rectangle-copy metadata while omitting pixel effects"
	)
	var display_refresh_code := PackedByteArray([0x0D, 0x0B, 0xFF])
	for value in [13, 10, 20, 29, 39, 0]:
		display_refresh_code.append_array(PackedByteArray([0x02, value, 0xFF]))
	display_refresh_code.append_array(PackedByteArray([0x00, 0x00]))
	var display_refresh_result := runner.run(
		display_refresh_code,
		0,
		SandboxStateScript.new(1)
	)
	_check(
		display_refresh_result.status == "script_return"
		and display_refresh_result.trace[0].effect == "surface_display_refresh_omitted"
		and display_refresh_result.trace[0].surface_mode == 13
		and display_refresh_result.trace[0].surface_record_count == 6
		and display_refresh_result.trace[0].surface_arguments == [13, 10, 20, 29, 39, 0]
		and display_refresh_result.trace[0].refresh_input_bounds == [10, 20, 20, 20]
		and display_refresh_result.trace[0].refresh_rectangle == [0, 0, 20, 20]
		and display_refresh_result.trace[0].native_rectangle_helper == 0x00427640
		and display_refresh_result.trace[0].native_raster_operation == 0x00CC0020
		and display_refresh_result.trace[0].native_display_refresh_omitted
		and not display_refresh_result.trace[0].gameplay_sandbox_changed
		and display_refresh_result.state_diff.is_empty(),
		"runner reports the confirmed mode-13 display refresh without executing host pixels"
	)
	var unresolved_surface_code := PackedByteArray([
		0x0D, 0x0B, 0xFF,
		0x02, 0x0D, 0xFF,
		0x02, 0x3D, 0xFF,
		0x00,
		0x00,
	])
	var unresolved_surface_state := SandboxStateScript.new(1)
	var unresolved_surface_result := runner.run(unresolved_surface_code, 0, unresolved_surface_state)
	_check(
		unresolved_surface_result.status == "script_return"
		and unresolved_surface_result.trace[0].effect == "surface_dispatch_omitted"
		and unresolved_surface_result.trace[0].surface_mode == 13
		and unresolved_surface_result.trace[0].surface_mode_source == "literal"
		and unresolved_surface_result.trace[0].surface_record_count == 2
		and unresolved_surface_result.trace[0].surface_arguments == [13, 61]
		and unresolved_surface_result.trace[0].native_dispatch_semantics == "out_of_range_mode_skips_switch_body_then_reaches_common_tail"
		and unresolved_surface_result.trace[0].native_effects_omitted
		and unresolved_surface_result.state_diff.is_empty(),
		"runner consumes a complete out-of-range surface dispatch without applying unresolved native effects"
	)
	var empty_surface_state := SandboxStateScript.new(1)
	var empty_surface_result := runner.run(
		PackedByteArray([0x0D, 0x0B, 0xFF, 0x00, 0x00]),
		0,
		empty_surface_state
	)
	_check(
		empty_surface_result.status == "script_return"
		and empty_surface_result.trace[0].effect == "surface_dispatch_omitted"
		and empty_surface_result.trace[0].surface_mode == -1
		and empty_surface_result.trace[0].surface_mode_source == "native_record_default_unresolved"
		and empty_surface_result.trace[0].surface_record_count == 0
		and empty_surface_result.trace[0].surface_arguments.is_empty()
		and empty_surface_result.state_diff.is_empty(),
		"runner consumes the empty native dispatch while keeping default records unresolved"
	)

	var presentation_code := PackedByteArray([
		0x0D,
		0x09, 0xFF, 0x01,
		0x44, 0x31, 0x2E, 0x4D, 0x4D, 0x4F, 0x00,
		0x00,
		0x07, 0x01, 0xFF, 0x00, 0x07, 0xFF, 0x00,
		0x00,
	])
	var presentation_state := SandboxStateScript.new(1)
	presentation_state.write_value("banked_u16", 1, 8, 0)
	var presentation_result := runner.run(presentation_code, 1, presentation_state)
	_check(presentation_result.status == "script_return" and presentation_result.offset == presentation_code.size() - 1, "bounded MMO resource marker falls through to the next exact return boundary")
	_check(
		presentation_result.trace[0].effect == "mmo_resource_marker"
		and presentation_result.trace[0].resource_name == "D1.MMO"
		and presentation_result.trace[0].outer_command == 0x0D
		and presentation_result.trace[0].presentation_subcommand == 9
		and presentation_result.trace[0].native_default_origin_arguments == [-1, -1]
		and presentation_result.trace[0].native_active_surface_storage == "banked_u16"
		and presentation_result.trace[0].native_active_surface_bank == 0
		and presentation_result.trace[0].native_active_surface_storage_index == 1
		and presentation_result.trace[0].native_active_surface_value == 8
		and presentation_result.trace[0].native_playback_semantics == "named_mmo_load_into_active_surface_confirmed",
		"runner preserves the EXE-confirmed native MMO active-surface load boundary"
	)
	_check(
		presentation_result.trace[1].effect == "banked_u16_write_run"
		and presentation_state.read_value("banked_u16", 1, 0) == 7
		and presentation_result.state_diff.size() == 1
		and presentation_result.state_diff[0].before == 8
		and presentation_result.state_diff[0].after == 7,
		"runner executes the independent banked-u16 write immediately after the MMO presentation"
	)

	var bgm_code := PackedByteArray([
		0x09, 0x01, 0x00, 0x1A, 0xFF, 0x00,
		0x1D, 0x02, 0x17, 0xFF, 0x00,
		0x1F, 0x10, 0x00, 0x00, 0x00,
		0x1F, 0x16, 0x00, 0x00, 0x00,
		0x1F, 0x17, 0x00, 0x00, 0x00,
		0x0D,
		0x00,
	])
	var bgm_result := runner.run(bgm_code, 0, SandboxStateScript.new(1))
	_check(bgm_result.status == "script_return" and bgm_result.offset == bgm_code.size() - 1, "confirmed BGM request falls through to the next exact return boundary")
	_check(
		bgm_result.trace[0].effect == "argument_slot_assignment"
		and bgm_result.trace[0].argument_slot == 1
		and bgm_result.trace[0].argument_value == 26,
		"runner retains the confirmed argument slot and selector"
	)
	_check(
		bgm_result.trace[1].effect == "bgm_request"
		and bgm_result.trace[1].routine_id == 23
		and bgm_result.trace[1].bgm_selector == 26
		and bgm_result.trace[1].resource_name == "X_MAS.WAV",
		"runner resolves confirmed routine 23 selector 33 to the authoritative BGM table entry"
	)
	_check(
		bgm_result.trace[2].effect == "source_line_marker"
		and bgm_result.trace[2].source_line == 16
		and bgm_result.trace[4].source_line == 23,
		"source-line markers fall through without changing the BGM request"
	)
	_check(
		bgm_result.state_diff == [{"storage": "global_i32", "bank": 0, "index": 1, "before": 0, "after": 26}]
		and bgm_result.trace[0].write_storage == "global_i32"
		and bgm_result.trace[0].write_start == 1
		and bgm_result.trace[0].write_count == 1
		and bgm_result.trace[0].write_bank == 0
		and bgm_result.trace[1].bgm_selector == 26,
		"command 0x09 is the BGM request's only sandbox write: it lands in global_i32, the storage token 0xF6 reads (Core 0.377.0)"
	)
	_check(
		bgm_result.trace[5].effect == "statement_separator"
		and bgm_result.trace[5].native_stream_probe.consumed_byte_count == 1
		and bgm_result.offset == bgm_code.size() - 1,
		"empty statement separator projection falls through to the next exact boundary"
	)
	# 0D 0C FF 02 32 FF 00 is System.function[12](50): the 0x0C is the call's
	# selector, not a continuation transfer, so the runner records the call
	# and walks on instead of stopping at a native presentation boundary.
	var separator_payload := runner.run(PackedByteArray([0x0D, 0x0C, 0xFF, 0x02, 0x32, 0xFF, 0x00]), 0, SandboxStateScript.new(1))
	_check(
		separator_payload.status == "completed"
		and separator_payload.offset == 7
		and separator_payload.trace[-1].effect == "system_call_omitted"
		and separator_payload.trace[-1].system_function == 12
		and separator_payload.trace[-1].argument_count == 1
		and separator_payload.trace[-1].gameplay_sandbox_changed == false
		and separator_payload.state_diff.is_empty(),
		"a system call whose selector byte looks like a control command is one call, never false control flow"
	)
	var skipped_separator_payload := runner.run(
		PackedByteArray([0x0D, 0x0C, 0xFF, 0x02, 0x32, 0xFF, 0x00, 0x00]),
		0,
		SandboxStateScript.new(1),
		-1,
		RunnerScript.DEFAULT_MAX_STEPS,
		{"native_stream_policy": "skip_bounded"}
	)
	_check(
		skipped_separator_payload.status == "script_return"
		and skipped_separator_payload.offset == 7
		and skipped_separator_payload.trace[0].effect == "system_call_omitted"
		and skipped_separator_payload.trace[0].next_offset == 7
		and skipped_separator_payload.state_diff.is_empty(),
		"the skip policy advances over a system call the same way, without applying presentation state"
	)
	var skipped_command02_payload := runner.run(
		PackedByteArray([0x02, 0x41, 0x00, 0x00]),
		0,
		SandboxStateScript.new(1),
		-1,
		RunnerScript.DEFAULT_MAX_STEPS,
		{"native_stream_policy": "skip_bounded"}
	)
	_check(
		skipped_command02_payload.status == "script_return"
		and skipped_command02_payload.offset == 3
		and skipped_command02_payload.trace.size() == 2
		and skipped_command02_payload.trace[0].effect == "native_presentation_omitted"
		and skipped_command02_payload.trace[0].native_dispatch_next_offset == 3
		and skipped_command02_payload.state_diff.is_empty(),
		"explicit analysis policy advances command 0x02 after its bounded native stream instead of stopping twice"
	)
	var preserved_dialogue := runner.run(
		PackedByteArray([0x01, 0x41, 0x00, 0x13, 0xFF, 0x02, 0x02, 0xFF, 0x00, 0x00]),
		0,
		SandboxStateScript.new(1),
		-1,
		RunnerScript.DEFAULT_MAX_STEPS,
		{
			"native_stream_policy": "skip_bounded_preserve_dialogue",
			"persistent_expression_stack": [19],
		}
	)
	_check(
		preserved_dialogue.ok
		and preserved_dialogue.status == "dialogue_boundary"
		and preserved_dialogue.offset == 5
		and preserved_dialogue.resume_offset == 9
		and preserved_dialogue.messages.size() == 1
		and preserved_dialogue.persistent_expression_stack == [19]
		and preserved_dialogue.trace[-1].effect == "dialogue_boundary",
		"dialogue-preserving native omission stops at an exact message trailer before skipping it"
	)
	var skipped_command02_deferred_pair := runner.run(
		PackedByteArray([0x02, 0x41, 0x82, 0xA0, 0x00, 0x00]),
		0,
		SandboxStateScript.new(1),
		-1,
		RunnerScript.DEFAULT_MAX_STEPS,
		{"native_stream_policy": "skip_bounded"}
	)
	_check(
		skipped_command02_deferred_pair.status == "script_return"
		and skipped_command02_deferred_pair.offset == 5
		and skipped_command02_deferred_pair.trace.size() == 3
		and skipped_command02_deferred_pair.trace[0].effect == "native_presentation_omitted"
		and skipped_command02_deferred_pair.trace[0].native_stream_probe.stop_reason == "double_byte_lead_deferred"
		and skipped_command02_deferred_pair.trace[1].effect == "message"
		and skipped_command02_deferred_pair.messages.size() == 1
		and skipped_command02_deferred_pair.state_diff.is_empty(),
		"command 0x02 omission hands a deferred primary lead to the bounded double-byte decoder"
	)
	var invalid_native_pair := runner.run(PackedByteArray([0x8F, 0x01, 0xFF, 0x00]), 0, SandboxStateScript.new(1))
	_check(
		invalid_native_pair.status == "native_presentation_boundary"
		and invalid_native_pair.offset == 0
		and invalid_native_pair.messages.is_empty()
		and invalid_native_pair.trace[0].native_stream_probe.character_count == 1
		and invalid_native_pair.trace[0].native_stream_probe.consumed_byte_count == 2,
		"native double-byte pairs that are invalid CP932 remain presentation boundaries instead of fabricated dialogue"
	)
	var skipped_invalid_native_pair := runner.run(
		PackedByteArray([0x8F, 0x01, 0xFF, 0x00]),
		0,
		SandboxStateScript.new(1),
		-1,
		RunnerScript.DEFAULT_MAX_STEPS,
		{"native_stream_policy": "skip_bounded"}
	)
	_check(
		skipped_invalid_native_pair.status == "completed"
		and skipped_invalid_native_pair.messages.is_empty()
		and skipped_invalid_native_pair.trace.size() == 2
		and skipped_invalid_native_pair.trace.all(
			func(record: Dictionary) -> bool: return str(record.effect) == "native_presentation_omitted"
		),
		"bounded analysis skips invalid native pairs losslessly without presenting CP932 diagnostics as dialogue"
	)
	var dynamic_code := PackedByteArray([0x01, 0x5B, 0x00, 0x0D])
	dynamic_code.append_array(PackedByteArray([0x0E, 0xFF, 0x02, 0x00, 0xF9, 0x00, 0x00, 0xA0, 0x00, 0xE0, 0xF1, 0x40, 0x0B, 0xE0, 0xFF, 0x00]))
	dynamic_code.append_array(PackedByteArray([0x0D, 0x01, 0x5D, 0x00, 0x0D, 0x13, 0xFF, 0x02, 0x02, 0xFF, 0x00]))
	var dynamic_result := runner.run(dynamic_code, 0, SandboxStateScript.new(1), -1, RunnerScript.DEFAULT_MAX_STEPS, {
		"protagonist_name": "Akira",
		"argument_slots": {1: 33},
	})
	_check(dynamic_result.ok and dynamic_result.status == "dialogue_boundary", "dynamic name route recognizes the exact bounded dialogue trailer")
	_check(dynamic_result.resume_offset == dynamic_code.size(), "dialogue boundary reports the physical continuation coordinate")
	_check(dynamic_result.argument_slots.get(1, -1) == 33, "dialogue boundary retains temporary argument slots for an explicit continuation")
	_check(dynamic_result.trace[-2].effect == "message_cursor_no_advance", "command 0x13 FF falls through without changing sandbox state")
	_check(dynamic_result.trace[-1].effect == "dialogue_boundary" and dynamic_result.trace[-1].raw_hex == "0d13ff0202ff00", "the message-wait call that closes the page is retained losslessly in the trace")
	_check(
		dynamic_result.messages.size() == 3
		and dynamic_result.messages[1].dynamic_kind == "protagonist_name"
		and dynamic_result.messages[1].text == "Akira"
		and dynamic_result.messages[1].resolved,
		"exact command 0x0E inserts the tool-only protagonist preview name"
	)
	var placeholder_result := runner.run(PackedByteArray([0x0E, 0xFF, 0x02, 0x00, 0xF9, 0x00, 0x00, 0xA0, 0x00, 0xE0, 0xF1, 0x40, 0x0B, 0xE0, 0xFF, 0x00]), 0, SandboxStateScript.new(1))
	_check(placeholder_result.messages[0].text == "〈主人公名〉" and not placeholder_result.messages[0].resolved, "missing preview name remains an explicit dynamic placeholder")
	var literal_0e := runner.run(PackedByteArray([0x0E, 0x01, 0x82, 0xA0, 0x00, 0x00]), 0, SandboxStateScript.new(1))
	_check(
		literal_0e.status == "completed"
		and literal_0e.trace[0].effect == "literal_text_insert"
		and literal_0e.trace[0].record_byte_count == 2
		and literal_0e.messages[0].raw_hex == "82a0"
		and literal_0e.messages[0].dynamic_kind == "literal_record"
		and literal_0e.state_diff.is_empty(),
		"single-string command 0x0E retains its native literal text insertion without gameplay state"
	)
	var script_handoff := runner.run(PackedByteArray([
		0x0E, 0x01, 0x4D, 0x41, 0x43, 0x48, 0x49, 0x2E, 0x4D, 0x45, 0x53, 0x00, 0x00,
	]), 0, SandboxStateScript.new(1))
	_check(
		script_handoff.status == "script_handoff_boundary"
		and script_handoff.command_id == 0x0E
		and script_handoff.trace[-1].effect == "script_handoff_boundary"
		and script_handoff.trace[-1].target_entry == "MACHI.MES"
		and script_handoff.trace[-1].native_active_string_changed
		and not script_handoff.trace[-1].gameplay_sandbox_changed
		and script_handoff.messages.is_empty()
		and script_handoff.state_diff.is_empty(),
		"command 0x0E MES handoffs stop before the unresolved host consumer and are not exposed as dialogue"
	)
	var unresolved_13 := runner.run(PackedByteArray([0x13, 0x00]), 0, SandboxStateScript.new(1))
	_check(unresolved_13.status == "unsupported_opcode" and unresolved_13.command_id == 0x13, "other command 0x13 operands still stop")
	var unanchored_02 := runner.run(PackedByteArray([0x02, 0x02, 0xFF, 0x00]), 0, SandboxStateScript.new(1))
	_check(
		unanchored_02.status == "native_presentation_boundary"
		and unanchored_02.command_id == 0x02
		and unanchored_02.trace[-1].effect == "native_presentation_boundary"
		and unanchored_02.trace[-1].native_handler_family == "character_stream_presentation"
		and unanchored_02.trace[-1].native_stream_probe.consumed_byte_count == 3
		and str(unanchored_02.error).contains("display and cursor effects are not simulated"),
		"the same trailer without a traced dialogue stops at the native presentation boundary"
	)
	var unresolved_12 := runner.run(
		PackedByteArray([0x12, 0x02, 0x01, 0xFF, 0x02, 0x2B, 0xFF, 0x02, 0x00, 0xFF, 0x00, 0x00]),
		0,
		SandboxStateScript.new(1),
		-1,
		RunnerScript.DEFAULT_MAX_STEPS,
		{"argument_slots": {4: 9}, "persistent_expression_stack": [7]}
	)
	_check(
		unresolved_12.status == "native_record_boundary"
		and unresolved_12.command_id == 0x12
		and unresolved_12.trace[-1].native_handler_family == "native_record_dispatch"
		and unresolved_12.trace[-1].effect == "native_record_boundary"
		and unresolved_12.trace[-1].native_record_consumption == "typed_record_list_until_zero"
		and unresolved_12.trace[-1].native_record_count == 3
		and unresolved_12.trace[-1].native_record_terminator_consumed
		and not unresolved_12.has("resume_offset")
		and not unresolved_12.has("resume_policy")
		and unresolved_12.argument_slots.get(4, -1) == 9
		and unresolved_12.persistent_expression_stack == [7]
		and unresolved_12.state_diff.is_empty()
		and str(unresolved_12.error).contains("state and presentation effects are not executed"),
		"command 0x12 exposes a fail-closed typed-record boundary without offering a generic omission resume"
	)
	var omitted_12 := runner.run(
		PackedByteArray([0x12, 0x02, 0x01, 0xFF, 0x02, 0x2B, 0xFF, 0x02, 0x00, 0xFF, 0x00, 0x00]),
		0,
		SandboxStateScript.new(1),
		-1,
		RunnerScript.DEFAULT_MAX_STEPS,
		{"native_record_policy": "omit_bounded"}
	)
	_check(
		omitted_12.status == "script_return"
		and omitted_12.offset == 11
		and omitted_12.trace[0].effect == "native_record_effects_omitted"
		and omitted_12.trace[0].next_offset == 11
		and omitted_12.trace[0].native_record_count == 3
		and omitted_12.state_diff.is_empty(),
		"explicit sandbox policy can omit one bounded native record dispatch without applying its effects"
	)
	_test_map_location_contracts()
	_test_native_record_stop_offsets()
	var eventd08_record_prefix := PackedByteArray([
		0x12, 0x02, 0x01, 0xFF, 0x02, 0x03, 0xFF, 0x02, 0x00, 0xFF, 0x00,
		0x12, 0x02, 0x01, 0xFF, 0x02, 0x04, 0xFF, 0x02, 0x00, 0xFF, 0x00,
	])
	var eventd08_prelude_code := eventd08_record_prefix.duplicate()
	eventd08_prelude_code.append_array(PackedByteArray([0x0D, 0x09, 0xFF, 0x01]))
	eventd08_prelude_code.append_array("D08.MMO".to_ascii_buffer())
	eventd08_prelude_code.append_array(PackedByteArray([
		0x00, 0x00,
		0x07, 0x02, 0x04, 0xFF, 0x00, 0x02, 0x09, 0xFF, 0x00,
		0x00,
	]))
	var eventd08_prelude_state := SandboxStateScript.new(1)
	var eventd08_prelude_result := runner.run(
		eventd08_prelude_code,
		0,
		eventd08_prelude_state,
		-1,
		RunnerScript.DEFAULT_MAX_STEPS,
		{"native_record_policy": "omit_bounded"}
	)
	_check(
		eventd08_prelude_result.status == "script_return"
		and eventd08_prelude_result.offset == eventd08_prelude_code.size() - 1
		and eventd08_prelude_result.trace.size() == 5
		and eventd08_prelude_result.trace[0].source_offset == 0
		and eventd08_prelude_result.trace[0].end_offset == 11
		and eventd08_prelude_result.trace[0].effect == "native_record_effects_omitted"
		and eventd08_prelude_result.trace[1].source_offset == 11
		and eventd08_prelude_result.trace[1].end_offset == 22
		and eventd08_prelude_result.trace[1].effect == "native_record_effects_omitted"
		and eventd08_prelude_result.trace[2].source_offset == 22
		and eventd08_prelude_result.trace[2].end_offset == 35
		and eventd08_prelude_result.trace[2].effect == "mmo_resource_marker"
		and eventd08_prelude_result.trace[2].command_id == 0x0D
		and eventd08_prelude_result.trace[2].resource_name == "D08.MMO"
		and eventd08_prelude_result.trace[2].outer_command_source_offset == 22
		and str(eventd08_prelude_result.trace[2].raw_hex).ends_with("0000")
		and eventd08_prelude_result.trace[3].source_offset == 35
		and eventd08_prelude_result.trace[3].effect == "banked_u16_write_run"
		and eventd08_prelude_state.read_value("banked_u16", 4, 0) == 9
		and eventd08_prelude_result.state_diff.size() == 1
		and eventd08_prelude_result.trace.all(
			func(record: Dictionary) -> bool: return str(record.effect) != "native_presentation_omitted"
		),
		"record-only omission crosses adjacent typed lists, preserves the outer-0D/sub-9 D08.MMO envelope, and reaches an independent write without enabling native-stream skipping"
	)
	var record_only_native_stream_code := eventd08_record_prefix.duplicate()
	record_only_native_stream_code.append_array(PackedByteArray([
		0x0D, 0x0C, 0xFF, 0x02, 0x32, 0xFF, 0x00,
		0x07, 0x02, 0x04, 0xFF, 0x00, 0x02, 0x09, 0xFF, 0x00,
		0x00,
	]))
	var record_only_native_stream_state := SandboxStateScript.new(1)
	var record_only_native_stream_result := runner.run(
		record_only_native_stream_code,
		0,
		record_only_native_stream_state,
		-1,
		RunnerScript.DEFAULT_MAX_STEPS,
		{"native_record_policy": "omit_bounded"}
	)
	# 0D 0C FF 02 32 FF 00 is System.function[12](50), one call the runner
	# records and walks past, so the write after it executes.
	_check(
		record_only_native_stream_result.status == "script_return"
		and record_only_native_stream_result.offset == 38
		and record_only_native_stream_result.trace.size() == 5
		and record_only_native_stream_result.trace[0].effect == "native_record_effects_omitted"
		and record_only_native_stream_result.trace[1].effect == "native_record_effects_omitted"
		and record_only_native_stream_result.trace[2].effect == "system_call_omitted"
		and record_only_native_stream_result.trace[2].system_function == 12
		and record_only_native_stream_result.trace[3].effect == "banked_u16_write_run"
		and record_only_native_stream_result.state_diff.size() == 1
		and record_only_native_stream_state.read_value("banked_u16", 4, 0) == 9,
		"native-record omission walks past a later system call to the independent write"
	)
	var separator_ff := runner.run(PackedByteArray([0xFF, 0x02, 0x02, 0xFF, 0x00]), 0, SandboxStateScript.new(1))
	_check(
		separator_ff.status == "native_presentation_boundary"
		and separator_ff.command_id == 0xFF
		and separator_ff.trace[-1].effect == "native_presentation_boundary"
		and separator_ff.trace[-1].native_handler_family == "character_stream_presentation"
		and separator_ff.trace[-1].native_stream_probe.consumed_byte_count == 4
		and separator_ff.trace[-1].native_stream_probe.stop_reason == "nul_consumed"
		and separator_ff.state_diff.is_empty(),
		"deferred 0xFF reports its EXE-classified native single-byte presentation boundary"
	)
	var empty_command_01 := runner.run(PackedByteArray([0x01, 0xFF]), 0, SandboxStateScript.new(1))
	_check(
		empty_command_01.status == "native_presentation_boundary"
		and empty_command_01.command_id == 0x01
		and empty_command_01.messages.is_empty()
		and empty_command_01.trace[-1].native_handler_family == "double_byte_character_stream_presentation"
		and empty_command_01.trace[-1].native_stream_probe.consumed_byte_count == 0
		and empty_command_01.trace[-1].native_stream_probe.stop_reason == "single_byte_marker_deferred"
		and empty_command_01.state_diff.is_empty()
		and str(empty_command_01.error).contains("without a bounded message operand"),
		"command 0x01 with no consumed character exposes a double-byte presentation boundary without fabricating a message"
	)
	var internal_clear_zero := runner.run(PackedByteArray([0x1B, 0x02, 0x00, 0xFF, 0x00, 0x00]), 0, SandboxStateScript.new(1))
	var internal_record_state := SandboxStateScript.new(1)
	var internal_records := runner.run(PackedByteArray([0x19, 0x1A, 0x00]), 0, internal_record_state)
	_check(
		internal_records.status == "script_return"
		and internal_records.trace[0].effect == "internal_record_push"
		and internal_records.trace[0].internal_record_delta == 1
		and not internal_records.trace[0].native_active_string_changed
		and internal_records.trace[1].effect == "internal_record_pop"
		and internal_records.trace[1].internal_record_delta == -1
		and internal_records.trace[1].native_active_string_changed
		and not internal_records.trace[1].native_internal_string_resolved
		and internal_records.state_diff.is_empty(),
		"commands 0x19/0x1A trace manager-record effects without inventing native strings or gameplay state"
	)
	_check(
		internal_clear_zero.status == "script_return"
		and internal_clear_zero.trace[0].effect == "internal_vector_clear"
		and internal_clear_zero.trace[0].internal_vector_selector == 0
		and internal_clear_zero.trace[0].record_value == 0
		and not internal_clear_zero.trace[0].gameplay_sandbox_changed
		and internal_clear_zero.state_diff.is_empty(),
		"confirmed command 0x1B single-record form clears the evaluated native vector selector"
	)
	var internal_clear_seventeen := runner.run(PackedByteArray([0x1B, 0x02, 0x11, 0xFF, 0x00, 0x00]), 0, SandboxStateScript.new(1))
	_check(
		internal_clear_seventeen.status == "script_return"
		and internal_clear_seventeen.trace[0].internal_vector_selector == 17
		and internal_clear_seventeen.trace[0].record_value == 17,
		"command 0x1B uses the evaluated record value as its native vector selector"
	)
	var internal_clear_large_value := runner.run(PackedByteArray([0x1B, 0x02, 0x64, 0xFF, 0x00, 0x00]), 0, SandboxStateScript.new(1))
	_check(
		internal_clear_large_value.status == "script_return"
		and internal_clear_large_value.trace[0].internal_vector_selector == 100
		and internal_clear_large_value.trace[0].record_value == 100,
		"command 0x1B retains the original evaluated selector even when it is 100"
	)
	var shared_transfer := runner.run(PackedByteArray([0x1D, 0x02, 0x18, 0xFF, 0x00]), 0, SandboxStateScript.new(1))
	_check(
		shared_transfer.status == "shared_routine_boundary"
		and shared_transfer.trace[-1].routine_id == 24
		and shared_transfer.trace[-1].persistent_expression_stack_depth == 0
		and shared_transfer.persistent_expression_stack.is_empty(),
		"unexecuted shared transfers expose a dedicated boundary with their literal routine ID"
	)
	var carried_shared_transfer := runner.run(PackedByteArray([
		0x0A,
		0xFF,
		0x01, 0x34, 0xFF, 0x00,
		0x1D, 0x02, 0x1C, 0xFF, 0x00,
	]), 0, SandboxStateScript.new(1))
	_check(
		carried_shared_transfer.status == "shared_routine_boundary"
		and carried_shared_transfer.trace[-1].routine_id == 28
		and carried_shared_transfer.trace[-1].persistent_expression_stack_depth == 1
		and carried_shared_transfer.trace[-1].persistent_expression_stack == [1]
		and carried_shared_transfer.persistent_expression_stack == [1],
		"shared routine boundary retains the execution-local evaluator carry required to audit its native call frame"
	)
	var restored_stack_state := SandboxStateScript.new(1)
	var restored_stack_run := runner.run(
		PackedByteArray([0x0A, 0xFF, 0x03, 0xFF, 0x00, 0x00]),
		0,
		restored_stack_state,
		-1,
		RunnerScript.DEFAULT_MAX_STEPS,
		{"persistent_expression_stack": [1]}
	)
	_check(
		restored_stack_run.status == "script_return"
		and restored_stack_state.read_value("global_i32", 1) == 3
		and restored_stack_run.persistent_expression_stack.is_empty(),
		"runner restores and returns an explicit isolated evaluator stack for nested library execution"
	)
	var definition_invoke := runner.run(PackedByteArray([0x11, 0x02, 0x0B, 0xFF, 0x00, 0x00]), 0, SandboxStateScript.new(1))
	_check(
		definition_invoke.status == "definition_invoke_boundary"
		and definition_invoke.schema == ContentCoreVersionScript.MES_EVENT_TRACE_SCHEMA
		and definition_invoke.command_id == 0x11
		and definition_invoke.trace[-1].effect == "definition_invoke_boundary"
		and definition_invoke.trace[-1].definition_id == 11
		and definition_invoke.trace[-1].end_offset == 5
		and definition_invoke.resume_offset == 5
		and definition_invoke.resume_policy == "registered_definition_call_restore"
		and definition_invoke.argument_slots.is_empty()
		and definition_invoke.persistent_expression_stack.is_empty(),
		"command 0x11 exposes the evaluated DEF selector and caller continuation context without invoking it"
	)
	var definition_context := runner.run(
		PackedByteArray([0x11, 0x02, 0x0B, 0xFF, 0x00, 0x00]),
		0,
		SandboxStateScript.new(1),
		-1,
		RunnerScript.DEFAULT_MAX_STEPS,
		{"argument_slots": {2: 7}, "persistent_expression_stack": [19]}
	)
	_check(
		definition_context.resume_offset == 5
		and definition_context.argument_slots == {2: 7}
		and definition_context.persistent_expression_stack == [19],
		"command 0x11 boundary preserves explicit temporary caller context for later bounded composition"
	)
	var script_dispatch := runner.run(
		PackedByteArray([0x0F, 0x01, 0x54, 0x52, 0x41, 0x49, 0x4E, 0x2E, 0x4D, 0x45, 0x53, 0x00, 0x00]),
		0,
		SandboxStateScript.new(1),
		-1,
		RunnerScript.DEFAULT_MAX_STEPS,
		{"argument_slots": {2: 7}, "persistent_expression_stack": [19]}
	)
	_check(
		script_dispatch.status == "script_dispatch_boundary"
		and script_dispatch.command_id == 0x0F
		and script_dispatch.trace[-1].effect == "script_dispatch_boundary"
		and script_dispatch.trace[-1].target_entry == "TRAIN.MES"
		and not script_dispatch.trace[-1].gameplay_sandbox_changed
		and script_dispatch.resume_offset == 13
		and script_dispatch.argument_slots == {2: 7}
		and script_dispatch.persistent_expression_stack == [19]
		and script_dispatch.state_diff.is_empty(),
		"command 0x0F exposes its target, physical resume, and temporary caller context without executing it"
	)
	var unsafe_script_dispatch := runner.run(PackedByteArray([0x0F, 0x01, 0x2E, 0x2E, 0x2F, 0x58, 0x2E, 0x4D, 0x45, 0x53, 0x00, 0x00]), 0, SandboxStateScript.new(1))
	_check(unsafe_script_dispatch.status == "unsupported_opcode", "unsafe command 0x0F targets remain unsupported")
	var native_selection := runner.run(PackedByteArray([0x15, 0x01, 0x41, 0x00, 0x02, 0x05, 0xFF, 0x00]), 0, SandboxStateScript.new(1))
	_check(
		native_selection.status == "native_selection_boundary"
		and native_selection.command_id == 0x15
		and native_selection.trace[-1].effect == "native_selection_boundary"
		and native_selection.trace[-1].record_count == 2
		and native_selection.trace[-1].string_record_count == 1
		and native_selection.trace[-1].expression_record_count == 1
		and not native_selection.trace[-1].gameplay_sandbox_changed
		and native_selection.state_diff.is_empty(),
		"command 0x15 reports the native interactive selection boundary without synthesizing input or state"
	)
	var argument_run := runner.run(PackedByteArray([0x16, 0x09, 0x21, 0xFF, 0x01, 0x22, 0xFF, 0x00, 0x00]), 0, SandboxStateScript.new(1))
	_check(
		argument_run.status == "script_return"
		and argument_run.trace[0].effect == "argument_slot_write_run"
		and argument_run.trace[0].argument_slot_start == 9
		and argument_run.trace[0].argument_slot_count == 2
		and argument_run.argument_slots.get(9, -1) == 33
		and argument_run.argument_slots.get(10, -1) == 34,
		"command 0x16 writes its evaluated run into temporary native argument slots"
	)
	# Core 0.377.0 (TD-56): command 0x16 stays argument-slot only. Its storage is not
	# established by the address audit, so it neither writes global_i32 nor says it does.
	_check(
		argument_run.state_diff.is_empty()
		and not argument_run.trace[0].has("write_storage")
		and argument_run.trace[0].argument_values == [33, 34],
		"command 0x16 writes no global_i32 cell and carries no storage write row"
	)
	var command_09_run := runner.run(PackedByteArray([0x09, 0x02, 0x00, 0x02, 0xFF, 0x01, 0x03, 0xFF, 0x00, 0x00]), 0, SandboxStateScript.new(1))
	_check(
		command_09_run.status == "script_return"
		and command_09_run.trace[0].effect == "argument_slot_write_run"
		and command_09_run.trace[0].argument_slot_start == 2
		and command_09_run.trace[0].argument_slot_count == 2
		and command_09_run.argument_slots.get(2, -1) == 2
		and command_09_run.argument_slots.get(3, -1) == 3,
		"command 0x09 executes the native u16-indexed temporary argument-slot run"
	)
	var command_09_state := SandboxStateScript.new(1)
	var command_09_storage_run := runner.run(PackedByteArray([0x09, 0x02, 0x00, 0x02, 0xFF, 0x01, 0x03, 0xFF, 0x00, 0x00]), 0, command_09_state)
	_check(
		command_09_state.read_value("global_i32", 2) == 2
		and command_09_state.read_value("global_i32", 3) == 3
		and command_09_state.read_value("global_u8", 2) == 0
		and command_09_storage_run.state_diff == [
			{"storage": "global_i32", "bank": 0, "index": 2, "before": 0, "after": 2},
			{"storage": "global_i32", "bank": 0, "index": 3, "before": 0, "after": 3},
		]
		and command_09_storage_run.trace[0].write_storage == "global_i32"
		and command_09_storage_run.trace[0].write_start == 2
		and command_09_storage_run.trace[0].write_count == 2
		and command_09_storage_run.trace[0].write_bank == 0
		and command_09_storage_run.trace[0].argument_values == [2, 3],
		"command 0x09 writes its run through the sandbox into global_i32, the storage token 0xF6 reads, and the trace says so (Core 0.377.0)"
	)
	var telephone_call := runner.run(PackedByteArray([0x09, 0x02, 0x00, 0x25, 0xFF, 0x00, 0x1D, 0x02, 0x09, 0xFF, 0x00]), 0, SandboxStateScript.new(1))
	_check(
		telephone_call.status == "shared_routine_boundary"
		and telephone_call.trace[0].effect == "argument_slot_assignment"
		and telephone_call.trace[0].argument_slot == 2
		and telephone_call.trace[0].argument_value == 37
		and telephone_call.trace[1].routine_id == 9
		and telephone_call.argument_slots.get(2, -1) == 37
		and telephone_call.state_diff == [{"storage": "global_i32", "bank": 0, "index": 2, "before": 0, "after": 37}],
		"original telephone-call shape reaches shared routine 9 with its argument in the shared storage global_i32[2] and the provenance slot intact"
	)
	_test_argument_storage_alias(runner)
	var bootstrap := runner.run(PackedByteArray([0x14, 0x01, 0xFF, 0x07, 0x00, 0x00, 0x00, 0x00]), 0, SandboxStateScript.new(1))
	_check(
		bootstrap.status == "script_return"
		and bootstrap.trace[0].effect == "bootstrap_transfer"
		and bootstrap.trace[0].bootstrap_selector == 1
		and bootstrap.trace[0].next_offset == 7
		and bootstrap.trace[0].native_context_map_changed
		and bootstrap.state_diff.is_empty(),
		"command 0x14 follows the native code-coordinate transfer while isolating the manager context map"
	)
	var definition_code := PackedByteArray([
		0x10, 0x02, 0x00, 0xFF, 0x00, 13, 0, 0, 0,
		0x01, 0x41, 0x00, 0x00,
		0x10, 0x02, 0x02, 0xFF, 0x00, 26, 0, 0, 0,
		0x01, 0x42, 0x00, 0x00,
		0x1D, 0x02, 0x28, 0xFF, 0x00,
	])
	var definition_result := runner.run(definition_code, 0, SandboxStateScript.new(1))
	_check(definition_result.ok and definition_result.status == "def_selection_boundary" and definition_result.offset == 26, "bounded DEF bodies skip to routine 40 and stop before unresolved selection input")
	_check(definition_result.trace.size() == 3 and definition_result.trace[0].effect == "def_register_skip" and definition_result.trace[1].definition_target == 26, "DEF trace retains literal IDs and exact forward targets")
	_check(definition_result.definitions.size() == 2 and definition_result.definitions[0].definition_id == 0 and definition_result.definitions[1].definition_id == 2, "DEF boundary retains ordered literal definitions")
	_check(definition_result.definitions[0].messages[0].raw_hex == "41" and definition_result.definitions[1].messages[0].raw_hex == "42", "DEF option bodies retain lossless CP932 message bytes without executing them")
	_check(definition_result.state_diff.is_empty(), "read-only DEF collection does not synthesize a selection state write")
	var grouped_definition_code := PackedByteArray([
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
	var grouped_definition_result := runner.run(grouped_definition_code, 0, SandboxStateScript.new(1))
	var grouped_registry: Dictionary = grouped_definition_result.get("definition_groups", {})
	_check(
		grouped_definition_result.status == "def_selection_boundary"
		and grouped_definition_result.offset == 49
		and grouped_definition_result.selection_definition_group == 0
		and grouped_definition_result.definitions.size() == 2
		and grouped_definition_result.registered_definition_count == 3
		and grouped_definition_result.observed_definition_count == 3
		and grouped_definition_result.definition_group_order == [0, 1]
		and grouped_registry.keys() == [0, 1]
		and (grouped_registry[0] as Array).size() == 2
		and (grouped_registry[1] as Array).size() == 1
		and str((grouped_registry[0] as Array)[0].messages[0].raw_hex) == "41"
		and str((grouped_registry[1] as Array)[0].messages[0].raw_hex) == "43"
		and grouped_definition_result.trace[-1].definition_count == 2
		and grouped_definition_result.trace[-1].registered_definition_count == 3,
		"routine 40 preserves command-1B groups and presents fixed key-0 rows as the first-stage selection"
	)
	var repeated_group_code := grouped_definition_code.duplicate()
	# Change the second clear from group 1 to group 0: native clear semantics must replace group 0.
	repeated_group_code[33] = 0x00
	var repeated_group_result := runner.run(repeated_group_code, 0, SandboxStateScript.new(1))
	var repeated_registry: Dictionary = repeated_group_result.get("definition_groups", {})
	_check(
		repeated_group_result.status == "def_selection_boundary"
		and repeated_group_result.definitions.size() == 1
		and repeated_group_result.registered_definition_count == 1
		and repeated_group_result.observed_definition_count == 3
		and repeated_group_result.definition_group_order == [0]
		and repeated_registry.keys() == [0]
		and str((repeated_registry[0] as Array)[0].messages[0].raw_hex) == "43",
		"a repeated command-1B selector replaces that native group without hiding the observed registration count"
	)
	var malformed_definition := definition_code.duplicate()
	malformed_definition.encode_u32(5, 11)
	var malformed_definition_result := runner.run(malformed_definition, 0, SandboxStateScript.new(1))
	_check(malformed_definition_result.status == "unsupported_opcode" and malformed_definition_result.command_id == 0x10, "command 0x10 rejects a target that splits a decoded body instruction")
	var nested_definition_code := PackedByteArray([
		0x10, 0x02, 0x01, 0xFF, 0x00, 21, 0, 0, 0,
		0x01, 0x41, 0x00,
		0x11, 0x02, 0x63, 0xFF, 0x00,
		0x01, 0x42, 0x00,
		0x00,
		0x1D, 0x02, 0x28, 0xFF, 0x00,
	])
	var nested_definition := runner.run(nested_definition_code, 0, SandboxStateScript.new(1))
	_check(
		nested_definition.status == "def_selection_boundary"
		and nested_definition.definitions.size() == 1
		and nested_definition.definitions[0].body_instruction_count == 4
		and nested_definition.definitions[0].body_size == 12
		and str(nested_definition.definitions[0].body_sha256).length() == 64
		and nested_definition.definitions[0].messages.size() == 2
		and nested_definition.definitions[0].messages[0].raw_hex == "41"
		and nested_definition.definitions[0].messages[1].raw_hex == "42",
		"DEF registration skips a structurally bounded nested body without executing its command 0x11"
	)
	var record_code := PackedByteArray([0x09, 0x01, 0x00, 0xF1, 0x64, 0x00, 0xFF, 0x00, 0x1D, 0x02, 0x00, 0xFF, 0x00, 0x00])
	var record_result := runner.run(record_code, 0, SandboxStateScript.new(1))
	_check(record_result.status == "script_return" and record_result.offset == record_code.size() - 1, "routine 0 message record falls through to the next exact return boundary")
	_check(record_result.trace[1].effect == "message_record_id" and record_result.trace[1].message_record_id == 100 and record_result.state_diff.size() == 1 and record_result.state_diff[0].storage == "global_i32" and record_result.state_diff[0].index == 1, "routine 0 retains its literal message record ID; its only sandbox write is the command-0x09 argument in global_i32[1]")

	var voice_marker_code := PackedByteArray([0x07, 0x02, 0xFF, 0x00, 0x02, 0xA0, 0x00, 0xF1, 0x80, 0x00, 0xE9, 0xFF, 0x00, 0x0D, 0x07, 0xFF, 0x02, 0x02, 0xFF, 0x01])
	voice_marker_code.append_array("d0977.ogg".to_ascii_buffer())
	voice_marker_code.append_array(PackedByteArray([0x00, 0x02, 0x00, 0xFF, 0x00, 0x07, 0x02, 0xFF, 0x00, 0x02, 0xA0, 0x00, 0xF1, 0x7F, 0xFF, 0xE8, 0xFF, 0x00, 0x00]))
	var voice_state := SandboxStateScript.new(1)
	var voice_result := runner.run(voice_marker_code, 0, voice_state)
	_check(voice_result.status == "script_return" and voice_result.offset == voice_marker_code.size() - 1, "bounded voice marker falls through to the next exact return boundary")
	_check(
		voice_result.trace[1].effect == "voice_marker"
		and voice_result.trace[1].resource_name == "D0977.OGG"
		and voice_result.trace[1].presentation_subcommand == 7
		and voice_result.trace[1].native_consumer_semantics == "presentation_queue_and_stream_handoff_confirmed"
		and voice_result.trace[1].native_audible_output == "confirmed_directsound_play_dispatch"
		and voice_result.trace[1].native_host_device_output == "not_observed_by_static_audit"
		and not voice_result.trace[1].gameplay_sandbox_changed,
		"runner retains the native queue/stream and DirectSound Play route without claiming observed device output"
	)
	_check(voice_state.read_value("banked_u16", 2, 0) == 0 and voice_result.state_diff.is_empty(), "surrounding set and clear writes execute while the marker itself performs no sandbox write")

	var inline_script_code := PackedByteArray([0x0D, 0x08, 0xFF, 0x02, 0x03, 0xFF, 0x01])
	inline_script_code.append_array("def_main.mes".to_ascii_buffer())
	inline_script_code.append_array(PackedByteArray([0x00, 0x00, 0x00]))
	var inline_script_state := SandboxStateScript.new(1)
	var inline_script_result := runner.run(inline_script_code, 0, inline_script_state)
	_check(
		inline_script_result.status == "native_script_execution_boundary"
		and inline_script_result.command_id == 0x0D
		and inline_script_result.trace.size() == 1
		and inline_script_result.trace[0].effect == "inline_script_execution_boundary"
		and inline_script_result.trace[0].resource_kind == "mes_script"
		and inline_script_result.trace[0].resource_name == "DEF_MAIN.MES"
		and inline_script_result.trace[0].presentation_subcommand == 8
		and inline_script_result.trace[0].execution_selector == 3
		and inline_script_result.trace[0].execution_role == "definition_bootstrap"
		and inline_script_result.trace[0].native_context_restore == "confirmed"
		and inline_script_result.trace[0].tool_execution_semantics == "not_executed"
		and inline_script_result.trace[0].next_offset == inline_script_code.size() - 1
		and inline_script_result.state_diff.is_empty(),
		"runner exposes confirmed inline script execution as a fail-closed native boundary"
	)

	var state_transfer_code := PackedByteArray([
		0x0D, 0x04, 0xFF, 0x02, 0x0D, 0xFF,
		0x02, 0xF8, 0x2B, 0xFF,
		0x01, 0x48, 0x54, 0x45, 0x00,
		0x00, 0x00,
	])
	var state_transfer_state := SandboxStateScript.new(1)
	var state_transfer_result := runner.run(state_transfer_code, 0, state_transfer_state)
	_check(
		state_transfer_result.status == "native_state_transfer_boundary"
		and state_transfer_result.schema == ContentCoreVersionScript.MES_EVENT_TRACE_SCHEMA
		and state_transfer_result.command_id == 0x0D
		and state_transfer_result.trace.size() == 1
		and state_transfer_result.trace[0].effect == "native_state_transfer_boundary"
		and state_transfer_result.trace[0].presentation_subcommand == 4
		and state_transfer_result.trace[0].transfer_selector == 13
		and state_transfer_result.trace[0].mapping_string == "HTE"
		and state_transfer_result.trace[0].native_copy_scope == "relative_offsets_only"
		and not state_transfer_result.trace[0].gameplay_sandbox_changed
		and state_transfer_result.state_diff.is_empty(),
		"runner exposes named native offset restoration as a fail-closed host-state boundary"
	)

	_test_ax_selected_cell_payload_ownership()
	_test_effect_requests_preserve_boundaries()
	await get_tree().process_frame
	get_tree().quit(1 if _failed else 0)


func _test_effect_requests_preserve_boundaries() -> void:
	var request := PackedByteArray([0x0D, 6, 0xFF, 2, 0, 0xFF, 1])
	request.append_array("tool_hit.wav".to_ascii_buffer())
	request.append_array(PackedByteArray([0, 2, 0xF6, 2, 0, 0xFF, 0]))
	var code := PackedByteArray([0x03, 41, 0, 8, 0xFF, 0])
	var first_request := code.size()
	code.append_array(request)
	var second_request := code.size()
	code.append_array(request)
	var stop_offset := code.size()
	code.append_array(PackedByteArray([0x0D, 6, 0xFF, 2, 1, 0xFF, 2, 43, 0xFF, 0]))
	var write_offset := code.size()
	code.append_array(PackedByteArray([0x03, 42, 0, 9, 0xFF, 0, 0]))
	var state := SandboxStateScript.new(1)
	state.write_value("global_i32", 2, 3)
	var result := RunnerScript.new().run(code, 0, state, -1, RunnerScript.DEFAULT_MAX_STEPS, {"argument_slots": {2: 7}})
	_check(result.ok and result.status == "script_return" and result.trace.size() == 6
		and result.trace.map(func(row: Dictionary) -> int: return row.source_offset) == [0, first_request, second_request, stop_offset, write_offset, code.size() - 1]
		and result.state_diff.size() == 2 and state.read_value("global_u8", 41) == 8
		and state.read_value("global_u8", 42) == 9,
		"two effect envelopes preserve actual surrounding writes without executing shadow bank payload")
	for index in [1, 2]:
		var record: Dictionary = result.trace[index]
		_check(record.effect == "effect_request" and record.resource_name == "TOOL_HIT.WAV"
			and record.resource_kind == "effect" and record.resource_archive == "se.arc"
			and record.execution_selector == 0 and record.presentation_subcommand == 6
			and record.channel_index == 3 and record.native_record_count == 3
			and record.native_record_terminator_consumed and record.native_effect_omitted
			and not record.gameplay_sandbox_changed,
			"each repeated filename remains its own nonexecuting effect request with the real sandbox channel")
	_check(result.trace[3].effect == "effect_dispatch_omitted" and result.trace[3].execution_selector == 1
		and not result.trace[3].has("resource_name") and result.argument_slots[2] == 7,
		"selector-one control cannot become playback and a seeded provenance slot is never read for meaning: the channel is global_i32[2]")
	var truncated := request.slice(0, request.size() - 1)
	var rejected_state := SandboxStateScript.new(1)
	var rejected := RunnerScript.new().run(truncated, 0, rejected_state)
	_check(not rejected.ok and rejected.status == "decode_error" and rejected.trace.is_empty() and rejected.state_diff.is_empty(),
		"truncated recognized effect dispatch fails before any request or shadow mutation")
	var opaque := PackedByteArray([0x0D, 6, 0xFF, 2, 0, 0xFF, 1, 0x03, 42, 0x12, 0xFF, 0, 2, 0, 0xFF, 0, 0])
	var opaque_result := RunnerScript.new().run(opaque, 0, SandboxStateScript.new(1))
	_check(opaque_result.ok and opaque_result.trace.size() == 2
		and opaque_result.trace[0].effect == "effect_dispatch_omitted"
		and opaque_result.trace[1].source_offset == opaque.size() - 1
		and opaque_result.state_diff.is_empty(),
		"opaque effect string owns command-looking bytes and cannot play or write state")


func _test_ax_selected_cell_payload_ownership() -> void:
	var code := PackedByteArray([
		0x0D, 3, 0xFF, 2, 2, 0xFF, 2, 1, 0xFF, 2, 12, 0xFF, 0,
		0x0D, 3, 0xFF, 2, 1, 0xFF, 2, 0, 0xFF, 2, 0, 0xFF, 0,
		0x03, 42, 0, 9, 0xFF, 0,
		0,
	])
	var state := SandboxStateScript.new(1)
	for index in range(767, 770):
		state.write_value("global_u8", index, 100 + index - 767)
	var result := RunnerScript.new().run(code, 0, state)
	_check(result.ok and result.status == "script_return" and result.offset == 32
		and result.trace.size() == 4
		and result.trace.map(func(row: Dictionary) -> int: return row.source_offset) == [0, 13, 26, 32]
		and result.state_diff.size() == 1 and state.read_value("global_u8", 42) == 9
		and state.read_value("global_u8", 767) == 100
		and state.read_value("global_u8", 768) == 101
		and state.read_value("global_u8", 769) == 102,
		"AX compound payload cannot mutate global bytes 767..769 or execute column-12 shadow continuation")
	_check(result.trace[1].effect == "ax_selected_cell_state_0_omitted"
		and result.trace[1].cell_row == 0 and result.trace[1].cell_column == 0
		and result.trace[1].native_state_transition_semantics == "activate_current_cell_cursor"
		and result.trace[0].effect == "ax_selected_cell_state_1_omitted"
		and result.trace[0].cell_column == 12
		and result.trace[0].native_state_transition_semantics == "request_inactive_at_wait_boundary_not_immediate_freeze"
		and result.trace[0].native_defaulted_arguments == 1,
		"runner preserves selected AX cell and graceful-stop metadata without executing native pixels")
	var truncated := code.slice(0, 12)
	var truncated_state := SandboxStateScript.new(1)
	var rejected := RunnerScript.new().run(truncated, 0, truncated_state)
	_check(not rejected.ok and rejected.state_diff.is_empty()
		and truncated_state.read_value("global_u8", 767) == 0,
		"truncated recognized AX controls fail before any shadow gameplay mutation")


func _test_native_record_stop_offsets() -> void:
	# Synthetic string payload contains both a command-looking 0x12 and a
	# complete state-u16 write. Neither is an independently executable record.
	var code := PackedByteArray([
		0x04, 0x1E, 0x05, 0xFF, 0x00,
		0x12, 0x02, 0x05, 0xFF, 0x00,
		0x04, 0x1F, 0x06, 0xFF, 0x00,
		0x12, 0x01, 0x04, 0x09, 0x12, 0xFF, 0x00, 0x00,
		0x04, 0x20, 0x07, 0xFF, 0x00,
		0x00,
	])
	var runner := RunnerScript.new()
	var state := SandboxStateScript.new(1)
	var stopped := runner.run(code, 0, state, -1, RunnerScript.DEFAULT_MAX_STEPS, {
		"native_record_policy": "omit_bounded",
		"native_record_stop_offsets": [15],
		"argument_slots": {4: 9},
		"persistent_expression_stack": [7],
	})
	_check(
		not stopped.ok and stopped.status == "native_record_boundary"
		and stopped.offset == 15 and stopped.command_id == 0x12
		and stopped.trace.size() == 4,
		"consumer-selected native command start stops even when other bounded records may be omitted"
	)
	_check(
		stopped.trace[1].source_offset == 5
		and stopped.trace[1].effect == "native_record_effects_omitted"
		and stopped.trace[1].end_offset == 10
		and stopped.trace[-1].source_offset == 15
		and stopped.trace[-1].effect == "native_record_boundary"
		and stopped.trace[-1].end_offset == 23
		and stopped.trace[-1].native_record_count == 1
		and stopped.trace[-1].native_record_terminator_consumed,
		"selective stopping retains both complete native envelopes and the exact selected successor"
	)
	_check(
		state.read_value("state_u16", 30) == 5
		and state.read_value("state_u16", 31) == 6
		and state.read_value("state_u16", 32) == 0
		and state.read_value("state_u16", 9) == 0
		and stopped.state_diff.size() == 2,
		"writes before the selected boundary survive while successor and shadow payload writes do not execute"
	)
	_check(
		stopped.argument_slots.get(4, -1) == 9
		and stopped.persistent_expression_stack == [7]
		and stopped.messages.is_empty()
		and not stopped.has("resume_offset")
		and not stopped.has("resume_policy"),
		"selected native stop preserves execution context without inventing a generic resume policy"
	)
	var resumed := runner.run(code, 23, state)
	_check(
		resumed.ok and resumed.status == "script_return"
		and state.read_value("state_u16", 30) == 5
		and state.read_value("state_u16", 31) == 6
		and state.read_value("state_u16", 32) == 7
		and state.read_value("state_u16", 9) == 0
		and resumed.state_diff.size() == 1,
		"an explicit successor invocation executes only the after-write and preserves earlier writes"
	)
	for selected_offsets in [[17], [19], [16, 17, 18, 19, 20, 21, 22], [0, 10, 23, 28], []]:
		var interior_state := SandboxStateScript.new(1)
		var result := runner.run(code, 0, interior_state, -1, RunnerScript.DEFAULT_MAX_STEPS, {
			"native_record_policy": "omit_bounded",
			"native_record_stop_offsets": selected_offsets,
		})
		_check(
			result.ok and result.status == "script_return" and result.offset == 28
			and result.trace.size() == 6
			and result.trace.map(func(record: Dictionary) -> int: return record.source_offset) == [0, 5, 10, 15, 23, 28]
			and result.trace[1].effect == "native_record_effects_omitted"
			and result.trace[3].effect == "native_record_effects_omitted"
			and result.trace[3].end_offset == 23
			and result.messages.is_empty()
			and interior_state.read_value("state_u16", 30) == 5
			and interior_state.read_value("state_u16", 31) == 6
			and interior_state.read_value("state_u16", 32) == 7
			and interior_state.read_value("state_u16", 9) == 0,
			"payload interiors and non-native starts neither split records nor execute shadow commands: %s" % str(selected_offsets)
		)
	var default_state := SandboxStateScript.new(1)
	var default_stop := runner.run(code, 0, default_state, -1, RunnerScript.DEFAULT_MAX_STEPS, {
		"native_record_stop_offsets": [15],
	})
	_check(
		default_stop.status == "native_record_boundary" and default_stop.offset == 5
		and default_state.read_value("state_u16", 30) == 5
		and default_state.read_value("state_u16", 31) == 0,
		"selected offsets do not enable native omission unless its policy is explicit"
	)


func _test_map_location_contracts() -> void:
	# Map.get_location (Util(6,13)) followed by state_u16[23] = state_u16[18],
	# the map scripts' idiom. A declared contract supplies the location; the
	# queue is consumed in place; a spent or absent contract leaves the
	# record an omitted native.
	var runner := RunnerScript.new()
	var code := MesRecordGrammar.map_location_poll()
	code.append_array(PackedByteArray([0x04, 0x17, 0x80, 0x12, 0xFF, 0x00, 0x00]))
	var queue := {"poll_offset": 0, "result_storage": "state_u16", "result_index": 18, "values": [7]}
	var supplied_state := SandboxStateScript.new(1)
	var supplied := runner.run(code, 0, supplied_state, -1, RunnerScript.DEFAULT_MAX_STEPS,
		{"native_record_policy": "omit_bounded", "map_locations": [queue]})
	_check(
		supplied.status == "script_return"
		and supplied.trace[0].effect == "map_location_supplied"
		and int(supplied.trace[0].map_location_value) == 7
		and supplied.trace[0].write_storage == "state_u16" and int(supplied.trace[0].write_start) == 18
		and supplied_state.read_value("state_u16", 18) == 7 and supplied_state.read_value("state_u16", 23) == 7
		and (queue.values as Array).is_empty(),
		"a declared map location is written into the native map result cell and consumed"
	)
	var spent_state := SandboxStateScript.new(1)
	var spent := runner.run(code, 0, spent_state, -1, RunnerScript.DEFAULT_MAX_STEPS,
		{"native_record_policy": "omit_bounded", "map_locations": [queue]})
	_check(
		spent.status == "script_return" and spent.trace[0].effect == "native_record_effects_omitted"
		and spent_state.read_value("state_u16", 18) == 0,
		"a spent map-location queue leaves the poll an omitted native"
	)
	var elsewhere_state := SandboxStateScript.new(1)
	var elsewhere := runner.run(code, 0, elsewhere_state, -1, RunnerScript.DEFAULT_MAX_STEPS,
		{"native_record_policy": "omit_bounded", "map_locations": [{"poll_offset": 8, "result_storage": "state_u16", "result_index": 18, "values": [3]}]})
	_check(
		elsewhere.status == "script_return" and elsewhere.trace[0].effect == "native_record_effects_omitted"
		and elsewhere_state.read_value("state_u16", 18) == 0,
		"a contract at another offset supplies nothing here"
	)


func _sha256(data: PackedByteArray) -> String:
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK or context.update(data) != OK:
		return ""
	return context.finish().hex_encode()


## Core 0.377.0 (TD-56): command 0x09 and token 0xF6 address one storage, so routine 0's
## message id and routine 23's selector are `global_i32[1]` whoever wrote it. The
## `argument_slots` dictionary is per-run provenance and is never read for meaning.
func _test_argument_storage_alias(runner: KakyuMesEventRunner) -> void:
	var read_23 := PackedByteArray([0x1D, 0x02, 0x17, 0xFF, 0x00, 0x00])
	var read_0 := PackedByteArray([0x1D, 0x02, 0x00, 0xFF, 0x00, 0x00])
	# A seeded index 1 with no command 0x09 at all: where an argument-slot mirror and the alias differ.
	var seeded := SandboxStateScript.new(1)
	seeded.write_value("global_i32", 1, 33)
	var seeded_23 := runner.run(read_23, 0, seeded)
	_check(
		seeded_23.status == "script_return"
		and seeded_23.trace[0].effect == "bgm_request"
		and seeded_23.trace[0].bgm_selector == 33
		and seeded_23.trace[0].resource_name == "MAKI.WAV"
		and seeded_23.argument_slots.is_empty()
		and seeded_23.state_diff.is_empty(),
		"routine 23 reads global_i32[1] seeded by the caller although no command 0x09 ran"
	)
	var seeded_0 := SandboxStateScript.new(1)
	seeded_0.write_value("global_i32", 1, 100)
	var read_0_result := runner.run(read_0, 0, seeded_0)
	_check(
		read_0_result.trace[0].effect == "message_record_id" and read_0_result.trace[0].message_record_id == 100 and read_0_result.argument_slots.is_empty(),
		"routine 0 reads global_i32[1] seeded by the caller although no command 0x09 ran"
	)
	# A command 0x0A write is visible to the reads (synthetic: the current decoders find no 0x0A row in the corpus).
	var written_by_0a := runner.run(PackedByteArray([0x0A, 0x01, 0xFF, 0x1A, 0xFF, 0x00, 0x1D, 0x02, 0x17, 0xFF, 0x00, 0x00]), 0, SandboxStateScript.new(1))
	_check(
		written_by_0a.status == "script_return"
		and written_by_0a.trace[0].effect == "global_i32_write_run"
		and written_by_0a.trace[1].effect == "bgm_request"
		and written_by_0a.trace[1].bgm_selector == 26
		and written_by_0a.argument_slots.is_empty(),
		"a command 0x0A write to global_i32[1] is read by routine 23 and leaves the provenance slots empty"
	)
	# The provenance slots are never read for meaning: a seeded slot that disagrees with the storage loses.
	var disagreeing := SandboxStateScript.new(1)
	disagreeing.write_value("global_i32", 1, 33)
	var disagreeing_result := runner.run(read_23, 0, disagreeing, -1, RunnerScript.DEFAULT_MAX_STEPS, {"argument_slots": {1: 99}})
	_check(
		disagreeing_result.trace[0].effect == "bgm_request"
		and disagreeing_result.trace[0].bgm_selector == 33
		and disagreeing_result.argument_slots == {1: 99},
		"argument_slots seeded in the context is provenance only: routine 23 reads the storage, not the slot"
	)
	var slot_only := runner.run(read_0, 0, SandboxStateScript.new(1), -1, RunnerScript.DEFAULT_MAX_STEPS, {"argument_slots": {1: 99}})
	_check(
		slot_only.trace[0].effect == "message_record_id" and slot_only.trace[0].message_record_id == 0 and slot_only.argument_slots == {1: 99},
		"a provenance slot alone does not supply routine 0's message id: the unwritten storage reads the sandbox's 0 (tool assumption)"
	)
	# The has(1) gate is gone: an unwritten index 1 reads 0 (the sandbox's value, a tool assumption).
	var unwritten_0 := runner.run(read_0, 0, SandboxStateScript.new(1))
	_check(
		unwritten_0.trace[0].effect == "message_record_id" and unwritten_0.trace[0].message_record_id == 0,
		"routine 0 with an unwritten index 1 reads 0 instead of falling to a shared-routine boundary"
	)
	var unwritten_23 := runner.run(read_23, 0, SandboxStateScript.new(1))
	_check(
		unwritten_23.status == "unsupported_opcode"
		and unwritten_23.trace[0].effect == "unsupported_stop"
		and str(unwritten_23.error).contains("unmapped selector: 0")
		and unwritten_23.state_diff.is_empty(),
		"routine 23 with an unwritten index 1 refuses on the unmapped selector 0 and writes nothing"
	)
