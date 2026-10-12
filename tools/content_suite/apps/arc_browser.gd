extends Control

const ArcReaderScript := preload("res://content_core/arc_reader.gd")
const ArcProvenanceScript := preload("res://content_core/arc_provenance.gd")
const ContentResolverScript := preload("res://content_core/content_resolver.gd")
const ContentLaunchContextScript := preload("res://content_core/content_launch_context.gd")
const ContentSelectionScript := preload("res://content_core/content_selection.gd")
const SelectionHandoffScript := preload("res://tools/content_suite/selection_handoff.gd")
const ToolWindowProfileScript := preload("res://tools/content_suite/tool_window_profile.gd")
const ToolPathHistoryScript := preload("res://tools/content_suite/tool_path_history.gd")
const ArcBatchExtractionScript := preload("res://tools/content_suite/arc_batch_extraction.gd")
const ArcComparisonScript := preload("res://tools/content_suite/arc_comparison.gd")
const ArcComparisonPanelScript := preload("res://tools/content_suite/apps/arc_comparison_panel.gd")
const RawReplacementStagingScript := preload("res://tools/content_suite/raw_replacement_staging.gd")

@onready var archive_label: Label = %ArchiveLabel
@onready var filter_edit: LineEdit = %FilterEdit
@onready var entry_tree: Tree = %EntryTree
@onready var status_label: Label = %StatusLabel
@onready var extraction_progress_row: Control = %ExtractionProgressRow
@onready var extraction_progress: ProgressBar = %ExtractionProgress
@onready var cancel_extraction_button: Button = %CancelExtraction
@onready var open_dialog: FileDialog = %OpenDialog
@onready var extract_dialog: FileDialog = %ExtractDialog
@onready var extract_directory_dialog: FileDialog = %ExtractDirectoryDialog
@onready var export_overlay_arc_dialog: FileDialog = %ExportOverlayArcDialog
@onready var load_overlay_dialog: FileDialog = %LoadOverlayDialog
@onready var compare_arc_dialog: FileDialog = %CompareArcDialog
@onready var stage_raw_dialog: FileDialog = %StageRawDialog

var _reader := ArcReaderScript.new()
var _resolver := ContentResolverScript.new()
var _path_history := ToolPathHistoryScript.new()
var _launch_context := ContentLaunchContextScript.new()
var _selected_entry := ""
var _entry_items: Dictionary = {}
var _visible_entry_count := 0
var _status_prefix := "Original archives are opened read-only."
var _status_is_summary := true
var _archive_sha256 := ""
var _overlay_root := ""
var _overlay_targets: Dictionary = {}
var _pending_batch: Array[String] = []
var _comparison_panel: KakyuArcComparisonPanel = null
var _extraction_job: KakyuArcBatchExtraction = null


func _ready() -> void:
	ToolWindowProfileScript.apply(get_window())
	entry_tree.select_mode = Tree.SELECT_MULTI
	entry_tree.set_column_title(0, "Entry")
	entry_tree.set_column_title(1, "Offset")
	entry_tree.set_column_title(2, "Effective bytes")
	entry_tree.set_column_title(3, "Source")
	entry_tree.set_column_expand(0, true)
	entry_tree.set_column_expand(1, false)
	entry_tree.set_column_expand(2, false)
	entry_tree.set_column_expand(3, false)
	entry_tree.set_column_custom_minimum_width(1, 120)
	entry_tree.set_column_custom_minimum_width(2, 110)
	entry_tree.set_column_custom_minimum_width(3, 90)
	_path_history.apply_source_dialog(open_dialog)
	set_process(false)
	var arguments := OS.get_cmdline_user_args()
	_apply_startup_arguments(arguments)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if _extraction_job != null:
			_extraction_job.cancel()
			_extraction_job = null


func _process(_delta: float) -> void:
	_advance_extraction_job()


func _apply_startup_arguments(arguments: PackedStringArray) -> void:
	var startup := _launch_context.activate(arguments)
	if not startup.ok:
		_show_status(str(startup.error))
		return
	if not startup.named:
		if not startup.legacy_arguments.is_empty():
			_open_archive(str(startup.legacy_arguments[0]))
		return
	var selection_document := {}
	var selection_path := _launch_context.get_selection_path()
	if not selection_path.is_empty():
		var selection_contract := ContentSelectionScript.new()
		var read_result := selection_contract.read_path(selection_path)
		if not read_result.get("ok", false):
			_show_status("Selection rejected: %s" % str(read_result.get("error", "")))
			return
		var validated := selection_contract.validate_for_workspace(
			read_result.document, _launch_context.get_snapshot()
		)
		if not validated.get("ok", false):
			_show_status("Selection rejected: %s" % str(validated.get("error", "")))
			return
		selection_document = read_result.document
	var preferred_names: Array[String] = ["mes.arc"]
	if not selection_document.is_empty():
		preferred_names = [str((selection_document.selection as Dictionary).archive)]
	var archive_path := _launch_context.get_preferred_archive_path(preferred_names)
	if archive_path.is_empty():
		_show_status("Workspace does not contain an ARC for the browser startup.")
		return
	_open_archive(archive_path)
	if not _reader.is_open():
		return
	var configured := _configure_loaded_overlay(_launch_context.get_workspace_root())
	if not configured.ok:
		_show_status("Workspace overlay rejected: %s" % str(configured.error))
		return
	_rebuild_entry_tree()
	if selection_document.is_empty():
		_refresh_status("Workspace overlay active")
		return
	var selection: Dictionary = selection_document.selection
	var entry_name := str(selection.entry)
	var item: TreeItem = _entry_items.get(entry_name.to_upper())
	if item == null:
		_show_status("Selection rejected: entry not found in the opened archive.")
		return
	item.select(0)
	_selected_entry = entry_name
	_show_status("Selection from %s: %s" % [str((selection_document.producer as Dictionary).app), entry_name])


func _on_open_pressed() -> void:
	_path_history.apply_source_dialog(open_dialog)
	open_dialog.popup_centered_ratio(0.75)


func _on_archive_selected(path: String) -> void:
	_open_archive(path)


func _open_archive(path: String) -> void:
	if _extraction_job != null:
		_show_status("An extraction is running; cancel it or wait.")
		return
	_resolver.close()
	_overlay_root = ""
	_overlay_targets.clear()
	entry_tree.clear()
	_entry_items.clear()
	_visible_entry_count = 0
	_archive_sha256 = ""
	_selected_entry = ""
	if not _reader.open(path):
		archive_label.text = "No archive open"
		_show_status(_reader.last_error)
		return
	_archive_sha256 = _reader.get_archive_fingerprint()
	if _archive_sha256.is_empty():
		_reader.close()
		archive_label.text = "No archive open"
		_show_status("Could not fingerprint the opened ARC.")
		return
	if not _resolver.register_original_archive(_archive_name(), _reader.archive_path):
		var resolver_error := _resolver.last_error
		_reader.close()
		archive_label.text = "No archive open"
		_show_status("Content resolver could not register the ARC: %s" % resolver_error)
		return
	_path_history.remember_source_path(_reader.archive_path)
	_path_history.apply_source_dialog(open_dialog)
	archive_label.text = path
	_rebuild_entry_tree()
	_refresh_status("Original ARC opened read-only")


func _rebuild_entry_tree() -> void:
	entry_tree.clear()
	_entry_items.clear()
	_visible_entry_count = 0
	var root := entry_tree.create_item()
	var filter := filter_edit.text.strip_edges().to_upper()
	for entry in _reader.get_entries():
		var entry_name := str(entry.name)
		if not filter.is_empty() and not entry_name.to_upper().contains(filter):
			continue
		var item := entry_tree.create_item(root)
		item.set_text(0, entry_name)
		item.set_text(1, "0x%08X" % int(entry.offset))
		item.set_text(2, str(_effective_entry_size(entry_name, int(entry.size))))
		item.set_text(3, "Overlay" if _overlay_targets.has(entry_name.to_upper()) else "Original")
		item.set_metadata(0, entry_name)
		_entry_items[entry_name.to_upper()] = item
		_visible_entry_count += 1
	if not _selected_entry.is_empty():
		var selected_item: TreeItem = _entry_items.get(_selected_entry.to_upper())
		if selected_item == null:
			_selected_entry = ""
		else:
			selected_item.select(0)


func _on_filter_changed(_value: String) -> void:
	_rebuild_entry_tree()
	if _status_is_summary:
		_update_status()


func _effective_entry_size(entry_name: String, original_size: int) -> int:
	var record: Dictionary = _overlay_targets.get(entry_name.to_upper(), {})
	if record.is_empty():
		return original_size
	var path := str(record.get("path", ""))
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return original_size
	var size := file.get_length()
	file.close()
	return size


func _refresh_status(prefix: String) -> void:
	_status_prefix = prefix
	_status_is_summary = true
	_update_status()


func _show_status(message: String) -> void:
	_status_is_summary = false
	status_label.text = message


func _update_status() -> void:
	if not _reader.is_open():
		status_label.text = "%s | %d visible / 0 entries" % [_status_prefix, _visible_entry_count]
		return
	status_label.text = "%s | %d visible / %d entries | %d overlay target(s) | SHA-256 %s" % [
		_status_prefix,
		_visible_entry_count,
		_reader.get_entries().size(),
		_overlay_targets.size(),
		_archive_sha256,
	]


func _on_load_overlay_pressed() -> void:
	if not _reader.is_open():
		_show_status("Open an ARC before loading an overlay.")
		return
	load_overlay_dialog.popup_centered_ratio(0.75)


func _on_load_overlay_directory_selected(path: String) -> void:
	var configured := _configure_loaded_overlay(path)
	if not configured.ok:
		_show_status("Overlay load failed: %s" % configured.error)
		return
	_rebuild_entry_tree()
	_refresh_status("Overlay read layer loaded")


func _on_hot_reload_overlay_pressed() -> void:
	if not _reader.is_open():
		_show_status("Open an ARC before loading an overlay.")
		return
	if _overlay_root.is_empty():
		_show_status("Load an overlay package before using Hot Reload.")
		return
	var configured := _configure_loaded_overlay(_overlay_root)
	if not configured.ok:
		_show_status("Overlay Hot Reload failed: %s" % configured.error)
		return
	_rebuild_entry_tree()
	_refresh_status("Overlay read layer Hot Reloaded")


func _on_clear_overlay_pressed() -> void:
	if not _reader.is_open():
		_show_status("Open an ARC before changing an overlay.")
		return
	if _overlay_root.is_empty():
		_show_status("No overlay read layer is loaded.")
		return
	_resolver.clear_overlay()
	_overlay_root = ""
	_overlay_targets.clear()
	_rebuild_entry_tree()
	_refresh_status("Overlay read layer cleared")


func _configure_loaded_overlay(path: String) -> Dictionary:
	var package_root := ProjectSettings.globalize_path(path).simplify_path()
	var candidate := ContentResolverScript.new()
	if not candidate.register_original_archive(_archive_name(), _reader.archive_path):
		var register_error := candidate.last_error
		candidate.close()
		return {"ok": false, "error": register_error}
	if not candidate.configure_overlay(package_root):
		var configure_error := candidate.last_error
		candidate.close()
		return {"ok": false, "error": configure_error}
	var archive_name := _archive_name()
	var bindings := candidate.validate_overlay_archive_bindings(archive_name)
	if not bindings.ok:
		var binding_error := str(bindings.error)
		candidate.close()
		return {"ok": false, "error": binding_error}
	if not _archive_sha256.is_empty() and str(bindings.archive_sha256) != _archive_sha256:
		candidate.close()
		return {"ok": false, "error": "The open ARC changed before overlay activation."}
	var targets: Dictionary = {}
	for untyped_record in bindings.records:
		var record: Dictionary = untyped_record
		var entry_name := str(_reader.get_entry(str(record.target_entry)).get("name", ""))
		var descriptor: Dictionary = bindings.descriptors.get(entry_name.to_upper(), {})
		if entry_name.is_empty() or descriptor.is_empty():
			candidate.close()
			return {"ok": false, "error": "Validated overlay binding is missing a target descriptor: %s" % str(record.target_entry)}
		targets[entry_name.to_upper()] = {
			"path": str(descriptor.path),
			"sha256": str(descriptor.sha256),
		}
	var previous_resolver := _resolver
	_resolver = candidate
	previous_resolver.close()
	_overlay_root = str(bindings.root)
	_overlay_targets = targets
	return {"ok": true, "target_count": targets.size()}


func _archive_name() -> String:
	return _reader.archive_path.replace("\\", "/").get_file()


func _on_entry_selected() -> void:
	var item := entry_tree.get_selected()
	_selected_entry = str(item.get_metadata(0)) if item != null else ""


func _on_entry_multi_selected(_item: TreeItem, _column: int, _selected: bool) -> void:
	var selected_entries := _selected_entries()
	_selected_entry = selected_entries[-1] if not selected_entries.is_empty() else ""


func _selected_entries() -> Array[String]:
	var names: Array[String] = []
	var item := entry_tree.get_next_selected(null)
	while item != null:
		names.append(str(item.get_metadata(0)))
		item = entry_tree.get_next_selected(item)
	return names


func _on_extract_pressed() -> void:
	if _selected_entry.is_empty():
		_show_status("Select an entry first.")
		return
	extract_dialog.current_file = _selected_entry
	extract_dialog.popup_centered_ratio(0.75)


func _on_extract_path_selected(path: String) -> void:
	var descriptor := _resolver.resolve(_archive_name(), _selected_entry)
	if not descriptor.ok:
		_show_status(str(descriptor.error))
		return
	var result := _resolver.extract_resolved(descriptor, path)
	_show_status("Extracted %s" % path if result.ok else str(result.error))


func _on_extract_selected_folder_pressed() -> void:
	var selected_entries := _selected_entries()
	if selected_entries.is_empty():
		_show_status("Select one or more entries first.")
		return
	_pending_batch = selected_entries
	extract_directory_dialog.popup_centered_ratio(0.75)


func _on_extract_archive_pressed() -> void:
	if not _reader.is_open():
		_show_status("Open an ARC before extracting the whole archive.")
		return
	var all_entries: Array[String] = []
	for entry in _reader.get_entries():
		all_entries.append(str(entry.name))
	_pending_batch = all_entries
	extract_directory_dialog.popup_centered_ratio(0.75)


func _on_extract_directory_selected(path: String) -> void:
	if _extraction_job != null:
		_show_status("An extraction is running; cancel it or wait.")
		return
	var batch_names := _pending_batch
	_pending_batch = []
	_extraction_job = ArcBatchExtractionScript.begin(_resolver, _archive_name(), batch_names, path)
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
	_show_status("Extracting %d / %d (%s)..." % [int(progress.done), int(progress.total), str(progress.entry)])


func _finish_extraction_job() -> void:
	var result: Dictionary = _extraction_job.result()
	_extraction_job = null
	extraction_progress_row.visible = false
	set_process(false)
	if result.get("ok", false):
		_show_status("Extracted %d entries (%d overlay, %d original, %d bytes) to %s" % [
			int(result.count),
			int(result.overlay_count),
			int(result.original_count),
			int(result.bytes),
			str(result.directory),
		])
	else:
		_show_status(str(result.get("error", "")))


func _on_export_overlay_arc_pressed() -> void:
	if not _reader.is_open():
		_show_status("Open an ARC before exporting an overlay copy.")
		return
	if _overlay_root.is_empty() or _overlay_targets.is_empty():
		_show_status("Load an overlay with at least one target for this ARC before exporting a copy.")
		return
	export_overlay_arc_dialog.current_dir = _reader.archive_path.get_base_dir()
	export_overlay_arc_dialog.current_file = "%s-overlay.arc" % _archive_name().get_basename()
	export_overlay_arc_dialog.popup_centered_ratio(0.75)


func _on_export_overlay_arc_path_selected(path: String) -> void:
	if _extraction_job != null:
		_show_status("An extraction is running; cancel it or wait.")
		return
	if not _reader.is_open() or _overlay_root.is_empty() or _overlay_targets.is_empty():
		_show_status("Active overlay bindings are required before exporting a new ARC copy.")
		return
	var result := ArcProvenanceScript.new().materialize_repacked_copy_from_bound_files(
		_reader.archive_path,
		path,
		_archive_sha256,
		_overlay_targets,
		_overlay_compatibility()
	)
	if not result.ok:
		_show_status("Overlay ARC export failed: %s" % str(result.error))
		return
	_show_status("Exported verified overlay ARC copy and provenance: %s" % str(result.path))


func _overlay_compatibility() -> String:
	var snapshot: Dictionary = _resolver.get_overlay_snapshot()
	var manifest: Dictionary = snapshot.get("manifest", {})
	var saw_original_compatible := false
	var saw_remake_only := false
	for value in manifest.get("replacements", []):
		if not value is Dictionary:
			continue
		var record: Dictionary = value
		if str(record.get("target_archive", "")).to_lower() != _archive_name().to_lower():
			continue
		if str(record.get("compatibility", "")) == "original_engine_compatible":
			saw_original_compatible = true
		else:
			saw_remake_only = true
	if saw_original_compatible and not saw_remake_only:
		return "original_engine_compatible"
	if saw_remake_only and not saw_original_compatible:
		return "remake_only"
	return "mixed"


func _on_compare_arc_pressed() -> void:
	if not _reader.is_open():
		_show_status("Open an ARC before comparing with another.")
		return
	compare_arc_dialog.popup_centered_ratio(0.75)


func _on_compare_arc_path_selected(path: String) -> void:
	var other := ArcReaderScript.new()
	if not other.open(path):
		_show_status("Could not open the ARC to compare: %s" % other.last_error)
		return
	var compared := ArcComparisonScript.compare_archives(_reader, other)
	other.close()
	if not compared.get("ok", false):
		_show_status(str(compared.get("error", "")))
		return
	var report: Dictionary = compared.report
	_show_comparison_panel(report)
	var summary: Dictionary = report.summary
	_show_status("Compared %s with %s: %d changed, %d only left, %d only right" % [
		str(report.left.name), str(report.right.name),
		int(summary.changed), int(summary.only_left), int(summary.only_right),
	])


func _on_compare_overlay_pressed() -> void:
	if not _reader.is_open():
		_show_status("Open an ARC before comparing with an overlay.")
		return
	if _overlay_root.is_empty():
		_show_status("Load an overlay before comparing with it.")
		return
	var compared := ArcComparisonScript.compare_overlay(_reader, _resolver, _archive_name())
	if not compared.get("ok", false):
		_show_status(str(compared.get("error", "")))
		return
	var report: Dictionary = compared.report
	_show_comparison_panel(report)
	var summary: Dictionary = report.summary
	_show_status("Compared %s with the loaded overlay: %d changed" % [str(report.left.name), int(summary.changed)])


func _show_comparison_panel(report: Dictionary) -> void:
	if _comparison_panel == null:
		_comparison_panel = ArcComparisonPanelScript.new()
		_comparison_panel.name = "ArcComparisonPanel"
		add_child(_comparison_panel)
	_comparison_panel.show_report(report)


func _on_stage_raw_pressed() -> void:
	if not _launch_context.is_active():
		_show_status("Open the browser from a named workspace to stage a replacement.")
		return
	var selected_entries := _selected_entries()
	if selected_entries.size() != 1:
		_show_status("Select exactly one entry to stage a replacement.")
		return
	_selected_entry = selected_entries[0]
	stage_raw_dialog.popup_centered_ratio(0.75)


func _on_stage_raw_file_selected(path: String) -> void:
	if _extraction_job != null:
		_show_status("An extraction is running; cancel it or wait.")
		return
	var entry_name := _selected_entry
	var staged := RawReplacementStagingScript.stage(
		_launch_context.get_workspace_root(),
		_launch_context.get_content_set_root(),
		_archive_name(),
		entry_name,
		path,
	)
	if not staged.ok:
		_show_status(str(staged.error))
		return
	var configured := _configure_loaded_overlay(_launch_context.get_workspace_root())
	if not configured.ok:
		_show_status("Workspace overlay rejected: %s" % str(configured.error))
		return
	_rebuild_entry_tree()
	var unvalidated_suffix := "" if bool(staged.validated) else " unvalidated"
	_show_status("Staged %s (%s%s, %d bytes, remake_only); workspace generation %s" % [
		entry_name,
		str(staged.format),
		unvalidated_suffix,
		int(staged.replacement_size),
		str(staged.generation_sha256).substr(0, 12),
	])


func _build_editor_launch() -> Dictionary:
	if not _launch_context.is_active():
		return {"ok": false, "error": "Open the browser from a named workspace to hand a selection to an editor."}
	var selected_entries := _selected_entries()
	if selected_entries.size() != 1:
		return {"ok": false, "error": "Select exactly one entry to open in its editor."}
	var entry_name := selected_entries[0]
	var archive_name := _archive_name().to_lower()
	var specialist := SelectionHandoffScript.specialist_for(archive_name, entry_name)
	if not specialist.get("ok", false):
		return specialist
	var entry_sha := _reader.get_entry_fingerprint(entry_name)
	var selection := ContentSelectionScript.new().build(
		_launch_context.get_snapshot(),
		{
			"archive": archive_name, "entry": entry_name, "source_entry_sha256": entry_sha,
			"catalog_id": "", "event_id": "", "preset_id": "",
		},
		"arc_browser"
	)
	if not selection.get("ok", false):
		return selection
	var launch := SelectionHandoffScript.launch(str(specialist.scene), _launch_context, selection)
	if not launch.get("ok", false):
		return launch
	launch["editor_label"] = str(specialist.label)
	launch["entry"] = entry_name
	return launch


func _on_open_in_editor_pressed() -> void:
	var launch := _build_editor_launch()
	if not launch.get("ok", false):
		_show_status(str(launch.error))
		return
	var started := SelectionHandoffScript.start(launch)
	if not started.get("ok", false):
		_show_status(str(started.error))
		return
	_show_status("Opened %s in %s (PID %d)" % [str(launch.entry), str(launch.editor_label), int(started.pid)])


func _exit_tree() -> void:
	if _extraction_job != null:
		_extraction_job.cancel()
		_extraction_job = null
	_launch_context.close()
	_resolver.close()
