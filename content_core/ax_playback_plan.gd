class_name KakyuAxPlaybackPlan
extends RefCounted

const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")
const AxAnimationScript := preload("res://content_core/ax_animation.gd")
const AxSurfaceBindingScript := preload("res://content_core/ax_surface_binding.gd")

const LOGICAL_SIZE := Vector2i(640, 400)

var _animation := AxAnimationScript.new()
var _surface_binding := AxSurfaceBindingScript.new()


func compile(
	animation: Dictionary,
	row: int,
	column: int,
	source_size: Vector2i,
	allow_noop_records := true,
	source_binding := {}
) -> Dictionary:
	if not bool(animation.get("ok", false)):
		return _error("A validated AX animation is required.")
	if str(animation.get("schema", "")) != ContentCoreVersionScript.AX_ANIMATION_SCHEMA:
		return _error("AX animation schema is not supported.")
	if source_size.x <= 0 or source_size.y <= 0:
		return _error("AX playback source dimensions must be positive.")
	var confirmed_binding: Dictionary = {}
	if not source_binding.is_empty():
		var binding_validation := _surface_binding.validate(source_binding, source_size)
		if not binding_validation.get("ok", false):
			return binding_validation
		confirmed_binding = source_binding.duplicate(true)
	var timeline := _animation.compile_tool_timeline(animation, row, column)
	if not timeline.get("ok", false):
		return timeline
	var records: Array = animation.get("shared_records", [])
	var referenced_set: Dictionary = {}
	for untyped_event in timeline.get("dispatch_events", []):
		if not untyped_event is Dictionary:
			return _error("AX playback timeline event is malformed.")
		var event := untyped_event as Dictionary
		var shared_record_index := int(event.get("shared_record_index", -1))
		if shared_record_index < 0 or shared_record_index >= records.size():
			return _error("AX playback references shared record %d outside the inspected table." % shared_record_index)
		referenced_set[shared_record_index] = true
	var shared_record_indices: Array[int] = []
	for untyped_index in referenced_set.keys():
		shared_record_indices.append(int(untyped_index))
	shared_record_indices.sort()
	if shared_record_indices.is_empty():
		return _error("AX playback cell contains no shared-record references.")

	var frames: Array[Dictionary] = []
	var local_index_by_shared_record: Dictionary = {}
	var drawable_count := 0
	var noop_count := 0
	for shared_record_index in shared_record_indices:
		var record: Dictionary = records[shared_record_index]
		var consumer := str(record.get("native_consumer", ""))
		var dispatch_type := int(record.get("dispatch_type", -1))
		var drawable := consumer == "24bit_green_key_copy" and dispatch_type in [0, 1]
		if drawable:
			var source_x := int(record.get("source_x", -1))
			var source_y := int(record.get("source_y", -1))
			var width := int(record.get("width", 0))
			var height := int(record.get("height", 0))
			var destination_x := int(record.get("destination_x", -1))
			var destination_y := int(record.get("destination_y", -1))
			if (
				width <= 0 or height <= 0
				or source_x < 0 or source_y < 0
				or source_x > source_size.x - width
				or source_y > source_size.y - height
			):
				return _error(
					"AX shared record %d is outside the explicit %dx%d playback source."
					% [shared_record_index, source_size.x, source_size.y]
				)
			if (
				destination_x < 0 or destination_y < 0
				or destination_x > LOGICAL_SIZE.x - width
				or destination_y > LOGICAL_SIZE.y - height
			):
				return _error("AX shared record %d is outside the 640x400 destination." % shared_record_index)
			drawable_count += 1
		elif consumer == "consumer_noop" and allow_noop_records:
			noop_count += 1
		else:
			return _error(
				"AX shared record %d uses unsupported playback consumer %s (type %d)."
				% [shared_record_index, consumer, dispatch_type]
			)
		var local_index := frames.size()
		local_index_by_shared_record[shared_record_index] = local_index
		var frame := record.duplicate(true)
		frame["playback_frame_index"] = local_index
		frame["shared_record_index"] = shared_record_index
		frame["drawable"] = drawable
		frames.append(frame)

	var local_timeline := timeline.duplicate(true)
	for untyped_event in local_timeline.get("dispatch_events", []):
		var event := untyped_event as Dictionary
		var source_index := int(event.get("shared_record_index", -1))
		event["source_shared_record_index"] = source_index
		event["shared_record_index"] = int(local_index_by_shared_record[source_index])
	return {
		"ok": true,
		"schema": ContentCoreVersionScript.AX_PLAYBACK_PLAN_SCHEMA,
		"row": row,
		"column": column,
		"source_width": source_size.x,
		"source_height": source_size.y,
		"destination_width": LOGICAL_SIZE.x,
		"destination_height": LOGICAL_SIZE.y,
		"frames": frames,
		"shared_record_indices": shared_record_indices,
		"drawable_frame_count": drawable_count,
		"noop_frame_count": noop_count,
		"timeline": local_timeline,
		"source_contract": (
			"confirmed_mes_mmo_load_into_native_surface_8"
			if not confirmed_binding.is_empty()
			else "explicit_detached_image_native_surface_8_owner_unresolved"
		),
		"source_binding": confirmed_binding,
		"timing_basis": "shared_tool_clock_native_host_cadence_unconfirmed",
	}


func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message}
