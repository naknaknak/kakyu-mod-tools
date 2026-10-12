extends Node

## Shared base of the test scenes (TD-05).
##
## A test script extends this file by path instead of `Node`, reports each
## assertion through `_check` and ends with
## `get_tree().quit(1 if _failed else 0)`. A test that counts its checks or
## failures differently keeps `extends Node` and its own `_check`. Hashing
## helpers stay in each test on purpose: a test must not verify the shared
## hashers with themselves.

## Hang guard for a background authoring process a test waits on (TD-38).
## It is not a performance budget: the runner's per-check timeout bounds the
## whole check, and this only stops a test from waiting forever on a process
## that never exits. About four times the roughly 60 s a two-step sequence
## compile of an original entry measures (TD-38, `todo/code_health.md`), so an
## ordinary slow machine passes and a genuine hang still fails well inside the
## runner's per-check bound. A compile approaching it is a speed item, not a reason
## to raise it.
const AUTHORING_HANG_GUARD_SECONDS := 240

var _failed := false


## Elapsed seconds against the hang guard, for the wait's own output so that
## compile-time drift is visible in batch logs.
static func authoring_wait_note(started_msec: int) -> String:
	return "%.1f s elapsed, hang guard %d s" % [float(Time.get_ticks_msec() - started_msec) / 1000.0, AUTHORING_HANG_GUARD_SECONDS]


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
	else:
		_failed = true
		push_error("FAIL: " + label)


## Delete a directory tree; a missing directory is not an error.
func _remove_tree(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	var directory := DirAccess.open(path)
	if directory == null:
		return
	for subdirectory in directory.get_directories():
		_remove_tree(path.path_join(subdirectory))
	for filename in directory.get_files():
		DirAccess.remove_absolute(path.path_join(filename))
	DirAccess.remove_absolute(path)
