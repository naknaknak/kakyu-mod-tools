class_name KakyuAxBindingTable
extends RefCounted

const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")

const ROW_COUNT := 10
const COLUMN_COUNT := 32
const ENTRY_COUNT := ROW_COUNT * COLUMN_COUNT
const ENTRY_BYTES := 4
const TABLE_BYTES := ENTRY_COUNT * ENTRY_BYTES


func inspect(data: PackedByteArray) -> Dictionary:
	if data.size() <= TABLE_BYTES:
		return _error("AX data does not contain a complete 0x500-byte binding table plus target data.")

	var entries: Array[Dictionary] = []
	var non_ff_entries: Array[Dictionary] = []
	var target_first_byte_counts: Dictionary = {}
	var unique_targets: Dictionary = {}
	var strictly_increasing := true
	var previous_target := -1
	var minimum_target := data.size()
	var maximum_target := -1
	for index in range(ENTRY_COUNT):
		var table_offset := index * ENTRY_BYTES
		var target_offset := int(data.decode_u32(table_offset))
		if target_offset < TABLE_BYTES:
			return _error(
				"AX binding cell (%d,%d) points inside the 0x500-byte table: 0x%X."
				% [floori(float(index) / float(COLUMN_COUNT)), index % COLUMN_COUNT, target_offset]
			)
		if target_offset >= data.size():
			return _error(
				"AX binding cell (%d,%d) target 0x%X exceeds the %d-byte entry."
				% [floori(float(index) / float(COLUMN_COUNT)), index % COLUMN_COUNT, target_offset, data.size()]
			)
		if previous_target >= 0 and target_offset <= previous_target:
			strictly_increasing = false
		previous_target = target_offset
		minimum_target = mini(minimum_target, target_offset)
		maximum_target = maxi(maximum_target, target_offset)
		unique_targets[target_offset] = true
		var target_first_byte := int(data[target_offset])
		target_first_byte_counts[target_first_byte] = int(target_first_byte_counts.get(target_first_byte, 0)) + 1
		var record := {
			"index": index,
			"row": floori(float(index) / float(COLUMN_COUNT)),
			"column": index % COLUMN_COUNT,
			"table_offset": table_offset,
			"target_offset": target_offset,
			"target_first_byte": target_first_byte,
		}
		entries.append(record)
		if target_first_byte != 0xFF:
			non_ff_entries.append(record)

	return {
		"ok": true,
		"schema": ContentCoreVersionScript.AX_BINDING_TABLE_SCHEMA,
		"row_count": ROW_COUNT,
		"column_count": COLUMN_COUNT,
		"entry_count": ENTRY_COUNT,
		"entry_bytes": ENTRY_BYTES,
		"table_bytes": TABLE_BYTES,
		"entries": entries,
		"non_ff_entries": non_ff_entries,
		"non_ff_entry_count": non_ff_entries.size(),
		"target_first_byte_counts": target_first_byte_counts,
		"minimum_target_offset": minimum_target,
		"maximum_target_offset": maximum_target,
		"strictly_increasing": strictly_increasing,
		"unique_target_count": unique_targets.size(),
		"all_targets_unique": unique_targets.size() == ENTRY_COUNT,
	}


func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message}
