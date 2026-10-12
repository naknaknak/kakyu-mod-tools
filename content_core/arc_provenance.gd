class_name KakyuArcProvenance
extends RefCounted

const ArcReaderScript := preload("res://content_core/arc_reader.gd")
const ArcWriterScript := preload("res://content_core/arc_writer.gd")
const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")
const PublicationLockScript := preload("res://content_core/publication_lock.gd")
const ContractValues := preload("res://content_core/contract_values.gd")

const SIDECAR_SUFFIX := ".kakyu-provenance.json"
const MAX_PROVENANCE_BYTES := 2 * 1024 * 1024
const COMPATIBILITY_VALUES := {
	"remake_only": true,
	"original_engine_compatible": true,
	"original_engine_unverified": true,
	"mixed": true,
}

var last_error := ""


func materialize_repacked_copy_from_bound_files(
	source_path: String,
	output_path: String,
	expected_source_sha256: String,
	replacement_files: Dictionary,
	declared_compatibility := "original_engine_unverified",
	workspace_snapshot := {}
) -> Dictionary:
	return _materialize(
		source_path, output_path, expected_source_sha256, replacement_files,
		true, true, declared_compatibility, workspace_snapshot
	)


func materialize_copy_if_source_matches(
	source_path: String,
	output_path: String,
	expected_source_sha256: String,
	replacements: Dictionary,
	declared_compatibility := "original_engine_unverified",
	workspace_snapshot := {}
) -> Dictionary:
	return _materialize(
		source_path, output_path, expected_source_sha256, replacements,
		false, false, declared_compatibility, workspace_snapshot
	)


func sidecar_path(arc_path: String) -> String:
	return ProjectSettings.globalize_path(arc_path).simplify_path() + SIDECAR_SUFFIX


func load_sidecar(arc_path: String) -> Dictionary:
	last_error = ""
	var path := sidecar_path(arc_path)
	if not FileAccess.file_exists(path):
		return _error("Materialized ARC provenance sidecar is missing.")
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _error("Materialized ARC provenance sidecar could not be opened.")
	var size := file.get_length()
	if size <= 0 or size > MAX_PROVENANCE_BYTES:
		file.close()
		return _error("Materialized ARC provenance sidecar exceeds its bounded JSON size.")
	var bytes := file.get_buffer(size)
	var read_error := file.get_error()
	file.close()
	if bytes.size() != size or read_error != OK:
		return _error("Materialized ARC provenance sidecar changed while reading.")
	var parsed = JSON.parse_string(bytes.get_string_from_utf8())
	if not parsed is Dictionary:
		return _error("Materialized ARC provenance sidecar must be a JSON object.")
	var validation := _validate_document(parsed)
	if not validation.ok:
		return validation
	return {
		"ok": true,
		"path": path,
		"sha256": _sha256_bytes(bytes),
		"provenance": parsed.duplicate(true),
	}


func classify(arc_path: String, original_reader = null, expected_archive_name := "") -> Dictionary:
	last_error = ""
	var arc_absolute := ProjectSettings.globalize_path(arc_path).simplify_path()
	if not FileAccess.file_exists(arc_absolute):
		return _error("ARC classification input does not exist.")
	var arc_sha := FileAccess.get_sha256(arc_absolute)
	if arc_sha.is_empty():
		return _error("ARC classification input could not be fingerprinted.")
	var expected_name := expected_archive_name.to_lower()
	if not expected_name.is_empty() and not _is_archive_name(expected_name):
		return _error("Expected ARC identity is invalid.")
	if original_reader != null and original_reader.is_open():
		var original_sha: String = original_reader.get_archive_fingerprint()
		if arc_sha == original_sha:
			return {
				"ok": true,
				"classification": "exact_original",
				"verified": true,
				"archive": expected_name if not expected_name.is_empty() else original_reader.archive_path.get_file().to_lower(),
				"sha256": arc_sha,
			}
	var loaded := load_sidecar(arc_absolute)
	if not loaded.ok:
		return {
			"ok": true,
			"classification": "unknown_raw",
			"verified": false,
			"archive": expected_name,
			"sha256": arc_sha,
			"reason": str(loaded.error),
		}
	var provenance: Dictionary = loaded.provenance
	var archive_name := str(provenance.archive)
	if (not expected_name.is_empty() and archive_name != expected_name) or str(provenance.materialized.filename) != arc_absolute.get_file() or str(provenance.materialized.sha256) != arc_sha or int(provenance.materialized.bytes) != _file_size(arc_absolute):
		return _unknown(archive_name, arc_sha, "Provenance does not match the selected materialized ARC.")
	var derived_reader := ArcReaderScript.new()
	if not derived_reader.open(arc_absolute):
		return _unknown(archive_name, arc_sha, "Materialized ARC structure is invalid: %s" % derived_reader.last_error)
	if derived_reader.get_entries().size() != int(provenance.materialized.entry_count):
		derived_reader.close()
		return _unknown(archive_name, arc_sha, "Materialized ARC entry count does not match provenance.")
	if original_reader == null or not original_reader.is_open():
		derived_reader.close()
		return {
			"ok": true,
			"classification": "declared_original_derived",
			"verified": false,
			"archive": archive_name,
			"sha256": arc_sha,
			"provenance": provenance.duplicate(true),
			"reason": "Select the bound original ARC to verify unchanged entries and lineage.",
		}
	var verified := _verify_against_original(provenance, derived_reader, original_reader)
	derived_reader.close()
	if not verified.ok:
		return _unknown(archive_name, arc_sha, str(verified.error))
	return {
		"ok": true,
		"classification": "verified_original_derived",
		"verified": true,
		"archive": archive_name,
		"sha256": arc_sha,
		"source_sha256": str(provenance.source.sha256),
		"replacement_count": provenance.replacements.size(),
		"declared_compatibility": str(provenance.declared_compatibility),
		"workspace": provenance.workspace.duplicate(true),
		"provenance": provenance.duplicate(true),
	}


func _materialize(
	source_path: String,
	output_path: String,
	expected_source_sha256: String,
	replacements: Dictionary,
	allow_resize: bool,
	from_bound_files: bool,
	declared_compatibility: String,
	workspace_snapshot: Dictionary
) -> Dictionary:
	last_error = ""
	var source_absolute := ProjectSettings.globalize_path(source_path).simplify_path()
	var output_absolute := ProjectSettings.globalize_path(output_path).simplify_path()
	var archive_name := source_absolute.get_file().to_lower()
	if not _is_archive_name(archive_name) or output_absolute.get_extension().to_lower() != "arc":
		return _error("Materialized ARC source and output must use safe ARC identities.")
	if source_absolute.to_lower() == output_absolute.to_lower():
		return _error("Source ARC overwrite is forbidden.")
	if not COMPATIBILITY_VALUES.has(declared_compatibility):
		return _error("Materialized ARC compatibility value is invalid.")
	if not ContractValues.is_sha256(expected_source_sha256):
		return _error("Materialized ARC requires the opened source SHA-256.")
	var source_reader := ArcReaderScript.new()
	if not source_reader.open(source_absolute):
		return _error(source_reader.last_error)
	if source_reader.get_archive_fingerprint() != expected_source_sha256:
		source_reader.close()
		return _error("Source ARC changed after it was opened; materialization was refused.")
	var workspace_result := _workspace_record(workspace_snapshot, archive_name, expected_source_sha256)
	if not workspace_result.ok:
		source_reader.close()
		return workspace_result
	var parent := output_absolute.get_base_dir()
	var lock_name := ".%s.materialize.lock" % output_absolute.get_file()
	var lock := PublicationLockScript.new().acquire(parent, lock_name)
	if not lock.ok:
		source_reader.close()
		return _error(str(lock.error))
	var result := _materialize_locked(
		source_absolute, output_absolute, archive_name, expected_source_sha256,
		replacements, allow_resize, from_bound_files, declared_compatibility,
		workspace_result.record, source_reader
	)
	var release := PublicationLockScript.new().release(lock)
	source_reader.close()
	if result.ok and not release.ok:
		return _error(str(release.error))
	return result


func _materialize_locked(
	source_absolute: String,
	output_absolute: String,
	archive_name: String,
	expected_source_sha256: String,
	replacements: Dictionary,
	allow_resize: bool,
	from_bound_files: bool,
	declared_compatibility: String,
	workspace_record: Dictionary,
	source_reader
) -> Dictionary:
	var final_sidecar := sidecar_path(output_absolute)
	if FileAccess.file_exists(output_absolute) or FileAccess.file_exists(final_sidecar):
		return _error("Materialized ARC output or provenance sidecar already exists; nothing was replaced.")
	var token := "%s-%s" % [OS.get_process_id(), Time.get_ticks_usec()]
	var staged_arc := "%s.materialize-%s.tmp" % [output_absolute, token]
	var writer := ArcWriterScript.new()
	var written: Dictionary
	if from_bound_files:
		written = writer.write_repacked_copy_from_bound_files(
			source_absolute, staged_arc, expected_source_sha256, replacements
		)
	elif allow_resize:
		written = writer.write_repacked_copy_if_source_matches(
			source_absolute, staged_arc, expected_source_sha256, replacements
		)
	else:
		written = writer.write_copy_if_source_matches(
			source_absolute, staged_arc, expected_source_sha256, replacements
		)
	if not written.ok:
		return _error(str(written.error))
	var document := {
		"schema": ContentCoreVersionScript.MATERIALIZED_ARC_PROVENANCE_SCHEMA,
		"core_version": ContentCoreVersionScript.CORE_VERSION,
		"archive": archive_name,
		"declared_compatibility": declared_compatibility,
		"source": {
			"archive": archive_name,
			"sha256": expected_source_sha256,
			"bytes": int(source_reader.archive_size),
			"entry_count": source_reader.get_entries().size(),
		},
		"materialized": {
			"filename": output_absolute.get_file(),
			"sha256": str(written.sha256),
			"bytes": _file_size(staged_arc),
			"entry_count": source_reader.get_entries().size(),
			"layout": str(written.layout),
		},
		"replacements": written.replacement_bindings.duplicate(true),
		"workspace": workspace_record.duplicate(true),
	}
	var validation := _validate_document(document)
	if not validation.ok:
		_remove_file(staged_arc)
		return validation
	var sidecar_bytes := (JSON.stringify(document, "  ") + "\n").to_utf8_buffer()
	var sidecar_sha := _sha256_bytes(sidecar_bytes)
	var staged_sidecar := "%s.tmp-%s" % [final_sidecar, token]
	var sidecar_file := FileAccess.open(staged_sidecar, FileAccess.WRITE)
	if sidecar_file == null:
		_remove_file(staged_arc)
		return _error("Could not create materialized ARC provenance temporary file.")
	sidecar_file.store_buffer(sidecar_bytes)
	var sidecar_error := sidecar_file.get_error()
	sidecar_file.close()
	if sidecar_error != OK or FileAccess.get_sha256(staged_sidecar) != sidecar_sha:
		_remove_file(staged_arc)
		_remove_file(staged_sidecar)
		return _error("Materialized ARC provenance temporary file failed verification.")
	if FileAccess.file_exists(output_absolute) or FileAccess.file_exists(final_sidecar):
		_remove_file(staged_arc)
		_remove_file(staged_sidecar)
		return _error("Materialized ARC output appeared before publication; it was preserved.")
	var sidecar_rename := DirAccess.rename_absolute(staged_sidecar, final_sidecar)
	if sidecar_rename != OK:
		_remove_file(staged_arc)
		_remove_file(staged_sidecar)
		return _error("Could not publish materialized ARC provenance (error %s)." % sidecar_rename)
	var arc_rename := DirAccess.rename_absolute(staged_arc, output_absolute)
	if arc_rename != OK:
		_remove_exact_file(final_sidecar, sidecar_sha)
		_remove_file(staged_arc)
		return _error("Could not publish materialized ARC after provenance (error %s)." % arc_rename)
	var classified := classify(output_absolute, source_reader, archive_name)
	if not classified.ok or str(classified.classification) not in ["verified_original_derived", "exact_original"]:
		_remove_exact_file(output_absolute, str(written.sha256))
		_remove_exact_file(final_sidecar, sidecar_sha)
		return _error("Published materialized ARC failed provenance reopen verification.")
	return {
		"ok": true,
		"path": output_absolute,
		"sha256": str(written.sha256),
		"sidecar_path": final_sidecar,
		"sidecar_sha256": sidecar_sha,
		"source_sha256": expected_source_sha256,
		"replacement_count": document.replacements.size(),
		"resized_count": int(written.resized_count),
		"layout": str(written.layout),
		"classification": str(classified.classification),
		"provenance": document.duplicate(true),
	}


func _verify_against_original(provenance: Dictionary, derived_reader, original_reader) -> Dictionary:
	var source_sha: String = original_reader.get_archive_fingerprint()
	if source_sha != str(provenance.source.sha256) or int(original_reader.archive_size) != int(provenance.source.bytes):
		return _error("Selected original ARC does not match provenance source lineage.")
	var source_entries: Array = original_reader.get_entries()
	var derived_entries: Array = derived_reader.get_entries()
	if source_entries.size() != int(provenance.source.entry_count) or source_entries.size() != derived_entries.size():
		return _error("Original/materialized ARC entry counts do not match provenance.")
	var replacements := {}
	for value in provenance.replacements:
		var record: Dictionary = value
		replacements[str(record.entry).to_upper()] = record
	var reached := {}
	for index in range(source_entries.size()):
		var source_entry: Dictionary = source_entries[index]
		var derived_entry: Dictionary = derived_entries[index]
		if str(source_entry.name) != str(derived_entry.name):
			return _error("Materialized ARC entry order/name differs from the source ARC.")
		var key := str(source_entry.name).to_upper()
		var source_entry_sha: String = original_reader.get_entry_fingerprint(str(source_entry.name))
		var derived_entry_sha: String = derived_reader.get_entry_fingerprint(str(derived_entry.name))
		if replacements.has(key):
			var record: Dictionary = replacements[key]
			if source_entry_sha != str(record.original_entry_sha256) or derived_entry_sha != str(record.replacement_sha256) or int(source_entry.size) != int(record.original_size) or int(derived_entry.size) != int(record.replacement_size):
				return _error("Materialized replacement does not match provenance: %s" % str(source_entry.name))
			reached[key] = true
		elif source_entry_sha != derived_entry_sha or int(source_entry.size) != int(derived_entry.size):
			return _error("Unchanged materialized entry differs from the source ARC: %s" % str(source_entry.name))
	if reached.size() != replacements.size():
		return _error("Provenance contains a replacement not present in the materialized ARC.")
	return {"ok": true}


func _workspace_record(snapshot: Dictionary, archive_name: String, source_sha256: String) -> Dictionary:
	if snapshot.is_empty():
		return {"ok": true, "record": {}}
	if str(snapshot.get("schema", "")) != ContentCoreVersionScript.CONTENT_WORKSPACE_SNAPSHOT_SCHEMA:
		return _error("Materialized ARC workspace snapshot schema is invalid.")
	var project = snapshot.get("project", null)
	var source = snapshot.get("source_content_set", null)
	if not project is Dictionary or not source is Dictionary:
		return _error("Materialized ARC workspace snapshot is incomplete.")
	var archive_bound := false
	for value in source.get("archives", []):
		if value is Dictionary and str(value.get("archive", "")) == archive_name and str(value.get("sha256", "")) == source_sha256:
			archive_bound = true
			break
	if not archive_bound:
		return _error("Materialized ARC source is not bound by the workspace snapshot.")
	var record := {
		"project_id": str(project.get("project_id", "")),
		"project_version": str(project.get("project_version", "")),
		"project_revision": int(project.get("project_revision", 0)),
		"compatibility_objective": str(project.get("compatibility_objective", "")),
		"source_content_set_fingerprint": str(source.get("fingerprint_sha256", "")),
		"project_sha256": str(snapshot.get("project_sha256", "")),
		"manifest_sha256": str(snapshot.get("manifest_sha256", "")),
		"generation_sha256": str(snapshot.get("generation_sha256", "")),
	}
	for hash_field in ["source_content_set_fingerprint", "project_sha256", "manifest_sha256", "generation_sha256"]:
		if not ContractValues.is_sha256(str(record[hash_field])):
			return _error("Materialized ARC workspace snapshot hash is invalid: %s" % hash_field)
	return {"ok": true, "record": record}


func _validate_document(document: Dictionary) -> Dictionary:
	var top_keys := {
		"schema": true, "core_version": true, "archive": true,
		"declared_compatibility": true, "source": true, "materialized": true,
		"replacements": true, "workspace": true,
	}
	if not ContractValues.has_only_key_set(document, top_keys) or str(document.get("schema", "")) != ContentCoreVersionScript.MATERIALIZED_ARC_PROVENANCE_SCHEMA or not _is_archive_name(str(document.get("archive", ""))) or not COMPATIBILITY_VALUES.has(str(document.get("declared_compatibility", ""))):
		return _error("Materialized ARC provenance top-level contract is invalid.")
	if not document.get("core_version", null) is String:
		return _error("Materialized ARC provenance core version is invalid.")
	var source = document.get("source", null)
	var materialized = document.get("materialized", null)
	var replacements = document.get("replacements", null)
	var workspace = document.get("workspace", null)
	if not source is Dictionary or not materialized is Dictionary or not replacements is Array or not workspace is Dictionary:
		return _error("Materialized ARC provenance records are invalid.")
	if not ContractValues.has_only_key_set(source, {"archive": true, "sha256": true, "bytes": true, "entry_count": true}) or str(source.get("archive", "")) != str(document.archive) or not ContractValues.is_sha256(str(source.get("sha256", ""))) or not _positive_json_integer(source.get("bytes", null)) or not _positive_json_integer(source.get("entry_count", null)):
		return _error("Materialized ARC provenance source binding is invalid.")
	if not ContractValues.has_only_key_set(materialized, {"filename": true, "sha256": true, "bytes": true, "entry_count": true, "layout": true}) or not ArcReaderScript.is_safe_entry_name(str(materialized.get("filename", ""))) or str(materialized.get("filename", "")).get_extension().to_lower() != "arc" or not ContractValues.is_sha256(str(materialized.get("sha256", ""))) or not _positive_json_integer(materialized.get("bytes", null)) or not _positive_json_integer(materialized.get("entry_count", null)) or str(materialized.get("layout", "")) not in ["canonical_contiguous", "preserved_source_layout"]:
		return _error("Materialized ARC provenance output binding is invalid.")
	if int(source.entry_count) != int(materialized.entry_count):
		return _error("Materialized ARC provenance cannot change entry count.")
	var names := {}
	for value in replacements:
		if not value is Dictionary:
			return _error("Materialized ARC provenance replacement is invalid.")
		var record: Dictionary = value
		if not ContractValues.has_only_key_set(record, {"entry": true, "original_entry_sha256": true, "replacement_sha256": true, "original_size": true, "replacement_size": true}):
			return _error("Materialized ARC provenance replacement contains an unknown field.")
		var entry_name := str(record.get("entry", ""))
		if not ArcReaderScript.is_safe_entry_name(entry_name) or names.has(entry_name.to_upper()) or not ContractValues.is_sha256(str(record.get("original_entry_sha256", ""))) or not ContractValues.is_sha256(str(record.get("replacement_sha256", ""))) or not _nonnegative_json_integer(record.get("original_size", null)) or not _nonnegative_json_integer(record.get("replacement_size", null)):
			return _error("Materialized ARC provenance replacement binding is invalid or duplicated.")
		names[entry_name.to_upper()] = true
	if not workspace.is_empty():
		var workspace_keys := {"project_id": true, "project_version": true, "project_revision": true, "compatibility_objective": true, "source_content_set_fingerprint": true, "project_sha256": true, "manifest_sha256": true, "generation_sha256": true}
		if not ContractValues.has_only_key_set(workspace, workspace_keys) or str(workspace.get("project_id", "")).is_empty() or str(workspace.get("project_version", "")).is_empty() or not _positive_json_integer(workspace.get("project_revision", null)) or str(workspace.get("compatibility_objective", "")) not in ["remake_only", "original_engine_compatible", "mixed"]:
			return _error("Materialized ARC provenance workspace identity is invalid.")
		for hash_field in ["source_content_set_fingerprint", "project_sha256", "manifest_sha256", "generation_sha256"]:
			if not ContractValues.is_sha256(str(workspace.get(hash_field, ""))):
				return _error("Materialized ARC provenance workspace hash is invalid.")
	return {"ok": true}


func _unknown(archive_name: String, sha256: String, reason: String) -> Dictionary:
	return {"ok": true, "classification": "unknown_raw", "verified": false, "archive": archive_name, "sha256": sha256, "reason": reason}


func _positive_json_integer(value) -> bool:
	return _nonnegative_json_integer(value) and int(value) > 0


func _nonnegative_json_integer(value) -> bool:
	if value is int:
		return value >= 0
	if value is float:
		return is_finite(value) and value >= 0.0 and value == floor(value)
	return false


func _is_archive_name(value: String) -> bool:
	return value == value.to_lower() and value.get_extension() == "arc" and ArcReaderScript.is_safe_entry_name(value)


func _file_size(path: String) -> int:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return -1
	var size := file.get_length()
	file.close()
	return size


func _sha256_bytes(data: PackedByteArray) -> String:
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK or context.update(data) != OK:
		return ""
	return context.finish().hex_encode()


func _remove_exact_file(path: String, expected_sha256: String) -> void:
	if FileAccess.file_exists(path) and FileAccess.get_sha256(path) == expected_sha256:
		DirAccess.remove_absolute(path)


func _remove_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func _error(message: String) -> Dictionary:
	last_error = message
	return {"ok": false, "schema": ContentCoreVersionScript.MATERIALIZED_ARC_PROVENANCE_SCHEMA, "error": message}
