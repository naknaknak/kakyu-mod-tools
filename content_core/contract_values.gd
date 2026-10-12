class_name KakyuContractValues
extends RefCounted

## Pure value checks shared by the versioned contract modules (TD-05).
##
## Every function here replaced private copies whose bodies were identical or
## provably equivalent. Variants that differ in meaning keep their own name
## (`sha256` and `sha256_lenient`, the Array and the Dictionary key checks) or
## stay private in their module (bounded integers, typed-key checks), so no
## contract changes what it accepts and no stored fingerprint moves.


const EMPTY_SHA256 := "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")


## SHA-256 of `data` as lower-case hex, or "" when hashing fails. Godot refuses
## an empty chunk, so empty input yields "".
static func sha256(data: PackedByteArray) -> String:
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK or context.update(data) != OK:
		return ""
	return context.finish().hex_encode()


## SHA-256 of `data` without checking the hashing calls. Empty input yields the
## digest of the empty message after the engine reports the refused chunk.
static func sha256_lenient(data: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(data)
	return context.finish().hex_encode()


## SHA-256 of `data`, with the digest of the empty message for empty input and
## "" when hashing fails.
static func sha256_or_empty_digest(data: PackedByteArray) -> String:
	if data.is_empty():
		return EMPTY_SHA256
	return sha256(data)


static func is_sha256(value: String) -> bool:
	if value.length() != 64:
		return false
	for character in value:
		if character not in "0123456789abcdef":
			return false
	return true


## Every listed key of `document` holds a SHA-256 hex string.
static func hash_values(document: Dictionary, keys: Array) -> bool:
	for key in keys:
		if not is_sha256(str(document.get(key, ""))):
			return false
	return true


## Every value of `document` is a SHA-256 hex string.
static func all_hash_values(document: Dictionary) -> bool:
	for value in document.values():
		if not is_sha256(str(value)):
			return false
	return true


static func has_only_keys(document: Dictionary, allowed: Array) -> bool:
	for key in document:
		if str(key) not in allowed:
			return false
	return true


static func has_exact_keys(document: Dictionary, expected: Array) -> bool:
	if document.size() != expected.size():
		return false
	return has_only_keys(document, expected)


static func has_only_key_set(document: Dictionary, allowed: Dictionary) -> bool:
	for key in document:
		if not allowed.has(str(key)):
			return false
	return true


static func has_exact_key_set(document: Dictionary, allowed: Dictionary) -> bool:
	if document.size() != allowed.size():
		return false
	return has_only_key_set(document, allowed)


## An int, or a float with an integral value, as JSON parsing delivers it.
static func json_integer(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or (
		typeof(value) == TYPE_FLOAT and float(value) == floor(float(value))
	)


static func nonnegative_json_integer(value: Variant) -> bool:
	return json_integer(value) and int(value) >= 0


## Every listed key of `document` holds a non-negative JSON integer.
static func nonnegative_integer_values(document: Dictionary, keys: Array) -> bool:
	for key in keys:
		if not nonnegative_json_integer(document.get(key, -1)):
			return false
	return true


## Every value is the boolean `true`. The private copies compared with
## `value != true`, which raises a script error for a non-boolean value; this
## refuses such a value cleanly instead.
static func all_true(document: Dictionary) -> bool:
	for value in document.values():
		if not (value is bool) or value != true:
			return false
	return true


## Lower-case, even-length hex to bytes; anything else yields no bytes.
static func decode_hex(value: String) -> PackedByteArray:
	if value.is_empty() or value.length() % 2 != 0:
		return PackedByteArray()
	for character in value:
		if character not in "0123456789abcdef":
			return PackedByteArray()
	return value.hex_decode()


## `value` as 4 little-endian bytes, lower-case hex.
static func u32_hex(value: int) -> String:
	var bytes := PackedByteArray()
	bytes.resize(4)
	bytes.encode_u32(0, value)
	return bytes.hex_encode()


## Lower-case ASCII identifier: 1-128 characters from `[a-z0-9._-]`.
static func is_identifier(value: String) -> bool:
	if value.is_empty() or value.length() > 128:
		return false
	for character in value:
		if character not in "abcdefghijklmnopqrstuvwxyz0123456789._-":
			return false
	return true


## Decodes the hex bytes at `row["<prefix>_raw_hex"]` and checks them against
## `row["<prefix>_raw_sha256"]`; empty bytes or a hash mismatch yields no bytes.
static func checked_bytes(row: Dictionary, prefix: String) -> PackedByteArray:
	var raw := decode_hex(str(row.get("%s_raw_hex" % prefix, "")))
	if raw.is_empty() or sha256_lenient(raw) != str(row.get("%s_raw_sha256" % prefix, "")):
		return PackedByteArray()
	return raw


## The project/generation/manifest identity a `kakyu_content_workspace_snapshot`
## binds a run to, or `{}` when `snapshot` is not that schema or lacks a project.
static func workspace_binding(snapshot: Dictionary) -> Dictionary:
	if (
		str(snapshot.get("schema", "")) != ContentCoreVersionScript.CONTENT_WORKSPACE_SNAPSHOT_SCHEMA
		or not snapshot.get("project", null) is Dictionary
	):
		return {}
	var project: Dictionary = snapshot.project
	return {
		"project_id": str(project.get("project_id", "")),
		"project_revision": project.get("project_revision", -1),
		"generation_sha256": str(snapshot.get("generation_sha256", "")),
		"project_sha256": str(snapshot.get("project_sha256", "")),
		"manifest_sha256": str(snapshot.get("manifest_sha256", "")),
		"source_content_set_sha256": str(
			snapshot.get("source_content_set", {}).get("fingerprint_sha256", "")
		),
	}


## The contract fingerprint rule (`tools/contract_fingerprint.py`, the same
## shape as the remake's `KakyuEventDefinitionValidator.fingerprint_directory`):
## SHA-256 over "<relative path>\t<sha256 of file bytes>\n" for every regular
## file under `path` except `fingerprint_name`, paths with "/" separators
## relative to `path`, sorted, LF.
static func directory_fingerprint(path: String, fingerprint_name: String) -> String:
	var rows: Array = []
	_collect_fingerprint_rows(path, path, fingerprint_name, rows)
	rows.sort_custom(func(a, b): return a[0] < b[0])
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	for row in rows:
		context.update(("%s\t%s\n" % [row[0], row[1]]).to_utf8_buffer())
	return context.finish().hex_encode()


## Godot's `JSON.parse_string` yields every number as a float; whole-number
## floats fold back to int so an integer field never serializes as `1.0`.
static func intify(value: Variant) -> Variant:
	if value is Dictionary:
		var result := {}
		for key in (value as Dictionary):
			result[key] = intify((value as Dictionary)[key])
		return result
	if value is Array:
		var result: Array = []
		for item in (value as Array):
			result.append(intify(item))
		return result
	if value is float and value == floor(value):
		return int(value)
	return value


static func _collect_fingerprint_rows(base: String, dir_path: String, fingerprint_name: String, rows: Array) -> void:
	var directory := DirAccess.open(dir_path)
	if directory == null:
		return
	directory.list_dir_begin()
	var name := directory.get_next()
	while name != "":
		if name != "." and name != "..":
			var full := dir_path.path_join(name)
			if directory.current_is_dir():
				_collect_fingerprint_rows(base, full, fingerprint_name, rows)
			else:
				var relative := full.substr(base.length())
				while relative.begins_with("/"):
					relative = relative.substr(1)
				if relative != fingerprint_name:
					rows.append([relative, sha256_lenient(FileAccess.get_file_as_bytes(full))])
		name = directory.get_next()
	directory.list_dir_end()
