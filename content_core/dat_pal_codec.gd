class_name KakyuDatPalCodec
extends RefCounted

const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")

const DIMENSIONS_BY_SIZE := {
	20480: Vector2i(640, 32),
	40960: Vector2i(640, 64),
	184320: Vector2i(640, 288),
	256000: Vector2i(640, 400),
}
const PALETTE_BYTES := 256 * 3


func inspect(dat_data: PackedByteArray, pal_data: PackedByteArray) -> Dictionary:
	if not DIMENSIONS_BY_SIZE.has(dat_data.size()):
		return _error("Unsupported DAT byte size: %d." % dat_data.size())
	if pal_data.size() != PALETTE_BYTES:
		return _error("PAL must contain exactly %d BGR bytes." % PALETTE_BYTES)
	var dimensions: Vector2i = DIMENSIONS_BY_SIZE[dat_data.size()]
	var transparent := dat_data.size() == 20480
	var used_indices: Dictionary = {}
	var index_zero_pixels := 0
	for palette_index in dat_data:
		var index := int(palette_index)
		used_indices[index] = true
		if index == 0:
			index_zero_pixels += 1
	return {
		"ok": true,
		"diagnostics_schema": ContentCoreVersionScript.DAT_PAL_DIAGNOSTICS_SCHEMA,
		"width": dimensions.x,
		"height": dimensions.y,
		"transparent_index_zero": transparent,
		"index_zero_reserved": transparent,
		"index_zero_pixel_count": index_zero_pixels,
		"transparent_pixel_count": index_zero_pixels if transparent else 0,
		"opaque_pixel_count": dat_data.size() - index_zero_pixels if transparent else dat_data.size(),
		"used_palette_entries": used_indices.size(),
		"used_opaque_palette_entries": used_indices.size() - (1 if transparent and used_indices.has(0) else 0),
		"unused_palette_entries": 256 - used_indices.size(),
	}


func decode_image(dat_data: PackedByteArray, pal_data: PackedByteArray) -> Dictionary:
	var metadata := inspect(dat_data, pal_data)
	if not metadata.ok:
		return metadata
	var width := int(metadata.width)
	var height := int(metadata.height)
	var transparent := bool(metadata.transparent_index_zero)
	var channels := 4 if transparent else 3
	var pixels := PackedByteArray()
	pixels.resize(width * height * channels)
	for target_y in range(height):
		var source_row := (height - 1 - target_y) * width
		var target_row := target_y * width * channels
		for x in range(width):
			var palette_index := int(dat_data[source_row + x])
			var palette_offset := palette_index * 3
			var target := target_row + x * channels
			pixels[target] = pal_data[palette_offset + 2]
			pixels[target + 1] = pal_data[palette_offset + 1]
			pixels[target + 2] = pal_data[palette_offset]
			if transparent:
				pixels[target + 3] = 0 if palette_index == 0 else 255
	var format := Image.FORMAT_RGBA8 if transparent else Image.FORMAT_RGB8
	var image := Image.create_from_data(width, height, false, format, pixels)
	if image == null or image.is_empty():
		return _error("Godot could not create the decoded DAT/PAL image.")
	return {
		"ok": true,
		"image": image,
		"width": width,
		"height": height,
		"transparent_index_zero": transparent,
		"diagnostics_schema": metadata.diagnostics_schema,
		"index_zero_reserved": metadata.index_zero_reserved,
		"index_zero_pixel_count": metadata.index_zero_pixel_count,
		"transparent_pixel_count": metadata.transparent_pixel_count,
		"opaque_pixel_count": metadata.opaque_pixel_count,
		"used_palette_entries": metadata.used_palette_entries,
		"used_opaque_palette_entries": metadata.used_opaque_palette_entries,
		"unused_palette_entries": metadata.unused_palette_entries,
	}


func inspect_palette(dat_data: PackedByteArray, pal_data: PackedByteArray) -> Dictionary:
	var metadata := inspect(dat_data, pal_data)
	if not metadata.ok:
		return metadata
	var use_counts := PackedInt32Array()
	use_counts.resize(256)
	for palette_index in dat_data:
		use_counts[int(palette_index)] += 1
	var entries: Array = []
	for index in range(256):
		var offset := index * 3
		var blue := int(pal_data[offset])
		var green := int(pal_data[offset + 1])
		var red := int(pal_data[offset + 2])
		entries.append({
			"index": index,
			"red": red,
			"green": green,
			"blue": blue,
			"color": Color8(red, green, blue, 255),
			"use_count": int(use_counts[index]),
			"used": int(use_counts[index]) > 0,
			"reserved_transparent": bool(metadata.index_zero_reserved) and index == 0,
		})
	return {
		"ok": true,
		"schema": ContentCoreVersionScript.DAT_PAL_PALETTE_SCHEMA,
		"entries": entries,
		"transparent_index_zero": metadata.transparent_index_zero,
		"used_palette_entries": metadata.used_palette_entries,
		"unused_palette_entries": metadata.unused_palette_entries,
	}


func replace_palette_entry(
	pal_data: PackedByteArray,
	index: int,
	color: Color,
	index_zero_reserved: bool = false
) -> Dictionary:
	if pal_data.size() != PALETTE_BYTES:
		return _error("PAL must contain exactly %d BGR bytes." % PALETTE_BYTES)
	if index < 0 or index >= 256:
		return _error("PAL entry index must be between 0 and 255.")
	if index_zero_reserved and index == 0:
		return _error("PAL entry zero is reserved for transparent pixels in 640x32 strips.")
	if (
		not is_finite(color.r)
		or not is_finite(color.g)
		or not is_finite(color.b)
		or not is_finite(color.a)
		or color.r < 0.0
		or color.r > 1.0
		or color.g < 0.0
		or color.g > 1.0
		or color.b < 0.0
		or color.b > 1.0
		or not is_equal_approx(color.a, 1.0)
	):
		return _error("PAL colors must be finite opaque RGB values in the 0..1 range.")
	var offset := index * 3
	var previous := Color8(int(pal_data[offset + 2]), int(pal_data[offset + 1]), int(pal_data[offset]), 255)
	var red := clampi(roundi(color.r * 255.0), 0, 255)
	var green := clampi(roundi(color.g * 255.0), 0, 255)
	var blue := clampi(roundi(color.b * 255.0), 0, 255)
	var replaced := pal_data.duplicate()
	replaced[offset] = blue
	replaced[offset + 1] = green
	replaced[offset + 2] = red
	return {
		"ok": true,
		"schema": ContentCoreVersionScript.DAT_PAL_PALETTE_SCHEMA,
		"pal_data": replaced,
		"index": index,
		"previous_color": previous,
		"color": Color8(red, green, blue, 255),
		"bgr": PackedByteArray([blue, green, red]),
		"changed": replaced != pal_data,
	}


func encode_image(image: Image) -> Dictionary:
	if image == null or image.is_empty():
		return _error("DAT/PAL source image is empty.")
	var width := image.get_width()
	var height := image.get_height()
	var dat_size := width * height
	if width != 640 or not DIMENSIONS_BY_SIZE.has(dat_size):
		return _error("DAT/PAL source dimensions are not one of the supported 640-pixel layouts.")
	var transparent := dat_size == 20480
	var normalized: Image = image.duplicate()
	normalized.convert(Image.FORMAT_RGBA8)
	var rgba := normalized.get_data()
	var histogram: Dictionary = {}
	var transparent_pixels := 0
	var opaque_pixels := 0
	for pixel_index in range(dat_size):
		var offset := pixel_index * 4
		var alpha := int(rgba[offset + 3])
		if transparent:
			if alpha != 0 and alpha != 255:
				return _error("640x32 DAT/PAL images require binary alpha.")
			if alpha == 0:
				transparent_pixels += 1
				continue
		elif alpha != 255:
			return _error("Opaque DAT/PAL layouts do not support alpha.")
		opaque_pixels += 1
		var key := _rgb_key(rgba[offset], rgba[offset + 1], rgba[offset + 2])
		histogram[key] = int(histogram.get(key, 0)) + 1

	var palette_limit := 255 if transparent else 256
	var palette_colors := _build_palette(histogram, palette_limit)
	var color_to_index := _map_colors_to_palette(histogram, palette_colors)
	var palette_offset := 1 if transparent else 0
	var dat_data := PackedByteArray()
	dat_data.resize(dat_size)
	for target_y in range(height):
		var source_row := target_y * width * 4
		var target_row := (height - 1 - target_y) * width
		for x in range(width):
			var source := source_row + x * 4
			if transparent and int(rgba[source + 3]) == 0:
				dat_data[target_row + x] = 0
				continue
			var key := _rgb_key(rgba[source], rgba[source + 1], rgba[source + 2])
			dat_data[target_row + x] = int(color_to_index[key]) + palette_offset

	var pal_data := PackedByteArray()
	pal_data.resize(PALETTE_BYTES)
	pal_data.fill(0)
	for index in range(palette_colors.size()):
		var key := int(palette_colors[index])
		var target := (index + palette_offset) * 3
		pal_data[target] = key & 0xFF
		pal_data[target + 1] = (key >> 8) & 0xFF
		pal_data[target + 2] = (key >> 16) & 0xFF
	var diagnostics := _quantization_diagnostics(
		histogram,
		palette_colors,
		color_to_index,
		opaque_pixels,
		transparent_pixels,
		palette_limit,
		transparent
	)
	return {
		"ok": true,
		"dat_data": dat_data,
		"pal_data": pal_data,
		"width": width,
		"height": height,
		"transparent_index_zero": transparent,
		"source_colors": histogram.size(),
		"palette_colors": palette_colors.size(),
		"quantized": histogram.size() > palette_limit,
		"diagnostics_schema": ContentCoreVersionScript.DAT_PAL_DIAGNOSTICS_SCHEMA,
		"diagnostics": diagnostics,
		"compatibility": "original_engine_unverified",
	}


func _quantization_diagnostics(
	histogram: Dictionary,
	palette: Array,
	color_to_index: Dictionary,
	opaque_pixels: int,
	transparent_pixels: int,
	palette_limit: int,
	index_zero_reserved: bool
) -> Dictionary:
	var changed_colors := 0
	var changed_pixels := 0
	var sum_absolute_error := 0
	var sum_squared_error := 0
	var maximum_channel_error := 0
	var maximum_squared_error := 0
	for untyped_key in histogram:
		var source_key := int(untyped_key)
		var count := int(histogram[source_key])
		var palette_index := int(color_to_index[source_key])
		var target_key := int(palette[palette_index])
		var red_delta: int = abs(((source_key >> 16) & 0xFF) - ((target_key >> 16) & 0xFF))
		var green_delta: int = abs(((source_key >> 8) & 0xFF) - ((target_key >> 8) & 0xFF))
		var blue_delta: int = abs((source_key & 0xFF) - (target_key & 0xFF))
		var squared_error: int = red_delta * red_delta + green_delta * green_delta + blue_delta * blue_delta
		if squared_error > 0:
			changed_colors += 1
			changed_pixels += count
		sum_absolute_error += (red_delta + green_delta + blue_delta) * count
		sum_squared_error += squared_error * count
		maximum_channel_error = maxi(maximum_channel_error, maxi(red_delta, maxi(green_delta, blue_delta)))
		maximum_squared_error = maxi(maximum_squared_error, squared_error)
	var rgb_sample_count := opaque_pixels * 3
	var mean_absolute_error := 0.0
	var root_mean_square_error := 0.0
	if rgb_sample_count > 0:
		mean_absolute_error = float(sum_absolute_error) / float(rgb_sample_count)
		root_mean_square_error = sqrt(float(sum_squared_error) / float(rgb_sample_count))
	return {
		"schema": ContentCoreVersionScript.DAT_PAL_DIAGNOSTICS_SCHEMA,
		"palette_limit": palette_limit,
		"source_color_count": histogram.size(),
		"palette_color_count": palette.size(),
		"opaque_pixel_count": opaque_pixels,
		"transparent_pixel_count": transparent_pixels,
		"index_zero_reserved": index_zero_reserved,
		"index_zero_pixel_count": transparent_pixels if index_zero_reserved else 0,
		"changed_color_count": changed_colors,
		"changed_pixel_count": changed_pixels,
		"exact_pixel_count": opaque_pixels - changed_pixels,
		"sum_absolute_rgb_error": sum_absolute_error,
		"sum_squared_rgb_error": sum_squared_error,
		"mean_absolute_rgb_error": mean_absolute_error,
		"root_mean_square_rgb_error": root_mean_square_error,
		"maximum_channel_error": maximum_channel_error,
		"maximum_squared_rgb_error": maximum_squared_error,
		"quantized": changed_pixels > 0,
	}


func _build_palette(histogram: Dictionary, limit: int) -> Array:
	var colors: Array = histogram.keys()
	colors.sort()
	if colors.size() <= limit:
		return colors
	var boxes: Array = [colors]
	while boxes.size() < limit:
		var selected := -1
		var selected_score := -1
		for index in range(boxes.size()):
			var box: Array = boxes[index]
			if box.size() < 2:
				continue
			var info := _box_info(box, histogram)
			var score := int(info.range) * int(info.population)
			if score > selected_score:
				selected = index
				selected_score = score
		if selected < 0:
			break
		var split := _split_box(boxes[selected], histogram)
		boxes[selected] = split.left
		boxes.append(split.right)
	var palette: Array = []
	for box in boxes:
		palette.append(_average_box(box, histogram))
	return palette


func _box_info(colors: Array, histogram: Dictionary) -> Dictionary:
	var minimum := Vector3i(255, 255, 255)
	var maximum := Vector3i.ZERO
	var population := 0
	for untyped_key in colors:
		var key := int(untyped_key)
		var rgb := Vector3i((key >> 16) & 0xFF, (key >> 8) & 0xFF, key & 0xFF)
		minimum = Vector3i(mini(minimum.x, rgb.x), mini(minimum.y, rgb.y), mini(minimum.z, rgb.z))
		maximum = Vector3i(maxi(maximum.x, rgb.x), maxi(maximum.y, rgb.y), maxi(maximum.z, rgb.z))
		population += int(histogram[key])
	var ranges := maximum - minimum
	var channel := 0
	if ranges.y > ranges.x and ranges.y >= ranges.z:
		channel = 1
	elif ranges.z > ranges.x and ranges.z > ranges.y:
		channel = 2
	return {"channel": channel, "range": maxi(ranges.x, maxi(ranges.y, ranges.z)), "population": population}


func _split_box(colors: Array, histogram: Dictionary) -> Dictionary:
	var sorted := colors.duplicate()
	var info := _box_info(sorted, histogram)
	var channel := int(info.channel)
	sorted.sort_custom(func(left, right) -> bool:
		var left_key := int(left)
		var right_key := int(right)
		var left_value := (left_key >> (16 - channel * 8)) & 0xFF
		var right_value := (right_key >> (16 - channel * 8)) & 0xFF
		return left_key < right_key if left_value == right_value else left_value < right_value
	)
	var half := float(info.population) / 2.0
	var cumulative := 0
	var split_index := 1
	for index in range(sorted.size() - 1):
		cumulative += int(histogram[int(sorted[index])])
		if cumulative >= half:
			split_index = index + 1
			break
	return {"left": sorted.slice(0, split_index), "right": sorted.slice(split_index)}


func _average_box(colors: Array, histogram: Dictionary) -> int:
	var red := 0
	var green := 0
	var blue := 0
	var total := 0
	for untyped_key in colors:
		var key := int(untyped_key)
		var count := int(histogram[key])
		red += ((key >> 16) & 0xFF) * count
		green += ((key >> 8) & 0xFF) * count
		blue += (key & 0xFF) * count
		total += count
	return _rgb_key(roundi(float(red) / total), roundi(float(green) / total), roundi(float(blue) / total))


func _map_colors_to_palette(histogram: Dictionary, palette: Array) -> Dictionary:
	var mapped: Dictionary = {}
	for untyped_key in histogram:
		var key := int(untyped_key)
		var red := (key >> 16) & 0xFF
		var green := (key >> 8) & 0xFF
		var blue := key & 0xFF
		var best_index := 0
		var best_distance := 0x7FFFFFFF
		for index in range(palette.size()):
			var candidate := int(palette[index])
			var red_delta := red - ((candidate >> 16) & 0xFF)
			var green_delta := green - ((candidate >> 8) & 0xFF)
			var blue_delta := blue - (candidate & 0xFF)
			var distance := red_delta * red_delta + green_delta * green_delta + blue_delta * blue_delta
			if distance < best_distance:
				best_index = index
				best_distance = distance
		mapped[key] = best_index
	return mapped


func _rgb_key(red: int, green: int, blue: int) -> int:
	return (red << 16) | (green << 8) | blue


func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message}
