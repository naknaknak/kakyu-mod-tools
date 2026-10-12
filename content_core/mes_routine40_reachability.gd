class_name KakyuMesRoutine40Reachability
extends RefCounted

const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")
const GroupPreviewContractScript := preload("res://content_core/mes_routine40_group_preview_contract.gd")

const EMPTY_LIST_RESULT := 0xFFFF


func build(
	code: PackedByteArray,
	end_offset: int,
	group_contract: Dictionary
) -> Dictionary:
	var validated := GroupPreviewContractScript.new().validate(
		code, end_offset, group_contract
	)
	if not validated.get("ok", false):
		return _error("Routine-40 grouped source contract is not current: %s" % str(
			validated.get("error", "validation failed")
		))
	var first_values: Array = group_contract.get("first_result_values", [])
	if first_values.is_empty():
		return _error("Routine-40 reachability has no first-stage results.")
	for index in range(first_values.size()):
		if int(first_values[index]) != index + 1:
			return _error("Routine-40 first-stage results are not sequential and one based.")

	var available_by_selector := {}
	for untyped_group in group_contract.get("groups", []):
		if not untyped_group is Dictionary:
			return _error("Routine-40 reachability contains an invalid group row.")
		var group: Dictionary = untyped_group
		var selector := int(group.get("selector", -1))
		if selector < 0 or available_by_selector.has(selector):
			return _error("Routine-40 reachability group selectors are invalid or repeated.")
		available_by_selector[selector] = group

	var default_continuation: Dictionary = group_contract.get("default_continuation", {})
	var default_source := int(default_continuation.get("source_offset", -1))
	var default_destination := int(default_continuation.get("destination_offset", -1))
	if default_source < 0 or default_destination < 0:
		return _error("Routine-40 reachability has no exact default continuation.")

	var consumer_groups: Array = group_contract.get("consumer_groups", [])
	if consumer_groups.size() != first_values.size():
		return _error("Routine-40 reachability consumer group count changed.")
	var route_rows: Array[Dictionary] = []
	var group_rows: Array[Dictionary] = []
	var stored_consumer_count := 0
	var fallback_count := 0
	var empty_boundary_count := 0
	var inactive_stored_count := 0
	for index in range(first_values.size()):
		var first_result := int(first_values[index])
		var available_group: Dictionary = available_by_selector.get(first_result, {})
		var consumer_group: Dictionary = consumer_groups[index]
		if (
			available_group.is_empty()
			or int(consumer_group.get("first_result", -1)) != first_result
			or int(consumer_group.get("group_selector", -1)) != first_result
		):
			return _error("Routine-40 reachability group/consumer order changed.")
		var definitions: Array = available_group.get("definitions", [])
		var available_count := int(available_group.get("definition_count", -1))
		if available_count != definitions.size():
			return _error("Routine-40 live group definition count changed.")
		var branches_by_result := {}
		for untyped_branch in consumer_group.get("second_branches", []):
			if not untyped_branch is Dictionary:
				return _error("Routine-40 reachability contains an invalid second-stage branch.")
			var branch: Dictionary = untyped_branch
			var second_result := int(branch.get("second_result", -1))
			if second_result <= 0 or branches_by_result.has(second_result):
				return _error("Routine-40 second-stage results are invalid or repeated.")
			branches_by_result[second_result] = branch
		var unmatched: Array = consumer_group.get("unmatched_available_second_results", [])
		var expected_unmatched: Array[int] = []
		var inactive_stored: Array[int] = []
		for untyped_result in branches_by_result:
			var stored_result := int(untyped_result)
			if stored_result > available_count:
				inactive_stored.append(stored_result)
		inactive_stored.sort()
		inactive_stored_count += inactive_stored.size()

		var live_routes: Array[Dictionary] = []
		if available_count == 0:
			var empty_route := {
				"first_result": first_result,
				"group_selector": first_result,
				"second_result": EMPTY_LIST_RESULT,
				"resolution": "native_empty_list_boundary",
				"source_offset": int(consumer_group.get("first_branch_offset", -1)),
				"destination_offset": -1,
				"numeric_meaning": "empty_list_sentinel",
			}
			live_routes.append(empty_route)
			route_rows.append(empty_route.duplicate(true))
			empty_boundary_count += 1
		else:
			for second_result in range(1, available_count + 1):
				var definition: Dictionary = definitions[second_result - 1]
				var route := {
					"first_result": first_result,
					"group_selector": first_result,
					"second_result": second_result,
					"definition_id": int(definition.get("definition_id", -1)),
					"definition_source_offset": int(definition.get("source_offset", -1)),
					"definition_body_offset": int(definition.get("body_offset", -1)),
					"definition_target_offset": int(definition.get("target_offset", -1)),
					"definition_body_sha256": str(definition.get("body_sha256", "")),
					"numeric_meaning": "unresolved",
				}
				if branches_by_result.has(second_result):
					var branch: Dictionary = branches_by_result[second_result]
					route["resolution"] = "stored_consumer_coordinate"
					route["source_offset"] = int(branch.get("source_offset", -1))
					route["destination_offset"] = int(branch.get("consumer_entry_offset", -1))
					stored_consumer_count += 1
				else:
					expected_unmatched.append(second_result)
					route["resolution"] = "stored_default_continuation"
					route["source_offset"] = default_source
					route["destination_offset"] = default_destination
					fallback_count += 1
				live_routes.append(route)
				route_rows.append(route.duplicate(true))
		var normalized_unmatched: Array[int] = []
		for untyped_result in unmatched:
			normalized_unmatched.append(int(untyped_result))
		if normalized_unmatched != expected_unmatched:
			return _error("Routine-40 live unmatched-result set changed.")
		group_rows.append({
			"first_result": first_result,
			"group_selector": first_result,
			"available_definition_count": available_count,
			"stored_second_result_count": branches_by_result.size(),
			"inactive_stored_second_results": inactive_stored,
			"live_routes": live_routes,
		})

	return {
		"ok": true,
		"schema": ContentCoreVersionScript.MES_ROUTINE40_REACHABILITY_SCHEMA,
		"source_identity": (group_contract.get("source_identity", {}) as Dictionary).duplicate(true),
		"bytecode_sha256": str(group_contract.get("bytecode_sha256", "")),
		"code_size": int(group_contract.get("code_size", -1)),
		"boundary_offset": int(group_contract.get("boundary_offset", -1)),
		"resume_offset": int(group_contract.get("resume_offset", -1)),
		"first_result_storage": str(group_contract.get("first_result_storage", "")),
		"first_result_index": int(group_contract.get("first_result_index", -1)),
		"second_result_storage": str(group_contract.get("second_result_storage", "")),
		"second_result_index": int(group_contract.get("second_result_index", -1)),
		"empty_list_result": EMPTY_LIST_RESULT,
		"groups": group_rows,
		"routes": route_rows,
		"route_count": route_rows.size(),
		"stored_consumer_count": stored_consumer_count,
		"fallback_count": fallback_count,
		"empty_boundary_count": empty_boundary_count,
		"inactive_stored_result_count": inactive_stored_count,
		"complete_live_numeric_mapping": true,
		"reachability_scope": "post_routine40_numeric_dispatch_with_live_registry",
		"semantic_label_policy": "numeric_only",
		"native_input_and_cadence": "unresolved",
		"consumer_execution_policy": "coordinates_not_executed",
		"caller_resume_policy": "forbidden",
	}


func resolve(report: Dictionary, first_result: int, second_result: int) -> Dictionary:
	if str(report.get("schema", "")) != ContentCoreVersionScript.MES_ROUTINE40_REACHABILITY_SCHEMA:
		return _error("Routine-40 reachability schema is unsupported.")
	for untyped_route in report.get("routes", []):
		if not untyped_route is Dictionary:
			continue
		var route: Dictionary = untyped_route
		if (
			int(route.get("first_result", -1)) == first_result
			and int(route.get("second_result", -1)) == second_result
		):
			return {"ok": true, "route": route.duplicate(true)}
	return _error("Routine-40 result pair is not reachable in the retained live registry.")


func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message}
