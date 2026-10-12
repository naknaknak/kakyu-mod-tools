class_name KakyuMesLibraryIndex
extends RefCounted

const DecoderScript := preload("res://content_core/mes_instruction_decoder.gd")
const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")

var last_error := ""
var _decoder := DecoderScript.new()


func build(code: PackedByteArray, end_offset := -1) -> Dictionary:
	last_error = ""
	var limit := code.size() if end_offset < 0 else mini(end_offset, code.size())
	if limit <= 0:
		return _error("MES library bytecode is empty.")
	var cursor := 0
	var routines: Array[Dictionary] = []
	var by_id: Dictionary = {}
	while cursor < limit:
		var instruction := _decoder.decode_at(code, cursor, limit)
		if not instruction.ok:
			return _error("MES library index decode failed at 0x%X: %s" % [cursor, str(instruction.error)])
		var command_id := int(instruction.command_id)
		if command_id == 0x1F or command_id == 0x0D:
			cursor = int(instruction.end_offset)
			continue
		if command_id == 0x00:
			if routines.is_empty():
				return _error("MES library terminated before any routine registration.")
			return {
				"ok": true,
				"schema": ContentCoreVersionScript.MES_LIBRARY_INDEX_SCHEMA,
				"registration_count": routines.size(),
				"terminal_offset": cursor,
				"routines": routines,
				"by_id": by_id,
			}
		if command_id != 0x1C or str(instruction.op) != "library_register_skip":
			return _error("Unexpected command 0x%02X at MES library index offset 0x%X." % [command_id, cursor])
		var expression: Dictionary = instruction.operands[0].value
		if not expression.get("ok", false) or str(expression.get("ast", {}).get("type", "")) != "literal":
			return _error("MES library registration at 0x%X does not use a literal routine ID." % cursor)
		var routine_id := int(expression.ast.value)
		if routine_id < 0 or by_id.has(routine_id):
			return _error("MES library routine ID %d at 0x%X is invalid or duplicated." % [routine_id, cursor])
		var body_start := int(instruction.end_offset)
		var body_end := int(instruction.operands[1].value)
		if body_end <= body_start or body_end > limit:
			return _error("MES library routine %d target 0x%X is not a forward in-range skip." % [routine_id, body_end])
		var record := {
			"routine_id": routine_id,
			"registration_offset": cursor,
			"body_offset": body_start,
			"end_offset": body_end,
			"size": body_end - body_start,
		}
		routines.append(record)
		by_id[routine_id] = record.duplicate(true)
		cursor = body_end
	return _error("MES library index reached the bytecode limit without a terminal return.")


func _error(message: String) -> Dictionary:
	last_error = message
	return {"ok": false, "error": message}
