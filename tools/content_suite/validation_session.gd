class_name KakyuValidationSession
extends RefCounted

const ReportScript := preload("res://tools/content_suite/validation_report.gd")

var _project_root: String
var _python_path: String
var _godot_path: String
var _reports_root: String
var _process_id := -1
var _active_request: Dictionary = {}
var last_result: Dictionary = {}
var spawn_process: Callable = OS.create_process
var process_running: Callable = OS.is_process_running
var process_exit_code: Callable = OS.get_process_exit_code


func _init(project_root := "", python_path := "", godot_path := "", reports_root := "") -> void:
	_project_root = ProjectSettings.globalize_path("res://") if project_root.is_empty() else project_root
	_python_path = find_python() if python_path.is_empty() else python_path
	_godot_path = find_godot() if godot_path.is_empty() else godot_path
	_reports_root = ProjectSettings.globalize_path("user://content_tools/validation") if reports_root.is_empty() else reports_root


func is_running() -> bool:
	return _process_id > 0


func active_request() -> Dictionary:
	return _active_request.duplicate(true)


func availability() -> Dictionary:
	if not FileAccess.file_exists(_project_root.path_join("tools/content_suite/run_headless_validation.py")):
		return {"ok": false, "error": "Validation execution is unavailable: the development runner is absent. Saved reports can still be opened."}
	if _python_path.is_empty() or not FileAccess.file_exists(_python_path):
		return {"ok": false, "error": "Validation execution is unavailable: the Windows py launcher was not found. Saved reports can still be opened."}
	if not FileAccess.file_exists(_godot_path):
		return {"ok": false, "error": "Validation execution is unavailable: the Godot executable is absent."}
	return {"ok": true}


func start(elfimage: String, executable: String) -> Dictionary:
	if is_running():
		return {"ok": false, "error": "A validation run is already active."}
	last_result = {}
	var available := availability()
	if not available.ok:
		return available
	var source := elfimage.strip_edges()
	var native_exe := executable.strip_edges()
	if not source.is_empty():
		source = ProjectSettings.globalize_path(source).simplify_path()
		if not DirAccess.dir_exists_absolute(source):
			return {"ok": false, "error": "The selected ELFIMAGE directory does not exist."}
	if not native_exe.is_empty():
		native_exe = ProjectSettings.globalize_path(native_exe).simplify_path()
		if not FileAccess.file_exists(native_exe):
			return {"ok": false, "error": "The selected original executable does not exist."}
	if DirAccess.make_dir_recursive_absolute(_reports_root) != OK:
		return {"ok": false, "error": "The local validation report directory could not be created."}
	var run_id := _new_run_id()
	var report_path := _reports_root.path_join(run_id + ".json")
	if FileAccess.file_exists(report_path):
		return {"ok": false, "error": "Validation report identity already exists; start again."}
	var arguments := PackedStringArray([
		_project_root.path_join("tools/content_suite/run_headless_validation.py"),
		"--godot", _godot_path, "--report", report_path, "--run-id", run_id,
	])
	if not source.is_empty():
		arguments.append_array(["--elfimage", source])
	if not native_exe.is_empty():
		arguments.append_array(["--exe", native_exe])
	_active_request = {"run_id": run_id, "report_path": report_path, "elfimage": source, "executable": native_exe}
	_process_id = int(spawn_process.call(_python_path, arguments, false))
	if _process_id <= 0:
		return {"ok": false, "error": "The validation process could not be started."}
	return {"ok": true, "request": active_request(), "process_id": _process_id}


func poll() -> Dictionary:
	if not is_running() or bool(process_running.call(_process_id)):
		return {"finished": false}
	var exit_code := int(process_exit_code.call(_process_id))
	_process_id = -1
	var loaded := ReportScript.read_path(str(_active_request.report_path))
	if loaded.ok and (loaded.legacy or loaded.payload.run_id != _active_request.run_id):
		loaded = {"ok": false, "error": "The completed report does not belong to this validation run."}
	if loaded.ok and (not _same_path(loaded.payload.context.elfimage, _active_request.elfimage) or not _same_path(loaded.payload.context.executable, _active_request.executable)):
		loaded = {"ok": false, "error": "The completed report does not match the source selection for this run."}
	if loaded.ok:
		var expected_exit := {"passed": 0, "failed": 1, "configuration_error": 2}
		if exit_code != int(expected_exit[loaded.payload.status]):
			loaded = {"ok": false, "error": "The validation process exit code disagrees with its report."}
	last_result = loaded.duplicate(true)
	return {"finished": true, "result": loaded, "request": active_request(), "exit_code": exit_code}


static func find_python() -> String:
	return preload("res://tools/content_suite/python_runtime.gd").find_python()


static func _same_path(left: String, right: String) -> bool:
	var normalized_left := left.replace("\\", "/").simplify_path()
	var normalized_right := right.replace("\\", "/").simplify_path()
	if OS.get_name() == "Windows":
		normalized_left = normalized_left.to_lower()
		normalized_right = normalized_right.to_lower()
	return normalized_left == normalized_right


static func find_godot() -> String:
	var executable := OS.get_executable_path()
	if not executable.get_basename().ends_with("_console"):
		var console := executable.get_basename() + "_console." + executable.get_extension()
		if FileAccess.file_exists(console):
			return console
	return executable


static func _new_run_id() -> String:
	var bytes := Crypto.new().generate_random_bytes(16)
	bytes[6] = (bytes[6] & 0x0F) | 0x40
	bytes[8] = (bytes[8] & 0x3F) | 0x80
	var hex := bytes.hex_encode()
	return "%s-%s-%s-%s-%s" % [hex.substr(0, 8), hex.substr(8, 4), hex.substr(12, 4), hex.substr(16, 4), hex.substr(20, 12)]
