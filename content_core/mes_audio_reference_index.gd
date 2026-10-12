class_name KakyuMesAudioReferenceIndex
extends RefCounted

const DecoderScript := preload("res://content_core/mes_instruction_decoder.gd")
const BgmCatalogScript := preload("res://content_core/mes_bgm_catalog.gd")
const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")
const MAX_INSTRUCTIONS := 500000

var _decoder := DecoderScript.new()


func index_document(mes_entry_name: String, document: Dictionary) -> Dictionary:
	var normalized_entry := mes_entry_name.strip_edges().to_upper()
	if normalized_entry.is_empty():
		return _error("MES source entry name is required.")
	if not document.get("ok", false):
		return _error("A valid MES container document is required.")
	var references: Array[Dictionary] = []
	var code: PackedByteArray = document.bytecode
	var ranges := _document_ranges(document)
	var instruction_starts: Dictionary = {}
	var diagnostics: Array[Dictionary] = []
	for region in ranges:
		var decoded := _decoder.decode_region(code, int(region.offset), int(region.end_offset), MAX_INSTRUCTIONS)
		var instructions: Array = decoded.get("instructions", [])
		for instruction in instructions:
			instruction_starts[int(instruction.source_offset)] = true
		for instruction_index in range(instructions.size() - 1):
			var assignment: Dictionary = instructions[instruction_index]
			var call: Dictionary = instructions[instruction_index + 1]
			assignment["region"] = str(region.id)
			call["region"] = str(region.id)
			_append_bgm_reference(normalized_entry, assignment, call, references)
		if not decoded.get("ok", false):
			diagnostics.append({
				"region": str(region.id),
				"source_offset": int(decoded.get("decoded_end_offset", -1)),
				"error": str(decoded.get("error", "Strict MES audio scan stopped.")),
			})
	_append_voice_references(normalized_entry, code, ranges, instruction_starts, references)

	references.sort_custom(_reference_less)
	return {
		"ok": true,
		"schema": ContentCoreVersionScript.MES_AUDIO_REFERENCE_INDEX_SCHEMA,
		"mes_entry": normalized_entry,
		"reference_count": references.size(),
		"references": references,
		"analysis_complete": diagnostics.is_empty(),
		"analysis_diagnostic_count": diagnostics.size(),
	}


func _append_bgm_reference(
	mes_entry: String,
	assignment: Dictionary,
	call: Dictionary,
	output: Array[Dictionary]
) -> void:
	if not _is_confirmed_bgm_pair(assignment, call):
		return
	var selector := _literal_argument_selector(assignment)
	var audio_entry := BgmCatalogScript.resolve_entry(selector).to_upper()
	if audio_entry.is_empty():
		return
	output.append({
		"audio_entry": audio_entry,
		"audio_kind": "bgm",
		"target_archives": ["bgm.arc"],
		"mes_entry": mes_entry,
		"source_offset": int(assignment.get("source_offset", -1)),
		"call_offset": int(call.get("source_offset", -1)),
		"region": str(assignment.get("region", "unassigned")),
		"boundary": "strict_adjacent_instructions",
		"evidence": "literal_argument_slot_1_then_shared_routine_23",
		"selector": selector,
	})


func _append_voice_references(
	mes_entry: String,
	code: PackedByteArray,
	ranges: Array[Dictionary],
	instruction_starts: Dictionary,
	output: Array[Dictionary]
) -> void:
	var offset := 0
	while offset < code.size():
		if int(code[offset]) != 0x0D:
			offset += 1
			continue
		var marker := _decoder.decode_resource_marker_at(code, offset, code.size())
		if not marker.get("matched", false) or not marker.get("result", {}).get("ok", false):
			offset += 1
			continue
		var instruction: Dictionary = marker.result
		if str(instruction.get("op", "")) == "voice_marker":
			var operands: Array = instruction.get("operands", [])
			if not operands.is_empty() and operands[0] is Dictionary:
				var operand: Dictionary = operands[0]
				output.append({
					"audio_entry": str(operand.get("name", "")).to_upper(),
					"audio_kind": "voice",
					"target_archives": ["voice.arc", "tina1.arc", "tina2.arc"],
					"mes_entry": mes_entry,
					"source_offset": offset,
					"call_offset": -1,
					"region": _find_region(offset, ranges),
					"boundary": "strict_indexed" if instruction_starts.has(offset) else "bounded_envelope_scan",
					"evidence": "confirmed_voice_marker_envelope",
					"selector": -1,
				})
		offset = maxi(offset + 1, int(instruction.get("end_offset", offset + 1)))


func _document_ranges(document: Dictionary) -> Array[Dictionary]:
	var ranges: Array[Dictionary] = []
	var bootstrap: Dictionary = document.get("bootstrap", {})
	if int(bootstrap.get("size", 0)) > 0:
		ranges.append({
			"id": "bootstrap",
			"offset": int(bootstrap.offset),
			"end_offset": int(bootstrap.end_offset),
		})
	for untyped_entry in document.get("entries", []):
		var entry: Dictionary = untyped_entry
		ranges.append({
			"id": str(entry.id),
			"offset": int(entry.offset),
			"end_offset": int(entry.end_offset),
		})
	return ranges


func _find_region(offset: int, ranges: Array[Dictionary]) -> String:
	for range_record in ranges:
		if offset >= int(range_record.offset) and offset < int(range_record.end_offset):
			return str(range_record.id)
	return "unassigned"


func build(sources: Array) -> Dictionary:
	var indexed_documents: Array[Dictionary] = []
	for untyped_source in sources:
		if not untyped_source is Dictionary:
			indexed_documents.append(_error("MES source record is malformed."))
			continue
		var source: Dictionary = untyped_source
		indexed_documents.append(index_document(str(source.get("entry_name", "")), source.get("document", {})))
	return build_indexed(indexed_documents)


func build_indexed(indexed_documents: Array) -> Dictionary:
	var references: Array[Dictionary] = []
	var diagnostics: Array[Dictionary] = []
	var source_count := 0
	for untyped_indexed in indexed_documents:
		if not untyped_indexed is Dictionary:
			diagnostics.append({"mes_entry": "", "error": "Indexed MES audio source is malformed."})
			continue
		var indexed: Dictionary = untyped_indexed
		if not indexed.get("ok", false):
			diagnostics.append({
				"mes_entry": str(indexed.get("mes_entry", "")).to_upper(),
				"error": str(indexed.get("error", "MES audio reference indexing failed.")),
			})
			continue
		if str(indexed.get("schema", "")) != ContentCoreVersionScript.MES_AUDIO_REFERENCE_INDEX_SCHEMA:
			diagnostics.append({
				"mes_entry": str(indexed.get("mes_entry", "")).to_upper(),
				"error": "Indexed MES audio source uses an unsupported schema.",
			})
			continue
		source_count += 1
		references.append_array(indexed.references)
		if not indexed.get("analysis_complete", false):
			diagnostics.append({
				"mes_entry": str(indexed.mes_entry),
				"error": "Strict MES analysis stopped at one or more bounded regions; confirmed envelopes were retained.",
			})

	references.sort_custom(_reference_less)
	var by_audio_entry: Dictionary = {}
	var audio_kind_counts := {"bgm": 0, "voice": 0}
	for reference in references:
		var key := str(reference.audio_entry).to_upper()
		if not by_audio_entry.has(key):
			by_audio_entry[key] = []
		(by_audio_entry[key] as Array).append(reference.duplicate(true))
		var kind := str(reference.get("audio_kind", ""))
		if audio_kind_counts.has(kind):
			audio_kind_counts[kind] = int(audio_kind_counts[kind]) + 1
	return {
		"ok": true,
		"schema": ContentCoreVersionScript.MES_AUDIO_REFERENCE_INDEX_SCHEMA,
		"source_count": source_count,
		"reference_count": references.size(),
		"audio_entry_count": by_audio_entry.size(),
		"audio_kind_counts": audio_kind_counts,
		"references": references,
		"by_audio_entry": by_audio_entry,
		"diagnostics": diagnostics,
		"diagnostic_count": diagnostics.size(),
	}


func find(index: Dictionary, audio_entry_name: String) -> Dictionary:
	if (
		not index.get("ok", false)
		or str(index.get("schema", "")) != ContentCoreVersionScript.MES_AUDIO_REFERENCE_INDEX_SCHEMA
	):
		return _error("A current MES audio reference index is required.")
	var key := audio_entry_name.strip_edges().to_upper()
	var references: Array = index.get("by_audio_entry", {}).get(key, [])
	return {
		"ok": true,
		"schema": ContentCoreVersionScript.MES_AUDIO_REFERENCE_INDEX_SCHEMA,
		"audio_entry": key,
		"reference_count": references.size(),
		"references": references.duplicate(true),
	}


func _is_confirmed_bgm_pair(assignment: Dictionary, call: Dictionary) -> bool:
	return (
		str(assignment.get("op", "")) == "argument_slot_write_run"
		and int(assignment.get("command_id", -1)) == 0x09
		and _literal_argument_selector(assignment) >= 0
		and str(call.get("op", "")) == "script_transfer"
		and int(call.get("command_id", -1)) == 0x1D
		and _literal_script_routine(call) == 23
		and str(assignment.get("region", "")) == str(call.get("region", ""))
		and int(assignment.get("end_offset", -1)) == int(call.get("source_offset", -2))
	)


func _literal_argument_selector(instruction: Dictionary) -> int:
	var operands_value = instruction.get("operands", null)
	if not operands_value is Array or (operands_value as Array).size() != 2:
		return -1
	var slot_value = (operands_value as Array)[0]
	var pairs_value = (operands_value as Array)[1]
	if (
		not slot_value is Dictionary
		or not pairs_value is Dictionary
		or int((slot_value as Dictionary).get("value", -1)) != 1
	):
		return -1
	var pairs = (pairs_value as Dictionary).get("pairs", null)
	if not pairs is Array or (pairs as Array).size() != 1:
		return -1
	var pair = (pairs as Array)[0]
	if not pair is Dictionary or int((pair as Dictionary).get("continuation", -1)) != 0:
		return -1
	return _literal_expression((pair as Dictionary).get("expression", {}))


func _literal_script_routine(instruction: Dictionary) -> int:
	var operands_value = instruction.get("operands", null)
	if not operands_value is Array or (operands_value as Array).size() != 1:
		return -1
	var operand = (operands_value as Array)[0]
	if not operand is Dictionary:
		return -1
	var records_value = (operand as Dictionary).get("records", null)
	if not records_value is Array or (records_value as Array).size() != 1:
		return -1
	var record = (records_value as Array)[0]
	if not record is Dictionary or str((record as Dictionary).get("type", "")) != "expression_record":
		return -1
	return _literal_expression((record as Dictionary).get("value", {}))


func _literal_expression(expression: Dictionary) -> int:
	if not expression.get("ok", false):
		return -1
	var ast_value = expression.get("ast", null)
	if not ast_value is Dictionary or str((ast_value as Dictionary).get("type", "")) != "literal":
		return -1
	return int((ast_value as Dictionary).get("value", -1))


func _reference_less(a: Dictionary, b: Dictionary) -> bool:
	var left := "%s\u001f%s\u001f%08X\u001f%s" % [a.audio_entry, a.mes_entry, int(a.source_offset), a.audio_kind]
	var right := "%s\u001f%s\u001f%08X\u001f%s" % [b.audio_entry, b.mes_entry, int(b.source_offset), b.audio_kind]
	return left < right


func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message}
