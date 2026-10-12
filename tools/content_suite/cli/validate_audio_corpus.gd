extends SceneTree

const ArcReaderScript := preload("res://content_core/arc_reader.gd")
const AudioValidatorScript := preload("res://content_core/audio_entry_validator.gd")
const AudioTimelineSummaryScript := preload("res://content_core/audio_timeline_summary.gd")
const HEADER_READ_SIZE := 64 * 1024


func _initialize() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.is_empty():
		push_error("Usage: godot --headless --path . --script res://tools/content_suite/cli/validate_audio_corpus.gd -- <ELFIMAGE>")
		quit(2)
		return
	var source_root := arguments[0].replace("\\", "/").trim_suffix("/")
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

	var total_audio := 0
	var failures := 0
	for archive_name in archive_names:
		var reader := ArcReaderScript.new()
		if not reader.open(source_root.path_join(archive_name)):
			failures += 1
			push_error("AUDIO_CORPUS_FAIL %s reader: %s" % [archive_name, reader.last_error])
			continue
		var archive_audio := 0
		var formats: Dictionary = {}
		var summarized_extensions: Dictionary = {}
		for entry in reader.get_entries():
			var extension := str(entry.name).get_extension().to_lower()
			if extension != "ogg" and extension != "wav":
				continue
			archive_audio += 1
			total_audio += 1
			var header_size := mini(HEADER_READ_SIZE, int(entry.size))
			var header := reader.read_entry_range(int(entry.index), 0, header_size)
			var validation := AudioValidatorScript.validate(str(entry.name), header, int(entry.size))
			if not validation.ok:
				failures += 1
				push_error("AUDIO_CORPUS_FAIL %s/%s: %s" % [archive_name, entry.name, validation.error])
				continue
			var key := "%s/%sch/%sHz" % [validation.codec, validation.channels, validation.sample_rate]
			formats[key] = int(formats.get(key, 0)) + 1
			if not summarized_extensions.has(extension):
				summarized_extensions[extension] = {"attempted": true}
				var summary: Dictionary = AudioTimelineSummaryScript.summarize_ranges(
					str(entry.name),
					int(entry.size),
					func(offset: int, length: int) -> PackedByteArray:
						return reader.read_entry_range(int(entry.index), offset, length)
				)
				if not summary.ok:
					failures += 1
					push_error("AUDIO_CORPUS_FAIL %s/%s timeline: %s" % [archive_name, entry.name, summary.error])
				else:
					summarized_extensions[extension] = {
						"duration_ms": int(summary.duration_ms),
						"waveform": bool(summary.waveform_available),
						"analyzed_frames": int(summary.analyzed_frames),
					}
		if archive_audio > 0:
			print("AUDIO_CORPUS_PASS %s entries=%d formats=%s timeline_samples=%s" % [archive_name, archive_audio, JSON.stringify(formats), JSON.stringify(summarized_extensions)])
		reader.close()
	print("AUDIO_CORPUS_SUMMARY entries=%d failures=%d" % [total_audio, failures])
	quit(1 if failures > 0 else 0)
