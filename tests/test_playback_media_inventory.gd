extends "res://tests/test_case.gd"

# WD-21 U1 C2a: the package's media inventory and script references - the
# classifier's one rule per kind, the producer's identity lookup and scan
# cross-check against synthetic archives, the manifest blocks, and the reader's
# fail-closed recompute.

const Exporter := preload("res://tools/content_suite/playback_package_export.gd")
const MediaIdentity := preload("res://tools/content_suite/playback_media_identity.gd")
const Classifier := preload("res://content_core/playback_media_classifier.gd")
const Inventory := preload("res://content_core/playback_package_inventory.gd")
const ArchiveIdentity := preload("res://content_core/original_archive_identity.gd")
const Package := preload("res://content_core/playback_package.gd")
const Integrity := preload("res://content_core/playback_package_integrity.gd")
const Version := preload("res://content_core/content_core_version.gd")
const SyntheticArc := preload("res://tests/synthetic_arc.gd")

const FIXTURE_CATALOG := {"catalog_id": "fixture-catalog", "catalog_revision": 7}
const REGION := {"id": "entry_0000", "index": 0, "at": 0, "end": 400}

var _root := ""


func _ready() -> void:
	_root = ProjectSettings.globalize_path("user://media-inventory-%s-%s" % [OS.get_process_id(), Time.get_ticks_usec()])
	DirAccess.make_dir_recursive_absolute(_root)
	_pinned_archive_table()
	_one_fixture_per_kind()
	_bgm_adjacency_and_selectors()
	_loader_strings()
	_native_record_dispatch_strings()
	_library_routines_are_regions()
	_script_references()
	_json_round_trip_does_not_change_the_rows()
	_identity_lookup_states()
	_identity_lookup_fails_closed()
	_scan_cross_check()
	_identity_accumulator_matches_collect()
	_blocks_round_trip()
	_synthetic_end_to_end()
	_serialize_fails_closed()
	_reader_fails_closed()
	_reader_tolerates_absences_and_missing_blocks()
	_remove_tree(_root)
	get_tree().quit(1 if _failed else 0)


# ---- fixtures ---------------------------------------------------------------

func _document(entry: String, records: Array, regions: Array = [REGION], code_size := 400) -> Dictionary:
	var identity := "a".repeat(64)
	return {"schema": Version.PLAYBACK_PACKAGE_SCHEMA, "entry": entry, "entry_sha256": identity,
		"code_size": code_size, "code_sha256": identity, "address_table": [0], "regions": regions,
		"provenance_records": [], "records": records}


func _library(entry: String, routines: Array) -> Dictionary:
	var identity := "a".repeat(64)
	return {"schema": Version.PLAYBACK_PACKAGE_SCHEMA, "entry": entry, "entry_sha256": identity,
		"kind": "library", "code_size": 400, "code_sha256": identity, "routines": routines}


func _marker(op: String, at: int, end: int, name: String) -> Dictionary:
	return {"op": op, "id": 13, "at": at, "end": end,
		"operands": [{"t": "resource_name", "kind": op, "name": name, "resource_kind": op}]}


func _effect(at: int, end: int, name: String) -> Dictionary:
	return {"op": "effect_request", "id": 13, "at": at, "end": end,
		"operands": [{"t": "effect_request", "resource_kind": "effect", "resource_archive": "se.arc", "name": name}]}


func _literal(value: int) -> Dictionary:
	return {"type": "literal", "value": value, "width": 8}


func _expression_record(ast: Dictionary) -> Dictionary:
	return {"tag": 2, "kind": "expression_record", "ast": ast}


func _string_record(index: int) -> Dictionary:
	return {"tag": 1, "kind": "string_record", "s": index}


func _banked(index: int, bank := 0) -> Dictionary:
	return {"type": "state_ref", "storage": "banked_i32", "bank": bank, "index": _literal(index)}


func _system_call(at: int, end: int, function: int, records: Array) -> Dictionary:
	return {"op": "system_call", "id": 13, "at": at, "end": end, "system_function": function,
		"operands": [{"t": "expression", "ast": _literal(function)}, {"t": "record_list", "records": records}]}


func _a6(at: int, string_index: int) -> Dictionary:
	return _system_call(at, at + 10, 8, [_expression_record(_literal(0)), _string_record(string_index), _expression_record(_banked(3))])


func _bgm_assign(at: int, end: int, ast: Dictionary, slot := 1) -> Dictionary:
	return {"op": "argument_slot_write_run", "id": 9, "at": at, "end": end,
		"operands": [{"t": "u16_index", "v": slot}, {"t": "expression_byte_pairs", "pairs": [{"ast": ast, "continuation": 0}]}]}


func _bgm_transfer(at: int, routine: int) -> Dictionary:
	return {"op": "script_transfer", "id": 29, "at": at, "end": at + 5,
		"operands": [{"t": "record_list", "records": [_expression_record(_literal(routine))]}]}


func _script_target(op: String, at: int, target: String) -> Dictionary:
	return {"op": op, "id": 15, "at": at, "end": at + 8, "script_target": target,
		"operands": [{"t": "record_list", "records": [_string_record(0)]}]}


func _dispatch(at: int, records: Array) -> Dictionary:
	return {"op": "native_record_dispatch", "id": 18, "at": at, "end": at + 12,
		"operands": [{"t": "record_list", "records": records}]}


func _inline(at: int, name: String) -> Dictionary:
	return {"op": "inline_script_execution", "id": 13, "at": at, "end": at + 10,
		"operands": [{"t": "resource_name", "kind": "mes_script", "name": name, "resource_kind": "mes_script"}]}


func _rows(document: Dictionary, strings: Array = []) -> Array:
	return Classifier.new().occurrences(document, strings)


func _row_list(rows: Array) -> Array:
	var simple: Array = []
	for row in rows:
		simple.append("%d:%s:%s" % [row.at, row.kind, row.name])
	return simple


# ---- the pinned table -------------------------------------------------------

func _pinned_archive_table() -> void:
	_check(ArchiveIdentity.ARCHIVE_SHA256.size() == 8, "the pinned table holds the six station archives and both Tina banks")
	for archive in ["mes.arc", "mmo.arc", "data.arc", "bgm.arc", "se.arc", "voice.arc", "tina1.arc", "tina2.arc"]:
		_check(ArchiveIdentity.expected(archive).length() == 64, "%s has a 64-hex pin" % archive)
	_check(ArchiveIdentity.expected("nothing.arc").is_empty(), "an unknown archive has no pin")
	_check(ArchiveIdentity.SIX_ARCHIVE_SHA256.size() == 6 and not ArchiveIdentity.SIX_ARCHIVE_SHA256.has("tina1.arc"), "the six-archive table stays six archives")
	for archive in ArchiveIdentity.SIX_ARCHIVE_SHA256:
		_check(ArchiveIdentity.SIX_ARCHIVE_SHA256[archive] == ArchiveIdentity.ARCHIVE_SHA256[archive], "%s keeps its long-standing pin" % archive)
	_check(ArchiveIdentity.MEDIA_ARCHIVES.size() == 7 and not "mes.arc" in ArchiveIdentity.MEDIA_ARCHIVES, "the media archives are the seven that are not mes.arc")
	var path := _root.path_join("pin.bin")
	var handle := FileAccess.open(path, FileAccess.WRITE)
	handle.store_string("pin")
	handle.close()
	var live := FileAccess.get_sha256(path)
	_check(ArchiveIdentity.verify_file(path, "x.arc", {"x.arc": live}).ok, "a file with its pinned hash verifies")
	_check(not ArchiveIdentity.verify_file(path, "x.arc", {"x.arc": "0".repeat(64)}).ok, "a different hash fails")
	_check(not ArchiveIdentity.verify_file(path, "y.arc", {"x.arc": live}).ok, "an archive without a pin fails")
	_check(not ArchiveIdentity.verify_file(_root.path_join("missing.bin"), "x.arc", {"x.arc": live}).ok, "an unreadable file fails")


# ---- the classifier ---------------------------------------------------------

func _one_fixture_per_kind() -> void:
	var strings := ["album.a6", "floor5.ccd"]
	var records := [
		_marker("mmo_resource_marker", 10, 20, "r.mmo"),
		_marker("ax_resource_marker", 30, 40, "b19.ax"),
		_marker("voice_marker", 50, 60, "h0001.ogg"),
		_effect(70, 80, "KSE0001.WAV"),
		_a6(90, 0),
		_bgm_assign(120, 126, _literal(1)),
		_bgm_transfer(126, 23),
		_system_call(150, 160, 8, [_expression_record(_literal(0)), _string_record(1), _expression_record(_banked(4))]),
	]
	var rows := _rows(_document("A.MES", records), strings)
	_check(
		_row_list(rows) == [
			"10:mmo:R.MMO", "30:ax:B19.AX", "50:voice:H0001.OGG", "70:se:KSE0001.WAV", "90:a6:ALBUM.A6",
			"120:bgm:IDOU.WAV", "150:unclassified:FLOOR5.CCD",
		],
		"one record of each kind classifies with its upper-case name and offset"
	)
	_check(str(rows[6].evidence) == "system_function_8_loader_string", "an unclassified loader string carries its evidence")
	_check(_rows(_document("A.MES", [_marker("mmo_resource_marker", 10, 20, "")])).is_empty(), "a marker without a name is no occurrence")
	var other_archive := _effect(70, 80, "KSE0001.WAV")
	other_archive.operands[0].resource_archive = "bgm.arc"
	_check(_rows(_document("A.MES", [other_archive])).is_empty(), "an effect request that does not name se.arc is no SE occurrence")
	_check(_rows(_document("A.MES", [{"op": "text", "id": 2, "at": 1, "end": 2, "operands": []}])).is_empty(), "other records are no occurrence")
	var unsorted := _rows(_document("A.MES", [_marker("ax_resource_marker", 30, 40, "b.ax"), _marker("mmo_resource_marker", 10, 20, "a.mmo")]))
	_check(_row_list(unsorted) == ["10:mmo:A.MMO", "30:ax:B.AX"], "records in any order give rows sorted by offset")


func _bgm_adjacency_and_selectors() -> void:
	var two_regions := [{"id": "bootstrap", "at": 0, "end": 130}, {"id": "entry_0000", "index": 0, "at": 130, "end": 400}]
	var cases := {
		"a literal selector then routine 23": [[_bgm_assign(120, 126, _literal(1)), _bgm_transfer(126, 23)], [REGION], ["120:bgm:IDOU.WAV"]],
		"a gap between the two records": [[_bgm_assign(120, 126, _literal(1)), _bgm_transfer(127, 23)], [REGION], []],
		"a record between the two": [[_bgm_assign(120, 126, _literal(1)), _marker("mmo_resource_marker", 126, 130, "q.mmo"), _bgm_transfer(130, 23)], [REGION], ["126:mmo:Q.MMO"]],
		"another routine": [[_bgm_assign(120, 126, _literal(1)), _bgm_transfer(126, 22)], [REGION], []],
		"another slot": [[_bgm_assign(120, 126, _literal(1), 2), _bgm_transfer(126, 23)], [REGION], []],
		"a pair that crosses a region boundary": [[_bgm_assign(126, 132, _literal(1)), _bgm_transfer(132, 23)], two_regions, []],
		"a pair inside the second region": [[_bgm_assign(140, 146, _literal(1)), _bgm_transfer(146, 23)], two_regions, ["140:bgm:IDOU.WAV"]],
		"a non-literal selector": [[_bgm_assign(120, 126, _banked(3)), _bgm_transfer(126, 23)], [REGION], ["120:unclassified:"]],
		"an unresolved selector": [[_bgm_assign(120, 126, {"unresolved": "boundary"}), _bgm_transfer(126, 23)], [REGION], ["120:unclassified:"]],
		"a selector the catalog does not map": [[_bgm_assign(120, 126, _literal(99)), _bgm_transfer(126, 23)], [REGION], ["120:unclassified:"]],
		"selector 133": [[_bgm_assign(120, 126, _literal(133)), _bgm_transfer(126, 23)], [REGION], ["120:bgm:KSE0069.WAV"]],
		"an absent-name table entry": [[_bgm_assign(120, 126, _literal(51)), _bgm_transfer(126, 23)], [REGION], ["120:bgm:BOALING.WAV"]],
		"no region covers the offsets": [[_bgm_assign(520, 526, _literal(1)), _bgm_transfer(526, 23)], [REGION], []],
	}
	for label in cases:
		var spec: Array = cases[label]
		var rows := _rows(_document("A.MES", spec[0], spec[1], 600))
		_check(_row_list(rows) == spec[2], "BGM %s" % label)
	var unclassified := _rows(_document("A.MES", [_bgm_assign(120, 126, _banked(3)), _bgm_transfer(126, 23)]))
	_check(unclassified.size() == 1 and unclassified[0].name == "" and unclassified[0].evidence == "bgm_selector_not_literal", "a non-literal selector is listed with its evidence and no name")
	var unmapped := _rows(_document("A.MES", [_bgm_assign(120, 126, _literal(99)), _bgm_transfer(126, 23)]))
	_check(unmapped.size() == 1 and unmapped[0].evidence == "bgm_selector_unmapped", "an unmapped selector is listed with its evidence")
	var out_of_order := _rows(_document("A.MES", [_bgm_transfer(126, 23), _bgm_assign(120, 126, _literal(1))]))
	_check(_row_list(out_of_order) == ["120:bgm:IDOU.WAV"], "adjacency is decided on the records sorted by offset")


func _loader_strings() -> void:
	var strings := ["album.a6", "floor5.ccd", "d15ss.gp8", "k_end0.mmo", "idou.wav", "floor1.eve", "x.mpc", "p.dat", "p.pal", "Msg", "", "zzz.mes", "other.a6"]
	var one := func(function: int, index: int) -> Array:
		return _rows(_document("A.MES", [_system_call(10, 20, function, [_expression_record(_literal(4)), _string_record(index)])]), strings)
	_check(_row_list(one.call(9, 2)) == ["10:unclassified:D15SS.GP8"], "a function-9 .gp8 string is an unclassified loader string")
	_check(one.call(8, 2).is_empty(), "a function-8 .gp8 string is not a loader string: .gp8 is a function-9 string")
	_check(_row_list(one.call(24, 3)) == ["10:unclassified:K_END0.MMO"], "a function-24 .mmo string is an unclassified loader string")
	_check(_row_list(one.call(5, 4)) == ["10:unclassified:IDOU.WAV"], "a function-5 .wav string is an unclassified loader string")
	for pair in [[8, 5], [8, 6], [8, 1]]:
		_check(one.call(pair[0], pair[1]).size() == 1, "a function-8 string %s is looked up" % strings[pair[1]])
	_check(one.call(8, 7).is_empty() and one.call(8, 8).is_empty(), "a .dat or .pal string on function 8 is not a loader string: they arrive through native_record_dispatch")
	_check(one.call(9, 7).is_empty() and one.call(24, 7).is_empty() and one.call(5, 8).is_empty(), "a .dat or .pal string on another function is not a loader string either")
	_check(one.call(8, 3).is_empty(), "an .mmo string on function 8 is not a loader string")
	_check(one.call(24, 1).is_empty(), "a .ccd string on function 24 is not a loader string")
	_check(one.call(24, 9).is_empty() and one.call(24, 10).is_empty() and one.call(27, 9).is_empty(), "strings without a loader extension, and other functions, are no occurrence")
	_check(one.call(8, 11).is_empty(), "a string with an unlisted extension is no occurrence")
	var wrong_shape := _system_call(10, 20, 8, [_expression_record(_literal(1)), _string_record(0), _expression_record(_banked(3))])
	var wrong_index := _system_call(10, 20, 8, [_expression_record(_literal(0)), _string_record(0), _expression_record(_banked(4))])
	var wrong_bank := _system_call(10, 20, 8, [_expression_record(_literal(0)), _string_record(0), _expression_record(_banked(3, 1))])
	var wrong_storage := _system_call(10, 20, 8, [_expression_record(_literal(0)), _string_record(0), _expression_record({"type": "state_ref", "storage": "banked_u8", "bank": 0, "index": _literal(3)})])
	var short := _system_call(10, 20, 8, [_expression_record(_literal(0)), _string_record(0)])
	var long := _system_call(10, 20, 8, [_expression_record(_literal(0)), _string_record(0), _expression_record(_banked(3)), _expression_record(_literal(0))])
	for label in ["literal 1", "index 4", "bank 1", "storage", "two records", "four records"]:
		var variant: Dictionary = {"literal 1": wrong_shape, "index 4": wrong_index, "bank 1": wrong_bank, "storage": wrong_storage, "two records": short, "four records": long}[label]
		var rows := _rows(_document("A.MES", [variant]), strings)
		_check(rows.size() == 1 and rows[0].kind == "unclassified" and rows[0].name == "ALBUM.A6", "an .a6 string with %s is unclassified, not an A6 reference" % label)
	var exact := _rows(_document("A.MES", [_a6(10, 0)]), strings)
	_check(exact.size() == 1 and exact[0].kind == "a6" and exact[0].name == "ALBUM.A6", "the exact album.a6 shape is an A6 reference")
	var on_nine := _system_call(10, 20, 9, [_expression_record(_literal(0)), _string_record(0), _expression_record(_banked(3))])
	_check(_rows(_document("A.MES", [on_nine]), strings).is_empty(), "the A6 shape on another function is nothing")
	var hex_only := _system_call(10, 20, 8, [_expression_record(_literal(0)), {"tag": 1, "kind": "string_record", "hex": "6162"}])
	_check(_rows(_document("A.MES", [hex_only]), strings).is_empty(), "an undecodable string carries no name")
	var out_of_range := _system_call(10, 20, 8, [_expression_record(_literal(0)), _string_record(99)])
	_check(_rows(_document("A.MES", [out_of_range]), strings).is_empty(), "a string index past the text document carries no name")


func _native_record_dispatch_strings() -> void:
	var strings := ["x01.dat", "face.pal", "kao01.mmo", "Msg", "notes.txt", "second.dat", "gone.gp8"]
	var literal := func(value: int) -> Dictionary:
		return _expression_record(_literal(value))
	var dat := _dispatch(10, [literal.call(6), literal.call(25), _string_record(0), literal.call(0)])
	var pal := _dispatch(30, [literal.call(6), literal.call(24), _string_record(1), literal.call(1)])
	var mmo := _dispatch(50, [literal.call(1), literal.call(12), _string_record(2)])
	var rows := _rows(_document("A.MES", [dat, pal, mmo]), strings)
	_check(
		_row_list(rows) == ["10:unclassified:X01.DAT", "30:unclassified:FACE.PAL", "50:unclassified:KAO01.MMO"],
		"the three observed native_record_dispatch shapes yield their .dat, .pal and .mmo string"
	)
	var evidence_ok := true
	for row in rows:
		evidence_ok = evidence_ok and row.evidence == "native_record_dispatch_string"
	_check(evidence_ok, "a native_record_dispatch string carries its evidence")
	var nothing := [
		_dispatch(10, [literal.call(6), literal.call(25), _string_record(3), literal.call(0)]),
		_dispatch(20, [literal.call(6), literal.call(25), _string_record(4), literal.call(0)]),
		_dispatch(30, [literal.call(6), literal.call(2)]),
		_dispatch(40, [literal.call(6), literal.call(25), _string_record(99)]),
		_dispatch(50, [literal.call(6), literal.call(25), {"tag": 1, "kind": "string_record", "hex": "6162"}]),
		_dispatch(60, []),
		{"op": "native_record_dispatch", "id": 18, "at": 70, "end": 80, "operands": []},
	]
	_check(_rows(_document("A.MES", nothing), strings).is_empty(), "a native_record_dispatch without a media string yields nothing: a non-loader string, a text name, no string, a bad index, an undecodable string, an empty or missing record list")
	var second := _rows(_document("A.MES", [_dispatch(10, [literal.call(6), _string_record(3), _string_record(5), _string_record(0)])]), strings)
	_check(_row_list(second) == ["10:unclassified:SECOND.DAT"], "the first string whose extension is a loader extension is the name")
	var gp8 := _rows(_document("A.MES", [_dispatch(10, [literal.call(6), _string_record(6)])]), strings)
	_check(_row_list(gp8) == ["10:unclassified:GONE.GP8"], "any extension the loader table knows is looked up, a .gp8 string included")
	var other_op := {"op": "script_dispatch", "id": 15, "at": 10, "end": 20, "operands": [{"t": "record_list", "records": [_string_record(0)]}]}
	_check(_rows(_document("A.MES", [other_op]), strings).is_empty(), "a string in another op's record list is not a native_record_dispatch string")
	var in_library := _rows(_library("LIBLARY.LIB", [{"routine_id": 27, "at": 0, "end": 100, "provenance_records": [], "records": [dat]}]), strings)
	_check(_row_list(in_library) == ["10:unclassified:X01.DAT"], "a library routine's native_record_dispatch string is classified too")


func _library_routines_are_regions() -> void:
	var routines := [
		{"routine_id": 23, "at": 100, "end": 200, "provenance_records": [], "records": [
			_marker("mmo_resource_marker", 110, 120, "lib.mmo"),
			_bgm_assign(130, 136, _literal(2)), _bgm_transfer(136, 23),
			_effect(150, 160, "kse0002.wav")]},
		{"routine_id": 24, "at": 200, "end": 300, "provenance_records": [], "records": [
			_bgm_assign(290, 296, _literal(2)), _bgm_transfer(296, 23)]},
	]
	var rows := _rows(_library("LIBLARY.LIB", routines))
	_check(
		_row_list(rows) == ["110:mmo:LIB.MMO", "130:bgm:STAFF.WAV", "150:se:KSE0002.WAV", "290:bgm:STAFF.WAV"],
		"a library's routines are classified, and a BGM pair stays inside its routine"
	)
	var crossing := [
		{"routine_id": 23, "at": 100, "end": 130, "provenance_records": [], "records": [_bgm_assign(124, 128, _literal(2)), _bgm_transfer(128, 23)]},
	]
	_check(_rows(_library("LIBLARY.LIB", crossing)).size() == 1, "a pair inside one library routine is a BGM reference")
	var past_end := [
		{"routine_id": 23, "at": 100, "end": 128, "provenance_records": [], "records": [_bgm_assign(124, 128, _literal(2)), _bgm_transfer(128, 23)]},
	]
	_check(_rows(_library("LIBLARY.LIB", past_end)).is_empty(), "a pair whose transfer starts at the routine's end is not inside one region")


func _script_references() -> void:
	var document := _document("A.MES", [
		_script_target("script_dispatch", 10, "girls.mes"),
		_script_target("script_handoff_marker", 30, "Miko_CG.mes"),
		_script_target("script_dispatch", 50, "GIRLS.MES"),
		_inline(70, "LIBLARY.LIB"),
		_inline(90, "start.mes"),
		_marker("mmo_resource_marker", 110, 120, "r.mmo"),
	])
	var references := Classifier.new().script_references(document)
	var simple: Array = []
	for reference in references:
		simple.append("%s@%d:%s" % [reference.name, reference.at, reference.via])
	_check(
		simple == [
			"GIRLS.MES@10:script_dispatch", "GIRLS.MES@50:script_dispatch", "LIBLARY.LIB@70:inline_script_execution",
			"MIKO_CG.MES@30:script_handoff_marker", "START.MES@90:inline_script_execution",
		],
		"script targets and inline script names are normalized and sorted, with their op as the way"
	)
	_check(not _rows(document).any(func(row): return row.name in ["LIBLARY.LIB", "START.MES"]), "inline script names are not media")


func _json_round_trip_does_not_change_the_rows() -> void:
	var strings := ["album.a6", "floor5.ccd", "x01.dat"]
	var document := _document("A.MES", [
		_marker("mmo_resource_marker", 10, 20, "r.mmo"), _a6(90, 0),
		_bgm_assign(120, 126, _literal(1)), _bgm_transfer(126, 23),
		_system_call(150, 160, 8, [_expression_record(_literal(0)), _string_record(1)]),
		_dispatch(170, [_expression_record(_literal(6)), _expression_record(_literal(25)), _string_record(2), _expression_record(_literal(0))]),
	])
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(document))
	_check(
		_row_list(_rows(parsed, strings)) == _row_list(_rows(document, strings)) and _rows(parsed, strings).size() == 5,
		"a document read back from JSON (every number a float) classifies exactly as the in-memory one"
	)


# ---- the producer's identity lookup and scan cross-check --------------------

func _write_archives(directory: String, entries_by_archive: Dictionary) -> Dictionary:
	DirAccess.make_dir_recursive_absolute(directory)
	var pinned := {}
	for archive in entries_by_archive:
		var entries: Array = []
		for entry_name in entries_by_archive[archive]:
			entries.append({"name": entry_name, "data": ("payload of " + entry_name).to_utf8_buffer()})
		SyntheticArc.write_arc(directory.path_join(archive), entries)
		pinned[archive] = FileAccess.get_sha256(directory.path_join(archive))
	return pinned


func _identity_fixture_documents() -> Array:
	var strings := ["album.a6", "floor5.ccd", "d15ss.gp8", "k_end0.mmo", "p.dat"]
	var records := [
		_marker("mmo_resource_marker", 10, 20, "r.mmo"),
		_marker("mmo_resource_marker", 22, 30, "gone.mmo"),
		_marker("ax_resource_marker", 40, 50, "b19.ax"),
		_marker("voice_marker", 60, 70, "m0001.ogg"),
		_marker("voice_marker", 72, 80, "v0001.ogg"),
		_marker("voice_marker", 82, 90, "gone.ogg"),
		_effect(100, 110, "KSE0001.WAV"),
		_a6(120, 0),
		_bgm_assign(150, 156, _literal(1)), _bgm_transfer(156, 23),
		_system_call(180, 190, 8, [_expression_record(_literal(0)), _string_record(1)]),
		_system_call(200, 210, 9, [_expression_record(_literal(0)), _string_record(2)]),
		_system_call(220, 230, 24, [_expression_record(_literal(0)), _string_record(3)]),
		_dispatch(240, [_expression_record(_literal(6)), _expression_record(_literal(25)), _string_record(4), _expression_record(_literal(0))]),
	]
	return [{"A.MES": _document("A.MES", records, [REGION], 400)}, {"A.MES": {"strings": strings}}]


func _identity_archives() -> Dictionary:
	return {
		"mmo.arc": ["R.MMO", "OTHER.MMO"],
		"data.arc": ["B19.AX", "ALBUM.A6", "FLOOR5.CCD", "P.DAT"],
		"bgm.arc": ["IDOU.WAV"],
		"se.arc": ["KSE0001.WAV"],
		"voice.arc": ["V0001.OGG"],
		"tina1.arc": ["M0001.OGG"],
		"tina2.arc": ["M0001.OGG"],
	}


func _identity_lookup_states() -> void:
	var directory := _root.path_join("identity")
	var pinned := _write_archives(directory, _identity_archives())
	var fixture := _identity_fixture_documents()
	var identity := MediaIdentity.new()
	identity.expected_archive_sha256 = pinned
	var collected := identity.collect(directory, fixture[0], fixture[1], {})
	_check(collected.get("ok", false), "the identity lookup runs over synthetic archives: %s" % str(collected.get("failures", [])))
	if not collected.get("ok", false):
		return
	var by_key := {}
	for row in collected.media_identity.names:
		by_key["%s:%s" % [row.kind, row.name]] = row
	var shipped: Dictionary = by_key["mmo:R.MMO"]
	_check(shipped.shipped == true and shipped.rows.size() == 1 and shipped.rows[0].archive == "mmo.arc" and shipped.rows[0].entry == "R.MMO", "a shipped name has one identity row naming its archive and entry")
	_check(int(shipped.rows[0].size) == ("payload of R.MMO").length() and shipped.rows[0].entry_sha256 == ("payload of R.MMO").sha256_text(), "the row carries the entry's size and SHA-256")
	var absent: Dictionary = by_key["mmo:GONE.MMO"]
	_check(absent.shipped == false and absent.searched == ["mmo.arc"] and not absent.has("rows"), "a name no archive of its kind holds is recorded absent with the archives searched")
	var bank: Dictionary = by_key["voice:M0001.OGG"]
	_check(bank.shipped == true and bank.rows.size() == 2 and bank.rows[0].archive == "tina1.arc" and bank.rows[1].archive == "tina2.arc", "a Tina name has one row in each bank, neither preferred")
	var plain_voice: Dictionary = by_key["voice:V0001.OGG"]
	_check(plain_voice.shipped == true and plain_voice.rows.size() == 1 and plain_voice.rows[0].archive == "voice.arc", "a voice name outside the Tina banks has its one row")
	var absent_voice: Dictionary = by_key["voice:GONE.OGG"]
	_check(absent_voice.shipped == false and absent_voice.searched == ["voice.arc", "tina1.arc", "tina2.arc"], "an absent voice name was searched in the voice archive and both banks")
	_check(by_key["se:KSE0001.WAV"].shipped == true and by_key["bgm:IDOU.WAV"].shipped == true and by_key["ax:B19.AX"].shipped == true and by_key["a6:ALBUM.A6"].shipped == true, "se, bgm, ax and a6 names resolve in their archives")
	_check(by_key["unclassified:FLOOR5.CCD"].shipped == true, "an unclassified loader string resolves by extension")
	_check(by_key["unclassified:P.DAT"].shipped == true and by_key["unclassified:P.DAT"].rows[0].archive == "data.arc", "a native_record_dispatch .dat name resolves in the data bank")
	_check(by_key["unclassified:D15SS.GP8"].shipped == false and by_key["unclassified:D15SS.GP8"].searched == ["data.arc"], "an unclassified .gp8 string is recorded absent in the data bank")
	_check(by_key["unclassified:K_END0.MMO"].shipped == false, "an unclassified .mmo string absent from mmo.arc is recorded absent")
	_check(collected.media_identity.archives.size() == 7, "every opened archive's live hash is recorded")
	var names_sorted := true
	var previous := ""
	for row in collected.media_identity.names:
		var key := "%s\u001f%s" % [row.kind, row.name]
		names_sorted = names_sorted and (previous.is_empty() or key > previous)
		previous = key
	_check(names_sorted, "the identity table is sorted by kind then name")

	# Archives the source root lacks leave their names undecided, not absent.
	var partial_directory := _root.path_join("partial")
	var partial_archives := _identity_archives()
	partial_archives.erase("bgm.arc")
	partial_archives.erase("tina2.arc")
	var partial_pinned := _write_archives(partial_directory, partial_archives)
	var partial := MediaIdentity.new()
	partial.expected_archive_sha256 = partial_pinned
	var partial_result := partial.collect(partial_directory, fixture[0], fixture[1], {})
	_check(partial_result.get("ok", false), "a source root missing archives still collects")
	var partial_keys := {}
	for row in partial_result.media_identity.names:
		partial_keys["%s:%s" % [row.kind, row.name]] = row
	_check(partial_keys["bgm:IDOU.WAV"].shipped == null and partial_keys["bgm:IDOU.WAV"].unavailable == ["bgm.arc"], "a name only a missing archive could settle is undecided and names the missing archive")
	_check(partial_keys["voice:GONE.OGG"].shipped == null and partial_keys["voice:GONE.OGG"].unavailable == ["tina2.arc"], "an absent voice name with a missing bank is undecided, not absent")
	_check(partial_keys["voice:M0001.OGG"].shipped == true and partial_keys["voice:M0001.OGG"].rows.size() == 1, "a Tina name present in the one bank that is available is shipped there")
	_check(partial_keys["mmo:GONE.MMO"].shipped == false, "an absence in a fully searched kind is still recorded")
	_check(not partial_result.media_identity.archives.has("bgm.arc"), "an unavailable archive has no recorded hash")
	var undecided := MediaIdentity.unavailable_rows(partial_result.media_identity)
	_check(undecided == ["bgm IDOU.WAV (bgm.arc)", "voice GONE.OGG (tina2.arc)"], "the original export CLI's undecided rows name each name with its missing archives: %s" % str(undecided))
	_check(MediaIdentity.unavailable_rows(collected.media_identity).is_empty(), "a fully searched identity table has no undecided row")
	var bare := MediaIdentity.new()
	var bare_result := bare.collect(_root.path_join("no-such-root"), fixture[0], fixture[1], {})
	var all_undecided: bool = bare_result.get("ok", false)
	for row in bare_result.get("media_identity", {}).get("names", []):
		all_undecided = all_undecided and row.shipped == null
	_check(all_undecided and bare_result.media_identity.names.size() > 0 and bare_result.media_identity.archives.is_empty(), "a source root with no media archives leaves every name undecided")
	var none := MediaIdentity.new().collect(_root.path_join("no-such-root"), {"B.MES": _document("B.MES", [])}, {"B.MES": {"strings": []}}, {})
	_check(none.get("ok", false) and none.media_identity.names.is_empty(), "a package with no media references records no identity")
	var mutated := _identity_archives()
	var mutated_directory := _root.path_join("mutated")
	var mutated_pinned := _write_archives(mutated_directory, mutated)
	mutated_pinned["mmo.arc"] = "0".repeat(64)
	var strict := MediaIdentity.new()
	strict.expected_archive_sha256 = mutated_pinned
	var strict_result := strict.collect(mutated_directory, fixture[0], fixture[1], {})
	_check(not strict_result.get("ok", true) and str(strict_result.failures).contains("mmo.arc"), "an archive that is not the pinned original fails the lookup")
	_check(not MediaIdentity.new().collect(directory, fixture[0], fixture[1], {}).get("ok", true), "synthetic archives are refused against the original pins")


func _identity_lookup_fails_closed() -> void:
	var fixture := _identity_fixture_documents()
	var elsewhere_archives := _identity_archives()
	elsewhere_archives["data.arc"] = ["B19.AX", "ALBUM.A6", "FLOOR5.CCD", "GONE.MMO"]
	var directory := _root.path_join("elsewhere")
	var pinned := _write_archives(directory, elsewhere_archives)
	var identity := MediaIdentity.new()
	identity.expected_archive_sha256 = pinned
	var result := identity.collect(directory, fixture[0], fixture[1], {})
	_check(not result.get("ok", true) and str(result.failures).contains("GONE.MMO") and str(result.failures).contains("data.arc"), "an absent name that another archive holds stops the build")

	var two_archives := _identity_archives()
	two_archives["voice.arc"] = ["V0001.OGG", "M0001.OGG"]
	var two_directory := _root.path_join("two-archives")
	var two_pinned := _write_archives(two_directory, two_archives)
	var two := MediaIdentity.new()
	two.expected_archive_sha256 = two_pinned
	var two_result := two.collect(two_directory, fixture[0], fixture[1], {})
	_check(not two_result.get("ok", true) and str(two_result.failures).contains("M0001.OGG"), "a name in the voice archive and a Tina bank is outside a declared bank set and stops the build")

	var wav_archives := _identity_archives()
	wav_archives["se.arc"] = ["KSE0001.WAV", "IDOU.WAV"]
	var wav_directory := _root.path_join("wav")
	var wav_pinned := _write_archives(wav_directory, wav_archives)
	var wav_documents := {"A.MES": _document("A.MES", [_system_call(10, 20, 5, [_expression_record(_literal(2)), _string_record(0)])])}
	var wav := MediaIdentity.new()
	wav.expected_archive_sha256 = wav_pinned
	var wav_result := wav.collect(wav_directory, wav_documents, {"A.MES": {"strings": ["idou.wav"]}}, {})
	_check(not wav_result.get("ok", true) and str(wav_result.failures).contains("IDOU.WAV"), "a loader .wav name held by both sound archives stops the build")


func _scan_hit(at: int, kind: String, name: String, boundary: String) -> Dictionary:
	return {"at": at, "kind": kind, "name": name, "boundary": boundary}


func _scan_cross_check() -> void:
	var records := [
		_marker("mmo_resource_marker", 10, 20, "r.mmo"),
		_marker("ax_resource_marker", 30, 40, "b19.ax"),
		_inline(50, "liblary.lib"),
	]
	var documents := {"A.MES": _document("A.MES", records)}
	var texts := {"A.MES": {"strings": []}}
	var archives := {"mmo.arc": ["R.MMO"], "data.arc": ["B19.AX"]}
	var directory := _root.path_join("scan")
	var pinned := _write_archives(directory, archives)
	var scan_hits := {"A.MES": [
		_scan_hit(10, "mmo", "R.MMO", "strict_indexed"),
		_scan_hit(30, "ax", "B19.AX", "bounded_envelope_scan"),
		_scan_hit(50, "mes_script", "LIBLARY.LIB", "strict_indexed"),
		_scan_hit(300, "mmo", "STRAY.MMO", "bounded_envelope_scan"),
		_scan_hit(310, "voice", "STRAY.OGG", "bounded_envelope_scan"),
		_scan_hit(320, "mes_script", "OTHER.MES", "bounded_envelope_scan"),
		_scan_hit(10, "mmo", "OTHER.MMO", "bounded_envelope_scan"),
	]}
	var identity := MediaIdentity.new()
	identity.expected_archive_sha256 = pinned
	var result := identity.collect(directory, documents, texts, scan_hits)
	_check(result.get("ok", false), "a scan whose strict hits are all records cross-checks: %s" % str(result.get("failures", [])))
	if not result.get("ok", false):
		return
	var cross: Dictionary = result.media_scan.cross_check
	_check(cross.mmo.record_backed_strict == 1 and cross.mmo.record_backed_bounded == 0 and cross.mmo.scan_only == 2, "a strict record hit is counted, a bounded hit in no record and a hit with another name are scan-only")
	_check(cross.ax.record_backed_bounded == 1 and cross.ax.record_backed_strict == 0 and cross.ax.scan_only == 0, "a bounded hit that is a record is counted apart from scan-only")
	_check(cross.voice.scan_only == 1 and cross.mes_script.record_backed_strict == 1 and cross.mes_script.scan_only == 1, "voice scan-only and inline script hits are counted")
	var rows: Array = result.media_scan.scan_only
	var listed: Array = []
	for row in rows:
		listed.append("%s@%d:%s:%s" % [row.entry, row.at, row.kind, row.name])
	listed.sort()
	_check(listed == ["A.MES@10:mmo:OTHER.MMO", "A.MES@300:mmo:STRAY.MMO", "A.MES@310:voice:STRAY.OGG"], "scan-only media rows are listed and an inline script hit has no row")
	var names := {}
	for row in result.media_identity.names:
		names["%s:%s" % [row.kind, row.name]] = row
	_check(names.has("mmo:STRAY.MMO") and names.has("voice:STRAY.OGG") and names.has("mmo:OTHER.MMO"), "scan-only names are looked up for identity")
	_check(names["mmo:STRAY.MMO"].shipped == false, "a scan-only name no archive holds is recorded absent")

	# A strict scan hit that is no record is a record the package lost.
	var strict_miss := {"A.MES": [_scan_hit(70, "mmo", "LOST.MMO", "strict_indexed")]}
	var failed := identity.collect(directory, documents, texts, strict_miss)
	_check(not failed.get("ok", true) and str(failed.failures).contains("strict_indexed") and str(failed.failures).contains("A.MES"), "a strict scan hit that is not a record occurrence fails the build")
	var strict_other_name := {"A.MES": [_scan_hit(10, "mmo", "OTHER.MMO", "strict_indexed")]}
	_check(not identity.collect(directory, documents, texts, strict_other_name).get("ok", true), "a strict scan hit with another name than the record fails the build")
	var strict_script := {"A.MES": [_scan_hit(50, "mes_script", "ELSE.MES", "strict_indexed")]}
	_check(not identity.collect(directory, documents, texts, strict_script).get("ok", true), "a strict inline script hit with another name fails the build")
	var unknown_kind := {"A.MES": [_scan_hit(70, "something", "X", "strict_indexed")]}
	_check(identity.collect(directory, documents, texts, unknown_kind).get("ok", false), "a scan kind outside the cross-check is ignored")


## TD-64 part 2: `collect` is a wrapper over the per-entry accumulator. Feeding
## the entries in any order gives the result `collect` gives - the scan-only
## rows and the failures too, which are joined in entry order.
func _identity_accumulator_matches_collect() -> void:
	var documents := {
		"A.MES": _document("A.MES", [_marker("mmo_resource_marker", 10, 20, "r.mmo")]),
		"B.MES": _document("B.MES", [_marker("ax_resource_marker", 10, 20, "b19.ax"), _marker("mmo_resource_marker", 30, 40, "r.mmo")]),
		"C.MES": _document("C.MES", []),
	}
	var texts := {"A.MES": {"strings": []}, "B.MES": {"strings": []}, "C.MES": {"strings": []}}
	var directory := _root.path_join("accumulator")
	var pinned := _write_archives(directory, {"mmo.arc": ["R.MMO", "OTHER.MMO"], "data.arc": ["B19.AX"]})
	var identity := MediaIdentity.new()
	identity.expected_archive_sha256 = pinned
	var scan_hits := {
		"A.MES": [_scan_hit(10, "mmo", "R.MMO", "strict_indexed"), _scan_hit(300, "mmo", "STRAY.MMO", "bounded_envelope_scan"), _scan_hit(310, "voice", "STRAY.OGG", "bounded_envelope_scan")],
		"B.MES": [
			_scan_hit(10, "ax", "B19.AX", "strict_indexed"), _scan_hit(30, "mmo", "R.MMO", "strict_indexed"),
			_scan_hit(200, "voice", "ALSO.OGG", "bounded_envelope_scan"), _scan_hit(90, "mmo", "OTHER.MMO", "bounded_envelope_scan"),
		],
	}
	var strict_misses := {
		"A.MES": [_scan_hit(70, "mmo", "LOST.MMO", "strict_indexed")],
		"B.MES": [_scan_hit(71, "mmo", "LOST2.MMO", "strict_indexed")],
	}
	for hits in [scan_hits, strict_misses]:
		var whole := identity.collect(directory, documents, texts, hits)
		var expected_json := JSON.stringify(whole, "", true, true)
		var all_orders_match := true
		for order in [["A.MES", "B.MES", "C.MES"], ["C.MES", "B.MES", "A.MES"], ["B.MES", "C.MES", "A.MES"]]:
			var accumulator := identity.begin(directory)
			for entry in order:
				accumulator.add(entry, documents[entry], texts[entry].strings, hits.get(entry, []))
			all_orders_match = all_orders_match and JSON.stringify(accumulator.finish(), "", true, true) == expected_json
		var label := "a clean scan" if whole.get("ok", false) else "two strict misses"
		_check(all_orders_match, "the accumulator gives collect's result for %s whatever order the entries are fed in" % label)
		if whole.get("ok", false):
			var rows: Array = whole.media_scan.scan_only
			var listed: Array = []
			for row in rows:
				listed.append("%s@%d" % [row.entry, row.at])
			_check(listed == ["A.MES@300", "A.MES@310", "B.MES@200", "B.MES@90"], "the scan-only rows come out in entry order, then discovery order")
		else:
			_check(whole.failures.size() == 2 and str(whole.failures[0]).begins_with("A.MES") and str(whole.failures[1]).begins_with("B.MES"), "the failures come out in entry order")


# ---- the manifest blocks ----------------------------------------------------

func _spec_identity(specs: Array, missing: Array = []) -> Dictionary:
	var archives := {}
	for archive in ArchiveIdentity.MEDIA_ARCHIVES:
		if not archive in missing:
			archives[archive] = ArchiveIdentity.expected(archive)
	var names: Array = []
	for spec in specs:
		var kind: String = spec[0]
		var name: String = spec[1]
		var candidates := Classifier.archives_for(kind, name)
		match str(spec[2]):
			"ship":
				names.append({"kind": kind, "name": name, "shipped": true, "rows": [_identity_row(str(candidates[0]), name)]})
			"banks":
				names.append({"kind": kind, "name": name, "shipped": true, "rows": [_identity_row("tina1.arc", name), _identity_row("tina2.arc", name)]})
			"absent":
				names.append({"kind": kind, "name": name, "shipped": false, "searched": candidates})
			"null":
				var unavailable: Array = []
				for archive in candidates:
					if archive in missing:
						unavailable.append(archive)
				names.append({"kind": kind, "name": name, "shipped": null, "unavailable": unavailable})
	return {"archives": archives, "names": names}


func _identity_row(archive: String, name: String) -> Dictionary:
	return {"archive": archive, "entry": name, "size": 10, "entry_sha256": "b".repeat(64)}


func _built(documents: Dictionary, strings: Dictionary, identity: Dictionary, scan: Dictionary) -> Dictionary:
	var reports: Array = []
	var texts := {}
	var first := ""
	for entry in documents:
		if first.is_empty():
			first = str(entry)
		reports.append({"entry": entry, "entry_sha256": "a".repeat(64), "role": "event_entry"})
		texts[entry] = {"schema": Version.PLAYBACK_PACKAGE_SCHEMA, "entry": entry, "encoding": "utf-8", "strings": strings.get(entry, ["x"])}
	# The members are streamed payloads and the inventory evidence, made by the
	# exporter's own per-entry function, as `build()` hands them over.
	var built := {"ok": true,
		"events": [{"event_id": first, "source": {"callee": {"entry": first, "start_coordinate": 0}}, "terminals": [{"offset": 0}], "presets": [], "choices": []}],
		"entry_reports": reports, "catalog": FIXTURE_CATALOG.duplicate(), "resource_names": [], "media": [],
		"media_identity": identity, "media_scan": scan,
		"dropped_instruction_fields": {}, "dropped_operand_fields": {},
		"undecodable_text_payloads": 0, "unresolved_expression_boundaries": 0, "text_round_trip_failures": 0}
	built.merge(Exporter.new().payloads_for(documents, texts))
	return built


# The package every block test starts from: two members, every kind, the three
# identity states, a bank-set name, two scan-only rows and the script references.
func _block_fixture(missing: Array = ["bgm.arc"]) -> Dictionary:
	var strings_a := ["girls.mes", "album.a6", "floor5.ccd", "d15ss.gp8", "p.dat"]
	var records_a := [
		_script_target("script_dispatch", 4, "girls.mes"),
		_marker("mmo_resource_marker", 10, 20, "r.mmo"),
		_marker("mmo_resource_marker", 22, 30, "gone.mmo"),
		_marker("ax_resource_marker", 40, 50, "b19.ax"),
		_marker("voice_marker", 60, 70, "m0001.ogg"),
		_marker("voice_marker", 72, 80, "v0001.ogg"),
		_effect(100, 110, "KSE0001.WAV"),
		_a6(120, 1),
		_bgm_assign(150, 156, _literal(1)), _bgm_transfer(156, 23),
		_bgm_assign(160, 166, _banked(3)), _bgm_transfer(166, 23),
		_system_call(180, 190, 8, [_expression_record(_literal(0)), _string_record(2)]),
		_system_call(200, 210, 9, [_expression_record(_literal(0)), _string_record(3)]),
		_dispatch(215, [_expression_record(_literal(6)), _expression_record(_literal(25)), _string_record(4), _expression_record(_literal(0))]),
		_inline(230, "B.MES"),
	]
	var records_b := [
		_script_target("script_handoff_marker", 4, "elsewhere.mes"),
		_marker("mmo_resource_marker", 10, 20, "R.MMO"),
	]
	var documents := {"A.MES": _document("A.MES", records_a), "B.MES": _document("B.MES", records_b)}
	var strings := {"A.MES": strings_a, "B.MES": ["elsewhere.mes"]}
	var specs := [
		["mmo", "R.MMO", "ship"], ["mmo", "GONE.MMO", "absent"], ["mmo", "STRAY.MMO", "absent"],
		["ax", "B19.AX", "ship"], ["voice", "M0001.OGG", "banks"], ["voice", "V0001.OGG", "ship"],
		["se", "KSE0001.WAV", "ship"], ["a6", "ALBUM.A6", "ship"],
		["bgm", "IDOU.WAV", "null"],
		["unclassified", "FLOOR5.CCD", "ship"], ["unclassified", "D15SS.GP8", "absent"], ["unclassified", "P.DAT", "ship"],
	]
	var scan := Inventory.empty_scan()
	scan.cross_check.mmo = {"record_backed_strict": 2, "record_backed_bounded": 0, "scan_only": 2}
	scan.cross_check.ax = {"record_backed_strict": 0, "record_backed_bounded": 1, "scan_only": 0}
	scan.cross_check.mes_script = {"record_backed_strict": 1, "record_backed_bounded": 0, "scan_only": 0}
	scan.scan_only = [
		{"entry": "A.MES", "at": 300, "kind": "mmo", "name": "STRAY.MMO", "boundary": "bounded_envelope_scan"},
		{"entry": "B.MES", "at": 100, "kind": "mmo", "name": "R.MMO", "boundary": "bounded_envelope_scan"},
	]
	return _built(documents, strings, _spec_identity(specs, missing), scan)


func _blocks_round_trip() -> void:
	var built := _block_fixture()
	var serialized := Exporter.new().serialize(built)
	_check(serialized.get("ok", false), "a package with every kind of occurrence serializes: %s" % str(serialized.get("failures", [])))
	if not serialized.get("ok", false):
		return
	var inventory: Dictionary = serialized.manifest.media_inventory
	_check(inventory.schema == "kakyu_media_inventory/v1" and serialized.manifest.script_references.schema == "kakyu_script_references/v1", "the manifest carries both blocks with their own schema ids")
	_check(Version.PLAYBACK_PACKAGE_SCHEMA == "kakyu_playback_package/v7" and serialized.manifest.schema == "kakyu_playback_package/v7", "the package schema stays v7")
	_check(serialized.manifest.incompleteness.media_extraction == "deferred", "media extraction stays deferred")
	var counts: Dictionary = inventory.counts
	_check(
		counts.occurrences == {"mmo": 3, "ax": 1, "voice": 2, "se": 1, "a6": 1, "bgm": 1, "unclassified": 4}
		and counts.names.mmo == 3 and counts.names.voice == 2 and counts.names.bgm == 1 and counts.names.unclassified == 3,
		"the counts record the occurrences and the distinct names per kind"
	)
	_check(counts.states == {"shipped": 8, "absent": 3, "unavailable": 1}, "the counts record the three identity states")
	_check(counts.scan_only == 2 and inventory.scan_only.size() == 2, "the counts record the scan-only rows")
	var occurrence_names: Array = []
	for member in inventory.members:
		for row in member.occurrences:
			occurrence_names.append("%s:%s:%s" % [member.entry, row.kind, row.name])
	_check(occurrence_names.has("A.MES:bgm:IDOU.WAV") and occurrence_names.has("A.MES:unclassified:") and occurrence_names.has("B.MES:mmo:R.MMO"), "the members list each occurrence with its kind and normalized name")
	var targets: Dictionary = {}
	for target in serialized.manifest.script_references.targets:
		targets[target.name] = target
	_check(targets["GIRLS.MES"].member == false and targets["ELSEWHERE.MES"].member == false and targets["B.MES"].member == true, "a script target is a member only when the package carries its entry")
	_check(targets["B.MES"].references[0].via == "inline_script_execution" and targets["GIRLS.MES"].references[0].via == "script_dispatch", "each reference names its way")
	var summary := {}
	for line in MediaIdentity.summary_lines(inventory):
		var fields := {}
		for token in line.split(" ", false):
			if "=" in token:
				fields[token.get_slice("=", 0)] = token.get_slice("=", 1)
		summary["%s:%s" % [line.get_slice(" ", 0), fields.kind]] = fields
	_check(
		summary.size() == 11 and summary["media:mmo"].record_backed == "3" and summary["media:mmo"].scan_only == "2"
		and summary["media:mmo"].shipped == "1" and summary["media:mmo"].absent == "2" and summary["media:bgm"].unavailable == "1"
		and summary["media:voice"].shipped == "2" and summary["media:unclassified"].record_backed == "4",
		"the export prints each kind's record-backed and scan-only counts with its identity states"
	)
	_check(
		summary["media_scan:mmo"].record_backed_strict == "2" and summary["media_scan:mmo"].scan_only == "2"
		and summary["media_scan:ax"].record_backed_bounded == "1" and summary["media_scan:mes_script"].record_backed_strict == "1",
		"the export prints each scan kind's cross-check counts"
	)
	var directory := _root.path_join("blocks")
	_check(Exporter.new().write(directory, serialized).ok, "the package with both blocks publishes after its own reopen")
	var loaded := Package.new().load_directory(directory)
	_check(loaded.get("ok", false), "the reader's recompute accepts the producer's blocks: %s" % str(loaded.get("error", "")))
	_check(serialized.manifest.files.size() == 4, "the blocks are manifest fields and add no package file")
	var again := Exporter.new().serialize(_block_fixture())
	_check(again.manifest.package_sha256 == serialized.manifest.package_sha256, "the same inputs give the same package hash")
	var shuffled := _block_fixture()
	shuffled.media_scan.scan_only.reverse()
	var sorted_by_writer := Exporter.new().serialize(shuffled)
	_check(
		sorted_by_writer.get("ok", false) and sorted_by_writer.manifest.package_sha256 == serialized.manifest.package_sha256,
		"the manifest writer sorts the scan-only rows, whatever order the build discovered them in"
	)


# `collect` over synthetic archives (with the test's own pins) -> `serialize` ->
# `write` -> `load_directory`: the producer's own output is readable.
func _synthetic_end_to_end() -> void:
	var directory := _root.path_join("end-to-end-archives")
	var pinned := _write_archives(directory, _identity_archives())
	var fixture := _identity_fixture_documents()
	var identity := MediaIdentity.new()
	identity.expected_archive_sha256 = pinned
	var collected := identity.collect(directory, fixture[0], fixture[1], {})
	_check(collected.get("ok", false), "the synthetic archives collect: %s" % str(collected.get("failures", [])))
	if not collected.get("ok", false):
		return
	var built := _built(fixture[0], {"A.MES": fixture[1]["A.MES"].strings}, collected.media_identity, collected.media_scan)
	var serialized := Exporter.new().serialize(built)
	_check(serialized.get("ok", false), "a build collected from synthetic archives serializes: %s" % str(serialized.get("failures", [])))
	if not serialized.get("ok", false):
		return
	_check(serialized.manifest.media_inventory.archives == pinned, "the manifest records the synthetic archives' own live hashes")
	var package_directory := _root.path_join("end-to-end")
	_check(Exporter.new().write(package_directory, serialized).ok, "the synthetic package publishes")
	var loaded := Package.new().load_directory(package_directory)
	_check(loaded.get("ok", false), "the synthetic package loads, so the reader does not need the original pins: %s" % str(loaded.get("error", "")))


func _serialize_fails_closed() -> void:
	var built := _block_fixture()
	_check(Exporter.new().serialize(built).get("ok", false), "the unmutated fixture serializes")
	var without_identity := _block_fixture()
	without_identity.erase("media_identity")
	_check(not Exporter.new().serialize(without_identity).get("ok", true), "serialize refuses a build result without the identity table")
	var without_scan := _block_fixture()
	without_scan.erase("media_scan")
	_check(not Exporter.new().serialize(without_scan).get("ok", true), "serialize refuses a build result without the scan cross-check")
	var missing_name := _block_fixture()
	missing_name.media_identity.names = missing_name.media_identity.names.filter(func(row): return row.name != "B19.AX")
	var refused := Exporter.new().serialize(missing_name)
	_check(not refused.get("ok", true) and str(refused.failures).contains("identity"), "serialize refuses an occurrence whose name has no identity entry")
	var extra_name := _block_fixture()
	extra_name.media_identity.names.append({"kind": "mmo", "name": "UNUSED.MMO", "shipped": false, "searched": ["mmo.arc"]})
	_check(not Exporter.new().serialize(extra_name).get("ok", true), "serialize refuses an identity entry no occurrence uses")
	var stale_scan := _block_fixture()
	stale_scan.media_scan.scan_only.append({"entry": "A.MES", "at": 310, "kind": "mmo", "name": "R.MMO", "boundary": "bounded_envelope_scan"})
	_check(not Exporter.new().serialize(stale_scan).get("ok", true), "serialize refuses scan-only rows that disagree with the cross-check counts")
	var coincident := _block_fixture()
	coincident.media_scan.scan_only[0] = {"entry": "A.MES", "at": 10, "kind": "mmo", "name": "R.MMO", "boundary": "bounded_envelope_scan"}
	_check(not Exporter.new().serialize(coincident).get("ok", true), "serialize refuses a scan-only row that is a record occurrence")
	var malformed_hash := _block_fixture()
	malformed_hash.media_identity.archives["mmo.arc"] = "1".repeat(63)
	_check(not Exporter.new().serialize(malformed_hash).get("ok", true), "serialize refuses an archive identity that is not a SHA-256")
	var partial_bank := _block_fixture()
	for row in partial_bank.media_identity.names:
		if row.name == "M0001.OGG":
			row.rows = [_identity_row("tina1.arc", "M0001.OGG"), _identity_row("voice.arc", "M0001.OGG")]
	_check(not Exporter.new().serialize(partial_bank).get("ok", true), "serialize refuses one name held by the voice archive and a Tina bank")
	var one_bank := _block_fixture()
	for row in one_bank.media_identity.names:
		if row.name == "M0001.OGG":
			row.rows = [_identity_row("tina2.arc", "M0001.OGG")]
	_check(Exporter.new().serialize(one_bank).get("ok", false), "serialize accepts a Tina name present in one bank only")
	var wrong_archive := _block_fixture()
	for row in wrong_archive.media_identity.names:
		if row.name == "R.MMO":
			row.rows = [_identity_row("data.arc", "R.MMO")]
	_check(not Exporter.new().serialize(wrong_archive).get("ok", true), "serialize refuses an identity row from an archive that is not one of the kind's")


func _reader_fails_closed() -> void:
	var serialized := Exporter.new().serialize(_block_fixture())
	var directory := _root.path_join("mutations")
	_check(Exporter.new().write(directory, serialized).ok, "the mutation fixture publishes")
	var cases := {
		"an occurrence removed": func(m): m.media_inventory.members[0].occurrences.remove_at(1),
		"an occurrence added": func(m): m.media_inventory.members[1].occurrences.append({"at": 15, "kind": "ax", "name": "EXTRA.AX"}),
		"an occurrence moved": func(m): m.media_inventory.members[0].occurrences[0].at = 99,
		"an occurrence renamed": func(m): m.media_inventory.members[0].occurrences[1].name = "R2.MMO",
		"a member emptied": func(m): m.media_inventory.members.remove_at(1),
		"a name without identity": func(m): m.media_inventory.names = m.media_inventory.names.filter(func(row): return row.name != "B19.AX"),
		"an identity entry no occurrence uses": func(m): _insert_name(m, {"kind": "mmo", "name": "ZZZ.MMO", "shipped": false, "searched": ["mmo.arc"]}),
		"an unsorted identity table": func(m): m.media_inventory.names.reverse(),
		"an unknown media schema id": func(m): m.media_inventory.schema = "kakyu_media_inventory/v2",
		"an unknown script schema id": func(m): m.script_references.schema = "kakyu_script_references/v2",
		"a wrong member flag": func(m): m.script_references.targets[0].member = not m.script_references.targets[0].member,
		"a wrong script reference": func(m): m.script_references.targets[0].references[0].at = 77,
		"a dropped script target": func(m): m.script_references.targets.remove_at(0),
		"wrong script counts": func(m): m.script_references.counts.references = 1,
		"wrong media counts": func(m): m.media_inventory.counts.occurrences.mmo = 1,
		"an absence claimed over an unsearched archive": func(m): _set_name(m, "GONE.MMO", {"kind": "mmo", "name": "GONE.MMO", "shipped": false, "searched": []}),
		"an absence searched in the wrong archive": func(m): _set_name(m, "GONE.MMO", {"kind": "mmo", "name": "GONE.MMO", "shipped": false, "searched": ["data.arc"]}),
		"a shipped name without rows": func(m): _set_name(m, "R.MMO", {"kind": "mmo", "name": "R.MMO", "shipped": true, "rows": []}),
		"a row of another entry": func(m): m.media_inventory.names[_name_index(m, "R.MMO")].rows[0].entry = "OTHER.MMO",
		"a row with a bad fingerprint": func(m): m.media_inventory.names[_name_index(m, "R.MMO")].rows[0].entry_sha256 = "short",
		"a row in the wrong archive": func(m): m.media_inventory.names[_name_index(m, "R.MMO")].rows[0].archive = "data.arc",
		"rows across the voice archive and a bank": func(m): m.media_inventory.names[_name_index(m, "M0001.OGG")].rows = [_identity_row("tina1.arc", "M0001.OGG"), _identity_row("voice.arc", "M0001.OGG")],
		"unsorted bank rows": func(m): m.media_inventory.names[_name_index(m, "M0001.OGG")].rows.reverse(),
		"a state that is neither": func(m): m.media_inventory.names[_name_index(m, "R.MMO")].shipped = "yes",
		"an undecided name with a wrong archive list": func(m): m.media_inventory.names[_name_index(m, "IDOU.WAV")].unavailable = ["se.arc"],
		"an archive hash removed that its names rely on": func(m): m.media_inventory.archives.erase("mmo.arc"),
		"a malformed archive hash": func(m): m.media_inventory.archives["mmo.arc"] = "2".repeat(63),
		"an unknown archive": func(m): m.media_inventory.archives["nothing.arc"] = "2".repeat(64),
		"a scan-only row that is a record": func(m): m.media_inventory.scan_only[0] = {"entry": "A.MES", "at": 10, "kind": "mmo", "name": "R.MMO", "boundary": "bounded_envelope_scan"},
		"a scan-only row of a non-member": func(m): m.media_inventory.scan_only[0].entry = "C.MES",
		"a scan-only row without identity": func(m): _add_scan_row_without_identity(m),
		"a scan-only boundary": func(m): m.media_inventory.scan_only[0].boundary = "strict_indexed",
		"scan counts that disagree with the rows": func(m): m.media_inventory.cross_check.mmo.scan_only = 5,
		"more record-backed hits than records": func(m): m.media_inventory.cross_check.mmo.record_backed_strict = 99,
		"a missing cross-check kind": func(m): m.media_inventory.cross_check.erase("voice"),
		"tampered rules": func(m): m.media_inventory.kind_archives.mmo = ["data.arc"],
		"an extra block field": func(m): m.media_inventory["extra"] = 1,
		"a media block that is not an object": func(m): m.media_inventory = [],
		"a script block that is not an object": func(m): m.script_references = "none",
	}
	for label in cases:
		var changed: Dictionary = serialized.manifest.duplicate(true)
		(cases[label] as Callable).call(changed)
		changed.package_sha256 = Integrity.new().fingerprint(changed)
		_write_manifest(directory, changed)
		var loaded := Package.new().load_directory(directory)
		_check(not loaded.get("ok", true), "a rehashed manifest with %s fails closed" % label)
	_write_manifest(directory, serialized.manifest)
	_check(Package.new().load_directory(directory).get("ok", false), "the unmutated manifest still loads after the mutation cases")
	var edited: Dictionary = serialized.manifest.duplicate(true)
	edited.media_inventory.members[0].occurrences.remove_at(1)
	_write_manifest(directory, edited)
	_check(not Package.new().load_directory(directory).get("ok", true), "a changed block fails the unchanged package hash as well")
	_write_manifest(directory, serialized.manifest)

	# The recompute reads the member records, so a changed record alone fails.
	var other := Exporter.new().serialize(_block_fixture())
	var changed_records := other.duplicate(true)
	for file in changed_records.files:
		if file.name == "events/A.json":
			var document: Dictionary = JSON.parse_string((file.payload as PackedByteArray).get_string_from_utf8())
			document.records.remove_at(1)
			file.payload = JSON.stringify(document).to_utf8_buffer()
	var edited_directory := _root.path_join("edited-record")
	DirAccess.make_dir_recursive_absolute(edited_directory.path_join("events"))
	DirAccess.make_dir_recursive_absolute(edited_directory.path_join("text"))
	var rebound: Dictionary = other.manifest.duplicate(true)
	var inventory: Array = []
	for file in changed_records.files:
		if file.name != "manifest.json":
			var handle := FileAccess.open(edited_directory.path_join(str(file.name)), FileAccess.WRITE)
			handle.store_buffer(file.payload)
			handle.close()
			inventory.append({"name": file.name, "size": file.payload.size(), "sha256": FileAccess.get_sha256(edited_directory.path_join(str(file.name)))})
	inventory.sort_custom(func(a, b): return str(a.name) < str(b.name))
	rebound.files = inventory
	rebound.package_sha256 = Integrity.new().fingerprint(rebound)
	_write_manifest(edited_directory, rebound)
	var edited_load := Package.new().load_directory(edited_directory)
	_check(not edited_load.get("ok", true) and str(edited_load.get("error", "")).contains("media inventory"), "a rebound package whose record no longer matches its inventory is refused by the recompute")


func _name_index(manifest: Dictionary, name: String) -> int:
	var names: Array = manifest.media_inventory.names
	for index in range(names.size()):
		if names[index].name == name:
			return index
	return -1


func _insert_name(manifest: Dictionary, entry: Dictionary) -> void:
	var names: Array = manifest.media_inventory.names
	names.append(entry)
	names.sort_custom(func(a, b): return "%s%s" % [a.kind, a.name] < "%s%s" % [b.kind, b.name])
	manifest.media_inventory.counts.names.mmo += 1
	manifest.media_inventory.counts.states.absent += 1


# One more scan-only row whose name the identity table does not know, with the
# cross-check and the counts moved to agree, so only the missing identity is wrong.
func _add_scan_row_without_identity(manifest: Dictionary) -> void:
	manifest.media_inventory.scan_only.append({"entry": "B.MES", "at": 200, "kind": "mmo", "name": "NOID.MMO", "boundary": "bounded_envelope_scan"})
	manifest.media_inventory.cross_check.mmo.scan_only += 1
	manifest.media_inventory.counts.scan_only += 1


func _set_name(manifest: Dictionary, name: String, replacement: Dictionary) -> void:
	manifest.media_inventory.names[_name_index(manifest, name)] = replacement


func _reader_tolerates_absences_and_missing_blocks() -> void:
	var serialized := Exporter.new().serialize(_block_fixture())
	var directory := _root.path_join("tolerance")
	_check(Exporter.new().write(directory, serialized).ok, "the tolerance fixture publishes")
	var absent_count := 0
	for row in serialized.manifest.media_inventory.names:
		if row.shipped == false:
			absent_count += 1
	_check(absent_count == 3, "the fixture records three absent names, one of them known only from the scan")
	_check(Package.new().load_directory(directory).get("ok", false), "a package that records absent and undecided names loads")

	var without: Dictionary = serialized.manifest.duplicate(true)
	without.erase("media_inventory")
	without.erase("script_references")
	without.package_sha256 = Integrity.new().fingerprint(without)
	_write_manifest(directory, without)
	_check(Package.new().load_directory(directory).get("ok", false), "a v7 manifest without the blocks still loads and makes no inventory claim")
	_check(Integrity.new().inventory_error(without, {}, {}).is_empty(), "the inventory recompute is skipped when neither block is present")

	var other_hash: Dictionary = serialized.manifest.duplicate(true)
	other_hash.media_inventory.archives["mmo.arc"] = "2".repeat(64)
	other_hash.package_sha256 = Integrity.new().fingerprint(other_hash)
	_write_manifest(directory, other_hash)
	_check(Package.new().load_directory(directory).get("ok", false), "the reader checks the archive header's shape only: a SHA-256 that is not a pin loads (the pin is build()'s)")

	var only_media: Dictionary = serialized.manifest.duplicate(true)
	only_media.erase("script_references")
	only_media.package_sha256 = Integrity.new().fingerprint(only_media)
	_write_manifest(directory, only_media)
	_check(Package.new().load_directory(directory).get("ok", false), "a manifest with only the media block loads")
	var only_scripts: Dictionary = serialized.manifest.duplicate(true)
	only_scripts.erase("media_inventory")
	only_scripts.package_sha256 = Integrity.new().fingerprint(only_scripts)
	_write_manifest(directory, only_scripts)
	_check(Package.new().load_directory(directory).get("ok", false), "a manifest with only the script block loads")

	# A package with no media reference still carries both blocks and loads.
	var plain := Exporter.new().serialize(_built({"A.MES": _document("A.MES", [])}, {}, Inventory.empty_identity(), Inventory.empty_scan()))
	_check(plain.get("ok", false) and plain.manifest.media_inventory.members.is_empty() and plain.manifest.script_references.targets.is_empty(), "a package with no references records empty blocks")
	var plain_directory := _root.path_join("plain")
	_check(Exporter.new().write(plain_directory, plain).ok and Package.new().load_directory(plain_directory).get("ok", false), "an empty-inventory package publishes and loads")


func _write_manifest(directory: String, manifest: Dictionary) -> void:
	var handle := FileAccess.open(directory.path_join("manifest.json"), FileAccess.WRITE)
	handle.store_string(JSON.stringify(manifest))
	handle.close()
