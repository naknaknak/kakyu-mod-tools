extends "res://tests/test_case.gd"

const PlanScript := preload("res://content_core/mes_registered_definition_call_edit_plan.gd")


func _ready() -> void:
	var validator := PlanScript.new()
	var plan := _plan()
	var result := validator.validate(plan)
	_check(
		result.ok
		and result.instruction_start == 0
		and result.literal_start == 2
		and result.source_selector == 3
		and result.replacement_selector == 4
		and result.physical_resume_offset == 5
		and result.source_body_start == 20
		and result.replacement_body_start == 40,
		"registered-definition call edit plan validates"
	)
	var transported = JSON.parse_string(JSON.stringify(plan))
	_check(validator.validate(transported).ok, "registered-definition plan survives JSON transport")

	var changed_selector: Dictionary = plan.duplicate(true)
	changed_selector.replacement.literal_raw_hex = "05"
	changed_selector.replacement.literal_raw_sha256 = _sha256("05".hex_decode())
	changed_selector.payload_sha256 = validator.FingerprintScript.new().fingerprint(changed_selector)
	_check(not validator.validate(changed_selector).ok, "replacement literal bytes are bound")

	var changed_resume: Dictionary = plan.duplicate(true)
	changed_resume.target.call_proof.physical_resume_offset = 6
	changed_resume.payload_sha256 = validator.FingerprintScript.new().fingerprint(changed_resume)
	_check(not validator.validate(changed_resume).ok, "physical resume remains exact")

	var changed_body: Dictionary = plan.duplicate(true)
	changed_body.replacement.registry_binding.body_end = 42
	changed_body.payload_sha256 = validator.FingerprintScript.new().fingerprint(changed_body)
	_check(not validator.validate(changed_body).ok, "replacement registry body remains exact")

	var fractional: Dictionary = plan.duplicate(true)
	fractional.target.literal_start = 2.5
	fractional.payload_sha256 = validator.FingerprintScript.new().fingerprint(fractional)
	_check(not validator.validate(fractional).ok, "fractional call coordinates are rejected")

	var unknown: Dictionary = plan.duplicate(true)
	unknown["ignored"] = true
	unknown.payload_sha256 = validator.FingerprintScript.new().fingerprint(unknown)
	_check(not validator.validate(unknown).ok, "unknown registered-call fields are rejected")

	var stale: Dictionary = plan.duplicate(true)
	stale.operation.selector = 5
	_check(not validator.validate(stale).ok, "stale registered-call fingerprint is rejected")
	await get_tree().process_frame
	get_tree().quit(1 if _failed else 0)


func _plan() -> Dictionary:
	var source_literal := PackedByteArray([3])
	var source_expression := PackedByteArray([3, 0xFF])
	var source_instruction := PackedByteArray([0x11, 0x02, 3, 0xFF, 0])
	var output_literal := PackedByteArray([4])
	var output_expression := PackedByteArray([4, 0xFF])
	var output_instruction := PackedByteArray([0x11, 0x02, 4, 0xFF, 0])
	var source_binding := _binding(3, 10, 20, 21)
	var replacement_binding := _binding(4, 30, 40, 41)
	var call_proof := {
		"id": "registered_call_00000000",
		"call_node_id": "linear_00000000",
		"caller_entry": "CALL.MES",
		"caller_region": "entry_0000",
		"call_start": 0,
		"call_end": 5,
		"physical_resume_offset": 5,
		"physical_resume_node_id": "linear_00000005",
		"physical_resume_region": "entry_0000",
		"physical_resume_raw_sha256": _sha256(PackedByteArray([0])),
		"selector": 3,
		"proof_status": "typed_registered_selector_and_exact_physical_resume",
		"native_role": "registered_definition_lookup_call_and_restore",
		"registry_binding_status": "source_and_replacement_exact_body_boundaries_supplied",
		"return_edge": "unproved_registered_body_total_return_not_supplied",
	}
	var document := {
		"ok": true,
		"schema": "kakyu_mes_registered_definition_call_edit_plan/v1",
		"producer": {
			"implementation": "python_phase6_registered_definition_call_edit_planner",
			"contract": "kakyu_mes_registered_definition_call_edit_plan/v1",
		},
		"compatibility": PlanScript.COMPATIBILITY.duplicate(true),
		"source_identity": {
			"archive": "mes.arc", "entry": "CALL.MES",
			"source_kind": "original_arc", "archive_sha256": "a".repeat(64),
		},
		"registry_identity": {
			"archive": "mes.arc", "archive_sha256": "a".repeat(64),
			"entry": "DEF_TEST.MES", "entry_sha256": "b".repeat(64),
			"proof_sha256": "c".repeat(64),
		},
		"inputs": {
			"editable_ir_sha256": "1".repeat(64),
			"decompiler_ir_sha256": "2".repeat(64),
			"call_family_proof_sha256": "3".repeat(64),
			"registry_proof_sha256": "c".repeat(64),
		},
		"operation": {
			"kind": "replace_registered_definition_literal", "source_offset": 0,
			"instruction_raw_sha256": _sha256(source_instruction), "selector": 4,
		},
		"target": {
			"node_id": "linear_00000000", "region_id": "entry_0000",
			"op": "definition_invoke", "command_id": 0x11,
			"instruction_start": 0, "instruction_end": 5,
			"instruction_raw_hex": source_instruction.hex_encode(),
			"instruction_raw_sha256": _sha256(source_instruction),
			"record_list_start": 1, "record_list_end": 5,
			"expression_start": 2, "expression_end": 4,
			"expression_raw_hex": source_expression.hex_encode(),
			"expression_raw_sha256": _sha256(source_expression),
			"literal_start": 2, "literal_end": 3,
			"literal_raw_hex": source_literal.hex_encode(),
			"literal_raw_sha256": _sha256(source_literal),
			"selector": 3, "width": 8,
			"expression_terminator_offset": 3, "expression_terminator": 0xFF,
			"record_terminator_offset": 4, "record_terminator": 0,
			"call_proof": call_proof,
			"registry_binding": source_binding,
		},
		"replacement": {
			"selector": 4, "width": 8,
			"literal_raw_hex": output_literal.hex_encode(),
			"literal_raw_sha256": _sha256(output_literal),
			"expression_raw_hex": output_expression.hex_encode(),
			"expression_raw_sha256": _sha256(output_expression),
			"instruction_raw_hex": output_instruction.hex_encode(),
			"instruction_raw_sha256": _sha256(output_instruction),
			"registry_binding": replacement_binding,
		},
		"assembly_ready": true,
		"invariants": PlanScript.INVARIANTS.duplicate(true),
	}
	document["payload_sha256"] = PlanScript.FingerprintScript.new().fingerprint(document)
	return document


func _binding(selector: int, start: int, body_start: int, body_end: int) -> Dictionary:
	return {
		"selector": selector,
		"registration_start": start,
		"registration_end": body_start,
		"registration_raw_sha256": "1".repeat(64),
		"selector_start": start + 1,
		"selector_end": start + 2,
		"selector_raw_sha256": "2".repeat(64),
		"expression_start": start + 1,
		"expression_end": start + 3,
		"expression_raw_sha256": "3".repeat(64),
		"body_start": body_start,
		"body_end": body_end,
		"body_size": body_end - body_start,
		"body_raw_sha256": "4".repeat(64),
		"skip_target": body_end,
		"body_execution": "not_performed",
		"proof_status": "literal_command14_registration_with_exact_body_boundary",
	}


func _sha256(data: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(data)
	return context.finish().hex_encode()
