extends SceneTree

## WD-17 multi-process worker: stages a workspace replacement or holds the
## workspace + manifest locks (with abandoned temporaries) until killed.
##
## User arguments:
## <workspace_root> <content_set_root> <archive> <entry> <payload_hex> <mode> <ready_path> <result_path>

const ContentWorkspaceScript := preload("res://content_core/content_workspace.gd")
const OverlayPackageScript := preload("res://content_core/overlay_package.gd")
const PublicationLockScript := preload("res://content_core/publication_lock.gd")

const RETRY_WAIT_SECONDS := 0.05
const RETRY_TIMEOUT_SECONDS := 20.0
const HOLD_SECONDS := 3600.0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() != 8:
		quit(2)
		return
	var workspace_root := str(arguments[0])
	var content_set_root := str(arguments[1])
	var archive := str(arguments[2])
	var entry := str(arguments[3])
	var payload_hex := str(arguments[4])
	var mode := str(arguments[5])
	var ready_path := str(arguments[6])
	var result_path := str(arguments[7])
	if mode == "stage":
		await _run_stage(workspace_root, content_set_root, archive, entry, payload_hex, result_path)
	elif mode == "hold":
		await _run_hold(workspace_root, archive, ready_path)
	else:
		quit(2)


func _run_stage(
	workspace_root: String,
	content_set_root: String,
	archive: String,
	entry: String,
	payload_hex: String,
	result_path: String
) -> void:
	var payload: PackedByteArray = payload_hex.hex_decode()
	var attempts := 0
	var start_ticks := Time.get_ticks_msec()
	var ok := false
	var error := ""
	var generation_sha256 := ""
	while true:
		attempts += 1
		var workspace := ContentWorkspaceScript.new()
		var retryable := false
		var opened := workspace.open(workspace_root, content_set_root)
		if not opened.get("ok", false):
			error = str(opened.get("error", ""))
			retryable = error.contains("locked by process") or error.contains("retry")
		else:
			var staged := workspace.stage_replacements(archive, {entry: payload}, "remake_only", "not_applicable")
			if staged.get("ok", false):
				ok = true
				error = ""
				generation_sha256 = str(staged.snapshot.generation_sha256)
			else:
				error = str(staged.get("error", ""))
				retryable = error.contains("locked by process") or error.contains("retry")
		workspace.close()
		if ok:
			break
		var elapsed_seconds := float(Time.get_ticks_msec() - start_ticks) / 1000.0
		if not retryable or elapsed_seconds >= RETRY_TIMEOUT_SECONDS:
			break
		await create_timer(RETRY_WAIT_SECONDS).timeout
	var result := {
		"ok": ok,
		"attempts": attempts,
		"error": error,
		"generation_sha256": generation_sha256,
	}
	_write_result_atomic(result_path, result)
	quit(0 if ok else 6)


func _run_hold(workspace_root: String, archive: String, ready_path: String) -> void:
	var root_absolute := ProjectSettings.globalize_path(workspace_root).simplify_path()
	var workspace_lock := PublicationLockScript.new().acquire(root_absolute, ContentWorkspaceScript.WORKSPACE_LOCK_DIRECTORY)
	if not workspace_lock.get("ok", false):
		quit(3)
		return
	var manifest_lock := PublicationLockScript.new().acquire(root_absolute, OverlayPackageScript.MANIFEST_LOCK_DIRECTORY)
	if not manifest_lock.get("ok", false):
		PublicationLockScript.new().release(workspace_lock)
		quit(3)
		return
	var pid := OS.get_process_id()
	var manifest_temp_path := root_absolute.path_join("manifest.json.tmp-%d-1" % pid)
	if not _write_bytes(manifest_temp_path, "abandoned manifest temporary".to_utf8_buffer()):
		PublicationLockScript.new().release(manifest_lock)
		PublicationLockScript.new().release(workspace_lock)
		quit(4)
		return
	var payload_directory := root_absolute.path_join("replacements").path_join(archive)
	if DirAccess.make_dir_recursive_absolute(payload_directory) != OK:
		PublicationLockScript.new().release(manifest_lock)
		PublicationLockScript.new().release(workspace_lock)
		quit(4)
		return
	var payload_temp_path := payload_directory.path_join("orphan.bin.tmp-%d-2" % pid)
	if not _write_bytes(payload_temp_path, "abandoned payload temporary".to_utf8_buffer()):
		PublicationLockScript.new().release(manifest_lock)
		PublicationLockScript.new().release(workspace_lock)
		quit(4)
		return
	var ready := FileAccess.open(ready_path, FileAccess.WRITE)
	if ready == null:
		PublicationLockScript.new().release(manifest_lock)
		PublicationLockScript.new().release(workspace_lock)
		quit(4)
		return
	ready.store_string(str(pid))
	ready.close()
	await create_timer(HOLD_SECONDS).timeout


func _write_bytes(path: String, data: PackedByteArray) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_buffer(data)
	var write_error := file.get_error()
	file.close()
	return write_error == OK


func _write_result_atomic(result_path: String, result: Dictionary) -> void:
	var temp_path := "%s.tmp-%d-%d" % [result_path, OS.get_process_id(), Time.get_ticks_usec()]
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(result, "  ") + "\n")
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		if FileAccess.file_exists(temp_path):
			DirAccess.remove_absolute(temp_path)
		return
	DirAccess.rename_absolute(temp_path, result_path)
