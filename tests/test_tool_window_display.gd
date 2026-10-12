extends "res://tests/test_case.gd"

## WD-15: the DPI factor helper (`ContentToolWindowProfile`) and the Event
## Player's stretch/fullscreen helper (`ContentToolWindowDisplay`).

const ContentToolWindowProfileScript := preload("res://tools/content_suite/tool_window_profile.gd")
const ContentToolWindowDisplayScript := preload("res://tools/content_suite/tool_window_display.gd")

const TEST_CONFIG_ROOT := "user://tool_window_display_test"
const TEST_CONFIG_PATH := TEST_CONFIG_ROOT + "/window_display.cfg"
const STRETCH_SIZES := [Vector2i(1024, 640), Vector2i(1920, 1080), Vector2i(2560, 1440)]


func _ready() -> void:
	_remove_tree(ProjectSettings.globalize_path(TEST_CONFIG_ROOT))
	var window := get_window()
	var original_scale_mode := window.content_scale_mode
	var original_scale_size := window.content_scale_size
	var original_scale_factor := window.content_scale_factor
	var original_scale_aspect := window.content_scale_aspect
	var original_min_size := window.min_size
	var original_window_size := window.size

	_check_scale_for_dpi()
	await _check_profile_apply_with_explicit_scale(window)
	_check_profile_apply_at_headless_dpi(window)
	await _check_window_display(window)

	window.content_scale_mode = original_scale_mode
	window.content_scale_size = original_scale_size
	window.content_scale_factor = original_scale_factor
	window.content_scale_aspect = original_scale_aspect
	window.min_size = original_min_size
	window.size = original_window_size
	_remove_tree(ProjectSettings.globalize_path(TEST_CONFIG_ROOT))
	get_tree().quit(1 if _failed else 0)


func _check_scale_for_dpi() -> void:
	var table := {96: 1.0, 120: 1.25, 144: 1.5, 168: 1.75, 192: 2.0, 72: 1.0, 0: 1.0, -1: 1.0, 1000: 3.0}
	for dpi in table:
		_check(
			is_equal_approx(ContentToolWindowProfileScript.scale_for_dpi(int(dpi)), float(table[dpi])),
			"scale_for_dpi(%s) is %s" % [str(dpi), str(table[dpi])]
		)


func _check_profile_apply_with_explicit_scale(window: Window) -> void:
	var root := _make_full_rect_control()
	add_child(root)
	await get_tree().process_frame
	ContentToolWindowProfileScript.apply(window, 1.5)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(is_equal_approx(window.content_scale_factor, 1.5), "ContentToolWindowProfile.apply(window, 1.5) sets factor 1.5")
	_check(window.min_size == Vector2i(1536, 960), "ContentToolWindowProfile.apply(window, 1.5) sets min_size 1536x960")
	_check(root.size.is_equal_approx(Vector2(window.size) / 1.5), "ContentToolWindowProfile.apply(window, 1.5) leaves a full-rect root at window/1.5")
	root.queue_free()
	await get_tree().process_frame


func _check_profile_apply_at_headless_dpi(window: Window) -> void:
	ContentToolWindowProfileScript.apply(window)
	_check(is_equal_approx(window.content_scale_factor, 1.0), "ContentToolWindowProfile.apply(window) at 96 DPI leaves factor 1.0")
	_check(window.min_size == Vector2i(1024, 640), "ContentToolWindowProfile.apply(window) at 96 DPI leaves min 1024x640")


func _check_window_display(window: Window) -> void:
	var helper := ContentToolWindowDisplayScript.new("probe_app", TEST_CONFIG_PATH)
	var default_mode := helper.apply(window)
	_check(default_mode == ContentToolWindowDisplayScript.MODE_WINDOWED, "the display helper defaults to windowed")
	_check(window.content_scale_mode == Window.CONTENT_SCALE_MODE_CANVAS_ITEMS, "the display helper sets CANVAS_ITEMS")
	_check(window.content_scale_size == ContentToolWindowDisplayScript.STRETCH_BASE_SIZE, "the display helper sets base size 1280x800")
	_check(window.content_scale_aspect == Window.CONTENT_SCALE_ASPECT_KEEP, "the display helper keeps aspect while windowed")
	_check(window.min_size == ContentToolWindowDisplayScript.STRETCH_MINIMUM_SIZE, "the display helper sets min size 640x400")

	var fullscreen_mode := helper.toggle(window)
	_check(
		fullscreen_mode == ContentToolWindowDisplayScript.MODE_FULLSCREEN
		and window.content_scale_aspect == Window.CONTENT_SCALE_ASPECT_IGNORE,
		"toggle switches to fullscreen and ignores aspect"
	)
	var windowed_mode := helper.toggle(window)
	_check(
		windowed_mode == ContentToolWindowDisplayScript.MODE_WINDOWED
		and window.content_scale_aspect == Window.CONTENT_SCALE_ASPECT_KEEP,
		"toggle switches back to windowed and keeps aspect"
	)

	var reloaded := ContentToolWindowDisplayScript.new("probe_app", TEST_CONFIG_PATH)
	_check(reloaded.get_mode() == ContentToolWindowDisplayScript.MODE_WINDOWED, "a new helper instance with the same config starts in the remembered mode")

	var absolute_config := ProjectSettings.globalize_path(TEST_CONFIG_PATH)
	var raw_config := ConfigFile.new()
	raw_config.load(absolute_config)
	raw_config.set_value("probe_app", "mode", "sideways")
	raw_config.save(absolute_config)
	var unknown_helper := ContentToolWindowDisplayScript.new("probe_app", TEST_CONFIG_PATH)
	_check(unknown_helper.get_mode() == ContentToolWindowDisplayScript.MODE_WINDOWED, "an unknown stored value falls back to windowed")

	var missing_config_helper := ContentToolWindowDisplayScript.new("probe_app", TEST_CONFIG_ROOT + "/missing.cfg")
	_check(missing_config_helper.get_mode() == ContentToolWindowDisplayScript.MODE_WINDOWED, "a missing config file falls back to windowed")

	var helper_a := ContentToolWindowDisplayScript.new("app_a", TEST_CONFIG_PATH)
	var helper_b := ContentToolWindowDisplayScript.new("app_b", TEST_CONFIG_PATH)
	helper_a.apply(window, ContentToolWindowDisplayScript.MODE_FULLSCREEN)
	helper_b.apply(window, ContentToolWindowDisplayScript.MODE_WINDOWED)
	var reloaded_a := ContentToolWindowDisplayScript.new("app_a", TEST_CONFIG_PATH)
	var reloaded_b := ContentToolWindowDisplayScript.new("app_b", TEST_CONFIG_PATH)
	_check(
		reloaded_a.get_mode() == ContentToolWindowDisplayScript.MODE_FULLSCREEN
		and reloaded_b.get_mode() == ContentToolWindowDisplayScript.MODE_WINDOWED,
		"two app ids in one config do not disturb each other"
	)

	await _check_stretch_sizes(window, helper)


func _check_stretch_sizes(window: Window, helper: ContentToolWindowDisplay) -> void:
	var root := _make_full_rect_control()
	add_child(root)
	await get_tree().process_frame
	for mode in [ContentToolWindowDisplayScript.MODE_WINDOWED, ContentToolWindowDisplayScript.MODE_FULLSCREEN]:
		helper.apply(window, mode)
		for size in STRETCH_SIZES:
			window.size = size
			await get_tree().process_frame
			await get_tree().process_frame
			_check(
				root.size == Vector2(1280, 800),
				"helper-applied full-rect root is 1280x800 at %dx%d in %s" % [size.x, size.y, mode]
			)
	root.queue_free()
	await get_tree().process_frame


func _make_full_rect_control() -> Control:
	var control := Control.new()
	control.set_anchors_preset(Control.PRESET_FULL_RECT)
	return control
