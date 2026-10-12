extends RefCounted

var _files: Array[String] = []
var _failures: Array[String] = []


func run(tree: SceneTree, args: PackedStringArray) -> Dictionary:
	await tree.process_frame
	var expected := str(args[1]) if args.size() >= 2 else "arc_browser"
	if expected not in ["arc_browser", "mes_editor", "image_arc_editor", "audio_arc_editor", "event_player", "content_suite_launcher"]:
		return {"ok":false,"error":"Unknown distribution application."}
	var expected_scene := "res://tools/content_suite/apps/%s.tscn" % expected
	var main_scene := str(ProjectSettings.get_setting_with_override("application/run/main_scene"))
	if main_scene != expected_scene:
		_failures.append("Exported default scene differs: %s" % main_scene)
	_collect("res://")
	for path in _files:
		for forbidden in ["res://assets/", "res://data/", "res://analysis/", "res://reverse_engineering/", "res://.agents/"]:
			if path.begins_with(forbidden):
				_failures.append("Original/local-only content was included: %s" % path)
	var created := tree.current_scene == null
	var app: Node = tree.current_scene
	if created:
		var scene = load(expected_scene)
		if not scene is PackedScene:
			return {"ok":false,"error":"Application scene is unavailable."}
		app = scene.instantiate()
		tree.root.add_child(app)
	await tree.process_frame
	await tree.process_frame
	if app.scene_file_path != expected_scene:
		_failures.append("Running application scene differs from its export preset.")
	if created:
		app.queue_free()
		await tree.process_frame
	var runtime := {}
	if "--require-python" in args:
		var command := preload("res://tools/content_suite/python_runtime.gd").resolve("tools/windows_runtime_selftest.py")
		if not command.get("ok", false) or command.get("kind") != "bundled":
			_failures.append("Bundled Python resolution failed: %s" % str(command.get("error", "not bundled")))
		else:
			var output: Array = []
			var exit_code := OS.execute(str(command.python), ["-B", str(command.script)], output, true, false)
			var result: Variant = JSON.parse_string("".join(output))
			if exit_code != 0 or not result is Dictionary or not result.get("ok", false) or result.get("isolated") != 1:
				_failures.append("Bundled Python authoring diagnostic failed: %s" % "".join(output))
			else:
				runtime = result
	if args.size() >= 1:
		var file := FileAccess.open(str(args[0]), FileAccess.WRITE)
		if file == null:
			_failures.append("Runtime license report could not be written.")
		else:
			file.store_string(JSON.stringify({"godot": Engine.get_license_text(), "third_party": Engine.get_license_info(), "copyright": Engine.get_copyright_info()}, "  "))
			file.close()
	return {"ok": _failures.is_empty(), "resource_file_count": _files.size(), "main_scene": main_scene,
		"original_payload_files": 0 if _failures.is_empty() else -1, "failures": _failures,
		"python": runtime, "editor_feature": OS.has_feature("editor"),
		"scope": "exported application scene and resource inventory; headless development-machine smoke"}


func _collect(path: String) -> void:
	var directory := DirAccess.open(path)
	if directory == null:
		_failures.append("Exported resource directory is unreadable: %s" % path)
		return
	directory.list_dir_begin()
	var name := directory.get_next()
	while not name.is_empty():
		if name not in [".", ".."]:
			var child := path.path_join(name)
			if directory.current_is_dir():
				_collect(child)
			else:
				_files.append(child)
		name = directory.get_next()
	directory.list_dir_end()
