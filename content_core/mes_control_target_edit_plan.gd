class_name KakyuMesControlTargetEditPlan
extends RefCounted

const ArcReaderScript := preload("res://content_core/arc_reader.gd")
const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")
const FingerprintScript := preload("res://content_core/mes_payload_fingerprint.gd")
const ContractValues := preload("res://content_core/contract_values.gd")

const PLAN_KEYS := [
	"ok", "schema", "producer", "compatibility", "source_identity", "inputs",
	"operation", "source_control", "replacement_target", "patch", "coverage",
	"assembly_ready", "invariants", "payload_sha256",
]
const OPERATION_KEYS := [
	"kind", "source_offset", "reference_kind", "source_instruction_raw_sha256",
	"replacement_target_offset", "replacement_target_instruction_raw_sha256",
]
const SOURCE_CONTROL_KEYS := [
	"node_id", "evidence_status", "source_region_id", "instruction_start",
	"instruction_end", "instruction_raw_sha256", "op", "command_id",
	"reference_id", "reference_kind", "operand_start", "operand_end",
	"current_target_offset", "current_target_node_id", "expression_kind",
	"expression_start", "expression_end", "expression_raw_sha256",
]
const REPLACEMENT_TARGET_KEYS := [
	"node_id", "evidence_status", "source_region_id", "instruction_start",
	"instruction_end", "instruction_raw_sha256", "op", "command_id",
]
const PATCH_KEYS := [
	"operand_start", "operand_end", "source_raw_hex", "output_raw_hex",
	"encoding", "source_instruction_raw_hex", "output_instruction_raw_hex",
	"output_instruction_raw_sha256",
]
const COVERAGE_KEYS := [
	"source_code_size", "output_code_size", "source_node_count",
	"source_typed_node_count", "source_opaque_node_count", "changed_byte_count",
]
const SOURCE_IDENTITY_KEYS := ["archive", "entry", "source_kind", "archive_sha256"]
const EMPTY_SHA256 := "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
const SUPPORTED_FORMS := {
	"condition_false_target": {
		"op": "branch_if_not_true",
		"command_id": 11.0,
		"operand_position": "instruction_tail_u32_le",
		"expression_kind": "condition",
	},
	"continuation_target": {
		"op": "continuation_transfer",
		"command_id": 12.0,
		"operand_position": "command_plus_one_u32_le",
		"expression_kind": "none",
	},
}
const COMPATIBILITY := {
	"policy": "planning_only_retarget_one_exact_control_transfer",
	"input_editable_schema": "kakyu_mes_editable_ir/v1",
	"input_decompiler_schema": "kakyu_mes_decompiler_ir/v1",
	"supported_operation": "retarget_control_flow",
	"supported_forms": SUPPORTED_FORMS,
	"source_policy": "strict_typed_transfer_with_one_exact_reference",
	"replacement_policy": "strict_unique_typed_instruction_start",
	"coordinate_policy": "code_relative_offsets_unchanged",
	"byte_length_policy": "unchanged_u32_operand_only",
	"binary_publication": "forbidden",
	"native_engine_compatibility": "unverified",
	"unknown_plan_schema": "reject",
	"unknown_v1_field": "reject",
}
const INVARIANTS := {
	"source_editable_ir_validated": true,
	"source_transfer_unique_and_typed": true,
	"source_instruction_hash_matched": true,
	"source_expression_or_transfer_form_exact": true,
	"source_reference_unique_aligned_and_in_code": true,
	"current_target_unique_and_typed": true,
	"replacement_target_unique_and_typed": true,
	"replacement_target_hash_matched": true,
	"instruction_length_unchanged": true,
	"only_target_operand_planned_to_change": true,
	"opaque_bytes_not_rewritten": true,
	"binary_not_published": true,
}


func validate(document: Dictionary) -> Dictionary:
	if (
		document.get("ok") != true
		or str(document.get("schema", "")) != ContentCoreVersionScript.MES_CONTROL_TARGET_EDIT_PLAN_SCHEMA
		or not ContractValues.has_exact_keys(document, PLAN_KEYS)
	):
		return _error("MES control-target edit plan schema or fields changed.")
	if document.get("producer") != {
		"implementation": "python_phase6_control_target_edit_planner",
		"contract": ContentCoreVersionScript.MES_CONTROL_TARGET_EDIT_PLAN_SCHEMA,
	}:
		return _error("MES control-target edit producer changed.")
	if document.get("compatibility") != COMPATIBILITY:
		return _error("MES control-target edit compatibility changed.")
	var retained_hash := str(document.get("payload_sha256", ""))
	if not ContractValues.is_sha256(retained_hash) or FingerprintScript.new().fingerprint(document) != retained_hash:
		return _error("MES control-target edit fingerprint changed.")
	var source_identity = document.get("source_identity")
	if (
		not source_identity is Dictionary
		or not ContractValues.has_only_keys(source_identity, SOURCE_IDENTITY_KEYS)
		or not ArcReaderScript.is_safe_entry_name(str(source_identity.get("archive", "")))
		or not ArcReaderScript.is_safe_entry_name(str(source_identity.get("entry", "")))
		or not ContractValues.is_sha256(str(source_identity.get("archive_sha256", "")))
	):
		return _error("MES control-target edit source identity changed.")
	var inputs = document.get("inputs")
	if (
		not inputs is Dictionary
		or not ContractValues.has_exact_keys(inputs, ["editable_ir_sha256", "decompiler_ir_sha256"])
		or not ContractValues.all_hash_values(inputs)
	):
		return _error("MES control-target edit input identity changed.")
	var operation = document.get("operation")
	var source = document.get("source_control")
	var target = document.get("replacement_target")
	var patch = document.get("patch")
	var coverage = document.get("coverage")
	if not operation is Dictionary or not ContractValues.has_exact_keys(operation, OPERATION_KEYS):
		return _error("MES control-target edit operation fields changed.")
	if not source is Dictionary or not ContractValues.has_exact_keys(source, SOURCE_CONTROL_KEYS):
		return _error("MES control-target edit source fields changed.")
	if not target is Dictionary or not ContractValues.has_exact_keys(target, REPLACEMENT_TARGET_KEYS):
		return _error("MES control-target edit replacement fields changed.")
	if not patch is Dictionary or not ContractValues.has_exact_keys(patch, PATCH_KEYS):
		return _error("MES control-target edit patch fields changed.")
	if not coverage is Dictionary or not ContractValues.has_exact_keys(coverage, COVERAGE_KEYS):
		return _error("MES control-target edit coverage fields changed.")
	var integers := _validate_integers(operation, source, target, patch, coverage)
	if not integers.ok:
		return integers
	var reference_kind := str(operation.reference_kind)
	var form: Dictionary = SUPPORTED_FORMS.get(reference_kind, {})
	if (
		str(operation.kind) != "retarget_control_flow"
		or form.is_empty()
		or not ContractValues.is_sha256(str(operation.source_instruction_raw_sha256))
		or not ContractValues.is_sha256(str(operation.replacement_target_instruction_raw_sha256))
		or int(operation.source_offset) != int(source.instruction_start)
		or int(operation.replacement_target_offset) != int(target.instruction_start)
		or int(source.current_target_offset) == int(target.instruction_start)
	):
		return _error("MES control-target edit operation changed.")
	if (
		str(source.node_id).is_empty()
		or str(source.current_target_node_id).is_empty()
		or str(source.reference_id).is_empty()
		or str(source.evidence_status) != "typed_phase1_4"
		or str(source.reference_kind) != reference_kind
		or str(source.op) != str(form.op)
		or int(source.command_id) != int(form.command_id)
		or str(source.expression_kind) != str(form.expression_kind)
		or str(source.instruction_raw_sha256) != str(operation.source_instruction_raw_sha256)
		or int(source.instruction_end) <= int(source.instruction_start)
		or int(source.operand_end) - int(source.operand_start) != 4
		or int(source.operand_start) < int(source.instruction_start)
		or int(source.operand_end) > int(source.instruction_end)
	):
		return _error("MES control-target edit typed source changed.")
	if (
		str(target.node_id).is_empty()
		or str(target.evidence_status) != "typed_phase1_4"
		or int(target.instruction_end) <= int(target.instruction_start)
		or str(target.instruction_raw_sha256) != str(operation.replacement_target_instruction_raw_sha256)
		or str(target.source_region_id).is_empty()
		or str(target.op).is_empty()
	):
		return _error("MES control-target edit typed replacement changed.")
	if (
		reference_kind == "continuation_target"
		and (
			int(source.instruction_end) - int(source.instruction_start) != 5
			or int(source.operand_start) != int(source.instruction_start) + 1
			or int(source.expression_start) != int(source.operand_start)
			or int(source.expression_end) != int(source.expression_start)
			or str(source.expression_raw_sha256) != EMPTY_SHA256
		)
	):
		return _error("MES continuation target edit form changed.")
	if (
		reference_kind == "condition_false_target"
		and (
			int(source.operand_start) != int(source.instruction_end) - 4
			or int(source.expression_start) != int(source.instruction_start) + 1
			or int(source.expression_end) != int(source.operand_start)
			or not ContractValues.is_sha256(str(source.expression_raw_sha256))
		)
	):
		return _error("MES conditional target edit form changed.")
	var patch_validation := _validate_patch(source, target, patch)
	if not patch_validation.ok:
		return patch_validation
	if (
		int(coverage.source_code_size) != int(coverage.output_code_size)
		or int(coverage.source_code_size) <= int(target.instruction_start)
		or int(coverage.source_node_count)
		!= int(coverage.source_typed_node_count) + int(coverage.source_opaque_node_count)
		or int(coverage.source_node_count) <= 0
		or int(coverage.changed_byte_count) <= 0
		or int(coverage.changed_byte_count) > 4
	):
		return _error("MES control-target edit coverage changed.")
	if document.get("assembly_ready") != true or document.get("invariants") != INVARIANTS:
		return _error("MES control-target edit readiness or invariants changed.")
	return {
		"ok": true,
		"schema": ContentCoreVersionScript.MES_CONTROL_TARGET_EDIT_PLAN_SCHEMA,
		"payload_sha256": retained_hash,
		"source_identity": source_identity.duplicate(true),
		"reference_kind": reference_kind,
		"source_offset": int(source.instruction_start),
		"current_target_offset": int(source.current_target_offset),
		"replacement_target_offset": int(target.instruction_start),
		"changed_byte_count": int(coverage.changed_byte_count),
		"mes_bytes": false,
	}


func _validate_patch(source: Dictionary, target: Dictionary, patch: Dictionary) -> Dictionary:
	if (
		int(patch.operand_start) != int(source.operand_start)
		or int(patch.operand_end) != int(source.operand_end)
		or str(patch.encoding) != "u32_le_absolute_code_offset"
		or str(patch.source_raw_hex) != ContractValues.u32_hex(int(source.current_target_offset))
		or str(patch.output_raw_hex) != ContractValues.u32_hex(int(target.instruction_start))
	):
		return _error("MES control-target edit operand patch changed.")
	var source_raw := str(patch.source_instruction_raw_hex).hex_decode()
	var output_raw := str(patch.output_instruction_raw_hex).hex_decode()
	var instruction_size := int(source.instruction_end) - int(source.instruction_start)
	var relative_start := int(source.operand_start) - int(source.instruction_start)
	var relative_end := int(source.operand_end) - int(source.instruction_start)
	if (
		source_raw.size() != instruction_size
		or output_raw.size() != instruction_size
		or ContractValues.sha256_or_empty_digest(source_raw) != str(source.instruction_raw_sha256)
		or ContractValues.sha256_or_empty_digest(output_raw) != str(patch.output_instruction_raw_sha256)
		or source_raw.slice(relative_start, relative_end).hex_encode() != str(patch.source_raw_hex)
		or output_raw.slice(relative_start, relative_end).hex_encode() != str(patch.output_raw_hex)
		or source_raw.slice(0, relative_start) != output_raw.slice(0, relative_start)
		or source_raw.slice(relative_end) != output_raw.slice(relative_end)
	):
		return _error("MES control-target edit instruction patch changed.")
	if str(source.expression_kind) == "condition":
		var expression_start := int(source.expression_start) - int(source.instruction_start)
		var expression_end := int(source.expression_end) - int(source.instruction_start)
		if ContractValues.sha256_or_empty_digest(source_raw.slice(expression_start, expression_end)) != str(source.expression_raw_sha256):
			return _error("MES control-target edit condition bytes changed.")
	return {"ok": true}


func _validate_integers(
	operation: Dictionary, source: Dictionary, target: Dictionary,
	patch: Dictionary, coverage: Dictionary
) -> Dictionary:
	for key in ["source_offset", "replacement_target_offset"]:
		if not _nonnegative_json_integer(operation.get(key, -1)):
			return _error("MES control-target edit operation coordinate changed.")
	for key in [
		"instruction_start", "instruction_end", "command_id", "operand_start",
		"operand_end", "current_target_offset", "expression_start", "expression_end",
	]:
		if not _nonnegative_json_integer(source.get(key, -1)):
			return _error("MES control-target edit source coordinate changed.")
	for key in ["instruction_start", "instruction_end", "command_id"]:
		if not _nonnegative_json_integer(target.get(key, -1)):
			return _error("MES control-target edit replacement coordinate changed.")
	for key in ["operand_start", "operand_end"]:
		if not _nonnegative_json_integer(patch.get(key, -1)):
			return _error("MES control-target edit patch coordinate changed.")
	for key in COVERAGE_KEYS:
		if not _nonnegative_json_integer(coverage.get(key, -1)):
			return _error("MES control-target edit coverage count changed.")
	return {"ok": true}


func _nonnegative_json_integer(value: Variant) -> bool:
	return (
		(value is int or value is float)
		and is_finite(float(value))
		and float(value) == floor(float(value))
		and float(value) >= 0.0
		and float(value) <= 4294967295.0
	)


func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message}
