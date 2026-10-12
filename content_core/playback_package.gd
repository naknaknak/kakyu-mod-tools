class_name KakyuPlaybackPackage
extends RefCounted

# Reader for the boundary artifact defined in
# kakyu-remake/docs/spec/tech/playback_package_schema.md (historical v3),
# with this producer's v4 integrity and v5 boundary revisions in
# docs/spec/tech/content_tools.md.
#
# This is the remake's only way in: it opens a package directory, checks the
# schema and the package hash fail-closed, and hands out one code source per
# member entry. Nothing here reads an original archive, and a package that does
# not verify is refused rather than partially loaded.
#
# TD-64 part 2: the reader does not hold the package as parsed documents. The
# load makes one streaming pass over the manifest's entries. For each it reads
# both files, verifies size and SHA-256 against the manifest and keeps the
# verified bytes (about 300 MB for the full package, against about 5.9 GB of
# parsed documents); it parses transiently, runs the document checks, builds
# its code source transiently so a document the source cannot index still
# fails the load, feeds the inventory accumulator and records the metadata the
# eager accessors need (`code_size`, `address_table`, the entry fingerprint).
# Then it lets the parse go. `code_source(entry)` hands out one lazy shell per
# entry for the life of the snapshot; a shell parses its entry from the kept
# bytes on first need, under a bounded cache of parsed sources. The reader
# never reads a file after the load.

const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")
const CodeSourceScript := preload("res://content_core/playback_package_code_source.gd")
const LazyCodeSourceScript := preload("res://content_core/playback_package_lazy_code_source.gd")
const SourceStoreScript := preload("res://content_core/playback_package_source_store.gd")
const IntegrityScript := preload("res://content_core/playback_package_integrity.gd")
const InventoryScript := preload("res://content_core/playback_package_inventory.gd")
const Cp932CodecScript := preload("res://content_core/cp932_codec.gd")

## How many parsed code sources a loaded package keeps at once. A tool decision:
## the largest number of distinct entries one packaged event touches is 15, so
## 32 keeps every event's working set resident, and the worst case (the 32
## largest entries) is about 0.54 GB parsed. Any value of 1 or more is safe.
const DEFAULT_SOURCE_CACHE := 32

var last_error := ""

## The parsed-source cache size. It applies to the loaded snapshot at once and
## to every later load.
var source_cache_limit := DEFAULT_SOURCE_CACHE:
	set(value):
		source_cache_limit = maxi(1, value)
		if _store != null:
			_store.set_limit(source_cache_limit)

var _root := ""
var _manifest: Dictionary = {}
var _entries: Array[String] = []
var _roles: Dictionary = {}
## entry -> {code_size, address_table, entry_sha256}, recorded at load.
var _meta: Dictionary = {}
var _sources: Dictionary = {}
var _store


func load_directory(path: String) -> Dictionary:
	last_error = ""
	var candidate_root := path.replace("\\", "/").trim_suffix("/")
	var manifest := _read_json(candidate_root + "/manifest.json")
	if not manifest.get("ok", false):
		return _error(str(manifest.get("error", "manifest could not be read")))
	var candidate_manifest: Dictionary = manifest.document
	manifest = {}
	var integrity := IntegrityScript.new()
	var problem := integrity.manifest_error(candidate_manifest)
	if not problem.is_empty():
		return _error(problem)
	var file_records := {}
	for file in candidate_manifest.files:
		file_records[str(file.name)] = file
	var inventory := InventoryScript.new()
	var accumulator: Variant = null
	if inventory.carries_blocks(candidate_manifest):
		accumulator = inventory.begin(inventory.manifest_entries(candidate_manifest))
	var candidate_entries: Array[String] = []
	var candidate_roles := {}
	var candidate_meta := {}
	var candidate_sources := {}
	# One codec per load, shared by every entry's code source (TD-64). It is
	# not process-wide: a source's `last_error` must not be shared across loads.
	var text_codec := Cp932CodecScript.new()
	var candidate_store := SourceStoreScript.new(text_codec, source_cache_limit)
	for untyped_report in candidate_manifest.entries:
		var report: Dictionary = untyped_report
		var entry_name := str(report.entry)
		var stem := entry_name.get_basename().to_upper()
		var events_file := _read_member(candidate_root, file_records["events/%s.json" % stem])
		if not events_file.get("ok", false):
			return _error(str(events_file.error))
		var text_file := _read_member(candidate_root, file_records["text/%s.json" % stem])
		if not text_file.get("ok", false):
			return _error(str(text_file.error))
		var document: Dictionary = events_file.document
		var text: Dictionary = text_file.document
		problem = integrity.document_error(document, text, report)
		if not problem.is_empty():
			return _error("%s: %s" % [entry_name, problem])
		# Built to be dropped: a document the source cannot index fails the load
		# here, rather than in the middle of a playback.
		var transient_source := CodeSourceScript.new(document, text.strings, text_codec)
		transient_source = null
		if accumulator != null:
			accumulator.add(entry_name, document, text.strings)
		var offsets: Array[int] = []
		for untyped_offset in document.get("address_table", []):
			offsets.append(int(untyped_offset))
		candidate_entries.append(entry_name)
		candidate_roles[entry_name] = str(report.get("role", ""))
		candidate_meta[entry_name] = {
			"code_size": int(document.get("code_size", 0)),
			"address_table": offsets,
			"entry_sha256": str(document.get("entry_sha256", "")),
		}
		candidate_store.keep(entry_name, events_file.bytes, text_file.bytes)
		candidate_sources[entry_name] = LazyCodeSourceScript.new(
			candidate_store, entry_name, int(document.get("code_size", 0)), offsets,
			str(document.get("kind", "")) == "library", text_codec
		)
	for event in candidate_manifest.events:
		if int(event.start_coordinate) >= int(candidate_meta[event.entry].code_size):
			return _error("Event start coordinate is outside its packaged entry.")
		for terminal in event.terminals:
			var owner := str(terminal.get("owner_entry", event.entry))
			if candidate_meta.has(owner) and int(terminal.offset) > int(candidate_meta[owner].code_size):
				return _error("Terminal coordinate is outside its packaged owner entry.")
	# The inventory blocks are recomputed from the member documents the pass fed
	# above, so this is the one place a reader can check them without an archive.
	if accumulator != null:
		problem = inventory.accumulated_error(candidate_manifest, accumulator.finish())
		if not problem.is_empty():
			return _error(problem)
	# A failed load leaves the complete last verified snapshot available.
	_root = candidate_root
	_manifest = candidate_manifest
	_entries = candidate_entries
	_roles = candidate_roles
	_meta = candidate_meta
	_store = candidate_store
	_sources = candidate_sources
	return {
		"ok": true,
		"schema": str(_manifest.schema),
		"content_core_version": str(_manifest.get("content_core_version", "")),
		"event_ids": event_ids(),
		"entry_count": _entries.size(),
		"package_sha256": str(_manifest.package_sha256),
	}


func manifest() -> Dictionary:
	return _manifest.duplicate(true)


func events() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for untyped_event in _manifest.get("events", []):
		rows.append((untyped_event as Dictionary).duplicate(true))
	return rows


func event_ids() -> Array[String]:
	var ids: Array[String] = []
	for untyped_event in _manifest.get("events", []):
		ids.append(str((untyped_event as Dictionary).get("event_id", "")))
	return ids


func event(event_id: String) -> Dictionary:
	for untyped_event in _manifest.get("events", []):
		var row: Dictionary = untyped_event
		if str(row.get("event_id", "")) == event_id:
			return row.duplicate(true)
	return {}


func entry_names() -> Array[String]:
	return _entries.duplicate()


func role(entry: String) -> String:
	return str(_roles.get(entry, ""))


func has_entry(entry: String) -> bool:
	return _sources.has(entry)


## The entry's code source: one shell per entry for the life of the loaded
## snapshot, so a context that holds it keeps holding the same object across
## evictions of its parsed state. A failed reload leaves it as it was.
func code_source(entry: String) -> KakyuPlaybackPackageCodeSource:
	return _sources.get(entry, null)


func code_size(entry: String) -> int:
	return int(_meta.get(entry, {}).get("code_size", 0))


func address_table(entry: String) -> Array[int]:
	var offsets: Array[int] = []
	offsets.assign(_meta.get(entry, {}).get("address_table", []))
	return offsets


func routines(entry: String) -> Dictionary:
	var source: KakyuPlaybackPackageCodeSource = _sources.get(entry, null)
	return {} if source == null else source.routines()


## The parsed-source cache of the loaded snapshot, for the tests and the
## measurements: `limit`, `resident` (parsed sources held now), `parses` and
## `evictions` (since the snapshot was loaded) and `bytes` (the verified bytes).
func source_cache_stats() -> Dictionary:
	if _store == null:
		return {"limit": source_cache_limit, "resident": 0, "parses": 0, "evictions": 0, "bytes": 0}
	return {
		"limit": _store.limit(), "resident": _store.resident_count(), "parses": _store.parse_count,
		"evictions": _store.eviction_count, "bytes": _store.byte_count(),
	}


# The shared library is addressed by routine id, so a packaged library entry
# presents the same index shape mes_library_runner.gd expects. The registration
# terminal offset is a byte coordinate the package does not carry, and no
# playback path reads it.
func library_index(entry: String) -> Dictionary:
	var source: KakyuPlaybackPackageCodeSource = _sources.get(entry, null)
	if source == null:
		return {"ok": false, "error": "%s is not in this package." % entry}
	var by_id := source.routines()
	var routines: Array[Dictionary] = []
	var ids := by_id.keys()
	ids.sort()
	for routine_id in ids:
		routines.append((by_id[routine_id] as Dictionary).duplicate(true))
	return {
		"ok": true,
		"schema": ContentCoreVersionScript.MES_LIBRARY_INDEX_SCHEMA,
		"registration_count": routines.size(),
		"terminal_offset": -1,
		"routines": routines,
		"by_id": by_id,
	}


# A container document shape for the analysis-side builders that still take one,
# carrying the package code source in place of bytecode.
func container_document(entry: String) -> Dictionary:
	var source: KakyuPlaybackPackageCodeSource = _sources.get(entry, null)
	if source == null:
		return {"ok": false, "error": "%s is not in this package." % entry}
	return {
		"ok": true,
		"bytecode": PackedByteArray(),
		"code_source": source,
		"entry_sha256": str(_meta.get(entry, {}).get("entry_sha256", "")),
		"source": {"archive": "playback_package", "entry": entry},
		"header": {"code_size": code_size(entry), "entry_offsets": address_table(entry)},
	}


func text_strings(entry: String) -> Array:
	return [] if _store == null or not _sources.has(entry) else _store.text_strings(entry)


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "error": "%s does not exist" % path.get_file()}
	var payload := FileAccess.get_file_as_bytes(path)
	if payload.is_empty():
		return {"ok": false, "error": "%s is empty" % path.get_file()}
	var parser := JSON.new()
	if parser.parse(payload.get_string_from_utf8()) != OK:
		return {"ok": false, "error": "%s is not valid JSON" % path.get_file()}
	if not parser.data is Dictionary:
		return {"ok": false, "error": "%s is not a JSON object" % path.get_file()}
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(payload)
	return {"ok": true, "document": parser.data as Dictionary, "bytes": payload, "size": payload.size(), "sha256": context.finish().hex_encode()}


## One member file, read once: the bytes are the ones the manifest's size and
## SHA-256 were checked against, and are what the store keeps.
func _read_member(root: String, file: Dictionary) -> Dictionary:
	var loaded := _read_json(root.path_join(str(file.name)))
	if not loaded.get("ok", false):
		return {"ok": false, "error": str(loaded.get("error", "Package file could not be read."))}
	if loaded.sha256 != file.sha256 or int(loaded.size) != int(file.size):
		return {"ok": false, "error": "Package file %s does not match the manifest fingerprint." % file.name}
	return loaded


func _error(message: String) -> Dictionary:
	last_error = message
	return {"ok": false, "error": message}
