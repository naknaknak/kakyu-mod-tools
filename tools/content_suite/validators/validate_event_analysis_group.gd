extends SceneTree

# TD-32 part 2 (2026-09-21): the per-profile validation this CLI used to run
# end to end now lives in `KakyuEventAnalysisGroupValidation`
# (tools/content_suite/event_analysis_group_validation.gd), so
# `validate_event_analysis_groups.gd` can run every planned profile in one
# Godot process with the archive opened once. This script keeps its CLI
# exactly (arguments, `--replay`, `--witness`, exit codes, the printed
# canonical JSON); its main path is now parse arguments, call the module,
# print `result.report_json`, quit. `--witness` is a separate quiet mode with
# its own output (never `_check`/`_report`) that stayed here; it reuses the
# module's pure helpers (`_map_locations`, `_carried`, `_dup_queues`,
# `_choices`, `_replay_terminal`) through `_shared` instead of duplicating
# them again. See analysis/_docs/td32_part2_groups_spec.md.

const Module := preload("res://tools/content_suite/event_analysis_group_validation.gd")
const FlowModule := preload("res://tools/content_suite/event_analysis_group_flow_validation.gd")
const Probe := preload("res://content_core/mes_route_probe.gd")
const State := preload("res://content_core/mes_sandbox_state.gd")
const Runner := preload("res://content_core/mes_event_runner.gd")
const ContainerScript := preload("res://content_core/mes_container.gd")
const Calendar := preload("res://content_core/mes_calendar_state.gd")
const ChoiceContract := preload("res://content_core/mes_routine40_choice_contract.gd")
const DEFAULT_PROFILE := "config/event_catalog/analysis_groups/ground_h17_k09_v2.json"
var reader: KakyuArcReader
# The witness path re-derives the same route-kind classification the module's
# `validate()` uses for the normal path, quietly (see `_run_witness` below);
# it shares the module's pure per-route helpers through this instance.
var _shared := Module.new()
var runtime_schema := "kakyu_event_analysis_group_runtime/v1"


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 1:
		quit(2)
		return
	var elfimage_path: String = args[0]
	var profile_arg := DEFAULT_PROFILE
	var profile_given := false
	var do_replay := false
	var replay_path := ""
	var do_witness := false
	var witness_requests_path := ""
	var witness_out_path := ""
	var index := 1
	while index < args.size():
		if args[index] == "--replay":
			if index + 1 >= args.size():
				quit(2)
				return
			do_replay = true
			replay_path = args[index + 1]
			index += 2
		elif args[index] == "--witness":
			if index + 2 >= args.size():
				quit(2)
				return
			do_witness = true
			witness_requests_path = args[index + 1]
			witness_out_path = args[index + 2]
			index += 3
		elif not profile_given and not str(args[index]).begins_with("--"):
			profile_arg = args[index]
			profile_given = true
			index += 1
		else:
			quit(2)
			return
	if do_replay and do_witness:
		quit(2)
		return
	if do_witness:
		_run_witness(elfimage_path, profile_arg, witness_requests_path, witness_out_path)
		return
	if _profile_schema(profile_arg) == FlowModule.PROFILE_SCHEMA:
		# EP-12 part 2 (2026-09-24), extended EP-12 / WD unit 2 (2026-09-25):
		# a v14 flow profile has no per-route caller/callee pair for the
		# shared module's checks to interleave into, so it runs through its
		# own sibling validator instead - `--replay` now reaches it too,
		# through the same `_shared` helpers the v6/v13 replay path uses
		# (one code path). `--witness` is handled above for every non-v14
		# profile schema (v2..v13 pick their runtime schema in `_run_witness`);
		# it does no schema check, so a v14 flow profile must not be passed to
		# it (flow documents never use witnesses and the planner skips their
		# replays, TD-37).
		var flow_result := FlowModule.new().validate(elfimage_path, profile_arg, replay_path if do_replay else "", _shared)
		print(JSON.stringify(flow_result))
		quit(0 if flow_result.ok else 1)
		return
	var module := Module.new()
	var result := module.validate(elfimage_path, profile_arg, null, replay_path if do_replay else "")
	print(result.report_json)
	quit(0 if result.ok else 1)


# A profile's own `schema` field, read without loading it through the
# Python audit - just enough to route this CLI to the right validator.
func _profile_schema(profile_path: String) -> String:
	var file := FileAccess.open(profile_path, FileAccess.READ)
	if file == null:
		return ""
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return str((parsed as Dictionary).get("schema", "")) if parsed is Dictionary else ""


# --- Event definition v4 unit 1b: --witness ---------------------------------
# A separate, self-contained path: it never calls `_check` (the module's
# checks/failures stay untouched) and never calls `_report`/`_finish`. It
# re-derives the same route-kind classification the normal path uses, seeds
# each requested variant exactly as `_seed_route` does (duplicated here,
# quietly, without its `_check` calls), and runs the same "whole" unbroken
# request `_continue_route`/`_replace_route` build for that route kind
# (duplicated here too, quietly, rather than reusing those functions, since
# they are inseparable from `_check` calls and from producing
# continuation/replacement side data this mode does not need).
func _run_witness(elfimage_path: String, profile_arg: String, witness_requests_path: String, witness_out_path: String) -> void:
	var output: Array = []
	var exit_code := OS.execute("py", ["tools/audit_event_analysis_group.py", elfimage_path, "--profile", profile_arg], output, true)
	var audited: Variant = JSON.parse_string("".join(output))
	if not (exit_code == 0 and audited is Dictionary and audited.get("ok", false)):
		printerr("witness: Python exact source audit failed")
		quit(1)
		return
	var profile: Dictionary = audited.profile
	reader = preload("res://content_core/arc_reader.gd").new()
	if not (reader.open(elfimage_path.path_join("mes.arc")) and reader.get_archive_fingerprint() == profile.archive_sha256):
		printerr("witness: original archive identity mismatch")
		quit(1)
		return
	var documents := {}
	for member in profile.source_members:
		if reader.get_entry_fingerprint(member.entry) != member.entry_sha256:
			printerr("witness: original member fingerprint mismatch: %s" % member.entry)
			reader.close()
			quit(1)
			return
		documents[member.entry] = ContainerScript.new().parse(reader.read_entry(member.entry), {"entry":member.entry,"archive":"mes.arc"})
	var probe := Probe.new()
	var provider := probe.context_from_documents(documents)
	if not provider.get("ok", false):
		printerr("witness: library and definition context failed")
		reader.close()
		quit(1)
		return

	var replacement: bool = profile.schema == "kakyu_event_analysis_group/v6" or profile.schema == "kakyu_event_analysis_group/v7" or profile.schema == "kakyu_event_analysis_group/v11"
	var map_locations_v12: bool = profile.schema == "kakyu_event_analysis_group/v12"
	var loop_resume: bool = profile.schema == "kakyu_event_analysis_group/v10" or map_locations_v12
	# v13 is v8's returning callee plus visits; the witness path needs the
	# same def-selection/observed-guard classification v8 gets, exactly as
	# the normal path (event_analysis_group_validation.gd) does.
	var visits_schema: bool = profile.schema == "kakyu_event_analysis_group/v13"
	var def_selection_resume: bool = profile.schema == "kakyu_event_analysis_group/v8" or profile.schema == "kakyu_event_analysis_group/v9" or loop_resume or visits_schema
	var observed_guard: bool = replacement or def_selection_resume or profile.schema == "kakyu_event_analysis_group/v5"
	var anchored: bool = observed_guard or profile.schema == "kakyu_event_analysis_group/v4"
	var extended: bool = anchored or profile.schema == "kakyu_event_analysis_group/v3"
	var continuation: bool = extended or profile.schema == "kakyu_event_analysis_group/v2"
	var unguarded: bool = profile.schema == "kakyu_event_analysis_group/v7" or profile.schema == "kakyu_event_analysis_group/v9"
	var map_locations_v11: bool = profile.schema == "kakyu_event_analysis_group/v11"
	# _choices reads runtime_schema to decide which script owns a selection; the
	# normal path sets it from the profile schema and the witness path must too.
	if continuation: runtime_schema = "kakyu_event_analysis_group_runtime/v2"
	if extended: runtime_schema = "kakyu_event_analysis_group_runtime/v3"
	if anchored: runtime_schema = "kakyu_event_analysis_group_runtime/v4"
	if observed_guard: runtime_schema = "kakyu_event_analysis_group_runtime/v5"
	if replacement: runtime_schema = "kakyu_event_analysis_group_runtime/v6"
	if unguarded: runtime_schema = "kakyu_event_analysis_group_runtime/v7"
	if def_selection_resume: runtime_schema = "kakyu_event_analysis_group_runtime/v8"
	if profile.schema == "kakyu_event_analysis_group/v9": runtime_schema = "kakyu_event_analysis_group_runtime/v9"
	if loop_resume: runtime_schema = "kakyu_event_analysis_group_runtime/v10"
	if map_locations_v11: runtime_schema = "kakyu_event_analysis_group_runtime/v11"
	if map_locations_v12: runtime_schema = "kakyu_event_analysis_group_runtime/v12"
	if visits_schema: runtime_schema = "kakyu_event_analysis_group_runtime/v13"
	_shared.runtime_schema = runtime_schema

	var routes_by_id := {}
	for route in profile.routes:
		routes_by_id[str((route as Dictionary).route_id)] = route

	var requests_text := FileAccess.get_file_as_string(witness_requests_path)
	var requests_doc: Variant = JSON.parse_string(requests_text)
	if not (requests_doc is Dictionary):
		printerr("witness: could not read requests file %s" % witness_requests_path)
		reader.close()
		quit(1)
		return
	var requests: Array = requests_doc.get("requests", [])
	var results: Array = []
	for request_index in range(requests.size()):
		var request: Dictionary = requests[request_index]
		var route: Dictionary = routes_by_id.get(str(request.get("route_id", "")), {})
		if route.is_empty():
			results.append({"request_index": request_index, "error": "unknown route_id %s" % str(request.get("route_id", ""))})
			continue
		var variant: Dictionary = {}
		for untyped_variant in route.variants:
			var candidate: Dictionary = untyped_variant
			if str(candidate.variant_id) == str(request.get("variant_id", "")):
				variant = candidate
				break
		if variant.is_empty():
			results.append({"request_index": request_index, "error": "unknown variant_id %s in route %s" % [str(request.get("variant_id", "")), str(request.route_id)]})
			continue
		var kind := str(request.get("kind", ""))
		if kind == "shift":
			results.append(_witness_shift(probe, provider, documents, route, variant, request, request_index,
				replacement, continuation, anchored, observed_guard))
		elif kind == "done_probe":
			results.append(_witness_done_probe(probe, provider, documents, route, variant, request, request_index,
				replacement, continuation, anchored, observed_guard))
		else:
			results.append({"request_index": request_index, "error": "unknown request kind %s" % kind})

	var out := {
		"schema": "kakyu_event_effect_witness/v1",
		"group_id": requests_doc.get("group_id", profile.group_id),
		"profile": requests_doc.get("profile", profile_arg.get_file().get_basename()),
		"payload_sha256": requests_doc.get("payload_sha256", profile.payload_sha256),
		"results": results,
	}
	var out_dir := witness_out_path.get_base_dir()
	if out_dir != "":
		DirAccess.make_dir_recursive_absolute(out_dir)
	var out_file := FileAccess.open(witness_out_path, FileAccess.WRITE)
	out_file.store_string(JSON.stringify(out, "\t"))
	out_file.close()
	print("WITNESS_WRITTEN %s results=%d" % [witness_out_path, results.size()])
	reader.close()
	quit(0)


# The seed construction the module's `_seed_route` performs, without its
# `_check` calls.
func _witness_seed_route(route: Dictionary, writes: Array, documents: Dictionary, continuation: bool) -> KakyuMesSandboxState:
	var seed := State.new(1)
	if continuation and route.state_context.kind == "original_calendar":
		var calendar := Calendar.new()
		var projection := calendar.build(documents[route.state_context.entry])
		calendar.apply_to_state(projection, seed)
	seed.load_values(route.baseline)
	seed.load_values(writes)
	return seed


# The whole_request the module's `_continue_route` (non-replacement) or
# `_replace_route` (replacement) builds for its unbroken run, for the same
# route.
func _witness_whole_request(route: Dictionary, replacement: bool, anchored: bool, choices: Array) -> Dictionary:
	var caller: Dictionary = route.caller
	if replacement:
		var whole_request: Dictionary = {"entry":caller.entry,"start_coordinate":route.origin_offset,"choices":choices,"map_locations":_shared._map_locations(route)}
		if str(route.caller_outcome.get("kind", "")) != "nested_root_handoff":
			whole_request["follow_root_handoff"] = {"entry":caller.entry,"offset":caller.offset,"end":caller.end,"target":route.callee.entry}
		return whole_request
	var loop_policy: bool = str(route.resume.get("boundary_policy", "")) == "caller_menu_loop"
	var whole_start: int = route.origin_offset if (anchored or not route.has("guard")) else route.guard.offset
	var whole_request := {"entry":caller.entry,"start_coordinate":whole_start,"choices":choices,"map_locations":_shared._map_locations(route)}
	if loop_policy: whole_request["detect_loops"] = true
	return whole_request


# The segmented prefix + callee pair the variant loop always runs (the
# module's normal path), quietly: used for every route kind's "first visit's
# callee messages" (the done probe) and as the baseline itself for a route
# kind with no unbroken "whole" run today (schema v1: continuation is false,
# so neither `_continue_route` nor `_replace_route` ever runs).
func _witness_segmented_run(probe: KakyuMesRouteProbe, provider: Dictionary, route: Dictionary, seed: KakyuMesSandboxState,
		choices: Array, origin: int, observed_guard: bool, replacement: bool, nested_replacement: bool) -> Dictionary:
	var caller: Dictionary = route.caller
	var callee: Dictionary = route.callee
	var prefix_provider: Dictionary = provider.duplicate()
	prefix_provider.entries = provider.entries.duplicate()
	if not observed_guard: prefix_provider.entries.erase(callee.entry)
	var prefix_request := {"entry":caller.entry,"start_coordinate":origin,"choices":choices,"map_locations":_shared._map_locations(route)}
	if observed_guard and (not replacement or nested_replacement):
		prefix_request["stop_before_dispatch"] = {"entry":caller.entry,"offset":caller.offset,"end":caller.end,"target":callee.entry}
	var prefix: Dictionary = probe.run_route(prefix_provider, prefix_request, {}, seed)
	var stopped: bool = prefix.get("stop", "") == "nested entry %s is not a package member" % callee.entry
	if observed_guard:
		stopped = prefix.get("stop_detail", {}).get("status") == "analysis_dispatch_stop"
	if replacement and not nested_replacement:
		stopped = prefix.get("stop", "unexpected").is_empty() and prefix.get("terminal", {}).get("entry") == caller.entry \
			and prefix.get("terminal", {}).get("status") == "script_handoff_boundary"
	var prefix_trace: Array = prefix.get("trace", [])
	var dispatch: Dictionary = prefix_trace[-1] if not prefix_trace.is_empty() else {}
	var reached: bool = prefix.get("ok", false) and stopped \
		and int(dispatch.get("source_offset", -1)) == int(caller.offset) and int(dispatch.get("end_offset", -1)) == int(caller.end) \
		and int(dispatch.get("command_id", -1)) == int(caller.command) and str(dispatch.get("target_entry", "")).to_upper() == callee.entry
	var entry_state: KakyuMesSandboxState = prefix.state_object if reached else seed
	var before_callee: Array = _shared._carried(prefix) if reached else _shared._map_locations(route)
	var callee_result := probe.run_route(provider, {"entry": callee.entry, "start_coordinate": callee.offset, "choices": choices, "map_locations": _shared._dup_queues(before_callee)}, {}, entry_state)
	return {"prefix": prefix, "callee": callee_result, "reached": reached}


# The baseline the shift and done-probe witnesses both start from: the same
# request the existing "whole" run uses for a continuation or replacement
# route; the segmented prefix+callee pair (concatenated) when the route kind
# has no unbroken run today.
func _witness_baseline_run(probe: KakyuMesRouteProbe, provider: Dictionary, route: Dictionary, seed: KakyuMesSandboxState,
		choices: Array, origin: int, observed_guard: bool, replacement: bool, nested_replacement: bool, continuation: bool, anchored: bool) -> Dictionary:
	if continuation:
		var whole_request := _witness_whole_request(route, replacement, anchored, choices)
		var whole := probe.run_route(provider, whole_request, {}, seed)
		return {"state": whole.state_object, "message_hex": whole.message_hex, "terminal": _shared._replay_terminal(whole), "unbroken_run": "whole"}
	var segmented := _witness_segmented_run(probe, provider, route, seed, choices, origin, observed_guard, replacement, nested_replacement)
	var callee_result: Dictionary = segmented.callee
	var prefix_result: Dictionary = segmented.prefix
	var combined_hex: Array = (prefix_result.message_hex if segmented.reached else []) + callee_result.message_hex
	return {"state": callee_result.state_object, "message_hex": combined_hex, "terminal": _shared._replay_terminal(callee_result), "unbroken_run": "sequential_prefix_callee"}


func _witness_message_sha256(message_hex: Array) -> String:
	return JSON.stringify(message_hex).sha256_text()


func _witness_in_range(storage: String, value: int) -> bool:
	match storage:
		"global_u8", "banked_u8", "relative_u8":
			return value >= 0 and value <= 255
		"state_u16", "banked_u16":
			return value >= 0 and value <= 65535
		"state_i32", "global_i32", "banked_i32":
			return value >= 0 and value <= 4294967295
		_:
			return false


func _witness_shift(probe: KakyuMesRouteProbe, provider: Dictionary, documents: Dictionary, route: Dictionary, variant: Dictionary,
		request: Dictionary, request_index: int, replacement: bool, continuation: bool, anchored: bool, observed_guard: bool) -> Dictionary:
	var cell: Dictionary = request.cell
	var storage := str(cell.storage)
	var bank := int(cell.bank)
	var cell_index := int(cell.index)
	var entry_value := int(request.entry)
	var guard: Dictionary = route.get("guard", {})
	var origin: int = int(route.origin_offset if anchored else guard.offset)
	var choices: Array = _shared._choices(variant, route.callee.entry) if continuation else []
	var nested_replacement: bool = replacement and str(route.caller_outcome.get("kind", "")) == "nested_root_handoff"

	var seed := _witness_seed_route(route, variant.writes, documents, continuation)
	var baseline := _witness_baseline_run(probe, provider, route, seed, choices, origin, observed_guard, replacement, nested_replacement, continuation, anchored)
	var baseline_state: KakyuMesSandboxState = baseline.state
	var baseline_final := baseline_state.read_value(storage, cell_index, bank)
	var baseline_hash := _witness_message_sha256(baseline.message_hex)
	var baseline_terminal: Dictionary = baseline.terminal

	var tried: Array = []
	var steps: Array[int] = [7, -7, 1, -1]
	for step in steps:
		var shifted_entry: int = entry_value + step
		if not _witness_in_range(storage, shifted_entry):
			continue
		var shifted_seed := seed.duplicate_state()
		shifted_seed.write_value(storage, cell_index, shifted_entry, bank)
		var shifted := _witness_baseline_run(probe, provider, route, shifted_seed, choices, origin, observed_guard, replacement, nested_replacement, continuation, anchored)
		var shifted_state: KakyuMesSandboxState = shifted.state
		var shifted_final: int = shifted_state.read_value(storage, cell_index, bank)
		var shifted_hash := _witness_message_sha256(shifted.message_hex)
		var shifted_terminal: Dictionary = shifted.terminal
		if shifted_hash == baseline_hash and shifted_terminal == baseline_terminal:
			var delta: int = shifted_final - baseline_final
			var outcome_kind := "add" if delta == step else ("set" if shifted_final == baseline_final else "other")
			return {"request_index": request_index, "cell": cell, "entry": entry_value, "final": baseline_final,
				"step": step, "shifted_entry": shifted_entry, "shifted_final": shifted_final,
				"path_same": true, "kind": outcome_kind, "unbroken_run": baseline.unbroken_run}
		tried.append({"step": step, "shifted_entry": shifted_entry, "shifted_final": shifted_final,
			"message_sha256": shifted_hash, "terminal": shifted_terminal})
	return {"request_index": request_index, "cell": cell, "entry": entry_value, "final": baseline_final,
		"path_same": false, "kind": "path_changes", "tried": tried, "unbroken_run": baseline.unbroken_run}


func _witness_done_probe(probe: KakyuMesRouteProbe, provider: Dictionary, documents: Dictionary, route: Dictionary, variant: Dictionary,
		request: Dictionary, request_index: int, replacement: bool, continuation: bool, anchored: bool, observed_guard: bool) -> Dictionary:
	var guard: Dictionary = route.get("guard", {})
	var origin: int = int(route.origin_offset if anchored else guard.offset)
	var choices: Array = _shared._choices(variant, route.callee.entry) if continuation else []
	var nested_replacement: bool = replacement and str(route.caller_outcome.get("kind", "")) == "nested_root_handoff"

	var seed := _witness_seed_route(route, variant.writes, documents, continuation)
	var baseline := _witness_baseline_run(probe, provider, route, seed, choices, origin, observed_guard, replacement, nested_replacement, continuation, anchored)
	var baseline_state: KakyuMesSandboxState = baseline.state

	# The first visit's callee-only messages: the same segmented callee run
	# every route kind's normal path produces (route.callee.offset onward),
	# independent of whether this route kind also has a "whole" run.
	var segmented := _witness_segmented_run(probe, provider, route, seed.duplicate_state(), choices, origin, observed_guard, replacement, nested_replacement)
	var first_visit_callee: Dictionary = segmented.callee
	var first_visit_hash := _witness_message_sha256(first_visit_callee.message_hex)

	var gates: Array = []
	var per_cell: Array = []
	var control := probe.run_route(provider, {"entry":route.callee.entry,"start_coordinate":route.callee.offset,"map_locations":_shared._map_locations(route)}, {}, baseline_state.duplicate_state())
	per_cell.append({"cell": null, "entry": null, "reentry_message_count": control.messages.size(), "replays_scene": control.messages.size() > 0 and _witness_message_sha256(control.message_hex) == first_visit_hash, "control": true,
		"baseline_terminal": baseline.terminal, "expected_resume_outcome": route.resume.outcome if route.has("resume") else null,
		"whole_messages": baseline.message_hex.size()})
	for untyped_cell in request.get("cells", []):
		var cell_request: Dictionary = untyped_cell
		var storage := str(cell_request.storage)
		var bank := int(cell_request.bank)
		var cell_index := int(cell_request.index)
		var entry_value := int(cell_request.entry)
		var restored := baseline_state.duplicate_state()
		restored.write_value(storage, cell_index, entry_value, bank)
		var reentry_request: Dictionary
		if replacement:
			reentry_request = {"entry":route.callee.entry,"start_coordinate":route.callee.offset,"choices":choices,"map_locations":_shared._map_locations(route)}
		else:
			reentry_request = {"entry":route.callee.entry,"start_coordinate":route.callee.offset,"map_locations":_shared._map_locations(route)}
		var reentry := probe.run_route(provider, reentry_request, {}, restored)
		var reentry_hash := _witness_message_sha256(reentry.message_hex)
		var cell_dict := {"storage": storage, "bank": bank, "index": cell_index}
		var message_count: int = reentry.messages.size()
		var replays_scene: bool = message_count > 0 and reentry_hash == first_visit_hash
		if message_count > 0:
			gates.append(cell_dict)
		per_cell.append({"cell": cell_dict, "entry": entry_value,
			"reentry_message_count": message_count, "replays_scene": replays_scene})
	return {"request_index": request_index, "gates": gates, "per_cell": per_cell, "unbroken_run": baseline.unbroken_run}
