class_name KakyuProvenanceReport
extends RefCounted

## Portable, path-free, fingerprinted lineage report for a content workspace
## (WD-04). It states what a workspace claims - project identity, source
## content-set binding, every replacement/projection with its declared
## compatibility, and the compiled authoring proof behind a replacement when
## one exists - and it is produced only after every claim is re-verified
## against the workspace files on disk. It never contains a machine path, a
## payload byte of an original entry, or dialogue.

const ContentWorkspaceScript := preload("res://content_core/content_workspace.gd")
const ContentSetScript := preload("res://content_core/content_set.gd")
const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")
const FingerprintScript := preload("res://content_core/mes_payload_fingerprint.gd")
const SessionScript := preload("res://tools/content_suite/mes_authoring_session.gd")
const ContractValues := preload("res://content_core/contract_values.gd")

const MAX_REPORT_BYTES := 1024 * 1024

const TOP_LEVEL_KEYS := {
	"schema": true, "core_version": true, "project": true, "workspace": true,
	"source_content_set": true, "replacements": true, "projections": true,
	"compatibility": true, "verification": true, "payload_sha256": true,
}
const PROJECT_KEYS := {
	"project_id": true, "project_version": true, "display_name": true, "project_revision": true,
	"compatibility_objective": true, "content_core": true, "target_archives": true,
	"dependencies": true, "event_player": true,
}
const CORE_REQUIREMENT_KEYS := {"minimum_version": true, "maximum_exclusive": true}
const EVENT_PLAYER_KEYS := {"catalog_id": true, "preset_count": true}
const OBJECTIVE_VALUES := {"remake_only": true, "original_engine_compatible": true, "mixed": true}
const WORKSPACE_KEYS := {
	"generation_sha256": true, "project_sha256": true, "manifest_sha256": true,
	"manifest_editor_version": true,
}
const SOURCE_KEYS := {"profile_id": true, "fingerprint_sha256": true, "archives": true}
const ARCHIVE_ROW_KEYS := {"archive": true, "sha256": true, "required": true, "bytes": true, "entries": true}
const REPLACEMENT_KEYS := {
	"target_archive": true, "target_entry": true, "original_entry_sha256": true, "original_size": true,
	"replacement_sha256": true, "replacement_size": true, "compatibility": true, "text_encoding": true,
	"authoring": true,
}
const AUTHORING_KEYS := {"bundle_schema": true, "proof_schema": true, "step_count": true, "operations": true}
const COMPATIBILITY_VALUES := {
	"remake_only": true, "original_engine_compatible": true, "original_engine_unverified": true,
}
const TEXT_ENCODING_VALUES := {"utf8": true, "cp932": true, "utf8_and_cp932": true, "not_applicable": true}
const PROJECTION_KEYS := {
	"kind": true, "target_archive": true, "target_entry": true, "original_entry_sha256": true,
	"projection_sha256": true, "edit_count": true, "compatibility": true, "text_encoding": true,
}
const COMPATIBILITY_BLOCK_KEYS := {
	"objective": true, "declared": true, "consistent_with_objective": true, "original_engine_verification": true,
}
const DECLARED_VALUES := {
	"not_applicable": true, "mixed": true, "remake_only": true,
	"original_engine_compatible": true, "original_engine_unverified": true,
}
const VERIFICATION_KEYS := {
	"manifest_payloads_verified": true, "replacement_blobs": true, "projection_files": true,
	"authoring_bundles_reopened": true,
}


static func build(workspace_root: String, content_set_root: String) -> Dictionary:
	var workspace := ContentWorkspaceScript.new()
	var opened := workspace.open(workspace_root, content_set_root)
	if not opened.get("ok", false):
		return _error(str(opened.get("error", "Provenance report workspace could not be opened.")))
	var snapshot := workspace.get_snapshot()
	workspace.close()
	var content_set := ContentSetScript.new()
	if not content_set.open(content_set_root):
		return _error(content_set.last_error)
	var result := _build_report(snapshot, content_set, workspace_root)
	content_set.close()
	return result


static func write(report: Dictionary, output_path: String) -> Dictionary:
	var output_absolute := ProjectSettings.globalize_path(output_path).simplify_path()
	if FileAccess.file_exists(output_absolute):
		return _error("Provenance report output already exists; it was not replaced.")
	var fingerprinter := FingerprintScript.new()
	var bytes := (fingerprinter.canonical_document_json(report) + "\n").to_utf8_buffer()
	var expected_sha := fingerprinter.sha256_bytes(bytes)
	if expected_sha.is_empty():
		return _error("Could not fingerprint the provenance report.")
	var temp_path := "%s.tmp-%s-%s" % [output_absolute, OS.get_process_id(), Time.get_ticks_usec()]
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return _error("Could not create provenance report temporary file (error %s)." % FileAccess.get_open_error())
	file.store_buffer(bytes)
	var write_error := file.get_error()
	file.close()
	if write_error != OK or FileAccess.get_sha256(temp_path) != expected_sha:
		_remove_if_present(temp_path)
		return _error("Provenance report temporary file failed verification.")
	if FileAccess.file_exists(output_absolute):
		_remove_if_present(temp_path)
		return _error("Provenance report output already exists; it was not replaced.")
	var rename_error := DirAccess.rename_absolute(temp_path, output_absolute)
	if rename_error != OK:
		_remove_if_present(temp_path)
		return _error("Could not publish the provenance report (error %s)." % rename_error)
	if FileAccess.get_sha256(output_absolute) != expected_sha:
		return _error("Published provenance report failed reopen verification.")
	return {"ok": true, "path": output_absolute, "sha256": expected_sha, "bytes": bytes.size()}


static func read_path(path: String) -> Dictionary:
	var absolute := ProjectSettings.globalize_path(path).simplify_path()
	var file := FileAccess.open(absolute, FileAccess.READ)
	if file == null:
		return _error("Provenance report could not be opened (error %s)." % FileAccess.get_open_error())
	var size := file.get_length()
	if size <= 0 or size > MAX_REPORT_BYTES:
		file.close()
		return _error("Provenance report exceeds its bounded JSON size.")
	var bytes := file.get_buffer(size)
	var read_error := file.get_error()
	file.close()
	if bytes.size() != size or read_error != OK:
		return _error("Provenance report changed or was truncated while reading.")
	var parsed = JSON.parse_string(bytes.get_string_from_utf8())
	if not parsed is Dictionary:
		return _error("Provenance report must be a JSON object.")
	return _validate_document(parsed)


static func _build_report(snapshot: Dictionary, content_set, workspace_root: String) -> Dictionary:
	var workspace_absolute := ProjectSettings.globalize_path(workspace_root).simplify_path()
	var project: Dictionary = snapshot.project
	var manifest: Dictionary = snapshot.manifest

	for untyped_row in snapshot.source_content_set.archives:
		var row: Dictionary = untyped_row
		var reader = content_set.get_reader(str(row.archive))
		if reader == null or not reader.is_open() or reader.get_archive_fingerprint() != str(row.sha256):
			return _error("Provenance report source archive no longer matches its binding: %s" % str(row.archive))

	var replacements_block: Array = []
	var authoring_reopened := 0
	var declared_values: Dictionary = {}
	for untyped_record in manifest.get("replacements", []):
		var record: Dictionary = untyped_record
		var row_result := _replacement_row(record, content_set, workspace_absolute)
		if not row_result.get("ok", false):
			return row_result
		var row: Dictionary = row_result.row
		replacements_block.append(row)
		if row.authoring != null:
			authoring_reopened += 1
		declared_values[str(row.compatibility)] = true

	var projections_block: Array = []
	for untyped_projection in manifest.get("projections", []):
		var projection: Dictionary = untyped_projection
		var row_result := _projection_row(projection, workspace_absolute)
		if not row_result.get("ok", false):
			return row_result
		var row: Dictionary = row_result.row
		projections_block.append(row)
		declared_values[str(row.compatibility)] = true

	var declared := "not_applicable"
	if declared_values.size() == 1:
		declared = str(declared_values.keys()[0])
	elif declared_values.size() > 1:
		declared = "mixed"
	var objective := str(project.compatibility_objective)
	var consistent := objective == "mixed" or objective == declared or declared == "not_applicable"

	var report := {
		"schema": ContentCoreVersionScript.CONTENT_PROVENANCE_REPORT_SCHEMA,
		"core_version": ContentCoreVersionScript.CORE_VERSION,
		"project": _project_block(project),
		"workspace": _workspace_block(snapshot),
		"source_content_set": _source_block(project, snapshot),
		"replacements": replacements_block,
		"projections": projections_block,
		"compatibility": {
			"objective": objective,
			"declared": declared,
			"consistent_with_objective": consistent,
			"original_engine_verification": "unverified",
		},
		"verification": {
			"manifest_payloads_verified": true,
			"replacement_blobs": replacements_block.size(),
			"projection_files": projections_block.size(),
			"authoring_bundles_reopened": authoring_reopened,
		},
	}
	report["payload_sha256"] = FingerprintScript.new().fingerprint(report)
	return {"ok": true, "report": report}


static func _project_block(project: Dictionary) -> Dictionary:
	return {
		"project_id": str(project.project_id),
		"project_version": str(project.project_version),
		"display_name": str(project.display_name),
		"project_revision": int(project.project_revision),
		"compatibility_objective": str(project.compatibility_objective),
		"content_core": {
			"minimum_version": str(project.content_core.minimum_version),
			"maximum_exclusive": str(project.content_core.maximum_exclusive),
		},
		"target_archives": (project.target_archives as Array).duplicate(true),
		"dependencies": (project.dependencies as Array).duplicate(true),
		"event_player": {
			"catalog_id": str(project.event_player.catalog_id),
			"preset_count": (project.event_player.presets as Array).size(),
		},
	}


static func _workspace_block(snapshot: Dictionary) -> Dictionary:
	return {
		"generation_sha256": str(snapshot.generation_sha256),
		"project_sha256": str(snapshot.project_sha256),
		"manifest_sha256": str(snapshot.manifest_sha256),
		"manifest_editor_version": str(snapshot.manifest.editor_version),
	}


static func _source_block(project: Dictionary, snapshot: Dictionary) -> Dictionary:
	var archives: Array = []
	for untyped_row in snapshot.source_content_set.archives:
		var row: Dictionary = untyped_row
		archives.append({
			"archive": str(row.archive),
			"sha256": str(row.sha256),
			"required": bool(row.required),
			"bytes": int(row.bytes),
			"entries": int(row.entries),
		})
	return {
		"profile_id": str(project.source_content_set.profile_id),
		"fingerprint_sha256": str(snapshot.source_content_set.fingerprint_sha256),
		"archives": archives,
	}


static func _replacement_row(record: Dictionary, content_set, workspace_root: String) -> Dictionary:
	var target_archive := str(record.target_archive)
	var target_entry := str(record.target_entry)
	var reader = content_set.get_reader(target_archive)
	if reader == null:
		return _error("Provenance report replacement archive is unavailable: %s" % target_archive)
	var entry: Dictionary = reader.get_entry(target_entry)
	if entry.is_empty() or reader.get_entry_fingerprint(str(entry.name)) != str(record.original_entry_sha256):
		return _error("Provenance report replacement original entry no longer matches its binding: %s" % target_entry)
	var replacement_path := workspace_root.path_join(str(record.replacement_path))
	if not FileAccess.file_exists(replacement_path) or FileAccess.get_sha256(replacement_path) != str(record.replacement_sha256):
		return _error("Provenance report replacement blob is missing or changed: %s" % target_entry)
	var replacement_size := _file_size(replacement_path)
	if replacement_size < 0:
		return _error("Provenance report replacement blob is missing or changed: %s" % target_entry)
	var authoring = _link_authoring(workspace_root, target_entry, str(record.original_entry_sha256), str(record.replacement_sha256))
	var row := {
		"target_archive": target_archive,
		"target_entry": target_entry,
		"original_entry_sha256": str(record.original_entry_sha256),
		"original_size": int(entry.size),
		"replacement_sha256": str(record.replacement_sha256),
		"replacement_size": replacement_size,
		"compatibility": str(record.compatibility),
		"text_encoding": str(record.text_encoding),
		"authoring": authoring,
	}
	return {"ok": true, "row": row}


static func _projection_row(record: Dictionary, workspace_root: String) -> Dictionary:
	var target_entry := str(record.target_entry)
	var projection_path := workspace_root.path_join(str(record.projection_path))
	if not FileAccess.file_exists(projection_path) or FileAccess.get_sha256(projection_path) != str(record.projection_sha256):
		return _error("Provenance report projection file is missing or changed: %s" % target_entry)
	var document = JSON.parse_string(FileAccess.get_file_as_string(projection_path))
	if not document is Dictionary or not document.get("edits", null) is Array:
		return _error("Provenance report projection file is missing or changed: %s" % target_entry)
	var row := {
		"kind": str(record.kind),
		"target_archive": str(record.target_archive),
		"target_entry": target_entry,
		"original_entry_sha256": str(record.original_entry_sha256),
		"projection_sha256": str(record.projection_sha256),
		"edit_count": (document.edits as Array).size(),
		"compatibility": str(record.compatibility),
		"text_encoding": str(record.text_encoding),
	}
	return {"ok": true, "row": row}


## Scans `authoring/*` and `.authoring/delta` in sorted order for the first
## bundle whose reopened summary binds the exact original/replacement hashes
## and target entry. Returns `null` when nothing matches.
static func _link_authoring(workspace_root: String, target_entry: String, original_entry_sha256: String, replacement_sha256: String):
	var candidates: Array[String] = []
	if DirAccess.dir_exists_absolute(workspace_root.path_join(".authoring/delta")):
		candidates.append(".authoring/delta")
	var authoring_root := workspace_root.path_join("authoring")
	if DirAccess.dir_exists_absolute(authoring_root):
		for name in DirAccess.get_directories_at(authoring_root):
			candidates.append("authoring/%s" % name)
	candidates.sort()
	var target_upper := target_entry.to_upper()
	for relative in candidates:
		var bundle := SessionScript.read_bundle(workspace_root.path_join(relative))
		if not bundle.get("ok", false):
			continue
		var summary: Dictionary = bundle.manifest.summary
		if str(summary.get("source_entry_sha256", "")) != original_entry_sha256:
			continue
		if str(summary.get("output_entry_sha256", "")) != replacement_sha256:
			continue
		var source_identity: Dictionary = summary.get("source_identity", {})
		if str(source_identity.get("entry", "")).to_upper() != target_upper:
			continue
		return {
			"bundle_schema": str(bundle.manifest.schema),
			"proof_schema": str(bundle.proof.get("schema", "")),
			"step_count": int(summary.get("step_count", 0)),
			"operations": (summary.get("operations", []) as Array).duplicate(true),
		}
	return null


static func _validate_document(report: Dictionary) -> Dictionary:
	if not ContractValues.has_exact_key_set(report, TOP_LEVEL_KEYS):
		return _error("Provenance report top-level contract is invalid.")
	if str(report.get("schema", "")) != ContentCoreVersionScript.CONTENT_PROVENANCE_REPORT_SCHEMA:
		return _error("Unsupported provenance report schema.")
	if not report.get("core_version", null) is String or str(report.core_version).is_empty():
		return _error("Provenance report core version is invalid.")
	if not ContractValues.is_sha256(str(report.get("payload_sha256", ""))) or FingerprintScript.new().fingerprint(report) != str(report.payload_sha256):
		return _error("Provenance report fingerprint does not match its payload.")
	var project = report.get("project", null)
	if not project is Dictionary or not _validate_project_block(project):
		return _error("Provenance report project block is invalid.")
	var workspace = report.get("workspace", null)
	if not workspace is Dictionary or not _validate_workspace_block(workspace):
		return _error("Provenance report workspace block is invalid.")
	var source = report.get("source_content_set", null)
	if not source is Dictionary or not _validate_source_block(source):
		return _error("Provenance report source content set block is invalid.")
	var replacements = report.get("replacements", null)
	if not replacements is Array or not _validate_replacements(replacements):
		return _error("Provenance report replacements are invalid.")
	var projections = report.get("projections", null)
	if not projections is Array or not _validate_projections(projections):
		return _error("Provenance report projections are invalid.")
	var compatibility = report.get("compatibility", null)
	if not compatibility is Dictionary or not _validate_compatibility_block(compatibility):
		return _error("Provenance report compatibility block is invalid.")
	var verification = report.get("verification", null)
	if not verification is Dictionary or not _validate_verification_block(verification):
		return _error("Provenance report verification block is invalid.")
	return {"ok": true, "report": report.duplicate(true)}


static func _validate_project_block(value: Dictionary) -> bool:
	if not ContractValues.has_exact_key_set(value, PROJECT_KEYS):
		return false
	if not value.get("project_id", null) is String or str(value.project_id).is_empty():
		return false
	if not value.get("project_version", null) is String or str(value.project_version).is_empty():
		return false
	if not value.get("display_name", null) is String or str(value.display_name).is_empty():
		return false
	if not _nonnegative_int(value.get("project_revision", null)) or int(value.project_revision) <= 0:
		return false
	if not OBJECTIVE_VALUES.has(str(value.get("compatibility_objective", ""))):
		return false
	var core = value.get("content_core", null)
	if not core is Dictionary or not ContractValues.has_exact_key_set(core, CORE_REQUIREMENT_KEYS):
		return false
	if not core.get("minimum_version", null) is String or not core.get("maximum_exclusive", null) is String:
		return false
	if not value.get("target_archives", null) is Array or value.target_archives.is_empty():
		return false
	for archive in value.target_archives:
		if not archive is String or str(archive).is_empty():
			return false
	if not value.get("dependencies", null) is Array:
		return false
	var event_player = value.get("event_player", null)
	if not event_player is Dictionary or not ContractValues.has_exact_key_set(event_player, EVENT_PLAYER_KEYS):
		return false
	if not event_player.get("catalog_id", null) is String or str(event_player.catalog_id).is_empty():
		return false
	if not _nonnegative_int(event_player.get("preset_count", null)):
		return false
	return true


static func _validate_workspace_block(value: Dictionary) -> bool:
	if not ContractValues.has_exact_key_set(value, WORKSPACE_KEYS):
		return false
	for hash_field in ["generation_sha256", "project_sha256", "manifest_sha256"]:
		if not ContractValues.is_sha256(str(value.get(hash_field, ""))):
			return false
	return value.get("manifest_editor_version", null) is String and not str(value.manifest_editor_version).is_empty()


static func _validate_source_block(value: Dictionary) -> bool:
	if not ContractValues.has_exact_key_set(value, SOURCE_KEYS):
		return false
	if not value.get("profile_id", null) is String or str(value.profile_id).is_empty():
		return false
	if not ContractValues.is_sha256(str(value.get("fingerprint_sha256", ""))):
		return false
	if not value.get("archives", null) is Array or value.archives.is_empty():
		return false
	for untyped_row in value.archives:
		if not untyped_row is Dictionary or not ContractValues.has_exact_key_set(untyped_row, ARCHIVE_ROW_KEYS):
			return false
		var row: Dictionary = untyped_row
		if not row.get("archive", null) is String or str(row.archive).is_empty():
			return false
		if not ContractValues.is_sha256(str(row.get("sha256", ""))):
			return false
		if not row.get("required", null) is bool:
			return false
		if not _nonnegative_int(row.get("bytes", null)):
			return false
		if not _nonnegative_int(row.get("entries", null)):
			return false
	return true


static func _validate_replacements(rows: Array) -> bool:
	for untyped_row in rows:
		if not untyped_row is Dictionary:
			return false
		var row: Dictionary = untyped_row
		if not ContractValues.has_exact_key_set(row, REPLACEMENT_KEYS):
			return false
		if not row.get("target_archive", null) is String or str(row.target_archive).is_empty():
			return false
		if not row.get("target_entry", null) is String or str(row.target_entry).is_empty():
			return false
		if not ContractValues.is_sha256(str(row.get("original_entry_sha256", ""))):
			return false
		if not _nonnegative_int(row.get("original_size", null)):
			return false
		if not ContractValues.is_sha256(str(row.get("replacement_sha256", ""))):
			return false
		if not _nonnegative_int(row.get("replacement_size", null)):
			return false
		if not COMPATIBILITY_VALUES.has(str(row.get("compatibility", ""))):
			return false
		if not TEXT_ENCODING_VALUES.has(str(row.get("text_encoding", ""))):
			return false
		if row.get("authoring", "missing") != null:
			var authoring = row.get("authoring", null)
			if not authoring is Dictionary or not ContractValues.has_exact_key_set(authoring, AUTHORING_KEYS):
				return false
			if not authoring.get("bundle_schema", null) is String or str(authoring.bundle_schema).is_empty():
				return false
			if not authoring.get("proof_schema", null) is String or str(authoring.proof_schema).is_empty():
				return false
			if not _nonnegative_int(authoring.get("step_count", null)):
				return false
			if not authoring.get("operations", null) is Array:
				return false
	return true


static func _validate_projections(rows: Array) -> bool:
	for untyped_row in rows:
		if not untyped_row is Dictionary:
			return false
		var row: Dictionary = untyped_row
		if not ContractValues.has_exact_key_set(row, PROJECTION_KEYS):
			return false
		if str(row.get("kind", "")) != "mes_text":
			return false
		if not row.get("target_archive", null) is String or str(row.target_archive).is_empty():
			return false
		if not row.get("target_entry", null) is String or str(row.target_entry).is_empty():
			return false
		if not ContractValues.is_sha256(str(row.get("original_entry_sha256", ""))):
			return false
		if not ContractValues.is_sha256(str(row.get("projection_sha256", ""))):
			return false
		if not _nonnegative_int(row.get("edit_count", null)) or int(row.edit_count) <= 0:
			return false
		if str(row.get("compatibility", "")) != "remake_only":
			return false
		if str(row.get("text_encoding", "")) != "utf8":
			return false
	return true


static func _validate_compatibility_block(value: Dictionary) -> bool:
	if not ContractValues.has_exact_key_set(value, COMPATIBILITY_BLOCK_KEYS):
		return false
	if not OBJECTIVE_VALUES.has(str(value.get("objective", ""))):
		return false
	if not DECLARED_VALUES.has(str(value.get("declared", ""))):
		return false
	if not value.get("consistent_with_objective", null) is bool:
		return false
	return str(value.get("original_engine_verification", "")) == "unverified"


static func _validate_verification_block(value: Dictionary) -> bool:
	if not ContractValues.has_exact_key_set(value, VERIFICATION_KEYS):
		return false
	if value.get("manifest_payloads_verified", null) != true:
		return false
	for key in ["replacement_blobs", "projection_files", "authoring_bundles_reopened"]:
		if not _nonnegative_int(value.get(key, null)):
			return false
	return true


static func _nonnegative_int(value) -> bool:
	if value is int:
		return value >= 0
	if value is float:
		return is_finite(value) and value >= 0.0 and value == floor(value)
	return false


static func _file_size(path: String) -> int:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return -1
	var size := file.get_length()
	file.close()
	return size


static func _remove_if_present(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


static func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message}
