class_name KakyuMesTextCache
extends RefCounted

const ArcReaderScript := preload("res://content_core/arc_reader.gd")
const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")
const ContractValues := preload("res://content_core/contract_values.gd")
const MAX_JSON_BYTES := 16 * 1024 * 1024

var last_error := ""
var _root := ""
var _archive_sha256 := ""
var _entries: Dictionary = {}


func configure(root: String, archive_sha256: String) -> bool:
	clear()
	if not ContractValues.is_sha256(archive_sha256):
		return _fail("Text cache archive SHA-256 is invalid.")
	var absolute_root := ProjectSettings.globalize_path(root).simplify_path()
	var manifest_result := _load_json(absolute_root.path_join("manifest.json"))
	if not manifest_result.ok:
		return _fail(str(manifest_result.error))
	var manifest: Dictionary = manifest_result.value
	if manifest.get("schema", "") != ContentCoreVersionScript.MES_TEXT_CACHE_SCHEMA:
		return _fail("Unsupported MES text cache schema.")
	if manifest.get("archive_sha256", "") != archive_sha256:
		return _fail("MES text cache archive SHA-256 does not match.")
	if not manifest.get("entries", []) is Array:
		return _fail("MES text cache entries are not an array.")
	var indexed: Dictionary = {}
	for untyped_record in manifest.entries:
		if not untyped_record is Dictionary:
			return _fail("MES text cache contains a non-object entry record.")
		var record: Dictionary = untyped_record
		var entry_name := str(record.get("entry", ""))
		var relative_path := str(record.get("path", ""))
		if not ArcReaderScript.is_safe_entry_name(entry_name) or not _is_safe_entry_path(relative_path):
			return _fail("MES text cache contains an unsafe entry or path.")
		if not ContractValues.is_sha256(str(record.get("entry_sha256", ""))) or not ContractValues.is_sha256(str(record.get("file_sha256", ""))):
			return _fail("MES text cache contains an invalid SHA-256 field.")
		var key := entry_name.to_upper()
		if indexed.has(key):
			return _fail("MES text cache contains a duplicate entry: %s" % entry_name)
		var absolute_path := absolute_root.path_join(relative_path)
		var file_validation := _validate_cache_file(absolute_path, str(record.file_sha256))
		if not file_validation.ok:
			return _fail("MES text cache entry file rejected (%s): %s" % [relative_path, str(file_validation.error)])
		indexed[key] = record.duplicate(true)
	_root = absolute_root
	_archive_sha256 = archive_sha256
	_entries = indexed
	return true


func clear() -> void:
	last_error = ""
	_root = ""
	_archive_sha256 = ""
	_entries.clear()


func load_entry(entry_name: String, entry_sha256: String) -> Dictionary:
	last_error = ""
	var record: Dictionary = _entries.get(entry_name.to_upper(), {})
	if record.is_empty():
		return _error("MES text cache has no projection for %s." % entry_name)
	if record.entry_sha256 != entry_sha256:
		return _error("MES text cache entry SHA-256 does not match the resolved MES bytes.")
	var loaded := _load_json(_root.path_join(str(record.path)), str(record.file_sha256))
	if not loaded.ok:
		return loaded
	var document: Dictionary = loaded.value
	if document.get("schema", "") != ContentCoreVersionScript.MES_TEXT_ENTRY_SCHEMA:
		return _error("Unsupported MES text entry cache schema.")
	if document.get("entry", "") != entry_name or document.get("entry_sha256", "") != entry_sha256:
		return _error("MES text entry cache binding does not match.")
	if not document.get("messages", []) is Array:
		return _error("MES text entry messages are not an array.")
	var messages: Dictionary = {}
	for untyped_message in document.messages:
		if not untyped_message is Dictionary:
			return _error("MES text cache contains a non-object message.")
		var message: Dictionary = untyped_message
		var offset := int(message.get("source_offset", -1))
		var text_value = message.get("text")
		if offset < 0 or not text_value is String or not ContractValues.is_sha256(str(message.get("raw_sha256", ""))):
			return _error("MES text cache contains an invalid message record.")
		if messages.has(offset):
			return _error("MES text cache contains a duplicate message offset.")
		messages[offset] = {
			"text": text_value,
			"raw_sha256": str(message.raw_sha256),
		}
	return {"ok": true, "messages": messages, "message_count": messages.size()}


func _load_json(path: String, expected_sha256 := "") -> Dictionary:
	var read_result := _read_bounded_file(path)
	if not read_result.ok:
		return read_result
	var bytes: PackedByteArray = read_result.bytes
	if not expected_sha256.is_empty() and ContractValues.sha256_lenient(bytes) != expected_sha256:
		return _error("MES text cache entry file changed after configuration.")
	var value = JSON.parse_string(bytes.get_string_from_utf8())
	if not value is Dictionary:
		return _error("MES text cache JSON root is not an object.")
	return {"ok": true, "value": value}


func _validate_cache_file(path: String, expected_sha256: String) -> Dictionary:
	var read_result := _read_bounded_file(path)
	if not read_result.ok:
		return read_result
	if ContractValues.sha256_lenient(read_result.bytes) != expected_sha256:
		return _error("MES text cache entry file fingerprint does not match.")
	return {"ok": true}


func _read_bounded_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return _error("MES text cache file does not exist: %s" % path)
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _error("Could not open MES text cache file.")
	var file_size := file.get_length()
	if file_size > MAX_JSON_BYTES:
		file.close()
		return _error("MES text cache JSON exceeds the %d-byte limit." % MAX_JSON_BYTES)
	var bytes := file.get_buffer(file_size)
	var read_error := file.get_error()
	file.close()
	if bytes.size() != file_size or read_error != OK:
		return _error("MES text cache file changed or was truncated while reading.")
	return {"ok": true, "bytes": bytes}


func _is_safe_entry_path(path: String) -> bool:
	if path.is_empty() or path.begins_with("/") or path.contains("\\") or path.contains(":"):
		return false
	var parts := path.split("/", false)
	if parts.size() != 2 or parts[0] != "entries":
		return false
	for part in parts:
		if part.is_empty() or part == "." or part == "..":
			return false
	return true


func _fail(message: String) -> bool:
	last_error = message
	return false


func _error(message: String) -> Dictionary:
	last_error = message
	return {"ok": false, "error": message}
