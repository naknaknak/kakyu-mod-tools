class_name KakyuArcComparison
extends RefCounted

## Entry-by-entry ARC-to-ARC and ARC-to-overlay comparison (WD-01). It only
## reads: two already-open `KakyuArcReader`s, or one reader plus the resolver
## that already re-verifies every overlay binding before it hands out a
## descriptor. The report it builds is path-free and fingerprinted like
## `KakyuProvenanceReport`, and `write`/`read_path` follow the same
## refuse-existing-output, atomic-publish, bounded-reopen conventions.

const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")
const FingerprintScript := preload("res://content_core/mes_payload_fingerprint.gd")
const ContractValues := preload("res://content_core/contract_values.gd")

const MAX_REPORT_BYTES := 8 * 1024 * 1024

const TOP_LEVEL_KEYS := {
	"schema": true, "core_version": true, "mode": true, "left": true, "right": true,
	"order_preserved": true, "rows": true, "summary": true, "payload_sha256": true,
}
const LEFT_KEYS := {"name": true, "sha256": true, "bytes": true, "entries": true}
const RIGHT_ARCHIVE_KEYS := {"name": true, "sha256": true, "bytes": true, "entries": true}
const RIGHT_OVERLAY_KEYS := {
	"name": true, "sha256": true, "bytes": true, "entries": true, "manifest_editor_version": true,
}
const ROW_KEYS_ARCHIVE := {
	"entry": true, "status": true, "left_index": true, "right_index": true,
	"left_size": true, "right_size": true, "left_sha256": true, "right_sha256": true,
}
const ROW_KEYS_OVERLAY := {
	"entry": true, "status": true, "left_index": true, "right_index": true,
	"left_size": true, "right_size": true, "left_sha256": true, "right_sha256": true,
	"compatibility": true,
}
const SUMMARY_KEYS := {
	"identical": true, "changed": true, "overlay_identical": true,
	"only_left": true, "only_right": true, "total": true,
}
const MODE_VALUES := {"archive": true, "overlay": true}
const STATUS_VALUES := {
	"identical": true, "changed": true, "overlay_identical": true, "only_left": true, "only_right": true,
}
const COMPATIBILITY_VALUES := {
	"": true, "remake_only": true, "original_engine_compatible": true, "original_engine_unverified": true,
}


## Every left entry in left index order, then the right-only entries in right
## index order; names match case-insensitively. When the two archives share
## the same whole-file SHA-256 each entry is hashed once and the hash is
## reused for both sides instead of streamed twice.
static func compare_archives(left_reader, right_reader) -> Dictionary:
	if left_reader == null or not left_reader.is_open():
		return _error("Left ARC reader is not open.")
	if right_reader == null or not right_reader.is_open():
		return _error("Right ARC reader is not open.")
	var left_fp: String = left_reader.get_archive_fingerprint()
	var right_fp: String = right_reader.get_archive_fingerprint()
	if left_fp.is_empty() or right_fp.is_empty():
		return _error("Could not fingerprint an archive for comparison.")
	var same_archive := left_fp == right_fp

	var left_entries: Array[Dictionary] = left_reader.get_entries()
	var right_entries: Array[Dictionary] = right_reader.get_entries()
	var right_by_upper: Dictionary = {}
	for entry in right_entries:
		right_by_upper[str(entry.name).to_upper()] = entry

	var matched_right: Dictionary = {}
	var left_common_order: Array[String] = []
	var rows: Array[Dictionary] = []
	for entry in left_entries:
		var left_name := str(entry.name)
		var upper := left_name.to_upper()
		var right_entry: Dictionary = right_by_upper.get(upper, {})
		if right_entry.is_empty():
			rows.append({
				"entry": left_name,
				"status": "only_left",
				"left_index": int(entry.index),
				"right_index": -1,
				"left_size": int(entry.size),
				"right_size": -1,
				"left_sha256": left_reader.get_entry_fingerprint(left_name),
				"right_sha256": "",
			})
			continue
		matched_right[upper] = true
		left_common_order.append(upper)
		var left_sha: String = left_reader.get_entry_fingerprint(left_name)
		var right_sha: String
		if same_archive:
			right_sha = left_sha
		else:
			right_sha = right_reader.get_entry_fingerprint(str(right_entry.name))
		var status := "identical" if (int(entry.size) == int(right_entry.size) and left_sha == right_sha) else "changed"
		rows.append({
			"entry": left_name,
			"status": status,
			"left_index": int(entry.index),
			"right_index": int(right_entry.index),
			"left_size": int(entry.size),
			"right_size": int(right_entry.size),
			"left_sha256": left_sha,
			"right_sha256": right_sha,
		})

	var right_common_order: Array[String] = []
	for entry in right_entries:
		var upper := str(entry.name).to_upper()
		if matched_right.has(upper):
			right_common_order.append(upper)
			continue
		var right_name := str(entry.name)
		rows.append({
			"entry": right_name,
			"status": "only_right",
			"left_index": -1,
			"right_index": int(entry.index),
			"left_size": -1,
			"right_size": int(entry.size),
			"left_sha256": "",
			"right_sha256": right_reader.get_entry_fingerprint(right_name),
		})

	var order_preserved := left_common_order == right_common_order
	var report := {
		"schema": ContentCoreVersionScript.ARC_COMPARISON_SCHEMA,
		"core_version": ContentCoreVersionScript.CORE_VERSION,
		"mode": "archive",
		"left": _archive_block(left_reader, left_fp, left_entries.size()),
		"right": _archive_block(right_reader, right_fp, right_entries.size()),
		"order_preserved": order_preserved,
		"rows": rows,
		"summary": _summarize(rows),
	}
	report["payload_sha256"] = FingerprintScript.new().fingerprint(report)
	return {"ok": true, "report": report}


## One row per index entry of the opened ARC. `identical` when the resolver
## resolves the entry to the original ARC (no active overlay replacement),
## `changed`/`overlay_identical` when an overlay replacement's re-hashed
## bytes differ from, or match, the original entry's hash. Fails closed
## instead of reporting a row when a bound overlay file no longer matches
## its validated descriptor.
static func compare_overlay(reader, resolver, archive_name: String) -> Dictionary:
	if reader == null or not reader.is_open():
		return _error("ARC reader is not open.")
	var left_fp: String = reader.get_archive_fingerprint()
	if left_fp.is_empty():
		return _error("Could not fingerprint the opened ARC.")
	var snapshot: Dictionary = resolver.get_overlay_snapshot()
	if snapshot.is_empty():
		return _error("An overlay must be loaded before comparing with it.")
	var manifest: Dictionary = snapshot.manifest
	var replacement_count := 0
	for untyped_record in manifest.get("replacements", []):
		if not untyped_record is Dictionary:
			continue
		var record: Dictionary = untyped_record
		if str(record.get("target_archive", "")).to_upper() == archive_name.to_upper():
			replacement_count += 1

	var entries: Array[Dictionary] = reader.get_entries()
	var rows: Array[Dictionary] = []
	for entry in entries:
		var entry_name := str(entry.name)
		var descriptor: Dictionary = resolver.resolve(archive_name, entry_name)
		if not descriptor.get("ok", false):
			return _error(str(descriptor.get("error", "Could not resolve %s for overlay comparison." % entry_name)))
		var original_sha: String = reader.get_entry_fingerprint(entry_name)
		if original_sha.is_empty():
			return _error("Could not fingerprint %s for overlay comparison." % entry_name)
		var row := {
			"entry": entry_name,
			"left_index": int(entry.index),
			"right_index": int(entry.index),
			"left_size": int(entry.size),
			"left_sha256": original_sha,
		}
		var source := str(descriptor.get("source", ""))
		if source == "original_arc":
			row["status"] = "identical"
			row["right_size"] = int(entry.size)
			row["right_sha256"] = original_sha
			row["compatibility"] = ""
		elif source == "overlay":
			var overlay_path := str(descriptor.get("path", ""))
			var descriptor_sha := str(descriptor.get("sha256", ""))
			if overlay_path.is_empty() or not FileAccess.file_exists(overlay_path):
				return _error("Overlay replacement file no longer exists: %s" % entry_name)
			var overlay_file := FileAccess.open(overlay_path, FileAccess.READ)
			if overlay_file == null:
				return _error("Overlay replacement file could not be opened: %s" % entry_name)
			var overlay_size := overlay_file.get_length()
			overlay_file.close()
			var actual_sha := FileAccess.get_sha256(overlay_path)
			if actual_sha.is_empty() or actual_sha != descriptor_sha:
				return _error("Overlay replacement content changed after validation: %s" % entry_name)
			row["right_size"] = overlay_size
			row["right_sha256"] = actual_sha
			row["compatibility"] = str(descriptor.get("compatibility", ""))
			row["status"] = "overlay_identical" if actual_sha == original_sha else "changed"
		else:
			return _error("Overlay comparison does not support resolved source '%s' for %s." % [source, entry_name])
		rows.append(row)

	var report := {
		"schema": ContentCoreVersionScript.ARC_COMPARISON_SCHEMA,
		"core_version": ContentCoreVersionScript.CORE_VERSION,
		"mode": "overlay",
		"left": _archive_block(reader, left_fp, entries.size()),
		"right": {
			"name": archive_name,
			"sha256": "",
			"bytes": -1,
			"entries": replacement_count,
			"manifest_editor_version": str(manifest.get("editor_version", "")),
		},
		"order_preserved": true,
		"rows": rows,
		"summary": _summarize(rows),
	}
	report["payload_sha256"] = FingerprintScript.new().fingerprint(report)
	return {"ok": true, "report": report}


static func write(report: Dictionary, output_path: String) -> Dictionary:
	var output_absolute := ProjectSettings.globalize_path(output_path).simplify_path()
	if FileAccess.file_exists(output_absolute):
		return _error("ARC comparison report output already exists; it was not replaced.")
	var fingerprinter := FingerprintScript.new()
	var bytes := (fingerprinter.canonical_document_json(report) + "\n").to_utf8_buffer()
	var expected_sha := fingerprinter.sha256_bytes(bytes)
	if expected_sha.is_empty():
		return _error("Could not fingerprint the ARC comparison report.")
	var temp_path := "%s.tmp-%s-%s" % [output_absolute, OS.get_process_id(), Time.get_ticks_usec()]
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return _error("Could not create ARC comparison report temporary file (error %s)." % FileAccess.get_open_error())
	file.store_buffer(bytes)
	var write_error := file.get_error()
	file.close()
	if write_error != OK or FileAccess.get_sha256(temp_path) != expected_sha:
		_remove_if_present(temp_path)
		return _error("ARC comparison report temporary file failed verification.")
	if FileAccess.file_exists(output_absolute):
		_remove_if_present(temp_path)
		return _error("ARC comparison report output already exists; it was not replaced.")
	var rename_error := DirAccess.rename_absolute(temp_path, output_absolute)
	if rename_error != OK:
		_remove_if_present(temp_path)
		return _error("Could not publish the ARC comparison report (error %s)." % rename_error)
	if FileAccess.get_sha256(output_absolute) != expected_sha:
		return _error("Published ARC comparison report failed reopen verification.")
	return {"ok": true, "path": output_absolute, "sha256": expected_sha, "bytes": bytes.size()}


static func read_path(path: String) -> Dictionary:
	var absolute := ProjectSettings.globalize_path(path).simplify_path()
	var file := FileAccess.open(absolute, FileAccess.READ)
	if file == null:
		return _error("ARC comparison report could not be opened (error %s)." % FileAccess.get_open_error())
	var size := file.get_length()
	if size <= 0 or size > MAX_REPORT_BYTES:
		file.close()
		return _error("ARC comparison report exceeds its bounded JSON size.")
	var bytes := file.get_buffer(size)
	var read_error := file.get_error()
	file.close()
	if bytes.size() != size or read_error != OK:
		return _error("ARC comparison report changed or was truncated while reading.")
	var parsed = JSON.parse_string(bytes.get_string_from_utf8())
	if not parsed is Dictionary:
		return _error("ARC comparison report must be a JSON object.")
	return _validate_document(parsed)


static func _archive_block(reader, fingerprint: String, entry_count: int) -> Dictionary:
	return {
		"name": reader.archive_path.replace("\\", "/").get_file(),
		"sha256": fingerprint,
		"bytes": int(reader.archive_size),
		"entries": entry_count,
	}


static func _summarize(rows: Array) -> Dictionary:
	var summary := {"identical": 0, "changed": 0, "overlay_identical": 0, "only_left": 0, "only_right": 0}
	for untyped_row in rows:
		var row: Dictionary = untyped_row
		var status := str(row.status)
		summary[status] = int(summary.get(status, 0)) + 1
	summary["total"] = rows.size()
	return summary


static func _validate_document(report: Dictionary) -> Dictionary:
	if not ContractValues.has_exact_key_set(report, TOP_LEVEL_KEYS):
		return _error("ARC comparison report top-level contract is invalid.")
	if str(report.get("schema", "")) != ContentCoreVersionScript.ARC_COMPARISON_SCHEMA:
		return _error("Unsupported ARC comparison report schema.")
	if not report.get("core_version", null) is String or str(report.core_version).is_empty():
		return _error("ARC comparison report core version is invalid.")
	var mode := str(report.get("mode", ""))
	if not MODE_VALUES.has(mode):
		return _error("ARC comparison report mode is invalid.")
	var left = report.get("left", null)
	if not left is Dictionary or not _validate_left_or_archive_right(left):
		return _error("ARC comparison report left block is invalid.")
	var right = report.get("right", null)
	if not right is Dictionary or not _validate_right(right, mode):
		return _error("ARC comparison report right block is invalid.")
	if not report.get("order_preserved", null) is bool:
		return _error("ARC comparison report order_preserved is invalid.")
	if mode == "overlay" and not bool(report.order_preserved):
		return _error("ARC comparison report overlay mode must preserve order.")
	var rows = report.get("rows", null)
	var row_keys := ROW_KEYS_OVERLAY if mode == "overlay" else ROW_KEYS_ARCHIVE
	if not rows is Array or not _validate_rows(rows, row_keys, mode):
		return _error("ARC comparison report rows are invalid.")
	var summary = report.get("summary", null)
	if not summary is Dictionary or not _validate_summary(summary, rows.size()):
		return _error("ARC comparison report summary is invalid.")
	if not ContractValues.is_sha256(str(report.get("payload_sha256", ""))) or FingerprintScript.new().fingerprint(report) != str(report.payload_sha256):
		return _error("ARC comparison report fingerprint does not match its payload.")
	return {"ok": true, "report": report.duplicate(true)}


static func _validate_left_or_archive_right(value: Dictionary) -> bool:
	if not ContractValues.has_exact_key_set(value, LEFT_KEYS):
		return false
	if not value.get("name", null) is String or str(value.name).is_empty():
		return false
	if not ContractValues.is_sha256(str(value.get("sha256", ""))):
		return false
	if not _nonnegative_int(value.get("bytes", null)):
		return false
	if not _nonnegative_int(value.get("entries", null)):
		return false
	return true


static func _validate_right(value: Dictionary, mode: String) -> bool:
	if mode != "overlay":
		return _validate_left_or_archive_right(value)
	if not ContractValues.has_exact_key_set(value, RIGHT_OVERLAY_KEYS):
		return false
	if not value.get("name", null) is String or str(value.name).is_empty():
		return false
	if str(value.get("sha256", "")) != "":
		return false
	if not _integral(value.get("bytes", null)) or int(value.get("bytes", null)) != -1:
		return false
	if not _nonnegative_int(value.get("entries", null)):
		return false
	if not value.get("manifest_editor_version", null) is String or str(value.manifest_editor_version).is_empty():
		return false
	return true


static func _validate_rows(rows: Array, row_keys: Dictionary, mode: String) -> bool:
	for untyped_row in rows:
		if not untyped_row is Dictionary:
			return false
		var row: Dictionary = untyped_row
		if not ContractValues.has_exact_key_set(row, row_keys):
			return false
		if not row.get("entry", null) is String or str(row.entry).is_empty():
			return false
		var status := str(row.get("status", ""))
		if not STATUS_VALUES.has(status):
			return false
		if mode == "overlay" and (status == "only_left" or status == "only_right"):
			return false
		if mode == "archive" and status == "overlay_identical":
			return false
		for index_key in ["left_index", "right_index"]:
			var index_value = row.get(index_key, null)
			if not _integral(index_value) or int(index_value) < -1:
				return false
		for size_key in ["left_size", "right_size"]:
			var size_value = row.get(size_key, null)
			if not _integral(size_value) or int(size_value) < -1:
				return false
		for hash_key in ["left_sha256", "right_sha256"]:
			var hash_value := str(row.get(hash_key, ""))
			if not hash_value.is_empty() and not ContractValues.is_sha256(hash_value):
				return false
		if status == "only_left":
			if int(row.right_index) != -1 or int(row.right_size) != -1 or str(row.right_sha256) != "":
				return false
			if int(row.left_index) < 0 or int(row.left_size) < 0 or str(row.left_sha256).is_empty():
				return false
		elif status == "only_right":
			if int(row.left_index) != -1 or int(row.left_size) != -1 or str(row.left_sha256) != "":
				return false
			if int(row.right_index) < 0 or int(row.right_size) < 0 or str(row.right_sha256).is_empty():
				return false
		else:
			if int(row.left_index) < 0 or int(row.right_index) < 0:
				return false
			if int(row.left_size) < 0 or int(row.right_size) < 0:
				return false
			if str(row.left_sha256).is_empty() or str(row.right_sha256).is_empty():
				return false
		if row_keys.has("compatibility"):
			var compatibility := str(row.get("compatibility", ""))
			if not COMPATIBILITY_VALUES.has(compatibility):
				return false
			if status == "identical" and not compatibility.is_empty():
				return false
	return true


static func _validate_summary(summary: Dictionary, rows_count: int) -> bool:
	if not ContractValues.has_exact_key_set(summary, SUMMARY_KEYS):
		return false
	var total := 0
	for key in ["identical", "changed", "overlay_identical", "only_left", "only_right"]:
		if not _nonnegative_int(summary.get(key, null)):
			return false
		total += int(summary[key])
	if not _nonnegative_int(summary.get("total", null)):
		return false
	return int(summary.total) == total and int(summary.total) == rows_count


static func _nonnegative_int(value) -> bool:
	if value is int:
		return value >= 0
	if value is float:
		return is_finite(value) and value >= 0.0 and value == floor(value)
	return false


## `JSON.parse_string` returns every whole number as a float, so a
## round-tripped document never satisfies a raw `is int` check.
static func _integral(value) -> bool:
	if value is int:
		return true
	if value is float:
		return is_finite(value) and value == floor(value)
	return false


static func _remove_if_present(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


static func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message}
