class_name KakyuModDefinitionRowList
extends VBoxContainer

## A generic list of row editors (conditions, effects, dialogue entries,
## override operations) with Add / Remove / Up / Down (MW-13, unit B2). The
## caller supplies `build_row` to fill an empty row's controls and wire their
## own "changed" notifications, and `row_to_data`/`row_from_data` to
## translate a row's controls to and from its JSON shape; this class only
## manages the list, not what a row means.

signal changed

## Callable(row: HFlowContainer, notify: Callable) -> void
var build_row: Callable
## Callable(row: HFlowContainer) -> Dictionary
var row_to_data: Callable
## Callable(row: HFlowContainer, data: Dictionary) -> void
var row_from_data: Callable
var add_label := "Add"

var _list: VBoxContainer
var _entries: Array = []  # [{"wrapper": Control, "row": HFlowContainer}]
var _built := false


func _ready() -> void:
	_ensure_built()


## Builds the toolbar and list container the first time they are needed.
## `add_row` may run before this node has entered the scene tree (a nested
## `KakyuModDefinitionRowList` built by an outer row's `row_from_data`, for
## instance, is populated before it is added anywhere), so construction
## cannot wait for `_ready`.
func _ensure_built() -> void:
	if _built:
		return
	_built = true
	var toolbar := HBoxContainer.new()
	add_child(toolbar)
	var add_button := Button.new()
	add_button.text = add_label
	add_button.pressed.connect(func() -> void: add_row())
	toolbar.add_child(add_button)
	_list = VBoxContainer.new()
	add_child(_list)


func add_row(data: Dictionary = {}) -> HFlowContainer:
	_ensure_built()
	var row := HFlowContainer.new()
	build_row.call(row, func() -> void: changed.emit())
	if not data.is_empty():
		row_from_data.call(row, data)
	var wrapper := HBoxContainer.new()
	var row_panel := PanelContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_panel.add_child(row)
	row_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrapper.add_child(row_panel)
	var buttons := HBoxContainer.new()
	var up := Button.new()
	up.text = "Up"
	up.pressed.connect(func() -> void: _move(wrapper, -1))
	var down := Button.new()
	down.text = "Down"
	down.pressed.connect(func() -> void: _move(wrapper, 1))
	var remove := Button.new()
	remove.text = "Remove"
	remove.pressed.connect(func() -> void: _remove(wrapper))
	buttons.add_child(up)
	buttons.add_child(down)
	buttons.add_child(remove)
	wrapper.add_child(buttons)
	_list.add_child(wrapper)
	_entries.append({"wrapper": wrapper, "row": row})
	changed.emit()
	return row


func clear() -> void:
	for entry in _entries:
		(entry.wrapper as Control).queue_free()
	_entries.clear()


func get_rows() -> Array:
	var result: Array = []
	for entry in _entries:
		result.append(entry.row)
	return result


func get_data() -> Array:
	var result: Array = []
	for entry in _entries:
		result.append(row_to_data.call(entry.row))
	return result


func _entry_index_for_wrapper(wrapper: Control) -> int:
	for i in range(_entries.size()):
		if _entries[i].wrapper == wrapper:
			return i
	return -1


func _move(wrapper: Control, delta: int) -> void:
	var entry_index := _entry_index_for_wrapper(wrapper)
	if entry_index == -1:
		return
	var target_index := entry_index + delta
	if target_index < 0 or target_index >= _entries.size():
		return
	_list.move_child(wrapper, wrapper.get_index() + delta)
	var tmp = _entries[entry_index]
	_entries[entry_index] = _entries[target_index]
	_entries[target_index] = tmp
	changed.emit()


func _remove(wrapper: Control) -> void:
	var entry_index := _entry_index_for_wrapper(wrapper)
	if entry_index != -1:
		_entries.remove_at(entry_index)
	wrapper.queue_free()
	changed.emit()
