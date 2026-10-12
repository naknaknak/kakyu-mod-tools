class_name KakyuEventPlayerRoutine40ConsumerPlan
extends RefCounted

const ArcReaderScript := preload("res://content_core/arc_reader.gd")
const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")
const DecoderScript := preload("res://content_core/mes_instruction_decoder.gd")
const FingerprintScript := preload("res://content_core/mes_payload_fingerprint.gd")
const ReachabilityScript := preload("res://content_core/mes_routine40_reachability.gd")
const ContractValues := preload("res://content_core/contract_values.gd")

const TOP_KEYS := [
	"ok", "schema", "producer", "source", "choice", "route", "state_writes",
	"execution", "payload_sha256",
]
const SOURCE_KEYS := [
	"archive", "entry", "entry_sha256", "resolved_source", "bytecode_sha256",
	"code_size", "boundary_offset", "resume_offset",
]
const CHOICE_KEYS := ["first_result", "second_result"]
const ROUTE_KEYS := [
	"resolution", "source_offset", "destination_offset", "definition_id",
	"definition_source_offset", "definition_body_offset", "definition_target_offset",
	"definition_body_sha256", "numeric_meaning",
]
const WRITE_KEYS := ["storage", "index", "value"]
const EXECUTION_KEYS := [
	"mode", "start_offset", "compatibility", "state_commit_policy",
	"native_effects", "caller_resume_policy", "semantic_label_policy",
]
const RESOLVED_SOURCE_VALUES := {
	"original_arc": true,
	"overlay": true,
	"materialized_arc": true,
	"synthetic": true,
}
const ROUTE_RESOLUTIONS := {
	"stored_consumer_coordinate": true,
	"stored_default_continuation": true,
	"native_empty_list_boundary": true,
}

var _decoder := DecoderScript.new()
var _reachability := ReachabilityScript.new()


func build(
	code: PackedByteArray,
	end_offset: int,
	group_contract: Dictionary,
	first_result: int,
	second_result: int
) -> Dictionary:
	var built := _build_unvalidated(
		code, end_offset, group_contract, first_result, second_result
	)
	if not built.get("ok", false):
		return built
	built["payload_sha256"] = fingerprint(built)
	var reopened := validate(code, end_offset, group_contract, built)
	return built if reopened.get("ok", false) else reopened


func validate(
	code: PackedByteArray,
	end_offset: int,
	group_contract: Dictionary,
	plan: Dictionary
) -> Dictionary:
	if (
		plan.get("ok") != true
		or str(plan.get("schema", ""))
			!= ContentCoreVersionScript.EVENT_PLAYER_ROUTINE40_CONSUMER_PLAN_SCHEMA
		or not ContractValues.has_exact_keys(plan, TOP_KEYS)
	):
		return _error("Event Player routine-40 consumer-plan schema or fields changed.")
	if plan.get("producer") != {
		"implementation": "content_core_event_player_routine40_consumer_plan",
		"contract": ContentCoreVersionScript.EVENT_PLAYER_ROUTINE40_CONSUMER_PLAN_SCHEMA,
	}:
		return _error("Event Player routine-40 consumer-plan producer changed.")
	var source = plan.get("source")
	if (
		not source is Dictionary
		or not ContractValues.has_exact_keys(source, SOURCE_KEYS)
		or not ArcReaderScript.is_safe_entry_name(str(source.get("archive", "")))
		or not ArcReaderScript.is_safe_entry_name(str(source.get("entry", "")))
		or not ContractValues.is_sha256(str(source.get("entry_sha256", "")))
		or not RESOLVED_SOURCE_VALUES.has(str(source.get("resolved_source", "")))
		or not ContractValues.is_sha256(str(source.get("bytecode_sha256", "")))
		or not _positive_json_integer(source.get("code_size", -1))
		or not ContractValues.nonnegative_json_integer(source.get("boundary_offset", -1))
		or not ContractValues.nonnegative_json_integer(source.get("resume_offset", -1))
	):
		return _error("Event Player routine-40 consumer-plan source is invalid.")
	var retained_sha := str(plan.get("payload_sha256", ""))
	if not ContractValues.is_sha256(retained_sha) or retained_sha != fingerprint(plan):
		return _error("Event Player routine-40 consumer-plan fingerprint changed.")
	var choice = plan.get("choice")
	if (
		not choice is Dictionary
		or not ContractValues.has_exact_keys(choice, CHOICE_KEYS)
		or not _positive_json_integer(choice.get("first_result", -1))
		or not ContractValues.nonnegative_json_integer(choice.get("second_result", -1))
		or int(choice.get("first_result", -1)) > 0xFFFF
		or int(choice.get("second_result", -1)) > 0xFFFF
	):
		return _error("Event Player routine-40 consumer-plan choice changed.")
	var route = plan.get("route")
	if (
		not route is Dictionary
		or not ContractValues.has_exact_keys(route, ROUTE_KEYS)
		or not ROUTE_RESOLUTIONS.has(str(route.get("resolution", "")))
		or not ContractValues.json_integer(route.get("source_offset", -1))
		or not ContractValues.json_integer(route.get("destination_offset", -1))
		or not ContractValues.json_integer(route.get("definition_id", -1))
		or not ContractValues.json_integer(route.get("definition_source_offset", -1))
		or not ContractValues.json_integer(route.get("definition_body_offset", -1))
		or not ContractValues.json_integer(route.get("definition_target_offset", -1))
		or (
			str(route.get("resolution", "")) != "native_empty_list_boundary"
			and not ContractValues.is_sha256(str(route.get("definition_body_sha256", "")))
		)
		or str(route.get("numeric_meaning", "")) not in ["unresolved", "empty_list_sentinel"]
	):
		return _error("Event Player routine-40 consumer-plan route is invalid.")
	var writes = plan.get("state_writes")
	if not writes is Array or writes.size() != 2:
		return _error("Event Player routine-40 consumer-plan writes changed.")
	for write_index in range(writes.size()):
		var write = writes[write_index]
		if (
			not write is Dictionary
			or not ContractValues.has_exact_keys(write, WRITE_KEYS)
			or str(write.get("storage", "")) != "state_u16"
			or int(write.get("index", -1)) != (21 if write_index == 0 else 13)
			or not ContractValues.nonnegative_json_integer(write.get("value", -1))
			or int(write.get("value", -1)) > 0xFFFF
		):
			return _error("Event Player routine-40 consumer-plan write is invalid.")
	var execution = plan.get("execution")
	if (
		not execution is Dictionary
		or not ContractValues.has_exact_keys(execution, EXECUTION_KEYS)
		or str(execution.get("mode", "")) not in [
			"run_source_qualified_consumer", "stop_at_empty_list_boundary",
		]
		or not ContractValues.json_integer(execution.get("start_offset", -2))
		or str(execution.get("compatibility", "")) != "remake_only"
		or str(execution.get("state_commit_policy", ""))
			!= "write_numeric_result_pair_before_consumer"
		or str(execution.get("native_effects", "")) != "omitted"
		or str(execution.get("caller_resume_policy", ""))
			!= "forbidden_without_source_bound_frame"
		or str(execution.get("semantic_label_policy", "")) != "numeric_only"
	):
		return _error("Event Player routine-40 consumer-plan execution policy changed.")
	var rebuilt := _build_unvalidated(
		code,
		end_offset,
		group_contract,
		int(choice.get("first_result", -1)),
		int(choice.get("second_result", -1))
	)
	if not rebuilt.get("ok", false):
		return rebuilt
	rebuilt["payload_sha256"] = fingerprint(rebuilt)
	if str(rebuilt.get("payload_sha256", "")) != retained_sha:
		return _error("Event Player routine-40 consumer plan no longer matches its source contract.")
	return {
		"ok": true,
		"schema": ContentCoreVersionScript.EVENT_PLAYER_ROUTINE40_CONSUMER_PLAN_SCHEMA,
		"payload_sha256": retained_sha,
		"source": (plan.source as Dictionary).duplicate(true),
		"choice": (plan.choice as Dictionary).duplicate(true),
		"route": (plan.route as Dictionary).duplicate(true),
		"state_writes": (plan.state_writes as Array).duplicate(true),
		"execution": (plan.execution as Dictionary).duplicate(true),
	}


func fingerprint(plan: Dictionary) -> String:
	return FingerprintScript.new().fingerprint(plan)


func _build_unvalidated(
	code: PackedByteArray,
	end_offset: int,
	group_contract: Dictionary,
	first_result: int,
	second_result: int
) -> Dictionary:
	var source_identity = group_contract.get("source_identity")
	if not source_identity is Dictionary or not _valid_source_identity(source_identity):
		return _error("Routine-40 consumer plan requires a path-free source identity.")
	var reachability := _reachability.build(code, end_offset, group_contract)
	if not reachability.get("ok", false):
		return _error("Routine-40 consumer reachability is not current: %s" % str(
			reachability.get("error", "validation failed")
		))
	if (
		not bool(reachability.get("complete_live_numeric_mapping", false))
		or str(reachability.get("semantic_label_policy", "")) != "numeric_only"
		or str(reachability.get("consumer_execution_policy", "")) != "coordinates_not_executed"
		or str(reachability.get("caller_resume_policy", "")) != "forbidden"
	):
		return _error("Routine-40 analyzer reachability policy changed.")
	var resolved := _reachability.resolve(reachability, first_result, second_result)
	if not resolved.get("ok", false):
		return _error(str(resolved.get("error", "Routine-40 result pair is not reachable.")))
	var route: Dictionary = resolved.route
	var resolution := str(route.get("resolution", ""))
	if not ROUTE_RESOLUTIONS.has(resolution):
		return _error("Routine-40 consumer route resolution is unsupported.")
	var normalized_route := _normalize_route(route)
	var mode := "stop_at_empty_list_boundary"
	var start_offset := -1
	if resolution != "native_empty_list_boundary":
		start_offset = int(normalized_route.destination_offset)
		if start_offset < 0 or start_offset >= end_offset:
			return _error("Routine-40 consumer destination is outside the current bytecode.")
		if not _decoder.decode_at_structural(code, start_offset, end_offset).get("ok", false):
			return _error("Routine-40 consumer destination is not an exact typed instruction start.")
		mode = "run_source_qualified_consumer"
	elif second_result != int(reachability.get("empty_list_result", -1)):
		return _error("Routine-40 empty-list route lost its confirmed sentinel.")

	return {
		"ok": true,
		"schema": ContentCoreVersionScript.EVENT_PLAYER_ROUTINE40_CONSUMER_PLAN_SCHEMA,
		"producer": {
			"implementation": "content_core_event_player_routine40_consumer_plan",
			"contract": ContentCoreVersionScript.EVENT_PLAYER_ROUTINE40_CONSUMER_PLAN_SCHEMA,
		},
		"source": {
			"archive": str(source_identity.archive).to_lower(),
			"entry": str(source_identity.entry).to_upper(),
			"entry_sha256": str(source_identity.entry_sha256),
			"resolved_source": str(source_identity.resolved_source),
			"bytecode_sha256": str(reachability.bytecode_sha256),
			"code_size": int(reachability.code_size),
			"boundary_offset": int(reachability.boundary_offset),
			"resume_offset": int(reachability.resume_offset),
		},
		"choice": {
			"first_result": first_result,
			"second_result": second_result,
		},
		"route": normalized_route,
		"state_writes": [
			{"storage": "state_u16", "index": int(reachability.first_result_index), "value": first_result},
			{"storage": "state_u16", "index": int(reachability.second_result_index), "value": second_result},
		],
		"execution": {
			"mode": mode,
			"start_offset": start_offset,
			"compatibility": "remake_only",
			"state_commit_policy": "write_numeric_result_pair_before_consumer",
			"native_effects": "omitted",
			"caller_resume_policy": "forbidden_without_source_bound_frame",
			"semantic_label_policy": "numeric_only",
		},
		"payload_sha256": "",
	}


func _normalize_route(route: Dictionary) -> Dictionary:
	return {
		"resolution": str(route.get("resolution", "")),
		"source_offset": int(route.get("source_offset", -1)),
		"destination_offset": int(route.get("destination_offset", -1)),
		"definition_id": int(route.get("definition_id", -1)),
		"definition_source_offset": int(route.get("definition_source_offset", -1)),
		"definition_body_offset": int(route.get("definition_body_offset", -1)),
		"definition_target_offset": int(route.get("definition_target_offset", -1)),
		"definition_body_sha256": str(route.get("definition_body_sha256", "")),
		"numeric_meaning": str(route.get("numeric_meaning", "unresolved")),
	}


func _valid_source_identity(source: Dictionary) -> bool:
	return (
		ContractValues.has_exact_keys(source, ["archive", "entry", "entry_sha256", "resolved_source"])
		and ArcReaderScript.is_safe_entry_name(str(source.get("archive", "")))
		and ArcReaderScript.is_safe_entry_name(str(source.get("entry", "")))
		and ContractValues.is_sha256(str(source.get("entry_sha256", "")))
		and RESOLVED_SOURCE_VALUES.has(str(source.get("resolved_source", "")))
	)


func _positive_json_integer(value: Variant) -> bool:
	return ContractValues.json_integer(value) and int(value) > 0


func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message}
