extends "res://tests/test_case.gd"

const DatPalCodecScript := preload("res://content_core/dat_pal_codec.gd")
const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")


func _ready() -> void:
	var dat := PackedByteArray()
	dat.resize(640 * 32)
	dat.fill(0)
	dat[0] = 1
	dat[(31 * 640) + 1] = 2
	var palette := PackedByteArray()
	palette.resize(768)
	palette.fill(0)
	palette[3] = 0
	palette[4] = 0
	palette[5] = 255
	palette[6] = 0
	palette[7] = 255
	palette[8] = 0
	var codec := DatPalCodecScript.new()
	var decoded := codec.decode_image(dat, palette)
	_check(decoded.ok and decoded.transparent_index_zero, "character DAT/PAL decodes with index-zero alpha")
	_check(
		decoded.ok
		and decoded.diagnostics_schema == ContentCoreVersionScript.DAT_PAL_DIAGNOSTICS_SCHEMA
		and int(decoded.used_palette_entries) == 3
		and int(decoded.used_opaque_palette_entries) == 2
		and int(decoded.index_zero_pixel_count) == (640 * 32) - 2,
		"DAT/PAL decode reports palette use and reserved index-zero pixels"
	)
	if decoded.ok:
		var image: Image = decoded.image
		_check(image.get_pixel(1, 0).is_equal_approx(Color(0, 1, 0, 1)), "DAT scanlines flip vertically")
		_check(image.get_pixel(0, 31).is_equal_approx(Color(1, 0, 0, 1)), "PAL BGR channels convert to RGB")
		_check(image.get_pixel(0, 0).a == 0.0, "palette index zero becomes transparent")
	var palette_inspection := codec.inspect_palette(dat, palette)
	_check(
		palette_inspection.ok
		and palette_inspection.schema == ContentCoreVersionScript.DAT_PAL_PALETTE_SCHEMA
		and palette_inspection.entries.size() == 256
		and int(palette_inspection.entries[0].use_count) == (640 * 32) - 2
		and bool(palette_inspection.entries[0].reserved_transparent)
		and palette_inspection.entries[1].color == Color8(255, 0, 0, 255)
		and int(palette_inspection.entries[2].use_count) == 1,
		"DAT/PAL palette inspection reports all BGR colors, use counts, and reserved index zero"
	)
	var edited_palette := codec.replace_palette_entry(palette, 1, Color8(12, 34, 56, 255), true)
	_check(
		edited_palette.ok
		and edited_palette.schema == ContentCoreVersionScript.DAT_PAL_PALETTE_SCHEMA
		and edited_palette.changed
		and edited_palette.bgr == PackedByteArray([56, 34, 12])
		and palette[3] == 0
		and edited_palette.pal_data[3] == 56
		and edited_palette.pal_data[4] == 34
		and edited_palette.pal_data[5] == 12,
		"PAL entry replacement writes a detached BGR mutation without changing its source"
	)
	var edited_decode := codec.decode_image(dat, edited_palette.pal_data) if edited_palette.ok else {"ok": false}
	_check(
		edited_decode.ok and edited_decode.image.get_pixel(0, 31) == Color8(12, 34, 56, 255),
		"edited PAL entry changes only pixels using that palette index"
	)
	_check(not codec.replace_palette_entry(palette, 0, Color.WHITE, true).ok, "reserved transparent palette entry zero cannot be edited")
	_check(not codec.replace_palette_entry(palette, 256, Color.WHITE).ok, "PAL entry replacement rejects an out-of-range index")
	_check(not codec.replace_palette_entry(palette, 1, Color(1, 1, 1, 0.5)).ok, "PAL entry replacement rejects non-opaque colors")
	_check(not codec.inspect_palette(PackedByteArray([1, 2]), palette).ok, "palette inspection retains DAT size validation")
	_check(not codec.inspect(PackedByteArray([1, 2]), palette).ok, "unsupported DAT size is rejected")
	_check(not codec.inspect(dat, PackedByteArray([1, 2])).ok, "invalid PAL size is rejected")

	var source := Image.create(640, 32, false, Image.FORMAT_RGBA8)
	source.set_pixel(0, 0, Color(1, 0, 0, 1))
	source.set_pixel(1, 0, Color(0, 1, 0, 1))
	var encoded := codec.encode_image(source)
	_check(encoded.ok and encoded.transparent_index_zero, "640x32 image encodes with index-zero alpha")
	_check(
		encoded.ok
		and encoded.diagnostics_schema == ContentCoreVersionScript.DAT_PAL_DIAGNOSTICS_SCHEMA
		and int(encoded.diagnostics.source_color_count) == 2
		and int(encoded.diagnostics.palette_color_count) == 2
		and int(encoded.diagnostics.opaque_pixel_count) == 2
		and int(encoded.diagnostics.transparent_pixel_count) == (640 * 32) - 2
		and int(encoded.diagnostics.changed_pixel_count) == 0
		and float(encoded.diagnostics.mean_absolute_rgb_error) == 0.0,
		"exact DAT/PAL encoding reports a lossless quantization baseline"
	)
	_check(encoded.ok and encoded.dat_data[31 * 640] != 0, "DAT encoder flips scanlines bottom-up")
	var round_trip := codec.decode_image(encoded.dat_data, encoded.pal_data) if encoded.ok else {"ok": false}
	_check(round_trip.ok and round_trip.image.get_pixel(0, 0).is_equal_approx(Color(1, 0, 0, 1)), "DAT/PAL opaque pixel round trip")
	_check(round_trip.ok and round_trip.image.get_pixel(2, 0).a == 0.0, "DAT/PAL transparent pixel round trip")
	var red_index := int(encoded.dat_data[31 * 640]) if encoded.ok else 0
	_check(encoded.ok and encoded.pal_data[red_index * 3 + 2] == 255, "DAT/PAL encoder writes BGR palette bytes")

	var partial_alpha := source.duplicate()
	partial_alpha.set_pixel(2, 0, Color(1, 1, 1, 0.5))
	_check(not codec.encode_image(partial_alpha).ok, "DAT/PAL encoder rejects non-binary strip alpha")
	_check(not codec.encode_image(Image.create(2, 2, false, Image.FORMAT_RGB8)).ok, "DAT/PAL encoder rejects unsupported dimensions")

	var many_colors := Image.create(640, 32, false, Image.FORMAT_RGBA8)
	for index in range(300):
		many_colors.set_pixel(index, 0, Color8(index & 0xFF, (index * 17) & 0xFF, (index * 37) & 0xFF, 255))
	var quantized := codec.encode_image(many_colors)
	_check(quantized.ok and quantized.quantized and quantized.palette_colors <= 255, "DAT/PAL encoder quantizes to the strip palette limit")
	_check(
		quantized.ok
		and bool(quantized.diagnostics.quantized)
		and int(quantized.diagnostics.changed_color_count) > 0
		and int(quantized.diagnostics.changed_pixel_count) > 0
		and float(quantized.diagnostics.mean_absolute_rgb_error) > 0.0
		and int(quantized.diagnostics.maximum_channel_error) > 0,
		"lossy DAT/PAL encoding reports changed colors, pixels, and RGB error"
	)
	_check(quantized.ok and codec.decode_image(quantized.dat_data, quantized.pal_data).ok, "quantized DAT/PAL output decodes")
	var repeated_quantization := codec.encode_image(many_colors)
	_check(
		quantized.ok
		and repeated_quantization.ok
		and quantized.dat_data == repeated_quantization.dat_data
		and quantized.pal_data == repeated_quantization.pal_data,
		"DAT/PAL quantization is deterministic"
	)
	_check(
		quantized.ok and repeated_quantization.ok and quantized.diagnostics == repeated_quantization.diagnostics,
		"DAT/PAL quantization diagnostics are deterministic"
	)
	var empty_strip := codec.encode_image(Image.create(640, 32, false, Image.FORMAT_RGBA8))
	_check(
		empty_strip.ok
		and int(empty_strip.diagnostics.opaque_pixel_count) == 0
		and int(empty_strip.diagnostics.transparent_pixel_count) == 640 * 32
		and int(empty_strip.diagnostics.palette_color_count) == 0
		and float(empty_strip.diagnostics.root_mean_square_rgb_error) == 0.0,
		"fully transparent strip diagnostics avoid empty-palette division errors"
	)
	await get_tree().process_frame
	get_tree().quit(1 if _failed else 0)
