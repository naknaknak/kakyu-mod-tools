class_name KakyuModDefinitionPanel
extends Control

## The MES Editor's Definitions panel (mod event definition unit D): lists
## the active named workspace's `kakyu_mod_event_definition/v1` documents,
## creates one from a `new_event` or `override` template, edits it as JSON
## text with the contract validator's verdict inline, saves it into the
## workspace through the editor's own staging Callables (which require the
## validator), removes one, and imports or exports a definition set. Built
## in code like `mes_authoring_panel.gd`; the panel never touches the
## editor's launch context or reader directly, only the three Callables the
## editor sets before adding it as a tab.

const OverlayPackageScript := preload("res://content_core/overlay_package.gd")
const ModDefinitionBindingScript := preload("res://tools/content_suite/mod_definition_binding.gd")
const ModDefinitionSetImportScript := preload("res://tools/content_suite/mod_definition_set_import.gd")
const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")
const ModDefinitionFormScript := preload("res://tools/content_suite/mod_definition_form.gd")
const ContractValues := preload("res://content_core/contract_values.gd")
const StateCellsScript := preload("res://content_core/state_cells.gd")

const DEFAULT_CONTRACT_FINGERPRINT_PATH := "res://config/contracts/mod_event_definition_v1/contract_fingerprint"
const DEFAULT_CELLS_FINGERPRINT_PATH := "res://config/contracts/state_cells_v1/cells_fingerprint"

var context_provider: Callable
var publish_definitions: Callable
var remove_definition: Callable

var _layout: VBoxContainer
var _tree: Tree
var _views: TabContainer
var _form: Control
var _text: TextEdit
var _switching_views := false
var _mod_id_edit: LineEdit
var _target_id_edit: LineEdit
var _new_event_button: Button
var _new_override_button: Button
var _validate_button: Button
var _save_button: Button
var _remove_button: Button
var _refresh_button: Button
var _import_set_button: Button
var _export_set_button: Button
var _replace_on_import: CheckButton
var _summary: RichTextLabel
var _import_set_dialog: FileDialog
var _export_set_dialog: FileDialog

var _context: Dictionary = {}
var _manifest: Dictionary = {}
var _selected_id := ""
var _status_line := ""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layout = VBoxContainer.new()
	_layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_layout)

	var top_row := HFlowContainer.new()
	_layout.add_child(top_row)
	_refresh_button = _button(top_row, "Refresh", _on_refresh_pressed)
	_mark_unique(_refresh_button, "RefreshButton")
	top_row.add_child(_label("Mod id"))
	_mod_id_edit = LineEdit.new()
	_mod_id_edit.custom_minimum_size.x = 160
	top_row.add_child(_mod_id_edit)
	_mark_unique(_mod_id_edit, "ModIdEdit")
	_new_event_button = _button(top_row, "New event", _on_new_event_pressed)
	_mark_unique(_new_event_button, "NewEventButton")
	top_row.add_child(_label("Target id"))
	_target_id_edit = LineEdit.new()
	_target_id_edit.custom_minimum_size.x = 220
	top_row.add_child(_target_id_edit)
	_mark_unique(_target_id_edit, "TargetIdEdit")
	_new_override_button = _button(top_row, "New override", _on_new_override_pressed)
	_mark_unique(_new_override_button, "NewOverrideButton")
	_import_set_button = _button(top_row, "Import set...", _on_import_set_pressed)
	_mark_unique(_import_set_button, "ImportSetButton")
	_replace_on_import = CheckButton.new()
	_replace_on_import.text = "Replace existing"
	top_row.add_child(_replace_on_import)
	_mark_unique(_replace_on_import, "ReplaceOnImport")
	_export_set_button = _button(top_row, "Export set...", _on_export_set_pressed)
	_mark_unique(_export_set_button, "ExportSetButton")

	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.custom_minimum_size.y = 220
	_layout.add_child(split)

	_tree = Tree.new()
	_tree.columns = 4
	_tree.column_titles_visible = true
	_tree.hide_root = true
	_tree.custom_minimum_size = Vector2(320, 200)
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for index in range(4):
		_tree.set_column_title(index, ["Id", "Kind", "Target or revision", "Hash prefix"][index])
	_tree.item_selected.connect(_on_tree_item_selected)
	split.add_child(_tree)
	_mark_unique(_tree, "DefinitionTree")

	var right := VBoxContainer.new()
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(right)

	_views = TabContainer.new()
	_views.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_views.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_views.custom_minimum_size = Vector2(360, 180)
	right.add_child(_views)
	_mark_unique(_views, "DefinitionViews")

	_form = ModDefinitionFormScript.new()
	_views.add_child(_form)
	_form.set_heroines(StateCellsScript.heroines())
	_form.changed.connect(_on_form_changed)
	_mark_unique(_form, "DefinitionForm")
	_views.set_tab_title(_views.get_tab_idx_from_control(_form), "Form")

	_text = TextEdit.new()
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.custom_minimum_size = Vector2(360, 180)
	_text.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_views.add_child(_text)
	_mark_unique(_text, "DefinitionText")
	_views.set_tab_title(_views.get_tab_idx_from_control(_text), "JSON")
	_views.tab_changed.connect(_on_view_tab_changed)

	var actions_row := HBoxContainer.new()
	right.add_child(actions_row)
	_validate_button = _button(actions_row, "Validate", _on_validate_pressed)
	_mark_unique(_validate_button, "ValidateButton")
	_save_button = _button(actions_row, "Save", _on_save_pressed)
	_mark_unique(_save_button, "SaveButton")
	_remove_button = _button(actions_row, "Remove", _on_remove_pressed)
	_mark_unique(_remove_button, "RemoveButton")

	_summary = RichTextLabel.new()
	_summary.custom_minimum_size.y = 90
	_summary.selection_enabled = true
	_layout.add_child(_summary)
	_mark_unique(_summary, "DefinitionSummary")

	_import_set_dialog = FileDialog.new()
	_import_set_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_import_set_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_import_set_dialog.filters = PackedStringArray(["*.json ; Mod definition set"])
	_import_set_dialog.title = "Import a mod definition set"
	_import_set_dialog.file_selected.connect(_on_import_set_path_selected)
	add_child(_import_set_dialog)
	_mark_unique(_import_set_dialog, "ImportSetDialog")

	_export_set_dialog = FileDialog.new()
	_export_set_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_export_set_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_export_set_dialog.filters = PackedStringArray(["*.json ; Mod definition set"])
	_export_set_dialog.title = "Export a mod definition set"
	_export_set_dialog.file_selected.connect(_on_export_set_path_selected)
	add_child(_export_set_dialog)
	_mark_unique(_export_set_dialog, "ExportSetDialog")

	_set_controls_enabled(false)
	refresh()


func refresh() -> void:
	var outcome := _do_refresh()
	_status_line = str(outcome.status)
	if _context.get("ok", false) and not _selected_id.is_empty():
		var still_present := false
		for untyped_record in _manifest.get("definitions", []):
			if str((untyped_record as Dictionary).get("definition_id", "")) == _selected_id:
				still_present = true
				break
		if still_present:
			_select_tree_row(_selected_id)
		else:
			_selected_id = ""
			_text.text = ""
	_render_summary()


func _on_refresh_pressed() -> void:
	refresh()


## Reloads the workspace context and manifest, rebuilds the tree and the
## mod id field, without touching `_status_line` (callers compose their own
## outcome message and call this to keep the rest of the panel in sync).
func _do_refresh() -> Dictionary:
	var start := Time.get_ticks_msec()
	var current: Dictionary = (
		context_provider.call() if context_provider.is_valid()
		else {"ok": false, "error": "Definitions panel has no context provider."}
	)
	_context = current.duplicate(true) if current is Dictionary else {"ok": false, "error": "Definitions context is invalid."}
	if not _context.get("ok", false):
		_manifest = {}
		_tree.clear()
		_selected_id = ""
		_text.text = ""
		_set_controls_enabled(false)
		return {"ok": false, "status": str(_context.get("error", "No active workspace."))}
	var loaded := OverlayPackageScript.new().load_manifest(str(_context.workspace))
	var elapsed := Time.get_ticks_msec() - start
	if not loaded.get("ok", false):
		_manifest = {}
		_tree.clear()
		_set_controls_enabled(false)
		return {
			"ok": false,
			"status": "Manifest could not be loaded: %s (%d ms)" % [str(loaded.get("error", "")), elapsed],
		}
	_manifest = loaded.manifest
	_set_controls_enabled(true)
	_populate_tree()
	var definitions: Array = _manifest.get("definitions", [])
	if definitions.is_empty():
		_mod_id_edit.editable = true
		if _mod_id_edit.text.strip_edges().is_empty():
			_mod_id_edit.text = _derived_mod_id(str(_context.get("snapshot", {}).get("project", {}).get("project_id", "")))
	else:
		_mod_id_edit.editable = false
		_mod_id_edit.text = _definitions_mod_id()
	return {
		"ok": true,
		"status": "mod %s · %d definition(s) (%d ms)" % [_mod_id_edit.text, definitions.size(), elapsed],
	}


func _populate_tree() -> void:
	_tree.clear()
	var root := _tree.create_item()
	for untyped_record in _manifest.get("definitions", []):
		var record: Dictionary = untyped_record
		var item := _tree.create_item(root)
		item.set_text(0, str(record.get("definition_id", "")))
		item.set_text(1, str(record.get("definition_kind", "")))
		if str(record.get("definition_kind", "")) == "override":
			item.set_text(2, str(record.get("target_id", "")))
		else:
			item.set_text(2, str(int(record.get("mod_revision", 0))))
		item.set_text(3, str(record.get("definition_sha256", "")).substr(0, 12))
		item.set_metadata(0, str(record.get("definition_id", "")))


func _definitions_mod_id() -> String:
	var definitions: Array = _manifest.get("definitions", [])
	if definitions.is_empty():
		return ""
	return str((definitions[0] as Dictionary).get("mod_id", ""))


func _derived_mod_id(project_id: String) -> String:
	var lowered := project_id.to_lower()
	var expression := RegEx.new()
	expression.compile("[^a-z0-9_]")
	var normalized := expression.sub(lowered, "_", true)
	normalized = normalized.substr(0, min(normalized.length(), 32))
	if normalized.is_empty() or normalized.unicode_at(0) < "a".unicode_at(0) or normalized.unicode_at(0) > "z".unicode_at(0):
		normalized = ("m" + normalized).substr(0, 32)
	return normalized


func _set_controls_enabled(enabled: bool) -> void:
	_mod_id_edit.editable = enabled
	_target_id_edit.editable = enabled
	_new_event_button.disabled = not enabled
	_new_override_button.disabled = not enabled
	_validate_button.disabled = not enabled
	_save_button.disabled = not enabled
	_remove_button.disabled = not enabled
	_import_set_button.disabled = not enabled
	_export_set_button.disabled = not enabled
	_replace_on_import.disabled = not enabled
	_text.editable = enabled


func _on_tree_item_selected() -> void:
	var item := _tree.get_selected()
	if item == null:
		return
	var definition_id := str(item.get_metadata(0))
	if _load_definition_text(definition_id):
		_selected_id = definition_id
		_status_line = "Loaded %s" % definition_id
		_sync_form_from_text()
	else:
		_status_line = "Could not load %s" % definition_id
	_render_summary()


func _load_definition_text(definition_id: String) -> bool:
	if not _context.get("ok", false):
		return false
	var loaded := OverlayPackageScript.new().load_mod_definition(str(_context.workspace), definition_id)
	if not loaded.get("ok", false) or not bool(loaded.get("found", false)):
		return false
	_text.text = (loaded.bytes as PackedByteArray).get_string_from_utf8()
	return true


## Loads `document` into the JSON text and the form, selecting the Form tab
## when the form covers it, else the JSON tab (section D).
func _load_into_views(document: Dictionary) -> void:
	_text.text = JSON.stringify(document, "  ") + "\n"
	var outcome: Dictionary = _form.load_document(document)
	_switch_tab_silently(0 if outcome.get("ok", false) else 1)


## Parses the current JSON text and loads it into the form, selecting the
## Form tab when it covers the document, else staying on JSON.
func _sync_form_from_text() -> void:
	var parsed := JSON.new()
	if parsed.parse(_text.text) == OK and parsed.data is Dictionary:
		var document: Dictionary = ContractValues.intify(parsed.data)
		var outcome: Dictionary = _form.load_document(document)
		_switch_tab_silently(0 if outcome.get("ok", false) else 1)
	else:
		_switch_tab_silently(1)


func _switch_tab_silently(tab_index: int) -> void:
	_switching_views = true
	_views.current_tab = tab_index
	_switching_views = false


## The Form/JSON tab switch (section D): leaving JSON parses the text into
## the form (invalid JSON or an uncovered document stays on JSON, saying
## so); leaving Form serializes the form into the text.
func _on_view_tab_changed(tab_index: int) -> void:
	if _switching_views:
		return
	if tab_index == 0:
		var parsed := JSON.new()
		if parsed.parse(_text.text) != OK or not (parsed.data is Dictionary):
			_status_line = "Invalid JSON; staying on the JSON view."
			_render_summary()
			_switch_tab_silently(1)
			return
		var document: Dictionary = ContractValues.intify(parsed.data)
		var outcome: Dictionary = _form.load_document(document)
		if not outcome.get("ok", false):
			_status_line = str(outcome.get("reason", "The form does not cover this document."))
			_render_summary()
			_switch_tab_silently(1)
			return
	else:
		var document: Dictionary = _form.to_document()
		_text.text = JSON.stringify(document, "  ") + "\n"


func _on_form_changed() -> void:
	_status_line = "unsaved"
	_render_summary()


func _select_tree_row(definition_id: String) -> void:
	var root := _tree.get_root()
	if root == null:
		return
	var item := root.get_first_child()
	while item != null:
		if str(item.get_metadata(0)) == definition_id:
			item.select(0)
			break
		item = item.get_next()


func _on_new_event_pressed() -> void:
	if not _context.get("ok", false):
		return
	var mod_id := _mod_id_edit.text.strip_edges()
	if mod_id.is_empty():
		_status_line = "Enter a mod id before New event."
		_render_summary()
		return
	var name := _first_unused_new_event_name(mod_id)
	var document := {
		"schema_version": ContentCoreVersionScript.MOD_EVENT_DEFINITION_SCHEMA,
		"contract_fingerprint": _read_tracked_fingerprint(DEFAULT_CONTRACT_FINGERPRINT_PATH),
		"cells_fingerprint": _read_tracked_fingerprint(DEFAULT_CELLS_FINGERPRINT_PATH),
		"kind": "new_event",
		"mod": {"id": mod_id, "revision": 1},
		"id": "mod.%s.%s" % [mod_id, name],
		"display": {"title_ko": "", "title_en": "New event", "category": "school", "place": "gate"},
		"trigger": {"type": "place", "category": "school", "place": "gate"},
		"conditions": [{"type": "event_not_completed"}],
		"dialogue": [{"kind": "line", "text": ""}],
		"after": [],
		"results": {
			"result_default": {
				"selected_by": {"kind": "default"},
				"event_played": true,
				"dialogue": [],
				"after": [],
				"terminal": "map",
			},
		},
		"terminals": {"map": {"kind": "return_to_map"}},
	}
	_load_into_views(document)
	_selected_id = ""
	_status_line = "New event template for %s; write the line text before Validate." % str(document.id)
	_render_summary()


func _first_unused_new_event_name(mod_id: String) -> String:
	var used := {}
	var prefix := "mod.%s.new_event_" % mod_id
	for untyped_record in _manifest.get("definitions", []):
		var record: Dictionary = untyped_record
		var definition_id := str(record.get("definition_id", ""))
		if definition_id.begins_with(prefix):
			var suffix := definition_id.substr(prefix.length())
			if suffix.is_valid_int():
				used[int(suffix)] = true
	var n := 1
	while used.has(n):
		n += 1
	return "new_event_%d" % n


func _on_new_override_pressed() -> void:
	if not _context.get("ok", false):
		return
	var mod_id := _mod_id_edit.text.strip_edges()
	if mod_id.is_empty():
		_status_line = "Enter a mod id before New override."
		_render_summary()
		return
	var target_id := _target_id_edit.text.strip_edges()
	if target_id.is_empty():
		_status_line = "Enter a target id before New override."
		_render_summary()
		return
	var target_path := "res://%s/%s.json" % [ModDefinitionBindingScript.DEFAULT_DEFINITIONS_DIR, target_id]
	if not FileAccess.file_exists(target_path):
		_status_line = "Tracked v4 document is missing: %s" % target_path
		_render_summary()
		return
	var document := {
		"schema_version": ContentCoreVersionScript.MOD_EVENT_DEFINITION_SCHEMA,
		"contract_fingerprint": _read_tracked_fingerprint(DEFAULT_CONTRACT_FINGERPRINT_PATH),
		"cells_fingerprint": _read_tracked_fingerprint(DEFAULT_CELLS_FINGERPRINT_PATH),
		"kind": "override",
		"mod": {"id": mod_id, "revision": 1},
		"id": "mod.%s.override_%s" % [mod_id, target_id.replace(".", "_")],
		"target": {
			"id": target_id,
			"contract": "kakyu_event_definition/v4",
			"document_sha256": ModDefinitionFormScript.document_sha256_lf(target_path),
		},
		"operations": [{"op": "replace_conditions", "conditions": [{"type": "event_not_completed"}]}],
	}
	_load_into_views(document)
	_selected_id = ""
	_status_line = "New override template for %s." % str(document.id)
	_render_summary()



func _read_tracked_fingerprint(res_path: String) -> String:
	return FileAccess.get_file_as_string(res_path).strip_edges()


## Validate always reads the JSON text, serializing the form first when the
## Form tab is active (section D).
func _serialize_form_if_active() -> void:
	if _views.current_tab == 0:
		_text.text = JSON.stringify(_form.to_document(), "  ") + "\n"


func _on_validate_pressed() -> void:
	_serialize_form_if_active()
	var start := Time.get_ticks_msec()
	var bytes := _text.text.to_utf8_buffer()
	var verdict := ModDefinitionBindingScript.validate(bytes)
	var elapsed := Time.get_ticks_msec() - start
	if bool(verdict.get("ok", false)):
		_status_line = "ok (%d ms)" % elapsed
	else:
		_status_line = "%s: %s (%d ms)" % [str(verdict.get("reason", "")), str(verdict.get("detail", "")), elapsed]
	_render_summary()


func _on_save_pressed() -> void:
	if not publish_definitions.is_valid() or not _context.get("ok", false):
		return
	_serialize_form_if_active()
	var start := Time.get_ticks_msec()
	var bytes := _text.text.to_utf8_buffer()
	var result: Dictionary = publish_definitions.call([bytes])
	var elapsed := Time.get_ticks_msec() - start
	if not result.get("ok", false):
		_status_line = str(result.get("error", "Save failed."))
		_render_summary()
		return
	var saved_id := ""
	var parsed := JSON.new()
	if parsed.parse(_text.text) == OK and parsed.data is Dictionary:
		saved_id = str((parsed.data as Dictionary).get("id", ""))
	_do_refresh()
	if not saved_id.is_empty():
		_selected_id = saved_id
		_load_definition_text(saved_id)
		# TreeItem.select() emits "item_selected", which runs
		# _on_tree_item_selected and overwrites _status_line; set the final
		# Save outcome after reselecting, not before.
		_select_tree_row(saved_id)
	_status_line = "Saved %s (%d ms)" % [saved_id, elapsed]
	_render_summary()


func _on_remove_pressed() -> void:
	if _selected_id.is_empty() or not remove_definition.is_valid():
		return
	var start := Time.get_ticks_msec()
	var result: Dictionary = remove_definition.call(_selected_id)
	var elapsed := Time.get_ticks_msec() - start
	if not result.get("ok", false):
		_status_line = "Remove refused: %s (%d ms)" % [str(result.get("error", "")), elapsed]
	else:
		_status_line = "Removed %s (%d ms)" % [_selected_id, elapsed]
		_selected_id = ""
		_text.text = ""
	_do_refresh()
	_render_summary()


func _on_import_set_pressed() -> void:
	if not _context.get("ok", false):
		return
	_import_set_dialog.current_dir = str(_context.workspace)
	_import_set_dialog.popup_centered_ratio(0.75)


func _on_import_set_path_selected(path: String) -> void:
	if not _context.get("ok", false):
		return
	var start := Time.get_ticks_msec()
	var importer := ModDefinitionSetImportScript.new()
	var result := importer.import_set(
		str(_context.content_set_root), str(_context.workspace), path, _replace_on_import.button_pressed
	)
	var elapsed := Time.get_ticks_msec() - start
	if not result.get("ok", false):
		_status_line = "Import refused: %s (%d ms)" % [str(result.get("error", "")), elapsed]
	else:
		_status_line = "added %d, replaced %d, unchanged %d (%d ms)" % [
			int(result.get("added", 0)), int(result.get("replaced", 0)), int(result.get("unchanged", 0)), elapsed,
		]
	_do_refresh()
	_render_summary()


func _on_export_set_pressed() -> void:
	if not _context.get("ok", false):
		return
	_export_set_dialog.current_dir = str(_context.workspace)
	_export_set_dialog.popup_centered_ratio(0.75)


func _on_export_set_path_selected(path: String) -> void:
	if not _context.get("ok", false):
		return
	var start := Time.get_ticks_msec()
	var built: Dictionary = ModDefinitionSetImportScript.build_set(str(_context.workspace), path)
	var elapsed := Time.get_ticks_msec() - start
	if not built.get("ok", false):
		_status_line = "Export refused: %s (%d ms)" % [str(built.get("error", "")), elapsed]
	else:
		_status_line = "Exported %d definition(s) to %s (%d ms)" % [
			int(built.get("definition_count", 0)), path, elapsed,
		]
	_render_summary()


func _render_summary() -> void:
	_summary.text = _status_line


func _mark_unique(node: Node, unique_name: String) -> void:
	node.name = unique_name
	node.unique_name_in_owner = true
	node.owner = self


static func _label(value: String) -> Label:
	var label := Label.new()
	label.text = value
	return label


func _button(parent: Node, label_text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = label_text
	button.pressed.connect(action)
	parent.add_child(button)
	return button
