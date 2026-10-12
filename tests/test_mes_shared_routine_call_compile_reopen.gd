extends "res://tests/test_case.gd"

const ReopenScript := preload("res://content_core/mes_shared_routine_call_compile_reopen.gd")
const PlanTestScript := preload("res://tests/test_mes_shared_routine_call_edit_plan.gd")


func _ready() -> void:
	var source_code := PackedByteArray([0x1D, 0x02, 3, 0xFF, 0, 0])
	var output_code := PackedByteArray([0x1D, 0x02, 4, 0xFF, 0, 0])
	var preamble := PackedByteArray([1, 0, 0, 0, 0, 0, 0, 0])
	var source := _join(preamble, source_code)
	var output := _join(preamble, output_code)
	var audit := _audit(source, output, source_code, output_code, preamble)
	var reopener := ReopenScript.new()
	var result := reopener.audit(output, audit)
	_check(
		result.ok
		and result.edited_call.instruction_start == 0
		and result.edited_call.instruction_end == 5
		and result.edited_call.literal_start == 2
		and result.edited_call.source_routine_id == 3
		and result.edited_call.replacement_routine_id == 4
		and result.edited_call.physical_resume_offset == 5
		and result.edited_call.physical_resume_end == 6
		and result.edited_call.physical_resume_kind == "statement"
		and result.coverage.node_count == 2,
		"shared-routine call edit reopens through Phase 1-4"
	)
	var transported = JSON.parse_string(JSON.stringify(audit))
	_check(reopener.audit(output, transported).ok, "shared-routine call audit survives JSON number transport")

	var changed_output := output.duplicate()
	changed_output[2] = 1
	_check(not reopener.audit(changed_output, audit).ok, "changed shared-call output is rejected")

	var changed_resume: Dictionary = audit.duplicate(true)
	changed_resume.target.resume_end = 5
	changed_resume.payload_sha256 = reopener.fingerprint(changed_resume)
	_check(not reopener.audit(output, changed_resume).ok, "changed resume boundary is rejected")

	var changed_callee: Dictionary = audit.duplicate(true)
	changed_callee.target.replacement_callee.routine_id = 5
	changed_callee.payload_sha256 = reopener.fingerprint(changed_callee)
	_check(not reopener.audit(output, changed_callee).ok, "changed replacement callee is rejected")

	var fractional: Dictionary = audit.duplicate(true)
	fractional.target.literal_start = 2.5
	fractional.payload_sha256 = reopener.fingerprint(fractional)
	_check(not reopener.audit(output, fractional).ok, "fractional shared-call coordinates are rejected")

	var unknown: Dictionary = audit.duplicate(true)
	unknown["ignored"] = true
	unknown.payload_sha256 = reopener.fingerprint(unknown)
	_check(not reopener.audit(output, unknown).ok, "unknown shared-call audit fields are rejected")

	var stale: Dictionary = audit.duplicate(true)
	stale.operation.replacement_routine_id = 5
	_check(not reopener.audit(output, stale).ok, "stale shared-call audit fingerprint is rejected")
	await get_tree().process_frame
	get_tree().quit(1 if _failed else 0)


func _audit(
	source: PackedByteArray,
	output: PackedByteArray,
	source_code: PackedByteArray,
	output_code: PackedByteArray,
	preamble: PackedByteArray
) -> Dictionary:
	var plan := PlanTestScript.new()._plan()
	var target: Dictionary = plan.target
	var replacement: Dictionary = plan.replacement
	var address_table := preamble.slice(4, 8)
	var document := {
		"ok": true,
		"schema": "kakyu_mes_shared_routine_call_compile_audit/v1",
		"producer": {
			"implementation": "python_phase6_shared_routine_call_compiler",
			"contract": "kakyu_mes_shared_routine_call_compile_audit/v1",
		},
		"compatibility": ReopenScript.COMPATIBILITY.duplicate(true),
		"source_identity": plan.source_identity.duplicate(true),
		"library_identity": plan.library_identity.duplicate(true),
		"inputs": {
			"editable_ir_sha256": "1".repeat(64),
			"decompiler_ir_sha256": "2".repeat(64),
			"shared_call_return_proof_sha256": "3".repeat(64),
			"library_audit_sha256": "4".repeat(64),
			"shared_routine_call_plan_sha256": str(plan.payload_sha256),
		},
		"source": _summary(source, source_code, preamble, address_table),
		"output": _summary(output, output_code, preamble, address_table),
		"operation": {
			"kind": "replace_shared_routine_literal",
			"source_offset": 0,
			"source_routine_id": 3,
			"replacement_routine_id": 4,
			"width": 8,
			"physical_resume_offset": 5,
		},
		"target": {
			"node_id": "linear_00000000",
			"region_id": "entry_0000",
			"instruction_start": 0,
			"instruction_end": 5,
			"literal_start": 2,
			"literal_end": 3,
			"resume_node_id": "linear_00000005",
			"resume_region_id": "entry_0000",
			"resume_start": 5,
			"resume_end": 6,
			"resume_raw_sha256": _sha256(PackedByteArray([0])),
			"source_instruction_sha256": str(target.instruction_raw_sha256),
			"replacement_instruction_sha256": str(replacement.instruction_raw_sha256),
			"source_expression_sha256": str(target.expression_raw_sha256),
			"replacement_expression_sha256": str(replacement.expression_raw_sha256),
			"source_literal_sha256": str(target.literal_raw_sha256),
			"replacement_literal_sha256": str(replacement.literal_raw_sha256),
			"source_callee": target.call_proof.duplicate(true),
			"replacement_callee": replacement.callee_proof.duplicate(true),
		},
		"coverage": {
			"region_count": 2, "node_count": 2, "typed_node_count": 2,
			"opaque_node_count": 0, "code_bytes": 6,
		},
		"invariants": {},
	}
	for key in ReopenScript.INVARIANT_KEYS:
		document.invariants[key] = true
	document["payload_sha256"] = ReopenScript.new().fingerprint(document)
	return document


func _summary(
	payload: PackedByteArray,
	code: PackedByteArray,
	preamble: PackedByteArray,
	address_table: PackedByteArray
) -> Dictionary:
	return {
		"size": payload.size(),
		"entry_count": 1,
		"code_offset": 8,
		"code_size": code.size(),
		"entry_sha256": _sha256(payload),
		"bytecode_sha256": _sha256(code),
		"preamble_sha256": _sha256(preamble),
		"address_table_sha256": _sha256(address_table),
	}


func _join(first: PackedByteArray, second: PackedByteArray) -> PackedByteArray:
	var result := PackedByteArray()
	result.append_array(first)
	result.append_array(second)
	return result


func _sha256(data: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(data)
	return context.finish().hex_encode()
