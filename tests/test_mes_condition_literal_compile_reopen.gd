extends "res://tests/test_case.gd"

const ReopenScript := preload("res://content_core/mes_condition_literal_compile_reopen.gd")


func _ready() -> void:
	var reopener := ReopenScript.new()
	var fixture := _fixture()
	var result := reopener.audit(fixture.output, fixture.audit)
	_check(
		result.ok
		and result.edited_branch.op == "branch_if_not_true"
		and result.edited_branch.value == 2
		and result.edited_branch.width == 8
		and result.edited_branch.false_target == 0
		and result.coverage.node_count == 1,
		"same-width 8-bit condition edit reopens through Phase 1-4"
	)
	var transported = JSON.parse_string(JSON.stringify(fixture.audit))
	_check(
		transported is Dictionary and reopener.audit(fixture.output, transported).ok,
		"condition literal compile audit survives JSON number transport"
	)
	var fixture_u16 := _fixture_u16()
	var result_u16 := reopener.audit(fixture_u16.output, fixture_u16.audit)
	_check(
		result_u16.ok
		and result_u16.edited_branch.value == 0x5678
		and result_u16.edited_branch.width == 16
		and result_u16.edited_branch.false_target == 0,
		"same-width 16-bit condition edit reopens through Phase 1-4"
	)
	var changed_payload: PackedByteArray = fixture.output.duplicate()
	changed_payload[12] = 3
	_check(
		not reopener.audit(changed_payload, fixture.audit).ok,
		"condition literal reopen rejects output bytes that differ from the audit"
	)
	var changed_value: Dictionary = fixture.audit.duplicate(true)
	changed_value.operation.replacement_value = 3
	_rehash(changed_value)
	_check(
		not reopener.audit(fixture.output, changed_value).ok,
		"condition literal reopen rejects a value that differs from decoded AST"
	)
	var changed_target: Dictionary = fixture.audit.duplicate(true)
	changed_target.operation.false_target = 1
	_rehash(changed_target)
	_check(
		not reopener.audit(fixture.output, changed_target).ok,
		"condition literal reopen rejects a target that differs from decoded branch"
	)
	var fractional: Dictionary = fixture.audit.duplicate(true)
	fractional.target.literal_start = 4.5
	_rehash(fractional)
	_check(
		not reopener.audit(fixture.output, fractional).ok,
		"condition literal compile audit rejects fractional JSON coordinates"
	)
	var unknown: Dictionary = fixture.audit.duplicate(true)
	unknown["ignored"] = true
	_rehash(unknown)
	_check(
		not reopener.audit(fixture.output, unknown).ok,
		"condition literal compile audit rejects unknown fields"
	)
	var stale: Dictionary = fixture.audit.duplicate(true)
	stale.output.entry_sha256 = "0".repeat(64)
	_check(
		not reopener.audit(fixture.output, stale).ok,
		"condition literal compile audit rejects a stale fingerprint"
	)
	await get_tree().process_frame
	get_tree().quit(1 if _failed else 0)


func _fixture() -> Dictionary:
	return _build_fixture(
		"0bf3010001efff00000000".hex_decode(),
		"0bf3010002efff00000000".hex_decode(),
		0,
		11,
		1,
		7,
		4,
		5,
		1,
		2,
		8
	)


func _fixture_u16() -> Dictionary:
	return _build_fixture(
		"0bf30100f13412efff00000000".hex_decode(),
		"0bf30100f17856efff00000000".hex_decode(),
		0,
		13,
		1,
		9,
		4,
		7,
		0x1234,
		0x5678,
		16
	)


func _build_fixture(
	source_code: PackedByteArray,
	output_code: PackedByteArray,
	instruction_start: int,
	instruction_end: int,
	condition_start: int,
	condition_end: int,
	literal_start: int,
	literal_end: int,
	source_value: int,
	replacement_value: int,
	width: int
) -> Dictionary:
	var preamble := PackedByteArray()
	preamble.resize(8)
	preamble.encode_u32(0, 1)
	preamble.encode_u32(4, 0)
	var source := preamble + source_code
	var output := preamble + output_code
	var source_condition := source_code.slice(condition_start, condition_end)
	var output_condition := output_code.slice(condition_start, condition_end)
	var source_literal := source_code.slice(literal_start, literal_end)
	var output_literal := output_code.slice(literal_start, literal_end)
	var false_target_start := condition_end
	var false_target_end := instruction_end
	var false_target_bytes := source_code.slice(false_target_start, false_target_end)
	var source_summary := _summary(source, preamble.size())
	var output_summary := _summary(output, preamble.size())
	var audit := {
		"ok": true,
		"schema": "kakyu_mes_condition_literal_compile_audit/v1",
		"producer": {
			"implementation": "python_phase6_condition_literal_compiler",
			"contract": "kakyu_mes_condition_literal_compile_audit/v1",
		},
		"compatibility": ReopenScript.COMPATIBILITY.duplicate(true),
		"source_identity": {
			"archive": "mes.arc",
			"entry": "CONDITION.MES",
			"archive_sha256": "a".repeat(64),
		},
		"inputs": {
			"editable_ir_sha256": "1".repeat(64),
			"decompiler_ir_sha256": "2".repeat(64),
			"condition_literal_plan_sha256": "3".repeat(64),
		},
		"source": source_summary,
		"output": output_summary,
		"operation": {
			"kind": "replace_condition_literal",
			"source_offset": instruction_start,
			"literal_offset": literal_start,
			"source_value": source_value,
			"replacement_value": replacement_value,
			"width": width,
			"false_target": 0,
		},
		"target": {
			"node_id": "linear_%08x" % instruction_start,
			"region_id": "entry_0000",
			"instruction_start": instruction_start,
			"instruction_end": instruction_end,
			"condition_start": condition_start,
			"condition_end": condition_end,
			"literal_start": literal_start,
			"literal_end": literal_end,
			"source_instruction_sha256": _sha256(source_code),
			"replacement_instruction_sha256": _sha256(output_code),
			"source_condition_sha256": _sha256(source_condition),
			"replacement_condition_sha256": _sha256(output_condition),
			"source_literal_sha256": _sha256(source_literal),
			"replacement_literal_sha256": _sha256(output_literal),
			"false_target_reference_id": "code_00000000",
			"false_target_operand_start": false_target_start,
			"false_target_operand_end": false_target_end,
			"false_target_operand_sha256": _sha256(false_target_bytes),
		},
		"coverage": {
			"region_count": 2,
			"node_count": 1,
			"typed_node_count": 1,
			"opaque_node_count": 0,
			"code_bytes": output_code.size(),
		},
		"invariants": {
			"plan_ready": true,
			"output_reopened": true,
			"container_size_preserved": true,
			"entry_count_preserved": true,
			"code_offset_preserved": true,
			"code_size_preserved": true,
			"address_table_preserved": true,
			"preamble_preserved": true,
			"code_prefix_preserved": true,
			"replacement_instruction_exact": true,
			"code_suffix_preserved": true,
			"condition_terminator_preserved": true,
			"false_target_operand_preserved": true,
			"source_container_not_modified": true,
		},
	}
	_rehash(audit)
	return {"source": source, "output": output, "audit": audit}


func _summary(payload: PackedByteArray, code_offset: int) -> Dictionary:
	var preamble := payload.slice(0, code_offset)
	return {
		"size": payload.size(),
		"entry_count": 1,
		"code_offset": code_offset,
		"code_size": payload.size() - code_offset,
		"entry_sha256": _sha256(payload),
		"bytecode_sha256": _sha256(payload.slice(code_offset)),
		"preamble_sha256": _sha256(preamble),
		"address_table_sha256": _sha256(preamble),
	}


func _rehash(document: Dictionary) -> void:
	document["payload_sha256"] = ReopenScript.new().fingerprint(document)


func _sha256(data: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(data)
	return context.finish().hex_encode()
