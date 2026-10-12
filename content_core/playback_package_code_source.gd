class_name KakyuPlaybackPackageCodeSource
extends KakyuMesCodeSource

# A code source backed by one playback-package entry document instead of
# bytecode. It answers the same questions the byte source answers, from
# records, so the existing MES runners execute a package with no archive
# access at all.
#
# Two rules make that honest. A target offset with no record of its own
# resolves forward to the next record, which is the resolution rule fixed in
# docs/spec/tech/playback_package_schema.md. Anything the records cannot
# answer - a hex range, an unauthorized byte-range hash, a byte the export did
# not resolve - is refused rather than guessed.
#
# CP932 re-encoding exists only for the runner's message API, which still
# speaks the original encoding. The package itself stores UTF-8, and the
# exporter proves the round trip is lossless before writing a string.

const Cp932CodecScript := preload("res://content_core/cp932_codec.gd")

var last_error := ""

var _entry := ""
var _code_size := 0
var _records: Array[Dictionary] = []
var _offsets: Array[int] = []
var _opaque_ends: Array[int] = []
var _provenance_ends := {}
var _index_by_offset: Dictionary = {}
var _strings: Array = []
var _range_hashes: Dictionary = {}
var _address_table: Array[int] = []
var _routines: Dictionary = {}
var _cp932: KakyuCp932Codec


## `codec` is the CP932 codec this source re-encodes message text with. The
## package passes one codec to all of its sources (TD-64): a codec builds a
## 0.88 MB encode map on its first `encode()`, so one per entry cost about
## 0.76 GB over the 869 entries of a full package. A source built without one
## gets a codec of its own, which builds nothing until it encodes.
func _init(document: Dictionary, strings: Array, codec: KakyuCp932Codec = null) -> void:
	_cp932 = codec if codec != null else Cp932CodecScript.new()
	_entry = str(document.get("entry", ""))
	_code_size = int(document.get("code_size", 0))
	_strings = strings
	for untyped_offset in document.get("address_table", []):
		_address_table.append(int(untyped_offset))
	if str(document.get("kind", "")) == "library":
		for untyped_routine in document.get("routines", []):
			var routine: Dictionary = untyped_routine
			_routines[int(routine.routine_id)] = {
				"routine_id": int(routine.routine_id),
				"body_offset": int(routine.at),
				"end_offset": int(routine.end),
				"size": int(routine.end) - int(routine.at),
			}
			for untyped_record in routine.get("records", []):
				_records.append(untyped_record)
			_index_provenance(routine)
	else:
		for untyped_record in document.get("records", []):
			_records.append(untyped_record)
		_index_provenance(document)
	_records.sort_custom(func(a, b): return int(a.at) < int(b.at))
	var opaque_end := 0
	for index in range(_records.size()):
		var record: Dictionary = _records[index]
		_offsets.append(int(record.at))
		if str(record.op) == "opaque_region":
			opaque_end = maxi(opaque_end, int(record.end))
		_opaque_ends.append(opaque_end)
		_index_by_offset[int(record.at)] = index
		if record.has("body_sha256"):
			var target := _definition_target(record)
			if target > int(record.end):
				_range_hashes["%d:%d" % [int(record.end), target]] = str(record.body_sha256)
	if _code_size > 0 and document.has("code_sha256"):
		_range_hashes["0:%d" % _code_size] = str(document.code_sha256)


func entry() -> String:
	return _entry


func address_table() -> Array[int]:
	return _address_table.duplicate()


func routines() -> Dictionary:
	return _routines.duplicate(true)


func record_count() -> int:
	return _records.size()


func size() -> int:
	return _code_size


func decode_at(offset: int, limit := -1) -> Dictionary:
	return _decode(offset, limit)


func decode_at_structural(offset: int, limit := -1) -> Dictionary:
	return _decode(offset, limit)


func is_dialogue_boundary_pattern(offset: int, limit: int) -> bool:
	if offset < 0 or offset + 4 > limit:
		return false
	var index := int(_index_by_offset.get(offset, -1))
	if index < 0:
		return false
	return bool(_records[index].get("dialogue_boundary_pattern", false))


func dialogue_boundary_end(offset: int, limit: int) -> int:
	# The export resolved the wait call's pattern onto its record; its end is
	# where the boundary resumes.
	var index := int(_index_by_offset.get(offset, -1))
	if index < 0:
		return -1
	var record: Dictionary = _records[index]
	if not bool(record.get("dialogue_boundary_pattern", false)):
		return -1
	var end := int(record.get("end", -1))
	return end if end > offset and end <= limit else -1


func byte_at(offset: int, limit: int) -> int:
	# The only byte the runners read directly is the one after a separator, and
	# the export resolved it onto that separator's record.
	if offset <= 0 or offset >= limit:
		return -1
	var index := int(_index_by_offset.get(offset - 1, -1))
	if index < 0:
		return -1
	return int(_records[index].get("payload_lead", -1))


func hex_range(_start: int, _end: int) -> String:
	# A package carries records, not bytes, so no range can be rendered as hex.
	return RANGE_UNAVAILABLE


func sha256_range(start: int, end: int) -> String:
	# Only the ranges the package recorded can be answered. Any other range is
	# refused rather than reported as an empty fingerprint.
	return str(_range_hashes.get("%d:%d" % [start, end], RANGE_UNAVAILABLE))


func _decode(offset: int, limit: int) -> Dictionary:
	var end_limit := _code_size if limit < 0 else mini(limit, _code_size)
	if offset < 0 or offset >= end_limit:
		return _error("Offset 0x%X is outside the packaged range of %s." % [offset, _entry])
	var index := _first_at_or_after(offset)
	if index < 0 or int(_records[index].at) >= end_limit:
		return _error(
			"No packaged record at or after 0x%X in %s within 0x%X."
			% [offset, _entry, end_limit]
		)
	var record: Dictionary = _records[index]
	if index > 0 and _opaque_ends[index - 1] > offset:
		# The prefix maximum also detects a broad opaque interval that overlaps
		# several later records. An exact decoded record (from either the linear
		# sweep or transfer closure) owns its start; a forward search does not.
		if int(record.at) != offset and not _provenance_reaches(offset, int(record.at)):
			return _error("Offset 0x%X enters the interior of an opaque packaged region in %s." % [offset, _entry])
	if str(record.op) == "opaque_region":
		return _error(
			"Packaged record boundary at 0x%X in %s is an undecoded region of %d bytes."
			% [int(record.at), _entry, int(record.get("bytes", 0))]
		)
	if int(record.end) > end_limit:
		return _error("Packaged record at 0x%X crosses the requested end 0x%X in %s." % [int(record.at), end_limit, _entry])
	return _instruction(record)


func _index_provenance(group: Dictionary) -> void:
	for span in group.get("provenance_records", []):
		_provenance_ends[int(span.at)] = int(span.end)


func _provenance_reaches(offset: int, target: int) -> bool:
	var cursor := offset
	while cursor < target:
		var end := int(_provenance_ends.get(cursor, -1))
		if end <= cursor or end > target:
			return false
		cursor = end
	return cursor == target


func _first_at_or_after(offset: int) -> int:
	var low := 0
	var high := _offsets.size()
	while low < high:
		var middle := (low + high) / 2
		if _offsets[middle] < offset:
			low = middle + 1
		else:
			high = middle
	return low if low < _offsets.size() else -1


func _instruction(record: Dictionary) -> Dictionary:
	var instruction := {
		"ok": true,
		"schema": ContentCoreVersion.MES_INSTRUCTION_SCHEMA,
		"op": str(record.op),
		"command_id": int(record.id),
		"source_offset": int(record.at),
		"end_offset": int(record.end),
		"byte_length": int(record.end) - int(record.at),
		"raw_hex": "",
	}
	if record.has("script_target"):
		instruction["script_target"] = str(record.script_target)
	if record.has("family"):
		instruction["native_handler_family"] = str(record.family)
	if record.has("stream"):
		instruction["native_stream_consumption"] = str(record.stream)
	if record.has("record_consumption"):
		instruction["native_record_consumption"] = str(record.record_consumption)
	if record.has("record_count"):
		instruction["native_record_count"] = int(record.record_count)
	if record.has("record_terminator"):
		instruction["native_record_terminator_consumed"] = bool(record.record_terminator)
	if record.has("structural_only"):
		instruction["structural_only"] = bool(record.structural_only)
	if record.has("system_function"):
		instruction["system_function"] = int(record.system_function)
	if record.has("skip_to"):
		instruction["native_stream_probe"] = {
			"consumed_byte_count": int(record.get("skip_bytes", 0)),
			"probe_end_offset": int(record.skip_to),
		}
	var operands: Array[Dictionary] = []
	for untyped_operand in record.get("operands", []):
		operands.append(_whole_numbers(_expand_operand(untyped_operand, int(record.at))))
	instruction["operands"] = operands
	return instruction


# JSON numbers parse as floats. Every number in this schema is an integer
# offset, index, selector or literal, so they are restored as integers and the
# expanded instruction matches a decoded one field for field.
func _whole_numbers(value):
	if value is float and value == floor(value) and absf(value) < 9007199254740992.0:
		return int(value)
	if value is Dictionary:
		var out := {}
		for key in value.keys():
			out[key] = _whole_numbers(value[key])
		return out
	if value is Array:
		var items := []
		for item in value:
			items.append(_whole_numbers(item))
		return items
	return value


func _expand_operand(operand: Dictionary, source_offset: int) -> Dictionary:
	var type_name := str(operand.get("t", ""))
	match type_name:
		"expression", "condition", "expression_index":
			return {"type": type_name, "value": _expression(operand.get("ast", {}))}
		"code_offset", "u8", "u8_index", "u16_index", "u8_bank", "entry_index", "source_line":
			return {"type": type_name, "value": int(operand.v)}
		"u8_array":
			return {"type": type_name, "value": operand.v}
		"text":
			return _text_operand(operand, source_offset)
		"expression_byte_pair":
			return {
				"type": type_name,
				"expression": _expression(operand.get("ast", {})),
				"continuation": int(operand.get("continuation", 0)),
			}
		"expression_byte_pairs":
			var pairs: Array[Dictionary] = []
			for untyped_pair in operand.get("pairs", []):
				var pair: Dictionary = untyped_pair
				pairs.append({
					"type": "expression_byte_pair",
					"expression": _expression(pair.get("ast", {})),
					"continuation": int(pair.get("continuation", 0)),
				})
			return {"type": type_name, "pairs": pairs}
		"record_list":
			var records: Array[Dictionary] = []
			for untyped_sub in operand.get("records", []):
				records.append(_expand_record(untyped_sub, source_offset))
			return {"type": type_name, "records": records}
		_:
			var typed := {"type": type_name}
			for key in operand.keys():
				var name := str(key)
				if name == "t":
					continue
				if name == "expressions":
					var items: Array[Dictionary] = []
					for untyped_expression in operand[key]:
						items.append(_expression(untyped_expression))
					typed[name] = items
					continue
				if name in ["expression", "channel_expression", "index_expression", "value_expression"]:
					typed[name] = _expression(operand[key])
					continue
				if name == "records":
					var sub_records: Array[Dictionary] = []
					for untyped_sub in operand[key]:
						sub_records.append(_expand_record(untyped_sub, source_offset))
					typed[name] = sub_records
					continue
				typed[name] = operand[key]
			return typed


func _expand_record(source: Dictionary, source_offset: int) -> Dictionary:
	var kind := str(source.get("kind", ""))
	var record := {"tag": int(source.get("tag", 0)), "type": kind, "source_offset": source_offset}
	match kind:
		"expression_record":
			record["value"] = _expression(source.get("ast", {}))
		"string_record":
			record["value"] = _text_operand(source, source_offset)
	return record


func _expression(ast) -> Dictionary:
	return {"ok": true, "ast": ast if ast is Dictionary else {}}


func _text_operand(operand: Dictionary, source_offset: int) -> Dictionary:
	var raw_bytes := PackedByteArray()
	if operand.has("source_hex"):
		raw_bytes = _hex_bytes(str(operand.source_hex))
	elif operand.has("s"):
		var index := int(operand.s)
		if index >= 0 and index < _strings.size():
			var encoded := _cp932.encode(str(_strings[index]))
			if bool(encoded.get("ok", false)):
				raw_bytes = PackedByteArray(encoded.data)
	elif operand.has("hex"):
		raw_bytes = _hex_bytes(str(operand.hex))
	return {
		"type": "cp932_bytes",
		"raw_bytes": raw_bytes,
		"raw_hex": raw_bytes.hex_encode(),
		"source_offset": source_offset,
	}


func _hex_bytes(hex: String) -> PackedByteArray:
	var bytes := PackedByteArray()
	var cursor := 0
	while cursor + 1 < hex.length():
		bytes.append(("0x" + hex.substr(cursor, 2)).hex_to_int())
		cursor += 2
	return bytes


func _definition_target(record: Dictionary) -> int:
	var operands: Array = record.get("operands", [])
	if operands.size() != 2 or str(operands[1].get("t", "")) != "u8_array":
		return -1
	var target_bytes: Array = operands[1].v
	if target_bytes.size() != 4:
		return -1
	return (
		int(target_bytes[0])
		| (int(target_bytes[1]) << 8)
		| (int(target_bytes[2]) << 16)
		| (int(target_bytes[3]) << 24)
	)


func _error(message: String) -> Dictionary:
	last_error = message
	return {"ok": false, "error": message}
