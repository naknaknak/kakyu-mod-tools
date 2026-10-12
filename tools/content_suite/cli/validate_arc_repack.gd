extends SceneTree

const ArcReaderScript := preload("res://content_core/arc_reader.gd")
const ArcWriterScript := preload("res://content_core/arc_writer.gd")
const AudioValidatorScript := preload("res://content_core/audio_entry_validator.gd")


func _initialize() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() < 2:
		push_error("Usage: godot --headless --path . --script res://tools/content_suite/cli/validate_arc_repack.gd -- <archive> <entry> [temporary-parent]")
		quit(2)
		return
	var source_path := arguments[0]
	var entry_name := arguments[1]
	var temporary_parent := arguments[2] if arguments.size() > 2 else "user://content_core_validation"
	var reader := ArcReaderScript.new()
	if not reader.open(source_path):
		push_error("REPACK_FAIL reader: %s" % reader.last_error)
		quit(1)
		return
	var entry := reader.get_entry(entry_name)
	if entry.is_empty():
		push_error("REPACK_FAIL missing entry: %s" % entry_name)
		reader.close()
		quit(1)
		return
	var source_sha := reader.get_archive_fingerprint()
	var replacement := reader.read_entry(entry_name)
	if replacement.size() != int(entry.size):
		push_error("REPACK_FAIL source entry read was truncated")
		reader.close()
		quit(1)
		return
	replacement.append(0)
	if entry_name.get_extension().to_lower() in ["wav", "ogg"]:
		var audio_validation := AudioValidatorScript.validate(entry_name, replacement, replacement.size())
		if not audio_validation.ok:
			push_error("REPACK_FAIL generated audio replacement is invalid: %s" % audio_validation.error)
			reader.close()
			quit(1)
			return
	reader.close()

	var validation_root := "%s/kakyu-repack-validation-%s-%s" % [
		temporary_parent.trim_suffix("/"),
		OS.get_process_id(),
		Time.get_ticks_usec(),
	]
	var validation_absolute := ProjectSettings.globalize_path(validation_root).simplify_path()
	if DirAccess.make_dir_recursive_absolute(validation_absolute) != OK:
		push_error("REPACK_FAIL could not create temporary directory")
		quit(1)
		return
	var output_path := validation_absolute.path_join(source_path.replace("\\", "/").get_file())
	var result := ArcWriterScript.new().write_repacked_copy(
		source_path,
		output_path,
		{entry_name: replacement}
	)
	var failed: bool = not bool(result.ok)
	if failed:
		push_error("REPACK_FAIL writer: %s" % result.error)
	elif FileAccess.get_sha256(source_path) != source_sha:
		failed = true
		push_error("REPACK_FAIL source archive hash changed")
	else:
		print(
			"REPACK_PASS archive=%s entry=%s old_bytes=%d new_bytes=%d sha256=%s" %
				[source_path.replace("\\", "/").get_file(), entry_name, int(entry.size), replacement.size(), result.sha256]
		)
	_remove_if_present(output_path)
	DirAccess.remove_absolute(validation_absolute)
	quit(1 if failed else 0)


func _remove_if_present(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
