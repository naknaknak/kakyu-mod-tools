class_name KakyuAxWriter
extends RefCounted

## The AX writer: a byte-identical serializer for `KakyuAxAnimation.inspect`
## results, plus a change-scoped edit/reopen/audit path. See ME-03 in
## `todo/*.md` for the measured contract this encodes.

const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")
const AxDwordStreamScript := preload("res://content_core/ax_dword_stream.gd")
const AxBindingTableScript := preload("res://content_core/ax_binding_table.gd")
const AxAnimationScript := preload("res://content_core/ax_animation.gd")
const PayloadFingerprintScript := preload("res://content_core/mes_payload_fingerprint.gd")

const TABLE_BYTES := 0x500
const ROW_COUNT := 10
const COLUMN_COUNT := 32
const ENTRY_COUNT := ROW_COUNT * COLUMN_COUNT
const SHARED_RECORD_BYTES := 0x1C
const LOGICAL_WIDTH := 640
const LOGICAL_HEIGHT := 400
const SOURCE_SURFACE_WIDTH := 2688
const SOURCE_SURFACE_HEIGHT := 864
const NO_OPERAND_OPCODES := [0x00, 0x03, 0x04, 0x06, 0x08]
const U32_OPERAND_OPCODES := [0x01, 0x02, 0x05, 0x07]
const TERMINAL_OPCODE_04 := 0x04
const TERMINAL_OPCODE_FF := 0xFF
const SHARED_RECORD_FIELDS := [
	"dispatch_type", "source_x", "source_y", "width", "height", "destination_x", "destination_y",
]

var _payload_fingerprint := PayloadFingerprintScript.new()


## Serializes a `KakyuAxAnimation.inspect`-shaped document back into raw AX
## bytes. Fails closed on anything the grammar does not confirm.
func serialize(document: Dictionary) -> Dictionary:
	if not document.get("ok", false):
		return _error("AX serialize requires a successfully inspected animation document.")
	var shared_records_variant = document.get("shared_records")
	if not shared_records_variant is Array:
		return _error("AX serialize requires a shared_records array.")
	var shared_records: Array = shared_records_variant
	for record_index in range(shared_records.size()):
		var record_check := _validate_shared_record(shared_records[record_index])
		if not record_check.ok:
			return _error("AX shared record %d: %s" % [record_index, record_check.error])

	var streams_variant = document.get("streams")
	if not streams_variant is Array:
		return _error("AX serialize requires a streams array.")
	var streams: Array = streams_variant
	if streams.size() != ENTRY_COUNT:
		return _error(
			"AX serialize requires exactly %d cell streams, found %d." % [ENTRY_COUNT, streams.size()]
		)

	var stream_byte_lengths: Array[int] = []
	var command_count := 0
	for stream_index in range(ENTRY_COUNT):
		var stream_variant = streams[stream_index]
		if not stream_variant is Dictionary:
			return _error("AX cell stream %d is not a record." % stream_index)
		var stream: Dictionary = stream_variant
		var expected_row := floori(float(stream_index) / float(COLUMN_COUNT))
		var expected_column := stream_index % COLUMN_COUNT
		if (
			int(stream.get("index", -1)) != stream_index
			or int(stream.get("row", -1)) != expected_row
			or int(stream.get("column", -1)) != expected_column
		):
			return _error(
				"AX cell stream %d does not carry a consistent index/row/column." % stream_index
			)
		var commands_variant = stream.get("commands")
		if not commands_variant is Array or (commands_variant as Array).is_empty():
			return _error("AX cell (%d,%d) has no commands." % [expected_row, expected_column])
		var commands: Array = commands_variant
		var stream_bytes := 0
		for command_index in range(commands.size()):
			var command_variant = commands[command_index]
			if not command_variant is Dictionary:
				return _error(
					"AX cell (%d,%d) command %d is not a record." % [expected_row, expected_column, command_index]
				)
			var is_last := command_index == commands.size() - 1
			var command_check := _validate_command(command_variant, is_last, shared_records.size())
			if not command_check.ok:
				return _error(
					"AX cell (%d,%d) command %d: %s"
					% [expected_row, expected_column, command_index, command_check.error]
				)
			stream_bytes += int(command_check.byte_count)
		var trailing_stop_ff := bool(stream.get("trailing_stop_ff", false))
		var terminal_opcode := int((commands[commands.size() - 1] as Dictionary).get("opcode", -1))
		if trailing_stop_ff:
			if terminal_opcode != TERMINAL_OPCODE_04:
				return _error(
					"AX cell (%d,%d) trailing_stop_ff requires a 0x04 terminal." % [expected_row, expected_column]
				)
			stream_bytes += 1
		stream_byte_lengths.append(stream_bytes)
		command_count += commands.size()

	var shared_bytes := shared_records.size() * SHARED_RECORD_BYTES
	var data := PackedByteArray()
	data.resize(TABLE_BYTES + shared_bytes)

	var cumulative := 0
	for stream_index in range(ENTRY_COUNT):
		data.encode_u32(stream_index * 4, TABLE_BYTES + shared_bytes + cumulative)
		cumulative += stream_byte_lengths[stream_index]

	for record_index in range(shared_records.size()):
		var record: Dictionary = shared_records[record_index]
		var record_offset := TABLE_BYTES + record_index * SHARED_RECORD_BYTES
		for field_index in range(SHARED_RECORD_FIELDS.size()):
			data.encode_u32(record_offset + field_index * 4, int(record[SHARED_RECORD_FIELDS[field_index]]))

	for stream_index in range(ENTRY_COUNT):
		var stream: Dictionary = streams[stream_index]
		var commands: Array = stream.commands
		for command_variant in commands:
			var command: Dictionary = command_variant
			var opcode := int(command.opcode)
			data.append(opcode)
			if opcode in U32_OPERAND_OPCODES or (opcode >= 9 and opcode <= 254):
				var operand_offset := data.size()
				data.resize(operand_offset + 4)
				data.encode_u32(operand_offset, int(command.operand))
		if bool(stream.get("trailing_stop_ff", false)):
			data.append(TERMINAL_OPCODE_FF)

	return {
		"ok": true,
		"data": data,
		"byte_count": data.size(),
		"shared_record_count": shared_records.size(),
		"stream_count": streams.size(),
		"command_count": command_count,
		"sha256": _payload_fingerprint.sha256_bytes(data),
	}


## Builds the `kakyu_ax_write_audit/v1` audit for a source/output byte pair.
## Re-inspects `output` to fill its structural counts, so a caller cannot
## report counts the reopened bytes do not carry.
func write_audit(source: PackedByteArray, output: PackedByteArray, changed_cells: Array) -> Dictionary:
	var reopened := reopen(output)
	if not reopened.ok:
		return reopened
	var animation: Dictionary = reopened.animation
	var normalized_cells: Array[Dictionary] = []
	for cell_variant in changed_cells:
		if not cell_variant is Dictionary:
			return _error("AX write audit changed_cells entries must be records.")
		var cell: Dictionary = cell_variant
		if not cell.has("row") or not cell.has("column"):
			return _error("AX write audit changed_cells entries require row and column.")
		normalized_cells.append({"row": int(cell.row), "column": int(cell.column)})
	normalized_cells.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			if int(a.row) != int(b.row):
				return int(a.row) < int(b.row)
			return int(a.column) < int(b.column)
	)
	var result := {
		"ok": true,
		"schema": ContentCoreVersionScript.AX_WRITE_AUDIT_SCHEMA,
		"source_sha256": _payload_fingerprint.sha256_bytes(source),
		"output_sha256": _payload_fingerprint.sha256_bytes(output),
		"source_bytes": source.size(),
		"output_bytes": output.size(),
		"byte_delta": output.size() - source.size(),
		"shared_record_count": int(animation.shared_record_count),
		"stream_count": int(animation.stream_count),
		"command_count": int(animation.command_count),
		"changed_cells": normalized_cells,
		"noop": source == output,
	}
	result["payload_sha256"] = _payload_fingerprint.fingerprint(result)
	return result


## Reopens serialized AX bytes through every read-only reader the corpus
## contract requires: the dword-boundary reader, the binding table (bounded to
## strictly increasing, unique targets) and the animation grammar.
func reopen(data: PackedByteArray) -> Dictionary:
	var dwords := AxDwordStreamScript.new().inspect(data)
	if not dwords.ok:
		return _error("AX reopen dword stream: %s" % str(dwords.error))
	var binding := AxBindingTableScript.new().inspect(data)
	if not binding.ok:
		return _error("AX reopen binding table: %s" % str(binding.error))
	if not binding.strictly_increasing or not binding.all_targets_unique:
		return _error("AX reopen binding table targets must be strictly increasing and unique.")
	var animation := AxAnimationScript.new().inspect(data)
	if not animation.ok:
		return _error("AX reopen animation: %s" % str(animation.error))
	return {"ok": true, "animation": animation, "binding": binding, "dwords": dwords}


## Returns a deep-copied, re-inspected document whose cell `(row, column)`
## carries `commands` and the given terminal rule. The result always equals
## `inspect(serialize(edited))`, so offsets and command `kind`/`offset` fields
## are always recomputed, never carried over from the caller.
func replace_stream(
	document: Dictionary, row: int, column: int, commands: Array, trailing_stop_ff: bool = false
) -> Dictionary:
	if not document.get("ok", false):
		return _error("AX replace_stream requires a successfully inspected animation document.")
	var streams_variant = document.get("streams")
	if not streams_variant is Array:
		return _error("AX replace_stream requires a streams array.")
	var streams: Array = streams_variant
	var target_index := -1
	for stream_index in range(streams.size()):
		var stream: Dictionary = streams[stream_index]
		if int(stream.get("row", -1)) == row and int(stream.get("column", -1)) == column:
			target_index = stream_index
			break
	if target_index < 0:
		return _error("AX cell (%d,%d) is not present." % [row, column])
	if commands.is_empty():
		return _error("AX cell (%d,%d) replacement requires at least one command." % [row, column])

	var shared_record_count := (document.get("shared_records", []) as Array).size()
	var normalized_commands: Array[Dictionary] = []
	for command_index in range(commands.size()):
		var command_variant = commands[command_index]
		if not command_variant is Dictionary:
			return _error(
				"AX cell (%d,%d) replacement command %d is not a record." % [row, column, command_index]
			)
		var is_last := command_index == commands.size() - 1
		var check := _validate_command(command_variant, is_last, shared_record_count)
		if not check.ok:
			return _error("AX cell (%d,%d) replacement command %d: %s" % [row, column, command_index, check.error])
		var command: Dictionary = command_variant
		var opcode := int(command.opcode)
		var normalized := {"opcode": opcode}
		if opcode in U32_OPERAND_OPCODES or (opcode >= 9 and opcode <= 254):
			normalized["operand"] = int(command.operand)
			if opcode >= 9 and opcode <= 254:
				normalized["shared_record_index"] = int(command.operand)
		normalized_commands.append(normalized)
	var terminal_opcode := int(normalized_commands[normalized_commands.size() - 1].opcode)
	if trailing_stop_ff and terminal_opcode != TERMINAL_OPCODE_04:
		return _error("AX cell (%d,%d) trailing_stop_ff requires a 0x04 terminal." % [row, column])

	var edited_document: Dictionary = document.duplicate(true)
	var edited_streams: Array = edited_document.streams
	var edited_stream: Dictionary = (edited_streams[target_index] as Dictionary).duplicate(true)
	edited_stream["commands"] = normalized_commands
	edited_stream["trailing_stop_ff"] = trailing_stop_ff
	edited_streams[target_index] = edited_stream
	edited_document["streams"] = edited_streams

	var serialized := serialize(edited_document)
	if not serialized.ok:
		return serialized
	var reopened := reopen(serialized.data)
	if not reopened.ok:
		return reopened
	return reopened.animation


## Same edit/serialize/reopen pattern as `replace_stream`, for exactly one
## shared draw record.
func replace_shared_record(document: Dictionary, index: int, record: Dictionary) -> Dictionary:
	if not document.get("ok", false):
		return _error("AX replace_shared_record requires a successfully inspected animation document.")
	var shared_records_variant = document.get("shared_records")
	if not shared_records_variant is Array:
		return _error("AX replace_shared_record requires a shared_records array.")
	var shared_records: Array = shared_records_variant
	if index < 0 or index >= shared_records.size():
		return _error("AX shared record index %d exceeds count %d." % [index, shared_records.size()])
	var check := _validate_shared_record(record)
	if not check.ok:
		return check
	var normalized := {}
	for field in SHARED_RECORD_FIELDS:
		normalized[field] = int(record[field])

	var edited_document: Dictionary = document.duplicate(true)
	var edited_records: Array = edited_document.shared_records
	edited_records[index] = normalized
	edited_document["shared_records"] = edited_records

	var serialized := serialize(edited_document)
	if not serialized.ok:
		return serialized
	var reopened := reopen(serialized.data)
	if not reopened.ok:
		return reopened
	return reopened.animation


func _validate_command(command_variant: Variant, is_last: bool, shared_record_count: int) -> Dictionary:
	if not command_variant is Dictionary:
		return _error("command is not a record.")
	var command: Dictionary = command_variant
	var opcode_variant = command.get("opcode")
	if not _is_integer(opcode_variant):
		return _error("opcode is not an integer.")
	var opcode := int(opcode_variant)
	if opcode < 0 or opcode > 0xFF:
		return _error("opcode 0x%X is outside one byte." % opcode)
	var is_terminal := opcode == TERMINAL_OPCODE_04 or opcode == TERMINAL_OPCODE_FF
	if is_terminal and not is_last:
		return _error("terminal opcode 0x%02X is not the last command." % opcode)
	if is_last and not is_terminal:
		return _error("the last command is not a 0x04 or 0xFF terminal.")
	if opcode in NO_OPERAND_OPCODES or opcode == TERMINAL_OPCODE_FF:
		return {"ok": true, "byte_count": 1}
	if opcode in U32_OPERAND_OPCODES or (opcode >= 9 and opcode <= 254):
		var operand_variant = command.get("operand")
		if not _is_integer(operand_variant):
			return _error("opcode 0x%02X requires an integer operand." % opcode)
		var operand := int(operand_variant)
		if operand < 0 or operand > 0xFFFFFFFF:
			return _error("opcode 0x%02X operand 0x%X is outside u32 range." % [opcode, operand])
		if opcode >= 9 and opcode <= 254 and operand >= shared_record_count:
			return _error("shared-record index %d exceeds count %d." % [operand, shared_record_count])
		return {"ok": true, "byte_count": 5}
	return _error("opcode 0x%02X is outside the AX grammar." % opcode)


func _validate_shared_record(record_variant: Variant) -> Dictionary:
	if not record_variant is Dictionary:
		return _error("record is not a record.")
	var record: Dictionary = record_variant
	for field in SHARED_RECORD_FIELDS:
		if not _is_integer(record.get(field)):
			return _error("field '%s' is not an integer." % field)
	var width := int(record.width)
	var height := int(record.height)
	if width <= 0 or height <= 0:
		return _error("width/height must be positive.")
	var destination_x := int(record.destination_x)
	var destination_y := int(record.destination_y)
	var destination_bounded := (
		destination_x >= 0 and destination_y >= 0
		and destination_x <= LOGICAL_WIDTH and destination_y <= LOGICAL_HEIGHT
		and width <= LOGICAL_WIDTH - destination_x and height <= LOGICAL_HEIGHT - destination_y
	)
	if not destination_bounded:
		return _error("destination rectangle is outside %dx%d." % [LOGICAL_WIDTH, LOGICAL_HEIGHT])
	var source_x := int(record.source_x)
	var source_y := int(record.source_y)
	var source_bounded := (
		source_x >= 0 and source_y >= 0
		and source_x <= SOURCE_SURFACE_WIDTH and source_y <= SOURCE_SURFACE_HEIGHT
		and width <= SOURCE_SURFACE_WIDTH - source_x and height <= SOURCE_SURFACE_HEIGHT - source_y
	)
	if not source_bounded:
		return _error("source rectangle is outside %dx%d." % [SOURCE_SURFACE_WIDTH, SOURCE_SURFACE_HEIGHT])
	return {"ok": true}


func _is_integer(value: Variant) -> bool:
	return (
		value is int
		or (value is float and is_finite(value) and float(value) == floor(float(value)))
	)


func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message}
