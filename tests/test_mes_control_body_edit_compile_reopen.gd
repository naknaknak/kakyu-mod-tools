extends Node

const ReopenScript := preload("res://content_core/mes_control_body_edit_compile_reopen.gd")

var _failures := 0


func _ready() -> void:
	var payload := "02000000000000001a000000001f010000001f010000001f020000000c1a0000001f0300000000".hex_decode()
	var audit := _audit(payload)
	var reopen := ReopenScript.new()
	var result := reopen.audit(payload, audit)
	_check(
		result.ok
		and result.operation.kind == "insert_typed_body_copy"
		and result.coverage.node_count == 7
		and result.coverage.typed_node_count == 7
		and result.coverage.opaque_node_count == 0
		and result.body_boundary.node_count == 1
		and result.target_patch_verification.patch_count == 1
		and result.target_patch_verification.code_reference_count == 1,
		"control-body compile output reopens through the current Phase 1-4 contracts"
	)
	var changed_payload := payload.duplicate()
	changed_payload[17 + 12] ^= 1
	_check(
		not reopen.audit(changed_payload, audit).ok,
		"control-body reopen rejects changed output bytes"
	)
	var changed_patch := audit.duplicate(true)
	changed_patch.target_patches[0].output_raw_hex = "19000000"
	changed_patch.relocation.target_patch_stream_sha256 = reopen.call("_json_sha256", changed_patch.target_patches)
	_rehash(changed_patch)
	_check(
		not reopen.validate_compile_audit(changed_patch).ok,
		"control-body compile audit rejects a rehashed changed target patch"
	)
	var changed_coverage := audit.duplicate(true)
	changed_coverage.coverage.expected_output_node_count = 8
	_rehash(changed_coverage)
	_check(
		not reopen.validate_compile_audit(changed_coverage).ok,
		"control-body compile audit rejects changed output coverage"
	)
	var unknown := audit.duplicate(true)
	unknown["ignored"] = true
	_rehash(unknown)
	_check(not reopen.validate_compile_audit(unknown).ok, "control-body compile audit rejects unknown fields")
	var stale := audit.duplicate(true)
	stale.payload_sha256 = "0".repeat(64)
	_check(not reopen.validate_compile_audit(stale).ok, "control-body compile audit rejects a stale fingerprint")
	get_tree().quit(0 if _failures == 0 else 1)


func _audit(payload: PackedByteArray) -> Dictionary:
	var reopen := ReopenScript.new()
	var patches := [{
		"reference_id": "code_00000000",
		"reference_kind": "continuation_target",
		"owner_node_id": "linear_0000000b",
		"owner_op": "continuation_transfer",
		"command_id": 12,
		"source_instruction_start": 11,
		"source_instruction_end": 16,
		"output_instruction_start": 16,
		"output_instruction_end": 21,
		"source_operand_start": 12,
		"source_operand_end": 16,
		"output_operand_start": 17,
		"output_operand_end": 21,
		"source_target_offset": 21,
		"output_target_offset": 26,
		"source_target_node_id": "linear_00000015",
		"source_raw_hex": "15000000",
		"output_raw_hex": "1a000000",
		"encoding": "u32_le_absolute_code_offset",
	}]
	var document := {
		"ok": true,
		"schema": "kakyu_mes_control_body_edit_compile_audit/v1",
		"producer": {
			"implementation": "python_phase6_control_body_edit_compiler",
			"contract": "kakyu_mes_control_body_edit_compile_audit/v1",
		},
		"compatibility": ReopenScript.COMPATIBILITY.duplicate(true),
		"source_identity": {
			"archive": "mes.arc", "entry": "CONTROL_BODY.MES",
			"source_kind": "original_arc", "archive_sha256": "a".repeat(64),
		},
		"inputs": {
			"editable_ir_sha256": "b".repeat(64),
			"decompiler_ir_sha256": "c".repeat(64),
			"control_body_edit_plan_sha256": "d".repeat(64),
		},
		"operation": {
			"kind": "insert_typed_body_copy", "source_start": 1, "source_end": 6,
			"output_start": 6, "output_end": 11,
		},
		"body": {
			"byte_length": 5,
			"source_raw_sha256": _sha256("1f01000000".hex_decode()),
			"source_node_count": 1,
			"inserted_node_count": 1,
		},
		"relocation": {
			"delta": 5, "pivot": 6, "address_update_count": 1,
			"region_update_count": 2, "node_map_count": 4,
			"reference_map_count": 1, "cfg_node_count": 0, "cfg_edge_count": 0,
			"target_patch_count": 1,
			"target_patch_stream_sha256": reopen.call("_json_sha256", patches),
		},
		"target_patches": patches,
		"changed_output_code_offsets": [17],
		"source": {
			"size": 34, "entry_count": 2, "code_offset": 12, "code_size": 22,
			"entry_sha256": "e".repeat(64), "bytecode_sha256": "e".repeat(64),
			"preamble_sha256": "e".repeat(64), "address_table_sha256": "e".repeat(64),
		},
		"output": {
			"size": payload.size(), "entry_count": 2, "code_offset": 12,
			"code_size": payload.size() - 12,
			"entry_sha256": _sha256(payload),
			"bytecode_sha256": _sha256(payload.slice(12)),
			"preamble_sha256": _sha256(payload.slice(0, 12)),
			"address_table_sha256": _sha256(payload.slice(4, 12)),
		},
		"coverage": {
			"expected_output_region_count": 2, "source_node_count": 6,
			"source_typed_node_count": 6, "source_opaque_node_count": 0,
			"expected_output_node_count": 7, "expected_output_typed_node_count": 7,
			"expected_output_opaque_node_count": 0, "source_code_bytes": 22,
			"output_code_bytes": 27,
		},
		"invariants": {
			"plan_ready": true, "output_reopened": true,
			"entry_count_preserved": true, "code_size_delta_exact": true,
			"address_table_relocated_exactly": true,
			"nonaddress_preamble_bytes_preserved": true, "body_edit_exact": true,
			"target_patches_exact": true, "changed_offsets_exhaustive": true,
			"source_container_not_modified": true, "source_documents_not_modified": true,
		},
	}
	_rehash(document)
	return document


func _rehash(document: Dictionary) -> void:
	document["payload_sha256"] = ReopenScript.new().fingerprint(document)


func _sha256(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
	else:
		_failures += 1
		push_error("FAIL: %s" % label)
