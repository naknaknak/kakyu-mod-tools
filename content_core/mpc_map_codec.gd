class_name KakyuMpcMapCodec
extends RefCounted

const TILE_SIZE := 16
const ATLAS_WIDTH := 640
const ATLAS_HEIGHT := 400
const ATLAS_COLUMNS := 40
const ATLAS_ROWS := 25
const ATLAS_BYTES := ATLAS_WIDTH * ATLAS_HEIGHT
const PALETTE_BYTES := 256 * 3
const NO_OVERLAY_TILE := 0x3FF


func inspect(mpc_data: PackedByteArray) -> Dictionary:
	if mpc_data.size() < 4:
		return _error("MPC header requires four bytes.")
	var width_cells := int(mpc_data[0]) | (int(mpc_data[1]) << 8)
	var height_cells := int(mpc_data[2]) | (int(mpc_data[3]) << 8)
	if width_cells <= 0 or height_cells <= 0:
		return _error("MPC cell dimensions must be positive.")
	var expected_size := 4 + width_cells * height_cells * 3
	if mpc_data.size() != expected_size:
		return _error("MPC size does not match its 3-byte cell grid: %d != %d." % [mpc_data.size(), expected_size])
	return {
		"ok": true,
		"width_cells": width_cells,
		"height_cells": height_cells,
		"world_width": width_cells * TILE_SIZE,
		"world_height": height_cells * TILE_SIZE,
	}


func compose_viewport(
	mpc_data: PackedByteArray,
	atlas_data: PackedByteArray,
	palette_data: PackedByteArray,
	camera_cell: Vector2i,
	viewport_size: Vector2i = Vector2i(640, 400),
	wrap_at_map_edges := false
) -> Dictionary:
	var metadata := inspect(mpc_data)
	if not metadata.get("ok", false):
		return metadata
	if atlas_data.size() != ATLAS_BYTES:
		return _error("MPC tile atlas must contain exactly %d indices." % ATLAS_BYTES)
	if palette_data.size() != PALETTE_BYTES:
		return _error("MPC tile palette must contain exactly %d BGR bytes." % PALETTE_BYTES)
	if (
		viewport_size.x <= 0
		or viewport_size.y <= 0
		or viewport_size.x % TILE_SIZE != 0
		or viewport_size.y % TILE_SIZE != 0
	):
		return _error("MPC viewport dimensions must be positive 16-pixel multiples.")
	var viewport_cells := Vector2i(viewport_size.x / TILE_SIZE, viewport_size.y / TILE_SIZE)
	if not wrap_at_map_edges and (
		camera_cell.x < 0
		or camera_cell.y < 0
		or camera_cell.x + viewport_cells.x > int(metadata.width_cells)
		or camera_cell.y + viewport_cells.y > int(metadata.height_cells)
	):
		return _error("MPC camera viewport is outside the map cell grid.")

	var indices := PackedByteArray()
	indices.resize(viewport_size.x * viewport_size.y)
	for viewport_y in range(viewport_cells.y):
		for viewport_x in range(viewport_cells.x):
			var map_x := camera_cell.x + viewport_x
			var map_y := camera_cell.y + viewport_y
			if wrap_at_map_edges:
				map_x = posmod(map_x, int(metadata.width_cells))
				map_y = posmod(map_y, int(metadata.height_cells))
			var cell_index := map_y * int(metadata.width_cells) + map_x
			var record_offset := 4 + cell_index * 3
			var packed := (
				int(mpc_data[record_offset])
				| (int(mpc_data[record_offset + 1]) << 8)
				| (int(mpc_data[record_offset + 2]) << 16)
			)
			var base_tile := packed & 0x3FF
			var overlay_tile := (packed >> 10) & 0x3FF
			if not _blit_tile(indices, viewport_size, atlas_data, base_tile, viewport_x, viewport_y, false):
				return _error("MPC base tile %d is outside the 40x25 atlas." % base_tile)
			if overlay_tile != NO_OVERLAY_TILE and not _blit_tile(indices, viewport_size, atlas_data, overlay_tile, viewport_x, viewport_y, true):
				return _error("MPC overlay tile %d is outside the 40x25 atlas." % overlay_tile)

	var pixels := PackedByteArray()
	pixels.resize(viewport_size.x * viewport_size.y * 3)
	for pixel_index in range(indices.size()):
		var palette_offset := int(indices[pixel_index]) * 3
		var target := pixel_index * 3
		pixels[target] = palette_data[palette_offset + 2]
		pixels[target + 1] = palette_data[palette_offset + 1]
		pixels[target + 2] = palette_data[palette_offset]
	var image := Image.create_from_data(viewport_size.x, viewport_size.y, false, Image.FORMAT_RGB8, pixels)
	if image == null or image.is_empty():
		return _error("Godot could not create the composed MPC viewport image.")
	return {
		"ok": true,
		"image": image,
		"width": viewport_size.x,
		"height": viewport_size.y,
		"camera_cell": camera_cell,
		"wrap_at_map_edges": wrap_at_map_edges,
		"map_width_cells": int(metadata.width_cells),
		"map_height_cells": int(metadata.height_cells),
	}


func composite_actor(
	viewport_image: Image,
	actor_strip: Image,
	camera_cell: Vector2i,
	actor_cell: Vector2i,
	frame_index: int,
	frame_size: Vector2i = Vector2i(32, 32)
) -> Dictionary:
	if viewport_image == null or viewport_image.is_empty():
		return _error("MPC actor composition requires a viewport image.")
	if actor_strip == null or actor_strip.is_empty():
		return _error("MPC actor composition requires an actor strip image.")
	if frame_size.x <= 0 or frame_size.y <= 0 or frame_index < 0:
		return _error("MPC actor frame selection is invalid.")
	var frame_columns := actor_strip.get_width() / frame_size.x
	var frame_rows := actor_strip.get_height() / frame_size.y
	if (
		actor_strip.get_width() % frame_size.x != 0
		or actor_strip.get_height() % frame_size.y != 0
		or frame_index >= frame_columns * frame_rows
	):
		return _error("MPC actor frame lies outside the source strip.")
	var destination := Vector2i(
		(actor_cell.x - camera_cell.x) * TILE_SIZE,
		(actor_cell.y - camera_cell.y) * TILE_SIZE
	)
	if (
		destination.x < 0
		or destination.y < 0
		or destination.x + frame_size.x > viewport_image.get_width()
		or destination.y + frame_size.y > viewport_image.get_height()
	):
		return _error("MPC actor footprint lies outside the camera viewport.")
	var frame_origin := Vector2i(
		(frame_index % frame_columns) * frame_size.x,
		(frame_index / frame_columns) * frame_size.y
	)
	var composed := viewport_image.duplicate()
	composed.convert(Image.FORMAT_RGBA8)
	var source := actor_strip.duplicate()
	source.convert(Image.FORMAT_RGBA8)
	composed.blend_rect(source, Rect2i(frame_origin, frame_size), destination)
	return {
		"ok": true,
		"image": composed,
		"actor_cell": actor_cell,
		"actor_pixel": destination,
		"frame_index": frame_index,
		"frame_size": frame_size,
	}


func _blit_tile(
	destination: PackedByteArray,
	viewport_size: Vector2i,
	atlas_data: PackedByteArray,
	tile_id: int,
	destination_cell_x: int,
	destination_cell_y: int,
	transparent: bool
) -> bool:
	if tile_id < 0 or tile_id >= ATLAS_COLUMNS * ATLAS_ROWS:
		return false
	var source_x := (tile_id % ATLAS_COLUMNS) * TILE_SIZE
	var source_y := ATLAS_HEIGHT - TILE_SIZE - floori(float(tile_id) / ATLAS_COLUMNS) * TILE_SIZE
	var destination_x := destination_cell_x * TILE_SIZE
	var destination_y := destination_cell_y * TILE_SIZE
	for row in range(TILE_SIZE):
		var source_row := (source_y + row) * ATLAS_WIDTH + source_x
		var destination_row := (destination_y + row) * viewport_size.x + destination_x
		for column in range(TILE_SIZE):
			var color_index := int(atlas_data[source_row + column])
			if not transparent or color_index != 0:
				destination[destination_row + column] = color_index
	return true


func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message}
