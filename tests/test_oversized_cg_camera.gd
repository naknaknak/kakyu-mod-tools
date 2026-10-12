extends Node

const CameraScript := preload("res://content_core/oversized_cg_camera.gd")
const SOURCE_SIZE := Vector2i(988, 588)
const VIEWPORT_SIZE := Vector2i(640, 400)

var _failed := false
var _checks := 0


func _ready() -> void:
	_test_automatic_samples()
	_test_deadline_boundaries()
	_test_clock_partitioning()
	_test_manual_mode()
	_test_manual_return()
	_test_manual_return_partitioning()
	_test_transactional_rejection()
	_test_finish_and_reset()
	print("OVERSIZED_CG_CAMERA checks=%d failed=%s" % [_checks, _failed])
	get_tree().quit(1 if _failed else 0)


func _test_automatic_samples() -> void:
	var camera := CameraScript.new()
	var state := camera.start(7, SOURCE_SIZE, VIEWPORT_SIZE)
	_check(state.ok and state.active and not state.finished and state.mode == 7, "mode 7 starts only on the requested command")
	_check(state.crop == Vector2i(2, 1) and state.elapsed_ms == 0.0, "first outbound sample is drawn before its 15-ms deadline")
	_check(state.clock_semantics == "deterministic_tool_clock_projection" and state.sample_semantics == CameraScript.SAMPLE_SEMANTICS, "snapshot labels clock and rational samples as tool projections")
	var outbound_matches := true
	for index in range(1, 174):
		state = camera.snapshot()
		outbound_matches = outbound_matches and state.phase == "outbound" and state.sample_index == index
		outbound_matches = outbound_matches and state.crop == Vector2i(2 * index, floori(float(376 * index) / 348.0))
		camera.advance(0.015)
	_check(outbound_matches, "all 173 outbound samples match the audited rational geometry")
	state = camera.snapshot()
	_check(state.phase == "endpoint_hold" and state.crop == Vector2i(348, 188) and state.elapsed_ms == 2595.0, "outbound deadline sum reaches the explicit endpoint copy")
	camera.advance(1.0)
	var return_matches := true
	for index in range(173, -1, -1):
		state = camera.snapshot()
		return_matches = return_matches and state.phase == "return" and state.sample_index == index
		return_matches = return_matches and state.crop == Vector2i(2 * index, floori(float(376 * index) / 348.0))
		camera.advance(0.015)
	_check(return_matches, "all 174 return samples include index zero and its deadline")
	state = camera.snapshot()
	_check(state.finished and not state.active and state.crop == Vector2i.ZERO and state.phase == "finished", "automatic completion restores the origin")
	_check(state.elapsed_ms == 6205.0, "nominal tool-clock duration is exactly 6205 ms")


func _test_deadline_boundaries() -> void:
	var camera := CameraScript.new()
	camera.start(7, SOURCE_SIZE, VIEWPORT_SIZE)
	_check(camera.advance(0.014999).sample_index == 1, "sample is retained immediately before its deadline")
	_check(camera.advance(0.000001).sample_index == 2, "fractional deltas cross exactly one sample deadline")
	camera.start(7, SOURCE_SIZE, VIEWPORT_SIZE)
	_check(camera.advance(2.595).phase == "endpoint_hold", "large delta enters the endpoint hold at its exact boundary")
	_check(camera.advance(0.999999).phase == "endpoint_hold", "endpoint stays visible through the whole hold")
	var state := camera.advance(0.000001)
	_check(state.phase == "return" and state.sample_index == 173 and state.crop == Vector2i(346, 186), "return starts with the confirmed 173 sample after the hold")
	state = camera.advance(2.595)
	_check(state.phase == "return" and state.active and state.sample_index == 0 and state.crop == Vector2i.ZERO, "return index zero remains active during its last deadline")
	_check(camera.advance(0.014999).active, "automatic mode does not finish before the last deadline")
	_check(camera.advance(0.000001).finished, "automatic mode finishes at the last deadline")
	camera.start(7, SOURCE_SIZE, VIEWPORT_SIZE)
	state = camera.advance(1.0e100)
	_check(state.finished and state.elapsed_ms == 6205.0 and state.crop == Vector2i.ZERO, "oversized finite delta crosses all phases without overflow or overshoot")


func _test_clock_partitioning() -> void:
	var stepped := CameraScript.new()
	var direct := CameraScript.new()
	stepped.start(7, SOURCE_SIZE, VIEWPORT_SIZE)
	var frame_matches := true
	for frame in range(1, 401):
		stepped.advance(1.0 / 60.0)
		direct.start(7, SOURCE_SIZE, VIEWPORT_SIZE)
		direct.advance(float(frame) / 60.0)
		frame_matches = frame_matches and stepped.snapshot() == direct.snapshot()
	_check(frame_matches, "every 60-Hz prefix matches one equivalent large delta without clock drift")
	stepped.start(7, SOURCE_SIZE, VIEWPORT_SIZE)
	for step in range(6205):
		stepped.advance(0.001)
	direct.start(7, SOURCE_SIZE, VIEWPORT_SIZE)
	direct.advance(6.205)
	_check(stepped.snapshot() == direct.snapshot(), "6205 one-millisecond steps equal one full-duration step")
	stepped.start(7, SOURCE_SIZE, VIEWPORT_SIZE)
	for step in range(62050):
		stepped.advance(0.0001)
	_check(stepped.snapshot() == direct.snapshot(), "sub-millisecond accumulation does not lose deadline fractions")


func _test_manual_mode() -> void:
	var camera := CameraScript.new()
	var state := camera.start(8, SOURCE_SIZE, VIEWPORT_SIZE)
	_check(state.ok and state.active and state.phase == "manual" and state.crop == Vector2i.ZERO, "mode 8 starts at the origin with no automatic motion")
	state = camera.move_pixels(Vector2i(1, 1))
	_check(state.crop == Vector2i(1, 1), "manual one-pixel movement preserves logical coordinates")
	state = camera.move_pixels(Vector2i(1000, 1000))
	_check(state.crop == Vector2i(348, 188), "manual movement clamps each axis to the source extent")
	state = camera.move_pixels(Vector2i(-3, -7))
	_check(state.crop == Vector2i(345, 181), "negative crop-space deltas move back from the endpoint")
	state = camera.move_pixels(Vector2i(2147483647, 2147483647))
	_check(state.crop == Vector2i(348, 188), "extreme positive deltas clamp before Vector2i overflow")
	state = camera.move_pixels(Vector2i(-2147483648, -2147483648))
	_check(state.crop == Vector2i.ZERO, "extreme negative deltas clamp to the origin")
	camera.move_pixels(Vector2i(125, 67))
	state = camera.advance(1000.0)
	_check(state.active and not state.finished and state.crop == Vector2i(125, 67), "manual mode has no deterministic completion time")
	state = camera.finish()
	_check(state.finished and not state.active and state.crop == Vector2i.ZERO and state.elapsed_ms == 1000000.0, "manual completion restores the origin and retains elapsed tool time")
	state = camera.start(8, VIEWPORT_SIZE, VIEWPORT_SIZE)
	_check(state.ok and camera.move_pixels(Vector2i(10, -10)).crop == Vector2i.ZERO, "manual mode safely supports a source with zero crop extent")
	state = camera.start(8, Vector2i(800, 480), VIEWPORT_SIZE)
	_check(state.ok and camera.move_pixels(Vector2i(300, 300)).crop == Vector2i(160, 80), "manual clamp geometry can be reused independently of automatic native samples")


func _test_manual_return() -> void:
	var camera := CameraScript.new()
	camera.start(8, SOURCE_SIZE, VIEWPORT_SIZE)
	camera.move_pixels(Vector2i(348, 188))
	camera.advance(123.456)
	var state := camera.request_finish()
	_check(state.mode == 8 and state.active and not state.finished and state.phase == "manual_return"
		and state.sample_index == 173 and state.crop == Vector2i(346, 186)
		and state.manual_return_sample_count == 174 and state.manual_return_deadline_ms == 2610,
		"mode-8 finish request begins the source-bounded return without completing MES")
	_check(state.elapsed_ms == 123456.0 and state.manual_return_elapsed_ms == 0.0,
		"manual return has a separate clock from the unbounded inspection period")
	_check(camera.request_finish() == state, "repeated finish request cannot restart the return")
	_check(not camera.move_pixels(Vector2i.ONE).ok and camera.snapshot() == state,
		"manual input cannot change a returning mode-8 camera")
	var samples_match := true
	for index in range(173, -1, -1):
		state = camera.snapshot()
		samples_match = samples_match and state.active and state.phase == "manual_return" and state.sample_index == index
		samples_match = samples_match and state.crop == Vector2i(2 * index, floori(float(376 * index) / 348.0))
		camera.advance(0.015)
	_check(samples_match, "mode-8 endpoint return visits all 174 rational samples and deadlines")
	state = camera.snapshot()
	_check(state.finished and not state.active and state.crop == Vector2i.ZERO
		and state.elapsed_ms == 126066.0 and state.manual_return_elapsed_ms == 2610.0,
		"mode-8 return completes only after its 2610-ms nominal deadline budget")
	_check(camera.request_finish() == state, "finish request is stable after completed return")
	for crop in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(0, 1), Vector2i.ONE]:
		camera.start(8, SOURCE_SIZE, VIEWPORT_SIZE)
		camera.move_pixels(crop)
		state = camera.request_finish()
		_check(state.finished and not state.active and state.crop == Vector2i.ZERO
			and state.manual_return_sample_count == 0 and state.manual_return_deadline_ms == 0,
			"native negative initial index skips return samples for tiny crop %s" % crop)
	for crop in [Vector2i(2, 1), Vector2i(1, 2)]:
		camera.start(8, SOURCE_SIZE, VIEWPORT_SIZE)
		camera.move_pixels(crop)
		state = camera.request_finish()
		_check(state.active and state.phase == "manual_return" and state.sample_index == 0
			and state.crop == Vector2i.ZERO and state.manual_return_sample_count == 1,
			"two-pixel extent still owns the zero sample's deadline: %s" % crop)
		_check(camera.advance(0.014999).active and camera.advance(0.000001).finished,
			"one-sample manual return does not finish before 15 ms")
	for crop in [Vector2i(13, 7), Vector2i(7, 13)]:
		camera.start(8, SOURCE_SIZE, VIEWPORT_SIZE)
		camera.move_pixels(crop)
		state = camera.request_finish()
		_check(state.manual_return_sample_count == 6 and state.sample_index == 5
			and state.crop == Vector2i(floori(10.0 * crop.x / 13.0), floori(10.0 * crop.y / 13.0)),
			"odd and vertical-major extents normalize by max axis and floor half-length")
		_check(camera.advance(1.0e100).finished and camera.snapshot().manual_return_elapsed_ms == 90.0,
			"large delta clamps to the dynamic return duration")
	camera.start(8, SOURCE_SIZE, VIEWPORT_SIZE)
	camera.move_pixels(Vector2i(2, 0))
	camera.advance(CameraScript.MAX_TOOL_SECONDS - 0.001)
	var before := camera.snapshot()
	_check(not camera.request_finish().ok and camera.snapshot() == before,
		"a return exceeding the cumulative tool-clock range is rejected transactionally")
	camera.start(8, Vector2i(2147483647, 2147483647), Vector2i.ONE)
	camera.move_pixels(Vector2i(2147483647, 2147483647))
	state = camera.request_finish()
	_check(state.active and state.crop == Vector2i(2147483644, 2147483644)
		and state.manual_return_sample_count == 1073741823,
		"extreme manual-return rational products remain within scalar int64 bounds")
	state = camera.finish()
	_check(state.finished and state.crop == Vector2i.ZERO and state.manual_return_elapsed_ms == 0.0,
		"explicit cancellation can stop a return without inventing completed deadlines")


func _test_manual_return_partitioning() -> void:
	var stepped := CameraScript.new()
	var direct := CameraScript.new()
	for camera in [stepped, direct]:
		camera.start(8, SOURCE_SIZE, VIEWPORT_SIZE)
		camera.move_pixels(Vector2i(348, 188))
		camera.advance(1000.25)
		camera.request_finish()
	var matches := true
	for frame in range(1, 158):
		stepped.advance(1.0 / 60.0)
		direct.start(8, SOURCE_SIZE, VIEWPORT_SIZE)
		direct.move_pixels(Vector2i(348, 188))
		direct.advance(1000.25)
		direct.request_finish()
		direct.advance(float(frame) / 60.0)
		matches = matches and stepped.snapshot() == direct.snapshot()
	_check(matches, "manual return's every 60-Hz prefix equals a single equivalent delta")
	stepped.start(8, SOURCE_SIZE, VIEWPORT_SIZE)
	stepped.move_pixels(Vector2i(348, 188))
	stepped.request_finish()
	for index in range(26100):
		stepped.advance(0.0001)
	_check(stepped.snapshot().finished and stepped.snapshot().elapsed_ms == 2610.0,
		"manual return preserves sub-millisecond fractions through completion")
	stepped.start(8, SOURCE_SIZE, VIEWPORT_SIZE)
	stepped.move_pixels(Vector2i(348, 188))
	stepped.advance(1000000.0)
	stepped.request_finish()
	_check(stepped.advance(0.014999).sample_index == 173 and stepped.advance(0.000001).sample_index == 172,
		"long manual inspection does not erase fractional return deadlines")


func _test_transactional_rejection() -> void:
	var camera := CameraScript.new()
	camera.start(8, SOURCE_SIZE, VIEWPORT_SIZE)
	camera.move_pixels(Vector2i(123, 45))
	camera.advance(0.25)
	var before := camera.snapshot()
	for arguments in [[6, SOURCE_SIZE, VIEWPORT_SIZE], [9, SOURCE_SIZE, VIEWPORT_SIZE], [7, Vector2i(989, 588), VIEWPORT_SIZE], [7, SOURCE_SIZE, Vector2i(1920, 1080)], [8, SOURCE_SIZE, Vector2i.ZERO], [8, Vector2i(639, 400), VIEWPORT_SIZE]]:
		var rejected: Dictionary = camera.start(arguments[0], arguments[1], arguments[2])
		_check(not rejected.ok and camera.snapshot() == before, "unsupported start preserves the existing camera transactionally: %s" % str(arguments))
	for delta in [-0.001, NAN, INF, -INF, 1.0e100]:
		var rejected := camera.advance(delta)
		_check(not rejected.ok and camera.snapshot() == before, "invalid or overflowing manual clock delta is transactional: %s" % str(delta))
	camera.start(7, SOURCE_SIZE, VIEWPORT_SIZE)
	before = camera.snapshot()
	_check(not camera.request_finish().ok and camera.snapshot() == before, "interactive completion cannot interrupt automatic mode 7")
	_check(not camera.move_pixels(Vector2i.ONE).ok and camera.snapshot() == before, "manual input cannot mutate automatic motion")
	camera.finish()
	before = camera.snapshot()
	_check(not camera.move_pixels(Vector2i.ONE).ok and camera.snapshot() == before, "manual input cannot mutate a completed camera")


func _test_finish_and_reset() -> void:
	var camera := CameraScript.new()
	var idle := camera.snapshot()
	_check(idle.mode == 0 and idle.phase == "idle" and not idle.active and not idle.finished, "fresh camera is idle and is not already completed")
	_check(camera.advance(1.0) == idle and camera.finish() == idle, "advance and finish are no-ops while idle")
	camera.start(7, SOURCE_SIZE, VIEWPORT_SIZE)
	camera.advance(1.2)
	var state := camera.finish()
	_check(state.finished and state.crop == Vector2i.ZERO and state.elapsed_ms == 1200.0, "early finish restores automatic origin without inventing elapsed time")
	_check(camera.finish() == state and camera.advance(10.0) == state, "completed camera is stable under repeated finish and clock ticks")
	var external := camera.snapshot()
	external.crop = Vector2i(999, 999)
	_check(camera.snapshot() == state, "snapshot mutation cannot change camera-owned state")
	camera.reset()
	_check(camera.snapshot() == idle, "reset clears mode, clock, source extent, crop, and completion")
	camera.start(7, SOURCE_SIZE, VIEWPORT_SIZE)
	camera.advance(2.595)
	state = camera.start(8, SOURCE_SIZE, VIEWPORT_SIZE)
	_check(state.mode == 8 and state.elapsed_ms == 0.0 and state.crop == Vector2i.ZERO and not state.finished, "a valid new start clears prior motion and completion state")


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("PASS: ", label)
	else:
		_failed = true
		push_error("FAIL: " + label)
