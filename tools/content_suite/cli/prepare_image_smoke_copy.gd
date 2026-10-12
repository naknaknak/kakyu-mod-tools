extends SceneTree

const ArcReaderScript := preload("res://content_core/arc_reader.gd")
const ArcWriterScript := preload("res://content_core/arc_writer.gd")
const MmoCodecScript := preload("res://content_core/mmo_codec.gd")

const MARKER_OFFSET := 8
const MARKER_SIZE := 80
const INNER_OFFSET := 20
const INNER_SIZE := 40
const OUTER_COLOR := Color(1, 0, 1)
const INNER_COLOR := Color(0, 1, 0)


func _initialize() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() != 3:
		push_error(
			"Usage: godot --headless --path . --script " +
			"res://tools/content_suite/cli/prepare_image_smoke_copy.gd -- " +
			"<source-mmo.arc> <entry-prefix> <new-mmo.arc>"
		)
		quit(2)
		return
	var source_path := arguments[0]
	var entry_prefix := arguments[1]
	var output_path := arguments[2]
	if entry_prefix.is_empty() or entry_prefix.contains("/") or entry_prefix.contains("\\"):
		push_error("IMAGE_SMOKE_PREPARE_FAIL unsafe entry prefix")
		quit(2)
		return

	var reader := ArcReaderScript.new()
	if not reader.open(source_path):
		push_error("IMAGE_SMOKE_PREPARE_FAIL reader: %s" % reader.last_error)
		quit(1)
		return
	var source_sha := reader.get_archive_fingerprint()
	var targets: Array[Dictionary] = []
	for entry in reader.get_entries():
		var entry_name := str(entry.name)
		if entry_name.get_extension().to_lower() == "mmo" and entry_name.begins_with(entry_prefix):
			targets.append(entry)
	if targets.is_empty():
		reader.close()
		push_error("IMAGE_SMOKE_PREPARE_FAIL no MMO entries match prefix: %s" % entry_prefix)
		quit(1)
		return

	var codec := MmoCodecScript.new()
	var replacements: Dictionary = {}
	var source_bytes := 0
	var replacement_bytes := 0
	for target in targets:
		var entry_name := str(target.name)
		var source_data := reader.read_entry(entry_name)
		var decoded := codec.decode_image(source_data)
		if not decoded.ok:
			reader.close()
			push_error("IMAGE_SMOKE_PREPARE_FAIL decode %s: %s" % [entry_name, decoded.error])
			quit(1)
			return
		var image: Image = decoded.image
		if image.get_width() < MARKER_OFFSET + MARKER_SIZE or image.get_height() < MARKER_OFFSET + MARKER_SIZE:
			reader.close()
			push_error("IMAGE_SMOKE_PREPARE_FAIL image is too small for marker: %s" % entry_name)
			quit(1)
			return
		_apply_marker(image)
		var encoded := codec.encode_image(image, source_data.slice(0, codec.HEADER_SIZE))
		var verified := codec.decode_image(encoded.data) if encoded.ok else {"ok": false}
		if (
			not encoded.ok
			or not verified.ok
			or not _marker_is_exact(verified.image)
			or encoded.data.slice(0, codec.HEADER_SIZE) != source_data.slice(0, codec.HEADER_SIZE)
		):
			reader.close()
			push_error("IMAGE_SMOKE_PREPARE_FAIL encode verification: %s" % entry_name)
			quit(1)
			return
		replacements[entry_name] = encoded.data
		source_bytes += source_data.size()
		replacement_bytes += encoded.data.size()
	reader.close()

	var result := ArcWriterScript.new().write_repacked_copy(source_path, output_path, replacements)
	if not result.ok:
		push_error("IMAGE_SMOKE_PREPARE_FAIL writer: %s" % result.error)
		quit(1)
		return
	var rebuilt := ArcReaderScript.new()
	if not rebuilt.open(output_path):
		push_error("IMAGE_SMOKE_PREPARE_FAIL output reopen: %s" % rebuilt.last_error)
		quit(1)
		return
	for target in targets:
		var entry_name := str(target.name)
		var verified := codec.decode_image(rebuilt.read_entry(entry_name))
		if not verified.ok or not _marker_is_exact(verified.image):
			rebuilt.close()
			push_error("IMAGE_SMOKE_PREPARE_FAIL output marker verification: %s" % entry_name)
			quit(1)
			return
	rebuilt.close()
	if FileAccess.get_sha256(source_path) != source_sha:
		push_error("IMAGE_SMOKE_PREPARE_FAIL source archive hash changed")
		quit(1)
		return
	print(
		"IMAGE_SMOKE_PREPARE_PASS prefix=%s entries=%d old_bytes=%d new_bytes=%d output_sha256=%s" %
		[entry_prefix, targets.size(), source_bytes, replacement_bytes, result.sha256]
	)
	quit(0)


func _apply_marker(image: Image) -> void:
	for y in range(MARKER_OFFSET, MARKER_OFFSET + MARKER_SIZE):
		for x in range(MARKER_OFFSET, MARKER_OFFSET + MARKER_SIZE):
			image.set_pixel(x, y, OUTER_COLOR)
	for y in range(MARKER_OFFSET + INNER_OFFSET, MARKER_OFFSET + INNER_OFFSET + INNER_SIZE):
		for x in range(MARKER_OFFSET + INNER_OFFSET, MARKER_OFFSET + INNER_OFFSET + INNER_SIZE):
			image.set_pixel(x, y, INNER_COLOR)


func _marker_is_exact(image: Image) -> bool:
	return (
		image.get_pixel(MARKER_OFFSET, MARKER_OFFSET).is_equal_approx(OUTER_COLOR)
		and image.get_pixel(MARKER_OFFSET + MARKER_SIZE - 1, MARKER_OFFSET + MARKER_SIZE - 1).is_equal_approx(OUTER_COLOR)
		and image.get_pixel(MARKER_OFFSET + INNER_OFFSET, MARKER_OFFSET + INNER_OFFSET).is_equal_approx(INNER_COLOR)
		and image.get_pixel(
			MARKER_OFFSET + INNER_OFFSET + INNER_SIZE - 1,
			MARKER_OFFSET + INNER_OFFSET + INNER_SIZE - 1
		).is_equal_approx(INNER_COLOR)
	)
