extends "res://tools/content_suite/cli_script.gd"

const ArcReaderScript := preload("res://content_core/arc_reader.gd")
const MesContainerScript := preload("res://content_core/mes_container.gd")
const MesAnalysisScript := preload("res://content_core/mes_analysis_index.gd")
const AnalyzerHandoffScript := preload("res://content_core/mes_analyzer_handoff.gd")
const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")
const ContractValues := preload("res://content_core/contract_values.gd")

const ARCHIVE_SHA256 := "31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6"
const EXPECTED_CORPUS_FINGERPRINT := "74f1408836440b7194ffb25aaa498aa8b61bda695326ed148ccd35a562a1dff8"


func _init() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() < 1 or arguments.size() > 2:
		_fail("Usage: audit_mes_analyzer_handoff_corpus.gd <mes.arc> [completion.json]", 2)
		return
	var reader := ArcReaderScript.new()
	if not reader.open(arguments[0]):
		_fail(reader.last_error)
		return
	var source_archive_sha := reader.get_archive_fingerprint()
	if source_archive_sha != ARCHIVE_SHA256:
		reader.close()
		_fail("Authoritative mes.arc fingerprint changed.")
		return
	var parser := MesContainerScript.new()
	var analysis_builder := MesAnalysisScript.new()
	var handoff_builder := AnalyzerHandoffScript.new()
	var failures: Array[String] = []
	var entry_count := 0
	var code_bytes := 0
	var analysis_instructions := 0
	var analysis_messages := 0
	var analysis_code_references := 0
	var analysis_state_references := 0
	var analysis_resource_references := 0
	var analysis_diagnostics := 0
	var analysis_opaque_boundaries := 0
	var analysis_opaque_bytes := 0
	var alignment_instructions := 0
	var alignment_compound_records := 0
	var alignment_opaque_boundaries := 0
	var alignment_opaque_bytes := 0
	var instruction_ops := {}
	var compound_families := {}
	var code_reference_kinds := {}
	var resource_reference_kinds := {}
	var corpus_fingerprint_input := PackedByteArray()
	for untyped_entry in reader.get_entries():
		var entry: Dictionary = untyped_entry
		if str(entry.name).get_extension().to_lower() not in ["mes", "lib"]:
			continue
		entry_count += 1
		var document := parser.parse(reader.read_entry(str(entry.name)), {
			"archive": reader.archive_path.replace("\\", "/").get_file(),
			"entry": str(entry.name),
			"archive_sha256": source_archive_sha,
		})
		if not document.get("ok", false):
			failures.append("%s container: %s" % [entry.name, document.get("error", "failed")])
			continue
		var analysis := analysis_builder.build(document)
		var handoff := handoff_builder.build(document, analysis)
		var verified := handoff_builder.verify(handoff)
		if not verified.get("ok", false):
			failures.append("%s handoff: %s" % [entry.name, verified.get("error", handoff.get("error", "failed"))])
			continue
		var alignment: Dictionary = handoff.record_alignment
		var capability: Dictionary = handoff.capability_report
		code_bytes += int(handoff.container.header.code_size)
		analysis_instructions += int((handoff.typed_ir.instructions as Array).size())
		analysis_messages += int((handoff.references.messages as Array).size())
		analysis_code_references += int((handoff.references.code as Array).size())
		analysis_state_references += int((handoff.references.state as Array).size())
		analysis_resource_references += int((handoff.references.resources as Array).size())
		analysis_diagnostics += int((handoff.typed_ir.diagnostics as Array).size())
		analysis_opaque_boundaries += int((handoff.typed_ir.opaque_boundaries as Array).size())
		analysis_opaque_bytes += _sum_field(handoff.typed_ir.opaque_boundaries, "byte_length")
		alignment_instructions += int(alignment.instruction_count)
		alignment_compound_records += int(alignment.compound_record_count)
		alignment_opaque_boundaries += int(alignment.opaque_boundary_count)
		alignment_opaque_bytes += int(alignment.opaque_bytes)
		_merge_counts(instruction_ops, capability.typed_instruction_ops)
		_merge_counts(compound_families, capability.compound_record_families)
		_merge_counts(code_reference_kinds, capability.code_reference_kinds)
		_merge_counts(resource_reference_kinds, capability.resource_reference_kinds)
		corpus_fingerprint_input.append_array(
			("%s\t%s\t%s\n" % [
				str(entry.name),
				str(handoff.container.entry_sha256),
				str(handoff.payload_sha256),
			]).to_utf8_buffer()
		)
		if entry_count % 100 == 0:
			print("MES_ANALYZER_HANDOFF_PROGRESS entries=%d" % entry_count)
	var corpus_fingerprint := ContractValues.sha256(corpus_fingerprint_input)
	if (
		not EXPECTED_CORPUS_FINGERPRINT.is_empty()
		and corpus_fingerprint != EXPECTED_CORPUS_FINGERPRINT
	):
		failures.append("Archive-wide analyzer handoff fingerprint changed.")
	if reader.get_archive_fingerprint() != source_archive_sha:
		failures.append("Source mes.arc changed during analyzer handoff audit.")
	var completion_report := {
		"schema": ContentCoreVersionScript.MES_ANALYZER_COMPLETION_SCHEMA,
		"handoff_schema": ContentCoreVersionScript.MES_ANALYZER_HANDOFF_SCHEMA,
		"component_schemas": {
			"container": ContentCoreVersionScript.MES_CONTAINER_SCHEMA,
			"instruction": ContentCoreVersionScript.MES_INSTRUCTION_SCHEMA,
			"analysis": ContentCoreVersionScript.MES_ANALYSIS_SCHEMA,
			"record_alignment": ContentCoreVersionScript.MES_RECORD_ALIGNMENT_AUDIT_SCHEMA,
			"reference_graph": ContentCoreVersionScript.MES_REFERENCE_GRAPH_SCHEMA,
		},
		"source_archive_sha256": source_archive_sha,
		"corpus_handoff_sha256": corpus_fingerprint,
		"phase_status": {
			"1": "closed",
			"2": "closed",
			"3": "closed",
			"4": "closed",
		},
		"counts": {
			"entries": entry_count,
			"code_bytes": code_bytes,
			"analysis_instructions": analysis_instructions,
			"messages": analysis_messages,
			"code_references": analysis_code_references,
			"state_references": analysis_state_references,
			"resource_references": analysis_resource_references,
			"analysis_diagnostics": analysis_diagnostics,
			"analysis_opaque_boundaries": analysis_opaque_boundaries,
			"analysis_opaque_bytes": analysis_opaque_bytes,
			"alignment_instructions": alignment_instructions,
			"alignment_compound_records": alignment_compound_records,
			"alignment_opaque_boundaries": alignment_opaque_boundaries,
			"alignment_opaque_bytes": alignment_opaque_bytes,
		},
		"supported_typed_forms": instruction_ops,
		"explicit_native_boundaries": compound_families,
		"code_reference_kinds": code_reference_kinds,
		"resource_reference_kinds": resource_reference_kinds,
		"explicit_opaque_boundaries": {
			"strict_analysis_opaque_region_tail": {
				"count": analysis_opaque_boundaries,
				"bytes": analysis_opaque_bytes,
				"policy": "byte_preserving_fail_closed",
			},
			"structural_alignment_opaque_region_tail": {
				"count": alignment_opaque_boundaries,
				"bytes": alignment_opaque_bytes,
				"policy": "byte_preserving_fail_closed",
			},
		},
		"remaining_numeric_or_unresolved_meanings": [
			"state_and_bank_indices",
			"native_selector_arguments",
			"choice_and_routine_results_without_source_qualified_labels",
			"native_pixel_audio_and_input_effects",
			"outer_host_handoff_consumers",
		],
		"compatibility_policy": "exact_handoff_and_component_schema_match",
		"phase5_default_consumer": "python_offline_decompiler",
		"godot_role": "gdscript_phase1_4_producer_and_runtime_validator",
		"product_ui_data": "forbidden",
		"source_mutation": "forbidden",
	}
	completion_report["payload_sha256"] = ContractValues.sha256(
		JSON.stringify(completion_report, "", true, true).to_utf8_buffer()
	)
	if arguments.size() == 2 and failures.is_empty():
		var output_path := ProjectSettings.globalize_path(arguments[1]).simplify_path()
		var source_path := ProjectSettings.globalize_path(arguments[0]).simplify_path()
		if output_path.get_base_dir().to_lower() == source_path.get_base_dir().to_lower():
			failures.append("Completion output must be outside the source archive directory.")
		else:
			var output := FileAccess.open(output_path, FileAccess.WRITE)
			if output == null:
				failures.append("Could not open completion report: %s" % FileAccess.get_open_error())
			else:
				output.store_string(JSON.stringify(completion_report, "", true, true) + "\n")
				output.close()
	reader.close()
	print(
		"MES_ANALYZER_HANDOFF_CORPUS schema=%s entries=%d code_bytes=%d analysis_instructions=%d messages=%d code_refs=%d state_refs=%d resource_refs=%d diagnostics=%d analysis_opaque=%d/%d alignment_instructions=%d compound_records=%d alignment_opaque=%d/%d corpus_sha256=%s source_unchanged=%s failures=%d"
		% [
			ContentCoreVersionScript.MES_ANALYZER_HANDOFF_SCHEMA,
			entry_count,
			code_bytes,
			analysis_instructions,
			analysis_messages,
			analysis_code_references,
			analysis_state_references,
			analysis_resource_references,
			analysis_diagnostics,
			analysis_opaque_boundaries,
			analysis_opaque_bytes,
			alignment_instructions,
			alignment_compound_records,
			alignment_opaque_boundaries,
			alignment_opaque_bytes,
			corpus_fingerprint,
			str(failures.find("Source mes.arc changed during analyzer handoff audit.") < 0),
			failures.size(),
		]
	)
	print("MES_ANALYZER_HANDOFF_OPS ", _format_counts(instruction_ops))
	print("MES_ANALYZER_HANDOFF_COMPOUND ", _format_counts(compound_families))
	print("MES_ANALYZER_HANDOFF_CODE_REFS ", _format_counts(code_reference_kinds))
	print("MES_ANALYZER_HANDOFF_RESOURCE_REFS ", _format_counts(resource_reference_kinds))
	if failures.is_empty():
		print("MES_ANALYZER_COMPLETION schema=%s payload_sha256=%s phase1_4=closed" % [
			str(completion_report.schema), str(completion_report.payload_sha256),
		])
	else:
		print("MES_ANALYZER_COMPLETION schema=%s status=failed failures=%d" % [
			str(completion_report.schema), failures.size(),
		])
	for failure in failures:
		push_error(failure)
	quit(1 if not failures.is_empty() else 0)


func _sum_field(rows: Array, field: String) -> int:
	var total := 0
	for untyped_row in rows:
		total += int((untyped_row as Dictionary).get(field, 0))
	return total


func _merge_counts(target: Dictionary, source: Dictionary) -> void:
	for key in source:
		target[str(key)] = int(target.get(str(key), 0)) + int(source[key])


func _format_counts(counts: Dictionary) -> String:
	var keys: Array[String] = []
	for key in counts:
		keys.append(str(key))
	keys.sort()
	var labels: Array[String] = []
	for key in keys:
		labels.append("%s:%d" % [key, int(counts[key])])
	return ",".join(labels) if not labels.is_empty() else "none"
