extends Node

const PlanScript := preload("res://content_core/mes_control_target_edit_plan.gd")

var _failures := 0


func _ready() -> void:
	var validator := PlanScript.new()
	var source := _fixture()
	var result := validator.validate(source)
	_check(
		result.ok
		and result.reference_kind == "continuation_target"
		and result.source_offset == 0
		and result.current_target_offset == 5
		and result.replacement_target_offset == 6
		and result.changed_byte_count == 1
		and result.mes_bytes == false,
		"exact continuation target edit plan validates"
	)
	var transported = JSON.parse_string(JSON.stringify(source))
	var transported_result := validator.validate(transported) if transported is Dictionary else {"ok": false, "error": "transport failed"}
	if not transported_result.ok:
		print("transport validation error: ", transported_result.get("error", "unknown"))
	_check(
		transported is Dictionary and transported_result.ok,
		"control-target edit plan survives JSON number transport"
	)
	var branch := _branch_fixture()
	_check(
		validator.validate(branch).ok,
		"conditional target edit binds its exact expression bytes"
	)
	var changed_target := source.duplicate(true)
	changed_target.patch.output_raw_hex = "05000000"
	_rehash(changed_target)
	_check(
		not validator.validate(changed_target).ok,
		"control-target edit rejects a changed replacement operand"
	)
	var changed_prefix := source.duplicate(true)
	changed_prefix.patch.output_instruction_raw_hex = "0d06000000"
	changed_prefix.patch.output_instruction_raw_sha256 = _sha256_hex("0d06000000")
	_rehash(changed_prefix)
	_check(
		not validator.validate(changed_prefix).ok,
		"control-target edit rejects changes outside the target operand"
	)
	var unchanged := source.duplicate(true)
	unchanged.operation.replacement_target_offset = 5
	unchanged.replacement_target.instruction_start = 5
	unchanged.patch.output_raw_hex = "05000000"
	unchanged.patch.output_instruction_raw_hex = "0c05000000"
	unchanged.patch.output_instruction_raw_sha256 = _sha256_hex("0c05000000")
	unchanged.coverage.changed_byte_count = 0
	_rehash(unchanged)
	_check(
		not validator.validate(unchanged).ok,
		"control-target edit rejects an unchanged target"
	)
	var fractional := source.duplicate(true)
	fractional.operation.source_offset = 0.5
	_rehash(fractional)
	_check(
		not validator.validate(fractional).ok,
		"control-target edit rejects fractional JSON coordinates"
	)
	var unknown := source.duplicate(true)
	unknown["ignored"] = true
	_rehash(unknown)
	_check(
		not validator.validate(unknown).ok,
		"control-target edit plan rejects unknown fields"
	)
	var stale := source.duplicate(true)
	stale.payload_sha256 = "0".repeat(64)
	_check(
		not validator.validate(stale).ok,
		"control-target edit plan rejects a stale fingerprint"
	)
	get_tree().quit(0 if _failures == 0 else 1)


func _fixture() -> Dictionary:
	var source_hex := "0c05000000"
	var output_hex := "0c06000000"
	var target_hash := _sha256_hex("00")
	var document := {
		"ok": true,
		"schema": "kakyu_mes_control_target_edit_plan/v1",
		"producer": {
			"implementation": "python_phase6_control_target_edit_planner",
			"contract": "kakyu_mes_control_target_edit_plan/v1",
		},
		"compatibility": PlanScript.COMPATIBILITY.duplicate(true),
		"source_identity": {
			"archive": "mes.arc",
			"entry": "CONTROL_EDIT.MES",
			"source_kind": "original_arc",
			"archive_sha256": "a".repeat(64),
		},
		"inputs": {
			"editable_ir_sha256": "b".repeat(64),
			"decompiler_ir_sha256": "c".repeat(64),
		},
		"operation": {
			"kind": "retarget_control_flow",
			"source_offset": 0,
			"reference_kind": "continuation_target",
			"source_instruction_raw_sha256": _sha256_hex(source_hex),
			"replacement_target_offset": 6,
			"replacement_target_instruction_raw_sha256": target_hash,
		},
		"source_control": {
			"node_id": "linear_00000000",
			"evidence_status": "typed_phase1_4",
			"source_region_id": "entry_0000",
			"instruction_start": 0,
			"instruction_end": 5,
			"instruction_raw_sha256": _sha256_hex(source_hex),
			"op": "continuation_transfer",
			"command_id": 0x0C,
			"reference_id": "code_00000000",
			"reference_kind": "continuation_target",
			"operand_start": 1,
			"operand_end": 5,
			"current_target_offset": 5,
			"current_target_node_id": "linear_00000005",
			"expression_kind": "none",
			"expression_start": 1,
			"expression_end": 1,
			"expression_raw_sha256": PlanScript.EMPTY_SHA256,
		},
		"replacement_target": {
			"node_id": "linear_00000006",
			"evidence_status": "typed_phase1_4",
			"source_region_id": "entry_0000",
			"instruction_start": 6,
			"instruction_end": 7,
			"instruction_raw_sha256": target_hash,
			"op": "command_00",
			"command_id": 0,
		},
		"patch": {
			"operand_start": 1,
			"operand_end": 5,
			"source_raw_hex": "05000000",
			"output_raw_hex": "06000000",
			"encoding": "u32_le_absolute_code_offset",
			"source_instruction_raw_hex": source_hex,
			"output_instruction_raw_hex": output_hex,
			"output_instruction_raw_sha256": _sha256_hex(output_hex),
		},
		"coverage": {
			"source_code_size": 7,
			"output_code_size": 7,
			"source_node_count": 3,
			"source_typed_node_count": 3,
			"source_opaque_node_count": 0,
			"changed_byte_count": 1,
		},
		"assembly_ready": true,
		"invariants": PlanScript.INVARIANTS.duplicate(true),
	}
	_rehash(document)
	return document


func _branch_fixture() -> Dictionary:
	var document := _fixture()
	var source_hex := "0b01ff07000000"
	var output_hex := "0b01ff08000000"
	document.operation.reference_kind = "condition_false_target"
	document.operation.source_instruction_raw_sha256 = _sha256_hex(source_hex)
	document.operation.replacement_target_offset = 8
	document.source_control.instruction_end = 7
	document.source_control.instruction_raw_sha256 = _sha256_hex(source_hex)
	document.source_control.op = "branch_if_not_true"
	document.source_control.command_id = 0x0B
	document.source_control.reference_kind = "condition_false_target"
	document.source_control.operand_start = 3
	document.source_control.operand_end = 7
	document.source_control.current_target_offset = 7
	document.source_control.current_target_node_id = "linear_00000007"
	document.source_control.expression_kind = "condition"
	document.source_control.expression_start = 1
	document.source_control.expression_end = 3
	document.source_control.expression_raw_sha256 = _sha256_hex("01ff")
	document.replacement_target.node_id = "linear_00000008"
	document.replacement_target.instruction_start = 8
	document.replacement_target.instruction_end = 9
	document.patch.operand_start = 3
	document.patch.operand_end = 7
	document.patch.source_raw_hex = "07000000"
	document.patch.output_raw_hex = "08000000"
	document.patch.source_instruction_raw_hex = source_hex
	document.patch.output_instruction_raw_hex = output_hex
	document.patch.output_instruction_raw_sha256 = _sha256_hex(output_hex)
	document.coverage.source_code_size = 9
	document.coverage.output_code_size = 9
	_rehash(document)
	return document


func _sha256_hex(value: String) -> String:
	return _sha256(value.hex_decode())


func _sha256(bytes: PackedByteArray) -> String:
	if bytes.is_empty():
		return PlanScript.EMPTY_SHA256
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()


func _rehash(document: Dictionary) -> void:
	document["payload_sha256"] = PlanScript.FingerprintScript.new().fingerprint(document)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
	else:
		_failures += 1
		push_error("FAIL: %s" % label)
