class_name ContentToolPathHistory
extends RefCounted

const DEFAULT_CONFIG_PATH := "user://content_tools/path_history.cfg"
const SECTION := "paths"
const ELFIMAGE_KEY := "elfimage_root"
const SOURCE_DIRECTORY_KEY := "source_directory"
const WORKSPACE_DIRECTORY_KEY := "workspace_directory"

var _config_path: String


func _init(config_path := DEFAULT_CONFIG_PATH) -> void:
	_config_path = config_path


func remember_elfimage(path: String) -> bool:
	var absolute_path := ProjectSettings.globalize_path(path).simplify_path()
	if not _is_elfimage_root(absolute_path):
		return false
	return _save_paths({
		ELFIMAGE_KEY: absolute_path,
		SOURCE_DIRECTORY_KEY: absolute_path,
	})


func remember_source_path(path: String) -> bool:
	var absolute_path := ProjectSettings.globalize_path(path).simplify_path()
	var directory := absolute_path if DirAccess.dir_exists_absolute(absolute_path) else absolute_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(directory):
		return false
	var values := {SOURCE_DIRECTORY_KEY: directory}
	if _is_elfimage_root(directory):
		values[ELFIMAGE_KEY] = directory
	return _save_paths(values)


func remember_workspace_directory(path: String) -> bool:
	var absolute_path := ProjectSettings.globalize_path(path).simplify_path()
	if not DirAccess.dir_exists_absolute(absolute_path):
		return false
	return _save_paths({WORKSPACE_DIRECTORY_KEY: absolute_path})


func _save_paths(values: Dictionary) -> bool:
	var absolute_config := ProjectSettings.globalize_path(_config_path)
	var parent := absolute_config.get_base_dir()
	if not DirAccess.dir_exists_absolute(parent):
		var make_error := DirAccess.make_dir_recursive_absolute(parent)
		if make_error != OK:
			return false
	var config := ConfigFile.new()
	if FileAccess.file_exists(absolute_config):
		config.load(absolute_config)
	for key in values:
		config.set_value(SECTION, str(key), str(values[key]))
	return config.save(absolute_config) == OK


func get_last_elfimage() -> String:
	var absolute_config := ProjectSettings.globalize_path(_config_path)
	if not FileAccess.file_exists(absolute_config):
		return ""
	var config := ConfigFile.new()
	if config.load(absolute_config) != OK:
		return ""
	var stored_path := str(config.get_value(SECTION, ELFIMAGE_KEY, "")).simplify_path()
	return stored_path if _is_elfimage_root(stored_path) else ""


func apply_elfimage_dialog(dialog: FileDialog) -> bool:
	if not is_instance_valid(dialog):
		return false
	var stored_path := get_last_elfimage()
	if stored_path.is_empty():
		return false
	dialog.current_dir = stored_path
	return true


func get_last_source_directory() -> String:
	var stored_path := _read_directory(SOURCE_DIRECTORY_KEY)
	return stored_path if not stored_path.is_empty() else get_last_elfimage()


func apply_source_dialog(dialog: FileDialog) -> bool:
	if not is_instance_valid(dialog):
		return false
	var stored_path := get_last_source_directory()
	if stored_path.is_empty():
		return false
	dialog.current_dir = stored_path
	return true


func get_last_workspace_directory() -> String:
	return _read_directory(WORKSPACE_DIRECTORY_KEY)


func apply_workspace_dialog(dialog: FileDialog) -> bool:
	if not is_instance_valid(dialog):
		return false
	var stored_path := get_last_workspace_directory()
	if stored_path.is_empty():
		return false
	dialog.current_dir = stored_path
	return true


func _read_directory(key: String) -> String:
	var absolute_config := ProjectSettings.globalize_path(_config_path)
	if not FileAccess.file_exists(absolute_config):
		return ""
	var config := ConfigFile.new()
	if config.load(absolute_config) != OK:
		return ""
	var stored_path := str(config.get_value(SECTION, key, "")).simplify_path()
	return stored_path if DirAccess.dir_exists_absolute(stored_path) else ""


func _is_elfimage_root(path: String) -> bool:
	return (
		not path.is_empty()
		and DirAccess.dir_exists_absolute(path)
		and FileAccess.file_exists(path.path_join("mes.arc"))
	)
