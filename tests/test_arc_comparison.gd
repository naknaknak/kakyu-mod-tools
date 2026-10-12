extends "res://tests/test_case.gd"

const ArcComparisonScript := preload("res://tools/content_suite/arc_comparison.gd")
const ArcReaderScript := preload("res://content_core/arc_reader.gd")
const ContentResolverScript := preload("res://content_core/content_resolver.gd")
const OverlayPackageScript := preload("res://content_core/overlay_package.gd")
const FingerprintScript := preload("res://content_core/mes_payload_fingerprint.gd")
const SyntheticArc := preload("res://tests/synthetic_arc.gd")

const TEST_ROOT := "user://arc_comparison_test"


func _ready() -> void:
	_cleanup()
	var absolute_root := ProjectSettings.globalize_path(TEST_ROOT)
	DirAccess.make_dir_recursive_absolute(absolute_root)

	_test_archive_mode_mixed(absolute_root)
	_test_archive_mode_identical(absolute_root)
	_test_overlay_mode(absolute_root)
	_test_write_read(absolute_root)

	_cleanup()
	get_tree().quit(1 if _failed else 0)


func _test_archive_mode_mixed(root: String) -> void:
	var left_path := root.path_join("left.arc")
	var right_path := root.path_join("right.arc")
	var a_bytes := "AAAA".to_ascii_buffer()
	var b_bytes := "BBBB".to_ascii_buffer()
	var c_bytes := "CCCC".to_ascii_buffer()
	var a_changed_bytes := "aaaa".to_ascii_buffer()
	var d_bytes := "DDDD".to_ascii_buffer()
	SyntheticArc.write_arc(left_path, [
		{"name": "A.BIN", "data": a_bytes},
		{"name": "B.BIN", "data": b_bytes},
		{"name": "C.BIN", "data": c_bytes},
	])
	SyntheticArc.write_arc(right_path, [
		{"name": "c.bin", "data": c_bytes},
		{"name": "A.BIN", "data": a_changed_bytes},
		{"name": "D.BIN", "data": d_bytes},
	])
	var left_reader := ArcReaderScript.new()
	var right_reader := ArcReaderScript.new()
	_check(left_reader.open(left_path), "mixed compare fixture opens the left ARC")
	_check(right_reader.open(right_path), "mixed compare fixture opens the right ARC")

	var compared := ArcComparisonScript.compare_archives(left_reader, right_reader)
	_check(compared.get("ok", false), "compare_archives succeeds on the mixed fixture")
	var report: Dictionary = compared.report
	_check(str(report.mode) == "archive", "mixed compare reports archive mode")
	_check(not bool(report.order_preserved), "mixed compare reports order not preserved")
	var rows: Array = report.rows
	_check(rows.size() == 4, "mixed compare reports one row per distinct entry")
	var by_entry: Dictionary = {}
	for untyped_row in rows:
		var row: Dictionary = untyped_row
		by_entry[str(row.entry).to_upper()] = row

	var a_row: Dictionary = by_entry.get("A.BIN", {})
	_check(
		str(a_row.get("entry", "")) == "A.BIN" and str(a_row.get("status", "")) == "changed"
		and int(a_row.get("left_index", -9)) == 0 and int(a_row.get("right_index", -9)) == 1
		and int(a_row.get("left_size", -9)) == a_bytes.size() and int(a_row.get("right_size", -9)) == a_changed_bytes.size()
		and str(a_row.get("left_sha256", "")) == left_reader.get_entry_fingerprint("A.BIN")
		and str(a_row.get("right_sha256", "")) == right_reader.get_entry_fingerprint("A.BIN"),
		"mixed compare reports A.BIN changed with both indices and both hashes"
	)
	var b_row: Dictionary = by_entry.get("B.BIN", {})
	_check(
		str(b_row.get("status", "")) == "only_left" and int(b_row.get("left_index", -9)) == 1
		and int(b_row.get("right_index", -9)) == -1 and int(b_row.get("right_size", -9)) == -1
		and str(b_row.get("right_sha256", "")) == "" and not str(b_row.get("left_sha256", "")).is_empty(),
		"mixed compare reports B.BIN only on the left"
	)
	var c_row: Dictionary = by_entry.get("C.BIN", {})
	_check(
		str(c_row.get("entry", "")) == "C.BIN" and str(c_row.get("status", "")) == "identical"
		and int(c_row.get("left_index", -9)) == 2 and int(c_row.get("right_index", -9)) == 0,
		"mixed compare reports C.BIN identical to right's case-different, relocated c.bin using the left spelling"
	)
	var d_row: Dictionary = by_entry.get("D.BIN", {})
	_check(
		str(d_row.get("status", "")) == "only_right" and int(d_row.get("right_index", -9)) == 2
		and int(d_row.get("left_index", -9)) == -1 and int(d_row.get("left_size", -9)) == -1
		and str(d_row.get("left_sha256", "")) == "" and not str(d_row.get("right_sha256", "")).is_empty(),
		"mixed compare reports D.BIN only on the right"
	)
	var summary: Dictionary = report.summary
	_check(
		int(summary.identical) == 1 and int(summary.changed) == 1 and int(summary.overlay_identical) == 0
		and int(summary.only_left) == 1 and int(summary.only_right) == 1 and int(summary.total) == 4,
		"mixed compare summary counts match the fixture"
	)
	_check(
		str(report.left.name) == "left.arc" and str(report.right.name) == "right.arc",
		"mixed compare reports file names only for each side"
	)
	var payload_text := JSON.stringify(report)
	_check(
		not payload_text.contains(root) and not payload_text.contains("user://"),
		"mixed compare report carries no machine path"
	)

	left_reader.close()
	right_reader.close()


func _test_archive_mode_identical(root: String) -> void:
	var source_path := root.path_join("identical_source.arc")
	var copy_path := root.path_join("identical_copy.arc")
	SyntheticArc.write_arc(source_path, [
		{"name": "ONE.BIN", "data": "one".to_ascii_buffer()},
		{"name": "TWO.BIN", "data": "two".to_ascii_buffer()},
	])
	_write_bytes(copy_path, FileAccess.get_file_as_bytes(source_path))
	_check(
		FileAccess.get_sha256(source_path) == FileAccess.get_sha256(copy_path),
		"identical compare fixture copy matches byte for byte"
	)

	var left_reader := ArcReaderScript.new()
	var right_reader := ArcReaderScript.new()
	_check(left_reader.open(source_path), "identical compare fixture opens the source ARC")
	_check(right_reader.open(copy_path), "identical compare fixture opens the copy ARC")

	var compared := ArcComparisonScript.compare_archives(left_reader, right_reader)
	_check(compared.get("ok", false), "compare_archives succeeds on identical archives")
	var report: Dictionary = compared.report
	_check(bool(report.order_preserved), "identical compare preserves order")
	var all_identical := true
	for untyped_row in report.rows:
		var row: Dictionary = untyped_row
		if str(row.status) != "identical":
			all_identical = false
	_check(all_identical and (report.rows as Array).size() == 2, "identical compare reports every row identical")
	var summary: Dictionary = report.summary
	_check(int(summary.identical) == 2 and int(summary.total) == 2, "identical compare summary counts both entries identical")

	left_reader.close()
	right_reader.close()


func _test_overlay_mode(root: String) -> void:
	var archive_path := root.path_join("overlay_source.arc")
	var overlay_root := root.path_join("overlay_pkg")
	var first_original := "first original".to_ascii_buffer()
	var second_original := "second original".to_ascii_buffer()
	var third_original := "third original".to_ascii_buffer()
	SyntheticArc.write_arc(archive_path, [
		{"name": "FIRST.BIN", "data": first_original},
		{"name": "SECOND.BIN", "data": second_original},
		{"name": "THIRD.BIN", "data": third_original},
	])
	var staging_reader := ArcReaderScript.new()
	_check(staging_reader.open(archive_path), "overlay compare fixture opens its source ARC for staging")
	var overlay_package := OverlayPackageScript.new()
	var changed_staged := overlay_package.stage_replacement(
		overlay_root, staging_reader, "overlay_source.arc", "FIRST.BIN",
		"first replacement".to_ascii_buffer(), "remake_only", "not_applicable"
	)
	_check(changed_staged.ok, "overlay compare fixture stages a changed replacement")
	var identical_staged := overlay_package.stage_replacement(
		overlay_root, staging_reader, "overlay_source.arc", "SECOND.BIN",
		second_original, "original_engine_compatible", "not_applicable"
	)
	_check(identical_staged.ok, "overlay compare fixture stages a byte-identical replacement")
	staging_reader.close()

	var reader := ArcReaderScript.new()
	_check(reader.open(archive_path), "overlay compare fixture reopens the ARC for comparison")
	var resolver := ContentResolverScript.new()
	_check(resolver.register_original_archive("overlay_source.arc", archive_path), "overlay compare fixture registers the original ARC")
	_check(resolver.configure_overlay(overlay_root), "overlay compare fixture configures the overlay")

	var bare_resolver := ContentResolverScript.new()
	_check(bare_resolver.register_original_archive("overlay_source.arc", archive_path), "overlay compare fixture registers a bare resolver")
	var no_overlay := ArcComparisonScript.compare_overlay(reader, bare_resolver, "overlay_source.arc")
	_check(not no_overlay.get("ok", false), "compare_overlay fails without a loaded overlay")
	bare_resolver.close()

	var compared := ArcComparisonScript.compare_overlay(reader, resolver, "overlay_source.arc")
	_check(compared.get("ok", false), "compare_overlay succeeds on the staged overlay")
	var report: Dictionary = compared.report
	_check(str(report.mode) == "overlay", "overlay compare reports overlay mode")
	_check(bool(report.order_preserved), "overlay compare always preserves order")
	var by_entry: Dictionary = {}
	for untyped_row in report.rows:
		var row: Dictionary = untyped_row
		by_entry[str(row.entry).to_upper()] = row

	var first_row: Dictionary = by_entry.get("FIRST.BIN", {})
	_check(
		str(first_row.get("status", "")) == "changed" and str(first_row.get("compatibility", "")) == "remake_only"
		and int(first_row.get("left_index", -9)) == 0 and int(first_row.get("right_index", -9)) == 0
		and str(first_row.get("left_sha256", "")) == reader.get_entry_fingerprint("FIRST.BIN")
		and str(first_row.get("right_sha256", "")) != str(first_row.get("left_sha256", "")),
		"overlay compare reports the changed replacement"
	)
	var second_row: Dictionary = by_entry.get("SECOND.BIN", {})
	_check(
		str(second_row.get("status", "")) == "overlay_identical"
		and str(second_row.get("compatibility", "")) == "original_engine_compatible"
		and str(second_row.get("right_sha256", "")) == str(second_row.get("left_sha256", "")),
		"overlay compare reports the byte-identical replacement as overlay_identical"
	)
	var third_row: Dictionary = by_entry.get("THIRD.BIN", {})
	_check(
		str(third_row.get("status", "")) == "identical" and str(third_row.get("compatibility", "")) == ""
		and str(third_row.get("right_sha256", "")) == str(third_row.get("left_sha256", "")),
		"overlay compare reports an unreplaced entry identical with no compatibility"
	)
	var summary: Dictionary = report.summary
	_check(
		int(summary.changed) == 1 and int(summary.overlay_identical) == 1 and int(summary.identical) == 1
		and int(summary.only_left) == 0 and int(summary.only_right) == 0 and int(summary.total) == 3,
		"overlay compare summary counts match the fixture"
	)
	_check(
		str(report.right.name) == "overlay_source.arc" and str(report.right.sha256) == "" and int(report.right.bytes) == -1
		and int(report.right.entries) == 2 and not str(report.right.manifest_editor_version).is_empty(),
		"overlay compare right block reports the overlay identity and its replacement count for this archive"
	)

	var overlay_absolute := ProjectSettings.globalize_path(overlay_root).simplify_path()
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(overlay_absolute.path_join("manifest.json")))
	var first_replacement_path := ""
	for untyped_record in manifest.replacements:
		var record: Dictionary = untyped_record
		if str(record.target_entry).to_upper() == "FIRST.BIN":
			first_replacement_path = overlay_absolute.path_join(str(record.replacement_path))
	_check(not first_replacement_path.is_empty(), "overlay compare fixture locates the staged changed-replacement blob")
	var blob_bytes := FileAccess.get_file_as_bytes(first_replacement_path)
	var tampered_bytes := blob_bytes.duplicate()
	tampered_bytes[tampered_bytes.size() - 1] ^= 0x01
	_write_bytes(first_replacement_path, tampered_bytes)
	var failed_closed := ArcComparisonScript.compare_overlay(reader, resolver, "overlay_source.arc")
	_check(not failed_closed.get("ok", false), "compare_overlay fails closed when a bound replacement blob changed after validation")
	_write_bytes(first_replacement_path, blob_bytes)
	_check(
		FileAccess.get_file_as_bytes(first_replacement_path) == blob_bytes,
		"overlay compare fixture restores the mutated replacement blob"
	)

	reader.close()
	resolver.close()


func _test_write_read(root: String) -> void:
	var left_path := root.path_join("write_left.arc")
	var right_path := root.path_join("write_right.arc")
	SyntheticArc.write_arc(left_path, [{"name": "ONLY.BIN", "data": "payload".to_ascii_buffer()}])
	SyntheticArc.write_arc(right_path, [{"name": "ONLY.BIN", "data": "payload changed".to_ascii_buffer()}])
	var left_reader := ArcReaderScript.new()
	var right_reader := ArcReaderScript.new()
	left_reader.open(left_path)
	right_reader.open(right_path)
	var compared := ArcComparisonScript.compare_archives(left_reader, right_reader)
	_check(compared.get("ok", false), "write/read fixture builds a valid comparison report")
	var report: Dictionary = compared.report
	left_reader.close()
	right_reader.close()

	var output_path := root.path_join("comparison.json")
	var written := ArcComparisonScript.write(report, output_path)
	_check(written.get("ok", false), "write publishes the comparison report")
	var repeat_write := ArcComparisonScript.write(report, output_path)
	_check(
		not repeat_write.get("ok", false) and str(repeat_write.get("error", "")).contains("already exists"),
		"write refuses to replace an existing output"
	)

	var reopened := ArcComparisonScript.read_path(output_path)
	var fingerprinter := FingerprintScript.new()
	_check(
		reopened.get("ok", false)
		and fingerprinter.canonical_document_json(reopened.report) == fingerprinter.canonical_document_json(report),
		"read_path accepts a freshly written report and reproduces it"
	)

	var raw_text := FileAccess.get_file_as_string(output_path)
	_check(
		not raw_text.contains(root) and not raw_text.contains("user://"),
		"written comparison report carries no machine path"
	)

	var tampered_fingerprint_document: Dictionary = JSON.parse_string(raw_text)
	tampered_fingerprint_document.rows[0].left_size = int(tampered_fingerprint_document.rows[0].left_size) + 1
	var tampered_fingerprint_path := root.path_join("tampered_fingerprint.json")
	_write_text(tampered_fingerprint_path, JSON.stringify(tampered_fingerprint_document, "\t") + "\n")
	var tampered_fingerprint_result := ArcComparisonScript.read_path(tampered_fingerprint_path)
	_check(not tampered_fingerprint_result.get("ok", false), "read_path rejects a report with a tampered fingerprint")

	var extra_key_document: Dictionary = JSON.parse_string(raw_text)
	extra_key_document["extra"] = true
	extra_key_document["payload_sha256"] = FingerprintScript.new().fingerprint(extra_key_document)
	var extra_key_path := root.path_join("extra_key.json")
	_write_text(extra_key_path, JSON.stringify(extra_key_document, "\t") + "\n")
	var extra_key_result := ArcComparisonScript.read_path(extra_key_path)
	_check(not extra_key_result.get("ok", false), "read_path rejects a report with an extra top-level key")

	var bad_status_document: Dictionary = JSON.parse_string(raw_text)
	bad_status_document.rows[0].status = "bogus"
	bad_status_document["payload_sha256"] = FingerprintScript.new().fingerprint(bad_status_document)
	var bad_status_path := root.path_join("bad_status.json")
	_write_text(bad_status_path, JSON.stringify(bad_status_document, "\t") + "\n")
	var bad_status_result := ArcComparisonScript.read_path(bad_status_path)
	_check(not bad_status_result.get("ok", false), "read_path rejects a report with an invalid row status")


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
