extends "res://tests/test_case.gd"

const MmoCodecScript := preload("res://content_core/mmo_codec.gd")
const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")
const SyntheticArc := preload("res://tests/synthetic_arc.gd")


func _ready() -> void:
	var codec := MmoCodecScript.new()
	var mmo := _build_test_mmo()
	var metadata := codec.inspect(mmo)
	_check(
		metadata.ok
		and metadata.schema == ContentCoreVersionScript.MMO_HEADER_PROFILE_SCHEMA
		and metadata.width == 2
		and metadata.height == 2
		and metadata.secondary_width == 2
		and metadata.secondary_height == 2
		and metadata.header_profile == codec.PROFILE_STANDARD,
		"MMO standard mirrored-dimension header inspect"
	)
	var decoded := codec.decode_image(mmo)
	_check(decoded.ok and decoded.complete, "literal-compressed MMO decodes")
	if decoded.ok:
		var image: Image = decoded.image
		_check(image.get_pixel(0, 0).is_equal_approx(Color(1, 0, 0)), "MMO top-left pixel restores red")
		_check(image.get_pixel(1, 0).is_equal_approx(Color(0, 1, 0)), "MMO top-right pixel restores green")
		_check(image.get_pixel(0, 1).is_equal_approx(Color(0, 0, 1)), "MMO bottom-left pixel restores blue")
		_check(image.get_pixel(1, 1).is_equal_approx(Color(1, 1, 1)), "MMO bottom-right pixel restores white")
		var template_header := mmo.slice(0, 0x28)
		var encoded := codec.encode_image(image, template_header)
		_check(encoded.ok and encoded.compatibility == "original_engine_compatible", "template-bound MMO is engine-compatible")
		_check(encoded.ok and encoded.header_profile == codec.PROFILE_STANDARD and encoded.header_origin == "target_template_preserved", "standard target header provenance is explicit")
		_check(encoded.ok and encoded.data.slice(0, 0x28) == template_header, "MMO encoder preserves the exact standard template header")
		var round_trip := codec.decode_image(encoded.data) if encoded.ok else {"ok": false}
		_check(round_trip.ok and _images_equal(image, round_trip.image), "MMO pixel encode/decode round trip")
		var mismatch := Image.create(1, 1, false, Image.FORMAT_RGB8)
		_check(not codec.encode_image(mismatch, template_header).ok, "MMO template dimension mismatch is rejected")
		var generated := codec.encode_image(image)
		_check(
			generated.ok
			and generated.compatibility == "remake_only"
			and generated.header_origin == "generated_canonical"
			and generated.data.decode_u32(28) == 2
			and generated.data.decode_u32(32) == 2,
			"generated canonical mirrored header is explicitly remake-only"
		)
		var flagged_header := template_header.duplicate()
		flagged_header.encode_u32(8, 3)
		flagged_header.encode_u32(28, 640)
		flagged_header.encode_u32(32, 400)
		var flagged := codec.encode_image(image, flagged_header)
		_check(
			flagged.ok
			and flagged.header_profile == codec.PROFILE_FLAGGED_SECONDARY
			and flagged.compatibility == "remake_only"
			and flagged.data.slice(0, 0x28) == flagged_header,
			"flagged secondary-dimension target header is preserved but not engine-certified"
		)
		var tailed_header := template_header.duplicate()
		tailed_header.encode_u32(36, 123)
		var tailed := codec.encode_image(image, tailed_header)
		_check(
			tailed.ok
			and tailed.header_profile == codec.PROFILE_NONZERO_TRAILER
			and tailed.compatibility == "remake_only"
			and tailed.data.slice(0, 0x28) == tailed_header,
			"nonzero-trailer target header is preserved but not engine-certified"
		)
		var unclassified_header := template_header.duplicate()
		unclassified_header.encode_u32(4, 1)
		var unclassified := codec.encode_image(image, unclassified_header)
		_check(
			unclassified.ok
			and unclassified.header_profile == codec.PROFILE_UNCLASSIFIED
			and unclassified.compatibility == "remake_only",
			"unclassified target header fails closed to remake-only compatibility"
		)
		_check(not codec.encode_image(image, PackedByteArray([1, 2, 3])).ok, "short MMO template header is rejected")

	var truncated := mmo.slice(0, mmo.size() - 3)
	_check(not codec.decode_image(truncated).ok, "short MMO decode is strict by default")
	var padded := codec.decode_image(truncated, true)
	_check(padded.ok and padded.padded_bytes > 0, "explicit preview mode reports zero padding")
	var invalid := mmo.duplicate()
	invalid.encode_u32(12, 0)
	_check(not codec.inspect(invalid).ok, "invalid MMO dimensions are rejected")

	await get_tree().process_frame
	get_tree().quit(1 if _failed else 0)


func _build_test_mmo() -> PackedByteArray:
	var restored_bgr := PackedByteArray([
		255, 0, 0, 255, 255, 255,
		0, 0, 255, 0, 255, 0,
	])
	var delta := restored_bgr.duplicate()
	for index in range(3, 6):
		delta[index] = (int(restored_bgr[index]) - int(restored_bgr[index - 3])) & 0xFF
	for index in range(6, 12):
		delta[index] = (int(restored_bgr[index]) - int(restored_bgr[index - 6])) & 0xFF
	var compressed := _literal_compress(delta)
	var data := PackedByteArray()
	data.resize(0x28)
	data.fill(0)
	SyntheticArc.write_ascii(data, 0, "MMO ")
	data.encode_u32(12, 2)
	data.encode_u32(16, 2)
	data.encode_u32(28, 2)
	data.encode_u32(32, 2)
	data.append_array(compressed)
	return data


func _literal_compress(data: PackedByteArray) -> PackedByteArray:
	var output := PackedByteArray()
	var offset := 0
	while offset < data.size():
		var count := mini(8, data.size() - offset)
		output.append((1 << count) - 1)
		output.append_array(data.slice(offset, offset + count))
		offset += count
	return output


func _images_equal(left: Image, right: Image) -> bool:
	return (
		left.get_width() == right.get_width()
		and left.get_height() == right.get_height()
		and left.get_data() == right.get_data()
	)
