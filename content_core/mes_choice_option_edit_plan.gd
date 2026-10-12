class_name KakyuMesChoiceOptionEditPlan
extends RefCounted

const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")
const FingerprintScript := preload("res://content_core/mes_payload_fingerprint.gd")
const ContractValues := preload("res://content_core/contract_values.gd")

const PLAN_KEYS := [
	"ok", "schema", "producer", "compatibility", "source_identity", "inputs",
	"operation", "target", "replacement", "retained_contract",
	"assembly_ready", "invariants", "payload_sha256",
]
const OPERATION_KEYS := [
	"kind", "group_selector", "definition_id", "source_payload_sha256",
	"text", "encoding",
]
const TARGET_KEYS := [
	"group_selector", "definition_id", "registration_start", "registration_end",
	"registration_raw_sha256", "body_start", "body_end", "body_raw_hex",
	"body_raw_sha256", "instruction_start", "instruction_end",
	"instruction_raw_hex", "instruction_raw_sha256", "payload_start",
	"payload_end", "payload_size", "payload_raw_hex", "payload_raw_sha256",
	"terminator_offset", "terminator", "return_start", "return_end",
	"return_raw_hex", "return_raw_sha256", "guard_sha256",
]
const REPLACEMENT_KEYS := [
	"text", "encoding", "payload_size", "payload_raw_hex",
	"payload_raw_sha256", "instruction_raw_hex", "instruction_raw_sha256",
	"body_raw_hex", "body_raw_sha256", "byte_delta", "output_entry_sha256",
	"output_bytecode_sha256",
]
const RETAINED_KEYS := [
	"choice_proof_sha256", "address_entry_index", "address_entry_start",
	"address_entry_end", "groups_sha256", "result_mapping_sha256",
	"terminal_start", "terminal_end", "terminal_raw_sha256",
	"physical_resume_start", "physical_resume_end", "physical_resume_raw_sha256",
	"source_prefix_sha256", "source_suffix_sha256",
	"all_bytes_outside_payload_unchanged", "all_coordinates_unchanged",
	"native_input_and_gameplay_labels",
]
const SOURCE_IDENTITY_KEYS := ["archive", "archive_sha256", "entry", "entry_sha256"]
const COMPATIBILITY := {
	"policy": "planning_only_source_bound_same_length_choice_option_replacement",
	"input_choice_proof_schema": "kakyu_mes_choice_group_authoring_proof/v1",
	"supported_operation": "replace_choice_option_cp932_same_length",
	"supported_instruction": {"command_id": 1.0, "body_shape": "message_then_return"},
	"encoding": "cp932",
	"length_policy": "replacement_payload_must_match_source_length",
	"coordinate_policy": "zero_delta_all_source_coordinates_retained",
	"result_mapping_policy": "exact_choice_proof_fingerprint_retained",
	"native_input_and_gameplay_labels": "unresolved",
	"binary_publication": "forbidden",
	"unknown_plan_schema": "reject",
	"unknown_v1_field": "reject",
}
const INVARIANTS := {
	"source_choice_proof_rebuilt": true,
	"target_group_and_definition_unique": true,
	"target_is_one_strict_cp932_message_then_return": true,
	"source_payload_hash_matched": true,
	"replacement_cp932_strict_and_same_length": true,
	"registration_target_unchanged": true,
	"definition_return_unchanged": true,
	"group_topology_unchanged": true,
	"result_mapping_unchanged": true,
	"routine40_terminal_and_physical_resume_unchanged": true,
	"all_other_entry_bytes_unchanged": true,
	"native_input_not_executed": true,
	"binary_not_published": true,
}


func validate(document: Dictionary) -> Dictionary:
	if (
		document.get("ok") != true
		or str(document.get("schema", ""))
		!= ContentCoreVersionScript.MES_CHOICE_OPTION_EDIT_PLAN_SCHEMA
		or not ContractValues.has_exact_keys(document, PLAN_KEYS)
	):
		return _error("MES choice-option edit plan schema or fields changed.")
	if document.get("producer") != {
		"implementation": "python_phase6_choice_option_edit_planner",
		"contract": ContentCoreVersionScript.MES_CHOICE_OPTION_EDIT_PLAN_SCHEMA,
	}:
		return _error("MES choice-option edit plan producer changed.")
	if document.get("compatibility") != COMPATIBILITY:
		return _error("MES choice-option edit compatibility changed.")
	var retained_hash := str(document.get("payload_sha256", ""))
	if not ContractValues.is_sha256(retained_hash) or FingerprintScript.new().fingerprint(document) != retained_hash:
		return _error("MES choice-option edit plan fingerprint changed.")
	var source = document.get("source_identity")
	if (
		not source is Dictionary
		or not ContractValues.has_exact_keys(source, SOURCE_IDENTITY_KEYS)
		or str(source.get("archive", "")).is_empty()
		or str(source.get("entry", "")).is_empty()
		or not ContractValues.hash_values(source, ["archive_sha256", "entry_sha256"])
	):
		return _error("MES choice-option edit source identity changed.")
	var inputs = document.get("inputs")
	if (
		not inputs is Dictionary
		or not ContractValues.has_exact_keys(inputs, ["choice_proof_sha256"])
		or not ContractValues.is_sha256(str(inputs.get("choice_proof_sha256", "")))
	):
		return _error("MES choice-option edit input identity changed.")
	var operation = document.get("operation")
	if not _valid_operation(operation):
		return _error("MES choice-option edit operation changed.")
	var target = document.get("target")
	var replacement = document.get("replacement")
	if not target is Dictionary or not ContractValues.has_exact_keys(target, TARGET_KEYS):
		return _error("MES choice-option edit target fields changed.")
	if not replacement is Dictionary or not ContractValues.has_exact_keys(replacement, REPLACEMENT_KEYS):
		return _error("MES choice-option edit replacement fields changed.")
	var bytes_result := _validate_bytes(operation, target, replacement)
	if not bytes_result.ok:
		return bytes_result
	var retained = document.get("retained_contract")
	if not _valid_retained(retained, inputs):
		return _error("MES choice-option retained contract changed.")
	if document.get("assembly_ready") != true:
		return _error("MES choice-option edit plan is not assembly ready.")
	if document.get("invariants") != INVARIANTS:
		return _error("MES choice-option edit invariants changed.")
	return {
		"ok": true,
		"schema": ContentCoreVersionScript.MES_CHOICE_OPTION_EDIT_PLAN_SCHEMA,
		"payload_sha256": retained_hash,
		"source_identity": source.duplicate(true),
		"group_selector": int(target.group_selector),
		"definition_id": int(target.definition_id),
		"payload_start": int(target.payload_start),
		"payload_end": int(target.payload_end),
		"payload_size": int(target.payload_size),
		"routine40_terminal": int(retained.terminal_start),
		"physical_resume": int(retained.physical_resume_start),
		"output_entry_sha256": str(replacement.output_entry_sha256),
		"byte_delta": 0,
		"mes_bytes": false,
	}


func _valid_operation(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	var operation: Dictionary = value
	return (
		ContractValues.has_exact_keys(operation, OPERATION_KEYS)
		and str(operation.get("kind", ""))
		== "replace_choice_option_cp932_same_length"
		and str(operation.get("encoding", "")) == "cp932"
		and _nonnegative_json_integer(operation.get("group_selector", -1))
		and _nonnegative_json_integer(operation.get("definition_id", -1))
		and ContractValues.is_sha256(str(operation.get("source_payload_sha256", "")))
		and not str(operation.get("text", "")).is_empty()
	)


func _validate_bytes(
	operation: Dictionary,
	target: Dictionary,
	replacement: Dictionary
) -> Dictionary:
	for key in [
		"group_selector", "definition_id", "registration_start", "registration_end",
		"body_start", "body_end", "instruction_start", "instruction_end",
		"payload_start", "payload_end", "payload_size", "terminator_offset",
		"terminator", "return_start", "return_end",
	]:
		if not _nonnegative_json_integer(target.get(key, -1)):
			return _error("MES choice-option target coordinate changed.")
	if (
		int(target.group_selector) != int(operation.group_selector)
		or int(target.definition_id) != int(operation.definition_id)
		or str(target.payload_raw_sha256) != str(operation.source_payload_sha256)
		or not ContractValues.hash_values(target, [
			"registration_raw_sha256", "body_raw_sha256", "instruction_raw_sha256",
			"payload_raw_sha256", "return_raw_sha256", "guard_sha256",
		])
	):
		return _error("MES choice-option target identity changed.")
	var source_body := ContractValues.checked_bytes(target, "body")
	var source_instruction := ContractValues.checked_bytes(target, "instruction")
	var source_payload := ContractValues.checked_bytes(target, "payload")
	var return_raw := ContractValues.checked_bytes(target, "return")
	if (
		source_body.is_empty() or source_instruction.is_empty()
		or source_payload.is_empty() or return_raw.is_empty()
		or source_instruction != _join(
			PackedByteArray([0x01]), source_payload, PackedByteArray([0])
		)
		or source_body != _join(source_instruction, return_raw)
		or int(target.payload_size) != source_payload.size()
		or int(target.payload_start) != int(target.instruction_start) + 1
		or int(target.payload_end) != int(target.payload_start) + source_payload.size()
		or int(target.terminator_offset) != int(target.payload_end)
		or int(target.instruction_end) != int(target.terminator_offset) + 1
		or int(target.terminator) != 0
		or int(target.body_start) != int(target.instruction_start)
		or int(target.return_start) != int(target.instruction_end)
		or int(target.return_end) != int(target.body_end)
	):
		return _error("MES choice-option source body boundary changed.")
	if (
		not _nonnegative_json_integer(replacement.get("payload_size", -1))
		or not _nonnegative_json_integer(replacement.get("byte_delta", -1))
		or int(replacement.byte_delta) != 0
		or str(replacement.get("text", "")) != str(operation.text)
		or str(replacement.get("encoding", "")) != "cp932"
		or not ContractValues.hash_values(replacement, [
			"payload_raw_sha256", "instruction_raw_sha256", "body_raw_sha256",
			"output_entry_sha256", "output_bytecode_sha256",
		])
	):
		return _error("MES choice-option replacement identity changed.")
	var output_payload := ContractValues.checked_bytes(replacement, "payload")
	var output_instruction := ContractValues.checked_bytes(replacement, "instruction")
	var output_body := ContractValues.checked_bytes(replacement, "body")
	if (
		output_payload.is_empty() or output_instruction.is_empty() or output_body.is_empty()
		or output_payload == source_payload
		or output_payload.has(0)
		or output_payload.size() != source_payload.size()
		or int(replacement.payload_size) != output_payload.size()
		or output_instruction != _join(
			PackedByteArray([0x01]), output_payload, PackedByteArray([0])
		)
		or output_body != _join(output_instruction, return_raw)
	):
		return _error("MES choice-option replacement bytes changed.")
	return {"ok": true}


func _valid_retained(value: Variant, inputs: Dictionary) -> bool:
	if not value is Dictionary:
		return false
	var retained: Dictionary = value
	if not ContractValues.has_exact_keys(retained, RETAINED_KEYS):
		return false
	for key in [
		"address_entry_index", "address_entry_start", "address_entry_end",
		"terminal_start", "terminal_end", "physical_resume_start",
		"physical_resume_end",
	]:
		if not _nonnegative_json_integer(retained.get(key, -1)):
			return false
	return (
		ContractValues.hash_values(retained, [
			"choice_proof_sha256", "groups_sha256", "result_mapping_sha256",
			"terminal_raw_sha256", "physical_resume_raw_sha256",
			"source_prefix_sha256", "source_suffix_sha256",
		])
		and str(retained.choice_proof_sha256) == str(inputs.choice_proof_sha256)
		and int(retained.address_entry_end) > int(retained.address_entry_start)
		and int(retained.terminal_end) > int(retained.terminal_start)
		and int(retained.terminal_end) == int(retained.physical_resume_start)
		and int(retained.physical_resume_end) > int(retained.physical_resume_start)
		and retained.get("all_bytes_outside_payload_unchanged") == true
		and retained.get("all_coordinates_unchanged") == true
		and str(retained.get("native_input_and_gameplay_labels", "")) == "unresolved"
	)


func _join(first: PackedByteArray, second: PackedByteArray, third := PackedByteArray()) -> PackedByteArray:
	var result := PackedByteArray()
	result.append_array(first)
	result.append_array(second)
	result.append_array(third)
	return result


func _nonnegative_json_integer(value: Variant) -> bool:
	return (
		(value is int and int(value) >= 0)
		or (value is float and is_finite(value) and float(value) >= 0.0 and float(value) == floor(float(value)))
	)


func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message}
