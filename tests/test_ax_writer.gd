extends "res://tests/test_case.gd"

const AxAnimationScript := preload("res://content_core/ax_animation.gd")
const AxWriterScript := preload("res://content_core/ax_writer.gd")


func _ready() -> void:
	var fixture := _animation_fixture()
	var animation := AxAnimationScript.new().inspect(fixture)
	_check(animation.ok and animation.stream_count == 320 and animation.command_count == 325, "AX writer test fixture inspects cleanly")

	var writer := AxWriterScript.new()

	# No-op round trip is byte-identical.
	var serialized := writer.serialize(animation)
	_check(
		serialized.ok
		and serialized.data == fixture
		and serialized.byte_count == fixture.size()
		and serialized.shared_record_count == 2
		and serialized.stream_count == 320
		and serialized.command_count == 325,
		"AX writer no-op round trip is byte-identical"
	)

	# reopen ok.
	var reopened := writer.reopen(fixture)
	_check(
		reopened.ok and reopened.animation.stream_count == 320 and reopened.binding.all_targets_unique,
		"AX writer reopen succeeds through the dword/binding/animation readers"
	)

	var noop_audit := writer.write_audit(fixture, serialized.data, [])
	_check(
		noop_audit.ok
		and noop_audit.schema == "kakyu_ax_write_audit/v1"
		and noop_audit.noop
		and noop_audit.byte_delta == 0
		and noop_audit.changed_cells.is_empty()
		and noop_audit.source_sha256 == noop_audit.output_sha256,
		"AX write audit reports a byte-identical no-op"
	)

	# replace_stream on cell (0,1) with a longer command list.
	var cell0_start := int(animation.streams[0].start_offset)
	var cell0_end := int(animation.streams[0].end_offset)
	var grown_commands := [
		{"opcode": 5, "operand": 2},
		{"opcode": 9, "operand": 0},
		{"opcode": 6},
		{"opcode": 0},
		{"opcode": 0xFF},
	]
	var grown := writer.replace_stream(animation, 0, 1, grown_commands, false)
	_check(grown.ok, "AX writer replace_stream on cell (0,1) accepts a longer command list")
	var grown_serialized := writer.serialize(grown)
	_check(grown_serialized.ok, "AX writer re-serializes the replace_stream result")
	if grown.ok and grown_serialized.ok:
		var grown_cell1: Dictionary = {}
		for candidate in grown.streams:
			if int(candidate.row) == 0 and int(candidate.column) == 1:
				grown_cell1 = candidate
				break
		_check(
			not grown_cell1.is_empty() and int(grown_cell1.commands.size()) == int(animation.streams[1].commands.size()) + 1,
			"AX writer replace_stream grows the edited cell's command count by exactly one"
		)
		var shift_ok := true
		for index in range(320):
			var original_target := int(animation.binding_table.entries[index].target_offset)
			var grown_target := int(grown.binding_table.entries[index].target_offset)
			var expected_target := original_target + (1 if index >= 2 else 0)
			if grown_target != expected_target:
				shift_ok = false
				break
		_check(shift_ok, "AX writer replace_stream shifts only later cells' table targets by the byte growth")
		_check(
			fixture.slice(cell0_start, cell0_end) == grown_serialized.data.slice(cell0_start, cell0_end),
			"AX writer replace_stream on cell (0,1) leaves cell (0,0) bytes unchanged"
		)
		var grown_audit := writer.write_audit(fixture, grown_serialized.data, [{"row": 0, "column": 1}])
		_check(
			grown_audit.ok
			and not grown_audit.noop
			and grown_audit.byte_delta == 1
			and grown_audit.changed_cells == [{"row": 0, "column": 1}],
			"AX write audit reports the one-byte growth and the changed cell"
		)

	# replace_stream with a 0x04 terminal and trailing_stop_ff true encodes 04 FF.
	var stop_ff := writer.replace_stream(animation, 0, 0, [{"opcode": 0}, {"opcode": 4}], true)
	_check(stop_ff.ok, "AX writer replace_stream accepts a 0x04 terminal with trailing_stop_ff")
	if stop_ff.ok:
		var stop_ff_serialized := writer.serialize(stop_ff)
		var stop_ff_cell: Dictionary = {}
		for candidate in stop_ff.streams:
			if int(candidate.row) == 0 and int(candidate.column) == 0:
				stop_ff_cell = candidate
				break
		_check(
			stop_ff_serialized.ok
			and not stop_ff_cell.is_empty()
			and bool(stop_ff_cell.trailing_stop_ff)
			and int(stop_ff_cell.terminal_opcode) == 4
			and stop_ff_serialized.data.slice(int(stop_ff_cell.start_offset), int(stop_ff_cell.end_offset)) == PackedByteArray([0x00, 0x04, 0xFF]),
			"AX writer trailing_stop_ff encodes 04 FF"
		)

	# replace_shared_record with an in-bounds record reopens and the dispatching cell's rect changes.
	var new_record := {
		"dispatch_type": 1,
		"source_x": 32,
		"source_y": 0,
		"width": 40,
		"height": 30,
		"destination_x": 200,
		"destination_y": 150,
	}
	var re_recorded := writer.replace_shared_record(animation, 1, new_record)
	_check(
		re_recorded.ok
		and int(re_recorded.shared_records[1].destination_x) == 200
		and int(re_recorded.shared_records[1].destination_y) == 150
		and int(re_recorded.streams[0].commands[1].shared_record_index) == 1,
		"AX writer replace_shared_record reopens with the dispatching cell's overlay rect changed"
	)

	# Rejections: every one returns ok false and writes nothing.
	var before_snapshot: Dictionary = animation.duplicate(true)

	var out_of_range_dispatch := writer.replace_stream(animation, 0, 1, [{"opcode": 9, "operand": 5}, {"opcode": 0xFF}], false)
	_check(not out_of_range_dispatch.ok, "AX writer rejects a dispatch index out of range")

	var bad_destination := writer.replace_shared_record(animation, 0, {
		"dispatch_type": 0, "source_x": 0, "source_y": 0, "width": 40, "height": 30,
		"destination_x": 610, "destination_y": 390,
	})
	_check(not bad_destination.ok, "AX writer rejects a destination outside 640x400")

	var bad_source := writer.replace_shared_record(animation, 0, {
		"dispatch_type": 0, "source_x": 2680, "source_y": 850, "width": 40, "height": 30,
		"destination_x": 10, "destination_y": 10,
	})
	_check(not bad_source.ok, "AX writer rejects a source outside 2688x864")

	var missing_terminal := writer.replace_stream(animation, 0, 1, [{"opcode": 0}], false)
	_check(not missing_terminal.ok, "AX writer rejects a stream with no terminal")

	var terminal_not_last := writer.replace_stream(animation, 0, 1, [{"opcode": 4}, {"opcode": 0xFF}], false)
	_check(not terminal_not_last.ok, "AX writer rejects a terminal that is not the last command")

	var missing_operand := writer.replace_stream(animation, 0, 1, [{"opcode": 1}, {"opcode": 0xFF}], false)
	_check(not missing_operand.ok, "AX writer rejects an operand-bearing opcode with a missing operand")

	var absent_cell := writer.replace_stream(animation, 99, 99, [{"opcode": 0xFF}], false)
	_check(not absent_cell.ok, "AX writer rejects replace_stream on an absent cell")

	var short_document: Dictionary = animation.duplicate(true)
	var short_streams: Array = short_document.streams.duplicate(true)
	short_streams.resize(319)
	short_document["streams"] = short_streams
	var short_serialize := writer.serialize(short_document)
	_check(not short_serialize.ok, "AX writer rejects a document with 319 streams")

	_check(animation == before_snapshot, "AX writer rejections leave the source document unmodified")

	await get_tree().process_frame
	get_tree().quit(1 if _failed else 0)


func _animation_fixture() -> PackedByteArray:
	var data := PackedByteArray()
	data.resize(0x538)
	data.fill(0)
	_write_record(data, 0x500, 0, 0, 0, 32, 24, 10, 20)
	_write_record(data, 0x51C, 1, 32, 0, 40, 30, 100, 120)
	for index in range(320):
		data.encode_u32(index * 4, data.size())
		if index == 0:
			data.append_array(PackedByteArray([1, 3, 0, 0, 0, 9, 1, 0, 0, 0, 0xFF]))
		elif index == 1:
			data.append_array(PackedByteArray([5, 2, 0, 0, 0, 9, 0, 0, 0, 0, 6, 0xFF]))
		else:
			data.append(0xFF)
	return data


func _write_record(data: PackedByteArray, offset: int, dispatch_type: int, source_x: int, source_y: int, width: int, height: int, destination_x: int, destination_y: int) -> void:
	var values := [dispatch_type, source_x, source_y, width, height, destination_x, destination_y]
	for index in range(values.size()):
		data.encode_u32(offset + index * 4, int(values[index]))
