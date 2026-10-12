extends "res://tools/content_suite/cli_script.gd"

## EP-12 leftovers (checkpoint B): two re-entry measurements, executed against
## the original `mes.arc` and kept re-runnable (they replace two probe scripts
## that lived only in the untracked `analysis/`).
##
## Part 1 - J's two-visit hotel mechanism. Facts reproduced (`docs/spec/mes/heroine_date_flows.md`, the J entry):
##   first visit  - `J_DATE3.MES` entered at 0 under the date-flow seed with
##                  the hotel answers (Q1 case 3, Q2 case 1) writes
##                  `global_u8[867] = 0`, `[868] = 1`, `[866] = 1`, `[286] = 1`
##                  and stops at a `script_handoff_boundary` to `MACHI.MES` at
##                  offset 43769. The runner halts there, so the
##                  `continuation_transfer` record after it (43787, operand
##                  44083) is not reached in this run.
##   second visit - `J_DATE3.MES` entered directly at 43797 (address-table
##                  entry 360) with `global_u8[868] = 1` seeded runs 7 messages
##                  and hands off to `J_HOTEL.MES` at 44083; the generic chain
##                  `J_HOTEL.MES` (site selector answered 5) 39 messages ->
##                  `J_HOTEL1.MES` 57 -> `J_HOTEL2.MES` 22 -> `MACHI.MES`.
##                  7 + 39 + 57 + 22 = 125 messages across 4 hops.
## Not established (kept so): what natively selects entry 360 on the later
## invocation. J's hotel stays measured, not declared.
##
## Part 2 - the A_PROMIS.MES picker's position-1 re-ask
## (`docs/spec/mes/promise_groups.md`). Under the declared baseline of
## `01m_a_promis_v5.json` route 0 (read from the tracked profile) with the
## original calendar projection, `A_PROMIS.MES` run from 0 with no answer stops
## at the picker boundary 2221 (0x8AD) after 6 messages. Answering position 1
## there plays the place's dialogue and returns to the *same* boundary (0x8AD)
## after 21 messages; a further answer at that second occurrence cannot be
## measured because the sparse-catalog contract build refuses the hidden
## leading id ("leading gap has no supporting gate-branch landmark"), a
## pre-existing builder edge case this unit did not fix. Position 3 (the
## declared answer) continues to the time question at 11371 (0x2C6B) with no
## loop (23 messages at that boundary). Nothing is declared from position 1.
##
##   godot --headless --path . --script res://tools/content_suite/validators/validate_ep12_reentry_probes.gd -- "<ELFIMAGE dir>"

const Probe := preload("res://content_core/mes_route_probe.gd")
const State := preload("res://content_core/mes_sandbox_state.gd")
const ContainerScript := preload("res://content_core/mes_container.gd")
const Calendar := preload("res://content_core/mes_calendar_state.gd")

const MEMBERS := ["01M.MES", "A_PROMIS.MES", "J_PIC.MES", "J_DATE3.MES", "J_HOTEL.MES", "J_HOTEL1.MES", "J_HOTEL2.MES",
	"MACHI.MES", "LIBLARY.LIB", "DEF_MAIN.MES", "START.MES"]
const ARCHIVE_SHA256 := "31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6"

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_validate")


func _expect(label: String, actual, expected) -> void:
	if actual != expected:
		failures.append("%s: got %s, expected %s" % [label, str(actual), str(expected)])


func _validate() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() != 1:
		_fail("Usage: <ELFIMAGE-directory>")
		return
	var elfimage_root := ProjectSettings.globalize_path(str(arguments[0]))
	var mes_path := elfimage_root.path_join("mes.arc")
	if not FileAccess.file_exists(mes_path):
		_fail("Original mes.arc is unavailable.")
		return
	var source_hash := FileAccess.get_sha256(mes_path)
	_expect("archive sha256", source_hash, ARCHIVE_SHA256)
	var reader := preload("res://content_core/arc_reader.gd").new()
	reader.open(mes_path)
	var documents := {}
	for member in MEMBERS:
		documents[member] = ContainerScript.new().parse(reader.read_entry(member), {"entry": member, "archive": "mes.arc"})
		if not documents[member].get("ok", false):
			reader.close()
			_fail("%s did not parse" % member)
			return
	reader.close()
	var probe := Probe.new()
	var provider := probe.context_from_documents(documents)
	var calendar := Calendar.new()
	var projection := calendar.build(documents["START.MES"])

	# The date-flow seed (`tools/content_suite/cli/measure_date_flow.gd`, J's
	# recipe: promise field 235, location field 219, affection cell 211, guard
	# flags global_u8[210] = 1 / [217] = 2).
	var seed := State.new(1)
	calendar.apply_to_state(projection, seed)
	seed.write_value("state_u16", 7, 502)
	seed.write_value("state_u16", 19, 1530)
	seed.write_value("banked_u16", 235, 502)
	seed.write_value("banked_u16", 236, 900)
	seed.write_value("global_u8", 210, 1)
	seed.write_value("global_u8", 217, 2)
	seed.write_value("global_u8", 219, 15)

	# First visit: the hotel case of J_DATE3.MES.
	var first_state: KakyuMesSandboxState = seed.duplicate_state()
	first_state.write_value("banked_u16", 211, 121)
	var first := probe.run_route(provider, {"entry": "J_DATE3.MES", "start_coordinate": 0,
		"choices": [
			{"owner_entry": "J_DATE3.MES", "boundary_offset": 10667, "options": [{"result_value": 3}]},
			{"owner_entry": "J_DATE3.MES", "boundary_offset": 34558, "options": [{"result_value": 1}]}],
		"poll_supplies": [{"definition": 17, "poll_offset": 4222, "result_storage": "state_u16", "result_index": 18, "value": 0}],
		"detect_loops": true}, {}, first_state)
	_expect("first visit stop", str(first.get("stop", "")), "")
	var first_terminal: Dictionary = first.get("terminal", {})
	_expect("first visit terminal status", str(first_terminal.get("status", "")), "script_handoff_boundary")
	_expect("first visit terminal offset", int(first_terminal.get("offset", -1)), 43769)
	_expect("first visit terminal target", str(first_terminal.get("target", "")), "MACHI.MES")
	var first_state_after: KakyuMesSandboxState = first.get("state_object")
	var first_values := {}
	if first_state_after != null:
		for cell in [867, 868, 866, 286]:
			first_values[cell] = first_state_after.read_value("global_u8", cell)
	_expect("first visit global_u8[867]/[868]/[866]/[286]", first_values, {867: 0, 868: 1, 866: 1, 286: 1})
	var first_messages := (first.get("messages", []) as Array).size()

	# Second visit: entry 360 of J_DATE3.MES with [868] = 1 (tool_seeded; the
	# first visit writes it).
	var second_state: KakyuMesSandboxState = seed.duplicate_state()
	second_state.write_value("global_u8", 868, 1)
	var hops := []
	var total_messages := 0
	var second := probe.run_route(provider, {"entry": "J_DATE3.MES", "start_coordinate": 43797, "detect_loops": true}, {}, second_state)
	_expect("second visit stop", str(second.get("stop", "")), "")
	var second_terminal: Dictionary = second.get("terminal", {})
	_expect("second visit terminal status", str(second_terminal.get("status", "")), "script_handoff_boundary")
	_expect("second visit terminal offset", int(second_terminal.get("offset", -1)), 44083)
	_expect("second visit terminal target", str(second_terminal.get("target", "")), "J_HOTEL.MES")
	var second_messages := (second.get("messages", []) as Array).size()
	_expect("second visit messages", second_messages, 7)
	hops.append(second_messages)
	total_messages += second_messages
	var state: KakyuMesSandboxState = second.get("state_object")
	var chain := [
		{"entry": "J_HOTEL.MES", "messages": 39, "target": "J_HOTEL1.MES",
			"choices": [{"owner_entry": "J_HOTEL.MES", "boundary_offset": 11376, "options": [{"result_value": 5}]}]},
		{"entry": "J_HOTEL1.MES", "messages": 57, "target": "J_HOTEL2.MES", "choices": []},
		{"entry": "J_HOTEL2.MES", "messages": 22, "target": "MACHI.MES", "choices": []},
	]
	for link in chain:
		if state == null:
			break
		var descriptor := {"entry": str(link.entry), "start_coordinate": 0, "detect_loops": true}
		if not (link.choices as Array).is_empty():
			descriptor["choices"] = link.choices
		var run := probe.run_route(provider, descriptor, {}, state)
		_expect("%s stop" % link.entry, str(run.get("stop", "")), "")
		var terminal: Dictionary = run.get("terminal", {})
		_expect("%s terminal status" % link.entry, str(terminal.get("status", "")), "script_handoff_boundary")
		_expect("%s terminal target" % link.entry, str(terminal.get("target", "")), str(link.target))
		var count := (run.get("messages", []) as Array).size()
		_expect("%s messages" % link.entry, count, int(link.messages))
		hops.append(count)
		total_messages += count
		state = run.get("state_object")
	_expect("chain hops", hops.size(), 4)
	_expect("chain messages", total_messages, 125)

	# Part 2: the A_PROMIS.MES picker, position 1 and position 3.
	var profile = JSON.parse_string(FileAccess.get_file_as_string("res://config/event_catalog/analysis_groups/01m_a_promis_v5.json"))
	var baseline: Array = (profile.routes[0] as Dictionary).baseline
	var picker := {"owner_entry": "A_PROMIS.MES", "boundary_offset": 2221}
	var reask := {}
	for position in [0, 1, 3]:
		var picker_state := State.new(1)
		calendar.apply_to_state(projection, picker_state)
		picker_state.load_values(baseline)
		var descriptor := {"entry": "A_PROMIS.MES", "start_coordinate": 0, "detect_loops": true}
		if position != 0:
			descriptor["choices"] = [picker.merged({"options": [{"result_value": position}]})]
		var run := probe.run_route(provider, descriptor, {}, picker_state)
		reask[position] = {"stop": str(run.get("stop", "")), "messages": (run.get("messages", []) as Array).size(),
			"kind": str((run.get("stop_detail", {}) as Dictionary).get("kind", "")),
			"boundary": int((run.get("stop_detail", {}) as Dictionary).get("boundary_offset", -1))}
	_expect("picker unanswered kind", reask[0].kind, "unanswered_choice")
	_expect("picker unanswered boundary", reask[0].boundary, 2221)
	_expect("picker unanswered messages", reask[0].messages, 6)
	_expect("position 1 second-occurrence messages", reask[1].messages, 21)
	_expect("position 1 second-occurrence stop", reask[1].stop,
		"routine-40 contract at 0x8AD: Routine-40 sparse catalog's leading gap has no supporting gate-branch landmark.")
	_expect("position 3 next boundary", reask[3].boundary, 11371)
	_expect("position 3 messages", reask[3].messages, 23)

	if FileAccess.get_sha256(mes_path) != source_hash:
		failures.append("original mes.arc changed during the EP-12 re-entry validation")
	if not failures.is_empty():
		_fail("; ".join(failures))
		return
	print("PASS: EP-12 re-entry probes picker_position1=2221->reask@0x8AD messages=6->21 picker_position3->11371 messages=23 | J hotel two-visit mechanism first_visit=J_DATE3@0->MACHI@43769 first_messages=%d writes=867:0,868:1,866:1,286:1 second_visit=J_DATE3@43797->J_HOTEL@44083 chain_hops=%d chain_messages=%d (%s) source_unchanged=true declared=false" % [
		first_messages, hops.size(), total_messages, "+".join(hops.map(func(h): return str(h)))])
	quit(0)
