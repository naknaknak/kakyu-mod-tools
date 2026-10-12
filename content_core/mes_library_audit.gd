class_name KakyuMesLibraryAudit
extends RefCounted

const DecoderScript := preload("res://content_core/mes_instruction_decoder.gd")
const StackEffectScript := preload("res://content_core/mes_stack_effect.gd")
const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")

var last_error := ""
var _decoder := DecoderScript.new()
var _stack_effect := StackEffectScript.new()


func audit(code: PackedByteArray, library_index: Dictionary, routine_ids: Array[int]) -> Dictionary:
	last_error = ""
	if not library_index.get("ok", false):
		return _error("A valid MES library index is required.")
	if routine_ids.is_empty():
		return _error("At least one shared routine ID is required.")
	var seen: Dictionary = {}
	var routines: Array[Dictionary] = []
	for routine_id in routine_ids:
		if routine_id < 0 or seen.has(routine_id):
			return _error("Shared routine IDs must be unique non-negative integers.")
		seen[routine_id] = true
		var by_id: Dictionary = library_index.get("by_id", {})
		if not by_id.has(routine_id):
			return _error("Shared routine %d is not registered." % routine_id)
		var bounds: Dictionary = by_id[routine_id]
		routines.append(_audit_routine(code, bounds))
	return {
		"ok": true,
		"schema": ContentCoreVersionScript.MES_LIBRARY_AUDIT_SCHEMA,
		"routines": routines,
	}


func _audit_routine(code: PackedByteArray, bounds: Dictionary) -> Dictionary:
	var body_offset := int(bounds.body_offset)
	var end_offset := int(bounds.end_offset)
	var strict := _decoder.decode_region(code, body_offset, end_offset)
	var structural := _decoder.decode_region_structural(code, body_offset, end_offset)
	var rows: Array[Dictionary] = []
	var native_stream_boundaries: Array[Dictionary] = []
	var native_record_boundaries: Array[Dictionary] = []
	for untyped_instruction in structural.get("instructions", []):
		var instruction: Dictionary = untyped_instruction
		var effect := _stack_effect.analyze_instruction(instruction)
		var row := {
			"source_offset": int(instruction.source_offset),
			"end_offset": int(instruction.end_offset),
			"command_id": int(instruction.command_id),
			"op": str(instruction.op),
			"structural_only": bool(instruction.get("structural_only", false)),
		}
		if int(effect.expression_count) > 0:
			row["stack_effect"] = effect
		if instruction.has("native_stream_consumption"):
			row["native_handler_family"] = str(instruction.get("native_handler_family", ""))
			row["native_stream_consumption"] = str(instruction.native_stream_consumption)
			if instruction.has("native_stream_probe"):
				row["native_stream_probe"] = instruction.native_stream_probe.duplicate(true)
				if instruction.has("native_stream_projection_match"):
					row["native_stream_projection_match"] = bool(instruction.native_stream_projection_match)
				native_stream_boundaries.append({
					"source_offset": int(instruction.source_offset),
					"command_id": int(instruction.command_id),
					"op": str(instruction.op),
					"probe": instruction.native_stream_probe.duplicate(true),
					"projection_match": bool(instruction.get("native_stream_projection_match", true)),
				})
		if instruction.has("native_record_consumption"):
			var record_operand: Dictionary = instruction.get("operands", [])[0]
			row["native_handler_family"] = str(instruction.native_handler_family)
			row["native_record_consumption"] = str(instruction.native_record_consumption)
			row["native_record_count"] = int(instruction.native_record_count)
			row["native_record_terminator_consumed"] = bool(instruction.native_record_terminator_consumed)
			native_record_boundaries.append({
				"source_offset": int(instruction.source_offset),
				"payload_start_offset": int(record_operand.get("source_offset", -1)),
				"end_offset": int(instruction.end_offset),
				"command_id": int(instruction.command_id),
				"op": str(instruction.op),
				"handler_family": str(instruction.native_handler_family),
				"record_count": int(instruction.native_record_count),
				"terminator_consumed": bool(instruction.native_record_terminator_consumed),
			})
		rows.append(row)
	var sequence_effect := _stack_effect.analyze_sequence(structural.get("instructions", []))
	var native_dispatch_flow := _audit_native_dispatch_flow(code, body_offset, end_offset)
	var unreached_structural_instructions := _unreached_structural_instructions(
		rows,
		native_dispatch_flow
	)
	native_dispatch_flow["unreached_structural_instructions"] = unreached_structural_instructions
	var shadowed_structural_instructions: Array[Dictionary] = []
	for row in unreached_structural_instructions:
		if str(row.get("reason", "")) == "native_payload":
			shadowed_structural_instructions.append(row.duplicate(true))
	native_dispatch_flow["shadowed_structural_instructions"] = shadowed_structural_instructions
	return {
		"routine_id": int(bounds.routine_id),
		"registration_offset": int(bounds.registration_offset),
		"body_offset": body_offset,
		"end_offset": end_offset,
		"strict": _decode_summary(strict),
		"structural": _decode_summary(structural),
		"linear_stack_effect": sequence_effect,
		"linear_stack_effect_scope": "structural_instruction_order_not_cfg_path",
		"native_stream_scope": "dispatch_token_probe_resolved_execution_path_unresolved",
		"native_stream_boundaries": native_stream_boundaries,
		"native_record_scope": "typed_record_extent_confirmed_dispatch_effects_not_executed",
		"native_record_boundaries": native_record_boundaries,
		"native_dispatch_flow": native_dispatch_flow,
		"return_delimited_segments": _return_delimited_segments(structural.get("instructions", [])),
		"instructions": rows,
	}


func _unreached_structural_instructions(rows: Array[Dictionary], native_flow: Dictionary) -> Array[Dictionary]:
	var reached_offsets := {}
	for untyped_instruction in native_flow.get("instructions", []):
		var instruction: Dictionary = untyped_instruction
		reached_offsets[int(instruction.get("source_offset", -1))] = true
	var native_spans: Array = native_flow.get("native_spans", [])
	var unreached: Array[Dictionary] = []
	for row in rows:
		var source_offset := int(row.source_offset)
		if reached_offsets.has(source_offset):
			continue
		var record := {
			"source_offset": source_offset,
			"end_offset": int(row.end_offset),
			"command_id": int(row.command_id),
			"op": str(row.op),
			"reason": "control_flow_not_reached",
		}
		for untyped_span in native_spans:
			var span: Dictionary = untyped_span
			var span_start := int(span.get("source_offset", -1))
			var span_end := int(span.get("end_offset", -1))
			if source_offset <= span_start or source_offset >= span_end:
				continue
			record["reason"] = "native_payload"
			record["owning_span_source_offset"] = span_start
			record["owning_span_end_offset"] = span_end
			record["owning_handler_family"] = str(span.get("handler_family", ""))
			break
		unreached.append(record)
	return unreached


func _literal_record_value(instruction: Dictionary) -> int:
	var operands: Array = instruction.get("operands", [])
	if operands.is_empty():
		return -1
	var records: Array = operands[0].get("records", [])
	if records.size() != 1 or str(records[0].get("type", "")) != "expression_record":
		return -1
	var expression: Dictionary = records[0].get("value", {})
	var ast: Dictionary = expression.get("ast", {})
	return int(ast.get("value", -1)) if expression.get("ok", false) and str(ast.get("type", "")) == "literal" else -1


func _literal_expression_value(instruction: Dictionary) -> int:
	var operands: Array = instruction.get("operands", [])
	if operands.is_empty() or str(operands[0].get("type", "")) != "expression":
		return -1
	var expression: Dictionary = operands[0].get("value", {})
	var ast: Dictionary = expression.get("ast", {})
	return int(ast.get("value", -1)) if expression.get("ok", false) and str(ast.get("type", "")) == "literal" else -1


func _definition_target(instruction: Dictionary) -> int:
	var operands: Array = instruction.get("operands", [])
	if operands.size() != 2:
		return -1
	var target_bytes: Array = operands[1].get("value", [])
	if target_bytes.size() != 4:
		return -1
	return (
		int(target_bytes[0])
		| (int(target_bytes[1]) << 8)
		| (int(target_bytes[2]) << 16)
		| (int(target_bytes[3]) << 24)
	)


func _audit_native_dispatch_flow(code: PackedByteArray, body_offset: int, end_offset: int) -> Dictionary:
	var pending: Array[int] = [body_offset]
	var visited := {}
	var rows_by_offset := {}
	var edges: Array[Dictionary] = []
	var native_spans: Array[Dictionary] = []
	var definition_registrations: Array[Dictionary] = []
	var definition_invocations: Array[Dictionary] = []
	var return_offsets: Array[int] = []
	var exit_offsets: Array[int] = []
	var boundaries: Array[Dictionary] = []
	var failures: Array[String] = []
	while not pending.is_empty():
		var cursor: int = pending.pop_back()
		if cursor == end_offset:
			if not exit_offsets.has(cursor):
				exit_offsets.append(cursor)
			continue
		if cursor < body_offset or cursor > end_offset:
			failures.append("successor 0x%X is outside routine 0x%X..0x%X" % [cursor, body_offset, end_offset])
			continue
		if visited.has(cursor):
			continue
		visited[cursor] = true
		var instruction := _decoder.decode_at_structural(code, cursor, end_offset)
		if not instruction.ok:
			failures.append("decode stopped at 0x%X: %s" % [cursor, str(instruction.error)])
			continue
		var command_id := int(instruction.command_id)
		var dispatch_end := int(instruction.end_offset)
		var row := {
			"source_offset": cursor,
			"decoded_end_offset": dispatch_end,
			"command_id": command_id,
			"op": str(instruction.op),
			"structural_only": bool(instruction.get("structural_only", false)),
		}
		var stack_effect := _stack_effect.analyze_instruction(instruction)
		if int(stack_effect.expression_count) > 0:
			row["stack_effect"] = stack_effect
		match command_id:
			0x03:
				row["write_storage"] = "global_u8"
				row["write_start"] = int(instruction.operands[0].value)
				row["write_count"] = (instruction.operands[1].pairs as Array).size()
			0x04:
				row["write_storage"] = "state_u16"
				row["write_start"] = int(instruction.operands[0].value)
				var write_expressions: Array[Dictionary] = []
				for untyped_pair in instruction.operands[1].pairs:
					var pair: Dictionary = untyped_pair
					write_expressions.append({
						"continuation": int(pair.get("continuation", 0)),
						"ast": pair.get("expression", {}).get("ast", {}).duplicate(true),
					})
				row["write_count"] = write_expressions.size()
				row["write_expressions"] = write_expressions
			0x0A:
				row["write_storage"] = "global_i32"
				row["write_count"] = (instruction.operands[1].pairs as Array).size()
			0x0B:
				row["branch_target"] = int(instruction.operands[1].value)
				row["condition_ast"] = instruction.operands[0].get("value", {}).get("ast", {}).duplicate(true)
			0x0C:
				row["continuation_target"] = int(instruction.operands[0].value)
			0x10:
				row["definition_body_record_value"] = _literal_record_value(instruction)
				row["definition_target"] = _definition_target(instruction)
			0x11:
				row["definition_id"] = _literal_record_value(instruction)
				definition_invocations.append({
					"source_offset": cursor,
					"definition_id": int(row.definition_id),
				})
			0x14:
				row["definition_id"] = _literal_expression_value(instruction)
				row["definition_target"] = int(instruction.operands[1].value)
				definition_registrations.append({
					"source_offset": cursor,
					"definition_id": int(row.definition_id),
					"target_offset": int(row.definition_target),
				})
			0x1D:
				row["routine_id"] = _literal_record_value(instruction)
			0x17:
				row["entry_index"] = int(instruction.operands[0].get("value", -1))
			0x1B:
				row["record_value"] = _literal_record_value(instruction)
		if instruction.has("native_stream_probe"):
			var probe: Dictionary = instruction.native_stream_probe
			var consumed := int(probe.get("consumed_byte_count", 0))
			if consumed > 0:
				var probe_end := int(probe.get("probe_end_offset", dispatch_end))
				if probe_end <= cursor or probe_end > end_offset:
					failures.append("native stream at 0x%X has invalid end 0x%X" % [cursor, probe_end])
					continue
				var payload_start := int(instruction.end_offset)
				var terminator_consumed := (
					str(probe.get("stop_reason", "")) == "nul_consumed"
					and probe_end > payload_start
					and int(code[probe_end - 1]) == 0
				)
				dispatch_end = probe_end
				row["dispatch_end_offset"] = dispatch_end
				row["native_handler_family"] = str(instruction.get("native_handler_family", ""))
				row["native_payload_byte_count"] = consumed
				row["native_payload_start_offset"] = payload_start
				row["native_payload_end_offset"] = probe_end
				row["native_content_byte_count"] = consumed - (1 if terminator_consumed else 0)
				row["native_terminator_consumed"] = terminator_consumed
				native_spans.append({
					"source_offset": cursor,
					"payload_start_offset": payload_start,
					"payload_end_offset": probe_end,
					"end_offset": dispatch_end,
					"command_id": command_id,
					"handler_family": str(instruction.get("native_handler_family", "")),
					"consumed_byte_count": consumed,
					"content_byte_count": consumed - (1 if terminator_consumed else 0),
					"terminator_consumed": terminator_consumed,
					"stop_reason": str(probe.get("stop_reason", "")),
				})
		if instruction.has("native_record_consumption"):
			var record_operand: Dictionary = instruction.get("operands", [])[0]
			var record_payload_start := int(record_operand.get("source_offset", cursor + 1))
			var record_count := int(instruction.get("native_record_count", 0))
			row["native_handler_family"] = str(instruction.get("native_handler_family", ""))
			row["native_record_consumption"] = str(instruction.get("native_record_consumption", ""))
			row["native_record_count"] = record_count
			row["native_payload_start_offset"] = record_payload_start
			row["native_payload_end_offset"] = dispatch_end
			row["native_payload_byte_count"] = dispatch_end - record_payload_start
			row["native_terminator_consumed"] = bool(instruction.get("native_record_terminator_consumed", false))
			native_spans.append({
				"source_offset": cursor,
				"payload_start_offset": record_payload_start,
				"payload_end_offset": dispatch_end,
				"end_offset": dispatch_end,
				"command_id": command_id,
				"handler_family": str(instruction.get("native_handler_family", "")),
				"consumption_kind": str(instruction.get("native_record_consumption", "")),
				"payload_byte_count": dispatch_end - record_payload_start,
				"record_count": record_count,
				"terminator_consumed": bool(instruction.get("native_record_terminator_consumed", false)),
				"dispatch_semantics": str(instruction.get("native_record_dispatch_semantics", "")),
			})
		rows_by_offset[cursor] = row
		var successors: Array[Dictionary] = []
		match command_id:
			0x00:
				return_offsets.append(cursor)
			0x0B:
				successors.append({"offset": dispatch_end, "kind": "true_fallthrough"})
				successors.append({"offset": int(instruction.operands[1].value), "kind": "false_branch"})
			0x0C:
				successors.append({"offset": int(instruction.operands[0].value), "kind": "continuation"})
			0x10:
				successors.append({"offset": _definition_target(instruction), "kind": "definition_skip"})
			0x14:
				successors.append({"offset": int(instruction.operands[1].value), "kind": "bootstrap_transfer"})
			0x18:
				boundaries.append({"source_offset": cursor, "command_id": command_id, "reason": "jump_table_targets_unresolved"})
			_:
				successors.append({"offset": dispatch_end, "kind": "fallthrough"})
		for successor in successors:
			var target := int(successor.offset)
			edges.append({"from_offset": cursor, "to_offset": target, "kind": str(successor.kind)})
			if target < body_offset or target > end_offset:
				failures.append("edge 0x%X -> 0x%X leaves routine bounds" % [cursor, target])
			elif not visited.has(target):
				pending.append(target)
	var offsets: Array = rows_by_offset.keys()
	offsets.sort()
	var rows: Array[Dictionary] = []
	for offset in offsets:
		rows.append(rows_by_offset[offset])
	for invocation in definition_invocations:
		var matching_offsets: Array[int] = []
		for registration in definition_registrations:
			if int(registration.definition_id) == int(invocation.definition_id):
				matching_offsets.append(int(registration.source_offset))
		invocation["matching_registration_offsets"] = matching_offsets
	return {
		"complete": failures.is_empty() and boundaries.is_empty(),
		"instruction_count": rows.size(),
		"edge_count": edges.size(),
		"instructions": rows,
		"edges": edges,
		"native_spans": native_spans,
		"definition_registrations": definition_registrations,
		"definition_invocations": definition_invocations,
		"definition_link_scope": "command14_context_map_coordinates_without_registration_dominance_or_lifetime",
		"return_offsets": return_offsets,
		"exit_offsets": exit_offsets,
		"boundaries": boundaries,
		"failures": failures,
		"scope": "both_branch_edges_with_native_payload_spans_no_expression_evaluation",
	}


func _return_delimited_segments(instructions: Array) -> Array[Dictionary]:
	var segments: Array[Dictionary] = []
	var current: Array = []
	for untyped_instruction in instructions:
		var instruction: Dictionary = untyped_instruction
		current.append(instruction)
		if int(instruction.command_id) == 0x00:
			segments.append(_segment_record(current))
			current = []
	if not current.is_empty():
		segments.append(_segment_record(current))
	return segments


func _segment_record(instructions: Array) -> Dictionary:
	var structural_only_count := 0
	var native_stream_boundary_count := 0
	var first_native_stream_boundary_offset := -1
	for untyped_instruction in instructions:
		var instruction: Dictionary = untyped_instruction
		if bool(instruction.get("structural_only", false)):
			structural_only_count += 1
		if instruction.has("native_stream_consumption"):
			native_stream_boundary_count += 1
			if first_native_stream_boundary_offset < 0:
				first_native_stream_boundary_offset = int(instruction.source_offset)
	var first: Dictionary = instructions[0]
	var last: Dictionary = instructions[-1]
	return {
		"start_offset": int(first.source_offset),
		"end_offset": int(last.end_offset),
		"instruction_count": instructions.size(),
		"structural_only_instruction_count": structural_only_count,
		"native_stream_boundary_count": native_stream_boundary_count,
		"first_native_stream_boundary_offset": first_native_stream_boundary_offset,
		"ends_in_return": int(last.command_id) == 0x00,
		"stack_effect": _stack_effect.analyze_sequence(instructions),
	}


func _decode_summary(decoded: Dictionary) -> Dictionary:
	return {
		"complete": bool(decoded.get("ok", false)),
		"decoded_end_offset": int(decoded.get("decoded_end_offset", -1)),
		"instruction_count": decoded.get("instructions", []).size(),
		"error": str(decoded.get("error", "")),
	}


func _error(message: String) -> Dictionary:
	last_error = message
	return {"ok": false, "error": message}
