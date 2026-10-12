extends SceneTree

# Steps 3 and 4 of the modding tools repository split: play a playback package.
#
# The question this answers is whether the package contains enough to run the
# catalog's events, so it runs every route twice and compares:
#
#   reference  the authoritative mes.arc bytecode, as every existing audit runs
#   packaged   the package alone, through KakyuPlaybackPackage, with no archive
#
# Both sides use the same runners and the same driver. Only the code source
# differs, so a divergence is a fact about the package rather than about two
# runtimes. Where a route stops at a boundary the driver does not handle, both
# sides must stop at the same place for the same reason; that is equivalence
# too, and it is reported rather than hidden.
#
# The driver takes its choices, presets and terminals from the catalog data the
# package carries, not from constants here.
#
# The package is written under user:// and removed again. It carries original
# dialogue, and this script never prints message text.

const RouteProbeScript := preload("res://content_core/mes_route_probe.gd")
const ArcReaderScript := preload("res://content_core/arc_reader.gd")
const MesContainerScript := preload("res://content_core/mes_container.gd")
const ExportScript := preload("res://tools/content_suite/playback_package_export.gd")
const PackageScript := preload("res://content_core/playback_package.gd")
const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")
const AnalysisRunScript := preload("res://tools/content_suite/catalog_analysis_run.gd")
const FlowRunnerScript := preload("res://tools/content_suite/event_flow_runner.gd")

const CATALOG_PATH := "res://config/event_catalog/original_events_v1.json"

const ARCHIVE_SHA256 := "31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6"
const PACKAGE_DIRECTORY := "user://kakyu_playback_package_check"
const LIBRARY_ENTRY := "LIBLARY.LIB"
const DEFINITION_ENTRY := "DEF_MAIN.MES"

# Terminal kinds that end a route rather than continue it.
const ROOT_TERMINAL_KINDS := {
	"root_replacement": true,
	"caller_handoff": true,
	"normal_completion": true,
	"early_return": true,
	"rejection_return": true,
}

var _checks := 0
var _failures: Array[String] = []
var _documents: Dictionary = {}
var _rows: Array[Dictionary] = []
var _menu_endings := 0
var _chain_continuations := 0
var _catalog: KakyuEventCatalog
var _profiles: KakyuEventAnalysisProfiles


func _init() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() != 1:
		push_error("Usage: validate_playback_package_playback.gd <ELFIMAGE-directory>")
		quit(2)
		return
	var source_root := str(arguments[0]).replace("\\", "/")
	while source_root.ends_with("/"):
		source_root = source_root.substr(0, source_root.length() - 1)

	var package: KakyuPlaybackPackage = _build_and_load(source_root)
	if package == null:
		_report()
		return
	_load_reference_documents(source_root, package)
	_load_catalog_and_profiles()
	if _failures.is_empty():
		_compare_all(package)
	_remove_directory(ProjectSettings.globalize_path(PACKAGE_DIRECTORY))
	_report()


func _build_and_load(source_root: String) -> KakyuPlaybackPackage:
	var root := ProjectSettings.globalize_path(PACKAGE_DIRECTORY)
	# TD-64: the exporter, the build result, the serialized package and the
	# write result all go out of scope inside `_build_and_write`, so the
	# package is not held twice while the reload below runs.
	var staged := _build_and_write(source_root, root)
	if staged.is_empty():
		return null

	var package: KakyuPlaybackPackage = PackageScript.new()
	var loaded := package.load_directory(root)
	_check(loaded.get("ok", false), "package did not load: %s" % str(loaded.get("error", "")))
	if not loaded.get("ok", false):
		return null
	_check(
		str(loaded.schema) == ContentCoreVersionScript.PLAYBACK_PACKAGE_SCHEMA,
		"loaded package schema is not the current one"
	)
	_check(
		str(loaded.package_sha256) == str(staged.package_sha256),
		"recomputed package hash does not match the manifest"
	)
	_check(int(loaded.event_ids.size()) == int(staged.event_count), "package lost an event")
	return package


## Builds, serializes and writes the package under `root`, and returns only
## what the reload checks compare: `{package_sha256, event_count}`. An empty
## result means a failure was recorded.
func _build_and_write(source_root: String, root: String) -> Dictionary:
	var exporter := ExportScript.new()
	var built := exporter.build(source_root, [])
	if not built.get("ok", false):
		for failure in built.get("failures", []):
			_failures.append("export: %s" % str(failure))
		return {}
	var event_count := int(built.events.size())
	var serialized := exporter.serialize(built)
	# The build result is not read again; releasing it before `write()` reopens
	# the staged package is the point of this helper.
	built = {}
	if not serialized.get("ok", false):
		for failure in serialized.get("failures", []):
			_failures.append("serialize: %s" % str(failure))
		return {}
	_remove_directory(root)
	var written := exporter.write(root, serialized)
	if not written.get("ok", false):
		for failure in written.get("failures", []):
			_failures.append("write: %s" % str(failure))
		return {}
	return {
		"package_sha256": str(serialized.manifest.package_sha256),
		"event_count": event_count,
	}


func _load_reference_documents(source_root: String, package: KakyuPlaybackPackage) -> void:
	var reader := ArcReaderScript.new()
	if not reader.open(source_root + "/mes.arc"):
		_failures.append("original mes.arc could not be opened")
		return
	if reader.get_archive_fingerprint() != ARCHIVE_SHA256:
		reader.close()
		_failures.append("mes.arc identity changed")
		return
	var parser := MesContainerScript.new()
	for entry in package.entry_names():
		var document := parser.parse(reader.read_entry(entry), {"entry": entry})
		if not document.get("ok", false):
			_failures.append("%s could not be parsed" % entry)
			continue
		_documents[entry] = document
	reader.close()


func _load_catalog_and_profiles() -> void:
	_catalog = KakyuEventCatalog.new()
	var loaded_catalog := _catalog.load_file(CATALOG_PATH)
	if not loaded_catalog.get("ok", false):
		_failures.append("catalog could not be loaded: %s" % str(loaded_catalog.get("error", "")))
		return
	_profiles = KakyuEventAnalysisProfiles.new()
	var loaded_profiles := _profiles.load_dir()
	if not loaded_profiles.get("ok", false):
		_failures.append("analysis-group profiles could not be loaded: %s" % str(loaded_profiles.get("error", "")))


func _find_preset(event: Dictionary, preset_id: String) -> Dictionary:
	for preset_value in event.get("presets", []):
		var preset: Dictionary = preset_value
		if str(preset.get("preset_id", "")) == preset_id:
			return preset
	return {}


## The row's default option id: whatever `build_play_request` itself
## defaults to (the row's first choice's default option, or "" for a
## choiceless row) - the same rule the player's `_sync_catalog_preset_selection`
## uses, not a second, separately maintained copy of it.
func _default_option_id(event_id: String) -> String:
	var default_probe_request := _catalog.build_play_request(event_id, "", "")
	if not default_probe_request.get("ok", false):
		return ""
	return str(default_probe_request.get("selection", {}).get("option_id", ""))


## The Play-equivalent descriptor and seed for a packaged row: the row's
## default measured preset resolves the row's measured route
## (`resolve_group_route_reference`); `seed_route_state` seeds the route's
## own calendar context and the preset's writes (the same seed for both the
## reference and the packaged run, isolating whether the *bytecode* the
## package carries reproduces the archive's own trace). A v14 flow route
## (`route.has("hops")`, EP-12 catalog part) has no per-route
## `caller`/`callee`/`origin_offset` pair for `build_group_route_descriptor`
## to read - `_compare_all` walks it through the same
## `KakyuEventFlowRunner` `catalog_analysis_run.gd`'s own v14 branch uses
## instead, seeded once here exactly as an ordinary route is; any other
## route still gets `build_group_route_descriptor`'s single-dispatch
## descriptor, the call frame `catalog_analysis_run.gd`'s `run_group_route`
## builds for it (rather than the pre-EP-10 callee-start/probe-default
## policy).
func _row_run_frame(event_id: String) -> Dictionary:
	var analyzer := AnalysisRunScript.new()
	var event: Dictionary = _catalog.get_event(event_id)
	var option_id := _default_option_id(event_id)
	var preset_id := analyzer.pick_measured_preset_id(_catalog, _profiles, event_id, option_id)
	if preset_id.is_empty():
		return {"ok": false, "error": "no measured preset resolves for the default option"}
	var preset := _find_preset(event, preset_id)
	var reference := analyzer.resolve_group_route_reference(event, str(preset.get("notes", "")), _profiles)
	if reference.is_empty():
		return {"ok": false, "error": "the measured preset's route could not be resolved"}
	var route: Dictionary = reference.route
	var seeded := analyzer.seed_route_state(_documents, route, preset.get("writes", []))
	if not seeded.get("ok", false):
		return {"ok": false, "error": str(seeded.get("error", "the route state could not be seeded"))}
	var frame := {
		"ok": true,
		"is_flow": route.has("hops"),
		"route": route,
		"variant": reference.variant,
		"state": seeded.state,
		"route_id": str(reference.route_id),
		"variant_id": str((reference.variant as Dictionary).get("variant_id", "")),
	}
	if not frame.is_flow:
		var route_descriptor := analyzer.build_group_route_descriptor(route, reference.variant)
		if not route_descriptor.get("ok", false):
			return {"ok": false, "error": str(route_descriptor.get("error", "the route has no origin coordinate"))}
		frame["descriptor"] = route_descriptor
	return frame


func _compare_all(package: KakyuPlaybackPackage) -> void:
	var reference_context := _reference_context(package)
	var packaged_context := _packaged_context(package)
	if not _failures.is_empty():
		return
	var reached := 0
	var at_menu := 0
	var chained := 0
	var stopped := 0
	for untyped_descriptor in package.events():
		var descriptor: Dictionary = untyped_descriptor
		var event_id := str(descriptor.event_id)
		var frame := _row_run_frame(event_id)
		_check(frame.get("ok", false), "%s builds its Play-equivalent run frame: %s" % [event_id, str(frame.get("error", ""))])
		if not frame.get("ok", false):
			continue
		var seed_state: KakyuMesSandboxState = frame.state
		var reference: Dictionary
		var packaged: Dictionary
		if bool(frame.get("is_flow", false)):
			# EP-12 catalog part: the same `KakyuEventFlowRunner`
			# `catalog_analysis_run.gd`'s own v14 branch calls - no second
			# copy of the hop-chain walk - seeded once here and run against
			# each code source's own provider in turn.
			var route: Dictionary = frame.route
			var variant: Dictionary = frame.variant
			reference = FlowRunnerScript.run_route(RouteProbeScript.new(), reference_context, {}, route, variant, {"initial_state": seed_state})
			packaged = FlowRunnerScript.run_route(RouteProbeScript.new(), packaged_context, {}, route, variant, {"initial_state": seed_state.duplicate_state()})
		else:
			var route_descriptor: Dictionary = frame.descriptor
			reference = RouteProbeScript.new().run_route(reference_context, route_descriptor, {}, seed_state)
			packaged = RouteProbeScript.new().run_route(packaged_context, route_descriptor, {}, seed_state.duplicate_state())
		_check(
			JSON.stringify(reference.segments) == JSON.stringify(packaged.segments),
			"%s segments differ at %s" % [
				event_id,
				_first_difference(reference.segments, packaged.segments),
			]
		)
		_check(
			reference.signature == packaged.signature,
			"%s trace rows differ at %s" % [
				event_id,
				_first_difference(reference.rows, packaged.rows),
			]
		)
		_check(
			JSON.stringify(reference.message_hex) == JSON.stringify(packaged.message_hex),
			"%s message payloads differ at %s" % [
				event_id,
				_first_difference(reference.message_hex, packaged.message_hex),
			]
		)
		_check(
			JSON.stringify(reference.state) == JSON.stringify(packaged.state),
			"%s final state differs at %s" % [
				event_id,
				_first_difference(reference.state, packaged.state),
			]
		)
		_check(
			JSON.stringify(reference.terminal) == JSON.stringify(packaged.terminal)
			and str(reference.stop) == str(packaged.stop),
			"%s terminal or stop reason differs: reference %s/%s packaged %s/%s" % [
				event_id,
				JSON.stringify(reference.terminal),
				str(reference.stop),
				JSON.stringify(packaged.terminal),
				str(packaged.stop),
			]
		)
		var declared := _declared_terminal(descriptor, packaged.terminal)
		if not packaged.terminal.is_empty():
			reached += 1
			# Most catalog terminals sit in the calling map or day script, which
			# is not a package member: the package ends where the event entry
			# ends. A terminal is only required to match when the catalog
			# declares one inside that entry.
			if not _declares_entry_terminal(descriptor, str(packaged.terminal.get("entry", ""))):
				declared = {"terminal_id": "caller-side"}
			_check(
				not declared.is_empty(),
				"%s reached a terminal the catalog does not declare: %s" % [
					event_id,
					JSON.stringify(packaged.terminal),
				]
			)
		elif not str(packaged.stop).is_empty():
			# A run that stops at the place script's own menu ends there in the
			# game's vocabulary (`place_menu`, EP-09) when the catalog declares
			# that menu as the row's terminal; any other stop stays a stop.
			declared = _declared_menu_terminal(descriptor, str(packaged.stop))
			if not declared.is_empty():
				at_menu += 1
			else:
				# EP-03 step 2 (owner ruling 2026-09-23): a dependency stop
				# whose stop_detail entry/offset match a declared
				# script_dispatch_boundary terminal that already carries a
				# next_target (the promotion tool's `chain` ruling) counted
				# into the next event rather than staying a plain stop -
				# same coordinate match `catalog_analysis_run.gd`'s
				# `run_group_route` uses for script_dispatch_boundary.
				declared = _declared_chain_terminal(descriptor, packaged.get("stop_detail", {}))
				if not declared.is_empty():
					chained += 1
				else:
					stopped += 1
		_rows.append({
			"event": event_id,
			"status": str(descriptor.playback_status),
			"route": "%s/%s" % [str(frame.route_id), str(frame.variant_id)],
			"segments": reference.segments.size(),
			"dialogue": reference.segments.filter(
				func(row): return str(row.status) == "dialogue_boundary"
			).size(),
			"library": reference.segments.filter(
				func(row): return str(row.status) == "shared_routine_boundary"
			).size(),
			"rows": reference.rows.size(),
			"messages": reference.message_hex.size(),
			"terminal": str(reference.terminal.get("target", "-"))
				if not reference.terminal.is_empty() else "-",
			"terminal_offset": int(reference.terminal.get("offset", -1)),
			"declared": str(declared.get("terminal_id", "-")) if not declared.is_empty() else "-",
			"stop": str(reference.stop),
		})
	_check(reached > 0, "no packaged route reached a terminal")
	for row in _rows:
		print("EVENT %s" % JSON.stringify(row))
	_menu_endings = at_menu
	_chain_continuations = chained
	print("SUMMARY: %d rows, %d reached a terminal, %d ended at a declared place menu, %d continued into the next event, %d stopped" % [
		_rows.size(),
		reached,
		at_menu,
		chained,
		stopped,
	])


func _declared_menu_terminal(descriptor: Dictionary, stop: String) -> Dictionary:
	for untyped_declared in descriptor.get("terminals", []):
		var declared: Dictionary = untyped_declared
		if str(declared.get("runtime_status", "")) != "def_selection_boundary":
			continue
		var expected := "no catalog choice at 0x%X in %s" % [
			int(declared.get("offset", -1)),
			str(declared.get("owner_entry", "")),
		]
		if stop.to_upper() == expected.to_upper():
			return declared
	return {}


func _declared_chain_terminal(descriptor: Dictionary, stop_detail: Dictionary) -> Dictionary:
	if stop_detail.is_empty():
		return {}
	for untyped_declared in descriptor.get("terminals", []):
		var declared: Dictionary = untyped_declared
		if str(declared.get("runtime_status", "")) != "script_dispatch_boundary":
			continue
		if str(declared.get("next_target", "")).is_empty():
			continue
		if str(declared.get("owner_entry", "")).to_upper() != str(stop_detail.get("entry", "")).to_upper():
			continue
		if int(declared.get("offset", -1)) != int(stop_detail.get("offset", -2)):
			continue
		return declared
	return {}


func _declared_terminal(descriptor: Dictionary, terminal: Dictionary) -> Dictionary:
	if terminal.is_empty():
		return {}
	for untyped_declared in descriptor.get("terminals", []):
		var declared: Dictionary = untyped_declared
		if int(declared.get("offset", -1)) != int(terminal.get("offset", -2)):
			continue
		if str(declared.get("owner_entry", "")).to_upper() != str(terminal.get("entry", "")).to_upper():
			continue
		return declared
	return {}


func _declares_entry_terminal(descriptor: Dictionary, entry: String) -> bool:
	for untyped_declared in descriptor.get("terminals", []):
		var declared: Dictionary = untyped_declared
		if str(declared.get("owner_entry", "")).to_upper() == entry.to_upper():
			return true
	return false


func _reference_context(_package: KakyuPlaybackPackage) -> Dictionary:
	var context := RouteProbeScript.new().context_from_documents(_documents)
	if not context.get("ok", false):
		_failures.append(str(context.error))
	return context


func _packaged_context(package: KakyuPlaybackPackage) -> Dictionary:
	var context := RouteProbeScript.new().context_from_package(package)
	if not context.get("ok", false):
		_failures.append(str(context.error))
	return context


func _first_difference(reference: Array, packaged: Array) -> String:
	for index in range(maxi(reference.size(), packaged.size())):
		var left = reference[index] if index < reference.size() else {}
		var right = packaged[index] if index < packaged.size() else {}
		if JSON.stringify(left) != JSON.stringify(right):
			return "index %d of %d/%d: reference %s packaged %s" % [
				index,
				reference.size(),
				packaged.size(),
				JSON.stringify(left),
				JSON.stringify(right),
			]
	return "no difference"


func _remove_directory(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for sub in ["events", "text"]:
		var child := "%s/%s" % [path, sub]
		if not DirAccess.dir_exists_absolute(child):
			continue
		for name in DirAccess.get_files_at(child):
			DirAccess.remove_absolute("%s/%s" % [child, name])
		DirAccess.remove_absolute(child)
	for name in DirAccess.get_files_at(path):
		DirAccess.remove_absolute("%s/%s" % [path, name])
	DirAccess.remove_absolute(path)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _report() -> void:
	if not _failures.is_empty():
		for failure in _failures:
			print("FAILURE %s" % failure)
		quit(1)
		return
	var terminals := 0
	var dialogue := 0
	var messages := 0
	for row in _rows:
		if str(row.terminal_offset) != "-1":
			terminals += 1
		dialogue += int(row.dialogue)
		messages += int(row.messages)
	print(
		"PASS: playback package playback: %d checks over %d catalog events; " % [_checks, _rows.size()]
		+ "%d reach a catalog-declared terminal, %d end at a declared place menu, %d continue into the next event, " % [terminals, _menu_endings, _chain_continuations]
		+ "%d dialogue boundaries and %d message payloads " % [
			dialogue,
			messages,
		]
		+ "run from the package alone with no archive access, matching the bytecode reference "
		+ "on segments, trace rows, message payloads, final state and terminal. Core %s / %s. " % [
			ContentCoreVersionScript.CORE_VERSION,
			ContentCoreVersionScript.PLAYBACK_PACKAGE_SCHEMA,
		]
		+ "Media, native presentation cadence and unselected choices are not part of this run."
	)
	quit(0)
