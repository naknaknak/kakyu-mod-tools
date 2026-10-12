extends "res://tests/test_case.gd"

const CacheScript := preload("res://content_core/mes_text_cache.gd")
const TEST_ROOT := "user://mes_text_cache_test"
const ARCHIVE_SHA := "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
const ENTRY_SHA := "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"


func _ready() -> void:
	_cleanup()
	var absolute := ProjectSettings.globalize_path(TEST_ROOT)
	DirAccess.make_dir_recursive_absolute(absolute.path_join("entries"))
	var entry_path := absolute.path_join("entries/cache.json")
	var entry_document := {
		"schema": "kakyu_mes_text_entry/v1",
		"entry": "TEST.MES",
		"entry_sha256": ENTRY_SHA,
		"messages": [{
			"source_offset": 16,
			"text": "preview",
			"raw_sha256": "cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc",
		}],
	}
	_write_json(entry_path, entry_document)
	var original_entry_bytes := FileAccess.get_file_as_bytes(entry_path)
	_write_json(absolute.path_join("manifest.json"), {
		"schema": "kakyu_mes_text_cache/v1",
		"archive_sha256": ARCHIVE_SHA,
		"entries": [{
			"entry": "TEST.MES",
			"entry_sha256": ENTRY_SHA,
			"path": "entries/cache.json",
			"file_sha256": FileAccess.get_sha256(entry_path),
		}],
	})
	var cache := CacheScript.new()
	_check(cache.configure(TEST_ROOT, ARCHIVE_SHA), "hash-bound text cache configures")
	var loaded := cache.load_entry("TEST.MES", ENTRY_SHA)
	_check(loaded.ok and loaded.messages[16].text == "preview", "UTF-8 message projection loads by source offset")
	_check(loaded.messages[16].raw_sha256.begins_with("cccc"), "projection retains its original CP932 hash binding")
	_check(not cache.load_entry("TEST.MES", ARCHIVE_SHA).ok, "stale entry hash fails closed")
	entry_document.messages[0].text = "changed after configure"
	_write_json(entry_path, entry_document)
	var changed_load := cache.load_entry("TEST.MES", ENTRY_SHA)
	_check(
		not changed_load.ok and str(changed_load.error).contains("changed after configuration"),
		"text cache rechecks the configured projection fingerprint at load time"
	)
	_write_repeated_file(entry_path, CacheScript.MAX_JSON_BYTES + 1, 0x20)
	var oversized_load := cache.load_entry("TEST.MES", ENTRY_SHA)
	_check(
		not oversized_load.ok and str(oversized_load.error).contains("exceeds"),
		"text cache rejects an entry JSON that grows beyond the bounded load limit"
	)
	_write_bytes(entry_path, original_entry_bytes)
	var restored_load := cache.load_entry("TEST.MES", ENTRY_SHA)
	_check(restored_load.ok and restored_load.messages[16].text == "preview", "restored hash-bound text cache loads again")
	_check(not cache.configure(TEST_ROOT, ENTRY_SHA), "wrong archive hash fails closed")
	_write_repeated_file(absolute.path_join("manifest.json"), CacheScript.MAX_JSON_BYTES + 1, 0x20)
	_check(not cache.configure(TEST_ROOT, ARCHIVE_SHA) and cache.last_error.contains("exceeds"), "text cache rejects an oversized manifest before parsing")
	_cleanup()
	await get_tree().process_frame
	get_tree().quit(1 if _failed else 0)


func _write_json(path: String, value: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(value))
	file.close()


func _write_bytes(path: String, bytes: PackedByteArray) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()


func _write_repeated_file(path: String, size: int, value: int) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	var chunk := PackedByteArray()
	chunk.resize(64 * 1024)
	chunk.fill(value)
	var remaining := size
	while remaining > 0:
		var write_size := mini(chunk.size(), remaining)
		file.store_buffer(chunk.slice(0, write_size))
		remaining -= write_size
	file.close()


func _cleanup() -> void:
	var absolute := ProjectSettings.globalize_path(TEST_ROOT)
	var entry_path := absolute.path_join("entries/cache.json")
	if FileAccess.file_exists(entry_path):
		DirAccess.remove_absolute(entry_path)
	var manifest_path := absolute.path_join("manifest.json")
	if FileAccess.file_exists(manifest_path):
		DirAccess.remove_absolute(manifest_path)
	DirAccess.remove_absolute(absolute.path_join("entries"))
	DirAccess.remove_absolute(absolute)
