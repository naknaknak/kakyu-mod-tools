extends "res://tests/test_case.gd"

const CallerRouteScript := preload("res://content_core/mes_caller_route.gd")
const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")
const RunnerScript := preload("res://content_core/mes_event_runner.gd")
const DecoderScript := preload("res://content_core/mes_instruction_decoder.gd")
const SandboxStateScript := preload("res://content_core/mes_sandbox_state.gd")


func _ready() -> void:
	var dispatch := PackedByteArray([0x0F, 0x01])
	dispatch.append_array("eventd99.mes".to_ascii_buffer())
	dispatch.append_array(PackedByteArray([0x00, 0x00]))
	var prefix := PackedByteArray([
		0x09, 0x01, 0x00, 0x1A, 0xFF, 0x00,
		0x1D, 0x02, 0x17, 0xFF, 0x00,
	])
	var suffix := PackedByteArray([
		0x03, 0x1E, 0x01, 0xF1, 0x01, 0x00, 0xFF, 0x00,
		0x1F, 0x01, 0x00, 0x00, 0x00,
		0x07, 0xF1, 0xB7, 0x00, 0xFF, 0x00, 0xF1, 0x0C, 0x00, 0xFF, 0x00,
		0x1F, 0x02, 0x00, 0x00, 0x00,
		0x0E, 0x01, 0x4D, 0x41, 0x43, 0x48, 0x49, 0x2E, 0x4D, 0x45, 0x53, 0x00, 0x00,
	])
	var bytecode := dispatch.duplicate()
	bytecode.append_array(prefix)
	bytecode.append_array(suffix)
	var resume_offset := dispatch.size()
	var bgm_boundary := resume_offset + prefix.size()
	var handoff_offset := bytecode.size() - 13
	var specification := {
		"callee_entry": "EVENTD99.MES",
		"dispatch_offset": 0,
		"resume_offset": resume_offset,
		"bgm_boundary": bgm_boundary,
		"bgm_sha256": _sha256(prefix),
		"date_index": 7,
		"bgm_routes": [
			{"date": 1224, "selector": 26, "resource": "X_MAS.WAV"},
			{"date": 0, "default": true, "selector": 26, "resource": "X_MAS.WAV"},
		],
		"handoff_offset": handoff_offset,
		"handoff_end": bytecode.size(),
		"handoff_sha256": _sha256(suffix),
		"handoff_target": "MACHI.MES",
		"handoff_trace_commands": [0x03, 0x1F, 0x07, 0x1F, 0x0E],
		"state_writes": [
			{"storage": "global_u8", "index": 286, "bank": 0, "value": 1},
			{"storage": "banked_u16", "index": 183, "bank": 0, "value": 12},
		],
	}
	var caller_route := CallerRouteScript.new()
	var validation: Dictionary = caller_route.validate(bytecode, bytecode.size(), specification)
	_check(
		validation.get("ok", false)
		and str(validation.get("schema", "")) == ContentCoreVersionScript.MES_CALLER_ROUTE_SCHEMA
		and int(validation.get("resume_offset", -1)) == resume_offset
		and int(validation.get("boundary_offset", -1)) == bgm_boundary
		and int(validation.get("handoff_offset", -1)) == handoff_offset,
		"shared caller route validates exact dispatch, BGM prefix, writes, and handoff"
	)

	var christmas_state := SandboxStateScript.new(1)
	christmas_state.write_value("state_u16", 7, 1224)
	var christmas_execution: Dictionary = caller_route.run_bgm_prefix(bytecode, christmas_state, specification)
	_check(
		christmas_execution.get("ok", false)
		and int(christmas_execution.route.selector) == 26
		and str(christmas_execution.route.resource) == "X_MAS.WAV"
		and christmas_execution.result.get("state_diff", []) == [{"storage": "global_i32", "bank": 0, "index": 1, "before": 0, "after": 26}],
		"shared caller route resolves an exact-date BGM request; its only sandbox write is its own argument storage global_i32[1] (Core 0.377.0)"
	)
	# The prefix's diff may be only the cells its own command-0x09 rows wrote, with the
	# values they wrote (Core 0.377.0, TD-56); everything else refuses.
	var own_row := {"command_id": 0x09, "write_storage": "global_i32", "write_start": 1, "write_count": 1, "argument_values": [26]}
	var own_change := {"storage": "global_i32", "bank": 0, "index": 1, "before": 0, "after": 26}
	_check(caller_route._diff_is_own_argument_storage({"trace": [own_row], "state_diff": [own_change]}), "a prefix diff naming exactly its own argument write is accepted")
	_check(caller_route._diff_is_own_argument_storage({"trace": [own_row], "state_diff": []}), "a prefix whose argument cell already held the value (no diff row) is accepted")
	_check(not caller_route._diff_is_own_argument_storage({"trace": [own_row], "state_diff": [own_change.merged({"after": 34}, true)]}), "a prefix diff with a value its own row did not write is refused")
	_check(not caller_route._diff_is_own_argument_storage({"trace": [own_row], "state_diff": [own_change.merged({"index": 2}, true)]}), "a global_i32 cell no command-0x09 row wrote is refused")
	_check(not caller_route._diff_is_own_argument_storage({"trace": [own_row], "state_diff": [own_change.merged({"storage": "global_u8"}, true)]}), "another storage is refused")
	_check(not caller_route._diff_is_own_argument_storage({"trace": [own_row], "state_diff": [own_change.merged({"bank": 1}, true)]}), "another bank is refused")
	var command_0a_row := {"command_id": 0x0A, "write_storage": "global_i32", "write_start": 1, "write_count": 1}
	_check(not caller_route._diff_is_own_argument_storage({"trace": [command_0a_row], "state_diff": [own_change]}), "a command-0x0A write carries no argument values and is refused")
	_check(not caller_route._diff_is_own_argument_storage({"trace": [own_row.merged({"write_count": 2}, true)], "state_diff": [own_change]}), "a row whose write count disagrees with its values is refused")
	var default_route: Dictionary = caller_route.route_for_date(500, specification)
	_check(int(default_route.get("selector", -1)) == 26 and str(default_route.get("resource", "")) == "X_MAS.WAV", "shared caller route uses only the explicit default BGM record")

	var handoff_state := SandboxStateScript.new(1)
	var handoff_execution: Dictionary = caller_route.run_handoff(bytecode, handoff_state, specification)
	_check(
		handoff_execution.get("ok", false)
		and handoff_state.read_value("global_u8", 286) == 1
		and handoff_state.read_value("banked_u16", 183, 0) == 12
		and (handoff_execution.result.get("state_diff", []) as Array).size() == 2,
		"shared caller route applies only the expected isolated handoff writes"
	)

	var changed_prefix := bytecode.duplicate()
	changed_prefix[resume_offset + 3] ^= 0x01
	_check(not caller_route.validate(changed_prefix, changed_prefix.size(), specification).get("ok", false), "shared caller route rejects a changed BGM prefix hash")
	var shifted_specification: Dictionary = specification.duplicate(true)
	shifted_specification["handoff_offset"] = handoff_offset + 1
	_check(not caller_route.validate(bytecode, bytecode.size(), shifted_specification).get("ok", false), "shared caller route rejects a shifted handoff coordinate")
	var wrong_target_specification: Dictionary = specification.duplicate(true)
	wrong_target_specification["handoff_target"] = "OTHER.MES"
	_check(not caller_route.validate(bytecode, bytecode.size(), wrong_target_specification).get("ok", false), "shared caller route rejects a changed handoff target")
	var missing_default_specification: Dictionary = specification.duplicate(true)
	missing_default_specification["bgm_routes"] = [{"date": 1224, "selector": 26, "resource": "X_MAS.WAV"}]
	_check(not caller_route.validate(bytecode, bytecode.size(), missing_default_specification).get("ok", false), "shared caller route requires an explicit default BGM route")
	var duplicate_default_specification: Dictionary = specification.duplicate(true)
	duplicate_default_specification["bgm_routes"] = [
		{"date": 0, "default": true, "selector": 26, "resource": "X_MAS.WAV"},
		{"date": 1, "default": true, "selector": 26, "resource": "X_MAS.WAV"},
	]
	_check(not caller_route.run_bgm_prefix(bytecode, SandboxStateScript.new(1), duplicate_default_specification).get("ok", false), "shared caller route execution rejects ambiguous default BGM records")
	var unsafe_target_specification: Dictionary = specification.duplicate(true)
	unsafe_target_specification["handoff_target"] = "../MACHI.MES"
	_check(not caller_route.validate(bytecode, bytecode.size(), unsafe_target_specification).get("ok", false), "shared caller route rejects unsafe handoff entry names")
	var duplicate_state_specification: Dictionary = specification.duplicate(true)
	duplicate_state_specification["state_writes"] = [specification.state_writes[0], specification.state_writes[0]]
	_check(not caller_route.run_handoff(bytecode, SandboxStateScript.new(1), duplicate_state_specification).get("ok", false), "shared caller route execution rejects duplicate state targets")

	_test_bgm_dispatch_alignment(bytecode, specification)
	_test_direct_route(dispatch, suffix)
	_test_choice_projection(dispatch)
	_test_restore_followup(dispatch)
	await get_tree().process_frame
	get_tree().quit(1 if _failed else 0)



func _test_bgm_dispatch_alignment(bytecode: PackedByteArray, specification: Dictionary) -> void:
	# The BGM route used to decode its dispatch straight from the catalog
	# coordinate, so bytes that merely look like a dispatch were accepted as one.
	# These are the cases the direct route already proved, applied to the path
	# that six of the nine cataloged routes take.
	var caller_route := CallerRouteScript.new()
	for prefix in [PackedByteArray([0x12, 0x01]), PackedByteArray([0x01, 0x41])]:
		var shadow: PackedByteArray = prefix.duplicate()
		shadow.append_array(bytecode)
		var shifted := _shift_bgm_coordinates(specification, prefix.size())
		_check(
			not caller_route.validate(shadow, shadow.size(), shifted, [0]).get("ok", false),
			"caller BGM route rejects a dispatch envelope inside record payload %02X" % int(prefix[0])
		)

	var preceding_record := PackedByteArray([0x12, 0x01, 0x41, 0x00, 0x00])
	var aligned := preceding_record.duplicate()
	aligned.append_array(bytecode)
	var aligned_specification := _shift_bgm_coordinates(specification, preceding_record.size())
	_check(
		caller_route.validate(aligned, aligned.size(), aligned_specification, [preceding_record.size()]).get("ok", false),
		"caller BGM route accepts a real dispatch after a complete native record"
	)

	var opaque := PackedByteArray([0x12, 0x03])
	opaque.append_array(bytecode)
	var opaque_specification := _shift_bgm_coordinates(specification, 2)
	_check(
		not caller_route.validate(opaque, opaque.size(), opaque_specification).get("ok", false),
		"caller BGM route fails closed when an opaque prefix prevents dispatch alignment"
	)
	_check(
		caller_route.validate(opaque, opaque.size(), opaque_specification, [2]).get("ok", false),
		"caller BGM route accepts an indexed dispatch in a separate region after an opaque prefix"
	)

	for invalid in [[-1], [1 << 40], ["0"], [4, 4], [8, 4]]:
		_check(
			not caller_route.validate(bytecode, bytecode.size(), specification, invalid).get("ok", false),
			"caller BGM route rejects invalid address-table offset %s" % str(invalid)
		)


func _shift_bgm_coordinates(specification: Dictionary, amount: int) -> Dictionary:
	var shifted: Dictionary = specification.duplicate(true)
	for key in ["dispatch_offset", "resume_offset", "bgm_boundary", "handoff_offset", "handoff_end"]:
		shifted[key] = int(specification[key]) + amount
	return shifted


func _test_direct_route(dispatch: PackedByteArray, suffix: PackedByteArray) -> void:
	var bytecode := dispatch.duplicate()
	bytecode.append_array(suffix)
	var specification := {
		"direct_handoff": true,
		"caller_entry": "CALLER.MES",
		"callee_entry": "EVENTD99.MES",
		"dispatch_offset": 0,
		"resume_offset": dispatch.size(),
		"handoff_offset": bytecode.size() - 13,
		"handoff_end": bytecode.size(),
		"handoff_sha256": _sha256(suffix),
		"handoff_target": "MACHI.MES",
		"handoff_trace_commands": [0x03, 0x1F, 0x07, 0x1F, 0x0E],
		"state_writes": [
			{"storage": "global_u8", "index": 286, "bank": 0, "value": 1},
			{"storage": "banked_u16", "index": 183, "bank": 0, "value": 12},
		],
	}
	var caller_route := CallerRouteScript.new()
	var validation: Dictionary = caller_route.validate_direct(bytecode, bytecode.size(), specification)
	_check(
		validation.get("ok", false)
		and validation.get("schema", "") == ContentCoreVersionScript.MES_DIRECT_CALLER_ROUTE_SCHEMA
		and validation.get("caller_entry", "") == "CALLER.MES"
		and validation.get("start_offset", -1) == dispatch.size()
		and validation.get("handoff_offset", -1) == bytecode.size() - 13
		and validation.get("handoff_end", -1) == bytecode.size()
		and validation.get("target_entry", "") == "MACHI.MES"
		and validation.get("state_writes", []) == specification.state_writes,
		"direct caller validates its exact dispatch, suffix, trace, state, and versioned result"
	)
	if validation.get("ok", false):
		validation.state_writes[0].value = 99
		_check(specification.state_writes[0].value == 1, "direct caller result cannot mutate the specification")
	var json_specification: Dictionary = JSON.parse_string(JSON.stringify(specification))
	_check(caller_route.validate_direct(bytecode, bytecode.size(), json_specification).get("ok", false), "direct caller accepts exact integer values from JSON")
	_check(not caller_route.validate_direct(bytecode, bytecode.size() - 1, specification).get("ok", false), "direct caller rejects a mismatched code size")
	for override in [
		{"dispatch_offset": -1}, {"dispatch_offset": true}, {"dispatch_offset": NAN},
		{"resume_offset": dispatch.size() + 0.5}, {"resume_offset": INF},
		{"resume_offset": specification.handoff_offset},
		{"handoff_offset": specification.handoff_offset + 1},
		{"handoff_end": bytecode.size() + 1}, {"handoff_end": specification.handoff_offset},
		{"handoff_sha256": "g".repeat(64)}, {"handoff_sha256": "0".repeat(64)},
		{"caller_entry": "../CALLER.MES"}, {"caller_entry": "BAD\n.MES"},
		{"callee_entry": "OTHER.MES"}, {"callee_entry": "bad?.mes"},
		{"handoff_target": "OTHER.MES"}, {"handoff_target": "C:MACHI.MES"},
		{"handoff_trace_commands": []}, {"handoff_trace_commands": [0x03, 0x00]},
		{"handoff_trace_commands": [0x1F, 0x1F, 0x07, 0x1F, 0x0E]},
		{"handoff_trace_commands": [0x03, 0x1F, 0x07, 0x1F, 14.5]},
		{"state_writes": []}, {"state_writes": ["invalid"]},
		{"state_writes": [specification.state_writes[0], specification.state_writes[0]]},
		{"direct_handoff": 1}, {"direct_handoff": false},
	]:
		var changed: Dictionary = specification.duplicate(true)
		changed.merge(override, true)
		_check(not caller_route.validate_direct(bytecode, bytecode.size(), changed).get("ok", false), "direct caller rejects invalid %s: %s" % [str(override.keys()[0]), str(override.values()[0])])
	for override in [
		{"storage": "unknown"}, {"index": -1}, {"index": 1.5}, {"index": INF},
		{"bank": true}, {"bank": -1}, {"value": NAN}, {"value": 256}, {"value": -1},
	]:
		var changed: Dictionary = specification.duplicate(true)
		changed.state_writes[0].merge(override, true)
		_check(not caller_route.validate_direct(bytecode, bytecode.size(), changed).get("ok", false), "direct caller rejects invalid state %s: %s" % [str(override.keys()[0]), str(override.values()[0])])
	for key in specification:
		var missing: Dictionary = specification.duplicate(true)
		missing.erase(key)
		_check(not caller_route.validate_direct(bytecode, bytecode.size(), missing).get("ok", false), "direct caller rejects missing %s" % key)

	var changed_dispatch := bytecode.duplicate()
	changed_dispatch[2] = 0x45
	_check(not caller_route.validate_direct(changed_dispatch, changed_dispatch.size(), specification).get("ok", false), "direct caller rejects changed dispatch bytes even when the decoded target is equivalent")
	var changed_suffix := bytecode.duplicate()
	changed_suffix[dispatch.size() + 4] = 2
	_check(not caller_route.validate_direct(changed_suffix, changed_suffix.size(), specification).get("ok", false), "direct caller rejects changed suffix bytes")
	var changed_state_specification: Dictionary = specification.duplicate(true)
	changed_state_specification.handoff_sha256 = _sha256(changed_suffix.slice(dispatch.size()))
	_check(not caller_route.validate_direct(changed_suffix, changed_suffix.size(), changed_state_specification).get("ok", false), "direct caller rejects unexpected state after an explicitly refreshed suffix hash")
	var shadow_bytecode := bytecode.slice(0, int(specification.handoff_offset))
	shadow_bytecode.append_array(PackedByteArray([0x01, 0x41]))
	shadow_bytecode.append_array(suffix.slice(suffix.size() - 13))
	var shadow_specification: Dictionary = specification.duplicate(true)
	shadow_specification.handoff_offset += 2
	shadow_specification.handoff_end = shadow_bytecode.size()
	shadow_specification.handoff_sha256 = _sha256(shadow_bytecode.slice(dispatch.size()))
	_check(not caller_route.validate_direct(shadow_bytecode, shadow_bytecode.size(), shadow_specification).get("ok", false), "direct caller cannot execute a handoff-shaped envelope inside a message payload")
	_test_direct_dispatch_alignment(bytecode, specification)

	var state := SandboxStateScript.new(1)
	state.write_value("global_u8", 286, 5)
	state.write_value("banked_u16", 183, 7)
	state.write_value("state_u16", 7, 500)
	var before := state.snapshot()
	var result := RunnerScript.new().run(bytecode, dispatch.size(), state)
	_check(caller_route.direct_result_matches(result, before, specification, state), "direct result matcher preserves nonzero prior writes and unrelated existing state")
	var untrusted_diff: Dictionary = result.duplicate(true)
	untrusted_diff.state_diff = []
	_check(caller_route.direct_result_matches(untrusted_diff, before, specification, state), "direct result matcher derives its diff from the live state snapshot")
	for override in [
		{"status": "completed"}, {"offset": specification.handoff_offset + 1},
		{"offset": NAN}, {"trace": []}, {"trace": "invalid"},
	]:
		var changed: Dictionary = result.duplicate(true)
		changed.merge(override, true)
		_check(not caller_route.direct_result_matches(changed, before, specification, state), "direct result matcher rejects invalid %s" % str(override.keys()[0]))
	var changed_trace: Dictionary = result.duplicate(true)
	changed_trace.trace[-1].target_entry = "OTHER.MES"
	_check(not caller_route.direct_result_matches(changed_trace, before, specification, state), "direct result matcher rejects an unexpected final target")
	changed_trace = result.duplicate(true)
	changed_trace.trace = []
	changed_trace.trace.append_array(result.trace)
	changed_trace.trace[0] = "invalid"
	_check(not caller_route.direct_result_matches(changed_trace, before, specification, state), "direct result matcher rejects an untyped trace record")
	state.write_value("global_u8", 100, 1)
	_check(not caller_route.direct_result_matches(result, before, specification, state), "direct result matcher rejects an additional changed state key")
	var swapped_state := SandboxStateScript.new(1)
	swapped_state.write_value("global_u8", 286, 1)
	swapped_state.write_value("banked_u16", 183, 7)
	var swapped_before := swapped_state.snapshot()
	var swapped_result := RunnerScript.new().run(bytecode, dispatch.size(), swapped_state)
	swapped_state.write_value("global_u8", 100, 1)
	_check(
		swapped_state.diff(swapped_before).size() == specification.state_writes.size()
		and not caller_route.direct_result_matches(swapped_result, swapped_before, specification, swapped_state),
		"direct result matcher rejects an unexpected key replacing an unchanged expected key at the same diff count"
	)
	_test_direct_address_table(dispatch, suffix, specification)


func _test_direct_dispatch_alignment(bytecode: PackedByteArray, specification: Dictionary) -> void:
	var caller_route := CallerRouteScript.new()
	for prefix in [PackedByteArray([0x12, 0x01]), PackedByteArray([0x01, 0x41])]:
		var shadow: PackedByteArray = prefix.duplicate()
		shadow.append_array(bytecode)
		var shifted := _shift_direct_coordinates(specification, prefix.size())
		_check(not caller_route.validate_direct(shadow, shadow.size(), shifted).get("ok", false), "direct caller rejects a dispatch envelope inside record payload %02X" % int(prefix[0]))
		_check(not caller_route.validate_direct(shadow, shadow.size(), shifted, [0]).get("ok", false), "direct caller rejects record payload %02X within an address-table region" % int(prefix[0]))

	var preceding_record := PackedByteArray([0x12, 0x01, 0x41, 0x00, 0x00])
	var aligned := preceding_record.duplicate()
	aligned.append_array(bytecode)
	var aligned_specification := _shift_direct_coordinates(specification, preceding_record.size())
	_check(caller_route.validate_direct(aligned, aligned.size(), aligned_specification).get("ok", false), "direct caller accepts a real dispatch after a complete native record")
	_check(caller_route.validate_direct(aligned, aligned.size(), aligned_specification, [preceding_record.size()]).get("ok", false), "direct caller accepts an address-table coordinate at a real dispatch boundary")

	var opaque := PackedByteArray([0x12, 0x03])
	opaque.append_array(bytecode)
	_check(not caller_route.validate_direct(opaque, opaque.size(), _shift_direct_coordinates(specification, 2)).get("ok", false), "direct caller fails closed when an opaque prefix prevents dispatch alignment")
	_check(caller_route.validate_direct(opaque, opaque.size(), _shift_direct_coordinates(specification, 2), [2]).get("ok", false), "direct caller accepts an indexed dispatch in a separate region after an opaque prefix")
	var opaque_tail := bytecode.duplicate()
	opaque_tail.append_array(PackedByteArray([0x12, 0x03]))
	_check(caller_route.validate_direct(opaque_tail, opaque_tail.size(), specification).get("ok", false), "a later opaque tail does not invalidate the proven dispatch and handoff")


func _shift_direct_coordinates(specification: Dictionary, amount: int) -> Dictionary:
	var shifted: Dictionary = specification.duplicate(true)
	for key in ["dispatch_offset", "resume_offset", "handoff_offset", "handoff_end"]:
		shifted[key] += amount
	return shifted


func _test_direct_address_table(dispatch: PackedByteArray, suffix: PackedByteArray, specification: Dictionary) -> void:
	var bytecode := dispatch.duplicate()
	bytecode.append_array(PackedByteArray([0x18, 0x00, 0xFF, 0x00]))
	bytecode.append_array(suffix)
	var with_table: Dictionary = specification.duplicate(true)
	with_table.handoff_offset += 4
	with_table.handoff_end = bytecode.size()
	with_table.handoff_sha256 = _sha256(bytecode.slice(dispatch.size()))
	with_table.handoff_trace_commands.push_front(0x18)
	var caller_route := CallerRouteScript.new()
	var offsets: Array = [dispatch.size() + 4]
	_check(caller_route.validate_direct(bytecode, bytecode.size(), with_table, offsets).get("ok", false), "direct caller supplies the active address table to its fresh-state execution")
	_check(offsets == [dispatch.size() + 4], "direct caller does not mutate the supplied address table")
	_check(not caller_route.validate_direct(bytecode, bytecode.size(), with_table).get("ok", false), "direct caller fails closed when a required address table is absent")
	for invalid in [-1, bytecode.size() + 1, 1.5, NAN, true]:
		_check(not caller_route.validate_direct(bytecode, bytecode.size(), with_table, [invalid]).get("ok", false), "direct caller rejects invalid address-table offset %s" % str(invalid))
	for invalid_table in [[offsets[0], bytecode.size()], [offsets[0], offsets[0]], [offsets[0], 0]]:
		_check(not caller_route.validate_direct(bytecode, bytecode.size(), with_table, invalid_table).get("ok", false), "direct caller rejects a non-container address table %s" % str(invalid_table))


func _test_choice_projection(dispatch: PackedByteArray) -> void:
	var fixture := _choice_fixture(dispatch)
	var bytecode: PackedByteArray = fixture.bytecode
	var specification: Dictionary = fixture.specification
	var caller_route := CallerRouteScript.new()
	var validation: Dictionary = caller_route.validate_choice_projection(bytecode, bytecode.size(), specification)
	_check(
		validation.get("ok", false)
		and validation.get("schema", "") == ContentCoreVersionScript.MES_CALLER_CHOICE_PROJECTION_SCHEMA
		and validation.get("caller_entry", "") == "CALLER.MES"
		and validation.get("start_offset", -1) == specification.resume_offset
		and validation.get("bgm_offset", -1) == specification.caller_bgm_offset
		and validation.get("bgm_resource", "") == "IDOU.WAV"
		and validation.get("definition_offsets", []) == specification.caller_definition_offsets
		and validation.get("choice_boundary", -1) == specification.caller_choice_boundary
		and validation.get("choice_routine", -1) == 40
		and validation.get("trace_boundary_policy", "") == "structural_indexed_instruction"
		and validation.get("verified_trace_records", -1) == 5,
		"caller choice projection validates an exact dispatch, stored suffix, BGM and definitions"
	)
	_check(
		validation.get("selected_state_policy", "") == "fresh_isolated_default"
		and validation.get("stored_suffix_only", false)
		and not validation.get("callee_reachability_verified", true)
		and not validation.get("native_choice_executed", true)
		and validation.get("execution_policy", "") == "explicit_remake_one_based_result_native_effects_omitted",
		"caller choice projection labels default-state proof and omitted native execution"
	)
	if validation.get("ok", false):
		validation.definition_offsets[0] += 1
		_check(specification.caller_definition_offsets[0] == fixture.first_definition, "caller choice result cannot mutate specification offsets")
	var json_specification: Dictionary = JSON.parse_string(JSON.stringify(specification))
	_check(caller_route.validate_choice_projection(bytecode, bytecode.size(), json_specification).get("ok", false), "caller choice accepts exact integer coordinates from JSON")
	_check(not caller_route.validate_choice_projection(bytecode, bytecode.size() - 1, specification).get("ok", false), "caller choice rejects mismatched code size")
	for override in [
		{"caller_choice_projection": false}, {"caller_choice_projection": 1},
		{"caller_entry": "../CALLER.MES"}, {"callee_entry": 123}, {"callee_entry": "OTHER.MES"},
		{"dispatch_offset": true}, {"dispatch_offset": -1}, {"dispatch_offset": NAN},
		{"resume_offset": specification.resume_offset + 1}, {"resume_offset": INF},
		{"caller_choice_boundary": specification.caller_choice_boundary + 1},
		{"caller_choice_boundary": bytecode.size()},
		{"caller_bgm_offset": specification.caller_bgm_offset + 1},
		{"caller_bgm_offset": specification.caller_bgm_offset + 0.5},
		{"caller_suffix_sha256": "0".repeat(64)}, {"caller_suffix_sha256": "g".repeat(64)},
		{"caller_suffix_sha256": 123},
		{"callee_return_offsets": []}, {"callee_return_offsets": [1, 1]},
		{"callee_return_offsets": [2, 1]}, {"callee_return_offsets": [true]},
		{"caller_definition_offsets": []}, {"caller_definition_offsets": "invalid"},
		{"caller_definition_offsets": [specification.caller_definition_offsets[0] + 1, specification.caller_definition_offsets[1]]},
		{"caller_definition_offsets": [0]},
		{"caller_bgm_resources": []}, {"caller_bgm_resources": ["STAFF.WAV"]},
		{"caller_bgm_resources": ["IDOU.WAV", "IDOU.WAV"]},
		{"caller_bgm_resources": ["../IDOU.WAV"]}, {"caller_bgm_resources": [1]},
		{"caller_bgm_resources": ["IDOU\n.WAV"]}, {"caller_bgm_resources": ["IDOU?.WAV"]},
	]:
		var changed: Dictionary = specification.duplicate(true)
		changed.merge(override, true)
		_check(not caller_route.validate_choice_projection(bytecode, bytecode.size(), changed).get("ok", false), "caller choice rejects invalid %s: %s" % [str(override.keys()[0]), str(override.values()[0])])
	for key in specification:
		var missing: Dictionary = specification.duplicate(true)
		missing.erase(key)
		_check(not caller_route.validate_choice_projection(bytecode, bytecode.size(), missing).get("ok", false), "caller choice rejects missing %s" % key)
	var changed_dispatch := bytecode.duplicate()
	changed_dispatch[2] = 0x45
	_check(not caller_route.validate_choice_projection(changed_dispatch, changed_dispatch.size(), specification).get("ok", false), "caller choice rejects equivalent target spelling with altered dispatch envelope bytes")
	var changed_suffix := bytecode.duplicate()
	changed_suffix[int(specification.resume_offset) + 5] = 2
	_check(not caller_route.validate_choice_projection(changed_suffix, changed_suffix.size(), specification).get("ok", false), "caller choice rejects modified suffix bytes")
	var changed_choice := bytecode.duplicate()
	changed_choice[int(specification.caller_choice_boundary) + 2] = 41
	_check(not caller_route.validate_choice_projection(changed_choice, changed_choice.size(), specification).get("ok", false), "caller choice checks the final routine outside the stored suffix hash")
	for prefix in [PackedByteArray([0x12, 0x01]), PackedByteArray([0x01, 0x41])]:
		var shadow := _choice_fixture(dispatch, prefix)
		_check(not caller_route.validate_choice_projection(shadow.bytecode, shadow.bytecode.size(), shadow.specification, [0]).get("ok", false), "caller choice rejects dispatch-shaped payload bytes in record %02X" % int(prefix[0]))
	var opaque := _choice_fixture(dispatch, PackedByteArray([0x12, 0x03]))
	_check(not caller_route.validate_choice_projection(opaque.bytecode, opaque.bytecode.size(), opaque.specification).get("ok", false), "caller choice rejects a dispatch beyond an unframed opaque prefix")
	var offsets: Array = [2]
	_check(caller_route.validate_choice_projection(opaque.bytecode, opaque.bytecode.size(), opaque.specification, offsets).get("ok", false) and offsets == [2], "caller choice uses the actual separate container region without mutating its address table")
	for invalid_table in [[-1], [1.5], [NAN], [true], [bytecode.size()], [0, 0], [1, 0]]:
		_check(not caller_route.validate_choice_projection(bytecode, bytecode.size(), specification, invalid_table).get("ok", false), "caller choice rejects malformed container address table %s" % str(invalid_table))
	var active_state := SandboxStateScript.new(1)
	active_state.write_value("state_u16", 7, 25)
	var active_probe := RunnerScript.new().run(bytecode, int(specification.resume_offset), active_state)
	# The probe's own command-0x09 argument assignment is a sandbox write since Core
	# 0.377.0, so the snapshot that proves validation leaves the active state alone
	# is taken after the probe.
	var active_before := active_state.snapshot()
	var fresh_validation := caller_route.validate_choice_projection(bytecode, bytecode.size(), specification)
	_check(
		active_probe.get("trace", [])[1].get("resource_name", "") == "X_MAS.WAV"
		and fresh_validation.get("bgm_resource", "") == "IDOU.WAV"
		and active_state.diff(active_before).is_empty(),
		"caller choice source proof uses fresh default state independently of an active preset"
	)
	var native_fixture := _choice_fixture(dispatch, PackedByteArray(), PackedByteArray([0x12, 0x01, 0x41, 0x00, 0x00]))
	_check(not caller_route.validate_choice_projection(native_fixture.bytecode, native_fixture.bytecode.size(), native_fixture.specification).get("ok", false), "caller choice does not silently skip a native record before its expected choice")
	_test_choice_payload_jumps(fixture)


func _test_choice_payload_jumps(fixture: Dictionary) -> void:
	var caller_route := CallerRouteScript.new()
	for payload in [PackedByteArray(), PackedByteArray([0x03, 0x1E, 0x01, 0xF1, 0x01, 0x00, 0xFF, 0x00])]:
		var original: PackedByteArray = fixture.bytecode
		var specification: Dictionary = fixture.specification.duplicate(true)
		var old_bgm := int(specification.caller_bgm_offset)
		var bytecode := original.slice(0, old_bgm)
		var jump := PackedByteArray([0x0C, 0, 0, 0, 0])
		jump.encode_u32(1, old_bgm + 7)
		bytecode.append_array(jump)
		bytecode.append_array(PackedByteArray([0x12, 0x02]))
		# Empty payload places the original BGM inside the native envelope. A
		# state-write payload instead leaves BGM/DEF/choice structurally aligned,
		# so validating those named coordinates alone cannot detect the intrusion.
		bytecode.append_array(payload)
		bytecode.append_array(original.slice(old_bgm))
		var shift: int = 7 + payload.size()
		specification.caller_bgm_offset += shift
		specification.caller_choice_boundary += shift
		for index in range(specification.caller_definition_offsets.size()):
			specification.caller_definition_offsets[index] += shift
			var offset := int(specification.caller_definition_offsets[index])
			bytecode.encode_u32(offset + 5, bytecode.decode_u32(offset + 5) + shift)
		specification.caller_suffix_sha256 = _sha256(bytecode.slice(int(specification.resume_offset), int(specification.caller_choice_boundary)))
		var state := SandboxStateScript.new(1)
		var execution := RunnerScript.new().run(bytecode, int(specification.resume_offset), state)
		var framing := DecoderScript.new().decode_region_structural_aligned(bytecode, 0, bytecode.size())
		var bgm_is_aligned := false
		var payload_is_aligned := false
		for instruction in framing.get("instructions", []):
			bgm_is_aligned = bgm_is_aligned or int(instruction.source_offset) == int(specification.caller_bgm_offset)
			payload_is_aligned = payload_is_aligned or int(instruction.source_offset) == old_bgm + 7
		_check(
			execution.get("status", "") == "def_selection_boundary"
			and int(execution.get("offset", -1)) == int(specification.caller_choice_boundary)
			and not payload_is_aligned
			and bgm_is_aligned == not payload.is_empty()
			and state.read_value("global_u8", 286) == (0 if payload.is_empty() else 1),
			"payload-jump fixture reaches the expected choice while executing %s inside a native record" % ("BGM" if payload.is_empty() else "an intermediate state write")
		)
		_check(
			not caller_route.validate_choice_projection(bytecode, bytecode.size(), specification).get("ok", false),
			"caller choice rejects a jump into native payload %s despite a refreshed suffix hash" % ("BGM" if payload.is_empty() else "state write")
		)
		if not payload.is_empty():
			bytecode.encode_u32(old_bgm + 1, int(specification.caller_bgm_offset))
			specification.caller_suffix_sha256 = _sha256(bytecode.slice(int(specification.resume_offset), int(specification.caller_choice_boundary)))
			_check(caller_route.validate_choice_projection(bytecode, bytecode.size(), specification).get("ok", false), "caller choice accepts an aligned jump over an unexecuted native payload")


func _choice_fixture(dispatch: PackedByteArray, leading: PackedByteArray = PackedByteArray(), native_prefix: PackedByteArray = PackedByteArray()) -> Dictionary:
	var bytecode := leading.duplicate()
	bytecode.append_array(dispatch)
	var resume_offset := bytecode.size()
	bytecode.append_array(native_prefix)
	# Date-sensitive selector: the isolated zero date chooses IDOU; an active
	# preset with date value 25 would choose X_MAS and must not affect validation.
	bytecode.append_array(PackedByteArray([0x09, 0x01, 0x00, 0x80, 0x07, 0x01, 0xE0, 0xFF, 0x00]))
	var bgm_offset := bytecode.size()
	bytecode.append_array(PackedByteArray([0x1D, 0x02, 0x17, 0xFF, 0x00]))
	var definition_offsets: Array[int] = []
	for identifier in [0, 1]:
		definition_offsets.append(bytecode.size())
		var definition := PackedByteArray([0x10, 0x02, identifier, 0xFF, 0x00, 0, 0, 0, 0, 0x01, 0x41 + identifier, 0x00, 0x00])
		definition.encode_u32(5, bytecode.size() + definition.size())
		bytecode.append_array(definition)
	var choice_boundary := bytecode.size()
	bytecode.append_array(PackedByteArray([0x1D, 0x02, 0x28, 0xFF, 0x00]))
	return {
		"bytecode": bytecode, "first_definition": definition_offsets[0],
		"specification": {
			"caller_choice_projection": true,
			"caller_entry": "CALLER.MES", "callee_entry": "EVENTD99.MES",
			"dispatch_offset": leading.size(), "resume_offset": resume_offset,
			"callee_return_offsets": [1, 9],
			"caller_choice_boundary": choice_boundary,
			"caller_suffix_sha256": _sha256(bytecode.slice(resume_offset, choice_boundary)),
			"caller_bgm_offset": bgm_offset, "caller_definition_offsets": definition_offsets,
			"caller_bgm_resources": ["IDOU.WAV", "X_MAS.WAV"],
		},
	}


func _test_restore_followup(dispatch: PackedByteArray) -> void:
	var fixture := _restore_fixture(dispatch)
	var bytecode: PackedByteArray = fixture.bytecode
	var specification: Dictionary = fixture.specification
	var caller_route := CallerRouteScript.new()
	var validation: Dictionary = caller_route.validate_restore_followup(bytecode, bytecode.size(), specification)
	_check(
		validation.get("ok", false)
		and validation.get("schema", "") == ContentCoreVersionScript.MES_CALLER_RESTORE_FOLLOWUP_SCHEMA
		and validation.get("caller_entry", "") == "CALLER.MES"
		and validation.get("dispatch_offset", -1) == specification.dispatch_offset
		and validation.get("resume_offset", -1) == specification.resume_offset
		and validation.get("restore_dispatch_offset", -1) == specification.restore_dispatch_offset
		and validation.get("restore_entry", "") == "D_PIC.MES"
		and validation.get("followup_offset", -1) == specification.followup_offset
		and validation.get("handoff_offset", -1) == specification.handoff_offset
		and validation.get("handoff_end", -1) == bytecode.size()
		and validation.get("target_entry", "") == "MACHI.MES"
		and validation.get("verified_trace_records", -1) == 2,
		"caller restore proves both dispatch envelopes, prefix trace, followup and handoff coordinates"
	)
	_check(
		validation.get("selected_state_policy", "") == "fresh_isolated_default"
		and validation.get("trace_boundary_policy", "") == "structural_indexed_instruction"
		and validation.get("stored_prefix_only", false)
		and not validation.get("restored_body_executed", true)
		and not validation.get("callee_reachability_verified", true)
		and not validation.get("full_followup_reachability_verified", true)
		and not validation.get("outer_host_executed", true),
		"caller restore labels fresh prefix-only proof without callee, restore body or followup execution"
	)
	var state := SandboxStateScript.new(1)
	var execution := RunnerScript.new().run(bytecode, int(specification.resume_offset), state)
	_check(
		not execution.get("ok", true)
		and execution.get("status", "") == "script_dispatch_boundary"
		and execution.get("resume_offset", -1) == specification.followup_offset
		and state.read_value("global_u8", 286) == 1,
		"caller restore accepts the expected unexecuted nested-dispatch boundary with prefix writes"
	)
	var json_specification: Dictionary = JSON.parse_string(JSON.stringify(specification))
	_check(caller_route.validate_restore_followup(bytecode, bytecode.size(), json_specification).get("ok", false), "caller restore accepts exact integer coordinates from JSON")
	_check(not caller_route.validate_restore_followup(bytecode, bytecode.size() - 1, specification).get("ok", false), "caller restore rejects a mismatched code size")
	for override in [
		{"event_id": " "}, {"event_id": 7}, {"restore_followup": false}, {"restore_followup": 1},
		{"caller_entry": "../CALLER.MES"}, {"callee_entry": "OTHER.MES"}, {"callee_entry": 7},
		{"restore_entry": "OTHER.MES"}, {"restore_entry": "D_PIC?.MES"},
		{"handoff_target": "OTHER.MES"}, {"handoff_target": "MACHI\n.MES"},
		{"caller_entry_sha256": "g".repeat(64)}, {"caller_entry_sha256": "A".repeat(64)},
		{"callee_entry_sha256": 12}, {"restore_entry_sha256": ""},
		{"restore_prefix_sha256": "0".repeat(64)}, {"restore_prefix_sha256": 42},
		{"return_offset": -1}, {"return_offset": true}, {"return_offset": INF},
		{"dispatch_offset": true}, {"dispatch_offset": NAN}, {"dispatch_offset": -1},
		{"resume_offset": specification.resume_offset + 1}, {"resume_offset": 1.5},
		{"restore_dispatch_offset": specification.restore_dispatch_offset + 1},
		{"restore_dispatch_offset": specification.resume_offset - 1},
		{"followup_offset": specification.followup_offset - 1},
		{"followup_offset": bytecode.size()}, {"handoff_offset": specification.handoff_offset + 1},
		{"handoff_offset": bytecode.size()}, {"handoff_offset": specification.followup_offset - 1},
	]:
		var changed: Dictionary = specification.duplicate(true)
		changed.merge(override, true)
		_check(not caller_route.validate_restore_followup(bytecode, bytecode.size(), changed).get("ok", false), "caller restore rejects invalid %s: %s" % [str(override.keys()[0]), str(override.values()[0])])
	for key in specification:
		var missing: Dictionary = specification.duplicate(true)
		missing.erase(key)
		_check(not caller_route.validate_restore_followup(bytecode, bytecode.size(), missing).get("ok", false), "caller restore rejects missing %s" % key)
	for offset in [2, int(specification.restore_dispatch_offset) + 2]:
		var changed := bytecode.duplicate()
		changed[offset] = String.chr(changed[offset]).to_upper().unicode_at(0)
		var refreshed: Dictionary = specification.duplicate(true)
		refreshed.restore_prefix_sha256 = _sha256(changed.slice(int(specification.resume_offset), int(specification.followup_offset)))
		_check(not caller_route.validate_restore_followup(changed, changed.size(), refreshed).get("ok", false), "caller restore rejects altered dispatch spelling despite an equivalent target and refreshed hash at %d" % offset)
	var changed_prefix := bytecode.duplicate()
	changed_prefix[int(specification.resume_offset) + 4] = 2
	_check(not caller_route.validate_restore_followup(changed_prefix, changed_prefix.size(), specification).get("ok", false), "caller restore rejects changed prefix bytes")
	var early_return := bytecode.duplicate()
	early_return[int(specification.resume_offset)] = 0
	var early_specification: Dictionary = specification.duplicate(true)
	early_specification.restore_prefix_sha256 = _sha256(early_return.slice(int(specification.resume_offset), int(specification.followup_offset)))
	_check(not caller_route.validate_restore_followup(early_return, early_return.size(), early_specification).get("ok", false), "caller restore rejects a refreshed prefix that returns before the restore dispatch")
	for leading in [PackedByteArray([0x12, 0x01]), PackedByteArray([0x01, 0x41])]:
		var shadow := _restore_fixture(dispatch, leading)
		_check(not caller_route.validate_restore_followup(shadow.bytecode, shadow.bytecode.size(), shadow.specification, [0]).get("ok", false), "caller restore rejects event-dispatch-shaped payload bytes in record %02X" % int(leading[0]))
	var opaque := _restore_fixture(dispatch, PackedByteArray([0x12, 0x03]))
	_check(not caller_route.validate_restore_followup(opaque.bytecode, opaque.bytecode.size(), opaque.specification).get("ok", false), "caller restore fails closed beyond an opaque unframed prefix")
	var offsets: Array = [2]
	_check(caller_route.validate_restore_followup(opaque.bytecode, opaque.bytecode.size(), opaque.specification, offsets).get("ok", false) and offsets == [2], "caller restore uses a separate container region without mutating the address table")
	var opaque_tail := bytecode.duplicate()
	opaque_tail.append_array(PackedByteArray([0x12, 0x03]))
	_check(caller_route.validate_restore_followup(opaque_tail, opaque_tail.size(), specification).get("ok", false), "caller restore tolerates an opaque tail after its indexed boundaries")
	for invalid_table in [[-1], [1.5], [NAN], [true], [bytecode.size()], [0, 0], [1, 0]]:
		_check(not caller_route.validate_restore_followup(bytecode, bytecode.size(), specification, invalid_table).get("ok", false), "caller restore rejects malformed container address table %s" % str(invalid_table))
	var native := _restore_fixture(dispatch, PackedByteArray(), PackedByteArray([0x12, 0x01, 0x41, 0x00, 0x00]))
	_check(not caller_route.validate_restore_followup(native.bytecode, native.bytecode.size(), native.specification).get("ok", false), "caller restore does not silently omit a native prefix record")
	_test_restore_payload_jumps(fixture)


func _test_restore_payload_jumps(fixture: Dictionary) -> void:
	var caller_route := CallerRouteScript.new()
	for payload in [PackedByteArray(), PackedByteArray([0x03, 0x1F, 0x01, 0xF1, 0x02, 0x00, 0xFF, 0x00])]:
		var original: PackedByteArray = fixture.bytecode
		var specification: Dictionary = fixture.specification.duplicate(true)
		var old_restore := int(specification.restore_dispatch_offset)
		var bytecode := original.slice(0, old_restore)
		var jump := PackedByteArray([0x0C, 0, 0, 0, 0])
		jump.encode_u32(1, old_restore + 7)
		bytecode.append_array(jump)
		bytecode.append_array(PackedByteArray([0x12, 0x02]))
		bytecode.append_array(payload)
		bytecode.append_array(original.slice(old_restore))
		for key in ["restore_dispatch_offset", "followup_offset", "handoff_offset"]:
			specification[key] += 7 + payload.size()
		specification.restore_prefix_sha256 = _sha256(bytecode.slice(int(specification.resume_offset), int(specification.followup_offset)))
		var state := SandboxStateScript.new(1)
		var execution := RunnerScript.new().run(bytecode, int(specification.resume_offset), state)
		var framing := DecoderScript.new().decode_region_structural_aligned(bytecode, 0, bytecode.size())
		var restore_is_aligned := false
		var payload_is_aligned := false
		for instruction in framing.get("instructions", []):
			restore_is_aligned = restore_is_aligned or int(instruction.source_offset) == int(specification.restore_dispatch_offset)
			payload_is_aligned = payload_is_aligned or int(instruction.source_offset) == old_restore + 7
		_check(
			execution.get("status", "") == "script_dispatch_boundary"
			and int(execution.get("offset", -1)) == int(specification.restore_dispatch_offset)
			and not payload_is_aligned
			and restore_is_aligned == not payload.is_empty()
			and state.read_value("global_u8", 287) == (0 if payload.is_empty() else 2),
			"restore payload-jump fixture reaches the expected dispatch after executing %s inside native payload" % ("a dispatch" if payload.is_empty() else "an intermediate state write")
		)
		_check(not caller_route.validate_restore_followup(bytecode, bytecode.size(), specification).get("ok", false), "caller restore rejects native payload execution despite refreshed prefix hash")
		if not payload.is_empty():
			bytecode.encode_u32(old_restore + 1, int(specification.restore_dispatch_offset))
			specification.restore_prefix_sha256 = _sha256(bytecode.slice(int(specification.resume_offset), int(specification.followup_offset)))
			_check(caller_route.validate_restore_followup(bytecode, bytecode.size(), specification).get("ok", false), "caller restore accepts an aligned jump over unexecuted native payload")


func _restore_fixture(dispatch: PackedByteArray, leading: PackedByteArray = PackedByteArray(), native_prefix: PackedByteArray = PackedByteArray()) -> Dictionary:
	var bytecode := leading.duplicate()
	bytecode.append_array(dispatch)
	var resume_offset := bytecode.size()
	bytecode.append_array(native_prefix)
	bytecode.append_array(PackedByteArray([0x03, 0x1E, 0x01, 0xF1, 0x01, 0x00, 0xFF, 0x00]))
	var restore_dispatch_offset := bytecode.size()
	bytecode.append_array(PackedByteArray([0x0F, 0x01]))
	bytecode.append_array("d_pic.mes".to_ascii_buffer())
	bytecode.append_array(PackedByteArray([0x00, 0x00]))
	var followup_offset := bytecode.size()
	# A standalone return makes the later aligned handoff unreachable. The
	# source proof must preserve its explicit lack of full-followup reachability.
	bytecode.append(0x00)
	var handoff_offset := bytecode.size()
	bytecode.append_array(PackedByteArray([0x0E, 0x01]))
	bytecode.append_array("machi.mes".to_ascii_buffer())
	bytecode.append_array(PackedByteArray([0x00, 0x00]))
	return {
		"bytecode": bytecode,
		"specification": {
			"event_id": "original/synthetic/restore", "restore_followup": true,
			"caller_entry": "CALLER.MES", "caller_entry_sha256": "a".repeat(64),
			"callee_entry": "EVENTD99.MES", "callee_entry_sha256": "b".repeat(64),
			"return_offset": 1, "dispatch_offset": leading.size(), "resume_offset": resume_offset,
			"restore_dispatch_offset": restore_dispatch_offset,
			"restore_entry": "D_PIC.MES", "restore_entry_sha256": "c".repeat(64),
			"followup_offset": followup_offset, "handoff_offset": handoff_offset,
			"handoff_target": "MACHI.MES",
			"restore_prefix_sha256": _sha256(bytecode.slice(resume_offset, followup_offset)),
		},
	}


func _sha256(data: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(data)
	return context.finish().hex_encode()
