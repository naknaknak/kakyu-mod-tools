extends "res://tests/test_case.gd"

## WD-21 U2 C5 (decision D9): gate 3, `tools/content_suite/declared_media.gd` - every
## medium name the group-routes Playback pass's timeline uses must be the `entry` of one of
## the row's catalog `resources`. Synthetic steps and resources only (plus one tracked
## catalog row, to bind the compare to the item shape the promoter writes), no archive.
## Pins the five categories gate 2 reads, the upper-case folding, the name-level compare
## (no kind, no offset), the empty-resources and empty-name cases, and that the compare
## reads the step shape `KakyuEventPresentationTimeline` really builds.
##
## EP-14 (Core 0.378.0) adds the library-coordinate compare (`compare_library`) and the
## coverage report (`library_coverage`): timelines are built with `TimelineScript.build(trace,
## [], {}, library_media)`, and the checks pin that a library picture and effect declared at
## their coordinates pass, that the same name at another `LIBLARY.LIB` offset (the TD-55 class)
## or at the same offset under `DEF_MAIN.MES` passes the name-level compare and fails the
## library compare, that an unclassified declared library item is declared and never presented,
## that route-own media are not in the library compare, and the tracked catalog's item shape.

const Gate := preload("res://tools/content_suite/declared_media.gd")
const EventCatalogScript := preload("res://content_core/event_catalog.gd")
const TimelineScript := preload("res://content_core/event_presentation_timeline.gd")

const CATALOG_PATH := "res://config/event_catalog/original_events_v1.json"


func _ready() -> void:
	_categories_are_the_five_gate_two_reads()
	_every_declared_medium_passes()
	_each_category_fails_when_undeclared()
	_names_are_compared_upper_cased()
	_empty_resources_declare_nothing()
	_the_compare_is_by_name_only()
	_empty_and_malformed_inputs()
	_undeclared_are_listed_in_timeline_order_with_their_step()
	_the_real_timeline_step_shape_is_read()
	_a_tracked_row_declares_what_it_lists()
	_library_media_is_compared_at_its_coordinates()
	_same_name_at_another_offset_is_undeclared_at_the_library_coordinate()
	_same_offset_under_another_entry_is_undeclared()
	_a_library_medium_without_a_source_entry_is_undeclared()
	_unclassified_library_items_are_declared_and_never_presented()
	_route_own_media_are_not_in_the_library_compare()
	_a_tracked_rows_library_items_are_declared_at_their_coordinates()
	get_tree().quit(1 if _failed else 0)


# ---- fixtures ---------------------------------------------------------------

## A catalog resource item as the promoter writes it.
func _item(ordinal: int, name: String, entry: String = "01M.MES", offset: int = 0) -> Dictionary:
	return {"resource_id": "res-%04d" % ordinal, "request_entry": entry, "request_offset": offset, "entry": name}


func _step(index: int, fields: Dictionary = {}) -> Dictionary:
	var step := {"index": index, "messages": [], "voice": "", "bgm": [], "pictures": [], "animations": [], "effects": []}
	step.merge(fields, true)
	return step


## One step that plays one medium of each category.
func _full_step(index: int = 0) -> Dictionary:
	return _step(index, {
		"pictures": [{"resource_name": "BG1.MMO", "role": "base"}],
		"animations": [{"resource_name": "ANI.AX", "resource_kind": "ax"}, {"resource_name": "ATLAS.MMO", "resource_kind": "mmo"}],
		"voice": "V0001.WAV",
		"bgm": [{"resource_name": "THEME.WAV", "selector": 3}],
		"effects": [{"resource_name": "SE01.WAV", "resource_archive": "", "channel": 0}],
	})


func _full_resources() -> Array:
	return [
		_item(1, "ANI.AX"), _item(2, "ATLAS.MMO"), _item(3, "BG1.MMO"), _item(4, "SE01.WAV"),
		_item(5, "THEME.WAV"), _item(6, "V0001.WAV"),
	]


# ---- checks -----------------------------------------------------------------

func _categories_are_the_five_gate_two_reads() -> void:
	_check(Gate.CATEGORIES == ["PICTURE", "ANIMATION_SOURCE", "VOICE", "BGM", "EFFECT"], "the categories are the five the Playback pass's gate 2 reads")
	var played := Gate.played_media([_full_step()])
	var seen := {}
	for medium in played:
		seen[medium.category] = true
	_check(seen.keys().size() == 5 and played.size() == 6, "a step playing one medium of each category (two animation sources) lists six names in five categories")


func _every_declared_medium_passes() -> void:
	var result := Gate.compare(_full_resources(), [_full_step(0), _full_step(1)])
	_check(int(result.compared) == 12 and (result.undeclared as Array).is_empty(), "twelve played names, all declared: nothing undeclared (%s)" % str(result))
	# The list may declare more than the default playback reaches (the union over every
	# measured variant): extra declared names are not a failure.
	var more := _full_resources() + [_item(7, "UNUSED.MMO")]
	_check((Gate.compare(more, [_full_step()]).undeclared as Array).is_empty(), "a declared medium that is not played is not an error")
	_check(Gate.compare(_full_resources(), []).compared == 0, "no steps compare nothing")


func _each_category_fails_when_undeclared() -> void:
	# [step fields, the undeclared name as played] per category.
	var cases := {
		"PICTURE": [{"pictures": [{"resource_name": "new.mmo", "role": "base"}]}, "new.mmo"],
		"ANIMATION_SOURCE": [{"animations": [{"resource_name": "NEW.AX", "resource_kind": "ax"}]}, "NEW.AX"],
		"VOICE": [{"voice": "NEW.WAV"}, "NEW.WAV"],
		"BGM": [{"bgm": [{"resource_name": "NEW.WAV", "selector": 1}]}, "NEW.WAV"],
		"EFFECT": [{"effects": [{"resource_name": "NEW.WAV", "resource_archive": "", "channel": 0}]}, "NEW.WAV"],
	}
	for category in cases:
		var fields: Dictionary = cases[category][0]
		var played_name: String = cases[category][1]
		var result := Gate.compare(_full_resources(), [_step(4, fields)])
		var undeclared: Array = result.undeclared
		_check(int(result.compared) == 1 and undeclared.size() == 1, "%s: one played name, one undeclared" % category)
		if undeclared.size() == 1:
			var medium: Dictionary = undeclared[0]
			_check(
				medium.category == category and medium.step == 4 and medium.resource_name == played_name and medium.name == played_name.to_upper(),
				"%s: the undeclared medium names its category, step and name (%s)" % [category, str(medium)],
			)
	# A medium declared only under another name does not pass: NEW.MMO is not NEW2.MMO.
	var near := Gate.compare([_item(1, "NEW2.MMO")], [_step(0, {"pictures": [{"resource_name": "NEW.MMO"}]})])
	_check((near.undeclared as Array).size() == 1, "a declared name that only resembles the played one does not declare it")


func _names_are_compared_upper_cased() -> void:
	var lower_declared := Gate.compare([_item(1, "bg1.mmo"), _item(2, "v0001.wav")], [_step(0, {"pictures": [{"resource_name": "BG1.MMO"}], "voice": "V0001.WAV"})])
	_check((lower_declared.undeclared as Array).is_empty(), "a lower-case declared name declares the upper-case played one")
	var lower_played := Gate.compare([_item(1, "BG1.MMO"), _item(2, "V0001.WAV")], [_step(0, {"pictures": [{"resource_name": "bg1.mmo"}], "voice": "v0001.wav"})])
	_check((lower_played.undeclared as Array).is_empty(), "a lower-case played name is declared by the upper-case one")
	var mixed := Gate.compare([_item(1, "Tina01.Wav")], [_step(0, {"voice": "TINA01.WAV"})])
	_check((mixed.undeclared as Array).is_empty(), "a mixed-case name folds to the same key")
	var undeclared := Gate.compare([_item(1, "other.mmo")], [_step(0, {"pictures": [{"resource_name": "bg1.mmo"}]})])
	var listed: Array = undeclared.undeclared
	_check(listed.size() == 1 and listed[0].resource_name == "bg1.mmo" and listed[0].name == "BG1.MMO", "an undeclared name is reported as played and normalized")
	_check(Gate.declared_names([_item(1, "a.mmo"), _item(2, "A.MMO"), _item(3, "b.ax")]) == {"A.MMO": true, "B.AX": true}, "declared names fold to upper case and de-duplicate")


func _empty_resources_declare_nothing() -> void:
	var result := Gate.compare([], [_full_step()])
	_check(int(result.compared) == 6 and (result.undeclared as Array).size() == 6, "an empty resource list leaves every played name undeclared")
	var cats := {}
	for medium in result.undeclared:
		cats[medium.category] = int(cats.get(medium.category, 0)) + 1
	_check(cats == {"PICTURE": 1, "ANIMATION_SOURCE": 2, "VOICE": 1, "BGM": 1, "EFFECT": 1}, "every category is reported (%s)" % str(cats))
	var nothing := Gate.compare([], [_step(0), _step(1)])
	_check(int(nothing.compared) == 0 and (nothing.undeclared as Array).is_empty(), "no resources and no media played passes (a route with no media)")


func _the_compare_is_by_name_only() -> void:
	# The timeline keeps no offset and the catalog item no kind: a name declared at any
	# entry or offset declares the played name, whatever category plays it.
	var elsewhere := Gate.compare([_item(1, "BG1.MMO", "LIBLARY.LIB", 99999)], [_step(0, {"pictures": [{"resource_name": "BG1.MMO"}]})])
	_check((elsewhere.undeclared as Array).is_empty(), "the declaring item's entry and offset are not compared")
	var other_category := Gate.compare([_item(1, "SHARED.WAV")], [_step(0, {"voice": "SHARED.WAV", "bgm": [{"resource_name": "SHARED.WAV"}]})])
	_check((other_category.undeclared as Array).is_empty(), "the catalog item has no kind: one name declares it in every category")
	# The item's `entry` is the name; its `request_entry` is the requesting script and is never read.
	var request_only := Gate.compare([_item(1, "OTHER.MMO", "BG1.MMO")], [_step(0, {"pictures": [{"resource_name": "BG1.MMO"}]})])
	_check((request_only.undeclared as Array).size() == 1, "a name that only appears as a request entry declares nothing")


func _empty_and_malformed_inputs() -> void:
	var played := Gate.played_media([_step(0, {"voice": "", "pictures": [{"resource_name": ""}], "bgm": [{"resource_name": ""}]})])
	_check(played.is_empty(), "an empty name is not a medium name and is not compared")
	_check(Gate.declared_names([{"entry": ""}, {"nothing": 1}, 5, "x", {"resource_id": "res-0001"}]).is_empty(), "an empty or missing entry and a non-dictionary item declare nothing")
	_check(Gate.played_media([5, "x", null]).is_empty(), "a non-dictionary step plays nothing")
	var sparse := Gate.played_media([{"index": 2, "voice": "ONLY.WAV"}])
	_check(sparse.size() == 1 and sparse[0].category == "VOICE" and sparse[0].step == 2, "a step missing its lists plays only what it has")


func _undeclared_are_listed_in_timeline_order_with_their_step() -> void:
	var steps := [
		_step(0, {"pictures": [{"resource_name": "A.MMO"}, {"resource_name": "B.MMO"}], "voice": "V1.WAV"}),
		_step(1, {"voice": "V2.WAV", "bgm": [{"resource_name": "M.WAV"}]}),
	]
	var result := Gate.compare([_item(1, "B.MMO"), _item(2, "V2.WAV")], steps)
	var listed: Array = result.undeclared
	var names: Array = []
	for medium in listed:
		names.append("%s:%d:%s" % [medium.category, medium.step, medium.name])
	_check(int(result.compared) == 5 and names == ["PICTURE:0:A.MMO", "VOICE:0:V1.WAV", "BGM:1:M.WAV"], "undeclared names come in timeline order with their step (%s)" % str(names))


## The compare must read the step shape the shared timeline builder produces, not a
## shape this test invents: build real steps from runner-keyed trace rows.
func _the_real_timeline_step_shape_is_read() -> void:
	var trace := [
		{"effect": "mmo_resource_marker", "resource_name": "BASE.MMO", "source_entry": "01M.MES", "source_offset": 10, "native_active_surface_value": 1},
		{"effect": "mmo_resource_marker", "resource_name": "ATLAS.MMO", "source_entry": "01M.MES", "source_offset": 20, "native_active_surface_value": 8},
		{"effect": "ax_resource_marker", "resource_name": "ANIM.AX", "source_entry": "01M.MES", "source_offset": 30, "resource_kind": "ax"},
		{"effect": "voice_marker", "resource_name": "V9.WAV", "source_entry": "01M.MES", "source_offset": 40},
		{"effect": "bgm_request", "resource_name": "SONG.WAV", "bgm_selector": 2, "source_entry": "01M.MES", "source_offset": 50},
		{"effect": "effect_request", "resource_name": "BANG.WAV", "resource_archive": "SE.ARC", "channel_index": 1, "source_entry": "01M.MES", "source_offset": 60},
		{"effect": "dialogue_boundary", "source_entry": "01M.MES", "source_offset": 70},
		{"effect": "mmo_resource_marker", "resource_name": "LATER.MMO", "source_entry": "01M.MES", "source_offset": 80, "native_active_surface_value": 2},
	]
	var built: Dictionary = TimelineScript.build(trace, [], {})
	var steps: Array = built.steps
	var played := Gate.played_media(steps)
	var by_category := {}
	for medium in played:
		by_category[medium.category] = by_category.get(medium.category, []) + [medium.name]
	_check(by_category == {
		"PICTURE": ["BASE.MMO", "LATER.MMO"], "ANIMATION_SOURCE": ["ATLAS.MMO", "ANIM.AX"], "VOICE": ["V9.WAV"],
		"BGM": ["SONG.WAV"], "EFFECT": ["BANG.WAV"],
	}, "the real timeline's pictures, animation sources, voice, bgm and effects are all read (%s)" % str(by_category))
	var resources := [_item(1, "BASE.MMO"), _item(2, "ATLAS.MMO"), _item(3, "ANIM.AX"), _item(4, "V9.WAV"), _item(5, "SONG.WAV"), _item(6, "BANG.WAV"), _item(7, "LATER.MMO")]
	_check((Gate.compare(resources, steps).undeclared as Array).is_empty(), "a row declaring every played name passes against a real timeline")
	var short := resources.duplicate()
	short.remove_at(3)
	var failed := Gate.compare(short, steps)
	_check((failed.undeclared as Array).size() == 1 and failed.undeclared[0].category == "VOICE" and failed.undeclared[0].name == "V9.WAV", "dropping one declared name fails exactly that medium")


## Binds the compare to the tracked catalog's item shape: a row's resources, read back
## as played names, are all declared; remove one and exactly it is undeclared.
func _a_tracked_row_declares_what_it_lists() -> void:
	var catalog := EventCatalogScript.new()
	var loaded: Dictionary = catalog.load_file(CATALOG_PATH)
	_check(loaded.get("ok", false), "the tracked catalog loads")
	if not loaded.get("ok", false):
		return
	var checked_rows := 0
	for event in catalog.get_events():
		var resources: Array = event.resources
		if resources.size() < 2:
			continue
		var pictures: Array = []
		for item in resources:
			pictures.append({"resource_name": str(item.entry).to_lower()})
		var steps := [_step(0, {"pictures": pictures})]
		var result := Gate.compare(resources, steps)
		_check(int(result.compared) == resources.size() and (result.undeclared as Array).is_empty(), "%s: every listed resource name is declared by its own row" % event.event_id)
		var missing_name := str(resources[0].entry)
		var without_first := resources.duplicate(true)
		without_first.remove_at(0)
		var still_declared := false
		for item in without_first:
			still_declared = still_declared or str(item.entry).to_upper() == missing_name.to_upper()
		if not still_declared:
			var dropped := Gate.compare(without_first, steps)
			_check((dropped.undeclared as Array).size() == 1 and dropped.undeclared[0].name == missing_name.to_upper(), "%s: dropping %s from its row leaves exactly it undeclared" % [event.event_id, missing_name])
		checked_rows += 1
		if checked_rows >= 12:
			break
	_check(checked_rows == 12, "twelve tracked rows were checked")


# ---- EP-14: library media at their library coordinates ------------------------

## A library media row as the probe's `library_media` carries it (anchored at trace row 0).
func _library_media_row(effect: String, name: String, offset: int, routine: int, extra: Dictionary = {}) -> Dictionary:
	var row := {
		"effect": effect, "resource_name": name, "source_entry": "LIBLARY.LIB", "source_offset": offset, "trace_index": 0,
		"library_call": {"routine": routine, "caller_entry": "01M.MES", "caller_offset": 6, "caller_definition_id": -1},
	}
	row.merge(extra, true)
	return row


## Steps built by the real timeline from a route that calls a library routine at row 0: one
## library picture (routine 27, surface 2, the lower-case name as the archive would give it) and
## one library sound effect (routine 9).
func _library_steps(extra_media: Array = []) -> Array:
	var trace := [
		{"effect": "shared_routine_boundary", "source_entry": "01M.MES", "source_offset": 6},
		{"effect": "script_return", "source_entry": "01M.MES", "source_offset": 11},
	]
	var library_media := [
		_library_media_row("mmo_resource_marker", "01ma_3.mmo", 15553, 27, {"native_active_surface_value": 2}),
		_library_media_row("effect_request", "se_01.wav", 2000, 9, {"resource_archive": "se.arc", "channel_index": 0}),
	]
	library_media.append_array(extra_media)
	var built: Dictionary = TimelineScript.build(trace, [], {}, library_media)
	_check(built.get("ok", false), "the library fixture timeline builds: %s" % str(built.get("error", "")))
	return built.get("steps", [])


func _library_item(ordinal: int, name: String, offset: int, entry: String = "LIBLARY.LIB") -> Dictionary:
	return _item(ordinal, name, entry, offset)


func _library_media_is_compared_at_its_coordinates() -> void:
	var steps := _library_steps()
	var resources := [_library_item(1, "01MA_3.MMO", 15553), _library_item(2, "SE_01.WAV", 2000)]
	var played := Gate.played_library_media(steps)
	_check(
		played.size() == 2 and played[0].category == "PICTURE" and played[0].entry == "LIBLARY.LIB" and played[0].at == 15553
		and played[0].library_call.routine == 27 and played[0].library_call.caller_offset == 6
		and played[1].category == "EFFECT" and played[1].entry == "LIBLARY.LIB" and played[1].at == 2000
		and played[1].library_call.routine == 9,
		"the played library media carry their category, library coordinate and library_call (a library effect reads LIBLARY.LIB): %s" % str(played),
	)
	var library := Gate.compare_library(resources, steps)
	_check(int(library.compared) == 2 and (library.undeclared as Array).is_empty(), "a library picture and effect declared at their coordinates: compared, nothing undeclared (%s)" % str(library))
	var named := Gate.compare(resources, steps)
	_check(int(named.compared) == 2 and (named.undeclared as Array).is_empty(), "the name-level compare includes the library media: its compared number rises")
	var coverage := Gate.library_coverage(resources, steps)
	_check(
		int(coverage.declared) == 2 and int(coverage.presented) == 2 and coverage.presented_by_category == {"PICTURE": 1, "EFFECT": 1},
		"both declared library items are presented, one per category (%s)" % str(coverage),
	)
	_check(Gate.compare_library(resources, []).compared == 0 and Gate.library_coverage(resources, []).presented == 0, "no steps present no library media")


func _same_name_at_another_offset_is_undeclared_at_the_library_coordinate() -> void:
	var steps := _library_steps()
	var resources := [_library_item(1, "01MA_3.MMO", 15554), _library_item(2, "SE_01.WAV", 2000)]
	var named := Gate.compare(resources, steps)
	_check((named.undeclared as Array).is_empty(), "the name-level compare passes a name declared at another LIBLARY.LIB offset")
	var library := Gate.compare_library(resources, steps)
	var undeclared: Array = library.undeclared
	_check(
		int(library.compared) == 2 and undeclared.size() == 1 and undeclared[0].category == "PICTURE"
		and undeclared[0].at == 15553 and undeclared[0].entry == "LIBLARY.LIB" and undeclared[0].name == "01MA_3.MMO",
		"the library compare reports the picture undeclared at its own offset: the class a name-level match cannot see (%s)" % str(undeclared),
	)
	var coverage := Gate.library_coverage(resources, steps)
	_check(int(coverage.declared) == 2 and int(coverage.presented) == 1 and coverage.presented_by_category == {"EFFECT": 1}, "only the matched item counts as presented (%s)" % str(coverage))
	var other_name := Gate.compare_library([_library_item(1, "OTHER.MMO", 15553), _library_item(2, "SE_01.WAV", 2000)], steps)
	_check((other_name.undeclared as Array).size() == 1 and other_name.undeclared[0].category == "PICTURE", "another name at the same offset does not declare the picture either")


func _same_offset_under_another_entry_is_undeclared() -> void:
	var steps := _library_steps()
	var resources := [_library_item(1, "01MA_3.MMO", 15553, "DEF_MAIN.MES"), _library_item(2, "SE_01.WAV", 2000)]
	var library := Gate.compare_library(resources, steps)
	_check((library.undeclared as Array).size() == 1 and library.undeclared[0].name == "01MA_3.MMO", "an item declared at the same offset under DEF_MAIN.MES does not declare a LIBLARY.LIB medium")
	_check((Gate.compare(resources, steps).undeclared as Array).is_empty(), "while the name-level compare passes it")
	var coverage := Gate.library_coverage(resources, steps)
	_check(int(coverage.declared) == 1 and int(coverage.presented) == 1, "declared counts only the LIBLARY.LIB items, and presented only the matched one (%s)" % str(coverage))
	var from_definition := _library_steps([_library_media_row("mmo_resource_marker", "DEFPIC.MMO", 40, 27, {"native_active_surface_value": 2, "source_entry": "DEF_MAIN.MES"})])
	var definition_library := Gate.compare_library([_library_item(1, "01MA_3.MMO", 15553), _library_item(2, "SE_01.WAV", 2000), _library_item(3, "DEFPIC.MMO", 40, "DEF_MAIN.MES")], from_definition)
	_check(int(definition_library.compared) == 3 and (definition_library.undeclared as Array).is_empty(), "a picture the library's definition presented is compared under DEF_MAIN.MES, as the row declares it")


## The entry is the timeline entry own `source_entry`; a medium without one matches nothing.
func _a_library_medium_without_a_source_entry_is_undeclared() -> void:
	var step := _step(0, {
		"pictures": [{"resource_name": "01MA_3.MMO", "source_offset": 15553, "library_call": {"routine": 27, "caller_entry": "01M.MES", "caller_offset": 6, "caller_definition_id": -1}}],
		"effects": [{"resource_name": "SE_01.WAV", "resource_archive": "se.arc", "channel": 0, "source_entry": "LIBLARY.LIB", "source_offset": 2000,
			"library_call": {"routine": 9, "caller_entry": "01M.MES", "caller_offset": 6, "caller_definition_id": -1}}],
	})
	var resources := [_library_item(1, "01MA_3.MMO", 15553), _library_item(2, "SE_01.WAV", 2000)]
	var played := Gate.played_library_media([step])
	_check(played.size() == 2 and played[0].entry == "" and played[1].entry == "LIBLARY.LIB", "a medium without a source_entry has an empty entry; no member is assumed (%s)" % str(played))
	var library := Gate.compare_library(resources, [step])
	_check(int(library.compared) == 2 and (library.undeclared as Array).size() == 1 and library.undeclared[0].category == "PICTURE", "the medium without an entry is undeclared and the effect with one passes: the compare fails closed")
	var coverage := Gate.library_coverage(resources, [step])
	_check(int(coverage.presented) == 1 and coverage.presented_by_category == {"EFFECT": 1}, "and it is not counted as presented (%s)" % str(coverage))


func _unclassified_library_items_are_declared_and_never_presented() -> void:
	var steps := _library_steps()
	# The function-24 twin of the picture's marker (same name, another offset) and a routine-33
	# style dispatch string: declared under LIBLARY.LIB, no played medium has their offsets.
	var resources := [
		_library_item(1, "01MA_3.MMO", 15553), _library_item(2, "01MA_3.MMO", 15616),
		_library_item(3, "SE_01.WAV", 2000), _library_item(4, "table.dat", 7000),
		_item(5, "ROUTE.MMO", "01M.MES", 30),
	]
	var coverage := Gate.library_coverage(resources, steps)
	_check(
		int(coverage.declared) == 4 and int(coverage.presented) == 2 and coverage.presented_by_category == {"PICTURE": 1, "EFFECT": 1},
		"declared counts every LIBLARY.LIB item, presented only the two a played medium matches; the twin and the dispatch string are never presented (%s)" % str(coverage),
	)
	_check((Gate.compare_library(resources, steps).undeclared as Array).is_empty(), "and they are not a failure: coverage is a report, not a gate")
	var repeated := Gate.library_coverage(resources, _library_steps([_library_media_row("effect_request", "se_01.wav", 2000, 9, {"resource_archive": "se.arc", "channel_index": 0})]))
	_check(int(repeated.presented) == 2, "an item presented twice counts once")


func _route_own_media_are_not_in_the_library_compare() -> void:
	var trace := [
		{"effect": "mmo_resource_marker", "resource_name": "ROUTE.MMO", "source_entry": "01M.MES", "source_offset": 30, "native_active_surface_value": 1},
		{"effect": "effect_request", "resource_name": "ROUTE.WAV", "resource_archive": "se.arc", "channel_index": 0, "source_entry": "01M.MES", "source_offset": 40},
		{"effect": "shared_routine_boundary", "source_entry": "01M.MES", "source_offset": 50},
	]
	var library_media := [_library_media_row("mmo_resource_marker", "01ma_3.mmo", 15553, 27, {"native_active_surface_value": 2, "trace_index": 2})]
	var steps: Array = TimelineScript.build(trace, [], {}, library_media).steps
	var route_only := Gate.compare_library([], TimelineScript.build(trace.slice(0, 2), [], {}).steps)
	_check(int(route_only.compared) == 0 and (route_only.undeclared as Array).is_empty(), "route-own media (no library_call) are not in the library compare")
	var played := Gate.played_media(steps)
	_check(
		played.size() == 3 and played[0].entry == "01M.MES" and played[0].at == 30 and not played[0].has("library_call")
		and played[1].has("library_call") and played[2].category == "EFFECT" and played[2].entry == "01M.MES" and played[2].at == 40
		and not played[2].has("library_call"),
		"a route picture and a route effect carry their entry and offset, and neither a library_call (%s)" % str(played),
	)
	var mixed := Gate.compare_library([_library_item(1, "01MA_3.MMO", 15553)], steps)
	_check(int(mixed.compared) == 1 and (mixed.undeclared as Array).is_empty(), "only the library medium is compared among route-own ones")
	_check(int(Gate.compare([_item(1, "ROUTE.MMO"), _item(2, "ROUTE.WAV"), _library_item(3, "01MA_3.MMO", 15553)], steps).compared) == 3, "the name-level compare still compares all three")
	_check(int(Gate.library_coverage([_item(1, "ROUTE.MMO", "01M.MES", 30)], steps).declared) == 0, "a row without LIBLARY.LIB items declares none")


## Binds the library compare to the tracked catalog's item shape (`request_entry`,
## `request_offset`, `entry`): a row's own LIBLARY.LIB items, played back as library pictures at
## their declared coordinates, are all declared and presented; remove one and exactly it is
## undeclared.
func _a_tracked_rows_library_items_are_declared_at_their_coordinates() -> void:
	var catalog := EventCatalogScript.new()
	var loaded: Dictionary = catalog.load_file(CATALOG_PATH)
	_check(loaded.get("ok", false), "the tracked catalog loads for the library compare")
	if not loaded.get("ok", false):
		return
	var checked_rows := 0
	for event in catalog.get_events():
		var library_items: Array = (event.resources as Array).filter(func(item: Dictionary) -> bool: return str(item.request_entry) == "LIBLARY.LIB")
		if library_items.size() < 2:
			continue
		var media: Array = []
		for item in library_items:
			media.append(_library_media_row("mmo_resource_marker", str(item.entry).to_lower(), int(item.request_offset), 27, {"native_active_surface_value": 2}))
		var trace := [{"effect": "shared_routine_boundary", "source_entry": "01M.MES", "source_offset": 6}]
		var steps: Array = TimelineScript.build(trace, [], {}, media).steps
		var result := Gate.compare_library(event.resources, steps)
		_check(int(result.compared) == library_items.size() and (result.undeclared as Array).is_empty(), "%s: every LIBLARY.LIB item is declared at its own coordinate" % event.event_id)
		var coverage := Gate.library_coverage(event.resources, steps)
		_check(int(coverage.declared) == library_items.size() and int(coverage.presented) == library_items.size(), "%s: a row's library items played back are all presented (%s)" % [event.event_id, str(coverage)])
		var first: Dictionary = library_items[0]
		var rest := (event.resources as Array).duplicate(true)
		rest.remove_at((event.resources as Array).find(first))
		var still_declared := false
		for item in rest:
			still_declared = still_declared or (str(item.request_entry) == "LIBLARY.LIB" and int(item.request_offset) == int(first.request_offset) and str(item.entry).to_upper() == str(first.entry).to_upper())
		if not still_declared:
			var dropped := Gate.compare_library(rest, steps)
			_check((dropped.undeclared as Array).size() == 1 and dropped.undeclared[0].at == int(first.request_offset), "%s: dropping %s leaves exactly its coordinate undeclared" % [event.event_id, str(first.entry)])
		checked_rows += 1
		if checked_rows >= 8:
			break
	_check(checked_rows == 8, "eight tracked rows with library items were checked")
