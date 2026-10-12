class_name KakyuContentLaunchContext
extends RefCounted

const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")
const ContentWorkspaceScript := preload("res://content_core/content_workspace.gd")

const ARG_CONTENT_SET := "--content-set"
const ARG_WORKSPACE := "--workspace"
const ARG_ARCHIVE := "--archive"
const ARG_RUN_REQUEST := "--run-request"
const ARG_INTERFACE_PROOF := "--interface-proof"
const ARG_SELECTION := "--selection"
const ALLOWED_ARGUMENTS := {
	ARG_CONTENT_SET: true, ARG_WORKSPACE: true, ARG_ARCHIVE: true,
	ARG_RUN_REQUEST: true, ARG_INTERFACE_PROOF: true, ARG_SELECTION: true,
}

var last_error := ""
var _workspace := ContentWorkspaceScript.new()
var _content_set_root := ""
var _workspace_root := ""
var _archive_path := ""
var _run_request_path := ""
var _interface_proof_path := ""
var _selection_path := ""


func activate(arguments: PackedStringArray) -> Dictionary:
	close()
	last_error = ""
	if arguments.is_empty():
		return {"ok": true, "named": false, "legacy_arguments": PackedStringArray()}
	if not str(arguments[0]).begins_with("--"):
		return {"ok": true, "named": false, "legacy_arguments": arguments.duplicate()}
	if arguments.size() % 2 != 0:
		return _error("Content tool startup arguments require flag/value pairs.")
	var values := {}
	for index in range(0, arguments.size(), 2):
		var key := str(arguments[index])
		var value := str(arguments[index + 1]).strip_edges()
		if not ALLOWED_ARGUMENTS.has(key):
			return _error("Unknown content tool startup argument: %s" % key)
		if values.has(key) or value.is_empty():
			return _error("Content tool startup argument is duplicate or empty: %s" % key)
		values[key] = value
	if not values.has(ARG_CONTENT_SET) or not values.has(ARG_WORKSPACE):
		return _error("Named startup requires both --content-set and --workspace.")
	var content_root := ProjectSettings.globalize_path(str(values[ARG_CONTENT_SET])).simplify_path()
	var workspace_root := ProjectSettings.globalize_path(str(values[ARG_WORKSPACE])).simplify_path()
	var opened := _workspace.open(workspace_root, content_root)
	if not opened.ok:
		return _error("Workspace startup rejected: %s" % str(opened.error))
	var selected_archive := ""
	if values.has(ARG_ARCHIVE):
		selected_archive = ProjectSettings.globalize_path(str(values[ARG_ARCHIVE])).simplify_path()
		if not _is_bound_archive_path(selected_archive, content_root, opened.snapshot):
			_workspace.close()
			return _error("Startup ARC is not a source archive bound by the workspace.")
	if values.has(ARG_INTERFACE_PROOF) and not values.has(ARG_RUN_REQUEST):
		_workspace.close()
		return _error("An interface proof requires a MES Editor Run request.")
	if values.has(ARG_SELECTION) and values.has(ARG_RUN_REQUEST):
		_workspace.close()
		return _error("A launch carries either a selection or a Run request.")
	var run_request_path := ""
	if values.has(ARG_RUN_REQUEST):
		run_request_path = _validated_json_input(str(values[ARG_RUN_REQUEST]))
		if run_request_path.is_empty():
			_workspace.close()
			return _error("MES Editor Run request is not a readable JSON file.")
	var interface_proof_path := ""
	if values.has(ARG_INTERFACE_PROOF):
		interface_proof_path = _validated_json_input(str(values[ARG_INTERFACE_PROOF]))
		if interface_proof_path.is_empty():
			_workspace.close()
			return _error("MES interface proof is not a readable JSON file.")
	var selection_path := ""
	if values.has(ARG_SELECTION):
		selection_path = _validated_json_input(str(values[ARG_SELECTION]))
		if selection_path.is_empty():
			_workspace.close()
			return _error("Content selection is not a readable JSON file.")
	_content_set_root = content_root
	_workspace_root = workspace_root
	_archive_path = selected_archive
	_run_request_path = run_request_path
	_interface_proof_path = interface_proof_path
	_selection_path = selection_path
	return {
		"ok": true,
		"named": true,
		"schema": ContentCoreVersionScript.CONTENT_LAUNCH_CONTEXT_SCHEMA,
		"snapshot": _workspace.get_snapshot(),
		"content_set_root": _content_set_root,
		"workspace_root": _workspace_root,
		"archive_path": _archive_path,
		"run_request_path": _run_request_path,
		"interface_proof_path": _interface_proof_path,
		"selection_path": _selection_path,
	}


func close() -> void:
	_workspace.close()
	_content_set_root = ""
	_workspace_root = ""
	_archive_path = ""
	_run_request_path = ""
	_interface_proof_path = ""
	_selection_path = ""


func is_active() -> bool:
	return _workspace.is_open()


func get_snapshot() -> Dictionary:
	return _workspace.get_snapshot()


func refresh() -> Dictionary:
	return _workspace.refresh()


func get_content_set_root() -> String:
	return _content_set_root


func get_workspace_root() -> String:
	return _workspace_root


func get_selected_archive_path() -> String:
	return _archive_path


func get_run_request_path() -> String:
	return _run_request_path


func get_interface_proof_path() -> String:
	return _interface_proof_path


func get_selection_path() -> String:
	return _selection_path


func get_preferred_archive_path(archive_names: Array[String]) -> String:
	if not _archive_path.is_empty():
		var selected_name := _archive_path.get_file().to_lower()
		for archive_name in archive_names:
			if archive_name.to_lower() == selected_name:
				return _archive_path
		return ""
	if not is_active():
		return ""
	var snapshot := _workspace.get_snapshot()
	var available := {}
	for value in snapshot.project.source_content_set.archives:
		available[str(value.archive).to_lower()] = true
	for archive_name in archive_names:
		var normalized := archive_name.to_lower()
		if available.has(normalized):
			return _content_set_root.path_join(normalized)
	return ""


func _is_bound_archive_path(path: String, content_root: String, snapshot: Dictionary) -> bool:
	if path.get_base_dir().simplify_path().to_lower() != content_root.to_lower():
		return false
	var filename := path.get_file().to_lower()
	for value in snapshot.project.source_content_set.archives:
		if str(value.archive).to_lower() == filename:
			return FileAccess.file_exists(path)
	return false


func _validated_json_input(path: String) -> String:
	var absolute := ProjectSettings.globalize_path(path).simplify_path()
	if absolute.get_extension().to_lower() != "json" or not FileAccess.file_exists(absolute):
		return ""
	var file := FileAccess.open(absolute, FileAccess.READ)
	if file == null:
		return ""
	file.close()
	return absolute


func _error(message: String) -> Dictionary:
	last_error = message
	return {"ok": false, "error": message}
