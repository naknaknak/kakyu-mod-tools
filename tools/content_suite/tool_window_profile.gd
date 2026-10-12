class_name ContentToolWindowProfile
extends RefCounted

const DEFAULT_SIZE := Vector2i(1280, 800)
const MINIMUM_SIZE := Vector2i(1024, 640)


static func scale_for_dpi(dpi: int) -> float:
	if dpi <= 0:
		return 1.0
	var rounded := roundf((dpi / 96.0) / 0.25) * 0.25
	return clampf(rounded, 1.0, 3.0)


static func apply(window: Window, scale := 0.0) -> void:
	if window == null:
		return
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	window.content_scale_size = Vector2i.ZERO
	var factor := scale if scale > 0.0 else scale_for_dpi(DisplayServer.screen_get_dpi(window.current_screen))
	window.content_scale_factor = factor
	window.min_size = Vector2i(Vector2(MINIMUM_SIZE) * factor)
	if window.size.x < window.min_size.x or window.size.y < window.min_size.y:
		window.size = Vector2i(Vector2(DEFAULT_SIZE) * factor)
	if scale <= 0.0:
		var callable := Callable(ContentToolWindowProfile, "_on_dpi_changed").bind(window)
		if not window.dpi_changed.is_connected(callable):
			window.dpi_changed.connect(callable)


static func _on_dpi_changed(window: Window) -> void:
	apply(window)
