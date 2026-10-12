extends "res://tests/test_case.gd"

const ContentSetScript := preload("res://content_core/content_set.gd")
const SyntheticArc := preload("res://tests/synthetic_arc.gd")

const TEST_ROOT := "user://content_set_test"


func _ready() -> void:
	_cleanup()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEST_ROOT))
	var full_root := TEST_ROOT + "/full"
	var missing_root := TEST_ROOT + "/missing"
	var malformed_root := TEST_ROOT + "/malformed"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(full_root))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(missing_root))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(malformed_root))
	SyntheticArc.write_arc(full_root + "/mes.arc", [{"name": "TEST.MES", "data": PackedByteArray([1, 2, 3])}])
	SyntheticArc.write_arc(full_root + "/mmo.arc", [{"name": "BACK.MMO", "data": PackedByteArray([4, 5])}])
	SyntheticArc.write_arc(full_root + "/voice.arc", [{"name": "LINE.OGG", "data": PackedByteArray([6])}])
	SyntheticArc.write_arc(missing_root + "/mmo.arc", [])
	SyntheticArc.write_arc(malformed_root + "/mes.arc", [])
	_write_bytes(malformed_root + "/mmo.arc", PackedByteArray([1, 2, 3]))
	var mes_sha := FileAccess.get_sha256(full_root + "/mes.arc")
	var mmo_sha := FileAccess.get_sha256(full_root + "/mmo.arc")

	var content_set := ContentSetScript.new()
	_check(content_set.open(full_root), "content set opens a directory with required mes.arc")
	_check(content_set.is_open(), "content set reports an open required archive")
	_check(content_set.get_archive_names() == ["mes.arc", "mmo.arc", "voice.arc"], "content set preserves canonical archive order")
	var summary: Dictionary = content_set.get_summary()
	_check(summary.schema == "kakyu_elfimage_content_set/v1" and summary.archive_count == 3, "content set exposes a versioned non-payload summary")
	_check(summary.warnings.size() == 5, "content set reports every unavailable optional archive")
	var found: Dictionary = content_set.find_entry("back.mmo", ["mmo.arc"])
	_check(found.ok and found.archive == "mmo.arc" and found.entry.name == "BACK.MMO", "content set resolves case-insensitive entries in a preferred archive")
	_check(content_set.read_entry("voice.arc", "line.ogg") == PackedByteArray([6]), "content set reads through the shared bounded ARC reader")
	_check(not content_set.find_entry("../unsafe.mmo").ok, "content set rejects unsafe lookup names")
	content_set.close()
	_check(FileAccess.get_sha256(full_root + "/mes.arc") == mes_sha and FileAccess.get_sha256(full_root + "/mmo.arc") == mmo_sha, "content set leaves every source ARC unchanged")

	_check(not content_set.open(missing_root) and content_set.last_error.contains("mes.arc"), "content set rejects a directory without required mes.arc")
	_check(not content_set.open(malformed_root) and content_set.last_error.contains("mmo.arc"), "content set rejects a malformed optional ARC instead of partially opening")

	_cleanup()
	get_tree().quit(1 if _failed else 0)


func _write_bytes(path: String, data: PackedByteArray) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(data)
	file.close()


func _cleanup() -> void:
	var absolute := ProjectSettings.globalize_path(TEST_ROOT)
	if DirAccess.dir_exists_absolute(absolute):
		_remove_tree(absolute)


func _remove_tree(path: String) -> void:
	var directory := DirAccess.open(path)
	if directory == null:
		return
	directory.list_dir_begin()
	var name := directory.get_next()
	while not name.is_empty():
		var child := path.path_join(name)
		if directory.current_is_dir():
			_remove_tree(child)
		else:
			DirAccess.remove_absolute(child)
		name = directory.get_next()
	directory.list_dir_end()
	DirAccess.remove_absolute(path)
