extends "res://tests/test_case.gd"

const ExpressionScript := preload("res://content_core/mes_expression.gd")
const PersistentExpressionScript := preload("res://content_core/mes_persistent_expression.gd")
const SandboxStateScript := preload("res://content_core/mes_sandbox_state.gd")


func _ready() -> void:
	var parser := ExpressionScript.new()
	var state := SandboxStateScript.new(1234)
	var exact_and := parser.parse(PackedByteArray([2, 1, 0xE6, 0xFF]), 0)
	_check(exact_and.ok and parser.evaluate(exact_and.ast, state).value == 0, "native E6 does not treat raw 2 as true")
	var exact_or := parser.parse(PackedByteArray([0, 2, 0xE7, 0xFF]), 0)
	_check(exact_or.ok and parser.evaluate(exact_or.ast, state).value == 0, "native E7 does not treat raw 2 as true")
	_test_native_exact_one_logic(parser)
	state.write_value("state_u16", 4, 6)
	state.write_value("global_u8", 402, 1)
	state.write_value("banked_u16", 212, 50, 0)
	var expression := PackedByteArray([
		0x80, 4,
		0xF1, 6, 0,
		0xEF,
		0xF3, 0x92, 0x01,
		0xF1, 1, 0,
		0xEF,
		0xE6,
		0xFF,
	])
	var parsed := parser.parse(expression, 0)
	_check(parsed.ok, "confirmed RPN expression parses")
	var value := parser.evaluate(parsed.ast, state)
	_check(value.ok and value.value == 1, "state/global expression evaluates")
	state.write_value("global_u8", 402, 0)
	_check(parser.evaluate(parsed.ast, state).value == 0, "state changes affect sandbox evaluation")

	var banked := PackedByteArray([0xF1, 0xD4, 0, 0xA0, 0, 0xF1, 50, 0, 0xEF, 0xFF])
	var banked_parsed := parser.parse(banked, 0)
	_check(banked_parsed.ok and parser.evaluate(banked_parsed.ast, state).value == 1, "banked state reference evaluates")
	state.write_value("banked_u8", 3, 7, 25)
	_check(state.read_value("banked_u8", 3, 25) == 7, "banked byte state remains logical by default")
	state.write_value("state_u16", 0, 0x24A0)
	state.write_value("state_u16", 25, 0x24C0)
	state.set_native_relative_u8_aliases_enabled(true)
	_check(state.native_relative_u8_aliases_enabled(), "native relative byte aliases are explicitly enabled")
	_check(
		state.write_relative_u8_block(0x24A0, PackedByteArray([1, 2, 3, 15, 4])),
		"native relative byte block is seeded within the bounded address space"
	)
	_check(state.read_value("banked_u8", 3, 0) == 15, "bank zero reads through its state-relative byte base")
	state.write_value("banked_u8", 2, 9, 25)
	_check(
		state.read_value("relative_u8", 0x24C2) == 9,
		"banked byte writes share the native relative byte memory"
	)
	var relative_expression := parser.parse(PackedByteArray([2, 0xC0, 25, 0xFF]), 0)
	_check(
		relative_expression.ok and parser.evaluate(relative_expression.ast, state).value == 9,
		"expression token 0xC0 observes the explicit native alias"
	)
	var relative_before := state.snapshot()
	state.write_value("banked_u8", 2, 10, 25)
	var relative_diff := state.diff(relative_before)
	_check(
		relative_diff.size() == 1
		and relative_diff[0].storage == "relative_u8"
		and relative_diff[0].index == 0x24C2,
		"native alias diffs expose the physical relative byte address"
	)
	state.restore(relative_before)
	_check(state.read_value("banked_u8", 2, 25) == 9, "snapshot restore preserves relative byte memory")
	state.write_value("state_u16", 25, 0xFFFF)
	_check(not state.write_value("banked_u8", 1, 1, 25), "native alias rejects an out-of-range relative address")
	state.set_native_relative_u8_aliases_enabled(false)
	_check(state.read_value("banked_u8", 3, 25) == 7, "disabling native aliases restores the isolated logical bank")
	var arithmetic := PackedByteArray([5, 3, 0xE0, 2, 0xE2, 0xFF])
	var arithmetic_parsed := parser.parse(arithmetic, 0)
	_check(arithmetic_parsed.ok and parser.evaluate(arithmetic_parsed.ast, state).value == 16, "raw literals and arithmetic evaluate")
	_check(not parser.parse(PackedByteArray([0xE0, 0xFF]), 0).ok, "expression stack underflow is rejected")
	_check(not parser.parse(PackedByteArray([1, 2]), 0).ok, "missing expression terminator is rejected")
	var structural_empty := parser.parse_structural(PackedByteArray([0xFF]), 0)
	_check(
		structural_empty.ok
		and not structural_empty.valid
		and structural_empty.ast.type == "stack"
		and structural_empty.ast.items.is_empty()
		and structural_empty.end_offset == 1,
		"structural parser retains a terminated empty stack without making it valid"
	)
	_check(
		not parser.parse_structural(PackedByteArray([0xE0, 0xFF]), 0).ok,
		"structural parser still rejects stack underflow"
	)

	var before := state.snapshot()
	state.write_value("state_u16", 7, 801)
	var diff := state.diff(before)
	_check(diff.size() == 1 and diff[0].storage == "state_u16" and diff[0].index == 7, "sandbox state diff is isolated")
	await get_tree().process_frame
	get_tree().quit(1 if _failed else 0)


func _test_native_exact_one_logic(parser: KakyuMesExpression) -> void:
	var state := SandboxStateScript.new(1234)
	var values := [0, 1, 2, 255, 65535, 0xFFFFFFFF]
	for left in values:
		for right in values:
			var left_wide := int(left) > 0xFFFF
			var right_wide := int(right) > 0xFFFF
			state.write_value("state_i32" if left_wide else "state_u16", 42, left)
			state.write_value("state_i32" if right_wide else "state_u16", 43, right)
			for left_from_state in [false, true]:
				for right_from_state in [false, true]:
					for token in [0xE6, 0xE7]:
						var code := PackedByteArray([0xF8 if left_wide else 0x80, 42]) if left_from_state else _logic_literal(left)
						code.append_array(PackedByteArray([0xF8 if right_wide else 0x80, 43]) if right_from_state else _logic_literal(right))
						code.append_array(PackedByteArray([token, 0xFF]))
						var expected := int(left == 1 and right == 1) if token == 0xE6 else int(left == 1 or right == 1)
						_check_pure_expression(
							parser, state, code, expected,
							"exact-one 0x%X ordered pair %d/%d (%s/%s)" % [
								token, left, right,
								"state" if left_from_state else "literal",
								"state" if right_from_state else "literal",
							]
						)
	for test_case in [
		[PackedByteArray([2, 0, 0xE7, 1, 0xE6, 0xFF]), 0, "nested nonbinary OR is not promoted to true by AND"],
		[PackedByteArray([2, 1, 0xE7, 1, 0xE6, 0xFF]), 1, "nested exact-one OR result remains true for AND"],
		[PackedByteArray([2, 1, 0xE6, 1, 0xE7, 0xFF]), 1, "nested false AND followed by exact-one OR evaluates"],
		[PackedByteArray([2, 0, 0xF0, 1, 0xE6, 0xFF]), 1, "explicit nonzero comparison normalizes raw 2 before AND"],
		[PackedByteArray([2, 3, 3, 0xEF, 0xE6, 0xFF]), 0, "raw 2 remains false beside a normalized equality result"],
		[_logic_literal(65535) + PackedByteArray([1, 0xEC, 2, 0, 0xF0, 0xE6, 0xFF]), 1, "nested comparison results preserve existing boolean-normalized gates"],
		[PackedByteArray([2, 3, 0xE8, 0xFF]), 2, "bitwise AND retains its nonboolean numeric result"],
		[PackedByteArray([2, 3, 0xE9, 0xFF]), 3, "bitwise OR retains its nonboolean numeric result"],
		[PackedByteArray([2, 3, 0xE8, 1, 0xE6, 0xFF]), 0, "logical AND does not normalize a nonbinary bitwise result"],
		[PackedByteArray([2, 1, 0xE9, 0, 0xE7, 0xFF]), 0, "logical OR does not normalize a nonbinary bitwise result"],
		[PackedByteArray([3, 1, 0xE8, 1, 0xE6, 0xFF]), 1, "bitwise mask producing exactly one is true for logical AND"],
	]:
		_check_pure_expression(parser, state, test_case[0], int(test_case[1]), str(test_case[2]))
	for token in [0xE6, 0xE7]:
		for random_on_left in [false, true]:
			var evaluated_state := SandboxStateScript.new(1234)
			var persistent_state := SandboxStateScript.new(1234)
			var reference_state := SandboxStateScript.new(1234)
			var fixed := 0 if token == 0xE6 else 1
			var random_code := _logic_literal(65535) + PackedByteArray([0xE5])
			var code := random_code + _logic_literal(fixed) if random_on_left else _logic_literal(fixed) + random_code
			code.append_array(PackedByteArray([token, 0xFF]))
			var parsed := parser.parse(code, 0)
			var before := evaluated_state.snapshot()
			var evaluated := parser.evaluate(parsed.ast, evaluated_state) if parsed.ok else {}
			var carried_stack: Array[int] = [19]
			var persistent := PersistentExpressionScript.new().evaluate_fragment(parsed, persistent_state, carried_stack) if parsed.ok else {}
			reference_state.random_below(65535)
			_check(
				parsed.ok and parsed.end_offset == code.size()
				and evaluated.get("ok", false) and evaluated.get("value", -1) == fixed
				and persistent.get("ok", false) and persistent.get("value", -1) == fixed
				and carried_stack == [19]
				and evaluated_state.snapshot() == before and persistent_state.snapshot() == before
				and evaluated_state.get("_random").state == reference_state.get("_random").state
				and persistent_state.get("_random").state == reference_state.get("_random").state,
				"logical 0x%X evaluates both operands without short-circuiting (%s random)" % [
					token, "left" if random_on_left else "right",
				]
			)


func _logic_literal(value: int) -> PackedByteArray:
	if value <= 0xFFFF:
		var narrow := PackedByteArray([0xF1, 0, 0])
		narrow.encode_u16(1, value)
		return narrow
	var wide := PackedByteArray([0xF2, 0, 0, 0, 0])
	wide.encode_u32(1, value)
	return wide


func _check_pure_expression(
	parser: KakyuMesExpression,
	state: KakyuMesSandboxState,
	code: PackedByteArray,
	expected: int,
	label: String
) -> void:
	var before := state.snapshot()
	var random_before: int = state.get("_random").state
	var parsed := parser.parse(code, 0)
	var evaluated := parser.evaluate(parsed.ast, state) if parsed.ok else {}
	var carried_stack: Array[int] = [19]
	var persistent := PersistentExpressionScript.new().evaluate_fragment(parsed, state, carried_stack) if parsed.ok else {}
	_check(
		parsed.ok and parsed.end_offset == code.size()
		and evaluated.get("ok", false) and evaluated.get("value", -1) == expected
		and persistent.get("ok", false) and persistent.get("value", -1) == expected
		and persistent.get("stack_depth_before", -1) == 1
		and persistent.get("stack_depth_after", -1) == 1
		and persistent.get("local_depth", -1) == 1
		and not persistent.get("used_empty_fallback", true) and carried_stack == [19]
		and state.snapshot() == before and state.get("_random").state == random_before,
		label
	)
