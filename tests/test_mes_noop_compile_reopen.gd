extends "res://tests/test_case.gd"

const ReopenAuditScript := preload("res://content_core/mes_noop_compile_reopen.gd")
const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")
const SyntheticArc := preload("res://tests/synthetic_arc.gd")


func _ready() -> void:
	var payload := _framed_mes()
	var validator := ReopenAuditScript.new()
	var compile_audit := _compile_audit(payload, validator)
	var report: Dictionary = validator.audit(payload, compile_audit)
	_check(
		report.get("ok", false)
		and report.schema == ContentCoreVersionScript.MES_NOOP_REOPEN_AUDIT_SCHEMA
		and report.output.size == payload.size()
		and report.output.entry_count == 1
		and report.coverage.region_count == 2
		and report.coverage.node_count == 3
		and report.coverage.typed_node_count == 2
		and report.coverage.opaque_node_count == 1
		and report.phase1_4.analysis_diagnostic_count == 1
		and report.phase1_4.alignment_failure_count == 0
		and _all_true(report.invariants)
		and report.payload_sha256 == validator.fingerprint(report),
		"GDScript reopens a Python-contract no-op MES through the current Phase 1-4 boundary"
	)
	var transported = JSON.parse_string(JSON.stringify(compile_audit))
	var transport_report: Dictionary = validator.audit(payload, transported)
	_check(
		transport_report.get("ok", false)
		and transport_report.compile_audit_sha256 == compile_audit.payload_sha256,
		"GDScript canonicalizes integral JSON numbers without changing the Python audit fingerprint"
	)
	var changed_payload := payload.duplicate()
	changed_payload[changed_payload.size() - 1] ^= 0x01
	_check(
		not validator.audit(changed_payload, compile_audit).get("ok", false),
		"GDScript no-op reopen rejects bytes that differ from the compile audit"
	)
	var changed_coverage: Dictionary = compile_audit.duplicate(true)
	changed_coverage.coverage.opaque_node_count = 0
	changed_coverage.coverage.node_count = 2
	changed_coverage.payload_sha256 = validator.fingerprint(changed_coverage)
	_check(
		not validator.audit(payload, changed_coverage).get("ok", false),
		"GDScript no-op reopen rejects rehashed Phase 1-4 coverage changes"
	)
	var unknown_field: Dictionary = compile_audit.duplicate(true)
	unknown_field["ignored_operation"] = true
	unknown_field.payload_sha256 = validator.fingerprint(unknown_field)
	_check(
		not validator.audit(payload, unknown_field).get("ok", false),
		"GDScript no-op reopen rejects rehashed unknown compile-audit fields"
	)
	var changed_fingerprint: Dictionary = compile_audit.duplicate(true)
	changed_fingerprint.payload_sha256 = "0".repeat(64)
	_check(
		not validator.audit(payload, changed_fingerprint).get("ok", false),
		"GDScript no-op reopen rejects a changed compile-audit fingerprint"
	)
	var fractional_count: Dictionary = compile_audit.duplicate(true)
	fractional_count.operations.count = 0.5
	fractional_count.payload_sha256 = validator.fingerprint(fractional_count)
	_check(
		not validator.audit(payload, fractional_count).get("ok", false),
		"GDScript no-op reopen rejects non-integral compile-audit counts"
	)
	get_tree().quit(1 if _failed else 0)


func _compile_audit(payload: PackedByteArray, validator: RefCounted) -> Dictionary:
	var code_offset := 8
	var entry_sha := _sha256(payload)
	var bytecode_sha := _sha256(payload.slice(code_offset))
	var preamble_sha := _sha256(payload.slice(0, code_offset))
	var document := {
		"ok": true,
		"schema": ContentCoreVersionScript.MES_NOOP_COMPILE_AUDIT_SCHEMA,
		"producer": {
			"implementation": "python_phase6_noop_compiler",
			"contract": ContentCoreVersionScript.MES_NOOP_COMPILE_AUDIT_SCHEMA,
		},
		"compatibility": {
			"policy": "exact_editable_ir_v1_no_operations",
			"input_editable_schema": ContentCoreVersionScript.MES_EDITABLE_IR_SCHEMA,
			"input_decompiler_schema": ContentCoreVersionScript.MES_DECOMPILER_IR_SCHEMA,
			"unknown_audit_schema": "reject",
			"unknown_v1_field": "reject",
			"output_policy": "new_file_only",
		},
		"source_identity": {"entry": "SYNTHETIC.MES"},
		"inputs": {
			"editable_ir_sha256": "1".repeat(64),
			"decompiler_ir_sha256": "2".repeat(64),
		},
		"source": {
			"entry_sha256": entry_sha,
			"bytecode_sha256": bytecode_sha,
			"preamble_sha256": preamble_sha,
		},
		"output": {
			"size": payload.size(),
			"entry_count": 1,
			"entry_sha256": entry_sha,
			"code_offset": code_offset,
			"code_size": payload.size() - code_offset,
			"bytecode_sha256": bytecode_sha,
			"preamble_sha256": preamble_sha,
		},
		"operations": {"count": 0, "relocation_count": 0},
		"coverage": {
			"region_count": 2,
			"node_count": 3,
			"typed_node_count": 2,
			"opaque_node_count": 1,
			"code_bytes": payload.size() - code_offset,
		},
		"invariants": {
			"output_reopened": true,
			"source_container_byte_identical": true,
			"source_bytecode_byte_identical": true,
			"preamble_byte_identical": true,
			"region_partition_preserved": true,
			"node_partition_preserved": true,
			"opaque_records_preserved": true,
		},
	}
	document["payload_sha256"] = validator.fingerprint(document)
	return document


func _framed_mes() -> PackedByteArray:
	var code := PackedByteArray([
		0x0D,
		0x0B, 0x02, 0xFF, 0x01, 0x01, 0x01, 0x01,
		0x00,
		0x12, 0x02, 0x01, 0xFF, 0x00,
		0x0A, 0xE3, 0xFF, 0x00,
	])
	var mes := PackedByteArray()
	SyntheticArc.append_u32(mes, 1)
	SyntheticArc.append_u32(mes, 0)
	mes.append_array(code)
	return mes


func _all_true(document: Dictionary) -> bool:
	for value in document.values():
		if value != true:
			return false
	return true


func _sha256(data: PackedByteArray) -> String:
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK or context.update(data) != OK:
		return ""
	return context.finish().hex_encode()
