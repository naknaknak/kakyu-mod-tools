extends "res://tools/content_suite/cli_script.gd"

## EP-12 gallery (2026-10-04): measure one album menu's `SCENE_*` flows and
## write the `tools/build_event_flow_profile.py` spec files, one per scene,
## plus a measurement report. Driven by `tools/draft_menu_flow_specs.py`'s
## recipe (the archive's own bytecode offsets, found statically); this tool
## supplies the seeded state and the answers.
##
## A route is two hops, both run through the shared call frame
## (`content_core/mes_route_probe.gd`), one fresh `probe.run_route` call each,
## exactly as `tools/content_suite/event_flow_runner.gd` will run them later:
##
##   hop 1  the menu, from the route's origin (the page test of an ordinary
##          scene, the slot test of an H scene) to the scene's nested-call
##          record, with the selection seeded
##   hop 2  the scene, entered by that nested call, to its own `script_return`
##
## The menu selection is a seeded state, not a choice: the menu's own
## selection record (command `0x15`) cannot run in the tools, so
## `state_u16[18]` (the A6 record id of the slot) and `global_u8[20]` (the
## page) are written as the route's baseline, beside the ambient cells a
## gallery visit starts from and the scene's unlock flag. That convention is
## a tool decision (`docs/spec/mes/gallery_families.md`, "Declared").
##
## A scene with its own routine-40 question is answered with its first option
## (`result_value` 1) at each question, in order; each question's choice
## contract is built from the live stop, as `measure_date_flow.gd` does. That
## is the route's default path. Since the EP-12 all-menus unit (2026-10-04) the
## measurer also **declares what the scene can otherwise do** as route variants
## (`docs/spec/tech/content_tools.md`, "Variant `answers` and
## `message_counts`"): every other answered combination of the scene's
## questions that ends at the route's own terminal (a two-question scene: each
## combination), and a recap scene's second path (its four cells all 2) with
## its own message count. A path that ends elsewhere or does not return stays
## in the route's `unresolved` list and the report (the stop rule). The rules
## that assemble the variants are `menu_flow_variants.gd`'s.
##
##   godot --headless --path . --script res://tools/content_suite/cli/measure_menu_flow.gd \
##       -- "<ELFIMAGE dir>" analysis/_undoc/ep12_j_menu_recipe.json analysis/_undoc/ep12j_menu_specs analysis/_undoc/ep12_j_menu_report.json

const Probe := preload("res://content_core/mes_route_probe.gd")
const State := preload("res://content_core/mes_sandbox_state.gd")
const ContainerScript := preload("res://content_core/mes_container.gd")
const ChoiceContractScript := preload("res://content_core/mes_routine40_choice_contract.gd")
const MenuVariants := preload("res://tools/content_suite/menu_flow_variants.gd")

const MAX_QUESTIONS := 4
## A scene whose questions multiply past this many paths is not measured
## silently: the measurer stops and names it.
const MAX_LEAVES := 64

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

	var menu := str(recipe.menu_entry)
	var members: Array = [menu]
	for scene in recipe.scenes:
		members.append(str(scene.scene))
	for support in recipe.support_members:
		members.append(str(support))
	# The helper entries a scene nests (the `*_PIC.MES` standing-picture
	# scripts, found statically by the drafter) are loaded too and are source
	# members of that scene's flow.
	for scene in recipe.scenes:
		for nested in scene.get("nested_members", []):
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

	var report := {"menu": menu, "archive_sha256": str(recipe.archive_sha256), "routes": []}
	var failed := false
	DirAccess.make_dir_recursive_absolute(out_dir)
	for scene in recipe.scenes:
		var measured := _measure_scene(scene, members)
		(report.routes as Array).append(measured.report)
		if not measured.get("ok", false):
			print("ROUTE_FAILED ", scene.scene, " ", measured.get("error", ""))
			failed = true
			continue
		var file := FileAccess.open(out_dir.path_join("%s_spec.json" % str(scene.route_id).replace("-", "_")), FileAccess.WRITE)
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


## The route's baseline in the order the audit and the flow runner apply it:
## the ambient cells, the page (ordinary scenes), the selected slot, and the
## scene's unlock flag.
func _baseline(scene: Dictionary) -> Array:
	var writes := []
	for ambient in recipe.ambient:
		writes.append(_write(str(ambient.storage), int(ambient.index), int(ambient.value)))
	if scene.page != null:
		writes.append(_write(str(recipe.page_cell[0]), int(recipe.page_cell[1]), int(scene.page)))
	writes.append(_write(str(recipe.slot_cell[0]), int(recipe.slot_cell[1]), int(scene.slot)))
	writes.append(_write("global_u8", int(scene.flag), 1))
	# A recap scene reads the state cells its heroine's DATE5 path writes 1 to
	# and her hotel path writes 2 to; the default route is the DATE5 path
	# (all 1), the hotel path (all 2) is the route's `hotel-path` variant.
	for cell in scene.recap_cells:
		writes.append(_write("global_u8", int(cell), 1))
	return writes


func _measure_scene(scene: Dictionary, members: Array) -> Dictionary:
	var menu := str(recipe.menu_entry)
	var target := str(scene.scene)
	var dispatch_offset := int(scene.dispatch_offset)
	var dispatch_end := int(scene.dispatch_end)
	var baseline := _baseline(scene)
	var report := {"scene": target, "route_id": str(scene.route_id)}

	var state := State.new(1)
	if not state.load_values(baseline).get("ok", false):
		return {"ok": false, "error": "baseline did not load", "report": report}
	# Hop 1: the menu, origin to the scene's nested-call record.
	var hop1 := probe.run_route(provider, {
		"entry": menu, "start_coordinate": int(scene.origin_offset), "choices": [], "map_locations": [], "poll_supplies": [],
		"stop_before_dispatch": {"entry": menu, "offset": dispatch_offset, "end": dispatch_end, "target": target},
	}, {}, state)
	var detail: Dictionary = hop1.get("stop_detail", {})
	if str(detail.get("status", "")) != "analysis_dispatch_stop":
		return {"ok": false, "error": "%s: the menu did not reach the %s dispatch: %s" % [menu, target, hop1.get("error", hop1.get("stop", ""))], "report": report}
	var hop1_messages: int = (hop1.messages as Array).size()
	if hop1_messages != 0:
		return {"ok": false, "error": "%s: hop 1 played %d messages, expected 0" % [menu, hop1_messages], "report": report}
	state = hop1.state_object

	# Hop 2: the scene from its own start, first option at every question.
	var contracts := []
	var choices := []
	var answers := []
	var hop2 := {}
	for _attempt in range(MAX_QUESTIONS + 1):
		hop2 = probe.run_route(provider, {
			"entry": target, "start_coordinate": 0, "choices": choices, "map_locations": [], "poll_supplies": [],
		}, {}, state.duplicate_state())
		var stop_detail: Dictionary = hop2.get("stop_detail", {})
		if str(stop_detail.get("kind", "")) != "unanswered_choice":
			break
		if str(stop_detail.get("entry", "")) != target:
			return {"ok": false, "error": "%s: a question outside the scene stopped the run" % target, "report": report}
		var live_code: PackedByteArray = documents[target].bytecode
		var contract: Dictionary = ChoiceContractScript.new().build(live_code, int(stop_detail.get("code_size", live_code.size())),
			stop_detail.result, stop_detail.get("source_identity", {"entry": target, "archive": "mes.arc"}))
		if not contract.get("ok", false):
			return {"ok": false, "error": "%s: the question contract did not build" % target, "report": report}
		var boundary := int(contract.boundary_offset)
		contracts.append(contract)
		choices.append({"owner_entry": target, "boundary_offset": boundary, "options": [{"result_value": 1}]})
		answers.append({"boundary_offset": boundary, "result_value": 1})
	if str(hop2.get("stop", "")) != "":
		return {"ok": false, "error": "%s did not return: %s" % [target, hop2.get("stop", "")], "report": report}
	var terminal: Dictionary = hop2.terminal
	if str(terminal.get("status", "")) != "script_return":
		return {"ok": false, "error": "%s ended in %s, not a script_return" % [target, terminal.get("status", "")], "report": report}
	var questions: Array = scene.questions
	if answers.size() != questions.size():
		return {"ok": false, "error": "%s: %d questions answered, the recipe names %d" % [target, answers.size(), questions.size()], "report": report}
	var hop2_messages: int = (hop2.messages as Array).size()
	report["hop2_messages"] = hop2_messages
	report["terminal"] = {"offset": int(terminal.offset), "status": str(terminal.status)}
	report["answers"] = answers

	var default_terminal := "%s@%d" % [str(terminal.status), int(terminal.offset)]
	var explored := _explore(target, state, contracts)
	if str(explored.get("error", "")) != "":
		return {"ok": false, "error": "%s: %s" % [target, explored.error], "report": report}
	var leaves: Array = explored.leaves
	# The default path is one of the walk's own leaves: it must be the path the
	# default run took, or the contract discovery and the default run disagree.
	if not contracts.is_empty():
		var default_leaf_found := false
		for leaf in leaves:
			if _answers_equal(leaf.answers, answers):
				default_leaf_found = true
				if int(leaf.messages) != hop2_messages or str(leaf.terminal) != default_terminal:
					return {"ok": false, "error": "%s: the answer walk's default path disagrees with the default run" % target, "report": report}
		if not default_leaf_found:
			return {"ok": false, "error": "%s: the answer walk never reached the default path" % target, "report": report}
	var recap_alt := _recap_second_path(scene, state, target, choices)
	var assembled := MenuVariants.assemble("h2_scene", answers, hop2_messages, default_terminal, leaves, recap_alt)
	# A question that exists only on a variant's path needs its own contract in
	# the route; contracts the declared variants do not use are not added.
	var found: Dictionary = explored.contracts
	var known_boundaries := []
	for contract in contracts:
		known_boundaries.append(int((contract as Dictionary).boundary_offset))
	for variant in assembled.variants:
		for variant_answer in (variant as Dictionary).get("answers", []):
			var boundary := int(variant_answer.boundary_offset)
			if not known_boundaries.has(boundary):
				contracts.append(found[boundary])
				known_boundaries.append(boundary)
	var variant_ids := []
	for variant in assembled.variants:
		variant_ids.append(str((variant as Dictionary).variant_id))
	report["answer_paths"] = leaves.size()
	report["variants"] = maxi(variant_ids.size() - 1, 0)
	report["variant_ids"] = variant_ids
	report["not_declared"] = assembled.not_declared
	report["variant_only_questions"] = assembled.variant_only_questions
	report["skipped_questions"] = assembled.skipped_questions
	report["alternatives"] = _alternatives_report(leaves, answers, recap_alt, assembled)
	var unresolved := [
		"The menu's own selection (command 0x15, state_u16[18]) cannot run: the slot and the page are seeded state, a tool decision.",
	]
	unresolved.append_array(MenuVariants.unresolved_lines(assembled.not_declared))

	var spec_members := [menu, target]
	for support in recipe.support_members:
		spec_members.append(str(support))
	for nested in scene.get("nested_members", []):
		spec_members.append(str(nested))
	var flag := int(scene.flag)
	var spec := {
		"group_id": str(recipe.group_id),
		"route_id": str(scene.route_id),
		"source_members": spec_members,
		"state_context": {"kind": "fresh"},
		"origin": {"entry": menu, "offset": int(scene.origin_offset), "guard_offset": int(scene.guard_offset),
			"guard_end": int(scene.guard_end), "false_target": int(scene.false_target)},
		"guard_cases": [
			{"case_id": "accepted", "expected": 1, "writes": []},
			{"case_id": "rejected", "expected": 0, "writes": [_write("global_u8", flag, 0)]},
		],
		"baseline": baseline,
		"choice_contracts": contracts,
		"hops": [
			{"hop_id": "h1_menu_dispatch", "entry": menu, "answers": [], "gates": [], "message_count": 0,
				"outcome_offset": dispatch_offset, "outcome_status": "script_dispatch_boundary", "outcome_target": target},
			{"hop_id": "h2_scene", "entry": target, "entered_by_kind": "nested_call", "answers": answers, "gates": [],
				"message_count": hop2_messages, "outcome_offset": int(terminal.offset), "outcome_status": "script_return"},
		],
		"unresolved": unresolved,
	}
	if not (assembled.variants as Array).is_empty():
		spec["variants"] = assembled.variants
	return {"ok": true, "spec": spec, "report": report}


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


func _terminal_text(run: Dictionary) -> String:
	var run_terminal: Dictionary = run.get("terminal", {})
	return "%s@%d" % [str(run_terminal.get("status", "")), int(run_terminal.get("offset", -1))]


func _build_contract(target: String, stop_detail: Dictionary) -> Dictionary:
	var live_code: PackedByteArray = documents[target].bytecode
	var contract: Dictionary = ChoiceContractScript.new().build(live_code, int(stop_detail.get("code_size", live_code.size())),
		stop_detail.result, stop_detail.get("source_identity", {"entry": target, "archive": "mes.arc"}))
	return contract if contract.get("ok", false) else {}


## Every answered path of the scene's questions, depth first and in option
## order: at each question the walk answers each of its options in turn and
## runs on, so a question that exists only after another answer is found too.
## `known` are the contracts the default run already built; the walk adds the
## ones it meets. Returns `{error, leaves: [{answers, stop, messages,
## terminal}], contracts: {boundary: contract}}`.
func _explore(target: String, state: KakyuMesSandboxState, known: Array) -> Dictionary:
	var found := {}
	for contract in known:
		found[int((contract as Dictionary).boundary_offset)] = contract
	var leaves := []
	if known.is_empty():
		return {"error": "", "leaves": leaves, "contracts": found}
	var error := _walk(target, state, [], found, leaves)
	return {"error": error, "leaves": leaves, "contracts": found}


func _walk(target: String, state: KakyuMesSandboxState, prefix: Array, found: Dictionary, leaves: Array) -> String:
	var choices := []
	for untyped_answer in prefix:
		var answer: Dictionary = untyped_answer
		choices.append({"owner_entry": target, "boundary_offset": int(answer.boundary_offset), "options": [{"result_value": int(answer.result_value)}]})
	var run := probe.run_route(provider, {"entry": target, "start_coordinate": 0, "choices": choices,
		"map_locations": [], "poll_supplies": []}, {}, state.duplicate_state())
	var stop_detail: Dictionary = run.get("stop_detail", {})
	if str(stop_detail.get("kind", "")) == "unanswered_choice" and str(stop_detail.get("entry", "")) == target:
		if prefix.size() >= MAX_QUESTIONS:
			return "more than %d questions on one path" % MAX_QUESTIONS
		var contract := _build_contract(target, stop_detail)
		if contract.is_empty():
			return "a question on an alternative path did not build a contract"
		var boundary := int(contract.boundary_offset)
		if not found.has(boundary):
			found[boundary] = contract
		for value in range(1, int(contract.get("definition_count", 1)) + 1):
			var next := prefix.duplicate(true)
			next.append({"boundary_offset": boundary, "result_value": value})
			var error := _walk(target, state, next, found, leaves)
			if error != "":
				return error
		return ""
	if leaves.size() >= MAX_LEAVES:
		return "more than %d answer paths" % MAX_LEAVES
	leaves.append({"answers": prefix, "stop": str(run.get("stop", "")), "messages": (run.messages as Array).size(),
		"terminal": _terminal_text(run)})
	return ""


## A recap scene's second path: its four cells all 2, the default answers.
func _recap_second_path(scene: Dictionary, state: KakyuMesSandboxState, target: String, choices: Array) -> Dictionary:
	if (scene.recap_cells as Array).is_empty():
		return {}
	var second: KakyuMesSandboxState = state.duplicate_state()
	for cell in scene.recap_cells:
		second.write_value("global_u8", int(cell), 2)
	var run := probe.run_route(provider, {"entry": target, "start_coordinate": 0, "choices": choices,
		"map_locations": [], "poll_supplies": []}, {}, second)
	return {"cells": scene.recap_cells, "stop": str(run.get("stop", "")), "messages": (run.messages as Array).size(),
		"terminal": _terminal_text(run)}


## The report's account of every measured path other than the default.
func _alternatives_report(leaves: Array, default_answers: Array, recap_alt: Dictionary, assembled: Dictionary) -> Array:
	var declared_ids := {}
	for variant in assembled.variants:
		declared_ids[str((variant as Dictionary).variant_id)] = true
	var out := []
	for leaf in leaves:
		if _answers_equal(leaf.answers, default_answers):
			continue
		var id := MenuVariants.variant_id(leaf.answers)
		out.append({"kind": "answers", "variant_id": id, "answers": leaf.answers, "stop": str(leaf.stop),
			"messages": int(leaf.messages), "terminal": str(leaf.terminal), "declared": declared_ids.has(id)})
	if not recap_alt.is_empty():
		out.append({"kind": "recap_path_2", "variant_id": "hotel-path", "cells": recap_alt.cells, "stop": str(recap_alt.stop),
			"messages": int(recap_alt.messages), "terminal": str(recap_alt.terminal), "declared": declared_ids.has("hotel-path")})
	return out
