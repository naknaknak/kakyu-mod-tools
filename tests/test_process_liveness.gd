extends "res://tests/test_case.gd"

const ProcessLivenessScript := preload("res://content_core/process_liveness.gd")

const ROOT := "user://process_liveness_test"
const HELPER := "res://tests/helpers/process_liveness_probe.gd"


func _ready() -> void:
	var root := ProjectSettings.globalize_path(ROOT)
	_remove_tree(root)
	DirAccess.make_dir_recursive_absolute(root)

	_check(not ProcessLivenessScript.is_running(0), "process id zero is never running")
	_check(not ProcessLivenessScript.is_running(-5), "a negative process id is never running")
	_check(ProcessLivenessScript.is_running(OS.get_process_id()), "the calling process is running")
	_check(
		ProcessLivenessScript.is_running(OS.get_process_id(), "some-other-program.exe"),
		"the calling process is running whatever image name the record carries"
	)
	_check(not ProcessLivenessScript.is_running(2147483000), "an id no process has is not running")
	_check(not ProcessLivenessScript.current_image_name().is_empty(), "the current image name is known")

	var rows: Array = ProcessLivenessScript._csv_rows(
		"\"Godot.exe\",\"4242\",\"Console\",\"1\",\"6,520 K\"\r\nINFO: no tasks are running\r\n"
	)
	_check(
		rows.size() == 1 and rows[0].size() == 5 and rows[0][0] == "Godot.exe" and rows[0][1] == "4242" and rows[0][4] == "6,520 K",
		"task list rows keep quoted commas and skip the unquoted notice line"
	)

	# A sleeper this test starts, asked about by a checker this test also
	# starts: the two are strangers to each other, the case the engine's own
	# call cannot answer.
	var ready_path := root.path_join("sleeper.json")
	var sleeper_pid := _spawn(["sleep", ready_path])
	_check(sleeper_pid > 0 and await _await_file(ready_path), "a sleeper process starts and reports itself")
	var sleeper: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ready_path))
	var reported_pid := int(sleeper.get("pid", 0))
	var reported_image := str(sleeper.get("image", ""))
	_check(reported_pid > 0 and not reported_image.is_empty(), "the sleeper names its process id and image")

	var live := await _ask(root, "live", reported_pid, "-")
	_check(live.get("shared", false) == true, "a stranger finds the live sleeper running")
	print("INFO: engine answer about a live stranger = ", live.get("engine"))
	var live_image := await _ask(root, "live_image", reported_pid, reported_image)
	_check(live_image.get("shared", false) == true, "a stranger finds the live sleeper running under its own image name")
	var reused := await _ask(root, "reused", reported_pid, "some-other-program.exe")
	_check(reused.get("shared", true) == false, "the same id under another image name is a reused id, not the owner")

	OS.kill(sleeper_pid)
	OS.kill(reported_pid)
	for ignored in range(200):
		if not ProcessLivenessScript.is_running(reported_pid, reported_image):
			break
		await get_tree().create_timer(0.05).timeout
	var dead := await _ask(root, "dead", reported_pid, reported_image)
	_check(dead.get("shared", true) == false, "a stranger finds the killed sleeper gone")

	_remove_tree(root)
	get_tree().quit(1 if _failed else 0)


func _spawn(user_arguments: Array) -> int:
	var arguments := PackedStringArray([
		"--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", HELPER, "--",
	])
	for argument in user_arguments:
		arguments.append(str(argument))
	return OS.create_process(OS.get_executable_path(), arguments)


func _ask(root: String, label: String, pid: int, image: String) -> Dictionary:
	var result_path := root.path_join("check_%s.json" % label)
	var checker := _spawn(["check", pid, image, result_path])
	if checker <= 0 or not await _await_file(result_path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(result_path))
	return parsed if parsed is Dictionary else {}


func _await_file(path: String) -> bool:
	for ignored in range(400):
		if FileAccess.file_exists(path):
			return true
		await get_tree().create_timer(0.05).timeout
	return false
