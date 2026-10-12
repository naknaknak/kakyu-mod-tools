extends "res://tests/test_case.gd"

const ContentProjectScript := preload("res://content_core/content_project.gd")
const ContentWorkspaceScript := preload("res://content_core/content_workspace.gd")
const OverlayPackageScript := preload("res://content_core/overlay_package.gd")
const PublicationLockScript := preload("res://content_core/publication_lock.gd")
const ArcReaderScript := preload("res://content_core/arc_reader.gd")
const SyntheticArc := preload("res://tests/synthetic_arc.gd")

const TEST_ROOT := "user://content_workspace_test"


func _ready() -> void:
	_cleanup()
	var absolute_root := ProjectSettings.globalize_path(TEST_ROOT)
	var source_root := TEST_ROOT + "/ELFIMAGE"
	var project_root := TEST_ROOT + "/my_mod"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(source_root))
	SyntheticArc.write_arc(source_root + "/mes.arc", [
		{"name": "TEST.MES", "data": PackedByteArray([1, 2, 3])},
	])
	SyntheticArc.write_arc(source_root + "/mmo.arc", [
		{"name": "ONE.MMO", "data": PackedByteArray([4, 5, 6])},
		{"name": "TWO.MMO", "data": PackedByteArray([7, 8, 9])},
	])
	var source_mes_sha := FileAccess.get_sha256(source_root + "/mes.arc")
	var source_mmo_sha := FileAccess.get_sha256(source_root + "/mmo.arc")
	var project_document := _project_document(source_mes_sha, source_mmo_sha)
	var workspace := ContentWorkspaceScript.new()
	var created := workspace.create(project_root, source_root, project_document)
	_check(created.get("ok", false), "workspace creates project and empty overlay as one validated service operation")
	_check(FileAccess.file_exists(project_root + "/project.json") and FileAccess.file_exists(project_root + "/manifest.json"), "workspace creation publishes both metadata authorities")
	var first_snapshot := workspace.get_snapshot()
	_check(first_snapshot.schema == "kakyu_content_workspace_snapshot/v1" and first_snapshot.replacement_count == 0 and first_snapshot.projection_count == 0, "workspace exposes the versioned empty immutable snapshot")
	_check(str(first_snapshot.generation_sha256).length() == 64 and str(first_snapshot.project_sha256).length() == 64 and str(first_snapshot.manifest_sha256).length() == 64, "workspace snapshot binds project, manifest, and combined generation hashes")
	_check(not _contains_machine_path(first_snapshot), "workspace snapshot excludes machine-specific source and project paths")
	var detached := workspace.get_snapshot()
	detached.project.display_name = "mutated"
	_check(workspace.get_snapshot().project.display_name == "Workspace Test", "workspace snapshots are returned as deep copies")
	var create_conflict := ContentWorkspaceScript.new().create(project_root, source_root, project_document)
	_check(not create_conflict.get("ok", false), "workspace create refuses to replace an existing project or manifest")

	var first_stage := workspace.stage_replacements(
		"mmo.arc", {"ONE.MMO": PackedByteArray([10, 11, 12])}
	)
	_check(first_stage.get("ok", false) and first_stage.snapshot.replacement_count == 1, "workspace publishes one intentional replacement and refreshes its snapshot")
	var snapshot_after_first := workspace.get_snapshot()
	_check(snapshot_after_first.generation_sha256 != first_snapshot.generation_sha256, "workspace generation changes when the manifest changes")
	var rejected_target := workspace.stage_replacements("mes.arc", {"TEST.MES": PackedByteArray([9])}, "remake_only", "not_applicable")
	_check(not rejected_target.get("ok", false) and workspace.get_snapshot().generation_sha256 == snapshot_after_first.generation_sha256, "workspace rejects a source-bound but non-target archive without changing its snapshot")

	var external_reader := ArcReaderScript.new()
	_check(external_reader.open(source_root + "/mmo.arc"), "external tool fixture opens the same read-only source ARC")
	var external_stage := OverlayPackageScript.new().stage_replacement(
		project_root, external_reader, "mmo.arc", "TWO.MMO", PackedByteArray([13, 14, 15])
	)
	_check(external_stage.get("ok", false), "external specialist tool publishes an unrelated current manifest record")
	var merged := workspace.stage_replacements(
		"mmo.arc", {"ONE.MMO": PackedByteArray([16, 17, 18])}
	)
	_check(merged.get("ok", false) and merged.snapshot.replacement_count == 2, "workspace merges its intentional target over the latest manifest")
	var merged_manifest := OverlayPackageScript.new().load_manifest(project_root)
	_check(merged_manifest.get("ok", false) and _replacement_sha(merged_manifest.manifest, "TWO.MMO") == OverlayPackageScript.sha256_bytes(PackedByteArray([13, 14, 15])), "workspace merge preserves the unrelated externally published record byte identity")
	var valid_manifest_bytes := FileAccess.get_file_as_bytes(project_root + "/manifest.json")
	var before_out_of_scope := workspace.get_snapshot()
	var external_mes_reader := ArcReaderScript.new()
	_check(external_mes_reader.open(source_root + "/mes.arc"), "out-of-scope fixture opens the read-only MES source")
	var out_of_scope_stage := OverlayPackageScript.new().stage_replacement(
		project_root, external_mes_reader, "mes.arc", "TEST.MES", PackedByteArray([31, 32, 33])
	)
	_check(out_of_scope_stage.get("ok", false), "legacy direct publisher can produce a structurally valid record outside project intent")
	var out_of_scope_refresh := workspace.refresh()
	_check(not out_of_scope_refresh.get("ok", false) and workspace.get_snapshot().generation_sha256 == before_out_of_scope.generation_sha256, "workspace rejects an externally added record outside target archives and retains its active generation")
	_write_bytes(project_root + "/manifest.json", valid_manifest_bytes)
	_check(workspace.refresh().get("ok", false), "workspace reopens after the valid manifest revision is restored")
	external_mes_reader.close()

	var workspace_lock := PublicationLockScript.new().acquire(ProjectSettings.globalize_path(project_root), ".workspace.lock")
	_check(workspace_lock.get("ok", false), "workspace lock fixture acquires the service coordination boundary")
	var blocked := workspace.stage_replacements("mmo.arc", {"ONE.MMO": PackedByteArray([19, 20, 21])})
	_check(not blocked.get("ok", false) and str(blocked.get("error", "")).contains("locked by process"), "workspace change cannot enter while another process owns the workspace lock")
	_check(PublicationLockScript.new().release(workspace_lock).get("ok", false), "workspace lock fixture releases safely")

	var before_project_update := workspace.get_snapshot()
	var project_update: Dictionary = before_project_update.project.duplicate(true)
	project_update.project_revision = int(project_update.project_revision) + 1
	project_update.project_version = "0.2.0"
	project_update.display_name = "Workspace Test Updated"
	var updated := workspace.publish_project_update(project_update)
	_check(updated.get("ok", false) and updated.snapshot.project.project_revision == 2, "workspace publishes an exact next project revision")
	_check(updated.snapshot.manifest_sha256 == before_project_update.manifest_sha256 and updated.snapshot.replacement_count == 2, "project metadata update preserves the complete manifest snapshot")

	var invalid_targets: Dictionary = workspace.get_snapshot().project.duplicate(true)
	invalid_targets.project_revision = int(invalid_targets.project_revision) + 1
	invalid_targets.target_archives = ["mes.arc"]
	var project_sha_before_invalid := FileAccess.get_sha256(project_root + "/project.json")
	var rejected_project := workspace.publish_project_update(invalid_targets)
	_check(not rejected_project.get("ok", false) and FileAccess.get_sha256(project_root + "/project.json") == project_sha_before_invalid, "project update cannot orphan an existing overlay target")

	var active_before_external := workspace.get_snapshot()
	var external_project: Dictionary = active_before_external.project.duplicate(true)
	external_project.project_revision = int(external_project.project_revision) + 1
	external_project.project_version = "0.3.0"
	external_project.display_name = "External Project Revision"
	var external_publish := ContentProjectScript.new().publish(
		project_root, external_project, true, str(active_before_external.project_sha256)
	)
	_check(external_publish.get("ok", false), "external project publisher advances the portable project revision")
	var stale_stage := workspace.stage_replacements("mmo.arc", {"ONE.MMO": PackedByteArray([22, 23, 24])})
	_check(not stale_stage.get("ok", false) and workspace.get_snapshot().project.project_revision == 2, "stale workspace refuses content publication until its project is refreshed")
	var refreshed := workspace.refresh()
	_check(refreshed.get("ok", false) and refreshed.snapshot.project.project_revision == 3 and refreshed.snapshot.replacement_count == 2, "workspace refresh atomically adopts compatible external project and manifest revisions")

	var stable_snapshot := workspace.get_snapshot()
	var original_mmo_bytes := FileAccess.get_file_as_bytes(source_root + "/mmo.arc")
	var changed_mmo_bytes := original_mmo_bytes.duplicate()
	changed_mmo_bytes[changed_mmo_bytes.size() - 1] ^= 0x01
	_write_bytes(source_root + "/mmo.arc", changed_mmo_bytes)
	var changed_source_refresh := workspace.refresh()
	_check(not changed_source_refresh.get("ok", false) and workspace.get_snapshot().generation_sha256 == stable_snapshot.generation_sha256, "source ARC mutation rejects refresh and preserves the last immutable snapshot")
	var changed_source_stage := workspace.stage_replacements("mmo.arc", {"ONE.MMO": PackedByteArray([25, 26, 27])})
	_check(not changed_source_stage.get("ok", false), "workspace-bound overlay publisher rejects a source ARC that no longer matches project lineage")
	_write_bytes(source_root + "/mmo.arc", original_mmo_bytes)
	_check(workspace.refresh().get("ok", false), "workspace reopens after the exact source ARC bytes are restored")

	var wrong_source_root := TEST_ROOT + "/wrong_source"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(wrong_source_root))
	SyntheticArc.write_arc(wrong_source_root + "/mes.arc", [{"name": "TEST.MES", "data": PackedByteArray([99])}])
	SyntheticArc.write_arc(wrong_source_root + "/mmo.arc", [{"name": "ONE.MMO", "data": PackedByteArray([99])}])
	var before_wrong_open := workspace.get_snapshot()
	var wrong_open := workspace.open(project_root, wrong_source_root)
	_check(not wrong_open.get("ok", false) and workspace.get_snapshot().generation_sha256 == before_wrong_open.generation_sha256, "failed workspace open does not replace the last valid active snapshot")

	var contract_fp := FileAccess.get_file_as_string("res://config/contracts/mod_event_definition_v1/contract_fingerprint").strip_edges()
	var cells_fp := FileAccess.get_file_as_string("res://config/contracts/state_cells_v1/cells_fingerprint").strip_edges()
	var definition_document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://config/contracts/mod_event_definition_v1/valid/new_event_plain.json"))
	definition_document.contract_fingerprint = contract_fp
	definition_document.cells_fingerprint = cells_fp
	var definition_bytes := (JSON.stringify(definition_document, "  ") + "\n").to_utf8_buffer()
	var definition_id := str(definition_document.id)

	var accepting_validator := func(bytes: PackedByteArray) -> Dictionary:
		return {"ok": true}
	var staged_definitions := workspace.stage_mod_definitions([definition_bytes], accepting_validator)
	_check(
		staged_definitions.get("ok", false)
		and int(staged_definitions.snapshot.definition_count) == 1
		and str(staged_definitions.snapshot.mod_id) == "samplemod",
		"workspace stages a mod definition through a stub validator and refreshes definition_count/mod_id"
	)

	var snapshot_before_rejected_definition := workspace.get_snapshot()
	var rejecting_validator := func(bytes: PackedByteArray) -> Dictionary:
		return {"ok": false, "reason": "bad_placeholder", "detail": "x"}
	var rejected_definition := workspace.stage_mod_definitions([definition_bytes], rejecting_validator)
	_check(
		not rejected_definition.get("ok", false) and str(rejected_definition.get("error", "")).contains("bad_placeholder"),
		"workspace refuses a batch when the validator reports a failing verdict, naming the reason"
	)
	_check(
		workspace.get_snapshot().manifest_sha256 == snapshot_before_rejected_definition.manifest_sha256
		and int(workspace.get_snapshot().definition_count) == int(snapshot_before_rejected_definition.definition_count),
		"a rejected mod definition batch leaves the manifest sha and snapshot unchanged"
	)

	var null_callable_result := workspace.stage_mod_definitions([definition_bytes], Callable())
	_check(not null_callable_result.get("ok", false), "a null Callable validator is refused, not treated as a pass")

	var removal_result := workspace.remove_mod_definition(definition_id)
	_check(
		removal_result.get("ok", false) and int(removal_result.snapshot.definition_count) == 0,
		"remove_mod_definition updates the workspace snapshot"
	)

	external_reader.close()
	workspace.close()
	_check(not workspace.is_open() and workspace.get_snapshot().is_empty(), "workspace close releases readers and clears runtime metadata")
	_check(FileAccess.get_sha256(source_root + "/mes.arc") == source_mes_sha and FileAccess.get_sha256(source_root + "/mmo.arc") == source_mmo_sha, "workspace operations leave every selected source ARC unchanged")
	_check(not DirAccess.dir_exists_absolute(absolute_root.path_join("my_mod/.workspace.lock")) and not DirAccess.dir_exists_absolute(absolute_root.path_join("my_mod/.project.lock")) and not DirAccess.dir_exists_absolute(absolute_root.path_join("my_mod/.manifest.lock")), "workspace operations leave no publication lock directories")
	_cleanup()
	get_tree().quit(1 if _failed else 0)


func _project_document(mes_sha: String, mmo_sha: String) -> Dictionary:
	var archives: Array = [
		{"archive": "mes.arc", "sha256": mes_sha, "required": true},
		{"archive": "mmo.arc", "sha256": mmo_sha, "required": false},
	]
	return {
		"schema": "kakyu_content_project/v1",
		"project_id": "workspace.test",
		"project_version": "0.1.0",
		"display_name": "Workspace Test",
		"project_revision": 1,
		"content_core": {"minimum_version": "0.147.0", "maximum_exclusive": "1.0.0"},
		"source_content_set": {
			"profile_id": "synthetic-test",
			"fingerprint_sha256": ContentProjectScript.compute_content_set_fingerprint(archives),
			"archives": archives,
		},
		"target_archives": ["mmo.arc"],
		"compatibility_objective": "mixed",
		"dependencies": [],
		"event_player": {"catalog_id": "kakyu-original-events", "presets": []},
		"overlay_manifest": "manifest.json",
	}


func _replacement_sha(manifest: Dictionary, entry_name: String) -> String:
	for value in manifest.replacements:
		var record: Dictionary = value
		if str(record.target_entry) == entry_name:
			return str(record.replacement_sha256)
	return ""


func _contains_machine_path(value) -> bool:
	if value is Dictionary:
		for nested in value.values():
			if _contains_machine_path(nested):
				return true
	elif value is Array:
		for nested in value:
			if _contains_machine_path(nested):
				return true
	elif value is String:
		var text: String = value
		return text.contains("user://") or text.contains("AppData") or (text.length() >= 3 and text[1] == ":" and (text[2] == "/" or text[2] == "\\"))
	return false


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
