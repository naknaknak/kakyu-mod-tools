extends "res://tests/test_case.gd"

const ContentProjectScript := preload("res://content_core/content_project.gd")
const ContentWorkspaceScript := preload("res://content_core/content_workspace.gd")
const OverlayPackageScript := preload("res://content_core/overlay_package.gd")
const ProvenanceReportScript := preload("res://tools/content_suite/provenance_report.gd")
const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")
const DashboardPanelScript := preload("res://tools/content_suite/apps/workspace_dashboard_panel.gd")
const SyntheticArc := preload("res://tests/synthetic_arc.gd")

const TEST_ROOT := "user://workspace_dashboard_test"


func _ready() -> void:
	_cleanup()
	var source_root := TEST_ROOT + "/ELFIMAGE"
	var workspace_root := TEST_ROOT + "/my_mod"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(source_root))
	var synthetic_mes := _synthetic_mes()
	SyntheticArc.write_arc(source_root + "/mes.arc", [{"name": "TEST.MES", "data": synthetic_mes}])
	SyntheticArc.write_arc(source_root + "/mmo.arc", [{"name": "ONE.MMO", "data": PackedByteArray([4, 5, 6])}])
	var mes_sha := FileAccess.get_sha256(source_root + "/mes.arc")
	var mmo_sha := FileAccess.get_sha256(source_root + "/mmo.arc")
	var project_document := _project_document(mes_sha, mmo_sha, "mixed")
	var workspace := ContentWorkspaceScript.new()
	var created := workspace.create(workspace_root, source_root, project_document)
	_check(created.get("ok", false), "workspace dashboard fixture creates a named workspace")

	var replacement_bytes := PackedByteArray([9, 9, 9])
	var staged_replacement := workspace.stage_replacements("mmo.arc", {"ONE.MMO": replacement_bytes}, "remake_only", "not_applicable")
	_check(staged_replacement.get("ok", false), "workspace dashboard fixture stages one replacement")

	var hello_sha := OverlayPackageScript.sha256_bytes("HELLO".to_ascii_buffer())
	var staged_projection := workspace.stage_mes_text_projections(
		"mes.arc", {"TEST.MES": [{"source_offset": 0, "raw_sha256": hello_sha, "text": "번역문"}]}
	)
	_check(staged_projection.get("ok", false), "workspace dashboard fixture stages one MES text projection")

	var snapshot := workspace.get_snapshot()
	var replacement_record := OverlayPackageScript.new().find_replacement(snapshot.manifest, "mmo.arc", "ONE.MMO")
	workspace.close()

	var panel: KakyuWorkspaceDashboardPanel = DashboardPanelScript.new()
	add_child(panel)
	await get_tree().process_frame
	panel.show_for_workspace(workspace_root, source_root)
	_check(panel.visible, "workspace dashboard panel becomes visible for an open workspace")
	var report := panel.get_report()
	_check(not report.is_empty(), "workspace dashboard panel holds a built report")
	_check(panel.get_error().is_empty(), "workspace dashboard panel reports no error for a valid workspace")

	_check(panel.project_label.text.contains(str(snapshot.project.project_id)), "project label names the workspace's project id")
	_check(panel.project_label.text.contains("revision %d" % int(snapshot.project.project_revision)) and int(snapshot.project.project_revision) == 1, "project label names revision 1")
	_check(panel.core_label.text.contains(ContentCoreVersionScript.CORE_VERSION), "core label names the running Content Core version")
	_check(panel.core_label.text.contains("within range"), "core label reports the running Core version within the project range")
	_check(panel.generation_label.text.contains(str(snapshot.generation_sha256).substr(0, 12)), "generation label carries the shortened generation hash")
	_check(not panel.generation_label.text.contains(str(snapshot.generation_sha256)), "generation label does not spell out the full generation hash")
	_check(panel.generation_label.tooltip_text.contains(str(snapshot.generation_sha256)), "generation label tooltip carries the full generation hash")

	var archive_root := panel.archives_tree.get_root()
	var archive_rows := []
	var archive_item := archive_root.get_first_child() if archive_root != null else null
	while archive_item != null:
		archive_rows.append(archive_item)
		archive_item = archive_item.get_next()
	_check(archive_rows.size() == report.source_content_set.archives.size(), "archives tree has one row per bound archive")
	for index in range(archive_rows.size()):
		var expected: Dictionary = report.source_content_set.archives[index]
		var row: TreeItem = archive_rows[index]
		_check(row.get_text(0) == str(expected.archive), "archive row %s names its archive" % str(expected.archive))
		_check(row.get_text(1) == str(int(expected.bytes)), "archive row %s carries its byte count" % str(expected.archive))
		_check(row.get_text(2) == str(int(expected.entries)), "archive row %s carries its entry count" % str(expected.archive))

	var changes_root := panel.changes_tree.get_root()
	var change_rows := []
	var change_item := changes_root.get_first_child() if changes_root != null else null
	while change_item != null:
		change_rows.append(change_item)
		change_item = change_item.get_next()
	_check(change_rows.size() == 2, "changes tree has two rows (one replacement, one projection)")
	var replacement_row: TreeItem = change_rows[0]
	_check(replacement_row.get_text(0) == "replacement", "first change row is the replacement")
	_check(replacement_row.get_text(3) == "3 → %d" % replacement_bytes.size(), "replacement row shows its size transition")
	_check(replacement_row.get_text(4) == "remake_only", "replacement row shows its compatibility")
	_check(replacement_row.get_text(6) == "-", "replacement row with no authoring bundle shows a dash")
	var projection_row: TreeItem = change_rows[1]
	_check(projection_row.get_text(0) == "projection", "second change row is the projection")
	_check(projection_row.get_text(3) == "1 edit(s)", "projection row shows its edit count")
	_check(projection_row.get_text(6) == "-", "projection row authoring column is a dash")

	_check(panel.compatibility_label.text.contains("consistent") and not panel.compatibility_label.text.contains("NOT consistent"), "compatibility label says consistent")
	_check(panel.verification_label.text.contains("Verified 1 replacement blob(s), 1 projection file(s)"), "verification label counts one blob and one projection")

	var replacement_blob_path := ProjectSettings.globalize_path(workspace_root).path_join(str(replacement_record.replacement_path))
	var original_blob_bytes := FileAccess.get_file_as_bytes(replacement_blob_path)
	var mutated_blob_bytes := original_blob_bytes.duplicate()
	mutated_blob_bytes[mutated_blob_bytes.size() - 1] ^= 0x01
	_write_bytes(replacement_blob_path, mutated_blob_bytes)
	panel.refresh()
	_check(panel.verification_label.text.begins_with("Workspace verification failed"), "verification label reports a failed refresh after a blob mutation")
	_check(panel.archives_tree.get_root() == null or panel.archives_tree.get_root().get_first_child() == null, "archives tree is empty after a failed refresh")
	_check(panel.changes_tree.get_root() == null or panel.changes_tree.get_root().get_first_child() == null, "changes tree is empty after a failed refresh")
	_check(panel.export_button.disabled, "export is disabled after a failed refresh")

	_write_bytes(replacement_blob_path, original_blob_bytes)
	var restored := panel.refresh()
	_check(restored.get("ok", false), "refresh succeeds again once the replacement blob is restored")

	var export_path := ProjectSettings.globalize_path(TEST_ROOT + "/export.json")
	panel.call("_on_report_path_selected", export_path)
	_check(FileAccess.file_exists(export_path), "export report writes a file")
	_check(ProvenanceReportScript.read_path(export_path).get("ok", false), "exported report is accepted by read_path")
	_check(panel.verification_label.text.begins_with("Exported report to"), "verification label confirms the export")
	panel.call("_on_report_path_selected", export_path)
	_check(not panel.verification_label.text.begins_with("Exported report to"), "second export to the same path shows the refusal")

	panel.queue_free()
	await get_tree().process_frame

	_check(
		DashboardPanelScript.version_within_range("0.337.0", "0.146.0", "1.0.0"),
		"version range helper accepts a version within its half-open range"
	)
	_check(
		not DashboardPanelScript.version_within_range("1.0.0", "0.146.0", "1.0.0"),
		"version range helper excludes the exclusive maximum"
	)
	_check(
		not DashboardPanelScript.version_within_range("0.145.9", "0.146.0", "1.0.0"),
		"version range helper excludes a version below the minimum"
	)

	_cleanup()
	get_tree().quit(1 if _failed else 0)


func _project_document(mes_sha: String, mmo_sha: String, objective: String) -> Dictionary:
	var archives: Array = [
		{"archive": "mes.arc", "sha256": mes_sha, "required": true},
		{"archive": "mmo.arc", "sha256": mmo_sha, "required": false},
	]
	return {
		"schema": ContentCoreVersionScript.CONTENT_PROJECT_SCHEMA,
		"project_id": "workspace.dashboard.test",
		"project_version": "0.1.0",
		"display_name": "Workspace Dashboard Test",
		"project_revision": 1,
		"content_core": {"minimum_version": ContentCoreVersionScript.CORE_VERSION, "maximum_exclusive": "1.0.0"},
		"source_content_set": {
			"profile_id": "synthetic-test",
			"fingerprint_sha256": ContentProjectScript.compute_content_set_fingerprint(archives),
			"archives": archives,
		},
		"target_archives": ["mes.arc", "mmo.arc"],
		"compatibility_objective": objective,
		"dependencies": [],
		"event_player": {"catalog_id": "kakyu-original-events", "presets": []},
		"overlay_manifest": "manifest.json",
	}


func _synthetic_mes() -> PackedByteArray:
	var code := PackedByteArray()
	code.append(0x01)
	code.append_array("HELLO".to_ascii_buffer())
	code.append(0)
	code.append_array(PackedByteArray([0x0B, 0xF3, 0x34, 0x12, 0xFF]))
	SyntheticArc.append_u32(code, 0)
	var mes := PackedByteArray()
	SyntheticArc.append_u32(mes, 1)
	SyntheticArc.append_u32(mes, 0)
	mes.append_array(code)
	return mes


func _write_bytes(path: String, data: PackedByteArray) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(data)
	file.close()


func _cleanup() -> void:
	var absolute := ProjectSettings.globalize_path(TEST_ROOT)
	if DirAccess.dir_exists_absolute(absolute):
		_remove_tree(absolute)


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
