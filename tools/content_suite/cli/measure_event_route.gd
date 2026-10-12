extends SceneTree

# Spec-driven measurement of one EVENT intro route (root handoff into a callee
# that leaves by one door), replacing the per-route copies of
# analysis/35m_i13_measure.gd. Usage:
#
#   godot --headless --path . --script res://tools/content_suite/cli/measure_event_route.gd \
#       -- "<ELFIMAGE dir>" analysis/<route>_spec.json analysis/<route>_measure.json
#
# The spec (tools/draft_event_route_spec.py) names the caller, callee, members,
# guard, call record, baseline seed, guard witnesses, variants (optional
# `direct`: run the callee from the baseline prefix state with the writes
# applied; optional `result`: the callee answer this row is measured at), the
# optional caller question (`caller_choice`: {boundary, result_value,
# result_values}) and the optional callee question (`callee_question`:
# {routine40, result_values}). Output mirrors the hand-written probes:
# guard_cases, route (prefix/target/whole + return record), identical,
# post_guard (with guard-cell writes before/after per owner), reentry,
# diagnostics, profile_cells (two-pass), variants with profile_cell_effects,
# contracts, and per-result blocks when the callee asks.

const Probe := preload("res://content_core/mes_route_probe.gd")
const State := preload("res://content_core/mes_sandbox_state.gd")
const Runner := preload("res://content_core/mes_event_runner.gd")
const ContainerScript := preload("res://content_core/mes_container.gd")
const Calendar := preload("res://content_core/mes_calendar_state.gd")
const ChoiceContract := preload("res://content_core/mes_routine40_choice_contract.gd")

var spec := {}
var documents := {}
var provider: Dictionary
var probe: KakyuMesRouteProbe
var projection: Dictionary
var calendar: KakyuMesCalendarState
var not_a_package_member := []
var caller: String
var callee: String
var origin: int
var guard_offset: int
var guard_end: int
var guard_false: int
var call_offset: int
var call_end: int
var guard_cells := []
var calendar_cells := []
var reported := []
var caller_choices := []
# A nested call (command 0x0F): the callee returns and the caller resumes at
# the dispatch end; the resume walk is measured to its natural stop (a root
# handoff, the caller's own routine-40 without a supplied choice, a dispatch
# to a script outside the package, or - with the probe's loop detection - the
# caller's own loop, proven by a repeated continuation).
var nested := false
# 0.318.0: map-location contracts from the spec ({entry, poll_offset,
# locations}); every run of the route supplies them, and the baseline target
# must spend them all.
var map_location_contracts := []


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var elfimage: String = args[0]
	var spec_path: String = args[1]
	var out_path: String = args[2]
	spec = JSON.parse_string(FileAccess.get_file_as_string(spec_path))
	caller = str(spec.caller)
	callee = str(spec.callee)
	origin = int(spec.origin)
	guard_offset = int(spec.guard.offset)
	guard_end = int(spec.guard.end)
	guard_false = int(spec.guard.false_target)
	call_offset = int(spec.call.offset)
	call_end = int(spec.call.end)
	nested = str(spec.get("form", "")) == "nested_call" or int(spec.call.get("command", 14)) == 15
	for c in spec.get("guard_cells", []):
		guard_cells.append([str(c[0]), int(c[1])])
	for c in spec.get("calendar_cells", [0, 1, 2, 4, 7, 10, 19, 25]):
		calendar_cells.append(int(c))
	_build_reported()
	if spec.get("caller_choice", null) != null:
		caller_choices = [{"owner_entry": caller, "boundary_offset": int(spec.caller_choice.boundary),
			"options": [{"result_value": int(spec.caller_choice.result_value)}]}]
	for untyped_contract in spec.get("map_location_contracts", []):
		var contract: Dictionary = untyped_contract
		map_location_contracts.append({"entry": str(contract.entry).to_upper(), "poll_offset": int(contract.poll_offset),
			"result_storage": "state_u16", "result_index": 18, "locations": (contract.locations as Array).duplicate()})

	var reader := preload("res://content_core/arc_reader.gd").new()
	reader.open(elfimage.path_join("mes.arc"))
	for m in spec.members:
		documents[m] = ContainerScript.new().parse(reader.read_entry(m), {"entry": m, "archive": "mes.arc"})
	probe = Probe.new()
	provider = probe.context_from_documents(documents)
	calendar = Calendar.new()
	projection = calendar.build(documents["START.MES"])

	var out := {"spec_route": spec.route, "guard_cases": [], "not_a_package_member": [],
		"map_location_contracts": map_location_contracts.duplicate(true)}

	# Guard witnesses.
	for witness in spec.guard_cases:
		out.guard_cases.append(_guard_case(witness))

	# Contracts.
	var seed0 := _seed([])
	if spec.get("caller_choice", null) != null:
		var probe_run := probe.run_route(provider, _descriptor({"entry": caller, "start_coordinate": origin}), {}, seed0)
		_note(out, probe_run)
		out["caller_contract"] = _contract(caller, origin, seed0)
		out["caller_contract_probe"] = {"messages": probe_run.messages.size(),
			"state_diff": probe_run.state_diff, "stop": str(probe_run.get("stop", "")),
			"segments": _boundaries(probe_run)}
	var prefix := _prefix(seed0)
	_note(out, prefix)
	out["prefix"] = _report_route(prefix)
	out["prefix_reached_dispatch"] = _reached_handoff(prefix)

	# EP-12 PROMIS: a callee with an earlier, undeclared routine-40 before the
	# one named `callee_question` (the location picker before the time picker)
	# needs its own fixed answer supplied up front, or every walk stops at the
	# first `def_selection_boundary` it reaches. One answer, constant across
	# every route of the group (the spec's own baseline, not a variant). Each
	# contract is captured *before* its own answer is added to caller_choices,
	# the same way callee_contract is captured for the declared question, so
	# the builder can bind it (choice_contracts/selections) for the runtime
	# validator's own replay - a fixed answer that never reaches build()
	# would silently desync every check that replays the route.
	out["callee_prefix_contracts"] = []
	for untyped_prefix_choice in spec.get("callee_prefix_choices", []):
		var prefix_choice: Dictionary = untyped_prefix_choice
		var prefix_contract := _contract(callee, 0, prefix.state_object)
		out["callee_prefix_contracts"].append(prefix_contract)
		caller_choices.append({"owner_entry": callee, "boundary_offset": int(prefix_choice.boundary),
			"options": [{"result_value": int(prefix_choice.result_value)}]})

	var results := [null]
	var callee_choice_boundary := -1
	if spec.get("callee_question", null) != null:
		var contract := _contract(callee, 0, prefix.state_object)
		out["callee_contract"] = contract
		callee_choice_boundary = int(contract.get("boundary_offset", -1))
		results = []
		for v in contract.get("result_values", []):
			results.append(int(v))
		out["callee_result_values"] = results

	# Baseline route per result (or once when there is no callee question).
	out["results"] = {}
	var baseline_visited := {}
	var baseline_targets := {}
	var baseline_resumes := {}
	for r in results:
		var block := _measure_baseline(seed0, prefix, r, callee_choice_boundary)
		_note(out, block.get("_target", {}))
		baseline_visited[_rkey(r)] = _visited(block._target.trace)
		baseline_targets[_rkey(r)] = block._target
		block.erase("_target")
		if block.has("_resume"):
			_note(out, block._resume)
			baseline_resumes[_rkey(r)] = block._resume
			block.erase("_resume")
		out.results[_rkey(r)] = block
	if results.size() == 1 and results[0] == null:
		# Flat shape for the plain route, matching the hand-written probes.
		var flat: Dictionary = out.results["null"]
		for key in flat:
			out[key] = flat[key]
		out.erase("results")

	# Variants (two pass).
	var measured := []
	var diff_keys := {}
	for r in results:
		for pair in baseline_targets[_rkey(r)].state_diff:
			diff_keys[_diff_key(pair)] = true
		if baseline_resumes.has(_rkey(r)):
			for pair in baseline_resumes[_rkey(r)].state_diff:
				diff_keys[_diff_key(pair)] = true
	for v in spec.variants:
		var r = v.get("result", results[0])
		var r_key := _rkey(r)
		if not baseline_visited.has(r_key):
			r_key = _rkey(results[0])
		var m := _measure_variant(v, prefix.state_object, prefix.get("map_locations", []), baseline_visited[r_key],
			int(r) if r != null else -1, callee_choice_boundary)
		measured.append(m)
		if m.get("_diff_source", null) != null:
			for pair in (m._diff_source as Array):
				diff_keys[_diff_key(pair)] = true

	var profile_cells := []
	for key in diff_keys:
		var parts: Array = key.split(":")
		var storage: String = parts[0]
		var index: int = int(parts[1])
		if storage == "state_u16" and (index in calendar_cells or index == 21):
			continue
		if storage != "global_u8" and storage != "state_u16" and storage != "banked_u16":
			continue
		profile_cells.append([storage, index])
	profile_cells.sort_custom(func(a, b):
		if a[0] == b[0]:
			return a[1] < b[1]
		return a[0] < b[0])
	out["profile_cells"] = profile_cells
	for r in results:
		var effects := _effects(baseline_targets[_rkey(r)].state_object, profile_cells)
		var block: Dictionary = out.results[_rkey(r)] if out.has("results") else out
		block["profile_cell_effects"] = effects
		if baseline_resumes.has(_rkey(r)):
			block["resume_profile_cell_effects"] = _effects(baseline_resumes[_rkey(r)].state_object, profile_cells)
	for m in measured:
		var state_obj = m.get("_state_object", null)
		if state_obj != null:
			m["profile_cell_effects"] = _effects(state_obj, profile_cells)
		var reentry_obj = m.get("_reentry_state", null)
		if reentry_obj != null:
			m["reentry_profile_cell_effects"] = _effects(reentry_obj, profile_cells)
		var resume_obj = m.get("_resume_state", null)
		if resume_obj != null:
			m["resume_profile_cell_effects"] = _effects(resume_obj, profile_cells)
		m.erase("_diff_source")
		m.erase("_state_object")
		m.erase("_reentry_state")
		m.erase("_resume_state")
	out["variants"] = measured
	out["not_a_package_member"] = not_a_package_member

	var file := FileAccess.open(out_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(out))
	file.close()
	print("MEASURED_OK ", out_path)
	reader.close()
	quit(0)


func _rkey(r) -> String:
	return "null" if r == null else str(int(r))


func _build_reported() -> void:
	var seen := {}
	var add := func(storage: String, index: int) -> void:
		var key := "%s:%d" % [storage, index]
		if not seen.has(key):
			seen[key] = true
			reported.append([storage, index])
	for b in spec.baseline:
		add.call(str(b.storage), int(b.index))
	for c in guard_cells:
		add.call(c[0], c[1])
	for c in spec.get("watch_cells", []):
		add.call(str(c[0]), int(c[1]))
	for pair in [["global_u8", 3005], ["global_u8", 4000], ["global_u8", 4001], ["global_u8", 4090],
			["global_u8", 4091], ["banked_u16", 1], ["banked_u16", 2], ["banked_u16", 242],
			["state_u16", 2], ["state_u16", 5], ["state_u16", 8], ["state_u16", 16], ["state_u16", 21]]:
		add.call(pair[0], pair[1])


func _note(out: Dictionary, run: Dictionary) -> void:
	var err := str(run.get("error", run.get("stop", "")))
	if err.findn("not a package member") >= 0 and not not_a_package_member.has(err):
		not_a_package_member.append(err)
	for e in not_a_package_member:
		if not (out.not_a_package_member as Array).has(e):
			(out.not_a_package_member as Array).append(e)


func _diff_key(pair: Dictionary) -> String:
	return "%s:%d" % [str(pair.get("storage", "")), int(pair.get("index", -1))]


func _seed(writes: Array) -> KakyuMesSandboxState:
	var state := State.new(1)
	calendar.apply_to_state(projection, state)
	state.load_values(spec.baseline)
	state.load_values(writes)
	return state


func _prefix(seed: KakyuMesSandboxState) -> Dictionary:
	var descriptor := {"entry": caller, "start_coordinate": origin,
		"stop_before_dispatch": {"entry": caller, "offset": call_offset, "end": call_end, "target": callee}}
	if not caller_choices.is_empty():
		descriptor["choices"] = caller_choices
	return probe.run_route(provider, _descriptor(descriptor), {}, seed)


func _descriptor(base: Dictionary) -> Dictionary:
	# Every run gets its own copy of the declared location queues.
	if map_location_contracts.is_empty():
		return base
	var queues := []
	for untyped_contract in map_location_contracts:
		var contract: Dictionary = untyped_contract
		queues.append({"entry": contract.entry, "poll_offset": contract.poll_offset, "result_storage": contract.result_storage,
			"result_index": contract.result_index, "values": (contract.locations as Array).duplicate()})
	base["map_locations"] = queues
	return base


func _choices(result: int, boundary: int) -> Array:
	var choices := caller_choices.duplicate(true)
	if result >= 0 and boundary >= 0:
		choices.append({"owner_entry": callee, "boundary_offset": boundary, "options": [{"result_value": result}]})
	return choices


# The direct reentry the validator replays: for a nested call its
# post-continuation check runs the callee on the resumed state with no
# answer supplied, so a callee that asks again stops at its question (the
# EVENTA22 shape); for a root replacement the post-replacement check supplies
# the variant's answer, so the reentry is measured with it.
func _run_reentry(state: KakyuMesSandboxState, result: int, boundary: int) -> Dictionary:
	if nested:
		return _run_target(state, -1, -1)
	return _run_target(state, result, boundary)


func _run_target(state: KakyuMesSandboxState, result: int, boundary: int, carried = null) -> Dictionary:
	var descriptor := {"entry": callee, "start_coordinate": 0}
	var choices := _choices(result, boundary)
	if not choices.is_empty():
		descriptor["choices"] = choices
	return probe.run_route(provider, _carry(_descriptor(descriptor), carried), {}, state)


func _carry(descriptor: Dictionary, carried) -> Dictionary:
	# 0.319.0: the segmented chain carries one queue the way the unbroken run
	# does - what the previous run left is what the next run may spend. A
	# reentry starts a fresh queue: it is a new visit.
	if carried == null:
		return descriptor
	var queues := []
	for untyped_queue in carried:
		var queue: Dictionary = untyped_queue
		queues.append(queue.duplicate(true))
	descriptor["map_locations"] = queues
	return descriptor


func _run_whole(seed: KakyuMesSandboxState, result: int, boundary: int) -> Dictionary:
	var descriptor := {"entry": caller, "start_coordinate": origin}
	if not nested:
		descriptor["follow_root_handoff"] = {"entry": caller, "offset": call_offset, "end": call_end, "target": callee}
	else:
		descriptor["detect_loops"] = true
	var choices := _choices(result, boundary)
	if not choices.is_empty():
		descriptor["choices"] = choices
	return probe.run_route(provider, _descriptor(descriptor), {}, seed)


func _run_resume(state: KakyuMesSandboxState, carried = null) -> Dictionary:
	# The caller continues at the dispatch end on the callee's returned state,
	# with the same caller choices the validator supplies to its suffix run.
	var descriptor := {"entry": caller, "start_coordinate": call_end, "detect_loops": true}
	if not caller_choices.is_empty():
		descriptor["choices"] = caller_choices.duplicate(true)
	return probe.run_route(provider, _carry(_descriptor(descriptor), carried), {}, state)


func _resume_stop(result: Dictionary) -> Dictionary:
	var segments: Array = result.get("segments", [])
	var terminal: Dictionary = result.get("terminal", {})
	var report := {"stop": str(result.get("stop", "")), "stop_detail": result.get("stop_detail", {}),
		"segments": segments.size()}
	if not terminal.is_empty():
		report["kind"] = str(terminal.get("status", ""))
		report["entry"] = str(terminal.get("entry", ""))
		report["offset"] = int(terminal.get("offset", -1))
		report["end"] = int(terminal.get("end", -1))
		report["target"] = str(terminal.get("target", ""))
		if report.kind == "loop_boundary":
			# The caller's own loop (0.317.0): the head record, the period,
			# the cycle's segments and the messages one period emits.
			report["period"] = int(terminal.get("period", 0))
			report["period_message_count"] = int(terminal.get("period_message_count", 0))
			report["cycle"] = terminal.get("cycle", [])
	elif not segments.is_empty() and str((segments[-1] as Dictionary).get("status", "")) == "def_selection_boundary":
		var last: Dictionary = segments[-1]
		report["kind"] = "def_selection_boundary"
		report["entry"] = str(last.get("entry", ""))
		report["offset"] = int(last.get("offset", -1))
		report["end"] = -1
		report["target"] = ""
	else:
		report["kind"] = "unresolved"
	return report


func _identical(whole: Dictionary, parts: Array) -> Dictionary:
	var rows := []
	var hex := []
	for part in parts:
		rows += (part.rows as Array)
		hex += (part.message_hex as Array)
	var last: Dictionary = parts[-1]
	return {"state_equal": whole.state_object.snapshot() == last.state_object.snapshot(),
		"rows_equal": whole.rows == rows, "message_hex_equal": whole.message_hex == hex}


func _guard_eval(state: KakyuMesSandboxState) -> Dictionary:
	var run := Runner.new().run(documents[caller].bytecode, guard_offset, state.duplicate_state(),
		documents[caller].bytecode.size(), 1)
	var row: Dictionary = run.get("trace", [])[0]
	return {"condition_value": int(row.get("condition_value", -1)), "next_offset": int(row.get("next_offset", -1))}


func _guard_case(witness: Dictionary) -> Dictionary:
	var state := _seed(witness.writes)
	var evaluated := _guard_eval(state)
	var accept: bool = evaluated.next_offset == guard_end
	var entry := {"case_id": witness.case_id, "writes": witness.writes,
		"condition_value": evaluated.condition_value, "next_offset": evaluated.next_offset,
		"result": "accept" if accept else "reject"}
	var walk := _prefix(_seed(witness.writes))
	if accept:
		entry["prefix_hash"] = walk.signature
		entry["caller_messages"] = walk.messages.size()
		entry["prefix_reached_dispatch"] = _reached_handoff(walk)
	else:
		entry["rejected_walk"] = {"stop": str(walk.get("stop", "")), "stop_detail": walk.get("stop_detail", {}),
			"terminal": walk.get("terminal", {}), "messages": walk.messages.size()}
	return entry


func _reached_handoff(result: Dictionary) -> bool:
	var terminal: Dictionary = result.get("terminal", {})
	if str(terminal.get("target", "")) == callee and int(terminal.get("offset", -1)) == call_offset \
			and int(terminal.get("end", -1)) == call_end:
		return true
	var detail: Dictionary = result.get("stop_detail", {})
	return str(detail.get("status", "")) == "analysis_dispatch_stop" and int(detail.get("offset", -1)) == call_offset


func _measure_baseline(seed0: KakyuMesSandboxState, prefix: Dictionary, result, boundary: int) -> Dictionary:
	var r := int(result) if result != null else -1
	var target := _run_target(prefix.state_object, r, boundary, prefix.get("map_locations", []))
	var whole := _run_whole(seed0, r, boundary)
	var post_guard := _guard_eval(target.state_object)
	var reentry := _run_reentry(target.state_object, r, boundary)
	var parts := [prefix, target]
	var block := {
		"result_value": result,
		"route": {"prefix": _report_route(prefix), "target": _report_route(target),
			"target_return_record": _return_record(target), "whole": _report_route(whole)},
		"post_guard": {"condition_value": post_guard.condition_value, "next_offset": post_guard.next_offset,
			"guard_cell_writes": {"caller_prefix": _cell_writes_with_before_after(prefix, caller, guard_cells),
				"callee": _cell_writes_with_before_after(target, callee, guard_cells)}},
		"reentry": {"direct": _report_route(reentry), "direct_return_record": _return_record(reentry)},
		"diagnostics": _diagnostics(prefix, target),
		"_target": target,
	}
	if nested:
		# A continuation route's post-guard truth and reentry are read on the
		# caller's resumed state (the validator's suffix state), not on the
		# callee's returned state; the callee-only readings stay as diagnostics.
		var resume := _run_resume(target.state_object, target.get("map_locations", []))
		parts.append(resume)
		block["resume"] = _report_route(resume)
		block.resume["stop"] = _resume_stop(resume)
		block.resume["return_record"] = _return_record(resume)
		block.resume["guard_cell_writes"] = _cell_writes_with_before_after(resume, caller, guard_cells)
		block["after_callee"] = {"post_guard": block.post_guard, "reentry": block.reentry}
		var post_resume := _guard_eval(resume.state_object)
		block["post_guard"] = {"condition_value": post_resume.condition_value, "next_offset": post_resume.next_offset,
			"guard_cell_writes": {"caller_prefix": _cell_writes_with_before_after(prefix, caller, guard_cells),
				"callee": _cell_writes_with_before_after(target, callee, guard_cells),
				"caller_resume": _cell_writes_with_before_after(resume, caller, guard_cells)}}
		var completed := _run_reentry(resume.state_object, r, boundary)
		block["reentry"] = {"direct": _report_route(completed), "direct_return_record": _return_record(completed)}
		block["_resume"] = resume
	block["identical"] = _identical(whole, parts)
	return block


func _diagnostics(prefix: Dictionary, target: Dictionary) -> Dictionary:
	var watch := []
	for c in spec.get("watch_cells", []):
		watch.append([str(c[0]), int(c[1])])
	var seeded_4000: KakyuMesSandboxState = prefix.state_object.duplicate_state()
	seeded_4000.write_value("global_u8", 4000, 1)
	var run_4000 := _run_target(seeded_4000, -1, -1)
	return {
		"state_u16_8_writes_callee": _find_writes(target.trace, callee, "state_u16", 8),
		"global_u8_4000_at_entry": prefix.state_object.read_value("global_u8", 4000, 0),
		"global_u8_4000_seeded_1_final": run_4000.state_object.read_value("global_u8", 4000, 0),
		"watch_cell_writes_callee": _cell_writes_with_before_after(target, callee, watch),
		"watch_cell_writes_prefix": _cell_writes_with_before_after(prefix, caller, watch),
		"banked_u16_242_final": target.state_object.read_value("banked_u16", 242, 0),
	}


func _measure_variant(v: Dictionary, baseline_prefix_state: KakyuMesSandboxState, baseline_prefix_queues: Array,
		baseline_visited: Dictionary, result: int, boundary: int) -> Dictionary:
	var out := {"variant_id": v.variant_id, "writes": v.writes, "result_value": result if result >= 0 else null}
	if v.get("direct", false):
		var direct_seed: KakyuMesSandboxState = baseline_prefix_state.duplicate_state()
		for wr in v.writes:
			direct_seed.write_value(str(wr.storage), int(wr.index), int(wr.value))
		var direct := _run_target(direct_seed, result, boundary, baseline_prefix_queues)
		out["mode"] = "direct_from_prefix"
		out["guard"] = _guard_eval(_seed(v.writes))
		out["callee_messages"] = direct.messages.size()
		out["terminal"] = direct.get("terminal", {})
		out["callee_state_diff"] = direct.state_diff
		out["branches_changing_arm"] = _changed_arms(_visited(direct.trace), baseline_visited)
		out["_diff_source"] = direct.state_diff
		out["_state_object"] = direct.state_object
		return out
	var seed := _seed(v.writes)
	var prefix := _prefix(seed)
	out["prefix_messages"] = prefix.messages.size()
	out["prefix_reached_dispatch"] = _reached_handoff(prefix)
	if not out.prefix_reached_dispatch:
		out["guard"] = _guard_eval(seed)
		out["prefix_stop"] = str(prefix.get("stop", ""))
		# A walk the guard turns away still ends somewhere. Its terminal, the
		# scripts it executed and its effects are reported so that a walk which
		# leaves the caller by a door of its own - the map's exit without the
		# event - can be declared as a bypass variant; the builder decides.
		out["prefix_terminal"] = _return_record(prefix)
		out["prefix_state_diff"] = prefix.state_diff
		out["prefix_entries"] = _entries(prefix.get("trace", []))
		out["_state_object"] = prefix.state_object
		return out
	var target := _run_target(prefix.state_object, result, boundary, prefix.get("map_locations", []))
	var whole := _run_whole(seed, result, boundary)
	var post_guard := _guard_eval(target.state_object)
	var reentry := _run_reentry(target.state_object, result, boundary)
	var parts := [prefix, target]
	out["callee_messages"] = target.messages.size()
	out["terminal"] = target.get("terminal", {})
	out["return_record"] = _return_record(target)
	out["post_guard"] = post_guard.condition_value
	out["post_guard_next_offset"] = post_guard.next_offset
	out["callee_state_diff"] = target.state_diff
	out["branches_changing_arm"] = _changed_arms(_visited(target.trace), baseline_visited)
	out["reentry_messages"] = reentry.messages.size()
	out["reentry_return_record"] = _return_record(reentry)
	out["reentry_state_diff"] = reentry.state_diff
	out["_diff_source"] = target.state_diff.duplicate(true)
	out["_state_object"] = target.state_object
	out["_reentry_state"] = reentry.state_object
	if nested:
		var resume := _run_resume(target.state_object, target.get("map_locations", []))
		parts.append(resume)
		out["resume_messages"] = resume.messages.size()
		out["resume_stop"] = _resume_stop(resume)
		out["resume_return_record"] = _return_record(resume)
		out["resume_state_diff"] = resume.state_diff
		out["after_callee"] = {"post_guard": out.post_guard, "reentry_messages": out.reentry_messages,
			"reentry_return_record": out.reentry_return_record}
		var post_resume := _guard_eval(resume.state_object)
		out["post_guard"] = post_resume.condition_value
		out["post_guard_next_offset"] = post_resume.next_offset
		var completed := _run_reentry(resume.state_object, result, boundary)
		out["reentry_messages"] = completed.messages.size()
		out["reentry_return_record"] = _return_record(completed)
		out["reentry_state_diff"] = completed.state_diff
		out["_reentry_state"] = completed.state_object
		out["_diff_source"] = (out._diff_source as Array) + (resume.state_diff as Array)
		out["_resume_state"] = resume.state_object
	var same := _identical(whole, parts)
	out["identical"] = bool(same.state_equal) and bool(same.rows_equal) and bool(same.message_hex_equal)
	out["identical_detail"] = same
	return out


func _changed_arms(here_visited: Dictionary, baseline_visited: Dictionary) -> Array:
	var changed := []
	for key in here_visited:
		if here_visited[key] != baseline_visited.get(key, []):
			changed.append(key)
	return changed


func _contract(entry: String, start: int, seed: KakyuMesSandboxState) -> Dictionary:
	var descriptor := {"entry": entry, "start_coordinate": start}
	if entry == callee and not caller_choices.is_empty():
		# EP-12 PROMIS: a callee-owned prefix choice (an earlier, undeclared
		# routine-40 before the callee_question) must be supplied here too, or
		# the walk into the callee stops at that earlier boundary instead of
		# reaching the one this contract measures. A caller-owned choice in
		# the same list never matches inside the callee (owner_entry differs),
		# so this is a no-op for every existing caller-choice-only group.
		descriptor["choices"] = caller_choices
	var awaiting := probe.run_route(provider, _descriptor(descriptor), {}, seed)
	var stop_detail: Dictionary = awaiting.get("stop_detail", {})
	var contract: Dictionary
	# Core 0.368.0: build from the live stop
	# (`content_core/mes_route_probe.gd`'s `_select_choice`,
	# `stop_detail.kind == "unanswered_choice"`) instead of re-running from a
	# bare resume coordinate - the bare re-run lacks the argument-slot/library
	# context the live walk already carries and can diverge into an unrelated
	# `shared_routine_boundary` before reaching the boundary this contract
	# measures.
	if str(stop_detail.get("kind", "")) == "unanswered_choice" and str(stop_detail.get("entry", "")) == entry:
		var live_code: PackedByteArray = documents[entry].bytecode
		contract = ChoiceContract.new().build(live_code, int(stop_detail.get("code_size", live_code.size())),
			stop_detail.result, stop_detail.get("source_identity", {"entry": entry, "archive": "mes.arc"}))
	else:
		# Documented fallback: the stop carried no unanswered-choice boundary
		# (an unexpected stop shape - not seen in this unit's own
		# twelve-hotel-menu and ten-ordinary-group byte-identity check).
		# Re-run from the last known dialogue resume point, as before EP-12's
		# Core 0.368.0 fix.
		push_warning("_contract fallback re-run for %s: stop_detail carried no unanswered-choice boundary (stop=%s)" % [entry, awaiting.get("stop", "")])
		var resume := start
		for untyped_segment in awaiting.get("segments", []):
			var segment: Dictionary = untyped_segment
			if int(segment.get("resume", -1)) >= 0 and str(segment.get("entry", "")) == entry:
				resume = int(segment.resume)
		var code: PackedByteArray = documents[entry].bytecode
		var run := Runner.new().run(code, resume, awaiting.state_object, code.size(), 10000,
			{"native_record_policy": "omit_bounded"})
		contract = ChoiceContract.new().build(code, code.size(), run, {"entry": entry, "archive": "mes.arc"})
	contract["messages_before_boundary"] = awaiting.messages.size()
	contract["awaiting_stop"] = str(awaiting.get("stop", ""))
	return contract


func _boundaries(run: Dictionary) -> Array:
	var found := []
	for untyped_segment in run.get("segments", []):
		var segment: Dictionary = untyped_segment
		if str(segment.get("status", "")) == "def_selection_boundary":
			found.append({"entry": segment.get("entry", ""), "offset": segment.get("offset", -1)})
	return found


func _effects(state: KakyuMesSandboxState, cells: Array) -> Array:
	var effects := []
	for pair in cells:
		effects.append({"storage": pair[0], "index": pair[1], "value": state.read_value(pair[0], int(pair[1]), 0)})
	return effects


func _find_writes(trace: Array, owner_entry: String, storage: String, index: int) -> Array:
	var found := []
	for untyped_row in trace:
		var row: Dictionary = untyped_row
		if str(row.get("source_entry", "")) != owner_entry or str(row.get("write_storage", "")) != storage:
			continue
		var start := int(row.get("write_start", -1))
		var count := int(row.get("write_count", 0))
		if start <= index and index < start + count:
			found.append({"offset": int(row.get("source_offset", -1)), "end": int(row.get("end_offset", -1))})
	return found


func _entries(trace: Array) -> Array:
	var seen := {}
	for row in trace:
		var entry := str(row.get("source_entry", ""))
		if not entry.is_empty():
			seen[entry] = true
	var entries := seen.keys()
	entries.sort()
	return entries


func _return_record(result: Dictionary) -> Dictionary:
	var terminal: Dictionary = result.get("terminal", {})
	var trace: Array = result.get("trace", [])
	var last: Dictionary = trace[-1] if not trace.is_empty() else {}
	var segments: Array = result.get("segments", [])
	if terminal.is_empty() and not segments.is_empty() and str((segments[-1] as Dictionary).get("status", "")) == "def_selection_boundary":
		# The run stopped at a routine-40 selection no answer was declared
		# for (a nested route's reentry replayed without an answer, the
		# EVENTA22 shape): the record is the selection itself, as the resume
		# stop reports it.
		var selection: Dictionary = segments[-1]
		return {"offset": int(selection.get("offset", -1)), "end": int(last.get("end_offset", -1)),
			"target": "", "status": "def_selection_boundary", "op": str(last.get("op", ""))}
	return {"offset": int(terminal.get("offset", -1)), "end": int(terminal.get("end", -1)),
		"target": str(terminal.get("target", "")), "status": str(terminal.get("status", "")),
		"op": str(last.get("op", ""))}


func _cell_writes_with_before_after(run: Dictionary, owner_entry: String, cells: Array) -> Array:
	var diff_by_key := {}
	for untyped_d in run.get("state_diff", []):
		var d: Dictionary = untyped_d
		diff_by_key["%s:%d" % [str(d.get("storage", "")), int(d.get("index", -1))]] = d
	var found := []
	for untyped_row in run.trace:
		var row: Dictionary = untyped_row
		if str(row.get("source_entry", "")) != owner_entry:
			continue
		var storage := str(row.get("write_storage", ""))
		if storage == "":
			continue
		var start := int(row.get("write_start", -1))
		var count := int(row.get("write_count", 0))
		for pair in cells:
			if pair[0] == storage and start <= int(pair[1]) and int(pair[1]) < start + count:
				var d: Dictionary = diff_by_key.get("%s:%d" % [pair[0], int(pair[1])], {})
				found.append({"storage": pair[0], "index": int(pair[1]), "offset": int(row.get("source_offset", -1)),
					"end": int(row.get("end_offset", -1)), "owner": owner_entry,
					"before": d.get("before", null), "after": d.get("after", null)})
	return found


func _report_route(result: Dictionary) -> Dictionary:
	return {"stop": str(result.get("stop", "")), "stop_detail": result.get("stop_detail", {}),
		"terminal": result.get("terminal", {}), "messages": result.messages.size(),
		"caller_messages": _count_source(result.messages, caller),
		"callee_messages": _count_source(result.messages, callee),
		"state_diff": result.state_diff, "reported_state": _report_state(result.state_object),
		"visited": _visited(result.trace), "signature": result.signature,
		"map_locations_remaining": int(result.get("map_locations_remaining", 0)),
		"map_locations": _report_map_locations(result)}


func _report_map_locations(result: Dictionary) -> Array:
	# 0.319.0: what each declared queue still holds after this run, so the
	# builder can say which segmented run spends a contract.
	var rows := []
	for untyped_queue in result.get("map_locations", []):
		var queue: Dictionary = untyped_queue
		rows.append({"entry": str(queue.get("entry", "")), "poll_offset": int(queue.get("poll_offset", -1)),
			"remaining": (queue.get("values", []) as Array).duplicate()})
	return rows


func _report_state(state: KakyuMesSandboxState) -> Array:
	var values := []
	for pair in reported:
		values.append({"storage": pair[0], "bank": 0, "index": pair[1], "value": state.read_value(pair[0], int(pair[1]), 0)})
	return values


func _count_source(messages: Array, source: String) -> int:
	var n := 0
	for m in messages:
		if str(m.get("source_entry", "")) == source:
			n += 1
	return n


func _visited(trace: Array) -> Dictionary:
	var seen := {}
	for row in trace:
		if row.get("op") == "branch_if_not_true" and row.get("source_entry", callee) == callee:
			var key := str(row.get("source_offset", -1))
			if not seen.has(key):
				seen[key] = []
			var v: int = int(row.get("condition_value", -1))
			if not seen[key].has(v):
				seen[key].append(v)
	return seen
