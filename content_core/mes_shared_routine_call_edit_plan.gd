class_name KakyuMesSharedRoutineCallEditPlan
extends RefCounted

const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")
const FingerprintScript := preload("res://content_core/mes_payload_fingerprint.gd")
const ContractValues := preload("res://content_core/contract_values.gd")

const PLAN_KEYS := [
	"ok", "schema", "producer", "compatibility", "source_identity",
	"library_identity", "inputs", "operation", "target", "replacement",
	"assembly_ready", "invariants", "payload_sha256",
]
const OPERATION_KEYS := ["kind", "source_offset", "instruction_raw_sha256", "routine_id"]
const TARGET_KEYS := [
	"node_id", "region_id", "op", "command_id", "instruction_start",
	"instruction_end", "instruction_raw_hex", "instruction_raw_sha256",
	"record_list_start", "record_list_end", "expression_start", "expression_end",
	"expression_raw_hex", "expression_raw_sha256", "literal_start", "literal_end",
	"literal_raw_hex", "literal_raw_sha256", "routine_id", "width",
	"expression_terminator_offset", "expression_terminator",
	"record_terminator_offset", "record_terminator", "call_proof",
]
const REPLACEMENT_KEYS := [
	"routine_id", "width", "literal_raw_hex", "literal_raw_sha256",
	"expression_raw_hex", "expression_raw_sha256", "instruction_raw_hex",
	"instruction_raw_sha256", "callee_proof",
]
const CALL_PROOF_KEYS := [
	"id", "call_node_id", "call_start", "call_end", "physical_resume_offset",
	"physical_resume_node_id", "physical_resume_region", "physical_resume_raw_sha256",
	"routine_id", "callee_entry", "callee_registration_offset", "callee_body_start",
	"callee_body_end", "callee_return_offsets", "direct_callee_routine_ids",
	"transitive_callee_routine_ids", "proof_status",
]
const CALLEE_PROOF_KEYS := [
	"routine_id", "callee_entry", "registration_offset", "body_start", "body_end",
	"return_offsets", "direct_callee_routine_ids", "transitive_callee_routine_ids",
	"proof_status",
]
const SOURCE_IDENTITY_KEYS := ["archive", "entry", "source_kind", "archive_sha256"]
const LIBRARY_IDENTITY_KEYS := ["archive_name", "archive_sha256", "entry", "entry_sha256"]
const COMPATIBILITY := {
	"policy": "planning_only_same_width_literal_shared_routine_call_replacement",
	"input_editable_schema": "kakyu_mes_editable_ir/v1",
	"input_decompiler_schema": "kakyu_mes_decompiler_ir/v1",
	"input_shared_call_proof_schema": "kakyu_mes_shared_call_return_proof/v2",
	"input_library_audit_schema": "kakyu_mes_library_audit/v17",
	"supported_operation": "replace_shared_routine_literal",
	"supported_instruction": {"op": "script_transfer", "command_id": 29.0},
	"supported_literal_widths": [8.0],
	"u8_literal_policy": "unambiguous_token_00_through_7f_only",
	"selection_policy": "one_exact_typed_call_and_unique_physical_resume_node",
	"callee_policy": "source_and_replacement_require_total_return_certificates",
	"length_policy": "replacement_literal_must_match_source_length",
	"binary_publication": "forbidden",
	"native_engine_compatibility": "unverified",
	"unknown_plan_schema": "reject",
	"unknown_v1_field": "reject",
}
const INVARIANTS := {
	"source_editable_ir_validated": true,
	"source_call_return_proof_validated": true,
	"library_audit_validated": true,
	"target_node_unique_and_typed": true,
	"source_instruction_hash_matched": true,
	"source_literal_expression_exact": true,
	"physical_resume_node_unique": true,
	"source_callee_total_return_proved": true,
	"replacement_callee_total_return_proved": true,
	"replacement_literal_same_width_and_length": true,
	"expression_and_record_terminators_unchanged": true,
	"all_other_instruction_bytes_unchanged": true,
	"opaque_bytes_not_rewritten": true,
	"binary_not_published": true,
}


func validate(document: Dictionary) -> Dictionary:
	if (
		document.get("ok") != true
		or str(document.get("schema", ""))
		!= ContentCoreVersionScript.MES_SHARED_ROUTINE_CALL_EDIT_PLAN_SCHEMA
		or not ContractValues.has_exact_keys(document, PLAN_KEYS)
	):
		return _error("MES shared-routine call edit plan schema or fields changed.")
	if document.get("producer") != {
		"implementation": "python_phase6_shared_routine_call_edit_planner",
		"contract": ContentCoreVersionScript.MES_SHARED_ROUTINE_CALL_EDIT_PLAN_SCHEMA,
	}:
		return _error("MES shared-routine call edit plan producer changed.")
	if document.get("compatibility") != COMPATIBILITY:
		return _error("MES shared-routine call edit compatibility changed.")
	var retained_hash := str(document.get("payload_sha256", ""))
	if not ContractValues.is_sha256(retained_hash) or FingerprintScript.new().fingerprint(document) != retained_hash:
		return _error("MES shared-routine call edit plan fingerprint changed.")
	var source_identity = document.get("source_identity")
	if (
		not source_identity is Dictionary
		or not ContractValues.has_only_keys(source_identity, SOURCE_IDENTITY_KEYS)
		or str(source_identity.get("archive", "")).is_empty()
		or str(source_identity.get("entry", "")).is_empty()
		or (source_identity.has("archive_sha256") and not ContractValues.is_sha256(str(source_identity.archive_sha256)))
	):
		return _error("MES shared-routine call edit source identity changed.")
	var library_identity = document.get("library_identity")
	if (
		not library_identity is Dictionary
		or not ContractValues.has_exact_keys(library_identity, LIBRARY_IDENTITY_KEYS)
		or str(library_identity.get("entry", "")) != "LIBLARY.LIB"
		or str(library_identity.get("archive_name", "")).is_empty()
		or not ContractValues.is_sha256(str(library_identity.get("archive_sha256", "")))
		or not ContractValues.is_sha256(str(library_identity.get("entry_sha256", "")))
	):
		return _error("MES shared-routine call edit library identity changed.")
	var inputs = document.get("inputs")
	if (
		not inputs is Dictionary
		or not ContractValues.has_exact_keys(inputs, [
			"editable_ir_sha256", "decompiler_ir_sha256",
			"shared_call_return_proof_sha256", "library_audit_sha256",
		])
		or not ContractValues.hash_values(inputs, inputs.keys())
	):
		return _error("MES shared-routine call edit input identity changed.")
	var operation = document.get("operation")
	if (
		not operation is Dictionary
		or not ContractValues.has_exact_keys(operation, OPERATION_KEYS)
		or str(operation.get("kind", "")) != "replace_shared_routine_literal"
		or not ContractValues.nonnegative_json_integer(operation.get("source_offset", -1))
		or not ContractValues.nonnegative_json_integer(operation.get("routine_id", -1))
		or int(operation.routine_id) > 0x7F
		or not ContractValues.is_sha256(str(operation.get("instruction_raw_sha256", "")))
	):
		return _error("MES shared-routine call edit operation changed.")
	var target = document.get("target")
	var replacement = document.get("replacement")
	if not target is Dictionary or not ContractValues.has_exact_keys(target, TARGET_KEYS):
		return _error("MES shared-routine call edit target fields changed.")
	if not replacement is Dictionary or not ContractValues.has_exact_keys(replacement, REPLACEMENT_KEYS):
		return _error("MES shared-routine call edit replacement fields changed.")
	if (
		str(target.get("node_id", "")).is_empty()
		or str(target.get("region_id", "")).is_empty()
		or str(target.get("op", "")) != "script_transfer"
		or int(target.get("command_id", -1)) != 0x1D
		or int(target.get("instruction_start", -1)) != int(operation.source_offset)
		or str(target.get("instruction_raw_sha256", "")) != str(operation.instruction_raw_sha256)
		or int(replacement.get("routine_id", -1)) != int(operation.routine_id)
	):
		return _error("MES shared-routine call edit target identity changed.")
	var byte_validation := _validate_bytes(target, replacement, library_identity)
	if not byte_validation.ok:
		return byte_validation
	if document.get("assembly_ready") != true:
		return _error("MES shared-routine call edit plan is not assembly ready.")
	if document.get("invariants") != INVARIANTS:
		return _error("MES shared-routine call edit invariants changed.")
	return {
		"ok": true,
		"schema": ContentCoreVersionScript.MES_SHARED_ROUTINE_CALL_EDIT_PLAN_SCHEMA,
		"payload_sha256": retained_hash,
		"source_identity": source_identity.duplicate(true),
		"library_identity": library_identity.duplicate(true),
		"instruction_start": int(target.instruction_start),
		"literal_start": int(target.literal_start),
		"physical_resume_offset": int(target.call_proof.physical_resume_offset),
		"source_routine_id": int(target.routine_id),
		"replacement_routine_id": int(replacement.routine_id),
		"mes_bytes": false,
	}


func _validate_bytes(target: Dictionary, replacement: Dictionary, library_identity: Dictionary) -> Dictionary:
	for key in [
		"instruction_start", "instruction_end", "record_list_start", "record_list_end",
		"expression_start", "expression_end", "literal_start", "literal_end",
		"routine_id", "width", "expression_terminator_offset",
		"expression_terminator", "record_terminator_offset", "record_terminator",
	]:
		if not ContractValues.nonnegative_json_integer(target.get(key, -1)):
			return _error("MES shared-routine call edit target coordinate changed.")
	if (
		not ContractValues.nonnegative_json_integer(replacement.get("routine_id", -1))
		or not ContractValues.nonnegative_json_integer(replacement.get("width", -1))
		or int(target.width) != 8 or int(replacement.width) != 8
		or int(target.routine_id) > 0x7F or int(replacement.routine_id) > 0x7F
		or int(target.routine_id) == int(replacement.routine_id)
	):
		return _error("MES shared-routine call edit replacement literal changed.")
	var source_literal := ContractValues.checked_bytes(target, "literal")
	var source_expression := ContractValues.checked_bytes(target, "expression")
	var source_instruction := ContractValues.checked_bytes(target, "instruction")
	var output_literal := ContractValues.checked_bytes(replacement, "literal")
	var output_expression := ContractValues.checked_bytes(replacement, "expression")
	var output_instruction := ContractValues.checked_bytes(replacement, "instruction")
	if (
		source_literal != PackedByteArray([int(target.routine_id)])
		or output_literal != PackedByteArray([int(replacement.routine_id)])
		or source_expression != _join(source_literal, PackedByteArray([0xFF]))
		or output_expression != _join(output_literal, PackedByteArray([0xFF]))
		or source_instruction != _join(PackedByteArray([0x1D, 0x02]), source_expression, PackedByteArray([0]))
		or output_instruction != _join(PackedByteArray([0x1D, 0x02]), output_expression, PackedByteArray([0]))
	):
		return _error("MES shared-routine call edit instruction bytes changed.")
	var start := int(target.instruction_start)
	if (
		int(target.instruction_end) != start + 5
		or int(target.record_list_start) != start + 1
		or int(target.expression_start) != start + 2
		or int(target.literal_start) != start + 2
		or int(target.literal_end) != start + 3
		or int(target.expression_terminator_offset) != start + 3
		or int(target.expression_end) != start + 4
		or int(target.record_terminator_offset) != start + 4
		or int(target.record_list_end) != start + 5
		or int(target.expression_terminator) != 0xFF
		or int(target.record_terminator) != 0
	):
		return _error("MES shared-routine call edit record boundary changed.")
	var call = target.get("call_proof")
	var callee = replacement.get("callee_proof")
	if not call is Dictionary or not ContractValues.has_exact_keys(call, CALL_PROOF_KEYS):
		return _error("MES shared-routine call edit source call proof fields changed.")
	if not callee is Dictionary or not ContractValues.has_exact_keys(callee, CALLEE_PROOF_KEYS):
		return _error("MES shared-routine call edit replacement callee proof fields changed.")
	if (
		int(call.get("call_start", -1)) != start
		or int(call.get("call_end", -1)) != start + 5
		or int(call.get("physical_resume_offset", -1)) != start + 5
		or int(call.get("routine_id", -1)) != int(target.routine_id)
		or str(call.get("callee_entry", "")) != str(library_identity.entry)
		or str(call.get("proof_status", ""))
		!= "literal_shared_call_all_callee_terminals_return_to_physical_resume"
		or not ContractValues.is_sha256(str(call.get("physical_resume_raw_sha256", "")))
		or int(callee.get("routine_id", -1)) != int(replacement.routine_id)
		or str(callee.get("callee_entry", "")) != str(library_identity.entry)
		or str(callee.get("proof_status", "")) != "replacement_shared_routine_total_return_proved"
	):
		return _error("MES shared-routine call edit call or callee proof changed.")
	for row in [call, callee]:
		var keys := (
			["call_start", "call_end", "physical_resume_offset", "routine_id",
			"callee_registration_offset", "callee_body_start", "callee_body_end"]
			if row == call else
			["routine_id", "registration_offset", "body_start", "body_end"]
		)
		for key in keys:
			if not ContractValues.nonnegative_json_integer(row.get(key, -1)):
				return _error("MES shared-routine call edit proof coordinate changed.")
	for pair in [
		[call, "callee_return_offsets"], [call, "direct_callee_routine_ids"],
		[call, "transitive_callee_routine_ids"], [callee, "return_offsets"],
		[callee, "direct_callee_routine_ids"], [callee, "transitive_callee_routine_ids"],
	]:
		if not _integer_list(pair[0].get(pair[1])):
			return _error("MES shared-routine call edit proof list changed.")
	return {"ok": true}


func _integer_list(value: Variant) -> bool:
	if not value is Array:
		return false
	var retained: Array[int] = []
	for item in value:
		if not ContractValues.nonnegative_json_integer(item):
			return false
		retained.append(int(item))
	var sorted_values := retained.duplicate()
	sorted_values.sort()
	if retained != sorted_values:
		return false
	for index in range(1, retained.size()):
		if retained[index - 1] == retained[index]:
			return false
	return true


func _join(first: PackedByteArray, second: PackedByteArray, third := PackedByteArray()) -> PackedByteArray:
	var result := PackedByteArray()
	result.append_array(first)
	result.append_array(second)
	result.append_array(third)
	return result


func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message}
