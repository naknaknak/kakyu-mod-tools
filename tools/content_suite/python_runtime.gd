extends RefCounted

const FingerprintScript := preload("res://content_core/mes_payload_fingerprint.gd")
const VersionScript := preload("res://content_core/content_core_version.gd")
const SCHEMA := "kakyu_python_runtime/v1"


static func resolve(script: String, install_root := "") -> Dictionary:
	if not _relative(script) or not script.begins_with("tools/") or not script.ends_with(".py"):
		return {"ok": false, "error": "Python tool path is invalid."}
	if install_root.is_empty() and OS.has_feature("editor"):
		var path := ProjectSettings.globalize_path("res://" + script)
		var python := _development_python()
		if python.is_empty() or not FileAccess.file_exists(path):
			return {"ok": false, "error": "The development Python launcher or tool is unavailable."}
		return {"ok": true, "python": python, "script": path, "kind": "development"}
	var checked := validate_bundle(install_root)
	if not checked.get("ok", false):
		return checked
	if not checked.files.has(script) or not checked.files.has("python/python.exe"):
		return {"ok": false, "error": "The bundled Python tool is not in the runtime inventory."}
	return {"ok": true, "python": str(checked.root).path_join("python/python.exe"),
		"script": str(checked.root).path_join(script), "kind": "bundled", "runtime_sha256": checked.payload_sha256}


static func find_python() -> String:
	if OS.has_feature("editor"):
		return _development_python()
	var checked := validate_bundle()
	return str(checked.root).path_join("python/python.exe") if checked.get("ok", false) and checked.files.has("python/python.exe") else ""


static func validate_bundle(install_root := "") -> Dictionary:
	var runtime_root := (OS.get_executable_path().get_base_dir() if install_root.is_empty() else install_root).path_join("runtime")
	var path := runtime_root.path_join("manifest.json")
	if not FileAccess.file_exists(path):
		return {"ok": false, "error": "The bundled Python runtime is missing from this installation."}
	var value = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not value is Dictionary or value.size() != 6 or value.get("schema") != SCHEMA or value.get("core_version") != VersionScript.CORE_VERSION or not value.get("files") is Array:
		return {"ok": false, "error": "The bundled Python runtime schema or application version changed."}
	for field in ["python_version", "pillow_version", "payload_sha256"]:
		if not value.get(field) is String or str(value[field]).is_empty():
			return {"ok": false, "error": "The bundled Python runtime identity is incomplete."}
	if FingerprintScript.new().fingerprint(value) != str(value.get("payload_sha256", "")):
		return {"ok": false, "error": "The bundled Python runtime fingerprint changed."}
	var files := {}
	for row in value.files:
		if not row is Dictionary or row.size() != 3 or not _relative(str(row.get("path", ""))) or files.has(str(row.path).to_lower()):
			return {"ok": false, "error": "The bundled Python inventory contains an invalid path."}
		var file_path := runtime_root.path_join(str(row.path))
		var file := FileAccess.open(file_path, FileAccess.READ)
		if file == null:
			return {"ok": false, "error": "A bundled Python dependency is missing: %s" % str(row.path)}
		var size := file.get_length()
		file.close()
		if size != row.get("size", -1) or FileAccess.get_sha256(file_path) != row.get("sha256", ""):
			return {"ok": false, "error": "A bundled Python dependency changed: %s" % str(row.path)}
		files[str(row.path).to_lower()] = true
	if not _inventory_matches(runtime_root, "", files):
		return {"ok": false, "error": "The bundled Python runtime contains an unexpected file."}
	return {"ok": true, "root": runtime_root, "files": files, "payload_sha256": value.payload_sha256}


static func _inventory_matches(root: String, prefix: String, files: Dictionary) -> bool:
	var directory := DirAccess.open(root.path_join(prefix))
	if directory == null:
		return false
	for name in directory.get_files():
		var relative := prefix.path_join(name) if not prefix.is_empty() else name
		if relative != "manifest.json" and not files.has(relative.to_lower()):
			return false
	for name in directory.get_directories():
		if not _inventory_matches(root, prefix.path_join(name) if not prefix.is_empty() else name, files):
			return false
	return true


static func _relative(path: String) -> bool:
	if path.is_empty() or path.contains(":") or path.contains("\\") or path.is_absolute_path() or path != path.strip_edges():
		return false
	for part in path.split("/", true):
		if part in ["", ".", ".."]:
			return false
	return true


static func _development_python() -> String:
	var candidates: Array[String] = []
	var local_app_data := OS.get_environment("LOCALAPPDATA")
	if not local_app_data.is_empty():
		candidates.append(local_app_data.path_join("Programs/Python/Launcher/py.exe"))
	var windows_root := OS.get_environment("WINDIR")
	if not windows_root.is_empty():
		candidates.append(windows_root.path_join("py.exe"))
	for directory in OS.get_environment("PATH").split(";", false):
		candidates.append(directory.trim_prefix("\"").trim_suffix("\"").path_join("py.exe"))
	for candidate in candidates:
		if FileAccess.file_exists(candidate):
			return candidate.simplify_path()
	return ""
