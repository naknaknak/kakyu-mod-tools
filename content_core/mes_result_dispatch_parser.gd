class_name KakyuMesResultDispatchParser
extends RefCounted





func skip_source_markers(code, start_offset: int, limit: int) -> Dictionary:
	var source := _as_source(code)
	var cursor := start_offset
	var seen := {}
	while not seen.has(cursor):
		seen[cursor] = true
		if cursor < 0 or cursor >= limit:
			return _error("Result coordinate is outside bytecode.")
		var instruction := source.decode_at_structural(cursor, limit)
		if not instruction.get("ok", false):
			return _error("Result coordinate does not decode.")
		if int(instruction.command_id) != 0x1F:
			# The resolved offset, not the requested one: a record source skips
			# the markers a byte source walks over here.
			return {"ok": true, "offset": int(instruction.source_offset)}
		cursor = int(instruction.end_offset)
	return _error("Result source markers form a cycle.")


func validated_branch_targets(
	code, instruction: Dictionary, target: int, limit: int
) -> Dictionary:
	var source := _as_source(code)
	var fallthrough_result := skip_source_markers(code, int(instruction.end_offset), limit)
	var false_result := skip_source_markers(code, target, limit)
	if not fallthrough_result.get("ok", false) or not false_result.get("ok", false):
		return {"ok": false}
	var fallthrough := int(fallthrough_result.offset)
	var false_target := int(false_result.offset)
	if (
		not source.decode_at_structural(fallthrough, limit).get("ok", false)
		or not source.decode_at_structural(false_target, limit).get("ok", false)
	):
		return {"ok": false}
	return {
		"ok": true,
		"fallthrough_offset": fallthrough,
		"false_target_offset": false_target,
	}


func state_u16_equal_literal_branch(instruction: Dictionary) -> Dictionary:
	if int(instruction.get("command_id", -1)) != 0x0B:
		return {"ok": false}
	var operands: Array = instruction.get("operands", [])
	if operands.size() != 2 or str(operands[0].get("type", "")) != "condition":
		return {"ok": false}
	var ast: Dictionary = operands[0].get("value", {}).get("ast", {})
	if str(ast.get("type", "")) != "binary" or str(ast.get("op", "")) != "equal":
		return {"ok": false}
	var state_index := _state_u16_index(ast.get("lhs", {}))
	var literal := _literal_value(ast.get("rhs", {}))
	if state_index < 0 or literal < 0:
		state_index = _state_u16_index(ast.get("rhs", {}))
		literal = _literal_value(ast.get("lhs", {}))
	if state_index < 0 or literal < 0 or str(operands[1].get("type", "")) != "code_offset":
		return {"ok": false}
	return {
		"ok": true,
		"state_index": state_index,
		"literal": literal,
		"target": int(operands[1].get("value", -1)),
	}


func compound_state_result_gate_branch(
	instruction: Dictionary, result_storage: String, result_index: int
) -> Dictionary:
	if int(instruction.get("command_id", -1)) != 0x0B:
		return {"ok": false}
	var operands: Array = instruction.get("operands", [])
	if operands.size() != 2 or str(operands[0].get("type", "")) != "condition":
		return {"ok": false}
	var ast: Dictionary = operands[0].get("value", {}).get("ast", {})
	if str(ast.get("type", "")) != "binary" or str(ast.get("op", "")) != "logical_and":
		return {"ok": false}
	var left := _state_equal_literal(ast.get("lhs", {}))
	var right := _state_equal_literal(ast.get("rhs", {}))
	if not left.get("ok", false) or not right.get("ok", false):
		return {"ok": false}
	var result: Dictionary = (
		left
		if str(left.storage) == result_storage and int(left.index) == result_index
		else right
	)
	var gate: Dictionary = right if result == left else left
	if (
		str(result.get("storage", "")) != result_storage
		or int(result.get("index", -1)) != result_index
		or (str(gate.get("storage", "")) == result_storage and int(gate.get("index", -1)) == result_index)
		or str(operands[1].get("type", "")) != "code_offset"
	):
		return {"ok": false}
	var normalized_gate := {
		"storage": str(gate.storage),
		"index": int(gate.index),
		"literal": int(gate.literal),
	}
	return {
		"ok": true,
		"result": int(result.literal),
		"gate": normalized_gate,
		"target": int(operands[1].get("value", -1)),
	}


func code_coordinate_transfer(instruction: Dictionary) -> Dictionary:
	if int(instruction.get("command_id", -1)) != 0x0C:
		return {"ok": false}
	var operands: Array = instruction.get("operands", [])
	if operands.size() != 1 or str(operands[0].get("type", "")) != "code_offset":
		return {"ok": false}
	return {"ok": true, "destination_offset": int(operands[0].get("value", -1))}


func _state_equal_literal(ast_value: Variant) -> Dictionary:
	if not ast_value is Dictionary:
		return {"ok": false}
	var ast: Dictionary = ast_value
	if str(ast.get("type", "")) != "binary" or str(ast.get("op", "")) != "equal":
		return {"ok": false}
	var left = ast.get("lhs", {})
	var right = ast.get("rhs", {})
	var state: Dictionary = left if left is Dictionary and str(left.get("type", "")) == "state_ref" else right
	var literal_ast = right if state == left else left
	if str(state.get("type", "")) != "state_ref":
		return {"ok": false}
	var index := _literal_value(state.get("index", {}))
	var literal := _literal_value(literal_ast)
	if index < 0 or literal < 0:
		return {"ok": false}
	var result := {
		"ok": true,
		"storage": str(state.get("storage", "")),
		"index": index,
		"literal": literal,
	}
	if state.has("bank"):
		result["bank"] = int(state.bank)
	return result


func _state_u16_index(ast_value: Variant) -> int:
	if not ast_value is Dictionary:
		return -1
	var ast: Dictionary = ast_value
	if str(ast.get("type", "")) != "state_ref" or str(ast.get("storage", "")) != "state_u16":
		return -1
	return _literal_value(ast.get("index", {}))


func _literal_value(ast_value: Variant) -> int:
	if not ast_value is Dictionary:
		return -1
	var ast: Dictionary = ast_value
	return int(ast.get("value", -1)) if str(ast.get("type", "")) == "literal" else -1



# Callers pass either the bytecode itself or a code source supplied by a
# playback package. Both answer the same questions. See mes_code_source.gd.
func _as_source(code) -> KakyuMesCodeSource:
	if code is KakyuMesCodeSource:
		return code
	return KakyuMesCodeSource.for_bytecode(code if code is PackedByteArray else PackedByteArray())


func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message}
