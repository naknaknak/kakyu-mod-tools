class_name KakyuMesStationCandidatePriorityPlan
extends RefCounted

# Source-only projection of the fifteen 01M.MES predicates that precede the
# EVENTB03-local candidate guard. A matching predicate stops at its true-body
# boundary; this class never executes or interprets any candidate body.
const ContainerScript := preload("res://content_core/mes_container.gd")
const DecoderScript := preload("res://content_core/mes_instruction_decoder.gd")
const ExpressionScript := preload("res://content_core/mes_expression.gd")
const StateScript := preload("res://content_core/mes_sandbox_state.gd")
const Version := preload("res://content_core/content_core_version.gd")
const ContractValues := preload("res://content_core/contract_values.gd")

const SOURCE_SHA256 := "a50511b0ad0ad446b7988c3cfb36736424bf6617e9eb952e20b505f745607cc5"
const SOURCE_BYTECODE_SHA256 := "f590b3007ea98dcce6f10bc85eb316abdf250f6417a87cec4ab0a6d98ed2230b"
const CASCADE_SHA256 := "34ae9a590921cf5e4ac5f4a5921c2d5b1a779ae6d868d7b4ead456bcb1671c29"
const CASCADE_OFFSET := 0x026D
const JOIN_OFFSET := 0x7691

const INPUT_GROUPS := ["state_u16", "banked_u16_0", "global_u8"]
const STATE_U16_INDICES := [4, 7, 19]
const BANKED_U16_INDICES := [
	213, 214, 215, 216, 217, 218, 219, 220, 221, 222,
	225, 226, 227, 228, 229, 230, 231, 232, 233, 234,
	235, 236, 237, 238, 268,
]
const GLOBAL_U8_INDICES := [
	100, 107, 109, 110, 117, 119, 120, 127, 129, 130, 137,
	139, 140, 147, 149, 160, 167, 169, 170, 177, 179, 180,
	187, 189, 190, 197, 199, 200, 207, 209, 210, 217, 219,
	220, 227, 229, 1188, 1189, 1750, 1751, 2300, 2301, 2304,
	2305,
]

# start, end, false destination, exact SHA-256, schedule date cell,
# schedule time cell, schedule byte-family base. Negative parameters select
# one of the three non-schedule signatures.
const GUARD_ROWS := [
	[0x026D, 0x02A3, 0x247E, "0d0e009000726fe0f17548178304c4c6e86b71f2ac575d2f6437bd10c82eef57", -1, -1, -1],
	[0x247E, 0x24D7, 0x2AF7, "dc89fca3c2c7a529c34c5ee8063a8974d2ddaed4e6e2cc697c211007e4f28b61", 213, 214, 100],
	[0x2AF7, 0x2B50, 0x3170, "b7314844e929563792746672a74858c66aa4c6adb20880c7a1928ec5b95949ae", 215, 216, 110],
	[0x3170, 0x31C9, 0x37E9, "af269a8ec3cdd5d8d2c05bb4ce63c64981e550ec78b363b7d1722d2490a3eabb", 217, 218, 120],
	[0x37E9, 0x3842, 0x3E62, "759c90777fecd03bc76b37627e4b639cf2c3caa01bdacd9c088f0cdec291f3e1", 219, 220, 130],
	[0x3E62, 0x3EBB, 0x44DB, "728f5cecff49a64f35a7bb39cb9434cceb213727eb6203e54ea9e8393e9fa86b", 221, 222, 140],
	[0x44DB, 0x4534, 0x4B54, "f6cb89285e40075b7520511300e16cb24aad36638775e1b941280b8602d53c88", 225, 226, 160],
	[0x4B54, 0x4BAD, 0x51CD, "86fe3d853c62a02e8498e2c7e59be95ac102305d42476e0a4e626ff69c07e931", 227, 228, 170],
	[0x51CD, 0x5226, 0x5846, "dfa883381166c690755794263524fed545f8c175cb89871a47745047df484530", 229, 230, 180],
	[0x5846, 0x589F, 0x5EBF, "285f1ed60093062ceaf35777b4a875f5825c9c190195be5dc11a6a35fd3e5482", 231, 232, 190],
	[0x5EBF, 0x5F18, 0x6538, "4d11b77ddf881fc8b1d1f42c736c5717c93d1a74acc3aa373047221bba3a7550", 233, 234, 200],
	[0x6538, 0x6591, 0x6BB1, "70dd239bdc7caf40e80a53d732c085d39d409608b48b8817c41c2ec595510b86", 235, 236, 210],
	[0x6BB1, 0x6C0A, 0x722A, "67e133c45363e595f4c08ac5a25643865d7fb67b7b29bbeb2051a45fe8ca330a", 237, 238, 220],
	[0x722A, 0x725D, 0x73F5, "2ca7c628287f9a65b90969240f1dbab5a19cae41c05f89811d124300a08753b0", -1, -1, -2],
	[0x73F5, 0x7425, 0x7691, "a97d3d398e663593eb01b85e1ce4892cd69ca38696a7089f51ec25c53928144b", -1, -1, -3],
]


func build(source_payload: PackedByteArray, input_value: Variant) -> Dictionary:
	var normalized := _normalize_input(input_value, false)
	if not normalized.get("ok", false):
		return normalized
	var document := ContainerScript.new().parse(source_payload)
	if (
		not document.get("ok", false)
		or str(document.get("entry_sha256", "")) != SOURCE_SHA256
		or str(document.get("bytecode_sha256", "")) != SOURCE_BYTECODE_SHA256
	):
		return _error("Station candidate priority planning requires the audited original 01M.MES payload.")
	if not _original_entry_layout_matches(document):
		return _error("Station candidate cascade address-table ownership changed.")
	var code: PackedByteArray = document.bytecode
	if ContractValues.sha256(code.slice(CASCADE_OFFSET, JOIN_OFFSET)) != CASCADE_SHA256:
		return _error("Station candidate cascade source slice changed.")
	var inspected := _inspect(code, true)
	if not inspected.get("ok", false):
		return inspected
	return _compose_plan(inspected, normalized.values, {
		"archive": "mes.arc",
		"entry": "01M.MES",
		"entry_sha256": SOURCE_SHA256,
		"bytecode_sha256": SOURCE_BYTECODE_SHA256,
		"offset_basis": "code_start",
		"cascade_offset": CASCADE_OFFSET,
		"join_offset": JOIN_OFFSET,
		"cascade_sha256": CASCADE_SHA256,
	})


func validate(source_payload: PackedByteArray, plan: Dictionary) -> Dictionary:
	var normalized := _normalize_input(plan.get("input", null), true)
	if not normalized.get("ok", false):
		return _error("Station candidate priority plan input is malformed.")
	var rebuilt := build(source_payload, normalized.values)
	if not rebuilt.get("ok", false):
		return rebuilt
	if not _same_plan_value(plan, rebuilt):
		return _error("Station candidate priority plan no longer matches its source-bound projection.")
	return {"ok": true}


# Test-only source-local entry point. It accepts a synthetic code buffer only
# when all fifteen original guard envelopes, signatures, hashes and edges are
# reproduced exactly; it still does not inspect or execute true bodies.
func _build_from_code(code: PackedByteArray, input_value: Variant) -> Dictionary:
	var normalized := _normalize_input(input_value, false)
	if not normalized.get("ok", false):
		return normalized
	var inspected := _inspect(code, true)
	if not inspected.get("ok", false):
		return inspected
	return _compose_plan(inspected, normalized.values, {
		"archive": "synthetic_fixture",
		"entry": "01M.MES-shaped-code",
		"entry_sha256": "not_applicable",
		"bytecode_sha256": ContractValues.sha256(code),
		"offset_basis": "code_start",
		"cascade_offset": CASCADE_OFFSET,
		"join_offset": JOIN_OFFSET,
		"cascade_sha256": ContractValues.sha256(code.slice(CASCADE_OFFSET, JOIN_OFFSET)),
	})


func _validate_from_code(code: PackedByteArray, plan: Dictionary) -> Dictionary:
	var normalized := _normalize_input(plan.get("input", null), true)
	if not normalized.get("ok", false):
		return _error("Synthetic station candidate priority plan input is malformed.")
	var rebuilt := _build_from_code(code, normalized.values)
	if not rebuilt.get("ok", false):
		return rebuilt
	if not _same_plan_value(plan, rebuilt):
		return _error("Synthetic station candidate priority plan changed.")
	return {"ok": true}


func _inspect(code: PackedByteArray, require_original_hashes := true) -> Dictionary:
	if code.size() < JOIN_OFFSET:
		return _error("Station candidate cascade is truncated.")
	var decoder := DecoderScript.new()
	var guards: Array[Dictionary] = []
	var guard_asts: Array[Dictionary] = []
	var observed_references := {}
	for order in range(GUARD_ROWS.size()):
		var row: Array = GUARD_ROWS[order]
		var offset := int(row[0])
		var end_offset := int(row[1])
		var false_offset := int(row[2])
		var record: Dictionary = decoder.decode_at_structural(code, offset, end_offset)
		if (
			not record.get("ok", false)
			or str(record.get("op", "")) != "branch_if_not_true"
			or int(record.get("end_offset", -1)) != end_offset
		):
			return _error("Station candidate guard %d boundary changed." % order)
		var operands: Array = record.get("operands", [])
		if operands.size() != 2 or int(operands[1].get("value", -1)) != false_offset:
			return _error("Station candidate guard %d false edge changed." % order)
		var ast: Dictionary = operands[0].get("value", {}).get("ast", {})
		var signature: Variant = _signature(ast)
		var expected_signature: Variant = _expected_guard_signature(order)
		if signature != expected_signature:
			return _error("Station candidate guard %d predicate changed." % order)
		var source_sha := ContractValues.sha256(code.slice(offset, end_offset))
		if require_original_hashes and source_sha != str(row[3]):
			return _error("Station candidate guard %d source bytes changed." % order)
		var references := _state_references(signature)
		for reference in references:
			observed_references[_reference_key(reference)] = true
		guards.append({
			"order": order,
			"offset": offset,
			"end_offset": end_offset,
			"true_offset": end_offset,
			"false_offset": false_offset,
			"sha256": source_sha,
			"predicate_signature": expected_signature,
			"state_references": references,
		})
		guard_asts.append(ast.duplicate(true))
	var observed_keys: Array = observed_references.keys()
	var expected_keys: Array = _expected_reference_keys()
	observed_keys.sort()
	expected_keys.sort()
	if observed_keys != expected_keys:
		return _error("Station candidate input coverage no longer matches every source read.")
	return {
		"ok": true,
		"guards": guards,
		"guard_asts": guard_asts,
		"required_input": _required_input_descriptor(),
	}


func _compose_plan(inspected: Dictionary, input: Dictionary, source: Dictionary) -> Dictionary:
	var evaluated := _evaluate(inspected.get("guard_asts", []), input)
	if not evaluated.get("ok", false):
		return evaluated
	var first_true := int(evaluated.first_true_order)
	var selected_boundary: Dictionary
	if first_true >= 0:
		var guard: Dictionary = inspected.guards[first_true]
		selected_boundary = {
			"kind": "stop_before_true_body",
			"guard_order": first_true,
			"guard_offset": int(guard.offset),
			"offset": int(guard.end_offset),
			"end_offset": int(guard.end_offset),
			"tool_execution": false,
			"true_body_interpretation": "unresolved",
		}
	else:
		selected_boundary = {
			"kind": "candidate_cascade_join",
			"offset": JOIN_OFFSET,
			"end_offset": JOIN_OFFSET,
			"next_plan_schema": Version.MES_EVENTB03_CANDIDATE_PLAN_SCHEMA,
			"delegated": false,
		}
	return {
		"ok": true,
		"schema": Version.MES_STATION_CANDIDATE_PRIORITY_PLAN_SCHEMA,
		"producer": {
			"core_version": Version.CORE_VERSION,
			"instruction_schema": Version.MES_INSTRUCTION_SCHEMA,
		},
		"source": source.duplicate(true),
		"required_input": inspected.required_input.duplicate(true),
		"input": input.duplicate(true),
		"guards": inspected.guards.duplicate(true),
		"evaluation": {
			"evaluated_guards": evaluated.evaluated_guards.duplicate(true),
			"first_true_order": first_true,
			"all_upstream_false": bool(evaluated.all_upstream_false),
		},
		"selected_boundary": selected_boundary,
		"execution": {
			"kind": "read_only_projection",
			"state_mutation": false,
			"frozen_state_preemption": "qualified",
			"true_body_execution": false,
			"terminal_resolution": false,
			"entry_zero_reachability": "unqualified",
			"natural_scheduler_eligibility": "unqualified",
			"native_address_row_selection": "unresolved",
			"native_cadence": "unresolved",
		},
	}


func _evaluate(guard_asts: Array, input_value: Variant) -> Dictionary:
	if guard_asts.size() != GUARD_ROWS.size():
		return _error("Station candidate evaluation requires all fifteen source guards.")
	var normalized := _normalize_input(input_value, false)
	if not normalized.get("ok", false):
		return normalized
	var state := StateScript.new(1)
	for index in STATE_U16_INDICES:
		state.write_value("state_u16", int(index), int(normalized.values.state_u16[str(index)]), 0)
	for index in BANKED_U16_INDICES:
		state.write_value("banked_u16", int(index), int(normalized.values.banked_u16_0[str(index)]), 0)
	for index in GLOBAL_U8_INDICES:
		state.write_value("global_u8", int(index), int(normalized.values.global_u8[str(index)]), 0)
	var before: Dictionary = state.snapshot()
	var outcomes: Array[Dictionary] = []
	for order in range(guard_asts.size()):
		var ast: Dictionary = guard_asts[order]
		if _signature(ast) != _expected_guard_signature(order):
			return _error("Station candidate evaluation guard %d changed." % order)
		var result: Dictionary = ExpressionScript.new().evaluate(ast, state)
		if (
			not result.get("ok", false)
			or int(result.get("value", -1)) not in [0, 1]
			or state.snapshot() != before
		):
			return _error("Station candidate guard %d evaluation failed or changed state." % order)
		var value := int(result.value)
		var row: Array = GUARD_ROWS[order]
		outcomes.append({
			"order": order,
			"offset": int(row[0]),
			"value": value,
			"next_offset": int(row[1]) if value == 1 else int(row[2]),
		})
		if value == 1:
			return {
				"ok": true,
				"evaluated_guards": outcomes,
				"first_true_order": order,
				"all_upstream_false": false,
			}
	return {
		"ok": true,
		"evaluated_guards": outcomes,
		"first_true_order": -1,
		"all_upstream_false": true,
	}


func _expected_guard_signature(order: int) -> Variant:
	if order == 0:
		return _left_and([
			["equal", ["add", _state_ref("banked_u16", 268), 1], _state_ref("state_u16", 7)],
			["greater_than", _state_ref("state_u16", 19), 930],
			["less_than", _state_ref("state_u16", 19), 1100],
			["equal", _state_ref("global_u8", 2300), 1],
			["equal", _state_ref("global_u8", 2304), 0],
			["equal", _state_ref("global_u8", 2305), 0],
			["equal", _state_ref("global_u8", 2301), 1],
		])
	if order >= 1 and order <= 12:
		var row: Array = GUARD_ROWS[order]
		return [
			"logical_or",
			_schedule_signature(int(row[4]), int(row[5]), int(row[6]), "equal"),
			_schedule_signature(int(row[4]), int(row[5]), int(row[6]), "greater_than"),
		]
	if order == 13:
		return _left_and([
			["not_equal", _state_ref("state_u16", 7), 1301],
			["greater_than", _state_ref("state_u16", 19), 1800],
			["less_than", _state_ref("state_u16", 19), 2100],
			["not_equal", _state_ref("state_u16", 7), 1301],
			["equal", _state_ref("global_u8", 160), 1],
			["equal", _state_ref("global_u8", 1750), 1],
			["equal", _state_ref("global_u8", 1751), 0],
		])
	if order == 14:
		return _left_and([
			["equal", _state_ref("state_u16", 4), 0],
			["greater_than", _state_ref("state_u16", 19), 1100],
			["less_than", _state_ref("state_u16", 19), 1700],
			["equal", _state_ref("global_u8", 110), 1],
			["equal", _state_ref("global_u8", 117), 0],
			["equal", _state_ref("global_u8", 1188), 1],
			["equal", _state_ref("global_u8", 1189), 0],
		])
	return null


func _schedule_signature(date_index: int, time_index: int, byte_base: int, time_operation: String) -> Variant:
	return _left_and([
		["equal", _state_ref("state_u16", 7), _state_ref("banked_u16", date_index)],
		["equal", _state_ref("global_u8", byte_base), 1],
		["equal", _state_ref("global_u8", byte_base + 7), 2],
		[time_operation, _state_ref("state_u16", 19), _state_ref("banked_u16", time_index)],
		["greater_than", _state_ref("global_u8", byte_base + 9), 8],
		["not_equal", _state_ref("global_u8", byte_base + 9), 14],
	])


func _left_and(conditions: Array) -> Variant:
	if conditions.is_empty():
		return null
	var result: Variant = conditions[0]
	for index in range(1, conditions.size()):
		result = ["logical_and", result, conditions[index]]
	return result


func _state_ref(storage: String, index: int) -> Array:
	return ["state_ref", storage, 0, index]


func _signature(ast: Dictionary, depth := 0) -> Variant:
	if depth > 32:
		return null
	match str(ast.get("type", "")):
		"literal":
			return ast.get("value")
		"state_ref":
			return [
				"state_ref",
				str(ast.get("storage", "")),
				int(ast.get("bank", -1)),
				_signature(ast.get("index", {}), depth + 1),
			]
		"binary":
			return [
				str(ast.get("op", "")),
				_signature(ast.get("lhs", {}), depth + 1),
				_signature(ast.get("rhs", {}), depth + 1),
			]
	return null


func _state_references(signature: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var seen := {}
	_collect_state_references(signature, result, seen)
	return result


func _collect_state_references(value: Variant, result: Array[Dictionary], seen: Dictionary) -> void:
	if not value is Array:
		return
	if value.size() == 4 and value[0] == "state_ref":
		var reference := {"storage": str(value[1]), "bank": int(value[2]), "index": int(value[3])}
		var key := _reference_key(reference)
		if not seen.has(key):
			seen[key] = true
			result.append(reference)
		return
	for child in value:
		_collect_state_references(child, result, seen)


func _reference_key(reference: Dictionary) -> String:
	return "%s:%d:%d" % [str(reference.storage), int(reference.bank), int(reference.index)]


func _expected_reference_keys() -> Array:
	var result: Array = []
	for index in STATE_U16_INDICES:
		result.append("state_u16:0:%d" % index)
	for index in BANKED_U16_INDICES:
		result.append("banked_u16:0:%d" % index)
	for index in GLOBAL_U8_INDICES:
		result.append("global_u8:0:%d" % index)
	return result


func _required_input_descriptor() -> Dictionary:
	return {
		"state_u16": STATE_U16_INDICES.duplicate(),
		"banked_u16_0": BANKED_U16_INDICES.duplicate(),
		"global_u8": GLOBAL_U8_INDICES.duplicate(),
		"total_unique_cells": STATE_U16_INDICES.size() + BANKED_U16_INDICES.size() + GLOBAL_U8_INDICES.size(),
	}


func _normalize_input(input_value: Variant, json_compatible: bool) -> Dictionary:
	if not input_value is Dictionary or input_value.size() != INPUT_GROUPS.size():
		return _error("Station candidate input requires the exact nested storage groups.")
	for key in input_value:
		if typeof(key) != TYPE_STRING or key not in INPUT_GROUPS:
			return _error("Station candidate input contains an unknown storage group.")
	var values := {}
	for group in INPUT_GROUPS:
		if not input_value.has(group) or not input_value[group] is Dictionary:
			return _error("Station candidate input is missing a storage dictionary.")
		var source_values: Dictionary = input_value[group]
		var indices: Array = _indices_for_group(group)
		if source_values.size() != indices.size():
			return _error("Station candidate input storage dictionary has the wrong size.")
		var normalized_group := {}
		for untyped_key in source_values:
			if typeof(untyped_key) != TYPE_STRING or not str(untyped_key).is_valid_int() or int(str(untyped_key)) not in indices:
				return _error("Station candidate input contains an unknown state index.")
		for index in indices:
			var key := str(index)
			if not source_values.has(key):
				return _error("Station candidate input is missing state index %s." % key)
			var value: Variant = source_values[key]
			if typeof(value) == TYPE_FLOAT and json_compatible:
				if not is_finite(float(value)) or float(value) != floor(float(value)):
					return _error("Station candidate input values must be exact integers.")
				value = int(value)
			if typeof(value) != TYPE_INT:
				return _error("Station candidate input values must be exact integers.")
			var maximum := 255 if group == "global_u8" else 65535
			if int(value) < 0 or int(value) > maximum:
				return _error("Station candidate input value is outside its source storage width.")
			normalized_group[key] = int(value)
		values[group] = normalized_group
	return {"ok": true, "values": values}


func _indices_for_group(group: String) -> Array:
	match group:
		"state_u16": return STATE_U16_INDICES
		"banked_u16_0": return BANKED_U16_INDICES
		"global_u8": return GLOBAL_U8_INDICES
	return []


func _original_entry_layout_matches(document: Dictionary) -> bool:
	var entries: Array = document.get("entries", [])
	if entries.size() != 426:
		return false
	for expected in [
		[0, 0x0008, 0x03AF],
		[59, 0x23DE, 0x733A],
		[60, 0x733A, 0x7377],
		[61, 0x7377, 0x74FD],
		[62, 0x74FD, 0x753A],
		[63, 0x753A, 0x75A1],
		[64, 0x75A1, 0x75DE],
		[65, 0x75DE, 0x7712],
	]:
		var entry: Dictionary = entries[int(expected[0])]
		if (
			int(entry.get("index", -1)) != int(expected[0])
			or int(entry.get("offset", -1)) != int(expected[1])
			or int(entry.get("end_offset", -1)) != int(expected[2])
		):
			return false
	return true


func _same_plan_value(actual: Variant, expected: Variant, depth := 0) -> bool:
	if depth > 32:
		return false
	if expected is Dictionary:
		if not actual is Dictionary or actual.size() != expected.size():
			return false
		for key in actual:
			if typeof(key) != TYPE_STRING or not expected.has(key) or not _same_plan_value(actual[key], expected[key], depth + 1):
				return false
		return true
	if expected is Array:
		if not actual is Array or actual.size() != expected.size():
			return false
		for index in range(expected.size()):
			if not _same_plan_value(actual[index], expected[index], depth + 1):
				return false
		return true
	if typeof(expected) == TYPE_INT:
		if typeof(actual) == TYPE_FLOAT:
			return is_finite(float(actual)) and float(actual) == floor(float(actual)) and float(actual) == float(expected)
		return typeof(actual) == TYPE_INT and actual == expected
	return typeof(actual) == typeof(expected) and actual == expected


func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message}
