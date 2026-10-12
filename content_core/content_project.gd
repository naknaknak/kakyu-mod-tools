class_name KakyuContentProject
extends RefCounted

const ArcReaderScript := preload("res://content_core/arc_reader.gd")
const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")
const PublicationLockScript := preload("res://content_core/publication_lock.gd")
const ProcessLivenessScript := preload("res://content_core/process_liveness.gd")
const ContractValues := preload("res://content_core/contract_values.gd")

const PROJECT_FILENAME := "project.json"
const PROJECT_LOCK_DIRECTORY := ".project.lock"
const MAX_PROJECT_BYTES := 1024 * 1024
const COMPATIBILITY_OBJECTIVES := {"remake_only": true, "original_engine_compatible": true, "mixed": true}
const PRESET_KINDS := {"catalog_reference": true, "tool_seeded_analysis": true, "remake_only": true}
const STORAGE_WIDTHS := {
	"state_u16": 0xFFFF,
	"state_i32": 0xFFFFFFFF,
	"global_u8": 0xFF,
	"global_i32": 0xFFFFFFFF,
	"relative_u8": 0xFF,
	"banked_u8": 0xFF,
	"banked_u16": 0xFFFF,
	"banked_i32": 0xFFFFFFFF,
}
const TOP_LEVEL_KEYS := {
	"schema": true,
	"project_id": true,
	"project_version": true,
	"display_name": true,
	"project_revision": true,
	"content_core": true,
	"source_content_set": true,
	"target_archives": true,
	"compatibility_objective": true,
	"dependencies": true,
	"event_player": true,
	"overlay_manifest": true,
}
const CORE_REQUIREMENT_KEYS := {"minimum_version": true, "maximum_exclusive": true}
const SOURCE_CONTENT_SET_KEYS := {"profile_id": true, "fingerprint_sha256": true, "archives": true}
const ARCHIVE_BINDING_KEYS := {"archive": true, "sha256": true, "required": true}
const DEPENDENCY_KEYS := {"project_id": true, "minimum_version": true, "maximum_exclusive": true, "optional": true}
const EVENT_PLAYER_KEYS := {"catalog_id": true, "presets": true}
const EVENT_PRESET_KEYS := {"preset_id": true, "label": true, "kind": true, "event_id": true, "catalog_preset_id": true, "writes": true}
const STATE_WRITE_KEYS := {"storage": true, "bank": true, "index": true, "value": true}
const FORBIDDEN_KEYS := {
	"dialogue": true,
	"payload": true,
	"payload_bytes": true,
	"bytecode": true,
	"source_path": true,
	"absolute_path": true,
	"elfimage_path": true,
}

var last_error := ""
var _document: Dictionary = {}
var _sha256 := ""


func load_project(project_root: String) -> Dictionary:
	last_error = ""
	_document.clear()
	_sha256 = ""
	if project_root.is_empty():
		return _error("Content project root is empty.")
	var root_absolute := ProjectSettings.globalize_path(project_root).simplify_path()
	var path := root_absolute.path_join(PROJECT_FILENAME)
	if not FileAccess.file_exists(path):
		return _error("Content project does not contain project.json.")
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _error("Content project could not be opened (error %s)." % FileAccess.get_open_error())
	var size := file.get_length()
	if size <= 0 or size > MAX_PROJECT_BYTES:
		file.close()
		return _error("Content project exceeds its bounded JSON size.")
	var bytes := file.get_buffer(size)
	var read_error := file.get_error()
	file.close()
	if bytes.size() != size or read_error != OK:
		return _error("Content project changed or was truncated while reading.")
	var parsed = JSON.parse_string(bytes.get_string_from_utf8())
	if not parsed is Dictionary:
		return _error("Content project must be a JSON object.")
	var validation := validate(parsed)
	if not validation.ok:
		return validation
	_document = parsed.duplicate(true)
	_sha256 = _sha256_bytes(bytes)
	return {
		"ok": true,
		"schema": ContentCoreVersionScript.CONTENT_PROJECT_SCHEMA,
		"path": path,
		"sha256": _sha256,
		"project": _document.duplicate(true),
		"summary": get_summary(),
	}


func validate(document: Dictionary) -> Dictionary:
	last_error = ""
	if str(document.get("schema", "")) != ContentCoreVersionScript.CONTENT_PROJECT_SCHEMA:
		return _error("Unsupported content project schema.")
	for key in document:
		if not TOP_LEVEL_KEYS.has(str(key)):
			return _error("Content project contains an unknown top-level field: %s" % str(key))
	if _contains_forbidden_key(document) or _contains_nonportable_string(document):
		return _error("Content project contains forbidden payload metadata or a machine-specific path.")
	var project_id := str(document.get("project_id", ""))
	if not _is_project_id(project_id):
		return _error("Content project ID must be portable lowercase ASCII.")
	if not _is_semver(str(document.get("project_version", ""))):
		return _error("Content project version must be canonical major.minor.patch.")
	if str(document.get("display_name", "")).strip_edges().is_empty():
		return _error("Content project display name is empty.")
	if not _is_json_integer(document.get("project_revision", null)) or int(document.project_revision) <= 0:
		return _error("Content project revision must be positive.")
	if str(document.get("overlay_manifest", "")) != "manifest.json":
		return _error("Content project overlay manifest must be manifest.json in the project root.")
	if not COMPATIBILITY_OBJECTIVES.has(str(document.get("compatibility_objective", ""))):
		return _error("Content project compatibility objective is invalid.")
	if not _validate_core_requirement(document.get("content_core", null)):
		return _error(last_error)
	var source = document.get("source_content_set", null)
	if not source is Dictionary or not _validate_source_content_set(source):
		return _error(last_error)
	var targets = document.get("target_archives", null)
	if not targets is Array or not _validate_targets(targets, source.archives):
		return _error(last_error)
	var dependencies = document.get("dependencies", null)
	if not dependencies is Array or not _validate_dependencies(project_id, dependencies):
		return _error(last_error)
	var event_player = document.get("event_player", null)
	if not event_player is Dictionary or not _validate_event_player(event_player, str(document.compatibility_objective)):
		return _error(last_error)
	return {
		"ok": true,
		"schema": ContentCoreVersionScript.CONTENT_PROJECT_SCHEMA,
		"project_id": project_id,
		"project_revision": int(document.project_revision),
		"target_count": targets.size(),
		"dependency_count": dependencies.size(),
		"preset_count": event_player.presets.size(),
	}


func publish(
	project_root: String,
	document: Dictionary,
	expected_exists: bool,
	expected_sha256: String
) -> Dictionary:
	var validation := validate(document)
	if not validation.ok:
		return validation
	var root_absolute := ProjectSettings.globalize_path(project_root).simplify_path()
	if root_absolute.is_empty():
		return _error("Content project root is empty.")
	var lock: Dictionary = PublicationLockScript.new().acquire(root_absolute, PROJECT_LOCK_DIRECTORY)
	if not lock.ok:
		return lock
	var result := _publish_locked(root_absolute, document, expected_exists, expected_sha256)
	var release := PublicationLockScript.new().release(lock)
	if not release.ok and result.ok:
		return release
	return result


func get_project() -> Dictionary:
	return _document.duplicate(true)


func get_sha256() -> String:
	return _sha256


func get_summary() -> Dictionary:
	if _document.is_empty():
		return {}
	return {
		"schema": ContentCoreVersionScript.CONTENT_PROJECT_SCHEMA,
		"project_id": str(_document.project_id),
		"project_version": str(_document.project_version),
		"project_revision": int(_document.project_revision),
		"compatibility_objective": str(_document.compatibility_objective),
		"source_fingerprint": str(_document.source_content_set.fingerprint_sha256),
		"target_archives": _document.target_archives.duplicate(),
		"dependency_count": _document.dependencies.size(),
		"preset_count": _document.event_player.presets.size(),
	}


static func compute_content_set_fingerprint(archives: Array) -> String:
	var normalized: Array[Dictionary] = []
	for value in archives:
		if not value is Dictionary:
			return ""
		normalized.append({
			"archive": str(value.get("archive", "")).to_lower(),
			"sha256": str(value.get("sha256", "")),
			"required": bool(value.get("required", false)),
		})
	normalized.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return str(left.archive) < str(right.archive)
	)
	return _sha256_bytes_static((JSON.stringify(normalized) + "\n").to_utf8_buffer())


func _publish_locked(root_absolute: String, document: Dictionary, expected_exists: bool, expected_sha256: String) -> Dictionary:
	var path := root_absolute.path_join(PROJECT_FILENAME)
	_recover_project_temporaries(root_absolute)
	var current_exists := FileAccess.file_exists(path)
	if current_exists != expected_exists:
		return _error("Content project changed before publication; reopen and retry.")
	if expected_exists:
		if not ContractValues.is_sha256(expected_sha256) or FileAccess.get_sha256(path) != expected_sha256:
			return _error("Content project changed before publication; reopen and retry.")
		var current := KakyuContentProject.new().load_project(root_absolute)
		if not current.ok:
			return _error("Current content project is invalid; publication stopped.")
		if int(document.project_revision) != int(current.project.project_revision) + 1:
			return _error("Content project update must increment project_revision by exactly one.")
	elif int(document.project_revision) != 1:
		return _error("A new content project must start at project_revision 1.")
	var bytes := (JSON.stringify(document, "  ") + "\n").to_utf8_buffer()
	var sha := _sha256_bytes(bytes)
	var temp_path := "%s.tmp-%s-%s" % [path, OS.get_process_id(), Time.get_ticks_usec()]
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return _error("Could not create content project temporary file.")
	file.store_buffer(bytes)
	var write_error := file.get_error()
	file.close()
	if write_error != OK or FileAccess.get_sha256(temp_path) != sha:
		_remove_file(temp_path)
		return _error("Content project temporary file failed verification.")
	current_exists = FileAccess.file_exists(path)
	if current_exists != expected_exists or (expected_exists and FileAccess.get_sha256(path) != expected_sha256):
		_remove_file(temp_path)
		return _error("Content project changed before publication; reopen and retry.")
	var rename_error := DirAccess.rename_absolute(temp_path, path)
	if rename_error != OK:
		_remove_file(temp_path)
		return _error("Could not atomically publish content project (error %s)." % rename_error)
	var reopened := KakyuContentProject.new().load_project(root_absolute)
	if not reopened.ok or str(reopened.sha256) != sha:
		return _error("Published content project failed reopen verification.")
	return {"ok": true, "path": path, "sha256": sha, "project": reopened.project, "summary": reopened.summary}


func _validate_core_requirement(value) -> bool:
	if not value is Dictionary:
		return _fail("Content project core requirement is missing.")
	if not ContractValues.has_only_key_set(value, CORE_REQUIREMENT_KEYS):
		return _fail("Content project core requirement contains an unknown field.")
	var minimum := str(value.get("minimum_version", ""))
	var maximum := str(value.get("maximum_exclusive", ""))
	if not _is_semver(minimum) or (not maximum.is_empty() and not _is_semver(maximum)):
		return _fail("Content project core version range is invalid.")
	if not maximum.is_empty() and _compare_semver(minimum, maximum) >= 0:
		return _fail("Content project core version range is empty.")
	if _compare_semver(ContentCoreVersionScript.CORE_VERSION, minimum) < 0:
		return _fail("Content project requires a newer Content Core.")
	if not maximum.is_empty() and _compare_semver(ContentCoreVersionScript.CORE_VERSION, maximum) >= 0:
		return _fail("Content project requires an older Content Core major range.")
	return true


func _validate_source_content_set(source: Dictionary) -> bool:
	if not ContractValues.has_only_key_set(source, SOURCE_CONTENT_SET_KEYS):
		return _fail("Content project source content set contains an unknown field.")
	if not _is_project_id(str(source.get("profile_id", ""))):
		return _fail("Content project source profile ID is invalid.")
	var archives = source.get("archives", null)
	if not archives is Array or archives.is_empty():
		return _fail("Content project source archive bindings are empty.")
	var previous := ""
	var names := {}
	for value in archives:
		if not value is Dictionary:
			return _fail("Content project source archive binding is invalid.")
		if not ContractValues.has_only_key_set(value, ARCHIVE_BINDING_KEYS):
			return _fail("Content project source archive binding contains an unknown field.")
		var archive := str(value.get("archive", ""))
		if archive != archive.to_lower() or not ArcReaderScript.is_safe_entry_name(archive) or archive.get_extension() != "arc" or not ContractValues.is_sha256(str(value.get("sha256", ""))) or not value.get("required", null) is bool:
			return _fail("Content project source archive binding is invalid.")
		if names.has(archive) or (not previous.is_empty() and archive < previous):
			return _fail("Content project source archives must be unique and sorted.")
		names[archive] = true
		previous = archive
	if not names.has("mes.arc"):
		return _fail("Content project source set must bind mes.arc.")
	var expected := compute_content_set_fingerprint(archives)
	if expected.is_empty() or str(source.get("fingerprint_sha256", "")) != expected:
		return _fail("Content project source content-set fingerprint is invalid.")
	return true


func _validate_targets(targets: Array, archives: Array) -> bool:
	if targets.is_empty():
		return _fail("Content project target archives are empty.")
	var available := {}
	for value in archives:
		available[str(value.archive)] = true
	var previous := ""
	for value in targets:
		if not value is String:
			return _fail("Content project target archives must be strings.")
		var archive := str(value)
		if not available.has(archive) or (not previous.is_empty() and archive <= previous):
			return _fail("Content project target archives must be unique, sorted source archives.")
		previous = archive
	return true


func _validate_dependencies(project_id: String, dependencies: Array) -> bool:
	var previous := ""
	for value in dependencies:
		if not value is Dictionary:
			return _fail("Content project dependency is invalid.")
		if not ContractValues.has_only_key_set(value, DEPENDENCY_KEYS):
			return _fail("Content project dependency contains an unknown field.")
		var dependency_id := str(value.get("project_id", ""))
		var minimum := str(value.get("minimum_version", ""))
		var maximum := str(value.get("maximum_exclusive", ""))
		if not _is_project_id(dependency_id) or dependency_id == project_id or (not previous.is_empty() and dependency_id <= previous):
			return _fail("Content project dependencies must be unique, sorted, and non-recursive.")
		if not _is_semver(minimum) or (not maximum.is_empty() and (not _is_semver(maximum) or _compare_semver(minimum, maximum) >= 0)) or not value.get("optional", null) is bool:
			return _fail("Content project dependency version range is invalid.")
		previous = dependency_id
	return true


func _validate_event_player(value: Dictionary, objective: String) -> bool:
	if not ContractValues.has_only_key_set(value, EVENT_PLAYER_KEYS):
		return _fail("Content project Event Player settings contain an unknown field.")
	if not _is_project_id(str(value.get("catalog_id", ""))):
		return _fail("Content project Event Catalog ID is invalid.")
	var presets = value.get("presets", null)
	if not presets is Array:
		return _fail("Content project Event Player presets must be an array.")
	var ids := {}
	for preset_value in presets:
		if not preset_value is Dictionary:
			return _fail("Content project Event Player preset is invalid.")
		var preset: Dictionary = preset_value
		if not ContractValues.has_only_key_set(preset, EVENT_PRESET_KEYS):
			return _fail("Content project Event Player preset contains an unknown field.")
		var preset_id := str(preset.get("preset_id", ""))
		var kind := str(preset.get("kind", ""))
		var base_id := str(preset.get("catalog_preset_id", ""))
		if not _is_project_id(preset_id) or ids.has(preset_id) or not PRESET_KINDS.has(kind) or not _is_event_id(str(preset.get("event_id", ""))):
			return _fail("Content project Event Player preset identity is invalid.")
		if str(preset.get("label", "")).strip_edges().is_empty():
			return _fail("Content project Event Player preset label is empty.")
		if kind == "catalog_reference" and not _is_project_id(base_id):
			return _fail("Catalog-reference preset requires a catalog preset ID.")
		if kind != "catalog_reference" and not base_id.is_empty():
			return _fail("Non-catalog preset cannot claim a catalog preset ID.")
		if objective == "original_engine_compatible" and kind == "remake_only":
			return _fail("Original-engine-compatible project cannot contain remake-only Event Player presets.")
		var writes = preset.get("writes", null)
		if not writes is Array:
			return _fail("Content project Event Player preset writes must be an array.")
		for write_value in writes:
			if not write_value is Dictionary or not _validate_state_write(write_value):
				return _fail("Content project Event Player preset write is invalid.")
		ids[preset_id] = true
	return true


func _validate_state_write(value: Dictionary) -> bool:
	if not ContractValues.has_only_key_set(value, STATE_WRITE_KEYS):
		return false
	if not _is_json_integer(value.get("bank", null)) or not _is_json_integer(value.get("index", null)) or not _is_json_integer(value.get("value", null)):
		return false
	var storage := str(value.get("storage", ""))
	if not STORAGE_WIDTHS.has(storage) or int(value.get("bank", -1)) < 0 or int(value.get("index", -1)) < 0:
		return false
	var stored := int(value.get("value", -1))
	return stored >= 0 and stored <= int(STORAGE_WIDTHS[storage])


func _is_json_integer(value) -> bool:
	if value is int:
		return true
	if value is float:
		return is_finite(value) and value == floor(value)
	return false


func _recover_project_temporaries(root_absolute: String) -> void:
	var directory := DirAccess.open(root_absolute)
	if directory == null:
		return
	directory.list_dir_begin()
	var name := directory.get_next()
	while not name.is_empty():
		if not directory.current_is_dir() and name.begins_with(PROJECT_FILENAME + ".tmp-"):
			var suffix := name.substr((PROJECT_FILENAME + ".tmp-").length())
			var parts := suffix.split("-", false)
			if not parts.is_empty() and str(parts[0]).is_valid_int() and not ProcessLivenessScript.is_running(int(parts[0])):
				DirAccess.remove_absolute(root_absolute.path_join(name))
		name = directory.get_next()
	directory.list_dir_end()


func _contains_forbidden_key(value) -> bool:
	if value is Dictionary:
		for key in value:
			if FORBIDDEN_KEYS.has(str(key).to_lower()) or _contains_forbidden_key(value[key]):
				return true
	elif value is Array:
		for item in value:
			if _contains_forbidden_key(item):
				return true
	return false


func _contains_nonportable_string(value) -> bool:
	if value is Dictionary:
		for item in value.values():
			if _contains_nonportable_string(item):
				return true
	elif value is Array:
		for item in value:
			if _contains_nonportable_string(item):
				return true
	elif value is String:
		var text: String = value
		if text.to_lower().begins_with("file://") or text.contains("..\\") or text.contains("../") or text.begins_with("/") or text.begins_with("\\"):
			return true
		if text.length() >= 3 and text[1] == ":" and (text[2] == "/" or text[2] == "\\"):
			return true
	return false


func _is_project_id(value: String) -> bool:
	if value.is_empty() or value != value.to_lower() or value.begins_with(".") or value.ends_with("."):
		return false
	for character in value:
		if character not in "abcdefghijklmnopqrstuvwxyz0123456789._-":
			return false
	return true


func _is_event_id(value: String) -> bool:
	if value.is_empty() or value != value.to_lower() or value.begins_with("/") or value.ends_with("/") or value.contains("//") or value.contains(".."):
		return false
	for character in value:
		if character not in "abcdefghijklmnopqrstuvwxyz0123456789-_/":
			return false
	return true


func _is_semver(value: String) -> bool:
	var parts := value.split(".", false)
	if parts.size() != 3:
		return false
	for part in parts:
		if not part.is_valid_int() or int(part) < 0 or (part.length() > 1 and part.begins_with("0")):
			return false
	return true


func _compare_semver(left: String, right: String) -> int:
	var left_parts := left.split(".", false)
	var right_parts := right.split(".", false)
	for index in range(3):
		var difference := int(left_parts[index]) - int(right_parts[index])
		if difference != 0:
			return -1 if difference < 0 else 1
	return 0


func _sha256_bytes(data: PackedByteArray) -> String:
	return _sha256_bytes_static(data)


static func _sha256_bytes_static(data: PackedByteArray) -> String:
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK or context.update(data) != OK:
		return ""
	return context.finish().hex_encode()


func _remove_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func _fail(message: String) -> bool:
	last_error = message
	return false


func _error(message: String) -> Dictionary:
	last_error = message
	return {"ok": false, "schema": ContentCoreVersionScript.CONTENT_PROJECT_SCHEMA, "error": message}
