extends "res://tests/test_case.gd"

const ArcReaderScript := preload("res://content_core/arc_reader.gd")
const OverlayPackageScript := preload("res://content_core/overlay_package.gd")
const SyntheticArc := preload("res://tests/synthetic_arc.gd")

const TEST_ROOT := "user://overlay_publication_lock_test"


func _ready() -> void:
	_cleanup()
	var root_absolute := ProjectSettings.globalize_path(TEST_ROOT)
	DirAccess.make_dir_recursive_absolute(root_absolute)
	var archive_path := root_absolute.path_join("voice.arc")
	var overlay_root := root_absolute.path_join("overlay")
	var ready_path := root_absolute.path_join("holder.ready")
	SyntheticArc.write_arc(archive_path, [
		{"name": "LINE.WAV", "data": PackedByteArray([1, 2, 3, 4])},
		{"name": "OTHER.WAV", "data": PackedByteArray([4, 3, 2, 1])},
	])
	var source_sha := FileAccess.get_sha256(archive_path)
	var reader := ArcReaderScript.new()
	_check(reader.open(archive_path), "publication-lock fixture opens its source ARC")

	var holder_args := PackedStringArray([
		"--headless",
		"--path",
		ProjectSettings.globalize_path("res://"),
		"--script",
		"res://tests/helpers/overlay_lock_holder.gd",
		"--",
		overlay_root,
		ready_path,
		archive_path,
		"OTHER.WAV",
	])
	var holder_pid := OS.create_process(OS.get_executable_path(), holder_args)
	_check(holder_pid > 0, "a separate headless publisher process starts")
	for ignored in range(300):
		if FileAccess.file_exists(ready_path) or not OS.is_process_running(holder_pid):
			break
		await get_tree().create_timer(0.01).timeout
	_check(FileAccess.file_exists(ready_path) and OS.is_process_running(holder_pid), "separate publisher owns the manifest lock")
	var competing := OverlayPackageScript.new().stage_replacement(
		overlay_root, reader, "voice.arc", "LINE.WAV", PackedByteArray([5, 6, 7, 8])
	)
	_check(not competing.get("ok", false) and str(competing.get("error", "")).contains("locked by process"), "a second process cannot enter the same manifest publication transaction")
	_check(not FileAccess.file_exists(overlay_root.path_join("manifest.json")), "rejected competing publisher cannot expose a partial manifest while the lock owner is preparing")
	for ignored in range(500):
		if not OS.is_process_running(holder_pid):
			break
		await get_tree().create_timer(0.01).timeout
	_check(not OS.is_process_running(holder_pid), "separate publisher commits its record and releases the lock normally")
	var first_publish := OverlayPackageScript.new().stage_replacement(
		overlay_root, reader, "voice.arc", "LINE.WAV", PackedByteArray([5, 6, 7, 8])
	)
	_check(first_publish.get("ok", false), "publisher succeeds after the other process releases the lock")
	_check(not DirAccess.dir_exists_absolute(overlay_root.path_join(".manifest.lock")), "successful publication removes its lock directory")
	var merged := OverlayPackageScript.new().load_manifest(overlay_root)
	_check(merged.get("ok", false) and merged.manifest.replacements.size() == 2, "second publisher reloads the locked revision and preserves the first process record")

	var stale_lock_path := overlay_root.path_join(".manifest.lock")
	DirAccess.make_dir_absolute(stale_lock_path)
	_write_text(stale_lock_path.path_join("owner.json"), JSON.stringify({
		"schema": "kakyu_workspace_publication_lock/v1",
		"token": "dead-owner",
		"pid": 2147483000,
		"created_unix": int(Time.get_unix_time_from_system()) - 60,
	}) + "\n")
	var manifest_temp := overlay_root.path_join("manifest.json.tmp-2147483000-1")
	var payload_temp_dir := overlay_root.path_join("replacements/voice.arc")
	DirAccess.make_dir_recursive_absolute(payload_temp_dir)
	var payload_temp := payload_temp_dir.path_join("orphan.bin.tmp-2147483000-2")
	_write_bytes(manifest_temp, PackedByteArray([9]))
	_write_bytes(payload_temp, PackedByteArray([9]))
	var recovered_publish := OverlayPackageScript.new().stage_replacement(
		overlay_root, reader, "voice.arc", "LINE.WAV", PackedByteArray([8, 7, 6, 5])
	)
	_check(recovered_publish.get("ok", false), "dead-process manifest lock is quarantined and recovered")
	_check(not FileAccess.file_exists(manifest_temp) and not FileAccess.file_exists(payload_temp), "recovery removes abandoned manifest and payload sibling temporary files")
	_check(not DirAccess.dir_exists_absolute(stale_lock_path), "recovered publication leaves no stale or active lock")

	var package := OverlayPackageScript.new()
	var owned_lock: Dictionary = package._acquire_manifest_lock(overlay_root)
	_check(owned_lock.get("ok", false), "lock owner fixture acquires a publication lock")
	var owner_path := str(owned_lock.get("owner_path", ""))
	var owner_document = JSON.parse_string(FileAccess.get_file_as_string(owner_path))
	owner_document.token = "changed-owner"
	_write_text(owner_path, JSON.stringify(owner_document) + "\n")
	var unsafe_release := package._release_manifest_lock(owned_lock)
	_check(not unsafe_release.get("ok", false) and DirAccess.dir_exists_absolute(stale_lock_path), "publisher refuses to remove a lock whose ownership token changed")
	owner_document.token = str(owned_lock.token)
	_write_text(owner_path, JSON.stringify(owner_document) + "\n")
	_check(package._release_manifest_lock(owned_lock).get("ok", false), "restored owner token permits safe lock release")

	var loaded := OverlayPackageScript.new().load_manifest(overlay_root)
	_check(loaded.get("ok", false) and loaded.manifest.replacements.size() == 2, "recovery retains both valid latest-writer manifest records")
	_check(FileAccess.get_sha256(archive_path) == source_sha, "publication locking and recovery leave the source ARC unchanged")
	reader.close()
	_cleanup()
	get_tree().quit(1 if _failed else 0)


func _write_text(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


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
