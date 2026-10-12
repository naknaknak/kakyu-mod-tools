extends "res://tests/test_case.gd"

## The rules that keep a live publication lock from being taken over. They were
## found under full CPU load (WD-17 follow-up): a judgement that an owner is
## dead takes long enough for the lock to change hands meanwhile.

const PublicationLockScript := preload("res://content_core/publication_lock.gd")
const ProcessLivenessScript := preload("res://content_core/process_liveness.gd")

const ROOT := "user://publication_lock_rules_test"
const LOCK_NAME := ".rules.lock"
const DEAD_PID := 2147483000


func _ready() -> void:
	var root := ProjectSettings.globalize_path(ROOT)
	_remove_tree(root)
	DirAccess.make_dir_recursive_absolute(root)
	var lock_path := root.path_join(LOCK_NAME)
	var now := int(Time.get_unix_time_from_system())

	# Acquire and release: the name is free at once and nothing is left behind.
	var held: Dictionary = PublicationLockScript.new().acquire(root, LOCK_NAME)
	_check(held.get("ok", false) and DirAccess.dir_exists_absolute(lock_path), "a free lock is acquired")
	var owner: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(lock_path.path_join("owner.json")))
	_check(
		int(owner.get("pid", 0)) == OS.get_process_id() and str(owner.get("image", "")) == ProcessLivenessScript.current_image_name(),
		"the owner record names this process and its image"
	)
	var second: Dictionary = PublicationLockScript.new().acquire(root, LOCK_NAME)
	_check(
		not second.get("ok", false) and str(second.get("error", "")).contains("locked by process %d" % OS.get_process_id()),
		"a held lock refuses a second acquire and names its holder"
	)
	_check(PublicationLockScript.new().release(held).get("ok", false), "the holder releases its lock")
	_check(not DirAccess.dir_exists_absolute(lock_path) and _leftovers(root).is_empty(), "release frees the name and leaves no retired or stale directory")
	_check(not PublicationLockScript.new().release(held).get("ok", false), "releasing the same lock twice is refused")

	# A young record is respected even when its process is gone: the question
	# "is it dead" is only asked about a record older than the fresh window.
	_write_owner(lock_path, DEAD_PID, now, "fresh-dead")
	var fresh: Dictionary = PublicationLockScript.new().acquire(root, LOCK_NAME)
	_check(
		not fresh.get("ok", false) and str(fresh.get("error", "")).contains("locked by process %d" % DEAD_PID)
		and DirAccess.dir_exists_absolute(lock_path),
		"a record younger than the fresh window is not taken over, dead process or not"
	)
	_remove_tree(lock_path)

	# An old record of a dead process is taken over, and the takeover leaves
	# only the new lock.
	_write_owner(lock_path, DEAD_PID, now - 60, "old-dead")
	var recovered: Dictionary = PublicationLockScript.new().acquire(root, LOCK_NAME)
	_check(recovered.get("ok", false) and bool(recovered.get("recovered_lock", false)), "an old record of a dead process is recovered")
	_check(PublicationLockScript.new().release(recovered).get("ok", false) and _leftovers(root).is_empty(), "the recovered lock releases cleanly")

	# An old record of a LIVE process (this one) is never taken over.
	_write_owner(lock_path, OS.get_process_id(), now - 60, "old-live", ProcessLivenessScript.current_image_name())
	var live: Dictionary = PublicationLockScript.new().acquire(root, LOCK_NAME)
	_check(not live.get("ok", false) and DirAccess.dir_exists_absolute(lock_path), "an old record of a live process is respected")
	_remove_tree(lock_path)

	# A directory without an owner record is inside its grace period.
	DirAccess.make_dir_absolute(lock_path)
	var ownerless: Dictionary = PublicationLockScript.new().acquire(root, LOCK_NAME)
	_check(
		not ownerless.get("ok", false) and str(ownerless.get("error", "")).contains("retry")
		and DirAccess.dir_exists_absolute(lock_path),
		"a lock directory without an owner record is left alone during its grace period and the refusal says retry"
	)
	_remove_tree(lock_path)

	# The release of a lock whose record was replaced is refused and changes nothing.
	var mine: Dictionary = PublicationLockScript.new().acquire(root, LOCK_NAME)
	_write_owner(lock_path, OS.get_process_id(), now, "someone-else", ProcessLivenessScript.current_image_name())
	var foreign_release: Dictionary = PublicationLockScript.new().release(mine)
	_check(
		not foreign_release.get("ok", false) and DirAccess.dir_exists_absolute(lock_path)
		and FileAccess.file_exists(lock_path.path_join("owner.json")),
		"a lock whose owner record names another token is not released by the old holder"
	)

	_remove_tree(root)
	get_tree().quit(1 if _failed else 0)


func _write_owner(lock_path: String, pid: int, created: int, token: String, image := "") -> void:
	DirAccess.make_dir_recursive_absolute(lock_path)
	var record := {
		"schema": "kakyu_workspace_publication_lock/v1", "token": token, "pid": pid, "created_unix": created,
	}
	if not image.is_empty():
		record["image"] = image
	var file := FileAccess.open(lock_path.path_join("owner.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(record) + "\n")
	file.close()


func _leftovers(root: String) -> Array:
	var found: Array = []
	var directory := DirAccess.open(root)
	if directory == null:
		return found
	for name in directory.get_directories():
		if name.contains(".released-") or name.contains(".stale-"):
			found.append(name)
	return found
