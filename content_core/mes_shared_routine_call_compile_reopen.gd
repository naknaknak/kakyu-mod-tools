class_name KakyuMesSharedRoutineCallCompileReopen
extends RefCounted

const CompileCoverageScript := preload("res://content_core/mes_compile_coverage.gd")

const ArcReaderScript := preload("res://content_core/arc_reader.gd")
const MesContainerScript := preload("res://content_core/mes_container.gd")
const MesAnalysisScript := preload("res://content_core/mes_analysis_index.gd")
const MesDecoderScript := preload("res://content_core/mes_instruction_decoder.gd")
const AnalyzerHandoffScript := preload("res://content_core/mes_analyzer_handoff.gd")
const FingerprintScript := preload("res://content_core/mes_payload_fingerprint.gd")
const PlanScript := preload("res://content_core/mes_shared_routine_call_edit_plan.gd")
const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")
const ContractValues := preload("res://content_core/contract_values.gd")

const AUDIT_KEYS := [
	"ok", "schema", "producer", "compatibility", "source_identity",
	"library_identity", "inputs", "source", "output", "operation", "target",
	"coverage", "invariants", "payload_sha256",
]
const SUMMARY_KEYS := [
	"size", "entry_count", "code_offset", "code_size", "entry_sha256",
	"bytecode_sha256", "preamble_sha256", "address_table_sha256",
]
const OPERATION_KEYS := [
	"kind", "source_offset", "source_routine_id", "replacement_routine_id",
	"width", "physical_resume_offset",
]
const TARGET_KEYS := [
	"node_id", "region_id", "instruction_start", "instruction_end",
	"literal_start", "literal_end", "resume_node_id", "resume_region_id",
	"resume_start", "resume_end", "resume_raw_sha256",
	"source_instruction_sha256", "replacement_instruction_sha256",
	"source_expression_sha256", "replacement_expression_sha256",
	"source_literal_sha256", "replacement_literal_sha256", "source_callee",
	"replacement_callee",
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
	"source_callee_certificate_retained", "replacement_callee_certificate_retained",
	"source_container_not_modified",
]
const SOURCE_IDENTITY_KEYS := ["archive", "entry", "source_kind", "archive_sha256"]
const LIBRARY_IDENTITY_KEYS := ["archive_name", "archive_sha256", "entry", "entry_sha256"]
const COMPATIBILITY := {
	"policy": "exact_same_width_literal_shared_routine_call_plan_only",
	"input_editable_schema": "kakyu_mes_editable_ir/v1",
	"input_plan_schema": "kakyu_mes_shared_routine_call_edit_plan/v1",
	"input_decompiler_schema": "kakyu_mes_decompiler_ir/v1",
	"input_shared_call_proof_schema": "kakyu_mes_shared_call_return_proof/v2",
	"input_library_audit_schema": "kakyu_mes_library_audit/v17",
	"unknown_audit_schema": "reject",
	"unknown_v1_field": "reject",
	"output_policy": "new_file_only",
	"relocation": "forbidden",
	"tool_execution": "not_performed",
	"native_engine_compatibility": "unverified",
}


func audit(payload: PackedByteArray, compile_audit: Dictionary) -> Dictionary:
	var validation := validate_compile_audit(compile_audit)
	if not validation.ok:
		return validation
	var output_row: Dictionary = compile_audit.output
	if payload.size() != int(output_row.size) or ContractValues.sha256_lenient(payload) != str(output_row.entry_sha256):
		return _error("Compiled MES bytes do not match their shared-routine call audit.")
	var source_identity: Dictionary = compile_audit.source_identity.duplicate(true)
	var document := MesContainerScript.new().parse(payload, source_identity)
	if not document.get("ok", false):
		return _error("Compiled shared-routine call MES did not reopen: %s" % document.get("error", "failed"))
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
		return _error("GDScript container reopen differs from the shared-routine call audit.")
	var analysis := MesAnalysisScript.new().build(document)
	if not analysis.get("ok", false):
		return _error("Compiled shared-routine call MES Phase 1-4 analysis failed.")
	var handoff_builder := AnalyzerHandoffScript.new()
	var handoff := handoff_builder.build(document, analysis)
	var verified: Dictionary = handoff_builder.verify(handoff)
	if not verified.get("ok", false):
		return _error("Compiled shared-routine call MES handoff failed: %s" % verified.get(
			"error", handoff.get("error", "failed")
		))
	if handoff.source_identity != source_identity:
		return _error("Compiled shared-routine call MES source identity changed during reopen.")
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
		return _error("Phase 1-4 coverage differs from the shared-routine call audit.")
	var edited_call := _find_edited_call(document.bytecode, analysis, compile_audit)
	if not edited_call.ok:
		return edited_call
	var result := {
		"ok": true,
		"schema": ContentCoreVersionScript.MES_SHARED_ROUTINE_CALL_REOPEN_AUDIT_SCHEMA,
		"producer": {
			"implementation": "godot_gdscript_phase1_4_shared_routine_call_reopen",
			"contract": ContentCoreVersionScript.MES_SHARED_ROUTINE_CALL_REOPEN_AUDIT_SCHEMA,
		},
		"compatibility": {
			"policy": "exact_shared_routine_call_compile_audit_and_current_phase1_4_schemas",
			"input_compile_audit_schema": ContentCoreVersionScript.MES_SHARED_ROUTINE_CALL_COMPILE_AUDIT_SCHEMA,
			"container_schema": ContentCoreVersionScript.MES_CONTAINER_SCHEMA,
			"analysis_schema": ContentCoreVersionScript.MES_ANALYSIS_SCHEMA,
			"record_alignment_schema": ContentCoreVersionScript.MES_RECORD_ALIGNMENT_AUDIT_SCHEMA,
			"analyzer_handoff_schema": ContentCoreVersionScript.MES_ANALYZER_HANDOFF_SCHEMA,
		},
		"source_identity": source_identity,
		"library_identity": compile_audit.library_identity.duplicate(true),
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
			"callee_certificates_retained": true,
		},
	}
	result["payload_sha256"] = fingerprint(result)
	return result


func validate_compile_audit(document: Dictionary) -> Dictionary:
	if (
		document.get("ok") != true
		or str(document.get("schema", ""))
		!= ContentCoreVersionScript.MES_SHARED_ROUTINE_CALL_COMPILE_AUDIT_SCHEMA
		or not ContractValues.has_exact_keys(document, AUDIT_KEYS)
	):
		return _error("MES shared-routine call compile audit schema or fields changed.")
	if document.get("producer") != {
		"implementation": "python_phase6_shared_routine_call_compiler",
		"contract": ContentCoreVersionScript.MES_SHARED_ROUTINE_CALL_COMPILE_AUDIT_SCHEMA,
	}:
		return _error("MES shared-routine call compile audit producer changed.")
	if document.get("compatibility") != COMPATIBILITY:
		return _error("MES shared-routine call compile compatibility changed.")
	var retained_hash := str(document.get("payload_sha256", ""))
	if not ContractValues.is_sha256(retained_hash) or fingerprint(document) != retained_hash:
		return _error("MES shared-routine call compile audit fingerprint changed.")
	var source_identity = document.get("source_identity")
	var library_identity = document.get("library_identity")
	if (
		not source_identity is Dictionary
		or not ContractValues.has_only_keys(source_identity, SOURCE_IDENTITY_KEYS)
		or not ArcReaderScript.is_safe_entry_name(str(source_identity.get("entry", "")))
		or not library_identity is Dictionary
		or not ContractValues.has_exact_keys(library_identity, LIBRARY_IDENTITY_KEYS)
		or str(library_identity.get("entry", "")) != "LIBLARY.LIB"
		or not ContractValues.is_sha256(str(library_identity.get("archive_sha256", "")))
		or not ContractValues.is_sha256(str(library_identity.get("entry_sha256", "")))
	):
		return _error("MES shared-routine call compile source identity changed.")
	var inputs = document.get("inputs")
	if (
		not inputs is Dictionary
		or not ContractValues.has_exact_keys(inputs, [
			"editable_ir_sha256", "decompiler_ir_sha256",
			"shared_call_return_proof_sha256", "library_audit_sha256",
			"shared_routine_call_plan_sha256",
		])
		or not ContractValues.hash_values(inputs, inputs.keys())
	):
		return _error("MES shared-routine call compile input identity changed.")
	var source = document.get("source")
	var output = document.get("output")
	if not _valid_summary(source) or not _valid_summary(output):
		return _error("MES shared-routine call compile container summary changed.")
	if (
		int(output.size) != int(source.size)
		or int(output.entry_count) != int(source.entry_count)
		or int(output.code_offset) != int(source.code_offset)
		or int(output.code_size) != int(source.code_size)
		or str(output.preamble_sha256) != str(source.preamble_sha256)
		or str(output.address_table_sha256) != str(source.address_table_sha256)
	):
		return _error("MES shared-routine call compile layout preservation changed.")
	var operation = document.get("operation")
	if (
		not operation is Dictionary
		or not ContractValues.has_exact_keys(operation, OPERATION_KEYS)
		or str(operation.get("kind", "")) != "replace_shared_routine_literal"
		or not ContractValues.nonnegative_integer_values(operation, [
			"source_offset", "source_routine_id", "replacement_routine_id", "width",
			"physical_resume_offset",
		])
		or int(operation.width) != 8
		or int(operation.source_routine_id) == int(operation.replacement_routine_id)
	):
		return _error("MES shared-routine call compile operation changed.")
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
		or int(target.instruction_end) != int(operation.physical_resume_offset)
		or int(target.resume_start) != int(operation.physical_resume_offset)
		or int(target.literal_end) != int(target.literal_start) + 1
		or int(target.resume_end) <= int(target.resume_start)
	):
		return _error("MES shared-routine call compile target changed.")
	var source_callee = target.get("source_callee")
	var replacement_callee = target.get("replacement_callee")
	if (
		not source_callee is Dictionary
		or not ContractValues.has_exact_keys(source_callee, PlanScript.CALL_PROOF_KEYS)
		or not replacement_callee is Dictionary
		or not ContractValues.has_exact_keys(replacement_callee, PlanScript.CALLEE_PROOF_KEYS)
		or int(source_callee.get("routine_id", -1)) != int(operation.source_routine_id)
		or int(replacement_callee.get("routine_id", -1)) != int(operation.replacement_routine_id)
		or int(source_callee.get("physical_resume_offset", -1)) != int(operation.physical_resume_offset)
		or str(source_callee.get("callee_entry", "")) != str(library_identity.entry)
		or str(replacement_callee.get("callee_entry", "")) != str(library_identity.entry)
		or str(source_callee.get("proof_status", ""))
		!= "literal_shared_call_all_callee_terminals_return_to_physical_resume"
		or str(replacement_callee.get("proof_status", ""))
		!= "replacement_shared_routine_total_return_proved"
	):
		return _error("MES shared-routine call compile callee proof changed.")
	var coverage = document.get("coverage")
	if (
		not coverage is Dictionary
		or not ContractValues.has_exact_keys(coverage, COVERAGE_KEYS)
		or not ContractValues.nonnegative_integer_values(coverage, COVERAGE_KEYS)
		or int(coverage.node_count) != int(coverage.typed_node_count) + int(coverage.opaque_node_count)
		or int(coverage.code_bytes) != int(source.code_size)
	):
		return _error("MES shared-routine call compile coverage changed.")
	var invariants = document.get("invariants")
	if (
		not invariants is Dictionary
		or not ContractValues.has_exact_keys(invariants, INVARIANT_KEYS)
		or not ContractValues.all_true(invariants)
	):
		return _error("MES shared-routine call compile invariants changed.")
	return {
		"ok": true,
		"schema": ContentCoreVersionScript.MES_SHARED_ROUTINE_CALL_COMPILE_AUDIT_SCHEMA,
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
		return _error("Compiled MES shared-routine call range is outside the code.")
	var instruction := MesDecoderScript.new().decode_at(code, start, end)
	if (
		not instruction.get("ok", false)
		or str(instruction.get("op", "")) != "script_transfer"
		or int(instruction.get("command_id", -1)) != 0x1D
		or int(instruction.get("end_offset", -1)) != end
		or ContractValues.sha256_lenient(str(instruction.get("raw_hex", "")).hex_decode())
		!= str(target.replacement_instruction_sha256)
	):
		return _error("Compiled MES shared-routine call was not exactly redecoded.")
	var operands: Array = instruction.get("operands", [])
	if operands.size() != 1 or not operands[0] is Dictionary:
		return _error("Compiled MES shared-routine call operand was not redecoded.")
	var records = operands[0].get("records")
	if not records is Array or records.size() != 1 or not records[0] is Dictionary:
		return _error("Compiled MES shared-routine call record list changed.")
	var expression = records[0].get("value")
	var ast = expression.get("ast") if expression is Dictionary else null
	var expected_routine := int(operation.replacement_routine_id)
	if (
		not expression is Dictionary
		or not ast is Dictionary
		or str(ast.get("type", "")) != "literal"
		or int(ast.get("value", -1)) != expected_routine
		or int(ast.get("width", -1)) != 8
		or int(ast.get("source", {}).get("offset", -1)) != literal_start
		or int(expression.get("offset", -1)) != literal_start
		or int(expression.get("end_offset", -1)) != literal_end + 1
		or ContractValues.sha256_lenient(str(expression.get("raw_hex", "")).hex_decode())
		!= str(target.replacement_expression_sha256)
		or ContractValues.sha256_lenient(code.slice(literal_start, literal_end))
		!= str(target.replacement_literal_sha256)
	):
		return _error("Compiled MES shared-routine literal differs from its audit.")
	var call_matches := 0
	for untyped_row in analysis.instructions:
		var row: Dictionary = untyped_row
		if int(row.get("source_offset", -1)) == start and int(row.get("end_offset", -1)) == end:
			call_matches += 1
	if call_matches != 1:
		return _error("Compiled MES shared-routine call partition was not preserved.")
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
		return _error("Compiled MES shared-routine physical resume partition was not preserved.")
	return {
		"ok": true,
		"call": {
			"op": "script_transfer",
			"command_id": 0x1D,
			"instruction_start": start,
			"instruction_end": end,
			"instruction_sha256": str(target.replacement_instruction_sha256),
			"literal_start": literal_start,
			"literal_end": literal_end,
			"literal_sha256": str(target.replacement_literal_sha256),
			"source_routine_id": int(operation.source_routine_id),
			"replacement_routine_id": expected_routine,
			"physical_resume_offset": resume_start,
			"physical_resume_end": resume_end,
			"physical_resume_kind": resume_kind,
			"physical_resume_sha256": str(target.resume_raw_sha256),
			"source_callee": target.source_callee.duplicate(true),
			"replacement_callee": target.replacement_callee.duplicate(true),
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
