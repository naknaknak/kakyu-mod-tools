class_name KakyuOverlayPackage
extends RefCounted

const ArcReaderScript := preload("res://content_core/arc_reader.gd")
const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")
const Cp932CodecScript := preload("res://content_core/cp932_codec.gd")
const MesContainerScript := preload("res://content_core/mes_container.gd")
const MesAnalysisScript := preload("res://content_core/mes_analysis_index.gd")
const MesUtf8OverlayPlanScript := preload("res://content_core/mes_utf8_overlay_plan.gd")
const PublicationLockScript := preload("res://content_core/publication_lock.gd")
const ProcessLivenessScript := preload("res://content_core/process_liveness.gd")
const ContractValues := preload("res://content_core/contract_values.gd")

const MANIFEST_FILENAME := "manifest.json"
const MANIFEST_LOCK_DIRECTORY := ".manifest.lock"
const MAX_MANIFEST_BYTES := 8 * 1024 * 1024
const MAX_DEFINITION_BYTES := 1 * 1024 * 1024
const DEFINITION_KIND := "mod_event_definition"
const COMPATIBILITY_VALUES := [
	"remake_only", "original_engine_compatible", "original_engine_unverified",
]
const TEXT_ENCODING_VALUES := ["utf8", "cp932", "utf8_and_cp932", "not_applicable"]


func create_empty_manifest(package_root: String) -> Dictionary:
	if package_root.is_empty():
		return _error("Overlay package root is empty.")
	var package_absolute := ProjectSettings.globalize_path(package_root).simplify_path()
	var lock := _acquire_manifest_lock(package_absolute)
	if not lock.ok:
		return lock
	var manifest_path := package_absolute.path_join(MANIFEST_FILENAME)
	var result: Dictionary
	if FileAccess.file_exists(manifest_path):
		result = _error("Overlay manifest already exists; it was not replaced.")
	else:
		var manifest := {
			"schema": ContentCoreVersionScript.OVERLAY_SCHEMA,
			"editor_version": ContentCoreVersionScript.CORE_VERSION,
			"replacements": [],
			"projections": [],
			"definitions": [],
		}
		var validation := _validate_manifest(package_absolute, manifest)
		if not validation.ok:
			result = validation
		else:
			result = _write_manifest_atomic(manifest_path, manifest, false, "")
			if result.ok:
				var reopened := load_manifest(package_absolute)
				if not reopened.ok or str(reopened.sha256) != str(result.sha256):
					result = _error("Published empty overlay manifest failed reopen validation.")
				else:
					result["path"] = manifest_path
					result["manifest"] = reopened.manifest.duplicate(true)
	var release := _release_manifest_lock(lock)
	if not release.ok and result.ok:
		return release
	return result


func load_manifest(package_root: String) -> Dictionary:
	if package_root.is_empty():
		return _error("Overlay package root is empty.")
	var manifest_path := package_root.path_join(MANIFEST_FILENAME)
	if not FileAccess.file_exists(manifest_path):
		return _error("Overlay manifest does not exist: %s" % manifest_path)
	var file := FileAccess.open(manifest_path, FileAccess.READ)
	if file == null:
		return _error("Could not open overlay manifest (error %s)." % FileAccess.get_open_error())
	var manifest_size := file.get_length()
	if manifest_size > MAX_MANIFEST_BYTES:
		file.close()
		return _error("Overlay manifest exceeds the size limit.")
	var manifest_bytes := file.get_buffer(manifest_size)
	var read_error := file.get_error()
	file.close()
	if manifest_bytes.size() != manifest_size or read_error != OK:
		return _error("Overlay manifest changed or was truncated while reading.")
	var json := JSON.new()
	var parse_error := json.parse(manifest_bytes.get_string_from_utf8())
	if parse_error != OK:
		return _error("Overlay manifest JSON is invalid at line %d: %s" % [json.get_error_line(), json.get_error_message()])
	if not json.data is Dictionary:
		return _error("Overlay manifest root must be an object.")
	_normalize_definition_records(json.data)
	var validated := _validate_manifest(package_root, json.data)
	if not validated.ok:
		return validated
	return {"ok": true, "manifest": json.data, "path": manifest_path, "sha256": sha256_bytes(manifest_bytes)}


## Godot's JSON parser yields every number as a float. A definition record
## carried over from a loaded manifest into the next publication would then
## be written back as `"mod_revision": 1.0`, which the Python side refuses as
## a non-integer. Whole-number revisions are folded back to int on load;
## anything else is left for `_validate_manifest` to reject.
func _normalize_definition_records(manifest: Dictionary) -> void:
	if not manifest.get("definitions", null) is Array:
		return
	for untyped_record in manifest.definitions:
		if not untyped_record is Dictionary:
			continue
		var record: Dictionary = untyped_record
		if ContractValues.json_integer(record.get("mod_revision", null)):
			record.mod_revision = int(record.mod_revision)


func stage_replacement(
	package_root: String,
	reader: KakyuArcReader,
	target_archive: String,
	target_entry: String,
	replacement_data: PackedByteArray,
	compatibility := "remake_only",
	text_encoding := "not_applicable",
	expected_base_archive_sha := ""
) -> Dictionary:
	var staged := stage_replacements(
		package_root,
		reader,
		target_archive,
		{target_entry: replacement_data},
		compatibility,
		text_encoding,
		expected_base_archive_sha
	)
	if not staged.ok:
		return staged
	var record: Dictionary = staged.records[0]
	return {
		"ok": true,
		"manifest_path": staged.manifest_path,
		"replacement_path": staged.replacement_paths[str(record.target_entry)],
		"record": record,
	}


func stage_replacements(
	package_root: String,
	reader: KakyuArcReader,
	target_archive: String,
	replacement_data_by_entry: Dictionary,
	compatibility := "remake_only",
	text_encoding := "not_applicable",
	expected_base_archive_sha := ""
) -> Dictionary:
	return _with_replacement_lock(
		package_root, reader, target_archive, replacement_data_by_entry,
		compatibility, text_encoding, false, expected_base_archive_sha
	)


func stage_replacements_from_files(
	package_root: String,
	reader: KakyuArcReader,
	target_archive: String,
	replacement_paths_by_entry: Dictionary,
	compatibility := "remake_only",
	text_encoding := "not_applicable",
	expected_base_archive_sha := ""
) -> Dictionary:
	return _with_replacement_lock(
		package_root, reader, target_archive, replacement_paths_by_entry,
		compatibility, text_encoding, true, expected_base_archive_sha
	)


func _with_replacement_lock(
	package_root: String,
	reader: KakyuArcReader,
	target_archive: String,
	replacement_sources_by_entry: Dictionary,
	compatibility: String,
	text_encoding: String,
	from_files: bool,
	expected_base_archive_sha: String = ""
) -> Dictionary:
	if package_root.is_empty():
		return _error("Overlay package root is empty.")
	var package_absolute := ProjectSettings.globalize_path(package_root).simplify_path()
	var lock := _acquire_manifest_lock(package_absolute)
	if not lock.ok:
		return lock
	var result := _stage_replacements(
		package_absolute, reader, target_archive, replacement_sources_by_entry,
		compatibility, text_encoding, from_files, expected_base_archive_sha
	)
	var release := _release_manifest_lock(lock)
	if not release.ok and result.ok:
		return release
	return result


func _stage_replacements(
	package_root: String,
	reader: KakyuArcReader,
	target_archive: String,
	replacement_sources_by_entry: Dictionary,
	compatibility: String,
	text_encoding: String,
	from_files: bool,
	expected_base_archive_sha: String = ""
) -> Dictionary:
	if package_root.is_empty():
		return _error("Overlay package root is empty.")
	if not reader.is_open():
		return _error("A source ARC must be open before staging an overlay replacement.")
	if not ArcReaderScript.is_safe_entry_name(target_archive):
		return _error("Unsafe or invalid target archive name.")
	if replacement_sources_by_entry.is_empty():
		return _error("At least one overlay replacement is required.")
	if compatibility not in COMPATIBILITY_VALUES:
		return _error("Invalid overlay compatibility value.")
	if text_encoding not in TEXT_ENCODING_VALUES:
		return _error("Invalid overlay text encoding value.")

	var package_absolute := ProjectSettings.globalize_path(package_root).simplify_path()
	var source_absolute := ProjectSettings.globalize_path(reader.archive_path).simplify_path()
	var base_archive_sha := reader.get_archive_fingerprint()
	if base_archive_sha.is_empty():
		return _error("Could not fingerprint the source ARC.")
	if not expected_base_archive_sha.is_empty() and (not ContractValues.is_sha256(expected_base_archive_sha) or base_archive_sha != expected_base_archive_sha):
		return _error("Source ARC no longer matches the workspace project binding.")

	var replacements: Array = []
	var projections: Array = []
	var definitions: Array = []
	var manifest_path := package_absolute.path_join(MANIFEST_FILENAME)
	var expected_manifest_exists := FileAccess.file_exists(manifest_path)
	var expected_manifest_sha := ""
	if expected_manifest_exists:
		var loaded := load_manifest(package_absolute)
		if not loaded.ok:
			return loaded
		expected_manifest_sha = str(loaded.sha256)
		replacements = loaded.manifest.replacements.duplicate(true)
		projections = loaded.manifest.get("projections", []).duplicate(true)
		definitions = loaded.manifest.get("definitions", []).duplicate(true)

	# Build every record and fingerprint before creating files. A bad item cannot
	# partially retarget the manifest; at worst a later I/O failure leaves an
	# unreferenced content-addressed payload behind.
	var prepared: Array[Dictionary] = []
	var seen_targets: Dictionary = {}
	for untyped_entry_name in replacement_sources_by_entry:
		if not untyped_entry_name is String and not untyped_entry_name is StringName:
			return _error("Overlay replacement keys must be ARC entry names.")
		var requested_entry_name := str(untyped_entry_name)
		var entry := reader.get_entry(requested_entry_name)
		if entry.is_empty():
			return _error("Target entry does not exist in the source ARC: %s" % requested_entry_name)
		var canonical_entry_name := str(entry.name)
		var target_key := _target_key(target_archive, canonical_entry_name)
		if seen_targets.has(target_key):
			return _error("Overlay batch targets the same entry more than once: %s" % canonical_entry_name)
		seen_targets[target_key] = true
		var untyped_source = replacement_sources_by_entry[untyped_entry_name]
		var source_descriptor: Dictionary
		if from_files:
			if not untyped_source is String and not untyped_source is StringName:
				return _error("Overlay replacement file paths must be strings: %s" % canonical_entry_name)
			var source_path := ProjectSettings.globalize_path(str(untyped_source)).simplify_path()
			if not FileAccess.file_exists(source_path):
				return _error("Overlay replacement file does not exist: %s" % canonical_entry_name)
			if source_path.to_lower() == source_absolute.to_lower():
				return _error("An overlay replacement file cannot be the source ARC: %s" % canonical_entry_name)
			var source_file := FileAccess.open(source_path, FileAccess.READ)
			if source_file == null:
				return _error("Could not open overlay replacement file: %s" % canonical_entry_name)
			var source_size := source_file.get_length()
			source_file.close()
			var source_sha := FileAccess.get_sha256(source_path)
			if source_sha.is_empty():
				return _error("Could not fingerprint overlay replacement file: %s" % canonical_entry_name)
			source_descriptor = {"kind": "file", "path": source_path, "size": source_size, "sha256": source_sha}
		else:
			if not untyped_source is PackedByteArray:
				return _error("Overlay replacement data must be PackedByteArray: %s" % canonical_entry_name)
			var replacement_data: PackedByteArray = untyped_source
			source_descriptor = {
				"kind": "bytes",
				"data": replacement_data,
				"size": replacement_data.size(),
				"sha256": sha256_bytes(replacement_data),
			}
		if int(source_descriptor.size) == 0 and int(entry.size) > 0:
			return _error("A non-empty source entry cannot be replaced with empty data: %s" % canonical_entry_name)
		var original_entry_sha := reader.get_entry_fingerprint(canonical_entry_name)
		if original_entry_sha.is_empty():
			return _error("Could not fingerprint the original ARC entry: %s" % canonical_entry_name)
		var replacement_sha := str(source_descriptor.sha256)
		if replacement_sha.is_empty():
			return _error("Could not fingerprint overlay replacement: %s" % canonical_entry_name)
		var safe_leaf := "%s-%s" % [replacement_sha, canonical_entry_name]
		var relative_path := "replacements/%s/%s" % [target_archive, safe_leaf]
		var replacement_path := package_absolute.path_join(relative_path)
		if replacement_path.to_lower() == source_absolute.to_lower():
			return _error("Overlay replacement cannot overwrite the source ARC.")
		var replacement_record := {
			"base_archive_sha256": base_archive_sha,
			"original_entry_sha256": original_entry_sha,
			"replacement_sha256": replacement_sha,
			"target_archive": target_archive,
			"target_entry": canonical_entry_name,
			"replacement_path": relative_path,
			"compatibility": compatibility,
			"text_encoding": text_encoding,
		}
		prepared.append({
			"source": source_descriptor,
			"path": replacement_path,
			"record": replacement_record,
		})

	for prepared_item in prepared:
		var replacement_record: Dictionary = prepared_item.record
		var replaced_existing := false
		for index in range(replacements.size()):
			var candidate: Dictionary = replacements[index]
			if _target_key(candidate.target_archive, candidate.target_entry) == _target_key(target_archive, replacement_record.target_entry):
				replacements[index] = replacement_record
				replaced_existing = true
				break
		if not replaced_existing:
			replacements.append(replacement_record)

	var manifest := {
		"schema": ContentCoreVersionScript.OVERLAY_SCHEMA,
		"editor_version": ContentCoreVersionScript.CORE_VERSION,
		"replacements": replacements,
		"projections": projections,
		"definitions": definitions,
	}
	var replacement_paths: Dictionary = {}
	var records: Array[Dictionary] = []
	for prepared_item in prepared:
		var replacement_path := str(prepared_item.path)
		var replacement_record: Dictionary = prepared_item.record
		var directory_error := DirAccess.make_dir_recursive_absolute(replacement_path.get_base_dir())
		if directory_error != OK:
			return _error("Could not create overlay replacement directory (error %s)." % directory_error)
		if not FileAccess.file_exists(replacement_path):
			var source_descriptor: Dictionary = prepared_item.source
			var payload_result := (
				_copy_new_file(replacement_path, source_descriptor)
				if source_descriptor.kind == "file"
				else _write_new_file(replacement_path, source_descriptor.data)
			)
			if not payload_result.ok:
				return payload_result
		if FileAccess.get_sha256(replacement_path) != str(replacement_record.replacement_sha256):
			return _error("Overlay replacement verification failed: %s" % replacement_record.target_entry)
		replacement_paths[str(replacement_record.target_entry)] = replacement_path
		records.append(replacement_record)

	var manifest_validation := _validate_manifest(package_absolute, manifest)
	if not manifest_validation.ok:
		return _error("Generated overlay manifest failed validation: %s" % manifest_validation.error)
	var manifest_result := _write_manifest_atomic(manifest_path, manifest, expected_manifest_exists, expected_manifest_sha)
	if not manifest_result.ok:
		return manifest_result
	var loaded_result := load_manifest(package_absolute)
	if not loaded_result.ok:
		return _error("Published overlay failed validation: %s" % loaded_result.error)
	if str(loaded_result.sha256) != str(manifest_result.sha256):
		return _error("Overlay manifest changed immediately after publication; reload the package before continuing.")
	return {
		"ok": true,
		"manifest_path": manifest_path,
		"replacement_paths": replacement_paths,
		"records": records,
	}


func stage_mes_text_projection(
	package_root: String,
	reader: KakyuArcReader,
	target_archive: String,
	target_entry: String,
	edits: Array[Dictionary],
	expected_base_archive_sha := ""
) -> Dictionary:
	var staged := stage_mes_text_projections(
		package_root,
		reader,
		target_archive,
		{target_entry: edits},
		expected_base_archive_sha
	)
	if not staged.ok:
		return staged
	var record: Dictionary = staged.records[0]
	return {
		"ok": true,
		"manifest_path": staged.manifest_path,
		"projection_path": staged.projection_paths[str(record.target_entry)],
		"record": record,
	}


func stage_mes_utf8_overlay_plan(
	package_root: String,
	reader: KakyuArcReader,
	plan: Dictionary
) -> Dictionary:
	var validated := MesUtf8OverlayPlanScript.new().validate(plan)
	if not validated.ok:
		return validated
	var projection: Dictionary = validated.projection_document
	if reader.get_archive_fingerprint() != str(projection.base_archive_sha256):
		return _error("MES UTF-8 overlay plan base ARC SHA-256 does not match.")
	if reader.get_entry_fingerprint(str(projection.target_entry)) != str(projection.entry_sha256):
		return _error("MES UTF-8 overlay plan entry SHA-256 does not match.")
	var edits: Array[Dictionary] = []
	for untyped_edit in projection.edits:
		edits.append((untyped_edit as Dictionary).duplicate(true))
	return stage_mes_text_projection(
		package_root,
		reader,
		str(projection.target_archive),
		str(projection.target_entry),
		edits,
		str(projection.base_archive_sha256)
	)


func stage_mes_text_projections(
	package_root: String,
	reader: KakyuArcReader,
	target_archive: String,
	edits_by_entry: Dictionary,
	expected_base_archive_sha := ""
) -> Dictionary:
	if package_root.is_empty():
		return _error("Overlay package root is empty.")
	var package_absolute := ProjectSettings.globalize_path(package_root).simplify_path()
	var lock := _acquire_manifest_lock(package_absolute)
	if not lock.ok:
		return lock
	var result := _stage_mes_text_projections(package_absolute, reader, target_archive, edits_by_entry, expected_base_archive_sha)
	var release := _release_manifest_lock(lock)
	if not release.ok and result.ok:
		return release
	return result


func _stage_mes_text_projections(
	package_root: String,
	reader: KakyuArcReader,
	target_archive: String,
	edits_by_entry: Dictionary,
	expected_base_archive_sha: String = ""
) -> Dictionary:
	if not reader.is_open():
		return _error("A source ARC must be open before staging MES text projections.")
	if not ArcReaderScript.is_safe_entry_name(target_archive):
		return _error("Unsafe or invalid target archive name.")
	if edits_by_entry.is_empty():
		return _error("At least one MES text projection is required.")
	var base_archive_sha := reader.get_archive_fingerprint()
	if base_archive_sha.is_empty():
		return _error("Could not fingerprint the source ARC.")
	if not expected_base_archive_sha.is_empty() and (not ContractValues.is_sha256(expected_base_archive_sha) or base_archive_sha != expected_base_archive_sha):
		return _error("Source ARC no longer matches the workspace project binding.")
	var package_absolute := ProjectSettings.globalize_path(package_root).simplify_path()
	var manifest_path := package_absolute.path_join(MANIFEST_FILENAME)
	var replacements: Array = []
	var projections: Array = []
	var definitions: Array = []
	var expected_manifest_exists := FileAccess.file_exists(manifest_path)
	var expected_manifest_sha := ""
	if expected_manifest_exists:
		var loaded := load_manifest(package_absolute)
		if not loaded.ok:
			return loaded
		expected_manifest_sha = str(loaded.sha256)
		replacements = loaded.manifest.replacements.duplicate(true)
		projections = loaded.manifest.get("projections", []).duplicate(true)
		definitions = loaded.manifest.get("definitions", []).duplicate(true)

	# Validate and encode the entire batch before creating any payload file. A
	# bad entry therefore cannot partially publish or retarget the manifest.
	var prepared: Array[Dictionary] = []
	var seen_targets: Dictionary = {}
	for untyped_entry_name in edits_by_entry:
		if not untyped_entry_name is String and not untyped_entry_name is StringName:
			return _error("MES text projection keys must be ARC entry names.")
		var untyped_edits = edits_by_entry[untyped_entry_name]
		if not untyped_edits is Array:
			return _error("MES text projection edits must be arrays: %s" % str(untyped_entry_name))
		var prepared_result := _prepare_mes_text_projection(
			reader,
			target_archive,
			str(untyped_entry_name),
			untyped_edits,
			base_archive_sha,
			package_absolute
		)
		if not prepared_result.ok:
			return prepared_result
		var prepared_item: Dictionary = prepared_result.item
		var record: Dictionary = prepared_item.record
		var target_key := _target_key(target_archive, str(record.target_entry))
		if seen_targets.has(target_key):
			return _error("MES text projection batch targets the same entry more than once: %s" % record.target_entry)
		seen_targets[target_key] = true
		prepared.append(prepared_item)

	for prepared_item in prepared:
		var projection_record: Dictionary = prepared_item.record
		var target_key := _target_key(target_archive, str(projection_record.target_entry))
		var replaced_existing := false
		for index in range(projections.size()):
			var candidate: Dictionary = projections[index]
			if str(candidate.get("kind", "")) == "mes_text" and _target_key(str(candidate.target_archive), str(candidate.target_entry)) == target_key:
				projections[index] = projection_record
				replaced_existing = true
				break
		if not replaced_existing:
			projections.append(projection_record)
	var manifest := {
		"schema": ContentCoreVersionScript.OVERLAY_SCHEMA,
		"editor_version": ContentCoreVersionScript.CORE_VERSION,
		"replacements": replacements,
		"projections": projections,
		"definitions": definitions,
	}
	var projection_paths: Dictionary = {}
	var records: Array[Dictionary] = []
	for prepared_item in prepared:
		var projection_path := str(prepared_item.path)
		var projection_record: Dictionary = prepared_item.record
		var directory_error := DirAccess.make_dir_recursive_absolute(projection_path.get_base_dir())
		if directory_error != OK:
			return _error("Could not create MES projection directory (error %s)." % directory_error)
		if not FileAccess.file_exists(projection_path):
			var payload_result := _write_new_file(projection_path, prepared_item.bytes)
			if not payload_result.ok:
				return payload_result
		if FileAccess.get_sha256(projection_path) != str(projection_record.projection_sha256):
			return _error("MES text projection verification failed: %s" % projection_record.target_entry)
		projection_paths[str(projection_record.target_entry)] = projection_path
		records.append(projection_record)
	var validation := _validate_manifest(package_absolute, manifest)
	if not validation.ok:
		return _error("Generated overlay manifest failed validation: %s" % validation.error)
	var manifest_result := _write_manifest_atomic(manifest_path, manifest, expected_manifest_exists, expected_manifest_sha)
	if not manifest_result.ok:
		return manifest_result
	var loaded_result := load_manifest(package_absolute)
	if not loaded_result.ok:
		return _error("Published overlay failed validation: %s" % loaded_result.error)
	if str(loaded_result.sha256) != str(manifest_result.sha256):
		return _error("Overlay manifest changed immediately after publication; reload the package before continuing.")
	return {
		"ok": true,
		"manifest_path": manifest_path,
		"projection_paths": projection_paths,
		"records": records,
	}


func _prepare_mes_text_projection(
	reader: KakyuArcReader,
	target_archive: String,
	target_entry: String,
	edits: Array,
	base_archive_sha: String,
	package_absolute: String
) -> Dictionary:
	if edits.is_empty():
		return _error("At least one MES text edit is required: %s" % target_entry)
	var entry := reader.get_entry(target_entry)
	if entry.is_empty():
		return _error("Target entry does not exist in the source ARC: %s" % target_entry)
	var canonical_entry_name := str(entry.name)
	if canonical_entry_name.get_extension().to_lower() not in ["mes", "lib"]:
		return _error("MES text projections require a MES or LIB target entry.")
	var original_entry_sha := reader.get_entry_fingerprint(canonical_entry_name)
	if original_entry_sha.is_empty():
		return _error("Could not fingerprint the source MES entry: %s" % canonical_entry_name)
	var source_bytes := reader.read_entry(canonical_entry_name)
	if source_bytes.size() != int(entry.size):
		return _error("Could not read the complete source MES entry: %s" % canonical_entry_name)
	var document := MesContainerScript.new().parse(source_bytes, {
		"archive": target_archive,
		"entry": canonical_entry_name,
		"archive_offset": entry.offset,
		"size": entry.size,
	})
	if not document.get("ok", false):
		return _error("MES text projection source could not be parsed: %s" % document.get("error", "unknown error"))
	var analysis := MesAnalysisScript.new().build(document)
	if not analysis.get("ok", false):
		return _error("MES text projection source could not be analyzed: %s" % analysis.get("error", "unknown error"))
	var source_messages: Dictionary = {}
	for untyped_message in analysis.get("messages", []):
		var message: Dictionary = untyped_message
		source_messages[int(message.source_offset)] = message
	var cp932 := Cp932CodecScript.new()
	var normalized_edits: Array[Dictionary] = []
	var seen_offsets: Dictionary = {}
	for untyped_edit in edits:
		if not untyped_edit is Dictionary:
			return _error("MES text edits must be objects.")
		var edit: Dictionary = untyped_edit
		var source_offset := int(edit.get("source_offset", -1))
		var text_value = edit.get("text")
		var raw_sha := str(edit.get("raw_sha256", ""))
		if source_offset < 0 or not text_value is String or not ContractValues.is_sha256(raw_sha):
			return _error("MES text edit has an invalid offset, text, or raw SHA-256.")
		if seen_offsets.has(source_offset):
			return _error("MES text projection contains a duplicate source offset: 0x%X" % source_offset)
		var source_message: Dictionary = source_messages.get(source_offset, {})
		if source_message.is_empty():
			return _error("MES text edit offset is not a strictly indexed message: 0x%X" % source_offset)
		if str(source_message.raw_sha256) != raw_sha:
			return _error("MES text edit raw SHA-256 does not match the source message at 0x%X." % source_offset)
		var source_decode := cp932.decode(source_message.raw_bytes)
		if not bool(source_decode.ok):
			return _error(
				"MES text edit source is native presentation data, not valid CP932 dialogue at 0x%X: %s"
				% [source_offset, str(source_decode.get("error", "invalid sequence"))]
			)
		seen_offsets[source_offset] = true
		normalized_edits.append({
			"source_offset": source_offset,
			"raw_sha256": raw_sha,
			"text": text_value,
		})
	normalized_edits.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return int(left.source_offset) < int(right.source_offset)
	)
	var projection_document := {
		"schema": ContentCoreVersionScript.MES_TEXT_OVERLAY_ENTRY_SCHEMA,
		"base_archive_sha256": base_archive_sha,
		"entry_sha256": original_entry_sha,
		"target_archive": target_archive,
		"target_entry": canonical_entry_name,
		"edits": normalized_edits,
	}
	var projection_bytes := (JSON.stringify(projection_document, "  ") + "\n").to_utf8_buffer()
	var projection_sha := sha256_bytes(projection_bytes)
	if projection_sha.is_empty():
		return _error("Could not fingerprint the MES text projection.")
	var relative_path := "projections/mes/%s-%s.json" % [projection_sha, canonical_entry_name]
	var projection_record := {
		"kind": "mes_text",
		"schema": ContentCoreVersionScript.MES_TEXT_OVERLAY_ENTRY_SCHEMA,
		"base_archive_sha256": base_archive_sha,
		"original_entry_sha256": original_entry_sha,
		"projection_sha256": projection_sha,
		"target_archive": target_archive,
		"target_entry": canonical_entry_name,
		"projection_path": relative_path,
		"compatibility": "remake_only",
		"text_encoding": "utf8",
	}
	return {
		"ok": true,
		"item": {
			"bytes": projection_bytes,
			"path": package_absolute.path_join(relative_path),
			"record": projection_record,
		},
	}


func find_replacement(manifest: Dictionary, archive_name: String, entry_name: String) -> Dictionary:
	var wanted := _target_key(archive_name, entry_name)
	for untyped_record in manifest.get("replacements", []):
		var record: Dictionary = untyped_record
		if _target_key(str(record.target_archive), str(record.target_entry)) == wanted:
			return record.duplicate(true)
	return {}


func find_mes_text_projection(manifest: Dictionary, archive_name: String, entry_name: String) -> Dictionary:
	var wanted := _target_key(archive_name, entry_name)
	for untyped_record in manifest.get("projections", []):
		var record: Dictionary = untyped_record
		if str(record.get("kind", "")) == "mes_text" and _target_key(str(record.target_archive), str(record.target_entry)) == wanted:
			return record.duplicate(true)
	return {}


func load_mes_text_projection(
	package_root: String,
	archive_name: String,
	entry_name: String,
	base_archive_sha256: String,
	entry_sha256: String
) -> Dictionary:
	if not ContractValues.is_sha256(base_archive_sha256) or not ContractValues.is_sha256(entry_sha256):
		return _error("MES text projection source hashes are invalid.")
	var loaded := load_manifest(package_root)
	if not loaded.ok:
		return loaded
	var record := find_mes_text_projection(loaded.manifest, archive_name, entry_name)
	if record.is_empty():
		return {
			"ok": true,
			"found": false,
			"edits": [],
			"messages": {},
		}
	if record.base_archive_sha256 != base_archive_sha256:
		return _error("MES text projection base ARC SHA-256 does not match.")
	if record.original_entry_sha256 != entry_sha256:
		return _error("MES text projection entry SHA-256 does not match.")
	var projection_path := ProjectSettings.globalize_path(package_root).simplify_path().path_join(str(record.projection_path))
	var document_result := _load_json_dictionary(projection_path)
	if not document_result.ok:
		return document_result
	var validation := _validate_mes_text_projection_document(record, document_result.value)
	if not validation.ok:
		return validation
	var edits: Array[Dictionary] = []
	var messages: Dictionary = {}
	for untyped_edit in document_result.value.edits:
		var edit: Dictionary = untyped_edit
		var normalized := {
			"source_offset": int(edit.source_offset),
			"raw_sha256": str(edit.raw_sha256),
			"text": str(edit.text),
		}
		edits.append(normalized)
		messages[int(edit.source_offset)] = {
			"raw_sha256": str(edit.raw_sha256),
			"text": str(edit.text),
		}
	return {
		"ok": true,
		"found": true,
		"record": record,
		"path": projection_path,
		"edits": edits,
		"messages": messages,
	}


func remove_mes_text_projection(package_root: String, archive_name: String, entry_name: String) -> Dictionary:
	if package_root.is_empty():
		return _error("Overlay package root is empty.")
	var package_absolute := ProjectSettings.globalize_path(package_root).simplify_path()
	var lock := _acquire_manifest_lock(package_absolute)
	if not lock.ok:
		return lock
	var result := _remove_mes_text_projection(package_absolute, archive_name, entry_name)
	var release := _release_manifest_lock(lock)
	if not release.ok and result.ok:
		return release
	return result


func _remove_mes_text_projection(package_root: String, archive_name: String, entry_name: String) -> Dictionary:
	if not ArcReaderScript.is_safe_entry_name(archive_name) or not ArcReaderScript.is_safe_entry_name(entry_name):
		return _error("Unsafe or invalid MES text projection target.")
	var loaded := load_manifest(package_root)
	if not loaded.ok:
		return loaded
	var manifest: Dictionary = loaded.manifest.duplicate(true)
	var wanted := _target_key(archive_name, entry_name)
	var removed_record: Dictionary = {}
	for index in range(manifest.get("projections", []).size()):
		var candidate: Dictionary = manifest.projections[index]
		if str(candidate.get("kind", "")) == "mes_text" and _target_key(str(candidate.target_archive), str(candidate.target_entry)) == wanted:
			removed_record = candidate.duplicate(true)
			manifest.projections.remove_at(index)
			break
	if removed_record.is_empty():
		return {
			"ok": true,
			"removed": false,
			"manifest_path": str(loaded.path),
		}
	manifest.editor_version = ContentCoreVersionScript.CORE_VERSION
	var package_absolute := ProjectSettings.globalize_path(package_root).simplify_path()
	var validation := _validate_manifest(package_absolute, manifest)
	if not validation.ok:
		return _error("Updated overlay manifest failed validation: %s" % validation.error)
	var manifest_path := package_absolute.path_join(MANIFEST_FILENAME)
	var write_result := _write_manifest_atomic(manifest_path, manifest, true, str(loaded.sha256))
	if not write_result.ok:
		return write_result
	var reopened := load_manifest(package_absolute)
	if not reopened.ok:
		return _error("Published overlay failed validation: %s" % reopened.error)
	if str(reopened.sha256) != str(write_result.sha256):
		return _error("Overlay manifest changed immediately after publication; reload the package before continuing.")
	return {
		"ok": true,
		"removed": true,
		"manifest_path": manifest_path,
		"record": removed_record,
		"unreferenced_projection_path": package_absolute.path_join(str(removed_record.projection_path)),
	}


func stage_mod_definitions(package_root: String, documents: Array) -> Dictionary:
	if package_root.is_empty():
		return _error("Overlay package root is empty.")
	var package_absolute := ProjectSettings.globalize_path(package_root).simplify_path()
	var lock := _acquire_manifest_lock(package_absolute)
	if not lock.ok:
		return lock
	var result := _stage_mod_definitions(package_absolute, documents)
	var release := _release_manifest_lock(lock)
	if not release.ok and result.ok:
		return release
	return result


func _stage_mod_definitions(package_root: String, documents: Array) -> Dictionary:
	if documents.is_empty():
		return _error("At least one mod definition is required.")
	var package_absolute := ProjectSettings.globalize_path(package_root).simplify_path()
	var manifest_path := package_absolute.path_join(MANIFEST_FILENAME)
	var replacements: Array = []
	var projections: Array = []
	var definitions: Array = []
	var expected_manifest_exists := FileAccess.file_exists(manifest_path)
	var expected_manifest_sha := ""
	if expected_manifest_exists:
		var loaded := load_manifest(package_absolute)
		if not loaded.ok:
			return loaded
		expected_manifest_sha = str(loaded.sha256)
		replacements = loaded.manifest.get("replacements", []).duplicate(true)
		projections = loaded.manifest.get("projections", []).duplicate(true)
		definitions = loaded.manifest.get("definitions", []).duplicate(true)

	var existing_mod_id := ""
	for untyped_record in definitions:
		var existing_record: Dictionary = untyped_record
		existing_mod_id = str(existing_record.get("mod_id", ""))
		break

	# Validate and encode the entire batch before creating any payload file. A
	# bad document cannot partially publish or retarget the manifest.
	var prepared: Array[Dictionary] = []
	var seen_ids: Dictionary = {}
	var batch_mod_id := existing_mod_id
	for untyped_bytes in documents:
		if not untyped_bytes is PackedByteArray:
			return _error("Mod definition documents must be PackedByteArray.")
		var bytes: PackedByteArray = untyped_bytes
		if bytes.size() > MAX_DEFINITION_BYTES:
			return _error("Mod definition document exceeds the size limit.")
		var decoded := bytes.get_string_from_utf8()
		if decoded.to_utf8_buffer() != bytes:
			return _error("Mod definition document is not valid UTF-8.")
		var json := JSON.new()
		if json.parse(decoded) != OK or not json.data is Dictionary:
			return _error("Mod definition document is not a valid JSON object.")
		var document: Dictionary = json.data
		var built := _build_definition_record(document, bytes)
		if not built.ok:
			return built
		var record: Dictionary = built.record
		if _document_has_text_reference(document):
			return _error("Mod definition document carries a projected text reference: %s" % str(record.get("definition_id", "")))
		var definition_id := str(record.definition_id)
		if seen_ids.has(definition_id):
			return _error("Mod definition batch has a duplicate definition_id: %s" % definition_id)
		seen_ids[definition_id] = true
		var record_mod_id := str(record.mod_id)
		if batch_mod_id.is_empty():
			batch_mod_id = record_mod_id
		elif batch_mod_id != record_mod_id:
			return _error("Mod definition batch mixes mod ids: %s" % record_mod_id)
		prepared.append({"bytes": bytes, "record": record})

	for prepared_item in prepared:
		var record: Dictionary = prepared_item.record
		var replaced_existing := false
		for index in range(definitions.size()):
			var candidate: Dictionary = definitions[index]
			if str(candidate.get("definition_id", "")) == str(record.definition_id):
				definitions[index] = record
				replaced_existing = true
				break
		if not replaced_existing:
			definitions.append(record)

	var manifest := {
		"schema": ContentCoreVersionScript.OVERLAY_SCHEMA,
		"editor_version": ContentCoreVersionScript.CORE_VERSION,
		"replacements": replacements,
		"projections": projections,
		"definitions": definitions,
	}
	var definition_paths: Dictionary = {}
	var records: Array[Dictionary] = []
	for prepared_item in prepared:
		var record: Dictionary = prepared_item.record
		var definition_path := package_absolute.path_join(str(record.definition_path))
		var directory_error := DirAccess.make_dir_recursive_absolute(definition_path.get_base_dir())
		if directory_error != OK:
			return _error("Could not create mod definition directory (error %s)." % directory_error)
		if not FileAccess.file_exists(definition_path):
			var payload_result := _write_new_file(definition_path, prepared_item.bytes)
			if not payload_result.ok:
				return payload_result
		if FileAccess.get_sha256(definition_path) != str(record.definition_sha256):
			return _error("Mod definition verification failed: %s" % record.definition_id)
		definition_paths[str(record.definition_id)] = definition_path
		records.append(record)

	var validation := _validate_manifest(package_absolute, manifest)
	if not validation.ok:
		return _error("Generated overlay manifest failed validation: %s" % validation.error)
	var manifest_result := _write_manifest_atomic(manifest_path, manifest, expected_manifest_exists, expected_manifest_sha)
	if not manifest_result.ok:
		return manifest_result
	var loaded_result := load_manifest(package_absolute)
	if not loaded_result.ok:
		return _error("Published overlay failed validation: %s" % loaded_result.error)
	if str(loaded_result.sha256) != str(manifest_result.sha256):
		return _error("Overlay manifest changed immediately after publication; reload the package before continuing.")
	return {
		"ok": true,
		"manifest_path": manifest_path,
		"definition_paths": definition_paths,
		"records": records,
	}


func find_mod_definition(manifest: Dictionary, definition_id: String) -> Dictionary:
	for untyped_record in manifest.get("definitions", []):
		var record: Dictionary = untyped_record
		if str(record.get("definition_id", "")) == definition_id:
			return record.duplicate(true)
	return {}


func load_mod_definition(package_root: String, definition_id: String) -> Dictionary:
	var loaded := load_manifest(package_root)
	if not loaded.ok:
		return loaded
	var record := find_mod_definition(loaded.manifest, definition_id)
	if record.is_empty():
		return {"ok": true, "found": false}
	var package_absolute := ProjectSettings.globalize_path(package_root).simplify_path()
	var definition_path := package_absolute.path_join(str(record.definition_path))
	if not FileAccess.file_exists(definition_path):
		return _error("Mod definition file is missing: %s" % record.definition_path)
	var file := FileAccess.open(definition_path, FileAccess.READ)
	if file == null:
		return _error("Could not open mod definition file: %s" % record.definition_path)
	var size := file.get_length()
	if size > MAX_DEFINITION_BYTES:
		file.close()
		return _error("Mod definition file exceeds the size limit: %s" % record.definition_path)
	var bytes := file.get_buffer(size)
	var read_error := file.get_error()
	file.close()
	if bytes.size() != size or read_error != OK:
		return _error("Mod definition file changed or was truncated while reading.")
	if sha256_bytes(bytes) != str(record.definition_sha256):
		return _error("Mod definition file hash does not match its manifest record: %s" % record.definition_path)
	var json := JSON.new()
	if json.parse(bytes.get_string_from_utf8()) != OK or not json.data is Dictionary:
		return _error("Mod definition file is not a valid JSON object: %s" % record.definition_path)
	var document: Dictionary = json.data
	var document_validation := _validate_mod_definition_document(record, document, "Mod definition %s" % definition_id)
	if not document_validation.ok:
		return document_validation
	return {
		"ok": true,
		"found": true,
		"record": record,
		"path": definition_path,
		"bytes": bytes,
		"document": document,
	}


func remove_mod_definition(package_root: String, definition_id: String) -> Dictionary:
	if package_root.is_empty():
		return _error("Overlay package root is empty.")
	var package_absolute := ProjectSettings.globalize_path(package_root).simplify_path()
	var lock := _acquire_manifest_lock(package_absolute)
	if not lock.ok:
		return lock
	var result := _remove_mod_definition(package_absolute, definition_id)
	var release := _release_manifest_lock(lock)
	if not release.ok and result.ok:
		return release
	return result


func _remove_mod_definition(package_root: String, definition_id: String) -> Dictionary:
	var loaded := load_manifest(package_root)
	if not loaded.ok:
		return loaded
	var manifest: Dictionary = loaded.manifest.duplicate(true)
	var removed_record: Dictionary = {}
	for index in range(manifest.get("definitions", []).size()):
		var candidate: Dictionary = manifest.definitions[index]
		if str(candidate.get("definition_id", "")) == definition_id:
			removed_record = candidate.duplicate(true)
			manifest.definitions.remove_at(index)
			break
	if removed_record.is_empty():
		return {"ok": true, "removed": false, "manifest_path": str(loaded.path)}
	manifest.editor_version = ContentCoreVersionScript.CORE_VERSION
	var package_absolute := ProjectSettings.globalize_path(package_root).simplify_path()
	var validation := _validate_manifest(package_absolute, manifest)
	if not validation.ok:
		return _error("Updated overlay manifest failed validation: %s" % validation.error)
	var manifest_path := package_absolute.path_join(MANIFEST_FILENAME)
	var write_result := _write_manifest_atomic(manifest_path, manifest, true, str(loaded.sha256))
	if not write_result.ok:
		return write_result
	var reopened := load_manifest(package_absolute)
	if not reopened.ok:
		return _error("Published overlay failed validation: %s" % reopened.error)
	if str(reopened.sha256) != str(write_result.sha256):
		return _error("Overlay manifest changed immediately after publication; reload the package before continuing.")
	return {
		"ok": true,
		"removed": true,
		"manifest_path": manifest_path,
		"record": removed_record,
		"unreferenced_definition_path": package_absolute.path_join(str(removed_record.definition_path)),
	}


func _acquire_manifest_lock(package_root: String) -> Dictionary:
	var package_absolute := ProjectSettings.globalize_path(package_root).simplify_path()
	var lock: Dictionary = PublicationLockScript.new().acquire(package_absolute, MANIFEST_LOCK_DIRECTORY)
	if not lock.ok:
		return lock
	var temp_recovery := _recover_abandoned_temporary_files(package_absolute)
	if not temp_recovery.ok:
		_release_manifest_lock(lock)
		return temp_recovery
	lock["removed_temporary_files"] = int(temp_recovery.get("removed", 0))
	return lock


func _release_manifest_lock(lock: Dictionary) -> Dictionary:
	return PublicationLockScript.new().release(lock)


func _recover_abandoned_temporary_files(package_root: String) -> Dictionary:
	var removed := 0
	for root_name in ["", "replacements", "projections", "definitions"]:
		var scan_root := package_root if root_name.is_empty() else package_root.path_join(root_name)
		if DirAccess.dir_exists_absolute(scan_root):
			removed += _recover_temporary_files_below(scan_root, root_name.is_empty())
	return {"ok": true, "removed": removed}


func _recover_temporary_files_below(path: String, package_root_only: bool) -> int:
	var directory := DirAccess.open(path)
	if directory == null:
		return 0
	var removed := 0
	directory.list_dir_begin()
	var name := directory.get_next()
	while not name.is_empty():
		var child := path.path_join(name)
		if directory.current_is_dir():
			if not package_root_only and name != MANIFEST_LOCK_DIRECTORY and not name.begins_with(MANIFEST_LOCK_DIRECTORY + ".stale-"):
				removed += _recover_temporary_files_below(child, false)
		elif name.contains(".tmp-") and (not package_root_only or name.begins_with(MANIFEST_FILENAME + ".tmp-")):
			if _temporary_owner_is_gone(name, child):
				if DirAccess.remove_absolute(child) == OK:
					removed += 1
		name = directory.get_next()
	directory.list_dir_end()
	return removed


func _temporary_owner_is_gone(name: String, path: String) -> bool:
	var marker := name.find(".tmp-")
	if marker < 0:
		return false
	var suffix := name.substr(marker + 5)
	var parts := suffix.split("-", false)
	if not parts.is_empty() and str(parts[0]).is_valid_int():
		var pid := int(parts[0])
		return pid <= 0 or not ProcessLivenessScript.is_running(pid)
	var modified := int(FileAccess.get_modified_time(path))
	return modified > 0 and int(Time.get_unix_time_from_system()) - modified >= PublicationLockScript.ORPHAN_GRACE_SECONDS


static func sha256_bytes(data: PackedByteArray) -> String:
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK:
		return ""
	if context.update(data) != OK:
		return ""
	return context.finish().hex_encode()


func _validate_manifest(package_root: String, manifest: Dictionary) -> Dictionary:
	if manifest.get("schema", "") != ContentCoreVersionScript.OVERLAY_SCHEMA:
		return _error("Unsupported overlay schema: %s" % manifest.get("schema", "<missing>"))
	if not manifest.get("editor_version", null) is String or str(manifest.editor_version).is_empty():
		return _error("Overlay editor_version must be a non-empty string.")
	if not manifest.get("replacements", null) is Array:
		return _error("Overlay replacements must be an array.")
	if not manifest.get("projections", []) is Array:
		return _error("Overlay projections must be an array.")
	var targets: Dictionary = {}
	for index in range(manifest.replacements.size()):
		var untyped_record = manifest.replacements[index]
		if not untyped_record is Dictionary:
			return _error("Overlay replacement %d must be an object." % index)
		var record: Dictionary = untyped_record
		for field in [
			"base_archive_sha256", "original_entry_sha256", "replacement_sha256",
			"target_archive", "target_entry", "replacement_path", "compatibility", "text_encoding",
		]:
			if not record.get(field, null) is String or str(record.get(field, "")).is_empty():
				return _error("Overlay replacement %d has an invalid %s." % [index, field])
		for hash_field in ["base_archive_sha256", "original_entry_sha256", "replacement_sha256"]:
			if not ContractValues.is_sha256(str(record[hash_field])):
				return _error("Overlay replacement %d has an invalid %s." % [index, hash_field])
		if not ArcReaderScript.is_safe_entry_name(str(record.target_archive)):
			return _error("Overlay replacement %d has an unsafe archive name." % index)
		if not ArcReaderScript.is_safe_entry_name(str(record.target_entry)):
			return _error("Overlay replacement %d has an unsafe entry name." % index)
		if record.compatibility not in COMPATIBILITY_VALUES:
			return _error("Overlay replacement %d has invalid compatibility." % index)
		if record.text_encoding not in TEXT_ENCODING_VALUES:
			return _error("Overlay replacement %d has invalid text_encoding." % index)
		var relative_path := str(record.replacement_path)
		if not _is_safe_relative_path(relative_path):
			return _error("Overlay replacement %d has an unsafe replacement path." % index)
		var key := _target_key(str(record.target_archive), str(record.target_entry))
		if targets.has(key):
			return _error("Overlay has duplicate target: %s" % key)
		targets[key] = true
		var replacement_path := ProjectSettings.globalize_path(package_root).simplify_path().path_join(relative_path)
		if not FileAccess.file_exists(replacement_path):
			return _error("Overlay replacement file is missing: %s" % relative_path)
		if FileAccess.get_sha256(replacement_path) != str(record.replacement_sha256):
			return _error("Overlay replacement hash mismatch: %s" % relative_path)
	var projection_targets: Dictionary = {}
	for index in range(manifest.get("projections", []).size()):
		var untyped_projection = manifest.projections[index]
		if not untyped_projection is Dictionary:
			return _error("Overlay projection %d must be an object." % index)
		var projection: Dictionary = untyped_projection
		for field in [
			"kind", "schema", "base_archive_sha256", "original_entry_sha256",
			"projection_sha256", "target_archive", "target_entry", "projection_path",
			"compatibility", "text_encoding",
		]:
			if not projection.get(field, null) is String or str(projection.get(field, "")).is_empty():
				return _error("Overlay projection %d has an invalid %s." % [index, field])
		if projection.kind != "mes_text" or projection.schema != ContentCoreVersionScript.MES_TEXT_OVERLAY_ENTRY_SCHEMA:
			return _error("Overlay projection %d has an unsupported kind or schema." % index)
		for hash_field in ["base_archive_sha256", "original_entry_sha256", "projection_sha256"]:
			if not ContractValues.is_sha256(str(projection[hash_field])):
				return _error("Overlay projection %d has an invalid %s." % [index, hash_field])
		if not ArcReaderScript.is_safe_entry_name(str(projection.target_archive)) or not ArcReaderScript.is_safe_entry_name(str(projection.target_entry)):
			return _error("Overlay projection %d has an unsafe target." % index)
		if projection.compatibility != "remake_only" or projection.text_encoding != "utf8":
			return _error("Overlay MES text projection %d must be remake-only UTF-8." % index)
		var projection_relative_path := str(projection.projection_path)
		if not _is_safe_projection_path(projection_relative_path):
			return _error("Overlay projection %d has an unsafe projection path." % index)
		var projection_key := "mes_text/%s" % _target_key(str(projection.target_archive), str(projection.target_entry))
		if projection_targets.has(projection_key):
			return _error("Overlay has a duplicate projection target: %s" % projection_key)
		projection_targets[projection_key] = true
		var projection_path := ProjectSettings.globalize_path(package_root).simplify_path().path_join(projection_relative_path)
		if not FileAccess.file_exists(projection_path) or FileAccess.get_sha256(projection_path) != str(projection.projection_sha256):
			return _error("Overlay projection file is missing or changed: %s" % projection_relative_path)
		var projection_document_result := _load_json_dictionary(projection_path)
		if not projection_document_result.ok:
			return projection_document_result
		var projection_document_validation := _validate_mes_text_projection_document(projection, projection_document_result.value)
		if not projection_document_validation.ok:
			return projection_document_validation
	if not manifest.get("definitions", []) is Array:
		return _error("Overlay definitions must be an array.")
	var definition_ids: Dictionary = {}
	var definitions_mod_id := ""
	for index in range(manifest.get("definitions", []).size()):
		var untyped_definition = manifest.definitions[index]
		if not untyped_definition is Dictionary:
			return _error("Overlay definition %d must be an object." % index)
		var definition_record: Dictionary = untyped_definition
		var where := "Overlay definition %d" % index
		var header_check := _validate_definition_record_fields(definition_record, where)
		if not header_check.ok:
			return header_check
		var definition_id := str(definition_record.definition_id)
		if definition_ids.has(definition_id):
			return _error("Overlay has a duplicate definition id: %s" % definition_id)
		definition_ids[definition_id] = true
		var definition_mod_id := str(definition_record.mod_id)
		if definitions_mod_id.is_empty():
			definitions_mod_id = definition_mod_id
		elif definitions_mod_id != definition_mod_id:
			return _error("Overlay definitions do not share one mod_id.")
		var definition_relative_path := str(definition_record.definition_path)
		var definition_path := ProjectSettings.globalize_path(package_root).simplify_path().path_join(definition_relative_path)
		if not FileAccess.file_exists(definition_path):
			return _error("%s file is missing: %s" % [where, definition_relative_path])
		if FileAccess.get_sha256(definition_path) != str(definition_record.definition_sha256):
			return _error("%s file hash mismatch: %s" % [where, definition_relative_path])
		var definition_document_result := _load_json_dictionary(definition_path, MAX_DEFINITION_BYTES)
		if not definition_document_result.ok:
			return definition_document_result
		var definition_document_validation := _validate_mod_definition_document(definition_record, definition_document_result.value, where)
		if not definition_document_validation.ok:
			return definition_document_validation
	return {"ok": true}


func _validate_mes_text_projection_document(record: Dictionary, document: Dictionary) -> Dictionary:
	if document.get("schema", "") != ContentCoreVersionScript.MES_TEXT_OVERLAY_ENTRY_SCHEMA:
		return _error("Unsupported MES text projection document schema.")
	for field in ["base_archive_sha256", "entry_sha256", "target_archive", "target_entry"]:
		if not document.get(field, null) is String:
			return _error("MES text projection document has an invalid %s." % field)
	if document.base_archive_sha256 != record.base_archive_sha256 or document.entry_sha256 != record.original_entry_sha256:
		return _error("MES text projection document hash binding does not match its manifest record.")
	if document.target_archive != record.target_archive or document.target_entry != record.target_entry:
		return _error("MES text projection document target does not match its manifest record.")
	if not document.get("edits", null) is Array or document.edits.is_empty():
		return _error("MES text projection document must contain edits.")
	var offsets: Dictionary = {}
	for untyped_edit in document.edits:
		if not untyped_edit is Dictionary:
			return _error("MES text projection document contains a non-object edit.")
		var edit: Dictionary = untyped_edit
		var offset := int(edit.get("source_offset", -1))
		if offset < 0 or offsets.has(offset) or not edit.get("text", null) is String or not ContractValues.is_sha256(str(edit.get("raw_sha256", ""))):
			return _error("MES text projection document contains an invalid or duplicate edit.")
		offsets[offset] = true
	return {"ok": true}


func _load_json_dictionary(path: String, max_bytes: int = MAX_MANIFEST_BYTES) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _error("Could not open overlay projection file.")
	if file.get_length() > max_bytes:
		file.close()
		return _error("Overlay projection file exceeds the size limit.")
	var json := JSON.new()
	var parse_error := json.parse(file.get_as_text())
	file.close()
	if parse_error != OK or not json.data is Dictionary:
		return _error("Overlay projection file is not a valid JSON object.")
	return {"ok": true, "value": json.data}


func _write_new_file(path: String, data: PackedByteArray) -> Dictionary:
	var temp_path := "%s.tmp-%s-%s" % [path, OS.get_process_id(), Time.get_ticks_usec()]
	var expected_sha := sha256_bytes(data)
	if expected_sha.is_empty():
		return _error("Could not fingerprint overlay replacement data.")
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return _error("Could not create overlay temporary file (error %s)." % FileAccess.get_open_error())
	file.store_buffer(data)
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		_remove_if_present(temp_path)
		return _error("Could not write overlay replacement.")
	if FileAccess.get_sha256(temp_path) != expected_sha:
		_remove_if_present(temp_path)
		return _error("Overlay temporary replacement verification failed.")
	return _publish_content_addressed_temp(temp_path, path, expected_sha)


func _copy_new_file(path: String, descriptor: Dictionary) -> Dictionary:
	var temp_path := "%s.tmp-%s-%s" % [path, OS.get_process_id(), Time.get_ticks_usec()]
	var source := FileAccess.open(str(descriptor.path), FileAccess.READ)
	if source == null or source.get_length() != int(descriptor.size):
		if source != null:
			source.close()
		return _error("Overlay replacement file changed before streaming.")
	var output := FileAccess.open(temp_path, FileAccess.WRITE)
	if output == null:
		source.close()
		return _error("Could not create overlay temporary file (error %s)." % FileAccess.get_open_error())
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK:
		source.close()
		output.close()
		_remove_if_present(temp_path)
		return _error("Could not initialize overlay replacement verification.")
	var remaining := int(descriptor.size)
	while remaining > 0:
		var chunk_size := mini(1024 * 1024, remaining)
		var chunk := source.get_buffer(chunk_size)
		if chunk.size() != chunk_size or context.update(chunk) != OK:
			source.close()
			output.close()
			_remove_if_present(temp_path)
			return _error("Overlay replacement file read was truncated.")
		output.store_buffer(chunk)
		if output.get_error() != OK:
			source.close()
			output.close()
			_remove_if_present(temp_path)
			return _error("Could not write overlay replacement.")
		remaining -= chunk_size
	source.close()
	output.close()
	if context.finish().hex_encode() != str(descriptor.sha256) or FileAccess.get_sha256(temp_path) != str(descriptor.sha256):
		_remove_if_present(temp_path)
		return _error("Overlay replacement file changed while streaming.")
	return _publish_content_addressed_temp(temp_path, path, str(descriptor.sha256))


func _publish_content_addressed_temp(temp_path: String, path: String, expected_sha256: String) -> Dictionary:
	if not ContractValues.is_sha256(expected_sha256) or not FileAccess.file_exists(temp_path):
		_remove_if_present(temp_path)
		return _error("Overlay temporary replacement is missing or has an invalid fingerprint.")
	if FileAccess.get_sha256(temp_path) != expected_sha256:
		_remove_if_present(temp_path)
		return _error("Overlay temporary replacement verification failed.")
	if FileAccess.file_exists(path):
		var existing_sha := FileAccess.get_sha256(path)
		_remove_if_present(temp_path)
		if existing_sha == expected_sha256:
			return {"ok": true, "reused": true, "sha256": expected_sha256}
		return _error("Overlay content-addressed destination already exists with different bytes.")
	var rename_error := DirAccess.rename_absolute(temp_path, path)
	if rename_error != OK:
		# Another publisher may have won the race after the existence check. The
		# path is reusable only when it is the exact same content-addressed blob.
		var collision_sha := FileAccess.get_sha256(path) if FileAccess.file_exists(path) else ""
		_remove_if_present(temp_path)
		if collision_sha == expected_sha256:
			return {"ok": true, "reused": true, "sha256": expected_sha256}
		return _error("Could not publish overlay replacement (error %s)." % rename_error)
	if FileAccess.get_sha256(path) != expected_sha256:
		return _error("Published overlay replacement failed reopen verification.")
	return {"ok": true, "reused": false, "sha256": expected_sha256}


func _write_manifest_atomic(
	path: String,
	manifest: Dictionary,
	expected_exists: bool,
	expected_sha256: String
) -> Dictionary:
	var temp_path := "%s.tmp-%s-%s" % [path, OS.get_process_id(), Time.get_ticks_usec()]
	var manifest_bytes := (JSON.stringify(manifest, "  ") + "\n").to_utf8_buffer()
	var manifest_sha := sha256_bytes(manifest_bytes)
	if manifest_sha.is_empty():
		return _error("Could not fingerprint the generated overlay manifest.")
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return _error("Could not create overlay manifest temporary file (error %s)." % FileAccess.get_open_error())
	file.store_buffer(manifest_bytes)
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		_remove_if_present(temp_path)
		return _error("Could not write overlay manifest.")
	if FileAccess.get_sha256(temp_path) != manifest_sha:
		_remove_if_present(temp_path)
		return _error("Overlay manifest temporary-file verification failed.")
	var current_exists := FileAccess.file_exists(path)
	if current_exists != expected_exists:
		_remove_if_present(temp_path)
		return _error("Overlay manifest changed before publication; reload the package and retry.")
	if expected_exists and (expected_sha256.is_empty() or FileAccess.get_sha256(path) != expected_sha256):
		_remove_if_present(temp_path)
		return _error("Overlay manifest changed before publication; reload the package and retry.")
	var rename_error := DirAccess.rename_absolute(temp_path, path)
	if rename_error != OK:
		_remove_if_present(temp_path)
		return _error("Could not atomically publish overlay manifest (error %s)." % rename_error)
	return {"ok": true, "sha256": manifest_sha}


func _is_safe_relative_path(path: String) -> bool:
	if path.is_empty() or path.begins_with("/") or path.contains("\\") or path.contains(":"):
		return false
	var parts := path.split("/", false)
	if parts.size() < 3 or parts[0] != "replacements":
		return false
	for part in parts:
		if part.is_empty() or part == "." or part == "..":
			return false
	return true


func _is_safe_projection_path(path: String) -> bool:
	if path.is_empty() or path.begins_with("/") or path.contains("\\") or path.contains(":"):
		return false
	var parts := path.split("/", false)
	if parts.size() != 3 or parts[0] != "projections" or parts[1] != "mes":
		return false
	for part in parts:
		if part.is_empty() or part == "." or part == "..":
			return false
	return true


func _is_safe_definition_path(path: String) -> bool:
	if path.is_empty() or path.begins_with("/") or path.contains("\\") or path.contains(":"):
		return false
	var parts := path.split("/", false)
	if parts.size() != 2 or parts[0] != "definitions":
		return false
	for part in parts:
		if part.is_empty() or part == "." or part == "..":
			return false
	return true


func _build_definition_record(document: Dictionary, bytes: PackedByteArray) -> Dictionary:
	var schema_version = document.get("schema_version")
	var kind = document.get("kind")
	var mod = document.get("mod")
	if not mod is Dictionary:
		return _error("Mod definition document mod is missing or not an object.")
	var doc_id = document.get("id")
	var contract_fingerprint = document.get("contract_fingerprint")
	var cells_fingerprint = document.get("cells_fingerprint")
	var mod_id = mod.get("id")
	var mod_revision = mod.get("revision")
	var target_id := ""
	if kind == "override":
		var target = document.get("target")
		if not target is Dictionary:
			return _error("Mod definition override document target is missing or not an object.")
		target_id = str(target.get("id", "")) if target.get("id", null) is String else ""
	var definition_id := str(doc_id) if doc_id is String else ""
	var definition_sha256 := sha256_bytes(bytes)
	var record := {
		"kind": DEFINITION_KIND,
		"schema": str(schema_version) if schema_version is String else "",
		"definition_id": definition_id,
		"definition_kind": str(kind) if kind is String else "",
		"mod_id": str(mod_id) if mod_id is String else "",
		"mod_revision": (int(mod_revision) if ContractValues.json_integer(mod_revision) else mod_revision),
		"target_id": target_id,
		"definition_sha256": definition_sha256,
		"definition_path": "definitions/%s-%s.json" % [definition_sha256, definition_id],
		"contract_fingerprint": str(contract_fingerprint) if contract_fingerprint is String else "",
		"cells_fingerprint": str(cells_fingerprint) if cells_fingerprint is String else "",
		"compatibility": "remake_only",
		"text_encoding": "utf8",
	}
	var header_check := _validate_definition_record_fields(record, "Mod definition document")
	if not header_check.ok:
		return header_check
	return {"ok": true, "record": record}


func _validate_definition_record_fields(record: Dictionary, where: String) -> Dictionary:
	for field in [
		"kind", "schema", "definition_id", "definition_kind", "mod_id", "target_id",
		"definition_sha256", "definition_path", "contract_fingerprint", "cells_fingerprint",
		"compatibility", "text_encoding",
	]:
		if not record.get(field, null) is String:
			return _error("%s has an invalid %s." % [where, field])
		if field != "target_id" and str(record[field]).is_empty():
			return _error("%s has an invalid %s." % [where, field])
	if not ContractValues.json_integer(record.get("mod_revision", null)) or int(record.mod_revision) < 1:
		return _error("%s has an invalid mod_revision." % where)
	if record.kind != DEFINITION_KIND:
		return _error("%s has an unsupported kind." % where)
	if record.schema != ContentCoreVersionScript.MOD_EVENT_DEFINITION_SCHEMA:
		return _error("%s has an unsupported schema." % where)
	if record.compatibility != "remake_only":
		return _error("%s compatibility must be remake_only." % where)
	if record.text_encoding != "utf8":
		return _error("%s text_encoding must be utf8." % where)
	var definition_id_expression := RegEx.new()
	definition_id_expression.compile("^mod\\.([a-z][a-z0-9_]{1,31})\\.[a-z][a-z0-9_]{0,63}$")
	var definition_id_match := definition_id_expression.search(str(record.definition_id))
	if definition_id_match == null:
		return _error("%s has an invalid definition_id." % where)
	var mod_id_expression := RegEx.new()
	mod_id_expression.compile("^[a-z][a-z0-9_]{1,31}$")
	if mod_id_expression.search(str(record.mod_id)) == null:
		return _error("%s has an invalid mod_id." % where)
	if definition_id_match.get_string(1) != str(record.mod_id):
		return _error("%s mod_id does not match the definition id." % where)
	if record.definition_kind not in ["new_event", "override"]:
		return _error("%s has an invalid definition_kind." % where)
	if record.definition_kind == "new_event":
		if not str(record.target_id).is_empty():
			return _error("%s target_id must be empty for a new_event." % where)
	else:
		var target_id_expression := RegEx.new()
		target_id_expression.compile("^[a-z]+\\.(school|town|date|special)\\.[a-z0-9_]+\\.[a-z0-9]+\\.[1-9]$")
		if target_id_expression.search(str(record.target_id)) == null:
			return _error("%s has an invalid target_id." % where)
	for hash_field in ["definition_sha256", "contract_fingerprint", "cells_fingerprint"]:
		if not ContractValues.is_sha256(str(record[hash_field])):
			return _error("%s has an invalid %s." % [where, hash_field])
	var expected_path := "definitions/%s-%s.json" % [record.definition_sha256, record.definition_id]
	if not _is_safe_definition_path(str(record.definition_path)) or str(record.definition_path) != expected_path:
		return _error("%s has an invalid definition_path." % where)
	return {"ok": true}


func _validate_mod_definition_document(record: Dictionary, document: Dictionary, where: String) -> Dictionary:
	if not document.get("schema_version", null) is String or document.schema_version != str(record.schema):
		return _error("%s document schema_version does not match its manifest record." % where)
	if not document.get("kind", null) is String or document.kind != str(record.definition_kind):
		return _error("%s document kind does not match its manifest record." % where)
	var mod = document.get("mod")
	if not mod is Dictionary or str(mod.get("id", "")) != str(record.mod_id) or not ContractValues.json_integer(mod.get("revision", null)) or int(mod.get("revision")) != int(record.mod_revision):
		return _error("%s document mod does not match its manifest record." % where)
	if not document.get("id", null) is String or document.id != str(record.definition_id):
		return _error("%s document id does not match its manifest record." % where)
	if not document.get("contract_fingerprint", null) is String or document.contract_fingerprint != str(record.contract_fingerprint):
		return _error("%s document contract_fingerprint does not match its manifest record." % where)
	if not document.get("cells_fingerprint", null) is String or document.cells_fingerprint != str(record.cells_fingerprint):
		return _error("%s document cells_fingerprint does not match its manifest record." % where)
	if str(record.definition_kind) == "new_event":
		if document.has("target"):
			return _error("%s new_event document carries a target." % where)
	else:
		var target = document.get("target")
		if not target is Dictionary or str(target.get("id", "")) != str(record.target_id) or str(target.get("contract", "")) != "kakyu_event_definition/v4":
			return _error("%s override document target does not match its manifest record." % where)
	if _document_has_text_reference(document):
		return _error("%s carries a projected text reference." % where)
	return {"ok": true}


func _document_has_text_reference(node) -> bool:
	if node is Dictionary:
		if node.has("text_ref") or node.has("raw_sha256"):
			return true
		for value in node.values():
			if _document_has_text_reference(value):
				return true
	elif node is Array:
		for item in node:
			if _document_has_text_reference(item):
				return true
	return false


func _target_key(archive_name: String, entry_name: String) -> String:
	return "%s/%s" % [archive_name.to_upper(), entry_name.to_upper()]


func _remove_if_present(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message}
