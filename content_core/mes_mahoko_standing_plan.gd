class_name KakyuMesMahokoStandingPlan
extends RefCounted

# Read-only B_PIC selection proof. Neither the prefix nor native copies run.
const Version := preload("res://content_core/content_core_version.gd")
const ContainerScript := preload("res://content_core/mes_container.gd")
const Decoder := preload("res://content_core/mes_instruction_decoder.gd")
const ExpressionScript := preload("res://content_core/mes_expression.gd")
const State := preload("res://content_core/mes_sandbox_state.gd")
const PICTURE_SHA256 := "d72612395e8571848a7782ff48d8c63604a09a983ae2c564f2ee5bd5ac2b4ada"
const SELECTOR_OFFSET := 0x02A5
const SELECTOR_END := 0x0568
const MAX_PREFIX_RECORDS := 32


func build(picture_payload: PackedByteArray, mmdd: Variant) -> Dictionary:
	if not _word(mmdd):
		return _error("Mahoko standing selection requires an exact unsigned-word date input.")
	var document := ContainerScript.new().parse(picture_payload)
	if not document.get("ok", false) or document.entry_sha256 != PICTURE_SHA256:
		return _error("Mahoko standing selection requires the audited original B_PIC.MES payload.")
	var selected := _select(document.bytecode, SELECTOR_OFFSET, SELECTOR_END, mmdd)
	if not selected.get("ok", false):
		return selected
	selected["schema"] = Version.MES_MAHOKO_STANDING_PLAN_SCHEMA
	selected["producer"] = {"core_version": Version.CORE_VERSION, "instruction_schema": Version.MES_INSTRUCTION_SCHEMA}
	selected["source"] = {
		"archive": "mes.arc", "entry": "B_PIC.MES", "entry_sha256": document.entry_sha256,
		"bytecode_sha256": document.bytecode_sha256, "offset_basis": "code_start",
		"offset": SELECTOR_OFFSET, "end_offset": SELECTOR_END,
	}
	selected["input"] = {"mmdd": mmdd, "g206": 1}
	selected["execution"] = {
		"kind": "read_only_projection", "state_mutation": false, "compatibility": "remake_only",
		"native_cadence": "unresolved", "event_eligibility": "unqualified",
	}
	return selected


func validate(picture_payload: PackedByteArray, plan: Dictionary) -> Dictionary:
	var inputs: Variant = plan.get("input", {})
	if not inputs is Dictionary or not _plan_word(inputs.get("mmdd")):
		return _error("Mahoko standing plan input is not an exact unsigned-word date.")
	var rebuilt := build(picture_payload, int(inputs.mmdd))
	if not rebuilt.get("ok", false):
		return rebuilt
	if not _same_plan_value(plan, rebuilt):
		return _error("Mahoko standing plan no longer matches its source-bound selection.")
	return {"ok": true}


func _select(code: PackedByteArray, start: int, end: int, mmdd: int) -> Dictionary:
	if start < 0 or end <= start or end > code.size() or not _word(mmdd):
		return _error("Mahoko standing selection bounds or date input are invalid.")
	var state := State.new(1)
	state.write_value("global_u8", 206, 1)
	state.write_value("state_u16", 7, mmdd)
	var guards: Array[Dictionary] = []
	var cursor := start
	var seen := {}
	for _step in range(MAX_PREFIX_RECORDS):
		if cursor == end:
			# This is the face-join pointer, not a decoded face record or a blank.
			return {"ok": true, "guards": guards, "selection": {}, "copies": [], "boundary": {"kind": "face_join", "offset": end, "end_offset": end, "routine_id": -1}}
		if cursor < start or cursor > end or seen.has(cursor):
			return _error("Mahoko standing branch escaped its selector or revisited a record.")
		seen[cursor] = true
		var record := _record(code, cursor, end)
		if record.is_empty():
			return _error("Mahoko standing prefix contains an undecodable source record.")
		match str(record.op):
			"source_line_marker":
				if record.end_offset != cursor + 5:
					return _error("Mahoko standing source-line record boundary changed.")
				cursor = record.end_offset
			"branch_if_not_true":
				var ast: Dictionary = record.operands[0].value.ast
				if not _safe_condition(ast):
					return _error("Mahoko standing guard contains an unqualified state read or operation.")
				var evaluated := ExpressionScript.new().evaluate(ast, state)
				if not evaluated.get("ok", false):
					return _error("Mahoko standing condition evaluation failed.")
				var next: int = record.end_offset if evaluated.value == 1 else record.operands[1].value
				if next < record.end_offset or next > end:
					return _error("Mahoko standing branch target is outside its forward boundary.")
				guards.append({"offset": cursor, "end_offset": record.end_offset, "value": evaluated.value, "next_offset": next})
				cursor = next
			"banked_u16_write_run":
				var selected := _load_copies(code, cursor, end)
				if selected.get("ok", false):
					selected["guards"] = guards
				return selected
			_:
				return _error("Mahoko standing prefix reached an unsupported source operation.")
	return _error("Mahoko standing source-prefix budget was exhausted.")


func _load_copies(code: PackedByteArray, offset: int, end: int) -> Dictionary:
	var load := _record(code, offset, end, "banked_u16_write_run")
	if not _surface_write(load, 2):
		return _error("Mahoko standing producer is not the exact surface-2 write.")
	var outer: int = load.end_offset
	if outer >= end or code[outer] != 0x0D:
		return _error("Mahoko standing MMO outer command is missing.")
	var marker := _record(code, outer + 1, end, "mmo_resource_marker")
	if marker.is_empty():
		return _error("Mahoko standing MMO marker is not a complete source record.")
	var resource: Dictionary = marker.operands[0]
	var name := str(resource.get("name", "")).to_upper()
	if (
		name not in ["B1.MMO", "B2.MMO", "B3.MMO", "B4.MMO"]
		or resource.get("argument_count", -1) != 1
		or resource.get("outer_command_source_offset", -1) != outer
		or resource.get("native_active_surface_storage", "") != "banked_u16"
		or resource.get("native_active_surface_bank", -1) != 0
		or resource.get("native_active_surface_storage_index", -1) != 1
	):
		return _error("Mahoko standing MMO producer identity changed.")
	var active := _record(code, marker.end_offset, end, "banked_u16_write_run")
	if not _surface_write(active, 7):
		return _error("Mahoko standing post-load active-surface write changed.")
	var cursor: int = active.end_offset
	var copies: Array[Dictionary] = []
	for mode in [0, 1]:
		var record := _record(code, cursor, end, "surface_operation")
		if record.is_empty():
			return _error("Mahoko standing symbolic copy record is unavailable.")
		var operation: Dictionary = record.operands[0]
		var expressions: Array[Dictionary] = []
		for expression in operation.get("expressions", []):
			expressions.append(expression.get("ast", {}).duplicate(true))
		var signatures: Array = expressions.map(func(ast): return _signature(ast))
		var semantics: String = ["opaque_rectangle_copy_confirmed", "rgb_chroma_key_rectangle_copy_confirmed"][mode]
		if operation.get("mode", -1) != mode or signatures != _copy_signature(mode) or operation.get("native_operation_semantics", "") != semantics:
			return _error("Mahoko standing copy expression or native operation changed.")
		copies.append({"offset": cursor, "end_offset": record.end_offset, "mode": mode, "expressions": expressions, "native_operation_semantics": semantics, "active_surface": 7, "evaluation": "symbolic_not_evaluated"})
		cursor = record.end_offset
	var write := _record(code, cursor, end, "global_u8_write_run")
	if write.is_empty() or write.operands[0].value != 4000:
		return _error("Mahoko standing pre-refresh flag write changed.")
	var pairs: Array = write.operands[1].get("pairs", [])
	if pairs.size() != 1 or not _literal(pairs[0].expression.ast, 1) or pairs[0].get("continuation", -1) != 0:
		return _error("Mahoko standing pre-refresh flag value changed.")
	var call := _record(code, write.end_offset, end, "script_transfer")
	if call.is_empty():
		return _error("Mahoko standing refresh boundary is unavailable.")
	var records: Array = call.operands[0].get("records", [])
	if records.size() != 1 or not _literal(records[0].get("value", {}).get("ast", {}), 22):
		return _error("Mahoko standing refresh boundary does not call routine 22.")
	return {"ok": true, "selection": {"entry": name, "offset": outer + 1, "end_offset": marker.end_offset, "outer_command_offset": outer, "load_surface": 2}, "copies": copies, "boundary": {"kind": "shared_routine", "offset": call.source_offset, "end_offset": call.end_offset, "routine_id": 22}}


func _copy_signature(mode: int) -> Array:
	var x := ["banked_u16", 0, 17]
	var y := ["banked_u16", 0, 18]
	var width := ["banked_u16", 0, 19]
	var height := ["banked_u16", 0, 20]
	var destination := ["banked_u16", 0, 23]
	if mode == 0:
		return [0, 0, 0, 639, 399, 1, 0, 0, destination]
	return [1, x, y, ["subtract", ["add", x, width], 1], ["subtract", ["add", y, height], 1], 2, x, y, destination]


func _signature(ast: Dictionary, depth := 0) -> Variant:
	if depth > 16:
		return null
	match str(ast.get("type", "")):
		"literal":
			return ast.get("value")
		"state_ref":
			return [ast.get("storage"), ast.get("bank"), _signature(ast.get("index", {}), depth + 1)]
		"binary":
			return [ast.get("op"), _signature(ast.get("lhs", {}), depth + 1), _signature(ast.get("rhs", {}), depth + 1)]
	return null


func _record(code: PackedByteArray, offset: int, end: int, operation := "") -> Dictionary:
	if offset < 0 or offset >= end:
		return {}
	var record := Decoder.new().decode_at_structural(code, offset, end)
	if not record.get("ok", false) or record.get("end_offset", end + 1) > end or record.get("end_offset", offset) <= offset:
		return {}
	if not operation.is_empty() and record.get("op", "") != operation:
		return {}
	return record


func _surface_write(record: Dictionary, value: int) -> bool:
	if record.is_empty():
		return false
	var operands: Array = record.operands
	var pairs: Array = operands[2].get("pairs", [])
	return _literal(operands[0].value.ast, 1) and operands[1].value == 0 and pairs.size() == 1 and _literal(pairs[0].expression.ast, value) and pairs[0].get("continuation", -1) == 0


func _safe_condition(ast: Dictionary, depth := 0) -> bool:
	if depth > 16:
		return false
	match str(ast.get("type", "")):
		"literal":
			return true
		"state_ref":
			if ast.get("bank", -1) != 0:
				return false
			return (ast.get("storage", "") == "state_u16" and _literal(ast.get("index", {}), 7)) or (ast.get("storage", "") == "global_u8" and _literal(ast.get("index", {}), 206))
		"binary":
			return ast.get("op", "") in ["equal", "less_than", "greater_than", "logical_and", "logical_or"] and _safe_condition(ast.get("lhs", {}), depth + 1) and _safe_condition(ast.get("rhs", {}), depth + 1)
	return false


func _same_plan_value(actual: Variant, expected: Variant, depth := 0) -> bool:
	if depth > 32:
		return false
	if expected is Dictionary:
		if not actual is Dictionary or actual.size() != expected.size():
			return false
		for key in actual:
			if typeof(key) != TYPE_STRING or not expected.has(key) or not _same_plan_value(actual[key], expected[key], depth + 1):
				return false
		return true
	if expected is Array:
		if not actual is Array or actual.size() != expected.size():
			return false
		for index in range(expected.size()):
			if not _same_plan_value(actual[index], expected[index], depth + 1):
				return false
		return true
	if typeof(expected) == TYPE_INT:
		if typeof(actual) == TYPE_FLOAT:
			return is_finite(actual) and actual == floor(actual) and actual == float(expected)
		return typeof(actual) == TYPE_INT and actual == expected
	return typeof(actual) == typeof(expected) and actual == expected


func _literal(ast: Dictionary, value: int) -> bool:
	return ast.get("type", "") == "literal" and ast.get("value") == value


func _word(value: Variant) -> bool:
	return typeof(value) == TYPE_INT and value >= 0 and value <= 65535


func _plan_word(value: Variant) -> bool:
	return _word(value) or (typeof(value) == TYPE_FLOAT and is_finite(value) and value >= 0.0 and value <= 65535.0 and value == floor(value))


func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message}
