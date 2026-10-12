class_name KakyuProcessLiveness
extends RefCounted

## Whether a process that another program started is still running.
##
## `OS.is_process_running` only knows the children of the calling process: for
## a live process started by anyone else it answers false. A publication lock
## or an abandoned temporary names the process that made it, and that process
## is normally NOT a child of the one that finds it, so the engine call alone
## reads every foreign owner as dead. This asks the operating system instead
## and answers "running" whenever the question cannot be decided: a lock that
## stays a little too long is a retry, a stolen live lock is lost work.


## True when `pid` names a running process. When `image_name` is given and the
## operating system reports another program under that id, the id was reused
## after the owner ended and the answer is false.
static func is_running(pid: int, image_name := "") -> bool:
	if pid <= 0:
		return false
	if pid == OS.get_process_id():
		return true
	if OS.is_process_running(pid):
		return true
	if OS.get_name() == "Windows":
		return _windows_is_running(pid, image_name)
	return _posix_is_running(pid)


## The executable name an owner record stores beside its process id.
static func current_image_name() -> String:
	return OS.get_executable_path().get_file()


static func _windows_is_running(pid: int, image_name: String) -> bool:
	var output: Array = []
	var code := OS.execute(
		"tasklist", PackedStringArray(["/FI", "PID eq %d" % pid, "/FO", "CSV", "/NH"]), output, true, false
	)
	if code != 0:
		return true
	for row in _csv_rows("".join(output)):
		if row.size() >= 2 and str(row[1]).strip_edges() == str(pid):
			if image_name.is_empty():
				return true
			return str(row[0]).strip_edges().to_lower() == image_name.to_lower()
	return false


static func _posix_is_running(pid: int) -> bool:
	if DirAccess.dir_exists_absolute("/proc/self"):
		return DirAccess.dir_exists_absolute("/proc/%d" % pid)
	var output: Array = []
	var code := OS.execute("ps", PackedStringArray(["-p", str(pid)]), output, true, false)
	if code == -1:
		return true
	return code == 0


## The quoted fields of each CSV line; a line without a quoted field (the
## localized "no tasks" notice) yields no row.
static func _csv_rows(text: String) -> Array:
	var rows: Array = []
	for line in text.replace("\r", "").split("\n", false):
		var fields: Array = []
		var inside := false
		var field := ""
		for character in line:
			if character == "\"":
				if inside:
					fields.append(field)
					field = ""
				inside = not inside
			elif inside:
				field += character
		if not fields.is_empty():
			rows.append(fields)
	return rows
