extends "res://tests/test_case.gd"

const PlanScript := preload("res://content_core/mes_shared_routine_call_edit_plan.gd")


func _ready() -> void:
	var validator := PlanScript.new()
	var plan := _plan()
	var result := validator.validate(plan)
	_check(
		result.ok
		and result.instruction_start == 0
		and result.literal_start == 2
		and result.source_routine_id == 3
		and result.replacement_routine_id == 4
		and result.physical_resume_offset == 5,
		"shared-routine call edit plan validates"
	)
	var transported = JSON.parse_string(JSON.stringify(plan))
	_check(validator.validate(transported).ok, "shared-routine call plan survives JSON number transport")

	var changed_selector: Dictionary = plan.duplicate(true)
	changed_selector.replacement.literal_raw_hex = "05"
	changed_selector.replacement.literal_raw_sha256 = _sha256("05".hex_decode())
	changed_selector.payload_sha256 = validator.FingerprintScript.new().fingerprint(changed_selector)
	_check(not validator.validate(changed_selector).ok, "replacement literal bytes are bound")

	var changed_resume: Dictionary = plan.duplicate(true)
	changed_resume.target.call_proof.physical_resume_offset = 6
	changed_resume.payload_sha256 = validator.FingerprintScript.new().fingerprint(changed_resume)
	_check(not validator.validate(changed_resume).ok, "physical resume remains exact")

	var changed_callee: Dictionary = plan.duplicate(true)
	changed_callee.replacement.callee_proof.routine_id = 5
	changed_callee.payload_sha256 = validator.FingerprintScript.new().fingerprint(changed_callee)
	_check(not validator.validate(changed_callee).ok, "replacement callee proof remains paired")

	var fractional: Dictionary = plan.duplicate(true)
	fractional.target.literal_start = 2.5
	fractional.payload_sha256 = validator.FingerprintScript.new().fingerprint(fractional)
	_check(not validator.validate(fractional).ok, "fractional call coordinates are rejected")

	var unknown: Dictionary = plan.duplicate(true)
	unknown["ignored"] = true
	unknown.payload_sha256 = validator.FingerprintScript.new().fingerprint(unknown)
	_check(not validator.validate(unknown).ok, "unknown call-plan fields are rejected")

	var stale: Dictionary = plan.duplicate(true)
	stale.operation.routine_id = 5
	_check(not validator.validate(stale).ok, "stale call-plan fingerprint is rejected")
	await get_tree().process_frame
	get_tree().quit(1 if _failed else 0)


func _plan() -> Dictionary:
	var source_literal := PackedByteArray([3])
	var source_expression := PackedByteArray([3, 0xFF])
	var source_instruction := PackedByteArray([0x1D, 0x02, 3, 0xFF, 0])
	var output_literal := PackedByteArray([4])
	var output_expression := PackedByteArray([4, 0xFF])
	var output_instruction := PackedByteArray([0x1D, 0x02, 4, 0xFF, 0])
	var source_callee := {
		"id": "shared_call_00000000",
		"call_node_id": "linear_00000000",
		"call_start": 0,
		"call_end": 5,
		"physical_resume_offset": 5,
		"physical_resume_node_id": "linear_00000005",
		"physical_resume_region": "entry_0000",
		"physical_resume_raw_sha256": _sha256(PackedByteArray([0])),
		"routine_id": 3,
		"callee_entry": "LIBLARY.LIB",
		"callee_registration_offset": 90,
		"callee_body_start": 100,
		"callee_body_end": 101,
		"callee_return_offsets": [100],
		"direct_callee_routine_ids": [],
		"transitive_callee_routine_ids": [],
		"proof_status": "literal_shared_call_all_callee_terminals_return_to_physical_resume",
	}
	var replacement_callee := {
		"routine_id": 4,
		"callee_entry": "LIBLARY.LIB",
		"registration_offset": 190,
		"body_start": 200,
		"body_end": 201,
		"return_offsets": [200],
		"direct_callee_routine_ids": [],
		"transitive_callee_routine_ids": [],
		"proof_status": "replacement_shared_routine_total_return_proved",
	}
	var document := {
		"ok": true,
		"schema": "kakyu_mes_shared_routine_call_edit_plan/v1",
		"producer": {
			"implementation": "python_phase6_shared_routine_call_edit_planner",
			"contract": "kakyu_mes_shared_routine_call_edit_plan/v1",
		},
		"compatibility": PlanScript.COMPATIBILITY.duplicate(true),
		"source_identity": {
			"archive": "mes.arc", "entry": "CALL.MES",
			"source_kind": "original_arc", "archive_sha256": "a".repeat(64),
		},
		"library_identity": {
			"archive_name": "mes.arc", "archive_sha256": "a".repeat(64),
			"entry": "LIBLARY.LIB", "entry_sha256": "b".repeat(64),
		},
		"inputs": {
			"editable_ir_sha256": "1".repeat(64),
			"decompiler_ir_sha256": "2".repeat(64),
			"shared_call_return_proof_sha256": "3".repeat(64),
			"library_audit_sha256": "4".repeat(64),
		},
		"operation": {
			"kind": "replace_shared_routine_literal", "source_offset": 0,
			"instruction_raw_sha256": _sha256(source_instruction), "routine_id": 4,
		},
		"target": {
			"node_id": "linear_00000000", "region_id": "entry_0000",
			"op": "script_transfer", "command_id": 0x1D,
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
			"routine_id": 3, "width": 8,
			"expression_terminator_offset": 3, "expression_terminator": 0xFF,
			"record_terminator_offset": 4, "record_terminator": 0,
			"call_proof": source_callee,
		},
		"replacement": {
			"routine_id": 4, "width": 8,
			"literal_raw_hex": output_literal.hex_encode(),
			"literal_raw_sha256": _sha256(output_literal),
			"expression_raw_hex": output_expression.hex_encode(),
			"expression_raw_sha256": _sha256(output_expression),
			"instruction_raw_hex": output_instruction.hex_encode(),
			"instruction_raw_sha256": _sha256(output_instruction),
			"callee_proof": replacement_callee,
		},
		"assembly_ready": true,
		"invariants": PlanScript.INVARIANTS.duplicate(true),
	}
	document["payload_sha256"] = PlanScript.FingerprintScript.new().fingerprint(document)
	return document


func _sha256(data: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(data)
	return context.finish().hex_encode()
