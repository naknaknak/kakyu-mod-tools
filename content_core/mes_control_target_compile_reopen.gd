class_name KakyuMesControlTargetCompileReopen
extends RefCounted

const MesContainerScript := preload("res://content_core/mes_container.gd")
const MesAnalysisScript := preload("res://content_core/mes_analysis_index.gd")
const AnalyzerHandoffScript := preload("res://content_core/mes_analyzer_handoff.gd")
const PlanScript := preload("res://content_core/mes_control_target_relocation_plan.gd")
const FingerprintScript := preload("res://content_core/mes_payload_fingerprint.gd")
const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")
const ContractValues := preload("res://content_core/contract_values.gd")

const AUDIT_KEYS := [
	"ok", "schema", "producer", "compatibility", "source_identity", "inputs",
	"source", "output", "operation", "relocation", "target_patches", "coverage",
	"invariants", "payload_sha256",
]
const CONTAINER_KEYS := [
	"size", "entry_count", "code_offset", "code_size", "entry_sha256",
	"bytecode_sha256", "preamble_sha256",
]
const SOURCE_IDENTITY_KEYS := ["archive", "entry", "source_kind", "archive_sha256"]
const COMPATIBILITY := {
	"policy": "exact_message_and_control_target_plans",
	"input_editable_schema": "kakyu_mes_editable_ir/v1",
	"input_decompiler_schema": "kakyu_mes_decompiler_ir/v1",
	"input_message_plan_schema": "kakyu_mes_message_relocation_plan/v1",
	"input_control_plan_schema": "kakyu_mes_control_target_relocation_plan/v2",
	"unknown_audit_schema": "reject",
	"unknown_v1_field": "reject",
	"output_policy": "new_file_only",
	"native_engine_compatibility": "unverified",
}
const INVARIANTS := {
	"message_plan_validated": true,
	"control_target_plan_ready": true,
	"source_target_operands_matched": true,
	"target_patches_applied_exactly": true,
	"output_reopened": true,
	"entry_count_preserved": true,
	"code_size_delta_exact": true,
	"address_table_relocated_exactly": true,
	"nonaddress_preamble_bytes_preserved": true,
	"only_planned_code_ranges_changed": true,
	"opaque_records_not_shifted": true,
	"source_container_not_modified": true,
}


func audit(payload: PackedByteArray, compile_audit: Dictionary) -> Dictionary:
	var validation := validate_compile_audit(compile_audit)
	if not validation.ok:
		return validation
	var output_row: Dictionary = compile_audit.output
	if payload.size() != int(output_row.size) or ContractValues.sha256(payload) != str(output_row.entry_sha256):
		return _error("Compiled MES bytes do not match their control-target compile audit.")
	var source_identity: Dictionary = compile_audit.source_identity.duplicate(true)
	var document := MesContainerScript.new().parse(payload, source_identity)
	if not document.get("ok", false):
		return _error("Compiled control-target MES did not reopen: %s" % document.get("error", "failed"))
	if (
		int(document.header.entry_count) != int(output_row.entry_count)
		or int(document.header.code_offset) != int(output_row.code_offset)
		or int(document.header.code_size) != int(output_row.code_size)
		or str(document.entry_sha256) != str(output_row.entry_sha256)
		or str(document.bytecode_sha256) != str(output_row.bytecode_sha256)
		or ContractValues.sha256(payload.slice(0, int(document.header.code_offset))) != str(output_row.preamble_sha256)
	):
		return _error("GDScript MES container reopen differs from the control-target compile audit.")
	var analysis_builder := MesAnalysisScript.new()
	var analysis := analysis_builder.build(document)
	if not analysis.get("ok", false):
		return _error("Compiled control-target MES Phase 1-4 analysis failed.")
	var coverage: Dictionary = compile_audit.coverage
	var analysis_mode := "strict"
	if not _analysis_partition_matches(analysis, coverage):
		analysis = analysis_builder.build_structural(document)
		analysis_mode = "structural_relocation"
	if not analysis.get("ok", false) or not _analysis_partition_matches(analysis, coverage):
		return _error("GDScript Phase 1-4 node partition differs from the control-target compile audit.")
	var handoff_builder := AnalyzerHandoffScript.new()
	var handoff := handoff_builder.build(document, analysis)
	var verified: Dictionary = handoff_builder.verify(handoff)
	if not verified.get("ok", false):
		return _error("Compiled control-target MES Phase 1-4 handoff failed: %s" % verified.get(
			"error", handoff.get("error", "failed")
		))
	if handoff.source_identity != source_identity:
		return _error("Compiled control-target MES source identity changed during GDScript reopen.")
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
		return _error("GDScript Phase 1-4 coverage differs from the control-target compile audit.")
	var edited_message := _find_edited_message(
		analysis.messages, compile_audit.operation, compile_audit.relocation
	)
	if not edited_message.ok:
		return edited_message
	var patch_verification := _verify_target_patches(
		document.bytecode, analysis, compile_audit.target_patches
	)
	if not patch_verification.ok:
		return patch_verification
	var result := {
		"ok": true,
		"schema": ContentCoreVersionScript.MES_CONTROL_TARGET_REOPEN_AUDIT_SCHEMA,
		"producer": {
			"implementation": "godot_gdscript_phase1_4_control_target_reopen",
			"contract": ContentCoreVersionScript.MES_CONTROL_TARGET_REOPEN_AUDIT_SCHEMA,
		},
		"compatibility": {
			"policy": "exact_control_target_compile_audit_and_current_phase1_4_schemas",
			"input_compile_audit_schema": ContentCoreVersionScript.MES_CONTROL_TARGET_COMPILE_AUDIT_SCHEMA,
			"container_schema": ContentCoreVersionScript.MES_CONTAINER_SCHEMA,
			"analysis_schema": ContentCoreVersionScript.MES_ANALYSIS_SCHEMA,
			"record_alignment_schema": ContentCoreVersionScript.MES_RECORD_ALIGNMENT_AUDIT_SCHEMA,
			"analyzer_handoff_schema": ContentCoreVersionScript.MES_ANALYZER_HANDOFF_SCHEMA,
		},
		"source_identity": source_identity,
		"compile_audit_sha256": str(compile_audit.payload_sha256),
		"output": output_row.duplicate(true),
		"edited_message": edited_message.message,
		"target_relocation": patch_verification.summary,
		"phase1_4": {
			"handoff_sha256": str(handoff.payload_sha256),
			"analysis_mode": analysis_mode,
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
			"target_operand_bytes_reopened": true,
			"target_references_reindexed": true,
			"target_instruction_alignment_preserved": true,
		},
	}
	result["payload_sha256"] = fingerprint(result)
	return result


func _analysis_partition_matches(analysis: Dictionary, coverage: Dictionary) -> bool:
	var typed_count := int((analysis.get("instructions", []) as Array).size())
	var opaque_count := int((analysis.get("opaque_boundaries", []) as Array).size())
	return (
		int(coverage.get("source_typed_node_count", -1)) == typed_count
		and int(coverage.get("source_opaque_node_count", -1)) == opaque_count
		and int(coverage.get("source_node_count", -1)) == typed_count + opaque_count
	)


func validate_compile_audit(document: Dictionary) -> Dictionary:
	if (
		document.get("ok") != true
		or str(document.get("schema", "")) != ContentCoreVersionScript.MES_CONTROL_TARGET_COMPILE_AUDIT_SCHEMA
		or not ContractValues.has_exact_keys(document, AUDIT_KEYS)
	):
		return _error("MES control-target compile audit schema or fields changed.")
	if document.get("producer") != {
		"implementation": "python_phase6_control_target_compiler",
		"contract": ContentCoreVersionScript.MES_CONTROL_TARGET_COMPILE_AUDIT_SCHEMA,
	}:
		return _error("MES control-target compile audit producer changed.")
	if document.get("compatibility") != COMPATIBILITY:
		return _error("MES control-target compile compatibility changed.")
	var retained_hash := str(document.get("payload_sha256", ""))
	if not ContractValues.is_sha256(retained_hash) or fingerprint(document) != retained_hash:
		return _error("MES control-target compile audit fingerprint changed.")
	var source_identity = document.get("source_identity")
	if (
		not source_identity is Dictionary
		or not ContractValues.has_only_keys(source_identity, SOURCE_IDENTITY_KEYS)
		or str(source_identity.get("entry", "")).is_empty()
		or not ContractValues.is_sha256(str(source_identity.get("archive_sha256", "")))
	):
		return _error("MES control-target compile source identity changed.")
	var inputs = document.get("inputs")
	if (
		not inputs is Dictionary
		or not ContractValues.has_exact_keys(inputs, [
			"editable_ir_sha256", "decompiler_ir_sha256",
			"message_relocation_plan_sha256", "control_target_plan_sha256",
		])
		or not ContractValues.all_hash_values(inputs)
	):
		return _error("MES control-target compile input identity changed.")
	var source = document.get("source")
	var output = document.get("output")
	if not _valid_container_summary(source) or not _valid_container_summary(output):
		return _error("MES control-target compile container summary changed.")
	var operation = document.get("operation")
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
		or not ContractValues.is_sha256(str(operation.source_raw_sha256))
		or not ContractValues.is_sha256(str(operation.replacement_raw_sha256))
	):
		return _error("MES control-target compile operation changed.")
	var relocation = document.get("relocation")
	if (
		not relocation is Dictionary
		or not ContractValues.has_exact_keys(relocation, [
			"delta", "pivot_source_end", "source_code_size", "output_code_size",
			"source_instruction_start", "source_instruction_end", "output_instruction_end",
			"address_table_update_count", "affected_reference_count", "target_patch_count",
		])
		or not ContractValues.json_integer(relocation.get("delta", 0))
		or not ContractValues.nonnegative_integer_values(relocation, [
			"pivot_source_end", "source_code_size", "output_code_size",
			"source_instruction_start", "source_instruction_end", "output_instruction_end",
			"address_table_update_count", "affected_reference_count", "target_patch_count",
		])
		or int(relocation.delta) != int(operation.replacement_byte_length) - int(operation.source_byte_length)
		or int(relocation.output_code_size) != int(relocation.source_code_size) + int(relocation.delta)
		or int(relocation.output_instruction_end) != int(relocation.source_instruction_end) + int(relocation.delta)
	):
		return _error("MES control-target compile relocation changed.")
	var patches = document.get("target_patches")
	if not patches is Array or patches.size() != int(relocation.target_patch_count):
		return _error("MES control-target compile patch count changed.")
	var patch_validation := PlanScript.new().validate_patch_rows(patches, relocation)
	if not patch_validation.ok:
		return patch_validation
	var coverage = document.get("coverage")
	if (
		not coverage is Dictionary
		or not ContractValues.has_exact_keys(coverage, [
			"output_region_count", "source_node_count", "source_typed_node_count",
			"source_opaque_node_count", "source_code_bytes", "output_code_bytes",
		])
		or not ContractValues.nonnegative_integer_values(coverage, coverage.keys())
		or int(coverage.source_node_count) != int(coverage.source_typed_node_count) + int(coverage.source_opaque_node_count)
		or int(coverage.source_code_bytes) != int(source.code_size)
		or int(coverage.output_code_bytes) != int(output.code_size)
		or int(relocation.source_code_size) != int(source.code_size)
		or int(relocation.output_code_size) != int(output.code_size)
		or int(output.entry_count) != int(source.entry_count)
		or int(output.code_offset) != int(source.code_offset)
		or int(output.size) != int(source.size) + int(relocation.delta)
	):
		return _error("MES control-target compile coverage changed.")
	if document.get("invariants") != INVARIANTS:
		return _error("MES control-target compile invariants changed.")
	return {
		"ok": true,
		"schema": ContentCoreVersionScript.MES_CONTROL_TARGET_COMPILE_AUDIT_SCHEMA,
		"payload_sha256": retained_hash,
	}


func fingerprint(document: Dictionary) -> String:
	return FingerprintScript.new().fingerprint(document)


func _find_edited_message(messages: Array, operation: Dictionary, relocation: Dictionary) -> Dictionary:
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
		or int((message.raw_bytes as PackedByteArray).size()) != int(operation.replacement_byte_length)
		or str(message.raw_sha256) != str(operation.replacement_raw_sha256)
	):
		return _error("Compiled MES edited message differs from its control-target audit.")
	return {
		"ok": true,
		"message": {
			"source_offset": int(message.source_offset),
			"end_offset": int(message.end_offset),
			"byte_length": int((message.raw_bytes as PackedByteArray).size()),
			"raw_sha256": str(message.raw_sha256),
		},
	}


func _verify_target_patches(code: PackedByteArray, analysis: Dictionary, patches: Array) -> Dictionary:
	var typed_starts := {}
	var instructions_by_start := {}
	for untyped_instruction in analysis.instructions:
		var instruction: Dictionary = untyped_instruction
		typed_starts[int(instruction.source_offset)] = true
		instructions_by_start[int(instruction.source_offset)] = instruction
	var branch_count := 0
	var continuation_count := 0
	var definition_skip_count := 0
	for untyped_patch in patches:
		var patch: Dictionary = untyped_patch
		var operand_start := int(patch.output_operand_start)
		var operand_end := int(patch.output_operand_end)
		if code.slice(operand_start, operand_end).hex_encode() != str(patch.output_raw_hex):
			return _error("Compiled MES target operand bytes differ from the audit.")
		var owner: Dictionary = instructions_by_start.get(int(patch.output_instruction_start), {})
		if (
			owner.is_empty()
			or int(owner.end_offset) != int(patch.output_instruction_end)
			or int(owner.command_id) != int(patch.command_id)
			or str(owner.op) != str(patch.owner_op)
			or not typed_starts.has(int(patch.output_target_offset))
		):
			return _error("Compiled MES target instruction alignment changed.")
		if str(patch.reference_kind) == "definition_skip_target":
			var operands: Array = owner.get("operands", [])
			var target_bytes: Array = (
				operands[1].get("value", [])
				if operands.size() == 2 and operands[1] is Dictionary
				else []
			)
			if (
				target_bytes.size() != 4
				or _u32_from_bytes(target_bytes) != int(patch.output_target_offset)
			):
				return _error("Compiled MES definition skip target did not reindex exactly.")
			definition_skip_count += 1
		else:
			var matches: Array[Dictionary] = []
			for untyped_reference in analysis.code_references:
				var reference: Dictionary = untyped_reference
				if (
					int(reference.source_offset) == int(patch.output_instruction_start)
					and str(reference.kind) == str(patch.reference_kind)
					and int(reference.target_offset) == int(patch.output_target_offset)
				):
					matches.append(reference)
			if matches.size() != 1 or matches[0].get("aligned") != true or matches[0].get("in_code") != true:
				return _error("Compiled MES target reference did not reindex exactly.")
		if str(patch.reference_kind) == "condition_false_target":
			branch_count += 1
		elif str(patch.reference_kind) == "continuation_target":
			continuation_count += 1
	return {
		"ok": true,
		"summary": {
			"patch_count": patches.size(),
			"branch_patch_count": branch_count,
			"continuation_patch_count": continuation_count,
			"definition_skip_patch_count": definition_skip_count,
		},
	}


func _u32_from_bytes(bytes: Array) -> int:
	return (
		int(bytes[0])
		| (int(bytes[1]) << 8)
		| (int(bytes[2]) << 16)
		| (int(bytes[3]) << 24)
	)


func _valid_container_summary(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	var row: Dictionary = value
	return (
		ContractValues.has_exact_keys(row, CONTAINER_KEYS)
		and ContractValues.nonnegative_integer_values(row, ["size", "entry_count", "code_offset", "code_size"])
		and ContractValues.is_sha256(str(row.get("entry_sha256", "")))
		and ContractValues.is_sha256(str(row.get("bytecode_sha256", "")))
		and ContractValues.is_sha256(str(row.get("preamble_sha256", "")))
		and int(row.size) == int(row.code_offset) + int(row.code_size)
	)


func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message}
