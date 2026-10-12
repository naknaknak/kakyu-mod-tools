extends SceneTree

# EP-12: measure one heroine's promise-date flow end to end and write the
# three route spec files `tools/build_event_flow_profile.py` consumes, plus a
# measurement report. Driven by `tools/draft_date_flow_specs.py`'s recipe
# (the archive's own bytecode offsets, discovered statically); this tool
# supplies the seeds/choices/poll_supplies each gate needs and runs every hop
# through the shared call frame (`content_core/mes_route_probe.gd`), one
# fresh top-level `probe.run_route` call per hop - the technique
# `docs/spec/mes/a_date_flow.md` used by hand for heroine A.
#
#   godot --headless --path . --script res://tools/content_suite/cli/measure_date_flow.gd \
#       -- "<ELFIMAGE dir>" analysis/_undoc/ep12_b_flow_recipe.json analysis/_undoc/ep12b_specs analysis/_undoc/ep12_b_flow_measure_report.json

const Probe := preload("res://content_core/mes_route_probe.gd")
const State := preload("res://content_core/mes_sandbox_state.gd")
const ContainerScript := preload("res://content_core/mes_container.gd")
const Calendar := preload("res://content_core/mes_calendar_state.gd")
const RunnerScript := preload("res://content_core/mes_event_runner.gd")
const ChoiceContractScript := preload("res://content_core/mes_routine40_choice_contract.gd")

var recipe := {}
var letter := ""
var documents := {}
var provider: Dictionary
var probe: KakyuMesRouteProbe
var report := {"routes": {}}


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var elfimage: String = args[0]
	var recipe_path: String = args[1]
	var out_dir: String = args[2]
	var report_path: String = args[3]
	recipe = JSON.parse_string(FileAccess.get_file_as_string(recipe_path))
	letter = str(recipe.letter)

	var members := ["01M.MES"]
	for d in recipe.shared_dispatches:
		if not members.has(str(d.target)):
			members.append(str(d.target))
	for extra in [str(recipe.town_tail.dispatch.target), "%s_DATE5.MES" % letter,
			str(recipe.hotel_chain.hotel_entry), str(recipe.hotel_chain.hotel1_entry),
			str(recipe.hotel_chain.hotel2_entry), "LIBLARY.LIB", "DEF_MAIN.MES", "START.MES",
			str(recipe.train_contract.entry)]:
		if not members.has(extra):
			members.append(extra)

	var reader := preload("res://content_core/arc_reader.gd").new()
	reader.open(elfimage.path_join("mes.arc"))
	var archive_sha256 := FileAccess.get_sha256(elfimage.path_join("mes.arc"))
	for m in members:
		documents[m] = ContainerScript.new().parse(reader.read_entry(m), {"entry": m, "archive": "mes.arc"})
		if not documents[m].get("ok", false):
			push_error("%s did not parse" % m)
			quit(1)
			return
	probe = Probe.new()
	provider = probe.context_from_documents(documents)
	var calendar := Calendar.new()
	var projection := calendar.build(documents["START.MES"])

	var seed := State.new(1)
	calendar.apply_to_state(projection, seed)
	var promise_field: int = recipe.params.promise_field
	var location_field: int = recipe.params.location_field
	seed.write_value("state_u16", 7, 502)
	seed.write_value("state_u16", 19, 1530)
	seed.write_value("banked_u16", promise_field, 502)
	seed.write_value("banked_u16", promise_field + 1, 900)
	# The guard's own two flag conjuncts (global_u8[200]/[207] for B; the
	# offset scan finds the exact cells for whichever heroine is drafted).
	var guard_flag_cells := []
	for c in recipe.guard.cells:
		if c[0] == "global_u8" and int(c[1]) != location_field:
			guard_flag_cells.append(c)
	# The guard's own two flag conjuncts are always `==1` then `==2` in file
	# order (confirmed for A and B by `tools/draft_date_flow_specs.py`'s own
	# guard scan; both must be satisfied, not just referenced).
	seed.write_value("global_u8", int(guard_flag_cells[0][1]), 1)
	seed.write_value("global_u8", int(guard_flag_cells[1][1]), 2)
	seed.write_value("global_u8", location_field, 15)

	report["members"] = members
	report["archive_sha256"] = archive_sha256

	var town := _measure_route("town", seed.duplicate_state(), 1)
	var date5 := _measure_route("date5", seed.duplicate_state(), 2)
	var hotel := _measure_route("hotel", seed.duplicate_state(), 3)

	report["routes"] = {"town": town, "date5": date5, "hotel": hotel}

	var any_failed := false
	for route_id in ["town", "date5", "hotel"]:
		var block: Dictionary = report.routes[route_id]
		if not block.get("ok", false):
			print("ROUTE_FAILED ", route_id, " ", block.get("error", ""))
			any_failed = true
	if any_failed:
		var rf2 := FileAccess.open(report_path, FileAccess.WRITE)
		rf2.store_string(JSON.stringify(report, "  "))
		rf2.close()
		quit(1)
		return

	DirAccess.make_dir_recursive_absolute(out_dir)
	for route_id in ["town", "date5", "hotel"]:
		var block: Dictionary = report.routes[route_id]
		var file := FileAccess.open(out_dir.path_join("01m_%s_date_%s_v14_spec.json" % [letter.to_lower(), route_id]), FileAccess.WRITE)
		file.store_string(JSON.stringify(block.spec, "  "))
		file.close()
	var rf := FileAccess.open(report_path, FileAccess.WRITE)
	rf.store_string(JSON.stringify(report, "  "))
	rf.close()
	print("MEASURED_OK ", report_path)
	reader.close()
	quit(0)


func _shared_prefix(seed: KakyuMesSandboxState) -> Dictionary:
	var hops := []
	var contracts := []
	var state := seed
	var cursor: int = int(recipe.guard.offset)
	var kind := "origin"
	var idx := 0
	var dispatches: Array = recipe.shared_dispatches
	for d_index in dispatches.size():
		var d: Dictionary = dispatches[d_index]
		var target := str(d.target)
		var dispatch_offset := int(d.offset)
		var dispatch_end := int(d.end)
		var is_last := d_index == dispatches.size() - 1
		# Dispatch hop: run 01M.MES from `cursor` and stop exactly at this
		# dispatch record.
		var run := probe.run_route(provider, {"entry": "01M.MES", "start_coordinate": cursor,
			"stop_before_dispatch": {"entry": "01M.MES", "offset": dispatch_offset, "end": dispatch_end, "target": target}},
			{}, state)
		var detail: Dictionary = run.get("stop_detail", {})
		if str(detail.get("status", "")) != "analysis_dispatch_stop":
			return {"ok": false, "error": "shared dispatch to %s not reached: %s" % [target, run.get("error", "")]}
		hops.append({"hop_id": "h%d_dispatch_%s" % [idx * 2 + 1, target.to_lower().replace(".mes", "")],
			"entry": "01M.MES", "entered_by_kind": kind, "outcome_offset": dispatch_offset,
			"outcome_status": "script_dispatch_boundary", "outcome_target": target,
			"message_count": run.messages.size(), "answers": [], "gates": [], "poll_supplies": []})
		state = run.state_object
		if is_last:
			# The last shared dispatch is into ?_DATE3.MES, whose own nested
			# run is route-specific (its own first question needs an answer
			# per route) - `_measure_route` runs it, not this shared walk.
			break
		# Nested hop: run the target from offset 0 to its own natural stop.
		var extra := {}
		var flat_answers := []
		var stored_map_locations := []
		if target == "DENSHA.MES":
			extra["map_locations"] = [_train_contract()]
			# DENSHA.MES's own first routine-40 (2652, shared/heroine-independent -
			# confirmed identical to A's own offset by the recipe's static scan),
			# answered value 1 as `docs/spec/mes/a_date_flow.md` established.
			extra["choices"] = [{"owner_entry": "DENSHA.MES", "boundary_offset": 2652,
				"options": [{"result_value": 1}]}]
			flat_answers = [{"boundary_offset": 2652, "result_value": 1}]
			stored_map_locations = [_train_map_location_contract()]
			contracts.append(_build_contract("DENSHA.MES", 0, state, [], [_train_contract()]))
		if target == "%s_TIME.MES" % letter:
			var time_boundary := _routine40_of(target)
			extra["choices"] = [{"owner_entry": target, "boundary_offset": time_boundary,
				"options": [{"result_value": 1}]}]
			flat_answers = [{"boundary_offset": time_boundary, "result_value": 1}]
			contracts.append(_build_contract(target, 0, state))
		var nested := probe.run_route(provider, ({"entry": target, "start_coordinate": 0, "detect_loops": true}).merged(extra), {}, state)
		if str(nested.get("stop", "")) != "":
			return {"ok": false, "error": "%s did not return: %s" % [target, nested.get("stop", "")]}
		var terminal: Dictionary = nested.terminal
		hops.append({"hop_id": "h%d_%s" % [idx * 2 + 2, target.to_lower().replace(".mes", "")],
			"entry": target, "entered_by_kind": "nested_call", "outcome_offset": int(terminal.offset),
			"outcome_status": str(terminal.status), "outcome_target": str(terminal.get("target", "")),
			"message_count": nested.messages.size(), "answers": flat_answers, "gates": [],
			"map_locations": stored_map_locations, "poll_supplies": []})
		state = nested.state_object
		cursor = dispatch_end
		kind = "resume"
		idx += 1
	return {"ok": true, "hops": hops, "state": state, "contracts": contracts,
		"last_dispatch_end": int(recipe.shared_dispatches[-1].end)}


func _build_contract(entry: String, start: int, seed: KakyuMesSandboxState, prior_choices: Array = [],
		map_locations: Array = [], poll_supplies: Array = []) -> Dictionary:
	# Mirrors `tools/content_suite/cli/measure_event_route.gd`'s own
	# `_contract()`: walk with whatever choices are already answered (none,
	# for the first question in a file; the first question's own answer, to
	# reach a second), let the walk fail at the next unanswered routine-40, and
	# build `KakyuMesRoutine40ChoiceContract` from the live stop
	# (`content_core/mes_route_probe.gd`'s `_select_choice`, Core 0.368.0
	# `stop_detail.kind == "unanswered_choice"`) rather than re-running: a bare
	# re-run from a raw resume coordinate lacks the argument-slot/library
	# context the live walk already carries and can diverge into an unrelated
	# `shared_routine_boundary` before reaching the boundary this contract
	# measures (D's own `?_HOTEL.MES` site selector). `map_locations` carries
	# DENSHA.MES's own TRAIN.MES poll contract through to its own routine-40;
	# `poll_supplies` is the same seam for a definition-17 wait (L's own
	# `L_DATE5.MES:5945` open choice needs it threaded here too, or this
	# independent walk stalls on the same definition-17 wait the route's own
	# walk already supplies - measured, not an argument-slot divergence for
	# this specific site).
	var descriptor := {"entry": entry, "start_coordinate": start}
	if not prior_choices.is_empty():
		descriptor["choices"] = prior_choices
	if not map_locations.is_empty():
		descriptor["map_locations"] = map_locations
	if not poll_supplies.is_empty():
		descriptor["poll_supplies"] = poll_supplies
	var awaiting := probe.run_route(provider, descriptor, {}, seed)
	var stop_detail: Dictionary = awaiting.get("stop_detail", {})
	if str(stop_detail.get("kind", "")) == "unanswered_choice" and str(stop_detail.get("entry", "")) == entry:
		var live_code: PackedByteArray = documents[entry].bytecode
		return ChoiceContractScript.new().build(live_code, int(stop_detail.get("code_size", live_code.size())),
			stop_detail.result, stop_detail.get("source_identity", {"entry": entry, "archive": "mes.arc"}))
	# Documented fallback: the stop carried no unanswered-choice boundary (an
	# unexpected stop shape - not seen in this unit's own twelve-hotel-menu and
	# ten-ordinary-group byte-identity check). Re-run from the last known
	# dialogue resume point, as before EP-12's Core 0.368.0 fix.
	push_warning("_build_contract fallback re-run for %s: stop_detail carried no unanswered-choice boundary (stop=%s)" % [entry, awaiting.get("stop", "")])
	var resume := start
	for untyped_segment in awaiting.get("segments", []):
		var segment: Dictionary = untyped_segment
		if int(segment.get("resume", -1)) >= 0 and str(segment.get("entry", "")) == entry:
			resume = int(segment.resume)
	var code: PackedByteArray = documents[entry].bytecode
	var run := RunnerScript.new().run(code, resume, awaiting.state_object, code.size(), 10000,
		{"native_record_policy": "omit_bounded"})
	return ChoiceContractScript.new().build(code, code.size(), run, {"entry": entry, "archive": "mes.arc"})


func _routine40_of(entry: String) -> int:
	# Only `?_TIME.MES` needs this; its own single routine-40 site is read
	# from the recipe (`tools/draft_date_flow_specs.py`'s own static scan).
	return int(recipe.get("time_boundary", -1))


func _measure_route(route_id: String, seed: KakyuMesSandboxState, case_value: int) -> Dictionary:
	var prefix := _shared_prefix(seed)
	if not prefix.get("ok", false):
		return {"ok": false, "error": prefix.error}
	var hops: Array = prefix.hops
	var contracts: Array = (prefix.contracts as Array).duplicate(true)
	var state: KakyuMesSandboxState = prefix.state
	var date3 := str(recipe.date3_entry)
	var q1_boundary := int(recipe.q1_boundary)
	contracts.append(_build_contract(date3, 0, state))
	var choices := [{"owner_entry": date3, "boundary_offset": q1_boundary, "options": [{"result_value": case_value}]}]
	var flat_answers := [{"boundary_offset": q1_boundary, "result_value": case_value}]
	var gates := []
	var poll := []
	if route_id == "date5":
		state.write_value("banked_u16", int(recipe.params.affection_cell), int(recipe.date5_gate.seed_value))
		state.write_value("global_u8", 539, 0)
		gates = [{"storage": "banked_u16", "bank": 0, "index": int(recipe.params.affection_cell),
			"value": int(recipe.date5_gate.seed_value), "op": "greater_or_equal", "basis": "tool_seeded"}]
	elif route_id == "hotel":
		state.write_value("banked_u16", int(recipe.params.affection_cell), int(recipe.hotel_first_question_gate.seed_value))
		gates = [{"storage": "banked_u16", "bank": 0, "index": int(recipe.params.affection_cell),
			"value": int(recipe.hotel_first_question_gate.seed_value), "op": "greater_or_equal", "basis": "tool_seeded"}]
		# Five heroines' own hotel case bodies (E, G, I, J, L) carry no
		# `state_u16[12]` money gate at all - the recipe's own
		# `q2.money_threshold` is `null` for them, and this seed/gate is
		# skipped rather than forced.
		if recipe.q2.get("money_threshold") != null:
			state.write_value("state_u16", 12, int(recipe.q2.money_threshold))
			gates.append({"storage": "state_u16", "bank": 0, "index": 12, "value": int(recipe.q2.money_threshold),
				"op": "greater_or_equal", "basis": "tool_seeded"})
		var q2_boundary := int(recipe.q2.boundary)
		# The second question's own accepting value is heroine-specific
		# (`hotel_state21_value`: 1 for G/J/L, 2 for E/I, 3 for A/B/C/D/F/H/K)
		# - not always the same literal `case_value` (3) the *first* question's
		# hotel case uses; answering it wrong is rejected by the routine-40
		# catalog (a real out-of-range check, confirmed for G) rather than
		# silently taking the wrong branch.
		var hotel_answer := int(recipe.params.hotel_state21_value)
		choices.append({"owner_entry": date3, "boundary_offset": q2_boundary, "options": [{"result_value": hotel_answer}]})
		flat_answers.append({"boundary_offset": q2_boundary, "result_value": hotel_answer})
		poll = [_poll_supply()]
		contracts.append(_build_contract(date3, 0, state, [choices[0]]))

	var d3 := probe.run_route(provider, {"entry": date3, "start_coordinate": 0, "choices": choices,
		"poll_supplies": poll, "detect_loops": true}, {}, state)
	if str(d3.get("stop", "")) != "":
		return {"ok": false, "error": "%s did not reach its own route terminal: %s" % [date3, d3.get("stop", "")]}
	var terminal: Dictionary = d3.terminal
	hops.append({"hop_id": "t20_%s_date3" % route_id, "entry": date3, "entered_by_kind": "nested_call",
		"outcome_offset": int(terminal.offset), "outcome_status": str(terminal.status),
		"outcome_target": str(terminal.get("target", "")), "message_count": d3.messages.size(),
		"answers": flat_answers, "gates": gates, "poll_supplies": poll})
	state = d3.state_object

	if route_id == "town":
		var t21 := probe.run_route(provider, {"entry": "01M.MES", "start_coordinate": int(prefix.last_dispatch_end),
			"stop_before_dispatch": {"entry": "01M.MES", "offset": int(recipe.town_tail.dispatch.offset),
				"end": int(recipe.town_tail.dispatch.end), "target": str(recipe.town_tail.dispatch.target)}}, {}, state)
		var d21 := str((t21.get("stop_detail", {}) as Dictionary).get("status", ""))
		if d21 != "analysis_dispatch_stop":
			return {"ok": false, "error": "town route did not reach its own DATE4 dispatch: %s" % t21.get("error", "")}
		hops.append({"hop_id": "t21_dispatch_date4", "entry": "01M.MES", "entered_by_kind": "resume",
			"outcome_offset": int(recipe.town_tail.dispatch.offset), "outcome_status": "script_dispatch_boundary",
			"outcome_target": str(recipe.town_tail.dispatch.target), "message_count": t21.messages.size(),
			"answers": [], "gates": [], "poll_supplies": []})
		state = t21.state_object
		var t22 := probe.run_route(provider, {"entry": str(recipe.town_tail.dispatch.target), "start_coordinate": 0}, {}, state)
		if str(t22.get("stop", "")) != "":
			return {"ok": false, "error": "DATE4 did not return: %s" % t22.get("stop", "")}
		hops.append({"hop_id": "t22_date4", "entry": str(recipe.town_tail.dispatch.target), "entered_by_kind": "nested_call",
			"outcome_offset": int(t22.terminal.offset), "outcome_status": str(t22.terminal.status),
			"outcome_target": str(t22.terminal.get("target", "")), "message_count": t22.messages.size(),
			"answers": [], "gates": [], "poll_supplies": []})
		state = t22.state_object
		var t23 := probe.run_route(provider, {"entry": "01M.MES", "start_coordinate": int(recipe.town_tail.dispatch.end)}, {}, state)
		if str(t23.get("stop", "")) != "":
			return {"ok": false, "error": "town route did not reach its own MACHI.MES terminal: %s" % t23.get("stop", "")}
		hops.append({"hop_id": "t23_handoff_machi", "entry": "01M.MES", "entered_by_kind": "resume",
			"outcome_offset": int(t23.terminal.offset), "outcome_status": str(t23.terminal.status),
			"outcome_target": str(t23.terminal.get("target", "")), "message_count": t23.messages.size(),
			"answers": [], "gates": [], "poll_supplies": []})
		state = t23.state_object

	elif route_id == "date5":
		var date5_entry := "%s_DATE5.MES" % letter
		var date5_descriptor := {"entry": date5_entry, "start_coordinate": 0,
			"poll_supplies": [_poll_supply()], "detect_loops": true}
		var d21 := probe.run_route(provider, date5_descriptor, {}, state)
		var d21_answers := []
		if str(d21.get("stop", "")) != "":
			# L's own `?_DATE5.MES` falls straight from the lateness check into
			# an open routine-40 (the same 44C.MES/MACHI.MES own-choice shape
			# `?_HOTEL2.MES` carries for E/I) - a question with no route
			# policy, answered value 1 (the first option the choice contract
			# offers) here too, per the task's own policy for such questions.
			var boundary := _open_choice_boundary(str(d21.stop), date5_entry)
			if boundary < 0:
				return {"ok": false, "error": "%s did not reach its own terminal: %s" % [date5_entry, d21.get("stop", "")]}
			date5_descriptor["choices"] = [{"owner_entry": date5_entry, "boundary_offset": boundary, "options": [{"result_value": 1}]}]
			d21_answers = [{"boundary_offset": boundary, "result_value": 1}]
			contracts.append(_build_contract(date5_entry, 0, state, [], [], [_poll_supply()]))
			d21 = probe.run_route(provider, date5_descriptor, {}, state)
			if str(d21.get("stop", "")) != "":
				return {"ok": false, "error": "%s did not reach its own terminal after answering its own open choice: %s" % [date5_entry, d21.get("stop", "")]}
		hops.append({"hop_id": "d21_date5", "entry": date5_entry, "entered_by_kind": "root_handoff",
			"outcome_offset": int(d21.terminal.offset), "outcome_status": str(d21.terminal.status),
			"outcome_target": str(d21.terminal.get("target", "")), "message_count": d21.messages.size(),
			"answers": d21_answers, "gates": [], "poll_supplies": [_poll_supply()]})
		state = d21.state_object

	elif route_id == "hotel":
		var hotel_entry := str(recipe.hotel_chain.hotel_entry)
		var hotel_boundary := int(recipe.hotel_chain.hotel_boundary)
		contracts.append(_build_contract(hotel_entry, 0, state))
		var o21 := probe.run_route(provider, {"entry": hotel_entry, "start_coordinate": 0, "detect_loops": true,
			"choices": [{"owner_entry": hotel_entry, "boundary_offset": hotel_boundary,
				"options": [{"result_value": 5}]}]}, {}, state)
		if str(o21.get("stop", "")) != "":
			return {"ok": false, "error": "%s did not reach its own terminal: %s" % [hotel_entry, o21.get("stop", "")]}
		hops.append({"hop_id": "o21_hotel", "entry": hotel_entry, "entered_by_kind": "root_handoff",
			"outcome_offset": int(o21.terminal.offset), "outcome_status": str(o21.terminal.status),
			"outcome_target": str(o21.terminal.get("target", "")), "message_count": o21.messages.size(),
			"answers": [{"boundary_offset": hotel_boundary, "result_value": 5}], "gates": [], "poll_supplies": []})
		state = o21.state_object
		var hotel1_entry := str(recipe.hotel_chain.hotel1_entry)
		var o22 := probe.run_route(provider, {"entry": hotel1_entry, "start_coordinate": 0, "detect_loops": true}, {}, state)
		if str(o22.get("stop", "")) != "":
			return {"ok": false, "error": "%s did not reach its own terminal: %s" % [hotel1_entry, o22.get("stop", "")]}
		hops.append({"hop_id": "o22_hotel1", "entry": hotel1_entry, "entered_by_kind": "root_handoff",
			"outcome_offset": int(o22.terminal.offset), "outcome_status": str(o22.terminal.status),
			"outcome_target": str(o22.terminal.get("target", "")), "message_count": o22.messages.size(),
			"answers": [], "gates": [{"storage": "state_u16", "bank": 0, "index": 21, "value": 5, "op": "equal",
				"basis": "written_by:o21_hotel"}], "poll_supplies": []})
		state = o22.state_object
		var hotel2_entry := str(recipe.hotel_chain.hotel2_entry)
		var hotel2_descriptor := {"entry": hotel2_entry, "start_coordinate": 0, "detect_loops": true}
		var hotel2_answers := []
		# E and I gate ?_HOTEL2.MES's own terminal handoff behind one more
		# routine-40 (2 options) `docs/spec/mes/heroine_date_flows.md`'s own
		# "no route policy" question - answered value 1 (the first option the
		# choice contract offers), per the task's own policy.
		if recipe.hotel_chain.get("hotel2_choice_boundary") != null:
			var hotel2_boundary := int(recipe.hotel_chain.hotel2_choice_boundary)
			hotel2_descriptor["choices"] = [{"owner_entry": hotel2_entry, "boundary_offset": hotel2_boundary,
				"options": [{"result_value": 1}]}]
			hotel2_answers = [{"boundary_offset": hotel2_boundary, "result_value": 1}]
			contracts.append(_build_contract(hotel2_entry, 0, state))
		var o23 := probe.run_route(provider, hotel2_descriptor, {}, state)
		if str(o23.get("stop", "")) != "":
			return {"ok": false, "error": "%s did not reach its own terminal: %s" % [hotel2_entry, o23.get("stop", "")]}
		hops.append({"hop_id": "o23_hotel2", "entry": hotel2_entry, "entered_by_kind": "root_handoff",
			"outcome_offset": int(o23.terminal.offset), "outcome_status": str(o23.terminal.status),
			"outcome_target": str(o23.terminal.get("target", "")), "message_count": o23.messages.size(),
			"answers": hotel2_answers, "gates": [], "poll_supplies": []})
		state = o23.state_object

	var spec := {
		"group_id": "01m-%s-date" % letter.to_lower(),
		"route_id": "%s-date-%s" % [letter.to_lower(), route_id],
		"source_members": report.get("members", []),
		"state_context": {"kind": "original_calendar"},
		"origin": {"entry": "01M.MES", "offset": int(recipe.guard.offset), "guard_offset": int(recipe.guard.offset),
			"guard_end": int(recipe.guard.end), "false_target": int(recipe.guard.false_target)},
		"guard_cases": [{"case_id": "accepted", "writes": [], "expected": 1},
			{"case_id": "rejected", "writes": [_guard_flag_write()], "expected": 0}],
		"baseline": _baseline_writes(),
		"choice_contracts": contracts,
		"hops": hops,
		"unresolved": [
			"state_u16[18]'s own natural clearing for definition 17's host wait (poll_supplies stands in for it).",
			"state_u16[12]'s natural supply (read as money; who credits it is not measured).",
			"global_u8[200]/[207]'s own natural writer (traced only to a LIBLARY.LIB/?_TALKnn.MES class, per A's own equivalent finding).",
		],
	}
	return {"ok": true, "spec": spec, "hop_count": hops.size(), "terminal": (hops[-1] as Dictionary)}


func _poll_supply() -> Dictionary:
	# `JSON.parse_string` reads every recipe number as a float; the audit
	# requires an exact Python `int`, so every poll_supplies dict this tool
	# writes is rebuilt with explicit `int()`/`str()` coercions rather than
	# reusing the parsed recipe dict verbatim.
	var p: Dictionary = recipe.def17_poll
	return {"definition": int(p.definition), "poll_offset": int(p.poll_offset), "entry": str(p.entry),
		"result_storage": str(p.result_storage), "result_index": int(p.result_index), "value": int(p.value)}


func _train_contract() -> Dictionary:
	var t: Dictionary = recipe.train_contract
	var values := []
	for v in (t.values as Array):
		values.append(int(v))
	return {"entry": str(t.entry), "poll_offset": int(t.poll_offset), "result_storage": str(t.result_storage),
		"result_index": int(t.result_index), "values": values}


func _train_map_location_contract() -> Dictionary:
	# The real `kakyu_mes_map_location_contract/v1` binding
	# (`tools/draft_date_flow_specs.py`'s own `_train_map_location_contract`,
	# built with `build_event_route_profile.py`'s `map_location_binding`) -
	# what a hop's own stored `map_locations` field must hold for
	# `content_core/mes_route_probe.gd`'s `map_location_queues` (the runtime
	# flow validator's own reader) to supply the same poll this tool's own
	# execution used.
	var c: Dictionary = recipe.train_map_location_contract
	var locations := []
	for v in (c.locations as Array):
		locations.append(int(v))
	return {"schema": str(c.schema), "source_identity": {"archive": str(c.source_identity.archive),
			"entry": str(c.source_identity.entry)}, "poll_offset": int(c.poll_offset), "poll_end": int(c.poll_end),
		"poll_function": [int(c.poll_function[0]), int(c.poll_function[1])], "record_sha256": str(c.record_sha256),
		"result_storage": str(c.result_storage), "result_index": int(c.result_index),
		"none_value": int(c.none_value), "locations": locations}


func _open_choice_boundary(err: String, entry: String) -> int:
	# Parses `content_core/mes_route_probe.gd`'s own
	# `"no catalog choice at 0x%X in %s"` stop message back into the boundary
	# offset it names, so an unresolved-choice stop can be retried once with
	# that offset answered, instead of the caller needing to know in advance
	# which heroine's own hop carries an unresolved question.
	var prefix := "no catalog choice at 0x"
	if not err.begins_with(prefix):
		return -1
	var rest := err.substr(prefix.length())
	var hex_part := rest.split(" ")[0]
	if not rest.ends_with(" in %s" % entry):
		return -1
	return ("0x" + hex_part).hex_to_int()


func _guard_flag_write() -> Dictionary:
	for c in recipe.guard.cells:
		if c[0] == "global_u8" and int(c[1]) != int(recipe.params.location_field):
			return {"storage": "global_u8", "bank": 0, "index": int(c[1]), "value": 0}
	return {}


func _baseline_writes() -> Array:
	# Exactly the cells `_init` seeds before any hop runs: today's date/clock
	# matching the promise's own written cells, the guard's own two flags
	# (both `==1` then `==2` in file order), and the promised location
	# (15, avoiding the presentation-only 9..13 flavor branch - A's own tool
	# decision, reused here).
	var promise_field: int = recipe.params.promise_field
	var location_field: int = recipe.params.location_field
	var flag_cells := []
	for c in recipe.guard.cells:
		if c[0] == "global_u8" and int(c[1]) != location_field:
			flag_cells.append(int(c[1]))
	return [
		{"storage": "state_u16", "bank": 0, "index": 7, "value": 502},
		{"storage": "state_u16", "bank": 0, "index": 19, "value": 1530},
		{"storage": "banked_u16", "bank": 0, "index": promise_field, "value": 502},
		{"storage": "banked_u16", "bank": 0, "index": promise_field + 1, "value": 900},
		{"storage": "global_u8", "bank": 0, "index": flag_cells[0], "value": 1},
		{"storage": "global_u8", "bank": 0, "index": flag_cells[1], "value": 2},
		{"storage": "global_u8", "bank": 0, "index": location_field, "value": 15},
	]
