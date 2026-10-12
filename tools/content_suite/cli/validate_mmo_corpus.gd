extends SceneTree

const ArcReaderScript := preload("res://content_core/arc_reader.gd")
const MmoCodecScript := preload("res://content_core/mmo_codec.gd")

const EXPECTED_ENTRY_COUNT := 1727
const EXPECTED_DIMENSION_PAIR_COUNT := 302
const EXPECTED_STANDARD_COUNT := 1718
const EXPECTED_FLAGGED_NAMES := ["CALFACE.MMO"]
const EXPECTED_TRAILER_NAMES := [
	"DIALOG00.MMO", "DIALOG01.MMO", "DIALOG02.MMO", "DIALOG03.MMO", "DIALOG04.MMO",
	"FRAME.MMO", "PARTS.MMO", "VOL.MMO",
]


func _initialize() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.is_empty():
		push_error("Usage: godot --headless --path . --script res://tools/content_suite/cli/validate_mmo_corpus.gd -- <mmo.arc>")
		quit(2)
		return
	var archive_path := arguments[0].replace("\\", "/")
	var reader := ArcReaderScript.new()
	if not reader.open(archive_path):
		push_error("MMO_CORPUS_FAIL reader: %s" % reader.last_error)
		quit(2)
		return
	var source_sha256 := reader.get_archive_fingerprint()
	var codec := MmoCodecScript.new()
	var inspected := 0
	var failures := 0
	var profile_counts := {
		codec.PROFILE_STANDARD: 0,
		codec.PROFILE_FLAGGED_SECONDARY: 0,
		codec.PROFILE_NONZERO_TRAILER: 0,
		codec.PROFILE_UNCLASSIFIED: 0,
	}
	var dimension_pairs := {}
	var flagged_names: Array[String] = []
	var trailer_names: Array[String] = []
	for entry in reader.get_entries():
		if str(entry.name).get_extension().to_lower() != "mmo":
			continue
		var header_size := mini(0x28, int(entry.size))
		var header := reader.read_entry_range(int(entry.index), 0, header_size)
		var metadata := codec.inspect(header)
		if not metadata.ok:
			failures += 1
			push_error("MMO_CORPUS_FAIL %s: %s" % [entry.name, metadata.error])
		else:
			inspected += 1
			var profile := str(metadata.header_profile)
			profile_counts[profile] = int(profile_counts.get(profile, 0)) + 1
			var dimension_key := "%dx%d" % [int(metadata.width), int(metadata.height)]
			dimension_pairs[dimension_key] = int(dimension_pairs.get(dimension_key, 0)) + 1
			if profile == codec.PROFILE_FLAGGED_SECONDARY:
				flagged_names.append(str(entry.name))
			elif profile == codec.PROFILE_NONZERO_TRAILER:
				trailer_names.append(str(entry.name))
			if not bool(metadata.reserved_zero):
				failures += 1
				push_error("MMO_CORPUS_FAIL reserved header fields: %s" % entry.name)

	flagged_names.sort()
	trailer_names.sort()
	if (
		inspected != EXPECTED_ENTRY_COUNT
		or dimension_pairs.size() != EXPECTED_DIMENSION_PAIR_COUNT
		or int(profile_counts[codec.PROFILE_STANDARD]) != EXPECTED_STANDARD_COUNT
		or int(profile_counts[codec.PROFILE_FLAGGED_SECONDARY]) != EXPECTED_FLAGGED_NAMES.size()
		or int(profile_counts[codec.PROFILE_NONZERO_TRAILER]) != EXPECTED_TRAILER_NAMES.size()
		or int(profile_counts[codec.PROFILE_UNCLASSIFIED]) != 0
		or flagged_names != EXPECTED_FLAGGED_NAMES
		or trailer_names != EXPECTED_TRAILER_NAMES
	):
		failures += 1
		push_error("MMO_CORPUS_FAIL header compatibility matrix changed")
	else:
		print(
			"MMO_CORPUS_HEADERS entries=%d dimensions=%d standard=%d flagged=%d trailer=%d unclassified=0" % [
				inspected,
				dimension_pairs.size(),
				int(profile_counts[codec.PROFILE_STANDARD]),
				flagged_names.size(),
				trailer_names.size(),
			]
		)

	var representative_data := reader.read_entry("01CA_1.MMO")
	var representative := codec.decode_image(representative_data)
	if not representative.ok or representative.width != 640 or representative.height != 400:
		failures += 1
		push_error("MMO_CORPUS_FAIL representative strict decode")
	else:
		print("MMO_CORPUS_DECODE 01CA_1.MMO width=640 height=400 padded=0")
		var encoded := codec.encode_image(representative.image, representative_data.slice(0, codec.HEADER_SIZE))
		var round_trip := codec.decode_image(encoded.data) if encoded.ok else {"ok": false}
		if (
			not encoded.ok
			or encoded.data.slice(0, codec.HEADER_SIZE) != representative_data.slice(0, codec.HEADER_SIZE)
			or not round_trip.ok
			or round_trip.image.get_data() != representative.image.get_data()
		):
			failures += 1
			push_error("MMO_CORPUS_FAIL representative encode/decode round trip")
		else:
			print(
				"MMO_CORPUS_ENCODE 01CA_1.MMO source=%d encoded=%d header_preserved=true pixels_equal=true" %
				[representative_data.size(), encoded.data.size()]
			)
	var calface_data := reader.read_entry("CALFACE.MMO")
	var calface_strict := codec.decode_image(calface_data)
	var calface_preview := codec.decode_image(calface_data, true)
	if calface_strict.ok or not calface_preview.ok or int(calface_preview.padded_bytes) != 216:
		failures += 1
		push_error("MMO_CORPUS_FAIL CALFACE.MMO strict/padded boundary")
	else:
		print(
			"MMO_CORPUS_DECODE CALFACE.MMO width=%d height=%d padded=%d" %
			[calface_preview.width, calface_preview.height, calface_preview.padded_bytes]
		)
		var calface_encoded := codec.encode_image(
			calface_preview.image,
			calface_data.slice(0, codec.HEADER_SIZE)
		)
		if (
			not calface_encoded.ok
			or str(calface_encoded.header_profile) != codec.PROFILE_FLAGGED_SECONDARY
			or str(calface_encoded.compatibility) != "remake_only"
			or calface_encoded.data.slice(0, codec.HEADER_SIZE) != calface_data.slice(0, codec.HEADER_SIZE)
		):
			failures += 1
			push_error("MMO_CORPUS_FAIL CALFACE.MMO special-header authoring boundary")
		else:
			print("MMO_CORPUS_HEADER CALFACE.MMO profile=flagged_secondary_dimensions compatibility=remake_only header_preserved=true")
	if reader.get_archive_fingerprint() != source_sha256:
		failures += 1
		push_error("MMO_CORPUS_FAIL source archive changed during validation")
	print("MMO_CORPUS_SUMMARY entries=%d failures=%d" % [inspected, failures])
	reader.close()
	quit(1 if failures > 0 else 0)
