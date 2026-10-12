class_name KakyuModDefinitionForm
extends Control

## A structured form view of one `kakyu_mod_event_definition/v1` document,
## beside the Definitions tab's JSON text (MW-13, unit B). Covers a
## `new_event` with no top-level choice, exactly one `default`-selected
## result with no nested choice/results, and one terminal; and an `override`
## whose operations are all `replace_conditions`, `replace_after`,
## `replace_order_hint` or `disable`. Anything else is refused with a reason
## naming the first uncovered feature (section C); the JSON text stays the
## editor for that document.

const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")
const ContractValues := preload("res://content_core/contract_values.gd")
const StateCells := preload("res://content_core/state_cells.gd")

signal changed

const STORAGES := ["global_u8", "state_u16", "banked_u16", "banked_u8", "global_i32"]
const OPERATORS := ["equal", "not_equal", "less_than", "greater_than"]
const CONDITION_TYPES := [
	"always", "event_not_completed", "event_completed", "flag_equals", "weekday_equals",
	"date_equals", "date_in_range", "time_at_or_after", "time_before", "legacy_cell", "mes_expression",
]
const EFFECT_TYPES := ["write_legacy_value", "add_legacy_value", "consume_time", "set_flag"]
const DIALOGUE_KINDS := ["line", "choice_point", "scene_end"]
const OPERATION_KINDS := ["replace_conditions", "replace_after", "replace_order_hint", "disable"]
const TERMINAL_KINDS := ["return_to_map", "continue_caller"]
const CATEGORIES := ["school", "town", "date", "special"]

var _mod_id := ""
var _mod_id_editable := true
var _heroines := PackedStringArray()
var _suppress_changed := false
var _kind := "new_event"
var _contract_fingerprint := "self"
var _cells_fingerprint := "self"
## The single terminal's key as loaded (e.g. "term_return"); to_document
## writes this key back unchanged. Empty when the form has not loaded a
## document with a terminal of its own (a fresh form, or after refusing a
## document): to_document then names the entry by kind, "map" or "caller".
var _terminal_key := ""

var _header_reason_label: Label
var _kind_label: Label
var _mod_id_edit: LineEdit
var _name_edit: LineEdit
var _revision_spin: SpinBox
var _title_ko_edit: LineEdit
var _title_en_edit: LineEdit
var _heroine_option: OptionButton
var _category_option: OptionButton
var _place_edit: LineEdit

var _new_event_section: Control
var _trigger_category_label: Label
var _trigger_place_label: Label
var _order_rank_spin: SpinBox
var _conditions_list: KakyuModDefinitionRowList
var _presentation_mode_edit: LineEdit
var _presentation_background_edit: LineEdit
var _presentation_bgm_edit: LineEdit
var _presentation_hud_edit: LineEdit
var _presentation_message_window_edit: LineEdit
var _presentation_characters_edit: LineEdit
var _dialogue_list: KakyuModDefinitionRowList
var _after_list: KakyuModDefinitionRowList
var _result_dialogue_list: KakyuModDefinitionRowList
var _result_after_list: KakyuModDefinitionRowList
var _terminal_option: OptionButton
var _done_storage_option: OptionButton
var _done_bank_spin: SpinBox
var _done_index_spin: SpinBox
var _done_value_spin: SpinBox
var _done_unset_check: CheckButton

var _override_section: Control
var _target_id_label: Label
var _target_sha_label: Label
var _rebase_button: Button
var _operations_list: KakyuModDefinitionRowList


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(scroll)
	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(root)

	_header_reason_label = Label.new()
	_header_reason_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	root.add_child(_header_reason_label)

	_build_header(root)
	_new_event_section = _build_new_event_section(root)
	_override_section = _build_override_section(root)
	_apply_kind_visibility()


# ---------------------------------------------------------------------------
# Layout
# ---------------------------------------------------------------------------


func _build_header(root: VBoxContainer) -> void:
	var header := VBoxContainer.new()
	root.add_child(header)

	_kind_label = Label.new()
	header.add_child(_kind_label)

	var mod_row := HBoxContainer.new()
	header.add_child(mod_row)
	mod_row.add_child(Label.new())
	_mod_id_edit = LineEdit.new()
	_mod_id_edit.placeholder_text = "mod id"
	_mod_id_edit.text_changed.connect(func(_t: String) -> void: _notify_changed())
	mod_row.add_child(_mod_id_edit)
	_name_edit = _new_line_edit(mod_row, "name", _notify_changed)
	_revision_spin = _new_spin(mod_row, "revision", 1, 4294967295, _notify_changed)
	_revision_spin.value = 1

	var title_row := HBoxContainer.new()
	header.add_child(title_row)
	_title_ko_edit = _new_line_edit(title_row, "title_ko", _notify_changed)
	_title_en_edit = _new_line_edit(title_row, "title_en", _notify_changed)

	var display_row := HBoxContainer.new()
	header.add_child(display_row)
	_heroine_option = _new_option(display_row, "heroine", ["(none)"], _notify_changed)
	_category_option = _new_option(display_row, "category", CATEGORIES, _notify_changed)
	_place_edit = _new_line_edit(display_row, "place", _notify_changed)


func _build_new_event_section(root: VBoxContainer) -> Control:
	var section := VBoxContainer.new()
	root.add_child(section)

	section.add_child(_label_heading("Trigger"))
	var trigger_box := HBoxContainer.new()
	section.add_child(trigger_box)
	_trigger_category_label = Label.new()
	trigger_box.add_child(_trigger_category_label)
	_trigger_place_label = Label.new()
	trigger_box.add_child(_trigger_place_label)
	_order_rank_spin = _new_spin(trigger_box, "order rank (0 = no hint)", 0, 4294967295, _notify_changed)

	section.add_child(_label_heading("Conditions"))
	_conditions_list = _make_row_list("Add condition", _build_condition_row, _condition_row_to_data, _condition_row_from_data)
	_conditions_list.changed.connect(_notify_changed)
	section.add_child(_conditions_list)

	section.add_child(_label_heading("Presentation"))
	_presentation_mode_edit = _new_line_edit(section, "mode", _notify_changed)
	_presentation_background_edit = _new_line_edit(section, "background", _notify_changed)
	_presentation_bgm_edit = _new_line_edit(section, "bgm", _notify_changed)
	_presentation_characters_edit = _new_line_edit(section, "characters (comma-separated)", _notify_changed)
	_presentation_hud_edit = _new_line_edit(section, "hud", _notify_changed)
	_presentation_message_window_edit = _new_line_edit(section, "message_window", _notify_changed)

	section.add_child(_label_heading("Dialogue"))
	_dialogue_list = _make_row_list("Add dialogue entry", _build_dialogue_row, _dialogue_row_to_data, _dialogue_row_from_data)
	_dialogue_list.changed.connect(_notify_changed)
	section.add_child(_dialogue_list)

	section.add_child(_label_heading("After"))
	_after_list = _make_row_list("Add effect", _build_effect_row, _effect_row_to_data, _effect_row_from_data)
	_after_list.changed.connect(_notify_changed)
	section.add_child(_after_list)

	section.add_child(_label_heading("Result"))
	section.add_child(_label_heading("Result dialogue"))
	_result_dialogue_list = _make_row_list("Add dialogue entry", _build_dialogue_row, _dialogue_row_to_data, _dialogue_row_from_data)
	_result_dialogue_list.changed.connect(_notify_changed)
	section.add_child(_result_dialogue_list)
	section.add_child(_label_heading("Result after"))
	_result_after_list = _make_row_list("Add effect", _build_effect_row, _effect_row_to_data, _effect_row_from_data)
	_result_after_list.changed.connect(_notify_changed)
	section.add_child(_result_after_list)
	var terminal_row := HBoxContainer.new()
	section.add_child(terminal_row)
	_terminal_option = _new_option(terminal_row, "terminal", TERMINAL_KINDS, _notify_changed)

	section.add_child(_label_heading("Done cell"))
	var done_row := HBoxContainer.new()
	section.add_child(done_row)
	_done_storage_option = _new_option(done_row, "storage", STORAGES, _notify_changed)
	_done_bank_spin = _new_spin(done_row, "bank", 0, 4294967295, _notify_changed)
	_done_index_spin = _new_spin(done_row, "index", 0, 4294967295, _notify_changed)
	_done_value_spin = _new_spin(done_row, "value", -2147483648, 2147483647, _notify_changed)
	_done_unset_check = _new_check_button(done_row, "unset", _notify_changed)
	_done_unset_check.button_pressed = true

	return section


func _build_override_section(root: VBoxContainer) -> Control:
	var section := VBoxContainer.new()
	root.add_child(section)

	section.add_child(_label_heading("Target"))
	var target_row := HBoxContainer.new()
	section.add_child(target_row)
	_target_id_label = Label.new()
	target_row.add_child(_target_id_label)
	_target_sha_label = Label.new()
	target_row.add_child(_target_sha_label)
	_rebase_button = Button.new()
	_rebase_button.text = "Rebase"
	_rebase_button.pressed.connect(_on_rebase_pressed)
	target_row.add_child(_rebase_button)

	section.add_child(_label_heading("Operations"))
	_operations_list = _make_row_list("Add operation", _build_operation_row, _operation_row_to_data, _operation_row_from_data)
	_operations_list.changed.connect(_notify_changed)
	section.add_child(_operations_list)

	return section


func _label_heading(text: String) -> Label:
	var label := Label.new()
	label.text = text
	return label


# ---------------------------------------------------------------------------
# Small control builders
# ---------------------------------------------------------------------------


func _new_line_edit(parent: Node, placeholder: String, notify: Callable) -> LineEdit:
	var edit := LineEdit.new()
	edit.placeholder_text = placeholder
	edit.custom_minimum_size.x = 140
	edit.text_changed.connect(func(_t: String) -> void: notify.call())
	parent.add_child(edit)
	return edit


func _new_spin(parent: Node, label_text: String, min_value: float, max_value: float, notify: Callable) -> SpinBox:
	var box := HBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	box.add_child(label)
	var spin := SpinBox.new()
	spin.min_value = min_value
	spin.max_value = max_value
	spin.step = 1
	spin.allow_greater = false
	spin.allow_lesser = false
	spin.value_changed.connect(func(_v: float) -> void: notify.call())
	box.add_child(spin)
	parent.add_child(box)
	return spin


func _new_option(parent: Node, label_text: String, options: Array, notify: Callable) -> OptionButton:
	var box := HBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	box.add_child(label)
	var option := OptionButton.new()
	for value in options:
		option.add_item(str(value))
	option.item_selected.connect(func(_i: int) -> void: notify.call())
	box.add_child(option)
	parent.add_child(box)
	return option


func _new_check_button(parent: Node, label_text: String, notify: Callable) -> CheckButton:
	var check := CheckButton.new()
	check.text = label_text
	check.toggled.connect(func(_b: bool) -> void: notify.call())
	parent.add_child(check)
	return check


func _make_row_list(add_label_text: String, build_row_fn: Callable, to_data_fn: Callable, from_data_fn: Callable) -> KakyuModDefinitionRowList:
	var list := KakyuModDefinitionRowList.new()
	list.add_label = add_label_text
	list.build_row = build_row_fn
	list.row_to_data = to_data_fn
	list.row_from_data = from_data_fn
	return list


# ---------------------------------------------------------------------------
# Condition rows
# ---------------------------------------------------------------------------


func _build_condition_row(row: HFlowContainer, notify: Callable) -> void:
	var type_option := OptionButton.new()
	for type_name in CONDITION_TYPES:
		type_option.add_item(type_name)
	row.add_child(type_option)
	row.set_meta("kind_option", type_option)
	var fields_box := HFlowContainer.new()
	row.add_child(fields_box)
	row.set_meta("fields_box", fields_box)
	row.set_meta("notify", notify)
	var failure_edit := LineEdit.new()
	failure_edit.placeholder_text = "failure_reason"
	failure_edit.custom_minimum_size.x = 140
	failure_edit.text_changed.connect(func(_t: String) -> void: notify.call())
	row.add_child(failure_edit)
	row.set_meta("failure_reason_edit", failure_edit)
	type_option.item_selected.connect(func(index: int) -> void:
		_rebuild_condition_fields(row, CONDITION_TYPES[index])
		notify.call()
	)
	_rebuild_condition_fields(row, CONDITION_TYPES[0])


func _rebuild_condition_fields(row: HFlowContainer, type_name: String) -> void:
	var fields_box: HFlowContainer = row.get_meta("fields_box")
	for child in fields_box.get_children():
		child.queue_free()
	row.remove_meta("cell_class_label")
	row.remove_meta("cell_key_getter")
	var notify: Callable = row.get_meta("notify")
	match type_name:
		"always":
			pass
		"event_not_completed", "event_completed":
			row.set_meta("event_id_edit", _new_line_edit(fields_box, "event_id", notify))
		"flag_equals":
			row.set_meta("name_edit", _new_line_edit(fields_box, "name", notify))
			row.set_meta("value_check", _new_check_button(fields_box, "value", notify))
		"weekday_equals":
			row.set_meta("weekday_spin", _new_spin(fields_box, "weekday", 0, 6, notify))
		"date_equals":
			row.set_meta("date_spin", _new_spin(fields_box, "date_code", 101, 1231, notify))
		"date_in_range":
			row.set_meta("from_spin", _new_spin(fields_box, "from_date_code", 101, 1231, notify))
			row.set_meta("to_spin", _new_spin(fields_box, "to_date_code", 101, 1231, notify))
		"time_at_or_after", "time_before":
			row.set_meta("time_spin", _new_spin(fields_box, "time_code", 0, 2359, notify))
		"legacy_cell":
			var storage_option := _new_option(fields_box, "storage", STORAGES, notify)
			row.set_meta("storage_option", storage_option)
			var bank_spin := _new_spin(fields_box, "bank", 0, 4294967295, notify)
			row.set_meta("bank_spin", bank_spin)
			var index_spin := _new_spin(fields_box, "index", 0, 4294967295, notify)
			row.set_meta("index_spin", index_spin)
			var value_spin := _new_spin(fields_box, "value", -2147483648, 2147483647, notify)
			row.set_meta("value_spin", value_spin)
			row.set_meta("operator_option", _new_option(fields_box, "operator", OPERATORS, notify))
			var class_label := Label.new()
			class_label.text = "cell_class: "
			fields_box.add_child(class_label)
			row.set_meta("cell_class_label", class_label)
			row.set_meta("cell_key_getter", func() -> Dictionary:
				return {
					"storage": STORAGES[storage_option.selected],
					"bank": int(bank_spin.value),
					"index": int(index_spin.value),
				}
			)
		"mes_expression":
			var ast_edit := TextEdit.new()
			ast_edit.custom_minimum_size = Vector2(220, 60)
			ast_edit.text = "{}"
			row.set_meta("last_valid_ast", {})
			ast_edit.text_changed.connect(func() -> void: notify.call())
			fields_box.add_child(ast_edit)
			row.set_meta("ast_edit", ast_edit)


func _condition_row_to_data(row: HFlowContainer) -> Dictionary:
	var type_option: OptionButton = row.get_meta("kind_option")
	var type_name: String = CONDITION_TYPES[type_option.selected]
	var data := {"type": type_name}
	match type_name:
		"always":
			pass
		"event_not_completed", "event_completed":
			var event_id: String = (row.get_meta("event_id_edit") as LineEdit).text.strip_edges()
			if not event_id.is_empty():
				data["event_id"] = event_id
		"flag_equals":
			data["name"] = (row.get_meta("name_edit") as LineEdit).text.strip_edges()
			data["value"] = (row.get_meta("value_check") as CheckButton).button_pressed
		"weekday_equals":
			data["weekday"] = int((row.get_meta("weekday_spin") as SpinBox).value)
		"date_equals":
			data["date_code"] = int((row.get_meta("date_spin") as SpinBox).value)
		"date_in_range":
			data["from_date_code"] = int((row.get_meta("from_spin") as SpinBox).value)
			data["to_date_code"] = int((row.get_meta("to_spin") as SpinBox).value)
		"time_at_or_after", "time_before":
			data["time_code"] = int((row.get_meta("time_spin") as SpinBox).value)
		"legacy_cell":
			data["storage"] = STORAGES[(row.get_meta("storage_option") as OptionButton).selected]
			data["bank"] = int((row.get_meta("bank_spin") as SpinBox).value)
			data["index"] = int((row.get_meta("index_spin") as SpinBox).value)
			data["operator"] = OPERATORS[(row.get_meta("operator_option") as OptionButton).selected]
			data["value"] = int((row.get_meta("value_spin") as SpinBox).value)
		"mes_expression":
			var ast_edit: TextEdit = row.get_meta("ast_edit")
			var parsed: Variant = JSON.parse_string(ast_edit.text)
			if parsed is Dictionary and not (parsed as Dictionary).is_empty():
				row.set_meta("last_valid_ast", ContractValues.intify(parsed))
			data["ast"] = row.get_meta("last_valid_ast", {})
	var failure_reason: String = (row.get_meta("failure_reason_edit") as LineEdit).text.strip_edges()
	if not failure_reason.is_empty():
		data["failure_reason"] = failure_reason
	return data


func _condition_row_from_data(row: HFlowContainer, data: Dictionary) -> void:
	var type_name := str(data.get("type", "always"))
	var type_index := maxi(0, CONDITION_TYPES.find(type_name))
	(row.get_meta("kind_option") as OptionButton).select(type_index)
	_rebuild_condition_fields(row, CONDITION_TYPES[type_index])
	match CONDITION_TYPES[type_index]:
		"event_not_completed", "event_completed":
			(row.get_meta("event_id_edit") as LineEdit).text = str(data.get("event_id", ""))
		"flag_equals":
			(row.get_meta("name_edit") as LineEdit).text = str(data.get("name", ""))
			(row.get_meta("value_check") as CheckButton).button_pressed = bool(data.get("value", false))
		"weekday_equals":
			(row.get_meta("weekday_spin") as SpinBox).value = int(data.get("weekday", 0))
		"date_equals":
			(row.get_meta("date_spin") as SpinBox).value = int(data.get("date_code", 101))
		"date_in_range":
			(row.get_meta("from_spin") as SpinBox).value = int(data.get("from_date_code", 101))
			(row.get_meta("to_spin") as SpinBox).value = int(data.get("to_date_code", 101))
		"time_at_or_after", "time_before":
			(row.get_meta("time_spin") as SpinBox).value = int(data.get("time_code", 0))
		"legacy_cell":
			(row.get_meta("storage_option") as OptionButton).select(maxi(0, STORAGES.find(str(data.get("storage", "global_u8")))))
			(row.get_meta("bank_spin") as SpinBox).value = int(data.get("bank", 0))
			(row.get_meta("index_spin") as SpinBox).value = int(data.get("index", 0))
			(row.get_meta("value_spin") as SpinBox).value = int(data.get("value", 0))
			(row.get_meta("operator_option") as OptionButton).select(maxi(0, OPERATORS.find(str(data.get("operator", "equal")))))
		"mes_expression":
			var ast: Dictionary = data.get("ast", {})
			row.set_meta("last_valid_ast", ast)
			(row.get_meta("ast_edit") as TextEdit).text = JSON.stringify(ast)
	(row.get_meta("failure_reason_edit") as LineEdit).text = str(data.get("failure_reason", ""))
	_refresh_cell_class_labels()


# ---------------------------------------------------------------------------
# Effect rows
# ---------------------------------------------------------------------------


func _build_effect_row(row: HFlowContainer, notify: Callable) -> void:
	var type_option := OptionButton.new()
	for type_name in EFFECT_TYPES:
		type_option.add_item(type_name)
	row.add_child(type_option)
	row.set_meta("kind_option", type_option)
	var fields_box := HFlowContainer.new()
	row.add_child(fields_box)
	row.set_meta("fields_box", fields_box)
	row.set_meta("notify", notify)
	type_option.item_selected.connect(func(index: int) -> void:
		_rebuild_effect_fields(row, EFFECT_TYPES[index])
		notify.call()
	)
	_rebuild_effect_fields(row, EFFECT_TYPES[0])


func _rebuild_effect_fields(row: HFlowContainer, type_name: String) -> void:
	var fields_box: HFlowContainer = row.get_meta("fields_box")
	for child in fields_box.get_children():
		child.queue_free()
	row.remove_meta("cell_class_label")
	row.remove_meta("cell_key_getter")
	var notify: Callable = row.get_meta("notify")
	match type_name:
		"write_legacy_value":
			var storage_option := _new_option(fields_box, "storage", STORAGES, notify)
			row.set_meta("storage_option", storage_option)
			var bank_spin := _new_spin(fields_box, "bank", 0, 4294967295, notify)
			row.set_meta("bank_spin", bank_spin)
			var index_spin := _new_spin(fields_box, "index", 0, 4294967295, notify)
			row.set_meta("index_spin", index_spin)
			row.set_meta("value_spin", _new_spin(fields_box, "value", -2147483648, 2147483647, notify))
			var class_label := Label.new()
			class_label.text = "cell_class: "
			fields_box.add_child(class_label)
			row.set_meta("cell_class_label", class_label)
			row.set_meta("cell_key_getter", func() -> Dictionary:
				return {"storage": STORAGES[storage_option.selected], "bank": int(bank_spin.value), "index": int(index_spin.value)}
			)
		"add_legacy_value":
			var storage_option2 := _new_option(fields_box, "storage", STORAGES, notify)
			row.set_meta("storage_option", storage_option2)
			var bank_spin2 := _new_spin(fields_box, "bank", 0, 4294967295, notify)
			row.set_meta("bank_spin", bank_spin2)
			var index_spin2 := _new_spin(fields_box, "index", 0, 4294967295, notify)
			row.set_meta("index_spin", index_spin2)
			row.set_meta("delta_spin", _new_spin(fields_box, "delta", -2147483648, 2147483647, notify))
			var min_unset := _new_check_button(fields_box, "min unset", notify)
			min_unset.button_pressed = true
			row.set_meta("min_unset_check", min_unset)
			row.set_meta("min_spin", _new_spin(fields_box, "min", -2147483648, 2147483647, notify))
			var max_unset := _new_check_button(fields_box, "max unset", notify)
			max_unset.button_pressed = true
			row.set_meta("max_unset_check", max_unset)
			row.set_meta("max_spin", _new_spin(fields_box, "max", -2147483648, 2147483647, notify))
			var class_label2 := Label.new()
			class_label2.text = "cell_class: "
			fields_box.add_child(class_label2)
			row.set_meta("cell_class_label", class_label2)
			row.set_meta("cell_key_getter", func() -> Dictionary:
				return {"storage": STORAGES[storage_option2.selected], "bank": int(bank_spin2.value), "index": int(index_spin2.value)}
			)
		"consume_time":
			row.set_meta("minutes_spin", _new_spin(fields_box, "minutes", 1, 4294967295, notify))
		"set_flag":
			var name_edit := _new_line_edit(fields_box, "name", notify)
			name_edit.text = "mod.%s." % _mod_id
			row.set_meta("name_edit", name_edit)
			row.set_meta("value_check", _new_check_button(fields_box, "value", notify))


func _effect_row_to_data(row: HFlowContainer) -> Dictionary:
	var type_option: OptionButton = row.get_meta("kind_option")
	var type_name: String = EFFECT_TYPES[type_option.selected]
	var data := {"type": type_name}
	match type_name:
		"write_legacy_value":
			data["storage"] = STORAGES[(row.get_meta("storage_option") as OptionButton).selected]
			data["bank"] = int((row.get_meta("bank_spin") as SpinBox).value)
			data["index"] = int((row.get_meta("index_spin") as SpinBox).value)
			data["value"] = int((row.get_meta("value_spin") as SpinBox).value)
		"add_legacy_value":
			data["storage"] = STORAGES[(row.get_meta("storage_option") as OptionButton).selected]
			data["bank"] = int((row.get_meta("bank_spin") as SpinBox).value)
			data["index"] = int((row.get_meta("index_spin") as SpinBox).value)
			data["delta"] = int((row.get_meta("delta_spin") as SpinBox).value)
			if not (row.get_meta("min_unset_check") as CheckButton).button_pressed:
				data["min"] = int((row.get_meta("min_spin") as SpinBox).value)
			if not (row.get_meta("max_unset_check") as CheckButton).button_pressed:
				data["max"] = int((row.get_meta("max_spin") as SpinBox).value)
		"consume_time":
			data["minutes"] = int((row.get_meta("minutes_spin") as SpinBox).value)
			data["cell_class"] = "clock"
		"set_flag":
			data["name"] = (row.get_meta("name_edit") as LineEdit).text.strip_edges()
			data["value"] = (row.get_meta("value_check") as CheckButton).button_pressed
	return data


func _effect_row_from_data(row: HFlowContainer, data: Dictionary) -> void:
	var type_name := str(data.get("type", "write_legacy_value"))
	var type_index := maxi(0, EFFECT_TYPES.find(type_name))
	(row.get_meta("kind_option") as OptionButton).select(type_index)
	_rebuild_effect_fields(row, EFFECT_TYPES[type_index])
	match EFFECT_TYPES[type_index]:
		"write_legacy_value":
			(row.get_meta("storage_option") as OptionButton).select(maxi(0, STORAGES.find(str(data.get("storage", "global_u8")))))
			(row.get_meta("bank_spin") as SpinBox).value = int(data.get("bank", 0))
			(row.get_meta("index_spin") as SpinBox).value = int(data.get("index", 0))
			(row.get_meta("value_spin") as SpinBox).value = int(data.get("value", 0))
		"add_legacy_value":
			(row.get_meta("storage_option") as OptionButton).select(maxi(0, STORAGES.find(str(data.get("storage", "global_u8")))))
			(row.get_meta("bank_spin") as SpinBox).value = int(data.get("bank", 0))
			(row.get_meta("index_spin") as SpinBox).value = int(data.get("index", 0))
			(row.get_meta("delta_spin") as SpinBox).value = int(data.get("delta", 1))
			var has_min: bool = data.has("min")
			(row.get_meta("min_unset_check") as CheckButton).button_pressed = not has_min
			if has_min:
				(row.get_meta("min_spin") as SpinBox).value = int(data.get("min"))
			var has_max: bool = data.has("max")
			(row.get_meta("max_unset_check") as CheckButton).button_pressed = not has_max
			if has_max:
				(row.get_meta("max_spin") as SpinBox).value = int(data.get("max"))
		"consume_time":
			(row.get_meta("minutes_spin") as SpinBox).value = int(data.get("minutes", 1))
		"set_flag":
			(row.get_meta("name_edit") as LineEdit).text = str(data.get("name", ""))
			(row.get_meta("value_check") as CheckButton).button_pressed = bool(data.get("value", false))
	_refresh_cell_class_labels()


# ---------------------------------------------------------------------------
# Dialogue rows
# ---------------------------------------------------------------------------


func _build_dialogue_row(row: HFlowContainer, notify: Callable) -> void:
	var type_option := OptionButton.new()
	for kind_name in DIALOGUE_KINDS:
		type_option.add_item(kind_name)
	row.add_child(type_option)
	row.set_meta("kind_option", type_option)
	var fields_box := HFlowContainer.new()
	row.add_child(fields_box)
	row.set_meta("fields_box", fields_box)
	row.set_meta("notify", notify)
	type_option.item_selected.connect(func(index: int) -> void:
		_rebuild_dialogue_fields(row, DIALOGUE_KINDS[index])
		notify.call()
	)
	_rebuild_dialogue_fields(row, DIALOGUE_KINDS[0])


func _rebuild_dialogue_fields(row: HFlowContainer, kind_name: String) -> void:
	var fields_box: HFlowContainer = row.get_meta("fields_box")
	for child in fields_box.get_children():
		child.queue_free()
	var notify: Callable = row.get_meta("notify")
	match kind_name:
		"line":
			row.set_meta("speaker_edit", _new_line_edit(fields_box, "speaker", notify))
			row.set_meta("voice_edit", _new_line_edit(fields_box, "voice", notify))
			var text_edit := TextEdit.new()
			text_edit.custom_minimum_size = Vector2(260, 60)
			text_edit.text_changed.connect(func() -> void: notify.call())
			fields_box.add_child(text_edit)
			row.set_meta("text_edit", text_edit)
		"choice_point":
			row.set_meta("choice_edit", _new_line_edit(fields_box, "choice (top or a result id)", notify))
		"scene_end":
			pass


func _dialogue_row_to_data(row: HFlowContainer) -> Dictionary:
	var type_option: OptionButton = row.get_meta("kind_option")
	var kind_name: String = DIALOGUE_KINDS[type_option.selected]
	var data := {"kind": kind_name}
	match kind_name:
		"line":
			data["text"] = (row.get_meta("text_edit") as TextEdit).text
			var speaker: String = (row.get_meta("speaker_edit") as LineEdit).text.strip_edges()
			if not speaker.is_empty():
				data["speaker"] = speaker
			var voice: String = (row.get_meta("voice_edit") as LineEdit).text.strip_edges()
			if not voice.is_empty():
				data["voice"] = voice
		"choice_point":
			data["choice"] = (row.get_meta("choice_edit") as LineEdit).text.strip_edges()
		"scene_end":
			pass
	return data


func _dialogue_row_from_data(row: HFlowContainer, data: Dictionary) -> void:
	var kind_name := str(data.get("kind", "line"))
	var kind_index := maxi(0, DIALOGUE_KINDS.find(kind_name))
	(row.get_meta("kind_option") as OptionButton).select(kind_index)
	_rebuild_dialogue_fields(row, DIALOGUE_KINDS[kind_index])
	match DIALOGUE_KINDS[kind_index]:
		"line":
			(row.get_meta("text_edit") as TextEdit).text = str(data.get("text", ""))
			(row.get_meta("speaker_edit") as LineEdit).text = str(data.get("speaker", ""))
			(row.get_meta("voice_edit") as LineEdit).text = str(data.get("voice", ""))
		"choice_point":
			(row.get_meta("choice_edit") as LineEdit).text = str(data.get("choice", ""))
		"scene_end":
			pass


# ---------------------------------------------------------------------------
# Override operation rows
# ---------------------------------------------------------------------------


func _build_operation_row(row: HFlowContainer, notify: Callable) -> void:
	var type_option := OptionButton.new()
	for op_name in OPERATION_KINDS:
		type_option.add_item(op_name)
	row.add_child(type_option)
	row.set_meta("kind_option", type_option)
	var fields_box := VBoxContainer.new()
	row.add_child(fields_box)
	row.set_meta("fields_box", fields_box)
	row.set_meta("notify", notify)
	type_option.item_selected.connect(func(index: int) -> void:
		_rebuild_operation_fields(row, OPERATION_KINDS[index])
		notify.call()
	)
	_rebuild_operation_fields(row, OPERATION_KINDS[0])


func _rebuild_operation_fields(row: HFlowContainer, op_name: String) -> void:
	var fields_box: VBoxContainer = row.get_meta("fields_box")
	for child in fields_box.get_children():
		child.queue_free()
	row.remove_meta("conditions_list")
	row.remove_meta("effects_list")
	var notify: Callable = row.get_meta("notify")
	match op_name:
		"replace_conditions":
			var conditions_list := _make_row_list("Add condition", _build_condition_row, _condition_row_to_data, _condition_row_from_data)
			conditions_list.changed.connect(func() -> void: notify.call())
			fields_box.add_child(conditions_list)
			row.set_meta("conditions_list", conditions_list)
		"replace_after":
			row.set_meta("scope_edit", _new_line_edit(fields_box, "scope (body or a result id)", notify))
			var effects_list := _make_row_list("Add effect", _build_effect_row, _effect_row_to_data, _effect_row_from_data)
			effects_list.changed.connect(func() -> void: notify.call())
			fields_box.add_child(effects_list)
			row.set_meta("effects_list", effects_list)
		"replace_order_hint":
			row.set_meta("rank_spin", _new_spin(fields_box, "rank", 1, 4294967295, notify))
		"disable":
			pass


func _operation_row_to_data(row: HFlowContainer) -> Dictionary:
	var type_option: OptionButton = row.get_meta("kind_option")
	var op_name: String = OPERATION_KINDS[type_option.selected]
	var data := {"op": op_name}
	match op_name:
		"replace_conditions":
			data["conditions"] = (row.get_meta("conditions_list") as KakyuModDefinitionRowList).get_data()
		"replace_after":
			data["scope"] = (row.get_meta("scope_edit") as LineEdit).text.strip_edges()
			data["after"] = (row.get_meta("effects_list") as KakyuModDefinitionRowList).get_data()
		"replace_order_hint":
			data["rank"] = int((row.get_meta("rank_spin") as SpinBox).value)
		"disable":
			pass
	return data


func _operation_row_from_data(row: HFlowContainer, data: Dictionary) -> void:
	var op_name := str(data.get("op", "disable"))
	var op_index := maxi(0, OPERATION_KINDS.find(op_name))
	(row.get_meta("kind_option") as OptionButton).select(op_index)
	_rebuild_operation_fields(row, OPERATION_KINDS[op_index])
	match OPERATION_KINDS[op_index]:
		"replace_conditions":
			var conditions_list: KakyuModDefinitionRowList = row.get_meta("conditions_list")
			for condition_data in data.get("conditions", []):
				conditions_list.add_row(condition_data)
		"replace_after":
			(row.get_meta("scope_edit") as LineEdit).text = str(data.get("scope", "body"))
			var effects_list: KakyuModDefinitionRowList = row.get_meta("effects_list")
			for effect_data in data.get("after", []):
				effects_list.add_row(effect_data)
		"replace_order_hint":
			(row.get_meta("rank_spin") as SpinBox).value = int(data.get("rank", 1))
		"disable":
			pass


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------


func set_heroines(names: PackedStringArray) -> void:
	_heroines = names
	var previous := _selected_heroine()
	_heroine_option.clear()
	_heroine_option.add_item("(none)")
	for name in names:
		_heroine_option.add_item(name)
	_select_heroine(previous)


func set_mod_id(mod_id: String, editable: bool) -> void:
	_mod_id = mod_id
	_mod_id_editable = editable
	_mod_id_edit.text = mod_id
	_mod_id_edit.editable = editable


## `{ok: true}` when the form can show `document`, else `{ok: false, reason}`
## naming the first feature it does not cover (section C).
func load_document(document: Dictionary) -> Dictionary:
	_suppress_changed = true
	var kind := str(document.get("kind", ""))
	var outcome: Dictionary
	if kind != "new_event" and kind != "override":
		outcome = {"ok": false, "reason": "kind %s is not new_event or override" % kind}
	elif kind == "new_event":
		outcome = _check_new_event_covered(document)
	else:
		outcome = _check_override_covered(document)

	if not outcome.get("ok", false):
		_set_reason(str(outcome.get("reason", "")))
		_set_editors_enabled(false)
		_suppress_changed = false
		return outcome

	_kind = kind
	_set_reason("")
	_contract_fingerprint = str(document.get("contract_fingerprint", "self"))
	_cells_fingerprint = str(document.get("cells_fingerprint", "self"))
	if kind == "new_event":
		_populate_new_event(document)
	else:
		_populate_override(document)
	_apply_kind_visibility()
	_set_editors_enabled(true)
	_suppress_changed = false
	_refresh_cell_class_labels()
	return {"ok": true}


## The document the form's fields describe (section B/B3).
func to_document() -> Dictionary:
	var document: Dictionary = _build_new_event_document() if _kind == "new_event" else _build_override_document()
	var observed := {}
	_apply_cell_classes(document, observed)
	return document


func _check_new_event_covered(document: Dictionary) -> Dictionary:
	if document.has("choice"):
		return {"ok": false, "reason": "a top-level choice is not covered"}
	var results: Dictionary = document.get("results", {})
	if results.size() != 1:
		return {"ok": false, "reason": "more than one result is not covered"}
	var only_result: Dictionary = results.values()[0]
	var selected_by: Dictionary = only_result.get("selected_by", {})
	if str(selected_by.get("kind", "")) != "default":
		return {"ok": false, "reason": "a result selected by something other than default is not covered"}
	if only_result.has("choice") or only_result.has("results"):
		return {"ok": false, "reason": "a nested choice or results is not covered"}
	var terminals: Dictionary = document.get("terminals", {})
	if terminals.size() != 1:
		return {"ok": false, "reason": "terminals with more than one entry is not covered"}
	return {"ok": true}


func _check_override_covered(document: Dictionary) -> Dictionary:
	var operations: Array = document.get("operations", [])
	for untyped_op in operations:
		var op: Dictionary = untyped_op
		var op_name := str(op.get("op", ""))
		if not op_name in OPERATION_KINDS:
			return {"ok": false, "reason": "an operation of kind %s is not covered" % op_name}
	return {"ok": true}


func _set_reason(text: String) -> void:
	_header_reason_label.text = text


func _set_editors_enabled(enabled: bool) -> void:
	_mod_id_edit.editable = enabled and _mod_id_editable
	_name_edit.editable = enabled
	_revision_spin.editable = enabled
	_title_ko_edit.editable = enabled
	_title_en_edit.editable = enabled
	_heroine_option.disabled = not enabled
	_category_option.disabled = not enabled
	_place_edit.editable = enabled
	if not enabled:
		_new_event_section.visible = false
		_override_section.visible = false
		_clear_all_lists()
		_terminal_key = ""


func _apply_kind_visibility() -> void:
	_kind_label.text = _kind
	_new_event_section.visible = (_kind == "new_event")
	_override_section.visible = (_kind == "override")


func _clear_all_lists() -> void:
	_conditions_list.clear()
	_dialogue_list.clear()
	_after_list.clear()
	_result_dialogue_list.clear()
	_result_after_list.clear()
	_operations_list.clear()


func _name_from_id(doc_id: String) -> String:
	var parts := doc_id.split(".", true, 2)
	if parts.size() == 3:
		return parts[2]
	return ""


func _select_heroine(name: String) -> void:
	if name.is_empty():
		_heroine_option.select(0)
		return
	for i in range(_heroines.size()):
		if _heroines[i] == name:
			_heroine_option.select(i + 1)
			return
	_heroine_option.select(0)


func _selected_heroine() -> String:
	var index := _heroine_option.selected
	if index <= 0:
		return ""
	return _heroines[index - 1]


func _select_category(name: String) -> void:
	_category_option.select(maxi(0, CATEGORIES.find(name)))


# ---------------------------------------------------------------------------
# Loading a document into the controls
# ---------------------------------------------------------------------------


func _populate_new_event(document: Dictionary) -> void:
	_clear_all_lists()
	var mod: Dictionary = document.get("mod", {})
	_mod_id_edit.text = str(mod.get("id", _mod_id))
	_name_edit.text = _name_from_id(str(document.get("id", "")))
	_revision_spin.value = int(mod.get("revision", 1))
	var display: Dictionary = document.get("display", {})
	_title_ko_edit.text = str(display.get("title_ko", ""))
	_title_en_edit.text = str(display.get("title_en", ""))
	_select_heroine(str(display.get("heroine", "")))
	_select_category(str(display.get("category", "school")))
	_place_edit.text = str(display.get("place", ""))

	var trigger: Dictionary = document.get("trigger", {})
	_trigger_category_label.text = str(trigger.get("category", ""))
	_trigger_place_label.text = str(trigger.get("place", ""))
	var order_hint: Dictionary = trigger.get("order_hint", {})
	_order_rank_spin.value = int(order_hint.get("rank", 0))

	for condition_data in document.get("conditions", []):
		_conditions_list.add_row(condition_data)

	var presentation: Dictionary = document.get("presentation", {})
	_presentation_mode_edit.text = str(presentation.get("mode", ""))
	_presentation_background_edit.text = str(presentation.get("background", ""))
	_presentation_bgm_edit.text = str(presentation.get("bgm", ""))
	_presentation_hud_edit.text = str(presentation.get("hud", ""))
	_presentation_message_window_edit.text = str(presentation.get("message_window", ""))
	var characters: Array = presentation.get("characters", [])
	var character_strings := PackedStringArray()
	for character in characters:
		character_strings.append(str(character))
	_presentation_characters_edit.text = ", ".join(character_strings)

	for dialogue_data in document.get("dialogue", []):
		_dialogue_list.add_row(dialogue_data)
	for effect_data in document.get("after", []):
		_after_list.add_row(effect_data)

	var results: Dictionary = document.get("results", {})
	var only_result: Dictionary = results.values()[0] if not results.is_empty() else {}
	for dialogue_data in only_result.get("dialogue", []):
		_result_dialogue_list.add_row(dialogue_data)
	for effect_data in only_result.get("after", []):
		_result_after_list.add_row(effect_data)
	var terminal_id := str(only_result.get("terminal", ""))
	var terminals: Dictionary = document.get("terminals", {})
	var terminal_entry: Dictionary = terminals.get(terminal_id, {})
	var terminal_kind := str(terminal_entry.get("kind", "return_to_map"))
	_terminal_option.select(maxi(0, TERMINAL_KINDS.find(terminal_kind)))
	_terminal_key = terminal_id

	var done: Variant = document.get("done", null)
	if done is Dictionary and (done as Dictionary).has("cell"):
		var cell: Dictionary = (done as Dictionary).cell
		_done_unset_check.button_pressed = false
		_done_storage_option.select(maxi(0, STORAGES.find(str(cell.get("storage", "global_u8")))))
		_done_bank_spin.value = int(cell.get("bank", 0))
		_done_index_spin.value = int(cell.get("index", 0))
		_done_value_spin.value = int(cell.get("value", 0))
	else:
		_done_unset_check.button_pressed = true
		_done_storage_option.select(0)
		_done_bank_spin.value = 0
		_done_index_spin.value = 0
		_done_value_spin.value = 0


func _populate_override(document: Dictionary) -> void:
	_clear_all_lists()
	_terminal_key = ""
	var mod: Dictionary = document.get("mod", {})
	_mod_id_edit.text = str(mod.get("id", _mod_id))
	_name_edit.text = _name_from_id(str(document.get("id", "")))
	_revision_spin.value = int(mod.get("revision", 1))
	var display: Variant = document.get("display", null)
	if display is Dictionary:
		var display_dict: Dictionary = display
		_title_ko_edit.text = str(display_dict.get("title_ko", ""))
		_title_en_edit.text = str(display_dict.get("title_en", ""))
		_select_heroine(str(display_dict.get("heroine", "")))
		_select_category(str(display_dict.get("category", "school")))
		_place_edit.text = str(display_dict.get("place", ""))
	else:
		_title_ko_edit.text = ""
		_title_en_edit.text = ""
		_select_heroine("")
		_select_category("school")
		_place_edit.text = ""

	var target: Dictionary = document.get("target", {})
	_target_id_label.text = str(target.get("id", ""))
	_target_sha_label.text = str(target.get("document_sha256", ""))

	for op_data in document.get("operations", []):
		_operations_list.add_row(op_data)


# ---------------------------------------------------------------------------
# Assembling a document from the controls
# ---------------------------------------------------------------------------


func _build_display() -> Dictionary:
	var display := {
		"title_ko": _title_ko_edit.text,
		"title_en": _title_en_edit.text,
		"category": CATEGORIES[_category_option.selected],
		"place": _place_edit.text.strip_edges(),
	}
	var heroine := _selected_heroine()
	if not heroine.is_empty():
		display["heroine"] = heroine
	return display


func _build_override_display_or_null() -> Variant:
	var title_ko := _title_ko_edit.text
	var title_en := _title_en_edit.text
	var heroine := _selected_heroine()
	var place := _place_edit.text.strip_edges()
	if title_ko.is_empty() and title_en.is_empty() and heroine.is_empty() and place.is_empty():
		return null
	return _build_display()


func _build_presentation() -> Dictionary:
	var mode := _presentation_mode_edit.text.strip_edges()
	var background := _presentation_background_edit.text.strip_edges()
	var bgm := _presentation_bgm_edit.text.strip_edges()
	var hud := _presentation_hud_edit.text.strip_edges()
	var message_window := _presentation_message_window_edit.text.strip_edges()
	var characters: Array = []
	for part in _presentation_characters_edit.text.split(","):
		var trimmed: String = str(part).strip_edges()
		if not trimmed.is_empty():
			characters.append(trimmed)
	if mode.is_empty() and background.is_empty() and bgm.is_empty() and hud.is_empty() and message_window.is_empty() and characters.is_empty():
		return {}
	var presentation := {"mode": mode}
	if not background.is_empty():
		presentation["background"] = background
	if not bgm.is_empty():
		presentation["bgm"] = bgm
	if not characters.is_empty():
		presentation["characters"] = characters
	if not hud.is_empty():
		presentation["hud"] = hud
	if not message_window.is_empty():
		presentation["message_window"] = message_window
	return presentation


func _build_new_event_document() -> Dictionary:
	var document := {}
	document["schema_version"] = ContentCoreVersionScript.MOD_EVENT_DEFINITION_SCHEMA
	document["contract_fingerprint"] = _contract_fingerprint
	document["cells_fingerprint"] = _cells_fingerprint
	document["kind"] = "new_event"
	var mod_id := _mod_id_edit.text.strip_edges()
	document["mod"] = {"id": mod_id, "revision": int(_revision_spin.value)}
	document["id"] = "mod.%s.%s" % [mod_id, _name_edit.text.strip_edges()]
	document["display"] = _build_display()

	var category: String = CATEGORIES[_category_option.selected]
	var place := _place_edit.text.strip_edges()
	var trigger := {"type": "place", "category": category, "place": place}
	if int(_order_rank_spin.value) > 0:
		trigger["order_hint"] = {"rank": int(_order_rank_spin.value)}
	document["trigger"] = trigger

	document["conditions"] = _conditions_list.get_data()

	var presentation := _build_presentation()
	if not presentation.is_empty():
		document["presentation"] = presentation

	document["dialogue"] = _dialogue_list.get_data()
	document["after"] = _after_list.get_data()

	var terminal_kind: String = TERMINAL_KINDS[_terminal_option.selected]
	# The form keeps the terminal key it loaded (e.g. "term_return") even
	# when the terminal's kind changes; only a document the form has not
	# loaded a terminal from names the entry by kind ("map"/"caller").
	var terminal_key := _terminal_key if not _terminal_key.is_empty() else ("map" if terminal_kind == "return_to_map" else "caller")
	document["results"] = {
		"result_default": {
			"selected_by": {"kind": "default"},
			"event_played": true,
			"dialogue": _result_dialogue_list.get_data(),
			"after": _result_after_list.get_data(),
			"terminal": terminal_key,
		},
	}
	document["terminals"] = {terminal_key: {"kind": terminal_kind}}

	if not _done_unset_check.button_pressed:
		document["done"] = {
			"cell": {
				"storage": STORAGES[_done_storage_option.selected],
				"bank": int(_done_bank_spin.value),
				"index": int(_done_index_spin.value),
				"value": int(_done_value_spin.value),
			},
		}
	return document


func _build_override_document() -> Dictionary:
	var document := {}
	document["schema_version"] = ContentCoreVersionScript.MOD_EVENT_DEFINITION_SCHEMA
	document["contract_fingerprint"] = _contract_fingerprint
	document["cells_fingerprint"] = _cells_fingerprint
	document["kind"] = "override"
	var mod_id := _mod_id_edit.text.strip_edges()
	document["mod"] = {"id": mod_id, "revision": int(_revision_spin.value)}
	document["id"] = "mod.%s.%s" % [mod_id, _name_edit.text.strip_edges()]
	var display: Variant = _build_override_display_or_null()
	if display != null:
		document["display"] = display
	document["target"] = {
		"id": _target_id_label.text,
		"contract": "kakyu_event_definition/v4",
		"document_sha256": _target_sha_label.text,
	}
	document["operations"] = _operations_list.get_data()
	return document


# ---------------------------------------------------------------------------
# Observed values and cell classes (B3)
# ---------------------------------------------------------------------------


func _walk_observed(node: Variant, observed: Dictionary) -> void:
	if node is Dictionary:
		var dict: Dictionary = node
		var type_name := str(dict.get("type", ""))
		if type_name == "write_legacy_value" or type_name == "legacy_cell":
			_add_observed(observed, dict.get("storage"), dict.get("bank"), dict.get("index"), dict.get("value"))
		for key in dict:
			_walk_observed(dict[key], observed)
	elif node is Array:
		for item in node:
			_walk_observed(item, observed)


func _add_observed(observed: Dictionary, storage: Variant, bank: Variant, index: Variant, value: Variant) -> void:
	if typeof(storage) != TYPE_STRING or typeof(bank) != TYPE_INT or typeof(index) != TYPE_INT or typeof(value) != TYPE_INT:
		return
	var key := "%s|%d|%d" % [storage, bank, index]
	if not observed.has(key):
		observed[key] = []
	var values: Array = observed[key]
	if not values.has(value):
		values.append(value)


func _apply_cell_classes(document: Dictionary, observed: Dictionary) -> void:
	_walk_observed(document, observed)
	if document.has("done") and document.done is Dictionary and (document.done as Dictionary).has("cell"):
		var cell: Dictionary = (document.done as Dictionary).cell
		_add_observed(observed, cell.get("storage"), cell.get("bank"), cell.get("index"), cell.get("value"))
	_apply_cell_classes_walk(document, observed)


func _apply_cell_classes_walk(node: Variant, observed: Dictionary) -> void:
	if node is Dictionary:
		var dict: Dictionary = node
		var type_name := str(dict.get("type", ""))
		if type_name == "legacy_cell" or type_name == "write_legacy_value" or type_name == "add_legacy_value":
			var storage := str(dict.get("storage", ""))
			var bank := int(dict.get("bank", 0))
			var index := int(dict.get("index", 0))
			var key := "%s|%d|%d" % [storage, bank, index]
			dict["cell_class"] = StateCells.classify(storage, bank, index, observed.get(key, []))
		for key2 in dict:
			_apply_cell_classes_walk(dict[key2], observed)
	elif node is Array:
		for item in node:
			_apply_cell_classes_walk(item, observed)


func _refresh_cell_class_labels() -> void:
	if _conditions_list == null:
		return
	var document: Dictionary = _build_new_event_document() if _kind == "new_event" else _build_override_document()
	var observed := {}
	_walk_observed(document, observed)
	if document.has("done") and document.done is Dictionary and (document.done as Dictionary).has("cell"):
		var cell: Dictionary = (document.done as Dictionary).cell
		_add_observed(observed, cell.get("storage"), cell.get("bank"), cell.get("index"), cell.get("value"))
	for row in _all_rows_with_cell_class():
		var getter: Callable = row.get_meta("cell_key_getter")
		var key_data: Dictionary = getter.call()
		var storage := str(key_data.storage)
		var bank := int(key_data.bank)
		var index := int(key_data.index)
		var cell_key := "%s|%d|%d" % [storage, bank, index]
		var cls := StateCells.classify(storage, bank, index, observed.get(cell_key, []))
		(row.get_meta("cell_class_label") as Label).text = "cell_class: %s" % cls


func _all_rows_with_cell_class() -> Array:
	var rows: Array = []
	for list in [_conditions_list, _after_list, _result_after_list]:
		if list == null:
			continue
		for row in list.get_rows():
			if row.has_meta("cell_class_label"):
				rows.append(row)
	if _operations_list != null:
		for op_row in _operations_list.get_rows():
			if op_row.has_meta("conditions_list"):
				for row in (op_row.get_meta("conditions_list") as KakyuModDefinitionRowList).get_rows():
					if row.has_meta("cell_class_label"):
						rows.append(row)
			if op_row.has_meta("effects_list"):
				for row in (op_row.get_meta("effects_list") as KakyuModDefinitionRowList).get_rows():
					if row.has_meta("cell_class_label"):
						rows.append(row)
	return rows


func _notify_changed() -> void:
	if _suppress_changed:
		return
	_refresh_cell_class_labels()
	changed.emit()


# ---------------------------------------------------------------------------
# Override rebase
# ---------------------------------------------------------------------------


func _on_rebase_pressed() -> void:
	var target_id := _target_id_label.text
	if target_id.is_empty():
		return
	var path := "res://config/event_definitions/v4/%s.json" % target_id
	if not FileAccess.file_exists(path):
		return
	_target_sha_label.text = document_sha256_lf(path)
	_notify_changed()


## SHA-256 of a tracked file's bytes with every CRLF normalized to LF - the
## same rule `tools/validate_mod_event_definition.py`'s `document_sha256`
## uses (moved here from `mod_definition_panel.gd` so the form's Rebase
## button needs no Python round trip).
static func document_sha256_lf(res_path: String) -> String:
	var bytes := FileAccess.get_file_as_bytes(res_path)
	var normalized := PackedByteArray()
	normalized.resize(bytes.size())
	var write_index := 0
	var index := 0
	while index < bytes.size():
		if bytes[index] == 0x0D and index + 1 < bytes.size() and bytes[index + 1] == 0x0A:
			normalized[write_index] = 0x0A
			write_index += 1
			index += 2
		else:
			normalized[write_index] = bytes[index]
			write_index += 1
			index += 1
	normalized.resize(write_index)
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(normalized)
	return context.finish().hex_encode()


