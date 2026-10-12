extends "res://tools/content_suite/cli_script.gd"

const AudioEditorScene := preload("res://tools/content_suite/apps/audio_arc_editor.tscn")
const MesAudioReferenceIndexScript := preload("res://content_core/mes_audio_reference_index.gd")
const ArcBatchExtractionScript := preload("res://tools/content_suite/arc_batch_extraction.gd")
const AudioMetadataReportScript := preload("res://tools/content_suite/audio_metadata_report.gd")

const WAV_ARCHIVE := "se.arc"
const WAV_ENTRY := "KSE0031.WAV"
const OGG_ARCHIVE := "voice.arc"
const OGG_ENTRY := "D0044.OGG"
const BGM_ARCHIVE := "bgm.arc"
const BGM_ENTRY := "MAKI.WAV"
const MES_ARCHIVE := "mes.arc"
const SE_BATCH_ENTRY_COUNT := 87
const BATCH_DIRECTORY := "user://validate_audio_arc_editor_original_batch"
const ARCHIVE_DIRECTORY := "user://validate_audio_arc_editor_original_archive"


func _initialize() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() != 1:
		_fail("Usage: <ELFIMAGE>")
		return
	var source_root := ProjectSettings.globalize_path(str(arguments[0]))
	var wav_path := source_root.path_join(WAV_ARCHIVE)
	var ogg_path := source_root.path_join(OGG_ARCHIVE)
	var bgm_path := source_root.path_join(BGM_ARCHIVE)
	var mes_path := source_root.path_join(MES_ARCHIVE)
	var source_hashes := {
		wav_path: FileAccess.get_sha256(wav_path),
		ogg_path: FileAccess.get_sha256(ogg_path),
		bgm_path: FileAccess.get_sha256(bgm_path),
		mes_path: FileAccess.get_sha256(mes_path),
	}
	if source_hashes.values().any(func(value): return str(value).is_empty()):
		_fail("Original audio archives are unavailable.")
		return
	var editor: Control = AudioEditorScene.instantiate()
	root.add_child(editor)
	await process_frame
	var details: RichTextLabel = editor.get_node("Margin/Layout/Split/Right/Details")
	editor.call("_open_archive", wav_path)
	var wav_count := (editor.get("_audio_entries") as Array).size()
	editor.set("_selected_entry", WAV_ENTRY)
	editor.call("_refresh_details")
	if (
		wav_count <= 0
		or not details.text.contains(WAV_ENTRY)
		or not details.text.contains("Container: wav")
		or not details.text.contains("Codec: pcm")
	):
		editor.queue_free()
		_fail("Audio Editor did not validate the original representative PCM WAV: count=%d details=%s" % [wav_count, details.text])
		return

	var batch_names: Array[String] = [WAV_ENTRY]
	for entry in (editor.get("_audio_entries") as Array):
		var candidate_name := str(entry.name)
		if candidate_name == WAV_ENTRY:
			continue
		batch_names.append(candidate_name)
		if batch_names.size() >= 3:
			break
	_remove_tree_if_present(BATCH_DIRECTORY)
	var resolver = editor.get("_resolver")
	var batch_result: Dictionary = ArcBatchExtractionScript.extract_entries(resolver, WAV_ARCHIVE, batch_names, BATCH_DIRECTORY)
	var batch_hashes_ok: bool = batch_result.get("ok", false) and int(batch_result.get("count", -1)) == batch_names.size()
	if batch_hashes_ok:
		for untyped_row in batch_result.get("rows", []):
			var row: Dictionary = untyped_row
			var on_disk := FileAccess.get_file_as_bytes(str(row.path))
			if on_disk.size() != int(row.size) or FileAccess.get_sha256(str(row.path)) != str(row.sha256):
				batch_hashes_ok = false
				break
	_remove_tree_if_present(BATCH_DIRECTORY)

	_remove_tree_if_present(ARCHIVE_DIRECTORY)
	var archive_reader = editor.get("_reader")
	var archive_result: Dictionary = ArcBatchExtractionScript.extract_archive(resolver, archive_reader, WAV_ARCHIVE, ARCHIVE_DIRECTORY)
	var archive_entries := int(archive_result.get("count", -1))
	var archive_bytes := int(archive_result.get("bytes", -1))
	var archive_ok: bool = archive_result.get("ok", false) and archive_entries == SE_BATCH_ENTRY_COUNT
	_remove_tree_if_present(ARCHIVE_DIRECTORY)

	if not batch_hashes_ok or not archive_ok:
		editor.queue_free()
		_fail(
			"Audio Editor batch extraction did not reproduce the original se.arc entries: batch_ok=%s batch_count=%s archive_ok=%s archive_entries=%d"
			% [str(batch_hashes_ok), str(batch_result.get("count", -1)), str(archive_ok), archive_entries]
		)
		return

	editor.call("_open_archive", bgm_path)
	var reference_index: Dictionary = editor.call("_load_mes_reference_index", mes_path)
	var indexer := MesAudioReferenceIndexScript.new()
	var maki_references := indexer.find(reference_index, BGM_ENTRY)
	var voice_references := indexer.find(reference_index, "B0796.OGG")
	editor.set("_selected_entry", BGM_ENTRY)
	editor.call("_refresh_details")
	if (
		not reference_index.get("ok", false)
		or int(reference_index.get("source_count", 0)) != 1016
		or not _has_reference(maki_references, "EVENTD01.MES", 0x03E6, "bgm", 33)
		or not _has_reference(voice_references, "EVENTB01.MES", 0x02BF, "voice", -1)
		or not details.text.contains("Confirmed MES references:")
		or not details.text.contains("EVENTD01.MES 0x3E6")
	):
		editor.queue_free()
		_fail("Audio Editor did not reproduce confirmed original MES audio references: %s" % details.text)
		return

	var bgm_names: Array[String] = []
	for entry in (editor.get("_audio_entries") as Array):
		bgm_names.append(str(entry.name))
	var bgm_report_built: Dictionary = AudioMetadataReportScript.build(
		editor.get("_reader"), editor.get("_resolver"), BGM_ARCHIVE, bgm_names,
		editor.get("_session"), reference_index, mes_path, str(source_hashes[mes_path])
	)
	var bgm_report_entries := 0
	var bgm_referenced := 0
	var bgm_report_ok: bool = bgm_report_built.get("ok", false)
	if bgm_report_ok:
		var bgm_report: Dictionary = bgm_report_built.report
		bgm_report_entries = int(bgm_report.summary.entry_count)
		bgm_referenced = int(bgm_report.summary.referenced_count)
		var maki_row_reference_count := -1
		for untyped_row in bgm_report.entries:
			var row: Dictionary = untyped_row
			if str(row.name) == BGM_ENTRY:
				maki_row_reference_count = int(row.get("mes_reference_count", -1))
				break
		bgm_report_ok = (
			bool(bgm_report.mes_references.indexed)
			and bgm_referenced > 0
			and maki_row_reference_count > 0
		)
	if not bgm_report_ok:
		editor.queue_free()
		_fail("Audio Editor audio metadata report did not reproduce confirmed original bgm.arc MES references: %s" % str(bgm_report_built.get("error", "")))
		return

	editor.call("_open_archive", ogg_path)
	var ogg_count := (editor.get("_audio_entries") as Array).size()
	editor.set("_selected_entry", OGG_ENTRY)
	editor.call("_refresh_details")
	if (
		ogg_count <= 0
		or not details.text.contains(OGG_ENTRY)
		or not details.text.contains("Container: ogg")
		or not details.text.contains("Codec: vorbis")
		or not (editor.get("_session") as Dictionary).is_empty()
		or (editor.get_node("PreviewPlayer") as AudioStreamPlayer).playing
	):
		editor.queue_free()
		_fail("Audio Editor did not validate the original representative Ogg Vorbis without playback or staging.")
		return
	var sources_unchanged := (
		FileAccess.get_sha256(wav_path) == str(source_hashes[wav_path])
		and FileAccess.get_sha256(ogg_path) == str(source_hashes[ogg_path])
		and FileAccess.get_sha256(bgm_path) == str(source_hashes[bgm_path])
		and FileAccess.get_sha256(mes_path) == str(source_hashes[mes_path])
	)
	editor.queue_free()
	await process_frame
	if not sources_unchanged:
		_fail("Audio Editor changed an original archive during read-only validation.")
		return
	print(
		(
			"PASS: Audio Editor original integration WAV=%s PCM OGG=%s Vorbis entries=%d/%d mes_sources=%d confirmed_refs=%d bgm_refs=%d voice_refs=%d playback=stopped session=empty sources_unchanged=true "
			+ "batch=%d archive_entries=%d archive_bytes=%d bgm_report_entries=%d bgm_referenced=%d"
		) % [
			WAV_ENTRY, OGG_ENTRY, wav_count, ogg_count, reference_index.source_count, reference_index.reference_count,
			reference_index.audio_kind_counts.bgm, reference_index.audio_kind_counts.voice,
			batch_names.size(), archive_entries, archive_bytes, bgm_report_entries, bgm_referenced,
		]
	)
	quit(0)


func _has_reference(result: Dictionary, mes_entry: String, source_offset: int, kind: String, selector: int) -> bool:
	if not result.get("ok", false):
		return false
	for untyped_reference in result.get("references", []):
		var reference: Dictionary = untyped_reference
		if (
			str(reference.get("mes_entry", "")) == mes_entry
			and int(reference.get("source_offset", -1)) == source_offset
			and str(reference.get("audio_kind", "")) == kind
			and (selector < 0 or int(reference.get("selector", -1)) == selector)
		):
			return true
	return false


func _remove_tree_if_present(path: String) -> void:
	var absolute := ProjectSettings.globalize_path(path).simplify_path()
	if not DirAccess.dir_exists_absolute(absolute):
		return
	_remove_tree(absolute)


func _remove_tree(path: String) -> void:
	var directory := DirAccess.open(path)
	if directory == null:
		return
	for subdirectory in directory.get_directories():
		_remove_tree(path.path_join(subdirectory))
	for filename in directory.get_files():
		DirAccess.remove_absolute(path.path_join(filename))
	DirAccess.remove_absolute(path)
