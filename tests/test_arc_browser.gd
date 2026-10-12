extends "res://tests/test_case.gd"

const ArcBrowserScene := preload("res://tools/content_suite/apps/arc_browser.tscn")
const ArcProvenanceScript := preload("res://content_core/arc_provenance.gd")
const ArcReaderScript := preload("res://content_core/arc_reader.gd")
const ArcComparisonScript := preload("res://tools/content_suite/arc_comparison.gd")
const OverlayPackageScript := preload("res://content_core/overlay_package.gd")
const ToolPathHistoryScript := preload("res://tools/content_suite/tool_path_history.gd")
const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")
const ContentProjectScript := preload("res://content_core/content_project.gd")
const ContentWorkspaceScript := preload("res://content_core/content_workspace.gd")
const ContentSelectionScript := preload("res://content_core/content_selection.gd")
const SyntheticArc := preload("res://tests/synthetic_arc.gd")

const TEST_ROOT := "user://arc_browser_test"


func _ready() -> void:
	_cleanup()
	var absolute_root := ProjectSettings.globalize_path(TEST_ROOT)
	DirAccess.make_dir_recursive_absolute(absolute_root)
	var archive_path := TEST_ROOT.path_join("sample.arc")
	var overlay_root := TEST_ROOT.path_join("my_mod")
	var overlay_extract_path := TEST_ROOT.path_join("overlay.bin")
	var reloaded_extract_path := TEST_ROOT.path_join("reloaded.bin")
	var rejected_extract_path := TEST_ROOT.path_join("rejected-hot-reload.bin")
	var overlay_arc_path := TEST_ROOT.path_join("overlay-copy.arc")
	var changed_payload_arc_path := TEST_ROOT.path_join("changed-payload-copy.arc")
	var changed_source_arc_path := TEST_ROOT.path_join("changed-source-copy.arc")
	var original_extract_path := TEST_ROOT.path_join("original.bin")
	var hidden_extract_path := TEST_ROOT.path_join("hidden.bin")
	var original_payload := "original".to_ascii_buffer()
	var overlay_payload := "overlay replacement".to_ascii_buffer()
	var reloaded_payload := "hot reload replacement".to_ascii_buffer()
	SyntheticArc.write_arc(archive_path, [
		{"name": "FIRST.BIN", "data": original_payload},
		{"name": "SECOND.BIN", "data": "second".to_ascii_buffer()},
	])
	var source_sha := FileAccess.get_sha256(archive_path)
	var source_reader := ArcReaderScript.new()
	_check(source_reader.open(archive_path), "ARC Browser overlay fixture opens its source ARC")
	var overlay_package := OverlayPackageScript.new()
	var staged := overlay_package.stage_replacement(
		overlay_root,
		source_reader,
		"sample.arc",
		"FIRST.BIN",
		overlay_payload,
		"remake_only",
		"not_applicable"
	)
	_check(staged.ok, "ARC Browser overlay fixture publishes a hash-bound replacement")

	var browser: Control = ArcBrowserScene.instantiate()
	browser.set("_path_history", ToolPathHistoryScript.new(TEST_ROOT.path_join("path_history.cfg")))
	add_child(browser)
	await get_tree().process_frame
	browser.call("_open_archive", archive_path)
	_check((browser.get("_path_history") as ContentToolPathHistory).get_last_source_directory() == absolute_root.simplify_path(), "ARC Browser remembers its successfully opened ARC directory")
	_check((browser.get_node("OpenDialog") as FileDialog).current_dir.simplify_path() == absolute_root.simplify_path(), "ARC Browser reopens its ARC chooser at the remembered directory")
	_check((browser.get_node("Margin/Layout/StatusLabel") as Label).text.contains("2 entries"), "ARC Browser keeps the source read-only and lists its index")
	_check((browser.get_node("Margin/Layout/StatusLabel") as Label).text.contains("2 visible / 2 entries"), "ARC Browser reports the initial visible and total entry counts")
	var original_window_size := get_window().size
	get_window().size = Vector2i(1024, 640)
	await get_tree().process_frame
	_check(_controls_fit(browser), "ARC Browser overlay controls fit the shared minimum desktop size")
	_check(browser.has_node("Margin/Layout/Toolbar2/ExportOverlayArc"), "ARC Browser exposes active-overlay ARC export")
	_check(browser.has_node("Margin/Layout/Toolbar3/CompareArc"), "ARC Browser exposes Compare with ARC")
	_check(browser.has_node("Margin/Layout/Toolbar3/CompareOverlay"), "ARC Browser exposes Compare with overlay")
	_check(browser.has_node("Margin/Layout/Toolbar3/OpenInEditor"), "ARC Browser exposes Open in editor")
	_check(browser.has_node("Margin/Layout/Toolbar3/StageRaw"), "ARC Browser exposes Stage raw replacement...")
	get_window().size = original_window_size
	await get_tree().process_frame

	var entry_tree: Tree = browser.get_node("Margin/Layout/EntryTree")
	var filter_edit: LineEdit = browser.get_node("Margin/Layout/FilterEdit")
	var extraction_progress_row: Control = browser.get_node("Margin/Layout/ExtractionProgressRow")
	var extraction_progress: ProgressBar = browser.get_node("Margin/Layout/ExtractionProgressRow/ExtractionProgress")
	var cancel_extraction_button: Button = browser.get_node("Margin/Layout/ExtractionProgressRow/CancelExtraction")
	_check(not extraction_progress_row.visible, "ARC Browser hides the extraction progress row while idle")
	filter_edit.text = "fIrSt"
	browser.call("_on_filter_changed", filter_edit.text)
	var first_item := entry_tree.get_root().get_first_child()
	_check(entry_tree.get_root().get_child_count() == 1 and str(first_item.get_metadata(0)) == "FIRST.BIN", "ARC Browser filters entry names without case sensitivity")
	_check((browser.get_node("Margin/Layout/StatusLabel") as Label).text.contains("1 visible / 2 entries"), "ARC Browser reports filtered visible and total entry counts")
	first_item.select(0)
	browser.call("_on_entry_selected")
	_check(str(browser.get("_selected_entry")) == "FIRST.BIN", "ARC Browser records the visible filtered selection")
	var no_context_launch: Dictionary = browser.call("_build_editor_launch")
	_check(
		not no_context_launch.get("ok", false)
		and str(no_context_launch.error) == "Open the browser from a named workspace to hand a selection to an editor.",
		"_build_editor_launch without a named workspace context returns the named-workspace error"
	)
	browser.call("_on_stage_raw_pressed")
	_check(
		(browser.get_node("Margin/Layout/StatusLabel") as Label).text == "Open the browser from a named workspace to stage a replacement.",
		"_on_stage_raw_pressed without a named workspace context returns the named-workspace error"
	)

	browser.call("_on_load_overlay_directory_selected", overlay_root)
	first_item = entry_tree.get_root().get_first_child()
	_check(filter_edit.text == "fIrSt" and entry_tree.get_root().get_child_count() == 1, "ARC Browser preserves its entry filter while loading an overlay")
	_check(str(browser.get("_selected_entry")) == "FIRST.BIN" and entry_tree.get_selected() != null, "ARC Browser restores a still-visible selection after loading an overlay")
	_check(first_item.get_text(2) == str(overlay_payload.size()) and first_item.get_text(3) == "Overlay", "ARC Browser reports effective overlay size and source")
	browser.call("_on_extract_path_selected", overlay_extract_path)
	_check(FileAccess.get_file_as_bytes(overlay_extract_path) == overlay_payload, "ARC Browser stream-extracts effective overlay bytes")
	_check((browser.get_node("Margin/Layout/StatusLabel") as Label).text.contains("Extracted %s" % overlay_extract_path), "ARC Browser reports its successful resolved extraction")
	filter_edit.text = "fir"
	browser.call("_on_filter_changed", filter_edit.text)
	_check((browser.get_node("Margin/Layout/StatusLabel") as Label).text.contains("Extracted %s" % overlay_extract_path), "ARC Browser preserves the current extraction result while filtering")
	filter_edit.text = "fIrSt"
	browser.call("_on_filter_changed", filter_edit.text)

	filter_edit.text = ""
	browser.call("_on_filter_changed", filter_edit.text)
	_check(entry_tree.get_root().get_child_count() == 2, "ARC Browser batch-extraction fixture shows every entry before a folder batch")
	var batch_first_item := entry_tree.get_root().get_first_child()
	var batch_second_item := batch_first_item.get_next()
	batch_first_item.select(0)
	batch_second_item.select(0)
	browser.call("_on_entry_multi_selected", batch_second_item, 0, true)
	_check(browser.call("_selected_entries") == ["FIRST.BIN", "SECOND.BIN"], "ARC Browser reports both multi-selected entries in tree order")
	var second_payload := "second".to_ascii_buffer()
	var selected_batch_folder := TEST_ROOT.path_join("selected_batch")
	browser.call("_on_extract_selected_folder_pressed")
	browser.call("_on_extract_directory_selected", selected_batch_folder)
	_check(
		extraction_progress_row.visible and cancel_extraction_button.visible and browser.get("_extraction_job") != null,
		"ARC Browser shows the extraction progress row and cancel button while a folder batch job runs"
	)
	browser.call("_run_extraction_to_end")
	_check(
		not extraction_progress_row.visible and browser.get("_extraction_job") == null,
		"ARC Browser hides the extraction progress row once _run_extraction_to_end finishes the folder batch job"
	)
	var selected_batch_absolute := ProjectSettings.globalize_path(selected_batch_folder).simplify_path()
	var selected_batch_first_path := selected_batch_absolute.path_join("FIRST.BIN")
	var selected_batch_second_path := selected_batch_absolute.path_join("SECOND.BIN")
	_check(
		FileAccess.get_file_as_bytes(selected_batch_first_path) == overlay_payload
		and FileAccess.get_file_as_bytes(selected_batch_second_path) == second_payload,
		"ARC Browser batch-extracts the effective bytes of both selected entries"
	)
	_check(
		(browser.get_node("Margin/Layout/StatusLabel") as Label).text.contains(
			"Extracted 2 entries (1 overlay, 1 original, %d bytes) to %s" % [overlay_payload.size() + second_payload.size(), selected_batch_absolute]
		),
		"ARC Browser reports the folder-batch extraction summary"
	)
	DirAccess.remove_absolute(selected_batch_second_path)
	_check(not FileAccess.file_exists(selected_batch_second_path), "ARC Browser batch-extraction fixture removes the second output before the repeat run")
	browser.call("_on_extract_selected_folder_pressed")
	browser.call("_on_extract_directory_selected", selected_batch_folder)
	browser.call("_run_extraction_to_end")
	_check(
		(browser.get_node("Margin/Layout/StatusLabel") as Label).text.contains("already exists")
		and not FileAccess.file_exists(selected_batch_second_path),
		"ARC Browser refuses a repeat folder batch into an existing output and writes nothing"
	)
	filter_edit.text = "fIrSt"
	browser.call("_on_filter_changed", filter_edit.text)
	_check(entry_tree.get_root().get_child_count() == 1, "ARC Browser batch-extraction fixture hides SECOND.BIN before the whole-archive batch")
	var archive_batch_folder := TEST_ROOT.path_join("archive_batch")
	browser.call("_on_extract_archive_pressed")
	browser.call("_on_extract_directory_selected", archive_batch_folder)
	browser.call("_run_extraction_to_end")
	var archive_batch_absolute := ProjectSettings.globalize_path(archive_batch_folder).simplify_path()
	_check(
		FileAccess.get_file_as_bytes(archive_batch_absolute.path_join("FIRST.BIN")) == overlay_payload
		and FileAccess.get_file_as_bytes(archive_batch_absolute.path_join("SECOND.BIN")) == second_payload,
		"ARC Browser Extract archive writes every index entry regardless of the active filter"
	)
	_check(_controls_fit(browser), "ARC Browser batch-extraction controls still fit the shared minimum desktop size")
	_check(FileAccess.get_sha256(archive_path) == source_sha, "ARC Browser batch extraction never changes the source ARC")
	first_item = entry_tree.get_root().get_first_child()
	first_item.select(0)
	browser.call("_on_entry_selected")
	_check(str(browser.get("_selected_entry")) == "FIRST.BIN" and entry_tree.get_selected() != null, "ARC Browser batch-extraction fixture restores the single-entry selection")

	# A running extraction job refuses a second extraction and refuses to
	# open another archive, then finishes normally once run to the end.
	var guard_batch_folder := TEST_ROOT.path_join("guard_batch")
	browser.call("_on_extract_archive_pressed")
	browser.call("_on_extract_directory_selected", guard_batch_folder)
	_check(browser.get("_extraction_job") != null, "ARC Browser fixture starts a running job for the concurrency guard checks")
	var guard_second_target := TEST_ROOT.path_join("guard_batch_refused")
	browser.call("_on_extract_archive_pressed")
	browser.call("_on_extract_directory_selected", guard_second_target)
	_check(
		(browser.get_node("Margin/Layout/StatusLabel") as Label).text == "An extraction is running; cancel it or wait."
		and not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(guard_second_target).simplify_path()),
		"ARC Browser refuses a second extraction while one is running and writes nothing for it"
	)
	browser.call("_open_archive", archive_path)
	_check(
		(browser.get_node("Margin/Layout/StatusLabel") as Label).text == "An extraction is running; cancel it or wait."
		and entry_tree.get_root().get_child_count() == 1,
		"ARC Browser refuses to open another archive while an extraction is running"
	)
	browser.call("_run_extraction_to_end")
	var guard_batch_absolute := ProjectSettings.globalize_path(guard_batch_folder).simplify_path()
	_check(
		browser.get("_extraction_job") == null
		and not extraction_progress_row.visible
		and FileAccess.file_exists(guard_batch_absolute.path_join("FIRST.BIN"))
		and FileAccess.file_exists(guard_batch_absolute.path_join("SECOND.BIN")),
		"ARC Browser finishes the guarded job normally once run to the end"
	)

	# Cancelling a running job removes the file it had already written,
	# reports the cancellation status, and hides the progress row.
	var cancel_batch_folder := TEST_ROOT.path_join("cancel_batch")
	browser.call("_on_extract_archive_pressed")
	browser.call("_on_extract_directory_selected", cancel_batch_folder)
	var cancel_running_job = browser.get("_extraction_job")
	_check(cancel_running_job != null, "ARC Browser fixture starts a running job for the cancellation check")
	var progress_before_step: Dictionary = cancel_running_job.call("progress")
	_check(int(progress_before_step.done) == 0, "ARC Browser stepped job fixture has written nothing before its first step")
	cancel_running_job.call("step", 0)
	var progress_after_step: Dictionary = cancel_running_job.call("progress")
	_check(int(progress_after_step.done) == 1, "ARC Browser stepped job fixture writes one entry before cancellation")
	browser.call("_on_cancel_extraction_pressed")
	var cancel_batch_absolute := ProjectSettings.globalize_path(cancel_batch_folder).simplify_path()
	_check(
		(browser.get_node("Margin/Layout/StatusLabel") as Label).text == "Extraction cancelled; removed 1 file(s)."
		and not FileAccess.file_exists(cancel_batch_absolute.path_join("FIRST.BIN"))
		and not FileAccess.file_exists(cancel_batch_absolute.path_join("SECOND.BIN"))
		and not extraction_progress_row.visible
		and browser.get("_extraction_job") == null,
		"ARC Browser cancellation removes the written file, reports the cancellation status, and hides the progress row"
	)

	var reloaded := overlay_package.stage_replacement(
		overlay_root,
		source_reader,
		"sample.arc",
		"FIRST.BIN",
		reloaded_payload,
		"remake_only",
		"not_applicable"
	)
	_check(reloaded.ok, "ARC Browser Hot Reload fixture atomically updates its replacement")
	browser.call("_on_hot_reload_overlay_pressed")
	first_item = entry_tree.get_root().get_first_child()
	_check(filter_edit.text == "fIrSt" and entry_tree.get_root().get_child_count() == 1, "ARC Browser preserves its entry filter across Hot Reload")
	_check(str(browser.get("_selected_entry")) == "FIRST.BIN" and entry_tree.get_selected() != null, "ARC Browser restores a still-visible selection after Hot Reload")
	_check(first_item.get_text(2) == str(reloaded_payload.size()) and first_item.get_text(3) == "Overlay", "ARC Browser Hot Reload refreshes effective metadata")
	browser.call("_on_extract_path_selected", reloaded_extract_path)
	_check(FileAccess.get_file_as_bytes(reloaded_extract_path) == reloaded_payload, "ARC Browser Hot Reload extracts the updated payload")
	browser.call("_on_export_overlay_arc_path_selected", overlay_arc_path)
	var overlay_arc_reader := ArcReaderScript.new()
	_check(
		overlay_arc_reader.open(overlay_arc_path)
		and overlay_arc_reader.read_entry("FIRST.BIN") == reloaded_payload
		and overlay_arc_reader.read_entry("SECOND.BIN") == "second".to_ascii_buffer(),
		"ARC Browser materializes the active overlay into a verified new ARC while preserving unchanged entries"
	)
	overlay_arc_reader.close()
	var browser_provenance := ArcProvenanceScript.new().load_sidecar(overlay_arc_path)
	_check(browser_provenance.get("ok", false) and browser_provenance.provenance.declared_compatibility == "remake_only", "ARC Browser publishes portable provenance with its overlay compatibility")

	browser.call("_on_compare_arc_path_selected", overlay_arc_path)
	var comparison_panel = browser.get("_comparison_panel")
	_check(comparison_panel != null, "ARC Browser creates its comparison result panel on first use")
	var arc_compare_report: Dictionary = comparison_panel.call("get_report")
	var arc_changed_entries: Array[String] = []
	for untyped_row in (arc_compare_report.get("rows", []) as Array):
		var row: Dictionary = untyped_row
		if str(row.status) != "identical":
			arc_changed_entries.append(str(row.entry))
	_check(
		str(arc_compare_report.get("mode", "")) == "archive" and arc_changed_entries == ["FIRST.BIN"],
		"ARC Browser Compare with ARC reports exactly the overlay target as changed"
	)
	_check(int(comparison_panel.call("visible_row_count")) == 1, "ARC Browser Compare with ARC shows one visible row with differences only")
	var comparison_checkbox: CheckBox = comparison_panel.get("differences_only")
	comparison_checkbox.button_pressed = false
	comparison_panel.call("_render_rows")
	_check(int(comparison_panel.call("visible_row_count")) == 2, "ARC Browser Compare with ARC shows every row with differences only off")
	comparison_checkbox.button_pressed = true
	comparison_panel.call("_render_rows")
	_check(
		(browser.get_node("Margin/Layout/StatusLabel") as Label).text == "Compared sample.arc with overlay-copy.arc: 1 changed, 0 only left, 0 only right",
		"ARC Browser reports the Compare with ARC summary in its status"
	)
	_check(FileAccess.get_sha256(archive_path) == source_sha, "ARC Browser Compare with ARC leaves the source ARC unchanged")

	browser.call("_on_compare_overlay_pressed")
	var overlay_compare_report: Dictionary = comparison_panel.call("get_report")
	var overlay_changed_entries: Array[String] = []
	for untyped_row in (overlay_compare_report.get("rows", []) as Array):
		var row: Dictionary = untyped_row
		if str(row.status) != "identical":
			overlay_changed_entries.append(str(row.entry))
	_check(
		str(overlay_compare_report.get("mode", "")) == "overlay" and overlay_changed_entries == ["FIRST.BIN"],
		"ARC Browser Compare with overlay reports the same entry changed"
	)
	_check(
		(browser.get_node("Margin/Layout/StatusLabel") as Label).text == "Compared sample.arc with the loaded overlay: 1 changed",
		"ARC Browser reports the Compare with overlay summary in its status"
	)
	_check(FileAccess.get_sha256(archive_path) == source_sha, "ARC Browser Compare with overlay leaves the source ARC unchanged")

	var comparison_export_path := TEST_ROOT.path_join("comparison-export.json")
	comparison_panel.call("_on_export_path_selected", comparison_export_path)
	var comparison_export_absolute := ProjectSettings.globalize_path(comparison_export_path).simplify_path()
	var comparison_reopened := ArcComparisonScript.read_path(comparison_export_absolute)
	_check(comparison_reopened.get("ok", false), "ARC Browser comparison export writes a report read_path accepts")

	var active_target: Dictionary = (browser.get("_overlay_targets") as Dictionary)["FIRST.BIN"]
	var active_payload_path := str(active_target.path)
	var active_payload_bytes := FileAccess.get_file_as_bytes(active_payload_path)
	var changed_payload_bytes := active_payload_bytes.duplicate()
	changed_payload_bytes[changed_payload_bytes.size() - 1] ^= 0x01
	_write_bytes(active_payload_path, changed_payload_bytes)
	browser.call("_on_export_overlay_arc_path_selected", changed_payload_arc_path)
	_check(
		not FileAccess.file_exists(changed_payload_arc_path)
		and (browser.get_node("Margin/Layout/StatusLabel") as Label).text.contains("bound SHA-256"),
		"ARC Browser rejects an overlay payload changed after its active manifest snapshot"
	)
	_write_bytes(active_payload_path, active_payload_bytes)
	_check(FileAccess.get_sha256(active_payload_path) == str(active_target.sha256), "ARC Browser overlay-payload mutation fixture restores the content-addressed blob")
	var source_archive_bytes := FileAccess.get_file_as_bytes(archive_path)
	var changed_source_bytes := source_archive_bytes.duplicate()
	changed_source_bytes[changed_source_bytes.size() - 1] ^= 0x01
	_write_bytes(archive_path, changed_source_bytes)
	browser.call("_on_export_overlay_arc_path_selected", changed_source_arc_path)
	_check(
		not FileAccess.file_exists(changed_source_arc_path)
		and (browser.get_node("Margin/Layout/StatusLabel") as Label).text.contains("changed after it was opened"),
		"ARC Browser rejects overlay ARC export after the open source ARC changes"
	)
	_write_bytes(archive_path, source_archive_bytes)
	_check(FileAccess.get_sha256(archive_path) == source_sha, "ARC Browser export source-mutation fixture restores the source ARC")
	var previous_resolver: Object = browser.get("_resolver")
	var previous_root := str(browser.get("_overlay_root"))
	var previous_targets: Dictionary = (browser.get("_overlay_targets") as Dictionary).duplicate(true)
	var previous_snapshot: Dictionary = previous_resolver.call("get_overlay_snapshot")
	var active_bindings: Dictionary = previous_resolver.call("validate_overlay_archive_bindings", "sample.arc")
	_check(
		active_bindings.ok
		and active_bindings.records.size() == 1
		and active_bindings.descriptors.size() == 1
		and active_bindings.descriptors.has("FIRST.BIN")
		and str(active_bindings.archive_sha256) == source_sha
		and previous_resolver.call("resolve", "sample.arc", "FIRST.BIN") == active_bindings.descriptors["FIRST.BIN"],
		"ARC Browser normal resolve matches the independently batch-validated extraction descriptor"
	)
	var second_staged := overlay_package.stage_replacement(
		overlay_root,
		source_reader,
		"sample.arc",
		"SECOND.BIN",
		"invalid candidate only".to_ascii_buffer(),
		"remake_only",
		"not_applicable"
	)
	_check(second_staged.ok, "ARC Browser Hot Reload failure fixture publishes a second structurally valid target")
	var manifest_path := ProjectSettings.globalize_path(overlay_root).simplify_path().path_join("manifest.json")
	var valid_manifest_text := FileAccess.get_file_as_string(manifest_path)
	var wrong_base_manifest: Dictionary = JSON.parse_string(valid_manifest_text)
	for untyped_record in wrong_base_manifest.replacements:
		var record: Dictionary = untyped_record
		if str(record.target_entry).to_upper() == "SECOND.BIN":
			record.base_archive_sha256 = "0".repeat(64)
	_write_text(manifest_path, JSON.stringify(wrong_base_manifest, "\t") + "\n")
	_check(overlay_package.load_manifest(overlay_root).ok, "ARC Browser wrong-base Hot Reload fixture remains structurally valid")
	browser.call("_on_hot_reload_overlay_pressed")
	_check(
		(browser.get_node("Margin/Layout/StatusLabel") as Label).text.contains("Overlay Hot Reload failed:")
		and (browser.get_node("Margin/Layout/StatusLabel") as Label).text.contains("base ARC hash does not match"),
		"ARC Browser reports a rejected batch-bound Hot Reload"
	)
	_check(
		browser.get("_resolver") == previous_resolver
		and str(browser.get("_overlay_root")) == previous_root
		and browser.get("_overlay_targets") == previous_targets
		and previous_resolver.call("get_overlay_snapshot") == previous_snapshot
		and filter_edit.text == "fIrSt"
		and str(browser.get("_selected_entry")) == "FIRST.BIN",
		"failed ARC Browser Hot Reload preserves resolver, root, targets, snapshot, filter, and selection"
	)
	filter_edit.text = "first.bin"
	browser.call("_on_filter_changed", filter_edit.text)
	_check((browser.get_node("Margin/Layout/StatusLabel") as Label).text.contains("Overlay Hot Reload failed:"), "ARC Browser preserves the current Hot Reload failure while filtering")
	filter_edit.text = "fIrSt"
	browser.call("_on_filter_changed", filter_edit.text)
	browser.call("_on_extract_path_selected", rejected_extract_path)
	_check(
		FileAccess.get_file_as_bytes(rejected_extract_path) == reloaded_payload,
		"failed ARC Browser Hot Reload keeps the previous effective overlay extract usable"
	)
	_write_text(manifest_path, valid_manifest_text)

	browser.call("_on_clear_overlay_pressed")
	first_item = entry_tree.get_root().get_first_child()
	_check(filter_edit.text == "fIrSt" and entry_tree.get_root().get_child_count() == 1, "ARC Browser preserves its entry filter while clearing an overlay")
	_check(str(browser.get("_selected_entry")) == "FIRST.BIN" and entry_tree.get_selected() != null, "ARC Browser restores a still-visible selection after clearing an overlay")
	_check(first_item.get_text(2) == str(original_payload.size()) and first_item.get_text(3) == "Original", "ARC Browser Clear overlay restores original index metadata")
	browser.call("_on_extract_path_selected", original_extract_path)
	_check(FileAccess.get_file_as_bytes(original_extract_path) == original_payload, "ARC Browser stream-extracts original ARC bytes after clearing overlay")

	browser.call("_on_compare_overlay_pressed")
	_check(
		(browser.get_node("Margin/Layout/StatusLabel") as Label).text == "Load an overlay before comparing with it.",
		"ARC Browser Compare with overlay without a loaded overlay reports the status error"
	)

	filter_edit.text = "sEcOnD"
	browser.call("_on_filter_changed", filter_edit.text)
	var second_item := entry_tree.get_root().get_first_child()
	_check(entry_tree.get_root().get_child_count() == 1 and str(second_item.get_metadata(0)) == "SECOND.BIN", "ARC Browser applies a replacement mixed-case filter")
	_check(str(browser.get("_selected_entry")).is_empty() and entry_tree.get_selected() == null, "ARC Browser clears a selection hidden by the entry filter")
	browser.call("_on_extract_path_selected", hidden_extract_path)
	_check(not FileAccess.file_exists(hidden_extract_path), "ARC Browser fails closed instead of extracting a filter-hidden selection")
	_check(FileAccess.get_sha256(archive_path) == source_sha, "ARC Browser overlay inspection never changes the source ARC")

	source_reader.close()
	browser.queue_free()
	await get_tree().process_frame
	await _test_startup_selection()
	await _test_editor_launch(archive_path)
	await _test_stage_raw()
	_cleanup()
	get_tree().quit(1 if _failed else 0)


func _test_startup_selection() -> void:
	var absolute_root := ProjectSettings.globalize_path(TEST_ROOT)
	var source_root := absolute_root.path_join("selection_source")
	var workspace_root := absolute_root.path_join("selection_workspace")
	DirAccess.make_dir_recursive_absolute(source_root)
	var archive_path := source_root.path_join("mes.arc")
	SyntheticArc.write_arc(archive_path, [
		{"name": "FIRST.BIN", "data": "first".to_ascii_buffer()},
		{"name": "SECOND.BIN", "data": "second".to_ascii_buffer()},
	])
	var archive_sha := FileAccess.get_sha256(archive_path)
	var archives := [{"archive": "mes.arc", "sha256": archive_sha, "required": true}]
	var project := {
		"schema": ContentCoreVersionScript.CONTENT_PROJECT_SCHEMA, "project_id": "arc-browser.selection.test",
		"project_version": "0.1.0", "display_name": "ARC Browser Selection Test", "project_revision": 1,
		"content_core": {"minimum_version": ContentCoreVersionScript.CORE_VERSION, "maximum_exclusive": "1.0.0"},
		"source_content_set": {
			"profile_id": "synthetic-test",
			"fingerprint_sha256": ContentProjectScript.compute_content_set_fingerprint(archives),
			"archives": archives,
		},
		"target_archives": ["mes.arc"], "compatibility_objective": "mixed", "dependencies": [],
		"event_player": {"catalog_id": "kakyu-original-events", "presets": []}, "overlay_manifest": "manifest.json",
	}
	var workspace := ContentWorkspaceScript.new()
	var created := workspace.create(workspace_root, source_root, project)
	_check(created.get("ok", false), "ARC Browser selection fixture creates a named workspace")
	var snapshot := workspace.get_snapshot()
	workspace.close()

	var reader := ArcReaderScript.new()
	reader.open(archive_path)
	var entry_sha := reader.get_entry_fingerprint("SECOND.BIN")
	reader.close()
	var document := ContentSelectionScript.new().build(
		snapshot,
		{
			"archive": "mes.arc", "entry": "SECOND.BIN", "source_entry_sha256": entry_sha,
			"catalog_id": "", "event_id": "", "preset_id": "",
		},
		"mes_editor"
	)
	_check(document.get("ok", false), "ARC Browser selection fixture builds a content selection for SECOND.BIN")
	var selection_path := absolute_root.path_join("selection.json")
	_write_text(selection_path, JSON.stringify(document, "", true, true) + "\n")

	var selection_browser: Control = ArcBrowserScene.instantiate()
	add_child(selection_browser)
	await get_tree().process_frame
	selection_browser.call("_apply_startup_arguments", PackedStringArray([
		"--content-set", source_root, "--workspace", workspace_root, "--selection", selection_path,
	]))
	_check(
		str(selection_browser.get("_selected_entry")) == "SECOND.BIN"
		and (selection_browser.get_node("Margin/Layout/StatusLabel") as Label).text
			== "Selection from mes_editor: SECOND.BIN",
		"ARC Browser startup with --selection selects the named row"
	)
	selection_browser.queue_free()
	await get_tree().process_frame


func _test_editor_launch(sample_archive_path: String) -> void:
	var absolute_root := ProjectSettings.globalize_path(TEST_ROOT)
	var source_root := absolute_root.path_join("editor_launch_source")
	var workspace_root := absolute_root.path_join("editor_launch_workspace")
	DirAccess.make_dir_recursive_absolute(source_root)
	var archive_path := source_root.path_join("mes.arc")
	SyntheticArc.write_arc(archive_path, [
		{"name": "FIRST.MES", "data": "first mes".to_ascii_buffer()},
		{"name": "SECOND.MES", "data": "second mes".to_ascii_buffer()},
	])
	var archive_sha := FileAccess.get_sha256(archive_path)
	var archives := [{"archive": "mes.arc", "sha256": archive_sha, "required": true}]
	var project := {
		"schema": ContentCoreVersionScript.CONTENT_PROJECT_SCHEMA, "project_id": "arc-browser.editor-launch.test",
		"project_version": "0.1.0", "display_name": "ARC Browser Editor Launch Test", "project_revision": 1,
		"content_core": {"minimum_version": ContentCoreVersionScript.CORE_VERSION, "maximum_exclusive": "1.0.0"},
		"source_content_set": {
			"profile_id": "synthetic-test",
			"fingerprint_sha256": ContentProjectScript.compute_content_set_fingerprint(archives),
			"archives": archives,
		},
		"target_archives": ["mes.arc"], "compatibility_objective": "mixed", "dependencies": [],
		"event_player": {"catalog_id": "kakyu-original-events", "presets": []}, "overlay_manifest": "manifest.json",
	}
	var workspace := ContentWorkspaceScript.new()
	var created := workspace.create(workspace_root, source_root, project)
	_check(created.get("ok", false), "editor-launch fixture creates a named workspace bound to mes.arc")
	workspace.close()

	var browser: Control = ArcBrowserScene.instantiate()
	add_child(browser)
	await get_tree().process_frame
	browser.call("_apply_startup_arguments", PackedStringArray([
		"--content-set", source_root, "--workspace", workspace_root,
	]))

	var entry_tree: Tree = browser.get_node("Margin/Layout/EntryTree")
	var first_item := entry_tree.get_root().get_first_child()
	var second_item := first_item.get_next()
	first_item.select(0)
	browser.call("_on_entry_selected")
	second_item.select(0)
	browser.call("_on_entry_multi_selected", second_item, 0, true)
	var two_selected_launch: Dictionary = browser.call("_build_editor_launch")
	_check(
		not two_selected_launch.get("ok", false)
		and str(two_selected_launch.error) == "Select exactly one entry to open in its editor.",
		"_build_editor_launch with two selected entries returns the exactly-one error"
	)

	entry_tree.deselect_all()
	first_item.select(0)
	browser.call("_on_entry_selected")
	var launch: Dictionary = browser.call("_build_editor_launch")
	_check(
		launch.get("ok", false) and (launch.arguments as PackedStringArray).has("--selection"),
		"_build_editor_launch for a specialist-owned entry returns arguments naming a --selection handoff"
	)
	var mes_reader := ArcReaderScript.new()
	mes_reader.open(archive_path)
	var expected_entry_sha := mes_reader.get_entry_fingerprint("FIRST.MES")
	mes_reader.close()
	var contract := ContentSelectionScript.new()
	var read_back := contract.read_path(str(launch.get("path", "")))
	_check(
		read_back.get("ok", false)
		and str((read_back.document as Dictionary).producer.app) == "arc_browser"
		and str((read_back.document as Dictionary).selection.entry) == "FIRST.MES"
		and str((read_back.document as Dictionary).selection.source_entry_sha256) == expected_entry_sha,
		"the handoff file reads back naming FIRST.MES with producer arc_browser and its original hash"
	)

	browser.call("_open_archive", sample_archive_path)
	var sample_entry_tree: Tree = browser.get_node("Margin/Layout/EntryTree")
	var sample_item := sample_entry_tree.get_root().get_first_child()
	sample_item.select(0)
	browser.call("_on_entry_selected")
	var sample_selected_entry := str(browser.get("_selected_entry"))
	var no_specialist_launch: Dictionary = browser.call("_build_editor_launch")
	_check(
		not no_specialist_launch.get("ok", false)
		and str(no_specialist_launch.error) == "No specialist editor handles %s in sample.arc." % sample_selected_entry,
		"_build_editor_launch for sample.arc, which has no specialist, returns the no-specialist error"
	)

	browser.queue_free()
	await get_tree().process_frame


func _test_stage_raw() -> void:
	var absolute_root := ProjectSettings.globalize_path(TEST_ROOT)
	var source_root := absolute_root.path_join("stage_raw_source")
	var workspace_root := absolute_root.path_join("stage_raw_workspace")
	DirAccess.make_dir_recursive_absolute(source_root)
	var archive_path := source_root.path_join("mes.arc")
	var original_payload := "original mes bytes".to_ascii_buffer()
	SyntheticArc.write_arc(archive_path, [
		{"name": "FIRST.MES", "data": original_payload},
		{"name": "SECOND.MES", "data": "second mes".to_ascii_buffer()},
	])
	var archive_sha := FileAccess.get_sha256(archive_path)
	var archives := [{"archive": "mes.arc", "sha256": archive_sha, "required": true}]
	var project := {
		"schema": ContentCoreVersionScript.CONTENT_PROJECT_SCHEMA, "project_id": "arc-browser.stage-raw.test",
		"project_version": "0.1.0", "display_name": "ARC Browser Stage Raw Test", "project_revision": 1,
		"content_core": {"minimum_version": ContentCoreVersionScript.CORE_VERSION, "maximum_exclusive": "1.0.0"},
		"source_content_set": {
			"profile_id": "synthetic-test",
			"fingerprint_sha256": ContentProjectScript.compute_content_set_fingerprint(archives),
			"archives": archives,
		},
		"target_archives": ["mes.arc"], "compatibility_objective": "mixed", "dependencies": [],
		"event_player": {"catalog_id": "kakyu-original-events", "presets": []}, "overlay_manifest": "manifest.json",
	}
	var workspace := ContentWorkspaceScript.new()
	var created := workspace.create(workspace_root, source_root, project)
	_check(created.get("ok", false), "stage-raw fixture creates a named workspace bound to mes.arc")
	workspace.close()

	var browser: Control = ArcBrowserScene.instantiate()
	add_child(browser)
	await get_tree().process_frame
	browser.call("_apply_startup_arguments", PackedStringArray([
		"--content-set", source_root, "--workspace", workspace_root,
	]))

	var entry_tree: Tree = browser.get_node("Margin/Layout/EntryTree")
	var first_item := entry_tree.get_root().get_first_child()
	var second_item := first_item.get_next()
	first_item.select(0)
	browser.call("_on_entry_selected")
	second_item.select(0)
	browser.call("_on_entry_multi_selected", second_item, 0, true)
	browser.call("_on_stage_raw_pressed")
	_check(
		(browser.get_node("Margin/Layout/StatusLabel") as Label).text == "Select exactly one entry to stage a replacement.",
		"_on_stage_raw_pressed with two selected entries returns the exactly-one error"
	)

	entry_tree.deselect_all()
	first_item.select(0)
	browser.call("_on_entry_selected")

	var replacement_bytes := PackedByteArray([0, 0, 0, 0, 0xAA])
	var replacement_path := absolute_root.path_join("stage_raw_replacement.mes")
	_write_bytes(replacement_path, replacement_bytes)
	browser.call("_on_stage_raw_file_selected", replacement_path)
	var status_text := (browser.get_node("Margin/Layout/StatusLabel") as Label).text
	_check(
		status_text.begins_with("Staged FIRST.MES (mes, %d bytes, remake_only); workspace generation " % replacement_bytes.size())
		and not status_text.contains("unvalidated"),
		"_on_stage_raw_file_selected reports the staged format, size, and generation"
	)
	first_item = entry_tree.get_root().get_first_child()
	_check(
		first_item.get_text(2) == str(replacement_bytes.size()) and first_item.get_text(3) == "Overlay",
		"_on_stage_raw_file_selected shows the row as Overlay with the new effective size"
	)
	var extracted_path := absolute_root.path_join("stage_raw_extracted.mes")
	browser.call("_on_extract_path_selected", extracted_path)
	_check(FileAccess.get_file_as_bytes(extracted_path) == replacement_bytes, "extracting the staged entry yields the replacement bytes")
	_check(FileAccess.get_sha256(archive_path) == archive_sha, "staging a raw replacement leaves the source ARC hash unchanged")

	var identical_replacement_path := absolute_root.path_join("stage_raw_identical.mes")
	_write_bytes(identical_replacement_path, original_payload)
	browser.call("_on_stage_raw_file_selected", identical_replacement_path)
	_check(
		(browser.get_node("Margin/Layout/StatusLabel") as Label).text == "Replacement is identical to the original entry; nothing to stage.",
		"_on_stage_raw_file_selected with an identical file returns the identical error"
	)

	browser.queue_free()
	await get_tree().process_frame


func _controls_fit(browser: Control) -> bool:
	var margin: Control = browser.get_node("Margin")
	if not Rect2(Vector2.ZERO, browser.size).encloses(margin.get_rect()):
		return false
	var layout: Control = browser.get_node("Margin/Layout")
	for child in layout.get_children():
		if child is HBoxContainer and str(child.name).begins_with("Toolbar"):
			var toolbar: Control = child
			if toolbar.size.x < toolbar.get_combined_minimum_size().x:
				return false
	return true


func _write_text(path: String, value: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(value)
	file.close()


func _write_bytes(path: String, value: PackedByteArray) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(value)
	file.close()


func _cleanup() -> void:
	_remove_tree(ProjectSettings.globalize_path(TEST_ROOT))
