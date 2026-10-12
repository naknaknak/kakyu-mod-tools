extends RefCounted

static func for_scene(scene: String, install_root := "") -> Dictionary:
	if install_root.is_empty() and OS.has_feature("editor"):
		return {"ok": true, "executable": OS.get_executable_path(), "arguments": PackedStringArray([
			"--path", ProjectSettings.globalize_path("res://").simplify_path(), scene])}
	var catalog: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://config/distribution/applications_v1.json"))
	if not catalog is Dictionary or catalog.get("schema") != "kakyu_windows_applications/v1" or preload("res://content_core/mes_payload_fingerprint.gd").new().fingerprint(catalog) != str(catalog.get("payload_sha256", "")):
		return {"ok": false, "error": "The application launch catalog changed."}
	for app in catalog.applications:
		if str(app.scene) != scene:
			continue
		var name := str(app.executable)
		if name.get_file() != name or not name.ends_with(".exe") or name.contains(":"):
			return {"ok": false, "error": "The application executable name is invalid."}
		var executable := (OS.get_executable_path().get_base_dir() if install_root.is_empty() else install_root).path_join(name)
		if not FileAccess.file_exists(executable):
			return {"ok": false, "error": "The application is missing from this installation: %s" % name}
		return {"ok": true, "executable": executable, "arguments": PackedStringArray()}
	return {"ok": false, "error": "The application scene is not in this installation."}
