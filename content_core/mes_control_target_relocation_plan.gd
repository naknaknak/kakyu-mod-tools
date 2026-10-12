class_name KakyuMesControlTargetRelocationPlan
extends RefCounted

const ArcReaderScript := preload("res://content_core/arc_reader.gd")
const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")
const FingerprintScript := preload("res://content_core/mes_payload_fingerprint.gd")
const ContractValues := preload("res://content_core/contract_values.gd")

const PLAN_KEYS := [
	"ok", "schema", "producer", "compatibility", "source_identity", "inputs",
	"relocation", "target_patches", "resolved_blocker_reference_ids",
	"remaining_blockers", "assembly_ready", "invariants", "payload_sha256",
]
const PATCH_KEYS := [
	"reference_id", "reference_kind", "owner_node_id", "owner_op", "command_id",
	"source_instruction_start", "source_instruction_end", "output_instruction_start",
	"output_instruction_end", "source_operand_start", "source_operand_end",
	"output_operand_start", "output_operand_end", "source_target_offset",
	"output_target_offset", "source_target_node_id", "source_raw_hex",
	"output_raw_hex", "encoding",
]
const SOURCE_IDENTITY_KEYS := ["archive", "entry", "source_kind", "archive_sha256"]
const SUPPORTED_TARGET_FORMS := {
	"condition_false_target": {
		"op": "branch_if_not_true",
		"command_id": 11.0,
		"operand_index": 1.0,
		"operand_position": "instruction_tail_u32_le",
	},
	"continuation_target": {
		"op": "continuation_transfer",
		"command_id": 12.0,
		"operand_index": 0.0,
		"operand_position": "command_plus_one_u32_le",
	},
	"definition_skip_target": {
		"op": "command_10",
		"command_id": 16.0,
		"operand_index": 1.0,
		"operand_position": "instruction_tail_u32_le",
	},
}
const COMPATIBILITY := {
	"policy": "augment_exact_message_relocation_plan",
	"input_editable_schema": "kakyu_mes_editable_ir/v1",
	"input_decompiler_schema": "kakyu_mes_decompiler_ir/v1",
	"input_message_plan_schema": "kakyu_mes_message_relocation_plan/v1",
	"supported_target_forms": SUPPORTED_TARGET_FORMS,
	"target_alignment_policy": "typed_instruction_start_only",
	"operand_encoding": "u32_le_absolute_code_offset",
	"unsupported_target_policy": "retain_blocker",
	"binary_publication": "forbidden",
	"native_engine_compatibility": "unverified",
	"unknown_plan_schema": "reject",
	"unknown_v1_field": "reject",
}
const INVARIANTS := {
	"source_editable_ir_validated": true,
	"message_relocation_plan_validated": true,
	"source_instruction_bytes_matched": true,
	"target_operand_u32_le_matched": true,
	"target_instruction_start_confirmed": true,
	"patch_ranges_nonoverlapping": true,
	"definition_skip_targets_scanned": true,
	"unsupported_blockers_retained": true,
	"binary_not_published": true,
}


func validate(document: Dictionary) -> Dictionary:
	if (
		document.get("ok") != true
		or str(document.get("schema", "")) != ContentCoreVersionScript.MES_CONTROL_TARGET_RELOCATION_PLAN_SCHEMA
		or not ContractValues.has_exact_keys(document, PLAN_KEYS)
	):
		return _error("MES control-target relocation plan schema or fields changed.")
	if document.get("producer") != {
		"implementation": "python_phase6_control_target_relocation_planner",
		"contract": ContentCoreVersionScript.MES_CONTROL_TARGET_RELOCATION_PLAN_SCHEMA,
	}:
		return _error("MES control-target relocation plan producer changed.")
	if document.get("compatibility") != COMPATIBILITY:
		return _error("MES control-target relocation compatibility changed.")
	var retained_hash := str(document.get("payload_sha256", ""))
	if not ContractValues.is_sha256(retained_hash) or FingerprintScript.new().fingerprint(document) != retained_hash:
		return _error("MES control-target relocation plan fingerprint changed.")
	var source_identity = document.get("source_identity")
	if (
		not source_identity is Dictionary
		or not ContractValues.has_only_keys(source_identity, SOURCE_IDENTITY_KEYS)
		or not ArcReaderScript.is_safe_entry_name(str(source_identity.get("archive", "")))
		or not ArcReaderScript.is_safe_entry_name(str(source_identity.get("entry", "")))
		or not ContractValues.is_sha256(str(source_identity.get("archive_sha256", "")))
	):
		return _error("MES control-target relocation source identity is incomplete.")
	var inputs = document.get("inputs")
	if (
		not inputs is Dictionary
		or not ContractValues.has_exact_keys(inputs, [
			"editable_ir_sha256", "decompiler_ir_sha256", "message_relocation_plan_sha256",
		])
		or not ContractValues.all_hash_values(inputs)
	):
		return _error("MES control-target relocation input identity changed.")
	var relocation = document.get("relocation")
	if (
		not relocation is Dictionary
		or not ContractValues.has_exact_keys(relocation, [
			"delta", "pivot_source_end", "source_code_size", "output_code_size",
		])
		or not ContractValues.json_integer(relocation.get("delta", 0))
		or not ContractValues.nonnegative_json_integer(relocation.get("pivot_source_end", -1))
		or not ContractValues.nonnegative_json_integer(relocation.get("source_code_size", -1))
		or not ContractValues.nonnegative_json_integer(relocation.get("output_code_size", -1))
		or int(relocation.output_code_size) != int(relocation.source_code_size) + int(relocation.delta)
	):
		return _error("MES control-target relocation coordinates changed.")
	var patches = document.get("target_patches")
	var resolved = document.get("resolved_blocker_reference_ids")
	var remaining = document.get("remaining_blockers")
	if not patches is Array or not resolved is Array or not remaining is Array:
		return _error("MES control-target relocation patch collection changed.")
	var patch_validation := _validate_patches(patches, relocation)
	if not patch_validation.ok:
		return patch_validation
	if resolved.size() != patches.size():
		return _error("MES control-target relocation resolved blockers changed.")
	for index in range(patches.size()):
		if not resolved[index] is String or str(resolved[index]) != str(patches[index].reference_id):
			return _error("MES control-target relocation resolved blockers changed.")
	for blocker in remaining:
		if not blocker is Dictionary:
			return _error("MES control-target relocation remaining blocker changed.")
	if document.get("assembly_ready") != remaining.is_empty():
		return _error("MES control-target relocation readiness changed.")
	if document.get("invariants") != INVARIANTS:
		return _error("MES control-target relocation invariants changed.")
	return {
		"ok": true,
		"schema": ContentCoreVersionScript.MES_CONTROL_TARGET_RELOCATION_PLAN_SCHEMA,
		"payload_sha256": retained_hash,
		"source_identity": source_identity.duplicate(true),
		"patch_count": patches.size(),
		"remaining_blocker_count": remaining.size(),
		"assembly_ready": remaining.is_empty(),
	}


func validate_patch_rows(patches: Array, relocation: Dictionary) -> Dictionary:
	return _validate_patches(patches, relocation)


func _validate_patches(patches: Array, relocation: Dictionary) -> Dictionary:
	var seen_ids := {}
	var previous_end := -1
	for untyped_patch in patches:
		if not untyped_patch is Dictionary or not ContractValues.has_exact_keys(untyped_patch, PATCH_KEYS):
			return _error("MES control-target relocation patch fields changed.")
		var patch: Dictionary = untyped_patch
		var reference_id := str(patch.get("reference_id", ""))
		var reference_kind := str(patch.get("reference_kind", ""))
		var form: Dictionary = SUPPORTED_TARGET_FORMS.get(reference_kind, {})
		if (
			reference_id.is_empty()
			or seen_ids.has(reference_id)
			or form.is_empty()
			or str(patch.get("owner_node_id", "")).is_empty()
			or str(patch.get("source_target_node_id", "")).is_empty()
			or str(patch.get("owner_op", "")) != str(form.op)
			or not ContractValues.nonnegative_json_integer(patch.get("command_id", -1))
			or int(patch.command_id) != int(form.command_id)
			or str(patch.get("encoding", "")) != "u32_le_absolute_code_offset"
		):
			return _error("MES control-target relocation patch fields changed.")
		seen_ids[reference_id] = true
		for key in [
			"source_instruction_start", "source_instruction_end", "output_instruction_start",
			"output_instruction_end", "source_operand_start", "source_operand_end",
			"output_operand_start", "output_operand_end", "source_target_offset",
			"output_target_offset",
		]:
			if not ContractValues.nonnegative_json_integer(patch.get(key, -1)):
				return _error("MES control-target relocation patch coordinate changed.")
		var source_start := int(patch.source_instruction_start)
		var source_end := int(patch.source_instruction_end)
		var output_start := int(patch.output_instruction_start)
		var output_end := int(patch.output_instruction_end)
		var source_operand_start := int(patch.source_operand_start)
		var source_operand_end := int(patch.source_operand_end)
		var output_operand_start := int(patch.output_operand_start)
		var output_operand_end := int(patch.output_operand_end)
		if (
			source_end <= source_start
			or output_end - output_start != source_end - source_start
			or source_operand_end - source_operand_start != 4
			or output_operand_end - output_operand_start != 4
			or source_operand_start < source_start
			or source_operand_end > source_end
			or output_operand_start < output_start
			or output_operand_end > output_end
			or output_operand_start < previous_end
			or output_start != _relocate_offset(source_start, relocation)
			or output_operand_start != _relocate_offset(source_operand_start, relocation)
			or int(patch.output_target_offset) != _relocate_offset(int(patch.source_target_offset), relocation)
		):
			return _error("MES control-target relocation patch boundary changed.")
		if reference_kind in ["condition_false_target", "definition_skip_target"]:
			if source_operand_start != source_end - 4:
				return _error("MES trailing target is not the final u32 operand.")
		elif source_end - source_start != 5 or source_operand_start != source_start + 1:
			return _error("MES continuation target is not command-plus-one u32.")
		if (
			_decode_u32_le_hex(str(patch.get("source_raw_hex", ""))) != int(patch.source_target_offset)
			or _decode_u32_le_hex(str(patch.get("output_raw_hex", ""))) != int(patch.output_target_offset)
		):
			return _error("MES control-target relocation patch bytes changed.")
		previous_end = output_operand_end
	return {"ok": true}


func _relocate_offset(value: int, relocation: Dictionary) -> int:
	return value + int(relocation.delta) if value >= int(relocation.pivot_source_end) else value


func _decode_u32_le_hex(value: String) -> int:
	if value.length() != 8:
		return -1
	var bytes := value.hex_decode()
	if bytes.size() != 4:
		return -1
	return int(bytes[0]) | (int(bytes[1]) << 8) | (int(bytes[2]) << 16) | (int(bytes[3]) << 24)


func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message}
