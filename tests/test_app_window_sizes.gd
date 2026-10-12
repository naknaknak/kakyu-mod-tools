extends "res://tests/test_case.gd"

## WD-15, the part a machine can check: every app, at the shared minimum size,
## the default size, 1080p and 1440p, fills its window, keeps every visible
## control inside the window, and squeezes no control below its own minimum.
## What this cannot see - legibility, DPI scaling on a real monitor - stays a
## manual check.
##
## The Event Player is the one app that stretches and keeps a fixed 1280x800
## logical canvas at every window size; the five other apps reflow with the
## window and get a DPI factor instead (checked in a second pass below).

const ContentToolWindowProfileScript := preload("res://tools/content_suite/tool_window_profile.gd")

const EVENT_PLAYER_SCENE := "res://tools/content_suite/apps/event_player.tscn"
const EVENT_PLAYER_LOGICAL_SIZE := Vector2(1280, 800)

const APP_SCENES := [
	"res://tools/content_suite/apps/arc_browser.tscn",
	"res://tools/content_suite/apps/mes_editor.tscn",
	"res://tools/content_suite/apps/image_arc_editor.tscn",
	"res://tools/content_suite/apps/audio_arc_editor.tscn",
	EVENT_PLAYER_SCENE,
	"res://tools/content_suite/apps/content_suite_launcher.tscn",
]
const SIZES := [
	Vector2i(1024, 640),
	Vector2i(1280, 800),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]
const DPI_FACTORS: Array[float] = [1.25, 1.5, 2.0]
const TOLERANCE := 1.0


func _ready() -> void:
	var original_size := get_window().size
	for scene_path in APP_SCENES:
		var app: Control = load(scene_path).instantiate()
		add_child(app)
		await get_tree().process_frame
		for size in SIZES:
			get_window().size = size
			await get_tree().process_frame
			await get_tree().process_frame
			var expected := _expected_logical_size(scene_path, Vector2(size))
			var problems := _layout_problems(app, expected)
			_check(
				problems.is_empty(),
				"%s lays out at %dx%d%s" % [
					scene_path.get_file().get_basename(), size.x, size.y,
					"" if problems.is_empty() else ": " + "; ".join(problems.slice(0, 4)),
				]
			)
		app.queue_free()
		await get_tree().process_frame
		if scene_path != EVENT_PLAYER_SCENE:
			await _check_dpi_factor_layout(scene_path)
		ContentToolWindowProfileScript.apply(get_window(), 1.0)
		await get_tree().process_frame
	get_window().size = original_size
	get_tree().quit(1 if _failed else 0)


func _expected_logical_size(scene_path: String, window_size: Vector2) -> Vector2:
	return EVENT_PLAYER_LOGICAL_SIZE if scene_path == EVENT_PLAYER_SCENE else window_size


func _check_dpi_factor_layout(scene_path: String) -> void:
	var app: Control = load(scene_path).instantiate()
	add_child(app)
	await get_tree().process_frame
	for factor in DPI_FACTORS:
		var minimum := ContentToolWindowProfileScript.MINIMUM_SIZE
		for window_size in [Vector2i(Vector2(minimum) * factor), Vector2i(2560, 1440)]:
			var logical := Vector2(window_size) / factor
			if logical.x < float(minimum.x) - TOLERANCE or logical.y < float(minimum.y) - TOLERANCE:
				continue
			ContentToolWindowProfileScript.apply(get_window(), factor)
			get_window().size = window_size
			await get_tree().process_frame
			await get_tree().process_frame
			var problems := _layout_problems(app, logical)
			_check(
				problems.is_empty(),
				"%s lays out at %dx%d with DPI factor %s%s" % [
					scene_path.get_file().get_basename(), window_size.x, window_size.y, str(factor),
					"" if problems.is_empty() else ": " + "; ".join(problems.slice(0, 4)),
				]
			)
	app.queue_free()
	await get_tree().process_frame


func _layout_problems(app: Control, logical_size: Vector2) -> Array[String]:
	var problems: Array[String] = []
	if app.size.distance_to(logical_size) > TOLERANCE:
		problems.append("root is %s, expected %s" % [str(app.size), str(logical_size)])
	var bounds := Rect2(Vector2.ZERO, logical_size).grow(TOLERANCE)
	_collect(app, app, bounds, problems)
	return problems


func _collect(root: Control, node: Node, bounds: Rect2, problems: Array[String]) -> void:
	for child in node.get_children():
		if child is Window:
			continue
		if not child is Control:
			_collect(root, child, bounds, problems)
			continue
		var control: Control = child
		if not control.is_visible_in_tree():
			continue
		var rect := control.get_global_rect()
		if rect.size.x > 0.0 and rect.size.y > 0.0 and not bounds.encloses(rect):
			problems.append("%s leaves the window (%s)" % [str(root.get_path_to(control)), str(rect)])
		var minimum := control.get_combined_minimum_size()
		if control.size.x + TOLERANCE < minimum.x or control.size.y + TOLERANCE < minimum.y:
			problems.append("%s is %s, needs %s" % [str(root.get_path_to(control)), str(control.size), str(minimum)])
		# What scrolls or clips its content is allowed to hold more than it shows.
		if control is ScrollContainer or control is Tree or control is ItemList or control is RichTextLabel or control is TextEdit or control.clip_contents:
			continue
		_collect(root, control, bounds, problems)
