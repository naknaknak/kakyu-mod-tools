extends "res://tools/content_suite/cli_script.gd"

## WD-09 original integration: a content selection for the original EVENTB15.MES
## with its catalog event/preset attached, consumed by Event Player through
## --selection, reaches the loaded entry and the selected catalog row/preset
## without starting playback, leaving the source archives unchanged.

const EventPlayerScene := preload("res://tools/content_suite/apps/event_player.tscn")
const ImageEditorScene := preload("res://tools/content_suite/apps/image_arc_editor.tscn")
const AudioEditorScene := preload("res://tools/content_suite/apps/audio_arc_editor.tscn")
const ArcReaderScript := preload("res://content_core/arc_reader.gd")
const ContentSetScript := preload("res://content_core/content_set.gd")
const WorkspaceProjectDocumentScript := preload("res://tools/content_suite/workspace_project_document.gd")
const ContentWorkspaceScript := preload("res://content_core/content_workspace.gd")
const ContentSelectionScript := preload("res://content_core/content_selection.gd")
const EventCatalogScript := preload("res://content_core/event_catalog.gd")

const PRIMARY_ENTRY := "EVENTB15.MES"
const FALLBACK_ENTRY := "EVENTD01.MES"
const EVENT_CATALOG_PATH := "res://config/event_catalog/original_events_v1.json"
const IMAGE_ENTRY := "A01.AX"
const AUDIO_ENTRY := "KSE0031.WAV"


func _initialize() -> void:
	call_deferred("_validate")


func _validate() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() != 1:
		_fail("Usage: <ELFIMAGE-directory>")
		return
	var elfimage_root := ProjectSettings.globalize_path(str(arguments[0]))
	if not DirAccess.dir_exists_absolute(elfimage_root):
		_fail("ELFIMAGE directory is unavailable.")
		return

	var catalog := EventCatalogScript.new()
	if not catalog.load_file(EVENT_CATALOG_PATH).get("ok", false):
		_fail("Event Catalog could not be loaded.")
		return
	var callee_entry := PRIMARY_ENTRY
	var note := ""
	var found := catalog.find_callee_source(callee_entry)
	if found.is_empty():
		callee_entry = FALLBACK_ENTRY
		found = catalog.find_callee_source(callee_entry)
		note = " (EVENTB15.MES callee lookup was ambiguous or absent; used EVENTD01.MES instead)"
	if found.is_empty():
		_fail("Neither EVENTB15.MES nor EVENTD01.MES name exactly one catalog event.")
		return
	var event_id := str(found.event_id)
	var event := catalog.get_event(event_id)
	var presets: Array = event.get("presets", [])
	if presets.is_empty():
		_fail("Selected catalog event %s has no presets." % event_id)
		return
	var preset_id := str((presets[0] as Dictionary).get("preset_id", ""))
	var catalog_id := str(catalog.get_summary().catalog_id)

	var fixture := _create_selection_fixture(elfimage_root, callee_entry, catalog_id, event_id, preset_id)
	if not fixture.get("ok", false):
		_fail("Could not prepare the selection handoff fixture: %s" % str(fixture.get("error", "")))
		return

	var player: KakyuEventPlayer = EventPlayerScene.instantiate()
	root.add_child(player)
	await process_frame
	player.call("_apply_startup_arguments", PackedStringArray([
		"--content-set", elfimage_root,
		"--workspace", str(fixture.workspace_root),
		"--selection", str(fixture.selection_path),
	]))
	await process_frame

	var catalog_tree: Tree = player.get("catalog_tree")
	var catalog_preset_select: OptionButton = player.get("catalog_preset_select")
	var selected_item := catalog_tree.get_selected()
	var selected_event_id := str(selected_item.get_metadata(0)) if selected_item != null else ""
	var selected_preset_id := (
		str(catalog_preset_select.get_item_metadata(catalog_preset_select.selected))
		if catalog_preset_select.selected >= 0 else ""
	)
	var loaded_entry := str(player.get("_selected_entry")).to_upper()
	var playback_active := bool(player.get("_catalog_playback_active"))

	player.queue_free()
	await process_frame

	var image_result := await _validate_image_selection(fixture, elfimage_root)
	var audio_result := await _validate_audio_selection(fixture, elfimage_root)

	var sources_unchanged: bool = _archive_hashes(elfimage_root) == fixture.source_hashes
	_remove_tree(str(fixture.root))

	var failures: Array[String] = []
	if loaded_entry != callee_entry:
		failures.append("Event Player did not load the selected entry %s (loaded %s)" % [callee_entry, loaded_entry])
	if playback_active:
		failures.append("selection handoff must not start playback")
	if selected_event_id != event_id:
		failures.append("selection handoff did not select the catalog event row (selected %s)" % selected_event_id)
	if selected_preset_id != preset_id:
		failures.append("selection handoff did not select the catalog preset (selected %s)" % selected_preset_id)
	if not image_result.get("ok", false):
		failures.append(str(image_result.get("error", "Image editor selection handoff failed.")))
	if not audio_result.get("ok", false):
		failures.append(str(audio_result.get("error", "Audio editor selection handoff failed.")))
	if not sources_unchanged:
		failures.append("a source archive changed during the selection handoff validation")
	if not failures.is_empty():
		_fail("Selection handoff original integration failed: %s.%s" % ["; ".join(failures), note])
		return
	print(
		"PASS: selection handoff original integration entry=%s event=%s preset=%s playback=inactive sources_unchanged=true image=%s audio=%s%s"
		% [callee_entry, event_id, preset_id, IMAGE_ENTRY, AUDIO_ENTRY, note]
	)
	quit(0)


func _validate_image_selection(fixture: Dictionary, elfimage_root: String) -> Dictionary:
	var reader := ArcReaderScript.new()
	if not reader.open(elfimage_root.path_join("data.arc")):
		return {"ok": false, "error": "Image selection fixture could not open data.arc: %s" % reader.last_error}
	var entry_sha := reader.get_entry_fingerprint(IMAGE_ENTRY)
	reader.close()
	if entry_sha.is_empty():
		return {"ok": false, "error": "%s is unavailable in data.arc." % IMAGE_ENTRY}
	var document := ContentSelectionScript.new().build(
		fixture.snapshot,
		{
			"archive": "data.arc", "entry": IMAGE_ENTRY, "source_entry_sha256": entry_sha,
			"catalog_id": "", "event_id": "", "preset_id": "",
		},
		"arc_browser"
	)
	if not document.get("ok", false):
		return {"ok": false, "error": "Image selection document could not be built: %s" % str(document.get("error", ""))}
	var written := ContentSelectionScript.new().write(document, str(fixture.root).path_join("image-selection.json"))
	if not written.get("ok", false):
		return {"ok": false, "error": "Image selection document could not be written: %s" % str(written.get("error", ""))}

	var editor: Control = ImageEditorScene.instantiate()
	root.add_child(editor)
	await process_frame
	editor.call("_apply_startup_arguments", PackedStringArray([
		"--content-set", elfimage_root, "--workspace", str(fixture.workspace_root), "--selection", str(written.path),
	]))
	await process_frame
	var selected_name := str(editor.get("_selected_name"))
	var ax_inspector: Control = editor.get("ax_inspector")
	var inspector_visible := is_instance_valid(ax_inspector) and ax_inspector.visible
	editor.queue_free()
	await process_frame

	if selected_name.to_upper() != IMAGE_ENTRY.to_upper():
		return {"ok": false, "error": "Image editor did not select %s (selected %s)" % [IMAGE_ENTRY, selected_name]}
	if not inspector_visible:
		return {"ok": false, "error": "Image editor did not show the AX inspector for %s" % IMAGE_ENTRY}
	return {"ok": true}


func _validate_audio_selection(fixture: Dictionary, elfimage_root: String) -> Dictionary:
	var reader := ArcReaderScript.new()
	if not reader.open(elfimage_root.path_join("se.arc")):
		return {"ok": false, "error": "Audio selection fixture could not open se.arc: %s" % reader.last_error}
	var entry_sha := reader.get_entry_fingerprint(AUDIO_ENTRY)
	reader.close()
	if entry_sha.is_empty():
		return {"ok": false, "error": "%s is unavailable in se.arc." % AUDIO_ENTRY}
	var document := ContentSelectionScript.new().build(
		fixture.snapshot,
		{
			"archive": "se.arc", "entry": AUDIO_ENTRY, "source_entry_sha256": entry_sha,
			"catalog_id": "", "event_id": "", "preset_id": "",
		},
		"arc_browser"
	)
	if not document.get("ok", false):
		return {"ok": false, "error": "Audio selection document could not be built: %s" % str(document.get("error", ""))}
	var written := ContentSelectionScript.new().write(document, str(fixture.root).path_join("audio-selection.json"))
	if not written.get("ok", false):
		return {"ok": false, "error": "Audio selection document could not be written: %s" % str(written.get("error", ""))}

	var editor: Control = AudioEditorScene.instantiate()
	root.add_child(editor)
	await process_frame
	editor.call("_apply_startup_arguments", PackedStringArray([
		"--content-set", elfimage_root, "--workspace", str(fixture.workspace_root), "--selection", str(written.path),
	]))
	await process_frame
	var selected_entry := str(editor.get("_selected_entry"))
	var details: RichTextLabel = editor.get("details")
	var shows_container := is_instance_valid(details) and details.text.contains("Container: wav")
	editor.queue_free()
	await process_frame

	if selected_entry.to_upper() != AUDIO_ENTRY.to_upper():
		return {"ok": false, "error": "Audio editor did not select %s (selected %s)" % [AUDIO_ENTRY, selected_entry]}
	if not shows_container:
		return {"ok": false, "error": "Audio editor did not show Container: wav for %s" % AUDIO_ENTRY}
	return {"ok": true}


func _create_selection_fixture(
	elfimage_root: String, callee_entry: String, catalog_id: String, event_id: String, preset_id: String
) -> Dictionary:
	var root_path := ProjectSettings.globalize_path("user://validate_selection_handoff_original")
	_remove_tree(root_path)
	DirAccess.make_dir_recursive_absolute(root_path)
	var built := WorkspaceProjectDocumentScript.from_content_set(
		elfimage_root, "event-player.selection-handoff.original", "Selection Handoff Original",
		"authoritative-original-profile", catalog_id
	)
	if not built.get("ok", false):
		return {"ok": false, "error": str(built.error)}
	var project: Dictionary = built.project
	var source_hashes: Dictionary = built.source_hashes
	var workspace_root := root_path.path_join("workspace")
	var workspace := ContentWorkspaceScript.new()
	var created := workspace.create(workspace_root, elfimage_root, project)
	if not created.get("ok", false):
		return {"ok": false, "error": str(created.error)}
	var snapshot := workspace.get_snapshot()
	workspace.close()
	var reader := ArcReaderScript.new()
	if not reader.open(elfimage_root.path_join("mes.arc")):
		return {"ok": false, "error": reader.last_error}
	var entry_sha := reader.get_entry_fingerprint(callee_entry)
	reader.close()
	if entry_sha.is_empty():
		return {"ok": false, "error": "%s is unavailable." % callee_entry}
	var document := ContentSelectionScript.new().build(
		snapshot,
		{
			"archive": "mes.arc", "entry": callee_entry, "source_entry_sha256": entry_sha,
			"catalog_id": catalog_id, "event_id": event_id, "preset_id": preset_id,
		},
		"mes_editor"
	)
	if not document.get("ok", false):
		return {"ok": false, "error": str(document.error)}
	var selection_path := root_path.path_join("selection.json")
	var written := ContentSelectionScript.new().write(document, selection_path)
	if not written.get("ok", false):
		return {"ok": false, "error": str(written.error)}
	return {
		"ok": true, "root": root_path, "workspace_root": workspace_root,
		"selection_path": selection_path, "source_hashes": source_hashes,
		"snapshot": snapshot,
	}


func _archive_hashes(elfimage_root: String) -> Dictionary:
	var content_set := ContentSetScript.new()
	if not content_set.open(elfimage_root):
		return {}
	var result := {}
	for archive_name in content_set.get_archive_names():
		result[archive_name] = FileAccess.get_sha256(elfimage_root.path_join(str(archive_name)))
	content_set.close()
	return result


func _remove_tree(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	var directory := DirAccess.open(path)
	if directory == null:
		return
	for subdirectory in directory.get_directories():
		_remove_tree(path.path_join(subdirectory))
	for filename in directory.get_files():
		DirAccess.remove_absolute(path.path_join(filename))
	DirAccess.remove_absolute(path)
