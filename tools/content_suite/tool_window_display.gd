class_name ContentToolWindowDisplay
extends RefCounted

const ContentToolWindowProfileScript := preload("res://tools/content_suite/tool_window_profile.gd")

const MODE_WINDOWED := "windowed"
const MODE_FULLSCREEN := "fullscreen"
const STRETCH_BASE_SIZE := Vector2i(1280, 800)
const STRETCH_MINIMUM_SIZE := Vector2i(640, 400)
const DEFAULT_CONFIG_PATH := "user://content_tools/window_display.cfg"
const SECTION_KEY := "mode"

var _app_id: String
var _config_path: String
var _mode := ""
var _applied_once := false


func _init(app_id: String, config_path := DEFAULT_CONFIG_PATH) -> void:
	_app_id = app_id
	_config_path = config_path


func apply(window: Window, mode := "") -> String:
	if window == null:
		return get_mode()
	var requested := mode.strip_edges().to_lower() if not mode.is_empty() else _stored_mode()
	var target := requested if requested == MODE_FULLSCREEN else MODE_WINDOWED
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	window.content_scale_size = STRETCH_BASE_SIZE
	window.content_scale_factor = 1.0
	window.min_size = STRETCH_MINIMUM_SIZE
	if not _applied_once:
		var minimum := ContentToolWindowProfileScript.MINIMUM_SIZE
		if window.size.x < minimum.x or window.size.y < minimum.y:
			var factor := ContentToolWindowProfileScript.scale_for_dpi(DisplayServer.screen_get_dpi(window.current_screen))
			window.size = Vector2i(Vector2(ContentToolWindowProfileScript.DEFAULT_SIZE) * factor)
		_applied_once = true
	if target == MODE_FULLSCREEN:
		window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
		window.mode = Window.MODE_FULLSCREEN
	else:
		window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
		if _mode == MODE_FULLSCREEN:
			window.mode = Window.MODE_WINDOWED
	_mode = target
	_save_mode(target)
	return target


func toggle(window: Window) -> String:
	return apply(window, MODE_WINDOWED if get_mode() == MODE_FULLSCREEN else MODE_FULLSCREEN)


func get_mode() -> String:
	return _mode if not _mode.is_empty() else _stored_mode()


func _stored_mode() -> String:
	var absolute_config := ProjectSettings.globalize_path(_config_path)
	if not FileAccess.file_exists(absolute_config):
		return MODE_WINDOWED
	var config := ConfigFile.new()
	if config.load(absolute_config) != OK:
		return MODE_WINDOWED
	var stored := str(config.get_value(_app_id, SECTION_KEY, MODE_WINDOWED))
	return stored if stored == MODE_FULLSCREEN else MODE_WINDOWED


func _save_mode(mode: String) -> bool:
	var absolute_config := ProjectSettings.globalize_path(_config_path)
	var parent := absolute_config.get_base_dir()
	if not DirAccess.dir_exists_absolute(parent):
		var make_error := DirAccess.make_dir_recursive_absolute(parent)
		if make_error != OK:
			return false
	var config := ConfigFile.new()
	if FileAccess.file_exists(absolute_config):
		config.load(absolute_config)
	config.set_value(_app_id, SECTION_KEY, mode)
	return config.save(absolute_config) == OK
