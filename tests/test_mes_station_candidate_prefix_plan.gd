extends Node

const PlanScript := preload("res://content_core/mes_station_candidate_prefix_plan.gd")
const Version := preload("res://content_core/content_core_version.gd")

const PREFIX_OFFSET := 0x0008
const PREFIX_END := 0x026D
const ENTRY_ZERO_END := 0x03AF
const RECORD_COUNT := 103

const EXTERNAL_ROWS := [
	["registered_definition", 0x0143, 0x0148, "always", "selector", 11],
	["shared_routine", 0x0152, 0x0157, "always", "routine_id", 32],
	["ax_presentation_control", 0x015C, 0x0163, "always", "execution_selector", 7],
	["shared_routine", 0x019C, 0x01A1, "always", "routine_id", 25],
	["native_record_dispatch", 0x01A1, 0x01A9, "always", "record_values", [6, 2]],
	["native_record_dispatch", 0x01A9, 0x01B1, "always", "record_values", [6, 6]],
	["native_record_dispatch", 0x01B1, 0x01B9, "always", "record_values", [6, 10]],
	["ax_presentation_control", 0x01C3, 0x01CA, "always", "execution_selector", 6],
	["ax_presentation_control", 0x01CA, 0x01D1, "always", "execution_selector", 8],
	["shared_routine", 0x01DE, 0x01E3, "always", "routine_id", 27],
	["shared_routine", 0x01EA, 0x01EF, "always", "routine_id", 25],
	["surface_operation", 0x01FA, 0x021F, "global_u8[2847] == 1", "presentation_subcommand", 11],
	["shared_routine", 0x0224, 0x0229, "global_u8[2847] != 1", "routine_id", 21],
]

var _checks := 0
var _failed := false


func _ready() -> void:
	var planner := PlanScript.new()
	var partition := _fixture_partition()
	_test_partition_contract(planner, partition)
	_test_local_cfg(planner, partition)
	_test_symbolic_effects(planner, partition)
	_test_external_boundaries(planner, partition)
	_test_execution_boundary(planner, partition)
	_test_validation_and_tamper(planner, partition)
	_test_partition_rejections(planner, partition)
	_test_public_source_boundary(planner)
	print("Station candidate prefix plan synthetic checks: ", _checks)
	await get_tree().process_frame
	get_tree().quit(1 if _failed else 0)


func _test_partition_contract(planner: RefCounted, partition: Array[Dictionary]) -> void:
	var before := partition.duplicate(true)
	var plan: Dictionary = planner.call("_build_from_partition_for_test", partition)
	_check(plan.get("ok", false), "exact 103-record fixture builds")
	if not plan.get("ok", false):
		return
	_check(plan.keys() == ["ok", "schema", "producer", "source", "record_partition", "local_flow", "symbolic_effects", "external_boundaries", "execution"], "plan exposes only the documented root shape")
	_check(plan.schema == Version.MES_STATION_CANDIDATE_PREFIX_PLAN_SCHEMA, "plan schema comes from the Content Core version contract")
	_check(plan.producer == {"core_version": Version.CORE_VERSION, "instruction_schema": Version.MES_INSTRUCTION_SCHEMA}, "producer binds the current Core and instruction schemas")
	_check(plan.source.archive == "synthetic_fixture" and plan.source.entry == "01M.MES-shaped-prefix" and plan.source.offset_basis == "code_start", "synthetic source is explicitly non-authoritative")
	_check(plan.source.address_entry_index == 0 and plan.source.address_entry_offset == PREFIX_OFFSET and plan.source.address_entry_end_offset == ENTRY_ZERO_END, "source retains entry-zero ownership boundary")
	_check(plan.source.prefix_offset == PREFIX_OFFSET and plan.source.prefix_end_offset == PREFIX_END and _is_digest(plan.source.prefix_sha256), "source retains exact half-open prefix identity")
	_check(plan.record_partition.offset == PREFIX_OFFSET and plan.record_partition.end_offset == PREFIX_END, "partition covers exactly 0x0008..0x026D")
	_check(plan.record_partition.record_count == RECORD_COUNT and plan.record_partition.typed_record_count == RECORD_COUNT and plan.record_partition.opaque_record_count == 0, "partition is exactly 103 typed and zero opaque records")
	_check(plan.record_partition.records == partition and partition == before, "plan copies every sanitized record descriptor without mutating input")
	var cursor := PREFIX_OFFSET
	for order in range(partition.size()):
		var row: Dictionary = partition[order]
		_check(row.order == order and row.offset == cursor and row.end_offset > row.offset, "record %d is ordered and contiguous" % order)
		cursor = row.end_offset
	_check(cursor == PREFIX_END, "all 613 bytes are covered once without a gap")
	_check(not _contains_unsanitized_value(plan), "plan contains no source payload, decoder operands or executable AST")


func _test_local_cfg(planner: RefCounted, partition: Array[Dictionary]) -> void:
	var plan: Dictionary = planner.call("_build_from_partition_for_test", partition)
	var flow: Dictionary = plan.local_flow
	_check(flow.kind == "symbolic_local_cfg" and flow.entry_offset == PREFIX_OFFSET, "local CFG starts at the audited entry-zero label")
	var loop: Dictionary = flow.loop
	_check(loop.counter == {"storage": "state_u16", "index": 2}, "loop counter is state_u16[2]")
	_check(loop.initialization.offset == 0x0169 and loop.initialization.end_offset == 0x016E and loop.initialization.value == 0, "loop records its caller-local initialization")
	_check(loop.guard.offset == 0x016E and loop.guard.end_offset == 0x0178 and loop.guard.predicate_signature == ["less_than", _state_ref("state_u16", 2), 16], "loop records the exact less-than-16 guard")
	_check(loop.guard.true_offset == 0x0178 and loop.guard.false_offset == 0x0196, "loop records both source edges")
	_check(loop.body.destination_signature == ["add", 31, _state_ref("state_u16", 2)], "loop destination index is 31 plus the counter")
	_check(loop.body.source_signature == _state_ref("banked_u16", ["add", 168, _state_ref("state_u16", 2)]), "loop source index is 168 plus the counter")
	_check(loop.body.increment_signature == ["add", _state_ref("state_u16", 2), 1], "loop increments only its local counter")
	_check(loop.back_edge.target_offset == 0x016E and loop.local_iteration_count == 16 and loop.exit_offset == 0x0196, "local proof retains the exact sixteen-iteration back edge")
	var branch: Dictionary = flow.surface_branch
	_check(branch.guard.offset == 0x01EF and branch.guard.predicate_signature == ["equal", _state_ref("global_u8", 2847), 1], "surface branch retains the exact source predicate")
	_check(branch.guard.true_offset == 0x01FA and branch.guard.false_offset == 0x0224, "surface branch retains both edges")
	_check(branch.true_path.surface_offset == 0x01FA and branch.true_path.continuation_target == 0x0229, "surface arm follows the stored continuation")
	_check(branch.false_path.routine_id == 21 and branch.false_path.physical_resume == 0x0229 and branch.join_offset == 0x0229, "routine-21 arm joins at the same caller offset")
	_check(flow.conditional_join == {
		"kind": "candidate_cascade_prefix_join",
		"offset": PREFIX_END,
		"end_offset": PREFIX_END,
		"requires_external_completion": true,
		"reached_by_tool": false,
		"next_plan_schema": Version.MES_STATION_CANDIDATE_PRIORITY_PLAN_SCHEMA,
		"delegated": false,
	}, "0x026D remains a conditional, non-delegated join")


func _test_symbolic_effects(planner: RefCounted, partition: Array[Dictionary]) -> void:
	var plan: Dictionary = planner.call("_build_from_partition_for_test", partition)
	var effects: Array = plan.symbolic_effects
	_check(effects.size() == 15, "all bounded caller-local effect families are symbolic metadata")
	_check(effects[0] == {"kind": "manager_vector_clear", "offset": 0x000D, "end_offset": 0x0062, "selectors": range(1, 18), "mapped_gameplay_state": false}, "manager selectors 1 through 17 are retained without gameplay-state mapping")
	_check(effects[1].storage == "global_u8" and effects[1].start_index == 10 and effects[1].count == 11 and effects[1].value == 0, "global byte clear range is bounded")
	_check(effects[2].index == 350 and effects[2].value_signature == ["call", "random_below", [3]] and not effects[2].evaluated, "random-below-3 write is not evaluated")
	_check(effects[3].index == 351 and effects[3].value_signature == ["call", "random_below", [13]] and not effects[3].evaluated, "random-below-13 write is not evaluated")
	var copy: Dictionary = effects[7]
	_check(copy.kind == "bounded_copy_loop" and copy.source_start == 168 and copy.destination_start == 31 and copy.count == 16 and copy.counter_final == 16, "loop copy summary retains only its proven local bounds")
	_check(effects[-3].index == 2836 and effects[-2].index == 3000 and effects[-1].index == 2841, "tail writes remain in source order")


func _test_external_boundaries(planner: RefCounted, partition: Array[Dictionary]) -> void:
	var plan: Dictionary = planner.call("_build_from_partition_for_test", partition)
	var boundaries: Array = plan.external_boundaries
	_check(boundaries.size() == EXTERNAL_ROWS.size(), "all thirteen nonlocal/native checkpoints are retained")
	var previous_end := -1
	for order in range(mini(boundaries.size(), EXTERNAL_ROWS.size())):
		var boundary: Dictionary = boundaries[order]
		var expected: Array = EXTERNAL_ROWS[order]
		_check(boundary.order == order and boundary.kind == expected[0] and boundary.offset == expected[1] and boundary.end_offset == expected[2], "checkpoint %d retains kind and exact record boundary" % order)
		_check(boundary.offset >= previous_end and boundary.physical_resume == boundary.end_offset, "checkpoint %d remains source-ordered with caller-local resume" % order)
		_check(boundary.condition == expected[3] and boundary[expected[4]] == expected[5], "checkpoint %d retains only its qualified selector or routine metadata" % order)
		_check(boundary.sha256 == _hash_at(partition, boundary.offset), "checkpoint %d is bound to its sanitized record hash" % order)
		_check(boundary.tool_execution == false and boundary.completion == "unresolved", "checkpoint %d is neither executed nor promoted complete" % order)
		previous_end = boundary.end_offset
	_check(boundaries[2].presentation_subcommand == 3 and boundaries[7].presentation_subcommand == 3 and boundaries[8].presentation_subcommand == 3, "AX checkpoints retain their typed subcommand")
	_check(boundaries[11].presentation_subcommand == 11, "conditional surface checkpoint retains its typed subcommand")


func _test_execution_boundary(planner: RefCounted, partition: Array[Dictionary]) -> void:
	var plan: Dictionary = planner.call("_build_from_partition_for_test", partition)
	_check(plan.execution == {
		"kind": "read_only_symbolic_projection",
		"mes_instruction_execution": false,
		"local_effect_application": false,
		"external_call_execution": false,
		"native_effect_execution": false,
		"state_mutation": false,
		"post_prefix_state": "not_computed",
		"external_completion": "unresolved",
		"prefix_join_reachability": "conditional",
		"entry_zero_reachability": "unqualified",
		"host_zero_start": "unresolved",
		"native_address_row_selection": "unresolved",
		"natural_scheduler_eligibility": "unqualified",
		"native_cadence": "unresolved",
	}, "execution receipt keeps every host, completion and post-state boundary unresolved")


func _test_validation_and_tamper(planner: RefCounted, partition: Array[Dictionary]) -> void:
	var partition_before := partition.duplicate(true)
	var plan: Dictionary = planner.call("_build_from_partition_for_test", partition)
	var plan_before := plan.duplicate(true)
	_check(planner.call("_validate_from_partition_for_test", partition, plan).get("ok", false), "deterministically rebuilt native-integer plan validates")
	var json_plan: Variant = JSON.parse_string(JSON.stringify(plan))
	_check(json_plan is Dictionary and planner.call("_validate_from_partition_for_test", partition, json_plan).get("ok", false), "lossless integral JSON replay validates")
	_check(planner.call("_build_from_partition_for_test", partition) == plan, "synthetic rebuild is deterministic")
	var cases: Array[Dictionary] = []
	var schema := plan.duplicate(true); schema.schema = "wrong"; cases.append({"label": "schema", "plan": schema})
	var source := plan.duplicate(true); source.source.prefix_end_offset += 1; cases.append({"label": "source range", "plan": source})
	var partition_row := plan.duplicate(true); partition_row.record_partition.records[10].op = "opaque"; cases.append({"label": "record operation", "plan": partition_row})
	var partition_hash := plan.duplicate(true); partition_hash.record_partition.records[20].sha256 = "0".repeat(64); cases.append({"label": "record hash", "plan": partition_hash})
	var loop := plan.duplicate(true); loop.local_flow.loop.local_iteration_count = 15; cases.append({"label": "loop bound", "plan": loop})
	var edge := plan.duplicate(true); edge.local_flow.surface_branch.guard.false_offset += 1; cases.append({"label": "branch edge", "plan": edge})
	var effect := plan.duplicate(true); effect.symbolic_effects[2].evaluated = true; cases.append({"label": "effect evaluation", "plan": effect})
	var external_order := plan.duplicate(true); external_order.external_boundaries[0].order = 1; cases.append({"label": "external order", "plan": external_order})
	var external_completion := plan.duplicate(true); external_completion.external_boundaries[8].completion = "complete"; cases.append({"label": "external completion", "plan": external_completion})
	var external_execution := plan.duplicate(true); external_execution.external_boundaries[3].tool_execution = true; cases.append({"label": "external execution", "plan": external_execution})
	var join := plan.duplicate(true); join.local_flow.conditional_join.reached_by_tool = true; cases.append({"label": "join promotion", "plan": join})
	var execution := plan.duplicate(true); execution.execution.post_prefix_state = {}; cases.append({"label": "post-state claim", "plan": execution})
	var host := plan.duplicate(true); host.execution.natural_scheduler_eligibility = "qualified"; cases.append({"label": "host eligibility", "plan": host})
	var extra := plan.duplicate(true); extra["extra"] = 0; cases.append({"label": "extra root field", "plan": extra})
	for item in cases:
		var changed: Dictionary = item.plan
		var before := changed.duplicate(true)
		_check(not planner.call("_validate_from_partition_for_test", partition, changed).get("ok", true) and changed == before, "%s tamper rejects without mutation" % item.label)
	_check(plan == plan_before and partition == partition_before, "validation and tamper probes preserve plan and partition")


func _test_partition_rejections(planner: RefCounted, partition: Array[Dictionary]) -> void:
	var cases: Array[Dictionary] = []
	var missing := partition.duplicate(true); missing.pop_back(); cases.append({"label": "missing record", "value": missing})
	var extra_record := partition.duplicate(true); extra_record.append(partition[-1].duplicate(true)); cases.append({"label": "extra record", "value": extra_record})
	var unknown := partition.duplicate(true); unknown[0]["extra"] = 0; cases.append({"label": "unknown field", "value": unknown})
	var missing_hash := partition.duplicate(true); missing_hash[0].erase("sha256"); cases.append({"label": "missing hash", "value": missing_hash})
	var boolean_order := partition.duplicate(true); boolean_order[1].order = true; cases.append({"label": "boolean order", "value": boolean_order})
	var float_offset := partition.duplicate(true); float_offset[0].offset = float(PREFIX_OFFSET); cases.append({"label": "float offset", "value": float_offset})
	var gap := partition.duplicate(true); gap[50].offset += 1; cases.append({"label": "gap", "value": gap})
	var overlap := partition.duplicate(true); overlap[50].end_offset -= 1; cases.append({"label": "overlap", "value": overlap})
	var changed_op := partition.duplicate(true); changed_op[75].op = "source_line_marker"; cases.append({"label": "changed operation", "value": changed_op})
	var short_hash := partition.duplicate(true); short_hash[12].sha256 = "a".repeat(63); cases.append({"label": "short hash", "value": short_hash})
	var uppercase_hash := partition.duplicate(true); uppercase_hash[12].sha256 = "A".repeat(64); cases.append({"label": "noncanonical hash", "value": uppercase_hash})
	var bool_hash := partition.duplicate(true); bool_hash[12].sha256 = false; cases.append({"label": "boolean hash", "value": bool_hash})
	var swapped := partition.duplicate(true); var temp: Dictionary = swapped[5]; swapped[5] = swapped[6]; swapped[6] = temp; cases.append({"label": "record order", "value": swapped})
	for item in cases:
		var changed: Variant = item.value
		var before: Variant = changed.duplicate(true)
		_check(not planner.call("_build_from_partition_for_test", changed).get("ok", true) and changed == before, "%s rejects without mutation" % item.label)
	for invalid in [null, true, {}, "records", 103, 103.0]:
		_check(not planner.call("_build_from_partition_for_test", invalid).get("ok", true), "non-array partition rejects")


func _test_public_source_boundary(planner: RefCounted) -> void:
	var empty := PackedByteArray()
	var before := empty.duplicate()
	_check(not planner.build(empty).get("ok", true) and empty == before, "public build rejects non-original bytes without mutation")
	for forged in [{}, {"ok": true}, {"schema": Version.MES_STATION_CANDIDATE_PREFIX_PLAN_SCHEMA}]:
		var plan: Dictionary = forged.duplicate(true)
		var plan_before := plan.duplicate(true)
		_check(not planner.validate(empty, plan).get("ok", true) and plan == plan_before and empty == before, "public validation rejects forged evidence without mutation")


func _fixture_partition() -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	_append(records, 0x0008, 0x000D, "entry_label")
	for index in range(17): _append(records, 0x000D + index * 5, 0x0012 + index * 5, "command_1b")
	for index in range(22): _append(records, 0x0062 + index * 5, 0x0067 + index * 5, "source_line_marker")
	for index in range(11): _append(records, 0x00D0 + index * 6, 0x00D6 + index * 6, "global_u8_write_run")
	for row in [
		[0x0112, 0x0117, "source_line_marker"], [0x0117, 0x011E, "global_u8_write_run"],
		[0x011E, 0x0123, "source_line_marker"], [0x0123, 0x012A, "global_u8_write_run"],
	]: _append(records, row[0], row[1], row[2])
	for index in range(4): _append(records, 0x012A + index * 5, 0x012F + index * 5, "source_line_marker")
	for row in [
		[0x013E, 0x0143, "state_u16_write_run"], [0x0143, 0x0148, "definition_invoke"],
		[0x0148, 0x014D, "source_line_marker"], [0x014D, 0x0152, "state_u16_write_run"],
		[0x0152, 0x0157, "script_transfer"], [0x0157, 0x015C, "source_line_marker"],
		[0x015C, 0x0163, "ax_presentation_control"], [0x0163, 0x0169, "global_u8_write_run"],
		[0x0169, 0x016E, "state_u16_write_run"], [0x016E, 0x0178, "branch_if_not_true"],
		[0x0178, 0x0189, "banked_u16_write_run"], [0x0189, 0x0191, "state_u16_write_run"],
		[0x0191, 0x0196, "continuation_transfer"], [0x0196, 0x019C, "global_u8_write_run"],
		[0x019C, 0x01A1, "script_transfer"], [0x01A1, 0x01A9, "native_record_dispatch"],
		[0x01A9, 0x01B1, "native_record_dispatch"], [0x01B1, 0x01B9, "native_record_dispatch"],
		[0x01B9, 0x01BE, "source_line_marker"], [0x01BE, 0x01C3, "source_line_marker"],
		[0x01C3, 0x01CA, "ax_presentation_control"], [0x01CA, 0x01D1, "ax_presentation_control"],
		[0x01D1, 0x01D8, "banked_u16_write_run"], [0x01D8, 0x01DE, "argument_slot_write_run"],
		[0x01DE, 0x01E3, "script_transfer"], [0x01E3, 0x01EA, "banked_u16_write_run"],
		[0x01EA, 0x01EF, "script_transfer"], [0x01EF, 0x01FA, "branch_if_not_true"],
		[0x01FA, 0x021F, "surface_operation"], [0x021F, 0x0224, "continuation_transfer"],
		[0x0224, 0x0229, "script_transfer"], [0x0229, 0x022F, "global_u8_write_run"],
		[0x022F, 0x0235, "global_u8_write_run"], [0x0235, 0x023B, "global_u8_write_run"],
	]: _append(records, row[0], row[1], row[2])
	for index in range(10): _append(records, 0x023B + index * 5, 0x0240 + index * 5, "source_line_marker")
	return records


func _append(records: Array[Dictionary], offset: int, end_offset: int, op: String) -> void:
	var order := records.size()
	records.append({
		"order": order,
		"offset": offset,
		"end_offset": end_offset,
		"op": op,
		"sha256": _sha256(("fixture-record:%d:0x%04X:0x%04X:%s" % [order, offset, end_offset, op]).to_utf8_buffer()),
	})


func _hash_at(partition: Array[Dictionary], offset: int) -> String:
	for record in partition:
		if int(record.offset) == offset:
			return str(record.sha256)
	return ""


func _state_ref(storage: String, index: Variant) -> Array:
	return ["state_ref", storage, 0, index]


func _contains_unsanitized_value(value: Variant, key := "", depth := 0) -> bool:
	if depth > 32 or value is PackedByteArray:
		return true
	if key in ["payload", "bytes", "bytecode", "operands", "ast", "expression"]:
		return true
	if value is Dictionary:
		for child_key in value:
			if typeof(child_key) != TYPE_STRING or _contains_unsanitized_value(value[child_key], child_key, depth + 1):
				return true
	elif value is Array:
		for child in value:
			if _contains_unsanitized_value(child, "", depth + 1):
				return true
	return false


func _is_digest(value: Variant) -> bool:
	if typeof(value) != TYPE_STRING or value.length() != 64:
		return false
	var text := str(value)
	for index in range(text.length()):
		var code: int = text.unicode_at(index)
		if not (code >= 48 and code <= 57) and not (code >= 97 and code <= 102):
			return false
	return true


func _sha256(data: PackedByteArray) -> String:
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK or context.update(data) != OK:
		return ""
	return context.finish().hex_encode()


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failed = true
	push_error(message)
