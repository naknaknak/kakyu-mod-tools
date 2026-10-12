extends SceneTree

const ArcReaderScript := preload("res://content_core/arc_reader.gd")
const ArcWriterScript := preload("res://content_core/arc_writer.gd")
const AudioValidatorScript := preload("res://content_core/audio_entry_validator.gd")


func _initialize() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() not in [3, 4]:
		push_error("Usage: godot --headless --path . --script res://tools/content_suite/cli/prepare_arc_smoke_copy.gd -- <source-archive> <audio-entry> <new-archive> [replacement-audio]")
		quit(2)
		return
	var source_path := arguments[0]
	var entry_name := arguments[1]
	var output_path := arguments[2]
	var replacement_path := arguments[3] if arguments.size() == 4 else ""
	if entry_name == "*" and replacement_path.is_empty():
		push_error("SMOKE_PREPARE_FAIL '*' requires replacement-audio")
		quit(2)
		return
	var reader := ArcReaderScript.new()
	if not reader.open(source_path):
		push_error("SMOKE_PREPARE_FAIL reader: %s" % reader.last_error)
		quit(1)
		return
	var target_entries: Array = []
	if entry_name == "*":
		for candidate in reader.get_entries():
			if candidate.name.get_extension().to_lower() in ["ogg", "wav"]:
				target_entries.append(candidate)
	else:
		var entry := reader.get_entry(entry_name)
		if not entry.is_empty():
			target_entries.append(entry)
	if target_entries.is_empty():
		push_error("SMOKE_PREPARE_FAIL missing audio target: %s" % entry_name)
		reader.close()
		quit(1)
		return
	var source_sha := reader.get_archive_fingerprint()
	var replacement := PackedByteArray()
	var replacement_size := 0
	var replacement_header := PackedByteArray()
	if replacement_path.is_empty():
		replacement = reader.read_entry(target_entries[0].name)
		replacement.append(0)
		replacement_size = replacement.size()
		replacement_header = replacement
	else:
		var replacement_file := FileAccess.open(replacement_path, FileAccess.READ)
		if replacement_file == null:
			push_error("SMOKE_PREPARE_FAIL replacement open: %s" % error_string(FileAccess.get_open_error()))
			reader.close()
			quit(1)
			return
		replacement_size = replacement_file.get_length()
		replacement_header = replacement_file.get_buffer(mini(64 * 1024, replacement_size))
		replacement_file.close()
	var replacements := {}
	var old_bytes := 0
	for target in target_entries:
		var audio_validation := AudioValidatorScript.validate(target.name, replacement_header, replacement_size)
		if not audio_validation.ok:
			push_error("SMOKE_PREPARE_FAIL replacement audio for %s: %s" % [target.name, audio_validation.error])
			reader.close()
			quit(1)
			return
		replacements[target.name] = replacement_path if not replacement_path.is_empty() else replacement
		old_bytes += int(target.size)
	reader.close()

	var writer := ArcWriterScript.new()
	var result := (
		writer.write_repacked_copy_from_files(source_path, output_path, replacements)
		if not replacement_path.is_empty()
		else writer.write_repacked_copy(source_path, output_path, replacements)
	)
	if not result.ok:
		push_error("SMOKE_PREPARE_FAIL writer: %s" % result.error)
		quit(1)
		return
	if FileAccess.get_sha256(source_path) != source_sha:
		push_error("SMOKE_PREPARE_FAIL source archive hash changed")
		quit(1)
		return
	if target_entries.size() == 1:
		print(
			"SMOKE_PREPARE_PASS entry=%s old_bytes=%d new_bytes=%d output_sha256=%s" %
				[target_entries[0].name, old_bytes, replacement_size, result.sha256]
		)
	else:
		print(
			"SMOKE_PREPARE_PASS entries=%d old_bytes=%d new_bytes=%d output_sha256=%s" %
				[target_entries.size(), old_bytes, replacement_size * target_entries.size(), result.sha256]
		)
	quit(0)
