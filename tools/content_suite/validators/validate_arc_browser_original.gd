extends "res://tools/content_suite/cli_script.gd"

const ArcBrowserScene := preload("res://tools/content_suite/apps/arc_browser.tscn")
const ArcReaderScript := preload("res://content_core/arc_reader.gd")
const ContentResolverScript := preload("res://content_core/content_resolver.gd")
const ArcBatchExtractionScript := preload("res://tools/content_suite/arc_batch_extraction.gd")
const MES_ARCHIVE := "mes.arc"
const REPRESENTATIVE_ENTRY := "START.MES"
const OUTPUT_PATH := "user://arc_browser_original_validation-start.mes"
const HIDDEN_OUTPUT_PATH := "user://arc_browser_original_validation-hidden.mes"
const BATCH_OUTPUT_PATH := "user://arc_browser_original_validation-batch"
const ARCHIVE_OUTPUT_PATH := "user://arc_browser_original_validation-archive"
const BATCH_ENTRIES := ["START.MES", "DEF_MAIN.MES", "LIBLARY.LIB"]

# WD-16 large-ARC block: a real voice.arc / bgm.arc from the ELFIMAGE root the
# check is given (and takes mes.arc from), exercised through the stepped job
# API. The check receives the root rather than mes.arc so that its validation
# inputs include every archive it reads (TD-53).
const LARGE_VOICE_ARCHIVE := "voice.arc"
const LARGE_BGM_ARCHIVE := "bgm.arc"
const LARGE_VOICE_OUTPUT_PATH := "user://arc_browser_original_validation-large-voice"
const LARGE_BGM_OUTPUT_PATH := "user://arc_browser_original_validation-large-bgm"
const LARGE_CANCEL_MIN_ENTRIES := 300
const LARGE_CANCEL_MAX_SECONDS := 30.0
const LARGE_BGM_EXPECTED_ENTRIES := 52
const LARGE_PEAK_GROWTH_LIMIT_BYTES := 128 * 1024 * 1024


func _initialize() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() != 1:
		_fail("Usage: <ELFIMAGE>")
		return
	var source_root := ProjectSettings.globalize_path(str(arguments[0]))
	var archive_path := source_root.path_join(MES_ARCHIVE)
	var source_sha := FileAccess.get_sha256(archive_path)
	if source_sha.is_empty():
		_fail("Original MES archive is unavailable.")
		return
	var output_absolute := ProjectSettings.globalize_path(OUTPUT_PATH)
	var hidden_output_absolute := ProjectSettings.globalize_path(HIDDEN_OUTPUT_PATH)
	if FileAccess.file_exists(output_absolute):
		DirAccess.remove_absolute(output_absolute)
	if FileAccess.file_exists(hidden_output_absolute):
		DirAccess.remove_absolute(hidden_output_absolute)
	var browser: Control = ArcBrowserScene.instantiate()
	root.add_child(browser)
	await process_frame
	browser.call("_open_archive", archive_path)
	var reader: KakyuArcReader = browser.get("_reader")
	var tree: Tree = browser.get_node("Margin/Layout/EntryTree")
	var filter_edit: LineEdit = browser.get_node("Margin/Layout/FilterEdit")
	var entry := reader.get_entry(REPRESENTATIVE_ENTRY)
	var count := reader.get_entries().size()
	if (
		not reader.is_open()
		or reader.get_entries().is_empty()
		or entry.is_empty()
		or tree.get_root() == null
		or tree.get_root().get_child_count() != count
	):
		browser.queue_free()
		_fail("ARC Browser did not reproduce the original archive index.")
		return
	filter_edit.text = "sTaRt.MeS"
	browser.call("_on_filter_changed", filter_edit.text)
	var representative_item := tree.get_root().get_first_child()
	var status_label: Label = browser.get_node("Margin/Layout/StatusLabel")
	if (
		tree.get_root().get_child_count() != 1
		or representative_item == null
		or str(representative_item.get_metadata(0)) != REPRESENTATIVE_ENTRY
		or not status_label.text.contains("1 visible / %d entries" % count)
	):
		browser.queue_free()
		_fail("ARC Browser original entry filter was not case-insensitive or its count was incorrect.")
		return
	representative_item.select(0)
	browser.call("_on_entry_selected")
	filter_edit.text = "__NO_SUCH_ORIGINAL_ENTRY__"
	browser.call("_on_filter_changed", filter_edit.text)
	if (
		tree.get_root().get_child_count() != 0
		or not str(browser.get("_selected_entry")).is_empty()
		or tree.get_selected() != null
	):
		browser.queue_free()
		_fail("ARC Browser retained a selection hidden by its original entry filter.")
		return
	browser.call("_on_extract_path_selected", HIDDEN_OUTPUT_PATH)
	if FileAccess.file_exists(hidden_output_absolute):
		DirAccess.remove_absolute(hidden_output_absolute)
		browser.queue_free()
		_fail("ARC Browser extracted a filter-hidden original entry.")
		return
	filter_edit.text = "sTaRt.MeS"
	browser.call("_on_filter_changed", filter_edit.text)
	representative_item = tree.get_root().get_first_child()
	representative_item.select(0)
	browser.call("_on_entry_selected")
	browser.call("_on_extract_path_selected", OUTPUT_PATH)
	var output_sha := FileAccess.get_sha256(output_absolute)
	var expected_sha := reader.get_entry_fingerprint(REPRESENTATIVE_ENTRY)
	var extracted := not output_sha.is_empty() and output_sha == expected_sha
	if FileAccess.file_exists(output_absolute):
		DirAccess.remove_absolute(output_absolute)
	if not extracted:
		browser.queue_free()
		await process_frame
		_fail("ARC Browser failed resolved extraction of a representative original entry.")
		return

	var resolver = browser.get("_resolver")
	var archive_name := str(browser.call("_archive_name"))

	var batch_absolute := ProjectSettings.globalize_path(BATCH_OUTPUT_PATH).simplify_path()
	_remove_directory(batch_absolute)
	var batch_result := ArcBatchExtractionScript.extract_entries(resolver, archive_name, BATCH_ENTRIES, BATCH_OUTPUT_PATH)
	var batch_ok: bool = batch_result.get("ok", false) and int(batch_result.get("count", -1)) == BATCH_ENTRIES.size()
	if batch_ok:
		for batch_name in BATCH_ENTRIES:
			var batch_path := batch_absolute.path_join(batch_name)
			if FileAccess.get_sha256(batch_path) != reader.get_entry_fingerprint(batch_name):
				batch_ok = false
	_remove_directory(batch_absolute)

	var archive_absolute := ProjectSettings.globalize_path(ARCHIVE_OUTPUT_PATH).simplify_path()
	_remove_directory(archive_absolute)
	var archive_result := ArcBatchExtractionScript.extract_archive(resolver, reader, archive_name, ARCHIVE_OUTPUT_PATH)
	var expected_archive_bytes := 0
	for entry_row in reader.get_entries():
		expected_archive_bytes += int(entry_row.size)
	var archive_ok: bool = (
		archive_result.get("ok", false)
		and int(archive_result.get("count", -1)) == count
		and int(archive_result.get("bytes", -1)) == expected_archive_bytes
	)
	if archive_ok:
		var spot_entries: Array = reader.get_entries().slice(0, mini(10, count))
		for spot_entry in spot_entries:
			var spot_name := str(spot_entry.name)
			var spot_path := archive_absolute.path_join(spot_name)
			if FileAccess.get_sha256(spot_path) != reader.get_entry_fingerprint(spot_name):
				archive_ok = false
	_remove_directory(archive_absolute)

	browser.call("_on_compare_arc_path_selected", archive_path)
	var comparison_panel = browser.get("_comparison_panel")
	var self_compare_identical := 0
	var self_compare_ok := false
	if comparison_panel != null:
		var compare_report: Dictionary = comparison_panel.call("get_report")
		var compare_summary: Dictionary = compare_report.get("summary", {})
		self_compare_identical = int(compare_summary.get("identical", -1))
		self_compare_ok = (
			str(compare_report.get("mode", "")) == "archive"
			and bool(compare_report.get("order_preserved", false))
			and self_compare_identical == count
			and int(compare_summary.get("changed", -1)) == 0
			and int(compare_summary.get("only_left", -1)) == 0
			and int(compare_summary.get("only_right", -1)) == 0
			and int(comparison_panel.call("visible_row_count")) == 0
		)

	var source_unchanged := FileAccess.get_sha256(archive_path) == source_sha
	browser.queue_free()
	await process_frame
	if not batch_ok or not archive_ok or not source_unchanged or not self_compare_ok:
		_fail("ARC Browser batch or complete-archive extraction failed, changed its source archive, or the self-compare did not report every entry identical.")
		return
	var large_block := _run_large_archive_block(source_root)
	if not large_block.get("ok", false):
		_fail(str(large_block.get("error", "")))
		return
	print(
		(
			"PASS: ARC Browser original integration entries=%d representative=%s filter_casefold=true hidden_selection_rejected=true extracted_hash_match=true source_unchanged=true batch=%d archive_entries=%d archive_bytes=%d self_compare_identical=%d %s"
		) % [
			count, REPRESENTATIVE_ENTRY, BATCH_ENTRIES.size(), int(archive_result.get("count", 0)), int(archive_result.get("bytes", 0)), self_compare_identical,
			str(large_block.get("token", "")),
		]
	)
	quit(0)


## Exercises the stepped job API (`begin`/`step`/`cancel`) on the real
## voice.arc and bgm.arc from `elfimage_root`. Skipped with the
## `large_archives=absent` token when either file is not present in the
## ELFIMAGE root; otherwise: (1) begins a whole-archive job on voice.arc,
## steps it to at least 300 entries done, cancels it, and checks the output
## directory holds nothing, the cancellation names the removed count, and the
## cancellation is not slower than 30s; (2) extracts the whole bgm.arc by
## steps to completion and checks its 52 entries, byte total, and per-file
## SHA-256 against `reader.get_entry_fingerprint`; (3) checks static memory
## peak growth stays under 128 MiB; (4) checks both source archives are
## unchanged.
func _run_large_archive_block(elfimage_root: String) -> Dictionary:
	var voice_path := elfimage_root.path_join(LARGE_VOICE_ARCHIVE)
	var bgm_path := elfimage_root.path_join(LARGE_BGM_ARCHIVE)
	if not FileAccess.file_exists(voice_path) or not FileAccess.file_exists(bgm_path):
		return {"ok": true, "token": "large_archives=absent"}
	var voice_source_sha := FileAccess.get_sha256(voice_path)
	var bgm_source_sha := FileAccess.get_sha256(bgm_path)
	if voice_source_sha.is_empty() or bgm_source_sha.is_empty():
		return {"ok": false, "error": "Large-archive block could not fingerprint voice.arc or bgm.arc."}
	var peak_before := OS.get_static_memory_peak_usage()

	var voice_reader := ArcReaderScript.new()
	if not voice_reader.open(voice_path):
		return {"ok": false, "error": "Large-archive block could not open voice.arc: %s" % voice_reader.last_error}
	var voice_resolver := ContentResolverScript.new()
	if not voice_resolver.register_original_archive(LARGE_VOICE_ARCHIVE, voice_reader.archive_path):
		var voice_register_error := voice_resolver.last_error
		voice_reader.close()
		return {"ok": false, "error": "Large-archive block could not register voice.arc: %s" % voice_register_error}
	var voice_output_absolute := ProjectSettings.globalize_path(LARGE_VOICE_OUTPUT_PATH).simplify_path()
	_remove_directory(voice_output_absolute)
	var voice_job: KakyuArcBatchExtraction = ArcBatchExtractionScript.begin(voice_resolver, LARGE_VOICE_ARCHIVE, _entry_name_list(voice_reader), LARGE_VOICE_OUTPUT_PATH)
	var cancel_start := Time.get_ticks_msec()
	while not voice_job.is_done() and int(voice_job.progress().done) < LARGE_CANCEL_MIN_ENTRIES:
		voice_job.step(50)
	var entries_before_cancel := int(voice_job.progress().done)
	voice_job.cancel()
	var cancel_elapsed := (Time.get_ticks_msec() - cancel_start) / 1000.0
	var voice_cancel_result := voice_job.result()
	voice_reader.close()
	voice_resolver.close()
	var voice_directory_empty := _directory_has_no_files(voice_output_absolute)
	_remove_directory(voice_output_absolute)
	var voice_cancel_ok: bool = (
		entries_before_cancel >= LARGE_CANCEL_MIN_ENTRIES
		and not voice_cancel_result.get("ok", false)
		and bool(voice_cancel_result.get("cancelled", false))
		and int(voice_cancel_result.get("removed_count", -1)) == entries_before_cancel
		and voice_directory_empty
		and cancel_elapsed < LARGE_CANCEL_MAX_SECONDS
	)
	if not voice_cancel_ok:
		return {
			"ok": false,
			"error": "Large-archive voice.arc cancellation did not meet its bound: entries=%d removed=%s elapsed=%.1fs" % [
				entries_before_cancel, str(voice_cancel_result.get("removed_count", -1)), cancel_elapsed,
			],
		}

	var bgm_reader := ArcReaderScript.new()
	if not bgm_reader.open(bgm_path):
		return {"ok": false, "error": "Large-archive block could not open bgm.arc: %s" % bgm_reader.last_error}
	var bgm_resolver := ContentResolverScript.new()
	if not bgm_resolver.register_original_archive(LARGE_BGM_ARCHIVE, bgm_reader.archive_path):
		var bgm_register_error := bgm_resolver.last_error
		bgm_reader.close()
		return {"ok": false, "error": "Large-archive block could not register bgm.arc: %s" % bgm_register_error}
	var bgm_output_absolute := ProjectSettings.globalize_path(LARGE_BGM_OUTPUT_PATH).simplify_path()
	_remove_directory(bgm_output_absolute)
	var bgm_job: KakyuArcBatchExtraction = ArcBatchExtractionScript.begin(bgm_resolver, LARGE_BGM_ARCHIVE, _entry_name_list(bgm_reader), LARGE_BGM_OUTPUT_PATH)
	while not bgm_job.is_done():
		bgm_job.step(1000)
	var bgm_result := bgm_job.result()
	var bgm_expected_bytes := 0
	for bgm_entry in bgm_reader.get_entries():
		bgm_expected_bytes += int(bgm_entry.size)
	var bgm_ok: bool = (
		bgm_result.get("ok", false)
		and int(bgm_result.get("count", -1)) == LARGE_BGM_EXPECTED_ENTRIES
		and int(bgm_result.get("bytes", -1)) == bgm_expected_bytes
	)
	if bgm_ok:
		for untyped_row in bgm_result.get("rows", []):
			var row: Dictionary = untyped_row
			if FileAccess.get_sha256(str(row.path)) != bgm_reader.get_entry_fingerprint(str(row.entry)):
				bgm_ok = false
				break
	bgm_reader.close()
	bgm_resolver.close()
	_remove_directory(bgm_output_absolute)
	if not bgm_ok:
		return {"ok": false, "error": "Large-archive bgm.arc stepped extraction did not reproduce the original archive."}

	var peak_after := OS.get_static_memory_peak_usage()
	var peak_growth := peak_after - peak_before
	if peak_growth >= LARGE_PEAK_GROWTH_LIMIT_BYTES:
		return {"ok": false, "error": "Large-archive block grew peak static memory by %d bytes." % peak_growth}

	if FileAccess.get_sha256(voice_path) != voice_source_sha or FileAccess.get_sha256(bgm_path) != bgm_source_sha:
		return {"ok": false, "error": "Large-archive block changed a source archive."}

	return {
		"ok": true,
		"token": "large_cancel_removed=%d large_extract=%d large_peak_mib=%d" % [
			int(voice_cancel_result.get("removed_count", -1)), LARGE_BGM_EXPECTED_ENTRIES, int(peak_growth / (1024 * 1024)),
		],
	}


func _entry_name_list(reader) -> Array[String]:
	var names: Array[String] = []
	for entry in reader.get_entries():
		names.append(str(entry.name))
	return names


func _directory_has_no_files(path: String) -> bool:
	if not DirAccess.dir_exists_absolute(path):
		return true
	var directory := DirAccess.open(path)
	if directory == null:
		return true
	return directory.get_files().is_empty()


func _remove_directory(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	var directory := DirAccess.open(path)
	if directory == null:
		return
	for filename in directory.get_files():
		DirAccess.remove_absolute(path.path_join(filename))
	DirAccess.remove_absolute(path)
