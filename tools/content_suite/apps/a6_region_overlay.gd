class_name ContentToolA6RegionOverlay
extends Control

const SELECTED_FILL := Color(0.2, 0.75, 1.0, 0.22)
const SELECTED_LINE := Color(0.35, 0.85, 1.0, 1.0)
const HOVER_LINE := Color(1.0, 0.8, 0.2, 1.0)
const REGION_LINE := Color(0.45, 0.65, 0.8, 0.68)

var _records: Array = []
var _selected_index := -1
var _hovered_index := -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_regions(records: Array, selected_index: int) -> void:
	_records = records.duplicate(true)
	_selected_index = selected_index if selected_index >= 0 and selected_index < _records.size() else -1
	_hovered_index = -1
	visible = not _records.is_empty()
	queue_redraw()


func clear_regions() -> void:
	_records.clear()
	_selected_index = -1
	_hovered_index = -1
	visible = false
	queue_redraw()


func set_selected_index(record_index: int) -> void:
	_selected_index = record_index if record_index >= 0 and record_index < _records.size() else -1
	queue_redraw()


func set_hovered_index(record_index: int) -> void:
	var bounded := record_index if record_index >= 0 and record_index < _records.size() else -1
	if bounded == _hovered_index:
		return
	_hovered_index = bounded
	queue_redraw()


func get_region_count() -> int:
	return _records.size()


func get_selected_index() -> int:
	return _selected_index


func get_region_rect(record_index: int) -> Rect2:
	if record_index < 0 or record_index >= _records.size():
		return Rect2()
	var record: Dictionary = _records[record_index]
	var left := int(record.get("left", 0))
	var top := int(record.get("top", 0))
	var right := int(record.get("right", left - 1))
	var bottom := int(record.get("bottom", top - 1))
	if right < left or bottom < top:
		return Rect2()
	return Rect2(Vector2(left, top), Vector2(right - left + 1, bottom - top + 1))


func _draw() -> void:
	for record_index in range(_records.size()):
		var region := get_region_rect(record_index)
		if region.size.x <= 0.0 or region.size.y <= 0.0:
			continue
		if record_index == _selected_index:
			draw_rect(region, SELECTED_FILL, true)
		var line_color := REGION_LINE
		var line_width := 1.0
		if record_index == _selected_index:
			line_color = SELECTED_LINE
			line_width = 2.0
		if record_index == _hovered_index:
			line_color = HOVER_LINE
			line_width = 2.0
		draw_rect(region, line_color, false, line_width)
