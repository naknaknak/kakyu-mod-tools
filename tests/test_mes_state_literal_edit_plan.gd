extends "res://tests/test_case.gd"

const PlanScript := preload("res://content_core/mes_state_literal_edit_plan.gd")
const FingerprintScript := preload("res://content_core/mes_payload_fingerprint.gd")


func _ready() -> void:
	var validator := PlanScript.new()
	var source := _fixture()
	var valid := validator.validate(source)
	_check(
		valid.ok
		and valid.storage == "global_u8"
		and valid.instruction_start == 16297
		and valid.source_value == 1
		and valid.replacement_value == 0
		and not valid.mes_bytes,
		"exact state literal edit plan validates"
	)
	var transported = JSON.parse_string(JSON.stringify(source))
	_check(
		transported is Dictionary and validator.validate(transported).ok,
		"state literal edit plan survives JSON number transport"
	)
	var u16_plan := _fixture_u16()
	_check(
		validator.validate(u16_plan).ok,
		"same-width 16-bit state literal plan validates"
	)
	var changed_command := source.duplicate(true)
	changed_command.target.command_id = 4
	changed_command.target.op = "state_u16_write_run"
	changed_command.target.storage = "state_u16"
	_rehash(changed_command)
	_check(
		not validator.validate(changed_command).ok,
		"typed command must match the retained instruction byte"
	)
	var changed_continuation := source.duplicate(true)
	changed_continuation.target.continuation = 1
	_rehash(changed_continuation)
	_check(
		not validator.validate(changed_continuation).ok,
		"retained continuation byte must match the source instruction"
	)
	var wrong_destination := source.duplicate(true)
	wrong_destination.target.destination = {
		"kind": "expression_index",
		"expression_raw_hex": "00ff",
		"expression_raw_sha256": _sha256("00ff".hex_decode()),
		"bank": 0,
	}
	_rehash(wrong_destination)
	_check(
		not validator.validate(wrong_destination).ok,
		"destination shape must match its typed write form"
	)
	var ambiguous_u8 := source.duplicate(true)
	ambiguous_u8.operation.value = 0x80
	ambiguous_u8.replacement.value = 0x80
	ambiguous_u8.replacement.expression_raw_hex = "80ff"
	ambiguous_u8.replacement.expression_raw_sha256 = _sha256("80ff".hex_decode())
	ambiguous_u8.replacement.instruction_raw_hex = "031e0180ff00"
	ambiguous_u8.replacement.instruction_raw_sha256 = _sha256("031e0180ff00".hex_decode())
	_rehash(ambiguous_u8)
	_check(
		not validator.validate(ambiguous_u8).ok,
		"ambiguous 8-bit expression tokens remain rejected"
	)
	var fractional := source.duplicate(true)
	fractional.target.pair_index = 0.5
	_rehash(fractional)
	_check(
		not validator.validate(fractional).ok,
		"state literal edit plan rejects fractional JSON coordinates"
	)
	var unknown := source.duplicate(true)
	unknown["ignored"] = true
	_rehash(unknown)
	_check(
		not validator.validate(unknown).ok,
		"state literal edit plan rejects unknown fields"
	)
	var stale := source.duplicate(true)
	stale.replacement.value = 3
	_check(
		not validator.validate(stale).ok,
		"state literal edit plan rejects a stale fingerprint"
	)
	await get_tree().process_frame
	get_tree().quit(1 if _failed else 0)


func _fixture() -> Dictionary:
	var source_instruction := "031e0101ff00".hex_decode()
	var source_expression := "01ff".hex_decode()
	var output_instruction := "031e0100ff00".hex_decode()
	var output_expression := "00ff".hex_decode()
	var document := {
		"ok": true,
		"schema": "kakyu_mes_state_literal_edit_plan/v1",
		"producer": {
			"implementation": "python_phase6_state_literal_edit_planner",
			"contract": "kakyu_mes_state_literal_edit_plan/v1",
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
			"kind": "replace_state_write_literal",
			"source_offset": 16297,
			"instruction_raw_sha256": _sha256(source_instruction),
			"pair_index": 0,
			"value": 0,
		},
		"target": {
			"node_id": "linear_00003fa9",
			"region_id": "entry_0151",
			"op": "global_u8_write_run",
			"command_id": 3,
			"instruction_start": 16297,
			"instruction_end": 16303,
			"instruction_raw_hex": source_instruction.hex_encode(),
			"instruction_raw_sha256": _sha256(source_instruction),
			"storage": "global_u8",
			"destination": {"kind": "fixed_index", "index": 286, "bank": 0},
			"pair_index": 0,
			"pair_count": 1,
			"continuation_offset": 16302,
			"continuation": 0,
			"expression_start": 16300,
			"expression_end": 16302,
			"expression_raw_hex": source_expression.hex_encode(),
			"expression_raw_sha256": _sha256(source_expression),
			"value": 1,
			"width": 8,
		},
		"replacement": {
			"value": 0,
			"width": 8,
			"expression_raw_hex": output_expression.hex_encode(),
			"expression_raw_sha256": _sha256(output_expression),
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
	var source_instruction := "0402f13412ff00".hex_decode()
	var source_expression := "f13412ff".hex_decode()
	var output_instruction := "0402f17856ff00".hex_decode()
	var output_expression := "f17856ff".hex_decode()
	document.operation.source_offset = 0
	document.operation.instruction_raw_sha256 = _sha256(source_instruction)
	document.operation.value = 0x5678
	document.target.node_id = "linear_00000000"
	document.target.region_id = "entry_0000"
	document.target.op = "state_u16_write_run"
	document.target.command_id = 4
	document.target.instruction_start = 0
	document.target.instruction_end = 7
	document.target.instruction_raw_hex = source_instruction.hex_encode()
	document.target.instruction_raw_sha256 = _sha256(source_instruction)
	document.target.storage = "state_u16"
	document.target.destination = {"kind": "fixed_index", "index": 2, "bank": 0}
	document.target.continuation_offset = 6
	document.target.expression_start = 2
	document.target.expression_end = 6
	document.target.expression_raw_hex = source_expression.hex_encode()
	document.target.expression_raw_sha256 = _sha256(source_expression)
	document.target.value = 0x1234
	document.target.width = 16
	document.replacement.value = 0x5678
	document.replacement.width = 16
	document.replacement.expression_raw_hex = output_expression.hex_encode()
	document.replacement.expression_raw_sha256 = _sha256(output_expression)
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
