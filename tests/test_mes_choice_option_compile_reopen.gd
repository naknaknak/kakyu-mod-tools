extends "res://tests/test_case.gd"

const ReopenScript := preload("res://content_core/mes_choice_option_compile_reopen.gd")


func _ready() -> void:
	var source_payload := "FIRST".to_utf8_buffer()
	var output_payload := "OTHER".to_utf8_buffer()
	var source_instruction := _join(PackedByteArray([0x01]), source_payload, PackedByteArray([0]))
	var output_instruction := _join(PackedByteArray([0x01]), output_payload, PackedByteArray([0]))
	var return_raw := PackedByteArray([0])
	var source_code := _code(source_instruction, return_raw)
	var output_code := _code(output_instruction, return_raw)
	var preamble := PackedByteArray([2, 0, 0, 0, 0, 0, 0, 0, 13, 0, 0, 0])
	var source := _join(preamble, source_code)
	var output := _join(preamble, output_code)
	var audit := _audit(
		source, output, source_code, output_code, preamble,
		source_payload, output_payload, source_instruction, output_instruction,
		return_raw
	)
	var reopener := ReopenScript.new()
	var result := reopener.audit(output, audit)
	_check(
		result.ok
		and result.edited_option.group_selector == 0
		and result.edited_option.definition_id == 0
		and result.edited_option.instruction_start == 5
		and result.edited_option.payload_start == 6
		and result.edited_option.payload_end == 11
		and result.edited_option.return_start == 12
		and result.retained_contract.terminal_start == 18
		and result.retained_contract.physical_resume_start == 23
		and result.coverage.node_count >= 6,
		"choice-option edit reopens through Phase 1-4"
	)
	var transported = JSON.parse_string(JSON.stringify(audit))
	_check(
		transported is Dictionary and reopener.audit(output, transported).ok,
		"choice-option compile audit survives JSON transport"
	)

	var changed_output := output.duplicate()
	changed_output[18] = 0x58
	_check(not reopener.audit(changed_output, audit).ok, "changed choice-option output is rejected")

	var changed_resume: Dictionary = audit.duplicate(true)
	changed_resume.retained_contract.physical_resume_end = 25
	changed_resume.payload_sha256 = reopener.fingerprint(changed_resume)
	_check(not reopener.audit(output, changed_resume).ok, "changed physical resume is rejected")

	var changed_structure: Dictionary = audit.duplicate(true)
	changed_structure.retained_contract.output_structure_sha256 = "9".repeat(64)
	changed_structure.payload_sha256 = reopener.fingerprint(changed_structure)
	_check(not reopener.audit(output, changed_structure).ok, "changed group structure hash is rejected")

	var fractional: Dictionary = audit.duplicate(true)
	fractional.patch.code_start = 6.5
	fractional.payload_sha256 = reopener.fingerprint(fractional)
	_check(not reopener.audit(output, fractional).ok, "fractional option coordinates are rejected")

	var unknown: Dictionary = audit.duplicate(true)
	unknown["ignored"] = true
	unknown.payload_sha256 = reopener.fingerprint(unknown)
	_check(not reopener.audit(output, unknown).ok, "unknown choice compile fields are rejected")

	var stale: Dictionary = audit.duplicate(true)
	stale.patch.definition_id = 1
	_check(not reopener.audit(output, stale).ok, "stale choice compile fingerprint is rejected")
	await get_tree().process_frame
	get_tree().quit(1 if _failed else 0)


func _code(instruction: PackedByteArray, return_raw: PackedByteArray) -> PackedByteArray:
	var code := PackedByteArray([0x17, 0, 0, 0, 0])
	code.append_array(instruction)
	code.append_array(return_raw)
	code.append_array(PackedByteArray([0x17, 0, 0, 0, 0]))
	code.append_array(PackedByteArray([0x1D, 0x02, 40, 0xFF, 0]))
	code.append_array(PackedByteArray([0]))
	return code


func _audit(
	source: PackedByteArray,
	output: PackedByteArray,
	source_code: PackedByteArray,
	output_code: PackedByteArray,
	preamble: PackedByteArray,
	source_payload: PackedByteArray,
	output_payload: PackedByteArray,
	source_instruction: PackedByteArray,
	output_instruction: PackedByteArray,
	return_raw: PackedByteArray
) -> Dictionary:
	var source_body := _join(source_instruction, return_raw)
	var output_body := _join(output_instruction, return_raw)
	var address_table := preamble.slice(4)
	var document := {
		"ok": true,
		"schema": "kakyu_mes_choice_option_compile_audit/v1",
		"producer": {
			"implementation": "python_phase6_choice_option_compiler",
			"contract": "kakyu_mes_choice_option_compile_audit/v1",
		},
		"compatibility": ReopenScript.COMPATIBILITY.duplicate(true),
		"source_identity": {
			"archive": "mes.arc", "archive_sha256": "a".repeat(64),
			"entry": "CHOICE.MES", "entry_sha256": _sha256(source),
		},
		"inputs": {
			"choice_proof_sha256": "b".repeat(64),
			"choice_option_plan_sha256": "c".repeat(64),
		},
		"source": _summary(source, source_code, address_table, "b".repeat(64)),
		"output": _summary(output, output_code, address_table, "d".repeat(64)),
		"patch": {
			"group_selector": 0, "definition_id": 0,
			"code_start": 6, "code_end": 11,
			"absolute_start": 18, "absolute_end": 23, "payload_size": 5,
			"source_payload_sha256": _sha256(source_payload),
			"replacement_payload_sha256": _sha256(output_payload),
			"source_instruction_sha256": _sha256(source_instruction),
			"replacement_instruction_sha256": _sha256(output_instruction),
			"source_body_sha256": _sha256(source_body),
			"replacement_body_sha256": _sha256(output_body),
			"byte_delta": 0,
		},
		"retained_contract": {
			"address_entry_index": 0, "address_entry_start": 0,
			"address_entry_end": 24,
			"source_structure_sha256": "e".repeat(64),
			"output_structure_sha256": "e".repeat(64),
			"result_mapping_sha256": "f".repeat(64),
			"terminal_start": 18, "terminal_end": 23,
			"terminal_raw_sha256": _sha256(output_code.slice(18, 23)),
			"physical_resume_start": 23, "physical_resume_end": 24,
			"physical_resume_raw_sha256": _sha256(output_code.slice(23, 24)),
			"source_prefix_sha256": _sha256(source.slice(0, 18)),
			"source_suffix_sha256": _sha256(source.slice(23)),
			"unchanged_definition_count": 1,
		},
		"invariants": ReopenScript.INVARIANTS.duplicate(true),
	}
	document["payload_sha256"] = ReopenScript.new().fingerprint(document)
	return document


func _summary(
	payload: PackedByteArray,
	code: PackedByteArray,
	address_table: PackedByteArray,
	proof_sha256: String
) -> Dictionary:
	return {
		"size": payload.size(), "entry_count": 2, "code_offset": 12,
		"code_size": code.size(), "entry_sha256": _sha256(payload),
		"bytecode_sha256": _sha256(code),
		"address_table_sha256": _sha256(address_table),
		"choice_proof_sha256": proof_sha256,
	}


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
