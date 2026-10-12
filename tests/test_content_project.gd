extends "res://tests/test_case.gd"

const ContentProjectScript := preload("res://content_core/content_project.gd")
const PublicationLockScript := preload("res://content_core/publication_lock.gd")

const TEST_ROOT := "user://content_project_test"


func _ready() -> void:
	_cleanup()
	var root_absolute := ProjectSettings.globalize_path(TEST_ROOT)
	var document := _valid_document()
	var project := ContentProjectScript.new()
	var validation: Dictionary = project.validate(document)
	_check(validation.get("ok", false) and validation.target_count == 2 and validation.preset_count == 1, "content project validates portable source, target, dependency, and Event Player metadata")
	var first := project.publish(TEST_ROOT, document, false, "")
	_check(first.get("ok", false) and FileAccess.file_exists(root_absolute.path_join("project.json")), "new content project publishes revision one atomically")
	_check(str(first.get("sha256", "")).length() == 64 and not DirAccess.dir_exists_absolute(root_absolute.path_join(".project.lock")), "project publication returns its exact revision hash and releases the lock")
	var loaded_project := ContentProjectScript.new()
	var loaded: Dictionary = loaded_project.load_project(TEST_ROOT)
	_check(loaded.get("ok", false) and loaded.project.project_id == "sample.maki.mod" and loaded.summary.source_fingerprint == document.source_content_set.fingerprint_sha256, "published content project reopens through the versioned loader")
	var detached := loaded_project.get_project()
	detached.display_name = "mutated"
	_check(loaded_project.get_project().display_name == "Sample Maki Mod", "content project accessors return deep copies")

	var unexpected_overwrite := project.publish(TEST_ROOT, document, false, "")
	_check(not unexpected_overwrite.get("ok", false) and FileAccess.get_sha256(root_absolute.path_join("project.json")) == first.sha256, "absent-snapshot publication cannot overwrite an existing project")
	var update: Dictionary = document.duplicate(true)
	update.project_revision = 2
	update.project_version = "0.2.0"
	var bad_revision: Dictionary = update.duplicate(true)
	bad_revision.project_revision = 3
	_check(not project.publish(TEST_ROOT, bad_revision, true, str(first.sha256)).get("ok", false), "project updates must increment the revision by exactly one")

	var lock := PublicationLockScript.new().acquire(root_absolute, ".project.lock")
	_check(lock.get("ok", false), "project lock fixture acquires the shared publication lock")
	var blocked := project.publish(TEST_ROOT, update, true, str(first.sha256))
	_check(not blocked.get("ok", false) and str(blocked.get("error", "")).contains("locked by process"), "project writer cannot enter while another process owns its shared lock")
	_check(PublicationLockScript.new().release(lock).get("ok", false), "project lock fixture releases safely")

	var orphan_temp := root_absolute.path_join("project.json.tmp-2147483000-1")
	_write_bytes(orphan_temp, PackedByteArray([1, 2, 3]))
	var second := project.publish(TEST_ROOT, update, true, str(first.sha256))
	_check(second.get("ok", false) and second.project.project_revision == 2, "content project publishes the next CAS-bound revision")
	_check(not FileAccess.file_exists(orphan_temp), "project publication removes a dead-process sibling temporary file under the lock")
	var stale_update: Dictionary = update.duplicate(true)
	stale_update.project_revision = 3
	stale_update.display_name = "Stale writer"
	var stale := project.publish(TEST_ROOT, stale_update, true, str(first.sha256))
	_check(not stale.get("ok", false) and FileAccess.get_sha256(root_absolute.path_join("project.json")) == second.sha256, "stale project CAS preserves the newer revision byte-identically")
	var third := project.publish(TEST_ROOT, stale_update, true, str(second.sha256))
	_check(third.get("ok", false) and third.project.display_name == "Stale writer", "current project revision can publish the intentional next update")

	var wrong_fingerprint: Dictionary = document.duplicate(true)
	wrong_fingerprint.source_content_set.fingerprint_sha256 = _sha("f")
	_check(not ContentProjectScript.new().validate(wrong_fingerprint).get("ok", false), "content-set fingerprint mismatch fails closed")
	var unknown_target: Dictionary = document.duplicate(true)
	unknown_target.target_archives = ["missing.arc"]
	_check(not ContentProjectScript.new().validate(unknown_target).get("ok", false), "project targets must be bound source archives")
	var empty_targets: Dictionary = document.duplicate(true)
	empty_targets.target_archives = []
	_check(not ContentProjectScript.new().validate(empty_targets).get("ok", false), "content project requires at least one target archive")
	var future_core: Dictionary = document.duplicate(true)
	future_core.content_core.minimum_version = "9.0.0"
	_check(not ContentProjectScript.new().validate(future_core).get("ok", false), "project requiring a newer Content Core fails closed")
	var absolute_path: Dictionary = document.duplicate(true)
	absolute_path["source_path"] = "C:/local/ELFIMAGE"
	_check(not ContentProjectScript.new().validate(absolute_path).get("ok", false), "machine-specific source paths fail closed")
	var file_uri: Dictionary = document.duplicate(true)
	file_uri.display_name = "file:///local/ELFIMAGE"
	_check(not ContentProjectScript.new().validate(file_uri).get("ok", false), "machine-specific file URIs fail closed")
	var traversal: Dictionary = document.duplicate(true)
	traversal.display_name = "../outside"
	_check(not ContentProjectScript.new().validate(traversal).get("ok", false), "parent traversal strings fail closed anywhere in portable project metadata")
	var bad_dependencies: Dictionary = document.duplicate(true)
	bad_dependencies.dependencies = [{"project_id": "sample.maki.mod", "minimum_version": "1.0.0", "maximum_exclusive": "2.0.0", "optional": false}]
	_check(not ContentProjectScript.new().validate(bad_dependencies).get("ok", false), "project cannot depend on itself")
	var incompatible_preset: Dictionary = document.duplicate(true)
	incompatible_preset.compatibility_objective = "original_engine_compatible"
	incompatible_preset.event_player.presets[0].kind = "remake_only"
	incompatible_preset.event_player.presets[0].catalog_preset_id = ""
	_check(not ContentProjectScript.new().validate(incompatible_preset).get("ok", false), "original-engine-compatible objective rejects remake-only Event Player presets")
	var invalid_write: Dictionary = document.duplicate(true)
	invalid_write.event_player.presets[0].writes = [{"storage": "global_u8", "bank": 0, "index": 1, "value": 256}]
	_check(not ContentProjectScript.new().validate(invalid_write).get("ok", false), "Event Player preset values cannot exceed storage width")
	var string_write: Dictionary = document.duplicate(true)
	string_write.event_player.presets[0].writes = [{"storage": "global_u8", "bank": 0, "index": 1, "value": "1"}]
	_check(not ContentProjectScript.new().validate(string_write).get("ok", false), "Event Player preset numeric values require exact integer types")
	var round_trip_write: Dictionary = document.duplicate(true)
	round_trip_write.event_player.presets[0].writes = [{"storage": "global_u8", "bank": 0, "index": 1, "value": 1}]
	var parsed_round_trip = JSON.parse_string(JSON.stringify(round_trip_write))
	_check(parsed_round_trip is Dictionary and ContentProjectScript.new().validate(parsed_round_trip).get("ok", false), "JSON integer-valued numbers retain the preset storage contract")
	var unknown_nested: Dictionary = document.duplicate(true)
	unknown_nested.content_core["future_field"] = true
	_check(not ContentProjectScript.new().validate(unknown_nested).get("ok", false), "content project nested records reject unknown fields")
	var payload: Dictionary = document.duplicate(true)
	payload["payload_bytes"] = [1, 2, 3]
	_check(not ContentProjectScript.new().validate(payload).get("ok", false), "project metadata cannot embed payload fields")

	var final_load := ContentProjectScript.new().load_project(TEST_ROOT)
	_check(final_load.get("ok", false) and final_load.project.project_revision == 3, "rejected project candidates leave the last valid revision active")
	_check(_project_temporary_files(root_absolute).is_empty(), "project publication leaves no sibling temporary files")
	_cleanup()
	get_tree().quit(1 if _failed else 0)


func _valid_document() -> Dictionary:
	var archives: Array = [
		{"archive": "mes.arc", "sha256": _sha("a"), "required": true},
		{"archive": "mmo.arc", "sha256": _sha("b"), "required": false},
	]
	return {
		"schema": "kakyu_content_project/v1",
		"project_id": "sample.maki.mod",
		"project_version": "0.1.0",
		"display_name": "Sample Maki Mod",
		"project_revision": 1,
		"content_core": {"minimum_version": "0.145.0", "maximum_exclusive": "1.0.0"},
		"source_content_set": {
			"profile_id": "original-jp",
			"fingerprint_sha256": ContentProjectScript.compute_content_set_fingerprint(archives),
			"archives": archives,
		},
		"target_archives": ["mes.arc", "mmo.arc"],
		"compatibility_objective": "mixed",
		"dependencies": [{"project_id": "base.shared", "minimum_version": "1.0.0", "maximum_exclusive": "2.0.0", "optional": true}],
		"event_player": {
			"catalog_id": "kakyu-original-events",
			"presets": [{
				"preset_id": "maki-morning",
				"label": "Maki morning",
				"kind": "catalog_reference",
				"event_id": "original/eventd01/12c-000007cd",
				"catalog_preset_id": "morning-default",
				"writes": [],
			}],
		},
		"overlay_manifest": "manifest.json",
	}


func _sha(character: String) -> String:
	return character.repeat(64)


func _write_bytes(path: String, bytes: PackedByteArray) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()


func _project_temporary_files(root_absolute: String) -> Array[String]:
	var result: Array[String] = []
	var directory := DirAccess.open(root_absolute)
	if directory == null:
		return result
	directory.list_dir_begin()
	var name := directory.get_next()
	while not name.is_empty():
		if not directory.current_is_dir() and name.begins_with("project.json.tmp-"):
			result.append(name)
		name = directory.get_next()
	directory.list_dir_end()
	return result


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
