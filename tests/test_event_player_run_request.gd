extends "res://tests/test_case.gd"

const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")
const ContentProjectScript := preload("res://content_core/content_project.gd")
const ContentWorkspaceScript := preload("res://content_core/content_workspace.gd")
const ContentLaunchContextScript := preload("res://content_core/content_launch_context.gd")
const MesEditorRunRequestScript := preload("res://content_core/mes_editor_run_request.gd")
const ContentSelectionScript := preload("res://content_core/content_selection.gd")
const EventPlayerScene := preload("res://tools/content_suite/apps/event_player.tscn")
const SyntheticArc := preload("res://tests/synthetic_arc.gd")

const ROOT := "user://event_player_run_request_test"


func _ready() -> void:
	var absolute_root := ProjectSettings.globalize_path(ROOT)
	_remove_tree(absolute_root)
	var source_root := absolute_root.path_join("ELFIMAGE")
	var workspace_root := absolute_root.path_join("workspace")
	DirAccess.make_dir_recursive_absolute(source_root)
	var mes := _synthetic_mes()
	var archive_path := source_root.path_join("mes.arc")
	SyntheticArc.write_arc(archive_path, [{"name": "TEST.MES", "data": mes}])
	var source_archive_sha := FileAccess.get_sha256(archive_path)
	var source_entry_sha := _sha256(mes)
	var workspace := ContentWorkspaceScript.new()
	var created := workspace.create(
		workspace_root, source_root, _project(source_archive_sha)
	)
	_check(created.get("ok", false), "Event Player Run fixture creates a named workspace")
	var snapshot := workspace.get_snapshot()
	workspace.close()
	var builder := MesEditorRunRequestScript.new()
	var request := builder.build(
		snapshot,
		{
			"archive": "mes.arc", "entry": "TEST.MES", "source": "original_arc",
			"source_archive_sha256": source_archive_sha,
			"source_entry_sha256": source_entry_sha,
			"effective_entry_sha256": source_entry_sha,
			"effective_byte_count": mes.size(),
		},
		{
			"mode": "analysis_entry", "start_kind": "code_offset", "start_value": 0,
			"catalog_id": "", "event_id": "", "preset_id": "", "preset_source": "none",
		},
		{
			"kind": "exact_original",
			"contract_schema": ContentCoreVersionScript.MES_EXACT_ORIGINAL_INTERFACE_SCHEMA,
			"proof_sha256": source_entry_sha,
			"source_entry_sha256": source_entry_sha,
			"output_entry_sha256": source_entry_sha,
			"compatibility": "original_engine_compatible",
			"control_flow_compatible": true,
		}
	)
	_check(request.get("ok", false), "Event Player Run fixture builds an exact-original request")
	var request_path := absolute_root.path_join("analysis.run.json")
	_write_text(request_path, JSON.stringify(request, "", true, true) + "\n")

	var player: KakyuEventPlayer = EventPlayerScene.instantiate()
	add_child(player)
	await get_tree().process_frame
	var catalog_event_id := "original/eventb01/13c-00000f93"
	var catalog_entry_sha := "3c4ba17751eb362130fef821e00bb7b1d2f7f909652a9a6c876bf6da0f8efadf"
	var catalog_binding := {
		"launch": {
			"mode": "catalog_event", "catalog_id": "kakyu-original-events",
			"event_id": catalog_event_id, "preset_id": "13c-b01-baseline",
			"preset_source": "catalog",
		},
		"content": {
			"archive": "mes.arc", "entry": "EVENTB01.MES",
			"effective_entry_sha256": catalog_entry_sha,
		},
	}
	var catalog_selected: Dictionary = player._build_catalog_run_play_request(catalog_binding, snapshot
	)
	_check(
		catalog_selected.get("ok", false)
		and str(catalog_selected.play_request.event_id) == catalog_event_id
		and str(catalog_selected.play_request.preset.preset_id) == "13c-b01-baseline",
		"Event Player resolves a Run request's exact catalog preset"
	)
	var project_snapshot: Dictionary = snapshot.duplicate(true)
	project_snapshot.project.event_player.presets = [{
		"preset_id": "workspace-daytime", "label": "Workspace daytime",
		"kind": "catalog_reference", "event_id": catalog_event_id,
		"catalog_preset_id": "13c-b01-baseline", "writes": [],
	}]
	var project_binding: Dictionary = catalog_binding.duplicate(true)
	project_binding.launch.preset_id = "workspace-daytime"
	project_binding.launch.preset_source = "project"
	var project_selected: Dictionary = player._build_catalog_run_play_request(project_binding, project_snapshot
	)
	_check(
		project_selected.get("ok", false)
		and str(project_selected.play_request.preset.preset_id) == "workspace-daytime"
		and (project_selected.play_request.preset.writes as Array).is_empty(),
		"Event Player resolves a validated workspace project preset over its catalog base"
	)
	var changed_callee: Dictionary = catalog_binding.duplicate(true)
	changed_callee.content.effective_entry_sha256 = "0".repeat(64)
	_check(
		not (player._build_catalog_run_play_request(changed_callee, snapshot
		) as Dictionary).get("ok", false),
		"Catalog Run rejects a changed callee without a mapped interface"
	)
	player._apply_startup_arguments(PackedStringArray([
		"--content-set", source_root,
		"--workspace", workspace_root,
		"--run-request", request_path,
	]))
	await get_tree().process_frame
	_check(
		str(player.get("_selected_entry")) == "TEST.MES"
		and str(player.get("_document").get("entry_sha256", "")) == source_entry_sha
		and str(player.get("_view_mode")) == "analysis"
		and (player.get_node("Margin/Layout/MainSplit/Right/RunBar/IntroEdit") as LineEdit).text == "0x0"
		and not str(player.get("_preview_result_status")).is_empty(),
		"Event Player transactionally starts the exact selected Analysis Run"
	)
	var retained_entry := str(player.get("_selected_entry"))
	var retained_hash := str(player.get("_document").get("entry_sha256", ""))
	var retained_status := str(player.get("_preview_result_status"))
	var stale := request.duplicate(true)
	stale.workspace.generation_sha256 = "0".repeat(64)
	stale.payload_sha256 = builder.fingerprint(stale)
	var stale_path := absolute_root.path_join("stale.run.json")
	_write_text(stale_path, JSON.stringify(stale, "", true, true) + "\n")
	var rejected: Dictionary = player._consume_run_request(stale_path, "")
	_check(
		not rejected.get("ok", false)
		and str(player.get("_selected_entry")) == retained_entry
		and str(player.get("_document").get("entry_sha256", "")) == retained_hash
		and str(player.get("_preview_result_status")) == retained_status,
		"a stale Run request is rejected before the active Event Player session changes"
	)
	var overlay_sourced := request.duplicate(true)
	overlay_sourced.content = (overlay_sourced.content as Dictionary).duplicate(true)
	overlay_sourced.content.source = "overlay"
	overlay_sourced.payload_sha256 = builder.fingerprint(overlay_sourced)
	var overlay_sourced_path := absolute_root.path_join("overlay-sourced.run.json")
	_write_text(overlay_sourced_path, JSON.stringify(overlay_sourced, "", true, true) + "\n")
	var overlay_sourced_rejected: Dictionary = player._consume_run_request(overlay_sourced_path, "")
	_check(
		not overlay_sourced_rejected.get("ok", false)
		and str(player.get("_selected_entry")) == retained_entry
		and str(player.get("_document").get("entry_sha256", "")) == retained_hash
		and str(player.get("_preview_result_status")) == retained_status,
		"an overlay-sourced Run request is rejected before the active Event Player session changes"
	)
	var semantic_diff_interface := request.duplicate(true)
	semantic_diff_interface.interface = (semantic_diff_interface.interface as Dictionary).duplicate(true)
	semantic_diff_interface.interface.kind = "semantic_diff"
	semantic_diff_interface.payload_sha256 = builder.fingerprint(semantic_diff_interface)
	var semantic_diff_interface_path := absolute_root.path_join("semantic-diff-interface.run.json")
	_write_text(semantic_diff_interface_path, JSON.stringify(semantic_diff_interface, "", true, true) + "\n")
	var semantic_diff_interface_rejected: Dictionary = player._consume_run_request(semantic_diff_interface_path, "")
	_check(
		not semantic_diff_interface_rejected.get("ok", false)
		and str(player.get("_selected_entry")) == retained_entry
		and str(player.get("_document").get("entry_sha256", "")) == retained_hash
		and str(player.get("_preview_result_status")) == retained_status,
		"a semantic-diff interface Run request is rejected before the active Event Player session changes"
	)
	var unnecessary_proof_path := absolute_root.path_join("proof.json")
	_write_text(unnecessary_proof_path, "{}\n")
	var proof_rejected: Dictionary = player._consume_run_request(request_path, unnecessary_proof_path
	)
	_check(
		not proof_rejected.get("ok", false)
		and str(player.get("_selected_entry")) == retained_entry,
		"exact-original Analysis Run rejects an unrelated semantic proof"
	)
	_check(
		FileAccess.get_sha256(archive_path) == source_archive_sha,
		"Event Player Run consumption leaves the source ARC unchanged"
	)

	var selection_builder := ContentSelectionScript.new()
	var selection_document := selection_builder.build(
		snapshot,
		{
			"archive": "mes.arc", "entry": "TEST.MES", "source_entry_sha256": source_entry_sha,
			"catalog_id": "", "event_id": "", "preset_id": "",
		},
		"mes_editor"
	)
	_check(selection_document.get("ok", false), "Event Player Run fixture builds a content selection for TEST.MES")
	var selection_path := absolute_root.path_join("test.selection.json")
	_write_text(selection_path, JSON.stringify(selection_document, "", true, true) + "\n")
	player._apply_startup_arguments(PackedStringArray([
		"--content-set", source_root,
		"--workspace", workspace_root,
		"--selection", selection_path,
	]))
	await get_tree().process_frame
	_check(
		str(player.get("_selected_entry")) == "TEST.MES"
		and str(player.get("_document").get("entry_sha256", "")) == source_entry_sha
		and str(player.get("_view_mode")) == "analysis"
		and (player.get_node("Margin/Layout/StatusLabel") as Label).text.contains("Selection from mes_editor: TEST.MES"),
		"Event Player startup with --selection loads the entry into Analysis, naming the producer"
	)

	var wrong_hash_selection := selection_document.duplicate(true)
	wrong_hash_selection.selection = (wrong_hash_selection.selection as Dictionary).duplicate(true)
	wrong_hash_selection.selection.source_entry_sha256 = "0".repeat(64)
	wrong_hash_selection.payload_sha256 = selection_builder.fingerprint(wrong_hash_selection)
	var wrong_hash_selection_path := absolute_root.path_join("wrong-hash.selection.json")
	_write_text(wrong_hash_selection_path, JSON.stringify(wrong_hash_selection, "", true, true) + "\n")
	player._apply_startup_arguments(PackedStringArray([
		"--content-set", source_root,
		"--workspace", workspace_root,
		"--selection", wrong_hash_selection_path,
	]))
	await get_tree().process_frame
	_check(
		str(player.get("_selected_entry")).is_empty()
		and (player.get_node("Margin/Layout/StatusLabel") as Label).text.begins_with("Selection rejected:"),
		"Event Player rejects a selection with a wrong hash without loading the entry"
	)

	var selection_and_run_context := ContentLaunchContextScript.new()
	var selection_and_run := selection_and_run_context.activate(PackedStringArray([
		"--content-set", source_root, "--workspace", workspace_root,
		"--run-request", request_path, "--selection", selection_path,
	]))
	_check(
		not selection_and_run.get("ok", false),
		"a selection with a Run request together is refused by the launch context"
	)
	selection_and_run_context.close()

	var overlay_workspace_root := absolute_root.path_join("workspace_overlay")
	var overlay_workspace := ContentWorkspaceScript.new()
	var overlay_workspace_created := overlay_workspace.create(
		overlay_workspace_root, source_root, _project(source_archive_sha)
	)
	_check(overlay_workspace_created.get("ok", false), "Event Player Run fixture creates a second named workspace for an overlay probe")
	var replacement_mes := mes.duplicate()
	replacement_mes[replacement_mes.size() - 1] ^= 0x01
	var staged_replacement := overlay_workspace.stage_replacements(
		"mes.arc", {"TEST.MES": replacement_mes}, "remake_only", "cp932"
	)
	_check(staged_replacement.get("ok", false), "Event Player Run fixture stages an MES replacement in the second workspace")
	overlay_workspace.close()
	player._apply_startup_arguments(PackedStringArray([
		"--content-set", source_root,
		"--workspace", overlay_workspace_root,
	]))
	await get_tree().process_frame
	var overlay_probe_descriptor: Dictionary = player._resolver.resolve("mes.arc", "TEST.MES")
	player._load_entry("TEST.MES")
	_check(
		(player.get("_reader") as KakyuArcReader).is_open()
		and str(overlay_probe_descriptor.get("source", "")) == "original_arc"
		and str(player.get("_document").get("source", {}).get("resolved_source", "")) == "original_arc"
		and str(player.get("_document").get("entry_sha256", "")) == source_entry_sha,
		"Event Player startup keeps the resolver on original layers when the workspace overlay carries an MES replacement"
	)

	player.queue_free()
	await get_tree().process_frame
	_remove_tree(absolute_root)
	get_tree().quit(1 if _failed else 0)


func _project(source_archive_sha: String) -> Dictionary:
	var archives := [{
		"archive": "mes.arc", "sha256": source_archive_sha, "required": true,
	}]
	return {
		"schema": ContentCoreVersionScript.CONTENT_PROJECT_SCHEMA,
		"project_id": "event-player.run.test", "project_version": "0.1.0",
		"display_name": "Event Player Run Test", "project_revision": 1,
		"content_core": {
			"minimum_version": ContentCoreVersionScript.CORE_VERSION,
			"maximum_exclusive": "1.0.0",
		},
		"source_content_set": {
			"profile_id": "synthetic-test",
			"fingerprint_sha256": ContentProjectScript.compute_content_set_fingerprint(archives),
			"archives": archives,
		},
		"target_archives": ["mes.arc"], "compatibility_objective": "mixed",
		"dependencies": [],
		"event_player": {"catalog_id": "kakyu-original-events", "presets": []},
		"overlay_manifest": "manifest.json",
	}


func _synthetic_mes() -> PackedByteArray:
	var code := PackedByteArray([0x01])
	code.append_array("HELLO".to_ascii_buffer())
	code.append_array(PackedByteArray([0x00, 0x00]))
	var mes := PackedByteArray()
	SyntheticArc.append_u32(mes, 1)
	SyntheticArc.append_u32(mes, 0)
	mes.append_array(code)
	return mes


func _sha256(data: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(data)
	return context.finish().hex_encode()


func _write_text(path: String, contents: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(contents)
	file.close()
