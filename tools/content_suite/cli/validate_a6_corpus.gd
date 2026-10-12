extends SceneTree

const ArcReaderScript := preload("res://content_core/arc_reader.gd")
const A6LayoutScript := preload("res://content_core/a6_layout.gd")

const EXPECTED_COUNTS := {
	"ALBUM.A6": 19,
	"GIRLS.A6": 15,
	"LOG.A6": 3,
	"MENU1.A6": 1,
	"MENU3.A6": 3,
	"MENU3_2.A6": 3,
	"MENU5.A6": 5,
	"MENU6.A6": 6,
	"MUSIC.A6": 20,
	"SLOT.A6": 4,
	"SMP1.A6": 44,
	"SMP2.A6": 30,
}
const EXPECTED_DUPLICATE_ID_COUNT := 9
const EXPECTED_OVERLAP_PAIR_COUNT := 21
const EXPECTED_PARTIALLY_OCCLUDED_COUNT := 19
const EXPECTED_UNREACHABLE_RECORD_COUNT := 0


func _initialize() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.is_empty():
		push_error("Usage: godot --headless --path . --script res://tools/content_suite/cli/validate_a6_corpus.gd -- <data.arc>")
		quit(2)
		return
	var reader := ArcReaderScript.new()
	if not reader.open(arguments[0].replace("\\", "/")):
		push_error("A6_CORPUS_FAIL reader: %s" % reader.last_error)
		quit(2)
		return
	var codec := A6LayoutScript.new()
	var source_sha := reader.get_archive_fingerprint()
	var inspected := 0
	var failures := 0
	var total_records := 0
	var duplicate_ids := 0
	var overlap_pairs := 0
	var partially_occluded := 0
	var unreachable_records := 0
	var byte_identical_rebuilds := 0
	var counts: Dictionary = {}
	for entry in reader.get_entries():
		if str(entry.name).get_extension().to_lower() != "a6":
			continue
		var data := reader.read_entry(str(entry.name))
		var result := codec.inspect(data)
		if not result.ok:
			failures += 1
			push_error("A6_CORPUS_FAIL %s: %s" % [entry.name, result.error])
			continue
		if result.schema != "kakyu_ai5_a6_input_regions/v4":
			failures += 1
			push_error("A6_CORPUS_FAIL %s: unexpected schema %s" % [entry.name, result.schema])
			continue
		if int(result.invalid_rectangle_count) != 0:
			failures += 1
			push_error("A6_CORPUS_FAIL %s: %d inverted rectangle(s)" % [entry.name, int(result.invalid_rectangle_count)])
			continue
		var encoded := codec.encode_records(result.records)
		if (
			not encoded.get("ok", false)
			or str(encoded.get("compatibility", "")) != "original_engine_compatible"
			or encoded.get("data", PackedByteArray()) != data
		):
			failures += 1
			push_error("A6_CORPUS_FAIL %s: no-op writer rebuild is not byte-identical" % entry.name)
			continue
		byte_identical_rebuilds += 1
		if not result.records.is_empty():
			var first: Dictionary = result.records[0]
			var lookup := codec.rectangle_for_id(data, int(first.id))
			var first_edge_hit := codec.hit_test(data, int(first.left), int(first.top))
			var last_edge_hit := codec.hit_test(data, int(first.right), int(first.bottom))
			if (
				not lookup.ok
				or not lookup.found
				or int(lookup.record_index) != 0
				or not first_edge_hit.ok
				or not first_edge_hit.found
				or int(first_edge_hit.record_id) != int(first.id)
				or not last_edge_hit.ok
				or not last_edge_hit.found
				or int(last_edge_hit.record_id) != int(first.id)
			):
				failures += 1
				push_error("A6_CORPUS_FAIL %s: native first-ID lookup or inclusive corner hit changed" % entry.name)
				continue
		inspected += 1
		total_records += int(result.record_count)
		duplicate_ids += int(result.duplicate_id_count)
		overlap_pairs += int(result.overlap_pair_count)
		partially_occluded += int(result.partially_occluded_count)
		unreachable_records += int(result.unreachable_record_count)
		counts[str(entry.name)] = int(result.record_count)
	if counts != EXPECTED_COUNTS:
		failures += 1
		push_error("A6_CORPUS_FAIL entry counts changed: %s" % JSON.stringify(counts))
	if duplicate_ids != EXPECTED_DUPLICATE_ID_COUNT:
		failures += 1
		push_error("A6_CORPUS_FAIL duplicate-ID count changed: %d" % duplicate_ids)
	if (
		overlap_pairs != EXPECTED_OVERLAP_PAIR_COUNT
		or partially_occluded != EXPECTED_PARTIALLY_OCCLUDED_COUNT
		or unreachable_records != EXPECTED_UNREACHABLE_RECORD_COUNT
	):
		failures += 1
		push_error("A6_CORPUS_FAIL first-match occlusion totals changed: overlap=%d partial=%d unreachable=%d" % [
			overlap_pairs, partially_occluded, unreachable_records,
		])
	if reader.get_archive_fingerprint() != source_sha:
		failures += 1
		push_error("A6_CORPUS_FAIL source archive hash changed")
	print(
		"A6_CORPUS_SUMMARY schema=kakyu_ai5_a6_input_regions/v4 entries=%d records=%d duplicate_ids=%d overlap_pairs=%d partial=%d unreachable=%d invalid_rectangles=0 byte_identical_rebuilds=%d failures=%d counts=%s" %
		[inspected, total_records, duplicate_ids, overlap_pairs, partially_occluded, unreachable_records, byte_identical_rebuilds, failures, JSON.stringify(counts)]
	)
	reader.close()
	quit(1 if failures > 0 else 0)
