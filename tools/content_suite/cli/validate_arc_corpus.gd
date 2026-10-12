extends SceneTree

const ArcReaderScript := preload("res://content_core/arc_reader.gd")
const ArcWriterScript := preload("res://content_core/arc_writer.gd")


func _initialize() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.is_empty():
		push_error("Usage: godot --headless --path . --script res://tools/content_suite/cli/validate_arc_corpus.gd -- <ELFIMAGE> [temporary-parent]")
		quit(2)
		return
	var source_root := arguments[0].replace("\\", "/").trim_suffix("/")
	var temporary_parent := arguments[1] if arguments.size() > 1 else "user://content_core_validation"
	var source_directory := DirAccess.open(source_root)
	if source_directory == null:
		push_error("Could not open ELFIMAGE directory: %s" % source_root)
		quit(2)
		return

	var archive_names: Array[String] = []
	for filename in source_directory.get_files():
		if filename.get_extension().to_lower() == "arc":
			archive_names.append(filename)
	archive_names.sort()
	if archive_names.is_empty():
		push_error("No ARC files were found: %s" % source_root)
		quit(2)
		return

	var validation_root := "%s/kakyu-arc-validation-%s-%s" % [
		temporary_parent.trim_suffix("/"),
		OS.get_process_id(),
		Time.get_ticks_usec(),
	]
	var validation_absolute := ProjectSettings.globalize_path(validation_root).simplify_path()
	var mkdir_error := DirAccess.make_dir_recursive_absolute(validation_absolute)
	if mkdir_error != OK:
		push_error("Could not create validation directory (error %s)." % mkdir_error)
		quit(2)
		return

	var failures := 0
	for archive_name in archive_names:
		var source_path := source_root.path_join(archive_name)
		var output_path := validation_absolute.path_join(archive_name)
		var reader := ArcReaderScript.new()
		if not reader.open(source_path):
			failures += 1
			push_error("CORPUS_FAIL %s reader: %s" % [archive_name, reader.last_error])
			continue
		var source_sha := reader.get_archive_fingerprint()
		var entry_count := reader.get_entries().size()
		var archive_bytes := reader.archive_size
		var layout_check := ArcWriterScript.new().validate_repack_source(reader)
		reader.close()
		if not layout_check.ok:
			failures += 1
			push_error("CORPUS_FAIL %s resize layout: %s" % [archive_name, layout_check.error])
			continue

		var writer := ArcWriterScript.new()
		var result := writer.write_copy(source_path, output_path)
		if not result.ok:
			failures += 1
			push_error("CORPUS_FAIL %s writer: %s" % [archive_name, result.error])
			_remove_if_present(output_path)
			continue
		var post_source_sha := FileAccess.get_sha256(source_path)
		if result.sha256 != source_sha or post_source_sha != source_sha:
			failures += 1
			push_error("CORPUS_FAIL %s SHA-256 mismatch" % archive_name)
		else:
			print(
				"CORPUS_PASS %s entries=%d bytes=%d repack_layout=canonical_contiguous sha256=%s" %
				[archive_name, entry_count, archive_bytes, source_sha]
			)
		_remove_if_present(output_path)

	DirAccess.remove_absolute(validation_absolute)
	quit(1 if failures > 0 else 0)


func _remove_if_present(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
