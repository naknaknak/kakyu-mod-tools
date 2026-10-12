class_name KakyuAudioMetadataReport
extends RefCounted

## Portable, path-free, fingerprinted metadata/provenance report over a set of
## audio ARC entries (ME-06). It states what each entry's effective bytes
## are - source, size, hash, validated container/codec header fields, its
## overlay binding when one exists, and its confirmed MES reference count
## when a MES reference index is loaded - re-verified against the workspace
## files on disk as it is built. It never contains a machine path, a
## directory, `user://`, or a payload byte.

const ArcReaderScript := preload("res://content_core/arc_reader.gd")
const AudioValidatorScript := preload("res://content_core/audio_entry_validator.gd")
const MesAudioReferenceIndexScript := preload("res://content_core/mes_audio_reference_index.gd")
const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")
const FingerprintScript := preload("res://content_core/mes_payload_fingerprint.gd")
const ContractValues := preload("res://content_core/contract_values.gd")

const HEADER_READ_SIZE := 64 * 1024
const MAX_REPORT_BYTES := 4 * 1024 * 1024

const TOP_LEVEL_KEYS := {
	"schema": true, "core_version": true, "archive": true, "overlay": true,
	"mes_references": true, "entries": true, "summary": true, "payload_sha256": true,
}
const ARCHIVE_KEYS := {"name": true, "sha256": true, "bytes": true, "entries": true, "audio_entries": true}
const OVERLAY_BLOCK_KEYS := {"loaded": true, "replacements_for_archive": true}
const MES_REFERENCES_KEYS := {
	"indexed": true, "source": true, "source_sha256": true, "source_count": true,
	"reference_count": true, "bgm_count": true, "voice_count": true,
}
const ENTRY_ROW_KEYS := {
	"name": true, "source": true, "size": true, "sha256": true, "valid": true,
	"container": true, "codec": true, "channels": true, "sample_rate": true,
	"bit_depth": true, "duration_ms": true, "error": true, "overlay": true,
	"mes_reference_count": true,
}
const ENTRY_OVERLAY_KEYS := {
	"original_entry_sha256": true, "replacement_sha256": true, "compatibility": true, "text_encoding": true,
}
const SUMMARY_KEYS := {
	"entry_count": true, "original_count": true, "overlay_count": true, "pending_count": true,
	"wav_count": true, "ogg_count": true, "invalid_count": true, "total_bytes": true,
	"known_duration_ms": true, "referenced_count": true,
}
const ENTRY_SOURCE_VALUES := {"original_arc": true, "overlay": true, "pending": true}


static func build(
	reader,
	resolver,
	archive_name: String,
	entry_names: Array,
	session: Dictionary,
	reference_index: Dictionary,
	reference_source_name: String,
	reference_source_sha256: String
) -> Dictionary:
	var validated_names := _validate_entry_names(reader, entry_names)
	if not validated_names.get("ok", false):
		return validated_names
	var canonical_names: Array = validated_names.names

	var archive_sha: String = reader.get_archive_fingerprint()
	if archive_sha.is_empty():
		return _error("Could not fingerprint the open audio ARC.")
	var audio_entry_count := 0
	for entry in (reader.get_entries() as Array):
		var extension := str(entry.name).get_extension().to_lower()
		if extension == "wav" or extension == "ogg":
			audio_entry_count += 1
	var archive_block := {
		"name": archive_name,
		"sha256": archive_sha,
		"bytes": int(reader.archive_size),
		"entries": reader.get_entries().size(),
		"audio_entries": audio_entry_count,
	}

	var overlay_snapshot: Dictionary = resolver.get_overlay_snapshot()
	var replacements_for_archive := 0
	if not overlay_snapshot.is_empty():
		for untyped_record in overlay_snapshot.get("manifest", {}).get("replacements", []):
			var record: Dictionary = untyped_record
			if str(record.get("target_archive", "")).to_upper() == archive_name.to_upper():
				replacements_for_archive += 1
	var overlay_block := {
		"loaded": not overlay_snapshot.is_empty(),
		"replacements_for_archive": replacements_for_archive,
	}

	var indexed := bool(reference_index.get("ok", false))
	var audio_kind_counts: Dictionary = reference_index.get("audio_kind_counts", {}) if indexed else {}
	var mes_references_block := {
		"indexed": indexed,
		"source": reference_source_name.get_file() if indexed else "",
		"source_sha256": reference_source_sha256 if indexed else "",
		"source_count": int(reference_index.get("source_count", 0)) if indexed else 0,
		"reference_count": int(reference_index.get("reference_count", 0)) if indexed else 0,
		"bgm_count": int(audio_kind_counts.get("bgm", 0)) if indexed else 0,
		"voice_count": int(audio_kind_counts.get("voice", 0)) if indexed else 0,
	}

	var rows: Array = []
	for canonical_name in canonical_names:
		var row_result := _build_row(reader, resolver, archive_name, str(canonical_name), session, reference_index, indexed)
		if not row_result.get("ok", false):
			return row_result
		rows.append(row_result.row)

	var report := {
		"schema": ContentCoreVersionScript.AUDIO_METADATA_REPORT_SCHEMA,
		"core_version": ContentCoreVersionScript.CORE_VERSION,
		"archive": archive_block,
		"overlay": overlay_block,
		"mes_references": mes_references_block,
		"entries": rows,
		"summary": _build_summary(rows),
	}
	report["payload_sha256"] = FingerprintScript.new().fingerprint(report)
	return {"ok": true, "report": report}


static func write(report: Dictionary, output_path: String) -> Dictionary:
	var output_absolute := ProjectSettings.globalize_path(output_path).simplify_path()
	if FileAccess.file_exists(output_absolute):
		return _error("Audio metadata report output already exists; it was not replaced.")
	var fingerprinter := FingerprintScript.new()
	var bytes := (fingerprinter.canonical_document_json(report) + "\n").to_utf8_buffer()
	var expected_sha := fingerprinter.sha256_bytes(bytes)
	if expected_sha.is_empty():
		return _error("Could not fingerprint the audio metadata report.")
	var temp_path := "%s.tmp-%s-%s" % [output_absolute, OS.get_process_id(), Time.get_ticks_usec()]
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return _error("Could not create audio metadata report temporary file (error %s)." % FileAccess.get_open_error())
	file.store_buffer(bytes)
	var write_error := file.get_error()
	file.close()
	if write_error != OK or FileAccess.get_sha256(temp_path) != expected_sha:
		_remove_if_present(temp_path)
		return _error("Audio metadata report temporary file failed verification.")
	if FileAccess.file_exists(output_absolute):
		_remove_if_present(temp_path)
		return _error("Audio metadata report output already exists; it was not replaced.")
	var rename_error := DirAccess.rename_absolute(temp_path, output_absolute)
	if rename_error != OK:
		_remove_if_present(temp_path)
		return _error("Could not publish the audio metadata report (error %s)." % rename_error)
	if FileAccess.get_sha256(output_absolute) != expected_sha:
		return _error("Published audio metadata report failed reopen verification.")
	return {"ok": true, "path": output_absolute, "sha256": expected_sha, "bytes": bytes.size()}


static func read_path(path: String) -> Dictionary:
	var absolute := ProjectSettings.globalize_path(path).simplify_path()
	var file := FileAccess.open(absolute, FileAccess.READ)
	if file == null:
		return _error("Audio metadata report could not be opened (error %s)." % FileAccess.get_open_error())
	var size := file.get_length()
	if size <= 0 or size > MAX_REPORT_BYTES:
		file.close()
		return _error("Audio metadata report exceeds its bounded JSON size.")
	var bytes := file.get_buffer(size)
	var read_error := file.get_error()
	file.close()
	if bytes.size() != size or read_error != OK:
		return _error("Audio metadata report changed or was truncated while reading.")
	var parsed = JSON.parse_string(bytes.get_string_from_utf8())
	if not parsed is Dictionary:
		return _error("Audio metadata report must be a JSON object.")
	return _validate_document(parsed)


static func _validate_entry_names(reader, entry_names: Array) -> Dictionary:
	if entry_names.is_empty():
		return _error("Audio metadata report entry list is empty.")
	var seen_names: Dictionary = {}
	var canonical_names: Array[String] = []
	for untyped_name in entry_names:
		var entry_name := str(untyped_name)
		if not ArcReaderScript.is_safe_entry_name(entry_name):
			return _error("Audio metadata report entry name is unsafe or invalid: %s" % entry_name)
		var lookup_name := entry_name.to_upper()
		if seen_names.has(lookup_name):
			return _error("Audio metadata report entry list repeats an entry: %s" % entry_name)
		seen_names[lookup_name] = true
		var extension := entry_name.get_extension().to_lower()
		if extension != "wav" and extension != "ogg":
			return _error("Audio metadata report only supports WAV/OGG entries: %s" % entry_name)
		var entry: Dictionary = reader.get_entry(entry_name)
		if entry.is_empty():
			return _error("Audio metadata report entry is not in the open ARC: %s" % entry_name)
		canonical_names.append(str(entry.name))
	return {"ok": true, "names": canonical_names}


static func _build_row(reader, resolver, archive_name: String, canonical_name: String, session: Dictionary, reference_index: Dictionary, indexed: bool) -> Dictionary:
	var source := ""
	var total_size := 0
	var sha256 := ""
	var header := PackedByteArray()
	var overlay_block = null
	if session.has(canonical_name):
		source = "pending"
		var pending: Dictionary = session[canonical_name]
		var read_result := _read_file_header(str(pending.get("path", "")))
		if not read_result.get("ok", false):
			return _error("Audio metadata report pending replacement %s: %s" % [canonical_name, str(read_result.error)])
		total_size = int(read_result.size)
		header = read_result.header
		sha256 = str(read_result.sha256)
		if sha256 != str(pending.get("sha256", "")):
			return _error("Audio metadata report pending replacement changed after it was staged: %s" % canonical_name)
	else:
		var descriptor: Dictionary = resolver.resolve(archive_name, canonical_name)
		if not descriptor.get("ok", false):
			return _error("Audio metadata report could not resolve %s: %s" % [canonical_name, str(descriptor.get("error", ""))])
		var descriptor_source := str(descriptor.get("source", ""))
		if descriptor_source == "original_arc":
			source = "original_arc"
			var entry: Dictionary = reader.get_entry(canonical_name)
			if entry.is_empty():
				return _error("Audio metadata report entry is no longer in the open ARC: %s" % canonical_name)
			total_size = int(entry.size)
			header = reader.read_entry_range(int(entry.index), 0, mini(HEADER_READ_SIZE, total_size))
			if not str(reader.last_error).is_empty():
				return _error("Audio metadata report entry header could not be read: %s: %s" % [canonical_name, reader.last_error])
			sha256 = reader.get_entry_fingerprint(canonical_name)
			if sha256.is_empty():
				return _error("Audio metadata report could not fingerprint entry: %s" % canonical_name)
		elif descriptor_source == "overlay":
			source = "overlay"
			var read_result := _read_file_header(str(descriptor.get("path", "")))
			if not read_result.get("ok", false):
				return _error("Audio metadata report overlay entry %s: %s" % [canonical_name, str(read_result.error)])
			total_size = int(read_result.size)
			header = read_result.header
			sha256 = str(read_result.sha256)
			if sha256 != str(descriptor.get("sha256", "")):
				return _error("Audio metadata report overlay file changed after validation: %s" % canonical_name)
			overlay_block = {
				"original_entry_sha256": str(descriptor.get("original_entry_sha256", "")),
				"replacement_sha256": str(descriptor.get("sha256", "")),
				"compatibility": str(descriptor.get("compatibility", "")),
				"text_encoding": str(descriptor.get("text_encoding", "")),
			}
		else:
			return _error("Audio metadata report does not support the resolved source for %s: %s" % [canonical_name, descriptor_source])

	var validation := AudioValidatorScript.validate(canonical_name, header, total_size)
	var ok := bool(validation.get("ok", false))
	var mes_reference_count = null
	if indexed:
		var found := MesAudioReferenceIndexScript.new().find(reference_index, canonical_name)
		mes_reference_count = int(found.get("reference_count", 0)) if found.get("ok", false) else 0
	var row := {
		"name": canonical_name,
		"source": source,
		"size": total_size,
		"sha256": sha256,
		"valid": ok,
		"container": validation.get("container", null) if ok else null,
		"codec": validation.get("codec", null) if ok else null,
		"channels": validation.get("channels", null) if ok else null,
		"sample_rate": validation.get("sample_rate", null) if ok else null,
		"bit_depth": validation.get("bit_depth", null) if ok else null,
		"duration_ms": validation.get("duration_ms", null) if ok else null,
		"error": "" if ok else str(validation.get("error", "")),
		"overlay": overlay_block,
		"mes_reference_count": mes_reference_count,
	}
	return {"ok": true, "row": row}


static func _read_file_header(path: String) -> Dictionary:
	if path.is_empty() or not FileAccess.file_exists(path):
		return _error("file is missing")
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _error("file is unreadable")
	var total_size := file.get_length()
	var header := file.get_buffer(mini(HEADER_READ_SIZE, total_size))
	var read_error := file.get_error()
	file.close()
	if read_error != OK:
		return _error("header could not be read")
	var sha256 := FileAccess.get_sha256(path)
	if sha256.is_empty():
		return _error("file could not be fingerprinted")
	return {"ok": true, "size": total_size, "header": header, "sha256": sha256}


static func _build_summary(rows: Array) -> Dictionary:
	var summary := {
		"entry_count": rows.size(),
		"original_count": 0,
		"overlay_count": 0,
		"pending_count": 0,
		"wav_count": 0,
		"ogg_count": 0,
		"invalid_count": 0,
		"total_bytes": 0,
		"known_duration_ms": 0,
		"referenced_count": 0,
	}
	for untyped_row in rows:
		var row: Dictionary = untyped_row
		match str(row.source):
			"original_arc":
				summary.original_count += 1
			"overlay":
				summary.overlay_count += 1
			"pending":
				summary.pending_count += 1
		var extension := str(row.name).get_extension().to_lower()
		if extension == "wav":
			summary.wav_count += 1
		elif extension == "ogg":
			summary.ogg_count += 1
		if not bool(row.valid):
			summary.invalid_count += 1
		summary.total_bytes += int(row.size)
		var duration_value = row.get("duration_ms", null)
		if duration_value != null:
			summary.known_duration_ms += int(duration_value)
		var reference_value = row.get("mes_reference_count", null)
		if reference_value != null and int(reference_value) > 0:
			summary.referenced_count += 1
	return summary


static func _validate_document(report: Dictionary) -> Dictionary:
	if not ContractValues.has_exact_key_set(report, TOP_LEVEL_KEYS):
		return _error("Audio metadata report top-level contract is invalid.")
	if str(report.get("schema", "")) != ContentCoreVersionScript.AUDIO_METADATA_REPORT_SCHEMA:
		return _error("Unsupported audio metadata report schema.")
	if not report.get("core_version", null) is String or str(report.core_version).is_empty():
		return _error("Audio metadata report core version is invalid.")
	if not ContractValues.is_sha256(str(report.get("payload_sha256", ""))) or FingerprintScript.new().fingerprint(report) != str(report.payload_sha256):
		return _error("Audio metadata report fingerprint does not match its payload.")
	var archive = report.get("archive", null)
	if not archive is Dictionary or not _validate_archive_block(archive):
		return _error("Audio metadata report archive block is invalid.")
	var overlay = report.get("overlay", null)
	if not overlay is Dictionary or not _validate_overlay_block(overlay):
		return _error("Audio metadata report overlay block is invalid.")
	var mes_references = report.get("mes_references", null)
	if not mes_references is Dictionary or not _validate_mes_references_block(mes_references):
		return _error("Audio metadata report MES reference block is invalid.")
	var entries = report.get("entries", null)
	if not entries is Array or not _validate_entries(entries):
		return _error("Audio metadata report entries are invalid.")
	var summary = report.get("summary", null)
	if not summary is Dictionary or not _validate_summary_block(summary, (entries as Array).size()):
		return _error("Audio metadata report summary block is invalid.")
	return {"ok": true, "report": report.duplicate(true)}


static func _validate_archive_block(value: Dictionary) -> bool:
	if not ContractValues.has_exact_key_set(value, ARCHIVE_KEYS):
		return false
	if not value.get("name", null) is String or str(value.name).is_empty():
		return false
	if not ContractValues.is_sha256(str(value.get("sha256", ""))):
		return false
	if not _nonnegative_int(value.get("bytes", null)):
		return false
	if not _nonnegative_int(value.get("entries", null)):
		return false
	return _nonnegative_int(value.get("audio_entries", null))


static func _validate_overlay_block(value: Dictionary) -> bool:
	if not ContractValues.has_exact_key_set(value, OVERLAY_BLOCK_KEYS):
		return false
	if not value.get("loaded", null) is bool:
		return false
	return _nonnegative_int(value.get("replacements_for_archive", null))


static func _validate_mes_references_block(value: Dictionary) -> bool:
	if not ContractValues.has_exact_key_set(value, MES_REFERENCES_KEYS):
		return false
	if not value.get("indexed", null) is bool:
		return false
	if not value.get("source", null) is String:
		return false
	if not value.get("source_sha256", null) is String:
		return false
	for key in ["source_count", "reference_count", "bgm_count", "voice_count"]:
		if not _nonnegative_int(value.get(key, null)):
			return false
	return true


static func _validate_entries(rows: Array) -> bool:
	for untyped_row in rows:
		if not untyped_row is Dictionary:
			return false
		var row: Dictionary = untyped_row
		if not ContractValues.has_exact_key_set(row, ENTRY_ROW_KEYS):
			return false
		if not row.get("name", null) is String or str(row.name).is_empty():
			return false
		if not ENTRY_SOURCE_VALUES.has(str(row.get("source", ""))):
			return false
		if not _nonnegative_int(row.get("size", null)):
			return false
		if not ContractValues.is_sha256(str(row.get("sha256", ""))):
			return false
		if not row.get("valid", null) is bool:
			return false
		for key in ["container", "codec"]:
			var text_value = row.get(key, "missing")
			if text_value != null and not text_value is String:
				return false
		for key in ["channels", "sample_rate", "bit_depth", "duration_ms"]:
			var numeric_value = row.get(key, "missing")
			if numeric_value != null and not _nonnegative_int(numeric_value):
				return false
		if not row.get("error", null) is String:
			return false
		var overlay_value = row.get("overlay", "missing")
		if overlay_value != null:
			if not overlay_value is Dictionary or not ContractValues.has_exact_key_set(overlay_value, ENTRY_OVERLAY_KEYS):
				return false
			if not ContractValues.is_sha256(str(overlay_value.get("original_entry_sha256", ""))):
				return false
			if not ContractValues.is_sha256(str(overlay_value.get("replacement_sha256", ""))):
				return false
			if not overlay_value.get("compatibility", null) is String or str(overlay_value.compatibility).is_empty():
				return false
			if not overlay_value.get("text_encoding", null) is String or str(overlay_value.text_encoding).is_empty():
				return false
		var reference_value = row.get("mes_reference_count", "missing")
		if reference_value != null and not _nonnegative_int(reference_value):
			return false
	return true


static func _validate_summary_block(value: Dictionary, entry_count: int) -> bool:
	if not ContractValues.has_exact_key_set(value, SUMMARY_KEYS):
		return false
	for key in SUMMARY_KEYS.keys():
		if not _nonnegative_int(value.get(key, null)):
			return false
	return int(value.get("entry_count", -1)) == entry_count


static func _nonnegative_int(value) -> bool:
	if value is int:
		return value >= 0
	if value is float:
		return is_finite(value) and value >= 0.0 and value == floor(value)
	return false


static func _remove_if_present(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


static func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message}
