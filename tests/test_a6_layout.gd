extends "res://tests/test_case.gd"

const A6LayoutScript := preload("res://content_core/a6_layout.gd")


func _ready() -> void:
	var data := PackedByteArray()
	data.resize(22)
	for field_index in range(5):
		data.encode_u16(field_index * 2, field_index + 1)
		data.encode_u16(10 + field_index * 2, (field_index + 1) * 100)
	data.encode_u16(20, 0xFFFF)
	var layout := A6LayoutScript.new().inspect(data)
	_check(layout.ok and layout.schema == "kakyu_ai5_a6_input_regions/v4", "A6 input-region table exposes its versioned schema")
	_check(layout.ok and layout.record_count == 2 and layout.record_bytes == 10, "A6 record count follows five little-endian u16 fields")
	_check(layout.ok and layout.records[0].offset == 0 and layout.records[1].offset == 10, "A6 record offsets retain exact source positions")
	_check(layout.ok and layout.records[0].fields == [1, 2, 3, 4, 5], "A6 fields remain raw unsigned words")
	_check(
		layout.ok
		and layout.field_names == ["id", "left", "top", "right", "bottom"]
		and layout.coordinate_edges_inclusive
		and layout.records[0].id == 1
		and layout.records[0].left == 2
		and layout.records[0].top == 3
		and layout.records[0].right == 4
		and layout.records[0].bottom == 5,
		"A6 records expose the EXE-confirmed ID and inclusive rectangle fields"
	)
	_check(layout.ok and layout.field_ranges[2].minimum == 3 and layout.field_ranges[2].maximum == 300, "A6 named field ranges retain their raw unsigned extrema")
	_check(layout.duplicate_id_count == 0 and layout.invalid_rectangle_count == 0, "A6 inspection reports clean ID and rectangle diagnostics")
	var encoded := A6LayoutScript.new().encode_records(layout.records)
	_check(
		encoded.ok
		and encoded.schema == "kakyu_ai5_a6_input_regions/v4"
		and encoded.compatibility == "original_engine_compatible"
		and encoded.record_order_preserved
		and encoded.data == data,
		"A6 inspected records rebuild byte-identically with original-engine compatibility"
	)
	var edited_records: Array = layout.records.duplicate(true)
	edited_records[0]["right"] = 9
	var edited := A6LayoutScript.new().encode_records(edited_records)
	var edited_layout := A6LayoutScript.new().inspect(edited.get("data", PackedByteArray()))
	_check(
		edited.ok
		and edited_layout.ok
		and edited_layout.records[0].right == 9
		and edited_layout.records[1].fields == layout.records[1].fields,
		"A6 encoder changes one validated rectangle while preserving following records"
	)
	var left_top := A6LayoutScript.new().hit_test(data, 2, 3)
	var right_bottom := A6LayoutScript.new().hit_test(data, 4, 5)
	var outside := A6LayoutScript.new().hit_test(data, 5, 5)
	_check(left_top.found and left_top.record_id == 1, "A6 hit testing includes the left and top edges")
	_check(right_bottom.found and right_bottom.record_id == 1, "A6 hit testing includes the right and bottom edges")
	_check(not outside.found and outside.record_id == 0xFFFF, "A6 hit testing returns the native no-match sentinel outside every rectangle")
	var second_rectangle := A6LayoutScript.new().rectangle_for_id(data, 100)
	_check(
		second_rectangle.found
		and second_rectangle.record_index == 1
		and second_rectangle.rectangle == {"left": 200, "top": 300, "right": 400, "bottom": 500},
		"A6 ID lookup returns the first matching inclusive rectangle"
	)
	var missing_rectangle := A6LayoutScript.new().rectangle_for_id(data, 0x7FFF)
	_check(not missing_rectangle.found and missing_rectangle.rectangle == {"left": 0, "top": 0, "right": 0, "bottom": 0}, "A6 missing-ID lookup returns the native zero rectangle")
	var diagnostic_data := data.duplicate()
	diagnostic_data.encode_u16(10, 1)
	diagnostic_data.encode_u16(12, 500)
	diagnostic_data.encode_u16(16, 400)
	var diagnostic_layout := A6LayoutScript.new().inspect(diagnostic_data)
	_check(
		diagnostic_layout.ok
		and diagnostic_layout.duplicate_id_count == 1
		and diagnostic_layout.invalid_rectangle_count == 1,
		"A6 inspection reports duplicate IDs and inverted rectangles without rejecting their bytes"
	)
	var duplicate_records := [
		{"id": 7, "left": 1, "top": 2, "right": 3, "bottom": 4},
		{"id": 7, "left": 5, "top": 6, "right": 7, "bottom": 8},
	]
	var duplicate_encoded := A6LayoutScript.new().encode_records(duplicate_records)
	var duplicate_layout := A6LayoutScript.new().inspect(duplicate_encoded.get("data", PackedByteArray()))
	_check(
		duplicate_encoded.ok and duplicate_encoded.duplicate_ids_preserved and duplicate_layout.duplicate_id_count == 1,
		"A6 encoder preserves ordered duplicate IDs for native first-match behavior"
	)
	var overlap_records := [
		{"id": 10, "left": 0, "top": 0, "right": 4, "bottom": 4},
		{"id": 11, "left": 2, "top": 0, "right": 6, "bottom": 4},
		{"id": 12, "left": 1, "top": 1, "right": 3, "bottom": 3},
	]
	var overlap_encoded := A6LayoutScript.new().encode_records(overlap_records)
	var overlap_layout := A6LayoutScript.new().inspect(overlap_encoded.get("data", PackedByteArray()))
	_check(
		overlap_layout.ok
		and int(overlap_layout.overlap_pair_count) == 3
		and int(overlap_layout.partially_occluded_count) == 1
		and int(overlap_layout.unreachable_record_count) == 1
		and int(overlap_layout.records[1].pixel_area) == 25
		and int(overlap_layout.records[1].covered_pixel_count) == 15
		and int(overlap_layout.records[1].visible_pixel_count) == 10
		and overlap_layout.records[1].partially_occluded_by_first_match
		and overlap_layout.records[2].fully_unreachable_by_first_match
		and int(overlap_layout.records[2].visible_pixel_count) == 0,
		"A6 diagnostics measure partial and fully unreachable regions under native first-match order"
	)
	var inserted := A6LayoutScript.new().insert_record(
		overlap_encoded.data,
		1,
		{"id": 20, "left": 20, "top": 20, "right": 21, "bottom": 21}
	)
	_check(
		inserted.ok
		and inserted.operation == "insert"
		and inserted.selected_index == 1
		and inserted.layout.records[1].id == 20
		and inserted.layout.records[2].id == 11,
		"A6 insertion reopens at the exact requested table position"
	)
	var duplicated := A6LayoutScript.new().duplicate_record(inserted.get("data", PackedByteArray()), 1)
	_check(
		duplicated.ok
		and duplicated.operation == "duplicate"
		and duplicated.selected_index == 2
		and duplicated.layout.records[1].fields == duplicated.layout.records[2].fields,
		"A6 duplication preserves all five fields immediately after the source record"
	)
	var moved := A6LayoutScript.new().move_record(duplicated.get("data", PackedByteArray()), 2, 0)
	_check(
		moved.ok
		and moved.operation == "move"
		and moved.selected_index == 0
		and moved.layout.records[0].id == 20
		and A6LayoutScript.new().hit_test(moved.data, 20, 20).record_index == 0,
		"A6 move changes first-match table order and preserves the moved record"
	)
	var removed := A6LayoutScript.new().remove_record(moved.get("data", PackedByteArray()), 0)
	_check(
		removed.ok
		and removed.operation == "remove"
		and removed.layout.record_count == overlap_records.size() + 1
		and removed.layout.records[0].id == 10,
		"A6 removal reopens the remaining records in their exact order"
	)
	_check(
		not A6LayoutScript.new().insert_record(data, 3, overlap_records[0]).ok
		and not A6LayoutScript.new().duplicate_record(data, 2).ok
		and not A6LayoutScript.new().remove_record(data, -1).ok
		and not A6LayoutScript.new().move_record(data, 0, 2).ok,
		"A6 table edit operations reject every out-of-range index"
	)
	_check(
		not A6LayoutScript.new().encode_records([{"id": 0xFFFF, "left": 0, "top": 0, "right": 1, "bottom": 1}]).ok,
		"A6 encoder rejects a premature native terminal ID"
	)
	_check(
		not A6LayoutScript.new().encode_records([{"id": 1, "left": 2, "top": 0, "right": 1, "bottom": 1}]).ok,
		"A6 encoder rejects an inverted authored rectangle"
	)
	_check(
		not A6LayoutScript.new().encode_records([{"id": 1, "left": 0, "top": 0, "right": 70000, "bottom": 1}]).ok,
		"A6 encoder rejects fields outside unsigned 16-bit range"
	)

	var empty := PackedByteArray()
	empty.resize(2)
	empty.encode_u16(0, 0xFFFF)
	var empty_layout := A6LayoutScript.new().inspect(empty)
	_check(empty_layout.ok and empty_layout.record_count == 0, "terminal-only A6 data is structurally valid")
	var first_insert := A6LayoutScript.new().insert_record(empty, 0, {"id": 1, "left": 0, "top": 0, "right": 0, "bottom": 0})
	var final_remove := A6LayoutScript.new().remove_record(first_insert.get("data", PackedByteArray()), 0)
	_check(
		first_insert.ok
		and first_insert.layout.record_count == 1
		and final_remove.ok
		and final_remove.selected_index == -1
		and final_remove.data == empty,
		"A6 edit operations support an empty terminal-only table without inventing records"
	)
	_check(not A6LayoutScript.new().inspect(PackedByteArray([0xFF])).ok, "truncated A6 terminal is rejected")
	_check(not A6LayoutScript.new().inspect(PackedByteArray([1, 2, 0xFF, 0xFF])).ok, "partial A6 record is rejected")
	_check(not A6LayoutScript.new().inspect(PackedByteArray([0, 0, 0, 0])).ok, "missing A6 terminal is rejected")
	var premature_terminal := PackedByteArray()
	premature_terminal.resize(12)
	premature_terminal.encode_u16(0, 0xFFFF)
	premature_terminal.encode_u16(10, 0xFFFF)
	_check(not A6LayoutScript.new().inspect(premature_terminal).ok, "A6 reader rejects a terminal ID before the physical table end")
	await get_tree().process_frame
	get_tree().quit(1 if _failed else 0)
