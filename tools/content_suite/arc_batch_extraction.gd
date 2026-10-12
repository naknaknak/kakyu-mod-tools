class_name KakyuArcBatchExtraction
extends RefCounted

# Multi-entry and complete-archive extraction over the shared content
# resolver. This helper never overwrites an existing output and, when one
# entry fails partway through a batch, removes only the files this call
# itself created before returning the failure.
#
# `extract_entries` and `extract_archive` keep their original, synchronous
# results and signatures. `begin` / `step` / `progress` / `cancel` expose the
# same work as a resumable job, so a caller (the ARC Browser, the Audio ARC
# Editor) can spread the file-writing loop over several frames, show
# progress, and offer cancellation without threads. `extract_entries` is now
# `begin` followed by `step` in a loop with a generous per-call budget.

const ArcReaderScript := preload("res://content_core/arc_reader.gd")


static func extract_entries(resolver, archive_name: String, entry_names: Array, output_directory: String, descriptor_overrides := {}) -> Dictionary:
	var job := begin(resolver, archive_name, entry_names, output_directory, descriptor_overrides)
	while not job.is_done():
		job.step(1000)
	return job.result()


static func extract_archive(resolver, reader, archive_name: String, output_directory: String) -> Dictionary:
	var entry_names: Array[String] = []
	for entry in reader.get_entries():
		entry_names.append(str(entry.name))
	return extract_entries(resolver, archive_name, entry_names, output_directory, {})


## Prepares a batch extraction (validation, directory, resolve, and
## destination-absent checks) and returns a job. A preparation failure
## returns a job that is already finished with that error (`is_done()` true,
## `result()` the same `{ok: false, error}` dictionary `extract_entries` would
## have returned for the same input).
static func begin(resolver, archive_name: String, entry_names: Array, output_directory: String, descriptor_overrides := {}) -> KakyuArcBatchExtraction:
	var job := KakyuArcBatchExtraction.new()
	job._begin(resolver, archive_name, entry_names, output_directory, descriptor_overrides)
	return job


var _resolver
var _descriptors: Array[Dictionary] = []
var _destinations: Array[String] = []
var _created_paths: Array[String] = []
var _rows: Array[Dictionary] = []
var _bytes_total := 0
var _overlay_count := 0
var _pending_count := 0
var _original_count := 0
var _output_absolute := ""
var _next_index := 0
var _total := 0
var _last_entry := ""
var _done := false
var _result: Dictionary = {}


func _begin(resolver, archive_name: String, entry_names: Array, output_directory: String, descriptor_overrides: Dictionary) -> void:
	_total = entry_names.size()
	if entry_names.is_empty():
		_finish({"ok": false, "error": "Extraction entry list is empty."})
		return
	var seen_names: Dictionary = {}
	var overrides_by_upper: Dictionary = {}
	for untyped_key in descriptor_overrides:
		overrides_by_upper[str(untyped_key).to_upper()] = descriptor_overrides[untyped_key]
	for untyped_name in entry_names:
		var entry_name := str(untyped_name)
		if not ArcReaderScript.is_safe_entry_name(entry_name):
			_finish({"ok": false, "error": "Extraction entry name is unsafe or invalid: %s" % entry_name})
			return
		var lookup_name := entry_name.to_upper()
		if seen_names.has(lookup_name):
			_finish({"ok": false, "error": "Extraction list repeats an entry: %s" % entry_name})
			return
		seen_names[lookup_name] = true

	var output_absolute := ProjectSettings.globalize_path(output_directory).simplify_path()
	if not DirAccess.dir_exists_absolute(output_absolute):
		var mkdir_error := DirAccess.make_dir_recursive_absolute(output_absolute)
		if mkdir_error != OK:
			_finish({"ok": false, "error": "Could not create extraction output directory (error %s): %s" % [mkdir_error, output_absolute]})
			return
	if not DirAccess.dir_exists_absolute(output_absolute):
		_finish({"ok": false, "error": "Extraction output directory is not a directory: %s" % output_absolute})
		return

	var descriptors: Array[Dictionary] = []
	var destinations: Array[String] = []
	for untyped_name in entry_names:
		var entry_name := str(untyped_name)
		var descriptor: Dictionary
		if overrides_by_upper.has(entry_name.to_upper()):
			descriptor = overrides_by_upper[entry_name.to_upper()]
		else:
			descriptor = resolver.resolve(archive_name, entry_name)
		if not descriptor.get("ok", false):
			_finish({"ok": false, "error": "Extraction could not resolve %s: %s" % [entry_name, str(descriptor.get("error", ""))]})
			return
		var destination := output_absolute.path_join(str(descriptor.entry))
		descriptors.append(descriptor)
		destinations.append(destination)

	for destination in destinations:
		if FileAccess.file_exists(destination):
			_finish({"ok": false, "error": "Extraction output already exists: %s" % destination})
			return

	_resolver = resolver
	_descriptors = descriptors
	_destinations = destinations
	_output_absolute = output_absolute


## Writes entries until `budget_msec` is spent (always at least one entry per
## call) or the batch ends, then returns `progress()`. A failing entry rolls
## back exactly as `extract_entries` did and finishes the job with the same
## failure dictionary. Calling `step` on an already-finished job only reports
## `progress()`; it never writes or removes anything.
func step(budget_msec := 12) -> Dictionary:
	if not _done:
		var start := Time.get_ticks_msec()
		while _next_index < _descriptors.size():
			var descriptor: Dictionary = _descriptors[_next_index]
			var destination: String = _destinations[_next_index]
			var extracted: Dictionary = _resolver.extract_resolved(descriptor, destination)
			if not extracted.get("ok", false):
				var removed_count := _created_paths.size()
				for created_path in _created_paths:
					if FileAccess.file_exists(created_path):
						DirAccess.remove_absolute(created_path)
				_finish({
					"ok": false,
					"error": "Extraction failed at %s: %s" % [str(descriptor.entry), str(extracted.get("error", ""))],
					"failed_entry": str(descriptor.entry),
					"removed_count": removed_count,
				})
				break
			_created_paths.append(destination)
			var entry_bytes := int(extracted.get("bytes", 0))
			var entry_sha256 := str(extracted.get("sha256", ""))
			var source := str(descriptor.get("source", ""))
			if source == "overlay":
				_overlay_count += 1
			elif source == "fallback":
				_pending_count += 1
			else:
				_original_count += 1
			_bytes_total += entry_bytes
			_last_entry = str(descriptor.entry)
			_rows.append({
				"entry": str(descriptor.entry),
				"path": destination,
				"size": entry_bytes,
				"sha256": entry_sha256,
				"source": source,
			})
			_next_index += 1
			if Time.get_ticks_msec() - start >= budget_msec:
				break
		if not _done and _next_index >= _descriptors.size():
			_finish({
				"ok": true,
				"directory": _output_absolute,
				"count": _rows.size(),
				"bytes": _bytes_total,
				"overlay_count": _overlay_count,
				"pending_count": _pending_count,
				"original_count": _original_count,
				"rows": _rows,
			})
	return progress()


## `{done, total, bytes, entry}`; `entry` is the last entry written, "" before
## the first.
func progress() -> Dictionary:
	return {
		"done": _rows.size(),
		"total": _total,
		"bytes": _bytes_total,
		"entry": _last_entry,
	}


## If the job is not finished, removes every file this job created (the same
## rollback code `step` uses on a failure) and finishes the job with a
## cancellation result. Calling it after the job finished does nothing.
func cancel() -> void:
	if _done:
		return
	var removed_count := _created_paths.size()
	for created_path in _created_paths:
		if FileAccess.file_exists(created_path):
			DirAccess.remove_absolute(created_path)
	_created_paths.clear()
	_finish({
		"ok": false,
		"cancelled": true,
		"error": "Extraction cancelled; removed %d file(s)." % removed_count,
		"removed_count": removed_count,
	})


func is_done() -> bool:
	return _done


## The final result dictionary; `{}` while the job is still running.
func result() -> Dictionary:
	return _result if _done else {}


func _finish(result_dictionary: Dictionary) -> void:
	_done = true
	_result = result_dictionary
