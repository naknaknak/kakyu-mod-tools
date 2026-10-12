extends SceneTree

const ArcReaderScript := preload("res://content_core/arc_reader.gd")
const TextCacheScript := preload("res://content_core/mes_text_cache.gd")


func _initialize() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() < 2:
		push_error("Usage: godot --headless --path . --script res://tools/content_suite/cli/validate_mes_text_cache.gd -- <mes.arc> <cache-root>")
		quit(2)
		return
	var archive_path := arguments[0].replace("\\", "/")
	var cache_root := arguments[1].replace("\\", "/")
	var reader := ArcReaderScript.new()
	if not reader.open(archive_path):
		push_error("MES_TEXT_CACHE_FAIL reader: %s" % reader.last_error)
		quit(2)
		return
	var cache := TextCacheScript.new()
	if not cache.configure(cache_root, reader.get_archive_fingerprint()):
		push_error("MES_TEXT_CACHE_FAIL cache: %s" % cache.last_error)
		reader.close()
		quit(2)
		return
	var manifest_file := FileAccess.open(cache_root.path_join("manifest.json"), FileAccess.READ)
	var manifest_value = JSON.parse_string(manifest_file.get_as_text()) if manifest_file != null else null
	if not manifest_value is Dictionary:
		push_error("MES_TEXT_CACHE_FAIL manifest could not be enumerated")
		reader.close()
		quit(2)
		return
	var checked := 0
	var messages := 0
	var failures := 0
	for untyped_record in manifest_value.get("entries", []):
		var record: Dictionary = untyped_record
		var entry_name := str(record.get("entry", ""))
		var loaded := cache.load_entry(entry_name, reader.get_entry_fingerprint(entry_name))
		if not loaded.ok:
			failures += 1
			push_error("MES_TEXT_CACHE_FAIL %s: %s" % [entry_name, loaded.error])
			continue
		checked += 1
		messages += int(loaded.message_count)
	print("MES_TEXT_CACHE_SUMMARY entries=%d messages=%d failures=%d" % [checked, messages, failures])
	reader.close()
	quit(1 if failures > 0 else 0)
