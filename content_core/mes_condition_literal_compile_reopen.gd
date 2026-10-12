class_name KakyuMesConditionLiteralCompileReopen
extends RefCounted

const CompileCoverageScript := preload("res://content_core/mes_compile_coverage.gd")

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
	"kind", "source_offset", "literal_offset", "source_value",
	"replacement_value", "width", "false_target",
]
const TARGET_KEYS := [
	"node_id", "region_id", "instruction_start", "instruction_end",
	"condition_start", "condition_end", "literal_start", "literal_end",
	"source_instruction_sha256", "replacement_instruction_sha256",
	"source_condition_sha256", "replacement_condition_sha256",
	"source_literal_sha256", "replacement_literal_sha256",
	"false_target_reference_id", "false_target_operand_start",
	"false_target_operand_end", "false_target_operand_sha256",
]
const COVERAGE_KEYS := [
	"region_count", "node_count", "typed_node_count", "opaque_node_count", "code_bytes",
]
const INVARIANT_KEYS := [
	"plan_ready", "output_reopened", "container_size_preserved",
	"entry_count_preserved", "code_offset_preserved", "code_size_preserved",
	"address_table_preserved", "preamble_preserved", "code_prefix_preserved",
	"replacement_instruction_exact", "code_suffix_preserved",
	"condition_terminator_preserved", "false_target_operand_preserved",
	"source_container_not_modified",
]
const SOURCE_IDENTITY_KEYS := ["archive", "entry", "source_kind", "archive_sha256"]
const COMPATIBILITY := {
	"policy": "exact_same_width_condition_literal_plan_only",
	"input_editable_schema": "kakyu_mes_editable_ir/v1",
	"input_plan_schema": "kakyu_mes_condition_literal_edit_plan/v1",
	"input_decompiler_schema": "kakyu_mes_decompiler_ir/v1",
	"unknown_audit_schema": "reject",
	"unknown_v1_field": "reject",
	"output_policy": "new_file_only",
	"relocation": "forbidden",
	"native_engine_compatibility": "unverified",
}


func audit(payload: PackedByteArray, compile_audit: Dictionary) -> Dictionary:
	var validation := validate_compile_audit(compile_audit)
	if not validation.ok:
		return validation
	var output_row: Dictionary = compile_audit.output
	if payload.size() != int(output_row.size) or ContractValues.sha256(payload) != str(output_row.entry_sha256):
		return _error("Compiled MES bytes do not match their condition literal compile audit.")
	var source_identity: Dictionary = compile_audit.source_identity.duplicate(true)
	var document := MesContainerScript.new().parse(payload, source_identity)
	if not document.get("ok", false):
		return _error("Compiled condition literal MES did not reopen: %s" % document.get(
			"error", "failed"
		))
	var code_offset := int(document.header.code_offset)
	var preamble := payload.slice(0, code_offset)
	if (
		int(document.header.entry_count) != int(output_row.entry_count)
		or code_offset != int(output_row.code_offset)
		or int(document.header.code_size) != int(output_row.code_size)
		or str(document.entry_sha256) != str(output_row.entry_sha256)
		or str(document.bytecode_sha256) != str(output_row.bytecode_sha256)
		or ContractValues.sha256(preamble) != str(output_row.preamble_sha256)
		or ContractValues.sha256(preamble) != str(output_row.address_table_sha256)
	):
		return _error("GDScript MES container reopen differs from the condition literal compile audit.")
	var analysis := MesAnalysisScript.new().build(document)
	if not analysis.get("ok", false):
		return _error("Compiled condition literal MES Phase 1-4 analysis failed.")
	var handoff_builder := AnalyzerHandoffScript.new()
	var handoff := handoff_builder.build(document, analysis)
	var verified: Dictionary = handoff_builder.verify(handoff)
	if not verified.get("ok", false):
		return _error("Compiled condition literal MES Phase 1-4 handoff failed: %s" % verified.get(
			"error", handoff.get("error", "failed")
		))
	if handoff.source_identity != source_identity:
		return _error("Compiled condition literal MES source identity changed during reopen.")
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
		return _error("GDScript Phase 1-4 coverage differs from the condition literal compile audit.")
	var edited_branch := _find_edited_branch(
		analysis.instructions,
		analysis.code_references,
		document.bytecode,
		compile_audit.operation,
		compile_audit.target
	)
	if not edited_branch.ok:
		return edited_branch
	var result := {
		"ok": true,
		"schema": ContentCoreVersionScript.MES_CONDITION_LITERAL_REOPEN_AUDIT_SCHEMA,
		"producer": {
			"implementation": "godot_gdscript_phase1_4_condition_literal_reopen",
			"contract": ContentCoreVersionScript.MES_CONDITION_LITERAL_REOPEN_AUDIT_SCHEMA,
		},
		"compatibility": {
			"policy": "exact_condition_literal_compile_audit_and_current_phase1_4_schemas",
			"input_compile_audit_schema": ContentCoreVersionScript.MES_CONDITION_LITERAL_COMPILE_AUDIT_SCHEMA,
			"container_schema": ContentCoreVersionScript.MES_CONTAINER_SCHEMA,
			"analysis_schema": ContentCoreVersionScript.MES_ANALYSIS_SCHEMA,
			"record_alignment_schema": ContentCoreVersionScript.MES_RECORD_ALIGNMENT_AUDIT_SCHEMA,
			"analyzer_handoff_schema": ContentCoreVersionScript.MES_ANALYZER_HANDOFF_SCHEMA,
		},
		"source_identity": source_identity,
		"compile_audit_sha256": str(compile_audit.payload_sha256),
		"output": output_row.duplicate(true),
		"edited_branch": edited_branch.branch,
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
			"replacement_branch_reindexed": true,
			"replacement_literal_reindexed": true,
			"false_target_reindexed": true,
		},
	}
	result["payload_sha256"] = fingerprint(result)
	return result


func validate_compile_audit(document: Dictionary) -> Dictionary:
	if (
		document.get("ok") != true
		or str(document.get("schema", ""))
		!= ContentCoreVersionScript.MES_CONDITION_LITERAL_COMPILE_AUDIT_SCHEMA
		or not ContractValues.has_exact_keys(document, AUDIT_KEYS)
	):
		return _error("MES condition literal compile audit schema or fields changed.")
	if document.get("producer") != {
		"implementation": "python_phase6_condition_literal_compiler",
		"contract": ContentCoreVersionScript.MES_CONDITION_LITERAL_COMPILE_AUDIT_SCHEMA,
	}:
		return _error("MES condition literal compile audit producer changed.")
	if document.get("compatibility") != COMPATIBILITY:
		return _error("MES condition literal compile compatibility changed.")
	var retained_hash := str(document.get("payload_sha256", ""))
	if not ContractValues.is_sha256(retained_hash) or fingerprint(document) != retained_hash:
		return _error("MES condition literal compile audit fingerprint changed.")
	var source_identity = document.get("source_identity")
	if (
		not source_identity is Dictionary
		or str(source_identity.get("entry", "")).is_empty()
		or not ContractValues.has_only_keys(source_identity, SOURCE_IDENTITY_KEYS)
	):
		return _error("MES condition literal compile source identity changed.")
	var inputs = document.get("inputs")
	if (
		not inputs is Dictionary
		or not ContractValues.has_exact_keys(inputs, [
			"editable_ir_sha256", "decompiler_ir_sha256",
			"condition_literal_plan_sha256",
		])
		or not ContractValues.hash_values(inputs, [
			"editable_ir_sha256", "decompiler_ir_sha256",
			"condition_literal_plan_sha256",
		])
	):
		return _error("MES condition literal compile input identity changed.")
	var source = document.get("source")
	var output = document.get("output")
	if not _valid_summary(source) or not _valid_summary(output):
		return _error("MES condition literal compile container summary changed.")
	if (
		int(output.size) != int(source.size)
		or int(output.entry_count) != int(source.entry_count)
		or int(output.code_offset) != int(source.code_offset)
		or int(output.code_size) != int(source.code_size)
		or str(output.preamble_sha256) != str(source.preamble_sha256)
		or str(output.address_table_sha256) != str(source.address_table_sha256)
	):
		return _error("MES condition literal compile layout preservation changed.")
	var operation = document.get("operation")
	if (
		not operation is Dictionary
		or not ContractValues.has_exact_keys(operation, OPERATION_KEYS)
		or str(operation.get("kind", "")) != "replace_condition_literal"
		or not ContractValues.nonnegative_integer_values(operation, OPERATION_KEYS.slice(1))
		or int(operation.width) not in [8, 16, 32]
	):
		return _error("MES condition literal compile operation changed.")
	var target = document.get("target")
	if (
		not target is Dictionary
		or not ContractValues.has_exact_keys(target, TARGET_KEYS)
		or str(target.get("node_id", "")).is_empty()
		or str(target.get("region_id", "")).is_empty()
		or str(target.get("false_target_reference_id", "")).is_empty()
		or not ContractValues.nonnegative_integer_values(target, [
			"instruction_start", "instruction_end", "condition_start", "condition_end",
			"literal_start", "literal_end", "false_target_operand_start",
			"false_target_operand_end",
		])
		or not ContractValues.hash_values(target, [
			"source_instruction_sha256", "replacement_instruction_sha256",
			"source_condition_sha256", "replacement_condition_sha256",
			"source_literal_sha256", "replacement_literal_sha256",
			"false_target_operand_sha256",
		])
		or int(target.instruction_end) <= int(target.instruction_start)
		or int(target.condition_start) != int(target.instruction_start) + 1
		or int(target.literal_start) < int(target.condition_start)
		or int(target.literal_end) > int(target.condition_end) - 1
		or int(target.false_target_operand_start) != int(target.condition_end)
		or int(target.false_target_operand_end) != int(target.instruction_end)
		or int(operation.source_offset) != int(target.instruction_start)
		or int(operation.literal_offset) != int(target.literal_start)
	):
		return _error("MES condition literal compile target changed.")
	var coverage = document.get("coverage")
	if (
		not coverage is Dictionary
		or not ContractValues.has_exact_keys(coverage, COVERAGE_KEYS)
		or not ContractValues.nonnegative_integer_values(coverage, COVERAGE_KEYS)
		or int(coverage.node_count) != int(coverage.typed_node_count) + int(coverage.opaque_node_count)
		or int(coverage.code_bytes) != int(source.code_size)
	):
		return _error("MES condition literal compile coverage changed.")
	var invariants = document.get("invariants")
	if (
		not invariants is Dictionary
		or not ContractValues.has_exact_keys(invariants, INVARIANT_KEYS)
		or not ContractValues.all_true(invariants)
	):
		return _error("MES condition literal compile invariants changed.")
	return {
		"ok": true,
		"schema": ContentCoreVersionScript.MES_CONDITION_LITERAL_COMPILE_AUDIT_SCHEMA,
		"payload_sha256": retained_hash,
	}


func fingerprint(document: Dictionary) -> String:
	return FingerprintScript.new().fingerprint(document)


func _find_edited_branch(
	instructions: Array,
	code_references: Array,
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
		return _error("Compiled MES edited condition branch was not uniquely reindexed.")
	var instruction: Dictionary = matches[0]
	if (
		str(instruction.op) != "branch_if_not_true"
		or int(instruction.end_offset) != int(target.instruction_end)
		or ContractValues.sha256(str(instruction.raw_hex).hex_decode())
		!= str(target.replacement_instruction_sha256)
	):
		return _error("Compiled MES edited condition instruction differs from its audit.")
	var operands: Array = instruction.get("operands", [])
	if operands.size() != 2:
		return _error("Compiled MES edited condition operands changed.")
	var condition_owner: Dictionary = operands[0]
	var target_operand: Dictionary = operands[1]
	if (
		str(condition_owner.get("type", "")) != "condition"
		or not condition_owner.get("value") is Dictionary
		or str(target_operand.get("type", "")) != "code_offset"
		or int(target_operand.get("value", -1)) != int(operation.false_target)
	):
		return _error("Compiled MES edited condition operand typing changed.")
	var condition: Dictionary = condition_owner.value
	if (
		int(condition.get("offset", -1)) != int(target.condition_start)
		or int(condition.get("end_offset", -1)) != int(target.condition_end)
		or ContractValues.sha256(str(condition.get("raw_hex", "")).hex_decode())
		!= str(target.replacement_condition_sha256)
	):
		return _error("Compiled MES edited condition expression differs from its audit.")
	var literal_matches: Array[Dictionary] = []
	_collect_literals(condition.get("ast"), int(target.literal_start), literal_matches)
	if literal_matches.size() != 1:
		return _error("Compiled MES edited condition literal was not uniquely reindexed.")
	var literal: Dictionary = literal_matches[0]
	var literal_bytes := code.slice(int(target.literal_start), int(target.literal_end))
	if (
		int(literal.get("value", -1)) != int(operation.replacement_value)
		or int(literal.get("width", -1)) != int(operation.width)
		or ContractValues.sha256(literal_bytes) != str(target.replacement_literal_sha256)
		or int(code[int(target.condition_end) - 1]) != 0xFF
	):
		return _error("Compiled MES edited condition literal differs from its audit.")
	var false_target_bytes := code.slice(
		int(target.false_target_operand_start), int(target.false_target_operand_end)
	)
	if (
		false_target_bytes.size() != 4
		or ContractValues.sha256(false_target_bytes) != str(target.false_target_operand_sha256)
		or int(false_target_bytes.decode_u32(0)) != int(operation.false_target)
	):
		return _error("Compiled MES edited condition false target differs from its audit.")
	var reference_matches: Array[Dictionary] = []
	for untyped_reference in code_references:
		var reference: Dictionary = untyped_reference
		if (
			int(reference.get("source_offset", -1)) == int(target.instruction_start)
			and str(reference.get("op", "")) == "branch_if_not_true"
			and str(reference.get("kind", "")) == "condition_false_target"
		):
			reference_matches.append(reference)
	if (
		reference_matches.size() != 1
		or int(reference_matches[0].get("target_offset", -1)) != int(operation.false_target)
	):
		return _error("Compiled MES edited condition target reference differs from its audit.")
	return {
		"ok": true,
		"branch": {
			"op": str(instruction.op),
			"instruction_start": int(instruction.source_offset),
			"instruction_end": int(instruction.end_offset),
			"instruction_sha256": str(target.replacement_instruction_sha256),
			"condition_start": int(condition.offset),
			"condition_end": int(condition.end_offset),
			"condition_sha256": str(target.replacement_condition_sha256),
			"literal_start": int(target.literal_start),
			"literal_end": int(target.literal_end),
			"literal_sha256": str(target.replacement_literal_sha256),
			"value": int(literal.value),
			"width": int(literal.width),
			"false_target_reference_id": str(target.false_target_reference_id),
			"false_target": int(operation.false_target),
			"false_target_operand_sha256": str(target.false_target_operand_sha256),
		},
	}


func _collect_literals(value: Variant, source_offset: int, output: Array[Dictionary]) -> void:
	if value is Dictionary:
		var row: Dictionary = value
		var source = row.get("source")
		if (
			str(row.get("type", "")) == "literal"
			and source is Dictionary
			and int(source.get("offset", -1)) == source_offset
		):
			output.append(row)
		for child in row.values():
			_collect_literals(child, source_offset, output)
	elif value is Array:
		for child in value:
			_collect_literals(child, source_offset, output)


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
