extends "res://tests/test_case.gd"

const ReopenScript := preload("res://content_core/mes_state_literal_compile_reopen.gd")


func _ready() -> void:
	var reopener := ReopenScript.new()
	var fixture := _fixture()
	var result := reopener.audit(fixture.output, fixture.audit)
	_check(
		result.ok
		and result.edited_write.storage == "global_u8"
		and result.edited_write.value == 2
		and result.edited_write.width == 8
		and result.coverage.node_count == 1,
		"same-width 8-bit state edit reopens through Phase 1-4"
	)
	var transported = JSON.parse_string(JSON.stringify(fixture.audit))
	var omitted_bootstrap: Dictionary = fixture.audit.duplicate(true)
	omitted_bootstrap.coverage.region_count = 1
	_rehash(omitted_bootstrap)
	_check(not reopener.audit(fixture.output, omitted_bootstrap).ok, "state compile coverage must retain the empty bootstrap region")
	_check(
		transported is Dictionary and reopener.audit(fixture.output, transported).ok,
		"state literal compile audit survives JSON number transport"
	)
	var fixture_u16 := _fixture_u16()
	var result_u16 := reopener.audit(fixture_u16.output, fixture_u16.audit)
	_check(
		result_u16.ok
		and result_u16.edited_write.storage == "state_u16"
		and result_u16.edited_write.value == 0x5678
		and result_u16.edited_write.width == 16,
		"same-width 16-bit state edit reopens through Phase 1-4"
	)
	var changed_payload: PackedByteArray = fixture.output.duplicate()
	changed_payload[11] = 3
	_check(
		not reopener.audit(changed_payload, fixture.audit).ok,
		"state literal reopen rejects output bytes that differ from the audit"
	)
	var changed_value: Dictionary = fixture.audit.duplicate(true)
	changed_value.operation.replacement_value = 3
	_rehash(changed_value)
	_check(
		not reopener.audit(fixture.output, changed_value).ok,
		"state literal reopen rejects a value that differs from decoded expression"
	)
	var fractional: Dictionary = fixture.audit.duplicate(true)
	fractional.target.expression_start = 3.5
	_rehash(fractional)
	_check(
		not reopener.audit(fixture.output, fractional).ok,
		"state literal compile audit rejects fractional JSON coordinates"
	)
	var unknown: Dictionary = fixture.audit.duplicate(true)
	unknown["ignored"] = true
	_rehash(unknown)
	_check(
		not reopener.audit(fixture.output, unknown).ok,
		"state literal compile audit rejects unknown fields"
	)
	var stale: Dictionary = fixture.audit.duplicate(true)
	stale.output.entry_sha256 = "0".repeat(64)
	_check(
		not reopener.audit(fixture.output, stale).ok,
		"state literal compile audit rejects a stale fingerprint"
	)
	await get_tree().process_frame
	get_tree().quit(1 if _failed else 0)


func _fixture() -> Dictionary:
	return _build_fixture(
		"031e0101ff00".hex_decode(),
		"031e0102ff00".hex_decode(),
		"global_u8",
		0,
		6,
		3,
		5,
		1,
		2,
		8
	)


func _fixture_u16() -> Dictionary:
	return _build_fixture(
		"0402f13412ff00".hex_decode(),
		"0402f17856ff00".hex_decode(),
		"state_u16",
		0,
		7,
		2,
		6,
		0x1234,
		0x5678,
		16
	)


func _build_fixture(
	source_code: PackedByteArray,
	output_code: PackedByteArray,
	storage: String,
	instruction_start: int,
	instruction_end: int,
	expression_start: int,
	expression_end: int,
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
	var source_expression := source_code.slice(expression_start, expression_end)
	var output_expression := output_code.slice(expression_start, expression_end)
	var source_summary := _summary(source, preamble.size())
	var output_summary := _summary(output, preamble.size())
	var audit := {
		"ok": true,
		"schema": "kakyu_mes_state_literal_compile_audit/v1",
		"producer": {
			"implementation": "python_phase6_state_literal_compiler",
			"contract": "kakyu_mes_state_literal_compile_audit/v1",
		},
		"compatibility": ReopenScript.COMPATIBILITY.duplicate(true),
		"source_identity": {
			"archive": "mes.arc",
			"entry": "STATE.MES",
			"archive_sha256": "a".repeat(64),
		},
		"inputs": {
			"editable_ir_sha256": "1".repeat(64),
			"decompiler_ir_sha256": "2".repeat(64),
			"state_literal_plan_sha256": "3".repeat(64),
		},
		"source": source_summary,
		"output": output_summary,
		"operation": {
			"kind": "replace_state_write_literal",
			"source_offset": instruction_start,
			"pair_index": 0,
			"storage": storage,
			"source_value": source_value,
			"replacement_value": replacement_value,
			"width": width,
		},
		"target": {
			"node_id": "linear_%08x" % instruction_start,
			"region_id": "entry_0000",
			"instruction_start": instruction_start,
			"instruction_end": instruction_end,
			"expression_start": expression_start,
			"expression_end": expression_end,
			"source_instruction_sha256": _sha256(source_code),
			"replacement_instruction_sha256": _sha256(output_code),
			"source_expression_sha256": _sha256(source_expression),
			"replacement_expression_sha256": _sha256(output_expression),
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
