extends SceneTree

# Command line front end for KakyuArcBatchExtraction. Opens one ARC read-only,
# optionally binds an overlay read layer, then extracts either the named
# entries or the complete archive into a fresh output directory. Prints
# exactly one JSON line and never overwrites an existing output.

const ArcReaderScript := preload("res://content_core/arc_reader.gd")
const ContentResolverScript := preload("res://content_core/content_resolver.gd")
const ArcBatchExtractionScript := preload("res://tools/content_suite/arc_batch_extraction.gd")


func _init() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() < 2:
		_fail("Usage: extract_arc_entries.gd <archive.arc> <output_dir> [--overlay <package_root>] [ENTRY ...]")
		return
	var archive_path := str(arguments[0])
	var output_directory := str(arguments[1])
	var overlay_root := ""
	var entry_names: Array[String] = []
	var index := 2
	while index < arguments.size():
		var argument := str(arguments[index])
		if argument == "--overlay":
			if index + 1 >= arguments.size():
				_fail("Missing value for --overlay.")
				return
			overlay_root = str(arguments[index + 1])
			index += 2
			continue
		entry_names.append(argument)
		index += 1

	var reader := ArcReaderScript.new()
	if not reader.open(archive_path):
		_fail(reader.last_error)
		return
	var archive_name := archive_path.replace("\\", "/").get_file()
	var resolver := ContentResolverScript.new()
	if not resolver.register_original_archive(archive_name, reader.archive_path):
		_fail(resolver.last_error)
		return
	if not overlay_root.is_empty():
		if not resolver.configure_overlay(overlay_root):
			_fail(resolver.last_error)
			return

	var result: Dictionary
	if entry_names.is_empty():
		result = ArcBatchExtractionScript.extract_archive(resolver, reader, archive_name, output_directory)
	else:
		result = ArcBatchExtractionScript.extract_entries(resolver, archive_name, entry_names, output_directory)

	if not result.get("ok", false):
		_fail(str(result.get("error", "")))
		return
	print(JSON.stringify({
		"ok": true,
		"count": int(result.count),
		"bytes": int(result.bytes),
		"overlay_count": int(result.overlay_count),
		"original_count": int(result.original_count),
		"directory": str(result.directory),
	}))
	quit(0)


func _fail(message: String) -> void:
	print(JSON.stringify({"ok": false, "error": message}))
	quit(1)
