extends "res://tests/test_case.gd"

const PlanScript := preload("res://content_core/mes_condition_literal_edit_plan.gd")
const FingerprintScript := preload("res://content_core/mes_payload_fingerprint.gd")


func _ready() -> void:
	var validator := PlanScript.new()
	var source := _fixture()
	var valid := validator.validate(source)
	_check(
		valid.ok
		and valid.instruction_start == 0x0134
		and valid.literal_start == 0x0138
		and valid.source_value == 1
		and valid.replacement_value == 0
		and valid.false_target == 0x0169
		and not valid.mes_bytes,
		"exact condition literal edit plan validates"
	)
	var transported = JSON.parse_string(JSON.stringify(source))
	_check(
		transported is Dictionary and validator.validate(transported).ok,
		"condition literal edit plan survives JSON number transport"
	)
	_check(
		validator.validate(_fixture_u16()).ok,
		"same-width 16-bit condition literal plan validates"
	)
	var changed_target := source.duplicate(true)
	changed_target.target.false_target.value = 0x0168
	_rehash(changed_target)
	_check(
		not validator.validate(changed_target).ok,
		"false-target value must match the retained operand"
	)
	var changed_terminator := source.duplicate(true)
	changed_terminator.target.terminator = 0
	_rehash(changed_terminator)
	_check(
		not validator.validate(changed_terminator).ok,
		"condition terminator remains fixed"
	)
	var changed_condition := source.duplicate(true)
	var condition: PackedByteArray = str(
		changed_condition.target.condition_raw_hex
	).hex_decode()
	condition[0] ^= 1
	changed_condition.target.condition_raw_hex = condition.hex_encode()
	changed_condition.target.condition_raw_sha256 = _sha256(condition)
	_rehash(changed_condition)
	_check(
		not validator.validate(changed_condition).ok,
		"condition slice must match the retained instruction"
	)
	var ambiguous_u8 := source.duplicate(true)
	ambiguous_u8.operation.value = 0x80
	ambiguous_u8.replacement.value = 0x80
	ambiguous_u8.replacement.literal_raw_hex = "80"
	ambiguous_u8.replacement.literal_raw_sha256 = _sha256("80".hex_decode())
	ambiguous_u8.replacement.condition_raw_hex = "f31f0c80efff"
	ambiguous_u8.replacement.condition_raw_sha256 = _sha256("f31f0c80efff".hex_decode())
	ambiguous_u8.replacement.instruction_raw_hex = "0bf31f0c80efff69010000"
	ambiguous_u8.replacement.instruction_raw_sha256 = _sha256(
		"0bf31f0c80efff69010000".hex_decode()
	)
	_rehash(ambiguous_u8)
	_check(
		not validator.validate(ambiguous_u8).ok,
		"ambiguous 8-bit condition tokens remain rejected"
	)
	var fractional := source.duplicate(true)
	fractional.target.literal_start = 312.5
	_rehash(fractional)
	_check(
		not validator.validate(fractional).ok,
		"condition literal edit plan rejects fractional JSON coordinates"
	)
	var unknown := source.duplicate(true)
	unknown["ignored"] = true
	_rehash(unknown)
	_check(
		not validator.validate(unknown).ok,
		"condition literal edit plan rejects unknown fields"
	)
	var stale := source.duplicate(true)
	stale.replacement.value = 2
	_check(
		not validator.validate(stale).ok,
		"condition literal edit plan rejects a stale fingerprint"
	)
	await get_tree().process_frame
	get_tree().quit(1 if _failed else 0)


func _fixture() -> Dictionary:
	var source_instruction := "0bf31f0c01efff69010000".hex_decode()
	var source_condition := "f31f0c01efff".hex_decode()
	var source_literal := "01".hex_decode()
	var false_target := "69010000".hex_decode()
	var output_instruction := "0bf31f0c00efff69010000".hex_decode()
	var output_condition := "f31f0c00efff".hex_decode()
	var output_literal := "00".hex_decode()
	var document := {
		"ok": true,
		"schema": "kakyu_mes_condition_literal_edit_plan/v1",
		"producer": {
			"implementation": "python_phase6_condition_literal_edit_planner",
			"contract": "kakyu_mes_condition_literal_edit_plan/v1",
		},
		"compatibility": PlanScript.COMPATIBILITY.duplicate(true),
		"source_identity": {
			"archive": "mes.arc",
			"entry": "03C.MES",
			"archive_sha256": "a".repeat(64),
		},
		"inputs": {
			"editable_ir_sha256": "1".repeat(64),
			"decompiler_ir_sha256": "2".repeat(64),
		},
		"operation": {
			"kind": "replace_condition_literal",
			"source_offset": 0x0134,
			"instruction_raw_sha256": _sha256(source_instruction),
			"literal_offset": 0x0138,
			"value": 0,
		},
		"target": {
			"node_id": "linear_00000134",
			"region_id": "entry_0000",
			"op": "branch_if_not_true",
			"command_id": 0x0B,
			"instruction_start": 0x0134,
			"instruction_end": 0x013F,
			"instruction_raw_hex": source_instruction.hex_encode(),
			"instruction_raw_sha256": _sha256(source_instruction),
			"condition_start": 0x0135,
			"condition_end": 0x013B,
			"condition_raw_hex": source_condition.hex_encode(),
			"condition_raw_sha256": _sha256(source_condition),
			"literal_start": 0x0138,
			"literal_end": 0x0139,
			"literal_raw_hex": source_literal.hex_encode(),
			"literal_raw_sha256": _sha256(source_literal),
			"value": 1,
			"width": 8,
			"terminator_offset": 0x013A,
			"terminator": 0xFF,
			"false_target": {
				"reference_id": "code_00000001",
				"operand_start": 0x013B,
				"operand_end": 0x013F,
				"operand_raw_hex": false_target.hex_encode(),
				"operand_raw_sha256": _sha256(false_target),
				"value": 0x0169,
				"in_code": true,
				"aligned": true,
				"target_region": "entry_0000",
			},
		},
		"replacement": {
			"value": 0,
			"width": 8,
			"literal_raw_hex": output_literal.hex_encode(),
			"literal_raw_sha256": _sha256(output_literal),
			"condition_raw_hex": output_condition.hex_encode(),
			"condition_raw_sha256": _sha256(output_condition),
			"instruction_raw_hex": output_instruction.hex_encode(),
			"instruction_raw_sha256": _sha256(output_instruction),
		},
		"assembly_ready": true,
		"invariants": PlanScript.INVARIANTS.duplicate(true),
	}
	_rehash(document)
	return document


func _fixture_u16() -> Dictionary:
	var document := _fixture()
	var source_instruction := "0bf30100f13412efff00000000".hex_decode()
	var source_condition := "f30100f13412efff".hex_decode()
	var source_literal := "f13412".hex_decode()
	var output_instruction := "0bf30100f17856efff00000000".hex_decode()
	var output_condition := "f30100f17856efff".hex_decode()
	var output_literal := "f17856".hex_decode()
	document.operation.source_offset = 0
	document.operation.instruction_raw_sha256 = _sha256(source_instruction)
	document.operation.literal_offset = 4
	document.operation.value = 0x5678
	document.target.node_id = "linear_00000000"
	document.target.instruction_start = 0
	document.target.instruction_end = 13
	document.target.instruction_raw_hex = source_instruction.hex_encode()
	document.target.instruction_raw_sha256 = _sha256(source_instruction)
	document.target.condition_start = 1
	document.target.condition_end = 9
	document.target.condition_raw_hex = source_condition.hex_encode()
	document.target.condition_raw_sha256 = _sha256(source_condition)
	document.target.literal_start = 4
	document.target.literal_end = 7
	document.target.literal_raw_hex = source_literal.hex_encode()
	document.target.literal_raw_sha256 = _sha256(source_literal)
	document.target.value = 0x1234
	document.target.width = 16
	document.target.terminator_offset = 8
	document.target.false_target.reference_id = "code_00000000"
	document.target.false_target.operand_start = 9
	document.target.false_target.operand_end = 13
	document.target.false_target.operand_raw_hex = "00000000"
	document.target.false_target.operand_raw_sha256 = _sha256("00000000".hex_decode())
	document.target.false_target.value = 0
	document.replacement.value = 0x5678
	document.replacement.width = 16
	document.replacement.literal_raw_hex = output_literal.hex_encode()
	document.replacement.literal_raw_sha256 = _sha256(output_literal)
	document.replacement.condition_raw_hex = output_condition.hex_encode()
	document.replacement.condition_raw_sha256 = _sha256(output_condition)
	document.replacement.instruction_raw_hex = output_instruction.hex_encode()
	document.replacement.instruction_raw_sha256 = _sha256(output_instruction)
	_rehash(document)
	return document


func _rehash(document: Dictionary) -> void:
	document["payload_sha256"] = FingerprintScript.new().fingerprint(document)


func _sha256(data: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(data)
	return context.finish().hex_encode()
