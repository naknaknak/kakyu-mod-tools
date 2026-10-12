class_name KakyuMesContainer
extends RefCounted

const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")
const ContractValues := preload("res://content_core/contract_values.gd")

var last_error := ""


func parse(data: PackedByteArray, source := {}) -> Dictionary:
	last_error = ""
	if data.size() < 4:
		return _error("MES entry is smaller than the 4-byte entry count.")
	var entry_count := int(data.decode_u32(0))
	if entry_count > (data.size() - 4) / 4:
		return _error("MES address table exceeds the entry data.")
	var code_offset := 4 + entry_count * 4
	var code_size := data.size() - code_offset
	var entry_offsets: Array[int] = []
	for index in range(entry_count):
		var offset := int(data.decode_u32(4 + index * 4))
		if offset >= code_size:
			return _error("MES address %d is outside code size 0x%X." % [index, code_size])
		if index > 0 and offset <= entry_offsets[index - 1]:
			return _error("MES addresses are not strictly increasing at index %d." % index)
		entry_offsets.append(offset)

	var first_entry := entry_offsets[0] if not entry_offsets.is_empty() else code_size
	var entries: Array[Dictionary] = []
	for index in range(entry_count):
		var offset := entry_offsets[index]
		var end_offset := entry_offsets[index + 1] if index + 1 < entry_count else code_size
		entries.append({
			"id": "entry_%04d" % index,
			"index": index,
			"offset": offset,
			"file_offset": code_offset + offset,
			"end_offset": end_offset,
			"size": end_offset - offset,
		})
	var diagnostics: Array[Dictionary] = []
	if not entry_offsets.is_empty() and first_entry > 0:
		diagnostics.append({
			"level": "info",
			"code": "bootstrap_prefix",
			"message": "%d code bytes precede the first address-table entry." % first_entry,
		})
	return {
		"ok": true,
		"schema": ContentCoreVersionScript.MES_CONTAINER_SCHEMA,
		"source": source.duplicate(true),
		"header": {
			"entry_count": entry_count,
			"table_offset": 4,
			"table_size": entry_count * 4,
			"code_offset": code_offset,
			"code_size": code_size,
			"entry_offsets": entry_offsets,
			"offset_basis": "code_start",
		},
		"bootstrap": {
			"offset": 0,
			"file_offset": code_offset,
			"end_offset": first_entry,
			"size": first_entry,
		},
		"entries": entries,
		"bytecode": data.slice(code_offset),
		"bytecode_sha256": ContractValues.sha256(data.slice(code_offset)),
		"entry_sha256": ContractValues.sha256(data),
		"diagnostics": diagnostics,
	}


func _error(message: String) -> Dictionary:
	last_error = message
	return {"ok": false, "error": message}
