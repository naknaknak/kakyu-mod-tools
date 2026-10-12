class_name KakyuContentSet
extends RefCounted

const ArcReaderScript := preload("res://content_core/arc_reader.gd")
const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")

const REQUIRED_ARCHIVES := ["mes.arc"]
const KNOWN_ARCHIVES := [
	"mes.arc",
	"mmo.arc",
	"data.arc",
	"bgm.arc",
	"se.arc",
	"voice.arc",
	"tina1.arc",
	"tina2.arc",
]

var root_path := ""
var last_error := ""
var warnings: Array[String] = []

var _readers: Dictionary = {}


func open(path: String) -> bool:
	close()
	last_error = ""
	warnings.clear()
	if path.is_empty():
		return _fail("Content-set directory path is empty.")
	var absolute_root := ProjectSettings.globalize_path(path).simplify_path()
	if not DirAccess.dir_exists_absolute(absolute_root):
		return _fail("Content-set directory does not exist: %s" % path)
	var directory := DirAccess.open(absolute_root)
	if directory == null:
		return _fail("Could not open content-set directory (error %s)." % DirAccess.get_open_error())

	var discovered: Dictionary = {}
	directory.list_dir_begin()
	var file_name := directory.get_next()
	while not file_name.is_empty():
		if not directory.current_is_dir():
			var lookup_name := file_name.to_lower()
			if lookup_name.get_extension() == "arc":
				if discovered.has(lookup_name):
					directory.list_dir_end()
					return _fail("Content set contains case-insensitive duplicate ARC names: %s" % file_name)
				discovered[lookup_name] = file_name
		file_name = directory.get_next()
	directory.list_dir_end()

	for required_name in REQUIRED_ARCHIVES:
		if not discovered.has(required_name):
			return _fail("Content set is missing required archive: %s" % required_name)

	var opened: Dictionary = {}
	for archive_name in KNOWN_ARCHIVES:
		if not discovered.has(archive_name):
			if not archive_name in REQUIRED_ARCHIVES:
				warnings.append("Optional archive is unavailable: %s" % archive_name)
			continue
		var reader := ArcReaderScript.new()
		var archive_path := absolute_root.path_join(str(discovered[archive_name]))
		if not reader.open(archive_path):
			_close_readers(opened)
			return _fail("Content-set archive %s was rejected: %s" % [archive_name, reader.last_error])
		opened[archive_name] = reader

	root_path = absolute_root
	_readers = opened
	return true


func close() -> void:
	_close_readers(_readers)
	_readers.clear()
	root_path = ""
	warnings.clear()


func is_open() -> bool:
	return not root_path.is_empty() and _readers.has("mes.arc")


func has_archive(archive_name: String) -> bool:
	return _readers.has(archive_name.to_lower())


func get_reader(archive_name: String):
	return _readers.get(archive_name.to_lower())


func get_archive_names() -> Array[String]:
	var names: Array[String] = []
	for archive_name in KNOWN_ARCHIVES:
		if _readers.has(archive_name):
			names.append(archive_name)
	return names


func get_summary() -> Dictionary:
	var archives: Array[Dictionary] = []
	for archive_name in get_archive_names():
		var reader = _readers[archive_name]
		archives.append({
			"name": archive_name,
			"bytes": int(reader.archive_size),
			"entries": reader.get_entries().size(),
		})
	return {
		"ok": is_open(),
		"schema": ContentCoreVersionScript.CONTENT_SET_SCHEMA,
		"archive_count": archives.size(),
		"archives": archives,
		"warnings": warnings.duplicate(),
	}


func find_entry(entry_name: String, preferred_archives: Array[String] = []) -> Dictionary:
	if not ArcReaderScript.is_safe_entry_name(entry_name):
		return {"ok": false, "error": "Entry name is unsafe or invalid."}
	var search_order: Array[String] = []
	for archive_name in preferred_archives:
		var normalized := archive_name.to_lower()
		if _readers.has(normalized) and not normalized in search_order:
			search_order.append(normalized)
	for archive_name in get_archive_names():
		if not archive_name in search_order:
			search_order.append(archive_name)
	for archive_name in search_order:
		var reader: KakyuArcReader = _readers[archive_name]
		var entry: Dictionary = reader.get_entry(entry_name)
		if not entry.is_empty():
			return {
				"ok": true,
				"archive": archive_name,
				"entry": entry,
			}
	return {"ok": false, "error": "Content-set entry does not exist: %s" % entry_name}


func read_entry(archive_name: String, entry_name: String) -> PackedByteArray:
	var reader = get_reader(archive_name)
	if reader == null:
		last_error = "Content-set archive is unavailable: %s" % archive_name
		return PackedByteArray()
	var data: PackedByteArray = reader.read_entry(entry_name)
	if data.is_empty() and not reader.last_error.is_empty():
		last_error = reader.last_error
	return data


func _close_readers(readers: Dictionary) -> void:
	for reader in readers.values():
		reader.close()


func _fail(message: String) -> bool:
	last_error = message
	return false
