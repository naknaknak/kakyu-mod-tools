extends Control

const ToolWindowProfileScript := preload("res://tools/content_suite/tool_window_profile.gd")
const ToolPathHistoryScript := preload("res://tools/content_suite/tool_path_history.gd")
const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")
const ContentProjectScript := preload("res://content_core/content_project.gd")
const ContentSetScript := preload("res://content_core/content_set.gd")
const ContentWorkspaceScript := preload("res://content_core/content_workspace.gd")
const ValidationPanelScript := preload("res://tools/content_suite/apps/validation_panel.gd")
const WorkspaceDashboardPanelScript := preload("res://tools/content_suite/apps/workspace_dashboard_panel.gd")
const ProvenanceReportScript := preload("res://tools/content_suite/provenance_report.gd")
const TOOL_SCENES := {
	"arc_browser": "res://tools/content_suite/apps/arc_browser.tscn",
	"audio_editor": "res://tools/content_suite/apps/audio_arc_editor.tscn",
	"mes_editor": "res://tools/content_suite/apps/mes_editor.tscn",
	"event_player": "res://tools/content_suite/apps/event_player.tscn",
	"image_editor": "res://tools/content_suite/apps/image_arc_editor.tscn",
}

@onready var archive_path_edit: LineEdit = %ArchivePathEdit
@onready var content_set_path_edit: LineEdit = %ContentSetPathEdit
@onready var workspace_path_edit: LineEdit = %WorkspacePathEdit
@onready var project_id_edit: LineEdit = %ProjectIdEdit
@onready var display_name_edit: LineEdit = %DisplayNameEdit
@onready var status_label: Label = %StatusLabel
@onready var archive_dialog: FileDialog = %ArchiveDialog
@onready var content_set_dialog: FileDialog = %ContentSetDialog
@onready var workspace_dialog: FileDialog = %WorkspaceDialog
@onready var report_dialog: FileDialog = %ReportDialog

var _path_history := ToolPathHistoryScript.new()
var _workspace := ContentWorkspaceScript.new()
var _workspace_dialog_mode := ""
var _active_content_set_root := ""
var _active_workspace_root := ""
var validation_panel: KakyuValidationPanel
var dashboard_panel: KakyuWorkspaceDashboardPanel


func _ready() -> void:
	ToolWindowProfileScript.apply(get_window())
	_path_history.apply_source_dialog(archive_dialog)
	_path_history.apply_elfimage_dialog(content_set_dialog)
	_path_history.apply_workspace_dialog(workspace_dialog)
	var arguments := OS.get_cmdline_user_args()
	if not arguments.is_empty():
		_set_startup_source(arguments[0])
	validation_panel = ValidationPanelScript.new()
	validation_panel.name = "ValidationPanel"
	add_child(validation_panel)
	dashboard_panel = WorkspaceDashboardPanelScript.new()
	dashboard_panel.name = "WorkspaceDashboardPanel"
	add_child(dashboard_panel)


func _on_validation_pressed() -> void:
	validation_panel.show_for_source(content_set_path_edit.text)


func _on_dashboard_pressed() -> void:
	if not _workspace.is_open():
		status_label.text = "Open a workspace before opening its dashboard."
		return
	dashboard_panel.show_for_workspace(_active_workspace_root, _active_content_set_root)


func _on_browse_pressed() -> void:
	_path_history.apply_source_dialog(archive_dialog)
	archive_dialog.popup_centered_ratio(0.75)


func _on_browse_content_set_pressed() -> void:
	_path_history.apply_elfimage_dialog(content_set_dialog)
	content_set_dialog.popup_centered_ratio(0.75)


func _on_create_workspace_pressed() -> void:
	_workspace_dialog_mode = "create"
	_path_history.apply_workspace_dialog(workspace_dialog)
	workspace_dialog.title = "Choose an empty directory for the new content workspace"
	workspace_dialog.popup_centered_ratio(0.75)


func _on_open_workspace_pressed() -> void:
	_workspace_dialog_mode = "open"
	_path_history.apply_workspace_dialog(workspace_dialog)
	workspace_dialog.title = "Choose an existing Kakyu content workspace"
	workspace_dialog.popup_centered_ratio(0.75)


func _on_export_report_pressed() -> void:
	if not _workspace.is_open():
		status_label.text = "Open a workspace before exporting its provenance report."
		return
	var snapshot := _workspace.get_snapshot()
	report_dialog.current_dir = _active_workspace_root
	report_dialog.current_file = "%s-r%d.kakyu-provenance.json" % [
		str(snapshot.project.project_id), int(snapshot.project.project_revision),
	]
	report_dialog.popup_centered_ratio(0.75)


func _on_report_path_selected(path: String) -> void:
	if not _workspace.is_open():
		status_label.text = "Open a workspace before exporting its provenance report."
		return
	var built := ProvenanceReportScript.build(_active_workspace_root, _active_content_set_root)
	if not built.get("ok", false):
		status_label.text = "Provenance report export failed: %s" % str(built.get("error", "unknown error"))
		return
	var written := ProvenanceReportScript.write(built.report, path)
	if not written.get("ok", false):
		status_label.text = "Provenance report export failed: %s" % str(written.get("error", "unknown error"))
		return
	var report: Dictionary = built.report
	status_label.text = "Exported provenance report (%d replacements, %d projections, declared %s) to %s" % [
		report.replacements.size(), report.projections.size(), str(report.compatibility.declared), str(written.path),
	]


func _on_archive_selected(path: String) -> void:
	_set_startup_archive(path)


func _on_content_set_selected(path: String) -> void:
	_set_startup_content_set(path)


func _on_workspace_selected(path: String) -> void:
	if _workspace_dialog_mode == "create":
		_create_workspace(path)
	elif _workspace_dialog_mode == "open":
		_open_workspace(path)
	else:
		status_label.text = "Choose Create Workspace or Open Workspace first."


func _on_clear_pressed() -> void:
	archive_path_edit.clear()
	status_label.text = "Optional startup ARC cleared."


func _on_arc_browser_pressed() -> void:
	_launch_tool("arc_browser")


func _on_audio_editor_pressed() -> void:
	_launch_tool("audio_editor")


func _on_mes_editor_pressed() -> void:
	_launch_tool("mes_editor")


func _on_event_player_pressed() -> void:
	_launch_tool("event_player")


func _on_image_editor_pressed() -> void:
	_launch_tool("image_editor")


func _set_startup_archive(path: String) -> bool:
	var checked := _validate_startup_path(path)
	if checked.ok and str(checked.kind) != "arc":
		status_label.text = "Choose an ARC file for this action."
		return false
	if not checked.ok:
		status_label.text = str(checked.error)
		return false
	archive_path_edit.text = str(checked.path)
	_path_history.remember_source_path(str(checked.path))
	_path_history.apply_source_dialog(archive_dialog)
	status_label.text = "Startup ARC selected; source tools will open it read-only."
	return true


func _set_startup_source(path: String) -> bool:
	var checked := _validate_startup_path(path)
	if not checked.ok:
		status_label.text = str(checked.error)
		return false
	if str(checked.kind) == "content_set":
		return _set_startup_content_set(str(checked.path))
	return _set_startup_archive(str(checked.path))


func _set_startup_content_set(path: String) -> bool:
	var checked := _validate_startup_path(path)
	if checked.ok and str(checked.kind) != "content_set":
		status_label.text = "Choose an ELFIMAGE directory for this action."
		return false
	if not checked.ok:
		status_label.text = str(checked.error)
		return false
	content_set_path_edit.text = str(checked.path)
	_path_history.remember_elfimage(str(checked.path))
	_path_history.apply_elfimage_dialog(content_set_dialog)
	status_label.text = "ELFIMAGE selected; Create/Open Workspace can bind it read-only."
	return true


func _create_workspace(path: String) -> bool:
	var source := _validate_content_set_path(content_set_path_edit.text)
	if not source.ok:
		status_label.text = str(source.error)
		return false
	var root := _validate_workspace_directory(path)
	if not root.ok:
		status_label.text = str(root.error)
		return false
	var document := _build_default_project_document(str(source.path))
	if not document.ok:
		status_label.text = str(document.error)
		return false
	var created := _workspace.create(str(root.path), str(source.path), document.project)
	if not created.ok:
		status_label.text = "Workspace Create failed: %s" % str(created.error)
		return false
	_activate_workspace_path(str(root.path), created.snapshot)
	status_label.text = "Workspace created and reopened: %s" % str(created.snapshot.project.display_name)
	return true


func _open_workspace(path: String) -> bool:
	var source := _validate_content_set_path(content_set_path_edit.text)
	if not source.ok:
		status_label.text = str(source.error)
		return false
	var root := _validate_workspace_directory(path)
	if not root.ok:
		status_label.text = str(root.error)
		return false
	var opened := _workspace.open(str(root.path), str(source.path))
	if not opened.ok:
		status_label.text = "Workspace Open failed: %s" % str(opened.error)
		return false
	_activate_workspace_path(str(root.path), opened.snapshot)
	status_label.text = "Workspace opened: %s" % str(opened.snapshot.project.display_name)
	return true


func _activate_workspace_path(path: String, _snapshot: Dictionary) -> void:
	workspace_path_edit.text = ProjectSettings.globalize_path(path).simplify_path()
	_active_workspace_root = workspace_path_edit.text
	_active_content_set_root = ProjectSettings.globalize_path(content_set_path_edit.text).simplify_path()
	_path_history.remember_workspace_directory(workspace_path_edit.text)
	_path_history.apply_workspace_dialog(workspace_dialog)


func _build_default_project_document(source_root: String) -> Dictionary:
	var content_set := ContentSetScript.new()
	if not content_set.open(source_root):
		return {"ok": false, "error": content_set.last_error}
	var archives: Array[Dictionary] = []
	var targets: Array[String] = []
	for archive_name in content_set.get_archive_names():
		var reader = content_set.get_reader(archive_name)
		var fingerprint: String = reader.get_archive_fingerprint()
		if fingerprint.is_empty():
			content_set.close()
			return {"ok": false, "error": "Could not fingerprint source archive: %s" % archive_name}
		archives.append({
			"archive": archive_name,
			"sha256": fingerprint,
			"required": archive_name == "mes.arc",
		})
		targets.append(archive_name)
	content_set.close()
	archives.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return str(left.archive) < str(right.archive))
	targets.sort()
	var project := {
		"schema": ContentCoreVersionScript.CONTENT_PROJECT_SCHEMA,
		"project_id": project_id_edit.text.strip_edges(),
		"project_version": "0.1.0",
		"display_name": display_name_edit.text.strip_edges(),
		"project_revision": 1,
		"content_core": {"minimum_version": ContentCoreVersionScript.CORE_VERSION, "maximum_exclusive": "1.0.0"},
		"source_content_set": {
			"profile_id": "original-jp",
			"fingerprint_sha256": ContentProjectScript.compute_content_set_fingerprint(archives),
			"archives": archives,
		},
		"target_archives": targets,
		"compatibility_objective": "mixed",
		"dependencies": [],
		"event_player": {"catalog_id": "kakyu-original-events", "presets": []},
		"overlay_manifest": "manifest.json",
	}
	var validation := ContentProjectScript.new().validate(project)
	return {"ok": true, "project": project} if validation.ok else {"ok": false, "error": str(validation.error)}


func _validate_content_set_path(path: String) -> Dictionary:
	var checked := _validate_startup_path(path)
	if not checked.ok or str(checked.get("kind", "")) != "content_set":
		return {"ok": false, "error": str(checked.get("error", "Choose an ELFIMAGE directory containing mes.arc."))}
	return checked


func _validate_workspace_directory(path: String) -> Dictionary:
	var cleaned := path.strip_edges()
	if cleaned.is_empty():
		return {"ok": false, "error": "Choose a workspace directory."}
	var absolute := ProjectSettings.globalize_path(cleaned).simplify_path()
	if not DirAccess.dir_exists_absolute(absolute):
		return {"ok": false, "error": "Workspace directory does not exist."}
	return {"ok": true, "path": absolute}


func _launch_tool(tool_id: String) -> void:
	var launch := _build_launch_arguments(tool_id)
	if not launch.ok:
		status_label.text = str(launch.error)
		return
	var pid := OS.create_process(str(launch.executable), launch.arguments)
	if pid <= 0:
		status_label.text = "Could not start %s." % tool_id
		return
	status_label.text = "Started %s in an independent Godot window (PID %d)." % [tool_id, pid]


func _build_launch_arguments(tool_id: String) -> Dictionary:
	if not TOOL_SCENES.has(tool_id):
		return {"ok": false, "error": "Unknown content tool: %s" % tool_id}
	var process := preload("res://tools/content_suite/application_process.gd").for_scene(str(TOOL_SCENES[tool_id]))
	if not process.get("ok", false):
		return process
	var arguments: PackedStringArray = process.arguments
	var archive_path := archive_path_edit.text.strip_edges()
	if _workspace.is_open():
		var current_content_root := ProjectSettings.globalize_path(content_set_path_edit.text.strip_edges()).simplify_path()
		if current_content_root != _active_content_set_root or workspace_path_edit.text.simplify_path() != _active_workspace_root:
			return {"ok": false, "error": "Workspace or ELFIMAGE selection changed; open the workspace again before launching."}
		var refreshed := _workspace.refresh()
		if not refreshed.ok:
			return {"ok": false, "error": "Workspace refresh failed before launch: %s" % str(refreshed.error)}
		arguments.append("--")
		arguments.append("--content-set")
		arguments.append(_active_content_set_root)
		arguments.append("--workspace")
		arguments.append(_active_workspace_root)
		if not archive_path.is_empty():
			var selected := _validate_startup_path(archive_path)
			if not selected.ok or str(selected.kind) != "arc":
				return {"ok": false, "error": str(selected.get("error", "Optional startup source must be an ARC file."))}
			if not _is_active_workspace_archive(str(selected.path)):
				return {"ok": false, "error": "Optional startup ARC must belong to the active workspace content set."}
			if not _tool_accepts_archive(tool_id, str(selected.path).get_file().to_lower()):
				return {"ok": false, "error": "Selected ARC is not compatible with %s." % tool_id}
			arguments.append("--archive")
			arguments.append(str(selected.path))
		return {"ok": true, "tool_id": tool_id, "executable": process.executable, "scene": str(TOOL_SCENES[tool_id]), "arguments": arguments}
	if not archive_path.is_empty():
		var checked := _validate_startup_path(archive_path)
		if not checked.ok:
			return checked
		if str(checked.kind) == "content_set" and tool_id != "event_player":
			return {"ok": false, "error": "ELFIMAGE startup directories are supported by Event Player only; clear the path or choose an ARC."}
		arguments.append("--")
		arguments.append(str(checked.path))
	elif tool_id == "event_player" and not content_set_path_edit.text.strip_edges().is_empty():
		var content_set := _validate_content_set_path(content_set_path_edit.text)
		if not content_set.ok:
			return content_set
		arguments.append("--")
		arguments.append(str(content_set.path))
	return {
		"ok": true,
		"tool_id": tool_id,
		"executable": process.executable,
		"scene": str(TOOL_SCENES[tool_id]),
		"arguments": arguments,
	}


func _is_active_workspace_archive(path: String) -> bool:
	var absolute := ProjectSettings.globalize_path(path).simplify_path()
	if absolute.get_base_dir().to_lower() != _active_content_set_root.to_lower():
		return false
	var filename := absolute.get_file().to_lower()
	var snapshot := _workspace.get_snapshot()
	for value in snapshot.get("project", {}).get("source_content_set", {}).get("archives", []):
		if str(value.get("archive", "")).to_lower() == filename:
			return true
	return false


func _tool_accepts_archive(tool_id: String, archive_name: String) -> bool:
	match tool_id:
		"arc_browser": return true
		"mes_editor", "event_player": return archive_name == "mes.arc"
		"audio_editor": return archive_name in ["voice.arc", "bgm.arc", "se.arc", "tina1.arc", "tina2.arc"]
		"image_editor": return archive_name in ["mmo.arc", "data.arc"]
	return false


func _validate_archive_path(path: String) -> Dictionary:
	var checked := _validate_startup_path(path)
	if checked.ok and str(checked.kind) != "arc":
		return {"ok": false, "error": "Startup source must be an ARC file."}
	return checked


func _validate_startup_path(path: String) -> Dictionary:
	var cleaned := path.strip_edges()
	if cleaned.is_empty():
		return {"ok": false, "error": "Choose an ARC file or ELFIMAGE directory, or clear the startup path."}
	var absolute := ProjectSettings.globalize_path(cleaned) if cleaned.begins_with("res://") or cleaned.begins_with("user://") else cleaned
	absolute = absolute.simplify_path()
	if DirAccess.dir_exists_absolute(absolute):
		var directory := DirAccess.open(absolute)
		if directory == null:
			return {"ok": false, "error": "Startup directory could not be opened."}
		var has_mes_arc := false
		for filename in directory.get_files():
			if filename.to_lower() == "mes.arc":
				has_mes_arc = true
				break
		if not has_mes_arc:
			return {"ok": false, "error": "ELFIMAGE startup directory must contain mes.arc."}
		return {"ok": true, "path": absolute, "kind": "content_set"}
	if absolute.get_extension().to_lower() != "arc":
		return {"ok": false, "error": "Startup source must be an ARC file or ELFIMAGE directory."}
	if not FileAccess.file_exists(absolute):
		return {"ok": false, "error": "Startup ARC does not exist."}
	return {"ok": true, "path": absolute, "kind": "arc"}
