class_name KakyuMesNoopCompileReopen
extends RefCounted

const CompileCoverageScript := preload("res://content_core/mes_compile_coverage.gd")

const PayloadFingerprintScript := preload("res://content_core/mes_payload_fingerprint.gd")
const MesContainerScript := preload("res://content_core/mes_container.gd")
const MesAnalysisScript := preload("res://content_core/mes_analysis_index.gd")
const AnalyzerHandoffScript := preload("res://content_core/mes_analyzer_handoff.gd")
const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")
const ContractValues := preload("res://content_core/contract_values.gd")

const COMPILE_AUDIT_KEYS := [
	"ok",
	"schema",
	"producer",
	"compatibility",
	"source_identity",
	"inputs",
	"source",
	"output",
	"operations",
	"coverage",
	"invariants",
	"payload_sha256",
]
const SOURCE_IDENTITY_KEYS := ["archive", "entry", "source_kind", "archive_sha256"]
const COMPILE_INVARIANT_KEYS := [
	"output_reopened",
	"source_container_byte_identical",
	"source_bytecode_byte_identical",
	"preamble_byte_identical",
	"region_partition_preserved",
	"node_partition_preserved",
	"opaque_records_preserved",
]


func audit(payload: PackedByteArray, compile_audit: Dictionary) -> Dictionary:
	var validation := validate_compile_audit(compile_audit)
	if not validation.get("ok", false):
		return validation
	var output_row: Dictionary = compile_audit.output
	if (
		payload.size() != int(output_row.size)
		or ContractValues.sha256(payload) != str(output_row.entry_sha256)
	):
		return _error("Compiled MES bytes do not match their compile audit.")
	var source_identity: Dictionary = compile_audit.source_identity.duplicate(true)
	var document := MesContainerScript.new().parse(payload, source_identity)
	if not document.get("ok", false):
		return _error("Compiled MES did not reopen: %s" % document.get("error", "failed"))
	if (
		int(document.header.entry_count) != int(output_row.entry_count)
		or int(document.header.code_offset) != int(output_row.code_offset)
		or int(document.header.code_size) != int(output_row.code_size)
		or str(document.entry_sha256) != str(output_row.entry_sha256)
		or str(document.bytecode_sha256) != str(output_row.bytecode_sha256)
		or ContractValues.sha256(payload.slice(0, int(document.header.code_offset)))
		!= str(output_row.preamble_sha256)
	):
		return _error("GDScript MES container reopen differs from the compile audit.")
	var analysis := MesAnalysisScript.new().build(document)
	if not analysis.get("ok", false):
		return _error("Compiled MES Phase 1-4 analysis failed.")
	var handoff_builder := AnalyzerHandoffScript.new()
	var handoff := handoff_builder.build(document, analysis)
	var verified: Dictionary = handoff_builder.verify(handoff)
	if not verified.get("ok", false):
		return _error("Compiled MES Phase 1-4 handoff failed: %s" % verified.get(
			"error", handoff.get("error", "failed")
		))
	if handoff.source_identity != source_identity:
		return _error("Compiled MES source identity changed during GDScript reopen.")
	var expected_coverage: Dictionary = compile_audit.coverage
	var typed_count := int((handoff.typed_ir.instructions as Array).size())
	var opaque_count := int((handoff.typed_ir.opaque_boundaries as Array).size())
	var alignment: Dictionary = handoff.record_alignment
	if (
		not CompileCoverageScript.regions_match(expected_coverage, document, alignment)
		or int(expected_coverage.typed_node_count) != typed_count
		or int(expected_coverage.opaque_node_count) != opaque_count
		or int(expected_coverage.node_count) != typed_count + opaque_count
		or int(expected_coverage.code_bytes) != int(document.header.code_size)
		or int(alignment.framed_bytes) != int(document.header.code_size)
	):
		return _error("GDScript Phase 1-4 coverage differs from the compile audit.")
	var result := {
		"ok": true,
		"schema": ContentCoreVersionScript.MES_NOOP_REOPEN_AUDIT_SCHEMA,
		"producer": {
			"implementation": "godot_gdscript_phase1_4_noop_reopen",
			"contract": ContentCoreVersionScript.MES_NOOP_REOPEN_AUDIT_SCHEMA,
		},
		"compatibility": {
			"policy": "exact_noop_compile_audit_and_current_phase1_4_schemas",
			"input_compile_audit_schema": ContentCoreVersionScript.MES_NOOP_COMPILE_AUDIT_SCHEMA,
			"container_schema": ContentCoreVersionScript.MES_CONTAINER_SCHEMA,
			"analysis_schema": ContentCoreVersionScript.MES_ANALYSIS_SCHEMA,
			"record_alignment_schema": ContentCoreVersionScript.MES_RECORD_ALIGNMENT_AUDIT_SCHEMA,
			"analyzer_handoff_schema": ContentCoreVersionScript.MES_ANALYZER_HANDOFF_SCHEMA,
		},
		"source_identity": source_identity,
		"compile_audit_sha256": str(compile_audit.payload_sha256),
		"output": {
			"size": payload.size(),
			"entry_count": int(document.header.entry_count),
			"code_offset": int(document.header.code_offset),
			"code_size": int(document.header.code_size),
			"entry_sha256": str(document.entry_sha256),
			"bytecode_sha256": str(document.bytecode_sha256),
			"preamble_sha256": str(output_row.preamble_sha256),
		},
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
			"coverage_matches_compile_audit": true,
		},
	}
	result["payload_sha256"] = fingerprint(result)
	return result


func validate_compile_audit(document: Dictionary) -> Dictionary:
	if (
		str(document.get("schema", ""))
		!= ContentCoreVersionScript.MES_NOOP_COMPILE_AUDIT_SCHEMA
		or not document.get("ok", false)
		or not ContractValues.has_exact_keys(document, COMPILE_AUDIT_KEYS)
	):
		return _error("MES no-op compile audit schema or fields changed.")
	if document.get("producer", {}) != {
		"implementation": "python_phase6_noop_compiler",
		"contract": ContentCoreVersionScript.MES_NOOP_COMPILE_AUDIT_SCHEMA,
	}:
		return _error("MES no-op compile audit producer changed.")
	if document.get("compatibility", {}) != {
		"policy": "exact_editable_ir_v1_no_operations",
		"input_editable_schema": ContentCoreVersionScript.MES_EDITABLE_IR_SCHEMA,
		"input_decompiler_schema": ContentCoreVersionScript.MES_DECOMPILER_IR_SCHEMA,
		"unknown_audit_schema": "reject",
		"unknown_v1_field": "reject",
		"output_policy": "new_file_only",
	}:
		return _error("MES no-op compile audit compatibility changed.")
	var retained_hash := str(document.get("payload_sha256", ""))
	var actual_hash := fingerprint(document)
	if not ContractValues.is_sha256(retained_hash) or actual_hash != retained_hash:
		return _error(
			"MES no-op compile audit fingerprint changed: expected %s, got %s."
			% [retained_hash, actual_hash]
		)
	var source_identity = document.get("source_identity", null)
	if (
		not source_identity is Dictionary
		or str(source_identity.get("entry", "")).is_empty()
		or not ContractValues.has_only_keys(source_identity, SOURCE_IDENTITY_KEYS)
	):
		return _error("MES no-op compile source identity changed.")
	var inputs = document.get("inputs", null)
	if (
		not inputs is Dictionary
		or not ContractValues.has_exact_keys(inputs, ["editable_ir_sha256", "decompiler_ir_sha256"])
		or not ContractValues.is_sha256(str(inputs.get("editable_ir_sha256", "")))
		or not ContractValues.is_sha256(str(inputs.get("decompiler_ir_sha256", "")))
	):
		return _error("MES no-op compile input identity changed.")
	var source = document.get("source", null)
	var output = document.get("output", null)
	if (
		not source is Dictionary
		or not ContractValues.has_exact_keys(source, ["entry_sha256", "bytecode_sha256", "preamble_sha256"])
		or not ContractValues.hash_values(source, ["entry_sha256", "bytecode_sha256", "preamble_sha256"])
		or not output is Dictionary
		or not ContractValues.has_exact_keys(output, [
			"size", "entry_count", "entry_sha256", "code_offset", "code_size",
			"bytecode_sha256", "preamble_sha256",
		])
		or not _integer_values(output, ["size", "entry_count", "code_offset", "code_size"])
		or not ContractValues.hash_values(output, ["entry_sha256", "bytecode_sha256", "preamble_sha256"])
	):
		return _error("MES no-op compile source or output fields changed.")
	if (
		int(output.size) != int(output.code_offset) + int(output.code_size)
		or source != {
			"entry_sha256": output.entry_sha256,
			"bytecode_sha256": output.bytecode_sha256,
			"preamble_sha256": output.preamble_sha256,
		}
	):
		return _error("MES no-op compile output differs from its source hashes.")
	var operations = document.get("operations", null)
	if (
		not operations is Dictionary
		or not ContractValues.has_exact_keys(operations, ["count", "relocation_count"])
		or not _integer_values(operations, ["count", "relocation_count"])
		or int(operations.count) != 0
		or int(operations.relocation_count) != 0
	):
		return _error("MES no-op compile operations changed.")
	var coverage = document.get("coverage", null)
	if (
		not coverage is Dictionary
		or not ContractValues.has_exact_keys(coverage, [
			"region_count", "node_count", "typed_node_count", "opaque_node_count", "code_bytes",
		])
		or not _integer_values(coverage, [
			"region_count", "node_count", "typed_node_count", "opaque_node_count", "code_bytes",
		])
		or int(coverage.node_count)
		!= int(coverage.typed_node_count) + int(coverage.opaque_node_count)
		or int(coverage.code_bytes) != int(output.code_size)
	):
		return _error("MES no-op compile coverage changed.")
	var invariants = document.get("invariants", null)
	if (
		not invariants is Dictionary
		or not ContractValues.has_exact_keys(invariants, COMPILE_INVARIANT_KEYS)
		or not ContractValues.all_true(invariants)
	):
		return _error("MES no-op compile invariants are incomplete.")
	return {
		"ok": true,
		"schema": ContentCoreVersionScript.MES_NOOP_COMPILE_AUDIT_SCHEMA,
		"payload_sha256": retained_hash,
	}


func fingerprint(document: Dictionary) -> String:
	return PayloadFingerprintScript.new().fingerprint(document)


func canonical_payload_json(document: Dictionary) -> String:
	return PayloadFingerprintScript.new().canonical_payload_json(document)


func _integer_values(document: Dictionary, keys: Array) -> bool:
	for key in keys:
		var value = document.get(key, -1)
		if not _is_nonnegative_json_integer(value):
			return false
	return true


func _is_nonnegative_json_integer(value: Variant) -> bool:
	if typeof(value) == TYPE_INT:
		return int(value) >= 0
	if typeof(value) == TYPE_FLOAT:
		return float(value) >= 0.0 and float(value) == floor(float(value))
	return false




func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message}
