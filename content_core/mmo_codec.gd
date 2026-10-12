class_name KakyuMmoCodec
extends RefCounted

const Ai5LzScript := preload("res://content_core/ai5_lz.gd")
const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")
const HEADER_SIZE := 0x28
const MAX_PIXELS := 8 * 1024 * 1024
const PROFILE_STANDARD := "standard_mirrored_dimensions"
const PROFILE_FLAGGED_SECONDARY := "flagged_secondary_dimensions"
const PROFILE_NONZERO_TRAILER := "nonzero_trailer"
const PROFILE_UNCLASSIFIED := "unclassified"


func inspect(data: PackedByteArray) -> Dictionary:
	if data.size() < HEADER_SIZE:
		return _error("MMO entry is smaller than its 0x28-byte header.")
	if data.slice(0, 4).get_string_from_ascii() != "MMO ":
		return _error("MMO signature is invalid.")
	var width := int(data.decode_u32(12))
	var height := int(data.decode_u32(16))
	if width <= 0 or height <= 0 or width > MAX_PIXELS / height:
		return _error("MMO dimensions are invalid or exceed the safety limit.")
	var control := int(data.decode_u32(8))
	var secondary_width := int(data.decode_u32(28))
	var secondary_height := int(data.decode_u32(32))
	var trailer := int(data.decode_u32(36))
	var reserved_zero := (
		int(data.decode_u32(4)) == 0
		and int(data.decode_u32(20)) == 0
		and int(data.decode_u32(24)) == 0
	)
	var profile := PROFILE_UNCLASSIFIED
	if reserved_zero and control == 0 and secondary_width == width and secondary_height == height and trailer == 0:
		profile = PROFILE_STANDARD
	elif reserved_zero and control != 0 and trailer == 0:
		profile = PROFILE_FLAGGED_SECONDARY
	elif reserved_zero and control == 0 and trailer > 0:
		profile = PROFILE_NONZERO_TRAILER
	return {
		"ok": true,
		"schema": ContentCoreVersionScript.MMO_HEADER_PROFILE_SCHEMA,
		"width": width,
		"height": height,
		"secondary_width": secondary_width,
		"secondary_height": secondary_height,
		"control": control,
		"trailer": trailer,
		"reserved_zero": reserved_zero,
		"header_profile": profile,
		"target_template_compatibility": (
			"original_engine_compatible" if profile == PROFILE_STANDARD else "remake_only"
		),
		"pixels": width * height,
		"decoded_bytes": width * height * 3,
		"compressed_bytes": data.size() - HEADER_SIZE,
	}


func decode_image(data: PackedByteArray, allow_padding := false) -> Dictionary:
	var metadata := inspect(data)
	if not metadata.ok:
		return metadata
	var decompressed := Ai5LzScript.decompress(data.slice(HEADER_SIZE), int(metadata.decoded_bytes))
	if not decompressed.ok:
		return decompressed
	var decoded: PackedByteArray = decompressed.data
	var padded_bytes := int(metadata.decoded_bytes) - decoded.size()
	if padded_bytes > 0 and not allow_padding:
		return _error(
			"MMO decompressed %d bytes, expected %d." %
			[decoded.size(), int(metadata.decoded_bytes)]
		)
	if padded_bytes > 0:
		decoded.resize(int(metadata.decoded_bytes))

	_restore_delta(decoded, int(metadata.width), int(metadata.height))
	var rgb := _bgr_to_rgb_and_flip(decoded, int(metadata.width), int(metadata.height))
	var image := Image.create_from_data(
		int(metadata.width),
		int(metadata.height),
		false,
		Image.FORMAT_RGB8,
		rgb
	)
	if image == null or image.is_empty():
		return _error("Godot could not create the decoded MMO image.")
	return {
		"ok": true,
		"image": image,
		"width": metadata.width,
		"height": metadata.height,
		"header_schema": metadata.schema,
		"header_profile": metadata.header_profile,
		"header_control": metadata.control,
		"header_trailer": metadata.trailer,
		"secondary_width": metadata.secondary_width,
		"secondary_height": metadata.secondary_height,
		"target_template_compatibility": metadata.target_template_compatibility,
		"decoded_bytes": metadata.decoded_bytes,
		"compressed_bytes": metadata.compressed_bytes,
		"padded_bytes": padded_bytes,
		"complete": padded_bytes == 0,
	}


func encode_image(image: Image, template_header := PackedByteArray()) -> Dictionary:
	if image == null or image.is_empty():
		return _error("MMO source image is empty.")
	var width := image.get_width()
	var height := image.get_height()
	if width <= 0 or height <= 0 or width > MAX_PIXELS / height:
		return _error("MMO source dimensions are invalid or exceed the safety limit.")

	var generated_header := template_header.is_empty()
	var header := PackedByteArray()
	var template_profile := PROFILE_STANDARD
	if generated_header:
		header.resize(HEADER_SIZE)
		header.fill(0)
		_write_ascii(header, 0, "MMO ")
	else:
		if template_header.size() != HEADER_SIZE:
			return _error("MMO template header must contain exactly 0x28 bytes.")
		if template_header.slice(0, 4).get_string_from_ascii() != "MMO ":
			return _error("MMO template header signature is invalid.")
		var inspected_template := inspect(template_header)
		if not inspected_template.ok:
			return inspected_template
		var template_width := int(inspected_template.width)
		var template_height := int(inspected_template.height)
		if template_width != width or template_height != height:
			return _error(
				"MMO replacement dimensions %dx%d do not match template %dx%d." %
				[width, height, template_width, template_height]
			)
		header = template_header.duplicate()
		template_profile = str(inspected_template.header_profile)
	header.encode_u32(12, width)
	header.encode_u32(16, height)
	if generated_header:
		header.encode_u32(28, width)
		header.encode_u32(32, height)

	var rgb_image: Image = image.duplicate()
	rgb_image.convert(Image.FORMAT_RGB8)
	var restored_bgr := _rgb_to_bgr_and_flip(rgb_image.get_data(), width, height)
	var delta := _apply_delta(restored_bgr, width, height)
	var compressed := Ai5LzScript.compress(delta)
	if not compressed.ok:
		return compressed
	var data := header.duplicate()
	data.append_array(compressed.data)
	return {
		"ok": true,
		"data": data,
		"width": width,
		"height": height,
		"decoded_bytes": delta.size(),
		"compressed_bytes": compressed.compressed_bytes,
		"generated_header": generated_header,
		"template_header_preserved": not generated_header,
		"header_origin": "generated_canonical" if generated_header else "target_template_preserved",
		"header_profile": template_profile,
		"compatibility": (
			"original_engine_compatible"
			if not generated_header and template_profile == PROFILE_STANDARD
			else "remake_only"
		),
		"literal_tokens": compressed.literal_tokens,
		"reference_tokens": compressed.reference_tokens,
	}


func _restore_delta(data: PackedByteArray, width: int, height: int) -> void:
	var stride := width * 3
	for index in range(3, stride):
		data[index] = (int(data[index]) + int(data[index - 3])) & 0xFF
	for y in range(1, height):
		var row := y * stride
		var previous := row - stride
		for x in range(stride):
			data[row + x] = (int(data[row + x]) + int(data[previous + x])) & 0xFF


func _bgr_to_rgb_and_flip(data: PackedByteArray, width: int, height: int) -> PackedByteArray:
	var stride := width * 3
	var output := PackedByteArray()
	output.resize(data.size())
	for target_y in range(height):
		var source_row := (height - 1 - target_y) * stride
		var target_row := target_y * stride
		for x in range(width):
			var source := source_row + x * 3
			var target := target_row + x * 3
			output[target] = data[source + 2]
			output[target + 1] = data[source + 1]
			output[target + 2] = data[source]
	return output


func _rgb_to_bgr_and_flip(data: PackedByteArray, width: int, height: int) -> PackedByteArray:
	var stride := width * 3
	var output := PackedByteArray()
	output.resize(data.size())
	for target_y in range(height):
		var source_row := (height - 1 - target_y) * stride
		var target_row := target_y * stride
		for x in range(width):
			var source := source_row + x * 3
			var target := target_row + x * 3
			output[target] = data[source + 2]
			output[target + 1] = data[source + 1]
			output[target + 2] = data[source]
	return output


func _apply_delta(data: PackedByteArray, width: int, height: int) -> PackedByteArray:
	var stride := width * 3
	var output := PackedByteArray()
	output.resize(data.size())
	for index in range(stride):
		output[index] = data[index] if index < 3 else (int(data[index]) - int(data[index - 3])) & 0xFF
	for y in range(1, height):
		var row := y * stride
		var previous := row - stride
		for x in range(stride):
			output[row + x] = (int(data[row + x]) - int(data[previous + x])) & 0xFF
	return output


func _write_ascii(target: PackedByteArray, offset: int, value: String) -> void:
	var bytes := value.to_ascii_buffer()
	for index in range(bytes.size()):
		target[offset + index] = bytes[index]


func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message}
