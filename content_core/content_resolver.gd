class_name KakyuContentResolver
extends RefCounted

const ArcReaderScript := preload("res://content_core/arc_reader.gd")
const ArcProvenanceScript := preload("res://content_core/arc_provenance.gd")
const OverlayPackageScript := preload("res://content_core/overlay_package.gd")
const DEFAULT_COPY_CHUNK_SIZE := 1024 * 1024
const MAX_COPY_CHUNK_SIZE := 64 * 1024 * 1024

var last_error := ""
var _archive_readers: Dictionary = {}
var _materialized_readers: Dictionary = {}
var _materialized_bindings: Dictionary = {}
var _overlay_root := ""
var _overlay_manifest: Dictionary = {}
var _overlay_package := OverlayPackageScript.new()


func register_original_archive(archive_name: String, archive_path: String) -> bool:
	last_error = ""
	if not ArcReaderScript.is_safe_entry_name(archive_name):
		return _fail("Unsafe or invalid archive name.")
	var reader := ArcReaderScript.new()
	if not reader.open(archive_path):
		return _fail(reader.last_error)
	var key := archive_name.to_upper()
	if _archive_readers.has(key):
		_archive_readers[key].close()
	_archive_readers[key] = reader
	clear_materialized_archive(archive_name)
	return true


func register_materialized_archive(archive_name: String, archive_path: String) -> bool:
	last_error = ""
	if not ArcReaderScript.is_safe_entry_name(archive_name) or archive_name.get_extension().to_lower() != "arc":
		return _fail("Unsafe or invalid materialized archive name.")
	var key := archive_name.to_upper()
	var original_reader: KakyuArcReader = _archive_readers.get(key)
	if original_reader == null:
		return _fail("Materialized ARC requires its registered original ARC: %s" % archive_name)
	var classification := ArcProvenanceScript.new().classify(archive_path, original_reader, archive_name)
	if not classification.get("ok", false) or str(classification.get("classification", "")) != "verified_original_derived":
		return _fail("Materialized ARC lineage was not verified: %s" % str(classification.get("reason", classification.get("error", "unknown provenance"))))
	var reader := ArcReaderScript.new()
	if not reader.open(archive_path):
		return _fail(reader.last_error)
	var bindings := _build_materialized_bindings(archive_name, original_reader, reader, classification)
	if not bindings.ok:
		reader.close()
		return _fail(str(bindings.error))
	if _materialized_readers.has(key):
		_materialized_readers[key].close()
	_materialized_readers[key] = reader
	_materialized_bindings[key] = bindings.snapshot
	return true


func get_materialized_snapshot(archive_name: String) -> Dictionary:
	return _materialized_bindings.get(archive_name.to_upper(), {}).duplicate(true)


func clear_materialized_archive(archive_name: String) -> void:
	var key := archive_name.to_upper()
	if _materialized_readers.has(key):
		_materialized_readers[key].close()
	_materialized_readers.erase(key)
	_materialized_bindings.erase(key)


func clear_materialized_archives() -> void:
	for reader in _materialized_readers.values():
		reader.close()
	_materialized_readers.clear()
	_materialized_bindings.clear()


func configure_overlay(package_root: String) -> bool:
	last_error = ""
	var loaded := _overlay_package.load_manifest(package_root)
	if not loaded.ok:
		return _fail(str(loaded.error))
	_overlay_root = ProjectSettings.globalize_path(package_root).simplify_path()
	_overlay_manifest = loaded.manifest
	return true


func get_overlay_snapshot() -> Dictionary:
	if _overlay_root.is_empty() or _overlay_manifest.is_empty():
		return {}
	return {
		"root": _overlay_root,
		"manifest": _overlay_manifest.duplicate(true),
	}


func validate_overlay_archive_bindings(archive_name: String) -> Dictionary:
	last_error = ""
	if not ArcReaderScript.is_safe_entry_name(archive_name):
		return _error("Unsafe or invalid archive name.")
	if _overlay_root.is_empty() or _overlay_manifest.is_empty():
		return _error("An overlay must be configured before validating archive bindings.")
	var archive_key := archive_name.to_upper()
	var reader: KakyuArcReader = _archive_readers.get(archive_key)
	if reader == null:
		return _error("Overlay archive binding has no registered original ARC: %s" % archive_name)

	var archive_sha := reader.get_archive_fingerprint()
	if archive_sha.is_empty():
		return _error("Could not fingerprint the registered original ARC: %s" % archive_name)
	var records: Array[Dictionary] = []
	var descriptors: Dictionary = {}
	for untyped_record in _overlay_manifest.get("replacements", []):
		var record: Dictionary = untyped_record
		if str(record.target_archive).to_upper() != archive_key:
			continue
		var requested_entry_name := str(record.target_entry)
		var original_entry := reader.get_entry(requested_entry_name)
		if original_entry.is_empty():
			return _error("Overlay target entry is missing from the original ARC: %s" % requested_entry_name)
		if archive_sha != str(record.base_archive_sha256):
			return _error("Overlay base ARC hash does not match: %s" % archive_name)
		var canonical_entry_name := str(original_entry.name)
		var entry_sha := reader.get_entry_fingerprint(canonical_entry_name)
		if entry_sha.is_empty():
			return _error("Could not fingerprint overlay target entry: %s" % canonical_entry_name)
		if entry_sha != str(record.original_entry_sha256):
			return _error("Overlay original entry hash does not match: %s" % canonical_entry_name)
		var descriptor := _overlay_descriptor(archive_name, canonical_entry_name, record)
		records.append(record.duplicate(true))
		descriptors[canonical_entry_name.to_upper()] = descriptor

	# Return only after every record for this archive has passed. Resolution keeps
	# its existing live ARC/entry fingerprint checks; this batch is activation
	# metadata, not a long-lived source-integrity cache.
	return {
		"ok": true,
		"root": _overlay_root,
		"archive": archive_name,
		"archive_sha256": archive_sha,
		"records": records.duplicate(true),
		"descriptors": descriptors.duplicate(true),
	}


func clear_overlay() -> void:
	_overlay_root = ""
	_overlay_manifest.clear()


func close() -> void:
	clear_materialized_archives()
	for reader in _archive_readers.values():
		reader.close()
	_archive_readers.clear()
	clear_overlay()


func resolve(archive_name: String, entry_name: String, fallback_path := "") -> Dictionary:
	last_error = ""
	if not ArcReaderScript.is_safe_entry_name(archive_name) or not ArcReaderScript.is_safe_entry_name(entry_name):
		return _error("Unsafe content identifier.")
	var reader: KakyuArcReader = _archive_readers.get(archive_name.to_upper())
	if not _overlay_manifest.is_empty():
		var overlay := _overlay_package.find_replacement(_overlay_manifest, archive_name, entry_name)
		if not overlay.is_empty():
			if reader == null:
				return _error("Overlay target has no registered original archive: %s" % archive_name)
			var original_entry := reader.get_entry(entry_name)
			if original_entry.is_empty():
				return _error("Overlay target entry is missing from the original ARC: %s" % entry_name)
			if reader.get_archive_fingerprint() != str(overlay.base_archive_sha256):
				return _error("Overlay base ARC hash does not match: %s" % archive_name)
			if reader.get_entry_fingerprint(entry_name) != str(overlay.original_entry_sha256):
				return _error("Overlay original entry hash does not match: %s" % entry_name)
			return _overlay_descriptor(archive_name, str(original_entry.name), overlay)
	var materialized: Dictionary = _materialized_bindings.get(archive_name.to_upper(), {})
	if not materialized.is_empty():
		var materialized_reader: KakyuArcReader = _materialized_readers.get(archive_name.to_upper())
		if materialized_reader == null:
			return _error("Materialized ARC reader is no longer registered: %s" % archive_name)
		var original_entry := reader.get_entry(entry_name) if reader != null else {}
		var derived_entry := materialized_reader.get_entry(entry_name)
		if original_entry.is_empty() or derived_entry.is_empty():
			return _error("Materialized ARC entry no longer matches the original index: %s" % entry_name)
		if materialized_reader.get_archive_fingerprint() != str(materialized.materialized_archive_sha256):
			return _error("Materialized ARC changed after provenance validation: %s" % archive_name)
		var canonical_entry := str(original_entry.name)
		var entry_binding: Dictionary = materialized.entries.get(canonical_entry.to_upper(), {})
		if entry_binding.is_empty() or materialized_reader.get_entry_fingerprint(str(derived_entry.name)) != str(entry_binding.sha256):
			return _error("Materialized ARC entry changed after provenance validation: %s" % canonical_entry)
		return entry_binding.duplicate(true)
	if reader != null and not reader.get_entry(entry_name).is_empty():
		return {
			"ok": true,
			"source": "original_arc",
			"archive": archive_name,
			"entry": entry_name,
		}
	if not fallback_path.is_empty() and FileAccess.file_exists(fallback_path):
		var fallback_absolute := ProjectSettings.globalize_path(fallback_path).simplify_path()
		var fallback_file := FileAccess.open(fallback_absolute, FileAccess.READ)
		if fallback_file == null:
			return _error("Fallback content is unreadable: %s" % fallback_path)
		var fallback_size := fallback_file.get_length()
		fallback_file.close()
		var fallback_sha := FileAccess.get_sha256(fallback_absolute)
		if fallback_sha.is_empty():
			return _error("Could not fingerprint fallback content: %s" % fallback_path)
		return {
			"ok": true,
			"source": "fallback",
			"path": fallback_absolute,
			"size": fallback_size,
			"sha256": fallback_sha,
			"archive": archive_name,
			"entry": entry_name,
		}
	return _error("Content was not found in overlay, materialized ARC, original ARC, or fallback.")


func read_resolved(descriptor: Dictionary) -> PackedByteArray:
	last_error = ""
	if not descriptor.get("ok", false):
		_fail("Cannot read an unresolved content descriptor.")
		return PackedByteArray()
	match descriptor.get("source", ""):
		"overlay", "fallback":
			var path := str(descriptor.get("path", ""))
			if not FileAccess.file_exists(path):
				_fail("Resolved content file no longer exists: %s" % path)
				return PackedByteArray()
			var data := FileAccess.get_file_as_bytes(path)
			if OverlayPackageScript.sha256_bytes(data) != str(descriptor.get("sha256", "")):
				_fail("Resolved %s content hash changed after validation." % str(descriptor.source))
				return PackedByteArray()
			if descriptor.has("size") and data.size() != int(descriptor.size):
				_fail("Resolved %s content size changed after validation." % str(descriptor.source))
				return PackedByteArray()
			return data
		"original_arc", "materialized_arc":
			var reader_map := _archive_readers if str(descriptor.source) == "original_arc" else _materialized_readers
			var reader: KakyuArcReader = reader_map.get(str(descriptor.archive).to_upper())
			if reader == null:
				_fail("Resolved %s is no longer registered." % str(descriptor.source).replace("_", " "))
				return PackedByteArray()
			var data := reader.read_entry(str(descriptor.entry))
			if not reader.last_error.is_empty():
				_fail(reader.last_error)
			elif str(descriptor.source) == "materialized_arc" and OverlayPackageScript.sha256_bytes(data) != str(descriptor.get("sha256", "")):
				_fail("Resolved materialized ARC entry hash changed after validation.")
				return PackedByteArray()
			return data
		_:
			_fail("Unknown resolved content source.")
			return PackedByteArray()


func extract_resolved(descriptor: Dictionary, output_path: String, chunk_size := DEFAULT_COPY_CHUNK_SIZE) -> Dictionary:
	last_error = ""
	if not descriptor.get("ok", false):
		return _error("Cannot extract an unresolved content descriptor.")
	if chunk_size <= 0 or chunk_size > MAX_COPY_CHUNK_SIZE:
		return _error("Resolved extraction chunk size is outside the safe range.")
	var output_absolute := ProjectSettings.globalize_path(output_path).simplify_path()
	if FileAccess.file_exists(output_absolute):
		return _error("Output already exists: %s" % output_path)
	match str(descriptor.get("source", "")):
		"original_arc", "materialized_arc":
			var reader_map := _archive_readers if str(descriptor.source) == "original_arc" else _materialized_readers
			var reader: KakyuArcReader = reader_map.get(str(descriptor.get("archive", "")).to_upper())
			if reader == null:
				return _error("Resolved %s is no longer registered." % str(descriptor.source).replace("_", " "))
			if str(descriptor.source) == "materialized_arc" and reader.get_entry_fingerprint(str(descriptor.entry)) != str(descriptor.get("sha256", "")):
				return _error("Resolved materialized ARC entry hash changed after validation.")
			var extracted := reader.extract_entry(str(descriptor.get("entry", "")), output_absolute)
			if not extracted.ok:
				return _error(str(extracted.error))
			if str(descriptor.source) == "materialized_arc" and str(extracted.get("sha256", "")) != str(descriptor.get("sha256", "")):
				if FileAccess.file_exists(output_absolute) and FileAccess.get_sha256(output_absolute) == str(extracted.get("sha256", "")):
					DirAccess.remove_absolute(output_absolute)
				return _error("Materialized ARC entry changed while it was being extracted.")
			return extracted
		"overlay", "fallback":
			var source_path := ProjectSettings.globalize_path(str(descriptor.get("path", ""))).simplify_path()
			if not FileAccess.file_exists(source_path):
				return _error("Resolved content file no longer exists: %s" % source_path)
			var expected_sha := str(descriptor.get("sha256", ""))
			var expected_size := int(descriptor.get("size", -1))
			if expected_sha.is_empty() or FileAccess.get_sha256(source_path) != expected_sha:
				return _error("Resolved %s content hash changed after validation." % str(descriptor.source))
			if expected_size >= 0:
				var source_check := FileAccess.open(source_path, FileAccess.READ)
				if source_check == null or source_check.get_length() != expected_size:
					if source_check != null:
						source_check.close()
					return _error("Resolved %s content size changed after validation." % str(descriptor.source))
				source_check.close()
			var copied := _copy_file_to_new_path(source_path, output_absolute, chunk_size, expected_sha, expected_size)
			if not copied.ok:
				return copied
			return copied
		_:
			return _error("Unknown resolved content source.")


func _copy_file_to_new_path(
	source_path: String,
	output_path: String,
	chunk_size: int,
	expected_sha256: String,
	expected_size: int
) -> Dictionary:
	var source := FileAccess.open(source_path, FileAccess.READ)
	if source == null:
		return _error("Resolved content file is missing or unreadable.")
	var parent := output_path.get_base_dir()
	var mkdir_error := DirAccess.make_dir_recursive_absolute(parent)
	if mkdir_error != OK:
		source.close()
		return _error("Could not create output directory (error %s)." % mkdir_error)
	var temporary := "%s.tmp-%s-%s" % [output_path, OS.get_process_id(), Time.get_ticks_usec()]
	var output := FileAccess.open(temporary, FileAccess.WRITE)
	if output == null:
		source.close()
		return _error("Could not create temporary output (error %s)." % FileAccess.get_open_error())
	var total_size := source.get_length()
	if expected_size >= 0 and total_size != expected_size:
		source.close()
		output.close()
		_remove_copy_temporary(temporary)
		return _error("Resolved content size changed after validation.")
	var streamed_context := HashingContext.new()
	if streamed_context.start(HashingContext.HASH_SHA256) != OK:
		source.close()
		output.close()
		_remove_copy_temporary(temporary)
		return _error("Could not initialize resolved extraction SHA-256.")
	var remaining := total_size
	var ok := true
	while remaining > 0:
		var read_size := mini(chunk_size, remaining)
		var chunk := source.get_buffer(read_size)
		if chunk.size() != read_size:
			ok = false
			break
		output.store_buffer(chunk)
		if output.get_error() != OK or streamed_context.update(chunk) != OK:
			ok = false
			break
		remaining -= chunk.size()
	source.close()
	var write_error := output.get_error()
	output.close()
	if not ok or remaining != 0 or write_error != OK:
		_remove_copy_temporary(temporary)
		return _error("Resolved content could not be copied completely.")
	var streamed_sha := streamed_context.finish().hex_encode()
	if not expected_sha256.is_empty() and streamed_sha != expected_sha256:
		_remove_copy_temporary(temporary)
		return _error("Resolved content changed while it was being extracted.")
	var reopened := FileAccess.open(temporary, FileAccess.READ)
	if reopened == null:
		_remove_copy_temporary(temporary)
		return _error("Could not reopen temporary resolved extraction output.")
	var reopened_size := reopened.get_length()
	reopened.close()
	var reopened_sha := FileAccess.get_sha256(temporary)
	if reopened_size != total_size or reopened_sha.is_empty() or reopened_sha != streamed_sha:
		_remove_copy_temporary(temporary)
		return _error("Temporary resolved extraction failed size/SHA-256 verification.")
	if FileAccess.file_exists(output_path):
		_remove_copy_temporary(temporary)
		return _error("Output appeared before resolved extraction could be published: %s" % output_path)
	var rename_error := DirAccess.rename_absolute(temporary, output_path)
	if rename_error != OK:
		_remove_copy_temporary(temporary)
		return _error("Could not atomically publish resolved extraction (error %s)." % rename_error)
	return {"ok": true, "bytes": total_size, "path": output_path, "sha256": reopened_sha}


func _remove_copy_temporary(path: String) -> void:
	if not path.is_empty() and FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func _overlay_descriptor(archive_name: String, entry_name: String, record: Dictionary) -> Dictionary:
	return {
		"ok": true,
		"source": "overlay",
		"path": _overlay_root.path_join(str(record.replacement_path)).simplify_path(),
		"sha256": str(record.replacement_sha256),
		"archive": archive_name,
		"entry": entry_name,
		"base_archive_sha256": str(record.base_archive_sha256),
		"original_entry_sha256": str(record.original_entry_sha256),
		"compatibility": str(record.compatibility),
		"text_encoding": str(record.text_encoding),
	}


func _build_materialized_bindings(archive_name: String, original_reader, derived_reader, classification: Dictionary) -> Dictionary:
	var provenance: Dictionary = classification.get("provenance", {})
	if (
		original_reader.get_archive_fingerprint() != str(provenance.get("source", {}).get("sha256", ""))
		or derived_reader.get_archive_fingerprint() != str(classification.get("sha256", ""))
	):
		return _error("Original or materialized ARC changed while lineage was being activated.")
	var replacement_by_entry := {}
	for value in provenance.get("replacements", []):
		var record: Dictionary = value
		replacement_by_entry[str(record.entry).to_upper()] = record
	var entries := {}
	for original_entry in original_reader.get_entries():
		var canonical_entry := str(original_entry.name)
		var derived_entry: Dictionary = derived_reader.get_entry(canonical_entry)
		if derived_entry.is_empty():
			return _error("Materialized ARC entry is missing: %s" % canonical_entry)
		var original_sha: String = original_reader.get_entry_fingerprint(canonical_entry)
		var effective_sha: String = derived_reader.get_entry_fingerprint(str(derived_entry.name))
		if original_sha.is_empty() or effective_sha.is_empty():
			return _error("Materialized ARC entry could not be fingerprinted: %s" % canonical_entry)
		var replacement: Dictionary = replacement_by_entry.get(canonical_entry.to_upper(), {})
		var compatibility := "original_engine_compatible" if replacement.is_empty() else str(provenance.declared_compatibility)
		entries[canonical_entry.to_upper()] = {
			"ok": true,
			"source": "materialized_arc",
			"archive": archive_name,
			"entry": canonical_entry,
			"sha256": effective_sha,
			"size": int(derived_entry.size),
			"compatibility": compatibility,
			"lineage_classification": "verified_original_derived",
			"source_archive_sha256": str(provenance.source.sha256),
			"original_entry_sha256": original_sha,
			"materialized_archive_sha256": str(classification.sha256),
		}
	return {
		"ok": true,
		"snapshot": {
			"archive": archive_name,
			"classification": "verified_original_derived",
			"source_archive_sha256": str(provenance.source.sha256),
			"materialized_archive_sha256": str(classification.sha256),
			"compatibility": str(provenance.declared_compatibility),
			"replacement_count": int(classification.replacement_count),
			"entries": entries,
		},
	}


func _fail(message: String) -> bool:
	last_error = message
	return false


func _error(message: String) -> Dictionary:
	last_error = message
	return {"ok": false, "error": message}
