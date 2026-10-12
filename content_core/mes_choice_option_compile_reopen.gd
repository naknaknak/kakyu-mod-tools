class_name KakyuMesChoiceOptionCompileReopen
extends RefCounted

const ArcReaderScript := preload("res://content_core/arc_reader.gd")
const MesContainerScript := preload("res://content_core/mes_container.gd")
const MesAnalysisScript := preload("res://content_core/mes_analysis_index.gd")
const MesDecoderScript := preload("res://content_core/mes_instruction_decoder.gd")
const AnalyzerHandoffScript := preload("res://content_core/mes_analyzer_handoff.gd")
const FingerprintScript := preload("res://content_core/mes_payload_fingerprint.gd")
const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")
const ContractValues := preload("res://content_core/contract_values.gd")

const AUDIT_KEYS := [
	"ok", "schema", "producer", "compatibility", "source_identity", "inputs",
	"source", "output", "patch", "retained_contract", "invariants",
	"payload_sha256",
]
const SUMMARY_KEYS := [
	"size", "entry_count", "code_offset", "code_size", "entry_sha256",
	"bytecode_sha256", "address_table_sha256", "choice_proof_sha256",
]
const PATCH_KEYS := [
	"group_selector", "definition_id", "code_start", "code_end",
	"absolute_start", "absolute_end", "payload_size", "source_payload_sha256",
	"replacement_payload_sha256", "source_instruction_sha256",
	"replacement_instruction_sha256", "source_body_sha256",
	"replacement_body_sha256", "byte_delta",
]
const RETAINED_KEYS := [
	"address_entry_index", "address_entry_start", "address_entry_end",
	"source_structure_sha256", "output_structure_sha256",
	"result_mapping_sha256", "terminal_start", "terminal_end",
	"terminal_raw_sha256", "physical_resume_start", "physical_resume_end",
	"physical_resume_raw_sha256", "source_prefix_sha256",
	"source_suffix_sha256", "unchanged_definition_count",
]
const SOURCE_IDENTITY_KEYS := ["archive", "archive_sha256", "entry", "entry_sha256"]
const COMPATIBILITY := {
	"policy": "exact_same_length_choice_option_plan_only",
	"input_plan_schema": "kakyu_mes_choice_option_edit_plan/v1",
	"input_choice_proof_schema": "kakyu_mes_choice_group_authoring_proof/v1",
	"output_choice_proof_schema": "kakyu_mes_choice_group_authoring_proof/v1",
	"output_policy": "new_file_only",
	"relocation": "forbidden_zero_delta_only",
	"native_engine_compatibility": "unverified",
	"native_input_and_gameplay_labels": "unresolved",
	"unknown_audit_schema": "reject",
	"unknown_v1_field": "reject",
}
const INVARIANTS := {
	"plan_ready": true,
	"source_choice_proof_rebuilt": true,
	"output_choice_proof_rebuilt": true,
	"container_size_preserved": true,
	"entry_count_preserved": true,
	"code_offset_preserved": true,
	"code_size_preserved": true,
	"address_table_preserved": true,
	"address_entry_boundary_preserved": true,
	"group_and_definition_coordinates_preserved": true,
	"result_mapping_preserved": true,
	"routine40_terminal_and_physical_resume_preserved": true,
	"registration_and_return_preserved": true,
	"replacement_payload_exact": true,
	"code_prefix_preserved": true,
	"code_suffix_preserved": true,
	"only_selected_payload_changed": true,
	"source_container_not_modified": true,
}


func audit(payload: PackedByteArray, compile_audit: Dictionary) -> Dictionary:
	var validation := validate_compile_audit(compile_audit)
	if not validation.ok:
		return validation
	var output_row: Dictionary = compile_audit.output
	if payload.size() != int(output_row.size) or ContractValues.sha256_lenient(payload) != str(output_row.entry_sha256):
		return _error("Compiled MES bytes do not match their choice-option audit.")
	var source_identity: Dictionary = compile_audit.source_identity.duplicate(true)
	var document := MesContainerScript.new().parse(payload, source_identity)
	if not document.get("ok", false):
		return _error("Compiled choice-option MES did not reopen: %s" % document.get("error", "failed"))
	var code_offset := int(document.header.code_offset)
	var address_table := payload.slice(4, code_offset)
	if (
		int(document.header.entry_count) != int(output_row.entry_count)
		or code_offset != int(output_row.code_offset)
		or int(document.header.code_size) != int(output_row.code_size)
		or str(document.entry_sha256) != str(output_row.entry_sha256)
		or str(document.bytecode_sha256) != str(output_row.bytecode_sha256)
		or ContractValues.sha256_lenient(address_table) != str(output_row.address_table_sha256)
	):
		return _error("GDScript container reopen differs from the choice-option audit.")
	var analysis := MesAnalysisScript.new().build(document)
	if not analysis.get("ok", false):
		return _error("Compiled choice-option MES Phase 1-4 analysis failed.")
	var handoff_builder := AnalyzerHandoffScript.new()
	var handoff := handoff_builder.build(document, analysis)
	var verified: Dictionary = handoff_builder.verify(handoff)
	if not verified.get("ok", false):
		return _error("Compiled choice-option MES handoff failed: %s" % verified.get(
			"error", handoff.get("error", "failed")
		))
	var handoff_identity := source_identity.duplicate(true)
	handoff_identity.erase("entry_sha256")
	if handoff.source_identity != handoff_identity:
		return _error("Compiled choice-option MES source identity changed during reopen.")
	var edited := _find_edited_option(document.bytecode, analysis, compile_audit)
	if not edited.ok:
		return edited
	var retained_partitions := _find_retained_partitions(
		document.bytecode, analysis, compile_audit.retained_contract
	)
	if not retained_partitions.ok:
		return retained_partitions
	var alignment: Dictionary = handoff.record_alignment
	var typed_count := int((handoff.typed_ir.instructions as Array).size())
	var opaque_count := int((handoff.typed_ir.opaque_boundaries as Array).size())
	var result := {
		"ok": true,
		"schema": ContentCoreVersionScript.MES_CHOICE_OPTION_REOPEN_AUDIT_SCHEMA,
		"producer": {
			"implementation": "godot_gdscript_phase1_4_choice_option_reopen",
			"contract": ContentCoreVersionScript.MES_CHOICE_OPTION_REOPEN_AUDIT_SCHEMA,
		},
		"compatibility": {
			"policy": "exact_choice_option_compile_audit_and_current_phase1_4_schemas",
			"input_compile_audit_schema": ContentCoreVersionScript.MES_CHOICE_OPTION_COMPILE_AUDIT_SCHEMA,
			"container_schema": ContentCoreVersionScript.MES_CONTAINER_SCHEMA,
			"analysis_schema": ContentCoreVersionScript.MES_ANALYSIS_SCHEMA,
			"record_alignment_schema": ContentCoreVersionScript.MES_RECORD_ALIGNMENT_AUDIT_SCHEMA,
			"analyzer_handoff_schema": ContentCoreVersionScript.MES_ANALYZER_HANDOFF_SCHEMA,
		},
		"source_identity": source_identity,
		"compile_audit_sha256": str(compile_audit.payload_sha256),
		"output": output_row.duplicate(true),
		"edited_option": edited.option,
		"retained_contract": retained_partitions.contract,
		"phase1_4": {
			"handoff_sha256": str(handoff.payload_sha256),
			"analysis_complete": bool(analysis.complete),
			"analysis_diagnostic_count": int(analysis.diagnostic_count),
			"alignment_failure_count": int(alignment.failure_count),
		},
		"coverage": {
			"region_count": int(alignment.region_count),
			"node_count": typed_count + opaque_count,
			"typed_node_count": typed_count,
			"opaque_node_count": opaque_count,
			"code_bytes": int(document.header.code_size),
		},
		"invariants": {
			"compile_audit_fingerprint_valid": true,
			"output_hashes_match": true,
			"container_reopened": true,
			"analysis_rebuilt": true,
			"alignment_rebuilt": true,
			"handoff_rebuilt_and_verified": true,
			"replacement_message_redecoded": true,
			"replacement_body_and_return_redecoded": true,
			"routine40_terminal_partition_preserved": true,
			"physical_resume_partition_preserved": true,
			"group_result_structure_hashes_retained": true,
		},
	}
	result["payload_sha256"] = fingerprint(result)
	return result


func validate_compile_audit(document: Dictionary) -> Dictionary:
	if (
		document.get("ok") != true
		or str(document.get("schema", ""))
		!= ContentCoreVersionScript.MES_CHOICE_OPTION_COMPILE_AUDIT_SCHEMA
		or not ContractValues.has_exact_keys(document, AUDIT_KEYS)
	):
		return _error("MES choice-option compile audit schema or fields changed.")
	if document.get("producer") != {
		"implementation": "python_phase6_choice_option_compiler",
		"contract": ContentCoreVersionScript.MES_CHOICE_OPTION_COMPILE_AUDIT_SCHEMA,
	}:
		return _error("MES choice-option compile audit producer changed.")
	if document.get("compatibility") != COMPATIBILITY:
		return _error("MES choice-option compile compatibility changed.")
	var retained_hash := str(document.get("payload_sha256", ""))
	if not ContractValues.is_sha256(retained_hash) or fingerprint(document) != retained_hash:
		return _error("MES choice-option compile audit fingerprint changed.")
	var source_identity = document.get("source_identity")
	if (
		not source_identity is Dictionary
		or not ContractValues.has_exact_keys(source_identity, SOURCE_IDENTITY_KEYS)
		or not ArcReaderScript.is_safe_entry_name(str(source_identity.get("entry", "")))
		or str(source_identity.get("archive", "")).is_empty()
		or not ContractValues.hash_values(source_identity, ["archive_sha256", "entry_sha256"])
	):
		return _error("MES choice-option compile source identity changed.")
	var inputs = document.get("inputs")
	if (
		not inputs is Dictionary
		or not ContractValues.has_exact_keys(inputs, ["choice_proof_sha256", "choice_option_plan_sha256"])
		or not ContractValues.hash_values(inputs, inputs.keys())
	):
		return _error("MES choice-option compile input identity changed.")
	var source = document.get("source")
	var output = document.get("output")
	if not _valid_summary(source) or not _valid_summary(output):
		return _error("MES choice-option compile container summary changed.")
	if (
		int(source.size) != int(output.size)
		or int(source.entry_count) != int(output.entry_count)
		or int(source.code_offset) != int(output.code_offset)
		or int(source.code_size) != int(output.code_size)
		or str(source.address_table_sha256) != str(output.address_table_sha256)
	):
		return _error("MES choice-option compile layout preservation changed.")
	var patch = document.get("patch")
	if not _valid_patch(patch, source):
		return _error("MES choice-option compile patch changed.")
	var retained = document.get("retained_contract")
	if not _valid_retained(retained, source):
		return _error("MES choice-option compile retained contract changed.")
	if document.get("invariants") != INVARIANTS:
		return _error("MES choice-option compile invariants changed.")
	return {
		"ok": true,
		"schema": ContentCoreVersionScript.MES_CHOICE_OPTION_COMPILE_AUDIT_SCHEMA,
		"payload_sha256": retained_hash,
	}


func fingerprint(document: Dictionary) -> String:
	return FingerprintScript.new().fingerprint(document)


func _find_edited_option(
	code: PackedByteArray,
	analysis: Dictionary,
	compile_audit: Dictionary
) -> Dictionary:
	var patch: Dictionary = compile_audit.patch
	var payload_start := int(patch.code_start)
	var payload_end := int(patch.code_end)
	var instruction_start := payload_start - 1
	var instruction_end := payload_end + 1
	var return_start := instruction_end
	var return_end := return_start + 1
	if instruction_start < 0 or return_end > code.size():
		return _error("Compiled choice-option range is outside the code.")
	var instruction := MesDecoderScript.new().decode_at(code, instruction_start, instruction_end)
	if (
		not instruction.get("ok", false)
		or str(instruction.get("op", "")) != "text"
		or int(instruction.get("command_id", -1)) != 0x01
		or int(instruction.get("end_offset", -1)) != instruction_end
		or ContractValues.sha256_lenient(code.slice(instruction_start, instruction_end))
		!= str(patch.replacement_instruction_sha256)
		or ContractValues.sha256_lenient(code.slice(payload_start, payload_end))
		!= str(patch.replacement_payload_sha256)
		or ContractValues.sha256_lenient(code.slice(instruction_start, return_end))
		!= str(patch.replacement_body_sha256)
	):
		return _error("Compiled MES choice option was not exactly redecoded.")
	var return_instruction := MesDecoderScript.new().decode_at(code, return_start, return_end)
	if (
		not return_instruction.get("ok", false)
		or int(return_instruction.get("command_id", -1)) != 0
		or int(return_instruction.get("end_offset", -1)) != return_end
	):
		return _error("Compiled MES choice-option return was not redecoded.")
	var matches := 0
	for untyped_row in analysis.instructions:
		var row: Dictionary = untyped_row
		if int(row.get("source_offset", -1)) == instruction_start and int(row.get("end_offset", -1)) == instruction_end:
			matches += 1
	if matches != 1:
		return _error("Compiled MES choice-option partition was not preserved.")
	return {
		"ok": true,
		"option": {
			"group_selector": int(patch.group_selector),
			"definition_id": int(patch.definition_id),
			"instruction_start": instruction_start,
			"instruction_end": instruction_end,
			"instruction_sha256": str(patch.replacement_instruction_sha256),
			"payload_start": payload_start,
			"payload_end": payload_end,
			"payload_size": int(patch.payload_size),
			"payload_sha256": str(patch.replacement_payload_sha256),
			"return_start": return_start,
			"return_end": return_end,
			"body_sha256": str(patch.replacement_body_sha256),
		},
	}


func _find_retained_partitions(
	code: PackedByteArray,
	analysis: Dictionary,
	retained: Dictionary
) -> Dictionary:
	var terminal_start := int(retained.terminal_start)
	var terminal_end := int(retained.terminal_end)
	var resume_start := int(retained.physical_resume_start)
	var resume_end := int(retained.physical_resume_end)
	if (
		terminal_start < 0 or terminal_end > code.size()
		or resume_start != terminal_end or resume_end > code.size()
		or ContractValues.sha256_lenient(code.slice(terminal_start, terminal_end))
		!= str(retained.terminal_raw_sha256)
		or ContractValues.sha256_lenient(code.slice(resume_start, resume_end))
		!= str(retained.physical_resume_raw_sha256)
	):
		return _error("Compiled MES choice-option terminal/resume bytes changed.")
	var terminal_matches := _partition_matches(analysis, terminal_start, terminal_end)
	var resume_matches := _partition_matches(analysis, resume_start, resume_end)
	if terminal_matches != 1 or resume_matches != 1:
		return _error("Compiled MES choice-option terminal/resume partition changed.")
	return {
		"ok": true,
		"contract": {
			"address_entry_index": int(retained.address_entry_index),
			"address_entry_start": int(retained.address_entry_start),
			"address_entry_end": int(retained.address_entry_end),
			"structure_sha256": str(retained.output_structure_sha256),
			"result_mapping_sha256": str(retained.result_mapping_sha256),
			"terminal_start": terminal_start,
			"terminal_end": terminal_end,
			"terminal_sha256": str(retained.terminal_raw_sha256),
			"physical_resume_start": resume_start,
			"physical_resume_end": resume_end,
			"physical_resume_sha256": str(retained.physical_resume_raw_sha256),
			"unchanged_definition_count": int(retained.unchanged_definition_count),
		},
	}


func _partition_matches(analysis: Dictionary, start: int, end: int) -> int:
	var matches := 0
	for rows in [analysis.instructions, analysis.get("opaque_boundaries", [])]:
		for untyped_row in rows:
			var row: Dictionary = untyped_row
			if int(row.get("source_offset", -1)) == start and int(row.get("end_offset", -1)) == end:
				matches += 1
	return matches


func _valid_summary(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	var row: Dictionary = value
	return (
		ContractValues.has_exact_keys(row, SUMMARY_KEYS)
		and _integer_values(row, ["size", "entry_count", "code_offset", "code_size"])
		and int(row.size) == int(row.code_offset) + int(row.code_size)
		and ContractValues.hash_values(row, [
			"entry_sha256", "bytecode_sha256", "address_table_sha256",
			"choice_proof_sha256",
		])
	)


func _valid_patch(value: Variant, source: Dictionary) -> bool:
	if not value is Dictionary:
		return false
	var patch: Dictionary = value
	return (
		ContractValues.has_exact_keys(patch, PATCH_KEYS)
		and _integer_values(patch, [
			"group_selector", "definition_id", "code_start", "code_end",
			"absolute_start", "absolute_end", "payload_size", "byte_delta",
		])
		and ContractValues.hash_values(patch, [
			"source_payload_sha256", "replacement_payload_sha256",
			"source_instruction_sha256", "replacement_instruction_sha256",
			"source_body_sha256", "replacement_body_sha256",
		])
		and int(patch.byte_delta) == 0
		and int(patch.code_end) - int(patch.code_start) == int(patch.payload_size)
		and int(patch.absolute_start) == int(source.code_offset) + int(patch.code_start)
		and int(patch.absolute_end) == int(source.code_offset) + int(patch.code_end)
	)


func _valid_retained(value: Variant, source: Dictionary) -> bool:
	if not value is Dictionary:
		return false
	var retained: Dictionary = value
	return (
		ContractValues.has_exact_keys(retained, RETAINED_KEYS)
		and _integer_values(retained, [
			"address_entry_index", "address_entry_start", "address_entry_end",
			"terminal_start", "terminal_end", "physical_resume_start",
			"physical_resume_end", "unchanged_definition_count",
		])
		and ContractValues.hash_values(retained, [
			"source_structure_sha256", "output_structure_sha256",
			"result_mapping_sha256", "terminal_raw_sha256",
			"physical_resume_raw_sha256", "source_prefix_sha256",
			"source_suffix_sha256",
		])
		and str(retained.source_structure_sha256) == str(retained.output_structure_sha256)
		and int(retained.address_entry_end) > int(retained.address_entry_start)
		and int(retained.address_entry_end) <= int(source.code_size)
		and int(retained.terminal_end) > int(retained.terminal_start)
		and int(retained.terminal_end) == int(retained.physical_resume_start)
		and int(retained.physical_resume_end) > int(retained.physical_resume_start)
	)


func _integer_values(document: Dictionary, keys: Array) -> bool:
	for key in keys:
		if not _nonnegative_json_integer(document.get(key, -1)):
			return false
	return true


func _nonnegative_json_integer(value: Variant) -> bool:
	return (
		(value is int and int(value) >= 0)
		or (value is float and is_finite(value) and float(value) >= 0.0 and float(value) == floor(float(value)))
	)


func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message}
