class_name KakyuMesStackEffect
extends RefCounted

const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")


func analyze_instruction(instruction: Dictionary) -> Dictionary:
	return analyze_depths(_instruction_expression_depths(instruction))


func analyze_sequence(instructions: Array) -> Dictionary:
	var depths: Array[int] = []
	for untyped_instruction in instructions:
		var instruction: Dictionary = untyped_instruction
		depths.append_array(_instruction_expression_depths(instruction))
	return analyze_depths(depths)


func analyze_depths(depths: Array[int]) -> Dictionary:
	var balance := 0
	var lowest_balance := 0
	for depth in depths:
		balance += depth - 1
		lowest_balance = mini(lowest_balance, balance)
	return {
		"schema": ContentCoreVersionScript.MES_STACK_EFFECT_SCHEMA,
		"minimum_incoming": maxi(0, -lowest_balance),
		"net_delta": balance,
		"expression_count": depths.size(),
		"local_depths": depths.duplicate(),
	}


func expression_depth(expression: Dictionary) -> int:
	var ast: Dictionary = expression.get("ast", {})
	if str(ast.get("type", "")) == "stack":
		return ast.get("items", []).size()
	return 1


func _instruction_expression_depths(instruction: Dictionary) -> Array[int]:
	var depths: Array[int] = []
	for untyped_operand in instruction.get("operands", []):
		var operand: Dictionary = untyped_operand
		match str(operand.get("type", "")):
			"expression", "condition", "expression_index":
				depths.append(expression_depth(operand.get("value", {})))
			"expression_byte_pair":
				depths.append(expression_depth(operand.get("expression", {})))
			"expression_byte_pairs":
				for untyped_pair in operand.get("pairs", []):
					var pair: Dictionary = untyped_pair
					depths.append(expression_depth(pair.get("expression", {})))
			"record_list":
				for untyped_record in operand.get("records", []):
					var record: Dictionary = untyped_record
					if str(record.get("type", "")) == "expression_record":
						depths.append(expression_depth(record.get("value", {})))
	return depths
