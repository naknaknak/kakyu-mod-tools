extends "res://tests/test_case.gd"

const AnalysisRunScript := preload("res://tools/content_suite/catalog_analysis_run.gd")
const FlowRunnerScript := preload("res://tools/content_suite/event_flow_runner.gd")


func _ready() -> void:
	_check_origin_from_origin_offset()
	_check_origin_from_guard_offset()
	_check_no_origin_not_ok()
	_check_selection_without_owner_defaults_to_callee()
	_check_root_handoff_follow()
	_check_menu_loop_detection()
	_check_stop_before_dispatch()
	_check_flow_selections_follow_the_variant()
	_check_flow_runner_variant_helpers()
	await get_tree().process_frame
	get_tree().quit(1 if _failed else 0)


func _base_route() -> Dictionary:
	return {
		"caller": {"entry": "CALLER.MES", "offset": 0x10, "end": 0x14},
		"callee": {"entry": "CALLEE.MES"},
		"origin_offset": 0x20,
	}


func _base_variant() -> Dictionary:
	return {"selections": []}


func _check_origin_from_origin_offset() -> void:
	var analyzer := AnalysisRunScript.new()
	var route := _base_route()
	var descriptor: Dictionary = analyzer.build_group_route_descriptor(route, _base_variant())
	_check(descriptor.get("ok", false), "a route with origin_offset builds ok")
	_check(int(descriptor.get("start_coordinate", -1)) == 0x20, "the descriptor's start_coordinate is the route's origin_offset")
	_check(str(descriptor.get("entry", "")) == "CALLER.MES", "the descriptor's entry is the caller's entry")


func _check_origin_from_guard_offset() -> void:
	var analyzer := AnalysisRunScript.new()
	var route := {
		"caller": {"entry": "CALLER.MES", "offset": 0x10, "end": 0x14},
		"callee": {"entry": "CALLEE.MES"},
		"guard": {"offset": 0x30},
	}
	var descriptor: Dictionary = analyzer.build_group_route_descriptor(route, _base_variant())
	_check(descriptor.get("ok", false), "a route with no origin_offset but a guard offset builds ok")
	_check(int(descriptor.get("start_coordinate", -1)) == 0x30, "the descriptor's start_coordinate falls back to guard.offset")


func _check_no_origin_not_ok() -> void:
	var analyzer := AnalysisRunScript.new()
	var route := {
		"caller": {"entry": "CALLER.MES", "offset": 0x10, "end": 0x14},
		"callee": {"entry": "CALLEE.MES"},
	}
	var descriptor: Dictionary = analyzer.build_group_route_descriptor(route, _base_variant())
	_check(not descriptor.get("ok", true), "a route with no origin_offset and no guard offset is not ok")
	_check(not str(descriptor.get("error", "")).is_empty(), "the not-ok descriptor carries an error message")


func _check_selection_without_owner_defaults_to_callee() -> void:
	var analyzer := AnalysisRunScript.new()
	var route := _base_route()
	var variant := {
		"selections": [
			{"boundary_offset": 0x40, "result_value": 3},
		],
	}
	var descriptor: Dictionary = analyzer.build_group_route_descriptor(route, variant)
	_check(descriptor.get("ok", false), "a route with an owner-less selection builds ok")
	var choices: Array = descriptor.get("choices", [])
	_check(choices.size() == 1, "the owner-less selection becomes one choice")
	_check(str((choices[0] as Dictionary).get("owner_entry", "")) == "CALLEE.MES", "an owner-less selection defaults to the route's callee")


func _check_root_handoff_follow() -> void:
	var analyzer := AnalysisRunScript.new()
	var route := _base_route()
	route["caller_outcome"] = {"kind": "root_handoff"}
	var descriptor: Dictionary = analyzer.build_group_route_descriptor(route, _base_variant())
	_check(descriptor.get("ok", false), "a route with a root_handoff caller outcome builds ok")
	_check(descriptor.has("follow_root_handoff"), "follow_root_handoff is set for a root_handoff caller outcome")
	var handoff: Dictionary = descriptor.get("follow_root_handoff", {})
	_check(str(handoff.get("entry", "")) == "CALLER.MES", "follow_root_handoff's entry is the caller's")
	_check(str(handoff.get("target", "")) == "CALLEE.MES", "follow_root_handoff's target is the callee's")


func _check_menu_loop_detection() -> void:
	var analyzer := AnalysisRunScript.new()
	var route := _base_route()
	route["resume"] = {"boundary_policy": "caller_menu_loop"}
	var descriptor: Dictionary = analyzer.build_group_route_descriptor(route, _base_variant())
	_check(descriptor.get("ok", false), "a route with a caller_menu_loop resume builds ok")
	_check(descriptor.get("detect_loops", false), "detect_loops is set for a caller_menu_loop resume boundary policy")


func _check_stop_before_dispatch() -> void:
	var analyzer := AnalysisRunScript.new()
	var route := _base_route()
	route["resume"] = {
		"boundary_policy": "stop_before_unprovided_dependency",
		"outcome": {"offset": 0x50, "end": 0x54, "target": "DEP.MES"},
	}
	var descriptor: Dictionary = analyzer.build_group_route_descriptor(route, _base_variant())
	_check(descriptor.get("ok", false), "a route with a stop_before_unprovided_dependency resume builds ok")
	_check(descriptor.has("stop_before_dispatch"), "stop_before_dispatch is set for a stop_before_unprovided_dependency resume boundary policy")
	var stop: Dictionary = descriptor.get("stop_before_dispatch", {})
	_check(str(stop.get("entry", "")) == "CALLER.MES", "stop_before_dispatch's entry is the caller's")
	_check(int(stop.get("offset", -1)) == 0x50, "stop_before_dispatch's offset is the resume outcome's offset")
	_check(str(stop.get("target", "")) == "DEP.MES", "stop_before_dispatch's target is the resume outcome's target")


## EP-12 (2026-10-04, additive to v14): what a variant measures at a flow
## route's questions is the hop's own answer unless the variant overrides it,
## so a selection (`owner_entry`, `boundary_offset`, `result_value`) is
## contained by exactly the variants that give that answer there.
func _flow_route() -> Dictionary:
	return {"route_id": "j-scene-x", "hops": [
		{"hop_id": "h1", "entry": "MENU.MES", "answers": [], "expected": {"message_count": 0}},
		{"hop_id": "h2", "entry": "SCENE.MES", "answers": [{"boundary_offset": 353, "result_value": 1}],
			"expected": {"message_count": 9}},
	]}


func _selection(value: int) -> Dictionary:
	return {"owner_entry": "SCENE.MES", "boundary_offset": 353, "result_value": value}


func _check_flow_selections_follow_the_variant() -> void:
	var analyzer := AnalysisRunScript.new()
	var route := _flow_route()
	var default_variant := {"variant_id": "default", "writes": [], "expected_state": []}
	var option_two := {"variant_id": "option-2", "writes": [], "expected_state": [],
		"answers": [{"hop_id": "h2", "boundary_offset": 353, "result_value": 2}], "message_counts": {"h2": 9}}
	_check(analyzer._selections_contain(default_variant, _selection(1), route), "a variant with no answers measures the hop's own answer")
	_check(not analyzer._selections_contain(default_variant, _selection(2), route), "a variant with no answers does not measure another option")
	_check(analyzer._selections_contain(option_two, _selection(2), route), "a variant's own answer is the option it measures")
	_check(not analyzer._selections_contain(option_two, _selection(1), route), "a variant's override replaces the hop's own answer")
	var other_hop := {"variant_id": "other", "answers": [{"hop_id": "h1", "boundary_offset": 353, "result_value": 2}]}
	_check(analyzer._selections_contain(other_hop, _selection(1), route) and not analyzer._selections_contain(other_hop, _selection(2), route),
		"an override naming another hop does not change this hop's answer")
	var wrong_owner := {"owner_entry": "MENU.MES", "boundary_offset": 353, "result_value": 1}
	_check(not analyzer._selections_contain(default_variant, wrong_owner, route), "the owner is still the answering hop's own entry")


func _check_flow_runner_variant_helpers() -> void:
	var route := _flow_route()
	var scene_hop: Dictionary = route.hops[1]
	var menu_hop: Dictionary = route.hops[0]
	_check(FlowRunnerScript.hop_answers(scene_hop, {}) == scene_hop.answers, "no variant answers keeps the hop's own answers")
	var answers := FlowRunnerScript.hop_answers(scene_hop, {"answers": [{"hop_id": "h2", "boundary_offset": 353, "result_value": 2}]})
	_check(answers.size() == 1 and int(answers[0].boundary_offset) == 353 and int(answers[0].result_value) == 2, "a variant answer replaces the hop's answer at its boundary")
	var supplied := FlowRunnerScript.hop_answers(menu_hop, {"answers": [{"hop_id": "h1", "boundary_offset": 7, "result_value": 3}]})
	_check(supplied.size() == 1 and int(supplied[0].boundary_offset) == 7, "a variant answer at a boundary the hop does not answer is supplied")
	var kept := FlowRunnerScript.hop_answers(scene_hop, {"answers": [{"hop_id": "h2", "boundary_offset": 400, "result_value": 1}]})
	_check(kept.size() == 2 and int(kept[0].boundary_offset) == 353 and int(kept[1].boundary_offset) == 400, "an override at another boundary leaves the hop's answer in place, in order")
	var transported: Dictionary = JSON.parse_string(JSON.stringify({"answers": [{"hop_id": "h2", "boundary_offset": 353, "result_value": 2}], "message_counts": {"h2": 14}}))
	_check(int(FlowRunnerScript.hop_answers(scene_hop, transported)[0].result_value) == 2, "answers survive JSON transport (floats) as integers")
	_check(FlowRunnerScript.hop_message_count(scene_hop, {}) == 9, "no variant counts keeps the hop's own message count")
	_check(FlowRunnerScript.hop_message_count(scene_hop, transported) == 14, "a variant's message count replaces the hop's own")
	_check(FlowRunnerScript.hop_message_count(menu_hop, transported) == 0, "a variant counts only the hops it names")
