class_name KakyuArcReader
extends RefCounted

const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")

const ENTRY_SIZE := 264
const NAME_SIZE := 256
const NAME_KEY := 0x72
const SIZE_KEY := 0xF97FD0EC
const OFFSET_KEY := 0xA2C947FC
const DEFAULT_CHUNK_SIZE := 1024 * 1024

var archive_path := ""
var archive_size := 0
var header_size := 0
var last_error := ""

var _file: FileAccess
var _entries: Array[Dictionary] = []
var _entry_indices: Dictionary = {}

# Archive identity memo (TD-57, a tool decision). Hashing a 400-500 MB media
# archive takes 1.6-1.8 s, and the Event Player asked for the same digest of
# the same open reader twice per voice line, BGM change and picture. The memo
# stores the digest of the last full hash together with the file's size and
# modified time taken around it, and `get_archive_identity_fingerprint()`
# trusts it while both still match. It is a per-reader instance memo: `close()`
# clears it and `open()` closes first, so nothing crosses an open, and nothing
# is shared between readers or processes.
#
# Its evidence is weak on purpose and the limits are part of the contract:
# - `FileAccess.get_modified_time` has one-second resolution, so a rewrite of
#   the same size inside the same second as the last full hash is invisible
#   to it. That is exactly what the mutation fixtures do, which is why every
#   change-detection caller keeps `get_archive_fingerprint()` (always a full
#   hash) and only a repeated identity lookup uses the memo.
# - NTFS can defer the last-write update of a file while another process
#   still holds it open for writing, so a writer that has not closed may not
#   have moved the modified time yet.
# - The CRT's `stat` can shift a modified time across a daylight-saving
#   change. The result is a spurious mismatch, hence an extra full hash,
#   which is fail-safe.
# - A modified time that cannot be read (zero or less) or a negative size
#   stores nothing, so such a file is always hashed in full.
# The tool never writes to a source archive and an external edit takes longer
# than a second and almost always changes the size, so the residual is
# accepted for identity lookups (owner, 2026-10-09; `todo/code_health.md`
# TD-57).
var _identity_size := -1
var _identity_modified_time := -1
var _identity_sha256 := ""


func open(path: String) -> bool:
	close()
	last_error = ""
	if path.is_empty():
		return _fail("Archive path is empty.")

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _fail("Could not open archive (error %s): %s" % [FileAccess.get_open_error(), path])
	archive_path = path
	archive_size = file.get_length()
	if archive_size < 4:
		return _fail_open(file, "Archive is smaller than its entry-count field.")

	file.seek(0)
	var entry_count := file.get_32()
	if entry_count > (archive_size - 4) / ENTRY_SIZE:
		return _fail_open(file, "ARC index extends beyond the archive.")
	header_size = 4 + entry_count * ENTRY_SIZE

	var parsed_entries: Array[Dictionary] = []
	var parsed_indices: Dictionary = {}
	for index in range(entry_count):
		var record_offset := 4 + index * ENTRY_SIZE
		file.seek(record_offset)
		var record := file.get_buffer(ENTRY_SIZE)
		if record.size() != ENTRY_SIZE:
			return _fail_open(file, "ARC record %d is truncated." % index)
		var name_result := _decode_name(record.slice(0, NAME_SIZE))
		if not name_result.ok:
			return _fail_open(file, "ARC record %d: %s" % [index, name_result.error])
		var entry_name: String = name_result.value
		var lookup_name := entry_name.to_upper()
		if parsed_indices.has(lookup_name):
			return _fail_open(file, "ARC contains a duplicate entry name: %s" % entry_name)

		var stored_size := record.decode_u32(NAME_SIZE)
		var stored_offset := record.decode_u32(NAME_SIZE + 4)
		var entry_size := stored_size ^ SIZE_KEY
		var entry_offset := stored_offset ^ OFFSET_KEY
		if entry_offset < header_size:
			return _fail_open(file, "ARC entry %s starts inside the index." % entry_name)
		if entry_offset > archive_size or entry_size > archive_size - entry_offset:
			return _fail_open(file, "ARC entry %s extends beyond the archive." % entry_name)

		var entry := {
			"index": index,
			"name": entry_name,
			"offset": entry_offset,
			"size": entry_size,
			"schema": ContentCoreVersionScript.ARC_SCHEMA,
		}
		parsed_indices[lookup_name] = index
		parsed_entries.append(entry)

	_file = file
	_entries = parsed_entries
	_entry_indices = parsed_indices
	return true


func close() -> void:
	if _file != null:
		_file.close()
	_file = null
	archive_path = ""
	archive_size = 0
	header_size = 0
	_entries.clear()
	_entry_indices.clear()
	_clear_identity_memo()


func is_open() -> bool:
	return _file != null


func get_entries() -> Array[Dictionary]:
	return _entries.duplicate(true)


func get_entry(entry_name: String) -> Dictionary:
	var index: int = _entry_indices.get(entry_name.to_upper(), -1)
	if index < 0:
		return {}
	return _entries[index].duplicate(true)


## The SHA-256 of the whole archive file, hashed in full on every call.
##
## This is the change-detection fingerprint: any check that exists to notice
## that the file changed after it was opened or recorded (a writer's
## "changed after it was opened" guard, an editor's live check, a before/after
## audit pair, a hash another process recorded) calls this method. It also
## refreshes the identity memo, but never reads it. A repeated identity lookup
## on the same open reader may call `get_archive_identity_fingerprint()`
## instead. An empty string means the archive path is empty or the file could
## not be hashed; an empty digest is never stored.
func get_archive_fingerprint() -> String:
	if archive_path.is_empty():
		return ""
	var before := _archive_stat()
	var digest := FileAccess.get_sha256(archive_path)
	var after := _archive_stat()
	if (
		digest.is_empty()
		or before.is_empty()
		or after.is_empty()
		or int(before.size) != int(after.size)
		or int(before.modified_time) != int(after.modified_time)
	):
		# The file could not be hashed or changed while it was hashed.
		_clear_identity_memo()
	else:
		_identity_size = int(before.size)
		_identity_modified_time = int(before.modified_time)
		_identity_sha256 = digest
	return digest


## The archive SHA-256 for a repeated identity lookup on this open reader: a
## comparison with a value derived from the same reader moments earlier, with
## a pinned constant, or with the reader's own cache key. It returns the
## digest of this reader's last full hash while the file's size and modified
## time still equal the ones taken around that hash, and otherwise hashes the
## file in full through `get_archive_fingerprint()`.
##
## It is NOT a change-detection fingerprint. A rewrite of the same size inside
## the same second as the last full hash is invisible to it (see the memo
## comment at the top of this file); a check that must notice a change calls
## `get_archive_fingerprint()`. An empty string means the archive path is empty
## or the file is gone.
func get_archive_identity_fingerprint() -> String:
	if archive_path.is_empty():
		return ""
	# The existence check precedes any stat so a missing file prints no engine
	# error.
	if not FileAccess.file_exists(archive_path):
		_clear_identity_memo()
		return ""
	var current := _archive_stat()
	if (
		not current.is_empty()
		and not _identity_sha256.is_empty()
		and int(current.size) == _identity_size
		and int(current.modified_time) == _identity_modified_time
	):
		return _identity_sha256
	return get_archive_fingerprint()


func get_entry_fingerprint(entry_name: String) -> String:
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK:
		last_error = "Could not initialize entry SHA-256."
		return ""
	var streamed := stream_entry(entry_name, func(chunk: PackedByteArray, _offset: int) -> bool:
		return context.update(chunk) == OK
	)
	if not streamed:
		return ""
	return context.finish().hex_encode()


func read_entry(entry_name: String) -> PackedByteArray:
	var entry := get_entry(entry_name)
	if entry.is_empty():
		last_error = "ARC entry does not exist: %s" % entry_name
		return PackedByteArray()
	return read_entry_range(int(entry.index), 0, int(entry.size))


func read_entry_range(entry_index: int, relative_offset: int, length: int) -> PackedByteArray:
	last_error = ""
	if _file == null:
		_fail("Archive is not open.")
		return PackedByteArray()
	if entry_index < 0 or entry_index >= _entries.size():
		_fail("ARC entry index is out of range: %d" % entry_index)
		return PackedByteArray()
	var entry := _entries[entry_index]
	var entry_size := int(entry.size)
	if relative_offset < 0 or relative_offset > entry_size:
		_fail("ARC entry read offset is out of range.")
		return PackedByteArray()
	if length < 0 or length > entry_size - relative_offset:
		_fail("ARC entry read length is out of range.")
		return PackedByteArray()
	_file.seek(int(entry.offset) + relative_offset)
	var data := _file.get_buffer(length)
	if data.size() != length:
		_fail("ARC entry read was truncated.")
		return PackedByteArray()
	return data


func stream_entry(entry_name: String, receiver: Callable, chunk_size := DEFAULT_CHUNK_SIZE) -> bool:
	last_error = ""
	var entry := get_entry(entry_name)
	if entry.is_empty():
		return _fail("ARC entry does not exist: %s" % entry_name)
	if not receiver.is_valid():
		return _fail("ARC stream receiver is invalid.")
	if chunk_size <= 0:
		return _fail("ARC stream chunk size must be positive.")

	var relative_offset := 0
	var remaining := int(entry.size)
	while remaining > 0:
		var read_size := mini(chunk_size, remaining)
		var chunk := read_entry_range(int(entry.index), relative_offset, read_size)
		if chunk.size() != read_size:
			return false
		if receiver.call(chunk, relative_offset) == false:
			return _fail("ARC stream receiver stopped the read.")
		relative_offset += read_size
		remaining -= read_size
	return true


func extract_entry(entry_name: String, output_path: String) -> Dictionary:
	last_error = ""
	var output_absolute := ProjectSettings.globalize_path(output_path).simplify_path()
	if FileAccess.file_exists(output_absolute):
		return _extract_error("Output already exists: %s" % output_path)
	var entry := get_entry(entry_name)
	if entry.is_empty():
		return _extract_error("ARC entry does not exist: %s" % entry_name)
	var parent := output_absolute.get_base_dir()
	var mkdir_error := DirAccess.make_dir_recursive_absolute(parent)
	if mkdir_error != OK:
		return _extract_error("Could not create output directory (error %s)." % mkdir_error)
	var temporary := "%s.tmp-%s-%s" % [output_absolute, OS.get_process_id(), Time.get_ticks_usec()]
	var output := FileAccess.open(temporary, FileAccess.WRITE)
	if output == null:
		return _extract_error("Could not create temporary output (error %s)." % FileAccess.get_open_error())
	var written_context := HashingContext.new()
	if written_context.start(HashingContext.HASH_SHA256) != OK:
		output.close()
		_remove_extract_temporary(temporary)
		return _extract_error("Could not initialize extraction SHA-256.")
	# Lambdas capture scalar values in GDScript, so keep the streaming count in a
	# mutable container that the receiver and the publication check both see.
	var written := {"bytes": 0}
	var wrote := stream_entry(entry_name, func(chunk: PackedByteArray, _offset: int) -> bool:
		output.store_buffer(chunk)
		if output.get_error() != OK or written_context.update(chunk) != OK:
			return false
		written.bytes = int(written.bytes) + chunk.size()
		return true
	)
	var write_error := output.get_error()
	output.close()
	if not wrote or write_error != OK or int(written.bytes) != int(entry.size):
		_remove_extract_temporary(temporary)
		return _extract_error(last_error if not last_error.is_empty() else "ARC entry extraction was incomplete.")
	var streamed_sha := written_context.finish().hex_encode()
	var reopened := FileAccess.open(temporary, FileAccess.READ)
	if reopened == null:
		_remove_extract_temporary(temporary)
		return _extract_error("Could not reopen temporary extraction output.")
	var reopened_size := reopened.get_length()
	reopened.close()
	var reopened_sha := FileAccess.get_sha256(temporary)
	if reopened_size != int(entry.size) or reopened_sha.is_empty() or reopened_sha != streamed_sha:
		_remove_extract_temporary(temporary)
		return _extract_error("Temporary extraction output failed size/SHA-256 verification.")
	if FileAccess.file_exists(output_absolute):
		_remove_extract_temporary(temporary)
		return _extract_error("Output appeared before extraction could be published: %s" % output_path)
	var rename_error := DirAccess.rename_absolute(temporary, output_absolute)
	if rename_error != OK:
		_remove_extract_temporary(temporary)
		return _extract_error("Could not atomically publish extracted entry (error %s)." % rename_error)
	return {"ok": true, "bytes": int(entry.size), "path": output_absolute, "sha256": reopened_sha}


static func is_safe_entry_name(entry_name: String) -> bool:
	if entry_name.is_empty() or entry_name == "." or entry_name == "..":
		return false
	if entry_name.contains("/") or entry_name.contains("\\") or entry_name.contains(":"):
		return false
	for character in entry_name.to_ascii_buffer():
		if character < 0x20 or character > 0x7E:
			return false
	return true


func _decode_name(raw_name: PackedByteArray) -> Dictionary:
	var decoded := PackedByteArray()
	for value in raw_name:
		var character := value ^ NAME_KEY
		if character == 0:
			break
		decoded.append(character)
	var entry_name := decoded.get_string_from_ascii()
	if not is_safe_entry_name(entry_name):
		return {"ok": false, "error": "unsafe or invalid entry name"}
	return {"ok": true, "value": entry_name}


func _clear_identity_memo() -> void:
	_identity_size = -1
	_identity_modified_time = -1
	_identity_sha256 = ""


## `{size, modified_time}` of the archive file now, or `{}` when the file is
## gone or its modified time or size is unusable (a modified time of zero or
## less, a negative size), so that no memo is ever built on evidence that
## cannot distinguish two states of the file.
func _archive_stat() -> Dictionary:
	if archive_path.is_empty() or not FileAccess.file_exists(archive_path):
		return {}
	var modified_time := int(FileAccess.get_modified_time(archive_path))
	if modified_time <= 0:
		return {}
	var size := int(FileAccess.get_size(archive_path))
	if size < 0:
		return {}
	return {"size": size, "modified_time": modified_time}


func _fail(message: String) -> bool:
	last_error = message
	return false


func _fail_open(file: FileAccess, message: String) -> bool:
	file.close()
	archive_path = ""
	archive_size = 0
	header_size = 0
	return _fail(message)


func _extract_error(message: String) -> Dictionary:
	last_error = message
	return {"ok": false, "error": message}


func _remove_extract_temporary(path: String) -> void:
	if not path.is_empty() and FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
