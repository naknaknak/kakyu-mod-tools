extends Control

const ArcReaderScript := preload("res://content_core/arc_reader.gd")
const ArcProvenanceScript := preload("res://content_core/arc_provenance.gd")
const AudioValidatorScript := preload("res://content_core/audio_entry_validator.gd")
const AudioConversionScript := preload("res://content_core/audio_conversion_presets.gd")
const AudioTimelineSummaryScript := preload("res://content_core/audio_timeline_summary.gd")
const MesContainerScript := preload("res://content_core/mes_container.gd")
const MesAudioReferenceIndexScript := preload("res://content_core/mes_audio_reference_index.gd")
const OverlayPackageScript := preload("res://content_core/overlay_package.gd")
const ContentResolverScript := preload("res://content_core/content_resolver.gd")
const ContentLaunchContextScript := preload("res://content_core/content_launch_context.gd")
const ContentSelectionScript := preload("res://content_core/content_selection.gd")
const SelectionHandoffScript := preload("res://tools/content_suite/selection_handoff.gd")
const EventCatalogScript := preload("res://content_core/event_catalog.gd")
const EVENT_CATALOG_PATH := "res://config/event_catalog/original_events_v1.json"
const ToolWindowProfileScript := preload("res://tools/content_suite/tool_window_profile.gd")
const ToolPathHistoryScript := preload("res://tools/content_suite/tool_path_history.gd")
const ArcBatchExtractionScript := preload("res://tools/content_suite/arc_batch_extraction.gd")
const AudioMetadataReportScript := preload("res://tools/content_suite/audio_metadata_report.gd")
const HEADER_READ_SIZE := 64 * 1024

@onready var archive_label: Label = %ArchiveLabel
@onready var filter_edit: LineEdit = %FilterEdit
@onready var entry_tree: Tree = %EntryTree
@onready var session_tree: Tree = %SessionTree
@onready var session_label: Label = %SessionLabel
@onready var details: RichTextLabel = %Details
@onready var mes_reference_select: OptionButton = %MesReferenceSelect
@onready var open_reference_event_player_button: Button = %OpenReferenceEventPlayer
@onready var analyze_button: Button = %AnalyzeTimeline
@onready var convert_wav_button: Button = %ConvertWav
@onready var load_mes_references_button: Button = %LoadMesReferences
@onready var status_label: Label = %StatusLabel
@onready var extraction_progress_row: Control = %ExtractionProgressRow
@onready var extraction_progress: ProgressBar = %ExtractionProgress
@onready var cancel_extraction_button: Button = %CancelExtraction
@onready var open_dialog: FileDialog = %OpenDialog
@onready var extract_dialog: FileDialog = %ExtractDialog
@onready var replacement_dialog: FileDialog = %ReplacementDialog
@onready var conversion_source_dialog: FileDialog = %ConversionSourceDialog
@onready var conversion_output_dialog: FileDialog = %ConversionOutputDialog
@onready var overlay_directory_dialog: FileDialog = %OverlayDirectoryDialog
@onready var load_overlay_dialog: FileDialog = %LoadOverlayDialog
@onready var mes_reference_dialog: FileDialog = %MesReferenceDialog
@onready var export_arc_dialog: FileDialog = %ExportArcDialog
@onready var extract_directory_dialog: FileDialog = %ExtractDirectoryDialog
@onready var report_dialog: FileDialog = %ReportDialog
@onready var discard_session_dialog: ConfirmationDialog = %DiscardSessionDialog
@onready var clear_session_dialog: ConfirmationDialog = %ClearSessionDialog
@onready var player: AudioStreamPlayer = %PreviewPlayer

var _reader := ArcReaderScript.new()
var _path_history := ToolPathHistoryScript.new()
var _launch_context := ContentLaunchContextScript.new()
var _overlay_package := OverlayPackageScript.new()
var _resolver := ContentResolverScript.new()
var _selected_entry := ""
var _session: Dictionary = {}
var _audio_entries: Array[Dictionary] = []
var _entry_items: Dictionary = {}
var _pending_open_path := ""
var _archive_sha256 := ""
var _overlay_root := ""
var _overlay_targets: Dictionary = {}
var _timeline_summary: Dictionary = {}
var _timeline_entry := ""
var _mes_reference_index: Dictionary = {}
var _mes_reference_source := ""
var _mes_reference_source_sha256 := ""
var _mes_reference_load_active := false
var _conversion_request: Dictionary = {}
var _pending_batch: Array[String] = []
var _pending_report_names: Array[String] = []
var _extraction_job: KakyuArcBatchExtraction = null


func _ready() -> void:
	set_process(false)
	ToolWindowProfileScript.apply(get_window())
	entry_tree.select_mode = Tree.SELECT_MULTI
	entry_tree.set_column_title(0, "Audio entry")
	entry_tree.set_column_title(1, "Bytes")
	entry_tree.set_column_title(2, "Session")
	entry_tree.set_column_expand(0, true)
	entry_tree.set_column_expand(1, false)
	entry_tree.set_column_expand(2, false)
	entry_tree.set_column_custom_minimum_width(1, 82)
	entry_tree.set_column_custom_minimum_width(2, 74)
	session_tree.set_column_title(0, "Pending entry")
	session_tree.set_column_title(1, "New bytes")
	session_tree.set_column_title(2, "Delta")
	session_tree.set_column_expand(0, true)
	session_tree.set_column_expand(1, false)
	session_tree.set_column_expand(2, false)
	session_tree.set_column_custom_minimum_width(1, 80)
	session_tree.set_column_custom_minimum_width(2, 70)
	_refresh_session_view()
	_path_history.apply_source_dialog(open_dialog)
	var arguments := OS.get_cmdline_user_args()
	_apply_startup_arguments(arguments)


func _apply_startup_arguments(arguments: PackedStringArray) -> void:
	var startup := _launch_context.activate(arguments)
	if not startup.ok:
		status_label.text = str(startup.error)
		return
	if not startup.named:
		if not startup.legacy_arguments.is_empty():
			_open_archive(str(startup.legacy_arguments[0]))
		return
	var selection_document := {}
	var selection_rejected := ""
	var selection_path := _launch_context.get_selection_path()
	if not selection_path.is_empty():
		var selection_contract := ContentSelectionScript.new()
		var read_result := selection_contract.read_path(selection_path)
		if not read_result.get("ok", false):
			status_label.text = "Selection rejected: %s" % str(read_result.get("error", ""))
			return
		var validated := selection_contract.validate_for_workspace(
			read_result.document, _launch_context.get_snapshot()
		)
		if not validated.get("ok", false):
			status_label.text = "Selection rejected: %s" % str(validated.get("error", ""))
			return
		var candidate_archive := str((read_result.document.selection as Dictionary).archive)
		if candidate_archive.to_lower() in ["voice.arc", "bgm.arc", "se.arc", "tina1.arc", "tina2.arc"]:
			selection_document = read_result.document
		else:
			selection_rejected = "Selection rejected: %s does not open in the Audio ARC Editor." % candidate_archive
	var preferred_names: Array[String] = ["voice.arc", "bgm.arc", "se.arc", "tina1.arc", "tina2.arc"]
	if not selection_document.is_empty():
		preferred_names = [str((selection_document.selection as Dictionary).archive)]
	var archive_path := _launch_context.get_preferred_archive_path(preferred_names)
	if archive_path.is_empty():
		status_label.text = "Workspace has no supported audio ARC."
		return
	_open_archive(archive_path)
	if not _reader.is_open():
		return
	var configured := _configure_loaded_overlay(_launch_context.get_workspace_root())
	if not configured.ok:
		status_label.text = "Workspace overlay rejected: %s" % str(configured.error)
		return
	_refresh_after_overlay_change()
	if not selection_rejected.is_empty():
		status_label.text = selection_rejected
		return
	if selection_document.is_empty():
		status_label.text = "Workspace overlay active; %d audio target(s)." % int(configured.target_count)
		return
	var selection: Dictionary = selection_document.selection
	var entry_name := str(selection.entry)
	var entry := _reader.get_entry(entry_name)
	if entry.is_empty() or _reader.get_entry_fingerprint(entry_name) != str(selection.source_entry_sha256):
		status_label.text = "Selection rejected: entry not found or changed in the opened archive."
		return
	filter_edit.text = ""
	_rebuild_entry_tree()
	var item: TreeItem = _entry_items.get(entry_name)
	if item == null:
		status_label.text = "Selection rejected: entry not found in the opened archive."
		return
	item.select(0)
	_selected_entry = entry_name
	_refresh_details()
	status_label.text = "Selection from %s: %s" % [str((selection_document.producer as Dictionary).app), entry_name]


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if _extraction_job != null:
			_extraction_job.cancel()
			_extraction_job = null


func _process(_delta: float) -> void:
	_advance_extraction_job()


func _on_open_pressed() -> void:
	_path_history.apply_source_dialog(open_dialog)
	open_dialog.popup_centered_ratio(0.75)


func _on_archive_selected(path: String) -> void:
	if not _session.is_empty():
		_pending_open_path = path
		discard_session_dialog.dialog_text = "Opening another ARC discards %d pending replacement(s). Continue?" % _session.size()
		discard_session_dialog.popup_centered()
		return
	_open_archive(path)


func _on_discard_session_confirmed() -> void:
	var path := _pending_open_path
	_pending_open_path = ""
	if not path.is_empty():
		_open_archive(path)


func _open_archive(path: String) -> void:
	if _extraction_job != null:
		status_label.text = "An extraction is running; cancel it or wait."
		return
	player.stop()
	_resolver.close()
	_overlay_root = ""
	_overlay_targets.clear()
	entry_tree.clear()
	details.text = ""
	_selected_entry = ""
	_clear_timeline_summary()
	_clear_mes_reference_index()
	_session.clear()
	_audio_entries.clear()
	_entry_items.clear()
	_pending_open_path = ""
	_archive_sha256 = ""
	_conversion_request.clear()
	_refresh_session_view()
	if not _reader.open(path):
		archive_label.text = "No archive open"
		status_label.text = _reader.last_error
		return
	_archive_sha256 = _reader.get_archive_fingerprint()
	if _archive_sha256.is_empty():
		_reader.close()
		archive_label.text = "No archive open"
		status_label.text = "Could not fingerprint the opened audio ARC."
		return
	if not _resolver.register_original_archive(_archive_name(), _reader.archive_path):
		var resolver_error := _resolver.last_error
		_reader.close()
		_archive_sha256 = ""
		archive_label.text = "No archive open"
		status_label.text = "Content resolver could not register the ARC: %s" % resolver_error
		return
	_path_history.remember_source_path(_reader.archive_path)
	_path_history.apply_source_dialog(open_dialog)
	archive_label.text = _reader.archive_path
	for entry in _reader.get_entries():
		var extension := str(entry.name).get_extension().to_lower()
		if extension != "ogg" and extension != "wav":
			continue
		_audio_entries.append(entry)
	_rebuild_entry_tree()
	status_label.text = "%d audio entries; source opened read-only" % _audio_entries.size()


func _on_load_overlay_pressed() -> void:
	if not _can_change_loaded_overlay():
		return
	load_overlay_dialog.popup_centered_ratio(0.75)


func _on_load_overlay_directory_selected(path: String) -> void:
	if not _can_change_loaded_overlay():
		return
	var configured := _configure_loaded_overlay(path)
	if not configured.ok:
		status_label.text = "Overlay load failed: %s" % configured.error
		return
	_refresh_after_overlay_change()
	status_label.text = "Loaded overlay read layer with %d audio replacement(s) for %s." % [configured.target_count, _archive_name()]


func _on_hot_reload_overlay_pressed() -> void:
	if not _can_change_loaded_overlay():
		return
	if _overlay_root.is_empty():
		status_label.text = "Load an overlay package before using Hot Reload."
		return
	var configured := _configure_loaded_overlay(_overlay_root)
	if not configured.ok:
		status_label.text = "Overlay Hot Reload failed: %s" % configured.error
		return
	_refresh_after_overlay_change()
	status_label.text = "Hot Reloaded overlay with %d audio replacement(s) for %s." % [configured.target_count, _archive_name()]


func _on_clear_overlay_pressed() -> void:
	if not _can_change_loaded_overlay():
		return
	if _overlay_root.is_empty():
		status_label.text = "No overlay read layer is loaded."
		return
	_resolver.clear_overlay()
	_overlay_root = ""
	_overlay_targets.clear()
	_refresh_after_overlay_change()
	status_label.text = "Cleared the overlay read layer; audio now resolves from the original ARC."


func _can_change_loaded_overlay() -> bool:
	if _extraction_job != null:
		status_label.text = "An extraction is running; cancel it or wait."
		return false
	if not _reader.is_open():
		status_label.text = "Open an audio ARC before loading an overlay."
		return false
	if not _session.is_empty():
		status_label.text = "Save or remove pending audio replacements before changing the overlay read layer."
		return false
	return true


func _configure_loaded_overlay(path: String) -> Dictionary:
	if _extraction_job != null:
		return {"ok": false, "error": "An extraction is running; cancel it or wait."}
	var package_root := ProjectSettings.globalize_path(path).simplify_path()
	var candidate := ContentResolverScript.new()
	var archive_name := _archive_name()
	if not candidate.register_original_archive(archive_name, _reader.archive_path):
		var register_error := candidate.last_error
		candidate.close()
		return {"ok": false, "error": register_error}
	if not candidate.configure_overlay(package_root):
		var configure_error := candidate.last_error
		candidate.close()
		return {"ok": false, "error": configure_error}
	var bindings := candidate.validate_overlay_archive_bindings(archive_name)
	if not bindings.ok:
		var binding_error := str(bindings.error)
		candidate.close()
		return {"ok": false, "error": binding_error}
	if _archive_sha256.is_empty() or str(bindings.archive_sha256) != _archive_sha256:
		candidate.close()
		return {"ok": false, "error": "The open audio ARC changed before overlay activation."}
	var targets: Dictionary = {}
	for untyped_record in bindings.records:
		var record: Dictionary = untyped_record
		var entry_name := str(record.target_entry)
		var descriptor: Dictionary = bindings.descriptors.get(entry_name.to_upper(), {})
		if descriptor.is_empty():
			candidate.close()
			return {"ok": false, "error": "Validated audio overlay binding is missing a descriptor: %s" % entry_name}
		if entry_name.get_extension().to_lower() in ["ogg", "wav"]:
			targets[entry_name.to_upper()] = record.duplicate(true)
	var previous_resolver := _resolver
	_resolver = candidate
	_overlay_root = str(bindings.root)
	_overlay_targets = targets
	previous_resolver.close()
	return {"ok": true, "target_count": targets.size()}


func _refresh_after_overlay_change() -> void:
	player.stop()
	_clear_timeline_summary()
	_rebuild_entry_tree()
	_refresh_details()


func _archive_name() -> String:
	return _reader.archive_path.replace("\\", "/").get_file()


func _on_filter_changed(_value: String) -> void:
	player.stop()
	_rebuild_entry_tree()
	if not _selected_entry.is_empty() and not _entry_items.has(_selected_entry):
		_selected_entry = ""
		_clear_timeline_summary()
		details.text = "Select an OGG or WAV entry to validate its header."


func _rebuild_entry_tree() -> void:
	entry_tree.clear()
	_entry_items.clear()
	var root := entry_tree.create_item()
	var filter := filter_edit.text.strip_edges().to_upper()
	for entry in _audio_entries:
		if not filter.is_empty() and not str(entry.name).to_upper().contains(filter):
			continue
		var item := entry_tree.create_item(root)
		item.set_text(0, entry.name)
		item.set_text(1, str(entry.size))
		item.set_text(2, _entry_source_label(str(entry.name)))
		item.set_metadata(0, entry.name)
		_entry_items[str(entry.name)] = item


func _entry_source_label(entry_name: String) -> String:
	if _session.has(entry_name):
		return "Pending"
	if _overlay_targets.has(entry_name.to_upper()):
		return "Overlay"
	return ""


func _on_entry_selected() -> void:
	player.stop()
	var item := entry_tree.get_selected()
	var selected := str(item.get_metadata(0)) if item != null else ""
	if selected != _selected_entry:
		_clear_timeline_summary()
		_conversion_request.clear()
	_selected_entry = selected
	_refresh_details()


func _on_entry_multi_selected(_item: TreeItem, _column: int, _selected: bool) -> void:
	player.stop()
	var selected_entries := _selected_entries()
	var selected := selected_entries[-1] if not selected_entries.is_empty() else ""
	if selected != _selected_entry:
		_clear_timeline_summary()
		_conversion_request.clear()
	_selected_entry = selected
	_refresh_details()


func _selected_entries() -> Array[String]:
	var names: Array[String] = []
	var item := entry_tree.get_next_selected(null)
	while item != null:
		names.append(str(item.get_metadata(0)))
		item = entry_tree.get_next_selected(item)
	return names


func _refresh_details() -> void:
	analyze_button.disabled = _selected_entry.is_empty() or not _reader.is_open()
	_refresh_conversion_action()
	_refresh_reference_actions()
	if _selected_entry.is_empty() or not _reader.is_open():
		details.text = "Select an OGG or WAV entry to validate its header."
		return
	var inspected := _inspect_effective_audio(_selected_entry)
	if not inspected.ok:
		details.text = "[b]%s[/b]\nInvalid: %s" % [_selected_entry, inspected.error]
		return
	var lines := _validation_lines(_selected_entry, inspected.validation)
	lines.append("Source: %s" % str(inspected.source).replace("_", " "))
	if str(inspected.source) == "pending replacement":
		var pending: Dictionary = _session[_selected_entry]
		lines.append("New bytes: %d (%+d)" % [pending.size, pending.delta])
		lines.append("Source file: %s" % str(pending.path).get_file())
		if pending.has("conversion"):
			var conversion: Dictionary = pending.conversion
			lines.append("Converted preset: %s" % str(conversion.preset_id))
			lines.append("Converted compatibility: %s" % str(conversion.compatibility).replace("_", " "))
	if _timeline_entry == _selected_entry and _timeline_summary.get("ok", false):
		lines.append_array(_timeline_summary_lines(_timeline_summary))
	elif str(inspected.validation.container) == "ogg":
		lines.append("Duration: Analyze timeline to inspect final Ogg granule")
		lines.append("Waveform: unavailable until decoded PCM is supplied")
	else:
		lines.append("Waveform: Analyze timeline for a bounded PCM summary")
	lines.append_array(_conversion_preset_lines(_selected_entry))
	lines.append_array(_mes_reference_lines(_selected_entry))
	details.text = "\n".join(lines)


func _refresh_conversion_action() -> void:
	if not is_instance_valid(convert_wav_button):
		return
	var preset := _conversion_preset_for_entry(_selected_entry)
	convert_wav_button.disabled = (
		_selected_entry.is_empty()
		or not _reader.is_open()
		or not preset.get("ok", false)
		or not bool(preset.get("can_encode", false))
	)


func _conversion_preset_for_entry(entry_name: String) -> Dictionary:
	if entry_name.is_empty() or not _reader.is_open():
		return {"ok": false, "error": "No audio target is selected."}
	return AudioConversionScript.preset_for_target(_archive_name(), entry_name)


func _conversion_preset_lines(entry_name: String) -> Array[String]:
	var preset := _conversion_preset_for_entry(entry_name)
	if not preset.get("ok", false):
		return ["Conversion preset: unavailable for this archive/entry"]
	var lines: Array[String] = [
		"[b]Conversion preset[/b]: %s" % str(preset.label),
		"Compatibility: %s" % str(preset.compatibility).replace("_", " "),
	]
	if bool(preset.can_encode):
		lines.append("Explicit WAV conversion only; matching input remains byte-identical")
	else:
		lines.append("Preserve only; nonmatching Vorbis requires an encoder that is not available")
	return lines


func _on_load_mes_references_pressed() -> void:
	if _mes_reference_load_active:
		status_label.text = "MES reference indexing is already in progress."
		return
	_path_history.apply_source_dialog(mes_reference_dialog)
	if _reader.is_open():
		mes_reference_dialog.current_dir = _reader.archive_path.get_base_dir()
		mes_reference_dialog.current_file = "mes.arc"
	mes_reference_dialog.popup_centered_ratio(0.75)


func _on_mes_reference_archive_selected(path: String) -> void:
	if _mes_reference_load_active:
		return
	_mes_reference_load_active = true
	load_mes_references_button.disabled = true
	var opened_audio_path := _reader.archive_path
	var opened_audio_sha := _archive_sha256
	var started := _begin_mes_reference_index(path)
	if not started.ok:
		_finish_mes_reference_load_ui()
		status_label.text = "MES reference indexing failed: %s" % str(started.error)
		return
	while not _index_mes_reference_batch(started, 16):
		status_label.text = "Indexing confirmed MES audio references: %d / %d source entries…" % [
			int(started.next_index), int((started.entries as Array).size())
		]
		await get_tree().process_frame
	if _reader.archive_path != opened_audio_path or _archive_sha256 != opened_audio_sha:
		(started.reader as KakyuArcReader).close()
		_finish_mes_reference_load_ui()
		status_label.text = "MES reference indexing was discarded because the open audio ARC changed."
		return
	var loaded := _finish_mes_reference_index(started, path)
	_finish_mes_reference_load_ui()
	if not loaded.ok:
		status_label.text = "MES reference indexing failed: %s" % str(loaded.error)
		return
	_refresh_details()
	status_label.text = "Indexed %d confirmed audio reference(s) (%d BGM, %d voice) from %d MES source entries." % [
		int(loaded.reference_count),
		int(loaded.audio_kind_counts.bgm),
		int(loaded.audio_kind_counts.voice),
		int(loaded.source_count),
	]


func _load_mes_reference_index(path: String) -> Dictionary:
	var started := _begin_mes_reference_index(path)
	if not started.ok:
		return started
	while not _index_mes_reference_batch(started, 256):
		pass
	return _finish_mes_reference_index(started, path)


func _begin_mes_reference_index(path: String) -> Dictionary:
	var mes_reader := ArcReaderScript.new()
	if not mes_reader.open(path):
		return {"ok": false, "error": mes_reader.last_error}
	var archive_name := mes_reader.archive_path.replace("\\", "/").get_file().to_lower()
	if archive_name != "mes.arc":
		mes_reader.close()
		return {"ok": false, "error": "Choose a mes.arc source or a verified materialized mes.arc copy."}
	var source_sha := mes_reader.get_archive_fingerprint()
	if source_sha.is_empty():
		mes_reader.close()
		return {"ok": false, "error": "Could not fingerprint the MES archive."}
	var entries: Array[Dictionary] = []
	for entry in mes_reader.get_entries():
		var extension := str(entry.name).get_extension().to_lower()
		if extension in ["mes", "lib"]:
			entries.append(entry)
	return {
		"ok": true,
		"reader": mes_reader,
		"source_sha256": source_sha,
		"entries": entries,
		"next_index": 0,
		"indexer": MesAudioReferenceIndexScript.new(),
		"indexed_documents": [],
		"parse_failures": [],
	}


func _index_mes_reference_batch(state: Dictionary, max_entries: int) -> bool:
	var mes_reader: KakyuArcReader = state.reader
	var entries: Array = state.entries
	var end_index := mini(entries.size(), int(state.next_index) + maxi(1, max_entries))
	for entry_index in range(int(state.next_index), end_index):
		var entry: Dictionary = entries[entry_index]
		var data := mes_reader.read_entry(str(entry.name))
		if not mes_reader.last_error.is_empty():
			(state.parse_failures as Array).append("%s: %s" % [entry.name, mes_reader.last_error])
			continue
		var document := MesContainerScript.new().parse(data)
		if not document.get("ok", false):
			(state.parse_failures as Array).append("%s: %s" % [entry.name, document.get("error", "invalid MES")])
			continue
		(state.indexed_documents as Array).append((state.indexer as KakyuMesAudioReferenceIndex).index_document(str(entry.name), document))
	state.next_index = end_index
	return end_index >= entries.size()


func _finish_mes_reference_index(state: Dictionary, path: String) -> Dictionary:
	var mes_reader: KakyuArcReader = state.reader
	var source_sha := str(state.source_sha256)
	if FileAccess.get_sha256(mes_reader.archive_path) != source_sha:
		mes_reader.close()
		return {"ok": false, "error": "The MES archive changed during reference indexing."}
	mes_reader.close()
	var built := (state.indexer as KakyuMesAudioReferenceIndex).build_indexed(state.indexed_documents)
	if not built.ok:
		return built
	var parse_failures: Array = state.parse_failures
	if not parse_failures.is_empty():
		return {
			"ok": false,
			"error": "%d MES source entry or entries could not be parsed; no partial index was activated. First failure: %s" % [
				parse_failures.size(), parse_failures[0]
			],
		}
	_mes_reference_index = built.duplicate(true)
	_mes_reference_source = ProjectSettings.globalize_path(path).simplify_path()
	_mes_reference_source_sha256 = source_sha
	_path_history.remember_source_path(_mes_reference_source)
	return built


func _finish_mes_reference_load_ui() -> void:
	_mes_reference_load_active = false
	if is_instance_valid(load_mes_references_button):
		load_mes_references_button.disabled = false


func _mes_reference_lines(entry_name: String) -> Array[String]:
	if _mes_reference_index.is_empty():
		return ["MES references: not indexed (use Load MES references)"]
	var found := MesAudioReferenceIndexScript.new().find(_mes_reference_index, entry_name)
	if not found.ok:
		return ["MES references: index unavailable"]
	var lines: Array[String] = [
		"[b]Confirmed MES references: %d[/b]" % int(found.reference_count),
		"MES source: %s" % _mes_reference_source.get_file(),
	]
	var display_limit := mini(80, int(found.reference_count))
	for reference_index in range(display_limit):
		var reference: Dictionary = found.references[reference_index]
		var offset_text := "0x%X" % int(reference.source_offset)
		if str(reference.audio_kind) == "bgm":
			lines.append("%s %s · BGM selector %d, routine 23 at 0x%X" % [
				reference.mes_entry,
				offset_text,
				int(reference.selector),
				int(reference.call_offset),
			])
		else:
			lines.append("%s %s · voice marker · %s" % [
				reference.mes_entry,
				offset_text,
				str(reference.boundary).replace("_", " "),
			])
	if int(found.reference_count) > display_limit:
		lines.append("… %d more confirmed reference(s)" % (int(found.reference_count) - display_limit))
	return lines


func _clear_mes_reference_index() -> void:
	_mes_reference_index.clear()
	_mes_reference_source = ""
	_mes_reference_source_sha256 = ""


func _refresh_reference_actions() -> void:
	mes_reference_select.clear()
	var references := _selected_reference_candidates()
	for reference in references:
		var index := mes_reference_select.item_count
		mes_reference_select.add_item("%s 0x%X · %s" % [
			str(reference.mes_entry), int(reference.source_offset), str(reference.audio_kind),
		])
		mes_reference_select.set_item_metadata(index, reference)
	mes_reference_select.disabled = references.is_empty()
	open_reference_event_player_button.disabled = references.is_empty()


func _selected_reference_candidates() -> Array:
	if _selected_entry.is_empty() or _mes_reference_index.is_empty():
		return []
	var found := MesAudioReferenceIndexScript.new().find(_mes_reference_index, _selected_entry)
	if not found.get("ok", false):
		return []
	return found.references


func _build_reference_selection() -> Dictionary:
	if not _launch_context.is_active():
		return {"ok": false, "error": "Open this editor from a named workspace to hand a selection to Event Player."}
	var index := mes_reference_select.selected
	if mes_reference_select.disabled or index < 0 or index >= mes_reference_select.item_count:
		return {"ok": false, "error": "Select a confirmed MES reference first."}
	var reference: Dictionary = mes_reference_select.get_item_metadata(index)
	var mes_entry := str(reference.mes_entry)
	var mes_path := _launch_context.get_content_set_root().path_join("mes.arc")
	var mes_reader := ArcReaderScript.new()
	if not mes_reader.open(mes_path):
		return {"ok": false, "error": mes_reader.last_error}
	var entry_sha := mes_reader.get_entry_fingerprint(mes_entry)
	mes_reader.close()
	if entry_sha.is_empty():
		return {"ok": false, "error": "The referencing MES entry is unavailable in this workspace's mes.arc."}
	var catalog_id := ""
	var event_id := ""
	var preset_id := ""
	var catalog := EventCatalogScript.new()
	if catalog.load_file(EVENT_CATALOG_PATH).get("ok", false):
		var found := catalog.find_callee_source(mes_entry)
		if not found.is_empty():
			var project: Dictionary = _launch_context.get_snapshot().get("project", {})
			var event_player: Dictionary = project.get("event_player", {})
			if str(event_player.get("catalog_id", "")) == str(catalog.get_summary().catalog_id):
				var event := catalog.get_event(str(found.event_id))
				var presets: Array = event.get("presets", [])
				if not presets.is_empty():
					catalog_id = str(catalog.get_summary().catalog_id)
					event_id = str(found.event_id)
					preset_id = str((presets[0] as Dictionary).get("preset_id", ""))
	return ContentSelectionScript.new().build(
		_launch_context.get_snapshot(),
		{
			"archive": "mes.arc", "entry": mes_entry, "source_entry_sha256": entry_sha,
			"catalog_id": catalog_id, "event_id": event_id, "preset_id": preset_id,
		},
		"audio_arc_editor"
	)


func _build_reference_launch() -> Dictionary:
	var selection := _build_reference_selection()
	if not selection.get("ok", false):
		return selection
	return SelectionHandoffScript.launch(
		"res://tools/content_suite/apps/event_player.tscn", _launch_context, selection
	)


func _on_open_reference_event_player_pressed() -> void:
	var selection := _build_reference_selection()
	if not selection.get("ok", false):
		status_label.text = str(selection.error)
		return
	var launch := SelectionHandoffScript.launch(
		"res://tools/content_suite/apps/event_player.tscn", _launch_context, selection
	)
	if not launch.get("ok", false):
		status_label.text = str(launch.error)
		return
	var started := SelectionHandoffScript.start(launch)
	if not started.get("ok", false):
		status_label.text = str(started.error)
		return
	status_label.text = "Opened %s in Event Player (PID %d)" % [str(selection.selection.entry), int(started.pid)]


func _inspect_effective_audio(entry_name: String) -> Dictionary:
	if _session.has(entry_name):
		var pending := _validate_staged_replacement(entry_name)
		if not pending.ok:
			return pending
		return {
			"ok": true,
			"validation": pending.validation,
			"size": pending.size,
			"source": "pending replacement",
		}
	var descriptor := _resolver.resolve(_archive_name(), entry_name)
	if not descriptor.ok:
		return descriptor
	if str(descriptor.source) == "original_arc":
		var entry := _reader.get_entry(entry_name)
		var header_size := mini(HEADER_READ_SIZE, int(entry.size))
		var header := _reader.read_entry_range(int(entry.index), 0, header_size)
		if not _reader.last_error.is_empty():
			return {"ok": false, "error": _reader.last_error}
		var validation := AudioValidatorScript.validate(entry_name, header, int(entry.size))
		return {"ok": validation.ok, "error": validation.get("error", ""), "validation": validation, "size": entry.size, "source": "original ARC"}
	var path := str(descriptor.get("path", ""))
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "error": "Resolved audio is missing or unreadable."}
	var total_size := file.get_length()
	var header := file.get_buffer(mini(HEADER_READ_SIZE, total_size))
	var read_error := file.get_error()
	file.close()
	if read_error != OK or header.is_empty():
		return {"ok": false, "error": "Resolved audio header could not be read."}
	var validation := AudioValidatorScript.validate(entry_name, header, total_size)
	return {"ok": validation.ok, "error": validation.get("error", ""), "validation": validation, "size": total_size, "source": str(descriptor.source)}


func _validation_lines(entry_name: String, validation: Dictionary) -> Array[String]:
	var lines: Array[String] = [
		"[b]%s[/b]" % entry_name,
		"Container: %s" % validation.container,
		"Codec: %s" % validation.codec,
		"Bytes: %d" % validation.bytes,
	]
	if validation.has("channels"):
		lines.append("Channels: %d" % validation.channels)
		lines.append("Sample rate: %d Hz" % validation.sample_rate)
	if validation.has("bit_depth"):
		lines.append("Bit depth: %d" % validation.bit_depth)
	if validation.has("duration_ms"):
		lines.append("Duration: %s" % _format_duration(int(validation.duration_ms)))
	return lines


func _on_analyze_timeline_pressed() -> void:
	if _selected_entry.is_empty() or not _reader.is_open():
		status_label.text = "Select an audio entry before analyzing its timeline."
		return
	var summary: Dictionary = _summarize_effective_audio(_selected_entry)
	if not summary.ok:
		status_label.text = "Audio timeline analysis failed: %s" % str(summary.error)
		return
	_timeline_entry = _selected_entry
	_timeline_summary = summary.duplicate(true)
	_refresh_details()
	status_label.text = "Analyzed %s: %s; %s." % [
		_selected_entry,
		_format_duration(int(summary.duration_ms)),
		"bounded PCM waveform" if bool(summary.waveform_available) else "Vorbis duration only",
	]


func _summarize_effective_audio(entry_name: String) -> Dictionary:
	if _session.has(entry_name):
		var pending := _validate_staged_replacement(entry_name)
		if not pending.ok:
			return pending
		return _summarize_audio_file(entry_name, str(pending.path), str(pending.sha256))
	var descriptor := _resolver.resolve(_archive_name(), entry_name)
	if not descriptor.ok:
		return descriptor
	if str(descriptor.source) == "original_arc":
		var entry := _reader.get_entry(entry_name)
		if entry.is_empty():
			return {"ok": false, "error": "Original audio entry is no longer indexed."}
		var summary: Dictionary = AudioTimelineSummaryScript.summarize_ranges(
			entry_name,
			int(entry.size),
			func(offset: int, length: int) -> PackedByteArray:
				return _reader.read_entry_range(int(entry.index), offset, length)
		)
		if not _reader.last_error.is_empty():
			return {"ok": false, "error": _reader.last_error}
		return summary
	if str(descriptor.source) in ["overlay", "fallback"]:
		return _summarize_audio_file(entry_name, str(descriptor.path), str(descriptor.get("sha256", "")))
	return {"ok": false, "error": "Audio timeline range analysis does not support this resolved source."}


func _summarize_audio_file(entry_name: String, path: String, expected_sha256: String) -> Dictionary:
	if path.is_empty() or not FileAccess.file_exists(path):
		return {"ok": false, "error": "Resolved audio file is missing."}
	if expected_sha256.is_empty() or FileAccess.get_sha256(path) != expected_sha256:
		return {"ok": false, "error": "Resolved audio file changed before timeline analysis."}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "error": "Resolved audio file is unreadable."}
	var total_size := file.get_length()
	var summary: Dictionary = AudioTimelineSummaryScript.summarize_ranges(
		entry_name,
		total_size,
		func(offset: int, length: int) -> PackedByteArray:
			file.seek(offset)
			return file.get_buffer(length)
	)
	var read_error := file.get_error()
	file.close()
	if read_error != OK:
		return {"ok": false, "error": "Resolved audio ranges could not be read completely."}
	if FileAccess.get_sha256(path) != expected_sha256:
		return {"ok": false, "error": "Resolved audio file changed during timeline analysis."}
	return summary


func _timeline_summary_lines(summary: Dictionary) -> Array[String]:
	var lines: Array[String] = [
		"[b]Timeline summary[/b]",
		"Duration: %s" % _format_duration(int(summary.duration_ms)),
		"Sample frames: %d" % int(summary.sample_frames),
	]
	if not bool(summary.waveform_available):
		lines.append("Waveform: unavailable (decoded Vorbis PCM is required)")
		return lines
	var complete_label := "complete" if bool(summary.complete) else "bounded sample"
	lines.append("Waveform frames: %d / %d (%s)" % [int(summary.analyzed_frames), int(summary.sample_frames), complete_label])
	lines.append("Waveform min/max/RMS (%d buckets):" % (summary.buckets as Array).size())
	lines.append("[font_size=18]%s[/font_size]" % _waveform_bar(summary.buckets))
	return lines


func _waveform_bar(buckets: Array) -> String:
	const LEVELS := ".:-=+*#@"
	var result := ""
	for untyped_bucket in buckets:
		var bucket: Dictionary = untyped_bucket
		var peak := maxf(absf(float(bucket.minimum)), absf(float(bucket.maximum)))
		var level := mini(LEVELS.length() - 1, int(floor(peak * float(LEVELS.length()))))
		result += LEVELS.substr(level, 1)
	return result


func _format_duration(duration_ms: int) -> String:
	var total_seconds := int(round(float(maxi(0, duration_ms)) / 1000.0))
	var minutes := int(total_seconds / 60)
	var seconds := total_seconds % 60
	var milliseconds := maxi(0, duration_ms) % 1000
	return "%d:%02d.%03d" % [minutes, seconds, milliseconds]


func _clear_timeline_summary() -> void:
	_timeline_summary.clear()
	_timeline_entry = ""
	if is_instance_valid(analyze_button):
		analyze_button.disabled = _selected_entry.is_empty() or not _reader.is_open()


func _on_preview_pressed() -> void:
	if _selected_entry.is_empty():
		status_label.text = "Select an audio entry first."
		return
	var loaded := _read_effective_audio(_selected_entry)
	if not loaded.ok:
		status_label.text = "Audio preview failed: %s" % loaded.error
		return
	var data: PackedByteArray = loaded.data
	var source_label := str(loaded.source)
	var validation := AudioValidatorScript.validate(_selected_entry, data, data.size())
	if not validation.ok:
		status_label.text = str(validation.error)
		return
	var stream: AudioStream
	if validation.container == "ogg":
		stream = AudioStreamOggVorbis.load_from_buffer(data)
	else:
		stream = AudioStreamWAV.load_from_buffer(data)
	if stream == null:
		status_label.text = "Godot could not decode the selected audio stream."
		return
	player.stream = stream
	player.play()
	status_label.text = "Previewing %s (%s)" % [_selected_entry, source_label]


func _on_stop_pressed() -> void:
	player.stop()
	status_label.text = "Preview stopped."


func _on_extract_pressed() -> void:
	if _selected_entry.is_empty():
		status_label.text = "Select an audio entry first."
		return
	extract_dialog.current_file = _selected_entry
	extract_dialog.popup_centered_ratio(0.75)


func _on_extract_path_selected(path: String) -> void:
	var result := _extract_effective_audio(_selected_entry, path)
	status_label.text = "Extracted %s" % path if result.ok else str(result.error)


func _on_extract_selected_folder_pressed() -> void:
	var selected_entries := _selected_entries()
	if selected_entries.is_empty():
		status_label.text = "Select one or more audio entries first."
		return
	_pending_batch = selected_entries
	extract_directory_dialog.popup_centered_ratio(0.75)


func _on_extract_archive_pressed() -> void:
	if not _reader.is_open():
		status_label.text = "Open an audio ARC before extracting the whole archive."
		return
	var all_entries: Array[String] = []
	for entry in _audio_entries:
		all_entries.append(str(entry.name))
	_pending_batch = all_entries
	extract_directory_dialog.popup_centered_ratio(0.75)


func _on_extract_directory_selected(path: String) -> void:
	if _extraction_job != null:
		status_label.text = "An extraction is running; cancel it or wait."
		return
	var batch_names := _pending_batch
	_pending_batch = []
	var overrides := _batch_pending_overrides(batch_names)
	if not overrides.ok:
		status_label.text = str(overrides.error)
		return
	_extraction_job = ArcBatchExtractionScript.begin(_resolver, _archive_name(), batch_names, path, overrides.descriptors)
	extraction_progress_row.visible = true
	extraction_progress.value = 0
	set_process(true)
	_update_extraction_progress()


func _on_cancel_extraction_pressed() -> void:
	if _extraction_job == null:
		return
	_extraction_job.cancel()
	_advance_extraction_job()


## Steps the current extraction job to completion without waiting for frames,
## then applies the same completion handling `_process` would have. Used by
## tests, which do not tick the engine between calling an extraction handler
## and reading its result.
func _run_extraction_to_end() -> void:
	while _extraction_job != null and not _extraction_job.is_done():
		_extraction_job.step(1000)
	_advance_extraction_job()


func _advance_extraction_job() -> void:
	if _extraction_job == null:
		return
	if not _extraction_job.is_done():
		_extraction_job.step(12)
	_update_extraction_progress()
	if _extraction_job.is_done():
		_finish_extraction_job()


func _update_extraction_progress() -> void:
	if _extraction_job == null:
		return
	var progress: Dictionary = _extraction_job.progress()
	extraction_progress.max_value = maxf(1.0, float(progress.total))
	extraction_progress.value = float(progress.done)
	status_label.text = "Extracting %d / %d (%s)..." % [int(progress.done), int(progress.total), str(progress.entry)]


func _finish_extraction_job() -> void:
	var result: Dictionary = _extraction_job.result()
	_extraction_job = null
	extraction_progress_row.visible = false
	set_process(false)
	if result.get("ok", false):
		status_label.text = "Extracted %d audio entries (%d overlay, %d pending, %d original, %d bytes) to %s" % [
			int(result.count),
			int(result.overlay_count),
			int(result.pending_count),
			int(result.original_count),
			int(result.bytes),
			str(result.directory),
		]
	else:
		status_label.text = str(result.get("error", ""))


func _batch_pending_overrides(entry_names: Array[String]) -> Dictionary:
	var descriptors: Dictionary = {}
	for entry_name in entry_names:
		if not _session.has(entry_name):
			continue
		var validated := _validate_staged_replacement(entry_name)
		if not validated.ok:
			return {"ok": false, "error": validated.error}
		descriptors[entry_name] = {
			"ok": true,
			"source": "fallback",
			"path": str(validated.path),
			"size": int(validated.size),
			"sha256": str(validated.sha256),
			"archive": _archive_name(),
			"entry": entry_name,
		}
	return {"ok": true, "descriptors": descriptors}


func _on_export_report_pressed() -> void:
	if not _reader.is_open():
		status_label.text = "Open an audio ARC before exporting a report."
		return
	var selected_entries := _selected_entries()
	var names: Array[String] = selected_entries
	if names.is_empty():
		for entry in _audio_entries:
			names.append(str(entry.name))
	_pending_report_names = names
	report_dialog.current_file = "%s.kakyu-audio-report.json" % _archive_name().get_basename()
	report_dialog.popup_centered_ratio(0.75)


func _on_report_path_selected(path: String) -> void:
	var names := _pending_report_names
	_pending_report_names = []
	var built := AudioMetadataReportScript.build(
		_reader,
		_resolver,
		_archive_name(),
		names,
		_session,
		_mes_reference_index,
		_mes_reference_source.get_file(),
		_mes_reference_source_sha256
	)
	if not built.get("ok", false):
		status_label.text = str(built.get("error", ""))
		return
	var written := AudioMetadataReportScript.write(built.report, path)
	if not written.get("ok", false):
		status_label.text = str(written.get("error", ""))
		return
	var summary: Dictionary = built.report.summary
	status_label.text = "Exported audio report: %d entries (%d overlay, %d pending, %d invalid, %d referenced) to %s" % [
		int(summary.entry_count),
		int(summary.overlay_count),
		int(summary.pending_count),
		int(summary.invalid_count),
		int(summary.referenced_count),
		str(written.path),
	]


func _read_effective_audio(entry_name: String) -> Dictionary:
	if _session.has(entry_name):
		var pending := _validate_staged_replacement(entry_name)
		if not pending.ok:
			return pending
		return {"ok": true, "data": FileAccess.get_file_as_bytes(pending.path), "source": "pending replacement"}
	var descriptor := _resolver.resolve(_archive_name(), entry_name)
	if not descriptor.ok:
		return descriptor
	var data := _resolver.read_resolved(descriptor)
	if not _resolver.last_error.is_empty():
		return {"ok": false, "error": _resolver.last_error}
	return {"ok": true, "data": data, "source": str(descriptor.source)}


func _extract_effective_audio(entry_name: String, output_path: String) -> Dictionary:
	if _session.has(entry_name):
		var pending := _validate_staged_replacement(entry_name)
		if not pending.ok:
			return pending
		return _resolver.extract_resolved({
			"ok": true,
			"source": "fallback",
			"path": str(pending.path),
			"size": int(pending.size),
			"sha256": str(pending.sha256),
			"archive": _archive_name(),
			"entry": entry_name,
		}, output_path)
	var descriptor := _resolver.resolve(_archive_name(), entry_name)
	if not descriptor.ok:
		return descriptor
	return _resolver.extract_resolved(descriptor, output_path)


func _on_add_replacement_pressed() -> void:
	if _selected_entry.is_empty():
		status_label.text = "Select an audio entry first."
		return
	replacement_dialog.filters = PackedStringArray([
		"*.%s ; Matching audio file" % _selected_entry.get_extension().to_lower(),
	])
	replacement_dialog.popup_centered_ratio(0.75)


func _on_convert_wav_pressed() -> void:
	var preset := _conversion_preset_for_entry(_selected_entry)
	if not preset.get("ok", false):
		status_label.text = str(preset.get("error", "No conversion preset is available."))
		return
	if not bool(preset.can_encode) or str(preset.container) != "wav":
		status_label.text = "This target is preserve-only; a verified Vorbis encoder is not available."
		return
	_conversion_request = {
		"target_entry": _selected_entry,
		"preset_id": str(preset.id),
	}
	conversion_source_dialog.filters = PackedStringArray(["*.wav ; PCM WAV source"])
	conversion_source_dialog.popup_centered_ratio(0.75)


func _on_conversion_source_selected(path: String) -> void:
	conversion_source_dialog.hide()
	if not _conversion_request.has("target_entry") or not _reader.is_open():
		status_label.text = "The conversion target is no longer available."
		_conversion_request.clear()
		return
	var target_entry := str(_conversion_request.target_entry)
	if target_entry != _selected_entry or _reader.get_entry(target_entry).is_empty():
		status_label.text = "The selected conversion target changed; start the conversion again."
		_conversion_request.clear()
		return
	var inspected := _inspect_audio_file("conversion-source.wav", path)
	if not inspected.ok:
		status_label.text = "Conversion source rejected: %s" % str(inspected.error)
		_conversion_request.clear()
		return
	if int(inspected.size) > AudioConversionScript.MAX_INPUT_BYTES:
		status_label.text = "Conversion source exceeds the %d-byte safety limit." % AudioConversionScript.MAX_INPUT_BYTES
		_conversion_request.clear()
		return
	_conversion_request["source_path"] = str(inspected.path)
	_conversion_request["source_sha256"] = str(inspected.sha256)
	conversion_output_dialog.current_dir = str(inspected.path).get_base_dir()
	conversion_output_dialog.current_file = "%s-converted.wav" % target_entry.get_basename()
	conversion_output_dialog.popup_centered_ratio(0.75)
	status_label.text = "Choose a new output path for the explicit %s conversion." % target_entry


func _on_conversion_output_selected(path: String) -> void:
	conversion_output_dialog.hide()
	if not _conversion_request.has("source_path") or not _reader.is_open():
		status_label.text = "Choose a conversion source again."
		_conversion_request.clear()
		return
	var target_entry := str(_conversion_request.target_entry)
	if target_entry != _selected_entry or _reader.get_entry(target_entry).is_empty():
		status_label.text = "The selected conversion target changed; no output was published."
		_conversion_request.clear()
		return
	if path.get_extension().to_lower() != "wav":
		status_label.text = "Converted PCM output must use the .wav extension."
		return
	var source_path := str(_conversion_request.source_path)
	var source_sha := str(_conversion_request.source_sha256)
	if not FileAccess.file_exists(source_path) or FileAccess.get_sha256(source_path) != source_sha:
		status_label.text = "Conversion source changed after selection; no output was published."
		_conversion_request.clear()
		return
	var source_data := FileAccess.get_file_as_bytes(source_path)
	if _sha256_data(source_data) != source_sha or FileAccess.get_sha256(source_path) != source_sha:
		status_label.text = "Conversion source changed while it was read; no output was published."
		_conversion_request.clear()
		return
	var converted: Dictionary = AudioConversionScript.convert(
		str(_conversion_request.preset_id),
		"conversion-source.wav",
		source_data
	)
	if not converted.ok:
		status_label.text = "Audio conversion failed: %s" % str(converted.error)
		return
	var published: Dictionary = AudioConversionScript.publish_new_file(path, converted.data)
	if not published.ok:
		status_label.text = "Converted audio was not published: %s" % str(published.error)
		return
	var conversion_record := {
		"schema": str(converted.schema),
		"preset_id": str(converted.preset_id),
		"converted": bool(converted.converted),
		"reason": str(converted.reason),
		"compatibility": str(converted.compatibility),
		"input_sha256": str(converted.input_sha256),
		"output_sha256": str(converted.output_sha256),
	}
	var staged := _stage_replacement_path(target_entry, str(published.path), conversion_record)
	if not staged.ok:
		status_label.text = "Converted file was published, but staging failed: %s" % str(staged.error)
		return
	_conversion_request.clear()
	status_label.text = "%s converted with %s and staged; %d replacement(s) pending." % [
		target_entry,
		str(converted.preset.label),
		_session.size(),
	]


func _on_replacement_file_selected(path: String) -> void:
	if _selected_entry.is_empty() or not _reader.is_open():
		status_label.text = "The selected ARC entry is no longer available."
		return
	var staged := _stage_replacement_path(_selected_entry, path)
	if not staged.ok:
		status_label.text = "Replacement rejected: %s" % staged.error
		return
	status_label.text = "%s added to the session; %d replacement(s) pending." % [_selected_entry, _session.size()]


func _stage_replacement_path(entry_name: String, path: String, conversion := {}) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "error": "Replacement file does not exist."}
	var inspected := _inspect_audio_file(entry_name, path)
	if not inspected.ok:
		return inspected
	var original_entry := _reader.get_entry(entry_name)
	if original_entry.is_empty():
		return {"ok": false, "error": "The target entry is no longer in the open ARC."}
	var original_size := int(original_entry.size)
	var absolute_path := ProjectSettings.globalize_path(path).simplify_path()
	var record := {
		"path": absolute_path,
		"sha256": inspected.sha256,
		"size": inspected.size,
		"original_size": original_size,
		"delta": int(inspected.size) - original_size,
		"container": inspected.validation.container,
		"codec": inspected.validation.codec,
	}
	if not (conversion as Dictionary).is_empty():
		record["conversion"] = (conversion as Dictionary).duplicate(true)
	_session[entry_name] = record
	_clear_timeline_summary()
	_refresh_session_view()
	_refresh_details()
	return {"ok": true, "record": record.duplicate(true)}


func _on_session_entry_selected() -> void:
	var session_item := session_tree.get_selected()
	if session_item == null:
		return
	var entry_name := str(session_item.get_metadata(0))
	if not _entry_items.has(entry_name):
		filter_edit.clear()
		_rebuild_entry_tree()
	if not _entry_items.has(entry_name):
		return
	var entry_item: TreeItem = _entry_items[entry_name]
	entry_item.select(0)
	entry_tree.scroll_to_item(entry_item)
	_selected_entry = entry_name
	_refresh_details()


func _on_remove_replacement_pressed() -> void:
	var session_item := session_tree.get_selected()
	if session_item == null:
		status_label.text = "Select a pending replacement to remove."
		return
	var entry_name := str(session_item.get_metadata(0))
	_session.erase(entry_name)
	if entry_name == _selected_entry:
		_clear_timeline_summary()
	_refresh_session_view()
	_refresh_details()
	status_label.text = "Removed %s from the session." % entry_name


func _on_clear_session_pressed() -> void:
	if _session.is_empty():
		status_label.text = "The replacement session is already empty."
		return
	clear_session_dialog.dialog_text = "Discard all %d pending replacement(s)?" % _session.size()
	clear_session_dialog.popup_centered()


func _on_clear_session_confirmed() -> void:
	_session.clear()
	_clear_timeline_summary()
	_refresh_session_view()
	_refresh_details()
	status_label.text = "Replacement session cleared."


func _on_save_overlay_pressed() -> void:
	if not _require_session():
		return
	overlay_directory_dialog.popup_centered_ratio(0.75)


func _on_export_arc_pressed() -> void:
	if not _require_session():
		return
	var archive_name := _reader.archive_path.replace("\\", "/").get_file()
	export_arc_dialog.current_file = "%s-mod.arc" % archive_name.get_basename()
	export_arc_dialog.popup_centered_ratio(0.75)


func _require_session() -> bool:
	if not _reader.is_open():
		status_label.text = "Open an audio ARC first."
		return false
	if _session.is_empty():
		status_label.text = "Add at least one validated replacement first."
		return false
	return true


func _on_overlay_directory_selected(path: String) -> void:
	if not _require_session():
		return
	var collected := _collect_session_replacement_paths()
	if not collected.ok:
		status_label.text = "Overlay save stopped: %s" % collected.error
		return
	var archive_name := _reader.archive_path.replace("\\", "/").get_file()
	var result := _overlay_package.stage_replacements_from_files(
		path,
		_reader,
		archive_name,
		collected.paths,
		_session_declared_compatibility(),
		"not_applicable"
	)
	if not result.ok:
		status_label.text = "Overlay save failed: %s" % result.error
		return
	var configured := _configure_loaded_overlay(path)
	_refresh_session_view()
	status_label.text = (
		"Saved %d replacements and loaded the overlay read layer: %s" % [_session.size(), result.manifest_path]
		if configured.ok
		else "Saved %d replacements, but overlay reload failed: %s" % [_session.size(), configured.error]
	)


func _on_export_arc_path_selected(path: String) -> void:
	if not _require_session():
		return
	if path.get_extension().to_lower() != "arc":
		status_label.text = "New archive output must use the .arc extension."
		return
	var collected := _collect_session_replacement_paths()
	if not collected.ok:
		status_label.text = "ARC export stopped: %s" % collected.error
		return
	var result := ArcProvenanceScript.new().materialize_repacked_copy_from_bound_files(
		_reader.archive_path,
		path,
		_archive_sha256,
		collected.bound_files,
		_session_declared_compatibility()
	)
	if not result.ok:
		status_label.text = "ARC export failed: %s" % result.error
		return
	status_label.text = "Verified ARC and provenance saved with %d replacements: %s (source unchanged)" % [result.replacement_count, result.path]


func _collect_session_replacement_paths() -> Dictionary:
	var paths: Dictionary = {}
	var bound_files: Dictionary = {}
	var total_bytes := 0
	# Preserve ARC index order in the dictionary passed to downstream writers.
	for entry in _reader.get_entries():
		var entry_name := str(entry.name)
		if not _session.has(entry_name):
			continue
		var loaded := _validate_staged_replacement(entry_name)
		if not loaded.ok:
			return loaded
		paths[entry_name] = loaded.path
		bound_files[entry_name] = {"path": loaded.path, "sha256": loaded.sha256}
		total_bytes += int(loaded.size)
	if paths.size() != _session.size():
		return {"ok": false, "error": "The session contains an entry that is not in the open ARC."}
	return {"ok": true, "paths": paths, "bound_files": bound_files, "total_bytes": total_bytes}


func _session_declared_compatibility() -> String:
	var result := "original_engine_compatible"
	for entry_name in _session:
		var pending: Dictionary = _session[entry_name]
		if not pending.has("conversion"):
			return "remake_only"
		var compatibility := str((pending.conversion as Dictionary).get("compatibility", "remake_only"))
		if compatibility == "remake_only":
			return "remake_only"
		if compatibility != "original_engine_compatible":
			result = "original_engine_unverified"
	return result


func _validate_staged_replacement(entry_name: String) -> Dictionary:
	if not _session.has(entry_name):
		return {"ok": false, "error": "No pending replacement exists for %s." % entry_name}
	var pending: Dictionary = _session[entry_name]
	var path := str(pending.path)
	if not FileAccess.file_exists(path):
		return {"ok": false, "error": "Replacement file is missing for %s." % entry_name}
	var inspected := _inspect_audio_file(entry_name, path)
	if not inspected.ok:
		return inspected
	if str(inspected.sha256) != str(pending.sha256):
		return {"ok": false, "error": "Replacement file changed after it was staged: %s." % entry_name}
	return {
		"ok": true,
		"path": path,
		"size": inspected.size,
		"sha256": inspected.sha256,
		"validation": inspected.validation,
	}


func _inspect_audio_file(entry_name: String, path: String) -> Dictionary:
	var absolute_path := ProjectSettings.globalize_path(path).simplify_path()
	var file := FileAccess.open(absolute_path, FileAccess.READ)
	if file == null:
		return {"ok": false, "error": "Replacement file is missing or unreadable for %s." % entry_name}
	var total_size := file.get_length()
	if total_size <= 0:
		file.close()
		return {"ok": false, "error": "Replacement file is empty for %s." % entry_name}
	var header := file.get_buffer(mini(HEADER_READ_SIZE, total_size))
	var read_error := file.get_error()
	file.close()
	if read_error != OK or header.is_empty():
		return {"ok": false, "error": "Replacement header could not be read for %s." % entry_name}
	var validation := AudioValidatorScript.validate(entry_name, header, total_size)
	if not validation.ok:
		return {"ok": false, "error": "Replacement is not valid for %s: %s" % [entry_name, validation.error]}
	var sha256 := FileAccess.get_sha256(absolute_path)
	if sha256.is_empty():
		return {"ok": false, "error": "Replacement file could not be fingerprinted for %s." % entry_name}
	return {"ok": true, "path": absolute_path, "size": total_size, "sha256": sha256, "validation": validation}


func _sha256_data(data: PackedByteArray) -> String:
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK or context.update(data) != OK:
		return ""
	return context.finish().hex_encode()


func _refresh_session_view() -> void:
	for entry_name in _entry_items:
		var entry_item: TreeItem = _entry_items[entry_name]
		entry_item.set_text(2, _entry_source_label(entry_name))
	session_tree.clear()
	var root := session_tree.create_item()
	var total_delta := 0
	for entry in _reader.get_entries() if _reader.is_open() else []:
		var entry_name := str(entry.name)
		if not _session.has(entry_name):
			continue
		var pending: Dictionary = _session[entry_name]
		var item := session_tree.create_item(root)
		item.set_text(0, entry_name)
		item.set_text(1, str(pending.size))
		item.set_text(2, "%+d" % pending.delta)
		item.set_metadata(0, entry_name)
		item.set_tooltip_text(0, str(pending.path))
		total_delta += int(pending.delta)
	session_label.text = "Pending session: %d replacement(s), total delta %+d bytes" % [_session.size(), total_delta]


func _exit_tree() -> void:
	if _extraction_job != null:
		_extraction_job.cancel()
		_extraction_job = null
	player.stop()
	_launch_context.close()
	_resolver.close()
