extends "res://tests/test_case.gd"

const ArcReaderScript := preload("res://content_core/arc_reader.gd")
const ArcProvenanceScript := preload("res://content_core/arc_provenance.gd")
const OverlayPackageScript := preload("res://content_core/overlay_package.gd")
const AudioEditorScene := preload("res://tools/content_suite/apps/audio_arc_editor.tscn")
const ToolPathHistoryScript := preload("res://tools/content_suite/tool_path_history.gd")
const AudioMetadataReportScript := preload("res://tools/content_suite/audio_metadata_report.gd")
const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")
const ContentProjectScript := preload("res://content_core/content_project.gd")
const ContentWorkspaceScript := preload("res://content_core/content_workspace.gd")
const ContentSelectionScript := preload("res://content_core/content_selection.gd")
const SyntheticArc := preload("res://tests/synthetic_arc.gd")

const TEST_ROOT := "user://audio_arc_editor_test"


func _ready() -> void:
	_cleanup()
	var absolute_root := ProjectSettings.globalize_path(TEST_ROOT)
	DirAccess.make_dir_recursive_absolute(absolute_root)
	var archive_path := TEST_ROOT + "/se.arc"
	var mes_archive_path := TEST_ROOT + "/mes.arc"
	var replacement_a_path := TEST_ROOT + "/replacement-a.wav"
	var replacement_b_path := TEST_ROOT + "/replacement-b.wav"
	var conversion_source_path := TEST_ROOT + "/conversion-source.wav"
	var conversion_output_path := TEST_ROOT + "/KSE0001-converted.wav"
	var output_arc_path := TEST_ROOT + "/se-session.arc"
	var changed_source_output_arc_path := TEST_ROOT + "/changed-source-session.arc"
	var overlay_root := TEST_ROOT + "/my_mod"
	var initial_overlay_root := TEST_ROOT + "/loaded_mod"
	var overlay_extract_path := TEST_ROOT + "/overlay-extract.wav"
	var pending_extract_path := TEST_ROOT + "/pending-extract.wav"
	var second_pending_replacement_path := TEST_ROOT + "/replacement-c.wav"
	var batch_pair_output_dir := TEST_ROOT + "/batch-pair-output"
	var batch_trio_output_dir := TEST_ROOT + "/batch-trio-output"
	var batch_archive_output_dir := TEST_ROOT + "/batch-archive-output"
	var audio_report_output_path := TEST_ROOT + "/audio-report.json"
	var original_a := _pcm_wave(1, 2)
	var original_b := _pcm_wave(2, 4)
	var original_metadata := PackedByteArray([1, 2, 3, 4])
	var loaded_overlay_a := _pcm_wave(7, 8)
	var loaded_overlay_metadata := PackedByteArray([5, 6, 7, 8])
	var reloaded_overlay_a := _pcm_wave(8, 12)
	var replacement_a := _pcm_wave(3, 6)
	var replacement_b := _pcm_wave(4, 10)
	var second_pending_replacement := _pcm_wave(6, 8)
	var conversion_source := _pcm16_wave(PackedInt32Array([-2000, 2000, 1000, 3000]), 2, 11025)
	SyntheticArc.write_arc(archive_path, [
		{"name": "KSE0001.WAV", "data": original_a},
		{"name": "KSE0002.WAV", "data": original_b},
		{"name": "MAKI.WAV", "data": original_a},
		{"name": "META.BIN", "data": original_metadata},
	])
	SyntheticArc.write_arc(mes_archive_path, [
		{"name": "EVENTD01.MES", "data": _mes_with_bgm_reference(33)},
		{"name": "NOT_AUDIO.MES", "data": _mes_without_bgm_reference()},
	])
	_write_bytes(replacement_a_path, replacement_a)
	_write_bytes(replacement_b_path, replacement_b)
	_write_bytes(conversion_source_path, conversion_source)
	var pristine_archive_bytes := FileAccess.get_file_as_bytes(archive_path)
	var source_sha := FileAccess.get_sha256(archive_path)
	var overlay_source := ArcReaderScript.new()
	_check(overlay_source.open(archive_path), "audio overlay fixture opens its source ARC")
	var overlay_package := OverlayPackageScript.new()
	var initial_overlay := overlay_package.stage_replacements(
		initial_overlay_root,
		overlay_source,
		"se.arc",
		{
			"KSE0001.WAV": loaded_overlay_a,
			"META.BIN": loaded_overlay_metadata,
		},
		"remake_only",
		"not_applicable"
	)
	_check(initial_overlay.ok, "audio overlay fixture publishes hash-bound audio and non-audio records")

	var editor: Control = AudioEditorScene.instantiate()
	editor.set("_path_history", ToolPathHistoryScript.new(TEST_ROOT.path_join("path_history.cfg")))
	add_child(editor)
	await get_tree().process_frame
	editor.call("_open_archive", archive_path)
	_check((editor.get("_path_history") as ContentToolPathHistory).get_last_source_directory() == absolute_root.simplify_path(), "audio editor remembers its successfully opened ARC directory")
	_check((editor.get_node("OpenDialog") as FileDialog).current_dir.simplify_path() == absolute_root.simplify_path(), "audio editor reopens its ARC chooser at the remembered directory")
	_check(get_window().content_scale_mode == Window.CONTENT_SCALE_MODE_DISABLED, "audio editor uses native desktop pixels")
	_check(editor.size == Vector2(get_window().size), "audio editor fills the desktop client area")
	_check(_controls_fit(editor), "audio editor controls fit the desktop client area")
	var original_window_size := get_window().size
	get_window().size = Vector2i(1024, 640)
	await get_tree().process_frame
	_check(editor.size == Vector2(1024, 640) and _controls_fit(editor), "audio editor remains usable at the shared minimum desktop size")
	get_window().size = Vector2i(1920, 1080)
	await get_tree().process_frame
	_check(editor.size == Vector2(1920, 1080), "audio editor reflows at 1920x1080")
	get_window().size = Vector2i(2560, 1440)
	await get_tree().process_frame
	_check(editor.size == Vector2(2560, 1440), "audio editor reflows at 2560x1440")
	get_window().size = original_window_size
	await get_tree().process_frame
	var filter_edit: LineEdit = editor.get_node("Margin/Layout/FilterEdit")
	var entry_tree: Tree = editor.get_node("Margin/Layout/Split/EntryTree")
	var details: RichTextLabel = editor.get_node("Margin/Layout/Split/Right/Details")
	var analyze_button: Button = editor.get_node("Margin/Layout/Toolbar/AnalyzeTimeline")
	var status: Label = editor.get_node("Margin/Layout/StatusLabel")
	var preview_player: AudioStreamPlayer = editor.get_node("PreviewPlayer")
	var extraction_progress_row: Control = editor.get_node("Margin/Layout/ExtractionProgressRow")
	var extraction_progress: ProgressBar = editor.get_node("Margin/Layout/ExtractionProgressRow/ExtractionProgress")
	var cancel_extraction_button: Button = editor.get_node("Margin/Layout/ExtractionProgressRow/CancelExtraction")
	_check(not extraction_progress_row.visible, "audio editor hides the extraction progress row while idle")
	filter_edit.text = "0001"
	editor.call("_on_filter_changed", filter_edit.text)
	_check(entry_tree.get_root().get_child_count() == 1, "audio editor filters OGG/WAV entry names")
	filter_edit.clear()
	editor.call("_on_filter_changed", "")
	_check(entry_tree.get_root().get_child_count() == 3, "clearing the audio filter restores all entries")

	editor.call("_on_load_overlay_directory_selected", initial_overlay_root)
	var mes_source_sha := FileAccess.get_sha256(mes_archive_path)
	var reference_index: Dictionary = editor.call("_load_mes_reference_index", mes_archive_path)
	_check(
		reference_index.ok
		and reference_index.source_count == 2
		and reference_index.reference_count == 1
		and str(editor.get("_mes_reference_source_sha256")) == mes_source_sha,
		"audio editor builds one source-bound confirmed reference index from a selected mes.arc"
	)
	editor.set("_selected_entry", "MAKI.WAV")
	editor.call("_refresh_details")
	_check(
		details.text.contains("Confirmed MES references: 1")
		and details.text.contains("EVENTD01.MES 0x0")
		and details.text.contains("BGM selector 33, routine 23 at 0x6"),
		"audio details search the loaded MES index for the selected WAV"
	)
	var mes_reference_select: OptionButton = editor.get_node("Margin/Layout/Split/Right/ReferenceActions/MesReferenceSelect")
	var open_reference_button: Button = editor.get_node("Margin/Layout/Split/Right/ReferenceActions/OpenReferenceEventPlayer")
	_check(
		not mes_reference_select.disabled and mes_reference_select.item_count == 1
		and str(mes_reference_select.get_item_text(0)).begins_with("EVENTD01.MES 0x")
		and str(mes_reference_select.get_item_text(0)).ends_with("· bgm")
		and not open_reference_button.disabled,
		"MesReferenceSelect lists the EVENTD01.MES confirmed reference for MAKI.WAV"
	)
	_check(
		not (editor.call("_build_reference_launch") as Dictionary).get("ok", true),
		"_build_reference_launch without a named context returns the named-workspace error"
	)
	editor.set("_selected_entry", "KSE0001.WAV")
	editor.call("_refresh_details")
	_check(details.text.contains("Confirmed MES references: 0"), "audio details distinguish a loaded index with no confirmed selected-entry references")
	_check(FileAccess.get_sha256(mes_archive_path) == mes_source_sha, "MES reference indexing leaves its source archive unchanged")
	editor.call("_clear_mes_reference_index")
	editor.call("_on_mes_reference_archive_selected", mes_archive_path)
	for _frame in range(8):
		if not bool(editor.get("_mes_reference_load_active")):
			break
		await get_tree().process_frame
	_check(
		not bool(editor.get("_mes_reference_load_active"))
		and not (editor.get_node("Margin/Layout/OverlayActions/LoadMesReferences") as Button).disabled
		and int((editor.get("_mes_reference_index") as Dictionary).reference_count) == 1,
		"interactive MES reference loading yields in bounded batches and re-enables its action"
	)
	var stable_reference_index: Dictionary = (editor.get("_mes_reference_index") as Dictionary).duplicate(true)
	var wrong_reference_source: Dictionary = editor.call("_load_mes_reference_index", archive_path)
	_check(
		not wrong_reference_source.ok
		and str(wrong_reference_source.error).contains("Choose a mes.arc")
		and editor.get("_mes_reference_index") == stable_reference_index,
		"a non-MES ARC is rejected without replacing the last valid reference index"
	)
	var first_entry := entry_tree.get_root().get_first_child()
	_check(editor.get("_overlay_root") == ProjectSettings.globalize_path(initial_overlay_root).simplify_path(), "audio editor loads an existing overlay as its active read layer")
	_check(first_entry.get_text(2) == "Overlay", "audio editor marks an entry resolved from the loaded overlay")
	var loaded_audio: Dictionary = editor.call("_read_effective_audio", "KSE0001.WAV")
	_check(loaded_audio.ok and loaded_audio.source == "overlay" and loaded_audio.data == loaded_overlay_a, "audio editor reads loaded overlay bytes before the original ARC")
	var loaded_inspection: Dictionary = editor.call("_inspect_effective_audio", "KSE0001.WAV")
	_check(loaded_inspection.ok and loaded_inspection.source == "overlay" and loaded_inspection.size == loaded_overlay_a.size(), "audio editor validates the loaded overlay header without using original metadata")
	editor.set("_selected_entry", "KSE0001.WAV")
	editor.call("_refresh_details")
	_check(not analyze_button.disabled and details.text.contains("Duration: 0:00.000"), "selected PCM WAV exposes exact header duration and enables explicit timeline analysis")
	_check((editor.get("_timeline_summary") as Dictionary).is_empty(), "audio selection remains header-bounded until timeline analysis is requested")
	editor.call("_on_analyze_timeline_pressed")
	var timeline_summary: Dictionary = editor.get("_timeline_summary")
	_check(
		timeline_summary.ok
		and int(timeline_summary.sample_frames) == 4
		and int(timeline_summary.analyzed_frames) == 4
		and timeline_summary.buckets.size() == 4,
		"Audio Editor produces a bounded PCM timeline summary only on explicit request"
	)
	_check(
		details.text.contains("Timeline summary")
		and details.text.contains("Waveform frames: 4 / 4 (complete)")
		and details.text.contains("Waveform min/max/RMS (4 buckets)"),
		"Audio Editor displays duration and bounded waveform provenance in its details pane"
	)
	var previous_details := details.text
	var previous_preview_stream := AudioStreamWAV.load_from_buffer(loaded_overlay_a)
	preview_player.stream = previous_preview_stream
	var previous_resolver: Object = editor.get("_resolver")
	var previous_root := str(editor.get("_overlay_root"))
	var previous_targets: Dictionary = (editor.get("_overlay_targets") as Dictionary).duplicate(true)
	var previous_session: Dictionary = (editor.get("_session") as Dictionary).duplicate(true)
	var previous_snapshot: Dictionary = previous_resolver.call("get_overlay_snapshot")
	var active_bindings: Dictionary = previous_resolver.call("validate_overlay_archive_bindings", "se.arc")
	var snapshot_record: Dictionary = {}
	for untyped_record in previous_snapshot.manifest.replacements:
		var record: Dictionary = untyped_record
		if str(record.target_archive).to_upper() == "SE.ARC" and str(record.target_entry).to_upper() == "KSE0001.WAV":
			snapshot_record = record
			break
	_check(
		str(previous_snapshot.root) == previous_root
		and previous_snapshot.manifest.replacements.size() == 2
		and previous_targets.size() == 1
		and not previous_targets.has("META.BIN")
		and active_bindings.ok
		and active_bindings.records.size() == 2
		and active_bindings.descriptors.size() == 2
		and active_bindings.descriptors.has("KSE0001.WAV")
		and active_bindings.descriptors.has("META.BIN")
		and str(active_bindings.archive_sha256) == source_sha
		and not snapshot_record.is_empty()
		and str(snapshot_record.replacement_sha256) == str(previous_targets["KSE0001.WAV"].replacement_sha256),
		"audio editor derives audio labels from an all-record batch-bound resolver snapshot"
	)
	_check(
		previous_resolver.call("resolve", "se.arc", "KSE0001.WAV") == active_bindings.descriptors["KSE0001.WAV"],
		"audio editor normal resolve matches the independently batch-validated audio descriptor"
	)
	var manifest_path := ProjectSettings.globalize_path(initial_overlay_root).simplify_path().path_join("manifest.json")
	var valid_manifest_text := FileAccess.get_file_as_string(manifest_path)
	var wrong_base_manifest: Dictionary = JSON.parse_string(valid_manifest_text)
	for untyped_record in wrong_base_manifest.replacements:
		var record: Dictionary = untyped_record
		if str(record.target_archive).to_upper() == "SE.ARC" and str(record.target_entry).to_upper() == "META.BIN":
			record.base_archive_sha256 = "0".repeat(64)
	_write_text(manifest_path, JSON.stringify(wrong_base_manifest, "\t") + "\n")
	_check(overlay_package.load_manifest(initial_overlay_root).ok, "wrong-base Hot Reload fixture remains structurally valid")
	editor.call("_on_hot_reload_overlay_pressed")
	var rejected_audio: Dictionary = editor.call("_read_effective_audio", "KSE0001.WAV")
	var rejected_snapshot: Dictionary = previous_resolver.call("get_overlay_snapshot")
	_check(
		status.text.contains("Overlay Hot Reload failed")
		and status.text.contains("base ARC hash does not match"),
		"audio editor rejects a wrong-base non-audio record in the current archive"
	)
	_check(
		editor.get("_resolver") == previous_resolver
		and str(editor.get("_overlay_root")) == previous_root
		and editor.get("_overlay_targets") == previous_targets
		and rejected_snapshot == previous_snapshot,
		"failed audio Hot Reload preserves the previous resolver, root, targets, and snapshot"
	)
	_check(
		rejected_audio.ok
		and rejected_audio.source == "overlay"
		and rejected_audio.data == loaded_overlay_a
		and details.text == previous_details
		and preview_player.stream == previous_preview_stream
		and first_entry.get_text(2) == "Overlay",
		"failed audio Hot Reload preserves effective bytes, details, preview stream, and source label"
	)
	_check(FileAccess.get_sha256(archive_path) == source_sha, "rejected audio Hot Reload leaves the source ARC unchanged")
	_write_text(manifest_path, valid_manifest_text)

	var changed_archive_bytes := pristine_archive_bytes.duplicate()
	var editor_reader: KakyuArcReader = editor.get("_reader")
	var unchanged_target_offset := int(editor_reader.get_entry("KSE0002.WAV").offset)
	changed_archive_bytes[unchanged_target_offset] = changed_archive_bytes[unchanged_target_offset] ^ 0x01
	_write_bytes(archive_path, changed_archive_bytes)
	var changed_archive_sha := FileAccess.get_sha256(archive_path)
	var rebound_manifest: Dictionary = JSON.parse_string(valid_manifest_text)
	for untyped_record in rebound_manifest.replacements:
		var record: Dictionary = untyped_record
		if str(record.target_archive).to_upper() == "SE.ARC":
			record.base_archive_sha256 = changed_archive_sha
	_write_text(manifest_path, JSON.stringify(rebound_manifest, "\t") + "\n")
	_check(overlay_package.load_manifest(initial_overlay_root).ok, "changed-source audio Hot Reload fixture remains structurally valid and rebound")
	editor.call("_on_hot_reload_overlay_pressed")
	_check(
		status.text.contains("Overlay Hot Reload failed")
		and status.text.contains("open audio ARC changed"),
		"audio editor rejects a candidate rebound to source bytes changed after open"
	)
	_check(
		editor.get("_resolver") == previous_resolver
		and str(editor.get("_overlay_root")) == previous_root
		and editor.get("_overlay_targets") == previous_targets
		and previous_resolver.call("get_overlay_snapshot") == previous_snapshot
		and details.text == previous_details
		and preview_player.stream == previous_preview_stream
		and first_entry.get_text(2) == "Overlay"
		and editor.get("_session") == previous_session
		and str(editor.get("_archive_sha256")) == source_sha,
		"changed-source audio rejection preserves resolver, overlay metadata, details, preview, selection label, pending state, and pinned SHA"
	)
	_write_bytes(archive_path, pristine_archive_bytes)
	_write_text(manifest_path, valid_manifest_text)
	_check(FileAccess.get_sha256(archive_path) == source_sha, "changed-source audio fixture restores its byte-identical ARC")
	_check(editor_reader.open(archive_path), "audio editor reader reopens the restored ARC")
	_check(previous_resolver.call("register_original_archive", "se.arc", archive_path), "audio active resolver reopens the restored ARC")
	_check(overlay_source.open(archive_path), "audio staging reader reopens the restored ARC")
	var restored_audio: Dictionary = editor.call("_read_effective_audio", "KSE0001.WAV")
	_check(restored_audio.ok and restored_audio.data == loaded_overlay_a, "audio overlay resolution resumes after restoring and reopening the source ARC")

	var extracted_overlay: Dictionary = editor.call("_extract_effective_audio", "KSE0001.WAV", overlay_extract_path)
	_check(extracted_overlay.ok and FileAccess.get_file_as_bytes(overlay_extract_path) == loaded_overlay_a, "audio editor extracts the effective overlay bytes to a new file")
	var reloaded_overlay := overlay_package.stage_replacement(
		initial_overlay_root,
		overlay_source,
		"se.arc",
		"KSE0001.WAV",
		reloaded_overlay_a,
		"remake_only",
		"not_applicable"
	)
	_check(reloaded_overlay.ok, "audio Hot Reload fixture atomically updates its replacement")
	editor.call("_on_hot_reload_overlay_pressed")
	var reloaded_audio: Dictionary = editor.call("_read_effective_audio", "KSE0001.WAV")
	_check(reloaded_audio.ok and reloaded_audio.data == reloaded_overlay_a, "audio editor Hot Reload reopens changed overlay bytes")

	editor.set("_selected_entry", "KSE0001.WAV")
	editor.call("_refresh_details")
	var convert_button: Button = editor.get_node("Margin/Layout/SessionActions/ConvertWav")
	_check(
		not convert_button.disabled
		and details.text.contains("Original SE PCM16 mono 22050 Hz")
		and details.text.contains("Explicit WAV conversion only"),
		"selected SE WAV exposes its explicit deterministic conversion preset"
	)
	editor.call("_on_convert_wav_pressed")
	_check(
		str((editor.get("_conversion_request") as Dictionary).target_entry) == "KSE0001.WAV",
		"conversion action binds the visible target before opening a source chooser"
	)
	var conversion_source_sha := FileAccess.get_sha256(conversion_source_path)
	editor.call("_on_conversion_source_selected", conversion_source_path)
	_check(
		str((editor.get("_conversion_request") as Dictionary).source_sha256) == conversion_source_sha,
		"conversion source is fingerprint-bound before an output path is accepted"
	)
	var changed_conversion_source := conversion_source.duplicate()
	changed_conversion_source[changed_conversion_source.size() - 1] ^= 0x01
	_write_bytes(conversion_source_path, changed_conversion_source)
	var changed_conversion_output_path := TEST_ROOT + "/changed-source-converted.wav"
	editor.call("_on_conversion_output_selected", changed_conversion_output_path)
	_check(
		not FileAccess.file_exists(changed_conversion_output_path)
		and (editor.get("_session") as Dictionary).is_empty()
		and status.text.contains("source changed after selection"),
		"changed conversion input fails before output publication or session staging"
	)
	_write_bytes(conversion_source_path, conversion_source)
	_check(FileAccess.get_sha256(conversion_source_path) == conversion_source_sha, "conversion source mutation fixture restores its exact bytes")
	editor.call("_on_convert_wav_pressed")
	editor.call("_on_conversion_source_selected", conversion_source_path)
	editor.call("_on_conversion_output_selected", conversion_output_path)
	var converted_session: Dictionary = editor.get("_session")
	var converted_inspection: Dictionary = editor.call("_inspect_audio_file", "KSE0001.WAV", conversion_output_path)
	_check(
		converted_inspection.ok
		and int(converted_inspection.validation.channels) == 1
		and int(converted_inspection.validation.sample_rate) == 22050
		and int(converted_inspection.validation.bit_depth) == 16,
		"Audio Editor publishes a reopened target-profile PCM WAV"
	)
	_check(
		converted_session.has("KSE0001.WAV")
		and converted_session["KSE0001.WAV"].has("conversion")
		and str(converted_session["KSE0001.WAV"].conversion.preset_id) == "original_se_pcm16_mono_22050"
		and str(converted_session["KSE0001.WAV"].conversion.input_sha256) == conversion_source_sha
		and str(converted_session["KSE0001.WAV"].conversion.output_sha256) == FileAccess.get_sha256(conversion_output_path),
		"successful explicit conversion stages path/hash/provenance metadata instead of resident payload bytes"
	)
	_check(
		str(editor.call("_session_declared_compatibility")) == "original_engine_compatible",
		"an all-SE-preset conversion session retains its verified compatibility declaration"
	)
	_check(
		FileAccess.get_sha256(conversion_source_path) == conversion_source_sha
		and FileAccess.get_sha256(archive_path) == source_sha
		and not _has_temp_residue(ProjectSettings.globalize_path(TEST_ROOT)),
		"conversion leaves its input and source ARC unchanged with no temporary residue"
	)
	editor.call("_on_clear_session_confirmed")

	editor.set("_selected_entry", "KSE0001.WAV")
	editor.call("_on_replacement_file_selected", replacement_a_path)
	editor.set("_selected_entry", "KSE0002.WAV")
	editor.call("_on_replacement_file_selected", replacement_b_path)
	var session: Dictionary = editor.get("_session")
	_check(session.size() == 2, "audio editor session holds two replacement targets")
	_check(not session["KSE0001.WAV"].has("data") and not session["KSE0002.WAV"].has("data"), "idle session retains paths and hashes instead of audio bytes")
	var pending_extract: Dictionary = editor.call(
		"_extract_effective_audio",
		"KSE0001.WAV",
		pending_extract_path
	)
	_check(
		pending_extract.ok
		and str(pending_extract.sha256) == FileAccess.get_sha256(replacement_a_path)
		and FileAccess.get_file_as_bytes(pending_extract_path) == replacement_a,
		"audio editor atomically extracts a hash-bound pending replacement"
	)
	editor.call("_on_clear_overlay_pressed")
	_check(editor.get("_overlay_root") == ProjectSettings.globalize_path(initial_overlay_root).simplify_path() and str(editor.get_node("Margin/Layout/StatusLabel").text).contains("pending"), "audio editor blocks overlay changes while a pending session depends on the read layer")
	var session_tree: Tree = editor.get_node("Margin/Layout/Split/Right/SessionTree")
	_check(session_tree.get_root().get_child_count() == 2, "pending session tree lists both targets")
	filter_edit.text = "0001"
	editor.call("_on_filter_changed", filter_edit.text)
	var hidden_session_item := session_tree.get_root().get_first_child().get_next()
	hidden_session_item.select(0)
	editor.call("_on_session_entry_selected")
	_check(
		filter_edit.text.is_empty()
		and editor.get("_selected_entry") == "KSE0002.WAV"
		and entry_tree.get_root().get_child_count() == 3,
		"selecting a hidden pending audio entry clears the filter and restores its source row"
	)

	var collected: Dictionary = editor.call("_collect_session_replacement_paths")
	_check(
		collected.ok
		and collected.paths.size() == 2
		and collected.bound_files.size() == 2
		and str(collected.bound_files["KSE0001.WAV"].sha256) == FileAccess.get_sha256(replacement_a_path),
		"session revalidates and SHA-binds both replacement paths for streaming save"
	)
	_check(collected.paths["KSE0001.WAV"] is String, "save collection contains paths rather than audio payload bytes")
	_write_bytes(replacement_b_path, _pcm_wave(9, 10))
	var changed: Dictionary = editor.call("_collect_session_replacement_paths")
	_check(not changed.ok and str(changed.error).contains("changed after it was staged"), "save rejects a replacement file changed after staging")
	_write_bytes(replacement_b_path, replacement_b)

	editor.call("_on_overlay_directory_selected", overlay_root)
	var loaded_overlay := overlay_package.load_manifest(overlay_root)
	_check(loaded_overlay.ok and loaded_overlay.manifest.replacements.size() == 2, "one editor save publishes both overlay targets")
	_check(editor.get("_session").size() == 2, "successful save preserves the authored session")
	_check(editor.get("_overlay_root") == ProjectSettings.globalize_path(overlay_root).simplify_path(), "successful audio save attaches the published overlay read layer")

	var export_changed_source := pristine_archive_bytes.duplicate()
	export_changed_source[export_changed_source.size() - 1] ^= 0x01
	_write_bytes(archive_path, export_changed_source)
	editor.call("_on_export_arc_path_selected", changed_source_output_arc_path)
	_check(
		not FileAccess.file_exists(changed_source_output_arc_path)
		and (editor.get_node("Margin/Layout/StatusLabel") as Label).text.contains("Source ARC changed after it was opened"),
		"audio ARC export rejects source bytes changed after the editor captured its open-time fingerprint"
	)
	_write_bytes(archive_path, pristine_archive_bytes)
	_check(FileAccess.get_sha256(archive_path) == source_sha, "audio export source-mutation fixture restores the source ARC")
	editor.call("_on_export_arc_path_selected", output_arc_path)
	var rebuilt := ArcReaderScript.new()
	_check(rebuilt.open(output_arc_path), "batch editor ARC export reopens")
	var audio_provenance := ArcProvenanceScript.new().load_sidecar(output_arc_path)
	_check(audio_provenance.get("ok", false) and audio_provenance.provenance.declared_compatibility == "remake_only", "audio ARC export publishes portable remake-only provenance")
	_check(rebuilt.read_entry("KSE0001.WAV") == replacement_a, "batch ARC export contains first replacement")
	_check(rebuilt.read_entry("KSE0002.WAV") == replacement_b, "batch ARC export contains second replacement")
	rebuilt.close()
	editor.call("_on_clear_session_confirmed")
	var saved_overlay_audio: Dictionary = editor.call("_read_effective_audio", "KSE0001.WAV")
	_check(saved_overlay_audio.ok and saved_overlay_audio.source == "overlay" and saved_overlay_audio.data == replacement_a, "removing pending audio reveals the just-saved overlay bytes")

	# ME-06: multi-select batch extraction and audio report export, using the
	# just-saved overlay (KSE0001.WAV) and the untouched original (MAKI.WAV)
	# while the session is empty.
	editor.call("_on_filter_changed", "")
	var editor_entry_items: Dictionary = editor.get("_entry_items")
	var pair_first_item: TreeItem = editor_entry_items["KSE0001.WAV"]
	var pair_second_item: TreeItem = editor_entry_items["MAKI.WAV"]
	pair_first_item.select(0)
	pair_second_item.select(0)
	editor.call("_on_entry_multi_selected", pair_second_item, 0, true)
	_check(
		(editor.call("_selected_entries") as Array) == ["KSE0001.WAV", "MAKI.WAV"],
		"audio editor multi-select reports both chosen rows in tree order"
	)
	editor.call("_on_extract_selected_folder_pressed")
	editor.call("_on_extract_directory_selected", batch_pair_output_dir)
	_check(
		extraction_progress_row.visible and cancel_extraction_button.visible and editor.get("_extraction_job") != null,
		"audio editor shows the extraction progress row and cancel button while a folder batch job runs"
	)
	editor.call("_run_extraction_to_end")
	_check(
		not extraction_progress_row.visible and editor.get("_extraction_job") == null,
		"audio editor hides the extraction progress row once _run_extraction_to_end finishes the folder batch job"
	)
	var batch_pair_absolute := ProjectSettings.globalize_path(batch_pair_output_dir).simplify_path()
	_check(
		status.text.begins_with("Extracted 2 audio entries (1 overlay, 0 pending, 1 original,")
		and FileAccess.get_file_as_bytes(batch_pair_absolute.path_join("KSE0001.WAV")) == replacement_a
		and FileAccess.get_file_as_bytes(batch_pair_absolute.path_join("MAKI.WAV")) == original_a,
		"multi-selected batch extraction writes the effective overlay and original bytes with correct status counts"
	)

	_write_bytes(second_pending_replacement_path, second_pending_replacement)
	editor.set("_selected_entry", "KSE0002.WAV")
	editor.call("_on_replacement_file_selected", second_pending_replacement_path)
	_check((editor.get("_session") as Dictionary).size() == 1, "audio editor session restages a pending replacement over a saved overlay entry")
	var trio_pending_item: TreeItem = editor_entry_items["KSE0002.WAV"]
	trio_pending_item.select(0)
	editor.call("_on_entry_multi_selected", trio_pending_item, 0, true)
	_check(
		(editor.call("_selected_entries") as Array) == ["KSE0001.WAV", "KSE0002.WAV", "MAKI.WAV"],
		"audio editor multi-select adds the newly pending row to the earlier selection"
	)
	editor.call("_on_extract_selected_folder_pressed")
	editor.call("_on_extract_directory_selected", batch_trio_output_dir)
	editor.call("_run_extraction_to_end")
	var batch_trio_absolute := ProjectSettings.globalize_path(batch_trio_output_dir).simplify_path()
	var batch_trio_pending_path := batch_trio_absolute.path_join("KSE0002.WAV")
	_check(
		status.text.begins_with("Extracted 3 audio entries (1 overlay, 1 pending, 1 original,")
		and FileAccess.get_file_as_bytes(batch_trio_pending_path) == second_pending_replacement,
		"a pending session entry in the batch is written from its session file"
	)
	editor.call("_on_extract_selected_folder_pressed")
	editor.call("_on_extract_directory_selected", batch_trio_output_dir)
	editor.call("_run_extraction_to_end")
	_check(
		status.text.contains("already exists")
		and FileAccess.get_file_as_bytes(batch_trio_pending_path) == second_pending_replacement,
		"a second batch run into the same folder is refused with nothing new written"
	)

	filter_edit.text = "0001"
	editor.call("_on_filter_changed", filter_edit.text)
	_check(entry_tree.get_root().get_child_count() == 1, "audio editor batch-extraction fixture narrows the visible tree before the whole-archive batch")
	editor.call("_on_extract_archive_pressed")
	editor.call("_on_extract_directory_selected", batch_archive_output_dir)
	editor.call("_run_extraction_to_end")
	var batch_archive_absolute := ProjectSettings.globalize_path(batch_archive_output_dir).simplify_path()
	_check(
		FileAccess.file_exists(batch_archive_absolute.path_join("KSE0001.WAV"))
		and FileAccess.file_exists(batch_archive_absolute.path_join("KSE0002.WAV"))
		and FileAccess.file_exists(batch_archive_absolute.path_join("MAKI.WAV"))
		and not FileAccess.file_exists(batch_archive_absolute.path_join("META.BIN")),
		"Extract archive writes every audio entry regardless of the active filter, and never a non-audio entry"
	)

	# A running extraction job refuses a second extraction, then finishes
	# normally once run to the end.
	var guard_audio_batch_dir := TEST_ROOT + "/guard-audio-batch"
	editor.call("_on_extract_archive_pressed")
	editor.call("_on_extract_directory_selected", guard_audio_batch_dir)
	_check(editor.get("_extraction_job") != null, "audio editor fixture starts a running job for the concurrency guard check")
	var guard_audio_second_target := TEST_ROOT + "/guard-audio-batch-refused"
	editor.call("_on_extract_archive_pressed")
	editor.call("_on_extract_directory_selected", guard_audio_second_target)
	_check(
		status.text == "An extraction is running; cancel it or wait."
		and not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(guard_audio_second_target).simplify_path()),
		"audio editor refuses a second extraction while one is running and writes nothing for it"
	)
	var guard_reader_path := str(editor.get("_reader").archive_path)
	editor.call("_open_archive", guard_reader_path)
	_check(
		status.text == "An extraction is running; cancel it or wait."
		and editor.get("_extraction_job") != null
		and str(editor.get("_reader").archive_path) == guard_reader_path,
		"audio editor refuses to reopen an archive while an extraction holds its resolver"
	)
	var guard_overlay: Dictionary = editor.call("_configure_loaded_overlay", TEST_ROOT + "/no-such-overlay")
	_check(
		not guard_overlay.get("ok", false)
		and str(guard_overlay.get("error", "")) == "An extraction is running; cancel it or wait.",
		"audio editor refuses to replace the overlay read layer while an extraction runs"
	)
	editor.call("_run_extraction_to_end")
	_check(
		editor.get("_extraction_job") == null and not extraction_progress_row.visible,
		"audio editor finishes the guarded job normally once run to the end"
	)

	# Cancelling a running job removes the file it had already written,
	# reports the cancellation status, and hides the progress row.
	var cancel_audio_batch_dir := TEST_ROOT + "/cancel-audio-batch"
	editor.call("_on_extract_archive_pressed")
	editor.call("_on_extract_directory_selected", cancel_audio_batch_dir)
	var cancel_audio_job = editor.get("_extraction_job")
	_check(cancel_audio_job != null, "audio editor fixture starts a running job for the cancellation check")
	cancel_audio_job.call("step", 0)
	var cancel_audio_progress: Dictionary = cancel_audio_job.call("progress")
	_check(int(cancel_audio_progress.done) == 1, "audio editor stepped job fixture writes one entry before cancellation")
	var cancel_audio_first_entry := str(cancel_audio_progress.entry)
	editor.call("_on_cancel_extraction_pressed")
	var cancel_audio_absolute := ProjectSettings.globalize_path(cancel_audio_batch_dir).simplify_path()
	_check(
		status.text == "Extraction cancelled; removed 1 file(s)."
		and not FileAccess.file_exists(cancel_audio_absolute.path_join(cancel_audio_first_entry))
		and not extraction_progress_row.visible
		and editor.get("_extraction_job") == null,
		"audio editor cancellation removes the written file, reports the cancellation status, and hides the progress row"
	)

	filter_edit.clear()
	editor.call("_on_filter_changed", "")
	_check((editor.call("_selected_entries") as Array).is_empty(), "audio editor filter-cleared tree carries no selection before the no-selection report export")
	(editor.get_node("ExtractDirectoryDialog") as FileDialog).hide()
	editor.call("_on_export_report_pressed")
	editor.call("_on_report_path_selected", audio_report_output_path)
	var audio_report := AudioMetadataReportScript.read_path(audio_report_output_path)
	_check(
		audio_report.get("ok", false) and int(audio_report.report.summary.entry_count) == 3,
		"Export audio report with no selection covers every audio entry and read_path accepts it"
	)

	get_window().size = Vector2i(1024, 640)
	await get_tree().process_frame
	_check(_controls_fit(editor), "audio editor batch/report controls still fit the shared minimum desktop size")
	_check(FileAccess.get_sha256(archive_path) == source_sha, "batch extraction and report export never change the source ARC")
	editor.call("_on_clear_session_confirmed")

	editor.call("_on_clear_overlay_pressed")
	var restored_original: Dictionary = editor.call("_read_effective_audio", "KSE0001.WAV")
	_check(restored_original.ok and restored_original.source == "original_arc" and restored_original.data == original_a, "clearing the audio overlay returns resolution to original ARC bytes")
	_check(FileAccess.get_sha256(archive_path) == source_sha, "audio editor session never changes the source ARC")
	overlay_source.close()

	editor.queue_free()
	await get_tree().process_frame
	await _test_reference_selection_producer(archive_path, mes_archive_path)
	await _test_startup_selection(archive_path, mes_archive_path)
	_cleanup()
	get_tree().quit(1 if _failed else 0)


func _test_reference_selection_producer(archive_path: String, mes_archive_path: String) -> void:
	var absolute_root := ProjectSettings.globalize_path(TEST_ROOT)
	var workspace_root := absolute_root.path_join("selection_workspace")
	var archive_sha := FileAccess.get_sha256(archive_path)
	var mes_sha := FileAccess.get_sha256(mes_archive_path)
	var archives := [
		{"archive": "mes.arc", "sha256": mes_sha, "required": true},
		{"archive": "se.arc", "sha256": archive_sha, "required": false},
	]
	var project := {
		"schema": ContentCoreVersionScript.CONTENT_PROJECT_SCHEMA, "project_id": "audio-editor.selection.test",
		"project_version": "0.1.0", "display_name": "Audio Editor Selection Test", "project_revision": 1,
		"content_core": {"minimum_version": ContentCoreVersionScript.CORE_VERSION, "maximum_exclusive": "1.0.0"},
		"source_content_set": {
			"profile_id": "synthetic-test",
			"fingerprint_sha256": ContentProjectScript.compute_content_set_fingerprint(archives),
			"archives": archives,
		},
		"target_archives": ["mes.arc", "se.arc"], "compatibility_objective": "mixed", "dependencies": [],
		"event_player": {"catalog_id": "kakyu-original-events", "presets": []}, "overlay_manifest": "manifest.json",
	}
	var workspace := ContentWorkspaceScript.new()
	var created := workspace.create(workspace_root, absolute_root, project)
	_check(created.get("ok", false), "audio editor selection fixture creates a named workspace")
	workspace.close()

	var selection_editor: Control = AudioEditorScene.instantiate()
	add_child(selection_editor)
	await get_tree().process_frame
	selection_editor.call("_apply_startup_arguments", PackedStringArray([
		"--content-set", absolute_root, "--workspace", workspace_root,
	]))
	var original_window_size := get_window().size
	get_window().size = Vector2i(1024, 640)
	await get_tree().process_frame
	_check(_controls_fit(selection_editor), "audio editor reference-selection controls fit the shared minimum desktop size")
	get_window().size = original_window_size
	await get_tree().process_frame

	var reloaded_index: Dictionary = selection_editor.call("_load_mes_reference_index", mes_archive_path)
	_check(reloaded_index.get("ok", false), "audio editor selection fixture reloads the MES reference index in the named workspace")
	selection_editor.set("_selected_entry", "MAKI.WAV")
	selection_editor.call("_refresh_details")

	var launch: Dictionary = selection_editor.call("_build_reference_launch")
	_check(
		launch.get("ok", false) and (launch.arguments as PackedStringArray).has("--selection"),
		"_build_reference_launch returns arguments naming a --selection handoff"
	)
	var contract := ContentSelectionScript.new()
	var read_back := contract.read_path(str(launch.get("path", "")))
	var mes_reader := ArcReaderScript.new()
	mes_reader.open(mes_archive_path)
	var expected_entry_sha := mes_reader.get_entry_fingerprint("EVENTD01.MES")
	mes_reader.close()
	_check(
		read_back.get("ok", false)
		and str((read_back.document as Dictionary).selection.entry) == "EVENTD01.MES"
		and str((read_back.document as Dictionary).selection.source_entry_sha256) == expected_entry_sha
		and str((read_back.document as Dictionary).producer.app) == "audio_arc_editor",
		"the handoff file reads back naming EVENTD01.MES with the right source hash and producer"
	)

	selection_editor.queue_free()
	await get_tree().process_frame


func _test_startup_selection(archive_path: String, mes_archive_path: String) -> void:
	var absolute_root := ProjectSettings.globalize_path(TEST_ROOT)
	var workspace_root := absolute_root.path_join("startup_selection_workspace")
	var archive_sha := FileAccess.get_sha256(archive_path)
	var mes_sha := FileAccess.get_sha256(mes_archive_path)
	var archives := [
		{"archive": "mes.arc", "sha256": mes_sha, "required": false},
		{"archive": "se.arc", "sha256": archive_sha, "required": true},
	]
	var project := {
		"schema": ContentCoreVersionScript.CONTENT_PROJECT_SCHEMA, "project_id": "audio-editor.startup-selection.test",
		"project_version": "0.1.0", "display_name": "Audio Editor Startup Selection Test", "project_revision": 1,
		"content_core": {"minimum_version": ContentCoreVersionScript.CORE_VERSION, "maximum_exclusive": "1.0.0"},
		"source_content_set": {
			"profile_id": "synthetic-test",
			"fingerprint_sha256": ContentProjectScript.compute_content_set_fingerprint(archives),
			"archives": archives,
		},
		"target_archives": ["mes.arc", "se.arc"], "compatibility_objective": "mixed", "dependencies": [],
		"event_player": {"catalog_id": "kakyu-original-events", "presets": []}, "overlay_manifest": "manifest.json",
	}
	var workspace := ContentWorkspaceScript.new()
	var created := workspace.create(workspace_root, absolute_root, project)
	_check(created.get("ok", false), "audio editor startup-selection fixture creates a named workspace")
	var snapshot := workspace.get_snapshot()
	workspace.close()

	var reader := ArcReaderScript.new()
	reader.open(archive_path)
	var entry_sha := reader.get_entry_fingerprint("KSE0001.WAV")
	var second_entry_sha := reader.get_entry_fingerprint("KSE0002.WAV")
	reader.close()
	var mes_reader := ArcReaderScript.new()
	mes_reader.open(mes_archive_path)
	var foreign_entry_sha := mes_reader.get_entry_fingerprint("NOT_AUDIO.MES")
	mes_reader.close()

	var document := ContentSelectionScript.new().build(
		snapshot,
		{
			"archive": "se.arc", "entry": "KSE0001.WAV", "source_entry_sha256": entry_sha,
			"catalog_id": "", "event_id": "", "preset_id": "",
		},
		"arc_browser"
	)
	_check(document.get("ok", false), "audio editor startup-selection fixture builds a content selection for KSE0001.WAV")
	var selection_path := absolute_root.path_join("startup-selection.json")
	_write_text(selection_path, JSON.stringify(document, "", true, true) + "\n")

	var selection_editor: Control = AudioEditorScene.instantiate()
	add_child(selection_editor)
	await get_tree().process_frame
	selection_editor.call("_apply_startup_arguments", PackedStringArray([
		"--content-set", absolute_root, "--workspace", workspace_root, "--selection", selection_path,
	]))
	_check(
		str(selection_editor.get("_selected_entry")) == "KSE0001.WAV"
		and (selection_editor.get("status_label") as Label).text == "Selection from arc_browser: KSE0001.WAV"
		and str((selection_editor.get("details") as RichTextLabel).text).contains("KSE0001.WAV"),
		"Audio editor startup with a selection opens se.arc, selects KSE0001.WAV, and shows its normal details"
	)
	selection_editor.queue_free()
	await get_tree().process_frame

	var bad_last_character := "0" if not second_entry_sha.ends_with("0") else "1"
	var wrong_hash_document := ContentSelectionScript.new().build(
		snapshot,
		{
			"archive": "se.arc", "entry": "KSE0002.WAV",
			"source_entry_sha256": second_entry_sha.substr(0, 63) + bad_last_character,
			"catalog_id": "", "event_id": "", "preset_id": "",
		},
		"arc_browser"
	)
	_check(wrong_hash_document.get("ok", false), "audio editor startup-selection fixture builds a wrong-hash content selection")
	var wrong_hash_path := absolute_root.path_join("startup-wrong-hash-selection.json")
	_write_text(wrong_hash_path, JSON.stringify(wrong_hash_document, "", true, true) + "\n")

	var wrong_hash_editor: Control = AudioEditorScene.instantiate()
	add_child(wrong_hash_editor)
	await get_tree().process_frame
	wrong_hash_editor.call("_apply_startup_arguments", PackedStringArray([
		"--content-set", absolute_root, "--workspace", workspace_root, "--selection", wrong_hash_path,
	]))
	_check(
		str((wrong_hash_editor.get("status_label") as Label).text).begins_with("Selection rejected:"),
		"Audio editor rejects a wrong-hash selection with a status error"
	)
	wrong_hash_editor.queue_free()
	await get_tree().process_frame

	var foreign_document := ContentSelectionScript.new().build(
		snapshot,
		{
			"archive": "mes.arc", "entry": "NOT_AUDIO.MES", "source_entry_sha256": foreign_entry_sha,
			"catalog_id": "", "event_id": "", "preset_id": "",
		},
		"arc_browser"
	)
	_check(foreign_document.get("ok", false), "audio editor startup-selection fixture builds a foreign-archive content selection")
	var foreign_path := absolute_root.path_join("startup-foreign-selection.json")
	_write_text(foreign_path, JSON.stringify(foreign_document, "", true, true) + "\n")

	var foreign_editor: Control = AudioEditorScene.instantiate()
	add_child(foreign_editor)
	await get_tree().process_frame
	foreign_editor.call("_apply_startup_arguments", PackedStringArray([
		"--content-set", absolute_root, "--workspace", workspace_root, "--selection", foreign_path,
	]))
	_check(
		str((foreign_editor.get("status_label") as Label).text) == "Selection rejected: mes.arc does not open in the Audio ARC Editor."
		and str((foreign_editor.get("archive_label") as Label).text).replace("\\", "/").ends_with("se.arc"),
		"Audio editor rejects a foreign-archive selection with a status error and opens the default archive"
	)
	foreign_editor.queue_free()
	await get_tree().process_frame


func _controls_fit(editor: Control) -> bool:
	var margin: Control = editor.get_node("Margin")
	var layout: Control = editor.get_node("Margin/Layout")
	var editor_rect := Rect2(Vector2.ZERO, editor.size)
	return editor_rect.encloses(margin.get_rect()) and margin.get_rect().size.y >= layout.get_combined_minimum_size().y


func _pcm_wave(marker: int, sample_bytes: int) -> PackedByteArray:
	var data := PackedByteArray()
	data.resize(44 + sample_bytes)
	data.fill(0)
	SyntheticArc.write_ascii(data, 0, "RIFF")
	data.encode_u32(4, 36 + sample_bytes)
	SyntheticArc.write_ascii(data, 8, "WAVE")
	SyntheticArc.write_ascii(data, 12, "fmt ")
	data.encode_u32(16, 16)
	data.encode_u16(20, 1)
	data.encode_u16(22, 1)
	data.encode_u32(24, 22050)
	data.encode_u32(28, 44100)
	data.encode_u16(32, 2)
	data.encode_u16(34, 16)
	SyntheticArc.write_ascii(data, 36, "data")
	data.encode_u32(40, sample_bytes)
	for index in range(sample_bytes):
		data[44 + index] = marker
	return data


func _pcm16_wave(samples: PackedInt32Array, channels: int, sample_rate: int) -> PackedByteArray:
	var data_bytes := samples.size() * 2
	var data := PackedByteArray()
	data.resize(44 + data_bytes)
	data.fill(0)
	SyntheticArc.write_ascii(data, 0, "RIFF")
	data.encode_u32(4, 36 + data_bytes)
	SyntheticArc.write_ascii(data, 8, "WAVE")
	SyntheticArc.write_ascii(data, 12, "fmt ")
	data.encode_u32(16, 16)
	data.encode_u16(20, 1)
	data.encode_u16(22, channels)
	data.encode_u32(24, sample_rate)
	data.encode_u32(28, sample_rate * channels * 2)
	data.encode_u16(32, channels * 2)
	data.encode_u16(34, 16)
	SyntheticArc.write_ascii(data, 36, "data")
	data.encode_u32(40, data_bytes)
	for index in range(samples.size()):
		data.encode_s16(44 + index * 2, samples[index])
	return data


func _has_temp_residue(path: String) -> bool:
	var directory := DirAccess.open(path)
	if directory == null:
		return false
	for filename in directory.get_files():
		if filename.contains(".tmp-"):
			return true
	return false


func _mes_with_bgm_reference(selector: int) -> PackedByteArray:
	var code := PackedByteArray([0x09, 0x01, 0x00])
	if selector < 0x80:
		code.append(selector)
	else:
		code.append(0xF1)
		var literal_offset := code.size()
		code.resize(literal_offset + 2)
		code.encode_u16(literal_offset, selector)
	code.append_array(PackedByteArray([0xFF, 0x00, 0x1D, 0x02, 0x17, 0xFF, 0x00, 0x00]))
	return _mes_payload(code)


func _mes_without_bgm_reference() -> PackedByteArray:
	return _mes_payload(PackedByteArray([0x09, 0x01, 0x00, 0x2A, 0xFF, 0x00, 0x1D, 0x02, 0x27, 0xFF, 0x00, 0x00]))


func _mes_payload(code: PackedByteArray) -> PackedByteArray:
	var payload := PackedByteArray()
	SyntheticArc.append_u32(payload, 1)
	SyntheticArc.append_u32(payload, 0)
	payload.append_array(code)
	return payload


func _write_bytes(path: String, data: PackedByteArray) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(data)
	file.close()


func _write_text(path: String, value: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(value)
	file.close()


func _cleanup() -> void:
	_remove_tree(ProjectSettings.globalize_path(TEST_ROOT))
