class_name KakyuMesAnalyzerHandoff
extends RefCounted

const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")
const AlignmentAuditScript := preload("res://content_core/mes_record_alignment_audit.gd")
const ContractValues := preload("res://content_core/contract_values.gd")

const CALL_EVIDENCE_SCHEMAS := [
	ContentCoreVersionScript.MES_REGISTERED_DEFINITION_CALL_SCHEMA,
	ContentCoreVersionScript.MES_CALLER_ROUTE_SCHEMA,
	ContentCoreVersionScript.MES_ROUTINE40_REACHABILITY_SCHEMA,
]
const TRACE_EVIDENCE_SCHEMAS := [
	ContentCoreVersionScript.MES_EVENT_TRACE_SCHEMA,
	ContentCoreVersionScript.MES_SCRIPT_CALL_TRACE_SCHEMA,
	ContentCoreVersionScript.MES_REGISTERED_DEFINITION_TRACE_SCHEMA,
	ContentCoreVersionScript.MES_LIBRARY_TRACE_SCHEMA,
]
const PRODUCT_UI_KEYS := [
	"ui",
	"ui_state",
	"ui_label",
	"footer_label",
	"status_label",
	"event_catalog",
	"event_player",
	"preview_footer",
	"preview_message",
]


func build(
	document: Dictionary,
	analysis: Dictionary,
	graphs: Array = [],
	call_evidence: Array = [],
	trace_evidence: Array = []
) -> Dictionary:
	var validation := _validate_inputs(
		document, analysis, graphs, call_evidence, trace_evidence
	)
	if not validation.get("ok", false):
		return validation
	var alignment: Dictionary = AlignmentAuditScript.new().audit(document)
	if (
		not alignment.get("ok", false)
		or str(alignment.get("schema", ""))
		!= ContentCoreVersionScript.MES_RECORD_ALIGNMENT_AUDIT_SCHEMA
	):
		return _error("MES record alignment is not complete for the handoff.")

	var raw_container := _rebuild_container(document)
	if ContractValues.sha256(raw_container) != str(document.get("entry_sha256", "")):
		return _error("MES container reconstruction does not match its source hash.")
	var source_identity := _source_identity(document.get("source", {}))
	var component_schemas := {
		"container": ContentCoreVersionScript.MES_CONTAINER_SCHEMA,
		"instruction": ContentCoreVersionScript.MES_INSTRUCTION_SCHEMA,
		"analysis": ContentCoreVersionScript.MES_ANALYSIS_SCHEMA,
		"record_alignment": ContentCoreVersionScript.MES_RECORD_ALIGNMENT_AUDIT_SCHEMA,
		"reference_graph": ContentCoreVersionScript.MES_REFERENCE_GRAPH_SCHEMA,
		"accepted_call_evidence": CALL_EVIDENCE_SCHEMAS.duplicate(),
		"accepted_trace_evidence": TRACE_EVIDENCE_SCHEMAS.duplicate(),
	}
	var payload := {
		"ok": true,
		"schema": ContentCoreVersionScript.MES_ANALYZER_HANDOFF_SCHEMA,
		"producer": {
			"implementation": "godot_gdscript_phase1_4",
			"contract": ContentCoreVersionScript.MES_ANALYZER_HANDOFF_SCHEMA,
		},
		"compatibility": {
			"policy": "exact_component_schema_match",
			"unknown_handoff_schema": "reject",
			"unknown_component_schema": "reject",
			"unknown_v1_field": "ignore",
			"dictionary_key_encoding": "unique_string_key",
			"packed_byte_array_encoding": "hex_object",
			"component_schemas": component_schemas,
		},
		"source_identity": source_identity,
		"container": {
			"schema": str(document.schema),
			"header": document.header.duplicate(true),
			"bootstrap": document.bootstrap.duplicate(true),
			"entries": (document.entries as Array).duplicate(true),
			"entry_sha256": str(document.entry_sha256),
			"bytecode_sha256": str(document.bytecode_sha256),
			"raw_hex": raw_container.hex_encode(),
		},
		"record_alignment": alignment.duplicate(true),
		"typed_ir": {
			"schema": str(analysis.schema),
			"complete": bool(analysis.complete),
			"instructions": (analysis.instructions as Array).duplicate(true),
			"diagnostics": (analysis.diagnostics as Array).duplicate(true),
			"opaque_boundaries": (
				analysis.get("opaque_boundaries", []) as Array
			).duplicate(true),
		},
		"references": {
			"messages": (analysis.messages as Array).duplicate(true),
			"code": (analysis.code_references as Array).duplicate(true),
			"state": (analysis.state_references as Array).duplicate(true),
			"resources": (analysis.resource_references as Array).duplicate(true),
		},
		"cfg": graphs.duplicate(true),
		"calls": call_evidence.duplicate(true),
		"traces": trace_evidence.duplicate(true),
		"capability_report": _capability_report(
			analysis, alignment, graphs, call_evidence, trace_evidence
		),
	}
	if analysis.has("analysis_mode"):
		payload.typed_ir["analysis_mode"] = str(analysis.analysis_mode)
		payload.typed_ir["expression_semantics"] = str(
			analysis.get("expression_semantics", "unresolved")
		)
	var transport := _validate_transport(payload, "handoff")
	if not transport.get("ok", false):
		return transport
	var normalized: Dictionary = _normalize(payload)
	normalized["payload_sha256"] = ContractValues.sha256(
		JSON.stringify(normalized, "", true, true).to_utf8_buffer()
	)
	return normalized


func verify(handoff: Dictionary) -> Dictionary:
	if str(handoff.get("schema", "")) != ContentCoreVersionScript.MES_ANALYZER_HANDOFF_SCHEMA:
		return _error("MES analyzer handoff schema is unsupported.")
	var compatibility: Dictionary = handoff.get("compatibility", {})
	var schemas: Dictionary = compatibility.get("component_schemas", {})
	var expected := {
		"container": ContentCoreVersionScript.MES_CONTAINER_SCHEMA,
		"instruction": ContentCoreVersionScript.MES_INSTRUCTION_SCHEMA,
		"analysis": ContentCoreVersionScript.MES_ANALYSIS_SCHEMA,
		"record_alignment": ContentCoreVersionScript.MES_RECORD_ALIGNMENT_AUDIT_SCHEMA,
		"reference_graph": ContentCoreVersionScript.MES_REFERENCE_GRAPH_SCHEMA,
	}
	for key in expected:
		if str(schemas.get(key, "")) != str(expected[key]):
			return _error("MES analyzer handoff component schema changed: %s" % key)
	if schemas.get("accepted_call_evidence", []) != CALL_EVIDENCE_SCHEMAS:
		return _error("MES analyzer handoff call evidence schemas changed.")
	if schemas.get("accepted_trace_evidence", []) != TRACE_EVIDENCE_SCHEMAS:
		return _error("MES analyzer handoff trace evidence schemas changed.")
	var ui_key := _find_product_ui_key(handoff)
	if not ui_key.is_empty():
		return _error("MES analyzer handoff contains product UI field: %s" % ui_key)
	var retained_hash := str(handoff.get("payload_sha256", ""))
	if retained_hash.length() != 64:
		return _error("MES analyzer handoff fingerprint is missing.")
	var payload := handoff.duplicate(true)
	payload.erase("payload_sha256")
	var transport := _validate_transport(payload, "handoff")
	if not transport.get("ok", false):
		return transport
	var normalized: Dictionary = _normalize(payload)
	var actual_hash := ContractValues.sha256(
		JSON.stringify(normalized, "", true, true).to_utf8_buffer()
	)
	if actual_hash != retained_hash:
		return _error("MES analyzer handoff fingerprint changed.")
	return {
		"ok": true,
		"schema": ContentCoreVersionScript.MES_ANALYZER_HANDOFF_SCHEMA,
		"payload_sha256": retained_hash,
	}


func to_json(handoff: Dictionary) -> String:
	if not verify(handoff).get("ok", false):
		return ""
	return JSON.stringify(handoff, "", true, true)


func _validate_inputs(
	document: Dictionary,
	analysis: Dictionary,
	graphs: Array,
	call_evidence: Array,
	trace_evidence: Array
) -> Dictionary:
	if (
		not document.get("ok", false)
		or str(document.get("schema", "")) != ContentCoreVersionScript.MES_CONTAINER_SCHEMA
		or not document.get("bytecode", null) is PackedByteArray
	):
		return _error("A current lossless MES container is required.")
	if (
		not analysis.get("ok", false)
		or str(analysis.get("schema", "")) != ContentCoreVersionScript.MES_ANALYSIS_SCHEMA
	):
		return _error("A current MES analysis index is required.")
	var code: PackedByteArray = document.bytecode
	var instructions: Array = analysis.get("instructions", [])
	if int(analysis.get("instruction_count", -1)) != instructions.size():
		return _error("MES analysis instruction count changed.")
	for untyped_instruction in instructions:
		if not untyped_instruction is Dictionary:
			return _error("MES analysis contains a non-dictionary instruction.")
		var instruction: Dictionary = untyped_instruction
		var start := int(instruction.get("source_offset", -1))
		var end := int(instruction.get("end_offset", -1))
		if (
			str(instruction.get("schema", "")) != ContentCoreVersionScript.MES_INSTRUCTION_SCHEMA
			or start < 0
			or end <= start
			or end > code.size()
			or int(instruction.get("byte_length", -1)) != end - start
			or str(instruction.get("raw_hex", "")) != code.slice(start, end).hex_encode()
		):
			return _error("MES handoff instruction boundary or schema changed.")
	var count_fields := {
		"message_count": "messages",
		"code_reference_count": "code_references",
		"state_reference_count": "state_references",
		"resource_reference_count": "resource_references",
		"diagnostic_count": "diagnostics",
		"opaque_boundary_count": "opaque_boundaries",
	}
	for count_key in count_fields:
		var rows: Array = analysis.get(count_fields[count_key], [])
		if int(analysis.get(count_key, -1)) != rows.size():
			return _error("MES analysis count changed: %s" % count_key)
	for untyped_boundary in analysis.get("opaque_boundaries", []):
		var boundary: Dictionary = untyped_boundary
		var start := int(boundary.get("source_offset", -1))
		var end := int(boundary.get("end_offset", -1))
		var raw := code.slice(start, end) if start >= 0 and end >= start else PackedByteArray()
		if (
			start < 0
			or end <= start
			or end > code.size()
			or str(boundary.get("raw_hex", "")) != raw.hex_encode()
			or str(boundary.get("raw_sha256", "")) != ContractValues.sha256(raw)
			or str(boundary.get("boundary", "")) != "byte_preserving_fail_closed"
		):
			return _error("MES analysis opaque boundary is not byte preserving.")
	for untyped_graph in graphs:
		if not untyped_graph is Dictionary:
			return _error("MES handoff contains a non-dictionary CFG.")
		var graph: Dictionary = untyped_graph
		if (
			not graph.get("ok", false)
			or str(graph.get("schema", "")) != ContentCoreVersionScript.MES_REFERENCE_GRAPH_SCHEMA
		):
			return _error("MES handoff CFG schema is unsupported.")
		var node_ids := {}
		for untyped_node in graph.get("nodes", []):
			node_ids[str((untyped_node as Dictionary).get("id", ""))] = true
		for untyped_edge in graph.get("edges", []):
			var edge: Dictionary = untyped_edge
			if not node_ids.has(str(edge.get("from_id", ""))) or not node_ids.has(
				str(edge.get("to_id", ""))
			):
				return _error("MES handoff CFG contains a dangling edge.")
	var call_result := _validate_evidence(call_evidence, CALL_EVIDENCE_SCHEMAS, "call")
	if not call_result.get("ok", false):
		return call_result
	var trace_result := _validate_evidence(trace_evidence, TRACE_EVIDENCE_SCHEMAS, "trace")
	if not trace_result.get("ok", false):
		return trace_result
	return {"ok": true}


func _validate_evidence(rows: Array, accepted_schemas: Array, kind: String) -> Dictionary:
	for untyped_row in rows:
		if not untyped_row is Dictionary:
			return _error("MES %s evidence is not a dictionary." % kind)
		var row: Dictionary = untyped_row
		if str(row.get("schema", "")) not in accepted_schemas:
			return _error("MES %s evidence schema is unsupported." % kind)
		var ui_key := _find_product_ui_key(row)
		if not ui_key.is_empty():
			return _error("MES %s evidence contains product UI field: %s" % [kind, ui_key])
	return {"ok": true}


func _capability_report(
	analysis: Dictionary,
	alignment: Dictionary,
	graphs: Array,
	call_evidence: Array,
	trace_evidence: Array
) -> Dictionary:
	var instructions: Array = analysis.get("instructions", [])
	return {
		"phase_range": [1, 2, 3, 4],
		"completion_scope": "safe_reproducible_low_level_structure",
		"typed_instruction_ops": _count_values(instructions, "op"),
		"compound_record_families": (
			alignment.get("compound_families", {}) as Dictionary
		).duplicate(true),
		"opaque_boundary_types": _count_values(
			analysis.get("opaque_boundaries", []), "type"
		),
		"code_reference_kinds": _count_values(
			analysis.get("code_references", []), "kind"
		),
		"resource_reference_kinds": _count_values(
			analysis.get("resource_references", []), "resource_kind"
		),
		"cfg_count": graphs.size(),
		"call_evidence_schemas": _count_values(call_evidence, "schema"),
		"trace_evidence_schemas": _count_values(trace_evidence, "schema"),
		"semantic_policy": "numeric_or_source_qualified_only",
		"remaining_numeric_or_unresolved_meanings": [
			"state_and_bank_indices",
			"native_selector_arguments",
			"choice_and_routine_results_without_source_qualified_labels",
			"native_pixel_audio_and_input_effects",
			"outer_host_handoff_consumers",
		],
		"product_ui_data": "forbidden",
		"source_mutation": "forbidden",
	}


func _count_values(rows: Array, key: String) -> Dictionary:
	var counts := {}
	for untyped_row in rows:
		if not untyped_row is Dictionary:
			continue
		var value := str((untyped_row as Dictionary).get(key, "unresolved"))
		counts[value] = int(counts.get(value, 0)) + 1
	return counts


func _source_identity(untyped_source: Variant) -> Dictionary:
	var output := {}
	if not untyped_source is Dictionary:
		return output
	var source: Dictionary = untyped_source
	for key in ["archive", "entry", "source_kind", "archive_sha256"]:
		if source.has(key):
			output[key] = source[key]
	return output


func _rebuild_container(document: Dictionary) -> PackedByteArray:
	var output := PackedByteArray()
	var offsets: Array = document.get("header", {}).get("entry_offsets", [])
	output.resize(4 + offsets.size() * 4)
	output.encode_u32(0, offsets.size())
	for index in range(offsets.size()):
		output.encode_u32(4 + index * 4, int(offsets[index]))
	output.append_array(document.bytecode)
	return output


func _validate_transport(value: Variant, path: String) -> Dictionary:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_PACKED_BYTE_ARRAY:
			return {"ok": true}
		TYPE_ARRAY:
			for index in range((value as Array).size()):
				var child := _validate_transport((value as Array)[index], "%s[%d]" % [path, index])
				if not child.get("ok", false):
					return child
			return {"ok": true}
		TYPE_DICTIONARY:
			var encoded_keys := {}
			for key in (value as Dictionary):
				var encoded_key := str(key)
				if encoded_keys.has(encoded_key):
					return _error("MES handoff dictionary key collision at %s." % path)
				encoded_keys[encoded_key] = true
				var child := _validate_transport(
					(value as Dictionary)[key], "%s.%s" % [path, encoded_key]
				)
				if not child.get("ok", false):
					return child
			return {"ok": true}
		_:
			return _error("MES handoff contains unsupported transport data at %s." % path)


func _normalize(value: Variant) -> Variant:
	match typeof(value):
		TYPE_PACKED_BYTE_ARRAY:
			return {"$packed_byte_array_hex": (value as PackedByteArray).hex_encode()}
		TYPE_ARRAY:
			var output: Array = []
			for child in value as Array:
				output.append(_normalize(child))
			return output
		TYPE_DICTIONARY:
			var dictionary: Dictionary = value
			var keys: Array[String] = []
			var value_by_key := {}
			for key in dictionary:
				var encoded_key := str(key)
				keys.append(encoded_key)
				value_by_key[encoded_key] = dictionary[key]
			keys.sort()
			var output := {}
			for key in keys:
				output[key] = _normalize(value_by_key[key])
			return output
		_:
			return value


func _find_product_ui_key(value: Variant) -> String:
	if value is Dictionary:
		for key in value:
			var encoded_key := str(key)
			if encoded_key in PRODUCT_UI_KEYS:
				return encoded_key
			var nested := _find_product_ui_key(value[key])
			if not nested.is_empty():
				return nested
	elif value is Array:
		for child in value:
			var nested := _find_product_ui_key(child)
			if not nested.is_empty():
				return nested
	return ""


func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message}
