extends Node

const LaunchContextScript := preload("res://content_core/content_launch_context.gd")
const ContentProjectScript := preload("res://content_core/content_project.gd")
const ContentWorkspaceScript := preload("res://content_core/content_workspace.gd")
const TOOL_SCENES := {
	"arc_browser": preload("res://tools/content_suite/apps/arc_browser.tscn"),
	"audio_editor": preload("res://tools/content_suite/apps/audio_arc_editor.tscn"),
	"mes_editor": preload("res://tools/content_suite/apps/mes_editor.tscn"),
	"event_player": preload("res://tools/content_suite/apps/event_player.tscn"),
	"image_editor": preload("res://tools/content_suite/apps/image_arc_editor.tscn"),
}
const ROOT := "user://content_launch_context_test"
const ENTRY_SIZE := 264
const NAME_KEY := 0x72
const SIZE_KEY := 0xF97FD0EC
const OFFSET_KEY := 0xA2C947FC

var _failed := false


func _ready() -> void:
	var root := ProjectSettings.globalize_path(ROOT)
	_remove_tree(root)
	DirAccess.make_dir_recursive_absolute(root.path_join("ELFIMAGE"))
	DirAccess.make_dir_recursive_absolute(root.path_join("workspace"))
	_create_arc(root.path_join("ELFIMAGE/mes.arc"), "TEST.MES", PackedByteArray([1, 2, 3]))
	_create_arc(root.path_join("ELFIMAGE/mmo.arc"), "TEST.MMO", PackedByteArray([4, 5]))
	_create_arc(root.path_join("ELFIMAGE/voice.arc"), "TEST.OGG", PackedByteArray([6, 7]))
	var mes_sha := FileAccess.get_sha256(root.path_join("ELFIMAGE/mes.arc"))
	var mmo_sha := FileAccess.get_sha256(root.path_join("ELFIMAGE/mmo.arc"))
	var voice_sha := FileAccess.get_sha256(root.path_join("ELFIMAGE/voice.arc"))
	var archives := [
		{"archive": "mes.arc", "sha256": mes_sha, "required": true},
		{"archive": "mmo.arc", "sha256": mmo_sha, "required": false},
		{"archive": "voice.arc", "sha256": voice_sha, "required": false},
	]
	var project := {
		"schema": "kakyu_content_project/v1", "project_id": "launch.test", "project_version": "0.1.0",
		"display_name": "Launch Test", "project_revision": 1,
		"content_core": {"minimum_version": "0.151.0", "maximum_exclusive": "1.0.0"},
		"source_content_set": {"profile_id": "synthetic-test", "fingerprint_sha256": ContentProjectScript.compute_content_set_fingerprint(archives), "archives": archives},
		"target_archives": ["mes.arc", "mmo.arc", "voice.arc"], "compatibility_objective": "mixed", "dependencies": [],
		"event_player": {"catalog_id": "kakyu-original-events", "presets": []}, "overlay_manifest": "manifest.json",
	}
	var workspace := ContentWorkspaceScript.new()
	_check(workspace.create(root.path_join("workspace"), root.path_join("ELFIMAGE"), project).get("ok", false), "launch fixture workspace is created through Content Core")
	workspace.close()
	var run_request_path := root.path_join("request.json")
	var interface_proof_path := root.path_join("proof.json")
	var selection_path := root.path_join("selection.json")
	_write_text(run_request_path, "{}\n")
	_write_text(interface_proof_path, "{}\n")
	_write_text(selection_path, "{}\n")

	var context := LaunchContextScript.new()
	var legacy := context.activate(PackedStringArray([root.path_join("ELFIMAGE/mes.arc"), "cache"]))
	_check(legacy.ok and not legacy.named and legacy.legacy_arguments.size() == 2, "legacy positional startup remains untouched")
	var active := context.activate(PackedStringArray(["--content-set", root.path_join("ELFIMAGE"), "--workspace", root.path_join("workspace")]))
	_check(active.ok and active.named and active.schema == "kakyu_content_launch_context/v1", "named startup opens one validated workspace generation")
	_check(context.get_preferred_archive_path(["voice.arc", "mmo.arc"]).get_file() == "voice.arc", "preferred archive selection uses the first available bound archive")
	var selected := context.activate(PackedStringArray(["--workspace", root.path_join("workspace"), "--archive", root.path_join("ELFIMAGE/mes.arc"), "--content-set", root.path_join("ELFIMAGE")]))
	_check(selected.ok and context.get_selected_archive_path().get_file() == "mes.arc", "optional startup ARC must belong to the same bound source set")
	_check(context.get_preferred_archive_path(["mmo.arc"]).is_empty(), "a bound but incompatible selected ARC cannot override a specialist default")
	var run_selected := context.activate(PackedStringArray([
		"--workspace", root.path_join("workspace"), "--content-set", root.path_join("ELFIMAGE"),
		"--run-request", run_request_path, "--interface-proof", interface_proof_path,
	]))
	_check(
		run_selected.ok
		and context.get_run_request_path() == run_request_path.simplify_path()
		and context.get_interface_proof_path() == interface_proof_path.simplify_path(),
		"named startup carries separate readable Run request and interface-proof inputs"
	)
	_check(
		not context.activate(PackedStringArray([
			"--workspace", root.path_join("workspace"), "--content-set", root.path_join("ELFIMAGE"),
			"--interface-proof", interface_proof_path,
		])).ok,
		"an interface proof without a Run request fails closed"
	)
	var selection_selected := context.activate(PackedStringArray([
		"--workspace", root.path_join("workspace"), "--content-set", root.path_join("ELFIMAGE"),
		"--selection", selection_path,
	]))
	_check(
		selection_selected.ok and context.get_selection_path() == selection_path.simplify_path(),
		"named startup carries a readable selection input"
	)
	_check(
		not context.activate(PackedStringArray([
			"--workspace", root.path_join("workspace"), "--content-set", root.path_join("ELFIMAGE"),
			"--run-request", run_request_path, "--selection", selection_path,
		])).ok,
		"a selection and a Run request together fail closed"
	)
	var outside := context.activate(PackedStringArray(["--content-set", root.path_join("ELFIMAGE"), "--workspace", root.path_join("workspace"), "--archive", root.path_join("outside.arc")]))
	_check(not outside.ok and not context.is_active(), "outside startup ARC fails closed and releases the candidate workspace")
	_check(not context.activate(PackedStringArray(["--content-set", root.path_join("ELFIMAGE")])).ok, "partial named startup is rejected")
	_check(not context.activate(PackedStringArray(["--future", "x", "--workspace", root.path_join("workspace")])).ok, "unknown named startup flags are rejected")
	var named_arguments := PackedStringArray(["--content-set", root.path_join("ELFIMAGE"), "--workspace", root.path_join("workspace")])
	for tool_id in TOOL_SCENES:
		var tool: Control = TOOL_SCENES[tool_id].instantiate()
		add_child(tool)
		await get_tree().process_frame
		tool.call("_apply_startup_arguments", named_arguments)
		await get_tree().process_frame
		var tool_context = tool.get("_launch_context")
		var tool_reader = tool.get("_reader")
		_check(tool_context.is_active() and tool_reader != null and tool_reader.is_open(), "%s reopens the named workspace and its preferred read-only ARC" % tool_id)
		if tool_id == "event_player":
			# EP-08: the Event Player keeps the workspace as launch context only
			# and activates no overlay - it plays original content only.
			_check(
				tool.get("_overlay_root") == null
				and str(tool_context.get_workspace_root()).simplify_path() == root.path_join("workspace").simplify_path(),
				"%s keeps the workspace as launch context and activates no overlay" % tool_id
			)
		else:
			_check(str(tool.get("_overlay_root")) == root.path_join("workspace").simplify_path(), "%s activates the same workspace manifest" % tool_id)
		tool.queue_free()
		await get_tree().process_frame
	_check(FileAccess.get_sha256(root.path_join("ELFIMAGE/mes.arc")) == mes_sha and FileAccess.get_sha256(root.path_join("ELFIMAGE/mmo.arc")) == mmo_sha and FileAccess.get_sha256(root.path_join("ELFIMAGE/voice.arc")) == voice_sha, "launch validation leaves source ARCs unchanged")
	context.close()
	_remove_tree(root)
	get_tree().quit(1 if _failed else 0)


func _create_arc(path: String, name: String, data: PackedByteArray) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_32(1)
	var record := PackedByteArray()
	record.resize(ENTRY_SIZE)
	var name_bytes := name.to_ascii_buffer()
	for index in range(256):
		record[index] = (name_bytes[index] if index < name_bytes.size() else 0) ^ NAME_KEY
	record.encode_u32(256, data.size() ^ SIZE_KEY)
	record.encode_u32(260, (4 + ENTRY_SIZE) ^ OFFSET_KEY)
	file.store_buffer(record)
	file.store_buffer(data)
	file.close()


func _write_text(path: String, contents: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(contents)
	file.close()


func _remove_tree(path: String) -> void:
	var directory := DirAccess.open(path)
	if directory == null:
		return
	directory.list_dir_begin()
	var name := directory.get_next()
	while not name.is_empty():
		var child := path.path_join(name)
		if directory.current_is_dir(): _remove_tree(child)
		else: DirAccess.remove_absolute(child)
		name = directory.get_next()
	directory.list_dir_end()
	DirAccess.remove_absolute(path)


func _check(condition: bool, label: String) -> void:
	if condition: print("PASS: ", label)
	else:
		_failed = true
		push_error("FAIL: " + label)
