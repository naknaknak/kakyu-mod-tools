extends Node

const CompositorScript := preload("res://content_core/logical_surface_compositor.gd")
const RunnerScript := preload("res://content_core/mes_event_runner.gd")
const SandboxStateScript := preload("res://content_core/mes_sandbox_state.gd")
const TestHelpers := preload("res://tests/test_helpers.gd")

var _failed := false


func _ready() -> void:
	var compositor := CompositorScript.new()
	var frame := Image.create(640, 400, false, Image.FORMAT_RGB8)
	frame.fill(Color(0.1, 0.1, 0.1))
	var source := Image.create(4, 2, false, Image.FORMAT_RGB8)
	source.fill(Color(1.0, 0.0, 1.0))
	source.set_pixel(0, 0, Color(0.0, 1.0, 0.0))
	source.set_pixel(1, 0, Color(0.0, 0.0, 1.0))

	_check(compositor.register_surface(0, frame, "logical_frame").ok, "compositor registers the fixed 640x400 logical destination")
	_check(compositor.register_surface(8, source, "source").ok, "compositor registers a separate source surface")
	frame.fill(Color(1.0, 1.0, 1.0))
	_check(TestHelpers.color_close(compositor.get_surface_copy(0).get_pixel(0, 0), Color(0.1, 0.1, 0.1)), "registered surfaces are detached from caller-owned images")
	_check(not compositor.register_surface(0, Image.create(10, 10, false, Image.FORMAT_RGB8), "logical_frame").ok, "surface 0 rejects a non-logical size")

	var opaque := compositor.apply_operation({
		"mode": 0,
		"source_x": 1,
		"source_y": 0,
		"inclusive_right": 2,
		"inclusive_bottom": 1,
		"source_surface_index": 8,
		"destination_x": 10,
		"destination_y": 20,
	})
	var opaque_frame := compositor.get_surface_copy(0)
	_check(
		opaque.ok
		and opaque.source_rect == Rect2i(1, 0, 2, 2)
		and opaque.destination_rect == Rect2i(10, 20, 2, 2)
		and TestHelpers.color_close(opaque_frame.get_pixel(10, 20), Color(0.0, 0.0, 1.0))
		and TestHelpers.color_close(opaque_frame.get_pixel(11, 20), Color(1.0, 0.0, 1.0)),
		"mode 0 expands inclusive endpoints and performs an opaque rectangle copy"
	)

	var keyed := compositor.apply_operation({
		"mode": 1,
		"source_x": 0,
		"source_y": 0,
		"inclusive_right": 1,
		"inclusive_bottom": 0,
		"source_surface_index": 8,
		"destination_x": 30,
		"destination_y": 40,
		"rgb_key": Color(0.0, 1.0, 0.0),
	})
	var keyed_frame := compositor.get_surface_copy(0)
	_check(
		keyed.ok
		and TestHelpers.color_close(keyed_frame.get_pixel(30, 40), Color(0.1, 0.1, 0.1))
		and TestHelpers.color_close(keyed_frame.get_pixel(31, 40), Color(0.0, 0.0, 1.0)),
		"mode 1 skips the exact RGB key while copying other pixels"
	)
	var fractional_key := Color(26.0 / 255.0, 51.0 / 255.0, 77.0 / 255.0)
	var fractional_source := Image.create(1, 1, false, Image.FORMAT_RGB8)
	fractional_source.set_pixel(0, 0, fractional_key)
	_check(compositor.register_surface(9, fractional_source, "source").ok, "compositor accepts an RGB8 key source")
	var quantized_keyed := compositor.apply_operation({
		"mode": 1,
		"source_x": 0,
		"source_y": 0,
		"inclusive_right": 0,
		"inclusive_bottom": 0,
		"source_surface_index": 9,
		"destination_x": 32,
		"destination_y": 40,
		"rgb_key": Color(0.10196, 0.2, 0.30196),
	})
	_check(
		quantized_keyed.ok
		and TestHelpers.color_close(compositor.get_surface_copy(0).get_pixel(32, 40), Color(0.1, 0.1, 0.1)),
		"mode 1 compares the exact quantized 24-bit RGB key"
	)

	var trace_copy := _runner_surface_trace([0, 1, 0, 2, 1, 8, 70, 80])
	var traced := compositor.apply_mes_trace(trace_copy)
	_check(
		traced.ok
		and traced.source == "mes_event_trace"
		and traced.destination_surface_index == 0
		and TestHelpers.color_close(compositor.get_surface_copy(0).get_pixel(70, 80), Color(0.0, 0.0, 1.0)),
		"confirmed mode-0 runner traces adapt to the default logical destination"
	)
	var trace_key := _runner_surface_trace([1, 0, 0, 1, 0, 8, 72, 80, 0])
	var before_missing_context := compositor.get_surface_copy(0).get_pixel(72, 80)
	_check(
		not compositor.apply_mes_trace(trace_key).ok
		and TestHelpers.color_close(compositor.get_surface_copy(0).get_pixel(72, 80), before_missing_context),
		"runner RGB-key traces require explicit presentation context before mutation"
	)
	_check(
		compositor.apply_mes_trace(trace_key, {"rgb_key": Color(0.0, 1.0, 0.0)}).ok
		and TestHelpers.color_close(compositor.get_surface_copy(0).get_pixel(72, 80), before_missing_context)
		and TestHelpers.color_close(compositor.get_surface_copy(0).get_pixel(73, 80), Color(0.0, 0.0, 1.0)),
		"runner mode-1 traces use only the explicit RGB-key context"
	)
	var trace_fill := _runner_surface_trace([2, 74, 80, 75, 81])
	_check(
		compositor.apply_mes_trace(trace_fill, {"fill_color": Color(0.2, 0.4, 0.6)}).ok
		and TestHelpers.color_close(compositor.get_surface_copy(0).get_pixel(75, 81), Color(0.2, 0.4, 0.6)),
		"runner mode-2 traces use only the explicit fill context on the active surface"
	)
	var wrong_helper := trace_copy.duplicate(true)
	wrong_helper["native_pixel_helper"] = 0x004255D0
	var before_wrong_evidence := compositor.get_surface_copy(0).get_pixel(70, 80)
	_check(
		not compositor.apply_mes_trace(wrong_helper).ok
		and TestHelpers.color_close(compositor.get_surface_copy(0).get_pixel(70, 80), before_wrong_evidence),
		"mismatched trace evidence fails closed before pixel mutation"
	)

	_check(compositor.set_active_surface(0).ok, "compositor selects a registered active surface")
	var filled := compositor.apply_operation({
		"mode": 2,
		"source_x": 50,
		"source_y": 60,
		"inclusive_right": 52,
		"inclusive_bottom": 61,
		"fill_color": Color(1.0, 0.5, 0.0),
	})
	var filled_frame := compositor.get_surface_copy(0)
	_check(
		filled.ok
		and filled.destination_surface_index == 0
		and filled.destination_rect == Rect2i(50, 60, 3, 2)
		and TestHelpers.color_close(filled_frame.get_pixel(52, 61), Color(1.0, 0.5, 0.0)),
		"mode 2 fills its inclusive rectangle on the active surface"
	)

	var before_reject := compositor.get_surface_copy(0).get_pixel(639, 399)
	_check(
		not compositor.apply_operation({
			"mode": 0,
			"source_x": 0,
			"source_y": 0,
			"inclusive_right": 3,
			"inclusive_bottom": 1,
			"source_surface_index": 8,
			"destination_x": 638,
			"destination_y": 399,
		}).ok
		and TestHelpers.color_close(compositor.get_surface_copy(0).get_pixel(639, 399), before_reject),
		"out-of-bounds operations fail before mutating the destination"
	)

	var detached := compositor.get_surface_copy(0)
	detached.set_pixel(0, 0, Color.WHITE)
	var description: Dictionary = compositor.describe()
	_check(
		TestHelpers.color_close(compositor.get_surface_copy(0).get_pixel(0, 0), Color(0.1, 0.1, 0.1))
		and description.schema == "kakyu_logical_surface_compositor/v1"
		and description.logical_width == 640
		and description.logical_height == 400
		and description.surfaces.size() == 3,
		"surface snapshots are detached and expose versioned role metadata"
	)

	var checkpoint := compositor.capture_checkpoint()
	var checkpoint_sequence := int(checkpoint.operation_sequence)
	var checkpoint_pixel := compositor.get_surface_copy(0).get_pixel(50, 60)
	_check(
		checkpoint.ok
		and checkpoint.schema == "kakyu_logical_surface_checkpoint/v1"
		and (checkpoint.state_sha256 as String).length() == 64,
		"compositor captures a versioned pixel- and metadata-bound checkpoint"
	)
	_check(
		compositor.apply_operation({
			"mode": 2,
			"source_x": 50,
			"source_y": 60,
			"inclusive_right": 50,
			"inclusive_bottom": 60,
			"fill_color": Color.WHITE,
		}).operation_sequence == checkpoint_sequence + 1
		and compositor.set_active_surface(9).ok,
		"operation order and active-surface changes advance after the checkpoint"
	)
	var restored := compositor.restore_checkpoint(checkpoint)
	_check(
		restored.ok
		and restored.operation_sequence == checkpoint_sequence
		and restored.active_surface_index == 0
		and TestHelpers.color_close(compositor.get_surface_copy(0).get_pixel(50, 60), checkpoint_pixel),
		"checkpoint restore atomically recovers pixels, operation order, and active surface"
	)
	var tampered_checkpoint := checkpoint.duplicate(true)
	var tampered_pixels: PackedByteArray = tampered_checkpoint.surfaces[0].pixels
	tampered_pixels[0] = tampered_pixels[0] ^ 0xFF
	tampered_checkpoint.surfaces[0]["pixels"] = tampered_pixels
	var before_tampered_restore := compositor.get_surface_copy(0).get_pixel(0, 0)
	_check(
		not compositor.restore_checkpoint(tampered_checkpoint).ok
		and compositor.get_active_surface_index() == 0
		and TestHelpers.color_close(compositor.get_surface_copy(0).get_pixel(0, 0), before_tampered_restore),
		"tampered checkpoint pixels are rejected without changing live compositor state"
	)
	var wrong_active_checkpoint := checkpoint.duplicate(true)
	wrong_active_checkpoint["active_surface_index"] = 99
	_check(
		not compositor.restore_checkpoint(wrong_active_checkpoint).ok
		and compositor.get_active_surface_index() == 0,
		"invalid checkpoint ownership metadata fails before state replacement"
	)

	var sequence_before_layers := int(compositor.describe().operation_sequence)
	var ordered_layers := compositor.apply_operations_in_order([
		{
			"mode": 0,
			"source_x": 1,
			"source_y": 0,
			"inclusive_right": 1,
			"inclusive_bottom": 0,
			"source_surface_index": 8,
			"destination_x": 100,
			"destination_y": 100,
		},
		{
			"mode": 0,
			"source_x": 2,
			"source_y": 0,
			"inclusive_right": 2,
			"inclusive_bottom": 0,
			"source_surface_index": 8,
			"destination_x": 100,
			"destination_y": 100,
		},
	])
	_check(
		ordered_layers.ok
		and ordered_layers.applied_count == 2
		and ordered_layers.operation_sequence == sequence_before_layers + 2
		and ordered_layers.stored_order_preserved
		and TestHelpers.color_close(compositor.get_surface_copy(0).get_pixel(100, 100), Color(1.0, 0.0, 1.0)),
		"atomic composition applies overlapping layers in stored order"
	)
	var before_failed_batch := compositor.get_surface_copy(0).get_pixel(100, 100)
	var sequence_before_failed_batch := int(compositor.describe().operation_sequence)
	var failed_layers := compositor.apply_operations_in_order([
		{
			"mode": 2,
			"source_x": 100,
			"source_y": 100,
			"inclusive_right": 100,
			"inclusive_bottom": 100,
			"fill_color": Color.WHITE,
		},
		{
			"mode": 0,
			"source_x": 0,
			"source_y": 0,
			"inclusive_right": 0,
			"inclusive_bottom": 0,
			"source_surface_index": 99,
			"destination_x": 100,
			"destination_y": 100,
		},
	])
	_check(
		not failed_layers.ok
		and failed_layers.failed_operation_index == 1
		and failed_layers.rolled_back
		and compositor.describe().operation_sequence == sequence_before_failed_batch
		and TestHelpers.color_close(compositor.get_surface_copy(0).get_pixel(100, 100), before_failed_batch),
		"a failed composition step atomically restores every prior layer and sequence"
	)
	var empty_sequence := compositor.apply_operations_in_order([])
	_check(
		empty_sequence.ok
		and empty_sequence.applied_count == 0
		and empty_sequence.operation_sequence == sequence_before_failed_batch,
		"an empty ordered composition is an explicit no-op"
	)

	if _failed:
		get_tree().quit(1)
	else:
		get_tree().quit(0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: %s" % label)
	else:
		_failed = true
		push_error("FAIL: %s" % label)


func _runner_surface_trace(arguments: Array[int]) -> Dictionary:
	var code := PackedByteArray([0x0D, 0x0B, 0xFF])
	for value in arguments:
		code.append_array(PackedByteArray([0x02, value, 0xFF]))
	code.append_array(PackedByteArray([0x00, 0x00]))
	var result: Dictionary = RunnerScript.new().run(code, 0, SandboxStateScript.new(1))
	if not result.get("ok", false) or (result.get("trace", []) as Array).is_empty():
		return {}
	return (result.trace[0] as Dictionary).duplicate(true)
