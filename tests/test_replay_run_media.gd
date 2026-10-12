extends "res://tests/test_case.gd"

## WD-21 U2 C2 (2026-10-08): `tools/content_suite/replay_run_media.gd`, the one place the
## replay v3 writers turn a probe result into `executed` / `resource_rows`. Synthetic probe
## results only (the rows and trace rows have the keys `KakyuMesRouteProbe` gives them:
## signature rows `{entry, at, end, op, effect, ...}`, trace rows `{source_entry,
## source_offset, effect, resource_name, ...}`), no archive. Pins the entry keying, the
## attribution rule for a definition invoked from inside a library routine (its rows arrive
## labelled `LIBLARY.LIB:<n>` with a DEF-relative `at`), both fail-closed guards, and the
## five-effect filter of `resource_rows`.

const RunMedia := preload("res://tools/content_suite/replay_run_media.gd")


func _row(entry: String, at: int, effect: String, op: String = "x") -> Dictionary:
	return {"entry": entry, "at": at, "end": at + 1, "op": op, "effect": effect, "resource": "", "routine": -1, "write": "::"}


func _trace(entry: String, at: int, effect: String, name: String = "") -> Dictionary:
	var row := {"source_entry": entry, "source_offset": at, "end_offset": at + 1, "op": "x", "effect": effect}
	if name != "":
		row["resource_name"] = name
	return row


func _ready() -> void:
	_check_keying()
	_check_library_invoked_definition()
	_check_self_keyed_library_definition()
	_check_guards()
	_check_resource_rows()
	_check_empty_run()
	get_tree().quit(1 if _failed else 0)


func _check_keying() -> void:
	var run := {"rows": [
		_row("01M.MES", 40, "message"), _row("01M.MES", 7, "branch"), _row("01M.MES", 40, "message"),
		_row("LIBLARY.LIB:9", 3757, "effect_dispatch_omitted"), _row("LIBLARY.LIB:27", 13658, "mmo_resource_marker"),
		_row("DEF_MAIN.MES:12", 1200, "native_record_effects_omitted"), _row("DEF_MAIN.MES:26", 520, "script_return"),
		_row("A_PIC.MES", 3, "script_return"),
	], "trace": []}
	var media := RunMedia.summarize(run)
	_check(media.ok, "plain run is accepted")
	_check(media.executed == {"01M.MES": [7, 40], "LIBLARY.LIB": [3757, 13658], "DEF_MAIN.MES": [520, 1200], "A_PIC.MES": [3]},
		"executed is keyed by package member, sorted and de-duplicated: %s" % str(media.executed))
	_check(int(media.definition_invokes) == 0 and int(media.definition_rows) == 0, "no library-invoked definition is counted in a plain run")


func _check_library_invoked_definition() -> void:
	# A library routine runs, invokes a registered definition (the definition's rows follow the
	# invoke row with DEF-relative offsets, labelled with the library routine), the definition
	# returns, the routine goes on. 3903 and 4397 are DEF record starts that equal LIB inventory
	# offsets in the real corpus: naive keying would claim library offsets for them.
	var run := {"rows": [
		_row("01M.MES", 10, "shared_routine_boundary"),
		_row("LIBLARY.LIB:9", 3769, "branch"),
		_row("LIBLARY.LIB:9", 3800, "definition_invoke_boundary", "definition_invoke"),
		_row("LIBLARY.LIB:9", 3903, "native_record_effects_omitted"),
		_row("LIBLARY.LIB:9", 4397, "native_record_effects_omitted"),
		_row("LIBLARY.LIB:9", 4400, "script_return", "command_00"),
		_row("LIBLARY.LIB:9", 3810, "continuation"),
		_row("LIBLARY.LIB:9", 6990, "script_return", "command_00"),
		_row("01M.MES", 20, "message"),
		_row("LIBLARY.LIB:27", 13640, "definition_invoke_boundary", "definition_invoke"),
		_row("LIBLARY.LIB:27", 1200, "native_record_effects_omitted"),
		_row("LIBLARY.LIB:27", 1210, "script_return", "command_00"),
		_row("LIBLARY.LIB:27", 13652, "script_return", "command_00"),
	], "trace": []}
	var media := RunMedia.summarize(run)
	_check(media.ok, "a library-invoked definition that returns is accepted: %s" % str(media.error))
	_check(media.executed == {"01M.MES": [10, 20], "LIBLARY.LIB": [3769, 3800, 3810, 6990, 13640, 13652],
		"DEF_MAIN.MES": [1200, 1210, 3903, 4397, 4400]}, "definition rows are keyed DEF_MAIN.MES, library rows LIBLARY.LIB: %s" % str(media.executed))
	_check(not (media.executed["LIBLARY.LIB"] as Array).has(3903) and not (media.executed["LIBLARY.LIB"] as Array).has(4397),
		"a DEF offset equal to a library offset is not claimed for the library")
	_check(int(media.definition_invokes) == 2 and int(media.definition_rows) == 5, "two library-invoked definitions, five rows moved: %d / %d" % [
		int(media.definition_invokes), int(media.definition_rows)])
	# A DEF-labelled invoke row (a definition the route itself invoked) is not a library invoke.
	var route_level := {"rows": [_row("DEF_MAIN.MES:11", 1076, "definition_invoke_boundary", "definition_invoke"), _row("LIBLARY.LIB:9", 3757, "effect_dispatch_omitted")], "trace": []}
	var route_media := RunMedia.summarize(route_level)
	_check(route_media.ok and int(route_media.definition_invokes) == 0 and route_media.executed == {"DEF_MAIN.MES": [1076], "LIBLARY.LIB": [3757]},
		"a route-level definition row with the invoke effect is not re-keyed: %s" % str(route_media.executed))


func _check_self_keyed_library_definition() -> void:
	# Core 0.377.0 (TD-55): the probe keys the rows of a definition a library routine invoked
	# by their own entry. The same rows, so the same executed map, and the same guards.
	var legacy := {"rows": [
		_row("LIBLARY.LIB:9", 3800, "definition_invoke_boundary", "definition_invoke"),
		_row("LIBLARY.LIB:9", 3903, "native_record_effects_omitted"),
		_row("LIBLARY.LIB:9", 4400, "script_return", "command_00"),
		_row("LIBLARY.LIB:9", 3810, "continuation"),
	], "trace": []}
	var self_keyed := {"rows": [
		_row("LIBLARY.LIB:9", 3800, "definition_invoke_boundary", "definition_invoke"),
		_row("DEF_MAIN.MES:12", 3903, "native_record_effects_omitted"),
		_row("DEF_MAIN.MES:12", 4400, "script_return", "command_00"),
		_row("LIBLARY.LIB:9", 3810, "continuation"),
	], "trace": []}
	var legacy_media := RunMedia.summarize(legacy)
	var media := RunMedia.summarize(self_keyed)
	_check(media.ok and media.executed == legacy_media.executed and media.executed == {"LIBLARY.LIB": [3800, 3810], "DEF_MAIN.MES": [3903, 4400]},
		"self-keyed definition rows give the executed map the legacy labelling gave: %s" % str(media.executed))
	_check(int(media.definition_invokes) == 1 and int(media.definition_rows) == 2, "one library-invoked definition, two rows: %d / %d" % [int(media.definition_invokes), int(media.definition_rows)])
	var route_row_inside := {"rows": [
		_row("LIBLARY.LIB:9", 3800, "definition_invoke_boundary", "definition_invoke"),
		_row("DEF_MAIN.MES:12", 3903, "native_record_effects_omitted"),
		_row("01M.MES", 20, "message"),
	], "trace": []}
	_check(not RunMedia.summarize(route_row_inside).ok, "a self-keyed definition left open by a route row is refused")
	var nested := {"rows": [
		_row("LIBLARY.LIB:9", 3800, "definition_invoke_boundary", "definition_invoke"),
		_row("DEF_MAIN.MES:12", 3903, "definition_invoke_boundary", "definition_invoke"),
		_row("DEF_MAIN.MES:13", 4400, "script_return", "command_00"),
	], "trace": []}
	var nested_media := RunMedia.summarize(nested)
	_check(not nested_media.ok and str(nested_media.error).contains("second"), "a second invoke row inside a self-keyed open definition is refused: %s" % str(nested_media.error))


func _check_guards() -> void:
	var unterminated_at_end := {"rows": [
		_row("LIBLARY.LIB:9", 3800, "definition_invoke_boundary", "definition_invoke"),
		_row("LIBLARY.LIB:9", 3903, "native_record_effects_omitted"),
	], "trace": []}
	var media := RunMedia.summarize(unterminated_at_end)
	_check(not media.ok and (media.executed as Dictionary).is_empty(), "an invoke row with no script_return before the run ends is refused")
	var unterminated_by_route := {"rows": [
		_row("LIBLARY.LIB:9", 3800, "definition_invoke_boundary", "definition_invoke"),
		_row("LIBLARY.LIB:9", 3903, "native_record_effects_omitted"),
		_row("01M.MES", 20, "message"),
	], "trace": []}
	media = RunMedia.summarize(unterminated_by_route)
	_check(not media.ok and (media.executed as Dictionary).is_empty(), "an open library-invoked definition followed by a route row is refused")
	var unterminated_by_definition := {"rows": [
		_row("LIBLARY.LIB:9", 3800, "definition_invoke_boundary", "definition_invoke"),
		_row("DEF_MAIN.MES:12", 1200, "native_record_effects_omitted"),
	], "trace": []}
	media = RunMedia.summarize(unterminated_by_definition)
	_check(not media.ok, "an open library-invoked definition followed by a DEF-labelled row is refused")
	var nested := {"rows": [
		_row("LIBLARY.LIB:9", 3800, "definition_invoke_boundary", "definition_invoke"),
		_row("LIBLARY.LIB:9", 3903, "native_record_effects_omitted"),
		_row("LIBLARY.LIB:9", 3910, "definition_invoke_boundary", "definition_invoke"),
		_row("LIBLARY.LIB:9", 3920, "script_return", "command_00"),
	], "trace": []}
	media = RunMedia.summarize(nested)
	_check(not media.ok and str(media.error).contains("second"), "a second invoke row inside an open one is refused: %s" % str(media.error))


func _check_resource_rows() -> void:
	var run := {"rows": [], "trace": [
		_trace("01M.MES", 1, "message"),
		_trace("01M.MES", 685, "bgm_request", "comic.wav"),
		_trace("01M.MES", 713, "mmo_resource_marker", "r.mmo"),
		_trace("01M.MES", 800, "voice_marker", "h0001.ogg"),
		_trace("A_PIC.MES", 12, "ax_resource_marker", "Ax_One.ax"),
		_trace("A_PIC.MES", 30, "effect_request", "KSE0031.WAV"),
		_trace("START.MES", 332, "inline_script_execution_boundary", "LIBLARY.LIB"),
		_trace("01M.MES", 900, "system_call_omitted"),
		_trace("01M.MES", 910, "native_record_effects_omitted"),
	]}
	var media := RunMedia.summarize(run)
	_check(media.ok and (media.executed as Dictionary).is_empty(), "a run with a trace and no rows has an empty executed map")
	var expected := [
		{"entry": "01M.MES", "at": 685, "effect": "bgm_request", "name": "COMIC.WAV"},
		{"entry": "01M.MES", "at": 713, "effect": "mmo_resource_marker", "name": "R.MMO"},
		{"entry": "01M.MES", "at": 800, "effect": "voice_marker", "name": "H0001.OGG"},
		{"entry": "A_PIC.MES", "at": 12, "effect": "ax_resource_marker", "name": "AX_ONE.AX"},
		{"entry": "A_PIC.MES", "at": 30, "effect": "effect_request", "name": "KSE0031.WAV"},
	]
	_check(media.resource_rows == expected, "resource_rows keeps the five media effects in trace order with upper-cased names: %s" % str(media.resource_rows))
	_check(RunMedia.MEDIA_EFFECTS.size() == 5, "exactly five media effects")


func _check_empty_run() -> void:
	var media := RunMedia.summarize({})
	_check(media.ok and (media.executed as Dictionary).is_empty() and (media.resource_rows as Array).is_empty(), "a result without rows or trace summarises to nothing")
