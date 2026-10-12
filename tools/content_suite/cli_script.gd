extends SceneTree

## Shared base of the headless scripts under `cli/` and `validators/` (TD-05).
##
## A script extends this file by path instead of `SceneTree` and inherits the
## failure exit and the bounded read that every script used to copy. GDScript
## refuses an override with a different signature, so a script whose `_fail`
## takes other arguments (a reader to close, a JSON error line) keeps
## `extends SceneTree` and its own copy.


## Report `message` as an error and end the run with `code`.
func _fail(message: String, code := 1) -> void:
	push_error(message)
	quit(code)


## The whole file when it exists, is not empty and is at most `limit` bytes;
## no bytes otherwise.
func _read_bounded(path: String, limit: int) -> PackedByteArray:
	if not FileAccess.file_exists(path):
		return PackedByteArray()
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() <= 0 or file.get_length() > limit:
		if file != null:
			file.close()
		return PackedByteArray()
	var bytes := file.get_buffer(file.get_length())
	var read_error := file.get_error()
	file.close()
	return bytes if read_error == OK else PackedByteArray()
