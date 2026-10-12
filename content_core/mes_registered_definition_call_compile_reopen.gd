class_name KakyuMesRegisteredDefinitionCallCompileReopen
extends RefCounted

const CompileCoverageScript := preload("res://content_core/mes_compile_coverage.gd")

const ArcReaderScript := preload("res://content_core/arc_reader.gd")
const MesContainerScript := preload("res://content_core/mes_container.gd")
const MesAnalysisScript := preload("res://content_core/mes_analysis_index.gd")
const MesDecoderScript := preload("res://content_core/mes_instruction_decoder.gd")
const AnalyzerHandoffScript := preload("res://content_core/mes_analyzer_handoff.gd")
const FingerprintScript := preload("res://content_core/mes_payload_fingerprint.gd")
const PlanScript := preload("res://content_core/mes_registered_definition_call_edit_plan.gd")
const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")
const ContractValues := preload("res://content_core/contract_values.gd")

const AUDIT_KEYS := [
	"ok", "schema", "producer", "compatibility", "source_identity",
	"registry_identity", "inputs", "source", "output", "operation", "target",
	"coverage", "invariants", "payload_sha256",
]
const SUMMARY_KEYS := [
	"size", "entry_count", "code_offset", "code_size", "entry_sha256",
	"bytecode_sha256", "preamble_sha256", "address_table_sha256",
]
const OPERATION_KEYS := [
	"kind", "source_offset", "source_selector", "replacement_selector",
	"width", "physical_resume_offset",
]
const TARGET_KEYS := [
	"node_id", "region_id", "instruction_start", "instruction_end",
	"literal_start", "literal_end", "resume_node_id", "resume_region_id",
	"resume_start", "resume_end", "resume_raw_sha256",
	"source_instruction_sha256", "replacement_instruction_sha256",
	"source_expression_sha256", "replacement_expression_sha256",
	"source_literal_sha256", "replacement_literal_sha256", "call_proof",
	"source_registry_binding", "replacement_registry_binding",
]
const COVERAGE_KEYS := [
	"region_count", "node_count", "typed_node_count", "opaque_node_count", "code_bytes",
]
const INVARIANT_KEYS := [
	"plan_ready", "output_reopened", "container_size_preserved",
	"entry_count_preserved", "code_offset_preserved", "code_size_preserved",
	"address_table_preserved", "preamble_preserved", "code_prefix_preserved",
	"replacement_instruction_exact", "code_suffix_preserved",
	"only_literal_range_changed", "physical_resume_bytes_preserved",
	"call_proof_retained", "source_registry_certificate_retained",
	"replacement_registry_certificate_retained", "registered_bodies_not_executed",
	"source_container_not_modified",
]
const SOURCE_IDENTITY_KEYS := ["archive", "entry", "source_kind", "archive_sha256"]
const COMPATIBILITY := {
	"policy": "exact_same_width_literal_registered_definition_call_plan_only",
	"input_editable_schema": "kakyu_mes_editable_ir/v1",
	"input_plan_schema": "kakyu_mes_registered_definition_call_edit_plan/v1",
	"input_decompiler_schema": "kakyu_mes_decompiler_ir/v1",
	"input_call_family_proof_schema": "kakyu_mes_call_family_proof/v1",
	"input_registry_proof_schema": "kakyu_mes_registered_definition_registry_proof/v1",
	"unknown_audit_schema": "reject",
	"unknown_v1_field": "reject",
	"output_policy": "new_file_only",
	"relocation": "forbidden",
	"registered_body_execution": "not_performed",
	"return_edge_policy": "not_emitted",
	"native_engine_compatibility": "unverified",
}


func audit(payload: PackedByteArray, compile_audit: Dictionary) -> Dictionary:
	var validation := validate_compile_audit(compile_audit)
	if not validation.ok:
		return validation
	var output_row: Dictionary = compile_audit.output
	if payload.size() != int(output_row.size) or ContractValues.sha256_lenient(payload) != str(output_row.entry_sha256):
		return _error("Compiled MES bytes do not match their registered-definition call audit.")
	var source_identity: Dictionary = compile_audit.source_identity.duplicate(true)
	var document := MesContainerScript.new().parse(payload, source_identity)
	if not document.get("ok", false):
		return _error("Compiled registered-definition call MES did not reopen: %s" % document.get("error", "failed"))
	var code_offset := int(document.header.code_offset)
	var preamble := payload.slice(0, code_offset)
	var address_table := payload.slice(4, code_offset)
	if (
		int(document.header.entry_count) != int(output_row.entry_count)
		or code_offset != int(output_row.code_offset)
		or int(document.header.code_size) != int(output_row.code_size)
		or str(document.entry_sha256) != str(output_row.entry_sha256)
		or str(document.bytecode_sha256) != str(output_row.bytecode_sha256)
		or ContractValues.sha256_lenient(preamble) != str(output_row.preamble_sha256)
		or ContractValues.sha256_lenient(address_table) != str(output_row.address_table_sha256)
	):
		return _error("GDScript container reopen differs from the registered-definition call audit.")
	var analysis := MesAnalysisScript.new().build(document)
	if not analysis.get("ok", false):
		return _error("Compiled registered-definition call MES Phase 1-4 analysis failed.")
	var handoff_builder := AnalyzerHandoffScript.new()
	var handoff := handoff_builder.build(document, analysis)
	var verified: Dictionary = handoff_builder.verify(handoff)
	if not verified.get("ok", false):
		return _error("Compiled registered-definition call MES handoff failed: %s" % verified.get(
			"error", handoff.get("error", "failed")
		))
	if handoff.source_identity != source_identity:
		return _error("Compiled registered-definition call MES source identity changed during reopen.")
	var coverage: Dictionary = compile_audit.coverage
	var alignment: Dictionary = handoff.record_alignment
	var typed_count := int((handoff.typed_ir.instructions as Array).size())
	var opaque_count := int((handoff.typed_ir.opaque_boundaries as Array).size())
	if (
		not CompileCoverageScript.regions_match(coverage, document, alignment)
		or int(coverage.typed_node_count) != typed_count
		or int(coverage.opaque_node_count) != opaque_count
		or int(coverage.node_count) != typed_count + opaque_count
		or int(coverage.code_bytes) != int(document.header.code_size)
		or int(alignment.framed_bytes) != int(document.header.code_size)
	):
		return _error("Phase 1-4 coverage differs from the registered-definition call audit.")
	var edited_call := _find_edited_call(document.bytecode, analysis, compile_audit)
	if not edited_call.ok:
		return edited_call
	var result := {
		"ok": true,
		"schema": ContentCoreVersionScript.MES_REGISTERED_DEFINITION_CALL_REOPEN_AUDIT_SCHEMA,
		"producer": {
			"implementation": "godot_gdscript_phase1_4_registered_definition_call_reopen",
			"contract": ContentCoreVersionScript.MES_REGISTERED_DEFINITION_CALL_REOPEN_AUDIT_SCHEMA,
		},
		"compatibility": {
			"policy": "exact_registered_definition_call_compile_audit_and_current_phase1_4_schemas",
			"input_compile_audit_schema": ContentCoreVersionScript.MES_REGISTERED_DEFINITION_CALL_COMPILE_AUDIT_SCHEMA,
			"container_schema": ContentCoreVersionScript.MES_CONTAINER_SCHEMA,
			"analysis_schema": ContentCoreVersionScript.MES_ANALYSIS_SCHEMA,
			"record_alignment_schema": ContentCoreVersionScript.MES_RECORD_ALIGNMENT_AUDIT_SCHEMA,
			"analyzer_handoff_schema": ContentCoreVersionScript.MES_ANALYZER_HANDOFF_SCHEMA,
		},
		"source_identity": source_identity,
		"registry_identity": compile_audit.registry_identity.duplicate(true),
		"compile_audit_sha256": str(compile_audit.payload_sha256),
		"output": output_row.duplicate(true),
		"edited_call": edited_call.call,
		"phase1_4": {
			"handoff_sha256": str(handoff.payload_sha256),
			"analysis_complete": bool(analysis.complete),
			"analysis_diagnostic_count": int(analysis.diagnostic_count),
			"alignment_failure_count": int(alignment.failure_count),
		},
		"coverage": {
			"region_count": CompileCoverageScript.region_count(document),
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
			"source_node_partition_preserved": true,
			"replacement_call_redecoded": true,
			"replacement_literal_redecoded": true,
			"physical_resume_partition_preserved": true,
			"call_proof_retained": true,
			"registry_certificates_retained_without_execution": true,
		},
	}
	result["payload_sha256"] = fingerprint(result)
	return result


func validate_compile_audit(document: Dictionary) -> Dictionary:
	if (
		document.get("ok") != true
		or str(document.get("schema", ""))
		!= ContentCoreVersionScript.MES_REGISTERED_DEFINITION_CALL_COMPILE_AUDIT_SCHEMA
		or not ContractValues.has_exact_keys(document, AUDIT_KEYS)
	):
		return _error("MES registered-definition call compile audit schema or fields changed.")
	if document.get("producer") != {
		"implementation": "python_phase6_registered_definition_call_compiler",
		"contract": ContentCoreVersionScript.MES_REGISTERED_DEFINITION_CALL_COMPILE_AUDIT_SCHEMA,
	}:
		return _error("MES registered-definition call compile audit producer changed.")
	if document.get("compatibility") != COMPATIBILITY:
		return _error("MES registered-definition call compile compatibility changed.")
	var retained_hash := str(document.get("payload_sha256", ""))
	if not ContractValues.is_sha256(retained_hash) or fingerprint(document) != retained_hash:
		return _error("MES registered-definition call compile audit fingerprint changed.")
	var source_identity = document.get("source_identity")
	var registry_identity = document.get("registry_identity")
	if (
		not source_identity is Dictionary
		or not ContractValues.has_only_keys(source_identity, SOURCE_IDENTITY_KEYS)
		or not ArcReaderScript.is_safe_entry_name(str(source_identity.get("entry", "")))
		or not ContractValues.is_sha256(str(source_identity.get("archive_sha256", "")))
		or not registry_identity is Dictionary
		or not ContractValues.has_exact_keys(registry_identity, PlanScript.REGISTRY_IDENTITY_KEYS)
		or str(registry_identity.get("archive", "")).is_empty()
		or not ArcReaderScript.is_safe_entry_name(str(registry_identity.get("entry", "")))
		or not ContractValues.hash_values(registry_identity, ["archive_sha256", "entry_sha256", "proof_sha256"])
		or str(registry_identity.archive_sha256) != str(source_identity.archive_sha256)
	):
		return _error("MES registered-definition call compile source identity changed.")
	var inputs = document.get("inputs")
	if (
		not inputs is Dictionary
		or not ContractValues.has_exact_keys(inputs, [
			"editable_ir_sha256", "decompiler_ir_sha256", "call_family_proof_sha256",
			"registry_proof_sha256", "registered_definition_call_plan_sha256",
		])
		or not ContractValues.hash_values(inputs, inputs.keys())
		or str(inputs.registry_proof_sha256) != str(registry_identity.proof_sha256)
	):
		return _error("MES registered-definition call compile input identity changed.")
	var source = document.get("source")
	var output = document.get("output")
	if not _valid_summary(source) or not _valid_summary(output):
		return _error("MES registered-definition call compile container summary changed.")
	if (
		int(output.size) != int(source.size)
		or int(output.entry_count) != int(source.entry_count)
		or int(output.code_offset) != int(source.code_offset)
		or int(output.code_size) != int(source.code_size)
		or str(output.preamble_sha256) != str(source.preamble_sha256)
		or str(output.address_table_sha256) != str(source.address_table_sha256)
	):
		return _error("MES registered-definition call compile layout preservation changed.")
	var operation = document.get("operation")
	if (
		not operation is Dictionary
		or not ContractValues.has_exact_keys(operation, OPERATION_KEYS)
		or str(operation.get("kind", "")) != "replace_registered_definition_literal"
		or not ContractValues.nonnegative_integer_values(operation, [
			"source_offset", "source_selector", "replacement_selector", "width",
			"physical_resume_offset",
		])
		or int(operation.width) != 8
		or int(operation.source_selector) > 0x7F
		or int(operation.replacement_selector) > 0x7F
		or int(operation.source_selector) == int(operation.replacement_selector)
	):
		return _error("MES registered-definition call compile operation changed.")
	var target = document.get("target")
	if (
		not target is Dictionary
		or not ContractValues.has_exact_keys(target, TARGET_KEYS)
		or str(target.get("node_id", "")).is_empty()
		or str(target.get("region_id", "")).is_empty()
		or str(target.get("resume_node_id", "")).is_empty()
		or str(target.get("resume_region_id", "")).is_empty()
		or not ContractValues.nonnegative_integer_values(target, [
			"instruction_start", "instruction_end", "literal_start", "literal_end",
			"resume_start", "resume_end",
		])
		or not ContractValues.hash_values(target, [
			"resume_raw_sha256", "source_instruction_sha256",
			"replacement_instruction_sha256", "source_expression_sha256",
			"replacement_expression_sha256", "source_literal_sha256",
			"replacement_literal_sha256",
		])
		or int(target.instruction_start) != int(operation.source_offset)
		or int(target.instruction_end) != int(target.instruction_start) + 5
		or int(target.literal_start) != int(target.instruction_start) + 2
		or int(target.instruction_end) != int(operation.physical_resume_offset)
		or int(target.resume_start) != int(operation.physical_resume_offset)
		or int(target.literal_end) != int(target.literal_start) + 1
		or int(target.resume_end) <= int(target.resume_start)
	):
		return _error("MES registered-definition call compile target changed.")
	var call_proof = target.get("call_proof")
	if (
		not call_proof is Dictionary
		or not ContractValues.has_exact_keys(call_proof, PlanScript.CALL_PROOF_KEYS)
		or int(call_proof.get("selector", -1)) != int(operation.source_selector)
		or int(call_proof.get("call_start", -1)) != int(target.instruction_start)
		or int(call_proof.get("call_end", -1)) != int(target.instruction_end)
		or int(call_proof.get("physical_resume_offset", -1)) != int(target.resume_start)
		or str(call_proof.get("physical_resume_node_id", "")) != str(target.resume_node_id)
		or str(call_proof.get("physical_resume_region", "")) != str(target.resume_region_id)
		or str(call_proof.get("physical_resume_raw_sha256", "")) != str(target.resume_raw_sha256)
		or str(call_proof.get("proof_status", ""))
		!= "typed_registered_selector_and_exact_physical_resume"
		or str(call_proof.get("native_role", ""))
		!= "registered_definition_lookup_call_and_restore"
		or str(call_proof.get("registry_binding_status", ""))
		!= "source_and_replacement_exact_body_boundaries_supplied"
		or str(call_proof.get("return_edge", ""))
		!= "unproved_registered_body_total_return_not_supplied"
	):
		return _error("MES registered-definition call compile call proof changed.")
	for binding_pair in [
		[target.get("source_registry_binding"), int(operation.source_selector)],
		[target.get("replacement_registry_binding"), int(operation.replacement_selector)],
	]:
		if not PlanScript.new()._valid_registry_binding(binding_pair[0], binding_pair[1]):
			return _error("MES registered-definition call compile registry binding changed.")
	var coverage = document.get("coverage")
	if (
		not coverage is Dictionary
		or not ContractValues.has_exact_keys(coverage, COVERAGE_KEYS)
		or not ContractValues.nonnegative_integer_values(coverage, COVERAGE_KEYS)
		or int(coverage.node_count) != int(coverage.typed_node_count) + int(coverage.opaque_node_count)
		or int(coverage.code_bytes) != int(source.code_size)
	):
		return _error("MES registered-definition call compile coverage changed.")
	var invariants = document.get("invariants")
	if (
		not invariants is Dictionary
		or not ContractValues.has_exact_keys(invariants, INVARIANT_KEYS)
		or not ContractValues.all_true(invariants)
	):
		return _error("MES registered-definition call compile invariants changed.")
	return {
		"ok": true,
		"schema": ContentCoreVersionScript.MES_REGISTERED_DEFINITION_CALL_COMPILE_AUDIT_SCHEMA,
		"payload_sha256": retained_hash,
	}


func fingerprint(document: Dictionary) -> String:
	return FingerprintScript.new().fingerprint(document)


func _find_edited_call(code: PackedByteArray, analysis: Dictionary, compile_audit: Dictionary) -> Dictionary:
	var operation: Dictionary = compile_audit.operation
	var target: Dictionary = compile_audit.target
	var start := int(target.instruction_start)
	var end := int(target.instruction_end)
	var literal_start := int(target.literal_start)
	var literal_end := int(target.literal_end)
	if start < 0 or end > code.size() or literal_end > end:
		return _error("Compiled MES registered-definition call range is outside the code.")
	var instruction := MesDecoderScript.new().decode_at(code, start, end)
	if (
		not instruction.get("ok", false)
		or str(instruction.get("op", "")) != "definition_invoke"
		or int(instruction.get("command_id", -1)) != 0x11
		or int(instruction.get("end_offset", -1)) != end
		or ContractValues.sha256_lenient(str(instruction.get("raw_hex", "")).hex_decode())
		!= str(target.replacement_instruction_sha256)
	):
		return _error("Compiled MES registered-definition call was not exactly redecoded.")
	var operands: Array = instruction.get("operands", [])
	if operands.size() != 1 or not operands[0] is Dictionary:
		return _error("Compiled MES registered-definition call operand was not redecoded.")
	var records = operands[0].get("records")
	if not records is Array or records.size() != 1 or not records[0] is Dictionary:
		return _error("Compiled MES registered-definition call record list changed.")
	var expression = records[0].get("value")
	var ast = expression.get("ast") if expression is Dictionary else null
	var expected_selector := int(operation.replacement_selector)
	if (
		not expression is Dictionary
		or not ast is Dictionary
		or str(ast.get("type", "")) != "literal"
		or int(ast.get("value", -1)) != expected_selector
		or int(ast.get("width", -1)) != 8
		or int(ast.get("source", {}).get("offset", -1)) != literal_start
		or int(expression.get("offset", -1)) != literal_start
		or int(expression.get("end_offset", -1)) != literal_end + 1
		or ContractValues.sha256_lenient(str(expression.get("raw_hex", "")).hex_decode())
		!= str(target.replacement_expression_sha256)
		or ContractValues.sha256_lenient(code.slice(literal_start, literal_end))
		!= str(target.replacement_literal_sha256)
	):
		return _error("Compiled MES registered-definition literal differs from its audit.")
	var call_matches := 0
	for untyped_row in analysis.instructions:
		var row: Dictionary = untyped_row
		if int(row.get("source_offset", -1)) == start and int(row.get("end_offset", -1)) == end:
			call_matches += 1
	if call_matches != 1:
		return _error("Compiled MES registered-definition call partition was not preserved.")
	var resume_start := int(target.resume_start)
	var resume_end := int(target.resume_end)
	var resume_matches := 0
	var resume_kind := ""
	for pair in [[analysis.instructions, "statement"], [analysis.get("opaque_boundaries", []), "opaque"]]:
		for untyped_row in pair[0]:
			var row: Dictionary = untyped_row
			if (
				int(row.get("source_offset", -1)) == resume_start
				and int(row.get("end_offset", -1)) == resume_end
				and str(row.get("region", "")) == str(target.resume_region_id)
				and ContractValues.sha256_lenient(str(row.get("raw_hex", "")).hex_decode()) == str(target.resume_raw_sha256)
			):
				resume_matches += 1
				resume_kind = pair[1]
	if resume_matches != 1 or resume_start != end:
		return _error("Compiled MES registered-definition physical resume partition was not preserved.")
	return {
		"ok": true,
		"call": {
			"op": "definition_invoke",
			"command_id": 0x11,
			"instruction_start": start,
			"instruction_end": end,
			"instruction_sha256": str(target.replacement_instruction_sha256),
			"literal_start": literal_start,
			"literal_end": literal_end,
			"literal_sha256": str(target.replacement_literal_sha256),
			"source_selector": int(operation.source_selector),
			"replacement_selector": expected_selector,
			"physical_resume_offset": resume_start,
			"physical_resume_end": resume_end,
			"physical_resume_kind": resume_kind,
			"physical_resume_sha256": str(target.resume_raw_sha256),
			"call_proof": target.call_proof.duplicate(true),
			"source_registry_binding": target.source_registry_binding.duplicate(true),
			"replacement_registry_binding": target.replacement_registry_binding.duplicate(true),
		},
	}


func _valid_summary(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	var row: Dictionary = value
	return (
		ContractValues.has_exact_keys(row, SUMMARY_KEYS)
		and ContractValues.nonnegative_integer_values(row, ["size", "entry_count", "code_offset", "code_size"])
		and ContractValues.hash_values(row, [
			"entry_sha256", "bytecode_sha256", "preamble_sha256", "address_table_sha256",
		])
		and int(row.size) == int(row.code_offset) + int(row.code_size)
	)


func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message}
