class_name KakyuAxToolScheduler
extends RefCounted

const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")
const MAX_TICKS_PER_ADVANCE := 4096

var _configured := false
var _cycle_ticks := 0
var _seconds_per_tick := 0.0
var _dispatch_by_tick: Dictionary = {}
var _current_tick := 0
var _current_shared_record_index := -1
var _completed_cycles := 0
var _elapsed_seconds := 0.0
var _loops := false
var _finished := false


func configure(timeline: Dictionary, seconds_per_tick: float) -> Dictionary:
	if not bool(timeline.get("ok", false)):
		return _error("A validated AX tool timeline is required.")
	if str(timeline.get("schema", "")) != ContentCoreVersionScript.AX_ANIMATION_SCHEMA:
		return _error("AX tool timeline schema is not supported.")
	if not is_finite(seconds_per_tick) or seconds_per_tick <= 0.0:
		return _error("AX tool tick duration must be a positive finite value.")
	var cycle_ticks := int(timeline.get("tool_ticks_per_cycle", 0))
	if cycle_ticks <= 0:
		return _error("AX tool timeline cycle length must be positive.")
	var dispatch_by_tick: Dictionary = {}
	var previous_tick := -1
	for untyped_event in timeline.get("dispatch_events", []):
		if not untyped_event is Dictionary:
			return _error("AX tool timeline dispatch events must be dictionaries.")
		var event := untyped_event as Dictionary
		var tick := int(event.get("tick", -1))
		var shared_record_index := int(event.get("shared_record_index", -1))
		if tick < 0 or tick >= cycle_ticks:
			return _error("AX tool timeline dispatch tick %d is outside cycle length %d." % [tick, cycle_ticks])
		if tick <= previous_tick or dispatch_by_tick.has(tick):
			return _error("AX tool timeline dispatch ticks must be strictly increasing and unique.")
		if shared_record_index < 0:
			return _error("AX tool timeline dispatch record index must be non-negative.")
		dispatch_by_tick[tick] = {
			"tick": tick,
			"shared_record_index": shared_record_index,
			"source_offset": int(event.get("source_offset", -1)),
		}
		previous_tick = tick
	if dispatch_by_tick.is_empty():
		return _error("AX tool timeline must contain at least one dispatch event.")

	_cycle_ticks = cycle_ticks
	_seconds_per_tick = seconds_per_tick
	_dispatch_by_tick = dispatch_by_tick
	_current_tick = 0
	_current_shared_record_index = -1
	_completed_cycles = 0
	_elapsed_seconds = 0.0
	_loops = bool(timeline.get("reset_at_end", false))
	_finished = false
	_configured = true
	if _dispatch_by_tick.has(0):
		_current_shared_record_index = int(_dispatch_by_tick[0].shared_record_index)
	return {
		"ok": true,
		"schema": ContentCoreVersionScript.AX_TOOL_SCHEDULER_SCHEMA,
		"initial_dispatch": _event_for_current_tick(),
		"snapshot": snapshot(),
	}


func advance_ticks(count: int) -> Dictionary:
	if not _configured:
		return _error("AX tool scheduler is not configured.")
	if count < 0:
		return _error("AX tool tick advance cannot be negative.")
	if count > MAX_TICKS_PER_ADVANCE:
		return _error("AX tool tick advance exceeds the bounded limit of %d." % MAX_TICKS_PER_ADVANCE)
	var events: Array[Dictionary] = []
	var advanced_ticks := 0
	for _step in range(count):
		if _finished:
			break
		_current_tick += 1
		advanced_ticks += 1
		if _current_tick >= _cycle_ticks:
			if _loops:
				_current_tick = 0
				_completed_cycles += 1
			else:
				_current_tick = _cycle_ticks - 1
				_finished = true
				break
		if _dispatch_by_tick.has(_current_tick):
			var dispatch: Dictionary = _dispatch_by_tick[_current_tick]
			_current_shared_record_index = int(dispatch.shared_record_index)
			events.append({
				"tick": _current_tick,
				"completed_cycles": _completed_cycles,
				"shared_record_index": _current_shared_record_index,
				"source_offset": int(dispatch.source_offset),
			})
	return {
		"ok": true,
		"schema": ContentCoreVersionScript.AX_TOOL_SCHEDULER_SCHEMA,
		"advanced_ticks": advanced_ticks,
		"events": events,
		"snapshot": snapshot(),
	}


func advance_seconds(delta: float, max_ticks := 240) -> Dictionary:
	if not _configured:
		return _error("AX tool scheduler is not configured.")
	if not is_finite(delta) or delta < 0.0:
		return _error("AX tool elapsed time must be finite and non-negative.")
	if max_ticks <= 0:
		return _error("AX tool catch-up limit must be positive.")
	if max_ticks > MAX_TICKS_PER_ADVANCE:
		return _error("AX tool catch-up limit exceeds %d ticks." % MAX_TICKS_PER_ADVANCE)
	if _finished:
		_elapsed_seconds = 0.0
		var finished_result := advance_ticks(0)
		finished_result["due_ticks"] = 0
		finished_result["catch_up_limited"] = false
		finished_result["pending_ticks"] = 0
		finished_result["snapshot"] = snapshot()
		return finished_result
	_elapsed_seconds += delta
	var due_ticks := floori(_elapsed_seconds / _seconds_per_tick)
	var requested_ticks := mini(due_ticks, max_ticks)
	var result := advance_ticks(requested_ticks)
	if not result.ok:
		return result
	var advanced_ticks := int(result.advanced_ticks)
	if advanced_ticks > 0:
		_elapsed_seconds -= float(advanced_ticks) * _seconds_per_tick
	if _finished:
		_elapsed_seconds = 0.0
	result["due_ticks"] = due_ticks
	result["catch_up_limited"] = not _finished and due_ticks > advanced_ticks
	result["pending_ticks"] = floori(_elapsed_seconds / _seconds_per_tick)
	result["snapshot"] = snapshot()
	return result


func snapshot() -> Dictionary:
	return {
		"schema": ContentCoreVersionScript.AX_TOOL_SCHEDULER_SCHEMA,
		"configured": _configured,
		"timing_basis": "explicit_tool_clock_native_host_cadence_unconfirmed",
		"cycle_ticks": _cycle_ticks,
		"seconds_per_tick": _seconds_per_tick,
		"current_tick": _current_tick,
		"current_shared_record_index": _current_shared_record_index,
		"completed_cycles": _completed_cycles,
		"elapsed_seconds": _elapsed_seconds,
		"loops": _loops,
		"finished": _finished,
	}


func clear() -> void:
	_configured = false
	_cycle_ticks = 0
	_seconds_per_tick = 0.0
	_dispatch_by_tick.clear()
	_current_tick = 0
	_current_shared_record_index = -1
	_completed_cycles = 0
	_elapsed_seconds = 0.0
	_loops = false
	_finished = false


func _event_for_current_tick() -> Dictionary:
	if not _dispatch_by_tick.has(_current_tick):
		return {}
	var dispatch: Dictionary = _dispatch_by_tick[_current_tick]
	return {
		"tick": _current_tick,
		"completed_cycles": _completed_cycles,
		"shared_record_index": int(dispatch.shared_record_index),
		"source_offset": int(dispatch.source_offset),
	}


func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message}
