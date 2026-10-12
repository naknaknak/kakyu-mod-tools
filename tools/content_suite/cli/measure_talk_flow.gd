extends "res://tools/content_suite/cli_script.gd"

## EP-12 TALK (2026-10-04): measure the `?_TALK*.MES` conversation scripts of a
## heroine at their confirmed callers and write the
## `tools/build_event_flow_profile.py` spec files, one per route, plus a
## measurement report. Driven by `tools/draft_talk_flow_specs.py`'s recipe (the
## archive's own bytecode offsets and the seeded state, found statically); this
## tool runs the three hops and walks the answers.
##
## A route is three hops, each one fresh `probe.run_route` call through the
## shared call frame (`content_core/mes_route_probe.gd`), exactly as
## `tools/content_suite/event_flow_runner.gd` runs them later:
##
##   hop 1  the caller from the block guard (the route's origin) through the
##          block's picture and intro scripts, the gate and the rung's test to
##          the script's nested-call record
##   hop 2  the script from its start to its own `script_return`, the first
##          option at every question (the question contracts are built from the
##          live stop; the natural presence state registers ids the contract tool
##          names since Core 0.371.0)
##   hop 3  the caller resuming after the call (the PROMIS call when the flag is
##          up, the outro, the shared tail) to its natural end: the town handoff
##
## A band-less script (a heroine's plain `?_TALK`, `M_TALK`, `N_TALK`..`Q_TALK1`) is
## the first two hops, plus the third when the recipe says `resume_hop: true` or, for
## `"auto"` (any caller but the `27C_EV.MES` day loop), when running hop 3 once on the
## default path reaches a handoff or a return; the probe is in the report either way.
## A question the contract tool cannot name, on an answered path other than the default
## one, is a leaf that does not run to the route's terminal (not a variant, named in
## `unresolved`); on the default path it stops the tool.
##
## The state is the **natural state** at the anchor, seeded by the recipe (tool
## decisions, labelled in the route's `unresolved`): the block guard's own
## conjuncts, the gate, the rung's affection band, every topic done-flag 0. The
## route's own path is its **default variant**. What the script can otherwise do
## is declared as variants through `menu_flow_variants.gd`'s rules
## (docs/spec/tech/content_tools.md, "Variant `answers` and `message_counts`"):
## every other answered combination that ends at the route's own two outcomes
## (the script's return and the caller's end) is an `answers` variant named
## `option-<values in the order asked>`; a follow-on call behind a single flag
## is a named cell variant `flag-<cell>` (the flag flipped). A path that ends
## elsewhere, that does not return, or that re-asks a question it answered (a
## loop) cannot be a variant (the stop rule); the report counts them and the
## route's `unresolved` names them.
##
##   godot --headless --path . --script res://tools/content_suite/cli/measure_talk_flow.gd \
##       -- "<ELFIMAGE dir>" analysis/_undoc/ep12_talk_k/recipe.json analysis/_undoc/ep12_talk_k/specs analysis/_undoc/ep12_talk_k/report.json [<route id>]

const Probe := preload("res://content_core/mes_route_probe.gd")
const State := preload("res://content_core/mes_sandbox_state.gd")
const ContainerScript := preload("res://content_core/mes_container.gd")
const ChoiceContractScript := preload("res://content_core/mes_routine40_choice_contract.gd")
const Runner := preload("res://content_core/mes_event_runner.gd")
const MenuVariants := preload("res://tools/content_suite/menu_flow_variants.gd")

const HOP_CALLER := "h1_caller_dispatch"
const HOP_TALK := "h2_talk"
const HOP_RESUME := "h3_caller_resume"
const MAX_QUESTIONS := 6
## A script whose questions multiply past this many paths is not measured
## silently: the measurer stops and names it.
const MAX_LEAVES := 400
const RETURN_STATUS := "script_return"

var recipe := {}
var documents := {}
var provider: Dictionary
var probe: KakyuMesRouteProbe


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 4:
		_fail("usage: -- <ELFIMAGE dir> <recipe.json> <out dir> <report.json> [<route id>]")
		return
	var elfimage := ProjectSettings.globalize_path(str(args[0]))
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(str(args[1])))
	if not parsed is Dictionary:
		_fail("the recipe is not a JSON object: %s" % args[1])
		return
	recipe = parsed
	var out_dir := str(args[2])
	var report_path := str(args[3])
	var only := str(args[4]) if args.size() > 4 else ""

	var members: Array = []
	for route in recipe.routes:
		if only != "" and str(route.route_id) != only:
			continue
		for name in [route.caller, route.callee]:
			if not members.has(str(name)):
				members.append(str(name))
		for name in route.callee_nested:
			if not members.has(str(name)):
				members.append(str(name))
		for name in route.block_members:
			if not members.has(str(name)):
				members.append(str(name))
	for support in recipe.support_members:
		if not members.has(str(support)):
			members.append(str(support))
	var reader := preload("res://content_core/arc_reader.gd").new()
	if not reader.open(elfimage.path_join("mes.arc")) or reader.get_archive_fingerprint() != str(recipe.archive_sha256):
		_fail("the archive is not the one the recipe was drafted from")
		return
	for member in members:
		documents[member] = ContainerScript.new().parse(reader.read_entry(member), {"entry": member, "archive": "mes.arc"})
		if not documents[member].get("ok", false):
			reader.close()
			_fail("%s did not parse" % member)
			return
	reader.close()
	probe = Probe.new()
	provider = probe.context_from_documents(documents)

	var report := {"archive_sha256": str(recipe.archive_sha256), "routes": []}
	var failed := false
	DirAccess.make_dir_recursive_absolute(out_dir)
	for route in recipe.routes:
		if only != "" and str(route.route_id) != only:
			continue
		var measured := _measure_route(route)
		(report.routes as Array).append(measured.report)
		if not measured.get("ok", false):
			print("ROUTE_FAILED ", route.route_id, " ", measured.get("error", ""))
			failed = true
			continue
		var file := FileAccess.open(out_dir.path_join("%s_spec.json" % str(route.route_id).replace("-", "_")), FileAccess.WRITE)
		file.store_string(JSON.stringify(measured.spec, "  "))
		file.close()
		print("ROUTE_OK ", route.route_id, " hop2=", measured.report.default.hop2_messages, " hop3=", measured.report.default.hop3_messages,
			" variants=", measured.report.variants)
	var report_file := FileAccess.open(report_path, FileAccess.WRITE)
	report_file.store_string(JSON.stringify(report, "  "))
	report_file.close()
	if failed:
		quit(1)
		return
	print("MEASURED_OK ", report_path)
	quit(0)


func _write(storage: String, index: int, value: int) -> Dictionary:
	return {"storage": storage, "bank": 0, "index": index, "value": value}


## The recipe's writes as whole numbers: JSON read back turns every number into a float,
## and a profile's writes must be integers (the audit refuses a float).
func _whole_writes(writes: Array) -> Array:
	var out := []
	for untyped_write in writes:
		var write: Dictionary = untyped_write
		out.append(_write(str(write.storage), int(write.index), int(write.value)))
	return out


func _seeded_state(route: Dictionary, variant_writes: Array, extra_writes: Array = []) -> KakyuMesSandboxState:
	var state := State.new(1)
	if not state.load_values(route.baseline).get("ok", false) or not state.load_values(variant_writes).get("ok", false) \
			or not state.load_values(extra_writes).get("ok", false):
		return null
	return state


func _terminal_text(run: Dictionary) -> String:
	var run_terminal: Dictionary = run.get("terminal", {})
	return "%s@%d" % [str(run_terminal.get("status", "")), int(run_terminal.get("offset", -1))]


func _entries_of(run: Dictionary, into: Array) -> void:
	for segment in run.get("segments", []):
		var entry := str((segment as Dictionary).get("entry", ""))
		if entry != "" and not into.has(entry):
			into.append(entry)


## The two guard witnesses of the route, run the way the flow validator runs them.
func _check_guard(route: Dictionary) -> String:
	var caller := str(route.caller)
	var origin: Dictionary = route.origin
	var code: PackedByteArray = provider.entries[caller].code
	for witness in [{"id": "accepted", "expected": 1, "writes": []}, {"id": "rejected", "expected": 0, "writes": route.guard_rejected_writes}]:
		var state := _seeded_state(route, witness.writes)
		if state == null:
			return "the guard witness state did not load"
		var result := Runner.new().run(code, int(origin.guard_offset), state, int(provider.entries[caller].code_size), 1)
		var trace: Array = result.get("trace", [])
		var row: Dictionary = trace[0] if trace.size() == 1 else {}
		var next_expected := int(origin.guard_end) if int(witness.expected) == 1 else int(origin.false_target)
		if int(row.get("source_offset", -1)) != int(origin.guard_offset) or int(row.get("end_offset", -1)) != int(origin.guard_end) \
				or int(row.get("condition_value", -1)) != int(witness.expected) or int(row.get("next_offset", -1)) != next_expected:
			return "the %s guard witness does not hold at %d" % [witness.id, int(origin.guard_offset)]
	return ""


## Hop 1 from a seeded state. `{ok, error, run}`; the carried state is `run.state_object`.
func _hop1(route: Dictionary, state: KakyuMesSandboxState) -> Dictionary:
	var caller := str(route.caller)
	var dispatch: Dictionary = route.dispatch
	var run := probe.run_route(provider, {
		"entry": caller, "start_coordinate": int(route.origin.offset), "choices": [], "map_locations": [], "poll_supplies": [],
		"stop_before_dispatch": {"entry": caller, "offset": int(dispatch.offset), "end": int(dispatch.end), "target": str(route.callee)},
	}, {}, state)
	var detail: Dictionary = run.get("stop_detail", {})
	if str(detail.get("status", "")) != "analysis_dispatch_stop":
		return {"ok": false, "error": "%s did not reach the %s call: %s" % [caller, route.callee, run.get("error", run.get("stop", ""))]}
	return {"ok": true, "run": run}


## Hop 2 from the carried state with `answers` (`[{boundary_offset, result_value}]`).
func _hop2(route: Dictionary, carried: KakyuMesSandboxState, answers: Array, detect_loops: bool) -> Dictionary:
	var target := str(route.callee)
	var choices := []
	for untyped_answer in answers:
		var answer: Dictionary = untyped_answer
		choices.append({"owner_entry": target, "boundary_offset": int(answer.boundary_offset), "options": [{"result_value": int(answer.result_value)}]})
	return probe.run_route(provider, {"entry": target, "start_coordinate": 0, "choices": choices, "map_locations": [], "poll_supplies": [],
		"detect_loops": detect_loops}, {}, carried.duplicate_state())


## Hop 3: the caller resuming at the call's end from the state hop 2 left.
func _hop3(route: Dictionary, after_hop2: KakyuMesSandboxState) -> Dictionary:
	return probe.run_route(provider, {"entry": str(route.caller), "start_coordinate": int(route.dispatch.end), "choices": [], "map_locations": [],
		"poll_supplies": []}, {}, after_hop2.duplicate_state())


func _build_contract(target: String, stop_detail: Dictionary) -> Dictionary:
	var live_code: PackedByteArray = documents[target].bytecode
	var contract: Dictionary = ChoiceContractScript.new().build(live_code, int(stop_detail.get("code_size", live_code.size())),
		stop_detail.result, stop_detail.get("source_identity", {"entry": target, "archive": "mes.arc"}))
	return contract if contract.get("ok", false) else {"error": str(contract.get("error", "the question contract did not build"))}


## A leaf of the walk: hop 2's run and, when it returned, hop 3's.
func _leaf(route: Dictionary, answers: Array, run: Dictionary) -> Dictionary:
	var stop := str(run.get("stop", ""))
	var hop2_terminal := _terminal_text(run)
	var leaf := {"answers": answers, "stop": stop, "messages": (run.messages as Array).size(), "terminal": hop2_terminal,
		"hop2_terminal": hop2_terminal, "hop3_messages": 0, "hop3_terminal": "", "hop3_stop": "", "entries": []}
	_entries_of(run, leaf.entries)
	var status := str((run.get("terminal", {}) as Dictionary).get("status", ""))
	if stop == "" and status == RETURN_STATUS and bool(route.resume_hop):
		var resumed := _hop3(route, run.state_object)
		leaf["hop3_messages"] = (resumed.messages as Array).size()
		leaf["hop3_terminal"] = _terminal_text(resumed)
		leaf["hop3_stop"] = str(resumed.get("stop", ""))
		leaf["terminal"] = "%s>%s" % [hop2_terminal, leaf.hop3_terminal]
		if leaf.hop3_stop != "":
			leaf["stop"] = "hop 3: %s" % leaf.hop3_stop
		_entries_of(resumed, leaf.entries)
		var resume_terminal: Dictionary = resumed.get("terminal", {})
		leaf["hop3_target"] = str(resume_terminal.get("target", ""))
		leaf["hop3_status"] = str(resume_terminal.get("status", ""))
		leaf["hop3_offset"] = int(resume_terminal.get("offset", -1))
		leaf["hop3_segments"] = (resumed.segments as Array).size()
	return leaf


## Every answered path of hop 2, depth first and in option order, with hop 3 run
## for each path that returns. `found` collects the contracts met.
func _walk(route: Dictionary, carried: KakyuMesSandboxState, prefix: Array, found: Dictionary, leaves: Array) -> String:
	var run := _hop2(route, carried, prefix, true)
	var stop_detail: Dictionary = run.get("stop_detail", {})
	var target := str(route.callee)
	if str(stop_detail.get("kind", "")) == "unanswered_choice" and str(stop_detail.get("entry", "")) == target:
		if prefix.size() >= MAX_QUESTIONS:
			return "more than %d questions on one path" % MAX_QUESTIONS
		var contract := _build_contract(target, stop_detail)
		if contract.has("error"):
			# A question the contract tool cannot name (heroine J's three, `docs/spec/mes/talk_family.md`)
			# met by an answered path other than the default one: the path is recorded as a leaf that
			# does not run to the route's terminal (the stop rule: not a variant, named in `unresolved`).
			var unnamed := "the question at %d is not nameable by the contract tool (%s)" % [int(stop_detail.get("boundary_offset", -1)), str(contract.error)]
			leaves.append({"answers": prefix, "stop": unnamed, "messages": (run.messages as Array).size(), "terminal": _terminal_text(run),
				"hop2_terminal": _terminal_text(run), "hop3_messages": 0, "hop3_terminal": "", "hop3_stop": "", "entries": []})
			return ""
		var boundary := int(contract.boundary_offset)
		if not found.has(boundary):
			found[boundary] = contract
		for value in range(1, int(contract.get("definition_count", 1)) + 1):
			var next := prefix.duplicate(true)
			next.append({"boundary_offset": boundary, "result_value": value})
			var error := _walk(route, carried, next, found, leaves)
			if error != "":
				return error
		return ""
	if leaves.size() >= MAX_LEAVES:
		return "more than %d answer paths" % MAX_LEAVES
	leaves.append(_leaf(route, prefix, run))
	return ""


func _answers_equal(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for untyped_answer in a:
		var answer: Dictionary = untyped_answer
		var matched := false
		for untyped_other in b:
			var other: Dictionary = untyped_other
			if int(other.boundary_offset) == int(answer.boundary_offset) and int(other.result_value) == int(answer.result_value):
				matched = true
		if not matched:
			return false
	return true


## The single flag a follow-on call sits behind: the nearest enclosing branch with
## one `global_u8` comparison. Returns `{cell, value}` (the value that flips it) or
## `{}` when the follow-on is behind an answer arm only (the walk covers it).
func _flag_of(follow_on: Dictionary) -> Dictionary:
	var enclosing: Array = follow_on.enclosing
	for index in range(enclosing.size() - 1, -1, -1):
		var branch: Dictionary = enclosing[index]
		var atoms: Array = branch.get("atoms", [])
		if atoms.is_empty():
			continue
		if atoms.size() == 1 and str(atoms[0].storage) == "global_u8" and str(atoms[0].op) in ["equal", "not_equal"]:
			var atom: Dictionary = atoms[0]
			var flipped := (1 if int(atom.value) == 0 else 0) if str(atom.op) == "equal" else int(atom.value)
			return {"cell": int(atom.index), "value": flipped}
		if atoms.size() == 1 and str(atoms[0].storage) == "state_u16" and int(atoms[0].index) == 21:
			return {}
		return {"error": "the follow-on at %d sits behind a condition that is neither an answer arm nor a single flag: %s" % [int(follow_on.offset), str(branch.condition)]}
	return {"error": "the follow-on at %d has no enclosing condition" % int(follow_on.offset)}


func _measure_route(route: Dictionary) -> Dictionary:
	var caller := str(route.caller)
	var target := str(route.callee)
	var report := {"route_id": str(route.route_id), "callee": target, "caller": caller}
	route["baseline"] = _whole_writes(route.baseline)
	route["guard_rejected_writes"] = _whole_writes(route.guard_rejected_writes)

	var guard_error := _check_guard(route)
	if guard_error != "":
		return {"ok": false, "error": "%s: %s" % [route.route_id, guard_error], "report": report}
	var state := _seeded_state(route, [])
	if state == null:
		return {"ok": false, "error": "baseline did not load", "report": report}
	var first := _hop1(route, state)
	if not first.ok:
		return {"ok": false, "error": "%s: %s" % [route.route_id, first.error], "report": report}
	var hop1: Dictionary = first.run
	var hop1_messages: int = (hop1.messages as Array).size()
	var carried: KakyuMesSandboxState = hop1.state_object
	var visited: Array = []
	_entries_of(hop1, visited)
	report["hop1"] = {"messages": hop1_messages, "segments": (hop1.segments as Array).size(), "entries": visited.duplicate()}

	# Hop 2 by default: the first option at every question, the contract built from the live stop.
	var contracts := []
	var answers := []
	var hop2 := {}
	for _attempt in range(MAX_QUESTIONS + 1):
		hop2 = _hop2(route, carried, answers, false)
		var stop_detail: Dictionary = hop2.get("stop_detail", {})
		if str(stop_detail.get("kind", "")) != "unanswered_choice":
			break
		if str(stop_detail.get("entry", "")) != target:
			return {"ok": false, "error": "%s: a question outside the script stopped the run (%s)" % [route.route_id, str(stop_detail.get("entry", ""))], "report": report}
		var contract := _build_contract(target, stop_detail)
		if contract.has("error"):
			report["unnamed_question"] = {"boundary_offset": int(stop_detail.get("boundary_offset", -1)), "error": str(contract.error)}
			return {"ok": false, "error": "%s: the question at %d is not nameable: %s" % [route.route_id, int(stop_detail.get("boundary_offset", -1)), str(contract.error)], "report": report}
		contracts.append(contract)
		answers.append({"boundary_offset": int(contract.boundary_offset), "result_value": 1})
	if str(hop2.get("stop", "")) != "":
		return {"ok": false, "error": "%s did not return: %s" % [route.route_id, hop2.get("stop", "")], "report": report}
	var terminal2: Dictionary = hop2.terminal
	if str(terminal2.get("status", "")) != RETURN_STATUS:
		return {"ok": false, "error": "%s ended in %s, not a script_return" % [route.route_id, terminal2.get("status", "")], "report": report}
	var is_return_record := false
	for record in route.callee_returns:
		if int(record) == int(terminal2.offset):
			is_return_record = true
	if not is_return_record:
		return {"ok": false, "error": "%s returned at %d, which is not one of its return records %s" % [route.route_id, int(terminal2.offset), str(route.callee_returns)], "report": report}
	if typeof(route.resume_hop) == TYPE_STRING:
		# "auto" (a caller other than the 27C_EV.MES day loop): the caller resumes after the call and the
		# route keeps a third hop only if that reaches a natural end - a handoff or a return - rather than
		# stopping (a day loop, a question). The probe's result is reported either way.
		var probe_resume := _hop3(route, hop2.state_object)
		var probe_terminal: Dictionary = probe_resume.get("terminal", {})
		var natural := str(probe_resume.get("stop", "")) == "" \
			and str(probe_terminal.get("status", "")) in ["script_handoff_boundary", RETURN_STATUS]
		route["resume_hop"] = natural
		route["hop3_note"] = "" if natural else "stop=%s, terminal=%s" % [str(probe_resume.get("stop", "")), _terminal_text(probe_resume)]
		report["hop3_probe"] = {"natural_end": natural, "stop": str(probe_resume.get("stop", "")), "terminal": _terminal_text(probe_resume),
			"messages": (probe_resume.messages as Array).size(), "segments": (probe_resume.segments as Array).size()}
	var default_leaf := _leaf(route, answers, hop2)
	if str(default_leaf.stop) != "":
		return {"ok": false, "error": "%s: hop 3 did not run to its end: %s" % [route.route_id, default_leaf.stop], "report": report}
	var resume_hop := bool(route.resume_hop)
	route["hop3_target"] = str(default_leaf.get("hop3_target", ""))
	var hop3_status := str(default_leaf.get("hop3_status", ""))
	if resume_hop:
		if hop3_status != "script_handoff_boundary" and hop3_status != RETURN_STATUS:
			return {"ok": false, "error": "%s: hop 3 ended in %s, not a handoff or a return" % [route.route_id, hop3_status], "report": report}
		if hop3_status == "script_handoff_boundary" and str(default_leaf.hop3_target) == "":
			return {"ok": false, "error": "%s: hop 3's handoff has no target" % route.route_id, "report": report}
	var hop2_messages: int = (hop2.messages as Array).size()
	var default_terminal := str(default_leaf.terminal)
	for entry in default_leaf.entries:
		if not visited.has(entry):
			visited.append(entry)
	report["default"] = {"hop2_messages": hop2_messages, "hop2_segments": (hop2.segments as Array).size(), "hop2_terminal": str(default_leaf.hop2_terminal),
		"hop3_messages": int(default_leaf.hop3_messages), "hop3_segments": int(default_leaf.get("hop3_segments", 0)), "hop3_terminal": str(default_leaf.hop3_terminal),
		"hop3_target": str(default_leaf.get("hop3_target", "")), "answers": answers, "questions": contracts.size()}
	var question_report := []
	for contract in contracts:
		question_report.append({"boundary_offset": int(contract.boundary_offset), "consumer_kind": str(contract.consumer_kind), "options": int(contract.definition_count),
			"catalog_form": str(contract.catalog_form), "hidden_ids": contract.hidden_ids})
	report["questions"] = question_report

	# Every answered path.
	var found := {}
	for contract in contracts:
		found[int((contract as Dictionary).boundary_offset)] = contract
	var leaves := []
	var walk_error := _walk(route, carried, [], found, leaves)
	if walk_error != "":
		return {"ok": false, "error": "%s: %s" % [route.route_id, walk_error], "report": report}
	var default_found := false
	for leaf in leaves:
		if _answers_equal(leaf.answers, answers):
			default_found = true
			if int(leaf.messages) != hop2_messages or str(leaf.terminal) != default_terminal or int(leaf.hop3_messages) != int(default_leaf.hop3_messages):
				return {"ok": false, "error": "%s: the answer walk's default path disagrees with the default run" % route.route_id, "report": report}
	if not default_found:
		return {"ok": false, "error": "%s: the answer walk never reached the default path" % route.route_id, "report": report}

	# Follow-on calls behind a single flag: a named cell variant (the flag flipped).
	var cell_paths := []
	var cell_counts := {}
	var seen_flags := {}
	var follow_on_report := []
	for follow_on in route.follow_ons:
		var flag := _flag_of(follow_on)
		if flag.has("error"):
			return {"ok": false, "error": "%s: %s" % [route.route_id, flag.error], "report": report}
		if flag.is_empty():
			follow_on_report.append({"offset": int(follow_on.offset), "behind": "an answer arm"})
			continue
		follow_on_report.append({"offset": int(follow_on.offset), "behind": "flag", "cell": int(flag.cell), "value": int(flag.value)})
		if seen_flags.has(int(flag.cell)):
			continue
		seen_flags[int(flag.cell)] = true
		var flagged_state := _seeded_state(route, [_write("global_u8", int(flag.cell), int(flag.value))])
		var flagged_first := _hop1(route, flagged_state)
		if not flagged_first.ok:
			return {"ok": false, "error": "%s (flag %d): %s" % [route.route_id, int(flag.cell), flagged_first.error], "report": report}
		var flagged_run := _hop2(route, flagged_first.run.state_object, answers, true)
		var flagged_leaf := _leaf(route, answers, flagged_run)
		var path_id := "flag-%d" % int(flag.cell)
		cell_paths.append({"variant_id": path_id, "label": "global_u8[%d] = %d (the follow-on's own flag)" % [int(flag.cell), int(flag.value)],
			"cells": [int(flag.cell)], "value": int(flag.value), "stop": str(flagged_leaf.stop), "messages": int(flagged_leaf.messages),
			"terminal": str(flagged_leaf.terminal)})
		cell_counts[path_id] = {"hop1": (flagged_first.run.messages as Array).size(), "hop2": int(flagged_leaf.messages), "hop3": int(flagged_leaf.hop3_messages),
			"entries": flagged_leaf.entries}
	report["follow_ons"] = follow_on_report

	var assembled := MenuVariants.assemble(HOP_TALK, answers, hop2_messages, default_terminal, leaves, {}, cell_paths)

	# A variant's `message_counts` names every hop whose count differs from the default's:
	# the walk's `assemble` knows hop 2 only, hop 1 and hop 3 are measured here.
	var leaf_counts := {}
	for leaf in leaves:
		leaf_counts[MenuVariants.variant_id(leaf.answers)] = {"hop1": hop1_messages, "hop2": int(leaf.messages), "hop3": int(leaf.hop3_messages), "entries": leaf.entries}
	var default_counts := {HOP_CALLER: hop1_messages, HOP_TALK: hop2_messages, HOP_RESUME: int(default_leaf.hop3_messages)}
	var declared_entries := visited.duplicate()
	for variant in assembled.variants:
		var variant_id := str((variant as Dictionary).variant_id)
		if variant_id == "default":
			continue
		var counts: Dictionary = leaf_counts.get(variant_id, cell_counts.get(variant_id, {}))
		var named := {}
		if int(counts.get("hop1", hop1_messages)) != hop1_messages:
			named[HOP_CALLER] = int(counts.hop1)
		if int(counts.get("hop2", hop2_messages)) != hop2_messages:
			named[HOP_TALK] = int(counts.hop2)
		if int(counts.get("hop3", int(default_leaf.hop3_messages))) != int(default_leaf.hop3_messages):
			named[HOP_RESUME] = int(counts.hop3)
		if named.is_empty():
			(variant as Dictionary).erase("message_counts")
		else:
			(variant as Dictionary)["message_counts"] = named
		for entry in counts.get("entries", []):
			if not declared_entries.has(entry):
				declared_entries.append(entry)
	var variant_ids := []
	for variant in assembled.variants:
		variant_ids.append(str((variant as Dictionary).variant_id))

	# A question that exists only on a variant's path needs its own contract in the route.
	var known_boundaries := []
	for contract in contracts:
		known_boundaries.append(int((contract as Dictionary).boundary_offset))
	for variant in assembled.variants:
		for variant_answer in (variant as Dictionary).get("answers", []):
			var boundary := int(variant_answer.boundary_offset)
			if not known_boundaries.has(boundary):
				contracts.append(found[boundary])
				known_boundaries.append(boundary)

	# A path that comes back to the question it answered is a re-ask (a decline arm of the topic
	# hub): either the run repeats unchanged (a proven loop) or the question returns without the
	# answered option (its topic is spent), which the probe reports as an answer outside the
	# contract. Both are counted; neither can be a variant.
	var loops := 0
	var spent := 0
	var other_not_declared := []
	var loop_ids := []
	for untyped_entry in assembled.not_declared:
		var entry: Dictionary = untyped_entry
		if str(entry.reason).contains("loop_boundary"):
			loops += 1
			loop_ids.append(str(entry.variant_id))
		elif str(entry.reason).contains("is outside the contract"):
			spent += 1
			loop_ids.append(str(entry.variant_id))
		else:
			other_not_declared.append(entry)
	report["answer_paths"] = leaves.size()
	report["variants"] = maxi(variant_ids.size() - 1, 0)
	report["variant_ids"] = variant_ids
	report["loops"] = loops
	report["reask_option_gone"] = spent
	report["not_declared"] = assembled.not_declared
	report["variant_only_questions"] = assembled.variant_only_questions
	report["skipped_questions"] = assembled.skipped_questions
	report["leaves"] = _leaves_report(leaves, answers, assembled)
	var unresolved := _unresolved(route, answers, int(default_leaf.hop3_messages), leaves.size(), loops, spent, loop_ids, other_not_declared, cell_paths, contracts)

	var spec_members := [caller, target]
	for entry in declared_entries:
		if not spec_members.has(str(entry)):
			spec_members.append(str(entry))
	for support in recipe.support_members:
		if not spec_members.has(str(support)):
			spec_members.append(str(support))
	report["source_members"] = spec_members

	var hop3_outcome_target := str(default_leaf.get("hop3_target", ""))
	var spec := {
		"group_id": str(route.group_id),
		"route_id": str(route.route_id),
		"source_members": spec_members,
		"state_context": {"kind": "fresh"},
		"origin": {"entry": caller, "offset": int(route.origin.offset), "guard_offset": int(route.origin.guard_offset),
			"guard_end": int(route.origin.guard_end), "false_target": int(route.origin.false_target)},
		"guard_cases": [
			{"case_id": "accepted", "expected": 1, "writes": []},
			{"case_id": "rejected", "expected": 0, "writes": route.guard_rejected_writes},
		],
		"baseline": route.baseline,
		"choice_contracts": contracts,
		"hops": [
			{"hop_id": HOP_CALLER, "entry": caller, "answers": [], "gates": [], "message_count": hop1_messages,
				"outcome_offset": int(route.dispatch.offset), "outcome_status": "script_dispatch_boundary", "outcome_target": target},
			{"hop_id": HOP_TALK, "entry": target, "entered_by_kind": "nested_call", "answers": answers, "gates": [],
				"message_count": hop2_messages, "outcome_offset": int(terminal2.offset), "outcome_status": RETURN_STATUS},
		],
		"unresolved": unresolved,
	}
	if resume_hop:
		(spec.hops as Array).append({"hop_id": HOP_RESUME, "entry": caller, "entered_by_kind": "resume", "answers": [], "gates": [],
			"message_count": int(default_leaf.hop3_messages), "outcome_offset": int(default_leaf.hop3_offset),
			"outcome_status": hop3_status, "outcome_target": hop3_outcome_target})
	if not (assembled.variants as Array).is_empty():
		spec["variants"] = assembled.variants
	return {"ok": true, "spec": spec, "report": report}


## The report's account of every measured path other than the default.
func _leaves_report(leaves: Array, default_answers: Array, assembled: Dictionary) -> Array:
	var declared_ids := {}
	for variant in assembled.variants:
		declared_ids[str((variant as Dictionary).variant_id)] = true
	var out := []
	for leaf in leaves:
		if _answers_equal(leaf.answers, default_answers):
			continue
		var id := MenuVariants.variant_id(leaf.answers)
		out.append({"variant_id": id, "answers": leaf.answers, "stop": str(leaf.stop), "hop2_messages": int(leaf.messages),
			"hop3_messages": int(leaf.hop3_messages), "terminal": str(leaf.terminal), "declared": declared_ids.has(id)})
	return out


## The route's `unresolved` lines: the tool decisions of the seeded state and what the
## walk left undeclared. English paraphrase of measured facts only.
func _unresolved(route: Dictionary, answers: Array, hop3_messages: int, path_count: int, loops: int, spent: int, loop_ids: Array,
		other_not_declared: Array, cell_paths: Array, contracts: Array) -> Array:
	var lines := []
	var baseline_cells := []
	for write in route.baseline:
		baseline_cells.append("%s[%d] = %d" % [str(write.storage), int(write.index), int(write.value)])
	if str(route.kind) == "ladder":
		var cells: Dictionary = route.block.cells
		lines.append("The state at the anchor is seeded, a tool decision: %s. The origin is the block guard at %d (the place's own level-0 gate is not part of the route); the heroine's presence flag global_u8[%d] = 1 is the natural presence state the guard requires, her block flag global_u8[%d] and today flag global_u8[%d] are clear (the guard's and the gate's own conjuncts), the affection word banked_u16[%d] = %d sits inside the rung's band, the calendar window is the guard's first alternative (weekday 0, the clock inside its window)." % [
			", ".join(baseline_cells), int(route.origin.guard_offset), int(cells.presence[1]), int(cells.block[1]), int(cells.today[1]), int(cells.affection[1]), int(route.affection)])
	elif str(route.kind) == "plain":
		lines.append("The state at the anchor is seeded, a tool decision: %s. The origin is the caller's block guard at %d; the cells are the guard's own conjuncts and the script's own gate (its date, affection word and once-only flag), solved by the smallest round value that satisfies them." % [
			", ".join(baseline_cells), int(route.origin.guard_offset)])
	else:
		lines.append("The state at the anchor is seeded, a tool decision: %s. The origin is the caller's block guard at %d; the cells are the guard's own conjuncts alone, solved by the smallest round value that satisfies them. The script is a chain of bodies each selected by flags and dates, and every cell the guard does not fix is 0 (the natural state), so the body that state selects is the one that plays." % [
			", ".join(baseline_cells), int(route.origin.guard_offset)])
	if str(route.kind) == "ladder" and (route.block as Dictionary).has("intro_affection_cap"):
		var cap: Dictionary = route.block.intro_affection_cap
		lines.append("The date is seeded at %d, a tool decision: the heroine's intro script %s caps her affection word at %d while the date is below %d (a branch at %d), and it runs before the rung test, so a rung above the cap is reachable only on a date the cap is off." % [
			int(cap.date_below), str(cap.entry), int(cap.affection_above), int(cap.date_below), int(cap.offset)])
	if answers.is_empty() and str(route.kind) == "character":
		lines.append("The script asks no question on the default path; it plays the body the seeded state selects (%d answer path(s) measured)." % [path_count])
	elif answers.is_empty():
		lines.append("The script asks no question; its own gate (date, affection word and once-only flag) is seeded satisfied, so the default path plays it whole (%d answer path(s) measured)." % [path_count])
	else:
		lines.append("The topic state is the natural one: every topic's done flag and the scratch cells the script clears at its start are 0, and the default path answers option 1 at each of its %d question(s). The script's other topic states (flags set by other events) are not walked; %d answer path(s) were measured." % [answers.size(), path_count])
	var kinds := {}
	for contract in contracts:
		kinds[str((contract as Dictionary).consumer_kind)] = true
	if kinds.has("one_based_state_u16_21_scratch_split_branch_chain"):
		lines.append("A question's consumer is a one-based chain whose positions split on scratch cells; the contract carries each position's cell (`position_gates`, Core 0.371.0).")
	if bool(route.resume_hop) and str(route.kind) != "ladder":
		lines.append("Hop 3 resumes the caller after the call and runs to its natural end, the handoff to %s (the probe reached it without a stop); it plays %d message(s) on the default path." % [str(route.get("hop3_target", "")), hop3_messages])
	elif bool(route.resume_hop):
		lines.append("Hop 3 resumes the caller after the call (the PROMIS call when the flag is up, the outro and the shared tail) and ends at the town handoff, the caller's natural end; it plays %d message(s) on the default path." % [hop3_messages])
	elif str(route.get("hop3_note", "")) != "":
		lines.append("The caller resumes after the call and does not reach a natural end the probe can measure (hop 3 stops: %s), so the flow ends at the script's own return." % [str(route.hop3_note)])
	else:
		lines.append("The caller resumes into the place's day loop after the call, which runs on day after day (its own definition steps stop at the probe's limit, and under the original calendar the loop plays on to the game's ending): there is no natural end to measure, so the flow ends at the script's own return.")
	if loops + spent > 0:
		lines.append("%d answer path(s) re-ask a question they answered (back to it unchanged: %d; the answered option gone: %d): %s; a topic hub's decline arms, not declared - a variant must end at the route's own terminal." % [
			loops + spent, loops, spent, ", ".join(PackedStringArray(loop_ids))])
	lines.append_array(MenuVariants.unresolved_lines(other_not_declared))
	for path in cell_paths:
		lines.append("The follow-on script is called only while global_u8[%d] is clear (its own done flag); the variant %s sets it and plays the script without the follow-on." % [
			int((path.cells as Array)[0]), str(path.variant_id)])
	return lines
