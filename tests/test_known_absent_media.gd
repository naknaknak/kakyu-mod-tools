extends "res://tests/test_case.gd"

# WD-21 U1 C3: the two batch gates over the known-absent media register
# (`tools/content_suite/known_absent_media.gd`) - the register reader's
# fail-closed checks, gate 1's compare of a package's absent set (exact for the
# default full build, "no unregistered absence" for any other), and gate 2's
# classification of a Playback-pass miss - over synthetic registers and inventories.
# The tracked register is also loaded: it is written by a Python tool and read
# here, so its fingerprint is an independent cross-language check.

const Gate := preload("res://tools/content_suite/known_absent_media.gd")
const Fingerprint := preload("res://content_core/mes_payload_fingerprint.gd")

const ARCHIVES := {
	"mmo.arc": "1111111111111111111111111111111111111111111111111111111111111111",
	"data.arc": "2222222222222222222222222222222222222222222222222222222222222222",
	"bgm.arc": "3333333333333333333333333333333333333333333333333333333333333333",
	"se.arc": "4444444444444444444444444444444444444444444444444444444444444444",
}

var _root := ""


func _ready() -> void:
	_root = ProjectSettings.globalize_path("user://known-absent-%s-%s" % [OS.get_process_id(), Time.get_ticks_usec()])
	DirAccess.make_dir_recursive_absolute(_root)
	_register_loads_and_keys()
	_malformed_registers_fail_closed()
	_schema_mismatch_fails_closed()
	_register_file_errors()
	_tracked_register_loads()
	_gate_one_exact_equal_passes()
	_gate_one_new_absence_fails()
	_gate_one_stale_row_fails()
	_gate_one_event_mode_tolerates_a_registered_subset()
	_gate_one_event_mode_fails_an_unregistered_name()
	_gate_one_archive_header_mismatch_fails()
	_gate_one_searched_difference_fails()
	_gate_one_refuses_what_it_cannot_read()
	_gate_two_category_mapping()
	_gate_two_misses()
	_remove_tree(_root)
	get_tree().quit(1 if _failed else 0)


# ---- fixtures ---------------------------------------------------------------

func _row(kind: String, name: String, searched: Array) -> Dictionary:
	return {"kind": kind, "name": name, "searched": searched}


func _rehash(document: Dictionary) -> Dictionary:
	document["payload_sha256"] = Fingerprint.new().fingerprint(document)
	return document


func _register_document(rows: Array, archives: Dictionary = ARCHIVES) -> Dictionary:
	return _rehash({
		"schema": Gate.SCHEMA, "inventory_schema": Gate.INVENTORY_SCHEMA, "normalization": "upper_case",
		"archives": archives.duplicate(), "rows": rows.duplicate(true),
		"evidence_boundary": "synthetic", "payload_sha256": "",
	})


func _default_rows() -> Array:
	return [
		_row("ax", "B02Z.AX", ["data.arc"]),
		_row("mmo", "ZAN.MMO", ["mmo.arc"]),
		_row("unclassified", "BOALING.WAV", ["bgm.arc", "se.arc"]),
	]


func _register(rows: Array = _default_rows(), archives: Dictionary = ARCHIVES) -> Dictionary:
	var parsed: Dictionary = Gate.parse_register(_register_document(rows, archives))
	_check(parsed.get("ok", false), "the synthetic register parses: %s" % str(parsed.get("error", "")))
	return parsed.get("register", {})


func _absent(kind: String, name: String, searched: Array) -> Dictionary:
	return {"kind": kind, "name": name, "shipped": false, "searched": searched}


func _shipped(kind: String, name: String) -> Dictionary:
	return {"kind": kind, "name": name, "shipped": true, "rows": [{"archive": "mmo.arc", "entry": name, "size": 1, "entry_sha256": "a".repeat(64)}]}


func _inventory(names: Array, archives: Dictionary = ARCHIVES, schema: String = Gate.INVENTORY_SCHEMA) -> Dictionary:
	return {"schema": schema, "archives": archives.duplicate(), "names": names.duplicate(true)}


func _default_names() -> Array:
	return [
		_shipped("mmo", "PRESENT.MMO"),
		_absent("ax", "B02Z.AX", ["data.arc"]),
		_absent("mmo", "ZAN.MMO", ["mmo.arc"]),
		_absent("unclassified", "BOALING.WAV", ["bgm.arc", "se.arc"]),
	]


func _refused(document: Variant, label: String) -> void:
	var parsed: Dictionary = Gate.parse_register(document)
	_check(not parsed.get("ok", true), "%s is refused" % label)
	_check(not str(parsed.get("error", "")).is_empty(), "%s names the reason" % label)


# ---- the register reader -----------------------------------------------------

func _register_loads_and_keys() -> void:
	var register := _register()
	_check(register.row_count == 3, "the register holds its three rows")
	_check(register.archives == ARCHIVES, "the header is the archives table")
	var by_key: Dictionary = register.rows
	_check(by_key.size() == 3, "rows are keyed by (kind, name)")
	# `searched` is stored sorted whatever order the document wrote.
	var reversed := _register_document([_row("unclassified", "BOALING.WAV", ["se.arc", "bgm.arc"])])
	var parsed: Dictionary = Gate.parse_register(reversed)
	_check(parsed.ok and (parsed.register.rows as Dictionary).values()[0] == ["bgm.arc", "se.arc"], "searched archives are compared as a sorted set")
	_check(Gate.parse_register(_register_document([])).ok, "an empty register is a valid register")


func _malformed_registers_fail_closed() -> void:
	_refused(null, "a register that is null")
	_refused([], "a register that is an array")
	_refused("text", "a register that is a string")
	var extra := _register_document(_default_rows())
	extra["note"] = "extra"
	_refused(_rehash(extra), "a register with an extra key")
	var missing := _register_document(_default_rows())
	missing.erase("evidence_boundary")
	_refused(_rehash(missing), "a register without evidence_boundary")
	var empty_boundary := _register_document(_default_rows())
	empty_boundary["evidence_boundary"] = ""
	_refused(_rehash(empty_boundary), "a register with an empty evidence_boundary")
	var tampered := _register_document(_default_rows())
	(tampered.rows as Array).append(_row("mmo", "SNEAKY.MMO", ["mmo.arc"]))
	_refused(tampered, "a register whose rows changed after its fingerprint")
	var no_hash := _register_document(_default_rows())
	no_hash["payload_sha256"] = "nothex"
	_refused(no_hash, "a register with a malformed fingerprint")
	var normalization := _register_document(_default_rows())
	normalization["normalization"] = "lower_case"
	_refused(_rehash(normalization), "a register with another normalization")
	var no_archives := _register_document(_default_rows())
	no_archives["archives"] = {}
	_refused(_rehash(no_archives), "a register with an empty header")
	var bad_header := _register_document(_default_rows())
	(bad_header.archives as Dictionary)["mmo.arc"] = "not-a-sha"
	_refused(_rehash(bad_header), "a register whose header value is not a SHA-256")
	var rows_not_array := _register_document(_default_rows())
	rows_not_array["rows"] = {}
	_refused(_rehash(rows_not_array), "a register whose rows are not an array")
	var duplicate := _register_document(_default_rows() + [_row("mmo", "ZAN.MMO", ["mmo.arc"])])
	_refused(duplicate, "a register with a duplicate row")
	_refused(_register_document([_row("movie", "X.MMO", ["mmo.arc"])]), "a row of an unknown kind")
	_refused(_register_document([_row("mmo", "zan.mmo", ["mmo.arc"])]), "a row whose name is not normalized")
	_refused(_register_document([_row("mmo", "", ["mmo.arc"])]), "a row with an empty name")
	_refused(_register_document([_row("mmo", "X.MMO", [])]), "a row with no searched archive")
	_refused(_register_document([_row("mmo", "X.MMO", ["nowhere.arc"])]), "a row searched in an archive the header lacks")
	_refused(_register_document([_row("mmo", "X.MMO", ["mmo.arc", "mmo.arc"])]), "a row that lists an archive twice")
	_refused(_register_document([_row("mmo", "X.MMO", [1])]), "a row whose searched archive is not a string")
	var row_extra := _row("mmo", "X.MMO", ["mmo.arc"])
	row_extra["evidence"] = "no"
	_refused(_register_document([row_extra]), "a row with an evidence key (rows carry the archives searched only)")
	_refused(_register_document(["text"]), "a row that is not an object")


func _schema_mismatch_fails_closed() -> void:
	var other_schema := _register_document(_default_rows())
	other_schema["schema"] = "kakyu_known_absent_media/v2"
	_refused(_rehash(other_schema), "a register of another schema version")
	var other_inventory := _register_document(_default_rows())
	other_inventory["inventory_schema"] = "kakyu_media_inventory/v2"
	_refused(_rehash(other_inventory), "a register derived from another inventory schema")


func _register_file_errors() -> void:
	var missing: Dictionary = Gate.load_register(_root.path_join("absent.json"))
	_check(not missing.ok and str(missing.error).contains("does not exist"), "a missing register file is refused")
	var garbage_path := _root.path_join("garbage.json")
	var handle := FileAccess.open(garbage_path, FileAccess.WRITE)
	handle.store_string("{not json")
	handle.close()
	var garbage: Dictionary = Gate.load_register(garbage_path)
	_check(not garbage.ok and str(garbage.error).contains("not valid JSON"), "a register file that is not JSON is refused")
	var good_path := _root.path_join("good.json")
	handle = FileAccess.open(good_path, FileAccess.WRITE)
	handle.store_string(JSON.stringify(_register_document(_default_rows()), "  ", true))
	handle.close()
	var good: Dictionary = Gate.load_register(good_path)
	_check(good.ok and good.register.row_count == 3, "a register file round-trips through JSON with its fingerprint intact")


func _tracked_register_loads() -> void:
	var loaded: Dictionary = Gate.load_register()
	_check(loaded.get("ok", false), "the tracked register loads and its Python-written fingerprint verifies here: %s" % str(loaded.get("error", "")))
	if not loaded.get("ok", false):
		return
	var register: Dictionary = loaded.register
	_check(register.row_count > 0, "the tracked register has rows")
	_check(register.archives.size() >= 4, "the tracked register's header covers the searched archives")
	var kinds := {}
	for key in register.rows:
		kinds[str(key).split("\u001f")[0]] = true
	_check(not kinds.has("voice") and not kinds.has("se"), "the tracked register has no voice or se absence (measured: none)")


# ---- gate 1 ---------------------------------------------------------------

func _compare(register: Dictionary, names: Array, exact: bool, archives: Dictionary = ARCHIVES) -> Dictionary:
	return Gate.compare_export(register, _inventory(names, archives), exact)


func _gate_one_exact_equal_passes() -> void:
	var result := _compare(_register(), _default_names(), true)
	_check(result.ok and (result.failures as Array).is_empty(), "exact: the package's absent set equal to the register passes")
	_check(result.absent == 3 and result.registered == 3, "exact: both sides count three rows")
	# Order of the package's rows and of `searched` does not matter, shipped rows are ignored.
	var shuffled := _default_names()
	shuffled.reverse()
	shuffled[0]["searched"] = ["se.arc", "bgm.arc"]
	_check(_compare(_register(), shuffled, true).ok, "exact: row order and searched order do not matter, and a shipped row is not an absence")
	var no_rows := _compare(_register([]), [_shipped("mmo", "PRESENT.MMO")], true)
	_check(no_rows.ok, "exact: an empty register equals a package with no absent name")


func _gate_one_new_absence_fails() -> void:
	var names := _default_names()
	names.append(_absent("mmo", "NEWLY.MMO", ["mmo.arc"]))
	var result := _compare(_register(), names, true)
	_check(not result.ok, "exact: a new absence fails")
	_check((result.unregistered as Array).size() == 1 and str((result.unregistered as Array)[0]).contains("NEWLY.MMO"), "exact: the new absence is named")
	_check((result.stale as Array).is_empty(), "exact: a new absence is not stale")
	var other_kind := _default_names()
	other_kind.append(_absent("voice", "ZAN.MMO", ["voice.arc"]))
	_check(not _compare(_register(), other_kind, true).ok, "exact: the same name under another kind is a new absence")


func _gate_one_stale_row_fails() -> void:
	var names := _default_names()
	names.remove_at(1)
	var result := _compare(_register(), names, true)
	_check(not result.ok, "exact: a stale register row fails")
	_check((result.stale as Array).size() == 1 and str((result.stale as Array)[0]).contains("B02Z.AX"), "exact: the stale row is named")
	_check((result.unregistered as Array).is_empty(), "exact: a stale row is not an unregistered absence")
	var shipped_now := _default_names()
	shipped_now[1] = _shipped("ax", "B02Z.AX")
	_check(not _compare(_register(), shipped_now, true).ok, "exact: a registered name the archives now ship is stale")


func _gate_one_event_mode_tolerates_a_registered_subset() -> void:
	var subset := [_shipped("mmo", "PRESENT.MMO"), _absent("ax", "B02Z.AX", ["data.arc"])]
	var result := _compare(_register(), subset, false)
	_check(result.ok and (result.stale as Array).is_empty(), "event mode: a registered subset passes and the missing rows are not stale")
	_check(_compare(_register(), [], false).ok, "event mode: a package with no absent name passes")
	_check(not _compare(_register(), subset, true).ok, "the same subset fails in exact mode")


func _gate_one_event_mode_fails_an_unregistered_name() -> void:
	var names := [_absent("ax", "B02Z.AX", ["data.arc"]), _absent("ax", "ELSEWHERE.AX", ["data.arc"])]
	var result := _compare(_register(), names, false)
	_check(not result.ok, "event mode: an unregistered absence fails")
	_check((result.unregistered as Array).size() == 1 and str((result.unregistered as Array)[0]).contains("ELSEWHERE.AX"), "event mode: the unregistered name is named")


func _gate_one_archive_header_mismatch_fails() -> void:
	var changed := ARCHIVES.duplicate()
	changed["mmo.arc"] = "9".repeat(64)
	for exact in [true, false]:
		var result := _compare(_register(), _default_names(), exact, changed)
		_check(not result.ok and (result.header as Array).size() == 1 and str((result.header as Array)[0]).begins_with("mmo.arc"), "header: a differing archive SHA-256 fails (exact=%s)" % str(exact))
	var fewer := ARCHIVES.duplicate()
	fewer.erase("se.arc")
	# The inventory's own rows must still be header-covered, so the unclassified row
	# searched in se.arc is dropped from the synthetic package to isolate the header.
	var names := _default_names()
	names.remove_at(3)
	var short := _compare(_register([_row("ax", "B02Z.AX", ["data.arc"]), _row("mmo", "ZAN.MMO", ["mmo.arc"])]), names, false, fewer)
	_check(not short.ok and (short.header as Array).size() == 1 and str((short.header as Array)[0]).begins_with("se.arc"), "header: an archive the package did not open fails")
	var extra := ARCHIVES.duplicate()
	extra["voice.arc"] = "8".repeat(64)
	var more := _compare(_register(), _default_names(), false, extra)
	_check(not more.ok and (more.header as Array).size() == 1 and str((more.header as Array)[0]).begins_with("voice.arc"), "header: an archive the register lacks fails")


func _gate_one_searched_difference_fails() -> void:
	var names := _default_names()
	names[2]["searched"] = ["mmo.arc", "data.arc"]
	var result := _compare(_register(), names, false)
	_check(not result.ok and (result.changed as Array).size() == 1 and str((result.changed as Array)[0]).contains("ZAN.MMO"), "a registered name searched in other archives fails")
	_check((result.unregistered as Array).is_empty() and (result.stale as Array).is_empty(), "a searched difference is neither unregistered nor stale")


func _gate_one_refuses_what_it_cannot_read() -> void:
	var register := _register()
	_check(not Gate.compare_export(register, null, true).ok, "a package with no media_inventory is refused")
	_check(not Gate.compare_export(register, [], true).ok, "a package whose media_inventory is not an object is refused")
	_check(not Gate.compare_export(register, _inventory(_default_names(), ARCHIVES, "kakyu_media_inventory/v2"), true).ok, "a package inventory of another schema is refused")
	var undecided := _default_names()
	undecided.append({"kind": "voice", "name": "M0001.OGG", "shipped": null, "unavailable": ["tina1.arc"]})
	var result := _compare(register, undecided, false)
	_check(not result.ok and str((result.failures as Array)[0]).contains("undecided"), "an undecided (shipped: null) row is refused")
	var malformed := _default_names()
	malformed[1]["searched"] = ["nowhere.arc"]
	_check(not _compare(register, malformed, false).ok, "an absent row searched in an archive the header lacks is refused")
	var odd_state := _default_names()
	odd_state[1]["shipped"] = "no"
	_check(not _compare(register, odd_state, false).ok, "a row with a non-boolean shipped state is refused")
	var duplicate := _default_names()
	duplicate.append(_absent("mmo", "ZAN.MMO", ["mmo.arc"]))
	_check(not _compare(register, duplicate, false).ok, "two absent rows for one name are refused")
	var no_names := _inventory(_default_names())
	no_names.erase("names")
	_check(not Gate.compare_export(register, no_names, true).ok, "an inventory without names is refused")


# ---- gate 2 ---------------------------------------------------------------

func _gate_two_category_mapping() -> void:
	_check(Gate.playback_kind("PICTURE", "mmo", "B02Z.mmo") == "mmo", "PICTURE maps to mmo")
	_check(Gate.playback_kind("ANIMATION_SOURCE", "mmo", "zan.mmo") == "mmo", "ANIMATION_SOURCE with resource_kind mmo maps to mmo")
	_check(Gate.playback_kind("ANIMATION_SOURCE", "ax", "B02Z.AX") == "ax", "ANIMATION_SOURCE with resource_kind ax maps to ax")
	_check(Gate.playback_kind("ANIMATION_SOURCE", "", "B02Z.AX") == "ax", "ANIMATION_SOURCE without a resource_kind maps by extension to ax")
	_check(Gate.playback_kind("ANIMATION_SOURCE", "", "zan.mmo") == "mmo", "ANIMATION_SOURCE without a resource_kind maps by extension to mmo")
	_check(Gate.playback_kind("VOICE", "voice", "H0001.OGG") == "voice", "VOICE maps to voice")
	_check(Gate.playback_kind("BGM", "bgm", "COMIC.WAV") == "bgm", "BGM maps to bgm")
	_check(Gate.playback_kind("EFFECT", "se", "BELL.WAV") == "se", "EFFECT maps to se")
	_check(Gate.playback_kind("NOVEL", "mmo", "X.MMO") == "", "an unknown category maps to no kind")


func _gate_two_misses() -> void:
	var register := _register([
		_row("ax", "B02Z.AX", ["data.arc"]), _row("mmo", "B02Z.MMO", ["mmo.arc"]), _row("mmo", "ZAN.MMO", ["mmo.arc"]),
		_row("se", "BELL.WAV", ["se.arc"]),
	])
	var picture: Dictionary = Gate.classify_playback_miss(register, "PICTURE", "mmo", "b02z.mmo")
	_check(picture.registered and picture.kind == "mmo" and picture.name == "B02Z.MMO", "a lower-case picture miss is normalized and registered")
	var animation_ax: Dictionary = Gate.classify_playback_miss(register, "ANIMATION_SOURCE", "ax", "B02Z.AX")
	_check(animation_ax.registered and animation_ax.kind == "ax", "an ax animation source miss is registered under ax")
	var animation_mmo: Dictionary = Gate.classify_playback_miss(register, "ANIMATION_SOURCE", "mmo", "zan.mmo")
	_check(animation_mmo.registered and animation_mmo.kind == "mmo", "an mmo animation source miss is registered under mmo")
	var effect: Dictionary = Gate.classify_playback_miss(register, "EFFECT", "se", "bell.wav")
	_check(effect.registered and effect.kind == "se", "an effect miss is registered under se")
	var unregistered_picture: Dictionary = Gate.classify_playback_miss(register, "PICTURE", "mmo", "other.mmo")
	_check(not unregistered_picture.registered, "a picture miss that is not in the register is unregistered (fails the shard)")
	var voice: Dictionary = Gate.classify_playback_miss(register, "VOICE", "voice", "H0001.OGG")
	_check(not voice.registered and voice.kind == "voice", "a voice miss is unregistered when the register holds no voice row")
	var bgm: Dictionary = Gate.classify_playback_miss(register, "BGM", "bgm", "NANA2.WAV")
	_check(not bgm.registered and bgm.kind == "bgm", "a BGM miss is unregistered when the register holds no bgm row")
	var wrong_kind: Dictionary = Gate.classify_playback_miss(register, "VOICE", "voice", "B02Z.MMO")
	_check(not wrong_kind.registered, "a registered mmo name does not register a voice miss of the same name")
	var unknown: Dictionary = Gate.classify_playback_miss(register, "NOVEL", "mmo", "ZAN.MMO")
	_check(not unknown.registered and unknown.kind == "", "an unknown category is never registered")
	var empty: Dictionary = Gate.classify_playback_miss({}, "PICTURE", "mmo", "ZAN.MMO")
	_check(not empty.registered, "with no register loaded every miss is unregistered")
