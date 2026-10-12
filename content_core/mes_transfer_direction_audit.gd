class_name KakyuMesTransferDirectionAudit
extends RefCounted

const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")

const TRANSFER_OPS := ["branch_if_not_true", "continuation_transfer"]


func audit(document: Dictionary, analysis: Dictionary) -> Dictionary:
	if (
		not document.get("ok", false)
		or str(document.get("schema", "")) != ContentCoreVersionScript.MES_CONTAINER_SCHEMA
		or not analysis.get("ok", false)
		or str(analysis.get("schema", "")) != ContentCoreVersionScript.MES_ANALYSIS_SCHEMA
	):
		return _error("A current MES container and analysis index are required.")
	var counts := {}
	var same_region_backward: Array[Dictionary] = []
	var invalid_targets: Array[Dictionary] = []
	var transfer_count := 0
	for untyped_instruction in analysis.get("instructions", []):
		var instruction: Dictionary = untyped_instruction
		var op := str(instruction.get("op", ""))
		if op not in TRANSFER_OPS:
			continue
		transfer_count += 1
		var source_offset := int(instruction.get("source_offset", -1))
		var source_region := str(instruction.get("region", ""))
		var target := _code_target(instruction)
		var target_region := _region_for_offset(document, target)
		if source_offset < 0 or target < 0 or target_region.is_empty():
			invalid_targets.append({
				"op": op,
				"source_offset": source_offset,
				"target_offset": target,
			})
			_increment(counts, "%s_invalid" % op)
			continue
		var direction := _direction(source_offset, target)
		var region_relation := "same_region" if source_region == target_region else "cross_region"
		_increment(counts, "%s_%s_%s" % [op, direction, region_relation])
		if direction == "backward" and region_relation == "same_region":
			same_region_backward.append({
				"op": op,
				"source_offset": source_offset,
				"target_offset": target,
				"region": source_region,
			})
	same_region_backward.sort_custom(_sort_candidate)
	invalid_targets.sort_custom(_sort_candidate)
	return {
		"ok": true,
		"schema": ContentCoreVersionScript.MES_TRANSFER_DIRECTION_AUDIT_SCHEMA,
		"source": {
			"entry": str(document.get("source", {}).get("entry", "")),
			"entry_sha256": str(document.get("entry_sha256", "")),
		},
		"transfer_count": transfer_count,
		"counts": counts,
		"same_region_backward_candidates": same_region_backward,
		"invalid_targets": invalid_targets,
		"opaque_boundary_count": int(analysis.get("opaque_boundary_count", 0)),
		"opaque_bytes": _sum_bytes(analysis.get("opaque_boundaries", [])),
		"scope": "confirmed_typed_branch_and_continuation_targets",
		"opaque_policy": "unresolved_not_scanned_as_transfer",
	}


func _code_target(instruction: Dictionary) -> int:
	for untyped_operand in instruction.get("operands", []):
		var operand: Dictionary = untyped_operand
		if str(operand.get("type", "")) == "code_offset":
			return int(operand.get("value", -1))
	return -1


func _region_for_offset(document: Dictionary, offset: int) -> String:
	var code_size := int(document.get("header", {}).get("code_size", -1))
	if offset < 0 or offset >= code_size:
		return ""
	var bootstrap: Dictionary = document.get("bootstrap", {})
	if offset >= int(bootstrap.get("offset", 0)) and offset < int(bootstrap.get("end_offset", 0)):
		return "bootstrap"
	for untyped_entry in document.get("entries", []):
		var entry: Dictionary = untyped_entry
		if offset >= int(entry.get("offset", -1)) and offset < int(entry.get("end_offset", -1)):
			return str(entry.get("id", ""))
	return ""


func _direction(source: int, target: int) -> String:
	if target < source:
		return "backward"
	if target > source:
		return "forward"
	return "self"


func _increment(counts: Dictionary, key: String) -> void:
	counts[key] = int(counts.get(key, 0)) + 1


func _sum_bytes(rows: Array) -> int:
	var total := 0
	for untyped_row in rows:
		var row: Dictionary = untyped_row
		total += int(row.get("byte_length", 0))
	return total


func _sort_candidate(left: Dictionary, right: Dictionary) -> bool:
	var left_source := int(left.get("source_offset", -1))
	var right_source := int(right.get("source_offset", -1))
	if left_source != right_source:
		return left_source < right_source
	return str(left.get("op", "")) < str(right.get("op", ""))


func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message}
