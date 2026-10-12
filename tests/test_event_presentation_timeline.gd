extends "res://tests/test_case.gd"

const TimelineScript := preload("res://content_core/event_presentation_timeline.gd")


func _ready() -> void:
	_check_empty_run()
	_check_line_grouping_and_collection()
	_check_cumulative_pictures()
	_check_picture_surface_roles()
	_check_library_media_placement()
	_check_library_media_at_dialogue_boundaries()
	_check_library_media_refusals()
	_check_build_without_library_media()
	_check_library_media_leave_messages_and_steps()
	await get_tree().process_frame
	get_tree().quit(1 if _failed else 0)


func _check_empty_run() -> void:
	var built: Dictionary = TimelineScript.build([], [], {})
	_check(built.get("ok", false), "an empty run builds ok")
	_check((built.steps as Array).is_empty(), "an empty run has no steps")
	_check((built.omitted as Dictionary).is_empty(), "an empty run has no omitted effects")
	_check((built.unclassified as Array).is_empty(), "an empty run has no unclassified effects")
	_check((built.unclassified_pictures as Array).is_empty(), "an empty run has no unclassified pictures")


func _row(entry: String, offset: int, effect: String, extra: Dictionary = {}) -> Dictionary:
	var row := {"source_entry": entry, "source_offset": offset, "effect": effect}
	for key in extra:
		row[key] = extra[key]
	return row


func _message(entry: String, offset: int, extra: Dictionary = {}) -> Dictionary:
	var message := {"source_entry": entry, "source_offset": offset, "text": "line"}
	for key in extra:
		message[key] = extra[key]
	return message


## EP-13 part B: a step is the run of message records between two
## `dialogue_boundary` rows, found by encounter order against the three
## message-producing effects - not by matching a message's own offset back
## onto a trace row, which does not work for `literal_text_insert` (its
## message carries its nested text record's offset, not the enclosing
## instruction's, modeled here by deliberately using a different offset for
## every literal message than its producing row). Covers: a single-message
## line (`m D`), a three-record line (`m P m D`, EVENTB03's dominant
## pattern), an empty line between two boundaries (a `D` with nothing
## between it and the previous one), and records after the last boundary
## forming the closing step. Also covers `voice`, `bgm`, `pictures`,
## `animations` and `effects` collecting over a step's whole run (not just
## its message rows), and the omitted/unclassified passthroughs.
func _check_line_grouping_and_collection() -> void:
	var trace := [
		_row("CALLER.MES", 0x08, "voice_marker", {"resource_name": "VOICE1"}),
		_row("CALLER.MES", 0x0C, "literal_text_insert"),
		_row("CALLER.MES", 0x10, "dialogue_boundary"),
		_row("CALLER.MES", 0x14, "bgm_request", {"resource_name": "BGM_A", "bgm_selector": 5}),
		_row("CALLER.MES", 0x18, "bgm_request", {"resource_name": "BGM_B", "bgm_selector": 6}),
		_row("CALLER.MES", 0x1C, "mmo_resource_marker", {"resource_name": "BG1.MMO"}),
		_row("X_PIC.MES", 0x20, "mmo_resource_marker", {"resource_name": "FG1.MMO"}),
		_row("CALLER.MES", 0x24, "literal_text_insert"),
		_row("CALLER.MES", 0x28, "protagonist_name_insert"),
		_row("CALLER.MES", 0x2C, "literal_text_insert"),
		_row("CALLER.MES", 0x30, "dialogue_boundary"),
		_row("CALLER.MES", 0x34, "ax_resource_marker", {"resource_name": "AX1.AX"}),
		_row("CALLER.MES", 0x38, "effect_request", {"resource_name": "SE1.SE", "resource_archive": "se.arc", "channel_index": 2}),
		_row("CALLER.MES", 0x3C, "surface_dispatch_omitted"),
		_row("CALLER.MES", 0x40, "system_call_omitted"),
		_row("CALLER.MES", 0x44, "native_presentation_boundary"),
		_row("CALLER.MES", 0x48, "unknown_runner_effect"),
		_row("CALLER.MES", 0x4C, "dialogue_boundary"),
		_row("CALLER.MES", 0x50, "literal_text_insert"),
		_row("CALLER.MES", 0x54, "script_return"),
	]
	var messages := [
		_message("CALLER.MES", 0x0D, {"dynamic_kind": "literal_record"}),
		_message("CALLER.MES", 0x25, {"dynamic_kind": "literal_record"}),
		_message("CALLER.MES", 0x28, {"dynamic_kind": "protagonist_name", "resolved": true}),
		_message("CALLER.MES", 0x2D, {"dynamic_kind": "literal_record"}),
		_message("CALLER.MES", 0x51, {"dynamic_kind": "literal_record"}),
	]
	var built: Dictionary = TimelineScript.build(trace, messages, {})
	_check(built.get("ok", false), "the run builds ok")
	var steps: Array = built.steps
	_check(steps.size() == 4, "three dialogue-boundary-closed steps plus one closing step")

	var step0: Dictionary = steps[0]
	_check((step0.messages as Array).size() == 1 and (step0.messages as Array)[0] == messages[0], "a single-message line (m D) collects exactly its one record")
	_check(step0.message == messages[0], "the compatibility message field is the step's first record")
	_check(str(step0.voice) == "VOICE1", "the voice marker before the first boundary is captured")
	_check(not step0.has("closing"), "the first step is not the closing step")
	_check(str(step0.visible.background) == "" and str(step0.visible.foreground) == "", "no picture is visible before any mmo_resource_marker row")

	var step1: Dictionary = steps[1]
	var step1_messages: Array = step1.messages
	_check(
		step1_messages.size() == 3 and step1_messages[0] == messages[1]
		and step1_messages[1] == messages[2] and step1_messages[2] == messages[3],
		"a three-record line (m P m D) collects its literal, name insert and literal in order",
	)
	var bgm: Array = step1.bgm
	_check(bgm.size() == 2, "both BGM requests before the second boundary are recorded even though neither is a message record")
	_check(str(bgm[0].resource_name) == "BGM_A" and int(bgm[0].selector) == 5, "the first BGM request is recorded")
	_check(str(bgm[1].resource_name) == "BGM_B" and int(bgm[1].selector) == 6, "the second BGM request is recorded")
	var pictures: Array = step1.pictures
	_check(pictures.size() == 2, "the background and foreground pictures before the second boundary are both recorded")
	_check(str(pictures[0].resource_name) == "BG1.MMO" and str(pictures[0].layer) == "background", "a picture from the caller entry with no surface value keeps the old file-name rule (background)")
	_check(str(pictures[1].resource_name) == "FG1.MMO" and str(pictures[1].layer) == "foreground", "a picture from an X_PIC.MES entry with no surface value keeps the old file-name rule (foreground)")
	_check(str(step1.visible.background) == "BG1.MMO" and str(step1.visible.foreground) == "FG1.MMO", "the second step's visible state reflects both new pictures")

	var step2: Dictionary = steps[2]
	_check((step2.messages as Array).is_empty(), "an empty line between two boundaries is still counted, with no message records")
	_check(not step2.has("message"), "an empty line carries no compatibility message field")
	_check(not step2.has("closing"), "an internal dialogue-boundary-closed step is not the closing step")
	_check(str(step2.visible.background) == "BG1.MMO" and str(step2.visible.foreground) == "FG1.MMO", "the empty third step carries the visible state forward with no picture rows of its own")
	var animations: Array = step2.animations
	_check(animations.size() == 1 and str(animations[0].resource_name) == "AX1.AX" and str(animations[0].resource_kind) == "ax", "the AX marker is recorded, not played")
	var effects: Array = step2.effects
	_check(
		effects.size() == 1 and str(effects[0].resource_name) == "SE1.SE"
		and str(effects[0].resource_archive) == "se.arc" and int(effects[0].channel) == 2,
		"the effect request is recorded with its archive and channel",
	)

	var omitted: Dictionary = built.omitted
	_check(
		int(omitted.get("surface_dispatch_omitted", 0)) == 1
		and int(omitted.get("system_call_omitted", 0)) == 1
		and int(omitted.get("native_presentation_boundary", 0)) == 1,
		"the three omitted kinds are each counted once",
	)
	var unclassified: Array = built.unclassified
	_check(unclassified == ["unknown_runner_effect"], "an unknown effect is listed by name, not silently dropped")

	var step3: Dictionary = steps[3]
	_check(bool(step3.get("closing", false)), "the trailing message after the last boundary forms the closing step")
	_check((step3.messages as Array).size() == 1 and (step3.messages as Array)[0] == messages[4], "the closing step still collects a trailing message record")
	_check(step3.message == messages[4], "the closing step's compatibility message field is its trailing record")
	_check(int(step3.index) == 3, "the closing step's index follows the dialogue-boundary-closed steps")
	_check(str(step3.visible.background) == "BG1.MMO" and str(step3.visible.foreground) == "FG1.MMO", "the closing step also carries the visible state forward")


func _check_cumulative_pictures() -> void:
	# Round 2 (owner, 2026-09-20): picture state is cumulative across steps,
	# and within one step a foreground followed by a background (last-write
	# per layer) does not wipe the other layer. Re-pinned for EP-13 part B: a
	# foreground and a background before the first boundary, a second line
	# with no picture rows of its own (carries both forward), and a trailing
	# background-only change forming the closing step.
	var trace := [
		_row("Y_PIC.MES", 0x04, "mmo_resource_marker", {"resource_name": "FG_A.MMO"}),
		_row("CALLER.MES", 0x08, "mmo_resource_marker", {"resource_name": "BG_A.MMO"}),
		_row("CALLER.MES", 0x0C, "literal_text_insert"),
		_row("CALLER.MES", 0x10, "dialogue_boundary"),
		_row("CALLER.MES", 0x14, "literal_text_insert"),
		_row("CALLER.MES", 0x18, "dialogue_boundary"),
		_row("CALLER.MES", 0x1C, "mmo_resource_marker", {"resource_name": "BG_B.MMO"}),
		_row("CALLER.MES", 0x20, "script_return"),
	]
	var messages := [
		_message("CALLER.MES", 0x0D, {"dynamic_kind": "literal_record"}),
		_message("CALLER.MES", 0x15, {"dynamic_kind": "literal_record"}),
	]
	var built: Dictionary = TimelineScript.build(trace, messages, {})
	_check(built.get("ok", false), "the cumulative-pictures run builds ok")
	var steps: Array = built.steps
	_check(steps.size() == 3, "the cumulative-pictures run has two dialogue-boundary-closed steps and one closing step")

	var step0: Dictionary = steps[0]
	_check(
		str(step0.visible.foreground) == "FG_A.MMO" and str(step0.visible.background) == "BG_A.MMO",
		"a foreground followed by a background in the same step sets both, wiping neither",
	)

	var step1: Dictionary = steps[1]
	_check(
		str(step1.visible.foreground) == "FG_A.MMO" and str(step1.visible.background) == "BG_A.MMO",
		"a step with no picture rows carries the prior visible state forward unchanged",
	)

	var step2: Dictionary = steps[2]
	_check(bool(step2.get("closing", false)), "the trailing background row forms a closing step")
	_check(
		str(step2.visible.foreground) == "FG_A.MMO" and str(step2.visible.background) == "BG_B.MMO",
		"the closing step updates only the background, carrying the untouched foreground forward",
	)


## EP-13 part A: every `mmo_resource_marker` row is classified by its
## confirmed `native_active_surface_value`, not by the loading script's file
## name. Covers surfaces 8 (animation source), 2 from a `*_PIC.MES` script
## (standing/foreground), 2 from any other script, 1 and 9 (all three base/
## background), and a row with no surface value at all (the old file-name
## rule, listed in `unclassified_pictures` - deduplicated by
## (source_entry, resource_name)).
func _check_picture_surface_roles() -> void:
	var trace := [
		_row("EVENTX01.MES", 0x10, "mmo_resource_marker", {"resource_name": "X01AN.MMO", "native_active_surface_value": 8}),
		_row("EVENTX01.MES", 0x14, "ax_resource_marker", {"resource_name": "X01.AX"}),
		_row("X_PIC.MES", 0x18, "mmo_resource_marker", {"resource_name": "X.MMO", "native_active_surface_value": 2}),
		_row("EVENTX01.MES", 0x1C, "mmo_resource_marker", {"resource_name": "X01.MMO", "native_active_surface_value": 2}),
		_row("EVENTX01.MES", 0x20, "mmo_resource_marker", {"resource_name": "X01B.MMO", "native_active_surface_value": 1}),
		_row("EVENTX01.MES", 0x24, "mmo_resource_marker", {"resource_name": "X01C.MMO", "native_active_surface_value": 9}),
		_row("EVENTX01.MES", 0x28, "mmo_resource_marker", {"resource_name": "X01D.MMO"}),
		_row("Y_PIC.MES", 0x2C, "mmo_resource_marker", {"resource_name": "Y.MMO"}),
		_row("Y_PIC.MES", 0x30, "mmo_resource_marker", {"resource_name": "Y.MMO"}),
	]
	var built: Dictionary = TimelineScript.build(trace, [], {})
	_check(built.get("ok", false), "the surface-role run builds ok")
	var steps: Array = built.steps
	_check(steps.size() == 1, "a run with no dialogue boundary at all forms one closing step")
	var step: Dictionary = steps[0]

	var animations: Array = step.animations
	_check(animations.size() == 2, "the surface-8 mmo row and the ax row both join animations, never pictures")
	_check(
		str(animations[0].resource_name) == "X01AN.MMO" and int(animations[0].surface) == 8
		and str(animations[0].resource_kind) == "mmo" and str(animations[0].role) == "animation_source",
		"the surface-8 mmo row is an animation source",
	)
	_check(str(animations[1].resource_name) == "X01.AX" and str(animations[1].resource_kind) == "ax", "the ax row is an animation source")

	var pictures: Array = step.pictures
	_check(pictures.size() == 7, "every mmo row except the surface-8 one is a picture")
	_check(
		str(pictures[0].resource_name) == "X.MMO" and str(pictures[0].role) == "standing"
		and str(pictures[0].layer) == "foreground" and int(pictures[0].surface) == 2,
		"surface 2 loaded from a *_PIC.MES script is a standing picture (foreground)",
	)
	_check(
		str(pictures[1].resource_name) == "X01.MMO" and str(pictures[1].role) == "base"
		and str(pictures[1].layer) == "background" and int(pictures[1].surface) == 2,
		"surface 2 loaded from any other script is the base picture (background)",
	)
	_check(str(pictures[2].role) == "base" and str(pictures[2].layer) == "background" and int(pictures[2].surface) == 1, "surface 1 is the base picture")
	_check(str(pictures[3].role) == "base" and str(pictures[3].layer) == "background" and int(pictures[3].surface) == 9, "surface 9 is the base picture")
	_check(
		str(pictures[4].resource_name) == "X01D.MMO" and str(pictures[4].role) == "unclassified"
		and str(pictures[4].layer) == "background" and int(pictures[4].surface) == -1,
		"a row with no surface value keeps the old file-name rule (background) and is unclassified",
	)
	_check(
		str(pictures[5].resource_name) == "Y.MMO" and str(pictures[5].role) == "unclassified"
		and str(pictures[5].layer) == "foreground",
		"a row with no surface value from a *_PIC.MES script keeps the old file-name rule (foreground)",
	)

	_check(str(step.visible.background) == "X01D.MMO", "the last background writer wins the cumulative visible state")
	_check(str(step.visible.foreground) == "Y.MMO", "the last foreground writer wins the cumulative visible state")

	var unclassified_pictures: Array = built.unclassified_pictures
	_check(
		unclassified_pictures.size() == 2,
		"the two distinct missing-surface pictures are listed once each for Analysis evidence, even though Y.MMO repeats",
	)


## EP-14: a media row a shared library routine executed, as the probe's
## `library_media` carries it - `source_entry` `LIBLARY.LIB`, its own library
## offset, the `library_call` naming the caller record, and the `trace_index`
## of the route row it is anchored to.
func _library_row(effect: String, offset: int, trace_index: int, extra: Dictionary = {}) -> Dictionary:
	var row := _row("LIBLARY.LIB", offset, effect, extra)
	row["trace_index"] = trace_index
	row["library_call"] = {"routine": 27, "caller_entry": "CALLER.MES", "caller_offset": 0x40, "caller_definition_id": -1}
	return row


## EP-14 placement: library media are applied at the end of their anchor row's
## iteration. A library picture (surface 2, `LIBLARY.LIB`) is a base picture
## of the step and updates `visible.background` at that point, so a later route
## picture of the same step still wins and a library picture after a route
## picture wins over it. A library effect lands in `step.effects` with its
## `source_offset` and `library_call`.
func _check_library_media_placement() -> void:
	var trace := [
		_row("CALLER.MES", 0x04, "mmo_resource_marker", {"resource_name": "R1.MMO", "native_active_surface_value": 2}),
		_row("CALLER.MES", 0x08, "shared_routine_boundary"),
		_row("CALLER.MES", 0x10, "mmo_resource_marker", {"resource_name": "R2.MMO", "native_active_surface_value": 2}),
		_row("CALLER.MES", 0x14, "literal_text_insert"),
		_row("CALLER.MES", 0x18, "dialogue_boundary"),
		_row("CALLER.MES", 0x1C, "mmo_resource_marker", {"resource_name": "R3.MMO", "native_active_surface_value": 2}),
		_row("CALLER.MES", 0x20, "shared_routine_boundary"),
		_row("CALLER.MES", 0x24, "literal_text_insert"),
		_row("CALLER.MES", 0x28, "dialogue_boundary"),
		_row("CALLER.MES", 0x2C, "script_return"),
	]
	var messages := [
		_message("CALLER.MES", 0x15, {"dynamic_kind": "literal_record"}),
		_message("CALLER.MES", 0x25, {"dynamic_kind": "literal_record"}),
	]
	var library_media := [
		_library_row("mmo_resource_marker", 0x100, 1, {"resource_name": "LIB1.MMO", "native_active_surface_value": 2}),
		_library_row("effect_request", 0x120, 1, {"resource_name": "LIB_SE.WAV", "resource_archive": "se.arc", "channel_index": 0}),
		_library_row("mmo_resource_marker", 0x140, 6, {"resource_name": "LIB2.MMO", "native_active_surface_value": 2}),
	]
	var built: Dictionary = TimelineScript.build(trace, messages, {}, library_media)
	_check(built.get("ok", false), "a run with library media builds ok")
	var steps: Array = built.steps
	_check(steps.size() == 3, "two dialogue-boundary-closed steps plus the closing step, library media or not")

	var step0: Dictionary = steps[0]
	var pictures0: Array = step0.pictures
	_check(
		pictures0.map(func(picture: Dictionary) -> String: return str(picture.resource_name)) == ["R1.MMO", "LIB1.MMO", "R2.MMO"],
		"a library picture is applied at its anchor row, between the route pictures around it",
	)
	_check(
		str(pictures0[1].role) == "base" and str(pictures0[1].layer) == "background" and int(pictures0[1].surface) == 2
		and str(pictures0[1].source_entry) == "LIBLARY.LIB" and int(pictures0[1].source_offset) == 0x100
		and pictures0[1].library_call == {"routine": 27, "caller_entry": "CALLER.MES", "caller_offset": 0x40, "caller_definition_id": -1},
		"a surface-2 library picture from LIBLARY.LIB is a base picture, with its own offset and the caller coordinate",
	)
	_check(
		int(pictures0[0].source_offset) == 0x04 and not pictures0[0].has("library_call")
		and int(pictures0[2].source_offset) == 0x10 and not pictures0[2].has("library_call"),
		"a route picture carries its own source_offset and no library_call",
	)
	_check(str(step0.visible.background) == "R2.MMO", "a later route picture in the same step still wins the visible background")
	var effects0: Array = step0.effects
	_check(
		effects0.size() == 1 and str(effects0[0].resource_name) == "LIB_SE.WAV" and str(effects0[0].resource_archive) == "se.arc"
		and int(effects0[0].channel) == 0 and str(effects0[0].source_entry) == "LIBLARY.LIB" and int(effects0[0].source_offset) == 0x120
		and effects0[0].library_call == {"routine": 27, "caller_entry": "CALLER.MES", "caller_offset": 0x40, "caller_definition_id": -1},
		"a library effect lands in the step's effects with its source_entry, source_offset and library_call",
	)

	var step1: Dictionary = steps[1]
	_check(
		(step1.pictures as Array).map(func(picture: Dictionary) -> String: return str(picture.resource_name)) == ["R3.MMO", "LIB2.MMO"],
		"a library picture after a route picture of the same step follows it",
	)
	_check(str(step1.visible.background) == "LIB2.MMO", "the library picture, applied last, is the visible background of its step")
	_check(
		bool(steps[2].get("closing", false)) and str(steps[2].visible.background) == "LIB2.MMO",
		"the closing step carries the library picture forward",
	)


## EP-14: a library row anchored at a `dialogue_boundary` row belongs to the
## step that boundary opens. When that boundary is the trace's last row the
## media still form a closing step (`"closing": true`) instead of being
## dropped, and the step count stays the boundary count plus one - the
## validator's step-count pin.
func _check_library_media_at_dialogue_boundaries() -> void:
	var trace := [
		_row("CALLER.MES", 0x00, "literal_text_insert"),
		_row("CALLER.MES", 0x04, "dialogue_boundary"),
		_row("CALLER.MES", 0x08, "literal_text_insert"),
		_row("CALLER.MES", 0x0C, "dialogue_boundary"),
		_row("CALLER.MES", 0x10, "script_return"),
	]
	var messages := [
		_message("CALLER.MES", 0x01, {"dynamic_kind": "literal_record"}),
		_message("CALLER.MES", 0x09, {"dynamic_kind": "literal_record"}),
	]
	var library_media := [
		_library_row("mmo_resource_marker", 0x200, 1, {"resource_name": "AT_BOUNDARY.MMO", "native_active_surface_value": 2}),
		_library_row("effect_request", 0x220, 1, {"resource_name": "AT_BOUNDARY.WAV", "resource_archive": "se.arc", "channel_index": 1}),
	]
	var built: Dictionary = TimelineScript.build(trace, messages, {}, library_media)
	_check(built.get("ok", false), "media anchored at a dialogue_boundary row build ok")
	var steps: Array = built.steps
	_check(steps.size() == 3, "an anchor at a boundary row adds no step")
	_check((steps[0].pictures as Array).is_empty() and (steps[0].effects as Array).is_empty(), "media anchored at a boundary row are not in the step the boundary closes")
	_check(
		(steps[1].pictures as Array).size() == 1 and str(steps[1].pictures[0].resource_name) == "AT_BOUNDARY.MMO"
		and (steps[1].effects as Array).size() == 1 and str(steps[1].effects[0].resource_name) == "AT_BOUNDARY.WAV",
		"media anchored at a boundary row are in the next step",
	)
	_check(str(steps[1].visible.background) == "AT_BOUNDARY.MMO" and str(steps[0].visible.background) == "", "the next step's visible state shows the library picture, the closed step's does not")

	# A trailing boundary: the media have no route row after them, yet are kept.
	var trailing_trace := [
		_row("CALLER.MES", 0x00, "literal_text_insert"),
		_row("CALLER.MES", 0x04, "dialogue_boundary"),
	]
	var trailing_messages := [_message("CALLER.MES", 0x01, {"dynamic_kind": "literal_record"})]
	var without: Dictionary = TimelineScript.build(trailing_trace, trailing_messages, {})
	_check((without.steps as Array).size() == 1 and not (without.steps[0] as Dictionary).has("closing"), "a trailing boundary alone opens no closing step")
	var trailing_media := [
		_library_row("mmo_resource_marker", 0x240, 1, {"resource_name": "TRAILING.MMO", "native_active_surface_value": 2}),
		_library_row("effect_request", 0x260, 1, {"resource_name": "TRAILING.WAV", "resource_archive": "se.arc", "channel_index": 0}),
	]
	var kept: Dictionary = TimelineScript.build(trailing_trace, trailing_messages, {}, trailing_media)
	_check(kept.get("ok", false), "media anchored at a trailing boundary build ok")
	var kept_steps: Array = kept.steps
	var boundary_count := trailing_trace.filter(func(row: Dictionary) -> bool: return str(row.effect) == "dialogue_boundary").size()
	_check(
		kept_steps.size() == 2 and kept_steps.size() == boundary_count + 1
		and bool(kept_steps[1].get("closing", false)) and not bool(kept_steps[0].get("closing", false)),
		"media after a trailing boundary form a closing step: the step count is the boundary count plus one",
	)
	_check(
		kept_steps.size() == 2 and (kept_steps[1].messages as Array).is_empty() and not (kept_steps[1] as Dictionary).has("message")
		and (kept_steps[1].pictures as Array).size() == 1 and str(kept_steps[1].pictures[0].resource_name) == "TRAILING.MMO"
		and (kept_steps[1].effects as Array).size() == 1 and str(kept_steps[1].effects[0].resource_name) == "TRAILING.WAV"
		and str(kept_steps[1].visible.background) == "TRAILING.MMO",
		"the closing step holds the trailing media and no message",
	)


## EP-14: `build` refuses a `library_media` list it cannot merge, whole and
## with a reason, before it builds anything.
func _check_library_media_refusals() -> void:
	var trace := [
		_row("CALLER.MES", 0x00, "shared_routine_boundary"),
		_row("CALLER.MES", 0x04, "shared_routine_boundary"),
		_row("CALLER.MES", 0x08, "script_return"),
	]
	var valid := _library_row("effect_request", 0x100, 1, {"resource_name": "OK.WAV", "resource_archive": "se.arc", "channel_index": 0})
	_check(TimelineScript.build(trace, [], {}, [valid]).get("ok", false), "the refusal fixtures' valid row builds ok")
	var cases := {
		"a non-Dictionary element": [valid, "not a row"],
		"a missing trace_index": [{"effect": "effect_request", "source_entry": "LIBLARY.LIB"}],
		"a non-int trace_index (float)": [_library_row("effect_request", 0x100, 1).merged({"trace_index": 1.0}, true)],
		"a non-int trace_index (string)": [_library_row("effect_request", 0x100, 1).merged({"trace_index": "1"}, true)],
		"an index past the trace": [_library_row("effect_request", 0x100, trace.size())],
		"a negative index": [_library_row("effect_request", 0x100, -1)],
		"a decreasing index": [_library_row("effect_request", 0x100, 2), _library_row("effect_request", 0x120, 1)],
		"an effect outside MEDIA_EFFECTS": [_library_row("literal_text_insert", 0x100, 1)],
		"a missing effect": [_library_row("effect_request", 0x100, 1).merged({"effect": ""}, true)],
	}
	for label in cases:
		var refused: Dictionary = TimelineScript.build(trace, [], {}, cases[label])
		_check(not refused.get("ok", true) and not str(refused.get("error", "")).is_empty() and not refused.has("steps"), "%s is refused with a reason" % label)
	var empty_trace: Dictionary = TimelineScript.build([], [], {}, [valid])
	_check(not empty_trace.get("ok", true), "library media cannot anchor to an empty trace")
	var non_decreasing: Dictionary = TimelineScript.build(trace, [], {}, [_library_row("effect_request", 0x100, 1), _library_row("effect_request", 0x120, 1)])
	_check(non_decreasing.get("ok", false), "two media at the same index are non-decreasing")


## EP-14: without the fourth argument `build` returns what it returned before,
## apart from the `source_offset` every `pictures`, `animations` and `effects`
## entry now carries; `voice` and `bgm` entries keep their shapes.
func _check_build_without_library_media() -> void:
	var trace := [
		_row("CALLER.MES", 0x00, "voice_marker", {"resource_name": "V1"}),
		_row("CALLER.MES", 0x04, "bgm_request", {"resource_name": "B1", "bgm_selector": 3}),
		_row("CALLER.MES", 0x08, "mmo_resource_marker", {"resource_name": "P1.MMO", "native_active_surface_value": 1}),
		_row("CALLER.MES", 0x0C, "mmo_resource_marker", {"resource_name": "A1.MMO", "native_active_surface_value": 8}),
		_row("CALLER.MES", 0x10, "ax_resource_marker", {"resource_name": "A2.AX"}),
		_row("CALLER.MES", 0x14, "effect_request", {"resource_name": "E1.WAV", "resource_archive": "se.arc", "channel_index": 4}),
		_row("CALLER.MES", 0x18, "script_return"),
	]
	var plain: Dictionary = TimelineScript.build(trace, [], {})
	var empty_list: Dictionary = TimelineScript.build(trace, [], {}, [])
	_check(plain == empty_list, "an empty library_media list builds exactly what the three-argument call builds")
	var step: Dictionary = plain.steps[0]
	_check(step.voice == "V1" and step.bgm == [{"resource_name": "B1", "selector": 3}], "voice and bgm entries keep their shapes")
	_check(
		step.pictures == [{"resource_name": "P1.MMO", "source_entry": "CALLER.MES", "layer": "background", "surface": 1, "role": "base", "source_offset": 0x08}],
		"a route picture entry is what it was plus its source_offset",
	)
	_check(
		step.animations == [
			{"resource_name": "A1.MMO", "source_entry": "CALLER.MES", "surface": 8, "resource_kind": "mmo", "role": "animation_source", "source_offset": 0x0C},
			{"resource_name": "A2.AX", "source_entry": "CALLER.MES", "surface": -1, "resource_kind": "ax", "role": "animation_source", "source_offset": 0x10},
		],
		"route animation entries are what they were plus their source_offset",
	)
	_check(
		step.effects == [{"resource_name": "E1.WAV", "resource_archive": "se.arc", "channel": 4, "source_entry": "CALLER.MES", "source_offset": 0x14}],
		"a route effect entry is what it was plus its source_entry and source_offset, and has no library_call",
	)


## EP-14: library rows are not trace rows - they never consume a message and
## never change the step count, the closing flag or the message grouping.
func _check_library_media_leave_messages_and_steps() -> void:
	var trace := [
		_row("CALLER.MES", 0x00, "shared_routine_boundary"),
		_row("CALLER.MES", 0x04, "literal_text_insert"),
		_row("CALLER.MES", 0x08, "dialogue_boundary"),
		_row("CALLER.MES", 0x0C, "shared_routine_boundary"),
		_row("CALLER.MES", 0x10, "message"),
		_row("CALLER.MES", 0x14, "dialogue_boundary"),
		_row("CALLER.MES", 0x18, "script_return"),
	]
	var messages := [
		_message("CALLER.MES", 0x05, {"dynamic_kind": "literal_record"}),
		_message("CALLER.MES", 0x11, {"dynamic_kind": "literal_record"}),
	]
	var library_media := [
		_library_row("voice_marker", 0x100, 0, {"resource_name": "LV.WAV"}),
		_library_row("bgm_request", 0x110, 0, {"resource_name": "LB", "bgm_selector": 2}),
		_library_row("effect_request", 0x120, 2, {"resource_name": "LE.WAV", "resource_archive": "se.arc", "channel_index": 0}),
		_library_row("mmo_resource_marker", 0x130, 3, {"resource_name": "L.MMO", "native_active_surface_value": 2}),
		_library_row("ax_resource_marker", 0x140, 5, {"resource_name": "L.AX"}),
	]
	var plain: Dictionary = TimelineScript.build(trace, messages, {})
	var merged: Dictionary = TimelineScript.build(trace, messages, {}, library_media)
	_check(merged.get("ok", false), "a mixed library list builds ok")
	var plain_steps: Array = plain.steps
	var merged_steps: Array = merged.steps
	_check(merged_steps.size() == plain_steps.size(), "library media never change the step count")
	var same_messages := true
	var same_closing := true
	for index in range(plain_steps.size()):
		same_messages = same_messages and merged_steps[index].messages == plain_steps[index].messages
		same_closing = same_closing and bool(merged_steps[index].get("closing", false)) == bool(plain_steps[index].get("closing", false))
	_check(same_messages, "library media never move the message cursor: every step keeps its messages")
	_check(same_closing, "library media never change which step is the closing step")
	_check(
		str(merged_steps[0].voice) == "LV.WAV" and (merged_steps[0].bgm as Array).size() == 1
		and str(merged_steps[0].bgm[0].resource_name) == "LB" and int(merged_steps[0].bgm[0].selector) == 2
		and (merged_steps[0].effects as Array).is_empty(),
		"a library voice and BGM request reach the step of their anchor row",
	)
	_check(
		(merged_steps[1].effects as Array).size() == 1 and str(merged_steps[1].effects[0].resource_name) == "LE.WAV"
		and (merged_steps[1].pictures as Array).size() == 1 and (merged_steps[1].animations as Array).is_empty()
		and (merged_steps[2].animations as Array).size() == 1 and str(merged_steps[2].animations[0].resource_kind) == "ax"
		and merged_steps[2].animations[0].library_call.caller_offset == 0x40,
		"media anchored at a boundary row open the next step, and the AX animation source carries its library_call",
	)
