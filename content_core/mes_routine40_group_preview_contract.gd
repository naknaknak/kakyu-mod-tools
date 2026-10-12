class_name KakyuMesRoutine40GroupPreviewContract
extends RefCounted

const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")
const DecoderScript := preload("res://content_core/mes_instruction_decoder.gd")
const ResultDispatchParserScript := preload("res://content_core/mes_result_dispatch_parser.gd")
const ContractValues := preload("res://content_core/contract_values.gd")

const FIRST_RESULT_STORAGE := "state_u16"
const FIRST_RESULT_INDEX := 21
const SECOND_RESULT_STORAGE := "state_u16"
const SECOND_RESULT_INDEX := 13
const MAX_GROUP_ROWS := 17

var _decoder := DecoderScript.new()
var _dispatch_parser := ResultDispatchParserScript.new()


func build(
	code: PackedByteArray,
	end_offset: int,
	boundary_result: Dictionary,
	source_identity: Dictionary = {}
) -> Dictionary:
	var limit := mini(end_offset, code.size())
	if limit <= 0 or end_offset != limit:
		return _error("Routine-40 grouped preview code range is invalid.")
	if str(boundary_result.get("status", "")) != "def_selection_boundary":
		return _error("Execution did not stop at a DEF selection boundary.")
	var trace: Array = boundary_result.get("trace", [])
	if trace.is_empty():
		return _error("Routine-40 grouped preview has no terminal trace row.")
	var terminal: Dictionary = trace[-1]
	if (
		int(terminal.get("command_id", -1)) != 0x1D
		or int(terminal.get("routine_id", -1)) != 40
		or int(terminal.get("source_offset", -1)) != int(boundary_result.get("offset", -2))
	):
		return _error("Grouped preview terminal is not the exact routine-40 call.")

	var groups: Dictionary = boundary_result.get("definition_groups", {})
	var group_order: Array = boundary_result.get("definition_group_order", [])
	if groups.size() < 2 or group_order.size() != groups.size():
		return _error("Routine-40 grouped preview requires an ordered multi-group registry.")
	if int(boundary_result.get("selection_definition_group", -1)) != 0:
		return _error("Routine-40 grouped preview does not expose fixed-key group 0 first.")
	var first_group: Array = groups.get(0, [])
	if first_group.is_empty() or first_group.size() > MAX_GROUP_ROWS:
		return _error("Routine-40 first-stage group requires 1..17 rows.")
	var expected_order: Array[int] = []
	for selector in range(first_group.size() + 1):
		expected_order.append(selector)
	var normalized_order: Array[int] = []
	for untyped_selector in group_order:
		normalized_order.append(int(untyped_selector))
	if normalized_order != expected_order:
		return _error("Routine-40 group selectors do not match one-based first-stage results.")

	var group_rows: Array[Dictionary] = []
	var registered_count := 0
	for selector in normalized_order:
		var definitions: Array = groups.get(selector, [])
		if definitions.size() > MAX_GROUP_ROWS:
			return _error("Routine-40 grouped preview contains more than 17 rows in one group.")
		var definition_rows: Array[Dictionary] = []
		var previous_source := -1
		for definition_index in range(definitions.size()):
			var definition: Dictionary = definitions[definition_index]
			var definition_id := int(definition.get("definition_id", -1))
			var source_offset := int(definition.get("source_offset", -1))
			var body_offset := int(definition.get("body_offset", -1))
			var target_offset := int(definition.get("target_offset", -1))
			if definition_id != definition_index:
				return _error("Routine-40 grouped definition identifiers are not zero-based and sequential.")
			if (
				source_offset <= previous_source
				or body_offset <= source_offset
				or target_offset <= body_offset
				or target_offset > limit
			):
				return _error("Routine-40 grouped definition bounds are invalid or out of order.")
			if int(definition.get("body_size", -1)) != target_offset - body_offset:
				return _error("Routine-40 grouped definition body size changed.")
			var body_sha256 := ContractValues.sha256(code.slice(body_offset, target_offset))
			if body_sha256 != str(definition.get("body_sha256", "")):
				return _error("Routine-40 grouped definition body fingerprint changed.")
			definition_rows.append({
				"definition_id": definition_id,
				"source_offset": source_offset,
				"body_offset": body_offset,
				"target_offset": target_offset,
				"body_size": target_offset - body_offset,
				"body_sha256": body_sha256,
			})
			previous_source = source_offset
		registered_count += definition_rows.size()
		group_rows.append({
			"selector": selector,
			"definition_count": definition_rows.size(),
			"definitions": definition_rows,
			"empty_after_clear": definition_rows.is_empty(),
		})
	if registered_count != int(boundary_result.get("registered_definition_count", -1)):
		return _error("Routine-40 grouped registered-row count changed.")
	if registered_count != int(boundary_result.get("observed_definition_count", -1)):
		return _error("Routine-40 grouped observed-row count changed.")
	var terminal_instruction := _decoder.decode_at_structural(
		code, int(terminal.source_offset), limit
	)
	if (
		not terminal_instruction.get("ok", false)
		or int(terminal_instruction.get("command_id", -1)) != 0x1D
	):
		return _error("Routine-40 grouped terminal no longer decodes.")
	var resume_offset := int(terminal_instruction.get("end_offset", -1))
	var consumer := _build_group_consumer(
		code, resume_offset, limit, group_rows, first_group.size()
	)
	if not consumer.get("ok", false):
		return consumer

	return {
		"ok": true,
		"schema": ContentCoreVersionScript.MES_ROUTINE40_GROUP_PREVIEW_SCHEMA,
		"bytecode_sha256": ContractValues.sha256(code.slice(0, limit)),
		"code_size": limit,
		"source_identity": source_identity.duplicate(true),
		"boundary_offset": int(terminal.source_offset),
		"resume_offset": resume_offset,
		"first_group_selector": 0,
		"first_result_storage": FIRST_RESULT_STORAGE,
		"first_result_index": FIRST_RESULT_INDEX,
		"first_result_values": range(1, first_group.size() + 1),
		"second_result_storage": SECOND_RESULT_STORAGE,
		"second_result_index": SECOND_RESULT_INDEX,
		"group_order": normalized_order,
		"groups": group_rows,
		"registered_definition_count": registered_count,
		"consumer_kind": str(consumer.consumer_kind),
		"consumer_groups": (consumer.get("groups", []) as Array).duplicate(true),
		"complete_available_mapping": bool(consumer.complete_available_mapping),
		"default_continuation": (consumer.default_continuation as Dictionary).duplicate(true),
		"input_policy": "explicit_disposable_analysis_preview",
		"native_result_encoding": "one_based_selected_record_index",
		"consumer_execution_policy": "structural_coordinates_only",
		"caller_resume_policy": "forbidden",
		"gameplay_state_policy": "unchanged",
	}


func validate(code: PackedByteArray, end_offset: int, contract: Dictionary) -> Dictionary:
	if str(contract.get("schema", "")) != ContentCoreVersionScript.MES_ROUTINE40_GROUP_PREVIEW_SCHEMA:
		return _error("Routine-40 grouped preview contract schema is unsupported.")
	var definition_groups := {}
	var presented_definitions: Array = []
	for untyped_group in contract.get("groups", []):
		if not untyped_group is Dictionary:
			return _error("Routine-40 grouped preview contract contains an invalid group.")
		var group: Dictionary = untyped_group
		var selector := int(group.get("selector", -1))
		var definitions: Array = group.get("definitions", []).duplicate(true)
		definition_groups[selector] = definitions
		if selector == int(contract.get("first_group_selector", -1)):
			presented_definitions = definitions
	var pseudo_result := {
		"status": "def_selection_boundary",
		"offset": int(contract.get("boundary_offset", -1)),
		"trace": [{
			"command_id": 0x1D,
			"routine_id": 40,
			"source_offset": int(contract.get("boundary_offset", -1)),
		}],
		"definitions": presented_definitions,
		"definition_groups": definition_groups,
		"definition_group_order": (contract.get("group_order", []) as Array).duplicate(),
		"selection_definition_group": int(contract.get("first_group_selector", -1)),
		"registered_definition_count": int(contract.get("registered_definition_count", -1)),
		"observed_definition_count": int(contract.get("registered_definition_count", -1)),
	}
	var rebuilt := build(code, end_offset, pseudo_result, contract.get("source_identity", {}))
	if not rebuilt.get("ok", false):
		return rebuilt
	for key in [
		"schema", "bytecode_sha256", "code_size", "source_identity", "boundary_offset",
		"resume_offset",
		"first_group_selector", "first_result_storage", "first_result_index",
		"first_result_values", "second_result_storage", "second_result_index", "group_order",
		"groups", "registered_definition_count", "consumer_kind", "consumer_groups",
		"complete_available_mapping", "default_continuation", "input_policy",
		"native_result_encoding", "consumer_execution_policy",
		"caller_resume_policy", "gameplay_state_policy",
	]:
		if rebuilt.get(key) != contract.get(key):
			return _error("Routine-40 grouped preview contract field changed: %s." % key)
	return rebuilt


func _build_group_consumer(
	code: PackedByteArray,
	resume_offset: int,
	limit: int,
	available_groups: Array[Dictionary],
	first_count: int
) -> Dictionary:
	var cursor_result := _dispatch_parser.skip_source_markers(code, resume_offset, limit)
	if not cursor_result.get("ok", false):
		return _error("Routine-40 grouped result consumer does not start at a decoded coordinate.")
	var cursor := int(cursor_result.offset)
	var rows: Array[Dictionary] = []
	for expected_first in range(1, first_count + 1):
		var instruction := _decoder.decode_at_structural(code, cursor, limit)
		if not instruction.get("ok", false):
			return _error("Routine-40 grouped first-result branch does not decode.")
		var first_branch := _dispatch_branch(instruction)
		if not first_branch.get("ok", false) or int(first_branch.first_result) != expected_first:
			return _error("Routine-40 grouped first-result branches are not sequential.")
		var first_false_result := _dispatch_parser.skip_source_markers(
			code, int(first_branch.target), limit
		)
		if not first_false_result.get("ok", false):
			return _error("Routine-40 grouped first-result false target does not decode.")
		var first_false_target := int(first_false_result.offset)
		if not _decoder.decode_at_structural(code, first_false_target, limit).get("ok", false):
			return _error("Routine-40 grouped first-result target is not an instruction.")

		var secondary_cursor := -1
		if int(first_branch.second_result) >= 0:
			secondary_cursor = cursor
		else:
			var secondary_search := _first_secondary_between(
				code, int(instruction.end_offset), first_false_target, limit
			)
			if not secondary_search.get("ok", false):
				return secondary_search
			secondary_cursor = int(secondary_search.offset)
		var secondary_rows: Array[Dictionary] = []
		var expected_second := 1
		var secondary_terminal := first_false_target
		var seen_secondary := {}
		while secondary_cursor >= 0 and not seen_secondary.has(secondary_cursor):
			seen_secondary[secondary_cursor] = true
			var secondary_instruction := _decoder.decode_at_structural(
				code, secondary_cursor, limit
			)
			if not secondary_instruction.get("ok", false):
				return _error("Routine-40 grouped second-result branch does not decode.")
			var secondary_branch := _secondary_dispatch_branch(
				secondary_instruction, expected_first
			)
			if not secondary_branch.get("ok", false):
				break
			if int(secondary_branch.second_result) != expected_second:
				return _error("Routine-40 grouped second-result branches are not sequential.")
			var targets := _dispatch_parser.validated_branch_targets(
				code, secondary_instruction, int(secondary_branch.target), limit
			)
			if not targets.get("ok", false):
				return _error("Routine-40 grouped second-result branch target does not decode.")
			secondary_terminal = int(targets.false_target_offset)
			secondary_rows.append({
				"source_offset": secondary_cursor,
				"second_result": expected_second,
				"consumer_entry_offset": int(targets.fallthrough_offset),
				"false_target_offset": secondary_terminal,
			})
			expected_second += 1
			var next_instruction := _decoder.decode_at_structural(
				code, secondary_terminal, limit
			)
			var next_branch := _secondary_dispatch_branch(next_instruction, expected_first)
			secondary_cursor = (
				secondary_terminal
				if next_branch.get("ok", false)
				and int(next_branch.second_result) == expected_second
				else -1
			)

		var available_count := int(available_groups[expected_first].definition_count)
		var unmatched_available: Array[int] = []
		for second_result in range(secondary_rows.size() + 1, available_count + 1):
			unmatched_available.append(second_result)
		rows.append({
			"first_result": expected_first,
			"group_selector": expected_first,
			"first_branch_offset": cursor,
			"first_branch_kind": (
				"first_and_second"
				if int(first_branch.second_result) >= 0
				else "first_only"
			),
			"first_false_target_offset": first_false_target,
			"available_definition_count": available_count,
			"stored_second_result_values": range(1, secondary_rows.size() + 1),
			"second_branches": secondary_rows,
			"available_mapping_complete": unmatched_available.is_empty(),
			"unmatched_available_second_results": unmatched_available,
			"second_terminal_false_target_offset": secondary_terminal,
		})
		if expected_first < first_count:
			cursor = first_false_target

	var default_source := int(rows[-1].second_terminal_false_target_offset)
	var default_instruction := _decoder.decode_at_structural(code, default_source, limit)
	var transfer := _dispatch_parser.code_coordinate_transfer(default_instruction)
	if not transfer.get("ok", false):
		return _error("Routine-40 grouped consumer has no exact default coordinate transfer.")
	var default_destination := int(transfer.destination_offset)
	if not _decoder.decode_at_structural(code, default_destination, limit).get("ok", false):
		return _error("Routine-40 grouped default destination does not decode.")
	var complete := true
	for row in rows:
		if not bool((row as Dictionary).available_mapping_complete):
			complete = false
			break
	return {
		"ok": true,
		"consumer_kind": "one_based_state_u16_21_then_state_u16_13_dispatch",
		"groups": rows,
		"complete_available_mapping": complete,
		"default_continuation": {
			"kind": "unconditional_code_coordinate_transfer",
			"source_offset": default_source,
			"destination_offset": default_destination,
			"backward_transfer": default_destination < default_source,
			"covers_unmatched_or_out_of_range_results": true,
			"gameplay_meaning": "unresolved",
		},
	}


func _first_secondary_between(
	code: PackedByteArray, start_offset: int, end_offset: int, limit: int
) -> Dictionary:
	var cursor := start_offset
	var seen := {}
	while cursor < end_offset and not seen.has(cursor):
		seen[cursor] = true
		var instruction := _decoder.decode_at_structural(code, cursor, limit)
		if not instruction.get("ok", false):
			return _error("Routine-40 grouped secondary-search range does not decode.")
		var branch := _dispatch_parser.state_u16_equal_literal_branch(instruction)
		if branch.get("ok", false) and int(branch.state_index) == SECOND_RESULT_INDEX:
			return {"ok": true, "offset": cursor}
		var next_offset := int(instruction.end_offset)
		if next_offset <= cursor:
			return _error("Routine-40 grouped secondary-search range did not advance.")
		cursor = next_offset
	return {"ok": true, "offset": -1}


func _dispatch_branch(instruction: Dictionary) -> Dictionary:
	var simple := _dispatch_parser.state_u16_equal_literal_branch(instruction)
	if simple.get("ok", false) and int(simple.state_index) == FIRST_RESULT_INDEX:
		return {
			"ok": true,
			"first_result": int(simple.literal),
			"second_result": -1,
			"target": int(simple.target),
		}
	var compound := _dispatch_parser.compound_state_result_gate_branch(
		instruction, FIRST_RESULT_STORAGE, FIRST_RESULT_INDEX
	)
	var gate: Dictionary = compound.get("gate", {})
	if (
		not compound.get("ok", false)
		or str(gate.get("storage", "")) != SECOND_RESULT_STORAGE
		or int(gate.get("index", -1)) != SECOND_RESULT_INDEX
	):
		return {"ok": false}
	return {
		"ok": true,
		"first_result": int(compound.result),
		"second_result": int(gate.literal),
		"target": int(compound.target),
	}


func _secondary_dispatch_branch(
	instruction: Dictionary, expected_first_result: int
) -> Dictionary:
	var compound := _dispatch_branch(instruction)
	if (
		compound.get("ok", false)
		and int(compound.first_result) == expected_first_result
		and int(compound.second_result) >= 0
	):
		return {
			"ok": true,
			"second_result": int(compound.second_result),
			"target": int(compound.target),
		}
	var simple := _dispatch_parser.state_u16_equal_literal_branch(instruction)
	if simple.get("ok", false) and int(simple.state_index) == SECOND_RESULT_INDEX:
		return {
			"ok": true,
			"second_result": int(simple.literal),
			"target": int(simple.target),
		}
	return {"ok": false}


func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message}
