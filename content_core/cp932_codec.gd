class_name KakyuCp932Codec
extends RefCounted

const TABLE_PATH := "res://content_core/tables/cp932_decode.bin"
const MAGIC := "KCP932V1"
const HEADER_SIZE := 16
const SINGLE_COUNT := 256
const LEAD_COUNT := 60
const TRAIL_COUNT := 188
const EXPECTED_SIZE := HEADER_SIZE + SINGLE_COUNT * 2 + LEAD_COUNT * TRAIL_COUNT * 2

var last_error := ""
var _table := PackedByteArray()
var _encode_map: Dictionary = {}


func decode(data: PackedByteArray) -> Dictionary:
	last_error = ""
	if not _ensure_table():
		return _error(last_error, -1)
	var output := ""
	var offset := 0
	while offset < data.size():
		var first := int(data[offset])
		if first <= 0x7F:
			output += String.chr(first)
			offset += 1
			continue
		var lead_index := _lead_index(first)
		if lead_index < 0:
			var single_codepoint := _table.decode_u16(HEADER_SIZE + first * 2)
			if single_codepoint == 0:
				return _error("Invalid CP932 single byte 0x%02X." % first, offset)
			output += String.chr(single_codepoint)
			offset += 1
			continue
		if offset + 1 >= data.size():
			return _error("Truncated CP932 lead byte 0x%02X." % first, offset)
		var second := int(data[offset + 1])
		var trail_index := _trail_index(second)
		if trail_index < 0:
			return _error("Invalid CP932 trail byte 0x%02X after 0x%02X." % [second, first], offset + 1)
		var table_offset := HEADER_SIZE + SINGLE_COUNT * 2 + (lead_index * TRAIL_COUNT + trail_index) * 2
		var codepoint := _table.decode_u16(table_offset)
		if codepoint == 0:
			return _error("Undefined CP932 byte pair 0x%02X 0x%02X." % [first, second], offset)
		output += String.chr(codepoint)
		offset += 2
	return {"ok": true, "text": output}


func encode(text: String) -> Dictionary:
	last_error = ""
	if not _ensure_encode_map():
		return _error(last_error, -1)
	var output := PackedByteArray()
	for character_index in range(text.length()):
		var codepoint := text.unicode_at(character_index)
		if not _encode_map.has(codepoint):
			return _error(
				"Unicode U+%04X at character %d is not representable in CP932." % [codepoint, character_index],
				character_index
			)
		var encoded := int(_encode_map[codepoint])
		if encoded <= 0xFF:
			output.append(encoded)
		else:
			output.append((encoded >> 8) & 0xFF)
			output.append(encoded & 0xFF)
	return {"ok": true, "data": output}


func _ensure_table() -> bool:
	if not _table.is_empty():
		return true
	var file := FileAccess.open(TABLE_PATH, FileAccess.READ)
	if file == null:
		last_error = "CP932 decode table is unavailable."
		return false
	if file.get_length() != EXPECTED_SIZE:
		file.close()
		last_error = "CP932 decode table has an unexpected size."
		return false
	var candidate := file.get_buffer(EXPECTED_SIZE)
	file.close()
	if candidate.size() != EXPECTED_SIZE or candidate.slice(0, 8).get_string_from_ascii() != MAGIC:
		last_error = "CP932 decode table header is invalid."
		return false
	if (
		candidate.decode_u16(8) != SINGLE_COUNT
		or candidate.decode_u16(10) != LEAD_COUNT
		or candidate.decode_u16(12) != TRAIL_COUNT
	):
		last_error = "CP932 decode table dimensions are invalid."
		return false
	_table = candidate
	return true


func _ensure_encode_map() -> bool:
	if not _encode_map.is_empty():
		return true
	if not _ensure_table():
		return false
	for value in range(SINGLE_COUNT):
		var codepoint := value if value <= 0x7F else _table.decode_u16(HEADER_SIZE + value * 2)
		if codepoint != 0 or value == 0:
			_register_encoding(codepoint, value)
	for lead_index in range(LEAD_COUNT):
		var lead := 0x81 + lead_index if lead_index < 31 else 0xE0 + lead_index - 31
		for trail_index in range(TRAIL_COUNT):
			var codepoint := _table.decode_u16(
				HEADER_SIZE + SINGLE_COUNT * 2 + (lead_index * TRAIL_COUNT + trail_index) * 2
			)
			if codepoint == 0:
				continue
			var trail := 0x40 + trail_index if trail_index < 63 else 0x80 + trail_index - 63
			_register_encoding(codepoint, (lead << 8) | trail)
	return true


func _register_encoding(codepoint: int, encoded: int) -> void:
	if not _encode_map.has(codepoint):
		_encode_map[codepoint] = encoded
		return
	var current := int(_encode_map[codepoint])
	var encoded_size := 1 if encoded <= 0xFF else 2
	var current_size := 1 if current <= 0xFF else 2
	if encoded_size < current_size or (encoded_size == current_size and encoded < current):
		_encode_map[codepoint] = encoded


func _lead_index(value: int) -> int:
	if value >= 0x81 and value <= 0x9F:
		return value - 0x81
	if value >= 0xE0 and value <= 0xFC:
		return 31 + value - 0xE0
	return -1


func _trail_index(value: int) -> int:
	if value >= 0x40 and value <= 0x7E:
		return value - 0x40
	if value >= 0x80 and value <= 0xFC:
		return 63 + value - 0x80
	return -1


func _error(message: String, offset: int) -> Dictionary:
	last_error = message
	return {"ok": false, "error": message, "offset": offset}
