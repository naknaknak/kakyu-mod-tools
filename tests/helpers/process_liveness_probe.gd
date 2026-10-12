extends SceneTree

## Helper for tests/test_process_liveness: "sleep <ready_path>" writes its
## process id and waits to be killed; "check <pid> <image or -> <result_path>"
## asks about a process this helper did not start and records both answers.

const ProcessLivenessScript := preload("res://content_core/process_liveness.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() == 2 and str(arguments[0]) == "sleep":
		_write_text(str(arguments[1]), JSON.stringify({
			"pid": OS.get_process_id(),
			"image": ProcessLivenessScript.current_image_name(),
		}))
		await create_timer(3600.0).timeout
		quit(0)
		return
	if arguments.size() == 4 and str(arguments[0]) == "check":
		var pid := int(arguments[1])
		var image := "" if str(arguments[2]) == "-" else str(arguments[2])
		_write_text(str(arguments[3]), JSON.stringify({
			"shared": ProcessLivenessScript.is_running(pid, image),
			"engine": OS.is_process_running(pid),
		}))
		quit(0)
		return
	quit(2)


func _write_text(path: String, text: String) -> void:
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(text)
	file.close()
	DirAccess.rename_absolute(temporary, path)
