class_name KakyuMesStationEventB03DecisionPlan
extends RefCounted

# Read-only composition of the station priority cascade and EVENTB03-local
# guard. Public plans are produced only through both existing source-bound
# child planners. The private synthetic boundary exercises those planners'
# frozen-state evaluators and is explicitly not source authority.
const Version := preload("res://content_core/content_core_version.gd")
const PriorityPlanScript := preload("res://content_core/mes_station_candidate_priority_plan.gd")
const CandidatePlanScript := preload("res://content_core/mes_eventb03_candidate_plan.gd")
const ContractValues := preload("res://content_core/contract_values.gd")

const SOURCE_SHA256 := "a50511b0ad0ad446b7988c3cfb36736424bf6617e9eb952e20b505f745607cc5"
const SOURCE_BYTECODE_SHA256 := "f590b3007ea98dcce6f10bc85eb316abdf250f6417a87cec4ab0a6d98ed2230b"
const PRIORITY_OFFSET := 0x026D
const EVENTB03_GUARD_OFFSET := 0x7691
const EVENTB03_TRUE_OFFSET := 0x76F1
const EVENTB03_HANDOFF_OFFSET := 0x788F
const EVENTB03_HANDOFF_END := 0x789F
const EVENTB03_FALSE_OFFSET := 0x78A9
const EVENTB03_HANDOFF_SHA256 := "31be24c8ca3ec0e0613e2bced44ff4d9edcf70e7f4c4bfc821e2c4a407b6fde4"

const INPUT_GROUPS := ["state_u16", "banked_u16_0", "global_u8"]
const STATE_U16_INDICES := [4, 7, 12, 19]
const BANKED_U16_INDICES := [
	210, 213, 214, 215, 216, 217, 218, 219, 220, 221, 222,
	225, 226, 227, 228, 229, 230, 231, 232, 233, 234, 235,
	236, 237, 238, 268,
]
const GLOBAL_U8_INDICES := [
	100, 107, 109, 110, 117, 119, 120, 127, 129, 130, 137,
	139, 140, 147, 149, 160, 167, 169, 170, 177, 179, 180,
	187, 189, 190, 197, 199, 200, 205, 207, 209, 210, 217,
	219, 220, 227, 229, 333, 400, 628, 631, 1188, 1189, 1750,
	1751, 2300, 2301, 2304, 2305,
]
const PRIORITY_STATE_U16_INDICES := [4, 7, 19]
const PRIORITY_BANKED_U16_INDICES := [
	213, 214, 215, 216, 217, 218, 219, 220, 221, 222,
	225, 226, 227, 228, 229, 230, 231, 232, 233, 234,
	235, 236, 237, 238, 268,
]
const PRIORITY_GLOBAL_U8_INDICES := [
	100, 107, 109, 110, 117, 119, 120, 127, 129, 130, 137,
	139, 140, 147, 149, 160, 167, 169, 170, 177, 179, 180,
	187, 189, 190, 197, 199, 200, 207, 209, 210, 217, 219,
	220, 227, 229, 1188, 1189, 1750, 1751, 2300, 2301, 2304,
	2305,
]
const EVENTB03_INPUT_BINDINGS := [
	["state_u16_7", "state_u16", 7],
	["state_u16_19", "state_u16", 19],
	["banked_u16_210", "banked_u16_0", 210],
	["global_u8_207", "global_u8", 207],
	["global_u8_333", "global_u8", 333],
	["global_u8_200", "global_u8", 200],
	["global_u8_400", "global_u8", 400],
	["global_u8_205", "global_u8", 205],
	["global_u8_631", "global_u8", 631],
	["state_u16_12", "state_u16", 12],
	["global_u8_628", "global_u8", 628],
]

# offset, true-body offset, false destination. These rows validate child
# evaluation receipts; source structure remains owned by the child planner.
const PRIORITY_GUARD_ROWS := [
	[0x026D, 0x02A3, 0x247E], [0x247E, 0x24D7, 0x2AF7],
	[0x2AF7, 0x2B50, 0x3170], [0x3170, 0x31C9, 0x37E9],
	[0x37E9, 0x3842, 0x3E62], [0x3E62, 0x3EBB, 0x44DB],
	[0x44DB, 0x4534, 0x4B54], [0x4B54, 0x4BAD, 0x51CD],
	[0x51CD, 0x5226, 0x5846], [0x5846, 0x589F, 0x5EBF],
	[0x5EBF, 0x5F18, 0x6538], [0x6538, 0x6591, 0x6BB1],
	[0x6BB1, 0x6C0A, 0x722A], [0x722A, 0x725D, 0x73F5],
	[0x73F5, 0x7425, 0x7691],
]


func build(source_payload: PackedByteArray, input_value: Variant) -> Dictionary:
	var normalized := _normalize_input(input_value, false)
	if not normalized.get("ok", false):
		return normalized
	var priority_input := _priority_input(normalized.values)
	var priority_planner := PriorityPlanScript.new()
	var priority_plan: Dictionary = priority_planner.build(source_payload, priority_input)
	if not priority_plan.get("ok", false):
		return _error("Station priority child plan failed: %s" % priority_plan.get("error", "unknown error"))
	if not priority_planner.validate(source_payload, priority_plan).get("ok", false):
		return _error("Station priority child plan failed deterministic source validation.")
	var priority_result := _priority_result_from_plan(priority_plan, priority_input)
	if not priority_result.get("ok", false):
		return priority_result

	var candidate_result: Variant = null
	var candidate_plan_hash := "not_computed"
	if bool(priority_result.all_upstream_false):
		var candidate_input := _candidate_input(normalized.values)
		var candidate_planner := CandidatePlanScript.new()
		var candidate_plan: Dictionary = candidate_planner.build(source_payload, candidate_input)
		if not candidate_plan.get("ok", false):
			return _error("EVENTB03 child plan failed: %s" % candidate_plan.get("error", "unknown error"))
		if not candidate_planner.validate(source_payload, candidate_plan).get("ok", false):
			return _error("EVENTB03 child plan failed deterministic source validation.")
		candidate_result = _candidate_result_from_plan(candidate_plan, candidate_input)
		if not candidate_result.get("ok", false):
			return candidate_result
		candidate_plan_hash = _value_sha256(candidate_plan)

	return _compose_plan(
		normalized.values,
		priority_result,
		candidate_result,
		_value_sha256(priority_plan),
		candidate_plan_hash,
		true,
		{
			"archive": "mes.arc",
			"entry": "01M.MES",
			"entry_sha256": SOURCE_SHA256,
			"bytecode_sha256": SOURCE_BYTECODE_SHA256,
			"offset_basis": "code_start",
			"priority_offset": PRIORITY_OFFSET,
			"priority_join_offset": EVENTB03_GUARD_OFFSET,
			"eventb03_guard_offset": EVENTB03_GUARD_OFFSET,
			"child_structural_authority": "source_bound_child_validation",
		}
	)


func validate(source_payload: PackedByteArray, plan: Dictionary) -> Dictionary:
	var normalized := _normalize_input(plan.get("input", null), true)
	if not normalized.get("ok", false):
		return _error("Station EVENTB03 decision plan input is malformed.")
	var rebuilt := build(source_payload, normalized.values)
	if not rebuilt.get("ok", false):
		return rebuilt
	if not _same_plan_value(plan, rebuilt):
		return _error("Station EVENTB03 decision plan no longer matches its source-bound projection.")
	return {"ok": true}


# Test-only evaluator boundary. It invokes the two existing child evaluators
# against canonical predicate ASTs and cannot produce source-bound authority.
func _evaluate_child_results_for_test(input_value: Variant) -> Dictionary:
	var normalized := _normalize_input(input_value, false)
	if not normalized.get("ok", false):
		return normalized
	return _evaluate_child_results(normalized.values)


# Test-only composition boundary. The supplied results must exactly equal a
# fresh child-evaluator replay for the same frozen snapshot.
func _build_from_child_results_for_test(input_value: Variant, child_results: Variant) -> Dictionary:
	var normalized := _normalize_input(input_value, false)
	if not normalized.get("ok", false):
		return normalized
	var expected := _evaluate_child_results(normalized.values)
	if not expected.get("ok", false):
		return expected
	if not _same_plan_value(child_results, expected):
		return _error("Synthetic child results do not match the strict frozen-state evaluator replay.")
	var candidate_result: Variant = expected.eventb03
	return _compose_plan(
		normalized.values,
		expected.priority,
		candidate_result,
		_value_sha256(expected.priority),
		"not_computed" if candidate_result == null else _value_sha256(candidate_result),
		false,
		{
			"archive": "synthetic_fixture",
			"entry": "01M.MES-evaluation-only",
			"entry_sha256": "not_applicable",
			"bytecode_sha256": "not_applicable",
			"offset_basis": "code_start",
			"priority_offset": PRIORITY_OFFSET,
			"priority_join_offset": EVENTB03_GUARD_OFFSET,
			"eventb03_guard_offset": EVENTB03_GUARD_OFFSET,
			"child_structural_authority": "synthetic_child_evaluators_only",
		}
	)


func _validate_from_child_results_for_test(input_value: Variant, child_results: Variant, plan: Dictionary) -> Dictionary:
	var rebuilt := _build_from_child_results_for_test(input_value, child_results)
	if not rebuilt.get("ok", false):
		return rebuilt
	if not _same_plan_value(plan, rebuilt):
		return _error("Synthetic station EVENTB03 decision plan changed.")
	return {"ok": true}


func _evaluate_child_results(input: Dictionary) -> Dictionary:
	var priority_planner := PriorityPlanScript.new()
	var guard_asts: Array[Dictionary] = []
	for order in range(PRIORITY_GUARD_ROWS.size()):
		var signature: Variant = priority_planner.call("_expected_guard_signature", order)
		var ast := _ast_from_signature(signature)
		if ast.is_empty():
			return _error("Synthetic priority predicate construction failed.")
		guard_asts.append(ast)
	var priority_result: Dictionary = priority_planner.call("_evaluate", guard_asts, _priority_input(input))
	if not _validate_priority_result(priority_result):
		return _error("Synthetic station priority child evaluation failed closed.")
	var candidate_result: Variant = null
	if bool(priority_result.all_upstream_false):
		var candidate_planner := CandidatePlanScript.new()
		var candidate_ast := _ast_from_signature(candidate_planner.call("_expected_guard_signature"))
		if candidate_ast.is_empty():
			return _error("Synthetic EVENTB03 predicate construction failed.")
		candidate_result = candidate_planner.call("_evaluate", candidate_ast, _candidate_input(input))
		if not _validate_candidate_result(candidate_result):
			return _error("Synthetic EVENTB03 child evaluation failed closed.")
	return {"ok": true, "priority": priority_result, "eventb03": candidate_result}


func _priority_result_from_plan(plan: Dictionary, expected_input: Dictionary) -> Dictionary:
	if (
		str(plan.get("schema", "")) != Version.MES_STATION_CANDIDATE_PRIORITY_PLAN_SCHEMA
		or not _same_plan_value(plan.get("input", null), expected_input)
		or not plan.get("execution", {}) is Dictionary
		or bool(plan.execution.get("state_mutation", true))
		or bool(plan.execution.get("true_body_execution", true))
	):
		return _error("Station priority child contract changed.")
	var evaluation: Variant = plan.get("evaluation", null)
	if not evaluation is Dictionary or not _has_exact_keys(evaluation, ["evaluated_guards", "first_true_order", "all_upstream_false"]):
		return _error("Station priority child evaluation receipt changed.")
	var result := {
		"ok": true,
		"evaluated_guards": evaluation.evaluated_guards.duplicate(true),
		"first_true_order": int(evaluation.first_true_order),
		"all_upstream_false": bool(evaluation.all_upstream_false),
	}
	if not _validate_priority_result(result):
		return _error("Station priority child evaluation receipt is inconsistent.")
	if not _same_plan_value(plan.get("selected_boundary", null), _priority_boundary(result)):
		return _error("Station priority child selected boundary changed.")
	return result


func _candidate_result_from_plan(plan: Dictionary, expected_input: Dictionary) -> Dictionary:
	if (
		str(plan.get("schema", "")) != Version.MES_EVENTB03_CANDIDATE_PLAN_SCHEMA
		or not _same_plan_value(plan.get("input", null), expected_input)
		or not plan.get("execution", {}) is Dictionary
		or bool(plan.execution.get("state_mutation", true))
		or bool(plan.execution.get("post_handoff_tool_execution", true))
	):
		return _error("EVENTB03 child contract changed.")
	var candidate: Variant = plan.get("candidate", null)
	if not candidate is Dictionary or not _has_exact_keys(candidate, ["matched", "value", "next_offset"]):
		return _error("EVENTB03 child candidate receipt changed.")
	var result := {
		"ok": true,
		"value": candidate.value,
		"candidate": candidate.matched,
	}
	if not _validate_candidate_result(result):
		return _error("EVENTB03 child candidate result is inconsistent.")
	if int(candidate.next_offset) != (EVENTB03_TRUE_OFFSET if bool(result.candidate) else EVENTB03_FALSE_OFFSET):
		return _error("EVENTB03 child next boundary changed.")
	if not _same_plan_value(plan.get("selected_boundary", null), _candidate_boundary(result)):
		return _error("EVENTB03 child selected boundary changed.")
	return result


func _compose_plan(
	input: Dictionary,
	priority_result: Dictionary,
	candidate_result: Variant,
	priority_plan_hash: String,
	candidate_plan_hash: String,
	source_bound_children: bool,
	source: Dictionary
) -> Dictionary:
	if not _validate_priority_result(priority_result):
		return _error("Station priority result failed composition validation.")
	if bool(priority_result.all_upstream_false):
		if not _validate_candidate_result(candidate_result):
			return _error("EVENTB03 result is required after an all-false priority cascade.")
	elif candidate_result != null:
		return _error("EVENTB03 result must remain absent after priority preemption.")
	if not _is_digest(priority_plan_hash):
		return _error("Station priority child fingerprint is malformed.")
	if candidate_result != null and not _is_digest(candidate_plan_hash):
		return _error("EVENTB03 child fingerprint is malformed.")

	var priority_input := _priority_input(input)
	var candidate_input := _candidate_input(input)
	var priority_boundary := _priority_boundary(priority_result)
	var priority_receipt := {
		"schema": Version.MES_STATION_CANDIDATE_PRIORITY_PLAN_SCHEMA,
		"source_bound": source_bound_children,
		"plan_sha256": priority_plan_hash,
		"input_sha256": _value_sha256(priority_input),
		"evaluated_guard_count": priority_result.evaluated_guards.size(),
		"first_true_order": int(priority_result.first_true_order),
		"all_upstream_false": bool(priority_result.all_upstream_false),
		"selected_boundary": priority_boundary,
	}
	var eventb03_receipt: Dictionary
	var outcome: String
	var selected_boundary: Dictionary
	if not bool(priority_result.all_upstream_false):
		outcome = "eventb03_preempted_by_upstream_guard"
		selected_boundary = priority_boundary
		eventb03_receipt = {
			"schema": Version.MES_EVENTB03_CANDIDATE_PLAN_SCHEMA,
			"status": "not_evaluated",
			"reason": "eventb03_preempted_by_upstream_guard",
			"source_bound": false,
			"plan_sha256": "not_computed",
			"input_sha256": _value_sha256(candidate_input),
		}
	else:
		var matched := bool(candidate_result.candidate)
		outcome = "eventb03_guard_matched" if matched else "eventb03_guard_rejected"
		selected_boundary = _candidate_boundary(candidate_result)
		eventb03_receipt = {
			"schema": Version.MES_EVENTB03_CANDIDATE_PLAN_SCHEMA,
			"status": "evaluated",
			"source_bound": source_bound_children,
			"plan_sha256": candidate_plan_hash,
			"input_sha256": _value_sha256(candidate_input),
			"matched": matched,
			"value": int(candidate_result.value),
			"selected_boundary": selected_boundary,
		}
	return {
		"ok": true,
		"schema": Version.MES_STATION_EVENTB03_DECISION_PLAN_SCHEMA,
		"producer": {
			"core_version": Version.CORE_VERSION,
			"priority_plan_schema": Version.MES_STATION_CANDIDATE_PRIORITY_PLAN_SCHEMA,
			"eventb03_plan_schema": Version.MES_EVENTB03_CANDIDATE_PLAN_SCHEMA,
		},
		"source": source.duplicate(true),
		"required_input": _required_input_descriptor(),
		"input": input.duplicate(true),
		"children": {"priority": priority_receipt, "eventb03": eventb03_receipt},
		"decision": {
			"outcome": outcome,
			"priority_first_true_order": int(priority_result.first_true_order),
			"eventb03_evaluated": bool(priority_result.all_upstream_false),
			"selected_boundary": selected_boundary,
		},
		"execution": {
			"kind": "read_only_frozen_state_decision",
			"state_mutation": false,
			"frozen_state_preemption": "qualified",
			"priority_body_execution": false,
			"eventb03_body_execution": false,
			"script_handoff_execution": false,
			"prefix_completion": "unresolved",
			"host_zero_start": "unresolved",
			"native_address_row_selection": "unresolved",
			"natural_scheduler_eligibility": "unqualified",
			"native_cadence": "unresolved",
			"product_preset_widening": false,
		},
	}


func _validate_priority_result(value: Variant) -> bool:
	if not value is Dictionary or not _has_exact_keys(value, ["ok", "evaluated_guards", "first_true_order", "all_upstream_false"]):
		return false
	if value.get("ok") != true or typeof(value.get("first_true_order")) != TYPE_INT or typeof(value.get("all_upstream_false")) != TYPE_BOOL:
		return false
	var outcomes: Variant = value.get("evaluated_guards")
	if not outcomes is Array or outcomes.is_empty() or outcomes.size() > PRIORITY_GUARD_ROWS.size():
		return false
	var found_true := -1
	for order in range(outcomes.size()):
		var outcome: Variant = outcomes[order]
		if not outcome is Dictionary or not _has_exact_keys(outcome, ["order", "offset", "value", "next_offset"]):
			return false
		for key in ["order", "offset", "value", "next_offset"]:
			if typeof(outcome.get(key)) != TYPE_INT:
				return false
		var row: Array = PRIORITY_GUARD_ROWS[order]
		if int(outcome.order) != order or int(outcome.offset) != int(row[0]) or int(outcome.value) not in [0, 1]:
			return false
		var expected_next := int(row[1]) if int(outcome.value) == 1 else int(row[2])
		if int(outcome.next_offset) != expected_next:
			return false
		if int(outcome.value) == 1:
			if found_true >= 0 or order != outcomes.size() - 1:
				return false
			found_true = order
	var first_true := int(value.first_true_order)
	var all_false := bool(value.all_upstream_false)
	if found_true >= 0:
		return first_true == found_true and not all_false and outcomes.size() == found_true + 1
	return first_true == -1 and all_false and outcomes.size() == PRIORITY_GUARD_ROWS.size()


func _validate_candidate_result(value: Variant) -> bool:
	return (
		value is Dictionary
		and _has_exact_keys(value, ["ok", "value", "candidate"])
		and value.get("ok") == true
		and typeof(value.get("value")) == TYPE_INT
		and int(value.value) in [0, 1]
		and typeof(value.get("candidate")) == TYPE_BOOL
		and bool(value.candidate) == (int(value.value) == 1)
	)


func _priority_boundary(result: Dictionary) -> Dictionary:
	var order := int(result.first_true_order)
	if order < 0:
		return {
			"kind": "candidate_cascade_join",
			"offset": EVENTB03_GUARD_OFFSET,
			"end_offset": EVENTB03_GUARD_OFFSET,
			"next_plan_schema": Version.MES_EVENTB03_CANDIDATE_PLAN_SCHEMA,
			"delegated": false,
		}
	var row: Array = PRIORITY_GUARD_ROWS[order]
	return {
		"kind": "stop_before_true_body",
		"guard_order": order,
		"guard_offset": int(row[0]),
		"offset": int(row[1]),
		"end_offset": int(row[1]),
		"tool_execution": false,
		"true_body_interpretation": "unresolved",
	}


func _candidate_boundary(result: Dictionary) -> Dictionary:
	if bool(result.candidate):
		return {
			"kind": "script_handoff_boundary",
			"offset": EVENTB03_HANDOFF_OFFSET,
			"end_offset": EVENTB03_HANDOFF_END,
			"command": 0x0E,
			"target_entry": "EVENTB03.MES",
			"target_start_coordinate": "not_encoded",
			"caller_frame": "not_encoded",
			"sha256": EVENTB03_HANDOFF_SHA256,
		}
	return {"kind": "candidate_false_boundary", "offset": EVENTB03_FALSE_OFFSET, "end_offset": EVENTB03_FALSE_OFFSET}


func _priority_input(input: Dictionary) -> Dictionary:
	return {
		"state_u16": _subset(input.state_u16, PRIORITY_STATE_U16_INDICES),
		"banked_u16_0": _subset(input.banked_u16_0, PRIORITY_BANKED_U16_INDICES),
		"global_u8": _subset(input.global_u8, PRIORITY_GLOBAL_U8_INDICES),
	}


func _candidate_input(input: Dictionary) -> Dictionary:
	var result := {}
	for binding in EVENTB03_INPUT_BINDINGS:
		result[str(binding[0])] = int(input[str(binding[1])][str(binding[2])])
	return result


func _subset(source: Dictionary, indices: Array) -> Dictionary:
	var result := {}
	for index in indices:
		result[str(index)] = int(source[str(index)])
	return result


func _required_input_descriptor() -> Dictionary:
	return {
		"state_u16": STATE_U16_INDICES.duplicate(),
		"banked_u16_0": BANKED_U16_INDICES.duplicate(),
		"global_u8": GLOBAL_U8_INDICES.duplicate(),
		"priority_unique_cells": 72,
		"eventb03_unique_cells": 11,
		"overlap_unique_cells": 4,
		"total_unique_cells": 79,
		"overlap": [
			{"storage": "state_u16", "index": 7},
			{"storage": "state_u16", "index": 19},
			{"storage": "global_u8", "index": 200},
			{"storage": "global_u8", "index": 207},
		],
	}


func _normalize_input(input_value: Variant, json_compatible: bool) -> Dictionary:
	if not input_value is Dictionary or input_value.size() != INPUT_GROUPS.size():
		return _error("Station EVENTB03 input requires the exact nested storage groups.")
	for key in input_value:
		if typeof(key) != TYPE_STRING or key not in INPUT_GROUPS:
			return _error("Station EVENTB03 input contains an unknown storage group.")
	var values := {}
	for group in INPUT_GROUPS:
		if not input_value.has(group) or not input_value[group] is Dictionary:
			return _error("Station EVENTB03 input is missing a storage dictionary.")
		var source: Dictionary = input_value[group]
		var indices := _indices_for_group(group)
		if source.size() != indices.size():
			return _error("Station EVENTB03 input storage dictionary has the wrong size.")
		var normalized_group := {}
		for untyped_key in source:
			if typeof(untyped_key) != TYPE_STRING or not str(untyped_key).is_valid_int() or int(str(untyped_key)) not in indices:
				return _error("Station EVENTB03 input contains an unknown state index.")
		for index in indices:
			var key := str(index)
			if not source.has(key):
				return _error("Station EVENTB03 input is missing state index %s." % key)
			var value: Variant = source[key]
			if typeof(value) == TYPE_FLOAT and json_compatible:
				if not is_finite(float(value)) or float(value) != floor(float(value)):
					return _error("Station EVENTB03 input values must be exact integers.")
				value = int(value)
			if typeof(value) != TYPE_INT:
				return _error("Station EVENTB03 input values must be exact integers.")
			var maximum := 255 if group == "global_u8" else 65535
			if int(value) < 0 or int(value) > maximum:
				return _error("Station EVENTB03 input value is outside its source storage width.")
			normalized_group[key] = int(value)
		values[group] = normalized_group
	return {"ok": true, "values": values}


func _indices_for_group(group: String) -> Array:
	match group:
		"state_u16": return STATE_U16_INDICES
		"banked_u16_0": return BANKED_U16_INDICES
		"global_u8": return GLOBAL_U8_INDICES
	return []


func _ast_from_signature(signature: Variant, depth := 0) -> Dictionary:
	if depth > 32:
		return {}
	if typeof(signature) == TYPE_INT:
		return {"type": "literal", "value": int(signature)}
	if not signature is Array:
		return {}
	if signature.size() == 4 and signature[0] == "state_ref":
		var index := _ast_from_signature(signature[3], depth + 1)
		if index.is_empty():
			return {}
		return {"type": "state_ref", "storage": str(signature[1]), "bank": int(signature[2]), "index": index}
	if signature.size() == 3:
		var lhs := _ast_from_signature(signature[1], depth + 1)
		var rhs := _ast_from_signature(signature[2], depth + 1)
		if lhs.is_empty() or rhs.is_empty():
			return {}
		return {"type": "binary", "op": str(signature[0]), "lhs": lhs, "rhs": rhs}
	return {}


func _has_exact_keys(value: Dictionary, expected: Array) -> bool:
	if value.size() != expected.size():
		return false
	for key in value:
		if typeof(key) != TYPE_STRING or key not in expected:
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


func _value_sha256(value: Variant) -> String:
	return ContractValues.sha256(JSON.stringify(value, "", true, true).to_utf8_buffer())


func _is_digest(value: String) -> bool:
	if value.length() != 64:
		return false
	for index in range(value.length()):
		var code: int = value.unicode_at(index)
		if not (code >= 48 and code <= 57) and not (code >= 97 and code <= 102):
			return false
	return true


func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message}
