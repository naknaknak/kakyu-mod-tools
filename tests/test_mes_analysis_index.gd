extends "res://tests/test_case.gd"

const MesContainerScript := preload("res://content_core/mes_container.gd")
const MesAnalysisScript := preload("res://content_core/mes_analysis_index.gd")
const AnalyzerHandoffScript := preload("res://content_core/mes_analyzer_handoff.gd")
const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")
const SyntheticArc := preload("res://tests/synthetic_arc.gd")
const MesRecordGrammar := preload("res://tests/mes_record_grammar.gd")


func _ready() -> void:
	var code := PackedByteArray()
	code.append_array(PackedByteArray([0x01]))
	code.append_array("HELLO".to_ascii_buffer())
	code.append(0)
	code.append_array(PackedByteArray([0x0B, 0xF3, 0x34, 0x12, 0xFF]))
	SyntheticArc.append_u32(code, 21)
	code.append(0x0C)
	SyntheticArc.append_u32(code, 21)
	code.append_array(PackedByteArray([0x82, 0xA0, 0x00]))
	code.append(0x0C)
	SyntheticArc.append_u32(code, 0)
	var mes := PackedByteArray()
	SyntheticArc.append_u32(mes, 2)
	SyntheticArc.append_u32(mes, 0)
	SyntheticArc.append_u32(mes, 21)
	mes.append_array(code)

	var document := MesContainerScript.new().parse(mes)
	var analysis := MesAnalysisScript.new().build(document)
	_check(analysis.ok, "MES structural analysis index builds")
	_check(analysis.schema == ContentCoreVersionScript.MES_ANALYSIS_SCHEMA, "MES analysis uses the current versioned projection schema")
	_check(analysis.complete and analysis.diagnostic_count == 0, "fully strict synthetic region has no boundary diagnostics")
	_check(analysis.instruction_count == 5, "MES analysis retains all strict instruction boundaries")
	_check(analysis.message_count == 2, "MES analysis indexes opcode and dispatcher text")
	_check(analysis.messages[0].raw_bytes == "HELLO".to_ascii_buffer(), "MES message index retains raw bytes")
	_check(analysis.messages[0].source_offset == 0 and analysis.messages[1].source_offset == 21, "MES message index uses code-relative instruction offsets")
	_check(
		not analysis.messages[0].native_stream_projection_match
		and analysis.messages[0].native_stream_probe.stop_reason == "single_byte_marker_deferred",
		"MES message index retains the EXE-matched boundary mismatch"
	)
	_check(
		analysis.messages[1].native_stream_projection_match
		and analysis.messages[1].native_stream_probe.stop_reason == "nul_consumed",
		"MES message index retains a matching native double-byte boundary"
	)
	_check(analysis.code_reference_count == 4, "MES analysis emits references across two address ranges")
	_check(_has_code_reference(analysis.code_references, 7, "condition_false_target", 21, true), "conditional false target is aligned")
	_check(_has_code_reference(analysis.code_references, 7, "condition_true_fallthrough", 16, true), "conditional fallthrough is aligned")
	_check(_has_code_reference(analysis.code_references, 16, "continuation_target", 21, true), "continuation target is aligned")
	_check(_has_code_reference(analysis.code_references, 24, "continuation_target", 0, true), "second range continuation returns to an aligned first-range instruction")
	_check(_has_state_reference(analysis.state_references, 7, "read", "global_u8", "4660"), "expression state read is indexed without assigning a symbolic meaning")
	var graph := MesAnalysisScript.new().build_reference_graph(analysis, 0, 21)
	_check(
		graph.ok
		and graph.schema == ContentCoreVersionScript.MES_REFERENCE_GRAPH_SCHEMA
		and graph.node_count == 3
		and graph.edge_count == 3,
		"versioned partial CFG contains only referenced instruction nodes and edges"
	)
	_check(_has_graph_edge(graph.edges, "condition_false_target", true), "partial CFG marks confirmed conditional flow")
	_check(_has_graph_edge(graph.edges, "continuation_target", true), "partial CFG marks confirmed continuation flow")
	_check(graph.expanded_region_count == 0, "partial CFG does not cross address ranges unless expansion is requested")
	var handoff_builder := AnalyzerHandoffScript.new()
	var call_evidence := [{
		"ok": true,
		"schema": ContentCoreVersionScript.MES_CALLER_ROUTE_SCHEMA,
		"source_offset": 7,
		"destination_offset": 21,
	}]
	var trace_evidence := [{
		"ok": true,
		"schema": ContentCoreVersionScript.MES_EVENT_TRACE_SCHEMA,
		"status": "analysis_boundary",
		"offset": 21,
		"trace": [],
	}]
	var handoff: Dictionary = handoff_builder.build(
		document, analysis, [graph], call_evidence, trace_evidence
	)
	var repeated_handoff: Dictionary = handoff_builder.build(
		document, analysis, [graph], call_evidence, trace_evidence
	)
	var handoff_json := handoff_builder.to_json(handoff)
	var parsed_handoff = JSON.parse_string(handoff_json)
	_check(
		handoff.get("ok", false)
		and handoff.schema == ContentCoreVersionScript.MES_ANALYZER_HANDOFF_SCHEMA
		and handoff.compatibility.component_schemas.container
		== ContentCoreVersionScript.MES_CONTAINER_SCHEMA
		and handoff.compatibility.component_schemas.instruction
		== ContentCoreVersionScript.MES_INSTRUCTION_SCHEMA
		and handoff.compatibility.component_schemas.reference_graph
		== ContentCoreVersionScript.MES_REFERENCE_GRAPH_SCHEMA
		and handoff.container.raw_hex == mes.hex_encode()
		and handoff.typed_ir.instructions.size() == analysis.instruction_count
		and handoff.references.messages.size() == analysis.message_count
		and handoff.cfg.size() == 1
		and handoff.calls.size() == 1
		and handoff.traces.size() == 1
		and handoff.capability_report.product_ui_data == "forbidden"
		and handoff_builder.verify(handoff).get("ok", false),
		"language-neutral Phase 1-4 handoff retains lossless container, typed IR, references, CFG, calls, and traces"
	)
	_check(
		handoff.payload_sha256 == repeated_handoff.payload_sha256
		and handoff_json == handoff_builder.to_json(repeated_handoff)
		and parsed_handoff is Dictionary
		and parsed_handoff.payload_sha256 == handoff.payload_sha256,
		"Phase 1-4 handoff serialization is deterministic and JSON-readable"
	)
	var changed_handoff: Dictionary = handoff.duplicate(true)
	changed_handoff.typed_ir.instructions[0].raw_hex = "00"
	_check(
		not handoff_builder.verify(changed_handoff).get("ok", false),
		"Phase 1-4 handoff rejects payload changes after fingerprinting"
	)
	var changed_graph: Dictionary = graph.duplicate(true)
	changed_graph.schema = "unsupported_graph/v1"
	_check(
		not handoff_builder.build(document, analysis, [changed_graph]).get("ok", false),
		"Phase 1-4 handoff rejects an unsupported CFG component schema"
	)
	var ui_trace: Dictionary = trace_evidence[0].duplicate(true)
	ui_trace["status_label"] = "product-only"
	_check(
		not handoff_builder.build(document, analysis, [], [], [ui_trace]).get("ok", false),
		"Phase 1-4 handoff rejects product UI fields from analyzer trace evidence"
	)
	var expanded_graph := MesAnalysisScript.new().build_reference_graph(analysis, 0, 21, 120, 1, 4)
	_check(expanded_graph.ok and expanded_graph.node_count == 5 and expanded_graph.edge_count == 4, "confirmed flow expands the partial CFG into a reached address range")
	_check(expanded_graph.expanded_region_count == 1 and expanded_graph.expanded_regions[0].region == "entry_0001", "expanded CFG reports the reached range and depth")
	_check(_has_graph_edge_from(expanded_graph.edges, 1, "continuation_target"), "expanded CFG retains outgoing flow from the reached range")
	var range_limited_graph := MesAnalysisScript.new().build_reference_graph(analysis, 0, 21, 120, 1, 0)
	_check(range_limited_graph.ok and range_limited_graph.truncated and range_limited_graph.skipped_expansion_regions == ["entry_0001"], "expanded CFG reports a reached range rejected by its range cap")
	var limited_graph := MesAnalysisScript.new().build_reference_graph(analysis, 0, 21, 2)
	_check(limited_graph.ok and limited_graph.truncated and limited_graph.node_count == 2, "partial CFG enforces its node limit visibly")
	var resource_analysis := MesAnalysisScript.new().build(
		MesContainerScript.new().parse(_resource_reference_mes())
	)
	_check(
		resource_analysis.ok and resource_analysis.complete and resource_analysis.resource_reference_count == 5,
		"MES analysis indexes only strict bounded resource marker instructions"
	)
	_check(
		_has_resource_reference(resource_analysis.resource_references, "mmo", "BACK.MMO", ["mmo.arc"])
		and _has_resource_reference(resource_analysis.resource_references, "ax", "BACK.AX", ["data.arc"])
		and _has_resource_reference(resource_analysis.resource_references, "voice", "D0001.OGG", ["voice.arc", "tina1.arc", "tina2.arc"])
		and _has_resource_reference(resource_analysis.resource_references, "mes_script", "LIBLARY.LIB", ["mes.arc"])
		and _has_resource_reference(resource_analysis.resource_references, "mes_script", "DEF_MAIN.MES", ["mes.arc"]),
		"MES resource references retain normalized names and bounded archive candidates"
	)
	var post_stop_analysis := MesAnalysisScript.new().build(
		MesContainerScript.new().parse(_post_stop_resource_mes())
	)
	_check(
		not post_stop_analysis.complete
		and post_stop_analysis.opaque_boundary_count == 1
		and post_stop_analysis.opaque_boundaries[0].source_offset == 0
		and post_stop_analysis.opaque_boundaries[0].end_offset == 23
		and post_stop_analysis.opaque_boundaries[0].boundary == "byte_preserving_fail_closed"
		and post_stop_analysis.opaque_boundaries[0].raw_hex == "0bff0d08ff0200ff017a6574612e6178000202f900ff00"
		and post_stop_analysis.resource_reference_count == 1
		and post_stop_analysis.resource_references[0].name == "ZETA.AX"
		and post_stop_analysis.resource_references[0].boundary == "bounded_envelope_scan",
		"MES analysis retains a byte-preserving opaque tail and labels resource evidence scanned inside it"
	)
	var structural_write_mes := PackedByteArray()
	SyntheticArc.append_u32(structural_write_mes, 1)
	SyntheticArc.append_u32(structural_write_mes, 0)
	structural_write_mes.append_array(PackedByteArray([
		0x04, 0xFF, 0x02, 0x01, 0xFF, 0x00,
		0x0C, 0x06, 0x00, 0x00, 0x00,
	]))
	var strict_write_analysis := MesAnalysisScript.new().build(
		MesContainerScript.new().parse(structural_write_mes)
	)
	var structural_write_analysis := MesAnalysisScript.new().build_structural(
		MesContainerScript.new().parse(structural_write_mes)
	)
	_check(
		not strict_write_analysis.complete
		and strict_write_analysis.opaque_boundary_count == 1,
		"strict MES analysis keeps a non-single-result write run fail-closed"
	)
	_check(
		structural_write_analysis.complete
		and structural_write_analysis.analysis_mode == "structural_relocation"
		and structural_write_analysis.expression_semantics == "strict_when_valid_otherwise_boundary_only"
		and structural_write_analysis.instruction_count == 2
		and structural_write_analysis.instructions[0].op == "state_u16_write_run"
		and structural_write_analysis.instructions[0].structural_only
		and structural_write_analysis.code_reference_count == 1
		and _has_code_reference(
			structural_write_analysis.code_references,
			6,
			"continuation_target",
			6,
			true
		),
		"structural relocation analysis retains exact boundaries and later control targets without claiming invalid expression semantics"
	)
	var structural_handoff := handoff_builder.build(
		MesContainerScript.new().parse(structural_write_mes),
		structural_write_analysis
	)
	_check(
		structural_handoff.ok
		and handoff_builder.verify(structural_handoff).ok
		and structural_handoff.typed_ir.analysis_mode == "structural_relocation"
		and structural_handoff.typed_ir.expression_semantics == "strict_when_valid_otherwise_boundary_only",
		"MES analyzer handoff preserves the explicit structural relocation evidence policy"
	)
	var empty_native_mes := PackedByteArray()
	SyntheticArc.append_u32(empty_native_mes, 1)
	SyntheticArc.append_u32(empty_native_mes, 0)
	empty_native_mes.append_array(PackedByteArray([0x01, 0xFF, 0x00]))
	var empty_native_analysis := MesAnalysisScript.new().build(
		MesContainerScript.new().parse(empty_native_mes)
	)
	_check(
		empty_native_analysis.ok
		and empty_native_analysis.message_count == 0
		and empty_native_analysis.instructions[0].op == "command_01",
		"MES analysis does not index an empty 01 FF native token as dialogue"
	)
	var shadow_stream_analysis := MesAnalysisScript.new().build(
		MesContainerScript.new().parse(_native_shadow_message_mes())
	)
	_check(
		shadow_stream_analysis.ok
		and shadow_stream_analysis.complete
		and shadow_stream_analysis.instruction_count == 2
		and shadow_stream_analysis.message_count == 1
		and shadow_stream_analysis.messages[0].source_offset == 9
		and shadow_stream_analysis.messages[0].raw_bytes == "REAL".to_ascii_buffer()
		and shadow_stream_analysis.instructions[0].native_payload_boundary == "bounded_byte_preserving_opaque_stream"
		and shadow_stream_analysis.instructions[0].native_payload_raw_hex == "0b02ff0101010100",
		"MES analysis excludes command-shaped text bytes owned by a bounded native payload"
	)
	get_tree().quit(1 if _failed else 0)


func _has_code_reference(references: Array, source: int, kind: String, target: int, aligned: bool) -> bool:
	for reference in references:
		if int(reference.source_offset) == source and reference.kind == kind and int(reference.target_offset) == target and bool(reference.aligned) == aligned:
			return true
	return false


func _has_state_reference(references: Array, source: int, access: String, storage: String, index: String) -> bool:
	for reference in references:
		if int(reference.source_offset) == source and reference.access == access and reference.storage == storage and reference.index == index:
			return true
	return false


func _has_resource_reference(references: Array, kind: String, resource_name: String, archives: Array) -> bool:
	var expected_native_semantics := "unresolved"
	if kind == "mmo":
		expected_native_semantics = "named_mmo_load_into_active_surface_confirmed"
	elif kind == "ax":
		expected_native_semantics = "data_arc_named_entry_load_confirmed"
	elif kind == "voice":
		expected_native_semantics = "presentation_queue_and_stream_handoff_confirmed"
	elif kind == "mes_script":
		expected_native_semantics = "archive_entry_load_inline_execute_restore_confirmed"
	for reference in references:
		if (
			str(reference.resource_kind) == kind
			and str(reference.name) == resource_name
			and reference.archive_candidates == archives
			and str(reference.boundary) == "strict_indexed"
			and str(reference.native_semantics) == expected_native_semantics
			and (kind != "mmo" or (
				int(reference.outer_command) == 0x0D
				and int(reference.presentation_subcommand) == 9
				and reference.native_default_origin_arguments == [-1, -1]
				and int(reference.native_active_surface_state_offset) == 0x20BA
				and str(reference.native_active_surface_storage) == "banked_u16"
				and int(reference.native_active_surface_bank) == 0
				and int(reference.native_active_surface_storage_index) == 1
				and str(reference.native_active_surface_identity) == "state_dependent"
			))
			and (kind != "voice" or (
				str(reference.native_audible_output) == "confirmed_directsound_play_dispatch"
				and str(reference.native_host_device_output) == "not_observed_by_static_audit"
			))
			and (kind != "ax" or (
				int(reference.presentation_subcommand) == 8
				and int(reference.execution_selector) == 0
				and int(reference.data_archive_index) == 0
				and str(reference.native_loader_argument) == "banked_i32[0][2]"
				and str(reference.native_loader_argument_semantics) == "engine_initialized_destination_buffer_pointer"
				and str(reference.native_payload_semantics) == "unresolved"
			))
			and (kind != "mes_script" or (
				int(reference.presentation_subcommand) == 8
				and int(reference.execution_selector) in [2, 3]
				and str(reference.native_context_restore) == "confirmed"
				and str(reference.tool_execution_semantics) == "not_executed"
			))
		):
			return true
	return false


func _has_graph_edge(edges: Array, kind: String, confirmed: bool) -> bool:
	for edge in edges:
		if edge.kind == kind and bool(edge.confirmed_flow) == confirmed:
			return true
	return false


func _has_graph_edge_from(edges: Array, source_depth: int, kind: String) -> bool:
	for edge in edges:
		if int(edge.source_depth) == source_depth and edge.kind == kind:
			return true
	return false


func _resource_reference_mes() -> PackedByteArray:
	var code := PackedByteArray([0x0D, 0x09, 0xFF, 0x01])
	code.append_array("BACK.MMO".to_ascii_buffer())
	code.append_array(PackedByteArray([0x00, 0x00, 0x07, 0x01, 0xFF, 0x00, 0x07, 0xFF, 0x00]))
	code.append_array(PackedByteArray([0x0D, 0x08, 0xFF, 0x02, 0x00, 0xFF, 0x01]))
	code.append_array("back.ax".to_ascii_buffer())
	code.append_array(PackedByteArray([0x00, 0x02, 0x02, 0xF9, 0x00, 0xFF, 0x00]))
	code.append_array(PackedByteArray([0x07, 0x02, 0xFF, 0x00, 0x02, 0xA0, 0x00, 0xF1, 0x80, 0x00, 0xE9, 0xFF, 0x00, 0x0D]))
	code.append_array(PackedByteArray([0x07, 0xFF, 0x02, 0x02, 0xFF, 0x01]))
	code.append_array("d0001.ogg".to_ascii_buffer())
	code.append_array(PackedByteArray([0x00, 0x02, 0x00, 0xFF, 0x00]))
	code.append_array(PackedByteArray([0x07, 0x02, 0xFF, 0x00, 0x02, 0xA0, 0x00, 0xF1, 0x7F, 0xFF, 0xE8, 0xFF, 0x00, 0x00]))
	code.resize(code.size() - 1)
	code.append_array(PackedByteArray([0x0D, 0x08, 0xFF, 0x02, 0x02, 0xFF, 0x01]))
	code.append_array("liblary.lib".to_ascii_buffer())
	code.append_array(MesRecordGrammar.name_end_and_record_list_end())
	code.append_array(MesRecordGrammar.resource_marker_head(3))
	code.append_array("def_main.mes".to_ascii_buffer())
	code.append_array(PackedByteArray([0x00, 0x00, 0x00]))
	var mes := PackedByteArray()
	SyntheticArc.append_u32(mes, 1)
	SyntheticArc.append_u32(mes, 0)
	mes.append_array(code)
	return mes


func _post_stop_resource_mes() -> PackedByteArray:
	var code := PackedByteArray([0x0B, 0xFF, 0x0D, 0x08, 0xFF, 0x02, 0x00, 0xFF, 0x01])
	code.append_array("zeta.ax".to_ascii_buffer())
	code.append_array(PackedByteArray([0x00, 0x02, 0x02, 0xF9, 0x00, 0xFF, 0x00]))
	var mes := PackedByteArray()
	SyntheticArc.append_u32(mes, 1)
	SyntheticArc.append_u32(mes, 0)
	mes.append_array(code)
	return mes


func _native_shadow_message_mes() -> PackedByteArray:
	var code := PackedByteArray([
		0x0D,
		0x0B, 0x02, 0xFF, 0x01, 0x01, 0x01, 0x01,
		0x00,
		0x01,
	])
	code.append_array("REAL".to_ascii_buffer())
	code.append(0x00)
	var mes := PackedByteArray()
	SyntheticArc.append_u32(mes, 1)
	SyntheticArc.append_u32(mes, 0)
	mes.append_array(code)
	return mes
