extends "res://tests/test_case.gd"

const ReopenScript := preload("res://content_core/mes_control_target_compile_reopen.gd")


func _ready() -> void:
	var source := _fixture()
	var payload: PackedByteArray = source.payload
	var audit: Dictionary = source.audit
	var reopened := ReopenScript.new().audit(payload, audit)
	_check(
		reopened.ok
		and reopened.edited_message.byte_length == 4
		and reopened.target_relocation.continuation_patch_count == 1,
		"GDScript reopens compiled message and shifted continuation target"
	)
	var branch := _fixture("branch")
	var branch_reopened := ReopenScript.new().audit(branch.payload, branch.audit)
	_check(
		branch_reopened.ok
		and branch_reopened.target_relocation.branch_patch_count == 1
		and branch_reopened.target_relocation.continuation_patch_count == 0,
		"GDScript reopens a variable-condition branch target"
	)
	var structural := _structural_fixture()
	var structural_reopened := ReopenScript.new().audit(structural.payload, structural.audit)
	_check(
		structural_reopened.ok
		and structural_reopened.phase1_4.analysis_mode == "structural_relocation"
		and structural_reopened.phase1_4.analysis_complete
		and structural_reopened.coverage.typed_node_count == 3
		and structural_reopened.coverage.opaque_node_count == 0,
		"GDScript reopens a structurally complete relocation without claiming invalid expression semantics"
	)
	var definition_verification := _definition_patch_verification()
	_check(
		definition_verification.ok
		and definition_verification.summary.definition_skip_patch_count == 1
		and definition_verification.summary.branch_patch_count == 0
		and definition_verification.summary.continuation_patch_count == 0,
		"GDScript independently reindexes a command-10 definition skip target"
	)
	var transported = JSON.parse_string(JSON.stringify(audit))
	_check(
		transported is Dictionary and ReopenScript.new().audit(payload, transported).ok,
		"control-target compile audit survives JSON number transport"
	)
	var changed_patch := audit.duplicate(true)
	changed_patch.target_patches[0].output_target_offset = 7
	changed_patch.target_patches[0].output_raw_hex = "07000000"
	_rehash(changed_patch)
	_check(
		not ReopenScript.new().audit(payload, changed_patch).ok,
		"control-target reopen rejects a relocated target inconsistent with the source mapping"
	)
	var changed_payload := payload.duplicate()
	changed_payload[19] = 7
	_check(
		not ReopenScript.new().audit(changed_payload, audit).ok,
		"control-target reopen rejects bytes outside the compile audit"
	)
	var unknown := audit.duplicate(true)
	unknown["ignored"] = true
	_rehash(unknown)
	_check(
		not ReopenScript.new().validate_compile_audit(unknown).ok,
		"control-target compile audit rejects unknown fields"
	)
	var fractional := audit.duplicate(true)
	fractional.relocation.target_patch_count = 1.5
	_rehash(fractional)
	_check(
		not ReopenScript.new().validate_compile_audit(fractional).ok,
		"control-target compile audit rejects fractional JSON counts"
	)
	var stale := audit.duplicate(true)
	stale.output.entry_sha256 = "0".repeat(64)
	_check(
		not ReopenScript.new().validate_compile_audit(stale).ok,
		"control-target compile audit rejects a stale fingerprint"
	)
	await get_tree().process_frame
	get_tree().quit(1 if _failed else 0)


func _fixture(control_kind := "continuation") -> Dictionary:
	var source_preamble := PackedByteArray([
		2, 0, 0, 0,
		0, 0, 0, 0,
		4, 0, 0, 0,
	])
	var output_preamble := PackedByteArray([
		2, 0, 0, 0,
		0, 0, 0, 0,
		6, 0, 0, 0,
	])
	var is_branch := control_kind == "branch"
	var source_code := (
		"0182a0000b01ff04000000" if is_branch else "0182a0000c04000000"
	).hex_decode()
	var output_code := (
		"0182a282a4000b01ff06000000" if is_branch else "0182a282a4000c06000000"
	).hex_decode()
	var source_payload := source_preamble + source_code
	var output_payload := output_preamble + output_code
	var source_message := "82a0".hex_decode()
	var replacement_message := "82a282a4".hex_decode()
	var audit := {
		"ok": true,
		"schema": "kakyu_mes_control_target_compile_audit/v1",
		"producer": {
			"implementation": "python_phase6_control_target_compiler",
			"contract": "kakyu_mes_control_target_compile_audit/v1",
		},
		"compatibility": ReopenScript.COMPATIBILITY.duplicate(true),
		"source_identity": {
			"archive": "mes.arc",
			"entry": "TEST.MES",
			"source_kind": "original_arc",
			"archive_sha256": "a".repeat(64),
		},
		"inputs": {
			"editable_ir_sha256": "1".repeat(64),
			"decompiler_ir_sha256": "2".repeat(64),
			"message_relocation_plan_sha256": "3".repeat(64),
			"control_target_plan_sha256": "4".repeat(64),
		},
		"source": _container_summary(source_payload, source_preamble.size()),
		"output": _container_summary(output_payload, output_preamble.size()),
		"operation": {
			"kind": "replace_message",
			"source_offset": 0,
			"source_raw_sha256": _sha256(source_message),
			"replacement_raw_sha256": _sha256(replacement_message),
			"source_byte_length": 2,
			"replacement_byte_length": 4,
			"encoding": "cp932",
		},
		"relocation": {
			"delta": 2,
			"pivot_source_end": 4,
			"source_code_size": source_code.size(),
			"output_code_size": output_code.size(),
			"source_instruction_start": 0,
			"source_instruction_end": 4,
			"output_instruction_end": 6,
			"address_table_update_count": 1,
			"affected_reference_count": 2,
			"target_patch_count": 1,
		},
		"target_patches": [{
			"reference_id": "code_00000000",
			"reference_kind": "condition_false_target" if is_branch else "continuation_target",
			"owner_node_id": "linear_00000004",
			"owner_op": "branch_if_not_true" if is_branch else "continuation_transfer",
			"command_id": 0x0B if is_branch else 0x0C,
			"source_instruction_start": 4,
			"source_instruction_end": 11 if is_branch else 9,
			"output_instruction_start": 6,
			"output_instruction_end": 13 if is_branch else 11,
			"source_operand_start": 7 if is_branch else 5,
			"source_operand_end": 11 if is_branch else 9,
			"output_operand_start": 9 if is_branch else 7,
			"output_operand_end": 13 if is_branch else 11,
			"source_target_offset": 4,
			"output_target_offset": 6,
			"source_target_node_id": "linear_00000004",
			"source_raw_hex": "04000000",
			"output_raw_hex": "06000000",
			"encoding": "u32_le_absolute_code_offset",
		}],
		"coverage": {
			"output_region_count": 2,
			"source_node_count": 2,
			"source_typed_node_count": 2,
			"source_opaque_node_count": 0,
			"source_code_bytes": 11 if is_branch else 9,
			"output_code_bytes": 13 if is_branch else 11,
		},
		"invariants": ReopenScript.INVARIANTS.duplicate(true),
	}
	_rehash(audit)
	return {"payload": output_payload, "audit": audit}


func _container_summary(payload: PackedByteArray, code_offset: int) -> Dictionary:
	return {
		"size": payload.size(),
		"entry_count": 2,
		"code_offset": code_offset,
		"code_size": payload.size() - code_offset,
		"entry_sha256": _sha256(payload),
		"bytecode_sha256": _sha256(payload.slice(code_offset)),
		"preamble_sha256": _sha256(payload.slice(0, code_offset)),
	}


func _structural_fixture() -> Dictionary:
	var source_preamble := PackedByteArray([
		2, 0, 0, 0,
		0, 0, 0, 0,
		4, 0, 0, 0,
	])
	var output_preamble := PackedByteArray([
		2, 0, 0, 0,
		0, 0, 0, 0,
		6, 0, 0, 0,
	])
	var source_code := "0182a00004ff0203ff000c0a000000".hex_decode()
	var output_code := "0182a282a40004ff0203ff000c0c000000".hex_decode()
	var source_payload := source_preamble + source_code
	var output_payload := output_preamble + output_code
	var source_message := "82a0".hex_decode()
	var replacement_message := "82a282a4".hex_decode()
	var audit := {
		"ok": true,
		"schema": "kakyu_mes_control_target_compile_audit/v1",
		"producer": {
			"implementation": "python_phase6_control_target_compiler",
			"contract": "kakyu_mes_control_target_compile_audit/v1",
		},
		"compatibility": ReopenScript.COMPATIBILITY.duplicate(true),
		"source_identity": {
			"archive": "mes.arc",
			"entry": "STRUCTURAL.MES",
			"source_kind": "original_arc",
			"archive_sha256": "b".repeat(64),
		},
		"inputs": {
			"editable_ir_sha256": "1".repeat(64),
			"decompiler_ir_sha256": "2".repeat(64),
			"message_relocation_plan_sha256": "3".repeat(64),
			"control_target_plan_sha256": "4".repeat(64),
		},
		"source": _container_summary(source_payload, source_preamble.size()),
		"output": _container_summary(output_payload, output_preamble.size()),
		"operation": {
			"kind": "replace_message",
			"source_offset": 0,
			"source_raw_sha256": _sha256(source_message),
			"replacement_raw_sha256": _sha256(replacement_message),
			"source_byte_length": 2,
			"replacement_byte_length": 4,
			"encoding": "cp932",
		},
		"relocation": {
			"delta": 2,
			"pivot_source_end": 4,
			"source_code_size": source_code.size(),
			"output_code_size": output_code.size(),
			"source_instruction_start": 0,
			"source_instruction_end": 4,
			"output_instruction_end": 6,
			"address_table_update_count": 1,
			"affected_reference_count": 2,
			"target_patch_count": 1,
		},
		"target_patches": [{
			"reference_id": "code_00000000",
			"reference_kind": "continuation_target",
			"owner_node_id": "linear_0000000a",
			"owner_op": "continuation_transfer",
			"command_id": 0x0C,
			"source_instruction_start": 10,
			"source_instruction_end": 15,
			"output_instruction_start": 12,
			"output_instruction_end": 17,
			"source_operand_start": 11,
			"source_operand_end": 15,
			"output_operand_start": 13,
			"output_operand_end": 17,
			"source_target_offset": 10,
			"output_target_offset": 12,
			"source_target_node_id": "linear_0000000a",
			"source_raw_hex": "0a000000",
			"output_raw_hex": "0c000000",
			"encoding": "u32_le_absolute_code_offset",
		}],
		"coverage": {
			"output_region_count": 2,
			"source_node_count": 3,
			"source_typed_node_count": 3,
			"source_opaque_node_count": 0,
			"source_code_bytes": source_code.size(),
			"output_code_bytes": output_code.size(),
		},
		"invariants": ReopenScript.INVARIANTS.duplicate(true),
	}
	_rehash(audit)
	return {"payload": output_payload, "audit": audit}


func _definition_patch_verification() -> Dictionary:
	var code := "100200ff000900000000".hex_decode()
	var analysis := {
		"instructions": [
			{
				"source_offset": 0,
				"end_offset": 9,
				"command_id": 0x10,
				"op": "command_10",
				"operands": [
					{"type": "record_list", "records": []},
					{"type": "u8_array", "value": [9, 0, 0, 0]},
				],
			},
			{
				"source_offset": 9,
				"end_offset": 10,
				"command_id": 0,
				"op": "command_00",
				"operands": [],
			},
		],
		"code_references": [],
	}
	var patches := [{
		"reference_kind": "definition_skip_target",
		"command_id": 0x10,
		"owner_op": "command_10",
		"output_instruction_start": 0,
		"output_instruction_end": 9,
		"output_operand_start": 5,
		"output_operand_end": 9,
		"output_target_offset": 9,
		"output_raw_hex": "09000000",
	}]
	return ReopenScript.new().call("_verify_target_patches", code, analysis, patches)


func _rehash(document: Dictionary) -> void:
	document["payload_sha256"] = ReopenScript.new().fingerprint(document)


func _sha256(payload: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(payload)
	return context.finish().hex_encode()
