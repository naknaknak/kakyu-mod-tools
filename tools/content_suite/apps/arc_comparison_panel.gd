class_name KakyuArcComparisonPanel
extends PanelContainer

## Renders a `KakyuArcComparison` report (WD-01): every entry row's status
## against a second ARC or the loaded overlay, filtered to differences by
## default. It never edits either side; `arc_comparison.gd` already
## re-verified every hash before this panel renders anything.

const ArcComparisonScript := preload("res://tools/content_suite/arc_comparison.gd")

var title_label: Label
var summary_label: Label
var differences_only: CheckBox
var rows_tree: Tree
var status_label: Label
var export_button: Button
var export_dialog: FileDialog
var layout: VBoxContainer

var _report: Dictionary = {}


func _ready() -> void:
	_build_ui()
	hide()


func show_report(report: Dictionary) -> void:
	_report = report
	title_label.text = _title_text(report)
	summary_label.text = _summary_text(report)
	status_label.text = ""
	_render_rows()
	show()


func get_report() -> Dictionary:
	return _report


func visible_row_count() -> int:
	if rows_tree.get_root() == null:
		return 0
	return rows_tree.get_root().get_child_count()


func _title_text(report: Dictionary) -> String:
	var left: Dictionary = report.left
	var right: Dictionary = report.right
	if str(report.mode) == "overlay":
		return "%s vs the loaded overlay" % str(left.name)
	return "%s vs %s" % [str(left.name), str(right.name)]


func _summary_text(report: Dictionary) -> String:
	var summary: Dictionary = report.summary
	if str(report.mode) == "overlay":
		return "%d identical · %d changed · %d overlay identical" % [
			int(summary.identical), int(summary.changed), int(summary.overlay_identical),
		]
	var suffix := " · order differs" if not bool(report.order_preserved) else ""
	return "%d identical · %d changed · %d only left · %d only right%s" % [
		int(summary.identical), int(summary.changed), int(summary.only_left), int(summary.only_right), suffix,
	]


func _render_rows() -> void:
	rows_tree.clear()
	if _report.is_empty():
		return
	var root := rows_tree.create_item()
	var only_differences := differences_only.button_pressed
	for untyped_row in _report.rows:
		var row: Dictionary = untyped_row
		if only_differences and str(row.status) == "identical":
			continue
		var item := rows_tree.create_item(root)
		item.set_text(0, str(row.entry))
		item.set_text(1, str(row.status))
		item.set_text(2, _size_text(int(row.left_size)))
		item.set_text(3, _size_text(int(row.right_size)))
		item.set_text(4, _hash_text(str(row.left_sha256)))
		item.set_text(5, _hash_text(str(row.right_sha256)))
		item.set_tooltip_text(4, str(row.left_sha256))
		item.set_tooltip_text(5, str(row.right_sha256))


func _on_differences_only_toggled(_pressed: bool) -> void:
	_render_rows()


func _on_export_pressed() -> void:
	if _report.is_empty():
		return
	export_dialog.current_file = "%s.kakyu-arc-comparison.json" % str(_report.left.name).get_basename()
	export_dialog.popup_centered_ratio(0.75)


func _on_export_path_selected(path: String) -> void:
	var written := ArcComparisonScript.write(_report, path)
	if not written.get("ok", false):
		status_label.text = str(written.get("error", "unknown error"))
		return
	status_label.text = "Exported comparison to %s" % str(written.path)


static func _size_text(value: int) -> String:
	return "-" if value < 0 else str(value)


static func _hash_text(value: String) -> String:
	return "-" if value.is_empty() else value.substr(0, 12)


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
	title_label = _label("")
	title_label.add_theme_font_size_override("font_size", 20)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title_label)
	export_button = _button(title_row, "Export comparison...", _on_export_pressed)
	_button(title_row, "Close", hide)
	summary_label = _label("")
	layout.add_child(summary_label)
	differences_only = CheckBox.new()
	differences_only.text = "Differences only"
	differences_only.button_pressed = true
	differences_only.toggled.connect(_on_differences_only_toggled)
	layout.add_child(differences_only)
	rows_tree = _tree(["Entry", "Status", "Left size", "Right size", "Left SHA-256", "Right SHA-256"], 220)
	layout.add_child(rows_tree)
	status_label = _label("")
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(status_label)
	export_dialog = FileDialog.new()
	export_dialog.access = FileDialog.ACCESS_FILESYSTEM
	export_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	export_dialog.title = "Export ARC comparison report"
	export_dialog.filters = PackedStringArray(["*.json ; Kakyu ARC comparison report"])
	export_dialog.file_selected.connect(_on_export_path_selected)
	add_child(export_dialog)


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
