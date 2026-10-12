extends SceneTree

## EP-10 unit 2: every promoted analysis-group catalog row runs through the
## Event Player's shared call frame exactly as `catalog_analysis_run.gd`'s
## `run_group_route` describes. Modeled on `validate_catalog_analysis_routes.gd`.

const Player := preload("res://tools/content_suite/apps/event_player.tscn")
const GuardForm := preload("res://content_core/event_guard_form.gd")
const ContainerScript := preload("res://content_core/mes_container.gd")
const SandboxStateScript := preload("res://content_core/mes_sandbox_state.gd")
const KnownAbsentMediaScript := preload("res://tools/content_suite/known_absent_media.gd")
const DeclaredMediaScript := preload("res://tools/content_suite/declared_media.gd")

## EP-10 unit 3: three promoted rows with a typed guard, used to exercise
## the guard-derived starting-state form end to end.
const GUARD_FORM_EVENT_IDS := [
	"original/eventk15/k_date3-000043da",
	"original/eventa01/27c3b-00000697",
	"original/eventa02/17m-00005a33",
]

var failures: Array[String] = []
var checks := 0
var run_count := 0
var unmeasured_options := 0
var outcome_counts: Dictionary = {}
var guard_in_bounds_runs := 0
var guard_out_of_bounds_refusals := 0
var playback_runs := 0
# Album-scene (`gallery`) rows whose status line was asserted; the shards sum to every album row.
var gallery_rows_checked := 0
var playback_pictures_found := 0
var playback_pictures_missing := 0
# EP-13 part A: pictures counted by role (`base`/`standing`/`unclassified` -
# an `animation_source` mmo row never reaches `step.pictures`, see
# `playback_animation_sources_*` below).
var playback_pictures_by_role_found: Dictionary = {}
var playback_pictures_by_role_missing: Dictionary = {}
var playback_animation_sources_found := 0
var playback_animation_sources_missing := 0
var playback_voices_found := 0
var playback_voices_missing := 0
var playback_bgm_found := 0
var playback_bgm_missing := 0
var playback_effects_found := 0
var playback_effects_missing := 0
var playback_unknown_effects: Dictionary = {}
# WD-21 U1 gate 2: a Playback-pass miss must be a registered absence
# (`config/event_catalog/known_absent_media_v1.json`). `known_absent_register` is
# the loaded register (`{}` when it could not be loaded, which is itself a failure
# and leaves every miss unregistered); the two counters split the misses.
var known_absent_register: Dictionary = {}
var playback_misses_registered := 0
var playback_misses_unregistered := 0
var playback_pictures_missing_names: Array[Dictionary] = []
var playback_animation_sources_missing_names: Array[Dictionary] = []
var playback_voices_missing_names: Array[Dictionary] = []
var playback_bgm_missing_names: Array[Dictionary] = []
var playback_effects_missing_names: Array[Dictionary] = []

# WD-21 U2 C5 gate 3 (`declared_media.gd`): every medium name the played timeline uses must be
# the `entry` of one of the row's catalog `resources`. `playback_media_compared` counts the
# played names compared, `playback_undeclared` those no resource declares (each also printed as
# a `PLAYBACK_UNDECLARED_<CATEGORY>` line and failing the shard). Name-level: it includes the media a shared
# library routine presented since Core 0.378.0 (EP-14); the library coordinates are compared below.
var playback_media_compared := 0
var playback_undeclared := 0
var playback_undeclared_by_category: Dictionary = {}
var playback_undeclared_names: Array[Dictionary] = []

# EP-14 (Core 0.378.0): the timeline now presents the media a shared `LIBLARY.LIB` routine
# executes, and gate 3 sees them twice. The name-level compare above includes them (its
# `compared` number rises). `declared_media.gd`'s `compare_library` checks each played library
# medium at its exact library coordinate against the row's declared items: `playback_library_media_compared`
# counts them, `playback_library_undeclared` those no item declares there (each printed as a
# `PLAYBACK_UNDECLARED_LIBRARY_<CATEGORY>` line and failing the shard - the playback-side check of
# TD-55's `(entry, offset)` labelling, which a name-level match cannot see). `library_coverage` is the
# report that never fails: `playback_library_items_declared` counts the `LIBLARY.LIB` items of the
# rows played, `playback_library_items_presented` those a played library medium matched, by category
# in `playback_library_presented_by_category` (a row's declaration is the union over every measured
# variant, the Playback pass plays one preset per row). `playback_library_media_rows` is this
# validator's own record of each played library medium and the MES-anchored caller coordinate that ran it.
var playback_library_media_compared := 0
var playback_library_undeclared := 0
var playback_library_undeclared_names: Array[Dictionary] = []
var playback_library_media_by_category: Dictionary = {}
var playback_library_items_declared := 0
var playback_library_items_presented := 0
var playback_library_presented_by_category: Dictionary = {}
var playback_library_media_rows: Array[Dictionary] = []

## EP-11 part 1b: every visit preset of a shard's rows, run through both the
## Analysis and Playback passes.
var visit_runs := 0

## TD-33 part 2: `shard_index`/`shard_count` are 1/1 (every row, "all") unless
## a second `shard=K/N` user argument selects one of `N` shards. `shard_label`
## is what the PASS line and JSON name the shard as; `shard_row_count` is how
## many analysis-group rows this process actually ran.
var shard_index := 1
var shard_count := 1
var shard_label := "all"
var shard_row_count := 0


func _init() -> void:
	call_deferred("_validate")


func _validate() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 1 or args.size() > 2:
		push_error("Usage: validate_catalog_group_routes.gd <ELFIMAGE-directory> [shard=K/N]")
		quit(2)
		return
	if args.size() == 2:
		var parsed_shard := _parse_shard_argument(str(args[1]))
		if parsed_shard.is_empty():
			push_error("Usage: validate_catalog_group_routes.gd <ELFIMAGE-directory> [shard=K/N] (1 <= K <= N, N >= 2)")
			quit(2)
			return
		shard_index = int(parsed_shard.k)
		shard_count = int(parsed_shard.n)
		shard_label = "%d/%d" % [shard_index, shard_count]
	var loaded_register: Dictionary = KnownAbsentMediaScript.load_register()
	if _check(loaded_register.get("ok", false), "the known-absent media register loads: %s" % str(loaded_register.get("error", ""))):
		known_absent_register = loaded_register.register
	var player: KakyuEventPlayer = Player.instantiate()
	root.add_child(player)
	await process_frame
	player.open_content_set(str(args[0]))
	var catalog: KakyuEventCatalog = player.get("_event_catalog")
	var reader: KakyuArcReader = player.get("_reader")
	var original_sha := reader.get_archive_fingerprint()
	var analyzer := preload("res://tools/content_suite/catalog_analysis_run.gd").new()
	var profiles = player.call("_ensure_event_analysis_profiles")
	# TD-33 part 2: the forged-request check only runs in shard 1 (on its
	# first row that plays); `forged_done` is already true for every other
	# shard, so the block below never fires there.
	var forged_done := shard_index != 1
	var group_index := 0
	# Round 2 code review, item 10: `analyze_catalog_request` analyzes a
	# promoted row outright - no `_set_view_mode` workaround needed.
	for event in catalog.get_events():
		if not event.has("analysis_group"):
			continue
		var this_group_index := group_index
		group_index += 1
		if not _shard_includes(this_group_index):
			continue
		shard_row_count += 1
		var event_id := str(event.event_id)
		var choices: Array = event.get("choices", [])
		var option_ids: Array[String] = []
		if choices.is_empty():
			option_ids.append("")
		else:
			for option_value in (choices[0] as Dictionary).get("options", []):
				var option: Dictionary = option_value
				# An option whose terminal_ids is empty was never measured as a
				# route; build_play_request refuses it, so skip it here rather
				# than counting it as a failure.
				if (option.get("terminal_ids", []) as Array).is_empty():
					unmeasured_options += 1
					continue
				option_ids.append(str(option.get("option_id", "")))
		for option_id in option_ids:
			var preset_id := analyzer.pick_measured_preset_id(catalog, profiles, event_id, option_id)
			if not _check(not preset_id.is_empty(), "%s option %s resolves a measured preset" % [event_id, option_id]):
				continue
			var request := catalog.build_play_request(event_id, preset_id, option_id)
			if not _check(request.get("ok", false), "%s option %s builds a play request" % [event_id, option_id]):
				continue
			var played: Dictionary = player.analyze_catalog_request(request)
			run_count += 1
			var ok := _check(played.get("ok", false), "%s option %s reaches the shared call frame: %s" % [event_id, option_id, str(played.get("error", ""))])
			if not ok:
				continue
			_check(str(played.get("mode", "")) == "group_route", "%s option %s reports the group_route mode" % [event_id, option_id])
			_check(bool(played.get("complete", false)), "%s option %s completes" % [event_id, option_id])
			_check(str(player.get("_view_mode")) == "analysis", "%s option %s leaves the player in Analysis view" % [event_id, option_id])
			var terminal_match: Dictionary = played.get("terminal_match", {})
			var outcome := KakyuEventOutcomeVocabulary.catalog_terminal_outcome(terminal_match)
			var outcome_key := str(outcome.get("outcome", "unknown"))
			outcome_counts[outcome_key] = int(outcome_counts.get(outcome_key, 0)) + 1
			if not option_id.is_empty():
				var option: Dictionary = {}
				for candidate in (choices[0] as Dictionary).get("options", []):
					if str((candidate as Dictionary).get("option_id", "")) == option_id:
						option = candidate
						break
				_check((option.get("terminal_ids", []) as Array).has(str(terminal_match.get("terminal_id", ""))), "%s option %s reaches one of its declared terminals" % [event_id, option_id])
			if str(terminal_match.get("kind", "")) != "analysis_boundary":
				_check(int(played.get("message_count", 0)) > 0, "%s option %s produces at least one message at a non-boundary terminal" % [event_id, option_id])
			if not forged_done and played.get("ok", false):
				forged_done = true
				var previous_state: KakyuMesSandboxState = player.get("_state")
				var previous_status: String = player.get("status_label").text
				var forged := request.duplicate(true)
				forged["preset"] = request.preset.duplicate(true)
				forged.preset["writes"] = [{"storage": "state_u16", "bank": 0, "index": 0, "value": 999999}]
				var rejected := player.analyze_catalog_request(forged)
				_check(not rejected.get("ok", true), "a forged preset write is rejected")
				_check(is_same(previous_state, player.get("_state")), "a forged request preserves the current sandbox state")
				_check(previous_status == player.get("status_label").text, "a forged request preserves the current status")
	_check(run_count > 0, "at least one analysis-group route ran")
	# TD-33 part 2: the guard-form checks exercise three fixed rows, not a
	# shard of the catalog - they run once, in shard 1 only.
	if shard_index == 1:
		_validate_guard_form(player, catalog, profiles, reader)
	_validate_playback_pass(player, catalog, analyzer, profiles)
	_validate_visit_presets(player, catalog, analyzer, profiles)
	_check(reader.get_archive_fingerprint() == original_sha, "original archive remains unchanged")
	player.queue_free()
	await process_frame
	_report()


## EP-10 unit 4 / Round 2 code review (item 7): a Playback pass over every
## promoted row's default option, through the public `play_catalog_request`
## (which now plays a promoted row outright) - proving the
## `_play_group_route` replay is behaviour-neutral for every promoted row.
## Reads the played result and the player's own
## `_catalog_timeline_steps` / `_catalog_timeline_unclassified` (the exact
## timeline `_play_group_route` built and applied) rather than running
## `run_group_route` or building a second timeline per row: the timeline's
## step count (`played.step_count`) equals the run's message count
## (`played.message_count`, +1 for a closing step), every step's text
## resolves, and the presentation resources resolve in the content set.
func _validate_playback_pass(player: KakyuEventPlayer, catalog: KakyuEventCatalog, analyzer, profiles) -> void:
	var content_set: KakyuContentSet = player.get("_content_set")
	var group_index := 0
	for event in catalog.get_events():
		if not event.has("analysis_group"):
			continue
		var this_group_index := group_index
		group_index += 1
		if not _shard_includes(this_group_index):
			continue
		var event_id := str(event.event_id)
		var default_request := catalog.build_play_request(event_id, "", "")
		if not _check(default_request.get("ok", false), "%s Playback default option builds a play request" % event_id):
			continue
		var option_id := str(default_request.get("selection", {}).get("option_id", ""))
		var preset_id: String = str(analyzer.pick_measured_preset_id(catalog, profiles, event_id, option_id))
		if not _check(not preset_id.is_empty(), "%s Playback default option resolves a measured preset" % event_id):
			continue
		var request := catalog.build_play_request(event_id, preset_id, option_id)
		if not _check(request.get("ok", false), "%s Playback default option builds its measured play request" % event_id):
			continue
		var played: Dictionary = player.play_catalog_request(request)
		if not _check(played.get("ok", false), "%s Playback default option plays: %s" % [event_id, str(played.get("error", ""))]):
			continue
		_check(str(player.get("_view_mode")) == "playback", "%s Playback default option leaves the player in Playback view" % event_id)
		# EP-12 gallery (2026-10-04): the status line names the matched
		# terminal's outcome through `matched_terminal_outcome` - a callee
		# return of a row that declares where its flow goes next is phrased by
		# the row's route outcome (an album scene: "Back to the place menu"),
		# not as an undeclared continuation.
		var status_text := str(player.get("status_label").text)
		var expected_phrase := KakyuEventOutcomeVocabulary.phrase(
			KakyuEventOutcomeVocabulary.matched_terminal_outcome(played.get("terminal_match", {}), request.get("terminals", []))
		)
		_check(status_text.ends_with(expected_phrase), "%s Playback status names the matched terminal's outcome (%s)" % [event_id, expected_phrase])
		# Every album scene row (EP-12 all-menus unit: 365) is a gallery row, the
		# predicate `display.categories` carries, not an id prefix.
		var categories: Array = (event.get("display", {}) as Dictionary).get("categories", [])
		if categories.has("gallery"):
			gallery_rows_checked += 1
			_check(status_text.ends_with("Back to the place menu"), "%s an album scene's callee return is phrased as the place menu" % event_id)
		playback_runs += 1
		var steps: Array = player.get("_catalog_timeline_steps")
		var step_count := int(played.get("step_count", 0))
		_check(steps.size() == step_count, "%s Playback timeline steps match the played step_count" % event_id)
		# EP-13 part B: the step count is now pinned to the run's own
		# `dialogue_boundary` count (+ closing), not the message count - a
		# step is the run of message records between two boundaries, so more
		# than one message record (or none at all) can share a step.
		var boundary_count := int(played.get("dialogue_boundary_count", 0))
		var has_closing := not steps.is_empty() and bool((steps[-1] as Dictionary).get("closing", false))
		var expected_step_count := boundary_count + (1 if has_closing else 0)
		_check(
			step_count == expected_step_count,
			"%s Playback timeline step count (%d) equals its dialogue_boundary count (%d)%s" % [
				event_id, step_count, boundary_count, " plus its closing step" if has_closing else "",
			],
		)
		for untyped_step in steps:
			var step: Dictionary = untyped_step
			var record_index := 0
			for untyped_record in step.get("messages", []):
				var presentation: Dictionary = player.call("_resolve_message_presentation", untyped_record)
				_check(
					str(presentation.get("source", "")) != "native bytes diagnostic",
					"%s Playback step %d record %d's text resolves" % [event_id, int(step.index), record_index],
				)
				record_index += 1
			for untyped_picture in step.get("pictures", []):
				var picture: Dictionary = untyped_picture
				var picture_name := str(picture.resource_name)
				var picture_role := str(picture.get("role", "unclassified"))
				var picture_searched: Array[String] = ["mmo.arc"]
				if (content_set.find_entry(picture_name, picture_searched) as Dictionary).get("ok", false):
					playback_pictures_found += 1
					playback_pictures_by_role_found[picture_role] = int(playback_pictures_by_role_found.get(picture_role, 0)) + 1
				else:
					playback_pictures_missing += 1
					playback_pictures_by_role_missing[picture_role] = int(playback_pictures_by_role_missing.get(picture_role, 0)) + 1
					_report_playback_missing("PICTURE", "mmo", playback_pictures_missing_names, event_id, int(step.index), picture_name, picture_searched)
			for untyped_animation in step.get("animations", []):
				var animation: Dictionary = untyped_animation
				var animation_name := str(animation.resource_name)
				var animation_searched: Array[String] = ["mmo.arc"]
				if str(animation.get("resource_kind", "")) == "ax":
					animation_searched = ["data.arc"]
				if (content_set.find_entry(animation_name, animation_searched) as Dictionary).get("ok", false):
					playback_animation_sources_found += 1
				else:
					playback_animation_sources_missing += 1
					_report_playback_missing("ANIMATION_SOURCE", str(animation.get("resource_kind", "")), playback_animation_sources_missing_names, event_id, int(step.index), animation_name, animation_searched)
			var voice_name := str(step.get("voice", ""))
			if not voice_name.is_empty():
				var voice_searched: Array[String] = ["voice.arc", "tina1.arc", "tina2.arc"]
				if (content_set.find_entry(voice_name, voice_searched) as Dictionary).get("ok", false):
					playback_voices_found += 1
				else:
					playback_voices_missing += 1
					_report_playback_missing("VOICE", "voice", playback_voices_missing_names, event_id, int(step.index), voice_name, voice_searched)
			for untyped_bgm in step.get("bgm", []):
				var bgm: Dictionary = untyped_bgm
				var bgm_name := str(bgm.resource_name)
				var bgm_searched: Array[String] = ["bgm.arc"]
				if (content_set.find_entry(bgm_name, bgm_searched) as Dictionary).get("ok", false):
					playback_bgm_found += 1
				else:
					playback_bgm_missing += 1
					_report_playback_missing("BGM", "bgm", playback_bgm_missing_names, event_id, int(step.index), bgm_name, bgm_searched)
			for untyped_effect in step.get("effects", []):
				var effect: Dictionary = untyped_effect
				var preferred: Array[String] = []
				if not str(effect.resource_archive).is_empty():
					preferred.append(str(effect.resource_archive).to_lower())
				preferred.append("voice.arc")
				preferred.append("se.arc")
				var effect_name := str(effect.resource_name)
				if (content_set.find_entry(effect_name, preferred) as Dictionary).get("ok", false):
					playback_effects_found += 1
				else:
					playback_effects_missing += 1
					_report_playback_missing("EFFECT", "se", playback_effects_missing_names, event_id, int(step.index), effect_name, preferred)
		# WD-21 U2 C5 gate 3: the played names against the row's declaration.
		var declared_check: Dictionary = DeclaredMediaScript.compare(event.get("resources", []), steps)
		playback_media_compared += int(declared_check.compared)
		for undeclared_value in declared_check.undeclared:
			_report_playback_undeclared(event_id, undeclared_value)
		# EP-14: the library media at their exact library coordinates, and the coverage report.
		var library_check: Dictionary = DeclaredMediaScript.compare_library(event.get("resources", []), steps)
		playback_library_media_compared += int(library_check.compared)
		for library_undeclared_value in library_check.undeclared:
			_report_playback_library_undeclared(event_id, library_undeclared_value)
		var coverage: Dictionary = DeclaredMediaScript.library_coverage(event.get("resources", []), steps)
		playback_library_items_declared += int(coverage.declared)
		playback_library_items_presented += int(coverage.presented)
		for coverage_category in coverage.presented_by_category:
			playback_library_presented_by_category[coverage_category] = int(playback_library_presented_by_category.get(coverage_category, 0)) + int(coverage.presented_by_category[coverage_category])
		for library_medium in DeclaredMediaScript.played_library_media(steps):
			var library_call: Dictionary = library_medium.library_call
			var library_category := str(library_medium.category)
			playback_library_media_by_category[library_category] = int(playback_library_media_by_category.get(library_category, 0)) + 1
			playback_library_media_rows.append({
				"event_id": event_id, "step": int(library_medium.step), "category": library_category,
				"name": str(library_medium.resource_name), "at": int(library_medium.at),
				"routine": int(library_call.routine), "caller_entry": str(library_call.caller_entry),
				"caller_offset": int(library_call.caller_offset),
			})
		for unclassified_name in (player.get("_catalog_timeline_unclassified") as Array):
			playback_unknown_effects[str(unclassified_name)] = true
	_check(playback_runs > 0, "at least one analysis-group route played in Playback view")
	_check(playback_unknown_effects.is_empty(), "the Playback pass finds no unclassified presentation effects")


## EP-11 part 1b/1c: every visit preset (`resolve_group_route_reference`
## resolves a stand-in variant carrying `visit_id`, see `catalog_analysis_run.gd`)
## of a shard's rows, run through both the Analysis and Playback passes.
## Checks: the Analysis run completes at a declared terminal, the played
## message count summed over the callee and every declared dispatch target
## (`visit.message_count` is "the callee's own run plus every nested call it
## makes", v13's own contract) equals the visit's `message_count`, the
## visit's declared dispatches occur (entry and offset in the trace), and the
## Playback pass plays the same preset without error.
func _validate_visit_presets(player: KakyuEventPlayer, catalog: KakyuEventCatalog, analyzer, profiles) -> void:
	var group_index := 0
	for event in catalog.get_events():
		if not event.has("analysis_group"):
			continue
		var this_group_index := group_index
		group_index += 1
		if not _shard_includes(this_group_index):
			continue
		var event_id := str(event.event_id)
		for preset_value in event.get("presets", []):
			var preset: Dictionary = preset_value
			var preset_id := str(preset.get("preset_id", ""))
			var reference: Dictionary = analyzer.resolve_group_route_reference(event, str(preset.get("notes", "")), profiles)
			if reference.is_empty() or not (reference.variant as Dictionary).has("visit_id"):
				continue
			var route: Dictionary = reference.route
			var visit: Dictionary = reference.variant
			var callee_entry := str(route.get("callee", {}).get("entry", ""))
			var request := catalog.build_play_request(event_id, preset_id, "")
			if not _check(request.get("ok", false), "%s visit preset %s builds a play request" % [event_id, preset_id]):
				continue
			visit_runs += 1
			var played: Dictionary = player.analyze_catalog_request(request)
			if not _check(played.get("ok", false), "%s visit preset %s Analysis reaches the shared call frame: %s" % [event_id, preset_id, str(played.get("error", ""))]):
				continue
			var terminal_match: Dictionary = played.get("terminal_match", {})
			_check(not str(terminal_match.get("terminal_id", "")).is_empty(), "%s visit preset %s Analysis completes at a declared terminal" % [event_id, preset_id])
			var verified: Dictionary = analyzer.run_group_route(player.get("_reader"), player.get("_resolver"), catalog, profiles, request)
			if not _check(verified.get("ok", false), "%s visit preset %s trace is available: %s" % [event_id, preset_id, str(verified.get("error", ""))]):
				continue
			var trace: Array = verified.probe.trace
			var messages: Array = verified.probe.messages
			# `visit.message_count` is "the callee's own run plus every nested
			# call it makes" (v13's own contract) - count messages from the
			# callee itself and from every declared dispatch target, not the
			# callee alone.
			var visit_entries := {callee_entry.to_upper(): true}
			for dispatch_value in visit.get("dispatches", []):
				visit_entries[str((dispatch_value as Dictionary).get("entry", "")).to_upper()] = true
			var callee_message_count := 0
			for untyped_message in messages:
				if visit_entries.has(str((untyped_message as Dictionary).get("source_entry", "")).to_upper()):
					callee_message_count += 1
			_check(
				callee_message_count == int(visit.get("message_count", -1)),
				"%s visit preset %s played callee message count (%d) equals the visit's message_count (%d)" % [
					event_id, preset_id, callee_message_count, int(visit.get("message_count", -1)),
				],
			)
			for dispatch_value in visit.get("dispatches", []):
				var dispatch: Dictionary = dispatch_value
				var found := false
				for untyped_row in trace:
					var row: Dictionary = untyped_row
					if (
						str(row.get("source_entry", "")).to_upper() == callee_entry.to_upper()
						and str(row.get("effect", "")) == "script_dispatch_boundary"
						and int(row.get("source_offset", -1)) == int(dispatch.get("offset", -2))
						and str(row.get("target_entry", "")).to_upper() == str(dispatch.get("entry", "")).to_upper()
					):
						found = true
						break
				_check(
					found,
					"%s visit preset %s dispatch to %s at 0x%X is in the trace" % [
						event_id, preset_id, str(dispatch.get("entry", "")), int(dispatch.get("offset", -1)),
					],
				)
			var play_request := catalog.build_play_request(event_id, preset_id, "")
			var play_played: Dictionary = player.play_catalog_request(play_request)
			_check(play_played.get("ok", false), "%s visit preset %s Playback plays: %s" % [event_id, preset_id, str(play_played.get("error", ""))])
	# Not asserted `> 0`: only two of 142 rows declare `visits` (EP-11 part
	# 1b's scope), so a given shard of `original catalog group routes` can
	# legitimately see none of them; `visit_runs` is still reported.


## EP-10 unit 3: for each of `GUARD_FORM_EVENT_IDS`, run once with a
## tool-seeded preset inside the bounds of the row's default measured
## preset (the run reaches the same terminal as that preset) and once with
## one field outside its bounds (`KakyuEventGuardForm.guard_result` reports
## `passes == false`, and the play request built from that out-of-bounds
## tool-seeded state is refused before the session is replaced).
func _validate_guard_form(player: KakyuEventPlayer, catalog: KakyuEventCatalog, profiles, reader: KakyuArcReader) -> void:
	var analyzer := preload("res://tools/content_suite/catalog_analysis_run.gd").new()
	for event_id in GUARD_FORM_EVENT_IDS:
		var event: Dictionary = catalog.get_event(event_id)
		if not _check(not event.is_empty(), "%s is a catalog row" % event_id):
			continue
		var definition_id := str(event.get("analysis_group", {}).get("definition_id", ""))
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://config/event_definitions/v4/%s.json" % definition_id))
		var definition: Dictionary = parsed if parsed is Dictionary else {}
		var conjuncts: Array = definition.get("guard", {}).get("conjuncts", [])
		if not _check(not conjuncts.is_empty(), "%s's document has a typed guard" % event_id):
			continue
		var built: Dictionary = GuardForm.fields(conjuncts)
		var fields: Array = built.fields
		# Round 3 code review, item 9: the default option is whatever
		# `build_play_request` itself defaults to, not a second copy of that rule.
		var default_probe_request := catalog.build_play_request(event_id, "", "")
		var option_id := str(default_probe_request.get("selection", {}).get("option_id", "")) if default_probe_request.get("ok", false) else ""
		var preset_id := analyzer.pick_measured_preset_id(catalog, profiles, event_id, option_id)
		if not _check(not preset_id.is_empty(), "%s resolves a measured preset for the guard form" % event_id):
			continue
		var base_preset: Dictionary = {}
		for preset_value in event.get("presets", []):
			if str((preset_value as Dictionary).get("preset_id", "")) == preset_id:
				base_preset = preset_value
				break
		var base_writes: Array = base_preset.get("writes", [])
		var writes_by_key := GuardForm.writes_by_key(base_writes)
		var caller_entry := str(event.get("source", {}).get("caller", {}).get("entry", ""))
		var document := ContainerScript.new().parse(reader.read_entry(caller_entry), {"entry": caller_entry})
		if not _check(document.get("ok", false), "%s caller entry parses" % event_id):
			continue
		var code: PackedByteArray = document.get("bytecode", PackedByteArray())
		var guard_offset := int(definition.get("guard", {}).get("offset", -1))

		# In-bounds: every field set to the default measured preset's own
		# value (or, absent a write, its fixed value or minimum).
		var in_bounds_values := {}
		for field_value in fields:
			var field: Dictionary = field_value
			var key := str(field.key)
			in_bounds_values[key] = writes_by_key.get(key, int(field.fixed) if field.fixed != null else int(field.min))
		var in_bounds_writes: Array = GuardForm.writes(fields, in_bounds_values, base_writes)
		var in_bounds_state := SandboxStateScript.new(1)
		in_bounds_state.load_values(in_bounds_writes)
		var in_bounds_guard: Dictionary = GuardForm.guard_result(code, code.size(), guard_offset, in_bounds_state)
		_check(in_bounds_guard.get("passes", false), "%s in-bounds guard form state passes the guard" % event_id)
		var in_bounds_tool_preset: Dictionary = GuardForm.tool_seeded_preset("tool-seeded", in_bounds_writes)
		var plain_request := catalog.build_play_request(event_id, preset_id, option_id)
		var plain_played: Dictionary = player.analyze_catalog_request(plain_request)
		var tool_request := catalog.build_play_request(event_id, preset_id, option_id, in_bounds_tool_preset)
		var tool_played: Dictionary = player.analyze_catalog_request(tool_request)
		if _check(plain_played.get("ok", false) and tool_played.get("ok", false), "%s in-bounds tool-seeded run and its preset both complete" % event_id):
			guard_in_bounds_runs += 1
			_check(
				str((plain_played.get("terminal_match", {}) as Dictionary).get("terminal_id", "")) == str((tool_played.get("terminal_match", {}) as Dictionary).get("terminal_id", "")),
				"%s in-bounds tool-seeded run reaches the same terminal as its preset" % event_id
			)

		# Out of bounds: push one bounded field past its range.
		var broken_key := ""
		var broken_value := 0
		for field_value in fields:
			var field: Dictionary = field_value
			if int(field.min) > 0:
				broken_key = str(field.key)
				broken_value = int(field.min) - 1
				break
		if broken_key.is_empty():
			for field_value in fields:
				var field: Dictionary = field_value
				var default_max := 255 if str(field.storage) in ["global_u8", "banked_u8"] else 65535
				if int(field.max) < default_max:
					broken_key = str(field.key)
					broken_value = int(field.max) + 1
					break
		if broken_key.is_empty():
			for field_value in fields:
				var field: Dictionary = field_value
				if field.fixed != null:
					broken_key = str(field.key)
					broken_value = int(field.fixed) + 1
					break
		if not _check(not broken_key.is_empty(), "%s has a bounded field to push out of range" % event_id):
			continue
		var out_values: Dictionary = in_bounds_values.duplicate(true)
		out_values[broken_key] = broken_value
		var out_writes: Array = GuardForm.writes(fields, out_values, base_writes)
		var out_state := SandboxStateScript.new(1)
		out_state.load_values(out_writes)
		var out_guard: Dictionary = GuardForm.guard_result(code, code.size(), guard_offset, out_state)
		_check(not out_guard.get("passes", true), "%s out-of-bounds guard form state fails the guard" % event_id)

		# Round 2 code review (owner, 2026-09-20): the refusal must also live
		# in the service, reachable without the UI toggle at all - build the
		# out-of-bounds tool preset directly and play it.
		var out_tool_preset: Dictionary = GuardForm.tool_seeded_preset("tool-seeded", out_writes)
		var out_request := catalog.build_play_request(event_id, preset_id, option_id, out_tool_preset)
		var pre_state: KakyuMesSandboxState = player.get("_state")
		var pre_status: String = player.get("status_label").text
		var out_played: Dictionary = player.analyze_catalog_request(out_request)
		_check(
			not out_played.get("ok", true) and str(out_played.get("error", "")) == "The tool-seeded state does not pass the route's guard.",
			"%s's service refuses the out-of-bounds tool-seeded request with the guard-failure message" % event_id
		)
		_check(is_same(pre_state, player.get("_state")), "%s's refused out-of-bounds request leaves the sandbox state untouched" % event_id)
		_check(pre_status == player.get("status_label").text, "%s's refused out-of-bounds request leaves the status label untouched" % event_id)

		# The UI-layer fact is a second, independent guarantee, checked
		# through the real Event Player catalog UI (as
		# `_catalog_selected_play_request` sees it): `_refresh_catalog_guard_line`
		# (run through `_on_catalog_guard_field_changed`) disables the "Use this
		# state" toggle against the real archive bytecode, and the request
		# builder falls back to the ordinary catalog preset - never a
		# tool-seeded one - even when the toggle is forced back on.
		var tree: Tree = player.get("catalog_tree")
		var row_item := tree.get_root().get_first_child()
		var row_selected := false
		while row_item != null:
			if str(row_item.get_metadata(0)) == event_id:
				row_item.select(0)
				player._on_catalog_event_selected()
				row_selected = true
				break
			row_item = row_item.get_next()
		if not _check(row_selected, "%s is selectable in the catalog tree" % event_id):
			continue
		var preset_selector: OptionButton = player.get("catalog_preset_select")
		var preset_index := -1
		for index in range(preset_selector.item_count):
			if str(preset_selector.get_item_metadata(index)) == preset_id:
				preset_index = index
				break
		if not _check(preset_index >= 0, "%s's measured preset is selectable in the catalog UI" % event_id):
			continue
		preset_selector.select(preset_index)
		player._on_catalog_preset_selected(preset_index)
		if not option_id.is_empty():
			var result_selector: OptionButton = player.get("catalog_result_select")
			for index in range(result_selector.item_count):
				if str(result_selector.get_item_metadata(index)) == option_id:
					result_selector.select(index)
					player._on_catalog_result_selected(index)
					break
		var toggle: CheckButton = player.get("catalog_use_form_state")
		_check(not toggle.disabled, "%s's guard form toggle is enabled for its measured (in-bounds) preset" % event_id)
		player._on_catalog_guard_field_changed(float(broken_value), broken_key)
		var refused := _check(toggle.disabled and not toggle.button_pressed, "%s's guard form toggle disables once a field is out of bounds" % event_id)
		# A user cannot press a disabled toggle, but force it anyway: the
		# request builder must still refuse the tool-seeded state.
		toggle.button_pressed = true
		var ui_out_request: Dictionary = player._catalog_selected_play_request()
		refused = refused and _check(
			ui_out_request.get("ok", false) and str((ui_out_request.get("preset", {}) as Dictionary).get("kind", "")) != "tool_seeded_analysis",
			"%s's request builder refuses the out-of-bounds tool-seeded state and falls back to its catalog preset" % event_id
		)
		if refused:
			guard_out_of_bounds_refusals += 1


## TD-33 part 2: parses a `shard=K/N` user argument (1 <= K <= N, N >= 2);
## an empty dictionary means the text is not a well-formed shard argument.
func _parse_shard_argument(text: String) -> Dictionary:
	if not text.begins_with("shard="):
		return {}
	var parts := text.substr(len("shard=")).split("/")
	if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
		return {}
	var k := int(parts[0])
	var n := int(parts[1])
	if n < 2 or k < 1 or k > n:
		return {}
	return {"k": k, "n": n}


## A row at `index` (its position among every catalog row with an
## `analysis_group`, in the catalog's own order) belongs to this process's
## shard when `index % shard_count == shard_index - 1`. Always true for the
## unsharded default (`shard_count == 1`).
func _shard_includes(index: int) -> bool:
	return index % shard_count == shard_index - 1


## TD-33 part 2: prints one `PLAYBACK_<CATEGORY>_MISSING` line for a
## presentation resource the Playback pass could not find, and records the
## same fields in `names` (this validator's own `playback_*_missing_names`
## list) for the JSON report.
##
## WD-21 U1 gate 2 (a tool decision over an original-data fact): the line and the
## record also carry `registered`, whether the register lists the name as absent
## from every original archive of its kind, and an unregistered miss fails the
## shard. The category maps to the register's kind (PICTURE -> `mmo`,
## ANIMATION_SOURCE -> `resource_kind` `mmo` or `ax`, VOICE -> `voice`, BGM ->
## `bgm`, EFFECT -> `se`) and the name is normalized the way the archives are
## searched (`to_upper()`).
func _report_playback_missing(
	category: String, resource_kind: String, names: Array[Dictionary], event_id: String, step: int, resource_name: String, searched: Array[String],
) -> void:
	var classified: Dictionary = KnownAbsentMediaScript.classify_playback_miss(known_absent_register, category, resource_kind, resource_name)
	var registered: bool = classified.registered
	var record := {
		"event_id": event_id, "step": step, "resource_name": resource_name, "searched": searched,
		"registered": registered,
	}
	print("PLAYBACK_%s_MISSING %s" % [category, JSON.stringify(record)])
	names.append(record)
	if registered:
		playback_misses_registered += 1
	else:
		playback_misses_unregistered += 1
	_check(
		registered,
		"%s %s (%s) at %s step %d is not in the known-absent media register" % [category, resource_name, str(classified.kind), event_id, step],
	)


## WD-21 U2 C5 gate 3 (a tool decision): prints one `PLAYBACK_UNDECLARED_<CATEGORY>` line for a
## medium the played timeline uses that the row's catalog `resources` do not declare, records it
## for the JSON report and fails the shard. The compare is name-level (`declared_media.gd`): the
## timeline keeps no offset and the catalog item no kind.
func _report_playback_undeclared(event_id: String, medium: Dictionary) -> void:
	var category := str(medium.category)
	var record := {
		"event_id": event_id, "category": category, "step": int(medium.step),
		"resource_name": str(medium.resource_name),
	}
	print("PLAYBACK_UNDECLARED_%s %s" % [category, JSON.stringify(record)])
	playback_undeclared_names.append(record)
	playback_undeclared += 1
	playback_undeclared_by_category[category] = int(playback_undeclared_by_category.get(category, 0)) + 1
	_check(false, "%s %s (%s) at %s step %d is not declared by the row's catalog resources" % [
		category, str(medium.resource_name), str(medium.name), event_id, int(medium.step),
	])


## EP-14 (a tool decision): prints one `PLAYBACK_UNDECLARED_LIBRARY_<CATEGORY>` line for a library
## medium the played timeline presented that no declared item matches at its library coordinate
## (`request_entry`, `request_offset`, name), records it for the JSON report and fails the shard.
## The line names the event, step, name, the library coordinate (`entry`, `at`) and the
## `library_call` that ran it. A name-level match (`_report_playback_undeclared`) cannot see this
## class: the same name declared at another offset or under another entry.
func _report_playback_library_undeclared(event_id: String, medium: Dictionary) -> void:
	var category := str(medium.category)
	var record := {
		"event_id": event_id, "category": category, "step": int(medium.step),
		"resource_name": str(medium.resource_name), "entry": str(medium.entry), "at": int(medium.at),
		"library_call": medium.library_call,
	}
	print("PLAYBACK_UNDECLARED_LIBRARY_%s %s" % [category, JSON.stringify(record)])
	playback_library_undeclared_names.append(record)
	playback_library_undeclared += 1
	_check(false, "%s library %s %s at %s:%d (called from %s:%d) is not declared there by the row's catalog resources" % [
		category, str(medium.resource_name), str(medium.name), str(medium.entry), int(medium.at),
		str((medium.library_call as Dictionary).caller_entry), int((medium.library_call as Dictionary).caller_offset),
	])


func _check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok:
		failures.append(label)
	return ok


func _report() -> void:
	# The verdict is the same one the exit code carries: a shard with any failure
	# prints FAIL, not PASS (it used to print PASS unconditionally).
	print(
		(
			"%s shard %s (%d rows): %d group-route runs across %d checks; %d unmeasured options skipped; %d guard-form in-bounds runs; "
			+ "%d guard-form out-of-bounds refusals; outcomes %s; %d Playback runs - pictures %d/%d found (by role %s/%s), "
			+ "animation sources %d/%d found, voices %d/%d found, "
			+ "bgm %d/%d found, effects %d/%d found, %d unknown effects; %d known-absent misses registered, %d unregistered; "
			+ "%d played media names compared with the declared resources, %d undeclared; "
			+ "%d library media presented (%d pictures, %d effects), compared at their library coordinates, %d undeclared; "
			+ "%d declared library items, %d presented; %d visit preset runs"
			+ "; %d failures"
		) % [
			"PASS" if failures.is_empty() else "FAIL", shard_label, shard_row_count,
			run_count, checks, unmeasured_options, guard_in_bounds_runs, guard_out_of_bounds_refusals, JSON.stringify(outcome_counts),
			playback_runs,
			playback_pictures_found, playback_pictures_found + playback_pictures_missing,
			JSON.stringify(playback_pictures_by_role_found), JSON.stringify(playback_pictures_by_role_missing),
			playback_animation_sources_found, playback_animation_sources_found + playback_animation_sources_missing,
			playback_voices_found, playback_voices_found + playback_voices_missing,
			playback_bgm_found, playback_bgm_found + playback_bgm_missing,
			playback_effects_found, playback_effects_found + playback_effects_missing,
			playback_unknown_effects.size(),
			playback_misses_registered, playback_misses_unregistered,
			playback_media_compared, playback_undeclared,
			playback_library_media_compared,
			int(playback_library_media_by_category.get("PICTURE", 0)), int(playback_library_media_by_category.get("EFFECT", 0)),
			playback_library_undeclared,
			playback_library_items_declared, playback_library_items_presented,
			visit_runs,
			failures.size(),
		]
	)
	print(JSON.stringify({
		"ok": failures.is_empty(), "shard": shard_label, "shard_rows": shard_row_count,
		"checks": checks, "run_count": run_count, "unmeasured_options": unmeasured_options,
		"guard_in_bounds_runs": guard_in_bounds_runs, "guard_out_of_bounds_refusals": guard_out_of_bounds_refusals,
		"outcome_counts": outcome_counts, "failures": failures,
		"playback_runs": playback_runs, "gallery_rows_checked": gallery_rows_checked,
		"playback_pictures_found": playback_pictures_found, "playback_pictures_missing": playback_pictures_missing,
		"playback_pictures_by_role_found": playback_pictures_by_role_found,
		"playback_pictures_by_role_missing": playback_pictures_by_role_missing,
		"playback_animation_sources_found": playback_animation_sources_found,
		"playback_animation_sources_missing": playback_animation_sources_missing,
		"playback_voices_found": playback_voices_found, "playback_voices_missing": playback_voices_missing,
		"playback_bgm_found": playback_bgm_found, "playback_bgm_missing": playback_bgm_missing,
		"playback_effects_found": playback_effects_found, "playback_effects_missing": playback_effects_missing,
		"playback_unknown_effects": playback_unknown_effects.keys(),
		"playback_misses_registered": playback_misses_registered,
		"playback_misses_unregistered": playback_misses_unregistered,
		"playback_media_compared": playback_media_compared, "playback_undeclared": playback_undeclared,
		"playback_undeclared_by_category": playback_undeclared_by_category,
		"playback_undeclared_names": playback_undeclared_names,
		"playback_library_media_compared": playback_library_media_compared,
		"playback_library_media_by_category": playback_library_media_by_category,
		"playback_library_undeclared": playback_library_undeclared,
		"playback_library_undeclared_names": playback_library_undeclared_names,
		"playback_library_items_declared": playback_library_items_declared,
		"playback_library_items_presented": playback_library_items_presented,
		"playback_library_presented_by_category": playback_library_presented_by_category,
		"playback_library_media_rows": playback_library_media_rows,
		"playback_pictures_missing_names": playback_pictures_missing_names,
		"playback_animation_sources_missing_names": playback_animation_sources_missing_names,
		"playback_voices_missing_names": playback_voices_missing_names,
		"playback_bgm_missing_names": playback_bgm_missing_names,
		"playback_effects_missing_names": playback_effects_missing_names,
		"visit_runs": visit_runs,
	}))
	quit(0 if failures.is_empty() else 1)
