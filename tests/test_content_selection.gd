extends "res://tests/test_case.gd"

const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")
const ContentProjectScript := preload("res://content_core/content_project.gd")
const ContentWorkspaceScript := preload("res://content_core/content_workspace.gd")
const ContentLaunchContextScript := preload("res://content_core/content_launch_context.gd")
const ContentSelectionScript := preload("res://content_core/content_selection.gd")
const SelectionHandoffScript := preload("res://tools/content_suite/selection_handoff.gd")
const ArcReaderScript := preload("res://content_core/arc_reader.gd")

const ROOT := "user://content_selection_test"
const ENTRY_SIZE := 264
const NAME_KEY := 0x72
const SIZE_KEY := 0xF97FD0EC
const OFFSET_KEY := 0xA2C947FC


func _ready() -> void:
	var root := ProjectSettings.globalize_path(ROOT)
	_remove_tree(root)
	var source_root := root.path_join("ELFIMAGE")
	var workspace_root := root.path_join("workspace")
	DirAccess.make_dir_recursive_absolute(source_root)
	_create_arc(source_root.path_join("mes.arc"), "TEST.MES", PackedByteArray([1, 2, 3]))
	var mes_sha := FileAccess.get_sha256(source_root.path_join("mes.arc"))
	var reader := ArcReaderScript.new()
	reader.open(source_root.path_join("mes.arc"))
	var entry_sha := reader.get_entry_fingerprint("TEST.MES")
	reader.close()
	var archives := [{"archive": "mes.arc", "sha256": mes_sha, "required": true}]
	var project := _project("selection.test", archives)
	var workspace := ContentWorkspaceScript.new()
	var created := workspace.create(workspace_root, source_root, project)
	_check(created.get("ok", false), "content selection fixture creates a named workspace")
	var snapshot := workspace.get_snapshot()
	workspace.close()

	var contract := ContentSelectionScript.new()
	var selection_fields := {
		"archive": "mes.arc", "entry": "TEST.MES", "source_entry_sha256": entry_sha,
		"catalog_id": "", "event_id": "", "preset_id": "",
	}
	var document := contract.build(snapshot, selection_fields, "mes_editor")
	_check(
		document.get("ok", false)
		and str(document.schema) == "kakyu_content_selection/v1"
		and (document.keys() as Array).size() == 7,
		"content selection builds a versioned reference-inspection document with exact keys"
	)
	_check(contract.validate(document).get("ok", false), "content selection validates its deterministic payload fingerprint")
	_check(contract.validate_for_workspace(document, snapshot).get("ok", false), "content selection rechecks the active workspace binding")

	var event_fields := selection_fields.duplicate(true)
	event_fields.catalog_id = "kakyu-original-events"
	event_fields.event_id = "original/eventb15/11m-0000347b"
	event_fields.preset_id = "daytime-original"
	var event_document := contract.build(snapshot, event_fields, "audio_arc_editor")
	_check(
		event_document.get("ok", false)
		and str(event_document.selection.event_id) == "original/eventb15/11m-0000347b",
		"content selection carries an attached catalog event and preset"
	)

	_check(
		not contract.build(snapshot, selection_fields, "unknown_app").get("ok", false),
		"content selection rejects an unknown producer app"
	)
	var unbound_fields := selection_fields.duplicate(true)
	unbound_fields.archive = "voice.arc"
	_check(
		not contract.build(snapshot, unbound_fields, "mes_editor").get("ok", false),
		"content selection rejects an archive the workspace does not bind"
	)
	var unsafe_fields := selection_fields.duplicate(true)
	unsafe_fields.entry = "../TEST.MES"
	_check(
		not contract.build(snapshot, unsafe_fields, "mes_editor").get("ok", false),
		"content selection rejects an unsafe entry name"
	)
	var bad_hash_fields := selection_fields.duplicate(true)
	bad_hash_fields.source_entry_sha256 = "not-a-hash"
	_check(
		not contract.build(snapshot, bad_hash_fields, "mes_editor").get("ok", false),
		"content selection rejects a malformed entry hash"
	)
	var empty_catalog_fields := selection_fields.duplicate(true)
	empty_catalog_fields.event_id = "original/eventb15/11m-0000347b"
	_check(
		not contract.build(snapshot, empty_catalog_fields, "mes_editor").get("ok", false),
		"content selection rejects event fields with an empty catalog_id"
	)

	var tampered := document.duplicate(true)
	tampered.selection = (tampered.selection as Dictionary).duplicate(true)
	tampered.selection.entry = "OTHER.MES"
	_check(not contract.validate(tampered).get("ok", false), "content selection rejects a tampered fingerprint")

	var extra := document.duplicate(true)
	extra["future"] = true
	extra.payload_sha256 = contract.fingerprint(extra)
	_check(not contract.validate(extra).get("ok", false), "content selection rejects an unknown top-level key")

	var wrong_purpose := document.duplicate(true)
	wrong_purpose.purpose = "playback"
	wrong_purpose.payload_sha256 = contract.fingerprint(wrong_purpose)
	_check(not contract.validate(wrong_purpose).get("ok", false), "content selection rejects an unsupported purpose")

	var changed_snapshot := snapshot.duplicate(true)
	changed_snapshot.generation_sha256 = "e".repeat(64)
	_check(
		not contract.validate_for_workspace(document, changed_snapshot).get("ok", false),
		"content selection rejects a changed workspace generation"
	)

	var write_path := root.path_join("selection.json")
	var written := contract.write(document, write_path)
	_check(written.get("ok", false) and FileAccess.file_exists(write_path), "content selection writes canonical JSON with a trailing newline")
	_check(not contract.write(document, write_path).get("ok", false), "content selection write refuses an existing path")
	var round_trip := contract.read_path(write_path)
	_check(round_trip.get("ok", false) and round_trip.document == document, "content selection read_path round-trips the written document")

	var launch_context := ContentLaunchContextScript.new()
	var activated := launch_context.activate(PackedStringArray([
		"--content-set", source_root, "--workspace", workspace_root,
	]))
	_check(activated.get("ok", false), "content selection handoff fixture activates the named launch context")
	var handoff_launch := SelectionHandoffScript.launch(
		"res://tools/content_suite/apps/event_player.tscn", launch_context, document
	)
	var handoff_files := _list_handoff_files(workspace_root)
	_check(
		handoff_launch.get("ok", false)
		and (handoff_launch.arguments as PackedStringArray).has("--selection")
		and handoff_files.size() == 1
		and str(handoff_launch.path) == ProjectSettings.globalize_path(handoff_files[0]).simplify_path(),
		"KakyuSelectionHandoff.launch writes the handoff file under .handoff/ and returns --selection arguments"
	)

	var other_root := root.path_join("other_workspace")
	var other_project := _project("selection.other", archives)
	var other_workspace := ContentWorkspaceScript.new()
	var other_created := other_workspace.create(other_root, source_root, other_project)
	_check(other_created.get("ok", false), "content selection handoff fixture creates a second unrelated workspace")
	var other_snapshot := other_workspace.get_snapshot()
	other_workspace.close()
	var other_document := contract.build(other_snapshot, selection_fields, "mes_editor")
	_check(other_document.get("ok", false), "content selection handoff fixture builds a document for the second workspace")
	var refused := SelectionHandoffScript.launch(
		"res://tools/content_suite/apps/event_player.tscn", launch_context, other_document
	)
	_check(not refused.get("ok", false), "KakyuSelectionHandoff.launch refuses a document for another workspace")

	var mes_specialist := SelectionHandoffScript.specialist_for("mes.arc", "TEST.MES")
	_check(
		mes_specialist.get("ok", false) and str(mes_specialist.app) == "mes_editor" and str(mes_specialist.label) == "MES Editor",
		"specialist_for routes mes.arc to the MES Editor"
	)
	var mmo_specialist := SelectionHandoffScript.specialist_for("mmo.arc", "TEST.MMO")
	var data_specialist := SelectionHandoffScript.specialist_for("data.arc", "TEST.A6")
	_check(
		mmo_specialist.get("ok", false) and str(mmo_specialist.app) == "image_arc_editor"
		and data_specialist.get("ok", false) and str(data_specialist.app) == "image_arc_editor"
		and str(mmo_specialist.label) == "Image and Animation ARC Editor",
		"specialist_for routes mmo.arc and data.arc to the Image and Animation ARC Editor"
	)
	var audio_specialist := SelectionHandoffScript.specialist_for("se.arc", "KSE0001.WAV")
	_check(
		audio_specialist.get("ok", false) and str(audio_specialist.app) == "audio_arc_editor"
		and str(audio_specialist.label) == "Audio ARC Editor",
		"specialist_for routes a WAV entry in se.arc to the Audio ARC Editor"
	)
	var audio_non_audio := SelectionHandoffScript.specialist_for("se.arc", "META.BIN")
	_check(
		not audio_non_audio.get("ok", false),
		"specialist_for rejects a non-audio entry in an audio archive"
	)
	var unknown_specialist := SelectionHandoffScript.specialist_for("unknown.arc", "TEST.BIN")
	_check(not unknown_specialist.get("ok", false), "specialist_for rejects an archive with no specialist editor")

	launch_context.close()
	_remove_tree(root)
	get_tree().quit(1 if _failed else 0)


func _project(project_id: String, archives: Array) -> Dictionary:
	return {
		"schema": ContentCoreVersionScript.CONTENT_PROJECT_SCHEMA, "project_id": project_id,
		"project_version": "0.1.0", "display_name": "Selection Test", "project_revision": 1,
		"content_core": {"minimum_version": ContentCoreVersionScript.CORE_VERSION, "maximum_exclusive": "1.0.0"},
		"source_content_set": {
			"profile_id": "synthetic-test",
			"fingerprint_sha256": ContentProjectScript.compute_content_set_fingerprint(archives),
			"archives": archives,
		},
		"target_archives": ["mes.arc"], "compatibility_objective": "mixed", "dependencies": [],
		"event_player": {"catalog_id": "kakyu-original-events", "presets": []}, "overlay_manifest": "manifest.json",
	}


func _list_handoff_files(workspace_root: String) -> Array[String]:
	var results: Array[String] = []
	var directory := DirAccess.open(workspace_root.path_join(".handoff"))
	if directory == null:
		return results
	directory.list_dir_begin()
	var name := directory.get_next()
	while not name.is_empty():
		if not directory.current_is_dir():
			results.append(workspace_root.path_join(".handoff").path_join(name))
		name = directory.get_next()
	directory.list_dir_end()
	return results


func _create_arc(path: String, name: String, data: PackedByteArray) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_32(1)
	var record := PackedByteArray()
	record.resize(ENTRY_SIZE)
	var name_bytes := name.to_ascii_buffer()
	for index in range(256):
		record[index] = (name_bytes[index] if index < name_bytes.size() else 0) ^ NAME_KEY
	record.encode_u32(256, data.size() ^ SIZE_KEY)
	record.encode_u32(260, (4 + ENTRY_SIZE) ^ OFFSET_KEY)
	file.store_buffer(record)
	file.store_buffer(data)
	file.close()
