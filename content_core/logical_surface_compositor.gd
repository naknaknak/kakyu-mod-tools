class_name KakyuLogicalSurfaceCompositor
extends RefCounted

const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")
const ContractValues := preload("res://content_core/contract_values.gd")

const LOGICAL_SURFACE_INDEX := 0
const LOGICAL_WIDTH := 640
const LOGICAL_HEIGHT := 400
const SUPPORTED_ROLES := {
	"logical_frame": true,
	"background": true,
	"foreground": true,
	"source": true,
	"intermediate": true,
}
const TRACE_MODE_SEMANTICS := {
	0: "opaque_rectangle_copy_confirmed",
	1: "rgb_chroma_key_rectangle_copy_confirmed",
	2: "active_surface_rectangle_fill_confirmed",
}
const TRACE_MODE_HELPERS := {
	0: 0x004254D0,
	1: 0x004255D0,
	2: 0x00425B10,
}

var last_error := ""
var _surfaces: Dictionary = {}
var _roles: Dictionary = {}
var _active_surface_index := -1
var _operation_sequence := 0


func clear() -> void:
	_surfaces.clear()
	_roles.clear()
	_active_surface_index = -1
	_operation_sequence = 0
	last_error = ""


func register_surface(index: int, image: Image, role := "intermediate") -> Dictionary:
	last_error = ""
	if index < 0 or image == null or image.is_empty():
		return _error("Surface index and image must be valid.")
	if not SUPPORTED_ROLES.has(role):
		return _error("Surface role is unsupported: %s" % role)
	if index == LOGICAL_SURFACE_INDEX and (
		image.get_width() != LOGICAL_WIDTH or image.get_height() != LOGICAL_HEIGHT
	):
		return _error("Logical surface 0 must be 640x400.")
	var stored := _clone_image(image)
	stored.convert(Image.FORMAT_RGB8)
	_surfaces[index] = stored
	_roles[index] = role
	if _active_surface_index < 0:
		_active_surface_index = index
	return {
		"ok": true,
		"index": index,
		"width": stored.get_width(),
		"height": stored.get_height(),
		"role": role,
	}


func set_active_surface(index: int) -> Dictionary:
	last_error = ""
	if not _surfaces.has(index):
		return _error("Active surface is not registered: %d" % index)
	_active_surface_index = index
	return {"ok": true, "active_surface_index": index}


func get_active_surface_index() -> int:
	return _active_surface_index


func get_surface_copy(index: int) -> Image:
	if not _surfaces.has(index):
		return null
	return _clone_image(_surfaces[index] as Image)


func describe() -> Dictionary:
	var rows: Array[Dictionary] = []
	var indices: Array = _surfaces.keys()
	indices.sort()
	for index_value in indices:
		var index := int(index_value)
		var image: Image = _surfaces[index]
		rows.append({
			"index": index,
			"width": image.get_width(),
			"height": image.get_height(),
			"format": image.get_format(),
			"role": str(_roles.get(index, "intermediate")),
			"active": index == _active_surface_index,
		})
	return {
		"ok": true,
		"schema": ContentCoreVersionScript.LOGICAL_SURFACE_COMPOSITOR_SCHEMA,
		"logical_width": LOGICAL_WIDTH,
		"logical_height": LOGICAL_HEIGHT,
		"active_surface_index": _active_surface_index,
		"operation_sequence": _operation_sequence,
		"surfaces": rows,
	}


func capture_checkpoint() -> Dictionary:
	last_error = ""
	var rows: Array[Dictionary] = []
	var indices: Array = _surfaces.keys()
	indices.sort()
	for index_value in indices:
		var index := int(index_value)
		var image: Image = _surfaces[index]
		var pixels := image.get_data()
		rows.append({
			"index": index,
			"width": image.get_width(),
			"height": image.get_height(),
			"format": int(image.get_format()),
			"mipmaps": image.has_mipmaps(),
			"role": str(_roles.get(index, "intermediate")),
			"pixels": pixels,
			"pixel_sha256": ContractValues.sha256(pixels),
		})
	return {
		"ok": true,
		"schema": ContentCoreVersionScript.LOGICAL_SURFACE_CHECKPOINT_SCHEMA,
		"compositor_schema": ContentCoreVersionScript.LOGICAL_SURFACE_COMPOSITOR_SCHEMA,
		"active_surface_index": _active_surface_index,
		"operation_sequence": _operation_sequence,
		"surfaces": rows,
		"state_sha256": _checkpoint_state_sha256(_active_surface_index, _operation_sequence, rows),
	}


func restore_checkpoint(checkpoint: Dictionary) -> Dictionary:
	last_error = ""
	if str(checkpoint.get("schema", "")) != ContentCoreVersionScript.LOGICAL_SURFACE_CHECKPOINT_SCHEMA:
		return _error("Logical-surface checkpoint schema is unsupported.")
	if str(checkpoint.get("compositor_schema", "")) != ContentCoreVersionScript.LOGICAL_SURFACE_COMPOSITOR_SCHEMA:
		return _error("Logical-surface checkpoint targets a different compositor schema.")
	var sequence := int(checkpoint.get("operation_sequence", -1))
	if sequence < 0:
		return _error("Logical-surface checkpoint operation sequence is invalid.")
	var rows_value = checkpoint.get("surfaces", null)
	if not rows_value is Array:
		return _error("Logical-surface checkpoint surface list is missing.")
	var candidate_surfaces := {}
	var candidate_roles := {}
	var normalized_rows: Array[Dictionary] = []
	for row_value in rows_value as Array:
		if not row_value is Dictionary:
			return _error("Logical-surface checkpoint row is invalid.")
		var row: Dictionary = row_value
		var index := int(row.get("index", -1))
		var width := int(row.get("width", 0))
		var height := int(row.get("height", 0))
		var format := int(row.get("format", -1))
		var role := str(row.get("role", ""))
		var pixels_value = row.get("pixels", null)
		if index < 0 or candidate_surfaces.has(index):
			return _error("Logical-surface checkpoint index is invalid or duplicated.")
		if width <= 0 or height <= 0 or format != Image.FORMAT_RGB8 or bool(row.get("mipmaps", true)):
			return _error("Logical-surface checkpoint image metadata is unsupported.")
		if index == LOGICAL_SURFACE_INDEX and (width != LOGICAL_WIDTH or height != LOGICAL_HEIGHT):
			return _error("Logical-surface checkpoint surface 0 is not 640x400.")
		if not SUPPORTED_ROLES.has(role):
			return _error("Logical-surface checkpoint role is unsupported: %s" % role)
		if not pixels_value is PackedByteArray:
			return _error("Logical-surface checkpoint pixels are missing.")
		var pixels: PackedByteArray = pixels_value
		if pixels.size() != width * height * 3 or ContractValues.sha256(pixels) != str(row.get("pixel_sha256", "")):
			return _error("Logical-surface checkpoint pixel binding is invalid.")
		var image := Image.create_from_data(width, height, false, Image.FORMAT_RGB8, pixels)
		if image == null or image.is_empty():
			return _error("Logical-surface checkpoint image could not be reopened.")
		candidate_surfaces[index] = image
		candidate_roles[index] = role
		normalized_rows.append(row.duplicate(true))
	var active_index := int(checkpoint.get("active_surface_index", -2))
	if (candidate_surfaces.is_empty() and active_index != -1) or (
		not candidate_surfaces.is_empty() and not candidate_surfaces.has(active_index)
	):
		return _error("Logical-surface checkpoint active surface is invalid.")
	if _checkpoint_state_sha256(active_index, sequence, normalized_rows) != str(checkpoint.get("state_sha256", "")):
		return _error("Logical-surface checkpoint state binding is invalid.")
	_surfaces = candidate_surfaces
	_roles = candidate_roles
	_active_surface_index = active_index
	_operation_sequence = sequence
	return {
		"ok": true,
		"schema": ContentCoreVersionScript.LOGICAL_SURFACE_CHECKPOINT_SCHEMA,
		"active_surface_index": active_index,
		"operation_sequence": sequence,
		"surface_count": candidate_surfaces.size(),
	}


func apply_mes_trace(trace_record: Dictionary, presentation_context := {}) -> Dictionary:
	last_error = ""
	if str(trace_record.get("effect", "")) != "surface_operation_omitted":
		return _error("MES trace is not a confirmed omitted surface operation.")
	if int(trace_record.get("presentation_subcommand", -1)) != 11:
		return _error("MES surface trace has the wrong presentation subcommand.")
	if not bool(trace_record.get("native_pixel_effect_omitted", false)):
		return _error("MES surface trace is not the non-executing runner boundary.")
	if bool(trace_record.get("gameplay_sandbox_changed", true)):
		return _error("MES surface trace unexpectedly changed sandbox state.")
	var mode := int(trace_record.get("surface_mode", -1))
	if not TRACE_MODE_SEMANTICS.has(mode):
		return _error("MES surface trace mode is unsupported: %d" % mode)
	if str(trace_record.get("native_operation_semantics", "")) != str(TRACE_MODE_SEMANTICS[mode]):
		return _error("MES surface trace semantics do not match mode %d." % mode)
	if str(trace_record.get("native_endpoint_semantics", "")) != "inclusive_width_height_expansion_confirmed":
		return _error("MES surface trace endpoint semantics are not confirmed.")
	if int(trace_record.get("native_pixel_helper", 0)) != int(TRACE_MODE_HELPERS[mode]):
		return _error("MES surface trace helper does not match mode %d." % mode)
	var arguments_value = trace_record.get("surface_arguments", null)
	if not arguments_value is Array:
		return _error("MES surface trace arguments are missing.")
	var arguments: Array = arguments_value
	var expected_counts := [8, 9] if mode == 0 else ([9] if mode == 1 else [5])
	if arguments.size() not in expected_counts or int(arguments[0]) != mode:
		return _error("MES surface trace argument shape does not match mode %d." % mode)
	var operation := {
		"mode": mode,
		"source_x": int(arguments[1]),
		"source_y": int(arguments[2]),
		"inclusive_right": int(arguments[3]),
		"inclusive_bottom": int(arguments[4]),
	}
	if mode in [0, 1]:
		operation["source_surface_index"] = int(arguments[5])
		operation["destination_x"] = int(arguments[6])
		operation["destination_y"] = int(arguments[7])
		operation["destination_surface_index"] = int(arguments[8]) if arguments.size() == 9 else LOGICAL_SURFACE_INDEX
		if mode == 1:
			if not presentation_context.has("rgb_key"):
				return _error("MES RGB-key trace requires an explicit presentation-context key.")
			operation["rgb_key"] = presentation_context.rgb_key
	else:
		if not presentation_context.has("fill_color"):
			return _error("MES fill trace requires an explicit presentation-context color.")
		operation["fill_color"] = presentation_context.fill_color
	var applied := apply_operation(operation)
	if not applied.get("ok", false):
		return applied
	applied["source"] = "mes_event_trace"
	applied["trace_effect"] = "surface_operation_omitted"
	applied["presentation_context_explicit"] = mode in [1, 2]
	return applied


func apply_operations_in_order(operations: Array[Dictionary]) -> Dictionary:
	last_error = ""
	var checkpoint := capture_checkpoint()
	if not checkpoint.get("ok", false):
		return checkpoint
	var sequence_start := _operation_sequence
	for operation_index in range(operations.size()):
		var applied := apply_operation(operations[operation_index])
		if not applied.get("ok", false):
			var operation_error := str(applied.get("error", "Surface operation failed."))
			var restored := restore_checkpoint(checkpoint)
			if not restored.get("ok", false):
				return _error("Surface batch failed and its internal checkpoint could not be restored.")
			last_error = operation_error
			return {
				"ok": false,
				"error": operation_error,
				"failed_operation_index": operation_index,
				"applied_before_failure": operation_index,
				"rolled_back": true,
				"operation_sequence": _operation_sequence,
			}
	return {
		"ok": true,
		"schema": ContentCoreVersionScript.LOGICAL_SURFACE_COMPOSITOR_SCHEMA,
		"applied_count": operations.size(),
		"operation_sequence_start": sequence_start,
		"operation_sequence": _operation_sequence,
		"stored_order_preserved": true,
	}


func apply_operation(operation: Dictionary) -> Dictionary:
	last_error = ""
	var mode := int(operation.get("mode", -1))
	if mode not in [0, 1, 2]:
		return _error("Surface operation mode is unsupported: %d" % mode)
	var source_x := int(operation.get("source_x", -1))
	var source_y := int(operation.get("source_y", -1))
	var inclusive_right := int(operation.get("inclusive_right", -1))
	var inclusive_bottom := int(operation.get("inclusive_bottom", -1))
	if source_x < 0 or source_y < 0 or inclusive_right < source_x or inclusive_bottom < source_y:
		return _error("Surface operation rectangle is invalid.")
	var width := inclusive_right - source_x + 1
	var height := inclusive_bottom - source_y + 1
	var destination_index := _active_surface_index if mode == 2 else int(operation.get("destination_surface_index", LOGICAL_SURFACE_INDEX))
	if not _surfaces.has(destination_index):
		return _error("Destination surface is not registered: %d" % destination_index)
	var destination: Image = _surfaces[destination_index]
	var destination_x := source_x if mode == 2 else int(operation.get("destination_x", -1))
	var destination_y := source_y if mode == 2 else int(operation.get("destination_y", -1))
	if not _rect_fits(destination, destination_x, destination_y, width, height):
		return _error("Destination rectangle is outside surface %d." % destination_index)
	var source_index := -1
	if mode in [0, 1]:
		source_index = int(operation.get("source_surface_index", -1))
		if not _surfaces.has(source_index):
			return _error("Source surface is not registered: %d" % source_index)
		var source: Image = _surfaces[source_index]
		if not _rect_fits(source, source_x, source_y, width, height):
			return _error("Source rectangle is outside surface %d." % source_index)
		if mode == 0:
			destination.blit_rect(source, Rect2i(source_x, source_y, width, height), Vector2i(destination_x, destination_y))
		else:
			var key_value = operation.get("rgb_key", Color(0.0, 1.0, 0.0))
			if not key_value is Color:
				return _error("RGB-key operation requires a Color key.")
			_blit_rgb_key(source, destination, Rect2i(source_x, source_y, width, height), Vector2i(destination_x, destination_y), key_value)
	else:
		var fill_value = operation.get("fill_color", null)
		if not fill_value is Color:
			return _error("Fill operation requires a Color value.")
		destination.fill_rect(Rect2i(destination_x, destination_y, width, height), fill_value)
	_operation_sequence += 1
	return {
		"ok": true,
		"schema": ContentCoreVersionScript.LOGICAL_SURFACE_COMPOSITOR_SCHEMA,
		"mode": mode,
		"operation": [
			"opaque_rectangle_copy_confirmed",
			"rgb_chroma_key_rectangle_copy_confirmed",
			"active_surface_rectangle_fill_confirmed",
		][mode],
		"source_surface_index": source_index,
		"destination_surface_index": destination_index,
		"source_rect": Rect2i(source_x, source_y, width, height),
		"destination_rect": Rect2i(destination_x, destination_y, width, height),
		"operation_sequence": _operation_sequence,
	}


func _rect_fits(image: Image, x: int, y: int, width: int, height: int) -> bool:
	return x >= 0 and y >= 0 and width > 0 and height > 0 and x + width <= image.get_width() and y + height <= image.get_height()


func _clone_image(image: Image) -> Image:
	return Image.create_from_data(
		image.get_width(),
		image.get_height(),
		image.has_mipmaps(),
		image.get_format(),
		image.get_data()
	)


func _blit_rgb_key(source: Image, destination: Image, source_rect: Rect2i, destination_position: Vector2i, key: Color) -> void:
	var key_rgb := _rgb24(key)
	for y in range(source_rect.size.y):
		for x in range(source_rect.size.x):
			var pixel := source.get_pixel(source_rect.position.x + x, source_rect.position.y + y)
			if _rgb24(pixel) == key_rgb:
				continue
			destination.set_pixel(destination_position.x + x, destination_position.y + y, pixel)


func _rgb24(color: Color) -> int:
	return (
		clampi(roundi(color.r * 255.0), 0, 255) << 16
		| clampi(roundi(color.g * 255.0), 0, 255) << 8
		| clampi(roundi(color.b * 255.0), 0, 255)
	)


func _checkpoint_state_sha256(active_index: int, sequence: int, rows: Array[Dictionary]) -> String:
	var ordered := rows.duplicate(true)
	ordered.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return int(left.index) < int(right.index))
	var binding := "active=%d\nsequence=%d\n" % [active_index, sequence]
	for row in ordered:
		binding += "%d|%s|%d|%d|%d|%s\n" % [
			int(row.index),
			str(row.role),
			int(row.width),
			int(row.height),
			int(row.format),
			str(row.pixel_sha256),
		]
	return ContractValues.sha256(binding.to_utf8_buffer())


func _error(message: String) -> Dictionary:
	last_error = message
	return {"ok": false, "error": message}
