extends Node

const ReopenScript := preload("res://content_core/mes_control_target_edit_compile_reopen.gd")
const EMPTY_SHA256 := "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"

var _failures := 0


func _ready() -> void:
	var reopener := ReopenScript.new()
	var continuation := _fixture(false)
	var result := reopener.audit(continuation.output, continuation.audit)
	_check(
		result.ok
		and result.edited_edge.reference_kind == "continuation_target"
		and result.edited_edge.source_offset == 0
		and result.edited_edge.current_target_offset == 5
		and result.edited_edge.replacement_target_offset == 6
		and result.coverage.node_count == 3,
		"continuation target edit reopens through Phase 1-4"
	)
	var transported = JSON.parse_string(JSON.stringify(continuation.audit))
	var transport_result := reopener.audit(continuation.output, transported) if transported is Dictionary else {"ok": false, "error": "transport failed"}
	if not transport_result.ok:
		print("transport validation error: ", transport_result.get("error", "unknown"))
	_check(
		transported is Dictionary and transport_result.ok,
		"control-target compile audit survives JSON number transport"
	)
	var branch := _fixture(true)
	var branch_result := reopener.audit(branch.output, branch.audit)
	_check(
		branch_result.ok
		and branch_result.edited_edge.reference_kind == "condition_false_target"
		and branch_result.edited_edge.replacement_target_offset == 8,
		"conditional target edit reopens with its unchanged expression"
	)
	var changed_payload: PackedByteArray = continuation.output.duplicate()
	changed_payload[9] = 7
	_check(
		not reopener.audit(changed_payload, continuation.audit).ok,
		"control-target reopen rejects changed output bytes"
	)
	var changed_target: Dictionary = continuation.audit.duplicate(true)
	changed_target.operation.replacement_target_offset = 5
	_rehash(changed_target)
	_check(
		not reopener.audit(continuation.output, changed_target).ok,
		"control-target reopen rejects an audit target differing from decoded edge"
	)
	var changed_expression: Dictionary = branch.audit.duplicate(true)
	changed_expression.source_control.expression_sha256 = "0".repeat(64)
	_rehash(changed_expression)
	_check(
		not reopener.audit(branch.output, changed_expression).ok,
		"control-target reopen rejects changed conditional expression evidence"
	)
	var fractional: Dictionary = continuation.audit.duplicate(true)
	fractional.patch.operand_start = 1.5
	_rehash(fractional)
	_check(
		not reopener.audit(continuation.output, fractional).ok,
		"control-target compile audit rejects fractional coordinates"
	)
	var unknown: Dictionary = continuation.audit.duplicate(true)
	unknown["ignored"] = true
	_rehash(unknown)
	_check(
		not reopener.audit(continuation.output, unknown).ok,
		"control-target compile audit rejects unknown fields"
	)
	var stale: Dictionary = continuation.audit.duplicate(true)
	stale.output.entry_sha256 = "0".repeat(64)
	_check(
		not reopener.audit(continuation.output, stale).ok,
		"control-target compile audit rejects a stale fingerprint"
	)
	get_tree().quit(0 if _failures == 0 else 1)


func _fixture(branch: bool) -> Dictionary:
	var source_code := (
		"0b01ff070000000000".hex_decode()
		if branch else "0c050000000000".hex_decode()
	)
	var output_code := (
		"0b01ff080000000000".hex_decode()
		if branch else "0c060000000000".hex_decode()
	)
	var instruction_end := 7 if branch else 5
	var old_target := 7 if branch else 5
	var new_target := 8 if branch else 6
	var operand_start := 3 if branch else 1
	var reference_kind := "condition_false_target" if branch else "continuation_target"
	var op := "branch_if_not_true" if branch else "continuation_transfer"
	var command_id := 0x0B if branch else 0x0C
	var expression_start := 1
	var expression_end := 3 if branch else 1
	var expression_hash := _sha256(output_code.slice(expression_start, expression_end)) if branch else EMPTY_SHA256
	var preamble := PackedByteArray()
	preamble.resize(8)
	preamble.encode_u32(0, 1)
	preamble.encode_u32(4, 0)
	var source := preamble + source_code
	var output := preamble + output_code
	var source_summary := _summary(source, preamble.size())
	var output_summary := _summary(output, preamble.size())
	var audit := {
		"ok": true,
		"schema": "kakyu_mes_control_target_edit_compile_audit/v1",
		"producer": {
			"implementation": "python_phase6_control_target_edit_compiler",
			"contract": "kakyu_mes_control_target_edit_compile_audit/v1",
		},
		"compatibility": ReopenScript.COMPATIBILITY.duplicate(true),
		"source_identity": {
			"archive": "mes.arc", "entry": "CONTROL_EDIT.MES",
			"source_kind": "original_arc", "archive_sha256": "a".repeat(64),
		},
		"inputs": {
			"editable_ir_sha256": "1".repeat(64),
			"decompiler_ir_sha256": "2".repeat(64),
			"control_target_edit_plan_sha256": "3".repeat(64),
		},
		"source": source_summary,
		"output": output_summary,
		"operation": {
			"kind": "retarget_control_flow",
			"reference_kind": reference_kind,
			"source_offset": 0,
			"current_target_offset": old_target,
			"replacement_target_offset": new_target,
		},
		"source_control": {
			"node_id": "linear_00000000",
			"source_region_id": "entry_0000",
			"instruction_start": 0,
			"instruction_end": instruction_end,
			"source_instruction_sha256": _sha256(source_code.slice(0, instruction_end)),
			"replacement_instruction_sha256": _sha256(output_code.slice(0, instruction_end)),
			"op": op,
			"command_id": command_id,
			"reference_id": "code_00000000",
			"reference_kind": reference_kind,
			"operand_start": operand_start,
			"operand_end": instruction_end,
			"expression_kind": "condition" if branch else "none",
			"expression_start": expression_start,
			"expression_end": expression_end,
			"expression_sha256": expression_hash,
			"current_target_node_id": "linear_%08x" % old_target,
		},
		"replacement_target": {
			"node_id": "linear_%08x" % new_target,
			"source_region_id": "entry_0000",
			"instruction_start": new_target,
			"instruction_end": new_target + 1,
			"instruction_sha256": _sha256(PackedByteArray([0])),
			"op": "command_00",
			"command_id": 0,
		},
		"patch": {
			"operand_start": operand_start,
			"operand_end": instruction_end,
			"source_raw_hex": ("07000000" if branch else "05000000"),
			"output_raw_hex": ("08000000" if branch else "06000000"),
			"changed_code_offsets": [operand_start],
			"encoding": "u32_le_absolute_code_offset",
		},
		"coverage": {
			"region_count": 2,
			"node_count": 3,
			"typed_node_count": 3,
			"opaque_node_count": 0,
			"code_bytes": output_code.size(),
		},
		"invariants": {
			"plan_ready": true, "output_reopened": true,
			"container_size_preserved": true, "entry_count_preserved": true,
			"code_offset_preserved": true, "code_size_preserved": true,
			"address_table_preserved": true, "preamble_preserved": true,
			"code_prefix_preserved": true, "replacement_instruction_exact": true,
			"code_suffix_preserved": true, "changed_offsets_exact": true,
			"source_container_not_modified": true,
		},
	}
	_rehash(audit)
	return {"source": source, "output": output, "audit": audit}


func _summary(payload: PackedByteArray, code_offset: int) -> Dictionary:
	var preamble := payload.slice(0, code_offset)
	return {
		"size": payload.size(), "entry_count": 1,
		"code_offset": code_offset, "code_size": payload.size() - code_offset,
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


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
	else:
		_failures += 1
		push_error("FAIL: %s" % label)
