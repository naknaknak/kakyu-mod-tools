extends Node

const PlanScript := preload("res://content_core/mes_eventb03_candidate_plan.gd")
const ContainerScript := preload("res://content_core/mes_container.gd")
const Version := preload("res://content_core/content_core_version.gd")

const ENTRY_END := 0x02AF
const HANDOFF_END := 0x020E
const FALSE_BOUNDARY := 0x0218

var _checks := 0
var _failed := false


func _ready() -> void:
	var planner := PlanScript.new()
	var fixture := _fixture()
	_test_inspection(planner, fixture)
	_test_evaluation(planner, fixture)
	_test_structural_rejections(planner, fixture)
	_test_public_source_boundary(planner, fixture)
	_test_json_contract(planner)
	print("EVENTB03 candidate plan synthetic checks: ", _checks)
	await get_tree().process_frame
	get_tree().quit(1 if _failed else 0)


func _test_inspection(planner: RefCounted, fixture: Dictionary) -> void:
	var code: PackedByteArray = fixture.code
	var before := code.duplicate()
	var inspected: Dictionary = planner.call("_inspect", code, 0, code.size())
	_check(inspected.get("ok", false), "source-shaped candidate arm is structurally accepted")
	_check(inspected.get("guard", {}) == {
		"offset": 0,
		"end_offset": 0x60,
		"false_offset": FALSE_BOUNDARY,
		"sha256": _sha256(code.slice(0, 0x60)),
		"unique_state_reference_count": 11,
		"predicate_signature": planner.call("_expected_guard_signature"),
	}, "guard retains its exact interval, false boundary and unique state-reference count")
	var true_path: Dictionary = inspected.get("true_path", {})
	_check(true_path.get("offset", -1) == 0x60 and true_path.get("end_offset", -1) == HANDOFF_END and str(true_path.get("sha256", "")) == _sha256(code.slice(0x60, HANDOFF_END)), "true arm is one bounded source slice")
	_check(true_path.get("routine23_request", {}) == {"argument_offset": 0x6A, "call_offset": 0x72, "routine_id": 23, "selector": 133}, "routine 23 retains selector 133 without executing audio")
	var dialogues: Array = true_path.get("dialogues", [])
	_check(dialogues.size() == 4 and dialogues.map(func(row): return row.entry_index) == [66, 67, 68, 69], "entry labels 66 through 69 remain ordered source checkpoints")
	_check(dialogues.map(func(row): return row.message_id) == [66, 67, 68, 69] and dialogues.map(func(row): return row.routine_offset) == [0xCF, 0x14B, 0x199, 0x1F4], "each entry retains its matching routine-0 message record")
	_check(dialogues.map(func(row): return row.trailer_offset) == [0xC2, 0x13E, 0x18C, 0x1E7] and dialogues.map(func(row): return row.resume_offset) == [0xC9, 0x145, 0x193, 0x1EE], "all four dialoguetrailers retain exact physical resumes")
	var sanitized := true
	for dialogue in dialogues:
		for forbidden in ["text", "raw_hex", "raw_bytes", "message"]:
			sanitized = sanitized and not dialogue.has(forbidden)
	_check(sanitized and dialogues[-1].protagonist_name_insert and not dialogues[0].protagonist_name_insert, "dialogue checkpoints expose structure without copying original text")
	_check(true_path.get("voice", {}) == {
		"set_offset": 0xD9, "set_end_offset": 0xE6,
		"storage": "banked_u16", "bank": 0, "index": 2,
		"set_operation": "bit_or", "set_mask": 128,
		"marker_offset": 0xE6, "marker_end_offset": 0xFB, "entry": "B0001.OGG",
		"clear_offset": 0xFB, "clear_end_offset": 0x108,
		"clear_operation": "bit_and", "clear_mask": 65407,
	}, "voice checkpoint retains its bounded set/marker/clear span")
	_check(true_path.get("handoff", {}) == {
		"kind": "script_handoff_boundary", "offset": 0x1FE, "end_offset": 0x20E,
		"command": 0x0E, "target_entry": "EVENTB03.MES",
		"target_start_coordinate": "not_encoded", "caller_frame": "not_encoded",
		"sha256": _sha256(code.slice(0x1FE, 0x20E)),
	}, "command 0E handoff is retained without inventing a target coordinate or caller frame")
	_check(inspected.get("excluded_tail", {}) == {
		"kind": "excluded_after_script_handoff", "offset": HANDOFF_END,
		"end_offset": ENTRY_END, "sha256": _sha256(code.slice(HANDOFF_END, ENTRY_END)),
		"tool_executed": false, "native_post_handoff": "unresolved",
	}, "declared entry-69 tail is hash-preserved and excluded by tool policy without claiming native behavior")
	_check(inspected.has("guard_ast") and code == before, "private inspection retains its evaluation AST without changing source bytes")


func _test_evaluation(planner: RefCounted, fixture: Dictionary) -> void:
	var inspected: Dictionary = planner.call("_inspect", fixture.code, 0, fixture.code.size())
	var ast: Dictionary = inspected.get("guard_ast", {})
	var input := _candidate_input()
	var input_before := input.duplicate(true)
	var accepted: Dictionary = planner.call("_evaluate", ast, input)
	_check(accepted == {"ok": true, "value": 1, "candidate": true} and input == input_before, "exact source state evaluates to one without input mutation")
	for row in [
		["state_u16_7", 400], ["state_u16_7", 616],
		["state_u16_19", 1800], ["state_u16_19", 2001],
		["banked_u16_210", 40], ["banked_u16_210", 80],
		["global_u8_207", 2], ["global_u8_333", 1],
		["global_u8_200", 1], ["global_u8_400", 0],
		["global_u8_205", 1], ["global_u8_631", 1],
		["state_u16_12", 0], ["global_u8_628", 1],
	]:
		var changed := input.duplicate(true)
		changed[row[0]] = row[1]
		var changed_before := changed.duplicate(true)
		var rejected: Dictionary = planner.call("_evaluate", ast, changed)
		_check(rejected == {"ok": true, "value": 0, "candidate": false} and changed == changed_before, "%s=%d takes the exact false boundary" % [row[0], row[1]])
	for row in [
		["state_u16_7", 401], ["state_u16_7", 615],
		["state_u16_19", 1801], ["state_u16_19", 2000],
		["banked_u16_210", 41], ["banked_u16_210", 79],
		["global_u8_207", 1], ["global_u8_207", 255],
		["state_u16_12", 1], ["state_u16_12", 65535],
	]:
		var changed := input.duplicate(true)
		changed[row[0]] = row[1]
		_check(planner.call("_evaluate", ast, changed).get("candidate", false), "%s=%d remains inside its exact true interval" % [row[0], row[1]])
	for mutation in [
		{"label": "missing key", "erase": "global_u8_628"},
		{"label": "extra key", "add": ["extra", 0]},
		{"label": "numeric key", "add": [7, 0], "erase": "global_u8_628"},
		{"label": "float", "set": ["state_u16_7", 413.0]},
		{"label": "fraction", "set": ["state_u16_7", 413.5]},
		{"label": "boolean", "set": ["global_u8_207", false]},
		{"label": "string", "set": ["state_u16_12", "100"]},
		{"label": "negative", "set": ["state_u16_12", -1]},
		{"label": "wide u16", "set": ["state_u16_12", 65536]},
		{"label": "wide u8", "set": ["global_u8_207", 256]},
	]:
		var changed := input.duplicate(true)
		if mutation.has("erase"):
			changed.erase(mutation.erase)
		if mutation.has("add"):
			changed[mutation.add[0]] = mutation.add[1]
		if mutation.has("set"):
			changed[mutation.set[0]] = mutation.set[1]
		var changed_before := changed.duplicate(true)
		_check(not planner.call("_evaluate", ast, changed).get("ok", true) and changed == changed_before, "%s source input rejects without coercion or mutation" % mutation.label)
	var changed_ast := ast.duplicate(true)
	changed_ast["op"] = "logical_or"
	_check(not planner.call("_evaluate", changed_ast, input).get("ok", true), "equivalent-looking but non-source guard AST rejects")


func _test_structural_rejections(planner: RefCounted, fixture: Dictionary) -> void:
	var code: PackedByteArray = fixture.code
	for mutation in [
		[0x002, 8, "guard state reference"],
		[0x06E, 134, "routine-23 selector"],
		[0x074, 24, "routine-23 call"],
		[0x082, 67, "entry-66 label"],
		[0x0C9 + 3, 67, "entry-66 message ID"],
		[0x0CF + 2, 1, "entry-66 routine"],
		[0x0D9 + 8, 129, "voice span set mask"],
		[0x0E6 + 7, 0x0E, "voice-name payload shadow"],
		[0x0FB + 8, 0x7E, "voice span clear mask"],
		[0x1AD + 4, 0xF8, "protagonist-name state storage"],
		[0x1FE, 0x0F, "handoff command"],
		[0x1FE + 2, 0x78, "handoff target"],
	]:
		var changed := code.duplicate()
		changed[int(mutation[0])] = int(mutation[1])
		_rejected_inspection(planner, changed, code.size(), "%s mutation" % mutation[2])
	var false_target := code.duplicate()
	false_target.encode_u32(0x5C, FALSE_BOUNDARY - 1)
	_rejected_inspection(planner, false_target, code.size(), "false branch target drift")
	var trailer := code.duplicate()
	trailer[0xC7] = 0x0E
	_rejected_inspection(planner, trailer, code.size(), "dialogue trailer payload shadow")
	var branch_shadow := code.duplicate()
	branch_shadow[0x86] = 0x0B
	_rejected_inspection(planner, branch_shadow, code.size(), "text payload reframed as a branch")
	for size in [0, 0x5F, 0x60, 0xC5, 0x1FE, 0x20D, ENTRY_END - 1]:
		var truncated := code.duplicate()
		truncated.resize(size)
		_rejected_inspection(planner, truncated, ENTRY_END, "truncated source at 0x%X" % size)
	for bounds in [[-1, ENTRY_END], [1, ENTRY_END], [0, ENTRY_END - 1], [0, ENTRY_END + 1]]:
		if bounds[0] == 0:
			_rejected_inspection(planner, code, bounds[1], "invalid source-local bounds %s" % [bounds])
		else:
			_check(not planner.call("_inspect", code, bounds[0], bounds[1]).get("ok", true), "invalid source-local bounds %s reject" % [bounds])
	var tail_changed := code.duplicate()
	tail_changed[ENTRY_END - 1] = 0x7E
	var tail_plan: Dictionary = planner.call("_inspect", tail_changed, 0, ENTRY_END)
	var original_plan: Dictionary = planner.call("_inspect", code, 0, ENTRY_END)
	_check(tail_plan.get("ok", false) and tail_plan.excluded_tail.sha256 != original_plan.excluded_tail.sha256 and not tail_plan.excluded_tail.tool_executed and tail_plan.excluded_tail.native_post_handoff == "unresolved", "post-handoff tail changes only its preserved hash and remains outside tool execution")
	_check(code == fixture.code, "all rejection probes preserve the original synthetic source")


func _test_public_source_boundary(planner: RefCounted, fixture: Dictionary) -> void:
	var fixture_code: PackedByteArray = fixture.code
	var payload: PackedByteArray = PackedByteArray([0, 0, 0, 0]) + fixture_code
	var payload_before: PackedByteArray = payload.duplicate()
	var input: Dictionary = _candidate_input()
	var input_before: Dictionary = input.duplicate(true)
	_check(ContainerScript.new().parse(payload).get("ok", false), "synthetic source is independently valid MES framing")
	var rejected: Dictionary = planner.build(payload, input)
	_check(not rejected.get("ok", true) and payload == payload_before and input == input_before, "public build rejects structurally valid synthetic bytes without claiming original evidence")
	for invalid in [null, true, "state", [], 7, 7.0, INF, NAN]:
		var invalid_result: Dictionary = planner.build(payload, invalid)
		_check(not invalid_result.get("ok", true) and payload == payload_before, "public build rejects a non-dictionary source state")
	for untyped_forged in [{}, {"input": _candidate_input()}, {"ok": true, "schema": Version.MES_EVENTB03_CANDIDATE_PLAN_SCHEMA, "input": _candidate_input()}]:
		var forged: Dictionary = untyped_forged
		var before: Dictionary = forged.duplicate(true)
		_check(not planner.validate(payload, forged).get("ok", true) and forged == before and payload == payload_before, "public validation rejects a forged synthetic plan without mutation")


func _test_json_contract(planner: RefCounted) -> void:
	var expected := {
		"ok": true,
		"schema": Version.MES_EVENTB03_CANDIDATE_PLAN_SCHEMA,
		"input": _candidate_input(),
		"candidate": {"matched": true, "value": 1, "next_offset": 0x76F1},
		"selected_boundary": {"kind": "script_handoff_boundary", "offset": 0x788F, "caller_frame": "not_encoded"},
		"dialogues": [{"entry_index": 66, "resume_offset": 0x775A}],
	}
	var encoded := JSON.stringify(expected)
	var parsed: Dictionary = JSON.parse_string(encoded)
	var parsed_before := JSON.stringify(parsed)
	_check(planner.call("_same_plan_value", parsed, expected), "JSON integral floats and nested arrays compare exactly")
	for row in [
		[["input", "state_u16_7"], 413.5],
		[["input", "state_u16_7"], "413"],
		[["candidate", "value"], false],
		[["selected_boundary", "caller_frame"], false],
		[["dialogues", 0, "entry_index"], INF],
		[["dialogues"], []],
	]:
		var changed := parsed.duplicate(true)
		var target: Variant = changed
		for index in range(row[0].size() - 1):
			target = target[row[0][index]]
		target[row[0][-1]] = row[1]
		_check(not planner.call("_same_plan_value", changed, expected), "JSON value, type, finiteness or array shape drift rejects")
	var extra := parsed.duplicate(true)
	var missing := parsed.duplicate(true)
	extra["unqualified"] = 1
	missing.erase("schema")
	_check(not planner.call("_same_plan_value", extra, expected) and not planner.call("_same_plan_value", missing, expected), "JSON comparison rejects extra and missing keys")
	var cycle := {}
	var expected_cycle := {}
	cycle["self"] = cycle
	expected_cycle["self"] = expected_cycle
	_check(not planner.call("_same_plan_value", cycle, expected_cycle), "cyclic dictionaries fail closed at the depth limit")
	cycle.clear()
	expected_cycle.clear()
	_check(JSON.stringify(expected) == encoded and JSON.stringify(parsed) == parsed_before, "JSON comparison leaves both values unchanged")


func _fixture() -> Dictionary:
	var code := PackedByteArray()
	code.resize(ENTRY_END)
	var guard := _guard(FALSE_BOUNDARY)
	_check(guard.size() == 0x60, "independent guard fixture has the audited record length")
	_put(code, 0x000, guard)
	_put(code, 0x060, _line(1050))
	_put(code, 0x065, _line(1051))
	_put(code, 0x06A, _argument(133))
	_put(code, 0x072, _routine(23))
	_put(code, 0x077, _line(1052))
	_put(code, 0x07C, _line(1053))
	_put(code, 0x081, _label(66))
	_put(code, 0x086, _text(0x3C))
	_put(code, 0x0C2, PackedByteArray([0x0D, 0x13, 0xFF, 0x02, 0x02, 0xFF, 0x00]))
	_put(code, 0x0C9, _argument(66))
	_put(code, 0x0CF, _routine(0))
	_put(code, 0x0D4, _line(1055))
	_put(code, 0x0D9, _span("bit_or"))
	_put(code, 0x0E6, _voice())
	_put(code, 0x0FB, _span("bit_and"))
	_put(code, 0x108, _line(1056))
	_put(code, 0x10D, _label(67))
	_put(code, 0x112, _text(0x2C))
	_put(code, 0x13E, PackedByteArray([0x0D, 0x13, 0xFF, 0x02, 0x02, 0xFF, 0x00]))
	_put(code, 0x145, _argument(67))
	_put(code, 0x14B, _routine(0))
	_put(code, 0x150, _line(1058))
	_put(code, 0x155, _label(68))
	_put(code, 0x15A, _text(0x32))
	_put(code, 0x18C, PackedByteArray([0x0D, 0x13, 0xFF, 0x02, 0x02, 0xFF, 0x00]))
	_put(code, 0x193, _argument(68))
	_put(code, 0x199, _routine(0))
	_put(code, 0x19E, _line(1060))
	_put(code, 0x1A3, _label(69))
	_put(code, 0x1A8, _text(4))
	_put(code, 0x1AC, PackedByteArray([0x0D]))
	_put(code, 0x1AD, PackedByteArray([0x0E, 0xFF, 0x02, 0x00, 0xF9, 0x00, 0x00, 0xA0, 0x00, 0xE0, 0xF1, 0x40, 0x0B, 0xE0, 0xFF, 0x00]))
	_put(code, 0x1BD, _text(0x2A))
	_put(code, 0x1E7, PackedByteArray([0x0D, 0x13, 0xFF, 0x02, 0x02, 0xFF, 0x00]))
	_put(code, 0x1EE, _argument(69))
	_put(code, 0x1F4, _routine(0))
	_put(code, 0x1F9, _line(1062))
	_put(code, 0x1FE, PackedByteArray([0x0E, 0x01]) + "eventb03.mes".to_ascii_buffer() + PackedByteArray([0x00, 0x00]))
	return {"code": code}


func _candidate_input() -> Dictionary:
	return {
		"state_u16_7": 413,
		"state_u16_19": 1825,
		"banked_u16_210": 50,
		"global_u8_207": 0,
		"global_u8_333": 0,
		"global_u8_200": 0,
		"global_u8_400": 1,
		"global_u8_205": 0,
		"global_u8_631": 0,
		"state_u16_12": 100,
		"global_u8_628": 0,
	}


func _guard(false_target: int) -> PackedByteArray:
	var conditions: Array[PackedByteArray] = [
		_state_u16(7) + _literal(400) + PackedByteArray([0xEC]),
		_state_u16(7) + _literal(616) + PackedByteArray([0xEB]),
		_state_u16(19) + _literal(1800) + PackedByteArray([0xEC]),
		_state_u16(19) + _literal(2001) + PackedByteArray([0xEB]),
		_banked_u16(210) + _literal(40) + PackedByteArray([0xEC]),
		_banked_u16(210) + _literal(80) + PackedByteArray([0xEB]),
		_global_u8(207) + _literal(2) + PackedByteArray([0xF0]),
		_global_u8(333) + _literal(0) + PackedByteArray([0xEF]),
		_global_u8(200) + _literal(0) + PackedByteArray([0xEF]),
		_global_u8(400) + _literal(1) + PackedByteArray([0xEF]),
		_global_u8(205) + _literal(0) + PackedByteArray([0xEF]),
		_global_u8(631) + _literal(0) + PackedByteArray([0xEF]),
		_state_u16(12) + _literal(0) + PackedByteArray([0xF0]),
		_global_u8(628) + _literal(0) + PackedByteArray([0xEF]),
	]
	var expression := conditions[0].duplicate()
	for index in range(1, conditions.size()):
		expression.append_array(conditions[index])
		expression.append(0xE6)
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


func _line(value: int) -> PackedByteArray:
	var result := PackedByteArray([0x1F, 0, 0, 0, 0])
	result.encode_u32(1, value)
	return result


func _label(value: int) -> PackedByteArray:
	var result := PackedByteArray([0x17, 0, 0, 0, 0])
	result.encode_u32(1, value)
	return result


func _argument(value: int) -> PackedByteArray:
	return PackedByteArray([0x09, 0x01, 0x00]) + _literal(value) + PackedByteArray([0xFF, 0x00])


func _routine(value: int) -> PackedByteArray:
	return PackedByteArray([0x1D, 0x02]) + _literal(value) + PackedByteArray([0xFF, 0x00])


func _text(length: int) -> PackedByteArray:
	var result := PackedByteArray([0x01])
	for _index in range(int((length - 2) / 2)):
		result.append_array(PackedByteArray([0x82, 0xA0]))
	result.append(0x00)
	return result


func _span(operation: String) -> PackedByteArray:
	return (
		PackedByteArray([0x07, 0x02, 0xFF, 0x00, 0x02, 0xA0, 0x00, 0xF1, 0x80, 0x00, 0xE9, 0xFF, 0x00])
		if operation == "bit_or"
		else PackedByteArray([0x07, 0x02, 0xFF, 0x00, 0x02, 0xA0, 0x00, 0xF1, 0x7F, 0xFF, 0xE8, 0xFF, 0x00])
	)


func _voice() -> PackedByteArray:
	return PackedByteArray([0x0D, 0x07, 0xFF, 0x02, 0x02, 0xFF, 0x01]) + "b0001.ogg".to_ascii_buffer() + PackedByteArray([0x00, 0x02, 0x00, 0xFF, 0x00])


func _put(target: PackedByteArray, offset: int, value: PackedByteArray) -> void:
	for index in range(value.size()):
		target[offset + index] = value[index]


func _rejected_inspection(planner: RefCounted, code: PackedByteArray, entry_end: int, label: String) -> void:
	var before := code.duplicate()
	var rejected: Dictionary = planner.call("_inspect", code, 0, entry_end)
	_check(not rejected.get("ok", true) and not str(rejected.get("error", "")).is_empty() and code == before, label + " rejects without source mutation")


func _sha256(data: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(data)
	return context.finish().hex_encode()


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("PASS: ", label)
	else:
		_failed = true
		push_error("FAIL: " + label)
