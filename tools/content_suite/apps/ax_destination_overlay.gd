class_name ContentToolAxDestinationOverlay
extends Control

const DESTINATION_FILL := Color(1.0, 0.35, 0.65, 0.13)
const DESTINATION_LINES := [
	Color(1.0, 0.35, 0.65, 0.95),
	Color(0.4, 0.85, 1.0, 0.95),
	Color(1.0, 0.8, 0.25, 0.95),
	Color(0.55, 1.0, 0.45, 0.95),
]

var _records: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_dispatch_records(records: Array) -> void:
	_records = records.duplicate(true)
	visible = not _records.is_empty()
	queue_redraw()


func clear_records() -> void:
	_records.clear()
	visible = false
	queue_redraw()


func get_dispatch_count() -> int:
	return _records.size()


func get_shared_record_index(dispatch_index: int) -> int:
	if dispatch_index < 0 or dispatch_index >= _records.size():
		return -1
	return int(_records[dispatch_index].get("index", -1))


func get_destination_rect(dispatch_index: int) -> Rect2:
	if dispatch_index < 0 or dispatch_index >= _records.size():
		return Rect2()
	var record: Dictionary = _records[dispatch_index]
	var width := int(record.get("width", 0))
	var height := int(record.get("height", 0))
	if width <= 0 or height <= 0:
		return Rect2()
	return Rect2(
		Vector2(int(record.get("destination_x", 0)), int(record.get("destination_y", 0))),
		Vector2(width, height)
	)


func _draw() -> void:
	for dispatch_index in range(_records.size()):
		var destination := get_destination_rect(dispatch_index)
		if destination.size.x <= 0.0 or destination.size.y <= 0.0:
			continue
		var color: Color = DESTINATION_LINES[dispatch_index % DESTINATION_LINES.size()]
		draw_rect(destination, DESTINATION_FILL, true)
		draw_rect(destination, color, false, 2.0)
