extends "res://tests/test_case.gd"

const AxDwordStreamScript := preload("res://content_core/ax_dword_stream.gd")
const AxBindingTableScript := preload("res://content_core/ax_binding_table.gd")
const AxAnimationScript := preload("res://content_core/ax_animation.gd")
const AxToolSchedulerScript := preload("res://content_core/ax_tool_scheduler.gd")
const AxPlaybackPlanScript := preload("res://content_core/ax_playback_plan.gd")
const AxSurfaceBindingScript := preload("res://content_core/ax_surface_binding.gd")


func _ready() -> void:
	var data := PackedByteArray()
	data.resize(17)
	data.encode_u32(0, 0x00000554)
	data.encode_u32(4, 0x00FF0652)
	data.encode_u32(8, 0x03000000)
	for offset in range(12, data.size()):
		data[offset] = 0xFF
	var stream := AxDwordStreamScript.new().inspect(data)
	_check(stream.ok and stream.schema == "kakyu_ai5_ax_dword_stream/v1", "AX dword stream exposes its versioned schema")
	_check(stream.ok and stream.token_count == 3 and stream.token_bytes == 4, "AX tokens stop at the first aligned all-FF dword")
	_check(stream.ok and stream.terminator_offset == 12 and stream.padding_bytes == 5, "AX terminal and padding byte counts remain exact")
	_check(stream.ok and stream.tokens[1].value == 0x00FF0652, "AX token values may contain individual FF bytes")
	_check(stream.ok and stream.tokens[2].offset == 8, "AX token source offsets are retained")

	_check(not AxDwordStreamScript.new().inspect(PackedByteArray([0xFF, 0xFF, 0xFF])).ok, "truncated AX terminator is rejected")
	_check(not AxDwordStreamScript.new().inspect(PackedByteArray([1, 0, 0, 0])).ok, "AX stream without a terminator is rejected")
	_check(not AxDwordStreamScript.new().inspect(PackedByteArray([0xFF, 0xFF, 0xFF, 0xFF, 0])).ok, "non-FF AX suffix bytes are rejected")

	var table_data := _binding_fixture()
	var table := AxBindingTableScript.new().inspect(table_data)
	_check(table.ok and table.schema == "kakyu_ai5_ax_binding_table/v1", "AX binding table exposes its versioned schema")
	_check(table.ok and table.row_count == 10 and table.column_count == 32 and table.entry_count == 320, "AX binding table retains the native 10 x 32 shape")
	_check(table.ok and table.table_bytes == 0x500 and table.entries[4].table_offset == 0x10, "AX binding table consumes exactly 0x500 bytes")
	_check(table.ok and table.entries[4].row == 0 and table.entries[4].column == 4 and table.entries[4].target_offset == 0x504, "AX binding cells retain row, column, and entry-relative target")
	_check(table.ok and table.non_ff_entry_count == 2 and table.non_ff_entries[1].target_first_byte == 0x09, "AX binding inspector labels non-FF target bytes without decoding their grammar")
	_check(table.ok and table.strictly_increasing and table.all_targets_unique, "AX binding inspector reports monotonic unique targets")
	var inside_table := table_data.duplicate()
	inside_table.encode_u32(0, 0x4FF)
	_check(not AxBindingTableScript.new().inspect(inside_table).ok, "AX binding target inside its offset table is rejected")
	var beyond_entry := table_data.duplicate()
	beyond_entry.encode_u32(0, beyond_entry.size())
	_check(not AxBindingTableScript.new().inspect(beyond_entry).ok, "AX binding target beyond the entry is rejected")
	_check(not AxBindingTableScript.new().inspect(PackedByteArray()).ok, "truncated AX binding table is rejected")

	var animation_data := _animation_fixture()
	var animation := AxAnimationScript.new().inspect(animation_data)
	_check(animation.ok and animation.schema == "kakyu_ai5_ax_animation/v3", "AX animation stream exposes its versioned schema")
	_check(animation.ok and animation.shared_record_count == 2 and animation.shared_record_bytes == 0x1C, "AX animation retains the native shared-record table")
	_check(animation.ok and animation.shared_records[1].dispatch_type == 1 and animation.shared_records[1].destination_x == 100, "AX shared records expose bounded source and destination rectangle fields")
	_check(animation.ok and animation.all_destination_rects_within_640x400, "AX shared-record destination rectangles are checked against the logical frame")
	_check(animation.ok and animation.source_surface_index == 8 and animation.source_surface_width == 2688 and animation.source_surface_height == 864, "AX source surface index and dimensions match the bounded native renderer")
	_check(animation.ok and animation.all_source_rects_within_surface_8_2688x864, "AX shared-record source rectangles are checked against native surface 8")
	_check(animation.ok and animation.destination_surface_index == 0 and animation.destination_surface_width == 640 and animation.destination_surface_height == 400, "AX destination surface 0 retains the logical game-frame dimensions")
	_check(animation.ok and animation.stream_count == 320 and animation.command_count == 325, "AX animation retains all 10 x 32 cell streams and control commands")
	_check(animation.ok and animation.shared_record_dispatch_count == 2 and animation.streams[0].commands[1].shared_record_index == 1, "AX stream dispatch indices resolve within the shared table")
	_check(animation.ok and animation.opcode_counts[0xFF] == 320 and animation.transparent_rgb == 0x00FF00, "AX stream terminals and native green transparency key are explicit")
	var timeline := AxAnimationScript.new().compile_tool_timeline(animation, 0, 0)
	_check(timeline.ok and timeline.dispatch_events.size() == 1 and timeline.dispatch_events[0].shared_record_index == 1, "bounded AX tool timeline retains shared-record dispatch order")
	_check(timeline.ok and timeline.tool_ticks_per_cycle == 3 and timeline.timing_basis.contains("native_host_cadence_unconfirmed"), "bounded AX tool timeline exposes its explicit non-native clock basis")
	var loop_timeline := AxAnimationScript.new().compile_tool_timeline(animation, 0, 1)
	_check(loop_timeline.ok and loop_timeline.dispatch_events.size() == 2, "bounded AX tool timeline expands the confirmed control-0x05/0x06 loop pair")
	var playback_plan := AxPlaybackPlanScript.new().compile(animation, 0, 0, Vector2i(72, 30))
	_check(
		playback_plan.ok
		and playback_plan.schema == "kakyu_ax_playback_plan/v2"
		and playback_plan.frames.size() == 1
		and playback_plan.frames[0].shared_record_index == 1
		and playback_plan.frames[0].playback_frame_index == 0
		and playback_plan.frames[0].drawable
		and playback_plan.timeline.dispatch_events[0].shared_record_index == 0
		and playback_plan.timeline.dispatch_events[0].source_shared_record_index == 1,
		"shared AX playback plan remaps referenced source records to stable local frames"
	)
	var surface_trace := {
		"effect": "mmo_resource_marker",
		"resource_name": "AN.MMO",
		"source_offset": 0x20,
		"outer_command_source_offset": 0x1F,
		"native_playback_semantics": "named_mmo_load_into_active_surface_confirmed",
		"native_active_surface_state_offset": 0x20BA,
		"native_active_surface_storage": "banked_u16",
		"native_active_surface_bank": 0,
		"native_active_surface_storage_index": 1,
		"native_active_surface_value": 8,
	}
	var source_binding := AxSurfaceBindingScript.new().from_mmo_trace(surface_trace, Vector2i(72, 30))
	var bound_plan := AxPlaybackPlanScript.new().compile(
		animation, 0, 0, Vector2i(72, 30), true, source_binding
	)
	_check(
		source_binding.ok
		and source_binding.schema == "kakyu_ax_surface_binding/v1"
		and source_binding.native_surface_index == 8
		and source_binding.state_storage == "banked_u16"
		and source_binding.state_index == 1
		and bound_plan.ok
		and bound_plan.source_contract == "confirmed_mes_mmo_load_into_native_surface_8"
		and bound_plan.source_binding.resource_name == "AN.MMO",
		"AX playback plan accepts a trace-bound MES MMO producer for native surface 8"
	)
	var wrong_surface_trace := surface_trace.duplicate(true)
	wrong_surface_trace.native_active_surface_value = 7
	_check(
		not AxSurfaceBindingScript.new().from_mmo_trace(wrong_surface_trace, Vector2i(72, 30)).ok,
		"AX source binding rejects an MMO load targeting a different active surface"
	)
	var unlocated_surface_trace := surface_trace.duplicate(true)
	unlocated_surface_trace.erase("outer_command_source_offset")
	_check(
		not AxSurfaceBindingScript.new().from_mmo_trace(unlocated_surface_trace, Vector2i(72, 30)).ok,
		"AX source binding rejects a producer trace without an exact MES envelope coordinate"
	)
	_check(
		playback_plan.frames[0].destination_x == 100
		and playback_plan.frames[0].destination_y == 120
		and playback_plan.source_contract.contains("surface_8_owner_unresolved")
		and playback_plan.timing_basis.contains("native_host_cadence_unconfirmed"),
		"AX playback plan retains explicit source/destination rectangles without claiming native ownership or cadence"
	)
	_check(
		not AxPlaybackPlanScript.new().compile(animation, 0, 0, Vector2i(71, 30)).ok,
		"AX playback plan rejects a referenced rectangle outside the caller-supplied source"
	)
	var noop_animation := animation.duplicate(true)
	noop_animation.shared_records[1]["dispatch_type"] = 7
	noop_animation.shared_records[1]["native_consumer"] = "consumer_noop"
	var noop_plan := AxPlaybackPlanScript.new().compile(noop_animation, 0, 0, Vector2i(1, 1))
	_check(
		noop_plan.ok and noop_plan.drawable_frame_count == 0 and noop_plan.noop_frame_count == 1,
		"AX playback plan preserves an explicitly bounded no-op dispatch without requiring source pixels"
	)
	_check(
		not AxPlaybackPlanScript.new().compile(noop_animation, 0, 0, Vector2i(1, 1), false).ok,
		"AX playback plan can fail closed when a consumer requires drawable-only records"
	)
	var detached_plan := AxPlaybackPlanScript.new().compile(animation, 0, 0, Vector2i(72, 30))
	playback_plan.frames[0]["destination_x"] = 999
	_check(detached_plan.frames[0].destination_x == 100, "AX playback plan results cannot mutate a separately compiled plan")
	var looping_timeline := loop_timeline.duplicate(true)
	looping_timeline.reset_at_end = true
	var scheduler := AxToolSchedulerScript.new()
	var scheduled := scheduler.configure(looping_timeline, 0.05)
	_check(
		scheduled.ok
		and scheduled.schema == "kakyu_ax_tool_scheduler/v1"
		and scheduled.snapshot.timing_basis.contains("native_host_cadence_unconfirmed")
		and scheduled.initial_dispatch.is_empty()
		and scheduled.snapshot.current_shared_record_index == -1,
		"shared AX tool scheduler does not invent a tick-zero dispatch before the timeline's first event"
	)
	var below_tick := scheduler.advance_seconds(0.049)
	_check(below_tick.ok and below_tick.advanced_ticks == 0 and below_tick.events.is_empty(), "AX tool scheduler retains sub-tick elapsed time without dispatch")
	var first_tick := scheduler.advance_seconds(0.001)
	_check(
		first_tick.ok
		and first_tick.advanced_ticks == 1
		and first_tick.events.size() == 1
		and first_tick.events[0].shared_record_index == 0
		and first_tick.snapshot.current_tick == 1,
		"AX tool scheduler dispatches the exact first event at its configured tool-clock boundary"
	)
	var cycle_advance := scheduler.advance_ticks(int(loop_timeline.tool_ticks_per_cycle) - 1)
	_check(
		cycle_advance.ok
		and cycle_advance.snapshot.current_tick == 0
		and cycle_advance.snapshot.completed_cycles == 1
		and not cycle_advance.events.is_empty()
		and cycle_advance.events[-1].shared_record_index == 0,
		"AX tool scheduler preserves dispatch order across an exact cycle wrap"
	)
	var limited := scheduler.advance_seconds(0.5, 2)
	_check(
		limited.ok
		and limited.due_ticks == 10
		and limited.advanced_ticks == 2
		and limited.catch_up_limited
		and limited.pending_ticks == 8,
		"AX tool scheduler bounds catch-up without discarding pending elapsed ticks"
	)
	var detached_snapshot: Dictionary = scheduler.snapshot()
	detached_snapshot.current_tick = 999
	_check(scheduler.snapshot().current_tick != 999, "AX tool scheduler snapshots cannot mutate live scheduling state")
	var invalid_timeline := loop_timeline.duplicate(true)
	invalid_timeline.dispatch_events.append(invalid_timeline.dispatch_events[0].duplicate(true))
	_check(not AxToolSchedulerScript.new().configure(invalid_timeline, 0.05).ok, "AX tool scheduler rejects duplicate or unordered dispatch ticks")
	_check(not AxToolSchedulerScript.new().configure(loop_timeline, 0.0).ok, "AX tool scheduler rejects a non-positive tool tick duration")
	var one_shot := AxToolSchedulerScript.new()
	var one_shot_start := one_shot.configure(timeline, 0.05)
	var one_shot_end := one_shot.advance_ticks(int(timeline.tool_ticks_per_cycle))
	_check(
		one_shot_start.ok
		and one_shot_end.ok
		and one_shot_end.snapshot.finished
		and not one_shot_end.snapshot.loops
		and one_shot.advance_ticks(1).advanced_ticks == 0,
		"AX tool scheduler stops a terminal timeline instead of inventing a whole-stream loop"
	)
	var previous_snapshot: Dictionary = scheduler.snapshot()
	var rejected_reconfigure := scheduler.configure(invalid_timeline, 0.05)
	_check(not rejected_reconfigure.ok and scheduler.snapshot() == previous_snapshot, "failed AX scheduler configuration preserves the prior valid clock transactionally")
	_check(not scheduler.advance_ticks(4097).ok, "AX tool scheduler rejects an unbounded direct tick advance")
	scheduler.clear()
	_check(not scheduler.snapshot().configured and not scheduler.advance_ticks(1).ok, "clearing the AX tool scheduler removes the prior timeline atomically")
	var malformed_loop := animation.duplicate(true)
	malformed_loop.streams[0]["commands"] = [{"opcode": 6, "offset": 0x500}]
	_check(not AxAnimationScript.new().compile_tool_timeline(malformed_loop, 0, 0).ok, "bounded AX tool timeline rejects a repeat without a counted-loop start")
	var unsupported_control := animation.duplicate(true)
	unsupported_control.streams[0]["commands"] = [{"opcode": 7, "operand": 1, "offset": 0x500}]
	_check(not AxAnimationScript.new().compile_tool_timeline(unsupported_control, 0, 0).ok, "bounded AX tool timeline rejects controls outside its confirmed execution subset")
	var invalid_dispatch := animation_data.duplicate()
	invalid_dispatch.encode_u32(int(animation.streams[0].commands[1].offset) + 1, 2)
	_check(not AxAnimationScript.new().inspect(invalid_dispatch).ok, "out-of-range AX shared-record dispatch is rejected")
	await get_tree().process_frame
	get_tree().quit(1 if _failed else 0)


func _binding_fixture() -> PackedByteArray:
	var data := PackedByteArray()
	data.resize(0x640)
	data.fill(0xFF)
	for index in range(320):
		data.encode_u32(index * 4, 0x500 + index)
	data[0x500] = 0x01
	data[0x504] = 0x09
	return data


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
