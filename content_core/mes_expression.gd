class_name KakyuMesExpression
extends RefCounted

const SandboxStateScript := preload("res://content_core/mes_sandbox_state.gd")
const MAX_EXPRESSION_BYTES := 0x1000
const BINARY_OPS := {
	0xE0: "add",
	0xE1: "subtract",
	0xE2: "multiply",
	0xE3: "divide_unsigned",
	0xE4: "modulo_unsigned",
	0xE6: "logical_and",
	0xE7: "logical_or",
	0xE8: "bit_and",
	0xE9: "bit_or",
	0xEA: "bit_xor",
	0xEB: "less_than",
	0xEC: "greater_than",
	0xED: "less_or_equal",
	0xEE: "greater_or_equal",
	0xEF: "equal",
	0xF0: "not_equal",
}


func parse(data: PackedByteArray, offset: int, limit := -1) -> Dictionary:
	return _parse(data, offset, limit, false)


func parse_structural(data: PackedByteArray, offset: int, limit := -1) -> Dictionary:
	return _parse(data, offset, limit, true)


func _parse(data: PackedByteArray, offset: int, limit: int, allow_non_single_result: bool) -> Dictionary:
	if offset < 0 or offset >= data.size():
		return _error("Expression offset is outside bytecode.")
	var start := offset
	var end_limit := mini(data.size(), offset + MAX_EXPRESSION_BYTES)
	if limit >= 0:
		end_limit = mini(end_limit, limit)
	var stack: Array[Dictionary] = []
	while offset < end_limit:
		var token_offset := offset
		var token := int(data[offset])
		offset += 1
		if token == 0xFF:
			if stack.size() != 1 and not allow_non_single_result:
				return _error("Expression ended with stack depth %d, expected 1." % stack.size(), start, offset)
			var result := {
				"ok": true,
				"offset": start,
				"end_offset": offset,
				"byte_length": offset - start,
				"raw_hex": data.slice(start, offset).hex_encode(),
				"ast": stack[0] if stack.size() == 1 else {"type": "stack", "items": stack},
			}
			if allow_non_single_result:
				result["valid"] = stack.size() == 1
				result["diagnostics"] = [] if stack.size() == 1 else [
					"Expression ended with stack depth %d, expected 1." % stack.size()
				]
			return result
		if BINARY_OPS.has(token):
			if stack.size() < 2:
				return _error("Expression stack underflow for token 0x%02X." % token, start, offset)
			var right: Dictionary = stack.pop_back()
			var left: Dictionary = stack.pop_back()
			stack.append({
				"type": "binary",
				"op": BINARY_OPS[token],
				"lhs": left,
				"rhs": right,
				"source": _source(token_offset, token),
			})
			continue
		if token == 0xE5:
			if stack.is_empty():
				return _error("Expression stack underflow for random_below.", start, offset)
			stack.append({
				"type": "call",
				"name": "random_below",
				"args": [stack.pop_back()],
				"source": _source(token_offset, token),
			})
			continue
		if token == 0xF1 or token == 0xF2:
			var size := 2 if token == 0xF1 else 4
			if offset + size > end_limit:
				return _error("Expression literal is truncated.", start, offset)
			var value := int(data.decode_u16(offset)) if size == 2 else int(data.decode_u32(offset))
			offset += size
			stack.append({
				"type": "literal",
				"value": value,
				"width": size * 8,
				"source": _source(token_offset, token),
			})
			continue
		if token == 0x80 or token == 0xF8:
			if offset >= end_limit:
				return _error("Expression state index is truncated.", start, offset)
			var index := int(data[offset])
			offset += 1
			stack.append(_state_ref("state_u16" if token == 0x80 else "state_i32", _literal(index), 0, token_offset, token))
			continue
		if token == 0xF3 or token == 0xF6:
			if offset + 2 > end_limit:
				return _error("Expression global index is truncated.", start, offset)
			var index := int(data.decode_u16(offset))
			offset += 2
			stack.append(_state_ref("global_u8" if token == 0xF3 else "global_i32", _literal(index), 0, token_offset, token))
			continue
		if token == 0xF5 or token == 0xF7:
			if stack.is_empty():
				return _error("Expression stack underflow for dynamic global index.", start, offset)
			stack.append(_state_ref("global_u8" if token == 0xF5 else "global_i32", stack.pop_back(), 0, token_offset, token))
			continue
		if token == 0xA0 or token == 0xC0 or token == 0xF9:
			if stack.is_empty() or offset >= end_limit:
				return _error("Expression banked state reference is truncated.", start, offset)
			var index_expression: Dictionary = stack.pop_back()
			var bank := int(data[offset])
			offset += 1
			var storage := str({0xA0: "banked_u16", 0xC0: "banked_u8", 0xF9: "banked_i32"}[token])
			stack.append(_state_ref(storage, index_expression, bank, token_offset, token))
			continue
		stack.append({
			"type": "literal",
			"value": token,
			"width": 8,
			"source": _source(token_offset, token),
		})
	return _error("Expression is missing its 0xFF terminator.", start, offset)


func evaluate(ast: Dictionary, state: KakyuMesSandboxState) -> Dictionary:
	match str(ast.get("type", "")):
		"literal":
			return {"ok": true, "value": int(ast.get("value", 0))}
		"state_ref":
			var index_result := evaluate(ast.get("index", {}), state)
			if not index_result.ok:
				return index_result
			return {
				"ok": true,
				"value": state.read_value(
					str(ast.get("storage", "")),
					int(index_result.value),
					int(ast.get("bank", 0))
				),
			}
		"binary":
			var left := evaluate(ast.get("lhs", {}), state)
			if not left.ok:
				return left
			var right := evaluate(ast.get("rhs", {}), state)
			if not right.ok:
				return right
			return _evaluate_binary(str(ast.get("op", "")), int(left.value), int(right.value))
		"call":
			if ast.get("name", "") != "random_below" or not ast.get("args", []) is Array or ast.args.size() != 1:
				return _error("Unsupported MES expression call.")
			var bound := evaluate(ast.args[0], state)
			if not bound.ok:
				return bound
			return {"ok": true, "value": state.random_below(int(bound.value))}
		_:
			return _error("Unsupported MES expression AST node.")


func _evaluate_binary(operation: String, left: int, right: int) -> Dictionary:
	var value: int
	match operation:
		"add": value = left + right
		"subtract": value = left - right
		"multiply": value = left * right
		"divide_unsigned": value = 0 if right == 0 else int((left & 0xFFFFFFFF) / (right & 0xFFFFFFFF))
		"modulo_unsigned": value = 0 if right == 0 else (left & 0xFFFFFFFF) % (right & 0xFFFFFFFF)
		"logical_and": value = 1 if left == 1 and right == 1 else 0
		"logical_or": value = 1 if left == 1 or right == 1 else 0
		"bit_and": value = left & right
		"bit_or": value = left | right
		"bit_xor": value = left ^ right
		"less_than": value = 1 if left < right else 0
		"greater_than": value = 1 if left > right else 0
		"less_or_equal": value = 1 if left <= right else 0
		"greater_or_equal": value = 1 if left >= right else 0
		"equal": value = 1 if left == right else 0
		"not_equal": value = 1 if left != right else 0
		_: return _error("Unsupported MES binary operation: %s" % operation)
	return {"ok": true, "value": value}


func _state_ref(storage: String, index: Dictionary, bank: int, offset: int, token: int) -> Dictionary:
	return {
		"type": "state_ref",
		"storage": storage,
		"bank": bank,
		"index": index,
		"source": _source(offset, token),
	}


func _literal(value: int) -> Dictionary:
	return {"type": "literal", "value": value}


func _source(offset: int, token: int) -> Dictionary:
	return {"offset": offset, "token": "0x%02x" % token}


func _error(message: String, offset := -1, end_offset := -1) -> Dictionary:
	var result := {"ok": false, "error": message}
	if offset >= 0:
		result["offset"] = offset
	if end_offset >= 0:
		result["end_offset"] = end_offset
	return result
