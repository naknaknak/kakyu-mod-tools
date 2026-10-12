extends Node

const PlanScript := preload("res://content_core/mes_mahoko_standing_plan.gd")
const ContainerScript := preload("res://content_core/mes_container.gd")
const Decoder := preload("res://content_core/mes_instruction_decoder.gd")
const State := preload("res://content_core/mes_sandbox_state.gd")

var _checks := 0
var _failed := false


func _ready() -> void:
	var planner := PlanScript.new()
	_test_selection(planner)
	_test_rejected_guards(planner)
	_test_rejected_producers(planner)
	_test_public_boundary(planner)
	_test_json_comparison(planner)
	print("Mahoko standing plan synthetic checks: ", _checks)
	await get_tree().process_frame
	get_tree().quit(1 if _failed else 0)


func _test_selection(planner: RefCounted) -> void:
	for name in ["B1.MMO", "B2.MMO", "B3.MMO", "B4.MMO"]:
		var block := _producer(name)
		var code: PackedByteArray = block.code
		_assert_selection(planner.call("_select", code, 0, code.size(), 413), code, block, 0, [], name)
	for row in [
		[PackedByteArray([1]), 413, 1], [PackedByteArray([0]), 413, 0],
		[PackedByteArray([2]), 413, 2], [_literal(65535), 413, 65535],
		[PackedByteArray([2, 1, 0xE6]), 413, 0], [PackedByteArray([2, 0, 0xE7]), 413, 0],
		[PackedByteArray([2, 1, 0xE7]), 413, 1], [PackedByteArray([2, 2, 0xEF, 1, 0xE6]), 413, 1],
		[PackedByteArray([0xF3, 206, 0, 1, 0xEF]), 413, 1],
		[PackedByteArray([0x80, 7]) + _literal(400) + PackedByteArray([0xEC, 0x80, 7]) + _literal(616) + PackedByteArray([0xEB, 0xE6]), 400, 0],
		[PackedByteArray([0x80, 7]) + _literal(400) + PackedByteArray([0xEC, 0x80, 7]) + _literal(616) + PackedByteArray([0xEB, 0xE6]), 401, 1],
		[PackedByteArray([0x80, 7]) + _literal(400) + PackedByteArray([0xEC, 0x80, 7]) + _literal(616) + PackedByteArray([0xEB, 0xE6]), 616, 0],
	]:
		var fixture := _branch_fixture(row[0])
		var code: PackedByteArray = fixture.code
		var before := code.duplicate()
		var result: Dictionary = planner.call("_select", code, 0, code.size(), row[1])
		var selected: int = fixture.true_offset if row[2] == 1 else fixture.false_offset
		var block: Dictionary = fixture.first if row[2] == 1 else fixture.second
		_assert_selection(result, code, block, selected, [{"offset": 0, "end_offset": fixture.true_offset, "value": row[2], "next_offset": selected}], "conditional producer")
		_check(code == before, "selection preserves source bytes")
	var block := _producer("B1.MMO")
	var lined: PackedByteArray = PackedByteArray([0x1F, 7, 0, 0, 0]) + block.code
	_assert_selection(planner.call("_select", lined, 0, lined.size(), 413), lined, block, 5, [], "source-line prefix is not a command payload")
	var shifted: PackedByteArray = PackedByteArray([0xFF, 0xFF, 0xFF]) + block.code
	_assert_selection(planner.call("_select", shifted, 3, shifted.size(), 413), shifted, block, 3, [], "nonzero bounded source start")
	var tail: PackedByteArray = block.code + PackedByteArray([0x03, 160, 15, 99, 0xFF, 0])
	var caller := State.new(71)
	caller.write_value("global_u8", 4000, 77)
	caller.write_value("banked_u16", 23, 4, 0)
	var snapshot := caller.snapshot()
	_assert_selection(planner.call("_select", tail, 0, tail.size(), 413), tail, block, 0, [], "routine22 is an unexecuted boundary")
	_check(caller.snapshot() == snapshot, "proof does not consume caller geometry, write global4000, or advance RNG")
	var no_selection := _branch(PackedByteArray([0]), 7)
	var joined: Dictionary = planner.call("_select", no_selection, 0, 7, 0)
	_check(joined.get("ok", false) and joined.get("selection", {"unexpected": true}).is_empty() and joined.get("copies", [1]).is_empty(), "exclusive face join means no standing load, not an invented blank image")
	_check(joined.get("boundary", {}) == {"kind": "face_join", "offset": 7, "end_offset": 7, "routine_id": -1}, "face join is a zero-length unexecuted pointer")


func _test_rejected_guards(planner: RefCounted) -> void:
	for expression in [
		PackedByteArray([0x80, 4]), PackedByteArray([0x80, 19]), PackedByteArray([0xF8, 7]),
		PackedByteArray([0xF3, 207, 0]), PackedByteArray([0xF6, 206, 0]),
		PackedByteArray([17, 0xA0, 0]), PackedByteArray([1, 1, 0xE0, 0xF5]),
		PackedByteArray([1, 0, 0xF0]), PackedByteArray([10, 0xE5]),
		PackedByteArray([0, 10, 0xE5, 0xE6]), PackedByteArray([1, 10, 0xE5, 0xE7]),
		PackedByteArray([1, 2]), PackedByteArray([0xE6]),
	]:
		var fixture := _branch_fixture(expression)
		_rejected(planner, fixture.code, 0, fixture.code.size(), "unsafe guard storage, expression or RNG")
	var fixture := _branch_fixture(PackedByteArray([0]))
	for target in [0, 1, fixture.true_offset + 12, fixture.code.size() + 1, 0xFFFFFFFF]:
		var code: PackedByteArray = fixture.code.duplicate()
		code.encode_u32(fixture.true_offset - 4, target)
		_rejected(planner, code, 0, code.size(), "loop, payload interior or escaped false edge")
	var cycle := _branch(PackedByteArray([0]), 7) + _branch(PackedByteArray([0]), 0)
	_rejected(planner, cycle, 0, cycle.size(), "two-record cycle")
	var deep := PackedByteArray([1])
	for _level in range(18):
		deep.append_array(PackedByteArray([1, 0xE6]))
	var deep_fixture := _branch_fixture(deep)
	_rejected(planner, deep_fixture.code, 0, deep_fixture.code.size(), "expression depth budget")
	var lines := PackedByteArray()
	for _line in range(33):
		lines.append_array(PackedByteArray([0x1F, 1, 0, 0, 0]))
	lines.append_array(_producer("B1.MMO").code)
	_rejected(planner, lines, 0, lines.size(), "prefix record budget")
	for bounds in [[-1, fixture.code.size()], [0, fixture.code.size() + 1], [0, 0], [3, 2]]:
		_rejected(planner, fixture.code, bounds[0], bounds[1], "invalid region")
	_rejected(planner, PackedByteArray(), 0, 0, "empty source")
	_rejected(planner, PackedByteArray([0x0C, 0, 0, 0, 0]), 0, 5, "unqualified continuation command")
	for date in [-1, 65536]:
		var result: Dictionary = planner.call("_select", fixture.code, 0, fixture.code.size(), date)
		_check(not result.get("ok", true), "selector rejects dates outside the unsigned-word domain")


func _test_rejected_producers(planner: RefCounted) -> void:
	var block := _producer("B1.MMO")
	var code: PackedByteArray = block.code
	for end in range(code.size()):
		_rejected(planner, code, 0, end, "truncated complete producer at %d" % end)
	for row in [
		[1, 2], [3, 1], [4, 1], [block.active + 1, 2], [block.active + 3, 1], [block.active + 4, 6],
		[block.outer, 0], [block.flag + 1, 161], [block.flag + 3, 0], [block.boundary + 2, 8],
	]:
		var changed := code.duplicate()
		changed[row[0]] = row[1]
		_rejected(planner, changed, 0, changed.size(), "producer write, surface or routine identity changed")
	for name in ["OTHER.MMO", "../B1.MMO", "B1.MES", "BAD/NAME.MMO", "BAD" + String.chr(7) + ".MMO"]:
		var invalid := _producer(name)
		_rejected(planner, invalid.code, 0, invalid.code.size(), "unqualified or unsafe resource name")
	for mode in range(2):
		var expressions := _copy_expressions(mode)
		for index in range(expressions.size()):
			var altered := expressions.duplicate(true)
			altered[index] = PackedByteArray([99])
			var invalid := _producer("B1.MMO", mode, altered)
			_rejected(planner, invalid.code, 0, invalid.code.size(), "symbolic copy operand %d/%d changed" % [mode, index])
	for replacement in [PackedByteArray([17, 0xA0, 1]), PackedByteArray([17, 0xC0, 0]), PackedByteArray([16, 1, 0xE0, 0xA0, 0]), PackedByteArray([10, 0xE5])]:
		var expressions := _copy_expressions(1)
		expressions[1] = replacement
		var invalid := _producer("B1.MMO", 1, expressions)
		_rejected(planner, invalid.code, 0, invalid.code.size(), "copy must preserve the exact qualified AST, not equivalent arithmetic or RNG")
	var run := code.slice(0, 6) + PackedByteArray([1, 99, 0xFF, 0]) + code.slice(7)
	_rejected(planner, run, 0, run.size(), "surface write run cannot hide an additional write")
	var shadow := code.duplicate()
	shadow[block.outer + 4] = 0x07
	_rejected(planner, shadow, 0, shadow.size(), "MMO payload cannot execute a shadow state command")


func _test_public_boundary(planner: RefCounted) -> void:
	var producer: PackedByteArray = _producer("B1.MMO").code
	var code := PackedByteArray()
	code.resize(0x0568)
	for index in range(producer.size()):
		code[0x02A5 + index] = producer[index]
	var payload := PackedByteArray([0, 0, 0, 0]) + code
	var before := payload.duplicate()
	_check(ContainerScript.new().parse(payload).get("ok", false) and planner.call("_select", code, 0x02A5, 0x0568, 413).get("ok", false), "source-hash fixture has valid framing and a valid independently constructed producer")
	var rejected: Dictionary = planner.build(payload, 413)
	_check(not rejected.get("ok", true) and payload == before, "public build rejects valid synthetic source without claiming original evidence")
	for value in [null, true, "413", -1, 65536, 413.0, 413.5, INF, NAN, [], {}]:
		var result: Dictionary = planner.build(payload, value)
		_check(not result.get("ok", true) and result != rejected and payload == before, "public input must be a strict unsigned-word integer")
	for plan in [{}, {"ok": true}, {"ok": true, "input": {"mmdd": 413, "g206": 1}, "source": {"entry_sha256": "d72612395e8571848a7782ff48d8c63604a09a983ae2c564f2ee5bd5ac2b4ada"}}]:
		var snapshot: Dictionary = plan.duplicate(true)
		_check(not planner.validate(payload, plan).get("ok", true) and plan == snapshot and payload == before, "forged source plans reject without mutation")


func _test_json_comparison(planner: RefCounted) -> void:
	var expressions: Array[Dictionary] = [{"type": "literal", "value": 0}, {"type": "state_ref", "index": {"type": "literal", "value": 23}, "bank": 0, "storage": "banked_u16"}]
	var expected := {"ok": true, "input": {"mmdd": 413, "g206": 1}, "copies": [{"mode": 0, "expressions": expressions}], "execution": {"state_mutation": false}, "empty": []}
	var encoded := JSON.stringify(expected)
	var parsed: Dictionary = JSON.parse_string(encoded)
	var parsed_encoded := JSON.stringify(parsed)
	_check(planner.call("_same_plan_value", parsed, expected), "JSON numeric floats and nested symbolic AST arrays round-trip exactly")
	for row in [
		[["input", "mmdd"], 413.5], [["input", "mmdd"], "413"], [["input", "g206"], true],
		[["copies", 0, "mode"], false], [["copies", 0, "expressions", 1, "bank"], 0.5],
		[["copies", 0, "expressions"], [parsed.copies[0].expressions[1], parsed.copies[0].expressions[0]]],
		[["copies", 0, "expressions"], []], [["execution", "state_mutation"], 0],
		[["ok"], 1], [["empty"], {}], [["input", "mmdd"], INF], [["input", "mmdd"], -INF], [["input", "mmdd"], NAN],
	]:
		var changed := parsed.duplicate(true)
		var target: Variant = changed
		for index in range(row[0].size() - 1):
			target = target[row[0][index]]
		target[row[0][-1]] = row[1]
		_check(not planner.call("_same_plan_value", changed, expected), "JSON plan changed value, type, array order or finiteness rejects")
	for nested in [false, true]:
		var extra := parsed.duplicate(true)
		var missing := parsed.duplicate(true)
		var extra_target: Dictionary = extra.input if nested else extra
		var missing_target: Dictionary = missing.input if nested else missing
		extra_target["unqualified"] = 1
		missing_target.erase("g206" if nested else "ok")
		_check(not planner.call("_same_plan_value", extra, expected) and not planner.call("_same_plan_value", missing, expected), "JSON exact key set rejects missing and extra keys")
	var cycle := {}
	var expected_cycle := {}
	cycle["self"] = cycle
	expected_cycle["self"] = expected_cycle
	_check(not planner.call("_same_plan_value", cycle, expected_cycle), "cyclic dictionaries reject at the comparison depth limit")
	cycle.clear()
	expected_cycle.clear()
	_check(JSON.stringify(expected) == encoded and JSON.stringify(parsed) == parsed_encoded, "comparison never modifies native or JSON plans")


func _producer(name: String, replacement_mode := -1, replacement: Array = []) -> Dictionary:
	var code := PackedByteArray([0x07, 1, 0xFF, 0, 2, 0xFF, 0])
	var outer := code.size()
	code.append_array(PackedByteArray([0x0D, 0x09, 0xFF, 0x01]) + name.to_ascii_buffer() + PackedByteArray([0, 0]))
	var marker_end := code.size()
	var active := code.size()
	code.append_array(PackedByteArray([0x07, 1, 0xFF, 0, 7, 0xFF, 0]))
	var copies := []
	for mode in range(2):
		var start := code.size()
		code.append_array(PackedByteArray([0x0D, 0x0B, 0xFF]))
		for expression in replacement if replacement_mode == mode else _copy_expressions(mode):
			code.append_array(PackedByteArray([2]) + expression + PackedByteArray([0xFF]))
		code.append(0)
		copies.append([start, code.size(), mode])
	var flag := code.size()
	code.append_array(PackedByteArray([0x03, 160, 15, 1, 0xFF, 0]))
	var boundary := code.size()
	code.append_array(PackedByteArray([0x1D, 2, 22, 0xFF, 0]))
	return {"code": code, "name": name, "outer": outer, "marker_end": marker_end, "active": active, "copies": copies, "flag": flag, "boundary": boundary}


func _copy_expressions(mode: int) -> Array:
	if mode == 0:
		return [PackedByteArray([0]), PackedByteArray([0]), PackedByteArray([0]), _literal(639), _literal(399), PackedByteArray([1]), PackedByteArray([0]), PackedByteArray([0]), PackedByteArray([23, 0xA0, 0])]
	return [PackedByteArray([1]), PackedByteArray([17, 0xA0, 0]), PackedByteArray([18, 0xA0, 0]), PackedByteArray([17, 0xA0, 0, 19, 0xA0, 0, 0xE0, 1, 0xE1]), PackedByteArray([18, 0xA0, 0, 20, 0xA0, 0, 0xE0, 1, 0xE1]), PackedByteArray([2]), PackedByteArray([17, 0xA0, 0]), PackedByteArray([18, 0xA0, 0]), PackedByteArray([23, 0xA0, 0])]


func _branch_fixture(expression: PackedByteArray) -> Dictionary:
	var first := _producer("B1.MMO")
	var second := _producer("B4.MMO")
	var branch := _branch(expression, 0)
	var false_offset: int = branch.size() + first.code.size()
	branch.encode_u32(branch.size() - 4, false_offset)
	return {"code": branch + first.code + second.code, "true_offset": branch.size(), "false_offset": false_offset, "first": first, "second": second}


func _branch(expression: PackedByteArray, target: int) -> PackedByteArray:
	var bytes := PackedByteArray([0x0B]) + expression + PackedByteArray([0xFF, 0, 0, 0, 0])
	bytes.encode_u32(bytes.size() - 4, target)
	return bytes


func _literal(value: int) -> PackedByteArray:
	if value < 0x80:
		return PackedByteArray([value])
	var bytes := PackedByteArray([0xF1, 0, 0])
	bytes.encode_u16(1, value)
	return bytes


func _assert_selection(result: Dictionary, code: PackedByteArray, block: Dictionary, shift: int, guards: Array, label: String) -> void:
	_check(result.get("ok", false), label + " selects a complete bounded producer")
	_check(result.get("selection", {}) == {"entry": block.name, "offset": block.outer + 1 + shift, "end_offset": block.marker_end + shift, "outer_command_offset": block.outer + shift, "load_surface": 2}, label + " retains exact MMO record and outer prefix")
	_check(result.get("guards", []) == guards and result.get("boundary", {}) == {"kind": "shared_routine", "offset": block.boundary + shift, "end_offset": block.code.size() + shift, "routine_id": 22}, label + " retains guards and routine22 stop")
	var copies: Array = result.get("copies", [])
	_check(copies.size() == 2, label + " retains both native copy modes")
	if copies.size() != 2:
		return
	for index in range(2):
		var expected: Array = block.copies[index]
		var record: Dictionary = Decoder.new().decode_at_structural(code, expected[0] + shift, expected[1] + shift)
		var expressions: Array = record.get("operands", [{}])[0].get("expressions", []).map(func(expression): return expression.ast)
		_check(copies[index] == {"offset": expected[0] + shift, "end_offset": expected[1] + shift, "mode": index, "expressions": expressions, "native_operation_semantics": ["opaque_rectangle_copy_confirmed", "rgb_chroma_key_rectangle_copy_confirmed"][index], "active_surface": 7, "evaluation": "symbolic_not_evaluated"}, label + " preserves complete ASTs including their source coordinates")
	var before := code.duplicate()
	copies[0].expressions[0].value = 99
	_check(code == before, label + " output AST mutation does not rewrite source bytes")


func _rejected(planner: RefCounted, code: PackedByteArray, start: int, end: int, label: String) -> void:
	var before := code.duplicate()
	var result: Dictionary = planner.call("_select", code, start, end, 413)
	_check(not result.get("ok", true) and not str(result.get("error", "")).is_empty() and code == before, label + " rejects without mutation")


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("PASS: ", label)
	else:
		_failed = true
		push_error("FAIL: " + label)
