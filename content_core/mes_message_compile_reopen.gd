class_name KakyuMesMessageCompileReopen
extends RefCounted

const MesContainerScript := preload("res://content_core/mes_container.gd")
const MesAnalysisScript := preload("res://content_core/mes_analysis_index.gd")
const AnalyzerHandoffScript := preload("res://content_core/mes_analyzer_handoff.gd")
const FingerprintScript := preload("res://content_core/mes_payload_fingerprint.gd")
const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")
const ContractValues := preload("res://content_core/contract_values.gd")

const COMPILE_AUDIT_KEYS := [
	"ok", "schema", "producer", "compatibility", "source_identity", "inputs",
	"source", "output", "operation", "relocation", "coverage", "invariants",
	"payload_sha256",
]
const CONTAINER_KEYS := [
	"size", "entry_count", "code_offset", "code_size", "entry_sha256",
	"bytecode_sha256", "preamble_sha256",
]
const COMPILE_INVARIANT_KEYS := [
	"plan_ready", "output_reopened", "entry_count_preserved",
	"code_size_delta_exact", "address_table_relocated_exactly",
	"nonaddress_preamble_bytes_preserved", "code_prefix_preserved",
	"replacement_node_exact", "code_suffix_preserved",
	"opaque_records_not_shifted", "source_container_not_modified",
]
const SOURCE_IDENTITY_KEYS := ["archive", "entry", "source_kind", "archive_sha256"]


func audit(payload: PackedByteArray, compile_audit: Dictionary) -> Dictionary:
	var validation := validate_compile_audit(compile_audit)
	if not validation.get("ok", false):
		return validation
	var output_row: Dictionary = compile_audit.output
	if payload.size() != int(output_row.size) or ContractValues.sha256(payload) != str(output_row.entry_sha256):
		return _error("Compiled MES bytes do not match their message compile audit.")
	var source_identity: Dictionary = compile_audit.source_identity.duplicate(true)
	var document := MesContainerScript.new().parse(payload, source_identity)
	if not document.get("ok", false):
		return _error("Compiled message MES did not reopen: %s" % document.get("error", "failed"))
	if (
		int(document.header.entry_count) != int(output_row.entry_count)
		or int(document.header.code_offset) != int(output_row.code_offset)
		or int(document.header.code_size) != int(output_row.code_size)
		or str(document.entry_sha256) != str(output_row.entry_sha256)
		or str(document.bytecode_sha256) != str(output_row.bytecode_sha256)
		or ContractValues.sha256(payload.slice(0, int(document.header.code_offset)))
		!= str(output_row.preamble_sha256)
	):
		return _error("GDScript MES container reopen differs from the message compile audit.")
	var analysis := MesAnalysisScript.new().build(document)
	if not analysis.get("ok", false):
		return _error("Compiled message MES Phase 1-4 analysis failed.")
	var handoff_builder := AnalyzerHandoffScript.new()
	var handoff := handoff_builder.build(document, analysis)
	var verified: Dictionary = handoff_builder.verify(handoff)
	if not verified.get("ok", false):
		return _error("Compiled message MES Phase 1-4 handoff failed: %s" % verified.get(
			"error", handoff.get("error", "failed")
		))
	if handoff.source_identity != source_identity:
		return _error("Compiled message MES source identity changed during GDScript reopen.")
	var coverage: Dictionary = compile_audit.coverage
	var alignment: Dictionary = handoff.record_alignment
	var typed_count := int((handoff.typed_ir.instructions as Array).size())
	var opaque_count := int((handoff.typed_ir.opaque_boundaries as Array).size())
	if (
		int(coverage.output_region_count) != int(alignment.region_count)
		or int(coverage.source_typed_node_count) != typed_count
		or int(coverage.source_opaque_node_count) != opaque_count
		or int(coverage.source_node_count) != typed_count + opaque_count
		or int(coverage.output_code_bytes) != int(document.header.code_size)
		or int(alignment.framed_bytes) != int(document.header.code_size)
	):
		return _error("GDScript Phase 1-4 coverage differs from the message compile audit.")
	var operation: Dictionary = compile_audit.operation
	var relocation: Dictionary = compile_audit.relocation
	var edited_message := _find_edited_message(analysis.messages, operation, relocation)
	if not edited_message.get("ok", false):
		return edited_message
	var result := {
		"ok": true,
		"schema": ContentCoreVersionScript.MES_MESSAGE_REOPEN_AUDIT_SCHEMA,
		"producer": {
			"implementation": "godot_gdscript_phase1_4_message_reopen",
			"contract": ContentCoreVersionScript.MES_MESSAGE_REOPEN_AUDIT_SCHEMA,
		},
		"compatibility": {
			"policy": "exact_message_compile_audit_and_current_phase1_4_schemas",
			"input_compile_audit_schema": ContentCoreVersionScript.MES_MESSAGE_COMPILE_AUDIT_SCHEMA,
			"container_schema": ContentCoreVersionScript.MES_CONTAINER_SCHEMA,
			"analysis_schema": ContentCoreVersionScript.MES_ANALYSIS_SCHEMA,
			"record_alignment_schema": ContentCoreVersionScript.MES_RECORD_ALIGNMENT_AUDIT_SCHEMA,
			"analyzer_handoff_schema": ContentCoreVersionScript.MES_ANALYZER_HANDOFF_SCHEMA,
		},
		"source_identity": source_identity,
		"compile_audit_sha256": str(compile_audit.payload_sha256),
		"output": output_row.duplicate(true),
		"edited_message": edited_message.message,
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
			"source_node_partition_preserved": true,
			"replacement_message_reindexed": true,
		},
	}
	result["payload_sha256"] = fingerprint(result)
	return result


func validate_compile_audit(document: Dictionary) -> Dictionary:
	if (
		str(document.get("schema", "")) != ContentCoreVersionScript.MES_MESSAGE_COMPILE_AUDIT_SCHEMA
		or document.get("ok", false) != true
		or not ContractValues.has_exact_keys(document, COMPILE_AUDIT_KEYS)
	):
		return _error("MES message compile audit schema or fields changed.")
	if document.get("producer", {}) != {
		"implementation": "python_phase6_message_compiler",
		"contract": ContentCoreVersionScript.MES_MESSAGE_COMPILE_AUDIT_SCHEMA,
	}:
		return _error("MES message compile audit producer changed.")
	if document.get("compatibility", {}) != {
		"policy": "blocker_free_message_plan_only",
		"input_editable_schema": ContentCoreVersionScript.MES_EDITABLE_IR_SCHEMA,
		"input_plan_schema": ContentCoreVersionScript.MES_MESSAGE_RELOCATION_PLAN_SCHEMA,
		"input_decompiler_schema": ContentCoreVersionScript.MES_DECOMPILER_IR_SCHEMA,
		"unknown_audit_schema": "reject",
		"unknown_v1_field": "reject",
		"output_policy": "new_file_only",
		"native_engine_compatibility": "unverified",
	}:
		return _error("MES message compile compatibility changed.")
	var retained_hash := str(document.get("payload_sha256", ""))
	if not ContractValues.is_sha256(retained_hash) or fingerprint(document) != retained_hash:
		return _error("MES message compile audit fingerprint changed.")
	var source_identity = document.get("source_identity", null)
	if (
		not source_identity is Dictionary
		or str(source_identity.get("entry", "")).is_empty()
		or not ContractValues.has_only_keys(source_identity, SOURCE_IDENTITY_KEYS)
	):
		return _error("MES message compile source identity changed.")
	var inputs = document.get("inputs", null)
	if (
		not inputs is Dictionary
		or not ContractValues.has_exact_keys(inputs, [
			"editable_ir_sha256", "decompiler_ir_sha256", "relocation_plan_sha256",
		])
		or not ContractValues.hash_values(inputs, [
			"editable_ir_sha256", "decompiler_ir_sha256", "relocation_plan_sha256",
		])
	):
		return _error("MES message compile input identity changed.")
	var source = document.get("source", null)
	var output = document.get("output", null)
	if not _valid_container_summary(source) or not _valid_container_summary(output):
		return _error("MES message compile container summary changed.")
	var operation = document.get("operation", null)
	if (
		not operation is Dictionary
		or not ContractValues.has_exact_keys(operation, [
			"kind", "source_offset", "source_raw_sha256", "replacement_raw_sha256",
			"source_byte_length", "replacement_byte_length", "encoding",
		])
		or str(operation.kind) != "replace_message"
		or str(operation.encoding) != "cp932"
		or not ContractValues.nonnegative_integer_values(operation, [
			"source_offset", "source_byte_length", "replacement_byte_length",
		])
		or not ContractValues.hash_values(operation, ["source_raw_sha256", "replacement_raw_sha256"])
	):
		return _error("MES message compile operation changed.")
	var relocation = document.get("relocation", null)
	if (
		not relocation is Dictionary
		or not ContractValues.has_exact_keys(relocation, [
			"delta", "source_instruction_start", "source_instruction_end",
			"output_instruction_end", "address_table_update_count",
			"affected_reference_count",
		])
		or not ContractValues.json_integer(relocation.delta)
		or not ContractValues.nonnegative_integer_values(relocation, [
			"source_instruction_start", "source_instruction_end", "output_instruction_end",
			"address_table_update_count", "affected_reference_count",
		])
		or int(relocation.source_instruction_end) <= int(relocation.source_instruction_start)
		or int(relocation.output_instruction_end) <= int(relocation.source_instruction_start)
		or int(relocation.delta)
		!= int(operation.replacement_byte_length) - int(operation.source_byte_length)
		or int(relocation.output_instruction_end)
		!= int(relocation.source_instruction_end) + int(relocation.delta)
	):
		return _error("MES message compile relocation changed.")
	var coverage = document.get("coverage", null)
	if (
		not coverage is Dictionary
		or not ContractValues.has_exact_keys(coverage, [
			"output_region_count", "source_node_count", "source_typed_node_count",
			"source_opaque_node_count", "source_code_bytes", "output_code_bytes",
		])
		or not ContractValues.nonnegative_integer_values(coverage, [
			"output_region_count", "source_node_count", "source_typed_node_count",
			"source_opaque_node_count", "source_code_bytes", "output_code_bytes",
		])
		or int(coverage.source_node_count)
		!= int(coverage.source_typed_node_count) + int(coverage.source_opaque_node_count)
		or int(coverage.source_code_bytes) != int(source.code_size)
		or int(coverage.output_code_bytes) != int(output.code_size)
		or int(output.entry_count) != int(source.entry_count)
		or int(output.code_offset) != int(source.code_offset)
		or int(output.code_size) != int(source.code_size) + int(relocation.delta)
		or int(output.size) != int(source.size) + int(relocation.delta)
	):
		return _error("MES message compile coverage changed.")
	var invariants = document.get("invariants", null)
	if (
		not invariants is Dictionary
		or not ContractValues.has_exact_keys(invariants, COMPILE_INVARIANT_KEYS)
		or not ContractValues.all_true(invariants)
	):
		return _error("MES message compile invariants changed.")
	return {
		"ok": true,
		"schema": ContentCoreVersionScript.MES_MESSAGE_COMPILE_AUDIT_SCHEMA,
		"payload_sha256": retained_hash,
	}


func fingerprint(document: Dictionary) -> String:
	return FingerprintScript.new().fingerprint(document)


func _find_edited_message(
	messages: Array, operation: Dictionary, relocation: Dictionary
) -> Dictionary:
	var matches: Array[Dictionary] = []
	for untyped_message in messages:
		var message: Dictionary = untyped_message
		if int(message.source_offset) == int(operation.source_offset):
			matches.append(message)
	if matches.size() != 1:
		return _error("Compiled MES edited message was not uniquely reindexed.")
	var message: Dictionary = matches[0]
	if (
		int(message.end_offset) != int(relocation.output_instruction_end)
		or int((message.raw_bytes as PackedByteArray).size())
		!= int(operation.replacement_byte_length)
		or str(message.raw_sha256) != str(operation.replacement_raw_sha256)
	):
		return _error("Compiled MES edited message differs from its compile audit.")
	return {
		"ok": true,
		"message": {
			"source_offset": int(message.source_offset),
			"end_offset": int(message.end_offset),
			"byte_length": int((message.raw_bytes as PackedByteArray).size()),
			"raw_sha256": str(message.raw_sha256),
		},
	}


func _valid_container_summary(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	var row: Dictionary = value
	return (
		ContractValues.has_exact_keys(row, CONTAINER_KEYS)
		and ContractValues.nonnegative_integer_values(row, ["size", "entry_count", "code_offset", "code_size"])
		and ContractValues.hash_values(row, ["entry_sha256", "bytecode_sha256", "preamble_sha256"])
		and int(row.size) == int(row.code_offset) + int(row.code_size)
	)


func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message}
