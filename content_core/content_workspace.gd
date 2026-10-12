class_name KakyuContentWorkspace
extends RefCounted

const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")
const ContentProjectScript := preload("res://content_core/content_project.gd")
const ContentSetScript := preload("res://content_core/content_set.gd")
const OverlayPackageScript := preload("res://content_core/overlay_package.gd")
const PublicationLockScript := preload("res://content_core/publication_lock.gd")

const WORKSPACE_LOCK_DIRECTORY := ".workspace.lock"

var last_error := ""

var _project_root := ""
var _source_root := ""
var _content_set
var _snapshot: Dictionary = {}


func create(project_root: String, source_content_set_root: String, project_document: Dictionary) -> Dictionary:
	last_error = ""
	if project_root.is_empty() or source_content_set_root.is_empty():
		return _error("Workspace project and source roots are required.")
	var root_absolute := ProjectSettings.globalize_path(project_root).simplify_path()
	var source_absolute := ProjectSettings.globalize_path(source_content_set_root).simplify_path()
	var validation := ContentProjectScript.new().validate(project_document)
	if not validation.ok:
		return _error(str(validation.error))
	if int(project_document.project_revision) != 1:
		return _error("A new workspace project must start at revision 1.")
	var source_set := ContentSetScript.new()
	if not source_set.open(source_absolute):
		return _error(source_set.last_error)
	var source_validation := _validate_source_bindings(project_document, source_set)
	if not source_validation.ok:
		source_set.close()
		return source_validation
	if FileAccess.file_exists(root_absolute.path_join(ContentProjectScript.PROJECT_FILENAME)) or FileAccess.file_exists(root_absolute.path_join(OverlayPackageScript.MANIFEST_FILENAME)):
		source_set.close()
		return _error("Workspace project or manifest already exists; nothing was replaced.")
	var workspace_lock := PublicationLockScript.new().acquire(root_absolute, WORKSPACE_LOCK_DIRECTORY)
	if not workspace_lock.ok:
		source_set.close()
		return _error(str(workspace_lock.error))
	var manifest_result := OverlayPackageScript.new().create_empty_manifest(root_absolute)
	var project_result: Dictionary = {}
	if manifest_result.ok:
		project_result = ContentProjectScript.new().publish(root_absolute, project_document, false, "")
	var candidate: Dictionary = {}
	if manifest_result.ok and project_result.ok:
		candidate = _build_candidate(root_absolute, source_absolute)
	if manifest_result.ok and not project_result.ok:
		_remove_created_empty_manifest(root_absolute, str(manifest_result.sha256))
	var release := PublicationLockScript.new().release(workspace_lock)
	source_set.close()
	if not manifest_result.ok:
		return _error(str(manifest_result.error))
	if not project_result.ok:
		return _error(str(project_result.error))
	if not release.ok:
		if candidate.get("ok", false):
			candidate.content_set.close()
		return _error(str(release.error))
	if not candidate.ok:
		return candidate
	_commit_candidate(candidate, root_absolute, source_absolute)
	return {"ok": true, "created": true, "snapshot": get_snapshot()}


func open(project_root: String, source_content_set_root: String) -> Dictionary:
	last_error = ""
	if project_root.is_empty() or source_content_set_root.is_empty():
		return _error("Workspace project and source roots are required.")
	var root_absolute := ProjectSettings.globalize_path(project_root).simplify_path()
	var source_absolute := ProjectSettings.globalize_path(source_content_set_root).simplify_path()
	if not DirAccess.dir_exists_absolute(root_absolute):
		return _error("Workspace project directory does not exist.")
	var workspace_lock := PublicationLockScript.new().acquire(root_absolute, WORKSPACE_LOCK_DIRECTORY)
	if not workspace_lock.ok:
		return _error(str(workspace_lock.error))
	var candidate := _build_candidate(root_absolute, source_absolute)
	var release := PublicationLockScript.new().release(workspace_lock)
	if not release.ok:
		if candidate.ok:
			candidate.content_set.close()
		return _error(str(release.error))
	if not candidate.ok:
		return candidate
	_commit_candidate(candidate, root_absolute, source_absolute)
	return {"ok": true, "created": false, "snapshot": get_snapshot()}


func refresh() -> Dictionary:
	if not is_open():
		return _error("Workspace is not open.")
	return open(_project_root, _source_root)


func close() -> void:
	if _content_set != null:
		_content_set.close()
	_content_set = null
	_snapshot.clear()
	_project_root = ""
	_source_root = ""


func is_open() -> bool:
	return _content_set != null and _content_set.is_open() and not _snapshot.is_empty()


func get_snapshot() -> Dictionary:
	return _snapshot.duplicate(true)


func stage_replacements(
	archive_name: String,
	replacement_data_by_entry: Dictionary,
	compatibility := "remake_only",
	text_encoding := "not_applicable"
) -> Dictionary:
	return _stage_overlay_change(
		archive_name,
		func(reader, expected_sha: String) -> Dictionary:
			return OverlayPackageScript.new().stage_replacements(
				_project_root, reader, archive_name, replacement_data_by_entry,
				compatibility, text_encoding, expected_sha
			)
	)


func stage_mes_text_projections(archive_name: String, edits_by_entry: Dictionary) -> Dictionary:
	return _stage_overlay_change(
		archive_name,
		func(reader, expected_sha: String) -> Dictionary:
			return OverlayPackageScript.new().stage_mes_text_projections(
				_project_root, reader, archive_name, edits_by_entry, expected_sha
			)
	)


func stage_mod_definitions(documents: Array, validate: Callable) -> Dictionary:
	if not is_open():
		return _error("Workspace is not open.")
	if not validate.is_valid():
		return _error("Mod definition staging requires a valid contract validator.")
	for index in range(documents.size()):
		var untyped_bytes = documents[index]
		if not untyped_bytes is PackedByteArray:
			return _error("Mod definition documents must be PackedByteArray.")
		var bytes: PackedByteArray = untyped_bytes
		var checked = validate.call(bytes)
		if not checked is Dictionary or not checked.get("ok", false):
			var label := _definition_batch_label(bytes, index)
			var reason := str(checked.get("reason", "")) if checked is Dictionary else "invalid"
			var detail := str(checked.get("detail", "")) if checked is Dictionary else "the contract validator did not return a verdict"
			return _error("Definition %s failed the contract check: %s: %s" % [label, reason, detail])
	return _stage_change(func() -> Dictionary:
		return OverlayPackageScript.new().stage_mod_definitions(_project_root, documents)
	)


func remove_mod_definition(definition_id: String) -> Dictionary:
	return _stage_change(func() -> Dictionary:
		return OverlayPackageScript.new().remove_mod_definition(_project_root, definition_id)
	)


func publish_project_update(document: Dictionary) -> Dictionary:
	if not is_open():
		return _error("Workspace is not open.")
	var validation := ContentProjectScript.new().validate(document)
	if not validation.ok:
		return _error(str(validation.error))
	var workspace_lock := PublicationLockScript.new().acquire(_project_root, WORKSPACE_LOCK_DIRECTORY)
	if not workspace_lock.ok:
		return _error(str(workspace_lock.error))
	var manifest_lock := PublicationLockScript.new().acquire(_project_root, OverlayPackageScript.MANIFEST_LOCK_DIRECTORY)
	if not manifest_lock.ok:
		PublicationLockScript.new().release(workspace_lock)
		return _error(str(manifest_lock.error))
	var result: Dictionary
	var loaded_manifest := OverlayPackageScript.new().load_manifest(_project_root)
	if not loaded_manifest.ok:
		result = _error(str(loaded_manifest.error))
	else:
		var source_validation := _validate_source_bindings(document, _content_set)
		var manifest_validation := _validate_manifest_against_project(document, loaded_manifest.manifest, _content_set)
		if not source_validation.ok:
			result = source_validation
		elif not manifest_validation.ok:
			result = manifest_validation
		else:
			var published := ContentProjectScript.new().publish(
				_project_root, document, true, str(_snapshot.project_sha256)
			)
			if not published.ok:
				result = _error(str(published.error))
			else:
				var candidate := _build_candidate(_project_root, _source_root)
				if not candidate.ok:
					result = candidate
				elif str(candidate.snapshot.project_sha256) != str(published.sha256):
					candidate.content_set.close()
					result = _error("Workspace project changed again after publication; reopen the workspace.")
				else:
					_commit_candidate(candidate, _project_root, _source_root)
					result = {"ok": true, "snapshot": get_snapshot()}
	var manifest_release := PublicationLockScript.new().release(manifest_lock)
	var workspace_release := PublicationLockScript.new().release(workspace_lock)
	if result.get("ok", false) and (not manifest_release.ok or not workspace_release.ok):
		return _error(str(manifest_release.get("error", workspace_release.get("error", "Workspace lock release failed."))))
	return result


func _stage_overlay_change(archive_name: String, operation: Callable) -> Dictionary:
	if not is_open():
		return _error("Workspace is not open.")
	var normalized := archive_name.to_lower()
	if normalized not in _snapshot.project.target_archives:
		return _error("Archive is not an intentional target of this project: %s" % archive_name)
	var reader = _content_set.get_reader(normalized)
	if reader == null:
		return _error("Workspace source archive is unavailable: %s" % archive_name)
	var expected_sha := _source_archive_sha(normalized)
	return _stage_change(func() -> Dictionary:
		return operation.call(reader, expected_sha)
	)


func _stage_change(operation: Callable) -> Dictionary:
	if not is_open():
		return _error("Workspace is not open.")
	var workspace_lock := PublicationLockScript.new().acquire(_project_root, WORKSPACE_LOCK_DIRECTORY)
	if not workspace_lock.ok:
		return _error(str(workspace_lock.error))
	var project_lock := PublicationLockScript.new().acquire(_project_root, ContentProjectScript.PROJECT_LOCK_DIRECTORY)
	if not project_lock.ok:
		PublicationLockScript.new().release(workspace_lock)
		return _error(str(project_lock.error))
	var result: Dictionary
	var project_path := _project_root.path_join(ContentProjectScript.PROJECT_FILENAME)
	if not FileAccess.file_exists(project_path) or FileAccess.get_sha256(project_path) != str(_snapshot.project_sha256):
		result = _error("Workspace project changed; refresh before publishing content.")
	else:
		var staged: Dictionary = operation.call()
		if not staged.ok:
			result = _error(str(staged.error))
		else:
			var candidate := _build_candidate(_project_root, _source_root)
			if not candidate.ok:
				result = candidate
			elif str(candidate.snapshot.project_sha256) != str(_snapshot.project_sha256):
				candidate.content_set.close()
				result = _error("Workspace project changed while publishing content; reopen the workspace.")
			else:
				_commit_candidate(candidate, _project_root, _source_root)
				result = {"ok": true, "stage": staged, "snapshot": get_snapshot()}
	var project_release := PublicationLockScript.new().release(project_lock)
	var workspace_release := PublicationLockScript.new().release(workspace_lock)
	if result.get("ok", false) and (not project_release.ok or not workspace_release.ok):
		return _error(str(project_release.get("error", workspace_release.get("error", "Workspace lock release failed."))))
	return result


func _definition_batch_label(bytes: PackedByteArray, index: int) -> String:
	var json := JSON.new()
	if json.parse(bytes.get_string_from_utf8()) == OK and json.data is Dictionary:
		var doc_id = json.data.get("id")
		if doc_id is String and not str(doc_id).is_empty():
			return str(doc_id)
	return str(index)


func _build_candidate(root_absolute: String, source_absolute: String) -> Dictionary:
	var project_loader := ContentProjectScript.new()
	var project_result := project_loader.load_project(root_absolute)
	if not project_result.ok:
		return _error(str(project_result.error))
	var candidate_set := ContentSetScript.new()
	if not candidate_set.open(source_absolute):
		return _error(candidate_set.last_error)
	var source_validation := _validate_source_bindings(project_result.project, candidate_set)
	if not source_validation.ok:
		candidate_set.close()
		return source_validation
	var manifest_result := OverlayPackageScript.new().load_manifest(root_absolute)
	if not manifest_result.ok:
		candidate_set.close()
		return _error(str(manifest_result.error))
	var manifest_validation := _validate_manifest_against_project(
		project_result.project, manifest_result.manifest, candidate_set
	)
	if not manifest_validation.ok:
		candidate_set.close()
		return manifest_validation
	var project_path := root_absolute.path_join(ContentProjectScript.PROJECT_FILENAME)
	var manifest_path := root_absolute.path_join(OverlayPackageScript.MANIFEST_FILENAME)
	if FileAccess.get_sha256(project_path) != str(project_result.sha256) or FileAccess.get_sha256(manifest_path) != str(manifest_result.sha256):
		candidate_set.close()
		return _error("Workspace files changed while the immutable snapshot was being prepared.")
	var generation := OverlayPackageScript.sha256_bytes((
		str(project_result.sha256) + "\n" + str(manifest_result.sha256) + "\n"
		+ str(project_result.project.source_content_set.fingerprint_sha256) + "\n"
	).to_utf8_buffer())
	var source_archives: Array[Dictionary] = []
	for binding_value in project_result.project.source_content_set.archives:
		var binding: Dictionary = binding_value
		var reader = candidate_set.get_reader(str(binding.archive))
		source_archives.append({
			"archive": str(binding.archive),
			"sha256": str(binding.sha256),
			"required": bool(binding.required),
			"bytes": int(reader.archive_size),
			"entries": reader.get_entries().size(),
		})
	var snapshot := {
		"schema": ContentCoreVersionScript.CONTENT_WORKSPACE_SNAPSHOT_SCHEMA,
		"generation_sha256": generation,
		"project_sha256": str(project_result.sha256),
		"manifest_sha256": str(manifest_result.sha256),
		"project": project_result.project.duplicate(true),
		"manifest": manifest_result.manifest.duplicate(true),
		"source_content_set": {
			"fingerprint_sha256": str(project_result.project.source_content_set.fingerprint_sha256),
			"archives": source_archives,
		},
		"replacement_count": manifest_result.manifest.replacements.size(),
		"projection_count": manifest_result.manifest.get("projections", []).size(),
		"definition_count": manifest_result.manifest.get("definitions", []).size(),
		"mod_id": _definitions_mod_id(manifest_result.manifest.get("definitions", [])),
	}
	return {"ok": true, "content_set": candidate_set, "snapshot": snapshot}


func _definitions_mod_id(definitions: Array) -> String:
	for untyped_record in definitions:
		var record: Dictionary = untyped_record
		return str(record.get("mod_id", ""))
	return ""


func _validate_source_bindings(project: Dictionary, content_set) -> Dictionary:
	var bindings: Array = project.source_content_set.archives
	var actual_names: Array[String] = content_set.get_archive_names()
	if actual_names.size() != bindings.size():
		return _error("Selected source content set does not match the project's archive set.")
	var seen := {}
	for binding_value in bindings:
		var binding: Dictionary = binding_value
		var archive_name := str(binding.archive)
		var reader = content_set.get_reader(archive_name)
		if reader == null:
			return _error("Selected source content set is missing a project-bound archive: %s" % archive_name)
		var sha: String = reader.get_archive_fingerprint()
		if sha.is_empty() or sha != str(binding.sha256):
			return _error("Selected source archive does not match the project binding: %s" % archive_name)
		seen[archive_name] = true
	for archive_name in actual_names:
		if not seen.has(archive_name):
			return _error("Selected source content set contains an archive outside the project binding: %s" % archive_name)
	return {"ok": true}


func _validate_manifest_against_project(project: Dictionary, manifest: Dictionary, content_set) -> Dictionary:
	var targets: Array = project.target_archives
	var objective := str(project.compatibility_objective)
	for collection_name in ["replacements", "projections"]:
		for untyped_record in manifest.get(collection_name, []):
			var record: Dictionary = untyped_record
			var archive_name := str(record.target_archive).to_lower()
			if archive_name not in targets:
				return _error("Overlay target is outside the project target archives: %s" % archive_name)
			var binding := _project_archive_binding(project, archive_name)
			var reader = content_set.get_reader(archive_name)
			if binding.is_empty() or reader == null or str(record.base_archive_sha256) != str(binding.sha256):
				return _error("Overlay base binding does not match the workspace project: %s" % archive_name)
			var entry: Dictionary = reader.get_entry(str(record.target_entry))
			if entry.is_empty() or reader.get_entry_fingerprint(str(entry.name)) != str(record.original_entry_sha256):
				return _error("Overlay entry binding does not match the workspace source: %s" % str(record.target_entry))
			if objective == "original_engine_compatible" and str(record.compatibility) != "original_engine_compatible":
				return _error("Overlay record is incompatible with the project's original-engine objective.")
	return {"ok": true}


func _project_archive_binding(project: Dictionary, archive_name: String) -> Dictionary:
	for binding_value in project.source_content_set.archives:
		var binding: Dictionary = binding_value
		if str(binding.archive) == archive_name:
			return binding
	return {}


func _source_archive_sha(archive_name: String) -> String:
	var binding := _project_archive_binding(_snapshot.project, archive_name)
	return str(binding.get("sha256", ""))


func _commit_candidate(candidate: Dictionary, root_absolute: String, source_absolute: String) -> void:
	if _content_set != null:
		_content_set.close()
	_content_set = candidate.content_set
	_snapshot = candidate.snapshot.duplicate(true)
	_project_root = root_absolute
	_source_root = source_absolute


func _remove_created_empty_manifest(root_absolute: String, expected_sha256: String) -> void:
	var lock := PublicationLockScript.new().acquire(root_absolute, OverlayPackageScript.MANIFEST_LOCK_DIRECTORY)
	if not lock.ok:
		return
	var path := root_absolute.path_join(OverlayPackageScript.MANIFEST_FILENAME)
	if FileAccess.file_exists(path) and FileAccess.get_sha256(path) == expected_sha256:
		DirAccess.remove_absolute(path)
	PublicationLockScript.new().release(lock)


func _error(message: String) -> Dictionary:
	last_error = message
	return {"ok": false, "schema": ContentCoreVersionScript.CONTENT_WORKSPACE_SNAPSHOT_SCHEMA, "error": message}
