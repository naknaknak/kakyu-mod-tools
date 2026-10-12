extends Node

const GroupPreviewContractScript := preload("res://content_core/mes_routine40_group_preview_contract.gd")
const ReachabilityScript := preload("res://content_core/mes_routine40_reachability.gd")
const ConsumerPlanScript := preload("res://content_core/event_player_routine40_consumer_plan.gd")
const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")
const EventRunnerScript := preload("res://content_core/mes_event_runner.gd")
const SandboxStateScript := preload("res://content_core/mes_sandbox_state.gd")

var _failed := false


func _ready() -> void:
	var code := PackedByteArray()
	_append_group_clear(code, 0)
	_append_definition(code, 0, "A")
	_append_definition(code, 1, "B")
	_append_group_clear(code, 1)
	_append_definition(code, 0, "A1")
	_append_definition(code, 1, "A2")
	_append_group_clear(code, 2)
	var boundary_offset := code.size()
	code.append_array(PackedByteArray([0x1D, 0x02, 0x28, 0xFF, 0x00]))
	_append_group_consumer(code)

	var state := SandboxStateScript.new(1)
	var before := state.snapshot()
	var boundary: Dictionary = EventRunnerScript.new().run(code, 0, state, code.size())
	_check(
		str(boundary.get("status", "")) == "def_selection_boundary"
		and int(boundary.get("offset", -1)) == boundary_offset
		and boundary.get("definition_group_order", []) == [0, 1, 2]
		and (boundary.get("definitions", []) as Array).size() == 2
		and int(boundary.get("registered_definition_count", -1)) == 4
		and state.snapshot() == before,
		"Event Runner retains a disposable grouped routine-40 registry without state changes"
	)

	var source_identity := {
		"archive": "mes.arc",
		"entry": "TEST.MES",
		"entry_sha256": "a".repeat(64),
		"resolved_source": "synthetic",
	}
	var builder := GroupPreviewContractScript.new()
	var contract: Dictionary = builder.build(code, code.size(), boundary, source_identity)
	var groups: Array = contract.get("groups", [])
	_check(
		contract.get("ok", false)
		and str(contract.get("schema", "")) == ContentCoreVersionScript.MES_ROUTINE40_GROUP_PREVIEW_SCHEMA
		and contract.get("first_result_values", []) == [1, 2]
		and str(contract.get("first_result_storage", "")) == "state_u16"
		and int(contract.get("first_result_index", -1)) == 21
		and str(contract.get("second_result_storage", "")) == "state_u16"
		and int(contract.get("second_result_index", -1)) == 13
		and groups.size() == 3
		and int((groups[0] as Dictionary).get("definition_count", -1)) == 2
		and int((groups[1] as Dictionary).get("definition_count", -1)) == 2
		and bool((groups[2] as Dictionary).get("empty_after_clear", false))
		and str(contract.get("consumer_kind", "")) == "one_based_state_u16_21_then_state_u16_13_dispatch"
		and (contract.get("consumer_groups", []) as Array).size() == 2
		and not bool(contract.get("complete_available_mapping", true))
		and int((contract.get("default_continuation", {}) as Dictionary).get("destination_offset", -1)) > 0
		and str(contract.get("consumer_execution_policy", "")) == "structural_coordinates_only"
		and str(contract.get("input_policy", "")) == "explicit_disposable_analysis_preview"
		and str(contract.get("caller_resume_policy", "")) == "forbidden"
		and str(contract.get("gameplay_state_policy", "")) == "unchanged",
		"grouped preview contract binds one-based first/second result coordinates while forbidding caller resume"
	)
	_check(
		builder.validate(code, code.size(), contract).get("ok", false),
		"grouped preview contract revalidates every retained body, consumer branch, and source identity"
	)
	var reachability_builder := ReachabilityScript.new()
	var reachability: Dictionary = reachability_builder.build(code, code.size(), contract)
	var fallback_resolution: Dictionary = reachability_builder.resolve(reachability, 1, 2)
	var empty_resolution: Dictionary = reachability_builder.resolve(
		reachability, 2, 0xFFFF
	)
	_check(
		reachability.get("ok", false)
		and str(reachability.get("schema", "")) == ContentCoreVersionScript.MES_ROUTINE40_REACHABILITY_SCHEMA
		and int(reachability.get("route_count", -1)) == 3
		and int(reachability.get("stored_consumer_count", -1)) == 1
		and int(reachability.get("fallback_count", -1)) == 1
		and int(reachability.get("empty_boundary_count", -1)) == 1
		and int(reachability.get("inactive_stored_result_count", -1)) == 0
		and bool(reachability.get("complete_live_numeric_mapping", false))
		and str(reachability.get("semantic_label_policy", "")) == "numeric_only"
		and fallback_resolution.get("ok", false)
		and str((fallback_resolution.get("route", {}) as Dictionary).get("resolution", "")) == "stored_default_continuation"
		and int((fallback_resolution.get("route", {}) as Dictionary).get("definition_id", -1)) == 1
		and empty_resolution.get("ok", false)
		and str((empty_resolution.get("route", {}) as Dictionary).get("resolution", "")) == "native_empty_list_boundary"
		and not reachability_builder.resolve(reachability, 2, 1).get("ok", false),
		"routine-40 reachability resolves live numeric rows, stored fallback, and empty-list sentinel without semantics"
	)
	var consumer_builder := ConsumerPlanScript.new()
	var stored_plan: Dictionary = consumer_builder.build(code, code.size(), contract, 1, 1)
	var fallback_plan: Dictionary = consumer_builder.build(code, code.size(), contract, 1, 2)
	var empty_plan: Dictionary = consumer_builder.build(code, code.size(), contract, 2, 0xFFFF)
	_check(
		stored_plan.get("ok", false)
		and str(stored_plan.get("schema", ""))
			== ContentCoreVersionScript.EVENT_PLAYER_ROUTINE40_CONSUMER_PLAN_SCHEMA
		and str(stored_plan.execution.mode) == "run_source_qualified_consumer"
		and int(stored_plan.execution.start_offset) == int(stored_plan.route.destination_offset)
		and stored_plan.state_writes == [
			{"storage": "state_u16", "index": 21, "value": 1},
			{"storage": "state_u16", "index": 13, "value": 1},
		]
		and str(stored_plan.execution.compatibility) == "remake_only"
		and str(stored_plan.execution.caller_resume_policy) == "forbidden_without_source_bound_frame",
		"Event Player consumer plan binds one reachable numeric pair to its exact stored coordinate"
	)
	_check(
		fallback_plan.get("ok", false)
		and str(fallback_plan.route.resolution) == "stored_default_continuation"
		and int(fallback_plan.execution.start_offset) == int(fallback_plan.route.destination_offset)
		and str(fallback_plan.route.numeric_meaning) == "unresolved",
		"Event Player consumer plan retains the exact fallback without inventing a gameplay label"
	)
	_check(
		empty_plan.get("ok", false)
		and str(empty_plan.route.resolution) == "native_empty_list_boundary"
		and str(empty_plan.execution.mode) == "stop_at_empty_list_boundary"
		and int(empty_plan.execution.start_offset) == -1
		and int(empty_plan.state_writes[1].value) == 0xFFFF,
		"Event Player consumer plan represents an empty live group as a terminal sentinel without a destination"
	)
	_check(
		consumer_builder.validate(code, code.size(), contract, stored_plan).get("ok", false)
		and not consumer_builder.build(code, code.size(), contract, 2, 1).get("ok", false),
		"Event Player consumer plan reopens exactly and rejects a result pair absent from the live registry"
	)
	var transported = JSON.parse_string(JSON.stringify(stored_plan))
	_check(
		transported is Dictionary
		and consumer_builder.validate(
			code, code.size(), contract, transported as Dictionary
		).get("ok", false),
		"Event Player consumer plan survives JSON transport with integral coordinates"
	)
	var promoted := stored_plan.duplicate(true)
	promoted.execution.compatibility = "original_engine_compatible"
	promoted.payload_sha256 = consumer_builder.fingerprint(promoted)
	_check(
		not consumer_builder.validate(code, code.size(), contract, promoted).get("ok", false),
		"Event Player consumer plan cannot promote explicit remake input to original-engine compatibility"
	)
	var serialized := JSON.stringify(stored_plan)
	_check(
		not serialized.contains("A1")
		and not serialized.contains("\\")
		and not serialized.contains(":/"),
		"Event Player consumer plan contains no choice text, payload bytes, or machine path"
	)
	var unsafe_contract := contract.duplicate(true)
	unsafe_contract.source_identity.archive = "C:/source/mes.arc"
	_check(
		not consumer_builder.build(
			code, code.size(), unsafe_contract, 1, 1
		).get("ok", false),
		"Event Player consumer plan rejects a machine path in its logical source identity"
	)

	var changed := code.duplicate()
	changed[12] ^= 0x01
	_check(
		not builder.validate(changed, changed.size(), contract).get("ok", false),
		"grouped preview contract rejects changed source bytes"
	)
	_check(
		not reachability_builder.build(changed, changed.size(), contract).get("ok", false),
		"routine-40 reachability rejects changed source bytes"
	)
	_check(
		not consumer_builder.validate(changed, changed.size(), contract, stored_plan).get("ok", false),
		"Event Player consumer plan rejects changed source bytes before result-state mutation"
	)
	var changed_consumer := code.duplicate()
	var consumer_groups: Array = contract.get("consumer_groups", [])
	var first_consumer_offset := int((consumer_groups[0] as Dictionary).get("first_branch_offset", -1))
	changed_consumer[first_consumer_offset + 3] = 2
	_check(
		not builder.validate(changed_consumer, changed_consumer.size(), contract).get("ok", false),
		"grouped preview contract rejects a changed two-stage result consumer"
	)
	var missing_group_boundary := boundary.duplicate(true)
	(missing_group_boundary.definition_groups as Dictionary).erase(2)
	missing_group_boundary.definition_group_order = [0, 1]
	_check(
		not builder.build(code, code.size(), missing_group_boundary, source_identity).get("ok", false),
		"grouped preview contract rejects a missing group selected by a first-stage result"
	)

	if _failed:
		get_tree().quit(1)
	else:
		print("PASS: MES routine-40 grouped disposable preview contract")
		get_tree().quit(0)


func _append_group_clear(code: PackedByteArray, selector: int) -> void:
	code.append_array(PackedByteArray([0x1B, 0x02, selector & 0xFF, 0xFF, 0x00]))


func _append_definition(code: PackedByteArray, definition_id: int, text: String) -> void:
	var source_offset := code.size()
	code.append_array(PackedByteArray([0x10, 0x02, definition_id & 0xFF, 0xFF, 0x00, 0, 0, 0, 0]))
	code.append(0x01)
	code.append_array(text.to_ascii_buffer())
	code.append(0x00)
	code.encode_u32(source_offset + 5, code.size())


func _append_group_consumer(code: PackedByteArray) -> void:
	var first_one := _append_compound_result_branch(code, 1, 1)
	code.append(0x00)
	var first_two := _append_result_branch(code, 21, 2)
	code.encode_u32(first_one + 11, first_two)
	code.append(0x00)
	var fallback := code.size()
	code.encode_u32(first_two + 6, fallback)
	code.append(0x0C)
	var destination := fallback + 5
	code.resize(destination)
	code.encode_u32(fallback + 1, destination)
	code.append(0x00)


func _append_result_branch(code: PackedByteArray, state_index: int, result_value: int) -> int:
	var source_offset := code.size()
	code.append_array(PackedByteArray([
		0x0B, 0x80, state_index & 0xFF, result_value & 0xFF, 0xEF, 0xFF,
	]))
	code.resize(code.size() + 4)
	return source_offset


func _append_compound_result_branch(
	code: PackedByteArray, first_result: int, second_result: int
) -> int:
	var source_offset := code.size()
	code.append_array(PackedByteArray([
		0x0B,
		0x80, 21, first_result & 0xFF, 0xEF,
		0x80, 13, second_result & 0xFF, 0xEF,
		0xE6, 0xFF,
	]))
	code.resize(code.size() + 4)
	return source_offset


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
