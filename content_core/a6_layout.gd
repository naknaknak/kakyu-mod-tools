class_name KakyuA6Layout
extends RefCounted

const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")

const RECORD_BYTES := 10
const FIELD_COUNT := 5
const TERMINATOR := 0xFFFF


func inspect(data: PackedByteArray) -> Dictionary:
	if data.size() < 2:
		return _error("A6 data is shorter than its terminal word.")
	if data.decode_u16(data.size() - 2) != TERMINATOR:
		return _error("A6 data does not end with the 0xFFFF terminal word.")
	var payload_size := data.size() - 2
	if payload_size % RECORD_BYTES != 0:
		return _error("A6 record payload is not a multiple of %d bytes." % RECORD_BYTES)

	var records: Array[Dictionary] = []
	var field_minimums := [0xFFFF, 0xFFFF, 0xFFFF, 0xFFFF, 0xFFFF]
	var field_maximums := [0, 0, 0, 0, 0]
	var seen_ids := {}
	var duplicate_id_count := 0
	var invalid_rectangle_count := 0
	var record_count := floori(float(payload_size) / float(RECORD_BYTES))
	for record_index in range(record_count):
		var offset := record_index * RECORD_BYTES
		var fields: Array[int] = []
		for field_index in range(FIELD_COUNT):
			var value := int(data.decode_u16(offset + field_index * 2))
			fields.append(value)
			field_minimums[field_index] = mini(field_minimums[field_index], value)
			field_maximums[field_index] = maxi(field_maximums[field_index], value)
		var record_id := int(fields[0])
		if record_id == TERMINATOR:
			return _error("A6 record %d uses the native 0xFFFF terminal ID before the end of the table." % record_index)
		var rectangle_valid := int(fields[1]) <= int(fields[3]) and int(fields[2]) <= int(fields[4])
		if seen_ids.has(record_id):
			duplicate_id_count += 1
		else:
			seen_ids[record_id] = true
		if not rectangle_valid:
			invalid_rectangle_count += 1
		records.append({
			"index": record_index,
			"offset": offset,
			"fields": fields,
			"id": record_id,
			"left": int(fields[1]),
			"top": int(fields[2]),
			"right": int(fields[3]),
			"bottom": int(fields[4]),
			"rectangle_valid": rectangle_valid,
		})

	var overlap_pair_count := 0
	var partially_occluded_count := 0
	var unreachable_record_count := 0
	for record_index in range(records.size()):
		var record: Dictionary = records[record_index]
		var prior_overlap_indices: Array[int] = []
		if bool(record.rectangle_valid):
			for prior_index in range(record_index):
				var prior: Dictionary = records[prior_index]
				if bool(prior.rectangle_valid) and _intersection_area(record, prior) > 0:
					prior_overlap_indices.append(prior_index)
		var total_area := _record_area(record) if bool(record.rectangle_valid) else 0
		var visible_area := _visible_area_after_prior(records, record_index) if bool(record.rectangle_valid) else 0
		var covered_area := total_area - visible_area
		var unreachable := total_area > 0 and visible_area == 0
		var partial := visible_area > 0 and covered_area > 0
		record["overlap_with_prior_indices"] = prior_overlap_indices
		record["overlap_with_prior_count"] = prior_overlap_indices.size()
		record["pixel_area"] = total_area
		record["covered_pixel_count"] = covered_area
		record["visible_pixel_count"] = visible_area
		record["fully_unreachable_by_first_match"] = unreachable
		record["partially_occluded_by_first_match"] = partial
		overlap_pair_count += prior_overlap_indices.size()
		if unreachable:
			unreachable_record_count += 1
		elif partial:
			partially_occluded_count += 1

	var field_ranges: Array[Dictionary] = []
	for field_index in range(FIELD_COUNT):
		field_ranges.append({
			"field": field_index,
			"minimum": int(field_minimums[field_index]) if not records.is_empty() else 0,
			"maximum": int(field_maximums[field_index]) if not records.is_empty() else 0,
		})
	return {
		"ok": true,
		"schema": ContentCoreVersionScript.A6_LAYOUT_SCHEMA,
		"record_bytes": RECORD_BYTES,
		"record_count": records.size(),
		"terminal_word": TERMINATOR,
		"field_names": ["id", "left", "top", "right", "bottom"],
		"coordinate_edges_inclusive": true,
		"duplicate_id_count": duplicate_id_count,
		"invalid_rectangle_count": invalid_rectangle_count,
		"overlap_pair_count": overlap_pair_count,
		"partially_occluded_count": partially_occluded_count,
		"unreachable_record_count": unreachable_record_count,
		"records": records,
		"field_ranges": field_ranges,
	}


func encode_records(records: Array) -> Dictionary:
	if records.size() > floori(float(0x7FFFFFFD) / float(RECORD_BYTES)):
		return _error("A6 record count is too large to encode safely.")
	var data := PackedByteArray()
	data.resize(records.size() * RECORD_BYTES + 2)
	for record_index in range(records.size()):
		if not records[record_index] is Dictionary:
			return _error("A6 record %d is not a dictionary." % record_index)
		var record: Dictionary = records[record_index]
		var field_names := ["id", "left", "top", "right", "bottom"]
		var fields: Array[int] = []
		for field_name in field_names:
			if not record.has(field_name):
				return _error("A6 record %d is missing field %s." % [record_index, field_name])
			var value = record[field_name]
			if not value is int and not value is float:
				return _error("A6 record %d field %s is not numeric." % [record_index, field_name])
			var integer_value := int(value)
			if float(value) != float(integer_value) or integer_value < 0 or integer_value > 0xFFFF:
				return _error("A6 record %d field %s is outside unsigned 16-bit range." % [record_index, field_name])
			fields.append(integer_value)
		if fields[0] == TERMINATOR:
			return _error("A6 record %d cannot use the native 0xFFFF terminal ID." % record_index)
		if fields[1] > fields[3] or fields[2] > fields[4]:
			return _error("A6 record %d has an inverted inclusive rectangle." % record_index)
		var offset := record_index * RECORD_BYTES
		for field_index in range(FIELD_COUNT):
			data.encode_u16(offset + field_index * 2, fields[field_index])
	data.encode_u16(data.size() - 2, TERMINATOR)
	var verified := inspect(data)
	if not verified.get("ok", false) or int(verified.get("record_count", -1)) != records.size():
		return _error("Encoded A6 table did not reopen with the expected record count.")
	return {
		"ok": true,
		"schema": ContentCoreVersionScript.A6_LAYOUT_SCHEMA,
		"data": data,
		"record_count": records.size(),
		"bytes": data.size(),
		"compatibility": "original_engine_compatible",
		"record_order_preserved": true,
		"duplicate_ids_preserved": true,
	}


func insert_record(data: PackedByteArray, insert_index: int, record: Dictionary) -> Dictionary:
	var inspected := inspect(data)
	if not inspected.ok:
		return inspected
	var records: Array = inspected.records.duplicate(true)
	if insert_index < 0 or insert_index > records.size():
		return _error("A6 insert index must be between zero and the record count.")
	records.insert(insert_index, record.duplicate(true))
	return _edited_table("insert", records, insert_index)


func duplicate_record(data: PackedByteArray, record_index: int) -> Dictionary:
	var inspected := inspect(data)
	if not inspected.ok:
		return inspected
	var records: Array = inspected.records.duplicate(true)
	if record_index < 0 or record_index >= records.size():
		return _error("A6 duplicate index is outside the record table.")
	var selected_index := record_index + 1
	records.insert(selected_index, (records[record_index] as Dictionary).duplicate(true))
	return _edited_table("duplicate", records, selected_index)


func remove_record(data: PackedByteArray, record_index: int) -> Dictionary:
	var inspected := inspect(data)
	if not inspected.ok:
		return inspected
	var records: Array = inspected.records.duplicate(true)
	if record_index < 0 or record_index >= records.size():
		return _error("A6 remove index is outside the record table.")
	records.remove_at(record_index)
	var selected_index := mini(record_index, records.size() - 1)
	return _edited_table("remove", records, selected_index)


func move_record(data: PackedByteArray, record_index: int, destination_index: int) -> Dictionary:
	var inspected := inspect(data)
	if not inspected.ok:
		return inspected
	var records: Array = inspected.records.duplicate(true)
	if record_index < 0 or record_index >= records.size():
		return _error("A6 move source index is outside the record table.")
	if destination_index < 0 or destination_index >= records.size():
		return _error("A6 move destination index is outside the record table.")
	var moved: Dictionary = records[record_index]
	records.remove_at(record_index)
	records.insert(destination_index, moved)
	return _edited_table("move", records, destination_index)


func hit_test(data: PackedByteArray, x: int, y: int) -> Dictionary:
	var inspected := inspect(data)
	if not inspected.ok:
		return inspected
	for untyped_record in inspected.records:
		var record: Dictionary = untyped_record
		if (
			x >= int(record.left)
			and x <= int(record.right)
			and y >= int(record.top)
			and y <= int(record.bottom)
		):
			return {
				"ok": true,
				"found": true,
				"record_id": int(record.id),
				"record_index": int(record.index),
				"rectangle": _rectangle(record),
			}
	return {
		"ok": true,
		"found": false,
		"record_id": TERMINATOR,
		"record_index": -1,
		"rectangle": _empty_rectangle(),
	}


func rectangle_for_id(data: PackedByteArray, record_id: int) -> Dictionary:
	var inspected := inspect(data)
	if not inspected.ok:
		return inspected
	for untyped_record in inspected.records:
		var record: Dictionary = untyped_record
		if int(record.id) == record_id:
			return {
				"ok": true,
				"found": true,
				"record_id": record_id,
				"record_index": int(record.index),
				"rectangle": _rectangle(record),
			}
	return {
		"ok": true,
		"found": false,
		"record_id": record_id,
		"record_index": -1,
		"rectangle": _empty_rectangle(),
	}


func _edited_table(operation: String, records: Array, selected_index: int) -> Dictionary:
	var encoded := encode_records(records)
	if not encoded.ok:
		return encoded
	var reopened := inspect(encoded.data)
	if not reopened.ok or int(reopened.record_count) != records.size():
		return _error("Edited A6 table did not reopen with the expected record count.")
	return {
		"ok": true,
		"schema": ContentCoreVersionScript.A6_LAYOUT_SCHEMA,
		"operation": operation,
		"data": encoded.data,
		"layout": reopened,
		"record_count": records.size(),
		"selected_index": selected_index,
		"compatibility": str(encoded.compatibility),
	}


func _record_area(record: Dictionary) -> int:
	return (int(record.right) - int(record.left) + 1) * (int(record.bottom) - int(record.top) + 1)


func _intersection_area(left_record: Dictionary, right_record: Dictionary) -> int:
	var left := maxi(int(left_record.left), int(right_record.left))
	var top := maxi(int(left_record.top), int(right_record.top))
	var right := mini(int(left_record.right), int(right_record.right))
	var bottom := mini(int(left_record.bottom), int(right_record.bottom))
	if left > right or top > bottom:
		return 0
	return (right - left + 1) * (bottom - top + 1)


func _visible_area_after_prior(records: Array[Dictionary], record_index: int) -> int:
	var target: Dictionary = records[record_index]
	var x_boundaries: Array[int] = [int(target.left), int(target.right) + 1]
	for prior_index in range(record_index):
		var prior: Dictionary = records[prior_index]
		if not bool(prior.rectangle_valid) or _intersection_area(target, prior) == 0:
			continue
		x_boundaries.append(maxi(int(target.left), int(prior.left)))
		x_boundaries.append(mini(int(target.right), int(prior.right)) + 1)
	x_boundaries.sort()
	var unique_boundaries: Array[int] = []
	for boundary in x_boundaries:
		if unique_boundaries.is_empty() or unique_boundaries[-1] != boundary:
			unique_boundaries.append(boundary)
	var target_height := int(target.bottom) - int(target.top) + 1
	var visible_area := 0
	for boundary_index in range(unique_boundaries.size() - 1):
		var x_start := unique_boundaries[boundary_index]
		var x_end := unique_boundaries[boundary_index + 1]
		if x_end <= x_start:
			continue
		var y_intervals: Array[Vector2i] = []
		for prior_index in range(record_index):
			var prior: Dictionary = records[prior_index]
			if (
				not bool(prior.rectangle_valid)
				or int(prior.left) > x_start
				or int(prior.right) + 1 < x_end
			):
				continue
			var y_start := maxi(int(target.top), int(prior.top))
			var y_end := mini(int(target.bottom), int(prior.bottom)) + 1
			if y_start < y_end:
				y_intervals.append(Vector2i(y_start, y_end))
		y_intervals.sort_custom(func(left: Vector2i, right: Vector2i) -> bool: return left.x < right.x)
		var covered_height := 0
		var merged_start := -1
		var merged_end := -1
		for interval in y_intervals:
			if merged_start < 0:
				merged_start = interval.x
				merged_end = interval.y
			elif interval.x > merged_end:
				covered_height += merged_end - merged_start
				merged_start = interval.x
				merged_end = interval.y
			else:
				merged_end = maxi(merged_end, interval.y)
		if merged_start >= 0:
			covered_height += merged_end - merged_start
		visible_area += (x_end - x_start) * (target_height - covered_height)
	return visible_area


func _rectangle(record: Dictionary) -> Dictionary:
	return {
		"left": int(record.left),
		"top": int(record.top),
		"right": int(record.right),
		"bottom": int(record.bottom),
	}


func _empty_rectangle() -> Dictionary:
	return {"left": 0, "top": 0, "right": 0, "bottom": 0}


func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message}
