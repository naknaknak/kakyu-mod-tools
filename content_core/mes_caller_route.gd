class_name KakyuMesCallerRoute
extends RefCounted

const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")
const MesEventRunnerScript := preload("res://content_core/mes_event_runner.gd")
const MesInstructionDecoderScript := preload("res://content_core/mes_instruction_decoder.gd")
const SandboxStateScript := preload("res://content_core/mes_sandbox_state.gd")
const ContractValues := preload("res://content_core/contract_values.gd")


func validate(bytecode: PackedByteArray, code_size: int, specification: Dictionary, address_table_offsets: Array = []) -> Dictionary:
	var shape := _validate_specification(bytecode, code_size, specification)
	if not shape.ok:
		return shape
	# The same structural boundary the direct, choice and restore routes use.
	# Decoding at the catalog coordinate alone cannot establish a command
	# boundary, because payload bytes can decode as a dispatch-shaped envelope.
	var dispatch_validation := _validate_aligned_dispatch(bytecode, code_size, specification, address_table_offsets)
	if not dispatch_validation.ok:
		return dispatch_validation
	var structural_regions: Dictionary = dispatch_validation.structural_regions
	if ContractValues.sha256_lenient(bytecode.slice(int(specification.resume_offset), int(specification.bgm_boundary))) != str(specification.bgm_sha256):
		return _error("Caller BGM prefix bytes changed.")
	if ContractValues.sha256_lenient(bytecode.slice(int(specification.bgm_boundary), int(specification.handoff_end))) != str(specification.handoff_sha256):
		return _error("Caller handoff suffix bytes changed.")

	var routes: Array[Dictionary] = []
	for untyped_route in specification.bgm_routes:
		if not untyped_route is Dictionary:
			return _error("Caller BGM route is not a dictionary.")
		var route: Dictionary = untyped_route
		var state := SandboxStateScript.new(1)
		state.write_value("state_u16", int(specification.date_index), int(route.get("date", 0)))
		var execution := run_bgm_prefix(bytecode, state, specification, address_table_offsets)
		if not execution.ok:
			return _error("Caller BGM route changed for date %d: %s" % [int(route.get("date", 0)), str(execution.error)])
		if int(execution.route.selector) != int(route.get("selector", -1)) or str(execution.route.resource) != str(route.get("resource", "")).to_upper():
			return _error("Caller BGM route catalog changed for date %d." % int(route.get("date", 0)))
		var bgm_trace := _validate_structural_trace(
			bytecode, code_size, address_table_offsets,
			execution.result.get("trace", []), structural_regions
		)
		if not bgm_trace.ok:
			return bgm_trace
		routes.append(route.duplicate(true))

	var handoff_state := SandboxStateScript.new(1)
	var handoff_execution := run_handoff(bytecode, handoff_state, specification, address_table_offsets)
	if not handoff_execution.ok:
		return _error("Caller handoff route changed: %s" % str(handoff_execution.error))
	if not _state_diff_matches(handoff_execution.result.get("state_diff", []), specification.state_writes):
		return _error("Caller handoff state diff changed.")
	var handoff_trace := _validate_structural_trace(
		bytecode, code_size, address_table_offsets,
		handoff_execution.result.get("trace", []), structural_regions
	)
	if not handoff_trace.ok:
		return handoff_trace

	return {
		"ok": true,
		"schema": ContentCoreVersionScript.MES_CALLER_ROUTE_SCHEMA,
		"callee_entry": str(specification.callee_entry).to_upper(),
		"dispatch_offset": int(specification.dispatch_offset),
		"resume_offset": int(specification.resume_offset),
		"start_offset": int(specification.resume_offset),
		"boundary_offset": int(specification.bgm_boundary),
		"handoff_offset": int(specification.handoff_offset),
		"handoff_end": int(specification.handoff_end),
		"target_entry": str(specification.handoff_target).to_upper(),
		"routes": routes,
		"state_writes": (specification.state_writes as Array).duplicate(true),
	}


func validate_direct(bytecode: PackedByteArray, code_size: int, specification: Dictionary, address_table_offsets: Array = []) -> Dictionary:
	var shape := _validate_direct_specification(code_size, specification)
	if not shape.ok:
		return shape
	var dispatch_validation := _validate_aligned_dispatch(bytecode, code_size, specification, address_table_offsets)
	if not dispatch_validation.ok:
		return dispatch_validation
	if ContractValues.sha256_lenient(bytecode.slice(int(specification.resume_offset), int(specification.handoff_end))) != str(specification.handoff_sha256):
		return _error("Direct caller handoff suffix bytes changed.")
	var decoder := MesInstructionDecoderScript.new()
	var handoff := decoder.decode_at(bytecode, int(specification.handoff_offset))
	if (
		not handoff.get("ok", false)
		or str(handoff.get("op", "")) != "script_handoff_marker"
		or int(handoff.get("command_id", -1)) != 0x0E
		or str(handoff.get("script_target", "")).to_upper() != str(specification.handoff_target).to_upper()
		or int(handoff.get("end_offset", -1)) != int(specification.handoff_end)
	):
		return _error("Direct caller handoff target or physical end changed.")
	var state := SandboxStateScript.new(1)
	var before := state.snapshot()
	var result := MesEventRunnerScript.new().run(
		bytecode, int(specification.resume_offset), state, code_size,
		MesEventRunnerScript.DEFAULT_MAX_STEPS,
		{"address_table_offsets": address_table_offsets.duplicate()}
	)
	if not direct_result_matches(result, before, specification, state):
		return _error("Direct caller did not reach its exact handoff trace and state.")
	return {
		"ok": true,
		"schema": ContentCoreVersionScript.MES_DIRECT_CALLER_ROUTE_SCHEMA,
		"caller_entry": str(specification.caller_entry).to_upper(),
		"start_offset": int(specification.resume_offset),
		"handoff_offset": int(specification.handoff_offset),
		"handoff_end": int(specification.handoff_end),
		"target_entry": str(specification.handoff_target).to_upper(),
		"state_writes": (specification.state_writes as Array).duplicate(true),
	}


func validate_choice_projection(bytecode: PackedByteArray, code_size: int, specification: Dictionary, address_table_offsets: Array = []) -> Dictionary:
	var shape := _validate_choice_specification(code_size, specification)
	if not shape.ok:
		return shape
	var dispatch_validation := _validate_aligned_dispatch(bytecode, code_size, specification, address_table_offsets)
	if not dispatch_validation.ok:
		return dispatch_validation
	if ContractValues.sha256_lenient(bytecode.slice(int(specification.resume_offset), int(specification.caller_choice_boundary))) != str(specification.caller_suffix_sha256):
		return _error("Caller choice suffix bytes changed.")
	# The probe validates the stored suffix from a fresh default state. It does
	# not consume catalog presets, execute the callee or supply native choice input.
	var probe := MesEventRunnerScript.new().run(
		bytecode, int(specification.resume_offset), SandboxStateScript.new(1), code_size,
		MesEventRunnerScript.DEFAULT_MAX_STEPS,
		{"address_table_offsets": address_table_offsets.duplicate()}
	)
	var trace: Array = probe.get("trace", [])
	var trace_validation := _validate_structural_trace(
		bytecode, code_size, address_table_offsets, trace, dispatch_validation.structural_regions
	)
	if not trace_validation.ok:
		return trace_validation
	var bgm_rows: Array[Dictionary] = []
	for record in trace:
		if (
			int(record.get("source_offset", -1)) == int(specification.caller_bgm_offset)
			and str(record.get("effect", "")) == "bgm_request"
			and int(record.get("routine_id", -1)) == 23
		):
			bgm_rows.append(record)
	var definition_offsets: Array[int] = []
	for definition in probe.get("definitions", []):
		definition_offsets.append(int(definition.get("source_offset", -1)))
	var expected_definition_offsets: Array[int] = []
	for offset in specification.caller_definition_offsets:
		expected_definition_offsets.append(int(offset))
	if (
		not probe.get("ok", false)
		or str(probe.get("status", "")) != "def_selection_boundary"
		or int(probe.get("offset", -1)) != int(specification.caller_choice_boundary)
		or trace.is_empty()
		or int(trace[-1].get("routine_id", -1)) != 40
		or bgm_rows.size() != 1
		or str(bgm_rows[0].get("resource_name", "")).to_upper() not in specification.caller_bgm_resources
		or definition_offsets != expected_definition_offsets
	):
		return _error("Caller choice suffix did not reach its exact BGM, definitions and routine-40 boundary.")
	return {
		"ok": true,
		"schema": ContentCoreVersionScript.MES_CALLER_CHOICE_PROJECTION_SCHEMA,
		"caller_entry": str(specification.caller_entry).to_upper(),
		"start_offset": int(specification.resume_offset),
		"bgm_offset": int(specification.caller_bgm_offset),
		"bgm_resource": str(bgm_rows[0].get("resource_name", "")).to_upper(),
		"definition_offsets": definition_offsets,
		"choice_boundary": int(specification.caller_choice_boundary),
		"choice_routine": 40,
		"trace_boundary_policy": "structural_indexed_instruction",
		"verified_trace_records": trace.size(),
		"execution_policy": "explicit_remake_one_based_result_native_effects_omitted",
		"selected_state_policy": "fresh_isolated_default",
		"stored_suffix_only": true,
		"callee_reachability_verified": false,
		"native_choice_executed": false,
	}


func validate_restore_followup(bytecode: PackedByteArray, code_size: int, specification: Dictionary, address_table_offsets: Array = []) -> Dictionary:
	var shape := _validate_restore_specification(code_size, specification)
	if not shape.ok:
		return shape
	var dispatch_validation := _validate_aligned_dispatch(bytecode, code_size, specification, address_table_offsets)
	if not dispatch_validation.ok:
		return dispatch_validation
	var structural_regions: Dictionary = dispatch_validation.structural_regions
	var restore_validation := _validate_aligned_dispatch(bytecode, code_size, {
		"dispatch_offset": specification.restore_dispatch_offset,
		"resume_offset": specification.followup_offset,
		"callee_entry": specification.restore_entry,
	}, address_table_offsets, structural_regions)
	if not restore_validation.ok:
		return _error("Caller restore dispatch changed: %s" % str(restore_validation.error))
	if ContractValues.sha256_lenient(bytecode.slice(int(specification.resume_offset), int(specification.followup_offset))) != str(specification.restore_prefix_sha256):
		return _error("Caller restore prefix bytes changed.")
	if _structural_instruction_at(bytecode, code_size, address_table_offsets, int(specification.followup_offset), structural_regions).is_empty():
		return _error("Caller restore followup is not an aligned instruction in its container region.")
	var handoff := _structural_instruction_at(bytecode, code_size, address_table_offsets, int(specification.handoff_offset), structural_regions)
	if (
		handoff.is_empty()
		or not handoff.get("ok", false)
		or str(handoff.get("op", "")) != "script_handoff_marker"
		or int(handoff.get("command_id", -1)) != 0x0E
		or str(handoff.get("script_target", "")).to_upper() != str(specification.handoff_target).to_upper()
	):
		return _error("Caller restore handoff is not an aligned command-0E record with its declared target.")
	# A fresh caller state proves only the prefix up to the restore dispatch.
	# The restore entry body and the subsequent followup are never executed here.
	var probe := MesEventRunnerScript.new().run(
		bytecode, int(specification.resume_offset), SandboxStateScript.new(1), code_size,
		MesEventRunnerScript.DEFAULT_MAX_STEPS,
		{"address_table_offsets": address_table_offsets.duplicate()}
	)
	var trace: Array = probe.get("trace", [])
	var trace_validation := _validate_structural_trace(bytecode, code_size, address_table_offsets, trace, structural_regions)
	if not trace_validation.ok:
		return trace_validation
	if (
		str(probe.get("status", "")) != "script_dispatch_boundary"
		or int(probe.get("offset", -1)) != int(specification.restore_dispatch_offset)
		or int(probe.get("resume_offset", -1)) != int(specification.followup_offset)
		or trace.is_empty()
		or str(trace[-1].get("target_entry", "")).to_upper() != str(specification.restore_entry).to_upper()
	):
		return _error("Caller restore prefix did not stop at its exact restore dispatch and physical followup.")
	return {
		"ok": true,
		"schema": ContentCoreVersionScript.MES_CALLER_RESTORE_FOLLOWUP_SCHEMA,
		"caller_entry": str(specification.caller_entry).to_upper(),
		"dispatch_offset": int(specification.dispatch_offset),
		"resume_offset": int(specification.resume_offset),
		"start_offset": int(specification.resume_offset),
		"restore_dispatch_offset": int(specification.restore_dispatch_offset),
		"restore_entry": str(specification.restore_entry).to_upper(),
		"followup_offset": int(specification.followup_offset),
		"handoff_offset": int(specification.handoff_offset),
		"handoff_end": int(handoff.end_offset),
		"target_entry": str(specification.handoff_target).to_upper(),
		"trace_boundary_policy": "structural_indexed_instruction",
		"verified_trace_records": trace.size(),
		"selected_state_policy": "fresh_isolated_default",
		"stored_prefix_only": true,
		"restored_body_executed": false,
		"callee_reachability_verified": false,
		"full_followup_reachability_verified": false,
		"outer_host_executed": false,
	}


func _runner_context(address_table_offsets: Array) -> Dictionary:
	# An absent table keeps the runner's existing default, so a caller that does
	# not supply one behaves exactly as it did before the boundary guard landed.
	if address_table_offsets.is_empty():
		return {}
	return {"address_table_offsets": address_table_offsets.duplicate()}


func _validate_aligned_dispatch(bytecode: PackedByteArray, code_size: int, specification: Dictionary, address_table_offsets: Array, structural_regions: Dictionary = {}) -> Dictionary:
	if code_size != bytecode.size():
		return _error("Caller code size does not match its bytecode.")
	var previous_offset := -1
	for offset in address_table_offsets:
		if not _is_bounded_integer(offset, code_size - 1) or int(offset) <= previous_offset:
			return _error("Caller address-table offsets must be strictly increasing integers inside the bytecode.")
		previous_offset = int(offset)
	# Use the analysis index's framing over the actual container region. Starting
	# at the catalog coordinate would also decode dispatch-shaped payload bytes.
	var dispatch := _structural_instruction_at(bytecode, code_size, address_table_offsets, int(specification.dispatch_offset), structural_regions)
	# A later opaque tail does not invalidate an already indexed instruction.
	if dispatch.is_empty():
		return _error("Caller dispatch is not an aligned instruction in its container region.")
	if (
		not dispatch.get("ok", false)
		or str(dispatch.get("op", "")) != "script_dispatch"
		or int(dispatch.get("command_id", -1)) != 0x0F
		or str(dispatch.get("script_target", "")).to_upper() != str(specification.callee_entry).to_upper()
		or int(dispatch.get("end_offset", -1)) != int(specification.resume_offset)
	):
		return _error("Caller dispatch target or physical resume changed.")
	if bytecode.slice(int(specification.dispatch_offset), int(specification.resume_offset)) != _dispatch_envelope(str(specification.callee_entry)):
		return _error("Caller dispatch envelope bytes changed.")
	return {"ok": true, "structural_regions": structural_regions}


func _validate_structural_trace(bytecode: PackedByteArray, code_size: int, address_table_offsets: Array, trace: Array, structural_regions: Dictionary) -> Dictionary:
	# Runtime jumps can enter bytes that decode in isolation but belong to a
	# native/text payload. Every executed record must retain its container owner,
	# including intermediate writes before the requested BGM/DEF/choice boundary.
	for record in trace:
		var offset := int(record.get("source_offset", -1))
		var instruction := _structural_instruction_at(bytecode, code_size, address_table_offsets, offset, structural_regions)
		if (
			instruction.is_empty()
			or int(record.get("end_offset", -1)) != int(instruction.get("end_offset", -1))
			or int(record.get("command_id", -1)) != int(instruction.get("command_id", -1))
		):
			return _error("Caller trace at 0x%X does not preserve its structural record boundary." % offset)
	return {"ok": true}


func _structural_instruction_at(bytecode: PackedByteArray, code_size: int, address_table_offsets: Array, offset: int, structural_regions: Dictionary) -> Dictionary:
	if offset < 0 or offset >= code_size:
		return {}
	var region_start := 0
	var region_end := code_size
	for entry_offset in address_table_offsets:
		if int(entry_offset) <= offset:
			region_start = int(entry_offset)
		else:
			region_end = int(entry_offset)
			break
	if not structural_regions.has(region_start):
		var framing := MesInstructionDecoderScript.new().decode_region_structural_aligned(bytecode, region_start, region_end)
		var instructions := {}
		for instruction in framing.get("instructions", []):
			instructions[int(instruction.source_offset)] = instruction
		structural_regions[region_start] = instructions
	return structural_regions[region_start].get(offset, {})


func direct_result_matches(result: Dictionary, before: Dictionary, specification: Dictionary, state: KakyuMesSandboxState) -> bool:
	if state == null or not _validate_direct_expectations(specification).ok:
		return false
	if not result.get("trace", null) is Array or not _is_bounded_integer(result.get("offset", null), 0x7FFFFFFF):
		return false
	var trace: Array = result.trace
	if (
		str(result.get("status", "")) != "script_handoff_boundary"
		or int(result.offset) != int(specification.handoff_offset)
		or trace.is_empty()
		or not _trace_commands_match(trace, specification.handoff_trace_commands)
		or str(trace[-1].get("target_entry", "")).to_upper() != str(specification.handoff_target).to_upper()
		or not _state_values_match(state, specification.state_writes)
	):
		return false
	# Compare the live snapshot, including pre-existing nonzero values. A reported
	# diff or an equal count alone cannot prove that only the declared keys changed.
	return _state_diff_matches(state.diff(before), specification.state_writes, false)


func run_bgm_prefix(
	bytecode: PackedByteArray, state: KakyuMesSandboxState, specification: Dictionary,
	address_table_offsets: Array = []
) -> Dictionary:
	var shape := _validate_specification(bytecode, bytecode.size(), specification)
	if not shape.ok:
		return shape
	var route := route_for_date(int(state.read_value("state_u16", int(specification.get("date_index", -1)))), specification)
	if route.is_empty():
		return _error("No caller BGM route matches the sandbox date.")
	var result := MesEventRunnerScript.new().run(
		bytecode,
		int(specification.resume_offset),
		state,
		int(specification.bgm_boundary),
		MesEventRunnerScript.DEFAULT_MAX_STEPS,
		_runner_context(address_table_offsets)
	)
	var request := _single_bgm_request(result)
	if (
		str(result.get("status", "")) != "completed"
		or int(result.get("offset", -1)) != int(specification.bgm_boundary)
		or not _diff_is_own_argument_storage(result)
		or request.is_empty()
		or int(request.get("bgm_selector", -1)) != int(route.selector)
		or str(request.get("resource_name", "")).to_upper() != str(route.resource)
	):
		return _error("BGM prefix did not reach its exact request boundary.")
	return {"ok": true, "result": result, "route": route}


func run_handoff(
	bytecode: PackedByteArray, state: KakyuMesSandboxState, specification: Dictionary,
	address_table_offsets: Array = []
) -> Dictionary:
	var shape := _validate_specification(bytecode, bytecode.size(), specification)
	if not shape.ok:
		return shape
	var result := MesEventRunnerScript.new().run(
		bytecode,
		int(specification.bgm_boundary),
		state,
		int(specification.get("code_size", bytecode.size())),
		MesEventRunnerScript.DEFAULT_MAX_STEPS,
		_runner_context(address_table_offsets)
	)
	var trace: Array = result.get("trace", [])
	if (
		str(result.get("status", "")) != "script_handoff_boundary"
		or int(result.get("offset", -1)) != int(specification.handoff_offset)
		or trace.is_empty()
		or str(trace[-1].get("target_entry", "")).to_upper() != str(specification.handoff_target).to_upper()
		or not _trace_commands_match(trace, specification.get("handoff_trace_commands", []))
		or not _state_values_match(state, specification.get("state_writes", []))
	):
		return _error("Handoff suffix did not reach its exact target and state.")
	return {"ok": true, "result": result}


func route_for_date(date_value: int, specification: Dictionary) -> Dictionary:
	var default_route: Dictionary = {}
	for untyped_route in specification.get("bgm_routes", []):
		if not untyped_route is Dictionary:
			continue
		var route: Dictionary = untyped_route
		if bool(route.get("default", false)):
			default_route = route
		elif int(route.get("date", -1)) == date_value:
			return {
				"date": date_value,
				"selector": int(route.get("selector", -1)),
				"resource": str(route.get("resource", "")).to_upper(),
			}
	if default_route.is_empty():
		return {}
	return {
		"date": date_value,
		"selector": int(default_route.get("selector", -1)),
		"resource": str(default_route.get("resource", "")).to_upper(),
	}


func _validate_specification(bytecode: PackedByteArray, code_size: int, specification: Dictionary) -> Dictionary:
	for key in [
		"callee_entry", "dispatch_offset", "resume_offset", "bgm_boundary", "bgm_sha256",
		"date_index", "bgm_routes", "handoff_offset", "handoff_end", "handoff_sha256",
		"handoff_target", "state_writes",
	]:
		if not specification.has(key):
			return _error("Caller route specification is missing %s." % key)
	var dispatch_offset := int(specification.dispatch_offset)
	var resume_offset := int(specification.resume_offset)
	var bgm_boundary := int(specification.bgm_boundary)
	var handoff_offset := int(specification.handoff_offset)
	var handoff_end := int(specification.handoff_end)
	if (
		code_size != bytecode.size()
		or dispatch_offset < 0
		or dispatch_offset >= resume_offset
		or resume_offset >= bgm_boundary
		or bgm_boundary >= handoff_offset
		or handoff_offset >= handoff_end
		or handoff_end > code_size
		or int(specification.date_index) < 0
		or not specification.bgm_routes is Array
		or specification.bgm_routes.is_empty()
		or not specification.state_writes is Array
		or specification.state_writes.is_empty()
	):
		return _error("Caller route specification has invalid bounds or collections.")
	if not _is_safe_mes_entry(str(specification.callee_entry)) or not _is_safe_mes_entry(str(specification.handoff_target)):
		return _error("Caller route filenames must be safe ASCII MES basenames.")
	var default_count := 0
	var exact_dates := {}
	for route in specification.bgm_routes:
		if not route is Dictionary or int(route.get("selector", -1)) < 0 or str(route.get("resource", "")).is_empty():
			return _error("Caller BGM route record is invalid.")
		if bool(route.get("default", false)):
			default_count += 1
		else:
			var date := int(route.get("date", -1))
			if date < 0 or exact_dates.has(date):
				return _error("Caller BGM exact dates must be nonnegative and unique.")
			exact_dates[date] = true
	if default_count != 1:
		return _error("Caller BGM routes require exactly one default route.")
	var state_keys := {}
	for untyped_write in specification.state_writes:
		if not untyped_write is Dictionary:
			return _error("Caller handoff state write is not a dictionary.")
		var write: Dictionary = untyped_write
		var storage := str(write.get("storage", ""))
		var key := _state_key(write)
		if (
			not SandboxStateScript.STORAGE_MASKS.has(storage)
			or int(write.get("index", -1)) < 0
			or int(write.get("bank", 0)) < 0
			or state_keys.has(key)
		):
			return _error("Caller handoff state writes must be valid and unique.")
		state_keys[key] = true
	return {"ok": true}


func _validate_choice_specification(code_size: int, specification: Dictionary) -> Dictionary:
	for key in [
		"caller_choice_projection", "caller_entry", "callee_entry", "dispatch_offset", "resume_offset",
		"callee_return_offsets", "caller_choice_boundary", "caller_suffix_sha256", "caller_bgm_offset",
		"caller_definition_offsets", "caller_bgm_resources",
	]:
		if not specification.has(key):
			return _error("Caller choice specification is missing %s." % key)
	if not specification.caller_choice_projection is bool or not specification.caller_choice_projection:
		return _error("Caller choice specification must declare a choice projection.")
	for key in ["caller_entry", "callee_entry"]:
		if not _is_safe_direct_mes_entry(specification[key]):
			return _error("Caller choice filenames must be safe ASCII MES basenames.")
	for key in ["dispatch_offset", "resume_offset", "caller_bgm_offset", "caller_choice_boundary"]:
		if not _is_bounded_integer(specification[key], code_size - 1):
			return _error("Caller choice coordinates must be bounded integers.")
	if (
		int(specification.dispatch_offset) >= int(specification.resume_offset)
		or int(specification.resume_offset) > int(specification.caller_bgm_offset)
		or int(specification.caller_bgm_offset) >= int(specification.caller_choice_boundary)
	):
		return _error("Caller choice specification has invalid bounds.")
	var fingerprint: Variant = specification.caller_suffix_sha256
	if not fingerprint is String or fingerprint.length() != 64 or fingerprint != fingerprint.to_lower() or not fingerprint.is_valid_hex_number(false):
		return _error("Caller choice suffix fingerprint must be a lowercase SHA-256.")
	for key in ["callee_return_offsets", "caller_definition_offsets"]:
		if not specification[key] is Array or specification[key].is_empty():
			return _error("Caller choice %s must be a nonempty array." % key)
		var previous_offset := -1
		for offset in specification[key]:
			if not _is_bounded_integer(offset, 0x7FFFFFFF) or int(offset) <= previous_offset:
				return _error("Caller choice %s must contain strictly increasing integer offsets." % key)
			if key == "caller_definition_offsets" and (int(offset) < int(specification.resume_offset) or int(offset) >= int(specification.caller_choice_boundary)):
				return _error("Caller definitions must be inside the stored choice suffix.")
			previous_offset = int(offset)
	if not specification.caller_bgm_resources is Array or specification.caller_bgm_resources.is_empty():
		return _error("Caller choice requires nonempty allowed BGM resources.")
	var resources := {}
	for resource in specification.caller_bgm_resources:
		if not resource is String or resource.is_empty() or resource != resource.to_upper() or resource.get_extension() != "WAV" or resource.get_file() != resource or resource.contains("..") or resources.has(resource):
			return _error("Caller choice BGM resources must be unique uppercase WAV basenames.")
		for character in resource:
			if character.unicode_at(0) < 0x21 or character.unicode_at(0) > 0x7E or character in '<>:"/\\|?*':
				return _error("Caller choice BGM resources must be safe ASCII basenames.")
		resources[resource] = true
	return {"ok": true}


func _validate_restore_specification(code_size: int, specification: Dictionary) -> Dictionary:
	for key in [
		"event_id", "restore_followup", "caller_entry", "caller_entry_sha256",
		"callee_entry", "callee_entry_sha256", "return_offset", "dispatch_offset", "resume_offset",
		"restore_dispatch_offset", "restore_entry", "restore_entry_sha256", "followup_offset",
		"handoff_offset", "handoff_target", "restore_prefix_sha256",
	]:
		if not specification.has(key):
			return _error("Caller restore specification is missing %s." % key)
	if not specification.restore_followup is bool or not specification.restore_followup:
		return _error("Caller restore specification must declare a restore followup.")
	if not specification.event_id is String or specification.event_id.strip_edges().is_empty():
		return _error("Caller restore event identifier must be a nonempty string.")
	for key in ["caller_entry", "callee_entry", "restore_entry", "handoff_target"]:
		if not _is_safe_direct_mes_entry(specification[key]):
			return _error("Caller restore filenames must be safe ASCII MES basenames.")
	for key in ["caller_entry_sha256", "callee_entry_sha256", "restore_entry_sha256", "restore_prefix_sha256"]:
		var fingerprint: Variant = specification[key]
		if not fingerprint is String or fingerprint.length() != 64 or fingerprint != fingerprint.to_lower() or not fingerprint.is_valid_hex_number(false):
			return _error("Caller restore fingerprints must be lowercase SHA-256 strings.")
	for key in ["dispatch_offset", "resume_offset", "restore_dispatch_offset", "followup_offset", "handoff_offset"]:
		if not _is_bounded_integer(specification[key], code_size - 1):
			return _error("Caller restore coordinates must be bounded integers.")
	if not _is_bounded_integer(specification.return_offset, 0x7FFFFFFF):
		return _error("Caller restore callee return coordinate must be a bounded integer.")
	if (
		int(specification.dispatch_offset) >= int(specification.resume_offset)
		or int(specification.resume_offset) > int(specification.restore_dispatch_offset)
		or int(specification.restore_dispatch_offset) >= int(specification.followup_offset)
		or int(specification.followup_offset) > int(specification.handoff_offset)
	):
		return _error("Caller restore specification has invalid bounds.")
	return {"ok": true}


func _validate_direct_specification(code_size: int, specification: Dictionary) -> Dictionary:
	for key in ["direct_handoff", "caller_entry", "callee_entry", "dispatch_offset", "resume_offset", "handoff_end", "handoff_sha256"]:
		if not specification.has(key):
			return _error("Direct caller specification is missing %s." % key)
	if not specification.direct_handoff is bool or not specification.direct_handoff:
		return _error("Direct caller specification must declare a direct handoff.")
	for key in ["caller_entry", "callee_entry"]:
		if not _is_safe_direct_mes_entry(specification[key]):
			return _error("Direct caller filenames must be safe ASCII MES basenames.")
	var expectations := _validate_direct_expectations(specification)
	if not expectations.ok:
		return expectations
	for key in ["dispatch_offset", "resume_offset", "handoff_offset", "handoff_end"]:
		if not _is_bounded_integer(specification[key], code_size):
			return _error("Direct caller coordinates must be bounded integers.")
	if (
		int(specification.dispatch_offset) >= int(specification.resume_offset)
		or int(specification.resume_offset) >= int(specification.handoff_offset)
		or int(specification.handoff_offset) >= int(specification.handoff_end)
	):
		return _error("Direct caller specification has invalid bounds.")
	var fingerprint: Variant = specification.handoff_sha256
	if not fingerprint is String or fingerprint.length() != 64 or fingerprint != fingerprint.to_lower() or not fingerprint.is_valid_hex_number(false):
		return _error("Direct caller suffix fingerprint must be a lowercase SHA-256.")
	return {"ok": true}


func _validate_direct_expectations(specification: Dictionary) -> Dictionary:
	for key in ["handoff_offset", "handoff_target", "handoff_trace_commands", "state_writes"]:
		if not specification.has(key):
			return _error("Direct caller specification is missing %s." % key)
	if not _is_bounded_integer(specification.handoff_offset, 0x7FFFFFFF) or not _is_safe_direct_mes_entry(specification.handoff_target):
		return _error("Direct caller handoff coordinate or target is invalid.")
	if not specification.handoff_trace_commands is Array or specification.handoff_trace_commands.is_empty():
		return _error("Direct caller requires a nonempty exact command trace.")
	for command in specification.handoff_trace_commands:
		if not _is_bounded_integer(command, 0xFF):
			return _error("Direct caller trace commands must be bytes.")
	if int(specification.handoff_trace_commands[-1]) != 0x0E:
		return _error("Direct caller trace must end at command 0E.")
	if not specification.state_writes is Array or specification.state_writes.is_empty():
		return _error("Direct caller requires nonempty state writes.")
	var keys := {}
	for write in specification.state_writes:
		if not write is Dictionary:
			return _error("Direct caller state write must be a dictionary.")
		var storage: Variant = write.get("storage", null)
		if not storage is String or not SandboxStateScript.STORAGE_MASKS.has(storage):
			return _error("Direct caller state storage is invalid.")
		if (
			not _is_bounded_integer(write.get("index", null), 0x7FFFFFFF)
			or not _is_bounded_integer(write.get("bank", 0), 0x7FFFFFFF)
			or not _is_bounded_integer(write.get("value", null), int(SandboxStateScript.STORAGE_MASKS[storage]))
		):
			return _error("Direct caller state coordinates and values must be bounded integers.")
		var key := _state_key(write)
		if keys.has(key):
			return _error("Direct caller state targets must be distinct.")
		keys[key] = true
	return {"ok": true}


func _is_bounded_integer(value: Variant, maximum: int) -> bool:
	if value is int:
		return value >= 0 and value <= maximum
	return value is float and is_finite(value) and value >= 0.0 and value <= maximum and value == floor(value)


func _is_safe_direct_mes_entry(value: Variant) -> bool:
	if not value is String or not _is_safe_mes_entry(value):
		return false
	for character in value:
		if character.unicode_at(0) < 0x21 or character.unicode_at(0) > 0x7E or character in '<>:"/\\|?*':
			return false
	return true


func _dispatch_envelope(callee_entry: String) -> PackedByteArray:
	var result := PackedByteArray([0x0F, 0x01])
	result.append_array(callee_entry.to_lower().to_ascii_buffer())
	result.append_array(PackedByteArray([0x00, 0x00]))
	return result


func _is_safe_mes_entry(entry_name: String) -> bool:
	return (
		not entry_name.is_empty()
		and entry_name.get_file() == entry_name
		and not entry_name.contains("..")
		and entry_name.get_extension().to_lower() == "mes"
		and entry_name.to_ascii_buffer().get_string_from_ascii() == entry_name
	)


# Core 0.377.0 (TD-56): command 0x09 writes the one original storage token 0xF6
# reads (`global_i32`), so the BGM prefix's own argument assignment is a
# sandbox write. It is the only write the prefix may make: every changed cell
# must be a bank-0 `global_i32` cell some command-0x09 row of this run wrote,
# holding the value that row wrote. Any other storage, a `global_i32` cell no
# 0x09 row named (a command-0x0A write carries no `argument_values`), or a
# different value refuses.
func _diff_is_own_argument_storage(result: Dictionary) -> bool:
	var written := {}
	for untyped_record in result.get("trace", []):
		if not untyped_record is Dictionary:
			continue
		var record: Dictionary = untyped_record
		if int(record.get("command_id", -1)) != 0x09 or str(record.get("write_storage", "")) != "global_i32":
			continue
		var values = record.get("argument_values", null)
		if not values is Array or int(record.get("write_count", -1)) != (values as Array).size():
			return false
		for value_index in range((values as Array).size()):
			written[int(record.get("write_start", -1)) + value_index] = int(values[value_index]) & 0xFFFFFFFF
	for untyped_change in result.get("state_diff", []):
		var change: Dictionary = untyped_change
		var index := int(change.get("index", -1))
		if (
			str(change.get("storage", "")) != "global_i32"
			or int(change.get("bank", -1)) != 0
			or not written.has(index)
			or int(change.get("after", -1)) != int(written[index])
		):
			return false
	return true


func _single_bgm_request(result: Dictionary) -> Dictionary:
	var requests: Array[Dictionary] = []
	for untyped_record in result.get("trace", []):
		if untyped_record is Dictionary and str(untyped_record.get("effect", "")) == "bgm_request":
			requests.append(untyped_record)
	return requests[0] if requests.size() == 1 else {}


func _trace_commands_match(trace: Array, expected_commands: Array) -> bool:
	if expected_commands.is_empty():
		return true
	if trace.size() != expected_commands.size():
		return false
	for index in range(expected_commands.size()):
		if not trace[index] is Dictionary or not _is_bounded_integer(trace[index].get("command_id", null), 0xFF) or int(trace[index].command_id) != int(expected_commands[index]):
			return false
	return true


func _state_values_match(state: KakyuMesSandboxState, expected_writes: Array) -> bool:
	for untyped_write in expected_writes:
		if not untyped_write is Dictionary:
			return false
		var write: Dictionary = untyped_write
		if state.read_value(str(write.get("storage", "")), int(write.get("index", -1)), int(write.get("bank", 0))) != int(write.get("value", 0)):
			return false
	return true


func _state_diff_matches(untyped_diff: Array, expected_writes: Array, require_zero_before: bool = true) -> bool:
	if untyped_diff.size() != expected_writes.size():
		return false
	var expected_by_key := {}
	for untyped_write in expected_writes:
		if not untyped_write is Dictionary:
			return false
		var write: Dictionary = untyped_write
		if expected_by_key.has(_state_key(write)):
			return false
		expected_by_key[_state_key(write)] = int(write.get("value", 0))
	for untyped_record in untyped_diff:
		if not untyped_record is Dictionary:
			return false
		var record: Dictionary = untyped_record
		var key := _state_key(record)
		if not expected_by_key.has(key) or (require_zero_before and int(record.get("before", -1)) != 0) or int(record.get("after", -1)) != int(expected_by_key[key]):
			return false
		expected_by_key.erase(key)
	return expected_by_key.is_empty()


func _state_key(record: Dictionary) -> String:
	return "%s:%d:%d" % [str(record.get("storage", "")), int(record.get("bank", 0)), int(record.get("index", -1))]


func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message}
