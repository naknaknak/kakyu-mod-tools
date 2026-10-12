class_name KakyuPublicationLock
extends RefCounted

const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")
const ProcessLivenessScript := preload("res://content_core/process_liveness.gd")

const OWNER_FILENAME := "owner.json"
const SCHEMA := ContentCoreVersionScript.WORKSPACE_PUBLICATION_LOCK_SCHEMA
const ORPHAN_GRACE_SECONDS := 30
const CREATE_ATTEMPTS := 5
const CREATE_RETRY_MSEC := 5
const RELEASE_ATTEMPTS := 400
const RELEASE_RETRY_MSEC := 5
const OWNER_READ_ATTEMPTS := 20
const FRESH_OWNER_SECONDS := 3


func acquire(root_path: String, lock_directory_name: String) -> Dictionary:
	var root_absolute := ProjectSettings.globalize_path(root_path).simplify_path()
	if root_absolute.is_empty() or not _safe_lock_name(lock_directory_name):
		return _error("Publication lock root or name is invalid.")
	var directory_error := DirAccess.make_dir_recursive_absolute(root_absolute)
	if directory_error != OK:
		return _error("Could not create publication root (error %s)." % directory_error)
	var lock_path := root_absolute.path_join(lock_directory_name)
	var recovered := false
	var create_error := DirAccess.make_dir_absolute(lock_path)
	# A directory that another process is removing at this instant refuses the
	# create without existing any more; that is a lock changing hands, not a
	# broken root, so try again briefly before reporting it.
	var attempt := 1
	while create_error != OK and not DirAccess.dir_exists_absolute(lock_path) and attempt < CREATE_ATTEMPTS:
		OS.delay_msec(CREATE_RETRY_MSEC)
		create_error = DirAccess.make_dir_absolute(lock_path)
		attempt += 1
	if create_error != OK:
		if not DirAccess.dir_exists_absolute(lock_path):
			return _error("Could not create publication lock (error %s); retry." % create_error)
		var recovery := _recover_stale(lock_path)
		if not recovery.ok:
			return recovery
		recovered = true
		create_error = DirAccess.make_dir_absolute(lock_path)
		if create_error != OK:
			return _error("Publication is locked by another process; retry after it completes.")
	var token := "%s-%s-%s" % [OS.get_process_id(), Time.get_unix_time_from_system(), Time.get_ticks_usec()]
	var owner_path := lock_path.path_join(OWNER_FILENAME)
	var owner := {
		"schema": SCHEMA,
		"token": token,
		"pid": OS.get_process_id(),
		"image": ProcessLivenessScript.current_image_name(),
		"created_unix": int(Time.get_unix_time_from_system()),
	}
	var owner_file := FileAccess.open(owner_path, FileAccess.WRITE)
	if owner_file == null:
		DirAccess.remove_absolute(lock_path)
		return _error("Could not write publication lock owner; retry.")
	owner_file.store_string(JSON.stringify(owner) + "\n")
	var owner_error := owner_file.get_error()
	owner_file.close()
	if owner_error != OK:
		_remove_file(owner_path)
		DirAccess.remove_absolute(lock_path)
		return _error("Could not write publication lock owner; retry.")
	return {
		"ok": true,
		"path": lock_path,
		"owner_path": owner_path,
		"token": token,
		"recovered_lock": recovered,
	}


func release(lock: Dictionary) -> Dictionary:
	var lock_path := str(lock.get("path", ""))
	var owner_path := str(lock.get("owner_path", ""))
	var token := str(lock.get("token", ""))
	if lock_path.is_empty() or owner_path.is_empty() or token.is_empty():
		return _error("Publication lock descriptor is invalid.")
	# A contender that is reading the owner record at this instant can make one
	# read fail; only a record that stays unreadable or names another token
	# means the lock is no longer ours.
	var owner_result := _read_owner(owner_path)
	var read_attempt := 1
	while not owner_result.ok and read_attempt < OWNER_READ_ATTEMPTS and DirAccess.dir_exists_absolute(lock_path):
		OS.delay_msec(RELEASE_RETRY_MSEC)
		owner_result = _read_owner(owner_path)
		read_attempt += 1
	if not owner_result.ok or str(owner_result.owner.get("token", "")) != token:
		return _error("Publication lock ownership changed before release.")
	# Release is one rename: the lock name is free the moment it succeeds, and
	# the owner record is never missing from a directory that still holds the
	# lock name (an ownerless lock directory reads as a crash to everyone else).
	# A contender probing the directory can refuse the rename for an instant.
	var retired := "%s.released-%s-%s" % [lock_path, OS.get_process_id(), Time.get_ticks_usec()]
	var rename_error := DirAccess.rename_absolute(lock_path, retired)
	var release_attempt := 1
	while rename_error != OK and release_attempt < RELEASE_ATTEMPTS:
		OS.delay_msec(RELEASE_RETRY_MSEC)
		rename_error = DirAccess.rename_absolute(lock_path, retired)
		release_attempt += 1
	if rename_error != OK:
		return _error("Could not release publication lock (error %s); it stays held until this process ends." % rename_error)
	_remove_tree(retired)
	return {"ok": true}


func _recover_stale(lock_path: String) -> Dictionary:
	var owner_path := lock_path.path_join(OWNER_FILENAME)
	var owner_result := _read_owner(owner_path)
	var judged_token := ""
	if owner_result.ok:
		var pid := int(owner_result.owner.get("pid", -1))
		var image := str(owner_result.owner.get("image", ""))
		var created := int(owner_result.owner.get("created_unix", 0))
		# A record this young belongs to a holder in the middle of its work.
		# Asking the operating system costs far longer than a normal hold, and
		# an answer that arrives after the holder has released and another
		# process has taken the name would be applied to the wrong owner.
		if int(Time.get_unix_time_from_system()) - created < FRESH_OWNER_SECONDS:
			return _error("Publication is locked by process %d; retry after it completes." % pid)
		if pid > 0 and ProcessLivenessScript.is_running(pid, image):
			return _error("Publication is locked by process %d; retry after it completes." % pid)
		# The owner is judged dead. The judgement took time: make sure the record
		# in place is still the one that was judged.
		judged_token = str(owner_result.owner.get("token", ""))
		var again := _read_owner(owner_path)
		if not again.ok or str(again.owner.get("token", "")) != judged_token:
			return _error("Publication lock changed during stale recovery; retry.")
	else:
		if not DirAccess.dir_exists_absolute(lock_path):
			return {"ok": true, "recovered": false}
		# An age that cannot be read is not an old age: only a lock directory
		# known to have sat without an owner record for the whole grace period
		# is taken over.
		var modified := int(FileAccess.get_modified_time(lock_path))
		var age := int(Time.get_unix_time_from_system()) - modified
		if modified <= 0 or age < ORPHAN_GRACE_SECONDS:
			return _error("Publication lock is incomplete and still within its recovery grace period; retry shortly.")
	var quarantine := "%s.stale-%s-%s" % [lock_path, OS.get_process_id(), Time.get_ticks_usec()]
	var rename_error := DirAccess.rename_absolute(lock_path, quarantine)
	if rename_error != OK:
		return _error("Publication lock changed during stale recovery; retry.")
	# What was taken must be what was judged. A directory that turns out to
	# hold another owner's record is a live lock caught in the instant between
	# the check and the rename: it goes back under its name if the name is
	# still free, and this attempt ends either way.
	var taken := _read_owner(quarantine.path_join(OWNER_FILENAME))
	var taken_token := str(taken.owner.get("token", "")) if taken.ok else ""
	if taken_token != judged_token:
		DirAccess.rename_absolute(quarantine, lock_path)
		return _error("Publication lock changed during stale recovery; retry.")
	_remove_tree(quarantine)
	return {"ok": true, "recovered": true}


func _read_owner(owner_path: String) -> Dictionary:
	if not FileAccess.file_exists(owner_path):
		return _error("Publication lock owner is missing.")
	var file := FileAccess.open(owner_path, FileAccess.READ)
	if file == null or file.get_length() > 4096:
		if file != null:
			file.close()
		return _error("Publication lock owner is invalid.")
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if (
		not parsed is Dictionary
		or str(parsed.get("schema", "")) != SCHEMA
		or str(parsed.get("token", "")).is_empty()
		or int(parsed.get("pid", -1)) <= 0
		or int(parsed.get("created_unix", -1)) <= 0
	):
		return _error("Publication lock owner is invalid.")
	return {"ok": true, "owner": parsed}


func _safe_lock_name(value: String) -> bool:
	return not value.is_empty() and not value.contains("/") and not value.contains("\\") and not value.contains(":") and value not in [".", ".."]


func _remove_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


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


func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message}
