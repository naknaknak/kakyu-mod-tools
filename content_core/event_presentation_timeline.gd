class_name KakyuEventPresentationTimeline
extends RefCounted

# EP-10 unit 4: a pure, static module that turns a finished
# `KakyuMesRouteProbe.run_route` result (its `trace` and `messages`) into a
# line-indexed presentation timeline.
#
# EP-13 part B (owner findings, 2026-09-24): a step is the run of message
# records between two `dialogue_boundary` trace rows (the click waits), not
# one record. Every `literal_text_insert`, `protagonist_name_insert` and
# `message` trace row is, by construction, emitted in the runner's own
# execution order together with exactly one entry appended to `messages` at
# that same instant (see the module footer), so walking `trace` in order and
# taking the next queued message whenever one of those three effects is seen
# groups messages correctly - including a `literal_text_insert` row, whose
# message carries its nested text record's own offset, not the enclosing
# instruction's, so it cannot be found by matching `(source_entry,
# source_offset)` back onto the trace row that produced it; only encounter
# order is reliable. A `dialogue_boundary` row closes the step in progress
# (even an empty one - a run with no message between two boundaries is still
# counted) and opens the next. Rows after the last `dialogue_boundary` form a
# closing step, exactly when there are any - `"closing": true`, with no
# `"message"` key unless trailing message records were themselves collected
# into it.
#
# Every step carries `"visible": {"background", "foreground"}` - the picture
# state in effect after the step, carried forward from the previous step and
# updated by the step's own pictures in trace order, so a step with no
# picture rows keeps what was last shown and a foreground followed by a
# background (or vice versa) in one step does not wipe the other layer.
#
# EP-13 part A (owner findings, 2026-09-24): every `mmo_resource_marker` row
# that carries `native_active_surface_value` (`banked_u16[0][1]`, confirmed
# semantics) is classified by that surface, not by the loading script's file
# name: surface 8 is an animation source (never a picture - joins
# `step.animations` with `ax_resource_marker` rows); surface 2 loaded from a
# `*_PIC.MES` script is a standing picture (`visible.foreground`); surface 1,
# surface 9, or surface 2 from any other script is the base picture
# (`visible.background`). A row with no `native_active_surface_value` keeps
# the old file-name rule and is additionally listed in
# `unclassified_pictures` so it shows in the Analysis evidence. An
# unrecognized surface value (none measured in the corpus) falls back to the
# same file-name rule and the same `unclassified_pictures` list. Every
# `pictures` entry carries `surface` and `role` (`"base"`, `"standing"`, or
# `"unclassified"`); every `animations` entry carries `surface`, `role`
# (`"animation_source"`) and `resource_kind` (`"mmo"` or `"ax"`, the field
# `mes_event_runner.gd` already writes, so a caller can pick the right
# archive - AX resources resolve in `data.arc`, MMO animation atlases in
# `mmo.arc`).
#
# This module reads only the fields the runner writes today: `effect`,
# `resource_name`, `bgm_selector`, `resource_archive`, `channel_index`,
# `source_entry`, `source_offset`, `native_active_surface_value`,
# `resource_kind` (see `content_core/mes_event_runner.gd` for the exact keys
# of `bgm_request`, `voice_marker`, `mmo_resource_marker`,
# `ax_resource_marker` and `effect_request`).
#
# EP-14 (Core 0.378.0): `build`'s optional fourth argument, `library_media`, is
# the probe result's list of the media rows a shared `LIBLARY.LIB` routine
# executed (`KakyuMesRouteProbe` `_collect_library`; the flow runner's combined
# list for a v14 route). They are not trace rows. Each is anchored by its
# `trace_index` to the route row after which the library ran, and is applied -
# through the same `_apply_row`, so a library picture is classified by its own
# `native_active_surface_value` and `source_entry` like any other - at the end
# of that row's iteration: after the anchor row's own handling, or, when the
# anchor is a `dialogue_boundary`, into the step that boundary opens. A library
# row never consumes a message and never counts toward the rows of a step; a
# trailing `dialogue_boundary` with library media anchored at it still forms
# the closing step (`"closing": true`), so the media are not dropped. The list
# is validated first and `build` refuses it whole (`{"ok": false, "error"}`):
# every element a Dictionary with an int `trace_index` inside `trace`,
# non-decreasing, and an `effect` in `KakyuMesRouteProbe.MEDIA_EFFECTS`.
# Every `pictures`, `animations` and `effects` entry now also carries its row's
# own `source_offset`, an `effects` entry its row's `source_entry` as the other two
# already did (so the three kinds are uniform and a consumer can read a medium's
# exact `(source_entry, source_offset)` coordinate), and an entry built from a
# library row carries its `library_call` (`{routine, caller_entry, caller_offset,
# caller_definition_id}`, the MES-anchored caller coordinate); `voice` (a string)
# and `bgm` entries keep their shapes. Without the argument `build` returns what it
# returned before, apart from the `source_offset` and effect `source_entry` fields.
#
# Tool decisions (not claims about the original): a library picture is
# presented as a still at the step of the call, by the EP-13 rule above, and a
# library sound effect fires at the step of the call. The original's screen
# refresh, surface lifetime and sound-effect cadence are unresolved
# (`todo/presentation_audio.md`), so a background may show earlier than the
# original redraws it, and `event_player.gd`'s one effect channel is restarted by
# every request, so several effects in one step are heard as the last one.

# Every other structural trace effect `mes_event_runner.gd` emits today: not
# a presentation producer and not a native-presentation omission, so a row
# carrying one of these names is simply not part of the timeline. A new
# runner effect absent from both this list and the omitted patterns below
# falls into `unclassified` instead of being silently dropped.
const IGNORED_EFFECTS := {
	"address_table_dispatch": true,
	"address_table_dispatch_boundary": true,
	"argument_slot_assignment": true,
	"argument_slot_write_run": true,
	"ax_presentation_binding": true,
	"banked_u8_write_run": true,
	"banked_u16_write_run": true,
	"banked_i32_write_run": true,
	"bootstrap_transfer": true,
	"branch": true,
	"continuation": true,
	"def_register_skip": true,
	"def_selection_boundary": true,
	"definition_invoke_boundary": true,
	"dialogue_boundary": true,
	"dynamic_global_u8_write_run": true,
	"fallthrough": true,
	"global_i32_write_run": true,
	"global_u8_write_run": true,
	"inline_script_execution_boundary": true,
	"internal_record_push": true,
	"internal_vector_clear": true,
	"invalid_address_table_index": true,
	"invalid_address_table_target": true,
	"literal_text_insert": true,
	"map_location_supplied": true,
	"message": true,
	"message_cursor_no_advance": true,
	"message_record_id": true,
	"native_record_boundary": true,
	"native_selection_boundary": true,
	"native_state_transfer_boundary": true,
	"protagonist_name_insert": true,
	"script_dispatch_boundary": true,
	"script_handoff_boundary": true,
	"script_return": true,
	"shared_routine_boundary": true,
	"source_line_marker": true,
	"state_u16_write_run": true,
	"statement_separator": true,
	"unsupported_stop": true,
}

const NATIVE_PRESENTATION_PREFIX := "native_presentation_"
const OMITTED_SUFFIX := "_omitted"

const SURFACE_ANIMATION := 8
const PIC_SUFFIX := "_PIC.MES"

# The three trace effects that each carry exactly one queued `messages` entry
# appended at the same instant (see the module header and
# `mes_event_runner.gd` `_apply_text_insert`, its `0x01` message-record
# branch, and its `dispatcher_character_text` branch). Consuming `messages`
# in encounter order against these three - not by matching offsets - is what
# makes grouping correct for `literal_text_insert`, whose message does not
# share its enclosing trace row's offset.
const MESSAGE_PRODUCING_EFFECTS := {
	"message": true,
	"literal_text_insert": true,
	"protagonist_name_insert": true,
}


static func build(trace: Array, messages: Array, _terminal_match: Dictionary, library_media: Array = []) -> Dictionary:
	var refusal := _library_media_refusal(library_media, trace.size())
	if not refusal.is_empty():
		return {"ok": false, "error": refusal}
	var omitted := {}
	var unclassified: Array = []
	var seen_unclassified := {}
	var unclassified_pictures: Array = []
	var seen_unclassified_pictures := {}
	var steps: Array = []
	var step_index := 0
	var current := _new_step(step_index)
	var current_messages: Array = []
	var message_cursor := 0
	var rows_since_boundary := 0
	# EP-14: the library media rows applied to the step in progress. Kept apart
	# from `rows_since_boundary` (they are not trace rows) so that media applied
	# into the step a trailing `dialogue_boundary` opened still make a closing step.
	var library_media_in_open_step := 0
	var library_cursor := 0
	# Round 2 (owner, 2026-09-20): picture state is cumulative, not per-step -
	# `visible` carries the background/foreground names forward across steps
	# so a step with no picture rows keeps whatever was last shown, and a
	# foreground followed later by a background (or vice versa) in the same
	# step does not wipe the other layer.
	var visible := {"background": "", "foreground": ""}

	for row_index in range(trace.size()):
		var row: Dictionary = trace[row_index]
		rows_since_boundary += 1
		var effect := str(row.get("effect", ""))
		if MESSAGE_PRODUCING_EFFECTS.has(effect) and message_cursor < messages.size():
			current_messages.append(messages[message_cursor])
			message_cursor += 1
		if effect == "dialogue_boundary":
			_finalize_step(current, current_messages, visible, steps)
			step_index += 1
			current = _new_step(step_index)
			current_messages = []
			rows_since_boundary = 0
			library_media_in_open_step = 0
		else:
			_apply_row(
				row, current, visible, omitted, unclassified, seen_unclassified,
				unclassified_pictures, seen_unclassified_pictures,
			)
		# EP-14: the library media anchored at this row, after the row's own
		# handling - into the step a `dialogue_boundary` anchor just opened.
		while library_cursor < library_media.size() and int((library_media[library_cursor] as Dictionary).trace_index) == row_index:
			_apply_row(
				library_media[library_cursor], current, visible, omitted, unclassified, seen_unclassified,
				unclassified_pictures, seen_unclassified_pictures,
			)
			library_media_in_open_step += 1
			library_cursor += 1

	if rows_since_boundary > 0 or not current_messages.is_empty() or library_media_in_open_step > 0:
		current["closing"] = true
		_finalize_step(current, current_messages, visible, steps)

	return {
		"ok": true,
		"steps": steps,
		"omitted": omitted,
		"unclassified": unclassified,
		"unclassified_pictures": unclassified_pictures,
	}


## The first reason a `library_media` list cannot be merged, or `""` when it can:
## every element a Dictionary with an int `trace_index` in `[0, trace_size)`
## that never decreases, and an `effect` in `KakyuMesRouteProbe.MEDIA_EFFECTS`.
static func _library_media_refusal(library_media: Array, trace_size: int) -> String:
	var previous_index := 0
	for position in range(library_media.size()):
		if not library_media[position] is Dictionary:
			return "library media %d is not a Dictionary" % position
		var media: Dictionary = library_media[position]
		if not media.has("trace_index") or typeof(media.trace_index) != TYPE_INT:
			return "library media %d has no integer trace_index" % position
		var trace_index: int = media.trace_index
		if trace_index < 0 or trace_index >= trace_size:
			return "library media %d trace_index %d is outside the trace of %d rows" % [position, trace_index, trace_size]
		if trace_index < previous_index:
			return "library media %d trace_index %d decreases from %d" % [position, trace_index, previous_index]
		previous_index = trace_index
		if not KakyuMesRouteProbe.MEDIA_EFFECTS.has(str(media.get("effect", ""))):
			return "library media %d effect '%s' is not a media effect" % [position, str(media.get("effect", ""))]
	return ""


static func _new_step(index: int) -> Dictionary:
	return {
		"index": index,
		"messages": [],
		"voice": "",
		"bgm": [],
		"pictures": [],
		"animations": [],
		"effects": [],
	}


## Assigns the step's index-ordered `messages`, its compatibility `message`
## (the first record, when there is one - callers that never learned about
## `messages` keep working), `source_entry`/`source_offset` (the first
## record's), and its cumulative `visible` snapshot; then appends it.
static func _finalize_step(step: Dictionary, collected_messages: Array, visible: Dictionary, steps: Array) -> void:
	var messages_copy: Array = collected_messages.duplicate()
	step["messages"] = messages_copy
	if not messages_copy.is_empty():
		var first: Dictionary = messages_copy[0]
		step["message"] = first
		step["source_entry"] = str(first.get("source_entry", ""))
		step["source_offset"] = int(first.get("source_offset", -1))
	step["visible"] = visible.duplicate()
	steps.append(step)


## Classifies one `mmo_resource_marker` row by its confirmed
## `native_active_surface_value` (see the module header). Returns
## `{"kind": "animation" | "standing" | "base" | "unclassified", "surface":
## int, "layer": "background" | "foreground"}` (`"layer"` is absent for
## `"animation"`, which is never a picture).
static func _classify_picture(row: Dictionary) -> Dictionary:
	var source_entry := str(row.get("source_entry", ""))
	var old_rule_layer := "foreground" if source_entry.to_upper().ends_with(PIC_SUFFIX) else "background"
	if not row.has("native_active_surface_value"):
		return {"kind": "unclassified", "surface": -1, "layer": old_rule_layer}
	var surface := int(row.get("native_active_surface_value"))
	if surface == SURFACE_ANIMATION:
		return {"kind": "animation", "surface": surface}
	if surface == 2 and source_entry.to_upper().ends_with(PIC_SUFFIX):
		return {"kind": "standing", "surface": surface, "layer": "foreground"}
	if surface == 1 or surface == 2 or surface == 9:
		return {"kind": "base", "surface": surface, "layer": "background"}
	# No other surface value is measured in the corpus; fall back to the old
	# file-name rule and the unclassified evidence list rather than guessing.
	return {"kind": "unclassified", "surface": surface, "layer": old_rule_layer}


## EP-14: a `pictures`, `animations` or `effects` entry carries the row's own
## `source_offset`, and its `library_call` when the row came from a shared
## library routine (`library_media`).
static func _with_provenance(entry: Dictionary, row: Dictionary) -> Dictionary:
	entry["source_offset"] = int(row.get("source_offset", -1))
	if row.has("library_call"):
		entry["library_call"] = (row.library_call as Dictionary).duplicate(true)
	return entry


static func _apply_row(
	untyped_row,
	step: Dictionary,
	visible: Dictionary,
	omitted: Dictionary,
	unclassified: Array,
	seen_unclassified: Dictionary,
	unclassified_pictures: Array,
	seen_unclassified_pictures: Dictionary,
) -> void:
	var row: Dictionary = untyped_row
	var effect := str(row.get("effect", ""))
	if effect.is_empty():
		return
	match effect:
		"voice_marker":
			step["voice"] = str(row.get("resource_name", ""))
			return
		"bgm_request":
			(step["bgm"] as Array).append({
				"resource_name": str(row.get("resource_name", "")),
				"selector": int(row.get("bgm_selector", -1)),
			})
			return
		"mmo_resource_marker":
			var source_entry := str(row.get("source_entry", ""))
			var resource_name := str(row.get("resource_name", ""))
			var classification := _classify_picture(row)
			var kind := str(classification.kind)
			if kind == "animation":
				(step["animations"] as Array).append(_with_provenance({
					"resource_name": resource_name,
					"source_entry": source_entry,
					"surface": int(classification.surface),
					"resource_kind": "mmo",
					"role": "animation_source",
				}, row))
				return
			var layer := str(classification.layer)
			(step["pictures"] as Array).append(_with_provenance({
				"resource_name": resource_name,
				"source_entry": source_entry,
				"layer": layer,
				"surface": int(classification.surface),
				"role": kind,
			}, row))
			visible[layer] = resource_name
			if kind == "unclassified":
				var picture_key := "%s:%s" % [source_entry, resource_name]
				if not seen_unclassified_pictures.has(picture_key):
					seen_unclassified_pictures[picture_key] = true
					unclassified_pictures.append({
						"resource_name": resource_name,
						"source_entry": source_entry,
						"surface": int(classification.surface),
					})
			return
		"ax_resource_marker":
			(step["animations"] as Array).append(_with_provenance({
				"resource_name": str(row.get("resource_name", "")),
				"source_entry": str(row.get("source_entry", "")),
				"surface": -1,
				"resource_kind": "ax",
				"role": "animation_source",
			}, row))
			return
		"effect_request":
			(step["effects"] as Array).append(_with_provenance({
				"resource_name": str(row.get("resource_name", "")),
				"resource_archive": str(row.get("resource_archive", "")),
				"channel": int(row.get("channel_index", -1)),
				"source_entry": str(row.get("source_entry", "")),
			}, row))
			return
	if effect.ends_with(OMITTED_SUFFIX) or effect.begins_with(NATIVE_PRESENTATION_PREFIX):
		omitted[effect] = int(omitted.get(effect, 0)) + 1
		return
	if IGNORED_EFFECTS.has(effect):
		return
	if not seen_unclassified.has(effect):
		seen_unclassified[effect] = true
		unclassified.append(effect)
