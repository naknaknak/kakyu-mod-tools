extends "res://tests/test_case.gd"

const PreviewScene := preload("res://tools/content_suite/apps/tool_game_preview.tscn")
const CompositorScript := preload("res://content_core/logical_surface_compositor.gd")
const TestHelpers := preload("res://tests/test_helpers.gd")

var _forwarded_events := 0
var _pointer_presses := 0


func _ready() -> void:
	var host := Control.new()
	host.size = Vector2(1000, 700)
	add_child(host)
	var preview := PreviewScene.instantiate()
	host.add_child(preview)
	preview.preview_input.connect(_on_preview_input)
	preview.preview_pointer_pressed.connect(_on_preview_pointer_pressed)
	await get_tree().process_frame
	await get_tree().process_frame

	var viewport: SubViewport = preview.get_game_viewport()
	var display: TextureRect = preview.get_node("PreviewSurface/Display")
	_check(viewport.size == Vector2i(640, 400), "tool game preview keeps a fixed 640x400 render viewport")
	_check(display.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "tool game preview uses nearest texture filtering")
	var fit_rect: Rect2 = preview.get_display_rect()
	_check(is_equal_approx(fit_rect.size.x / fit_rect.size.y, 1.6), "Fit mode preserves the game-frame aspect ratio")
	_check(Rect2(Vector2.ZERO, preview.get_node("PreviewSurface").size).encloses(fit_rect), "Fit mode stays inside the available tool panel")

	preview.set_scale_mode(preview.ScaleMode.ONE_TO_ONE)
	_check(preview.get_display_rect().size == Vector2(640, 400), "1x mode uses one desktop pixel per logical pixel")
	var center: Vector2 = preview.logical_position_from_display(Vector2(320, 200))
	_check(center.is_equal_approx(Vector2(320, 200)), "preview maps pointer coordinates into the 640x400 game space")

	var image := Image.create(2, 2, false, Image.FORMAT_RGB8)
	image.fill(Color(0.25, 0.5, 0.75))
	preview.set_preview_image(image)
	_check(preview.get_node("GameViewport/FrameRoot/FrameTexture").texture != null, "preview accepts an image without changing its render viewport")
	preview.set_frame_content_mode(preview.FrameContentMode.NATIVE_CENTERED)
	_check(preview.get_frame_content_rect() == Rect2(Vector2(319, 199), Vector2(2, 2)), "native-centered mode preserves source pixels in game coordinates")
	preview.set_frame_native_position(Vector2(12, 34))
	_check(preview.get_frame_content_rect() == Rect2(Vector2(12, 34), Vector2(2, 2)), "native-positioned mode exposes exact game-frame placement")

	var foreground_image := Image.create(640, 400, false, Image.FORMAT_RGB8)
	foreground_image.fill(Color(0, 1, 0))
	var foreground_material := ShaderMaterial.new()
	preview.set_foreground_image(foreground_image, foreground_material)
	_check(preview.get_foreground_texture() != null, "preview accepts an independent foreground image")
	_check(preview.get_foreground_material() == foreground_material, "preview preserves the caller-provided foreground material")
	_check(preview.get_node("GameViewport/FrameRoot/FrameTexture").texture != null, "setting a foreground does not replace the background frame")
	var positioned_foreground := Image.create(104, 112, false, Image.FORMAT_RGB8)
	positioned_foreground.fill(Color(1, 0, 0))
	preview.set_foreground_image_at(positioned_foreground, Vector2(216, 48), foreground_material)
	_check(preview.get_foreground_rect() == Rect2(Vector2(216, 48), Vector2(104, 112)), "preview positions a native-size foreground rectangle in 640x400 coordinates")
	preview.set_foreground_image(foreground_image, foreground_material)
	_check(preview.get_foreground_rect() == Rect2(Vector2.ZERO, Vector2(640, 400)), "ordinary foreground presentation resets native positioning")
	preview.clear_foreground()
	_check(preview.get_foreground_texture() == null and preview.get_foreground_material() == null, "foreground clearing leaves no stale texture or material")

	var compositor := CompositorScript.new()
	var composed_frame := Image.create(640, 400, false, Image.FORMAT_RGB8)
	composed_frame.fill(Color(0.1, 0.2, 0.3))
	_check(compositor.register_surface(0, composed_frame, "logical_frame").ok, "preview fixture registers the shared logical surface")
	preview.set_foreground_image(positioned_foreground)
	var compositor_presented: Dictionary = preview.present_compositor_surface(compositor)
	var frame_texture: Texture2D = preview.get_node("GameViewport/FrameRoot/FrameTexture").texture
	_check(
		compositor_presented.ok
		and compositor_presented.schema == "kakyu_tool_game_preview_compositor_binding/v1"
		and compositor_presented.surface_index == 0
		and compositor_presented.surface_role == "logical_frame"
		and compositor_presented.operation_sequence == 0
		and preview.get_foreground_texture() == null
		and frame_texture != null
		and TestHelpers.color_close(frame_texture.get_image().get_pixel(0, 0), Color(0.1, 0.2, 0.3)),
		"shared preview presents a detached compositor surface and removes stale foreground layers"
	)
	var first_binding: Dictionary = preview.get_compositor_surface_binding()
	_check(compositor.set_active_surface(0).ok, "preview fixture selects the logical compositor surface")
	_check(compositor.apply_operation({
		"mode": 2,
		"source_x": 0,
		"source_y": 0,
		"inclusive_right": 0,
		"inclusive_bottom": 0,
		"fill_color": Color.WHITE,
	}).ok, "preview fixture advances the compositor after presentation")
	_check(
		preview.get_compositor_surface_binding() == first_binding
		and TestHelpers.color_close(frame_texture.get_image().get_pixel(0, 0), Color(0.1, 0.2, 0.3)),
		"presented compositor images remain snapshot-bound until an explicit refresh"
	)
	var refreshed_binding: Dictionary = preview.present_compositor_surface(compositor)
	var refreshed_texture: Texture2D = preview.get_node("GameViewport/FrameRoot/FrameTexture").texture
	_check(
		refreshed_binding.ok
		and refreshed_binding.operation_sequence == 1
		and TestHelpers.color_close(refreshed_texture.get_image().get_pixel(0, 0), Color.WHITE),
		"explicit compositor refresh presents the new operation sequence"
	)
	var retained_texture := refreshed_texture
	_check(
		not preview.present_compositor_surface(compositor, 8).ok
		and preview.get_node("GameViewport/FrameRoot/FrameTexture").texture == retained_texture
		and preview.get_compositor_surface_binding().operation_sequence == 1,
		"invalid compositor surfaces fail without replacing the last valid preview"
	)
	preview.set_preview_image(image)
	_check(preview.get_compositor_surface_binding().is_empty(), "direct image presentation clears stale compositor binding metadata")

	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Vector2(64, 40)
	preview.call("_on_display_gui_input", click)
	_check(not preview.is_preview_focused(), "preview cannot capture input while forwarding is disabled")
	_check(_pointer_presses == 1, "preview reports logical pointer presses without enabling game input")
	preview.set_input_forwarding_enabled(true)
	preview.call("_on_display_gui_input", click)
	_check(preview.is_preview_focused(), "explicit frame click focuses game input")
	_check(_forwarded_events == 0, "focus-acquisition click is not also delivered as a game action")
	preview.call("_on_display_gui_input", click)
	_check(_forwarded_events == 1, "focused preview forwards a later click through the bounded input surface")

	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	preview.call("_on_display_gui_input", escape)
	_check(not preview.is_preview_focused(), "Escape releases preview input focus")
	preview.call("_on_display_gui_input", click)
	preview.release_preview_focus()
	var key := InputEventKey.new()
	key.keycode = KEY_SPACE
	key.pressed = true
	preview.call("_on_display_gui_input", key)
	_check(_forwarded_events == 1, "unfocused preview does not forward keyboard input")

	host.queue_free()
	await get_tree().process_frame
	get_tree().quit(1 if _failed else 0)


func _on_preview_input(_event: InputEvent, _logical_position: Vector2) -> void:
	_forwarded_events += 1


func _on_preview_pointer_pressed(_logical_position: Vector2) -> void:
	_pointer_presses += 1
