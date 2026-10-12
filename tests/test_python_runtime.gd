extends Node

const Runtime := preload("res://tools/content_suite/python_runtime.gd")
const Fingerprint := preload("res://content_core/mes_payload_fingerprint.gd")
const Version := preload("res://content_core/content_core_version.gd")
var failures: Array[String] = []
var install: String


func _ready() -> void:
	install = ProjectSettings.globalize_path("user://python-runtime-" + Crypto.new().generate_random_bytes(8).hex_encode())
	var runtime := install.path_join("runtime")
	DirAccess.make_dir_recursive_absolute(runtime.path_join("python"))
	DirAccess.make_dir_recursive_absolute(runtime.path_join("tools"))
	_write("python/python.exe", "fixture")
	_write("tools/tool.py", "pass")
	var rows := []
	for pair in [["python/python.exe",7],["tools/tool.py",4]]:
		rows.append({"path":pair[0],"size":pair[1],"sha256":FileAccess.get_sha256(runtime.path_join(pair[0]))})
	var manifest := {"schema": Runtime.SCHEMA, "core_version": Version.CORE_VERSION, "python_version": "fixture", "pillow_version": "fixture", "files":rows}
	_sign(manifest)
	var command := Runtime.resolve("tools/tool.py", install)
	_check(command.get("ok", false) and command.kind == "bundled" and command.python == runtime.path_join("python/python.exe"), "explicit bundle resolves beside application without host fallback")
	_write("python/python.exe", "changed")
	_check(not Runtime.resolve("tools/tool.py", install).get("ok", true), "modified Python executable is rejected")
	_write("python/python.exe", "fixture")
	_write("tools/unlisted.py", "pass")
	_check(not Runtime.resolve("tools/tool.py", install).get("ok", true), "unlisted importable code is rejected")
	DirAccess.remove_absolute(runtime.path_join("tools/unlisted.py"))
	for script in ["../tool.py", "tools/../tool.py", "tools\\tool.py", "C:/tool.py", "tools/missing.py"]:
		_check(not Runtime.resolve(script, install).get("ok", true), "unsafe or unlisted worker is rejected")
	var changed := manifest.duplicate(true)
	changed.core_version = "old"
	_sign(changed)
	_check(not Runtime.resolve("tools/tool.py", install).get("ok", true), "bundle for another application version is rejected")
	_sign(manifest)
	DirAccess.remove_absolute(runtime.path_join("python/python.exe"))
	_check(not Runtime.resolve("tools/tool.py", install).get("ok", true), "missing bundled executable cannot use installed Python")
	var applications: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://config/distribution/applications_v1.json"))
	var launcher := preload("res://tools/content_suite/application_process.gd")
	for app in applications.applications:
		_check(not launcher.for_scene(str(app.scene), install).get("ok", true), "missing companion app cannot relaunch the current app")
		var file := FileAccess.open(install.path_join(str(app.executable)), FileAccess.WRITE)
		file.store_string("fixture")
		file.close()
		var launched: Dictionary = launcher.for_scene(str(app.scene), install)
		_check(launched.get("ok", false) and launched.arguments.is_empty() and launched.executable == install.path_join(str(app.executable)), "packaged launch uses its named executable without path overrides")
		DirAccess.remove_absolute(install.path_join(str(app.executable)))
	_check(not launcher.for_scene("res://unlisted.tscn", install).get("ok", true), "unlisted scene cannot select a packaged executable")
	for name in ["tools/tool.py", "manifest.json", "python", "tools"]:
		DirAccess.remove_absolute(runtime.path_join(name))
	DirAccess.remove_absolute(runtime)
	DirAccess.remove_absolute(install)
	print(JSON.stringify({"ok":failures.is_empty(),"failures":failures}))
	get_tree().quit(0 if failures.is_empty() else 1)


func _write(path: String, value: String) -> void:
	var file := FileAccess.open(install.path_join("runtime").path_join(path),FileAccess.WRITE)
	file.store_string(value)
	file.close()


func _sign(value: Dictionary) -> void:
	var signed := value.duplicate(true)
	signed.payload_sha256 = Fingerprint.new().fingerprint(value)
	_write("manifest.json",JSON.stringify(signed))


func _check(ok: bool, label: String) -> void:
	if not ok: failures.append(label)
