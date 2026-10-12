class_name KakyuMesRecordAlignmentAudit
extends RefCounted

const DecoderScript := preload("res://content_core/mes_instruction_decoder.gd")
const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")
const ContractValues := preload("res://content_core/contract_values.gd")
const MAX_INSTRUCTIONS := 500000
const SAMPLE_LIMIT := 24

var _decoder := DecoderScript.new()


func audit(document: Dictionary) -> Dictionary:
	if not document.get("ok", false):
		return _error("A valid MES container document is required.")
	if not document.get("bytecode", null) is PackedByteArray:
		return _error("MES container bytecode is missing.")
	var code: PackedByteArray = document.bytecode
	var regions := _regions(document)
	var instruction_count := 0
	var instruction_bytes := 0
	var compound_record_count := 0
	var compound_record_bytes := 0
	var compound_families := {}
	var compound_family_bytes := {}
	var opaque_boundaries: Array[Dictionary] = []
	var opaque_bytes := 0
	var samples: Array[Dictionary] = []
	var failures: Array[String] = []
	var framed_bytes := 0
	var total_bytes := 0
	for region in regions:
		var region_start := int(region.offset)
		var region_end := int(region.end_offset)
		total_bytes += region_end - region_start
		var decoded := _decoder.decode_region_structural_aligned(
			code,
			region_start,
			region_end,
			MAX_INSTRUCTIONS
		)
		var cursor := region_start
		for untyped_instruction in decoded.get("instructions", []):
			var instruction: Dictionary = untyped_instruction
			var start := int(instruction.get("source_offset", -1))
			var end := int(instruction.get("end_offset", -1))
			var raw_hex := code.slice(start, end).hex_encode() if start >= 0 and end >= start else ""
			if (
				start != cursor
				or end <= start
				or end > region_end
				or int(instruction.get("byte_length", -1)) != end - start
				or str(instruction.get("raw_hex", "")) != raw_hex
			):
				failures.append("%s instruction 0x%X..0x%X is not an exact contiguous record" % [
					str(region.id), start, end,
				])
				break
			var byte_length := end - start
			instruction_count += 1
			instruction_bytes += byte_length
			framed_bytes += byte_length
			var family := _compound_family(instruction)
			if not family.is_empty():
				compound_record_count += 1
				compound_record_bytes += byte_length
				compound_families[family] = int(compound_families.get(family, 0)) + 1
				compound_family_bytes[family] = int(compound_family_bytes.get(family, 0)) + byte_length
				if samples.size() < SAMPLE_LIMIT:
					samples.append({
						"region": str(region.id),
						"source_offset": start,
						"end_offset": end,
						"family": family,
					})
			cursor = end
		if not decoded.get("ok", false):
			var opaque_start := int(decoded.get("decoded_end_offset", cursor))
			var opaque_data := code.slice(opaque_start, region_end)
			if opaque_start != cursor or opaque_start < region_start or opaque_start >= region_end:
				failures.append("%s structural stop does not begin at the framed cursor" % str(region.id))
			else:
				var boundary := {
					"type": "opaque_region_tail",
					"region": str(region.id),
					"source_offset": opaque_start,
					"end_offset": region_end,
					"byte_length": opaque_data.size(),
					"raw_hex": opaque_data.hex_encode(),
					"raw_sha256": ContractValues.sha256(opaque_data),
					"boundary": "byte_preserving_fail_closed",
					"reason": str(decoded.get("error", "structural decode stopped")),
				}
				opaque_boundaries.append(boundary)
				opaque_bytes += opaque_data.size()
				framed_bytes += opaque_data.size()
				cursor = region_end
		if cursor != region_end:
			failures.append("%s coverage ends at 0x%X instead of 0x%X" % [
				str(region.id), cursor, region_end,
			])
	if total_bytes != code.size():
		failures.append("Container regions cover %d of %d code bytes" % [total_bytes, code.size()])
	if framed_bytes != total_bytes:
		failures.append("Typed and opaque records cover %d of %d region bytes" % [framed_bytes, total_bytes])
	return {
		"ok": failures.is_empty(),
		"schema": ContentCoreVersionScript.MES_RECORD_ALIGNMENT_AUDIT_SCHEMA,
		"region_count": regions.size(),
		"code_bytes": code.size(),
		"framed_bytes": framed_bytes,
		"instruction_count": instruction_count,
		"instruction_bytes": instruction_bytes,
		"compound_record_count": compound_record_count,
		"compound_record_bytes": compound_record_bytes,
		"compound_families": compound_families,
		"compound_family_bytes": compound_family_bytes,
		"opaque_boundary_count": opaque_boundaries.size(),
		"opaque_bytes": opaque_bytes,
		"opaque_boundaries": opaque_boundaries,
		"samples": samples,
		"failure_count": failures.size(),
		"failures": failures,
		"coverage_policy": "every_region_byte_exactly_one_typed_instruction_or_opaque_tail",
	}


func _regions(document: Dictionary) -> Array[Dictionary]:
	var regions: Array[Dictionary] = []
	var bootstrap: Dictionary = document.get("bootstrap", {})
	if int(bootstrap.get("size", 0)) > 0:
		regions.append({
			"id": "bootstrap",
			"offset": int(bootstrap.offset),
			"end_offset": int(bootstrap.end_offset),
		})
	for untyped_entry in document.get("entries", []):
		var entry: Dictionary = untyped_entry
		regions.append({
			"id": str(entry.id),
			"offset": int(entry.offset),
			"end_offset": int(entry.end_offset),
		})
	if regions.is_empty() and int(document.get("header", {}).get("code_size", 0)) > 0:
		regions.append({
			"id": "zero_table_code",
			"offset": 0,
			"end_offset": int(document.header.code_size),
		})
	return regions


func _compound_family(instruction: Dictionary) -> String:
	if instruction.has("native_payload_boundary"):
		return "opaque_native_stream_branch_guard"
	if instruction.has("native_record_consumption"):
		return str(instruction.native_record_consumption)
	if instruction.has("native_stream_consumption") and not instruction.has("native_stream_probe"):
		return str(instruction.native_stream_consumption)
	if str(instruction.get("op", "")) == "mmo_resource_marker":
		return "typed_presentation_subcommand_9_mmo_record"
	var operands: Array = instruction.get("operands", [])
	if not operands.is_empty() and str(operands[0].get("type", "")) == "record_list":
		return "typed_record_list_command_%02x" % int(instruction.get("command_id", -1))
	return ""


func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message}
