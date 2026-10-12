class_name KakyuMesActiveSurfaceAxAudit
extends RefCounted

const DecoderScript := preload("res://content_core/mes_instruction_decoder.gd")
const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")
const BINDING_SEARCH_BYTES := 0x100

var _decoder := DecoderScript.new()


func scan_document(document: Dictionary, entry_name := "") -> Dictionary:
	if not document.get("ok", false):
		return _error("A valid MES container document is required.")
	if not document.get("bytecode", null) is PackedByteArray:
		return _error("MES container bytecode is missing.")
	var code: PackedByteArray = document.bytecode
	var limit := int(document.get("header", {}).get("code_size", code.size()))
	if limit < 0 or limit > code.size():
		return _error("MES code size is outside the bytecode buffer.")
	var surface8_writes: Array[int] = []
	var chains: Array[Dictionary] = []
	for offset in range(limit):
		if int(code[offset]) != 0x07:
			continue
		var select := _literal_active_surface_write(code, offset, limit)
		if select.is_empty() or int(select.value) != 8:
			continue
		surface8_writes.append(offset)
		# Core 0.316.0 (2026-09-13): the MMO marker is the whole System.function[9]
		# call, so the marker record starts at the 0x0D byte and its outer command
		# offset is the same byte.
		var marker_outer_offset := int(select.end_offset)
		var marker_offset := marker_outer_offset
		var marker := _decoder.decode_at_structural(code, marker_offset, limit)
		if not marker.get("ok", false) or str(marker.get("op", "")) != "mmo_resource_marker":
			continue
		var marker_operand: Dictionary = marker.get("operands", [{}])[0]
		if not _is_active_surface_operand(marker_operand):
			continue
		var restore := _literal_active_surface_write(code, int(marker.end_offset), limit)
		if restore.is_empty() or int(restore.value) != 7:
			continue
		var ax := _decoder.decode_at_structural(code, int(restore.end_offset), limit)
		if not ax.get("ok", false) or str(ax.get("op", "")) != "ax_resource_marker":
			continue
		var ax_operand: Dictionary = ax.get("operands", [{}])[0]
		var binding := _find_binding(code, int(ax.end_offset), limit)
		chains.append({
			"entry": entry_name,
			"boundary": "ordered_structural_bytes",
			"reachability": "not_proven_by_scan",
			"select_offset": offset,
			"select_end_offset": int(select.end_offset),
			"selected_surface": 8,
			"mmo_outer_offset": marker_outer_offset,
			"mmo_marker_offset": marker_offset,
			"mmo_end_offset": int(marker.end_offset),
			"mmo_name": str(marker_operand.get("name", "")),
			"active_surface_storage": str(marker_operand.native_active_surface_storage),
			"active_surface_bank": int(marker_operand.native_active_surface_bank),
			"active_surface_storage_index": int(marker_operand.native_active_surface_storage_index),
			"restore_offset": int(marker.end_offset),
			"restore_end_offset": int(restore.end_offset),
			"restored_surface": 7,
			"ax_marker_offset": int(restore.end_offset),
			"ax_end_offset": int(ax.end_offset),
			"ax_name": str(ax_operand.get("name", "")),
			"binding_offset": int(binding.get("source_offset", -1)),
			"binding_end_offset": int(binding.get("end_offset", -1)),
			"binding_row": int(binding.get("row", -1)),
			"binding_column": int(binding.get("column", -1)),
		})
	return {
		"ok": true,
		"schema": ContentCoreVersionScript.MES_ACTIVE_SURFACE_AX_AUDIT_SCHEMA,
		"entry": entry_name,
		"surface8_write_count": surface8_writes.size(),
		"surface8_writes": surface8_writes,
		"canonical_chain_count": chains.size(),
		"chains": chains,
	}


func _literal_active_surface_write(code: PackedByteArray, offset: int, limit: int) -> Dictionary:
	var instruction := _decoder.decode_at_structural(code, offset, limit)
	if not instruction.get("ok", false) or str(instruction.get("op", "")) != "banked_u16_write_run":
		return {}
	var operands: Array = instruction.get("operands", [])
	if operands.size() < 3 or int(operands[1].get("value", -1)) != 0:
		return {}
	var destination: Dictionary = operands[0].get("value", {}).get("ast", {})
	var pairs: Array = operands[2].get("pairs", [])
	if (
		str(destination.get("type", "")) != "literal"
		or int(destination.get("value", -1)) != 1
		or pairs.size() != 1
	):
		return {}
	var value: Dictionary = pairs[0].get("expression", {}).get("ast", {})
	if str(value.get("type", "")) != "literal":
		return {}
	return {
		"value": int(value.get("value", -1)),
		"end_offset": int(instruction.end_offset),
	}


func _is_active_surface_operand(operand: Dictionary) -> bool:
	return (
		str(operand.get("native_active_surface_storage", "")) == "banked_u16"
		and int(operand.get("native_active_surface_bank", -1)) == 0
		and int(operand.get("native_active_surface_storage_index", -1)) == 1
	)


func _find_binding(code: PackedByteArray, start_offset: int, limit: int) -> Dictionary:
	for offset in range(start_offset, mini(limit, start_offset + BINDING_SEARCH_BYTES)):
		if int(code[offset]) not in [0x03, 0x0D]:
			continue
		var instruction := _decoder.decode_at_structural(code, offset, limit)
		if not instruction.get("ok", false) or str(instruction.get("op", "")) != "ax_presentation_binding":
			continue
		var operand: Dictionary = instruction.get("operands", [{}])[0]
		return {
			"source_offset": offset,
			"end_offset": int(instruction.end_offset),
			"row": int(operand.get("cell_row", -1)),
			"column": int(operand.get("cell_column", -1)),
		}
	return {}


func _error(message: String) -> Dictionary:
	return {
		"ok": false,
		"schema": ContentCoreVersionScript.MES_ACTIVE_SURFACE_AX_AUDIT_SCHEMA,
		"error": message,
	}
