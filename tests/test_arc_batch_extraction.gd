extends "res://tests/test_case.gd"

const ArcReaderScript := preload("res://content_core/arc_reader.gd")
const ContentResolverScript := preload("res://content_core/content_resolver.gd")
const OverlayPackageScript := preload("res://content_core/overlay_package.gd")
const ArcBatchExtractionScript := preload("res://tools/content_suite/arc_batch_extraction.gd")
const SyntheticArc := preload("res://tests/synthetic_arc.gd")

const TEST_ROOT := "user://arc_batch_extraction_test"


func _ready() -> void:
	_cleanup()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEST_ROOT))
	var archive_path := TEST_ROOT.path_join("sample.arc")
	var overlay_root := TEST_ROOT.path_join("overlay")
	var a_data := "alpha".to_ascii_buffer()
	var b_data := "bravo".to_ascii_buffer()
	var c_data := "charlie".to_ascii_buffer()
	SyntheticArc.write_arc(archive_path, [
		{"name": "A.BIN", "data": a_data},
		{"name": "B.BIN", "data": b_data},
		{"name": "C.BIN", "data": c_data},
	])
	var source_sha := FileAccess.get_sha256(archive_path)

	var source_reader := ArcReaderScript.new()
	_check(source_reader.open(archive_path), "batch extraction fixture opens its source ARC")
	var overlay_payload := "beta-overlay".to_ascii_buffer()
	var overlay_package := OverlayPackageScript.new()
	var staged := overlay_package.stage_replacement(
		overlay_root,
		source_reader,
		"sample.arc",
		"B.BIN",
		overlay_payload,
		"remake_only",
		"not_applicable"
	)
	_check(staged.ok, "batch extraction fixture publishes a hash-bound overlay replacement")

	var reader := ArcReaderScript.new()
	_check(reader.open(archive_path), "batch extraction reader opens the synthetic ARC")
	var resolver := ContentResolverScript.new()
	_check(resolver.register_original_archive("sample.arc", archive_path), "batch extraction resolver registers the original ARC")
	_check(resolver.configure_overlay(overlay_root), "batch extraction resolver configures the overlay")

	# Whole-archive extraction: three rows, one overlay and two original, sizes
	# and hashes equal to the effective (post-overlay) bytes.
	var archive_dir := TEST_ROOT.path_join("archive_output")
	var archive_result := ArcBatchExtractionScript.extract_archive(resolver, reader, "sample.arc", archive_dir)
	_check(archive_result.get("ok", false), "whole-archive batch extraction succeeds")
	_check(int(archive_result.get("count", -1)) == 3, "whole-archive batch extracts all three entries")
	_check(int(archive_result.get("overlay_count", -1)) == 1 and int(archive_result.get("original_count", -1)) == 2, "whole-archive batch counts overlay and original entries")
	var rows: Array = archive_result.get("rows", [])
	var row_by_entry: Dictionary = {}
	for untyped_row in rows:
		var row: Dictionary = untyped_row
		row_by_entry[str(row.entry)] = row
	_check(row_by_entry.size() == 3 and row_by_entry.has("A.BIN") and row_by_entry.has("B.BIN") and row_by_entry.has("C.BIN"), "whole-archive batch rows name every entry")
	_check(
		str(row_by_entry.get("A.BIN", {}).get("source", "")) == "original_arc"
		and str(row_by_entry.get("C.BIN", {}).get("source", "")) == "original_arc"
		and str(row_by_entry.get("B.BIN", {}).get("source", "")) == "overlay",
		"whole-archive batch rows report the correct source per entry"
	)
	var expected_sizes := {"A.BIN": a_data.size(), "B.BIN": overlay_payload.size(), "C.BIN": c_data.size()}
	var sizes_ok := true
	var hashes_ok := true
	var total_bytes := 0
	for entry_name in expected_sizes.keys():
		var row: Dictionary = row_by_entry.get(entry_name, {})
		var row_size := int(row.get("size", -1))
		total_bytes += row_size
		if row_size != int(expected_sizes[entry_name]):
			sizes_ok = false
		var row_path := str(row.get("path", ""))
		var on_disk := FileAccess.get_file_as_bytes(row_path)
		if on_disk.size() != row_size or FileAccess.get_sha256(row_path) != str(row.get("sha256", "")):
			hashes_ok = false
	_check(sizes_ok, "whole-archive batch rows report the effective size per entry")
	_check(hashes_ok, "whole-archive batch rows report the sha256 of the effective bytes actually written")
	_check(int(archive_result.get("bytes", -1)) == total_bytes, "whole-archive batch reports the correct byte total")

	# An existing destination is refused before any write.
	var existing_dir := TEST_ROOT.path_join("existing_output")
	var existing_absolute := ProjectSettings.globalize_path(existing_dir).simplify_path()
	DirAccess.make_dir_recursive_absolute(existing_absolute)
	_write_bytes(existing_absolute.path_join("A.BIN"), "pre-existing".to_ascii_buffer())
	var existing_result := ArcBatchExtractionScript.extract_entries(resolver, "sample.arc", ["A.BIN", "C.BIN"], existing_dir)
	_check(not existing_result.get("ok", false) and str(existing_result.get("error", "")).contains("already exists"), "an existing destination is refused before any write")
	_check(not FileAccess.file_exists(existing_absolute.path_join("C.BIN")), "no destination is written when another destination already exists")

	# An unsafe entry name is refused.
	var unsafe_result := ArcBatchExtractionScript.extract_entries(resolver, "sample.arc", ["A.BIN", "BAD/NAME.BIN"], TEST_ROOT.path_join("unsafe_output"))
	_check(not unsafe_result.get("ok", false), "an unsafe entry name is refused")

	# A case-different repeated entry name is refused.
	var repeat_result := ArcBatchExtractionScript.extract_entries(resolver, "sample.arc", ["A.BIN", "a.bin"], TEST_ROOT.path_join("repeat_output"))
	_check(not repeat_result.get("ok", false) and str(repeat_result.get("error", "")).contains("repeats"), "a case-different repeated entry name is refused")

	# An empty extraction list is refused.
	var empty_result := ArcBatchExtractionScript.extract_entries(resolver, "sample.arc", [], TEST_ROOT.path_join("empty_output"))
	_check(not empty_result.get("ok", false), "an empty extraction list is refused")

	# An unresolvable entry name is refused and writes nothing.
	var missing_dir := TEST_ROOT.path_join("missing_output")
	var missing_absolute := ProjectSettings.globalize_path(missing_dir).simplify_path()
	var missing_result := ArcBatchExtractionScript.extract_entries(resolver, "sample.arc", ["MISSING.BIN"], missing_dir)
	_check(not missing_result.get("ok", false), "an unresolvable entry name is refused")
	_check(not FileAccess.file_exists(missing_absolute.path_join("MISSING.BIN")), "an unresolvable entry name writes nothing")

	# Rollback: B.BIN's destination is pre-created as a directory, so it passes
	# the file-absent check but its final publication fails. A's output (which
	# this call did create) is removed; the pre-created directory is untouched.
	var rollback_dir := TEST_ROOT.path_join("rollback_output")
	var rollback_absolute := ProjectSettings.globalize_path(rollback_dir).simplify_path()
	DirAccess.make_dir_recursive_absolute(rollback_absolute)
	DirAccess.make_dir_recursive_absolute(rollback_absolute.path_join("B.BIN"))
	var rollback_result := ArcBatchExtractionScript.extract_entries(resolver, "sample.arc", ["A.BIN", "B.BIN"], rollback_dir)
	_check(
		not rollback_result.get("ok", false)
		and str(rollback_result.get("failed_entry", "")) == "B.BIN"
		and int(rollback_result.get("removed_count", -1)) == 1,
		"extraction rollback reports the failed entry and removed count"
	)
	_check(not FileAccess.file_exists(rollback_absolute.path_join("A.BIN")), "extraction rollback removes the earlier entry it created")
	_check(DirAccess.dir_exists_absolute(rollback_absolute.path_join("B.BIN")), "extraction rollback never touches a destination it did not create")

	_check(FileAccess.get_sha256(archive_path) == source_sha, "batch extraction never changes the source ARC")

	source_reader.close()
	reader.close()
	resolver.close()
	_test_stepped_job()
	_cleanup()
	get_tree().quit(1 if _failed else 0)


func _test_stepped_job() -> void:
	var archive_path := TEST_ROOT.path_join("job_sample.arc")
	var payloads: Dictionary = {}
	var entries: Array[Dictionary] = []
	for letter in ["A", "B", "C", "D", "E"]:
		var data := ("payload-%s" % letter).to_ascii_buffer()
		payloads[letter] = data
		entries.append({"name": "%s.BIN" % letter, "data": data})
	SyntheticArc.write_arc(archive_path, entries)
	var entry_names: Array[String] = ["A.BIN", "B.BIN", "C.BIN", "D.BIN", "E.BIN"]

	var reader := ArcReaderScript.new()
	_check(reader.open(archive_path), "stepped-job reader opens the synthetic ARC")
	var resolver := ContentResolverScript.new()
	_check(resolver.register_original_archive("job_sample.arc", archive_path), "stepped-job resolver registers the original ARC")

	# begin() + repeated step(0) writes exactly one entry per call and reports
	# done/total/bytes/entry.
	var step_dir := TEST_ROOT.path_join("job_step_output")
	var step_job := ArcBatchExtractionScript.begin(resolver, "job_sample.arc", entry_names, step_dir)
	_check(not step_job.is_done(), "a prepared stepped job is not done before any step")
	var initial_progress: Dictionary = step_job.progress()
	_check(
		int(initial_progress.done) == 0 and int(initial_progress.total) == entry_names.size() and str(initial_progress.entry) == "",
		"progress() before the first step reports zero done and an empty entry"
	)
	var cumulative_bytes := 0
	var progress_ok := true
	for step_index in range(entry_names.size()):
		var expected_entry: String = entry_names[step_index]
		var expected_bytes: int = (payloads[expected_entry.get_basename()] as PackedByteArray).size()
		cumulative_bytes += expected_bytes
		var step_progress: Dictionary = step_job.step(0)
		if (
			int(step_progress.done) != step_index + 1
			or int(step_progress.total) != entry_names.size()
			or int(step_progress.bytes) != cumulative_bytes
			or str(step_progress.entry) != expected_entry
		):
			progress_ok = false
	_check(progress_ok, "step(0) writes exactly one entry per call and reports done/total/bytes/entry")
	_check(step_job.is_done(), "a stepped job finishes after writing every entry")
	var stepped_result: Dictionary = step_job.result()
	_check(stepped_result.get("ok", false), "finishing a stepped job by steps succeeds")

	# The stepped result matches extract_entries for the same input, comparing
	# everything except the paths' directory.
	var direct_dir := TEST_ROOT.path_join("job_direct_output")
	var direct_result: Dictionary = ArcBatchExtractionScript.extract_entries(resolver, "job_sample.arc", entry_names, direct_dir)
	_check(direct_result.get("ok", false), "extract_entries succeeds for the same input")
	_check(
		int(stepped_result.count) == int(direct_result.count)
		and int(stepped_result.bytes) == int(direct_result.bytes)
		and int(stepped_result.overlay_count) == int(direct_result.overlay_count)
		and int(stepped_result.pending_count) == int(direct_result.pending_count)
		and int(stepped_result.original_count) == int(direct_result.original_count),
		"a stepped job's summary matches extract_entries for the same input"
	)
	var stepped_rows: Array = stepped_result.rows
	var direct_rows: Array = direct_result.rows
	var rows_match := stepped_rows.size() == direct_rows.size()
	if rows_match:
		for row_index in range(stepped_rows.size()):
			var stepped_row: Dictionary = stepped_rows[row_index]
			var direct_row: Dictionary = direct_rows[row_index]
			if (
				str(stepped_row.entry) != str(direct_row.entry)
				or int(stepped_row.size) != int(direct_row.size)
				or str(stepped_row.sha256) != str(direct_row.sha256)
				or str(stepped_row.source) != str(direct_row.source)
			):
				rows_match = false
	_check(rows_match, "a stepped job's rows match extract_entries row-for-row, ignoring only the output directory")

	# cancel() after two of five entries removes both files, leaves the
	# output directory without them, and a later step does nothing.
	var cancel_dir := TEST_ROOT.path_join("job_cancel_output")
	var cancel_job := ArcBatchExtractionScript.begin(resolver, "job_sample.arc", entry_names, cancel_dir)
	cancel_job.step(0)
	cancel_job.step(0)
	_check(int(cancel_job.progress().done) == 2, "a stepped job reports two entries done before cancellation")
	cancel_job.cancel()
	var cancel_result: Dictionary = cancel_job.result()
	_check(
		not cancel_result.get("ok", false)
		and bool(cancel_result.get("cancelled", false))
		and int(cancel_result.get("removed_count", -1)) == 2,
		"cancel() after two of five entries reports cancelled and removed_count 2"
	)
	var cancel_absolute := ProjectSettings.globalize_path(cancel_dir).simplify_path()
	_check(
		not FileAccess.file_exists(cancel_absolute.path_join("A.BIN"))
		and not FileAccess.file_exists(cancel_absolute.path_join("B.BIN")),
		"cancel() removes the files the job had already written"
	)
	_check(cancel_job.is_done(), "a cancelled job reports done")
	var progress_before_late_step: Dictionary = cancel_job.progress()
	var step_after_cancel: Dictionary = cancel_job.step(1000)
	_check(step_after_cancel == progress_before_late_step, "a step call after cancellation reports unchanged progress")
	_check(cancel_job.result() == cancel_result, "a step call after cancellation does not change the job's result")

	# cancel() after completion changes nothing.
	var completed_dir := TEST_ROOT.path_join("job_completed_output")
	var completed_job := ArcBatchExtractionScript.begin(resolver, "job_sample.arc", entry_names, completed_dir)
	while not completed_job.is_done():
		completed_job.step(1000)
	var completed_result := completed_job.result()
	completed_job.cancel()
	_check(completed_job.result() == completed_result, "cancel() after completion changes nothing")
	var completed_absolute := ProjectSettings.globalize_path(completed_dir).simplify_path()
	_check(FileAccess.file_exists(completed_absolute.path_join("A.BIN")), "cancel() after completion does not remove already-published files")

	# Preparation failures are finished jobs with today's error text.
	var unsafe_job := ArcBatchExtractionScript.begin(resolver, "job_sample.arc", ["A.BIN", "BAD/NAME.BIN"], TEST_ROOT.path_join("job_unsafe_output"))
	_check(
		unsafe_job.is_done()
		and not unsafe_job.result().get("ok", false)
		and str(unsafe_job.result().get("error", "")).contains("unsafe or invalid"),
		"begin() with an unsafe entry name returns an already-finished job with today's error text"
	)
	var repeat_job := ArcBatchExtractionScript.begin(resolver, "job_sample.arc", ["A.BIN", "a.bin"], TEST_ROOT.path_join("job_repeat_output"))
	_check(
		repeat_job.is_done()
		and not repeat_job.result().get("ok", false)
		and str(repeat_job.result().get("error", "")).contains("repeats"),
		"begin() with a case-different repeated entry name returns an already-finished job with today's error text"
	)
	var existing_dir := TEST_ROOT.path_join("job_existing_output")
	var existing_absolute := ProjectSettings.globalize_path(existing_dir).simplify_path()
	DirAccess.make_dir_recursive_absolute(existing_absolute)
	_write_bytes(existing_absolute.path_join("A.BIN"), "pre-existing".to_ascii_buffer())
	var existing_job := ArcBatchExtractionScript.begin(resolver, "job_sample.arc", ["A.BIN", "C.BIN"], existing_dir)
	_check(
		existing_job.is_done()
		and not existing_job.result().get("ok", false)
		and str(existing_job.result().get("error", "")).contains("already exists"),
		"begin() with an existing destination returns an already-finished job with today's error text"
	)

	# A failing entry mid-way still rolls back as today.
	var rollback_dir := TEST_ROOT.path_join("job_rollback_output")
	var rollback_absolute := ProjectSettings.globalize_path(rollback_dir).simplify_path()
	DirAccess.make_dir_recursive_absolute(rollback_absolute)
	DirAccess.make_dir_recursive_absolute(rollback_absolute.path_join("B.BIN"))
	var rollback_job := ArcBatchExtractionScript.begin(resolver, "job_sample.arc", ["A.BIN", "B.BIN"], rollback_dir)
	while not rollback_job.is_done():
		rollback_job.step(1000)
	var rollback_result := rollback_job.result()
	_check(
		not rollback_result.get("ok", false)
		and str(rollback_result.get("failed_entry", "")) == "B.BIN"
		and int(rollback_result.get("removed_count", -1)) == 1,
		"a failing entry mid-way through a stepped job reports the failed entry and removed count"
	)
	_check(not FileAccess.file_exists(rollback_absolute.path_join("A.BIN")), "a failing stepped job removes the earlier entry it created")
	_check(DirAccess.dir_exists_absolute(rollback_absolute.path_join("B.BIN")), "a failing stepped job never touches a destination it did not create")

	reader.close()
	resolver.close()


func _write_bytes(path: String, value: PackedByteArray) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(value)
	file.close()


func _cleanup() -> void:
	_remove_tree(ProjectSettings.globalize_path(TEST_ROOT))
