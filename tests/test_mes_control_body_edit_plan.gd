extends Node

const PlanScript := preload("res://content_core/mes_control_body_edit_plan.gd")
const FingerprintScript := preload("res://content_core/mes_payload_fingerprint.gd")

var _failures := 0


func _ready() -> void:
	var validator := PlanScript.new()
	var insertion := _fixture()
	var inserted := validator.validate(insertion)
	_check(
		inserted.ok
		and inserted.operation_kind == "insert_typed_body_copy"
		and inserted.delta == 5
		and inserted.target_patch_count == 1
		and inserted.blocker_count == 0
		and inserted.assembly_ready
		and not inserted.mes_bytes,
		"control-body plan validates one exact typed copy insertion"
	)
	var removal := _removal_fixture()
	var removed := validator.validate(removal)
	_check(
		removed.ok
		and removed.operation_kind == "remove_typed_body"
		and removed.delta == -5
		and removed.assembly_ready,
		"control-body plan validates one exact typed removal"
	)
	var blocked := insertion.duplicate(true)
	blocked.blockers = [{
		"code": "incoming_target_at_insert_anchor",
		"source_id": "code_0000000b",
		"source_offset": 11,
		"target_offset": 6,
		"detail": "",
	}]
	blocked.assembly_ready = false
	_rehash(blocked)
	var blocked_result := validator.validate(blocked)
	_check(
		blocked_result.ok and not blocked_result.assembly_ready and blocked_result.blocker_count == 1,
		"control-body plan retains a valid fail-closed blocker report"
	)
	var wrong_ready := blocked.duplicate(true)
	wrong_ready.assembly_ready = true
	_rehash(wrong_ready)
	_check(not validator.validate(wrong_ready).ok, "control-body plan rejects stale readiness")
	var bad_patch := insertion.duplicate(true)
	bad_patch.target_patches[0].output_raw_hex = "19000000"
	_rehash(bad_patch)
	_check(not validator.validate(bad_patch).ok, "control-body plan rejects a changed target patch")
	var fractional := insertion.duplicate(true)
	fractional.operation.anchor_offset = 6.5
	_rehash(fractional)
	_check(not validator.validate(fractional).ok, "control-body plan rejects fractional coordinates")
	var unknown := insertion.duplicate(true)
	unknown["ignored"] = true
	_rehash(unknown)
	_check(not validator.validate(unknown).ok, "control-body plan rejects unknown fields")
	var stale := insertion.duplicate(true)
	stale.payload_sha256 = "0".repeat(64)
	_check(not validator.validate(stale).ok, "control-body plan rejects a stale fingerprint")
	get_tree().quit(0 if _failures == 0 else 1)


func _fixture() -> Dictionary:
	var body_hex := "1f01000000"
	var body_hash := _sha256(body_hex.hex_decode())
	var empty_hash := _sha256(PackedByteArray())
	var array_hash := _sha256("[]".to_utf8_buffer())
	var document := {
		"ok": true,
		"schema": "kakyu_mes_control_body_edit_plan/v1",
		"producer": {
			"implementation": "python_phase6_control_body_edit_planner",
			"contract": "kakyu_mes_control_body_edit_plan/v1",
		},
		"compatibility": PlanScript.COMPATIBILITY.duplicate(true),
		"source_identity": {
			"archive": "mes.arc", "entry": "CONTROL_BODY.MES",
			"source_kind": "original_arc", "archive_sha256": "a".repeat(64),
		},
		"inputs": {
			"editable_ir_sha256": "b".repeat(64),
			"decompiler_ir_sha256": "c".repeat(64),
		},
		"operation": {
			"kind": "insert_typed_body_copy",
			"anchor_offset": 6,
			"anchor_instruction_raw_sha256": "d".repeat(64),
			"donor_start": 1,
			"donor_end": 6,
			"donor_span_raw_sha256": body_hash,
		},
		"body": {
			"policy": "copied_before_anchor",
			"source_region_id": "entry_0000",
			"source_start": 1,
			"source_end": 6,
			"byte_length": 5,
			"source_raw_hex": body_hex,
			"source_raw_sha256": body_hash,
			"source_node_ids": ["linear_00000001"],
			"source_node_hashes": [body_hash],
			"output_start": 6,
			"output_end": 11,
			"output_raw_sha256": body_hash,
			"inserted_node_map": [{
				"source_node_id": "linear_00000001",
				"source_start": 1,
				"source_end": 6,
				"output_node_id": "linear_00000006",
				"output_start": 6,
				"output_end": 11,
				"raw_sha256": body_hash,
			}],
		},
		"relocation": {
			"delta": 5, "pivot": 6, "source_code_size": 22, "output_code_size": 27,
			"entry_count": 2, "affected_address_count": 1,
			"affected_region_count": 1, "affected_node_count": 1,
			"affected_reference_count": 1, "target_patch_count": 1,
			"cfg_node_count": 0, "cfg_edge_count": 0,
		},
		"address_table_updates": [{"index": 1, "source_offset": 21, "output_offset": 26}],
		"region_updates": [{
			"region_id": "entry_0000", "kind": "entry", "index": 0,
			"source_start": 0, "source_end": 21, "output_start": 0, "output_end": 26,
			"source_raw_sha256": "e".repeat(64), "output_raw_sha256": "f".repeat(64),
		}],
		"node_map": [{
			"source_node_id": "linear_00000006", "source_region_id": "entry_0000",
			"source_start": 6, "source_end": 11, "status": "retained",
			"output_node_id": "linear_0000000b", "output_start": 11, "output_end": 16,
			"raw_sha256": "d".repeat(64),
		}],
		"reference_map": [{
			"reference_id": "code_0000000b", "kind": "code", "status": "retained",
			"source_offset": 11, "output_source_offset": 16,
			"source_target_offset": 21, "output_target_offset": 26,
		}],
		"target_patches": [{
			"reference_id": "code_0000000b", "reference_kind": "continuation_target",
			"owner_node_id": "linear_0000000b", "owner_op": "continuation_transfer",
			"command_id": 12,
			"source_instruction_start": 11, "source_instruction_end": 16,
			"output_instruction_start": 16, "output_instruction_end": 21,
			"source_operand_start": 12, "source_operand_end": 16,
			"output_operand_start": 17, "output_operand_end": 21,
			"source_target_offset": 21, "output_target_offset": 26,
			"source_target_node_id": "linear_00000015",
			"source_raw_hex": "15000000", "output_raw_hex": "1a000000",
			"encoding": "u32_le_absolute_code_offset",
		}],
		"cfg_relocation": {
			"source_control_flow_sha256": array_hash, "graph_count": 0,
			"source_node_count": 0, "source_edge_count": 0,
			"node_rows": [], "edge_rows": [],
		},
		"evidence_inventory": {
			"source_reference_count": 1, "source_cfg_graph_count": 0,
			"source_cfg_node_count": 0, "source_cfg_edge_count": 0,
			"source_call_count": 0, "source_trace_count": 0,
			"source_opaque_node_count": 0, "moved_opaque_node_count": 0,
			"calls_sha256": array_hash, "traces_sha256": array_hash,
			"control_flow_sha256": array_hash,
		},
		"blockers": [],
		"assembly_ready": true,
		"invariants": PlanScript.INVARIANTS.duplicate(true),
	}
	_rehash(document)
	return document


func _removal_fixture() -> Dictionary:
	var document := _fixture()
	document.operation = {
		"kind": "remove_typed_body", "body_start": 1, "body_end": 6,
		"body_span_raw_sha256": document.body.source_raw_sha256,
	}
	document.body.policy = "removed_from_source"
	document.body.output_start = 1
	document.body.output_end = 1
	document.body.output_raw_sha256 = _sha256(PackedByteArray())
	document.body.inserted_node_map = []
	document.relocation.delta = -5
	document.relocation.output_code_size = 17
	document.address_table_updates[0].output_offset = 16
	document.node_map[0] = {
		"source_node_id": "linear_00000001", "source_region_id": "entry_0000",
		"source_start": 1, "source_end": 6, "status": "removed",
		"output_node_id": "", "output_start": -1, "output_end": -1,
		"raw_sha256": document.body.source_raw_sha256,
	}
	document.reference_map[0].output_source_offset = 6
	document.reference_map[0].output_target_offset = 16
	document.target_patches[0].output_instruction_start = 6
	document.target_patches[0].output_instruction_end = 11
	document.target_patches[0].output_operand_start = 7
	document.target_patches[0].output_operand_end = 11
	document.target_patches[0].output_target_offset = 16
	document.target_patches[0].output_raw_hex = "10000000"
	document.region_updates[0].output_end = 16
	_rehash(document)
	return document


func _sha256(bytes: PackedByteArray) -> String:
	if bytes.is_empty():
		return PlanScript.EMPTY_SHA256
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()


func _rehash(document: Dictionary) -> void:
	document["payload_sha256"] = FingerprintScript.new().fingerprint(document)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
	else:
		_failures += 1
		push_error("FAIL: %s" % label)
