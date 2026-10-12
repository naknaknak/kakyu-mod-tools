extends Node

const PlanScript := preload("res://content_core/mes_station_candidate_priority_plan.gd")
const ContainerScript := preload("res://content_core/mes_container.gd")
const Version := preload("res://content_core/content_core_version.gd")

const CASCADE_OFFSET := 0x026D
const JOIN_OFFSET := 0x7691
const CASCADE_SHA256 := "34ae9a590921cf5e4ac5f4a5921c2d5b1a779ae6d868d7b4ead456bcb1671c29"

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

# start, end, false destination, exact original guard SHA-256, schedule date,
# schedule time and byte-family base. Negative values select special guards.
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

var _checks := 0
var _failed := false


func _ready() -> void:
	var planner := PlanScript.new()
	var code := _fixture_code()
	_test_fixture_identity(planner, code)
	_test_all_false_plan(planner, code)
	_test_first_true_boundaries(planner, code)
	_test_input_contract(planner, code)
	_test_structural_rejections(planner, code)
	_test_plan_validation(planner, code)
	_test_public_source_boundary(planner, code)
	print("Station candidate priority plan synthetic checks: ", _checks)
	await get_tree().process_frame
	get_tree().quit(1 if _failed else 0)


func _test_fixture_identity(planner: RefCounted, code: PackedByteArray) -> void:
	var before := code.duplicate()
	var inspected: Dictionary = planner.call("_inspect", code, true)
	_check(inspected.get("ok", false), "all fifteen exact source guard envelopes inspect")
	var guards: Array = inspected.get("guards", [])
	_check(guards.size() == GUARD_ROWS.size(), "inspection retains fifteen guards in source order")
	for order in range(mini(guards.size(), GUARD_ROWS.size())):
		var guard: Dictionary = guards[order]
		var row: Array = GUARD_ROWS[order]
		_check(guard == {
			"order": order,
			"offset": row[0],
			"end_offset": row[1],
			"true_offset": row[1],
			"false_offset": row[2],
			"sha256": row[3],
			"predicate_signature": planner.call("_expected_guard_signature", order),
			"state_references": planner.call("_state_references", planner.call("_expected_guard_signature", order)),
		}, "guard %d binds boundary, edge, predicate, source order and hash" % order)
	var descriptor: Dictionary = inspected.get("required_input", {})
	_check(descriptor == {
		"state_u16": STATE_U16_INDICES,
		"banked_u16_0": BANKED_U16_INDICES,
		"global_u8": GLOBAL_U8_INDICES,
		"total_unique_cells": 72,
	}, "source-reference union exposes exactly 72 required cells")
	_check(code == before, "inspection does not mutate source bytes")


func _test_all_false_plan(planner: RefCounted, code: PackedByteArray) -> void:
	var input := _baseline_input()
	var input_before := input.duplicate(true)
	var code_before := code.duplicate()
	var plan: Dictionary = planner.call("_build_from_code", code, input)
	_check(plan.get("ok", false), "all-false source state builds a bounded plan")
	_check(plan.get("schema", "") == Version.MES_STATION_CANDIDATE_PRIORITY_PLAN_SCHEMA, "plan schema comes from the Content Core version contract")
	_check(plan.keys() == ["ok", "schema", "producer", "source", "required_input", "input", "guards", "evaluation", "selected_boundary", "execution"], "plan exposes only its exact documented root shape")
	_check(plan.get("input", {}) == input and input == input_before, "plan records every supplied source cell without mutating input")
	_check(plan.get("source", {}) == {
		"archive": "synthetic_fixture",
		"entry": "01M.MES-shaped-code",
		"entry_sha256": "not_applicable",
		"bytecode_sha256": _sha256(code),
		"offset_basis": "code_start",
		"cascade_offset": CASCADE_OFFSET,
		"join_offset": JOIN_OFFSET,
		"cascade_sha256": _sha256(code.slice(CASCADE_OFFSET, JOIN_OFFSET)),
	}, "synthetic plan identifies its complete local code and cascade slice")
	var outcomes: Array = plan.get("evaluation", {}).get("evaluated_guards", [])
	_check(outcomes.size() == 15 and plan.evaluation.first_true_order == -1 and plan.evaluation.all_upstream_false, "all fifteen false predicates are evaluated before the join")
	for order in range(mini(outcomes.size(), GUARD_ROWS.size())):
		_check(outcomes[order] == {"order": order, "offset": GUARD_ROWS[order][0], "value": 0, "next_offset": GUARD_ROWS[order][2]}, "false guard %d follows only its audited source edge" % order)
	_check(plan.get("selected_boundary", {}) == {
		"kind": "candidate_cascade_join",
		"offset": JOIN_OFFSET,
		"end_offset": JOIN_OFFSET,
		"next_plan_schema": Version.MES_EVENTB03_CANDIDATE_PLAN_SCHEMA,
		"delegated": false,
	}, "all-false projection stops at the candidate-plan delegation boundary")
	_check(plan.get("execution", {}) == {
		"kind": "read_only_projection",
		"state_mutation": false,
		"frozen_state_preemption": "qualified",
		"true_body_execution": false,
		"terminal_resolution": false,
		"entry_zero_reachability": "unqualified",
		"natural_scheduler_eligibility": "unqualified",
		"native_address_row_selection": "unresolved",
		"native_cadence": "unresolved",
	}, "execution receipt does not promote unresolved host or true-body behavior")
	_check(not _contains_payload(plan) and code == code_before, "plan remains metadata-only and preserves source bytes")


func _test_first_true_boundaries(planner: RefCounted, code: PackedByteArray) -> void:
	for order in range(GUARD_ROWS.size()):
		var input := _baseline_input()
		_enable_guard(input, order)
		var before := input.duplicate(true)
		var plan: Dictionary = planner.call("_build_from_code", code, input)
		_check(plan.get("ok", false), "guard %d true witness builds" % order)
		if not plan.get("ok", false):
			continue
		var outcomes: Array = plan.evaluation.evaluated_guards
		_check(outcomes.size() == order + 1 and plan.evaluation.first_true_order == order and not plan.evaluation.all_upstream_false, "guard %d is the first matching source-order predicate" % order)
		_check(outcomes[-1] == {"order": order, "offset": GUARD_ROWS[order][0], "value": 1, "next_offset": GUARD_ROWS[order][1]}, "guard %d true edge stops at its body boundary" % order)
		_check(plan.selected_boundary == {
			"kind": "stop_before_true_body",
			"guard_order": order,
			"guard_offset": GUARD_ROWS[order][0],
			"offset": GUARD_ROWS[order][1],
			"end_offset": GUARD_ROWS[order][1],
			"tool_execution": false,
			"true_body_interpretation": "unresolved",
		}, "guard %d reports a zero-length stop without interpreting its body" % order)
		_check(input == before, "guard %d evaluation leaves the frozen input unchanged" % order)
	var multiple := _baseline_input()
	_enable_guard(multiple, 12)
	_enable_guard(multiple, 1)
	var earliest: Dictionary = planner.call("_build_from_code", code, multiple)
	_check(earliest.get("ok", false) and earliest.evaluation.first_true_order == 1 and earliest.evaluation.evaluated_guards.size() == 2, "multiple matches stop at the earliest source-order guard")


func _test_input_contract(planner: RefCounted, code: PackedByteArray) -> void:
	var baseline := _baseline_input()
	var mutations := [
		{"label": "missing storage group", "erase_group": "global_u8"},
		{"label": "extra storage group", "add_group": ["other", {}]},
		{"label": "non-string storage group", "add_group": [7, {}], "erase_group": "global_u8"},
		{"label": "missing state cell", "group": "state_u16", "erase": "4"},
		{"label": "extra state cell", "group": "state_u16", "set": ["5", 0]},
		{"label": "numeric state key", "group": "state_u16", "erase": "4", "set": [4, 0]},
		{"label": "direct integral float", "group": "state_u16", "set": ["7", 413.0]},
		{"label": "fraction", "group": "state_u16", "set": ["7", 413.5]},
		{"label": "boolean", "group": "global_u8", "set": ["2300", true]},
		{"label": "string", "group": "banked_u16_0", "set": ["268", "412"]},
		{"label": "negative u16", "group": "state_u16", "set": ["7", -1]},
		{"label": "wide u16", "group": "banked_u16_0", "set": ["268", 65536]},
		{"label": "wide u8", "group": "global_u8", "set": ["2300", 256]},
		{"label": "infinite", "group": "state_u16", "set": ["7", INF]},
		{"label": "nan", "group": "state_u16", "set": ["7", NAN]},
	]
	for mutation in mutations:
		var changed: Dictionary = baseline.duplicate(true)
		if mutation.has("erase_group"):
			changed.erase(mutation.erase_group)
		if mutation.has("add_group"):
			changed[mutation.add_group[0]] = mutation.add_group[1]
		if mutation.has("group"):
			var group: Dictionary = changed[mutation.group]
			if mutation.has("erase"):
				group.erase(mutation.erase)
			if mutation.has("set"):
				group[mutation.set[0]] = mutation.set[1]
		var before := changed.duplicate(true)
		_check(not planner.call("_build_from_code", code, changed).get("ok", true) and _same_special(changed, before), "%s rejects without coercion or input mutation" % mutation.label)
	for invalid in [null, true, "state", [], 7, 7.0, INF, NAN]:
		_check(not planner.call("_build_from_code", code, invalid).get("ok", true), "non-dictionary input rejects")


func _test_structural_rejections(planner: RefCounted, code: PackedByteArray) -> void:
	var original := code.duplicate()
	for order in range(GUARD_ROWS.size()):
		var changed := code.duplicate()
		changed[GUARD_ROWS[order][0] + 1] ^= 1
		_check(not planner.call("_inspect", changed, true).get("ok", true), "guard %d source-byte mutation rejects" % order)
		var edge_changed := code.duplicate()
		edge_changed.encode_u32(GUARD_ROWS[order][1] - 4, GUARD_ROWS[order][2] + 1)
		_check(not planner.call("_inspect", edge_changed, true).get("ok", true), "guard %d false-edge mutation rejects" % order)
	for size in [0, CASCADE_OFFSET, GUARD_ROWS[7][1], JOIN_OFFSET - 1]:
		var truncated := code.duplicate()
		truncated.resize(size)
		_check(not planner.call("_inspect", truncated, true).get("ok", true), "truncated cascade at 0x%X rejects" % size)
	var body_changed := code.duplicate()
	body_changed[0x1000] = 0x7E
	var body_plan: Dictionary = planner.call("_build_from_code", body_changed, _baseline_input())
	var base_plan: Dictionary = planner.call("_build_from_code", code, _baseline_input())
	_check(body_plan.get("ok", false) and body_plan.selected_boundary == base_plan.selected_boundary and body_plan.evaluation == base_plan.evaluation, "uninterpreted true-body bytes cannot change predicate selection")
	_check(body_plan.source.bytecode_sha256 != base_plan.source.bytecode_sha256 and body_plan.source.cascade_sha256 != base_plan.source.cascade_sha256, "synthetic source identity still records uninterpreted body drift")
	_check(code == original, "all structural rejection probes preserve the fixture")


func _test_plan_validation(planner: RefCounted, code: PackedByteArray) -> void:
	var plan: Dictionary = planner.call("_build_from_code", code, _baseline_input())
	var plan_before := plan.duplicate(true)
	var code_before := code.duplicate()
	_check(planner.call("_validate_from_code", code, plan).get("ok", false), "native integer plan validates by deterministic rebuild")
	var parsed: Variant = JSON.parse_string(JSON.stringify(plan))
	_check(parsed is Dictionary and planner.call("_validate_from_code", code, parsed).get("ok", false), "lossless integral JSON numbers validate against the same plan")
	_check(planner.call("_build_from_code", code, _baseline_input()) == plan, "synthetic plan rebuild is deterministic")
	var tamper_cases: Array[Dictionary] = []
	var guard_tamper := plan.duplicate(true)
	guard_tamper.guards[0].false_offset += 1
	tamper_cases.append({"label": "guard edge", "plan": guard_tamper})
	var signature_tamper := plan.duplicate(true)
	signature_tamper.guards[1].predicate_signature[0] = "logical_and"
	tamper_cases.append({"label": "predicate signature", "plan": signature_tamper})
	var evaluation_tamper := plan.duplicate(true)
	evaluation_tamper.evaluation.evaluated_guards[0].value = 1
	tamper_cases.append({"label": "evaluation", "plan": evaluation_tamper})
	var boundary_tamper := plan.duplicate(true)
	boundary_tamper.selected_boundary.delegated = true
	tamper_cases.append({"label": "delegation claim", "plan": boundary_tamper})
	var source_tamper := plan.duplicate(true)
	source_tamper.source.cascade_sha256 = CASCADE_SHA256
	tamper_cases.append({"label": "source identity", "plan": source_tamper})
	var descriptor_tamper := plan.duplicate(true)
	descriptor_tamper.required_input.total_unique_cells = 71
	tamper_cases.append({"label": "required input descriptor", "plan": descriptor_tamper})
	var execution_tamper := plan.duplicate(true)
	execution_tamper.execution.true_body_execution = true
	tamper_cases.append({"label": "execution promotion", "plan": execution_tamper})
	var extra_tamper := plan.duplicate(true)
	extra_tamper["extra"] = 0
	tamper_cases.append({"label": "extra root field", "plan": extra_tamper})
	for item in tamper_cases:
		var changed: Dictionary = item.plan
		var before := changed.duplicate(true)
		_check(not planner.call("_validate_from_code", code, changed).get("ok", true) and changed == before, "%s tamper rejects without mutation" % item.label)
	var true_input := _baseline_input()
	_enable_guard(true_input, 14)
	var input_tamper: Dictionary = planner.call("_build_from_code", code, true_input)
	input_tamper.input.global_u8["1188"] = 0
	_check(not planner.call("_validate_from_code", code, input_tamper).get("ok", true), "valid-width input change rejects when its recorded evaluation no longer matches")
	var json_fraction: Dictionary = JSON.parse_string(JSON.stringify(plan))
	json_fraction.input.state_u16["7"] = 413.5
	_check(not planner.call("_validate_from_code", code, json_fraction).get("ok", true), "fractional JSON input rejects")
	var json_boolean: Dictionary = JSON.parse_string(JSON.stringify(plan))
	json_boolean.input.global_u8["2300"] = false
	_check(not planner.call("_validate_from_code", code, json_boolean).get("ok", true), "boolean JSON input rejects")
	_check(plan == plan_before and code == code_before, "validation and tamper probes preserve the original plan and source")


func _test_public_source_boundary(planner: RefCounted, code: PackedByteArray) -> void:
	var payload := PackedByteArray()
	payload.resize(8 + code.size())
	payload.encode_u32(0, 1)
	payload.encode_u32(4, 0)
	_put(payload, 8, code)
	var payload_before := payload.duplicate()
	var input := _baseline_input()
	var input_before := input.duplicate(true)
	_check(ContainerScript.new().parse(payload).get("ok", false), "synthetic cascade is independently valid MES framing")
	_check(not planner.build(payload, input).get("ok", true) and payload == payload_before and input == input_before, "public build rejects a structurally exact synthetic cascade that is not original 01M.MES")
	for forged in [{}, {"input": input}, {"ok": true, "schema": Version.MES_STATION_CANDIDATE_PRIORITY_PLAN_SCHEMA, "input": input}]:
		var before: Dictionary = forged.duplicate(true)
		_check(not planner.validate(payload, forged).get("ok", true) and forged == before and payload == payload_before, "public validation rejects forged synthetic evidence without mutation")


func _fixture_code() -> PackedByteArray:
	var code := PackedByteArray()
	code.resize(JOIN_OFFSET)
	for order in range(GUARD_ROWS.size()):
		var row: Array = GUARD_ROWS[order]
		var record: PackedByteArray
		if order == 0:
			record = _branch(_first_expression(), int(row[2]))
		elif order <= 12:
			var equal_arm := _schedule_expression(int(row[4]), int(row[5]), int(row[6]), 0xEF)
			var greater_arm := _schedule_expression(int(row[4]), int(row[5]), int(row[6]), 0xEC)
			record = _branch(equal_arm + greater_arm + PackedByteArray([0xE7]), int(row[2]))
		elif order == 13:
			record = _branch(_guard_13_expression(), int(row[2]))
		else:
			record = _branch(_guard_14_expression(), int(row[2]))
		_check(record.size() == int(row[1]) - int(row[0]), "guard %d generator reproduces the audited record length" % order)
		_check(_sha256(record) == str(row[3]), "guard %d generator reproduces the audited record hash" % order)
		_put(code, int(row[0]), record)
	return code


func _first_expression() -> PackedByteArray:
	return _left_and_bytes([
		_banked_u16(268) + _literal(1) + PackedByteArray([0xE0]) + _state_u16(7) + PackedByteArray([0xEF]),
		_state_u16(19) + _literal(930) + PackedByteArray([0xEC]),
		_state_u16(19) + _literal(1100) + PackedByteArray([0xEB]),
		_global_u8(2300) + _literal(1) + PackedByteArray([0xEF]),
		_global_u8(2304) + _literal(0) + PackedByteArray([0xEF]),
		_global_u8(2305) + _literal(0) + PackedByteArray([0xEF]),
		_global_u8(2301) + _literal(1) + PackedByteArray([0xEF]),
	])


func _schedule_expression(date_index: int, time_index: int, byte_base: int, time_operator: int) -> PackedByteArray:
	return _left_and_bytes([
		_state_u16(7) + _banked_u16(date_index) + PackedByteArray([0xEF]),
		_global_u8(byte_base) + _literal(1) + PackedByteArray([0xEF]),
		_global_u8(byte_base + 7) + _literal(2) + PackedByteArray([0xEF]),
		_state_u16(19) + _banked_u16(time_index) + PackedByteArray([time_operator]),
		_global_u8(byte_base + 9) + _literal(8) + PackedByteArray([0xEC]),
		_global_u8(byte_base + 9) + _literal(14) + PackedByteArray([0xF0]),
	])


func _guard_13_expression() -> PackedByteArray:
	return _left_and_bytes([
		_state_u16(7) + _literal(1301) + PackedByteArray([0xF0]),
		_state_u16(19) + _literal(1800) + PackedByteArray([0xEC]),
		_state_u16(19) + _literal(2100) + PackedByteArray([0xEB]),
		_state_u16(7) + _literal(1301) + PackedByteArray([0xF0]),
		_global_u8(160) + _literal(1) + PackedByteArray([0xEF]),
		_global_u8(1750) + _literal(1) + PackedByteArray([0xEF]),
		_global_u8(1751) + _literal(0) + PackedByteArray([0xEF]),
	])


func _guard_14_expression() -> PackedByteArray:
	return _left_and_bytes([
		_state_u16(4) + _literal(0) + PackedByteArray([0xEF]),
		_state_u16(19) + _literal(1100) + PackedByteArray([0xEC]),
		_state_u16(19) + _literal(1700) + PackedByteArray([0xEB]),
		_global_u8(110) + _literal(1) + PackedByteArray([0xEF]),
		_global_u8(117) + _literal(0) + PackedByteArray([0xEF]),
		_global_u8(1188) + _literal(1) + PackedByteArray([0xEF]),
		_global_u8(1189) + _literal(0) + PackedByteArray([0xEF]),
	])


func _left_and_bytes(conditions: Array[PackedByteArray]) -> PackedByteArray:
	var result := conditions[0].duplicate()
	for index in range(1, conditions.size()):
		result.append_array(conditions[index])
		result.append(0xE6)
	return result


func _branch(expression: PackedByteArray, false_target: int) -> PackedByteArray:
	var result := PackedByteArray([0x0B]) + expression + PackedByteArray([0xFF, 0, 0, 0, 0])
	result.encode_u32(result.size() - 4, false_target)
	return result


func _state_u16(index: int) -> PackedByteArray:
	return PackedByteArray([0x80, index])


func _banked_u16(index: int) -> PackedByteArray:
	return _literal(index) + PackedByteArray([0xA0, 0])


func _global_u8(index: int) -> PackedByteArray:
	var result := PackedByteArray([0xF3, 0, 0])
	result.encode_u16(1, index)
	return result


func _literal(value: int) -> PackedByteArray:
	if value < 0x80:
		return PackedByteArray([value])
	var result := PackedByteArray([0xF1, 0, 0])
	result.encode_u16(1, value)
	return result


func _baseline_input() -> Dictionary:
	var input := {"state_u16": {}, "banked_u16_0": {}, "global_u8": {}}
	for index in STATE_U16_INDICES:
		input.state_u16[str(index)] = 0
	for index in BANKED_U16_INDICES:
		input.banked_u16_0[str(index)] = 0
	for index in GLOBAL_U8_INDICES:
		input.global_u8[str(index)] = 0
	input.state_u16["4"] = 0
	input.state_u16["7"] = 413
	input.state_u16["19"] = 1825
	return input


func _enable_guard(input: Dictionary, order: int) -> void:
	if order == 0:
		input.state_u16["7"] = 413
		input.state_u16["19"] = 1000
		input.banked_u16_0["268"] = 412
		input.global_u8["2300"] = 1
		input.global_u8["2301"] = 1
		return
	if order >= 1 and order <= 12:
		var row: Array = GUARD_ROWS[order]
		input.state_u16["7"] = 500
		input.state_u16["19"] = 1200
		input.banked_u16_0[str(row[4])] = 500
		input.banked_u16_0[str(row[5])] = 1200
		input.global_u8[str(row[6])] = 1
		input.global_u8[str(int(row[6]) + 7)] = 2
		input.global_u8[str(int(row[6]) + 9)] = 9
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
	if depth > 32:
		return true
	if value is PackedByteArray:
		return true
	if value is Dictionary:
		for key in value:
			if str(key) in ["raw_hex", "raw_bytes", "payload", "bytecode"] or _contains_payload(value[key], depth + 1):
				return true
	if value is Array:
		for child in value:
			if _contains_payload(child, depth + 1):
				return true
	return false


func _same_special(actual: Variant, expected: Variant) -> bool:
	if actual is Dictionary and expected is Dictionary:
		if actual.size() != expected.size():
			return false
		for key in actual:
			if not expected.has(key) or not _same_special(actual[key], expected[key]):
				return false
		return true
	if typeof(actual) == TYPE_FLOAT and typeof(expected) == TYPE_FLOAT:
		if is_nan(float(actual)) and is_nan(float(expected)):
			return true
	return typeof(actual) == typeof(expected) and actual == expected


func _put(target: PackedByteArray, offset: int, data: PackedByteArray) -> void:
	for index in range(data.size()):
		target[offset + index] = data[index]


func _sha256(data: PackedByteArray) -> String:
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK or context.update(data) != OK:
		return ""
	return context.finish().hex_encode()


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		return
	_failed = true
	push_error("FAIL: " + label)
