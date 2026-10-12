extends Node

const Probe := preload("res://content_core/mes_route_probe.gd")
const State := preload("res://content_core/mes_sandbox_state.gd")
const FlowRunner := preload("res://tools/content_suite/event_flow_runner.gd")
const LibraryIndex := preload("res://content_core/mes_library_index.gd")
const SyntheticArc := preload("res://tests/synthetic_arc.gd")
const MesRecordGrammar := preload("res://tests/mes_record_grammar.gd")
var failed := false


func _ready() -> void:
	# Authored DEF 11 -> DEF 12 -> caller. The inner write must happen before
	# the outer suffix, and temporary contexts must return with the callee.
	var outer := PackedByteArray([0x11,2,12,0xFF,0, 0x03,5,0,9,0xFF,0, 0])
	var inner := PackedByteArray([0x03,5,0,3,0xFF,0, 0x09,33,0,7,0xFF,0, 0])
	var provider := {"definitions": {11: _definition(outer), 12: _definition(inner)}}
	var state := State.new(1)
	var run := {"state": state, "rows": []}
	var context := {"argument_slots": {2:4}, "persistent_expression_stack": [19]}
	var probe := Probe.new()
	var result: Dictionary = probe.call("_run_definition", provider, run, {"definition_id":11}, context)
	_check(result.get("ok", false) and state.read_value("global_u8",5) == 9, "nested definition returns to the exact outer suffix")
	_check(result.get("argument_slots") == {33:7,2:4} and result.get("persistent_expression_stack") == [19], "nested argument and expression contexts return intact")
	_check(context.argument_slots == {2:4} and int(run.definition_calls) == 2, "input context remains owned by caller and both calls are counted")
	var writes: Array = run.rows.filter(func(row: Dictionary) -> bool: return row.effect == "global_u8_write_run")
	_check(writes.size() == 2 and writes[0].entry == "DEF_MAIN.MES:12" and writes[1].entry == "DEF_MAIN.MES:11", "trace keeps nested execution order")
	provider.definitions.erase(12)
	run = {"state": State.new(1), "rows": []}
	result = probe.call("_run_definition", provider, run, {"definition_id":11}, context)
	_check(not result.get("ok", true) and result.error == "definition 12 is not registered" and run.state.read_value("global_u8",5) == 0, "missing nested definition never executes outer suffix")
	provider.definitions[11] = _definition(PackedByteArray([0x11,2,11,0xFF,0, 0]))
	run = {"state": State.new(1), "rows": []}
	result = probe.call("_run_definition", provider, run, {"definition_id":11}, context)
	_check(not result.get("ok", true) and result.error == "registered definition call limit exceeded" and run.definition_calls == 8, "recursive definitions stop at the tool depth limit")
	run = {"state": State.new(1), "rows": [], "definition_calls":128}
	result = probe.call("_run_definition", provider, run, {"definition_id":11}, context)
	_check(not result.get("ok", true) and run.rows.is_empty(), "total call limit applies before execution")
	provider.definitions[11] = _definition(PackedByteArray([0x0C,0,0,0,0]))
	run = {"state": State.new(1), "rows": []}
	result = probe.call("_run_definition", provider, run, {"definition_id":11}, context)
	_check(not result.get("ok", true) and result.get("status") == "definition_step_limit" and result.get("offset") == 0 and result.get("entry") == "DEF_MAIN.MES", "non-returning definition preserves the exact unresolved coordinate")
	_check_provenance_budget()
	_check_carried_runtime_state()
	_check_nested_script_terminals()
	_check_specific_dispatch_stop()
	_check_root_replacement()
	_check_loop_detection()
	_check_map_locations()
	_check_poll_supplies()
	_check_flow_runner_segment_budget()
	_check_library_invoked_definition_rows()
	_check_library_media_from_route_call()
	_check_library_media_from_definition_call()
	_check_library_media_loop_truncation()
	_check_library_media_through_flow_runner()
	_check_library_media_always_present()
	get_tree().quit(1 if failed else 0)


func _definition(code: PackedByteArray) -> Dictionary:
	return {"code":code,"body_offset":0,"end_offset":code.size(),"source_entry":"DEF_MAIN.MES"}


func _check_provenance_budget() -> void:
	var raw := PackedByteArray([0x1F,1,0,0,0, 0x17,0,0,0,0, 0x03,5,0,3,0xFF,0, 0x0C,10,0,0,0])
	var stripped := PackedByteArray([0x03,5,0,3,0xFF,0, 0x0C,0,0,0,0])
	var caller := preload("res://content_core/mes_registered_definition_call.gd").new()
	var raw_state := State.new(1)
	var raw_run: Dictionary = caller.run(1, _definition(raw), raw_state, {"exclude_provenance_steps":true}, 2)
	var stripped_state := State.new(1)
	var stripped_run: Dictionary = caller.run(1, _definition(stripped), stripped_state, {"exclude_provenance_steps":true}, 2)
	_check(raw_run.status == "definition_step_limit" and stripped_run.status == raw_run.status
		and raw_state.to_records() == stripped_state.to_records() and raw_state.read_value("global_u8",5) == 3,
		"bounded state is equal when a package omits provenance: %s/%s %s/%s" % [raw_run.status,stripped_run.status,raw_state.to_records(),stripped_state.to_records()])
	var default_state := State.new(1)
	caller.run(1, _definition(raw), default_state, {}, 2)
	_check(default_state.to_records().is_empty(), "ordinary runner keeps its existing record-count limit")


func _check_carried_runtime_state() -> void:
	var seed := State.new(7)
	seed.set_native_relative_u8_aliases_enabled(true)
	seed.set_native_banked_u16_zero_baseline(0x24A0)
	seed.write_relative_u8_block(0x24A0, PackedByteArray([6,15]))
	seed.write_value("state_u16",25,0x24A0)
	# Read the runtime-only relative byte through bank 25, then return.
	var code := PackedByteArray([0x03,5,0, 1,0xC0,25,0xFF,0, 0])
	var provider := {"entries":{"QA.MES":{"code":code,"code_size":code.size(),"address_table":[],"source":null}}}
	var probe := Probe.new()
	var route := {"entry":"QA.MES","start_coordinate":0}
	var result := probe.run_route(provider,route,{},seed)
	_check(result.stop.is_empty() and result.state_object.read_value("global_u8",5) == 15,
		"route continuation retains runtime-only relative backing and aliases")
	_check(result.state_object != seed and seed.read_value("global_u8",5) == 0
		and result.state_object.read_value("banked_u16",0,0) == 0x24A0,
		"route clones the seed and its native word baseline without mutating the caller")
	result.state_object.write_value("relative_u8",0x24A0+1,4)
	_check(seed.read_value("banked_u8",1,25) == 15,"continued state cannot mutate seed backing")
	var fresh := probe.run_route(provider,route)
	_check(fresh.state_object.read_value("global_u8",5) == 0
		and not fresh.state_object.native_relative_u8_aliases_enabled(),"ordinary route calls still start fresh")
	var invalid := probe.run_route(provider,route,{"writes":[{"storage":"invalid","bank":0,"index":0,"value":1}]},seed)
	_check(not invalid.ok and seed.read_value("banked_u8",1,25) == 15,"rejected preset preserves caller state")


func _check_nested_script_terminals() -> void:
	var probe := Probe.new()
	var caller := _script_transition(0x0F, "CHILD.MES")
	caller.append_array(PackedByteArray([0x03,5,0,9,0xFF,0, 0]))
	var handoff := _script_transition(0x0E, "NEXT.MES")
	# The replacement target is deliberately present. The probe must report
	# the boundary without running either that target or a suspended suffix.
	var provider := {"entries":{
		"CALLER.MES":_script_binding(caller),
		"CHILD.MES":_script_binding(handoff),
		"NEXT.MES":_script_binding(PackedByteArray([0x03,7,0,6,0xFF,0, 0])),
	}}
	var route := {"entry":"CALLER.MES", "start_coordinate":0}
	var direct := probe.run_route(provider, route)
	_check(direct.stop.is_empty() and direct.terminal == {"entry":"CHILD.MES", "status":"script_handoff_boundary",
		"offset":0,"end":handoff.size(),"target":"NEXT.MES"}, "nested handoff preserves the exact callee terminal")
	_check(direct.state_object.read_value("global_u8",5) == 0 and direct.state_object.read_value("global_u8",7) == 0
		and direct.rows.size() == 2, "nested handoff executes neither caller suffix nor replacement target")
	var middle := _script_transition(0x0F, "LEAF.MES")
	middle.append_array(PackedByteArray([0x03,6,0,4,0xFF,0, 0]))
	provider.entries["CHILD.MES"] = _script_binding(middle)
	provider.entries["LEAF.MES"] = _script_binding(handoff)
	var transitive := probe.run_route(provider, route)
	_check(transitive.stop.is_empty() and transitive.terminal == {"entry":"LEAF.MES", "status":"script_handoff_boundary",
		"offset":0,"end":handoff.size(),"target":"NEXT.MES"}, "handoff propagates through every suspended caller")
	_check(transitive.state_object.to_records().is_empty() and transitive.rows.size() == 3,
		"transitive handoff never executes either pending suffix or the replacement target")
	provider.entries["LEAF.MES"] = _script_binding(PackedByteArray([0]))
	var returned := probe.run_route(provider, route)
	_check(returned.stop.is_empty() and returned.terminal == {"entry":"CALLER.MES", "status":"script_return",
		"offset":caller.size()-1,"end":caller.size(),"target":""}, "ordinary nested returns still reach the root return")
	_check(returned.state_object.read_value("global_u8",5) == 9 and returned.state_object.read_value("global_u8",6) == 4
		and returned.state_object.read_value("global_u8",7) == 0 and returned.rows.size() == 7,
		"ordinary nested returns execute both suffixes in call order")


func _check_specific_dispatch_stop() -> void:
	var probe := Probe.new()
	var call := _script_transition(0x0F, "CHILD.MES")
	var caller := call.duplicate()
	caller.append_array(PackedByteArray([0x03,6,0,1,0xFF,0]))
	var second := caller.size()
	caller.append_array(call)
	caller.append_array(PackedByteArray([0x03,7,0,1,0xFF,0,0]))
	var child := PackedByteArray([0x03,5,0,0xF3,5,0,1,0xE0,0xFF,0,0])
	var provider := {"entries":{"CALLER.MES":_script_binding(caller),"CHILD.MES":_script_binding(child)}}
	var descriptor := {"entry":"CALLER.MES","start_coordinate":0,"stop_before_dispatch":{
		"entry":"CALLER.MES","offset":second,"end":second+call.size(),"target":"CHILD.MES"}}
	var seed := State.new(1)
	var prefix := probe.run_route(provider,descriptor,{},seed)
	_check(prefix.stop_detail.get("status") == "analysis_dispatch_stop" and prefix.terminal.is_empty()
		and prefix.stop_detail.offset == second and prefix.stop_detail.end == second+call.size(),
		"analysis stop binds the later caller coordinate without inventing a terminal")
	_check(prefix.state_object.read_value("global_u8",5) == 1 and prefix.state_object.read_value("global_u8",6) == 1
		and prefix.state_object.read_value("global_u8",7) == 0 and seed.to_records().is_empty(),
		"earlier call executes, selected child and suffix do not, and input state remains unchanged")
	var selected := probe.run_route(provider,{"entry":"CHILD.MES","start_coordinate":0},{},prefix.state_object)
	var suffix := probe.run_route(provider,{"entry":"CALLER.MES","start_coordinate":second+call.size()},{},selected.state_object)
	var whole := probe.run_route(provider,{"entry":"CALLER.MES","start_coordinate":0},{},seed)
	_check(whole.stop.is_empty() and whole.state_object.read_value("global_u8",5) == 2
		and whole.state_object.snapshot() == suffix.state_object.snapshot()
		and whole.rows == prefix.rows+selected.rows+suffix.rows,
		"specific dispatch segmentation preserves both repeated calls and the unbroken trace")
	for field in ["end","target"]:
		var wrong: Dictionary = descriptor.duplicate(true)
		wrong.stop_before_dispatch[field] = second+call.size()+1 if field == "end" else "OTHER.MES"
		var rejected := probe.run_route(provider,wrong)
		_check(rejected.stop_detail.get("status") == "analysis_dispatch_mismatch"
			and rejected.state_object.read_value("global_u8",5) == 1 and rejected.terminal.is_empty(),
			"changed dispatch %s stops before child execution" % field)
	var other: Dictionary = descriptor.duplicate(true)
	other.stop_before_dispatch.entry = "OTHER.MES"
	var unmatched := probe.run_route(provider,other)
	_check(unmatched.stop.is_empty() and unmatched.rows == whole.rows,
		"matching offset in a different owner does not trigger a dispatch stop")


func _check_root_replacement() -> void:
	var probe := Probe.new()
	var activation := _script_transition(0x0E, "TARGET.MES")
	var caller := PackedByteArray([0x03,5,0,3,0xFF,0])
	caller.append_array(activation)
	caller.append_array(PackedByteArray([0x03,6,0,9,0xFF,0,0]))
	var target := PackedByteArray([0x03,7,0,0xF3,5,0,0xFF,0,0])
	var provider := {"entries":{"CALLER.MES":_script_binding(caller),"TARGET.MES":_script_binding(target)}}
	var descriptor := {"entry":"CALLER.MES","start_coordinate":0,"follow_root_handoff":{
		"entry":"CALLER.MES","offset":6,"end":6+activation.size(),"target":"TARGET.MES"}}
	var seed := State.new(1)
	var whole := probe.run_route(provider,descriptor,{},seed)
	_check(whole.stop.is_empty() and whole.terminal == {"entry":"TARGET.MES","status":"script_return",
		"offset":target.size()-1,"end":target.size(),"target":""}, "followed replacement owns the root return")
	_check(whole.state_object.read_value("global_u8",7) == 3 and whole.state_object.read_value("global_u8",6) == 0
		and seed.to_records().is_empty(), "replacement carries state without executing old suffix or mutating seed")
	var prefix := probe.run_route(provider,{"entry":"CALLER.MES","start_coordinate":0},{},seed)
	var selected := probe.run_route(provider,{"entry":"TARGET.MES","start_coordinate":0},{},prefix.state_object)
	_check(prefix.terminal.entry == "CALLER.MES" and prefix.terminal.status == "script_handoff_boundary"
		and whole.rows == prefix.rows+selected.rows and whole.state_object.snapshot() == selected.state_object.snapshot(),
		"default root boundary and segmented replacement preserve the exact unbroken trace")
	for field in ["end","target"]:
		var wrong: Dictionary = descriptor.duplicate(true)
		wrong.follow_root_handoff[field] = 7+activation.size() if field == "end" else "OTHER.MES"
		var rejected := probe.run_route(provider,wrong)
		_check(rejected.stop_detail.get("status") == "analysis_handoff_mismatch"
			and rejected.state_object.read_value("global_u8",7) == 0 and rejected.rows == prefix.rows,
			"changed replacement %s stops before target execution" % field)
	var other: Dictionary = descriptor.duplicate(true)
	other.follow_root_handoff.entry = "OTHER.MES"
	var unmatched := probe.run_route(provider,other)
	_check(unmatched.stop.is_empty() and unmatched.rows == prefix.rows,
		"replacement coordinate belongs to its declared owner")
	provider.entries.erase("TARGET.MES")
	var missing := probe.run_route(provider,descriptor)
	_check(missing.stop == "root entry TARGET.MES is not a package member" and missing.rows == prefix.rows,
		"unprovided replacement target preserves the exact caller boundary")
	provider.entries["TARGET.MES"] = _script_binding(_script_transition(0x0E,"NEXT.MES"))
	provider.entries["NEXT.MES"] = _script_binding(PackedByteArray([0x03,8,0,1,0xFF,0,0]))
	var handed := probe.run_route(provider,descriptor)
	_check(handed.stop.is_empty() and handed.terminal.entry == "TARGET.MES" and handed.terminal.target == "NEXT.MES"
		and handed.state_object.read_value("global_u8",8) == 0, "replacement stops at its own next handoff")
	# Reenter the activating owner. The single explicit follow must be consumed.
	provider.entries["TARGET.MES"] = _script_binding(_script_transition(0x0F,"CALLER.MES"))
	var repeated := probe.run_route(provider,descriptor)
	_check(repeated.stop.is_empty() and repeated.terminal.entry == "CALLER.MES" and repeated.rows.size() == 5,
		"revisited activation cannot recursively follow the same root replacement")
	provider.entries["TARGET.MES"] = _script_binding(target)
	var ancestor := _script_transition(0x0F,"CALLER.MES")
	ancestor.append_array(PackedByteArray([0x03,9,0,1,0xFF,0,0]))
	provider.entries["ANCESTOR.MES"] = _script_binding(ancestor)
	var nested: Dictionary = descriptor.duplicate(true)
	nested.entry = "ANCESTOR.MES"
	var transitive := probe.run_route(provider,nested)
	_check(transitive.stop.is_empty() and transitive.terminal == whole.terminal
		and transitive.state_object.read_value("global_u8",9) == 0 and transitive.state_object.read_value("global_u8",6) == 0,
		"replacement root return never resumes any suspended ancestor")
	var carrying := PackedByteArray([0x0A,0xFF,1,2,0xFF,0])
	carrying.append_array(activation)
	provider.entries["CALLER.MES"] = _script_binding(carrying)
	provider.entries["TARGET.MES"] = _script_binding(PackedByteArray([0x05,0xFF,3,0xFF,0,0]))
	var isolated := probe.run_route(provider,descriptor)
	_check(isolated.stop.is_empty() and isolated.state_object.read_value("global_u8",0) == 3
		and isolated.state_object.read_value("global_u8",1) == 0,
		"replacement creates a fresh expression context instead of inheriting the old root carry")


func _check_loop_detection() -> void:
	var probe := Probe.new()
	# A write, a message, its wait and a jump back to the message: the
	# continuation at the wait repeats with the same state, so the walk is a
	# proven loop whose head is the wait record and whose period is one.
	var looping := PackedByteArray([0x03,5,0,1,0xFF,0, 0x01,0x41,0x00, 0x0D,0x13,0xFF,0x02,0x02,0xFF,0x00, 0x0C,6,0,0,0])
	var provider := {"entries":{"LOOP.MES":_script_binding(looping)}}
	var capped := probe.run_route(provider, {"entry":"LOOP.MES","start_coordinate":0})
	_check(capped.stop == "segment limit reached in LOOP.MES" and capped.terminal.is_empty() and capped.messages.size() == 512,
		"without the request a loop spends the segment budget")
	# EP-12 H (2026-10-04): a descriptor may name its own segment budget. The
	# default stays 512; a larger one is spent the same way, to the same phrase.
	var budgeted := probe.run_route(provider, {"entry":"LOOP.MES","start_coordinate":0,"segment_budget":600})
	_check(budgeted.stop == "segment limit reached in LOOP.MES" and budgeted.terminal.is_empty() and budgeted.messages.size() == 600,
		"a segment_budget of 600 spends 600 segments before the same stop: %d messages" % budgeted.messages.size())
	var whole_number := probe.run_route(provider, {"entry":"LOOP.MES","start_coordinate":0,"segment_budget":600.0})
	_check(whole_number.stop == "segment limit reached in LOOP.MES" and whole_number.messages.size() == 600,
		"a whole-number float budget (what JSON gives) is the same budget")
	for refused in [0, -1, 1.5, "600", true]:
		var invalid := probe.run_route(provider, {"entry":"LOOP.MES","start_coordinate":0,"segment_budget":refused})
		_check(not invalid.ok and invalid.error == "invalid segment budget" and not invalid.has("messages"),
			"segment budget %s is refused" % str(refused))
	var proven :=probe.run_route(provider, {"entry":"LOOP.MES","start_coordinate":0,"detect_loops":true})
	_check(proven.stop.is_empty() and proven.terminal == {"entry":"LOOP.MES","status":"loop_boundary","offset":9,"end":16,
		"target":"","period":1,"period_message_count":1,"cycle":[{"entry":"LOOP.MES","offset":9,"status":"dialogue_boundary"}]},
		"a repeated continuation is reported as the loop head with its cycle: %s" % str(proven.terminal))
	_check(proven.messages.size() == 1 and proven.segments.size() == 1 and proven.rows.size() == 4
		and proven.state_object.read_value("global_u8",5) == 1, "the observation is the walk up to the loop head: messages %d segments %d rows %d" % [proven.messages.size(), proven.segments.size(), proven.rows.size()])
	var again := probe.run_route(provider, {"entry":"LOOP.MES","start_coordinate":0,"detect_loops":true})
	_check(again.rows == proven.rows and again.signature == proven.signature, "a proven loop is observed identically each time")
	# A counter makes every continuation new: nothing is proven and the
	# budget is spent as before.
	var counting := PackedByteArray([0x01,0x41,0x00, 0x0D,0x13,0xFF,0x02,0x02,0xFF,0x00, 0x04,7,0x80,7,1,0xE0,0xFF,0x00, 0x0C,0,0,0,0])
	provider.entries["LOOP.MES"] = _script_binding(counting)
	var counted := probe.run_route(provider, {"entry":"LOOP.MES","start_coordinate":0,"detect_loops":true})
	_check(counted.stop == "segment limit reached in LOOP.MES" and counted.terminal.is_empty()
		and counted.state_object.read_value("state_u16",7) == 511, "a continuation whose state keeps changing is not a proven loop")
	# A loop inside a nested script ends the caller's walk too, without
	# executing the caller's suffix.
	provider.entries["LOOP.MES"] = _script_binding(looping)
	var caller := _script_transition(0x0F, "LOOP.MES")
	caller.append_array(PackedByteArray([0x03,6,0,9,0xFF,0, 0]))
	provider.entries["CALLER.MES"] = _script_binding(caller)
	var nested := probe.run_route(provider, {"entry":"CALLER.MES","start_coordinate":0,"detect_loops":true})
	_check(nested.stop.is_empty() and nested.terminal.get("entry") == "LOOP.MES" and nested.terminal.get("status") == "loop_boundary"
		and nested.state_object.read_value("global_u8",6) == 0, "a proven nested loop stops every suspended caller")


func _check_map_locations() -> void:
	var probe := Probe.new()
	# The train's shape: poll the location, copy it to state_u16[23], leave
	# when it is 1, otherwise poll again. Nothing inside the loop is a
	# boundary record, so only a supplied location can end it.
	var looping := MesRecordGrammar.map_location_poll()
	looping.append_array(PackedByteArray([0x04,0x17,0x80,0x12,0xFF,0x00,
		0x0B,0x80,0x17,0x01,0xEF,0xFF,0,0,0,0, 0x00]))
	var provider := {"entries":{"MAP.MES":_script_binding(looping)}}
	var contract := {"entry":"MAP.MES","poll_offset":0,"values":[5, 1]}
	var reached := probe.run_route(provider, {"entry":"MAP.MES","start_coordinate":0,"map_locations":[contract]})
	var supplied: Array = reached.trace.filter(func(row: Dictionary) -> bool: return row.effect == "map_location_supplied")
	_check(reached.stop.is_empty() and reached.terminal == {"entry":"MAP.MES","status":"script_return","offset":24,"end":25,"target":""}
		and supplied.size() == 2 and int(supplied[0].map_location_value) == 5 and int(supplied[1].map_location_value) == 1
		and reached.state_object.read_value("state_u16",23) == 1 and int(reached.map_locations_remaining) == 0
		and (contract.values as Array) == [5, 1],
		"declared locations lead the walk out of a map loop and the request's own queue is untouched")
	var unsupplied := probe.run_route(provider, {"entry":"MAP.MES","start_coordinate":0})
	_check(unsupplied.stop.begins_with("step_limit") and unsupplied.terminal.is_empty(),
		"without a contract the map loop spends the step budget")
	var short := probe.run_route(provider, {"entry":"MAP.MES","start_coordinate":0,"map_locations":[{"entry":"MAP.MES","poll_offset":0,"values":[5]}]})
	_check(short.stop.begins_with("step_limit") and int(short.map_locations_remaining) == 0,
		"a queue that ends before the loop leaves keeps the walk bounded and reports nothing left")
	# The queue serves a nested frame, and the caller's suffix runs afterwards.
	var caller := _script_transition(0x0F, "MAP.MES")
	caller.append_array(PackedByteArray([0x03,6,0,9,0xFF,0, 0]))
	provider.entries["CALLER.MES"] = _script_binding(caller)
	var nested := probe.run_route(provider, {"entry":"CALLER.MES","start_coordinate":0,"map_locations":[contract]})
	_check(nested.stop.is_empty() and nested.terminal.get("entry") == "CALLER.MES" and nested.terminal.get("status") == "script_return"
		and nested.state_object.read_value("global_u8",6) == 9 and int(nested.map_locations_remaining) == 0,
		"a nested map loop is served by the same queue and the caller resumes")


func _check_poll_supplies() -> void:
	# Definition 17's own wait shape (docs/spec/mes/a_date_flow.md): one
	# `branch_if_not_true (state_u16[9] equal 0)` whose false edge jumps back
	# to itself, so nothing but a supplied cell value can ever end it - no
	# native_record_dispatch (command 0x12) sits in this minimal loop, so this
	# proves the branch's own seam is independent of `_supplied_map_location`.
	var waiting := PackedByteArray([0x0B,0x80,9,0,0xEF,0xFF, 0,0,0,0, 0x00])
	var provider := {"definitions": {17: _definition(waiting)}}
	var probe := Probe.new()

	var unsupplied_state := State.new(1)
	unsupplied_state.write_value("state_u16", 9, 5)
	var unsupplied_run := {"state": unsupplied_state, "rows": []}
	var unsupplied: Dictionary = probe.call("_run_definition", provider, unsupplied_run, {"definition_id":17}, {"argument_slots":{}, "persistent_expression_stack":[]})
	_check(not unsupplied.get("ok", true) and unsupplied.get("status") == "definition_step_limit" and unsupplied_state.read_value("state_u16",9) == 5,
		"without a poll supply the branch loops on its own unsatisfied condition")

	var wrong_index_state := State.new(1)
	wrong_index_state.write_value("state_u16", 9, 5)
	var wrong_index_run := {"state": wrong_index_state, "rows": [],
		"poll_supplies": [{"definition":17, "poll_offset":0, "result_storage":"state_u16", "result_index":8, "value":0}]}
	var wrong_index: Dictionary = probe.call("_run_definition", provider, wrong_index_run, {"definition_id":17}, {"argument_slots":{}, "persistent_expression_stack":[]})
	_check(not wrong_index.get("ok", true) and wrong_index.get("status") == "definition_step_limit",
		"a poll supply naming a different cell does not satisfy this branch")

	var supplied_state := State.new(1)
	supplied_state.write_value("state_u16", 9, 5)
	var supplied_run := {"state": supplied_state, "rows": [],
		"poll_supplies": [{"definition":17, "poll_offset":0, "result_storage":"state_u16", "result_index":9, "value":0}]}
	var supplied: Dictionary = probe.call("_run_definition", provider, supplied_run, {"definition_id":17}, {"argument_slots":{}, "persistent_expression_stack":[]})
	_check(supplied.get("ok", false) and supplied_state.read_value("state_u16",9) == 0,
		"a matching poll supply writes its own value before the branch evaluates and the definition returns")
	var supplied_rows: Array = supplied_run.rows.filter(func(row: Dictionary) -> bool: return row.get("op","") == "branch_if_not_true")
	_check(supplied_rows.size() == 1, "the branch is reached exactly once once its own poll is satisfied")

	# End to end through `run_route`'s own `definition_invoke` boundary: the
	# same descriptor field a hop's own request carries.
	var caller := PackedByteArray([0x11,2,17,0xFF,0, 0x03,6,0,9,0xFF,0, 0])
	var route_provider := {"entries": {"CALLER.MES": _script_binding(caller)},
		"definitions": {17: _definition(waiting)}}
	var seed := State.new(1)
	seed.write_value("state_u16", 9, 5)
	var without_supply := probe.run_route(route_provider, {"entry":"CALLER.MES","start_coordinate":0}, {}, seed)
	_check(without_supply.stop.begins_with("definition 17 stopped at definition_step_limit"),
		"a route with no poll supply reports the exact stopped definition")
	var with_supply := probe.run_route(route_provider, {"entry":"CALLER.MES","start_coordinate":0,
		"poll_supplies":[{"definition":17,"poll_offset":0,"result_storage":"state_u16","result_index":9,"value":0}]}, {}, seed)
	_check(with_supply.stop.is_empty() and with_supply.terminal.get("status") == "script_return"
		and with_supply.state_object.read_value("state_u16",9) == 0 and with_supply.state_object.read_value("global_u8",6) == 9,
		"a route's own poll supply resolves the wait and the caller suffix still runs")


func _script_transition(command: int, target: String) -> PackedByteArray:
	var code := PackedByteArray([command,1])
	code.append_array(target.to_ascii_buffer())
	code.append_array(PackedByteArray([0,0]))
	return code


func _script_binding(code: PackedByteArray) -> Dictionary:
	return {"code":code,"code_size":code.size(),"address_table":[],"source":null}


func _check(ok: bool, label: String) -> void:
	if not ok:
		failed = true
		push_error(label)
	else:
		print("PASS: ", label)


## EP-12 H (2026-10-04): the flow runner forwards a hop's own `segment_budget`
## to the probe and only that hop's. A script that plays 600 messages needs more
## than the default 512 segments: a hop without a budget stops at the limit, the
## same hop with 1024 returns.
func _check_flow_runner_segment_budget() -> void:
	var long_code := PackedByteArray()
	for _index in range(600):
		long_code.append_array(PackedByteArray([0x01,0x41,0x00, 0x0D,0x13,0xFF,0x02,0x02,0xFF,0x00]))
	long_code.append(0)
	var provider := {"entries": {"LONG.MES": _script_binding(long_code)}}
	var route := {"origin": {"entry": "LONG.MES", "offset": 0}, "baseline": [], "hops": [
		{"hop_id": "plain", "entry": "LONG.MES", "expected": {"outcome": {"status": "script_return"}}}]}
	var variant := {"variant_id": "default", "writes": []}
	var plain := FlowRunner.run_route(Probe.new(), provider, {}, route, variant, {})
	_check(plain.stop == "segment limit reached in LONG.MES" and plain.messages.size() == 512 and plain.terminal.is_empty(),
		"a hop without segment_budget keeps the default 512: %d messages, stop '%s'" % [plain.messages.size(), plain.stop])
	route.hops[0]["segment_budget"] = 1024
	var budgeted := FlowRunner.run_route(Probe.new(), provider, {}, route, variant, {})
	_check(budgeted.stop.is_empty() and budgeted.messages.size() == 600 and str(budgeted.terminal.get("status", "")) == "script_return",
		"a hop with segment_budget 1024 runs its 600 messages to the return: stop '%s'" % budgeted.stop)
	route.hops[0]["segment_budget"] = 1024.0
	var from_json := FlowRunner.run_route(Probe.new(), provider, {}, route, variant, {})
	_check(from_json.stop.is_empty() and from_json.messages.size() == 600, "a whole-number float (JSON) budget is forwarded as is")


## TD-55 (Core 0.377.0): a registered definition a library routine invokes runs through the
## library runner, which appends the definition's own rows (DEF-relative offsets, the id in
## `external_definition_id`) to the library trace. The probe keys them by their own entry,
## like a definition the route invoked itself, not `LIBLARY.LIB:<routine>`, and its
## `definition` field carries the id the rows actually bear.
func _check_library_invoked_definition_rows() -> void:
	var def_code := PackedByteArray([0x12, 0x41, 0x00, 0x00])
	var library := PackedByteArray()
	SyntheticArc.append_registration(library, 25, PackedByteArray([
		0x03, 0x08, 0x00, 0x03, 0xFF, 0x00,
		0x11, 0x02, 0x1A, 0xFF, 0x00,
		0x03, 0x09, 0x00, 0x04, 0xFF, 0x00,
		0x00,
	]))
	library.append(0x00)
	var caller := PackedByteArray([0x1D, 0x02, 0x19, 0xFF, 0x00, 0x00])
	var provider := {
		"entries": {"QA.MES": _script_binding(caller)},
		"library_code": library, "library_source": null,
		"library_index": LibraryIndex.new().build(library),
		"definitions": {26: _definition(def_code)},
	}
	var result: Dictionary = Probe.new().run_route(provider, {"entry": "QA.MES", "start_coordinate": 0}, {}, State.new(1))
	_check(result.stop.is_empty() and result.state_object.read_value("global_u8", 9) == 4, "the route with a library-invoked definition runs to its return: '%s'" % result.stop)
	var rows: Array = result.rows
	var library_rows: Array = rows.filter(func(row: Dictionary) -> bool: return str(row.entry) == "LIBLARY.LIB:25")
	var definition_rows: Array = rows.filter(func(row: Dictionary) -> bool: return str(row.entry) == "DEF_MAIN.MES:26")
	var mislabelled: Array = rows.filter(func(row: Dictionary) -> bool: return str(row.entry).begins_with("LIBLARY.LIB") and int(row.definition) != -1)
	_check(
		definition_rows.size() == 2
		and definition_rows.map(func(row: Dictionary) -> String: return str(row.effect)) == ["native_record_effects_omitted", "script_return"]
		and definition_rows.all(func(row: Dictionary) -> bool: return int(row.definition) == 26)
		and mislabelled.is_empty(),
		"a definition invoked from a library routine is keyed DEF_MAIN.MES:<id> with its own id: %s" % str(rows.map(func(row: Dictionary) -> String: return "%s@%d" % [row.entry, row.at]))
	)
	# The library's own rows keep their LIBLARY.LIB key and offsets, including the invoke row.
	_check(
		library_rows.map(func(row: Dictionary) -> String: return str(row.effect)).has("definition_invoke_boundary")
		and library_rows.all(func(row: Dictionary) -> bool: return int(row.definition) == -1)
		and library_rows.size() + definition_rows.size() == rows.filter(func(row: Dictionary) -> bool: return str(row.entry) != "QA.MES").size(),
		"the library's own rows stay LIBLARY.LIB:<routine> with no definition id"
	)
	# Replay v3's attribution consumes these keys: the definition's offsets are DEF members, not library ones.
	var media := preload("res://tools/content_suite/replay_run_media.gd").summarize(result)
	_check(
		media.ok and int(media.definition_invokes) == 1 and int(media.definition_rows) == 2
		and media.executed.has("DEF_MAIN.MES") and media.executed.has("LIBLARY.LIB"),
		"replay media attribution accepts the self-keyed definition rows: %s" % str(media)
	)


## EP-14 (Core 0.378.0): the library routine the `library_media` checks call. Routine 25
## writes the active surface (`banked_u16[0][1] = 2`), loads one MMO through the
## presentation-9 marker and issues one sound-effect request - the shape of the real
## routine 27 and routine 9 in one body. Library offsets: the registration header is 7
## bytes, so the surface write is 7..14, the marker 14..29, the request 29..54 and the
## routine return 54..55.
func _media_library() -> PackedByteArray:
	var body := PackedByteArray([0x07, 1, 0xFF, 0, 2, 0xFF, 0])
	body.append_array(PackedByteArray([0x0D, 0x09, 0xFF, 0x01]) + "SYN_1.MMO".to_ascii_buffer() + PackedByteArray([0, 0]))
	body.append_array(PackedByteArray([0x0D, 6, 0xFF, 2, 0, 0xFF, 1]) + "SYN_HIT.WAV".to_ascii_buffer()
		+ PackedByteArray([0, 2, 0xF6, 2, 0, 0xFF, 0]))
	body.append(0x00)
	var library := PackedByteArray()
	SyntheticArc.append_registration(library, 25, body)
	library.append(0x00)
	return library


func _media_provider(entries: Dictionary, definitions: Dictionary = {}) -> Dictionary:
	var library := _media_library()
	return {
		"entries": entries, "library_code": library, "library_source": null,
		"library_index": LibraryIndex.new().build(library), "definitions": definitions,
	}


## One signature row, written out: the fields `_signature_row` produces, and `definition`
## for a library-collected row.
func _sig(entry: String, at: int, end: int, op: String, effect: String, resource: String, routine: int, write: String, definition = null) -> Dictionary:
	var row := {"entry": entry, "at": at, "end": end, "op": op, "effect": effect, "resource": resource, "routine": routine, "write": write}
	if definition != null:
		row["definition"] = definition
	return row


func _library_signature_rows() -> Array:
	return [
		_sig("LIBLARY.LIB:25", 7, 14, "banked_u16_write_run", "banked_u16_write_run", "", -1, "banked_u16:1:1", -1),
		_sig("LIBLARY.LIB:25", 14, 29, "mmo_resource_marker", "mmo_resource_marker", "SYN_1.MMO", -1, ":-1:-1", -1),
		_sig("LIBLARY.LIB:25", 29, 54, "effect_request", "effect_request", "SYN_HIT.WAV", -1, ":-1:-1", -1),
		_sig("LIBLARY.LIB:25", 54, 55, "command_00", "script_return", "", -1, ":-1:-1", -1),
	]


## A route calls the routine: its media travel in `library_media`, anchored to the route
## `shared_routine_boundary` row, and `trace`, `rows` and `signature` are what they were.
func _check_library_media_from_route_call() -> void:
	# global_u8[5] = 1 (0..6), the shared call to routine 25 (6..11), the return (11..12).
	var caller := PackedByteArray([0x03, 5, 0, 1, 0xFF, 0, 0x1D, 0x02, 0x19, 0xFF, 0x00, 0x00])
	var provider := _media_provider({"QA.MES": _script_binding(caller)})
	var result: Dictionary = Probe.new().run_route(provider, {"entry": "QA.MES", "start_coordinate": 0}, {}, State.new(1))
	_check(result.stop.is_empty() and result.terminal.get("status") == "script_return", "the media route runs to its return: '%s'" % result.stop)
	var trace: Array = result.trace
	_check(
		trace.map(func(row: Dictionary) -> String: return str(row.effect)) == ["global_u8_write_run", "shared_routine_boundary", "script_return"]
		and trace.all(func(row: Dictionary) -> bool: return str(row.source_entry) == "QA.MES"),
		"trace holds the route own rows only: no LIBLARY.LIB row",
	)
	var media: Array = result.library_media
	_check(
		media.map(func(row: Dictionary) -> String: return str(row.effect)) == ["mmo_resource_marker", "effect_request"],
		"library_media is exactly the marker row and then the effect row, in call order: %s" % str(media.map(func(row: Dictionary) -> String: return str(row.effect))),
	)
	var call := {"routine": 25, "caller_entry": "QA.MES", "caller_offset": 6, "caller_definition_id": -1}
	_check(
		str(media[0].source_entry) == "LIBLARY.LIB" and int(media[0].source_offset) == 14 and str(media[0].resource_name) == "SYN_1.MMO"
		and int(media[0].native_active_surface_value) == 2 and not media[0].has("step")
		and media[0].library_call == call and int(media[0].trace_index) == 1 and int(media[0].library_routine_id) == 25,
		"the marker row keeps its library offset and surface value, drops the library step counter, and names the caller record: %s" % str(media[0].get("library_call")),
	)
	_check(
		str(media[1].source_entry) == "LIBLARY.LIB" and int(media[1].source_offset) == 29 and str(media[1].resource_name) == "SYN_HIT.WAV"
		and str(media[1].resource_archive) == "se.arc" and not media[1].has("step")
		and media[1].library_call == call and int(media[1].trace_index) == 1,
		"the effect row keeps its library offset and archive, and names the same caller record",
	)
	_check(
		str((trace[int(media[0].trace_index)] as Dictionary).effect) == "shared_routine_boundary"
		and int((trace[1] as Dictionary).source_offset) == int(call.caller_offset),
		"trace_index is the route shared_routine_boundary row, whose offset is the caller coordinate",
	)
	var expected_rows: Array = [
		_sig("QA.MES", 0, 6, "global_u8_write_run", "global_u8_write_run", "", -1, "global_u8:5:1"),
		_sig("QA.MES", 6, 11, "script_transfer", "shared_routine_boundary", "", 25, ":-1:-1"),
	]
	expected_rows.append_array(_library_signature_rows())
	expected_rows.append(_sig("QA.MES", 11, 12, "command_00", "script_return", "", -1, ":-1:-1"))
	_check(
		result.rows == expected_rows and result.signature == JSON.stringify(expected_rows).sha256_text(),
		"rows and signature are the expected rows, library rows included, written out explicitly",
	)


## A registered definition the route invoked calls the routine: the caller is the
## definition own shared-call record (DEF-relative), and the anchor is the route
## definition_invoke_boundary row.
func _check_library_media_from_definition_call() -> void:
	# The definition: global_u8[6] = 1 (0..6), the shared call (6..11), its return (11..12).
	var definition_code := PackedByteArray([0x03, 6, 0, 1, 0xFF, 0, 0x1D, 0x02, 0x19, 0xFF, 0x00, 0x00])
	var caller := PackedByteArray([0x03, 5, 0, 1, 0xFF, 0, 0x11, 2, 26, 0xFF, 0, 0x00])
	var provider := _media_provider({"QA.MES": _script_binding(caller)}, {26: _definition(definition_code)})
	var result: Dictionary = Probe.new().run_route(provider, {"entry": "QA.MES", "start_coordinate": 0}, {}, State.new(1))
	_check(result.stop.is_empty() and result.terminal.get("status") == "script_return", "the route with a definition that calls the routine runs to its return: '%s'" % result.stop)
	var media: Array = result.library_media
	var call := {"routine": 25, "caller_entry": "DEF_MAIN.MES", "caller_offset": 6, "caller_definition_id": 26}
	_check(
		media.size() == 2 and media.all(func(row: Dictionary) -> bool: return row.library_call == call and str(row.source_entry) == "LIBLARY.LIB")
		and media.map(func(row: Dictionary) -> int: return int(row.source_offset)) == [14, 29],
		"the media name the definition shared-call record (DEF-relative offset, definition id) as their caller: %s" % str(media.map(func(row: Dictionary) -> Variant: return row.get("library_call"))),
	)
	var invoke_index := int(media[0].trace_index)
	_check(
		media.all(func(row: Dictionary) -> bool: return int(row.trace_index) == invoke_index)
		and str((result.trace[invoke_index] as Dictionary).effect) == "definition_invoke_boundary"
		and result.trace.all(func(row: Dictionary) -> bool: return str(row.source_entry) == "QA.MES"),
		"trace_index is the route definition_invoke_boundary row, and trace still holds no library or definition row",
	)
	var library_rows: Array = result.rows.filter(func(row: Dictionary) -> bool: return str(row.entry) == "LIBLARY.LIB:25")
	_check(library_rows == _library_signature_rows(), "the library signature rows are those of the route call")


## The loop head segment ends at the shared call: when the proven loop drops the head
## signature rows it drops the head media with them, and `library_media` is what the mark
## recorded.
func _check_library_media_loop_truncation() -> void:
	# The shared call (0..5), then a jump back to 0 (5..10).
	var looping := PackedByteArray([0x1D, 0x02, 0x19, 0xFF, 0x00, 0x0C, 0, 0, 0, 0])
	var provider := _media_provider({"LOOP.MES": _script_binding(looping)})
	var spent: Dictionary = Probe.new().run_route(provider, {"entry": "LOOP.MES", "start_coordinate": 0, "segment_budget": 2})
	_check(
		spent.stop == "segment limit reached in LOOP.MES" and spent.library_media.size() == 4,
		"without loop detection each of the two calls adds its two media rows: %d" % spent.library_media.size(),
	)
	var proven: Dictionary = Probe.new().run_route(provider, {"entry": "LOOP.MES", "start_coordinate": 0, "detect_loops": true})
	_check(proven.stop.is_empty() and str(proven.terminal.get("status")) == "loop_boundary", "the repeated shared call is a proven loop: %s" % str(proven.terminal))
	var kept_media: Array = proven.rows.filter(func(row: Dictionary) -> bool:
		return str(row.entry).begins_with("LIBLARY.LIB") and Probe.MEDIA_EFFECTS.has(str(row.effect)))
	_check(
		proven.library_media.size() == 2 and kept_media.size() == proven.library_media.size()
		and proven.library_media.map(func(row: Dictionary) -> int: return int(row.source_offset)) == kept_media.map(func(row: Dictionary) -> int: return int(row.at)),
		"the head library media are dropped with its signature rows: %d media, %d media rows" % [proven.library_media.size(), kept_media.size()],
	)
	var anchored := true
	for row in proven.library_media:
		var index := int(row.trace_index)
		anchored = anchored and index < proven.trace.size() and str((proven.trace[index] as Dictionary).effect) == "shared_routine_boundary"
	_check(anchored, "every kept medium is still anchored at a shared_routine_boundary row of the truncated trace")
	var again: Dictionary = Probe.new().run_route(provider, {"entry": "LOOP.MES", "start_coordinate": 0, "detect_loops": true})
	_check(again.library_media == proven.library_media, "a proven loop reports the same media each time")


## Two v14 hops that each call the routine: the flow runner indexes the combined trace, and
## each hop report own run keeps its hop-local indices (the rows were copied before the offset).
func _check_library_media_through_flow_runner() -> void:
	var first := PackedByteArray([0x1D, 0x02, 0x19, 0xFF, 0x00, 0x00])
	var second := PackedByteArray([0x03, 6, 0, 1, 0xFF, 0, 0x1D, 0x02, 0x19, 0xFF, 0x00, 0x00])
	var provider := _media_provider({"QA.MES": _script_binding(first), "QB.MES": _script_binding(second)})
	var route := {"origin": {"entry": "QA.MES", "offset": 0}, "baseline": [], "hops": [
		{"hop_id": "a", "entry": "QA.MES", "expected": {"outcome": {"status": "script_return"}}},
		{"hop_id": "b", "entry": "QB.MES", "expected": {"outcome": {"status": "script_return"}}},
	]}
	var result := FlowRunner.run_route(Probe.new(), provider, {}, route, {"variant_id": "default", "writes": []}, {})
	_check(result.ok and result.stop.is_empty() and result.hops.size() == 2, "the two-hop media flow runs: '%s'" % result.stop)
	var first_run: Dictionary = result.hops[0].run
	var second_run: Dictionary = result.hops[1].run
	_check(first_run.trace.size() == 2 and second_run.trace.size() == 3, "the hops own traces are two and three rows")
	var media: Array = result.library_media
	_check(
		media.size() == 4 and media.map(func(row: Dictionary) -> int: return int(row.trace_index)) == [0, 0, 3, 3]
		and media.map(func(row: Dictionary) -> String: return str(row.library_call.caller_entry)) == ["QA.MES", "QA.MES", "QB.MES", "QB.MES"]
		and media.map(func(row: Dictionary) -> int: return int(row.library_call.caller_offset)) == [0, 0, 6, 6],
		"the second hop indices are offset by the first hop trace length: %s" % str(media.map(func(row: Dictionary) -> int: return int(row.trace_index))),
	)
	_check(
		media.all(func(row: Dictionary) -> bool: return str((result.trace[int(row.trace_index)] as Dictionary).effect) == "shared_routine_boundary"),
		"every combined index points at a shared_routine_boundary row of the combined trace",
	)
	_check(
		first_run.library_media.map(func(row: Dictionary) -> int: return int(row.trace_index)) == [0, 0]
		and second_run.library_media.map(func(row: Dictionary) -> int: return int(row.trace_index)) == [1, 1],
		"each hop report own run keeps hop-local indices: the rows were copied before they were offset",
	)


## Every ok `run_route` result carries the list, `[]` with no library call; a library call with
## no anchor row is refused before the routine runs.
func _check_library_media_always_present() -> void:
	var plain := PackedByteArray([0x03, 5, 0, 1, 0xFF, 0, 0x00])
	var result: Dictionary = Probe.new().run_route({"entries": {"QA.MES": _script_binding(plain)}}, {"entry": "QA.MES", "start_coordinate": 0}, {}, State.new(1))
	_check(result.ok and result.has("library_media") and result.library_media == [], "a route with no library call has an empty library_media")
	var missing: Dictionary = Probe.new().run_route({"entries": {}}, {"entry": "QA.MES", "start_coordinate": 0}, {}, State.new(1))
	_check(missing.ok and missing.has("library_media") and missing.library_media == [] and not missing.stop.is_empty(), "a route that stops before it starts still has an empty library_media")
	var anchorless := {"trace": [], "library_media": [], "rows": []}
	var refused: Dictionary = Probe.new().call("_run_library", _media_provider({}), anchorless, 25,
		{"argument_slots": {}, "persistent_expression_stack": []}, {"caller_entry": "QA.MES", "caller_offset": 0, "caller_definition_id": -1})
	_check(
		not refused.ok and refused.error == "shared routine 25 has no anchor row" and anchorless.rows.is_empty() and anchorless.library_media.is_empty(),
		"a library call with an empty trace is refused before the routine runs: %s" % str(refused),
	)
