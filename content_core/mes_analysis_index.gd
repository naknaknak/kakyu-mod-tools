class_name KakyuMesAnalysisIndex
extends RefCounted

const DecoderScript := preload("res://content_core/mes_instruction_decoder.gd")
const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")
const ContractValues := preload("res://content_core/contract_values.gd")
const MAX_INSTRUCTIONS := 500000

var _decoder := DecoderScript.new()


func build(document: Dictionary) -> Dictionary:
	return _build(document, false)


func build_structural(document: Dictionary) -> Dictionary:
	return _build(document, true)


func _build(document: Dictionary, allow_non_strict_expressions: bool) -> Dictionary:
	if not document.get("ok", false):
		return _error("A valid MES container document is required.")
	if not document.get("bytecode", null) is PackedByteArray:
		return _error("MES container bytecode is missing.")
	var code: PackedByteArray = document.bytecode
	var ranges: Array[Dictionary] = []
	var bootstrap: Dictionary = document.get("bootstrap", {})
	if int(bootstrap.get("size", 0)) > 0:
		ranges.append({
			"id": "bootstrap",
			"offset": int(bootstrap.offset),
			"end_offset": int(bootstrap.end_offset),
		})
	for untyped_entry in document.get("entries", []):
		var entry: Dictionary = untyped_entry
		ranges.append({
			"id": str(entry.id),
			"index": int(entry.index),
			"offset": int(entry.offset),
			"end_offset": int(entry.end_offset),
		})

	var instructions: Array[Dictionary] = []
	var diagnostics: Array[Dictionary] = []
	var opaque_boundaries: Array[Dictionary] = []
	for region in ranges:
		var decoded := (
			_decoder.decode_region_structural_aligned(
				code,
				int(region.offset),
				int(region.end_offset),
				MAX_INSTRUCTIONS
			)
			if allow_non_strict_expressions
			else _decoder.decode_region_aligned(
				code,
				int(region.offset),
				int(region.end_offset),
				MAX_INSTRUCTIONS
			)
		)
		for untyped_instruction in decoded.instructions:
			var instruction: Dictionary = untyped_instruction.duplicate(true)
			instruction["region"] = str(region.id)
			instructions.append(instruction)
		if not decoded.ok:
			var opaque_start := int(decoded.decoded_end_offset)
			var opaque_end := int(region.end_offset)
			var opaque_bytes := code.slice(opaque_start, opaque_end)
			diagnostics.append({
				"region": str(region.id),
				"source_offset": opaque_start,
				"error": str(decoded.error),
			})
			opaque_boundaries.append({
				"type": "opaque_region_tail",
				"region": str(region.id),
				"source_offset": opaque_start,
				"end_offset": opaque_end,
				"byte_length": opaque_end - opaque_start,
				"raw_hex": opaque_bytes.hex_encode(),
				"raw_sha256": ContractValues.sha256_or_empty_digest(opaque_bytes),
				"boundary": "byte_preserving_fail_closed",
				"reason": str(decoded.error),
			})

	var instruction_starts: Dictionary = {}
	for instruction in instructions:
		instruction_starts[int(instruction.source_offset)] = true

	var messages: Array[Dictionary] = []
	var code_references: Array[Dictionary] = []
	var state_references: Array[Dictionary] = []
	var resource_references: Array[Dictionary] = []
	for instruction in instructions:
		_append_message(instruction, messages)
		_append_code_references(instruction, code, instruction_starts, ranges, code_references)
		_append_write_reference(instruction, state_references)
		_scan_state_references(instruction.get("operands", []), int(instruction.source_offset), state_references)
	resource_references = _scan_resource_references(code, instruction_starts, ranges)

	var result := {
		"ok": true,
		"schema": ContentCoreVersionScript.MES_ANALYSIS_SCHEMA,
		"complete": diagnostics.is_empty(),
		"diagnostic_count": diagnostics.size(),
		"instruction_count": instructions.size(),
		"message_count": messages.size(),
		"code_reference_count": code_references.size(),
		"state_reference_count": state_references.size(),
		"resource_reference_count": resource_references.size(),
		"instructions": instructions,
		"messages": messages,
		"code_references": code_references,
		"state_references": state_references,
		"resource_references": resource_references,
		"diagnostics": diagnostics,
		"opaque_boundary_count": opaque_boundaries.size(),
		"opaque_boundaries": opaque_boundaries,
	}
	if allow_non_strict_expressions:
		result["analysis_mode"] = "structural_relocation"
		result["expression_semantics"] = "strict_when_valid_otherwise_boundary_only"
	return result


func build_reference_graph(
	analysis: Dictionary,
	start_offset: int,
	end_offset: int,
	max_nodes := 120,
	expansion_depth := 0,
	max_expanded_regions := 8
) -> Dictionary:
	if not analysis.get("ok", false):
		return _error("A valid MES analysis index is required.")
	if start_offset < 0 or end_offset <= start_offset:
		return _error("CFG range is invalid.")
	if max_nodes < 2:
		return _error("CFG node limit must be at least 2.")
	if expansion_depth < 0:
		return _error("CFG expansion depth cannot be negative.")
	if max_expanded_regions < 0:
		return _error("CFG expanded-region limit cannot be negative.")
	var instructions_by_offset: Dictionary = {}
	var seed_regions: Dictionary = {}
	for instruction in analysis.get("instructions", []):
		var instruction_offset := int(instruction.source_offset)
		instructions_by_offset[instruction_offset] = instruction
		if instruction_offset >= start_offset and instruction_offset < end_offset:
			seed_regions[str(instruction.region)] = true
	var references_by_region: Dictionary = {}
	for reference in analysis.get("code_references", []):
		var source_instruction: Dictionary = instructions_by_offset.get(int(reference.source_offset), {})
		var source_region := str(source_instruction.get("region", "unassigned"))
		var region_references: Array = references_by_region.get(source_region, [])
		region_references.append(reference)
		references_by_region[source_region] = region_references

	var nodes_by_id: Dictionary = {}
	var edges: Array[Dictionary] = []
	var considered_references := 0
	var skipped_references := 0
	var pending: Array[Dictionary] = []
	for reference in analysis.get("code_references", []):
		var source_offset := int(reference.source_offset)
		if source_offset < start_offset or source_offset >= end_offset:
			continue
		pending.append({"reference": reference, "depth": 0})
	var included_regions := seed_regions.duplicate()
	var expanded_region_depths: Dictionary = {}
	var skipped_expansion_regions: Dictionary = {}
	var pending_index := 0
	while pending_index < pending.size():
		var pending_reference: Dictionary = pending[pending_index]
		pending_index += 1
		var reference: Dictionary = pending_reference.reference
		var reference_depth := int(pending_reference.depth)
		var source_offset := int(reference.source_offset)
		considered_references += 1
		var source_id := _graph_node_id(source_offset, "instruction")
		var target_offset := int(reference.target_offset)
		var target_id := _graph_node_id(target_offset, "instruction")
		var source_instruction: Dictionary = instructions_by_offset.get(source_offset, {})
		var source_region := str(source_instruction.get("region", "unassigned"))
		var target_region := str(reference.target_region)
		var confirmed_flow := _is_confirmed_flow_kind(str(reference.kind))
		var target_depth := reference_depth
		if confirmed_flow and target_region != source_region:
			target_depth += 1
		if not nodes_by_id.has(source_id):
			if nodes_by_id.size() >= max_nodes:
				skipped_references += 1
				continue
			nodes_by_id[source_id] = {
				"id": source_id,
				"offset": source_offset,
				"op": str(source_instruction.get("op", reference.op)),
				"status": "indexed",
				"region": source_region,
				"graph_depth": reference_depth,
			}
		if not nodes_by_id.has(target_id):
			if nodes_by_id.size() >= max_nodes:
				skipped_references += 1
				continue
			var target_instruction: Dictionary = instructions_by_offset.get(target_offset, {})
			nodes_by_id[target_id] = {
				"id": target_id,
				"offset": target_offset,
				"op": str(target_instruction.get("op", "unresolved_target")),
				"status": "indexed" if reference.aligned else ("unresolved" if reference.in_code else "outside"),
				"region": target_region,
				"graph_depth": target_depth,
			}
		edges.append({
			"from_id": source_id,
			"to_id": target_id,
			"kind": str(reference.kind),
			"confirmed_flow": confirmed_flow,
			"source_depth": reference_depth,
		})
		if not confirmed_flow or not bool(reference.aligned) or target_depth > expansion_depth:
			continue
		if target_region in [source_region, "outside", "unassigned"] or included_regions.has(target_region):
			continue
		if expanded_region_depths.size() >= max_expanded_regions:
			skipped_expansion_regions[target_region] = true
			continue
		included_regions[target_region] = true
		expanded_region_depths[target_region] = target_depth
		for expanded_reference in references_by_region.get(target_region, []):
			pending.append({"reference": expanded_reference, "depth": target_depth})

	var stop_count := 0
	var skipped_stops := 0
	for diagnostic in analysis.get("diagnostics", []):
		var stop_offset := int(diagnostic.source_offset)
		var stop_region := str(diagnostic.region)
		var in_seed_range := stop_offset >= start_offset and stop_offset < end_offset
		if not in_seed_range and not expanded_region_depths.has(stop_region):
			continue
		stop_count += 1
		var stop_id := _graph_node_id(stop_offset, "stop")
		if nodes_by_id.has(stop_id):
			continue
		if nodes_by_id.size() >= max_nodes:
			skipped_stops += 1
			continue
		nodes_by_id[stop_id] = {
			"id": stop_id,
			"offset": stop_offset,
			"op": "decode_stop",
			"status": "stop",
			"region": stop_region,
			"error": str(diagnostic.error),
			"graph_depth": int(expanded_region_depths.get(stop_region, 0)),
		}

	var nodes: Array[Dictionary] = []
	for node in nodes_by_id.values():
		nodes.append(node)
	nodes.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		if int(left.offset) == int(right.offset):
			return str(left.id) < str(right.id)
		return int(left.offset) < int(right.offset)
	)
	var expanded_regions: Array[Dictionary] = []
	for region_id in expanded_region_depths:
		expanded_regions.append({
			"region": str(region_id),
			"depth": int(expanded_region_depths[region_id]),
		})
	expanded_regions.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		if int(left.depth) == int(right.depth):
			return str(left.region) < str(right.region)
		return int(left.depth) < int(right.depth)
	)
	var skipped_regions: Array[String] = []
	for region_id in skipped_expansion_regions:
		skipped_regions.append(str(region_id))
	skipped_regions.sort()
	return {
		"ok": true,
		"schema": ContentCoreVersionScript.MES_REFERENCE_GRAPH_SCHEMA,
		"range_start": start_offset,
		"range_end": end_offset,
		"nodes": nodes,
		"edges": edges,
		"node_count": nodes.size(),
		"edge_count": edges.size(),
		"reference_count": considered_references,
		"stop_count": stop_count,
		"expansion_depth": expansion_depth,
		"expanded_regions": expanded_regions,
		"expanded_region_count": expanded_regions.size(),
		"max_expanded_regions": max_expanded_regions,
		"skipped_expansion_regions": skipped_regions,
		"truncated": skipped_references > 0 or skipped_stops > 0 or not skipped_regions.is_empty(),
		"skipped_references": skipped_references,
		"skipped_stops": skipped_stops,
	}


func _graph_node_id(offset: int, kind: String) -> String:
	return "%s_%s" % [kind, "%08x" % (offset & 0xFFFFFFFF)]


func _is_confirmed_flow_kind(kind: String) -> bool:
	return kind in [
		"condition_false_target",
		"condition_true_fallthrough",
		"continuation_target",
	]


func _append_message(instruction: Dictionary, messages: Array[Dictionary]) -> void:
	if str(instruction.op) not in ["text", "dispatcher_character_text"]:
		return
	if instruction.operands.is_empty() or not instruction.operands[0] is Dictionary:
		return
	var operand: Dictionary = instruction.operands[0]
	if not operand.get("raw_bytes", null) is PackedByteArray:
		return
	var raw_bytes: PackedByteArray = operand.raw_bytes
	var message := {
		"source_offset": int(instruction.source_offset),
		"end_offset": int(instruction.end_offset),
		"region": str(instruction.region),
		"kind": str(instruction.op),
		"raw_bytes": raw_bytes,
		"raw_hex": raw_bytes.hex_encode(),
		"raw_sha256": ContractValues.sha256_or_empty_digest(raw_bytes),
	}
	if instruction.has("native_stream_consumption"):
		message["native_handler_family"] = str(instruction.native_handler_family)
		message["native_stream_consumption"] = str(instruction.native_stream_consumption)
		message["native_stream_probe"] = instruction.native_stream_probe.duplicate(true)
		message["native_stream_projection_match"] = bool(
			instruction.get("native_stream_projection_match", false)
		)
	messages.append(message)


func _append_code_references(
	instruction: Dictionary,
	code: PackedByteArray,
	instruction_starts: Dictionary,
	ranges: Array[Dictionary],
	output: Array[Dictionary]
) -> void:
	var targets: Array[int] = []
	_collect_code_targets(instruction.get("operands", []), targets)
	for target in targets:
		output.append(_code_reference(
			int(instruction.source_offset),
			str(instruction.op),
			_target_kind(str(instruction.op)),
			target,
			code.size(),
			instruction_starts,
			ranges
		))
	if str(instruction.op) == "branch_if_not_true":
		var fallthrough := int(instruction.end_offset)
		output.append(_code_reference(
			int(instruction.source_offset),
			str(instruction.op),
			"condition_true_fallthrough",
			fallthrough,
			code.size(),
			instruction_starts,
			ranges
		))


func _code_reference(
	source_offset: int,
	op: String,
	kind: String,
	target: int,
	code_size: int,
	instruction_starts: Dictionary,
	ranges: Array[Dictionary]
) -> Dictionary:
	var in_code := target >= 0 and target < code_size
	return {
		"source_offset": source_offset,
		"op": op,
		"kind": kind,
		"target_offset": target,
		"in_code": in_code,
		"aligned": in_code and instruction_starts.has(target),
		"target_region": _find_region(target, ranges) if in_code else "outside",
	}


func _collect_code_targets(value, output: Array[int]) -> void:
	if value is Dictionary:
		var dictionary: Dictionary = value
		if dictionary.get("type", "") == "code_offset":
			output.append(int(dictionary.get("value", -1)))
			return
		for child in dictionary.values():
			_collect_code_targets(child, output)
	elif value is Array:
		for child in value:
			_collect_code_targets(child, output)


func _append_write_reference(instruction: Dictionary, output: Array[Dictionary]) -> void:
	var op := str(instruction.op)
	var operands: Array = instruction.get("operands", [])
	if op == "global_u8_write_run" and operands.size() >= 2:
		output.append({
			"source_offset": int(instruction.source_offset),
			"access": "write",
			"storage": "global_u8",
			"bank": 0,
			"index": str(operands[0].get("value", "?")),
			"count": operands[1].get("pairs", []).size(),
		})
	elif op == "state_u16_write_run" and operands.size() >= 2:
		# MA-11 (Core 0.320.0): the run's destination is its u8 index operand.
		output.append({
			"source_offset": int(instruction.source_offset),
			"access": "write",
			"storage": "state_u16",
			"bank": 0,
			"index": str(operands[0].get("value", "?")),
			"count": operands[1].get("pairs", []).size(),
		})
	elif op == "dynamic_global_u8_write_run" and operands.size() >= 1:
		# MA-11: an expression destination is summarised like a banked one.
		# Command 0x05 keeps its older flat operand shape - the destination
		# expression, then one expression_byte_pair operand per pair.
		var dynamic_destination: Dictionary = operands[0].get("value", {})
		var pair_count := 0
		for operand in operands.slice(1):
			if str(operand.get("type", "")) == "expression_byte_pair":
				pair_count += 1
		output.append({
			"source_offset": int(instruction.source_offset),
			"access": "write",
			"storage": "global_u8",
			"bank": 0,
			"index": _expression_summary(dynamic_destination.get("ast", {})),
			"count": pair_count,
		})
	elif op == "global_i32_write_run" and operands.size() >= 2:
		var i32_destination: Dictionary = operands[0].get("value", {})
		output.append({
			"source_offset": int(instruction.source_offset),
			"access": "write",
			"storage": "global_i32",
			"bank": 0,
			"index": _expression_summary(i32_destination.get("ast", {})),
			"count": operands[1].get("pairs", []).size(),
		})
	elif op in ["banked_u8_write_run", "banked_u16_write_run", "banked_i32_write_run"] and operands.size() >= 3:
		var destination: Dictionary = operands[0].get("value", {})
		var banked_storage := "banked_u16"
		if op == "banked_i32_write_run":
			banked_storage = "banked_i32"
		elif op == "banked_u8_write_run":
			banked_storage = "banked_u8"
		output.append({
			"source_offset": int(instruction.source_offset),
			"access": "write",
			"storage": banked_storage,
			"bank": int(operands[1].get("value", 0)),
			"index": _expression_summary(destination.get("ast", {})),
			"count": operands[2].get("pairs", []).size(),
		})


func _scan_state_references(value, source_offset: int, output: Array[Dictionary]) -> void:
	if value is Dictionary:
		var dictionary: Dictionary = value
		if dictionary.get("type", "") == "state_ref":
			output.append({
				"source_offset": source_offset,
				"access": "read",
				"storage": str(dictionary.get("storage", "unknown")),
				"bank": int(dictionary.get("bank", 0)),
				"index": _expression_summary(dictionary.get("index", {})),
				"count": 1,
			})
		for child in dictionary.values():
			_scan_state_references(child, source_offset, output)
	elif value is Array:
		for child in value:
			_scan_state_references(child, source_offset, output)


func _scan_resource_references(
	code: PackedByteArray,
	instruction_starts: Dictionary,
	ranges: Array[Dictionary]
) -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	var offset := 0
	while offset < code.size():
		if int(code[offset]) not in [0x08, 0x09, 0x0D]:
			offset += 1
			continue
		var marker := _decoder.decode_resource_marker_at(code, offset, code.size())
		if not marker.get("matched", false) or not marker.get("result", {}).get("ok", false):
			offset += 1
			continue
		var instruction: Dictionary = marker.result.duplicate(true)
		instruction["region"] = _find_region(offset, ranges)
		_append_resource_reference(instruction, instruction_starts.has(offset), output)
		offset = maxi(offset + 1, int(instruction.end_offset))
	return output


func _append_resource_reference(
	instruction: Dictionary,
	strict_indexed: bool,
	output: Array[Dictionary]
) -> void:
	var op := str(instruction.get("op", ""))
	var resource_kind := ""
	var archive_candidates: Array[String] = []
	match op:
		"mmo_resource_marker":
			resource_kind = "mmo"
			archive_candidates = ["mmo.arc"]
		"ax_resource_marker":
			resource_kind = "ax"
			archive_candidates = ["data.arc"]
		"voice_marker":
			resource_kind = "voice"
			archive_candidates = ["voice.arc", "tina1.arc", "tina2.arc"]
		"inline_script_execution":
			resource_kind = "mes_script"
			archive_candidates = ["mes.arc"]
		_:
			return
	var operands: Array = instruction.get("operands", [])
	if operands.is_empty() or not operands[0] is Dictionary:
		return
	var operand: Dictionary = operands[0]
	if str(operand.get("type", "")) != "resource_name":
		return
	var resource_name := str(operand.get("name", ""))
	if resource_name.is_empty():
		return
	var reference := {
		"source_offset": int(instruction.get("source_offset", -1)),
		"region": str(instruction.get("region", "unassigned")),
		"op": op,
		"resource_kind": resource_kind,
		"name": resource_name,
		"source_name": str(operand.get("source_name", resource_name)),
		"archive_candidates": archive_candidates,
		"boundary": "strict_indexed" if strict_indexed else "bounded_envelope_scan",
		"native_semantics": str(operand.get(
			"native_consumer_semantics",
			operand.get("native_playback_semantics", "unresolved")
		)),
	}
	if operand.has("native_audible_output"):
		reference["native_audible_output"] = str(operand.native_audible_output)
	if operand.has("native_audible_evidence"):
		reference["native_audible_evidence"] = str(operand.native_audible_evidence)
	if operand.has("native_host_device_output"):
		reference["native_host_device_output"] = str(operand.native_host_device_output)
	if operand.has("tool_preview_semantics"):
		reference["tool_preview_semantics"] = str(operand.tool_preview_semantics)
	if operand.has("presentation_subcommand"):
		reference["presentation_subcommand"] = int(operand.presentation_subcommand)
	if operand.has("outer_command"):
		reference["outer_command"] = int(operand.outer_command)
	if operand.has("native_default_origin_arguments"):
		reference["native_default_origin_arguments"] = operand.native_default_origin_arguments.duplicate()
	if operand.has("native_active_surface_state_offset"):
		reference["native_active_surface_state_offset"] = int(operand.native_active_surface_state_offset)
	if operand.has("native_active_surface_storage"):
		reference["native_active_surface_storage"] = str(operand.native_active_surface_storage)
	if operand.has("native_active_surface_bank"):
		reference["native_active_surface_bank"] = int(operand.native_active_surface_bank)
	if operand.has("native_active_surface_storage_index"):
		reference["native_active_surface_storage_index"] = int(operand.native_active_surface_storage_index)
	if operand.has("native_active_surface_identity"):
		reference["native_active_surface_identity"] = str(operand.native_active_surface_identity)
	if operand.has("execution_selector"):
		reference["execution_selector"] = int(operand.execution_selector)
	if operand.has("execution_role"):
		reference["execution_role"] = str(operand.execution_role)
	if operand.has("data_archive_index"):
		reference["data_archive_index"] = int(operand.data_archive_index)
	if operand.has("native_loader_argument"):
		reference["native_loader_argument"] = str(operand.native_loader_argument)
	if operand.has("native_loader_argument_semantics"):
		reference["native_loader_argument_semantics"] = str(
			operand.native_loader_argument_semantics
		)
	if operand.has("native_payload_semantics"):
		reference["native_payload_semantics"] = str(operand.native_payload_semantics)
	if operand.has("native_context_restore"):
		reference["native_context_restore"] = str(operand.native_context_restore)
	if operand.has("tool_execution_semantics"):
		reference["tool_execution_semantics"] = str(operand.tool_execution_semantics)
	output.append(reference)


func _expression_summary(ast: Dictionary) -> String:
	if ast.get("type", "") == "literal":
		return str(ast.get("value", 0))
	return "expression"


func _target_kind(op: String) -> String:
	match op:
		"branch_if_not_true": return "condition_false_target"
		"continuation_transfer": return "continuation_target"
		"bootstrap_transfer": return "bootstrap_transfer_target"
		"library_register_skip": return "library_body_skip_target"
		_: return "code_target"


func _find_region(offset: int, ranges: Array[Dictionary]) -> String:
	for region in ranges:
		if offset >= int(region.offset) and offset < int(region.end_offset):
			return str(region.id)
	return "unassigned"


func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message}
