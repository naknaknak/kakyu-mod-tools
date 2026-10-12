class_name KakyuEventAnalysisGroupValidation
extends RefCounted

# TD-32 part 2 (2026-09-21): `validate_event_analysis_group.gd`'s `_init` used
# to do everything end to end - the Python audit, the schema flags, the
# archive open and identity check, the member parses, the probe context, the
# route runs (`_continue_route`/`_replace_route`, replays) and the canonical
# report. That per-profile validation moved here so
# `validate_event_analysis_groups.gd` can run every planned profile in one
# Godot process with the archive opened once, while the single-profile CLI
# keeps calling `validate()` and printing `result.report_json`. See
# analysis/_docs/td32_part2_groups_spec.md. What each check verifies did not
# change; only where the code lives did. The `--witness` path
# (`validate_event_analysis_group.gd`'s own `_run_witness`) stays in that CLI
# script, since it never calls `_check` or `_report`/`_finish` and produces
# its own quiet output - it reuses the handful of pure helpers below
# (`_map_locations`, `_carried`, `_dup_queues`, `_choices`, `_replay_terminal`)
# through an instance of this class instead of duplicating them again.
#
# WD-21 U2 C2 (2026-10-08): `--replay` now writes `kakyu_event_analysis_group_replay/v3`,
# v2 plus, per run, `executed` and `resource_rows` (what the run's probe result
# executed, and which media effects its own entries requested), computed by the
# shared `replay_run_media.gd` from the probe results this module already holds
# at its write sites. A site variant carries them as `prefix_executed` /
# `prefix_resource_rows` (the caller prefix, like `prefix_messages`), `executed` /
# `resource_rows` at the variant's top level (the callee run, like `messages` and
# `terminal`), and inside `resume`, `reentry` (the replacement reentry too) and
# every `visits` entry. Nothing else in the file changes, and a run without
# `--replay` does not reach any of it. See analysis/_docs/wd21_u2_spec.md D2.

const RunMedia := preload("res://tools/content_suite/replay_run_media.gd")
const Probe := preload("res://content_core/mes_route_probe.gd")
const State := preload("res://content_core/mes_sandbox_state.gd")
const Runner := preload("res://content_core/mes_event_runner.gd")
const ContainerScript := preload("res://content_core/mes_container.gd")
const Calendar := preload("res://content_core/mes_calendar_state.gd")
const ChoiceContract := preload("res://content_core/mes_routine40_choice_contract.gd")

## The schema `--replay` writes: v2 plus the per-run `executed` / `resource_rows`
## (WD-21 U2 C2); the v2 fields are unchanged.
const REPLAY_SCHEMA := "kakyu_event_analysis_group_replay/v3"

var failures: Array[String] = []
var checks := 0
var runtime_schema := "kakyu_event_analysis_group_runtime/v1"
var do_replay := false
var replay_path := ""
var replay_routes: Array = []
var reader: KakyuArcReader
## Counters over the runs `_replay_run_media` summarised, printed on the
## `REPLAY_WRITTEN` line (`definition_runs`: runs with a library-invoked
## definition; since Core 0.377.0 the probe keys its rows itself, so the rule
## only counts them).
var replay_media_totals := {"runs": 0, "definition_runs": 0, "definition_invokes": 0, "definition_rows": 0}


# `shared_reader`, when given, must already be open on `mes.arc`; this call
# uses it (only checking its fingerprint against this profile) and never
# closes it. Without one this call opens and closes its own reader, exactly
# as the single-profile CLI did before this move. `replay_path_arg` mirrors
# the CLI's own `--replay <path>` (empty means no replay file is written).
# `audited`, when non-empty (TD-32 part 2b), is used as the Python audit
# result in place of running the subprocess: `validate_event_analysis_groups.gd`
# runs the audit for every planned profile in one Python process ahead of the
# loop and passes each profile's own report here.
func validate(elfimage_path: String, profile_path: String, shared_reader: KakyuArcReader = null,
		replay_path_arg := "", audited: Dictionary = {}) -> Dictionary:
	var start_ticks := Time.get_ticks_usec()
	do_replay = replay_path_arg != ""
	replay_path = replay_path_arg
	var owns_reader: bool = shared_reader == null

	var exit_code := 0
	if audited.is_empty():
		var output: Array = []
		exit_code = OS.execute("py", ["tools/audit_event_analysis_group.py", elfimage_path, "--profile", profile_path], output, true)
		var parsed: Variant = JSON.parse_string("".join(output))
		audited = parsed if parsed is Dictionary else {}
	_check(exit_code == 0 and not audited.is_empty() and audited.get("ok", false), "Python exact source audit")
	if not failures.is_empty():
		return _finish({}, [], start_ticks)
	var profile: Dictionary = audited.profile
	# v9 is unguarded like v7 (no local guard, an unconditional_dispatch window
	# instead) but a caller-resume continuation like v8, not a root replacement.
	var unguarded: bool = profile.schema == "kakyu_event_analysis_group/v7" or profile.schema == "kakyu_event_analysis_group/v9"
	var replacement: bool = profile.schema == "kakyu_event_analysis_group/v6" or profile.schema == "kakyu_event_analysis_group/v7" or profile.schema == "kakyu_event_analysis_group/v11"
	# v8 is a returning callee like v5, not a replacement: only its caller-resume
	# boundary policy is new, and _check_outcome already reads that boundary.
	# v10 is v8 with a fourth resume policy, the caller's own loop; the probe
	# proves the loop and stops at its head, and _continue_route compares the
	# cycle it reports with the declared one.
	# v11 / v12 carry map-location contracts: v11 is a v6 replacement, v12 a
	# v10 continuation; every run of such a route supplies the declared
	# locations and the callee and unbroken runs must spend them all.
	var map_locations_v11: bool = profile.schema == "kakyu_event_analysis_group/v11"
	var map_locations_v12: bool = profile.schema == "kakyu_event_analysis_group/v12"
	var loop_resume: bool = profile.schema == "kakyu_event_analysis_group/v10" or map_locations_v12
	# v13 is v8's returning callee with one addition: an optional `visits`
	# list that replays the same callee further past the one committed
	# reentry, each visit from the state an earlier pass ("route", the state
	# the dispatch and caller resume left; "reentry"; or an earlier visit's
	# own visit_id) left plus its own seed writes.
	var visits_schema: bool = profile.schema == "kakyu_event_analysis_group/v13"
	var def_selection_resume: bool = profile.schema == "kakyu_event_analysis_group/v8" or profile.schema == "kakyu_event_analysis_group/v9" or loop_resume or visits_schema
	var observed_guard: bool = replacement or def_selection_resume or profile.schema == "kakyu_event_analysis_group/v5"
	var anchored: bool = observed_guard or profile.schema == "kakyu_event_analysis_group/v4"
	var extended: bool = anchored or profile.schema == "kakyu_event_analysis_group/v3"
	var continuation: bool = extended or profile.schema == "kakyu_event_analysis_group/v2"
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
	if owns_reader:
		reader = preload("res://content_core/arc_reader.gd").new()
		_check(reader.open(elfimage_path.path_join("mes.arc")) and reader.get_archive_fingerprint() == profile.archive_sha256, "original archive identity")
	else:
		reader = shared_reader
		_check(reader.get_archive_fingerprint() == profile.archive_sha256, "original archive identity")
	if not failures.is_empty():
		return _finish({}, [], start_ticks)
	var documents := {}
	for member in profile.source_members:
		_check(reader.get_entry_fingerprint(member.entry) == member.entry_sha256, "original member %s" % member.entry)
		documents[member.entry] = ContainerScript.new().parse(reader.read_entry(member.entry), {"entry":member.entry,"archive":"mes.arc"})
	var probe := Probe.new()
	var provider := probe.context_from_documents(documents)
	_check(provider.get("ok", false), "library and definition context")
	if not failures.is_empty():
		if owns_reader: reader.close()
		return _finish({}, [], start_ticks)
	var routes: Array = []
	for route in profile.routes:
		var caller: Dictionary = route.caller
		var callee: Dictionary = route.callee
		var guard: Dictionary = route.get("guard", {})
		var origin: int = int(route.origin_offset if anchored else guard.offset)
		# A nested root handoff is a root replacement whose caller record is a
		# command-0F call: the callee hands the root on and never returns, so the
		# prefix stops before the dispatch exactly as a continuation's does and
		# the unbroken run needs no follow request - the probe nests naturally.
		var nested_replacement: bool = replacement and str(route.caller_outcome.get("kind", "")) == "nested_root_handoff"
		var code: PackedByteArray = documents[caller.entry].bytecode
		if continuation:
			for contract in route.choice_contracts:
				var owner: String = contract.source_identity.entry if anchored else callee.entry
				var choice_code: PackedByteArray = documents[owner].bytecode
				var validated := ChoiceContract.new().validate(choice_code, choice_code.size(), contract)
				_check(validated.get("ok", false), "exact original choice consumer and definition contract: %s" % validated.get("error", ""))
		var prefix_provider: Dictionary = provider.duplicate()
		prefix_provider.entries = provider.entries.duplicate()
		# Deliberately leave this one callee out. The existing probe stops before
		# invoking it, exposing the exact dispatch and the actual carried state.
		if not observed_guard: prefix_provider.entries.erase(callee.entry)
		for witness in route.get("guard_cases", []):
			var state := State.new(1)
			_check(state.load_values(route.baseline).ok and state.load_values(witness.writes).ok, "guard witness state")
			var result := Runner.new().run(code, int(guard.offset), state, code.size(), 1)
			var trace: Array = result.get("trace", [])
			var row: Dictionary = trace[0] if trace.size() == 1 else {}
			_check(int(row.get("source_offset", -1)) == int(guard.offset) and int(row.get("end_offset", -1)) == int(guard.end)
				and int(row.get("condition_value", -1)) == int(witness.expected)
				and int(row.get("next_offset", -1)) == (int(guard.end) if int(witness.expected) == 1 else int(guard.false_target)),
				"%s guard %s" % [route.route_id, witness.case_id])
		# An unguarded dispatch has no condition to accept or reject. Each
		# selector witness must therefore still arrive at the same record: a
		# natural terminal for a root replacement's handoff (command 14, which
		# always halts the walk), or an exact dispatch stop for a continuation
		# whose dispatch (command 15) is a real call that would otherwise be
		# invoked for real.
		for witness in route.get("selection_cases", []):
			var selector_seed := _seed_route(route, witness.writes, documents, continuation)
			var selector_request: Dictionary = {"entry":caller.entry,"start_coordinate":origin,"map_locations":_map_locations(route)}
			if not replacement or nested_replacement:
				selector_request["stop_before_dispatch"] = {"entry":caller.entry,"offset":caller.offset,"end":caller.end,"target":callee.entry}
			var selector := probe.run_route(prefix_provider, selector_request, {}, selector_seed)
			var selector_trace: Array = selector.get("trace", [])
			var selector_row: Dictionary = selector_trace[-1] if not selector_trace.is_empty() else {}
			var selector_terminal: Dictionary = selector.get("terminal", {})
			var selector_reached: bool = (selector.get("ok", false) and selector.get("stop", "unexpected").is_empty()
					and selector_terminal.get("entry") == caller.entry and selector_terminal.get("status") == "script_handoff_boundary") \
				if replacement and not nested_replacement else (selector.get("ok", false) and selector.get("stop_detail", {}).get("status") == "analysis_dispatch_stop")
			_check(selector_reached
				and int(selector_row.get("source_offset", -1)) == int(caller.offset)
				and int(selector_row.get("end_offset", -1)) == int(caller.end)
				and int(selector_row.get("command_id", -1)) == int(caller.command)
				and str(selector_row.get("target_entry", "")).to_upper() == callee.entry,
				"%s selector %s still reaches the unconditional dispatch" % [route.route_id, witness.case_id])
			_check(selector.messages.size() == int(witness.caller_message_count),
				"%s selector %s caller message observation count" % [route.route_id, witness.case_id])
		var variants: Array = []
		var replay_variants: Array = []
		var coverage := {}
		var blocked_prefix := {}
		var caller_outcome: Dictionary = route.caller_outcome
		if caller_outcome.kind == "blocked_definition":
			blocked_prefix = probe.run_route(prefix_provider, {"entry":caller.entry,"start_coordinate":guard.offset,"map_locations":_map_locations(route)}, {"writes":route.baseline})
			var detail: Dictionary = blocked_prefix.get("stop_detail", {})
			_check(detail.get("status") == caller_outcome.status and detail.get("entry") == caller_outcome.entry
				and int(detail.get("offset", -1)) == int(caller_outcome.offset) and int(detail.get("definition_id", -1)) == int(caller_outcome.definition_id), "exact unresolved caller definition boundary")
		for variant in route.variants:
			var seed := _seed_route(route, variant.writes, documents, continuation)
			var choices: Array = _choices(variant, callee.entry) if continuation else []
			var prefix_request := {"entry":caller.entry,"start_coordinate":origin,"choices":choices,"map_locations":_map_locations(route)}
			if observed_guard and (not replacement or nested_replacement):
				prefix_request["stop_before_dispatch"] = {"entry":caller.entry,"offset":caller.offset,"end":caller.end,"target":callee.entry}
			var prefix: Dictionary = blocked_prefix if not blocked_prefix.is_empty() else probe.run_route(prefix_provider, prefix_request, {}, seed)
			var prefix_trace: Array = prefix.get("trace", [])
			var dispatch: Dictionary = prefix_trace[-1] if not prefix_trace.is_empty() else {}
			var stopped: bool = prefix.get("stop", "") == "nested entry %s is not a package member" % callee.entry
			if observed_guard:
				stopped = prefix.get("stop_detail", {}).get("status") == "analysis_dispatch_stop"
			if replacement and not nested_replacement:
				stopped = prefix.get("stop", "unexpected").is_empty() and prefix.get("terminal", {}).get("entry") == caller.entry \
					and prefix.get("terminal", {}).get("status") == "script_handoff_boundary"
			var reached: bool = prefix.get("ok", false) and stopped \
				and int(dispatch.get("source_offset", -1)) == int(caller.offset) and int(dispatch.get("end_offset", -1)) == int(caller.end) \
				and int(dispatch.get("command_id", -1)) == int(caller.command) and str(dispatch.get("target_entry", "")).to_upper() == callee.entry
			if caller_outcome.kind in ["dispatch", "root_handoff", "nested_root_handoff"]:
				_check(reached, "%s caller reaches exact intro: %s (%s)" % [route.route_id, variant.variant_id, prefix.get("stop", "")])
			if not reached and caller_outcome.kind in ["dispatch", "root_handoff", "nested_root_handoff"]:
				continue
			if observed_guard and not unguarded:
				_check(_accepted_guard(prefix_trace, caller.entry, guard), "caller origin executes the declared local guard's accepting edge")
			var entry_state: KakyuMesSandboxState = prefix.state_object if reached else seed
			var before_callee: Array = _carried(prefix) if reached else _map_locations(route)
			var result := probe.run_route(provider, {"entry": callee.entry, "start_coordinate": callee.offset, "choices": choices, "map_locations": _dup_queues(before_callee)}, {}, entry_state)
			_check_map_spend(_map_locations(route), prefix, route, "prefix", "%s %s" % [route.route_id, variant.variant_id], false)
			_check_map_spend(before_callee, result, route, "callee", "%s %s" % [route.route_id, variant.variant_id], replacement)
			var segments: Array = result.get("segments", [])
			var last: Dictionary = segments[-1] if not segments.is_empty() else {}
			var trace: Array = result.get("trace", [])
			var tail: Dictionary = trace[-1] if not trace.is_empty() else {}
			var expected: Dictionary = route.outcome
			var expected_stop := "" if expected.status == "script_return" else "no catalog choice at 0x%X in %s" % [int(expected.offset), callee.entry]
			if replacement:
				_check_outcome(result, callee.entry, expected, "%s exact replacement outcome %s" % [route.route_id, variant.variant_id])
			else:
				_check(result.get("ok", false) and result.get("stop", "unexpected") == expected_stop and last.get("entry") == callee.entry
					and last.get("status") == expected.status and int(last.get("offset", -1)) == int(expected.offset)
					and int(tail.get("end_offset", -1)) == int(expected.end), "%s exact callee outcome %s" % [route.route_id, variant.variant_id])
			var state: KakyuMesSandboxState = result.state_object
			for write in route.expected_state:
				_check(state.read_value(write.storage, int(write.index), int(write.bank)) == int(write.value), "callee state effect")
			_collect_coverage(trace, callee.entry, coverage)
			var measured := {"variant_id": variant.variant_id, "entry_state_origin":"carried_from_caller" if reached else "isolated_callee_caller_unresolved",
				"caller_state_diff": prefix.state_diff if reached else [],
				"status": last.get("status"), "offset": last.get("offset"), "end": tail.get("end_offset"), "stop": result.stop,
				"message_count": result.messages.size(), "state_diff": result.state_diff, "trace_sha256": result.signature}
			var replay_extra := {}
			if continuation:
				_check(result.messages.size() == int(variant.message_count), "callee message observation count")
				_check_state(state, variant.expected_state, "selected callee effects")
				if replacement:
					measured["replacement"] = _replace_route(probe, provider, route, variant, choices, seed, prefix, result, coverage, replay_extra)
				else:
					measured["continuation"] = _continue_route(probe, provider, route, variant, choices, seed, prefix, result, coverage, replay_extra)
			if extended:
				measured["caller_message_count"] = prefix.messages.size()
				measured["qualification"] = route.qualification
			variants.append(measured)
			if do_replay:
				var run_label := "%s %s" % [route.route_id, variant.variant_id]
				var prefix_media := _replay_run_media(prefix, run_label + " prefix", failures) if reached else {"executed": {}, "resource_rows": []}
				var callee_media := _replay_run_media(result, run_label + " callee", failures)
				replay_variants.append({
					"variant_id": variant.variant_id,
					"writes": variant.writes,
					"selections": variant.get("selections", []),
					"reached": reached,
					"prefix_messages": _message_rows(prefix, reader) if reached else [],
					"prefix_executed": prefix_media.executed,
					"prefix_resource_rows": prefix_media.resource_rows,
					"messages": _message_rows(result, reader),
					"executed": callee_media.executed,
					"resource_rows": callee_media.resource_rows,
					"terminal": _replay_terminal(result),
					"final_state": _replay_final_state(state, route, variant),
					"resume": replay_extra.get("resume", null),
					"reentry": replay_extra.get("reentry", null),
					"visits": replay_extra.get("visits", []),
					"state_changes": {
						"prefix": prefix.get("state_diff", []) if reached else [],
						"callee": result.get("state_diff", []),
						"resume": replay_extra.get("resume_state_diff", []),
					},
					"seed_writes": (route.baseline as Array) + (variant.writes as Array),
				})
		var branch_rows: Array = []
		for branch in audited.handoffs[callee.entry].branches:
			var values: Array = coverage.get(str(int(branch.offset)), [])
			values.sort()
			branch_rows.append({"offset": branch.offset, "observed_condition_values": values})
		var measured_route := {"route_id": route.route_id, "caller": caller, "guard": guard, "callee": callee,
			"unconditional_dispatch": route.get("unconditional_dispatch", {}),
			"caller_blocker":blocked_prefix.get("stop_detail", {}),
			"guard_case_count": route.get("guard_cases", []).size(),
			"selection_case_count": route.get("selection_cases", []).size(),
			"variants": variants, "branch_coverage": branch_rows,
			"unresolved": route.unresolved}
		if anchored:
			measured_route["origin_offset"] = origin
			measured_route["bypass_variants"] = _bypass_routes(probe, provider, route, documents)
		routes.append(measured_route)
		if do_replay:
			replay_routes.append({
				"route_id": route.route_id,
				"caller": {"entry": caller.entry, "offset": caller.offset, "end": caller.end, "command": caller.command},
				"callee": {"entry": callee.entry, "offset": callee.offset},
				"guard": {"offset": int(guard.offset), "end": int(guard.end), "false_target": int(guard.false_target)} if not guard.is_empty() else null,
				"origin_offset": origin,
				"variants": replay_variants,
			})
	# TD-32 part 2c: a shared reader's fingerprint is fixed at open time
	# (content_core/arc_reader.gd's `get_archive_fingerprint()`), so
	# reusing it here checks this profile against the archive the reader
	# opened rather than re-hashing the file for every profile; the multi
	# CLI (`validate_event_analysis_groups.gd`) hashes the file itself
	# once, after the last profile, to catch a change made during the
	# run. The single-profile CLI has no shared reader and keeps hashing
	# the file directly, exactly as before.
	if owns_reader:
		_check(FileAccess.get_sha256(elfimage_path.path_join("mes.arc")) == profile.archive_sha256, "original remains unchanged")
	else:
		_check(reader.get_archive_fingerprint() == profile.archive_sha256, "original remains unchanged")
	var final_result := _finish({"group_id": profile.group_id, "profile_sha256": profile.payload_sha256, "source_audit_sha256": audited.payload_sha256}, routes, start_ticks)
	if do_replay:
		var out := {
			"schema": REPLAY_SCHEMA,
			"profile": profile_path.get_file().get_basename(),
			"group_id": profile.group_id,
			"payload_sha256": profile.payload_sha256,
			"archive_sha256": profile.archive_sha256,
			"runtime_schema": runtime_schema,
			"routes": replay_routes,
		}
		var replay_dir := replay_path.get_base_dir()
		if replay_dir != "":
			DirAccess.make_dir_recursive_absolute(replay_dir)
		var replay_file := FileAccess.open(replay_path, FileAccess.WRITE)
		replay_file.store_string(JSON.stringify(out, "\t"))
		replay_file.close()
		var variant_total := 0
		for replay_route in replay_routes:
			variant_total += (replay_route as Dictionary).get("variants", []).size()
		print("REPLAY_WRITTEN %s routes=%d variants=%d %s" % [replay_path, replay_routes.size(), variant_total, replay_media_summary()])
	if owns_reader:
		reader.close()
	return final_result


func _continue_route(probe: KakyuMesRouteProbe, provider: Dictionary, route: Dictionary, variant: Dictionary,
	choices: Array, seed: KakyuMesSandboxState, prefix: Dictionary, callee_result: Dictionary, coverage: Dictionary,
	replay_extra: Dictionary = {}) -> Dictionary:
	# 0.319.0: every anchored continuation shape starts its unbroken run at the
	# route's typed origin; the list used to stop at v5, which never showed
	# while the origin was the guard, and shows once an arrival origin (the
	# floor's entry) lies before the guard.
	var anchored: bool = runtime_schema in ["kakyu_event_analysis_group_runtime/v4", "kakyu_event_analysis_group_runtime/v5",
		"kakyu_event_analysis_group_runtime/v8", "kakyu_event_analysis_group_runtime/v9",
		"kakyu_event_analysis_group_runtime/v10", "kakyu_event_analysis_group_runtime/v12",
		"kakyu_event_analysis_group_runtime/v13"]
	# v8 belongs here too (a returning callee like v5, per-variant reentry
	# overrides included) - omitting it left variant.reentry inert for v8.
	# v13 is v8 plus visits and needs the same per-variant reentry override.
	var extended: bool = anchored or runtime_schema in [
		"kakyu_event_analysis_group_runtime/v3",
		"kakyu_event_analysis_group_runtime/v8",
		"kakyu_event_analysis_group_runtime/v9",
		"kakyu_event_analysis_group_runtime/v10",
		"kakyu_event_analysis_group_runtime/v12",
		"kakyu_event_analysis_group_runtime/v13",
	]
	var caller: Dictionary = route.caller
	# A caller-loop resume asks the probe to prove the loop instead of spending
	# its segment budget in it; the other policies never reach a repeated
	# continuation, so the request changes nothing for them.
	var loop_policy: bool = str(route.resume.get("boundary_policy", "")) == "caller_menu_loop"
	var before_resume: Array = _carried(callee_result)
	var suffix_request := {"entry":caller.entry,"start_coordinate":route.resume.start,"choices":choices,"map_locations":_dup_queues(before_resume)}
	if loop_policy: suffix_request["detect_loops"] = true
	var suffix := probe.run_route(provider, suffix_request, {}, callee_result.state_object)
	_check_map_spend(before_resume, suffix, route, "resume", "caller resume", true)
	_check_outcome(suffix, caller.entry, route.resume.outcome, "exact caller handoff observation")
	if loop_policy:
		_check(_loop_matches(suffix.get("terminal", {}), route.resume.loop), "caller resume repeats the declared loop")
	_check(suffix.messages.size() == int(route.resume.message_count), "caller message observation count")
	_check_state(suffix.state_object, route.resume.expected_state, "caller completion effects")
	_check_state(suffix.state_object, variant.expected_resume_state, "selected caller effects")
	# Also execute the unbroken caller -> callee -> caller path. This proves the
	# segmented state inspection did not change temporary contexts or execution.
	# An unguarded route (v9) has no local guard at all, so it always starts the
	# unbroken run at its typed origin, the same coordinate an anchored route uses.
	var whole_start: int = route.origin_offset if (anchored or not route.has("guard")) else route.guard.offset
	var whole_request := {"entry":caller.entry,"start_coordinate":whole_start,"choices":choices,"map_locations":_map_locations(route)}
	if loop_policy: whole_request["detect_loops"] = true
	var whole := probe.run_route(provider, whole_request, {}, seed)
	_check_outcome(whole, caller.entry, route.resume.outcome, "unbroken caller path reaches the same handoff")
	_check_map_spend(_map_locations(route), whole, route, "whole", "unbroken caller path", true)
	if loop_policy:
		_check(_loop_matches(whole.get("terminal", {}), route.resume.loop), "unbroken caller path repeats the declared loop")
	_check(whole.state_object.snapshot() == suffix.state_object.snapshot()
		and whole.rows == prefix.rows + callee_result.rows + suffix.rows
		and whole.message_hex == prefix.message_hex + callee_result.message_hex + suffix.message_hex,
		"segmented and unbroken routes have identical trace, messages and written-value snapshots")
	# An unguarded route has no local guard to re-test after the continuation
	# completes. A guarded route defaults to asserting rejection (0), exactly
	# the prior unconditional behavior, unless it (or this variant) declares
	# post_guard_expected explicitly - a calendar-only guard need not close.
	var guard_trace: Array = []
	if route.has("guard"):
		var binding: Dictionary = provider.entries[caller.entry]
		var guard_run := Runner.new().run(binding.code, int(route.guard.offset), suffix.state_object.duplicate_state(), int(binding.code_size), 1)
		guard_trace = guard_run.get("trace", [])
		# A handful of already-shipped V8 profiles carry a route-level
		# post_guard_expected: null placeholder (JSON null survives the
		# dictionary lookup, unlike a genuinely missing key) - treat it the
		# same as absent, not a declared truth.
		var declared_post_guard = variant.get("post_guard_expected", route.get("post_guard_expected"))
		var expected_post_guard: int = int(declared_post_guard) if declared_post_guard != null else 0
		var expected_post_guard_next: int = int(route.guard.end) if expected_post_guard == 1 else int(route.guard.false_target)
		_check(guard_trace.size() == 1 and int(guard_trace[0].condition_value) == expected_post_guard
			and int(guard_trace[0].next_offset) == expected_post_guard_next, "post-continuation state rejects the local intro guard")
	var reentry := probe.run_route(provider, {"entry":route.callee.entry,"start_coordinate":route.callee.offset,"map_locations":_map_locations(route)}, {}, suffix.state_object)
	var reentry_spec: Dictionary = variant.get("reentry", route.reentry) if extended else route.reentry
	_check_outcome(reentry, route.callee.entry, reentry_spec.outcome, "post-continuation callee exact boundary")
	_check(reentry.messages.size() == int(reentry_spec.message_count), "post-continuation callee message count")
	_check_state(reentry.state_object, reentry_spec.expected_state, "post-continuation callee effects")
	_collect_coverage(reentry.trace, route.callee.entry, coverage)
	# v13's optional `visits`: further replays of the same returning callee
	# past this one committed reentry, each from the state an earlier pass
	# left (the two fixed passes "route" - what reentry itself starts from -
	# and "reentry", or an earlier visit's own visit_id) plus its own seed
	# writes. The audit already bound every `after` to a known pass with no
	# cycle or forward reference; empty for every schema but v13.
	var visit_states := {"route": suffix.state_object, "reentry": reentry.state_object}
	var visit_replays: Array = []
	for untyped_visit in route.get("visits", []):
		var visit: Dictionary = untyped_visit
		var visit_after_state: KakyuMesSandboxState = visit_states[str(visit.after)]
		# EP-11 part 1b: `entry_state` is checked against the `after` pass's
		# own state before the visit's own `seed_writes` apply - it is the
		# precondition that pass actually left, not a post-seed value.
		_check_state(visit_after_state, visit.get("entry_state", []), "visit %s entry_state" % visit.visit_id)
		var visit_seed: KakyuMesSandboxState = visit_after_state.duplicate_state()
		if not (visit.seed_writes as Array).is_empty():
			visit_seed.load_values(visit.seed_writes)
		var visit_result := probe.run_route(provider, {"entry":route.callee.entry,"start_coordinate":route.callee.offset,
			"map_locations":_map_locations(route)}, {}, visit_seed)
		_check_outcome(visit_result, route.callee.entry, visit.outcome, "visit %s exact callee boundary" % visit.visit_id)
		_check(visit_result.messages.size() == int(visit.message_count), "visit %s message count" % visit.visit_id)
		_check_state(visit_result.state_object, visit.expected_state, "visit %s effects" % visit.visit_id)
		_check(_visit_dispatches_match(visit_result, route.callee.entry, visit.dispatches),
			"visit %s exactly the declared dispatches occurred" % visit.visit_id)
		_collect_coverage(visit_result.trace, route.callee.entry, coverage)
		visit_states[str(visit.visit_id)] = visit_result.state_object
		if do_replay:
			# WD-23: `state_diff` (every cell the visit's own run actually
			# changed, not only the profile's curated `expected_state`) is
			# needed so a v5 document's per-visit `after` can be decided
			# the way v4 decides a result's effects - over every net-changed
			# cell, not only a declared subset (a gated visit's nested
			# dispatch writes cells its own `expected_state` never lists).
			var visit_media := _replay_run_media(visit_result, "%s %s visit %s" % [route.route_id, variant.variant_id, visit.visit_id], failures)
			visit_replays.append({"visit_id":visit.visit_id, "after":visit.after,
				"messages": _message_rows(visit_result, reader), "terminal": _replay_terminal(visit_result),
				"state_diff": visit_result.get("state_diff", []),
				"executed": visit_media.executed, "resource_rows": visit_media.resource_rows})
	if do_replay:
		var resume_media := _replay_run_media(suffix, "%s %s resume" % [route.route_id, variant.variant_id], failures)
		var reentry_media := _replay_run_media(reentry, "%s %s reentry" % [route.route_id, variant.variant_id], failures)
		replay_extra["resume"] = {
			"messages": _message_rows(suffix, reader),
			"terminal": _replay_terminal(suffix),
			"final_state": _replay_final_state(suffix.state_object, route, variant),
			"executed": resume_media.executed,
			"resource_rows": resume_media.resource_rows,
		}
		replay_extra["reentry"] = {
			"message_count": reentry.messages.size(),
			"terminal": _replay_terminal(reentry),
			"executed": reentry_media.executed,
			"resource_rows": reentry_media.resource_rows,
		}
		replay_extra["resume_state_diff"] = suffix.get("state_diff", [])
		# WD-23: `replay_extra["visits"]` used to stop here - the per-visit
		# message rows were computed but never copied into the persisted
		# `--replay` file (see the `replay_variants.append` call above),
		# so a v5 document had no per-visit dialogue evidence to read.
		if not visit_replays.is_empty(): replay_extra["visits"] = visit_replays
	var guard_rejected: bool = guard_trace.size() == 1 and int(guard_trace[0].condition_value) == 0
	var measured := {"state_context":route.state_context,"selections":variant.selections,
		"resume":_observation(suffix),"unbroken":_observation(whole),
		"reentry":_observation(reentry),"resume_source_binding":route.resume.outcome.source_binding}
	if extended:
		if route.has("guard"): measured["local_guard_rejected_after_continuation"] = guard_rejected
		measured["boundary_policy"] = route.resume.boundary_policy
	else:
		measured["completed_guard_rejected"] = guard_rejected
	return measured


func _replace_route(probe: KakyuMesRouteProbe, provider: Dictionary, route: Dictionary, variant: Dictionary,
	choices: Array, seed: KakyuMesSandboxState, prefix: Dictionary, target_result: Dictionary, coverage: Dictionary,
	replay_extra: Dictionary = {}) -> Dictionary:
	var caller: Dictionary = route.caller
	var whole_request: Dictionary = {"entry":caller.entry,"start_coordinate":route.origin_offset,"choices":choices,"map_locations":_map_locations(route)}
	if str(route.caller_outcome.get("kind", "")) != "nested_root_handoff":
		whole_request["follow_root_handoff"] = {"entry":caller.entry,"offset":caller.offset,"end":caller.end,"target":route.callee.entry}
	var whole := probe.run_route(provider, whole_request, {}, seed)
	_check_outcome(whole, route.callee.entry, route.outcome, "unbroken root replacement reaches the same target boundary")
	_check_map_spend(_map_locations(route), whole, route, "whole", "unbroken root replacement", true)
	_check(whole.state_object.snapshot() == target_result.state_object.snapshot()
		and whole.rows == prefix.rows + target_result.rows
		and whole.message_hex == prefix.message_hex + target_result.message_hex,
		"segmented and unbroken root replacements have identical trace, messages and written-value snapshots")
	var observed_guard := -1
	if route.has("guard"):
		var binding: Dictionary = provider.entries[caller.entry]
		var guard_run := Runner.new().run(binding.code, int(route.guard.offset), target_result.state_object.duplicate_state(), int(binding.code_size), 1)
		var guard_trace: Array = guard_run.get("trace", [])
		var expected_guard: int = int(variant.get("post_guard_expected", route.post_guard_expected))
		observed_guard = int(guard_trace[0].get("condition_value", -1)) if guard_trace.size() == 1 else -1
		_check(observed_guard == expected_guard and int(guard_trace[0].get("end_offset", -1)) == int(route.guard.end)
			and int(guard_trace[0].get("next_offset", -1)) == int(route.guard.end if expected_guard == 1 else route.guard.false_target),
			"post-replacement state has the declared local guard truth")
	var reentry := probe.run_route(provider, {"entry":route.callee.entry,"start_coordinate":route.callee.offset,"choices":choices,"map_locations":_map_locations(route)}, {}, target_result.state_object)
	var reentry_spec: Dictionary = variant.get("reentry", route.reentry)
	_check_outcome(reentry, route.callee.entry, reentry_spec.outcome, "post-replacement direct reentry reaches its exact boundary")
	_check(reentry.messages.size() == int(reentry_spec.message_count), "post-replacement direct reentry message count")
	_check_state(reentry.state_object, reentry_spec.expected_state, "post-replacement direct reentry effects")
	_collect_coverage(reentry.trace, route.callee.entry, coverage)
	if do_replay:
		var reentry_media := _replay_run_media(reentry, "%s %s reentry" % [route.route_id, variant.variant_id], failures)
		replay_extra["reentry"] = {
			"message_count": reentry.messages.size(),
			"terminal": _replay_terminal(reentry),
			"executed": reentry_media.executed,
			"resource_rows": reentry_media.resource_rows,
		}
	return {"state_context":route.state_context,"selections":variant.selections,
		"activation":_observation(prefix),"unbroken":_observation(whole),"local_guard_value_after_replacement":observed_guard,
		"reentry":_observation(reentry),"outcome_source_binding":route.outcome.source_binding,
		"reentry_source_binding":reentry_spec.outcome.source_binding}


func _check_map_spend(before: Array, result: Dictionary, route: Dictionary, run_name: String, label: String, final: bool) -> void:
	# 0.319.0: the segmented chain carries one queue (what the prefix leaves
	# is what the callee may spend, and the resume what the callee leaves),
	# so each contract names the runs that consume from it (absent: the
	# callee run) beside the unbroken run. A named run must consume; the
	# chain's last run and the unbroken run must leave nothing. Queues are
	# matched by entry and poll record.
	if not route.has("map_location_contracts"): return
	var after: Array = result.get("map_locations", [])
	for untyped_contract in route.map_location_contracts:
		var contract: Dictionary = untyped_contract
		var entry := str(contract.source_identity.entry)
		var offset := int(contract.poll_offset)
		var before_count := _queue_count(before, entry, offset, (contract.locations as Array).size())
		var after_count := _queue_count(after, entry, offset, -1)
		var spent_by: Array = contract.get("spent_by", ["callee", "whole"])
		if spent_by.has(run_name):
			_check(after_count >= 0 and after_count < before_count, "%s: the %s run spends map locations declared at %s:%d" % [label, run_name, entry, offset])
		if final:
			_check(after_count == 0, "%s: every map location declared at %s:%d is spent" % [label, entry, offset])


func _queue_count(queues: Array, entry: String, offset: int, fallback: int) -> int:
	for untyped_queue in queues:
		var queue: Dictionary = untyped_queue
		if str(queue.get("entry", "")) == entry and int(queue.get("poll_offset", -1)) == offset:
			return (queue.get("values", []) as Array).size()
	return fallback


func _carried(result: Dictionary) -> Array:
	return _dup_queues(result.get("map_locations", []))


func _dup_queues(queues: Array) -> Array:
	var copies := []
	for untyped_queue in queues:
		var queue: Dictionary = untyped_queue
		copies.append(queue.duplicate(true))
	return copies


func _map_locations(route: Dictionary) -> Array:
	# The declared contracts as fresh queues: the probe consumes them in place.
	return Probe.map_location_queues(route.get("map_location_contracts", []))


func _loop_matches(terminal: Dictionary, loop: Dictionary) -> bool:
	# The probe reports the cycle it proved (entry, offset, status per
	# segment), its period and the messages one period emitted; the profile
	# declares the same rows with their record ends, which the audit bound.
	var observed: Array = terminal.get("cycle", [])
	var declared: Array = loop.get("cycle", [])
	if (int(terminal.get("period", -1)) != int(loop.get("period", -2))
			or int(terminal.get("period_message_count", -1)) != int(loop.get("period_message_count", -2))
			or observed.size() != declared.size()):
		return false
	for index in range(declared.size()):
		var seen: Dictionary = observed[index]
		var expected: Dictionary = declared[index]
		if (str(seen.get("entry", "")) != str(expected.get("entry", "")) or int(seen.get("offset", -1)) != int(expected.get("offset", -2))
				or str(seen.get("status", "")) != str(expected.get("status", ""))):
			return false
	return true


func _visit_dispatches_match(result: Dictionary, callee_entry: String, declared: Array) -> bool:
	# v13's per-visit `dispatches`: exactly the declared nested calls, in
	# order, each an exact script_dispatch record of the callee and an exact
	# return record plus message count of the dispatched member. Anything
	# else observed - a missing, extra or reordered dispatch - fails.
	var observed: Array = []
	for untyped_row in result.get("trace", []):
		var row: Dictionary = untyped_row
		if row.get("source_entry") != callee_entry or str(row.get("effect", "")) != "script_dispatch_boundary":
			continue
		observed.append({"offset":int(row.get("source_offset", -1)), "end":int(row.get("end_offset", -1)),
			"target":str(row.get("target_entry", "")).to_upper()})
	if observed.size() != declared.size():
		return false
	var messages: Array = result.get("messages", [])
	for index in range(declared.size()):
		var expected: Dictionary = declared[index]
		var seen: Dictionary = observed[index]
		if int(seen.offset) != int(expected.offset) or int(seen.end) != int(expected.end) \
				or str(seen.target) != str(expected.entry).to_upper():
			return false
		var nested_ok := false
		for untyped_row in result.get("trace", []):
			var row: Dictionary = untyped_row
			if row.get("source_entry") == expected.entry and str(row.get("effect", "")) == "script_return" \
					and int(row.get("source_offset", -1)) == int(expected.outcome.offset) \
					and int(row.get("end_offset", -1)) == int(expected.outcome.end):
				nested_ok = true
		var nested_count := 0
		for untyped_message in messages:
			var message: Dictionary = untyped_message
			if message.get("source_entry") == expected.entry:
				nested_count += 1
		if not nested_ok or nested_count != int(expected.message_count):
			return false
	return true


func _accepted_guard(trace: Array, entry: String, guard: Dictionary) -> bool:
	for row in trace:
		if row.get("source_entry") == entry and row.get("source_offset", -1) == guard.offset:
			if row.get("end_offset", -1) == guard.end and row.get("condition_value", -1) == 1 and row.get("next_offset", -1) == guard.end:
				return true
	return false


func _seed_route(route: Dictionary, writes: Array, documents: Dictionary, continuation: bool) -> KakyuMesSandboxState:
	var seed := State.new(1)
	if continuation and route.state_context.kind == "original_calendar":
		var calendar := Calendar.new()
		var projection := calendar.build(documents[route.state_context.entry])
		_check(projection.get("ok", false) and projection.get("table_sha256") == route.state_context.table_sha256
			and calendar.apply_to_state(projection, seed).get("ok", false), "source-bound runtime calendar context")
	_check(seed.load_values(route.baseline).ok and seed.load_values(writes).ok, "route witness state")
	return seed


func _choices(variant: Dictionary, callee: String) -> Array:
	var choices: Array = []
	for selection in variant.selections:
		var owner: String = selection.owner_entry if runtime_schema in ["kakyu_event_analysis_group_runtime/v4", "kakyu_event_analysis_group_runtime/v5", "kakyu_event_analysis_group_runtime/v6", "kakyu_event_analysis_group_runtime/v10", "kakyu_event_analysis_group_runtime/v11", "kakyu_event_analysis_group_runtime/v12"] else callee
		choices.append({"owner_entry":owner,"boundary_offset":selection.boundary_offset,"options":[{"result_value":selection.result_value}]})
	return choices


func _bypass_routes(probe: KakyuMesRouteProbe, provider: Dictionary, route: Dictionary, documents: Dictionary) -> Array:
	var observations: Array = []
	for variant in route.get("bypass_variants", []):
		var seed := _seed_route(route, variant.writes, documents, true)
		var result := probe.run_route(provider, {"entry":route.caller.entry,"start_coordinate":route.origin_offset,
			"choices":_choices(variant, route.callee.entry),"map_locations":_map_locations(route)}, {}, seed)
		_check_outcome(result, route.caller.entry, variant.outcome, "bypass reaches exact caller handoff")
		_check(result.messages.size() == int(variant.message_count), "bypass message observation count")
		_check_state(result.state_object, variant.expected_state, "bypass caller effects")
		var skipped := true
		for row in result.trace:
			if row.source_entry == route.callee.entry or str(row.get("target_entry", "")).to_upper() == route.callee.entry:
				skipped = false
		_check(skipped, "bypass never dispatches or executes the callee")
		observations.append({"variant_id":variant.variant_id,"selections":variant.selections,
			"callee_skipped":skipped,"unbroken":_observation(result),"source_binding":variant.outcome.source_binding})
	return observations


func _observation(result: Dictionary) -> Dictionary:
	var observation := {"terminal":result.terminal,"stop":result.stop,"message_count":result.messages.size(),
		"state_diff":result.state_diff,"trace_sha256":result.signature}
	var trace: Array = result.get("trace", [])
	if not trace.is_empty() and int(trace[-1].get("command_id", -1)) == 15 and not result.stop.is_empty():
		var tail: Dictionary = trace[-1]
		observation["boundary"] = {"entry":tail.source_entry,"offset":tail.source_offset,"end":tail.end_offset,
			"status":"script_dispatch_boundary","target":str(tail.get("target_entry", "")).to_upper()}
	elif not trace.is_empty() and int(trace[-1].get("routine_id", -1)) == 40 and not result.stop.is_empty():
		var tail: Dictionary = trace[-1]
		observation["boundary"] = {"entry":tail.source_entry,"offset":tail.source_offset,"end":tail.end_offset,
			"status":"def_selection_boundary","target":""}
	return observation


func _check_outcome(result: Dictionary, entry: String, expected: Dictionary, label: String) -> void:
	if expected.status == "def_selection_boundary":
		var segments: Array = result.get("segments", [])
		var last: Dictionary = segments[-1] if not segments.is_empty() else {}
		var trace: Array = result.get("trace", [])
		var tail: Dictionary = trace[-1] if not trace.is_empty() else {}
		_check(result.get("ok", false) and result.get("terminal", {}).is_empty()
			and result.get("stop", "") == "no catalog choice at 0x%X in %s" % [int(expected.offset),entry]
			and last.get("status") == expected.status and last.get("entry") == entry
			and int(last.get("offset", -1)) == int(expected.offset)
			and tail.get("source_entry") == entry and int(tail.get("source_offset", -1)) == int(expected.offset)
			and int(tail.get("end_offset", -1)) == int(expected.end) and int(tail.get("command_id", -1)) == 29
			and int(tail.get("routine_id", -1)) == 40, label)
		return
	if expected.status == "script_dispatch_boundary":
		var segments: Array = result.get("segments", [])
		var last: Dictionary = segments[-1] if not segments.is_empty() else {}
		var trace: Array = result.get("trace", [])
		var tail: Dictionary = trace[-1] if not trace.is_empty() else {}
		_check(result.get("ok", false) and result.get("terminal", {}).is_empty()
			and result.get("stop", "") == "nested entry %s is not a package member" % expected.target
			and last.get("status") == expected.status and last.get("entry") == entry
			and int(last.get("offset", -1)) == int(expected.offset)
			and tail.get("source_entry") == entry and int(tail.get("source_offset", -1)) == int(expected.offset)
			and int(tail.get("end_offset", -1)) == int(expected.end) and int(tail.get("command_id", -1)) == 15
			and str(tail.get("target_entry", "")).to_upper() == expected.target, label)
		return
	var terminal: Dictionary = result.get("terminal", {})
	_check(result.get("ok", false) and result.get("stop", "unexpected").is_empty() and terminal.get("entry") == entry
		and terminal.get("status") == expected.status and int(terminal.get("offset", -1)) == int(expected.offset)
		and int(terminal.get("end", -1)) == int(expected.end) and terminal.get("target", "") == expected.get("target", ""), label)


func _check_state(state: KakyuMesSandboxState, writes: Array, label: String) -> void:
	for write in writes:
		_check(state.read_value(write.storage, int(write.index), int(write.bank)) == int(write.value), label)


func _collect_coverage(trace: Array, entry: String, coverage: Dictionary) -> void:
	for row in trace:
		if row.source_entry == entry and row.op == "branch_if_not_true":
			var key := str(row.source_offset)
			if not coverage.has(key): coverage[key] = []
			var value := int(row.condition_value)
			if value not in coverage[key]: coverage[key].append(value)


func _cell_key(row: Dictionary) -> String:
	return "%s:%d:%d" % [str(row.get("storage", "")), int(row.get("bank", 0)), int(row.get("index", -1))]


func _replay_final_state(state: KakyuMesSandboxState, route: Dictionary, variant: Dictionary) -> Array:
	var seen := {}
	var ordered: Array = []
	for source in [route.get("expected_state", []), variant.get("expected_state", []), variant.get("expected_resume_state", [])]:
		for untyped_write in source:
			var write: Dictionary = untyped_write
			var key := _cell_key(write)
			if not seen.has(key):
				seen[key] = true
				ordered.append(write)
	var rows := []
	for write in ordered:
		rows.append({"storage": write.storage, "bank": int(write.bank), "index": int(write.index),
			"value": state.read_value(write.storage, int(write.index), int(write.bank))})
	rows.sort_custom(func(a, b): return _cell_key(a) < _cell_key(b))
	return rows


func _replay_terminal(result: Dictionary) -> Dictionary:
	var segments: Array = result.get("segments", [])
	var last: Dictionary = segments[-1] if not segments.is_empty() else {}
	var trace: Array = result.get("trace", [])
	var tail: Dictionary = trace[-1] if not trace.is_empty() else {}
	var terminal: Dictionary = result.get("terminal", {})
	var target := ""
	if terminal.has("target"):
		target = str(terminal.target)
	elif tail.has("target_entry"):
		target = str(tail.get("target_entry", "")).to_upper()
	return {"entry": last.get("entry", ""), "status": last.get("status", ""),
		"offset": int(last.get("offset", -1)), "end": int(tail.get("end_offset", -1)), "target": target}


## The two fields replay v3 adds to one run (`{executed, resource_rows}`), from the
## run's whole probe result, through the shared `replay_run_media.gd`. A refusal of
## its attribution rule (an unterminated or nested library-invoked definition) is
## appended to `sink` - the caller's `failures` - and the run gets empty fields, so
## the replay fails rather than carrying a guess. Only called under `--replay`.
func _replay_run_media(run: Dictionary, label: String, sink: Array) -> Dictionary:
	var media := RunMedia.summarize(run)
	replay_media_totals.runs = int(replay_media_totals.runs) + 1
	if not media.ok:
		sink.append("replay executed rows of %s: %s" % [label, media.error])
		return {"executed": {}, "resource_rows": []}
	if int(media.definition_invokes) > 0:
		replay_media_totals.definition_runs = int(replay_media_totals.definition_runs) + 1
		replay_media_totals.definition_invokes = int(replay_media_totals.definition_invokes) + int(media.definition_invokes)
		replay_media_totals.definition_rows = int(replay_media_totals.definition_rows) + int(media.definition_rows)
	return {"executed": media.executed, "resource_rows": media.resource_rows}


## The `REPLAY_WRITTEN` line's media counters (both replay writers print them).
func replay_media_summary() -> String:
	return "runs=%d definition_runs=%d definition_invokes=%d definition_rows=%d" % [
		int(replay_media_totals.runs), int(replay_media_totals.definition_runs),
		int(replay_media_totals.definition_invokes), int(replay_media_totals.definition_rows)]


func _message_rows(direct: Dictionary, arc_reader: KakyuArcReader) -> Array:
	var trace_by_key := {}
	for untyped_row in direct.get("trace", []):
		var row: Dictionary = untyped_row
		var key := "%s:%d" % [str(row.get("source_entry", "")), int(row.get("source_offset", -1))]
		if not trace_by_key.has(key):
			trace_by_key[key] = row

	var rows := []
	for untyped_message in direct.get("messages", []):
		var message: Dictionary = untyped_message
		var entry := str(message.get("source_entry", ""))
		var offset := int(message.get("source_offset", -1))
		var key := "%s:%d" % [entry, offset]
		var trace_row: Dictionary = trace_by_key.get(key, {})
		var end_offset := int(trace_row.get("end_offset", -1))
		var raw_bytes: PackedByteArray = message.get("raw_bytes", PackedByteArray())
		var raw_sha256 := _sha256_bytes(raw_bytes)
		rows.append({
			"entry": entry,
			"offset": offset,
			"end": end_offset,
			"raw_sha256": raw_sha256,
		})
	return rows


func _sha256_bytes(bytes: PackedByteArray) -> String:
	if bytes.is_empty():
		return "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()


func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)


# Builds the canonical report Dictionary `_report` used to build, print and
# quit on directly, and now returns it (with its canonical JSON and this
# call's duration) instead - the caller decides whether to print, quit, or
# fold it into a multi-profile summary.
func _finish(identity: Dictionary, routes: Array, start_ticks: int) -> Dictionary:
	var report := {"ok": failures.is_empty(), "schema": runtime_schema, "identity": identity,
		"checks": checks, "failures": failures, "native_presentation": "omitted", "routes": routes}
	report["payload_sha256"] = preload("res://content_core/mes_payload_fingerprint.gd").new().fingerprint(report)
	var report_json := preload("res://content_core/mes_payload_fingerprint.gd").new().canonical_document_json(report)
	return {
		"ok": report["ok"],
		"checks": checks,
		"failures": failures,
		"runtime_schema": runtime_schema,
		"identity": identity,
		"routes": routes,
		"report": report,
		"report_json": report_json,
		"duration_seconds": (Time.get_ticks_usec() - start_ticks) / 1000000.0,
	}
