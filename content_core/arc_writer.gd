class_name KakyuArcWriter
extends RefCounted

const ArcReaderScript := preload("res://content_core/arc_reader.gd")
const COPY_CHUNK_SIZE := 1024 * 1024
const UINT32_MAX := 0xFFFFFFFF
const NAME_SIZE := 256
const SIZE_KEY := 0xF97FD0EC
const OFFSET_KEY := 0xA2C947FC


func write_copy(source_path: String, output_path: String, replacements := {}) -> Dictionary:
	return _write(source_path, output_path, replacements, false, false, "")


func write_repacked_copy(source_path: String, output_path: String, replacements := {}) -> Dictionary:
	return _write(source_path, output_path, replacements, true, false, "")


func write_copy_from_files(source_path: String, output_path: String, replacement_paths := {}) -> Dictionary:
	return _write(source_path, output_path, replacement_paths, false, true, "")


func write_repacked_copy_from_files(source_path: String, output_path: String, replacement_paths := {}) -> Dictionary:
	return _write(source_path, output_path, replacement_paths, true, true, "")


func write_copy_if_source_matches(
	source_path: String,
	output_path: String,
	expected_source_sha256: String,
	replacements := {}
) -> Dictionary:
	return _write(source_path, output_path, replacements, false, false, expected_source_sha256)


func write_repacked_copy_if_source_matches(
	source_path: String,
	output_path: String,
	expected_source_sha256: String,
	replacements := {}
) -> Dictionary:
	return _write(source_path, output_path, replacements, true, false, expected_source_sha256)


func write_copy_from_files_if_source_matches(
	source_path: String,
	output_path: String,
	expected_source_sha256: String,
	replacement_paths := {}
) -> Dictionary:
	return _write(source_path, output_path, replacement_paths, false, true, expected_source_sha256)


func write_repacked_copy_from_files_if_source_matches(
	source_path: String,
	output_path: String,
	expected_source_sha256: String,
	replacement_paths := {}
) -> Dictionary:
	return _write(source_path, output_path, replacement_paths, true, true, expected_source_sha256)


func write_repacked_copy_from_bound_files(
	source_path: String,
	output_path: String,
	expected_source_sha256: String,
	replacement_files := {}
) -> Dictionary:
	var replacement_paths: Dictionary = {}
	var replacement_sha256: Dictionary = {}
	for untyped_name in replacement_files:
		var descriptor = replacement_files[untyped_name]
		if not descriptor is Dictionary:
			return _error("Bound replacement descriptors must be dictionaries: %s" % str(untyped_name))
		var path := str(descriptor.get("path", ""))
		var sha256 := str(descriptor.get("sha256", "")).strip_edges().to_lower()
		if path.is_empty() or sha256.length() != 64 or not sha256.is_valid_hex_number(false):
			return _error("Bound replacement requires a path and SHA-256: %s" % str(untyped_name))
		replacement_paths[untyped_name] = path
		replacement_sha256[untyped_name] = sha256
	return _write(
		source_path,
		output_path,
		replacement_paths,
		true,
		true,
		expected_source_sha256,
		replacement_sha256
	)


func validate_repack_source(reader: KakyuArcReader) -> Dictionary:
	if reader == null or not reader.is_open():
		return _error("ARC reader must be open before validating a repack source.")
	return _validate_canonical_layout(reader)


func _write(
	source_path: String,
	output_path: String,
	replacements: Dictionary,
	allow_resize: bool,
	from_files: bool,
	expected_source_sha256: String,
	expected_replacement_sha256 := {}
) -> Dictionary:
	var source_absolute := ProjectSettings.globalize_path(source_path).simplify_path()
	var output_absolute := ProjectSettings.globalize_path(output_path).simplify_path()
	if source_absolute.to_lower() == output_absolute.to_lower():
		return _error("Source ARC overwrite is forbidden.")
	if FileAccess.file_exists(output_absolute):
		return _error("Output already exists; choose a new ARC copy path.")

	var reader := ArcReaderScript.new()
	if not reader.open(source_absolute):
		return _error(reader.last_error)
	var normalized_expected_sha256 := expected_source_sha256.strip_edges().to_lower()
	if not normalized_expected_sha256.is_empty():
		if normalized_expected_sha256.length() != 64 or not normalized_expected_sha256.is_valid_hex_number(false):
			reader.close()
			return _error("Expected source ARC SHA-256 must be 64 lowercase or uppercase hexadecimal characters.")
		var opened_source_sha256 := reader.get_archive_fingerprint()
		if opened_source_sha256 != normalized_expected_sha256:
			reader.close()
			return _error("Source ARC changed after it was opened by the tool; reopen it before exporting a new ARC copy.")
	var checked_replacements := _validate_replacements(
		reader,
		replacements,
		allow_resize,
		from_files,
		source_absolute,
		expected_replacement_sha256
	)
	if not checked_replacements.ok:
		reader.close()
		return checked_replacements
	var normalized_replacements: Dictionary = checked_replacements.replacements
	var resized_count := int(checked_replacements.resized_count)
	var output_layout := "preserved_source_layout"
	if _validate_canonical_layout(reader).ok:
		output_layout = "canonical_contiguous"

	var parent := output_absolute.get_base_dir()
	var mkdir_error := DirAccess.make_dir_recursive_absolute(parent)
	if mkdir_error != OK:
		reader.close()
		return _error("Could not create output directory (error %s)." % mkdir_error)
	var temp_path := "%s.tmp-%s-%s" % [output_absolute, OS.get_process_id(), Time.get_ticks_usec()]
	var copied: Dictionary
	if resized_count > 0:
		copied = _write_repacked_file(source_absolute, temp_path, reader, normalized_replacements)
	else:
		copied = _copy_file(source_absolute, temp_path)
	if not copied.ok:
		reader.close()
		_remove_if_present(temp_path)
		return copied

	if resized_count == 0 and not normalized_replacements.is_empty():
		var patched := _patch_equal_size_entries(temp_path, reader, normalized_replacements)
		if not patched.ok:
			reader.close()
			_remove_if_present(temp_path)
			return patched

	var verified := _verify_copy(reader, temp_path, normalized_replacements, resized_count > 0)
	var replacement_bindings: Array[Dictionary] = []
	if verified.ok:
		for entry in reader.get_entries():
			var entry_name := str(entry.name)
			if not normalized_replacements.has(entry_name):
				continue
			var replacement: Dictionary = normalized_replacements[entry_name]
			replacement_bindings.append({
				"entry": entry_name,
				"original_entry_sha256": reader.get_entry_fingerprint(entry_name),
				"replacement_sha256": str(replacement.sha256),
				"original_size": int(entry.size),
				"replacement_size": int(replacement.size),
			})
	reader.close()
	if not verified.ok:
		_remove_if_present(temp_path)
		return verified
	if (
		not normalized_expected_sha256.is_empty()
		and FileAccess.get_sha256(source_absolute) != normalized_expected_sha256
	):
		_remove_if_present(temp_path)
		return _error("Source ARC changed while the new ARC copy was being built; the temporary output was removed.")
	var published := _publish_verified_temp(temp_path, output_absolute)
	if not published.ok:
		return published
	return {
		"ok": true,
		"path": output_absolute,
		"replacement_count": normalized_replacements.size(),
		"resized_count": resized_count,
		"layout": output_layout,
		"sha256": verified.sha256,
		"replacement_bindings": replacement_bindings,
		"source_sha256": (
			normalized_expected_sha256
			if not normalized_expected_sha256.is_empty()
			else FileAccess.get_sha256(source_absolute)
		),
	}


func _publish_verified_temp(temp_path: String, output_absolute: String) -> Dictionary:
	if FileAccess.file_exists(output_absolute):
		_remove_if_present(temp_path)
		return _error("Output appeared before ARC publication; the existing file was preserved.")
	var rename_error := DirAccess.rename_absolute(temp_path, output_absolute)
	if rename_error != OK:
		_remove_if_present(temp_path)
		return _error("Could not atomically publish ARC copy (error %s)." % rename_error)
	return {"ok": true}


func _validate_replacements(
	reader: KakyuArcReader,
	replacements: Dictionary,
	allow_resize: bool,
	from_files: bool,
	source_absolute: String,
	expected_replacement_sha256: Dictionary
) -> Dictionary:
	if not from_files and not expected_replacement_sha256.is_empty():
		return _error("Bound replacement hashes require file-backed replacement paths.")
	if not replacements.is_empty():
		var entries := reader.get_entries()
		entries.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
			return int(left.offset) < int(right.offset)
		)
		for index in range(1, entries.size()):
			var previous := entries[index - 1]
			var current := entries[index]
			if int(previous.offset) + int(previous.size) > int(current.offset):
				return _error("Replacement writes are unsafe because ARC entries overlap.")
	var normalized: Dictionary = {}
	var resized_count := 0
	for untyped_name in replacements:
		if not untyped_name is String and not untyped_name is StringName:
			return _error("Replacement keys must be ARC entry names.")
		var entry_name := str(untyped_name)
		var entry := reader.get_entry(entry_name)
		if entry.is_empty():
			return _error("Replacement entry does not exist: %s" % entry_name)
		var replacement = replacements[untyped_name]
		if normalized.has(str(entry.name)):
			return _error("Replacement targets the same entry more than once: %s" % entry.name)
		var descriptor: Dictionary
		if from_files:
			if not replacement is String and not replacement is StringName:
				return _error("Replacement file paths must be strings: %s" % entry_name)
			var replacement_path := ProjectSettings.globalize_path(str(replacement)).simplify_path()
			if not FileAccess.file_exists(replacement_path):
				return _error("Replacement file does not exist: %s" % entry_name)
			if replacement_path.to_lower() == source_absolute.to_lower():
				return _error("A replacement file cannot be the source ARC: %s" % entry_name)
			var replacement_file := FileAccess.open(replacement_path, FileAccess.READ)
			if replacement_file == null:
				return _error("Could not open replacement file: %s" % entry_name)
			var replacement_size := replacement_file.get_length()
			replacement_file.close()
			var replacement_sha := FileAccess.get_sha256(replacement_path)
			if replacement_sha.is_empty():
				return _error("Could not fingerprint replacement file: %s" % entry_name)
			if expected_replacement_sha256.has(untyped_name):
				var expected_sha := str(expected_replacement_sha256[untyped_name]).to_lower()
				if replacement_sha != expected_sha:
					return _error("Replacement file no longer matches its bound SHA-256: %s" % entry_name)
			descriptor = {"kind": "file", "path": replacement_path, "size": replacement_size, "sha256": replacement_sha}
		else:
			if not replacement is PackedByteArray:
				return _error("Replacement data must be PackedByteArray: %s" % entry_name)
			var replacement_data: PackedByteArray = replacement
			descriptor = {
				"kind": "bytes",
				"data": replacement_data,
				"size": replacement_data.size(),
				"sha256": _sha256_bytes(replacement_data),
			}
		var replacement_size := int(descriptor.size)
		if replacement_size > UINT32_MAX:
			return _error("Replacement exceeds the ARC u32 size limit: %s" % entry.name)
		if replacement_size != int(entry.size) and not allow_resize:
			return _error(
				"Resize rebuild is not supported: %s is %d bytes, expected %d. Use an overlay." %
					[entry_name, replacement_size, int(entry.size)]
			)
		if replacement_size != int(entry.size):
			resized_count += 1
		normalized[str(entry.name)] = descriptor
	if expected_replacement_sha256.size() != 0 and expected_replacement_sha256.size() != normalized.size():
		return _error("Every file-backed replacement must have exactly one bound SHA-256.")
	if resized_count > 0:
		var layout_check := _validate_canonical_layout(reader)
		if not layout_check.ok:
			return layout_check
	return {"ok": true, "replacements": normalized, "resized_count": resized_count}


func _validate_canonical_layout(reader: KakyuArcReader) -> Dictionary:
	var expected_offset := reader.header_size
	for entry in reader.get_entries():
		if int(entry.offset) != expected_offset:
			return _error(
				"Resize rebuild requires a canonical contiguous ARC; %s begins at %d, expected %d." %
					[entry.name, int(entry.offset), expected_offset]
			)
		expected_offset += int(entry.size)
		if expected_offset > UINT32_MAX:
			return _error("Source ARC payload exceeds the u32 offset range.")
	if expected_offset != reader.archive_size:
		return _error("Resize rebuild requires a canonical ARC with no trailing opaque bytes.")
	return {"ok": true}


func _copy_file(source_path: String, temp_path: String) -> Dictionary:
	var source := FileAccess.open(source_path, FileAccess.READ)
	if source == null:
		return _error("Could not reopen source ARC (error %s)." % FileAccess.get_open_error())
	var output := FileAccess.open(temp_path, FileAccess.WRITE)
	if output == null:
		source.close()
		return _error("Could not create temporary ARC (error %s)." % FileAccess.get_open_error())
	var remaining := source.get_length()
	while remaining > 0:
		var chunk_size := mini(COPY_CHUNK_SIZE, remaining)
		var chunk := source.get_buffer(chunk_size)
		if chunk.size() != chunk_size:
			source.close()
			output.close()
			return _error("Source ARC read was truncated.")
		output.store_buffer(chunk)
		if output.get_error() != OK:
			source.close()
			output.close()
			return _error("Temporary ARC write failed.")
		remaining -= chunk_size
	source.close()
	output.close()
	return {"ok": true}


func _write_repacked_file(
	source_path: String,
	temp_path: String,
	reader: KakyuArcReader,
	replacements: Dictionary
) -> Dictionary:
	var source := FileAccess.open(source_path, FileAccess.READ)
	if source == null:
		return _error("Could not reopen source ARC (error %s)." % FileAccess.get_open_error())
	var output := FileAccess.open(temp_path, FileAccess.WRITE)
	if output == null:
		source.close()
		return _error("Could not create temporary ARC (error %s)." % FileAccess.get_open_error())
	var header := source.get_buffer(reader.header_size)
	source.close()
	if header.size() != reader.header_size:
		output.close()
		return _error("Source ARC header read was truncated.")
	output.store_buffer(header)
	if output.get_error() != OK:
		output.close()
		return _error("Temporary ARC header write failed.")

	var entries := reader.get_entries()
	var next_offset := reader.header_size
	for entry in entries:
		var data_size := int(entry.size)
		if replacements.has(str(entry.name)):
			var replacement: Dictionary = replacements[str(entry.name)]
			data_size = int(replacement.size)
		if next_offset > UINT32_MAX or data_size > UINT32_MAX - next_offset:
			output.close()
			return _error("Repacked ARC exceeds the u32 offset/size range at %s." % entry.name)
		output.seek(4 + int(entry.index) * ArcReaderScript.ENTRY_SIZE + NAME_SIZE)
		output.store_32(data_size ^ SIZE_KEY)
		output.store_32(next_offset ^ OFFSET_KEY)
		if output.get_error() != OK:
			output.close()
			return _error("Temporary ARC index update failed at %s." % entry.name)
		next_offset += data_size

	output.seek(reader.header_size)
	for entry in entries:
		var entry_name := str(entry.name)
		if replacements.has(entry_name):
			var replacement_result := _write_replacement(output, replacements[entry_name], entry_name)
			if not replacement_result.ok:
				output.close()
				return replacement_result
			continue
		var streamed := reader.stream_entry(entry_name, func(chunk: PackedByteArray, _offset: int) -> bool:
			output.store_buffer(chunk)
			return output.get_error() == OK
		)
		if not streamed:
			output.close()
			return _error("Source ARC entry stream failed: %s" % entry_name)
	output.close()
	return {"ok": true}


func _patch_equal_size_entries(temp_path: String, reader: KakyuArcReader, replacements: Dictionary) -> Dictionary:
	var output := FileAccess.open(temp_path, FileAccess.READ_WRITE)
	if output == null:
		return _error("Could not reopen temporary ARC for patching (error %s)." % FileAccess.get_open_error())
	for untyped_name in replacements:
		var entry_name := str(untyped_name)
		var entry := reader.get_entry(entry_name)
		output.seek(int(entry.offset))
		var replacement_result := _write_replacement(output, replacements[untyped_name], entry_name)
		if not replacement_result.ok:
			output.close()
			return replacement_result
	output.close()
	return {"ok": true}


func _verify_copy(
	source: KakyuArcReader,
	temp_path: String,
	replacements: Dictionary,
	resized: bool
) -> Dictionary:
	var rebuilt := ArcReaderScript.new()
	if not rebuilt.open(temp_path):
		return _error("Rebuilt ARC failed validation: %s" % rebuilt.last_error)
	var source_entries := source.get_entries()
	var rebuilt_entries := rebuilt.get_entries()
	if source_entries.size() != rebuilt_entries.size():
		rebuilt.close()
		return _error("Rebuilt ARC entry count changed.")
	for index in range(source_entries.size()):
		var before := source_entries[index]
		var after := rebuilt_entries[index]
		if before.name != after.name:
			rebuilt.close()
			return _error("Rebuilt ARC entry order/name changed at entry %d." % index)
		var expected_size := int(before.size)
		if replacements.has(str(before.name)):
			var expected_replacement: Dictionary = replacements[str(before.name)]
			expected_size = int(expected_replacement.size)
		if int(after.size) != expected_size:
			rebuilt.close()
			return _error("Rebuilt ARC size metadata is wrong at entry %d." % index)
		if resized:
			var expected_offset := source.header_size if index == 0 else int(rebuilt_entries[index - 1].offset) + int(rebuilt_entries[index - 1].size)
			if int(after.offset) != expected_offset:
				rebuilt.close()
				return _error("Rebuilt ARC is not contiguous at entry %d." % index)
		elif before.offset != after.offset:
			rebuilt.close()
			return _error("Equal-size ARC offset metadata changed at entry %d." % index)
		if replacements.has(str(before.name)):
			if not _replacement_matches(rebuilt, after, replacements[str(before.name)]):
				rebuilt.close()
				return _error("Rebuilt ARC replacement verification failed: %s" % before.name)
		elif resized and not _entries_equal(source, rebuilt, before, after):
			rebuilt.close()
			return _error("Rebuilt ARC changed an unmodified entry: %s" % before.name)
	if not _raw_names_equal(source.archive_path, temp_path, source_entries.size()):
		rebuilt.close()
		return _error("Rebuilt ARC changed opaque entry-name bytes.")
	rebuilt.close()
	var output_sha := FileAccess.get_sha256(temp_path)
	if output_sha.is_empty():
		return _error("Could not fingerprint rebuilt ARC.")
	if replacements.is_empty() and FileAccess.get_sha256(source.archive_path) != output_sha:
		return _error("No-op ARC rebuild was not byte-identical.")
	return {"ok": true, "sha256": output_sha}


func _write_replacement(output: FileAccess, descriptor: Dictionary, entry_name: String) -> Dictionary:
	if descriptor.kind == "bytes":
		output.store_buffer(descriptor.data)
		return {"ok": true} if output.get_error() == OK else _error("Temporary ARC replacement write failed: %s" % entry_name)
	var path := str(descriptor.path)
	var source := FileAccess.open(path, FileAccess.READ)
	if source == null or source.get_length() != int(descriptor.size):
		if source != null:
			source.close()
		return _error("Replacement file changed before streaming: %s" % entry_name)
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK:
		source.close()
		return _error("Could not initialize replacement verification: %s" % entry_name)
	var remaining := int(descriptor.size)
	while remaining > 0:
		var chunk_size := mini(COPY_CHUNK_SIZE, remaining)
		var chunk := source.get_buffer(chunk_size)
		if chunk.size() != chunk_size or context.update(chunk) != OK:
			source.close()
			return _error("Replacement file read was truncated: %s" % entry_name)
		output.store_buffer(chunk)
		if output.get_error() != OK:
			source.close()
			return _error("Temporary ARC replacement write failed: %s" % entry_name)
		remaining -= chunk_size
	source.close()
	if context.finish().hex_encode() != str(descriptor.sha256):
		return _error("Replacement file changed while streaming: %s" % entry_name)
	return {"ok": true}


func _replacement_matches(rebuilt: KakyuArcReader, rebuilt_entry: Dictionary, descriptor: Dictionary) -> bool:
	if int(rebuilt_entry.size) != int(descriptor.size):
		return false
	if descriptor.kind == "bytes":
		return rebuilt.read_entry(str(rebuilt_entry.name)) == descriptor.data
	var source := FileAccess.open(str(descriptor.path), FileAccess.READ)
	if source == null or source.get_length() != int(descriptor.size):
		if source != null:
			source.close()
		return false
	var offset := 0
	var remaining := int(descriptor.size)
	while remaining > 0:
		var size := mini(COPY_CHUNK_SIZE, remaining)
		var expected := source.get_buffer(size)
		var actual := rebuilt.read_entry_range(int(rebuilt_entry.index), offset, size)
		if expected.size() != size or actual.size() != size or expected != actual:
			source.close()
			return false
		offset += size
		remaining -= size
	source.close()
	return true


func _entries_equal(
	source: KakyuArcReader,
	rebuilt: KakyuArcReader,
	source_entry: Dictionary,
	rebuilt_entry: Dictionary
) -> bool:
	if int(source_entry.size) != int(rebuilt_entry.size):
		return false
	var offset := 0
	var remaining := int(source_entry.size)
	while remaining > 0:
		var size := mini(COPY_CHUNK_SIZE, remaining)
		var before := source.read_entry_range(int(source_entry.index), offset, size)
		var after := rebuilt.read_entry_range(int(rebuilt_entry.index), offset, size)
		if before.size() != size or after.size() != size or before != after:
			return false
		offset += size
		remaining -= size
	return true


func _raw_names_equal(source_path: String, rebuilt_path: String, entry_count: int) -> bool:
	var source := FileAccess.open(source_path, FileAccess.READ)
	var rebuilt := FileAccess.open(rebuilt_path, FileAccess.READ)
	if source == null or rebuilt == null:
		if source != null:
			source.close()
		if rebuilt != null:
			rebuilt.close()
		return false
	for index in range(entry_count):
		var offset := 4 + index * ArcReaderScript.ENTRY_SIZE
		source.seek(offset)
		rebuilt.seek(offset)
		if source.get_buffer(NAME_SIZE) != rebuilt.get_buffer(NAME_SIZE):
			source.close()
			rebuilt.close()
			return false
	source.close()
	rebuilt.close()
	return true


func _remove_if_present(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message}


func _sha256_bytes(data: PackedByteArray) -> String:
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK or context.update(data) != OK:
		return ""
	return context.finish().hex_encode()
