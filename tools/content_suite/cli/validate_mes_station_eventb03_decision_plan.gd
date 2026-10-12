extends SceneTree

# Authoritative, metadata-only validation. This script evaluates exact source
# predicates in isolated state and never executes a body, native operation,
# handoff, target script, or original archive payload.
const Reader := preload("res://content_core/arc_reader.gd")
const ContainerScript := preload("res://content_core/mes_container.gd")
const Decoder := preload("res://content_core/mes_instruction_decoder.gd")
const ExpressionScript := preload("res://content_core/mes_expression.gd")
const State := preload("res://content_core/mes_sandbox_state.gd")
const DecisionPlan := preload("res://content_core/mes_station_eventb03_decision_plan.gd")
const PriorityPlan := preload("res://content_core/mes_station_candidate_priority_plan.gd")
const EventB03Plan := preload("res://content_core/mes_eventb03_candidate_plan.gd")
const Version := preload("res://content_core/content_core_version.gd")
const ContractValues := preload("res://content_core/contract_values.gd")
const ArchiveIdentity := preload("res://content_core/original_archive_identity.gd")

const ARCHIVE_SHA256 := ArchiveIdentity.SIX_ARCHIVE_SHA256
const STATION_SHA256 := "a50511b0ad0ad446b7988c3cfb36736424bf6617e9eb952e20b505f745607cc5"
const STATION_BYTECODE_SHA256 := "f590b3007ea98dcce6f10bc85eb316abdf250f6417a87cec4ab0a6d98ed2230b"
const PRIORITY_SHA256 := "34ae9a590921cf5e4ac5f4a5921c2d5b1a779ae6d868d7b4ead456bcb1671c29"
const EVENTB03_GUARD_SHA256 := "7f8da510f2f3b0e7d3714812605da35f9f249321044f60e7dcb321b9c4c3c9d4"
const EVENTB03_TRUE_SHA256 := "da17019f9f71d69723776c60f867741fef82be605149a995cd22da5a7d95cfc0"
const COMBINED_WINDOW_SHA256 := "f537624206b90bb337372f390f9731ed0b23b0e6d45a6e26a9d7246ea99d0fd1"

const STATE_U16_INDICES := [4, 7, 12, 19]
const BANKED_U16_INDICES := [
	210, 213, 214, 215, 216, 217, 218, 219, 220, 221, 222,
	225, 226, 227, 228, 229, 230, 231, 232, 233, 234, 235, 236,
	237, 238, 268,
]
const GLOBAL_U8_INDICES := [
	100, 107, 109, 110, 117, 119, 120, 127, 129, 130, 137, 139,
	140, 147, 149, 160, 167, 169, 170, 177, 179, 180, 187, 189,
	190, 197, 199, 200, 205, 207, 209, 210, 217, 219, 220, 227,
	229, 333, 400, 628, 631, 1188, 1189, 1750, 1751, 2300, 2301,
	2304, 2305,
]
const PRIORITY_STATE_U16_INDICES := [4, 7, 19]
const PRIORITY_BANKED_U16_INDICES := [
	213, 214, 215, 216, 217, 218, 219, 220, 221, 222,
	225, 226, 227, 228, 229, 230, 231, 232, 233, 234, 235, 236,
	237, 238, 268,
]
const PRIORITY_GLOBAL_U8_INDICES := [
	100, 107, 109, 110, 117, 119, 120, 127, 129, 130, 137, 139,
	140, 147, 149, 160, 167, 169, 170, 177, 179, 180, 187, 189,
	190, 197, 199, 200, 207, 209, 210, 217, 219, 220, 227, 229,
	1188, 1189, 1750, 1751, 2300, 2301, 2304, 2305,
]

# start, end, false destination, exact hash, schedule date cell, time cell,
# byte-family base. Negative schedule values identify the three special ASTs.
const PRIORITY_GUARDS := [
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
const EVENTB03_BASE := {
	"state_u16_7": 413,
	"state_u16_19": 1825,
	"banked_u16_210": 76,
	"global_u8_207": 0,
	"global_u8_333": 0,
	"global_u8_200": 0,
	"global_u8_400": 1,
	"global_u8_205": 0,
	"global_u8_631": 0,
	"state_u16_12": 100,
	"global_u8_628": 0,
}
const EVENTB03_FALSE_CASES := [
	["date_lower", "state_u16_7", 400], ["date_upper", "state_u16_7", 616],
	["time_lower", "state_u16_19", 1800], ["time_upper", "state_u16_19", 2001],
	["affection_lower", "banked_u16_210", 40], ["affection_upper", "banked_u16_210", 80],
	["global207_equal_two", "global_u8_207", 2], ["global333_nonzero", "global_u8_333", 1],
	["global200_nonzero", "global_u8_200", 1], ["global400_not_one", "global_u8_400", 0],
	["global205_nonzero", "global_u8_205", 1], ["global631_nonzero", "global_u8_631", 1],
	["state12_zero", "state_u16_12", 0], ["global628_nonzero", "global_u8_628", 1],
]

var _checks := 0
var _failures: Array[String] = []
var _decoder := Decoder.new()
var _decision_plans := DecisionPlan.new()
var _priority_plans := PriorityPlan.new()
var _eventb03_plans := EventB03Plan.new()
var _priority_asts: Array[Dictionary] = []
var _eventb03_ast := {}


func _initialize() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() != 1:
		push_error("Usage: validate_mes_station_eventb03_decision_plan.gd -- <ELFIMAGE-directory>")
		quit(2)
		return
	var source_root := ProjectSettings.globalize_path(str(arguments[0])).simplify_path()
	var before := {}
	for archive in ARCHIVE_SHA256:
		var path := source_root.path_join(archive)
		if not FileAccess.file_exists(path):
			push_error("Required original archive unavailable: %s" % archive)
			quit(2)
			return
		before[archive] = FileAccess.get_sha256(path)
		_check(before[archive] == ARCHIVE_SHA256[archive], "%s original identity changed" % archive)
	var mes := Reader.new()
	_check(mes.open(source_root.path_join("mes.arc")), "original mes.arc unavailable")
	if _failures.is_empty():
		_audit(mes)
	mes.close()
	for archive in ARCHIVE_SHA256:
		_check(FileAccess.get_sha256(source_root.path_join(archive)) == before[archive], "%s changed during read-only validation" % archive)
	if not _failures.is_empty():
		push_error("Station EVENTB03 decision source validation failed: %s" % "; ".join(_failures))
		quit(1)
		return
	print("PASS: station EVENTB03 frozen decision: %d checks / exact 79-cell input / 15 first-true stops / multiple-true earliest-wins / all-false B03 true / 14 B03 false boundaries / nested mapping and JSON replay / six archives unchanged. Prefix completion, host entry, native row selection and natural eligibility remain unqualified; no product preset is widened. %s / %s" % [_checks, Version.CORE_VERSION, Version.MES_STATION_EVENTB03_DECISION_PLAN_SCHEMA])
	quit(0)


func _audit(mes: RefCounted) -> void:
	_check(mes.get_archive_fingerprint() == ARCHIVE_SHA256["mes.arc"], "opened mes.arc identity changed")
	_check(mes.get_entry_fingerprint("01M.MES") == STATION_SHA256, "01M.MES identity changed")
	var payload: PackedByteArray = mes.read_entry("01M.MES")
	var payload_before := ContractValues.sha256(payload)
	var document: Dictionary = ContainerScript.new().parse(payload, {
		"archive": "mes.arc", "entry": "01M.MES", "resolved_source": "original_arc",
	})
	_check(document.get("ok", false), "01M.MES container could not be parsed")
	if not document.get("ok", false):
		return
	_check(document.entry_sha256 == STATION_SHA256 and document.bytecode_sha256 == STATION_BYTECODE_SHA256, "01M.MES parsed identity changed")
	_check(ContractValues.sha256(document.bytecode.slice(0x026D, 0x7691)) == PRIORITY_SHA256, "station priority source slice changed")
	_check(ContractValues.sha256(document.bytecode.slice(0x7691, 0x76F1)) == EVENTB03_GUARD_SHA256, "EVENTB03 guard source slice changed")
	_check(ContractValues.sha256(document.bytecode.slice(0x76F1, 0x789F)) == EVENTB03_TRUE_SHA256, "EVENTB03 true source slice changed")
	_check(ContractValues.sha256(document.bytecode.slice(0x026D, 0x78A9)) == COMBINED_WINDOW_SHA256, "combined source window changed")
	_load_source_oracle(document.bytecode)
	if not _failures.is_empty():
		return
	_validate_first_true_routes(payload)
	_validate_multiple_true_routes(payload)
	_validate_eventb03_routes(payload)
	_validate_rejections(payload)
	_check(ContractValues.sha256(payload) == payload_before and payload_before == STATION_SHA256, "decision validation changed its in-memory source")


func _load_source_oracle(code: PackedByteArray) -> void:
	_priority_asts.clear()
	for order in range(PRIORITY_GUARDS.size()):
		var row: Array = PRIORITY_GUARDS[order]
		var record := _record(code, int(row[0]), int(row[1]), "branch_if_not_true")
		if record.is_empty():
			continue
		_check(int(record.operands[1].value) == int(row[2]), "priority guard %d false edge changed" % order)
		_check(ContractValues.sha256(code.slice(int(row[0]), int(row[1]))) == str(row[3]), "priority guard %d hash changed" % order)
		var ast: Dictionary = record.operands[0].value.ast
		_check(_signature(ast) == _expected_priority_signature(order), "priority guard %d AST changed" % order)
		_priority_asts.append(ast.duplicate(true))
	_check(_priority_asts.size() == 15, "not all fifteen priority guards were decoded")
	var event_guard := _record(code, 0x7691, 0x76F1, "branch_if_not_true")
	if not event_guard.is_empty():
		_check(int(event_guard.operands[1].value) == 0x78A9, "EVENTB03 guard false edge changed")
		_eventb03_ast = event_guard.operands[0].value.ast.duplicate(true)
		_check(_signature(_eventb03_ast) == _expected_eventb03_signature(), "EVENTB03 guard AST changed")


func _validate_first_true_routes(payload: PackedByteArray) -> void:
	for order in range(PRIORITY_GUARDS.size()):
		var input := _priority_witness(order)
		var oracle := _evaluate_source(input)
		_check(oracle.get("ok", false) and int(oracle.upstream_first_true_order) == order and not oracle.eventb03_evaluated, "priority witness %d is not independently first true" % order)
		_assert_plan(payload, input, oracle, "priority guard %d first-true" % order)


func _validate_multiple_true_routes(payload: PackedByteArray) -> void:
	var cases := [
		{"orders": [0, 1], "input": _combined_zero_and_schedule()},
		{"orders": [1, 12], "input": _combined_schedules(1, 12, 1200)},
		{"orders": [12, 13], "input": _combined_schedule_and_thirteen()},
		{"orders": [1, 14], "input": _combined_schedule_and_fourteen()},
	]
	for specification in cases:
		var input: Dictionary = specification.input
		var state := _state_from(input)
		var before: Dictionary = state.snapshot()
		for order in specification.orders:
			var evaluated: Dictionary = ExpressionScript.new().evaluate(_priority_asts[int(order)], state)
			_check(evaluated.get("ok", false) and int(evaluated.get("value", -1)) == 1, "multiple-true fixture lost guard %d" % order)
		_check(state.snapshot() == before, "multiple-true source oracle changed state")
		var oracle := _evaluate_source(input)
		_check(int(oracle.get("upstream_first_true_order", -1)) == int(specification.orders.min()) and not oracle.get("eventb03_evaluated", true), "multiple-true fixture lost earliest-wins behavior")
		_assert_plan(payload, input, oracle, "multiple-true %s earliest-wins" % str(specification.orders))


func _validate_eventb03_routes(payload: PackedByteArray) -> void:
	var matching := _eventb03_union_input()
	var oracle := _evaluate_source(matching)
	_check(oracle.get("ok", false) and int(oracle.upstream_first_true_order) == -1 and oracle.eventb03_evaluated and int(oracle.eventb03_value) == 1, "baseline did not independently reach a true EVENTB03 guard")
	_assert_plan(payload, matching, oracle, "all-upstream-false EVENTB03 true")
	for specification in EVENTB03_FALSE_CASES:
		var changed := _eventb03_union_input()
		_set_flat_binding(changed, str(specification[1]), int(specification[2]))
		var before := JSON.stringify(changed)
		var false_oracle := _evaluate_source(changed)
		_check(false_oracle.get("ok", false) and int(false_oracle.upstream_first_true_order) == -1 and false_oracle.eventb03_evaluated and int(false_oracle.eventb03_value) == 0, "%s did not independently reach the EVENTB03 false boundary" % specification[0])
		_assert_plan(payload, changed, false_oracle, "%s EVENTB03 false" % specification[0])
		_check(JSON.stringify(changed) == before, "%s validation changed its input" % specification[0])


func _evaluate_source(input: Dictionary) -> Dictionary:
	var state := _state_from(input)
	var before: Dictionary = state.snapshot()
	var outcomes: Array[Dictionary] = []
	for order in range(_priority_asts.size()):
		var evaluated: Dictionary = ExpressionScript.new().evaluate(_priority_asts[order], state)
		if not evaluated.get("ok", false) or int(evaluated.get("value", -1)) not in [0, 1]:
			return {"ok": false}
		var value := int(evaluated.value)
		var row: Array = PRIORITY_GUARDS[order]
		outcomes.append({"order": order, "offset": row[0], "value": value, "next_offset": row[1] if value == 1 else row[2]})
		if value == 1:
			_check(state.snapshot() == before, "priority source oracle changed state")
			return {
				"ok": true,
				"upstream_first_true_order": order,
				"priority_outcomes": outcomes,
				"eventb03_evaluated": false,
				"eventb03_value": -1,
			}
	var event_result: Dictionary = ExpressionScript.new().evaluate(_eventb03_ast, state)
	if not event_result.get("ok", false) or int(event_result.get("value", -1)) not in [0, 1]:
		return {"ok": false}
	_check(state.snapshot() == before, "combined source oracle changed state")
	return {
		"ok": true,
		"upstream_first_true_order": -1,
		"priority_outcomes": outcomes,
		"eventb03_evaluated": true,
		"eventb03_value": int(event_result.value),
	}


func _state_from(input: Dictionary) -> KakyuMesSandboxState:
	var state := State.new(1)
	for index in STATE_U16_INDICES:
		state.write_value("state_u16", index, input.state_u16[str(index)])
	for index in BANKED_U16_INDICES:
		state.write_value("banked_u16", index, input.banked_u16_0[str(index)], 0)
	for index in GLOBAL_U8_INDICES:
		state.write_value("global_u8", index, input.global_u8[str(index)])
	return state


func _blank_input() -> Dictionary:
	var result := {"state_u16": {}, "banked_u16_0": {}, "global_u8": {}}
	for index in STATE_U16_INDICES:
		result.state_u16[str(index)] = 0
	for index in BANKED_U16_INDICES:
		result.banked_u16_0[str(index)] = 0
	for index in GLOBAL_U8_INDICES:
		result.global_u8[str(index)] = 0
	return result


func _eventb03_union_input() -> Dictionary:
	var result := _blank_input()
	for key in EVENTB03_BASE:
		_set_flat_binding(result, key, EVENTB03_BASE[key])
	return result


func _priority_witness(order: int) -> Dictionary:
	var input := _blank_input()
	if order == 0:
		input.state_u16["7"] = 413
		input.state_u16["19"] = 1000
		input.banked_u16_0["268"] = 412
		input.global_u8["2300"] = 1
		input.global_u8["2301"] = 1
		return input
	if order >= 1 and order <= 12:
		_apply_schedule_witness(input, order, 500, 1200)
		return input
	if order == 13:
		input.state_u16["7"] = 500
		input.state_u16["19"] = 1900
		input.global_u8["160"] = 1
		input.global_u8["1750"] = 1
		return input
	input.state_u16["4"] = 0
	input.state_u16["19"] = 1300
	input.global_u8["110"] = 1
	input.global_u8["117"] = 0
	input.global_u8["1188"] = 1
	return input


func _apply_schedule_witness(input: Dictionary, order: int, date: int, time: int) -> void:
	var row: Array = PRIORITY_GUARDS[order]
	var base := int(row[6])
	input.state_u16["7"] = date
	input.state_u16["19"] = time
	input.banked_u16_0[str(row[4])] = date
	input.banked_u16_0[str(row[5])] = time
	input.global_u8[str(base)] = 1
	input.global_u8[str(base + 7)] = 2
	input.global_u8[str(base + 9)] = 9


func _combined_zero_and_schedule() -> Dictionary:
	var input := _blank_input()
	_apply_schedule_witness(input, 1, 500, 1000)
	input.banked_u16_0["268"] = 499
	input.global_u8["2300"] = 1
	input.global_u8["2301"] = 1
	return input


func _combined_schedules(first: int, second: int, time: int) -> Dictionary:
	var input := _blank_input()
	_apply_schedule_witness(input, first, 500, time)
	_apply_schedule_witness(input, second, 500, time)
	return input


func _combined_schedule_and_thirteen() -> Dictionary:
	var input := _blank_input()
	_apply_schedule_witness(input, 12, 500, 1900)
	input.global_u8["160"] = 1
	input.global_u8["1750"] = 1
	return input


func _combined_schedule_and_fourteen() -> Dictionary:
	var input := _blank_input()
	_apply_schedule_witness(input, 1, 500, 1300)
	input.global_u8["110"] = 1
	input.global_u8["117"] = 0
	input.global_u8["1188"] = 1
	return input


func _priority_input(input: Dictionary) -> Dictionary:
	var result := {"state_u16": {}, "banked_u16_0": {}, "global_u8": {}}
	for index in PRIORITY_STATE_U16_INDICES:
		result.state_u16[str(index)] = input.state_u16[str(index)]
	for index in PRIORITY_BANKED_U16_INDICES:
		result.banked_u16_0[str(index)] = input.banked_u16_0[str(index)]
	for index in PRIORITY_GLOBAL_U8_INDICES:
		result.global_u8[str(index)] = input.global_u8[str(index)]
	return result


func _eventb03_input(input: Dictionary) -> Dictionary:
	return {
		"state_u16_7": input.state_u16["7"],
		"state_u16_19": input.state_u16["19"],
		"banked_u16_210": input.banked_u16_0["210"],
		"global_u8_207": input.global_u8["207"],
		"global_u8_333": input.global_u8["333"],
		"global_u8_200": input.global_u8["200"],
		"global_u8_400": input.global_u8["400"],
		"global_u8_205": input.global_u8["205"],
		"global_u8_631": input.global_u8["631"],
		"state_u16_12": input.state_u16["12"],
		"global_u8_628": input.global_u8["628"],
	}


func _set_flat_binding(input: Dictionary, key: String, value: int) -> void:
	var pieces := key.split("_")
	var index := str(pieces[-1])
	if key.begins_with("state_u16_"):
		input.state_u16[index] = value
	elif key.begins_with("banked_u16_"):
		input.banked_u16_0[index] = value
	elif key.begins_with("global_u8_"):
		input.global_u8[index] = value


func _assert_plan(payload: PackedByteArray, input: Dictionary, oracle: Dictionary, label: String) -> Dictionary:
	var input_before := JSON.stringify(input)
	var source_before := ContractValues.sha256(payload)
	var priority_input := _priority_input(input)
	var priority_plan: Dictionary = _priority_plans.build(payload, priority_input)
	_check(priority_plan.get("ok", false), "%s priority child failed" % label)
	if not priority_plan.get("ok", false):
		return {}
	_check(_priority_plans.validate(payload, priority_plan).get("ok", false), "%s priority child failed replay" % label)
	_check(priority_plan.input == priority_input, "%s priority input projection changed" % label)
	_check(priority_plan.evaluation.evaluated_guards == oracle.priority_outcomes, "%s priority child disagrees with independent source oracle" % label)
	_check(int(priority_plan.evaluation.first_true_order) == int(oracle.upstream_first_true_order), "%s priority first-true result changed" % label)

	var eventb03_input := _eventb03_input(input)
	var eventb03_plan: Variant = null
	if oracle.eventb03_evaluated:
		eventb03_plan = _eventb03_plans.build(payload, eventb03_input)
		_check(eventb03_plan.get("ok", false), "%s EVENTB03 child failed" % label)
		if not eventb03_plan.get("ok", false):
			return {}
		_check(_eventb03_plans.validate(payload, eventb03_plan).get("ok", false), "%s EVENTB03 child failed replay" % label)
		_check(eventb03_plan.input == eventb03_input, "%s EVENTB03 input projection changed" % label)
		_check(int(eventb03_plan.candidate.value) == int(oracle.eventb03_value), "%s EVENTB03 child disagrees with independent source oracle" % label)

	var plan: Dictionary = _decision_plans.build(payload, input)
	_check(plan.get("ok", false), "%s decision plan failed: %s" % [label, plan.get("error", "")])
	if not plan.get("ok", false):
		return {}
	_check(_has_exact_keys(plan, ["ok", "schema", "producer", "source", "required_input", "input", "children", "decision", "execution"]), "%s root key set changed" % label)
	_check(plan.schema == Version.MES_STATION_EVENTB03_DECISION_PLAN_SCHEMA, "%s schema changed" % label)
	_check(plan.producer == {
		"core_version": Version.CORE_VERSION,
		"priority_plan_schema": Version.MES_STATION_CANDIDATE_PRIORITY_PLAN_SCHEMA,
		"eventb03_plan_schema": Version.MES_EVENTB03_CANDIDATE_PLAN_SCHEMA,
	}, "%s producer changed" % label)
	_check(plan.source == {
		"archive": "mes.arc", "entry": "01M.MES", "entry_sha256": STATION_SHA256,
		"bytecode_sha256": STATION_BYTECODE_SHA256, "offset_basis": "code_start",
		"priority_offset": 0x026D, "priority_join_offset": 0x7691,
		"eventb03_guard_offset": 0x7691,
		"child_structural_authority": "source_bound_child_validation",
	}, "%s source qualification changed" % label)
	_check(plan.required_input == _required_input_descriptor(), "%s 79-cell descriptor changed" % label)
	_check(plan.input == input, "%s normalized input changed" % label)

	var expected_priority_receipt := {
		"schema": Version.MES_STATION_CANDIDATE_PRIORITY_PLAN_SCHEMA,
		"source_bound": true,
		"plan_sha256": _value_sha256(priority_plan),
		"input_sha256": _value_sha256(priority_input),
		"evaluated_guard_count": priority_plan.evaluation.evaluated_guards.size(),
		"first_true_order": int(priority_plan.evaluation.first_true_order),
		"all_upstream_false": bool(priority_plan.evaluation.all_upstream_false),
		"selected_boundary": priority_plan.selected_boundary,
	}
	_check(plan.children.priority == expected_priority_receipt, "%s priority child receipt changed" % label)
	var expected_eventb03_receipt: Dictionary
	var expected_outcome: String
	var expected_boundary: Dictionary
	if oracle.eventb03_evaluated:
		expected_boundary = eventb03_plan.selected_boundary
		expected_outcome = "eventb03_guard_matched" if int(oracle.eventb03_value) == 1 else "eventb03_guard_rejected"
		expected_eventb03_receipt = {
			"schema": Version.MES_EVENTB03_CANDIDATE_PLAN_SCHEMA,
			"status": "evaluated",
			"source_bound": true,
			"plan_sha256": _value_sha256(eventb03_plan),
			"input_sha256": _value_sha256(eventb03_input),
			"matched": int(oracle.eventb03_value) == 1,
			"value": int(oracle.eventb03_value),
			"selected_boundary": expected_boundary,
		}
	else:
		expected_boundary = priority_plan.selected_boundary
		expected_outcome = "eventb03_preempted_by_upstream_guard"
		expected_eventb03_receipt = {
			"schema": Version.MES_EVENTB03_CANDIDATE_PLAN_SCHEMA,
			"status": "not_evaluated",
			"reason": "eventb03_preempted_by_upstream_guard",
			"source_bound": false,
			"plan_sha256": "not_computed",
			"input_sha256": _value_sha256(eventb03_input),
		}
	_check(plan.children.eventb03 == expected_eventb03_receipt, "%s EVENTB03 child receipt changed" % label)
	_check(plan.decision == {
		"outcome": expected_outcome,
		"priority_first_true_order": int(oracle.upstream_first_true_order),
		"eventb03_evaluated": bool(oracle.eventb03_evaluated),
		"selected_boundary": expected_boundary,
	}, "%s composed decision or selected boundary changed" % label)
	_check(plan.execution == {
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
	}, "%s promoted execution, prefix completion, or native eligibility" % label)
	_check(_decision_plans.validate(payload, plan).get("ok", false), "%s decision failed source replay" % label)
	var reloaded: Variant = JSON.parse_string(JSON.stringify(plan))
	_check(reloaded is Dictionary and _decision_plans.validate(payload, reloaded).get("ok", false), "%s decision failed JSON replay" % label)
	_check(_decision_plans.build(payload, input) == plan, "%s decision rebuild is nondeterministic" % label)
	_check(JSON.stringify(input) == input_before and ContractValues.sha256(payload) == source_before, "%s changed input or source bytes" % label)
	return plan


func _validate_rejections(payload: PackedByteArray) -> void:
	var input := _eventb03_union_input()
	var plan: Dictionary = _decision_plans.build(payload, input)
	if not plan.get("ok", false):
		return
	var mutations := [
		[["schema"], "unqualified"],
		[["source", "priority_join_offset"], 0x76F1],
		[["required_input", "total_unique_cells"], 78],
		[["input", "state_u16", "7"], 414],
		[["children", "priority", "plan_sha256"], "unqualified"],
		[["children", "priority", "all_upstream_false"], false],
		[["children", "eventb03", "input_sha256"], "unqualified"],
		[["children", "eventb03", "matched"], false],
		[["decision", "outcome"], "natural_event"],
		[["decision", "selected_boundary", "target_start_coordinate"], 0],
		[["execution", "eventb03_body_execution"], true],
		[["execution", "script_handoff_execution"], true],
		[["execution", "frozen_state_preemption"], "unqualified"],
		[["execution", "prefix_completion"], "complete"],
		[["execution", "host_zero_start"], 0],
		[["execution", "native_address_row_selection"], "row_69"],
		[["execution", "natural_scheduler_eligibility"], "qualified"],
		[["execution", "product_preset_widening"], true],
	]
	for mutation in mutations:
		var changed: Dictionary = plan.duplicate(true)
		var target: Variant = changed
		var path: Array = mutation[0]
		for index in range(path.size() - 1):
			target = target[path[index]]
		target[path[-1]] = mutation[1]
		var before := JSON.stringify(changed)
		_check(not _decision_plans.validate(payload, changed).get("ok", true) and JSON.stringify(changed) == before, "mutated decision accepted or rewritten: %s" % str(path))
	var preempt_input := _priority_witness(0)
	var preempt_plan: Dictionary = _decision_plans.build(payload, preempt_input)
	if preempt_plan.get("ok", false):
		var fabricated: Dictionary = preempt_plan.duplicate(true)
		fabricated.children.eventb03.status = "evaluated"
		fabricated.children.eventb03.source_bound = true
		_check(not _decision_plans.validate(payload, fabricated).get("ok", true), "preempted decision accepted fabricated EVENTB03 evaluation")
	var extra: Dictionary = plan.duplicate(true)
	extra["product_preset"] = "widened"
	_check(not _decision_plans.validate(payload, extra).get("ok", true), "decision accepted product-preset widening metadata")
	var missing: Dictionary = plan.duplicate(true)
	missing.erase("execution")
	_check(not _decision_plans.validate(payload, missing).get("ok", true), "decision accepted a missing execution boundary")

	var invalid_inputs := []
	var invalid := input.duplicate(true)
	invalid.erase("global_u8")
	invalid_inputs.append(invalid)
	invalid = input.duplicate(true)
	invalid["extra"] = {}
	invalid_inputs.append(invalid)
	invalid = input.duplicate(true)
	invalid.global_u8.erase("631")
	invalid_inputs.append(invalid)
	invalid = input.duplicate(true)
	invalid.global_u8["631"] = true
	invalid_inputs.append(invalid)
	invalid = input.duplicate(true)
	invalid.state_u16["12"] = 100.0
	invalid_inputs.append(invalid)
	invalid = input.duplicate(true)
	invalid.global_u8["631"] = 256
	invalid_inputs.append(invalid)
	invalid = input.duplicate(true)
	invalid.state_u16["12"] = -1
	invalid_inputs.append(invalid)
	for rejected in invalid_inputs:
		var before := JSON.stringify(rejected)
		_check(not _decision_plans.build(payload, rejected).get("ok", true) and JSON.stringify(rejected) == before, "malformed 79-cell input accepted or rewritten")
	var document: Dictionary = ContainerScript.new().parse(payload)
	var changed_payload := payload.duplicate()
	changed_payload[int(document.header.code_offset) + 0x7691] ^= 1
	_check(not _decision_plans.build(changed_payload, input).get("ok", true) and not _decision_plans.validate(changed_payload, plan).get("ok", true), "changed 01M.MES source accepted")
	_check(not _decision_plans.build(payload.slice(0, payload.size() - 1), input).get("ok", true), "truncated 01M.MES source accepted")
	_check(_decision_plans.validate(payload, plan).get("ok", false), "negative probes contaminated the original decision")


func _required_input_descriptor() -> Dictionary:
	return {
		"state_u16": STATE_U16_INDICES,
		"banked_u16_0": BANKED_U16_INDICES,
		"global_u8": GLOBAL_U8_INDICES,
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


func _value_sha256(value: Variant) -> String:
	return ContractValues.sha256(JSON.stringify(value, "", true, true).to_utf8_buffer())


func _expected_priority_signature(order: int) -> Variant:
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
		var row: Array = PRIORITY_GUARDS[order]
		return ["logical_or", _schedule_signature(int(row[4]), int(row[5]), int(row[6]), "equal"), _schedule_signature(int(row[4]), int(row[5]), int(row[6]), "greater_than")]
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
	return _left_and([
		["equal", _state_ref("state_u16", 4), 0],
		["greater_than", _state_ref("state_u16", 19), 1100],
		["less_than", _state_ref("state_u16", 19), 1700],
		["equal", _state_ref("global_u8", 110), 1],
		["equal", _state_ref("global_u8", 117), 0],
		["equal", _state_ref("global_u8", 1188), 1],
		["equal", _state_ref("global_u8", 1189), 0],
	])


func _expected_eventb03_signature() -> Variant:
	return _left_and([
		["greater_than", _state_ref("state_u16", 7), 400],
		["less_than", _state_ref("state_u16", 7), 616],
		["greater_than", _state_ref("state_u16", 19), 1800],
		["less_than", _state_ref("state_u16", 19), 2001],
		["greater_than", _state_ref("banked_u16", 210), 40],
		["less_than", _state_ref("banked_u16", 210), 80],
		["not_equal", _state_ref("global_u8", 207), 2],
		["equal", _state_ref("global_u8", 333), 0],
		["equal", _state_ref("global_u8", 200), 0],
		["equal", _state_ref("global_u8", 400), 1],
		["equal", _state_ref("global_u8", 205), 0],
		["equal", _state_ref("global_u8", 631), 0],
		["not_equal", _state_ref("state_u16", 12), 0],
		["equal", _state_ref("global_u8", 628), 0],
	])


func _schedule_signature(date_index: int, time_index: int, base: int, time_operation: String) -> Variant:
	return _left_and([
		["equal", _state_ref("state_u16", 7), _state_ref("banked_u16", date_index)],
		["equal", _state_ref("global_u8", base), 1],
		["equal", _state_ref("global_u8", base + 7), 2],
		[time_operation, _state_ref("state_u16", 19), _state_ref("banked_u16", time_index)],
		["greater_than", _state_ref("global_u8", base + 9), 8],
		["not_equal", _state_ref("global_u8", base + 9), 14],
	])


func _left_and(conditions: Array) -> Variant:
	var result: Variant = conditions[0]
	for index in range(1, conditions.size()):
		result = ["logical_and", result, conditions[index]]
	return result


func _state_ref(storage: String, index: Variant) -> Array:
	return ["state_ref", storage, 0, index]


func _signature(ast: Dictionary, depth := 0) -> Variant:
	if depth > 32:
		return null
	match str(ast.get("type", "")):
		"literal": return ast.get("value")
		"state_ref": return ["state_ref", str(ast.get("storage", "")), int(ast.get("bank", -1)), _signature(ast.get("index", {}), depth + 1)]
		"binary": return [str(ast.get("op", "")), _signature(ast.get("lhs", {}), depth + 1), _signature(ast.get("rhs", {}), depth + 1)]
	return null


func _record(code: PackedByteArray, offset: int, expected_end: int, operation: String) -> Dictionary:
	var record: Dictionary = _decoder.decode_at_structural(code, offset, expected_end)
	var valid: bool = bool(record.get("ok", false)) and str(record.get("op", "")) == operation and int(record.get("end_offset", -1)) == expected_end
	_check(valid, "%s record boundary changed at 0x%X" % [operation, offset])
	return record if valid else {}


func _has_exact_keys(value: Dictionary, expected: Array) -> bool:
	if value.size() != expected.size():
		return false
	for key in value:
		if typeof(key) != TYPE_STRING or key not in expected:
			return false
	return true


func _check(value: bool, message: String) -> void:
	_checks += 1
	if not value:
		_failures.append(message)
