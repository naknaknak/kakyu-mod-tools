extends SceneTree

const ArcReaderScript := preload("res://content_core/arc_reader.gd")
const DatPalCodecScript := preload("res://content_core/dat_pal_codec.gd")
const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")


func _initialize() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.is_empty():
		push_error("Usage: godot --headless --path . --script res://tools/content_suite/cli/validate_dat_pal_corpus.gd -- <data.arc>")
		quit(2)
		return
	var reader := ArcReaderScript.new()
	if not reader.open(arguments[0].replace("\\", "/")):
		push_error("DAT_PAL_CORPUS_FAIL reader: %s" % reader.last_error)
		quit(2)
		return
	var codec := DatPalCodecScript.new()
	var source_sha := reader.get_archive_fingerprint()
	var decoded_count := 0
	var failures := 0
	var dimensions: Dictionary = {}
	for entry in reader.get_entries():
		if str(entry.name).get_extension().to_lower() != "dat":
			continue
		var palette_name := "%s.PAL" % str(entry.name).get_basename()
		var palette_entry := reader.get_entry(palette_name)
		if palette_entry.is_empty():
			failures += 1
			push_error("DAT_PAL_CORPUS_FAIL missing %s" % palette_name)
			continue
		var dat_data := reader.read_entry(str(entry.name))
		var pal_data := reader.read_entry(palette_name)
		var decoded := codec.decode_image(dat_data, pal_data)
		if not decoded.ok:
			failures += 1
			push_error("DAT_PAL_CORPUS_FAIL %s: %s" % [entry.name, decoded.error])
			continue
		if (
			str(decoded.get("diagnostics_schema", "")) != ContentCoreVersionScript.DAT_PAL_DIAGNOSTICS_SCHEMA
			or int(decoded.get("used_palette_entries", 0)) < 1
			or int(decoded.get("used_palette_entries", 0)) > 256
			or int(decoded.get("used_palette_entries", 0)) + int(decoded.get("unused_palette_entries", -1)) != 256
			or int(decoded.get("opaque_pixel_count", -1)) + int(decoded.get("transparent_pixel_count", -1)) != int(entry.size)
		):
			failures += 1
			push_error("DAT_PAL_CORPUS_FAIL %s: invalid palette diagnostics" % entry.name)
			continue
		var palette_inspection := codec.inspect_palette(dat_data, pal_data)
		if (
			not palette_inspection.ok
			or str(palette_inspection.get("schema", "")) != ContentCoreVersionScript.DAT_PAL_PALETTE_SCHEMA
			or palette_inspection.entries.size() != 256
			or int(palette_inspection.get("used_palette_entries", -1)) != int(decoded.used_palette_entries)
		):
			failures += 1
			push_error("DAT_PAL_CORPUS_FAIL %s: invalid palette inventory" % entry.name)
			continue
		decoded_count += 1
		var key := "%dx%d%s" % [
			decoded.width,
			decoded.height,
			"/alpha0" if decoded.transparent_index_zero else "",
		]
		dimensions[key] = int(dimensions.get(key, 0)) + 1
	for representative_name in ["CHARA.DAT", "MACHIN_3.DAT"]:
		var round_trip := _validate_round_trip(reader, codec, representative_name)
		if not round_trip.ok:
			failures += 1
			push_error("DAT_PAL_CORPUS_FAIL round trip %s: %s" % [representative_name, round_trip.error])
		else:
			print(
				"DAT_PAL_CORPUS_ENCODE entry=%s colors=%d palette=%d pixels_equal=true" %
				[representative_name, round_trip.source_colors, round_trip.palette_colors]
			)
	if reader.get_archive_fingerprint() != source_sha:
		failures += 1
		push_error("DAT_PAL_CORPUS_FAIL source archive hash changed")
	print(
		"DAT_PAL_CORPUS_SUMMARY pairs=%d failures=%d formats=%s" %
		[decoded_count, failures, JSON.stringify(dimensions)]
	)
	reader.close()
	quit(1 if failures > 0 else 0)


func _validate_round_trip(reader: KakyuArcReader, codec: KakyuDatPalCodec, dat_name: String) -> Dictionary:
	var dat_entry: Dictionary = reader.get_entry(dat_name)
	var pal_name := "%s.PAL" % dat_name.get_basename()
	var pal_entry: Dictionary = reader.get_entry(pal_name)
	if dat_entry.is_empty() or pal_entry.is_empty():
		return {"ok": false, "error": "representative pair is missing"}
	var source: Dictionary = codec.decode_image(reader.read_entry(dat_name), reader.read_entry(pal_name))
	if not source.ok:
		return source
	var encoded: Dictionary = codec.encode_image(source.image)
	if not encoded.ok:
		return encoded
	if encoded.dat_data.size() != int(dat_entry.size) or encoded.pal_data.size() != int(pal_entry.size):
		return {"ok": false, "error": "encoded pair sizes changed"}
	var decoded: Dictionary = codec.decode_image(encoded.dat_data, encoded.pal_data)
	if not decoded.ok or not _images_visibly_equal(source.image, decoded.image, bool(source.transparent_index_zero)):
		return {"ok": false, "error": "pixel round trip differs"}
	if (
		str(encoded.get("diagnostics_schema", "")) != ContentCoreVersionScript.DAT_PAL_DIAGNOSTICS_SCHEMA
		or int(encoded.diagnostics.changed_pixel_count) != 0
		or float(encoded.diagnostics.mean_absolute_rgb_error) != 0.0
	):
		return {"ok": false, "error": "lossless representative diagnostics differ"}
	return {
		"ok": true,
		"source_colors": encoded.source_colors,
		"palette_colors": encoded.palette_colors,
	}


func _images_visibly_equal(left: Image, right: Image, transparent: bool) -> bool:
	if left.get_width() != right.get_width() or left.get_height() != right.get_height():
		return false
	var left_data := left.get_data()
	var right_data := right.get_data()
	if not transparent:
		return left_data == right_data
	for offset in range(0, left_data.size(), 4):
		if left_data[offset + 3] != right_data[offset + 3]:
			return false
		if left_data[offset + 3] == 255 and left_data.slice(offset, offset + 3) != right_data.slice(offset, offset + 3):
			return false
	return true
