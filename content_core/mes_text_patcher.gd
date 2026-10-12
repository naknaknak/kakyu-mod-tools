class_name KakyuMesTextPatcher
extends RefCounted

const MesContainerScript := preload("res://content_core/mes_container.gd")
const MesAnalysisScript := preload("res://content_core/mes_analysis_index.gd")
const Cp932CodecScript := preload("res://content_core/cp932_codec.gd")
const ContractValues := preload("res://content_core/contract_values.gd")

var last_error := ""
var _parser := MesContainerScript.new()
var _analysis_builder := MesAnalysisScript.new()
var _cp932 := Cp932CodecScript.new()


func validate_replacement_text(text: String, expected_byte_length := -1) -> Dictionary:
	var encoded := _cp932.encode(text)
	if not encoded.ok:
		return {"ok": false, "error_code": "cp932", "error": "Text cannot encode as CP932: %s" % encoded.error}
	var replacement_bytes: PackedByteArray = encoded.data
	if replacement_bytes.has(0):
		return {"ok": false, "error_code": "embedded_nul", "error": "Text contains an embedded NUL."}
	var native_bytes := _validate_native_text_bytes(replacement_bytes)
	if not native_bytes.ok:
		return {"ok": false, "error_code": "native_byte_range", "error": native_bytes.error, "byte_length": replacement_bytes.size()}
	if expected_byte_length >= 0 and replacement_bytes.size() != expected_byte_length:
		return {
			"ok": false,
			"error_code": "byte_length",
			"error": "Text requires exactly %d CP932 bytes; encoded text uses %d." % [expected_byte_length, replacement_bytes.size()],
			"byte_length": replacement_bytes.size(),
			"expected_byte_length": expected_byte_length,
		}
	return {
		"ok": true,
		"data": replacement_bytes,
		"byte_length": replacement_bytes.size(),
		"expected_byte_length": expected_byte_length,
	}


func validate_native_double_byte_replacement(text: String, expected_byte_length := -1) -> Dictionary:
	var validation := validate_replacement_text(text, expected_byte_length)
	if not validation.ok:
		return validation
	var data: PackedByteArray = validation.data
	var offset := 0
	while offset < data.size():
		var value := int(data[offset])
		if not _is_native_double_byte_lead(value) or offset + 1 >= data.size():
			return {
				"ok": false,
				"error_code": "native_projection",
				"error": "Replacement byte %d does not begin a complete native double-byte character." % offset,
				"byte_length": data.size(),
				"expected_byte_length": expected_byte_length,
			}
		offset += 2
	return validation


func patch_equal_length(
	source_data: PackedByteArray,
	edits: Array[Dictionary],
	require_native_projection_match := false
) -> Dictionary:
	last_error = ""
	if edits.is_empty():
		return _error("At least one MES text edit is required.")
	var document := _parser.parse(source_data)
	if not document.ok:
		return _error("Source MES is invalid: %s" % document.error)
	var analysis := _analysis_builder.build(document)
	if not analysis.ok:
		return _error("Source MES analysis failed: %s" % analysis.error)
	var messages_by_offset := {}
	for untyped_message in analysis.messages:
		var message: Dictionary = untyped_message
		messages_by_offset[int(message.source_offset)] = message

	var prepared: Array[Dictionary] = []
	var seen_offsets := {}
	for edit in edits:
		var source_offset := int(edit.get("source_offset", -1))
		if source_offset < 0:
			return _error("MES text edit source_offset is invalid.")
		if seen_offsets.has(source_offset):
			return _error("MES text edit targets 0x%X more than once." % source_offset)
		seen_offsets[source_offset] = true
		if not messages_by_offset.has(source_offset):
			return _error("MES text edit 0x%X is not a strict-indexed message." % source_offset)
		var message: Dictionary = messages_by_offset[source_offset]
		if require_native_projection_match and not bool(message.get("native_stream_projection_match", false)):
			return _error("MES text edit 0x%X crosses the original native text-consumption boundary." % source_offset)
		var raw_bytes: PackedByteArray = message.raw_bytes
		if str(edit.get("raw_sha256", "")).to_lower() != str(message.raw_sha256):
			return _error("MES text edit 0x%X original-byte hash is stale." % source_offset)
		var original_decoded := _cp932.decode(raw_bytes)
		if not original_decoded.ok:
			return _error("MES text edit 0x%X source bytes are not strict CP932." % source_offset)
		var replacement_text := str(edit.get("text", ""))
		var replacement_validation := (
			validate_native_double_byte_replacement(replacement_text, raw_bytes.size())
			if require_native_projection_match
			else validate_replacement_text(replacement_text, raw_bytes.size())
		)
		if not replacement_validation.ok:
			return _error("MES text edit 0x%X: %s" % [source_offset, replacement_validation.error])
		var replacement_bytes: PackedByteArray = replacement_validation.data
		var payload_offset := source_offset + 1 if str(message.kind) == "text" else source_offset
		if payload_offset < 0 or payload_offset + raw_bytes.size() >= int(document.header.code_size):
			return _error("MES text edit 0x%X payload range is outside the bytecode." % source_offset)
		var expected_boundary_byte := 0
		if (
			require_native_projection_match
			and str(message.get("native_stream_probe", {}).get("stop_reason", "")) == "single_byte_marker_deferred"
		):
			expected_boundary_byte = 0xFF
		if int(document.bytecode[payload_offset + raw_bytes.size()]) != expected_boundary_byte:
			return _error(
				"MES text edit 0x%X is not followed by its expected native boundary byte 0x%02X."
				% [source_offset, expected_boundary_byte]
			)
		prepared.append({
			"source_offset": source_offset,
			"payload_offset": payload_offset,
			"file_offset": int(document.header.code_offset) + payload_offset,
			"byte_length": raw_bytes.size(),
			"replacement_bytes": replacement_bytes,
			"replacement_text": replacement_text,
		})

	var patched := source_data.duplicate()
	for item in prepared:
		var file_offset := int(item.file_offset)
		var replacement_bytes: PackedByteArray = item.replacement_bytes
		for byte_index in range(replacement_bytes.size()):
			patched[file_offset + byte_index] = replacement_bytes[byte_index]
	var verified := _verify_patch(document, analysis, patched, prepared, require_native_projection_match)
	if not verified.ok:
		return verified
	var records: Array[Dictionary] = []
	for item in prepared:
		records.append({
			"source_offset": item.source_offset,
			"byte_length": item.byte_length,
			"text": item.replacement_text,
			"raw_sha256": ContractValues.sha256(item.replacement_bytes),
		})
	return {
		"ok": true,
		"data": patched,
		"entry_sha256": ContractValues.sha256(patched),
		"edits": records,
		"edit_count": records.size(),
		"compatibility": "original_engine_unverified",
		"text_encoding": "cp932",
		"relocation": "not_required_equal_length",
	}


func _verify_patch(
	source_document: Dictionary,
	source_analysis: Dictionary,
	patched: PackedByteArray,
	prepared: Array[Dictionary],
	require_native_projection_match: bool
) -> Dictionary:
	if patched.size() != int(source_document.header.code_offset) + int(source_document.header.code_size):
		return _error("Patched MES size changed unexpectedly.")
	var document := _parser.parse(patched)
	if not document.ok:
		return _error("Patched MES failed reopen validation: %s" % document.error)
	if document.header.entry_offsets != source_document.header.entry_offsets:
		return _error("Patched MES address table changed unexpectedly.")
	var analysis := _analysis_builder.build(document)
	if not analysis.ok:
		return _error("Patched MES analysis failed: %s" % analysis.error)
	if int(analysis.diagnostic_count) != int(source_analysis.diagnostic_count):
		return _error("Patched MES changed strict decoder boundaries.")
	var messages_by_offset := {}
	for untyped_message in analysis.messages:
		var message: Dictionary = untyped_message
		messages_by_offset[int(message.source_offset)] = message
	for item in prepared:
		var source_offset := int(item.source_offset)
		if not messages_by_offset.has(source_offset):
			return _error("Patched MES message 0x%X no longer has its original instruction boundary." % source_offset)
		var message: Dictionary = messages_by_offset[source_offset]
		if require_native_projection_match and not bool(message.get("native_stream_projection_match", false)):
			return _error("Patched MES message 0x%X no longer matches the native text-consumption boundary." % source_offset)
		if message.raw_bytes != item.replacement_bytes:
			return _error("Patched MES message 0x%X did not reopen byte-identically." % source_offset)
		var decoded := _cp932.decode(message.raw_bytes)
		if not decoded.ok or str(decoded.text) != str(item.replacement_text):
			return _error("Patched MES message 0x%X did not decode back to the authored text." % source_offset)
	return {"ok": true}


func _validate_native_text_bytes(data: PackedByteArray) -> Dictionary:
	var offset := 0
	while offset < data.size():
		var value := int(data[offset])
		if value >= 0xF0 and value <= 0xF9:
			return {"ok": false, "error": "CP932 user-defined lead byte 0x%02X at byte %d is not a native AI5 double-byte lead." % [value, offset]}
		if _is_native_double_byte_lead(value):
			offset += 2
		else:
			offset += 1
	return {"ok": true}


func _is_native_double_byte_lead(value: int) -> bool:
	return (
		(value >= 0x81 and value <= 0x9F)
		or (value >= 0xE0 and value <= 0xEF)
		or (value >= 0xFA and value <= 0xFC)
	)


func _error(message: String) -> Dictionary:
	last_error = message
	return {"ok": false, "error": message}
