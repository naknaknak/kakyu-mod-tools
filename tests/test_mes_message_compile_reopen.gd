extends "res://tests/test_case.gd"

const ReopenScript := preload("res://content_core/mes_message_compile_reopen.gd")
const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")
const SyntheticArc := preload("res://tests/synthetic_arc.gd")


func _ready() -> void:
	var source := _source_mes()
	var output := _compiled_mes()
	var validator := ReopenScript.new()
	var compile_audit := _compile_audit(source, output, validator)
	var report: Dictionary = validator.audit(output, compile_audit)
	_check(
		report.get("ok", false)
		and report.schema == ContentCoreVersionScript.MES_MESSAGE_REOPEN_AUDIT_SCHEMA
		and report.output.entry_count == 2
		and report.output.code_size == 9
		and report.edited_message.source_offset == 0
		and report.edited_message.end_offset == 6
		and report.edited_message.byte_length == 4
		and report.coverage.region_count == 2
		and report.coverage.node_count == 2
		and report.coverage.opaque_node_count == 0
		and _all_true(report.invariants)
		and report.payload_sha256 == validator.fingerprint(report),
		"GDScript reopens a variable-length Python-contract MES message compile"
	)
	var transported = JSON.parse_string(JSON.stringify(compile_audit))
	_check(
		validator.audit(output, transported).get("ok", false),
		"GDScript message reopen canonicalizes integral JSON numbers"
	)
	var changed_payload := output.duplicate()
	changed_payload[changed_payload.size() - 1] ^= 0x01
	_check(
		not validator.audit(changed_payload, compile_audit).get("ok", false),
		"GDScript message reopen rejects bytes outside the compile audit"
	)
	var changed_coverage: Dictionary = compile_audit.duplicate(true)
	changed_coverage.coverage.source_node_count = 3
	changed_coverage.coverage.source_typed_node_count = 3
	changed_coverage.payload_sha256 = validator.fingerprint(changed_coverage)
	_check(
		not validator.audit(output, changed_coverage).get("ok", false),
		"GDScript message reopen rejects rehashed node coverage changes"
	)
	var changed_message: Dictionary = compile_audit.duplicate(true)
	changed_message.operation.replacement_raw_sha256 = "0".repeat(64)
	changed_message.payload_sha256 = validator.fingerprint(changed_message)
	_check(
		not validator.audit(output, changed_message).get("ok", false),
		"GDScript message reopen rejects a changed replacement identity"
	)
	var unknown: Dictionary = compile_audit.duplicate(true)
	unknown["ignored"] = true
	unknown.payload_sha256 = validator.fingerprint(unknown)
	_check(
		not validator.audit(output, unknown).get("ok", false),
		"GDScript message reopen rejects unknown audit fields"
	)
	var fractional: Dictionary = compile_audit.duplicate(true)
	fractional.relocation.address_table_update_count = 1.5
	fractional.payload_sha256 = validator.fingerprint(fractional)
	_check(
		not validator.audit(output, fractional).get("ok", false),
		"GDScript message reopen rejects non-integral relocation counts"
	)
	get_tree().quit(1 if _failed else 0)


func _compile_audit(
	source: PackedByteArray, output: PackedByteArray, validator: RefCounted
) -> Dictionary:
	var source_code_offset := 12
	var output_code_offset := 12
	var document := {
		"ok": true,
		"schema": ContentCoreVersionScript.MES_MESSAGE_COMPILE_AUDIT_SCHEMA,
		"producer": {
			"implementation": "python_phase6_message_compiler",
			"contract": ContentCoreVersionScript.MES_MESSAGE_COMPILE_AUDIT_SCHEMA,
		},
		"compatibility": {
			"policy": "blocker_free_message_plan_only",
			"input_editable_schema": ContentCoreVersionScript.MES_EDITABLE_IR_SCHEMA,
			"input_plan_schema": ContentCoreVersionScript.MES_MESSAGE_RELOCATION_PLAN_SCHEMA,
			"input_decompiler_schema": ContentCoreVersionScript.MES_DECOMPILER_IR_SCHEMA,
			"unknown_audit_schema": "reject",
			"unknown_v1_field": "reject",
			"output_policy": "new_file_only",
			"native_engine_compatibility": "unverified",
		},
		"source_identity": {"entry": "RELOCATE.MES"},
		"inputs": {
			"editable_ir_sha256": "1".repeat(64),
			"decompiler_ir_sha256": "2".repeat(64),
			"relocation_plan_sha256": "3".repeat(64),
		},
		"source": _summary(source, source_code_offset),
		"output": _summary(output, output_code_offset),
		"operation": {
			"kind": "replace_message",
			"source_offset": 0,
			"source_raw_sha256": _sha256(PackedByteArray([0x82, 0xA0])),
			"replacement_raw_sha256": _sha256(PackedByteArray([0x82, 0xA2, 0x82, 0xA4])),
			"source_byte_length": 2,
			"replacement_byte_length": 4,
			"encoding": "cp932",
		},
		"relocation": {
			"delta": 2,
			"source_instruction_start": 0,
			"source_instruction_end": 4,
			"output_instruction_end": 6,
			"address_table_update_count": 1,
			"affected_reference_count": 2,
		},
		"coverage": {
			"output_region_count": 2,
			"source_node_count": 2,
			"source_typed_node_count": 2,
			"source_opaque_node_count": 0,
			"source_code_bytes": 7,
			"output_code_bytes": 9,
		},
		"invariants": {
			"plan_ready": true,
			"output_reopened": true,
			"entry_count_preserved": true,
			"code_size_delta_exact": true,
			"address_table_relocated_exactly": true,
			"nonaddress_preamble_bytes_preserved": true,
			"code_prefix_preserved": true,
			"replacement_node_exact": true,
			"code_suffix_preserved": true,
			"opaque_records_not_shifted": true,
			"source_container_not_modified": true,
		},
	}
	document["payload_sha256"] = validator.fingerprint(document)
	return document


func _source_mes() -> PackedByteArray:
	var result := PackedByteArray()
	SyntheticArc.append_u32(result, 2)
	SyntheticArc.append_u32(result, 0)
	SyntheticArc.append_u32(result, 4)
	result.append_array(PackedByteArray([0x01, 0x82, 0xA0, 0x00, 0x82, 0xA2, 0x00]))
	return result


func _compiled_mes() -> PackedByteArray:
	var result := PackedByteArray()
	SyntheticArc.append_u32(result, 2)
	SyntheticArc.append_u32(result, 0)
	SyntheticArc.append_u32(result, 6)
	result.append_array(PackedByteArray([
		0x01, 0x82, 0xA2, 0x82, 0xA4, 0x00,
		0x82, 0xA2, 0x00,
	]))
	return result


func _summary(payload: PackedByteArray, code_offset: int) -> Dictionary:
	return {
		"size": payload.size(),
		"entry_count": 2,
		"code_offset": code_offset,
		"code_size": payload.size() - code_offset,
		"entry_sha256": _sha256(payload),
		"bytecode_sha256": _sha256(payload.slice(code_offset)),
		"preamble_sha256": _sha256(payload.slice(0, code_offset)),
	}


func _all_true(document: Dictionary) -> bool:
	for value in document.values():
		if value != true:
			return false
	return true


func _sha256(data: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(data)
	return context.finish().hex_encode()
