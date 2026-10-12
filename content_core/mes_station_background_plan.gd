class_name KakyuMesStationBackgroundPlan
extends RefCounted

# A read-only source selection proof, not a native surface/refresh executor.
const Version := preload("res://content_core/content_core_version.gd")
const ContainerScript := preload("res://content_core/mes_container.gd")
const Decoder := preload("res://content_core/mes_instruction_decoder.gd")
const ExpressionScript := preload("res://content_core/mes_expression.gd")
const State := preload("res://content_core/mes_sandbox_state.gd")
const LIBRARY_SHA256 := "d9aba6eb8dab51fe321e22c868ed0cf38416bba1f0cf2f5d7d719f48e89b8b4d"
const SELECTOR_OFFSET := 0x3B3C
const SELECTOR_END := 0x40C0
const MAX_GUARDS := 16


func build(library_payload: PackedByteArray, mmdd: Variant, hhmm: Variant) -> Dictionary:
	if not _word(mmdd) or not _word(hhmm):
		return _error("Station selection requires exact unsigned-word numeric inputs.")
	var document := ContainerScript.new().parse(library_payload)
	if not document.get("ok", false) or document.entry_sha256 != LIBRARY_SHA256:
		return _error("Station selection requires the audited original LIBLARY.LIB payload.")
	var selected := _select(document.bytecode, SELECTOR_OFFSET, SELECTOR_END, mmdd, hhmm)
	if not selected.get("ok", false):
		return selected
	selected["schema"] = Version.MES_STATION_BACKGROUND_PLAN_SCHEMA
	selected["producer"] = {"core_version": Version.CORE_VERSION, "instruction_schema": Version.MES_INSTRUCTION_SCHEMA}
	selected["source"] = {
		"archive": "mes.arc", "entry": "LIBLARY.LIB", "entry_sha256": document.entry_sha256,
		"bytecode_sha256": document.bytecode_sha256, "routine_id": 27, "selector": 11,
		"offset_basis": "code_start", "offset": SELECTOR_OFFSET, "end_offset": SELECTOR_END,
	}
	selected["input"] = {"mmdd": mmdd, "hhmm": hhmm}
	selected["execution"] = {
		"kind": "read_only_projection", "state_mutation": false, "compatibility": "remake_only",
		"native_cadence": "unresolved", "event_eligibility": "unqualified",
	}
	return selected


func validate(library_payload: PackedByteArray, plan: Dictionary) -> Dictionary:
	var inputs: Variant = plan.get("input", {})
	if not inputs is Dictionary:
		return _error("Station plan inputs are malformed.")
	# Godot's JSON reader represents numbers as floats. Accept only losslessly
	# integral u16 values here; direct build callers still pass actual integers.
	if not _plan_word(inputs.get("mmdd")) or not _plan_word(inputs.get("hhmm")):
		return _error("Station plan inputs are not exact unsigned-word values.")
	var rebuilt := build(library_payload, int(inputs.mmdd), int(inputs.hhmm))
	if not rebuilt.get("ok", false):
		return rebuilt
	if not _same_plan_value(plan, rebuilt):
		return _error("Station plan no longer matches its source-bound selection.")
	return {"ok": true}


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
	# Booleans and strings are never interchangeable with numbers.
	return typeof(actual) == typeof(expected) and actual == expected


func _select(code: PackedByteArray, start: int, end: int, mmdd: int, hhmm: int) -> Dictionary:
	if start < 0 or end <= start or end > code.size() or not _word(mmdd) or not _word(hhmm):
		return _error("Station selection bounds or inputs are invalid.")
	var state := State.new(1)
	state.write_value("global_i32", 1, 11)
	state.write_value("state_u16", 7, mmdd)
	state.write_value("state_u16", 19, hhmm)
	var guards: Array[Dictionary] = []
	var cursor := start
	var seen := {}
	for _step in range(MAX_GUARDS):
		if cursor < start or cursor >= end or seen.has(cursor):
			return _error("Station branch escaped its selector or revisited a record.")
		seen[cursor] = true
		var guard := _record(code, cursor, end, "branch_if_not_true")
		if not guard.get("ok", false):
			# Only the exact active-surface write can end the conditional prefix.
			var selected := _load_and_copy(code, cursor, end)
			if selected.get("ok", false):
				selected["guards"] = guards
			return selected
		var ast: Dictionary = guard.operands[0].value.ast
		if not _safe_condition(ast):
			return _error("Station condition contains an unqualified state read or operation.")
		var evaluated := ExpressionScript.new().evaluate(ast, state)
		if not evaluated.get("ok", false):
			return _error("Station condition evaluation failed.")
		var next: int = guard.end_offset if evaluated.value == 1 else guard.operands[1].value
		# The original selector is a forward-only decision tree. Never reframe a
		# condition's payload as a sibling command, even in synthetic checks.
		if next < guard.end_offset or next >= end:
			return _error("Station branch target is outside the forward record boundary.")
		guards.append({"offset": cursor, "end_offset": guard.end_offset, "value": evaluated.value, "next_offset": next})
		cursor = next
	return _error("Station condition budget was exhausted.")


func _load_and_copy(code: PackedByteArray, offset: int, end: int) -> Dictionary:
	var load_surface := _record(code, offset, end, "banked_u16_write_run")
	if not _surface_write(load_surface, 2):
		return _error("Station selection did not reach the exact surface-2 producer.")
	var outer: int = load_surface.end_offset
	if outer >= end or code[outer] != 0x0D:
		return _error("Station MMO outer command is missing.")
	var marker := _record(code, outer + 1, end, "mmo_resource_marker")
	if not marker.get("ok", false):
		return _error("Station MMO marker is not one complete source record.")
	var resource: Dictionary = marker.operands[0]
	var name := str(resource.get("name", "")).to_upper()
	if (
		name.is_empty() or not name.ends_with(".MMO") or name.contains("/") or name.contains("\\") or name.contains(":") or name.contains("..")
		or resource.get("outer_command_source_offset", -1) != outer
		or resource.get("native_active_surface_storage", "") != "banked_u16"
		or resource.get("native_active_surface_bank", -1) != 0
		or resource.get("native_active_surface_storage_index", -1) != 1
	):
		return _error("Station MMO producer identity changed.")
	var active := _record(code, marker.end_offset, end, "banked_u16_write_run")
	if not _surface_write(active, 7):
		return _error("Station post-load active surface changed.")
	var copy := _record(code, active.end_offset, end, "surface_operation")
	if not copy.get("ok", false):
		return _error("Station rectangle-copy record is unavailable.")
	var operation: Dictionary = copy.operands[0]
	var values: Array = []
	for expression in operation.get("expressions", []):
		var ast: Dictionary = expression.get("ast", {})
		if ast.get("type", "") != "literal":
			return _error("Station rectangle copy is not constant-bounded.")
		values.append(ast.get("value"))
	if operation.get("mode", -1) != 1 or operation.get("native_operation_semantics", "") != "rgb_chroma_key_rectangle_copy_confirmed" or values != [1, 0, 0, 639, 399, 2, 0, 0, 1]:
		return _error("Station source-2 to destination-1 rectangle copy changed.")
	var refresh := _record(code, copy.end_offset, end, "script_transfer")
	if not refresh.get("ok", false):
		return _error("Station refresh boundary is unavailable.")
	var records: Array = refresh.operands[0].get("records", [])
	if records.size() != 1 or not _literal(records[0].get("value", {}).get("ast", {}), 8):
		return _error("Station refresh boundary does not call routine 8.")
	return {
		"ok": true,
		"selection": {"entry": name, "offset": outer + 1, "end_offset": marker.end_offset, "outer_command_offset": outer, "load_surface": 2},
		"copy": {"offset": copy.source_offset, "end_offset": copy.end_offset, "mode": 1, "source_surface": 2, "destination_surface": 1, "source_rect": [0, 0, 640, 400], "destination": [0, 0], "active_surface": 7},
		"boundary": {"offset": refresh.source_offset, "end_offset": refresh.end_offset, "routine_id": 8},
	}


func _record(code: PackedByteArray, offset: int, end: int, operation: String) -> Dictionary:
	if offset < 0 or offset >= end:
		return {}
	var record := Decoder.new().decode_at_structural(code, offset, end)
	if not record.get("ok", false) or record.get("op", "") != operation or record.get("end_offset", end + 1) > end:
		return {}
	return record


func _surface_write(record: Dictionary, value: int) -> bool:
	if not record.get("ok", false):
		return false
	var operands: Array = record.operands
	var pairs: Array = operands[2].get("pairs", [])
	return _literal(operands[0].value.ast, 1) and operands[1].value == 0 and pairs.size() == 1 and _literal(pairs[0].expression.ast, value)


func _safe_condition(ast: Dictionary, depth := 0) -> bool:
	if depth > 16:
		return false
	match str(ast.get("type", "")):
		"literal":
			return true
		"state_ref":
			if ast.get("bank", -1) != 0:
				return false
			if ast.get("storage", "") == "state_u16":
				return _literal(ast.get("index", {}), 7) or _literal(ast.get("index", {}), 19)
			return ast.get("storage", "") == "global_i32" and _literal(ast.get("index", {}), 1)
		"binary":
			return ast.get("op", "") in ["equal", "less_than", "greater_than", "logical_and", "logical_or"] and _safe_condition(ast.get("lhs", {}), depth + 1) and _safe_condition(ast.get("rhs", {}), depth + 1)
	return false


func _literal(ast: Dictionary, value: int) -> bool:
	return ast.get("type", "") == "literal" and ast.get("value") == value


func _word(value: Variant) -> bool:
	return typeof(value) == TYPE_INT and value >= 0 and value <= 65535


func _plan_word(value: Variant) -> bool:
	return _word(value) or (typeof(value) == TYPE_FLOAT and is_finite(value) and value >= 0.0 and value <= 65535.0 and value == floor(value))


func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message}
