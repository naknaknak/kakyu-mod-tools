extends SceneTree

const ArcReaderScript := preload("res://content_core/arc_reader.gd")
const ArcWriterScript := preload("res://content_core/arc_writer.gd")
const DatPalCodecScript := preload("res://content_core/dat_pal_codec.gd")
const ContractValues := preload("res://content_core/contract_values.gd")

const TILE_SIZE := 16
const HALF_TILE := 8
const OUTER_COLOR := Color(1, 0, 1)
const INNER_COLOR := Color(0, 1, 0)


func _initialize() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() != 3:
		push_error(
			"Usage: godot --headless --path . --script " +
			"res://tools/content_suite/cli/prepare_dat_pal_smoke_copy.gd -- " +
			"<source-data.arc> <entry-stem> <new-data.arc>"
		)
		quit(2)
		return
	var source_path := arguments[0]
	var entry_stem := arguments[1]
	var output_path := arguments[2]
	if (
		entry_stem.is_empty()
		or entry_stem.contains("/")
		or entry_stem.contains("\\")
		or entry_stem.contains(".")
	):
		push_error("DAT_PAL_SMOKE_PREPARE_FAIL unsafe entry stem")
		quit(2)
		return

	var reader := ArcReaderScript.new()
	if not reader.open(source_path):
		push_error("DAT_PAL_SMOKE_PREPARE_FAIL reader: %s" % reader.last_error)
		quit(1)
		return
	var source_sha := reader.get_archive_fingerprint()
	var dat_name := "%s.DAT" % entry_stem
	var pal_name := "%s.PAL" % entry_stem
	var dat_entry: Dictionary = reader.get_entry(dat_name)
	var pal_entry: Dictionary = reader.get_entry(pal_name)
	if dat_entry.is_empty() or pal_entry.is_empty():
		reader.close()
		push_error("DAT_PAL_SMOKE_PREPARE_FAIL missing pair: %s/.PAL" % dat_name)
		quit(1)
		return

	var source_dat := reader.read_entry(dat_name)
	var source_pal := reader.read_entry(pal_name)
	var source_dat_sha := ContractValues.sha256(source_dat)
	var source_pal_sha := ContractValues.sha256(source_pal)
	print("DAT_PAL_SMOKE_PREPARE_STAGE read stem=%s" % entry_stem)
	var codec := DatPalCodecScript.new()
	var decoded := codec.decode_image(source_dat, source_pal)
	if not decoded.ok:
		reader.close()
		push_error("DAT_PAL_SMOKE_PREPARE_FAIL decode: %s" % decoded.error)
		quit(1)
		return
	var image: Image = decoded.image
	if image.get_width() % TILE_SIZE != 0 or image.get_height() % TILE_SIZE != 0:
		reader.close()
		push_error("DAT_PAL_SMOKE_PREPARE_FAIL image dimensions are not tile aligned")
		quit(1)
		return
	print("DAT_PAL_SMOKE_PREPARE_STAGE decoded dimensions=%dx%d" % [image.get_width(), image.get_height()])
	_apply_marker(image)
	print("DAT_PAL_SMOKE_PREPARE_STAGE marker_applied")
	var encoded := codec.encode_image(image)
	print("DAT_PAL_SMOKE_PREPARE_STAGE encoded")
	var verified := codec.decode_image(encoded.dat_data, encoded.pal_data) if encoded.ok else {"ok": false}
	if not encoded.ok or not verified.ok or not _marker_is_exact(verified.image):
		reader.close()
		push_error("DAT_PAL_SMOKE_PREPARE_FAIL encode verification")
		quit(1)
		return
	reader.close()

	var replacements := {
		dat_name: encoded.dat_data,
		pal_name: encoded.pal_data,
	}
	print("DAT_PAL_SMOKE_PREPARE_STAGE writing_archive")
	var result := ArcWriterScript.new().write_repacked_copy(source_path, output_path, replacements)
	if not result.ok:
		push_error("DAT_PAL_SMOKE_PREPARE_FAIL writer: %s" % result.error)
		quit(1)
		return
	print("DAT_PAL_SMOKE_PREPARE_STAGE archive_written")
	var rebuilt := ArcReaderScript.new()
	if not rebuilt.open(output_path):
		push_error("DAT_PAL_SMOKE_PREPARE_FAIL output reopen: %s" % rebuilt.last_error)
		quit(1)
		return
	var rebuilt_dat := rebuilt.read_entry(dat_name)
	var rebuilt_pal := rebuilt.read_entry(pal_name)
	var rebuilt_image := codec.decode_image(rebuilt_dat, rebuilt_pal)
	rebuilt.close()
	if (
		not rebuilt_image.ok
		or not _marker_is_exact(rebuilt_image.image)
		or rebuilt_dat != encoded.dat_data
		or rebuilt_pal != encoded.pal_data
	):
		push_error("DAT_PAL_SMOKE_PREPARE_FAIL output replacement verification")
		quit(1)
		return
	if FileAccess.get_sha256(source_path) != source_sha:
		push_error("DAT_PAL_SMOKE_PREPARE_FAIL source archive hash changed")
		quit(1)
		return
	print(
		(
			"DAT_PAL_SMOKE_PREPARE_PASS stem=%s dat_bytes=%d pal_bytes=%d colors=%d "
			+ "source_dat_sha256=%s source_pal_sha256=%s replacement_dat_sha256=%s "
			+ "replacement_pal_sha256=%s output_sha256=%s"
		) % [
			entry_stem,
			encoded.dat_data.size(),
			encoded.pal_data.size(),
			encoded.palette_colors,
			source_dat_sha,
			source_pal_sha,
			ContractValues.sha256(encoded.dat_data),
			ContractValues.sha256(encoded.pal_data),
			result.sha256,
		]
	)
	quit(0)


func _apply_marker(image: Image) -> void:
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var tile_x := x % TILE_SIZE
			var tile_y := y % TILE_SIZE
			image.set_pixel(x, y, OUTER_COLOR if (tile_x < HALF_TILE) == (tile_y < HALF_TILE) else INNER_COLOR)


func _marker_is_exact(image: Image) -> bool:
	return (
		image.get_pixel(0, 0).is_equal_approx(OUTER_COLOR)
		and image.get_pixel(HALF_TILE, 0).is_equal_approx(INNER_COLOR)
		and image.get_pixel(0, HALF_TILE).is_equal_approx(INNER_COLOR)
		and image.get_pixel(HALF_TILE, HALF_TILE).is_equal_approx(OUTER_COLOR)
		and image.get_pixel(image.get_width() - 1, image.get_height() - 1).is_equal_approx(OUTER_COLOR)
	)
