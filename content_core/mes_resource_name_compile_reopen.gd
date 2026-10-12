class_name KakyuMesResourceNameCompileReopen
extends RefCounted

const CompileCoverageScript := preload("res://content_core/mes_compile_coverage.gd")

const ArcReaderScript := preload("res://content_core/arc_reader.gd")
const MesContainerScript := preload("res://content_core/mes_container.gd")
const MesAnalysisScript := preload("res://content_core/mes_analysis_index.gd")
const AnalyzerHandoffScript := preload("res://content_core/mes_analyzer_handoff.gd")
const FingerprintScript := preload("res://content_core/mes_payload_fingerprint.gd")
const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")
const ContractValues := preload("res://content_core/contract_values.gd")

const AUDIT_KEYS := [
	"ok", "schema", "producer", "compatibility", "source_identity", "inputs",
	"source", "output", "operation", "target", "coverage", "invariants",
	"payload_sha256",
]
const SUMMARY_KEYS := [
	"size", "entry_count", "code_offset", "code_size", "entry_sha256",
	"bytecode_sha256", "preamble_sha256", "address_table_sha256",
]
const OPERATION_KEYS := [
	"kind", "source_offset", "reference_id", "resource_kind", "source_name",
	"replacement_name",
]
const TARGET_KEYS := [
	"node_id", "region_id", "op", "instruction_start", "instruction_end",
	"name_start", "name_end", "name_bytes", "prefix_bytes", "suffix_bytes",
	"source_instruction_sha256", "replacement_instruction_sha256",
	"source_name_sha256", "replacement_name_sha256", "prefix_sha256",
	"suffix_sha256", "reference_boundary",
]
const COVERAGE_KEYS := [
	"region_count", "node_count", "typed_node_count", "opaque_node_count", "code_bytes",
]
const INVARIANT_KEYS := [
	"plan_ready", "output_reopened", "container_size_preserved",
	"entry_count_preserved", "code_offset_preserved", "code_size_preserved",
	"address_table_preserved", "preamble_preserved", "code_prefix_preserved",
	"replacement_instruction_exact", "code_suffix_preserved",
	"marker_prefix_preserved", "marker_suffix_preserved",
	"only_name_range_changed", "source_container_not_modified",
]
const SOURCE_IDENTITY_KEYS := ["archive", "entry", "source_kind", "archive_sha256"]
const RESOURCE_FORMS := {
	"mmo": {"op": "mmo_resource_marker", "operand_kind": "mmo_marker", "extension": "mmo"},
	"ax": {"op": "ax_resource_marker", "operand_kind": "ax_marker", "extension": "ax"},
	"voice": {"op": "voice_marker", "operand_kind": "voice_marker", "extension": "ogg"},
}
const COMPATIBILITY := {
	"policy": "exact_same_length_resource_name_plan_only",
	"input_editable_schema": "kakyu_mes_editable_ir/v1",
	"input_plan_schema": "kakyu_mes_resource_name_edit_plan/v1",
	"input_decompiler_schema": "kakyu_mes_decompiler_ir/v1",
	"unknown_audit_schema": "reject",
	"unknown_v1_field": "reject",
	"output_policy": "new_file_only",
	"relocation": "forbidden",
	"resource_existence": "not_checked",
	"native_engine_compatibility": "unverified",
}


func audit(payload: PackedByteArray, compile_audit: Dictionary) -> Dictionary:
	var validation := validate_compile_audit(compile_audit)
	if not validation.ok:
		return validation
	var output_row: Dictionary = compile_audit.output
	if payload.size() != int(output_row.size) or ContractValues.sha256_lenient(payload) != str(output_row.entry_sha256):
		return _error("Compiled MES bytes do not match their resource name compile audit.")
	var source_identity: Dictionary = compile_audit.source_identity.duplicate(true)
	var document := MesContainerScript.new().parse(payload, source_identity)
	if not document.get("ok", false):
		return _error("Compiled resource name MES did not reopen: %s" % document.get("error", "failed"))
	var code_offset := int(document.header.code_offset)
	var preamble := payload.slice(0, code_offset)
	if (
		int(document.header.entry_count) != int(output_row.entry_count)
		or code_offset != int(output_row.code_offset)
		or int(document.header.code_size) != int(output_row.code_size)
		or str(document.entry_sha256) != str(output_row.entry_sha256)
		or str(document.bytecode_sha256) != str(output_row.bytecode_sha256)
		or ContractValues.sha256_lenient(preamble) != str(output_row.preamble_sha256)
		or ContractValues.sha256_lenient(preamble) != str(output_row.address_table_sha256)
	):
		return _error("GDScript MES container reopen differs from the resource name compile audit.")
	var analysis := MesAnalysisScript.new().build(document)
	if not analysis.get("ok", false):
		return _error("Compiled resource name MES Phase 1-4 analysis failed.")
	var handoff_builder := AnalyzerHandoffScript.new()
	var handoff := handoff_builder.build(document, analysis)
	var verified: Dictionary = handoff_builder.verify(handoff)
	if not verified.get("ok", false):
		return _error("Compiled resource name MES Phase 1-4 handoff failed: %s" % verified.get(
			"error", handoff.get("error", "failed")
		))
	if handoff.source_identity != source_identity:
		return _error("Compiled resource name MES source identity changed during reopen.")
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
		return _error("GDScript Phase 1-4 coverage differs from the resource name compile audit.")
	var edited_resource := _find_edited_resource(
		analysis.instructions,
		analysis.resource_references,
		document.bytecode,
		compile_audit.operation,
		compile_audit.target
	)
	if not edited_resource.ok:
		return edited_resource
	var result := {
		"ok": true,
		"schema": ContentCoreVersionScript.MES_RESOURCE_NAME_REOPEN_AUDIT_SCHEMA,
		"producer": {
			"implementation": "godot_gdscript_phase1_4_resource_name_reopen",
			"contract": ContentCoreVersionScript.MES_RESOURCE_NAME_REOPEN_AUDIT_SCHEMA,
		},
		"compatibility": {
			"policy": "exact_resource_name_compile_audit_and_current_phase1_4_schemas",
			"input_compile_audit_schema": ContentCoreVersionScript.MES_RESOURCE_NAME_COMPILE_AUDIT_SCHEMA,
			"container_schema": ContentCoreVersionScript.MES_CONTAINER_SCHEMA,
			"analysis_schema": ContentCoreVersionScript.MES_ANALYSIS_SCHEMA,
			"record_alignment_schema": ContentCoreVersionScript.MES_RECORD_ALIGNMENT_AUDIT_SCHEMA,
			"analyzer_handoff_schema": ContentCoreVersionScript.MES_ANALYZER_HANDOFF_SCHEMA,
		},
		"source_identity": source_identity,
		"compile_audit_sha256": str(compile_audit.payload_sha256),
		"output": output_row.duplicate(true),
		"edited_resource": edited_resource.resource,
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
			"replacement_marker_reindexed": true,
			"replacement_name_reindexed": true,
			"resource_reference_reindexed": true,
		},
	}
	result["payload_sha256"] = fingerprint(result)
	return result


func validate_compile_audit(document: Dictionary) -> Dictionary:
	if (
		document.get("ok") != true
		or str(document.get("schema", ""))
		!= ContentCoreVersionScript.MES_RESOURCE_NAME_COMPILE_AUDIT_SCHEMA
		or not ContractValues.has_exact_keys(document, AUDIT_KEYS)
	):
		return _error("MES resource name compile audit schema or fields changed.")
	if document.get("producer") != {
		"implementation": "python_phase6_resource_name_compiler",
		"contract": ContentCoreVersionScript.MES_RESOURCE_NAME_COMPILE_AUDIT_SCHEMA,
	}:
		return _error("MES resource name compile audit producer changed.")
	if document.get("compatibility") != COMPATIBILITY:
		return _error("MES resource name compile compatibility changed.")
	var retained_hash := str(document.get("payload_sha256", ""))
	if not ContractValues.is_sha256(retained_hash) or fingerprint(document) != retained_hash:
		return _error("MES resource name compile audit fingerprint changed.")
	var source_identity = document.get("source_identity")
	if (
		not source_identity is Dictionary
		or not ContractValues.has_only_keys(source_identity, SOURCE_IDENTITY_KEYS)
		or not ArcReaderScript.is_safe_entry_name(str(source_identity.get("entry", "")))
	):
		return _error("MES resource name compile source identity changed.")
	var inputs = document.get("inputs")
	if (
		not inputs is Dictionary
		or not ContractValues.has_exact_keys(inputs, [
			"editable_ir_sha256", "decompiler_ir_sha256", "resource_name_plan_sha256",
		])
		or not ContractValues.hash_values(inputs, [
			"editable_ir_sha256", "decompiler_ir_sha256", "resource_name_plan_sha256",
		])
	):
		return _error("MES resource name compile input identity changed.")
	var source = document.get("source")
	var output = document.get("output")
	if not _valid_summary(source) or not _valid_summary(output):
		return _error("MES resource name compile container summary changed.")
	if (
		int(output.size) != int(source.size)
		or int(output.entry_count) != int(source.entry_count)
		or int(output.code_offset) != int(source.code_offset)
		or int(output.code_size) != int(source.code_size)
		or str(output.preamble_sha256) != str(source.preamble_sha256)
		or str(output.address_table_sha256) != str(source.address_table_sha256)
	):
		return _error("MES resource name compile layout preservation changed.")
	var operation = document.get("operation")
	if (
		not operation is Dictionary
		or not ContractValues.has_exact_keys(operation, OPERATION_KEYS)
		or str(operation.get("kind", "")) != "replace_resource_name"
		or not ContractValues.nonnegative_json_integer(operation.get("source_offset", -1))
		or str(operation.get("reference_id", "")).is_empty()
		or not RESOURCE_FORMS.has(str(operation.get("resource_kind", "")))
		or not ArcReaderScript.is_safe_entry_name(str(operation.get("source_name", "")))
		or not ArcReaderScript.is_safe_entry_name(str(operation.get("replacement_name", "")))
	):
		return _error("MES resource name compile operation changed.")
	var form: Dictionary = RESOURCE_FORMS[str(operation.resource_kind)]
	var target = document.get("target")
	if (
		not target is Dictionary
		or not ContractValues.has_exact_keys(target, TARGET_KEYS)
		or str(target.get("node_id", "")).is_empty()
		or str(target.get("region_id", "")).is_empty()
		or str(target.get("op", "")) != str(form.op)
		or str(target.get("reference_boundary", "")) != "strict_indexed"
		or not ContractValues.nonnegative_integer_values(target, [
			"instruction_start", "instruction_end", "name_start", "name_end",
			"name_bytes", "prefix_bytes", "suffix_bytes",
		])
		or not ContractValues.hash_values(target, [
			"source_instruction_sha256", "replacement_instruction_sha256",
			"source_name_sha256", "replacement_name_sha256", "prefix_sha256",
			"suffix_sha256",
		])
		or int(target.instruction_end) <= int(target.instruction_start)
		or int(target.name_start) != int(target.instruction_start) + int(target.prefix_bytes)
		or int(target.name_end) != int(target.name_start) + int(target.name_bytes)
		or int(target.instruction_end) != int(target.name_end) + int(target.suffix_bytes)
		or int(operation.source_offset) != int(target.instruction_start)
	):
		return _error("MES resource name compile target changed.")
	var coverage = document.get("coverage")
	if (
		not coverage is Dictionary
		or not ContractValues.has_exact_keys(coverage, COVERAGE_KEYS)
		or not ContractValues.nonnegative_integer_values(coverage, COVERAGE_KEYS)
		or int(coverage.node_count) != int(coverage.typed_node_count) + int(coverage.opaque_node_count)
		or int(coverage.code_bytes) != int(source.code_size)
	):
		return _error("MES resource name compile coverage changed.")
	var invariants = document.get("invariants")
	if (
		not invariants is Dictionary
		or not ContractValues.has_exact_keys(invariants, INVARIANT_KEYS)
		or not ContractValues.all_true(invariants)
	):
		return _error("MES resource name compile invariants changed.")
	return {
		"ok": true,
		"schema": ContentCoreVersionScript.MES_RESOURCE_NAME_COMPILE_AUDIT_SCHEMA,
		"payload_sha256": retained_hash,
	}


func fingerprint(document: Dictionary) -> String:
	return FingerprintScript.new().fingerprint(document)


func _find_edited_resource(
	instructions: Array,
	resource_references: Array,
	code: PackedByteArray,
	operation: Dictionary,
	target: Dictionary
) -> Dictionary:
	var matches: Array[Dictionary] = []
	for untyped_instruction in instructions:
		var instruction: Dictionary = untyped_instruction
		if int(instruction.source_offset) == int(target.instruction_start):
			matches.append(instruction)
	if matches.size() != 1:
		return _error("Compiled MES edited resource marker was not uniquely reindexed.")
	var instruction: Dictionary = matches[0]
	if (
		str(instruction.op) != str(target.op)
		or int(instruction.end_offset) != int(target.instruction_end)
		or ContractValues.sha256_lenient(str(instruction.raw_hex).hex_decode())
		!= str(target.replacement_instruction_sha256)
	):
		return _error("Compiled MES edited resource instruction differs from its audit.")
	var operands: Array = instruction.get("operands", [])
	var resource_operands: Array[Dictionary] = []
	for untyped_operand in operands:
		if untyped_operand is Dictionary and str(untyped_operand.get("type", "")) == "resource_name":
			resource_operands.append(untyped_operand)
	if resource_operands.size() != 1:
		return _error("Compiled MES edited resource operand was not uniquely reindexed.")
	var operand: Dictionary = resource_operands[0]
	var form: Dictionary = RESOURCE_FORMS[str(operation.resource_kind)]
	var decoded_source_name := str(operand.get("source_name", operand.get("name", "")))
	var expected_normalized := _normalized_name(str(operation.replacement_name), str(operation.resource_kind))
	if (
		str(operand.get("resource_kind", "")) != str(form.operand_kind)
		or int(operand.get("source_offset", -1)) != int(target.name_start)
		or decoded_source_name != str(operation.replacement_name)
		or str(operand.get("name", "")) != expected_normalized
	):
		return _error("Compiled MES edited resource operand differs from its audit.")
	var name_bytes := code.slice(int(target.name_start), int(target.name_end))
	var prefix_bytes := code.slice(int(target.instruction_start), int(target.name_start))
	var suffix_bytes := code.slice(int(target.name_end), int(target.instruction_end))
	if (
		ContractValues.sha256_lenient(name_bytes) != str(target.replacement_name_sha256)
		or ContractValues.sha256_lenient(prefix_bytes) != str(target.prefix_sha256)
		or ContractValues.sha256_lenient(suffix_bytes) != str(target.suffix_sha256)
		or name_bytes.get_string_from_ascii() != str(operation.replacement_name)
	):
		return _error("Compiled MES edited resource byte slices differ from their audit.")
	var reference_matches: Array[Dictionary] = []
	for untyped_reference in resource_references:
		var reference: Dictionary = untyped_reference
		if (
			int(reference.get("source_offset", -1)) == int(target.instruction_start)
			and str(reference.get("op", "")) == str(target.op)
			and str(reference.get("resource_kind", "")) == str(operation.resource_kind)
		):
			reference_matches.append(reference)
	if (
		reference_matches.size() != 1
		or str(reference_matches[0].get("boundary", "")) != "strict_indexed"
		or str(reference_matches[0].get("source_name", "")) != str(operation.replacement_name)
		or str(reference_matches[0].get("name", "")) != expected_normalized
	):
		return _error("Compiled MES edited resource reference differs from its audit.")
	return {
		"ok": true,
		"resource": {
			"op": str(instruction.op),
			"instruction_start": int(instruction.source_offset),
			"instruction_end": int(instruction.end_offset),
			"instruction_sha256": str(target.replacement_instruction_sha256),
			"name_start": int(target.name_start),
			"name_end": int(target.name_end),
			"name_sha256": str(target.replacement_name_sha256),
			"resource_kind": str(operation.resource_kind),
			"reference_id": str(operation.reference_id),
			"source_name": str(operation.source_name),
			"replacement_name": str(operation.replacement_name),
			"normalized_name": expected_normalized,
			"reference_boundary": "strict_indexed",
		},
	}


func _normalized_name(value: String, resource_kind: String) -> String:
	if resource_kind == "mmo":
		return value
	return value.get_basename().to_upper() + "." + value.get_extension().to_upper()


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
