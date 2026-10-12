extends "res://tests/test_case.gd"

const LauncherScene := preload("res://tools/content_suite/apps/content_suite_launcher.tscn")
const ToolPathHistoryScript := preload("res://tools/content_suite/tool_path_history.gd")
const TEST_ARC := "user://content_suite_launcher_test.arc"
const TEST_CONTENT_SET := "user://content_suite_launcher_elfimage"
const TEST_WORKSPACE := "user://content_suite_launcher_workspace"
const TEST_PATH_HISTORY := "user://content_suite_launcher_path_history.cfg"
const TEST_REPORT := "user://content_suite_launcher_report.json"
const ProvenanceReportScript := preload("res://tools/content_suite/provenance_report.gd")


func _ready() -> void:
	var file := FileAccess.open(TEST_ARC, FileAccess.WRITE)
	file.store_32(0)
	file.close()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEST_CONTENT_SET))
	_remove_tree(ProjectSettings.globalize_path(TEST_WORKSPACE))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEST_WORKSPACE))
	var mes_file := FileAccess.open(TEST_CONTENT_SET.path_join("mes.arc"), FileAccess.WRITE)
	mes_file.store_32(0)
	mes_file.close()

	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH_HISTORY))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_REPORT))
	var path_history := ToolPathHistoryScript.new(TEST_PATH_HISTORY)
	var launcher: Control = LauncherScene.instantiate()
	launcher.set("_path_history", path_history)
	add_child(launcher)
	await get_tree().process_frame
	_check(get_window().content_scale_mode == Window.CONTENT_SCALE_MODE_DISABLED, "content suite launcher uses native desktop pixels")
	_check(get_window().min_size == Vector2i(1024, 640), "content suite launcher enforces the shared minimum window size")
	_check(launcher.size == Vector2(get_window().size), "content suite launcher fills the desktop client area")
	_check(_controls_fit(launcher), "content suite launcher controls fit the desktop client area")
	var original_window_size := get_window().size
	get_window().size = Vector2i(1920, 1080)
	await get_tree().process_frame
	_check(launcher.size == Vector2(1920, 1080), "content suite launcher reflows at 1920x1080")
	get_window().size = original_window_size

	_check(launcher.call("_set_startup_archive", TEST_ARC), "launcher accepts an existing ARC as optional startup input")
	var expected_arc_directory := ProjectSettings.globalize_path(TEST_ARC).get_base_dir().simplify_path()
	_check(path_history.get_last_source_directory() == expected_arc_directory, "launcher remembers the selected ARC directory")
	_check((launcher.get_node("ArchiveDialog") as FileDialog).current_dir.simplify_path() == expected_arc_directory, "launcher reopens its ARC chooser at the remembered directory")
	var launch: Dictionary = launcher.call("_build_launch_arguments", "mes_editor")
	_check(launch.ok and launch.scene == "res://tools/content_suite/apps/mes_editor.tscn", "launcher maps MES Editor to its independent scene")
	_check(launch.arguments[-2] == "--" and launch.arguments[-1] == ProjectSettings.globalize_path(TEST_ARC), "launcher forwards the selected ARC after the Godot argument boundary")
	_check(launcher.call("_set_startup_content_set", TEST_CONTENT_SET), "launcher accepts an ELFIMAGE directory containing mes.arc")
	var expected_content_root := ProjectSettings.globalize_path(TEST_CONTENT_SET).simplify_path()
	var content_set_dialog: FileDialog = launcher.get_node("ContentSetDialog")
	_check(path_history.get_last_elfimage() == expected_content_root, "launcher persists the validated ELFIMAGE directory under user data")
	_check(content_set_dialog.current_dir.simplify_path() == expected_content_root, "launcher reopens the ELFIMAGE chooser at the selected directory")
	_check(ToolPathHistoryScript.new(TEST_PATH_HISTORY).get_last_elfimage() == expected_content_root, "ELFIMAGE path history survives a new tool session")
	_check((launcher.get_node("Margin/Layout/ContentSetRow/ContentSetPathEdit") as LineEdit).text == expected_content_root, "launcher keeps ELFIMAGE separate from the optional ARC path")
	var status_label: Label = launcher.get_node("Margin/Layout/StatusLabel")
	_check(launcher.get_node("Margin/Layout/WorkspaceRow/ExportReport") is Button, "launcher exposes an Export report button in the workspace row")
	launcher.call("_on_export_report_pressed")
	_check(status_label.text == "Open a workspace before exporting its provenance report.", "launcher export report requires an open workspace")
	_check(launcher.get_node("Margin/Layout/WorkspaceRow/Dashboard") is Button, "launcher exposes a Dashboard button in the workspace row")
	launcher.call("_on_dashboard_pressed")
	_check(status_label.text == "Open a workspace before opening its dashboard.", "launcher dashboard requires an open workspace")
	_check(launcher.call("_create_workspace", TEST_WORKSPACE), "launcher creates and reopens a versioned workspace from the selected content set")
	var expected_workspace_root := ProjectSettings.globalize_path(TEST_WORKSPACE).simplify_path()
	_check(FileAccess.file_exists(expected_workspace_root.path_join("project.json")) and FileAccess.file_exists(expected_workspace_root.path_join("manifest.json")), "launcher workspace create publishes both portable metadata files")
	var project_text := FileAccess.get_file_as_string(expected_workspace_root.path_join("project.json"))
	_check(not project_text.contains(expected_content_root) and not project_text.contains("user://"), "launcher workspace metadata does not persist the machine-specific source path")
	_check((launcher.get_node("Margin/Layout/WorkspaceRow/WorkspacePathEdit") as LineEdit).text == expected_workspace_root, "launcher displays the active workspace root")
	_check(path_history.get_last_workspace_directory() == expected_workspace_root, "launcher remembers the last validated workspace directory")
	_check(launcher.call("_open_workspace", TEST_WORKSPACE), "launcher reopens an existing workspace against the selected content set")
	var workspace_snapshot: Dictionary = launcher.get("_workspace").get_snapshot()
	_check(workspace_snapshot.get("schema", "") == "kakyu_content_workspace_snapshot/v1" and workspace_snapshot.project.target_archives == ["mes.arc"], "launcher exposes the immutable validated workspace generation")
	var report_path := ProjectSettings.globalize_path(TEST_REPORT)
	launcher.call("_on_report_path_selected", report_path)
	_check(status_label.text.begins_with("Exported provenance report (0 replacements, 0 projections, declared not_applicable)"), "launcher exports a provenance report for the active workspace")
	_check(ProvenanceReportScript.read_path(report_path).get("ok", false), "launcher-exported provenance report is accepted by read_path")
	launcher.call("_on_report_path_selected", report_path)
	_check(status_label.text.begins_with("Provenance report export failed"), "launcher refuses a second export to the same path")
	launcher.call("_on_dashboard_pressed")
	var dashboard_panel: KakyuWorkspaceDashboardPanel = launcher.get("dashboard_panel")
	_check(dashboard_panel.visible, "launcher dashboard panel becomes visible for an open workspace")
	_check(str(dashboard_panel.get_report().get("project", {}).get("project_id", "")) == str(workspace_snapshot.project.project_id), "launcher dashboard panel names the workspace's project id")
	dashboard_panel.hide()
	launcher.call("_on_clear_pressed")
	for tool_id in ["arc_browser", "audio_editor", "mes_editor", "event_player", "image_editor"]:
		var workspace_launch: Dictionary = launcher.call("_build_launch_arguments", tool_id)
		_check(workspace_launch.ok and "--content-set" in workspace_launch.arguments and "--workspace" in workspace_launch.arguments, "launcher passes one named workspace context to %s" % tool_id)
	var wrong_source := ProjectSettings.globalize_path(TEST_CONTENT_SET).get_base_dir().path_join("missing_elfimage")
	var content_set_edit: LineEdit = launcher.get_node("Margin/Layout/ContentSetRow/ContentSetPathEdit")
	content_set_edit.text = wrong_source
	_check(not launcher.call("_open_workspace", TEST_WORKSPACE) and launcher.get("_workspace").get_snapshot().generation_sha256 == workspace_snapshot.generation_sha256, "failed launcher workspace open preserves the last valid generation")
	content_set_edit.text = expected_content_root
	_check(launcher.call("_set_startup_archive", TEST_ARC) and not launcher.call("_build_launch_arguments", "mes_editor").ok, "active workspace rejects an optional ARC from outside its bound content set")
	launcher.call("_on_clear_pressed")
	var unknown: Dictionary = launcher.call("_build_launch_arguments", "missing")
	_check(not unknown.ok, "launcher rejects unknown tool identifiers")
	var path_edit: LineEdit = launcher.get_node("Margin/Layout/ArchiveRow/ArchivePathEdit")
	path_edit.text = ProjectSettings.globalize_path(TEST_ARC).get_basename() + ".txt"
	var invalid: Dictionary = launcher.call("_build_launch_arguments", "arc_browser")
	_check(not invalid.ok, "launcher rejects a non-ARC startup path")
	launcher.call("_on_clear_pressed")
	var no_archive: Dictionary = launcher.call("_build_launch_arguments", "image_editor")
	_check(no_archive.ok and not "--archive" in no_archive.arguments and "--workspace" in no_archive.arguments, "launcher can start a workspace tool without an optional startup ARC")

	launcher.queue_free()
	await get_tree().process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_ARC))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_REPORT))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_CONTENT_SET).path_join("mes.arc"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_CONTENT_SET))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH_HISTORY))
	_remove_tree(ProjectSettings.globalize_path(TEST_WORKSPACE))
	get_tree().quit(1 if _failed else 0)


func _controls_fit(launcher: Control) -> bool:
	var margin: Control = launcher.get_node("Margin")
	var layout: Control = launcher.get_node("Margin/Layout")
	var fits := Rect2(Vector2.ZERO, launcher.size).encloses(margin.get_rect()) and margin.get_rect().size.y >= layout.get_combined_minimum_size().y
	if not fits:
		print("Launcher layout diagnostics: viewport=", launcher.size, " margin=", margin.get_rect(), " minimum=", layout.get_combined_minimum_size())
	return fits


func _remove_tree(path: String) -> void:
	var directory := DirAccess.open(path)
	if directory == null:
		return
	directory.list_dir_begin()
	var name := directory.get_next()
	while not name.is_empty():
		var child := path.path_join(name)
		if directory.current_is_dir():
			_remove_tree(child)
		else:
			DirAccess.remove_absolute(child)
		name = directory.get_next()
	directory.list_dir_end()
	DirAccess.remove_absolute(path)
