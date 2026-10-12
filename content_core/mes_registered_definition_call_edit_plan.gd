class_name KakyuMesRegisteredDefinitionCallEditPlan
extends RefCounted

const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")
const FingerprintScript := preload("res://content_core/mes_payload_fingerprint.gd")
const ContractValues := preload("res://content_core/contract_values.gd")

const PLAN_KEYS := [
	"ok", "schema", "producer", "compatibility", "source_identity",
	"registry_identity", "inputs", "operation", "target", "replacement",
	"assembly_ready", "invariants", "payload_sha256",
]
const OPERATION_KEYS := ["kind", "source_offset", "instruction_raw_sha256", "selector"]
const TARGET_KEYS := [
	"node_id", "region_id", "op", "command_id", "instruction_start",
	"instruction_end", "instruction_raw_hex", "instruction_raw_sha256",
	"record_list_start", "record_list_end", "expression_start", "expression_end",
	"expression_raw_hex", "expression_raw_sha256", "literal_start", "literal_end",
	"literal_raw_hex", "literal_raw_sha256", "selector", "width",
	"expression_terminator_offset", "expression_terminator",
	"record_terminator_offset", "record_terminator", "call_proof", "registry_binding",
]
const REPLACEMENT_KEYS := [
	"selector", "width", "literal_raw_hex", "literal_raw_sha256",
	"expression_raw_hex", "expression_raw_sha256", "instruction_raw_hex",
	"instruction_raw_sha256", "registry_binding",
]
const CALL_PROOF_KEYS := [
	"id", "call_node_id", "caller_entry", "caller_region", "call_start",
	"call_end", "physical_resume_offset", "physical_resume_node_id",
	"physical_resume_region", "physical_resume_raw_sha256", "selector",
	"proof_status", "native_role", "registry_binding_status", "return_edge",
]
const REGISTRY_BINDING_KEYS := [
	"selector", "registration_start", "registration_end",
	"registration_raw_sha256", "selector_start", "selector_end",
	"selector_raw_sha256", "expression_start", "expression_end",
	"expression_raw_sha256", "body_start", "body_end", "body_size",
	"body_raw_sha256", "skip_target", "body_execution", "proof_status",
]
const SOURCE_IDENTITY_KEYS := ["archive", "entry", "source_kind", "archive_sha256"]
const REGISTRY_IDENTITY_KEYS := [
	"archive", "archive_sha256", "entry", "entry_sha256", "proof_sha256",
]
const COMPATIBILITY := {
	"policy": "planning_only_same_width_literal_registered_definition_call_replacement",
	"input_editable_schema": "kakyu_mes_editable_ir/v1",
	"input_decompiler_schema": "kakyu_mes_decompiler_ir/v1",
	"input_call_family_proof_schema": "kakyu_mes_call_family_proof/v1",
	"input_registry_proof_schema": "kakyu_mes_registered_definition_registry_proof/v1",
	"supported_operation": "replace_registered_definition_literal",
	"supported_instruction": {"op": "definition_invoke", "command_id": 17.0},
	"supported_literal_widths": [8.0],
	"u8_literal_policy": "unambiguous_token_00_through_7f_only",
	"selection_policy": "one_exact_typed_call_and_unique_physical_resume_node",
	"registry_policy": "source_and_replacement_require_exact_command14_body_boundaries",
	"return_edge_policy": "not_emitted_without_registered_body_total_return_proof",
	"body_execution": "not_performed",
	"command_10_policy": "excluded_choice_definition_body_family",
	"length_policy": "replacement_literal_must_match_source_length",
	"binary_publication": "forbidden",
	"native_engine_compatibility": "unverified",
	"unknown_plan_schema": "reject",
	"unknown_v1_field": "reject",
}
const INVARIANTS := {
	"source_editable_ir_validated": true,
	"source_call_family_proof_validated": true,
	"registry_proof_validated": true,
	"target_node_unique_and_typed": true,
	"source_instruction_hash_matched": true,
	"source_literal_expression_exact": true,
	"physical_resume_node_unique": true,
	"source_registry_body_boundary_bound": true,
	"replacement_registry_body_boundary_bound": true,
	"replacement_literal_same_width_and_length": true,
	"expression_and_record_terminators_unchanged": true,
	"command_10_not_classified_as_registry": true,
	"registered_bodies_not_executed": true,
	"all_other_instruction_bytes_unchanged": true,
	"opaque_bytes_not_rewritten": true,
	"binary_not_published": true,
}


func validate(document: Dictionary) -> Dictionary:
	if (
		document.get("ok") != true
		or str(document.get("schema", ""))
		!= ContentCoreVersionScript.MES_REGISTERED_DEFINITION_CALL_EDIT_PLAN_SCHEMA
		or not ContractValues.has_exact_keys(document, PLAN_KEYS)
	):
		return _error("MES registered-definition call edit plan schema or fields changed.")
	if document.get("producer") != {
		"implementation": "python_phase6_registered_definition_call_edit_planner",
		"contract": ContentCoreVersionScript.MES_REGISTERED_DEFINITION_CALL_EDIT_PLAN_SCHEMA,
	}:
		return _error("MES registered-definition call edit plan producer changed.")
	if document.get("compatibility") != COMPATIBILITY:
		return _error("MES registered-definition call edit compatibility changed.")
	var retained_hash := str(document.get("payload_sha256", ""))
	if not ContractValues.is_sha256(retained_hash) or FingerprintScript.new().fingerprint(document) != retained_hash:
		return _error("MES registered-definition call edit plan fingerprint changed.")
	var source_identity = document.get("source_identity")
	var registry_identity = document.get("registry_identity")
	if (
		not source_identity is Dictionary
		or not ContractValues.has_only_keys(source_identity, SOURCE_IDENTITY_KEYS)
		or str(source_identity.get("archive", "")).is_empty()
		or str(source_identity.get("entry", "")).is_empty()
		or not ContractValues.is_sha256(str(source_identity.get("archive_sha256", "")))
		or not registry_identity is Dictionary
		or not ContractValues.has_exact_keys(registry_identity, REGISTRY_IDENTITY_KEYS)
		or str(registry_identity.get("archive", "")).is_empty()
		or str(registry_identity.get("entry", "")).is_empty()
		or not ContractValues.hash_values(registry_identity, ["archive_sha256", "entry_sha256", "proof_sha256"])
		or str(source_identity.archive_sha256) != str(registry_identity.archive_sha256)
	):
		return _error("MES registered-definition call edit source identity changed.")
	var inputs = document.get("inputs")
	if (
		not inputs is Dictionary
		or not ContractValues.has_exact_keys(inputs, [
			"editable_ir_sha256", "decompiler_ir_sha256",
			"call_family_proof_sha256", "registry_proof_sha256",
		])
		or not ContractValues.hash_values(inputs, inputs.keys())
		or str(inputs.registry_proof_sha256) != str(registry_identity.proof_sha256)
	):
		return _error("MES registered-definition call edit input identity changed.")
	var operation = document.get("operation")
	if (
		not operation is Dictionary
		or not ContractValues.has_exact_keys(operation, OPERATION_KEYS)
		or str(operation.get("kind", "")) != "replace_registered_definition_literal"
		or not ContractValues.nonnegative_json_integer(operation.get("source_offset", -1))
		or not ContractValues.nonnegative_json_integer(operation.get("selector", -1))
		or int(operation.selector) > 0x7F
		or not ContractValues.is_sha256(str(operation.get("instruction_raw_sha256", "")))
	):
		return _error("MES registered-definition call edit operation changed.")
	var target = document.get("target")
	var replacement = document.get("replacement")
	if not target is Dictionary or not ContractValues.has_exact_keys(target, TARGET_KEYS):
		return _error("MES registered-definition call edit target fields changed.")
	if not replacement is Dictionary or not ContractValues.has_exact_keys(replacement, REPLACEMENT_KEYS):
		return _error("MES registered-definition call edit replacement fields changed.")
	if (
		str(target.get("node_id", "")).is_empty()
		or str(target.get("region_id", "")).is_empty()
		or str(target.get("op", "")) != "definition_invoke"
		or int(target.get("command_id", -1)) != 0x11
		or int(target.get("instruction_start", -1)) != int(operation.source_offset)
		or str(target.get("instruction_raw_sha256", "")) != str(operation.instruction_raw_sha256)
		or int(replacement.get("selector", -1)) != int(operation.selector)
	):
		return _error("MES registered-definition call edit target identity changed.")
	var byte_validation := _validate_bytes(target, replacement)
	if not byte_validation.ok:
		return byte_validation
	if document.get("assembly_ready") != true:
		return _error("MES registered-definition call edit plan is not assembly ready.")
	if document.get("invariants") != INVARIANTS:
		return _error("MES registered-definition call edit invariants changed.")
	return {
		"ok": true,
		"schema": ContentCoreVersionScript.MES_REGISTERED_DEFINITION_CALL_EDIT_PLAN_SCHEMA,
		"payload_sha256": retained_hash,
		"source_identity": source_identity.duplicate(true),
		"registry_identity": registry_identity.duplicate(true),
		"instruction_start": int(target.instruction_start),
		"literal_start": int(target.literal_start),
		"physical_resume_offset": int(target.call_proof.physical_resume_offset),
		"source_selector": int(target.selector),
		"replacement_selector": int(replacement.selector),
		"source_body_start": int(target.registry_binding.body_start),
		"source_body_end": int(target.registry_binding.body_end),
		"replacement_body_start": int(replacement.registry_binding.body_start),
		"replacement_body_end": int(replacement.registry_binding.body_end),
		"mes_bytes": false,
	}


func _validate_bytes(target: Dictionary, replacement: Dictionary) -> Dictionary:
	for key in [
		"instruction_start", "instruction_end", "record_list_start", "record_list_end",
		"expression_start", "expression_end", "literal_start", "literal_end",
		"selector", "width", "expression_terminator_offset",
		"expression_terminator", "record_terminator_offset", "record_terminator",
	]:
		if not ContractValues.nonnegative_json_integer(target.get(key, -1)):
			return _error("MES registered-definition call edit target coordinate changed.")
	if (
		not ContractValues.nonnegative_json_integer(replacement.get("selector", -1))
		or not ContractValues.nonnegative_json_integer(replacement.get("width", -1))
		or int(target.width) != 8 or int(replacement.width) != 8
		or int(target.selector) > 0x7F or int(replacement.selector) > 0x7F
		or int(target.selector) == int(replacement.selector)
	):
		return _error("MES registered-definition call edit replacement literal changed.")
	var source_literal := ContractValues.checked_bytes(target, "literal")
	var source_expression := ContractValues.checked_bytes(target, "expression")
	var source_instruction := ContractValues.checked_bytes(target, "instruction")
	var output_literal := ContractValues.checked_bytes(replacement, "literal")
	var output_expression := ContractValues.checked_bytes(replacement, "expression")
	var output_instruction := ContractValues.checked_bytes(replacement, "instruction")
	if (
		source_literal != PackedByteArray([int(target.selector)])
		or output_literal != PackedByteArray([int(replacement.selector)])
		or source_expression != _join(source_literal, PackedByteArray([0xFF]))
		or output_expression != _join(output_literal, PackedByteArray([0xFF]))
		or source_instruction != _join(PackedByteArray([0x11, 0x02]), source_expression, PackedByteArray([0]))
		or output_instruction != _join(PackedByteArray([0x11, 0x02]), output_expression, PackedByteArray([0]))
	):
		return _error("MES registered-definition call edit instruction bytes changed.")
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
		return _error("MES registered-definition call edit record boundary changed.")
	var call = target.get("call_proof")
	if not call is Dictionary or not ContractValues.has_exact_keys(call, CALL_PROOF_KEYS):
		return _error("MES registered-definition call edit call proof fields changed.")
	if (
		int(call.get("call_start", -1)) != start
		or int(call.get("call_end", -1)) != start + 5
		or int(call.get("physical_resume_offset", -1)) != start + 5
		or int(call.get("selector", -1)) != int(target.selector)
		or str(call.get("proof_status", ""))
		!= "typed_registered_selector_and_exact_physical_resume"
		or str(call.get("native_role", ""))
		!= "registered_definition_lookup_call_and_restore"
		or str(call.get("registry_binding_status", ""))
		!= "source_and_replacement_exact_body_boundaries_supplied"
		or str(call.get("return_edge", ""))
		!= "unproved_registered_body_total_return_not_supplied"
		or not ContractValues.is_sha256(str(call.get("physical_resume_raw_sha256", "")))
	):
		return _error("MES registered-definition call edit call proof changed.")
	for binding_pair in [
		[target.get("registry_binding"), int(target.selector)],
		[replacement.get("registry_binding"), int(replacement.selector)],
	]:
		if not _valid_registry_binding(binding_pair[0], binding_pair[1]):
			return _error("MES registered-definition call edit registry binding changed.")
	return {"ok": true}


func _valid_registry_binding(value: Variant, selector: int) -> bool:
	if not value is Dictionary:
		return false
	var row: Dictionary = value
	if not ContractValues.has_exact_keys(row, REGISTRY_BINDING_KEYS):
		return false
	if not ContractValues.nonnegative_integer_values(row, [
		"selector", "registration_start", "registration_end", "selector_start",
		"selector_end", "expression_start", "expression_end", "body_start",
		"body_end", "body_size", "skip_target",
	]):
		return false
	return (
		int(row.selector) == selector and selector <= 0x7F
		and int(row.registration_end) == int(row.body_start)
		and int(row.body_end) == int(row.skip_target)
		and int(row.body_size) == int(row.body_end) - int(row.body_start)
		and int(row.body_size) > 0
		and int(row.registration_start) < int(row.selector_start)
		and int(row.selector_end) == int(row.selector_start) + 1
		and int(row.expression_start) == int(row.selector_start)
		and int(row.expression_end) == int(row.selector_end) + 1
		and int(row.expression_end) <= int(row.registration_end)
		and ContractValues.hash_values(row, [
			"registration_raw_sha256", "selector_raw_sha256",
			"expression_raw_sha256", "body_raw_sha256",
		])
		and str(row.body_execution) == "not_performed"
		and str(row.proof_status)
		== "literal_command14_registration_with_exact_body_boundary"
	)


func _join(first: PackedByteArray, second: PackedByteArray, third := PackedByteArray()) -> PackedByteArray:
	var result := PackedByteArray()
	result.append_array(first)
	result.append_array(second)
	result.append_array(third)
	return result


func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message}
