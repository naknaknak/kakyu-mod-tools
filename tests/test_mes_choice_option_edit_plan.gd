extends "res://tests/test_case.gd"

const PlanScript := preload("res://content_core/mes_choice_option_edit_plan.gd")


func _ready() -> void:
	var validator := PlanScript.new()
	var plan := _plan()
	var result := validator.validate(plan)
	_check(
		result.ok
		and result.group_selector == 0
		and result.definition_id == 0
		and result.payload_start == 15
		and result.payload_end == 20
		and result.payload_size == 5
		and result.routine40_terminal == 80
		and result.physical_resume == 85
		and result.byte_delta == 0
		and not result.mes_bytes,
		"choice-option edit plan validates"
	)
	var transported = JSON.parse_string(JSON.stringify(plan))
	_check(
		transported is Dictionary and validator.validate(transported).ok,
		"choice-option edit plan survives JSON transport"
	)

	var changed_payload: Dictionary = plan.duplicate(true)
	changed_payload.replacement.payload_raw_hex = "5448455245"
	changed_payload.payload_sha256 = validator.FingerprintScript.new().fingerprint(changed_payload)
	_check(not validator.validate(changed_payload).ok, "replacement payload hash remains exact")

	var changed_boundary: Dictionary = plan.duplicate(true)
	changed_boundary.target.payload_end = 21
	changed_boundary.payload_sha256 = validator.FingerprintScript.new().fingerprint(changed_boundary)
	_check(not validator.validate(changed_boundary).ok, "option payload boundary remains exact")

	var changed_resume: Dictionary = plan.duplicate(true)
	changed_resume.retained_contract.physical_resume_start = 86
	changed_resume.payload_sha256 = validator.FingerprintScript.new().fingerprint(changed_resume)
	_check(not validator.validate(changed_resume).ok, "routine-40 physical resume remains exact")

	var fractional: Dictionary = plan.duplicate(true)
	fractional.target.instruction_start = 14.5
	fractional.payload_sha256 = validator.FingerprintScript.new().fingerprint(fractional)
	_check(not validator.validate(fractional).ok, "fractional choice coordinates are rejected")

	var unknown: Dictionary = plan.duplicate(true)
	unknown["ignored"] = true
	unknown.payload_sha256 = validator.FingerprintScript.new().fingerprint(unknown)
	_check(not validator.validate(unknown).ok, "unknown choice-option fields are rejected")

	var stale: Dictionary = plan.duplicate(true)
	stale.operation.definition_id = 1
	_check(not validator.validate(stale).ok, "stale choice-option fingerprint is rejected")
	await get_tree().process_frame
	get_tree().quit(1 if _failed else 0)


func _plan() -> Dictionary:
	var source_payload := "FIRST".to_utf8_buffer()
	var output_payload := "OTHER".to_utf8_buffer()
	var return_raw := PackedByteArray([0])
	var source_instruction := _join(PackedByteArray([0x01]), source_payload, PackedByteArray([0]))
	var output_instruction := _join(PackedByteArray([0x01]), output_payload, PackedByteArray([0]))
	var source_body := _join(source_instruction, return_raw)
	var output_body := _join(output_instruction, return_raw)
	var document := {
		"ok": true,
		"schema": "kakyu_mes_choice_option_edit_plan/v1",
		"producer": {
			"implementation": "python_phase6_choice_option_edit_planner",
			"contract": "kakyu_mes_choice_option_edit_plan/v1",
		},
		"compatibility": PlanScript.COMPATIBILITY.duplicate(true),
		"source_identity": {
			"archive": "mes.arc", "archive_sha256": "a".repeat(64),
			"entry": "CHOICE.MES", "entry_sha256": "b".repeat(64),
		},
		"inputs": {"choice_proof_sha256": "c".repeat(64)},
		"operation": {
			"kind": "replace_choice_option_cp932_same_length",
			"group_selector": 0, "definition_id": 0,
			"source_payload_sha256": _sha256(source_payload),
			"text": "OTHER", "encoding": "cp932",
		},
		"target": {
			"group_selector": 0, "definition_id": 0,
			"registration_start": 5, "registration_end": 14,
			"registration_raw_sha256": "d".repeat(64),
			"body_start": 14, "body_end": 22,
			"body_raw_hex": source_body.hex_encode(),
			"body_raw_sha256": _sha256(source_body),
			"instruction_start": 14, "instruction_end": 21,
			"instruction_raw_hex": source_instruction.hex_encode(),
			"instruction_raw_sha256": _sha256(source_instruction),
			"payload_start": 15, "payload_end": 20, "payload_size": 5,
			"payload_raw_hex": source_payload.hex_encode(),
			"payload_raw_sha256": _sha256(source_payload),
			"terminator_offset": 20, "terminator": 0,
			"return_start": 21, "return_end": 22,
			"return_raw_hex": return_raw.hex_encode(),
			"return_raw_sha256": _sha256(return_raw),
			"guard_sha256": "e".repeat(64),
		},
		"replacement": {
			"text": "OTHER", "encoding": "cp932", "payload_size": 5,
			"payload_raw_hex": output_payload.hex_encode(),
			"payload_raw_sha256": _sha256(output_payload),
			"instruction_raw_hex": output_instruction.hex_encode(),
			"instruction_raw_sha256": _sha256(output_instruction),
			"body_raw_hex": output_body.hex_encode(),
			"body_raw_sha256": _sha256(output_body),
			"byte_delta": 0, "output_entry_sha256": "f".repeat(64),
			"output_bytecode_sha256": "1".repeat(64),
		},
		"retained_contract": {
			"choice_proof_sha256": "c".repeat(64),
			"address_entry_index": 0, "address_entry_start": 0,
			"address_entry_end": 100, "groups_sha256": "2".repeat(64),
			"result_mapping_sha256": "3".repeat(64),
			"terminal_start": 80, "terminal_end": 85,
			"terminal_raw_sha256": "4".repeat(64),
			"physical_resume_start": 85, "physical_resume_end": 86,
			"physical_resume_raw_sha256": "5".repeat(64),
			"source_prefix_sha256": "6".repeat(64),
			"source_suffix_sha256": "7".repeat(64),
			"all_bytes_outside_payload_unchanged": true,
			"all_coordinates_unchanged": true,
			"native_input_and_gameplay_labels": "unresolved",
		},
		"assembly_ready": true,
		"invariants": PlanScript.INVARIANTS.duplicate(true),
	}
	document["payload_sha256"] = PlanScript.FingerprintScript.new().fingerprint(document)
	return document


func _join(first: PackedByteArray, second: PackedByteArray, third := PackedByteArray()) -> PackedByteArray:
	var result := PackedByteArray()
	result.append_array(first)
	result.append_array(second)
	result.append_array(third)
	return result


func _sha256(data: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(data)
	return context.finish().hex_encode()
