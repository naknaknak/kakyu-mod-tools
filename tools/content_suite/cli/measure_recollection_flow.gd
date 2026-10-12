extends "res://tools/content_suite/cli_script.gd"

## EP-12 H (2026-10-04): measure the 13 `?_H.MES` recollection ladders of the
## protagonist's room and write the `tools/build_event_flow_profile.py` spec
## files, one per ladder, plus a measurement report. Driven by
## `tools/draft_recollection_flow_specs.py`'s recipe (the archive's own bytecode
## offsets and each ladder's gates, found statically); this tool supplies the
## seeded state and runs the two hops.
##
## A route is two hops, each one fresh `probe.run_route` call through the shared
## call frame (`content_core/mes_route_probe.gd`), exactly as
## `tools/content_suite/event_flow_runner.gd` runs them later:
##
##   hop 1  `43C.MES` from the clock save (the route's origin, after the
##          answer-3 test of the room-action menu) through the id test
##          `state_u16[13] == id` to the ladder's nested-call record, no message
##   hop 2  the ladder from its own start to its own `script_return`, with
##          `segment_budget` 1024: a ladder plays 570..911 messages, one
##          segment each, and the probe's default budget is 512 segments
##
## The room-action menu's selection and the heroine id are **seeded state - a
## tool decision**: the question at 20161 is a shape the choice-contract tool
## cannot name and `43C.MES` never writes `state_u16[13]`, so the baseline writes
## the cells the selection would have left (`state_u16[13]` = the picker id,
## `state_u16[21]` = 3) beside the room's evening ambient cells.
##
## The default variant is the **full recollection**: every gate flag of the
## ladder set (the recipe's `gates`, the structural rule of the drafter). The
## second variant, `no-recollection`, writes every gate cell 0 - what a room
## played before any of the events ran. Both must end at the same
## `script_return` (the stop rule of `menu_flow_variants.gd`, which assembles
## the variants: a named cell-write variant). Per-segment combinations (2^n) are
## not walked.
##
##   godot --headless --path . --script res://tools/content_suite/cli/measure_recollection_flow.gd \
##       -- "<ELFIMAGE dir>" analysis/_undoc/ep12_h_recipe.json analysis/_undoc/ep12h_specs analysis/_undoc/ep12_h_report.json

const Probe := preload("res://content_core/mes_route_probe.gd")
const State := preload("res://content_core/mes_sandbox_state.gd")
const ContainerScript := preload("res://content_core/mes_container.gd")
const MenuVariants := preload("res://tools/content_suite/menu_flow_variants.gd")

const HOP_ROOM := "h1_room_dispatch"
const HOP_LADDER := "h2_ladder"
const NO_RECOLLECTION := "no-recollection"

var recipe := {}
var documents := {}
var provider: Dictionary
var probe: KakyuMesRouteProbe


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 4:
		_fail("usage: -- <ELFIMAGE dir> <recipe.json> <out dir> <report.json>")
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

	var room := str(recipe.room_entry)
	var members: Array = [room]
	for ladder in recipe.ladders:
		members.append(str(ladder.entry))
	for support in recipe.support_members:
		members.append(str(support))
	for ladder in recipe.ladders:
		for nested in ladder.get("nested_members", []):
			if not members.has(str(nested)):
				members.append(str(nested))
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

	var report := {"room": room, "archive_sha256": str(recipe.archive_sha256), "ladders": []}
	var failed := false
	DirAccess.make_dir_recursive_absolute(out_dir)
	for ladder in recipe.ladders:
		if only != "" and str(ladder.entry) != only:
			continue
		var measured := _measure_ladder(ladder)
		(report.ladders as Array).append(measured.report)
		if not measured.get("ok", false):
			print("LADDER_FAILED ", ladder.entry, " ", measured.get("error", ""))
			failed = true
			continue
		var file := FileAccess.open(out_dir.path_join("%s_spec.json" % str(ladder.route_id).replace("-", "_")), FileAccess.WRITE)
		file.store_string(JSON.stringify(measured.spec, "  "))
		file.close()
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


## The route's baseline, in the order the audit and the flow runner apply it:
## the room's ambient cells, the seeded selection (the picker id and the
## answer), then every gate flag of the ladder set to 1 (cell order).
func _baseline(ladder: Dictionary) -> Array:
	var writes := []
	for ambient in recipe.ambient:
		writes.append(_write(str(ambient.storage), int(ambient.index), int(ambient.value)))
	writes.append(_write(str(recipe.id_cell[0]), int(recipe.id_cell[1]), int(ladder.id)))
	writes.append(_write(str(recipe.answer_cell[0]), int(recipe.answer_cell[1]), int(recipe.answer_value)))
	for cell in ladder.gate_cells:
		writes.append(_write("global_u8", int(cell), 1))
	return writes


func _terminal_text(run: Dictionary) -> String:
	var run_terminal: Dictionary = run.get("terminal", {})
	return "%s@%d" % [str(run_terminal.get("status", "")), int(run_terminal.get("offset", -1))]


## Both hops from `baseline` plus `variant_writes`. Returns `{ok, error,
## hop1, hop2}`; `hop2` is the ladder's own run.
func _run_chain(ladder: Dictionary, baseline: Array, variant_writes: Array) -> Dictionary:
	var room := str(recipe.room_entry)
	var target := str(ladder.entry)
	var state := State.new(1)
	if not state.load_values(baseline).get("ok", false) or not state.load_values(variant_writes).get("ok", false):
		return {"ok": false, "error": "the seeded state did not load"}
	var hop1 := probe.run_route(provider, {
		"entry": room, "start_coordinate": int(recipe.origin.offset), "choices": [], "map_locations": [], "poll_supplies": [],
		"stop_before_dispatch": {"entry": room, "offset": int(ladder.dispatch_offset), "end": int(ladder.dispatch_end), "target": target},
	}, {}, state)
	var detail: Dictionary = hop1.get("stop_detail", {})
	if str(detail.get("status", "")) != "analysis_dispatch_stop":
		return {"ok": false, "error": "%s did not reach the %s call: %s" % [room, target, hop1.get("error", hop1.get("stop", ""))]}
	if (hop1.messages as Array).size() != 0:
		return {"ok": false, "error": "%s: hop 1 played %d messages, expected 0" % [room, (hop1.messages as Array).size()]}
	var hop2 := probe.run_route(provider, {
		"entry": target, "start_coordinate": 0, "choices": [], "map_locations": [], "poll_supplies": [],
		"segment_budget": int(recipe.segment_budget),
	}, {}, hop1.state_object.duplicate_state())
	return {"ok": true, "hop1": hop1, "hop2": hop2}


func _measure_ladder(ladder: Dictionary) -> Dictionary:
	var room := str(recipe.room_entry)
	var target := str(ladder.entry)
	var baseline := _baseline(ladder)
	var report := {"id": int(ladder.id), "entry": target, "route_id": str(ladder.route_id), "gates": (ladder.gates as Array).size(),
		"gate_cells": (ladder.gate_cells as Array).size()}

	var chain := _run_chain(ladder, baseline, [])
	if not chain.ok:
		return {"ok": false, "error": "%s: %s" % [target, chain.error], "report": report}
	var hop2: Dictionary = chain.hop2
	if str(hop2.get("stop", "")) != "":
		return {"ok": false, "error": "%s did not return: %s" % [target, hop2.get("stop", "")], "report": report}
	var terminal: Dictionary = hop2.terminal
	if str(terminal.get("status", "")) != "script_return":
		return {"ok": false, "error": "%s ended in %s, not a script_return" % [target, terminal.get("status", "")], "report": report}
	var is_return_record := false
	for record in ladder.returns:
		if int(record) == int(terminal.offset):
			is_return_record = true
	if not is_return_record:
		return {"ok": false, "error": "%s returned at %d, which is not one of its return records %s" % [target, int(terminal.offset), str(ladder.returns)], "report": report}
	var messages: int = (hop2.messages as Array).size()
	var default_terminal := _terminal_text(hop2)
	report["default"] = {"messages": messages, "segments": (hop2.segments as Array).size(), "terminal": default_terminal}

	# Every gate the drafter named must be evaluated on the full recollection's
	# path, and taken: a gate the run never reaches is not on the main path.
	var seen := {}
	for row in hop2.get("trace", []):
		if str(row.get("op", "")) == "branch_if_not_true":
			seen[int(row.source_offset)] = int(row.condition_value)
	var not_evaluated := []
	var not_taken := []
	for gate in ladder.gates:
		if not seen.has(int(gate.offset)):
			not_evaluated.append(int(gate.offset))
		elif seen[int(gate.offset)] != 1:
			not_taken.append(int(gate.offset))
	report["gates_not_evaluated"] = not_evaluated
	report["gates_not_taken"] = not_taken
	if not not_evaluated.is_empty() or not not_taken.is_empty():
		return {"ok": false, "error": "%s: gates not evaluated %s, not taken %s under the full recollection" % [target, str(not_evaluated), str(not_taken)], "report": report}

	# The second variant: every gate cell 0.
	var zero_writes := []
	for cell in ladder.gate_cells:
		zero_writes.append(_write("global_u8", int(cell), 0))
	var none_chain := _run_chain(ladder, baseline, zero_writes)
	if not none_chain.ok:
		return {"ok": false, "error": "%s (%s): %s" % [target, NO_RECOLLECTION, none_chain.error], "report": report}
	var none_run: Dictionary = none_chain.hop2
	var none_measured := {"stop": str(none_run.get("stop", "")), "messages": (none_run.messages as Array).size(),
		"terminal": _terminal_text(none_run)}
	report[NO_RECOLLECTION] = {"messages": none_measured.messages, "segments": (none_run.segments as Array).size(),
		"terminal": none_measured.terminal, "stop": none_measured.stop}
	var seen_none := {}
	for row in none_run.get("trace", []):
		if str(row.get("op", "")) == "branch_if_not_true":
			seen_none[int(row.source_offset)] = int(row.condition_value)
	var none_taken := 0
	for gate in ladder.gates:
		if seen_none.get(int(gate.offset), 0) == 1:
			none_taken += 1
	report[NO_RECOLLECTION]["gates_taken"] = none_taken

	var assembled := MenuVariants.assemble(HOP_LADDER, [], messages, default_terminal, [], {}, [{
		"variant_id": NO_RECOLLECTION, "label": "no recollection (every gate flag of the ladder 0)",
		"cells": ladder.gate_cells, "value": 0, "stop": none_measured.stop, "messages": none_measured.messages,
		"terminal": none_measured.terminal}])
	report["not_declared"] = assembled.not_declared
	var unresolved := _unresolved(ladder)
	unresolved.append_array(MenuVariants.unresolved_lines(assembled.not_declared))

	var spec_members := [room, target]
	for support in recipe.support_members:
		spec_members.append(str(support))
	for nested in ladder.get("nested_members", []):
		spec_members.append(str(nested))
	var other_id := (int(ladder.id) % 13) + 1
	var spec := {
		"group_id": str(ladder.group_id),
		"route_id": str(ladder.route_id),
		"source_members": spec_members,
		"state_context": {"kind": "fresh"},
		"origin": {"entry": room, "offset": int(recipe.origin.offset), "guard_offset": int(ladder.guard_offset),
			"guard_end": int(ladder.guard_end), "false_target": int(ladder.false_target)},
		"guard_cases": [
			{"case_id": "accepted", "expected": 1, "writes": []},
			{"case_id": "rejected", "expected": 0, "writes": [_write(str(recipe.id_cell[0]), int(recipe.id_cell[1]), other_id)]},
		],
		"baseline": baseline,
		"choice_contracts": [],
		"hops": [
			{"hop_id": HOP_ROOM, "entry": room, "answers": [], "gates": [], "message_count": 0,
				"outcome_offset": int(ladder.dispatch_offset), "outcome_status": "script_dispatch_boundary", "outcome_target": target},
			{"hop_id": HOP_LADDER, "entry": target, "entered_by_kind": "nested_call", "answers": [], "gates": [],
				"message_count": messages, "segment_budget": int(recipe.segment_budget),
				"outcome_offset": int(terminal.offset), "outcome_status": "script_return"},
		],
		"unresolved": unresolved,
	}
	if not (assembled.variants as Array).is_empty():
		spec["variants"] = assembled.variants
	return {"ok": true, "spec": spec, "report": report}


## The route's `unresolved` lines: the tool decisions of the seeded room and
## the branch cells the full recollection leaves alone.
func _unresolved(ladder: Dictionary) -> Array:
	var excluded: Dictionary = ladder.excluded
	var lines := [
		"The room-action menu's selection (the routine-40 question at %d, answer %d) is a shape the choice-contract tool cannot name, and the picked girl's id is the native secondary selection's result, which %s never writes: state_u16[13] = %d (the picker id) and state_u16[21] = %d are seeded state, a tool decision." % [
			int(recipe.question.offset), int(recipe.answer_value), str(recipe.room_entry), int(ladder.id), int(recipe.answer_value)],
		"The room's evening ambient cells (state_u16[19] = %d, state_u16[8] = %d, global_u8[2573] = %d) are tool decisions; the origin is the clock save at %d, after the answer-%d test." % [
			int(recipe.ambient[0].value), int(recipe.ambient[1].value), int(recipe.ambient[2].value), int(recipe.origin.offset), int(recipe.answer_value)],
		"The ladder's %d gate flags (%d cells) are set by ordinary events; the default variant sets every one (the full recollection), no-recollection none. Per-segment combinations are not walked." % [
			(ladder.gates as Array).size(), (ladder.gate_cells as Array).size()],
		"Branch cells left at their ambient value 0: selector cells %s, flag tests inside conditional arms %s, guard-only cells %s, presentation cells %s." % [
			str(excluded.selector_cells), str(excluded.flag_tests_inside_arms), str(excluded.guard_only_cells), str(excluded.presentation_cells)],
	]
	return lines
