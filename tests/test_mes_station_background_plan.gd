extends Node

const PlanScript := preload("res://content_core/mes_station_background_plan.gd")
const ContainerScript := preload("res://content_core/mes_container.gd")

var _failed := false
var _checks := 0


func _ready() -> void:
	var planner := PlanScript.new()
	_test_selection(planner)
	_test_rejected_guards(planner)
	_test_rejected_producers(planner)
	_test_public_source_boundary(planner)
	_test_json_plan_comparison(planner)
	print("Station background plan synthetic checks: ", _checks)
	await get_tree().process_frame
	get_tree().quit(1 if _failed else 0)


func _test_selection(planner: RefCounted) -> void:
	for row in [
		[PackedByteArray([1]), 413, 1825, 1, "literal true"],
		[PackedByteArray([0]), 413, 1825, 0, "literal false"],
		[PackedByteArray([2]), 413, 1825, 2, "raw nonbinary branch value"],
		[_literal(65535), 413, 1825, 65535, "wide nonbinary branch value"],
		[PackedByteArray([2, 1, 0xE6]), 413, 1825, 0, "exact-one AND"],
		[PackedByteArray([2, 0, 0xE7]), 413, 1825, 0, "exact-one OR"],
		[PackedByteArray([2, 1, 0xE7]), 413, 1825, 1, "exact-one OR accepts one operand"],
		[PackedByteArray([2, 2, 0xEF, 1, 0xE6]), 413, 1825, 1, "explicit comparison normalization"],
		[PackedByteArray([0xF6, 1, 0, 11, 0xEF]), 413, 1825, 1, "fixed selector eleven"],
		[PackedByteArray([0x80, 7]) + _literal(616) + PackedByteArray([0xEB, 0x80, 19]) + _literal(1800) + PackedByteArray([0xEB, 0xE6]), 413, 1200, 1, "date and time true"],
		[PackedByteArray([0x80, 7]) + _literal(616) + PackedByteArray([0xEB, 0x80, 19]) + _literal(1800) + PackedByteArray([0xEB, 0xE6]), 616, 1200, 0, "date boundary false"],
		[PackedByteArray([0x80, 7]) + _literal(616) + PackedByteArray([0xEB, 0x80, 19]) + _literal(1800) + PackedByteArray([0xEB, 0xE6]), 413, 1800, 0, "time boundary false"],
		[PackedByteArray([0x80, 7]) + _literal(65535) + PackedByteArray([0xEF]), 65535, 0, 1, "numeric u16 is not a calendar validity claim"],
	]:
		var fixture := _branch_fixture(row[0])
		var code: PackedByteArray = fixture.code
		var before := code.duplicate()
		var selected: Dictionary = planner.call("_select", code, 0, code.size(), int(row[1]), int(row[2]))
		var branch_value := int(row[3])
		var selected_start := int(fixture.true_offset) if branch_value == 1 else int(fixture.false_offset)
		var block: Dictionary = fixture.true_block if branch_value == 1 else fixture.false_block
		var expected_guards := [{"offset": 0, "end_offset": int(fixture.true_offset), "value": branch_value, "next_offset": selected_start}]
		_assert_selection(selected, block, selected_start, expected_guards, str(row[4]))
		_check(code == before, str(row[4]) + " leaves source bytes unchanged")

	var direct := _producer("DIRECT.MMO")
	var direct_code: PackedByteArray = direct.code
	var direct_result: Dictionary = planner.call("_select", direct_code, 0, direct_code.size(), 0, 65535)
	_assert_selection(direct_result, direct, 0, [], "direct bounded producer")
	var tailed := direct_code + PackedByteArray([0x07, 1, 0xFF, 0, 99, 0xFF, 0])
	var tailed_before := tailed.duplicate()
	var tailed_result: Dictionary = planner.call("_select", tailed, 0, tailed.size(), 413, 1825)
	_assert_selection(tailed_result, direct, 0, [], "stops before post-refresh write")
	_check(tailed == tailed_before, "post-refresh payload is never executed or modified")

	var shifted_fixture := _branch_fixture(PackedByteArray([0]))
	var shifted: PackedByteArray = shifted_fixture.code.duplicate()
	shifted.encode_u32(int(shifted_fixture.target_operand), int(shifted_fixture.false_offset) + 3)
	shifted = PackedByteArray([0xFF, 0xFF, 0xFF]) + shifted
	var shifted_result: Dictionary = planner.call("_select", shifted, 3, shifted.size(), 413, 1825)
	_assert_selection(shifted_result, shifted_fixture.false_block, int(shifted_fixture.false_offset) + 3, [{
		"offset": 3, "end_offset": int(shifted_fixture.true_offset) + 3,
		"value": 0, "next_offset": int(shifted_fixture.false_offset) + 3,
	}], "code-relative offsets retain nonzero region start")


func _test_rejected_guards(planner: RefCounted) -> void:
	for row in [
		[PackedByteArray([0x80, 4]), "unqualified weekday read"],
		[PackedByteArray([0x80, 12]), "unqualified state read"],
		[PackedByteArray([0xF8, 7]), "wrong state storage"],
		[PackedByteArray([0xF6, 2, 0]), "unqualified global selector slot"],
		[PackedByteArray([0xF3, 1, 0]), "wrong global storage"],
		[PackedByteArray([1, 0xA0, 0]), "banked state read"],
		[PackedByteArray([1, 1, 0xE0, 0xF7]), "dynamic global index"],
		[PackedByteArray([2, 0, 0xF0]), "operator outside the selected branch subset"],
		[PackedByteArray([10, 0xE5]), "random call"],
		[PackedByteArray([0, 10, 0xE5, 0xE6]), "RNG hidden in false AND"],
		[PackedByteArray([1, 10, 0xE5, 0xE7]), "RNG hidden in true OR"],
		[PackedByteArray([1, 2]), "multiple-result expression"],
		[PackedByteArray([0xE6]), "expression stack underflow"],
	]:
		var fixture := _branch_fixture(row[0])
		_expect_rejected(planner, fixture.code, 0, fixture.code.size(), str(row[1]))
	var branch := _branch_fixture(PackedByteArray([0]))
	for row in [[0, "self loop"], [1, "branch payload interior"], [branch.true_offset + branch.true_block.selection.offset + 3, "forward edge into MMO name payload"], [branch.code.size(), "edge at exclusive end"], [0xFFFFFFFF, "edge outside code"]]:
		var code: PackedByteArray = branch.code.duplicate()
		code.encode_u32(int(branch.target_operand), int(row[0]))
		_expect_rejected(planner, code, 0, code.size(), str(row[1]))
	var loop := _branch(PackedByteArray([0]), 7) + _branch(PackedByteArray([0]), 0)
	_expect_rejected(planner, loop, 0, loop.size(), "two-guard cycle")
	var deep := PackedByteArray([1])
	for _level in range(18):
		deep.append_array(PackedByteArray([1, 0xE6]))
	var deep_branch := _branch_fixture(deep)
	_expect_rejected(planner, deep_branch.code, 0, deep_branch.code.size(), "AST depth budget")
	var exhausted := PackedByteArray()
	for _guard in range(17):
		exhausted.append_array(_branch(PackedByteArray([1]), 0))
	exhausted.append_array(_producer("BUDGET.MMO").code)
	_expect_rejected(planner, exhausted, 0, exhausted.size(), "guard count budget")
	var bytecode: PackedByteArray = branch.code
	for bounds in [[-1, bytecode.size()], [0, bytecode.size() + 1], [0, -1], [0, 0], [bytecode.size(), bytecode.size()], [5, 4]]:
		_expect_rejected(planner, bytecode, int(bounds[0]), int(bounds[1]), "invalid region %s" % str(bounds))
	_expect_rejected(planner, PackedByteArray(), 0, 0, "empty code")
	_expect_rejected(planner, PackedByteArray([0x0C, 0, 0, 0, 0]), 0, 5, "unqualified continuation command")
	_expect_rejected(planner, PackedByteArray([0x1F, 1, 0, 0, 0]), 0, 5, "unqualified source-line command")


func _test_rejected_producers(planner: RefCounted) -> void:
	var block := _producer("SAFE.MMO")
	var code: PackedByteArray = block.code
	for cut in range(code.size()):
		_expect_rejected(planner, code, 0, cut, "truncated bounded producer at %d" % cut)
	for row in [
		[1, 2, "first write destination"],
		[3, 1, "first write bank"],
		[4, 1, "first active surface"],
		[block.post_write_offset + 1, 2, "second write destination"],
		[block.post_write_offset + 3, 1, "second write bank"],
		[block.post_write_offset + 4, 6, "second active surface"],
		[block.selection.outer_command_offset, 0, "missing native MMO outer prefix"],
		[block.boundary.offset + 2, 9, "unexpected following routine"],
	]:
		var changed := code.duplicate()
		changed[int(row[0])] = int(row[1])
		_expect_rejected(planner, changed, 0, changed.size(), str(row[2]))
	var run := code.slice(0, 6) + PackedByteArray([1, 99, 0xFF, 0]) + code.slice(7)
	_expect_rejected(planner, run, 0, run.size(), "multiple active-surface writes")
	var computed_write := code.slice(0, 4) + PackedByteArray([1, 1, 0xE0]) + code.slice(5)
	_expect_rejected(planner, computed_write, 0, computed_write.size(), "computed rather than literal surface write")
	var computed_copy := code.slice(0, int(block.copy.offset) + 7) + PackedByteArray([0, 0, 0xE0]) + code.slice(int(block.copy.offset) + 8)
	_expect_rejected(planner, computed_copy, 0, computed_copy.size(), "computed rather than literal copy operand")
	var computed_refresh := code.slice(0, int(block.boundary.offset) + 2) + PackedByteArray([4, 4, 0xE0]) + code.slice(int(block.boundary.offset) + 3)
	_expect_rejected(planner, computed_refresh, 0, computed_refresh.size(), "computed rather than literal refresh routine")
	for row in [[0, 0], [1, 1], [2, 1], [3, 638], [4, 398], [5, 3], [6, 1], [7, 1], [8, 2]]:
		var values := [1, 0, 0, 639, 399, 2, 0, 0, 1]
		values[int(row[0])] = int(row[1])
		var changed_block := _producer("SAFE.MMO", values)
		_expect_rejected(planner, changed_block.code, 0, changed_block.code.size(), "copy operand %d differs" % row[0])
	for resource in ["../ESCAPE.MMO", "OTHER.MES", "BAD/NAME.MMO", "BAD\\NAME.MMO", "BAD" + String.chr(7) + ".MMO"]:
		var changed_block := _producer(resource)
		_expect_rejected(planner, changed_block.code, 0, changed_block.code.size(), "unsafe or non-MMO resource")
	var command_shadow := code.slice(0, int(block.selection.offset))
	command_shadow.append_array(PackedByteArray([0x09, 0xFF, 0x01, 0x07, 1, 0xFF, 0, 2, 0xFF, 0, 0]))
	command_shadow.append_array(code.slice(int(block.post_write_offset)))
	_expect_rejected(planner, command_shadow, 0, command_shadow.size(), "MMO payload cannot execute a shadow write")


func _test_public_source_boundary(planner: RefCounted) -> void:
	var producer: PackedByteArray = _producer("SYNTHETIC.MMO").code
	var code := PackedByteArray()
	code.resize(0x4100)
	for index in range(producer.size()):
		code[0x3B3C + index] = producer[index]
	var payload := PackedByteArray([0, 0, 0, 0]) + code
	var before := payload.duplicate()
	var synthetic_selection: Dictionary = planner.call("_select", code, 0x3B3C, 0x40C0, 413, 1825)
	_check(ContainerScript.new().parse(payload).get("ok", false) and synthetic_selection.get("ok", false), "synthetic source-hash fixture has valid framing and a valid selector-local producer")
	var source_rejected: Dictionary = planner.build(payload, 413, 1825)
	_check(not source_rejected.get("ok", true) and payload == before, "public build never promotes synthetic bytes to original LIB evidence")
	for invalid in [null, true, "413", -1, 65536, 413.0, 413.5, INF, NAN, [], {}]:
		var invalid_date: Dictionary = planner.build(payload, invalid, 1825)
		var invalid_time: Dictionary = planner.build(payload, 413, invalid)
		_check(not invalid_date.get("ok", true) and invalid_date != source_rejected and payload == before, "public build rejects invalid MMDD before source selection without changing bytes")
		_check(not invalid_time.get("ok", true) and invalid_time != source_rejected and payload == before, "public build rejects invalid HHMM before source selection without changing bytes")
	for plan in [{}, {"ok": true}, {"ok": true, "input": {"mmdd": 413, "hhmm": 1825}, "selection": synthetic_selection.get("selection", {}).duplicate(true), "source": {"entry_sha256": "d9aba6eb8dab51fe321e22c868ed0cf38416bba1f0cf2f5d7d719f48e89b8b4d"}}]:
		var snapshot: Dictionary = plan.duplicate(true)
		_check(not planner.validate(payload, plan).get("ok", true) and payload == before and plan == snapshot, "public validation rejects forged source plans without mutation")


func _test_json_plan_comparison(planner: RefCounted) -> void:
	var typed_rectangle: Array[int] = [0, 0, 640, 400]
	var typed_guards: Array[Dictionary] = [{"offset": 7, "value": 1}, {"offset": 19, "value": 0}]
	var expected := {
		"ok": true, "schema": "synthetic_station_plan",
		"input": {"mmdd": 413, "hhmm": 1825}, "guards": typed_guards,
		"selection": {"entry": "SYNTHETIC.MMO", "load_surface": 2},
		"copy": {"source_rect": typed_rectangle},
		"execution": {"state_mutation": false, "native_cadence": "unresolved"},
		"empty": [], "optional": null,
	}
	var encoded := JSON.stringify(expected)
	var transported: Dictionary = JSON.parse_string(encoded)
	var transported_encoded := JSON.stringify(transported)
	_check(planner.call("_same_plan_value", expected, expected), "native nested plan compares equal without JSON transport")
	_check(typeof(transported.input.mmdd) == TYPE_FLOAT and planner.call("_same_plan_value", transported, expected), "JSON float numbers and untyped arrays match the exact native typed plan")
	var reordered := transported.duplicate(true)
	var input: Dictionary = reordered.input
	reordered.erase("input")
	reordered["input"] = input
	_check(planner.call("_same_plan_value", reordered, expected), "dictionary insertion order does not change plan equality")
	for row in [
		[["input", "mmdd"], "413", "numeric string"],
		[["input", "mmdd"], 413.5, "fractional numeric input"],
		[["selection", "load_surface"], 2.5, "fractional nested source coordinate"],
		[["copy", "source_rect", 0], false, "false is not numeric zero"],
		[["execution", "state_mutation"], 0, "numeric zero is not false"],
		[["ok"], 1, "numeric one is not true"],
		[["guards"], [transported.guards[1], transported.guards[0]], "reordered guard array"],
		[["copy", "source_rect"], [0, 0, 400, 640], "reordered coordinate array"],
		[["copy", "source_rect"], [0, 0, 640], "missing array element"],
		[["copy", "source_rect"], [0, 0, 640, 400, 0], "extra array element"],
		[["input"], [], "array substituted for dictionary"],
		[["empty"], {}, "dictionary substituted for array"],
		[["input", "hhmm"], INF, "positive infinity"],
		[["input", "hhmm"], -INF, "negative infinity"],
		[["input", "hhmm"], NAN, "not-a-number"],
	]:
		var changed := _mutated_json_plan(transported, row[0], row[1])
		_check(not planner.call("_same_plan_value", changed, expected), str(row[2]) + " cannot match a source plan")
	for nested in [false, true]:
		var missing := transported.duplicate(true)
		var extra := transported.duplicate(true)
		var missing_target: Dictionary = missing.input if nested else missing
		var extra_target: Dictionary = extra.input if nested else extra
		missing_target.erase("mmdd" if nested else "schema")
		extra_target["unqualified"] = 1
		_check(not planner.call("_same_plan_value", missing, expected), "missing %s key rejects" % ("nested" if nested else "root"))
		_check(not planner.call("_same_plan_value", extra, expected), "extra %s key rejects" % ("nested" if nested else "root"))
	var non_string_key := transported.duplicate(true)
	non_string_key.erase("schema")
	non_string_key[42] = "synthetic_station_plan"
	_check(not planner.call("_same_plan_value", non_string_key, expected), "non-string dictionary key rejects")
	var deep_expected: Variant = 1
	var deep_actual: Variant = 1.0
	for _level in range(32):
		deep_expected = {"child": deep_expected}
		deep_actual = {"child": deep_actual}
	_check(planner.call("_same_plan_value", deep_actual, deep_expected), "depth limit accepts a numeric leaf at depth 32")
	_check(not planner.call("_same_plan_value", {"child": deep_actual}, {"child": deep_expected}), "oversized nested plan stops at the depth budget")
	var cyclic_actual := {}
	var cyclic_expected := {}
	cyclic_actual["self"] = cyclic_actual
	cyclic_expected["self"] = cyclic_expected
	var cyclic_rejected := not bool(planner.call("_same_plan_value", cyclic_actual, cyclic_expected))
	_check(cyclic_rejected and cyclic_actual.size() == 1 and cyclic_expected.size() == 1, "self-referenced dictionaries fail safely without mutation")
	cyclic_actual.clear()
	cyclic_expected.clear()
	_check(JSON.stringify(expected) == encoded and JSON.stringify(transported) == transported_encoded, "plan comparisons preserve the native and transported inputs")


func _mutated_json_plan(plan: Dictionary, path: Array, value: Variant) -> Dictionary:
	var changed := plan.duplicate(true)
	var target: Variant = changed
	for index in range(path.size() - 1):
		target = target[path[index]]
	target[path[-1]] = value
	return changed


func _branch_fixture(expression: PackedByteArray) -> Dictionary:
	var first := _producer("TRUE.MMO")
	var second := _producer("FALSE.MMO")
	var condition := _branch(expression, 0)
	var true_offset := condition.size()
	var false_offset: int = true_offset + first.code.size()
	condition.encode_u32(condition.size() - 4, false_offset)
	return {"code": condition + first.code + second.code, "true_offset": true_offset, "false_offset": false_offset, "target_operand": condition.size() - 4, "true_block": first, "false_block": second}


func _branch(expression: PackedByteArray, target: int) -> PackedByteArray:
	var code := PackedByteArray([0x0B]) + expression + PackedByteArray([0xFF, 0, 0, 0, 0])
	code.encode_u32(code.size() - 4, target)
	return code


func _producer(resource: String, values := [1, 0, 0, 639, 399, 2, 0, 0, 1]) -> Dictionary:
	var code := PackedByteArray([0x07, 1, 0xFF, 0, 2, 0xFF, 0])
	var outer := code.size()
	code.append_array(PackedByteArray([0x0D, 0x09, 0xFF, 0x01]))
	code.append_array(resource.to_ascii_buffer())
	code.append_array(PackedByteArray([0, 0]))
	var selection := {"entry": resource, "offset": outer + 1, "end_offset": code.size(), "outer_command_offset": outer, "load_surface": 2}
	var post_write := code.size()
	code.append_array(PackedByteArray([0x07, 1, 0xFF, 0, 7, 0xFF, 0]))
	var copy_offset := code.size()
	code.append_array(PackedByteArray([0x0D, 0x0B, 0xFF]))
	for value in values:
		code.append(0x02)
		code.append_array(_literal(value))
		code.append(0xFF)
	code.append(0)
	var copy := {"offset": copy_offset, "end_offset": code.size(), "mode": 1, "source_surface": 2, "destination_surface": 1, "source_rect": [0, 0, 640, 400], "destination": [0, 0], "active_surface": 7}
	var boundary_offset := code.size()
	code.append_array(PackedByteArray([0x1D, 0x02, 8, 0xFF, 0]))
	return {"code": code, "selection": selection, "copy": copy, "boundary": {"offset": boundary_offset, "end_offset": code.size(), "routine_id": 8}, "post_write_offset": post_write}


func _literal(value: int) -> PackedByteArray:
	if value < 0x80:
		return PackedByteArray([value])
	var code := PackedByteArray([0xF1, 0, 0])
	code.encode_u16(1, value)
	return code


func _assert_selection(result: Dictionary, block: Dictionary, offset: int, guards: Array, label: String) -> void:
	_check(result.get("ok", false), label + " selects a bounded producer")
	var selection: Dictionary = block.selection.duplicate(true)
	for key in ["offset", "end_offset", "outer_command_offset"]:
		selection[key] += offset
	var copy: Dictionary = block.copy.duplicate(true)
	var boundary: Dictionary = block.boundary.duplicate(true)
	for item in [copy, boundary]:
		item.offset += offset
		item.end_offset += offset
	_check(result.get("guards", []) == guards and result.get("selection", {}) == selection, label + " retains exact guard and MMO intervals")
	_check(result.get("copy", {}) == copy and result.get("boundary", {}) == boundary, label + " retains exact copy and refresh boundary")


func _expect_rejected(planner: RefCounted, code: PackedByteArray, start: int, end: int, label: String) -> void:
	var before := code.duplicate()
	var result: Dictionary = planner.call("_select", code, start, end, 413, 1825)
	_check(not result.get("ok", true) and not str(result.get("error", "")).is_empty() and code == before, label + " rejects without mutating source bytes")


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("PASS: ", label)
	else:
		_failed = true
		push_error("FAIL: " + label)
