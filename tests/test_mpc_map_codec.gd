extends "res://tests/test_case.gd"

const MpcMapCodecScript := preload("res://content_core/mpc_map_codec.gd")


func _ready() -> void:
	var mpc := PackedByteArray([1, 0, 1, 0])
	var packed := 0 | (1 << 10)
	mpc.append(packed & 0xFF)
	mpc.append((packed >> 8) & 0xFF)
	mpc.append((packed >> 16) & 0xFF)
	var atlas := PackedByteArray()
	atlas.resize(640 * 400)
	atlas.fill(0)
	for y in range(384, 400):
		for x in range(16):
			atlas[y * 640 + x] = 1
	atlas[384 * 640 + 16] = 2
	var palette := PackedByteArray()
	palette.resize(768)
	palette.fill(0)
	palette[3] = 255
	palette[8] = 255

	var codec := MpcMapCodecScript.new()
	var composed := codec.compose_viewport(mpc, atlas, palette, Vector2i.ZERO, Vector2i(16, 16))
	_check(composed.ok, "MPC codec composes a bounded cell viewport")
	if composed.ok:
		var image: Image = composed.image
		_check(image.get_pixel(0, 0).is_equal_approx(Color(1, 0, 0, 1)), "MPC overlay tile replaces nonzero pixels")
		_check(image.get_pixel(1, 0).is_equal_approx(Color(0, 0, 1, 1)), "MPC overlay index zero preserves the base tile")
		_check(composed.map_width_cells == 1 and composed.map_height_cells == 1, "MPC codec reports stored map dimensions")
		var actor_strip := Image.create(32, 16, false, Image.FORMAT_RGBA8)
		actor_strip.fill(Color(0, 0, 0, 0))
		actor_strip.fill_rect(Rect2i(16, 0, 16, 16), Color(1, 1, 0, 1))
		var with_actor := codec.composite_actor(
			image,
			actor_strip,
			Vector2i.ZERO,
			Vector2i.ZERO,
			1,
			Vector2i(16, 16)
		)
		_check(with_actor.ok, "MPC codec composites a selected actor frame at cell scale")
		if with_actor.ok:
			_check(with_actor.actor_pixel == Vector2i.ZERO, "MPC actor cell resolves to the camera-relative logical pixel")
			_check((with_actor.image as Image).get_pixel(0, 0).is_equal_approx(Color(1, 1, 0, 1)), "MPC actor alpha-blends over the map viewport")
		_check(not codec.composite_actor(image, actor_strip, Vector2i.ZERO, Vector2i(1, 0), 1, Vector2i(16, 16)).ok, "MPC codec rejects an actor footprint outside the viewport")
		_check(not codec.composite_actor(image, actor_strip, Vector2i.ZERO, Vector2i.ZERO, 2, Vector2i(16, 16)).ok, "MPC codec rejects an actor frame outside the strip")
	_check(not codec.compose_viewport(mpc, atlas, palette, Vector2i(1, 0), Vector2i(16, 16)).ok, "MPC codec rejects an out-of-grid camera")
	var wrapped := codec.compose_viewport(mpc, atlas, palette, Vector2i(1, 0), Vector2i(16, 16), true)
	_check(wrapped.ok and wrapped.wrap_at_map_edges and wrapped.image.get_pixel(0, 0) == composed.image.get_pixel(0, 0), "MPC codec explicitly wraps an out-of-grid tool-projection camera")
	_check(not codec.compose_viewport(mpc, atlas, palette, Vector2i.ZERO, Vector2i(15, 16)).ok, "MPC codec rejects a non-cell-aligned viewport")
	var malformed := mpc.duplicate()
	malformed.resize(malformed.size() - 1)
	_check(not codec.inspect(malformed).ok, "MPC codec rejects a truncated cell grid")
	await get_tree().process_frame
	get_tree().quit(1 if _failed else 0)
