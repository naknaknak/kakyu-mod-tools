class_name KakyuWorkspaceDashboardPanel
extends PanelContainer

## Renders the provenance report (WD-04) for the active workspace inside the
## Launcher: revision, declared compatibility, every replacement/projection
## and the running Content Core's compatibility with the project's declared
## range. Every statement it shows comes from `KakyuProvenanceReport.build`,
## which re-verifies the workspace files on disk before this panel renders
## anything; it never edits the workspace itself.

const ProvenanceReportScript := preload("res://tools/content_suite/provenance_report.gd")
const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")

var project_label: Label
var core_label: Label
var generation_label: Label
var archives_tree: Tree
var changes_tree: Tree
var compatibility_label: Label
var verification_label: Label
var export_button: Button
var report_dialog: FileDialog
var layout: VBoxContainer

var _workspace_root := ""
var _content_set_root := ""
var _report: Dictionary = {}
var _error := ""


func _ready() -> void:
	_build_ui()
	hide()


func show_for_workspace(workspace_root: String, content_set_root: String) -> void:
	_workspace_root = workspace_root
	_content_set_root = content_set_root
	refresh()
	show()


func refresh() -> Dictionary:
	var result := ProvenanceReportScript.build(_workspace_root, _content_set_root)
	if not result.get("ok", false):
		_report = {}
		_error = str(result.get("error", "unknown error"))
		archives_tree.clear()
		changes_tree.clear()
		verification_label.text = "Workspace verification failed: %s" % _error
		export_button.disabled = true
		return result
	_error = ""
	_report = result.report
	_render(_report)
	export_button.disabled = false
	return result


func get_report() -> Dictionary:
	return _report


func get_error() -> String:
	return _error


static func version_within_range(version: String, minimum_version: String, maximum_exclusive: String) -> bool:
	return _compare_versions(version, minimum_version) >= 0 and _compare_versions(version, maximum_exclusive) < 0


static func _compare_versions(left: String, right: String) -> int:
	var left_parts := _version_parts(left)
	var right_parts := _version_parts(right)
	for index in range(3):
		var difference: int = left_parts[index] - right_parts[index]
		if difference != 0:
			return difference
	return 0


static func _version_parts(value: String) -> Array:
	var pieces := value.split(".")
	var parts: Array = [0, 0, 0]
	for index in range(min(3, pieces.size())):
		parts[index] = int(pieces[index])
	return parts


func _render(report: Dictionary) -> void:
	var project: Dictionary = report.project
	var content_core: Dictionary = project.content_core
	project_label.text = "%s · %s v%s · revision %d · objective %s" % [
		str(project.display_name), str(project.project_id), str(project.project_version),
		int(project.project_revision), str(project.compatibility_objective),
	]
	var within := version_within_range(
		ContentCoreVersionScript.CORE_VERSION, str(content_core.minimum_version), str(content_core.maximum_exclusive)
	)
	core_label.text = "Content Core %s · project range %s ..< %s · %s" % [
		ContentCoreVersionScript.CORE_VERSION, str(content_core.minimum_version), str(content_core.maximum_exclusive),
		"within range" if within else "OUTSIDE range",
	]
	var workspace: Dictionary = report.workspace
	generation_label.text = "generation %s · project %s · manifest %s · manifest editor %s" % [
		_short_hash(str(workspace.generation_sha256)), _short_hash(str(workspace.project_sha256)),
		_short_hash(str(workspace.manifest_sha256)), str(workspace.manifest_editor_version),
	]
	generation_label.tooltip_text = "generation %s · project %s · manifest %s · manifest editor %s" % [
		str(workspace.generation_sha256), str(workspace.project_sha256),
		str(workspace.manifest_sha256), str(workspace.manifest_editor_version),
	]
	_render_archives(report.source_content_set.archives)
	_render_changes(report.replacements, report.projections)
	var compatibility: Dictionary = report.compatibility
	compatibility_label.text = "objective %s · declared %s · %s" % [
		str(compatibility.objective), str(compatibility.declared),
		"consistent" if bool(compatibility.consistent_with_objective) else "NOT consistent with the objective",
	]
	var verification: Dictionary = report.verification
	verification_label.text = (
		"Verified %d replacement blob(s), %d projection file(s), %d authoring bundle(s) reopened · original engine unverified"
		% [int(verification.replacement_blobs), int(verification.projection_files), int(verification.authoring_bundles_reopened)]
	)


func _render_archives(archives: Array) -> void:
	archives_tree.clear()
	var root := archives_tree.create_item()
	for untyped_row in archives:
		var row: Dictionary = untyped_row
		var item := archives_tree.create_item(root)
		item.set_text(0, str(row.archive))
		item.set_text(1, str(int(row.bytes)))
		item.set_text(2, str(int(row.entries)))
		item.set_text(3, "yes" if bool(row.required) else "no")
		item.set_text(4, _short_hash(str(row.sha256)))
		item.set_tooltip_text(4, str(row.sha256))


func _render_changes(replacements: Array, projections: Array) -> void:
	changes_tree.clear()
	var root := changes_tree.create_item()
	for untyped_replacement in replacements:
		var replacement: Dictionary = untyped_replacement
		var item := changes_tree.create_item(root)
		item.set_text(0, "replacement")
		item.set_text(1, str(replacement.target_archive))
		item.set_text(2, str(replacement.target_entry))
		item.set_text(3, "%d → %d" % [int(replacement.original_size), int(replacement.replacement_size)])
		item.set_text(4, str(replacement.compatibility))
		item.set_text(5, str(replacement.text_encoding))
		var authoring = replacement.authoring
		if authoring != null:
			var authoring_row: Dictionary = authoring
			item.set_text(6, "%d step(s) · %s" % [int(authoring_row.step_count), str(authoring_row.proof_schema).get_file()])
		else:
			item.set_text(6, "-")
	for untyped_projection in projections:
		var projection: Dictionary = untyped_projection
		var item := changes_tree.create_item(root)
		item.set_text(0, "projection")
		item.set_text(1, str(projection.target_archive))
		item.set_text(2, str(projection.target_entry))
		item.set_text(3, "%d edit(s)" % int(projection.edit_count))
		item.set_text(4, str(projection.compatibility))
		item.set_text(5, str(projection.text_encoding))
		item.set_text(6, "-")


func _on_export_pressed() -> void:
	if _report.is_empty():
		return
	var project: Dictionary = _report.project
	report_dialog.current_file = "%s-r%d.kakyu-provenance.json" % [str(project.project_id), int(project.project_revision)]
	if not _workspace_root.is_empty():
		report_dialog.current_dir = _workspace_root
	report_dialog.popup_centered_ratio(0.75)


func _on_report_path_selected(path: String) -> void:
	var refreshed := refresh()
	if not refreshed.get("ok", false):
		return
	var written := ProvenanceReportScript.write(_report, path)
	if not written.get("ok", false):
		verification_label.text = str(written.get("error", "unknown error"))
		return
	verification_label.text = "Exported report to %s" % str(written.path)


static func _short_hash(value: String) -> String:
	return value.substr(0, 12)


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
	var title := _label("Workspace dashboard")
	title.add_theme_font_size_override("font_size", 22)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)
	_button(title_row, "Refresh", refresh)
	export_button = _button(title_row, "Export report...", _on_export_pressed)
	_button(title_row, "Close", hide)
	project_label = _label("")
	layout.add_child(project_label)
	core_label = _label("")
	layout.add_child(core_label)
	generation_label = _label("")
	layout.add_child(generation_label)
	archives_tree = _tree(["Archive", "Bytes", "Entries", "Required", "SHA-256"], 90)
	layout.add_child(archives_tree)
	changes_tree = _tree(["Kind", "Archive", "Entry", "Size", "Compatibility", "Encoding", "Authoring"], 130)
	changes_tree.size_flags_stretch_ratio = 1.5
	layout.add_child(changes_tree)
	compatibility_label = _label("")
	layout.add_child(compatibility_label)
	verification_label = _label("")
	verification_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(verification_label)
	report_dialog = FileDialog.new()
	report_dialog.access = FileDialog.ACCESS_FILESYSTEM
	report_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	report_dialog.title = "Export a portable provenance report"
	report_dialog.filters = PackedStringArray(["*.json ; Kakyu provenance report"])
	report_dialog.file_selected.connect(_on_report_path_selected)
	add_child(report_dialog)


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
