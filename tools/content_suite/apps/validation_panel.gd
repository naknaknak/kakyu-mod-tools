class_name KakyuValidationPanel
extends PanelContainer

const ReportScript := preload("res://tools/content_suite/validation_report.gd")
const SessionScript := preload("res://tools/content_suite/validation_session.gd")
const PathHistoryScript := preload("res://tools/content_suite/tool_path_history.gd")

var session := SessionScript.new()
var include_source: CheckBox
var source_label: Label
var executable_edit: LineEdit
var run_button: Button
var open_button: Button
var executable_button: Button
var clear_executable_button: Button
var status_label: Label
var context_label: Label
var coverage_tree: Tree
var checks_tree: Tree
var output_edit: TextEdit
var report_dialog: FileDialog
var executable_dialog: FileDialog
var layout: VBoxContainer
var report_origin := ""
var _selected_source := ""
var _poll_elapsed := 0.0
var _path_history := PathHistoryScript.new()


func _ready() -> void:
	_build_ui()
	hide()


func show_for_source(source: String) -> void:
	if not session.is_running():
		_selected_source = source.strip_edges()
		source_label.text = _selected_source if not _selected_source.is_empty() else "No ELFIMAGE selected in Launcher"
		source_label.tooltip_text = source_label.text
		include_source.disabled = _selected_source.is_empty()
		if include_source.disabled:
			include_source.button_pressed = false
	show()
	_update_buttons()


func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 14)
	add_child(margin)
	layout = VBoxContainer.new()
	layout.add_theme_constant_override("separation", 6)
	margin.add_child(layout)
	var title_row := HBoxContainer.new()
	layout.add_child(title_row)
	var title := _label("Repository validation")
	title.add_theme_font_size_override("font_size", 22)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)
	_button(title_row, "Close", hide)
	var scope_note := _label("Local synthetic checks always run. Selected original sources are read-only.\nThis suite does not validate the active workspace's modifications or a mod package.")
	scope_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(scope_note)
	var source_row := HBoxContainer.new()
	layout.add_child(source_row)
	include_source = CheckBox.new()
	include_source.text = "Include selected ELFIMAGE"
	source_row.add_child(include_source)
	source_label = _label("")
	source_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	source_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	source_row.add_child(source_label)
	var executable_row := HBoxContainer.new()
	layout.add_child(executable_row)
	executable_row.add_child(_label("Optional original EXE:"))
	executable_edit = LineEdit.new()
	executable_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	executable_edit.placeholder_text = "Choose AI5WIN.exe for static native audits"
	executable_row.add_child(executable_edit)
	executable_button = _button(executable_row, "Browse...", _browse_executable)
	clear_executable_button = _button(executable_row, "Clear", executable_edit.clear)
	var actions := HBoxContainer.new()
	layout.add_child(actions)
	run_button = _button(actions, "Run validation", _run_validation)
	open_button = _button(actions, "Open saved report...", _browse_report)
	status_label = _label("Choose a scope or open a saved report.")
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	actions.add_child(status_label)
	context_label = _label("No report loaded. Coverage groups may overlap.")
	context_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(context_label)
	coverage_tree = _tree(["Coverage", "Status", "Checks", "Reason"], 92)
	coverage_tree.set_column_expand(0, false)
	coverage_tree.set_column_custom_minimum_width(0, 180)
	coverage_tree.set_column_expand(1, false)
	coverage_tree.set_column_custom_minimum_width(1, 95)
	coverage_tree.set_column_expand(2, false)
	coverage_tree.set_column_custom_minimum_width(2, 60)
	layout.add_child(coverage_tree)
	checks_tree = _tree(["Check", "Status", "Seconds"], 120)
	checks_tree.size_flags_stretch_ratio = 1.5
	checks_tree.set_column_expand(1, false)
	checks_tree.set_column_custom_minimum_width(1, 115)
	checks_tree.set_column_expand(2, false)
	checks_tree.set_column_custom_minimum_width(2, 75)
	checks_tree.item_selected.connect(_show_check_output)
	layout.add_child(checks_tree)
	output_edit = TextEdit.new()
	output_edit.custom_minimum_size.y = 70
	output_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	output_edit.editable = false
	output_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	output_edit.placeholder_text = "Select a check to inspect its failure output."
	layout.add_child(output_edit)
	var lifecycle_note := _label("Runs continue in the background if Launcher closes. Reopen the saved report to inspect the result.")
	lifecycle_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(lifecycle_note)
	report_dialog = FileDialog.new()
	report_dialog.access = FileDialog.ACCESS_FILESYSTEM
	report_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	report_dialog.title = "Open a saved validation report"
	report_dialog.filters = PackedStringArray(["*.json ; Validation JSON reports"])
	report_dialog.file_selected.connect(open_report)
	add_child(report_dialog)
	executable_dialog = FileDialog.new()
	executable_dialog.access = FileDialog.ACCESS_FILESYSTEM
	executable_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	executable_dialog.title = "Choose read-only original AI5WIN.exe"
	executable_dialog.filters = PackedStringArray(["*.exe ; Original Windows executable"])
	executable_dialog.file_selected.connect(func(path: String) -> void: executable_edit.text = path)
	add_child(executable_dialog)


func _run_validation() -> void:
	if session.is_running():
		return
	_clear_report()
	var started := session.start(_selected_source if include_source.button_pressed else "", executable_edit.text)
	if not started.ok:
		status_label.text = str(started.error)
		_update_buttons()
		return
	status_label.text = "Running in the background (PID %d). Full batches may take several minutes." % int(started.process_id)
	context_label.text = "Current run: %s\nReport: %s" % [str(started.request.run_id), str(started.request.report_path)]
	_update_buttons()


func _process(delta: float) -> void:
	_poll_elapsed += delta
	if _poll_elapsed < 0.25 or not session.is_running():
		return
	_poll_elapsed = 0.0
	var polled := session.poll()
	if not polled.finished:
		return
	display_result(polled.result, "Completed run")
	context_label.text += "\nReport: %s" % str(polled.request.report_path)
	_update_buttons()


func open_report(path: String) -> void:
	if session.is_running():
		return
	display_result(ReportScript.read_path(path), "Saved report")
	context_label.text += "\nReport: %s" % path


func display_result(result: Dictionary, origin: String) -> void:
	_clear_report()
	report_origin = origin
	if not result.ok:
		status_label.text = "%s rejected: %s" % [origin, str(result.error)]
		return
	var payload: Dictionary = result.payload
	status_label.text = "%s: %s — %d passed, %d failed (%.1f s)" % [origin, str(payload.status).to_upper(), int(payload.passed), int(payload.failed), float(payload.duration_seconds)]
	var integrity := "Legacy v2: unsigned; coverage unverified" if result.legacy else "Verified report fingerprint"
	var tier := str(payload.context.get("tier", "full"))
	# TD-32 part 3b: `cache`/`cache_dir`/`cached` are synthesized for a v4/v3/v2
	# report too (`not_consulted`, 0), so this reads uniformly regardless of
	# which accepted schema `result.payload` came from.
	var cache_state := str(payload.context.get("cache", "not_consulted"))
	var cached_count := int(payload.get("cached", 0))
	context_label.text = "%s. Repository suite only; workspace modifications were not validated.\nELFIMAGE: %s | EXE: %s | tier: %s | cache: %s, %d cached" % [integrity, _source_text(payload.context.elfimage, bool(result.legacy)), _source_text(payload.context.executable, bool(result.legacy)), tier, cache_state, cached_count]
	context_label.tooltip_text = context_label.text
	var coverage_root := coverage_tree.create_item()
	for value in payload.coverage:
		var row := coverage_tree.create_item(coverage_root)
		row.set_text(0, str(value.title))
		row.set_text(1, str(value.status).replace("_", " ").to_upper())
		row.set_text(2, str(int(value.check_count)))
		row.set_text(3, str(value.reason))
		row.set_tooltip_text(3, str(value.reason))
	var checks_root := checks_tree.create_item()
	var first_failure: TreeItem = null
	for value in payload.checks:
		var row := checks_tree.create_item(checks_root)
		var is_cached: bool = bool(value.get("cached", false))
		row.set_text(0, str(value.name) + (" (cached)" if is_cached else ""))
		row.set_tooltip_text(0, str(value.name))
		row.set_text(1, str(value.status).to_upper())
		row.set_text(2, "%.3f" % float(value.duration_seconds))
		row.set_metadata(0, str(value.get("output_tail", "No failure output was recorded.")))
		if value.status != "passed" and first_failure == null:
			first_failure = row
	if first_failure != null:
		first_failure.select(0)
		_show_check_output()
	if not str(payload.configuration_error).is_empty():
		output_edit.text = str(payload.configuration_error)


func _clear_report() -> void:
	report_origin = ""
	coverage_tree.clear()
	checks_tree.clear()
	output_edit.clear()
	context_label.text = "No report loaded. Coverage groups may overlap."


func _update_buttons() -> void:
	var running := session.is_running()
	var available := session.availability()
	run_button.disabled = running or not available.ok
	run_button.tooltip_text = "" if available.ok else str(available.error)
	open_button.disabled = running
	include_source.disabled = running or _selected_source.is_empty()
	executable_edit.editable = not running
	executable_button.disabled = running
	clear_executable_button.disabled = running
	if not available.ok and not running and report_origin.is_empty():
		status_label.text = str(available.error)


func _browse_report() -> void:
	var reports_root := ProjectSettings.globalize_path("user://content_tools/validation")
	if DirAccess.dir_exists_absolute(reports_root):
		report_dialog.current_dir = reports_root
	report_dialog.popup_centered_ratio(0.8)


func _browse_executable() -> void:
	_path_history.apply_source_dialog(executable_dialog)
	executable_dialog.popup_centered_ratio(0.8)


func _show_check_output() -> void:
	var selected := checks_tree.get_selected()
	if selected != null:
		output_edit.text = str(selected.get_metadata(0))


static func _source_text(value: String, legacy: bool) -> String:
	return "unknown" if legacy else ("not selected" if value.is_empty() else value)


static func _label(value: String) -> Label:
	var label := Label.new()
	label.text = value
	return label


static func _button(parent: Node, title: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = title
	button.pressed.connect(action)
	parent.add_child(button)
	return button


static func _tree(titles: Array, minimum_height: float) -> Tree:
	var tree := Tree.new()
	tree.columns = titles.size()
	tree.column_titles_visible = true
	tree.hide_root = true
	tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tree.custom_minimum_size.y = minimum_height
	for index in titles.size():
		tree.set_column_title(index, str(titles[index]))
	return tree
