class_name KakyuMesContextIndex
extends RefCounted

const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")



func build(document: Dictionary, audited_offsets: Array[int]) -> Dictionary:
	if not document.get("ok", false):
		return _error("A valid MES container document is required.")
	var source := _document_source(document)
	if source == null:
		return _error("A valid MES container document is required.")
	var code_size := source.size()
	var registrations: Array[Dictionary] = []
	var rejected: Array[Dictionary] = []
	var seen := {}
	for cursor in audited_offsets:
		if seen.has(cursor):
			continue
		seen[cursor] = true
		if cursor < 0 or cursor >= code_size:
			rejected.append({"source_offset": cursor, "reason": "coordinate_out_of_bounds"})
			continue
		var instruction := source.decode_at_structural(cursor, code_size)
		if not instruction.ok:
			rejected.append({"source_offset": cursor, "reason": "coordinate_not_decodable"})
			continue
		if int(instruction.command_id) != 0x14:
			rejected.append({"source_offset": cursor, "reason": "coordinate_not_command14"})
			continue
		var selector := _literal_selector(instruction)
		var target := _context_target(instruction)
		var reason := ""
		if selector < 0:
			reason = "selector_not_literal"
		elif target <= int(instruction.end_offset):
			reason = "target_not_forward"
		elif target > code_size:
			reason = "target_out_of_bounds"
		elif target < code_size:
			var target_instruction := source.decode_at_structural(target, code_size)
			if not target_instruction.ok:
				reason = "target_not_decodable"
		if not reason.is_empty():
			rejected.append({
				"source_offset": cursor,
				"reason": reason,
			})
			continue
		registrations.append({
			"selector": selector,
			"registration_offset": cursor,
			"body_offset": int(instruction.end_offset),
			"skip_target": target,
			"body_size": target - int(instruction.end_offset),
		})

	var by_id := {}
	for registration in registrations:
		var selector := int(registration.selector)
		var matches: Array = by_id.get(selector, [])
		matches.append(registration)
		by_id[selector] = matches
	return {
		"ok": true,
		"schema": ContentCoreVersionScript.MES_CONTEXT_INDEX_SCHEMA,
		"complete": rejected.is_empty(),
		"scope": "caller_supplied_audited_coordinates",
		"audited_coordinate_count": seen.size(),
		"registration_count": registrations.size(),
		"rejected_count": rejected.size(),
		"registrations": registrations,
		"by_id": by_id,
		"rejected": rejected,
	}



# A container document normally carries its bytecode. A document assembled from
# a playback package carries a code source instead; both answer the same
# questions. See mes_code_source.gd.
func _document_source(document: Dictionary) -> KakyuMesCodeSource:
	var supplied = document.get("code_source", null)
	if supplied is KakyuMesCodeSource:
		return supplied
	var code = document.get("bytecode", null)
	if code is PackedByteArray and not (code as PackedByteArray).is_empty():
		return KakyuMesCodeSource.for_bytecode(code)
	return null


func _literal_selector(instruction: Dictionary) -> int:
	var operands: Array = instruction.get("operands", [])
	if operands.is_empty() or str(operands[0].get("type", "")) != "expression":
		return -1
	var expression: Dictionary = operands[0].get("value", {})
	var ast: Dictionary = expression.get("ast", {})
	if not expression.get("ok", false) or str(ast.get("type", "")) != "literal":
		return -1
	return int(ast.value)


func _context_target(instruction: Dictionary) -> int:
	var operands: Array = instruction.get("operands", [])
	if operands.size() != 2 or str(operands[1].get("type", "")) != "code_offset":
		return -1
	return int(operands[1].value)


func _error(message: String) -> Dictionary:
	return {
		"ok": false,
		"schema": ContentCoreVersionScript.MES_CONTEXT_INDEX_SCHEMA,
		"error": message,
	}
