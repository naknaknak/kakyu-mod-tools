class_name ContentToolGamePreview
extends VBoxContainer

const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")

signal preview_focus_changed(focused: bool)
signal preview_input(event: InputEvent, logical_position: Vector2)
signal preview_pointer_moved(logical_position: Vector2)
signal preview_pointer_pressed(logical_position: Vector2)

enum ScaleMode {
	FIT,
	ONE_TO_ONE,
	TWO_TO_ONE,
	INTEGER,
}

enum FrameContentMode {
	FIT,
	NATIVE_CENTERED,
	NATIVE_POSITIONED,
	STRETCH,
}

const LOGICAL_SIZE := Vector2i(640, 400)

@onready var scale_selector: OptionButton = %ScaleSelector
@onready var coordinate_label: Label = %CoordinateLabel
@onready var focus_label: Label = %FocusLabel
@onready var preview_surface: Control = %PreviewSurface
@onready var display: TextureRect = %Display
@onready var game_viewport: SubViewport = %GameViewport
@onready var frame_texture: TextureRect = %FrameTexture
@onready var foreground_texture: TextureRect = %ForegroundTexture
@onready var overlay_root: Control = %OverlayRoot

var _scale_mode := ScaleMode.FIT
var _frame_content_mode := FrameContentMode.FIT
var _frame_native_position := Vector2.ZERO
var _foreground_native_positioned := false
var _foreground_native_position := Vector2.ZERO
var _input_forwarding_enabled := false
var _compositor_surface_binding := {}


func _ready() -> void:
	_configure_scale_selector()
	game_viewport.size = LOGICAL_SIZE
	game_viewport.handle_input_locally = true
	display.texture = game_viewport.get_texture()
	display.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	frame_texture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	foreground_texture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_layout_frame_texture()
	preview_surface.resized.connect(_layout_display)
	display.gui_input.connect(_on_display_gui_input)
	display.focus_entered.connect(_on_display_focus_entered)
	display.focus_exited.connect(_on_display_focus_exited)
	display.mouse_exited.connect(_on_display_mouse_exited)
	_update_focus_label()
	call_deferred("_layout_display")


func get_game_viewport() -> SubViewport:
	return game_viewport


func get_overlay_root() -> Control:
	return overlay_root


func get_display_rect() -> Rect2:
	return Rect2(display.position, display.size)


func get_frame_content_rect() -> Rect2:
	return Rect2(frame_texture.position, frame_texture.size)


func get_foreground_texture() -> Texture2D:
	return foreground_texture.texture


func get_foreground_material() -> Material:
	return foreground_texture.material


func get_foreground_rect() -> Rect2:
	return Rect2(foreground_texture.position, foreground_texture.size)


func get_compositor_surface_binding() -> Dictionary:
	return _compositor_surface_binding.duplicate(true)


func is_preview_focused() -> bool:
	return display.has_focus()


func set_input_forwarding_enabled(enabled: bool) -> void:
	_input_forwarding_enabled = enabled
	if not enabled:
		release_preview_focus()
	_update_focus_label()


func set_scale_mode(mode: ScaleMode) -> void:
	_scale_mode = mode
	if is_node_ready():
		scale_selector.select(int(mode))
		_layout_display()


func set_frame_content_mode(mode: FrameContentMode) -> void:
	_frame_content_mode = mode
	if is_node_ready():
		_layout_frame_texture()


func set_frame_native_position(position: Vector2) -> void:
	_frame_native_position = position
	_frame_content_mode = FrameContentMode.NATIVE_POSITIONED
	if is_node_ready():
		_layout_frame_texture()


func set_preview_image(image: Image) -> void:
	_compositor_surface_binding.clear()
	if image == null or image.is_empty():
		frame_texture.texture = null
		return
	frame_texture.texture = ImageTexture.create_from_image(image)
	_layout_frame_texture()


func set_preview_texture(texture: Texture2D) -> void:
	_compositor_surface_binding.clear()
	frame_texture.texture = texture
	_layout_frame_texture()


func present_compositor_surface(compositor: Object, surface_index := 0) -> Dictionary:
	if compositor == null or not compositor.has_method("describe") or not compositor.has_method("get_surface_copy"):
		return {"ok": false, "error": "Preview compositor is invalid."}
	var description_value = compositor.call("describe")
	if not description_value is Dictionary:
		return {"ok": false, "error": "Preview compositor description is invalid."}
	var description: Dictionary = description_value
	if str(description.get("schema", "")) != ContentCoreVersionScript.LOGICAL_SURFACE_COMPOSITOR_SCHEMA:
		return {"ok": false, "error": "Preview compositor schema is unsupported."}
	if surface_index != 0:
		return {"ok": false, "error": "Tool Game Preview accepts only logical compositor surface 0."}
	var image_value = compositor.call("get_surface_copy", surface_index)
	if not image_value is Image:
		return {"ok": false, "error": "Logical compositor surface 0 is unavailable."}
	var image: Image = image_value
	if image.is_empty() or image.get_width() != LOGICAL_SIZE.x or image.get_height() != LOGICAL_SIZE.y:
		return {"ok": false, "error": "Logical compositor surface 0 is not 640x400."}
	var role := ""
	for row_value in description.get("surfaces", []) as Array:
		if row_value is Dictionary and int((row_value as Dictionary).get("index", -1)) == surface_index:
			role = str((row_value as Dictionary).get("role", ""))
			break
	if role.is_empty():
		return {"ok": false, "error": "Logical compositor surface 0 metadata is unavailable."}
	set_preview_image(image)
	set_frame_content_mode(FrameContentMode.STRETCH)
	clear_foreground()
	_compositor_surface_binding = {
		"schema": ContentCoreVersionScript.TOOL_GAME_PREVIEW_COMPOSITOR_BINDING_SCHEMA,
		"compositor_schema": ContentCoreVersionScript.LOGICAL_SURFACE_COMPOSITOR_SCHEMA,
		"surface_index": surface_index,
		"surface_role": role,
		"operation_sequence": int(description.get("operation_sequence", -1)),
		"width": image.get_width(),
		"height": image.get_height(),
	}
	var result := _compositor_surface_binding.duplicate(true)
	result["ok"] = true
	return result


func set_foreground_image(image: Image, material: Material = null) -> void:
	if image == null or image.is_empty():
		clear_foreground()
		return
	set_foreground_texture(ImageTexture.create_from_image(image), material)


func set_foreground_texture(texture: Texture2D, material: Material = null) -> void:
	_foreground_native_positioned = false
	foreground_texture.texture = texture
	foreground_texture.material = material
	_layout_foreground_texture()


func set_foreground_image_at(image: Image, position: Vector2, material: Material = null) -> void:
	if image == null or image.is_empty():
		clear_foreground()
		return
	set_foreground_texture_at(ImageTexture.create_from_image(image), position, material)


func set_foreground_texture_at(texture: Texture2D, position: Vector2, material: Material = null) -> void:
	_foreground_native_positioned = true
	_foreground_native_position = position
	foreground_texture.texture = texture
	foreground_texture.material = material
	_layout_foreground_texture()


func clear_foreground() -> void:
	_foreground_native_positioned = false
	_foreground_native_position = Vector2.ZERO
	foreground_texture.texture = null
	foreground_texture.material = null
	_layout_foreground_texture()


func clear_preview() -> void:
	_compositor_surface_binding.clear()
	frame_texture.texture = null
	clear_foreground()
	for child in overlay_root.get_children():
		child.queue_free()


func release_preview_focus() -> void:
	if is_instance_valid(display) and display.has_focus():
		display.release_focus()


func logical_position_from_display(local_position: Vector2) -> Vector2:
	if display.size.x <= 0.0 or display.size.y <= 0.0:
		return Vector2.ZERO
	return Vector2(
		clampf(local_position.x * float(LOGICAL_SIZE.x) / display.size.x, 0.0, float(LOGICAL_SIZE.x) - 0.001),
		clampf(local_position.y * float(LOGICAL_SIZE.y) / display.size.y, 0.0, float(LOGICAL_SIZE.y) - 0.001)
	)


func _configure_scale_selector() -> void:
	scale_selector.clear()
	scale_selector.add_item("Fit", ScaleMode.FIT)
	scale_selector.add_item("1x", ScaleMode.ONE_TO_ONE)
	scale_selector.add_item("2x", ScaleMode.TWO_TO_ONE)
	scale_selector.add_item("Integer", ScaleMode.INTEGER)
	scale_selector.select(int(_scale_mode))
	scale_selector.item_selected.connect(_on_scale_selected)


func _layout_display() -> void:
	if not is_node_ready():
		return
	var available := preview_surface.size
	if available.x <= 0.0 or available.y <= 0.0:
		return
	var fit_scale := minf(available.x / float(LOGICAL_SIZE.x), available.y / float(LOGICAL_SIZE.y))
	var scale := fit_scale
	match _scale_mode:
		ScaleMode.ONE_TO_ONE:
			scale = 1.0
		ScaleMode.TWO_TO_ONE:
			scale = 2.0
		ScaleMode.INTEGER:
			scale = maxf(1.0, floorf(fit_scale))
		_:
			scale = maxf(0.01, fit_scale)
	display.size = Vector2(LOGICAL_SIZE) * scale
	display.position = (available - display.size) * 0.5


func _layout_frame_texture() -> void:
	if not is_node_ready():
		return
	frame_texture.set_anchors_preset(Control.PRESET_TOP_LEFT)
	var logical_size := Vector2(LOGICAL_SIZE)
	match _frame_content_mode:
		FrameContentMode.NATIVE_CENTERED, FrameContentMode.NATIVE_POSITIONED:
			var texture_size := frame_texture.texture.get_size() if frame_texture.texture != null else Vector2.ZERO
			frame_texture.size = texture_size
			frame_texture.position = (
				(logical_size - texture_size) * 0.5
				if _frame_content_mode == FrameContentMode.NATIVE_CENTERED
				else _frame_native_position
			)
			frame_texture.stretch_mode = TextureRect.STRETCH_SCALE
		FrameContentMode.STRETCH:
			frame_texture.position = Vector2.ZERO
			frame_texture.size = logical_size
			frame_texture.stretch_mode = TextureRect.STRETCH_SCALE
		_:
			frame_texture.position = Vector2.ZERO
			frame_texture.size = logical_size
			frame_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED


func _layout_foreground_texture() -> void:
	if not is_node_ready():
		return
	foreground_texture.set_anchors_preset(Control.PRESET_TOP_LEFT)
	if _foreground_native_positioned and foreground_texture.texture != null:
		foreground_texture.position = _foreground_native_position
		foreground_texture.size = foreground_texture.texture.get_size()
		foreground_texture.stretch_mode = TextureRect.STRETCH_SCALE
	else:
		foreground_texture.position = Vector2.ZERO
		foreground_texture.size = Vector2(LOGICAL_SIZE)
		foreground_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED


func _on_scale_selected(index: int) -> void:
	_scale_mode = scale_selector.get_item_id(index) as ScaleMode
	_layout_display()


func _on_display_gui_input(event: InputEvent) -> void:
	var logical_position := Vector2.ZERO
	if event is InputEventMouse:
		logical_position = logical_position_from_display(event.position)
		coordinate_label.text = "%03d, %03d" % [int(logical_position.x), int(logical_position.y)]
		preview_pointer_moved.emit(logical_position)

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		preview_pointer_pressed.emit(logical_position)
		if _input_forwarding_enabled:
			if not display.has_focus():
				display.grab_focus()
				display.accept_event()
				return

	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE and display.has_focus():
		release_preview_focus()
		display.accept_event()
		return

	if not _input_forwarding_enabled or not display.has_focus():
		return

	var forwarded := event.duplicate()
	if forwarded is InputEventMouse:
		forwarded.position = logical_position
		forwarded.global_position = logical_position
	game_viewport.push_input(forwarded, true)
	preview_input.emit(forwarded, logical_position)
	display.accept_event()


func _on_display_focus_entered() -> void:
	_update_focus_label()
	preview_focus_changed.emit(true)


func _on_display_focus_exited() -> void:
	_update_focus_label()
	preview_focus_changed.emit(false)


func _on_display_mouse_exited() -> void:
	coordinate_label.text = "---, ---"


func _update_focus_label() -> void:
	if not is_node_ready():
		return
	if not _input_forwarding_enabled:
		focus_label.text = "Input disabled"
	elif display.has_focus():
		focus_label.text = "Game input focused · Esc releases"
	else:
		focus_label.text = "Click frame for game input"
