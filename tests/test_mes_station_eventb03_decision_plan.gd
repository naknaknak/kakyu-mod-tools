extends Node

const PlanScript := preload("res://content_core/mes_station_eventb03_decision_plan.gd")
const Version := preload("res://content_core/content_core_version.gd")

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
const PRIORITY_ROWS := [
	[0x026D, 0x02A3, 0x247E], [0x247E, 0x24D7, 0x2AF7],
	[0x2AF7, 0x2B50, 0x3170], [0x3170, 0x31C9, 0x37E9],
	[0x37E9, 0x3842, 0x3E62], [0x3E62, 0x3EBB, 0x44DB],
	[0x44DB, 0x4534, 0x4B54], [0x4B54, 0x4BAD, 0x51CD],
	[0x51CD, 0x5226, 0x5846], [0x5846, 0x589F, 0x5EBF],
	[0x5EBF, 0x5F18, 0x6538], [0x6538, 0x6591, 0x6BB1],
	[0x6BB1, 0x6C0A, 0x722A], [0x722A, 0x725D, 0x73F5],
	[0x73F5, 0x7425, 0x7691],
]
const SCHEDULE_ROWS := [
	[213, 214, 100], [215, 216, 110], [217, 218, 120],
	[219, 220, 130], [221, 222, 140], [225, 226, 160],
	[227, 228, 170], [229, 230, 180], [231, 232, 190],
	[233, 234, 200], [235, 236, 210], [237, 238, 220],
]
const B03_FALSE_CASES := [
	["state_u16", 7, 400], ["state_u16", 7, 616],
	["state_u16", 19, 1800], ["state_u16", 19, 2001],
	["banked_u16_0", 210, 40], ["banked_u16_0", 210, 80],
	["global_u8", 207, 2], ["global_u8", 333, 1],
	["global_u8", 200, 1], ["global_u8", 400, 0],
	["global_u8", 205, 1], ["global_u8", 631, 1],
	["state_u16", 12, 0], ["global_u8", 628, 1],
]

var _checks := 0
var _failed := false


func _ready() -> void:
	var planner := PlanScript.new()
	_test_union_and_matched_contract(planner)
	_test_priority_preemption(planner)
	_test_eventb03_false_classes(planner)
	_test_input_contract(planner)
	_test_child_result_fail_closed(planner)
	_test_plan_validation(planner)
	_test_public_source_boundary(planner)
	print("Station EVENTB03 decision plan synthetic checks: ", _checks)
	await get_tree().process_frame
	get_tree().quit(1 if _failed else 0)


func _test_union_and_matched_contract(planner: RefCounted) -> void:
	var input := _baseline_input()
	var input_before := input.duplicate(true)
	var results: Dictionary = planner.call("_evaluate_child_results_for_test", input)
	_check(results.get("ok", false), "child evaluators accept the exact 79-cell true witness")
	_check(results.priority.all_upstream_false and results.priority.first_true_order == -1 and results.priority.evaluated_guards.size() == 15, "all fifteen priority guards are false before EVENTB03 evaluation")
	_check(results.eventb03 == {"ok": true, "value": 1, "candidate": true}, "EVENTB03 exact guard evaluates true")
	var plan: Dictionary = planner.call("_build_from_child_results_for_test", input, results)
	_check(plan.get("ok", false), "matched child results compose")
	if not plan.get("ok", false):
		return
	_check(plan.keys() == ["ok", "schema", "producer", "source", "required_input", "input", "children", "decision", "execution"], "decision plan exposes only its documented root shape")
	_check(plan.schema == Version.MES_STATION_EVENTB03_DECISION_PLAN_SCHEMA, "decision schema comes from Content Core version contract")
	_check(plan.producer == {"core_version": Version.CORE_VERSION, "priority_plan_schema": Version.MES_STATION_CANDIDATE_PRIORITY_PLAN_SCHEMA, "eventb03_plan_schema": Version.MES_EVENTB03_CANDIDATE_PLAN_SCHEMA}, "producer binds both child schemas")
	_check(plan.source.child_structural_authority == "synthetic_child_evaluators_only" and plan.source.priority_offset == 0x026D and plan.source.priority_join_offset == 0x7691, "synthetic output cannot claim source structural authority")
	_check(plan.required_input.state_u16 == STATE_U16_INDICES and plan.required_input.banked_u16_0 == BANKED_U16_INDICES and plan.required_input.global_u8 == GLOBAL_U8_INDICES, "required input exposes the exact nested union")
	_check(plan.required_input.priority_unique_cells == 72 and plan.required_input.eventb03_unique_cells == 11 and plan.required_input.overlap_unique_cells == 4 and plan.required_input.total_unique_cells == 79, "72 plus 11 child cells collapse to 79 unique cells with four overlaps")
	_check(plan.required_input.overlap == [{"storage": "state_u16", "index": 7}, {"storage": "state_u16", "index": 19}, {"storage": "global_u8", "index": 200}, {"storage": "global_u8", "index": 207}], "overlap ledger names the exact shared cells")
	_check(plan.input == input and input == input_before, "the single frozen snapshot is copied without mutation")
	_check(plan.children.priority.evaluated_guard_count == 15 and plan.children.priority.all_upstream_false and not plan.children.priority.source_bound, "priority child receipt retains the complete all-false result")
	_check(plan.children.eventb03.status == "evaluated" and plan.children.eventb03.matched and plan.children.eventb03.value == 1 and not plan.children.eventb03.source_bound, "EVENTB03 child receipt is evaluated but synthetic-only")
	_check(plan.decision.outcome == "eventb03_guard_matched" and plan.decision.priority_first_true_order == -1 and plan.decision.eventb03_evaluated, "matched decision follows only after all upstream guards fail")
	_check(plan.decision.selected_boundary.kind == "script_handoff_boundary" and plan.decision.selected_boundary.offset == 0x788F and plan.decision.selected_boundary.target_entry == "EVENTB03.MES", "matched result stops at the child handoff boundary")
	_check(_is_digest(plan.children.priority.plan_sha256) and _is_digest(plan.children.eventb03.plan_sha256) and _is_digest(plan.children.priority.input_sha256) and _is_digest(plan.children.eventb03.input_sha256), "child results and projections are fingerprinted without payloads")
	_check(not _contains_payload(plan), "decision plan contains no source byte payload or expression AST")


func _test_priority_preemption(planner: RefCounted) -> void:
	for order in range(PRIORITY_ROWS.size()):
		var input := _baseline_input()
		_enable_priority_guard(input, order)
		var before := input.duplicate(true)
		var results: Dictionary = planner.call("_evaluate_child_results_for_test", input)
		_check(results.get("ok", false) and results.priority.first_true_order == order and results.priority.evaluated_guards.size() == order + 1, "priority guard %d wins at its first source position" % order)
		_check(results.eventb03 == null, "priority guard %d leaves EVENTB03 unevaluated" % order)
		var plan: Dictionary = planner.call("_build_from_child_results_for_test", input, results)
		_check(plan.get("ok", false) and plan.decision.outcome == "eventb03_preempted_by_upstream_guard" and not plan.decision.eventb03_evaluated, "priority guard %d records an upstream guard preemption" % order)
		_check(plan.children.eventb03.status == "not_evaluated" and plan.children.eventb03.reason == "eventb03_preempted_by_upstream_guard" and not plan.children.eventb03.source_bound and plan.children.eventb03.plan_sha256 == "not_computed", "priority guard %d cannot promote an EVENTB03 child result" % order)
		_check(plan.decision.selected_boundary.guard_order == order and plan.decision.selected_boundary.offset == PRIORITY_ROWS[order][1] and not plan.decision.selected_boundary.tool_execution, "priority guard %d stops before its true body" % order)
		_check(input == before, "priority guard %d decision preserves input" % order)
	var multiple := _baseline_input()
	_enable_priority_guard(multiple, 12)
	_enable_priority_guard(multiple, 1)
	var earliest: Dictionary = planner.call("_evaluate_child_results_for_test", multiple)
	_check(earliest.get("ok", false) and earliest.priority.first_true_order == 1 and earliest.priority.evaluated_guards.size() == 2 and earliest.eventb03 == null, "multiple matches select the earliest source-order priority guard")


func _test_eventb03_false_classes(planner: RefCounted) -> void:
	for case_index in range(B03_FALSE_CASES.size()):
		var row: Array = B03_FALSE_CASES[case_index]
		var input := _baseline_input()
		input[str(row[0])][str(row[1])] = int(row[2])
		var before := input.duplicate(true)
		var results: Dictionary = planner.call("_evaluate_child_results_for_test", input)
		_check(results.get("ok", false) and results.priority.all_upstream_false, "EVENTB03 false class %d remains downstream of an all-false priority cascade" % case_index)
		_check(results.eventb03 == {"ok": true, "value": 0, "candidate": false}, "EVENTB03 false class %d rejects the local candidate" % case_index)
		var plan: Dictionary = planner.call("_build_from_child_results_for_test", input, results)
		_check(plan.get("ok", false) and plan.decision.outcome == "eventb03_guard_rejected" and plan.decision.eventb03_evaluated, "EVENTB03 false class %d records the rejected guard" % case_index)
		_check(plan.decision.selected_boundary == {"kind": "candidate_false_boundary", "offset": 0x78A9, "end_offset": 0x78A9}, "EVENTB03 false class %d stops at the exact false boundary" % case_index)
		_check(not plan.execution.eventb03_body_execution and not plan.execution.script_handoff_execution and input == before, "EVENTB03 false class %d executes nothing and preserves input" % case_index)


func _test_input_contract(planner: RefCounted) -> void:
	var baseline := _baseline_input()
	var mutations := [
		{"label": "missing group", "erase_group": "global_u8"},
		{"label": "extra group", "add_group": ["other", {}]},
		{"label": "numeric group", "erase_group": "global_u8", "add_group": [7, {}]},
		{"label": "missing cell", "group": "state_u16", "erase": "12"},
		{"label": "extra cell", "group": "global_u8", "set": ["999", 0]},
		{"label": "numeric cell", "group": "global_u8", "erase": "628", "set": [628, 0]},
		{"label": "direct float", "group": "state_u16", "set": ["7", 413.0]},
		{"label": "fraction", "group": "state_u16", "set": ["7", 413.5]},
		{"label": "boolean", "group": "global_u8", "set": ["207", false]},
		{"label": "string", "group": "banked_u16_0", "set": ["210", "50"]},
		{"label": "negative", "group": "state_u16", "set": ["12", -1]},
		{"label": "wide u16", "group": "banked_u16_0", "set": ["210", 65536]},
		{"label": "wide u8", "group": "global_u8", "set": ["628", 256]},
	]
	for mutation in mutations:
		var changed: Dictionary = baseline.duplicate(true)
		if mutation.has("erase_group"): changed.erase(mutation.erase_group)
		if mutation.has("add_group"): changed[mutation.add_group[0]] = mutation.add_group[1]
		if mutation.has("group"):
			var group: Dictionary = changed[mutation.group]
			if mutation.has("erase"): group.erase(mutation.erase)
			if mutation.has("set"): group[mutation.set[0]] = mutation.set[1]
		var before := changed.duplicate(true)
		_check(not planner.call("_evaluate_child_results_for_test", changed).get("ok", true) and _same_special(changed, before), "%s rejects without coercion or mutation" % mutation.label)
	for invalid in [null, true, [], "state", 79, 79.0, INF, NAN]:
		_check(not planner.call("_evaluate_child_results_for_test", invalid).get("ok", true), "non-dictionary snapshot rejects")


func _test_child_result_fail_closed(planner: RefCounted) -> void:
	var input := _baseline_input()
	var results: Dictionary = planner.call("_evaluate_child_results_for_test", input)
	var cases: Array[Dictionary] = []
	var extra := results.duplicate(true); extra["extra"] = 0; cases.append({"label": "extra root field", "value": extra})
	var missing := results.duplicate(true); missing.erase("eventb03"); cases.append({"label": "missing EVENTB03 result", "value": missing})
	var order := results.duplicate(true); order.priority.first_true_order = 0; cases.append({"label": "priority summary", "value": order})
	var guard := results.duplicate(true); guard.priority.evaluated_guards[3].offset += 1; cases.append({"label": "priority offset", "value": guard})
	var next := results.duplicate(true); next.priority.evaluated_guards[8].next_offset += 1; cases.append({"label": "priority edge", "value": next})
	var candidate := results.duplicate(true); candidate.eventb03.value = 0; cases.append({"label": "candidate value", "value": candidate})
	var candidate_bool := results.duplicate(true); candidate_bool.eventb03.candidate = false; cases.append({"label": "candidate boolean", "value": candidate_bool})
	for item in cases:
		var changed: Dictionary = item.value
		var before := changed.duplicate(true)
		_check(not planner.call("_build_from_child_results_for_test", input, changed).get("ok", true) and changed == before, "%s child-result tamper rejects without mutation" % item.label)
	var preempt_input := _baseline_input()
	_enable_priority_guard(preempt_input, 2)
	var preempt: Dictionary = planner.call("_evaluate_child_results_for_test", preempt_input)
	var invented := preempt.duplicate(true)
	invented.eventb03 = {"ok": true, "value": 1, "candidate": true}
	_check(not planner.call("_build_from_child_results_for_test", preempt_input, invented).get("ok", true), "invented EVENTB03 result after preemption rejects")
	var different_input := input.duplicate(true)
	different_input.global_u8["400"] = 0
	_check(not planner.call("_build_from_child_results_for_test", different_input, results).get("ok", true), "child results from a different frozen snapshot reject")


func _test_plan_validation(planner: RefCounted) -> void:
	var input := _baseline_input()
	var input_before := input.duplicate(true)
	var results: Dictionary = planner.call("_evaluate_child_results_for_test", input)
	var results_before := results.duplicate(true)
	var plan: Dictionary = planner.call("_build_from_child_results_for_test", input, results)
	var plan_before := plan.duplicate(true)
	_check(planner.call("_validate_from_child_results_for_test", input, results, plan).get("ok", false), "native-integer synthetic plan validates by replay")
	var json_plan: Variant = JSON.parse_string(JSON.stringify(plan))
	var json_results: Variant = JSON.parse_string(JSON.stringify(results))
	_check(json_plan is Dictionary and json_results is Dictionary and planner.call("_validate_from_child_results_for_test", input, json_results, json_plan).get("ok", false), "lossless integral JSON child results and plan validate")
	_check(planner.call("_build_from_child_results_for_test", input, results) == plan, "synthetic decision rebuild is deterministic")
	var cases: Array[Dictionary] = []
	var schema := plan.duplicate(true); schema.schema = "wrong"; cases.append({"label": "schema", "plan": schema})
	var source := plan.duplicate(true); source.source.child_structural_authority = "source_bound_child_validation"; cases.append({"label": "source authority", "plan": source})
	var count := plan.duplicate(true); count.required_input.total_unique_cells = 78; cases.append({"label": "input union", "plan": count})
	var child := plan.duplicate(true); child.children.priority.first_true_order = 0; cases.append({"label": "priority child", "plan": child})
	var event_child := plan.duplicate(true); event_child.children.eventb03.source_bound = true; cases.append({"label": "EVENTB03 child authority", "plan": event_child})
	var decision := plan.duplicate(true); decision.decision.outcome = "eventb03_preempted_by_upstream_guard"; cases.append({"label": "decision", "plan": decision})
	var body := plan.duplicate(true); body.execution.eventb03_body_execution = true; cases.append({"label": "body execution", "plan": body})
	var handoff := plan.duplicate(true); handoff.execution.script_handoff_execution = true; cases.append({"label": "handoff execution", "plan": handoff})
	var preemption := plan.duplicate(true); preemption.execution.frozen_state_preemption = "unqualified"; cases.append({"label": "frozen-state preemption", "plan": preemption})
	var prefix := plan.duplicate(true); prefix.execution.prefix_completion = "complete"; cases.append({"label": "prefix completion", "plan": prefix})
	var eligibility := plan.duplicate(true); eligibility.execution.natural_scheduler_eligibility = "qualified"; cases.append({"label": "natural eligibility", "plan": eligibility})
	var preset := plan.duplicate(true); preset.execution.product_preset_widening = true; cases.append({"label": "product preset widening", "plan": preset})
	var extra := plan.duplicate(true); extra["extra"] = 0; cases.append({"label": "extra root field", "plan": extra})
	for item in cases:
		var changed: Dictionary = item.plan
		var before := changed.duplicate(true)
		_check(not planner.call("_validate_from_child_results_for_test", input, results, changed).get("ok", true) and changed == before, "%s plan tamper rejects without mutation" % item.label)
	_check(input == input_before and results == results_before and plan == plan_before, "validation and tamper probes preserve snapshot, child results and plan")


func _test_public_source_boundary(planner: RefCounted) -> void:
	var input := _baseline_input()
	var input_before := input.duplicate(true)
	var payload := PackedByteArray()
	var payload_before := payload.duplicate()
	_check(not planner.build(payload, input).get("ok", true) and payload == payload_before and input == input_before, "public build rejects non-original source without mutation")
	for forged in [{}, {"ok": true}, {"schema": Version.MES_STATION_EVENTB03_DECISION_PLAN_SCHEMA, "input": input}]:
		var plan: Dictionary = forged.duplicate(true)
		var before := plan.duplicate(true)
		_check(not planner.validate(payload, plan).get("ok", true) and plan == before and payload == payload_before, "public validation rejects forged non-original evidence")


func _baseline_input() -> Dictionary:
	var input := {"state_u16": {}, "banked_u16_0": {}, "global_u8": {}}
	for index in STATE_U16_INDICES: input.state_u16[str(index)] = 0
	for index in BANKED_U16_INDICES: input.banked_u16_0[str(index)] = 0
	for index in GLOBAL_U8_INDICES: input.global_u8[str(index)] = 0
	input.state_u16["7"] = 413
	input.state_u16["19"] = 1825
	input.state_u16["12"] = 100
	input.banked_u16_0["210"] = 50
	input.global_u8["400"] = 1
	return input


func _enable_priority_guard(input: Dictionary, order: int) -> void:
	if order == 0:
		input.state_u16["7"] = 413
		input.state_u16["19"] = 1000
		input.banked_u16_0["268"] = 412
		input.global_u8["2300"] = 1
		input.global_u8["2301"] = 1
		return
	if order >= 1 and order <= 12:
		var row: Array = SCHEDULE_ROWS[order - 1]
		input.state_u16["7"] = 500
		input.state_u16["19"] = 1200
		input.banked_u16_0[str(row[0])] = 500
		input.banked_u16_0[str(row[1])] = 1200
		input.global_u8[str(row[2])] = 1
		input.global_u8[str(int(row[2]) + 7)] = 2
		input.global_u8[str(int(row[2]) + 9)] = 9
		return
	if order == 13:
		input.state_u16["7"] = 500
		input.state_u16["19"] = 1900
		input.global_u8["160"] = 1
		input.global_u8["1750"] = 1
		return
	input.state_u16["4"] = 0
	input.state_u16["19"] = 1300
	input.global_u8["110"] = 1
	input.global_u8["1188"] = 1


func _contains_payload(value: Variant, depth := 0) -> bool:
	if depth > 32 or value is PackedByteArray:
		return true
	if value is Dictionary:
		for key in value:
			if str(key) in ["raw_hex", "raw_bytes", "payload", "bytecode", "operands", "ast"] or _contains_payload(value[key], depth + 1):
				return true
	elif value is Array:
		for child in value:
			if _contains_payload(child, depth + 1): return true
	return false


func _is_digest(value: Variant) -> bool:
	if typeof(value) != TYPE_STRING or str(value).length() != 64:
		return false
	for index in range(str(value).length()):
		var code: int = str(value).unicode_at(index)
		if not (code >= 48 and code <= 57) and not (code >= 97 and code <= 102): return false
	return true


func _same_special(actual: Variant, expected: Variant) -> bool:
	if actual is Dictionary and expected is Dictionary:
		if actual.size() != expected.size(): return false
		for key in actual:
			if not expected.has(key) or not _same_special(actual[key], expected[key]): return false
		return true
	if typeof(actual) == TYPE_FLOAT and typeof(expected) == TYPE_FLOAT and is_nan(float(actual)) and is_nan(float(expected)):
		return true
	return typeof(actual) == typeof(expected) and actual == expected


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failed = true
	push_error(message)
