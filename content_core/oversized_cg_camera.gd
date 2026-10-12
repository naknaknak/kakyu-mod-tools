class_name KakyuOversizedCgCamera
extends RefCounted

## Source-commanded camera geometry projected onto a deterministic tool clock.
## Mode 7 deliberately supports only the audited 988x588 / 640x400 geometry.
## Its rational samples are not a native x87 pixel or observed-cadence oracle.
## Mode 8 accepts crop-space pixel deltas; pointer-drag sign belongs to the UI.

const AUDITED_SOURCE_SIZE := Vector2i(988, 588)
const LOGICAL_VIEWPORT_SIZE := Vector2i(640, 400)
const SAMPLE_DEADLINE_MS := 15
const OUTBOUND_SAMPLE_COUNT := 173
const RETURN_SAMPLE_COUNT := 174
const ENDPOINT_HOLD_MS := 1000
const OUTBOUND_END_MS := OUTBOUND_SAMPLE_COUNT * SAMPLE_DEADLINE_MS
const RETURN_START_MS := OUTBOUND_END_MS + ENDPOINT_HOLD_MS
const DURATION_MS := RETURN_START_MS + RETURN_SAMPLE_COUNT * SAMPLE_DEADLINE_MS
const SAMPLE_SEMANTICS := "rational_geometry_deadline_projection_not_native_pixel_oracle"
const NANOSECONDS_PER_SECOND := 1000000000.0
const NANOSECONDS_PER_MS := 1000000
# Keeps tool-clock conversion within a signed 64-bit integer, including mode 8.
const MAX_TOOL_SECONDS := 1000000000.0

var _mode := 0
var _active := false
var _finished := false
var _source_size := Vector2i.ZERO
var _viewport_size := Vector2i.ZERO
var _crop_bounds := Vector2i.ZERO
var _crop := Vector2i.ZERO
var _elapsed_seconds := 0.0
var _clock_compensation := 0.0
var _phase := "idle"
var _sample_index := -1
var _manual_return_start_crop := Vector2i.ZERO
var _manual_return_sample_count := 0
var _manual_return_elapsed_seconds := 0.0
var _manual_return_clock_compensation := 0.0


func start(mode: int, source_size: Vector2i, viewport_size: Vector2i) -> Dictionary:
	if mode not in [7, 8]:
		return _error("Only source-commanded camera modes 7 and 8 are supported.")
	if viewport_size.x <= 0 or viewport_size.y <= 0:
		return _error("The logical viewport must have positive dimensions.")
	if source_size.x < viewport_size.x or source_size.y < viewport_size.y:
		return _error("The source must contain the complete logical viewport.")
	if mode == 7 and (source_size != AUDITED_SOURCE_SIZE or viewport_size != LOGICAL_VIEWPORT_SIZE):
		return _error("Mode 7 requires the audited 988x588 source and 640x400 viewport.")
	reset()
	_mode = mode
	_active = true
	_source_size = source_size
	_viewport_size = viewport_size
	_crop_bounds = source_size - viewport_size
	if mode == 7:
		_project_automatic()
	else:
		_phase = "manual"
	return snapshot()


func advance(delta: float) -> Dictionary:
	if not is_finite(delta) or delta < 0.0:
		return _error("Camera delta must be finite and nonnegative.")
	if not _active or delta == 0.0:
		return snapshot()
	var accepted_delta := delta
	if _mode == 7:
		accepted_delta = minf(delta, float(DURATION_MS) / 1000.0 - _elapsed_seconds)
	elif _phase == "manual_return":
		accepted_delta = minf(delta, float(_manual_return_duration_ms()) / 1000.0 - _manual_return_elapsed_seconds)
	elif delta > MAX_TOOL_SECONDS - _elapsed_seconds:
		return _error("Camera elapsed time would exceed the tool clock range.")
	# Compensated accumulation retains sub-deadline fractions across arbitrarily
	# partitioned frame deltas. Round only the cumulative clock, not each delta.
	var corrected_delta := accepted_delta - _clock_compensation
	var next_seconds := _elapsed_seconds + corrected_delta
	_clock_compensation = (next_seconds - _elapsed_seconds) - corrected_delta
	_elapsed_seconds = next_seconds
	if _mode == 7:
		_project_automatic()
	elif _phase == "manual_return":
		var return_delta := accepted_delta - _manual_return_clock_compensation
		var return_seconds := _manual_return_elapsed_seconds + return_delta
		_manual_return_clock_compensation = (return_seconds - _manual_return_elapsed_seconds) - return_delta
		_manual_return_elapsed_seconds = return_seconds
		_project_manual_return()
	return snapshot()


func move_pixels(delta: Vector2i) -> Dictionary:
	if not _active or _mode != 8 or _phase != "manual":
		return _error("Manual crop movement requires a mode-8 camera in its manual phase.")
	# Add as 64-bit scalars before clamping, avoiding Vector2i overflow.
	_crop = Vector2i(
		clampi(int(_crop.x) + int(delta.x), 0, _crop_bounds.x),
		clampi(int(_crop.y) + int(delta.y), 0, _crop_bounds.y)
	)
	return snapshot()


func request_finish() -> Dictionary:
	if not _active or _phase == "manual_return":
		return snapshot()
	if _mode != 8:
		return _error("Only mode 8 accepts an interactive finish request.")
	# Native 0x4177AD..0x4179AB starts at floor(max(dx,dy)/2)-1 and
	# visits every index down to zero, with a 15-ms deadline per sample.
	# Extents zero/one skip the loop and reach the explicit origin copy.
	var sample_count := int(maxi(_crop.x, _crop.y) / 2)
	if float(sample_count * SAMPLE_DEADLINE_MS) / 1000.0 > MAX_TOOL_SECONDS - _elapsed_seconds:
		return _error("Manual return would exceed the tool clock range.")
	_manual_return_start_crop = _crop
	_manual_return_sample_count = sample_count
	_manual_return_elapsed_seconds = 0.0
	_manual_return_clock_compensation = 0.0
	_phase = "manual_return"
	_project_manual_return()
	return snapshot()


func finish() -> Dictionary:
	# Explicit tool cancellation; normal mode-8 completion uses request_finish.
	if _active:
		_restore_origin()
	return snapshot()


func reset() -> void:
	_mode = 0
	_active = false
	_finished = false
	_source_size = Vector2i.ZERO
	_viewport_size = Vector2i.ZERO
	_crop_bounds = Vector2i.ZERO
	_crop = Vector2i.ZERO
	_elapsed_seconds = 0.0
	_clock_compensation = 0.0
	_phase = "idle"
	_sample_index = -1
	_manual_return_start_crop = Vector2i.ZERO
	_manual_return_sample_count = 0
	_manual_return_elapsed_seconds = 0.0
	_manual_return_clock_compensation = 0.0


func snapshot() -> Dictionary:
	return {
		"ok": true,
		"mode": _mode,
		"active": _active,
		"finished": _finished,
		"source_size": _source_size,
		"viewport_size": _viewport_size,
		"crop_bounds": _crop_bounds,
		"crop": _crop,
		"elapsed_ms": float(_elapsed_nanoseconds()) / NANOSECONDS_PER_MS,
		"phase": _phase,
		"sample_index": _sample_index,
		"manual_return_start_crop": _manual_return_start_crop,
		"manual_return_sample_count": _manual_return_sample_count,
		"manual_return_elapsed_ms": float(roundi(_manual_return_elapsed_seconds * NANOSECONDS_PER_SECOND)) / NANOSECONDS_PER_MS,
		"manual_return_deadline_ms": _manual_return_duration_ms(),
		"clock_semantics": "deterministic_tool_clock_projection",
		"sample_semantics": SAMPLE_SEMANTICS,
	}


func _project_automatic() -> void:
	var elapsed_ns := _elapsed_nanoseconds()
	if elapsed_ns < OUTBOUND_END_MS * NANOSECONDS_PER_MS:
		_phase = "outbound"
		_sample_index = 1 + int(elapsed_ns / (SAMPLE_DEADLINE_MS * NANOSECONDS_PER_MS))
		_crop = _rational_crop(_sample_index)
	elif elapsed_ns < RETURN_START_MS * NANOSECONDS_PER_MS:
		_phase = "endpoint_hold"
		_sample_index = -1
		_crop = _crop_bounds
	elif elapsed_ns < DURATION_MS * NANOSECONDS_PER_MS:
		_phase = "return"
		var return_elapsed_ns := elapsed_ns - RETURN_START_MS * NANOSECONDS_PER_MS
		_sample_index = OUTBOUND_SAMPLE_COUNT - int(return_elapsed_ns / (SAMPLE_DEADLINE_MS * NANOSECONDS_PER_MS))
		_crop = _rational_crop(_sample_index)
	else:
		_elapsed_seconds = float(DURATION_MS) / 1000.0
		_clock_compensation = 0.0
		_restore_origin()


func _rational_crop(index: int) -> Vector2i:
	return Vector2i(2 * index, int((376 * index) / 348))


func _project_manual_return() -> void:
	var elapsed_ns := roundi(_manual_return_elapsed_seconds * NANOSECONDS_PER_SECOND)
	if elapsed_ns >= _manual_return_duration_ms() * NANOSECONDS_PER_MS:
		_manual_return_elapsed_seconds = float(_manual_return_duration_ms()) / 1000.0
		_manual_return_clock_compensation = 0.0
		_restore_origin()
		return
	_sample_index = _manual_return_sample_count - 1 - int(elapsed_ns / (SAMPLE_DEADLINE_MS * NANOSECONDS_PER_MS))
	var maximum := maxi(_manual_return_start_crop.x, _manual_return_start_crop.y)
	# Scalar integer products stay below int64 even for the Vector2i limit.
	# Native uses stored x87/binary64 ratios; this remains a rational projection.
	_crop = Vector2i(
		int((2 * int(_manual_return_start_crop.x) * _sample_index) / maximum),
		int((2 * int(_manual_return_start_crop.y) * _sample_index) / maximum)
	)


func _manual_return_duration_ms() -> int:
	return _manual_return_sample_count * SAMPLE_DEADLINE_MS


func _elapsed_nanoseconds() -> int:
	return roundi(_elapsed_seconds * NANOSECONDS_PER_SECOND)


func _restore_origin() -> void:
	_crop = Vector2i.ZERO
	_active = false
	_finished = true
	_phase = "finished"
	_sample_index = 0


func _error(message: String) -> Dictionary:
	var result := snapshot()
	result["ok"] = false
	result["error"] = message
	return result
